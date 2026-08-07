# Security Policy

## Supported versions

This is a small personal open-source project. Security fixes are applied on a best-effort basis to the default branch (`main`).

## Trust model (read this first)

Git Team Reporting is a **local, single-operator** Rails app:

- There is **no multi-user authentication** for the web UI.
- Anyone who can reach the running app can manage teams, repositories, settings, and generate reports.
- A GitHub personal access token (PAT) may live in environment variables and/or the **encrypted browser session**.
- The app is **not** designed for multi-tenant internet hosting without you adding real authentication and hardening.

Do **not** expose a default install on a public URL.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems that could be exploited.

Prefer one of:

1. [GitHub private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) for this repository (if enabled), or
2. Contact the maintainer privately via the email on their GitHub profile.

Include:

- A short description of the issue and impact
- Steps to reproduce (or a proof of concept)
- Affected commit / version if known

You should get an acknowledgment when practical. Please allow reasonable time for a fix before public disclosure.

## Secrets and tokens

| Do | Don't |
|----|--------|
| Put tokens in `.env` (gitignored) or temporary Settings session overrides | Commit `.env`, PATs, or `config/master.key` |
| Use least-privilege GitHub tokens (read-only repo access when enough) | Paste tokens into issues, PRs, or chat logs |
| Rotate a token immediately if it may have leaked | Rely on this app as a secrets store |

`config/credentials.yml.enc` is encrypted Rails credentials. The decrypting **master key must stay private**.

## Out of scope (unless clearly a code bug)

- Misconfiguration (binding to `0.0.0.0` on an untrusted network without auth)
- Compromised operator machine or stolen session cookie
- Abuse of a GitHub PAT the operator chose to provide
- Vulnerabilities only in upstream dependencies with no practical impact on this app (file those upstream; Dependabot/bundler-audit track many of these)

## Hardening tips if you self-host

1. Keep the app on localhost or a private network, **or** add authentication in front of it.
2. Set a strong `SECRET_KEY_BASE` via the environment.
3. Configure `config.hosts` and TLS if the app is reachable over a network.
4. Prefer env-based tokens over long-lived session PAT overrides on shared machines.
5. Run `bin/ci` (RuboCop, Brakeman, bundler-audit, tests) before deploying changes.
