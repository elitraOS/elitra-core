# 4. MPC Automation Wallets (2-of-3)

## Purpose

Eliminate single-key risk entirely by ensuring that **no private key ever exists**, while still supporting **fully automated execution**.

Used by:

* Institutional funds
* Custodians
* High-TVL automated strategies

---

## Core Principle

> **Policy is a cryptographic participant, not a pre-check.**

If policy does not participate, **a signature cannot mathematically exist**.

---

## Architecture Overview (2-of-3)

```
Share A → Execution Bot
Share B → Policy Engine / Co-signer
Share C → Backup / Human / HSM
```

Automation uses **A + B**.
C is for recovery or exceptional approval.

---

## How Automation Actually Works

### Step 1: Transaction Proposal (No Signing)

The bot constructs an **unsigned transaction intent**:

* to
* data
* value
* gas
* nonce
* chainId

No cryptographic operation occurs here.

---

### Step 2: Policy Validation

The policy engine evaluates the intent using the same rules as in the HSM model:

* Destination allowlists
* Function selectors
* Slippage bounds
* Gas limits
* Rate limits
* Price sanity

If rejected → process stops.

---

### Step 3: MPC Session Creation

If approved, a **single-use MPC session** is created:

```
session_id = hash(tx_hash || policy_hash || nonce)
```

This session:

* Is non-replayable
* Is bound to one transaction only

---

### Step 4: Interactive MPC Signing

Signing is **not sequential**.

Instead, an interactive protocol runs:

* Each participant contributes random values
* Commitments are exchanged
* Partial computations occur
* No participant ever reconstructs the key

If **either A or B refuses**, the protocol fails.

---

### Step 5: Final Signature Assembly

Only if the MPC protocol completes:

* A valid `(r, s, v)` ECDSA signature exists
* Transaction is broadcast

No partial signatures are stored or reused.

---

## Why MPC Is Stronger Than HSM

### HSM Model

```
Policy approves → HSM signs
```

### MPC Model

```
Policy participates → signature exists
Policy refuses → signature impossible
```

Policy enforcement is **cryptographic**, not procedural.

---

## Automation vs Human Approval

| Scenario           | Result                  |
| ------------------ | ----------------------- |
| Normal rebalance   | Fully automated (A + B) |
| Abnormal tx        | Policy refuses          |
| Emergency override | Share C required        |
| Recovery           | Share C used            |

---

## Security Guarantees

| Threat                    | Outcome                    |
| ------------------------- | -------------------------- |
| Bot compromise            | Insufficient to sign       |
| Policy service compromise | Insufficient to sign       |
| Insider threat            | Needs multiple shares      |
| Key exfiltration          | Impossible (no key exists) |

---

## Tradeoffs

**Pros**

* No single point of failure
* Strong insider resistance
* Institutional-grade guarantees

**Cons**

* High cost
* Vendor lock-in
* Limited flexibility for custom logic
* More operational complexity

---

## When to Use

* TVL > $50–100M
* Regulated environments
* Strong insider threat model

---

## Summary

MPC automation wallets are **not about speed or convenience**.
They are about **ensuring that even catastrophic system compromise cannot directly move funds**.

They represent the **upper bound of key security** for automated crypto systems.
