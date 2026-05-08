variable "resource_group_id" {
  type        = string
  description = "Resource ID of the resource group."
}

variable "location" {
  type        = string
  description = "Azure region for the workspace."
}

variable "name" {
  type        = string
  description = "Name of the Log Analytics workspace."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the workspace."
  default     = {}
}
