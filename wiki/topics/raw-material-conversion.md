---
title: 原始材料转换工具指南
type: topic
tags: [tooling, workflow, markdown, pdf, ocr]
created: 2026-06-16
updated: 2026-06-16
sources: []
related: ["[[wiki/concepts/llm-wiki-pattern]]"]
status: stable
---

# 原始材料转换工具指南

把各种格式的资料转成 markdown，放入 `raw/` 供 LLM 摄入。按来源分类。

---

## 📰 网页文章（最高频）

### Obsidian Web Clipper（强烈推荐，免费）

- Chrome / Firefox / Safari 插件
- 一键把当前网页转成 markdown，直接存到 Obsidian vault 的指定路径（配置指向 `raw/articles/`）
- 自动提取标题、作者、URL、发布日期填入 frontmatter
- 安装：https://obsidian.md/clipper

### MarkDownload（备选）

- 类似 Web Clipper，更轻量，存到任意本地文件夹

---

## 📄 PDF / 论文

| 工具 | 特点 | 安装 / 用法 |
|---|---|---|
| **marker**（本地，推荐） | 开源，布局保留好，支持图片提取，已在本机安装 | 见下方详细说明 |
| **pdftotext** | 极简，纯文本无格式 | `brew install poppler` → `pdftotext xxx.pdf xxx.txt` |
| **LLM 直传**（最懒） | 直接把 PDF 扔给 Claude，让它"转录成 markdown，保留章节结构" | 免安装，超长文件分批处理 |

### marker 用法（已安装在 conda env `marker`）

```bash
# 转换单个 PDF
conda activate marker
marker_single input.pdf --output_dir ~/Documents/llm-wiki/raw/papers/

# 批量转换整个目录
marker ~/Downloads/papers/ --output_format markdown

# 快捷 alias（已加入 ~/.zshrc 后）
pdf2md ~/Downloads/paper.pdf --output_dir ~/Documents/llm-wiki/raw/papers/
```

输出：`output/input/input.md`，保留标题层级、表格、图片。

---

## 📝 Word / Pages / 富文本

**pandoc** 是万能转换器，macOS 首选：

```bash
brew install pandoc
pandoc input.docx -o output.md          # Word → md
pandoc input.html -o output.md          # HTML → md
# Pages 先在应用里导出为 .docx，再用 pandoc
```

---

## 💬 微信公众号

- **PC 端网页版**：Obsidian Web Clipper 最方便
- **手机端**：复制粘贴到 `raw/notes/` 的新 md 文件，手动整理

---

## 🎙 播客 / 视频（语音转文字）

| 工具 | 特点 | 安装 |
|---|---|---|
| **MacWhisper**（macOS App，推荐） | Whisper 的 GUI 包装，拖拽音频即可转录，支持中英文 | App Store |
| **Whisper CLI**（开源，本地） | 质量最好，支持中文 | `pip install openai-whisper` |
| **飞书妙记 / 腾讯会议** | 会议录音有内置 AI 转录 | 无需安装 |

```bash
# Whisper CLI 用法
whisper audio.mp3 --language Chinese --output_format txt
```

---

## 📸 截图 / 扫描件（OCR）

| 工具 | 特点 |
|---|---|
| **macOS 原生 OCR** | 截图后三指拖选文字，或截图 App 直接识别文字，零成本 |
| **TextSniper**（付费 App） | 截图区域即可 OCR，支持中文，体验流畅 |
| **LLM 直接看截图** | 把截图发给 Claude："提取所有文字，输出 markdown 格式" |
| **Tesseract**（批量 CLI） | `brew install tesseract tesseract-lang` + 脚本批量处理 |

---

## 💡 一句话速查

| 场景 | 最佳工具 |
|---|---|
| 网页文章 | **Obsidian Web Clipper** |
| PDF / 论文 | **marker**（本地，已装）或直接扔给 LLM |
| Word / Pages | **pandoc** |
| 播客 / 视频 | **MacWhisper** |
| 截图文字 | macOS 原生 OCR 或 **TextSniper** |
| 一切其他 | 发给 LLM："转成 markdown，保留结构" |

---

## 命名规则（转换后存入 raw/ 前）

- 小写、连字符、可读：`karpathy-llm-wiki.md`、`pg-do-things.md`
- 避免：`截屏 2026.png`、`Document(2).pdf`
- 因为 `wiki/sources/<同名>.md` 会自动与原始文件配对

> 详见 [[AGENTS]] §2「原始材料格式约定」。
