# Backend development rules

- Use TDD for every FastAPI behavior change: add a failing regression or contract test first, implement the smallest fix, then run `cd backend && uv run pytest`.
- Keep tenant-scoped data filtered by the authenticated profile's `tenant_id`; never accept a tenant ID from an ordinary tenant user as an authorization substitute.
- Do not expose API tokens, encrypted token values, password hashes, or JWT secrets in API responses, errors, or logs.
