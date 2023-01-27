extends Node

var stepify_to = 0.01

var accel_ticks = ""
var apparent_velocity = ""
var apparent_velocity_units = ""

func get_magnitude_units(val):
	if (val >= 0) and (val < 1e3):
		return [stepify(val, stepify_to), "m"]
	elif (val >= 1e3) and (val < 1e6):
		return [stepify(val/1e3, stepify_to), "km"]
	elif (val >= 1e6) and (val < 1e9):
		return [stepify(val/1e6, stepify_to), "Mm"]
	elif (val >= 1e9) and (val < 1e12):
		return [stepify(val/1e9, stepify_to), "Gm"]
	elif (val >= 1e12) and (val < 1e15):
		return [stepify(val/1e12, stepify_to), "Tm"]
	elif (val >= 1e15) and (val < 1e18):
		return [stepify(val/1e15, stepify_to), "Pm"]
	elif (val >= 1e18) and (val < 1e21):
		return [stepify(val/1e18, stepify_to), "Em"]
	else:
		return [stepify(val/1e21, stepify_to), "Zm"]
