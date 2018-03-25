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

Generate the certificates for the orderer:
First, enroll an identity. 
* use 'kubectl exec -it  orderer-ca-86c89f6764-bc8xs -n mcdgorderer bash' to exec into the fabric-ca-server you 
just started. Replace the pod name with your own
* export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/admin
* run 'fabric-ca-client enroll -u http://admin:adminpw@localhost:7054'
* run 'ls -lR $FABRIC_CA_CLIENT_HOME' and check the msp certs have been generated
*  fabric-ca-client register --id.name orderer --id.affiliation orderer.mcdgorderer --id.attrs 'hf.Revoker=true,admin=true:ecert'

You should see a response such as:

root@orderer-ca-86c89f6764-6xcd8:/# fabric-ca-client register --id.name orderer --id.affiliation orderer.mcdgorderer --id.attrs 'hf.Revoker=true,admin=true:ecert'
2018/03/22 06:26:49 [INFO] Configuration file location: /etc/hyperledger/fabric-ca-server/clients/admin/fabric-ca-client-config.yaml
Password: CmwvxRAxSeqw

Now, enroll the orderer user

* export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/orderer
* fabric-ca-client enroll -u http://mcdgorderer:<replace pwd>@localhost:7054 -M $FABRIC_CA_CLIENT_HOME/msp
- wonder if mcdgorderer above should be just orderer

Exit the fabric-ca container

* Admin certs will be in the EFS drive at: /opt/share/mcdg/orderer/admin/msp
* Orderer certs will be in the EFS drive at: /opt/share/mcdg/orderer/orderer/msp

* copy the admin cert to the admincerts folder of the orderer:
sudo mkdir /opt/share/mcdg/orderer/orderer/msp/admincerts
In directory: /opt/share/mcdg/orderer  
sudo cp admin/msp/signcerts/cert.pem orderer/msp/admincerts

## Generate the genesis block for the orderer
Back on the EC2 instance, go to /opt/share/mcdg
curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/linux-amd64-1.1.0-rc1/hyperledger-fabric-linux-amd64-1.1.0-rc1.tar.gz | tar xz
cd /opt/share/mcdg
copy the files configtx.yaml, core.yaml and orderer.yaml from this repo (see orderer/config directory) : 
sudo cp fabric-prod-kubernetes/orderer/config/* orderer/orderer/

copy the file configtx.yaml from this repo (see orderer/config directory) to /opt/share/mcdg
cd /opt/share/mcdg
sudo cp fabric-prod-kubernetes/orderer/config/configtx.yaml .

Still in directory: /opt/share/mcdg
sudo bin/configtxgen -profile OrdererGenesis -outputBlock channel-artifacts/genesis.block

The orderer genesis.block will now be in:

/opt/share/mcdg/channel-artifacts/genesis.block

Inspect the contents of the genesis block:

bin/configtxgen -inspectBlock channel-artifacts/genesis.block

Now you can deploy the orderer. At this point we have an orderer with an orderer system channel
Next we need an orderer peer.

## Register an orderer peer
- for some reason I had to enroll the admin user again... not sure why. This regenerated the keys
* use 'kubectl exec -it  orderer-ca-86c89f6764-bc8xs -n mcdgorderer bash' to exec into the fabric-ca-server you 
just started. Replace the pod name with your own
fabric-ca-client register --id.name peer0 --id.type peer --id.affiliation orderer.mcdgorderer --id.attrs 'hf.Revoker=true,admin=true:ecert'
2018/03/25 04:10:27 [INFO] Configuration file location: /etc/hyperledger/fabric-ca-server/fabric-ca-client-config.yaml
Password: VawcmZhcegHa

Now, enroll the peer0 user

* export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/peer0
* fabric-ca-client enroll -u http://peer0:<replace pwd>@localhost:7054 -M $FABRIC_CA_CLIENT_HOME/msp

* Peer certs will be in the EFS drive at: /opt/share/mcdg/orderer/peer0/msp

* copy the admin cert to the admincerts folder of the orderer:
sudo mkdir /opt/share/mcdg/orderer/peer0/msp/admincerts
In directory: /opt/share/mcdg/orderer
sudo cp admin/msp/signcerts/cert.pem peer0/msp/admincerts

copy the files configtx.yaml, core.yaml and orderer.yaml from this repo (see orderer/config directory) : 
sudo cp fabric-prod-kubernetes/orderer/config/* orderer/peer0/

Start the peer container

## Register the CLI user
- for some reason I had to enroll the admin user again... not sure why. This regenerated the keys
* use 'kubectl exec -it  orderer-ca-86c89f6764-bc8xs -n mcdgorderer bash' to exec into the fabric-ca-server you 
just started. Replace the pod name with your own
fabric-ca-client register --id.name cli --id.type client --id.affiliation orderer.mcdgorderer --id.attrs 'hf.Revoker=true,admin=true:ecert'
2018/03/25 06:08:39 [INFO] Configuration file location: /etc/hyperledger/fabric-ca-server/fabric-ca-client-config.yaml
Password: NaNujwwwAlnX

Now, enroll the peer0 user

* export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_HOME/cli
* fabric-ca-client enroll -u http://cli:<replace pwd>@localhost:7054 -M $FABRIC_CA_CLIENT_HOME/msp

Exit the CA container

* CLI certs will be in the EFS drive at: /opt/share/mcdg/orderer/cli/msp


* copy the admin cert to the admincerts folder of the orderer:
sudo mkdir /opt/share/mcdg/orderer/cli/msp/admincerts
In directory: /opt/share/mcdg/orderer
sudo cp admin/msp/signcerts/cert.pem cli/msp/admincerts

copy the files configtx.yaml, core.yaml and orderer.yaml from this repo (see orderer/config directory) : 
sudo cp fabric-prod-kubernetes/orderer/config/* orderer/cli/


Start the CLI pod

## Create a channel
cd /opt/share/mcdg

sudo bin/configtxgen -profile OrdererGenesis --outputCreateChannelTx channel-artifacts/channel1.tx -channelID channel1

peer channel create -c channel1 -o orderer:7050 -f channel-artifacts/<channel tx file - see configtxgen> -t 10

If you see an error such as this, just remove the intermediate cert. Since we didn't specify an intermediate cert
none should be generated, but for some reason it generates blank certs

2018-03-25 06:16:03.349 UTC [msp] getPemMaterialFromDir -> WARN 001 Failed reading file /etc/hyperledger/fabric/msp/intermediatecerts/localhost-7054.pem: no pem content for file /etc/hyperledger/fabric/msp/intermediatecerts/localhost-7054.pem

## Stopping and starting the pods
cd /opt/share/mcdg
kubectl delete -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-cli.yaml
kubectl delete -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-peer.yaml
kubectl delete -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer.yaml

kubectl apply -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-cli.yaml
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer-peer.yaml
kubectl apply -f fabric-prod-kubernetes/orderer/fabric-deployment-orderer.yaml

kubectl get po -n mcdgorderer
## Ports
Orderer CA - container port: 7054, NodePort: 30300
Orderer - container port: 7050, NodePort: 32301

## Troubleshooting:
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