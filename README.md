# AI Daily Digest

一个可本地运行的 AI 日报生成工具：从 **150 个信息源**抓取内容，按时间窗口过滤，再由 AI 评分与摘要，最终输出结构化 Markdown 日报。
`r`n
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

## 使用方式（推荐顺序）

## 方式 A：自然语言触发（最推荐）

```bat
scripts\digest-intent.cmd 来一份今日日报
scripts\digest-intent.cmd AI快讯 英文
scripts\digest-intent.cmd AI深度日报 waytoagi
scripts\digest-intent.cmd AI日报 仅openai gpt-5.4
```

### 支持关键词（可组合）

- 类型：`今日日报` `晨报` `午报` `晚报` `快讯` `速览` `深度` `周报`
- 语言：`中文` `英文` / `english`
- 模型：`flash-latest` `flash-preview` `pro-preview` `3.1-pro-preview` `gpt-5.4` `gpt-5.3`
- 策略：`waytoagi` `仅openai` / `openai-only`

---

## 方式 B：固定快捷命令

```bat
scripts\digest-today.cmd
scripts\digest-brief.cmd
scripts\digest-deep.cmd
scripts\digest-weekly.cmd
scripts\digest-openai-only.cmd
```

含义：
- `digest-today`：48h / Top 15 / 中文
- `digest-brief`：24h / Top 10
- `digest-deep`：72h / Top 20
- `digest-weekly`：7天 / Top 20
- `digest-openai-only`：仅 OpenAI

---

## 方式 C：直接命令行参数运行

```bash
npx -y bun scripts/digest.ts --hours 48 --top-n 15 --lang zh --output ./reports/digest-manual.md
```

常用参数：
- `--hours <n>`
- `--top-n <n>`
- `--lang zh|en`
- `--waytoagi-limit <n>`
- `--output <path>`
- `--health-log <path>`

---

## 方式 D：在 Codex / Claude Code 中调用

可直接让代理执行本地命令，例如：

```text
请在项目目录执行：scripts\digest-intent.cmd 来一份今日日报
```

---

## 输出与目录

- 日报输出（默认）：`./reports/digest-YYYYMMDD-HHmm.md`
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


