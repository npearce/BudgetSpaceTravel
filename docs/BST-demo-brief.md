# BST — Budget Space Tourism
## SE Demo Project Brief

> *The Booking.com of commercial space travel.*
> *A field-ready AgentGateway + AgentRegistry demo. Clean slate. Laptop-runnable. Deliverable in a week.*

---

## The Scenario

**BST (Budget Space Tourism)** aggregates commercial space travel availability across SpaceX and NASA. Think Booking.com — for space travel. BST doesn't fly anyone anywhere. They find the best deal, handle the booking, and manage the customer relationship across providers they don't control and data they don't own.

The scenario is deliberately industry-agnostic. Nobody in the room works in commercial space travel, so the scenario disappears and the platform behavior comes forward. The business model is universally understood — everyone knows how Booking.com works.

---

## The Goal

A lightweight, laptop-runnable demo that lets any SE tell the AgentGateway and AgentRegistry story fluently, in a VS Code IDE, against the BST scenario.

**Definition of done:**
- An SE who has never seen it before can learn it in a day
- They can deliver it confidently after a week
- It tells the developer story and the platform/security story from the same demo
- It never requires an apology ("sorry, that usually works")

---

## The Two Stories — One Demo

The demo tells two stories simultaneously, to two different buyers in the same room.

| Audience | What they see | What they think |
|---|---|---|
| Agent Developer / AI Engineer | Clean API surface, provider abstraction, no credential management, fast iteration | *I could build that* |
| Platform Engineer / Security Lead | Governed tool surface, policy enforcement, attributed traffic, no token sprawl | *I could control that* |

Same demo. Same five beats. Two lenses.

---

## The Narrative Arc — Five Beats

### Beat 1 — Ingress: The API Surface
A chat message hits the BST API. AgentGateway owns the ingress — JWT-validated, rate-limited, observable. This is the entry point the web team calls. They don't know or care what's behind it.

*Developer sees:* a clean API they'd actually want to consume.
*Platform lead sees:* a governed, authenticated entry point they'd actually want to provide.
*Defeats:* the "egress-only" perception of competitors. AgentGateway governs both directions.

### Beat 2 — LLM Routing: Provider Abstraction
The agent calls an LLM. AgentGateway routes it — provider abstraction, cost attribution, rate limits visible. Swap providers without recoding. Fall back automatically. A/B test models.

*Developer sees:* write once, run against any provider.
*Platform lead sees:* every LLM call attributed to an identity, governed, cost-visible.
*Defeats:* LLM provider lock-in.

### Beat 3 — External MCPs: Credential Brokering
The scheduling agent calls external providers — NASA (launch windows and weather/meteorological conditions) and SpaceX (vehicle availability and pricing). AgentGateway handles each call `onBehalfOf` the agent. The API key lives in the gateway, not in the agent, not in the developer's config.

AgentRegistry governs the surface — approved providers only, approved functions only. NASA exposes several functions; the registry makes only the approved subset available to this agent.

*Developer sees:* I never touch a credential. I just call what the registry says I can call.
*Security lead sees:* one credentialed caller, full attribution, no token sprawl across the team.
*Defeats:* token sprawl and ungoverned external MCP surface.

### Beat 4 — Internal MCP: The Data Shortcut
The booking agent calls the internal CRM — a shortcut to the customer record, travel history, tier, and existing bookings. Governed by AgentRegistry. No direct system access. No shadow integrations.

*Developer sees:* fast, clean access to internal data without owning the system.
*Platform lead sees:* internal tool surface is as governed as the external one.
*Defeats:* internal MCP sprawl.

### Beat 5 — Policy Across the Whole Flow
One policy layer. North/south on LLM calls and external MCP traffic. East/west between agents and internal services. Not per-product configuration — structural enforcement across the entire runtime.

*Developer sees:* it just works within the approved boundaries.
*Security lead sees:* one place to define, enforce, and audit policy across everything.
*Defeats:* governance as an afterthought.

---

## The Response

The streaming response synthesizes across sources — visibly. The customer watches it arrive token by token through AgentGateway and can see the stitching:

> *"Based on current launch availability from SpaceX (3 windows in Q2), weather constraints from NASA indicating favorable conditions March 15–18, SpaceX pricing tiers for the requested configuration, and your customer's existing Gold tier status in our CRM, the optimal booking window is..."*

Multiple MCPs. Multiple sources. One governed, attributed, streaming response. That's both the demo and the proof.

---

## Architecture

### Inside k8s
| Component | Role |
|---|---|
| Scheduling Agent | Queries external providers for launch windows and conditions |
| Booking Agent | Manages customer records and confirms reservations via CRM |
| AgentGateway | Ingress (JWT-validated API surface) + Egress (LLM routing, onBehalfOf, policy) |
| AgentRegistry | Governed catalog — approved providers and functions for both agents |
| CRM Service | Internal system of record, JSON-backed |
| CRM MCP Server | AgentRegistry-governed interface in front of the CRM |
| Keycloak | Identity provider for all internal workloads — agents, services, demo client |

### Outside k8s (External Service Containers)
| Container | Data |
|---|---|
| NASA MCP Server | Launch windows, weather and meteorological conditions, JSON-backed |
| SpaceX MCP Server | Vehicle availability and pricing, JSON-backed |

Each external container is a lightweight MCP server in front of a JSON document. Small, stable, fully controlled. No external dependencies. No live APIs that can break mid-demo. Brought up with a single `docker compose up`.

### LLM
Live LLM provider(s) via AgentGateway egress. Real provider routing. Real provider abstraction story.

### Demo Client
VS Code IDE. curl or simple API client hitting the AgentGateway ingress endpoint. Streaming response visible in the terminal.

---

## Auth Model

### Internal Identity (Keycloak)
Every identity in the system has a Keycloak-issued token — the SE acting as a developer, the demo client, the scheduling agent, the booking agent. AgentGateway validates on every call. This is what makes traffic attribution and cost governance possible. Without identity, you can't answer "which developer or agent consumed which tokens."

Developer auth is a Keycloak realm/client config on the same instance — nothing additional to stand up. One identity provider, all identities covered.

### External Credentials (onBehalfOf)
Static API keys for each external MCP container, stored securely in AgentGateway. The agent never sees a credential. The developer never touches one. AgentGateway brokers every outbound call and attributes it back through the identity chain.

---

## North/South vs East/West

| Traffic | Direction | Governed By |
|---|---|---|
| Chat client → AgentGateway | North/South (ingress) | AgentGateway + Keycloak JWT |
| AgentGateway → LLM providers | North/South (egress) | AgentGateway policy |
| AgentGateway → External MCPs | North/South (egress) | AgentGateway onBehalfOf + AgentRegistry |
| Scheduling Agent → Booking Agent | East/West (A2A) | AgentGateway identity chain |
| Booking Agent → CRM MCP | East/West (internal) | AgentRegistry |

---

## What This Demo Is Not

- It is not a frontend web application
- It is not a complex multi-service platform (that's AMSS)
- It is not bound to any industry vertical
- It is not a v0.2 with Kagent (that decision belongs to the CRO, not the roadmap)

---

## Scope Guardrails

**In scope for v0.1:**
AgentGateway + AgentRegistry story. Five beats. BST scenario. Laptop-runnable. Field-ready.

**Documented but not built:**
Ollama local model fallback for air-gapped scenarios. One config swap, SE narrates the provider story, everything else runs identically.

**Not in scope until there is a commercial reason:**
Kagent. A new SKU requires field evidence, a CRO conversation, and a business case — not a product roadmap assumption.

---

## Relationship to AMSS

AMSS lives on as the home lab environment — always running, complex, evolving, for advanced concepts, recorded demonstrations, and proof-of-concept work requiring real depth.

BST is a clean slate. New repo. No AMSS dependencies. Self-contained. The knowledge and lessons learned from building AMSS transfer. The code does not.

---

## The One-Sentence Pitch

*"BST is the Booking.com of commercial space travel — and their entire agent platform runs on AgentGateway and AgentRegistry."*

---

*Internal planning document. Not for external distribution.*

---

## Repo Structure

```
bst-demo/
├── README.md                    # The only doc an SE needs to get running
├── docs/
│   └── BST-demo-brief.md        # This brief
├── k8s/
│   ├── agents/
│   │   ├── scheduling-agent.yaml
│   │   └── booking-agent.yaml
│   ├── gateway/
│   │   └── agentgateway.yaml
│   ├── registry/
│   │   └── agentregistry.yaml
│   ├── crm/
│   │   ├── crm-service.yaml
│   │   └── crm-mcp.yaml
│   └── keycloak/
│       └── keycloak.yaml
├── external-services/
│   ├── docker-compose.yaml      # One command brings up both external MCPs
│   ├── nasa/                    # Launch windows + weather/meteorological conditions
│   └── spacex/                  # Vehicle availability + pricing
├── agents/
│   ├── scheduling/
│   └── booking/
├── crm/
│   └── data/
└── demo/
    └── requests/                # curl commands, demo script, SE talking points
```

### SE Setup — Two Commands

```bash
# Terminal 1 — external services (outside k8s)
docker compose -f external-services/docker-compose.yaml up

# Terminal 2 — k8s cluster
kind create cluster --config k8s/kind-config.yaml
kubectl apply -f k8s/
```

**OrbStack users:** same docker-compose, same manifests. Networking is handled natively.
