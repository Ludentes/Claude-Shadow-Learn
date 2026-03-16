# Shadow Learning — Agent Runtime

Shadow learning for simulated agents (Galatea beta-level simulations).

## What This Does

Gives simulated developer and PM agents a knowledge accumulation system:

1. **Cold start** — generic role-based patterns (coding for devs, product for PMs)
2. **Seeding** — optionally bootstrap from a real developer's shadow-learned patterns
3. **Work-to-knowledge** — after each completed task, extract reusable patterns
4. **Accumulation** — agent gets smarter over time as patterns build up

The system works even with zero prior experience (cold start patterns provide a baseline).

## Quick Start

```bash
# Initialize a developer agent
./agent/init-agent.sh beki developer data/agents/beki \
  --name Beki --domain "Expo / React Native"

# Initialize a PM agent
./agent/init-agent.sh besa pm data/agents/besa \
  --name Besa --domain "Product management"

# Optionally seed from a real developer's patterns
./agent/seed-from-human.sh \
  ~/.claude/projects/-home-kirill-w-app/memory \
  data/agents/beki/memory

# Check agent health
./agent/health-agent.sh data/agents/beki
```

## Directory Structure

After init, each agent gets:

```
data/agents/beki/
├── CLAUDE.md              # Agent identity + shadow learning bootstrap
├── AGENTS.md              # Cross-tool instructions
├── memory/
│   ├── MEMORY.md          # Knowledge index
│   ├── patterns/
│   │   └── coding.md      # Learned patterns (starts with bootstrap)
│   ├── entities/           # People, services, systems
│   └── extracted-knowledge.md  # Staging area from work sessions
└── skills/
    └── work-to-knowledge/  # Post-task extraction skill
```

## Integration with Galatea

The coding adapter should:

1. **Before launching Claude Code** — read `{agent-dir}/memory/patterns/*.md` and inject into the system prompt, or point Claude Code to the agent's `CLAUDE.md`
2. **After task completion** — run work-to-knowledge extraction using the task summary from `TaskState.progress[]` and `artifacts[]`
3. **Periodically** — run `health-agent.sh` to check knowledge store health

### System Prompt Integration

The generated `CLAUDE.md` can be included in the coding adapter's system prompt:

```typescript
const agentClaudeMd = fs.readFileSync(`${agentDir}/CLAUDE.md`, 'utf-8');
const patterns = glob.sync(`${agentDir}/memory/patterns/*.md`)
  .map(f => fs.readFileSync(f, 'utf-8'))
  .join('\n\n');

const systemPrompt = `${agentClaudeMd}\n\n## Learned Patterns\n\n${patterns}`;
```

### Work-to-Knowledge Flow

```
Task completes (status → "done")
  → Galatea calls work-to-knowledge with:
    - task_summary: TaskState.progress.join(', ')
    - task_type: TaskState.type
    - outcome: success | partial | failed
    - memory_dir: agent's memory path
    - corrections: any feedback received
  → Patterns extracted and staged
  → Next task benefits from updated patterns
```

## Cold Start vs Seeded

| Aspect | Cold Start | Seeded from Human |
|--------|-----------|-------------------|
| Patterns | Generic role-based (5-10 rules) | Real project patterns (20+ rules) |
| Entities | Empty | Copied from human memory |
| Quality | Functional but generic | Project-specific from day 1 |
| Learning curve | Agent needs 5-10 tasks to build useful patterns | Agent starts with useful patterns |

**Recommendation**: Seed from human patterns when available. Cold start is the fallback, not the goal.

## Scripts

| Script | Purpose |
|--------|---------|
| `init-agent.sh` | Initialize agent with memory structure, bootstrap patterns, CLAUDE.md |
| `seed-from-human.sh` | Copy patterns from a real developer's memory to an agent |
| `health-agent.sh` | Check agent's knowledge store health |

## Bootstrap Patterns

Role-specific starting patterns in `bootstrap/`:

- `developer/patterns/coding.md` — architecture, process, quality, git conventions
- `pm/patterns/product.md` — research, task management, communication, reviews
