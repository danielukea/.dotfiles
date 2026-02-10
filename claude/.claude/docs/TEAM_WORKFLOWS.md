# Team Workflows

Guide to deploying skills and agents across teams.

## Version-Control Skills

Maintain custom skills in a repository:

- Store skills in source control
- Treat skill definitions as code
- Commit skills to your project repository
- Update skills via pull requests
- Track changes and enable peer review

This ensures quality and fosters collective ownership.

## PR Integration

Include Claude in code review workflows:

- Tag Claude agent to review changes
- Have agent update CLAUDE.md with new insights
- Create feedback loop where AI produces work AND learns
- Place the agent where collaboration happens

Example workflow:
1. Developer opens PR
2. Claude reviews changes
3. Claude notes if a pattern should be avoided
4. Knowledge base gets updated

## Shared Permissions

Establish team-wide permission policies:

- Avoid blanket "dangerously skip permissions" mode
- Maintain shared set of pre-approved safe actions
- Review permissions as a team
- Make changes deliberate and transparent

Example policy:
- **Auto-approve**: Running tests, linters, formatters
- **Require confirmation**: Deployments, data deletion, production access

## Workflow Automation

Convert frequent tasks to shared skills:

- If a task is done often, skill it
- Saves cumulative team hours
- Ensures consistent execution
- Empowers new team members immediately

Examples:
- Code style formatting
- Changelog updates
- Weekly report generation
- Tech debt scanning

## Onboarding

Document your AI setup for new team members:

- List available skills and what they do
- Document MCP connectors and how to use them
- Provide example prompts
- Create "Using Claude at Our Company" guide

Include:
- Skill catalog with descriptions
- Permission policies
- Common workflows
- Troubleshooting tips

## Knowledge Distribution

Share learnings across the organization:

- Develop a library of common skills
- Standardize behavior across teams
- Enable skill contributions from all members
- Review and merge skill improvements
