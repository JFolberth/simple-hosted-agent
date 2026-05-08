variable "resource_group_id" {
  type        = string
  description = "Resource ID of the resource group."
}

variable "location" {
  type        = string
  description = "Azure region for the project."
}

variable "resource_token" {
  type        = string
  description = "Unique token for deterministic resource naming (passed from root module)."
}

variable "ai_foundry_project_name" {
  type        = string
  description = "Name of the AI Foundry project."
}

variable "ai_account_id" {
  type        = string
  description = "Resource ID of the parent AI Services account."
}

variable "app_insights_id" {
  type        = string
  description = "Resource ID of the Application Insights instance. Pass empty string to skip."
  default     = ""
}

variable "app_insights_connection_string" {
  type        = string
  description = "Connection string for App Insights. Pass empty string to skip."
  sensitive   = true
  default     = ""
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
