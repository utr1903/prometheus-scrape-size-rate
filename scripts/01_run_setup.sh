#####################
### Run the setup ###
#####################

# Update & upgrade
sudo apt-get update
echo Y | sudo apt-get upgrade

# Intall wget
echo Y | sudo apt-get install wget

#####################
### Node Exporter ###
#####################

# Prepare directories for Node Exporter
sudo mkdir -p /tmp/node_exporter
sudo mkdir -p /var/lib/node_exporter

# Install Node Exporter
sudo wget -O /tmp/node_exporter/node_exporter-1.7.0.linux-amd64.tar.gz https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
sudo tar -xvf /tmp/node_exporter/node_exporter-1.7.0.linux-amd64.tar.gz -C /tmp/node_exporter/
sudo mv /tmp/node_exporter/node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

# Set up Node Exporter group & user
sudo groupadd -f node_exporter
sudo useradd -g node_exporter --no-create-home --shell /bin/false node_exporter
sudo mkdir /etc/node_exporter
sudo chown node_exporter:node_exporter /etc/node_exporter /usr/local/bin/node_exporter /var/lib/node_exporter

# Create custom script to measure Prometheus data directory
sudo bash -c 'sudo cat <<'EOF' > /tmp/node_exporter/get_prom_data_size.sh
#!/bin/bash
echo "# HELP node_prometheus_data_size_kilobytes Size of specified folder in kilobytes"
echo "# TYPE node_prometheus_data_size_kilobytes gauge"
echo node_prometheus_data_size_kilobytes\ \$(du -s /var/lib/prometheus 2>/dev/null | cut -f1)
EOF'

# Create a cronjob to run the Prometheus data directory script
cron_job="* * * * * sudo bash -c \"bash /tmp/node_exporter/get_prom_data_size.sh > /var/lib/node_exporter/custom_metrics.prom.new \
  && mv /var/lib/node_exporter/custom_metrics.prom.new /var/lib/node_exporter/custom_metrics.prom\""
(crontab -l ; echo "$cron_job") | crontab -

# Run Node Exporter as a systemd service
sudo bash -c "sudo cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address=:9200 \
  --collector.textfile.directory=/var/lib/node_exporter

[Install]
WantedBy=multi-user.target
EOF"

sudo chmod 664 /etc/systemd/system/node_exporter.service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

##################
### Prometheus ###
##################

# Prepare directories for Prometheus
sudo mkdir -p /var/lib/prometheus
sudo mkdir -p /etc/prometheus
sudo mkdir -p /tmp/prometheus

# Download and setup Prometheus
sudo wget -O /tmp/prometheus/prometheus-2.45.1.linux-amd64.tar.gz https://github.com/prometheus/prometheus/releases/download/v2.45.1/prometheus-2.45.1.linux-amd64.tar.gz
sudo tar -xvf /tmp/prometheus/prometheus-2.45.1.linux-amd64.tar.gz -C /tmp/prometheus/
sudo mv /tmp/prometheus/prometheus-2.45.1.linux-amd64/prometheus /tmp/prometheus/prometheus-2.45.1.linux-amd64/promtool /usr/local/bin/
sudo mv /tmp/prometheus/prometheus-2.45.1.linux-amd64/consoles/ /tmp/prometheus/prometheus-2.45.1.linux-amd64/console_libraries/ /etc/prometheus/
sudo mv /tmp/prometheus/prometheus-2.45.1.linux-amd64/prometheus.yml /etc/prometheus/

# Set up Prometheus group & user
sudo groupadd prometheus
sudo useradd -s /sbin/nologin --system -g prometheus prometheus
sudo chown -R prometheus:prometheus /etc/prometheus/ /var/lib/prometheus/
sudo chmod -R 775 /etc/prometheus/ /var/lib/prometheus/

# Edit Prometheus configuration file
sudo bash -c "sudo cat <<EOF | sudo tee /etc/prometheus/prometheus.yml
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
EOF"

# Run Prometheus as a systemd service
sudo bash -c "sudo cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/prometheus \
--config.file=/etc/prometheus/prometheus.yml \
--storage.tsdb.path=/var/lib/prometheus \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries \
--web.listen-address=0.0.0.0:9090 \
--web.external-url=
SyslogIdentifier=prometheus
Restart=always
[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
