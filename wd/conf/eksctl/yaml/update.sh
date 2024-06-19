#!/bin/bash
# install KTO
# https://github.com/kubeflow/training-operator
kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.7.0"

# create service role
kubectl create -f conf/eksctl/yaml/test_rbac.yaml
kubectl create -f conf/eksctl/yaml/test_rbac_iam.yaml     # with IAM binding
kubectl create -f conf/eksctl/yaml/test_rbac_iam_agi.yaml
# check service role
kubectl describe serviceaccount job-watcher -n kube-system
# Annotations:         eks.amazonaws.com/role-arn: arn:aws:iam::590184049168:role/Test-EKS-Admin
kubectl describe clusterrolebinding job-watcher-binding
kubectl describe clusterrole system:job-watcher
kubectl describe clusterrole hyperpod-scientist-test-role
# delete service role
kubectl delete serviceaccount job-watcher -n kube-system
kubectl delete clusterrolebinding job-watcher-binding
kubectl delete clusterrole system:job-watcher

# deploy job watcher
kubectl create -f conf/eksctl/yaml/test_job_watcher.yaml
# in case deployment failed / debug deployment failure
kubectl describe deployment job-watcher -n kube-system
kubectl get pods -n kube-system --field-selector=status.phase!=Running
kubectl describe replicaset job-watcher-77c69c857c-rln7j -n kube-system
# monitor job watcher logs
# kubectl logs -f job-watcher-77c69c857c --namespace=kube-system
kubectl logs -f $(kubectl get pods -l app=job-watcher -n kube-system -o jsonpath='{.items[0].metadata.name}') -n kube-system

# Test job creation
kubectl create -f conf/eksctl/yaml/pytorchjob_mnist.yaml
kubectl create -f pytorchjob_mnist.yaml   # AGI
kubectl get pods -n kubeflow
operator_pod_name=`kubectl get pods -n kubeflow | grep "training-operator" | awk -F' ' '{print $1}'`
# only for 1 time debug
kubectl logs -n kubeflow $operator_pod_name
kubectl logs -f -n kubeflow $operator_pod_name

# clean up and retry
kubectl delete deployment job-watcher -n kube-system
kubectl delete pytorchjob pt-test-job1 -n kubeflow

kubectl get pods -l app=job-watcher -n kube-system
kubectl get pods -l app=job-watcher -n kube-system | grep -oE '^[^ ]+'

# Get yaml file for the job
kubectl get -o yaml pytorchjobs pt-test-job1 -n kubeflow

# delete test job
kubectl delete pytorchjob pt-test-job1 -n kubeflow

# Test node label change
kubectl get node

kubectl label nodes ip-192-168-207-242.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReboot
kubectl label nodes i-0194083c3e0e352e7.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status- --overwrite

kubectl label nodes i-08e69006e78c25e4c.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReplacement
kubectl label nodes i-0194083c3e0e352e7.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=SchedulablePreferred
kubectl label nodes ip-192-168-129-59.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=Schedulable
kubectl get nodes ip-192-168-129-59.us-west-2.compute.internal --show-labels | grep Unschedulable
kubectl label nodes ip-192-168-129-59.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status- --overwrite
kubectl uncordon ip-192-168-129-59.us-west-2.compute.internal

# Delete pod
kubectl get pods -n kubeflow
kubectl delete pod $(kubectl get pods -l app=job-watcher -n kube-system -o jsonpath='{.items[0].metadata.name}')

kubectl delete pods -l $LABEL=$VALUE
kubectl delete pods --all

kubectl delete pod pt-test-job1-worker-0