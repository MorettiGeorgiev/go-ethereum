variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "limechain-devnet-1"
}

variable "docker_image" {
  description = "Docker image to deploy"
  type        = string
}
