# Agent-to-Agent Protocol (A2A) 深度调研

> 原始资料整理 | 调研时间：2026-09-07 | 作者：yuxudong

---

## 摘要

Agent-to-Agent Protocol（A2A）是由 Google 于 2025 年 4 月发布的开放通信协议，专为 AI Agent 之间的跨框架、跨组织互通设计。2025 年 6 月，Google 将协议捐献给 Linux Foundation，由 AWS、Cisco、Microsoft、Salesforce、SAP、ServiceNow 等成为创始成员。2025 年 8 月，IBM 的 ACP 协议并入 A2A。**v1.0 规范于 2026 年 3 月 12 日冻结**，2026 年 8 月 17 日迁入 **Agentic AI Foundation（AAIF）**，与 MCP、AGENTS.md、goose、agentgateway 并列，成为 AI Agent 通信的核心开放标准之一。截至 2026 年，A2A 获得超过 150 个组织的支持，GitHub 仓库约 25,000 stars。

---

## 1. 背景与历史

### 1.1 时间线

| 时间 | 事件 |
|------|------|
| 2025 年 4 月 9 日 | Google 发布 A2A 协议（v0.1），联合 50+ 技术伙伴 |
| 2025 年 6 月 23 日 | Google 将 A2A 捐献给 Linux Foundation，创立 Agent2Agent Protocol Project |
| 2025 年 7 月 30 日 | v0.3 发布，Agent Card 路径从 `agent.json` 改为 `agent-card.json` |
| 2025 年 8 月 | IBM ACP 协议合并入 A2A，停止独立开发 |
| 2025 年 9 月 | Google 发布基于 A2A 的 Agent Payments Protocol（AP2） |
| 2026 年 3 月 12 日 | A2A v1.0 规范冻结 |
| 2026 年 4 月 | Python SDK v1.0、Microsoft .NET SDK 等多语言 SDK 发布 |
| 2026 年 6 月 | Java SDK 1.0.0.Final 发布（Quarkus 团队） |
| 2026 年 8 月 17 日 | A2A 迁入 Agentic AI Foundation（AAIF） |

### 1.2 设计动机

现有 AI Agent 生态存在根本性碎片化问题：

- LangChain、crewAI、AutoGen、Semantic Kernel 等框架各自为营，缺乏互通
- 点对点集成呈指数级爆炸：n 个 Agent 需要 n(n-1)/2 个集成点
- Agent 无法在不暴露内部实现的前提下安全协作
- 长时任务（小时级、天级）缺乏标准化的生命周期管理

A2A 的核心设计约束：**Agent 是不透明的（opaque）**——调用方不获取对方的工具列表、内存状态、模型选型或内部执行计划，只得到一张描述卡（AgentCard）、一个任务 ID 和任务经历的状态序列。

---

## 2. 核心架构

### 2.1 四个基础对象

A2A 规范本质上只标准化四个对象，其余均为传输细节：

| 对象 | 描述 |
|------|------|
| **Agent Card** | JSON manifest，声明 Agent 是谁、能做什么、在哪里、如何认证 |
| **Task** | 工作单元，含唯一 ID、上下文 ID、状态机、历史记录和 Artifacts |
| **Message** | 由 Parts 组成的单次交换（文本、原始字节、URL 或结构化数据） |
| **Artifact** | Task 执行产生的有形输出（文档、图片、表格等任何可交付物） |

### 2.2 角色模型

```
┌─────────────────────────────────────────────────┐
│                   用户 / 上层系统                  │
└─────────────────────┬───────────────────────────┘
                      │ 发起请求
┌─────────────────────▼───────────────────────────┐
│               A2A Client（客户端 Agent）           │
│  • 获取并解析 AgentCard                           │
│  • 选择合适的 Remote Agent                        │
│  • 处理认证、构建 Task 请求                        │
│  • 管理流式更新、轮询或 Webhook                    │
└─────────────────────┬───────────────────────────┘
                      │ HTTPS + JSON-RPC 2.0 / gRPC / REST
┌─────────────────────▼───────────────────────────┐
│            A2A Server（Remote Agent）             │
│  • 暴露 HTTP 端点（/.well-known/agent-card.json） │
│  • 处理 Task 请求，执行域特定逻辑                  │
│  • 发出状态更新事件，返回 Artifacts                │
│  • 实现认证/授权（OAuth 2.0 等）                   │
└─────────────────────────────────────────────────┘
```

### 2.3 传输协议

A2A v1.0 定义了三种等价的传输绑定（三者功能完全等价，选择是运维决策而非功能决策）：

| 传输绑定 | 标识符 | 特点 |
|---------|-------|------|
| JSON-RPC 2.0 over HTTP | `JSONRPC` | 最通用，所有客户端支持 |
| gRPC | `GRPC` | 高性能，低延迟 |
| HTTP+JSON/REST | `HTTP+JSON` | 最简单，无需额外依赖 |

流式更新通过 **Server-Sent Events（SSE）** 实现。

---

## 3. Agent Card 深度解析

### 3.1 发现机制

Agent Card 发布于固定路径：

```
GET https://your-domain/.well-known/agent-card.json
```

> **注意**：v0.3 之前路径为 `agent.json`，v0.3（2025-07-30）改为 `agent-card.json`，v1.0 已在 IANA 注册此 URI。

客户端同时需发送版本头：`A2A-Version: 1.0`（缺失则被视为 v0.3）。

### 3.2 Agent Card 结构示例

```json
{
  "name": "Billing Agent",
  "description": "Issues refunds and answers invoice questions",
  "version": "1.2.0",
  "provider": { "organization": "Example Corp" },
  "capabilities": {
    "streaming": true,
    "pushNotifications": true
  },
  "supportedInterfaces": [
    {
      "protocolBinding": "JSONRPC",
      "url": "https://agents.example.com/a2a",
      "protocolVersion": "1.0"
    },
    {
      "protocolBinding": "GRPC",
      "url": "agents.example.com:443",
      "protocolVersion": "1.0"
    },
    {
      "protocolBinding": "JSONRPC",
      "url": "https://agents.example.com/a2a",
      "protocolVersion": "0.3"
    }
  ],
  "securitySchemes": {
    "oauth": {
      "type": "oauth2",
      "flows": {
        "clientCredentials": {
          "tokenUrl": "https://auth.example.com/token",
          "scopes": { "billing:write": "Issue refunds" }
        }
      }
    }
  },
  "security": [{ "oauth": ["billing:write"] }],
  "skills": [
    {
      "id": "refund",
      "name": "Issue a refund",
      "description": "Refunds a charge by transaction ID",
      "examples": ["Refund charge ch_3Nk for $40"]
    }
  ]
}
```

### 3.3 关键字段说明

- **`supportedInterfaces`**：有序列表，客户端按顺序选取第一个可用接口。每项包含 `protocolBinding`、`url`、`protocolVersion` 和可选的 `tenant`（客户端须在每个请求中回传）
- **`capabilities`**：是承诺不是愿望清单——若 `pushNotifications: false` 或缺失，相关操作必须返回 `PushNotificationNotSupportedError`
- **`skills`**：路由 Agent 读取此字段决定是否向该 Agent 分配任务，`examples` 字段更接近产品文案而非文档
- **`securitySchemes`**：复用 OpenAPI 安全方案结构（API Key、OAuth 2.0、OpenID Connect、mTLS 均支持）

---

## 4. Task 生命周期状态机

### 4.1 九个状态

A2A v1.0 的 Task 是一个严格的状态机，共九个状态：

```
                          ┌──────────────┐
                    ┌────►│ INPUT_REQUIRED├──────┐
                    │     └──────────────┘      │ 收到输入
                    │                           │
┌──────────┐  ┌────────┐  ┌─────────┐           ▼
│UNSPECIFIED│──►│SUBMITTED├──►│ WORKING ├──────►COMPLETED
└──────────┘  └────────┘  └─────────┘          (终态)
                    │           │
                    │           ├──────►FAILED    (终态)
                    │           │
                    │           ├──────►AUTH_REQUIRED──┐
                    │           │                      │ 认证完成
                    │           │◄─────────────────────┘
                    │           │
                    └───────────┴──────►CANCELED  (终态)
                                        REJECTED  (终态)
```

| 状态 | 类型 | 含义 |
|------|------|------|
| `UNSPECIFIED` | 初始 | Proto enum 零值，无实际语义 |
| `SUBMITTED` | 活跃 | Task 已接受，未开始处理 |
| `WORKING` | 活跃 | Agent 正在处理 |
| `INPUT_REQUIRED` | 中断 | Agent 需要调用方提供更多信息 |
| `AUTH_REQUIRED` | 中断 | Agent 需要额外认证 |
| `COMPLETED` | **终态** | Task 成功完成 |
| `FAILED` | **终态** | Task 执行出错 |
| `CANCELED` | **终态** | 调用方或 Agent 主动取消 |
| `REJECTED` | **终态** | Agent 拒绝执行该 Task |

### 4.2 重要错误

- 向**终态 Task** 发送消息 → `UnsupportedOperationError`
- 取消**终态 Task** → `TaskNotCancelableError`
- 服务端响应顺序错误 → `InvalidAgentResponseError`

### 4.3 SendMessage 的默认行为

> ⚠️ **常见陷阱**：`SendMessage` 默认是**阻塞**的——除非设置 `returnImmediately: true`，否则调用不返回直到 Task 到达终态或中断态。对于耗时 20 分钟以上的任务，这会导致网关超时。

---

## 5. 三种任务跟踪机制

| 机制 | 触发条件 | 适用场景 |
|------|---------|---------|
| **轮询（Polling）** | 始终可用 | 防火墙限制、最简单的实现 |
| **流式（Streaming）** | `capabilities.streaming: true` | 需要实时更新、持久连接 |
| **推送通知（Push Notifications）** | `capabilities.pushNotifications: true` | 长时任务、断线重连场景 |

### 5.1 流式 SSE 示例

```
POST /a2a HTTP/1.1
Host: agents.example.com
Authorization: Bearer <token>
A2A-Version: 1.0
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "id": "1",
  "method": "message/stream",
  "params": {
    "message": {
      "role": "user",
      "parts": [{ "kind": "text", "text": "Refund charge ch_3Nk for $40" }]
    }
  }
}
```

每个 SSE 事件是 `StreamResponse` 对象，恰好包含以下四者之一：
- `task`：初始 Task 对象
- `taskStatusUpdate`：状态转变事件（`TaskStatusUpdateEvent`）
- `taskArtifactUpdate`：新 Artifact 或 Artifact 增量
- `message`：直接消息（服务端可绕过 Task 创建直接返回消息）

### 5.2 推送通知安全要求

A2A 规范对 Webhook 安全有极为具体的要求：

- **Agent 侧**：必须携带 `PushNotificationConfig` 中的凭证；超时 10~30 秒；指数退避重试；**必须拒绝私有地址范围**（127.0.0.0/8、10.0.0.0/8、172.16.0.0/12、192.168.0.0/16）以防 SSRF
- **接收方侧**：必须返回 2xx；必须验证 Task ID 是自己创建的；应假设重复投递

---

## 6. 三步工作流

### 步骤 1：发现（Discovery）

客户端或用户发起请求后，客户端 Agent 获取目标 Agent 的 Card：

```bash
GET https://supplier-agent.example.com/.well-known/agent-card.json
A2A-Version: 1.0
```

解析 Card，评估 `skills`，确认 Agent 能胜任任务。

### 步骤 2：认证（Authentication）

按 Card 中 `securitySchemes` 指定的方案完成认证。A2A 支持 OpenAPI 安全方案：
- API Key
- HTTP Basic/Bearer
- OAuth 2.0（客户端凭证、授权码等流程）
- OpenID Connect Discovery
- mTLS

认证成功后，Remote Agent 负责授权与访问控制。

### 步骤 3：通信（Communication）

通过 JSON-RPC 2.0 发送 Task，管理任务生命周期：

```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "method": "message/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [
        { "kind": "text", "text": "Check inventory for SKU-4892 and create a PO if below 100 units" }
      ]
    },
    "configuration": {
      "returnImmediately": true
    }
  }
}
```

---

## 7. 服务端实现要点（v1.0）

### 7.1 两种流式响应模式

v1.0 规范强制区分两种模式（v0.3 时可混用，现已不行）：

**模式一：直接消息**
```
→ Message（完整回复，无 Task）
```
适用于简单、快速的请求（Agent 可完全跳过 Task 创建）。

**模式二：Task + 状态更新**
```
→ Task（初始）
→ TaskStatusUpdateEvent（WORKING）
→ TaskArtifactUpdateEvent（部分结果）
→ TaskStatusUpdateEvent（COMPLETED）
```
适用于复杂、长时任务。

混用两种模式 → `InvalidAgentResponseError`

### 7.2 Card 路由分离

Card 路由（`/.well-known/agent-card.json`）必须与协议路由（`/a2a`）分开挂载：
- Card 路由：公开可缓存，无需认证
- 协议路由：需要认证

> **常见错误**：将两者置于同一中间件下，导致新客户端无法发现该 Agent。

### 7.3 版本兼容

服务器可在 `supportedInterfaces` 中同时列出 v1.0 和 v0.3 接口，实现向后兼容：

```json
"supportedInterfaces": [
  { "protocolBinding": "JSONRPC", "url": "...", "protocolVersion": "1.0" },
  { "protocolBinding": "JSONRPC", "url": "...", "protocolVersion": "0.3" }
]
```

---

## 8. 安全分析

### 8.1 主要威胁

| 威胁 | 描述 | OWASP 参考 |
|------|------|-----------|
| **AgentCard 投毒** | 恶意修改 Card 内容，重定向流量或提升权限 | OWASP Agentic Top 10 |
| **Confused Deputy 攻击** | 令牌被某 Agent 获取后重放到另一个 Agent | MCP 授权规范明确提及 |
| **Prompt Injection** | 恶意内容通过 Agent 响应进入模型上下文 | LLM01（OWASP LLM Top 10） |
| **工具中毒（Tool Poisoning）** | 恶意工具返回操控模型行为的内容 | OWASP MCP Top 10 #3 |
| **过度代理（Excessive Agency）** | Agent 被授予超出任务所需的权限 | LLM06（OWASP LLM Top 10） |
| **SSRF via Webhook** | 攻击者注册私有地址 Webhook，利用 Agent 探测内网 | CWE-918 |

### 8.2 OAuth 2.0 令牌绑定

A2A 鼓励（但不强制）令牌绑定机制：
- 令牌应与特定 Agent 绑定，防止跨 Agent 重放
- AgentCard 支持签名验证（signed agent cards），客户端可验证 Card 完整性
- 身份联邦（Identity Federation）在 A2A 路线图中

### 8.3 Webhook 安全强制规则（规范条款）

```
MUST: 包含 PushNotificationConfig 中的凭证
MUST: 拒绝对私有地址范围的回调（SSRF 防护）
SHOULD: 10~30 秒超时
SHOULD: 指数退避重试
SHOULD: 在重复投递时幂等处理
```

---

## 9. 与 MCP 的协作关系

A2A 与 MCP 解决不同层面的问题，在实际系统中通常协同使用：

```
用户请求
    │
    ▼
编排 Agent（Orchestrator）
    │  使用 A2A 委派任务
    ├──────────────────►  专业 Agent A（财务）
    │                           │ 使用 MCP 访问工具
    │                           ├──► 数据库
    │                           └──► Stripe API
    │
    └──────────────────►  专业 Agent B（物流）
                                │ 使用 MCP 访问工具
                                ├──► 运输 API
                                └──► 地图服务
```

| 维度 | MCP | A2A |
|------|-----|-----|
| **核心定位** | Agent ↔ 工具/资源 | Agent ↔ Agent |
| **连接对象** | 工具、数据库、API | 自主 Agent |
| **信息暴露** | 工具定义完全透明 | Agent 内部完全不透明 |
| **治理** | AAIF（Agentic AI Foundation） | AAIF（Agentic AI Foundation） |
| **类比** | 给人配备工具 | 让人组成团队 |

---

## 10. 生态系统与支持

### 10.1 官方 SDK

| SDK | 语言 | 状态 |
|-----|------|------|
| [a2a-python](https://github.com/a2aproject/a2a-python) | Python | 稳定（v1.0 支持） |
| a2a-js | TypeScript/JavaScript | 稳定 |
| a2a-java | Java | 1.0.0.Final（Quarkus） |
| A2A .NET SDK | C# | Preview（Microsoft） |

### 10.2 框架集成

- **LangChain / LangGraph**：原生支持 A2A Server 和 Client
- **crewAI**：支持 A2A Agent 发布
- **AutoGen**：Microsoft 集成 A2A v1.0
- **Semantic Kernel**：Microsoft 官方支持
- **Vertex AI**：Google Cloud 原生集成

### 10.3 创始成员（Linux Foundation 项目）

Google、AWS、Cisco、Microsoft、Salesforce、SAP、ServiceNow

### 10.4 扩展协议

**AP2（Agent Payments Protocol）**：2025 年 9 月 Google 发布，基于 A2A 扩展支付能力，使 Agent 能够安全处理金融交易。

---

## 11. v0.3 → v1.0 关键变更

| 变更点 | v0.3 | v1.0 |
|--------|------|------|
| **AgentCard 路径** | `/.well-known/agent.json` | `/.well-known/agent-card.json` |
| **接口声明** | 单个 `url` 字段 | `supportedInterfaces` 有序列表 |
| **版本协商** | 无头部要求 | 必须发送 `A2A-Version: 1.0` 头部 |
| **流式规则** | Message 和 Task 事件可混用 | 严格两种模式之一，违反为 `InvalidAgentResponseError` |
| **任务状态** | 7 个状态 | 9 个状态（增加 `AUTH_REQUIRED`、`UNSPECIFIED`） |
| **媒体类型** | 无正式注册 | IANA 注册 `application/a2a+json` |
| **版本头** | 无 | 缺失版本头 = v0.3，非 "latest" |

---

## 12. 实际案例

### 案例 1：零售库存与供应商协作

**问题**：零售商库存 Agent 检测到某 SKU 库存不足，需自动向供应商下采购订单。

**流程**：
1. 零售商库存 Agent（使用 MCP 连接内部数据库）检测到低库存
2. 通过 A2A 发现供应商 Agent（读取 `/.well-known/agent-card.json`）
3. 完成 OAuth 2.0 认证
4. 发送采购任务：`{ "sku": "4892", "quantity": 500, "delivery": "2026-10-01" }`
5. 供应商 Agent 处理，流式返回确认单号和交货预计

**优势**：双方无需暴露内部系统；新增供应商只需发布 AgentCard；集成成本接近零。

### 案例 2：内容创作多 Agent 流水线

```
用户请求："为产品 X 写一篇 SEO 优化的博客文章"
    │
    ▼
编排 Agent
    ├──A2A──► 研究 Agent（收集关键词和竞品信息）
    │              │──MCP──► Google Search API
    │              │──MCP──► SEMrush API
    ├──A2A──► 写作 Agent（生成初稿）
    │              │──MCP──► LLM API
    └──A2A──► SEO Agent（优化标题/元描述/关键词密度）
                   │──MCP──► SEO 分析工具
```

每个 Agent 独立可替换（更好的写作模型上线时，只需更新 AgentCard 指向新实现），编排层无需修改。

---

## 13. 路线图与未来方向

### v1.x 计划中

- **身份联邦（Identity Federation）**：支持跨组织的 Agent 信任机制
- **动态 UX 协商**：任务进行中动态切换交互模态（添加音视频等）
- **推送通知增强**：提升流可靠性，支持更丰富的 Webhook 重试策略
- **动态技能检查**：处理未预期或不支持的 Skill 请求

### 生态演进

- A2A 与 MCP 同在 AAIF 治理下，形成**工具层（MCP）+ Agent 层（A2A）**的双层架构
- OWASP 已推出 [2026 年 Agentic Applications Top 10](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)
- 预计未来 AI Agent 网关（如 Zuplo、Kong）将原生支持 A2A 认证与能力过滤

---

## 14. 开发者实践指南

### 常见陷阱

| 陷阱 | 原因 | 修复 |
|------|------|------|
| SendMessage 超时 | 默认阻塞，长任务挂起网关 | 设置 `returnImmediately: true` |
| Card 无法被发现 | Card 路由与协议路由放在同一认证中间件下 | 分离路由，Card 公开访问 |
| 版本头缺失 | 忘记发送 `A2A-Version: 1.0` | 服务端会视为 v0.3，行为不一致 |
| capabilities 当愿望清单 | `pushNotifications: false` 后调用推送 API | 返回 `PushNotificationNotSupportedError` |
| 混用流式模式 | v1.0 前允许混用 Message 和 Task | 选择一种模式到底，违反为运行时错误 |

### 版本迁移（v0.3 → v1.0）核心变更

1. 更新 Card 路径到 `agent-card.json`
2. 将 `url` 字段替换为 `supportedInterfaces` 列表
3. 添加 `A2A-Version: 1.0` 请求头
4. 检查所有 executor 是否混用了 Message 和 Task 模式
5. 更新 Task 状态处理逻辑（增加 `AUTH_REQUIRED`）

---

## 15. 消息路由机制：如何将用户消息导向正确的 Agent

### 15.1 路由的本质

A2A 协议本身**不定义路由算法**，只提供发现所需的数据（AgentCard 的 `skills` 字段）。路由决策由上层的**编排 Agent（Orchestrator）**承担：它读取各 Agent 的技能描述，用 LLM 匹配用户意图，再通过 A2A 调用选定的 Agent。

```
用户消息「退款上个月的订单」
    │
    ▼
编排 Agent（路由核心）
    ├── 读取所有 AgentCard 的 skills 描述
    ├── LLM 匹配意图 → 选出 Billing Agent
    └── 通过 A2A 调用 → Billing Agent
```

### 15.2 AgentCard skills 字段是路由的信号源

`skills` 中的 `description` 和 `examples` **不是供人阅读的文档，而是给 LLM 路由器做意图匹配的输入**：

```json
"skills": [
  {
    "id": "refund",
    "name": "Issue a refund",
    "description": "Refunds a charge by transaction ID or order number",
    "examples": [
      "Refund charge ch_3Nk for $40",
      "退款上个月 5 号的订单"
    ]
  }
]
```

### 15.3 三种路由实现模式

| 模式 | 做法 | 适用场景 |
|------|------|---------|
| **静态注册表 + LLM 匹配** | 配置文件写死已知 Agent 域名，启动时拉取 Card，LLM 选出最匹配 Agent | 生产最常见 |
| **Tool-Calling 路由** | 将每个 Agent 的 skill 包装成 LLM function definition，由 LLM 的 tool_call 决定调用哪个 | 结构清晰、易于审计 |
| **分层路由** | 一级 Orchestrator 做粗粒度领域分类，二级再精细选 Agent | Agent 数量达数百个时 |

**Tool-Calling 路由核心代码骨架**：

```python
# 将每个 Agent 的 skill 包装成 LLM function definition
tools = []
for agent_card in registry:
    for skill in agent_card["skills"]:
        tools.append({
            "type": "function",
            "function": {
                "name": f"{agent_card['name']}__{skill['id']}",
                "description": skill["description"],
            }
        })

# LLM 根据用户消息 + tools 返回 tool_call，决定路由目标
response = llm.chat(messages=[{"role": "user", "content": user_message}], tools=tools)
agent_name, skill_id = response.tool_calls[0].function.name.split("__")

# 通过 A2A 发起调用
a2a_client.send_message(agent_url=registry[agent_name]["url"], message=user_message)
```

---

## 16. 发现机制详解：拉取式 vs 注册式

### 16.1 核心设计：纯拉取式（Pull-based），无主动注册

A2A 协议的发现机制是**拉取式**的——Agent 把 Card 挂在固定 URL 上等待客户端来取，**不存在任何主动注册协议**。

规范原文明确声明：

> *"A2A does not define a registry or directory service. Clients are expected to know the Agent's base URL through out-of-band means (configuration, user input, a directory service of their choosing)."*
>
> A2A **不定义注册表或目录服务**。客户端应通过带外手段（配置、用户输入、自选目录服务）知悉 Agent 的 base URL。

类比：**DNS + Robots.txt**，而非 Consul/Nacos/Eureka。

| 对比维度 | 传统微服务（Consul/Nacos） | A2A 协议 |
|----------|--------------------------|---------|
| 启动行为 | 服务主动注册到注册中心 | Agent 挂出 AgentCard，等待拉取 |
| 客户端行为 | 查注册中心获取地址 | 直接请求 `/.well-known/agent-card.json` |
| 健康检查 | 注册中心负责 | 无内置，由上层自行实现 |
| 下线处理 | 主动注销 / TTL 过期 | Card URL 返回 404 |

### 16.2 base URL 的来源（带外机制）

A2A 规范不管 base URL 从哪来，实践中有三种来源：

1. **硬编码配置**：运维人员在编排 Agent 的配置文件中直接写入已知 Agent 的域名
2. **企业内部注册表（规范外）**：自建数据库/配置服务存储 `{ name, card_url, owner }`，由 CI/CD 部署时脚本写入；客户端查注册表获取 URL 列表，再逐一拉取 Card
3. **用户输入**：用户直接告知 Agent 要调用的目标地址（适用于开放场景）

### 16.3 企业内部注册表模式

```
Agent 部署 ──(运维/CI 脚本)──► 内部注册表（数据库）
                               { name, card_url, owner }
                                        │
                               编排 Agent 查询列表
                                        │
                               拉取具体 AgentCard
                               GET /.well-known/agent-card.json
```

> **关键区分**：注册的是 **Card 的 URL**（元数据地址），注册动作由运维/CI 完成，**不是 Agent 自身主动推送**，也不是 A2A 协议的一部分。

### 16.4 未来：ANP 的去中心化发现

A2A 的"搭档协议" **ANP（Agent Network Protocol）** 正在设计基于 DID（去中心化身份）的发现机制，接近真正的"主动注册"语义：

```
Agent 发布 DID Document
    → 存储到去中心化网络（区块链/IPFS）
    → 其他 Agent 解析 DID → 得到 Card URL → 拉取 Card
```

这是 ANP 的范畴，A2A 本身不涉及，但两者在 AAIF 的协议栈中是互补关系。

### 16.5 为什么 A2A 不采用 ACP 的注册机制？

ACP（Agent Connect Protocol）有主动注册机制——Agent 启动后向中心化目录服务报到，客户端查目录获取地址。A2A 明确不采用这个模式，原因在于两者面向的**信任环境**根本不同。

**ACP 的注册表前提**：AGNTCY 集体（Cisco、LangChain、LlamaIndex 等）具有**服务网格思维**，熟悉 Consul/Kubernetes ServiceDiscovery——有一个内部注册中心，组织内所有服务向它报到。注册表由你自己运维、边界清晰，在**组织内部或已知合作伙伴**场景工作良好。

**A2A 面对的问题**：A2A 是 Google 联合 AWS、Microsoft、Salesforce、SAP 等共同设计的**跨组织**协议，核心问题是：

> **谁来运维一个 AWS、Google、Microsoft、阿里巴巴都信任的全球 Agent 注册表？**

答案是**没有人**——这是一个治理上无法解决的问题。任何一方运维注册表，其他方就处于依赖和不对等的地位。

**A2A 的解法**：直接绕过这个问题——**URL 本身就是注册**。

```
HTTP 服务器从不向任何中心注册，URL 就是它的地址：
  你发布网站 → URL 就是你的地址 → 别人知道 URL 就能访问你

A2A 完全复用同一模型：
  你发布 Agent → URL 就是你的地址 → 别人知道 URL 就能拿 AgentCard
```

**"带外获取 URL"并不是缺陷**，而是与现有商业合作流程完全对齐：企业 A 和 B 集成时，原本就会签合同、交换 API 文档、提供端点 URL。A2A 只是将"API 文档"标准化为 AgentCard URL，通过已有渠道传递——不需要额外的注册基础设施。

| | ACP 注册表 | A2A 无注册 |
|--|--|--|
| **适用范围** | 组织内部 / 已知合作方生态 | 任意两方，包括跨互联网 |
| **治理模型** | 中心化，注册表有明确运维方 | 去中心化，URL 即注册 |
| **信任来源** | 信任注册表运维方 | 信任 HTTPS 证书（已有 CA 体系） |
| **优点** | 发现更简单（一处查询）| 无单点故障，无治理纠纷 |
| **缺点** | 注册表成为瓶颈和单点故障 | 需带外知道对方 URL |
| **类比** | 企业内网黄页 | 互联网 URL + HTTPS |

这也从侧面解释了为什么 ACP 后来**合并进 A2A**，而不是反过来：A2A 的无注册模型在开放跨组织场景下具有结构性优势。

### 16.6 路由与发现的完整工程全景

```
┌─────────────────────────────────────────────────────────────────┐
│                         工程层（规范外）                           │
│  内部注册表                                                        │
│  { billing.corp: card_url_A, logistics.corp: card_url_B, ... }   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ 查询 Card URL 列表
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     编排 Agent                                    │
│  1. 拉取各 Agent 的 Card（GET /.well-known/agent-card.json）       │
│  2. 解析 skills 描述，用 LLM 匹配用户意图                           │
│  3. 选出目标 Agent，发起 A2A 调用                                   │
└─────────┬─────────────────────┬────────────────────────────────┘
          │ A2A (JSON-RPC 2.0)  │ A2A (JSON-RPC 2.0)
          ▼                     ▼
  ┌──────────────┐      ┌──────────────┐
  │ Billing Agent│      │ Order Agent  │
  │ AgentCard ✓  │      │ AgentCard ✓  │
  └──────────────┘      └──────────────┘
         ▲                     ▲
         └─────────────────────┘
    协议层（A2A 规范定义）：
    只管 Card 格式和调用协议，不管路由和注册
```

---

## 参考资料

1. IBM Think: [What is A2A protocol (Agent2Agent)?](https://www.ibm.com/think/topics/agent2agent-protocol)
2. Google Developers Blog: [Announcing the Agent2Agent Protocol (A2A)](https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/) (2025-04-09)
3. AAIF Blog: [A2A v1.0 Builder's Guide Part 1: Discovery, Tasks, and Clients](https://aaif.io/blog/a2a-v1-0-a-builder-s-guide-part-1-discovery-tasks-and-clients) (2026-08-27)
4. Zuplo Blog: [MCP, A2A, and Where ACP Went](https://zuplo.com/blog/agent-protocol-stack-mcp-a2a-acp-2026) (2026-07-03)
5. arXiv: [A Survey of Agent Interoperability Protocols: MCP, ACP, A2A, and ANP](https://arxiv.org/html/2505.02279v1) (2025-05-04)
6. GitHub: [a2aproject/A2A](https://github.com/a2aproject/A2A) - 官方规范仓库
7. GitHub: [a2aproject/a2a-python](https://github.com/a2aproject/a2a-python) - 官方 Python SDK
8. GitHub: [a2aproject/a2a-samples](https://github.com/a2aproject/a2a-samples) - 代码示例
9. Google Cloud Blog: [Announcing Agent Payments Protocol (AP2)](https://cloud.google.com/blog/products/ai-machine-learning/announcing-agents-to-payments-ap2-protocol) (2025-09-16)
10. Quarkus Blog: [A2A Java SDK 1.0.0.Final Released](https://quarkus.io/blog/a2a-java-sdk-1-0-0-final-released/) (2026-06-10)
