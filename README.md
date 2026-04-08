# AI Daily Digest

一个可本地运行的 AI 日报生成工具：从 **150 个信息源**抓取内容，按时间窗口过滤，再由 AI 评分与摘要，最终输出结构化 Markdown 日报。
## 信息源说明（当前默认配置）

- 总信息源：**150 个**
- 构成：
  - **92 个**：Karpathy 推荐基础源（HN 技术博客集合）
  - **58 个**：`spsz0831` 补充源（中文/垂直渠道等）

> 源列表维护在 `scripts/digest.ts` 中，可按需继续增删。

---

## 核心功能

### 1) 150 源聚合抓取
- 并发抓取 RSS/Atom
- 自动统计成功/失败源
- 输出健康日志（可用于后续清洗）

### 2) 时间窗口过滤
- 支持 24h / 48h / 72h / 7d
- 只保留时效内容，减少噪音

### 3) AI 评分与分类
- 多维评分（相关性/质量/时效）
- 自动分类、关键词提取
- Gemini 为主，OpenAI 兼容接口兜底

### 4) AI 摘要与看点
- Top N 文章摘要
- 今日看点（趋势总结）
- Markdown 可直接用于知识库/飞书/Obsidian

### 5) 容错与可维护
- Gemini 异常自动切兜底模型
- 支持健康分析脚本，生成“建议禁用源”

---

## 环境要求

- Windows（已内置 `.cmd` 快捷入口）
- Node.js / npm（用于 `npx`)
- Bun（可通过 `npx -y bun` 自动拉起）
- 至少一个 API Key：
  - `GEMINI_API_KEY`（推荐）
  - 或 `OPENAI_API_KEY`（兜底或单独使用）

---

## 快速开始

### 1) 克隆仓库

```bash
git clone https://github.com/spsz831/ai-daily-digest.git
cd ai-daily-digest
```

### 2) 配置环境变量

参考 `.env.example`（不要提交真实密钥）：

```bash
GEMINI_API_KEY=...
OPENAI_API_KEY=...
GEMINI_MODEL=gemini-flash-latest
OPENAI_API_BASE=https://api.openai.com/v1
OPENAI_MODEL=gpt-5.4
```

---

## 使用方式

这个项目只保留 3 种运行方式。

### 1) 双击 `.cmd` 启动

直接运行：

```bat
scripts\ai-daily-digest-launcher.cmd
```

适合：
- 日常手动使用
- 不想记参数

### 2) PowerShell / 终端命令执行

```powershell
npx -y bun scripts/digest.ts --hours 48 --top-n 15 --lang zh --output ./reports/output/ai-daily-digest-manual.md --health-log ./reports/health/run-manual.json
```

常用参数：
- `--hours <n>`
- `--top-n <n>`
- `--lang zh|en`
- `--waytoagi-limit <n>`
- `--output <path>`
- `--health-log <path>`

### 3) 在 Codex / Claude Code 中执行

代理本质上也是执行这两个入口之一。推荐直接让代理运行下面两种命令：

```text
请在项目目录执行：scripts\ai-daily-digest-launcher.cmd
```

或：

```text
请在项目目录执行：npx -y bun scripts/digest.ts --hours 48 --top-n 15 --lang zh --output ./reports/output/ai-daily-digest-manual.md --health-log ./reports/health/run-manual.json
```

---

## 输出与目录

- 日报输出（默认）：`./reports/output/ai-daily-digest-YYYYMMDD-HHmm.md`
- 健康日志（默认）：`./reports/health/run-YYYYMMDD-HHmm.json`

可通过环境变量覆盖输出目录：

```bash
DIGEST_OUTPUT_DIR=./my-reports
```

---

## 健康清洗（建议每 2~3 天一次）

你可以基于健康日志统计长期超时/403 源，生成禁用建议名单（若你已集成分析脚本）：

- 连续异常源：建议禁用
- 波动源：观察后再处理

---

## 开源与安全

- 本仓库为开源公开项目（Public）
- 已默认忽略以下敏感/运行产物：
  - `.env` / `.env.local`
  - `reports/`
- 请勿提交真实 API Key、Token、Cookie

---

## License

MIT

---

由 **spsz0831** 制作，欢迎 Star / Issue / PR。


