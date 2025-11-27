# OCF Scheduler Genesis Kit

This kit allows you to deploy the OCF Scheduler service for Cloud Foundry, which enables applications to schedule tasks to run at specified times.

## Features

- **Scheduler Service**: Deploys the OCF Scheduler API and configurable number of workers
- **Database Options**: 
  - Internal PostgreSQL database (default, colocated)
  - External PostgreSQL database (configurable via parameters or vault)
- **CF Integration**: 
  - Automatic route registration with your Cloud Foundry deployment
  - Service broker for application integration
- **Operations**: 
  - Smoke tests to verify deployment functionality
  - CF CLI plugin setup for direct interaction with the scheduler

## Prerequisites

- A running Cloud Foundry deployment created with Genesis
- Vault for credential management
- BOSH director with sufficient resources
- Genesis v3.1.0 or later

## Quick Start

### Create a New Deployment Repository

```bash
# create a scheduler-deployments repo using the latest version of the scheduler kit
genesis init --kit ocf-scheduler

# OR specify a specific version
genesis init --kit ocf-scheduler/1.0.0
```

### Create a New Environment

```bash
# Create a new environment file
cd scheduler-deployments
genesis new myenv
```

### Deploy the Environment

```bash
# Deploy your environment
genesis deploy myenv
```

## Post-Deployment Setup

After deploying the scheduler, you'll need to:

1. **Install CF CLI Scheduler Plugin**:
   ```bash
   genesis do myenv setup-cf-plugin [-f]
   ```
   This adds the OCF scheduler plugin to your CF CLI.

2. ~~**Register and Configure Service Broker**~~ (Not Yet Implemented):
   > **⚠️ Note**: The `bind-scheduler` addon is currently disabled. The upstream OCF Scheduler application does not implement the Cloud Foundry Service Broker API. Use the scheduler directly via the CF CLI plugin commands instead.

3. **Verify Deployment with Smoke Tests**:
   ```bash
   genesis do myenv smoke-tests
   ```
   This runs tests to verify that the scheduler is working properly.

## Using the Scheduler Service

After setting up the CLI plugin, you can schedule jobs directly:

1. **Create a job**:
   ```bash
   cf create-job my-app my-job-name "rake db:migrate"
   ```

2. **Schedule the job with a cron expression**:
   ```bash
   cf schedule-job my-job-name "0 2 * * *"  # Run daily at 2 AM
   ```

3. **List all jobs**:
   ```bash
   cf jobs
   ```

4. **View job schedules**:
   ```bash
   cf job-schedules
   ```

5. **Run a job immediately**:
   ```bash
   cf run-job my-job-name
   ```

6. **View job execution history**:
   ```bash
   cf job-history my-job-name
   ```

For more detailed usage instructions, please see the [MANUAL.md](MANUAL.md) file.

## Available Features

### `external-postgres` and `external-postgres-vault`

By default, an internal (colocated) PostgreSQL database is deployed. You can configure an external PostgreSQL database in two ways:

#### Using the `external-postgres-vault` feature:

Add credentials to vault:
```bash
safe set secret/myenv/ocf-scheduler/db \
  hostname="my-database-host.example.com" \
  port="5432" \
  username="scheduler" \
  password="superSecretPassword" \
  scheme="postgres://" \
  sslmode="disable" \
  database="scheduler"
```

#### Using the `external-postgres` feature:

Add the following to your environment file:
```yaml
params:
  pg_scheme:   "postgres://"
  pg_username: "scheduler"
  pg_password: "superSecretPassword"
  pg_hostname: "my-database-host.example.com"
  pg_port:     "5432"
  pg_sslmode:  "disable"
  pg_database: "scheduler"
```

### `cf-route-registrar`

By enabling the `cf-route-registrar` feature, the kit will extract CF deployment information required to register the scheduler API with CF at `scheduler.<cf_system_domain>`.

## Configuration Parameters

### Worker Count

The number of workers defaults to 10 and can be set using the `worker_count` param:
```yaml
params:
  worker_count: 40
```

### Log Level

The log level defaults to `info` and can be set using the `log_level` param:
```yaml
params:
  log_level: debug
```

### Cloud Config Requirements

The scheduler service is golang-based and requires:
- Sufficient CPU resources (recommended: 2 dedicated cores)
- If using internal postgres (default), allocate additional resources for PostgreSQL
- Default VM and disk types can be overridden using the following parameters:

```yaml
params:
  vm_type: "medium"
  disk_type: "medium"
  network: "cf-services"
  availability_zones: ["z1", "z2"]
```

## More Information

For more detailed information, please refer to:
- [MANUAL.md](MANUAL.md) - Detailed usage instructions
- [docs/](docs/) - Additional documentation for specific features
- [Official OCF Scheduler Documentation](https://github.com/cloudfoundry-community/scheduler-boshrelease)

## Troubleshooting

For troubleshooting common issues, see the [Troubleshooting Guide](docs/troubleshooting.md).