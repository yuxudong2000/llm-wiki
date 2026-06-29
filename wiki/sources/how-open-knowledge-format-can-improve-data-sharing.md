---
title: "How the Open Knowledge Format Can Improve Data Sharing"
type: source
tags: [knowledge-management, llm, agents, open-standard, data-sharing, OKF]
created: 2026-06-24
updated: 2026-06-24
sources: ["raw/articles/How the Open Knowledge Format can improve data sharing.md"]
related:
  - "[[wiki/concepts/llm-wiki-pattern]]"
  - "[[wiki/entities/andrej-karpathy]]"
confidence: EXTRACTED
status: stable
---

# How the Open Knowledge Format Can Improve Data Sharing

**作者**: Sam McVeety、Amir Hormati（Google Cloud）
**形式**: Blog Post
**发布日期**: 2026-06-12
**链接**: https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing
**本地副本**: `raw/articles/How the Open Knowledge Format can improve data sharing.md`
**阅读日期**: 2026-06-24

## TL;DR

Google Cloud 将 Karpathy 的 LLM-wiki 模式**规范化**为开放格式标准 OKF（Open Knowledge Format）v0.1：markdown 文件目录 + 极简 YAML frontmatter，无 SDK、无平台锁定，让不同团队和 agent 能读写同一份知识而无需翻译层。

## 核心问题：上下文碎片化

组织内 AI agent 所需的知识散落在：
- 各自有 API 的元数据目录
- Wiki、第三方文档、共享文档
- 代码注释、docstring、notebook 单元格
- 少数资深工程师的脑子里

每个 agent 开发者都在**从零解决同一个"上下文拼装"问题**，知识被锁在创建它的平台里，无法跨工具流转。

## OKF 设计

**一个 bundle = 一个 markdown 文件目录**，每个概念对应一个文件，文件路径即概念的 identity。

YAML frontmatter 只强制规定 6 个字段：

| 字段 | 说明 |
|---|---|
| `type` | 唯一**必填**字段，其余均可选 |
| `title` | 概念标题 |
| `description` | 一句话描述 |
| `resource` | 外部链接（如数据库表的 console URL） |
| `tags` | 标签 |
| `timestamp` | 最后更新时间 |

概念之间用普通 markdown 链接互连，构成**关系图**，比文件系统的父子关系更丰富。可选附加 `index.md`（导航分层）和 `log.md`（变更历史）。

### 三个设计原则

| 原则 | 含义 |
|---|---|
| **最小化约束** | 只强制 `type`，内容模型由 producer 自定义 |
| **生产者/消费者独立** | 人写的 bundle 可被 agent 消费；LLM 生成的可被另一个 LLM 查询；格式是契约，工具独立替换 |
| **格式而非平台** | 不绑定任何云/模型/框架，价值来自有多少方使用，而非谁拥有 |

### 与 Karpathy LLM-wiki 的关系

> OKF 是 LLM-wiki 模式的**形式化与标准化** —— 相同的 Markdown + frontmatter + 交叉链接结构，但增加了互操作性约定，让不同团队的 wiki 可以相互读取，而不是各自为战。

## Google 随规格发布的参考实现

| 工具 | 说明 |
|---|---|
| BigQuery enrichment agent | 自动为每张表/视图生成 OKF 概念文档，LLM 二次补充 schema、join 路径和引用 |
| 静态 HTML 可视化器 | 将任意 OKF bundle 渲染为交互图谱，单文件无需后端，数据不离页 |
| 三份示例 bundle | GA4 电商、Stack Overflow、Bitcoin 公开数据集 |

## 对本 wiki 的启示

1. **当前 llm-wiki 结构已高度符合 OKF 精神**（`index.md`、`log.md`、YAML frontmatter），差距仅在于部分页面缺少 `resource`（原文 URL）字段
2. **OKF spec v0.1 只有一页**，值得作为本 wiki 格式演进的参考标准
3. **未来可能性**：用 OKF 兼容格式与外部工具（如 BigQuery catalog、外部 agent）交换知识
4. **Google 的切入点**（BigQuery）表明：数据团队是 OKF 最早的受益场景，但格式本身是通用的

## 反直觉点 / 出彩处

- "答案不是又一个知识服务，而是一个**格式**" —— 这句话定义了 OKF 与 Notion/Confluence 等产品的本质区别
- 格式价值来自"**有多少方讲它**"，而非谁拥有它 —— 典型开放标准思维
- 本文发布时间（2026-06-12）距 Karpathy LLM-wiki gist（2026-04-04）仅 2 个月，说明该模式扩散极快

## 用户评注

> 本仓库本身就是 OKF 的一个先行实例。OKF v0.1 的 `type`/`title`/`description`/`tags`/`timestamp` 字段可逐步补入现有 frontmatter，实现向标准靠拢而不破坏现有结构。

---

_Source: [[wiki/sources/how-open-knowledge-format-can-improve-data-sharing]] | 2026-06-24_
