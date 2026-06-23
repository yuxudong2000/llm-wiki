---
title: Karpathy — A pattern for LLM-maintained personal wikis
type: source
tags: [knowledge-management, llm, agents, methodology]
created: 2026-06-15
updated: 2026-06-15
sources: []
related: ["[[wiki/concepts/llm-wiki-pattern]]"]
status: stable
---

# Karpathy — A pattern for LLM-maintained personal wikis

**作者**: Andrej Karpathy
**形式**: GitHub Gist (`llm-wiki.md`)
**发布日期**: 2026-04-04
**链接**: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
**本地副本**: `raw/articles/karpathy-llm-wiki.md`
**阅读日期**: 2026-06-15

## TL;DR

提出一个 **LLM 增量维护、人类只负责喂料和提问** 的个人知识库模式：把 RAG 的"每次查询都重新检索"换成"持续把新资料编译进一个持久化的 wiki"。结构是 raw / wiki / schema 三层；操作是 ingest / query / lint 三动作；导航靠 `index.md` + `log.md` 两个特殊文件。

## 核心论点

1. **RAG 的局限**：每次查询都从零检索零碎片段，知识不积累。
2. **替代范式**：LLM 持续把新资料"编译"进 wiki，跨引用、矛盾、综合都已就位。
3. **分工**：人负责 sourcing / exploration / 提问；LLM 负责所有簿记。
4. **三层架构**：
   - `raw/`（不可变原始资料）
   - `wiki/`（LLM 生成的 markdown 页面）
   - `schema`（如 `AGENTS.md` / `CLAUDE.md`，定义约定与流程）
5. **三个操作**：
   - **Ingest**：一份新资料常更新 10–15 个 wiki 页。
   - **Query**：好回答应回流为新页面，不要让它消失在聊天历史里。
   - **Lint**：定期体检矛盾 / 过时 / 孤儿页 / 缺页 / 缺引用 / 数据缺口。
6. **两个特殊文件**：
   - `index.md`（按内容分类）
   - `log.md`（按时间 append-only，用一致前缀方便 grep）
7. **维护成本是关键**：人会因簿记成本超过价值而放弃 wiki，LLM 不会。

## 反直觉点 / 出彩处

- 提示用户"**好答案要回流写成 wiki 页**"——把对话当一次性消费是浪费。
- 把这个想法上溯到 **Vannevar Bush 的 Memex (1945)**：Bush 当年没解决的"谁来维护"问题，LLM 解决了。
- 工具栈极轻：起步只要 markdown + git + Obsidian + 一个 LLM agent；规模上来再考虑 [qmd](https://github.com/tobi/qmd) 之类本地搜索。
- 一份资料触动 **10-15 个 wiki 页** 是正常的——这是 LLM 才扛得起的工作量。
- 文档刻意保持**抽象**：模式不是实现，让你和 LLM 共同实例化。

## 应用场景（原文列举）

- 个人成长（goals / 健康 / 心理）
- 长期研究（论文 / 报告综合）
- 读书伴随 wiki（类似 Tolkien Gateway 但私有）
- 团队/业务内部知识库（Slack / 会议纪要喂入）
- 竞品分析、尽调、旅行规划、课程笔记、爱好深耕

## 工具与小技巧（原文）

- Obsidian Web Clipper（网页 → markdown）
- 本地下载图片（Obsidian 设置 attachment folder + 热键）
- Obsidian 图谱视图看拓扑
- Marp 直接生成幻灯
- Dataview 利用 frontmatter
- 一切都是 git 仓库 → 历史 / 分支 / 协作免费

## 用户评注（待补充）

> 此处留给你写自己的反思：哪些点对你有启发？哪些与你的工作流冲突？要不要在 AGENTS.md 中改写？

---

_本页是 wiki 的"元资料"——它描述了 wiki 自己赖以运转的模式。_
