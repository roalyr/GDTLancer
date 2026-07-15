import curses
import copy
import textwrap
import re
import random
from models import GameState, TempTag, Goal, Message, Hook
from oracles import *
from main import setup_game, generate_sector_hooks

class TUI:
    def __init__(self, stdscr):
        self.stdscr = stdscr
        try:
            curses.curs_set(0)
        except curses.error:
            pass
        curses.mousemask(curses.ALL_MOUSE_EVENTS | curses.REPORT_MOUSE_POSITION)
        self.game = setup_game()
        self.game.previous_state = None
        self.log_lines = ["[System] Welcome to GDTLancer TUI Sandbox"]
        self.menu_stack = []
        self.show_full_state = False
        self.state_scroll_offset = 0
        
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_CYAN, -1)     
        curses.init_pair(2, curses.COLOR_GREEN, -1)    
        curses.init_pair(3, curses.COLOR_RED, -1)      
        curses.init_pair(4, curses.COLOR_BLACK, curses.COLOR_WHITE) 
        curses.init_pair(5, curses.COLOR_BLACK, curses.COLOR_CYAN)  
        curses.init_pair(6, curses.COLOR_BLACK, curses.COLOR_RED)   
        curses.init_pair(7, curses.COLOR_BLACK, curses.COLOR_GREEN) 
        curses.init_pair(8, curses.COLOR_YELLOW, -1)   
        
        self.push_main_menu()

    def log(self, msg):
        self.log_lines.append(msg)
        self.game.log(msg)
        
    def save_undo(self):
        # Detach previous state chain to prevent recursive deepcopy crashes
        prev = getattr(self.game, 'previous_state', None)
        self.game.previous_state = None
        state_copy = copy.deepcopy(self.game)
        self.game.previous_state = state_copy
        state_copy.previous_state = prev

    def do_undo(self):
        if self.game.previous_state:
            self.game = self.game.previous_state
            self.log("[System] Undid last action.")
            self.menu_stack = []
            self.push_main_menu()
        else:
            self.log("[System] Nothing to undo.")

    def push_menu(self, title, text, options):
        self.menu_stack.append({"title": title, "text": text, "options": options})

    def pop_menu(self):
        if self.menu_stack:
            self.menu_stack.pop()
        if not self.menu_stack:
            self.push_main_menu()

    def replace_menu(self, title, text, options):
        if self.menu_stack:
            self.menu_stack.pop()
        self.push_menu(title, text, options)
        
    def get_string(self, prompt_text="> "):
        max_y, max_x = self.stdscr.getmaxyx()
        self.stdscr.addstr(max_y-1, 0, " " * (max_x - 1))
        self.stdscr.addstr(max_y-1, 0, prompt_text)
        curses.echo()
        try:
            curses.curs_set(1)
        except curses.error:
            pass
        self.stdscr.refresh()
        s = self.stdscr.getstr(max_y-1, len(prompt_text), 500).decode('utf-8')
        curses.noecho()
        try:
            curses.curs_set(0)
        except curses.error:
            pass
        self.stdscr.addstr(max_y-1, 0, " " * (max_x - 1))
        return s

    def draw(self):
        self.stdscr.clear()
        max_y, max_x = self.stdscr.getmaxyx()
        mid_y = max_y // 2
        mid_x = max_x // 2
        
        generate_sector_hooks(self.game)
        loc_status = "In Space" if self.game.phase == "Travel" or self.game.current_sector.type == "Deep Space" else "Docked"
        self.stdscr.addstr(0, 0, f" [{self.game.current_sector.name} ({loc_status}) | Phase: {self.game.phase} | T{self.game.clock}] ", curses.color_pair(1) | curses.A_BOLD)
        
        t = self.game.player.tracks
        self.stdscr.addstr(1, 0, f" Tracks: H:{t['Health'].value} W:{t['Wealth'].value} M:{t['Morale'].value} S:{t['Supplies'].value} ")
        tag_str = ", ".join(str(tg) for tg in self.game.player.tags) if self.game.player.tags else "None"
        self.stdscr.addstr(2, 0, f" Tags: {tag_str}")
        bonds_str = ", ".join(f"{b.name}({b.strength[:3]})" for b in self.game.player.bonds) if self.game.player.bonds else "None"
        self.stdscr.addstr(3, 0, f" Bonds: {bonds_str}")
        
        self.stdscr.addstr(4, 0, " Goals:")
        goal_y = 5
        for g in self.game.player.goals[:4]: 
            try:
                self.stdscr.addstr(goal_y, 2, f"[{g.rank[:3]}] {g.statement[:mid_x-10]} ({g.progress}/10)")
                goal_y += 1
            except curses.error: pass
            
        unresolved_hooks = [h for h in self.game.current_sector.hooks if not h.resolved]
        try:
            self.stdscr.addstr(goal_y, 0, f" Hooks: {len(unresolved_hooks)} active")
            goal_y += 1
            npcs_str = ", ".join(n.name for n in self.game.current_sector.npcs) if self.game.current_sector.npcs else "None"
            self.stdscr.addstr(goal_y, 0, f" Local NPCs: {npcs_str[:mid_x-15]}")
        except curses.error: pass
        
        for y in range(0, mid_y):
            try:
                self.stdscr.addch(y, mid_x, '|')
            except curses.error: pass

        self.stdscr.addstr(0, mid_x + 2, " CHRONICLE ", curses.A_BOLD)
        log_height = mid_y - 1
        visible_logs = self.log_lines[-log_height:] if len(self.log_lines) > log_height else self.log_lines
        for i, line in enumerate(visible_logs):
            try:
                self.stdscr.addstr(1 + i, mid_x + 2, line[:(max_x - mid_x - 3)])
            except curses.error: pass

        try:
            self.stdscr.addstr(mid_y, 0, "-" * (max_x - 1))
        except curses.error: pass

        if self.menu_stack:
            menu = self.menu_stack[-1]
            try:
                self.stdscr.addstr(mid_y + 1, 2, menu["title"], curses.A_BOLD)
                wrapped = []
                for paragraph in str(menu["text"]).split('\n'):
                    if paragraph.strip() == "":
                        wrapped.append("")
                    else:
                        wrapped.extend(textwrap.wrap(paragraph, width=max_x - 6))
                text_y = mid_y + 3
                for line in wrapped:
                    self.stdscr.addstr(text_y, 4, line)
                    text_y += 1
                
                self.active_buttons = []
                btn_start_y = text_y + 1
                curr_y = btn_start_y
                curr_x = 4
                
                # Dynamic column width based on longest label
                max_label_len = max([len(l) for l, _, _ in menu["options"]] + [20])
                col_width = min(max_label_len + 8, max_x - 10)
                
                for label, cb, color in menu["options"]:
                    if curr_y >= max_y - 1:
                        curr_y = btn_start_y
                        curr_x += col_width
                        if curr_x >= max_x - 20: break 
                    btn_str = f" [ {label} ] "
                    if len(btn_str) > col_width - 2:
                        btn_str = btn_str[:col_width-5] + "... ] "
                    self.stdscr.addstr(curr_y, curr_x, btn_str, curses.color_pair(color))
                    self.active_buttons.append((curr_y, curr_x, curr_x + len(btn_str), cb))
                    curr_y += 2
            except curses.error: pass

        self.stdscr.refresh()

    def handle_mouse(self):
        try:
            _, x, y, _, bstate = curses.getmouse()
            if bstate & (curses.BUTTON1_CLICKED | curses.BUTTON1_RELEASED | curses.BUTTON1_PRESSED):
                if hasattr(self, 'active_buttons'):
                    for by, bx_start, bx_end, cb in self.active_buttons:
                        if y == by and bx_start <= x <= bx_end:
                            cb()
                            return
        except curses.error:
            pass

    def run(self):
        while True:
            if self.game.game_over and not getattr(self, 'game_over_shown', False):
                self.game_over_shown = True
                
            if hasattr(self.game, 'pending_alerts') and self.game.pending_alerts:
                alert = self.game.pending_alerts.pop(0)
                if "[GAME OVER" in alert:
                    self.push_menu("GAME OVER", alert, [("Quit", lambda: exit(0), 4)])
                else:
                    self.push_menu("ALERT", alert, [("Acknowledge", self.pop_menu, 6)])

            if self.show_full_state:
                self.draw_full_state()
            else:
                self.draw()
                
            event = self.stdscr.getch()
            
            if self.show_full_state:
                if event == curses.KEY_UP or event == ord('w'):
                    self.state_scroll_offset = max(0, self.state_scroll_offset - 1)
                elif event == curses.KEY_DOWN or event == ord('s'):
                    # We don't have the exact max lines here, but we can safely let it scroll down.
                    # Or limit it in draw_full_state.
                    self.state_scroll_offset += 1
                elif event in [ord('q'), 27]: # q or ESC
                    self.show_full_state = False
                elif event == curses.KEY_MOUSE:
                    try:
                        _, _, _, _, bstate = curses.getmouse()
                        if bstate & getattr(curses, 'BUTTON4_PRESSED', 65536) or bstate == 65536:
                            self.state_scroll_offset = max(0, self.state_scroll_offset - 1)
                        elif bstate & getattr(curses, 'BUTTON5_PRESSED', 2097152) or bstate == 2097152:
                            self.state_scroll_offset += 1
                        elif bstate & (curses.BUTTON1_CLICKED | curses.BUTTON1_PRESSED):
                            self.show_full_state = False
                    except curses.error:
                        pass
                continue

            if event == ord('q'): break
            elif event == curses.KEY_MOUSE: self.handle_mouse()
            elif event == ord('u'): self.do_undo()

    def push_main_menu(self):
        options = []
        active_nots = [n for n in self.game.notifications if not n.resolved]
        if active_nots:
            for n in active_nots:
                options.append((f"! {n.source}'s Request !", lambda n=n: self.flow_resolve_notification(n), 8))
                
        options.extend([
            ("Act", self.flow_act, 6),           
            ("Travel", self.flow_travel, 5),     
            ("Converse", self.flow_converse, 5), 
            ("Hooks", self.flow_hooks, 7),       
            ("Goals", self.flow_goals, 5),
            ("Messages", self.flow_messages, 5),
            ("Tags/Bonds", self.flow_tags_bonds, 5),
            ("Wait (+1 Tick)", self.do_wait, 4),
            ("Custom Log", self.do_log, 4),
            ("Full State", self.flow_full_state, 5),
            ("Undo", self.do_undo, 4),
            ("Quit", lambda: exit(0), 4)
        ])
        text = "Select an action below. Press 'q' to quit, 'u' to undo."
        self.replace_menu("MAIN MENU", text, options)
        
    def flow_resolve_notification(self, notif):
        def do_act():
            notif.resolved = True
            self.pop_menu()
            self.flow_act(context=f"Notification: {notif.source} - {notif.reason}")
        def do_msg():
            notif.resolved = True
            self.pop_menu()
            self.flow_messages()
        def do_dismiss():
            notif.resolved = True
            self.pop_menu()
            self.log(f"Dismissed notification from {notif.source}")
            
        text = f"Notification from {notif.source}\nReason: {notif.reason}\nExpires: T{notif.expiry_tick}\n\nHow do you want to respond?"
        opts = [
            ("Take Action (Act)", do_act, 6),
            ("Send Message", do_msg, 5),
            ("Dismiss/Ignore", do_dismiss, 4),
            ("Back", self.pop_menu, 4)
        ]
        self.push_menu(f"Notification: {notif.source}", text, opts)

    def do_wait(self):
        self.save_undo()
        self.game.advance_clock(1)
        self.log("Waited 1 tick.")
        
    def do_log(self):
        txt = self.get_string("Enter log text: ")
        if txt:
            self.log(f"Log: {txt}")
            
    def flow_full_state(self):
        self.show_full_state = True
        self.state_scroll_offset = 0
        
    def draw_full_state(self):
        self.stdscr.clear()
        max_y, max_x = self.stdscr.getmaxyx()
        
        lines = []
        lines.append(f"=== FULL STATE OVERVIEW ===")
        lines.append(f"Sector: {self.game.current_sector.name} ({self.game.current_sector.type})")
        lines.append(f"Phase: {self.game.phase} | World Clock: T{self.game.clock}")
        
        lines.append(""); lines.append("--- PLAYER ---")
        lines.append(f"Vessel: {self.game.player.vessel_status}")
        lines.append("Tracks:")
        for t in self.game.player.tracks.values():
            lines.append(f"  {t.name}: {t.tier_name} ({t.value}/10) [Mod: {t.modifier:+d}]")
        
        lines.append("Crew:")
        for c in self.game.player.crew:
            lines.append(f"  {c.name} ({c.role}) - Morale: {c.morale}")
            
        lines.append("Tools:")
        for t in self.game.player.tools:
            lines.append(f"  {t}")
            
        lines.append("Tags:")
        if self.game.player.tags:
            for tag in self.game.player.tags:
                lines.append(f"  {tag}")
        else:
            lines.append("  None")

        lines.append(""); lines.append("--- RELATIONSHIPS & GOALS ---")
        lines.append("Bonds:")
        if self.game.player.bonds:
            for b in self.game.player.bonds:
                lines.append(f"  {b.name} ({b.role}) - Strength: {b.strength}")
                for ng in b.npc_goals:
                    lines.append(f"    - {ng}")
        else:
            lines.append("  None")
                
        lines.append("Player Goals:")
        if self.game.player.goals:
            for g in self.game.player.goals:
                lines.append(f"  [{g.rank}] {g.statement} (Progress: {g.progress}/10)")
        else:
            lines.append("  None")

        lines.append(""); lines.append("--- CURRENT SECTOR ---")
        lines.append("Sector Tracks:")
        for t in self.game.current_sector.tracks.values():
            lines.append(f"  {t.name}: {t.value}/10")
            
        lines.append("Local NPCs:")
        if self.game.current_sector.npcs:
            for n in self.game.current_sector.npcs:
                lines.append(f"  {n.name} ({n.role}) - Disposition: {n.disposition}")
        else:
            lines.append("  None")
            
        lines.append("Hooks:")
        if self.game.current_sector.hooks:
            for h in self.game.current_sector.hooks:
                res_str = "[RESOLVED]" if h.resolved else "[OPEN]"
                lines.append(f"  {res_str} [{h.hook_type}] {h.name} (Source: {h.provider})")
                lines.append(f"    Success: {h.success_opt}")
                lines.append(f"    Failure: {h.fail_opt}")
        else:
            lines.append("  None")

        lines.append(""); lines.append("--- NAV ROUTES ---")
        lines.append("Routes:")
        for r, d in self.game.routes.get(self.game.current_sector.name, {}).items():
            lines.append(f"  -> {r} (Dist: {d})")

        # Clamp scroll
        max_scroll = max(0, len(lines) - (max_y - 3))
        self.state_scroll_offset = min(max_scroll, self.state_scroll_offset)
        
        visible_lines = lines[self.state_scroll_offset : self.state_scroll_offset + max_y - 2]
        
        for i, line in enumerate(visible_lines):
            try:
                self.stdscr.addstr(i, 2, line[:max_x-4])
            except curses.error:
                pass
                
        try:
            scroll_percent = int((self.state_scroll_offset / max(1, max_scroll)) * 100) if max_scroll > 0 else 100
            self.stdscr.addstr(max_y-1, 2, f"[ UP/DOWN: Scroll ({scroll_percent}%) ]  [ Q or CLICK: Close ]", curses.color_pair(5))
        except curses.error: pass
        self.stdscr.refresh()

    def apply_track_option(self, option_str, is_crisis=False):
        results = self.game.player.apply_option(option_str, is_crisis=is_crisis, impact_callback=lambda t, a: ("Player", f"Strain on {t} is felt." if a < 0 else f"Boost to {t} invigorates."))
        for res in results:
            if "choose a bond to STRENGTHEN" in res:
                self.flow_modify_bond(1)
            elif "choose a bond to WEAKEN" in res:
                self.flow_modify_bond(-1)
            elif "pending" in res:
                match = re.search(r'Sector (Health|Wealth|Morale|Supplies) change ([+-]\d+) pending', res)
                if match:
                    tr, amt = match.groups()
                    if tr in self.game.current_sector.tracks:
                        s_res = self.game.current_sector.tracks[tr].change(int(amt))
                        self.log(f"Sector {self.game.current_sector.name} {s_res}")
            else:
                self.log(res)

    def flow_modify_bond(self, amount):
        opts = []
        for b in self.game.player.bonds:
            opts.append((f"{b.name} ({b.strength})", lambda b=b: self._apply_bond_mod(b, amount), 7 if amount > 0 else 6))
        self.push_menu("Select Bond to Modify", f"Apply {amount} to a bond.", opts)

    def _apply_bond_mod(self, bond, amount):
        res = bond.modify(amount)
        self.log(res)
        self.pop_menu()

    def process_action_outcome(self, outcome, is_crisis, hook=None, context=""):
        in_space = self.game.phase == "Travel"
        
        def do_apply(opt, crisis):
            self.pop_menu()
            self.apply_track_option(opt, crisis)

        def push_disadv(context_str=""):
            comp_name, dis_options = get_complication()
            text = f"{context_str}\n[COMPLICATION] {comp_name}\n"
            if is_crisis: text += "CRISIS ACTIVE: Negative track hits are doubled (-2)!\n"
            text += "Choose your disadvantage:"
            opts = [(opt, lambda o=opt: do_apply(o, is_crisis), 6) for opt in dis_options]
            self.push_menu("Action Disadvantage", text, opts)
            
        def push_adv(next_step=None, context_str=""):
            opp_name, adv_options = get_opportunity(in_space)
            text = f"{context_str}\n[OPPORTUNITY] {opp_name}\nChoose your advantage:"
            opts = []
            for opt in adv_options:
                def cb(o=opt):
                    self.pop_menu()
                    self.apply_track_option(o, is_crisis)
                    if next_step: next_step()
                opts.append((opt, cb, 7))
            self.push_menu("Action Advantage", text, opts)

        c_str = context if context else ""

        if hook:
            hook.resolved = True
            if "Success" in outcome:
                self.log(f"[HOOK SUCCESS] {hook.success_opt}")
                text = f"{c_str}\n\n[SUCCESS]\nYou fully resolved the hook!\nRewards: {hook.success_opt}"
                self.push_menu("Hook Success", text, [("Excellent", lambda: do_apply(hook.success_opt, is_crisis), 7)])
            elif outcome == "Partial":
                self.log(f"[HOOK SUCCESS] {hook.success_opt}")
                self.apply_track_option(hook.success_opt, is_crisis)
                text = f"{c_str}\n\n[PARTIAL SUCCESS]\nYou succeeded ({hook.success_opt}) but suffer a complication:\n{hook.fail_opt}"
                self.push_menu("Hook Complication", text, [("Accept", lambda: do_apply(hook.fail_opt, is_crisis), 6)])
            else:
                self.log(f"[HOOK FAILURE] {hook.fail_opt}")
                text = f"{c_str}\n\n[FAILURE]\nYou failed to resolve the hook. Consequences:\n{hook.fail_opt}"
                if is_crisis: text += "\nCRISIS ACTIVE (-2 instead of -1)!"
                self.push_menu("Hook Failure", text, [("Accept", lambda: do_apply(hook.fail_opt, is_crisis), 6)])
        else:
            if "Success" in outcome: push_adv(context_str=c_str)
            elif outcome == "Partial": push_adv(next_step=lambda: push_disadv(context_str=c_str), context_str=c_str)
            elif outcome in ["Setback", "Crisis"]: push_disadv(context_str=c_str)

    def do_action_roll(self, action_name, approach, bond=None, tool=None, hook=None, context=""):
        self.save_undo()
        valid_tracks = get_action_tracks(action_name)
        track_name = valid_tracks[0]
        if len(valid_tracks) > 1:
            mod1, _ = self.game.player.get_track_modifier(valid_tracks[0])
            mod2, _ = self.game.player.get_track_modifier(valid_tracks[1])
            if mod2 > mod1: track_name = valid_tracks[1]
                
        mod, used_tags = self.game.player.get_track_modifier(track_name)
        sector_tracks = list(self.game.current_sector.tracks.values())
        avg_sector = sum(t.value for t in sector_tracks) / 4.0
        if avg_sector > 6: mod += 1
        elif avg_sector < 4: mod -= 1
            
        if bond:
            if bond.strength == "DEEP": mod += 1
            elif bond.strength == "SEVERED": mod -= 1
        if tool:
            mod += 1

        mod = max(-4, min(4, mod))

        for t in used_tags:
            self.game.player.remove_tag(t)
            self.log(f"Used tag: {t}")
            
        roll = roll_3d6()
        total = roll + mod
        is_crisis = False
        is_outstanding = False
        if approach == "risky":
            if roll <= 5: total = 6; is_crisis = True
            elif roll >= 16: total = 15; is_outstanding = True
                
        if total <= 6: outcome = "Crisis" if is_crisis else "Setback"
        elif total <= 10: outcome = "Partial"
        elif total <= 14: outcome = "Success"
        else: outcome = "Success (Outstanding)" if is_outstanding else "Success"

        roll_desc = f"Roll: 3d6({roll}) {mod:+d} mod = {total} -> {outcome.upper()}"
        self.log(f"Action: {action_name.capitalize()} ({approach.capitalize()}) via {track_name}. {roll_desc}")
        
        # Robustly clear action menus back to Main Menu
        self.menu_stack = []
        self.push_main_menu()
        
        extended_context = f"{context}\n{roll_desc}" if context else roll_desc
        self.process_action_outcome(outcome, is_crisis, hook, extended_context)
        self.game.advance_clock(1)

    def flow_act_modifiers(self, action_name, approach, hook=None, context=""):
        bonds = self.game.player.bonds
        tools = self.game.player.tools
        def choose_tool(b=None):
            if not tools:
                self.do_action_roll(action_name, approach, b, None, hook, context)
                return
            opts = [(t, lambda t=t: self.do_action_roll(action_name, approach, b, t, hook, context), 5) for t in tools]
            opts.append(("No Tool", lambda: self.do_action_roll(action_name, approach, b, None, hook, context), 4))
            self.push_menu(f"Select Tool", f"{context}\nOptionally select a tool (+1 Mod):", opts)
            
        if not bonds:
            choose_tool()
            return
        opts = [(b.name, lambda b=b: choose_tool(b), 5) for b in bonds]
        opts.append(("No Bond", lambda: choose_tool(None), 4))
        self.push_menu(f"Select Bond", f"{context}\nOptionally invoke a bond (Deep = +1, Severed = -1):", opts)

    def flow_act_approach(self, action_name, hook=None, context=""):
        opts = [
            ("Cautious", lambda: self.flow_act_modifiers(action_name, "cautious", hook, context), 5),
            ("Risky", lambda: self.flow_act_modifiers(action_name, "risky", hook, context), 6),
            ("Cancel", self.pop_menu, 4)
        ]
        self.push_menu(f"Approach: {action_name.capitalize()}", f"{context}\nChoose approach.", opts)

    def flow_act(self, hook=None, context=""):
        actions = ["command", "navigate", "endure", "overcome", "scavenge", "repair", "barter", "acquire", "petition", "convince", "investigate", "scan"]
        opts = [(a.capitalize(), lambda a=a: self.flow_act_approach(a, hook, context), 6) for a in actions]
        opts.append(("Cancel", self.pop_menu, 4))
        self.push_menu("Select Action", (f"{context}\n" if context else "") + "What action are you taking?", opts)

    def flow_travel(self):
        sectors = list(self.game.sectors.keys())
        opts = [(s, lambda s=s: self.do_travel_step1(s), 5) for s in sectors if s != self.game.current_sector.name]
        opts.append(("Cancel", self.pop_menu, 4))
        self.push_menu("Travel", "Select destination.", opts)

    def do_travel_step1(self, dest_name):
        self.save_undo()
        import heapq
        distances = {s: float('inf') for s in self.game.sectors}
        distances[self.game.current_sector.name] = 0
        pq = [(0, self.game.current_sector.name)]
        while pq:
            d, current = heapq.heappop(pq)
            if d > distances[current]: continue
            if current == dest_name: break
            for neighbor, weight in self.game.routes.get(current, {}).items():
                dist = d + weight
                if dist < distances[neighbor]:
                    distances[neighbor] = dist
                    heapq.heappush(pq, (dist, neighbor))
        
        distance = distances[dest_name]
        if distance == float('inf'):
            self.push_menu("Error", "No route.", [("OK", self.pop_menu, 4)]); return
            
        self.game.phase = "Travel"
        self.log(f"Initiated travel to {dest_name} (Dist: {distance})")
        
        # 1. Community Cost
        cost_name, cost_opts = get_community_cost()
        def pick_cost(opt):
            self.pop_menu()
            self.apply_track_option(opt, False)
            # 2. Crew Checks
            issues = []
            for crew in self.game.player.crew:
                if random.random() < 0.5:
                    name, opts, ctype = get_pre_flight_crew()
                    issues.append((crew, name, opts, ctype))
            if issues:
                crew, name, opts, ctype = random.choice(issues)
                def pick_crew(opt2):
                    self.pop_menu()
                    self.apply_track_option(opt2, False)
                    self.do_travel_step3(dest_name, distance)
                c_opts = [(o, lambda o=o: pick_crew(o), 6) for o in opts]
                self.push_menu(f"{ctype} for {crew.name}", f"Transit to {dest_name}\nIssue: {name}", c_opts)
            else:
                self.do_travel_step3(dest_name, distance)
                
        c_opts = [(o, lambda o=o: pick_cost(o), 6) for o in cost_opts]
        self.replace_menu("Community Cost", f"Transit to {dest_name}\n{cost_name}", c_opts)

    def do_travel_step3(self, dest_name, distance):
        self.log(f"--- TRANSIT TO {dest_name} ---")
        for step in range(distance):
            self.game.player.tracks["Supplies"].change(-1)
            self.log("Consumed 1 Supplies during travel.")
            enc = random.randint(1, 6)
            if enc == 1: 
                comp_name, dis_opts = get_complication()
                self.log(f"[TRAVEL ENCOUNTER] Hazard: {comp_name}")
                def pick_haz(o):
                    self.pop_menu()
                    self.apply_track_option(o, False)
                self.push_menu("Hazard Disadvantage", f"Travel to {dest_name}\nHazard: {comp_name}", [(o, lambda o=o: pick_haz(o), 6) for o in dis_opts])
            elif enc == 2: 
                opp_name, adv_opts = get_opportunity(in_space=True)
                self.log(f"[TRAVEL ENCOUNTER] Opportunity: {opp_name}")
                def pick_opp(o):
                    self.pop_menu()
                    self.apply_track_option(o, False)
                self.push_menu("Discovery Advantage", f"Travel to {dest_name}\nDiscovery: {opp_name}", [(o, lambda o=o: pick_opp(o), 7) for o in adv_opts])
            self.game.advance_clock(1)
            
        self.game.current_sector = self.game.sectors[dest_name]
        self.game.phase = "Encounter"
        self.log(f"Arrived at {dest_name}")

    def flow_converse(self):
        if not self.game.current_sector.npcs:
            self.push_menu("Converse", "No NPCs present.", [("Back", self.pop_menu, 4)])
            return
        opts = [(n.name, lambda n=n: self._converse_npc(n), 5) for n in self.game.current_sector.npcs]
        opts.append(("Cancel", self.pop_menu, 4))
        self.push_menu("Converse", "Select an NPC.", opts)

    def _converse_npc(self, npc):
        self.save_undo()
        seed = roll_conversation_seed()
        disp = roll_disposition()
        npc.disposition = disp
        
        def do_text_input():
            self.draw()
            topic = self.get_string(f"Topic Node (e.g. 'a shortage' or press enter for '{seed}'): ")
            if not topic.strip(): topic = seed
            self.draw()
            outcome = self.get_string("Outcome Node (e.g. 'tension increased', 'agreement'): ")
            self.draw()
            free_text = self.get_string("Optional Free Text (dialogue/notes): ")
            
            log_entry = f"Spoke with {npc.name} about {topic} resulting in {outcome}."
            if free_text: log_entry += f" Note: {free_text}"
            self.log(log_entry)
            self.pop_menu()
            self.pop_menu()

        text = f"NPC: {npc.name}\nDisposition: {disp}\nTopic Seed: {seed}"
        opts = [("Continue to conversation input", do_text_input, 5)]
        
        if disp in ["Frustrated", "Worried", "Distant"]:
            def calm():
                self.game.player.tracks["Morale"].change(-1)
                npc.disposition = "Calm"
                self.log(f"Spent 1 Morale. {npc.name} is now Calm.")
                do_text_input()
            opts.insert(0, ("Spend 1 Morale to calm them", calm, 5))
        elif disp in ["Hopeful", "Eager"]:
            def intel():
                self.game.player.tags.append(TempTag("Useful Intel", "Used in action"))
                self.log("Gained tag: Useful Intel")
                do_text_input()
            opts.insert(0, ("Accept Useful Intel tag", intel, 7))

        self.push_menu(f"Converse with {npc.name}", text, opts)

    def flow_hooks(self):
        unresolved = [h for h in self.game.current_sector.hooks if not h.resolved]
        if not unresolved:
            self.push_menu("Hooks", "No unresolved hooks here.", [("Back", self.pop_menu, 4)])
            return
        opts = [(f"{h.name} ({h.provider})", lambda h=h: self.flow_hook_detail(h), 7) for h in unresolved]
        opts.append(("Back", self.pop_menu, 4))
        self.push_menu("Available Hooks", "Select a hook.", opts)

    def flow_hook_detail(self, hook):
        def resolve_with_action():
            self.pop_menu(); self.pop_menu()
            self.flow_act(hook=hook, context=f"Hook: {hook.name}")
        def dismiss():
            hook.resolved = True
            self.log(f"Dismissed hook: {hook.name}")
            self.pop_menu(); self.pop_menu()
        text = f"Hook: {hook.name}\nProvider: {hook.provider}\nType: {hook.hook_type}\n\nSuccess: {hook.success_opt}\nFailure: {hook.fail_opt}"
        opts = [("Resolve with Action", resolve_with_action, 6), ("Dismiss", dismiss, 4), ("Cancel", self.pop_menu, 4)]
        self.push_menu("Hook Details", text, opts)

    def flow_goals(self):
        opts = [(f"{g.id}: {g.statement} ({g.progress}/10)", lambda g=g: self.flow_goal_detail(g), 5) for g in self.game.player.goals]
        opts.append(("Add New Goal", self.do_goal_add, 5))
        opts.append(("Back", self.pop_menu, 4))
        self.push_menu("Goals", "Select a goal or add a new one.", opts)
        
    def do_goal_add(self):
        rank = self.get_string("Rank (MINOR/MAJOR/EPIC): ").upper()
        if rank in ["MINOR", "MAJOR", "EPIC"]:
            stmt = self.get_string("Statement: ")
            self.game.player.goals.append(Goal(stmt, rank=rank))
            self.log(f"Added {rank} goal: {stmt}")
        self.pop_menu()

    def flow_goal_detail(self, goal):
        def advance():
            self.save_undo()
            amt = {"MINOR": 2, "MAJOR": 1, "EPIC": 1}.get(goal.rank, 1)
            res = goal.advance(amt)
            self.log(res)
            self.pop_menu(); self.pop_menu()
        def resolve():
            if goal.progress < 10:
                self.push_menu("Error", "Goal must be at 10/10.", [("OK", self.pop_menu, 4)])
                return
            self.save_undo()
            self.pop_menu(); self.pop_menu()
            
            # Remove goal before action, as TUI action engine expects standard track options
            # Alternatively we just let the player roleplay the failure.
            self.game.player.goals.remove(goal)
            self.log(f"Attempting to resolve goal: {goal.statement}")
            self.flow_act_approach("petition", context="Action: Petition")

        opts = [("Advance Progress", advance, 7), ("Resolve Goal", resolve, 6), ("Back", self.pop_menu, 4)]
        self.push_menu(f"Goal: {goal.id}", f"{goal.rank} Goal\n{goal.statement}\nProgress: {goal.progress}/10", opts)

    def flow_messages(self):
        opts = [("Send Message", self.do_msg_send, 5)]
        arr = [m for m in self.game.message_queue if m.status == "ARRIVED"]
        for m in arr:
            opts.append((f"Resolve Msg {m.id}", lambda m=m: self.do_msg_resolve(m), 6))
        opts.append(("Back", self.pop_menu, 4))
        self.push_menu("Messages", "Send or resolve tight-beam messages.", opts)
        
    def do_msg_send(self):
        to = self.get_string("Send to (NPC/Bond name): ")
        sub = self.get_string("Subject: ")
        arr_tick = self.game.clock + 2
        msg = Message(f"M{self.game.msg_counter}", to, self.game.clock, arr_tick, sub)
        self.game.message_queue.append(msg)
        self.game.msg_counter += 1
        self.log(f"Sent tight-beam to {to}. Subject: {sub}")
        self.pop_menu()

    def do_msg_resolve(self, m):
        self.log(f"Resolving message {m.id} to {m.to_npc}")
        m.status = "RESOLVED"
        self.pop_menu()
        self.flow_act_approach("petition", context="Action: Petition")

    def flow_tags_bonds(self):
        opts = [("Add NPC Goal", self.do_npc_goal, 5)]
        for t in self.game.player.tags:
            opts.append((f"Remove Tag: {t}", lambda t=t: self.do_remove_tag(t), 4))
        opts.append(("Back", self.pop_menu, 4))
        self.push_menu("Tags & Bonds", "Manage Tags and Bonds.", opts)
        
    def do_npc_goal(self):
        b_name = self.get_string("Bond Name: ")
        bond = next((b for b in self.game.player.bonds if b.name.lower() == b_name.lower()), None)
        if bond:
            a = self.get_string("Action (e.g. destroy, protect): ")
            t = self.get_string("Target: ")
            m = self.get_string("Motivation: ")
            bond.add_goal(a, t, m)
            self.log(f"Authored NPC Goal for {bond.name}.")
        else:
            self.log(f"Bond {b_name} not found.")
        self.pop_menu()

    def do_remove_tag(self, tag):
        if self.game.player.remove_tag(str(tag)):
            self.log(f"Removed tag: {tag}")
        self.pop_menu()

def main():
    try:
        curses.wrapper(lambda stdscr: TUI(stdscr).run())
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
