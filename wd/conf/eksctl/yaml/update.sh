#!/bin/bash
kubectl delete pytorchjob pt-test-job1 -n kubeflow
kubectl delete deployment job-watcher -n kube-system
kubectl create -f conf/eksctl/yaml/test_job_watcher.yaml
kubectl get pods -l app=job-watcher -n kube-system
kubectl get pods -l app=job-watcher -n kube-system | grep -oE '^[^ ]+'
kubectl describe deployment job-watcher -n kube-system
# kubectl logs -f job-watcher-6c5494df57-vgz9d --namespace=kube-system
kubectl logs -f $(kubectl get pods -l app=job-watcher -n kube-system -o jsonpath='{.items[0].metadata.name}') -n kube-system

# Test job creation
kubectl create -f conf/eksctl/yaml/pytorchjob_mnist.yaml

# Test node label change
kubectl get node
kubectl label nodes ip-192-168-141-155.us-west-2.compute.internal node-health-status=UnschedulablePendingReboot
kubectl label nodes ip-192-168-141-155.us-west-2.compute.internal node-health-status=UnschedulablePendingReplacement
kubectl label nodes ip-192-168-141-155.us-west-2.compute.internal node-health-status=SchedulablePreferred
kubectl label nodes ip-192-168-141-155.us-west-2.compute.internal node-health-status=Schedulable
kubectl get nodes ip-192-168-141-155.us-west-2.compute.internal --show-labels | grep Unschedulable
kubectl label nodes ip-192-168-141-155.us-west-2.compute.internal node-health-status- --overwrite
kubectl uncordon ip-192-168-141-155.us-west-2.compute.internal

# Delete pod
kubectl get pods -n kubeflow
kubectl delete pod $(kubectl get pods -l app=job-watcher -n kube-system -o jsonpath='{.items[0].metadata.name}')