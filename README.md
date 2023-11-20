# Prometheus Scrape Size Tracking

This repo represents an example way of measuring the scrape size rate a Prometheus instance. You can use this methodology to measure your actual Prometheus scrape size rates.

## Prerequisites

- AWS account
- Terraform

## Getting started

You don't need to do much though... Just configure your AWS CLI in your local machine and expose your AWS account ID:

```shell
echo "export AWS_REGION=12345" >> ~/.bashrc
source ~/.bashrc
```

and run the [`01_run_setup.sh`](/scripts/00_deploy_aws.sh) script.

This script will deploy all the necessary components in your AWS account. It already has the setup script [`01_run_setup.sh`](/scripts/01_run_setup.sh) included as `user data` in the EC2 configuration, meaning that the moment your VM is booted, the necessary environment will be automatically created.

### REMARK

If the `user data` does not work because of some reason, just SSH into your machine and copy/paste the `01_run_setup.sh`! That'll do the job as well.

## Environment

### Node-Exporter

The setup script downloads & configures a `node-exporter` instance and runs it as a systemd service. The `node-exporter` has a special configuration which is the `textfile collector`.

With this collector, we define the following specific cronjob:

```shell
cron_job="* * * * * sudo bash -c \"bash /tmp/node_exporter/get_prom_data_size.sh > /var/lib/node_exporter/custom_metrics.prom.new \
  && mv /var/lib/node_exporter/custom_metrics.prom.new /var/lib/node_exporter/custom_metrics.prom\""
(crontab -l ; echo "$cron_job") | crontab -
```

where `get_prom_data_size.sh` does the following:

```shell
#!/bin/bash
echo "# HELP node_prometheus_data_size_kilobytes Size of specified folder in kilobytes"
echo "# TYPE node_prometheus_data_size_kilobytes gauge"
echo node_prometheus_data_size_kilobytes\ \$(du -s /var/lib/prometheus 2>/dev/null | cut -f1)
```

Basically, it checks the size of the directory where Prometheus stores its timeseries data.

So when the cronjob runs this script, it will create a custom Prometheus metric and writes that to the directory where the `node-exporter` `textfile collector` listens to. Thereby, the custom metric `node_prometheus_data_size_kilobytes` will be created.

### Prometheus

Moreover, the `user data` script downloads & configures a Prometheus instance and runs it again as a systemd service. The scrape configuration is as follows:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
scrape_configs:
  - job_name: \"prometheus\"
    static_configs:
      - targets: [\"localhost:9090\"]
  - job_name: \"node-exporter\"
    static_configs:
      - targets: [\"localhost:9200\"]
```

Long story short, it scrapes itself and the `node-exporter`.

## Reaching out Prometheus UI

The Terraform deployment exposes the port `9090` to the outside world. You can enter the Prometheus UI per `http://<YOUR_EC2_PUBLIC_IP>:9090`.

Afterwards, run the following to find out your Prometheus instance scrape size & rate:

```promql
node_prometheus_data_size_kilobytes

rate(node_prometheus_data_size_kilobytes[60m])
```

## What about your actual instances?

Measuring your own Prometheus instances is a bit tricker. Probably, you have set up data retention to your timeseries, meaning that the Prometheus data directory keeps scraping new data as well removing the older ones. So, if you were to just check the size of the data directory, it would give you a lot lower size than reality.

What you can do is:

- You can deploy a VM into the private network where your actual Prometheus instances are running.
- You can install a fresh Prometheus instance on to that VM and configure it just like your actual instances.
- You can install a Node Exporter with the custom metric generator and run this VM for a day or two.

You probably can be able gather enough information about what the scrape size rate is. You can than remove your VM.
