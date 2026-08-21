# Clawd

**Digital serf: a persistent local agent with memory, tools, and autonomous task execution.**

Clawd is a minimal, dependency-free autonomous agent loop in pure Python stdlib.
No API keys required to run the core loop — bring your own LLM endpoint for full
autonomy, or run the built-in dry-run mode to see the plan→act→reflect cycle.

## Design

- **Persistent memory** — JSON file store (`memory.json`) with timestamped episodes
- **Tool registry** — plain functions registered by decorator; the agent plans which to call
- **Autonomous loop** — goal → plan → act → observe → reflect, until done or budget exhausted
- **Stdlib only** — `json`, `urllib`, `datetime`. Nothing else.

## Quick start

```bash
python clawd.py --goal "remember my favorite color is teal"
python clawd.py --goal "what is my favorite color?"
python clawd.py --demo   # dry-run walkthrough of the loop
```

## Status

Core loop, memory store, and tool registry are implemented. LLM-backed planning
is pluggable via `set_planner()` — wire any OpenAI-compatible endpoint.

## License

MIT
