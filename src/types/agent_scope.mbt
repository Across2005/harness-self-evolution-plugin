///|
/// 子 Agent 定义文件的作用域（v2.1，`docs/subagent-factory.md`；无 1.0 对应物）。
///
/// · `Plugin` = 插件自己的数据根下的 `agents/` 目录（`<数据根>/agents/`），
///   插件自管理，删除与重建都不影响宿主；
/// · `User` = 宿主的用户级目录 `~/.zcode/agents/` —— **跨出插件数据根**，
///   ZCode loader 会在后续会话中发现并加载那里的定义，
///   文件内容会成为可被调用的 agent 系统提示词。
///
/// 后者是刻意的显式选择：MCP 协议里没有「请求宿主即时 spawn 一个子 agent
/// 会话」的方法，插件能做的只有管理定义文件（创建 ≠ 派发），
/// 影响面必须写进工具描述让 LLM 与用户都有感知（见 mcp/tools.mbt 的
/// create_sub_agent 描述文案）。
pub(all) enum AgentScope {
  /// 插件数据目录内的定义（默认）
  Plugin
  /// 宿主用户目录 `~/.zcode/agents/` 内的定义
  User
} derive(Eq, Debug)
