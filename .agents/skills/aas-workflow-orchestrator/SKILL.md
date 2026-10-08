---
name: aas-workflow-orchestrator
description: >-
  Agentic Awesome Skills (AAS) workflow orchestrator and playbook catalog runner.
  Selects, validates, and coordinates domain-specific playbooks for architecture,
  hardening, performance, testing, and multi-service orchestration. Use PROACTIVELY
  when coordinating complex full-stack features, auditing security, or running workflows.
---

# Agentic Awesome Skills (AAS) Workflow Orchestrator

The Agentic Awesome Skills framework provides structured, repeatable engineering playbooks for AI coding agents. It prevents ad-hoc, unguided execution through standard control-plane phases: Stack Validation, Skill Selection, Plan Preview, Execution, and Evidence Verification.

---

## 1. AAS Control Plane Lifecycle

Every major engineering task runs through five verifiable gates:

```
[Stack Validation] -> [Skill Selection] -> [Plan Preview] -> [Surgical Execution] -> [Evidence Verification]
```

1. **Stack Validation**: Inspect repository architecture, languages, package managers, and configuration files. Do not guess framework versions or tooling.
2. **Skill Selection**: Select the matching domain playbook (Architecture, Security, Performance, Testing, Database) based on task scope.
3. **Plan Preview**: Outline the concrete steps, affected files, and verification criteria for review before modifying code.
4. **Surgical Execution**: Execute tasks sequentially following Karpathy and Superpowers principles.
5. **Evidence Verification**: Prove success through automated test execution, lint checks, or running service health verification.

---

## 2. Core Domain Playbooks

### Playbook A: Architecture Review and Deep Modules
* Verify module boundaries, interfaces, and separation of concerns.
* Ensure data access, business logic, and transport layers remain decoupled.
* Design deep interfaces: Simple surface area hiding internal complexity.

### Playbook B: Security Hardening and Vulnerability Defense
* Audit input validation, parameter sanitization, and output encoding.
* Verify JWT, session handling, password hashing, and role-based access control.
* Check for hardcoded secrets, insecure deserialization, and unvalidated redirects.
* Enforce least-privilege principles across database connections and API permissions.

### Playbook C: Performance Profiling and Optimization
* Audit database queries for missing indexes, full table scans, and N+1 query loops.
* Verify caching strategies (e.g., Redis layer, cache invalidation, key TTLs).
* Check payload sizes and serialization overhead on API response boundaries.
* Ensure non-blocking I/O and asynchronous handling for external network calls.

### Playbook D: Comprehensive Testing and Quality Assurance
* Maintain balanced test pyramids: Unit tests for core domain logic, integration tests for API endpoints, and end-to-end flows for critical user paths.
* Implement property-based or boundary tests for financial calculations, balance tracking, and status transitions.
* Verify test isolation: Tests must not depend on order of execution or leave lingering state in shared databases.

### Playbook E: Database Migration and Resilience
* Enforce backwards-compatible schema evolutions (expand and contract pattern).
* Ensure migrations run in atomic transactions where supported.
* Validate rollback strategies and idempotency before applying schema changes.

---

## 3. AAS Catalog Access and Execution

To query or install additional playbooks from the Agentic Awesome Skills catalog:
* Use the catalog helper script or npx CLI: `npx -y agentic-awesome-skills`
* When installing specific skills, install to `.agents/skills/<skill-name>/SKILL.md` or global `~/.gemini/config/skills/<skill-name>/SKILL.md`.
* Always preview the skill contents before applying instructions to a live repository.
