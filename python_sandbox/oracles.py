import random

def roll_3d6():
    return random.randint(1, 6) + random.randint(1, 6) + random.randint(1, 6)

def roll_2d6():
    return random.randint(1, 6), random.randint(1, 6)

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

def generate_dynamic_hook(sector, npc):
    hook_types = ["Docking Approach", "Perimeter Investigation", "Direct Interception", "Boarding Action", "Community Petition"]
    htype = random.choice(hook_types)
    r1, r2 = roll_2d6()
    
    # Simple table for hook concepts based on Focus/Theme oracles
    themes = ["Scarcity", "Trust", "Obligation", "Survival", "Isolation", "Kinship"]
    focus = ["Vessel", "Community", "Bond", "Resource", "Route", "Equipment"]
    
    # Context-aware adjustments
    if sector.tracks["Supplies"].value <= 3:
        themes[0] = "Critical Shortage"
        focus[3] = "Rations"
        htype = "Community Petition"
    
    if npc.disposition in ["Frustrated", "Worried"]:
        themes[1] = "Desperation"
    
    t = themes[random.randint(0, 5)]
    f = focus[random.randint(0, 5)]
    
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
    
    return f"Issue concerning {t} and {f}.", htype, paths, succ, fail
