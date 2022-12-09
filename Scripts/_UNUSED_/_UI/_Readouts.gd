extends Node

func get_magnitude_units(val):
	if val < 1:
		return [stepify(val*1e3, 0.1), "mm"]
	elif (val >= 1) and (val < 1e3):
		return [stepify(val, 0.1), "m"]
	elif (val >= 1e3) and (val < 1e6):
		return [stepify(val/1e3, 0.1), "km"]
	elif (val >= 1e6) and (val < 1e9):
		return [stepify(val/1e6, 0.1), "Mm"]
	elif (val >= 1e9) and (val < 1e12):
		return [stepify(val/1e9, 0.1), "Gm"]
	elif (val >= 1e12) and (val < 1e15):
		return [stepify(val/1e12, 0.1), "Tm"]
	elif (val >= 1e15) and (val < 1e18):
		return [stepify(val/1e15, 0.1), "Pm"]
	elif (val >= 1e18) and (val < 1e21):
		return [stepify(val/1e18, 0.1), "Em"]
