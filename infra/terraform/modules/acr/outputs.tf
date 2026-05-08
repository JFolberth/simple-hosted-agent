output "registry_name" {
  description = "Name of the container registry."
  value       = azapi_resource.container_registry.name
}

output "login_server" {
  description = "Login server hostname for the container registry."
  value       = azapi_resource.container_registry.output.properties.loginServer
}

output "registry_id" {
  description = "Resource ID of the container registry."
  value       = azapi_resource.container_registry.id
}

output "connection_name" {
  description = "Name of the ACR connection on the Foundry project."
  value       = module.acr_connection.connection_name
}
