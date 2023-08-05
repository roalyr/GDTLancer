# This script generates instances of "Local_space_system" nodes with coords
# generated in Gaussian (normal) distribution.

import re, random, collections

# Keep under 10k per batch.
system_number = 50000
mean = 0.0
deviation = 2.0

galaxy_size = [1440000004889509888, 287999994105954304, 1440000004889509888]

seed1 = 1
seed2 = 2
seed3 = 3

# Adding three different generators for the sake of consistency of distributions each way.

rng_x = random.Random(seed1)
rng_y = random.Random(seed2)
rng_z = random.Random(seed3)

ID = 0
file_body = ''
raw_dict = {}
ordered_dict = {}
sep = "-"
file_name = "../Data/TSCN/Main_galaxy_stars_50k.tscn"

if system_number > 100000:
	input('Too many systems, setting to 100000')
	system_number = 100000

# Create zones to spawn stellar systems in.
for system in range(system_number):

	# Make up a position. (Multiply by 0.5 because 5 sigma range).
	pos_x = (rng_x.gauss(mean, deviation)*0.2)*galaxy_size[0]
	pos_y = (rng_y.gauss(mean, deviation)*0.2)*galaxy_size[1]
	pos_z = (rng_z.gauss(mean, deviation)*0.2)*galaxy_size[2]
	pos = [pos_x, pos_y, pos_z]
	
	# Get relative position of the coordinates. Normalize.
	# There can be values less than 0 and more than 1. Mark them.
	rel_x = (pos_x/galaxy_size[0]+1)/2
	rel_y = (pos_y/galaxy_size[1]+1)/2
	rel_z = (pos_z/galaxy_size[2]+1)/2
	rel_pos = [rel_x, rel_y, rel_z]
	#print(rel_pos)
	
	# Number of characters in English + 1 (In order to fit <= 1).
	N = 26
	UTF_offset = 65
	
	chr_x_1 = ""
	chr_x_2 = ""
	
	# X coordinate.
	# Assign first character to position.
	if rel_x >= 0 and rel_x <= 1:
		chr_x_1 = chr(int(rel_x*N) + UTF_offset)
	elif rel_x < 0:
		chr_x_1 = "(A)"
	elif rel_x > 1:
		chr_x_1 = "(Z)"

	# Assign second character to position.
	rel_x_2 = (rel_x * 10 % 1)
	if rel_x_2 >= 0 and rel_x_2 <= 1:
		chr_x_2 = chr(int(rel_x_2*N) + UTF_offset)
	
	# Assign third character to position.
	rel_x_3 = (rel_x * 100 % 1)
	chr_x_3 = str(int(rel_x_3*10)//1)

	# Combine.
	key_x = chr_x_1+chr_x_2+chr_x_3
	
	# Y coordinate.
	# Assign first character to position.
	if rel_y >= 0 and rel_y <= 1:
		chr_y_1 = chr(int(rel_y*N) + UTF_offset)
	elif rel_y < 0:
		chr_y_1 = "(A)"
	elif rel_y > 1:
		chr_y_1 = "(Z)"

	# Assign second character to position.
	rel_y_2 = (rel_y * 10 % 1)
	if rel_y_2 >= 0 and rel_y_2 <= 1:
		chr_y_2 = chr(int(rel_y_2*N) + UTF_offset)

	# Assign third character to position.
	rel_y_3 = (rel_y * 100 % 1)
	chr_y_3 = str(int(rel_y_3*10)//1)

	# Combine.
	key_y = chr_y_1+chr_y_2+chr_y_3
	
	# Z coordinate.
	# Assign first character to position.
	if rel_z >= 0 and rel_z <= 1:
		chr_z_1 = chr(int(rel_z*N) + UTF_offset)
	elif rel_z < 0:
		chr_z_1 = "(A)"
	elif rel_z > 1:
		chr_z_1 = "(Z)"

	# Assign second character to position.
	rel_z_2 = (rel_z * 10 % 1)
	if rel_z_2 >= 0 and rel_z_2 <= 1:
		chr_z_2 = chr(int(rel_z_2*N) + UTF_offset)

	# Assign third character to position.
	rel_z_3 = (rel_z * 100 % 1)
	chr_z_3 = str(int(rel_z_3*10)//1)

	# Combine.
	key_z = chr_z_1+chr_z_2+chr_z_3
	
	# Get the final key.
	key = key_x + sep + key_y + sep + key_z
	
	# Write data.
	raw_dict[key] = pos

# Sort list alphabetically.
ordered_dict = collections.OrderedDict(sorted(raw_dict.items()))

# Write the text and do preview output.
file_body += '[gd_scene format=2]\n\n[node name="Procedural_space" type="Position3D"]\n\n'

i = 0
for key, value in ordered_dict.items():
	print(i, key, value)
	i += 1
	

	str1 = '[node name="'+key+'" type="Position3D" parent="."]\n'
	str2 = 'transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, '+str(value[0])+', '+str(value[1])+', '+str(value[2])+')\n\n'
	
	file_body += str1+str2
	
	
print(file_body, file=open(file_name, "w"))

################################################################################	
#[gd_scene format=2]
#
#[node name="Procedural_space" type="Position3D"]
#
#[node name="Coordinates1" type="Position3D" parent="."]
#transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -0.769, -0.546, -0.989 )
#
#[node name="Coordinates2" type="Position3D" parent="."]
#transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -1.032, 0.879, -1.561 )
#
#[node name="Coordinates3" type="Position3D" parent="."]
#transform = Transform( 1, 0, 0, 0, 1, 0, 0, 0, 1, -0.111, 0.282, 0.52 )
#
	