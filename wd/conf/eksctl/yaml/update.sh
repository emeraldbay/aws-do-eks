#!/bin/bash
# install KTO
# https://github.com/kubeflow/training-operator
kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.7.0"

# create service role
kubectl create -f conf/eksctl/yaml/test_rbac.yaml
kubectl create -f conf/eksctl/yaml/test_rbac_iam.yaml     # with IAM binding
kubectl create -f conf/eksctl/yaml/test_rbac_iam_agi.yaml
kubectl create -f conf/eksctl/yaml/job-watcher-permision-from-helm.yaml
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

kubectl label nodes ip-192-168-196-253.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReplacement
kubectl label nodes ip-192-168-164-40.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=UnschedulablePendingReboot
kubectl label nodes hyperpod-i-077d281abaef65046 sagemaker.amazonaws.com/node-health-status- --overwrite

# "ip-192-168-154-218.us-west-2.compute.internal"
# force delete pod
kubectl delete pod pt-job-1-worker-0 --force --grace-period=0 --namespace=kubeflow
Warning: Immediate deletion does not wait for confirmation that the running resource has been terminated. The resource may continue to run on the clust
er indefinitely.
pod "pt-job-1-worker-0" force deleted

kubectl describe pod -n kubeflow pt-job-1-worker-1
kubectl label nodes ip-192-168-196-253.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=SchedulablePreferred
kubectl label nodes ip-192-168-212-8.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status=Schedulable
kubectl get nodes hyperpod-i-0f38d8a021f279074 --show-labels | grep Unschedulable
kubectl label nodes ip-192-168-196-253.us-west-2.compute.internal sagemaker.amazonaws.com/node-health-status- --overwrite
kubectl uncordon ip-192-168-129-59.us-west-2.compute.internal

# check node labels
kubectl get nodes hyperpod-i-032366fbbe49905d3 --show-labels | grep sagemaker.amazonaws.com

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
kubectl apply -f ./scale-etcv2.yaml
kubectl get services -n kubeflow
kubectl describe service etcd -n kubeflow
kubectl get pods -l app=etcd -n kubeflow
sleep 5
kubectl apply -f ./scale-megatron-lm.yaml
kubectl get pods -n kubeflow | grep Running | wc -l
kubectl get pods -n kubeflow | grep megatron-llm | grep Running | wc -l

kubectl describe pod -n kubeflow megatron-llm-worker-997



kubectl delete -f ./scale-megatron-lm.yaml
kubectl delete -f ./scale-etcv2.yaml

kubectl edit daemonset -n kube-system aws-node -o yaml
## then add
- name: MAX_ENI
  value: "1"
- name: MINIMUM_IP_TARGET
  value: "1"
- name: WARM_IP_TARGET
  value: "1"
- name: WARM_ENI_TARGET
  value: "0"
- name: WARM_PREFIX_TARGET
  value: "1"
# need to delete existing value for WARM_ENI_TARGET and WARM_PREFIX_TARGET

## Jump host
sudo apt install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

aws eks update-kubeconfig --region us-west-2 --name agi-hyperpod-eks-cluster


curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.3/2024-04-19/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo cp ./kubectl /usr/sbin


# delete test job
kubectl delete pytorchjob pytorch-simple -n kubeflow

# create Hyperpod cluster
cd HyperPodEKSTests/bin

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
# AGI
kubectl get pods -n obsidian
kubectl describe pod -n obsidian lev-470b-hyperpod-1512-3g5e-worker-1378
kubectl get nodes hyperpod-i-03571c4d67c2903eb --show-labels
kubectl get pods --field-selector=spec.nodeName=hyperpod-i-03571c4d67c2903eb --all-namespaces

kubectl get pods --field-selector=spec.nodeName=hyperpod-i-03571c4d67c2903eb --all-namespaces
NAMESPACE                   NAME                                                       READY   STATUS    RESTARTS      AGE
amazon-cloudwatch           cloudwatch-agent-grphf                                     1/1     Running   1 (13m ago)   25h
amazon-cloudwatch           dcgm-exporter-m7pmk                                        1/1     Running   1 (13m ago)   25h
amazon-cloudwatch           fluent-bit-pvkq2                                           1/1     Running   2 (12m ago)   25h
amazon-guardduty            aws-guardduty-agent-dpg84                                  1/1     Running   1 (13m ago)   25h
aws-efa-k8s-device-plugin   aws-efa-k8s-device-plugin-tpqwx                            1/1     Running   1 (13m ago)   25h
aws-for-fluent-bit          aws-for-fluent-bit-w6tk4                                   1/1     Running   2 (12m ago)   23h
aws-fsx-csi-driver          fsx-csi-node-wdn6k                                         3/3     Running   3 (13m ago)   25h
aws-hyperpod                hyperpod-ml-health-monitoring-agent-s474t                  1/1     Running   1 (13m ago)   25h
dcgm-exporter               dcgm-exporter-5jgq2                                        1/1     Running   0             10m
eks-pod-identity-agent      eks-pod-identity-agent-8nzbj                               1/1     Running   1 (13m ago)   25h
kube-system                 aws-node-fcpbt                                             2/2     Running   4 (11m ago)   25h
kube-system                 kube-proxy-qhhn8                                           1/1     Running   1 (13m ago)   25h
nvidia-device-plugin        nvidia-device-plugin-gpu-feature-discovery-zv7sb           1/1     Running   1 (13m ago)   25h
nvidia-device-plugin        nvidia-device-plugin-node-feature-discovery-worker-5bztf   1/1     Running   5 (13m ago)   25h
nvidia-device-plugin        nvidia-device-plugin-tsfbl                                 1/1     Running   1 (13m ago)   25h
prometheus                  kube-prometheus-stack-prometheus-node-exporter-gfs2j       1/1     Running   1 (13m ago)   25h


kubectl get pods -n obsidian | grep ^lev-470b-hyperpod-1512-3t38


# scale test
aws eks update-kubeconfig --region us-west-2 --name agi-hyperpod-eks-cluster
aws eks update-kubeconfig --region us-west-2 --name eks-scale-test-g5
kubectl config current-context

python3 -m venv /home/ubuntu/hyperpod-cli-venv                                                                          │
source /home/ubuntu/hyperpod-cli-venv/bin/activate

helm list
helm get all my-release
helm dependencies update helm_chart/HyperPodHelmChart
helm install dependencies helm_chart/HyperPodHelmChart --dry-run
helm install dependencies helm_chart/HyperPodHelmChart --namespace kube-system

# validate 
kubectl get namespaces
kubectl describe clusterrole job-auto-restart

# Create personal stack
# https://docs.aws.amazon.com/sagemaker/latest/dg/sagemaker-hyperpod-eks-operate-console-ui-create-cluster.html
export VPC_STACK_NAME=agi-hyperpod-vpc-stack
export SAGEMAKER_STACK_NAME=agi-hyperpod-sm-stack
export EKS_STACK_NAME=agi-hyperpod-eks-stack

# under HyperPodEKSTests/bin
export SUBNET1=$(./cfn-output $VPC_STACK_NAME PrivateSubnet1) && echo $SUBNET1
export SUBNET2=$(./cfn-output $VPC_STACK_NAME PrivateSubnet2) && echo $SUBNET2
export SUBNET3=$(./cfn-output $VPC_STACK_NAME PrivateSubnet3) && echo $SUBNET3
export SECURITY_GROUP=$(./cfn-output $VPC_STACK_NAME NoIngressSecurityGroup) && echo $SECURITY_GROUP

export SUBNET=$(./cfn-output $VPC_STACK_NAME PrivateSubnet2) && echo $SUBNET
export SECURITY_GROUP=$(./cfn-output $VPC_STACK_NAME NoIngressSecurityGroup) && echo $SECURITY_GROUP
export EKS_CLUSTER_ARN=$(./cfn-output $EKS_STACK_NAME ClusterArn) && echo $EKS_CLUSTER_ARN
export EXECUTION_ROLE=$(./cfn-output $SAGEMAKER_STACK_NAME ExecutionRole) && echo $EXECUTION_ROLE
export SERVICE_ROLE=$(./cfn-output $SAGEMAKER_STACK_NAME ServiceRole) && echo $SERVICE_ROLE
export BUCKET_NAME=$(./cfn-output $SAGEMAKER_STACK_NAME Bucket) && echo $BUCKET_NAME
export HP_CLUSTER_NAME="hyperpod-sacle-test-g5" && echo $HP_CLUSTER_NAME

aws eks update-kubeconfig --name $(cfn-output $EKS_STACK_NAME ClusterName)
kubectl create namespace aws-hyperpod

aws s3 cp lifecyclescripts/on_create_noop.sh s3://$BUCKET_NAME

aws sagemaker create-cluster --region us-west-2 \
    --cluster-name $HP_CLUSTER_NAME \
    --orchestrator '{"Eks": {"ClusterArn":"'$EKS_CLUSTER_ARN'"}}' \
    --instance-groups '{
        "InstanceGroupName": "compute-nodes-g5",
        "InstanceType": "ml.g5.8xlarge",
        "InstanceCount": 8,
        "LifeCycleConfig": {
            "SourceS3Uri": "s3://'$BUCKET_NAME'",
            "OnCreate": "on_create_noop.sh"
        },
        "ExecutionRole": "'$EXECUTION_ROLE'",
        "ThreadsPerCore": 1
    }' \
    --instance-groups '{
        "InstanceGroupName": "compute-nodes-t3",
        "InstanceType": "ml.t3.medium",
        "InstanceCount": 8,
        "LifeCycleConfig": {
            "SourceS3Uri": "s3://'$BUCKET_NAME'",
            "OnCreate": "on_create_noop.sh"
        },
        "ExecutionRole": "'$EXECUTION_ROLE'",
        "ThreadsPerCore": 1
    }' \
    --vpc-config '{
        "SecurityGroupIds": ["'$SECURITY_GROUP'"],
        "Subnets": ["'$SUBNET'"]
    }'

aws sagemaker update-cluster --region us-west-2 \
    --cluster-name $HP_CLUSTER_NAME \
    --instance-groups '{
        "InstanceGroupName": "compute-nodes",
        "InstanceType": "ml.g5.8xlarge",
        "InstanceCount": 1530,
        "LifeCycleConfig": {
            "SourceS3Uri": "s3://'$BUCKET_NAME'",
            "OnCreate": "on_create_noop.sh"
        },
        "ExecutionRole": "'$EXECUTION_ROLE'",
        "ThreadsPerCore": 1
    }'

aws sagemaker delete-cluster --region us-west-2 \
    --cluster-name $HP_CLUSTER_NAME

arn:aws:sagemaker:us-west-2:654654592687:cluster/qovn86muc8d6

# upgrade kubeflow training operator
# remove old version
kubectl delete -k "github.com/kubeflow/training-operator.git/manifests/overlays/standalone?ref=v1.7.0"
namespace "kubeflow" deleted
customresourcedefinition.apiextensions.k8s.io "mpijobs.kubeflow.org" deleted
customresourcedefinition.apiextensions.k8s.io "mxjobs.kubeflow.org" deleted
customresourcedefinition.apiextensions.k8s.io "paddlejobs.kubeflow.org" deleted
customresourcedefinition.apiextensions.k8s.io "pytorchjobs.kubeflow.org" deleted
customresourcedefinition.apiextensions.k8s.io "tfjobs.kubeflow.org" deleted
customresourcedefinition.apiextensions.k8s.io "xgboostjobs.kubeflow.org" deleted
serviceaccount "training-operator" deleted
clusterrole.rbac.authorization.k8s.io "training-operator" deleted
clusterrolebinding.rbac.authorization.k8s.io "training-operator" deleted
service "training-operator" deleted
deployment.apps "training-operator" deleted

# install the new version
kubectl apply --server-side -k "github.com/kubeflow/training-operator.git/manifests/overlays/standalone?ref=v1.8.1"
