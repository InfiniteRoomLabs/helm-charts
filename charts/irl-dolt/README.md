# irl-dolt

One [Dolt](https://github.com/dolthub/dolt) SQL server per Helm release. Dolt is a MySQL-compatible database with Git-style version control (branches, commits, diffs, merges) built into the storage engine.

The chart is meant to be installed many times: one release per instance, the way you would create one managed database instance per consumer. Each instance gets its own volume, credentials, declared databases and users, nightly backups, metrics and alerts.

```sh
helm repo add irl https://infiniteroomlabs.github.io/helm-charts/
helm install orders irl/irl-dolt -f orders.yaml
helm test orders
```

```yaml
# orders.yaml
databases:
  - name: orders
users:
  - name: orders_app
    grants:
      - "ALL PRIVILEGES ON `orders`.*"
backup:
  enabled: true
```

Clients connect to `orders-irl-dolt.<namespace>.svc:3306` with any MySQL client or driver. Set `fullnameOverride` for a shorter name.

## What you get

| Managed-database feature | Here |
|---|---|
| Instance | StatefulSet, 1 replica, unprivileged uid, read-only root filesystem |
| Parameter group | `config`, rendered into the server's `config.yaml`; a change rolls the pod |
| Master credentials | `auth.existingSecret`, or a generated Secret that stays stable across upgrades |
| Databases and users | `databases[]` and `users[]`, applied by a Job after every install and upgrade |
| Password rotation (users) | Change the Secret, run `helm upgrade` |
| Automated backups | CronJob calling `DOLT_BACKUP('sync-url')` for every database: online and incremental |
| Restore, clone | `databases[].restoreFrom`, optionally from another instance's backup volume |
| Point-in-time recovery | Dolt itself: every commit is addressable (`AS OF`, `dolt_reset`, branches) |
| Endpoint | ClusterIP Service, optional NodePort Service |
| Monitoring | `/metrics`, optional ServiceMonitor and PrometheusRule |
| Network isolation | NetworkPolicies for the server pod |
| Deletion protection | The generated Secret and the chart-created backup claim carry `helm.sh/resource-policy: keep` |

Not included: replicas, automatic failover, TLS on the SQL port. See "Why no replication" below.

## How provisioning behaves

The Job is additive. Listed databases are created if missing. Listed users are created if missing, and their password and grants are re-applied every time. Removing an entry from the values does **not** drop the database, the user or the grant. Drop things over SQL, on purpose.

The Job is a Helm hook (`post-install,post-upgrade`). If it fails, the release fails, and `kubectl logs job/<fullname>-provision` says which statement was refused. The finished Job is kept for a day so the log stays readable.

Database and user names are restricted to letters, digits and underscore; anything else fails the render. Passwords may contain any character except a newline.

## Credentials

With `auth.existingSecret` empty the chart creates `<fullname>-credentials` with a random 40-character password under `auth.rootPasswordKey` and under each user's `passwordKey` (default `<name>-password`). Existing keys are read back on every upgrade and never re-rolled; new users get new keys. The Secret survives `helm uninstall`.

With `auth.existingSecret` set, that Secret must carry the same keys. A missing key keeps the pod that needs it from starting (`CreateContainerConfigError`, and the event names the key), which fails the release instead of leaving a user without a password.

### Rotating a user password

Change the key in the Secret, then `helm upgrade`. The Job runs `ALTER USER ... IDENTIFIED BY` with the new value.

### Rotating the root password

The server reads `DOLT_ROOT_PASSWORD` only on first boot, while the volume has no privileges database. Later the Secret and the server must be changed together, server first:

```sh
# 1. Change it inside Dolt. In the pod, `dolt sql` is a local superuser
#    session and needs no password.
kubectl exec -it <fullname>-0 -- dolt sql -q "ALTER USER 'root'@'%' IDENTIFIED BY '<new>'"
# 2. Put the same value in the Secret.
# 3. Restart the pod so its probes pick up the new value.
kubectl rollout restart statefulset/<fullname>
```

Doing step 2 first leaves the probes, the provisioning Job and the backup CronJob with a password the server does not accept. The fix is the same three steps.

## Backups and restore

With `backup.enabled` the server pod mounts a backup volume at `/backups` and a CronJob asks the server to sync every database to `backup.urlTemplate` (default `file:///backups/{database}`). All user databases are included, also ones created over SQL and not declared in the values.

The backup job runs as root and builds a SQL statement and a path from each database name, so it only handles names made of letters, digits, underscore and hyphen. A database with any other name is skipped and the Job fails, so the gap is visible instead of silent.

A Dolt backup contains the full history of every branch plus uncommitted working changes. It is a single copy, updated in place: the backup volume always holds the state as of the last run. Keep older states by snapshotting that volume, or simply use Dolt history, which a backup preserves.

Restore into the same instance under a new name:

```yaml
databases:
  - name: orders_restored
    restoreFrom: "file:///backups/orders"
```

Restore into a different instance (clone, restore drill, migration) by mounting the source instance's backup claim read-only:

```yaml
restore:
  existingClaim: orders-irl-dolt-backup
databases:
  - name: orders
    restoreFrom: "file:///restore/orders"
```

`restoreFrom` is only used when the database does not exist. To restore over an existing database, drop or rename it first.

Users and grants are not part of a database backup. They are recreated from `users[]`.

`backup.urlTemplate` is passed to Dolt unchanged, so the other schemes Dolt documents (`aws://`, `gs://`, `s3://` with an endpoint) are available in principle: pass credentials through `extraEnv` / `extraEnvFrom` and open `networkPolicy.egressInternet` if the target is public. Only `file://` has been tested with this chart.

## Storage

- `persistence.existingClaim` empty: the StatefulSet gets a volumeClaimTemplate (`persistence.storageClass`, `persistence.size`).
- `persistence.existingClaim` set: that claim is used as is. For hostPath-backed static volumes, `fsGroup` has no effect, so the directory must be owned by the pod uid (1000 by default) before the first start.

The same applies to `backup.persistence`.

Dolt's storage is append-only. Automatic garbage collection is on by default (`config.behavior.auto_gc_behavior`) and keeps the volume from growing without bound.

## Upgrading Dolt

Set `image.tag` (or take a chart version with a newer `appVersion`) and upgrade. Dolt reads data written by older versions. The reverse is not guaranteed: once a newer version has written, an older binary may refuse the database. Take a backup first and treat a downgrade as a restore.

## Network access

The NetworkPolicies select the server pod only:

- SQL (3306) from `networkPolicy.ingressFrom` (default: any pod in the namespace) and from `networkPolicy.externalCidrs`.
- Metrics from `networkPolicy.metricsFrom`.
- Egress: DNS, plus public HTTPS when `networkPolicy.egressInternet.enabled`.

NetworkPolicy is additive. In a namespace that already allows everything, these rules restrict nothing.

`service.external` adds a NodePort Service for clients outside the cluster. NodePort traffic keeps its source address, so list the client ranges in `networkPolicy.externalCidrs`. The SQL port is not encrypted by this chart; expose it only on a network you trust (a VPN or overlay network) or configure `config.listener.tls_cert` / `tls_key` yourself.

## Why no replication

Dolt supports primary/standby replication, and DoltHub publishes an operator for it ([dolthub/doltdb-operator](https://github.com/dolthub/doltdb-operator)). This chart does not use either:

- It was written for a single-node cluster, where a standby shares the primary's failure domain and buys nothing but complexity.
- Failover needs a controller that picks and promotes a standby. A Helm chart is not one.
- At the time of writing (2026-11) the operator is `v0.0.2` with a `v1alpha` API. It has no container-level security context, no way to bind a pre-existing claim, a server config limited to a handful of keys, and backups that target AWS only.

If you need failover, use the operator. The `databases` / `users` / `backup` shape here maps closely onto its `Database`, `User`, `Grant` and `BackupSchedule` resources.

## Values

See [`values.yaml`](values.yaml); every key is documented there.
