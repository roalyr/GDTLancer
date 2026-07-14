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
    def __init__(self, name, expiration_condition="Unknown"):
        self.name = name
        self.expiration_condition = expiration_condition

    def __str__(self):
        return f"{self.name} (Expires when: {self.expiration_condition})"

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

class Goal:
    _id_counter = 1
    def __init__(self, statement, anchor=None, rank="MAJOR"):
        self.id = Goal._id_counter
        Goal._id_counter += 1
        self.statement = statement
        self.anchor = anchor
        self.progress = 0
        self.rank = rank

    def advance(self, amount):
        self.progress = min(10, self.progress + amount)
        return f"Goal '{self.statement}' progress now {self.progress}/10"

    def __str__(self):
        anchor_str = f" [Anchor: {self.anchor}]" if self.anchor else ""
        return f"[G{self.id}] [{self.rank}] {self.statement}{anchor_str} - Progress: {self.progress}/10"

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
    def __init__(self, name, role, disposition, tags=None):
        self.name = name
        self.role = role
        self.disposition = disposition
        self.tags = tags or []
        
    def __str__(self):
        return f"{self.name} ({self.role}) - Mood: {self.disposition}"

class Hook:
    def __init__(self, name, hook_type, provider, success_opt="[Supplies +1]", fail_opt="[Health -1]", tags=None):
        self.name = name
        self.hook_type = hook_type 
        self.provider = provider
        self.success_opt = success_opt
        self.fail_opt = fail_opt
        self.tags = tags or []
        self.resolved = False

    def __str__(self):
        return f"[{self.hook_type}] {self.name} (Source: {self.provider}) | Success: {self.success_opt} | Failure: {self.fail_opt}"

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
        
    def get_track_modifier(self, track_name):
        mod = self.tracks[track_name].modifier
        tag_names = [t.name for t in self.tags]
        used = []
        if track_name == "Supplies" and "Clear Path" in tag_names:
            mod += 1
            used.append("Clear Path")
        if track_name == "Supplies" and "Extra Cargo" in tag_names:
            mod += 1
            used.append("Extra Cargo")
        if track_name == "Health" and "Sick Crew" in tag_names:
            mod -= 1
        if track_name == "Morale" and "Divided Crew" in tag_names:
            mod -= 1
        if track_name == "Wealth" and "Useful Intel" in tag_names:
            mod += 1
            used.append("Useful Intel")
        return mod, used

    def apply_option(self, option_text, is_crisis=False, impact_callback=None):
        results = []
        
        # Modify track regex to allow hitting Sector or Player
        track_matches = re.findall(r'\[(Health|Wealth|Morale|Supplies) ([+-]\d+)\]', option_text)
        
        for track_name, amount in track_matches:
            # If crisis, a -1 becomes a -2 to risk a tier drop
            amt = int(amount)
            if is_crisis and amt < 0:
                amt = -2
            
            # Use callback to determine if this applies to Player or Sector (or just enforce Player/Community impact)
            if impact_callback:
                target, impact_text = impact_callback(track_name, amt)
                if target == "Player":
                    res = self.tracks[track_name].change(amt)
                else:
                    res = f"Sector {track_name} change {amt} pending." # Sector modification will be handled externally
                results.append(f"Named Impact [{target}]: {impact_text}")
                results.append(res)
            else:
                res = self.tracks[track_name].change(amt)
                results.append(res)
            
        tag_matches = re.findall(r'\[Gain tag: (.*?)\]', option_text)
        for tag in tag_matches:
            if not any(t.name == tag for t in self.tags):
                self.tags.append(TempTag(tag, expiration_condition="narrative condition met/broken"))
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

class GameState:
    def __init__(self, log_file="chronicle.md"):
        self.clock = 0
        self.player = Player()
        self.sectors = {}
        self.routes = {}
        self.current_sector = None
        self.phase = "Encounter"
        self.chronicle = []
        self.message_queue = []
        self.notifications = []
        self.msg_counter = 1
        self.last_goal_prompt_tick = -2
        self.game_over = False
        self.log_file = log_file
        self.journal_file = log_file.replace("chronicle", "journal")
        
        import os
        from datetime import datetime
        if not os.path.exists(self.log_file):
            with open(self.log_file, "w") as f:
                f.write(f"# GDTLancer Mechanical Log\n\n")
        if not os.path.exists(self.journal_file):
            with open(self.journal_file, "w") as f:
                f.write(f"# GDTLancer Narrative Journal\n\n")
                
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
        with open(self.journal_file, "a") as f:
            f.write(header)


    def advance_clock(self, ticks=1):
        if self.game_over: return
        for _ in range(ticks):
            self.clock += 1
            # Suppress world clock entries unless interesting, handled externally or skipped
            self.check_clock_events()

    def log(self, message):
        entry = f"**[T{self.clock}]** {message}"
        self.chronicle.append(entry)
        with open(self.log_file, "a") as f:
            f.write(f"- {entry}\n")
            
    def log_narrative(self, narrative_text):
        entry = f"**[T{self.clock}]** [NARRATIVE]"
        self.chronicle.append(f"{entry} {narrative_text}")
        with open(self.journal_file, "a") as f:
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
            print("\n*** GAME OVER: EXILED ***")
            self.game_over = True
        
        # Stranded Check
        if self.phase == "Travel" and self.current_sector.type == "Deep Space" and self.player.tracks["Supplies"].tier_name == "EMPTY":
            self.log("DEFEAT: Stranded. Supplies EMPTY in Deep Space.")
            print("\n*** GAME OVER: STRANDED ***")
            self.game_over = True
            
        # Home Collapsed Check
        home = self.sectors.get(self.player.home_sector)
        if home:
            all_bottom = all(t.value <= 2 for t in home.tracks.values()) # A loose representation of "bottom tier" for 0-10
            if all_bottom:
                self.log("DEFEAT: Home Collapsed. Home sector tracks all critically low.")
                print("\n*** GAME OVER: HOME COLLAPSED ***")
                self.game_over = True

        # 3. Check Incoming Notifications (NPC Interaction)
        warning_nots = [n for n in self.notifications if not n.resolved and n.expiry_tick - 1 == self.clock]
        for n in warning_nots:
            print(f"\n[WARNING] Notification from {n.source} expires NEXT TICK! (Consequence: Bond weakens)")

        expired_nots = [n for n in self.notifications if not n.resolved and n.expiry_tick <= self.clock]
        for n in expired_nots:
            n.resolved = True
            print(f"\n[CONSEQUENCE] Unanswered request from {n.source} expired. Relationship worsened.")
            # Deterministic consequence
            for b in self.player.bonds:
                if b.name == n.source:
                    print("  -> " + b.modify(-1))
            self.log(f"Notification from {n.source} expired resulting in negative consequence.")

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
