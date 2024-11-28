scheduler Genesis Kit
=================

This assumes a genesis deployed CF environment with the same environment name
has already been deployed.

Quick Start
-----------

To use it, you don't even need to clone this repository! Just run
the following (using Genesis v2):

```
# create a scheduler-deployments repo using the latest version of the scheduler kit
genesis init --kit scheduler

# create a scheduler-deployments repo using v1.0.0 of the scheduler kit
genesis init --kit scheduler/1.0.0
```

Once created, refer to the deployment repository README for information on
provisioning and deploying new environments.

Features
-------

## `external-postgres` and `external-postgres-vault`

By default an internal (colocoated job) postgres is deployed for use. Optionally
you may configure to use an external PostgreSQL database by adding the
`external-postgres-vault` feature together with the following in vault (no defaults).

```
secret/$env/vault/db:scheme
secret/$env/vault/db:username
secret/$env/vault/db:password
secret/$env/vault/db:hostname
secret/$env/vault/db:port
secret/$env/vault/db:sslmode
secret/$env/vault/db:database
```

Note that when you do a `new` environment you will be prompted for these and
they will get stored in vault directly so you do not need to set them separately.

If you are using another system to generate them and stick into vault
(ex: terraform) then it will be directly consumed.

You can do this using `safe` in a single command like so:
```sh
safe set secret/dev/ocf-scheduler/db \
  hostname="rds-scheduler-20220817135133803000000001.amzdohuu4x1g.us-west-2.rds.amazonaws.com" \
  port="5432" \
  username="scheduler" \
  password="U4k294KkhuNEe9ZaGoe15tGywr5o" \
  scheme="postgres://" \
  sslmode="disable" \
  database="scheduler"
```

for the `external-postgres` feature (no `-vault`) you can override defaults
using the environment file's params object:

```yaml
params:
  pg_scheme:   "..."
  pg_username: "..."
  pg_password: "..."
  pg_hostname: "..."
  pg_port:     "..."
  pg_sslmode:  "..."
  pg_database: "..."
```

## `cf-route-registrar`

By enabling the `cf-route-registrar` feature the kit will extrac the CF deployment
information required to register the scheduler API with CF at
`scheduler.<cf_system_domain>`


## Number of Workers

The number of works defaults to 20 and can be set using the `worker_count` param, for example:
```yaml
params:
  worker_count: 40
```

## Log Level

The log level defaults to `info` and can be set using the `log_level` param, for example:
```yaml
params:
  log_level: debug
```

Params
------

No specific parameters are required in order to deploy the OCF Scheduler kit.

Params per-feature are defined above.

Cloud Config
------------

The scheduler service is golang based and as such does not require a huge amount
of resources. That said be sure to allocate enough dedicated CPU vs time-shared.
Two cores should be sufficient.

If using the internal postgres feature (default) then more resources should be
allocated for the running of the PostgreSQL server.
