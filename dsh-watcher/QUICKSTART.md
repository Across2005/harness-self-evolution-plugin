# DSH Watcher 快速开始

## 安装

### 方式一：从 GitHub 安装（推荐）

```sh
dsh plugin --profile web add github:aa2246740/dsh-watcher
```

### 方式二：本地构建安装

```sh
# 进入 dsh-watcher 目录
cd dsh-watcher

# 安装依赖
npm install

# 构建
npm run build

# 链接到 DSH
dsh plugin --profile web add .
```

## 使用

1. 重启 DSH Host
2. 刷新浏览器页面
3. 在会话标题栏中点击眼睛图标打开 Watcher 面板

## 与 harness-self-evolution-plugin 协同

当 harness-self-evolution-plugin 执行进化提案时：

1. 启动进化执行：`execute_evolution` MCP 工具
2. 在 DSH Web UI 中打开 Watcher 面板
3. 观察实时执行过程：
   - 模型推理时间
   - 工具执行时间
   - 并行任务分布
   - 重试和错误处理

## 功能说明

- **时间线视图**：按时间顺序显示所有执行步骤
- **分组视图**：将相同类型的工具调用分组显示
- **性能面板**：显示模型时间、工具时间、首 token 延迟
- **推理记录**：展示供应商暴露的 reasoning 内容

## 故障排除

### Watcher 面板不显示

1. 确认插件已安装：`dsh plugin --profile web list`
2. 重启 DSH Host
3. 刷新浏览器页面

### 性能数据不准确

- dsh-watcher 是只读插件，不会修改任何数据
- 性能数据来自 DSH 的会话快照
- 如果数据不完整，可能是会话历史尚未完全加载

## 更多信息

- [dsh-watcher 官方文档](https://github.com/aa2246740/dsh-watcher)
- [DESIGN.md](./DESIGN.md) - 交互约定
- [INTEGRATION.md](./INTEGRATION.md) - 与 harness-self-evolution-plugin 集成说明
