variable "prefix" {
  description = "Prefix for all resource names."
  type        = string
  default     = "ugrant"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westus2"
}

variable "node_count" {
  description = "AKS node count"
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "AKS node VM size"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version"
  type        = string
  default     = "1.32.7"
}
