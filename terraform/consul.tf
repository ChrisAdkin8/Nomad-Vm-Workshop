provider "hcp" {}

data "hcp_consul_cluster" "selected" {
  cluster_id = var.cluster_id
}

resource "hcp_hvn" "hvn" {
  hvn_id         = var.hvn_id
  cloud_provider = var.cloud_provider
  region         = var.region
}

resource "hcp_consul_cluster" "consul" {
  hvn_id          = hcp_hvn.hvn.hvn_id
  cluster_id      = var.cluster_id
  tier            = "development"
  public_endpoint = true
}

resource "hcp_consul_cluster_root_token" "token" {
  cluster_id = data.hcp_consul_cluster.selected.id
} 
