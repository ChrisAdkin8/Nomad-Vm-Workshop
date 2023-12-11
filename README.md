# NOMAD AWS DEMO

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
$ git clone 
```

7. Change directory to ```Nomad-Vm-Workshop/terraform```:
```
$ cd Nomad-Vm-Workshop/terraform
```

8. Specify the environment variables in order that terraform can connect to your AWS account:
```
export AWS_ACCESS_KEY_ID=<your AWS access key ID>
export AWS_SECRET_ACCESS_KEY=<your AWS secret access key>
export AWS_SESSION_TOKEN=<your AWS session token>
```

9. Install the provider plugins required by the configuration:
```
$ terraform init
```
    
10. Apply the configuration:
```$ terraform apply -auto-approve```
    When the configuration is fully applied, 23 new resources should appear in yuor AWS account.
    

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
