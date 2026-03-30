---
name: linux-hardening
description: Linux operations hardening (patching, least privilege, backups, monitoring, baseline security). Triggers: "linux hardening", "linux patching", "server hardening", "secure linux", "linux ops".
license: MIT
---

# Linux Hardening Agent

Concise, standards-aligned guidance for hardening Linux operations with safe, repeatable steps.

---

## PHASE 0: Context Gathering (MANDATORY)

<context_gathering>
**Execute these commands IN PARALLEL to establish ground truth:**

```bash
uname -a
cat /etc/os-release
id
```

**Capture these data points:**
1. OS distribution and version
2. Kernel version
3. Current user and privilege level
</context_gathering>

---

## PHASE 1: Analysis & Strategy (BLOCKING)

<analysis>
**Analyze the context and determine the mode/strategy.**

### 1.1 Decision Logic

| Condition | Mode/Strategy |
|-----------|---------------|
| Production system with uptime constraints | Conservative patch window + staged rollout + rollback plan |
| Non-production or lab environment | Aggressive patching + baseline enforcement |
| Compliance-bound environment (CIS/NIST) | Benchmark-driven hardening with audit trail |

### 1.2 MANDATORY OUTPUT

**You MUST output this block before proceeding. NO EXCEPTIONS.**

```
ANALYSIS RESULT
===============
Detected Context: [...]
Selected Strategy: [...]
Plan:
  1. Confirm scope and change window
  2. Apply baseline hardening controls
  3. Patch and verify critical services
  4. Validate monitoring and backups
```
</analysis>

---

## PHASE 2: Execution (Atomic & Safe)

<execution>
### 2.1 Step-by-Step Instructions

1. **Define scope and risk**:
   - Confirm environment, SLA, and rollback plan.
   - Record current baselines for auditability.

2. **Baseline hardening**:
   - Remove/disable unnecessary services.
   - Enforce least privilege and strong authentication.
   - Apply secure defaults aligned with CIS guidance.

3. **Patch management**:
   - Update packages in a controlled window.
   - Reboot where required and verify service health.

4. **Backups and monitoring**:
   - Confirm backup success + restore test.
   - Ensure monitoring/alerting covers auth, integrity, and resource anomalies.

### 2.2 Critical Rules

- Never patch production without a rollback plan and maintenance window.
- Always validate service health and monitoring after changes.
- Do not disable security controls to “make it work.”
</execution>

---

## PHASE 3: Verification

<verification>
**Verify the work before finishing.**

```bash
# Example verification (adjust to environment)
systemctl --failed
```

**Final Report:**
Output a summary of actions taken, risks accepted, and next steps.
</verification>

---

<best_practices>
- Use CIS Benchmarks or similar baselines to reduce attack surface and standardize controls. (Source: https://ncp.nist.gov/checklist/1129)
- Keep systems patched with a defined process, maintenance windows, and verification of service health. (Source: https://www.suse.com/c/linux-hardeningthe-complete-guide-to-securing-your-systems/)
- Enforce least privilege and strong access control (e.g., minimal sudo, MFA/SSH hardening). (Source: https://www.zenarmor.com/docs/linux-tutorials/linux-server-hardening-steps-and-best-practices)
- Maintain tested backups and monitoring to detect and recover from incidents quickly. (Source: https://www.suse.com/c/linux-hardeningthe-complete-guide-to-securing-your-systems/)
</best_practices>

<anti_patterns>
1. Skipping baseline benchmarks and relying on ad-hoc tweaks only. (Source: https://ncp.nist.gov/checklist/1129)
2. Patching production without a rollback or verification plan. (Source: https://www.suse.com/c/linux-hardeningthe-complete-guide-to-securing-your-systems/)
3. Granting broad admin access instead of least privilege. (Source: https://www.zenarmor.com/docs/linux-tutorials/linux-server-hardening-steps-and-best-practices)
4. Backups without regular restore testing. (Source: https://www.suse.com/c/linux-hardeningthe-complete-guide-to-securing-your-systems/)
</anti_patterns>

**Sources**
- https://ncp.nist.gov/checklist/1129
- https://www.suse.com/c/linux-hardeningthe-complete-guide-to-securing-your-systems/
- https://www.zenarmor.com/docs/linux-tutorials/linux-server-hardening-steps-and-best-practices
