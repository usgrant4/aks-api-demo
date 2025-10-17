variable "prefix" {
  description = "Prefix for all resource names (letters, numbers, hyphens)."
  type        = string
  default     = "ugrant"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "node_count" {
  description = "AKS node count"
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "AKS node VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version (optional)"
  type        = string
  default     = "1.29.7"
}
