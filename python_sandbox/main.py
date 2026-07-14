import sys
import random
from models import GameState, Sector, Goal, Message, NPC, Hook
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
            name, htype = generate_dynamic_hook(game.current_sector, provider)
            game.current_sector.hooks.append(Hook(name, htype, provider.name))

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
    for i, g in enumerate(game.player.goals):
        print(f"  {i+1}: {g}")

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
    print("Commands:")
    print("  act <action_name> <cautious/risky> [bond_idx] [tool_idx] - Action Check")
    print("  travel <destination> - Initiate Travel Phase")
    print("  message <npc> <subject> - Send tight-beam message")
    print("  resolve_message <msg_id> - Action check for arrived message")
    print("  converse <npc> - Engage in Free Action conversation")
    print("  goal_add <rank> <statement> - Add new goal")
    print("  goal_advance <goal_idx> <amount> - Advance a goal track")
    print("  goal_resolve <goal_idx> <cautious/risky> - Resolve a 10/10 goal")
    print("  npc_goal <bond_idx> <action> <target> <motivation> - Add NPC goal")
    print("  hook_resolve <hook_idx> - Mark a hook as resolved")
    print("  remove_tag <tag_name> - Expire a temporary tag")
    print("  wait <ticks> - Advance clock")
    print("  log <text> - Custom Chronicle log")
    print("  quit - End session and show Debrief")
    print("=" * 70)

def ask_impact_callback(track_name, amount):
    print(f"\n[NAMED IMPACT RULE] Track '{track_name}' changed by {amount:d}.")
    while True:
        target = input("Apply to (P)layer or (S)ector? [P/S]: ").upper()
        if target in ["P", "S"]:
            break
    
    print("Who in the community is affected by this?")
    impact_desc = input("> ")
    return ("Player" if target == "P" else "Sector"), impact_desc

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
            choice = input(f"Enter choice for {opt_type} (1-{len(opt_list)}): ")
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(opt_list):
                    selected = opt_list[idx]
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

def roll_action_engine(game, track_name, approach, mod):
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

def resolve_action(game, args):
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
        mod1 = game.player.get_track_modifier(valid_tracks[0])
        mod2 = game.player.get_track_modifier(valid_tracks[1])
        if mod2 > mod1:
            track_name = valid_tracks[1]
            
    print(f"System mapped action '{action_name}' to track '{track_name}'.")

    # Mod calculation
    mod = game.player.get_track_modifier(track_name)
    
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
        except: pass
            
    if len(args) > 3:
        try:
            t_idx = int(args[3]) - 1
            if 0 <= t_idx < len(game.player.tools): mod += 1
        except: pass
            
    mod = max(-4, min(4, mod))
    roll_action_engine(game, track_name, approach, mod)
    game.advance_clock(1)

def do_travel(game, destination_str):
    dest_name = " ".join(destination_str)
    if dest_name not in game.sectors:
        print(f"Unknown destination: {dest_name}")
        print("Available:", list(game.sectors.keys()))
        return
        
    game.phase = "Travel"
    game.log(f"Initiated travel to {dest_name}")
    print("\n--- PRE-DEPARTURE SEQUENCE ---")
    
    # 1. Community Cost
    cost_name, cost_opts = get_community_cost()
    print(f"\n[COMMUNITY COST] {cost_name}")
    for i, opt in enumerate(cost_opts):
        print(f"  {i+1}: {opt}")
    handle_options_loop(game, [("Community Cost Option", cost_opts)])
    
    # 2. Crew Checks
    print("\n[PRE-FLIGHT CREW CHECKS]")
    for crew in game.player.crew:
        name, opts, ctype = get_pre_flight_crew()
        print(f"\nCrew '{crew.name}' ({crew.role}): {name} ({ctype})")
        for i, opt in enumerate(opts):
            print(f"  {i+1}: {opt}")
        handle_options_loop(game, [(f"{ctype} for {crew.name}", opts)])
        
    # 3. Travel Transit
    distance = 1
    print(f"\n--- TRAVELING TO {dest_name} ---")
    for _ in range(distance):
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
    npc = " ".join(args)
    print(f"\n--- CONVERSATION WITH {npc} ---")
    topic = input("Topic Node (e.g. 'a shortage', 'a rival'): ")
    outcome = input("Outcome Node (e.g. 'tension increased', 'agreement reached'): ")
    free_text = input("Optional Free Text (dialogue/notes): ")
    
    log_entry = f"Spoke with {npc} about {topic} resulting in {outcome}."
    if free_text:
        log_entry += f" Note: {free_text}"
    game.log_narrative(log_entry)
    print("Conversation logged as free action.")

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
            
            mod = game.player.get_track_modifier("Morale")
            outcome = roll_action_engine(game, "Morale", approach, mod)
            m.status = "RESOLVED"
            game.log(f"Resolved message {m.id} with outcome: {outcome}")
            return
    print("No pending ARRIVED message found with that ID.")

def resolve_goal(game, args):
    if len(args) < 2:
        print("Usage: goal_resolve <goal_idx> <cautious/risky>")
        return
    try:
        idx = int(args[0]) - 1
        app = args[1].lower()
        if 0 <= idx < len(game.player.goals):
            g = game.player.goals[idx]
            if g.progress < 10:
                print("Goal must reach 10 progress to resolve.")
                return
            print(f"Attempting to resolve goal: {g.statement}")
            mod = game.player.get_track_modifier("Morale")
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
            print("Invalid goal index.")
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

        print_state(game)
        cmd_input = input("> ").strip().split(" ")
        if not cmd_input or not cmd_input[0]:
            continue
            
        cmd = cmd_input[0].lower()
        args = cmd_input[1:]
        
        if cmd == "quit":
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
            do_travel(game, args)
            
        elif cmd == "converse":
            do_converse(game, args)
            
        elif cmd == "message":
            if len(args) >= 2:
                to_npc = args[0]
                subject = " ".join(args[1:])
                arr_tick = game.clock + 2
                msg = Message(f"M{game.msg_counter}", to_npc, game.clock, arr_tick, subject)
                game.message_queue.append(msg)
                game.msg_counter += 1
                game.log(f"Sent tight-beam to {to_npc}. Subject: {subject}")
                print(f"Message sent. Will arrive at T{arr_tick}.")
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
            if len(args) == 2:
                try:
                    idx = int(args[0]) - 1
                    amt = int(args[1])
                    if 0 <= idx < len(game.player.goals):
                        res = game.player.goals[idx].advance(amt)
                        print(res)
                        game.log(res)
                    else:
                        print("Invalid goal index.")
                except:
                    print("Usage: goal_advance <index> <amount>")
            else:
                print("Usage: goal_advance <index> <amount>")
                
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
                except: pass
            else:
                print("Usage: npc_goal <bond_idx> <action> <target> <motivation>")
                
        elif cmd == "hook_resolve":
            if len(args) >= 1:
                try:
                    idx = int(args[0]) - 1
                    if 0 <= idx < len(game.current_sector.hooks):
                        h = game.current_sector.hooks[idx]
                        h.resolved = True
                        print(f"Hook resolved: {h.name}")
                        game.log(f"Resolved hook: {h.name}")
                except: pass
                
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
