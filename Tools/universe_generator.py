############### PARAMETERS ###############
seed = "GDTLancer"

# GODOT engine parameters.
star_zone_size_factor = 50 # Multiplied by star size.
star_zone_size_by_death_zone_factor = 10 # If star zone is less than death zone.
star_death_zone_min_factor = 1.5 # If death zone is too small.
star_detail_decay_distance_factor = 40 # Distance factor at which star core turns white.
star_autopilot_factor = 2.0 # Multiplied by death zone size.
star_flare_factor = 1.0 # Multiplied by star zone size. Acts like an indicatort.
system_zone_size_min = 1e13 # Threshold to prevent jitter.

planet_zone_size_factor = 20 # Multiplied by planet size.
planet_death_zone_factor = 1.05 # Planet death zone (atmosphere or gravitation pull?)
planet_autopilot_factor = 2.0 # Multiplied by death zone size.

# Companion stars for the main star.
num_stars_min = 0
num_stars_max = 5

# Planets for each star type.
star_o_num_planets_min = 1
star_o_num_planets_max = 5

star_b_num_planets_min = 1
star_b_num_planets_max = 15

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









############### IMPORTS ################

import universe_presets
import universe_test_presets
import palettes

# Using multiple random instances to not to affect different states.
import random as random_star_num
import random as random_star_abundance
import random as random_star_val
import random as random_planet_num
import random as random_planet_val
import random as random_char
import operator

import os
import png
import math












######### CONSTANTS: FUNCTIONS ##########

# Formatting mini-functions.
def e(x):
	return  "{:.2e}".format(x)

def rgb_to_hex(rgb):
	return '%02x%02x%02x' % rgb

def clamp(n, min, max):
	if n < min:
		return min
	elif n > max:
		return max
	else:
		return n

# Make additional folders.
cwd = os.path.normpath(os.getcwd())

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
width = 19
height = 19

for color in palettes.spectrum_palette:
	img = []
	for y in range(height):
		t = pow(math.sin(y/height*math.pi),1.2)
		row = []
		for x in range(width):
			s = pow(math.sin(x/width*math.pi),1.2)
			row.append(int(color[0]*s*t))
			row.append(int(color[1]*s*t))
			row.append(int(color[2]*s*t))
		img.append(row)
		
	name = rgb_to_hex(color) + ".png"
	with open(cwd + "/Doc/Universe/Colors/" + name, 'wb') as f:
		w = png.Writer(width, height, greyscale=False)
		w.write(f, img)
		
# Make a blank image.
img = []
for y in range(height):
	row = ()
	for x in range(width):
		row = (0, 0, 0)*width
	img.append(row)
	
name = rgb_to_hex((0, 0, 0)) + ".png"
with open(cwd + "/Doc/Universe/Colors/" + name, 'wb') as f:
	w = png.Writer(width, height, greyscale=False)
	w.write(f, img)














######### CONSTANTS: STARS ##########

# Sun data for reference
sun_diameter = 1.39e9
sun_density = 1408 # kg / m3
sun_distance_au = 149597870700 #m
sun_luminosity = 3.827e+26 # Watts
sun_luminosity_visible = 0.47 * sun_luminosity # ~1.8e+26 Watts
sun_temperature = 5771.8 # K
sun_mass = 1.99e30 # kg

# GODOT omni light
# Omni light formula: range = (luminocity/4)^(1/2)
# Omni energy = 2, omni attenuation = 10.
star_omni_ratio = 4 
sun_omni_didstance = 1e13 # For reference.
sun_omni_energy = 2.0
sun_omni_attenuation = 10.0 

# f = L / (4 * pi * d²).
# d² = L / (4 * pi * f), d = (L / (4 * pi * f))^(1/2)
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

# Set those margins respectively.
# W/m^2 at respective star distance.
flux_dust_melting  = 225000 # Derived above.
flux_hot_zone  = 34000
flux_warm_zone  = 2800
flux_temperate_zone  = 1400
flux_cold_zone  = 600
# https://en.m.wikipedia.org/wiki/Frost_line_(astrophysics)
# Distinction between terran and jovian planet formation regions.
# Water ice formation flux.
flux_frost_line  = 170 # Ice sublimation.

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


# Star type parameters
# https://en.m.wikipedia.org/wiki/Stellar_classification

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
star_o_abundance = 0.02 # use 0.002

star_b_size_min = 1.8 * sun_diameter
star_b_size_max = 6.6 * sun_diameter
star_b_temp_min = 10000
star_b_temp_max = 30000
star_b_mass_min = 2.1
star_b_mass_max = 16
# Abundance is tweaked for gameplay purposes.
star_b_abundance = 0.05 # use 0.02

star_a_size_min = 1.4 * sun_diameter
star_a_size_max = 1.8 * sun_diameter
star_a_temp_min = 7500
star_a_temp_max = 10000
star_a_mass_min = 1.4
star_a_mass_max = 2.1
# Abundance is tweaked for gameplay purposes.
star_a_abundance = 0.1 # use 0.06

star_f_size_min = 1.15 * sun_diameter
star_f_size_max = 1.4 * sun_diameter
star_f_temp_min = 6000
star_f_temp_max = 7500
star_f_mass_min = 1.04
star_f_mass_max = 1.4
# Abundance is tweaked for gameplay purposes.
star_f_abundance = 0.2 # use 0.1

star_g_size_min = 0.96 * sun_diameter
star_g_size_max = 1.15 * sun_diameter
star_g_temp_min = 5200
star_g_temp_max = 6000
star_g_mass_min = 0.8
star_g_mass_max = 1.04
# Abundance is tweaked for gameplay purposes.
star_g_abundance = 0.3 # use 0.2

star_k_size_min = 0.7 * sun_diameter
star_k_size_max = 0.96 * sun_diameter
star_k_temp_min = 3700
star_k_temp_max = 5200
star_k_mass_min = 0.45
star_k_mass_max = 0.8
# Abundance is tweaked for gameplay purposes.
star_k_abundance = 0.5 # use 0.3

star_m_size_min = 0.1 * sun_diameter
star_m_size_max = 0.7 * sun_diameter
star_m_temp_min = star_temp_min
star_m_temp_max = 3700
star_m_mass_min = 0.08
star_m_mass_max = 0.45
# Abundance is tweaked for gameplay purposes.
star_m_abundance = 1.0 #use 0.8 when giants and white dwarfs are implemented.









######### CONSTANTS: PLANETS ##########
earth_mass = 5.972e24 #kg
earth_radius =  6.3781e6 #m

# Protoplanetary disks
# https://www.researchgate.net/publication/311106398_The_Gas_Disk_Evolution_and_Chemistry
# Total amount of planetaty systems which are at protoplanetary stage.
protoplanetary_disks_fraction = 0.05

# Total number of protoplanetary systems which are moderately young.
# have acctetion and jets. Uniform consistent disks?
protoplanetary_disks_with_accretion_fraction = 0.2 

# Amount of gas mass in protoplanetary systems which are more mature.
# Here we assume that some of it was scattered away.
protoplanetaty_disk_gas_debris_ratio_max = 1.0
protoplanetaty_disk_gas_debris_ratio_min = 0.1

# Protoplanetary disk mass according to central star mass ratio.
# https://www.researchgate.net/figure/Scattering-of-protoplanetary-disk-masses-according-to-the-mass-of-the-central-star_fig5_330576670
protoplanetaty_disk_mass_ratio_max = 1.0
protoplanetaty_disk_mass_ratio_min = 0.01

# Zoning of a disk as a function of a star flux (W/m2).
# Flux at which ice begins to form.
protoplanetaty_disk_snow_line_flux = flux_frost_line



# A next stage in modelling after a protoplanetagy disk will be young planetary system.
# Total number of young planetary systems.
young_planetary_systems_fraction = 0.2

# The amount of mass distributed as debris and dust(?).
young_planetary_system_debris_ratio_max = 0.4
young_planetary_system_debris_ratio_min = 0.05

# Large planetary objects.
young_planetary_system_planets_min  = 0
# young_planetary_system_planets_max  = ???

# Small planetary objects.
young_planetary_system_planetoid_min  = 0
# young_planetary_system_planetoid_max  = ???


# Planetary resonanse factors.
resonance_ratio_list = [1.33, 1.5, 2.0]

# Safe gravitational zone threshild multiplier for beighbor planets.
hill_radii_stability_multiplier = 2

# Multiplier for frost line.
gas_giant_spawn_distance_factor = 10

# Type of planet  Earth units		R = M^f
planet_rocky_radius_factor = 0.28

#  M min  M max  R min  R max  f
# Sub-dwarf  0.000002  0.00002  0.025  0.048  0.28
planet_sD_mass_min = 0.000002
planet_sD_mass_max = 0.00002

# Dwarf  0.00002  0.0002  0.048  0.092  0.28
planet_D_mass_min = 0.00002
planet_D_mass_max = 0.0002

# Super-dwarf  0.0002  0.002  0.092  0.176  0.28
planet_SD_mass_min = 0.0002
planet_SD_mass_max = 0.002
		   
# Sub-terrestrial  0.002  0.02  0.176  0.334  0.28
planet_sT_mass_min = 0.002
planet_sT_mass_max = 0.02

# Terrestrial  0.02  0.2  0.334  0.637  0.28
planet_T_mass_min = 0.02
planet_T_mass_max = 0.2

# Super-terrestrial  0.2  2  0.637  1.214  0.28
planet_ST_mass_min = 0.2
planet_ST_mass_max = 2

# Sub-giant  2  130  1.505  17.670  0.59
planet_sub_giant_radius_factor = 0.59

planet_sG_mass_min = 2
planet_sG_mass_max = 130

# Giant  130  300  9.000  20.000  -
planet_G_mass_min = 130
planet_G_mass_max = 300

# Super-giant  300  3000  9.000  20.000  -
planet_SG_mass_min = 300
planet_SG_mass_max = 3000

planet_G_radius_min = 9
planet_G_radius_max = 20













################# TESTING ###############
# Habitable zone margins for sun (lax).
# https://en.m.wikipedia.org/wiki/Circumstellar_habitable_zone
# 0.2 a.u. from Sun (hot zone).
sun_hot_zone = sun_distance_au * 0.2 
sun_hot_zone_flux = sun_luminosity / (4 * 3.14 * sun_hot_zone * sun_hot_zone)
# Venus (warm zone).
sun_warm_zone = sun_distance_au * 0.7
sun_warm_zone_flux = sun_luminosity / (4 * 3.14 * sun_warm_zone * sun_warm_zone)
# Earth (reference value).
sun_temperate_zone = sun_distance_au * 1.0
sun_temperate_zone_flux = sun_luminosity / (4 * 3.14 * sun_temperate_zone * sun_temperate_zone)
# Mars (cold zone).
sun_cold_zone = sun_distance_au * 1.5
sun_cold_zone_flux = sun_luminosity / (4 * 3.14 * sun_cold_zone * sun_cold_zone)

# Sun snow line.
# T = (L / (2.85e-6 * R^2))^(1/4)
# T^4 = L / (2.85e-6 * R^2); R = (L / (T^4 * 2.85e-6))^(1/2)
# flux = sigma * T^4
SB_sigma = 5.670373e-8 # Stefan-Boltzman c.
sun_frost_line_dust_temp = 170
sun_frost_line_distance = pow(sun_luminosity / (2.85e-6 * pow(sun_frost_line_dust_temp, 4)), 0.5)
sun_frost_line_flux = sun_luminosity / (4 * 3.14 * sun_frost_line_distance * sun_frost_line_distance)

# Silicate particles melting distance.
dust_melting_temp = 1000
sun_dust_melting_distance = pow(sun_luminosity / (2.85e-6 * pow(dust_melting_temp, 4)), 0.5)
sun_dust_melting_flux = sun_luminosity / (4 * 3.14 * sun_dust_melting_distance * sun_dust_melting_distance)

# Values for ship default flux resistence. Affects the distance you can be at around star.
melting_temp = 900
material_albedo = 0.9
melting_flux_worst =  SB_sigma * pow(melting_temp, 4) / (1 - material_albedo)
melting_flux_average = melting_flux_worst * 2

# Testing.
melting_distance_average_O0 =  pow( 2e33 / (4 * 3.14 * melting_flux_average), 0.5)
melting_distance_average_B9 =  pow( 1.85e+29 / (4 * 3.14 * melting_flux_average), 0.5)
melting_distance_average_G5 =  pow( 4.5e26 / (4 * 3.14 * melting_flux_average), 0.5)
melting_distance_average_M9 =  pow( 2.94e+23 / (4 * 3.14 * melting_flux_average), 0.5)


print("Value testing")
print("-----------")
print("Melting flux at 0.9 albedo (W/m2) worst ", e(melting_flux_worst))
print("Melting flux at 0.9 albedo (W/m2) avg ", e(melting_flux_average))
print("Melting distance avg O0 star (rel) ", e(melting_distance_average_O0/1.1e10))
print("Melting distance avg B9 star (rel) ", e(melting_distance_average_B9/7.85e+09))
print("Melting distance avg G5 star (rel) ", e(melting_distance_average_G5/1.6e9))
print("Melting distance avg M9 star (rel) ", e(melting_distance_average_M9/2.13e+08))
print("-----------")
print("Assumed dust melting temperature (K)", dust_melting_temp)
print("Sun dust melting flux (W/m2)", round(sun_dust_melting_flux, 1), " at ", round(sun_dust_melting_distance/sun_distance_au, 2), "AU" ) # ~34000
print()
print("Sun hot zone flux (W/m2)", round(sun_hot_zone_flux, 1), " at ", round(sun_hot_zone/sun_distance_au, 2), "AU" ) # ~34000
print("Sun warm zone flux (W/m2)", round(sun_warm_zone_flux, 1), " at ", round(sun_warm_zone/sun_distance_au, 2), "AU" ) # ~2800
print("Sun temperate zone flux (W/m2)", round(sun_temperate_zone_flux, 1), " at ", round(sun_temperate_zone/sun_distance_au, 2), "AU" ) # ~1400
print("Sun cold zone flux (W/m2)", round(sun_cold_zone_flux, 1), " at ", round(sun_cold_zone/sun_distance_au, 2), "AU" ) # ~600
print()
print("Sun frost line flux (W/m2)", round(sun_frost_line_flux, 1), " at ", round(sun_frost_line_distance/sun_distance_au, 2), "AU" ) # ~190
print("Sun frost line dust temp (K)", round(sun_frost_line_dust_temp, 1)) # 170
print("-----------")













############### FUNCTIONS ###############

random_star_num.seed(seed + '153gf67')
random_star_abundance.seed(seed + 'hwhdd34')
random_star_val.seed(seed + 'gj754')
random_planet_num.seed(seed + '2hf5578')
random_planet_val.seed(seed + 'wyf7eh')
random_char.seed(seed + '3643rg')

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








############ SYSTEM GENERATION ###########

def system_generation(star_id, system, cluster_name):
	
	global output
	
	main_star = {}
	star_type = ''
	secondary_stars_num = 0
	planets_num = 0
	star_name = ''
	p = ''
	p_secondary_stars = ''
	star_list = []
	planet_list = []
	orbit_list = []
	planetary_data = []
	star_color_list = []
	
	# Get the star if it was defined. Second argument is for secondary stars, thus empty.
	if "main_star" in system:
		main_star = make_star(system["main_star"], ())
		star_type = system["main_star"]
	else:
		# Generate a stat.
		main_star = make_star('', ())
		star_type = main_star["type"]
	
	# Generate a systems and main star name if not defined.
	if "name" in system:
		star_name = system["name"]
		# Track user-defined names too.
		used_names.append(star_name)
	else:
		star_name = random_system_name(4, 7) 
	
	# Index 0 in the end takes the text + color sample image, 1 - only returns image.
	primary_star = formatting_star_data(star_id, True, main_star, star_name + " A")
	
	
	# Whether there are secondary stars (user defined).
	if "companion_stars" in system:
		secondary_stars_num = len(system["companion_stars"])
		if secondary_stars_num > 0:
			
			# Make from preset and store.
			for secondary_star_type in system["companion_stars"]:
				secondary_star = make_star(secondary_star_type, main_star["type"])
				star_list.append(secondary_star)
	
	# Randomly generate secondary stars otherwise.
	else:
		secondary_stars_num = random_star_number()
		if secondary_stars_num > 0:
			
			# Generate and store.
			for _ in range(secondary_stars_num):
				secondary_star = make_star('', main_star["type"])
				star_list.append(secondary_star)
					
	# Sort and output.
	star_list.sort(key = lambda x: (-x["temperature"]) )
	i = 0
	for secondary_star in star_list:
		i += 1
		s = formatting_star_data(
			str(star_id) + "_" + str(i), 
			False, # Not primary
			secondary_star, 
			star_name + " " + ABC[i])
		p_secondary_stars += s[0]
		star_color_list.append(s[1])
		
	# Generate planets.
	if "total_planets" in system:
		planets_num = len(system["total_planets"])
		if planets_num > 0:
			
			# Make from preset and store.
			for planet_type in system["total_planets"]:
				planet = make_planet(planet_type, main_star["type"])
				planet_list.append(planet)
	else:
		planets_num = random_planet_number(star_type[0])
		if planets_num > 0:
			
			# Generate and store.
			for _ in range(planets_num):
				planet = make_planet('', main_star["type"])
				planet_list.append(planet)

	# Split planetary system into orbits.
	# Initial ranges.
	Lmin = main_star["zone_margins"][5]*random_planet_val.uniform(1, 10)  # Minimum distance from star
	Lmax = main_star["zone_margins"][0]*random_planet_val.uniform(0.9, 1.2)  # Maximum distance from star
	if "closest_orbit" in system:
		Lmin = clamp(system["closest_orbit"], main_star["zone_margins"][5], main_star["omni_range"])
	if "furthest_orbit" in system:
		Lmax = clamp(system["furthest_orbit"], main_star["zone_margins"][5], main_star["omni_range"])
	
	N = len(planet_list)
	resonance_ratio = random_planet_val.choice(resonance_ratio_list)
	if "orbit_ratio" in system:
		if system["orbit_ratio"] in resonance_ratio_list:
			resonance_ratio = system["orbit_ratio"]
	
	if N > 1:
		orbit_list = generate_semi_major_axes(N, Lmin, Lmax, resonance_ratio)
	elif N == 1:
		orbit_list = [random_planet_val.uniform(Lmin, Lmax)]
	else:
		orbit_list = []
		
	# Check planet list and sort out unlikely sequences.
	# Calculate Hill radii of each star-planet pair.
	planet_list = sort_orbits(planet_list, orbit_list, main_star, Lmax)
	
	# Determine temperature range and combine data.
	temperature_list = get_planet_temperature_list(orbit_list, planet_list, main_star)
	
	# TODO
	# Determine atmosphere.
	atmosphere_list = get_planet_atmosphere(planet_list, temperature_list)
	
	# Determine albedo.
	
	
	# Combine data previously received.
	for i in range(len(planet_list)):
		planetary_data.append(planet_list[i])
		planetary_data[i]["orbit"] = orbit_list[i]
		planetary_data[i]["temperature_type"] = temperature_list[i][0]
		planetary_data[i]["temperature"] = temperature_list[i][1]

	
	# Write down the text for the main star and the system.
	p += formatting_system_data(star_id, system, main_star, star_name)
	p += primary_star[0]
	p += p_secondary_stars
	p += formatting_planet_data(star_name, star_type, planetary_data)
	
	# Add star color samples in the end of star block.
	p += " " + primary_star[1] + ' '
	for sec_star_color in star_color_list:
		p += sec_star_color + ' '
	p += "  \n"
	p += "\n---  \n"

	# Write down to the global output.
	output += p
	
	
	
	
	
	
	
###### PLANET FUNCTIONS #######

def random_planet_number(star_type):
	num = 0
	if star_type == "O":
		num = int(random_planet_num.uniform(star_o_num_planets_min, star_o_num_planets_max))
	elif star_type == "B":
		num = int(random_planet_num.uniform(star_b_num_planets_min, star_b_num_planets_max))
	elif star_type == "A":
		num = int(random_planet_num.uniform(star_a_num_planets_min, star_a_num_planets_max))
	elif star_type == "F":
		num = int(random_planet_num.uniform(star_f_num_planets_min, star_f_num_planets_max))
	elif star_type == "G":
		num = int(random_planet_num.uniform(star_g_num_planets_min, star_g_num_planets_max))
	elif star_type == "K":
		num = int(random_planet_num.uniform(star_k_num_planets_min, star_k_num_planets_max))
	elif star_type == "M":
		num = int(random_planet_num.uniform(star_m_num_planets_min, star_m_num_planets_max))
		
	return num


def make_planet(user_defined_type, primary_star_type):
	planet_type = ""
	planet_size = 0
	planet_zone_margins = 0
	
	if user_defined_type:
		# Process planet data according to type.
		if user_defined_type == "SD":
			planet_type = "sub dwarf"
		elif user_defined_type == "D":
			planet_type = "dwarf"
		elif user_defined_type == "LD":
			planet_type = "super dwarf"
			
		elif user_defined_type == "ST":
			planet_type = "sub terrestrial"
		elif user_defined_type == "T":
			planet_type = "terrestrial"
		elif user_defined_type == "LT":
			planet_type = "super terrestrial"
			
		elif user_defined_type == "SG":
			planet_type = "sub giant"
		elif user_defined_type == "G":
			planet_type = "giant"
		elif user_defined_type == "LG":
			planet_type = "super giant"
		
		else:
			planet_type = "other"
			
	else:
		# Make a random type first.
		planet_type_list  = [
			"sub dwarf",
			"dwarf",
			"super dwarf",
			"sub terrestrial",
			"terrestrial",
			"super terrestrial",
			"sub giant",
			"giant",
			"super giant",
		]
		planet_type = random_planet_val.choice(planet_type_list)

	
	planet_mass = get_planet_mass(planet_type)
	planet_size = get_planet_size(planet_type, planet_mass)
	
	# Define zones.
	planet_zone_size = planet_size * planet_zone_size_factor
	planet_death_zone = planet_size * planet_death_zone_factor
	
	planet_zone_margins = [planet_zone_size, planet_death_zone]
	
	planet = {
		"type" : planet_type,
		"size" : planet_size,
		"mass" : planet_mass,
		"zone_margins": planet_zone_margins,
	}
	
	return planet


def get_planet_mass(planet_type):
	planet_mass = 0
	
	if planet_type == "sub dwarf":
		planet_mass = random_planet_val.uniform(planet_sD_mass_min, planet_sD_mass_max)
	elif planet_type == "dwarf":
		planet_mass = random_planet_val.uniform(planet_D_mass_min, planet_D_mass_max)
	elif planet_type == "super dwarf":
		planet_mass = random_planet_val.uniform(planet_SD_mass_min, planet_SD_mass_max)

	elif planet_type == "sub terrestrial":
		planet_mass = random_planet_val.uniform(planet_sT_mass_min, planet_sT_mass_max)
	elif planet_type == "terrestrial":
		planet_mass = random_planet_val.uniform(planet_T_mass_min, planet_T_mass_max)
	elif planet_type == "super terrestrial":
		planet_mass = random_planet_val.uniform(planet_ST_mass_min, planet_ST_mass_max)
		
	elif planet_type == "sub giant":
		planet_mass = random_planet_val.uniform(planet_sG_mass_min, planet_sG_mass_max)
	elif planet_type == "giant":
		planet_mass = random_planet_val.uniform(planet_G_mass_min, planet_G_mass_max)
	elif planet_type == "super giant":
		planet_mass = random_planet_val.uniform(planet_SG_mass_min, planet_SG_mass_max)

	else:
		print("Unknown planet type: ", planet_type)

	planet_mass *= earth_mass
	return planet_mass
	

def get_planet_size(planet_type, planet_mass):
	planet_size = 0

	planet_mass /= earth_mass

	if planet_type == "sub dwarf" or \
		planet_type == "dwarf" or \
		planet_type == "super dwarf" or \
		planet_type == "sub terrestrial" or \
		planet_type == "terrestrial" or \
		planet_type == "super terrestrial":
			
		planet_size = pow(planet_mass, planet_rocky_radius_factor) * earth_radius * 2

	elif planet_type == "sub giant":
		planet_size = pow(planet_mass, planet_sub_giant_radius_factor) * earth_radius * 2

	elif planet_type == "giant" or \
		planet_type == "super giant":

		planet_size = random_planet_val.uniform(planet_G_radius_min, planet_G_radius_max) * earth_radius * 2
	
	else:
		print("Unknown planet type: ", planet_type)
	
	return planet_size


def sort_orbits(planet_list, orbit_list, main_star, Lmax):
	# Hill radii.
	hill_radii_list = []
	for i in range(len(orbit_list)):
		planet = planet_list[i]
		orbit = orbit_list[i]
		hr = orbit * pow((planet["mass"] / 3 / (planet["mass"] + main_star["mass"])), (1/3))
		hill_radii_list.append(hr)
	
	# Remove gas giants past some threshold by changung its type.
	threshold = main_star["zone_margins"][0] * gas_giant_spawn_distance_factor
	for i in range(len(orbit_list)):
		planet = planet_list[i]
		orbit = orbit_list[i]
		if orbit >= threshold:
			if planet["type"] == "sub giant" or \
				planet["type"] == "giant" or \
				planet["type"] == "super giant": 
					
					# Change gas planet for tge dwarf planet.
					planet_list[i]["type"] = random_planet_val.choice(["sub dwarf", "dwarf", "super dwarf"])
					planet_list[i]["mass"] = get_planet_mass(planet_list[i]["type"])
					planet_list[i]["size"] = get_planet_size(planet_list[i]["type"], planet_list[i]["mass"])
					#print("Changing planet type past threshold at:", e(threshold), planet_list[i]["type"])
	
	# Remove small planets between giants.
	i = 0
	while i < len(planet_list)-2:
		if planet_list[i+1]["type"] == "sub dwarf" or \
		planet_list[i+1]["type"] == "dwarf" or \
		planet_list[i+1]["type"] == "super dwarf" or \
		planet_list[i+1]["type"] == "sub terrestrial" or \
		planet_list[i+1]["type"] == "terrestrial" or \
		planet_list[i+1]["type"] == "super terrestrial":
			
			if planet_list[i]["type"] == "sub giant" or \
			planet_list[i]["type"] == "giant" or \
			planet_list[i]["type"] == "super giant":
				if planet_list[i+2]["type"] == "sub giant" or \
				planet_list[i+2]["type"] == "giant" or \
				planet_list[i+2]["type"] == "super giant":
					
					#print("removing:", planet_list[i+1]["type"], "between:", planet_list[i]["type"], "and", planet_list[i+2]["type"])
					planet_list[i+1]["type"] = "- empty orbit -"
					planet_list[i+1]["mass"] = 0
					planet_list[i+1]["size"] = 0
					hill_radii_list[i+1] = 0
					i = 0
			
		i += 1
	
	# Remove small planets between hot-cold giants and frost line (migration).
	for i in range(len(orbit_list)):
		if orbit_list[i] < main_star["zone_margins"][0]:
			if planet_list[i]["type"] == "sub giant" or \
			planet_list[i]["type"] == "giant" or \
			planet_list[i]["type"] == "super giant":
				
				k = i + 1# start checking planets ahead of i.
				k_max = len(orbit_list) - 1
				if k < k_max - i - 1:
					while orbit_list[k] < main_star["zone_margins"][0] and k < k_max:
						# Remove all the small planets.
						if planet_list[k]["type"] == "sub dwarf" or \
						planet_list[k]["type"] == "dwarf" or \
						planet_list[k]["type"] == "super dwarf" or \
						planet_list[k]["type"] == "sub terrestrial" or \
						planet_list[k]["type"] == "terrestrial" or \
						planet_list[k]["type"] == "super terrestrial": 
							
							planet_list[k]["type"] = "- empty orbit -"
							planet_list[k]["mass"] = 0
							planet_list[k]["size"] = 0
							hill_radii_list[k] = 0
							
						k += 1
					
	# Check for intersecting HR.
	for i in range(len(orbit_list)-1):
		# Find the distance between neighbiring orbits.
		orbit_distance = orbit_list[i+1] - orbit_list[i]
		# Get respective Hill radii.
		hr1 = hill_radii_list[i]
		hr2 = hill_radii_list[i+1]
		# Check if Hill radii overlap within said orbits.
		if (hill_radii_stability_multiplier*hr1 + hill_radii_stability_multiplier*hr2) > orbit_distance:
			# print("Hill radii overlap:", planet_list[i]["type"], planet_list[i+1]["type"], e(hr1), e(hr2), e(orbit_distance))
			# Eject smaller planet.
			if planet_list[i]["mass"] < planet_list[i+1]["mass"]:
				planet_list[i]["type"] = "- empty orbit -"
				planet_list[i]["mass"] = 0
				planet_list[i]["size"] = 0
				hill_radii_list[i] = 0
			else:
				planet_list[i+1]["type"] = "- empty orbit -"
				planet_list[i+1]["mass"] = 0
				planet_list[i+1]["size"] = 0
				hill_radii_list[i+1] = 0
	
	return planet_list


def generate_semi_major_axes(N, Lmin, Lmax, resonance_ratio):
	semi_major_axes = [Lmin]  # Start with the minimum distance as the first orbit
	
	# print("Initial orbit ranges:", "Lmin:", round(Lmin/sun_distance_au, 3), "Lmax", round(Lmax/sun_distance_au, 3), "AU")

	for i in range(1, N):
		prev_axis = semi_major_axes[i-1]
		semi_major_axis = prev_axis * resonance_ratio
		semi_major_axes.append(semi_major_axis)

	# Scale the semi-major axes to fit within the desired range (Lmin to Lmax)
	range_span = Lmax - Lmin
	axes_span = max(semi_major_axes) - min(semi_major_axes)
	scaling_factor = range_span / axes_span
	if scaling_factor < 1.0:
		scaling_factor = 1.0
	semi_major_axes = [axis * scaling_factor for axis in semi_major_axes]

	return semi_major_axes
	

def get_planet_temperature_list(orbit_list, planet_list, main_star):
	# flux = sigma * T^4
	# T = (flux / sigma)^(1/4)
	# zones : type
	#	> star_frost_line		:	icy
	#	< star_frost_line		:	cold
	#	< star_temperate_zone	:	temperate
	#	< star_warm_zone		:	warm
	#	< star_hot_zone			:	hot
	#	< star_dust_melting		:	very hot
	#	< star_death_zone		:	evaporated
	
	temperature_list = []
	temperature_type = ""
	
	
	for i in range(len(orbit_list)):
		current_orbit = orbit_list[i]
		# Get the flux and temperature at said orbit.
		orbit_flux = main_star["luminosity"] / (4 * 3.14 * current_orbit * current_orbit)
		orbit_temperature = round(pow((orbit_flux / SB_sigma), 0.25), 2)
		orbit_temperature_c = round(orbit_temperature - 273.15, 2)
		
		if current_orbit < main_star["zone_margins"][5]:
			temperature_type = "evaporated"
		elif current_orbit < main_star["zone_margins"][4]:
			temperature_type = "very hot"	
		elif current_orbit < main_star["zone_margins"][3]:
			temperature_type = "hot"	
		elif current_orbit < main_star["zone_margins"][2]:
			temperature_type = "warm"	
		elif current_orbit < main_star["zone_margins"][1]:
			temperature_type = "temperate"	
		elif current_orbit < main_star["zone_margins"][0]:
			temperature_type = "cold"	
		elif current_orbit > main_star["zone_margins"][0]:
			temperature_type = "icy"

		# print(planet_list[i]["type"],temperature_type, round(current_orbit/sun_distance_au, 3), "AU,", "t.:", orbit_temperature, "K,", orbit_temperature_c, "C")

		temperature_list.append((temperature_type, orbit_temperature))

	return temperature_list


def get_planet_atmosphere(planet_list, temperature_list):
	return
	#for i in range(len(planet_list)):
		#if temperature_list[0][i] == 






########### STAR GENERATION #############

def make_star(user_defined_type, primary_star_type):
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
	star_type_temp = -1
	star_type_id = -1 # For further sorting.
	star_size = 0
	star_lum = 0
	star_temp = 0
	star_temp_norm = 0
	
	# If the star is secondary - limit its class according to primary star.
	r = random_star_abundance.random()
	if user_defined_type :
		star_type = user_defined_type[0]
		star_type_temp = user_defined_type[1]
	else:
		# For secondary stars (if primary exists).
		if primary_star_type:
			if r < star_o_abundance and primary_star_type[0] == 'O' and primary_star_type[1] > 0:
				star_type = ("O")
				star_type_id = 6
			elif r < star_b_abundance and primary_star_type \
				and (primary_star_type[0] == 'O' or (primary_star_type[0] == 'B' and primary_star_type[1] > 0)):
				star_type = ("B")
				star_type_id = 5
			elif r < star_a_abundance and primary_star_type \
				and (primary_star_type[0] == 'O' or primary_star_type[0] == 'B' or (primary_star_type[0] == 'A' and primary_star_type[1] > 0)):
				star_type = ("A")
				star_type_id = 4
			elif r < star_f_abundance and primary_star_type \
				and (primary_star_type[0] == 'O' or primary_star_type[0] == 'B' or primary_star_type[0] == 'A' \
					or (primary_star_type[0] == 'F' and primary_star_type[1] > 0)):
				star_type = ("F")
				star_type_id = 3
			elif r < star_g_abundance and primary_star_type \
				and (primary_star_type[0] == 'O' or primary_star_type[0] == 'B' or primary_star_type[0] == 'A' \
					or primary_star_type[0] == 'F' or (primary_star_type[0] == 'G' and primary_star_type[1] > 0)):
				star_type = ("G")
				star_type_id = 2
			elif r < star_k_abundance and primary_star_type \
				and (primary_star_type[0] == 'O' or primary_star_type[0] == 'B' or primary_star_type[0] == 'A' \
					or primary_star_type[0] == 'F' or primary_star_type[0] == 'G' or (primary_star_type[0] == 'K' and primary_star_type[1] > 0)):
				star_type = ("K")
				star_type_id = 1
			elif r <= star_m_abundance  and primary_star_type \
				and (primary_star_type[0] == 'O' or primary_star_type[0] == 'B' or primary_star_type[0] == 'A' \
					or primary_star_type[0] == 'F' or primary_star_type[0] == 'G' or primary_star_type[0] == 'K' \
					or primary_star_type[0] == 'M'): # Allows M9 star systems.
				star_type = ("M")
				star_type_id = 0
			else:
				star_type = ("Other")
				star_type_id = -1
		
		# For primary stars:
		else:
			if r < star_o_abundance :
				star_type = ("O")
				star_type_id = 6
			elif r < star_b_abundance :
				star_type = ("B")
				star_type_id = 5
			elif r < star_a_abundance :
				star_type = ("A")
				star_type_id = 4
			elif r < star_f_abundance :
				star_type = ("F")
				star_type_id = 3
			elif r < star_g_abundance :
				star_type = ("G")
				star_type_id = 2
			elif r < star_k_abundance :
				star_type = ("K")
				star_type_id = 1
			elif r <= star_m_abundance  :
				star_type = ("M")
				star_type_id = 0
			else:
				star_type = ("Other")
				star_type_id = -1
		
	# Make sure that if the star is secondary - it is less or equally bright than primary if in the same class.
	if primary_star_type and (star_type == primary_star_type[0]):
		star_type_temp = random_star_val.randint(int(primary_star_type[1]), 9)
		
	if star_type == "O":
		total_number_o_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_o_size_min), int(star_o_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_o_temp_min), int(star_o_temp_max))
		else:
			star_o_temp_min_type = (star_o_temp_max - star_o_temp_min) / 10 * (9-star_type_temp) + star_o_temp_min
			star_o_temp_max_type = (star_o_temp_max - star_o_temp_min) / 10 * (9-star_type_temp + 1) + star_o_temp_min
			star_temp = random_star_val.randrange(int(star_o_temp_min_type), int(star_o_temp_max_type))
		star_temp_norm = (star_temp - star_o_temp_min) / (star_o_temp_max - star_o_temp_min)
	elif star_type == "B":
		total_number_b_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_b_size_min), int(star_b_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_b_temp_min), int(star_b_temp_max))
		else:
			star_b_temp_min_type = (star_b_temp_max - star_b_temp_min) / 10 * (9-star_type_temp) + star_b_temp_min
			star_b_temp_max_type = (star_b_temp_max - star_b_temp_min) / 10 * (9-star_type_temp + 1) + star_b_temp_min
			star_temp = random_star_val.randrange(int(star_b_temp_min_type), int(star_b_temp_max_type))
		star_temp_norm = (star_temp - star_b_temp_min) / (star_b_temp_max - star_b_temp_min)
	elif star_type == "A":
		total_number_a_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_a_size_min), int(star_a_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_a_temp_min), int(star_a_temp_max))
		else:
			star_a_temp_min_type = (star_a_temp_max - star_a_temp_min) / 10 * (9-star_type_temp) + star_a_temp_min
			star_a_temp_max_type = (star_a_temp_max - star_a_temp_min) / 10 * (9-star_type_temp + 1) + star_a_temp_min
			star_temp = random_star_val.randrange(int(star_a_temp_min_type), int(star_a_temp_max_type))
		star_temp_norm = (star_temp - star_a_temp_min) / (star_a_temp_max - star_a_temp_min)
	elif star_type == "F":
		total_number_f_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_f_size_min), int(star_f_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_f_temp_min), int(star_f_temp_max))
		else:
			star_f_temp_min_type = (star_f_temp_max - star_f_temp_min) / 10 * (9-star_type_temp) + star_f_temp_min
			star_f_temp_max_type = (star_f_temp_max - star_f_temp_min) / 10 * (9-star_type_temp + 1) + star_f_temp_min
			star_temp = random_star_val.randrange(int(star_f_temp_min_type), int(star_f_temp_max_type))
		star_temp_norm = (star_temp - star_f_temp_min) / (star_f_temp_max - star_f_temp_min)
	elif star_type == "G":
		total_number_g_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_g_size_min), int(star_g_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_g_temp_min), int(star_g_temp_max))
		else:
			star_g_temp_min_type = (star_g_temp_max - star_g_temp_min) / 10 * (9-star_type_temp) + star_g_temp_min
			star_g_temp_max_type = (star_g_temp_max - star_g_temp_min) / 10 * (9-star_type_temp + 1) + star_g_temp_min
			star_temp = random_star_val.randrange(int(star_g_temp_min_type), int(star_g_temp_max_type))
		star_temp_norm = (star_temp - star_g_temp_min) / (star_g_temp_max - star_g_temp_min)
	elif star_type == "K":
		total_number_k_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_k_size_min), int(star_k_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_k_temp_min), int(star_k_temp_max))
		else:
			star_k_temp_min_type = (star_k_temp_max - star_k_temp_min) / 10 * (9-star_type_temp) + star_k_temp_min
			star_k_temp_max_type = (star_k_temp_max - star_k_temp_min) / 10 * (9-star_type_temp + 1) + star_k_temp_min
			star_temp = random_star_val.randrange(int(star_k_temp_min_type), int(star_k_temp_max_type))
		star_temp_norm = (star_temp - star_k_temp_min) / (star_k_temp_max - star_k_temp_min)
	elif star_type == "M":
		total_number_m_stars += 1
		total_number_all_stars += 1
		star_size = random_star_val.randrange(int(star_m_size_min), int(star_m_size_max))
		if star_type_temp == -1:
			star_temp = random_star_val.randrange(int(star_m_temp_min), int(star_m_temp_max))
		else:
			star_m_temp_min_type = (star_m_temp_max - star_m_temp_min) / 10 * (9-star_type_temp) + star_m_temp_min
			star_m_temp_max_type = (star_m_temp_max - star_m_temp_min) / 10 * (9-star_type_temp + 1) + star_m_temp_min
			star_temp = random_star_val.randrange(int(star_m_temp_min_type), int(star_m_temp_max_type))
		star_temp_norm = (star_temp - star_m_temp_min) / (star_m_temp_max - star_m_temp_min)
	else:
		total_number_other_stars += 1
		total_number_all_stars += 1
	
	star_type_temp = 9 - int(star_temp_norm*10)
	star_lum = get_strar_lum(star_size, star_temp)
	star_peak_wavelength = get_strar_peak_wavelength(star_temp)
	star_mass = get_star_mass(star_type, star_type_temp)
	
	# Godot parameters.
	star_omni_range = pow(star_lum/star_omni_ratio, 0.5)
	star_zone_margins = get_star_zone_margins(star_lum)
	
	star = {
		"type" : (star_type, star_type_temp, star_type_id),
		"size" : star_size,
		"mass" : star_mass,
		"luminosity" : star_lum,
		"temperature" : star_temp,
		"peak_wavelength":  star_peak_wavelength[0],
		"peak_wavelength_type":  star_peak_wavelength[1],
		"peak_wavelength_colorcode":  star_peak_wavelength[2],
		"omni_range": star_omni_range,
		"zone_margins": star_zone_margins,
	}
	
	return star

def get_star_zone_margins(star_lum):
	# Star death zone corresponds to  afistance where ship with coating should start to melt.
	star_death_zone =  pow(star_lum / (4 * 3.14 * melting_flux_average), 0.5)
	star_hot_zone = pow(star_lum /(4 * 3.14 * flux_hot_zone), 0.5)
	star_warm_zone = pow(star_lum /(4 * 3.14 * flux_warm_zone), 0.5)
	star_temperate_zone = pow(star_lum /(4 * 3.14 * flux_temperate_zone), 0.5)
	star_cold_zone = pow(star_lum /(4 * 3.14 * flux_cold_zone), 0.5)
	star_frost_line = pow(star_lum /(4 * 3.14 * flux_frost_line), 0.5)
	star_dust_melting = pow(star_lum /(4 * 3.14 * flux_dust_melting), 0.5)
	return (star_frost_line, star_cold_zone, star_temperate_zone, star_warm_zone, star_hot_zone, star_dust_melting, star_death_zone)
	
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
		palette_index = (len(palettes.spectrum_palette)-1) - int(wl_norm*(len(palettes.spectrum_palette)-1)) # reverse spectrum.
		peak_wavelength_colorcode = palettes.spectrum_palette[palette_index]
		
	return (peak_wavelength, peak_wavelength_type, peak_wavelength_colorcode)


def random_star_number():
	num = int(
		pow(random_star_num.random(), 1.5) \
		* random_star_num.randint(num_stars_min, num_stars_max))
	return num

def get_star_mass(star_type, star_type_temp):
	star_mass = 0
	if star_type == "O":
		star_o_mass_min_type = (star_o_mass_max - star_o_mass_min) / 10 * (9-star_type_temp) + star_o_mass_min
		star_o_mass_max_type = (star_o_mass_max - star_o_mass_min) / 10 * (9-star_type_temp + 1) + star_o_mass_min
		star_mass = random_star_val.uniform((star_o_mass_min_type), (star_o_mass_max_type))
	elif star_type == "B":
		star_b_mass_min_type = (star_b_mass_max - star_b_mass_min) / 10 * (9-star_type_temp) + star_b_mass_min
		star_b_mass_max_type = (star_b_mass_max - star_b_mass_min) / 10 * (9-star_type_temp + 1) + star_b_mass_min
		star_mass = random_star_val.uniform((star_b_mass_min_type), (star_b_mass_max_type))
	elif star_type == "A":
		star_a_mass_min_type = (star_a_mass_max - star_a_mass_min) / 10 * (9-star_type_temp) + star_a_mass_min
		star_a_mass_max_type = (star_a_mass_max - star_a_mass_min) / 10 * (9-star_type_temp + 1) + star_a_mass_min
		star_mass = random_star_val.uniform((star_a_mass_min_type), (star_a_mass_max_type))
	elif star_type == "F":
		star_f_mass_min_type = (star_f_mass_max - star_f_mass_min) / 10 * (9-star_type_temp) + star_f_mass_min
		star_f_mass_max_type = (star_f_mass_max - star_f_mass_min) / 10 * (9-star_type_temp + 1) + star_f_mass_min
		star_mass = random_star_val.uniform((star_f_mass_min_type), (star_f_mass_max_type))
	elif star_type == "G":
		star_g_mass_min_type = (star_g_mass_max - star_g_mass_min) / 10 * (9-star_type_temp) + star_g_mass_min
		star_g_mass_max_type = (star_g_mass_max - star_g_mass_min) / 10 * (9-star_type_temp + 1) + star_g_mass_min
		star_mass = random_star_val.uniform((star_g_mass_min_type), (star_g_mass_max_type))
	elif star_type == "K":
		star_k_mass_min_type = (star_k_mass_max - star_k_mass_min) / 10 * (9-star_type_temp) + star_k_mass_min
		star_k_mass_max_type = (star_k_mass_max - star_k_mass_min) / 10 * (9-star_type_temp + 1) + star_k_mass_min
		star_mass = random_star_val.uniform((star_k_mass_min_type), (star_k_mass_max_type))
	elif star_type == "M":
		star_m_mass_min_type = (star_m_mass_max - star_m_mass_min) / 10 * (9-star_type_temp) + star_m_mass_min
		star_m_mass_max_type = (star_m_mass_max - star_m_mass_min) / 10 * (9-star_type_temp + 1) + star_m_mass_min
		star_mass = random_star_val.uniform((star_m_mass_min_type), (star_m_mass_max_type))

	return star_mass*sun_mass



######## NAME GENERATOR ##########

# Quantity according to frequency
# https://www3.nd.edu/~busiforc/handouts/cryptography/letterfrequencies.html
chars_low_v = "y"+"u"*2+"oi"*4+"a"*5+"e"*6
chars_low_c = "qjzx"+"vk"*5+"w"*7+"f"*9+"b"*11\
	+"g"*12+"hm"*15+"p"*16+"d"*17+"c"*23+"l"*28\
	+"s"*29+"n"*34+"t"*35+"r"*39

chars_low_c = ''.join(random_char.sample(chars_low_c,len(chars_low_c)))
chars_low_v = ''.join(random_char.sample(chars_low_v,len(chars_low_v)))

ABC = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z']


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









######### FORMATTING FUNCTIONS ############

def formatting_system_data(star_id, system, main_star, star_name):
	star_type = main_star["type"]
	system_zone_size = e(main_star["omni_range"]) # use omni range instead.
	if float(system_zone_size) < system_zone_size_min:
		system_zone_size = e(system_zone_size_min)
		
	system_autopilot_range = system_zone_size
	
	# Temperature zoning.
	star_zone_margins = main_star["zone_margins"]
	star_dust_melting = round(star_zone_margins[5] / sun_distance_au, 3)
	star_hot_zone = round(star_zone_margins[4] / sun_distance_au, 3)
	star_warm_zone = round(star_zone_margins[3] / sun_distance_au, 3)
	star_temperate_zone = round(star_zone_margins[2] / sun_distance_au, 3)
	star_cold_zone = round(star_zone_margins[1] / sun_distance_au, 3)
	star_frost_line = round(star_zone_margins[0] / sun_distance_au, 3)
	
	p = ''
	p += "# System: " + star_name + "  \n"
	
	p += "<details><summary>" \
		+ "System data" \
		+  "</summary>" + "  \n\n"
		
	p += "#### System Infocard data"+ "  \n"
		
	p += "```" + "  \n"
	
	p += "Temperature zone data by main star:"+ "\n"
	p += "* Mineral melting line:"+ " < " + str(star_dust_melting) + " AU" + "\n"
	p += "* Hot zone   :"+ "   " + str(star_dust_melting) + " ... " + str(star_hot_zone) + " AU" + "\n"
	p += "* Warm zone  :"+ "   " + str(star_hot_zone) + " ... " + str(star_warm_zone) + " AU" + "\n"
	p += "* Temp. zone :"+ "   " + str(star_warm_zone) + " ... " + str(star_temperate_zone) + " AU" + "\n"
	p += "* Cold zone  :"+ "   " + str(star_temperate_zone) + " ... " + str(star_frost_line) + " AU" + "\n"
	p += "* Frost line :" + " > " + str(star_frost_line) + " AU" + "\n"
	p += "```" + "  \n"
	
	p += "```" + "  \n"
	p += "Дані температурного зонування відносно основної зірки:"+ "\n"
	p += "* Межа плавлення мінералів:"+ " < " + str(star_dust_melting) + " а.о." + "\n"
	p += "* Гаряча зона  :"+ "   " + str(star_dust_melting) + " ... " + str(star_hot_zone) + " а.о." + "\n"
	p += "* Тепла зона   :"+ "   " + str(star_hot_zone) + " ... " + str(star_warm_zone) + " а.о." + "\n"
	p += "* Помірна зона :"+ "   " + str(star_warm_zone) + " ... " + str(star_temperate_zone) + " а.о." + "\n"
	p += "* Холодна зона :"+ "   " + str(star_temperate_zone) + " ... " + str(star_cold_zone) + " а.о." + "\n"
	p += "* Межа кригоутворення :" + " > " + str(star_frost_line) + " а.о." + "\n"
	
	p += "```" + "  \n"
	
	p += "#### GODOT data"+ "  \n"
	
	p += "```" + "  \n"
	p += "* System ID: " + str(star_id) + "\n"
	
	if "cluster" in system:
		p += "* Star cluster: " + system["cluster"] + "\n"
	else:
		p += "* Star cluster: unspecified" + "\n"
	
	p += "* System zone codename: " + "STAR_" + str(star_id) + "_SYSTEM_ZONE" + "\n"
	p += "* System codename: " + "STAR_" +  str(star_id) + "_SYSTEM" + "\n"
	p += "* System translation name codename: " + "NAME_STAR_" + str(star_id) + "_SYSTEM" + "\n"
	p += "* System translation description codename: " + "DESC_STAR_" + str(star_id) + "_SYSTEM" + "\n"
	p += "* System name: " + star_name  + "\n"
	p += "* System description: see above. Optionally add lore." + "\n"
	p += "* System zone size: " + str(system_zone_size) + "\n"
	p += "* System autopilot range: " + str(system_autopilot_range) + "\n"

	p += "```" + "\n"
	p += "\n </details>" + "  \n"
	
	p += "\n---  \n"
	
	return p



def formatting_star_data(star_id, primary, main_star, star_name):
	p = ''
	
	if primary:
		star_in_system_hierarchy = "Primary star"
	else:
		star_in_system_hierarchy = "Secondary star"
	
	star_type = main_star["type"]
	# Format star size.
	star_size = e(main_star["size"])
	star_size_rel = round(main_star["size"] / sun_diameter, 3)
	
	star_mass = e(main_star["mass"])
	star_mass_rel = round(main_star["mass"] / sun_mass, 3)
	
	
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
		
	# temperature values.
	star_temp = round(main_star["temperature"])
	star_temp_rel = round(main_star["temperature"] / sun_temperature, 2)
	star_zone_margins = main_star["zone_margins"]
	star_death_zone_size = star_zone_margins[6]

	# If star death zone is too small, tweak it.
	if star_death_zone_size < (star_death_zone_min_factor * float(star_size)):
		star_death_zone_size = star_death_zone_min_factor * float(star_size)
	
	# Death zone values.
	star_death_zone = round(star_death_zone_size / sun_distance_au, 3)
	star_death_zone_meters = e(star_death_zone_size)
	
	# Make zone size larger than death zone, if it is smaller.
	star_zone_size = e(star_zone_size_factor * float(star_size))
	if (star_zone_size_factor * float(star_size)) < star_death_zone_size:
		star_zone_size = e(star_death_zone_size * star_zone_size_by_death_zone_factor)
	
	# Auopilot approach range, limited by death zone + comfortable margin.
	star_autopilot_range = e(star_death_zone_size  * star_autopilot_factor)
	
	# Sprite flare distance, handy to depict the entrance to star zone.
	star_flare_distance = e(float(star_zone_size)  * star_flare_factor)
	
	
	
	# Wavelength data.
	star_peak_wavelength = round(main_star["peak_wavelength"], 0)
	star_peak_wavelength_type = main_star["peak_wavelength_type"]
	star_peak_wavelength_colorcode = main_star["peak_wavelength_colorcode"]
	star_peak_wavelength_colorcode_hex = rgb_to_hex(star_peak_wavelength_colorcode)
	star_omni_range = e(main_star["omni_range"])
	
	
	color_sample = "![" + str(star_peak_wavelength_colorcode_hex)  + "]" \
		+ "(Colors/" + str(star_peak_wavelength_colorcode_hex)  + ".png)"
		
	p += "<details><summary>" \
		+ star_in_system_hierarchy  + " : " \
		+ star_name + ", type: " \
		+ star_type[0] + str(star_type[1]) \
		+  "</summary>" + "  \n\n"
	
	p += "#### Star pseudo-color" + "  \n"

	p += color_sample + "  \n"
	
	p += "#### Star Infocard data"+ "  \n"
	
	p += "```" + "  \n"
	
	p += "Absolute units:" + "\n"
	p += "* Size: " + str(star_size) + " m" + "\n"
	p += "* Mass: " + str(star_mass) + " kg" + "\n"
	p += "* Temperature: " + str(star_temp) + " K" + "\n"
	p += "* Luminosity: " + str(star_lum) + " W" + "\n"*2
	
	p += "Sun-relative units:" + "\n"
	p += "* Size: " + str(star_size_rel) + " D" + "\n"
	p += "* Mass: " + str(star_mass_rel) + " M" + "\n"
	p += "* Temperature: " + str(star_temp_rel) + " T" + "\n"
	p += "* Luminosity: " + str(star_lum_rel) + " L" + "\n"*2
	
	p += "Spectral data:"+ "\n"
	p += "* Type: " + star_type[0] + str(star_type[1]) + "\n"
	p += "* Peak wavelength: " + str(star_peak_wavelength) + " nm"+ "\n"
	p += "* Peak wavelength type: " + star_peak_wavelength_type + "\n"*2
	p += "```" + "  \n"
	
	
	p += "```" + "  \n"
	p += "Абсолютні величини:" + "\n"
	p += "* Розмір: " + str(star_size) + " м" + "\n"
	p += "* Маса: " + str(star_mass) + " кг" + "\n"
	p += "* Температура: " + str(star_temp) + " К" + "\n"
	p += "* Світність: " + str(star_lum) + " Вт" + "\n"*2
	
	p += "Величини відносно Сонця:" + "\n"
	p += "* Розмір: " + str(star_size_rel) + " D" + "\n"
	p += "* Маса: " + str(star_mass_rel) + " M" + "\n"
	p += "* Температура: " + str(star_temp_rel) + " T" + "\n"
	p += "* Світність: " + str(star_lum_rel) + " L" + "\n"*2
	
	p += "Спектральні дані:"+ "\n"
	p += "* Тип: " + star_type[0] + str(star_type[1]) + "\n"
	p += "* Пікова довжина хвилі: " + str(star_peak_wavelength) + " нм"+ "\n"
	p += "* Тип пікового випромінювання: " + star_peak_wavelength_type + "\n"*2
	
	p += "```" + "  \n"
	
	p += "#### GODOT data"+ "  \n"
	
	p += "```" + "  \n"
	
	p += "* Star zone codename: " + "STAR_" + str(star_id) + "_ZONE" + "\n"
	p += "* Star codename: " + "STAR_" + str(star_id)  + "\n"
	p += "* Star translation name codename: " + "NAME_STAR_" + str(star_id)  + "\n"
	p += "* Star translation description codename: " + "DESC_STAR_" +  str(star_id) + "\n"
	p += "* Star name: " + star_name  + "\n"
	p += "* Star description: see above." + "\n"
	p += "* Star zone size: " + str(star_zone_size) + "\n"
	p += "* Star death zone size: " + str(star_death_zone_meters) + "\n"
	p += "* Star size: " + str(star_size) + "\n"
	p += "* Star flare distance: " + str(star_flare_distance) + "\n"
	p += "* Star autopilot range: " + str(star_autopilot_range) + "\n"
	
	p += "\n"
	
	p += "* Omni range: " + str(star_omni_range) + "\n"
	p += "* Omni attenuation: " + str(sun_omni_attenuation) + "\n"
	p += "* Omni energy: " + str(sun_omni_energy) + "\n"
	p += "* Surface color (Peak w.l. color code):" + "\n"
	p += " - rgb: " + str(star_peak_wavelength_colorcode) + "\n"
	p += " - hex: #" + str(star_peak_wavelength_colorcode_hex) + "\n"
	
	p += "```" + "  \n"
	
	p += "\n </details>" + "  \n"
	
	p += "\n---  \n"
	
	return (p, color_sample)


def formatting_planet_data(star_name, star_type, planetary_data):
	p =""
	
	for i in range(len(planetary_data)):
		planet = planetary_data[i]
		planet_order_letter = ABC[i].lower()
		
		#"type"
		#"size"
		#"mass"
		#"zone_margins" [planet_zone_size, planet_death_zone]
		#"orbit"
		#"temperature_type"
		#"temperature" [temperature_type, orbit_temperature]
		
		# Re-assigning those for the sake of tweking the terminology.
		planet_type = planet["type"]
		planet_type_ua = ""
		if planet_type == "sub dwarf":
			planet_type_ua = "мала карликова планета"
		elif planet_type == "dwarf":
			planet_type_ua = "карликова планета"
		elif planet_type == "super dwarf":
			planet_type_ua = "велика карликова планета"
		elif planet_type == "sub terrestrial":
			planet_type_ua = "мала землеподібна планета"
		elif planet_type == "terrestrial":
			planet_type_ua = "землеподібна планета"
		elif planet_type == "super terrestrial":
			planet_type_ua = "велика землеподібна планета"
		elif planet_type == "sub giant":
			planet_type_ua = "планета малий гігант"
		elif planet_type == "giant":
			planet_type_ua = "планета гігант"
		elif planet_type == "super giant":
			planet_type_ua = "планета великий гігант"
			
		planet_type_en = ""
		if planet_type == "sub dwarf":
			planet_type_en = "small dwarf planet"
		elif planet_type == "dwarf":
			planet_type_en = "dwarf planet"
		elif planet_type == "super dwarf":
			planet_type_en = "large dwarf planet"
		elif planet_type == "sub terrestrial":
			planet_type_en = "small terrestrial planet"
		elif planet_type == "terrestrial":
			planet_type_en = "terrestrial planet"
		elif planet_type == "super terrestrial":
			planet_type_en = "large terrestrial planet"
		elif planet_type == "sub giant":
			planet_type_en = "small giant planet"
		elif planet_type == "giant":
			planet_type_en = "giant planet"
		elif planet_type == "super giant":
			planet_type_en = "large giant planet"
			
		planet_temperature_type = planet["temperature_type"]
		if planet_temperature_type == "evaporated":
			planet_temperature_type_ua = "планета, що випаровується"
		elif planet_temperature_type == "very hot":
			planet_temperature_type_ua = "дуже гаряча"
		elif planet_temperature_type == "hot":
			planet_temperature_type_ua = "гаряча"
		elif planet_temperature_type == "warm":	
			planet_temperature_type_ua = "тепла"
		elif planet_temperature_type == "temperate":	
			planet_temperature_type_ua = "помірна"
		elif planet_temperature_type == "cold":	
			planet_temperature_type_ua = "холодна"
		elif planet_temperature_type == "icy":
			planet_temperature_type_ua = "льодяна"
		
				
		planet_orbit = e(planet["orbit"])
		planet_orbit_au = round(planet["orbit"] / sun_distance_au, 3)
		planet_temperature_abs = round(planet["temperature"], 2)
		planet_temperature_celsius =  round(planet["temperature"] - 273.15, 2)
		# Size is diameter.
		planet_size = e(planet["size"])
		planet_size_earth = round(planet["size"] / (earth_radius * 2), 3)
		planet_mass = e(planet["mass"])
		planet_mass_earth = round(planet["mass"] / earth_mass, 5)
		# Godot data
		planet_zone_size = e(planet["zone_margins"][0])
		planet_death_zone = e(planet["zone_margins"][1])
		planet_autopilot_range = e(planet_autopilot_factor*planet["zone_margins"][1])

		p += "<details><summary>" \
			+ "Planet " \
			+ star_name + " " + planet_order_letter \
			+ " (" + str(planet_temperature_type) + " " + str(planet_type_en) + ")" \
			+  "</summary>" + "  \n\n"
		
		p += "#### Planet albedo" + "  \n"
	
		p += "WIP" + "  \n"
		
		p += "#### Planet Infocard data"+ "  \n"
		
		p += "```" + "  \n"
		p += "Planet type: " + str(planet_temperature_type + " " + planet_type_en) + "\n"*2
		
		p += "Absolute units:" + "\n"
		p += "* Size: " + str(planet_size) + " m" + "\n"
		p += "* Mass: " + str(planet_mass) + " kg" + "\n"
		p += "* Temperature: " + str(planet_temperature_abs) + " K" + "\n"
		p += "* Orbit semi-major axis: " + str(planet_orbit) + " m" + "\n"*2
		
		p += "Earth-relative units:" + "\n"
		p += "* Size: " + str(planet_size_earth) + " D" + "\n"
		p += "* Mass: " + str(planet_mass_earth) + " M" + "\n"
		p += "* Temperature: " + str(planet_temperature_celsius) + " C" + "\n"
		p += "* Orbit semi-major axis: " + str(planet_orbit_au) + " AU" + "\n"*2
		p += "```" + "  \n"
		
		p += "```" + "  \n"
		p += "Тип планети: " + str(planet_temperature_type_ua + " " + planet_type_ua) + "\n"*2
		
		p += "Абсолютні величини:" + "\n"
		p += "* Розмір: " + str(planet_size) + " м" + "\n"
		p += "* Маса: " + str(planet_mass) + " кг" + "\n"
		p += "* Температура: " + str(planet_temperature_abs) + " К" + "\n"
		p += "* Велика піввісь орбіти: " + str(planet_orbit) + " м" + "\n"*2
		
		p += "Величини відносно Землі:" + "\n"
		p += "* Розмір: " + str(planet_size_earth) + " D" + "\n"
		p += "* Маса: " + str(planet_mass_earth) + " M" + "\n"
		p += "* Температура: " + str(planet_temperature_celsius) + " C" + "\n"
		p += "* Велика піввісь орбіти: " + str(planet_orbit_au) + " а.о." + "\n"*2
		p += "```" + "  \n"
		
		p += "#### GODOT data"+ "  \n"
		
		p += "```" + "  \n"
		
		p += "* Planet zone codename: " + "STAR_" + str(star_id) + "_PLANET_" + str(i) + "_ZONE" + "\n"
		p += "* Planet codename: " + "STAR_"  + str(star_id)  + "_PLANET_" + str(i) + "\n"
		p += "* Planet translation name codename: " + "NAME_STAR_" + str(star_id)  + "_PLANET_" + str(i) + "\n"
		p += "* Planet translation description codename: " + "DESC_STAR_" + str(star_id) + "_PLANET_" + str(i)  + "\n"
		p += "* Planet name: " + star_name + " " + planet_order_letter + "\n"
		p += "* Planet description: see above." + "\n"
		p += "* Planet zone size: " + str(planet_zone_size) + "\n"
		p += "* Planet death zone size: " + str(planet_death_zone) + "\n"
		p += "* Planet size: " + str(planet_size) + "\n"
		p += "* Planet autopilot range: " + str(planet_autopilot_range) + "\n"
		p += "* Planet semi-major axis: " + str(planet_orbit) + "\n"		

		p += "\n"
		
		p += "* Surface color (albedo):" + "\n"
		p += " - rgb: " + "WIP" + "\n"
		p += " - hex: #" + "WIP" + "\n"
		
		p += "```" + "  \n"
		
		p += "\n </details>" + "  \n"
		
		p += "\n---  \n"
	

	return p

















################### GENERATE TEST ####################
print("Generation begin: FROM TEST PRESET")
for star_id in range(len(universe_test_presets.systems)):
	system_generation(star_id, universe_test_presets.systems[star_id], '')
			
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
print("Generation done: Universe/Universe_test.md")
print()


f = open(cwd + "/Doc/Universe/Universe_test.md", "w")
f.write(output)
f.close()
#print(output)
	


################### GENERATE PRESET ###################
# Reset generators in order to not to affect new entities.
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

print("Generation begin: FROM PRESET")
for star_id in range(len(universe_presets.systems)):
	system_generation(star_id, universe_presets.systems[star_id], '')
			
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



###################### GENERATE RANDOM ####################
# Reset generators in order to not to affect new entities.
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
for cluster in universe_presets.clusters:
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
