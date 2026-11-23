# Security policy

## This is not open-source software

The code in this repository is proprietary (see [`LICENSE`](LICENSE)). Viewing
it grants no right to run, deploy, copy or reuse it. There is no public
deployment of this project that you are authorised to test.

## Do not test against our systems

You are not authorised to probe, scan, fuzz, load-test or otherwise interact
with any Firebase project, Cloud Functions endpoint, Stripe account or hosted
domain referenced by this repository. Doing so is unauthorised access.

## Reporting a vulnerability

If you find a security defect in the code itself, report it privately:

1. Use GitHub's **Security → Report a vulnerability** advisory flow on this
   repository, or
2. Contact the repository owner through their GitHub profile.

Please include the affected file or function, the impact you believe it has, and
a minimal reproduction if you have one. Do not open a public issue for a
vulnerability, and do not include live credentials or customer data in a report.

We will acknowledge a report, tell you whether it is in scope, and say what we
intend to do. There is no bug bounty.

## Secrets in this repository

**No secret is stored in this repository.** The values present in client
configuration files are Firebase *client* identifiers (project id, app id, API
key, sender id) and a Stripe *publishable* key placeholder. Client identifiers
are, by design, shipped inside a mobile or web binary; they are not
authentication secrets and they grant no access on their own.

What must never be committed, and is excluded by `.gitignore`:

- service-account JSON keys and any private key material
- Stripe secret keys, webhook signing secrets and restricted keys
- keystores, `key.properties`, signing certificates
- `.env` and `.dev.vars` files

If you believe a real secret has been committed, report it privately using the
flow above rather than opening an issue.
