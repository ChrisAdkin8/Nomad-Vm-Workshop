#!/bin/bash

set -e
set -o pipefail

if [ -d "/etc/nomad.d" ]; then
  sudo rm -rf /etc/nomad.d
fi

sudo mkdir /etc/nomad.d
sudo cat << EOF > /etc/nomad.d/nomad.hcl

data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
datacenter = "${DC}"

# Enable the client
client {
  enabled = true
  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
  server_join {
   retry_join = ["${RETRY_JOIN}"]
  }
}

acl {
  enabled = true 
}

tls {
  http = true
  rpc  = true

  ca_file   = "/etc/nomad.d/nomad-agent-ca.pem"
  cert_file = "/etc/nomad.d/global-client-nomad.pem"
  key_file  = "/etc/nomad.d/global-client-nomad-key.pem"

  verify_server_hostname = true
  verify_https_client    = ${NOMAD_TLS_VERIFY_HTTPS_CLIENT}
}

# Configuration for Consul integration
consul {
  address             = "127.0.0.1:8500"
  server_service_name = "nomad"
  client_service_name = "nomad-client"
  auto_advertise      = true
  server_auto_join    = true
  client_auto_join    = true
}
EOF

export NOMAD_ADDR=https://localhost:4646
echo "export NOMAD_ADDR=https://localhost:4646" >> /home/ubuntu/.bashrc

# install CA and key
sudo cat << EOF > /etc/nomad.d/nomad-agent-ca.pem
${NOMAD_CA_PEM}
EOF

# install client cert and key
sudo cat << EOF > /etc/nomad.d/global-client-nomad.pem
${NOMAD_CLIENT_PEM}
EOF

sudo cat << EOF > /etc/nomad.d/global-client-nomad-key.pem
${NOMAD_CLIENT_KEY}
EOF

sleep 25
sudo systemctl start nomad
