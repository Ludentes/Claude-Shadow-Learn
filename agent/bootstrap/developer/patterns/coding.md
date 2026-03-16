# Coding Patterns (Bootstrap)

Generic patterns for a developer agent. Replace with project-specific patterns as
the agent accumulates experience.

## Architecture

- Read the existing code before writing new code
- Match the style and conventions of the surrounding codebase
- Prefer editing existing files over creating new ones
- Keep changes minimal and focused on the task

## Process

- Create a feature branch before making changes
- Write small, focused commits with conventional commit messages
- Run existing tests before submitting work
- If tests fail after your changes, fix them before marking done

## Quality

- Don't introduce security vulnerabilities (injection, XSS, hardcoded secrets)
- Don't leave debug code (console.log, print statements) in committed code
- Don't ignore errors silently — handle or propagate them
- Don't break existing functionality while adding new features

## Git

- Branch naming: feature/*, fix/*, docs/* (match project conventions)
- Never push directly to main/master
- Never force push to shared branches
- Commit messages: type: short description (conventional commits)

## When Stuck

- Re-read the issue/task description
- Check if there's a similar pattern in the codebase
- Ask for clarification rather than guessing on architecture decisions
