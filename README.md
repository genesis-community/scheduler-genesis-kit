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

## `external-postgres`

By default an internal (colocoated job) postgres is deployed for use. Optionally
you may configure to use an external PostgreSQL database by adding the 
`external-postgres` feature together with the following parameters:

```
params:
  pg:
    host: "..."
    port: "5432"
    user: "..."
    pass: "..."
```

## `cf-route-registrar`

By enabling the `cf-route-registrar` feature the kit will extrac the CF deployment
information required to register the scheduler API with CF at 
`scheduler.<cf_system_domain>`

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

