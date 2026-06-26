# 设计：按需引入前置模组（前置 library / dependency mods）

- 日期：2026-06-26
- 目标 skill：`create-mods`（SKILL.md）
- 触发者：用户提需求做"大型 mod"或需求超出 vanilla/Forge 原生能力时

## 背景与动机

当前 skill 的核心承诺是「做完拿到一个独立 jar，放 mods 文件夹就能用」，整套流程只依赖 vanilla + Forge 原生 API。这对"加把剑、加个方块、加个食物"这类小活儿完全合理。

但当 mod 规模上去（要做 GUI 配置界面、配饰槽、游戏内手册、合成查询兼容等）时，社区里早有成熟前置库（Cloth Config、Curios、Patchouli、JEI、Architectury 等）。从零重造这些轮子既低效又易错——大型 mod 在生态里站前置的肩膀上是社区常态。

本设计在**不破坏 skill 现有灵魂**的前提下，加一条「按需引入前置」的能力。

## 设计目标

1. 让 agent 在需求超出 vanilla/Forge 能力时，能识别该信号、主动提示候选前置。
2. 引入前置时，工程改动正确（build.gradle 依赖、mods.toml mandatory 声明、交付清单）。
3. 第三方前置 API 同样「不靠记忆」——核实手段从 javap（只覆盖 forge jar）延伸到看前置 GitHub 源码/javadoc。
4. vanilla 优先：默认用原生写，前置作为可选进阶项，最终由用户拍板。

## 非目标（YAGNI）

- 不做"每次必做的前置调研"——只按需触发。
- 不做 agent 自动选型/自动写依赖——用户拍板。
- 不内置一个完整的前置百科——只内置一张常见映射表兜底，坐标以联网核实为准。
- 不改造现有 0-5 步主线的 vanilla 路径——小活儿流程零影响。

## 设计决策（已对齐）

| 维度 | 决策 |
|------|------|
| 介入深度 | 提醒 + 候选表 + 联网核实坐标，最终用户拍板 |
| 默认倾向 | vanilla 优先，前置作为可选 |
| 第三方 API 核实 | 看前置 GitHub 源码 / javadoc（不走 javap，因其只覆盖 forge jar） |
| 落点结构 | 渐进式披露：SKILL.md 只留极轻触发指针（一句话 + 触发信号词 + 指向引用文件），重内容全部外置到 `references/prerequisite-mods.md`，仅真触发时才 Read 加载。避免每次调用 skill 都为前置内容付 token |
| 离线兜底 | 联网查不到时退化用内置表坐标，标注"可能过时，构建失败优先怀疑版本号" |

## 具体改动（共 4 处）

> 落点原则：**渐进式披露**。SKILL.md 每次 skill 调用都全量加载，故其中只留**极轻触发指针**；前置的重内容（映射表、工程改动、核实纪律、离线兜底）全部外置到 `references/prerequisite-mods.md`，仅真触发时才 Read。日常小活儿零额外 token 开销。

### 改动 1：SKILL.md 第 0 步加极轻触发指针

在第 0 步「第六问」段加一条**一句话**触发判断（不展开内容，只给信号词 + 指向引用文件）：

> **当需求超出原版/Forge 能力时**（GUI 配置界面 / 配饰槽 / 游戏内手册 / 合成查询兼容 / 多方块机器 / 自定义矿物世界生成 等），停下，**Read `references/prerequisite-mods.md`** 看「自己用原版写 vs 引入前置」的利弊，默认倾向原版原生，用户拍板再决定。不命中就跳过，不影响小活儿流程。

这条只占几行 token，是触发到引用文件唯一的入口。

### 改动 2：新建 `references/prerequisite-mods.md`（承载全部重内容）

新建此文件，集中放前置全貌。**只有改动 1 的触发条命中时才被 Read，平时不进上下文**：

**(a) 需求 → 候选前置映射表**（内置兜底，标注"1.20.1-Forge 适用性 / 版本号请联网核实"）

| 需求信号 | 常见候选前置 |
|---|---|
| GUI 配置界面 | Cloth Config（+ Configured 图形化） |
| 额外装备槽 / 配饰 | Curios API |
| 游戏内手册 / 说明书 | Patchouli |
| 物品/方块/配方合成查询兼容 | JEI |
| 大型 mod 跨平台/底层 API | Architectury |

> 表为兜底常识，仅覆盖常见信号。表未覆盖的需求（如自定义矿物世界生成），触发后同样联网自查候选前置。查到后用 WebSearch 联网核实：该前置是否支持 1.20.1 + Forge、最新版本号、maven 坐标，再写进 build.gradle。查不到（离线/冷门）则退化用上表坐标并标注"可能过时，构建失败优先怀疑版本号"。

**(b) 引入前置后的工程三处改动**

1. `build.gradle` 的 `dependencies` 块加：
   ```gradle
   implementation fg.deobf("前置group:前置artifact:版本号")
   ```
2. `META-INF/mods.toml` 加 mandatory 依赖声明（不声明 → 玩家不装前置直接崩）：
   ```toml
   [[dependencies.<modid>]]
       modId="前置modid"
       mandatory=true
       versionRange="[版本,)"
       ordering="NONE"
       side="BOTH"
   ```
3. 交付物多一条：jar **不再独立可用**，须附"玩家须同时安装的前置清单"。

**(c) 第三方前置 API 核实纪律**

skill 灵魂「Forge API 不靠记忆，必须核实」延伸到前置：前置 API 不在 javap 脚本覆盖的 forge jar 里，**用前置前看其 GitHub 源码 / javadoc 核实真实签名**，同样不靠记忆。

**(d) 离线兜底说明**

环境无网或前置冷门查不到坐标时，退化用内置表坐标并标注风险；构建失败时版本号是第一怀疑对象。

### 改动 3：SKILL.md 的 Common Mistakes 补一行

| 错误 | 原因 | 修复 |
|------|------|------|
| 引入前置却没在 mods.toml 声明 mandatory 依赖 | 漏配 | 玩家没装前置直接崩，必须声明 `[[dependencies.<modid>]]` + `mandatory=true` |

### 改动 4：Red Flags 补一条

- 需求明显超出 vanilla（要做配置界面 / 配饰槽 / 游戏内手册），却埋头从零写、没考虑前置 → 停下，看「前置模组（按需）」映射表，把利弊摆给用户。

## 对 skill 灵魂的影响

- vanilla 路径零改动，"独立 jar 放 mods 就能用"承诺对小活儿不变。
- 引入前置是用户知情后拍板，且明确标注"jar 不再独立"——承诺被诚实降级，而非悄悄破坏。
- 「不靠记忆」纪律延伸到前置（核实手段从 javap 扩展到 GitHub 源码/javadoc），灵魂不被开口子。

## 验证标准

- SKILL.md 第 0 步触发条**极轻**（一句话 + 信号词 + 指向 `references/prerequisite-mods.md`），不展开前置内容。
- `references/prerequisite-mods.md` 新建，含：映射表（5 个前置）、工程三处改动、第三方核实纪律、离线兜底说明，四部分齐全。
- Common Mistakes + Red Flags 各补对应条目（这两条很短，留 SKILL.md 不外置）。
- 现有 0-5 步 vanilla 主线无破坏性改动。
