# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库性质

这不是一个可构建的代码项目，而是一个 **Claude Code skill 单文件仓库**：整个仓库只有 `SKILL.md`。没有构建系统、没有测试、没有依赖。

`SKILL.md` 定义的 skill 名为 `create-mods`，用于**从零创建 Minecraft 1.20.1 + Forge 47.x 的 mod**（加物品/自定义 Tier/剑/配方/贴图）。skill 本身不生成代码到本仓库——它指导 Claude 在**用户的目标 mod 目录**里产出 Forge 工程。所以本仓库的"开发"就是**编辑 `SKILL.md` 这个 skill 定义本身**。

## 编辑 SKILL.md 时的不变量

`SKILL.md` 里的所有 API 事实都来自对真实 jar 跑 `javap` 的核实，不是凭记忆写的。修改时必须遵守：

- **版本锁定**：skill 是 1.20.1 + Forge 47.x 专用。不要把 NeoForge / 1.20.2+ / Fabric 的事实混进来。版本警告段（`⚠️ 版本警告`）是 skill 的第一道闸门，保持置顶。
- **API 速查表（`1.20.1 API 速查`）的每一条都是 javap 验证过的**：改任何一条（如 `SimpleTier` 不存在、`TierSortingRegistry.registerTier` 签名、`SwordItem` 构造器、配方用 `"item"` 而非 `"id"`）前，必须重新 javap 真实 jar 核实，不能凭记忆改。
- **核心纪律**：`javap 核实 API` 是整份 skill 的灵魂——来自真实失败（凭记忆写 Tier 连踩 3 坑）。这条纪律和"鸡生蛋问题"（mapped jar 首次 build 才物化）的解释不能删。
- 保持 `Common Mistakes` 与 `Rationalizations` 表：它们是 skill 自我校验机制，对应 Red Flags 行为约束。

## 关键约束（使用 skill 时）

- 目标 Java 17（`build.gradle` 工具链锁定，靠 foojay 自动下载，不随本机 JDK 改）。
- 贴图必须 **16×16 透明 PNG**，用 PIL 程序化生成，不用 AI 文生图。
- 攻击力数值反推公式：`attackDamageModifier = 目标显示攻击力 - 1 - Tier.getAttackDamageBonus()`。
- 4 环节命名链必须一致：注册名 ↔ 模型文件 ↔ 模型内 `layer0` ↔ 贴图文件名。

## 验证 skill 改动

没有自动测试。验证方式是通读 `SKILL.md` 检查：API 事实仍与 1.20.1 一致、版本警告未被弱化、纪律段完整。若改动涉及具体 API 签名，按 skill 自身要求 javap 复核后再落笔。
