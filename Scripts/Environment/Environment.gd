extends WorldEnvironment

# GLOBAL VALUES
export var global_brightness = 1.0
export var global_contrast = 1.0
export var global_saturation = 1.0

# Upper limit values so preserve your eyes.
var brightness_cap = 4.0
var contrast_cap = 2.0
var saturation_cap = 2.0

# Global rate of adjustment.
var refresh_rate = 0.05
var increment_step = 0.01

# Individual rates of change (mult. by physical delta).
var brightness_change_rate = 1e-2
var contrast_change_rate = 1e-2
var saturation_change_rate = 1e-2

# INTERNAL VALUES
# Connect to those variables from other scripts.
var brightness_variation = 0.0
var contrast_variation = 0.0
var saturation_variation = 0.0

# Ship velocity effects.
var warp_brightness_variation = 0.0
var warp_brightness_variation_prev = 0.0

# Summary variation
var zone_brightness_variation = 0.0
var zone_contrast_variation = 0.0
var zone_saturation_variation = 0.0

# Different kinds of zones
var nebula_global_brightness_variation = 0.0
var nebula_global_contrast_variation = 0.0
var nebula_global_saturation_variation = 0.0

var nebula_brightness_variation = 0.0
var nebula_contrast_variation = 0.0
var nebula_saturation_variation = 0.0

var system_brightness_variation = 0.0
var system_contrast_variation = 0.0
var system_saturation_variation = 0.0

var star_brightness_variation = 0.0
var star_contrast_variation = 0.0
var star_saturation_variation = 0.0

var planet_brightness_variation = 0.0
var planet_contrast_variation = 0.0
var planet_saturation_variation = 0.0

var structure_brightness_variation = 0.0
var structure_contrast_variation = 0.0
var structure_saturation_variation = 0.0


enum Adjustment_kind {BRIGHTNESS, CONTRAST, SATURATION}

var brightness_increment = 0.0
var contrast_increment = 0.0
var saturation_increment = 0.0


var saturation_delta = 0.0

var timer = 0.0


func _ready():
	# Set up initial global values.
	self.environment.adjustment_brightness = global_brightness
	self.environment.adjustment_contrast = global_contrast
	self.environment.adjustment_saturation = global_saturation


func _physics_process(delta):
	
	if timer <= refresh_rate:
		timer += delta
		return

	timer = 0.0

#	print(self.environment.adjustment_brightness)
#	print(self.environment.adjustment_contrast)
#	print(self.environment.adjustment_saturation)

	zone_brightness_variation = system_brightness_variation + star_brightness_variation \
		+ planet_brightness_variation + structure_brightness_variation \
		+ nebula_brightness_variation + nebula_global_brightness_variation
		
	zone_contrast_variation = system_contrast_variation + star_contrast_variation \
		+ planet_contrast_variation + structure_contrast_variation \
		+ nebula_contrast_variation + nebula_global_contrast_variation
		
	zone_saturation_variation = system_saturation_variation + star_saturation_variation \
		+ planet_saturation_variation + structure_saturation_variation \
		+ nebula_saturation_variation + nebula_global_saturation_variation
	
	brightness_variation = stepify(zone_brightness_variation + warp_brightness_variation, increment_step )
	contrast_variation = stepify(zone_contrast_variation, increment_step )
	saturation_variation = stepify(zone_saturation_variation - warp_brightness_variation/8, increment_step )
		
		
	# Adjust brightness on zone change.
	self.environment.adjustment_brightness = adjust_brightness(
			self.environment.adjustment_brightness, 
			global_brightness + brightness_variation,
			brightness_change_rate)
			
	# Adjust contrast on zone change.
	self.environment.adjustment_contrast = adjust_contrast(
			self.environment.adjustment_contrast, 
			global_contrast + contrast_variation,
			contrast_change_rate)
			
	# Adjust saturation on zone change.
	self.environment.adjustment_saturation = adjust_saturation(
			self.environment.adjustment_saturation, 
			global_saturation + saturation_variation,
			saturation_change_rate)

#	# Adjust brightness based on velocity.	
#	if not stepify(warp_brightness_variation_prev, increment_step) == stepify(warp_brightness_variation, increment_step):
#		# 1e-6 is used instead of 0.0 because it is universally used clamping minimum here.
#		if warp_brightness_variation > 1e-6:
#			self.environment.adjustment_brightness = \
#				global_brightness + brightness_variation + warp_brightness_variation
#		# Adjust back and stop updateing.
#		else:
#			self.environment.adjustment_brightness = global_brightness + brightness_variation

	# Record previous values.
	warp_brightness_variation_prev = warp_brightness_variation
	
	
	

func adjust_brightness(current_value, target_value, rate):
	# Stepify is used to ensure the condition checking. Doesn't work otherwise.
	# Partially compensate for warp velocity variation.
	if stepify(current_value, increment_step) != stepify(target_value + warp_brightness_variation, increment_step):
		
		# Positive change.
		if current_value < target_value:
#			print("Positive: ", current_value, " ", target_value, " ")
			brightness_increment = rate
			current_value += brightness_increment
			
			# Reset when reaching the end.
			if current_value > target_value:
				brightness_increment = 0.0
				current_value = target_value
		
		# Negative change.
		else:
#			print("Negative: ", current_value, " ", target_value)
			brightness_increment = rate
			current_value -= brightness_increment
			
			# Reset when reaching the end.
			if current_value < target_value:
				brightness_increment = 0.0
				current_value = target_value
	
	return current_value
	

func adjust_contrast(current_value, target_value, rate):
	# Stepify is used to ensure the condition checking. Doesn't work otherwise.
	if stepify(current_value, increment_step) != stepify(target_value, increment_step):
		
		# Positive change.
		if current_value < target_value:
			contrast_increment = rate
			current_value += contrast_increment
			
			# Reset when reaching the end.
			if current_value > target_value:
				contrast_increment = 0.0
				current_value = target_value
		
		# Negative change.
		else:
			contrast_increment = rate
			current_value -= contrast_increment
			
			# Reset when reaching the end.
			if current_value < target_value:
				contrast_increment = 0.0
				current_value = target_value
				
	return current_value
	

func adjust_saturation(current_value, target_value, rate):
	# Stepify is used to ensure the condition checking. Doesn't work otherwise.
	if stepify(current_value, increment_step) != stepify(target_value, increment_step):
		
		# Positive change.
		if current_value < target_value:
#			print("Positive: ", current_value, " ", target_value, " ")
			saturation_increment = rate
			current_value += saturation_increment

			# Reset when reaching the end.
			if current_value > target_value:
				saturation_increment = 0.0
				current_value = target_value
		
		# Negative change.
		else:
#			print("Negative: ", current_value, " ", target_value)
			saturation_increment = rate
			current_value -= saturation_increment
			
			# Reset when reaching the end.
			if current_value < target_value:
				saturation_increment = 0.0
				current_value = target_value
				
	return current_value
