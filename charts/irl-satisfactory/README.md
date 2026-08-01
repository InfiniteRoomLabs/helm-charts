# irl-satisfactory

Satisfactory dedicated server for the IRL homelab, wrapping [`wolveix/satisfactory-server`](https://github.com/wolveix/satisfactory-server).

## What this chart deploys

| Resource | Notes |
| --- | --- |
| Deployment (1 replica, `Recreate`) | Single process, single save. Not horizontally scalable. |
| Service (NodePort) | Game 30777 (TCP+UDP, same nodePort) + messaging 30888 (TCP) |

## Prerequisites (created outside this chart)

| Thing | Who creates it |
| --- | --- |
| PVC `satisfactory-data-pvc` (40Gi, `zfs-local`, bound to `pv-satisfactory-data`) | ansible (`helm-deploy.yml` / `k3s.yml`) |
| ZFS dataset owned by uid/gid 1000 | ansible (`zfs.yml`) |
| nftables allowlist entries: 30777 tcp+udp, 30888 tcp | ansible (`group_vars/homelab`) |

No secrets. The admin password is set in-game at claim time and lives on the PVC.

## Decisions worth knowing about

- **Container listens on the NodePort numbers directly** (`SERVERGAMEPORT=30777`, `SERVERMESSAGINGPORT=30888`). Satisfactory 1.1+ advertises the messaging port to clients through the game-port handshake, so the listen port must equal the reachable port. No translation anywhere = nothing to get wrong.
- **No CPU limit.** CFS throttling on a tick-based sim reads as stuttering belts. Requests + `irl.dev/tier: data` pinning instead.
- **`startupProbe` budgeted 30 minutes.** SteamCMD pulls ~10Gi on a cold volume; without this the pod CrashLoops forever.
- **Probes hit the messaging TCP port.** UDP probes are meaningless.
- **`fsGroupChangePolicy: OnRootMismatch`** avoids a recursive chown of 40Gi on every pod start.
- **`terminationGracePeriodSeconds: 120`** gives the shutdown autosave time to land.
- **Pin `image.tag`.** The game client auto-updates; a `latest` server restart after a game release can strand the save on a mismatched version.

## Sharp edges

- The server starts unclaimed -- claiming and setting the admin password is a one-time manual step in the game client (Server Manager).
- The Session Name is baked inside the `.sav`; renaming the file changes nothing.
- The in-game save uploader is flaky on very large saves; use `kubectl cp` into `/config/saved/server/` instead.
