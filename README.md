# Mastering Windows Incident Response
# DFIR Dashboards & Detection Material

This repository contains dashboards, configurations, and supporting material designed to accompany real-world Digital Forensics and Incident Response (DFIR) workflows.

This is not lab-based theory or certification-focused content.

These materials are built around how incidents actually unfold in live environments:

* incomplete telemetry
* inconsistent logging
* fragmented visibility across systems
* the need to validate attacker behavior under real constraints

---

Purpose

The purpose of this repository is to provide practical, hands-on material for:

* Individual DFIR skill development
* Threat hunting practice
* Validation of attacker behavior across systems
* Real-world investigative workflows

This material is intended to complement the associated published work and provide a usable, applied extension of those concepts.

---

Repository Contents

This repository may include:

* Wazuh dashboards (`.ndjson`)
* Detection logic and supporting scripts
* Investigative workflows and examples
* Supporting configurations and references

---

Usage

Dashboards

Dashboards are exported as `.ndjson` files and can be imported via:

Menu → Dashboard Management → Saved Objects → Import

Ensure your environment contains relevant data (e.g., `wazuh-alerts-*`) for dashboards to function as expected.

---

General Guidance

* All material should be tested in a controlled lab or development environment
* Do not deploy directly into production without validation
* Expect differences between environments and adjust accordingly

---

Usage Restrictions

This material is provided for **individual, non-commercial educational use only**.

The following uses are not permitted without a commercial license:

* Corporate or enterprise environments
* Security Operations Centers (SOCs)
* Internal team training or enablement
* Consulting, contracting, or third-party service delivery
* Use on behalf of any organization or client

For full terms, see `LICENSE.md`.

---

Important Notice

All scripts, dashboards, and configurations should be tested in a controlled environment prior to use.

Use of this material in production or live systems is done entirely at your own risk.

---

Disclaimer

This material is provided "as is" without warranty of any kind.

Network Defense Solutions, Inc. assumes no responsibility or liability for:

* System disruption
* Data loss
* Security incidents
* Operational impact

resulting from the use or misuse of this material.

---

Companion Material

This repository is designed to support the associated published work.

Additional context, methodology, and implementation details are provided within that material.

---

Final Note

Incident Response is not performed in clean environments.

This material reflects that reality.

---
