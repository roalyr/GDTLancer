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

	# An example of user-specified planetary system.
	{
		"cluster" : "Moirai",
		"name" : "Victory",
		"total_companion_stars" : 2,
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
		"user_defined_main_star" : "B",
		"total_companion_stars" : 1,
	},
	
	# Only the name of a system is given.
	{
		"cluster" : "Moirai",
		"name" : "Spark",
		"user_defined_main_star" : "M",
		"total_companion_stars" : 0,
	},
	
	# Nothing is provided, everything is at random.
	{
		"cluster" : "Moirai",
		"user_defined_main_star" : "A",
	},
	
]





######################################
# Below is the code, do not edit.
######################################



############### CONSTANTS ###############
# General
seed = "GDTLancer"

import os
cwd = os.path.normpath(os.getcwd())

# Sun data for reference
sun_diameter = 1.39e9
sun_density = 1408 # kg / m3
sun_luminosity = 3.827e+26 # Watts
sun_temperature = 5771.8 # K
sun_omni_sidstance = 1e13 # GODOT omni light

# f = L / (4 * pi * d²).
# https://www.astronomy.ohio-state.edu/weinberg.21/Intro/lec2.html#:~:text=More%20generally%2C%20the%20luminosity%2C%20apparent,is%20an%20important%20intrinsic%20property.
# L = intrinsic luminosity of the source
# d = distance of the source
# f = apparent brightness (flux) of the source
#
# Luminocity formula
# https://www.quora.com/What-is-the-formula-between-the-temperature-and-luminosity-of-a-main-sequence-star
# L = (7.12560265e-7 Wm⁻²K⁻⁴) R²T⁴
c_lum = 7.12560265e-7

# Wavelength constant. nm*K
c_wien = 2897771.9 
# Spectrum margins. In nanometers.
# X-ray. https://en.m.wikipedia.org/wiki/X-ray
wl_xray_min = 0.01
# Ultraviolet. https://en.m.wikipedia.org/wiki/Ultraviolet
wl_euv_min = 10
wl_fuv_min = 122
wl_muv_min = 200
wl_nuv_min = 300
# Visible. https://en.m.wikipedia.org/wiki/Light
wl_visible_min = 400
# Infrared. https://en.m.wikipedia.org/wiki/Infrared#Regions_within_the_infrared
wl_nir_min = 700
wl_swir_min = 1400
wl_mwir_min = 3000
wl_lwir_min = 8000
wl_fir_min = 15000

# Companion stars for the main star.
num_stars_min = 0
num_stars_max = 7

# Planets for each star type.
star_o_num_planets_min = 1
star_o_num_planets_max = 30
star_b_num_planets_min = 1
star_b_num_planets_max = 20
star_a_num_planets_min = 1
star_a_num_planets_max = 20
star_f_num_planets_min = 1
star_f_num_planets_max = 15
star_g_num_planets_min = 0
star_g_num_planets_max = 10
star_k_num_planets_min = 0
star_k_num_planets_max = 7
star_m_num_planets_min = 0
star_m_num_planets_max = 5

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

star_temp_max = 100000
star_temp_min = 2400
star_primary_wl_min = c_wien / star_temp_min
star_primary_wl_max = c_wien / star_temp_max

star_o_size_min = 6.6 * sun_diameter
star_o_size_max = 10 * sun_diameter
star_o_temp_min = 30000
star_o_temp_max = star_temp_max
star_o_mass_min = 16
star_o_mass_max = 90
# Abundance is tweaked for gameplay purposes.
star_o_abundance = 0.002

star_b_size_min = 1.8 * sun_diameter
star_b_size_max = 6.6 * sun_diameter
star_b_temp_min = 10000
star_b_temp_max = 30000
star_b_mass_min = 2.1
star_b_mass_max = 16
# Abundance is tweaked for gameplay purposes.
star_b_abundance = 0.02

star_a_size_min = 1.4 * sun_diameter
star_a_size_max = 1.8 * sun_diameter
star_a_temp_min = 7500
star_a_temp_max = 10000
star_a_mass_min = 1.4
star_a_mass_max = 2.1
# Abundance is tweaked for gameplay purposes.
star_a_abundance = 0.06

star_f_size_min = 1.15 * sun_diameter
star_f_size_max = 1.4 * sun_diameter
star_f_temp_min = 6000
star_f_temp_max = 7500
star_f_mass_min = 1.04
star_f_mass_max = 1.4
# Abundance is tweaked for gameplay purposes.
star_f_abundance = 0.1

star_g_size_min = 0.96 * sun_diameter
star_g_size_max = 1.15 * sun_diameter
star_g_temp_min = 5200
star_g_temp_max = 6000
star_g_mass_min = 0.8
star_g_mass_max = 1.04
# Abundance is tweaked for gameplay purposes.
star_g_abundance = 0.2

star_k_size_min = 0.7 * sun_diameter
star_k_size_max = 0.96 * sun_diameter
star_k_temp_min = 3700
star_k_temp_max = 5200
star_k_mass_min = 0.45
star_k_mass_max = 0.8
# Abundance is tweaked for gameplay purposes.
star_k_abundance = 0.3

star_m_size_min = 0.1 * sun_diameter
star_m_size_max = 0.7 * sun_diameter
star_m_temp_min = star_temp_min
star_m_temp_max = 3700
star_m_mass_min = 0.08
star_m_mass_max = 0.45
# Abundance is tweaked for gameplay purposes.
star_m_abundance = 0.8

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
import random as random_star_num
import random as random_star_abundance
import random as random_star_val
import random as random_planet_num
import random as random_planet_val
import random as random_char

random_star_num.seed(seed + '153gf67')
random_star_abundance.seed(seed + 'hwhdd34')
random_star_val.seed(seed + 'gj754')
random_planet_num.seed(seed + '2hf5578')
random_planet_val.seed(seed + 'wyf7eh')
random_char.seed(seed + '3643rg')

# Quantity according to frequency
# https://www3.nd.edu/~busiforc/handouts/cryptography/letterfrequencies.html
chars_low_v = "y"+"u"*2+"oi"*4+"a"*5+"e"*6
chars_low_c = "qjzx"+"vk"*5+"w"*7+"f"*9+"b"*11\
	+"g"*12+"hm"*15+"p"*16+"d"*17+"c"*23+"l"*28\
	+"s"*29+"n"*34+"t"*35+"r"*39

chars_low_c = ''.join(random_char.sample(chars_low_c,len(chars_low_c)))
chars_low_v = ''.join(random_char.sample(chars_low_v,len(chars_low_v)))

output = ''

generated_systems_random = []
generated_systems_preset = []
used_names = []

total_number_o_stars = 0
total_number_b_stars = 0
total_number_a_stars = 0
total_number_f_stars = 0
total_number_g_stars = 0
total_number_k_stars = 0
total_number_m_stars = 0
total_number_other_stars = 0
total_number_all_stars = 0

# Visible spectrum palette.64 colors
spectrum_palette  = [
(79, 38, 122), 
(85, 51, 141), 
(85, 62, 150), 
(84, 73, 157), 
(85, 80, 162), 
(87, 91, 168), 
(93, 109, 179), 
(100, 128, 192), 
(106, 146, 204), 
(113, 163, 215),
(119, 179, 225), 
(125, 193, 234), 
(128, 205, 241), 
(120, 208, 232), 
(100, 201, 206), 
(77, 193, 177), 
(55, 185, 151), 
(35, 178, 125), 
(17, 171, 103), 
(3, 166, 85), 
(8, 167, 78), 
(25, 172, 71), 
(47, 179, 65), 
(72, 186, 57), 
(99, 195, 49), 
(128, 202, 39), 
(159, 212, 29), 
(192, 222, 18), 
(225, 232, 8), 
(248, 236, 2), 
(252, 227, 2), 
(251, 213, 3), 
(250, 199, 6), 
(249, 185, 9), 
(248, 170, 11), 
(247, 155, 14), 
(246, 139, 16),
(244, 123, 19),
(243, 106, 22),
(241, 90, 24),
(240, 74, 26),
(239, 57, 29),
(237, 40, 32),
(236, 27, 35),
(236, 27, 36),
(237, 27, 37),
(237, 27, 38),
(237, 27, 39),
(236, 26, 40),
(237, 26, 42),
(237, 26, 44),
(236, 26, 46),
(236, 26, 49), 
(235, 25, 51), 
(236, 25, 54),
(236, 25, 57), 
(236, 25, 58), 
(236, 25, 58), 
(235, 25, 58), 
(232, 26, 57), 
(226, 26, 56), 
(216, 27, 55), 
(202, 29, 53), 
(176, 31, 48),
(0, 0, 0)]

def e(x):
	return  "{:.2e}".format(x)

def rgb_to_hex(rgb):
	return '%02x%02x%02x' % rgb

###### FORMATTING ######
def system_generation(star_id, system, cluster_name):
	
	global output
	
	main_star = {}
	star_type = ''
	star_name = ''
	
	# Get the star if it was defined.
	if "user_defined_main_star" in system:
		main_star = random_star(system["user_defined_main_star"])
		star_type = system["user_defined_main_star"]
	else:
		# Generate a stat.
		main_star = random_star('')
		star_type = main_star["type"]
		
	
	# Format star size.
	star_size = e(main_star["size"])
	star_size_rel = round(main_star["size"] / sun_diameter, 3)
	
	# Format the number back to proper range.
	star_lum = e(main_star["luminosity"])
	star_lum_rel = main_star["luminosity"] / sun_luminosity
	if star_lum_rel < 1:
		star_lum_rel = round(star_lum_rel, 3)
	elif star_lum_rel < 10:
		star_lum_rel = round(star_lum_rel, 2)
	elif star_lum_rel < 100:
		star_lum_rel = round(star_lum_rel, 1)
	else:
		star_lum_rel = round(star_lum_rel)
		
	# Format the number for temperature.
	star_temp = round(main_star["temperature"])
	star_temp_rel = round(main_star["temperature"] / sun_temperature, 2)
	
	star_peak_wavelength = round(main_star["peak_wavelength"], 0)
	star_peak_wavelength_type = main_star["peak_wavelength_type"]
	star_peak_wavelength_colorcode = main_star["peak_wavelength_colorcode"]
	star_peak_wavelength_colorcode_hex = rgb_to_hex(star_peak_wavelength_colorcode)
	
	p = ""
	p += "# System ID: " + str(star_id) + "  \n"
	
	if "name" in system:
		star_name = system["name"]
		# Track user-defined names too.
		used_names.append(star_name)
		p += "## System name: " + star_name + "  \n"
	else:
		star_name = random_system_name(5, 6) 
		p += "## System name (generated): " + star_name + "  \n"
	
	if "cluster" in system:
		p += "Star cluster: " + system["cluster"] + "  \n"
	else:
		if cluster_name:
			p += "Star cluster: " + cluster_name + "  \n"
		else:
			p += "Star cluster: unspecified" + "  \n"
	
	if "total_companion_stars" in system:
		p += "Total number of companion stars: " + str(system["total_companion_stars"]) + "  \n"
	else:
		p += "Total number of companion stars (generated): " + str(random_star_number())+ "  \n"
		
	if "total_planets" in system:
		p += "Total number of planets: " + str(system["total_planets"]) + "  \n"
	else:
		p += "Total number of planets (generated): " + str(random_planet_number(star_type)) + "  \n"
	
	if "user_defined_main_star" in system:
		p += "### Main star: " + star_name + " A (" + star_type + ")" + "  \n"
	else:
		p += "### Main star (generated): " + star_name + " A (" + star_type + ")" + "  \n"
	
	p += "<details><summary>Main star details</summary>" + "  \n\n"
	
	p += "#### Absolute units." + "  \n"
	p += "* Size: " + str(star_size) + " m" + "  \n"
	p += "* Temperature: " + str(star_temp) + " K" + "  \n"
	p += "* Luminosity: " + str(star_lum) + " W" + "  \n"
	
	p += "#### Sun units." + "  \n"
	p += "* Size: " + str(star_size_rel) + " D☉" + "  \n"
	p += "* Temperature: " + str(star_temp_rel) + " T☉" + "  \n"
	p += "* Luminosity: " + str(star_lum_rel) + " L☉" + "  \n"
	
	p += "#### Spectral data."+ "  \n"
	p += "* Peak wavelength: " + str(star_peak_wavelength) + " nm"+ "  \n"
	p += "* Peak wavelength type: " + star_peak_wavelength_type + "  \n"
	p += "* Peak w.l. color code (R, G, B), hex:" + "  \n"
	p +=  "![" + str(star_peak_wavelength_colorcode_hex)  + "]" \
		+ "(Colors/" + str(star_peak_wavelength_colorcode_hex)  + ".png)"
	p += " | " + str(star_peak_wavelength_colorcode)
	p += " | #" + str(star_peak_wavelength_colorcode_hex) + "  \n"
	
	p += "\n </details>" + "  \n"
	
	p += "\n---\n"
	
	output += p
	


###### STAR FUNCTIONS #######
def random_star(user_defined_type):
	global total_number_o_stars
	global total_number_b_stars
	global total_number_a_stars
	global total_number_f_stars
	global total_number_g_stars
	global total_number_k_stars
	global total_number_m_stars
	global total_number_other_stars
	global total_number_all_stars
	
	star_type = ''
	star_size = 0
	star_lum = 0
	star_temp = 0
	
	r = random_star_abundance.random()
	if user_defined_type :
		star_type = user_defined_type
	else:
		if r < star_o_abundance:
			star_type = ("O")
		elif r < star_b_abundance:
			star_type = ("B")
		elif r < star_a_abundance:
			star_type = ("A")
		elif r < star_f_abundance:
			star_type = ("F")
		elif r < star_g_abundance:
			star_type = ("G")
		elif r < star_k_abundance:
			star_type = ("K")
		elif r < star_m_abundance:
			star_type = ("M")
		else:
			star_type = ("Other")
		
	if star_type == "O":
		total_number_o_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_o_size_min), int(star_o_size_max))
		star_temp = random_star_val.randrange(int(star_o_temp_min), int(star_o_temp_max))
		star_temp_norm = (star_temp - star_o_temp_min) / (star_o_temp_max - star_o_temp_min)
	elif star_type == "B":
		total_number_b_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_b_size_min), int(star_b_size_max))
		star_temp = random_star_val.randrange(int(star_b_temp_min), int(star_b_temp_max))
		star_temp_norm = (star_temp - star_b_temp_min) / (star_b_temp_max - star_b_temp_min)
	elif star_type == "A":
		total_number_a_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_a_size_min), int(star_a_size_max))
		star_temp = random_star_val.randrange(int(star_a_temp_min), int(star_a_temp_max))
	elif star_type == "F":
		total_number_f_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_f_size_min), int(star_f_size_max))
		star_temp = random_star_val.randrange(int(star_f_temp_min), int(star_f_temp_max))
	elif star_type == "G":
		total_number_g_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_g_size_min), int(star_g_size_max))
		star_temp = random_star_val.randrange(int(star_g_temp_min), int(star_g_temp_max))
	elif star_type == "K":
		total_number_k_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_k_size_min), int(star_k_size_max))
		star_temp = random_star_val.randrange(int(star_k_temp_min), int(star_k_temp_max))
	elif star_type == "M":
		total_number_m_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_m_size_min), int(star_m_size_max))
		star_temp = random_star_val.randrange(int(star_m_temp_min), int(star_m_temp_max))
	else:
		total_number_other_stars += 1
		total_number_all_stars += 1
	
	star_lum = get_strar_lum(star_size, star_temp)
	star_peak_wavelength = get_strar_peak_wavelength(star_temp)
	
	
	star = {
		"type" : star_type,
		"size" : star_size,
		"luminosity" : star_lum,
		"temperature" : star_temp,
		"peak_wavelength":  star_peak_wavelength[0],
		"peak_wavelength_type":  star_peak_wavelength[1],
		"peak_wavelength_colorcode":  star_peak_wavelength[2],
	}
	
	return star
	
	
def get_strar_lum(star_size, star_temp):
	lum = c_lum * pow((star_size/2), 2) * pow(star_temp, 4)
	return lum
	
	
def get_strar_peak_wavelength(star_temp):
	peak_wavelength = 0
	peak_wavelength_type = ''
	peak_wavelength_colorcode = (0, 0, 0)
	
	if star_temp > 0:
		peak_wavelength = c_wien / star_temp
	
	if peak_wavelength < wl_xray_min:
		peak_wavelength_type  = "gamma"
	elif peak_wavelength >= wl_xray_min and peak_wavelength < wl_euv_min:
		peak_wavelength_type  = "x-ray"
	elif peak_wavelength >= wl_euv_min and peak_wavelength < wl_fuv_min:
		peak_wavelength_type  = "extreme UV"
	elif peak_wavelength >= wl_fuv_min and peak_wavelength < wl_muv_min:
		peak_wavelength_type  = "far UV"
	elif peak_wavelength >= wl_muv_min and peak_wavelength < wl_nuv_min:
		peak_wavelength_type  = "medium UV"
	elif peak_wavelength >= wl_nuv_min and peak_wavelength < wl_visible_min:
		peak_wavelength_type  = "near UV"
	elif peak_wavelength >= wl_visible_min and peak_wavelength < wl_nir_min:
		peak_wavelength_type  = "visible"
	elif peak_wavelength >= wl_nir_min and peak_wavelength < wl_swir_min:
		peak_wavelength_type  = "near IR"
	elif peak_wavelength >= wl_swir_min and peak_wavelength < wl_mwir_min:
		peak_wavelength_type  = "short IR"
	elif peak_wavelength >= wl_mwir_min and peak_wavelength < wl_lwir_min:
		peak_wavelength_type  = "medium IR"
	elif peak_wavelength >= wl_lwir_min and peak_wavelength < wl_fir_min:
		peak_wavelength_type  = "long IR"
	elif peak_wavelength >= wl_fir_min:
		peak_wavelength_type  = "far IR"
	elif peak_wavelength == 0:
		peak_wavelength_type  = " -- "
		
	# Get proper RGB from palette.
	if peak_wavelength > 0:
		wl_norm = (peak_wavelength - star_primary_wl_min) / (star_primary_wl_max - star_primary_wl_min)
		palette_index = 64 - int(wl_norm*64) # reverse spectrum.
		peak_wavelength_colorcode = spectrum_palette[palette_index]
		
	return (peak_wavelength, peak_wavelength_type, peak_wavelength_colorcode)


def random_star_number():
	num = int(random_star_num.random()*random_star_num.randint(num_stars_min, num_stars_max))
	if num == 0:
		num =1
	return num



###### PLANET FUNCTIONS #######
def random_planet_number(star_type):
	num = 0
	if star_type == "O":
		num = int(random_planet_num.randint(star_o_num_planets_min, star_o_num_planets_max))
	elif star_type == "B":
		num = int(random_planet_num.randint(star_b_num_planets_min, star_b_num_planets_max))
	elif star_type == "A":
		num = int(random_planet_num.randint(star_a_num_planets_min, star_a_num_planets_max))
	elif star_type == "F":
		num = int(random_planet_num.randint(star_f_num_planets_min, star_f_num_planets_max))
	elif star_type == "G":
		num = int(random_planet_num.randint(star_g_num_planets_min, star_g_num_planets_max))
	elif star_type == "K":
		num = int(random_planet_num.randint(star_k_num_planets_min, star_k_num_planets_max))
	elif star_type == "M":
		num = int(random_planet_num.randint(star_m_num_planets_min, star_m_num_planets_max))
		
	return num



###### NAMING ######
def random_system_name(min, max):
	system_name = random_name(min, max)
	if not system_name in used_names:
		used_names.append(system_name)
	else:
		print("duplicate name: ", system_name)
		while system_name in used_names:
			system_name = random_name(min, max)
	return system_name

def random_name(length_max, length_min):
	length = random_char.randint(length_max, length_min)
	vowel_ratio = 0.5
	r = random_char.random()
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
		r = random_char.random()
		if r < vowel_ratio:
			if num_v < max_vowels_consequtive:
				str += ''.join(random_char.choices(chars_low_v, k=1))
				num_v += 1
				num_c = 0
			else:
				str += ''.join(random_char.choices(chars_low_c, k=1))
				num_v = 0
				num_c += 1
		else:
			if num_c < max_cosonants_consequiteve:
				str += ''.join(random_char.choices(chars_low_c, k=1))
				num_c += 1
				num_v = 0
			else:
				str += ''.join(random_char.choices(chars_low_v, k=1))
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
import os
try:
	os.mkdir(cwd + "/Doc/Universe/")
except:
	pass

try:
	os.mkdir(cwd + "/Doc/Universe/Colors")
except:
	pass

# Prepare colors from palettes.
# https://stackoverflow.com/questions/8554282/creating-a-png-file-in-python
import png
width = 15*3
height = 15

for color in spectrum_palette:
	img = []
	for y in range(height):
		row = ()
		for x in range(width):
			row = color*width
		img.append(row)
		
	name = rgb_to_hex(color) + ".png"
	with open(cwd + "/Doc/Universe/Colors/" + name, 'wb') as f:
		w = png.Writer(width, height, greyscale=False)
		w.write(f, img)

	
# Proceed with preset data.
print("Generation begin: FROM PRESET")
for cluster in clusters:
	for star_id in range(len(systems)):
		system_generation(star_id, systems[star_id], '')
			
print("Total number of stars:")
print("O - ", total_number_o_stars)
print("B - ", total_number_b_stars)
print("A - ", total_number_a_stars)
print("F - ", total_number_f_stars)
print("G - ", total_number_g_stars)
print("K - ", total_number_k_stars)
print("M - ", total_number_m_stars)
print("Other - ", total_number_other_stars)
print("All - ", total_number_all_stars)
print("Generation done: Universe/Universe_user_defined.md")
print()


f = open(cwd + "/Doc/Universe/Universe_user_defined.md", "w")
f.write(output)
f.close()
#print(output)


# Generate additional random universe file.
# Quickly reset generators in order to not to affect new entities.
import random as random_star_num
import random as random_star_abundance
import random as random_star_val
import random as random_planet_num
import random as random_planet_val
import random as random_char


random_star_num.seed(seed + '153gf67')
random_star_abundance.seed(seed + 'hwhdd34')
random_star_val.seed(seed + 'gj754')
random_planet_num.seed(seed + '2hf5578')
random_planet_val.seed(seed + 'wyf7eh')
random_char.seed(seed + '3643rg')


output = ''

total_number_o_stars = 0
total_number_b_stars = 0
total_number_a_stars = 0
total_number_f_stars = 0
total_number_g_stars = 0
total_number_k_stars = 0
total_number_m_stars = 0
total_number_other_stars = 0
total_number_all_stars = 0

print("Generation begin: RANDOM")
for cluster in clusters:
	generated_stars = 0
	cluster_name = cluster[0]
	cluster_stars = cluster[1]
	while generated_stars < cluster_stars:
		star_id = generated_stars
		system_generation(star_id, {}, cluster_name)
		generated_stars += 1
	
print("Total number of stars:")
print("O - ", total_number_o_stars)
print("B - ", total_number_b_stars)
print("A - ", total_number_a_stars)
print("F - ", total_number_f_stars)
print("G - ", total_number_g_stars)
print("K - ", total_number_k_stars)
print("M - ", total_number_m_stars)
print("Other - ", total_number_other_stars)
print("All - ", total_number_all_stars)
print("Generation done: Universe/Universe_random_reference.md")


f = open(cwd + "/Doc/Universe/Universe_random_reference.md", "w")
f.write(output)
f.close()
#print(output)