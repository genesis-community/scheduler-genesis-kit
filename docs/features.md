# Feature Documentation

This document details the available features of the OCF Scheduler Genesis Kit.

## Available Features

### Internal PostgreSQL (Default)

By default, the kit deploys a colocated PostgreSQL instance on the scheduler VM. This is suitable for development, testing, and small-scale production deployments.

### `external-postgres`

Configures the scheduler to use an external PostgreSQL database instead of the colocated one. Configuration is provided via params in the environment file.

**Environment configuration:**
```yaml
features:
  - external-postgres

params:
  pg_scheme:   "postgres://"
  pg_username: "scheduler"
  pg_password: "superSecretPassword"
  pg_hostname: "my-database-host.example.com"
  pg_port:     "5432"
  pg_sslmode:  "disable"
  pg_database: "scheduler"
```

### `external-postgres-vault`

Similar to `external-postgres`, but retrieves database connection information from Vault instead of the environment file. This is the recommended approach for production environments as it keeps credentials secure.

**Environment configuration:**
```yaml
features:
  - external-postgres-vault
```

**Vault configuration:**
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

The following vault paths are used:
```
secret/$env/ocf-scheduler/db:scheme
secret/$env/ocf-scheduler/db:username
secret/$env/ocf-scheduler/db:password
secret/$env/ocf-scheduler/db:hostname
secret/$env/ocf-scheduler/db:port
secret/$env/ocf-scheduler/db:sslmode
secret/$env/ocf-scheduler/db:database
```

### `cf-route-registrar`

Enables automatic route registration with Cloud Foundry. This creates a route for the scheduler API at `scheduler.<cf_system_domain>`.

**Environment configuration:**
```yaml
features:
  - cf-route-registrar
```

## Feature Compatibility

| Feature Combination | Compatible | Notes |
|---------------------|------------|-------|
| internal-postgres (default) + cf-route-registrar | Yes | Standard deployment |
| external-postgres + cf-route-registrar | Yes | Production recommended |
| external-postgres-vault + cf-route-registrar | Yes | Most secure option |
| external-postgres + external-postgres-vault | No | Use one database config method |

## Feature Details

### Internal PostgreSQL

When using the internal PostgreSQL database:

- PostgreSQL is colocated on the scheduler VM
- Database credentials are generated and stored in Vault
- Database persistence depends on the VM's persistent disk
- Database is automatically configured during deployment

### External PostgreSQL Considerations

When using an external PostgreSQL database:

- The database must already exist before deployment
- The specified user must have all necessary permissions
- Connection is verified during pre-deploy hooks
- Database migrations are applied automatically
- For high availability, consider using a database service or cluster

### CF Route Registrar Details

The route registrar:

- Extracts CF deployment information from the specified CF deployment
- Registers a route in the system domain
- Updates route registration if the scheduler VM changes
- Requires the CF deployment to be accessible from the scheduler VM