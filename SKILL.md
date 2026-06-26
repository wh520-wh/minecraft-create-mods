---
name: create-mods
description: Use when creating or extending a Minecraft Forge mod from scratch — adding any in-game content (items, tools, weapons, blocks, food, armor, custom tool tiers/Tier, recipes, textures, lang, creative tabs) or building/fixing the project. Only for Minecraft 1.20.1 + Forge 47.x. Do not use for Fabric/NeoForge or other MC versions without re-verifying every API.
---

# Create Mods (Minecraft Forge 1.20.1)

## ⚠️ 版本警告（调用时先看这里）

**本 skill 针对 Minecraft 1.20.1 + Forge 47.x 专用。** Forge API 在不同 MC 版本之间差异巨大——1.20.2+ 用 `SimpleTier` + `TagKey<Block>`，1.20.1 用 `getLevel()` 整数挖掘等级。**用户调用本 skill 时，先确认目标版本：**

- 若用户说 1.20.1 + Forge → 本 skill 直接适用。
- 若用户说别的版本/加载器（Fabric、NeoForge、1.21 等）→ **停下，明确告诉用户本 skill 是 1.20.1-Forge 专用，版本不符不能照搬**，问是否仍按 1.20.1 走或另寻办法。

不要把本 skill 的 API 事实套用到其他版本。每个版本都要重新核实。

## Overview

从空目录做出一个能编译的 Forge 1.20.1 mod。核心纪律一句话：

> **Forge API 绝不靠记忆猜，必须用 `javap` 核实缓存里的真实 jar。**

这条纪律来自真实失败：凭记忆写自定义 Tier，连续踩 3 个坑（`SimpleTier` 不存在、方法名 `register` 错、签名错），全是"凭训练印象套用了较新版本 API"。子 agent 一次过的唯一原因也是它主动 javap 核实了。所以——**写任何 Forge API 调用前，先 javap 看真实签名**。

## When to Use

- 从零创建 Forge 1.20.1 mod
- 给现有 Forge 1.20.1 mod 添加任意游戏内容（物品、工具、武器、方块、食物、盔甲、自定义 Tier、配方、贴图、语言文件、创造标签页）
- mod 编译失败、怀疑是 Forge API 用错时

不用于：Fabric/NeoForge、非 1.20.1 版本、纯 datapack（那是另一套）。

## Core Discipline: javap 核实 API

写涉及 Forge/vanilla 类的代码前，对真实 jar 跑 javap 看签名。`javap` 通常不在 PATH，定位到 JDK 安装目录：

```bash
# 一键对账 6 条 API 事实（首选，仓库已固化）：
bash scripts/javap-verify.sh

# 手动 javap 看任意类（教学/排查用，按实际 JDK 路径）：
JAVAP="/c/Program Files/Java/jdk-21/bin/javap.exe"
JAR=~/.gradle/caches/forge_gradle/minecraft_user_repo/net/minecraftforge/forge/1.20.1-47.3.0_mapped_official_1.20.1/forge-1.20.1-47.3.0_mapped_official_1.20.1.jar
"$JAVAP" -cp "$JAR" -p net.minecraftforge.common.TierSortingRegistry
"$JAVAP" -cp "$JAR" -p net.minecraft.world.item.Tier
```

jar 路径里的 `forge_version` 与 `gradle.properties` 一致；`official_1.20.1` 段随 `mapping_channel`/`mapping_version` 变（parchment 映射下路径不同）。

**鸡生蛋问题（重要）**：那个 mapped jar **全新工程里不存在**，要等 ForgeGradle 第一次解析 `minecraft` 依赖（首次 `./gradlew compileJava` 或 `build`）才生成。所以正确顺序是：
1. 写一个能编译的**极简主类**（只 `@Mod` + 空 `DeferredRegister`，不含任何待核实的 Tier/SwordItem 调用）
2. 跑 `./gradlew compileJava` 物化 jar（首次约 7 分钟）
3. javap 核实 Tier / SwordItem / TierSortingRegistry 等真实签名
4. 再写完整 Tier/物品代码

机器若有旧缓存（jar 已在）可跳过 1-2。判断方法：`ls "$JAR"` 看在不在。

**铁律：看到一个类不确定有哪些方法/构造器/字段，就 javap 它。一次 javap 顶十次盲猜。**

注：`javap -p` 默认不打印注解（如 `@Deprecated`）。要确认某方法是否废弃，用编译期 `-Xlint:deprecation` 告警验证。

## JDK / 工具链（版本地雷的另一维度）

- Forge 1.20.1 **目标 Java 17**。`build.gradle` 里 `java.toolchain.languageVersion = JavaLanguageVersion.of(17)`——实际编译走 JDK 17 工具链，靠 `settings.gradle` 的 `foojay-resolver-convention` 插件**自动下载**，不依赖你本机装的 JDK 版本。
- `gradlew` 可在 JDK 21 上**启动**，但需 **Gradle wrapper ≥ 8.5**。47.3.0 MDK 自带 8.8 没问题；若用旧 MDK（带 8.1.1）在 JDK 21 上会炸。开发机装 JDK 17 或 21 都行。
- 不要因为本机是 JDK 21 就改 `build.gradle` 的工具链版本——保持 17。

## 流程

### 0. 动工前五问：先对齐再动手

接到需求后**不要立刻敲代码**。先在脑里过一遍这五个问题，然后用大白话向用户复述确认，用户点头了再进第 1 步。这一步是为了避免"做出来不是你想要的"。

| 拷问 | 要想清楚什么 | 复述时怎么说 |
|------|-------------|-------------|
| ① 你到底要什么 | 把需求翻译成清晰目标：加什么内容（物品/工具/方块/食物/盔甲…）、几个、放哪个创造标签页、有没有特殊属性（耐久、攻击力等） | "你要的是一个 XX，耐久 X，放在 XX 标签页" |
| ② 大概分几步 | 搭骨架→改配置→写源码→资源→构建验证，五步 | "我大概分五步：搭工程、填信息、写代码、配资源、编译验证" |
| ③ 做出来啥效果 | 一个能 build 出 jar、塞进 mods 文件夹就能在游戏里用的 mod | "做完你能拿到一个 jar，放 mods 文件夹，进游戏就能用" |
| ④ 用到什么工具 | Forge MDK、Gradle、javap、PIL（贴图） | "用到官方 MDK 起步、Gradle 编译、PIL 画贴图" |
| ⑤ 要不要生成贴图 | 大部分自定义内容都要贴图（16×16 透明 PNG）；没图会显示紫黑方块 | "要给这个内容画贴图吗？要的话我用程序画一个 16×16 透明图" |

> 上表右列只是示范复述口径，请按用户真实需求替换（比如用户要做剑，才提攻击力；做方块就不提）。

**第六问——最该提醒的注意事项**（复述时主动说，别等用户问；按需求挑相关的说）：

- 版本锁死：本 skill 只做 1.20.1 + Forge。你要是 1.21 或别的加载器，我得先停下确认。
- 首次编译慢：第一次 build 要下反编译产物，约 7 分钟，后面就快了。
- API 我不靠记忆：涉及 Forge 类我会先 javap 核实真实 jar，不猜。
- 数值换算（涉及武器/工具时才提）：你给的"攻击力 30"等是游戏 UI 显示值，我会反推成代码里的 modifier，公式见下「攻击力数值拆算」。

复述完等用户确认"对，就这样"。需求不清或有多种解读时，**宁可多问一轮也别返工**。

---

### 1. 搭骨架：下载官方 MDK，不要手写

`gradle-wrapper.jar` 是二进制，手写不了。下载官方 MDK（自带可用 wrapper）：

```bash
curl -L -o mdk.zip "https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-<FORGE_VER>/forge-1.20.1-<FORGE_VER>-mdk.zip"
unzip -t mdk.zip >/dev/null 2>&1 || { echo "✗ mdk.zip 下载不完整或损坏，删除后重新下载"; rm -f mdk.zip; exit 1; }
unzip -o mdk.zip -d <目标目录>
```

> **下载后必须校验**：`unzip -t` 测试 zip 完整性。curl 偶尔断在半截，损坏的 zip 解压会爆不明错误；校验失败就删掉重下，别拿坏 zip 往下走。

> 若该 maven 路径 404（偶发），从 https://files.minecraftforge.net/ 找对应版本 MDK 直链。

### 2. 改 gradle.properties 里的 mod 信息

改这几个占位值（其他保持）：

| 字段 | 说明 |
|------|------|
| `mod_id` | 全小写，匹配主类 `@Mod("...")`，如 `moresword` |
| `mod_name` | 显示名 |
| `mod_license` | 如 `MIT` |
| `mod_group_id` | 包名前缀，如 `com.moresword`，与 src 包路径一致 |
| `forge_version` | 与用户游戏对齐 |

`build.gradle` 不要硬编码 mod_id——它读 gradle.properties 占位符，故无需改。

### 3. 写 Java 源码（按内容类型分叉）

**先删 MDK 自带的示例代码**（所有类型都要做）：删掉 `src/main/java/com/example/` 整个目录（含 `examplemod/` 下的 ExampleMod.java、Config.java）。不删的话 `@Mod("examplemod")` 与你改后的 mod_id 不符，mod 加载会出问题。

包路径对应 `mod_group_id`，如 `com/moresword/`（新建目录，别用残留的 com/example/）。

**主类**（`@Mod(MODID)`，所有类型都要写）：创建 mod 事件总线、`register` 各 DeferredRegister、监听 `BuildCreativeModeTabContentsEvent` 把内容塞进创造标签页。

**然后按要加的内容类型选写法**（不是所有 mod 都只有物品/Tier——做方块、食物、盔甲是不同的类和资源）：

| 内容类型 | 注册方式 | 关键点 |
|---------|---------|--------|
| 物品/工具/武器 | `DeferredRegister<Item>` + `ITEMS.register("xxx", () -> new Item/SwordItem(...))` | 自定义武器等级见下「自定义 Tier」；非武器普通物品用 `new Item(props)` |
| 方块 | `DeferredRegister<Block>` + 对应的 `BlockItem`（方块本身不进背包，要靠 BlockItem） | 方块还需 blockstate/models 方块状态 JSON，命名链比物品多一层 |
| 食物 | `DeferredRegister<Item>`，构造时带 `FoodProperties` | 食物本质是带食用属性的 Item，注册走 Item 通道 |
| 盔甲 | `DeferredRegister<Item>` + `ArmorItem` + 自定义 `ArmorMaterial` | 盔甲材质注册和 Tier 类似，1.20.1 API 也要 javap 核实 |

> 上表只给方向。**涉及具体类（BlockItem / FoodProperties / ArmorMaterial 等）的构造器和字段，先 javap 核实真实签名再写，不靠记忆**——这是本 skill 铁律。本 skill 已核实并写进速查表的只有 Tier/SwordItem/TierSortingRegistry（见下），其余类型自行核实。

**自定义 Tier**（仅武器/工具需要）：1.20.1 **没有 `SimpleTier`**（那是 NeoForge 1.20.2+）。直接 `implements net.minecraft.world.item.Tier`，实现 6 个方法（见下速查）。

### 4. 资源文件（命名空间 = mod_id）

> 下面是**物品/工具/武器**的资源结构。方块还需 `blockstates/` 和 `models/block/`（方块状态 JSON），盔甲还需贴图分层——这些类型的资源结构不同，按需补，并先核实 1.20.1 的具体路径约定。

```
src/main/resources/
├── META-INF/mods.toml          # MDK 自带，走占位符，无需改
├── pack.mcmeta
├── assets/<modid>/
│   ├── lang/{en_us,zh_cn}.json   # 键格式 item.<modid>.<name>
│   ├── models/item/<name>.json   # parent: minecraft:item/handheld
│   └── textures/item/<name>.png  # 必须 16×16 PNG 透明背景
└── data/<modid>/recipes/<name>.json
```

物品显示需 4 环节命名完全一致：注册名 `emerald_sword` ↔ 模型文件 `models/item/emerald_sword.json` ↔ 模型内 `layer0: <modid>:item/emerald_sword` ↔ 贴图 `textures/item/emerald_sword.png`。任一不一致 → 游戏里紫黑方块或显示原始键。

**配方示例**（仿钻石剑摆法，1.20.1 用 `"item"` 不是 `"id"`）：

```json
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["E", "E", "S"],
  "key": {
    "E": { "item": "minecraft:emerald" },
    "S": { "item": "minecraft:stick" }
  },
  "result": { "item": "<modid>:emerald_sword", "count": 1 }
}
```

### 5. 构建与验证产物

```bash
./gradlew build      # 产物 build/libs/<modid>-<ver>.jar，可直接放 mods 文件夹
./gradlew runClient  # 开发环境实测
```

首次 build 下载反编译产物较慢（约 7 分钟），后续增量快。

**构建后必须验证产物**（一个能 build 但占位符没展开的 mod 进游戏不加载）：

> 一键校验产物合规（贴图/pack_format/配方/命名链）：`bash scripts/check-mod-output.sh <mod工程根目录>`

```bash
# 1. 看 jar 内容齐全：3 个源类 class + lang/model/texture/recipe + mods.toml + pack.mcmeta
jar tf build/libs/<modid>-<ver>.jar | sort

# 2. 抽查 mods.toml 占位符已展开（不能有 ${mod_id} 这种残留）
unzip -p build/libs/<modid>-<ver>.jar META-INF/mods.toml | grep modId
# 期望：modId="<你的modid>"，不是 modId="${mod_id}"

# 3. pack.mcmeta 的 pack_format 对 1.20.1 必须是 15
unzip -p build/libs/<modid>-<ver>.jar pack.mcmeta | grep pack_format
```

## 1.20.1 API 速查（已 javap 核实，仍建议用时复核）

| 项 | 1.20.1 事实 |
|----|------------|
| `SimpleTier` | **不存在**。自定义 Tier 直接 `implements Tier` |
| `Tier` 接口 abstract 方法 | `getUses()` `getSpeed()` `getAttackDamageBonus()` `getLevel()` `getEnchantmentValue()` `getRepairIngredient()`（6 个，全要实现） |
| `Tier.getTag()` | default 方法，可不实现 |
| `Tier.getLevel()` | `@Deprecated` 但仍是 abstract，必须实现（警告无害） |
| `TierSortingRegistry.registerTier` | 签名 `registerTier(Tier, ResourceLocation, List<Object>, List<Object>)`——注意是 `registerTier` **不是** `register`，必须传 `ResourceLocation` 名字，`List<Object>` 可直接 `List.of(Tiers.DIAMOND)` |
| `SwordItem` 构造器 | `SwordItem(Tier tier, int attackDamageModifier, float attackSpeedModifier, Item.Properties)` |
| `TierSortingRegistry.registerTier` 静态初始化 | 必须在剑构造前执行——放在 `ModTiers` 的 `static {}` 块即可，别放错位置 |
| 创造标签页事件 | 监听 `BuildCreativeModeTabContentsEvent`：`event.getTabKey()` 返回 `ResourceKey<CreativeModeTab>`，用 `event.accept(RegistryObject<Item>)` 塞物品（靠 `accept(Supplier<? extends ItemLike>)` 重载适配，不是 `accept(ItemLike)`；后者继承自 `CreativeModeTab.Output`，单 javap 事件类会漏看） |
| 配方 JSON 格式 | 1.20.1 用 `"item": "minecraft:xxx"`（1.21 起改成 `"id"` 且配料多用 tag）——这是和 SimpleTier 同级的版本地雷 |
| 武器显示攻击力公式（剑/武器） | `玩家基础(1) + Tier.getAttackDamageBonus() + attackDamageModifier` |

## 贴图：必须 16×16 透明 PNG

> 贴图规格可一键校验：`bash scripts/check-mod-output.sh <工程>` 会查所有 item 贴图是否 16×16 透明 PNG。

Minecraft 物品贴图规格：**16×16 像素、PNG、透明背景**。AI 文生图（如 minimax）生成的图几乎都不满足——尺寸不对、背景非透明、剑不居中。

可靠做法：用 PIL 程序化画 16×16 透明 PNG。示例骨架：

```python
from PIL import Image
img = Image.new("RGBA", (16, 16), (0,0,0,0))  # 全透明
img.putpixel((x, y), (R,G,B,255))             # 逐像素上色
img.save("src/main/resources/assets/<modid>/textures/item/<name>.png")
```

不要把图片塞进对话（无多模态能力）。只生成、保存、用 `ls` 确认大小。

## 攻击力数值拆算（以剑/武器为例，非通用纪律）

> 这一节针对武器类内容。做方块、食物、普通物品时跳过本节。

用户给"攻击力 30"指 UI 显示总伤害。反推 `attackDamageModifier`：

```
attackDamageModifier = 目标显示攻击力 - 玩家基础(1) - Tier.getAttackDamageBonus()
```

例：Tier 加成照搬钻石 3.0，要显示 30 → `modifier = 30 - 1 - 3 = 26`。改攻击力改 modifier，改耐久改 `getUses()`。

## Common Mistakes

| 错误 | 原因 | 修复 |
|------|------|------|
| `SimpleTier` 找不到 | 套用了 NeoForge 1.20.2+ API | 直接 `implements Tier` |
| `TierSortingRegistry.register` 找不到 | 方法名错 | 用 `registerTier`，加 `ResourceLocation` |
| 游戏里紫黑方块 | 贴图/模型/注册名不一致 | 核对 4 环节命名链 |
| 物品名显示成 `item.xxx.yyy` 原文 | 语言文件键不对 | 键须 `item.<modid>.<name>` |
| 凭记忆写 API 编译反复失败 | 没核实版本 | **javap 真实 jar** |
| 贴图加载报错 | 尺寸非 16×16 或非 PNG | PIL 生成合规贴图 |

## Rationalizations（别给自己找借口）

| 借口 | 现实 |
|------|------|
| "我熟悉 Forge API，不用查" | 1.20.1 与较新版本差异大，记忆会骗你。javap 一次几秒 |
| "这个类我记得有这个方法" | 记得≠对。版本一变方法就没了。必须 javap |
| "先写代码，编译错了再查" | 每次盲改都浪费一轮 12s+ 编译。先查再写更快 |
| "贴图先用 AI 图凑合" | 非透明/非 16×16 会报错或显示异常。PIL 规范生成 |

**Red Flags——看到这些停下：**
- 准备写一个不确定的 Forge 类调用，却没先 javap
- 准备套用 `SimpleTier` / `register(`（1.20.1 没有）
- 用户说的版本不是 1.20.1 + Forge，却想直接套本流程
- 拿 AI 生成的图直接当贴图，没转 16×16 透明 PNG

**这些意味着：停下，回到 javap 核实 / 确认版本 / 用 PIL 生成贴图。**
