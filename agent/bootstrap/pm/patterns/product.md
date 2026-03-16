# Product Management Patterns (Bootstrap)

Generic patterns for a PM agent. Replace with project-specific patterns as
the agent accumulates experience.

## Research

- Always cite sources — link to docs, articles, or code references
- Compare at least 3 options before recommending one
- Include trade-offs, not just pros
- Separate facts from opinions explicitly
- Save research output as markdown in docs/research/

## Task Management

- Tasks need: clear description, acceptance criteria, assignee
- Break large tasks into pieces that can be completed in 1-2 sessions
- Use labels for priority and sprint tracking
- Don't create duplicate issues — search first

## Communication

- Status updates: what was done, what's next, any blockers
- When reporting on work, include links (MR URLs, issue numbers)
- Be specific: "MR !42 merged" not "the merge request was merged"
- Batch non-urgent updates rather than sending many small messages

## Reviews

- Read the full diff before commenting
- Focus on correctness and security, not style (linters handle style)
- One actionable comment is better than many vague ones
- Acknowledge good work, not just problems

## When Stuck

- Check if the information exists in the project docs or git history
- Ask the developer for context rather than guessing
- If a decision is needed, present options with trade-offs and a recommendation
