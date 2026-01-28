#
# PROJECT: GDTLancer
# MODULE: inventory_screen.gd
# STATUS: Level 3 - Verified
# TRUTH_LINK: TRUTH_GDD-COMBINED-TEXT-frozen-2026-01-26.md (Section 7 Platform Mechanics Divergence)
# LOG_REF: 2026-01-28-QA-Intern
#

extends Control

## InventoryScreen: UI for displaying player's owned ships, modules, and commodities.
## Provides detailed stats view for selected inventory items.

# Preload the InventorySystem script to access its enums
const InventorySystem = preload("res://src/core/systems/inventory_system.gd")

# --- Node References ---
onready var ShipList = $Panel/VBoxMain/HBoxContent/VBoxCategories/CategoryTabs/Ships/ShipList
onready var ModuleList = $Panel/VBoxMain/HBoxContent/VBoxCategories/CategoryTabs/Modules/ModuleList
onready var CommodityList = $Panel/VBoxMain/HBoxContent/VBoxCategories/CategoryTabs/Commodities/CommodityList

# --- Detail Panel Node References ---
onready var LabelName = $Panel/VBoxMain/HBoxContent/VBoxDetails/LabelName
onready var LabelDescription = $Panel/VBoxMain/HBoxContent/VBoxDetails/ScrollContainer/LabelDescription
onready var LabelStat1 = $Panel/VBoxMain/HBoxContent/VBoxDetails/LabelStat1
onready var LabelStat2 = $Panel/VBoxMain/HBoxContent/VBoxDetails/LabelStat2
onready var LabelStat3 = $Panel/VBoxMain/HBoxContent/VBoxDetails/LabelStat3


func _ready():
	GlobalRefs.set_inventory_screen(self)

	# Connect the item selection signals for each list
	ShipList.connect("item_selected", self, "_on_ShipList_item_selected")
	ModuleList.connect("item_selected", self, "_on_ModuleList_item_selected")
	CommodityList.connect("item_selected", self, "_on_CommodityList_item_selected")


func open_screen():
	_clear_details()  # Clear details panel when opening
	_populate_all_lists()

	self.show()


# Populates all three asset lists with data from the GameState via the system APIs.
func _populate_all_lists():
	# 1. Get Player UID
	if (
		not is_instance_valid(GlobalRefs.character_system)
		or not is_instance_valid(GlobalRefs.inventory_system)
		or not is_instance_valid(GlobalRefs.asset_system)
	):
		printerr("HangarScreen Error: Core systems not available in GlobalRefs.")
		return

	var player_uid = GlobalRefs.character_system.get_player_character_uid()
	if player_uid == -1:
		printerr("HangarScreen Error: Could not get a valid player UID.")
		return

	# 2. Clear existing lists
	ShipList.clear()
	ModuleList.clear()
	CommodityList.clear()

	# --- 3. Populate Ship List ---
	var ship_inventory = GlobalRefs.inventory_system.get_inventory_by_type(
		player_uid, InventorySystem.InventoryType.SHIP
	)
	for ship_uid in ship_inventory:
		var ship_resource = GlobalRefs.asset_system.get_ship(ship_uid)
		if is_instance_valid(ship_resource):
			ShipList.add_item(ship_resource.ship_model_name)
			# Store the UID for when the item is selected
			ShipList.set_item_metadata(ShipList.get_item_count() - 1, ship_uid)
		else:
			printerr("HangarScreen Error: Could not find ship asset for UID: ", ship_uid)

	# --- 4. Populate Module List ---
	var module_inventory = GlobalRefs.inventory_system.get_inventory_by_type(
		player_uid, InventorySystem.InventoryType.MODULE
	)
	for module_uid in module_inventory:
		# AssetSystem API doesn't have a get_module, so we access GameState directly
		var module_resource = GameState.assets_modules.get(module_uid)
		if is_instance_valid(module_resource):
			ModuleList.add_item(module_resource.module_name)
			ModuleList.set_item_metadata(ModuleList.get_item_count() - 1, module_uid)
		else:
			printerr("HangarScreen Error: Could not find module asset for UID: ", module_uid)

	# --- 5. Populate Commodity List ---
	var commodity_inventory = GlobalRefs.inventory_system.get_inventory_by_type(
		player_uid, InventorySystem.InventoryType.COMMODITY
	)
	for template_id in commodity_inventory:
		if TemplateDatabase.assets_commodities.has(template_id):
			var commodity_template = TemplateDatabase.assets_commodities[template_id]
			var quantity = commodity_inventory[template_id]

			# Display name and quantity in the list
			var item_text = "%s (x%d)" % [commodity_template.commodity_name, quantity]
			CommodityList.add_item(item_text)
			# Store the template_id for when the item is selected
			CommodityList.set_item_metadata(CommodityList.get_item_count() - 1, template_id)
		else:
			printerr("HangarScreen Error: Could not find commodity template for ID: ", template_id)


# --- Signal Handlers ---


# Clears the details panel text.
func _clear_details():
	LabelName.text = "Select an item"
	LabelDescription.text = ""
	LabelStat1.text = ""
	LabelStat2.text = ""
	LabelStat3.text = ""


func _on_ShipList_item_selected(index):
	var ship_uid = ShipList.get_item_metadata(index)
	var ship_resource = GlobalRefs.asset_system.get_ship(ship_uid)

	if is_instance_valid(ship_resource):
		_clear_details()
		LabelName.text = ship_resource.ship_model_name
		LabelDescription.text = "Ship Hull"  # Placeholder description
		LabelStat1.text = "Hull: %d" % ship_resource.hull_integrity
		LabelStat2.text = "Armor: %d" % ship_resource.armor_integrity
		LabelStat3.text = "Cargo: %d" % ship_resource.cargo_capacity
	else:
		_clear_details()
		LabelName.text = "Error: Ship not found"


func _on_ModuleList_item_selected(index):
	var module_uid = ModuleList.get_item_metadata(index)
	var module_resource = GameState.assets_modules.get(module_uid)

	if is_instance_valid(module_resource):
		_clear_details()
		LabelName.text = module_resource.module_name
		LabelDescription.text = "Ship Module"  # Placeholder description
		LabelStat1.text = "Base Value: %d Credits" % module_resource.base_value
	else:
		_clear_details()
		LabelName.text = "Error: Module not found"


func _on_CommodityList_item_selected(index):
	var template_id = CommodityList.get_item_metadata(index)
	var commodity_template = TemplateDatabase.assets_commodities.get(template_id)

	if is_instance_valid(commodity_template):
		var player_uid = GlobalRefs.character_system.get_player_character_uid()
		var quantity = GlobalRefs.inventory_system.get_asset_count(
			player_uid, InventorySystem.InventoryType.COMMODITY, template_id
		)

		_clear_details()
		LabelName.text = commodity_template.commodity_name
		LabelDescription.text = "Trade Good"  # Placeholder description
		LabelStat1.text = "Quantity: %d" % quantity
		LabelStat2.text = "Base Value: %d Credits" % commodity_template.base_value
	else:
		_clear_details()
		LabelName.text = "Error: Commodity not found"


func _on_ButtonClose_pressed():
	self.hide()
