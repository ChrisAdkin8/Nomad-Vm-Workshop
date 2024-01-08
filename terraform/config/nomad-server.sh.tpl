#!/bin/bash

set -e
set -o pipefail

if [ -d "/etc/nomad.d" ]; then
  sudo rm -rf /etc/nomad.d
fi

sudo mkdir /etc/nomad.d
sudo chmod 777 /etc/nomad.d

sudo cat << EOLIC > /etc/nomad.d/license.hclic
${NOMAD_LICENSE}
EOLIC

sudo cat << EOF > /etc/nomad.d/nomad.hcl
data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
datacenter = "${DC}"

# Enable the server
server {
  enabled          = true
  bootstrap_expect = ${SERVER_NUMBER}

  server_join {
   retry_join = ["${RETRY_JOIN}"]
  }

  license_path = "/etc/nomad.d/license.hclic"
}

acl {
  enabled = true 
}

# Require TLS
tls {
  http = true
  rpc  = true

  ca_file   = "/etc/nomad.d/nomad-agent-ca.pem"
  cert_file = "/etc/nomad.d/global-server-nomad.pem"
  key_file  = "/etc/nomad.d/global-server-nomad-key.pem"

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

export NOMAD_CACERT=/etc/nomad.d/nomad-agent-ca.pem
echo "export NOMAD_CACERT=/etc/nomad.d/nomad-agent-ca.pem" >> /home/ubuntu/.bashrc

# install CA and key
sudo cat << EOF > /etc/nomad.d/nomad-agent-ca.pem
${NOMAD_CA_PEM}
EOF

# install server cert and key
sudo cat << EOF > /etc/nomad.d/global-server-nomad.pem
${NOMAD_SERVER_PEM}
EOF

sudo cat << EOF > /etc/nomad.d/global-server-nomad-key.pem
${NOMAD_SERVER_KEY}
EOF

sleep 25
sudo systemctl start nomad
