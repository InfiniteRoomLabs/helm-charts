# irl-openmessage

[OpenMessage](https://github.com/Deathnerd/openmessage) -- a Go daemon that pairs with Google Messages for Web and re-exposes the conversation as an MCP server -- run as **one** pod for a whole household instead of one daemon per machine.

The image is built from the `Deathnerd/openmessage` fork, which adds the remote-serving mode (`--mcp-sse` bound to a non-loopback address), the `/healthz` endpoint and the container packaging this chart depends on. `Chart.yaml`'s `appVersion` is a label; `image.digest` in values is the authoritative pin.

## The one-pod rule

The pairing with Google is a single logical device backed by one `session.json` on the data volume. Two daemons sharing that pairing fight over the session and Google can revoke it outright, which costs a re-pair from the phone.

So: `replicas: 1`, `strategy: Recreate` (never `RollingUpdate` -- a rolling update deliberately runs old and new at once), no HPA, no PodDisruptionBudget. "Briefly down" is correct for this workload; "briefly doubled" is the failure mode.

## Topology

```
client (LAN or tailnet)
  -> Traefik  websecure / wildcard TLS
       -> Middleware ipAllowList (source ranges)
         -> Service ClusterIP :7007
           -> Deployment (1 pod, Recreate)
                /data  -> static ZFS-backed PVC (existingClaim)
                /run/secrets/openmessage/token -> Secret (existingSecret), mode 0400
                egress -> 443/tcp to Google
```

There is no NodePort, no LoadBalancer, no public DNS record and no tunnel.

## Two independent gates, two different failures

| Symptom | Which gate | Fix |
|---|---|---|
| `403` | Traefik `ipAllowList` rejected the source IP, **or** the daemon rejected the `Host` header (`OPENMESSAGES_ALLOWED_HOSTS`) | Add the CIDR to `ingress.allowList.sourceRange`, or make `app.allowedHosts` / `ingress.host` match the name actually used |
| `401` | Bearer token missing or wrong on a `/mcp*` request | Check the Secret and the mount; `/healthz` is exempt from auth |

`OPENMESSAGES_ALLOWED_HOSTS` is a DNS-rebinding defence and defaults to `ingress.host`. The route is a bare `Host()` match with no header rewriting, so Traefik passes the original `Host` through unchanged -- do not add a middleware that rewrites it.

## Does the IP allowlist actually work?

Only if Traefik sees the real client address. It does in the IRL homelab, because Traefik runs with `hostNetwork: true` and a `ClusterIP` Service: connections land on the node's own socket with no kube-proxy DNAT/SNAT in front, so Traefik's `RemoteAddr` is the client. The middleware is left at its default `ipStrategy` (no `depth`, no `excludedIPs`), which means it uses `RemoteAddr` and ignores `X-Forwarded-For` -- a client cannot spoof its way in with a header.

**If Traefik is ever moved behind a LoadBalancer, a NodePort Service with `externalTrafficPolicy: Cluster`, or another reverse proxy, `RemoteAddr` stops being the client and this middleware silently allows everything that can reach Traefik.** Re-verify after any change to how Traefik is exposed.

## NetworkPolicy is additive

The chart ships three NetworkPolicies (ingress to `:7007` from the pod CIDR, DNS egress to CoreDNS, 443/tcp egress to public addresses only). Kubernetes NetworkPolicy has no deny primitive: a pod's effective permission is the **union** of every policy selecting it. In a namespace that already carries blanket allows -- the IRL `irl` namespace has `allow-intra-namespace`, `allow-ingress-tailscale` and `allow-egress-internet`, all with `podSelector: {}` -- these rules cannot subtract anything.

They are therefore defence-in-depth and documentation there, real enforcement in a namespace without blanket allows, and what survives if the namespace policies are ever tightened. What actually keeps this service off the open internet is the tailnet-only DNS name plus the `ipAllowList` middleware.

## Streaming

`/mcp` (streamable HTTP) and `/mcp/sse` produce long-lived responses. The IngressRoute sets `responseForwarding.flushInterval: -1` so Traefik forwards each write immediately instead of coalescing for up to its 100ms default. Traefik's entrypoint `respondingTimeouts.idleTimeout` applies to idle keep-alive connections, not to a request that is actively streaming, so the stock timeouts do not cut these off.

## Required values (no defaults, chart will not render)

| Value | Why there is no default |
|---|---|
| `image.digest` | Digest-only pinning; a mutable tag is not acceptable for the pod holding the Google pairing |
| `ingress.host` | Operator-specific; also becomes `OPENMESSAGES_ALLOWED_HOSTS` |
| `ingress.allowList.sourceRange` | Empty would silently publish the route to everything that can reach Traefik |
| `persistence.existingClaim` | This chart never provisions storage (outside `ci.ephemeral`) |
| `secret.existingSecret` | This chart never takes a token value; outside `ci.ephemeral` it never creates a Secret |

## CI (`ct install` on kind)

`ci/ci-values.yaml` sets `ci.ephemeral: true`: the data volume becomes an
`emptyDir`, the chart generates a random control token Secret, the
IngressRoute is off (kind has no Traefik CRDs), and `app.dataDir` is
`/data/store`. The daemon chmods its data dir to `0700` at startup, which
only the owner may do; kind's emptyDir root is owned by root, and a
subdirectory the daemon creates is its own. A production data volume must
likewise be owned by uid 1000, or the pod exits with
`secure data dir: chmod /data: operation not permitted`. The pod boots unpaired and
passes its `/healthz` probes, which is what CI proves. Never set
`ci.ephemeral` in a real deployment: data would not survive a restart and no
client would know the token.

## Other values that matter

| Value | Default | Note |
|---|---|---|
| `app.args` | `["serve", "--mcp-sse"]` | Entrypoint is the binary |
| `app.port` | `7007` | Also the Service port and the probe port |
| `app.allowedHosts` | `[]` | Empty = use `ingress.host` |
| `probes.startup` | 60 x 5s | 5-minute budget; the first sync after a cold start or a restore is slow |
| `terminationGracePeriodSeconds` | `30` | A Google RPC can hang on SIGTERM |
| `resources.limits` | 1 CPU / 1Gi | Deep backfill is bursty; a low CPU limit turns it into hours of throttling |
| `networkPolicy.ingressFrom` | pod CIDR `10.42.0.0/16` | The source address a hostNetwork Traefik uses via cni0 |

Security context is the hardened shape shared with `irl-gunio-mcp`: non-root uid/gid 1000, `readOnlyRootFilesystem: true`, `drop: [ALL]`, `RuntimeDefault` seccomp, `fsGroup: 1000` with `OnRootMismatch`, and an `emptyDir` for `/tmp`.

## Install

```bash
helm install openmessage charts/irl-openmessage -n irl \
  --set image.digest=sha256:... \
  --set ingress.host=openmessage.example.com \
  --set 'ingress.allowList.sourceRange={192.0.2.0/24}' \
  --set persistence.existingClaim=openmessage-data \
  --set secret.existingSecret=openmessage-secrets
```

In the IRL homelab it is deployed by Ansible instead (`ansible/playbooks/helm-deploy.yml`, tag `openmessage`, values in `ansible/helm/openmessage/values.yaml`); the PVC, the static PV and the ZFS dataset are created there, and the Secret comes from the Bitwarden -> `bw-sync.sh` lane. Operational procedures -- re-pairing, backup/restore of `/data`, token rotation -- live in that repo's `ansible/docs/runbooks/openmessage-down.md`.
