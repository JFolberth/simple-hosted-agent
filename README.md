# Simple Hosted Agent

A minimal, production-ready reference for deploying a Python AI agent to [Microsoft Foundry Agent Service](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agents) using the **Invocations protocol**. Infrastructure is managed entirely with Bicep and deployed with a single shell script — no Azure Developer CLI (`azd`) required.

---

## Why Foundry Hosted Agents?

Foundry Hosted Agents are **not** the same as running a container on Azure Container Apps (ACA) or another self-managed compute service. The distinction matters:

| | Foundry Hosted Agent | Self-hosted (ACA, AKS, etc.) |
|---|---|---|
| **Infrastructure** | Per-session micro VMs (Microsoft-managed) | You provision, scale, and maintain |
| **Session isolation** | Each session gets a dedicated micro VM with persistent `$HOME` | Shared container instance; you manage state |
| **Agent identity** | Dedicated Microsoft Entra ID created automatically at deploy time | You create and bind a managed identity |
| **Scaling** | Scale-to-zero with automatic cold-start resume | You configure autoscale rules |
| **Toolbox** | Built-in access to Foundry tools (Code Interpreter, Web Search, MCP) via managed endpoint | Manual integration for each tool |
| **Observability** | Integrated with Application Insights; traces surfaced in Foundry portal | You wire up telemetry yourself |
| **Deployment** | Push a container image; platform provisions runtime | You manage container registry, ingress, and deployment rollout |

When you run a container on ACA, you own the runtime. When you deploy a hosted agent to Foundry, **you own only the agent logic**; the platform manages everything else. Use self-hosted compute when you have hard networking, compliance, or framework constraints that Foundry cannot satisfy. For everything else, hosted agents reduce operational overhead significantly.

See the official Microsoft documentation: [What are hosted agents?](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agents)

---

## What This Sample Deploys

### Agent

`src/agent-framework-agent-basic-invocations/` contains a Python agent built with the [Agent Framework](https://github.com/microsoft/agent-framework). It uses the **Invocations protocol** — the agent defines its own HTTP contract, manages its own session store, and formats streaming Server-Sent Events directly. This is the right choice when you need full control over the request/response shape.

> **Responses vs. Invocations**: The Responses protocol is the simpler starting point — the platform manages conversation history and streaming automatically, and any OpenAI-compatible SDK can talk to it. Invocations gives you complete HTTP control at the cost of managing sessions yourself. See the [protocol comparison](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agents#key-concepts) for guidance.

### Infrastructure

Six Bicep modules are deployed to a single resource group:

| Module | Resource | Why it's here | Hosted-agent-specific? |
|---|---|---|---|
| `foundry.bicep` | `Microsoft.CognitiveServices/accounts` (kind: `AIServices`) | AI Services account + model deployments + **account-level capability host** | Capability host only — the account itself is used by all Foundry project types |
| `foundry-project.bicep` | `Microsoft.CognitiveServices/accounts/projects` | Foundry project + App Insights connection + **Azure AI User** role for project MI on AI account | Project and App Insights connection are general purpose; **Azure AI User** role is hosted-agent-specific — it grants `Microsoft.CognitiveServices/*` data actions to the container's managed identity so it can call the model endpoint at runtime |
| `acr.bicep` | `Microsoft.ContainerRegistry/registries` | Container image registry + AcrPull role for project MI + ACR connection to the project | The registry itself is general purpose, but the **ACR connection registered on the Foundry project** is hosted-agent-specific — it is what tells Foundry Agent Service which registry to pull the container image from at runtime |
| `storage.bicep` | `Microsoft.Storage/storageAccounts` | Blob storage + Storage Blob Data Contributor for project MI + storage connection to the project | **Yes** — the account-level capability host discovers this connection to persist session thread state across the 15-minute idle timeout |
| `loganalytics.bicep` | `Microsoft.OperationalInsights/workspaces` | Log retention backend for Application Insights | No |
| `applicationinsights.bicep` | `Microsoft.Insights/components` | Distributed traces, metrics, and exceptions | No — prompt-based agents and evaluations also use it |

#### What makes this different from a standard Foundry project at the IaC level

A standard Foundry project (used for prompt-based agents, evaluations, or model calls) needs only the AI Services account and a project resource. Hosted agents require three additional things, all declared in this template:

1. **`capabilityHosts` on the account** (`foundry.bicep`) — registers the account with Foundry Agent Service and provisions the micro VM runtime layer. Without this, the account can serve model calls but cannot run hosted agents.

2. **An ACR connection on the project** (`acr.bicep`) — tells the micro VM runtime which container registry to pull images from. The registry itself is general purpose, but registering it as a connection on the Foundry project is specific to hosted agents. `authType: ManagedIdentity` means no stored credentials; the project managed identity (granted AcrPull on the registry) handles authentication.

3. **A storage connection on the project** (`storage.bicep`) — the account-level capability host discovers this connection automatically and uses it to persist agent session thread state (conversation history, in-flight tool calls) so sessions survive the idle timeout. `authType: AAD` uses the project managed identity (granted Storage Blob Data Contributor on the storage account).

4. **Azure AI User on the account for the project MI** (`foundry-project.bicep`) — the container running inside the hosted agent authenticates as the project managed identity. That identity must have `Microsoft.CognitiveServices/*` data actions on the AI account to call the model endpoint. Without this role the container receives a 401 `PermissionDenied` on its first model call.

See [Capability hosts](https://learn.microsoft.com/azure/foundry/agents/concepts/capability-hosts) for the full reference.

---

## Repository Structure

```
.
├── deployment/
│   ├── deploy.sh                      # Full deploy script (infra + image + agent) — Bicep
│   └── deploy-terraform.sh            # Full deploy script (infra + image + agent) — Terraform
├── infra/
│   ├── bicep/
│   │   ├── main.bicep                 # Subscription-scoped orchestrator
│   │   ├── main.bicepparam            # Parameter values — edit before deploying
│   │   ├── abbreviations.json         # Resource naming prefixes
│   │   └── modules/
│   │       ├── foundry.bicep          # AI Services account + model deployments + capability host
│   │       ├── foundry-project.bicep  # Foundry project + App Insights connection
│   │       ├── foundry-project-connection.bicep  # Reusable connection resource
│   │       ├── acr.bicep              # Container Registry + AcrPull role + ACR connection
│   │       ├── storage.bicep          # Storage account + Blob Contributor role + storage connection
│   │       ├── loganalytics.bicep     # Log Analytics workspace
│   │       └── applicationinsights.bicep  # Application Insights component
│   └── terraform/                     # Terraform (azapi) alternative — mirrors Bicep modules
└── src/
    └── agent-framework-agent-basic-invocations/
        ├── main.py                    # Agent implementation
        ├── agent.yaml                 # Foundry agent descriptor
        ├── Dockerfile                 # Container image definition
        └── requirements.txt           # Python dependencies
```

---

## Prerequisites

Regardless of whether you use the dev container or a local setup, you need:

- An **Azure subscription**
- The model you configure in `infra/bicep/main.bicepparam` available in your chosen region

### Required Azure permissions

`deployment/deploy.sh` performs these operations, each requiring different permissions on the identity running the script:

| Operation | What it does | Required role | Scope |
|---|---|---|---|
| `az deployment sub create` | Creates the resource group and all Azure resources | **Contributor** + **Role Based Access Control Administrator** | Subscription |
| `az role assignment create` | Grants Azure AI Project Manager at project scope | **Role Based Access Control Administrator** | Foundry project |
| `docker push` (via `az acr login`) | Pushes the container image to ACR | **AcrPush** or **Container Registry Repository Writer** | ACR resource |
| `az rest POST .../agents/{name}/versions` | Creates the hosted agent version via the Foundry data plane | **Azure AI Project Manager** | Foundry project |

> **Why assign at project scope explicitly, even with subscription-level access?**
> The Foundry data plane evaluates `Microsoft.CognitiveServices/accounts/AIServices/agents/write` at the scope of the Foundry **project** resource specifically. Subscription or resource group scoped role assignments are not reliably inherited by the Foundry data plane. The Microsoft docs state:
>
> > *"Azure AI Project Manager at the project scope is the recommended role assignment for agent creators, as that role includes both the required data plane permissions and the ability to assign the Azure AI User role."*
> > — [Hosted agent permissions reference — Agent creation](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agent-permissions#agent-creation)
>
> `deployment/deploy.sh` handles this automatically (Step 3) with an idempotent `az role assignment create` followed by a 30-second propagation wait, so you don't need to pre-configure it manually.

If your identity has **Owner** at subscription scope it satisfies the ARM operations. The project-scope data plane assignment is always made explicitly by the script regardless.

For a list of regions where hosted agents are available, see the [availability table](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agents#limits-pricing-and-availability-preview).

---

## Getting Started

### Option A — Dev Container (recommended)

The repository includes a [dev container](.devcontainer/devcontainer.json) that installs all tooling automatically. You need [VS Code](https://code.visualstudio.com/) and [Docker Desktop](https://www.docker.com/products/docker-desktop/) on your machine.

1. Clone the repository and open it in VS Code.
2. When prompted, click **Reopen in Container** (or run the **Dev Containers: Reopen in Container** command).
3. Wait for the container to build — it installs Azure CLI, Bicep, and Python dependencies automatically.
4. Inside the container, authenticate with Azure:
   ```bash
   az login
   ```

### Option B — Local Setup

Install the following tools on your machine:

| Tool | Version | Install |
|---|---|---|
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | Latest | `brew install azure-cli` / [Windows installer](https://aka.ms/installazurecliwindows) |
| [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) | Latest | `az bicep install` |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Latest | Platform installer |
| Python | 3.12 | [python.org](https://www.python.org/downloads/) |

Then authenticate:
```bash
az login
```

---

## Configuration

Before deploying, open `infra/bicep/main.bicepparam` and set values for your environment:

```bicep
param environmentName       = 'simple-hosted-agent'      // Used in resource naming
param resourceGroupName     = 'rg-simple-hosted-agent-dev'
param location              = 'swedencentral'             // Region for all resources
param aiDeploymentsLocation = 'swedencentral'             // Region for model deployments (can differ)
param aiFoundryProjectName  = 'ai-project'

param deployments = [
  {
    name: 'gpt-4.1-mini'
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1-mini'
      version: '2025-04-14'
    }
    sku: { name: 'Standard', capacity: 10 }
  }
]
```

**Choosing a region**: Not all models are available in every region. Run the following command to check what's available before deploying:

```bash
az cognitiveservices model list --location <region> \
  --query "[?name=='gpt-4.1-mini'].{version:version, lifecycleStatus:lifecycleStatus}" \
  --output table
```

Also update the top of `deployment/deploy.sh` to match:

```bash
ENVIRONMENT_NAME="simple-hosted-agent"   # Must match environmentName in main.bicepparam
LOCATION="swedencentral"                 # Must match location in main.bicepparam
```

---

## Deploying

`deployment/deploy.sh` performs the entire deployment in seven steps:

```bash
chmod +x deployment/deploy.sh
./deployment/deploy.sh
```

### What it does

**Step 1 — Deploy infrastructure**
Runs `az deployment sub create` against `infra/bicep/main.bicep`. This creates the resource group and all six Azure resources. On subsequent runs, Bicep is idempotent — only changed resources are updated.

**Step 2 — Read outputs**
Retrieves `az deployment sub show` output values: AI account name, project name, ACR endpoint, and model deployment name. These drive every subsequent step.

**Step 3 — Assign Azure AI Project Manager at project scope**
The Foundry data plane checks the `agents/write` permission at the Foundry **project** resource scope specifically — subscription-level assignments are not reliably inherited. This step runs `az role assignment create` (idempotent) scoped to the project resource ID, then waits 30 seconds for RBAC propagation.

**Step 4 — Authenticate to ACR**
Runs `az acr login` so Docker can push to the private registry.

**Step 5 — Build and push image**
Builds the Docker image from `src/agent-framework-agent-basic-invocations/` and tags it with the short Git commit hash. Tags are immutable — each commit produces a new image tag.

**Step 6 — Deploy the hosted agent**
POSTs to the Foundry data plane (`{projectEndpoint}/agents/{name}/versions?api-version=2025-11-15-preview`) via `az rest` with `--resource https://ai.azure.com/`. The request body specifies `kind: hosted`, the container image tag, CPU/memory, protocol (`invocations 1.0.0`), and the `AZURE_AI_MODEL_DEPLOYMENT_NAME` environment variable. The platform pulls the image, provisions a micro VM, and creates a dedicated Entra identity and endpoint for the agent. The Foundry runtime also injects `FOUNDRY_PROJECT_ENDPOINT` and `APPLICATIONINSIGHTS_CONNECTION_STRING` automatically. The management-plane CLI (`az cognitiveservices agent create`) is **not** used — it calls a separate start operation that returns 404 for hosted agents.

### Skipping infrastructure on subsequent deployments

If you only changed agent code (not infra), skip the Bicep step:

```bash
./deployment/deploy.sh --skip-infra
```

---

## Testing the Agent

After deployment, the agent is accessible through its Foundry endpoint. Open the [Foundry portal](https://ai.azure.com), navigate to your project, and select the agent to open the playground.

You can also call it directly using `curl`. The Invocations endpoint accepts arbitrary JSON:

```bash
# Non-streaming
curl -X POST \
  "<project_endpoint>/agents/agent-framework-agent-basic-invocations/endpoint/protocols/invocations" \
  -H "Authorization: Bearer $(az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv)" \
  -H "Content-Type: application/json" \
  -d '{"input": "Hi!"}'
```

For multi-turn conversation, capture the `x-agent-session-id` header from the first response and pass it as a query parameter:

```bash
curl -X POST \
  "<project_endpoint>/agents/agent-framework-agent-basic-invocations/endpoint/protocols/invocations?agent_session_id=<session_id>" \
  -H "Authorization: Bearer $(az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv)" \
  -H "Content-Type: application/json" \
  -d '{"input": "What did I just say?"}'
```

> The session store in `main.py` is in-memory and is lost on container restart. For production, replace it with a durable store such as Azure Cosmos DB or Redis.

---

## Running the Agent Locally

For iterating on agent logic without a full cloud deployment:

1. Create a `.env` file in `src/agent-framework-agent-basic-invocations/`:
   ```
   FOUNDRY_PROJECT_ENDPOINT=https://<your-project>.services.ai.azure.com/api/projects/<project>
   AZURE_AI_MODEL_DEPLOYMENT_NAME=gpt-4.1-mini
   ```

2. Install dependencies:
   ```bash
   pip install -r src/agent-framework-agent-basic-invocations/requirements.txt
   ```

3. Run the agent:
   ```bash
   python src/agent-framework-agent-basic-invocations/main.py
   ```

4. Test it:
   ```bash
   curl -X POST http://localhost:8088/invocations \
     -H "Content-Type: application/json" \
     -d '{"input": "Hi!"}'
   ```

You will need an existing Foundry project and model deployment. The `FOUNDRY_PROJECT_ENDPOINT` and model deployment name can be found in the Foundry portal under your project's overview page.

---

## Cleaning Up

To delete all provisioned Azure resources:

```bash
az group delete --name rg-simple-hosted-agent-dev --yes
az deployment sub delete --name deploy-simple-hosted-agent
```

---

## Further Reading

- [What are hosted agents?](https://learn.microsoft.com/azure/foundry/agents/concepts/hosted-agents) — platform concepts, session model, and protocol comparison
- [Capability hosts](https://learn.microsoft.com/azure/foundry/agents/concepts/capability-hosts) — how the account-level capability host enables the agent runtime
- [Deploy a hosted agent](https://learn.microsoft.com/azure/foundry/agents/how-to/deploy-hosted-agent) — full deployment lifecycle reference
- [Agent Framework — Foundry Hosted Agents (Python)](https://learn.microsoft.com/agent-framework/hosting/foundry-hosted-agent) — Agent Framework hosting integration
- [Azure AI Foundry documentation](https://learn.microsoft.com/azure/foundry/) — broader platform documentation
