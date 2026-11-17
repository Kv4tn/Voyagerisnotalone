# EngineeringSimulation
# Performs physics and engineering calculations (Tsiolkovsky equation, power, resources)
# Autoload singleton: res://scripts/core/engineering_simulation.gd
extends Node

# ============================================================================
# CONSTANTS
# ============================================================================

const EXHAUST_VELOCITY: float = 3000.0  # m/s (typical for chemical rockets)

# ============================================================================
# PUBLIC VARIABLES
# ============================================================================

var spacecraft_mass: float = 10000.0  # kg
var fuel_mass: float = 5000.0  # kg
var power_generation: float = 100.0  # kW
var power_consumption: float = 50.0  # kW
var battery_charge: float = 100.0  # %

# ============================================================================
# GODOT LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	print("EngineeringSimulation: Ready")

# ============================================================================
# PUBLIC METHODS
# ============================================================================

func calculate_delta_v(fuel: float) -> float:
	"""
	Calculate available delta-v using Tsiolkovsky rocket equation
	Δv = ve * ln(m0/mf)
	@param fuel: Fuel mass in kg
	@return: Delta-v in m/s
	"""
	if fuel <= 0:
		return 0.0
	
	var m0: float = spacecraft_mass + fuel  # Initial mass
	var mf: float = spacecraft_mass  # Final mass (after fuel burned)
	
	if mf <= 0:
		push_error("EngineeringSimulation: Invalid spacecraft mass")
		return 0.0
	
	var delta_v: float = EXHAUST_VELOCITY * log(m0 / mf)
	return delta_v

func update_power_balance(delta: float) -> void:
	"""Update battery charge based on power balance"""
	# TODO: Implement in Task 5.3
	print("EngineeringSimulation: update_power_balance() - Not yet implemented")
