<div align="center">

# create-mods

> *「凭记忆写 Forge API 会连踩 3 个坑——这个 skill 让你先 javap 真实 jar，再下笔。」*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-create--mods-blueviolet)](SKILL.md)
[![Minecraft](https://img.shields.io/badge/Minecraft-1.20.1-green)](https://files.minecraftforge.net/)
[![Forge](https://img.shields.io/badge/Forge-47.x-orange)](https://files.minecraftforge.net/)

**从空目录做出一个能跑的 Minecraft 1.20.1 Forge 模组——每条 API 都经真实 jar 对账。**

[看效果](#效果示例) · [快速开始](#快速开始) · [触发方式](#触发方式) · [它和同类有什么不同](#它和同类有什么不同) · [安全边界](#安全边界) · [验证](#验证与测试)

</div>

---

## 这个 skill 能做什么

一句话：**让 AI 从空目录给你做出一个能在 Minecraft 1.20.1 里直接用的 Forge mod**——不靠记忆猜 API，每一步都能拿游戏真实文件验证。

具体能帮你做这些事：

- **从零搭一个 Forge 1.20.1 mod 工程**：下载官方 MDK、填好 mod 信息、生成主类，不手写二进制 wrapper。
- **添加游戏内容**：注册物品、武器、工具及自定义等级（Tier），塞进创造模式背包。
- **写合成配方**：1.20.1 专用的配方格式（用 `"item"` 不用新版的 `"id"`）。
- **生成合规贴图**：用程序画 16×16 透明 PNG，不用会报错的 AI 文生图。
- **编译并验证产物**：build 出能塞进 mods 文件夹的 jar，再一键校验贴图/格式/命名链全合规。
- **修 Forge API 用错的编译失败**：怀疑 API 写错时，先核实真实签名再改，不盲改。

**不适合**：Fabric / NeoForge、1.21+ 等其他版本、纯 datapack——这些是另一套 API，本 skill 会先拦下来确认版本，不硬套。

---

## 它解决什么问题

事情是这样的：你想给 Minecraft 1.20.1 做个模组——比如加个自定义物品或武器。你问 AI，AI 凭记忆给你写了 `SimpleTier`——编译炸了，因为 **1.20.1 根本没有 `SimpleTier`**（那是 NeoForge 1.20.2+ 的）。你让它改，它又把 `TierSortingRegistry.registerTier` 写成 `register`——又炸。每个版本 Forge API 都在漂移，AI 的训练记忆会骗你，一轮盲改就浪费 12 秒+ 编译。

普通做法为什么不行：MCreator 是 GUI，界面劝退一半人；官方 MDK 是模板，新手仍要自己啃 API；其他"AI mod skill"要么空壳、要么吹覆盖五个 loader 却没代码。

这个 skill 换了什么思路：**绝不靠记忆猜 Forge API，写任何调用前先对真实 jar 跑 `javap` 看签名。** 这条铁律来自真实失败——凭记忆写 Tier 连踩 3 坑。子 agent 一次过的唯一原因，也是它主动 javap 核实了。所以这个 skill 把"先核实再下笔"立成纪律，并把核实动作固化成任何人一键可跑的脚本。

> ⚠️ **版本锁死**：本 skill 只认 **Minecraft 1.20.1 + Forge 47.x**。Fabric / NeoForge / 1.21+ 是另一套 API，不能照搬——触发时会先拦你确认版本。

---

## 效果示例

**信任底座**——`scripts/javap-verify.sh` 在真实 1.20.1-47.3.0 jar 上跑出的对账（任何人可复现）：

```
对账 6 条 Forge 1.20.1 API 事实
  PASS  SimpleTier 在 1.20.1 不存在（javap 退出码非0）
  PASS  Tier 接口 6 abstract 方法齐全 + getTag default
  PASS  registerTier 签名 (Tier,ResourceLocation,List,List)，是 registerTier 不是 register
  PASS  SwordItem 构造器 (Tier,int,float,Item.Properties)
  PASS  事件 accept 有 Supplier 重载；getTabKey 返回 ResourceKey
  PASS  Tier.getLevel 带 @Deprecated 但仍 abstract（必须实现，警告无害）
结果：PASS 15 / FAIL 0
```

完整原始输出见 [`examples/verify-report.md`](examples/verify-report.md)。

**skill 产出的合规贴图**——16×16、透明背景、PIL 程序化生成（不是 AI 文生图）：

![emerald_sword 贴图](examples/emerald_sword_mod/src/main/resources/assets/moresword/textures/item/emerald_sword.png)

<sub>16×16 透明 PNG，左上角 alpha=0。规格自检脚本见 skill 流程第 4 步。</sub>

---

## 快速开始

```bash
git clone https://github.com/wh520-wh/minecraft-create-mods ~/.claude/skills/create-mods
```

> Windows 下 `~/.claude/skills/` 实际是 `C:\Users\<你>\.claude\skills\`。

装完对 Agent 说：

```text
帮我做一个 Minecraft 1.20.1 Forge 的 mod，加一把绿宝石剑，攻击力显示 30，耐久 2000。
```

Agent 会：确认版本 → 下载官方 MDK → 改 gradle.properties → 写主类/自定义 Tier/物品注册 → 生成 lang/model/recipe/贴图 → 构建并验证产物，过程中对不确定的 API 跑 javap 核实。

> 仓库地址：https://github.com/wh520-wh/minecraft-create-mods

---

## 触发方式

- "帮我做一个 Minecraft 1.20.1 Forge 的 mod，加一把 XX 剑"
- "给这个 Forge mod 加个自定义 Tier 的武器，攻击力 X"
- "我的 Forge 1.20.1 mod 编译报错，怀疑 API 用错了"
- "帮我加个自定义物品和合成配方"
- "这把剑的贴图怎么做成游戏能识别的"
- "1.20.1 自定义 Tier 该实现哪些方法"

---

## 它和同类有什么不同

| 维度 | 其他 AI mod skill | 官方 MDK | MCreator | **create-mods** |
|---|---|---|---|---|
| 版本锁定 | 多 loader 全覆盖却常空壳 | 锁版本但无引导 | 锁版本、GUI | **锁死 1.20.1+Forge，负触发明确** |
| API 准确性 | 凭记忆，常踩版本坑 | — | — | **每条 API 对真实 jar 跑 javap 对账** |
| 可验证性 | 无 | 无 | 无 | **`javap-verify.sh` 一键复现 15 条 PASS** |
| 形态 | — | 模板 | GUI | 对话式，零界面 |
| 适合谁 | — | 老手 | 新手/教育 | 被界面劝退、又懒得啃 API 的人 |

差异不讲"功能多"，讲"**说的每句话都能验**"——这是访行里没有任何同行做到的深度。

---

## 安全边界

- **不会**在未确认版本前，把 1.20.1 的 API 套用到其他版本——版本不符会停下问你。
- **不会**用 AI 文生图当贴图——尺寸/透明度几乎都不合规，统一用 PIL 生成 16×16 透明 PNG。
- **不会**改 `build.gradle` 的 Java 工具链版本（锁 17，靠 foojay 自动下载）。
- **不会**手写 `gradle-wrapper.jar`（二进制，手写不了）——一律从官方 MDK 取。
- 涉及下载 MDK、跑 `./gradlew build` 这类操作会先说明再做。

---

## 文件结构

```
create-mods/
├── SKILL.md                 # skill 本体：版本警告 + javap 核实纪律 + 五问对齐 + 流程 + API 速查表
├── scripts/
│   ├── javap-verify.sh      # 一键对账 6 条 API 事实，输出 PASS/FAIL（信任底座）
│   └── check-mod-output.sh  # 校验 mod 产物合规：贴图规格/pack_format=15/配方字段/命名链
├── examples/
│   ├── verify-report.md     # javap-verify 真实输出存档（15 PASS）
│   └── emerald_sword_mod/   # 示例产物：合规 16×16 透明剑贴图
├── test-prompts.json        # 3 条验收 prompt + 合格表现
├── LICENSE                  # MIT
└── README.md
```

---

## 验证与测试

```bash
bash scripts/javap-verify.sh                          # 期望：PASS 15 / FAIL 0，退出码 0
bash scripts/check-mod-output.sh examples/emerald_sword_mod   # 期望：四项全 PASS，退出码 0
```

验收 prompt 见 [`test-prompts.json`](test-prompts.json)，三条覆盖：冒烟（生成绿宝石剑）、版本闸门（拦 1.21/NeoForge）、核实纪律（答 API 前先 javap）。

合格表现：触发版本确认 → 用 MDK 不手写 → `implements Tier` 不出现 `SimpleTier` → `registerTier` 不写成 `register` → 攻击力反推 `modifier = 显示值 - 1 - getAttackDamageBonus()` → PIL 生成贴图 → 构建后验证 jar/占位符/pack_format=15。

---

## 致谢

- [Minecraft Forge](https://files.minecraftforge.net/) —— 官方 MDK 是 skill 流程的起点。
- Forge API 事实全部由 `javap` 对真实 jar 核实得出，非训练记忆。
- 方法论受 obra/superpowers「先验证再下笔」的工程纪律启发。

---

## License

[MIT](LICENSE)
