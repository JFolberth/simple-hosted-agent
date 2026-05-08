output "account_id" {
  description = "Resource ID of the AI Services account."
  value       = azapi_resource.ai_account.id
}

output "ai_services_account_name" {
  description = "Name of the AI Services account."
  value       = azapi_resource.ai_account.name
}

output "openai_endpoint" {
  description = "OpenAI Language Model Instance API endpoint."
  # The endpoint key contains spaces; jsondecode(jsonencode(...)) converts the
  # dynamic azapi output to a plain map so bracket notation works correctly.
  value = jsondecode(jsonencode(azapi_resource.ai_account.output.properties.endpoints))["OpenAI Language Model Instance API"]
}
