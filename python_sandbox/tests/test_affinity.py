"""
Tests for the tag-affinity decision layer.
Run:  python -m pytest tests/test_affinity.py -v
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from core.simulation.affinity_matrix import (
    AFFINITY_MATRIX,
    ATTACK_THRESHOLD,
    TRADE_THRESHOLD,
    FLEE_THRESHOLD,
    compute_affinity,
    derive_agent_tags,
    derive_sector_tags,
)

# ---------------------------------------------------------------------------
# compute_affinity
# ---------------------------------------------------------------------------

def test_compute_affinity_positive_pair():
    """Trader + MARKET_HUB should yield a positive score."""
    score = compute_affinity(["TRADER"], ["MARKET_HUB"])
    assert score > 0.0, f"Expected positive, got {score}"


def test_compute_affinity_negative_pair():
    """AGGRESSIVE + MILITARY should be negative."""
    score = compute_affinity(["AGGRESSIVE"], ["MILITARY"])
    assert score <= 0.0, f"Expected <=0, got {score}"


def test_compute_affinity_empty_tags():
    """Empty tag lists → zero."""
    assert compute_affinity([], []) == 0.0
    assert compute_affinity(["TRADER"], []) == 0.0
    assert compute_affinity([], ["WEALTHY"]) == 0.0


def test_compute_affinity_symmetric_magnitude():
    """Order of actor/target may differ, but both should be nonzero if pair exists."""
    s1 = compute_affinity(["PIRATE"], ["WEALTHY"])
    s2 = compute_affinity(["WEALTHY"], ["PIRATE"])
    # At least one direction should be nonzero
    assert s1 != 0.0 or s2 != 0.0


def test_attack_threshold_reachable():
    """At least one tag combination should reach ATTACK_THRESHOLD."""
    found = False
    for (a, b), v in AFFINITY_MATRIX.items():
        if v >= ATTACK_THRESHOLD:
            score = compute_affinity([a], [b])
            if score >= ATTACK_THRESHOLD:
                found = True
                break
    assert found, "No pair reaches ATTACK_THRESHOLD"


# ---------------------------------------------------------------------------
# derive_agent_tags
# ---------------------------------------------------------------------------

def test_derive_agent_tags_basic():
    """Agent with high aggression should get 'aggressive' tag."""
    char = {"personality_traits": {"aggression": 0.9, "greed": 0.3,
                                     "risk_tolerance": 0.5, "loyalty": 0.5}}
    agent = {"agent_role": "military", "hull_integrity": 1.0,
             "cash_reserves": 500.0, "propellant_reserves": 50.0,
             "sentiment_tags": []}
    tags = derive_agent_tags(char, agent, has_cargo=False)
    assert "AGGRESSIVE" in tags
    assert "MILITARY" in tags


def test_derive_agent_tags_desperate():
    """Low hull + low cash → DESPERATE."""
    char = {"personality_traits": {"aggression": 0.5, "greed": 0.5,
                                     "risk_tolerance": 0.5, "loyalty": 0.5}}
    agent = {"agent_role": "trader", "hull_integrity": 0.1,
             "cash_reserves": 0.0, "propellant_reserves": 50.0,
             "sentiment_tags": []}
    tags = derive_agent_tags(char, agent, has_cargo=False)
    assert "DESPERATE" in tags


# ---------------------------------------------------------------------------
# derive_sector_tags
# ---------------------------------------------------------------------------

def test_derive_sector_tags_needs_state():
    """Smoke test — just make sure it doesn't crash on a bare GameState mock."""

    class FakeState:
        grid_dominion = {"s1": {"security_level": 0.9, "pirate_activity": 0.0}}
        grid_stockpiles = {"s1": {"commodity_stockpiles": {"commodity_ore": 100}}}
        world_hidden_resources = {"s1": {"mineral_density": 5.0, "propellant_sources": 2.0}}
        world_topology = {"s1": {"sector_type": "core", "connections": ["s2"]}}
        world_hazards = {"s1": {"radiation_level": 0.0}}
        grid_wrecks = {}
        grid_sector_tags = {}
        hostile_population_integral = {}

    tags = derive_sector_tags("s1", FakeState())
    assert isinstance(tags, list)
    # High security → should get 'SECURE'
    assert "SECURE" in tags


# ---------------------------------------------------------------------------
# Threshold constants sanity
# ---------------------------------------------------------------------------

def test_thresholds_ordered():
    assert FLEE_THRESHOLD < 0 < TRADE_THRESHOLD < ATTACK_THRESHOLD
