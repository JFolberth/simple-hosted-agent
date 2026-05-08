output "storage_account_name" {
  description = "Name of the storage account."
  value       = azapi_resource.storage_account.name
}

output "storage_account_id" {
  description = "Resource ID of the storage account."
  value       = azapi_resource.storage_account.id
}

output "connection_name" {
  description = "Name of the storage connection on the Foundry project."
  value       = module.storage_connection.connection_name
}
