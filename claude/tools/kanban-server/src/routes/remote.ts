import { Hono } from "@hono/hono";
import type { KanbanConfig } from "../config.ts";
import { SshService } from "../services/ssh-service.ts";

export function remoteRoutes(config: KanbanConfig): Hono {
  const app = new Hono();
  const ssh = new SshService();

  // GET /remote/hosts — list configured remote hosts
  app.get("/remote/hosts", (c) => {
    const hosts = Object.entries(config.remotes).map(([name, remote]) => ({
      name,
      host: remote.host,
      user: remote.user,
      repos: remote.repos,
      zellijLayout: remote.zellijLayout,
    }));
    return c.json({ hosts, defaultRemote: config.defaultRemote });
  });

  // GET /remote/ping — SSH ping check
  app.get("/remote/ping", async (c) => {
    const host = c.req.query("host") ?? config.defaultRemote;
    if (!host) {
      return c.json({
        error: "no host specified and no defaultRemote configured",
      }, 400);
    }
    const remote = config.remotes[host];
    if (!remote) {
      return c.json({ error: `unknown host: ${host}` }, 404);
    }
    const result = await ssh.ping(remote.host, remote.user);
    return c.json({ host, online: result.online, latencyMs: result.latencyMs });
  });

  // POST /remote/launch — launch Claude Code on remote
  app.post("/remote/launch", async (c) => {
    const body = await c.req.json();
    const { taskId, taskTitle, projectPath, context, host: requestedHost } =
      body;

    // Validation
    if (!taskId) {
      return c.json({ error: "taskId is required" }, 400);
    }
    if (!projectPath) {
      return c.json({ error: "projectPath is required" }, 400);
    }

    const hostName = requestedHost ?? config.defaultRemote;
    if (!hostName) {
      return c.json({
        error: "no host specified and no defaultRemote configured",
      }, 400);
    }
    const remote = config.remotes[hostName];
    if (!remote) {
      return c.json({ error: `unknown host: ${hostName}` }, 404);
    }

    const sessionName = `kanban-${taskId}`;
    const sshOpts = { user: remote.user };

    // 1. Git pull remote work repo
    await ssh.execSsh(remote.host, `cd ${projectPath} && git pull`, sshOpts);

    // 2. Git pull remote kanban repo
    if (remote.repos.kanban) {
      await ssh.execSsh(
        remote.host,
        `cd ${remote.repos.kanban} && git pull`,
        sshOpts,
      );
    }

    // 3. SCP context file if provided
    if (context) {
      const remotePath = `/tmp/kanban-context-${taskId}.md`;
      // Write context to a temp file locally, then scp
      const tmpFile = await Deno.makeTempFile({ prefix: "kanban-ctx-" });
      await Deno.writeTextFile(tmpFile, context);
      await ssh.scpTo(remote.host, tmpFile, remotePath, sshOpts);
      await Deno.remove(tmpFile);
    }

    // 4. SSH launch Claude Code in zellij session
    const titleArg = taskTitle ? ` --title '${taskTitle}'` : "";
    const launchCmd = [
      `cd ${projectPath}`,
      `zellij attach ${sessionName} --create -- claude${titleArg}`,
    ].join(" && ");
    // Launch detached so we don't block
    await ssh.execSsh(
      remote.host,
      `nohup bash -c '${launchCmd.replace(/'/g, "'\\''")}' > /dev/null 2>&1 &`,
      sshOpts,
    );

    return c.json({
      status: "launched",
      host: hostName,
      sessionName,
      taskId,
    });
  });

  // GET /remote/status — check zellij session status
  app.get("/remote/status", async (c) => {
    const taskId = c.req.query("taskId");
    const hostName = c.req.query("host") ?? config.defaultRemote;

    if (!taskId) {
      return c.json({ error: "taskId is required" }, 400);
    }
    if (!hostName) {
      return c.json({
        error: "no host specified and no defaultRemote configured",
      }, 400);
    }
    const remote = config.remotes[hostName];
    if (!remote) {
      return c.json({ error: `unknown host: ${hostName}` }, 404);
    }

    const sessionName = `kanban-${taskId}`;
    const result = await ssh.execSsh(
      remote.host,
      `zellij list-sessions 2>/dev/null | grep -q '^${sessionName}' && echo running || echo stopped`,
      { user: remote.user },
    );

    let status: "running" | "stopped" | "unknown" = "unknown";
    if (result.success) {
      const output = result.stdout.trim();
      if (output === "running") status = "running";
      else if (output === "stopped") status = "stopped";
    }

    return c.json({ taskId, host: hostName, sessionName, status });
  });

  return app;
}
