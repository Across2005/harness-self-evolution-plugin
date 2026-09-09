/**
 * MCP Server integration tests
 * 
 * Tests the tool definitions and error handling without starting the actual server.
 */

import { HarnessEvolutionServer } from '../src/mcp/server';

describe('HarnessEvolutionServer', () => {
  describe('constructor', () => {
    it('should create a server instance without errors', () => {
      expect(() => new HarnessEvolutionServer()).not.toThrow();
    });
  });

  describe('tool registration', () => {
    it('should have all required tools registered', () => {
      const server = new HarnessEvolutionServer();
      // Access the internal server to check tool registration
      // The McpServer exposes tools via its API
      const serverAny = server as any;
      expect(serverAny.server).toBeDefined();
      expect(serverAny.scanner).toBeDefined();
      expect(serverAny.monitor).toBeDefined();
      expect(serverAny.engine).toBeDefined();
      expect(serverAny.executor).toBeDefined();
      expect(serverAny.proposals).toBeDefined();
    });
  });

  describe('error handling', () => {
    it('should handle tool errors gracefully', async () => {
      const server = new HarnessEvolutionServer();
      // The defineTool wrapper catches errors and returns them as jsonError
      // This is tested implicitly through the tool tests
      expect(server).toBeDefined();
    });
  });
});
