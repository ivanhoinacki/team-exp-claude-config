# Codex agent model defaults

Use the model and reasoning effort selected by the user or inherited from the parent.
Do not translate Claude model names into Codex model overrides.

The source researcher, reviewer, copilot and implementer roles pin `gpt-5.4-mini`
and low reasoning effort in their agent TOML files. Other portable roles inherit the
parent. Explicit project policy or a user request can select a different model.

Codex skills do not change the model through Claude-only `model:` frontmatter.
Use standalone agent definitions for role-specific settings and the active session
configuration for the main model. Do not force a `model` argument on every spawn.

Delegate only when the user or applicable project/skill instructions request it.
