---
title: LLM-Wiki Pattern
type: concept
tags: [knowledge-management, methodology, meta, RAG, zettelkasten]
created: 2026-06-15
updated: 2026-06-23
sources: ["[[wiki/sources/karpathy-llm-wiki]]", "[[wiki/sources/andrej-karpathy-second-brain]]"]
related: ["[[wiki/entities/andrej-karpathy]]", "[[wiki/entities/niklas-luhmann]]"]
status: stable
---

# LLM-Wiki Pattern

一种用 LLM 增量构建并维护个人 / 团队知识库的模式。本仓库就是它的实例。

## 一句话定义

**LLM 在你和原始资料之间，持续编译一个持久化、相互链接的 markdown wiki。** 你只负责喂资料、提问、定方向；LLM 负责所有摘要、交叉引用、消歧、簿记。

## 与 RAG 的差别

| 维度 | RAG | LLM-Wiki |
|---|---|---|
| 知识何时被处理 | 查询时（每次重做） | 摄入时（一次编译，持续维护） |
| 是否积累 | 否 | 是，wiki 越用越富 |
| 跨文档综合 | 临场拼接 | 已落入页面 |
| 矛盾处理 | 无 | 已被显式标注 |
| 维护成本 | 低（无需维护） | 由 LLM 承担 |

## 三层架构

1. **Raw sources** — 你的原始资料，不可变。
2. **Wiki** — LLM 生成的 markdown 页面。
3. **Schema** — 操作手册（本仓库的 [[AGENTS]]）。

详见 [[wiki/sources/karpathy-llm-wiki]]。

## 三个操作

- **Ingest**：摄入新资料，更新所有受影响页面。
- **Query**：基于 wiki 回答，好答案回流为 [[wiki/synthesis/_]] 新页。
- **Lint**：周期性体检（矛盾 / 孤儿 / 缺页 / 数据缺口）。

## 关键洞察

- 人放弃 wiki 是因为**簿记**成本超过价值——LLM 不会厌倦簿记。
- 思想上溯 [[wiki/entities/vannevar-bush]] 的 Memex（1945）：Bush 没解决的"谁维护"，LLM 解决了。（_此实体页待建_）
- 一份资料触动 10–15 页才是正常的工作量。
- 文档**刻意保持抽象**——模式 ≠ 实现，让用户和 LLM 共同实例化。

## 在本仓库的体现

- `raw/` ↔ Raw sources
- `wiki/` ↔ Wiki
- [[AGENTS]] ↔ Schema
- [[index]] ↔ 内容目录
- [[log]] ↔ 时间线日志

## 局限性（Luhmann 批评）

> [!note] 2026-06-23 更新自 [[wiki/sources/andrej-karpathy-second-brain]]：补充第三方批评视角

一位 Substack 作者引用 [[wiki/entities/niklas-luhmann]] 指出：

- LLM 擅长**侦察阶段**（整理、连接、发现关联）
- **合成阶段**（形成原创洞见）仍是人的工作
- Luhmann 卡片盒的手写摩擦感不是障碍，而是理解发生的机制

> "The AI compiles the territory. You still have to walk it."

这一批评界定了 llm-wiki 的边界：消除组织体力劳动，但不替代深度思考。

## 知识飞轮

> [!note] 2026-06-23 更新自 [[wiki/sources/andrej-karpathy-second-brain]]：补充输出层描述

查询的答案作为 markdown 文件归档回 wiki，形成飞轮：

```
新素材 → Ingest → wiki 页面 → Query → 答案 → 归档回 wiki → 更富的 wiki
```

还可输出 Marp 幻灯片、matplotlib 图表、比较表格——输出物统一以 markdown 形式回流。

## 商业视角

> [!note] 2026-06-23 更新自 [[wiki/sources/andrej-karpathy-second-brain]]：Vamshi Reddy 洞察

> [!quote]
> "Every business has a raw/ directory. Nobody's ever compiled it. That's the product."
> — Vamshi Reddy

适用场景：竞品分析、尽职调查、行程规划、小说追踪、技术学习、考试复习……schema 层吸收所有领域定制，同一架构可编译不同类型的 wiki。

## 未来方向

> [!note] 2026-06-23 更新自 [[wiki/sources/andrej-karpathy-second-brain]]

- wiki 成熟后可生成**合成训练数据**，微调专属小模型——从"查询时读 wiki"升级为"模型已内化你的研究领域"

## 待办 / 可演化点

- [ ] 当 wiki > 100 篇时，引入 [qmd](https://github.com/tobi/qmd) 本地搜索。
- [ ] 探索 Obsidian Dataview + frontmatter 自动生成动态视图。
- [x] 评估是否需要 Marp 幻灯片输出。（Karpathy 已验证此用法）
