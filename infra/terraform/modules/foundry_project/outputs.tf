output "project_endpoint" {
  description = "AI Foundry data-plane endpoint for the project."
  # The endpoint key contains spaces; jsondecode(jsonencode(...)) converts the
  # dynamic azapi output to a plain map so bracket notation works correctly.
  value = jsondecode(jsonencode(azapi_resource.project.output.properties.endpoints))["AI Foundry API"]
}

output "project_id" {
  description = "Resource ID of the AI Foundry project."
  value       = azapi_resource.project.id
}

output "project_name" {
  description = "Name of the AI Foundry project."
  value       = azapi_resource.project.name
}

output "project_principal_id" {
  description = "Principal ID of the project's system-assigned managed identity."
  value       = azapi_resource.project.identity[0].principal_id
}
