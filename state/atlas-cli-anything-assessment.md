# EA Assessment: CLI-Anything
**TKT-0141 | Enterprise Architecture Deliverable**
**Author:** Atlas 🏛️ — Enterprise Architect, AInchors
**Date:** 2026-05-10 (Sunday, 5:42 PM AEST)
**Status:** FINAL — FOR KEN REVIEW
**Classification:** CONFIDENTIAL — INTERNAL

---

## Executive Summary

**Verdict: CONDITIONAL ADOPT — introduce in P2, with controlled internal use from late P1.**

CLI-Anything is a genuine strategic accelerator for AInchors. It operationalises the "agent-native everything" principle that underpins the entire Nexus platform vision. The security risk (SKILL.md poisoning / DDIPE) is real but already controlled via TKT-0141/0142 and Skill-Installation-Policy-v1.0.md. With controls in place, the opportunity significantly outweighs the residual risk.

**Three-line summary:**
- Internally: adopt now, carefully. Dramatically speeds up making AInchors' own tools agent-native.
- Client delivery: introduce in P2 Business Jumpstart engagements as a structured offering.
- Platform: a natural Nexus Holocron integration point. Consider CLI-Anything as an input layer to the Nexus skill registry.

---

## 1. Strategic Opportunity Assessment

### 1.1 What CLI-Anything enables that AInchors doesn't have today

AInchors currently relies on manually authored SKILL.md files for every tool, script, and platform integration. This is:
- Time-intensive (hours per skill)
- Inconsistent in quality and coverage
- A bottleneck that scales linearly with the number of integrations

CLI-Anything inverts this. It reads a repository's source code and generates a structured, agent-consumable SKILL.md automatically. The delta in time is an order of magnitude: what takes a skilled engineer 4–8 hours per tool takes CLI-Anything minutes.

**What this unlocks that AInchors doesn't have today:**

| Gap Today | CLI-Anything Capability |
|-----------|------------------------|
| Slow manual SKILL.md authoring | Automated SKILL.md generation from source analysis |
| Inconsistent skill quality across tools | Structured, consistent output format |
| No client repo → agent-native pathway | Direct path: clone client repo → run CLI-Anything → working agent skill |
| AInchors skills library grows slowly | Skills library can grow at velocity matching tool adoption |
| Agent onboarding to new tools is a project | Agent onboarding to new tools is a task |

### 1.2 Internal productivity tool, client delivery tool, or both?

**Both — but with different maturity timelines and risk profiles.**

**Internal (P1 late / P2 early):**
The primary initial value is internal. AInchors has ~52+ scripts, growing Nexus modules (Holocron, Bridge, Citadel, Holonet, Beacon, Sanctum, Datapad), and a growing skills registry. Every one of these is a CLI-Anything candidate. Using it internally first lets AInchors build operational confidence before putting it in front of clients.

**Client delivery (P2):**
Once AInchors has internal validation data (quality of generated skills, failure modes, edge cases), CLI-Anything becomes a structured consulting offering. It slots naturally into the Business Jumpstart pathway (TKT-0138) as the "make your tools agent-native" sprint — a high-value, time-bounded deliverable that clients can see and measure.

### 1.3 Phase fit

| Phase | CLI-Anything Role | Readiness Gate |
|-------|-------------------|----------------|
| **P1 (now)** | Internal use only. Generate skills for AInchors' own scripts and Nexus modules. Validate quality. Build internal confidence. | Security controls (TKT-0141/0142) must be active. No client repos. |
| **P2 Standard** | Client-facing offering in Business Jumpstart. Agent-native transformation sprint as a structured engagement. | P2 SaaS platform live. Client isolation in place. Skill sandbox/review workflow deployed. |
| **P3 (commercial tier within P2)** | Multi-agent/org-wide skill distribution. CLI-Anything generates skills that populate the org's shared Nexus skill registry. | Nexus Holocron multi-tenant registry operational. |
| **P4 (FSI)** | Controlled, scoped use for internal FSI tooling only. Not for client-facing regulated code without additional controls. | Formal skill approval workflow. Compliance Agent gate on generated skills. Change control per CHG process. |

---

## 2. Use Case Mapping

### 2.1 Internal — Making AInchors' Tools Agent-Native Faster

**High priority. Start here.**

AInchors has an expanding set of scripts and platform components that agents need to operate. Currently these require manual SKILL.md authoring. CLI-Anything can accelerate this significantly.

**Specific targets:**

| Tool / Asset | CLI-Anything Applicability | Estimated Value |
|--------------|---------------------------|-----------------|
| `scripts/pvt.sh` and test harness | ✅ High — structured CLI with defined inputs/outputs | Saves 4h manual authoring |
| `scripts/ticket.sh`, `incident-log.sh`, `cost-tracker.sh` | ✅ High — well-defined command structure | Saves 2–3h per script |
| `scripts/backup.sh`, `health-check.sh` | ✅ High | Saves 1–2h per script |
| OpenClaw CLI itself | ✅ High — ~33K star project with clean CLI surface | Existing OpenClaw skill exists; use CLI-Anything to validate/enhance |
| Nexus module CLIs (Bridge, Citadel, Holonet) | ✅ High when those CLIs are built | P2 build target |
| `gog` (Google Workspace CLI) | ✅ High — already a structured CLI | Complements existing gog SKILL.md, may improve coverage |
| Custom AInchors reporting tools | ✅ Medium — quality depends on code structure | Review output before deploying |

**Process recommendation:**
1. Run CLI-Anything against each candidate repo
2. Human review of generated SKILL.md (Atlas or Ken, 15–30 min)
3. Agent smoke test (Yoda runs 3–5 representative commands)
4. Promote to workspace skills registry

### 2.2 Consulting Delivery — Client Business Jumpstart and AI Transformation

**This is where CLI-Anything creates the most differentiated commercial value.**

The Business Jumpstart pathway (TKT-0138) is a 3-part client engagement. CLI-Anything can be a core deliverable in Part 2 or Part 3 — the "operationalise AI in your environment" sprint.

**Proposed consulting offering: "Agent-Native Sprint"**

Packaged as a fixed-scope, fixed-price consulting engagement (e.g., 3–5 days):

1. **Discovery:** Identify client's 5–10 most-used internal tools and repositories
2. **Analysis:** Run CLI-Anything across each repository
3. **Review and curate:** AInchors consultant reviews generated skills, enhances quality, removes errors
4. **Deploy and test:** Install skills into client's OpenClaw or agent runtime
5. **Handover:** Client receives a structured skills library, documentation, and maintenance guidance

**Why this is commercially compelling:**
- Clients get a tangible, measurable output (X tools now agent-accessible)
- AInchors captures the full margin — CLI-Anything does the heavy analysis lifting, consultant adds the review and integration value
- Repeatable. Scalable. Creates ongoing dependency (tools evolve, skills need updates)
- Differentiates AInchors from consultants who only advise — AInchors actually delivers working AI integration

**Integration with Consulting Playbook (TKT-0136):**
This becomes a standard module in the AInchors Consulting IP Library. Document the process, the review checklist, the quality gates, and the pricing model. Reusable across engagements.

### 2.3 Nexus Platform — Skill Generation for Nexus Integrations

**Strategic fit: HIGH. Execution timing: P2.**

The Nexus platform modules (Holocron, Bridge, Citadel, Holonet, Beacon, Sanctum, Datapad) will each expose CLI interfaces as they mature. CLI-Anything is a natural input to the Nexus skill registry.

**Proposed architecture: CLI-Anything as Nexus Skill Ingestion Pipeline**

```
Nexus Module CLI (e.g., Bridge CLI) 
  → CLI-Anything analysis 
    → Generated SKILL.md 
      → Atlas/Yoda human review 
        → Holocron skill registry 
          → Agent-consumable via standard skill lookup
```

This creates a flywheel:
- New Nexus module ships
- CLI-Anything generates the initial skill automatically
- Review and publish to Holocron within hours, not days
- Agents across all tenant environments can use the skill immediately

**Holocron-specific consideration:**
If Nexus Holocron becomes a multi-tenant skill registry in P2, CLI-Anything could be offered as a self-service capability — clients can submit their repos and receive generated skills, reviewed and approved via AInchors' workflow. This is a platform feature, not just a service.

**Datapad integration:**
Datapad (client-facing interface) could surface a "Skill Generator" workflow powered by CLI-Anything. Clients submit a repo URL, AInchors reviews the output, and the approved skill is published. Productised consulting.

### 2.4 Training Product — CLI-Anything as Course Content

**Fit: MEDIUM. Timing: P2–P3 commercial tier.**

CLI-Anything represents a genuinely teachable capability. For AInchors' AI courses and training products, it can be taught as:

1. **Conceptual module:** What is an agent-native tool? Why does it matter? What is SKILL.md architecture?
2. **Hands-on lab:** Students run CLI-Anything against a sample repo, review output, deploy to their agent
3. **Advanced module:** Security risks (SKILL.md poisoning, DDIPE) — how to review generated skills, what red flags to look for
4. **Enterprise module:** How to build an agent-native toolchain in your organisation — the AInchors Agent-Native Sprint methodology

**Commercial model:** This is a premium module in any AInchors AI transformation course. It's practical, immediately applicable, and positions AInchors as a vendor who understands the real operational detail — not just the concepts.

**Caution:** The security dimension (SKILL.md poisoning) must be covered honestly. Teaching CLI-Anything without covering the attack vector would be irresponsible. The security module makes the training more credible, not less.

---

## 3. Risk vs Opportunity Balance

### 3.1 Security Risk Profile

**Known attack vector: SKILL.md Poisoning (DDIPE — Data/Decision Injection via Prompt Engineering)**

A maliciously crafted repository can embed adversarial instructions in source code comments, README files, or documentation that CLI-Anything incorporates into the generated SKILL.md. When an agent loads this poisoned skill, it executes the adversarial instructions.

**Risk characteristics:**

| Dimension | Assessment |
|-----------|------------|
| **Likelihood (uncontrolled)** | HIGH — any open-source repo is a potential attack surface |
| **Impact (uncontrolled)** | HIGH — poisoned skills can redirect agent actions, exfiltrate data, or execute arbitrary commands |
| **Likelihood (with controls)** | LOW-MEDIUM — controlled ingest pipeline and human review significantly reduce attack surface |
| **Impact (with controls)** | LOW — human review gate catches injections before deployment |
| **Control maturity** | MEDIUM — TKT-0141/0142 controls exist; Skill-Installation-Policy-v1.0.md documented |

### 3.2 Controls Already in Place (TKT-0141/0142)

Per the established security posture:
- Skill-Installation-Policy-v1.0.md governs all skill installation
- Generated skills must be reviewed before deployment
- Untrusted source repos require elevated review scrutiny
- Chain-of-custody tracking on skill origin

**Assessment: these controls are necessary and sufficient for internal P1 use.** For client-facing use, additional controls are needed (see §3.3).

### 3.3 Additional Mitigations Required for Client-Facing Use

**Gap 1: Client repo provenance controls**
Before running CLI-Anything on a client repo, AInchors must verify:
- The repo is the client's legitimate codebase (not a supply-chain-compromised dependency)
- No third-party code with embedded injection attempts is in scope

**Mitigation:** Scoped analysis — run CLI-Anything against specific modules, not entire repos with all dependencies. Document the scope in the engagement.

**Gap 2: Client-environment deployment review**
The generated SKILL.md will be deployed into the client's agent environment. If the client's environment has different security controls than AInchors' (weaker), the risk profile changes.

**Mitigation:** Include a "Skill Review Checklist" as a client-facing deliverable. Train client's technical team to review and approve generated skills before deployment. AInchors provides the methodology; client takes ownership in their environment.

**Gap 3: Ongoing skill maintenance risk**
A skill generated from version X of a repo may become incorrect or unsafe when the repo changes significantly at version Y.

**Mitigation:** Skills are versioned. Generated skills carry a `generated-from-commit` metadata field. Client is responsible for re-running the analysis (or engaging AInchors) when significant changes occur.

**Gap 4: P4 FSI environment — additional controls required**
For regulated environments, generated skills represent unreviewed code artefacts. The Compliance Agent must gate all skill deployments with a formal change record.

**Mitigation:** P4 skill deployment = full CHG process. No exceptions. Compliance Agent review mandatory. This is already implied by the P4 change control posture but must be explicit for CLI-Anything.

### 3.4 Net Risk vs Opportunity Assessment

**Opportunity magnitude: HIGH**
- Dramatically accelerates internal tool agent-nativisation
- Creates a new commercial consulting offering (Agent-Native Sprint)
- Feeds Nexus Holocron skill registry pipeline
- Generates training content value

**Residual risk (with controls): LOW-MEDIUM (internal), MEDIUM (client-facing)**
- Human review gate is the primary control — it is manual and therefore fallible
- Risk is higher when running against unknown or third-party repos
- Risk is lower when running against AInchors' own well-understood codebase

**Verdict: opportunity significantly outweighs residual risk with appropriate controls.**
The risk is not "if CLI-Anything is safe" — it is "whether the review process is rigorous enough." That is a process control problem, not a technology problem. AInchors can manage it.

---

## 4. P2-P4 Roadmap Fit

### 4.1 Phase Entry Criteria

**P1 (now — internal only):**

Gates that must be in place before using CLI-Anything internally:
- ✅ Skill-Installation-Policy-v1.0.md active
- ✅ TKT-0141/0142 controls documented
- ✅ Human review step enforced (Atlas or Ken reviews every generated skill)
- ✅ Generated skills stored with provenance metadata (source repo, commit hash, generation date)

**P2 (client-facing):**

Gates before offering CLI-Anything in client engagements:
- [ ] Agent-Native Sprint methodology documented in Consulting Playbook (TKT-0136)
- [ ] Client Skill Review Checklist authored and reviewed by Ken
- [ ] At least 5 internal CLI-Anything runs completed with documented outcomes
- [ ] Scoped analysis procedure documented (which files/modules, which to exclude)
- [ ] Client engagement SOW template includes CLI-Anything scope and limitations clause

**P3 commercial tier (within P2):**

Gates before productising CLI-Anything in Nexus:
- [ ] Nexus Holocron multi-tenant skill registry operational
- [ ] CLI-Anything → Holocron ingest pipeline designed and tested
- [ ] Self-service skill generation workflow (with AInchors review gate) designed

**P4 (FSI):**

Gates before using CLI-Anything in regulated environments:
- [ ] P4 change control process explicitly covers AI-generated skill files
- [ ] Compliance Agent gate for all skill deployments active
- [ ] Engagement-specific risk assessment for CLI-Anything use documented per FSI client
- [ ] Formal risk acceptance from FSI client for AI-generated skills (contractual)

### 4.2 Dependencies and Prerequisites

| Dependency | Required For | Owner | Status |
|------------|-------------|-------|--------|
| Skill-Installation-Policy-v1.0.md | All phases | Ken | ✅ Done (TKT-0141) |
| TKT-0141/0142 security controls | All phases | Ken | ✅ Done |
| Consulting Playbook (TKT-0136) | P2 client-facing | Ken | 🔄 In progress |
| Business Jumpstart pathway (TKT-0138) | P2 client-facing | Ken | 🔄 In progress |
| Nexus Holocron registry design | P2 platform | Atlas | 📋 Not started |
| Agent-Native Sprint methodology doc | P2 consulting | Atlas/Ken | 📋 Not started |
| CLI-Anything → Holocron pipeline design | P2/P3 platform | Atlas | 📋 Not started |
| Compliance Agent skill review gate | P4 | Ken | 📋 P4 build |

### 4.3 What Platform Capabilities Must Exist First

For **internal use (P1):** No new platform capabilities needed. Skills registry on OC1 + Skill-Installation-Policy-v1.0.md is sufficient.

For **consulting delivery (P2):** Consulting Playbook and Business Jumpstart pathway must be production-ready. Agent-Native Sprint must be a documented, repeatable engagement model.

For **Nexus integration (P2/P3):** Holocron must have a skill submission and review workflow. This is a P2 build item, not a P1 item.

For **FSI use (P4):** Compliance Agent must be capable of reviewing and gate-approving agent-generated files. Full change control integration.

---

## 5. Recommendation

### 5.1 Verdict: CONDITIONAL ADOPT

**Conditions:**

1. **Internal use (start now):** Run CLI-Anything on AInchors' own scripts and Nexus module CLIs. Every generated skill must be reviewed by Atlas or Ken before deployment. Track outcomes (quality, time saved, gaps found). Target: 10 internal skills generated and validated by end of P1.

2. **Client-facing use (P2 gate):** Do not offer CLI-Anything to clients until the Agent-Native Sprint methodology is documented and Consulting Playbook (TKT-0136) has a formal module for it. Estimated timeline: P2 launch readiness.

3. **Platform integration (P2/P3 commercial tier):** Design the CLI-Anything → Holocron skill pipeline as a P2 architecture item. Build when Holocron registry is operational.

4. **FSI use (P4 — restricted):** CLI-Anything for FSI client repos requires formal risk acceptance, Compliance Agent gate, and engagement-specific approval. Default posture: NOT IN SCOPE for FSI unless explicitly risk-accepted.

### 5.2 Adoption Roadmap

| Phase | Action | Timeline | Owner |
|-------|--------|----------|-------|
| **P1 (now)** | Internal validation. Run CLI-Anything on AInchors scripts. Document outcomes. | Immediate | Yoda / Atlas |
| **P1** | Author Agent-Native Sprint methodology. Draft consulting offering. | 2–4 weeks | Atlas |
| **P2 launch** | Include Agent-Native Sprint in Business Jumpstart. First client engagements. | P2 launch | Ken |
| **P2** | Design CLI-Anything → Holocron skill ingest pipeline. | P2 build | Atlas |
| **P2/P3 commercial** | Productise self-service skill generation with AInchors review gate. | P3 commercial tier | Atlas / Ken |
| **P4** | Formal risk acceptance framework. Compliance Agent gate. | P4 build | Atlas |

### 5.3 What NOT to Do

- **Do not** run CLI-Anything on arbitrary public repos without human review. The attack vector is real.
- **Do not** auto-deploy generated skills without a review step. The human-in-the-loop is non-negotiable.
- **Do not** offer CLI-Anything as a self-service tool to clients without AInchors oversight in P2. Too early. Too risky.
- **Do not** use CLI-Anything in P4 FSI environments without explicit risk acceptance. Regulated = conservative.
- **Do not** treat the generated SKILL.md as production-ready without testing. It is a starting point, not a finished artefact.

### 5.4 Commercial Upside Summary

If adopted as recommended, CLI-Anything adds:

| Value Stream | Upside |
|--------------|--------|
| Internal productivity | Estimated 60–80% reduction in SKILL.md authoring time across AInchors toolchain |
| Consulting revenue | Agent-Native Sprint: new fixed-scope offering, 3–5 day engagement, premium pricing |
| Nexus platform differentiation | Skill ingestion pipeline makes Holocron self-sustaining at scale |
| Training content | High-value module in AI transformation courses |
| Competitive positioning | AInchors can credibly claim "we make your tools agent-native" — a concrete, measurable capability |

---

## 6. Open Questions for Ken

1. **Priority for internal validation:** Which AInchors scripts should be the first 3 CLI-Anything targets? Recommendation: `pvt.sh`, `ticket.sh`, and `health-check.sh` as representative complexity range.

2. **Agent-Native Sprint pricing:** How should this be priced in the Business Jumpstart pathway? Fixed fee per engagement or bundled into the overall engagement price?

3. **Holocron design timing:** When is the right time to start the Nexus Holocron skill registry architecture? This is a dependency for CLI-Anything platform integration.

4. **P4 appetite:** Is there any FSI client scenario where Ken sees CLI-Anything as in-scope? Or is P4 a hard no for now? Helps define where to invest in controls.

5. **Training product sequencing:** Should the CLI-Anything training module be developed before or after the Agent-Native Sprint consulting offering? The consulting offer builds credibility for the training; the training creates demand for the consulting.

---

## Appendix A — Risk Register

| Risk | Likelihood | Impact | Control | Residual Risk |
|------|------------|--------|---------|---------------|
| SKILL.md poisoning from malicious repo | Medium | High | Human review gate + provenance tracking | Low-Medium |
| Generated skill quality insufficient for production | Medium | Medium | Agent smoke test before deployment | Low |
| Client deploys unreviewed generated skill | Medium | High | Client Skill Review Checklist + SOW clause | Medium |
| FSI client repo analysis leaks sensitive code context | Low | High | Scoped analysis + no FSI use without risk acceptance | Low |
| CLI-Anything tool itself is compromised (supply chain) | Low | High | Pin to known good version. Review changelog on update. | Low |
| Skill becomes stale when underlying tool version changes | High | Medium | Generated-from-commit metadata + periodic review cadence | Medium |

---

## Appendix B — Architecture Integration Points

```
AInchors P2 Architecture — CLI-Anything Integration Points

┌─────────────────────────────────────────────────────────────┐
│                    NEXUS PLATFORM (P2)                      │
│                                                             │
│  ┌──────────┐    CLI-Anything    ┌──────────────────────┐  │
│  │  Client  │ ──────────────►   │  Skill Review Queue  │  │
│  │   Repo   │                   │  (Atlas/Ken review)  │  │
│  └──────────┘                   └──────────┬───────────┘  │
│                                            │               │
│  ┌──────────┐    CLI-Anything    ┌──────────▼───────────┐  │
│  │ AInchors │ ──────────────►   │   Holocron Skill     │  │
│  │  Scripts │                   │      Registry        │  │
│  └──────────┘                   └──────────┬───────────┘  │
│                                            │               │
│                                 ┌──────────▼───────────┐  │
│                                 │    Agent Runtimes    │  │
│                                 │  (Yoda, tenants)     │  │
│                                 └──────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

Security boundary: Review Queue is the control gate.
No skill crosses from Queue to Registry without human approval.
```

---

*Atlas 🏛️ — Enterprise Architect, AInchors*
*TKT-0141 | 2026-05-10*
*Classification: CONFIDENTIAL — INTERNAL*
