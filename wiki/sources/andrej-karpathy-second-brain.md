---
title: "Andrej Karpathy Stopped Using AI to Write Code. He's Using It to Build a Second Brain Instead"
type: source
tags: [llm-wiki, knowledge-management, RAG, zettelkasten, second-brain]
created: 2026-06-23
updated: 2026-06-23
url: https://pub.neuralnotions.ai/andrej-karpathy-stopped-using-ai-to-write-code-hes-using-it-to-build-a-second-brain-instead-cddceadc5df5
author: Nikhil
published: 2026-04-06
raw_path: raw/articles/Andrej Karpathy Stopped Using AI to Write Code. He's Using It to Build a Second Brain Instead.md
confidence: EXTRACTED
status: stable
images: 1
image_paths: []
sources: ["[[wiki/sources/karpathy-llm-wiki]]"]
related: ["[[wiki/concepts/llm-wiki-pattern]]", "[[wiki/entities/andrej-karpathy]]", "[[wiki/entities/niklas-luhmann]]"]
---

# Andrej Karpathy Stopped Using AI to Write Code. He's Using It to Build a Second Brain Instead

> 作者：Nikhil（Neural Notions）| 发布：2026-04-06  
> 原文：[Neural Notions](https://pub.neuralnotions.ai/andrej-karpathy-stopped-using-ai-to-write-code-hes-using-it-to-build-a-second-brain-instead-cddceadc5df5)

## TL;DR

- Karpathy 宣布更多使用 AI 整理知识而非写代码，其 wiki 已有约 100 篇文章、40 万字，本人几乎不直接编辑
- 本文系统拆解了 llm-wiki 三层架构（raw / schema / wiki）和三个操作（Ingest / Query / Lint）
- 核心对比：RAG 每次从头检索，无法积累；LLM-Wiki 一次编译持久复用，LLM 充当"图书馆员"而非搜索引擎
- 局限：LLM 擅长侦察（整理/连接），形成原创洞见仍是人的工作（引 Luhmann 卡片盒批评）
- 未来方向：wiki 成熟后可生成合成训练数据，微调专属小模型

## 核心论点 / 关键数据 / 反直觉点

- **40 万字、LLM 仍可导航**：Karpathy 的 wiki 不需要向量数据库，LLM 靠 `index.md` 和已有摘要页就能回答跨源复杂问题
- **"编译"隐喻**：Ingest 是增量编译，不是全量重建——每次只处理新素材并整合进现有结构
- **输出即输入（知识飞轮）**：查询的答案归档回 wiki，每次使用都让知识库变得更丰富
- **Vamshi Reddy 商业洞察**："每家公司都有一个 raw 目录，从来没有人编译过它——这就是产品机会"
- **Luhmann 批评（反直觉）**：手写卡片的摩擦感不是障碍，而是理解发生的机制；读别人的摘要与自己组织思路是两件事
- **未来：从知识库到专属模型**：wiki 干净后可生成合成训练数据，微调出"内化"了你的研究领域的小模型

## 原文精彩摘录

> [!quote]
> "It acts as a living AI knowledge base that actually heals itself."
>
> Source: `raw/articles/Andrej Karpathy Stopped Using AI to Write Code...md` §The operations: Ingest, Query, and Lint

> [!quote]
> "Every business has a raw/ directory. Nobody's ever compiled it. That's the product."
> — Vamshi Reddy
>
> Source: `raw/articles/Andrej Karpathy Stopped Using AI to Write Code...md` §Where this gets really interesting

> [!quote]
> "The AI compiles the territory. You still have to walk it."
>
> Source: `raw/articles/Andrej Karpathy Stopped Using AI to Write Code...md` §What it can't do

## 与 [[wiki/sources/karpathy-llm-wiki]] 的关系

本文是对 Karpathy 原始 gist 的**第三方解读**，两者互补：

| 维度 | karpathy-llm-wiki（原始 gist） | 本文（Nikhil 解读） |
|---|---|---|
| 视角 | 作者自述，偏抽象/设计意图 | 读者拆解，偏具体/可操作 |
| RAG 对比 | 简要提及 | 详细展开（架构级对比） |
| 局限性 | 未提及 | 明确引 Luhmann 批评 |
| 商业场景 | 未提及 | 引 Vamshi Reddy 洞察 |
| 操作步骤 | 概念级 | 10 步入门指南 |

## 我的评注

<!-- 供用户填写 -->
