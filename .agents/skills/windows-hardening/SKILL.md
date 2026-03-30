---
name: windows-hardening
description: Windows administration hardening for security baselines, GPO hardening, and patch management (triggers: Windows hardening, security baseline, GPO hardening, Windows patching, Windows admin)
license: MIT
---

# Windows Hardening Agent

Practical Windows administration hardening focused on security baselines, configuration control, and patch management for workstations and servers.

---

## PHASE 0: Context Gathering (MANDATORY)

<context_gathering>
**Execute these commands IN PARALLEL to establish ground truth:**

```bash
systeminfo
gpresult /r
Get-ComputerInfo | Select-Object OsName, OsVersion, CsDomain, WindowsProductName
```

**Capture these data points:**
1. OS version/edition and whether server or workstation
2. Domain/standalone status and applied GPOs
3. Patch/update management mechanism (WSUS/WUfB/Intune/other)
</context_gathering>

---

## PHASE 1: Analysis & Strategy (BLOCKING)

<analysis>
**Analyze the context and determine the mode/strategy.**

### 1.1 Decision Logic

| Condition | Mode/Strategy |
|-----------|---------------|
| Domain-joined + GPOs present | Use Microsoft Security Compliance Toolkit baseline + GPO hardening workflow |
| Intune/MDM-managed endpoints | Use Windows Security Baselines + MDM policy workflow |
| Standalone/workgroup systems | Apply baseline locally with audit-first, then enforce |
| Servers (any management model) | Apply server-specific baseline and change-control gating |

### 1.2 MANDATORY OUTPUT

**You MUST output this block before proceeding. NO EXCEPTIONS.**

```
ANALYSIS RESULT
===============
Detected Context: [...]
Selected Strategy: [...]
Plan:
  1. Identify applicable baseline and management plane
  2. Audit current state vs baseline
  3. Implement controls with change management
  4. Validate and monitor compliance
```
</analysis>

---

## PHASE 2: Execution (Atomic & Safe)

<execution>
### 2.1 Step-by-Step Instructions

1. **Baseline Selection**:
   - Choose Microsoft Security Baselines (SCT) or CIS Benchmark for the exact OS version.
   - Document scope (workstation/server, role-specific deviations).

2. **Audit First**:
   - Export current policy/state and compare to baseline.
   - Record exceptions with business justification.

3. **Controlled Rollout**:
   - Stage in test → pilot → broad rings.
   - Apply with GPO/MDM/OSConfig depending on management plane.

4. **Patch Management**:
   - Configure update rings or WSUS approvals.
   - Set deferrals, maintenance windows, and rollback plan.

### 2.2 Critical Rules

- Never enforce a baseline without audit/impact assessment.
- Always use rings or staged deployments for patching.
- Maintain rollback steps and change windows for critical systems.
</execution>

---

## PHASE 3: Verification

<verification>
**Verify the work before finishing.**

```bash
gpresult /h gpresult.html
Get-WindowsUpdateLog
```

**Final Report:**
Summarize applied baselines, deviations, update policy, and any remaining risks.
</verification>

---

<best_practices>
- Use Microsoft Security Baselines and the Security Compliance Toolkit (SCT) to apply recommended, version-specific baseline settings. (Source: https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/windows-security-baselines, https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10)
- Use CIS Benchmarks for prescriptive secure configuration guidance tailored to specific Windows versions and editions. (Source: https://www.cisecurity.org/benchmark/microsoft_windows_desktop)
- Harden Windows 10/11 following prioritized guidance (e.g., application control, credential protection, patching). (Source: https://www.cyber.gov.au/sites/default/files/2024-07/PROTECT%20-%20Hardening%20Microsoft%20Windows%2010%20and%20Windows%2011%20Workstations%20%28July%202024%29.pdf)
- Configure update rings and deferral policies for Windows Update for Business to stage updates safely. (Source: https://learn.microsoft.com/en-us/compliance/essential-eight/e8-patchos-configure-wufb-rings)
- Use WSUS to centrally approve and manage Windows updates in managed environments. (Source: https://learn.microsoft.com/en-us/windows/deployment/update/waas-manage-updates-wsus)
</best_practices>

<anti_patterns>
1. Enforcing baseline settings without audit or staged rollout (causes outages and policy regressions). (Source: https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10)
2. Applying a baseline that does not match the OS version or role (introduces incompatibilities). (Source: https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/windows-security-baselines)
3. Patching without rings/approval gates or rollback plan (increases blast radius). (Source: https://learn.microsoft.com/en-us/compliance/essential-eight/e8-patchos-configure-wufb-rings, https://learn.microsoft.com/en-us/windows/deployment/update/waas-manage-updates-wsus)
4. Ignoring prescriptive hardening guidance and leaving high-priority controls unaddressed. (Source: https://www.cyber.gov.au/sites/default/files/2024-07/PROTECT%20-%20Hardening%20Microsoft%20Windows%2010%20and%20Windows%2011%20Workstations%20%28July%202024%29.pdf)
</anti_patterns>

Sources:
- https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/windows-security-baselines
- https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10
- https://www.cisecurity.org/benchmark/microsoft_windows_desktop
- https://www.cyber.gov.au/sites/default/files/2024-07/PROTECT%20-%20Hardening%20Microsoft%20Windows%2010%20and%20Windows%2011%20Workstations%20%28July%202024%29.pdf
- https://learn.microsoft.com/en-us/compliance/essential-eight/e8-patchos-configure-wufb-rings
- https://learn.microsoft.com/en-us/windows/deployment/update/waas-manage-updates-wsus
