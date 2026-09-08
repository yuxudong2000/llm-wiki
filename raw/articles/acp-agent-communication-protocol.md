# Agent Communication Protocol (ACP) 深度调研

> 原始资料整理 | 调研时间：2026-09-07 | 作者：yuxudong

---

## 摘要

Agent Communication Protocol（ACP）是由 IBM Research 的 BeeAI 团队于 2025 年 3 月发布的开放标准，旨在解决 AI Agent 之间的跨框架、跨组织互通问题。ACP 以 REST-native 架构为基础，支持异步优先的通信模式，无需专用 SDK 即可集成。**2025 年 8 月，ACP 正式并入 Google 的 Agent-to-Agent（A2A）协议，在 Linux Foundation 的 LF AI & Data 基金会旗下统一演进；ACP 团队停止独立开发，将技术贡献转向 A2A。**

---

## 1. 背景：为什么需要 ACP？

### 1.1 AI Agent 的碎片化困境

随着 Agentic AI 的兴起，企业和开发者面临以下挑战：

- **框架多样性**：组织内部往往同时运行基于 LangChain、crewAI、AutoGen 等不同框架构建的数百乃至数千个 Agent
- **自定义集成爆炸**：没有统一协议时，开发者须为每对 Agent 交互编写定制连接器；n 个 Agent 系统潜在需要 n(n-1)/2 个集成点
- **跨组织难题**：不同的安全模型、认证系统和数据格式使跨公司集成更加复杂
- **脆弱集成**：现有点对点集成昂贵、脆弱、难以规模化扩展

### 1.2 ACP 的定位

ACP 是继 Model Context Protocol（MCP，解决"单模型 ↔ 多工具"）之后的下一步，专注于"多 Agent ↔ 多 Agent"的通信层：

| 协议 | 发起方 | 核心定位 |
|------|--------|---------|
| **MCP** | Anthropic | 单模型与工具/资源的上下文交互 |
| **ACP** | IBM BeeAI | 跨框架、跨组织的 Agent 间通信 |
| **A2A** | Google | Agent 间点对点任务协作（对标 ACP） |
| **ANP** | 社区 | 基于 DID 的去中心化 Agent 发现与协作 |

---

## 2. ACP 核心设计

### 2.1 关键特性

| 特性 | 描述 |
|------|------|
| **REST-based 通信** | 使用标准 HTTP 规范，相比 MCP 的 JSON-RPC 更易集成到生产环境 |
| **无需 SDK** | 可直接用 cURL、Postman 或浏览器与 Agent 交互；Python/TypeScript SDK 作为可选增强 |
| **离线发现（Offline Discovery）** | Agent 可将元数据嵌入发行包，即使离线也可被发现，支持 scale-to-zero 环境 |
| **异步优先，兼容同步** | 默认异步通信，适合长时任务；同样支持同步请求 |
| **多模态消息** | 通过 MIME Type 标识内容类型，支持文本、图片、音视频、二进制等任何格式 |

### 2.2 三层架构

```
┌─────────────────────────────────┐
│          Agent Client           │
│  发现 Agent、构建请求、处理响应   │
└─────────────┬───────────────────┘
              │ HTTP (REST)
┌─────────────▼───────────────────┐
│           ACP Server            │
│  维护 Agent Registry，负责认证、 │
│  授权、限流、路由                 │
└─────────────┬───────────────────┘
              │
┌─────────────▼───────────────────┐
│           ACP Agent             │
│  执行域特定逻辑，可有状态或无状态  │
└─────────────────────────────────┘
```

**Agent Client**：发起通信入口，通过注册表发现 Agent，将用户意图封装为多部分消息，处理返回的响应。

**ACP Server**：协议代理层，维护 Agent Registry（基于 Agent Detail Schema），执行系统级策略（认证、授权、限流），负责请求路由。

**ACP Agent**：执行端点，运行域特定逻辑，可以无状态微服务形式运行，也可维护会话上下文以支持多轮交互。

### 2.3 核心组件

#### Agent Detail
Agent 的自描述 JSON/YAML 文档，包含：
- Agent 名称与支持的操作
- 支持的内容类型（MIME types）
- 认证方案
- 运行时诊断信息

客户端依赖 Agent Detail 进行信任评估和 Agent 选择，无需逐个定制集成。

#### 发现机制（Discovery Mechanisms）
- **集中式**：注册表 API
- **去中心化**：`/.well-known/agent.yml` 等标准路径下的 manifest 文件，或容器标签中的元数据

#### 任务请求（Task Request）
结构化的工作委托单元，由有序的消息部分（message parts）组成，可包含：
- 文本输入
- 二进制载荷
- 外部数据引用

#### 消息结构（Message Structure）
标准化的通信信封，每条消息是有序的 part 列表，每个 part 包含：
- 显式的 `MIME content_type` 注解
- 嵌入内容（`content`）或可解引用的 URL（`content_url`）
- 可选的语义标签 `name`，支持命名 Artifacts

#### Artifacts
Agent 执行结果的封装体，可以是：
- 结构化 JSON 输出
- 纯文本响应
- 二进制文件
- 嵌套消息引用

---

## 3. Agent 生命周期

### 3.1 四阶段生命周期

| 阶段 | 内容 |
|------|------|
| **创建（Creation）** | 配置部署 Agent；通过 ASGI 或内置实现声明 Agent Detail；初始化认证机制和路由逻辑 |
| **运行（Operation）** | 处理 `sendTask` 请求；支持同步执行和流式中间结果；任务状态包括 `created`、`in_progress`、`awaiting`；多轮工作流保持会话持久性 |
| **更新（Update）** | 刷新 Agent Detail（新操作、MIME 类型、版本号）；客户端查询注册表获取最新 manifest，无需直接修改 API |
| **终止（Termination）** | 完成或终止所有活跃任务；关闭流连接；注销或标记 manifest 为非活跃；释放资源 |

---

## 4. ACP 与 MCP 的对比

### 4.1 设计差异

| 维度 | MCP | ACP |
|------|-----|-----|
| **通信协议** | JSON-RPC，需要专用 SDK | REST/HTTP，无需 SDK |
| **流式支持** | 基础流式（完整消息），不支持 delta 流 | 支持细粒度 delta 流（token 级、轨迹更新） |
| **消息结构** | 接受任意 JSON schema，不定义消息体结构 | 标准化 Message Structure，强制 MIME 类型 |
| **内存共享** | 不支持跨服务器多 Agent 共享内存 | 在开发路线图中 |
| **设计目标** | 工具增强（给模型更好的工具） | 团队协作（让 Agent 组成团队） |

**类比**：MCP 好比给一个人配备更好的工具（计算器、参考书），ACP 则是让多个人组成团队协作。

### 4.2 互补关系

ACP 和 MCP 并非竞争关系：
- **MCP**：Agent ↔ 工具（数据库、API、外部服务）
- **ACP**：Agent ↔ Agent（跨框架、跨组织）

在实际系统中，可以同时使用两者：编排 Agent 通过 ACP/A2A 向专业 Agent 委派任务，每个专业 Agent 再通过 MCP 访问所需工具。

---

## 5. ACP 与 A2A 的对比

ACP 和 Google 的 A2A 协议都针对 Agent 间通信，但存在设计理念和治理差异：

| 维度 | ACP | A2A |
|------|-----|-----|
| **发起方** | IBM BeeAI | Google |
| **协议基础** | REST-native，HTTP | JSON-RPC 2.0 + HTTP/gRPC/REST |
| **治理** | Linux Foundation（后并入 A2A） | Linux Foundation（Google 捐献） |
| **生态偏向** | 厂商中立、通用互通 | 优化 Google 生态的集成体验 |
| **SDK 依赖** | 无需 SDK，可选 Python/TypeScript | 有官方 SDK |

---

## 6. 实践：最小化 ACP Agent 实现

使用 Python SDK，几行代码即可创建符合 ACP 规范的 Agent：

```python
from typing import Annotated
import os
from typing_extensions import TypedDict
from dotenv import load_dotenv
# ACP SDK
from acp_sdk.models import Message
from acp_sdk.models.models import MessagePart
from acp_sdk.server import RunYield, RunYieldResume, Server
from collections.abc import AsyncGenerator
# LangChain SDK
from langgraph.graph.message import add_messages
from langchain_anthropic import ChatAnthropic

load_dotenv()

class State(TypedDict):
    messages: Annotated[list, add_messages]

llm = ChatAnthropic(
    model="claude-3-5-sonnet-latest",
    api_key=os.environ.get("ANTHROPIC_API_KEY")
)

# ---- ACP 核心部分 ----
server = Server()

@server.agent()
async def chatbot(messages: list[Message]) -> AsyncGenerator[RunYield, RunYieldResume]:
    """A simple chatbot enabled with memory"""
    # 将 ACP Message 格式转换为 LangChain 期望格式
    query = " ".join(
        part.content
        for m in messages
        for part in m.parts
    )
    llm_response = llm.invoke(query)
    assistant_message = Message(parts=[MessagePart(content=llm_response.content)])
    yield {"messages": [assistant_message]}

server.run()
# ----------------------
```

这个最小实现创建了一个完全符合 ACP 规范的 Agent，它能够：
- 被其他 Agent 在线或离线发现
- 同步或异步处理请求
- 使用标准消息格式通信
- 与任何 ACP 兼容系统集成

---

## 7. 真实世界案例

**制造商 + 物流商跨组织协作场景**：

- 制造商拥有管理生产计划的自治 Agent
- 物流商拥有提供实时运输报价的 Agent

**无 ACP 时**：需要构建定制集成，处理认证、数据格式不匹配和服务可用性问题；随着合作伙伴增多，集成成本指数级上升。

**有 ACP 时**：每个组织将 Agent 包装 ACP 接口。制造商 Agent 向物流 Agent 发送订单和目的地详情，物流 Agent 返回实时运输选项和 ETA。双方无需暴露内部实现，也无需编写定制集成；引入新物流合作伙伴只需实现 ACP 接口。

---

## 8. 安全考量

ACP 生命周期的各阶段均存在特定安全挑战：

### 注册阶段
- **风险**：未授权的 Agent 注册、元数据伪造
- **缓解**：强制认证注册请求、签名 Agent Detail manifest

### 运行阶段
- **风险**：任务注入（Task Injection）、会话劫持、越权执行
- **缓解**：输入验证、OAuth 2.0 令牌绑定、最小权限原则

### 发现阶段
- **风险**：Agent Card 投毒（类似 A2A 的 AgentCard 攻击面）
- **缓解**：签名验证、manifest 完整性校验

---

## 9. ACP 并入 A2A：历史转折（2025 年 8 月）

### 时间线

| 时间 | 事件 |
|------|------|
| 2025 年 3 月 | IBM Research 发布 ACP，作为 BeeAI 平台通信层 |
| 2025 年 6 月 23 日 | Google 将 A2A 协议捐献给 Linux Foundation，AWS、Cisco、Microsoft 等为创始成员 |
| 2025 年 8 月 29 日 | LF AI & Data 宣布 ACP 并入 A2A，ACP 团队停止独立开发 |
| 2025 年 8 月以后 | ACP 技术和专长持续向 A2A 贡献；用户被建议迁移到 A2A |

### 合并原因

ACP 与 A2A 在核心目标（Agent 间通信）上高度重叠。考虑到：
1. A2A 已经过渡到厂商中立治理（非 Google 独有）
2. 合并后的 A2A 已涵盖 ACP 的主要能力
3. 统一标准有利于整个生态系统

ACP 团队选择贡献力量而非与 A2A 竞争，这是成熟的开源协作精神体现。

### 迁移建议

> **⚠️ 重要提示**：ACP 已不再独立维护。  
> - 现有 ACP 用户应参考官方迁移指南迁移到 A2A  
> - 2026 年起，Agent 间通信的主流标准是 A2A  
> - A2A 的架构与 ACP 高度相似，迁移成本相对可控

---

## 10. 四协议横向对比（MCP / ACP / A2A / ANP）

| 维度 | MCP | ACP | A2A | ANP |
|------|-----|-----|-----|-----|
| **发起方** | Anthropic | IBM BeeAI | Google | 社区 |
| **核心场景** | 模型 ↔ 工具/资源 | Agent ↔ Agent（本地/企业） | Agent ↔ Agent（企业规模） | Agent ↔ Agent（开放互联网） |
| **通信协议** | JSON-RPC 2.0 | REST/HTTP | JSON-RPC + HTTP/gRPC | HTTP(S) + JSON-LD |
| **身份机制** | OAuth 2.0（2025 后强制） | OAuth/JWT | OAuth 2.0（OpenAPI schema） | DID（W3C 去中心化标识符） |
| **发现方式** | 直连（stdio/SSE） | Registry + well-known URL | AgentCard（.well-known） | ADP（/.well-known/agent-descriptions） |
| **流式支持** | SSE（基础流） | SSE（delta 流） | SSE | SSE / 长轮询 |
| **治理** | Linux Foundation（AAF） | 已并入 A2A | Linux Foundation | 开源社区 |
| **当前状态** | 稳定，持续演进 | 已停止独立维护 | 主流，持续演进 | 早期阶段 |

### 分阶段采用路线图

基于协议成熟度和集成复杂性，推荐如下分阶段路线：

1. **第一阶段 - MCP**：建立模型与工具的标准化交互（JSON-RPC，类型化工具调用）
2. **第二阶段 - ACP/A2A**：扩展到 Agent 间异步多模态通信
3. **第三阶段 - A2A 企业规模**：通过 AgentCard 实现动态能力发现和跨组织任务编排
4. **第四阶段 - ANP**：扩展到开放互联网，支持去中心化 Agent 市场

---

## 11. ACP 的历史意义

尽管 ACP 已并入 A2A，它仍具有重要的历史意义：

1. **验证了 REST-native Agent 协议的可行性**：相比 MCP 的 JSON-RPC，更贴近 Web 惯例
2. **推动了行业标准化进程**：ACP 和 A2A 的竞争加速了双方合并和 Linux Foundation 的统一治理
3. **贡献了关键设计理念**：异步优先、离线发现、无 SDK 依赖等理念都被 A2A 继承
4. **建立了 BeeAI 生态**：BeeAI 平台作为 ACP 参考实现，目前仍作为 Agent 编排工具存在

---

## 参考资料

1. IBM Think: [What is Agent Communication Protocol (ACP)?](https://www.ibm.com/think/topics/agent-communication-protocol)
2. 官方文档: [Agent Communication Protocol - Welcome](https://agentcommunicationprotocol.dev/introduction/welcome)
3. IBM Research: [Agent Communication Protocol (ACP) Project Page](https://research.ibm.com/projects/agent-communication-protocol)
4. Zuplo Blog: [MCP, A2A, and Where ACP Went](https://zuplo.com/blog/agent-protocol-stack-mcp-a2a-acp-2026) (2026-07-03)
5. LF AI & Data: [ACP Joins Forces with A2A](https://lfaidata.foundation/communityblog/2025/08/29/acp-joins-forces-with-a2a-under-the-linux-foundations-lf-ai-data/) (2025-08-29)
6. arXiv: [A Survey of Agent Interoperability Protocols: MCP, ACP, A2A, and ANP](https://arxiv.org/html/2505.02279v1) (2025-05-04)
7. GitHub: [i-am-bee/acp](https://github.com/i-am-bee/acp)
8. BeeAI Migration Guide: [ACP to A2A Migration](https://github.com/i-am-bee/beeai-platform/blob/main/docs/community-and-support/acp-a2a-migration-guide.mdx)
