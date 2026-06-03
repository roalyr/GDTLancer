######################################
# Editable section - presets.
######################################


# Specify the cluster and a number of systems in it.
# Those systems will be written in Universe/Universe_random.md
clusters = [
	("Moirai", 200),
]

# If user_defined stars and planets are set - they will be written to
# Universe/Universe_preset.md
systems = [

	{
		"cluster" : "Moirai",
		"name" : "Victory",
		"main_star" : ("B", 7),
		"companion_stars" : [("G", 8),],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Equberan",
		"main_star" : ("A", 7),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Selk'nam", # Make reference-trubute to a tribe.
		"main_star" : ("M", 9), # Try brown dwarf later on.
		"companion_stars" : [],
		# Asteroid belt and debris instead of planets.
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Valeri",
		"main_star" : ("A", 9),
		"companion_stars" : [("M", 9),], # Change Valeri B to white dwarf.
	},
	
	{
		"cluster" : "Global nebula",
		"name" : "Viakata", # A starting point in the game, give info as such.
		"main_star" : ("M", 2),
		"companion_stars" : [],
		"total_planets" : ["SD", "D", "ST", "D", ],
		"closest_orbit" : 0,
		"furthest_orbit" : 3e10,
		"orbit_ratio" : 2.0 # 1.33 | 1.5 | 2.0
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Glory",
		"main_star" : ("G", 9),
		"companion_stars" : [],
		"total_planets" : [],
	},
	
	{
		"cluster" : "", # Most likely outside of Moirai.
		"name" : "Hilicele", # In lore this will be the system where X are first found.
		"main_star" : ("F", 7),
		"companion_stars" : [],
	},
	
]
