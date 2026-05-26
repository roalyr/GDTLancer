#
# PROJECT: GDTLancer
# MODULE: legacy_system_name_generator.gd
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TACTICAL_TODO.md TASK_2
# LOG_REF: 2026-05-25 03:03:55
#

extends Reference
class_name LegacySystemNameGenerator

const _LEGACY_VOWEL_WEIGHTS: Array = [
	["y", 1],
	["u", 2],
	["o", 4],
	["i", 4],
	["a", 5],
	["e", 6],
]
const _LEGACY_CONSONANT_WEIGHTS: Array = [
	["q", 1], ["j", 1], ["z", 1], ["x", 1],
	["v", 5], ["k", 5],
	["w", 7],
	["f", 9],
	["b", 11],
	["g", 12],
	["h", 15], ["m", 15],
	["p", 16],
	["d", 17],
	["c", 23],
	["l", 28],
	["s", 29],
	["n", 34],
	["t", 35],
	["r", 39],
]
const _LEGACY_VOWEL_CHARS: String = "aeiouy"
const _LEGACY_CONSONANT_CHARS: String = "bcdfghjklmnpqrstvwxyz"


func generate_system_name(seed_key: String, length_min: int = 4, length_max: int = 7) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seed_key) + ":legacy_system_name")
	var consonant_pool: Array = _build_weighted_char_pool(_LEGACY_CONSONANT_WEIGHTS, rng)
	var vowel_pool: Array = _build_weighted_char_pool(_LEGACY_VOWEL_WEIGHTS, rng)
	var resolved_min: int = length_min
	var resolved_max: int = length_max
	if resolved_min > resolved_max:
		resolved_min = length_max
		resolved_max = length_min
	var generated_length: int = rng.randi_range(resolved_min, resolved_max)
	var max_vowels_consecutive: int = 0
	var max_consonants_consecutive: int = 0
	var structure_roll: float = rng.randf()
	if structure_roll < 0.3:
		max_vowels_consecutive = 1
		max_consonants_consecutive = 2
	elif structure_roll < 0.6:
		max_vowels_consecutive = 2
		max_consonants_consecutive = 2
	else:
		max_vowels_consecutive = 1
		max_consonants_consecutive = 1
		generated_length += 1

	var vowel_streak: int = 0
	var consonant_streak: int = 0
	var generated_name: String = ""
	for _idx in range(generated_length):
		var choose_vowel: bool = rng.randf() < 0.5
		if choose_vowel:
			if vowel_streak < max_vowels_consecutive:
				generated_name += _pick_weighted_char(vowel_pool, rng)
				vowel_streak += 1
				consonant_streak = 0
			else:
				generated_name += _pick_weighted_char(consonant_pool, rng)
				vowel_streak = 0
				consonant_streak += 1
		else:
			if consonant_streak < max_consonants_consecutive:
				generated_name += _pick_weighted_char(consonant_pool, rng)
				consonant_streak += 1
				vowel_streak = 0
			else:
				generated_name += _pick_weighted_char(vowel_pool, rng)
				consonant_streak = 0
				vowel_streak += 1

	generated_name = _trim_legacy_edges(generated_name)
	if generated_name.empty():
		generated_name = _pick_weighted_char(vowel_pool, rng) + _pick_weighted_char(consonant_pool, rng)
	return generated_name.capitalize()


func _build_weighted_char_pool(weights: Array, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for entry in weights:
		if not (entry is Array) or entry.size() < 2:
			continue
		var char_text: String = str(entry[0])
		var repeats: int = int(entry[1])
		for _idx in range(repeats):
			pool.append(char_text)
	for idx in range(pool.size() - 1, 0, -1):
		var swap_idx: int = rng.randi_range(0, idx)
		var swap_value = pool[idx]
		pool[idx] = pool[swap_idx]
		pool[swap_idx] = swap_value
	return pool


func _pick_weighted_char(pool: Array, rng: RandomNumberGenerator) -> String:
	if pool.empty():
		return ""
	return str(pool[rng.randi() % pool.size()])


func _trim_legacy_edges(generated_name: String) -> String:
	var trimmed_name: String = generated_name
	if trimmed_name.length() >= 2:
		var first_char: String = trimmed_name.substr(0, 1).to_lower()
		var second_char: String = trimmed_name.substr(1, 1).to_lower()
		if _is_consonant(first_char) and _is_consonant(second_char):
			trimmed_name = trimmed_name.substr(1, trimmed_name.length() - 1)
	if not trimmed_name.empty() and trimmed_name.substr(0, 1).to_lower() == "x":
		trimmed_name = trimmed_name.substr(1, trimmed_name.length() - 1)
	if not trimmed_name.empty():
		var last_char: String = trimmed_name.substr(trimmed_name.length() - 1, 1).to_lower()
		if last_char == "x" or last_char == "y":
			trimmed_name = trimmed_name.substr(0, trimmed_name.length() - 1)
	trimmed_name = _soften_internal_y(trimmed_name)
	return trimmed_name


func _soften_internal_y(generated_name: String) -> String:
	if generated_name.length() < 3:
		return generated_name
	var softened_name: String = ""
	for idx in range(generated_name.length()):
		var current_char: String = generated_name.substr(idx, 1)
		if current_char.to_lower() == "y" and idx > 0 and idx < generated_name.length() - 1:
			var previous_char: String = generated_name.substr(idx - 1, 1)
			var next_char: String = generated_name.substr(idx + 1, 1)
			if _is_consonant(previous_char) and _is_consonant(next_char):
				softened_name += "i"
				continue
		softened_name += current_char
	return softened_name


func _is_consonant(char_text: String) -> bool:
	return _LEGACY_CONSONANT_CHARS.find(char_text.to_lower()) != -1 and _LEGACY_VOWEL_CHARS.find(char_text.to_lower()) == -1
