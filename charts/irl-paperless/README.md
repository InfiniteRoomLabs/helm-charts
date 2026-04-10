# irl-paperless

Paperless-ngx deployment for the IRL homelab k3s cluster. Wraps [gabe565/paperless-ngx](https://github.com/gabe565/charts/tree/main/charts/paperless-ngx) and rewires it to match IRL conventions.

## What this chart does

- Declares `paperless-ngx` (gabe565) v0.24.1 as a dependency, aliased to `paperless`
- Disables the bundled Bitnami postgresql/mariadb/redis subcharts
- Connects to the cluster-level `postgresql-rw` CNPG service and `valkey` (DB index 3)
- Replaces upstream Ingress with a Traefik `IngressRoute` (our standard pattern)
- Adds a nightly `CronJob` that runs `document_exporter` and uploads the zip to Garage S3
- Wires Authentik OIDC via `django-allauth` and the `PAPERLESS_SOCIALACCOUNT_PROVIDERS` env var
- Aligns UID/GID 1000 across the pod, ZFS dataset, and NFS export (the highest-risk integration point)

## Prerequisites

Before `helm install`, the following must exist in the `irl` namespace:

| Kind | Name | Populated by |
|---|---|---|
| Secret | `postgres-paperless` | `scripts/bw-sync.sh --target kubernetes` |
| Secret | `paperless-secrets` | `scripts/bw-sync.sh --target kubernetes` |
| Secret | `paperless-backup-s3` | `scripts/bw-sync.sh --target kubernetes` |
| Secret | `redis-auth` | existing (shared valkey auth) |
| PVC | `paperless-data-pvc`, `paperless-media-pvc`, `paperless-consume-pvc`, `paperless-export-pvc` | `ansible/playbooks/k3s.yml --tags paperless` |
| Postgres DB + role | `paperless` | Phase 2 `helm-deploy.yml --tags postgres` (reads `irl_pg_databases`) |
| ZFS datasets | `paperless-consume`, `paperless-media`, `paperless-data` (all chowned to 1000:1000) | `ansible/playbooks/zfs.yml --tags paperless` |

## Secret shape

```
postgres-paperless:
  password: <generated>

paperless-secrets:
  secret-key: <generated, 50 chars>
  admin-password: <generated>
  PAPERLESS_SOCIALACCOUNT_PROVIDERS: |
    {"openid_connect":{"APPS":[{"provider_id":"authentik","name":"Authentik SSO",...}],"OAUTH_PKCE_ENABLED":true}}

paperless-backup-s3:
  AWS_ACCESS_KEY_ID: <garage access key>
  AWS_SECRET_ACCESS_KEY: <garage secret key>
```

## Local development

```bash
cd helm-charts/charts/irl-paperless
helm dependency update
helm lint .
helm template . --debug > /tmp/rendered.yaml
```

## Known caveats

1. **Scanbridge non-atomic writes** -- `PAPERLESS_CONSUMER_POLLING` is set to 30s with 5 retries (~2.5 min stability window). If big multipage scans exceed that, either increase `PAPERLESS_CONSUMER_POLLING_RETRY_COUNT` or patch scanbridge upstream to rename-on-complete.
2. **UID 1000 alignment** -- must be consistent across pod securityContext, ZFS dataset ownership, and NFS export (`all_squash,anonuid=1000,anongid=1000`). Any mismatch silently breaks the consume pipeline.
3. **NodePort 30800** -- verify free before deploy: `kubectl get svc -A -o jsonpath='{range .items[*]}{.spec.ports[*].nodePort}{"\n"}{end}' | sort -u`
4. **PAPERLESS_DISABLE_REGULAR_LOGIN** -- ships as `false` to allow bootstrap via local admin. Flip to `true` after SSO is verified end-to-end, then redeploy.
5. **Garage lifecycle** -- retention is handled by the backup CronJob itself (S3 delete pass after upload), not by Garage lifecycle rules, since Garage's lifecycle support varies by version.

## Source

Forked from [gabe565/charts/paperless-ngx @ v0.24.1](https://github.com/gabe565/charts/tree/main/charts/paperless-ngx). Upstream sync should be done quarterly; with the wrapper pattern, only `Chart.yaml`'s dependency version needs bumping.
