/**
 * Plugin Scanner - Scans Harness plugins and extracts metadata
 *
 * Scans:
 * - Official plugins from ZCode plugins directory
 * - Community plugins from configured paths
 * - Custom plugins from workspace
 */

import * as fs from 'fs-extra';
import * as path from 'path';
import { PluginMetadata, PluginMetrics } from '../types';

export class PluginScanner {
  private defaultPaths: string[];
  private cachePath: string;
  private pluginCache: Map<string, PluginMetadata> = new Map();

  constructor(customPaths?: string[], cachePath?: string) {
    // Default paths for ZCode plugins
    const homeDir = process.env.HOME || process.env.USERPROFILE || '';
    this.defaultPaths = customPaths ?? [
      path.join(homeDir, '.zcode', 'cli', 'plugins', 'cache', 'zcode-plugins-official'),
      path.join(homeDir, '.zcode', 'plugins'),
      path.join(homeDir, '.agents', 'plugins')
    ];

    this.cachePath = cachePath ?? path.join(homeDir, '.harness-evolution', 'plugin-cache.json');
  }

  /**
   * Scan all plugins from default and custom paths
   */
  async scanAll(forceRescan: boolean = false): Promise<Map<string, PluginMetadata>> {
    // Load from cache if available and not forcing rescan
    if (!forceRescan && await fs.pathExists(this.cachePath)) {
      const cached = await this.loadCache();
      if (cached.size > 0) {
        this.pluginCache = cached;
        return cached;
      }
    }

    // Clear cache for fresh scan
    this.pluginCache.clear();

    // Scan each path
    for (const scanPath of this.defaultPaths) {
      await this.scanPath(scanPath, 'official');
    }

    // Save cache
    await this.saveCache();

    return this.pluginCache;
  }

  /**
   * Scan a specific path for plugins
   */
  async scanPath(scanPath: string, type: 'official' | 'community' | 'custom'): Promise<void> {
    if (!await fs.pathExists(scanPath)) {
      console.log(`[Scanner] Path does not exist: ${scanPath}`);
      return;
    }

    const entries = await fs.readdir(scanPath, { withFileTypes: true });
    
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      
      const pluginDir = path.join(scanPath, entry.name);
      await this.scanPluginDirectory(pluginDir, type);
    }
  }

  /**
   * Scan a single plugin directory
   */
  private async scanPluginDirectory(pluginDir: string, type: 'official' | 'community' | 'custom'): Promise<void> {
    try {
      // Look for package.json or skill manifest
      const packageJsonPath = path.join(pluginDir, 'package.json');
      const skillManifestPath = path.join(pluginDir, 'SKILL.md');
      const hasPackageJson = await fs.pathExists(packageJsonPath);
      const hasSkillManifest = await fs.pathExists(skillManifestPath);

      // A directory with no manifest is not a plugin — skip it
      if (!hasPackageJson && !hasSkillManifest) {
        return;
      }
      
      let pluginName: string;
      let pluginVersion: string;
      let capabilities: string[] = [];
      let tools: string[] = [];
      let events: string[] = [];
      let dependencies: string[] = [];

      // Try to read package.json
      if (hasPackageJson) {
        const packageJson = await fs.readJson(packageJsonPath);
        pluginName = packageJson.name || path.basename(pluginDir);
        pluginVersion = packageJson.version || '0.0.0';
        dependencies = Object.keys(packageJson.dependencies || {});
      } else {
        pluginName = path.basename(pluginDir);
        pluginVersion = '0.0.0';
      }

      // Extract plugin ID (name-version format)
      const pluginId = `${pluginName}-${pluginVersion}`;

      // Skip if already scanned (prefer first found)
      if (this.pluginCache.has(pluginId)) {
        return;
      }

      // Scan for skills (SKILL.md files)
      const skillFiles = await this.findSkillFiles(pluginDir);
      for (const skillFile of skillFiles) {
        const skillInfo = await this.parseSkillFile(skillFile);
        capabilities.push(...skillInfo.capabilities);
        tools.push(...skillInfo.tools);
      }

      // Scan for MCP tools (if MCP server)
      const mcpTools = await this.scanMCPTools(pluginDir);
      tools.push(...mcpTools);

      // Calculate initial metrics
      const metrics = await this.calculateMetrics(pluginDir, tools, capabilities);

      // Create metadata
      const metadata: PluginMetadata = {
        plugin_id: pluginId,
        name: pluginName,
        version: pluginVersion,
        type,
        capabilities: [...new Set(capabilities)],
        tools: [...new Set(tools)],
        events: [...new Set(events)],
        dependencies,
        scan_timestamp: new Date().toISOString(),
        path: pluginDir,
        initial_metrics: metrics
      };

      this.pluginCache.set(pluginId, metadata);
      console.log(`[Scanner] Found plugin: ${pluginId} (${tools.length} tools, ${capabilities.length} capabilities)`);

    } catch (error) {
      console.error(`[Scanner] Error scanning ${pluginDir}:`, error);
    }
  }

  /**
   * Find all SKILL.md files in a plugin directory
   */
  private async findSkillFiles(pluginDir: string): Promise<string[]> {
    const skillFiles: string[] = [];
    
    async function scanDir(dir: string): Promise<void> {
      const entries = await fs.readdir(dir, { withFileTypes: true });
      
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        
        if (entry.isDirectory()) {
          await scanDir(fullPath);
        } else if (entry.name === 'SKILL.md') {
          skillFiles.push(fullPath);
        }
      }
    }

    try {
      await scanDir(pluginDir);
    } catch {
      // Ignore errors
    }

    return skillFiles;
  }

  /**
   * Parse a SKILL.md file to extract capabilities and tools
   */
  private async parseSkillFile(skillPath: string): Promise<{ capabilities: string[]; tools: string[] }> {
    const capabilities: string[] = [];
    const tools: string[] = [];

    try {
      const content = await fs.readFile(skillPath, 'utf-8');
      
      // Extract capabilities from description
      const capabilityPatterns = [
        /can\s+(\w+)/gi,
        /supports?\s+(\w+)/gi,
        /provides?\s+(\w+)/gi,
        /handles?\s+(\w+)/gi
      ];

      for (const pattern of capabilityPatterns) {
        const matches = content.matchAll(pattern);
        for (const match of matches) {
          if (match[1]) {
            capabilities.push(match[1].toLowerCase());
          }
        }
      }

      // Extract tool names from code blocks or tool references
      const toolPattern = /tool[=:]\s*['"`]?(\w+)['"`]?/gi;
      const toolMatches = content.matchAll(toolPattern);
      for (const match of toolMatches) {
        if (match[1]) {
          tools.push(match[1]);
        }
      }

    } catch (error) {
      console.error(`[Scanner] Error parsing skill file ${skillPath}:`, error);
    }

    return { capabilities, tools };
  }

  /**
   * Scan for MCP tools in a plugin
   */
  private async scanMCPTools(pluginDir: string): Promise<string[]> {
    const tools: string[] = [];

    try {
      // Look for MCP server files
      const serverFiles = await this.findFiles(pluginDir, /\.(ts|js|mjs)$/);
      
      for (const serverFile of serverFiles) {
        const content = await fs.readFile(serverFile, 'utf-8');
        
        // Extract tool names from registerTool or tool calls
        const toolPatterns = [
          /registerTool\s*\(\s*['"`]([^'"`]+)['"`]/g,
          /\.tool\s*\(\s*['"`]([^'"`]+)['"`]/g,
          /name:\s*['"`]([^'"`]+)['"`]/g
        ];

        for (const pattern of toolPatterns) {
          const matches = content.matchAll(pattern);
          for (const match of matches) {
            if (match[1] && !match[1].includes('$')) {
              tools.push(match[1]);
            }
          }
        }
      }
    } catch (error) {
      // Ignore errors
    }

    return tools;
  }

  /**
   * Find files matching a pattern
   */
  private async findFiles(dir: string, pattern: RegExp): Promise<string[]> {
    const files: string[] = [];

    async function scanDir(currentDir: string): Promise<void> {
      const entries = await fs.readdir(currentDir, { withFileTypes: true });
      
      for (const entry of entries) {
        const fullPath = path.join(currentDir, entry.name);
        
        if (entry.isDirectory() && !entry.name.startsWith('.') && entry.name !== 'node_modules') {
          await scanDir(fullPath);
        } else if (entry.isFile() && pattern.test(entry.name)) {
          files.push(fullPath);
        }
      }
    }

    try {
      await scanDir(dir);
    } catch {
      // Ignore errors
    }

    return files;
  }

  /**
   * Calculate initial metrics for a plugin
   */
  private async calculateMetrics(
    pluginDir: string, 
    tools: string[], 
    capabilities: string[]
  ): Promise<PluginMetrics> {
    // Complexity score based on number of tools and capabilities
    const toolComplexity = Math.min(tools.length * 0.5, 5);
    const capabilityComplexity = Math.min(capabilities.length * 0.3, 3);
    const complexityScore = Math.min(toolComplexity + capabilityComplexity + 2, 10);

    // Interface clarity (inverse of complexity, adjusted by documentation)
    let documentationScore = 5;
    const skillPath = path.join(pluginDir, 'SKILL.md');
    if (await fs.pathExists(skillPath)) {
      const content = await fs.readFile(skillPath, 'utf-8');
      // Simple heuristic: longer docs = better
      documentationScore = Math.min(content.length / 500, 5) + 5;
    }
    
    const interfaceClarity = Math.max(10 - complexityScore * 0.5, 3) + (documentationScore - 5) * 0.5;

    // Documentation quality
    const documentationQuality = documentationScore;

    return {
      complexity_score: Math.round(complexityScore * 10) / 10,
      interface_clarity: Math.round(Math.min(interfaceClarity, 10) * 10) / 10,
      documentation_quality: Math.round(Math.min(documentationQuality, 10) * 10) / 10,
      usage_frequency: 'idle' // Will be updated by monitor
    };
  }

  /**
   * Load plugin cache from file
   */
  private async loadCache(): Promise<Map<string, PluginMetadata>> {
    try {
      const content = await fs.readFile(this.cachePath, 'utf-8');
      const data = JSON.parse(content);
      return new Map(Object.entries(data));
    } catch {
      return new Map();
    }
  }

  /**
   * Save plugin cache to file
   */
  private async saveCache(): Promise<void> {
    const data = Object.fromEntries(this.pluginCache);
    await fs.ensureDir(path.dirname(this.cachePath));
    await fs.writeFile(this.cachePath, JSON.stringify(data, null, 2), 'utf-8');
  }

  /**
   * Get a specific plugin by ID
   */
  getPlugin(pluginId: string): PluginMetadata | undefined {
    return this.pluginCache.get(pluginId);
  }

  /**
   * Get all cached plugins
   */
  getAllPlugins(): Map<string, PluginMetadata> {
    return new Map(this.pluginCache);
  }
}
