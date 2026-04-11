# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.10.1] - 2026-04-10

### Changed

- `irl-paperless` v0.1.1: Rename the public hostname from `docs.lab.infiniteroomlabs.cloud` to `archives.lab.infiniteroomlabs.cloud`. Updates the IngressRoute host plus all paperless `*_HOSTS` / `_URL` / `_TRUSTED_ORIGINS` env vars in the chart defaults so a fresh install lands on the right URL with no override needed.

### Fixed

- `irl-paperless` v0.1.1: Tika image default now points at `docker.io/apache/tika:latest`. The previous default `ghcr.io/paperless-ngx/tika:latest` returns 403 Forbidden -- that path is not a published image. Upstream paperless-ngx docker-compose uses the Apache Tika image directly.
- `irl-paperless` v0.1.1: Mark `PAPERLESS_REDIS` as `OVERRIDE-ME` in the chart default env block and document the bjw-s/common alphabetization issue inline. The previous default used `redis://:$(PAPERLESS_REDIS_PASSWORD)@valkey:6379/3` which silently fails because bjw-s/common renders env vars in alphabetical order, so `PAPERLESS_REDIS` is emitted before `PAPERLESS_REDIS_PASSWORD` and the k8s `$(VAR)` substitution leaves a literal `$(PAPERLESS_REDIS_PASSWORD)` in the URL. Operators must override this env var with the inline-rendered URL from a secrets values file (the IRL ansible playbook does this from `vault_redis_password`).

## [0.10.0] - 2026-04-10

### Added

- `irl-paperless` v0.1.0: New chart wrapping gabe565/paperless-ngx v0.24.1 (aliased to `paperless`). Connects to shared CNPG postgres + Valkey (DB index 3), Traefik IngressRoute at `docs.lab.infiniteroomlabs.cloud`, Authentik OIDC via django-allauth, UID 1000 alignment for NFS/ZFS consume folder, dedicated Tika + Gotenberg deployments for Office doc ingestion, and nightly `document_exporter` backup CronJob uploading to Garage S3 with remote retention prune.

## [0.9.0] - 2026-04-06

### Added

- `irl-monitoring` v0.3.0: Add Tempo v1.24.4 (traces backend, single-binary, 7d retention) and OpenTelemetry Collector v0.147.1 (OTLP receiver, fan-out to Tempo/Prometheus/Loki). Completes observability Phase 2.

### Fixed

- Release workflow: add open-telemetry Helm repo for irl-monitoring dependency resolution
- `irl-monitoring` v0.3.1: Set required `image.repository` for OTel Collector chart (otel/opentelemetry-collector-contrib)
- `irl-monitoring` v0.3.2: Replace removed `loki` exporter with `otlphttp/loki` (Loki native OTLP endpoint)

## [0.8.0] - 2026-04-06

### Changed

- `irl-openviking` v0.4.1: Switch VLM from Gemini 3.1 Pro Preview to Gemini 2.5 Flash (250/day -> 10,000/day rate limit)

### Added

- `irl-gitea` v0.2.0: Add Traefik IngressRoute (HTTP) and IngressRouteTCP (SSH) templates
- `irl-monitoring` v0.2.0: Add Traefik IngressRoutes for Grafana, Prometheus, Alertmanager
- `irl-garage` v0.2.0: Add Traefik IngressRoute for Garage Web UI
- `irl-openviking` v0.5.0: Add Traefik IngressRoute

### Removed

- `irl-caddy`: Chart removed (replaced by Traefik)

### Fixed

- Release workflow: add `skip_existing: true` to chart-releaser to handle unchanged chart versions gracefully

## [0.7.0] - 2026-04-04

### Changed

- `irl-openviking` v0.4.0: Switch embeddings from Ollama nomic-embed-text (768d) to Gemini gemini-embedding-001 (3072d) via litellm
- `irl-openviking` v0.4.0: Add `embeddingApiKey` secret injection for external embedding providers
- `irl-openviking` v0.4.0: Generalize startup secret injection to handle both VLM and embedding API keys
- `irl-openviking` v0.4.0: Fix embedding provider to use `openai` compat endpoint (litellm not supported for embeddings)

## [0.6.0] - 2026-04-04

### Changed

- `irl-openviking` v0.3.0: Switch VLM from Ollama smollm2 to Gemini 3.1 Pro Preview via litellm
- `irl-openviking` v0.3.0: Add `vlmApiKey` secret injection for external VLM providers

## [0.5.1] - 2026-04-04

### Changed

- `irl-openviking` v0.2.1: Revert Ollama endpoints from laptop Tailscale IP to in-cluster service (`ollama.irl.svc.cluster.local`)

### Fixed

- `irl-openviking`: template `max_concurrent` from values instead of hardcoding to 10

## [0.5.0] - 2026-03-27

### Added

- `irl-vaultwarden` v0.1.0: Vaultwarden (Bitwarden-compatible) password manager wrapper around guerzon/vaultwarden@0.35.1. External CNPG PostgreSQL, SendGrid SMTP relay, admin panel with token auth, ClusterIP service for Caddy ingress, 2Gi PVC for attachments/RSA keys.

### Fixed

- Release workflow: add guerzon Helm repo for irl-vaultwarden dependency resolution.
- `irl-vaultwarden`: move `existingSecret` from `smtp` to `smtp.password` block to match upstream chart schema.

## [0.4.0] - 2026-03-22

### Added

- `irl-garage` v0.1.0: Garage S3-compatible object storage with ZFS-backed data, SSD metadata, garage-webui sidecar (NLnet-funded), NodePort for Tailscale-only admin access. Replaces MinIO for Plane file storage.
- `irl-garage` v0.1.1: Fix configmap -- add required `root_domain` for s3_web, move `rpc_bind_addr` to top-level (Garage v1.3.1 config format).
- `irl-openviking` v0.1.0: OpenViking context database with Ollama embedding integration (nomic-embed-text), MCP sidecar for Claude Code, ZFS-backed persistence.
- `irl-openviking` v0.1.1: Fix config schema, root_api_key injection, disable MCP sidecar.
- `irl-openviking` v0.1.2: Switch API to NodePort 31933 for Caddy access at `context.internal.lab.infiniteroomlabs.cloud`.

## [0.3.0] - 2026-03-21

### Added

- `irl-gitea` v0.1.0: Gitea wrapper chart with external CNPG PostgreSQL + Valkey. Disables bundled Bitnami subcharts.
- `irl-monitoring` v0.1.0: Monitoring umbrella chart bundling kube-prometheus-stack + Loki SingleBinary.

## [0.2.0] - 2026-03-21

### Changed

- `irl-postgres` v0.2.0: Remove broken Job-based database creation. CNPG manages superuser credentials internally; databases are created via kubectl exec in the Ansible playbook. Bump CNPG dependency to 0.27.1.
- `irl-valkey` v0.2.0: Fix chart dependency version (0.3.18 -> 0.8.1) and rewrite values to match Valkey chart's actual API (ACL auth, valkeyConfig, dataStorage).

## [0.1.0] - 2026-03-20

### Added

- `irl-postgres` chart: CloudNativePG operator wrapper with Cluster CR, database provisioning Jobs, existingSecret auth. Replaces deprecated Bitnami postgresql chart.
- `irl-valkey` chart: Valkey (Redis-compatible) with auth defaults, tuning, Prometheus metrics. Replaces deprecated Bitnami redis chart.
- CI: chart-testing-action for PR lint/test, chart-releaser-action for GitHub Pages publishing.
- `ct.yaml` chart-testing configuration.
- `CLAUDE.md` with chart conventions and contribution guide.
