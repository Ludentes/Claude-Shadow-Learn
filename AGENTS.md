# AGENTS.md

This project uses shadow learning for continuous improvement from user corrections.

## Knowledge Store

Before work that involves judgment (reviews, architecture, writing), check:
- `docs/playbooks/*.md` — repeatable procedures (deploy, setup, release)

When the user corrects your output, note the correction explicitly in your response.

## Conventions

- Hard rules (import order, commit format) belong in linters and hooks, not instructions
- Memory is for things requiring judgment — tone, structure, quality bar
- Keep instruction files concise — overly long files degrade agent performance
