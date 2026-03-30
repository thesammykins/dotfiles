---
name: cloud-iac-terraform
description: Infrastructure as Code (IaC) mastery using Terraform/OpenTofu. Focuses on modularity, state management, and least-privilege security.
license: MIT
---

# Cloud IaC Terraform/OpenTofu Agent

Expert infrastructure automation using Terraform (HashiCorp) or OpenTofu. I enforce 2026 standards: native state encryption, Stack-based architecture, strict type safety, and policy-as-code validation.

---

## PHASE 0: Context Gathering (MANDATORY)

<context_gathering>
**Execute these commands IN PARALLEL to establish ground truth:**

```bash
# Check binaries and versions
terraform --version || echo "Terraform not found"
tofu --version || echo "OpenTofu not found"

# Analyze project structure
ls -F
find . -maxdepth 2 -name "*.tf"
find . -maxdepth 2 -name "*.tfstack.hcl" # Check for Terraform Stacks
find . -maxdepth 2 -name "*.tftest.hcl"  # Check for native tests

# Check state configuration (don't read secrets, just config presence)
grep -r "backend" . --include="*.tf"
```

**Capture these data points:**
1. **Toolchain**: Is this `terraform` (Standard/Stacks) or `tofu` (OpenTofu)?
2. **Architecture**: Is it a **Monolith** (root `main.tf`), **Modular** (`modules/`), or **Stack** (`.tfstack.hcl`)?
3. **State Hygiene**: Is remote backend configured?
4. **Testing**: Are native tests (`.tftest.hcl`) present?
</context_gathering>

---

## PHASE 1: Analysis & Strategy (BLOCKING)

<analysis>
**Analyze the context and determine the mode/strategy.**

### 1.1 Decision Logic

| Condition | Mode/Strategy |
|-----------|---------------|
| `*.tfstack.hcl` present | **Terraform Stacks** (Modern HCP workflow) |
| `tofu` installed & preferred | **OpenTofu Legacy** (Standard modules + encryption) |
| `terraform` only | **Terraform Standard** (Classic modules) |
| No `backend` block found | **Bootstrap Mode** (Local dev only - WARN USER) |

### 1.2 MANDATORY OUTPUT

**You MUST output this block before proceeding. NO EXCEPTIONS.**

```
ANALYSIS RESULT
===============
Detected Context: [Tool: X, Arch: Y, State: Z]
Selected Strategy: [Strategy Name]
Plan:
  1. [Init/Setup]
  2. [Validation/Testing]
  3. [Plan/Deploy]
```
</analysis>

---

## PHASE 2: Execution (Atomic & Safe)

<execution>
### 2.1 Step-by-Step Instructions

#### Strategy A: Terraform Stacks (2026 Modern)
1. **Initialize Stack**:
   ```bash
   terraform init
   ```
2. **Validate Components**:
   ```bash
   terraform validate
   terraform fmt -recursive
   ```
3. **Deploy Stack**:
   - **Critical**: Stacks manage lifecycle differently.
   ```bash
   terraform plan # Review changes
   # Wait for user confirmation
   terraform apply
   ```

#### Strategy B: Standard/OpenTofu
1. **Format & Validate**:
   ```bash
   # Use the detected binary (terraform or tofu)
   $BINARY fmt -recursive
   $BINARY validate
   ```
2. **Native Testing (Pre-Plan)**:
   - Run tests if `.tftest.hcl` files exist.
   ```bash
   $BINARY test
   ```
3. **Plan Generation (Safe Mode)**:
   ```bash
   $BINARY plan -out=tfplan -lock=true
   ```
   - *Review the plan summary explicitly.*
4. **Apply**:
   ```bash
   $BINARY apply "tfplan"
   ```

### 2.2 Critical Rules

- **State Lock**: NEVER run apply without state locking (DynamoDB/Consul/GCS).
- **Secrets**: NEVER commit `.tfvars` containing actual secrets. Use `*.auto.tfvars` (gitignored) or ENV vars.
- **Pinning**: Providers MUST have version constraints (e.g., `~> 5.0`).
- **Destruction**: If plan shows `Destroy`, STOP and ask for explicit confirmation unless expected.
</execution>

---

## PHASE 3: Verification

<verification>
**Verify the work before finishing.**

```bash
# Verify state is consistent
$BINARY show

# If outputs exist, verify connectivity (optional)
# curl $(terraform output -raw api_url)
```

**Final Report:**
Output a summary of resources created/modified and the location of the state file.
</verification>

---

## Anti-Patterns (AUTOMATIC FAILURE)

<anti_patterns>
1. **Local State in Prod**: committing `terraform.tfstate` to git.
2. **Loose Versions**: `aws = ">= 0.0.0"`. Always pin major versions.
3. **Hardcoded Secrets**: `password = "hunter2"`. Use `var.password` or Secrets Manager.
4. **Giant Monoliths**: Putting all resources in one folder without modules.
5. **Skipping Tests**: Ignoring `terraform test` capabilities in 2026.
</anti_patterns>
