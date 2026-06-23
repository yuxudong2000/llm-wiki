# lint — 健康检查

> `WIKI_ROOT` = 仓库根目录；`SKILL_DIR` = `skill/` 目录。

Lint 分两层：**脚本机械检查**（确定性、快速）+ **AI 语义检查**（矛盾、缺页建议）。

**重要**：lint 只产出问题报告，不直接改文件。用户确认后再批量修。

---

## 触发时机

- 用户主动说"lint wiki"、"健康检查"
- ingest 后素材总数为 10 的倍数，可主动建议运行 lint

---

## Step 1：脚本机械检查

```bash
bash $SKILL_DIR/scripts/lint-runner.sh $WIKI_ROOT
```

脚本输出 JSON 报告，包含：
- `orphan_pages`：wiki/ 下不在 index.md 里的页面
- `broken_links`：`[[wikilink]]` 指向不存在文件的链接
- `missing_from_index`：存在于 wiki/ 但未被 index.md 收录的页面
- `missing_frontmatter`：缺少必填 frontmatter 字段的页面
- `no_source_signal`：`entities/` 和 `concepts/` 下 `sources` 字段缺失或为空的页面（知识点无来源支撑，可追溯性差）<!-- codeflicker-fix: P2-Issue-006/7qatih3meh7onycy27fd -->

脚本返回非 0 时，报告脚本错误并终止（不继续 AI 检查）。

---

## Step 2：AI 语义检查

读取 Step 1 报告，结合 wiki 内容做以下检查：

1. **矛盾**：读取 `wiki/concepts/` 和 `wiki/entities/` 中最近更新的 10 页，检查是否有相互矛盾的论断。
   - 定位方式：`grep -r '\[!warning\]' $WIKI_ROOT/wiki/` 先找已标注的矛盾
   - 再人工判断是否有未标注的矛盾

2. **过时**：检查 `log.md` 最近 5 条 ingest 记录，对应的 entity/concept 页面是否有被新素材推翻的旧论断。

3. **孤儿页**（来自脚本结果）：确认是真正孤立还是脚本漏扫。

4. **缺页**：
   ```bash
   # 找出被多次提及但没有自己页面的概念/实体
   grep -ro '\[\[concepts/[^]]*\]\]' $WIKI_ROOT/wiki/ | sort | uniq -c | sort -rn | head -20
   grep -ro '\[\[entities/[^]]*\]\]' $WIKI_ROOT/wiki/ | sort | uniq -c | sort -rn | head -20
   ```
   链接目标不存在但被引用 2 次以上 → 列为"缺页"建议。

5. **缺交叉引用**：相同 tags 的页面之间是否应该互相链接但还没有？

6. **数据缺口**：现有素材覆盖范围里，哪些问题靠现有资料答不出？

---

## Step 3：输出报告

报告格式（按优先级排序）：

```markdown
## Lint 报告 — [日期]

### 🔴 需要立即修复

| # | 类型 | 位置 | 描述 | 建议动作 |
|---|------|------|------|---------|
| 1 | 断链 | wiki/concepts/foo.md L12 | [[entities/bar]] 不存在 | 创建 bar.md 或修正链接 |
| 2 | 缺 frontmatter | wiki/sources/baz.md | 缺少 `type` 字段 | 补充 frontmatter |

### 🟡 建议改进

| # | 类型 | 位置 | 描述 | 建议动作 |
|---|------|------|------|---------|
| 3 | 孤立页 | wiki/concepts/qux.md | 没有任何反向链接 | 在相关页面添加链接 |
| 4 | 矛盾 | wiki/concepts/A.md vs wiki/sources/B.md | 对 X 的描述不一致 | 核查原文，统一表述 |

### 🔵 数据缺口

- 知识库目前无法回答：<具体问题>
- 建议下一步搜集：<具体资料建议>

共发现 N 个问题（🔴 M 个，🟡 P 个）。
```

---

## Step 4：用户确认后修复

用户确认要修复哪些条目后，AI 批量修改对应文件。

完成后追加 `log.md`：
```markdown
## [YYYY-MM-DD] lint | 修复 N 个问题
- fixed: 断链 2 个，补 frontmatter 1 个
- notes: 一句话本次 lint 最重要的发现
```

提示 git commit：`git commit -m "lint: fix N issues"`
