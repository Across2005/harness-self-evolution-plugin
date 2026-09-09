# Minimax Code 扫描支持 - 规格文档

## 目标
为 harness-self-evolution-plugin 添加 Minimax Code 的插件扫描支持，使插件能够发现和管理 Minimax Code 平台的插件。

## 背景
Minimax Code 是一款桌面端 AI Agent 应用，支持代码开发、日常工作流、自动化任务和远程控制。其插件系统使用 `.minimax-plugin/plugin.json` 作为清单文件。

## 技术规格

### 1. Minimax Code 插件目录结构
- **插件清单**：`.minimax-plugin/plugin.json`
- **用户插件目录**：`~/.minimax/plugins/` 或 `~/.minimax/extensions/`
- **MCP 配置**：`~/.minimax/mcp.json`

### 2. 需要修改的文件

#### 2.1 `src/scanner/scanner.mbt`
- 在 `default_scan_roots()` 函数中添加 Minimax Code 的插件目录
- 添加路径：`~/.minimax/plugins/` 和 `~/.minimax/extensions/`

#### 2.2 `.zcode-plugin/plugin.json`
- 在 `scan_targets` 数组中添加 Minimax Code 的路径
- 在 `engines` 对象中添加 `minimax-code` 支持

#### 2.3 `src/store/paths.mbt`
- 在 `user_agents_dir()` 函数中添加 Minimax Code 的子 Agent 路径支持
- 通过 `HARNESS_EVOLUTION_HOST` 环境变量切换到 `minimax-code`

#### 2.4 `README.md`
- 更新兼容性部分，添加 Minimax Code 说明
- 更新多宿主支持表格

### 3. 预期行为

#### 3.1 默认扫描
- 插件启动时自动扫描 Minimax Code 的插件目录
- 发现 `.minimax-plugin/plugin.json` 清单文件
- 提取插件元数据（name、version、dependencies 等）

#### 3.2 子 Agent 路径
- 默认使用 DeepSeek Harness 路径
- 设置 `HARNESS_EVOLUTION_HOST=minimax-code` 时使用 `~/.minimax/agents/`

#### 3.3 兼容性
- 支持 Minimax Code 的插件清单格式
- 与现有 DeepSeek Harness、ZCode、Claude Code 等平台兼容

## 验证标准

1. **扫描测试**：插件能够发现 Minimax Code 目录下的插件
2. **路径测试**：子 Agent 路径根据宿主类型正确切换
3. **兼容性测试**：现有测试全部通过（347/347）
4. **文档测试**：README.md 包含 Minimax Code 的兼容性说明

## 实现步骤

1. 修改 `src/scanner/scanner.mbt` 的 `default_scan_roots()`
2. 修改 `.zcode-plugin/plugin.json` 的 `scan_targets` 和 `engines`
3. 修改 `src/store/paths.mbt` 的 `user_agents_dir()`
4. 更新 `README.md` 的兼容性文档
5. 运行测试验证
