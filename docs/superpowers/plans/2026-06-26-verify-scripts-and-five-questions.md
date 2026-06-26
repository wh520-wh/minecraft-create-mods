# 硬规矩可验化 + 动工前五问 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 create-mods skill 里所有"AI 凭记忆必踩"的硬规矩做成可验脚本，让 SKILL.md 正文与脚本对齐（单一信源），并新增"动工前五问"对齐环节。

**Architecture:** 新增一个 `scripts/check-mod-output.sh` 校验产物（贴图规格、pack_format、配方字段、命名链），与现有 `javap-verify.sh` 并列，二者组成"信任底座"。SKILL.md 正文里手写的 javap 命令和散落的硬约束改为指向脚本。在流程开头插入"第 0 步：五问对齐"。

**Tech Stack:** Bash（校验脚本）、Python+PIL（贴图检查，机器已装 PIL 12.1.0）、Markdown（SKILL.md）。

---

## File Structure

- `scripts/check-mod-output.sh` —— **新增**。校验一个已 build 的 mod 产物是否合规：贴图 16×16 透明 PNG、`pack.mcmeta` 的 pack_format=15、配方 JSON 用 `"item"` 不是 `"id"`、注册名↔模型↔layer0↔贴图四环节命名一致。接受 mod 工程根目录或 jar 路径作参数。
- `scripts/javap-verify.sh` —— **小改**。无需改逻辑，仅在末尾提示"配套校验脚本 check-mod-output.sh"。
- `SKILL.md` —— **改**。① 在流程最前插入"第 0 步：动工前五问对齐"；② "Core Discipline" 段的手写 javap 命令块改为指向 `scripts/javap-verify.sh`；③ "贴图"段、"资源文件"段、"构建后必须验证产物"段的手写校验命令改为指向 `scripts/check-mod-output.sh`。
- `examples/verify-report.md` —— **小改**。补一句指向 check-mod-output 的说明（两个脚本分工）。
- `README.md` —— **小改**。"文件结构"和"验证与测试"两节补 check-mod-output.sh 一行。
- `examples/emerald_sword_mod/` —— 用作 check-mod-output 的真实测试夹具（贴图已有，Task 里补一个配方 JSON + model JSON + pack.mcmeta 让命名链可验）。

---

### Task 1: 设计并验证 check-mod-output 的贴图检查逻辑（先做最小可用的一段）

**Files:**
- Create: `scripts/check-mod-output.sh`
- Test 夹具: `examples/emerald_sword_mod/src/main/resources/assets/moresword/models/item/emerald_sword.json`
- Test 夹具: `examples/emerald_sword_mod/src/main/resources/assets/moresword/lang/en_us.json`
- Test 夹具: `examples/emerald_sword_mod/src/main/resources/assets/moresword/lang/zh_cn.json`
- Test 夹具: `examples/emerald_sword_mod/src/main/resources/data/moresword/recipes/emerald_sword.json`
- Test 夹具: `examples/emerald_sword_mod/src/main/resources/pack.mcmeta`

- [ ] **Step 1: 先建好测试夹具（命名链 + 配方 + pack.mcmeta）**

贴图已存在（`textures/item/emerald_sword.png`）。补齐命名链其余环节，让四环节齐全可验。

`models/item/emerald_sword.json`:
```json
{
  "parent": "minecraft:item/handheld",
  "textures": { "layer0": "moresword:item/emerald_sword" }
}
```

`lang/en_us.json`:
```json
{ "item.moresword.emerald_sword": "Emerald Sword" }
```

`lang/zh_cn.json`:
```json
{ "item.moresword.emerald_sword": "绿宝石剑" }
```

`data/moresword/recipes/emerald_sword.json`（1.20.1 用 "item" 不是 "id"）:
```json
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["E", "E", "S"],
  "key": {
    "E": { "item": "minecraft:emerald" },
    "S": { "item": "minecraft:stick" }
  },
  "result": { "item": "moresword:emerald_sword", "count": 1 }
}
```

`pack.mcmeta`（1.20.1 必须 pack_format=15）:
```json
{ "pack": { "pack_format": 15, "description": "create-mods example mod" } }
```

- [ ] **Step 2: 写 check-mod-output.sh 的骨架 + 贴图检查**

骨架负责：定位 mod 资源根目录、循环跑各项检查、汇总 PASS/FAIL。先只实现贴图检查（调用 Python PIL）。

`scripts/check-mod-output.sh`:
```bash
#!/usr/bin/env bash
# check-mod-output.sh — 校验一个 Forge 1.20.1 mod 产物是否合规
#
# 用法：bash scripts/check-mod-output.sh <mod工程根目录或jar>
#       工程根目录应含 src/main/resources/...
# 检查项：贴图规格、pack_format=15、配方字段用"item"、命名四环节一致。
# 退出码：0=全 PASS；1=有 FAIL 或参数错。

set -uo pipefail
ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  echo "用法: bash scripts/check-mod-output.sh <mod工程根目录或jar>" >&2
  exit 1
fi

# 若传 jar，解压到临时目录
if [ -f "$ROOT" ] && [[ "$ROOT" == *.jar ]]; then
  TMP="$(mktemp -d)"
  unzip -q "$ROOT" -d "$TMP"
  ROOT="$TMP"
  RES="$ROOT"
else
  RES="$ROOT/src/main/resources"
fi

PASS=0; FAIL=0
ok(){ printf "  PASS  %s\n" "$1"; PASS=$((PASS+1)); }
no(){ printf "  FAIL  %s\n     %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

echo "校验目标: $RES"
echo "──────────────────────────────────────────────────────────────"

# ── 检查 1：所有 item 贴图必须 16x16 透明 PNG ──
echo "[1] 贴图规格（16x16 透明 PNG）"
TEX_DIR="$RES/assets"
if [ -d "$TEX_DIR" ]; then
  found=0
  while IFS= read -r -d '' png; do
    found=1
    # 用 PIL 检查尺寸和透明度
    info=$(python - "$png" <<'PY'
import sys
from PIL import Image
try:
    im = Image.open(sys.argv[1])
    w,h = im.size
    mode = im.mode
    # 判透明：至少有一个 alpha=0 的像素
    transparent = False
    if mode in ("RGBA","LA") or (mode=="P" and "transparency" in im.info):
        rgba = im.convert("RGBA")
        transparent = any(rgba.getpixel((x,y))[3]==0 for x in range(w) for y in range(h))
    print(f"{w}x{h} mode={mode} transparent={'yes' if transparent else 'no'}")
except Exception as e:
    print(f"ERR {e}")
PY
)
    name=$(basename "$png")
    if printf '%s' "$info" | grep -q '^16x16 mode=RGBA transparent=yes'; then
      ok "  $name 16x16 透明"
    else
      no "  $name 规格不符" "$info（期望 16x16 RGBA 透明）"
    fi
  done < <(find "$TEX_DIR" -path '*/textures/item/*.png' -print0)
  [ "$found" -eq 0 ] && echo "  （无 item 贴图，跳过）"
else
  no "assets 目录不存在" "$TEX_DIR"
fi
echo ""

echo "──────────────────────────────────────────────────────────────"
echo "结果：PASS $PASS / FAIL $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ 全部通过"; exit 0; } || { echo "✗ 有 $FAIL 项未通过" >&2; exit 1; }
```

- [ ] **Step 3: 跑贴图检查，确认 PASS**

Run:
```bash
cd D:/github/skill/create-mods
bash scripts/check-mod-output.sh examples/emerald_sword_mod
```
Expected: `[1] 贴图规格` 下 `PASS emerald_sword.png 16x16 透明`，结果 PASS≥1 / FAIL 0。

- [ ] **Step 4: Commit**

```bash
git add scripts/check-mod-output.sh examples/emerald_sword_mod/
git commit -m "feat: 新增 check-mod-output 贴图检查 + 示例工程命名链夹具"
```

---

### Task 2: 给 check-mod-output 加 pack_format 检查

**Files:**
- Modify: `scripts/check-mod-output.sh`

- [ ] **Step 1: 在汇总输出前、贴图检查块之后，插入 pack_format 检查**

在 `Task 1` 的脚本里，贴图检查块（`[1]`）之后、汇总之前，插入：

```bash
# ── 检查 2：pack.mcmeta 的 pack_format 对 1.20.1 必须 = 15 ──
echo "[2] pack.mcmeta pack_format=15"
PMC="$RES/pack.mcmeta"
if [ -f "$PMC" ]; then
  pf=$(python - "$PMC" <<'PY'
import sys,json
try:
    print(json.load(open(sys.argv[1,encoding='utf-8']))["pack"]["pack_format"])
except Exception as e:
    print("ERR")
PY
)
  if [ "$pf" = "15" ]; then ok "pack_format=15"; else no "pack_format 错" "实际=$pf（期望 15）"; fi
else
  no "pack.mcmeta 缺失" "$PMC"
fi
echo ""
```

- [ ] **Step 2: 跑检查确认 PASS**

Run:
```bash
bash scripts/check-mod-output.sh examples/emerald_sword_mod
```
Expected: `[2] pack.mcmeta pack_format=15` → `PASS pack_format=15`。

- [ ] **Step 3: 临时改坏 pack_format 验证 FAIL 能被抓到**

Run:
```bash
cp examples/emerald_sword_mod/src/main/resources/pack.mcmeta /tmp/pack.bak
sed -i 's/15/18/' examples/emerald_sword_mod/src/main/resources/pack.mcmeta
bash scripts/check-mod-output.sh examples/emerald_sword_mod 2>&1 | grep -E 'pack_format|FAIL|结果'
cp /tmp/pack.bak examples/emerald_sword_mod/src/main/resources/pack.mcmeta
```
Expected: 看到 `FAIL pack_format 错 实际=18（期望 15）`。还原后重跑应恢复 PASS。

- [ ] **Step 4: Commit**

```bash
git add scripts/check-mod-output.sh
git commit -m "feat: check-mod-output 增加 pack_format=15 检查"
```

---

### Task 3: 给 check-mod-output 加配方字段检查（"item" 不是 "id"）

**Files:**
- Modify: `scripts/check-mod-output.sh`

- [ ] **Step 1: 在 pack_format 检查块后插入配方检查**

```bash
# ── 检查 3：配方 JSON 用 "item" 不用 "id"（1.20.1 事实）──
echo "[3] 配方字段用 item 不用 id"
REC="$RES/data"
if [ -d "$REC" ]; then
  while IFS= read -r -d '' rj; do
    name=$(basename "$rj")
    # 含 "id" 作为键（1.21 风格）= 警告；含 "item" = ok
    if grep -q '"id"[[:space:]]*:' "$rj"; then
      no "  $name 用了 id" "1.20.1 配方用 \"item\"，\"id\" 是 1.21+ 写法"
    else
      ok "  $name 字段合规"
    fi
  done < <(find "$REC" -path '*/recipes/*.json' -print0)
else
  echo "  （无 recipes 目录，跳过）"
fi
echo ""
```

- [ ] **Step 2: 跑检查确认 PASS**

Run:
```bash
bash scripts/check-mod-output.sh examples/emerald_sword_mod
```
Expected: `[3]` 下 `PASS emerald_sword.json 字段合规`。

- [ ] **Step 3: 临时改坏（item→id）验 FAIL**

Run:
```bash
cp examples/emerald_sword_mod/src/main/resources/data/moresword/recipes/emerald_sword.json /tmp/rec.bak
sed -i 's/"item"/"id"/g' examples/emerald_sword_mod/src/main/resources/data/moresword/recipes/emerald_sword.json
bash scripts/check-mod-output.sh examples/emerald_sword_mod 2>&1 | grep -E 'id|FAIL|结果'
cp /tmp/rec.bak examples/emerald_sword_mod/src/main/resources/data/moresword/recipes/emerald_sword.json
```
Expected: 看到 `FAIL emerald_sword.json 用了 id`。还原后重跑恢复 PASS。

- [ ] **Step 4: Commit**

```bash
git add scripts/check-mod-output.sh
git commit -m "feat: check-mod-output 增加配方字段 item/id 检查"
```

---

### Task 4: 给 check-mod-output 加命名链四环节一致性检查

**Files:**
- Modify: `scripts/check-mod-output.sh`

- [ ] **Step 1: 在配方检查块后插入命名链检查**

逻辑：对每个 `models/item/<name>.json`，读其 `layer0` 值 `<modid>:item/<name>`，核对贴图 `assets/<modid>/textures/item/<name>.png` 存在；模型文件名、layer0 名、贴图名三处 `<name>` 一致。lang 键 `item.<modid>.<name>` 存在。

```bash
# ── 检查 4：命名四环节一致（注册名↔模型↔layer0↔贴图↔lang）──
echo "[4] 命名链一致"
MOD_DIR=$(find "$RES/assets" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
if [ -n "$MOD_DIR" ]; then
  modid=$(basename "$MOD_DIR")
  while IFS= read -r -d '' mj; do
    name=$(basename "$mj" .json)
    # layer0 期望 "modid:item/name"
    layer0=$(python - "$mj" <<'PY'
import sys,json
try:
    print(json.load(open(sys.argv[1,encoding='utf-8'))["textures"]["layer0"])
except Exception:
    print("ERR")
PY
)
    want_layer0="${modid}:item/${name}"
    want_tex="$MOD_DIR/textures/item/${name}.png"
    want_lang_en="$MOD_DIR/lang/en_us.json"
    if [ "$layer0" != "$want_layer0" ]; then
      no "  $name layer0 不符" "实际=$layer0 期望=$want_layer0"
    elif [ ! -f "$want_tex" ]; then
      no "  $name 贴图缺失" "$want_tex"
    else
      # 查 lang 键
      key="item.${modid}.${name}"
      if [ -f "$want_lang_en" ] && grep -q "\"$key\"" "$want_lang_en"; then
        ok "  $name 命名链完整（模型↔layer0↔贴图↔lang）"
      else
        no "  $name lang 键缺失" "期望键 $key"
      fi
    fi
  done < <(find "$MOD_DIR/models/item" -name '*.json' -print0 2>/dev/null)
else
  no "assets 下无 modid 目录" "$RES/assets"
fi
echo ""
```

- [ ] **Step 2: 跑检查确认 PASS**

Run:
```bash
bash scripts/check-mod-output.sh examples/emerald_sword_mod
```
Expected: `[4]` 下 `PASS emerald_sword 命名链完整（模型↔layer0↔贴图↔lang）`，最终 PASS / FAIL 0。

- [ ] **Step 3: 临时改坏 layer0 验 FAIL**

Run:
```bash
cp examples/emerald_sword_mod/src/main/resources/assets/moresword/models/item/emerald_sword.json /tmp/mod.bak
sed -i 's|emerald_sword|wrong_name|' examples/emerald_sword_mod/src/main/resources/assets/moresword/models/item/emerald_sword.json
bash scripts/check-mod-output.sh examples/emerald_sword_mod 2>&1 | grep -E 'layer0|FAIL|结果'
cp /tmp/mod.bak examples/emerald_sword_mod/src/main/resources/assets/moresword/models/item/emerald_sword.json
```
Expected: 看到 `FAIL emerald_sword layer0 不符`。还原后重跑恢复 PASS。

- [ ] **Step 4: 跑完整脚本，确认全部 PASS 退出码 0**

Run:
```bash
bash scripts/check-mod-output.sh examples/emerald_sword_mod; echo "退出码: $?"
```
Expected: 四项全 PASS，`结果：PASS N / FAIL 0`，`退出码: 0`。

- [ ] **Step 5: Commit**

```bash
git add scripts/check-mod-output.sh
git commit -m "feat: check-mod-output 增加命名链四环节一致性检查"
```

---

### Task 5: SKILL.md 新增"第 0 步：动工前五问对齐"

**Files:**
- Modify: `D:/github/skill/create-mods/SKILL.md`（在 `## 流程` 的 `### 1. 搭骨架` 之前插入）

- [ ] **Step 1: 读 SKILL.md 定位插入点**

Run:
```bash
grep -n "## 流程\|### 1. 搭骨架" D:/github/skill/create-mods/SKILL.md
```
Expected: 看到 `## 流程` 和 `### 1. 搭骨架：` 两行行号，五问插在这两行之间。

- [ ] **Step 2: 插入"第 0 步：五问对齐"小节**

用 Edit 在 `## 流程` 之后、`### 1. 搭骨架` 之前插入：

```markdown
### 0. 动工前五问：先对齐再动手

接到需求后**不要立刻敲代码**。先在脑里过一遍这五个问题，然后用大白话向用户复述确认，用户点头了再进第 1 步。这一步是为了避免"做出来不是你想要的"。

| 拷问 | 要想清楚什么 | 复述时怎么说 |
|------|-------------|-------------|
| ① 你到底要什么 | 把"加把绿宝石剑"翻译成清晰目标：什么物品、什么 Tier、几个、放哪个创造标签页 | "你要的是一把绿宝石剑，攻击力显示 30、耐久 2000，放在战斗标签页" |
| ② 大概分几步 | 搭骨架→改配置→写源码→资源→构建验证，五步 | "我大概分五步：搭工程、填信息、写代码、配资源、编译验证" |
| ③ 做出来啥效果 | 一个能 build 出 jar、塞进 mods 文件夹就能在游戏里用/合成的剑 | "做完你能拿到一个 jar，放 mods 文件夹，进游戏能合成、能挥" |
| ④ 用到什么工具 | Forge MDK、Gradle、javap、PIL（贴图） | "用到官方 MDK 起步、Gradle 编译、PIL 画贴图" |
| ⑤ 要不要生成贴图 | 大部分自定义物品都要贴图（16×16 透明 PNG）；没图会显示紫黑方块 | "要给这把剑画贴图吗？要的话我用程序画一个 16×16 透明图" |

**第六问——最该提醒的注意事项**（复述时主动说，别等用户问）：

- 版本锁死：本 skill 只做 1.20.1 + Forge。你要是 1.21 或别的加载器，我得先停下确认。
- 首次编译慢：第一次 build 要下反编译产物，约 7 分钟，后面就快了。
- API 我不靠记忆：涉及 Forge 类我会先 javap 核实真实 jar，不猜。
- 攻击力换算：你要的"攻击力 30"是游戏 UI 显示值，我会反推成代码里的 modifier，公式 `modifier = 30 − 1 − Tier加成`。

复述完等用户确认"对，就这样"。需求不清或有多种解读时，**宁可多问一轮也别返工**。

---
```

- [ ] **Step 3: 确认插入位置正确（五问在流程标题后、第1步前）**

Run:
```bash
grep -n "动工前五问\|### 0\|### 1. 搭骨架" D:/github/skill/create-mods/SKILL.md
```
Expected: `### 0. 动工前五问` 出现在 `### 1. 搭骨架` 之前。

- [ ] **Step 4: Commit**

```bash
git add SKILL.md
git commit -m "feat: SKILL.md 新增第0步『动工前五问对齐』"
```

---

### Task 6: SKILL.md 正文与脚本对齐（手写 javap 命令改为指向脚本）

**Files:**
- Modify: `D:/github/skill/create-mods/SKILL.md`

- [ ] **Step 1: 读 Core Discipline 段当前内容**

Run:
```bash
grep -n "## Core Discipline\|javap 核实 API\|JAVAP=" D:/github/skill/create-mods/SKILL.md
```
Expected: 看到 `## Core Discipline: javap 核实 API` 标题和 `JAVAP=` 那段 bash 代码块行号。

- [ ] **Step 2: 在 javap 命令代码块前补一句"固化脚本"，但保留原命令作教学说明**

用 Edit 把现有这段：

```bash
JAVAP="/c/Program Files/Java/jdk-21/bin/javap.exe"   # 按实际 JDK 路径
JAR=~/.gradle/caches/forge_gradle/minecraft_user_repo/net/minecraftforge/forge/1.20.1-47.3.0_mapped_official_1.20.1/forge-1.20.1-47.3.0_mapped_official_1.20.1.jar
"$JAVAP" -cp "$JAR" -p net.minecraftforge.common.TierSortingRegistry
"$JAVAP" -cp "$JAR" -p net.minecraft.world.item.Tier
```

替换为（在前面加一行指向脚本的说明）：

```bash
# 一键对账 6 条 API 事实（首选，仓库已固化）：
bash scripts/javap-verify.sh

# 手动 javap 看任意类（教学/排查用，按实际 JDK 路径）：
JAVAP="/c/Program Files/Java/jdk-21/bin/javap.exe"
JAR=~/.gradle/caches/forge_gradle/minecraft_user_repo/net/minecraftforge/forge/1.20.1-47.3.0_mapped_official_1.20.1/forge-1.20.1-47.3.0_mapped_official_1.20.1.jar
"$JAVAP" -cp "$JAR" -p net.minecraftforge.common.TierSortingRegistry
"$JAVAP" -cp "$JAR" -p net.minecraft.world.item.Tier
```

- [ ] **Step 3: 在"构建后必须验证产物"段补指向 check-mod-output**

Run:
```bash
grep -n "构建后必须验证产物" D:/github/skill/create-mods/SKILL.md
```
在该段开头那行 `**构建后必须验证产物**` 之后，用 Edit 插入一句：

```markdown
> 一键校验产物合规（贴图/pack_format/配方/命名链）：`bash scripts/check-mod-output.sh <mod工程根目录>`
```

（保留下方原有的 jar 内容、占位符、pack_format 三步手动命令作教学说明。）

- [ ] **Step 4: 在"贴图：必须 16×16 透明 PNG"段补指向 check-mod-output**

Run:
```bash
grep -n "贴图：必须 16" D:/github/skill/create-mods/SKILL.md
```
在该段开头用 Edit 补一句：

```markdown
> 贴图规格可一键校验：`bash scripts/check-mod-output.sh <工程>` 会查所有 item 贴图是否 16×16 透明 PNG。
```

- [ ] **Step 5: Commit**

```bash
git add SKILL.md
git commit -m "docs: SKILL.md 正文与 javap-verify/check-mod-output 脚本对齐"
```

---

### Task 7: 更新 README、verify-report，跑全量验证收尾

**Files:**
- Modify: `D:/github/skill/create-mods/README.md`
- Modify: `D:/github/skill/create-mods/examples/verify-report.md`

- [ ] **Step 1: README 文件结构补 check-mod-output.sh**

Run:
```bash
grep -n "javap-verify.sh" D:/github/skill/create-mods/README.md
```
用 Edit 在 `javap-verify.sh` 那行下方加一行：

```markdown
│   └── check-mod-output.sh   # 校验 mod 产物合规：贴图规格/pack_format=15/配方字段/命名链
```

- [ ] **Step 2: README 验证与测试节补 check-mod-output 命令**

用 Edit 在 `bash scripts/javap-verify.sh` 命令行后追加：

```bash
bash scripts/check-mod-output.sh examples/emerald_sword_mod   # 期望：四项全 PASS，退出码 0
```

- [ ] **Step 3: verify-report.md 补两个脚本分工说明**

Run:
```bash
grep -n "怎么复现\|信任底座" D:/github/skill/create-mods/examples/verify-report.md
```
在文件末尾用 Edit 追加：

```markdown
## 两个脚本分工

- `scripts/javap-verify.sh` —— 核实 **API 事实**（Tier/TierSortingRegistry/SwordItem 等签名），针对真实 Forge jar。
- `scripts/check-mod-output.sh` —— 核实 **mod 产物合规**（贴图/pack_format/配方/命名链），针对 build 出来的工程或 jar。

一个查"API 对不对"，一个查"做出来的东西合不合规"，合起来是 create-mods 的完整信任底座。
```

- [ ] **Step 4: 跑两个脚本全量验证**

Run:
```bash
cd D:/github/skill/create-mods
bash scripts/javap-verify.sh; echo "javap退出码:$?"
bash scripts/check-mod-output.sh examples/emerald_sword_mod; echo "check退出码:$?"
```
Expected: javap `PASS 15 / FAIL 0` 退出码 0；check 四项 `FAIL 0` 退出码 0。

- [ ] **Step 5: 重跑结构尺体检**

Run:
```bash
cd C:/Users/32694/.claude/skills/luban
bash tools/check-skill-repo.sh D:/github/skill/create-mods
```
Expected: `FAIL: 0`，scripts/examples 项仍 PASS。

- [ ] **Step 6: Commit 并推送**

```bash
cd D:/github/skill/create-mods
git add README.md examples/verify-report.md
git commit -m "docs: README/verify-report 补 check-mod-output 说明"
git push origin main
```

---

## Self-Review

**1. Spec 覆盖：**
- 思路一（硬规矩可验）：贴图(Task1)、pack_format(Task2)、配方字段(Task3)、命名链(Task4) → ✅ 四类硬规矩全覆盖。
- 思路二（正文与脚本对齐）：javap 命令(Task6 Step2)、构建验证段(Task6 Step3)、贴图段(Task6 Step4) → ✅ 三处手写命令对齐脚本。
- 五问：Task5 → ✅ 作为第 0 步。
- README/verify-report 同步：Task7 → ✅。

**2. 占位符扫描：** 无 TBD/TODO；每个代码步骤都给了完整代码和完整命令。Task2/3/4 的"改坏验 FAIL"步骤有具体 sed 命令和还原步骤。

**3. 类型/名称一致：** 脚本名 `check-mod-output.sh`、参数 `<mod工程根目录或jar>`、四项检查编号 [1]-[4] 在各 Task 间一致；示例夹具 modid `moresword`、name `emerald_sword` 全程一致。

**4. 风险点：** Python heredoc 里 `sys.argv[1]` 传文件路径正常；Windows bash 下 PIL 已确认可用；sed 改坏夹具后均还原。无阻塞。
