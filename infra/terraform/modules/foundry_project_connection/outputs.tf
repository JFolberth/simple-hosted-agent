output "connection_name" {
  description = "Name of the connection resource."
  value       = azapi_resource.connection.name
}

output "connection_id" {
  description = "Resource ID of the connection."
  value       = azapi_resource.connection.id
}
