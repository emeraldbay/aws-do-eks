variable "aws_region" {
  description = "AWS Region"
  type        = string
  # default     = "us-east-1"
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  # default     = "do-eks-tf"
  default     = "xin-test-cluster"
}

variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
  # default     = "1.25"
  default     = "1.31"
}

variable "cluster_enabled_log_types" {
  description = "EKS Cluster Control Plane Logging"
  type        = list(any)
  default     = ["api", "authenticator", "audit", "scheduler", "controllerManager"]
}
