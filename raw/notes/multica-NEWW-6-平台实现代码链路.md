# NEWW-6 交付过程 — Multica 平台代码实现链路

> 本文从 Go 源码层面拆解 NEWW-6 整个交付过程（Squad assign → Agent run 完成）在 multica 服务端的实现。  
> 分析对象：`server/internal/handler/` 与 `server/internal/service/`  

---

## 系统总体架构

```
HTTP API 层              内部 Service 层            DB 层
──────────────          ─────────────────          ─────────
handler/issue.go        service/issue_trigger.go   agent_task_queue 表
handler/comment.go      service/task.go            comments 表
handler/daemon.go       service/autopilot.go       issues 表
handler/squad_briefing.go                          squads / squad_members 表
```

---

## 第一阶段：Issue Assign 触发第一个 Run

### 1. `PUT /api/issues/:id` → `UpdateIssue`

```go
// server/internal/handler/issue.go:3638
assigneeChanged := (req.AssigneeType != nil || req.AssigneeID != nil) &&
    (prevIssue.AssigneeType.String != issue.AssigneeType.String || ...)
statusChanged := req.Updates.Status != nil && prevIssue.Status != issue.Status

// L3704 - 决策层：是否需要入队一个新 Run
if trigger, ok := h.IssueService.WillEnqueueRun(r.Context(),
    service.IssueTriggerInput{
        Issue:           issue,
        PrevStatus:      prevIssue.Status,
        AssigneeChanged: assigneeChanged,
        StatusChanged:   statusChanged,
    },
    h.issueTriggerWriteProbe(r, actorType, actorID, issue),
); ok && !req.SuppressRun {
    h.dispatchIssueRun(r.Context(), issue, trigger, actorType, actorID, req.HandoffNote)
}
```

### 2. `WillEnqueueRun` — 单一决策入口

```go
// server/internal/service/issue_trigger.go:97
func (s *IssueService) WillEnqueueRun(ctx context.Context, in IssueTriggerInput, probe IssueTriggerProbe) (IssueRunTrigger, bool) {
    // 决策规则：
    //   - Assign/Create + status != backlog → RunSourceAssign
    //   - Status change: backlog → 非 backlog/done/cancelled → RunSourceStatus
    //   - 其余一律不触发

    switch issue.AssigneeType.String {
    case "agent":
        // 直接取 issue.AssigneeID 作为目标 agent
        return IssueRunTrigger{
            IssueID:      issue.ID,
            AgentID:      issue.AssigneeID,
            AssigneeType: "agent",
            Source:       source,
        }, true

    case "squad":
        // 解析 squad → 取 squad.LeaderID 作为实际 agent
        // 核心：Squad assign 触发的是 Leader Agent，不是 Squad 本身
        squad, _ := s.Queries.GetSquadInWorkspace(...)
        leader, _ := s.Queries.GetAgent(ctx, squad.LeaderID)
        return IssueRunTrigger{
            IssueID:      issue.ID,
            AgentID:      squad.LeaderID,   // ← Leader 执行
            AssigneeType: "squad",
            Source:       source,
        }, true
    }
}
```

**关键设计**：`WillEnqueueRun` 是唯一决策入口，preview 接口、create、单 assign、批量 assign 全部走同一路径，不会漂移（见代码注释 MUL-3375）。

### 3. `dispatchIssueRun` — 实际入队

```go
// server/internal/handler/issue_trigger.go:84
func (h *Handler) dispatchIssueRun(ctx context.Context, issue db.Issue, trigger service.IssueRunTrigger, actorType, actorID, handoffNote string) {
    switch trigger.AssigneeType {
    case "agent":
        h.TaskService.EnqueueTaskForIssueWithHandoff(ctx, issue, handoffNote, memberActorUserID(actorType, actorID))
    case "squad":
        h.enqueueSquadLeaderTask(ctx, issue, pgtype.UUID{}, actorType, actorID, handoffNote)
    }
}
```

### 4. `enqueueIssueTaskWithCommentPlan` — 写入 DB

```go
// server/internal/service/task.go:1234
func (s *TaskService) enqueueIssueTaskWithCommentPlan(...) (db.AgentTaskQueue, error) {
    // 1. 加载 agent 行，校验 archived / runtime
    agent, _ := s.Queries.GetAgent(ctx, issue.AssigneeID)

    // 2. 解析 attribution（谁发起了这次 run，用于审计）
    attr := s.attributionForIssueTask(ctx, issue, triggerCommentID, ...)

    // 3. 构建 CreateAgentTaskParams
    createParams := db.CreateAgentTaskParams{
        ID:               dbid.NewV7(),
        AgentID:          issue.AssigneeID,
        RuntimeID:        agent.RuntimeID,
        IssueID:          issue.ID,
        Priority:         priorityToInt(issue.Priority),
        TriggerCommentID: triggerCommentID,   // 触发此 run 的评论 ID
        OriginatorUserID: originatorUserID,   // 人类溯源
        RuntimeMcpOverlay: ...,              // Composio MCP overlay（可选）
        HeadSha:          headShaText(...),   // 防重复入队的 dedup key
    }

    // 4. 写入 DB
    task, err = s.Queries.CreateAgentTask(ctx, createParams)

    // 5. 广播 task:queued 事件（WebSocket → 前端实时更新）
    s.broadcastTaskEvent(ctx, protocol.EventTaskQueued, task)
    // 6. 通知 daemon 有新任务（进程内 channel → HTTP claim）
    s.NotifyTaskEnqueued(ctx, task)
}
```

---

## 第二阶段：Daemon Claim — 任务分发给 Agent

Multica CLI daemon（本地进程）轮询 `/api/daemon/tasks/claim`，server 执行 `buildClaimedTaskResponse`。

### 5. `buildClaimedTaskResponse` — 构建 Agent 执行上下文

```go
// server/internal/handler/daemon.go:2151
resp.LeaderRoleResolved = true  // 告知 daemon：我已决策好 leader 角色

// 如果这是 squad leader 任务：注入 Squad Operating Protocol
if resp.Agent != nil && task.SquadID.Valid {
    squad, _ := h.Queries.GetSquadInWorkspace(...)
    ownsIssueStatus := (issue.AssigneeType == "squad" && issue.AssigneeID == squad.ID)
    briefing := buildSquadLeaderBriefing(ctx, h.Queries, squad, ownsIssueStatus)

    // 把 Briefing 追加到 Agent.Instructions 末尾
    if strings.TrimSpace(resp.Agent.Instructions) == "" {
        resp.Agent.Instructions = briefing
    } else {
        resp.Agent.Instructions = resp.Agent.Instructions + "\n\n" + briefing
    }
}
```

### 6. `buildSquadLeaderBriefing` — Squad Leader 简报

```go
// server/internal/handler/squad_briefing.go:196
func buildSquadLeaderBriefing(ctx, q, squad, ownsIssueStatus) string {
    // 三个部分拼接：
    return squadOperatingProtocolFor(ownsIssueStatus) +  // ① 操作协议（固定常量）
           "\n\n" +
           buildSquadRoster(ctx, q, squad) +             // ② Squad 成员名单（动态）
           squadInstructions(squad)                      // ③ 用户自定义指令（可选）
}
```

**`squadOperatingProtocolFor`** 的核心内容（见 `squad_briefing.go:33-94`）：
1. 你是 **协调员**，不要自己实现工作
2. 用 `[@Name](mention://<type>/<UUID>)` 格式 **委派给成员**
3. 每次必须调用 `multica squad activity <issue-id> <outcome>`
4. 发出委派注释后 **立即停止**，等待下次触发
5. 重新触发时 **重新评估**，无需操作时 `no_action` 静默退出
6. 管理 parent issue 的状态（仅当此 squad 是 issue 的 assignee 时）

**`buildSquadRoster`** 的动态部分（见 `squad_briefing.go:213-258`）：
```
## Squad Roster

Leader (you):
- 业务负责人 — agent — `[@业务负责人](mention://agent/<uuid>)`

Members:
- 全栈工程师 — agent, role: "全栈工程师" — skills: ... — `[@全栈工程师](mention://agent/<uuid>)`
- 产品分析师  — agent, role: "产品分析师"  — skills: ... — `[@产品分析师](mention://agent/<uuid>)`
- 代码审查员  — agent, role: "代码审查员"  — skills: ... — `[@代码审查员](mention://agent/<uuid>)`
- 测试工程师  — agent, role: "测试工程师"  — skills: ... — `[@测试工程师](mention://agent/<uuid>)`
```

---

## 第三阶段：Agent 发表评论 → 触发下一个 Agent Run

### 7. `CreateComment` → `triggerTasksForComment`

```go
// server/internal/handler/comment.go:1923
func (h *Handler) triggerTasksForComment(ctx, issue, comment, parentComment, actorType, actorID, originatorUserID, suppressAgentIDs) []CommentTriggerOutcome {
    // 解析 comment.Content 中所有 @mention
    triggers := h.computeCommentAgentTriggers(ctx, issue, content, parentComment, actorType, actorID, opts)

    // 对每个触发的 agent 入队 task
    return h.enqueueCommentAgentTriggers(ctx, issue, triggerCommentID, triggers)
}
```

### 8. `computeCommentAgentTriggers` — @mention 解析与路由

```go
// server/internal/handler/comment.go:2572
func (h *Handler) computeCommentAgentTriggers(...) ([]commentAgentTrigger, []commentMentionTarget) {
    mentions := util.ParseMentions(content)   // 解析 [@Name](mention://agent/<uuid>) 语法

    if hasAgentOrSquadMention(mentions) {
        // 路径 A：显式 @mention 触发
        triggers, targets = h.resolveMentionedAgentCommentTriggers(ctx, issue, mentions, ...)
    } else if parentComment != nil {
        // 路径 B：回复 parent → 触发 parent 作者或 squad leader
        trigger, ok = h.routeReplyToParentAuthor(ctx, issue, parentComment, ...)
    } else {
        // 路径 C：无 @mention + 无 parent → assignee fallback
        trigger, ok = h.routeAssignedSquadLeaderFallback(ctx, issue, ...)
    }
}
```

**`resolveMentionedAgentCommentTriggers`** 关键路径（对 @squad mention）：
```go
// comment.go:2992
if mention.Type == "squad" {
    squad, _ = h.Queries.GetSquadInWorkspace(...)
    leader, _ = h.Queries.GetAgent(ctx, squad.LeaderID)
    return commentAgentTrigger{
        Agent: leader,
        Source: commentTriggerSourceMentionSquadLeader,
        Squad: &squad,
    }
}
```

### 9. `enqueueCommentAgentTriggers` → 写入 task

```go
// comment.go:2003
func (h *Handler) enqueueCommentAgentTriggers(...) map[string]commentEnqueueResult {
    for _, trigger := range triggers {
        result := h.resolveCommentTriggerEnqueue(ctx, issue, trigger, triggerCommentID)
        // 尝试 merge 进已有 pending task
        // 或入队新 task
    }
}
```

**`resolveCommentTriggerEnqueue`** 优先尝试 **merge** 到已有 pending task（`mergeCommentIntoPendingTask`），如果无法 merge 才创建新 task（`enqueueSingleCommentTrigger`）。

---

## 第四阶段：Task 完成 & 状态流转

### 10. `POST /api/daemon/tasks/:id/complete` → `CompleteTask`

```go
// server/internal/service/task.go:4203
func (s *TaskService) CompleteTask(ctx, taskID, result, sessionID, workDir, branchName, ...) (*db.AgentTaskQueue, error) {
    // 1. 更新 task.status → "done"，记录 session_id / work_dir / branch_name
    // 2. broadcastTaskEvent(EventTaskCompleted)
    // 3. 触发 reconcileCommentsOnCompletion（重路由未被覆盖的 comment）
    // 4. 触发 notifyParentOfChildDone（子 issue done → 通知父 issue）
}
```

### 11. `PUT /api/issues/:id` → `multica issue status in_progress`

Agent 调用 CLI → `PUT /api/issues/{id}` → `UpdateIssue` → 同上面第 1 步逻辑（但此时 `AssigneeChanged=false, StatusChanged=true`），再次经过 `WillEnqueueRun` 判断是否需要启动新 run（通常业务负责人手动改 status，不启动新 run）。

---

## 关键数据模型

### `agent_task_queue` 表（核心 Task 行）

| 字段 | 含义 |
|------|------|
| `id` | Task UUID（UUIDv7，单调递增） |
| `agent_id` | 执行这个 run 的 agent |
| `runtime_id` | 绑定的 CLI daemon runtime |
| `issue_id` | 所属 issue |
| `squad_id` | 如果是 leader task，记录 squad；用于 claim 时注入 briefing |
| `is_leader_task` | bool — 是否是 squad leader 角色 |
| `trigger_comment_id` | 触发此 task 的 comment ID（comment run 路径）|
| `coalesced_comment_ids` | 合并进此 task 的多个 comment ID |
| `status` | `queued` → `dispatched` → `started` → `done`/`failed`/`cancelled` |
| `originator_user_id` | 人类溯源（attribution chain 最终的人） |
| `head_sha` | 防重复 dedup key（PR review 场景） |
| `force_fresh_session` | 是否强制开新 session（rerun 路径） |
| `handoff_note` | 旧版 API 兼容字段，传递给 agent 的初始上下文 |
| `runtime_mcp_overlay` | Composio MCP apps 配置（动态工具注入） |

### `comments` 表 + 触发机制

- `author_type` = `"agent"` 时，写入 comment 后会走 `computeCommentAgentTriggers`
- `parent_id` IS NULL → root 评论（人类可见 + 可触发 assignee）
- `parent_id` NOT NULL → thread 内回复（Agent 间协作）
- `type` 字段区分 `comment` / `progress_update` / `system` 等 — 影响是否触发 agent

---

## 完整请求链路图

```
yuxudong 将 Issue NEWW-6 assign 给 "研发团队" Squad
         │
         ▼
PUT /api/issues/{id}  [handler/issue.go: UpdateIssue]
         │
         ├── assigneeChanged = true
         ▼
IssueService.WillEnqueueRun()  [service/issue_trigger.go]
         │ issue.AssigneeType = "squad"
         ├── GetSquad → GetAgent(squad.LeaderID) → AgentReadiness check
         └── return IssueRunTrigger{AgentID: leaderID, AssigneeType: "squad"}
         │
         ▼
handler.dispatchIssueRun()  [issue_trigger.go:84]
         │ trigger.AssigneeType = "squad"
         └── enqueueSquadLeaderTask()
         │
         ▼
TaskService.enqueueMentionTaskWithCommentPlan()  [task.go:1397]
         │
         ├── CreateAgentTask(DB) → agent_task_queue row (status=queued)
         ├── broadcastTaskEvent(task:queued)        → WebSocket → 前端
         └── NotifyTaskEnqueued(runtimeID, taskID)  → 进程内 channel → daemon
         │
         ▼
Daemon CLI 轮询 POST /api/daemon/tasks/claim
         │
         ▼
handler.buildClaimedTaskResponse()  [daemon.go:2151]
         │
         ├── 加载 agent 行（Instructions、Skills）
         ├── 加载 issue 行（title、description、comments）
         ├── task.SquadID.Valid = true →
         │     buildSquadLeaderBriefing()            [squad_briefing.go:196]
         │     = 操作协议 + Squad 成员名单 + 用户自定义指令
         │     → 追加到 agent.Instructions 末尾
         ├── WorkspaceContext（全局系统 prompt）
         └── IssueStatuses（自定义状态目录）
         │
         ▼
业务负责人 Agent (Leader) 执行 run：
  1. multica issue get <id>
  2. multica issue comment list <id> --roots-only
  3. multica issue status <id> in_progress
  4. 写评论：[@全栈工程师](mention://agent/<uuid>) 请执行初始化…
  5. multica squad activity <id> action --reason "..."
         │
         ▼
POST /api/issues/{id}/comments  [handler/comment.go: CreateComment]
         │
         ├── util.ParseMentions(content) → [{type:agent, id:<全栈工程师>}]
         ├── computeCommentAgentTriggers()
         │     → resolveMentionedAgentCommentTriggers()
         │     → commentAgentTrigger{Agent: 全栈工程师, Source: mention_agent}
         └── enqueueCommentAgentTriggers()
               │
               └── enqueueSingleCommentTrigger()
                     → TaskService.EnqueueTaskForMention()
                     → CreateAgentTask(DB, trigger_comment_id = 上一条评论)
         │
         ▼
全栈工程师 Agent 执行 run（R02、R07…）
  ← 重复以上 claim / execute / comment 循环，直到所有阶段完成
```

---

## 关键设计原则（源码注释中提炼）

### 1. 「Backlog 是停车场」规则
```go
// issue_trigger.go:126-128
if currentStatus == "backlog" {
    return IssueRunTrigger{}, false  // assign 到 backlog 不触发 run
}
```

### 2. 「任务不取消」原则（MUL-4113）
```go
// issue.go:3692-3703
// A reassignment intentionally does NOT cancel existing tasks on the issue.
// The previous "cancel every active task on the issue" was too coarse:
// it silently dropped unrelated in-flight work with no requeue.
```

### 3. 「Agent 间 comment 路由」防循环设计
```go
// comment.go:4065
// AGENT comments qualify, but ONLY through an explicit @agent/@squad mention
// (keepExplicitMentionTriggers). Every non-mention agent route — the
// assigned-squad-leader fallback, thread-parent / conversation continuation
// — is intentionally excluded, so a plain agent reply earns no follow-up
// regardless of issue assignment. That is the anti-loop boundary.
```

### 4. 「dedup 防重复入队」
```go
// task.go:1427-1462
// 写入时触发 PostgreSQL 唯一索引 (issue_id, agent_id) over pending tasks
// 唯一键冲突 → ErrDuplicatePendingTask (409) → 调用方静默处理
```

### 5. 「Attribution 溯源」链（MUL-4302）
- 每个 task 都记录 `originator_user_id`（最终人类责任人）
- Agent 作为 actor 时不算人类，需要向上回溯到 `trigger_comment.author` 的人类创始人
- 若整条链找不到人类 → `owner_fallback`（agent 所有者）或 fail-closed（拒绝入队）

---

## 文件索引

| 文件 | 核心职责 |
|------|----------|
| `server/internal/handler/issue.go` | Issue CRUD，assign/status 变更触发 run |
| `server/internal/handler/issue_trigger.go` | `WillEnqueueRun` 决策 + `dispatchIssueRun` |
| `server/internal/service/issue_trigger.go` | `WillEnqueueRun` 实现（squad → leader 解析） |
| `server/internal/service/task.go` | 所有 task enqueue 实现（7000 行） |
| `server/internal/handler/comment.go` | comment 创建 → @mention 解析 → agent 入队 |
| `server/internal/handler/daemon.go` | task claim，注入 squad briefing / workspace context |
| `server/internal/handler/squad_briefing.go` | Squad Operating Protocol + Roster 构建 |
| `server/internal/handler/agent_builder.go` | Agent Instructions / Skills / Permissions 构建 |
