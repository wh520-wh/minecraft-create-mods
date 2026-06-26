# 前置模组（按需）

> 本文件仅在第 0 步触发条命中、需求超出原版/Forge 能力时才被 Read。小活儿（加把剑、加个方块）用不上，跳过。

## 先说取舍

引入前置 = 站在成熟轮子的肩膀上省工作量，代价是**你的 jar 不再独立**——玩家必须同时装那个前置，否则游戏崩。所以默认倾向原版原生；只有当原生写起来明显不划算（如自己撸 GUI 配置界面）时才考虑前置。最终用户拍板。

## 需求 → 候选前置映射表（内置兜底）

| 需求信号 | 常见候选前置 |
|---|---|
| GUI 配置界面 | Cloth Config（+ Configured 图形化） |
| 额外装备槽 / 配饰 | Curios API |
| 游戏内手册 / 说明书 | Patchouli |
| 物品/方块/配方合成查询兼容 | JEI |
| 大型 mod 跨平台 / 底层 API | Architectury |

> 表为兜底常识，仅覆盖常见信号。表未覆盖的需求（多方块机器、自定义矿物世界生成等），触发后同样联网自查候选前置。表里的前置是否支持 1.20.1 + Forge、最新版本号、maven 坐标，**都必须用 WebSearch 联网核实**再写进 build.gradle——坐标会随版本变，别凭记忆。

## 离线兜底

环境无网或前置冷门查不到坐标时，退化用映射表里的坐标并标注"可能过时，构建失败优先怀疑版本号"。版本号始终是第一怀疑对象。

## 引入前置后的工程三处改动

**① `build.gradle` 的 `dependencies` 块加依赖**（用 `fg.deobf` 自动反混淆）：

```gradle
dependencies {
    minecraft "net.minecraftforge:forge:${mc_version}-${forge_version}"
    // 前置（坐标以联网核实为准）
    implementation fg.deobf("前置group:前置artifact:版本号")
}
```

**② `META-INF/mods.toml` 加 mandatory 依赖声明**——不声明，玩家没装前置会直接崩：

```toml
[[dependencies.<modid>]]
    modId="前置modid"
    mandatory=true
    versionRange="[版本号,)"
    ordering="NONE"
    side="BOTH"
```

**③ 交付物多一条**：jar **不再独立可用**，须附"玩家须同时安装的前置清单"（前置名 + 下载页 + 版本号）。

## 第三方前置 API 核实纪律

skill 铁律「Forge API 绝不靠记忆，必须核实」延伸到前置：前置的 API **不在 javap 脚本覆盖的那个 forge jar 里**（脚本只查 forge），所以前置 API 不能靠 javap。**用前置前，看它的 GitHub 源码 / javadoc 核实真实签名**——同样不靠记忆。一次翻源码顶十次盲猜。
