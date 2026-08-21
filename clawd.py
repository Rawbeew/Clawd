#!/usr/bin/env python
"""Clawd — digital serf: persistent local agent with memory, tools, autonomy.

Pure stdlib. Run `python clawd.py --demo` for a walkthrough.
"""
import argparse
import json
import time
from datetime import datetime, timezone
from pathlib import Path

MEMORY_FILE = Path(__file__).parent / "memory.json"

# ---------------------------------------------------------------- memory

def _load_memory():
    if MEMORY_FILE.exists():
        return json.loads(MEMORY_FILE.read_text(encoding="utf-8"))
    return {"episodes": []}

def _save_memory(mem):
    MEMORY_FILE.write_text(json.dumps(mem, indent=2), encoding="utf-8")

def remember(text):
    mem = _load_memory()
    ep = {"t": datetime.now(timezone.utc).isoformat(), "text": text}
    mem["episodes"].append(ep)
    _save_memory(mem)
    return ep

def recall(query=None, limit=5):
    eps = _load_memory()["episodes"]
    if query:
        q = query.lower()
        eps = [e for e in eps if q in e["text"].lower()]
    return eps[-limit:]

# ---------------------------------------------------------------- tools

_TOOLS = {}

def tool(name, desc):
    def deco(fn):
        _TOOLS[name] = {"fn": fn, "desc": desc}
        return fn
    return deco

@tool("store_fact", "Persist a fact to long-term memory")
def store_fact(fact: str):
    return remember(fact)

@tool("query_memory", "Search past episodes for a keyword")
def query_memory(query: str):
    hits = recall(query)
    return [h["text"] for h in hits] or ["(no matches)"]

# ---------------------------------------------------------------- planner

_planner = None  # set_planner(fn(goal, observation) -> (tool_name, args) | None)

def set_planner(fn):
    """fn(goal, last_observation) -> (tool_name, kwargs_dict) or None to stop."""
    global _planner
    _planner = fn

def run(goal, max_steps=8):
    """Autonomous loop: plan -> act -> observe -> reflect."""
    trace, obs = [], f"goal received: {goal}"
    for step in range(max_steps):
        if _planner:
            decision = _planner(goal, obs)
        else:  # default heuristic planner: keyword routing over the registry
            decision = _heuristic(goal, obs)
        if not decision or (decision[0] == "query_memory" and not str(obs).startswith("goal")):
            break  # answered — stop reflecting
        name, kwargs = decision
        entry = _TOOLS.get(name)
        prev_obs = obs
        obs = entry["fn"](**kwargs) if entry else f"unknown tool {name}"
        if obs == prev_obs:
            break  # no new information
        trace.append({"step": step + 1, "tool": name, "args": kwargs,
                      "observation": str(obs)[:200]})
    return trace

def _heuristic(goal, obs):
    g = goal.lower()
    if "what is my" in g or "recall" in g or "remember?" in g:
        key = g.replace("what is my", "").replace("?", "").strip()
        return ("query_memory", {"query": key or ""})
    if "remember" in g and (isinstance(obs, str) and obs.startswith("goal")):
        fact = goal.split("is", 1)[-1].strip().rstrip(".")
        return ("store_fact", {"fact": goal})
    return None

# ---------------------------------------------------------------- cli

def demo():
    print("== Clawd demo: autonomous loop ==")
    t1 = run("remember my favorite color is teal")
    t2 = run("what is my favorite color?")
    for tr in (t1, t2):
        for s in tr:
            print(f"[{s['step']}] {s['tool']}({s['args']}) -> {s['observation']}")
    print("memory.json episodes:", len(_load_memory()["episodes"]))

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Clawd digital serf")
    ap.add_argument("--goal")
    ap.add_argument("--demo", action="store_true")
    args = ap.parse_args()
    if args.demo:
        demo()
    elif args.goal:
        for s in run(args.goal):
            print(f"[{s['step']}] {s['tool']}({s['args']}) -> {s['observation']}")
    else:
        ap.print_help()
