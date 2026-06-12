# Zeval Engine — Usage Guide

> **This guide has moved.** It described an older, insecure API (unauthenticated
> tenant/key creation) that no longer exists. For current, runnable usage see:
>
> - **[Examples & Recipes](examples.md)** — scenario-driven walkthroughs
>   (role hierarchies, groups, folder inheritance, intersection/exclusion,
>   zookies, watch, and a full "mini Drive" model).
> - **[README](../README.md)** — concepts, entities, and the full REST reference.

Quick orientation:

- **Create a tenant** → from the dashboard (`/dashboard/tenants`); the creator
  becomes the owner. There is no tenant-creation API.
- **Create an API key** → from the dashboard (`/dashboard/api-keys`); copy the
  raw key once. Authenticate API calls with `Authorization: Bearer <raw_key>` —
  the tenant is derived from the key.
- **Everything else** (`/check`, `/tuples`, `/namespaces`, `/watch`) → see
  [examples.md](examples.md).
