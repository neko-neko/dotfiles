import { assertEquals } from "@std/assert";
import { GitSyncService } from "./git-sync-service.ts";

async function runGit(cwd: string, args: string[]): Promise<void> {
  const cmd = new Deno.Command("git", {
    args,
    cwd,
    stdout: "piped",
    stderr: "piped",
  });
  const output = await cmd.output();
  if (!output.success) {
    const stderr = new TextDecoder().decode(output.stderr);
    throw new Error(`git ${args.join(" ")} failed: ${stderr}`);
  }
}

async function setupGitRepo(): Promise<string> {
  const tmpDir = await Deno.makeTempDir({ prefix: "git-sync-test-" });
  await runGit(tmpDir, ["init"]);
  await runGit(tmpDir, ["config", "user.email", "test@example.com"]);
  await runGit(tmpDir, ["config", "user.name", "Test User"]);
  await Deno.writeTextFile(`${tmpDir}/init.txt`, "initial content");
  await runGit(tmpDir, ["add", "."]);
  await runGit(tmpDir, ["commit", "-m", "init"]);
  return tmpDir;
}

Deno.test("getStatus returns no-repo for non-git directory", async () => {
  const tmpDir = await Deno.makeTempDir({ prefix: "git-sync-test-" });
  try {
    const service = new GitSyncService(tmpDir);
    const status = await service.getStatus();
    assertEquals(status.isRepo, false);
    assertEquals(status.dirty, false);
    assertEquals(status.branch, "");
    assertEquals(status.hasRemote, false);
    assertEquals(status.lastCommit, "");
  } finally {
    await Deno.remove(tmpDir, { recursive: true });
  }
});

Deno.test("getStatus returns clean for fresh git repo", async () => {
  const tmpDir = await setupGitRepo();
  try {
    const service = new GitSyncService(tmpDir);
    const status = await service.getStatus();
    assertEquals(status.isRepo, true);
    assertEquals(status.dirty, false);
    assertEquals(status.branch.length > 0, true);
    assertEquals(status.hasRemote, false);
    assertEquals(status.lastCommit.includes("init"), true);
  } finally {
    await Deno.remove(tmpDir, { recursive: true });
  }
});

Deno.test("getStatus returns dirty after file change", async () => {
  const tmpDir = await setupGitRepo();
  try {
    await Deno.writeTextFile(`${tmpDir}/new-file.txt`, "new content");
    const service = new GitSyncService(tmpDir);
    const status = await service.getStatus();
    assertEquals(status.isRepo, true);
    assertEquals(status.dirty, true);
  } finally {
    await Deno.remove(tmpDir, { recursive: true });
  }
});

Deno.test("commitAndPush commits changes (no remote, push skipped)", async () => {
  const tmpDir = await setupGitRepo();
  try {
    await Deno.writeTextFile(`${tmpDir}/change.txt`, "some change");
    const service = new GitSyncService(tmpDir);
    const result = await service.commitAndPush("test commit");
    assertEquals(result.committed, true);
    assertEquals(result.pushed, false);
    assertEquals(result.error, undefined);

    // Verify repo is clean after commit
    const status = await service.getStatus();
    assertEquals(status.dirty, false);
    assertEquals(status.lastCommit.includes("test commit"), true);
  } finally {
    await Deno.remove(tmpDir, { recursive: true });
  }
});
