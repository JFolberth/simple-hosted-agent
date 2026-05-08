output "id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azapi_resource.log_analytics.id
}

output "name" {
  description = "Name of the Log Analytics workspace."
  value       = azapi_resource.log_analytics.name
}
