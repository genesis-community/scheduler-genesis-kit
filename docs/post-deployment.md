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

Register the scheduler service broker with your Cloud Foundry deployment to make it available in the marketplace.

```bash
# Register the service broker
genesis do myenv bind-scheduler
```

**Verification**:
```bash
# Verify service broker exists
cf service-brokers | grep scheduler

# Verify service is available in marketplace
cf marketplace | grep scheduler
```

You should see the scheduler service in the marketplace output:
```
service      plans       description
scheduler    dedicated   OCF Scheduler for jobs and tasks
```

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

### Creating a Service Instance

Before applications can use the scheduler, you need to create a service instance in your Cloud Foundry space.

```bash
# Create a service instance
cf create-service scheduler dedicated my-scheduler

# Wait for the service instance to be created
cf service my-scheduler
```

Wait until the status shows `create succeeded`.

### Create Service Keys for API Access

Service keys provide credentials for applications to access the scheduler API.

```bash
# Create a service key
cf create-service-key my-scheduler my-scheduler-key

# View the service key credentials
cf service-key my-scheduler my-scheduler-key
```

You'll see output similar to:
```json
{
  "scheduler_url": "https://scheduler.example.com",
  "client_id": "scheduler-client-0123456789",
  "client_secret": "abcdef0123456789"
}
```

### Scheduling Jobs with the CF CLI Plugin

The CF CLI plugin provides commands to manage scheduled jobs.

#### Schedule a Task

Schedule a task defined in your application's manifest.yml:

```bash
# Schedule a task to run every hour
cf schedule-job my-app "my-task" "0 * * * *"
```

Schedule a custom command (not defined in manifest):

```bash
# Schedule a rake task to run every 15 minutes
cf schedule-job my-app "cleanup" --command "rake cleanup:perform" "*/15 * * * *"
```

#### View Scheduled Jobs

```bash
# List all scheduled jobs for an application
cf jobs my-app
```

Example output:
```
Getting scheduled jobs for app my-app...

Job Name   Guid                                  Command               Schedule     Enabled
cleanup    01234567-89ab-cdef-0123-456789abcdef  rake cleanup:perform  */15 * * * *  true
my-task    fedcba98-7654-3210-fedc-ba9876543210                        0 * * * *     true
```

#### View Job Details and History

```bash
# View details and execution history for a job
cf job my-app 01234567-89ab-cdef-0123-456789abcdef
```

Example output:
```
Getting job cleanup for app my-app...

Job Name:    cleanup
Guid:        01234567-89ab-cdef-0123-456789abcdef
Command:     rake cleanup:perform
Schedule:    */15 * * * *
Enabled:     true

Execution History:
Execution Guid                         Scheduled Time             Execution Status
98765432-10fe-dcba-9876-543210fedcba   2023-04-15T12:00:00Z      SUCCEEDED
87654321-09fe-dcba-8765-432109fedcba   2023-04-15T11:45:00Z      SUCCEEDED
76543210-98fe-dcba-7654-321098fedcba   2023-04-15T11:30:00Z      FAILED
```

#### Run a Job Immediately

```bash
# Execute a job immediately, regardless of schedule
cf run-job my-app 01234567-89ab-cdef-0123-456789abcdef
```

#### Delete a Job

```bash
# Delete a scheduled job
cf delete-job my-app 01234567-89ab-cdef-0123-456789abcdef
```

## Application Integration Examples

### 1. Binding an Application

To use the scheduler from your application, bind the service instance:

```bash
# Bind the scheduler service to your application
cf bind-service my-app my-scheduler

# Restart your application to pick up the new environment variables
cf restart my-app
```

### 2. Accessing Scheduler Credentials in Your Application

The scheduler credentials are provided to your application through the `VCAP_SERVICES` environment variable.

#### Node.js Example

```javascript
// Get scheduler credentials from VCAP_SERVICES
const vcap = JSON.parse(process.env.VCAP_SERVICES);
const scheduler = vcap.scheduler[0].credentials;

console.log("Scheduler URL:", scheduler.scheduler_url);
console.log("Client ID:", scheduler.client_id);
console.log("Client Secret:", scheduler.client_secret);
```

#### Ruby Example

```ruby
# Get scheduler credentials from VCAP_SERVICES
vcap = JSON.parse(ENV['VCAP_SERVICES'])
scheduler = vcap['scheduler'][0]['credentials']

puts "Scheduler URL: #{scheduler['scheduler_url']}"
puts "Client ID: #{scheduler['client_id']}"
puts "Client Secret: #{scheduler['client_secret']}"
```

#### Java Example

```java
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

// Get scheduler credentials from VCAP_SERVICES
String vcapJson = System.getenv("VCAP_SERVICES");
ObjectMapper mapper = new ObjectMapper();
JsonNode vcap = mapper.readTree(vcapJson);
JsonNode scheduler = vcap.get("scheduler").get(0).get("credentials");

String schedulerUrl = scheduler.get("scheduler_url").asText();
String clientId = scheduler.get("client_id").asText();
String clientSecret = scheduler.get("client_secret").asText();
```

### 3. Using the Scheduler API Directly

You can use the scheduler API directly from your application for more advanced scheduling scenarios.

#### Authentication

First, obtain an OAuth token from UAA:

```bash
curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=CLIENT_ID&client_secret=CLIENT_SECRET" \
  https://uaa.example.com/oauth/token
```

Response:
```json
{
  "access_token": "eyJhbGci...",
  "token_type": "bearer",
  "expires_in": 43199
}
```

#### Creating a Job via API

```bash
# Create a new job
curl -k -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer ACCESS_TOKEN" \
  -d '{
    "name": "api-job",
    "command": "rake cleanup",
    "schedule": "*/30 * * * *",
    "app_guid": "APP_GUID",
    "enabled": true
  }' \
  https://scheduler.example.com/v1/jobs
```

Response:
```json
{
  "guid": "01234567-89ab-cdef-0123-456789abcdef",
  "name": "api-job",
  "command": "rake cleanup",
  "schedule": "*/30 * * * *",
  "app_guid": "APP_GUID",
  "enabled": true,
  "created_at": "2023-04-15T12:00:00Z",
  "updated_at": "2023-04-15T12:00:00Z"
}
```

#### Listing Jobs via API

```bash
# List all jobs for an application
curl -k -X GET -H "Authorization: Bearer ACCESS_TOKEN" \
  https://scheduler.example.com/v1/jobs?app_guid=APP_GUID
```

#### Getting Job Details via API

```bash
# Get details for a specific job
curl -k -X GET -H "Authorization: Bearer ACCESS_TOKEN" \
  https://scheduler.example.com/v1/jobs/01234567-89ab-cdef-0123-456789abcdef
```

#### Running a Job Immediately via API

```bash
# Execute a job immediately
curl -k -X POST -H "Authorization: Bearer ACCESS_TOKEN" \
  https://scheduler.example.com/v1/jobs/01234567-89ab-cdef-0123-456789abcdef/execute
```

## Common Use Cases and Examples

### 1. Data Cleanup Tasks

Schedule regular database cleanup tasks:

```bash
cf schedule-job data-service "cleanup" --command "rake db:cleanup" "0 2 * * *"
```

This schedules a cleanup task to run every day at 2:00 AM.

### 2. Periodic Reporting

Generate and email reports on a schedule:

```bash
cf schedule-job reporting-app "weekly-report" --command "python generate_report.py --type=weekly" "0 9 * * 1"
```

This schedules a weekly report to be generated every Monday at 9:00 AM.

### 3. Data Synchronization

Sync data from external systems periodically:

```bash
cf schedule-job integration-app "sync-inventory" --command "node sync.js --source=inventory" "*/15 * * * *"
```

This schedules data synchronization to run every 15 minutes.

### 4. Batch Processing

Process data in batches during off-peak hours:

```bash
cf schedule-job batch-processor "process-transactions" "0 1 * * *"
```

This schedules transaction processing to run at 1:00 AM daily.

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