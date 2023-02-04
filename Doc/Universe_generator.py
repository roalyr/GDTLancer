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
		"user_defined_main_star" : "O",
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

num_stars_min = 1
num_stars_max = 7

num_planets_min = 0
num_planets_max = 30

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



############### FUNCTIONS ###############
import random
random.seed(seed)
# Quantity according to frequency
# https://www3.nd.edu/~busiforc/handouts/cryptography/letterfrequencies.html
chars_low_v = "y"+"u"*2+"oi"*4+"a"*5+"e"*6
chars_low_c = "qjzx"+"vk"*5+"w"*7+"f"*9+"b"*11\
	+"g"*12+"hm"*15+"p"*16+"d"*17+"c"*23+"l"*28\
	+"s"*29+"n"*34+"t"*35+"r"*39

chars_low_c = ''.join(random.sample(chars_low_c,len(chars_low_c)))
chars_low_v = ''.join(random.sample(chars_low_v,len(chars_low_v)))


generated_systems_random = []
generated_systems_preset = []
generated_names = []

def system_random_generation(star_id, cluster_name):
	p = ""
	p += "Star cluster: " + cluster_name + "\n"
	p += "System ID: " + str(star_id) + "\n"
	p += "System name (gen): " + random_system_name(5, 6) + "\n"
	p += "Total number of stars (gen): " + str(random_star_number()) + "\n"
	p += "Total number of planets (gen): " + str(random_planet_number())+ "\n"
	
	print(p)
	
def system_preset_generation(star_id, system):
	p = ""
	p += "System ID: " + str(star_id) + "\n"
	
	if "cluster" in system:
		p += "Star cluster: " + system["cluster"] + "\n"
	else:
		p += "Star cluster: unspecified" + "\n"
	
	if "name" in system:
		p += "System name: " + system["name"] + "\n"
	else:
		p += "System name (gen): " + random_system_name(5, 6) + "\n"
	
	if "total_stars" in system:
		p += "Total number of stars: " + str(system["total_stars"]) + "\n"
	else:
		p += "Total number of stars (gen): " + str(random_star_number())+ "\n"
		
	if "total_planets" in system:
		p += "Total number of planets: " + str(system["total_planets"]) + "\n"
	else:
		p += "Total number of planets (gen): " + str(random_planet_number())+ "\n"
	
	print(p)
	
def random_star_number():
	num = int(random.random()*random.randint(num_stars_min, num_stars_max))
	if num == 0:
		num =1
	return num
	
def random_planet_number():
	num = int(random.random()*random.randint(num_planets_min, num_planets_max))
	return num

def random_system_name(min, max):
	system_name = random_name(min, max)
	if not system_name in generated_names:
		generated_names.append(system_name)
	else:
		print("duplicate name: ", system_name)
		while system_name in generated_names:
			system_name = random_name(min, max)
	return system_name

def random_name(length_max, length_min):
	length = random.randint(length_max, length_min)
	vowel_ratio = 0.5
	r = random.random()
	max_vowels_consequtive = 0
	max_cosonants_consequiteve = 0
	if r < 0.3:
		max_vowels_consequtive = 1
		max_cosonants_consequiteve = 2
	elif r > 0.3 and r < 0.6:
		max_vowels_consequtive = 2
		max_cosonants_consequiteve = 2
	else:
		max_vowels_consequtive = 1
		max_cosonants_consequiteve = 1
		length += 1
		
	num_v = 0
	num_c = 0
	str = ''
	for ch in range(length):
		r = random.random()
		if r < vowel_ratio:
			if num_v < max_vowels_consequtive:
				str += ''.join(random.choices(chars_low_v, k=1))
				num_v += 1
				num_c = 0
			else:
				str += ''.join(random.choices(chars_low_c, k=1))
				num_v = 0
				num_c += 1
		else:
			if num_c < max_cosonants_consequiteve:
				str += ''.join(random.choices(chars_low_c, k=1))
				num_c += 1
				num_v = 0
			else:
				str += ''.join(random.choices(chars_low_v, k=1))
				num_c = 0
				num_v += 1
	
	#str = str.replace("rs", "ras")
	if (str[0] in chars_low_c and str[1] in chars_low_c):
		str = str[1:]
	
	if  str[0] == 'x':
		str = str[1:]
		
	if  str[len(str)-1] == 'x':
		str = str[:len(str)-1]
		
	if  str[len(str)-1] == 'y':
		str = str[:len(str)-1]
	
	return str.capitalize()

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
				system_preset_generation(star_id, systems[star_id])
				generated_stars += 1
			# If clustee name is different - skip to random.
			else:
				system_random_generation(star_id, cluster_name)
				generated_stars += 1
		except IndexError:
			# Proceed with generation at random.
			system_random_generation(star_id, cluster_name)
			generated_stars += 1
		
print("\n=============")
print("Generation done")