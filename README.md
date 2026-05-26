# BST — Budget Space Tourism
### *The Booking.com of commercial space travel.*

A field-ready **AgentGateway + AgentRegistry** demo. Clean slate. Laptop-runnable.

---

## What This Is

BST aggregates commercial space travel availability across SpaceX and NASA. They find the best deal, handle the booking, and manage the customer relationship — but they never leave the ground themselves.

The scenario is deliberately industry-agnostic. The business model is universally understood. The platform behavior is the story.

---

## What This Demonstrates

| Capability | Product |
|---|---|
| JWT-validated API ingress | AgentGateway |
| LLM provider routing and abstraction | AgentGateway |
| Credential brokering to external services | AgentGateway (onBehalfOf) |
| North/south and east/west policy enforcement | AgentGateway |
| Governed external MCP catalog | AgentRegistry |
| Governed internal MCP catalog | AgentRegistry |
| Internal developer and agent identity | Keycloak |

---

## Prerequisites

- Docker + Docker Compose
- Kind or OrbStack
- kubectl
- A live LLM provider API key (OpenAI, Anthropic, etc.)

---

## Setup

```bash
# Terminal 1 — external services (outside k8s)
docker compose -f external-services/docker-compose.yaml up

# Terminal 2 — k8s cluster
kind create cluster --config k8s/kind-config.yaml
kubectl apply -f k8s/
```

**OrbStack users:** same docker-compose, same manifests. Networking is handled natively.

---

## Air-Gapped / No WiFi Mode

1. Uncomment the Ollama service in `external-services/docker-compose.yaml`
2. Add Ollama as an upstream in `k8s/gateway/agentgateway.yaml`
3. `docker compose up` — pull the model before the demo, not during it
4. That's it.

---

## Repo Structure

```
bst-demo/
├── README.md
├── docs/
│   └── BST-demo-brief.md        # Start here if you want to understand the why
├── k8s/
│   ├── agents/
│   ├── gateway/
│   ├── registry/
│   ├── crm/
│   └── keycloak/
├── external-services/
│   ├── docker-compose.yaml
│   ├── nasa/
│   └── spacex/
├── agents/
│   ├── scheduling/
│   └── booking/
├── crm/
│   └── data/
└── demo/
    └── requests/                # Start here if you want to run the demo
```

---

## The Demo

Full demo script, curl commands, and SE talking points are in `demo/requests/`.

---

*Internal SE enablement project. Not for external distribution.*