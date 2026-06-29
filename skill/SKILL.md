---
name: llm-wiki
description: |
  本地 Markdown 知识库管理 Skill（基于 llm-wiki 仓库）。
  素材经 ingest 编译进 wiki，后续 query/digest 复用已有页面，而非每次重读原文。
  触发：用户提到「知识库」「ingest」「消化」「查询」「lint」，或直接给文件/链接未说明意图（默认 ingest）。
  非触发：仅「总结这篇文章」且无知识库意图。
---

# llm-wiki Skill

本地 Markdown 知识库；素材经 **ingest** 编译进 `wiki/`，后续 **query/digest** 复用已有页面，而非每次重读原文。

## 路径约定

- `WIKI_ROOT` = 本仓库根目录（`AGENTS.md` 所在目录）
- `SKILL_DIR` = 本文件所在目录（`skill/`）
- 所有工作流操作的文件均在 `WIKI_ROOT` 下

## 工作流路由

| 意图关键词 | 文档 |
|---|---|
| 初始化、新建知识库 | [docs/workflow-init.md](docs/workflow-init.md) |
| 消化素材、给文件/链接/文本 | [docs/workflow-ingest.md](docs/workflow-ingest.md) |
| 查询、XX 是什么、解释 | [docs/workflow-query.md](docs/workflow-query.md) |
| 深度报告、对比、时间线 | [docs/workflow-digest.md](docs/workflow-digest.md) |
| 健康检查、lint | [docs/workflow-lint.md](docs/workflow-lint.md) |

**默认路由**：给文件/链接未说明意图 → **ingest**。

## 执行顺序

1. 根据上表只打开当前工作流对应的一个 `docs/workflow-*.md`
2. 执行前先读 `AGENTS.md`（仓库约定），工作流文档覆盖其中的执行步骤
3. 需要 CLI 命令细节或脚本参数时再读 `scripts/`

## 核心约定（速查）

- `raw/` 只读，LLM 绝不修改
- `wiki/` 由 LLM 维护；`sources/` 摘要页文件名 = raw 文件名（去扩展名）
- 内部链接统一用 `[[wiki-link]]` 格式
- 所有 wiki 页面必须有 YAML frontmatter
- **OKF 必填字段**：`type`、`title`、`description`、`resource`（无外部链接写 `""`）、`tags`
- 置信度：页面级 `confidence` frontmatter 字段 + 推断段落用 `> [!note] 推断：…` callout
- 去重：ingest 前必须 `ls wiki/sources/` 比对，发现重复询问用户
- git commit：用 `ingest:`、`query:`、`lint:` 前缀
