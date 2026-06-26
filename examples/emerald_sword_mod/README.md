# 示例：emerald_sword_mod

> 这是 create-mods skill 跑出来的一个**最小可验证产物**——一把绿宝石剑的贴图，
> 用来证明 skill 真能产出看得见、合规格的东西。

## 里面有什么

- `src/main/resources/assets/moresword/textures/item/emerald_sword.png`
  - **16×16、RGBA、透明背景**的剑贴图，由 PIL 程序化生成（不是 AI 文生图）
  - 对应 skill 流程第 4 步「资源文件」的贴图环节
  - 规格自检：`左上角 alpha=0（透明）、剑身像素 (8,5)=(40,190,90,255)`

## 为什么只放贴图，不放完整工程

完整 Java 工程（主类、Tier、Item 注册、lang/model/recipe）是**你触发 skill 时按你的需求现场生成的**——
版本、mod_id、攻击力都因人而异，没有一份"标准答案"值得固化。

但贴图规格是**硬约束**（必须 16×16 透明 PNG，AI 图几乎都不满足），所以把它作为
「skill 产出的东西长这样、且合规」的可验证样本留下来。

## 想要完整工程？

对装好 skill 的 Agent 说：

```text
帮我做一个 Minecraft 1.20.1 Forge 的 mod，加一把绿宝石剑，攻击力显示 30，耐久 2000。
```

skill 会从 MDK 起步，一路生成主类 / 自定义 Tier / 物品注册 / lang / model / recipe / 贴图，
并跑 `scripts/javap-verify.sh` 自证 API 事实。

## 对账报告

这个示例对应的 API 事实对账，见同目录 `../verify-report.md`——
那是 `scripts/javap-verify.sh` 在真实 1.20.1-47.3.0 jar 上跑出的原始输出，
15 条全 PASS，证明 skill 速查表里每一句都不靠记忆。
