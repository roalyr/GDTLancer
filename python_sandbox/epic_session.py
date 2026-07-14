import pexpect
import sys

def run():
    print("Starting Expanded Epic Playtest Session")
    child = pexpect.spawn('python3 main.py', encoding='utf-8', timeout=5)
    child.logfile = sys.stdout

    actions = [
        # --- Sector 1: Elace Station ---
        "log The sectors are drifting apart, faction conflicts are heating up. We need to construct a massive autonomous shipyard at Orin's Reach to unite them.",
        "goal_add EPIC Construct an autonomous shipyard at Orin's Reach", # G2
        "converse Kaelen",
        "act acquire cautious",
        "goal_add MINOR Secure raw materials from The Scatter", # G3
        "converse Overseer Relt",
        "act petition cautious",
        
        # --- Travel to Korr Anchorage ---
        "travel Korr Anchorage", 
        "converse Voss",
        "act investigate cautious",
        "goal_add MINOR Retrieve old blueprints from Voss's vault", # G4
        "converse Dockmaster Tyra",
        "act barter cautious",
        "goal_advance G4 2", "goal_advance G4 2", "goal_advance G4 2", "goal_advance G4 2", "goal_advance G4 2",
        "goal_resolve G4 cautious", # Fulfilled!
        
        # --- Travel to Veyra Hub ---
        "travel Veyra Hub",
        "converse Sera",
        "act convince cautious",
        "goal_add MINOR Establish a black market contact", # G5
        "converse Sera",
        "act command risky",
        "goal_advance G5 2", "goal_advance G5 2", "goal_advance G5 2", "goal_advance G5 2", "goal_advance G5 2",
        "goal_resolve G5 cautious", # Fulfilled!
        
        # --- Travel to The Scatter ---
        "travel The Scatter",
        "converse Kaelen",
        "act scavenge risky",
        "goal_advance G3 2", "goal_advance G3 2", "goal_advance G3 2",
        "act repair cautious",
        "act scavenge risky",
        "goal_advance G3 2", "goal_advance G3 2",
        "goal_resolve G3 cautious", # Fulfilled!
        
        # --- Travel to Orin's Reach ---
        "travel Orin's Reach",
        "log We arrived at Orin's Reach. The sector is guarded by rogue automated drones.",
        "goal_add MAJOR Clear the sector defenses at Orin's Reach", # G6
        "converse Kaelen",
        "act scan cautious",
        "act overcome risky",
        "goal_advance G6 1", "goal_advance G6 1", "goal_advance G6 1", "goal_advance G6 1", "goal_advance G6 1",
        "act overcome cautious",
        "goal_advance G6 1", "goal_advance G6 1", "goal_advance G6 1", "goal_advance G6 1", "goal_advance G6 1",
        "goal_resolve G6 cautious", # Fulfilled!
        
        # --- Shipyard Construction at Orin's Reach ---
        "log Sector cleared of defenses. Beginning shipyard assembly.",
        "act repair cautious",
        "goal_advance G2 1", "goal_advance G2 1", "goal_advance G2 1",
        "act navigate cautious",
        "goal_advance G2 1", "goal_advance G2 1",
        "act acquire cautious",
        "goal_advance G2 1", "goal_advance G2 1", "goal_advance G2 1",
        "act petition cautious",
        "goal_advance G2 1", "goal_advance G2 1",
        "goal_resolve G2 cautious", # Fulfilled!
        
        # --- Travel to Korr Anchorage to celebrate ---
        "travel Korr Anchorage",
        "converse Voss",
        "act barter cautious",
        
        # --- Travel to Elace Station to retrieve goods ---
        "travel Elace Station",
        "converse Overseer Relt",
        "act acquire cautious",
        
        # --- Travel to New Eden to establish HQ ---
        "travel New Eden",
        "log Arrived in New Eden to establish the new family-clan headquarters next to the shipyard corridor.",
        "converse Kaelen",
        "act endure cautious",
        
        # --- Wait and Fast Forward Clock ---
        "wait 10",
        "log The shipyard is thriving, and the sectors are united. The family-clan stands strong.",
        "quit"
    ]
    
    action_idx = 0
    topic_count = 0
    outcome_count = 0
    free_text_count = 0
    
    topics = [
        "the ambitious shipyard plan",
        "docking permits",
        "shipyard blueprints",
        "leasing cargo bays",
        "black market access",
        "securing cargo",
        "scavenging danger",
        "drone perimeter",
        "successful completion",
        "trading routes",
        "establishing headquarters"
    ]
    
    outcomes = [
        "agreement reached",
        "agreement reached",
        "agreement reached",
        "tension increased",
        "agreement reached",
        "agreement reached",
        "agreement reached",
        "agreement reached",
        "agreement reached",
        "agreement reached",
        "agreement reached"
    ]
    
    free_texts = [
        "Kaelen agrees to help pilot through the Scatter.",
        "Relt agrees to grant clearance if we keep local security updated.",
        "Voss shares details about his prototype vault blueprints.",
        "Tyra is hesitant and demands extra trade permits.",
        "Sera connects us with regional suppliers.",
        "Sera provides cargo loaders for our materials.",
        "Kaelen pinpoints high-yield debris locations.",
        "Kaelen scans the drone patrol routes.",
        "Voss celebrates our victory and offers technical aid.",
        "Relt signs docking treaties with the new shipyard.",
        "Kaelen selects a site for the new family-clan."
    ]
    
    while True:
        try:
            idx = child.expect([
                r'={50,}\r?\n> ',                                  # 0: Main prompt
                r'Enter choice for.*?Advantage.*?: ',              # 1
                r'Enter choice for.*?Disadvantage.*?: ',           # 2
                r'Enter choice for Community Cost Option.*?: ',   # 3
                r'Topic Node.*?: ',                                # 4
                r'Outcome Node.*?: ',                              # 5
                r'Optional Free Text.*?: ',                        # 6
                r'Strengthen which bond.*?: ',                     # 7
                r'Weaken which bond.*?: ',                         # 8
                r'Advantage for.*?: ',                             # 9
                r'Disadvantage for.*?: ',                          # 10
                r'Option: .*? \(y/n\)\r?\n> ',                     # 11: Converse optional mechanics
                r'Did your last action advance this goal\? \(y/n\): ' # 12: Goal confirm
            ])
            
            if idx == 0:
                if action_idx < len(actions):
                    cmd = actions[action_idx]
                    child.sendline(cmd)
                    action_idx += 1
                else:
                    child.sendline('quit')
            elif idx in [1, 2, 3, 9, 10]:
                child.sendline('1')
            elif idx == 4:
                topic_count += 1
                val = topics[min(topic_count - 1, len(topics) - 1)]
                child.sendline(val)
            elif idx == 5:
                outcome_count += 1
                val = outcomes[min(outcome_count - 1, len(outcomes) - 1)]
                child.sendline(val)
            elif idx == 6:
                free_text_count += 1
                val = free_texts[min(free_text_count - 1, len(free_texts) - 1)]
                child.sendline(val)
            elif idx in [7, 8]:
                child.sendline('1')
            elif idx == 11:
                child.sendline('n')
            elif idx == 12:
                child.sendline('y')
                
        except pexpect.EOF:
            print("\nSession ended naturally via EOF.")
            break
        except pexpect.TIMEOUT:
            # If we timeout, we might be at a weird prompt, just send a newline
            child.sendline('')

if __name__ == "__main__":
    run()
