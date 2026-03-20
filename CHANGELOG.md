# Changelog

## [0.1.0] - 2026-03-20

### Added

- `irl-postgres` chart: CloudNativePG operator wrapper with Cluster CR, database provisioning Jobs, existingSecret auth. Replaces deprecated Bitnami postgresql chart.
- `irl-valkey` chart: Valkey (Redis-compatible) with auth defaults, tuning, Prometheus metrics. Replaces deprecated Bitnami redis chart.
- CI: chart-testing-action for PR lint/test, chart-releaser-action for GitHub Pages publishing.
- `ct.yaml` chart-testing configuration.
- `CLAUDE.md` with chart conventions and contribution guide.
