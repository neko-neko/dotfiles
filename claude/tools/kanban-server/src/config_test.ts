import { assertEquals, assertRejects } from "@std/assert";
import { loadConfig } from "./config.ts";

Deno.test("loadConfig returns config with nodeName and peers", async () => {
  const dir = await Deno.makeTempDir();
  await Deno.writeTextFile(
    `${dir}/config.json`,
    JSON.stringify({
      nodeName: "test-node",
      peers: [{ name: "peer-1", host: "peer-1.ts.net", port: 3456 }],
    }),
  );
  const config = await loadConfig(dir);
  assertEquals(config.nodeName, "test-node");
  assertEquals(config.peers.length, 1);
  assertEquals(config.peers[0].name, "peer-1");
  assertEquals(config.peers[0].host, "peer-1.ts.net");
  assertEquals(config.peers[0].port, 3456);
  await Deno.remove(dir, { recursive: true });
});

Deno.test("loadConfig throws when nodeName is missing", async () => {
  const dir = await Deno.makeTempDir();
  await Deno.writeTextFile(
    `${dir}/config.json`,
    JSON.stringify({ port: 3456 }),
  );
  await assertRejects(
    () => loadConfig(dir),
    Error,
    "nodeName is required",
  );
  await Deno.remove(dir, { recursive: true });
});

Deno.test("loadConfig throws when config.json is missing", async () => {
  const dir = await Deno.makeTempDir();
  await assertRejects(
    () => loadConfig(dir),
    Error,
    "nodeName is required",
  );
  await Deno.remove(dir, { recursive: true });
});

Deno.test("loadConfig uses defaults for optional fields", async () => {
  const dir = await Deno.makeTempDir();
  await Deno.writeTextFile(
    `${dir}/config.json`,
    JSON.stringify({ nodeName: "n" }),
  );
  const config = await loadConfig(dir);
  assertEquals(config.port, 3456);
  assertEquals(config.dataDir, "~/.claude/kanban");
  assertEquals(config.peers, []);
  assertEquals(config.syncthingWatchIntervalMs, 5000);
  assertEquals(config.peerPollIntervalMs, 10000);
  await Deno.remove(dir, { recursive: true });
});

Deno.test("loadConfig reads peer launchCommand", async () => {
  const dir = await Deno.makeTempDir();
  await Deno.writeTextFile(
    `${dir}/config.json`,
    JSON.stringify({
      nodeName: "main",
      peers: [{
        name: "mini",
        host: "mini.ts.net",
        port: 3456,
        launchCommand: "zellij action new-tab -- claude",
      }],
    }),
  );
  const config = await loadConfig(dir);
  assertEquals(
    config.peers[0].launchCommand,
    "zellij action new-tab -- claude",
  );
  await Deno.remove(dir, { recursive: true });
});
