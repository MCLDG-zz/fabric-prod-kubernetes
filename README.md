## TODO
do we want to add a queue between the client and the peers? : https://medium.com/wearetheledger/hyperledger-fabric-concurrency-really-eccd901e4040

## Pre-requisite

### Kubernetes cluster
You need a Kubernetes cluster to start. 
You can create one using the kubernetes-on-aws-quickstart repo in MCLDG github account

### EC2 instance and EFS 
git clone the fabric-prod-on-k8s repo to your mac
check the parameters in ec2-for-efs/deploy-ec2-sh
The VPC, RouteTable, CIDR, and Subnet params should be those of your existing K8s cluster
Keypair is an AWS EC2 keypair you own, that you have previously saved to your Mac. You'll need this to access the EC2 
instance created by deploy-ec2.sh
VolumeName is the name assigned to your EFS volume
Once all the parameters are set, in a terminal window run ./ec2-for-efs/deploy-ec2.sh. Check CFN console for completion
When complete, SSH to one of the EC2 instances. The EFS should be mounted in /opt/share

## Use fabric-ca to generate orderer certificates
Prepare the CA server config file:
* In the EFS drive, create the folder structure: /opt/share/mcdg/orderer/
* Copy the file 'fabric-ca-server-config.yaml' from this repo to /opt/share/mcdg/orderer

On the EC2 instance created above, run ./start-orderer-ca.sh. This will run a fabric-ca-server for the orderer.
We will use the fabric-ca-server to generate the certs/keys we need for the orderer

Starting fabric-ca will create the following:
* a ca-cert.pem file in the same directory as 'fabric-ca-server-config.yaml'
* an 'msp/keystore' folder
* a fabric-ca-server.db file - this is the database used by fabric-ca. Should be replaced by MySQL before going to PROD

### Enroll the admin user
Generate the certificates for the orderer:
First, enroll an identity. 
* use 'kubectl exec -it  orderer-ca-86c89f6764-bc8xs -n mcdgorderer bash' to exec into the fabric-ca-server you 
just started. Replace the pod name with your own

The admin is created with no affiliation. Update this:

```bash
export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/admin
fabric-ca-client identity modify admin --affiliation orderer
```

Now enroll the admin and check the certs are in the msp folder:

```bash
export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/admin
fabric-ca-client enroll -u http://admin:adminpw@localhost:7054
ls -lR $FABRIC_CA_CLIENT_HOME
```

```bash
fabric-ca-client enroll -u http://admin:adminpw@localhost:7054
2018/03/26 00:08:43 [INFO] Created a default configuration file at /etc/hyperledger/fabric-ca-server/admin/fabric-ca-client-config.yaml
2018/03/26 00:08:43 [INFO] generating key: &{A:ecdsa S:256}
2018/03/26 00:08:43 [INFO] encoded CSR
2018/03/26 00:08:44 [INFO] Stored client certificate at /etc/hyperledger/fabric-ca-server/admin/msp/signcerts/cert.pem
2018/03/26 00:08:44 [INFO] Stored root CA certificate at /etc/hyperledger/fabric-ca-server/admin/msp/cacerts/localhost-7054.pem
2018/03/26 00:08:44 [INFO] Stored intermediate CA certificates at /etc/hyperledger/fabric-ca-server/admin/msp/intermediatecerts/localhost-7054.pem
```
The enroll command stores an enrollment certificate (ECert), corresponding private key and CA certificate chain 
PEM files in the subdirectories of the Fabric CA client’s msp directory. It also generates an admin/msp/keystore

It also creates a 'fabric-ca-client-config.yaml' in the $FABRIC_CA_HOME/admin directory
*

### Register the orderer user
```bash
export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/admin
fabric-ca-client register --id.name orderer --id.type orderer --id.affiliation orderer.mcdgorderer --id.attrs 'hf.Revoker=true,admin=true:ecert'
```

You should see a response such as:

```bash
fabric-ca-client register --id.name orderer --id.type orderer --id.affiliation orderer.mcdgorderer --id.attrs 'hf.Revoker=true,admin=true:ecert'
2018/03/26 01:57:44 [INFO] Configuration file location: /etc/hyperledger/fabric-ca-server/admin/fabric-ca-client-config.yaml
Password: iTAzQRSKnQFa
```

Exit the fabric-ca container

* copy the admin cert to the admincerts folder of the orderer:
```bash
sudo mkdir /opt/share/mcdg/orderer/orderer/msp/admincerts
cd /opt/share/mcdg/orderer  
sudo cp admin/msp/signcerts/cert.pem orderer/msp/admincerts
```

Back in the fabric-ca container, enroll the orderer user

```bash
export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/orderer
fabric-ca-client enroll -u http://orderer:<replace pwd>@localhost:7054 -M $FABRIC_CA_CLIENT_HOME/msp
```

This will result in:

```bash
# fabric-ca-client enroll -u http://orderer:iTAzQRSKnQFa@localhost:7054 -M $FABRIC_CA_CLIENT_HOME/msp
2018/03/26 02:10:42 [INFO] generating key: &{A:ecdsa S:256}
2018/03/26 02:10:42 [INFO] encoded CSR
2018/03/26 02:10:43 [INFO] Stored client certificate at /etc/hyperledger/fabric-ca-server/orderer/msp/signcerts/cert.pem
2018/03/26 02:10:43 [INFO] Stored root CA certificate at /etc/hyperledger/fabric-ca-server/orderer/msp/cacerts/localhost-7054.pem
2018/03/26 02:10:43 [INFO] Stored intermediate CA certificates at /etc/hyperledger/fabric-ca-server/orderer/msp/intermediatecerts/localhost-7054.pem
```

* Admin certs will be in the EFS drive at: /opt/share/mcdg/orderer/admin/msp
* Orderer certs will be in the EFS drive at: /opt/share/mcdg/orderer/orderer/msp

## Register an orderer peer
```bash
kubectl exec -it  orderer-ca-86c89f6764-bc8xs -n mcdgorderer bash 
```

```bash
export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/admin
fabric-ca-client register --id.name peer0 --id.type peer --id.affiliation orderer.mcdgorderer --id.attrs 'hf.Revoker=true,admin=true:ecert'
```

This will result in a password:

```bash
# fabric-ca-client register --id.name peer0 --id.type peer --id.affiliation orderer.mcdgorderer --id.attrs 'hf.Revoker=true,admin=true:ecert'
2018/03/26 03:08:37 [INFO] Configuration file location: /etc/hyperledger/fabric-ca-server/admin/fabric-ca-client-config.yaml
Password: WfXbQdDArLJz
```

Now, enroll the peer0 user

* export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/peer0
* fabric-ca-client enroll -u http://peer0:<replace pwd>@localhost:7054 -M $FABRIC_CA_CLIENT_HOME/msp

```bash
# fabric-ca-client enroll -u http://peer0:WfXbQdDArLJz@localhost:7054 -M $FABRIC_CA_CLIENT_HOME/msp
2018/03/26 03:11:02 [INFO] Created a default configuration file at /etc/hyperledger/fabric-ca-server/peer0/fabric-ca-client-config.yaml
2018/03/26 03:11:02 [INFO] generating key: &{A:ecdsa S:256}
2018/03/26 03:11:02 [INFO] encoded CSR
2018/03/26 03:11:02 [INFO] Stored client certificate at /etc/hyperledger/fabric-ca-server/peer0/msp/signcerts/cert.pem
2018/03/26 03:11:02 [INFO] Stored root CA certificate at /etc/hyperledger/fabric-ca-server/peer0/msp/cacerts/localhost-7054.pem
2018/03/26 03:11:02 [INFO] Stored intermediate CA certificates at /etc/hyperledger/fabric-ca-server/peer0/msp/intermediatecerts/localhost-7054.pem
```

Exit the fabric-ca container

* copy the admin cert to the admincerts folder of the peer:
```bash
sudo mkdir /opt/share/mcdg/orderer/peer0/msp/admincerts
cd /opt/share/mcdg/orderer  
sudo cp admin/msp/signcerts/cert.pem peer0/msp/admincerts
```

* Peer certs will be in the EFS drive at: /opt/share/mcdg/orderer/peer0/msp

## Generate the genesis block for the orderer
Back on the EC2 instance, generate the genesis.block using the configtx.yaml found in this repo

```bash
# get the configtxgen binary
cd /opt/share/mcdg
curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/linux-amd64-1.1.0-rc1/hyperledger-fabric-linux-amd64-1.1.0-rc1.tar.gz | tar xz
# clone this git repo
cd /opt/share/mcdg
git clone https://github.com/MCLDG/fabric-prod-kubernetes.git
# copy the files configtx.yaml, core.yaml and orderer.yaml from this repo (see orderer/config directory) :
# not sure I need to do this
# sudo cp fabric-prod-kubernetes/orderer/config/* orderer/orderer/

# copy the file configtx.yaml from this repo (see orderer/config directory) to /opt/share/mcdg
cd /opt/share/mcdg
sudo cp fabric-prod-kubernetes/orderer/config/configtx.yaml .

```

Generate the genesis.block
```bash
cd /opt/share/mcdg
sudo bin/configtxgen -profile OrdererGenesis -outputBlock channel-artifacts/genesis.block
```

```bash
$ sudo bin/configtxgen -profile OrdererGenesis -outputBlock channel-artifacts/genesis.block
2018-03-26 03:29:48.569 UTC [common/tools/configtxgen] main -> INFO 001 Loading configuration
2018-03-26 03:29:48.621 UTC [msp] getPemMaterialFromDir -> WARN 002 Failed reading file /opt/share/mcdg/orderer/orderer/msp/intermediatecerts/localhost-7054.pem: no pem content for file /opt/share/mcdg/orderer/orderer/msp/intermediatecerts/localhost-7054.pem
2018-03-26 03:29:48.640 UTC [msp] getPemMaterialFromDir -> WARN 003 Failed reading file /opt/share/mcdg/orderer/orderer/msp/intermediatecerts/localhost-7054.pem: no pem content for file /opt/share/mcdg/orderer/orderer/msp/intermediatecerts/localhost-7054.pem
2018-03-26 03:29:48.671 UTC [msp] getPemMaterialFromDir -> WARN 004 Failed reading file /opt/share/mcdg/orderer/peer0/msp/intermediatecerts/localhost-7054.pem: no pem content for file /opt/share/mcdg/orderer/peer0/msp/intermediatecerts/localhost-7054.pem
2018-03-26 03:29:48.676 UTC [common/tools/configtxgen] doOutputBlock -> INFO 005 Generating genesis block
2018-03-26 03:29:48.676 UTC [common/tools/configtxgen] doOutputBlock -> INFO 006 Writing genesis block
$ ls channel-artifacts/
genesis.block
```
The orderer genesis.block will now be in:

/opt/share/mcdg/channel-artifacts/genesis.block

Inspect the contents of the genesis block:

```bash
bin/configtxgen -inspectBlock channel-artifacts/genesis.block
```

## Start the orderer, peer and CLI pods

```bash
#copy the files core.yaml and orderer.yaml from this repo (see orderer/config directory) : 
sudo cp fabric-prod-kubernetes/orderer/config/orderer.yaml orderer/orderer
sudo cp fabric-prod-kubernetes/orderer/config/core.yaml orderer/peer0/
```

Start the pv's and pods

```bash
cd /opt/share/mcdg
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-pvc-orderer-artifacts.yaml

kubectl apply -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer.yaml
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-cli.yaml
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-peer.yaml

```

## Create a channel
cd /opt/share/mcdg

Generate the channel tx file for the channel

```bash
sudo bin/configtxgen -profile OrdererChannel --outputCreateChannelTx channel-artifacts/channel1.tx -channelID channel1
sudo bin/configtxgen -profile OrdererChannel --outputAnchorPeersUpdate channel-artifacts/ClientMSPanchors.tx -channelID channel1 -asOrg McdgClientOrg
```

```bash
$ sudo bin/configtxgen -profile OrdererChannel --outputCreateChannelTx channel-artifacts/channel1.tx -channelID channel1
2018-03-26 03:46:34.269 UTC [common/tools/configtxgen] main -> INFO 001 Loading configuration
2018-03-26 03:46:34.287 UTC [common/tools/configtxgen] doOutputChannelCreateTx -> INFO 002 Generating new channel configtx
2018-03-26 03:46:34.310 UTC [msp] getPemMaterialFromDir -> WARN 003 Failed reading file /opt/share/mcdg/orderer/peer0/msp/intermediatecerts/localhost-7054.pem: no pem content for file /opt/share/mcdg/orderer/peer0/msp/intermediatecerts/localhost-7054.pem
2018-03-26 03:46:34.330 UTC [common/tools/configtxgen] doOutputChannelCreateTx -> INFO 004 Writing new channel tx
[ec2-user@ip-172-20-66-113 mcdg]$ sudo bin/configtxgen -profile OrdererChannel --outputAnchorPeersUpdate channel-artifacts/ClientMSPanchors.tx -channelID channel1 -asOrg McdgClientOrg
2018-03-26 03:46:34.375 UTC [common/tools/configtxgen] main -> INFO 001 Loading configuration
2018-03-26 03:46:34.390 UTC [common/tools/configtxgen] doOutputAnchorPeersUpdate -> INFO 002 Generating anchor peer update
2018-03-26 03:46:34.391 UTC [common/tools/configtxgen] doOutputAnchorPeersUpdate -> INFO 003 Writing anchor peer update
[ec2-user@ip-172-20-66-113 mcdg]$ ls -l channel-artifacts/
total 16
-rw-r--r-- 1 root root  328 Mar 26 03:46 channel1.tx
-rw-r--r-- 1 root root  289 Mar 26 03:46 ClientMSPanchors.tx
-rw-r--r-- 1 root root 6877 Mar 26 03:29 genesis.block
```
kubectl exec into the CLI container:

```bash
kubectl exec -it cli-5cd5df69f6-q2mtm -n mcdgorderer bash
```

Create a channel

```bash
peer channel create -c channel1 -o orderer:7050 -f channel-artifacts/channel1.tx -t 10
```
This creates a genesis.block for the channel called: channel1.block in the CLI pod in the folder:

/opt/gopath/src/github.com/hyperledger/fabric/peer

You will use this to join the channel in the next section. In the meantime, in the CLI container, copy
this file to channel-artifacts:

```bash
mv channel1.block channel-artifacts/
```

If you see an error such as this, just ignore it (it's a warning) or remove the intermediate cert. 
Since we didn't specify an intermediate cert none should be generated, but for some reason it generates blank certs

2018-03-25 06:16:03.349 UTC [msp] getPemMaterialFromDir -> WARN 001 Failed reading file /etc/hyperledger/fabric/msp/intermediatecerts/localhost-7054.pem: no pem content for file /etc/hyperledger/fabric/msp/intermediatecerts/localhost-7054.pem

## Join a channel
cd /opt/share/mcdg

CORE_PEER_COMMITTER_LEDGER_ORDERER=orderer:7050 peer channel join -b ./channel-artifacts/channel1.block -o orderer:7050



## Stopping and starting the pods
cd /opt/share/mcdg
kubectl delete -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-cli.yaml
kubectl delete -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-peer.yaml
kubectl delete -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer.yaml

kubectl delete -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-ca.yaml
kubectl delete -f fabric-prod-kubernetes/orderer/fabric-pvc-orderer-artifacts.yaml
kubectl delete -f fabric-prod-kubernetes/orderer/fabric-pvc-orderer-config.yaml
kubectl delete -f fabric-prod-kubernetes/orderer/fabric-pvc-orderer-ca.yaml
  
cd /opt/share/mcdg
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-namespace-orderer.yaml
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-pvc-orderer-ca.yaml
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-ca.yaml
  
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-pvc-orderer-artifacts.yaml

kubectl apply -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-cli.yaml
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-peer.yaml
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer.yaml

kubectl get po -n mcdgorderer

## Ports
Orderer CA - container port: 7054, NodePort: 30300
Orderer - container port: 7050, NodePort: 32301

## Keys
Starting fabric-ca will create the following:
* a ca-cert.pem file in the same directory as 'fabric-ca-server-config.yaml'
* an 'msp/keystore' folder

Enrolling the admin user. Note that /opt/share/mcdg/orderer/admin is mapped to /etc/hyperledger/fabric-ca-server/admin
* /etc/hyperledger/fabric-ca-server/admin/msp/signcerts/cert.pem
* /etc/hyperledger/fabric-ca-server/admin/msp/cacerts/localhost-7054.pem
* /etc/hyperledger/fabric-ca-server/admin/msp/intermediatecerts/localhost-7054.pem
* /etc/hyperledger/fabric-ca-server/admin/msp/keystore/eac677f6f22091d507989e8d71587f0c267197c907bf3cbc52410c40d481a9c2_sk

Enrolling the orderer user.
* /etc/hyperledger/fabric-ca-server/orderer/msp/signcerts/cert.pem
* /etc/hyperledger/fabric-ca-server/orderer/msp/cacerts/localhost-7054.pem
* /etc/hyperledger/fabric-ca-server/orderer/msp/intermediatecerts/localhost-7054.pem
* /etc/hyperledger/fabric-ca-server/orderer/msp/keystore/59b7afb1a458afe1b35be00bcbae3d734b91959af1115125f10e430f4e7a2fdb_sk

Enrolling the peer user.
* /etc/hyperledger/fabric-ca-server/peer0/msp/signcerts/cert.pem
* /etc/hyperledger/fabric-ca-server/peer0/msp/cacerts/localhost-7054.pem
* /etc/hyperledger/fabric-ca-server/peer0/msp/intermediatecerts/localhost-7054.pem
* /etc/hyperledger/fabric-ca-server/peer0/msp/keystore/16c5f0e9135412c0eeed12bd2c4772de2170feadedabbf90b8655cbb58a827cc_sk

After enrolling admin, and registering and enrolling orderer & peer0, your directory structure should look as follows:

```bash
# pwd
/etc/hyperledger/fabric-ca-server
# ls -lR msp/
msp/:
total 4
drwxr-xr-x 2 root root 6144 Mar 26 01:42 keystore

msp/keystore:
total 4
-rwx------ 1 root root 241 Mar 26 01:42 a989dbf5940eb69ec326b89a3c7b2f4fdcc01276c03869583702c9e7ee4763cc_sk
# ls -lR admin
admin:
total 12
-rwxr-xr-x 1 root root 6082 Mar 26 01:52 fabric-ca-client-config.yaml
drwx------ 6 root root 6144 Mar 26 01:52 msp

admin/msp:
total 16
drwxr-xr-x 2 root root 6144 Mar 26 01:52 cacerts
drwxr-xr-x 2 root root 6144 Mar 26 01:52 intermediatecerts
drwx------ 2 root root 6144 Mar 26 01:52 keystore
drwxr-xr-x 2 root root 6144 Mar 26 01:52 signcerts

admin/msp/cacerts:
total 4
-rw-r--r-- 1 root root 786 Mar 26 01:52 localhost-7054.pem

admin/msp/intermediatecerts:
total 4
-rw-r--r-- 1 root root 0 Mar 26 01:52 localhost-7054.pem

admin/msp/keystore:
total 4
-rwx------ 1 root root 241 Mar 26 01:52 eac677f6f22091d507989e8d71587f0c267197c907bf3cbc52410c40d481a9c2_sk

admin/msp/signcerts:
total 4
-rw-r--r-- 1 root root 863 Mar 26 01:52 cert.pem
# ls -lR orderer/
orderer/:
total 12
-rwxr-xr-x 1 root root 6130 Mar 26 02:10 fabric-ca-client-config.yaml
drwx------ 7 root root 6144 Mar 26 02:10 msp

orderer/msp:
total 20
drwxr-xr-x 2 root root 6144 Mar 26 02:07 admincerts
drwxr-xr-x 2 root root 6144 Mar 26 02:10 cacerts
drwxr-xr-x 2 root root 6144 Mar 26 02:10 intermediatecerts
drwx------ 2 root root 6144 Mar 26 02:10 keystore
drwxr-xr-x 2 root root 6144 Mar 26 02:10 signcerts

orderer/msp/admincerts:
total 4
-rw-r--r-- 1 root root 863 Mar 26 02:07 cert.pem

orderer/msp/cacerts:
total 4
-rw-r--r-- 1 root root 786 Mar 26 02:10 localhost-7054.pem

orderer/msp/intermediatecerts:
total 4
-rw-r--r-- 1 root root 0 Mar 26 02:10 localhost-7054.pem

orderer/msp/keystore:
total 20
-rwx------ 1 root root 241 Mar 26 02:10 59b7afb1a458afe1b35be00bcbae3d734b91959af1115125f10e430f4e7a2fdb_sk
# ls -lR peer0/
peer0/:
total 12
-rwxr-xr-x 1 root root 6122 Mar 26 03:11 fabric-ca-client-config.yaml
drwx------ 7 root root 6144 Mar 26 03:15 msp

peer0/msp:
total 20
drwxr-xr-x 2 root root 6144 Mar 26 03:15 admincerts
drwxr-xr-x 2 root root 6144 Mar 26 03:11 cacerts
drwxr-xr-x 2 root root 6144 Mar 26 03:11 intermediatecerts
drwx------ 2 root root 6144 Mar 26 03:11 keystore
drwxr-xr-x 2 root root 6144 Mar 26 03:11 signcerts

peer0/msp/admincerts:
total 4
-rw-r--r-- 1 root root 863 Mar 26 03:15 cert.pem

peer0/msp/cacerts:
total 4
-rw-r--r-- 1 root root 786 Mar 26 03:11 localhost-7054.pem

peer0/msp/intermediatecerts:
total 4
-rw-r--r-- 1 root root 0 Mar 26 03:11 localhost-7054.pem

peer0/msp/keystore:
total 4
-rwx------ 1 root root 241 Mar 26 03:11 16c5f0e9135412c0eeed12bd2c4772de2170feadedabbf90b8655cbb58a827cc_sk

peer0/msp/signcerts:
total 4
-rw-r--r-- 1 root root 1078 Mar 26 03:11 cert.pem
```

## Troubleshooting:
### fabric ca client commands not running
To run fabric-ca-client commands, you must set the ENV variables first:

```bash
export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/admin
root@orderer-ca-78586498b4-kk74b:/etc/hyperledger/fabric-ca-server# fabric-ca-client affiliation list
affiliation: orderer
   affiliation: orderer.mcdgorderer
```

### Cannot create channel
Running: peer channel create -c channel1 -o orderer:7050 

2018-03-25 11:30:06.186 UTC [viperutil] getKeysRecursively -> DEBU 045 Found real value for application.Organizations setting to <nil> <nil>
2018-03-25 11:30:06.186 UTC [viperutil] EnhancedExactUnmarshal -> DEBU 046 map[capabilities:map[Orderer:map[V1_1:true] Application:map[V1_1:true] Global:map[V1_1:true]] profiles:map[OrdererGenesis:map[Orderer:map[Capabilities:map[V1_1:true] OrdererType:kafka Addresses:[orderer.mcdgorderer:7050] BatchTimeout:2s BatchSize:map[AbsoluteMaxBytes:99 MB PreferredMaxBytes:512 KB MaxMessageCount:10] Kafka:map[Brokers:[broker.kafka:9092]] Organizations:[map[MSPDir:/opt/share/mcdg/orderer/orderer/msp/ Name:McdgOrdererOrg ID:McdgOrdererOrgMSP]]] Consortiums:map[McdgConsortium:map[Organizations:[map[Name:McdgOrdererOrg ID:McdgOrdererOrgMSP MSPDir:/opt/share/mcdg/orderer/orderer/msp/]]]] Capabilities:map[V1_1:true]]] organizations:[map[MSPDir:/opt/share/mcdg/orderer/orderer/msp/ Name:McdgOrdererOrg ID:McdgOrdererOrgMSP]] orderer:map[Kafka:map[Brokers:[broker.kafka:9092]] Organizations:[map[Name:McdgOrdererOrg ID:McdgOrdererOrgMSP MSPDir:/opt/share/mcdg/orderer/orderer/msp/]] OrdererType:kafka Addresses:[orderer.mcdgorderer:7050] BatchTimeout:2s BatchSize:map[MaxMessageCount:10 AbsoluteMaxBytes:99 MB PreferredMaxBytes:512 KB]] application:map[Organizations:<nil>]]
2018-03-25 11:30:06.187 UTC [common/tools/configtxgen/localconfig] Load -> CRIT 047 Could not find profile:  SampleSingleMSPChannel
panic: Could not find profile: SampleSingleMSPChannel

This is because I need to run :

sudo bin/configtxgen -profile OrdererGenesis --outputCreateChannelTx channel-artifacts/channel1.tx -channelID channel1

to create the genesis block for the channel, then run:

peer channel create -c channel1 -o orderer:7050 -f channel-artifacts/<channel tx file - see configtxgen> -t 10

to pass in the genesis block when creating the channel

### No admin role when creating channel
peer channel create -c channel1 -o orderer:7050 -f channel-artifacts/channel1.tx -t 10

2018-03-26 04:08:59.944 UTC [msp] SatisfiesPrincipal -> DEBU 256 Checking if identity satisfies ADMIN role for McdgClientOrgMSP
2018-03-26 04:08:59.944 UTC [cauthdsl] func2 -> DEBU 257 0xc420122ad0 identity 0 does not satisfy principal: This identity is not an admin
2018-03-26 04:08:59.944 UTC [cauthdsl] func2 -> DEBU 258 0xc420122ad0 principal evaluation fails
2018-03-26 04:08:59.944 UTC [cauthdsl] func1 -> DEBU 259 0xc420122ad0 gate 1522037339944395559 evaluation fails
2018-03-26 04:08:59.944 UTC [policies] Evaluate -> DEBU 25a Signature set did not satisfy policy /Channel/Application/McdgClientOrg/Admins

Resolved this by adding the correct roles to configtx.yaml. Hyperledger will check if the identity is an 
admin if 'AdminPrincipal: Role.ADMIN'. I had this for McdgClientOrg, hence the error message above.

The code that checks this is here: https://github.com/hyperledger/fabric-sdk-go/blob/master/internal/github.com/hyperledger/fabric/msp/mspimpl.go

```
Organizations:

    # SampleOrg defines an MSP using the sampleconfig.  It should never be used
    # in production but may be used as a template for other definitions
    - &McdgOrdererOrg
        # DefaultOrg defines the organization which is used in the sampleconfig
        # of the fabric.git development environment
        Name: McdgOrdererOrg

        # ID to load the MSP definition as
        ID: McdgOrdererOrgMSP

        AdminPrincipal: Role.ADMIN

        # MSPDir is the filesystem path which contains the MSP configuration
        MSPDir: /opt/share/mcdg/orderer/orderer/msp/

    - &McdgClientOrg
        # DefaultOrg defines the organization which is used in the sampleconfig
        # of the fabric.git development environment
        Name: McdgClientOrg

        # ID to load the MSP definition as
        ID: McdgClientOrgMSP

        # MSPDir is the filesystem path which contains the MSP configuration
        MSPDir: /opt/share/mcdg/orderer/peer0/msp/

        AdminPrincipal: Role.PEER

        AnchorPeers:
            # AnchorPeers defines the location of peers which can be used
            # for cross org gossip communication.  Note, this value is only
            # encoded in the genesis block in the Application section context
            - Host: peer0.mcdgorderer
              Port: 7051
```