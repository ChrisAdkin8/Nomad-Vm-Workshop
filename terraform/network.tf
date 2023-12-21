data "aws_arn" "peer" {
  arn = aws_vpc.peer.arn
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_vpc" "peer" {
  cidr_block = local.cidr_block
}

resource "hcp_aws_network_peering" "peer" {
  hvn_id              = hcp_hvn.hvn.hvn_id
  peering_id          = var.peering_id
  peer_vpc_id         = aws_vpc.peer.id
  peer_account_id     = aws_vpc.peer.owner_id
  peer_vpc_region     = data.aws_arn.peer.region
}

resource "hcp_hvn_route" "peer_route" {
  hvn_link         = hcp_hvn.hvn.self_link
  hvn_route_id     = var.route_id
  destination_cidr = aws_vpc.peer.cidr_block
  target_link      = hcp_aws_network_peering.peer.self_link
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  vpc_peering_connection_id = hcp_aws_network_peering.peer.provider_peering_id
  auto_accept               = true
}

resource "aws_route_table" "peer" {
  vpc_id = aws_vpc.peer.id
}

resource "aws_route" "peer_route" {
  route_table_id            = resource.aws_route_table.peer.id
  destination_cidr_block    = hcp_hvn.hvn.cidr_block
  vpc_peering_connection_id = hcp_aws_network_peering.peer.provider_peering_id
}

resource "aws_security_group" "nomad_ui_ingress" {
  name   = "${var.name}-ui-ingress"
  vpc_id = aws_vpc.peer.id

  # Nomad
  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = [var.allowlist_ip, "${chomp(data.http.myip.response_body)}/32"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ local.cidr_block ]
  }
}

resource "aws_security_group" "ssh_ingress" {
  name   = "${var.name}-ssh-ingress"
  vpc_id = aws_vpc.peer.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowlist_ip, "${chomp(data.http.myip.response_body)}/32"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ local.cidr_block ]
  }
}

resource "aws_security_group" "allow_all_internal" {
  name   = "${var.name}-allow-all-internal"
  vpc_id = aws_vpc.peer.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ local.cidr_block ]
  }
}

resource "aws_security_group" "https_egress" {
  name        = "allow-https-egress"
  vpc_id      = aws_vpc.peer.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "clients_ingress" {
  name   = "${var.name}-clients-ingress"
  vpc_id = aws_vpc.peer.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ local.cidr_block ]
  }

  # Add application ingress rules here
  # These rules are applied only to the client nodes

  # nginx example
  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = [ local.cidr_block ]
  # }
}

resource "aws_subnet" "nomad" {
  vpc_id                  = aws_vpc.peer.id
  cidr_block              = local.cidr_block 
  map_public_ip_on_launch = true

  tags = {
    Name = "nomad-vm-lab"
  }
}

resource "aws_route_table_association" "pub_association" {
  route_table_id = aws_route_table.peer.id
  subnet_id      = aws_subnet.nomad.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.peer.id
}

resource "aws_route" "pub_route" {
  route_table_id         = aws_route_table.peer.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
