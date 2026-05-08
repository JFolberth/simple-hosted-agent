# simple-hosted-agent — Copilot Instructions

A minimal reference for deploying a Python AI agent to Azure AI Foundry Hosted Agents using the **Invocations protocol**. All infrastructure is managed with Bicep; no Azure Developer CLI (`azd`) is required.

---

## Architecture

| Layer | What it is |
|---|---|
| `src/agent-framework-agent-basic-invocations/` | Python agent built with Agent Framework + `InvocationAgentServerHost` |
| `infra/bicep/modules/foundry.bicep` | AI Services account, model deployments, account-level capability host |
| `infra/bicep/modules/foundry-project.bicep` | Foundry project, App Insights connection, Azure AI User role for project MI |
| `infra/bicep/modules/acr.bicep` | Container registry, AcrPull for project MI, ACR connection |
| `infra/bicep/modules/storage.bicep` | Blob storage, Storage Blob Data Contributor for project MI, storage connection |
| `deployment/deploy.sh` | Single-script deploy (Bicep): infra → image → agent |
| `deployment/deploy-terraform.sh` | Single-script deploy (Terraform): infra → image → agent |

The **Foundry data plane** (`POST {projectEndpoint}/agents/{name}/versions?api-version=2025-11-15-preview`) is used to create agent versions — NOT `az cognitiveservices agent create`, which calls a broken `containers/default:start` operation.

---

## Build & Deploy

```bash
# Full deploy (infra + image + agent)
./deployment/deploy.sh

# Code change only — skip Bicep
./deployment/deploy.sh --skip-infra
```

No `azd`, no `az cognitiveservices` extension. Prerequisites: `az login`, Docker daemon running.

---

## Key Conventions

### RBAC — roles required at infrastructure time
The project managed identity needs **these two** roles provisioned by IaC:

| Role | GUID | Scope | Grants |
|---|---|---|-|
| AcrPull | `7f951dda` | Container Registry | Image pull at container start |
| Storage Blob Data Contributor | `ba92f5b4` | Storage Account | Session thread state persistence |

### RBAC — role granted at deploy time (post-agent-version creation)
Foundry Agent Service creates a **per-version `instance_identity`** (a dedicated managed identity) for each hosted agent version. The container authenticates as this identity — **not** the project MI — when calling the model endpoint. This identity is only known after the agent version is created, so it cannot be pre-provisioned by IaC.

| Role | GUID | Scope | When |
|---|---|---|---|
| Azure AI User | `53ca6127` | AI Account | Step 7 of deploy script, after `az rest POST .../versions` |

The deploy scripts (`deployment/deploy.sh`, `deployment/deploy-terraform.sh`) parse `instance_identity.principal_id` from the version creation response and grant this role automatically (Step 7).

Missing Azure AI User on the instance identity → container starts but every model call gets `401 PermissionDenied`.

Note: the project MI also receives Azure AI User in `foundry-project.bicep` / the Terraform `foundry_project` module. This covers the project MI but **does not cover the instance identity**.

### Bicep scope
`main.bicep` is `targetScope = 'subscription'`; all modules are `targetScope = 'resourceGroup'`. Modules are called with `scope: rg`. Role assignment GUIDs are always deterministic: `guid(resourceGroup().id, <discriminator>, <roleGuid>)`.

### No project-level capability host
The **account-level** `capabilityHosts/agents` resource (in `foundry.bicep`) is sufficient. A project-level capability host causes `BadRequest: All connections must be provided`. Do not add one.

### Docker platform
Always build with `--platform linux/amd64`. Foundry runtime does not support arm64; building on Apple Silicon without this flag produces a platform mismatch error in the portal.

### Foundry data plane call
Required fields in the request body:
```json
{
  "metadata": {"enableVnextExperience": "true"},
  "definition": {
    "kind": "hosted",
    "container_protocol_versions": [{"protocol": "invocations", "version": "1.0.0"}],
    "image": "<acr>/<name>:<tag>",
    "cpu": "0.25",
    "memory": "0.5Gi",
    "environment_variables": {"AZURE_AI_MODEL_DEPLOYMENT_NAME": "<model>"}
  }
}
```
`metadata.enableVnextExperience: "true"` is a hard server-side requirement — omitting it causes a silent failure. Auth scope: `https://ai.azure.com/` (not `cognitiveservices.azure.com`).

### Invocations protocol
The agent uses `InvocationAgentServerHost` on port 8088. The `@app.invoke_handler` receives the raw `Request`; session ID comes from `request.state.session_id`. The in-memory `_sessions` store is intentionally simple — replace with Redis/Cosmos DB for production.

### Environment variables
The Foundry runtime injects these automatically at container start — do not set them manually in agent versions:
- `FOUNDRY_PROJECT_ENDPOINT`
- `APPLICATIONINSIGHTS_CONNECTION_STRING`

`AZURE_AI_MODEL_DEPLOYMENT_NAME` is NOT injected automatically — it must be set explicitly in the agent version request body and is present in `agent.yaml`.

---

## Infrastructure patterns to follow

- All resource names use `resourceToken = uniqueString(subscription().id, resourceGroup().id, location)` — never hardcode names.
- ACR connection uses `authType: ManagedIdentity`; storage connection uses `authType: AAD`. No stored keys anywhere.
- Model deployments run with `@batchSize(1)` to avoid capacity conflicts.
- New Bicep modules belong in `infra/bicep/modules/`; always add them to `infra/bicep/main.bicep` with a section comment block.

---

## What NOT to do

- Do not add a project-level `capabilityHosts` resource — see above.
- Do not use `az cognitiveservices agent create` — it calls a broken start operation for hosted agents.
- Do not build Docker images without `--platform linux/amd64` on Apple Silicon.
- Do not omit `metadata.enableVnextExperience: "true"` in agent version payloads.
- Do not add the `cognitiveservices` Azure CLI extension as a prerequisite — it is not used.
