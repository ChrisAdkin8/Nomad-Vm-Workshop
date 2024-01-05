#!/bin/bash

set -e
set -o pipefail

sudo rm -rf /etc/nomad.d 2> /dev/null
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
  enabled = ${ACL_ENABLED}
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

# init ACL if enabled

if ${ACL_ENABLED}
then
  	echo "init Nomad ACL system"
  

	ACL_DIRECTORY=/tmp/
	TOKENS_BASE_PATH="/home/ubuntu/"
	NOMAD_BOOTSTRAP_TOKEN="$TOKENS_BASE_PATH/nomad_bootstrap"
	NOMAD_USER_TOKEN="$TOKENS_BASE_PATH/nomad_user_token"


sudo cat << EOPOL > $ACL_DIRECTORY/nomad-acl-user.hcl
agent {
	policy = "read"
} 

node { 
	policy = "read" 
} 

namespace "*" { 
	policy = "read" 
	capabilities = ["submit-job", "read-logs", "read-fs"]
}
EOPOL

	# Wait for nomad servers to come up and bootstrap nomad ACL
	for i in {1..12}; do
		# capture stdout and stderr
		set +e
		sleep 5
		OUTPUT=$(nomad acl bootstrap 2>&1)
		if [ $? -ne 0 ]; then
			echo "nomad acl bootstrap: $OUTPUT"
			if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
				echo "nomad no cluster leader"
				continue
			else
				echo "nomad already bootstrapped"
				exit 0
			fi
		fi
		set -e

		echo "$OUTPUT" | grep -i secret | awk -F '=' '{print $2}' | xargs | awk 'NF' > $NOMAD_BOOTSTRAP_TOKEN
		if [ -s $NOMAD_BOOTSTRAP_TOKEN ]; then
			echo "nomad bootstrapped"
			break
		fi
	done

	nomad acl policy apply -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" -description "Policy to allow reading of agents and nodes and listing and submitting jobs in all namespaces." node-read-job-submit $ACL_DIRECTORY/nomad-acl-user.hcl

	nomad acl token create -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" -name "read-token" -policy node-read-job-submit | grep -i secret | awk -F "=" '{print $2}' | xargs > $NOMAD_USER_TOKEN

	chown ubuntu:ubuntu $NOMAD_BOOTSTRAP_TOKEN $NOMAD_USER_TOKEN

	echo "ACL bootstrap end"
fi
