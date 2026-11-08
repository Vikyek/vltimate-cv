# Agent Guidelines

## Commit & Git Conventions
When completing tasks and committing changes, follow these rules:

1. **Imperative Mood and Brevity**:
   - Start the subject line with an imperative verb (`feat`, `fix`, `docs`, `refactor`).
   - Keep the subject line under 72 characters.

2. **Focus on the "Why"**:
   - Explain motivation and problem solved before listing technical bullet points.

3. **Security & Privacy Invariant**:
   - Never commit personal profiles, `config/user_constraints.md`, API keys, PATs, or encrypted vault archives.
   - Run `pytest` and verify `PKGBUILD` / `.SRCINFO` alignment on every release change.
