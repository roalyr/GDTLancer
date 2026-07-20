import re
import random

class TierTrack:
    def __init__(self, name, tiers, start_tier_name, value=5):
        self.name = name
        self.tiers = tiers
        self.tier_idx = tiers.index(start_tier_name)
        self.value = value

    @property
    def tier_name(self):
        return self.tiers[self.tier_idx]

    @property
    def modifier(self):
        return self.tier_idx - 2

    def change(self, amount):
        old_tier = self.tier_name
        self.value += amount
        tier_shifted = False
        while self.value >= 10:
            if self.tier_idx < len(self.tiers) - 1:
                self.tier_idx += 1
                self.value -= 5
                tier_shifted = True
            else:
                self.value = 10
                break
        while self.value <= 0:
            if self.tier_idx > 0:
                self.tier_idx -= 1
                self.value += 5
                tier_shifted = True
            else:
                self.value = 0
                break
        msg = f"{self.name} is now {self.tier_name} ({self.value}/10)"
        if tier_shifted:
            msg += f" (Shifted from {old_tier})"
        return msg

    def __str__(self):
        return f"{self.name}: {self.tier_name} ({self.value}/10) [{self.modifier:+d}]"

class SectorTrack:
    def __init__(self, name, value=5):
        self.name = name
        self.value = value

    def change(self, amount):
        self.value = max(0, min(10, self.value + amount))
        return f"{self.name} is now {self.value}/10"
        
    def __str__(self):
        return f"{self.name}: {self.value}/10"

class TempTag:
    def __init__(self, name, category="ALL", modifier_value=0, expiry_condition="narrative condition met/broken", expiry_type="manual", expiry_ticks=None):
        self.name = name
        self.category = category
        self.modifier_value = modifier_value
        self.expiry_condition = expiry_condition
        self.expiry_type = expiry_type
        self.expiry_ticks = expiry_ticks

    def __str__(self):
        mod_str = f" [{self.modifier_value:+} {self.category}]" if self.modifier_value != 0 else ""
        return f"{self.name}{mod_str} (Expires when: {self.expiry_condition})"

class NPCGoal:
    def __init__(self, action_node, target_node, motivation_node):
        self.action = action_node
        self.target = target_node
        self.motivation = motivation_node
        self.resolved = False

    def __str__(self):
        status = "[RESOLVED]" if self.resolved else "[OPEN]"
        return f"{status} Intends to {self.action} {self.target} in order to {self.motivation}"

class Bond:
    def __init__(self, name, role, strength="STABLE", home_sector=None):
        self.name = name
        self.role = role
        self.strength = strength 
        self.home_sector = home_sector
        self.npc_goals = []

    def modify(self, amount):
        strengths = ["SEVERED", "FRAGILE", "STABLE", "DEEP"]
        idx = strengths.index(self.strength)
        new_idx = max(0, min(3, idx + amount))
        old_strength = self.strength
        self.strength = strengths[new_idx]
        msg = f"Bond with {self.name} is now {self.strength}"
        if old_strength == "FRAGILE" and self.strength == "SEVERED":
            msg += " -> [NARRATIVE TRIGGER] NPC becomes hostile or indifferent."
        return msg

    def add_goal(self, action, target, motivation):
        self.npc_goals.append(NPCGoal(action, target, motivation))

    def __str__(self):
        return f"{self.name} ({self.role}) - {self.strength}"

import uuid

class Goal:
    def __init__(self, statement, anchor=None, rank="MAJOR", goal_id=None):
        self.id = goal_id if goal_id else f"goal_{uuid.uuid4().hex[:8]}"
        self.statement = statement
        self.anchor = anchor
        self.progress = 0
        self.rank = rank

    def advance(self, amount, is_risky_success=False):
        max_amt = 1
        if self.rank == "MINOR":
            max_amt = 2
        elif self.rank == "EPIC" and not is_risky_success:
            return f"Goal '{self.statement}' (EPIC) can only be advanced after a Risky Success."
        
        amt_to_add = min(amount, max_amt)
        self.progress = min(10, self.progress + amt_to_add)
        return f"Goal '{self.statement}' progress now {self.progress}/10"

    def __str__(self):
        anchor_str = f" [Anchor: {self.anchor}]" if self.anchor else ""
        return f"[{self.id}] [{self.rank}] {self.statement}{anchor_str} - Progress: {self.progress}/10"

class CrewMember:
    def __init__(self, name, role, morale="STEADY"):
        self.name = name
        self.role = role
        self.morale = morale

    def change_morale(self, amount):
        states = ["LOW", "STEADY", "HIGH"]
        idx = states.index(self.morale)
        new_idx = max(0, min(2, idx + amount))
        self.morale = states[new_idx]
        msg = f"{self.name} morale is now {self.morale}."
        if self.morale == "LOW":
            msg += " [CONSEQUENCE] Crew member refuses an order, demands terms, or argues."
        return msg

    def __str__(self):
        return f"{self.name} ({self.role}) - Morale: {self.morale}"

class Message:
    def __init__(self, msg_id, to_npc, tick_sent, arrival_tick, subject):
        self.id = msg_id
        self.to_npc = to_npc
        self.tick_sent = tick_sent
        self.arrival_tick = arrival_tick
        self.subject = subject
        self.status = "PENDING"

    def __str__(self):
        return f"[{self.id}] To: {self.to_npc} | Sent: T{self.tick_sent} | Arrives: T{self.arrival_tick} | Subj: {self.subject} | Status: {self.status}"

class Notification:
    def __init__(self, source_npc, reason, tick_generated, expiry_ticks=5):
        self.source = source_npc
        self.reason = reason
        self.tick_generated = tick_generated
        self.expiry_tick = tick_generated + expiry_ticks
        self.resolved = False

    def __str__(self):
        return f"[Urgent] {self.source} reached out regarding '{self.reason}'. (Expires T{self.expiry_tick})"

class NPC:
    def __init__(self, npc_id, name, role, disposition, vessel_id=None, home_sector=None, tags=None):
        self.id = npc_id
        self.name = name
        self.role = role
        self.disposition = disposition
        self.vessel_id = vessel_id
        self.home_sector = home_sector
        self.tags = tags or []
        
    def get_location(self, game_state):
        if self.vessel_id and self.vessel_id in game_state.vessels:
            return game_state.vessels[self.vessel_id].current_sector
        return self.home_sector

    def __str__(self):
        return f"{self.name} ({self.role}) - Mood: {self.disposition}"

class Vessel:
    def __init__(self, vessel_id, name, hull_type, captain_id, crew_ids, home_sector, current_sector, routine_type, ownership="community-owned"):
        self.id = vessel_id
        self.name = name
        self.hull_type = hull_type
        self.captain = captain_id
        self.crew = crew_ids
        self.home_sector = home_sector
        self.current_sector = current_sector
        self.destination_sector = None
        self.status = "operational"
        self.routine_type = routine_type
        self.ownership = ownership

    def advance_tick(self):
        if self.status != "operational":
            return None
        if self.destination_sector:
            old_sector = self.current_sector
            self.current_sector = self.destination_sector
            self.destination_sector = None
            return f"{self.name} departed {old_sector} → {self.current_sector}"
        return None

    def take_damage(self):
        if self.status == "damaged":
            import random
            if random.random() < 0.5:
                # crew survives logic (handled externally for simplicity)
                pass
            self.status = "derelict"
        else:
            self.status = "damaged"

    def __str__(self):
        captain_str = self.captain if self.captain else "None"
        return f"{self.name} ({self.hull_type}) — Captain: {captain_str} — Location: {self.current_sector} — Status: {self.status}"

class Hook:
    def __init__(self, name, hook_type, provider, paths, success_opt="[Supplies +1]", fail_opt="[Health -1]", tags=None):
        self.name = name
        self.hook_type = hook_type 
        self.provider = provider
        self.paths = paths
        self.success_opt = success_opt
        self.fail_opt = fail_opt
        self.tags = tags or []
        self.resolved = False

    def __str__(self):
        paths_str = " | ".join(f"[{i+1}] {p[0]}" for i, p in enumerate(self.paths))
        return f"[{self.hook_type}] {self.name} (Source: {self.provider})\n      Paths: {paths_str}\n      Outcome -> Success: {self.success_opt} | Failure: {self.fail_opt}"

class Sector:
    def __init__(self, name, sector_type, wealth, security, morale, supplies):
        self.name = name
        self.type = sector_type
        self.tracks = {
            "Wealth": SectorTrack("Wealth", wealth),
            "Security": SectorTrack("Security", security),
            "Morale": SectorTrack("Morale", morale),
            "Supplies": SectorTrack("Supplies", supplies),
        }
        self.npcs = []
        self.hooks = []
        self.tags = []

    def __str__(self):
        tracks_str = ", ".join(str(t) for t in self.tracks.values())
        return f"Sector: {self.name} ({self.type}) | Tracks: {tracks_str}"

class Player:
    def __init__(self):
        self.tracks = {
            "Health": TierTrack("Health", ["CRITICAL", "INJURED", "FIT", "PEAK"], "FIT"),
            "Wealth": TierTrack("Wealth", ["DESTITUTE", "BROKE", "POOR", "COMFORTABLE", "WEALTHY"], "POOR"),
            "Morale": TierTrack("Morale", ["MUTINOUS", "LOW", "STEADY", "HIGH", "INSPIRED"], "STEADY"),
            "Supplies": TierTrack("Supplies", ["EMPTY", "SCARCE", "ADEQUATE", "STOCKED", "SURPLUS"], "ADEQUATE"),
        }
        self.bonds = [
            Bond("Kaelen", "Kin", "STABLE", "Elace Station"),
            Bond("Voss", "Mentor", "DEEP", "Korr Anchorage"),
            Bond("Sera", "Debtor", "FRAGILE", "Veyra Hub")
        ]
        self.goals = [
            Goal("Secure a dedicated medical bay for Korr Anchorage", anchor="Korr Anchorage", rank="MAJOR")
        ]
        self.tags = []
        self.vessel_status = "community-owned"
        self.tools = ["Survey array"]
        self.crew = [
            CrewMember("Jace", "Navigator"),
            CrewMember("Rin", "Mechanic"),
            CrewMember("Tova", "Cargo Handler")
        ]
        self.home_sector = "Elace Station"
        
    def get_tag_modifier(self, action_category):
        mod = 0
        used = []
        for t in self.tags:
            if t.category == action_category or t.category == "ALL":
                mod += t.modifier_value
                used.append(t.name)
        return mod, used

    def get_track_modifier(self, track_name):
        """Returns the base modifier for the given track plus any tag bonuses."""
        base = self.tracks[track_name].modifier
        tag_mod, used = self.get_tag_modifier(track_name.upper())
        return base + tag_mod, used

    def tick_tags(self):
        to_remove = []
        for t in self.tags:
            if t.expiry_type == "tick_count" and t.expiry_ticks is not None:
                t.expiry_ticks -= 1
                if t.expiry_ticks <= 0:
                    to_remove.append(t)
        for t in to_remove:
            self.tags.remove(t)
        return [f"Tag expired: {t.name}" for t in to_remove]
        
    def add_tag(self, tag):
        if not any(t.name == tag.name for t in self.tags):
            self.tags.append(tag)
            return f"Gained tag: {tag.name}"
        return f"Already have tag: {tag.name}"

    def apply_option(self, option_text, is_crisis=False, current_sector_name=None):
        results = []
        
        # Modify track regex to allow hitting Sector or Player
        track_matches = re.findall(r'\[(Health|Wealth|Morale|Supplies) ([+-]\d+)\]', option_text)
        
        for track_name, amount in track_matches:
            # If crisis, a -1 becomes a -2 to risk a tier drop
            amt = int(amount)
            if is_crisis and amt < 0:
                amt = -2
            
            res = self.tracks[track_name].change(amt)
            sector_ctx = f" at {current_sector_name}" if current_sector_name else ""
            results.append(f"{res}{sector_ctx}")
            
        tag_matches = re.findall(r'\[Gain tag: (.*?)\]', option_text)
        for tag in tag_matches:
            if not any(t.name == tag for t in self.tags):
                self.tags.append(TempTag(tag, expiry_condition="narrative condition met/broken"))
                results.append(f"Gained tag: {tag}")
            else:
                results.append(f"Already have tag: {tag}")

        strengthen_matches = re.findall(r'\[Strengthen one bond by 1 step\]', option_text)
        for _ in strengthen_matches:
            results.append("Need to choose a bond to STRENGTHEN.")

        weaken_matches = re.findall(r'\[Weaken one bond by 1 step\]', option_text)
        for _ in weaken_matches:
            results.append("Need to choose a bond to WEAKEN.")
            
        return results

    def remove_tag(self, tag_name):
        for t in self.tags:
            if t.name == tag_name:
                self.tags.remove(t)
                return True
        return False

import os

class GameState:
    def __init__(self, log_file=None):
        if log_file is None:
            # Place chronicle.md in the exact same directory as this file
            log_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chronicle.md")
        self.clock = 0
        self.player = Player()
        self.sectors = {}
        self.routes = {}
        self.vessels = {}
        self.npcs = {}
        self.current_sector = None
        self.phase = "Encounter"
        self.chronicle = []
        self.message_queue = []
        self.notifications = []
        self.pending_alerts = []
        self.msg_counter = 1
        self.last_goal_prompt_tick = -2
        self.game_over = False
        self.log_file = log_file
        self.reflection_pending = False

    def get_npcs_at_sector(self, sector_name):
        return [npc for npc in self.npcs.values() if npc.get_location(self) == sector_name]

    def get_all_npcs(self):
        return list(self.npcs.values())

    def get_vessels_at_sector(self, sector_name):
        return [v for v in self.vessels.values() if v.current_sector == sector_name]

    def advance_all_vessels(self):
        for v in self.vessels.values():
            if v.status != "operational": continue
            if v.destination_sector:
                res = v.advance_tick()
                if res:
                    self.log(res)
            elif v.routine_type:
                pass  # Future: routine scheduling
                
    def write_session_header(self):
        import datetime
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        header = f"\n\n## --- NEW SESSION: {now} ---\n\n"
        header += "### STARTING CONTEXT\n"
        header += f"- **Starting Sector:** {self.current_sector.name} ({self.current_sector.type})\n"
        header += "- **Player Tracks:**\n"
        for t in self.player.tracks.values():
            header += f"  - {t}\n"
        header += "- **Bonds:**\n"
        for b in self.player.bonds:
            header += f"  - {b}\n"
        header += "- **Goals:**\n"
        for g in self.player.goals:
            header += f"  - {g}\n"
        header += "--------------------------------------------------\n\n"
        
        with open(self.log_file, "a") as f:
            f.write(header)


    def advance_clock(self, ticks=1):
        if self.game_over: return
        for _ in range(ticks):
            self.clock += 1
            # Suppress world clock entries unless interesting, handled externally or skipped
            self.check_clock_events()
            self.advance_all_vessels()
            tag_msgs = self.player.tick_tags()
            for msg in tag_msgs:
                self.log(msg)

    def log(self, message):
        entry = f"**[T{self.clock}]** {message}"
        self.chronicle.append(entry)
        with open(self.log_file, "a") as f:
            f.write(f"- {entry}\n")
            
    def log_narrative(self, narrative_text):
        entry = f"**[T{self.clock}]** [NARRATIVE]"
        self.chronicle.append(f"{entry} {narrative_text}")
        with open(self.log_file, "a") as f:
            f.write(f"\n> **NARRATIVE [T{self.clock}]:** {narrative_text}\n\n")

    def log_system(self, message):
        entry = f"**[T{self.clock}]** *{message}*"
        self.chronicle.append(entry)
        with open(self.log_file, "a") as f:
            f.write(f"- {entry}\n")
        
    def check_clock_events(self):
        # 1. Mutiny Check
        if self.player.tracks["Morale"].tier_name == "MUTINOUS":
            print("\n*** CRITICAL EVENT: MUTINY! ***")
            print("The Morale track has reached MUTINOUS. The crew refuses orders.")
            print("Resolve via 'act petition cautious' (Negotiate) or 'act command risky' (Assert authority).")
            self.log("Mutiny occurred due to MUTINOUS morale.")

        # 2. Defeat Conditions Check (Section 11)
        # Exiled Check
        all_severed = len(self.player.bonds) > 0 and all(b.strength == "SEVERED" for b in self.player.bonds)
        if all_severed:
            self.log("DEFEAT: Exiled. All bonds severed. No group offers docking.")
            self.pending_alerts.append("[GAME OVER: EXILED]\nAll bonds have been severed. No group offers you docking or support anymore. You are cast out into the void.")
            self.game_over = True
        
        # Stranded Check
        if self.phase == "Travel" and self.current_sector.type == "Deep Space" and self.player.tracks["Supplies"].tier_name == "EMPTY":
            self.log("DEFEAT: Stranded. Supplies EMPTY in Deep Space.")
            self.pending_alerts.append("[GAME OVER: STRANDED]\nYour supplies have run completely empty while navigating Deep Space. Your crew starves in the dark.")
            self.game_over = True
            
        # Home Collapsed Check
        home = self.sectors.get(self.player.home_sector)
        if home:
            all_bottom = all(t.value <= 2 for t in home.tracks.values()) # A loose representation of "bottom tier" for 0-10
            if all_bottom:
                self.log("DEFEAT: Home Collapsed. Home sector tracks all critically low.")
                self.pending_alerts.append("[GAME OVER: HOME COLLAPSED]\nYour home sector has completely collapsed due to lack of support and security. There is nothing left to fight for.")
                self.game_over = True

        # 3. Check Incoming Notifications (NPC Interaction)
        warning_nots = [n for n in self.notifications if not n.resolved and n.expiry_tick - 1 == self.clock]
        for n in warning_nots:
            print(f"\n[WARNING] Notification from {n.source} expires NEXT TICK! (Consequence: Bond weakens)")

        expired_nots = [n for n in self.notifications if not n.resolved and n.expiry_tick <= self.clock]
        for n in expired_nots:
            n.resolved = True
            for b in self.player.bonds:
                if b.name == n.source:
                    b.modify(-1)
                    self.pending_alerts.append(f"Notification from {n.source} EXPIRED!\\nYou failed to respond in time.\\nBond with {n.source} weakened.")
            self.log(f"Notification from {n.source} expired resulting in negative consequence.")
            self.reflection_pending = True

        # 4. Check Messages
        arrived = [m for m in self.message_queue if m.arrival_tick == self.clock and m.status == "PENDING"]
        for m in arrived:
            m.status = "ARRIVED"
            print(f"\n[COMMUNICATION] Message {m.id} has ARRIVED at {m.to_npc}.")
            print(f"You must resolve the reply via Action Check: 'resolve_message {m.id}'")
            self.log(f"Message {m.id} arrived to {m.to_npc}")
            
        # 5. Goal progress prompt check
        if self.clock - self.last_goal_prompt_tick >= 2 and self.phase == "Encounter":
            print("\n[GOAL REMINDER] Time has passed. If you've acted on a goal's anchor, you may advance it using 'goal_advance'.")
            print("To resolve a fully progressed goal, use 'goal_resolve <index>'.")
            self.last_goal_prompt_tick = self.clock
            
        # Random chance to generate a new NPC notification based on World Clock
        if random.random() < 0.1 and self.phase == "Encounter":
            potential_sources = [b.name for b in self.player.bonds if b.strength != "SEVERED"]
            if potential_sources:
                source = random.choice(potential_sources)
                n = Notification(source, "Urgent community issue", self.clock)
                self.notifications.append(n)
                print(f"\n[INCOMING] {n}")
                self.log(f"Incoming notification generated for {source}.")
                self.pending_alerts.append(f"INCOMING REQUEST\\n{source} is requesting urgent assistance regarding a community issue.\\n\\nRespond via the Main Menu before the expiry tick (T{n.expiry_tick})!")
