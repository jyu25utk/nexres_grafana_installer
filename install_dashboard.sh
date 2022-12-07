if [ ! -d "Download" ]
then
  echo "Download folder doesn't exist. Creating now"
  mkdir "./Download"
  echo "Folder created"
else
  echo "Folder exists, removing existing files"
  rm -rf "./Download"
  mkdir "./Download"
  echo "New Folder created"
fi

echo "Downloading prometheus"
if curl -o "./Download/prometheus.tar.gz" -LO "https://github.com/prometheus/prometheus/releases/download/v2.39.1/prometheus-2.39.1.linux-amd64.tar.gz"
then 
  tar -xf "./Download/prometheus.tar.gz" -C "./Download/" && mv "./Download/prometheus-2.39.1.linux-amd64" "./Download/prometheus"
else
  echo "Something went wrong, cannot insall promethus"
fi
echo "prometheus downloaded"

echo "Downloading node_exporter.."
if curl -o "./Download/node_exporter.tar.gz" -LO "https://github.com/prometheus/node_exporter/releases/download/v1.4.0/node_exporter-1.4.0.linux-amd64.tar.gz"
then 
  tar -xf "./Download/node_exporter.tar.gz" -C "./Download/" && mv "./Download/node_exporter-1.4.0.linux-amd64" "./Download/node_exporter"
else
  echo "Something went wrong"
fi
echo "node_exporter downloaded"


echo "Installing grafana.."
sudo apt-get install -y apt-transport-https
sudo apt-get install -y software-properties-common wget
sudo wget -q -O "/usr/share/keyrings/grafana.key" "https://apt.grafana.com/gpg.key"
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | sudo tee -a "/etc/apt/sources.list.d/grafana.list"
sudo apt-get update
sudo apt-get install grafana
echo "Grafana installed"

echo "Set up grafana.ini"
sudo sed -i 's/;allow_embedding = false/allow_embedding = true/' "/etc/grafana/grafana.ini"
sudo sed -i 's/;enabled = false/enabled = true/1' "/etc/grafana/grafana.ini"
sudo sed -i 's/;org_name = Main Org./org_name = Main Org./1' "/etc/grafana/grafana.ini"
sudo sed -i 's/;org_role = Viewer/org_role = Viewer/1' "/etc/grafana/grafana.ini"

echo "Allow internet access on port 3000 for grafana internface"
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 3000 -j ACCEPT
sudo netfilter-persistent save

echo "Allow internet access on port 9090 for prometheus internface"
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 9090 -j ACCEPT
sudo netfilter-persistent save

echo "Configuring grafana start with system"
sudo systemctl enable grafana-server

promeyml='  - job_name: "node_exporter"\n    static_configs:\n      - targets: ["localhost:9100"]\n  - job_name: "cpp_client1"\n    static_configs:\n      - targets: ["localhost:8091"]\n  - job_name: "cpp_client2"\n    static_configs:\n      - targets: ["localhost:8092"]\n  - job_name: "cpp_client3"\n    static_configs:\n      - targets: ["localhost:8093"]\n  - job_name: "cpp_client4"\n    static_configs:\n      - targets: ["localhost:8094"]\n  - job_name: "cpp_client5"\n    static_configs:\n      - targets: ["localhost:8095"]\n'

echo "Adding nexres target information to prometheus"
# echo $promeyml >> "./Download/prometheus/prometheus.yml"
sed -i '$a\'"$promeyml"'' "./Download/prometheus/prometheus.yml"
echo "Chaning scraping time to 5s"
sed -i 's/  scrape_interval: 15s/  scrape_interval: 5s/' "./Download/prometheus/prometheus.yml"

echo "Cleaning directory"
if [ -d "/etc/prometheus" ]
then
  sudo rm -rf "/etc/prometheus"
fi

if [ -d "/var/lib/prometheus" ]
then
  sudo rm -rf "/var/lib/prometheus"
fi

if [ -f "/usr/local/bin/prometheus" ]
then
  sudo rm "/usr/local/bin/prometheus"
fi

if [ -f "/usr/local/bin/promtool" ]
then
  sudo rm "/usr/local/bin/promtool"
fi

if [ -f "/etc/systemd/system/prometheus.service" ]
then
  sudo rm "/etc/systemd/system/prometheus.service"
fi

if [ -f "/usr/local/bin/node_exporter" ]
then
  sudo rm "/usr/local/bin/node_exporter"
fi

if [ -f "/etc/systemd/system/node_exporter.service" ]
then
  sudo rm "/etc/systemd/system/node_exporter.service"
fi

echo "Creatinging promrtheus user profile"
sudo useradd --no-create-home --shell "/bin/false" prometheus
sudo mkdir "/etc/prometheus"
sudo mkdir "/var/lib/prometheus"
sudo chown prometheus:prometheus "/etc/prometheus"
sudo chown prometheus:prometheus "/var/lib/prometheus"

echo "Copy prometheus files"
sudo cp "./Download/prometheus/prometheus" "/usr/local/bin/"
sudo cp "./Download/prometheus/promtool" "/usr/local/bin/"
sudo chown prometheus:prometheus "/usr/local/bin/prometheus"
sudo chown prometheus:prometheus "/usr/local/bin/promtool"

echo "Moving prometheus console"
sudo cp -r "./Download/prometheus/consoles" "/etc/prometheus"
sudo cp -r "./Download/prometheus/console_libraries" "/etc/prometheus"
sudo chown -R prometheus:prometheus "/etc/prometheus/consoles"
sudo chown -R prometheus:prometheus "/etc/prometheus/console_libraries"

echo "Moving prometheus configuration file"
sudo cp -r "./Download/prometheus/prometheus.yml" "/etc/prometheus"
sudo chown prometheus:prometheus "/etc/prometheus/prometheus.yml"

echo "Setup prometheus service file"
sudo cp -r "./prometheus.service" "/etc/systemd/system"

echo "Start prometheus with system"
sudo systemctl daemon-reload
sudo systemctl stop prometheus
sudo systemctl start prometheus
sudo systemctl enable prometheus

echo "Create node exporter user"
sudo useradd -rs "/bin/false" node_exporter

echo "Moving node exporter files"
sudo cp -r "./Download/node_exporter/node_exporter" "/usr/local/bin"

echo "Setup node exporter service file"
sudo cp -r "./node_exporter.service" "/etc/systemd/system"

echo "Start node exporter with system"
sudo systemctl daemon-reload
sudo systemctl stop node_exporter
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

echo "configurate nexres as a system service"
sudo cp -r "./start_nexres.sh" "/usr/local/bin"
sudo chmod +x "/usr/local/bin/start_nexres.sh"
if [ ! -f "/etc/rc.local" ]
then
  sudo cp -r "./rc.local" "/etc"
fi
sudo chmod +x "/etc/rc.local"
if [ ! -f "/etc/systemd/system/rc-local.service" ]
then
 sudo cp -r "./rc-local.service" "/etc/systemd/system/"
fi
sudo systemctl stop rc-local
sudo systemctl start rc-local
sudo systemctl enable rc-local

echo "Nexres dashboard installation complete"
