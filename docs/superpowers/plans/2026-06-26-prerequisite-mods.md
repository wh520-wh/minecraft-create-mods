# 按需引入前置模组 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 create-mods skill 的 SKILL.md 里加一条「按需引入前置模组」能力：第 0 步加触发判断、新增一节前置模组、Common Mistakes 与 Red Flags 各补一条。

**Architecture:** 渐进式披露——SKILL.md 只加极轻触发指针（几行），重内容外置到新建 `references/prerequisite-mods.md`，仅真触发时才 Read。这样每次调用 skill 不为前置内容付 token。vanilla 主线零改动。

**Tech Stack:** Markdown（SKILL.md）

**Spec：** `docs/superpowers/specs/2026-06-26-prerequisite-mods-design.md`

---

## 文件结构

- Modify: `SKILL.md` —— 加极轻触发指针（第0步一条）+ Common Mistakes 一行 + Red Flags 一条
- Create: `references/prerequisite-mods.md` —— 承载前置全部重内容（映射表/工程改动/核实纪律/离线兜底），仅触发时 Read

## 编辑前的统一约定

- 所有新增中文段落沿用 SKILL.md 现有语气：直白、带「为什么」、用 `>` 引用块标注提醒。
- 表格列名沿用现有风格（`| xxx | xxx |`）。
- 代码示例用三反引号 + 语言标注（`gradle` / `toml`）。
- 不改动 vanilla 主线 0-5 步的任何现有文字。

---

### Task 1: SKILL.md 第 0 步加极轻触发指针

**Files:**
- Modify: `SKILL.md`（「第六问——最该提醒的注意事项」段的列表里加一条）

> 设计约束：这条要**极轻**（一句话 + 信号词 + 指向引用文件），不展开任何前置内容——SKILL.md 每次全量加载，重内容必须外置。前置详情在 Task 2 创建的 `references/prerequisite-mods.md` 里。

- [ ] **Step 1: 定位插入点**

读 SKILL.md，找到「第六问」段（约 L80-87）：

```markdown
**第六问——最该提醒的注意事项**（复述时主动说，别等用户问；按需求挑相关的说）：

- 版本锁死：本 skill 只做 1.20.1 + Forge。你要是 1.21 或别的加载器，我得先停下确认。
- 首次编译慢：第一次 build 要下反编译产物，约 7 分钟，后面就快了。
- API 我不靠记忆：涉及 Forge 类我会先 javap 核实真实 jar，不猜。
- 数值换算（涉及武器/工具时才提）：你给的"攻击力 30"等是游戏 UI 显示值，我会反推成代码里的 modifier，公式见下「攻击力数值拆算」。

复述完等用户确认"对，就这样"。需求不清或有多种解读时，**宁可多问一轮也别返工**。
```

- [ ] **Step 2: 在"数值换算"那条之后、"复述完"那句之前插入一条极轻指针**

插入内容（只这一条，不展开）：

```markdown
- 前置模组（需求大时才触发）：需求超出原版能做的范围（GUI 配置界面、配饰槽、游戏内手册、合成查询兼容、多方块机器、自定义矿物世界生成 等）时，先停下 Read `references/prerequisite-mods.md`，把"原生写 vs 引前置"的利弊摆给用户，**默认倾向原版原生**，用户拍板。小活儿不命中就跳过。
```

- [ ] **Step 3: 确认指针极轻、不展开内容**

读改动后该条，确认：只一句话、列出信号词、指向 `references/prerequisite-mods.md`、**没有**前置映射表/工程改动/核实纪律等任何重内容（那些在引用文件里）。

- [ ] **Step 4: Commit**

```bash
git add SKILL.md
git commit -m "docs: 第0步加极轻'前置模组'触发指针（指向 references）

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: 新建 `references/prerequisite-mods.md`（承载全部重内容）

**Files:**
- Create: `references/prerequisite-mods.md`

> 这是渐进式披露的重内容载体。只有 Task 1 的触发条命中、agent 主动 Read 时才进上下文，平时不占 token。

- [ ] **Step 1: 新建文件，写入完整内容**

创建 `references/prerequisite-mods.md`，内容：

````markdown
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

> 表为兜底常识，仅覆盖常见信号。表未覆盖的需求（如自定义矿物世界生成），触发后同样联网自查候选前置。表里的前置是否支持 1.20.1 + Forge、最新版本号、maven 坐标，**都必须用 WebSearch 联网核实**再写进 build.gradle——坐标会随版本变，别凭记忆。查不到（离线 / 冷门）则退化用上表坐标并标注"可能过时，构建失败优先怀疑版本号"。

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
````

- [ ] **Step 2: 确认文件四部分齐全**

读 `references/prerequisite-mods.md`，确认含：取舍说明、映射表（5 个前置）、工程三处改动、第三方核实纪律——四部分齐全且无占位符残留（`<modid>`/`前置group:前置artifact:版本号` 是与 SKILL.md 一致的占位风格，非计划占位符）。

- [ ] **Step 3: 确认 SKILL.md 未塞入此重内容**

`grep -n "Cloth Config\|Curios\|Patchouli" SKILL.md` 应**无输出**——重内容只在 references 文件里，SKILL.md 保持轻量。

- [ ] **Step 4: Commit**

```bash
git add references/prerequisite-mods.md
git commit -m "docs: 新建 references/prerequisite-mods.md 承载前置重内容（渐进式披露）

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Common Mistakes 表补一行

**Files:**
- Modify: `SKILL.md`（Common Mistakes 表，约 L268-275）

- [ ] **Step 1: 定位表格末行**

读 SKILL.md 找到 Common Mistakes 表的最后一行（约 L275）：

```markdown
| 贴图加载报错 | 尺寸非 16×16 或非 PNG | PIL 生成合规贴图 |
```

- [ ] **Step 2: 在末行后追加新行**

追加：

```markdown
| 引入前置却没在 mods.toml 声明 mandatory 依赖 | 漏配依赖声明 | 玩家没装前置直接崩，必须加 `[[dependencies.<modid>]]` 且 `mandatory=true` |
```

- [ ] **Step 3: 确认表格语法完整**

读改动后该表，确认新行三列齐全、表格闭合正确（其后接 `## Rationalizations` 段无错位）。

- [ ] **Step 4: Commit**

```bash
git add SKILL.md
git commit -m "docs: Common Mistakes 补'漏配前置 mandatory 依赖'

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Red Flags 列表补一条

**Files:**
- Modify: `SKILL.md`（Red Flags 列表，约 L286-290）

- [ ] **Step 1: 定位列表末项**

读 SKILL.md 找到 Red Flags 列表（约 L286-290）：

```markdown
**Red Flags——看到这些停下：**
- 准备写一个不确定的 Forge 类调用，却没先 javap
- 准备套用 `SimpleTier` / `register(`（1.20.1 没有）
- 用户说的版本不是 1.20.1 + Forge，却想直接套本流程
- 拿 AI 生成的图直接当贴图，没转 16×16 透明 PNG
```

- [ ] **Step 2: 在末项后追加新条**

追加：

```markdown
- 需求明显超出原版（要做配置界面 / 配饰槽 / 游戏内手册），却埋头从零写、没考虑前置 → 停下，看「前置模组（按需）」映射表，把"原生写 vs 引前置"的利弊摆给用户
```

- [ ] **Step 3: 确认列表与结尾段衔接**

读改动后 Red Flags 列表，确认 5 条齐全，其后仍接"这些意味着：停下，回到 javap 核实 / 确认版本 / 用 PIL 生成贴图。"句。

- [ ] **Step 4: Commit**

```bash
git add SKILL.md
git commit -m "docs: Red Flags 补'需求超原版却埋头从零写'

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## 验证（收尾）

- [ ] **grep 确认 SKILL.md 不含前置重内容**：`grep -n "Cloth Config\|Curios\|Patchouli\|fg.deobf" SKILL.md` 应无输出（重内容只在 references）。
- [ ] **通读整份 SKILL.md**，确认 3 处改动落地（第0步指针 + Common Mistakes + Red Flags）、vanilla 主线 0-5 步无破坏。
- [ ] **读 `references/prerequisite-mods.md`** 确认 4 部分齐全。
- [ ] **交叉核对 spec**：spec「具体改动」4 处 ↔ 计划 4 个 Task 一一对应，无遗漏。

## Self-Review 结论

- **Spec 覆盖**：spec 4 处改动 → Task 1-4 一一对应，全覆盖。✓
- **渐进式披露落实**：Task 1 触发条极轻（一句话 + 信号词 + 指向 references）；Task 2 重内容全在 `references/prerequisite-mods.md`；Task 3/4 两条很短留 SKILL.md。验证步骤含 grep 确认 SKILL.md 无重内容。✓
- **占位符**：代码块里的 `<modid>`/`版本号`/`前置group:前置artifact` 是 SKILL.md 现有写法就用的占位风格（参见 L96/L232），非计划占位符。✓
- **一致性**：第 0 步触发条、references 文件、Red Flags 三处对"需求超出原版"的信号列举口径一致（GUI 配置界面 / 配饰槽 / 游戏内手册…）。✓
