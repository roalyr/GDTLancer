import sys
import random
from models import GameState, Sector, Goal, Message, NPC, Hook, TempTag
from oracles import get_complication, get_opportunity, get_community_cost, get_pre_flight_crew, roll_3d6, roll_disposition, roll_conversation_seed, get_action_tracks, generate_dynamic_hook

def setup_game():
    game = GameState()
    
    # Initialize Sectors
    game.sectors["Elace Station"] = Sector("Elace Station", "Planet", wealth=5, security=5, morale=5, supplies=5)
    game.sectors["Elace Station"].npcs = [NPC("Kaelen", "Kin", "Calm"), NPC("Overseer Relt", "Administrator", "Worried")]
    
    game.sectors["Korr Anchorage"] = Sector("Korr Anchorage", "Moon", wealth=3, security=3, morale=4, supplies=3)
    game.sectors["Korr Anchorage"].npcs = [NPC("Voss", "Mentor", "Hopeful"), NPC("Dockmaster Tyra", "Logistics", "Frustrated")]
    
    game.sectors["Veyra Hub"] = Sector("Veyra Hub", "Star", wealth=7, security=7, morale=6, supplies=6)
    game.sectors["Veyra Hub"].npcs = [NPC("Sera", "Debtor", "Distant")]
    
    game.sectors["The Scatter"] = Sector("The Scatter", "Field", wealth=2, security=1, morale=3, supplies=2)
    game.sectors["Orin's Reach"] = Sector("Orin's Reach", "Deep Space", wealth=3, security=4, morale=5, supplies=4)
    
    game.sectors["New Eden"] = Sector("New Eden", "Deep Space", wealth=0, security=0, morale=0, supplies=0)
    game.sectors["New Eden"].npcs = []
    
    game.routes = {
        "Elace Station": {"Korr Anchorage": 1, "Veyra Hub": 2},
        "Korr Anchorage": {"Elace Station": 1, "The Scatter": 1, "Orin's Reach": 3},
        "Veyra Hub": {"Elace Station": 2, "The Scatter": 2, "New Eden": 4},
        "The Scatter": {"Korr Anchorage": 1, "Veyra Hub": 2, "Orin's Reach": 1},
        "Orin's Reach": {"Korr Anchorage": 3, "The Scatter": 1, "New Eden": 2},
        "New Eden": {"Veyra Hub": 4, "Orin's Reach": 2}
    }
    
    game.current_sector = game.sectors["Elace Station"]
    game.phase = "Encounter"
    return game

def generate_sector_hooks(game):
    # Only generate hooks for Encounter phase
    if game.phase == "Encounter":
        for h in game.current_sector.hooks:
            if h.resolved:
                game.current_sector.hooks.remove(h)
                
        # Fill hooks up to 2
        while len(game.current_sector.hooks) < 2 and game.current_sector.npcs:
            provider = random.choice(game.current_sector.npcs)
            name, htype, succ, fail = generate_dynamic_hook(game.current_sector, provider)
            game.current_sector.hooks.append(Hook(name, htype, provider.name, success_opt=succ, fail_opt=fail))

def print_header(game):
    if game.game_over:
        return
    generate_sector_hooks(game)
    print("\n" + "="*70)
    print(f"[{game.current_sector.name} | Phase: {game.phase} | World Clock: T{game.clock}]")
    t = game.player.tracks
    print(f"Tracks: H:{t['Health'].value} W:{t['Wealth'].value} M:{t['Morale'].value} S:{t['Supplies'].value}")
    if game.notifications:
        print("\nNOTIFICATIONS:")
        for n in game.notifications:
            if not n.resolved:
                print(f"  {n}")
    print("=" * 70)
    print("Type 'help' for commands, 'state' for full status.")
    print("=" * 70)

def print_state(game):
    if game.game_over:
        return
        
    generate_sector_hooks(game)
    
    print("\n" + "="*70)
    print(f"[{game.current_sector.name} | Phase: {game.phase} | World Clock: T{game.clock}]")
    print("-" * 70)
    print("PLAYER STATUS (Community Vessel):")
    for track in game.player.tracks.values():
        print(f"  {track}")
    if game.player.tags:
        print(f"  Temporary Tags: {', '.join(str(t) for t in game.player.tags)}")
    print("  Tools: " + (", ".join(game.player.tools) if game.player.tools else "None"))
    
    print("\nBONDS:")
    for i, b in enumerate(game.player.bonds):
        print(f"  {i+1}: {b}")
        for g in b.npc_goals:
            print(f"     - {g}")
        
    print("\nGOALS:")
    for g in game.player.goals:
        print(f"  {g}")

    print("\nCREW:")
    for c in game.player.crew:
        print(f"  {c}")

    print("-" * 70)
    print("COMMUNITY / SECTOR STATUS:")
    print(f"  {game.current_sector}")
    if game.phase == "Encounter":
        if game.current_sector.npcs:
            print(f"  Residents: " + ", ".join(str(npc) for npc in game.current_sector.npcs))
        if game.current_sector.hooks:
            print(f"  Available Hooks:")
            for i, h in enumerate(game.current_sector.hooks):
                print(f"    {i+1}: {h}")
                
    if game.notifications:
        print("\nNOTIFICATIONS:")
        for n in game.notifications:
            if not n.resolved:
                print(f"  {n}")
    print("=" * 70)

def ask_impact_callback(track_name, amount):
    if amount < 0:
        impact_desc = f"Strain on {track_name} is felt."
    else:
        impact_desc = f"Boost to {track_name} invigorates."
    return "Player", impact_desc

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
                    results = game.player.apply_option(selected, is_crisis=is_crisis, impact_callback=ask_impact_callback)
                    print(f"Applied: {selected}")
                    for res in results:
                        if "choose a bond to STRENGTHEN" in res:
                            b = handle_bond_selection(game, "Strengthen which bond?")
                            res_bond = b.modify(1)
                            print(f" -> {res_bond}")
                            game.log(res_bond)
                        elif "choose a bond to WEAKEN" in res:
                            b = handle_bond_selection(game, "Weaken which bond?")
                            res_bond = b.modify(-1)
                            print(f" -> {res_bond}")
                            game.log(res_bond)
                        elif "pending" in res:
                            # Parse sector track change
                            import re
                            match = re.search(r'Sector (Health|Wealth|Morale|Supplies) change ([+-]\d+) pending', res)
                            if match:
                                tr, amt = match.groups()
                                if tr in game.current_sector.tracks:
                                    s_res = game.current_sector.tracks[tr].change(int(amt))
                                    print(f" -> {s_res}")
                                    game.log(f"Sector {game.current_sector.name} {s_res}")
                        else:
                            print(f" -> {res}")
                            game.log(res)
                    break
                else:
                    print("Invalid choice.")
            except ValueError:
                print("Enter a number.")

def roll_action_engine(game, track_name, approach, mod, hook=None):
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
    return outcome

def resolve_action(game, args, hook=None):
    if len(args) < 2:
        print("Usage: act <action_name> <cautious/risky> [bond_idx] [tool_idx]")
        print("Valid actions: command, navigate, endure, overcome, scavenge, repair, barter, acquire, petition, convince, investigate, scan")
        return
        
    action_name = args[0].lower()
    approach = args[1].lower()
    
    valid_tracks = get_action_tracks(action_name)
    if not valid_tracks:
        print("Invalid action name. Use a standard action like 'command', 'repair', 'barter', etc.")
        return
        
    if approach not in ["cautious", "risky"]:
        print("Approach must be 'cautious' or 'risky'.")
        return
        
    track_name = valid_tracks[0]
    if len(valid_tracks) > 1:
        mod1, _ = game.player.get_track_modifier(valid_tracks[0])
        mod2, _ = game.player.get_track_modifier(valid_tracks[1])
        if mod2 > mod1:
            track_name = valid_tracks[1]
            
    print(f"System mapped action '{action_name}' to track '{track_name}'.")

    # Mod calculation
    mod, used_tags = game.player.get_track_modifier(track_name)
    
    # Sector mod based on conditions
    sector_tracks = list(game.current_sector.tracks.values())
    avg_sector = sum(t.value for t in sector_tracks) / 4.0
    if avg_sector > 6:
        print(f"Sector '{game.current_sector.name}' conditions strongly FAVOR the action (+1 mod)")
        mod += 1
    elif avg_sector < 4:
        print(f"Sector '{game.current_sector.name}' conditions OPPOSE the action (-1 mod)")
        mod -= 1
    
    if len(args) > 2:
        try:
            b_idx = int(args[2]) - 1
            b = game.player.bonds[b_idx]
            if b.strength == "DEEP": mod += 1
            elif b.strength == "SEVERED": mod -= 1
        except Exception as e:
            print(f"Invalid bond index: {e}")
            
    if len(args) > 3:
        try:
            t_idx = int(args[3]) - 1
            if 0 <= t_idx < len(game.player.tools): mod += 1
            else: print("Invalid tool index.")
        except Exception as e:
            print(f"Invalid tool index: {e}")
            
    mod = max(-4, min(4, mod))
    
    # Expire used tags
    for t in used_tags:
        game.player.remove_tag(t)
        print(f"Used and expired tag: {t}")
        
    roll_action_engine(game, track_name, approach, mod, hook=hook)
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
    
    # 1. Community Cost
    cost_name, cost_opts = get_community_cost()
    print(f"\n[COMMUNITY COST] {cost_name}")
    for i, opt in enumerate(cost_opts):
        print(f"  {i+1}: {opt}")
    handle_options_loop(game, [("Community Cost Option", cost_opts)])
    
    # 2. Crew Checks
    print("\n[PRE-FLIGHT CREW CHECKS]")
    import random
    issues = []
    for crew in game.player.crew:
        if random.random() < 0.5:
            name, opts, ctype = get_pre_flight_crew()
            issues.append((crew, name, opts, ctype))
            
    if not issues:
        print("All crew report ready.")
    else:
        crew, name, opts, ctype = random.choice(issues)
        print(f"Crew readiness: Most are good. Issue with {crew.name} ({crew.role}): {name}")
        for i, opt in enumerate(opts):
            print(f"  {i+1}: {opt}")
        handle_options_loop(game, [(f"{ctype} for {crew.name}", opts)])
        
    # 3. Travel Transit
    print(f"\n--- TRAVELING TO {dest_name} ---")
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
            
        game.advance_clock(1)
        
    game.current_sector = game.sectors[dest_name]
    game.phase = "Encounter"
    print(f"\nARRIVED at {dest_name}. Phase: {game.phase}")
    game.log(f"Arrived at {dest_name}")

def do_converse(game, args):
    if len(args) < 1:
        print("Usage: converse <npc_name>")
        return
    npc_name = " ".join(args)
    npc = None
    for n in game.current_sector.npcs:
        if n.name.lower() == npc_name.lower():
            npc = n
            break
    if not npc:
        print(f"{npc_name} is not present at {game.current_sector.name}.")
        return

    print(f"\n--- CONVERSATION WITH {npc.name} ---")
    seed = roll_conversation_seed()
    print(f"[ORACLE] Topic suggestion: '{seed}' (press Enter to use)")
    disposition = roll_disposition()
    npc.disposition = disposition
    print(f"[ORACLE] NPC Disposition: {disposition}")

    topic = input("Topic Node (e.g. 'a shortage', 'a rival'): ")
    if not topic.strip():
        topic = seed
        
    outcome = input("Outcome Node (e.g. 'tension increased', 'agreement reached'): ")
    free_text = input("Optional Free Text (dialogue/notes): ")
    
    if disposition in ["Frustrated", "Worried", "Distant"]:
        print("Option: Spend 1 Morale to ease their disposition? (y/n)")
        if input("> ").lower().startswith('y'):
            game.player.tracks["Morale"].change(-1)
            npc.disposition = "Calm"
            print(f"{npc.name} is now Calm.")
    elif disposition in ["Hopeful", "Eager"]:
        print("Option: They offer useful intel (gain tag: Useful Intel). Accept? (y/n)")
        if input("> ").lower().startswith('y'):
            game.player.tags.append(TempTag("Useful Intel", "Used in action"))
            print("Gained tag: Useful Intel")
            
    log_entry = f"Spoke with {npc.name} about {topic} resulting in {outcome}."
    if free_text:
        log_entry += f" Note: {free_text}"
    game.log_narrative(log_entry)
    print("Conversation logged.")

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
        print("Usage: goal_resolve <G1> <cautious/risky>")
        return
    try:
        goal_id_str = args[0].upper().replace('G', '')
        idx = int(goal_id_str)
        app = args[1].lower()
        g = next((g for g in game.player.goals if g.id == idx), None)
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
            else:
                print("Goal resolution hit a snag. Retain it or abandon it.")
                game.log(f"Goal resolution failed: {g.statement}")
            game.advance_clock(1)
        else:
            print("Invalid goal ID.")
    except Exception as e:
        print(f"Error: {e}")

def main():
    game = setup_game()
    game.write_session_header()
    print("Welcome to GDTLancer Playtest CLI")
    
    while True:
        if game.game_over:
            print("\n" + "="*70)
            print("SESSION DEBRIEF - CHRONICLE:")
            for entry in game.chronicle:
                print(entry)
            print("="*70)
            break

        print_header(game)
        cmd_input = input("> ").strip().split(" ")
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
            print("  act <action_name> <cautious/risky> [bond_idx] [tool_idx] - Action Check")
            print("  travel <destination> - Initiate Travel Phase")
            print("  message <npc> <subject> - Send tight-beam message")
            print("  resolve_message <msg_id> - Action check for arrived message")
            print("  converse <npc> - Engage in Free Action conversation")
            print("  goal_add <rank> <statement> - Add new goal")
            print("  goal_advance <goal_id> <amount> - Advance a goal track (e.g. goal_advance G1 1)")
            print("  goal_resolve <goal_id> <cautious/risky> - Resolve a 10/10 goal")
            print("  npc_goal <bond_idx> <action> <target> <motivation> - Add NPC goal")
            print("  hook_resolve <hook_idx> - Mark a hook as resolved")
            print("  remove_tag <tag_name> - Expire a temporary tag")
            print("  oracle <disposition|convo> - Roll an oracle")
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
            game.advance_clock(ticks)
            
        elif cmd == "log":
            text = " ".join(args)
            if text:
                game.log_narrative(text)
                print("Logged.")
            else:
                print("Usage: log <text>")
                
        elif cmd == "act":
            resolve_action(game, args)
            
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
                if not game.current_sector.npcs:
                    print("No NPCs in this sector.")
                    continue
                print("Available NPCs:")
                for i, n in enumerate(game.current_sector.npcs):
                    print(f"  {i+1}: {n.name}")
                try:
                    choice = int(input("Select NPC (number): ").strip())
                    if 1 <= choice <= len(game.current_sector.npcs):
                        do_converse(game, [game.current_sector.npcs[choice-1].name])
                except ValueError:
                    print("Invalid choice.")
            else:
                do_converse(game, args)
            
        elif cmd == "message":
            if len(args) >= 2:
                full_args = " ".join(args)
                all_npcs = [n.name for s in game.sectors.values() for n in s.npcs] + [b.name for b in game.player.bonds]
                to_npc = None
                for n in set(all_npcs):
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
                    goal_id_str = args[0].upper().replace('G', '')
                    idx = int(goal_id_str)
                    amt = 1
                    if len(args) == 2:
                        amt = int(args[1])
                    g = next((g for g in game.player.goals if g.id == idx), None)
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
                    print("Usage: goal_advance <G1> [amount]")
            else:
                print("Usage: goal_advance <G1> [amount]")
                
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
                
        elif cmd == "hook_resolve":
            if not args:
                unresolved = [h for h in game.current_sector.hooks if not h.resolved]
                if not unresolved:
                    print("No unresolved hooks here.")
                    continue
                print("Available hooks:")
                for i, h in enumerate(unresolved):
                    print(f"  {i+1}: {h.name}")
                try:
                    choice = int(input("Select hook (number): ").strip())
                    if 1 <= choice <= len(unresolved):
                        h = unresolved[choice-1]
                        h.resolved = True
                        print(f"Hook resolved: {h.name}")
                        game.log(f"Resolved hook: {h.name}")
                        print("Would you like to trigger an Action Check for this resolution? (y/n)")
                        if input("> ").lower().startswith('y'):
                            print("Format: <action_name> <cautious/risky> [bond_idx] [tool_idx]")
                            act_args = input("Enter action args: ").strip().split(" ")
                            if len(act_args) >= 2:
                                resolve_action(game, act_args, hook=h)
                except ValueError:
                    print("Invalid choice.")
            else:
                try:
                    idx = int(args[0]) - 1
                    if 0 <= idx < len(game.current_sector.hooks):
                        h = game.current_sector.hooks[idx]
                        h.resolved = True
                        print(f"Hook resolved: {h.name}")
                        game.log(f"Resolved hook: {h.name}")
                        print("Would you like to trigger an Action Check for this resolution? (y/n)")
                        if input("> ").lower().startswith('y'):
                            print("Format: <action_name> <cautious/risky> [bond_idx] [tool_idx]")
                            act_args = input("Enter action args: ").strip().split(" ")
                            if len(act_args) >= 2:
                                resolve_action(game, act_args, hook=h)
                except Exception as e:
                    print(f"Failed to resolve hook: {e}")
                
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
                print("Usage: oracle <disposition|convo>")
            elif args[0].lower() == "disposition":
                print(f"[ORACLE] NPC Disposition: {roll_disposition()}")
            elif args[0].lower() in ["convo", "conversation"]:
                print(f"[ORACLE] Conversation Seed: {roll_conversation_seed()}")
                
        else:
            print("Unknown command.")

if __name__ == "__main__":
    main()
