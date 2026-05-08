# agent-framework-agent-basic-invocations

An [Agent Framework](https://github.com/microsoft/agent-framework) agent hosted using the **Invocations protocol** with session management.

Unlike the Responses protocol, the Invocations protocol does **not** provide built-in server-side conversation history — this agent maintains an in-memory session store keyed by `agent_session_id`. In production, replace it with durable storage (Redis, Cosmos DB, etc.) so history survives restarts.

For deployment instructions, prerequisites, and infrastructure details see the [root README](../../README.md).

## How It Works

### Model Integration

The agent uses `FoundryChatClient` from the Agent Framework to call the project endpoint and model deployment. When a request arrives, the handler looks up (or creates) a session by `session_id`, runs the agent with the user's `input`, and returns the reply. Both streaming (SSE) and non-streaming (JSON) response modes are supported.

### Agent Hosting

`InvocationAgentServerHost` from the [Azure AI AgentServer Invocations SDK](https://pypi.org/project/azure-ai-agentserver-invocations/) provisions the REST endpoint and handles the Invocations protocol contract (health checks, session headers, OpenTelemetry).

## Invoking the Agent

Send a POST request with a JSON body containing an `"input"` field:

```bash
curl -X POST http://localhost:8088/invocations -i \
  -H "Content-Type: application/json" \
  -d '{"input": "Hi!"}'
```

The response includes session headers you can use for multi-turn conversation:

```
HTTP/1.1 200
content-type: application/json
x-agent-session-id: 9370b9d4-cd13-4436-a57f-03b843ac0e17
x-agent-invocation-id: ec04d020-a0e7-441e-ae83-db75635a9f83

{"response":"Hi! How can I help?"}
```

### Multi-turn conversation

Pass the `agent_session_id` as a query parameter on subsequent requests:

```bash
curl -X POST "http://localhost:8088/invocations?agent_session_id=9370b9d4-cd13-4436-a57f-03b843ac0e17" -i \
  -H "Content-Type: application/json" \
  -d '{"input": "What did I just say?"}'
```

### Streaming

Add `"stream": true` to receive a Server-Sent Events response:

```bash
curl -X POST http://localhost:8088/invocations \
  -H "Content-Type: application/json" \
  -d '{"input": "Tell me a joke.", "stream": true}'
```
