# NEWW-6 完整交付过程核心代码链路分析

> Issue：NEWW-6「增加分组能力，可以将书架上的书归属到不同的分组中展示」  
> Issue ID：`01a0a357-d5c6-7cbd-80f0-efc4c522967f`  
> 分析时间：2026-09-15  
> 状态：done  

---

## 总览

NEWW-6 从 assign 到 done 共经历 **20 个 runs**，4 个阶段，5 种角色，历时约 **90 分钟**。

| 阶段 | Runs | 主要角色 | 关键产出 |
|------|------|----------|----------|
| 接单初始化 | R01 ~ R02 | 业务负责人 → 全栈工程师 | feature 分支 + README（SHA: `efa884bf`）|
| 需求分析 | R03 ~ R05 + 人工确认 | 业务负责人 → 产品分析师 → yuxudong | `requirements.md` + `prototype.html`（SHA: `88430ada`）|
| 技术设计 + 实现 | R06 ~ R08 | 业务负责人 → 全栈工程师 | 全部代码 + 测试（SHA: `2072868b`）|
| 审查 + 验收 + 交付 | R09 ~ R14 | 代码审查员 → 测试工程师 → 代码审查员 | `code-review.md` + `test-report.md`（SHA: `3c4fa65`）|

---

## 阶段一：接单初始化（R01 → R02）

**核心链路：业务负责人 → 全栈工程师**

### R01 业务负责人（direct run，assign 触发）

```bash
multica issue get 01a0a357-d5c6-7cbd-80f0-efc4c522967f --output json
multica issue comment list <id> --roots-only --summary --compact --output json
multica issue status <id> in_progress
# 写委派指令文件
multica issue comment add <id> --content-file delegate-init.md   # root 评论
multica squad activity <id> action --reason "委派全栈工程师执行接单初始化"
```

**委派内容**（`delegate-init.md`）：
```
[@全栈工程师] 请对本需求（NEWW-6）执行接单初始化：
仓库 https://github.com/yuxudong2000/bookshelf.git
创建/复用分支 feature/NEWW-6-book-groups
写 README，提交推送后回报 Commit SHA
```

### R02 全栈工程师（初始化）

```bash
multica repo checkout https://github.com/yuxudong2000/bookshelf.git
git fetch origin feature/01a09efe-bookshelf-mvp
git checkout -b feature/NEWW-6-book-groups origin/feature/01a09efe-bookshelf-mvp
mkdir -p features/2026-09-15-NEWW-6-book-groups
# 写 README.md（含父 Issue ID、标题、链接、日期、分支、文档索引占位）
git add features/2026-09-15-NEWW-6-book-groups/README.md
git commit -m "init: NEWW-6 书架分组能力"
git push origin feature/NEWW-6-book-groups   # SHA: efa884bf
multica issue comment add <id> --parent <thread>  # 回复初始化结果
```

---

## 阶段二：需求分析（R03 → R04 → R05 → 人工确认）

**核心链路：业务负责人 → 产品分析师 → yuxudong（唯一人工介入点）**

### R03 业务负责人（核验初始化 → 派产品分析师）

```bash
# 核验 SHA efa884bf 存在
multica issue comment add <id> --parent <thread>
# [@产品分析师] 请接手 NEWW-6 需求分析，分支 feature/NEWW-6-book-groups
multica squad activity <id> action --reason "核验初始化，委派产品分析师进行 Stage 1 需求分析"
```

### R04 产品分析师（69 条消息）

**阅读现有代码**：
```bash
multica repo checkout --ref feature/NEWW-6-book-groups
cat features/2026-09-14-01a09efe-bookshelf-mvp/requirements.md   # 旧需求文档
cat server/src/db.ts                   # 现有 DB schema
cat server/src/routes/*.ts             # 现有 API 路由
cat client/src/App.tsx                 # 前端主组件
```

**产出文件**：
- `features/2026-09-15-NEWW-6-book-groups/requirements.md`
  - **F06**：分组管理（CRUD：创建、重命名、删除）
  - **F07**：书籍分组归属（归属一个或多个分组）
  - **F08**：自定义分组视图（按分组展示书籍）
- `features/2026-09-15-NEWW-6-book-groups/prototype.html`（HTML 交互原型）

```bash
git commit -m "docs(NEWW-6): 输出书架分组能力需求分析与原型"   # SHA: 88430ada
multica issue comment add <id> --parent <thread>   # 回报完成
```

### R05 业务负责人（发现待澄清 → 请求 yuxudong 决策）

```bash
# 发现两个待澄清点
multica issue comment add <id> --content-file ask-yuxudong.md   # root 评论（人类可见）
# [@yuxudong] 请确认：
#   1. 自定义分组数量是否有上限？
#   2. 书籍是否允许不归属任何分组？
```

### ⚠️ 人工介入（唯一一次）

**yuxudong 回复**：无上限，允许不归属 → 流程继续

---

## 阶段三：技术设计 + 全栈实现（R06 → R07）

**核心链路：业务负责人确认 → 全栈工程师（主力开发，250 条消息）**

### R06 业务负责人（收到确认 → 派全栈工程师 Stage 2）

```bash
multica issue comment add <id> --parent <thread>
# yuxudong 已确认：无上限，允许不归属（requirements.md 无需修改）
# [@全栈工程师] 请基于 feature/NEWW-6-book-groups 执行 Stage 2 技术设计与开发
multica squad activity <id> action --reason "yuxudong 已确认待澄清点，委派全栈工程师进行 Stage 2"
```

### R07 全栈工程师（主力开发）

#### ① 读取上下文

```bash
git fetch origin feature/NEWW-6-book-groups && git checkout feature/NEWW-6-book-groups
# 读取文件
read_file(requirements.md)
read_file(server/src/db.ts)
read_file(server/src/routes/books.ts)
read_file(server/src/index.ts)
read_file(client/src/App.tsx)
read_file(client/src/hooks/useBooks.ts)
read_file(client/src/api/books.ts)
read_file(features/2026-09-14-01a09efe-bookshelf-mvp/technical-design.md)   # 参考旧设计
```

#### ② 技术设计文档

输出 `features/2026-09-15-NEWW-6-book-groups/technical-design.md`：
- 新增 `groups`（自定义分组主表）和 `book_groups`（书籍-分组多对多关联表）
- 7 个 REST API 端点
- 前端组件方案：`GroupManageModal` / `BookGroupPicker` / `CustomGroupView`

#### ③ 后端实现

**`server/src/db.ts`**（修改）：
```typescript
// 新增接口
export interface Group {
  id: number
  name: string
  created_at: string
  book_count: number
}

// 新增建表语句（在 createDb 中）
CREATE TABLE IF NOT EXISTS groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
)
CREATE TABLE IF NOT EXISTS book_groups (
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  PRIMARY KEY (book_id, group_id)
)
PRAGMA foreign_keys = ON
```

**`server/src/routes/groups.ts`**（新建）：
```typescript
GET    /api/groups              // 查询所有分组 + book_count
POST   /api/groups              // 创建分组
PUT    /api/groups/:id          // 重命名分组
DELETE /api/groups/:id          // 删除分组（cascade book_groups）
GET    /api/groups/:id/books    // 查询分组内所有书籍
GET    /api/books/:id/groups    // 查询书籍所属分组列表
PUT    /api/books/:id/groups    // 覆盖式设置书籍分组归属
```

**`server/src/index.ts`**（修改）：
```typescript
import { createGroupsRouter } from './routes/groups.js'
app.use('/api', createGroupsRouter(db))
```

#### ④ 后端测试

**`server/__tests__/groups.api.test.ts`**（新建）：
- Vitest + supertest + in-memory SQLite（`:memory:`）
- **27 项测试**覆盖所有 7 个端点的正常/边界/异常场景

```bash
cd server && npm test   # 27/27 通过
```

#### ⑤ 前端实现

**`client/src/api/groups.ts`**（新建）：
```typescript
fetchGroups()              // GET /api/groups
createGroup(name)          // POST /api/groups
renameGroup(id, name)      // PUT /api/groups/:id
deleteGroup(id)            // DELETE /api/groups/:id
fetchGroupBooks(groupId)   // GET /api/groups/:id/books
fetchBookGroupIds(bookId)  // GET /api/books/:id/groups
setBookGroups(bookId, ids) // PUT /api/books/:id/groups
```

**`client/src/hooks/useGroups.ts`**（新建）：
```typescript
// useState + useEffect + useCallback
export function useGroups() {
  const [groups, setGroups] = useState<Group[]>([])
  // create / rename / delete / refresh 操作
}
```

**新建组件**：
- `client/src/components/GroupManageModal.tsx`：分组 CRUD 弹窗
- `client/src/components/BookGroupPicker.tsx`：书籍归属分组多选器（checkbox）
- `client/src/components/CustomGroupView.tsx`：按自定义分组展示书籍列表

**修改文件**：
- `client/src/components/BookViews.tsx`：扩展 `ViewMode = 'list' | 'group' | 'custom'`
- `client/src/components/BookDetail.tsx`：嵌入 `BookGroupPicker`
- `client/src/App.tsx`：集成 `useGroups`、自定义分组视图入口
- `client/src/hooks/useBooks.ts`：同步 `ViewMode` 类型
- `client/src/App.css`：新组件样式

#### ⑥ 前端测试

```bash
cd client && npm run build            # TypeScript 检查通过
# 写 client/__tests__/hooks/useGroups.test.ts（13 项 Vitest + Mock API）
cd client && npm test                 # 13/13 通过
```

#### ⑦ 部署验证（端口冲突处理）

```bash
lsof -i :3001   # 被 NEWW-5 测试环境占用 → 改用 PORT=3011
cd server && PORT=3011 npm run dev &
# 运行黑盒 API 验收测试（8 项）→ 8/8 通过
```

> **注**：黑盒 API 测试层（`e2e/api/groups.api.acceptance.test.ts`）已在 NEWW-6 交付后的测试职责调整中删除，后续由服务端单元测试覆盖。

#### ⑧ 提交推送

```bash
git add -A
git commit -m "feat(NEWW-6): 实现书架自定义分组能力（F06/F07/F08）"
# - 后端：新增 groups/book_groups 表与分组 CRUD、书籍分组归属查询/设置
# - 前端：GroupManageModal / BookGroupPicker / CustomGroupView
# - 测试：后端 27 项 / 前端 13 项 / 黑盒 8 项
git push origin feature/NEWW-6-book-groups   # SHA: 2072868b
# 因 runtime 无 GitHub 认证，PR 未能自动创建，提供 compare 链接供手动创建
```

---

## 阶段四：审查 + 验收 + 交付（R08 → R14）

### R08 业务负责人（核验 Stage 2 → 派代码审查员）

```bash
# 核验候选 SHA 2072868b，测试全部通过
multica issue comment add <id> --parent <thread>   # 向 yuxudong 提供 PR compare 链接
multica issue comment add <id> --parent <thread>   # [@代码审查员] 进行 Stage 3 审查
multica squad activity <id> action --reason "Stage 2 核验通过，委派代码审查员进行 Stage 3"
```

### R09 代码审查员（90 条消息）

```bash
multica repo checkout --ref feature/NEWW-6-book-groups
git diff --stat feature/01a09efe-bookshelf-mvp 2072868b   # diff 统计

# 读取所有新增/修改文件
read_file(requirements.md / technical-design.md)
read_file(server/src/routes/groups.ts)
read_file(server/src/db.ts)
read_file(server/src/index.ts)
read_file(client/src/components/GroupManageModal.tsx)
read_file(client/src/components/BookGroupPicker.tsx)
read_file(client/src/components/CustomGroupView.tsx)
read_file(client/src/hooks/useGroups.ts)

# 本地复现测试
cd server && npx vitest run              # 27/27 通过
cd client && npx vitest run              # 13/13 通过

# 输出审查报告
write_file(features/.../code-review.md)
# 结论：通过（🔴 必须修改 0 项）

git commit -m "review(NEWW-6): 代码审查报告"   # SHA: fada4d39
multica issue comment add <id> --parent <thread>  # 回报审查通过
```

### R10 业务负责人（Review 通过 → 派测试工程师 Stage 4）

```bash
multica issue comment add <id> --parent <thread>
# [@测试工程师] 执行独立验收，候选 SHA: 2072868b
multica squad activity <id> action --reason "代码审查通过，委派测试工程师进行 Stage 4"
```

### R11 测试工程师（独立验收，230 条消息）

#### 环境隔离

```bash
lsof -i :3001 -i :3011 -i :5173   # 检测端口占用（被 NEWW-5 占用）
# 使用隔离端口：后端 3021，前端 5183
```

**辅助配置文件**：
- `client/vite.groups.config.ts`：`port: 5183, proxy: /api → localhost:3021`
- `e2e/playwright.groups.config.ts`：`baseURL: http://localhost:5183`

#### UI E2E 测试（真实后端 + 真实数据库）

**`e2e/ui/groups.acceptance.e2e.test.ts`**（新建，19 项）：
```
F06-AC: 创建分组 / 重命名分组 / 删除分组 / 空态 / 名称重复校验 / 空名称校验
F07-AC: 书籍归属单个分组 / 取消归属 / 归属多个分组 / 分组视图内删除书籍
F08-AC: 分组视图切换 / 未归属书籍展示 / 按分组筛选展示
```

```bash
npx playwright test --config playwright.groups.config.ts --reporter=list   # 19/19 通过 x3
cd server && npx vitest run    # 回归：27/27
cd client && npx vitest run    # 回归：13/13

git commit                     # SHA: 3c4fa65
multica issue comment add <id> --parent <thread>  # 验收通过回报
```

### R12 业务负责人（验收通过 → 增量审查 + 业务确认）

```bash
multica issue comment add <id> --parent <thread>
# [@代码审查员] 请对新增测试代码做增量审查（SHA: 3c4fa65）
multica issue comment add <id>   # root 评论 → [@yuxudong] 请业务确认
multica squad activity <id> action --reason "验收通过，委派增量审查，请求 yuxudong 业务确认"
```

### R13 代码审查员（增量审查）

```bash
# 只审查测试代码增量
git diff 2072868b..3c4fa65
read_file(e2e/ui/groups.acceptance.e2e.test.ts)
read_file(e2e/playwright.groups.config.ts)

# 更新 code-review.md → 增量通过（🔴 0 项，🟡 1 项测试隔离建议）
git commit   # SHA: 3291b13d
multica issue comment add <id> --parent <thread>  # 回报增量审查通过
```

### R14 业务负责人（等待业务确认）

```bash
multica squad activity <id> no_action --reason "增量审查通过，等待 yuxudong 业务确认"
# issue 维持 in_progress → 等待最终合并授权
```

---

## 核心代码文件一览

```
bookshelf/
├── server/
│   ├── src/
│   │   ├── db.ts                    ← 修改：新增 Group 接口、groups/book_groups 建表
│   │   ├── routes/
│   │   │   └── groups.ts            ← 新建：7 个 REST 端点
│   │   └── index.ts                 ← 修改：注册 groupsRouter
│   └── __tests__/
│       └── groups.api.test.ts       ← 新建：27 项 Vitest + supertest + in-memory SQLite
├── client/
│   └── src/
│       ├── api/
│       │   └── groups.ts            ← 新建：7 个 fetch 方法
│       ├── hooks/
│       │   └── useGroups.ts         ← 新建：分组状态管理 hook
│       ├── components/
│       │   ├── GroupManageModal.tsx ← 新建：分组管理弹窗
│       │   ├── BookGroupPicker.tsx  ← 新建：书籍分组多选器
│       │   ├── CustomGroupView.tsx  ← 新建：自定义分组视图
│       │   ├── BookViews.tsx        ← 修改：扩展 ViewMode 类型
│       │   └── BookDetail.tsx       ← 修改：嵌入 BookGroupPicker
│       ├── App.tsx                  ← 修改：集成 useGroups + 新视图
│       ├── App.css                  ← 修改：新增 CSS
│       └── hooks/useBooks.ts        ← 修改：ViewMode 类型同步
│   └── __tests__/
│       └── hooks/useGroups.test.ts  ← 新建：13 项 Vitest hook 测试
├── e2e/
│   └── ui/
│       └── groups.acceptance.e2e.test.ts  ← 新建：19 项 Playwright UI E2E（真实后端）
└── features/2026-09-15-NEWW-6-book-groups/
    ├── README.md           ← 初始化占位（SHA: efa884bf）
    ├── requirements.md     ← 产品需求 F06/F07/F08（SHA: 88430ada）
    ├── prototype.html      ← HTML 交互原型
    ├── technical-design.md ← 技术设计文档
    ├── code-review.md      ← 审查报告（两轮，均通过，🔴 0 项）
    └── test-report.md      ← 验收测试报告（19/19 通过）
```

---

## Commit SHA 时间线

| 时间 | SHA | 操作者 | 内容 |
|------|-----|--------|------|
| `12:34` | `efa884bf` | 全栈工程师 | init: 创建分支 + README 占位 |
| `12:36` | `88430ada` | 产品分析师 | docs: 需求分析（requirements.md + prototype.html）|
| `12:45` | `2072868b` | 全栈工程师 | feat: 全部产品代码 + 测试（F06/F07/F08）|
| `12:55` | `fada4d39` | 代码审查员 | review: 代码审查报告（第一轮）|
| `13:10` | `3c4fa65` | 测试工程师 | test: 19 项 UI E2E 测试 + test-report.md |
| `13:13` | `3291b13d` | 代码审查员 | review: 增量审查报告（测试代码）|

---

## 关键设计模式

### Agent 间通信模式

```bash
# root 评论 → 触发被 @mention 的 Agent，同时人类可见
multica issue comment add <issue-id> --content-file <file>

# thread 内回复 → Agent 协作链，人类不在主 timeline 可见
multica issue comment add <issue-id> --parent <thread-id> --content-file <file>
```

每个 Agent run 的固定入口模式：
1. `multica issue get <id>` → 读取 issue 状态
2. `multica issue comment list <id> --roots-only` → 判断当前处于哪个阶段
3. 读取最新 thread 详情 → 确认 trigger 内容
4. 执行具体工作
5. 回复评论（thread 内 reply）
6. `multica squad activity <id> action/no_action --reason` → 记录协作轨迹

### 环境隔离模式

测试工程师在启动测试环境前**必须检测端口占用**，发现冲突时使用偏移端口：

```bash
lsof -i :3001 -i :3011 -i :5173   # 检测标准端口
# NEWW-5 占用 3001/3011/5173 → NEWW-6 使用 3021/5183
```

### 测试层次分工（NEWW-6 后确定的规范）

| 测试类型 | 负责角色 | 位置 | 工具 | 隔离方式 |
|----------|----------|------|------|----------|
| 后端 API 测试 | 全栈工程师 | `server/__tests__/` | Vitest + supertest | in-memory SQLite |
| 前端 Hook 单元测试 | 全栈工程师 | `client/__tests__/` | Vitest | Mock API |
| UI E2E 验收测试 | 测试工程师 | `e2e/ui/` | Playwright | 真实后端 + 真实 DB，按 issue 隔离端口 |

---

## 唯一人工介入点

整个 90 分钟交付中，**只有一次人工介入**：

> **时间**：`12:39`（Stage 1 需求分析完成后）  
> **触发**：业务负责人发现两个待澄清点，发出 root 评论 `@yuxudong`  
> **问题**：1. 自定义分组数量是否有上限？ 2. 书籍是否允许不归属任何分组？  
> **yuxudong 回复**：无上限，允许不归属  
> **结果**：`requirements.md` 无需修改，流程继续

其余全部由 5 个 Agent（业务负责人、产品分析师、全栈工程师、代码审查员、测试工程师）自主协作完成。
