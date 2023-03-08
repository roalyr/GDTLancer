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
		"main_star" : ("B", 2),
		"companion_stars" : [("G", 1),],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Equberan",
		"main_star" : ("A", 2),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Selk'nam",
		"main_star" : ("M", 0), # Try brown dwarf later on.
		"companion_stars" : [],
		# Asteroid belt and debris instead of planets.
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Valeri",
		"main_star" : ("A", 0),
		"companion_stars" : [("M", 0),], # Change Valeri B to white dwarf.
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Viakata",
		"main_star" : ("M", 7),
		"companion_stars" : [],
	},
	
	{
		"cluster" : "Moirai",
		"name" : "Glory",
		"main_star" : ("G", 0),
		"companion_stars" : [],
	},
	
]
