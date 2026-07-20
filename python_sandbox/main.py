import sys
import random
from models import GameState, Sector, Goal, Message, NPC, Hook, TempTag, Tool
from oracles import (get_complication, get_opportunity, get_community_cost, get_pre_flight_crew,
                     roll_3d6, roll_disposition, roll_conversation_seed, get_action_tracks,
                     generate_dynamic_hook, get_theme_focus, scene_context,
                     TOOLS_LIBRARY, STARTING_GOALS)
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'

def setup_game():
    game = GameState()
    
    # Initialize Sectors with randomized tracks
    def rt(): return random.randint(2, 8)
    game.sectors["Elace Station"] = Sector("Elace Station", "Planet", wealth=rt(), security=rt(), morale=rt(), supplies=rt())
    game.sectors["Korr Anchorage"] = Sector("Korr Anchorage", "Moon", wealth=rt(), security=rt(), morale=rt(), supplies=rt())
    game.sectors["Veyra Hub"] = Sector("Veyra Hub", "Star", wealth=rt(), security=rt(), morale=rt(), supplies=rt())
    game.sectors["The Scatter"] = Sector("The Scatter", "Field", wealth=rt(), security=rt(), morale=rt(), supplies=rt())
    game.sectors["Orin's Reach"] = Sector("Orin's Reach", "Deep Space", wealth=rt(), security=rt(), morale=rt(), supplies=rt())
    game.sectors["New Eden"] = Sector("New Eden", "Deep Space", wealth=0, security=0, morale=0, supplies=0) # Keeps dead sector theme
    
    game.routes = {
        "Elace Station": {"Korr Anchorage": 1, "Veyra Hub": 2},
        "Korr Anchorage": {"Elace Station": 1, "The Scatter": 1, "Orin's Reach": 3},
        "Veyra Hub": {"Elace Station": 2, "The Scatter": 2, "New Eden": 4},
        "The Scatter": {"Korr Anchorage": 1, "Veyra Hub": 2, "Orin's Reach": 1},
        "Orin's Reach": {"Korr Anchorage": 3, "The Scatter": 1, "New Eden": 2},
        "New Eden": {"Veyra Hub": 4, "Orin's Reach": 2}
    }
    
    # Initialize NPCs
    game.npcs = {
        "npc_kaelen": NPC("npc_kaelen", "Kaelen", "Kin", "Calm", home_sector="Elace Station"),
        "npc_relt": NPC("npc_relt", "Overseer Relt", "Administrator", "Worried", home_sector="Elace Station"),
        "npc_tyra": NPC("npc_tyra", "Dockmaster Tyra", "Logistics", "Frustrated", home_sector="Korr Anchorage"),
        "npc_voss": NPC("npc_voss", "Voss", "Mentor", "Hopeful", vessel_id="ves_lantern"),
        "npc_sera": NPC("npc_sera", "Sera", "Debtor", "Distant", vessel_id="ves_ember"),
        "npc_daro": NPC("npc_daro", "Daro", "Captain", "Calm", vessel_id="ves_ironweed"),
        "npc_maren": NPC("npc_maren", "Maren", "Captain", "Eager", vessel_id="ves_kestrel"),
        "npc_fen": NPC("npc_fen", "Fen", "Captain", "Worried", vessel_id="ves_hull07"),
        "npc_lia": NPC("npc_lia", "Lia", "Captain", "Hopeful", vessel_id="ves_dustwren")
    }
    
    # Initialize Vessels
    from models import Vessel
    game.vessels = {
        "ves_lantern": Vessel("ves_lantern", "Stray Lantern", "Light hauler", "Voss", ["npc_voss"], "Korr Anchorage", "Korr Anchorage", "supply_run"),
        "ves_ember": Vessel("ves_ember", "Quiet Ember", "Survey platform", "Sera", ["npc_sera"], "Veyra Hub", "Veyra Hub", "survey"),
        "ves_ironweed": Vessel("ves_ironweed", "Ironweed", "Tanker", "Daro", ["npc_daro"], "Elace Station", "Elace Station", "supply_run"),
        "ves_kestrel": Vessel("ves_kestrel", "Kestrel", "Patrol craft", "Maren", ["npc_maren"], "Veyra Hub", "Veyra Hub", "patrol"),
        "ves_hull07": Vessel("ves_hull07", "Hull 07", "Repair tender", "Fen", ["npc_fen"], "Korr Anchorage", "Korr Anchorage", "repair_tender"),
        "ves_dustwren": Vessel("ves_dustwren", "Dust Wren", "Light hauler", "Lia", ["npc_lia"], "Orin's Reach", "Orin's Reach", "supply_run")
    }
    
    # Randomize Player Initial State
    for track_name, track in game.player.tracks.items():
        track.value = random.randint(3, 8)
        # We don't bother updating the tier_idx here since the tier checks dynamically when rolling, but for consistency:
        # Actually it's best to let change(0) run to fix tier names if value is modified.
        track.change(0)
        
    bond_strengths = ["FRAGILE", "STABLE", "DEEP"]
    for b in game.player.bonds:
        b.strength = random.choice(bond_strengths)
        
    game.current_sector = game.sectors["Elace Station"]
    game.phase = "Encounter"
    return game

def generate_sector_hooks(game):
    # Only generate hooks for Encounter phase
    if game.phase == "Encounter":
        for h in game.current_sector.hooks:
            if h.resolved:
                game.current_sector.hooks.remove(h)
                
        # Fill hooks up to 2, tracking used sentences to avoid duplicates
        current_npcs = game.get_npcs_at_sector(game.current_sector.name)
        used_sentences = {h.name for h in game.current_sector.hooks}
        while len(game.current_sector.hooks) < 2 and current_npcs:
            provider = random.choice(current_npcs)
            name, htype, paths, succ, fail = generate_dynamic_hook(game.current_sector, provider, used_sentences)
            game.current_sector.hooks.append(Hook(name, htype, provider.name, paths, success_opt=succ, fail_opt=fail))

def print_header(game):
    if game.game_over:
        return
    generate_sector_hooks(game)
    print("\n\n" + Colors.CYAN + "="*70)
    print(f"{Colors.BOLD}[{game.current_sector.name} | Phase: {game.phase} | World Clock: T{game.clock}]{Colors.ENDC}{Colors.CYAN}")
    t = game.player.tracks
    print(f"Tracks: H:{t['Health'].value} W:{t['Wealth'].value} M:{t['Morale'].value} S:{t['Supplies'].value}")
    if game.notifications:
        has_active = False
        for n in game.notifications:
            if not n.resolved:
                if not has_active:
                    print(f"\n{Colors.WARNING}NOTIFICATIONS:{Colors.CYAN}")
                    has_active = True
                warning = f" {Colors.FAIL}[!] EXPIRES NEXT TICK{Colors.CYAN}" if n.expiry_tick == game.clock + 1 else ""
                print(f"  {n}{warning}")
    print("=" * 70 + Colors.ENDC)
    print(f"{Colors.DIM}Type 'help' for commands, 'state' for full status.{Colors.ENDC}")
    print(Colors.CYAN + "=" * 70 + Colors.ENDC + "\n")

def print_state(game):
    if game.game_over:
        return
        
    generate_sector_hooks(game)
    
    print("\n\n" + Colors.CYAN + "="*70)
    print(f"{Colors.BOLD}[{game.current_sector.name} | Phase: {game.phase} | World Clock: T{game.clock}]{Colors.ENDC}{Colors.CYAN}")
    print("-" * 70 + Colors.ENDC)
    print(f"{Colors.HEADER}PLAYER STATUS (Community Vessel):{Colors.ENDC}")
    for track in game.player.tracks.values():
        color = Colors.FAIL if track.value <= 2 else (Colors.WARNING if track.value <= 4 else Colors.GREEN)
        print(f"  {track.name}: {color}{track.tier_name} ({track.value}/10){Colors.ENDC} [{track.modifier:+d}]")
    if game.player.tags:
        print(f"  Tags: {', '.join(str(t) for t in game.player.tags)}")
    if game.player.tools:
        print(f"\n{Colors.HEADER}TOOLS:{Colors.ENDC}")
        for tool in game.player.tools:
            cond_color = Colors.FAIL if tool.condition == "Damaged" else (Colors.WARNING if tool.condition == "Worn" else Colors.GREEN)
            print(f"  {tool.name} {cond_color}[{tool.condition}]{Colors.ENDC} — {tool.description}")
    else:
        print(f"  Tools: None")
    
    print(f"\n{Colors.HEADER}BONDS:{Colors.ENDC}")
    for i, b in enumerate(game.player.bonds):
        color = Colors.FAIL if b.strength == "SEVERED" else (Colors.WARNING if b.strength == "FRAGILE" else Colors.GREEN)
        print(f"  {i+1}: {b.name} ({b.role}) - {color}{b.strength}{Colors.ENDC}")
        for g in b.npc_goals:
            print(f"     - {g}")
        
    print(f"\n{Colors.HEADER}GOALS:{Colors.ENDC}")
    for g in game.player.goals:
        print(f"  {g}")

    print(f"\n{Colors.HEADER}CREW:{Colors.ENDC}")
    for c in game.player.crew:
        color = Colors.FAIL if c.morale == "LOW" else (Colors.GREEN if c.morale == "HIGH" else Colors.ENDC)
        print(f"  {c.name} ({c.role}) - Morale: {color}{c.morale}{Colors.ENDC}")

    print(Colors.CYAN + "-" * 70 + Colors.ENDC)
    print(f"{Colors.HEADER}COMMUNITY / SECTOR STATUS:{Colors.ENDC}")
    print(f"  {game.current_sector.name} ({game.current_sector.type}) | Tracks: ", end="")
    s_t = game.current_sector.tracks
    s_strs = []
    for st_name, st in s_t.items():
        color = Colors.FAIL if st.value <= 2 else (Colors.WARNING if st.value <= 4 else Colors.GREEN)
        s_strs.append(f"{st_name}: {color}{st.value}/10{Colors.ENDC}")
    print(", ".join(s_strs))
    
    if game.phase == "Encounter":
        current_npcs = game.get_npcs_at_sector(game.current_sector.name)
        # Scene context block
        print(f"\n{Colors.DIM}{scene_context(game.current_sector, game.player, current_npcs)}{Colors.ENDC}")
        if current_npcs:
            on_station = [n for n in current_npcs if n.vessel_id is None]
            on_vessels = [n for n in current_npcs if n.vessel_id is not None]
            if on_station:
                print(f"  On Station: " + ", ".join(str(npc) for npc in on_station))
            if on_vessels:
                orbit_strs = []
                for n in on_vessels:
                    v_name = game.vessels[n.vessel_id].name if n.vessel_id in game.vessels else n.vessel_id
                    orbit_strs.append(f"{n} (aboard {v_name})")
                print(f"  In Orbit/Vessels: " + ", ".join(orbit_strs))
        if game.current_sector.hooks:
            print(f"  {Colors.BOLD}Available Hooks:{Colors.ENDC}")
            for i, h in enumerate(game.current_sector.hooks):
                print(f"    {i+1}: {h}")
                
    if game.notifications:
        has_active = False
        for n in game.notifications:
            if not n.resolved:
                if not has_active:
                    print(f"\n{Colors.WARNING}NOTIFICATIONS:{Colors.ENDC}")
                    has_active = True
                warning = f" {Colors.FAIL}[!] EXPIRES NEXT TICK{Colors.ENDC}" if n.expiry_tick == game.clock + 1 else ""
                print(f"  {n}{warning}")
    print(Colors.CYAN + "=" * 70 + Colors.ENDC + "\n")


def handle_bond_selection(game, prompt="Select bond"):
    print("\nSelect a bond to modify:")
    for i, b in enumerate(game.player.bonds):
        print(f"  {i+1}: {b.name} ({b.role}) - {b.strength}")
    while True:
        try:
            choice = int(input(f"{prompt} (1-{len(game.player.bonds)}): ")) - 1
            if 0 <= choice < len(game.player.bonds):
                return game.player.bonds[choice]
            print("Invalid.")
        except ValueError:
            print("Enter a number.")

def handle_options_loop(game, options_to_pick, is_crisis=False):
    for opt_type, opt_list in options_to_pick:
        while True:
            choice = input(f"Enter choice for {opt_type} (1-{len(opt_list)}): ").strip()
            try:
                c_idx = int(choice) - 1
                if 0 <= c_idx < len(opt_list):
                    selected = opt_list[c_idx]
                    results = game.player.apply_option(selected, is_crisis=is_crisis, current_sector_name=game.current_sector.name)
                    print(f"Applied: {selected}")
                    for res in results:
                        if "choose a bond to STRENGTHEN" in res:
                            b = handle_bond_selection(game, "Strengthen which bond?")
                            res_bond = b.modify(1)
                            print(f" -> {res_bond}")
                            game.log(res_bond)
                            game.reflection_pending = True
                        elif "choose a bond to WEAKEN" in res:
                            b = handle_bond_selection(game, "Weaken which bond?")
                            res_bond = b.modify(-1)
                            print(f" -> {res_bond}")
                            game.log(res_bond)
                            game.reflection_pending = True
                        else:
                            print(f" -> {res}")
                            game.log(res)
                            if "Shifted from" in res:
                                game.reflection_pending = True
                    break
                else:
                    print("Invalid choice.")
            except ValueError:
                print("Enter a number.")

def roll_action_engine(game, track_name, approach, mod, hook=None, used_bond=None, used_tool=None):
    roll = roll_3d6()
    total = roll + mod
    
    print(f"\n[ACTION CHECK] Rolled 3d6: {roll} + Mod: {mod} = Total: {total}")
    
    is_crisis = False
    is_outstanding = False
    
    if approach == "risky":
        if roll <= 5: 
            total = 6 
            is_crisis = True
        elif roll >= 16: 
            total = 15 
            is_outstanding = True
            
    if total <= 6:
        outcome = "Crisis" if is_crisis else "Setback"
    elif total <= 10:
        outcome = "Partial"
    elif total <= 14:
        outcome = "Success"
    else:
        outcome = "Success (Outstanding)" if is_outstanding else "Success"

    print(f"Outcome: {outcome.upper()}")
    
    in_space = game.phase == "Travel"
    options_to_pick = []
    
    if hook:
        if "Success" in outcome:
            print(f"\n[HOOK SUCCESS] {hook.success_opt}")
            options_to_pick.append(("Hook Success", [hook.success_opt]))
        elif outcome == "Partial":
            print(f"\n[HOOK SUCCESS] {hook.success_opt}")
            print(f"[HOOK FAILURE] {hook.fail_opt}")
            options_to_pick.append(("Hook Success", [hook.success_opt]))
            options_to_pick.append(("Hook Failure", [hook.fail_opt]))
        else:
            print(f"\n[HOOK FAILURE] {hook.fail_opt}")
            if is_crisis:
                print("CRISIS ACTIVE: Any negative track hits in your choice will be doubled (-2)!")
            options_to_pick.append(("Hook Failure", [hook.fail_opt]))
    else:
        if "Success" in outcome:
            opp_name, adv_options = get_opportunity(in_space)
            print(f"\n[OPPORTUNITY] {opp_name}")
            for i, opt in enumerate(adv_options):
                print(f"  {i+1}: {opt}")
            options_to_pick.append(("Advantage", adv_options))
            
        elif outcome == "Partial":
            opp_name, adv_options = get_opportunity(in_space)
            comp_name, dis_options = get_complication()
            print(f"\n[OPPORTUNITY] {opp_name}")
            for i, opt in enumerate(adv_options):
                print(f"  {i+1}: {opt}")
            print(f"\n[COMPLICATION] {comp_name}")
            for i, opt in enumerate(dis_options):
                print(f"  {i+1}: {opt}")
                
            options_to_pick.append(("Advantage", adv_options))
            options_to_pick.append(("Disadvantage", dis_options))
            
        elif outcome in ["Setback", "Crisis"]:
            comp_name, dis_options = get_complication()
            print(f"\n[COMPLICATION] {comp_name}")
            if is_crisis:
                print("CRISIS ACTIVE: Any negative track hits in your choice will be doubled (-2)!")
            for i, opt in enumerate(dis_options):
                print(f"  {i+1}: {opt}")
            options_to_pick.append(("Disadvantage", dis_options))

    handle_options_loop(game, options_to_pick, is_crisis=is_crisis)
    
    # Bond consequences — applied after oracle options
    if used_bond:
        if "Success" in outcome:
            # On success: offer bond strengthen as an option
            print(f"\n{Colors.GREEN}[BOND] You acted with {used_bond.name} in mind.{Colors.ENDC}")
            print(f"  Strengthen bond with {used_bond.name}? [Y/N]")
            if input("> ").strip().lower() == 'y':
                res = used_bond.modify(1)
                print(f" -> {res}")
                game.log(res)
                game.reflection_pending = True
        elif outcome == "Partial":
            # On partial: offer strengthen but also show the risk of -1
            print(f"\n{Colors.WARNING}[BOND] You called on {used_bond.name}'s trust to get through this.{Colors.ENDC}")
            print(f"  Strengthen bond with {used_bond.name}? [Y/N]")
            if input("> ").strip().lower() == 'y':
                res = used_bond.modify(1)
                print(f" -> {res}")
                game.log(res)
                game.reflection_pending = True
            else:
                print(f"  (Bond unchanged.)")
        elif outcome in ["Setback", "Crisis"]:
            # On failure: weaken is optional (cautious) or enforced (risky)
            if approach == "risky":
                print(f"\n{Colors.FAIL}[BOND] You put {used_bond.name}'s trust on the line — and it cost them.{Colors.ENDC}")
                res = used_bond.modify(-1)
                print(f" -> {res} (Risky — enforced)")
                game.log(res)
                game.reflection_pending = True
            else:
                print(f"\n{Colors.WARNING}[BOND] {used_bond.name} was involved. Did this damage the relationship?{Colors.ENDC}")
                print(f"  Weaken bond with {used_bond.name}? [Y/N]")
                if input("> ").strip().lower() == 'y':
                    res = used_bond.modify(-1)
                    print(f" -> {res}")
                    game.log(res)
                    game.reflection_pending = True
                else:
                    print(f"  (Bond unchanged — noted for narrative.)")
    
    # Tool consequences — applied after bond consequences
    if used_tool:
        if "Success" in outcome:
            # Success: tool is fine, note its contribution
            print(f"\n{Colors.GREEN}[TOOL] {used_tool.name} performed well.{Colors.ENDC} Condition: {used_tool.condition}.")
        elif outcome == "Partial":
            # Partial: optional wear on cautious, enforced wear on risky
            if approach == "risky":
                print(f"\n{Colors.WARNING}[TOOL] The {used_tool.name} took strain from that approach.{Colors.ENDC}")
                res = used_tool.wear()
                print(f" -> {res} (Risky — enforced)")
                game.log(res)
            else:
                print(f"\n{Colors.WARNING}[TOOL] Did the {used_tool.name} take wear from this?{Colors.ENDC}")
                print(f"  Mark {used_tool.name} as Worn? [Y/N]")
                if input("> ").strip().lower() == 'y':
                    res = used_tool.wear()
                    print(f" -> {res}")
                    game.log(res)
        elif outcome in ["Setback", "Crisis"]:
            # Failure: wear on cautious, damaged on risky
            if approach == "risky":
                print(f"\n{Colors.FAIL}[TOOL] The {used_tool.name} was pushed too hard — it is now Damaged.{Colors.ENDC}")
                res = used_tool.damage()
                print(f" -> {res} (Risky — enforced)")
                game.log(res)
            else:
                print(f"\n{Colors.WARNING}[TOOL] Did the {used_tool.name} get damaged in this?{Colors.ENDC}")
                print(f"  Mark {used_tool.name} as Worn? [Y/N]")
                if input("> ").strip().lower() == 'y':
                    res = used_tool.wear()
                    print(f" -> {res}")
                    game.log(res)
                else:
                    print(f"  (Tool unchanged — noted for narrative.)")
    
    return outcome

def prompt_reflection(game):
    print("\n[Reflect?] (Type your reflection, or press Enter to skip)")
    text = input("> ").strip()
    if text:
        with open(game.log_file, "a") as f:
            f.write(f"\n> **[REFLECT — T{game.clock}]** {text}\n\n")

def resolve_action(game, hook=None):
    if hook is None and game.current_sector.hooks:
        print("\nAvailable hooks in this sector:")
        for i, h in enumerate(game.current_sector.hooks):
            print(f"  [{i+1}] {h.name}")
        print("Are you acting to resolve a hook? (Enter hook number, or 0 for standard action)")
        while True:
            try:
                h_choice = int(input("> ").strip())
                if h_choice == 0:
                    break
                elif 1 <= h_choice <= len(game.current_sector.hooks):
                    hook = game.current_sector.hooks[h_choice - 1]
                    break
            except:
                pass

    actions_list = ["command", "navigate", "endure", "overcome", "scavenge", "repair", "barter", "acquire", "petition", "convince", "investigate", "scan"]

    
    if hook:
        print(f"\n--- RESOLVING HOOK: {hook.name} ---")
        for i, p in enumerate(hook.paths):
            print(f"  [{i+1}] {p[0]} (Valid actions: {', '.join(p[1])})")
        
        while True:
            try:
                p_idx = int(input("Select path (number): ")) - 1
                if 0 <= p_idx < len(hook.paths):
                    valid_acts = hook.paths[p_idx][1]
                    break
            except:
                pass
        
        print(f"\nChoose an action from the path:")
        for i, act in enumerate(valid_acts):
            print(f"  [{i+1}] {act.capitalize()}")
        while True:
            try:
                a_idx = int(input("Select action (number): ")) - 1
                if 0 <= a_idx < len(valid_acts):
                    action_name = valid_acts[a_idx]
                    break
            except:
                pass
    else:
        print("\n--- ACTION SELECTION ---")
        for i, act in enumerate(actions_list):
            print(f"  [{i+1}] {act.capitalize()}")
        while True:
            try:
                a_idx = int(input("Select action (number): ")) - 1
                if 0 <= a_idx < len(actions_list):
                    action_name = actions_list[a_idx]
                    break
            except:
                pass

    valid_tracks = get_action_tracks(action_name)
    print(f"\nChoose track for {action_name.capitalize()}:")
    for i, tr in enumerate(valid_tracks):
        mod = game.player.tracks[tr].modifier
        print(f"  [{i+1}] {tr} (Base: {mod:+d})")
    
    while True:
        try:
            t_idx = int(input("Select track (number): ")) - 1
            if 0 <= t_idx < len(valid_tracks):
                track_name = valid_tracks[t_idx]
                break
        except:
            pass

    print("\nChoose approach:")
    print("  [1] Cautious")
    print("  [2] Risky")
    while True:
        app = input("Select approach (1/2): ").strip()
        if app == "1":
            approach = "cautious"
            break
        elif app == "2":
            approach = "risky"
            break

    mod = game.player.tracks[track_name].modifier
    used_tags = []
    used_bond = None  # Track if a bond was used as modifier
    used_tool = None  # Track if a tool was used as modifier
    
    # Interactive modifiers
    print("\n--- MODIFIERS ---")
    available_tags = [t for t in game.player.tags if t.category in ["ALL", track_name.upper()] or t.category in ["SECURITY", "SOCIAL", "LOGISTICS", "ECONOMIC", "PHYSICAL"]]
    
    # We'll just show all active tags and bonds, let player toggle
    added_mods = []
    if available_tags:
        print("Available Tags:")
        for i, t in enumerate(available_tags):
            print(f"  [T{i+1}] {t}")
    if game.player.bonds:
        print("Available Bonds:")
        for i, b in enumerate(game.player.bonds):
            print(f"  [B{i+1}] {b}")
    if game.player.tools:
        print("Available Tools:")
        for i, tool in enumerate(game.player.tools):
            usable = tool.is_usable()
            bonus = tool.bonus()
            cond_str = f" [{tool.condition}]" if tool.condition != "Ready" else ""
            avail_str = f" (+{bonus})" if usable else " (DAMAGED — no bonus)"
            print(f"  [O{i+1}] {tool.name}{cond_str}{avail_str}")
            
    print("Enter codes to apply modifiers (e.g. 'T1 B2'), or press Enter to skip.")
    mods_input = input("> ").strip().upper().split()
    for code in mods_input:
        if code.startswith('T') and len(code) > 1:
            try:
                idx = int(code[1:]) - 1
                if 0 <= idx < len(available_tags):
                    t = available_tags[idx]
                    mod += t.modifier_value
                    used_tags.append(t.name)
                    added_mods.append(f"{t.name} ({t.modifier_value:+d})")
            except: pass
        elif code.startswith('B') and len(code) > 1:
            try:
                idx = int(code[1:]) - 1
                if 0 <= idx < len(game.player.bonds):
                    b = game.player.bonds[idx]
                    b_mod = 1 if b.strength == "DEEP" else (-1 if b.strength == "SEVERED" else 0)
                    mod += b_mod
                    used_bond = b  # Remember which bond was used
                    added_mods.append(f"{b.name} bond ({b_mod:+d})")
            except: pass
        elif code.startswith('O') and len(code) > 1:
            try:
                idx = int(code[1:]) - 1
                if 0 <= idx < len(game.player.tools):
                    tool = game.player.tools[idx]
                    bonus = tool.bonus()
                    if bonus > 0:
                        mod += bonus
                        used_tool = tool
                        added_mods.append(f"{tool.name} (+{bonus})")
                    else:
                        print(f"  {tool.name} is Damaged — no bonus applied.")
            except: pass

    # Sector context
    sector_tracks = list(game.current_sector.tracks.values())
    avg_sector = sum(t.value for t in sector_tracks) / 4.0
    if avg_sector > 6:
        mod += 1
        added_mods.append("Sector Conditions (+1)")
    elif avg_sector < 4:
        mod -= 1
        added_mods.append("Sector Conditions (-1)")
        
    mod = max(-4, min(4, mod))
    
    print(f"\n--- CONFIRMATION ---")
    print(f"Action: {action_name.upper()}")
    print(f"Track: {track_name}")
    print(f"Approach: {approach.capitalize()}")
    if added_mods:
        print(f"Modifiers applied: {', '.join(added_mods)}")
    print(f"Total Roll Modifier: {mod:+d}")
    
    input("Press Enter to roll...")
    
    kinetic_actions = ["command", "navigate", "scavenge", "repair"]
    if action_name in kinetic_actions:
        marker = f"[KINETIC STUB: PILOTING/EVA — {action_name.upper()}]"
        print(f"\n{marker}")
        game.log(marker)
        
    for t in used_tags:
        game.player.remove_tag(t)
        print(f"Used and expired tag: {t}")
        
    outcome = roll_action_engine(game, track_name, approach, mod, hook=hook, used_bond=used_bond, used_tool=used_tool)
    
    if hook and outcome != "Crisis" and outcome != "Setback":
        hook.resolved = True
        
    next_action_tags = [t for t in game.player.tags if t.expiry_type == "next_action"]
    for t in next_action_tags:
        game.player.tags.remove(t)
        print(f"Tag expired (next_action): {t.name}")
        
    game.advance_clock(1)

def do_travel(game, destination_str):
    dest_name = " ".join(destination_str)
    if dest_name not in game.sectors:
        print(f"Unknown destination: {dest_name}")
        print("Available:", list(game.sectors.keys()))
        return
        
    # Dijkstra's to find shortest path
    import heapq
    distances = {s: float('inf') for s in game.sectors}
    distances[game.current_sector.name] = 0
    pq = [(0, game.current_sector.name)]
    
    while pq:
        d, current = heapq.heappop(pq)
        if d > distances[current]:
            continue
        if current == dest_name:
            break
        for neighbor, weight in game.routes.get(current, {}).items():
            dist = d + weight
            if dist < distances[neighbor]:
                distances[neighbor] = dist
                heapq.heappush(pq, (dist, neighbor))
                
    distance = distances[dest_name]
    if distance == float('inf'):
        print(f"No known route to {dest_name}.")
        return

    game.phase = "Travel"
    game.log(f"Initiated travel to {dest_name} (Distance: {distance})")
    print(f"\n--- PRE-DEPARTURE SEQUENCE (Distance {distance}) ---")
    
    # 1. Community Cost & Crew Checks (Batched)
    cost_name, cost_opts = get_community_cost()
    print(f"\n[COMMUNITY COST] {cost_name}")
    
    import random
    crew_opts = []
    if random.random() < 0.5:
        crew_name, crew_opts, ctype = get_pre_flight_crew()
        print(f"[PRE-FLIGHT CREW CHECK] {ctype}: {crew_name}")
    else:
        print("[PRE-FLIGHT CREW CHECK] All crew report ready.")
        
    options_to_pick = [("Community Cost Option", cost_opts)]
    for i, opt in enumerate(cost_opts):
        print(f"  Cost Opt {i+1}: {opt}")
        
    if crew_opts:
        options_to_pick.append(("Crew Check Option", crew_opts))
        for i, opt in enumerate(crew_opts):
            print(f"  Crew Opt {i+1}: {opt}")
            
    handle_options_loop(game, options_to_pick)
    
    # 2. Kinetic Stub & Travel Transit
    print(f"\n[KINETIC STUB: FLIGHT MODE — {game.current_sector.name} → {dest_name}]")
    game.log(f"[KINETIC STUB: FLIGHT MODE — {game.current_sector.name} → {dest_name}]")
        
    # 3. Travel Transit
    print(f"\n--- TRAVELING TO {dest_name} ---")
    
    current_path_sector = game.current_sector.name
    # Since we don't store the exact path in this simple Dijkstra, we'll just simulate passing through distance number of sectors.
    
    for step in range(distance):
        game.player.tracks["Supplies"].change(-1)
        game.log("Consumed 1 Supplies during travel.")
        
        # Encounter Phase Check
        enc = random.randint(1, 6)
        if enc == 1:
            print("\n[TRAVEL ENCOUNTER] Hazard! Rolled 1 on Encounter die.")
            comp_name, dis_opts = get_complication()
            print(f"Hazard: {comp_name}")
            for i, opt in enumerate(dis_opts):
                print(f"  {i+1}: {opt}")
            handle_options_loop(game, [("Hazard Disadvantage", dis_opts)])
        elif enc == 2:
            print("\n[TRAVEL ENCOUNTER] Opportunity! Rolled 2 on Encounter die.")
            opp_name, adv_opts = get_opportunity(in_space=True)
            print(f"Discovery: {opp_name}")
            for i, opt in enumerate(adv_opts):
                print(f"  {i+1}: {opt}")
            handle_options_loop(game, [("Discovery Advantage", adv_opts)])
        else:
            print("Transit sector passed peacefully.")
            
        # Vessel encounter stub check
        vessels_here = game.get_vessels_at_sector(current_path_sector)
        if vessels_here:
            for v in vessels_here:
                print(f"\n[KINETIC STUB: Encountered {v.name} (Captain: {v.captain}) in {current_path_sector}. Hail? [Y/N]]")
                if input("> ").lower().startswith('y'):
                    if v.captain:
                        do_converse(game, [v.captain], override_sector=current_path_sector)
                    else:
                        print(f"Vessel {v.name} is derelict or has no captain.")
                
        game.advance_clock(1)
        
    game.current_sector = game.sectors[dest_name]
    game.phase = "Encounter"
    print(f"\nARRIVED at {dest_name}. Phase: {game.phase}")
    game.log(f"Arrived at {dest_name}")
    
    next_travel_tags = [t for t in game.player.tags if t.expiry_type == "next_travel"]
    for t in next_travel_tags:
        game.player.tags.remove(t)
        print(f"Tag expired (next_travel): {t.name}")
        
    game.reflection_pending = True

def do_converse(game, args, override_sector=None):
    if len(args) < 1:
        print("Usage: converse <npc_name>")
        return
    npc_name = " ".join(args)
    
    # Check crew first
    crew_member = next((c for c in game.player.crew if c.name.lower() == npc_name.lower()), None)
    if crew_member:
        print(f"\n--- CONVERSATION WITH {crew_member.name} (Crew) ---")
        seed = roll_conversation_seed()
        print(f"{crew_member.name} ({crew_member.role}) — Morale: {crew_member.morale} — Topic: {seed}")
        
        print("\n[Reflect?] (Type your free-text narrative, or press Enter to skip)")
        free_text = input("> ").strip()
                
        log_entry = f"Spoke with crew {crew_member.name}. Morale: {crew_member.morale}. Topic: {seed}."
        game.log(log_entry)
        
        if free_text:
            with open(game.log_file, "a") as f:
                f.write(f"\n> **[REFLECT — T{game.clock}]** {free_text}\n\n")
        print("Conversation logged.")
        return

    # Fallback to local NPCs
    npc = next((n for n in game.get_all_npcs() if n.name.lower() == npc_name.lower()), None)
    
    if not npc:
        print(f"Unknown NPC: {npc_name}")
        return
        
    npc_loc = npc.get_location(game)
    check_loc = override_sector if override_sector else game.current_sector.name
    
    if npc_loc != check_loc:
        vessel_str = f" aboard {npc.vessel_id}" if npc.vessel_id else ""
        print(f"{npc.name} is not here. They are{vessel_str} at {npc_loc}.")
        return

    print(f"\n--- CONVERSATION WITH {npc.name} ---")
    seed = roll_conversation_seed()
    disposition = roll_disposition()
    npc.disposition = disposition
    
    print(f"{npc.name} ({npc.role}) — Mood: {disposition} — Topic: {seed}")
    
    print("\n[Reflect?] (Type your free-text narrative, or press Enter to skip)")
    free_text = input("> ").strip()
            
    log_entry = f"Spoke with {npc.name}. Mood: {disposition}. Topic: {seed}."
    game.log(log_entry)
    
    if free_text:
        with open(game.log_file, "a") as f:
            f.write(f"\n> **[REFLECT — T{game.clock}]** {free_text}\n\n")
    print("Conversation logged.")
    
    # Resolve any pending notifications from this NPC
    for n in game.notifications:
        if not n.resolved and n.source.lower() == npc.name.lower():
            n.resolved = True
            print(f"[SYSTEM] Pending notification from {n.source} resolved.")

def resolve_msg(game, args):
    if not args:
        print("Usage: resolve_message <msg_id>")
        return
    msg_id = args[0]
    for m in game.message_queue:
        if m.id == msg_id and m.status == "ARRIVED":
            print(f"Resolving reply for message {m.id} to {m.to_npc}")
            print("You must roll 'petition' to determine the outcome.")
            approach = input("Approach [cautious/risky]: ").lower()
            if approach not in ["cautious", "risky"]: approach = "cautious"
            
            mod, _ = game.player.get_track_modifier("Morale")
            outcome = roll_action_engine(game, "Morale", approach, mod)
            m.status = "RESOLVED"
            game.log(f"Resolved message {m.id} with outcome: {outcome}")
            return
    print("No pending ARRIVED message found with that ID.")

def resolve_goal(game, args):
    if len(args) < 2:
        print("Usage: goal_resolve <goal_id> <cautious/risky>")
        return
    try:
        goal_id = args[0]
        app = args[1].lower()
        g = next((g for g in game.player.goals if g.id == goal_id), None)
        if g:
            if g.progress < 10:
                print("Goal must reach 10 progress to resolve.")
                return
            print(f"Attempting to resolve goal: {g.statement}")
            mod, _ = game.player.get_track_modifier("Morale")
            outcome = roll_action_engine(game, "Morale", app, mod)
            if "Success" in outcome:
                print("Goal FULFILLED!")
                game.player.goals.remove(g)
                game.log(f"Goal fulfilled: {g.statement}")
                game.reflection_pending = True
            else:
                print("Goal resolution hit a snag. Retain it or abandon it.")
                game.log(f"Goal resolution failed: {g.statement}")
            game.advance_clock(1)
        else:
            print("Invalid goal ID.")
    except Exception as e:
        print(f"Error: {e}")

def session_zero(game):
    """Interactive session zero onboarding flow."""
    C = Colors
    W = 70

    def hr(char="="): print(C.CYAN + char * W + C.ENDC)
    def section(title): 
        print()
        hr()
        print(f"{C.BOLD}{C.HEADER}  {title}{C.ENDC}")
        hr("-")
        print()
    def pause(): input(f"{C.DIM}  [ Press Enter to continue... ]{C.ENDC}")
    def pick(prompt, options, show_desc=False):
        """Display numbered options, return chosen index."""
        for i, opt in enumerate(options):
            if show_desc and len(opt) > 2:
                print(f"  {C.GREEN}[{i+1}]{C.ENDC} {opt[0]}")
                print(f"       {C.DIM}{opt[-1]}{C.ENDC}")
            else:
                label = opt[0] if isinstance(opt, (list, tuple)) else opt
                print(f"  {C.GREEN}[{i+1}]{C.ENDC} {label}")
        while True:
            try:
                c = int(input(f"{C.GREEN}> {C.ENDC}").strip()) - 1
                if 0 <= c < len(options):
                    return c
            except: pass
            print("  Invalid choice.")

    # ── INTRO ────────────────────────────────────────────────────────────────
    hr()
    print(f"""
{C.BOLD}{C.HEADER}  G D T L A N C E R{C.ENDC}
{C.DIM}  A solo survival narrative game.{C.ENDC}
""")
    hr()
    print(f"""
{C.CYAN}You are a pilot and steward of a community vessel — one of the few ships
still flying in a remote and struggling star system.

Your vessel is not yours. It belongs to the people who depend on it: the
anchorages, the outposts, the families scattered across dead rock and cold
space. You fly the routes no one else will. You carry what needs carrying.
You make the calls no one else is in a position to make.

This is not a story about heroes. It is a story about responsibility,
relationships, and the weight of keeping something alive.
{C.ENDC}""")
    pause()

    # ── STARTING SECTOR ──────────────────────────────────────────────────────
    section("WHERE DO YOU BEGIN?")
    print("  Your vessel is currently docked. Choose your starting station:\n")
    sectors = [
        ("Elace Station",  "Planet orbit. Mid-sized habitat. Familiar faces, old debts."),
        ("Korr Anchorage", "Moon anchorage. Small. Struggling. Everyone knows your name."),
        ("Veyra Hub",      "Star-adjacent hub. Traffic, trade, and eyes you don't recognize."),
    ]
    for i, (name, desc) in enumerate(sectors):
        print(f"  {C.GREEN}[{i+1}]{C.ENDC} {name}")
        print(f"       {C.DIM}{desc}{C.ENDC}")
    sector_idx = pick("", sectors)
    chosen_sector = sectors[sector_idx][0]
    game.current_sector = game.sectors[chosen_sector]
    print(f"\n  Starting at: {C.BOLD}{chosen_sector}{C.ENDC}")
    pause()

    # ── TOOL SELECTION ───────────────────────────────────────────────────────
    section("YOUR PERSONAL TOOL")
    print("  Every pilot carries one personal tool — something you've kept through"
          "\n  every berth change, every wreck, every close call.\n")
    print(f"  {C.DIM}Your tool gives +1 when used as a modifier during action checks.\n"
          f"  It can wear and be damaged, and must be repaired before it works again.{C.ENDC}\n")
    for i, (name, desc, affinity) in enumerate(TOOLS_LIBRARY):
        print(f"  {C.GREEN}[{i+1:2}]{C.ENDC} {C.BOLD}{name}{C.ENDC} {C.DIM}({affinity}){C.ENDC}")
        print(f"        {C.DIM}{desc}{C.ENDC}")
    tool_idx = pick("", TOOLS_LIBRARY)
    t_name, t_desc, t_affinity = TOOLS_LIBRARY[tool_idx]
    chosen_tool = Tool(t_name, t_desc, t_affinity)
    game.player.tools.append(chosen_tool)
    print(f"\n  You carry: {C.BOLD}{t_name}{C.ENDC}")
    pause()

    # ── BONDS ────────────────────────────────────────────────────────────────
    section("YOUR BONDS")
    print("  You have three bonds — people whose lives intersect with yours.\n"
          "  Bonds can be used as modifiers during action checks.\n"
          "  They grow or erode based on what you do in their name.\n")

    BOND_ROLES = ["Kin", "Mentor", "Debtor", "Rival", "Crew", "Elder", "Contact", "Ward"]
    BOND_STRENGTHS = ["FRAGILE", "STABLE", "DEEP"]
    BOND_STRENGTH_DESC = [
        "FRAGILE — the relationship is damaged or under strain.",
        "STABLE  — the relationship is functional and reliable.",
        "DEEP    — the relationship carries weight and trust.",
    ]

    # Clear defaults and rebuild through prompts
    game.player.bonds.clear()
    for bond_num in range(1, 4):
        print(f"  {C.HEADER}Bond {bond_num} of 3{C.ENDC}\n")
        name = input(f"  Name: {C.GREEN}").strip() or f"Contact_{bond_num}"
        print(C.ENDC, end="")
        print(f"  Role:\n")
        for i, role in enumerate(BOND_ROLES):
            print(f"    {C.GREEN}[{i+1}]{C.ENDC} {role}")
        role_idx = pick("", BOND_ROLES)
        role = BOND_ROLES[role_idx]
        print(f"\n  Relationship strength:\n")
        for i, s in enumerate(BOND_STRENGTH_DESC):
            print(f"    {C.GREEN}[{i+1}]{C.ENDC} {s}")
        str_idx = pick("", BOND_STRENGTHS)
        strength = BOND_STRENGTHS[str_idx]
        from models import Bond
        game.player.bonds.append(Bond(name, role, strength, chosen_sector))
        print(f"\n  Bonded with: {C.BOLD}{name}{C.ENDC} ({role}) — {strength}\n")
    pause()

    # ── STARTING GOAL ────────────────────────────────────────────────────────
    section("YOUR OPENING DRIVE")
    print("  Every run begins with something at stake. Choose a starting goal\n"
          "  or write your own.\n")
    for i, (stmt, anchor, rank, desc) in enumerate(STARTING_GOALS):
        print(f"  {C.GREEN}[{i+1}]{C.ENDC} {C.BOLD}[{rank}]{C.ENDC} {stmt}")
        print(f"        {C.DIM}{desc}{C.ENDC}")
    print(f"  {C.GREEN}[{len(STARTING_GOALS)+1}]{C.ENDC} Write my own goal")

    goal_options = list(STARTING_GOALS) + [(None, None, None, None)]
    g_idx = pick("", goal_options)
    game.player.goals.clear()
    if g_idx < len(STARTING_GOALS):
        stmt, anchor, rank, _ = STARTING_GOALS[g_idx]
        print(f"\n  Anchor this goal to a specific sector? (Enter name or press Enter to skip)")
        anchor_input = input(f"  {C.GREEN}> {C.ENDC}").strip()
        if anchor_input:
            anchor = anchor_input
    else:
        print(f"\n  Write your goal statement:")
        stmt = input(f"  {C.GREEN}> {C.ENDC}").strip() or "Survive the next run."
        rank = "MAJOR"
        anchor = None
        print(f"  Anchor this goal to a sector? (Enter name or press Enter to skip)")
        anchor_input = input(f"  {C.GREEN}> {C.ENDC}").strip()
        if anchor_input:
            anchor = anchor_input
    game.player.goals.append(Goal(stmt, anchor=anchor, rank=rank))
    print(f"\n  Goal set: {C.BOLD}{stmt}{C.ENDC}")
    pause()

    # ── ORACLE SCENE SEED ────────────────────────────────────────────────────
    section("THE OPENING SCENE")
    print("  Before the first action, the oracle gives you a scene seed.\n"
          "  Use it to frame what your character is doing right now.\n")
    theme, focus = get_theme_focus()
    seed = roll_conversation_seed()
    disp = roll_disposition()
    print(f"  {C.BOLD}Theme / Focus:{C.ENDC}  {C.CYAN}{theme} / {focus}{C.ENDC}")
    print(f"  {C.BOLD}On your mind:{C.ENDC}   {C.CYAN}{seed}{C.ENDC}")
    print(f"  {C.BOLD}Your mood:{C.ENDC}      {C.CYAN}{disp}{C.ENDC}")
    print()
    print(f"  {C.DIM}Use these fragments to write the first sentence of your narrative logbook,{C.ENDC}")
    print(f"  {C.DIM}or simply keep them in mind as you begin.{C.ENDC}\n")
    print(f"  [Reflect?] Write your opening logbook entry, or press Enter to skip.")
    text = input(f"  {C.GREEN}> {C.ENDC}").strip()
    if text:
        with open(game.log_file, "a") as f:
            f.write(f"\n> **[SESSION ZERO — OPENING]** {text}\n\n")

    # ── SUMMARY ──────────────────────────────────────────────────────────────
    section("YOUR VESSEL IS READY")
    print(f"  Sector:  {C.BOLD}{game.current_sector.name}{C.ENDC}")
    print(f"  Tool:    {C.BOLD}{chosen_tool.name}{C.ENDC} — {chosen_tool.description}")
    print(f"  Goal:    {C.BOLD}{game.player.goals[0].statement}{C.ENDC}")
    print(f"  Bonds:")
    for b in game.player.bonds:
        print(f"           {b.name} ({b.role}) — {b.strength}")
    print()
    print(f"  {C.DIM}Type 'state' to see your full starting conditions.{C.ENDC}")
    print(f"  {C.DIM}Type 'help' for all available commands.{C.ENDC}")
    hr()
    print()


def main():
    game = setup_game()
    game.write_session_header()
    session_zero(game)
    
    while True:
        if game.game_over:
            print("\n" + "="*70)
            print("SESSION DEBRIEF - CHRONICLE:")
            for entry in game.chronicle:
                print(entry)
            print("="*70)
            break

        print_header(game)
        cmd_input = input(Colors.GREEN + "> " + Colors.ENDC).strip().split(" ")
        if not cmd_input or not cmd_input[0]:
            continue
            
        cmd = cmd_input[0].lower()
        args = cmd_input[1:]
        
        if cmd not in ["undo", "state", "help", "log", "quit"]:
            import copy
            try:
                if hasattr(game, 'previous_state'):
                    del game.previous_state
                game.previous_state = copy.deepcopy(game)
            except Exception as e:
                pass
        
        if cmd == "help":
            print("=" * 70)
            print("Commands:")
            print("  state - Print full game state (Tracks, Goals, Bonds, Crew)")
            print("  act - Launch the interactive Action/Hook resolution menu")
            print("  travel [destination] - Initiate Travel Phase (or show menu if empty)")
            print("  converse [npc] - Engage in a conversation (or show menu if empty). Also resolves pending notifications.")
            print("  message <npc> <subject> - Send a tight-beam message. Also resolves pending notifications.")
            print("  resolve_message <msg_id> - Action check for an arrived message")
            print("  goal_add <rank> <statement> - Add new goal")
            print("  goal_advance <goal_id> <amount> - Advance a goal track (e.g. goal_advance goal_abc123 1)")
            print("  goal_resolve <goal_id> <cautious/risky> - Resolve a 10/10 goal")
            print("  npc_goal <bond_idx> <action> <target> <motivation> - Add NPC goal")
            print("  remove_tag <tag_name> - Expire a temporary tag")
            print("  oracle <disposition|convo|theme|comp|opp> - Roll an oracle for inspiration")
            print("  wait <ticks> - Advance clock")
            print("  log <text> - Custom Chronicle log")
            print("  undo - Revert the game state to before the last action")
            print("  quit - End session and show Debrief")
            print("=" * 70)
            
        elif cmd == "undo":
            if hasattr(game, 'previous_state') and game.previous_state:
                game = game.previous_state
                print("Undid last action.")
            else:
                print("Nothing to undo.")
                
        elif cmd == "state":
            print_state(game)
            
        elif cmd == "quit":
            game.game_over = True
            
        elif cmd == "wait":
            ticks = int(args[0]) if args else 1
            for _ in range(ticks):
                will_expire = any(not n.resolved and n.expiry_tick == game.clock + 1 for n in game.notifications)
                game.advance_clock(1)
                if will_expire:
                    print("\n[!] Wait interrupted! A notification has expired.")
                    break
            
        elif cmd == "log":
            text = " ".join(args)
            if text:
                game.log_narrative(text)
                print("Logged.")
            else:
                print("Usage: log <text>")
                
        elif cmd == "act":
            resolve_action(game)
            
        elif cmd == "travel":
            if not args:
                print("Available destinations:")
                sectors = list(game.sectors.keys())
                for i, s in enumerate(sectors):
                    print(f"  {i+1}: {s}")
                try:
                    choice = int(input("Select destination (number): ").strip())
                    if 1 <= choice <= len(sectors):
                        do_travel(game, [sectors[choice-1]])
                except ValueError:
                    print("Invalid choice.")
            else:
                do_travel(game, args)
                
        elif cmd == "converse":
            if not args:
                current_npcs = game.get_npcs_at_sector(game.current_sector.name)
                crew = game.player.crew
                if not current_npcs and not crew:
                    print("No NPCs in this sector and no crew.")
                    continue
                
                print("Available to talk:")
                idx = 1
                for n in current_npcs:
                    loc_str = ""
                    if n.vessel_id:
                        v_name = game.vessels[n.vessel_id].name if n.vessel_id in game.vessels else n.vessel_id
                        loc_str = f" (aboard {v_name})"
                    print(f"  {idx}: {n.name}{loc_str}")
                    idx += 1
                
                for c in crew:
                    print(f"  {idx}: {c.name} (Crew aboard your vessel)")
                    idx += 1
                    
                try:
                    choice = int(input("Select NPC (number): ").strip())
                    if 1 <= choice < idx:
                        if choice <= len(current_npcs):
                            do_converse(game, [current_npcs[choice-1].name])
                        else:
                            do_converse(game, [crew[choice - 1 - len(current_npcs)].name])
                except ValueError:
                    print("Invalid choice.")
            else:
                do_converse(game, args)
            
        elif cmd == "message":
            if len(args) >= 2:
                full_args = " ".join(args)
                all_npc_names = [n.name for n in game.get_all_npcs()] + [b.name for b in game.player.bonds]
                to_npc = None
                for n in sorted(set(all_npc_names), key=len, reverse=True):
                    if full_args.lower().startswith(n.lower()):
                        to_npc = n
                        subject = full_args[len(n):].strip()
                        break
                if to_npc:
                    arr_tick = game.clock + 2
                    msg = Message(f"M{game.msg_counter}", to_npc, game.clock, arr_tick, subject)
                    game.message_queue.append(msg)
                    game.msg_counter += 1
                    game.log(f"Sent tight-beam to {to_npc}. Subject: {subject}")
                    print(f"Message sent. Will arrive at T{arr_tick}.")
                    
                    # Resolve any pending notifications from this NPC
                    for n in game.notifications:
                        if not n.resolved and n.source.lower() == to_npc.lower():
                            n.resolved = True
                            print(f"[SYSTEM] Pending notification from {n.source} resolved by sending message.")
                else:
                    print(f"Could not identify a valid NPC from: {full_args}")
            else:
                print("Usage: message <npc> <subject>")
                
        elif cmd == "resolve_message":
            resolve_msg(game, args)
                
        elif cmd == "goal_add":
            if len(args) >= 2:
                rank = args[0].upper()
                stmt = " ".join(args[1:])
                game.player.goals.append(Goal(stmt, rank=rank))
                game.log(f"Added {rank} goal: {stmt}")
                print("Goal added.")
            else:
                print("Usage: goal_add <MINOR/MAJOR/EPIC> <statement>")
                
        elif cmd == "goal_advance":
            if len(args) >= 1:
                try:
                    goal_id = args[0]
                    amt = 1
                    if len(args) == 2:
                        amt = int(args[1])
                    g = next((g for g in game.player.goals if g.id == goal_id), None)
                    if g:
                        max_amt = {"MINOR": 2, "MAJOR": 1, "EPIC": 1}.get(g.rank, 1)
                        if amt > max_amt:
                            print(f"Cannot advance {g.rank} goal by more than {max_amt} per action.")
                            amt = max_amt
                        confirm = input(f"Did your last action advance this goal? (y/n): ")
                        if confirm.lower().startswith('y'):
                            res = g.advance(amt)
                            print(res)
                            game.log(res)
                    else:
                        print("Invalid goal ID.")
                except:
                    print("Usage: goal_advance <goal_id> [amount]")
            else:
                print("Usage: goal_advance <goal_id> [amount]")
                
        elif cmd == "goal_resolve":
            resolve_goal(game, args)
            
        elif cmd == "npc_goal":
            if len(args) >= 4:
                try:
                    idx = int(args[0]) - 1
                    if 0 <= idx < len(game.player.bonds):
                        b = game.player.bonds[idx]
                        action = args[1]
                        target = args[2]
                        motivation = " ".join(args[3:])
                        b.add_goal(action, target, motivation)
                        print(f"Added NPC Goal to {b.name}.")
                        game.log_narrative(f"Authored NPC Goal for {b.name}: Intends to {action} {target} in order to {motivation}")
                except Exception as e:
                    print(f"Failed to add NPC goal: {e}")
            else:
                print("Usage: npc_goal <bond_idx> <action> <target> <motivation>")
                

        elif cmd == "remove_tag":
            if args:
                t = " ".join(args)
                if game.player.remove_tag(t):
                    print(f"Removed tag: {t}")
                    game.log(f"Narrative condition met: removed tag {t}")
                else:
                    print("Tag not found.")
            else:
                print("Usage: remove_tag <tag_name>")
                
        elif cmd == "oracle":
            if not args:
                print("Usage: oracle <disposition|convo|theme|complication|opportunity>")
            elif args[0].lower() == "disposition":
                print(f"[ORACLE] NPC Disposition: {roll_disposition()}")
            elif args[0].lower() in ["convo", "conversation"]:
                print(f"[ORACLE] Conversation Seed: {roll_conversation_seed()}")
            elif args[0].lower() == "theme":
                theme, focus = get_theme_focus()
                print(f"[ORACLE] Theme & Focus: {theme} / {focus}")
            elif args[0].lower() in ["comp", "complication"]:
                name, opts = get_complication()
                print(f"[ORACLE] Complication: {name}")
                print(f"  Options: {', '.join(opts)}")
            elif args[0].lower() in ["opp", "opportunity"]:
                # In space or station? 
                in_space = game.current_sector.name in ["The Scatter", "Orin's Reach", "New Eden"] or game.phase == "Transit"
                name, opts = get_opportunity(in_space=in_space)
                print(f"[ORACLE] Opportunity ({'Space' if in_space else 'Station'}): {name}")
                print(f"  Options: {', '.join(opts)}")
                
        else:
            print("Unknown command.")
            
        if getattr(game, 'reflection_pending', False):
            prompt_reflection(game)
            game.reflection_pending = False

if __name__ == "__main__":
    main()
