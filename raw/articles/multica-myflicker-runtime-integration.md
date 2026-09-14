# Multica × MyFlicker Runtime 集成经验总结

> 时间：2026-09-10  
> 分支：`feature/myflicker-runtime`  
> 场景：将 MyFlicker（快手 AI 编码助手）作为 ACP runtime 集成进 Multica 平台

---

## 一、ACP 协议关键细节

### 1.1 `session/prompt` 的 prompt 字段是数组，不是字符串

MyFlicker ACP server 要求 `session/prompt` 的 `prompt` 字段为数组格式：

```json
{
  "sessionId": "xxx",
  "prompt": [{"type": "text", "text": "your prompt here"}]
}
```

传字符串会报错：`Invalid input: expected array, received string`

### 1.2 `initialize` 的 `protocolVersion` 是整数

```json
{"protocolVersion": 1}   // ✅ 正确
{"protocolVersion": "2025-01-01"}  // ❌ 错误，报 expected number, received string
```

### 1.3 `session/new` 参数

```json
{"cwd": "/absolute/path", "mcpServers": []}
```

- `cwd` 必须是绝对路径
- `mcpServers` 是必填数组，不传报类型错误

### 1.4 streaming 内容在 notification 里

MyFlicker 的流式输出通过 `session/update` notification 推送：

```json
{
  "method": "session/update",
  "params": {
    "sessionId": "...",
    "update": {
      "sessionUpdate": "agent_message_chunk",
      "content": {"type": "text", "text": "chunk..."}
    }
  }
}
```

`session/prompt` 的 response 只返回 `{"stopReason": "end_turn"}`，不含内容。

### 1.5 MyFlicker 原生读取 AGENTS.md

实验验证：把 `AGENTS.md` 写到 `cwd` 目录，MyFlicker 会自动读取并遵守其中的指令。  
无需像 `openclaw`/`kimi`/`traecli` 那样做 inline system prompt 注入。  
`--no-rules` 参数可以关闭此行为。

---

## 二、Skill 注入机制

### 2.1 两套机制的分工

| 机制 | 文件 | 作用 |
|------|------|------|
| UI 展示 | `local_skills.go` | 扫描本地 skill 目录，展示给用户选择绑定 |
| 运行时注入 | `myflicker_config.go` | 生成 `--config skillPaths` JSON，让 CLI 加载 |

两者的 skill 根目录必须保持一致，否则 UI 能看到但 agent 找不到。

### 2.2 完整的 skillPaths（5 个根目录）

```
workDir/.codeflicker/skills/     ← task 绑定的 skill（最高优先级）
~/.codeflicker/skills/           ← 用户手动安装的 skill
~/.agents/skills/                ← 跨工具通用 skill（universal root）
~/.codeflicker/remote-skills/    ← 平台预装 skill
~/.codeflicker/remote-personal-skills/  ← 个人远程 skill
```

**踩坑**：`myflicker_config.go` 最初漏掉了 `~/.agents/skills/`，导致 UI 能看到 universal skill 但运行时找不到。

### 2.3 MyFlicker skill 的加载行为

MyFlicker 的 local skill 是**懒加载（lazy）**：
- CLI 启动时通过 `skillPaths` 建立索引
- 只有被 `use_skill` 工具调用时才注入内容
- Agent 不会在"你有哪些技能"的回答里主动列出 local skill —— 这是正常行为

### 2.4 TAKUMI_CONFIG_HOME 环境变量

MyFlicker 支持通过 `TAKUMI_CONFIG_HOME` 覆盖 `~/.codeflicker` 的位置：

```go
func resolveMyflickerGlobalHome() string {
    if override := os.Getenv("TAKUMI_CONFIG_HOME"); override != "" {
        return filepath.Join(override, ".codeflicker")
    }
    home, _ := os.UserHomeDir()
    return filepath.Join(home, ".codeflicker")
}
```

Multica daemon 的 skill 路径解析必须 mirror 这个逻辑，否则自定义 home 的用户 skill 不可见。

---

## 三、版本约束

### 3.1 version.go 最低版本设置

`server/pkg/agent/version.go` 里的最低版本要与实际 CLI 版本兼容：

```go
"myflicker": "0.1.0",  // 实际版本 0.28.5 > 0.1.0，检查通过
```

设成 `1.0.0` 会导致版本检查失败（`0.28.5 < 1.0.0`）。

### 3.2 `--agent <name>` 不适合动态 brief 注入

`--agent <name>` 接受的是 MyFlicker 配置里注册的预定义 agent 名，不适合注入动态生成的 task brief。AGENTS.md 方案更灵活。

---

## 四、Database Migration

### 4.1 添加新 protocol_family 的标准流程

```sql
-- 457_runtime_profile_add_myflicker.up.sql
ALTER TABLE runtime_profile
  DROP CONSTRAINT runtime_profile_protocol_family_check;

ALTER TABLE runtime_profile
  ADD CONSTRAINT runtime_profile_protocol_family_check
  CHECK (protocol_family IN ('hermes', 'claude', 'openclaw', ..., 'myflicker'));
```

Migration 文件写好后需要执行 `make setup` 才会生效，否则 INSERT 时报 CHECK 约束违反。

---

## 五、本地开发环境运维

### 5.1 Server 启动必须加载 .env

`.env` 里的 `MULTICA_DEV_VERIFICATION_CODE=888888` 控制开发模式登录验证码，不加载时无法登录。

**错误方式**（不加载 env）：
```bash
nohup /tmp/multica-server serve &
```

**正确方式**：
```bash
set -a && source .env && set +a
nohup /tmp/multica-server serve >> /tmp/multica-server.log 2>&1 &
# 或者
make server  # 推荐，自动加载 .env 且支持热重载
```

### 5.2 Daemon 必须连正确的 Server

Daemon 和前端是两个独立进程，需要连同一个 server：

```
~/.multica/profiles/<profile>/config.json
```

```json
{
  "server_url": "http://localhost:8080",
  "token": "mul_xxx"
}
```

**创建本地 profile 步骤**：
1. 前端登录后在 Settings → API Tokens 创建 PAT
2. 手动写 config 文件（CLI `login` 不支持 `--api-url` 参数）
3. `multica --profile local daemon restart`

```bash
mkdir -p ~/.multica/profiles/local
cat > ~/.multica/profiles/local/config.json << EOF
{
  "server_url": "http://localhost:8080",
  "token": "mul_<your_token>"
}
EOF
cd server && go run ./cmd/multica --profile local daemon restart
```

### 5.3 Daemon Offline 排查

| 现象 | 原因 | 解决 |
|------|------|------|
| UI 显示 Offline | Daemon 连的是线上 server | 用本地 profile 重启 daemon |
| Daemon 日志 `count=0` | Token 对应 server 无 workspace | 确认 `server_url` 和 token 匹配 |
| 500 /api/config | Server 未运行或崩溃 | 重启 server，加载 .env |
| SIGHUP 杀死 Server | `&` 后台进程随 shell 退出 | 用 `nohup` 或 `make server` |

### 5.4 PAT 表结构

`personal_access_token` 表存的是 bcrypt hash，不能直接插入明文 token。必须通过 API 或前端 UI 创建。

---

## 六、ACP Smoke Test 方法

验证 MyFlicker 是否读取 AGENTS.md 的最小 smoke test：

```python
import subprocess, json, time

WORKDIR = "/tmp/test"
proc = subprocess.Popen(["myflicker", "acp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, cwd=WORKDIR)

def send(id_, method, params):
    proc.stdin.write((json.dumps({"jsonrpc":"2.0","id":id_,"method":method,"params":params})+"\n").encode())
    proc.stdin.flush()

def read_until_id(target_id, timeout=30):
    deadline = time.time() + timeout
    while time.time() < deadline:
        line = proc.stdout.readline()
        if not line: break
        msg = json.loads(line)
        if msg.get("id") == target_id:
            return msg
    return None

send(1, "initialize", {"protocolVersion": 1, "clientInfo": {"name": "test", "version": "0"}, "clientCapabilities": {}})
read_until_id(1)

send(2, "session/new", {"cwd": WORKDIR, "mcpServers": []})
r = read_until_id(2, timeout=15)
sid = r["result"]["sessionId"]

# prompt 必须是数组
send(3, "session/prompt", {"sessionId": sid, "prompt": [{"type": "text", "text": "say hello"}]})
# 内容在 session/update notification 里流式输出，id=3 的 response 只有 stopReason
```

**关键坑**：
- 读 stdout 时要跳过没有 `id` 的 notification（`session/update`）
- `prompt` 必须是数组，不是字符串

---

## 七、架构速查

```
Multica Frontend (localhost:3000)
    ↓ HTTP
Multica Server (localhost:8080)
    ↓ WebSocket / HTTP  
Local Daemon (multica --profile local daemon)
    ↓ spawn
myflicker acp --config /tmp/.../myflicker-config.json
    ↓ ACP JSON-RPC 2.0 stdin/stdout
MyFlicker Agent
    ↑ reads
workDir/AGENTS.md          ← task brief
workDir/.codeflicker/skills/  ← task-bound skills
~/.codeflicker/skills/        ← user global skills
~/.agents/skills/             ← universal skills
```
