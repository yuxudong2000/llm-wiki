# query — 查询知识库

> `WIKI_ROOT` = 仓库根目录；`SKILL_DIR` = `skill/` 目录。

**区别于 digest**：query 是快速问答，不主动生成新页面；digest 是跨素材深度综合，生成持久化报告。

---

## 步骤

### 1. 读 `index.md` 找候选页面

**不要凭记忆回答**，先读索引：

```bash
# 在 index.md 中快速定位关键词
grep -n "关键词" $WIKI_ROOT/index.md
```

从命中行提取候选页面路径（`[[wiki/path/page]]` 格式）。

### 1a. 别名展开（先读 SCHEMA.md）
<!-- codeflicker-fix: P1-Issue-004/7qatih3meh7onycy27fd -->

```bash
cat $WIKI_ROOT/wiki/SCHEMA.md 2>/dev/null | grep -A20 "别名词表"
```

- 如果 `wiki/SCHEMA.md` 存在且有"别名词表"章节，先找到用户查询词所在的同义词组
- 用该组内**所有词**一并搜索（不跨组传递）
- 例：用户问"self-attention"，词表中 `自注意力 = Self-Attention = self attention` → 同时搜索这三个词

### 2. 本地 grep 精确定位

```bash
# 在整个 wiki/ 目录中搜索关键词（含所有别名展开后的词）
grep -rl "关键词" $WIKI_ROOT/wiki/

# 需要上下文时
grep -n -C3 "关键词" $WIKI_ROOT/wiki/concepts/xxx.md
```

### 3. 按需读取相关页面（3-5 页）

优先顺序：
1. `wiki/concepts/` 或 `wiki/entities/`（最相关的 1-3 页）
2. `wiki/sources/`（对应摘要页）
3. `wiki/topics/` 或 `wiki/synthesis/`（若存在）

**单页长度上限**：超过 3000 字只读 frontmatter + 核心论点段落 + grep 命中上下文，跳过"原文精彩摘录"等冗长引用。

### 4. 信息充足性评估

| 问题类型 | wiki 层是否足够 | 处理方式 |
|---------|----------------|---------|
| 一般问答 / 解释概念 | 通常足够 | 直接用 wiki 回答 |
| 原文细节 / 数字佐证 | 不够 | 读 `raw/<对应文件>` |
| 跨素材对比 | 不够 | 建议用 **digest** 工作流 |
| 无相关页面 | 完全不够 | 告知用户知识库暂无此内容，建议 ingest |

### 5. 综合回答

- 按 `WIKI_ROOT/AGENTS.md` 中的语言约定回答
- **所有论断给出 `[[wiki-link]]` 引用**
- 多个素材有不同观点时分别列出并标注来源
- 置信度为 `INFERRED` 或 `AMBIGUOUS` 的内容，回答时明确说明"这是推断"

### 6. 判断是否值得持久化

如果回答引用了 **3 个及以上来源**的综合分析，主动提示：

> 这个回答信息密度不错，引用了 N 个来源。要不要存为 `wiki/synthesis/<主题>.md`？

征得用户同意后：
- 用 `templates/synthesis-template.md` 生成页面
- 更新 `index.md` 的 Synthesis 分类
- 追加 `log.md`：
  ```markdown
  ## [YYYY-MM-DD] query | <问题摘要>
  - synthesis: [[wiki/synthesis/xxx]]
  - sources: [[wiki/sources/a]], [[wiki/sources/b]]
  - notes: 一句话核心洞察
  ```
- 提示 git commit：`git commit -m "query: <问题摘要>"`

### 7. 自引用防护

`wiki/synthesis/` 下的衍生页面在后续 ingest 分析里视为二级来源，不作为主要知识来源。如果用户问到某个 synthesis 页面里的信息，要说明"这是之前的综合分析，原始来源是…"。

---

## 无结果时的处理

知识库里没有相关内容时：

> 我在知识库里没有找到关于「<关键词>」的页面。
>
> 建议：把相关资料（文章/论文/笔记）放入 `raw/` 并执行 ingest，下次就能从知识库回答了。
