#!/usr/bin/env bash
kubectl apply -f fabric-namespace-orderer.yaml
kubectl apply -f fabric-pvc-orderer-ca.yaml
kubectl apply -f fabric-deployment-orderer-ca.yaml
