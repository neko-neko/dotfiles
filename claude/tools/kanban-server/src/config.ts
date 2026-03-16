export interface PeerNode {
  name: string;
  host: string;
  port: number;
  launchCommand?: string;
}

export interface KanbanConfig {
  port: number;
  dataDir: string;
  nodeName: string;
  peers: PeerNode[];
  syncthingWatchIntervalMs: number;
  peerPollIntervalMs: number;
}

export async function loadConfig(dataDir: string): Promise<KanbanConfig> {
  let parsed: Record<string, unknown> = {};
  try {
    const raw = await Deno.readTextFile(`${dataDir}/config.json`);
    parsed = JSON.parse(raw);
  } catch {
    // config.json missing or invalid — will fail on nodeName check below
  }

  const nodeName = parsed.nodeName as string | undefined;
  if (!nodeName) {
    throw new Error(
      "nodeName is required in config.json. Set nodeName to identify this node (e.g. 'macbook-main')",
    );
  }

  return {
    port: (parsed.port as number) ?? 3456,
    dataDir: (parsed.dataDir as string) ?? "~/.claude/kanban",
    nodeName,
    peers: (parsed.peers as PeerNode[]) ?? [],
    syncthingWatchIntervalMs: (parsed.syncthingWatchIntervalMs as number) ??
      5000,
    peerPollIntervalMs: (parsed.peerPollIntervalMs as number) ?? 10000,
  };
}
