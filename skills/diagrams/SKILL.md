---
name: diagrams
description: PlantUML diagram standard. Use when creating diagrams, flowcharts, sequence diagrams, entity diagrams, or when the user mentions "diagram", "diagrama", "plantuml", "sequence", "flowchart", "entity diagram", "C4".
model: haiku
effort: low
---

# Diagrams Standard (PlantUML)

All diagrams in documentation MUST use PlantUML. No Mermaid, no ASCII art, no external image tools. PlantUML is the single standard for all visual documentation.

## Where and How

| Context | Format | Tool |
|---------|--------|------|
| **Obsidian vault** (any .md) | ` ```plantuml ` code block with `@startuml`/`@enduml` | Obsidian PlantUML plugin renders live |
| **GitHub PR body** | `![Title](PNG URL)` | `python3 ~/.claude/scripts/plantuml_encode.py /tmp/diagram.puml` |
| **Confluence** | ` ```plantuml ` code block in the Obsidian source file | Convert to PNG only when publishing |

**Diagram Popup plugin (installed):** All rendered diagrams (PlantUML, Mermaid, Graphviz) can be opened in a draggable, zoomable popup in Obsidian. This means:
- Complex diagrams are viable in vault notes (user can zoom to read details)
- No need to simplify diagrams for readability at inline scale
- Architecture diagrams, large sequence diagrams, and entity models can include full detail

**Rules:**
- NEVER generate PNG files for Obsidian vault documents. The plugin renders the code blocks directly.
- ALWAYS keep PlantUML source in the Obsidian file (editable, versionable).
- For GitHub PRs: extract PlantUML blocks to `/tmp/<name>.puml`, encode to PNG URL, replace in PR body. Keep source in Obsidian.
- Diagrams ALWAYS in English, regardless of the document language.

## When to Include Diagrams

| Document type | Required diagrams | Optional |
|---------------|-------------------|----------|
| **Feature discovery** | Sequence (main flow) | C4 Context |
| **Implementation plan** | Sequence (main flow), Data Model | Decision Flow, C4 Component |
| **Investigation/Bug** | Sequence (failure flow) | Before/After state |
| **PR Notes** | Sequence (what changed) | Data Model (if schema changed) |
| **Confluence doc** | Architecture Overview, Sequence, Data Model | Decision Flow, Data Flow |
| **Runbook** | C4 Context, C4 Container | C4 Component |
| **Test plan** | Sequence (test scenario flow) | Decision Flow |
| **ADR** | C4 Component (options comparison) | Sequence (proposed flow) |

Minimum: every document that describes a flow or data change MUST have at least one Sequence Diagram.

## Style Guide

### Base Config (always include)

```
!theme plain
skinparam backgroundColor #FEFEFE
skinparam defaultTextAlignment center
skinparam padding 5
```

### Color Palette

| Color | Hex | Usage |
|-------|-----|-------|
| Light Blue | `#E3F2FD` / `#BBDEFB` | API Layer, External Systems, Input/Output |
| Orange | `#FFF3E0` / `#FFE0B2` | Backend Services, Business Logic |
| Yellow | `#FFECB3` / `#FFF9C4` | Processing, Jobs, Decisions |
| Green | `#E8F5E9` / `#C8E6C9` | Database, Success Actions |
| Purple | `#F3E5F5` | Frontend, Models |
| Red | `#FFCDD2` | Errors, Skip Actions |

### Best Practices

1. **Directional arrows**: `-down->`, `-up->`, `-left->`, `-right->` to control layout
2. **Group related elements**: `together {}` or `box "Name" #Color`
3. **Sequence diagrams**:
   - `skinparam sequenceMessageAlign center`
   - `skinparam responseMessageBelowArrow true`
   - `activate/deactivate` for execution time
   - `== Section ==` separators to group phases
4. **Entity diagrams**:
   - `skinparam linetype ortho` for straight lines
   - New fields in `**bold**`
   - `--` separators between field groups
5. **Decision Flow** (for complex logic):
   - Numbered stages with `rectangle`: 1. Input, 2. Decision, 3. Actions, 4. Complete
   - Color by stage: input (`#E3F2FD`), decision (`#FFF9C4`), success (`#C8E6C9`), error (`#FFCDD2`)
   - `note right of` for explanations
   - Arrow labels in bold: `: **YES**`, `: **NO**`
   - Do NOT use Activity Diagram `if/else` syntax (unstable rendering)
6. **Notes**: `note right` in sequence diagrams, `note right of <element>` in others

## Diagram Types Reference

### C4 Context (system scope)
```
rectangle "**System**\n(Description)" as sys #E8F4FD
```

### C4 Component (internal components)
```
rectangle "**Layer Name**" as layer #E3F2FD {
    rectangle "Component" as comp
}
```

### Data Model (entity relationships)
```
entity "**table_name**" as tbl {
  * id : UUID <<PK>>
  --
  **new_field** : TYPE
}
```

### Sequence (data flows)
```
box "Service" #E8F5E9
    participant "API" as api
end box
```

### Decision Flow (business logic)
```
rectangle "**1. Input**" as input #E3F2FD { }
rectangle "**2. Decision**" as decision #FFF9C4 { }
rectangle "**3. Actions**" as actions { }
```

### Data Flow (sync/batch)
```
rectangle "**Step 1: Input**" as step1 #E3F2FD {
    rectangle "Source\n**Value**" as source #BBDEFB
}
```

## Templates

Full templates with all diagram types:
- Feature diagrams: `Templates/Feature-Diagrams.md`
- Confluence docs: `Templates/Confluence-Technical-Doc.md`
- C4 examples: `Runbooks/svc-experiences/diagrams/`

## GitHub PR Encoding

Script: `~/.claude/scripts/plantuml_encode.py`

```bash
# Get PNG URL for PR body
python3 ~/.claude/scripts/plantuml_encode.py /tmp/diagram.puml

# Download PNG file
python3 ~/.claude/scripts/plantuml_encode.py /tmp/diagram.puml /path/to/output.png
```

- User-Agent header required (PlantUML server returns 403 without it). Script handles this.
- URLs are deterministic (same source = same URL).
- No Java or PlantUML installation needed.
