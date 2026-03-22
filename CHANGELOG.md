# Changelog

## [0.4.0] - 2026-03-22

### Added

- `irl-garage` v0.1.0: Garage S3-compatible object storage with ZFS-backed data, SSD metadata, garage-webui sidecar (NLnet-funded), NodePort for Tailscale-only admin access. Replaces MinIO for Plane file storage.
- `irl-garage` v0.1.1: Fix configmap -- add required `root_domain` for s3_web, move `rpc_bind_addr` to top-level (Garage v1.3.1 config format).
- `irl-openviking` v0.1.0: OpenViking context database with Ollama embedding integration (nomic-embed-text), MCP sidecar for Claude Code, ZFS-backed persistence.
- `irl-openviking` v0.1.1: Fix config schema -- move max_concurrent to embedding level, rename logging to log, use ollama provider. Fix root_api_key injection via runtime config merge.

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
