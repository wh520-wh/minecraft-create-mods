#!/usr/bin/env bash
# check-mod-output.sh — 校验一个 Forge 1.20.1 mod 产物是否合规
#
# 用法：bash scripts/check-mod-output.sh <mod工程根目录或jar>
#       工程根目录应含 src/main/resources/...
# 检查项：贴图规格、pack_format=15、配方字段用"item"、命名四环节一致。
# 退出码：0=全 PASS；1=有 FAIL 或参数错。

set -uo pipefail

# 探测 python：优先 python3，回退 python（本机 python3 可能是 Store 桩，exit 非0会自动回退）
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys; sys.exit(0 if sys.version_info>=(3,8) else 1)' 2>/dev/null; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "✗ 找不到 python（需要 PIL）。装 Python 3.8+ 后重试。" >&2
  exit 1
fi

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  echo "用法: bash scripts/check-mod-output.sh <mod工程根目录或jar>" >&2
  exit 1
fi

# 若传 jar，解压到临时目录
if [ -f "$ROOT" ] && [[ "$ROOT" == *.jar ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "${TMP:-}"' EXIT   # 退出时清理解压临时目录
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
    info=$("$PY" - "$png" <<'PY'
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

# ── 检查 2：pack.mcmeta 的 pack_format 对 1.20.1 必须 = 15 ──
echo "[2] pack.mcmeta pack_format=15"
PMC="$RES/pack.mcmeta"
if [ -f "$PMC" ]; then
  pf=$("$PY" - "$PMC" <<'PY'
import sys,json
try:
    print(json.load(open(sys.argv[1],encoding='utf-8'))["pack"]["pack_format"])
except Exception as e:
    print("ERR")
PY
)
  if [ "$pf" = "15" ]; then ok "pack_format=15"; else no "pack_format 错" "实际=$pf（期望 15）"; fi
else
  no "pack.mcmeta 缺失" "$PMC"
fi
echo ""

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

# ── 检查 4：命名四环节一致（注册名↔模型↔layer0↔贴图↔lang）──
echo "[4] 命名链一致"
MOD_DIR=$(find "$RES/assets" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
if [ -n "$MOD_DIR" ]; then
  modid=$(basename "$MOD_DIR")
  while IFS= read -r -d '' mj; do
    name=$(basename "$mj" .json)
    # layer0 期望 "modid:item/name"
    layer0=$("$PY" - "$mj" <<'PY'
import sys,json
try:
    print(json.load(open(sys.argv[1],encoding='utf-8'))["textures"]["layer0"])
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

echo "──────────────────────────────────────────────────────────────"
echo "结果：PASS $PASS / FAIL $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ 全部通过"; exit 0; } || { echo "✗ 有 $FAIL 项未通过" >&2; exit 1; }
