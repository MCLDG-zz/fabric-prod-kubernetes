#!/usr/bin/env bash
kubectl apply -f fabric-pvc-orderer-artifacts.yaml
kubectl apply -f fabric-deployment-orderer.yaml
