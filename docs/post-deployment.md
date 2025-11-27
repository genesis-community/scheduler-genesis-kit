# Post-Deployment Guide

This guide provides detailed instructions and examples for setting up and using the OCF Scheduler after deployment.

## Initial Setup

After successfully deploying the OCF Scheduler, you need to complete these post-deployment steps to make the service fully operational.

### 1. Set Up the CF CLI Plugin

The OCF Scheduler provides a CF CLI plugin that enables you to manage scheduled jobs directly from the command line.

```bash
# Install the scheduler plugin
genesis do myenv setup-cf-plugin

# Force reinstallation if you want to update an existing plugin
genesis do myenv setup-cf-plugin -f
```

**Verification**:
```bash
cf plugins | grep OCFScheduler
```

You should see output similar to:
```
OCFScheduler   1.2.3   schedule-job, jobs, job, delete-job, run-job
```

### 2. Register the Service Broker

> **⚠️ NOT YET IMPLEMENTED**: The `bind-scheduler` addon is currently disabled as the upstream OCF Scheduler application does not implement the Cloud Foundry Service Broker API. The scheduler can be used directly via the CF CLI plugin without service broker registration.

~~Register the scheduler service broker with your Cloud Foundry deployment to make it available in the marketplace.~~

```bash
# DISABLED - Not yet implemented
# genesis do myenv bind-scheduler
```

Instead, use the scheduler directly via the CF CLI plugin commands after installing it in step 1.

### 3. Run Smoke Tests

Verify that the scheduler deployment is working correctly by running the included smoke tests.

```bash
# Run smoke tests
genesis do myenv smoke-tests
```

The tests will create a service instance, schedule a job, verify it runs correctly, and then clean up. Successful output looks like:
```
Running errand 'smoke-tests'...
[...]
Exit code: 0
Errand 'smoke-tests' completed successfully
```

## Using the Scheduler Service

> **Note**: Since the service broker functionality is not yet implemented, you'll use the scheduler directly via the CF CLI plugin commands. The scheduler API is automatically registered at `https://scheduler.<cf-system-domain>` and uses CF UAA for authentication.

### Direct Job Management with CF CLI Plugin

### Direct Job Management with CF CLI Plugin

The CF CLI plugin provides commands to manage scheduled jobs directly.

#### Create a Job

Create a job that executes a command in your application's container:

```bash
# Create a simple job
cf create-job my-app "cleanup-job" "rake db:cleanup"

# Create a job with custom resource limits
cf create-job my-app "heavy-job" "python process.py" --memory 2048M --disk 1024M
```

#### Schedule a Job

After creating a job, schedule it with a cron expression:

```bash
# Schedule a job to run every hour
cf schedule-job "cleanup-job" "0 * * * *"

# Schedule a job to run every day at 2 AM
cf schedule-job "cleanup-job" "0 2 * * *"

# Schedule a job to run every 15 minutes
cf schedule-job "data-sync-job" "*/15 * * * *"
```

#### View All Jobs

```bash
# List all jobs in the current space
cf jobs

# View jobs for a specific app
cf jobs --app my-app
```

Example output:
```
Getting jobs in space dev / org system...

Name          App Name  Command           
cleanup-job   my-app    rake db:cleanup
data-sync     my-app    python sync.py
```

#### View Job Schedules

```bash
# List all job schedules
cf job-schedules
```

Example output:
```
Getting job schedules in space dev / org system...

Job Name      Schedule      Enabled
cleanup-job   0 2 * * *     true
data-sync     */15 * * * *  true
```

#### Run a Job Immediately

```bash
# Execute a job immediately, regardless of schedule
cf run-job "cleanup-job"
```

#### View Job Execution History

```bash
# View execution history for a job
cf job-history "cleanup-job"
```

Example output:
```
Getting execution history for job cleanup-job...

Execution Guid                         Scheduled Time           State      Message
98765432-10fe-dcba-9876-543210fedcba   2025-11-27T14:00:00Z    SUCCEEDED  Task completed
87654321-09fe-dcba-8765-432109fedcba   2025-11-27T13:45:00Z    SUCCEEDED  Task completed
76543210-98fe-dcba-7654-321098fedcba   2025-11-27T13:30:00Z    FAILED     Command exited with code 1
```

#### Delete a Job

```bash
# Delete a job (this also removes all its schedules)
cf delete-job "cleanup-job"
```

#### Delete a Specific Schedule

```bash
# Delete a specific schedule (keeps the job, just removes the schedule)
cf delete-job-schedule "cleanup-job" "SCHEDULE-GUID"
```

## Advanced Usage: Calls (HTTP Endpoint Scheduling)

In addition to jobs (task execution), the scheduler supports "calls" - scheduling HTTP requests to endpoints.

### Create a Call

```bash
# This is done via the scheduler API directly
# See "Using the Scheduler API Directly" section below
```

## Application Integration Examples

### Accessing the Scheduler from Your Application

Since the scheduler uses CF UAA for authentication, your applications can interact with the scheduler API directly using CF user or client credentials.

## Using the Scheduler API Directly

You can use the scheduler API directly from your application for more advanced scheduling scenarios. The scheduler API is available at `https://scheduler.<cf-system-domain>`.

### Authentication

The scheduler uses CF UAA for authentication. You need a valid CF OAuth token.

#### Get a Token Using CF CLI

```bash
# The easiest way is to use your current CF session
cf oauth-token
```

This returns: `bearer eyJhbGci...`

#### Get a Token Programmatically

```bash
# Using CF user credentials
curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&username=USERNAME&password=PASSWORD" \
  https://uaa.<cf-system-domain>/oauth/token \
  -u "cf:"
```

#### Get a Token Using Client Credentials

If you have a UAA client configured:

```bash
curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=CLIENT_ID&client_secret=CLIENT_SECRET" \
  https://uaa.<cf-system-domain>/oauth/token
```

Response:
```json
{
  "access_token": "eyJhbGci...",
  "token_type": "bearer",
  "expires_in": 43199,
  "scope": "...",
  "jti": "..."
}
```

### API Endpoints

The scheduler exposes RESTful endpoints for managing jobs and calls.

#### Creating a Job via API

```bash
# Create a new job
TOKEN=$(cf oauth-token)
APP_GUID=$(cf app my-app --guid)

curl -k -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: ${TOKEN}" \
  -d '{
    "name": "api-created-job",
    "command": "rake db:cleanup",
    "app_guid": "'${APP_GUID}'"
  }' \
  https://scheduler.<cf-system-domain>/jobs?app_guid=${APP_GUID}
```

Response:
```json
{
  "guid": "01234567-89ab-cdef-0123-456789abcdef",
  "name": "api-created-job",
  "command": "rake db:cleanup",
  "app_guid": "APP_GUID",
  "space_guid": "SPACE_GUID",
  "created_at": "2025-11-27T12:00:00Z",
  "updated_at": "2025-11-27T12:00:00Z"
}
```

#### Listing Jobs via API

```bash
# List all jobs in a space
SPACE_GUID=$(cf space dev --guid)
TOKEN=$(cf oauth-token)

curl -k -X GET \
  -H "Authorization: ${TOKEN}" \
  https://scheduler.<cf-system-domain>/jobs?space_guid=${SPACE_GUID}
```

#### Getting Job Details via API

```bash
# Get details for a specific job
TOKEN=$(cf oauth-token)
JOB_GUID="01234567-89ab-cdef-0123-456789abcdef"

curl -k -X GET \
  -H "Authorization: ${TOKEN}" \
  https://scheduler.<cf-system-domain>/jobs/${JOB_GUID}
```

#### Creating a Job Schedule via API

```bash
# Schedule a job
TOKEN=$(cf oauth-token)
JOB_GUID="01234567-89ab-cdef-0123-456789abcdef"

curl -k -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: ${TOKEN}" \
  -d '{
    "enabled": true,
    "expression": "0 2 * * *",
    "expression_type": "cron"
  }' \
  https://scheduler.<cf-system-domain>/jobs/${JOB_GUID}/schedules
```

#### Running a Job Immediately via API

```bash
# Execute a job immediately
TOKEN=$(cf oauth-token)
JOB_GUID="01234567-89ab-cdef-0123-456789abcdef"

curl -k -X POST \
  -H "Authorization: ${TOKEN}" \
  https://scheduler.<cf-system-domain>/jobs/${JOB_GUID}/execute
```

#### Deleting a Job via API

```bash
# Delete a job
TOKEN=$(cf oauth-token)
JOB_GUID="01234567-89ab-cdef-0123-456789abcdef"

curl -k -X DELETE \
  -H "Authorization: ${TOKEN}" \
  https://scheduler.<cf-system-domain>/jobs/${JOB_GUID}
```

### Application Integration Example

Here's how to integrate the scheduler API into your application:

#### Node.js/JavaScript Example

```javascript
const axios = require('axios');

// Configuration
const SCHEDULER_URL = 'https://scheduler.system.example.com';
const UAA_URL = 'https://uaa.system.example.com';
const CLIENT_ID = 'your-client-id';
const CLIENT_SECRET = 'your-client-secret';

// Get OAuth token
async function getToken() {
  const response = await axios.post(
    `${UAA_URL}/oauth/token`,
    'grant_type=client_credentials',
    {
      auth: {
        username: CLIENT_ID,
        password: CLIENT_SECRET
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    }
  );
  return response.data.access_token;
}

// Create a job
async function createJob(appGuid, jobName, command) {
  const token = await getToken();
  
  const response = await axios.post(
    `${SCHEDULER_URL}/jobs?app_guid=${appGuid}`,
    {
      name: jobName,
      command: command,
      app_guid: appGuid
    },
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    }
  );
  
  return response.data;
}

// Schedule a job
async function scheduleJob(jobGuid, cronExpression) {
  const token = await getToken();
  
  const response = await axios.post(
    `${SCHEDULER_URL}/jobs/${jobGuid}/schedules`,
    {
      enabled: true,
      expression: cronExpression,
      expression_type: 'cron'
    },
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    }
  );
  
  return response.data;
}

// Usage
(async () => {
  const appGuid = process.env.APP_GUID;
  const job = await createJob(appGuid, 'cleanup-job', 'rake db:cleanup');
  console.log('Created job:', job.guid);
  
  const schedule = await scheduleJob(job.guid, '0 2 * * *');
  console.log('Scheduled job:', schedule);
})();
```

#### Python Example

```python
import requests
import os

# Configuration
SCHEDULER_URL = 'https://scheduler.system.example.com'
UAA_URL = 'https://uaa.system.example.com'
CLIENT_ID = 'your-client-id'
CLIENT_SECRET = 'your-client-secret'

def get_token():
    """Get OAuth token from UAA"""
    response = requests.post(
        f'{UAA_URL}/oauth/token',
        data={'grant_type': 'client_credentials'},
        auth=(CLIENT_ID, CLIENT_SECRET),
        headers={'Content-Type': 'application/x-www-form-urlencoded'}
    )
    response.raise_for_status()
    return response.json()['access_token']

def create_job(app_guid, job_name, command):
    """Create a new job"""
    token = get_token()
    
    response = requests.post(
        f'{SCHEDULER_URL}/jobs',
        params={'app_guid': app_guid},
        json={
            'name': job_name,
            'command': command,
            'app_guid': app_guid
        },
        headers={
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
    )
    response.raise_for_status()
    return response.json()

def schedule_job(job_guid, cron_expression):
    """Schedule a job with a cron expression"""
    token = get_token()
    
    response = requests.post(
        f'{SCHEDULER_URL}/jobs/{job_guid}/schedules',
        json={
            'enabled': True,
            'expression': cron_expression,
            'expression_type': 'cron'
        },
        headers={
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
    )
    response.raise_for_status()
    return response.json()

# Usage
if __name__ == '__main__':
    app_guid = os.environ['APP_GUID']
    
    # Create job
    job = create_job(app_guid, 'cleanup-job', 'python cleanup.py')
    print(f"Created job: {job['guid']}")
    
    # Schedule it
    schedule = schedule_job(job['guid'], '0 2 * * *')
    print(f"Scheduled job: {schedule}")
```

## Common Use Cases and Examples

### 1. Data Cleanup Tasks

Schedule regular database cleanup tasks:

```bash
# Create the job
cf create-job data-service "cleanup-job" "rake db:cleanup"

# Schedule it to run every day at 2:00 AM
cf schedule-job "cleanup-job" "0 2 * * *"
```

### 2. Periodic Reporting

Generate and email reports on a schedule:

```bash
# Create the reporting job
cf create-job reporting-app "weekly-report" "python generate_report.py --type=weekly"

# Schedule it for every Monday at 9:00 AM
cf schedule-job "weekly-report" "0 9 * * 1"
```

### 3. Data Synchronization

Sync data from external systems periodically:

```bash
# Create the sync job
cf create-job integration-app "sync-inventory" "node sync.js --source=inventory"

# Schedule it to run every 15 minutes
cf schedule-job "sync-inventory" "*/15 * * * *"
```

### 4. Batch Processing

Process data in batches during off-peak hours:

```bash
# Create the batch processing job
cf create-job batch-processor "process-transactions" "python batch_process.py"

# Schedule it to run daily at 1:00 AM
cf schedule-job "process-transactions" "0 1 * * *"
```

### 5. Cache Warming

Pre-warm application caches before peak usage times:

```bash
# Create the cache warming job
cf create-job web-app "warm-cache" "rake cache:warm"

# Schedule it to run at 8:00 AM on weekdays
cf schedule-job "warm-cache" "0 8 * * 1-5"
```

## Best Practices

1. **Use descriptive job names** that indicate the purpose of the scheduled task
2. **Document your cron expressions** to ensure others understand the schedule
3. **Implement proper error handling** in your scheduled tasks
4. **Monitor job execution history** to detect and troubleshoot failures
5. **Set appropriate timeouts** for long-running tasks
6. **Use idempotent operations** when possible to prevent issues with duplicate executions
7. **Limit concurrent job execution** to avoid overloading your application
8. **Test scheduled jobs** thoroughly before relying on them in production

## Cron Expression Reference

Quick reference for common cron expressions:

| Schedule               | Cron Expression | Description                        |
|------------------------|----------------|------------------------------------|
| Every minute           | `* * * * *`    | Runs every minute                  |
| Every 15 minutes       | `*/15 * * * *` | Runs at :00, :15, :30, :45 each hour |
| Hourly                 | `0 * * * *`    | Runs at the start of each hour     |
| Every 2 hours          | `0 */2 * * *`  | Runs every 2 hours (:00)           |
| Daily at midnight      | `0 0 * * *`    | Runs at 12:00 AM every day         |
| Daily at 8:30 AM       | `30 8 * * *`   | Runs at 8:30 AM every day          |
| Weekdays at 9:00 AM    | `0 9 * * 1-5`  | Runs at 9:00 AM Monday to Friday   |
| Weekends at 10:00 AM   | `0 10 * * 0,6` | Runs at 10:00 AM Saturday & Sunday |
| Weekly (Sunday at 12AM)| `0 0 * * 0`    | Runs at 12:00 AM on Sunday         |
| Monthly (1st at 12AM)  | `0 0 1 * *`    | Runs at 12:00 AM on the 1st        |
| Quarterly              | `0 0 1 1,4,7,10 *` | Runs on the 1st of Jan, Apr, Jul, Oct |