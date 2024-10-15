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


# https://github.com/aws/sagemaker-hyperpod-cli/blob/main/helm_chart/HyperPodHelmChart/charts/job-auto-restart/templates/job-auto-restart-rbac.yaml
# Validate job watcher related permissions
kubectl describe clusterrole job-auto-restart
kubectl describe serviceaccount job-auto-restart -n aws-hyperpod
kubectl describe clusterrolebinding  job-auto-restart

# Validate HMA related permissions
kubectl describe clusterrole health-monitoring-agent
kubectl describe serviceaccount health-monitoring-agent -n aws-hyperpod
kubectl describe clusterrolebinding  health-monitoring-agent

# Validate burn-in related permissions
kubectl describe clusterrole deep-health-check-service-account-role
kubectl describe serviceaccount deep-health-check-service-account -n aws-hyperpod
kubectl describe clusterrolebinding  deep-health-check-service-account-role-binding

# deploy job watcher
kubectl create -f conf/eksctl/yaml/test_job_watcher.yaml
# in case deployment failed / debug deployment failure
kubectl describe deployment job-watcher -n kube-system
kubectl get pods -n kube-system --field-selector=status.phase!=Running
kubectl describe replicaset job-watcher-77c69c857c -n kube-system
# monitor job watcher logs
# kubectl logs -f job-watcher-77c69c857c --namespace=kube-system
kubectl logs -f $(kubectl get pods -l app=job-watcher -n kube-system -o jsonpath='{.items[0].metadata.name}') -n kube-system

# update k8s config
aws eks update-kubeconfig --region us-west-2 --name xin-eks-1-30-c5
aws eks update-kubeconfig --region us-west-2 —name EKS-ManualK8sClusterWithCustomerVpc-1724883189-eade179c8

# create namespace
kubectl create namespace hyperpod1
kubectl get namespaces

# Test job creation
kubectl create -f conf/eksctl/yaml/pytorchjob_mnist.yaml
kubectl create -f conf/eksctl/yaml/pytorchjob_agi.yaml
kubectl create -f pytorchjob_mnist.yaml   # AGI hosts
kubectl get pods -n kubeflow
operator_pod_name=`kubectl get pods -n kubeflow | grep "training-operator" | awk -F' ' '{print $1}'`
# only for 1 time debug
kubectl logs -n kubeflow $operator_pod_name
kubectl logs -f -n kubeflow $operator_pod_name

# clean up and retry
kubectl delete deployment job-watcher -n kube-system    # only used for self testing
kubectl delete pytorchjob pt-job-1 -n kubeflow

kubectl get pods -l app=job-watcher -n kube-system
kubectl get pods -l app=job-watcher -n kube-system | grep -oE '^[^ ]+'

# Get yaml file for the job
kubectl get -o yaml pytorchjobs pt-test-job1 -n kubeflow

# delete test job
kubectl delete pytorchjob pt-test-job1 -n kubeflow

# Test node label change
kubectl get node

kubectl describe pod -n kubeflow pt-job-1-worker-1

kubectl label nodes ip-192-168-239-97.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReplacement
kubectl label nodes ip-192-168-164-40.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReboot
kubectl label nodes ip-192-168-164-40.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status- --overwrite

# "ip-192-168-154-218.us-west-2.compute.internal"
# force delete pod
kubectl delete pod pt-job-1-worker-0 --force --grace-period=0 --namespace=kubeflow
Warning: Immediate deletion does not wait for confirmation that the running resource has been terminated. The resource may continue to run on the clust
er indefinitely.
pod "pt-job-1-worker-0" force deleted

kubectl describe pod -n kubeflow pt-job-1-worker-1
kubectl label nodes i-0194083c3e0e352e7.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=SchedulablePreferred
kubectl label nodes ip-192-168-212-8.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=Schedulable
kubectl get nodes ip-192-168-129-59.us-west-2.compute.internal --show-labels | grep Unschedulable
kubectl label nodes ip-192-168-252-176.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status- --overwrite
kubectl uncordon ip-192-168-129-59.us-west-2.compute.internal

# Delete pod
kubectl get pods -n kubeflow
kubectl delete pod $(kubectl get pods -l app=job-watcher -n kube-system -o jsonpath='{.items[0].metadata.name}')

kubectl delete pods -l $LABEL=$VALUE
kubectl delete pods --all

kubectl delete pod pt-test-job1-worker-0

# Check restart times
kubectl describe pytorchjob -n kubeflow pt-job-1
kubectl get pods -n kubeflow
kubectl describe pod -n kubeflow pt-job-1-worker-1
# Successfully assigned kubeflow/pt-job-1-worker-0 to ip-192-168-188-53.us-west-2.compute.internal

# check instance launch time
aws ec2 describe-instances --instance-ids i-02e074c0e7614876e --query "Reservations[].Instances[].LaunchTime" --output text
aws ec2 describe-instances \
  --filters "Name=instance-id,Values=i-02e074c0e7614876e" \
  --query 'Reservations[*].Instances[*].[InstanceId, LastRebootTime]'

aws ec2 describe-instances --output table --instance-id i-02e074c0e7614876e

# download and upload docker image
ada credentials update --account=321098965911 --provider=isengard --role=Admin --once
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 321098965911.dkr.ecr.us-east-2.amazonaws.com
docker pull 321098965911.dkr.ecr.us-east-2.amazonaws.com/probe:megatron-llm

ada credentials update --account=654654592687 --provider=isengard --role=Admin --once
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 654654592687.dkr.ecr.us-west-2.amazonaws.com
docker tag 321098965911.dkr.ecr.us-east-2.amazonaws.com/probe:megatron-llm 654654592687.dkr.ecr.us-west-2.amazonaws.com/probe:megatron-llm
docker push 654654592687.dkr.ecr.us-west-2.amazonaws.com/probe:megatron-llm

# scale tes
kubectl apply -f ./etcv2.yaml
sleep 5
kubectl apply -f ./megatron-lm.yaml

kubectl delete -f ./megatron-lm.yaml
kubectl delete -f ./etcv2.yaml


## Jump host
sudo apt install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

aws eks update-kubeconfig --region us-west-2 --name hyperpod-scaling-benchmark-eks-cluster-g5

curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.3/2024-04-19/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo cp ./kubectl /usr/sbin


# delete test job
kubectl delete pytorchjob pytorch-simple -n kubeflow

# create Hyperpod cluster
cd /workplace/xwnamz/HyperPodEKSTests/bin

SUBNET=$(cfn-output $VPC_STACK_NAME PrivateSubnet1)
SECURITY_GROUP=$(cfn-output $VPC_STACK_NAME NoIngressSecurityGroup)
EKS_CLUSTER_ARN=$(cfn-output $EKS_STACK_NAME ClusterArn)
EXECUTION_ROLE=$(cfn-output $SAGEMAKER_STACK_NAME ExecutionRole)
SERVICE_ROLE=$(cfn-output $SAGEMAKER_STACK_NAME ServiceRole)
BUCKET_NAME=$(cfn-output $SAGEMAKER_STACK_NAME Bucket)
HP_CLUSTER_NAME="hyperpod-eks-test-$(date +%s)"

aws sagemaker-dev --endpoint $ENDPOINT create-cluster \
    --cluster-name $HP_CLUSTER_NAME \
    --orchestrator 'Eks={ClusterArn='$EKS_CLUSTER_ARN'}' \
    --instance-groups '{
    "InstanceGroupName": "group1",
    "InstanceType": "ml.c5.2xlarge",
    "InstanceCount": 4,
    "LifeCycleConfig": {
        "SourceS3Uri": "s3://'$BUCKET_NAME'",
        "OnCreate": "on_create_noop.sh"
    },
    "ExecutionRole": "'$EXECUTION_ROLE'",
    "ThreadsPerCore": 1
}' --vpc-config '{
   "SecurityGroupIds": ["'$SECURITY_GROUP'"],
   "Subnets": ["'$SUBNET'"]
}'

aws sagemaker create-cluster \
    --endpoint $ENDPOINT \
    --cluster-name $HP_CLUSTER_NAME \
    --orchestrator 'Eks={ClusterArn='$EKS_CLUSTER_ARN'}' \
    --instance-groups '{
    "InstanceGroupName": "group1",
    "InstanceType": "ml.c5.4xlarge",
    "InstanceCount": 4,
    "LifeCycleConfig": {
        "SourceS3Uri": "s3://'$BUCKET_NAME'",
        "OnCreate": "on_create_noop.sh"
    },
    "ExecutionRole": "'$EXECUTION_ROLE'",
    "ThreadsPerCore": 1
}' --vpc-config '{
   "SecurityGroupIds": ["'$SECURITY_GROUP'"],
   "Subnets": ["'$SUBNET'"]
}'

# describe Hyperpod cluster
aws sagemaker-dev --endpoint $ENDPOINT describe-cluster --cluster-name $HP_CLUSTER_NAME
aws sagemaker --endpoint $ENDPOINT describe-cluster --cluster-name $HP_CLUSTER_NAME
aws sagemaker describe-cluster --cluster-name hyperpod-eks-test-1726982497
aws sagemaker-dev --endpoint $ENDPOINT describe-cluster --cluster-name arn:aws:sagemaker:us-west-2:891377004071:cluster/6v8fd6qwgdnv
aws sagemaker --endpoint $ENDPOINT describe-cluster --cluster-name arn:aws:sagemaker:us-west-2:891377004071:cluster/6v8fd6qwgdnv


# delete Hyperpod cluster
aws sagemaker --endpoint $ENDPOINT delete-cluster --cluster-name arn:aws:sagemaker:us-west-2:891377004071:cluster/jl12jfn14b1a
aws sagemaker-dev --endpoint $ENDPOINT delete-cluster --cluster-name arn:aws:sagemaker:us-west-2:891377004071:cluster/jl12jfn14b1a
aws sagemaker delete-cluster --cluster-name hyperpod-eks-test-1726982497
