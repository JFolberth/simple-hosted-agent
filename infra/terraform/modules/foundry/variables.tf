variable "resource_group_id" {
  type        = string
  description = "Resource ID of the resource group."
}

variable "location" {
  type        = string
  description = "Azure region for the AI Services account."
}

variable "resource_token" {
  type        = string
  description = "Unique token for deterministic resource naming (passed from root module)."
}

variable "deployments" {
  type = list(object({
    name = string
    model = object({
      name    = string
      format  = string
      version = string
    })
    sku = object({
      name     = string
      capacity = number
    })
  }))
  description = "Model deployments to create on the account."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
