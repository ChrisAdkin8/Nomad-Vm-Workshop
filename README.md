# NOMAD AWS DEMO

## Envirionment Build Instructions

1. Login into the AWS console and create a key pair called nomad-aws-key, go to ```EC2 Dashboard``` -> ```Key Pairs``` -> ```Create key pair``` -> enter key pair name, this will
   result in a file called nomad-aws-key.pem being downloaded.

2. Create a Nomad gossip key on the laptop or PC where you intend to deploy Nomad from:
```
$ openssl rand -base64 32
```

3. Open the terraform.tfvars file and assign:
- an AMI id to the ami variable, the default in the file is for Ubuntu 22.04 in the ```us-east-1``` region, leave this as is if this is the region being deployed to,
  otherwise change this as is appropriate
   
- the string that this command generates to ```nomad_gossip_key``` in the ```terraform.tfvars``` file.
- `nomad_license`: the Nomad Enterprise license (only if using ENT version)
- uncomment the Nomad Enterprise / Nomad OSS blocks as appropriate

4. Specify the environment variables for 

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

## Run!
to provision the cluster run  
`terraform apply`

The `user_data` execution on the remote servers and clients takes a few minutes to complete.  
To check the progress ssh into the instance and `tail -f /var/log/cloud-init-output.log`
