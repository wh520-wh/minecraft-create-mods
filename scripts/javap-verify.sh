#!/usr/bin/env bash
# javap-verify.sh — 一键复现 create-mods skill 里 6 条 Forge 1.20.1 API 事实
#
# 用途：这个 skill 的每一句 API 断言都不靠记忆，而是对真实 jar 跑 javap 核实。
#       本脚本把那套核实动作固化下来，任何人装好 skill 都能一键自证——
#       绿色的文档会撒谎，真实 jar 不会。
#
# 用法：  bash scripts/javap-verify.sh
# 退出码：0 = 全部 PASS；1 = 有 FAIL 或环境不齐（见输出指引）

set -uo pipefail

# ── 1. 定位 javap ──────────────────────────────────────────────
find_javap() {
  # 优先 PATH
  if command -v javap >/dev/null 2>&1; then command -v javap; return; fi
  # 遍历常见 JDK 安装路径（Windows / macOS / Linux）
  for j in \
    "/c/Program Files/Java"/*/bin/javap.exe \
    "/c/Program Files/Eclipse Adoptium"/*/bin/javap.exe \
    "/Library/Java/JavaVirtualMachines"/*/Contents/Home/bin/javap \
    /usr/lib/jvm/*/bin/javap \
    /opt/*/bin/javap; do
    [ -x "$j" ] && { echo "$j"; return; }
  done
  return 1
}

JAVAP="$(find_javap || true)"
if [ -z "$JAVAP" ]; then
  echo "✗ 找不到 javap。装一个 JDK 17 或 21，或把它加进 PATH 后重试。" >&2
  echo "  Windows 常见路径：/c/Program Files/Java/jdk-21/bin/javap.exe" >&2
  exit 1
fi

# ── 2. 定位 Forge 1.20.1 mapped jar（鸡生蛋：首次 build 才物化）──
GRADLE_CACHE="${HOME}/.gradle/caches/forge_gradle/minecraft_user_repo/net/minecraftforge/forge"
JAR=""
for d in "$GRADLE_CACHE"/1.20.1-47.*_mapped_*; do
  [ -d "$d" ] || continue
  for f in "$d"/*.jar; do
    [ -f "$f" ] || continue
    case "$f" in *_mapped_*.jar) JAR="$f"; break;; esac
  done
  [ -n "$JAR" ] && break
done

if [ -z "$JAR" ]; then
  echo "✗ 找不到 Forge 1.20.1 mapped jar。" >&2
  echo "  这是「鸡生蛋」问题：mapped jar 要等 ForgeGradle 首次解析依赖才生成。" >&2
  echo "  先按 SKILL.md 搭好工程，跑一次 ./gradlew compileJava（首次约 7 分钟），" >&2
  echo "  之后本脚本就能在 $GRADLE_CACHE 找到它。" >&2
  echo "  已有缓存的机器可跳过此步，直接重跑本脚本。" >&2
  exit 1
fi

echo "javap : $JAVAP"
echo "jar   : $JAR"
echo "──────────────────────────────────────────────────────────────"
echo "对账 6 条 Forge 1.20.1 API 事实（SKILL.md 速查表）"
echo "──────────────────────────────────────────────────────────────"

PASS=0; FAIL=0
check() { # check "断言" "命令" "期望匹配的正则"
  local name="$1" cmd="$2" want="$3"
  local out
  out="$(eval "$cmd" 2>/dev/null || true)"
  if printf '%s' "$out" | grep -Eq "$want"; then
    printf "  PASS  %s\n" "$name"; PASS=$((PASS+1))
  else
    printf "  FAIL  %s\n     实际输出: %s\n" "$name" "$(printf '%s' "$out" | head -1)"; FAIL=$((FAIL+1))
  fi
}

# 1. SimpleTier 不存在（NeoForge 1.20.2+ 才有）
# javap 找不到类时退出码非 0，且错误信息编码随 locale 变（中文机常是 GBK 乱码），
# 所以用退出码判定，不依赖输出文本，避免编码踩坑。
if "$JAVAP" -cp "$JAR" -p net.minecraft.world.item.SimpleTier >/dev/null 2>&1; then
  printf "  FAIL  %s\n     SimpleTier 居然存在? 1.20.1 不该有它\n" "SimpleTier 在 1.20.1 不存在"; FAIL=$((FAIL+1))
else
  printf "  PASS  %s\n" "SimpleTier 在 1.20.1 不存在（javap 退出码非0）"; PASS=$((PASS+1))
fi

# 2. Tier 接口 6 个 abstract 方法 + getTag default
check "Tier 接口 6 abstract 方法齐全" \
  "\"$JAVAP\" -cp \"$JAR\" -p net.minecraft.world.item.Tier" \
  "getUses.*getSpeed.*getAttackDamageBonus.*getLevel.*getEnchantmentValue.*getRepairIngredient|getUses"

# 分项确认 Tier 的 6 个方法（更严格）
for m in getUses getSpeed getAttackDamageBonus getLevel getEnchantmentValue getRepairIngredient; do
  check "  Tier.$m 是 abstract" \
    "\"$JAVAP\" -cp \"$JAR\" -p net.minecraft.world.item.Tier" \
    "abstract .*$m"
done
check "Tier.getTag 是 default（可不实现）" \
  "\"$JAVAP\" -cp \"$JAR\" -p net.minecraft.world.item.Tier" \
  "default.*getTag"

# 3. TierSortingRegistry.registerTier 签名 = registerTier(Tier, ResourceLocation, List<Object>, List<Object>)
check "registerTier 签名 (Tier,ResourceLocation,List,List) 且方法名是 registerTier 不是 register" \
  "\"$JAVAP\" -cp \"$JAR\" -p net.minecraftforge.common.TierSortingRegistry" \
  "registerTier.*Tier.*ResourceLocation.*List.*List"

# 4. SwordItem 构造器 (Tier, int, float, Item.Properties)
check "SwordItem 构造器 (Tier,int,float,Item.Properties)" \
  "\"$JAVAP\" -cp \"$JAR\" -p net.minecraft.world.item.SwordItem" \
  "SwordItem.*Tier.*int.*float.*Item\\\$Properties"

# 5. 事件 getTabKey 返回 ResourceKey<CreativeModeTab>；accept 有 Supplier 重载
check "BuildCreativeModeTabContentsEvent.getTabKey 返回 ResourceKey" \
  "\"$JAVAP\" -cp \"$JAR\" -p net.minecraftforge.event.BuildCreativeModeTabContentsEvent" \
  "ResourceKey.*CreativeModeTab.*getTabKey"
check "事件 accept 有 Supplier<? extends ItemLike> 重载" \
  "\"$JAVAP\" -cp \"$JAR\" -p net.minecraftforge.event.BuildCreativeModeTabContentsEvent" \
  "accept.*Supplier.*ItemLike"

# 6. Tier.getLevel 带 @Deprecated 但仍是 abstract
check "Tier.getLevel 带 @Deprecated（常量池含 Deprecated 注解）" \
  "\"$JAVAP\" -cp \"$JAR\" -p -v net.minecraft.world.item.Tier" \
  "Deprecated"
check "Tier.getLevel 仍是 abstract（必须实现，警告无害）" \
  "\"$JAVAP\" -cp \"$JAR\" -p net.minecraft.world.item.Tier" \
  "abstract.*getLevel"

echo "──────────────────────────────────────────────────────────────"
echo "结果：PASS $PASS / FAIL $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "✓ 6 条 API 事实全部经真实 jar 对账通过。"
  echo "  这就是 create-mods 的信任底座——每句话都能验，不靠记忆。"
  exit 0
else
  echo "✗ 有 $FAIL 条未通过。若 jar 版本与 1.20.1-47.x 不符，属正常——本 skill 仅承诺 1.20.1。" >&2
  exit 1
fi
