# Troubleshooting Guide

This guide helps troubleshoot common issues with the OCF Scheduler deployment and usage.

## Deployment Issues

### Failed Deployment

**Symptoms**:
- `genesis deploy` command fails
- BOSH shows deployment errors

**Common causes and solutions**:

1. **Database Connection Issues**
   - **Symptom**: Errors like "could not connect to database" in logs
   - **Solution**:
     - For external database, verify connection parameters
     - Check network connectivity between the scheduler VM and database
     - Verify database existence and user permissions
     - Run: `bosh -d myenv-ocf-scheduler logs scheduler --follow` to see detailed errors

2. **Cloud Foundry Integration Issues**
   - **Symptom**: Errors referencing UAA or CF API
   - **Solution**:
     - Verify CF deployment exists and is healthy
     - Check that CF exodus data is available in Vault
     - Ensure CF system domain is accessible

3. **Resource Allocation Issues**
   - **Symptom**: VM or disk creation failures
   - **Solution**:
     - Verify cloud config has the required VM and disk types
     - Increase resources if necessary
     - Check IaaS quotas and limits

### Post-Deployment Hook Failures

**Symptoms**:
- Deployment succeeds but post-deploy hooks fail
- Errors in Genesis output after deployment

**Common causes and solutions**:

1. **Missing CF CLI**
   - **Symptom**: "cf command not found" errors
   - **Solution**: Install the CF CLI on the system running Genesis

2. **CF Authentication Problems**
   - **Symptom**: "Authentication failed" or "Not authorized" errors
   - **Solution**:
     - Check CF admin credentials in Vault
     - Verify CF API is accessible
     - Try logging in manually with the same credentials

3. **Plugin Repository Issues**
   - **Symptom**: "Could not connect to plugin repo" errors
   - **Solution**: Check internet connectivity or proxy settings

## Addon Script Issues

### `setup-cf-plugin` Failures

**Symptoms**:
- Error when running `genesis do myenv setup-cf-plugin`
- Plugin not installed or failing

**Common causes and solutions**:

1. **Plugin Repository Connection**
   - **Symptom**: "Unable to connect to repository" errors
   - **Solution**:
     - Check internet connectivity
     - Verify proxy settings or firewall rules
     - Try manually running `cf add-plugin-repo CF-Community http://plugins.cloudfoundry.org`

2. **Plugin Installation Conflict**
   - **Symptom**: "Plugin already exists" errors
   - **Solution**: Use the `-f` flag to force reinstallation

3. **CF CLI Version Incompatibility**
   - **Symptom**: Plugin installed but commands fail
   - **Solution**: Ensure you're using a compatible CF CLI version (v7+ recommended)

### `bind-scheduler` Addon (Disabled - Not Yet Implemented)

> **⚠️ IMPORTANT**: The `bind-scheduler` addon is currently **disabled** and **not functional**.

**Why it's disabled**:
- The upstream OCF Scheduler application does not implement the Cloud Foundry Service Broker API
- Attempting to register it as a service broker fails with "404 Not Found" errors when CF tries to access `/v2/catalog`
- The scheduler only provides job scheduling endpoints (`/jobs`, `/calls`), not service broker endpoints

**Symptoms you may have seen**:
- Error when running `genesis do myenv bind-scheduler`
- "Status Code: 404 Not Found" when trying to create/update service broker
- Service broker not appearing in marketplace after registration attempts

**Current Workaround**:
Use the scheduler **directly via the CF CLI plugin** instead of through the CF marketplace:

1. Install the CF CLI plugin:
   ```bash
   genesis do myenv setup-cf-plugin
   ```

2. Use the plugin commands directly:
   ```bash
   cf create-job my-app my-job-name "rake db:migrate"
   cf schedule-job my-job-name "0 2 * * *"
   cf jobs
   cf job-schedules
   ```

3. The scheduler API is accessible at: `https://scheduler.<cf-system-domain>`

**Future Resolution**:
This addon may be re-enabled if:
- Upstream OCF Scheduler implements the CF Service Broker API spec
- A separate service broker wrapper application is created
- An alternative integration approach is developed

### `smoke-tests` Failures

**Symptoms**:
- Error when running `genesis do myenv smoke-tests`
- Tests fail to complete

**Common causes and solutions**:

1. **Service Instance Creation Failure**
   - **Symptom**: "Failed to create service instance" errors
   - **Solution**:
     - Note: Service broker registration is not currently functional (see above)
     - Smoke tests should use direct API integration instead

2. **Job Scheduling Failure**
   - **Symptom**: "Failed to schedule job" errors
   - **Solution**:
     - Check scheduler logs for detailed errors
     - Verify UAA integration is working correctly

3. **Test App Issues**
   - **Symptom**: "Failed to push test app" errors
   - **Solution**:
     - Check CF staging logs
     - Verify CF has sufficient resources

## Service Usage Issues

### Scheduled Jobs Not Running

**Symptoms**:
- Jobs are created but never execute
- No execution history in job details

**Common causes and solutions**:

1. **Worker Configuration Issues**
   - **Symptom**: Jobs stuck in pending state
   - **Solution**:
     - Check worker logs: `bosh -d myenv-ocf-scheduler logs scheduler/0 --follow`
     - Increase worker count if overloaded
     - Restart the scheduler job: `bosh -d myenv-ocf-scheduler restart scheduler`

2. **Invalid Cron Expression**
   - **Symptom**: Jobs never trigger
   - **Solution**:
     - Verify cron expression syntax
     - Use a cron expression validator
     - Check for timezone differences

3. **Target Application Issues**
   - **Symptom**: Job failures in execution history
   - **Solution**:
     - Check that the target app exists and is running
     - Verify the task exists in the app manifest or via `--command`
     - Look at app logs during scheduled execution time

### CLI Plugin Issues

**Symptoms**:
- CF CLI commands for scheduler fail
- Error messages when using scheduler commands

**Common causes and solutions**:

1. **Authentication Issues**
   - **Symptom**: "Not authorized" errors
   - **Solution**:
     - Ensure you're logged into CF
     - Verify you have rights to the target space

2. **Plugin Version Mismatch**
   - **Symptom**: Commands fail or behave incorrectly
   - **Solution**: Reinstall the plugin with `genesis do myenv setup-cf-plugin -f`

3. **Service Instance Not Bound**
   - **Symptom**: "No scheduler services found" errors
   - **Solution**:
     - Create a scheduler service instance in your space
     - Verify the service broker is correctly registered

## Database Troubleshooting

### Internal PostgreSQL Issues

**Symptoms**:
- Database-related errors in scheduler logs
- Failed connections or queries

**Common causes and solutions**:

1. **Disk Space Issues**
   - **Symptom**: "No space left on device" errors
   - **Solution**:
     - Check disk usage: `bosh -d myenv-ocf-scheduler ssh scheduler/0 -c "df -h"`
     - Increase persistent disk size
     - Clean up unnecessary data

2. **PostgreSQL Process Issues**
   - **Symptom**: Connection refused errors
   - **Solution**:
     - Check process status: `bosh -d myenv-ocf-scheduler ssh scheduler/0 -c "sudo monit summary"`
     - Restart PostgreSQL if needed: `bosh -d myenv-ocf-scheduler ssh scheduler/0 -c "sudo monit restart postgres"`

### External PostgreSQL Issues

**Symptoms**:
- Connection errors to external database
- Deployment or upgrade failures related to database

**Common causes and solutions**:

1. **Connection Parameter Issues**
   - **Symptom**: "Could not connect to server" errors
   - **Solution**:
     - Verify hostname, port, username, and password
     - Check connection using psql from the scheduler VM

2. **Network Connectivity**
   - **Symptom**: Intermittent connection errors
   - **Solution**:
     - Test network connectivity: `bosh -d myenv-ocf-scheduler ssh scheduler/0 -c "nc -zv <db_host> <db_port>"`
     - Check security groups and firewall rules

3. **Database Permissions**
   - **Symptom**: "Permission denied" errors
   - **Solution**:
     - Verify the user has necessary permissions
     - Check database grants and roles

## Logging and Debugging

### Viewing Logs

1. **BOSH Logs**:
   ```bash
   # All logs
   bosh -d myenv-ocf-scheduler logs

   # Specific job logs
   bosh -d myenv-ocf-scheduler logs scheduler

   # Follow logs in real-time
   bosh -d myenv-ocf-scheduler logs --follow
   ```

2. **CF App Logs**:
   ```bash
   # For apps using scheduler
   cf logs my-app
   ```

3. **Service Broker Logs**:
   ```bash
   # Check CF API logs
   cf logs api
   ```

### Changing Log Level

To increase log verbosity for troubleshooting:

1. Update your deployment with debug log level:
   ```yaml
   params:
     log_level: debug
   ```

2. Redeploy:
   ```bash
   genesis deploy myenv
   ```

### Accessing the Scheduler VM

For advanced troubleshooting, access the VM directly:

```bash
# SSH to the scheduler VM
bosh -d myenv-ocf-scheduler ssh scheduler/0

# View logs directly
sudo cat /var/vcap/sys/log/scheduler/scheduler.log

# Check process status
sudo monit summary

# Check database
sudo su - vcap
/var/vcap/packages/postgres/bin/psql -U scheduler -d scheduler
```

## Getting Help

If you continue to experience issues after trying these troubleshooting steps:

1. File a GitHub issue with the [OCF Scheduler Genesis Kit repository](https://github.com/genesis-community/ocf-scheduler-genesis-kit)
2. Include detailed error messages, deployment manifests (sanitized of credentials), and logs
3. Specify the versions of Genesis, the OCF Scheduler Genesis Kit, and BOSH you're using