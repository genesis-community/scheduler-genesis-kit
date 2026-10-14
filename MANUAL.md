# OCF Scheduler Genesis Kit Manual

This manual provides detailed instructions for deploying and managing the OCF Scheduler service using Genesis.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Deployment](#deployment)
  - [Prerequisites](#prerequisites)
  - [Creating a New Environment](#creating-a-new-environment)
  - [Deployment Parameters](#deployment-parameters)
  - [Deployment Examples](#deployment-examples)
- [Ubuntu Resolute Stemcells](#ubuntu-resolute-stemcells)
- [Post-Deployment Setup](#post-deployment-setup)
  - [Setting Up the CF CLI Plugin](#setting-up-the-cf-cli-plugin)
  - [Using the Scheduler from Cloud Foundry](#using-the-scheduler-from-cloud-foundry)
  - [Registering the Service Broker](#registering-the-service-broker)
  - [Running Smoke Tests](#running-smoke-tests)
- [Using the Scheduler Service](#using-the-scheduler-service)
  - [Scheduling Jobs](#scheduling-jobs)
  - [Managing Scheduled Jobs](#managing-scheduled-jobs)
- [Advanced Configuration](#advanced-configuration)
  - [Database Configuration](#database-configuration)
  - [Security Settings](#security-settings)
  - [Worker Scaling](#worker-scaling)
- [Upgrades and Maintenance](#upgrades-and-maintenance)
- [Troubleshooting](#troubleshooting)

## Overview

The OCF Scheduler provides a job scheduling service for Cloud Foundry applications. It allows applications to schedule tasks to run at specific times using cron syntax, providing a reliable way to execute background tasks without maintaining a dedicated worker application.

## Architecture

The OCF Scheduler consists of the following components:

1. **Scheduler API**: Processes scheduler service API requests, exposed through Cloud Foundry routes
2. **Worker Pool**: Executes scheduled jobs based on their defined schedules
3. **Database**: Stores job definitions, schedules, and execution history

## Deployment

### Prerequisites

Before deploying the OCF Scheduler service, ensure you have:

- A functional BOSH director
- A Genesis-deployed Cloud Foundry environment
- Sufficient IaaS resources
- A vault server for credentials
- Genesis v3.1.0 or later

### Creating a New Environment

1. **Create a deployment repository**:
   ```bash
   genesis init --kit ocf-scheduler
   cd ocf-scheduler-deployments
   ```

2. **Define the environment**:
   ```bash
   genesis new myenv
   ```
   During this process, you'll be prompted for required parameters.

3. **Deploy the environment**:
   ```bash
   genesis deploy myenv
   ```

### Deployment Parameters

The OCF Scheduler Genesis Kit supports the following parameters:

#### Required Parameters

- `cf_deployment_env`: Name of your Cloud Foundry deployment environment (defaults to the scheduler environment name)
- `cf_deployment_type`: Type of your Cloud Foundry deployment (defaults to "cf")

#### Cloud Config Parameters

- `vm_type`: VM type for the scheduler instance (default: "default")
- `disk_type`: Disk type for the scheduler instance (default: "default")
- `network`: Network to use for deployment (default: "default")
- `availability_zones`: BOSH availability zones to use (default: "z1")
- `stemcell_os`: Stemcell operating system (default: "ubuntu-noble")
- `stemcell_version`: Stemcell version (default: "latest")

#### Scheduler Configuration

- `worker_count`: Number of scheduler workers (default: 10)
- `log_level`: Logging level (default: "info", options: "debug", "info", "warn", "error")

#### External PostgreSQL Parameters

When using the `external-postgres` feature:

- `pg_scheme`: Database connection scheme (default: "postgres://")
- `pg_username`: Database username
- `pg_password`: Database password
- `pg_hostname`: Database hostname or IP
- `pg_port`: Database port (default: "5432")
- `pg_sslmode`: SSL mode for the connection (default: "disable")
- `pg_database`: Database name (default: "scheduler")

### Deployment Examples

#### Basic Deployment with Internal PostgreSQL

```yaml
---
# myenv.yml
kit:
  name: ocf-scheduler
  version: latest

params:
  worker_count: 20
  log_level: info
```

#### Deployment with External PostgreSQL

```yaml
---
# myenv.yml
kit:
  name: ocf-scheduler
  version: latest

features:
  - external-postgres

params:
  worker_count: 20
  log_level: info
  pg_hostname: my-postgres-server.example.com
  pg_port: 5432
  pg_username: scheduler
  pg_password: secure-password
  pg_database: scheduler
```

#### Deployment with External PostgreSQL from Vault

```yaml
---
# myenv.yml
kit:
  name: ocf-scheduler
  version: latest

features:
  - external-postgres-vault

params:
  worker_count: 20
  log_level: info
```

Make sure to set up your vault accordingly:

```bash
safe set secret/myenv/ocf-scheduler/db \
  hostname="my-postgres-server.example.com" \
  port="5432" \
  username="scheduler" \
  password="secure-password" \
  scheme="postgres://" \
  sslmode="disable" \
  database="scheduler"
```

## Ubuntu Resolute Stemcells

The kit deploys the scheduler on ubuntu-noble stemcells unless we ask for something else. Adding the `resolute` feature moves the scheduler instance group and its errand onto ubuntu-resolute.

```yaml
kit:
  features:
  - resolute

params:
  stemcell_version: "0.184"
```

The feature is experimental, so we recommend trying it on a canary scheduler before we point anything real at it. It sets the stemcell `os` to `ubuntu-resolute`, and `stemcell_version` still selects the version, which defaults to `latest`. We pin it to a resolute version such as `"0.184"` so that the environment stays on a known build when a newer stemcell is uploaded. The feature works the same with or without `ocfp`. Because the feature owns the stemcell os, an environment that sets `params.stemcell_os` to anything else is refused, and so is an environment that sets it to `ubuntu-resolute` without the feature.

Resolute ships without runit, so the `chpst` command is missing. The ocf-scheduler release calls `chpst` in `jobs/scheduler/templates/bin/ctl.erb`, which is a plain control script that does not run under bpm, and that means the scheduler job cannot start on resolute. Release 2.0.0, the version this kit pinned before 2.1.1, has the problem, and so does every release before it.

For that reason the feature pins ocf-scheduler 2.3.2, which no longer calls `chpst`, in place of the default pin. The pin applies only when the feature is on, so noble deployments keep the default release 2.1.1. The director must be able to fetch release 2.3.2 from its release URL, or already hold it, before we deploy.

The bpm release is the second change. This kit pins bpm 1.4.26, and bpm releases older than 1.4.41 bundle a tini package that fails to compile on resolute. Under the feature the kit pins bpm 1.4.41 instead, and only when the route registrar is part of the deployment, because that is the one place the manifest carries the bpm release. The bosh-dns-aliases release, version 0.0.4, needs no change.

When the kit deploys its internal PostgreSQL, the feature also pins postgres-release 57.0.0 with `databases.version` set to 16, because release 51 does not build on resolute and release 57 would otherwise default to PostgreSQL 18, so pinning 16 keeps the existing data directory on its current major version.

Before the first deploy we need to do two things on the director.

- Upload the resolute stemcell to the director that deploys the scheduler, since both the compilation VMs and the instances need it.

- Make sure the director's runtime config carries bosh-dns 1.39.31 or later. Earlier bosh-dns releases do not run on resolute.

With `ocfp`, Genesis derives the vault path for the OCFP configuration from the environment name. An environment named `ocfp-lab-wayneeseguin-ocf` reads its configuration from `config/ocfp-lab-wayneeseguin/ocf`, so the name has to end in `-ocf` or `-mgmt` to land on the right path.

### Postgres collation after the stemcell move

Moving from ubuntu-noble to ubuntu-resolute takes glibc from 2.39 to 2.43, and a postgres server that keeps its data directory notices the change. Each database records the collation version it was created with, so after the move the postgres log fills with warnings such as `database "scheduler" has a collation version mismatch`. Text indexes built under the old glibc may order strings differently under the new one, so we rebuild them once and then record the new version. We only need this when an existing deployment moves from noble to resolute with its data kept. A deployment built new on resolute has no mismatch.

We run the fix once for every database on the server, including `postgres` and `template1`, which hold no application data but warn all the same. The kit's database is `scheduler`. Open a shell on the `scheduler` instance with `bosh ssh`.

```
bosh -d <deployment> ssh scheduler
```

Then become root with `sudo -i` and run the following. The server trusts the `vcap` user over the loopback address, so no password is needed. If the binary path differs, `ls -d /var/vcap/packages/postgres-*` shows the right one.

```
PSQL="sudo -u vcap /var/vcap/packages/postgres-16/bin/psql -h 127.0.0.1 -p 5432 -U vcap -X"
for db in scheduler postgres template1; do
  $PSQL -v ON_ERROR_STOP=1 -d $db -c "REINDEX DATABASE \"$db\";"
  $PSQL -v ON_ERROR_STOP=1 -d $db -c "ALTER DATABASE \"$db\" REFRESH COLLATION VERSION;"
done
```

Both statements print the mismatch warning themselves until the refresh completes, which is expected. The reindex is not concurrent and holds locks while it runs, but it is brief on a database of this size. We can confirm the result by comparing the two versions, and every row should show 2.43 on both sides.

```
$PSQL -d postgres -c "select datname, datcollversion, pg_database_collation_actual_version(oid) as actual from pg_database where datname<>'template0' order by 1"
```

Nothing needs a restart or a redeploy.

## Post-Deployment Setup

After deploying the scheduler, you need to complete these steps to make it fully operational.

### Setting Up the CF CLI Plugin

The OCF Scheduler provides a CF CLI plugin for managing scheduled jobs. Install it with:

```bash
genesis do myenv setup-cf-plugin
```

Add the `-f` flag to force installation over an existing version:

```bash
genesis do myenv setup-cf-plugin -f
```

### Using the Scheduler from Cloud Foundry

Apps use the scheduler through the OCF Scheduler plugin for the cf CLI, which we install with `genesis do myenv setup-cf-plugin` as described above. The plugin commands authenticate with your own Cloud Foundry token. A deployment without the `service-broker` feature needs no service instance or service binding, and the scheduler does not appear in `cf marketplace`. To offer the scheduler as a marketplace service, we turn on the `service-broker` feature, as described in the next section.

Release 2.1.1 limits each caller to their own spaces. A caller without `cloud_controller.admin` needs the space developer role in the space of the app, job, or call they name. The scheduler answers 403 when someone lists or creates in another space, and 404 when they name another tenant's job, call, or schedule. It still stores a call's `auth_header` and sends it when the call runs, but no response ever returns it. The default pin is 2.1.1, and the resolute and service-broker features pin 2.2.0, which keeps the same checks.

The following example creates a job for an app, runs it once, and schedules it to run every day at 2 AM.

```bash
# Create a job that runs a command in the app's environment
cf create-job my-app my-job-name "rake db:migrate"

# Run the job once, immediately
cf run-job my-job-name

# Schedule the job with a cron expression (every day at 2 AM)
cf schedule-job my-job-name "0 2 * * *"
```

Apps can also call an HTTP endpoint, such as an app route, on a schedule. We create the call with `cf create-call APP-NAME CALL-NAME URL` and schedule it with `cf schedule-call CALL-NAME SCHEDULE`.

### Registering the Service Broker

Release 2.2.0 and later can speak the Open Service Broker API, so we can register the scheduler with Cloud Foundry and let developers create a service instance and bind their apps to it. The broker is off unless we add the `service-broker` feature to the environment. The feature also needs `cf-route-registrar` or `ocfp`, because Cloud Controller reaches the broker through the scheduler route, and the check hook refuses the feature without one of them. The feature also pins ocf-scheduler 2.2.0 in place of the default pin, so the director must be able to fetch that release from its release URL, or already hold it, before we deploy.

When the feature is on, the kit generates the broker password in vault and gives the scheduler the broker username, the password, and the scheduler URL. It also publishes `broker_url`, `broker_username`, and `broker_password` in the scheduler's exodus data, which is where the `bind-scheduler` addon reads them. A service instance turns the scheduler on for one space, and each space can hold only one instance. A binding gives one app permission to be scheduled, and it returns the scheduler URL without any secret, because developers still authenticate to the scheduler with their own tokens.

The feature also turns on `require_binding`. An app that has no binding cannot create jobs or calls, and the scheduler answers 403 with `binding_required`. Reading, running, and deleting what already exists stays open, and an admin is never blocked. Every space check from release 2.1.1 still runs first, so the binding requirement adds to those checks and never replaces them.

```yaml
kit:
  features:
  - ocfp
  - service-broker

params:
  broker_orgs:
  - poc
```

After we deploy, we register the broker with the addon.

```bash
genesis do myenv bind-scheduler
```

The addon logs in to Cloud Foundry with the admin credentials from the CF exodus data, then creates the broker, or updates it when it already exists. It passes the broker password through the environment and never on a command line. It then enables the service only for the orgs in `params.broker_orgs`, and it never enables the service for every org. With no orgs listed, it registers the broker, enables nothing, and tells us how to add orgs. We can name orgs on the command line with `-o ORG`, which replaces the list for that run, and we can add `--prune` to disable access for any org that is no longer listed.

```bash
genesis do myenv bind-scheduler -o poc -o sandbox --prune
```

A developer in an enabled org then creates the instance and binds the app.

```bash
cf create-service scheduler standard my-scheduler
cf bind-service my-app my-scheduler
```

Unbinding pauses the app's schedules and deletes nothing, so its jobs, calls, and history all stay in place. A schedule that its owner had already disabled stays disabled. Binding the app again resumes only the schedules that the unbind paused. Deleting the service instance removes the instance record and leaves the paused jobs where they are.

### Running Smoke Tests

Verify your deployment with the built-in smoke tests:

```bash
genesis do myenv smoke-tests
```

This runs the `smoke-tests` errand, which logs in with the CF admin credentials from the environment. The errand creates a temporary space named `scheduler-smoke-tests-` followed by a timestamp, installs the scheduler plugin, and runs the acceptance tests in that space. The tests push a small test app and exercise the job and call commands, such as `create-job`, `schedule-job`, `run-job`, and `delete-job`. The errand deletes the space after the tests pass.

## Using the Scheduler Service

### Scheduling Jobs

Schedule jobs to run at specific times using cron expressions. The plugin takes the job name first and the cron expression second, and it accepts an optional `--timezone` flag:

```bash
# Schedule a job that was created with cf create-job
cf schedule-job my-job-name "0 * * * *"

# Interpret the cron expression in a named timezone
cf schedule-job --timezone Europe/Berlin my-job-name "0 9 * * 1-5"
```

Cron expression format:
```
┌─────────── minute (0-59)
│ ┌───────── hour (0-23)
│ │ ┌─────── day of month (1-31)
│ │ │ ┌───── month (1-12)
│ │ │ │ ┌─── day of week (0-6) (Sunday to Saturday)
│ │ │ │ │
* * * * *
```

Examples:
- `*/15 * * * *`: Every 15 minutes
- `0 * * * *`: Every hour at minute 0
- `0 0 * * *`: Every day at midnight
- `0 12 * * 1-5`: Every weekday at noon

### Managing Scheduled Jobs

List the jobs in the current space:

```bash
cf jobs
```

List the job schedules in the current space:

```bash
cf job-schedules
```

View the execution history for a job:

```bash
cf job-history my-job-name
```

Delete a schedule with its GUID:

```bash
cf delete-job-schedule my-job-name schedule-guid
```

Delete a job:

```bash
cf delete-job my-job-name
```

Run a job immediately:

```bash
cf run-job my-job-name
```

## Advanced Configuration

### Database Configuration

The OCF Scheduler requires a PostgreSQL database. You can use either:

1. **Internal PostgreSQL** (default):
   - Colocated on the scheduler VM
   - Suitable for development/testing
   - Limited by VM resources

2. **External PostgreSQL** (recommended for production):
   - More scalable and reliable
   - Can be configured via environment parameters or vault
   - Supports high availability configurations

### Security Settings

The service integrates with UAA for authentication and authorization. It uses an existing UAA client, `app_scheduler_client`, whose ID and secret come from the CF environment's exodus data. The Cloud Foundry kit defines that client with the `cloud_controller.read`, `cloud_controller.admin`, and `uaa.resource` authorities, so this kit does not create it.

### Worker Scaling

The number of workers determines how many concurrent scheduled jobs can be executed. Scale based on your expected workload:

- Light workload: 5-10 workers
- Medium workload: 10-20 workers
- Heavy workload: 20+ workers

Adjust using the `worker_count` parameter:

```yaml
params:
  worker_count: 30
```

## Upgrades and Maintenance

### Upgrading the Scheduler

To upgrade to a newer version:

1. Update your deployment repository:
   ```bash
   cd ocf-scheduler-deployments
   git pull
   ```

2. Update the kit version in your environment file:
   ```yaml
   kit:
     name: ocf-scheduler
     version: x.y.z
   ```

3. Deploy the update:
   ```bash
   genesis deploy myenv
   ```

### Monitoring

Monitor the scheduler service by:

- Checking BOSH VM health: `bosh -d myenv-ocf-scheduler instances --vitals`
- Viewing logs: `bosh -d myenv-ocf-scheduler logs scheduler`
- Monitoring job execution history via the CF CLI plugin
- Integrating with your monitoring system via the `/health` endpoint

## Troubleshooting

Common issues and their solutions:

### Scheduled Jobs Not Running

**Symptoms**: Jobs are scheduled but not executing.

**Solutions**:
- Check the scheduler logs: `bosh -d myenv-ocf-scheduler logs scheduler`
- Verify worker count is sufficient for your workload
- Ensure the app targeted by the job exists and is running
- Check that the task exists in the app manifest or is specified with `--command`

### Database Connection Issues

**Symptoms**: Scheduler fails to start or connect to the database.

**Solutions**:
- For external database: Verify connection details and network connectivity
- For internal database: Check disk space and VM health
- Examine logs for specific database connection errors

### CF CLI Plugin Issues

**Symptoms**: The CF CLI plugin fails to install or use.

**Solutions**:
- Verify CF CLI version compatibility (v7+ recommended)
- Check for plugin conflicts: `cf plugins`
- Reinstall the plugin with force flag: `genesis do myenv setup-cf-plugin -f`