# AGENTS.md — LLM-Wiki 仓库约定

> 这是给 LLM Agent 的仓库级约定文件，定义目录结构、文件格式和链接规则。
> **执行步骤（ingest/query/lint/digest 的具体操作流程）见 `skill/SKILL.md`。**
>
> 本仓库是 [Karpathy llm-wiki 模式](https://gist.github.com/karpathy/442a6bf555914893e9871c11519de94f) 的一个实例。
>
> **OKF 兼容声明**：本仓库 frontmatter 结构基于 [Open Knowledge Format v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf) 规范，并在此基础上扩展了 `confidence`、`status`、`sources` 字段。OKF 必填字段：`type`、`title`、`description`、`resource`、`tags`。

---

## 1. 三层架构

| 层 | 路径 | 写权限 | 说明 |
|---|---|---|---|
| **Raw sources** | `raw/` | 仅用户 | 原始、不可变资料。LLM 只读，绝不修改。 |
| **Wiki** | `wiki/` | 仅 LLM | LLM 生成与维护的所有页面。 |
| **Schema** | `AGENTS.md`（本文件）| 协同演化 | 仓库约定。 |
| **Skill** | `skill/` | 协同演化 | 工作流执行层（ingest/query/lint/digest）。 |

**铁律**：永远不要修改 `raw/` 下的任何文件。如果原始资料有错，在对应 `wiki/sources/` 摘要页中标注 `> [!note] 修订` 即可。

---

## 2. 目录约定

```
raw/
  articles/    # 网页文章（Obsidian Web Clipper 输出）
  papers/      # 学术论文（PDF 或转换后的 md）
  books/       # 书籍 / 章节笔记
  notes/       # 手写笔记、对话记录、播客转录
  assets/      # 图片等二进制附件

wiki/
  entities/    # 实体页：人、组织、产品、项目（一页一实体）
  concepts/    # 概念页：方法、模式、术语（一页一概念）
  topics/      # 主题页：跨多份资料的主题综合
  sources/     # 来源摘要页：每份 raw/ 资料对应一页
  synthesis/   # 综合页：跨主题分析、比较、问答回流的成果

skill/         # Skill 工作流定义（不含知识内容）

index.md       # 内容目录（按类别列出所有 wiki 页面）
log.md         # 时间线日志（每次 ingest/query/lint 追加一条）
```

### 文件命名

- 一律小写、连字符分隔：`vannevar-bush.md`、`compound-knowledge.md`
- `wiki/sources/` 下的摘要页文件名 = 原始资料文件名（去扩展名），便于配对
- 所有 wiki 页面都加 YAML frontmatter（见下）

### Frontmatter 必填字段

```yaml
---
title: 页面显示标题
type: entity | concept | topic | source | synthesis
description: 一句话概述此页内容           # OKF 必填
resource: "https://..."                   # OKF 必填，无外部链接时写 ""
tags: [tag1, tag2]
created: 2026-04-02
updated: 2026-04-05
sources: ["[[sources/xxx]]"]   # 引用了哪些 raw 来源
related: ["[[concepts/aaa]]"]  # 相关 wiki 页
confidence: EXTRACTED          # EXTRACTED | INFERRED | AMBIGUOUS | UNVERIFIED
status: stub | draft | stable  # 成熟度
---
```

**OKF 核心字段（必填，不可省略）**：`type`、`title`、`description`、`resource`、`tags`
**本仓库扩展字段（推荐填写）**：`confidence`、`status`、`sources`、`related`

**置信度说明**：
- `EXTRACTED`：信息在原文中可直接找到
- `INFERRED`：从多处原文推断，非直接引用；段落内加 `> [!note] 推断：…` callout
- `AMBIGUOUS`：原文说法不清楚或有歧义
- `UNVERIFIED`：来自 AI 背景知识，原文无据

---

## 3. 原始材料格式约定

**🟢 直接摄入**：`.md` / `.txt` / 图片（`raw/assets/`）

**🟡 建议先转 md**：网页 URL（Web Clipper）、PDF（pdftotext/marker）、Word/Pages（导出）、播客（Whisper）

**🔴 不接受**：扫描版 PDF（无 OCR）、单文件超长（> 50k tokens）、加密/DRM、音视频

**命名规则**：一律小写连字符，如 `karpathy-llm-wiki.md`。

---

## 4. 链接规则（Obsidian 风格）

- 内部链接统一用 `[[wiki-link]]`，不用相对路径
- 引用原文用 `> [!quote]` 块，末尾给出 `Source: [[sources/xxx]] §章节`
- 任何具体论断都要可追溯到至少一个 `sources/` 页面

---

## 5. 索引和日志

### `index.md`

- 按类别（entities / concepts / topics / sources / synthesis）分节
- 每行：`- [[wiki/path/page]] — 一句话摘要 (n sources)`
- 每次 ingest 必更

### `log.md`

- **append-only**，绝不重写历史条目
- 格式：
  ```
  ## [YYYY-MM-DD] ingest | <资料标题>
  ## [YYYY-MM-DD] query  | <问题摘要>
  ## [YYYY-MM-DD] lint   | <一句话结论>
  ## [YYYY-MM-DD] digest | <主题>
  ```

---

## 6. 别名词表（SCHEMA）
<!-- codeflicker-fix: P1-Issue-004/7qatih3meh7onycy27fd -->

在 `wiki/SCHEMA.md` 中维护同义词映射，供 query 和 digest 工作流展开搜索时使用。

格式：每行一组同义词，用 `=` 分隔，每组最多 5 个词：

```
自注意力 = Self-Attention = self attention
大语言模型 = LLM = 大模型 = 语言模型
检索增强生成 = RAG = Retrieval-Augmented Generation
```

**规则**：
- 不跨组合并（A=B 和 B=C 不自动推导出 A=C）
- 每组词在知识库内部保持统一称呼（用第一个词作为页面文件名）
- query/digest 执行时：先读 `wiki/SCHEMA.md`，对用户查询词展开同义词后一并搜索

---

## 7. 风格与品味

- **诚实优于完整**：不知道就写 `TBD` 或 `status: stub`，绝不编造
- **可追溯优于流畅**：任何具体数字/论断必须有 `[[sources/...]]` 出处
- **简洁优于堆砌**：摘要 ≤5 行，要点用列表，长论述用折叠 `<details>`
- **保留对立**：遇到分歧不要"调和"成中庸论断，明确列出双方立场和出处

---

## 7. Git 约定

- commit message 前缀：`ingest:`、`query:`、`lint:`、`digest:`、`init:`
- 私密内容：commit 前用户须自查（本仓库会 push 到 git remote）

---

## 8. 工作流执行

见 **`skill/SKILL.md`**，包含 ingest/query/digest/lint/init 的完整步骤。

---

## 9. 协同演化

这份 AGENTS.md 不是一成不变的。发现新约定有用、旧规则碍事时，主动提议修改。改动要小、要解释原因。

---

_首版：2026-06-15 | 重构：2026-06-23 | OKF 对齐：2026-06-29_
