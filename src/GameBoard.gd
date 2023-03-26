extends Node2D
class_name GameBoard

const DIRECTIONS = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

@export var grid : Resource = preload("res://scenes/components/Grid/Grid.tres")

# not a fan of accessing the unit overlay this way but didnt want to make 
# a new tilemap for it in godot 4, would rather use a different layer.
# seek an alternative to this
@onready var _unit_overlay: UnitOverlay = $"../Map"
# this is the godot 3 way to do it, what i was trying to avoid with unit overlay
# eventually it would be nice to have them just as seperate layers
# but need to figure out how to rearrange the code. maybe a resource for pathing?
@onready var _unit_path : UnitPath = $UnitPath

var _units := {}
var _active_unit : Unit
var _walkable_cells := []

func _ready() -> void:
	_reinitialize()
	print(_units)

func is_occupied(cell: Vector2) -> bool:
	return true if _units.has(cell) else false

func _reinitialize() -> void:
	_units.clear()
	
	for child in get_children():
		var unit := child as Unit
		if not unit:
			continue
		_units[unit.cell] = unit
		
func get_walkable_cells(unit: Unit) -> Array :
	return _flood_fill(unit.cell, unit.move_range)
	
func _flood_fill(cell: Vector2, max_distance: int) -> Array:
	var array := []
	var stack := [cell]
	
	while not stack.is_empty():
		var current = stack.pop_back()
		
		if not grid.is_within_bounds(current):
			continue
		if current in array:
			continue
		
		var difference: Vector2 = (current - cell).abs()
		var distance := int(difference.x + difference.y)
		if distance > max_distance:
			continue
		
		array.append(current)
		
		for direction in DIRECTIONS:
			var coordinates: Vector2 = current + direction
			if is_occupied(coordinates):
				continue
			if coordinates in array:
				continue
			
			stack.append(coordinates)
	return array

func _select_unit(cell: Vector2) -> void:
	if not _units.has(cell):
		return
		
	_active_unit = _units[cell]
	_active_unit.is_selected = true
	_walkable_cells = get_walkable_cells(_active_unit)
	_unit_overlay.draw(_walkable_cells)
	_unit_path.initialize(_walkable_cells)
	
func _deselect_active_unit() -> void:
	_active_unit.is_selected = false
	_unit_overlay.clear_layer(1)
	_unit_path.stop()
	
func _clear_active_unit() -> void:
	_active_unit = null
	_walkable_cells.clear()
	
	
func _move_active_unit(new_cell: Vector2) -> void:
	if is_occupied(new_cell) or not new_cell in _walkable_cells:
		return
		
	_units.erase(_active_unit.cell)
	_units[new_cell] = _active_unit
	
	_deselect_active_unit()
	
	_active_unit.walk_along(_unit_path.current_path)
	await _active_unit.walk_finished
	_clear_active_unit()

func _on_cursor_moved(new_cell: Vector2) -> void:
	if _active_unit and _active_unit.is_selected:
		_unit_path.draw(_active_unit.cell, new_cell)

func _on_cursor_accept_pressed(cell: Vector2) -> void:
	if not _active_unit:
		_select_unit(cell)
	elif _active_unit.is_selected:
		_move_active_unit(cell)

func _unhandled_input(event: InputEvent) -> void:
	if _active_unit and event.is_action_pressed("ui_cancel"):
		_deselect_active_unit()
		_clear_active_unit()