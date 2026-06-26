# 对账报告 · javap-verify 真实输出存档

> 这不是虚构样例，是 `scripts/javap-verify.sh` 在本机真实 Forge 1.20.1-47.3.0 mapped jar 上
> 跑出的原始输出（2026-06-26）。任何人重跑该脚本都应得到同样的 PASS。
>
> **绿色文档会撒谎，真实 jar 不会。** 这份报告是 create-mods 信任底座的活体证据。

## 环境

- javap：`/c/Program Files/Java/jdk-21/bin/javap.exe`
- jar：`~/.gradle/caches/forge_gradle/minecraft_user_repo/net/minecraftforge/forge/1.20.1-47.3.0_mapped_official_1.20.1/forge-1.20.1-47.3.0_mapped_official_1.20.1.jar`

## 原始输出

```
对账 6 条 Forge 1.20.1 API 事实（SKILL.md 速查表）
──────────────────────────────────────────────────────────────
  PASS  SimpleTier 在 1.20.1 不存在（javap 退出码非0）
  PASS  Tier 接口 6 abstract 方法齐全
  PASS    Tier.getUses 是 abstract
  PASS    Tier.getSpeed 是 abstract
  PASS    Tier.getAttackDamageBonus 是 abstract
  PASS    Tier.getLevel 是 abstract
  PASS    Tier.getEnchantmentValue 是 abstract
  PASS    Tier.getRepairIngredient 是 abstract
  PASS  Tier.getTag 是 default（可不实现）
  PASS  registerTier 签名 (Tier,ResourceLocation,List,List) 且方法名是 registerTier 不是 register
  PASS  SwordItem 构造器 (Tier,int,float,Item.Properties)
  PASS  BuildCreativeModeTabContentsEvent.getTabKey 返回 ResourceKey
  PASS  事件 accept 有 Supplier<? extends ItemLike> 重载
  PASS  Tier.getLevel 带 @Deprecated（常量池含 Deprecated 注解）
  PASS  Tier.getLevel 仍是 abstract（必须实现，警告无害）
──────────────────────────────────────────────────────────────
结果：PASS 15 / FAIL 0
✓ 6 条 API 事实全部经真实 jar 对账通过。
```

## 怎么复现

```bash
bash scripts/javap-verify.sh
```

前提：本机已有一个跑过 `./gradlew compileJava` 的 1.20.1-Forge 工程（mapped jar 已物化）。
全新机器首次约 7 分钟生成 jar，之后秒级重跑。

## 这份报告证明什么

SKILL.md 速查表的每一条——`SimpleTier` 不存在、Tier 的 6 个方法、`registerTier` 签名、
`SwordItem` 构造器、事件 `accept` 重载、`getLevel` 的 `@Deprecated`+abstract——
都不是凭训练记忆写的，而是对真实 jar 对账得出的。这是访行里**没有任何同行做到**的深度。

## 两个脚本分工

- `scripts/javap-verify.sh` —— 核实 **API 事实**（Tier/TierSortingRegistry/SwordItem 等签名），针对真实 Forge jar。
- `scripts/check-mod-output.sh` —— 核实 **mod 产物合规**（贴图/pack_format/配方/命名链），针对 build 出来的工程或 jar。

一个查"API 对不对"，一个查"做出来的东西合不合规"，合起来是 create-mods 的完整信任底座。
