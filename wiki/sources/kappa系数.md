---
title: Kappa系数：AI评测一致性指标解析
type: source
description: 详细解释Cohen's Kappa和Fleiss' Kappa的计算原理、公式推导和数值演示，聚焦AI模型人工评测场景中如何用Kappa衡量评测员间一致性
resource: ""
tags: [kappa系数, cohen-kappa, fleiss-kappa, ai评测, 一致性, 统计方法]
created: 2026-08-17
updated: 2026-08-17
raw_path: raw/notes/kappa系数.md
confidence: EXTRACTED
status: stable
images: 0
image_paths: []
---

# Kappa系数：AI评测一致性指标解析

## TL;DR

- Kappa系数 = 扣除"碰巧一致"后的真实评测员间一致性，解决"高表面一致率可能只是随机"的问题
- Cohen's Kappa 用于恰好2名评测员；Fleiss' Kappa 用于≥2名评测员；Weighted Kappa 用于有序等级评分
- Kappa < 0.4 一致性较差，评测结论不可信；≥ 0.61 属于较强一致性
- AI评测中的实际意义：不能只说"人工评测A比B好"，还必须证明评测标准稳定（Kappa足够高）

## 核心论点

- **核心公式**：κ = (Po - Pe) / (1 - Pe)，Po为实际一致率，Pe为随机期望一致率
- **关键直觉**：实际一致率85%未必好，如果随机情况下本来就有51%一致，真实收益只有34%
- **AI评测推荐**：多人评同一批数据，直接用 Fleiss' Kappa 即可
- **Kappa不足时的对策**：明确评分标准、提供样例、做评测员校准训练

## Kappa解读标准

| Kappa值 | 一致性 |
|---------|--------|
| < 0 | 比随机还差 |
| 0 ~ 0.20 | 很弱 |
| 0.21 ~ 0.40 | 较弱 |
| 0.41 ~ 0.60 | 中等 |
| 0.61 ~ 0.80 | 较强 |
| 0.81 ~ 1.00 | 很强 |

## 原文精彩摘录

> [!quote]
> 人工评测不能只靠感觉，必须有明确标准、样例、边界说明和评测员校准，否则评测结果噪声很大，没法作为可信结论。
> Source: raw/notes/kappa系数.md §核心含义

## 我的评注

<!-- 待填写 -->
