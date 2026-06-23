# ingest — 消化素材

> 这是最核心的工作流。用户给一个素材进来，AI 做所有的整理工作。
> `WIKI_ROOT` = 仓库根目录；`SKILL_DIR` = `skill/` 目录。

## 整体执行模型

```
① 去重检查（文件名比对）
② 读取素材内容
③ 隐私自查确认
④ 读取上下文（purpose.md + index.md + 相关已有页面）
⑤ 用户讨论（汇报要点，等待回应）
⑥ Step 1：结构化分析（输出 JSON + 降级容错）
⑦ Step 2：页面生成（基于 Step 1 结果 + 图片追踪）
⑧ 写入文件 + 更新 index.md / log.md
⑨ 提示 git commit
```

---

## Phase 0：去重检查（必须执行）

**在做任何分析之前**，先比对文件名：

```bash
ls $WIKI_ROOT/wiki/sources/
```

- 如果 raw 文件名（去扩展名）已存在于 `wiki/sources/` → **停止**，询问用户：
  > `wiki/sources/<同名>.md` 已存在，这个素材似乎已消化过。
  > 要 **更新** 现有页面，还是 **跳过**？
- 用户选"更新" → 继续执行，最终覆盖已有页面
- 用户选"跳过" → 终止，告知用户哪些页面已存在
- 纯文本粘贴（无文件名）→ 跳过此步，直接进入下一步

---

## Phase 1：读取素材

根据素材类型：

| 类型 | 处理方式 |
|---|---|
| 本地 `.md` / `.txt` | `read_file` 直接读取 |
| 本地 PDF（已转 md） | 读取同名 `.md`，原 PDF 保留 |
| 纯文本粘贴 | 直接使用用户提供的文本 |
| URL | 提示用户先用 Obsidian Web Clipper 转为 md 放入 `raw/articles/` |

**文件名约定**（若为新文件）：一律小写、连字符分隔，如 `karpathy-llm-wiki.md`。

---

## Phase 2：隐私自查（首次 ingest 必须执行）

在开始提取或分析任何内容之前，AI **必须**先对用户说下面这句话，然后等待确认：

> 在开始分析这份素材前，请先快速确认里面**不**包含这些敏感内容：
>
> - 手机号码（如 138xxxxxxxx）
> - 身份证号（18 位数字）
> - API 密钥（`sk-...`、`AIzaSy...`、`OPENAI_API_KEY=`、`Bearer ...`）
> - 明文密码（`password=`、`passwd=`）
> - 其他你不希望进入知识库的个人信息
>
> 本仓库内容会 push 到 git remote，处理后的内容会进入知识库。
> 确认无上述内容请回复 `y`，要中止请回复 `n`。

**流程规则**：
<!-- codeflicker-fix: P0-Issue-002/7qatih3meh7onycy27fd -->
- `y` 或明确肯定（"可以"、"继续"、"没有"等）→ 继续
- `n` 或明确否定（"停"、"取消"等）→ 终止，提示用户清理后再来
- **模糊回复**（非明确 y/n）→ 再问一次，最多问**两次**；两次都不是明确 y/n 则自动终止，提示："无法确认素材安全性，已终止本次 ingest。"
- **绕过条件**：用户在当前对话已明确说过"没有敏感信息" → 跳过本步

**为什么是自查清单而不是脚本**：
- 正则在非结构化文本（聊天记录、笔记）里误报率高，会漏掉真敏感词、误报无害词
- 把判断权还给用户，比让脚本决定更可靠

---

## Phase 3：读取上下文

读取以下文件（按优先级）：

```bash
# 1. 知识库意图文件（若存在，优先级最高）
cat $WIKI_ROOT/wiki/purpose.md 2>/dev/null

# 2. 当前索引（了解已有哪些页面）
cat $WIKI_ROOT/index.md

# 3. 相关已有页面（根据素材主题，按需读取 2-3 个最相关的）
# 从 index.md 找候选，用 grep 定位
grep -n "关键词" $WIKI_ROOT/index.md
```

**`purpose.md` 的作用**：
- 记录知识库的核心目标、关键问题、研究范围
- 用来指导 Step 1 分析时对实体/主题的权重判断
- 示例：purpose.md 说"关注 LLM 工程实践"，则 Step 1 应重点提取工程相关实体，降权纯学术内容

如果 `purpose.md` 不存在，直接用 `index.md` 了解现有知识库范围。

---

## Phase 4：用户讨论（等待回应）

读完素材后，**先用 3-8 条要点向用户汇报核心内容**，询问：
> 有没有特定的关注角度，或者这份素材和已有哪些 wiki 页面相关？

等待用户回应后，再进入 Step 1 分析。

---

## Phase 5：Step 1 结构化分析

在内存中生成如下 JSON（不持久化，只在当前 ingest 流程临时使用）：

```json
{
  "source_title": "一句话标题",
  "source_summary": "一句话概括这份素材讲什么",
  "entities": [
    {
      "name": "Transformer",
      "type": "concept",
      "relevance": "high",
      "confidence": "EXTRACTED",
      "evidence": "原文摘录（≤50字）"
    }
  ],
  "topics": [
    {"name": "注意力机制", "importance": "high"}
  ],
  "connections": [
    {
      "from": "Transformer",
      "to": "BERT",
      "type": "衍生",
      "confidence": "INFERRED",
      "evidence": "推理依据"
    }
  ],
  "contradictions": [
    {"claim": "...", "conflicts_with": "[[wiki/concepts/xxx]]", "context": "..."}
  ],
  "new_vs_existing": {
    "new_entities": ["新实体1"],
    "updates": ["wiki/concepts/existing.md"]
  },
  "image_refs": [],
  "page_confidence": "EXTRACTED"
}
```

**置信度赋值规则**：
- `EXTRACTED`：信息在原文中可直接找到，`evidence` 提供原文摘录（≤50字）
- `INFERRED`：从多处原文推断，原文没有直接说，`evidence` 说明推理依据
- `AMBIGUOUS`：原文说法不清楚或有歧义
- `UNVERIFIED`：来自 AI 背景知识，原文无据

**`page_confidence`**：本次 ingest 生成的所有页面的整体置信度（取最低的那个）。

**`image_refs`**：扫描素材正文中所有图片引用（`![`、`<img`、URL 以 `.png/.jpg/.jpeg/.webp/.gif/.svg` 结尾），记录每个引用的 URL 或路径。

### Step 1 降级容错
<!-- codeflicker-fix: P0-Issue-001/7qatih3meh7onycy27fd -->

如果 Step 1 输出**不是有效 JSON**，或缺少 `entities`、`topics`、`page_confidence` 任一必填字段：

1. **自动降级为单步 ingest**：跳过 Step 2，直接基于素材原文生成来源摘要页
2. 所有生成页面在 frontmatter 加：`confidence: UNVERIFIED`
3. 在来源摘要页顶部加注释：
   ```markdown
   > [!warning] 降级处理：Step 1 分析格式异常，已回退单步 ingest。此页内容置信度为 UNVERIFIED，建议人工复核。
   ```
4. 继续执行 Phase 6（写入文件），不因 Step 1 失败阻塞整个流程

---

## Phase 6：Step 2 页面生成（含图片追踪）

基于 Step 1 结果，读取相关已有页面，生成或更新以下文件：

### 1. 来源摘要页 `wiki/sources/<raw文件名>.md`

使用 `templates/source-template.md`，frontmatter 必填：

```yaml
---
title: <素材标题>
type: source
tags: [<来自素材的标签>]
created: <今日日期>
updated: <今日日期>
url: <来源 URL，若有>
author: <作者，若有>
published: <发布日期，若有>
raw_path: raw/<子目录>/<文件名>
confidence: EXTRACTED
status: stable
images: 0          # 图片引用数量（Step 1 image_refs 的长度）
image_paths: []    # 已下载到 raw/assets/ 的图片路径（初始为空）
---
```

**图片追踪**（来自 Step 1 的 `image_refs`）：
<!-- codeflicker-fix: P1-Issue-005/7qatih3meh7onycy27fd -->
- 如果 `image_refs` 非空（N > 0）：
  - 在 frontmatter 中设置 `images: N`
  - **告知用户**：
    > 素材包含 N 张图片引用。图片外链可能失效，建议手动下载到 `raw/assets/` 并更新 `wiki/sources/<文件名>.md` 的 `image_paths` 字段。
  - 不阻塞 ingest 流程，仅做提醒
- 如果 `image_refs` 为空：设置 `images: 0`，`image_paths: []`

**正文结构**：
- **TL;DR**（≤5 行）
- **核心论点 / 关键数据 / 反直觉点**（列表）
- **原文精彩摘录**（1-3 段，用 `> [!quote]` 块，末尾注 `Source: raw_path §章节`）
- **我的评注**（留空段落，供用户填写）

### 2. 实体页 `wiki/entities/<name>.md` / 概念页 `wiki/concepts/<name>.md`

- 新实体/概念 → 用对应模板新建（`status: stub` 可接受）
- 已有页面有新论据 → 追加段落，保留旧内容并标注：
  ```markdown
  > [!note] 2026-06-23 更新自 [[sources/xxx]]：新增的信息…
  ```
- 矛盾点：
  ```markdown
  > [!warning] 与 [[sources/yyy]] 矛盾：具体矛盾描述
  ```
- 推断内容（`INFERRED`），在段落末尾加：
  ```markdown
  > [!note] 推断：此处结论由多处原文推断，非直接引用。依据：…
  ```

### 3. 主题页 `wiki/topics/<topic>.md`（如适用）

若 Step 1 识别出跨素材的综合主题，用 `templates/topic-template.md` 创建或更新。

### 4. 更新 `index.md`

在对应分类下新增或更新条目：
```
- [[wiki/sources/xxx]] — <一句话摘要> (1 source)
- [[wiki/concepts/yyy]] — <一句话摘要> (n sources)
```

### 5. 追加 `log.md`

```markdown
## [YYYY-MM-DD] ingest | <素材标题>
- source: [[wiki/sources/xxx]]
- touched: [[wiki/entities/aaa]], [[wiki/concepts/bbb]]
- notes: 一句话本次最重要的发现
```

---

## Phase 7：向用户展示结果

```
已消化：<素材标题>

新增页面：
- wiki/sources/<xxx>.md
- wiki/concepts/<yyy>.md（新建）

更新页面：
- wiki/entities/<zzz>.md（追加了新信息）

发现关联：
- 这篇素材和 [[已有素材]] 在 <某概念> 上有联系

（如有推断内容）推断标注：
- wiki/concepts/<yyy>.md 中的 X 关系标注为 INFERRED，来源不足时请复核

（如有图片）图片提醒：
- 素材含 N 张图片引用，建议下载到 raw/assets/ 后更新 image_paths
```

---

## Phase 8：提示 git commit

```
建议执行：
git add wiki/ index.md log.md
git commit -m "ingest: <素材标题>"
```

---

## 简化处理（短素材 ≤ 500 字）

仅生成来源摘要页，跳过实体/概念页的创建/更新。提取 1-3 个关键概念，在摘要页用 `[待创建: [[概念名]]]` 标记但不新建。图片追踪规则同完整流程。

---

## 政策/规范原文（verbatim 路径）

**触发条件**：用户说"这是政策/规范"、"原文存入"、"不要概括"，或文件名含"规范/管理办法/条例/政策"等。

此路径**跳过所有分析步骤**，直接写入 `wiki/policies/<文件名>.md`（需新建此目录），frontmatter 加 `verbatim: true`，正文完整复制原文，不做任何改写。
