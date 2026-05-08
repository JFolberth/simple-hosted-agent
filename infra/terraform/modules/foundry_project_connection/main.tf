resource "azapi_resource" "connection" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2026-03-01"
  name      = var.connection_config.name
  parent_id = var.project_id

  # Schema validation disabled — api-version 2026-03-01 is not yet bundled.
  schema_validation_enabled = false

  # ignore_missing_property: don't fail plan when the API returns system-managed
  #   properties that aren't in our config (common for connection resources).
  # ignore_null_property: omit null fields (e.g. credentials when auth is AAD).
  ignore_missing_property = true
  ignore_null_property    = true

  body = {
    properties = {
      category      = var.connection_config.category
      target        = var.connection_config.target
      authType      = var.connection_config.auth_type
      isSharedToAll = var.connection_config.is_shared_to_all
      metadata      = var.connection_config.metadata
      credentials   = var.credentials
    }
  }
}
