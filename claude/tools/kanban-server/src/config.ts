export interface RemoteHost {
  host: string;
  user?: string;
  repos: Record<string, string>;
  zellijLayout?: string;
}

export interface KanbanConfig {
  port: number;
  dataDir: string;
  remotes: Record<string, RemoteHost>;
  defaultRemote?: string;
}

const DEFAULTS: KanbanConfig = {
  port: 3456,
  dataDir: "~/.claude/kanban",
  remotes: {},
  defaultRemote: undefined,
};

export async function loadConfig(dataDir: string): Promise<KanbanConfig> {
  try {
    const raw = await Deno.readTextFile(`${dataDir}/config.json`);
    const parsed = JSON.parse(raw);
    return {
      port: parsed.port ?? DEFAULTS.port,
      dataDir: parsed.dataDir ?? DEFAULTS.dataDir,
      remotes: parsed.remotes ?? DEFAULTS.remotes,
      defaultRemote: parsed.defaultRemote ?? DEFAULTS.defaultRemote,
    };
  } catch {
    return { ...DEFAULTS };
  }
}
