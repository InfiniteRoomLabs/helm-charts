# Helm Charts for Infinite Room Labs

## What This Is

Monorepo of Helm charts for the IRL homelab and platform. Each chart under `charts/` is independently versioned and released. Charts fill ecosystem gaps (Bitnami deprecation) or provide opinionated wrappers around upstream charts.

## Repository Structure

```
charts/
  irl-postgres/    # CloudNativePG operator + Cluster CR (replaces Bitnami postgresql)
  irl-valkey/      # Valkey with auth defaults (replaces Bitnami redis)
  irl-gitea/       # Gitea wrapper with external PG/Valkey + LFS
  irl-monitoring/  # Umbrella: kube-prometheus-stack + Loki
  irl-platform/    # Umbrella: entire homelab stack
```

## Chart Conventions

- Every chart has `Chart.yaml`, `values.yaml`, `templates/`, and `templates/_helpers.tpl`
- Version in `Chart.yaml` is the chart version. Bump it on every change.
- Use `existingSecret` pattern for all credentials -- no plaintext passwords in values.yaml
- Dependencies declared in `Chart.yaml`, resolved via `helm dependency update`
- `Chart.lock` is committed (reproducible builds)
- Labels follow `app.kubernetes.io/*` convention

## CI/CD

- PRs: `helm/chart-testing-action` lints and tests changed charts in a `kind` cluster
- Main merge: `helm/chart-releaser-action` packages charts and publishes to GitHub Pages

## Adding a Chart

```bash
helm repo add irl https://infiniteroomlabs.github.io/helm-charts/
```

## Releasing

1. Bump `version` in the chart's `Chart.yaml`
2. Push to `main` (or merge PR)
3. `chart-releaser-action` creates a GitHub Release and updates `index.yaml`
