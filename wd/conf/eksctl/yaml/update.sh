#!/bin/bash
kubectl delete pytorchjob pt-test-job1 -n kubeflow
kubectl delete deployment job-watcher -n kube-system
kubectl create -f conf/eksctl/yaml/test_job_watcher.yaml
kubectl get pods -l app=job-watcher -n kube-system
kubectl get pods -l app=job-watcher -n kube-system | grep -oE '^[^ ]+'
kubectl describe deployment job-watcher -n kube-system
# kubectl logs -f job-watcher-6c5494df57-vgz9d --namespace=kube-system
kubectl logs -f $(kubectl get pods -l app=job-watcher -n kube-system -o jsonpath='{.items[0].metadata.name}') -n kube-system
kubectl create -f conf/eksctl/yaml/pytorchjob_mnist.yaml