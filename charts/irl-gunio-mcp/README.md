# irl-gunio-mcp

Unofficial gun.io MCP server ([InfiniteRoomLabs/gunio-mcp](https://github.com/InfiniteRoomLabs/gunio-mcp))
in `--serve` mode (FastMCP streamable HTTP), published at
`https://gunio-mcp.infiniteroomlabs.com/mcp` through a Cloudflare Tunnel and
gated by Cloudflare Access.

## Topology: no Service, no Ingress

The pod runs two containers:

1. `gunio-mcp` -- binds `127.0.0.1:8000` (pod loopback only).
2. `cloudflared` -- dials the Cloudflare edge outbound and forwards requests
   for the public hostname to `http://localhost:8000`.

There is deliberately **no Service and no IngressRoute**: the loopback bind
plus the sidecar make the tunnel the only path to the app, even from inside
the cluster. The hostname, DNS record, Access application, and tunnel are
managed by Terraform in the infra repo (`tunnel-gunio` leaf), not by this
chart. NetworkPolicy allows egress only to CoreDNS, 443/tcp, and 7844/udp+tcp
on public addresses.

## Secrets: Vault + External Secrets Operator

No secret is bw-synced or passed in values. Two chart-owned ExternalSecrets
(`externalSecrets.enabled`, default true) pull from HashiCorp Vault through a
`ClusterSecretStore` (default `vault-irl`, KV v2 mount `irl/`):

| Secret | Vault path | Keys |
|---|---|---|
| `gunio-mcp-secrets` | `irl/gunio-mcp/app` | all keys at the path (`dataFrom` extract); `GUNIO_COOKIE` today |
| `gunio-cloudflared-token` | `irl/gunio-mcp/cloudflared` | `token` |

Key names at `gunio-mcp/app` become env var names via `envFrom`, so phase 2
credentials (`GUNIO_USERNAME`/`GUNIO_PASSWORD`) or a later
`GUNIO_MCP_AUTH_TOKEN` need only a `vault kv put` -- no chart change.

**Ordering**: ESO (CRDs) and the ClusterSecretStore must exist before this
chart installs. **Rotation**: `envFrom` is not hot-reloaded -- after ESO
refreshes a Secret (refresh interval 1h), run
`kubectl -n gunio rollout restart deploy/irl-gunio-mcp`.

## Values that matter

| Value | Default | Note |
|---|---|---|
| `image.digest` | `REPLACE_WITH_DIGEST` | Pin to the v0.2.0 image digest before deploying |
| `cloudflared.image.digest` | `REPLACE_WITH_DIGEST` | Pin the sidecar too |
| `cloudflared.enabled` | `true` | `false` for a port-forward-only bring-up |
| `externalSecrets.storeRef.name` | `vault-irl` | ClusterSecretStore name |
| `app.env` | loopback bind | `GUNIO_MCP_INSECURE`/`GUNIO_MCP_WRITE_SCOPE` intentionally absent -- keep it that way |

## Install

```bash
helm install irl-gunio-mcp charts/irl-gunio-mcp -n gunio --create-namespace
```
