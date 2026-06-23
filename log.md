# Log

> Append-only。每条以 `## [YYYY-MM-DD] <op> | <title>` 开头，便于 `grep "^## \[" log.md | tail -10`。

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
