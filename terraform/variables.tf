variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "lc-devnet"
}

variable "image_repo" {
  description = "Container image repository"
  type        = string
  default     = "967763122477.dkr.ecr.eu-central-1.amazonaws.com/limechain/devnet"
}

variable "image_tag" {
  description = "Container image tag"
  type        = string
  default     = "latest"
}

variable "namespace" {
  default = "default"
}

variable "app_name" {
  default = "lc-devnet-geth"
}

variable "replicas" {
  default = 1
}
