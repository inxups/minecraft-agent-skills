# Security Policy

## Reporting

Do not report security vulnerabilities in a public GitHub issue.

Use GitHub Security / private vulnerability reporting for this repository. If that workflow appears unavailable, open a minimal public issue asking maintainers to enable private vulnerability reporting for this repository; do not include exploit details, proof-of-concept payloads, secrets, or affected private infrastructure details in the public issue.

## What To Include

- A short description of the issue and affected files or workflows
- Reproduction steps
- Expected impact
- Any suggested remediation or containment steps

## Scope Notes

This repository primarily ships skills, docs, validators, and plugin metadata. Relevant reports still include:

- Unsafe validator behavior
- Guidance that could cause secret exposure
- Plugin packaging or marketplace metadata issues that could mislead users
- Docs or scripts that encourage unsafe defaults in public or shared environments

Please keep reports private until a fix is prepared and maintainers confirm disclosure timing.
