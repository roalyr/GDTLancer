import random

def roll_3d6():
    return random.randint(1, 6) + random.randint(1, 6) + random.randint(1, 6)

def roll_2d6():
    return random.randint(1, 6), random.randint(1, 6)

# ── Tool Library ────────────────────────────────────────────────────────────
# Each entry: (name, description, track_affinity)
TOOLS_LIBRARY = [
    ("Medkit",           "Field trauma kit. Splints, sealant, stimulants.",                "Health"),
    ("Survey array",     "Short-range scanner. Maps terrain, reads atmosphere and mass.",  "Supplies"),
    ("Cutting torch",    "Plasma cutter. Opens hatches, severs cable, breaks locks.",      "Supplies"),
    ("Signal beacon",    "Tight-beam emitter. Reaches vessels at medium range.",           "Morale"),
    ("Patch kit",        "Hull sealant, pressure tape, and a wrench set.",                 "Health"),
    ("Climbing rig",     "Magnetic clamps and tether line. Works in zero-g.",              "Health"),
    ("Encrypted comms",  "Hardened comm unit. Scrambles transmissions. Hard to intercept.","Morale"),
    ("Portable scanner", "Bio and chemical sniffer. Finds life signs and toxic zones.",    "Supplies"),
    ("Jury-rig kit",     "Salvaged parts and schematics. Fixes what others call dead.",    "Supplies"),
    ("Barter ledger",    "Encrypted trade records, debt tallies, and market contacts.",    "Wealth"),
    ("Forager's pack",   "Water reclaimer, nutrition tablets, and a folding trap set.",    "Supplies"),
    ("Anchor spike",     "Drives into hull or rock. Secures tether lines and rope nets.",  "Health"),
]

# ── Starting Goals ───────────────────────────────────────────────────────────
# Each entry: (statement, anchor, rank, description)
STARTING_GOALS = [
    ("Establish a reliable supply route between two stations",
     None, "MAJOR",
     "The system's food and medicine depend on regularity. Someone has to run the route."),
    ("Track down what happened to a lost vessel",
     None, "MAJOR",
     "A ship disappeared. The community deserves an answer. You knew someone aboard."),
    ("Secure a medical station for an underserved anchorage",
     None, "MAJOR",
     "The nearest clinic is three sectors away. People are dying from things that shouldn't kill."),
    ("Recover a debt owed to your community",
     None, "MINOR",
     "Someone took resources and didn't come back. The ledger needs to be settled."),
    ("Build trust between two communities that barely speak",
     None, "MAJOR",
     "Old tensions. Maybe a misunderstanding, maybe not. Either way it costs everyone."),
    ("Find out who has been intercepting community transmissions",
     None, "MAJOR",
     "Someone is listening. Messages have been altered. You don't know by whom or why yet."),
    ("Get your vessel repaired before the next long-haul run",
     None, "MINOR",
     "The hull is patched. The drive is unreliable. It will fail at the worst moment if you don't act."),
    ("Protect someone who can't protect themselves",
     None, "MAJOR",
     "They know something, or they are owed something. Either way, they are vulnerable."),
]

ACTIONS_MAPPING = {
    "command": ["Health", "Supplies"],
    "navigate": ["Health", "Supplies"],
    "endure": ["Health"],
    "overcome": ["Health"],
    "scavenge": ["Supplies"],
    "repair": ["Supplies"],
    "barter": ["Wealth"],
    "acquire": ["Wealth"],
    "petition": ["Morale"],
    "convince": ["Morale"],
    "investigate": ["Morale", "Supplies"],
    "scan": ["Morale", "Supplies"],
}

COMPLICATION_TABLE = {
    1: {1: ("Equipment failure", ["[Supplies -1]", "[Gain tag: Damaged Hull]", "[Health -2] and [Gain tag: Quick Fix]"]), 2: ("Betrayal", ["[Morale -1]", "[Weaken one bond by 1 step]", "[Wealth -2] and [Gain tag: Useful Intel]"]), 3: ("Micro-debris storm", ["[Health -1]", "[Supplies -1]", "[Gain tag: Hull Breach]"]), 4: ("Desperate scavengers", ["[Supplies -1]", "[Wealth -1]", "[Gain tag: Pursued]"]), 5: ("Debt called in", ["[Wealth -1]", "[Weaken one bond by 1 step]", "[Morale -1]"]), 6: ("Misunderstanding", ["[Morale -1]", "[Weaken one bond by 1 step]", "[Gain tag: Distrusted]"])},
    2: {1: ("Illness/Injury", ["[Health -1]", "[Morale -1]", "[Gain tag: Sick Crew]"]), 2: ("Resource loss", ["[Supplies -1]", "[Wealth -1]", "[Gain tag: Rationing]"]), 3: ("Rival interference", ["[Morale -1]", "[Wealth -1]", "[Gain tag: Watched]"]), 4: ("Navigation error", ["[Supplies -1]", "[Gain tag: Lost Position]", "[Morale -1]"]), 5: ("Hull parasites", ["[Health -1]", "[Supplies -1]", "[Gain tag: Infested]"]), 6: ("Clan dispute", ["[Morale -1]", "[Weaken one bond by 1 step]", "[Gain tag: Divided Crew]"])},
    3: {1: ("Power outage", ["[Supplies -1]", "[Gain tag: Dark Ship]", "[Morale -1]"]), 2: ("False information", ["[Morale -1]", "[Gain tag: Misled]", "[Supplies -1]"]), 3: ("Unexpected cost", ["[Wealth -1]", "[Supplies -1]", "[Gain tag: Indebted]"]), 4: ("Missing person", ["[Morale -1]", "[Weaken one bond by 1 step]", "[Gain tag: Shorthanded]"]), 5: ("Broken promise", ["[Morale -1]", "[Weaken one bond by 1 step]", "[Wealth -1]"]), 6: ("Inside sabotage", ["[Supplies -1]", "[Morale -1]", "[Gain tag: Compromised]"])},
    4: {1: ("Supply shortage", ["[Supplies -1]", "[Gain tag: Rationing]", "[Morale -1]"]), 2: ("Time limit", ["[Morale -1]", "[Gain tag: Deadline]", "[Supplies -1]"]), 3: ("Dangerous leak", ["[Health -1]", "[Supplies -1]", "[Gain tag: Hull Breach]"]), 4: ("Detained crew", ["[Morale -1]", "[Gain tag: Shorthanded]", "[Weaken one bond by 1 step]"]), 5: ("Conflicting clan ties", ["[Morale -1]", "[Weaken one bond by 1 step]", "[Gain tag: Divided Crew]"]), 6: ("Trap", ["[Health -1]", "[Supplies -1]", "[Gain tag: Cornered]"])},
    5: {1: ("Docking dispute", ["[Wealth -1]", "[Morale -1]", "[Gain tag: Denied Berth]"]), 2: ("Cargo contested", ["[Wealth -1]", "[Supplies -1]", "[Gain tag: Disputed Claim]"]), 3: ("Mutiny", ["[Morale -1]", "[Weaken one bond by 1 step]", "[Gain tag: Divided Crew]"]), 4: ("Theft", ["[Wealth -1]", "[Supplies -1]", "[Morale -1]"]), 5: ("Radiation spike", ["[Health -1]", "[Gain tag: Contaminated Zone]", "[Supplies -1]"]), 6: ("Communication failure", ["[Morale -1]", "[Gain tag: Cut Off]", "[Supplies -1]"])},
    6: {1: ("Structural collapse", ["[Health -1]", "[Supplies -1]", "[Gain tag: Blocked Path]"]), 2: ("Unpaid fee", ["[Wealth -1]", "[Weaken one bond by 1 step]", "[Gain tag: Indebted]"]), 3: ("Reputation hit", ["[Morale -1]", "[Weaken one bond by 1 step]", "[Gain tag: Distrusted]"]), 4: ("Family feud", ["[Morale -1]", "[Weaken one bond by 1 step]", "[Gain tag: Divided Crew]"]), 5: ("Lost cargo", ["[Wealth -1]", "[Supplies -1]", "[Morale -1]"]), 6: ("Urgent distress call", ["[Supplies -1]", "[Gain tag: Delayed]", "[Morale -1]"])}
}

OPPORTUNITY_SPACE_TABLE = {
    1: {1: ("Abandoned cargo", ["[Supplies +1]", "[Wealth +1]", "[Gain tag: Extra Cargo]"]), 2: ("Drifting derelict", ["[Gain tag: Salvage Opportunity]", "[Supplies +1]", "[Wealth +1]"]), 3: ("Uncharted shortcut", ["[Supplies +1]", "[Gain tag: Fast Route]", "[Morale +1]"]), 4: ("Favorable drift", ["[Supplies +1]", "[Gain tag: Smooth Passage]", "[Morale +1]"]), 5: ("Unclaimed salvage", ["[Wealth +1]", "[Supplies +1]", "[Gain tag: Spare Parts]"]), 6: ("Pristine machinery", ["[Supplies +1]", "[Gain tag: Quality Equipment]", "[Wealth +1]"])},
    2: {1: ("Rare resource deposit", ["[Wealth +1]", "[Supplies +1]", "[Gain tag: Valuable Find]"]), 2: ("Legitimate distress beacon", ["[Morale +1]", "[Strengthen one bond by 1 step]", "[Gain tag: Grateful Survivor]"]), 3: ("Smuggler's cache", ["[Wealth +1]", "[Supplies +1]", "[Gain tag: Hidden Goods]"]), 4: ("Blind spot in patrols", ["[Gain tag: Undetected]", "[Morale +1]", "[Supplies +1]"]), 5: ("Weakened security", ["[Gain tag: Undetected]", "[Morale +1]", "[Gain tag: Open Path]"]), 6: ("Mutual enemy engaged", ["[Gain tag: Undetected]", "[Morale +1]", "[Gain tag: Window of Opportunity]"])},
    3: {1: ("Safe haven / cove", ["[Health +1]", "[Morale +1]", "[Gain tag: Sheltered]"]), 2: ("Valuable data", ["[Wealth +1]", "[Gain tag: Useful Intel]", "[Morale +1]"]), 3: ("Specialized tool found", ["[Supplies +1]", "[Gain tag: Specialized Tool]", "[Wealth +1]"]), 4: ("Escaped prisoner's pod", ["[Morale +1]", "[Strengthen one bond by 1 step]", "[Gain tag: New Contact]"]), 5: ("Pristine parts", ["[Supplies +1]", "[Gain tag: Quality Parts]", "[Health +1]"]), 6: ("Free tow/transport", ["[Supplies +1]", "[Morale +1]", "[Gain tag: Assisted Travel]"])},
    4: {1: ("Hidden cache", ["[Wealth +1]", "[Supplies +1]", "[Gain tag: Secret Stash]"]), 2: ("Unguarded route", ["[Gain tag: Undetected]", "[Supplies +1]", "[Morale +1]"]), 3: ("Temporary truce", ["[Morale +1]", "[Strengthen one bond by 1 step]", "[Gain tag: Ceasefire]"]), 4: ("Missing kin found", ["[Morale +1]", "[Strengthen one bond by 1 step]", "[Health +1]"]), 5: ("Abandoned facility", ["[Supplies +1]", "[Gain tag: Salvage Opportunity]", "[Wealth +1]"]), 6: ("Secret passage", ["[Gain tag: Hidden Route]", "[Supplies +1]", "[Morale +1]"])},
    5: {1: ("Vulnerable rival", ["[Gain tag: Leverage]", "[Morale +1]", "[Wealth +1]"]), 2: ("Medical supplies in wreck", ["[Health +1]", "[Supplies +1]", "[Gain tag: Medical Stock]"]), 3: ("Stolen goods", ["[Wealth +1]", "[Supplies +1]", "[Gain tag: Contraband]"]), 4: ("Critical weakness exposed", ["[Gain tag: Leverage]", "[Morale +1]", "[Gain tag: Useful Intel]"]), 5: ("New outpost", ["[Morale +1]", "[Gain tag: Safe Harbor]", "[Strengthen one bond by 1 step]"]), 6: ("Quiet transit", ["[Supplies +1]", "[Morale +1]", "[Health +1]"])},
    6: {1: ("Nav-buoy intact", ["[Supplies +1]", "[Gain tag: Clear Navigation]", "[Morale +1]"]), 2: ("Scrap-rich field", ["[Supplies +1]", "[Wealth +1]", "[Gain tag: Spare Parts]"]), 3: ("Overlooked container", ["[Supplies +1]", "[Wealth +1]", "[Gain tag: Extra Cargo]"]), 4: ("Intact life support", ["[Health +1]", "[Supplies +1]", "[Morale +1]"]), 5: ("Fuel reserves", ["[Supplies +1]", "[Gain tag: Fuel Reserve]", "[Morale +1]"]), 6: ("Unspoken allowance", ["[Gain tag: Unofficial Permission]", "[Morale +1]", "[Strengthen one bond by 1 step]"])}
}

OPPORTUNITY_STATION_TABLE = {
    1: {1: ("Willing hand", ["[Morale +1]", "[Gain tag: Helper]", "[Supplies +1]"]), 2: ("Forgiveness of debt", ["[Wealth +1]", "[Morale +1]", "[Strengthen one bond by 1 step]"]), 3: ("Generous elder", ["[Supplies +1]", "[Strengthen one bond by 1 step]", "[Morale +1]"]), 4: ("Inside information", ["[Gain tag: Useful Intel]", "[Morale +1]", "[Wealth +1]"]), 5: ("Smuggler contact", ["[Gain tag: Black Market Access]", "[Wealth +1]", "[Supplies +1]"]), 6: ("Critical community need", ["[Morale +1]", "[Strengthen one bond by 1 step]", "[Gain tag: Respected]"])},
    2: {1: ("Reputation boost", ["[Morale +1]", "[Strengthen one bond by 1 step]", "[Gain tag: Respected]"]), 2: ("Clan favor", ["[Strengthen one bond by 1 step]", "[Morale +1]", "[Wealth +1]"]), 3: ("Unlocked door", ["[Gain tag: Access Granted]", "[Supplies +1]", "[Gain tag: Undetected]"]), 4: ("Distracted watchkeep", ["[Gain tag: Undetected]", "[Morale +1]", "[Supplies +1]"]), 5: ("Maintenance tunnel", ["[Gain tag: Hidden Route]", "[Supplies +1]", "[Gain tag: Undetected]"]), 6: ("Forgotten rule", ["[Gain tag: Unofficial Permission]", "[Morale +1]", "[Wealth +1]"])},
    3: {1: ("Black market access", ["[Gain tag: Black Market Access]", "[Wealth +1]", "[Supplies +1]"]), 2: ("Temporary truce", ["[Morale +1]", "[Strengthen one bond by 1 step]", "[Gain tag: Ceasefire]"]), 3: ("Valuable data", ["[Wealth +1]", "[Gain tag: Useful Intel]", "[Morale +1]"]), 4: ("Medical supplies", ["[Health +1]", "[Supplies +1]", "[Morale +1]"]), 5: ("Free transport", ["[Supplies +1]", "[Morale +1]", "[Gain tag: Assisted Travel]"]), 6: ("Unspoken allowance", ["[Gain tag: Unofficial Permission]", "[Morale +1]", "[Strengthen one bond by 1 step]"])},
    4: {1: ("Vulnerable rival", ["[Gain tag: Leverage]", "[Morale +1]", "[Wealth +1]"]), 2: ("Weakened security", ["[Gain tag: Undetected]", "[Morale +1]", "[Gain tag: Open Path]"]), 3: ("Missing kin found", ["[Morale +1]", "[Strengthen one bond by 1 step]", "[Health +1]"]), 4: ("Pristine parts in barter", ["[Supplies +1]", "[Gain tag: Quality Parts]", "[Wealth +1]"]), 5: ("Specialized tool", ["[Supplies +1]", "[Gain tag: Specialized Tool]", "[Wealth +1]"]), 6: ("Safe haven", ["[Health +1]", "[Morale +1]", "[Gain tag: Sheltered]"])},
    5: {1: ("Generous benefactor", ["[Wealth +1]", "[Supplies +1]", "[Strengthen one bond by 1 step]"]), 2: ("Abandoned cargo in hold", ["[Supplies +1]", "[Wealth +1]", "[Gain tag: Extra Cargo]"]), 3: ("Rare resource traded", ["[Wealth +1]", "[Supplies +1]", "[Gain tag: Valuable Find]"]), 4: ("Mutual enemy", ["[Gain tag: Common Cause]", "[Strengthen one bond by 1 step]", "[Morale +1]"]), 5: ("Hidden cache", ["[Wealth +1]", "[Supplies +1]", "[Gain tag: Secret Stash]"]), 6: ("Forgiven mistake", ["[Morale +1]", "[Strengthen one bond by 1 step]", "[Gain tag: Second Chance]"])},
    6: {1: ("Lucrative barter", ["[Wealth +1]", "[Supplies +1]", "[Morale +1]"]), 2: ("Unclaimed berth", ["[Gain tag: Docking Rights]", "[Morale +1]", "[Supplies +1]"]), 3: ("Restored trust", ["[Strengthen one bond by 1 step]", "[Morale +1]", "[Gain tag: Respected]"]), 4: ("Unexpected ally", ["[Strengthen one bond by 1 step]", "[Morale +1]", "[Gain tag: New Contact]"]), 5: ("Expedited repair", ["[Supplies +1]", "[Health +1]", "[Gain tag: Quick Fix]"]), 6: ("Forgotten stash", ["[Supplies +1]", "[Wealth +1]", "[Gain tag: Hidden Goods]"])}
}

COMMUNITY_COST_TABLE = {
    1: ("Watchkeep short-handed", ["[Morale -1]", "[Gain tag: Unprotected Settlement]", "[Weaken one bond by 1 step]"]),
    2: ("Scavenge run delayed", ["[Supplies -1]", "[Gain tag: Shortage Brewing]", "[Morale -1]"]),
    3: ("Medical duty missed", ["[Health -1]", "[Morale -1]", "[Gain tag: Untreated Sick]"]),
    4: ("Harvest left to rot", ["[Supplies -1]", "[Wealth -1]", "[Gain tag: Wasted Yield]"]),
    5: ("Machinery repair halted", ["[Supplies -1]", "[Gain tag: Broken Equipment]", "[Morale -1]"]),
    6: ("Vulnerable flank exposed", ["[Morale -1]", "[Gain tag: Unprotected Settlement]", "[Health -1]"])
}

PRE_FLIGHT_CREW_TABLE = {
    1: ("Minor leak patched", ["[Supplies -1]", "[Gain tag: Patched Hull]", "[Health -1]"], "Disadvantage"),
    2: ("Chart data corrupted", ["[Gain tag: Unreliable Charts]", "[Morale -1]", "[Supplies -1]"], "Disadvantage"),
    3: ("System requires recalibration", ["[Supplies -1]", "[Gain tag: Unreliable Systems]", "[Morale -1]"], "Disadvantage"),
    4: ("Route looks clear", ["[Gain tag: Clear Path]", "[Morale +1]", "[Supplies +1]"], "Advantage"),
    5: ("Essential spare found", ["[Supplies +1]", "[Gain tag: Spare Parts]", "[Health +1]"], "Advantage"),
    6: ("Crew morale high", ["[Morale +1]", "[Strengthen one bond by 1 step]", "[Health +1]"], "Advantage")
}

def get_action_tracks(action_name):
    return ACTIONS_MAPPING.get(action_name.lower(), [])

def get_complication():
    r1, r2 = roll_2d6()
    return COMPLICATION_TABLE[r1][r2]

def get_opportunity(in_space=True):
    r1, r2 = roll_2d6()
    if in_space:
        return OPPORTUNITY_SPACE_TABLE[r1][r2]
    else:
        return OPPORTUNITY_STATION_TABLE[r1][r2]

def get_community_cost():
    return COMMUNITY_COST_TABLE[random.randint(1, 6)]

def get_pre_flight_crew():
    return PRE_FLIGHT_CREW_TABLE[random.randint(1, 6)]

def roll_disposition():
    dispositions = ["Worried", "Hopeful", "Frustrated", "Calm", "Eager", "Distant"]
    return dispositions[random.randint(0, 5)]

def roll_conversation_seed():
    seeds = [
        ["A plan", "A worry", "A favor", "A memory", "A rumor", "A warning"],
        ["A debt", "A promise", "A question", "A regret", "A hope", "A grudge"],
        ["A change", "A loss", "A secret", "A proposal", "A complaint", "An offer"],
        ["A child", "A route", "A shortage", "A stranger", "A departure", "A return"],
        ["A vessel", "A skill", "A mistake", "A tradition", "A conflict", "A celebration"],
        ["The future", "The past", "A place", "A name", "A price", "A silence"]
    ]
    r1, r2 = roll_2d6()
    return seeds[r1-1][r2-1]

def get_theme_focus():
    themes = ["Scarcity", "Trust", "Obligation", "Survival", "Isolation", "Kinship"]
    focus = ["Vessel", "Community", "Bond", "Resource", "Route", "Equipment"]
    return themes[random.randint(0, 5)], focus[random.randint(0, 5)]

def generate_dynamic_hook(sector, npc, used_sentences=None):
    if used_sentences is None:
        used_sentences = set()
    hook_types = ["Docking Approach", "Perimeter Investigation", "Direct Interception", "Community Petition", "Overheard Exchange"]
    
    # Context-aware hook type
    if sector.tracks["Supplies"].value <= 3:
        htype = "Community Petition"
    elif sector.tracks["Security"].value <= 3:
        htype = random.choice(["Perimeter Investigation", "Docking Approach"])
    elif sector.tracks["Morale"].value <= 3:
        htype = random.choice(["Community Petition", "Overheard Exchange"])
    else:
        htype = random.choice(hook_types)

    # Build a vivid sentence from NPC + disposition + theme + focus
    low_supply = sector.tracks["Supplies"].value <= 4
    low_security = sector.tracks["Security"].value <= 4
    low_morale = sector.tracks["Morale"].value <= 4
    npc_tense = npc.disposition in ["Frustrated", "Worried", "Distant"]

    # Pre-authored sentence fragments keyed to context
    PETITION_SENTENCES = [
        f"{npc.name} pulls you aside — someone has been skimming the ration logs.",
        f"{npc.name} needs a word. A run is overdue and no one else has clearance.",
        f"{npc.name} is quietly asking for a favor no one else knows about.",
        f"A note left at your bunk: {npc.name} wants to meet before the next watch.",
        f"{npc.name} corners you near the airlock. There's a name they won't say aloud.",
    ]
    DOCKING_SENTENCES = [
        f"A vessel on approach isn't responding to hails. {npc.name} looks worried.",
        f"{npc.name} flags you: an unregistered ship is cycling the outer lock.",
        f"The docking arm is jammed. {npc.name} says it happened 'on purpose'.",
        f"Someone docked without logging their manifest. {npc.name} wants it handled quietly.",
        f"{npc.name} points to a vessel sitting dark on the far berth — been there three days.",
    ]
    PERIMETER_SENTENCES = [
        f"The perimeter sensors flagged movement in an area that should be empty. {npc.name} wants eyes on it.",
        f"{npc.name} found a repeater buoy stripped for parts — not by us.",
        f"A section of the outer hull shows tool marks from outside. {npc.name} is waiting on your call.",
        f"{npc.name} picked up a repeating signal with no origin tag. Someone is out there.",
        f"The watch rotation has a gap. {npc.name} thinks someone arranged it that way.",
    ]
    EXCHANGE_SENTENCES = [
        f"You overhear two of {npc.name}'s people arguing about a debt that isn't in any ledger.",
        f"In the common area, {npc.name} goes quiet the moment you walk in.",
        f"A conversation stops when you round the corner. {npc.name} is in the middle of it.",
        f"Someone says {npc.name}'s name in a tone you don't like. The room moves on too fast.",
        f"You catch the tail of it: {npc.name}, a number, and the word 'before we leave'.",
    ]
    PRESSURE_SENTENCES = [  # used when supplies/security/morale are critical
        f"The rationing board has been altered. {npc.name} is the only one with access.",
        f"People are skipping meals. {npc.name} says there's enough — but the numbers don't match.",
        f"A crew member collapsed in the corridor. {npc.name} wants to keep it quiet.",
        f"The common room is tense. {npc.name} hasn't spoken to anyone in two days.",
        f"There's been a fight in the cargo bay. {npc.name} knows what started it.",
    ]

    if htype == "Community Petition" and (low_supply or low_morale):
        pool = PRESSURE_SENTENCES
    elif htype == "Community Petition":
        pool = PETITION_SENTENCES
    elif htype == "Docking Approach":
        pool = DOCKING_SENTENCES
    elif htype == "Perimeter Investigation":
        pool = PERIMETER_SENTENCES
    elif htype == "Overheard Exchange":
        pool = EXCHANGE_SENTENCES
    else:
        pool = PETITION_SENTENCES

    # Avoid repeating a sentence already used in this session
    available = [s for s in pool if s not in used_sentences]
    if not available:
        available = pool
    sentence = random.choice(available)
    used_sentences.add(sentence)

    consequences_success = [
        "[Supplies +1]",
        "[Morale +1]",
        "[Gain tag: Useful Intel]",
        "[Strengthen one bond by 1 step]",
        "[Wealth +1]"
    ]
    consequences_fail = [
        "[Supplies -1]",
        "[Health -1]",
        "[Weaken one bond by 1 step]",
        "[Morale -1]",
        "[Wealth -1]"
    ]
    succ = random.choice(consequences_success)
    fail = random.choice(consequences_fail)
    
    paths = [
        ("Negotiate or Persuade", ["petition", "convince"]),
        ("Take action manually", ["scavenge", "repair", "command"])
    ]
    
    return sentence, htype, paths, succ, fail


def scene_context(sector, player, npcs_here):
    """Generate a short atmospheric impression based on sector tracks and NPCs present."""
    s = sector.tracks["Supplies"].value
    m = sector.tracks["Morale"].value
    sec = sector.tracks["Security"].value
    w = sector.tracks["Wealth"].value
    stype = sector.type

    # Atmosphere line
    TYPE_FLAVORS = {
        "Planet": ["The station clings to the orbital platform like a barnacle.", "Gravity is light here — boots click on mag-strips.", "The ring habitat hums with recycled air."],
        "Moon": ["The moon's shadow cuts across the dock every few hours.", "Everything here smells faintly of regolith and machine oil.", "The anchorage is small — everyone knows everyone's name."],
        "Star": ["The hub runs hot. Thermal shielding makes the walls tick at odd hours.", "Reflective panels cast hard lines across the common areas.", "Traffic is constant here. You feel watched."],
        "Field": ["The scatter drifts around you — slow tumbling rock and dead signal.", "Nothing is fixed here. The station moves with the debris.", "Light arrives late and leaves early. The field is old."],
        "Deep Space": ["The silence out here has weight to it.", "No horizon. No reference point. Just the vessel and the dark.", "The only light is your own."],
    }
    atm = random.choice(TYPE_FLAVORS.get(stype, ["The station hums quietly."]))

    # Pressure line based on worst track
    worst = min(s, m, sec, w)
    if worst <= 2:
        pressure = "Something is close to breaking — you can feel it in the way people move."
    elif worst <= 4:
        pressure = "There's tension in the small things: the rationing, the silences, the avoidance."
    elif worst >= 8:
        pressure = "The place feels stable — almost prosperous, by the standards of this region."
    else:
        pressure = "Things are holding together, for now."

    return f"  {atm}\n  {pressure}"

