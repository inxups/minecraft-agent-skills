# Security Policy

## Supported Scope

This repository contains documentation and skill definitions, not production services.
Security-sensitive issues are primarily:

- Accidental inclusion of secrets/tokens/private keys
- Unsafe operational guidance in examples
- Malicious or misleading automation instructions

## Reporting

If you discover a security issue, open a private security advisory on GitHub (preferred).
If that is unavailable, open an issue with minimal reproduction details and avoid posting any sensitive data.

## Secret Handling

- Do not commit credentials to this repository.
- Use placeholders in examples (`<token>`, `CHANGE_THIS`, etc.).
- Rotate any credential immediately if it was exposed in history.
