# ROADMAP — harness-self-evolution-plugin

> v2.6.0 已于 2026-09-17 发布（性能优化与缺陷修复：C1 定向重扫 + S1–S6 整改，测试 420→424；同批发布 mooncakes 0.2.6）。
> v2.5.0 已于 2026-09-16 发布（工程质量版本：全仓评审修复 56 个问题、测试 383→420）。
> 原预留的「v2.5 = 跨平台分发」目标顺延至 v2.7（v2.6.0 已由本次发布占用），内容不变。

## v2.7（目标：跨平台分发）

### 背景

v2.6.0 产物仍为 Windows native（`bin/harness-evolution.exe`）。Linux/macOS 沙盒首次安装需要 `allowBuilds` 显式放行，这是 L4 Install tested 绿章的主要拦路虎。

### 路线

1. **CI 构建矩阵**：在 GitHub Actions 上为 Windows / Linux / macOS 各构建一份 native 二进制
2. **Release 附件**：`v2.7.0` release 附带三平台二进制（`harness-evolution-windows.exe` / `harness-evolution-linux` / `harness-evolution-macos`）
3. **安装脚本**：提供 `install.sh`（Linux/macOS）和 `install.ps1`（Windows），自动检测平台并下载对应二进制
4. **dsh plugin 集成**：`dsh plugin --profile web add` 命令改为下载平台对应二进制，而非构建
5. **L4 验证**：在 dsh.so / dsh-market 沙盒中跑通 `allowBuilds` 免安装路径

### 里程碑

| 里程碑 | 目标 | 状态 |
|--------|------|------|
| v2.7.0-alpha.1 | CI 构建矩阵 + 三平台二进制 | 待开始 |
| v2.7.0-beta.1 | 安装脚本 + dsh plugin 集成 | 待开始 |
| v2.7.0-rc.1 | L4 沙盒验证通过 | 待开始 |
| v2.7.0 | 正式发布 + L5 端到端测试 | 待开始 |

### 依赖

- GitHub Actions 构建矩阵配置
- MoonBit 工具链跨平台支持（当前 moon 0.1.20260904 已支持 Windows/Linux/macOS）
- dsh.so / dsh-market 沙盒环境更新

### 已知风险

- MoonBit native 后端在不同平台的链接行为可能有差异
- `moonbitlang/async` 库的跨平台兼容性需要验证
- DSH 沙盒的 `allowBuilds` 机制可能随版本变化
