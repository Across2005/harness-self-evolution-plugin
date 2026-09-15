///|
/// 插件依赖图谱。用于跨插件协同进化分析。
///
/// **职责**：
/// - 构建插件间的依赖关系图
/// - 检测循环依赖
/// - 识别协同进化机会
/// - 分析版本冲突风险

///|
/// 依赖边：表示两个插件之间的依赖关系。
pub(all) struct DependencyEdge {
  /// 依赖方（消费者）
  from_plugin : String
  /// 被依赖方（提供者）
  to_plugin : String
  /// 依赖类型：required（必需）或 optional（可选）
  dep_type : DependencyType
} derive(Eq, Debug)

///|
/// 依赖类型。
pub(all) enum DependencyType {
  /// 必需依赖：缺少时插件无法工作
  Required
  /// 可选依赖：缺少时功能降级但可工作
  Optional
} derive(Eq, Debug)

///|
/// 依赖图谱。
pub(all) struct DependencyGraph {
  /// 所有依赖边
  edges : Array[DependencyEdge]
  /// 插件 ID 到依赖边的索引（用于快速查找）
  index : Map[String, Array[Int]]
} derive(Eq, Debug)

///|
/// 构建依赖图谱。
pub fn DependencyGraph::new(plugins : ArrayView[PluginMetadata]) -> DependencyGraph {
  let edges : Array[DependencyEdge] = []
  let index : Map[String, Array[Int]] = Map([])
  
  for i, plugin in plugins {
    // 确保每个插件都在索引中
    if !index.contains(plugin.plugin_id) {
      index.set(plugin.plugin_id, [])
    }
    
    // 处理依赖关系
    for dep in plugin.dependencies {
      let edge : DependencyEdge = {
        from_plugin: plugin.plugin_id,
        to_plugin: dep,
        dep_type: DependencyType::Required, // 默认为必需依赖
      }
      let edge_idx = edges.length()
      edges.push(edge)
      
      // 更新索引
      let from_indices = index.get(plugin.plugin_id).unwrap_or([])
      from_indices.push(edge_idx)
      index.set(plugin.plugin_id, from_indices)
      
      // 确保被依赖方也在索引中
      if !index.contains(dep) {
        index.set(dep, [])
      }
      let to_indices = index.get(dep).unwrap_or([])
      to_indices.push(edge_idx)
      index.set(dep, to_indices)
    }
  }
  
  { edges, index }
}

///|
/// 检测循环依赖。返回所有检测到的循环。
pub fn DependencyGraph::detect_cycles(self : DependencyGraph) -> Array[Array[String]] {
  let cycles : Array[Array[String]] = []
  let visited : Map[String, Int] = Map([]) // 0=未访问, 1=访问中, 2=已完成
  let path : Array[String] = []
  
  // 深度优先搜索检测循环
  fn dfs(
    node : String,
    graph : DependencyGraph,
    visited : Map[String, Int],
    path : Array[String],
    cycles : Array[Array[String]],
  ) -> Unit {
    visited.set(node, 1) // 标记为访问中
    path.push(node)
    
    // 获取当前节点的所有依赖
    let edge_indices = graph.index.get(node).unwrap_or([])
    for idx in edge_indices {
      let edge = graph.edges[idx]
      // 索引把每条边同时挂在两端点下；环检测只沿依赖方向（from → to）推进，
      // 否则任意单边 A→B 都会经反向边被当成 A-B-A 假环
      if edge.from_plugin != node {
        continue
      }
      let neighbor = edge.to_plugin
      
      match visited.get(neighbor) {
        Some(1) => {
          // 发现循环：从path中提取循环路径
          let cycle : Array[String] = []
          let mut found = false
          for p in path {
            if p == neighbor {
              found = true
            }
            if found {
              cycle.push(p)
            }
          }
          cycle.push(neighbor) // 闭合循环
          if cycle.length() > 0 {
            cycles.push(cycle)
          }
        }
        Some(2) => () // 已完成，跳过
        _ => dfs(neighbor, graph, visited, path, cycles)
      }
    }
    
    ignore(path.pop())
    visited.set(node, 2) // 标记为已完成
  }
  
  // 对所有未访问的节点进行DFS
  for node in self.index.keys() {
    if !visited.contains(node) {
      dfs(node, self, visited, [], cycles)
    }
  }
  
  cycles
}

///|
/// 获取插件的直接依赖。
pub fn DependencyGraph::get_dependencies(
  self : DependencyGraph,
  plugin_id : String,
) -> Array[String] {
  let deps : Array[String] = []
  let edge_indices = self.index.get(plugin_id).unwrap_or([])
  for idx in edge_indices {
    let edge = self.edges[idx]
    if edge.from_plugin == plugin_id {
      deps.push(edge.to_plugin)
    }
  }
  deps
}

///|
/// 获取依赖某插件的所有插件（反向依赖）。
pub fn DependencyGraph::get_dependents(
  self : DependencyGraph,
  plugin_id : String,
) -> Array[String] {
  let dependents : Array[String] = []
  let edge_indices = self.index.get(plugin_id).unwrap_or([])
  for idx in edge_indices {
    let edge = self.edges[idx]
    if edge.to_plugin == plugin_id {
      dependents.push(edge.from_plugin)
    }
  }
  dependents
}

///|
/// 识别协同进化机会：当一个插件发生变化时，哪些依赖它的插件可能需要同步更新。
pub fn DependencyGraph::identify_co_evolution_opportunities(
  self : DependencyGraph,
  changed_plugin : String,
) -> Array[String] {
  // 获取所有直接和间接依赖方
  let affected : Array[String] = []
  let visited : Map[String, Unit] = Map([])
  let queue : Array[String] = [changed_plugin]
  // 起点自身不计入结果（存在依赖环时 dependents 可能把它推回来）
  visited.set(changed_plugin, ())

  while queue.length() > 0 {
    let current = match queue.pop() {
      Some(c) => c
      None => break
    }

    // 获取依赖当前插件的所有插件
    let dependents = self.get_dependents(current)
    for dep in dependents {
      if !visited.contains(dep) {
        // 入队前即标记 visited：菱形依赖（同一节点经两条路径先后到达）时，
        // 若等出栈才标记，节点会被重复收进 affected
        visited.set(dep, ())
        affected.push(dep)
        queue.push(dep)
      }
    }
  }
  
  affected
}

///|
/// 分析版本冲突风险：检查依赖图中是否存在版本不兼容的风险。
/// 返回可能存在冲突的插件对。
pub fn DependencyGraph::analyze_version_conflicts(
  self : DependencyGraph,
  plugins : ArrayView[PluginMetadata],
) -> Array[(String, String, String)] {
  let conflicts : Array[(String, String, String)] = []
  
  // 构建插件名称到版本的映射
  let plugin_versions : Map[String, String] = Map([])
  for plugin in plugins {
    plugin_versions.set(plugin.name, plugin.version)
  }
  
  // 检查每个依赖关系
  for edge in self.edges {
    // 获取依赖方和被依赖方的插件名称
    let from_parts : Array[StringView] = []
    for part in edge.from_plugin.split("-") {
      from_parts.push(part)
    }
    let to_parts : Array[StringView] = []
    for part in edge.to_plugin.split("-") {
      to_parts.push(part)
    }
    let from_name = from_parts[0].to_owned()
    let to_name = to_parts[0].to_owned()
    
    // 检查是否存在版本信息
    let from_version = plugin_versions.get(from_name)
    let to_version = plugin_versions.get(to_name)
    
    // 如果依赖方指定了特定版本，检查是否与实际版本匹配
    // 这里简化处理：只检查是否存在同名不同版本的情况
    match (from_version, to_version) {
      (Some(fv), Some(tv)) => {
        // 检查是否存在多个版本的同名插件
        let mut count = 0
        for p in plugins {
          if p.name == to_name && p.version != tv {
            count += 1
          }
        }
        if count > 0 {
          conflicts.push((edge.from_plugin, edge.to_plugin, "Multiple versions of \{to_name} detected"))
        }
      }
      _ => ()
    }
  }
  
  conflicts
}
