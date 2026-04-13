# Security Policy

## Supported Versions

| Version | Supported |
| --- | --- |
| `0.1.x` | Yes |
| earlier preview builds | No |

This repository intentionally avoids shipping:

- auth files
- tokens
- live machine state
- personal history
- production credentials

## Reporting

If you find:

- a leaked secret
- a hardcoded personal path
- a template that encourages unsafe defaults
- validation gaps that let private state slip through

open a private report first instead of publishing the issue immediately.

Once the repository is public on GitHub, prefer GitHub private vulnerability reporting if it is enabled.

## Threat Model

The main risk here is not remote code execution inside the repo itself.
The main risk is accidental publication of private or machine-specific data through templates, examples, or docs.
