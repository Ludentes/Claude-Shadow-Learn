# Frontend Patterns

**Source skill:** none (manual)
**Last updated:** 2026-03-01
**Sessions learned from:** 2

## Architecture (FSD)

- Use Feature-Sliced Design: app/ → pages/ → features/ → shared/
- Each feature slice has: ui/, model/, api/, lib/ subdirectories
- Barrel exports (index.ts) at each slice boundary
- Never import from a lower layer to a higher layer

## Components

- Use shadcn/ui for all UI components
- Don't wrap simple shadcn components — only wrap when adding custom behavior
- Component files: PascalCase.tsx, one component per file
- Use shadcn/ui for all UI components
- Keep component props explicit — no ...rest spreading on custom components

## Imports

- Import order: react → external libs → shared/ → features/ → local
- Never use relative imports crossing slice boundaries — always @/shared/*, @/features/*
- Use meaningful variable names in destructured imports

## Styling

- Tailwind only — no CSS modules, no styled-components
- Use cn() helper from @/shared/lib/utils for conditional classes
- Design tokens in tailwind.config.ts, not CSS variables
