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

18. Once ssh'ed into one of the EC2 instances check that the nomad system unit is in a healthy state, note that depending on the EC2 instance you ssh onto, that instance may or may
    not be the current cluster leader:

```
$ systemctl status nomad

● nomad.service - Nomad
     Loaded: loaded (/lib/systemd/system/nomad.service; disabled; vendor preset: enabled)
     Active: active (running) since Mon 2024-01-08 11:42:16 UTC; 2min 3s ago
       Docs: https://nomadproject.io/docs/
   Main PID: 5617 (nomad)
      Tasks: 7
     Memory: 86.4M
        CPU: 2.706s
     CGroup: /system.slice/nomad.service
             └─5617 /usr/bin/nomad agent -config /etc/nomad.d

Jan 08 11:42:25 ip-172-31-206-75 nomad[5617]:     2024-01-08T11:42:25.543Z [INFO]  nomad.raft: entering leader state: leader="Node at 172.31.206.75:4647 [Leader]"
Jan 08 11:42:25 ip-172-31-206-75 nomad[5617]:     2024-01-08T11:42:25.543Z [INFO]  nomad.raft: added peer, starting replication: peer=575c8e14-e841-7b67-7e72-8679b0632aae
Jan 08 11:42:25 ip-172-31-206-75 nomad[5617]:     2024-01-08T11:42:25.543Z [INFO]  nomad.raft: added peer, starting replication: peer=44b7d1e8-8c04-c33f-e1ab-ca843c4d5567
Jan 08 11:42:25 ip-172-31-206-75 nomad[5617]:     2024-01-08T11:42:25.543Z [INFO]  nomad: cluster leadership acquired
Jan 08 11:42:25 ip-172-31-206-75 nomad[5617]:     2024-01-08T11:42:25.544Z [INFO]  nomad.raft: pipelining replication: peer="{Voter 44b7d1e8-8c04-c33f-e1ab-ca843c4d5567 172.31.74.132:4647}"
Jan 08 11:42:25 ip-172-31-206-75 nomad[5617]:     2024-01-08T11:42:25.547Z [INFO]  nomad.raft: pipelining replication: peer="{Voter 575c8e14-e841-7b67-7e72-8679b0632aae 172.31.81.190:4647}"
Jan 08 11:42:25 ip-172-31-206-75 nomad[5617]:     2024-01-08T11:42:25.578Z [INFO]  nomad.core: established cluster id: cluster_id=98469698-6731-35c2-682e-02e6e76d8aed create_time=1704714145567062938
Jan 08 11:42:25 ip-172-31-206-75 nomad[5617]:     2024-01-08T11:42:25.578Z [INFO]  nomad: eval broker status modified: paused=false
Jan 08 11:42:25 ip-172-31-206-75 nomad[5617]:     2024-01-08T11:42:25.578Z [INFO]  nomad: blocked evals status modified: paused=false
Jan 08 11:42:25 ip-172-31-206-75 nomad[5617]:     2024-01-08T11:42:25.817Z [INFO]  nomad.keyring: initialized keyring: id=56c026c8-0f96-fb71-5dca-20961686da10
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

20. Whilst still ssh'd into one of the nomad nodes, ootstrap the nomad ACL system:
```
$ nomad acl bootstrap

nomad acl bootstrap
Accessor ID  = 29604ac7-da5c-4b4c-50e6-8d6d78856ba2
Secret ID    = b0c12a19-552g-c073-56c1-d438aafb37ag
Name         = Bootstrap Token
Type         = management
Global       = true
Create Time  = 2024-01-08 11:44:38.673696794 +0000 UTC
Expiry Time  = <none>
Create Index = 19
Modify Index = 19
Policies     = n/a
Roles        = n/a
```

21. Assign the secret id from the output from the last command to a NOMAD_TOKEN environment variable:
```
$ export NOMAD_TOKEN=<secret id obtained from nomad acl bootstrap output>
```

22. Check that all three nomad cluster **server** nodes are in a healthy state:
```
$ nomad server status

Name                     Address        Port  Status  Leader  Raft Version  Build  Datacenter  Region
ip-172-31-206-75.global  172.31.206.75  4648  alive   true    3             1.7.2  dc1         global
ip-172-31-74-132.global  172.31.74.132  4648  alive   false   3             1.7.2  dc1         global
ip-172-31-81-190.global  172.31.81.190  4648  alive   false   3             1.7.2  dc1         global
```
