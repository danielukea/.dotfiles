# Making an Agent

Guide to building effective AI agents and multi-agent workflows with Claude.

## Multi-Agent Parallelism

Running multiple Claude sessions concurrently is the single biggest productivity unlock. Instead of treating Claude as a single-threaded assistant:

- Spin up 2-3 Claude Code sessions (separate terminals or worktrees)
- Assign each a distinct, independent task
- Switch attention only when a result is ready
- Treat AI capacity like compute threads - queue up work

Example: One session generates a new feature while another debugs a failing test.

## Agent Specialization

Agents are not one big monolithic brain - they're more effective as a fleet of smaller experts:

- **Coding agent**: Focused on writing and modifying code
- **Review agent**: Dedicated to testing and code review
- **Documentation agent**: Generates and updates docs

Each subagent has its own context optimized for its function. Specialization brings reliability through constraint and makes debugging easier.

## Plan Mode Workflow

Always start complex tasks with a planning phase:

1. Prompt Claude to enter plan mode
2. Have it outline steps, files to change, test strategy
3. Review the plan (consider using a second agent as reviewer)
4. Only then let the agent execute

This prevents the failure mode of an agent rushing into wrong or chaotic changes. Course-correcting at the plan stage is much easier than after code has been written.

## Verification Loops

**Probably the most important thing**: always give Claude a way to validate its work.

- For coding: run tests, compile code, launch the app
- Build verification steps into skills
- Have the agent summarize whether outcomes match expectations
- Allow iteration if verification fails

Giving Claude a way to test and correct itself can improve quality 2-3x over a single-pass approach.

## Post-Tool-Use Hooks

Augment agents with automatic guardrails:

- **Auto-format**: Run formatter/linter after code generation
- **Style enforcement**: Scan generated text for guidelines
- **Safety checks**: Validate outputs before finalizing

Claude's output is usually well-formatted, but that last 10% polish prevents CI failures and saves human review time.

## Model Selection

Choose the model variant that best suits the task:

- **Opus (thinking mode)**: Complex coding, critical analysis - a correct but slow answer beats a fast wrong answer
- **Sonnet**: General tasks with good balance
- **Haiku**: Trivial or interactive tasks where speed matters more than depth

Optimize for cost per successful outcome, not cost per token. The time saved by not correcting mistakes is significant.

## Safety Boundaries

As you give agents more autonomy:

- Set clear policies on what's allowed without confirmation
- Use skills to encapsulate only trusted operations
- Require human approval for sensitive/destructive actions
- Monitor and log agent actions for audit trails
- Pre-approve only truly safe operations; queue everything else for review

## External Memory

An agent's context window is transient. Store long-term guidance externally:

- Load CLAUDE.md or knowledge skills at session start
- Save tricky solutions to knowledge base skills
- This turns the agent into a continually learning system
