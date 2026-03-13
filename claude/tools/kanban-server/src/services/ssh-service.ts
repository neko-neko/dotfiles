export interface ExecResult {
  success: boolean;
  stdout: string;
  stderr: string;
}

export class SshService {
  buildSshArgs(
    host: string,
    command: string,
    opts?: { user?: string; timeout?: number },
  ): string[] {
    const timeout = opts?.timeout ?? 5;
    const target = opts?.user ? `${opts.user}@${host}` : host;
    return ["ssh", "-o", `ConnectTimeout=${timeout}`, target, command];
  }

  async execLocal(args: string[]): Promise<ExecResult> {
    const cmd = new Deno.Command(args[0], {
      args: args.slice(1),
      stdout: "piped",
      stderr: "piped",
    });
    const output = await cmd.output();
    return {
      success: output.success,
      stdout: new TextDecoder().decode(output.stdout).trim(),
      stderr: new TextDecoder().decode(output.stderr).trim(),
    };
  }

  execSsh(
    host: string,
    command: string,
    opts?: { user?: string; timeout?: number },
  ): Promise<ExecResult> {
    const args = this.buildSshArgs(host, command, opts);
    return this.execLocal(args);
  }

  async ping(
    host: string,
    user?: string,
  ): Promise<{ online: boolean; latencyMs: number }> {
    const start = Date.now();
    const result = await this.execSsh(host, "echo ok", { user, timeout: 5 });
    const latencyMs = Date.now() - start;
    return {
      online: result.success && result.stdout.includes("ok"),
      latencyMs,
    };
  }

  scpTo(
    host: string,
    localPath: string,
    remotePath: string,
    opts?: { user?: string },
  ): Promise<ExecResult> {
    const target = opts?.user ? `${opts.user}@${host}` : host;
    return this.execLocal([
      "scp",
      "-o",
      "ConnectTimeout=5",
      localPath,
      `${target}:${remotePath}`,
    ]);
  }
}
