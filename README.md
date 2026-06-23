# llm-wiki

我的个人知识库，基于 [Karpathy 的 llm-wiki 模式](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) 构建。

> Obsidian 是 IDE，LLM 是程序员，wiki 是代码库。

## 核心理念

不是 RAG。**LLM 增量地构建并维护一个持久化的、相互链接的 markdown wiki**，每加入一份新资料，LLM 就把它"编译"进 wiki：更新实体页、修订概念页、标记矛盾、强化或挑战已有综合判断。

- **你的工作**：找资料、提问题、定方向。
- **LLM 的工作**：摘要、交叉引用、归档、簿记 —— 所有让 wiki 真正可用的脏活。

## 目录结构

```
llm-wiki/
├── AGENTS.md          # LLM 操作手册（最重要的一个文件）
├── CLAUDE.md          # → AGENTS.md（软链接，给 Claude Code 用）
├── index.md           # wiki 的内容目录（按类别）
├── log.md             # wiki 演化日志（按时间）
├── raw/               # 原始资料（你写，LLM 只读）
│   ├── articles/
│   ├── papers/
│   ├── books/
│   ├── notes/
│   └── assets/        # 图片等附件
└── wiki/              # LLM 生成的页面（LLM 写，你读）
    ├── entities/      # 人物 / 组织 / 产品 / 项目
    ├── concepts/      # 概念 / 方法 / 模式
    ├── topics/        # 主题综合页
    ├── sources/       # 每份原始资料的摘要页
    └── synthesis/     # 跨主题的综合洞察 / 比较 / 决策
```

## 三个核心操作

1. **Ingest（摄入）**：把新资料丢进 `raw/`，对 LLM 说 `请按 AGENTS.md 摄入 raw/articles/xxx.md`。
2. **Query（提问）**：基于 wiki 提问，好答案要回流写成新页面，不要让它消失在聊天记录里。
3. **Lint（健康检查）**：定期让 LLM 检查矛盾、孤儿页、缺失交叉引用、过时论断。

## 推荐工作流

- 用 [Obsidian](https://obsidian.md/) 打开本仓库作为 vault，开图谱视图。
- 用 [Obsidian Web Clipper](https://obsidian.md/clipper) 浏览器插件把网页一键转 markdown 存到 `raw/articles/`。
- LLM Agent 在一边、Obsidian 在另一边，实时看 LLM 改了什么。
- Wiki 本身就是 git 仓库 —— 版本、分支、协作全免费。

## 起步

读一遍 [`AGENTS.md`](./AGENTS.md)。然后投喂第一份资料：
```
请按 AGENTS.md 的 Ingest 流程，处理 raw/articles/xxx.md
```
