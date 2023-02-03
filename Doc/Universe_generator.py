############### CONSTANTS ###############
# General
seed = "GDTLancer"
# Value variations
v_min = 0.8
v_max = 1.2

# Sun data for reference
sun_diameter = 1.39e9
sun_omni_sidstance = 1e13
sun_density = 1408

# GODOT engine parameters.
# Star constants
star_flare_distance_factor = 100
star_zone_size_factor = 10
star_detail_decay_distance_factor = 20
# Omni light formula: pow((a*log(size) + b), 10)
# Omni energy = 2, omni attenuation = 5.
star_omni_a = 2.076
star_omni_b = -5.937

# System constants
system_zone_size_factor = 10000

# Generic
autopilot_distance_factor = 3

# Star type parameters
# https://en.m.wikipedia.org/wiki/Stellar_classification
#Class | Temp | Vega-chr. Chromaticity | Mass | Radius | Luminosity bolometric | Hydrogen | Fraction
#O 	≥ 30,000 K 	blue 	blue 	≥ 16 M☉ 	≥ 6.6 R☉ 	≥ 30,000 L☉ 	Weak 	~0.00003%
#B 	10,000–30,000 K 	blue white 	deep blue white 	2.1–16 M☉ 	1.8–6.6 R☉ 	25–30,000 L☉ 	Medium 	0.13%
#A 	7,500–10,000 K 	white 	blue white 	1.4–2.1 M☉ 	1.4–1.8 R☉ 	5–25 L☉ 	Strong 	0.6%
#F 	6,000–7,500 K 	yellow white 	white 	1.04–1.4 M☉ 	1.15–1.4 R☉ 	1.5–5 L☉ 	Medium 	3%
#G 	5,200–6,000 K 	yellow 	yellowish white 	0.8–1.04 M☉ 	0.96–1.15 R☉ 	0.6–1.5 L☉ 	Weak 	7.6%
#K 	3,700–5,200 K 	light orange 	pale yellow orange 	0.45–0.8 M☉ 	0.7–0.96 R☉ 	0.08–0.6 L☉ 	Very weak 	12.1%
#M 	2,400–3,700 K 	orange red 	light orange red 	0.08–0.45 M☉ 	≤ 0.7 R☉ 	≤ 0.08 L☉ 	Very weak 	76.45%

star_o_size_min = 6.6
star_o_size_max = 10
star_o_lum_min = 30000
star_o_lum_max = 100000
star_o_temp_min = 30000
star_o_temp_max = 100000
star_o_mass_min = 16
star_o_mass_max = 90

star_b_size_min = 1.8
star_b_size_max = 6.6
star_b_lum_min = 25.0
star_b_lum_max = 30000.0
star_b_temp_min = 10000
star_b_temp_max = 30000
star_b_mass_min = 2.1
star_b_mass_max = 16

star_a_size_min = 1.4
star_a_size_max = 1.8
star_a_lum_min = 5.0
star_a_lum_max = 25.0
star_a_temp_min = 7500
star_a_temp_max = 10000
star_a_mass_min = 1.4
star_a_mass_max = 2.1

star_f_size_min = 1.15
star_f_size_max = 1.4
star_f_lum_min = 1.5
star_f_lum_max = 5.0
star_f_temp_min = 6000
star_f_temp_max = 7500
star_f_mass_min = 1.04
star_f_mass_max = 1.4

star_g_size_min = 0.96
star_g_size_max = 1.15
star_g_lum_min = 0.6
star_g_lum_max = 1.5
star_g_temp_min = 5200
star_g_temp_max = 6000
star_g_mass_min = 0.8
star_g_mass_max = 1.04

star_k_size_min = 0.7
star_k_size_max = 0.96
star_k_lum_min = 0.06
star_k_lum_max = 0.6
star_k_temp_min = 3700
star_k_temp_max = 5200
star_k_mass_min = 0.45
star_k_mass_max = 0.8

star_m_size_min = 0.1
star_m_size_max = 0.7
star_m_lum_min = 0.001
star_m_lum_max = 0.06
star_m_temp_min = 2400
star_m_temp_max = 3700
star_m_mass_min = 0.08
star_m_mass_max = 0.45

# Planetary parameters
#HOT, WARM, COLD, ICY
#Miniterrans
#Subterrans
#Terrans
#Superterrans
#Neptunians
#Jovians

# Moon parameters
# Rocky
# Icy
# Atmosphere

############### SYSTEMS ###############
# Specify the cluster and a number of systems in it.
clusters = [
	("Moirai", 270),
]

# If user_defined stars and planets are set - they will take up the
# quota of the total number of stars or planets, otherwise, all
# bodies will be generated within said numbers.
systems = [

	# An example of user-specified planetary system.
	{
		"cluster" : "Moirai",
		"name" : "Victory",
		"total_stars" : 3,
		"total_planets" : 10,
		"usee_defined_main_star" : "O",
		"user_defined_companion_stars" : ["K"],
		"user_defined_planets_and_moons" : [
			["hot_neptunian", "moon_rocky", "moon_rocky"],
			["warm_terran"],
			["cold_jovian", "moon_rocky", "moon_icy", "moon_atmo"],
		],
	},
	
	# Partially specified system.
	{
		"cluster" : "Moirai",
		"name" : "Valeri",
		"total_stars" : 3,
		"total_planets" : 10,
	},
	
	# Only the name of a system is given.
	{
		"cluster" : "Moirai",
		"name" : "Spark",
	},
	
	# Nothing is provided, everything is at random.
	{
		"cluster" : "Moirai",
	},
	
]

############### FUNCTIONS ###############
generated_systems_random = []
generated_systems_preset = []

def system_random_generation(star_id, cluster_name):
	print("rnd ", star_id, cluster_name)
	#generated_systems_random.append(1)
	
def system_preset_generation(system):
	print("DEF ", system)
	#generated_systems_preset.append(1)

############### MAIN ###############
print("Generation begin")
print("=============\n")
for cluster in clusters:
	generated_stars = 0
	cluster_name = cluster[0]
	cluster_stars = cluster[1]
	while generated_stars < cluster_stars:
		star_id = generated_stars
		try:
			# Proceed with user-defined list.
			# If cluster name matches - proceed with data.
			if systems[star_id]["cluster"] == cluster_name:
				system_preset_generation(systems[star_id])
				generated_stars += 1
			# If clustee name is different - skip to random.
			else:
				system_random_generation(star_id, cluster_name)
				generated_stars += 1
		except:
			# Proceed with generation at random.
			system_random_generation(star_id, cluster_name)
			generated_stars += 1
		
print("\n=============")
print("Generation done")