# Serf

**Digital serf: a persistent local agent with memory, tools, and autonomous task execution.**

Serf is a minimal autonomous agent loop in pure Python stdlib — no dependencies,
no API keys required for the core loop. Bring your own LLM endpoint via
`set_planner()` for full autonomy, or run the built-in heuristic planner to see
the plan→act→reflect cycle immediately.

## Design

- **Persistent memory** — JSON episode store (`memory.json`), timestamped, queryable
- **Tool registry** — decorator-registered plain functions; the planner picks which to call
- **Autonomous loop** — goal → plan → act → observe → done; stops when answered or budget exhausted
- **Pluggable planning** — keyword heuristic out of the box, any LLM via `set_planner()`
- **Stdlib only** — `json`, `datetime`, `argparse`. Nothing else.

## Quick start

```bash
python serf.py --goal "remember my favorite color is teal"
python serf.py --goal "what is my favorite color?"
python serf.py --demo   # walkthrough of the full loop
```

## Use as a library

```python
import serf

serf.remember("deploy key lives in vault")
serf.recall("deploy")            # -> [{'t': ..., 'text': 'deploy key lives in vault'}]

trace = serf.run("what do you know about deploy keys?")
for step in trace:
    print(step)

# plug in an LLM planner (any function: goal, observation -> ("tool", args) | ("done", summary) | None)
def my_planner(goal, observation):
    ...  # call your LLM here
    return ("store_fact", {"fact": "..."})

serf.set_planner(my_planner)
```

## Development

```bash
pip install pytest ruff
python -m pytest test_serf.py -q   # run tests
ruff check serf.py test_serf.py    # lint
python serf.py --demo              # smoke test
```

CI runs tests on Python 3.11–3.13 plus lint and a demo smoke test on every push.

## License

MIT
