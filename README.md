# Consul on ECS Demo for Containers on the Couch

This demo stands up Consul on ECS and deploys three example appliations: greeter, greeting, and name. The service architecture is:

```
user => ALB => greeter => greeting
                       => name
```

The greeter service depends on the greeting and name services. When it receives a request, it makes a further request to the greeting and name services
to retrieve a greeting (e.g. "Hello") and a name (e.g. "Torres"). It then responds back with `Hello, Torres`.

## Deployment

To deploy, first find out your IP address:

```
curl ifconfig.me
123.456.789.123%
```

This IP address will be used to secure the load balancers.

Clone this repo, `cd` into its directory and create a `terraform.tfvars` file with that IP:

```hcl
lb_ingress_ip = "207.6.233.68"
```

Run `terraform apply` to spin up:
* VPC
* ECS cluster
* The three applications
* Prometheus

Three URLs to the Consul UI, greeter service, and Prometheus will be output. You should be able to navigate to the greeter service URL.

### Metrics

In order to configure Consul to emit metrics to Prometheus, you must set some [configuration entries](https://www.consul.io/docs/connect/config-entries).

Use the Consul UI URL from your installation:

```
export CONSUL_HTTP_ADDR=http://consul-server-123.us-east-1.elb.amazonaws.com:8500
```

[Download Consul](https://www.consul.io/downloads) and run:

```
consul config write consul-configs/proxy-defaults.hcl
```

Now you need to restart the greeter, greeting, and name, tasks so they pick up this new config.
You can do this through the AWS console by stopping the tasks so new ones spin up.

Now you should see Prometheus metrics in the Consul UI.

### Routing

In order to try out Consul's routing configuration, apply the splitter and resolver configs:

```
consul config write consul-configs/service-resolver.hcl
consul config write consul-configs/service-splitter.hcl
```

When set to the `green` subset, the greeting will always be `Guten Tag!`. Try modifying the splitter configuration to point at the `blue` subset.
