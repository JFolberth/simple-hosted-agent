variable "resource_group_id" {
  type        = string
  description = "Resource ID of the resource group."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "name" {
  type        = string
  description = "Name of the Application Insights instance."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the Log Analytics workspace to back this instance."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply."
  default     = {}
}
