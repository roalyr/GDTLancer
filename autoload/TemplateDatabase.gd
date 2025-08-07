# File: autoload/TemplateDatabase.gd
# Autoload Singleton: Scanned templates from /data/ are indexed and stored here
# Version: 1.0 

extends Node

# Dictionaries to hold loaded templates, keyed by their template_id.
var actions: Dictionary = {}
var agents: Dictionary = {}
var characters: Dictionary = {}
var assets_ships: Dictionary = {}
var assets_modules: Dictionary = {}
var assets_commodities: Dictionary = {}
