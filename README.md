# NOMAD Virtual Machine Demo

## Notes

This repo represents a work in progress:

- The Consul cluster element of the configuration is based on [this HashiCorp tutorial](https://developer.hashicorp.com/consul/tutorials/cloud-production/terraform-hcp-consul-provider)
- The Nomad element of the configuration is based on [this repo](https://github.com/chebelom/nomad-aws-demo/tree/main)

## Environment Build Instructions

1. Open the terraform.tfvars file and assign:
- an AMI id to the ami variable, the default in the file is for Ubuntu 22.04 in the ```us-east-1``` region, leave this as is if this is the region being deployed to,
  otherwise change this as is appropriate
   
- the string that this command generates to ```nomad_gossip_key``` in the ```terraform.tfvars``` file.
- `nomad_license`: the Nomad Enterprise license (only if using ENT version)
- uncomment the Nomad Enterprise / Nomad OSS blocks as appropriate

2. Log into HashiCorp Cloud Platform and create a service principal:
<img style="float: left; margin: 0px 15px 15px 0px;" src="https://github.com/ChrisAdkin8/Nomad-Vm-Workshop/blob/main/png_images/01-HCP-Consul-Sp.png?raw=true">

3. Hit 'Create service principal key' for your service principal:
<img style="float: left; margin: 0px 15px 15px 0px;" src="https://github.com/ChrisAdkin8/Nomad-Vm-Workshop/blob/main/png_images/02-HCP-Create-Sp-Key.png?raw=true">

4. Make a note the of the key's Client Id and Client Secret:
<img style="float: left; margin: 0px 15px 15px 0px;" src="https://github.com/ChrisAdkin8/Nomad-Vm-Workshop/blob/main/png_images/03-HCP-Sp-Key.png?raw=true">

5. Specify environment variables for your HCP Client Id, Client secret and project:
```
export HCP_CLIENT_ID=<your client id>
export HCP_CLIENT_SECRET=<the key generated>
export HCP_PROJECT_ID=<your project id>
```

6. Clone this repo:
```
$ git clone https://github.com/ChrisAdkin8/Nomad-Vm-Workshop.git
```

7. Change directory to the certificates ca directory:
```
$ cd terraform/certificates/ca
```

8. Create the tls CA private key and certificate:
```
$ nomad tls ca create
```

9. Create the nomad server private key and certificate and move them to the servers directory:
```
$ nomad tls cert create -server -region global
$ mv *server*.pem ../servers/.
```

10. Create the nomad client private key and certificate and move them to the clients directory:
```
$ nomad tls cert create -client
$ mv *client*.pem ../clients/.
```

11. Create the nomad cli private key and certificate and move them to the cli directory:
```
$ nomad tls cert create -cli
$ mv *client*.pem ../cli/.
```

12. Change directory to ```Nomad-Vm-Workshop/terraform```:
```
$ cd ../..
```

13. Specify the environment variables in order that terraform can connect to your AWS account:
```
export AWS_ACCESS_KEY_ID=<your AWS access key ID>
export AWS_SECRET_ACCESS_KEY=<your AWS secret access key>
export AWS_SESSION_TOKEN=<your AWS session token>
```

14. Install the provider plugins required by the configuration:
```
$ terraform init
```
    
15. Apply the configuration, this will result in the creation of 23 new resources:
```
$ terraform apply -auto-approve
```

16. The tail of the ```terraform apply``` output should look something like this:
```
Apply complete! Resources: 29 added, 0 changed, 0 destroyed.

Outputs:

IP_Addresses = <<EOT

Nomad Cluster installed
SSH default user: ubuntu

Server public IPs: 54.172.43.18, 18.212.218.138, 184.72.134.0
Client public IPs: 54.167.92.93, 54.80.76.185, 52.73.202.229

If ACL is enabled:
To get the nomad bootstrap token, run the following on the leader server
export NOMAD_TOKEN=$(cat /home/ubuntu/nomad_bootstrap)


EOT
lb_address_consul_nomad = "http://54.172.43.18:4646"
```

17. ssh access to the nomad cluster client and server EC2 instances can be achieved via:
```
$ ssh -i certs/id_rsa.pem ubuntu@<client/server IP address>
```

18. Once ssh'ed into one of the EC2 instances check that the nomad system unit is in a healthy state:
```
$ systemctl status nomad

○ nomad.service - Nomad
     Loaded: loaded (/lib/systemd/system/nomad.service; disabled; vendor preset: enabled)
     Active: inactive (dead)
       Docs: https://nomadproject.io/docs/
```

19. Check that the consul agent system unit is in a healthy state:
```
$ systemctl status consul

○ consul.service - "HashiCorp Consul - A service mesh solution"
     Loaded: loaded (/lib/systemd/system/consul.service; disabled; vendor preset: enabled)
     Active: inactive (dead)
       Docs: https://www.consul.io/
```

**Note**
The process of nomad and consul components being installed by cloudinit may take an extra 30 seconds or so after the terraform config
has been applied.

### Optional configuration
#### enable ACL  
to enable and bootstrap the ACL system set  
`nomad_acl_enabled`: `true` 

This enables authentication, therefore you'll need a token to make requests to Nomad.  
Terraform performs the acl boostrap during the initial cluster creation and generates two tokens.  
*These tokens are saved on the server leader at these paths:*  
    - /home/ubuntu/nomad_bootstrap: the bootstap token  
    - /home/ubuntu/nomad_user_token: a token with a limited scope

To get the nomad bootstrap token, run the following on the leader server  
`export NOMAD_TOKEN=$(cat /home/ubuntu/nomad_bootstrap)`


#### enable TLS  
Before being able to use this feature, you need to generate the CA and certificates required by Nomad.  
The `create_tls_certificates.sh` script can do this for you, but you might need to add more [-additional-dnsname](https://developer.hashicorp.com/nomad/docs/commands/tls/cert-create#additional-dnsname) or [-additional-ipaddress](https://developer.hashicorp.com/nomad/docs/commands/tls/cert-create#additional-ipaddress) to match your environment.


If you are using different names or paths for your certificates, change the related variables accordingly.

set `nomad_tls_enabled: true` to enable TLS on the nomad cluster

Follow then this [section of the guide](https://developer.hashicorp.com/nomad/tutorials/transport-security/security-enable-tls#running-with-tls) to configure your CLI (or set nomad_tls_verify_https_client to false)      
