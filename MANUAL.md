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
- [Post-Deployment Setup](#post-deployment-setup)
  - [Setting Up the CF CLI Plugin](#setting-up-the-cf-cli-plugin)
  - [Binding the Scheduler Service Broker](#binding-the-scheduler-service-broker)
  - [Running Smoke Tests](#running-smoke-tests)
- [Using the Scheduler Service](#using-the-scheduler-service)
  - [Creating Service Instances](#creating-service-instances)
  - [Managing Service Keys](#managing-service-keys)
  - [Scheduling Jobs](#scheduling-jobs)
  - [Managing Scheduled Jobs](#managing-scheduled-jobs)
  - [Application Integration](#application-integration)
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
4. **Service Broker**: Provides marketplace integration with Cloud Foundry

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
- `stemcell_os`: Stemcell operating system (default: "ubuntu-jammy")
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

### Binding the Scheduler Service Broker

Register the scheduler service broker with your Cloud Foundry deployment:

```bash
genesis do myenv bind-scheduler
```

This will:
1. Log into the CF API using admin credentials
2. Create or update the service broker
3. Enable service access in all orgs

### Running Smoke Tests

Verify your deployment with the built-in smoke tests:

```bash
genesis do myenv smoke-tests
```

This runs an errand that creates a service instance, schedules a job, verifies execution, and cleans up.

## Using the Scheduler Service

### Creating Service Instances

Create a scheduler service instance in your CF space:

```bash
cf create-service scheduler dedicated my-scheduler
```

### Managing Service Keys

Create service keys to obtain credentials for application binding:

```bash
cf create-service-key my-scheduler my-scheduler-key
cf service-key my-scheduler my-scheduler-key
```

This will display output similar to:

```
Getting key my-scheduler-key for service instance my-scheduler...

{
  "scheduler_url": "https://scheduler.example.com",
  "client_id": "scheduler-client-0123456789",
  "client_secret": "abcdef0123456789"
}
```

### Scheduling Jobs

Schedule tasks to run at specific times using cron expressions:

```bash
# Schedule a task defined in app's manifest.yml
cf schedule-job my-app "my-task" "0 * * * *"

# Schedule a custom command
cf schedule-job my-app "cleanup" --command "rake cleanup:perform" "*/15 * * * *"
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

List scheduled jobs:

```bash
cf jobs my-app
```

View job details and execution history:

```bash
cf job my-app job-guid
```

Delete a scheduled job:

```bash
cf delete-job my-app job-guid
```

Execute a job immediately:

```bash
cf run-job my-app job-guid
```

### Application Integration

For direct application integration:

1. **Bind your application** to the scheduler service:
   ```bash
   cf bind-service my-app my-scheduler
   ```

2. **Access the credentials** in your application through the `VCAP_SERVICES` environment variable:
   ```json
   {
     "scheduler": [
       {
         "credentials": {
           "scheduler_url": "https://scheduler.example.com",
           "client_id": "scheduler-client-0123456789",
           "client_secret": "abcdef0123456789"
         },
         "label": "scheduler",
         "name": "my-scheduler",
         "plan": "dedicated",
         "tags": ["scheduler", "cf"]
       }
     ]
   }
   ```

3. **Use the Scheduler API** to programmatically manage jobs:
   ```
   GET /jobs                    # List jobs
   GET /jobs/{guid}             # Get job details
   POST /jobs                   # Create job
   DELETE /jobs/{guid}          # Delete job
   POST /jobs/{guid}/execute    # Execute job immediately
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

The service integrates with UAA for authentication and authorization. It creates a UAA client with appropriate scopes for the service broker and API access.

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

### Service Broker Registration Fails

**Symptoms**: The `bind-scheduler` addon fails with authentication errors.

**Solutions**:
- Verify CF admin credentials in vault
- Check connectivity to the CF API
- Ensure your CF deployment is healthy

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