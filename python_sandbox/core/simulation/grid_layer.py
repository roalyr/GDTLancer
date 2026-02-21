#
# PROJECT: GDTLancer
# MODULE: grid_layer.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_8
# LOG_REF: 2026-02-21 (TASK_7)
#

"""Tag-transition CA engine for economy, security, and environment layers."""

import random
from autoload import constants


class GridLayer:
    ECONOMY_LEVELS = ["POOR", "ADEQUATE", "RICH"]
    SECURITY_LEVELS = ["LAWLESS", "CONTESTED", "SECURE"]
    ENV_LEVELS = ["EXTREME", "HARSH", "MILD"]
    CATEGORIES = ["RAW", "MANUFACTURED", "CURRENCY"]

    def initialize_grid(self, state) -> None:
        state.colony_levels = state.colony_levels or {}
        for sector_id, data in state.world_topology.items():
            if sector_id not in state.sector_tags:
                state.sector_tags[sector_id] = ["STATION", "CONTESTED", "MILD", "RAW_ADEQUATE", "MANUFACTURED_ADEQUATE", "CURRENCY_ADEQUATE"]
            if sector_id not in state.colony_levels:
                state.colony_levels[sector_id] = data.get("sector_type", "frontier")
            if sector_id not in state.grid_dominion:
                state.grid_dominion[sector_id] = {
                    "controlling_faction_id": "",
                    "security_tag": self._security_tag(state.sector_tags[sector_id]),
                }
            if sector_id not in state.security_upgrade_progress:
                state.security_upgrade_progress[sector_id] = 0
            if sector_id not in state.security_downgrade_progress:
                state.security_downgrade_progress[sector_id] = 0
            if sector_id not in state.security_change_threshold:
                rng = random.Random(f"{state.world_seed}:sec_thresh:{sector_id}")
                state.security_change_threshold[sector_id] = rng.randint(
                    constants.SECURITY_CHANGE_TICKS_MIN,
                    constants.SECURITY_CHANGE_TICKS_MAX,
                )

    def process_tick(self, state, config: dict) -> None:
        new_tags = {}
        for sector_id in state.world_topology:
            current = list(state.sector_tags.get(sector_id, []))
            neighbors = state.world_topology.get(sector_id, {}).get("connections", [])
            neighbor_tags = [state.sector_tags.get(n, []) for n in neighbors]

            tags = self._step_economy(current, neighbor_tags, state, sector_id)
            tags = self._step_security(tags, neighbor_tags, state, sector_id)
            tags = self._step_environment(tags, state, sector_id)
            tags = self._step_hostile_presence(tags, state, sector_id)
            tags = self._step_colony_level(tags, state, sector_id)
            new_tags[sector_id] = self._unique(tags)

        state.sector_tags = new_tags
        for sector_id, tags in state.sector_tags.items():
            state.grid_dominion.setdefault(sector_id, {})["security_tag"] = self._security_tag(tags)

    def _step_economy(self, tags: list, neighbor_tags: list, state, sector_id: str) -> list:
        result = list(tags)
        world_age = state.world_age or "PROSPERITY"
        role_counts = self._role_counts_for_sector(state, sector_id)

        for category in self.CATEGORIES:
            level = self._economy_level(result, category)
            idx = self.ECONOMY_LEVELS.index(level)
            delta = 0

            # Homeostatic pressure (corruption / recovery)
            if level == "RICH":
                delta -= 1
            elif level == "POOR":
                delta += 1

            # World age influence
            if world_age == "DISRUPTION":
                delta -= 1
            elif world_age == "RECOVERY":
                delta += 2
            elif world_age == "PROSPERITY":
                delta += 1

            # Active commerce
            loaded_trade = self._loaded_trade_count_for_sector(state, sector_id)
            if loaded_trade > 0:
                delta += 1
            if role_counts.get("pirate", 0) > 0:
                delta -= 1

            if delta >= 1:
                idx = min(2, idx + 1)
            elif delta <= -1:
                idx = max(0, idx - 1)
            result = self._replace_prefix(result, f"{category}_", f"{category}_{self.ECONOMY_LEVELS[idx]}")

        return result

    def _step_security(self, tags: list, neighbor_tags: list, state, sector_id: str) -> list:
        result = list(tags)
        security = self._security_tag(result)
        idx = self.SECURITY_LEVELS.index(security)
        role_counts = self._role_counts_for_sector(state, sector_id)

        delta = 0

        # Homeostatic pressure (complacency / desperation)
        if security == "SECURE":
            delta -= 1
        elif security == "LAWLESS":
            delta += 1

        # World age influence
        if state.world_age == "DISRUPTION":
            delta -= 1
        elif state.world_age in ("PROSPERITY", "RECOVERY"):
            delta += 1

        # Agent presence
        if role_counts.get("military", 0) > 0:
            delta += 1
        if role_counts.get("pirate", 0) > 0:
            delta -= 1
        if "HOSTILE_INFESTED" in result:
            delta -= 1

        # Regional influence
        neighbor_idx = [self.SECURITY_LEVELS.index(self._security_tag(n)) for n in neighbor_tags if n]
        if neighbor_idx:
            avg = sum(neighbor_idx) / len(neighbor_idx)
            if avg > idx:
                delta += 1
            elif avg < idx:
                delta -= 1

        # Progress-counter gating (mirror of colony upgrade/downgrade pattern)
        up_progress = state.security_upgrade_progress.get(sector_id, 0)
        down_progress = state.security_downgrade_progress.get(sector_id, 0)
        threshold = state.security_change_threshold.get(
            sector_id, constants.SECURITY_CHANGE_TICKS_MIN
        )

        if delta >= 1:
            up_progress += 1
            down_progress = 0
        elif delta <= -1:
            down_progress += 1
            up_progress = 0
        else:
            up_progress = 0
            down_progress = 0

        if up_progress >= threshold and idx < 2:
            idx = min(2, idx + 1)
            up_progress = 0
        elif down_progress >= threshold and idx > 0:
            idx = max(0, idx - 1)
            down_progress = 0

        state.security_upgrade_progress[sector_id] = up_progress
        state.security_downgrade_progress[sector_id] = down_progress

        result = self._replace_one_of(result, {"SECURE", "CONTESTED", "LAWLESS"}, self.SECURITY_LEVELS[idx])
        return result

    def _step_environment(self, tags: list, state, sector_id: str) -> list:
        result = list(tags)
        idx = self.ENV_LEVELS.index(self._environment_tag(result))

        if state.world_age == "DISRUPTION":
            if idx == self.ENV_LEVELS.index("MILD"):
                idx = self.ENV_LEVELS.index("HARSH")
            elif idx == self.ENV_LEVELS.index("HARSH"):
                role_counts = self._role_counts_for_sector(state, sector_id)
                if role_counts.get("pirate", 0) > 0 or "HOSTILE_INFESTED" in result:
                    idx = self.ENV_LEVELS.index("EXTREME")
        elif state.world_age == "RECOVERY":
            idx = min(2, idx + 1)

        if self._sector_recently_disabled(state, sector_id):
            idx = 0

        result = self._replace_one_of(result, {"MILD", "HARSH", "EXTREME"}, self.ENV_LEVELS[idx])
        return result

    def _step_hostile_presence(self, tags: list, state, sector_id: str) -> list:
        result = [tag for tag in tags if tag not in {"HOSTILE_INFESTED", "HOSTILE_THREATENED"}]
        role_counts = self._role_counts_for_sector(state, sector_id)
        security = self._security_tag(tags)

        if security == "LAWLESS" and role_counts.get("military", 0) == 0:
            result.append("HOSTILE_INFESTED")
        elif security == "CONTESTED":
            result.append("HOSTILE_THREATENED")
        return result

    def _step_colony_level(self, tags: list, state, sector_id: str) -> list:
        level = state.colony_levels.get(sector_id, "frontier")
        levels = constants.COLONY_LEVELS
        up_progress = state.colony_upgrade_progress.get(sector_id, 0)
        down_progress = state.colony_downgrade_progress.get(sector_id, 0)

        economy_ok = all(
            req in tags or req.replace("_ADEQUATE", "_RICH") in tags
            for req in constants.COLONY_UPGRADE_REQUIRED_ECONOMY
        )
        security_ok = constants.COLONY_UPGRADE_REQUIRED_SECURITY in tags
        degrade = constants.COLONY_DOWNGRADE_SECURITY_TRIGGER in tags or any(req in tags for req in constants.COLONY_DOWNGRADE_ECONOMY_TRIGGER)

        if economy_ok and security_ok:
            up_progress += 1
            down_progress = 0
        elif degrade:
            down_progress += 1
            up_progress = 0
        else:
            up_progress = 0
            down_progress = 0

        min_level = constants.COLONY_MINIMUM_LEVEL
        min_idx = levels.index(min_level) if min_level in levels else 0

        if up_progress >= constants.COLONY_UPGRADE_TICKS_REQUIRED and level in levels[:-1]:
            level = levels[levels.index(level) + 1]
            up_progress = 0
        elif down_progress >= constants.COLONY_DOWNGRADE_TICKS_REQUIRED and level in levels[1:]:
            new_idx = levels.index(level) - 1
            if new_idx >= min_idx:
                level = levels[new_idx]
            down_progress = 0

        state.colony_levels[sector_id] = level
        state.colony_upgrade_progress[sector_id] = up_progress
        state.colony_downgrade_progress[sector_id] = down_progress
        return tags

    def _loaded_trade_count_for_sector(self, state, sector_id: str) -> int:
        """Count any agent carrying cargo in this sector (not just traders/haulers)."""
        count = 0
        for agent in state.agents.values():
            if agent.get("is_disabled"):
                continue
            if agent.get("current_sector_id") != sector_id:
                continue
            if agent.get("cargo_tag") == "LOADED":
                count += 1
        return count

    def _role_counts_for_sector(self, state, sector_id: str) -> dict:
        counts = {}
        for agent in state.agents.values():
            if agent.get("is_disabled"):
                continue
            if agent.get("current_sector_id") != sector_id:
                continue
            role = agent.get("agent_role", "idle")
            counts[role] = counts.get(role, 0) + 1
        return counts

    def _economy_level(self, tags: list, category: str) -> str:
        for level in self.ECONOMY_LEVELS:
            if f"{category}_{level}" in tags:
                return level
        return "ADEQUATE"

    def _security_tag(self, tags: list) -> str:
        for tag in self.SECURITY_LEVELS:
            if tag in tags:
                return tag
        return "CONTESTED"

    def _environment_tag(self, tags: list) -> str:
        for tag in self.ENV_LEVELS:
            if tag in tags:
                return tag
        return "MILD"

    def _replace_prefix(self, tags: list, prefix: str, replacement: str) -> list:
        base = [tag for tag in tags if not tag.startswith(prefix)]
        base.append(replacement)
        return base

    def _replace_one_of(self, tags: list, options: set, replacement: str) -> list:
        base = [tag for tag in tags if tag not in options]
        base.append(replacement)
        return base

    def _sector_recently_disabled(self, state, sector_id: str) -> bool:
        until = state.sector_disabled_until.get(sector_id, 0)
        return until > state.sim_tick_count

    def _unique(self, tags: list) -> list:
        seen = set()
        out = []
        for tag in tags:
            if tag not in seen:
                seen.add(tag)
                out.append(tag)
        return out
