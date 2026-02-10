# Making a Skill

Guide to authoring effective Claude skills.

## Skill Anatomy

A skill is a directory containing:

```
my-skill/
├── SKILL.md          # Main instructions with YAML frontmatter
├── reference.md      # Optional: detailed reference docs
├── examples.md       # Optional: example inputs/outputs
└── scripts/          # Optional: executable utilities
    └── process.py
```

The SKILL.md begins with YAML frontmatter:

```yaml
---
name: process-pdfs
description: Extracts text and tables from PDF files. Use when the user asks to work with PDFs, forms, or document data.
---
```

## Conciseness

Be economical with tokens. Provide only what Claude truly needs:

- Assume Claude knows general concepts
- Focus on specifics of your workflow
- Litmus test: "Does Claude already know this? If yes, don't include it."
- Don't explain what a PDF is or how to install libraries

## Metadata

### Name (required, ≤64 characters)
- Lowercase, hyphenated
- Use verb+noun or gerund form
- Examples: `process-pdfs`, `analyze-spreadsheets`, `generate-reports`

### Description (required, ≤1024 characters)
- State what the skill does and when to use it
- Write in third person ("Processes..." not "I can process...")
- Include specific keywords/triggers
- Be precise, not vague

**Good**: "Extracts text and tables from PDF files, and fills PDF forms. Use when the user asks to work with PDFs, forms, or document data."

**Bad**: "Helps with documents"

## Single Purpose

Each skill should have one well-defined scope:

- Don't make monolithic skills that do everything
- Multiple focused skills > one broad skill
- Rule of thumb: if you do a task more than once a day, make it a skill
- Specialized skills are more reliable and easier to test

## Guidance Calibration

Match instruction detail to task fragility:

| Task Type | Approach |
|-----------|----------|
| Only one safe way (db migration) | Step-by-step instructions (low freedom) |
| Many acceptable solutions (summarizing) | High-level strategy/checklist (high freedom) |

Constrain where necessary, trust Claude's abilities where appropriate.

## Progressive Disclosure

Organize content in layers:

- Keep SKILL.md body under ~500 lines
- Offload ancillary details to secondary files
- Claude only reads additional files if the situation demands it
- Keeps initial context lean while providing depth on demand

Structure example:
- SKILL.md: Quick start, core workflow
- reference.md: Detailed API reference
- examples.md: Verbose examples
- forms.md: Specific templates

## Code Integration

Include scripts for deterministic operations:

```
scripts/
├── parse_pdf.py      # Extract structured data
├── validate.sh       # Run validation checks
└── format_output.py  # Standardize output format
```

- Certain tasks are more reliable via code than text manipulation
- Offloads computation from the model (saves tokens, reduces errors)
- Document what each script does
- Clarify in instructions when to read vs. run

## Testing

Skills may perform differently across model sizes:

- Test with all model variants you support
- Smaller models may need more explicit guidance
- Larger models may be confused by over-explaining
- Aim for instructions robust to different capability levels

## Iteration Process

Skill writing is iterative:

1. Install skill in Claude environment
2. Run test tasks
3. Monitor: Did it load at the right time? Follow steps correctly?
4. Adjust content or metadata
5. Ask Claude what went wrong and how to improve
6. Treat the skill as a living document
