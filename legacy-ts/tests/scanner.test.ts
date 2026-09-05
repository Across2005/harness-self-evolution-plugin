import { PluginScanner } from '../src/scanner/index';
import * as fs from 'fs-extra';
import * as os from 'os';
import * as path from 'path';

describe('PluginScanner', () => {
  let tmpDir: string;
  let cachePath: string;
  let scanner: PluginScanner;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'evo-scan-'));
    cachePath = path.join(tmpDir, 'plugin-cache.json');
    // Restrict scan roots and cache to the temp dir so tests never touch real plugin dirs
    scanner = new PluginScanner([tmpDir], cachePath);
  });

  afterEach(async () => {
    await fs.remove(tmpDir);
  });

  async function makePluginDir(name: string, files: Record<string, string>): Promise<string> {
    const pluginDir = path.join(tmpDir, name);
    for (const [file, content] of Object.entries(files)) {
      await fs.outputFile(path.join(pluginDir, file), content, 'utf-8');
    }
    return pluginDir;
  }

  describe('scanPath', () => {
    it('should discover a plugin with a package.json and SKILL.md', async () => {
      await makePluginDir('my-plugin', {
        'package.json': JSON.stringify({ name: 'my-plugin', version: '2.1.0' }),
        'SKILL.md': '# My Plugin\nThis tool can navigate and supports clicks.'
      });

      await scanner.scanPath(tmpDir, 'community');
      const plugins = scanner.getAllPlugins();

      expect(plugins.size).toBe(1);
      const plugin = plugins.get('my-plugin-2.1.0');
      expect(plugin).toBeDefined();
      expect(plugin?.name).toBe('my-plugin');
      expect(plugin?.version).toBe('2.1.0');
      expect(plugin?.type).toBe('community');
    });

    it('should extract tools from MCP registerTool calls in source files', async () => {
      await makePluginDir('mcp-plugin', {
        'package.json': JSON.stringify({ name: 'mcp-plugin', version: '1.0.0' }),
        'src/server.ts': `
          server.registerTool('scan_plugins', { description: 'scan' }, cb);
          server.registerTool('propose_evolution', { description: 'propose' }, cb);
        `
      });

      await scanner.scanPath(tmpDir, 'official');
      const plugin = scanner.getAllPlugins().get('mcp-plugin-1.0.0');

      expect(plugin?.tools).toContain('scan_plugins');
      expect(plugin?.tools).toContain('propose_evolution');
    });

    it('should ignore directories without any manifest', async () => {
      await makePluginDir('empty-dir', { 'README.md': 'not a plugin' });

      await scanner.scanPath(tmpDir, 'community');

      expect(scanner.getAllPlugins().size).toBe(0);
    });

    it('should skip directories it cannot parse instead of throwing', async () => {
      // An unreadable subdirectory (simulated by a file where a dir is expected)
      await fs.outputFile(path.join(tmpDir, 'blocked'), 'not a directory');

      await expect(scanner.scanPath(tmpDir, 'community')).resolves.toBeUndefined();
    });
  });

  describe('scanAll', () => {
    it('should write the cache file after scanning', async () => {
      await makePluginDir('cached-plugin', {
        'package.json': JSON.stringify({ name: 'cached-plugin', version: '0.1.0' })
      });

      await scanner.scanAll(true);

      expect(scanner.getAllPlugins().size).toBe(1);
      expect(await fs.pathExists(cachePath)).toBe(true);

      // A fresh scanner should restore from cache without rescanning
      const second = new PluginScanner([path.join(tmpDir, 'nonexistent')], cachePath);
      await second.scanAll(false);
      expect(second.getAllPlugins().size).toBe(1);
    });
  });
});
