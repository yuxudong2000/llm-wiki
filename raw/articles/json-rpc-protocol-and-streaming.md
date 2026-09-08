# JSON-RPC 协议深度调研：协议规范与 Stream 通信方式对比

> 原始调研日期：2026-09-08  
> 来源：JSON-RPC 2.0 官方规范（jsonrpc.org）、MCP 传输协议演进文档、技术社区分析

---

## 目录

1. [背景与定位](#1-背景与定位)
2. [JSON-RPC 协议规范详解](#2-json-rpc-协议规范详解)
   - 2.1 概述与设计哲学
   - 2.2 版本演进：1.0 → 2.0
   - 2.3 核心消息结构
   - 2.4 错误处理机制
   - 2.5 批量调用（Batch）
3. [Stream 通信方式详解](#3-stream-通信方式详解)
   - 3.1 什么是 Stream 通信
   - 3.2 Server-Sent Events（SSE）
   - 3.3 WebSocket 双向流
   - 3.4 Streamable HTTP（现代演进）
4. [JSON-RPC 与 Stream 的异同点深度对比](#4-json-rpc-与-stream-的异同点深度对比)
5. [协议组合：JSON-RPC over Stream](#5-协议组合json-rpc-over-stream)
6. [典型应用场景分析](#6-典型应用场景分析)
7. [选型决策树](#7-选型决策树)
8. [总结](#8-总结)

---

## 1. 背景与定位

在分布式系统与 AI Agent 生态快速发展的今天，通信协议的选择直接影响系统的实时性、可扩展性和开发体验。JSON-RPC 作为一种轻量级 RPC 协议，被广泛用于 Ethereum、Language Server Protocol（LSP）、MCP（Model Context Protocol）等基础设施；而 Stream（流式）通信则代表着从"一问一答"到"持续数据流"的范式转变。

二者本质上不是同一维度的概念：
- **JSON-RPC** 是一个**消息格式与调用语义**规范（定义"说什么"）
- **Stream 通信**是一种**数据传输模式**（定义"怎么传"）

理解二者的关系，是构建高性能 Agent 通信、实时 API 或 AI 工具调用系统的基础。

---

## 2. JSON-RPC 协议规范详解

### 2.1 概述与设计哲学

JSON-RPC（JSON Remote Procedure Call）是一种**无状态、轻量级的远程过程调用协议**。其设计哲学可以用三个词概括：**简单、传输无关、语义清晰**。

> "It is designed to be simple!"  
> — JSON-RPC 2.0 官方规范

**核心特征：**
- 使用 JSON（RFC 4627）作为数据格式
- **传输无关（Transport Agnostic）**：可运行在 HTTP、WebSocket、stdio、TCP socket、进程内通信等任意传输层之上
- 无状态设计，每个请求独立
- 定义了完整的客户端/服务端语义

### 2.2 版本演进：1.0 → 2.0

| 特性 | JSON-RPC 1.0 | JSON-RPC 2.0 |
|---|---|---|
| 版本标识字段 | 无 | `"jsonrpc": "2.0"` 必填 |
| Notification 标识 | `id: null` | 不含 `id` 字段 |
| 参数形式 | 仅支持 positional（数组） | 支持 positional + named（对象） |
| 批量调用 | 不支持 | 支持 Batch 请求/响应 |
| 错误处理 | 基础 | 标准化 error object |
| 通信模式 | 点对点（Peer-to-peer） | 客户端/服务端（Client/Server） |

**识别方式**：检查是否有 `"jsonrpc": "2.0"` 字段即可区分版本。

### 2.3 核心消息结构

#### 请求对象（Request Object）

```json
{
  "jsonrpc": "2.0",
  "method": "subtract",
  "params": [42, 23],
  "id": 1
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `jsonrpc` | String | 是 | 必须为 `"2.0"` |
| `method` | String | 是 | 调用的方法名。`rpc.` 开头保留给系统扩展 |
| `params` | Array 或 Object | 否 | 参数。Array = 按位置传参；Object = 按名称传参 |
| `id` | String / Number / Null | 条件 | 省略则为 Notification；不应为小数或 Null |

**两种参数传递方式：**

```json
// 按位置（Positional）
{"jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": 1}

// 按名称（Named）
{"jsonrpc": "2.0", "method": "subtract", "params": {"minuend": 42, "subtrahend": 23}, "id": 3}
```

#### 通知（Notification）

通知是**不含 `id` 字段的请求**，服务端**不得**响应。常用于单向事件推送、日志记录、状态更新等场景。

```json
{"jsonrpc": "2.0", "method": "update", "params": [1, 2, 3, 4, 5]}
```

> ⚠️ 通知不可靠：客户端无法感知服务端的处理结果，包括错误信息。

#### 响应对象（Response Object）

```json
// 成功响应
{"jsonrpc": "2.0", "result": 19, "id": 1}

// 错误响应
{"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found"}, "id": "1"}
```

| 字段 | 说明 |
|---|---|
| `jsonrpc` | 必须为 `"2.0"` |
| `result` | 成功时必须包含，失败时不得存在 |
| `error` | 失败时必须包含，成功时不得存在 |
| `id` | 必须与请求的 `id` 一致；无法识别请求 id 时为 `null` |

`result` 和 `error` **互斥，且必须有其一**。

### 2.4 错误处理机制

错误对象（Error Object）包含三个字段：

```json
{
  "code": -32601,
  "message": "Method not found",
  "data": "额外诊断信息（可选）"
}
```

**标准错误码（-32768 ~ -32000 保留）：**

| Code | Message | 含义 |
|---|---|---|
| `-32700` | Parse error | 服务端收到了无效 JSON |
| `-32600` | Invalid Request | 不合法的 Request 对象 |
| `-32601` | Method not found | 方法不存在或不可用 |
| `-32602` | Invalid params | 无效的方法参数 |
| `-32603` | Internal error | 内部 JSON-RPC 错误 |
| `-32000` ~ `-32099` | Server error | 实现定义的服务端错误 |

`-32000` 以下的错误码空间开放给应用层自定义。

### 2.5 批量调用（Batch）

客户端可以通过发送**请求对象数组**一次性批量调用多个方法：

```json
// 请求
[
  {"jsonrpc": "2.0", "method": "sum", "params": [1, 2, 4], "id": "1"},
  {"jsonrpc": "2.0", "method": "notify_hello", "params": [7]},
  {"jsonrpc": "2.0", "method": "subtract", "params": [42, 23], "id": "2"}
]

// 响应（Notification 无响应；响应顺序不保证）
[
  {"jsonrpc": "2.0", "result": 7, "id": "1"},
  {"jsonrpc": "2.0", "result": 19, "id": "2"}
]
```

**Batch 语义要点：**
- 服务端**可以并发处理**，**不保证响应顺序**
- 客户端通过 `id` 字段匹配请求与响应
- 若整个 Batch 是无效 JSON，返回单个错误响应
- 若全部为 Notification，服务端**不应返回任何内容**（不返回空数组）

---

## 3. Stream 通信方式详解

### 3.1 什么是 Stream 通信

Stream（流式）通信是指**数据以连续、增量方式传输**的通信模式，而非完整地一次性发送再等待接收。相对于传统 HTTP 的请求-响应模式，Stream 通信具有以下核心特征：

- **低延迟**：数据产生即传输，无需等待全部处理完成
- **持续连接**：客户端与服务端维持长连接（或复用连接）
- **分块传输**：内容可以是文本事件流、二进制帧或分块 HTTP 响应

Stream 通信主要形态包括：**SSE（Server-Sent Events）**、**WebSocket**、**Streamable HTTP**。

### 3.2 Server-Sent Events（SSE）

SSE 是基于 HTTP 的**单向**服务端推流机制，数据格式为 `text/event-stream`。

**协议格式：**

```
Content-Type: text/event-stream

data: {"type": "progress", "value": 42}\n\n
data: {"type": "result", "value": "done"}\n\n

event: custom_event
data: some payload\n\n
```

**SSE 消息字段：**

| 字段 | 说明 |
|---|---|
| `data:` | 数据载荷（每行一个 data 字段，多行拼接） |
| `event:` | 事件类型（默认 `message`） |
| `id:` | 事件 ID，断线重连时通过 `Last-Event-ID` 头恢复 |
| `retry:` | 重连间隔（毫秒） |

**特征：**
- ✅ 基于标准 HTTP，无需协议升级
- ✅ 浏览器原生支持（`EventSource` API）
- ✅ 自动重连机制
- ❌ **单向**：只能 Server → Client
- ❌ 客户端发送消息需另开 HTTP POST 端点

### 3.3 WebSocket 双向流

WebSocket 是**全双工**双向通信协议，通过 HTTP Upgrade 握手建立持久连接，之后以帧（Frame）格式传输数据。

**握手示例：**

```http
GET /chat HTTP/1.1
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

**特征：**
- ✅ **全双工**：双方可随时发送消息
- ✅ 低延迟（无 HTTP 头重复开销）
- ✅ 支持文本和二进制帧
- ❌ 浏览器**无法设置自定义请求头**（如 `Authorization`）
- ❌ 代理/防火墙穿透比纯 HTTP 复杂
- ❌ 升级流程基于 GET，不适合 POST-based 工作流

### 3.4 Streamable HTTP（现代演进）

Streamable HTTP 是 MCP（Model Context Protocol）在 2025-03-26 版本中引入的新传输机制，代表了 Stream 通信的现代最佳实践：

**核心设计：**
- 服务端暴露**单一 HTTP 端点**（支持 GET 和 POST）
- 简单请求返回普通 JSON 响应
- 复杂/长耗时请求**按需升级为 SSE 流**
- 支持无状态服务器（Stateless）

**与 HTTP+SSE 的对比：**

| 维度 | HTTP+SSE | Streamable HTTP |
|---|---|---|
| 端点数量 | 2个（SSE GET + POST） | 1个（统一端点） |
| 连接状态 | 有状态，长连接 | 支持无状态 |
| 流式支持 | 强制 SSE | 按需 SSE |
| 基础设施兼容性 | 需要长连接支持 | 兼容标准 HTTP 代理/CDN |
| 资源消耗 | 高（持久连接） | 低（按需） |

---

## 4. JSON-RPC 与 Stream 的异同点深度对比

### 4.1 本质定位对比

| 维度 | JSON-RPC 2.0 | Stream 通信 |
|---|---|---|
| **层次** | 应用层消息格式/调用语义 | 传输层数据流模式 |
| **关注点** | "调用什么方法、传什么参数、返回什么结果" | "数据如何持续地传输" |
| **状态性** | 无状态（每个请求独立） | 通常有状态（维持连接上下文） |
| **方向性** | 请求-响应（Request/Response） | 单向（SSE）或双向（WebSocket） |
| **消息边界** | 每个 JSON 对象是独立消息 | 帧/事件/行 等多种边界约定 |

> 🔑 关键洞见：JSON-RPC 定义**语义（What）**，Stream 定义**传输（How）**。二者可以组合使用——即"JSON-RPC over Stream"。

### 4.2 通信模式对比

```
JSON-RPC（纯请求-响应模式）：
  Client ──── Request ────► Server
  Client ◄─── Response ─── Server

JSON-RPC over SSE（混合模式）：
  Client ──── HTTP POST ──► Server
  Client ◄══ SSE Stream ═══ Server（持久单向流）

WebSocket + JSON-RPC（全双工 RPC）：
  Client ◄══════════════════► Server
         (双向 JSON-RPC 消息)

Streamable HTTP + JSON-RPC（弹性模式）：
  Client ──── HTTP POST ──► Server ──► 普通 JSON 响应
  Client ──── HTTP POST ──► Server ══► SSE 流（按需升级）
```

### 4.3 核心差异详析

#### 差异 1：时序模型（Temporal Model）

**JSON-RPC（同步/异步 RPC 语义）**
- 客户端发送请求，等待对应 `id` 的响应
- 响应是一次性的完整结果
- 可通过 Batch 并发多个调用，但每个调用仍是"一次请求 → 一次响应"

**Stream 通信**
- 服务端可以**持续推送**多个数据块
- 无需等待完整结果即可开始处理部分数据
- 时序是"流"式的，而非"事务"式的

#### 差异 2：数据完整性（Completeness）

| | JSON-RPC | Stream |
|---|---|---|
| 响应时机 | 处理完成后一次性返回 | 边处理边推送 |
| 部分结果 | 不支持（要么成功，要么错误） | 核心特性（可推送增量数据） |
| 错误处理 | 标准化 error object | 取决于具体实现（如 SSE 的 error 事件） |

#### 差异 3：连接资源（Connection Resources）

| | JSON-RPC over HTTP | Stream（SSE/WS） |
|---|---|---|
| 连接生命周期 | 短连接（每次请求建立/关闭） | 长连接（持续维持） |
| 服务端资源 | 低（无状态） | 高（需维护连接状态） |
| 扩展性 | 容易水平扩展 | 需会话亲和（Session Affinity） |

#### 差异 4：流控与背压（Flow Control & Backpressure）

- **JSON-RPC**：天然背压——客户端控制请求节奏，未发请求则服务端不产生响应
- **SSE**：服务端主导推送，客户端无法通知服务端"暂停"
- **WebSocket**：可通过消息层协议实现背压控制
- **Streamable HTTP**：HTTP/2 具有原生流控，单连接多路复用

#### 差异 5：适用场景（Use Cases）

| 场景 | 适合 JSON-RPC | 适合 Stream | 适合组合 |
|---|---|---|---|
| 简单方法调用（加减乘除、查询） | ✅ | ❌ 过重 | — |
| 大文件/长任务的进度通知 | ❌ | ✅ SSE | ✅ |
| 实时协作编辑 | ❌ | ✅ WebSocket | ✅ |
| AI 模型流式生成 | ❌ | ✅ | ✅ JSON-RPC over SSE |
| 区块链节点 API | ✅ | — | — |
| IDE 语言服务器（LSP） | ✅ over stdio | — | — |
| 多 Agent 异步任务 | ✅ (Notification) | ✅ | ✅ |

### 4.4 可靠性与保证

| 特性 | JSON-RPC | SSE | WebSocket | Streamable HTTP |
|---|---|---|---|---|
| 请求确认 | ✅（通过 id 匹配） | ❌ | 应用层自实现 | ✅（HTTP 状态码） |
| 消息有序性 | ✅（单请求） | ✅（有序流） | ✅ | ✅ |
| 断线重连 | N/A | ✅（Last-Event-ID） | 应用层处理 | ✅（stream ID） |
| 消息重传 | N/A | ✅（基于 id） | 应用层处理 | 部分支持 |

---

## 5. 协议组合：JSON-RPC over Stream

在实际系统中，JSON-RPC 常常被"架"在 Stream 传输层之上，形成强大的组合模式。

### 5.1 JSON-RPC over WebSocket

这是 JSON-RPC 与 Stream 结合的最常见形态，适用于需要**双向、低延迟 RPC** 的场景：

```javascript
// 客户端发送 JSON-RPC 请求
ws.send(JSON.stringify({
  "jsonrpc": "2.0",
  "method": "eth_getBalance",
  "params": ["0xAddress", "latest"],
  "id": 1
}));

// 服务端通过同一连接推送响应
// 也可主动发送 Notification（无 id）通知客户端状态变化
ws.onmessage = (event) => {
  const rpc = JSON.parse(event.data);
  if (rpc.id) {
    // 响应处理
  } else {
    // Notification 处理（服务端主动推送）
  }
};
```

**典型应用**：Ethereum Web3、实时股票行情推送、在线游戏服务器

### 5.2 JSON-RPC over SSE（MCP 早期方案）

MCP 协议早期（2024-11-05 版本）采用此方案：

```
1. 客户端 GET /sse → 服务端建立 SSE 长连接，返回 endpoint URI
2. 客户端 POST {endpoint} → 发送 JSON-RPC 请求
3. 服务端通过 SSE 流推送 JSON-RPC 响应
```

```
// SSE 流中的 JSON-RPC 响应
event: message
data: {"jsonrpc":"2.0","result":{"tools":[...]},"id":1}

event: message
data: {"jsonrpc":"2.0","method":"notifications/progress","params":{"progress":50}}
```

### 5.3 JSON-RPC over Streamable HTTP（MCP 现行方案）

MCP 2025-03-26 版本采用：

```
// 简单调用 → 直接返回 JSON
POST /mcp
{"jsonrpc":"2.0","method":"tools/list","id":1}
→ HTTP 200 {"jsonrpc":"2.0","result":{...},"id":1}

// 长耗时调用 → 升级为 SSE 流
POST /mcp
{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search"},"id":2}
→ HTTP 200 Content-Type: text/event-stream
  data: {"jsonrpc":"2.0","method":"notifications/progress","params":{"progress":30}}
  data: {"jsonrpc":"2.0","result":{...},"id":2}
```

### 5.4 JSON-RPC over stdio（本地进程通信）

LSP（Language Server Protocol）和 MCP 本地模式的典型方案：

```
process.stdin  → JSON-RPC 请求（换行符分隔）
process.stdout ← JSON-RPC 响应（换行符分隔）
```

```bash
# 示例：向 LSP 服务发送初始化请求
echo '{"jsonrpc":"2.0","method":"initialize","params":{...},"id":0}' | lsp-server
```

---

## 6. 典型应用场景分析

### 6.1 Ethereum / 区块链节点 API

Ethereum 的 JSON-RPC API 是 JSON-RPC 应用的经典案例，运行在 HTTP 和 WebSocket 两种传输层上：

```json
// 查询账户余额
{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xAddress","latest"],"id":1}
{"jsonrpc":"2.0","result":"0x0234c8a3397aab58","id":1}

// 订阅新区块（WebSocket，服务端 Notification）
{"jsonrpc":"2.0","method":"eth_subscribe","params":["newHeads"],"id":1}
← {"jsonrpc":"2.0","result":"0x9cef478923ff08bf","id":1}  // 订阅 ID
← {"jsonrpc":"2.0","method":"eth_subscription","params":{"subscription":"0x9cef...","result":{...}}}
```

### 6.2 Language Server Protocol（LSP）

VS Code、JetBrains 等 IDE 使用 JSON-RPC over stdio 实现与语言服务器的通信：

```json
// 代码补全请求
{"jsonrpc":"2.0","method":"textDocument/completion","params":{"textDocument":{"uri":"file:///main.py"},"position":{"line":5,"character":3}},"id":10}

// 诊断通知（Notification，无 id）
{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"file:///main.py","diagnostics":[{"range":...,"severity":1,"message":"undefined variable"}]}}
```

### 6.3 AI 大模型流式生成（OpenAI Chat Completions）

OpenAI API 采用的是自定义流式方案（非标准 JSON-RPC），但体现了 Stream 通信的核心价值：

```
// HTTP POST with stream=true
POST /v1/chat/completions
{"model":"gpt-4","messages":[...],"stream":true}

// SSE 响应（每个 token 一个事件）
data: {"id":"chatcmpl-...","object":"chat.completion.chunk","choices":[{"delta":{"content":"Hello"}}]}
data: {"id":"chatcmpl-...","choices":[{"delta":{"content":" world"}}]}
data: [DONE]
```

### 6.4 MCP（Model Context Protocol）工具调用

MCP 是 JSON-RPC + Stream 组合的最新典型：

```json
// 工具发现（JSON-RPC 请求/响应）
→ {"jsonrpc":"2.0","method":"tools/list","id":1}
← {"jsonrpc":"2.0","result":{"tools":[{"name":"web_search","description":"..."}]},"id":1}

// 工具调用（可能升级为流式进度通知）
→ {"jsonrpc":"2.0","method":"tools/call","params":{"name":"web_search","arguments":{"query":"AI协议"}},"id":2}
← SSE: data: {"jsonrpc":"2.0","method":"notifications/progress","params":{"progressToken":"2","progress":0.5}}
← SSE: data: {"jsonrpc":"2.0","result":{"content":[{"type":"text","text":"..."}]},"id":2}
```

---

## 7. 选型决策树

```
你的通信需求是什么？
│
├── 简单方法调用，结果一次性返回
│   └── → JSON-RPC over HTTP（纯请求-响应）
│
├── 需要服务端主动推送事件（单向）
│   ├── 需要简单基础设施（CDN 友好）
│   │   └── → JSON-RPC over SSE 或 Streamable HTTP
│   └── 可以接受长连接
│       └── → SSE（HTTP+SSE）
│
├── 需要双向实时通信
│   ├── 延迟极其敏感（游戏、实时协作）
│   │   └── → WebSocket（+ JSON-RPC 消息格式）
│   └── 一般实时性需求
│       └── → Streamable HTTP 或 WebSocket
│
├── 需要流式输出（AI 生成、进度通知）
│   └── → Streamable HTTP（按需 SSE 升级）
│
└── 本地进程间通信（IDE 插件、本地工具）
    └── → JSON-RPC over stdio
```

---

## 8. 总结

### 核心结论

| 维度 | JSON-RPC | Stream 通信 |
|---|---|---|
| **本质** | 消息格式与调用语义规范 | 数据传输模式 |
| **交互模型** | 请求-响应（有 id 配对） | 持续数据流（无需配对） |
| **最大优势** | 语义清晰、错误标准化、批量调用 | 低延迟、增量结果、服务端主动推送 |
| **最大限制** | 不原生支持流式结果、服务端推送 | 连接资源消耗高、状态管理复杂 |
| **最佳组合** | JSON-RPC over Streamable HTTP | — |

### 关键洞见

1. **JSON-RPC 是语义层，Stream 是传输层**：二者正交，可以自由组合。不要将二者视为非此即彼的选择。

2. **AI 时代的协议趋势**：MCP、A2A 等新兴 AI 协议都采用"JSON-RPC 语义 + Stream 传输"的组合方案，体现了二者协同的最佳实践。

3. **Streamable HTTP 是现代最佳实践**：相比纯 SSE 或 WebSocket，Streamable HTTP 在基础设施兼容性、无状态性和渐进增强方面取得了最优平衡。

4. **Notification 是 JSON-RPC 的"单向流"近似**：通过 Notification（无 id 的请求），JSON-RPC 可以模拟单向事件推送，是在纯 JSON-RPC 语义内实现"流式"通知的方式。

5. **选型核心问题**：你是否需要**增量结果**？如果是，选 Stream；如果你的响应是完整的一次性结果，JSON-RPC over HTTP 足够。

---

## 参考资料

- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification) — JSON-RPC Working Group, 2010
- [MCP Transport Specification (2025-06-18)](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports) — Model Context Protocol
- [SSE vs Streamable HTTP: Why MCP Switched Transport Protocols](https://brightdata.com/blog/ai/sse-vs-streamable-http) — Bright Data, 2025
- [MCP Transport Options: stdio vs SSE vs WebSocket](https://www.grizzlypeaksoftware.com/library/mcp-transport-options-stdio-vs-sse-vs-websocket-decbjfzs) — Grizzly Peak Software
- [Ethereum JSON-RPC API](https://eips.ethereum.org/EIPS/eip-1474) — Ethereum Improvement Proposals
- [Language Server Protocol Specification](https://microsoft.github.io/language-server-protocol/) — Microsoft
