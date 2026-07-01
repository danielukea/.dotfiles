# Testing Skills and Agents

Guide to evaluation, iteration, and continuous improvement.

## Evaluation-First Development

Before building a new skill or agent feature:

1. Define what success looks like
2. Identify representative tasks the AI should handle
3. Run Claude on these tasks without the skill
4. Note where it fails or needs help
5. Those gaps inform what to teach

Write evaluation tests first - TDD for AI skills.

## Iterative Refinement

Don't expect perfection on the first draft:

- Use Claude during development to debug its own instructions
- If a skill is half-working, ask "why didn't you follow step 3?"
- Watch how behavior changes with each iteration
- Make one change at a time to isolate effects

## Transcript Analysis

Keep logs of agent actions to pinpoint failures:

- Where did the agent go off track?
- What information was missing?
- Which step was misinterpreted?
- Was the skill loaded at the right time?

## Production Monitoring

Set up mechanisms to capture feedback:

- Log when AI outputs are incorrect
- Track human corrections
- Update skills/CLAUDE.md based on patterns
- Hold periodic "AI review" meetings

Treat the agent as an evolving team member - give it performance reviews.

## Security Considerations

### Skill Auditing
- Only install skills from trusted sources
- Audit community skills before importing
- Read through SKILL.md and scripts
- Check for data exfiltration or dangerous commands

### Code Review
- Review external dependencies
- Verify network calls are safe
- Avoid hard-coding credentials or sensitive data
- Follow frontmatter restrictions

### Team Practices
- Code-review skills like any other code
- Maintain audit trails of agent actions
- Define clear policies for sensitive operations

## Continuous Improvement

The AI field evolves rapidly:

- Watch official documentation updates
- Share knowledge from articles and examples
- Refine skills to leverage new capabilities
- Patch pitfalls discovered by the community
- Encourage team knowledge sharing
