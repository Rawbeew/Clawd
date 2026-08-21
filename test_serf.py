"""Tests for serf.py — memory store, tool registry, autonomous loop."""
import json
import os
import sys
import tempfile
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))

# point MEMORY_FILE at a temp location before importing
_tmp = tempfile.mkdtemp()
import serf  # noqa: E402

serf.MEMORY_FILE = Path(_tmp) / "memory.json"


class TestMemory:
    def setup_method(self):
        if serf.MEMORY_FILE.exists():
            serf.MEMORY_FILE.unlink()

    def test_remember_creates_episode(self):
        ep = serf.remember("test fact alpha")
        assert ep["text"] == "test fact alpha"
        assert "t" in ep

    def test_recall_filters_by_query(self):
        serf.remember("favorite color is teal")
        serf.remember("grocery list has eggs")
        hits = serf.recall("color")
        assert len(hits) == 1
        assert "teal" in hits[0]["text"]

    def test_recall_limit(self):
        for i in range(10):
            serf.remember(f"episode number {i}")
        assert len(serf.recall(limit=3)) == 3

    def test_memory_persists_to_disk(self):
        serf.remember("persist me")
        data = json.loads(serf.MEMORY_FILE.read_text(encoding="utf-8"))
        assert any(e["text"] == "persist me" for e in data["episodes"])


class TestTools:
    def test_registry_has_builtins(self):
        assert "store_fact" in serf._TOOLS
        assert "query_memory" in serf._TOOLS

    def test_store_and_query_roundtrip(self):
        serf.store_fact.__self__ if False else None
        r = serf._TOOLS["store_fact"]["fn"]("roundtrip fact")
        assert "t" in r
        hits = serf._TOOLS["query_memory"]["fn"]("roundtrip")
        assert any("roundtrip" in h for h in hits)


class TestHeuristicPlanner:
    def test_retrieve_goal_routes_to_query(self):
        d = serf._heuristic("what is my favorite color?", "goal received: ...")
        assert d == ("query_memory", {"query": "favorite color"})

    def test_store_goal_routes_to_fact(self):
        d = serf._heuristic("remember my cat is loud", "goal received: ...")
        assert d == ("store_fact", {"fact": "remember my cat is loud"})

    def test_unknown_goal_returns_none(self):
        assert serf._heuristic("buy stocks", "goal received: ...") is None


class TestRunLoop:
    def test_run_stops_after_answer(self):
        serf.remember("the answer is 42")
        trace = serf.run("what is my the answer?")  # heuristic pattern: "what is my" -> query_memory
        assert len(trace) >= 1
        # must not loop to max_steps
        assert trace[-1]["step"] <= 3

    def test_run_respects_max_steps(self):
        trace = serf.run("do something impossible", max_steps=2)
        assert all(s["step"] <= 2 for s in trace)

    def test_pluggable_planner_called(self):
        calls = []
        def fake_planner(goal, obs):
            calls.append((goal, obs))
            return None
        with mock.patch.object(serf, "_planner", fake_planner):
            # set_planner sets module global; use it directly
            pass
        old = serf._planner
        serf.set_planner(fake_planner)
        try:
            serf.run("anything", max_steps=1)
            assert len(calls) == 1
        finally:
            serf.set_planner(old)
