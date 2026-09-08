# Agent Network Protocol (ANP) 深度调研

> 原始资料整理 | 调研时间：2026-09-07 | 作者：yuxudong

---

## 摘要

Agent Network Protocol（ANP）是一个专为**开放互联网 Agent 网络**设计的去中心化通信协议框架。与 A2A（企业内部横向协调）、MCP（工具垂直整合）不同，ANP 的目标是成为 **Agent 互联网时代的 HTTP**——让任意两个来自不同平台、不同组织的 Agent 无需可信中间方即可互相认证和通信。ANP 白皮书于 2025 年 7 月发布，目前处于规范制定阶段（v1.1），MIT License，GitHub 开源。项目由 GaoWei Chang 主导，属于 AAIF（Agentic AI Foundation）生态协议栈的全局发现层。

---

## 1. 背景与设计动机

### 1.1 现有互联网基础设施的三个缺口

ANP 白皮书指出，虽然现有互联网基础设施已相当成熟，但对 Agent 网络存在三个根本性不足：

1. **数据孤岛**：Agent 需要完整的用户信息上下文才能做出准确决策，但现有互联网将用户数据分散在不同平台，导致 Agent 决策能力受限
2. **界面向人设计**：现有互联网应用以图形界面为主，Agent 更擅长直接通过协议或 API 处理底层数据，GUI 不仅提高开发成本，还降低处理效率
3. **缺乏 Agent 原生通信**：Agent 天然具备用自然语言进行网络连接和协商的能力，可以通过自组织、自协作实现更个性化和高效的通信——但现有基础设施不支持这种模式

### 1.2 ANP vs 其他协议的定位分工

```
MCP    → Agent ↔ 工具/资源    （单 Agent 纵向扩展）
A2A    → Agent ↔ Agent        （企业内/跨组织横向协调）
ANP    → Agent ↔ 互联网       （全球开放网络，去中心化发现与互信）
```

三者在 AAIF 生态中互补而非竞争：MCP 解决工具接入，A2A 解决协作调用，ANP 解决身份互信与全局发现。

### 1.3 核心愿景

> "ANP 的目标是成为 Agent 互联网时代的 HTTP。"

就像 HTTP 让任何网站都可以被任何浏览器访问，ANP 希望让任何 Agent 都可以被任何其他 Agent 发现、认证并调用——无需可信中间方，无需预先建立信任关系。

---

## 2. 三层协议架构

ANP 采用分层设计，各层独立演进，实现者可按需采用：

```
┌────────────────────────────────────────────────────────┐
│              域协议层（Domain Protocols）                 │
│   支付、授权、认证、商务及其他领域特定协议                  │
├────────────────────────────────────────────────────────┤
│              应用协议层（Application Protocol Layer）     │
│   Agent 描述协议 + Agent 发现协议                        │
│   消息规格（P1-P9）：直接消息/群消息/E2EE/附件/联邦        │
├────────────────────────────────────────────────────────┤
│              元协议层（Meta-Protocol Layer）              │
│   Agent 间通信协议协商 + AI 代码生成 + 联调              │
├────────────────────────────────────────────────────────┤
│              身份与加密通信层（Identity Layer）            │
│   DID:WBA + WNS + 认证 + 密钥分发 + 安全消息             │
├────────────────────────────────────────────────────────┤
│              底层：开放互联网基础设施                       │
│   HTTP、CA、DNS、CDN、Search、TLS、既有 Web 部署模式      │
└────────────────────────────────────────────────────────┘
```

---

## 3. 第一层：身份与加密通信层

### 3.1 核心问题：跨平台身份认证

现有互联网主要使用中心化身份技术，不同技术实现使得跨系统账户难以互相认证。OAuth 2.0 虽有所缓解，但并非专为跨系统认证设计，流程复杂，去中心化程度不足。

ANP 的解法是引入 **W3C DID（去中心化标识符）标准**：

- DID 是新型标识符标准，允许用户控制自己的身份，无需依赖中心化系统即可互相认证
- DID 核心规范不要求使用特定计算基础设施，可充分利用现有成熟技术和 Web 基础设施
- 各类标识符系统只需在现有基础上创建 DID，即可实现跨系统互操作

### 3.2 did:wba 方法

ANP 基于 W3C 的 `did:web` 方法，提出了专为 Agent 通信场景设计的新 DID 方法：**`did:wba`（Web-Based Agent）**。

`did:wba` 在 `did:web` 的基础上，额外增加了：
- 跨平台身份认证流程
- Agent 描述服务

每个 Agent 有一个 DID Document（文档），托管在其 HTTPS 域名的固定路径下，包含：
- 身份验证方法（公钥）
- `humanAuthorization` 专用验证方法（区分人类授权与 Agent 自动授权）
- Agent 描述服务端点

**DID 认证时序**：

```
首次请求：
    Agent A 客户端  ──[HTTP + DID + 签名]──►  Agent B 服务端
                                               │
                    ◄──[获取 DID Document]──    │
         Agent A DID 服务器                     │
                    ──[DID Document]──►          │
                                       ◄──[验证签名]
                                               │
    Agent A 客户端  ◄──[HTTP Response + token]── Agent B 服务端

后续请求（直接使用 token，无需重复验证）：
    Agent A 客户端  ──[HTTP + token]──►  Agent B 服务端
                    ◄──[HTTP Response]──
```

**核心优势**：首次请求中无需额外交互即可完成身份认证，验证后颁发 token 供后续使用，整体流程简洁高效。

### 3.3 端到端加密

基于 DID 公私钥对，ANP 使用 **ECDHE（Elliptic Curve Diffie-Hellman Ephemeral）协议**设计端到端加密通信方案，确保中间节点无法解密通信内容。

### 3.4 humanAuthorization 机制

DID Document 中引入专用验证方法 `humanAuthorization`，区分两类操作：

| 操作类型 | 风险级别 | 授权方式 |
|---------|---------|---------|
| 查询公开信息 | 低 | Agent 自动代理用户授权 |
| 涉及隐私或财产的操作（如支付） | 高 | 必须获得人类显式授权 |

当 Agent 发起高风险请求时，需先向人类用户请求确认并获得签名授权，再执行操作。

### 3.5 多 DID 隐私保护策略

ANP 推荐多 DID 策略：
- **主 DID**：相对稳定，用于长期社会关系
- **子 DID**：为不同应用场景生成（购物、点餐等），各有不同角色和权限
- 定期停用过期子 DID，申请新 DID，防止跨平台追踪

---

## 4. 第二层：元协议层（Meta-Protocol Layer）

元协议层是 ANP 最具创新性的部分，解决的是**两个之前从未通信过的 Agent，如何动态协商出双方都能处理的通信协议**。

### 4.1 现有 Agent 通信的两个痛点

| 方法 | 问题 |
|------|------|
| 人类工程师设计通信协议 | 开发成本高、协议更新迭代慢、难以适配新场景 |
| Agent 直接用自然语言通信 | 数据处理成本高、处理精度低（LLM 推理每次都有成本）|

### 4.2 元协议通信的六步流程

```
步骤 1：元协议请求
    Agent A 发送元协议请求到 Agent B
    请求体用自然语言描述：需求、输入、期望输出、候选通信协议

步骤 2：协议协商
    Agent B 用 AI 处理请求，结合自身能力决策：
    - 无法满足 → 直接拒绝
    - 不接受候选协议 → 提出自己的候选协议，进入下一轮协商
    - 接受 → 进入步骤 3

步骤 3：代码生成与部署
    双方基于协商好的协议，各自生成协议处理代码并部署

步骤 4：联调
    双方协商测试数据，对协议和 AI 生成代码进行联合调试

步骤 5：正式通信
    联调完成后协议上线，Agent A 和 B 使用协商好的协议通信

步骤 6：需求变更处理
    需求变化时重复上述流程，直到双方再次达成协议
```

### 4.3 协商结果缓存与复用

元协议协商耗时且依赖 AI 代码生成能力，若每次通信都进行协商成本极高。ANP 的应对机制：

- Agent 保存元协议协商结果，相似需求出现时直接复用
- Agent 可以共享协商结果，供其他 Agent 查询使用
- **长期愿景**：类 PyPI 的协议服务平台，集中管理应用层协议供 Agent 搜索、下载和使用

### 4.4 元协议的本质价值

> 元协议是"协议的协议"——它不直接处理数据传输，而是提供一个弹性、通用、可扩展的通信框架，让 Agent 能够为具体任务自主协商出最优协议，而不必受限于预先定义的固定协议格式。

---

## 5. 第三层：应用协议层

应用协议层的目标是**在大多数场景下避免元协议协商**，通过标准化的协议描述和管理，直接实现高效通信。

### 5.1 Agent 能力描述规范

ANP 使用语义 Web 标准描述 Agent 能力：

- **RDF（Resource Description Framework）**：通用知识表示
- **JSON-LD（JSON Linked Data）**：JSON 格式的语义数据，兼容 Schema.org
- **Schema.org 词汇**：标准化的语义描述词汇

这些技术的复用确保了两个 Agent 对交换数据的含义理解一致——不只是知道数据的**结构**，还知道数据的**语义**。

### 5.2 Agent Description 示例

```json
{
  "@context": "https://schema.org",
  "@type": "WebAPI",
  "name": "Travel Booking Agent",
  "description": "Books flights, hotels, and car rentals across 500+ providers",
  "url": "https://travel-agent.example.com/.well-known/agent.json",
  "serviceType": "travel-booking",
  "availableChannel": {
    "@type": "ServiceChannel",
    "serviceUrl": "https://travel-agent.example.com/api",
    "serviceType": "REST"
  },
  "identifier": {
    "@type": "PropertyValue",
    "propertyID": "did",
    "value": "did:wba:travel-agent.example.com:agents:booking"
  }
}
```

### 5.3 应用协议管理规范

每个应用协议文档包含：

- **协议版本**：版本迭代信息
- **功能描述**：协议功能、适用场景和预期效果
- **输入输出数据格式**：格式、类型和约束
- **协议处理流程**：步骤、顺序和逻辑关系
- **可信 DID 签名的协议代码**：请求方发起请求和响应方处理请求的代码，确保安全可信

应用协议的来源可以是：
1. 人类专家/行业组织定义的标准协议
2. Agent 通过元协议协商达成的共识协议
3. 两个 Agent 之间的个性化协议

### 5.4 Agent 调用服务的四步流程

```
1. 能力发现（Capability Discovery）
   Agent A 通过搜索或查询服务发现 Agent B 具备所需能力

2. 协议匹配（Protocol Matching）
   A 查阅 B 的能力描述文档，确定可用的通信协议

3. 协议加载（Protocol Loading）
   A 通过协议服务平台加载对应的协议处理代码

4. 通信执行（Communication Execution）
   A 使用加载的协议代码与 B 按规定流程通信
```

---

## 6. 发现机制：搜索引擎模型

ANP 的发现机制与 A2A 的 AgentCard 拉取式有本质区别：

### 6.1 三种协议的发现机制对比

| 协议 | 发现模式 | 类比 |
|------|---------|------|
| **A2A** | 拉取式：知道 URL → 请求 `/.well-known/agent-card.json` | DNS：知道域名才能访问 |
| **ACP** | 注册式：Agent 向中心化目录服务注册 | 黄页：主动登记，被动查询 |
| **ANP** | 索引式：Agent 发布描述文档 → 被 Agent 搜索引擎索引 | Google Search：发布内容，等待被搜索 |

### 6.2 ANP 的搜索引擎模型

```
Agent 发布
    │  Agent 将能力描述文档（JSON-LD）发布到 HTTPS URL
    │  did:wba DID Document 中包含描述文档的端点
    ▼
搜索引擎索引
    │  专业 Agent 搜索引擎爬取并索引这些描述文档
    │  （类似 Google 爬取网页）
    ▼
被发现
    │  其他 Agent 通过自然语言查询搜索引擎
    │  得到符合条件的 Agent 列表及其 DID
    ▼
发起通信
       使用 did:wba 完成身份验证，建立安全连接
```

**优势**：最具互联网规模的扩展性，任何 Agent 可以被任何其他 Agent 发现，无需预先配置
**现状**：Agent 搜索引擎基础设施尚未大规模存在，是 ANP 生态的重要缺口

---

## 7. 消息规格（Messaging Profiles）

ANP 1.1 将消息能力拆分为 P1-P9 个专项规格，按需实现：

| 规格编号 | 功能 | 说明 |
|---------|------|------|
| P1 | 直接消息（Direct Messaging） | 点对点的基础消息传输 |
| P2 | 群消息（Group Messaging） | 多 Agent 群组通信 |
| P3 | 端到端加密（E2EE） | 基于 DID 密钥对的端到端加密 |
| P4 | 附件（Attachments） | 文件、二进制数据的传输 |
| P5-P9 | 联邦（Federation）等 | 跨域通信、消息路由等扩展能力 |

---

## 8. ANP Agent Description vs A2A Agent Card：深度对比

ANP 的 Agent Description 和 A2A 的 Agent Card 表面上都是"把 Agent 能力发布到某个位置等待拉取"，但两者的设计目标、信任模型和数据语义存在根本差异。

### 8.1 核心区别一句话总结

> **A2A Agent Card** 是企业局域网里的**工牌**——已经认识你才需要看，格式固定，按规范调用。
>
> **ANP Agent Description** 是互联网上的**公开档案**——陌生人也能找到你、理解你、甚至与你协商出新的合作方式，且身份由密码学保证而非 DNS 体系。

### 8.2 逐维度详细对比

#### 维度一：数据格式——结构 vs 语义

**A2A Agent Card**（A2A 私有 schema 的结构化 JSON）：
```json
{
  "name": "Billing Agent",
  "skills": [{ "id": "refund", "description": "Issues refunds" }],
  "supportedInterfaces": [{ "protocolBinding": "JSONRPC", "url": "..." }]
}
```
解读这个 JSON 需要懂 A2A 规范——`skills`、`supportedInterfaces` 都是 A2A 特有字段名，不认识 A2A 规范的系统无法自主理解它的含义。

**ANP Agent Description**（JSON-LD，复用 Schema.org 标准词汇）：
```json
{
  "@context": "https://schema.org",
  "@type": "WebAPI",
  "name": "Billing Agent",
  "description": "Issues refunds and manages invoices",
  "serviceType": "billing"
}
```
`@type: WebAPI`、`serviceType` 是 Schema.org 标准词汇——**任何理解语义 Web 的系统都能解读它**，不需要懂 ANP 规范。这使得 Agent 搜索引擎可以用语义理解来匹配，而不是字符串匹配 skill id。

#### 维度二：发现方式——已知 URL 拉取 vs 语义搜索

| | A2A Agent Card | ANP Agent Description |
|--|--|--|
| 前提条件 | **必须已知对方域名**（带外获取） | **不需要预知**，通过 Agent 搜索引擎发现 |
| 发现机制 | 拉取：`GET /.well-known/agent-card.json` | 索引：描述文档被爬取、语义索引、搜索匹配 |
| 类比 | 你知道 `taobao.com`，直接访问 | 你在 Google 搜"买东西的网站"，发现淘宝 |
| 适用范围 | 已知协作伙伴（企业内部/预配置合作方） | 开放互联网上的陌生 Agent |

这是两者**最根本**的区别：A2A 的发现依赖带外知识（预先配置域名），ANP 的目标是真正的"零先验知识发现"。

#### 维度三：身份绑定——HTTPS 域名 vs 密码学身份

**A2A**：Card 的可信度来自"HTTPS 域名被你信任"——你信任 `billing.example.com` 这个域名，所以你信任从这里拿到的 Card。如果域名被劫持或 CA 证书被伪造，Card 可以被替换。

**ANP**：Description 与 `did:wba` 密码学身份绑定：
```
DID Document（包含公钥，由私钥签名） → 指向 Agent Description
读取方验证描述文档的签名 → 确认它确实由该 DID 的私钥持有者发布
```
即使 HTTPS 证书被攻击，没有私钥就无法伪造 Description。**身份所有权可以被密码学证明**，而不是依赖 DNS/CA 体系的信任。

#### 维度四：协议描述的层次——固定接口 vs 协商能力

**A2A Agent Card** 声明的是**固定接口**：
- "我支持 JSON-RPC 2.0 接口，在这个 URL"
- "我的 skill 是 refund 和 invoice"
- 调用者按照这个规格调用，没有协商空间

**ANP Agent Description** 声明的是**协商能力**：
- "我支持这些协议格式（A2A / ACP / 自定义）"
- "如果你不支持我声明的协议，可以通过元协议跟我协商一个新的"
- 相当于不只告诉你"我在几号窗口办理业务"，还告诉你"如果那个窗口不合适，我们可以谈"

### 8.3 一图总结

```
A2A Agent Card                     ANP Agent Description
─────────────────────────          ─────────────────────────────
格式：A2A 私有 schema               格式：JSON-LD + Schema.org 语义
发现：需预知域名，主动拉取             发现：搜索引擎索引，零先验发现
信任：HTTPS 证书（DNS/CA 体系）       信任：DID 密码学（私钥签名）
协议：固定 JSON-RPC/gRPC/REST        协议：可协商（元协议层）
目标环境：企业内网/预配置合作方         目标环境：开放互联网
```

### 8.4 互补而非竞争

ANP Agent Description 可以在 `availableChannel` 中声明"我也支持 A2A 协议"——通过 ANP 搜索引擎发现某个 Agent 后，直接用 A2A 协议调用它。这正是 ANP 元协议层设计为"协议基底"的意义：ANP 负责发现和身份，A2A 负责具体的任务协作通信，两者可以叠加使用。

---

## 9. 与其他协议的全面对比

## 9. ANP vs A2A vs ACP vs Matrix

| 维度 | A2A | ACP | ANP | Matrix/HiClaw |
|------|-----|-----|-----|--------------|
| **传输** | HTTP/JSON-RPC | HTTP/REST | HTTPS/JSON-LD | Matrix Sync API |
| **发现** | AgentCard（URL 拉取） | 中心化注册表 | DID + 搜索引擎 | Room 目录 |
| **身份认证** | OAuth 2.0 / mTLS | Bearer Token + mTLS | W3C DID（无中心机构） | Matrix Auth + E2EE |
| **联邦** | URL 可达 | 注册表范围 | 互联网原生 | Homeserver 联邦 |
| **在线状态** | 无（仅 Task 状态） | 无 | Agent 描述中声明 | 内置 |
| **数据语义** | 结构化 JSON | MIME 多部分 | JSON-LD + Schema.org | 任意事件类型 |
| **成熟度** | 生产就绪 | 生产就绪 | 规范制定阶段 | 生产级（HiClaw） |
| **采用规模** | 100+ 企业 | 75+ AGNTCY 成员 | 早期采用者 | 阿里巴巴生态 |

### 9.2 ANP 的核心差异化：Agent 通过 DID 密钥对互相验证，无需信任任何中介——这是其他协议都不具备的属性。

**最高的协议灵活性**：元协议层允许两个 Agent 为特定任务协商出专属协议，而不是被迫使用统一的 JSON-RPC 或 REST 格式。

**最大的互联网规模潜力**：基于搜索引擎模型的发现机制，理论上支持全球数十亿 Agent 的互联。

**最高的实现复杂度**：需要 DID 基础设施（目前尚不成熟）+ 元协议协商开销 + Agent 搜索引擎生态，工程实现难度远高于 A2A。

---

## 10. did:wba 认证机制深度解析

### 9.1 DID Document 结构

```json
{
  "@context": ["https://www.w3.org/ns/did/v1"],
  "id": "did:wba:example.com:agents:assistant",
  "verificationMethod": [
    {
      "id": "did:wba:example.com:agents:assistant#key-1",
      "type": "EcdsaSecp256k1VerificationKey2019",
      "controller": "did:wba:example.com:agents:assistant",
      "publicKeyJwk": { "kty": "EC", "crv": "secp256k1", ... }
    },
    {
      "id": "did:wba:example.com:agents:assistant#human-auth",
      "type": "HumanAuthorization",
      "controller": "did:wba:example.com:agents:assistant"
    }
  ],
  "authentication": ["#key-1"],
  "humanAuthorization": ["#human-auth"],
  "service": [
    {
      "id": "#agent-description",
      "type": "AgentDescription",
      "serviceEndpoint": "https://example.com/agents/assistant/description.json"
    }
  ]
}
```

### 9.2 认证流程的技术细节

1. **Agent A** 生成请求签名：用私钥对请求内容签名，将 `DID` 和签名放入 HTTP Header
2. **Agent B 服务端** 收到请求后：
   - 解析 HTTP Header 中的 DID
   - 向 Agent A 的 DID Server 请求 DID Document
   - 从 DID Document 中获取公钥
   - 验证签名
3. **验证通过**：B 返回 token，后续请求直接携带 token，无需重复验证

**关键设计**：整个首次认证在**一个 HTTP 来回**内完成（不引入额外握手），大幅降低初始连接开销。

---

## 11. 安全机制

### 11.1 核心安全设计

| 机制 | 实现方式 |
|------|---------|
| **身份不可伪造** | 私钥由 Agent 本地持有，DID Document 中只有公钥 |
| **通信内容不可窃听** | ECDHE 端到端加密，中间节点无法解密 |
| **人机权限分离** | `humanAuthorization` 方法区分高/低风险操作 |
| **身份隐私** | 多 DID 策略，不同场景使用不同子 DID |
| **协议代码可信** | 应用协议代码由可信 DID 签名，防止篡改 |

### 11.2 与 A2A 安全机制的比较

| 安全属性 | A2A | ANP |
|---------|-----|-----|
| 跨组织身份互信 | 需要预先建立 OAuth 信任关系 | 无需预先关系，DID 即身份 |
| 无中介认证 | 不支持（依赖 OAuth 授权服务器） | 支持（DID 自证身份） |
| 端到端加密 | 不支持（依赖 TLS 传输加密） | 支持（ECDHE 应用层加密） |
| 人机权限分离 | 规范未定义 | `humanAuthorization` 内置支持 |

---

## 12. 当前状态与局限

### 12.1 成熟度评估（2026 年）

| 方面 | 状态 |
|------|------|
| 规范文档 | ANP 1.1 发布，技术白皮书完整 |
| 参考实现 | 早期阶段，MIT License 开源 |
| SDK/工具链 | 匮乏，显著落后于 A2A 和 ACP |
| W3C DID 基础设施 | 尚不成熟，是最大的外部依赖风险 |
| Agent 搜索引擎生态 | 基本不存在，是最大的生态缺口 |
| 企业采用 | 早期采用者，无规模化部署案例 |

### 12.2 关键挑战

**元协议协商开销**：每次与新 Agent 首次通信都需要协商，虽然有缓存机制，但初始开销仍显著高于 A2A。

**DID 基础设施依赖**：W3C DID 标准虽已发布，但其基础设施（DID Resolver、DID Registry 等）尚不成熟，生产级实现复杂。

**Agent 搜索引擎缺失**：搜索引擎模型的发现机制是 ANP 最核心的创新，但相应的"Agent 搜索引擎"基础设施目前几乎不存在。

**AI 代码生成依赖**：元协议层的协议代码生成需要高质量的 AI 代码生成能力，当前 AI 的稳定性和安全性尚不足以支撑生产环境自动代码部署。

**经济激励缺失**：如何激励 Agent 主动上传元协议协商结果，ANP 白皮书明确承认这仍是未解决的问题。

---

## 13. 协议栈全景：四协议分层模型

```
全球互联网 Agent 网络（ANP 层）
    ├── 任意两个 Agent 的去中心化发现与身份互信
    └── 跨互联网的开放协作
          │
          ▼
跨组织 Agent 协调（A2A 层）
    ├── 企业间 Agent 互操作
    └── 基于 AgentCard 的能力发现与任务委派
          │
          ▼
单 Agent 工具整合（MCP 层）
    ├── 连接数据库、API、文件系统
    └── Agent 自身能力的垂直扩展
          │
          ▼
AI 模型能力（LLM 层）
    └── 推理、生成、理解
```

| 层次 | 协议 | 解决的问题 | 当前状态 |
|------|------|----------|---------|
| **全球网络层** | ANP | 任意 Agent 的去中心化互信与发现 | 规范阶段 |
| **企业协作层** | A2A | 跨框架/跨组织的 Agent 任务协作 | 生产就绪 |
| **工具接入层** | MCP | 单 Agent 连接工具和资源 | 生产就绪 |

---

## 14. 路线图与未来方向

### 已在规范中的（ANP 1.1）

- **WNS（Agent Name Service）**：类似 DNS 的 Agent 命名服务，`did:wba` 方法已支持
- **消息规格 P1-P9**：分步完善各类消息传输场景
- **支付协议（Agent Payment）**：域协议层中的支付能力
- **跨域联邦消息**：不同平台/组织 Agent 之间的消息路由

### 未来研究方向

- **区块链在 Agent 网络中的应用**：ANP 白皮书指出，随着区块链技术成熟，其去中心化特性和内置金融属性可能成为 Agent 网络的理想基础设施
- **Agent 搜索引擎**：构建支持语义搜索的全球 Agent 目录
- **元协议经济激励**：如何激励 Agent 上传和共享协商结果
- **底层通信协议优化**：HTTP 是否是 Agent 间通信的最优选择？是否有专为 Agent 数据交换优化的协议？

---

## 15. 实践建议

### 何时考虑 ANP

- 需要跨组织身份互信，且无法预先建立 OAuth 信任关系
- 构建面向开放互联网的 Agent 服务，希望任何 Agent 都能发现和调用
- 对端到端加密有强需求（传输层 TLS 不满足）
- 构建长远的去中心化 Agent 平台基础设施

### 当前不建议 ANP 的场景

- 需要立即上生产的系统（工具链和基础设施尚不成熟）
- 企业内部 Agent 协调（A2A 更合适）
- Agent 连接工具和 API（MCP 更合适）
- 对实现复杂度有严格限制

### 观察信号：何时 ANP 会成熟

1. W3C DID 基础设施（特别是 `did:wba` DID Resolver）进入生产级
2. 主流 Agent 框架（LangChain、AutoGen 等）提供 ANP SDK
3. 出现一个或多个广泛使用的 Agent 搜索引擎
4. AAIF 宣布推动 A2A 和 ANP 的互操作标准

---

## 参考资料

1. ANP Official Site: [agent-network-protocol.com](https://www.agent-network-protocol.com/)
2. ANP Technical White Paper: [agentnetworkprotocol.com/en/specs/01-agentnetworkprotocol-technical-white-paper](https://agentnetworkprotocol.com/en/specs/01-agentnetworkprotocol-technical-white-paper) (2025-07)
3. ANP Technical Specifications: [agentnetworkprotocol.com/en/specs/](https://agentnetworkprotocol.com/en/specs/)
4. GitHub: [agent-network-protocol/AgentNetworkProtocol](https://github.com/agent-network-protocol/AgentNetworkProtocol)
5. arXiv Survey: [A Survey of Agent Interoperability Protocols: MCP, ACP, A2A, and ANP](https://arxiv.org/html/2505.02279v1) (2025-05-04)
6. Zylos AI Research: [The Protocol Layer: Comparing Communication Standards for AI Agent Interoperability](https://zylos.ai/research/2026-03-05-multi-agent-communication-protocols-comparison/) (2026-03-05)
7. arXiv: [Governance Gaps in Agent Interoperability Protocols](https://arxiv.org/html/2606.31498v1) (2026-06-30)
8. ANP Blog: [ANP Message协议重大升级：为Agent协作而设计的协议](https://agent-network-protocol.com/zh/blogs/posts/anp-message-protocol-upgrade) (2026-06-27)
9. ANP Blog: [智能体互联网的三大趋势：连接范式正在彻底重构](https://agent-network-protocol.com/zh/blogs/posts/three-major-trends-internet-of-agents) (2026-06-27)
10. W3C DID Core Specification: [w3.org/TR/did-core/](https://www.w3.org/TR/did-core/)
