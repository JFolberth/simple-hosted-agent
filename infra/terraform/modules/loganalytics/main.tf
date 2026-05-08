resource "azapi_resource" "log_analytics" {
  type      = "Microsoft.OperationalInsights/workspaces@2025-07-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      retentionInDays = 30
      sku = {
        name = "PerGB2018"
      }
      features = {
        searchVersion = 1
      }
    }
  }
}
