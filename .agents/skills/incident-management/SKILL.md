---
name: incident-management
description: Incident response/management for outages: severity triage, comms, mitigation, postmortems. Triggers: "incident response", "outage", "on-call", "postmortem", "major incident".
license: MIT
---

# Incident Management Agent

Concise, structured incident response guidance with clear triage, communication, mitigation, and postmortem flow.

---

## PHASE 0: Context Gathering (MANDATORY)

<context_gathering>
**Execute these commands IN PARALLEL to establish ground truth:**

```bash
git status
git log -5 --oneline
ls
```

**Capture these data points:**
1. Current working tree state (dirty/clean)
2. Recent changes that may relate to the incident
3. Repo structure/context (services, docs, runbooks)
</context_gathering>

---

## PHASE 1: Analysis & Strategy (BLOCKING)

<analysis>
**Analyze the context and determine the mode/strategy.**

### 1.1 Decision Logic

| Condition | Mode/Strategy |
|-----------|---------------|
| Customer impact confirmed + broad scope | Declare major incident, assign roles, increase comms cadence |
| Degraded service, limited scope | Standard incident response, focused mitigation |
| Potential issue only (no confirmed impact) | Investigate, monitor, prepare comms |

### 1.2 MANDATORY OUTPUT

**You MUST output this block before proceeding. NO EXCEPTIONS.**

```
ANALYSIS RESULT
===============
Detected Context: [...]
Selected Strategy: [...]
Plan:
  1. Triage severity + scope
  2. Assign roles + establish comms
  3. Mitigate + stabilize
  4. Post-incident review
```
</analysis>

---

## PHASE 2: Execution (Atomic & Safe)

<execution>
### 2.1 Step-by-Step Instructions

1. **Severity Triage**:
   - Confirm impact, scope, and user-facing symptoms.
   - Declare incident level based on impact and urgency.

2. **Roles + Communication**:
   - Assign incident commander and communications owner.
   - Establish update cadence and audience-specific updates.

3. **Mitigation**:
   - Prioritize stabilization and rollback/mitigation steps.
   - Track actions, timelines, and decisions.

4. **Postmortem**:
   - Conduct blameless review and capture learnings.
   - Create follow-up actions with owners and deadlines.

### 2.2 Critical Rules

- Always declare a single incident owner/commander.
- Communicate early and regularly; set expectations for next update.
- Optimize for service restoration before root cause perfection.
- Document key timestamps, decisions, and actions for postmortem.
</execution>

---

## PHASE 3: Verification

<verification>
**Verify the work before finishing.**

```bash
# Confirm incident status is resolved and comms are updated
```

**Final Report:**
Output a summary of actions taken, current status, and follow-up items.
</verification>

---

## Best Practices

<best_practices>
1. **Define incident severity and impact clearly** to drive urgency and response scope. (Atlassian)
2. **Assign clear roles (incident commander + communications owner)** to coordinate response. (incident.io)
3. **Communicate early, clearly, and on a predictable cadence** with audience-appropriate detail. (UptimeRobot)
4. **Prioritize restoration of service** before deep root-cause work during active response. (Microsoft WAF)
5. **Run blameless postmortems with actionable follow-ups** to improve reliability. (incident.io)
</best_practices>

---

## Anti-Patterns (AUTOMATIC FAILURE)

<anti_patterns>
1. **No ownership**: unclear leadership or multiple commanders. (incident.io)
2. **Silent or inconsistent communication** that erodes trust. (UptimeRobot)
3. **Blame-focused postmortems** that discourage reporting and learning. (incident.io)
4. **Chasing root cause during active outage** instead of stabilizing. (Microsoft WAF)
5. **Missing severity definitions**, leading to delayed or overblown responses. (Atlassian)
</anti_patterns>

---

## Sources

- https://www.atlassian.com/incident-management
- https://incident.io/guide
- https://uptimerobot.com/knowledge-hub/observability/incident-communication-guide/
- https://learn.microsoft.com/en-us/azure/well-architected/design-guides/incident-management
