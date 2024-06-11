#!/bin/bash
# install KTO
# https://github.com/kubeflow/training-operator
kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.7.0"

# create service role
kubectl create -f conf/eksctl/yaml/test_rbac.yaml
# deploy job watcher
kubectl create -f conf/eksctl/yaml/test_job_watcher.yaml
# in case deployment failed / debug deployment failure
kubectl describe deployment job-watcher -n kube-system
kubectl get pods -n kube-system --field-selector=status.phase!=Running -n kube-system
kubectl describe replicaset job-watcher-77c69c857c -n kube-system

# clean up and retry
kubectl delete pytorchjob pt-test-job1 -n kubeflow
kubectl delete deployment job-watcher -n kube-system

kubectl get pods -l app=job-watcher -n kube-system
kubectl get pods -l app=job-watcher -n kube-system | grep -oE '^[^ ]+'

# kubectl logs -f job-watcher-6c5494df57-vgz9d --namespace=kube-system
kubectl logs -f $(kubectl get pods -l app=job-watcher -n kube-system -o jsonpath='{.items[0].metadata.name}') -n kube-system

# Test job creation
kubectl create -f conf/eksctl/yaml/pytorchjob_mnist.yaml
operator_pod_name=`kubectl get pods -n kubeflow | grep "training-operator" | awk -F' ' '{print $1}'`
kubectl logs -n kubeflow $operator_pod_name

# Get yaml file for the job
kubectl get -o yaml pytorchjobs pt-test-job1 -n kubeflow

# delete test job
kubectl delete pytorchjob pt-test-job1 -n kubeflow

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