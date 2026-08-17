---
title: CUPED / CUPAC（协变量调整方法）
type: concept
description: 利用实验前历史数据降低指标方差、提升AB实验统计功效的方法，可将MDE降低50%以上，是提升实验效率的核心统计工具
resource: ""
tags: [ab-testing, cuped, cupac, 方差降低, mde, 统计方法]
created: 2026-08-17
updated: 2026-08-17
sources: ["[[sources/AB实验]]"]
related: ["[[concepts/mde]]", "[[concepts/ab-experiment]]"]
confidence: EXTRACTED
status: stable
---

# CUPED / CUPAC（协变量调整方法）

## 定义

**CUPED**（Controlled-experiment Using Pre-Experiment Data）和 **CUPAC** 是利用实验前的历史信息来**降低指标波动（方差）**，从而降低 [[concepts/mde|MDE]]、提升统计功效的实验方法。

## 核心直觉

同样看用户消费金额，一个用户过去本来就高消费，一个用户过去本来就低消费。如果不控制这些历史差异，实验结果会有很大噪声。

CUPED/CUPAC 的做法：**把用户天然差异扣掉一部分**，只分析相对于各自基线的变化量。

## 价值

- 降低指标方差
- 提升统计功效（Power）
- **降低 MDE 50%+**——这意味着原本需要很大流量才能检测的效果，现在可能用一半甚至更少流量即可判断
- 实验周期可以更短

## 适用场景

特别适合：
- 用户个体差异大的场景（如消费金额、打赏）
- 指标本身波动较大、历史数据充足的场景

## CUPAC

CUPAC 是 CUPED 的扩展版本，在 CUPED 基础上进一步利用更丰富的协变量信息，效果通常优于 CUPED。

> [!quote]
> CUPED/CUPAC 的价值是：把用户天然差异扣掉一部分，降低指标方差，提升统计功效，让小效果也更容易被检测出来。"降低 MDE 50%+"是很强的收益。
> Source: [[sources/AB实验]] §CUPED章节
