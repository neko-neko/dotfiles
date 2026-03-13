import { assertEquals } from "@std/assert";
import { loadConfig } from "./config.ts";
import type { KanbanConfig } from "./config.ts";

Deno.test("loadConfig reads config.json and returns typed config with remotes", async () => {
  const tmpDir = await Deno.makeTempDir();
  const config = {
    port: 9999,
    dataDir: "/custom/data",
    remotes: {
      "my-server": {
        host: "my-server.local",
        user: "deploy",
        repos: { app: "/srv/app" },
        zellijLayout: "compact",
      },
    },
    defaultRemote: "my-server",
  };
  await Deno.writeTextFile(`${tmpDir}/config.json`, JSON.stringify(config));

  const result = await loadConfig(tmpDir);

  assertEquals(result.port, 9999);
  assertEquals(result.dataDir, "/custom/data");
  assertEquals(result.remotes["my-server"].host, "my-server.local");
  assertEquals(result.remotes["my-server"].user, "deploy");
  assertEquals(result.remotes["my-server"].repos["app"], "/srv/app");
  assertEquals(result.remotes["my-server"].zellijLayout, "compact");
  assertEquals(result.defaultRemote, "my-server");

  await Deno.remove(tmpDir, { recursive: true });
});

Deno.test("loadConfig returns defaults when config.json is missing", async () => {
  const tmpDir = await Deno.makeTempDir();

  const result = await loadConfig(tmpDir);

  const expected: KanbanConfig = {
    port: 3456,
    dataDir: "~/.claude/kanban",
    remotes: {},
    defaultRemote: undefined,
  };
  assertEquals(result, expected);

  await Deno.remove(tmpDir, { recursive: true });
});

Deno.test("loadConfig returns defaults when remotes field is missing", async () => {
  const tmpDir = await Deno.makeTempDir();
  const config = { port: 7777, dataDir: "/some/dir" };
  await Deno.writeTextFile(`${tmpDir}/config.json`, JSON.stringify(config));

  const result = await loadConfig(tmpDir);

  assertEquals(result.port, 7777);
  assertEquals(result.dataDir, "/some/dir");
  assertEquals(result.remotes, {});
  assertEquals(result.defaultRemote, undefined);

  await Deno.remove(tmpDir, { recursive: true });
});
