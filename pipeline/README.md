# 每日岗位 → 概念卡片 流水线

把「BOSS 上今天新出的岗位要求」变成「明天要背的卡片」。抓取在本机跑，云端只存和发。

---

## 现在的架构

```
        ┌───────────────── 本机（每天 08:40 定时）─────────────────┐
        │                                                          │
        │  1. boss-scrape  →  pipeline/raw/2026-10-27/*.json       │
        │     （CloakBrowser 驱动，复用登录态、住宅 IP）            │
        │  2. 抽词 + 频次统计  → 找出「高频且题库里没有」的概念      │
        │  3. 按 jd_to_cards.md 写卡  →  candidates/2026-10-27.json │
        │  4. merge_cards.py  →  写入 drill/cards.json（去重校验）   │
        │  5. git commit + push                                    │
        └──────────────────────────┬───────────────────────────────┘
                                   │
                     GitHub（唯一数据源）
                                   │
                         GitHub Pages 自动构建
                                   │
        ┌──────────────────────────┴───────────────────────────────┐
        │  手机 / 平板 / 公司电脑：打开 /drill/ 就是最新题库        │
        │  进度存在各自浏览器的 localStorage，可导出导入            │
        └──────────────────────────────────────────────────────────┘
```

关键设计：**内置 129 张卡写在 `index.html` 里，JD 新增的写在 `cards.json` 里**。页面启动时先渲染内置卡，再 fetch `cards.json` 合并。所以：

- 断网、离线、甚至 `file://` 双击打开 —— 内置卡照常能用
- 云端新增的卡自动叠加上来，带「JD 新增」标记

### 卡片是「岗位场景驱动」的

每张卡八个字段，正面是术语，翻面第一屏是 **岗位场景 · 为什么考它**，然后是定义、原理、用法、坑：

```
┌ TF2 坐标变换树 ────────────────────┐
│ ① 一句话定义                        │
│ ② 岗位场景  ← 岗位高频表述 + 面试追到哪一层
│ ③ 原理与要点（3–4 条，含数值/公式）   │
│ ④ 工程上怎么用                       │
│ ⑤ 容易踩的坑                        │
└────────────────────────────────────┘
```

- 新卡（流水线产出）必须自带 `jd` 字段，`merge_cards.py` 会拒绝没有岗位场景的卡片
- 老的 119 张内置卡没有逐条 `jd`，会退化成**分类级岗位场景**（如「雷达·信号」→ 车载雷达算法与自动驾驶感知岗的核心考点），不至于空着

---

## 三种上云路线，怎么选

| | 抓取位置 | 全自动 | 成本 | 风险 | 适合 |
|---|---|---|---|---|---|
| **A. 本机定时 + Pages 分发**（已配好） | 家里电脑 | ✅ | 0 元 | 低 | **默认选这个** |
| B. GitHub Actions 跑抓取 | 机房 IP | ✅ | 0 元 | 高：验证码、封号 | 出差多、家里电脑常关 |
| C. 云服务器常驻 | 云主机桌面 | ✅ | 30–100 元/月 | 中：IP 纯净度不如家宽 | 已经有一台常开机器 |

**为什么默认是 A**：BOSS 的风控主要看两件事——登录态和设备/IP 指纹。机房 IP 在高频访问下很容易触发滑块验证甚至限制账号。家宽 + 真实浏览器 + 已有的 cookie，是这套流程能长期跑下去的唯一前提。

方案 A 的"自动化"完全不依赖你人在不在，也不依赖手机——电脑开机就行。要更稳，可以把脚本挂到一台常年开着的小主机上。

### B 的代价，说清楚再决定

GitHub Actions 能跑但要三件事同时成立：

1. 用 `xvfb-run` 给 CloakBrowser 一个虚拟显示（无头模式反而更容易被识别）
2. 把 cookie 存进 Secrets，并且**定期手动更新**——过期就整条流水线静默失效
3. 接受"某天开始全部被验证码拦住"的可能，且这个失败不会有明显报错

如果确实要走 B，骨架长这样（**不建议直接上**）：

```yaml
# .github/workflows/daily-jd.yml
name: daily-jd
on:
  schedule: [{ cron: '40 0 * * *' }]   # UTC 00:40 = 北京时间 08:40
  workflow_dispatch:
jobs:
  crawl:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.11' }
      - run: sudo apt-get install -y xvfb fonts-noto-cjk
      - run: pip install -r pipeline/requirements.txt
      - name: restore cookie
        run: echo "${{ secrets.BOSS_COOKIE }}" > pipeline/state/cookie.txt
      - run: xvfb-run -a python pipeline/crawl.py
      - run: python pipeline/merge_cards.py pipeline/candidates/latest.json
      - run: git config user.name bot && git add drill/cards.json && git commit -m "cards: daily" && git push
```

---

## 方案 A 的完整步骤

### 1. 部署（已完成）

简历站已在 Pages 上，`drill/` 跟着仓库一起发布，**线上地址：**

```
https://ccccty.github.io/resume/drill/
```

不需要单独的构建步骤，`git push` 到 `main` 后 Pages 自己重建，通常 1–2 分钟生效（CDN 最长缓存 10 分钟）。

### 2. 手机上怎么拿到每天的新卡

**日常增量不需要任何手动操作。** 页面每次打开都会带时间戳拉一次 `cards.json`（`?t=...` + `no-store`），所以只要 `cards.json` 是新的，手机打开就是新的。

| 场景 | 手机上要做什么 |
|---|---|
| 每天新增的 JD 卡片 | 什么都不用做，打开就是最新 |
| 我改了 `index.html` 本身（界面/内置卡） | 数据页点「刷新题库」，强制重载绕过缓存 |
| 想确认拿到的是哪一版 | 数据页底部看「页面版本 / JD 增量 / 数据更新于」 |

完整的每日链路：

```
08:40 本机自动化 → 抓 BOSS → 抽词 → 写 candidates/日期.json
                 → merge_cards.py 入池 drill/cards.json
                 → git push
                 → Pages 重建
                 → 手机打开 drill 页面即读到新卡
```

### 3. 手机加到主屏（一次性）

iOS Safari / Android Chrome 打开线上地址 → 分享 → 添加到主屏幕。之后点图标就是全屏应用，每天打开自动推 8 张。

扫码直达（`drill/qr.png`）：

<img src="../drill/qr.png" width="180" alt="二维码">

**两个必须知道的坑：**

- **iOS 主屏图标和 Safari 标签页的存储是分开的。** 在主屏里答过的进度，用 Safari 打开同一地址看不到。选定一种方式用到底，别两边混用。
- **iOS 会清理长期不访问站点的本地存储。** 进度在 `localStorage`，理论上 7 天不打开有被回收的风险，实际很少触发。养成每月在数据页点一次「导出进度」的习惯，换机时也用得上。

### 4. 首次抓取需要扫码登录

`boss-scrape` 复用登录态，第一次跑会开浏览器等你扫码。扫码一次，之后靠 cookie 静默运行几十天。

先在终端手动跑一次确认环境：

```bash
# 环境自检（装 CloakBrowser / Playwright，验证 navigator.webdriver 已隐藏）
# 在 WorkBuddy 里直接说「配置 boss 抓取环境」，会调用 boss-setup 技能
```

### 5. 定时任务

已建好一个每天 08:40 的自动化（见 WorkBuddy 的自动化列表），逻辑是：

```
boss-scrape 抓 4 城 × 4 方向 → 频次统计 → 生成候选 → merge_cards.py → git push
```

改城市或方向，只改 `pipeline/config.json`，不用动别的。

---

## 开源替代：不想依赖 WorkBuddy 的话

`boss-scrape` 底层就是两个开源件：**Playwright**（浏览器自动化）+ **CloakBrowser**（反检测补丁）。它们本身不绑定 WorkBuddy，你可以自己写脚本绕开 skill。

这个仓库的策略是**接口中立**：

- 抓取端唯一产出：`pipeline/candidates/YYYY-MM-DD.json`（格式见 `jd_to_cards.md`）
- 合并端唯一输入：同一个文件

所以想换实现，只需要替换「谁产出这个 JSON」。三种写法：

| 做法 | 工作量 | 说明 |
|---|---|---|
| 用 `boss-scrape` 技能 | 0 | 已经处理好登录态复用、两阶段抓取、限流恢复 |
| 自己写 Playwright + CloakBrowser | 2–3 天 | 要自己解决登录态持久化、详情页限流、去重 |
| 找现成开源爬虫 | 看运气 | BOSS 站点改造频繁，能长期维护的开源项目基本没有 |

写卡那一步同理：默认交给 LLM 按 `jd_to_cards.md` 生成，你也可以自己在 `candidates/` 里手写 JSON，`merge_cards.py` 一样收。

---

## 进度多端同步（可选项）

现在进度在浏览器 `localStorage` 里，**卡片共享、进度独立**。这与 Anki 的默认体验一致，多数人够用。

要真同步，两条路：

1. **轻量版**：每天手动点一次「导出进度」，文件存网盘；换设备时导入。零成本，30 秒。
2. **正经版**：接一个后端。给 5 个字段（`cardId / ef / ivl / due / reps`）建一张表，加一行 `fetch` 就行。用 Supabase 或 WorkBuddy 云服务都可以，代码改动约 40 行。需要的话我可以直接接上。

---

## 目录结构

```
drill/
  index.html          单文件应用（内置 129 张卡 + 运行时合并 cards.json）
  cards.json          JD 新增卡，由 merge_cards.py 维护
pipeline/
  config.json         城市、方向、关键词、阈值
  jd_to_cards.md      抽词与写卡规范（人机共用）
  merge_cards.py      合并 + 校验 + 去重
  candidates/         每天的候选卡（YYYY-MM-DD.json）
  raw/                抓取原始数据（可 gitignore）
```

---

## 风控清单

- 每个关键词每天只翻 3 页列表（`maxPagesPerKeyword`），别贪
- 请求间隔不要压到 1 秒以内，详情页尤其
- 只在**一个**设备上跑，多台并发登录同一账号是明显的异常信号
- cookie 失效时不要反复重试，停下来重新扫码
- 只抓自己看得过来的量。一天 100+ 个岗位的 JD，人工也消化不了，抓 30–50 个足够

---

## 常见问题

**Q：手机上打开看不到新卡？**
浏览器强缓存。页面已经加了 `?t=` 时间戳，正常情况下刷新就有。如果还是没有，检查 `cards.json` 是否真的 push 上去了（打开 `.../drill/cards.json` 直接看）。

**Q：本地双击 html，新卡不显示？**
预期行为。`file://` 下浏览器禁止 fetch 本地文件，此时只读内置的 129 张。想要新卡就用 Pages 地址或起个本地服务（`python -m http.server`）。

**Q：卡片加错了想删？**
打开 `drill/cards.json` 删掉那个对象，push 即可。进度记录还留在浏览器里，无害。

**Q：能不能只加我感兴趣的？**
可以。`candidates/` 里的 JSON 你随便删减，`merge_cards.py` 只认留下来的。或者给候选卡加 `"cat"` 之外的过滤逻辑。
