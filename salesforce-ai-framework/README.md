# Salesforce AI Framework

> **Enterprise Architecture, Development Standards & AI Agent Playbooks for Salesforce Implementations**

---

## 1. Framework Purpose & Vision
The **Salesforce AI Framework** is a unified, source-driven knowledge system designed to align **AI Coding Agents** and **Human Engineering Teams**. It establishes a single source of architectural truth for building mission-critical, enterprise-grade Salesforce solutions.

Whether an AI agent is generating an Apex service, scaffolding a responsive Lightning Web Component, or conducting requirements discovery, this framework enforces:
1. **Zero-Defect Bulkification**: Resilience against governor limits across 200-record transactions.
2. **Strict Security by Default**: `USER_MODE` queries, explicit sharing models, and PII masking.
3. **WarpDrive Visual Excellence**: High-end light-mode UI design, emerald accents, and pill ergonomics.
4. **Decoupled Architecture**: Clean Separation of Concerns (SoC) across controllers, services, selectors, and domain triggers.

---

## 2. Framework Directory Structure

```
salesforce-ai-framework/
├── README.md                                # Master Architecture Hub (This file)
├── agentforce-opportunities.md              # Agentforce Real Estate Opportunities & Blueprint
│
├── rules/                                   # Hard Architectural & Coding Constraints
│   ├── apex.md                              # Enterprise Apex, SoC, limits, bulkification
│   ├── lwc.md                               # Modern LWC, reactivity, LMS, wire vs imperative
│   ├── integrations.md                      # REST/OData, Named Credentials, SAP, Webhooks
│   ├── testing.md                           # 90%+ coverage, TestDataFactory, HTTP mocking
│   └── security.md                          # User Mode, CRUD/FLS, Aadhaar PII, maker-checker
│
├── skills/                                  # Actionable Step-by-Step Engineering Playbooks
│   ├── design-object-model.md               # Master-Detail vs Lookup, LDV, indexing
│   ├── build-lwc.md                         # 7-step LWC engineering lifecycle
│   ├── build-apex.md                        # Enterprise Apex service & trigger lifecycle
│   ├── discovery-analysis.md                # Stakeholder discovery, process maps, user stories
│   └── style-guide.md                       # WarpDrive design tokens, emerald palette, pills
│
├── templates/                               # Copy-Pasteable Markdown Scaffolding
│   ├── object-schema-template.md            # SObject data dictionary & relationship spec
│   ├── solution-design-template.md          # High-Level (HLD) & Technical Design (TDD) doc
│   └── project-context-template.md          # Repo context, personas, and system blueprint
│
└── understanding-project/                   # Domain Context & End-to-End Operational Maps
    └── end-to-end-flow.md                   # 6-stage Residential Real Estate buyer lifecycle
```

---

## 3. Quick Reference Matrix

| Category | Document | Primary Focus | Target Audience |
| :--- | :--- | :--- | :--- |
| **Agentforce** | [agentforce-opportunities.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/agentforce-opportunities.md) | Autonomous agents, WhatsApp, Atlas Engine | Product Owners, Architects |
| **Rules** | [apex.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/rules/apex.md) | SoC layers, bulkification, limits defense | Developers, AI Agents |
| **Rules** | [lwc.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/rules/lwc.md) | Reactivity, state management, light UI | Frontend Engineers |
| **Rules** | [integrations.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/rules/integrations.md) | SAP, CTI, Webhooks, Idempotency | Integration Architects |
| **Rules** | [testing.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/rules/testing.md) | 90%+ target, AAA pattern, mocking | QA, Developers |
| **Rules** | [security.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/rules/security.md) | User Mode, FLS, PII masking, sharing | Security Reviewers |
| **Skills** | [design-object-model.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/skills/design-object-model.md) | Schema design, MD vs Lookup, LDV | Data Architects |
| **Skills** | [build-lwc.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/skills/build-lwc.md) | LWC bundle creation & deployment | Frontend Engineers |
| **Skills** | [build-apex.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/skills/build-apex.md) | Services, selectors & triggers | Backend Engineers |
| **Skills** | [discovery-analysis.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/skills/discovery-analysis.md) | Persona interviews, As-Is/To-Be | Solution Architects |
| **Skills** | [style-guide.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/skills/style-guide.md) | WarpDrive color tokens, pills, badges | UI/UX Designers |
| **Templates**| [object-schema-template.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/templates/object-schema-template.md) | SObject data dictionary template | Technical Leads |
| **Templates**| [solution-design-template.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/templates/solution-design-template.md) | Technical Solution Design (TDD) | Solution Architects |
| **Templates**| [project-context-template.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/templates/project-context-template.md) | Context priming for AI agents | AI Engineering Leads |
| **Flow** | [end-to-end-flow.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/understanding-project/end-to-end-flow.md) | 6-stage Residential Real Estate flow | Stakeholders, Clients |

---

## 4. How AI Agents Should Consume This Framework

When an AI Agent is tasked with writing code or generating architecture:
1. **Step 1: Ingest Mandatory Rules**:
   - For backend tasks, read [rules/apex.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/rules/apex.md) and [rules/security.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/rules/security.md).
   - For frontend tasks, read [rules/lwc.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/rules/lwc.md) and [skills/style-guide.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/salesforce-ai-framework/skills/style-guide.md).
2. **Step 2: Follow Skill Playbooks**:
   - Execute workflows sequentially as prescribed in the respective skill markdown file.
3. **Step 3: Leverage Standard Templates**:
   - Always output technical proposals, schema catalogs, and design docs using the structured templates in `templates/`.

---

## 5. Cross-Repository Relationships
- **Live Demo & Click-Paths**: See root [README.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/README.md).
- **Pitch Call Technical Script**: See root [INTEGRATION_TOUCHPOINTS_PITCH_GUIDE.md](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/INTEGRATION_TOUCHPOINTS_PITCH_GUIDE.md).
- **Live Source Code**: Located under [force-app/main/default/](file:///c:/Users/Admin/Documents/Residential%20Sales%20Project/force-app/main/default).
