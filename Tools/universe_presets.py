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
		"name" : "Selk'nam",
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
		"cluster" : "Moirai",
		"name" : "Viakata",
		"main_star" : ("M", 2),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Glory",
		"main_star" : ("G", 9),
		"companion_stars" : [],
	},
	
]
