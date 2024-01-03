provider "aws" {
  region = var.region
}

resource "tls_private_key" "keypair_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "keypair" {
  key_name   = "id_rsa.pub.aws_nomad"

  public_key = tls_private_key.keypair_private_key.public_key_openssh

  # Create "id_rsa.pem" in local directory
  provisioner "local-exec" {
    command = "rm -rf certs/id_rsa.pem && mkdir -p certs &&  echo '${tls_private_key.keypair_private_key.private_key_pem}' > certs/id_rsa.pem && chmod 400 certs/id_rsa.pem"
  }
}

data "cloudinit_config" "server_config" {
  part {
    filename     = "consul_client.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/config/consul-user-data.sh.tpl", {
      setup = base64gzip(templatefile("${path.module}/config/consul-client.sh.tpl", {
        consul_ca        = data.hcp_consul_cluster.selected.consul_ca_file
        consul_config    = data.hcp_consul_cluster.selected.consul_config_file
        consul_acl_token = hcp_consul_cluster_root_token.token.secret_id,
        consul_version   = data.hcp_consul_cluster.selected.consul_version,
        consul_service   = base64encode(templatefile("${path.module}/config/consul-service.tpl", {
          service_name = "consul",
          service_cmd  = "/usr/bin/consul agent -data-dir /var/consul -config-dir=/etc/consul.d/",
        })),
        vpc_cidr = local.cidr_block
      })),
    })
  }
  part {
    filename     = "nomad_server.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/config/nomad-server.sh.tpl", {
      SERVER_NUMBER     = var.server_count
      RETRY_JOIN        = var.retry_join
      NOMAD_ENT         = var.nomad_ent
      NOMAD_LICENSE     = var.nomad_license
      DC                = var.nomad_dc
      ACL_ENABLED       = var.nomad_acl_enabled
      NOMAD_TLS_ENABLED = var.nomad_tls_enabled
      NOMAD_CA_PEM                  = fileexists("${var.nomad_ca_pem}") ? file("${var.nomad_ca_pem}") : ""
      NOMAD_SERVER_PEM              = fileexists("${var.nomad_server_pem}") ? file("${var.nomad_server_pem}") : ""
      NOMAD_SERVER_KEY              = fileexists("${var.nomad_server_key}") ? file("${var.nomad_server_key}") : ""
      NOMAD_TLS_VERIFY_HTTPS_CLIENT = var.nomad_tls_verify_https_client
    })
  }
}

resource "aws_instance" "server" {
  ami                    = var.ami
  instance_type          = var.server_instance_type
  subnet_id              = aws_subnet.nomad.id
  key_name               = aws_key_pair.keypair.key_name 
  vpc_security_group_ids = [aws_security_group.nomad_ui_ingress.id, aws_security_group.ssh_ingress.id, aws_security_group.allow_all_internal.id, aws_security_group.https_egress.id]
  count                  = var.server_count
  user_data              = data.cloudinit_config.server_config.rendered

  # instance tags
  # NomadAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name}-server-${count.index}"
    },
    {
      "NomadAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "server"
    }
  )

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

data "cloudinit_config" "client_config" {
  part {
    filename     = "consul_client.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/config/consul-user-data.sh.tpl", {
      setup = base64gzip(templatefile("${path.module}/config/consul-client.sh.tpl", {
        consul_ca        = data.hcp_consul_cluster.selected.consul_ca_file
        consul_config    = data.hcp_consul_cluster.selected.consul_config_file
        consul_acl_token = hcp_consul_cluster_root_token.token.secret_id,
        consul_version   = data.hcp_consul_cluster.selected.consul_version,
        consul_service   = base64encode(templatefile("${path.module}/config/consul-service.tpl", {
          service_name = "consul",
          service_cmd  = "/usr/bin/consul agent -data-dir /var/consul -config-dir=/etc/consul.d/",
        })),
        vpc_cidr = local.cidr_block
      })),
    })
  }
  part {
    filename     = "nomad_server.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/config/nomad-client.sh.tpl", {
      DC                = var.nomad_dc
      RETRY_JOIN        = var.retry_join
      NOMAD_ENT         = var.nomad_ent
      ACL_ENABLED       = var.nomad_acl_enabled
      NOMAD_TLS_ENABLED = var.nomad_tls_enabled
      NOMAD_CA_PEM      = fileexists("${var.nomad_ca_pem}") ? file("${var.nomad_ca_pem}") : ""
      NOMAD_CLIENT_PEM              = fileexists("${var.nomad_client_pem}") ? file("${var.nomad_client_pem}") : ""
      NOMAD_CLIENT_KEY              = fileexists("${var.nomad_client_key}") ? file("${var.nomad_client_key}") : ""
      NOMAD_TLS_VERIFY_HTTPS_CLIENT = var.nomad_tls_verify_https_client
    })
  }
}

resource "aws_instance" "client" {
  ami                    = var.ami
  instance_type          = var.client_instance_type
  subnet_id              = aws_subnet.nomad.id
  key_name               = aws_key_pair.keypair.key_name 
  vpc_security_group_ids = [aws_security_group.nomad_ui_ingress.id, aws_security_group.ssh_ingress.id, aws_security_group.clients_ingress.id, aws_security_group.allow_all_internal.id, aws_security_group.https_egress.id]
  count                  = var.client_count
  depends_on             = [aws_instance.server]
  user_data              = data.cloudinit_config.client_config.rendered

  # instance tags
  # NomadAutoJoin is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.name}-client-${count.index}"
    },
    {
      "NomadAutoJoin" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  ebs_block_device {
    device_name           = "/dev/xvdd"
    volume_type           = "gp2"
    volume_size           = "50"
    delete_on_termination = "true"
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = var.name
  role        = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = var.name
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "${var.name}-auto-discover-cluster"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.auto_discover_cluster.json
}

data "aws_iam_policy_document" "auto_discover_cluster" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }
}
