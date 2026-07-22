# Anatomy — files and frontmatter

The generic structure of a skill. (This is portable: how the skill is *installed* or
discovered on a particular machine is that machine's concern, not the skill's — keep
that out of the skill folder.)

## Folder layout

A skill is a directory whose only required file is `SKILL.md`:

```
skill-name/
├── SKILL.md              # required: frontmatter + the always-loaded body
├── references/           # optional: detail loaded on demand (docs, deep dives)
├── templates/            # optional: fill-in artifacts to copy into output
└── scripts/              # optional: executable helpers (can run without loading into context)
```

Add the optional dirs only when you have execute-time detail to offload. A one-concept
skill is just a `SKILL.md`. Reach for `references/` when the SKILL.md would otherwise
cross the decide/do line (see `principles.md`); reach for `scripts/` when the same
deterministic work would otherwise be redone by hand on every run.

## Frontmatter

YAML at the top of `SKILL.md`. Only three fields are commonly used:

```yaml
---
name: skill-name                    # required: kebab-case identifier, matches the folder
description: <trigger>              # required: how the skill is selected — see descriptions.md
allowed-tools: Read, Grep, Glob     # optional: restrict the tools the skill may use
---
```

- **`name`** — required. Kebab-case; match the directory name.
- **`description`** — required, and the most important field. It is the trigger; see
  `references/descriptions.md`. Single line or a YAML block scalar (`>`) both work.
- **`allowed-tools`** — optional. Narrow the tool set for a read-only knowledge skill
  (`Read, Grep, Glob`) or widen it for one that writes files and runs helpers. Honored
  by agents that support it and harmlessly ignored by those that don't.

Other fields exist for specific harnesses (e.g. `disable-model-invocation`,
`argument-hint`) — add them only when you actually need that behavior.

## Body

After the frontmatter, plain Markdown. Structure it by archetype:

- **Knowledge skill** — `# Title`, a short framing of what the lens optimizes for
  (say explicitly if there's *no* workflow), then `##` sections per principle. Detail
  pushed to `references/`.
- **Orchestration skill** — `# Title`, why-this-shape, usage, then the steps as a
  *toolkit, not a mandatory pipeline*. Reference knowledge skills by name instead of
  embedding them. Decision tables (Signal → action) and a fixed output-format block
  earn their keep here.
- **Thin delegator** — a handful of lines that exist so the skill is discoverable by
  name/description, pointing at the real source of truth. Don't duplicate that source.

Keep the body lean enough to scan. Lead with the gotchas — see the `## Gotchas` section
in `templates/SKILL.md.template`, which every new skill should carry and grow.
