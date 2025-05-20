# Addon Scripts Documentation

The OCF Scheduler Genesis Kit provides several addon scripts that automate common tasks after deployment. These scripts are executed using the `genesis do` command.

## Available Addons

### `setup-cf-plugin`

Installs the OCF Scheduler plugin for the Cloud Foundry CLI, which allows you to manage scheduled jobs directly through the CF CLI.

**Usage:**
```bash
# Install the plugin
genesis do myenv setup-cf-plugin

# Force reinstallation (overwrite existing plugin)
genesis do myenv setup-cf-plugin -f
```

**What it does:**
1. Checks if the CF Community plugin repository is registered, adds it if not
2. Installs the `ocf-scheduler-cf-plugin` from the Starkandwayne repository
3. If the plugin is already installed, it will check for updates unless forced with `-f`
4. Displays the installed plugin information

**Requirements:**
- Cloud Foundry CLI installed on the local machine
- Internet access to download the plugin

### `bind-scheduler`

Registers the scheduler service broker with your Cloud Foundry deployment, making the scheduler service available in the marketplace.

**Usage:**
```bash
genesis do myenv bind-scheduler
```

**What it does:**
1. Logs in to Cloud Foundry using admin credentials from the CF deployment exodus data
2. Creates a service broker for the scheduler or updates it if it already exists
3. Enables service access so all orgs can use the scheduler service

**Requirements:**
- Cloud Foundry CLI installed on the local machine
- CF CLI targets plugin (`cf-targets`)
- Admin access to the Cloud Foundry deployment
- The scheduler deployment must be running

### `smoke-tests`

Runs smoke tests to verify that the scheduler deployment is working correctly.

**Usage:**
```bash
genesis do myenv smoke-tests
```

**What it does:**
1. Executes the smoke-tests errand in the BOSH deployment
2. Creates a service instance
3. Schedules a test job
4. Verifies the job executes correctly
5. Cleans up test resources

**Requirements:**
- The scheduler deployment must be running
- Admin access to the Cloud Foundry deployment

## Common Command Patterns

### Complete Post-Deployment Setup

After deploying the scheduler, run the following commands in sequence:

```bash
# Set up the CF CLI plugin
genesis do myenv setup-cf-plugin

# Register the service broker
genesis do myenv bind-scheduler

# Verify everything works
genesis do myenv smoke-tests
```

### Updating After Config Changes

After making configuration changes and redeploying:

```bash
# Update the service broker
genesis do myenv bind-scheduler

# Verify changes didn't break anything
genesis do myenv smoke-tests
```

## Implementation Details

The addon scripts are implemented as Perl modules located in the `hooks/` directory:

- `addon-setup-cf-plugin~sp.pm`: Implements the setup-cf-plugin addon
- `addon-bind-scheduler~bs.pm`: Implements the bind-scheduler addon
- `addon-smoke-tests~st.pm`: Implements the smoke-tests addon

These modules use the Genesis hook infrastructure to interact with the deployment and provide consistent error handling and reporting.