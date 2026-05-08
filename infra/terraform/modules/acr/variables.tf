variable "resource_group_id" {
  type        = string
  description = "Resource ID of the resource group."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "resource_name" {
  type        = string
  description = "Name of the container registry."
}

variable "connection_name" {
  type        = string
  description = "Name for the AI Foundry ACR connection."
}

variable "project_id" {
  type        = string
  description = "Resource ID of the AI Foundry project."
}

variable "project_principal_id" {
  type        = string
  description = "Principal ID of the project managed identity."
}

variable "ai_project_name" {
  type        = string
  description = "Name of the AI Foundry project (used in deterministic role assignment naming)."
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID, used when constructing role definition resource IDs."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply."
  default     = {}
}
