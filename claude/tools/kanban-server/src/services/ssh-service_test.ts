import { assertEquals, assertStringIncludes } from "@std/assert";
import { SshService } from "./ssh-service.ts";

Deno.test("buildSshArgs constructs correct SSH command", () => {
  const svc = new SshService();
  const args = svc.buildSshArgs("mac-mini", "echo ok");
  assertEquals(args[0], "ssh");
  assertEquals(args[1], "-o");
  assertEquals(args[2], "ConnectTimeout=5");
  assertEquals(args[3], "mac-mini");
  assertEquals(args[4], "echo ok");
});

Deno.test("buildSshArgs includes user when specified", () => {
  const svc = new SshService();
  const args = svc.buildSshArgs("mac-mini", "echo ok", { user: "admin" });
  assertEquals(args[3], "admin@mac-mini");
});

Deno.test("execLocal runs a local command successfully", async () => {
  const svc = new SshService();
  const result = await svc.execLocal(["echo", "hello"]);
  assertEquals(result.success, true);
  assertStringIncludes(result.stdout, "hello");
});
