TODO

Set up the OSNs and Kafka cluster so that they communicate over SSL - see http://hyperledger-fabric.readthedocs.io/en/release-1.0/kafka.html
Orderers: Adjust polling intervals and timeouts - see step 8 in above link
Kafka and ZK in a separate namespace to Orderer

Steps

  519  git clone https://github.com/Yolean/kubernetes-kafka.git
  524  cd configure/
  526  kubectl apply -f aws-storageclass-zookeeper-gp2.yml
  527  kubectl apply -f aws-storageclass-broker-gp2.yml
  528  cd ..
  529  cd zookeeper/
  531  kubectl apply -f 00namespace.yml
  532  kubectl apply -f 10zookeeper-config.yml
  533  kubectl apply -f 20pzoo-service.yml
  534  kubectl apply -f 21zoo-service.yml
  535  kubectl apply -f 30service.yml
  536  kubectl apply -f 50pzoo.yml
  537  kubectl apply -f 51zoo.yml
  544  kubectl get all -n kafka
  545  cd ..
  546  cd kafka/
  548  kubectl apply -f 10broker-config.yml
  549  kubectl apply -f 20dns.yml
  550  kubectl apply -f 30bootstrap-service.yml
  
  before doing the next step, replace the kafka/50kafka.yml with the file in this repo. It includes
  the KAFKA env variables required by Fabric
  
  553  kubectl apply -f 50kafka.yml
  554  kubectl get all -n kafka
  560  cd test/
  563  kubectl apply -f .
  564  kubectl get pods -l test-type=readiness --namespace=test-kafka


Check ZK to confirm the Kafka brokers are running:

kubectl exec -it pzoo-0 -n kafka bash
cd /opt/kafka/bin
./zookeeper-shell.sh localhost:2181 <<< "ls /brokers/ids"

You should see this - the [0, 1, 2] shows 3 brokers are running:

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
[0, 1, 2]