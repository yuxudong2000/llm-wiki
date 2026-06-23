# init — 初始化知识库

> 当用户第一次使用或需要重置时运行。`WIKI_ROOT` = 仓库根目录。

---

## 触发条件

- 用户说"初始化知识库"、"新建 wiki"
- 用户首次 ingest 时发现 `wiki/` 目录为空

---

## 步骤

### 1. 检查现有状态

```bash
ls $WIKI_ROOT/wiki/
ls $WIKI_ROOT/raw/
cat $WIKI_ROOT/index.md 2>/dev/null || echo "index.md 不存在"
```

如果 `wiki/` 已有内容 → 告知用户当前状态，询问是否继续初始化（会覆盖现有 index）。

### 2. 创建目录结构（如不存在）

```bash
mkdir -p $WIKI_ROOT/wiki/entities
mkdir -p $WIKI_ROOT/wiki/concepts
mkdir -p $WIKI_ROOT/wiki/topics
mkdir -p $WIKI_ROOT/wiki/sources
mkdir -p $WIKI_ROOT/wiki/synthesis
mkdir -p $WIKI_ROOT/raw/articles
mkdir -p $WIKI_ROOT/raw/papers
mkdir -p $WIKI_ROOT/raw/books
mkdir -p $WIKI_ROOT/raw/notes
mkdir -p $WIKI_ROOT/raw/assets
```

### 3. 生成或重置 `index.md`

```markdown
# Wiki Index

> 本 wiki 所有页面的内容目录，按类别组织。
> LLM 在每次 ingest 后必须更新本文件。提问时也先读这里再钻具体页。

_最后更新：<今日日期>_

---

## Entities（实体：人 / 组织 / 产品）

_暂无_

## Concepts（概念 / 方法 / 模式）

_暂无_

## Topics（主题综合）

_暂无_

## Sources（原始资料摘要）

_暂无_

## Synthesis（综合 / 比较 / 问答回流）

_暂无_
```

### 4. 生成 `wiki/purpose.md`（新建，引导用户填写）
<!-- codeflicker-fix: P1-Issue-003/7qatih3meh7onycy27fd -->

```markdown
---
title: 知识库意图
type: purpose
created: <今日日期>
updated: <今日日期>
---

# 知识库意图

> 这个文件告诉 AI 这个知识库是做什么用的，帮助 ingest 时对内容做有取舍的分析。
> **请用户填写以下字段**，填写后 ingest 的质量会显著提升。

## 核心目标

（这个知识库的主要用途是什么？例：积累 LLM 工程实践知识，供日后查阅和决策参考）

TBD

## 关键问题

（你最想从这个知识库里找到哪类答案？例：如何提升 RAG 效果？如何评估 LLM 输出质量？）

- TBD

## 研究范围

（哪些主题是核心范围，哪些是边缘？）

- 核心：TBD
- 边缘/排除：TBD
```

### 5. 生成或重置 `log.md`

```markdown
# 操作日志

> append-only。每次 ingest/query/lint 后追加一条。

---

## [<今日日期>] init | 知识库初始化
- notes: 初始化完成，目录结构已创建
```

### 6. 向用户展示结果

```
知识库已初始化：

目录结构：
  raw/articles/    ← 网页文章（Obsidian Web Clipper 输出）
  raw/papers/      ← 学术论文
  raw/books/       ← 书籍/章节
  raw/notes/       ← 手写笔记、聊天记录
  raw/assets/      ← 图片等二进制附件
  wiki/entities/   ← 人、组织、产品
  wiki/concepts/   ← 方法、模式、术语
  wiki/topics/     ← 跨素材主题综合
  wiki/sources/    ← 每份素材的摘要页
  wiki/synthesis/  ← 问答回流、深度报告
  wiki/domains/    ← 按领域组织的深度报告（digest 产出）

已创建 wiki/purpose.md ← 请填写知识库意图，ingest 时 AI 会优先参考

下一步：
1. 填写 wiki/purpose.md（强烈建议，有助于提升 ingest 质量）
2. 把想消化的资料放入 raw/ 对应子目录，然后对我说"ingest 它"
```

### 7. 提示 git commit

```
git add wiki/ raw/ index.md log.md
git commit -m "init: 知识库初始化"
```
