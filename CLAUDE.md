# CLAUDE.md — BST Demo Project Context

This file provides persistent context for Claude Code. Read it before making any changes to this repository.

---

## What This Is

**BST (Budget Space Tourism)** is a field-ready SE demo for Solo.io's AgentGateway and AgentRegistry products. Think Booking.com for commercial space travel — BST aggregates launch availability across SpaceX and NASA, handles bookings, and manages customer relationships across providers they don't control and data they don't own.

The scenario is deliberately industry-agnostic. Nobody in the room works in commercial space travel. The scenario disappears and the platform behavior comes forward.

**This is not a complex platform demo. It is a teaching instrument.**

---

## The Two Audiences — Always In Mind

Every component, every config, every line of code serves two stories simultaneously:

| Audience | What they see | What they think |
|---|---|---|
| Agent Developer / AI Engineer | Clean API surface, provider abstraction, no credential management | *I could build that* |
| Platform Engineer / Security Lead | Governed tool surface, policy enforcement, attributed traffic, no token sprawl | *I could control that* |

When in doubt, ask: does this make the platform behavior more visible? If not, simplify it.

---

## Product Scope — v0.1

**In scope:**
- AgentGateway — ingress (JWT-validated API surface) and egress (LLM routing, onBehalfOf credential brokering, north/south and east/west policy enforcement)
- AgentRegistry — governed catalog of approved providers and functions for both agents

**Explicitly not in scope for v0.1:**
- Kagent — requires a CRO conversation and a new SKU before it earns a place in this demo
- Any frontend web application
- Any external live APIs — all external data is JSON-backed and fully controlled

Do not add complexity that isn't on this list. The simplest thing that tells the story is always the right answer.

---

## The Five Beats

The demo tells its story in five beats. Every component exists to serve one or more of these beats:

1. **Ingress** — A chat message hits the BST API. AgentGateway owns the ingress. JWT-validated, rate-limited, observable. *Defeats: egress-only perception of competitors.*

2. **LLM Routing** — The agent calls an LLM. AgentGateway routes it. Provider abstraction, cost attribution, rate limits visible. *Defeats: LLM provider lock-in.*

3. **External MCPs** — The scheduling agent calls NASA and SpaceX via AgentGateway `onBehalfOf`. Credentials live in the gateway, not in the agent. AgentRegistry governs which functions are reachable. *Defeats: token sprawl and ungoverned external MCP surface.*

4. **Internal MCP** — The booking agent calls the CRM MCP. Fast path to internal data. Governed by AgentRegistry. *Defeats: internal MCP sprawl.*

5. **Policy** — One policy layer across north/south and east/west traffic. Structural enforcement, not per-product configuration. *Defeats: governance as an afterthought.*

---

## Architecture

### Inside k8s
| Component | Role |
|---|---|
| Scheduling Agent | Queries external providers for launch windows and conditions |
| Booking Agent | Manages customer records and confirms reservations via CRM |
| AgentGateway | Ingress + Egress — LLM routing, onBehalfOf, policy |
| AgentRegistry | Governed catalog for both agents |
| CRM Service | Internal system of record, JSON-backed |
| CRM MCP Server | AgentRegistry-governed interface in front of the CRM |
| Keycloak | Identity provider for all internal workloads and the demo client |

### Outside k8s (docker-compose)
| Container | Functions |
|---|---|
| NASA MCP Server | `get_launch_windows`, `get_weather_conditions`, `get_launch_site_status`, `get_range_safety_status`, `get_cafeteria_menu` (blocked by AgentRegistry — this is the governance demo moment) |
| SpaceX MCP Server | Vehicle availability, pricing, and booking functions |

### LLM
Live LLM provider(s) via AgentGateway egress. Real provider routing story.

### Demo Client
VS Code IDE. curl hitting the AgentGateway ingress endpoint. Streaming response visible in the terminal, visibly synthesizing across multiple MCP sources.

---

## Auth Model

### Internal Identity
Keycloak issues tokens for every identity in the system — the SE acting as a developer, the scheduling agent, the booking agent, the demo client. AgentGateway validates on every call. This is what makes cost attribution and audit possible.

### External Credentials
Static API keys per external MCP container, stored in AgentGateway. Brokered via `onBehalfOf` on every outbound call. The agent never sees a credential. The developer never touches one.

---

## Technology Choices

| Concern | Choice | Why |
|---|---|---|
| External MCP servers | Python + FastMCP | Most popular real-world choice, minimal boilerplate, readable by any SE |
| Container orchestration | Kind (primary), OrbStack (supported) | Laptop-runnable, both supported, same manifests |
| External service orchestration | Docker Compose | One command, networking declared, SE-proof |
| Internal identity | Keycloak | Already proven in AMSS, no external dependencies |
| k8s manifests | Plain kubectl manifests | Simple, no Helm complexity for a demo |
| Demo client | curl in VS Code terminal | Developer-native, transparent, no UI to maintain |

### FastMCP Version
**FastMCP 3.3.1 is the tested and confirmed working version.** Do not upgrade without testing — breaking changes exist between 2.x and 3.x. Both external MCP servers run as persistent HTTP servers using the FastMCP 3.x transport API (`mcp.run(transport="http", host="0.0.0.0", port=8000)`). The authlib deprecation warning on startup is harmless — do not attempt to fix it.

### Air-Gapped Fallback (documented, not built for v0.1)
Uncomment Ollama in `docker-compose.yaml` and add as AgentGateway upstream. Two changes. Everything else identical. Do this before the demo, not during it.

---

## External MCP Server Pattern

Every external MCP server follows the same pattern:

```
external-services/
└── <provider>/
    ├── Dockerfile
    ├── server.py          # FastMCP server — the only interesting file
    ├── data.json          # The JSON document behind the MCP
    └── requirements.txt
```

**The data is fake but believable.** Launch windows have real-looking dates. Weather has real-looking conditions. Pricing has real-looking tiers. Nobody should question the data — all attention goes to the platform behavior.

**Functions are deliberately numerous.** Each MCP server exposes more functions than AgentRegistry allows the agent to call. This is intentional — it's how we demonstrate the governance story.

---

## Networking

External MCP containers and the Kind cluster share a Docker bridge network declared in `docker-compose.yaml`:

```yaml
networks:
  bst-external:
    name: bst-external
    driver: bridge
```

Kind is configured at cluster creation to connect to `bst-external`. AgentGateway reaches external MCP containers by service name. This keeps the demo entirely off the host network and guest-WiFi-proof.

OrbStack handles this natively — same compose file, same manifests.

---

## Repo Structure

```
bst-demo/
├── CLAUDE.md                    # This file
├── README.md                    # The only doc an SE needs to get running
├── docs/
│   └── BST-demo-brief.md        # Full project brief and design decisions
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
│   ├── docker-compose.yaml
│   ├── nasa/
│   └── spacex/
├── agents/
│   ├── scheduling/
│   └── booking/
├── crm/
│   └── data/
└── demo/
    └── requests/
```

---

## Build Order

Build in this order. Each step is independently testable before the next begins.

1. ✅ Repo scaffold — README, CLAUDE.md, brief in docs/
2. NASA MCP server — FastMCP + JSON, proves the external MCP pattern
3. SpaceX MCP server — same pattern, second provider
4. Docker Compose + networking — wrap both MCPs, validate Kind bridge
5. Keycloak — internal identity before agents need it
6. AgentGateway — ingress, LLM routing, onBehalfOf config
7. AgentRegistry — catalog config, function scoping for both external MCPs
8. CRM service + CRM MCP — internal data shortcut
9. Scheduling agent — talks to external MCPs via AgentGateway
10. Booking agent — talks to CRM MCP
11. Demo script + curl requests — the SE's actual demo experience

---

## Definition of Done

- An SE who has never seen it before can learn it in a day
- They can deliver it confidently after a week
- It tells the developer story and the platform/security story from the same demo
- It never requires an apology ("sorry, that usually works")

---

## What To Never Do

- Don't add a frontend web application
- Don't add Kagent — that's a CRO decision, not a build decision
- Don't use live external APIs — everything is JSON-backed and controlled
- Don't add Blue Origin or additional external providers — NASA and SpaceX are enough
- Don't over-engineer for the edge case — build for online first, document the Ollama fallback
- Don't add complexity that doesn't serve one of the five beats

---

## The Governance Demo Moment

The NASA MCP server exposes five functions. AgentRegistry makes four available to the scheduling agent. The fifth — `get_cafeteria_menu` — is blocked.

This is the moment in the demo where the governance story lands. Keep it. Don't accidentally make it available.

---

## Lessons Learned from AMSS

- Keycloak setup patterns are proven — borrow the config approach, not the code
- Keep external MCP servers as simple as possible — complexity lives in the platform, not the mock services
- The demo client experience matters as much as the architecture — invest in the curl commands and talking points in `demo/requests/`
- Test networking early — it's the most likely source of demo-day failure