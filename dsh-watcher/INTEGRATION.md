# DSH Watcher 集成说明

## 概述

`dsh-watcher` 是一个 DeepSeek Harness Web 的只读观察插件，用于可视化 Agent 的会话执行过程、模型推理时间和工具调用链路。

本目录包含 dsh-watcher 的源码副本，用于与 `harness-self-evolution-plugin` 集成。

## 功能特性

- **会话观察**：将 Session 收成可折叠的工作路径图
- **性能分析**：显示模型时间、工具时间、首 token 延迟
- **执行追踪**：可视化并行执行、重试、循环检测
- **推理记录**：展示供应商暴露的 reasoning 内容

## 安装方式

### 方式一：从 GitHub 安装（推荐）

```sh
dsh plugin --profile web add github:aa2246740/dsh-watcher
```

### 方式二：本地安装

```sh
# 在本项目目录中
cd dsh-watcher
npm install
npm run build

# 链接到 DSH
dsh plugin --profile web add ./dsh-watcher
```

## 与 harness-self-evolution-plugin 的集成

dsh-watcher 提供的会话观察功能可以与 harness-self-evolution-plugin 的进化执行器协同工作：

1. **执行监控**：当 harness-self-evolution-plugin 执行进化提案时，dsh-watcher 可以实时显示执行过程
2. **性能分析**：dsh-watcher 的性能指标可以帮助识别进化过程中的瓶颈
3. **调试支持**：通过 dsh-watcher 的详细执行追踪，可以更好地理解进化执行的每个步骤

## 使用场景

1. **观察进化执行**：启动进化提案后，在 DSH Web UI 中打开 dsh-watcher 面板
2. **分析性能**：查看模型推理时间、工具执行时间、并行任务分布
3. **调试问题**：当进化执行失败时，使用 dsh-watcher 追踪具体失败位置

## 注意事项

- dsh-watcher 是只读插件，不会修改任何数据
- 需要 DeepSeek Harness `0.1.2-rc.1` 或更高版本
- 需要 Node.js `^22.19.0` 或 `>=24`
