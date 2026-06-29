# Log

> Append-only。每条以 `## [YYYY-MM-DD] <op> | <title>` 开头，便于 `grep "^## \[" log.md | tail -10`。

## [2026-06-29] schema-update | 对齐 OKF v0.1 规范
- 改动范围：AGENTS.md（OKF 兼容声明 + frontmatter 定义新增 description/resource 必填字段）、skill/SKILL.md（核心约定补 OKF 必填字段说明）
- 补丁：为全部 6 个现有 wiki 页面补充 `description` 和 `resource` 字段
- notes: OKF 强制字段只有 type，本仓库对齐其推荐字段集（type/title/description/resource/tags）；confidence/status/sources/related 作为本仓库扩展保留

## [2026-06-24] ingest | How the Open Knowledge Format Can Improve Data Sharing
- source: [[wiki/sources/how-open-knowledge-format-can-improve-data-sharing]]
- touched: [[wiki/concepts/llm-wiki-pattern]]（关联：OKF 是 LLM-wiki 的形式化标准化）
- notes: Google Cloud 在 Karpathy LLM-wiki gist 发布 2 个月后即推出 OKF v0.1，本 wiki 结构已高度符合 OKF 精神，可逐步补充 resource 字段向标准靠拢

## [2026-06-23] ingest | Andrej Karpathy Stopped Using AI to Write Code. He's Using It to Build a Second Brain Instead
- source: [[wiki/sources/andrej-karpathy-second-brain]]
- touched: [[wiki/concepts/llm-wiki-pattern]]（追加局限性/知识飞轮/商业视角/未来方向）, [[wiki/entities/andrej-karpathy]]（新建）, [[wiki/entities/niklas-luhmann]]（新建）
- notes: 本次最重要发现——Luhmann 批评划定了 llm-wiki 边界（侦察 vs 合成），"每家公司都有一个 raw 目录"是最有力的商业洞察

## [2026-06-16] query | 如何把各种材料转换成 md 格式
- filed: [[wiki/topics/raw-material-conversion]]
- notes: 网页/PDF/Word/播客/截图的工具矩阵；marker 已本地安装（conda env: marker）

## [2026-06-16] schema-update | 新增"原始材料格式约定"章节
- file: AGENTS.md §2 内（链接规则之前）
- notes: 三级清单（🟢/🟡/🔴）+ 命名/frontmatter/图片/最小操作约定

## [2026-06-15] bootstrap | 初始化仓库
- 建立三层架构：raw/ + wiki/ + AGENTS.md
- 创建 index.md / log.md
- 摄入第一份资料：Karpathy 的 llm-wiki gist 作为元资料
- touched: [[wiki/sources/karpathy-llm-wiki]], [[wiki/concepts/llm-wiki-pattern]]
