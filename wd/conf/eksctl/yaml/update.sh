#!/bin/bash
kubectl delete deployment job-watcher -n kube-system
kubectl create -f conf/eksctl/yaml/test_job_watcher.yaml
kubectl get pods -l app=job-watcher -n kube-system
kubectl get pods -l app=job-watcher -n kube-system | grep -oE '^[^ ]+'
