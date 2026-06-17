variable "name" {
  description = "Name for the Kubernetes resources. Radius resolves this from a {{context.resource.name}} expression in the recipe."
  type        = string
}

variable "namespace" {
  description = "Namespace to deploy into. Radius resolves this from a {{context.runtime.kubernetes.namespace}} expression in the recipe."
  type        = string
}

variable "port" {
  description = "The Redis container/service port."
  type        = number
  default     = 6379
}
