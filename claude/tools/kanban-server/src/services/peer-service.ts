import type { PeerNode } from "../config.ts";

export interface PeerStatus {
  name: string;
  online: boolean;
  latencyMs: number;
  activeSessions: number;
}

export interface NodeInfo {
  nodeName: string;
  activeSessions: unknown[];
  uptime: number;
}

export interface LaunchParams {
  taskId: string;
  boardId: string;
  projectPath: string;
  contextFile?: string;
}

export interface PeerLaunchResult {
  success: boolean;
  sessionId?: string;
  error?: string;
}

const TIMEOUT_MS = 3000;
const BACKOFF_THRESHOLD = 3;
const BACKOFF_DURATION_MS = 30000;

export class PeerService {
  private readonly peers: PeerNode[];
  private readonly fetchFn: typeof fetch;
  private failCounts: Map<string, number> = new Map();
  private backoffUntil: Map<string, number> = new Map();

  constructor(peers: PeerNode[], fetchFn?: typeof fetch) {
    this.peers = peers;
    this.fetchFn = fetchFn ?? globalThis.fetch.bind(globalThis);
  }

  private baseUrl(peer: PeerNode): string {
    return `http://${peer.host}:${peer.port}`;
  }

  isInBackoff(peerName: string): boolean {
    const until = this.backoffUntil.get(peerName);
    if (!until) return false;
    if (Date.now() >= until) {
      this.backoffUntil.delete(peerName);
      this.failCounts.set(peerName, 0);
      return false;
    }
    return true;
  }

  private recordSuccess(peerName: string): void {
    this.failCounts.set(peerName, 0);
    this.backoffUntil.delete(peerName);
  }

  private recordFailure(peerName: string): void {
    const count = (this.failCounts.get(peerName) ?? 0) + 1;
    this.failCounts.set(peerName, count);
    if (count >= BACKOFF_THRESHOLD) {
      this.backoffUntil.set(peerName, Date.now() + BACKOFF_DURATION_MS);
    }
  }

  private async fetchWithTimeout(
    url: string,
    init?: RequestInit,
  ): Promise<Response> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
      const response = await this.fetchFn(url, {
        ...init,
        signal: controller.signal,
      });
      return response;
    } finally {
      clearTimeout(timeoutId);
    }
  }

  async pingAll(): Promise<PeerStatus[]> {
    const results = await Promise.allSettled(
      this.peers.map(async (peer): Promise<PeerStatus> => {
        if (this.isInBackoff(peer.name)) {
          return {
            name: peer.name,
            online: false,
            latencyMs: 0,
            activeSessions: 0,
          };
        }

        const start = Date.now();
        try {
          const res = await this.fetchWithTimeout(
            `${this.baseUrl(peer)}/api/node/info`,
          );
          const latencyMs = Date.now() - start;
          if (res.ok) {
            const info = (await res.json()) as NodeInfo;
            this.recordSuccess(peer.name);
            return {
              name: peer.name,
              online: true,
              latencyMs,
              activeSessions: info.activeSessions?.length ?? 0,
            };
          }
          this.recordFailure(peer.name);
          return {
            name: peer.name,
            online: false,
            latencyMs,
            activeSessions: 0,
          };
        } catch {
          this.recordFailure(peer.name);
          return {
            name: peer.name,
            online: false,
            latencyMs: Date.now() - start,
            activeSessions: 0,
          };
        }
      }),
    );

    return results.map((r) =>
      r.status === "fulfilled"
        ? r.value
        : { name: "unknown", online: false, latencyMs: 0, activeSessions: 0 }
    );
  }

  async getNodeInfo(peer: PeerNode): Promise<NodeInfo> {
    const res = await this.fetchWithTimeout(
      `${this.baseUrl(peer)}/api/node/info`,
    );
    if (!res.ok) {
      throw new Error(
        `Failed to get node info from ${peer.name}: ${res.status}`,
      );
    }
    return (await res.json()) as NodeInfo;
  }

  async launchOnPeer(
    peer: PeerNode,
    params: LaunchParams,
  ): Promise<PeerLaunchResult> {
    const res = await this.fetchWithTimeout(
      `${this.baseUrl(peer)}/api/peers/${peer.name}/launch`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(params),
      },
    );
    return (await res.json()) as PeerLaunchResult;
  }
}
