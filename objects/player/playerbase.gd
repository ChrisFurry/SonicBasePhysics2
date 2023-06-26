extends CharacterBody2D

# Movement
var movement:Vector2		= Vector2.ZERO;
var ground_movement:float	= 0.;
var surface_normal:Vector2	= Vector2.UP;
var floor_mode:int			= 0;
# Size
var size:Vector2i		= Vector2i(9,19);
var wall_size:int		= 10;
# Collision variables
var is_floored:bool			= false;
var floor_data:Array		= [];
var is_walled:bool			= false;
var wall_data:Array			= [];
var is_ceilinged:bool		= false;
var ceiling_data:Array		= [];
# 
var state:Callable		= state_normal;
var substate:Callable	= substate_normal;
# Physics Variables
var current_physics:Dictionary		= {
	accel		= .046875,
	frict		= .046875,
	deacc		= .5,
	gravity		= .21875,
	maxrun		= 6,
	jumpforce	= 6.5,
	airacc		= 0.09375,
}
# Saved for when using states
var temp_delta:float	= .0;
# Children
var Raycast:RayCast2D				= RayCast2D.new();
var Shapecast:ShapeCast2D			= ShapeCast2D.new();
var SizeShape:CollisionShape2D		= CollisionShape2D.new(); # Uses the player's current size
# Resources
var SizeRectangle:RectangleShape2D	= RectangleShape2D.new();
# Constants
const FLOOR_PERCISION			= 4; # How percise should the floor detection be.

func _ready():
	# Setup base shape size
	SizeRectangle.size		= size * 2;
	SizeRectangle.size.y = 2;
	# Setup Shapecast
	Shapecast.enabled		= false;
	Shapecast.max_results	= 1; # We'll only need 1 result
	Shapecast.shape			= SizeRectangle;
	# Setup Raycast
	Raycast.enabled			= false;
	# Add children
	add_child(Raycast);

func _physics_process(delta)->void:
	temp_delta = delta * 60.;
	state.call();
	queue_redraw();

func _draw()->void: 
	for i in FLOOR_PERCISION:
		var posx = lerp(-size.x,size.x,i / float(FLOOR_PERCISION - 1));
		draw_line(Vector2(posx,-size.y),Vector2(posx,size.y),Color(1,1,0,0.5));
	draw_line(Vector2(-wall_size,8 * int(is_floored && surface_normal == Vector2.UP)),Vector2(wall_size,8 * int(is_floored && surface_normal == Vector2.UP)),Color(1,0,1,0.5))

func _handle_physics(delta:float)->void:
	floor_data	= [];
	wall_data	= [];
	ceiling_data = [];
	is_walled = false;
	is_ceilinged = false;
	if(is_floored):
		movement = Vector2(-surface_normal.y * ground_movement,surface_normal.x * ground_movement);
	var playthrough:bool = false;
	while(!playthrough):
		playthrough = true;
		# Move player
		global_position += movement;
		# Wall Collision
		var wall = get_wall();
		if(!wall.is_empty()):
			is_walled = true;
			align_position_to_normal(wall.normal,wall.distance,wall_size);
			wall_data.append(wall);
		# Ceiling Collision
		var ceiling = get_ceiling();
		if(!ceiling.is_empty() && (movement.y < 0 || is_floored)):
			is_ceilinged = true;
			ceiling_data.append_array(ceiling);
			if(!is_floored):
				var main_normal = combine_normals(ceiling);
				align_position_to_normal(main_normal,shortest_distance(ceiling),size.y);
				if(abs(main_normal.angle_to(Vector2.UP)) < 2.35619):
					is_floored = true;
					surface_normal = main_normal;
					global_rotation = -surface_normal.angle_to(Vector2.UP);
					floor_data.append_array(ceiling);
					ground_movement = movement.y * sign(surface_normal.x);
		# Floor Collision
		var floor = get_floor();
		if(is_floored):
			if(floor.is_empty()): un_floor();
			else:
				surface_normal = combine_normals(filter_normals(floor));
				global_rotation = -surface_normal.angle_to(Vector2.UP);
				align_position_to_normal(surface_normal,shortest_distance(floor),size.y);
				floor_data.append_array(floor);
		else:
			if(!floor.is_empty() && movement.y >= -2):
				surface_normal = combine_normals(filter_normals(floor));
				global_rotation = -surface_normal.angle_to(Vector2.UP);
				align_position_to_normal(surface_normal,shortest_distance(floor),size.y);
				is_floored = true;
				floor_data.append_array(floor);
				# Landing
				if(abs(surface_normal.angle_to(Vector2.UP)) >= 0.418879):
					if(abs(surface_normal.angle_to(Vector2.UP)) <= 0.785398): ground_movement = movement.y * 0.5 * sign(surface_normal.x);
					else: ground_movement = movement.y * sign(surface_normal.x);
				else: ground_movement = movement.x;

func get_floor()->Array:
	var collision = [];
	for i in FLOOR_PERCISION:
		Raycast.position = Vector2(lerp(-size.x,size.x,i / float(FLOOR_PERCISION-1)),0);
		Raycast.target_position = Vector2(0,size.y + (int(is_floored) * 8));
		Raycast.force_raycast_update();
		if(Raycast.is_colliding()):
			collision.append({
				collider = Raycast.get_collider(),
				position = Raycast.get_collision_point(),
				normal = Raycast.get_collision_normal(),
				distance = get_raycast_distance(Raycast),
			});
	return collision;

func get_wall()->Dictionary:
	Raycast.position = Vector2(0,8 * int(is_floored && surface_normal == Vector2.UP));
	Raycast.target_position = Vector2(wall_size * sign(ground_movement if(is_floored)else movement.x),0);
	Raycast.force_raycast_update();
	if(Raycast.is_colliding()):
		return {
			collider = Raycast.get_collider(),
			position = Raycast.get_collision_point(),
			normal = Raycast.get_collision_normal(),
			distance = get_raycast_distance(Raycast),
		}
	return {};

func get_ceiling()->Array:
	var collision = [];
	for i in FLOOR_PERCISION:
		Raycast.position = Vector2(lerp(-size.x,size.x,i / float(FLOOR_PERCISION-1)),0);
		Raycast.target_position = -Vector2(0,size.y + (int(is_floored) * 8));
		Raycast.force_raycast_update();
		if(Raycast.is_colliding()):
			collision.append({
				collider = Raycast.get_collider(),
				position = Raycast.get_collision_point(),
				normal = Raycast.get_collision_normal(),
				distance = get_raycast_distance(Raycast),
			});
	return collision;

func filter_normals(normals:Array)->Array:
	var filtered:Array = [];
	for i in normals:
		if(i.normal.dot(surface_normal) > 0.45): filtered.append(i);
	return normals if(filtered.is_empty())else filtered;

func combine_normals(normals:Array)->Vector2:
	var final = Vector2.ZERO;
	for i in normals:
		final += i.normal;
	final /= float(normals.size());
	return final;

func shortest_distance(distances:Array)->float:
	var shortest = 128;
	for i in distances: if(i.distance < shortest): shortest = i.distance;
	return shortest;

func align_position_to_normal(normal:Vector2,distance:float,size:float)->void: global_position -= (distance - size) * normal;

func get_raycast_distance(ray:RayCast2D)->float:
	return ray.global_transform.origin.distance_to(ray.get_collision_point());

func un_floor()->void:
	is_floored = false;
	surface_normal = Vector2.UP;
	global_rotation = 0;

func state_normal()->void:
	substate.call();
	_handle_physics(temp_delta);
	if(!is_floored): movement.y += 0.2;

func substate_normal()->void:
	if(Input.is_action_just_pressed("jump") && !is_ceilinged):
		grounded_jump();
		return;
	grounded_control();
	grounded_slope_slip();
	grounded_slip_off();
	if(is_walled): ground_movement = 0;
	if(!is_floored): substate = substate_jump;

func substate_jump()->void:
	areal_control();
	if(is_ceilinged): movement.y = 0;
	if(is_walled): movement.x = 0;
	if(is_floored): substate = substate_normal;

func grounded_control()->void:
	var hor = Input.get_action_strength("right") - Input.get_action_strength("left");
	if(hor != 0):
		if(hor == sign(ground_movement) || ground_movement == 0): ground_movement = move_toward(ground_movement,current_physics.maxrun * hor,temp_delta * current_physics.accel);
		else: ground_movement = move_toward(ground_movement,current_physics.maxrun * hor,temp_delta * current_physics.deacc);
	else:
		ground_movement = move_toward(ground_movement,0,temp_delta * current_physics.frict);

func grounded_slope_slip()->void:
	ground_movement += surface_normal.x * 0.125;

func grounded_slip_off()->void:
	if(abs(ground_movement) < 2.5 && abs(surface_normal.angle_to(Vector2.UP)) >= 0.610865):
		if(abs(surface_normal.angle_to(Vector2.UP)) < 1.20428): ground_movement += sign(surface_normal.x) * 0.5;
		else: un_floor();

func grounded_jump()->void:
	movement += current_physics.jumpforce * surface_normal;
	un_floor();

func areal_control()->void:
	var hor = Input.get_action_strength("right") - Input.get_action_strength("left");
	if(hor != 0): movement.x = move_toward(movement.x,max(abs(movement.x),current_physics.maxrun) * hor,current_physics.airacc * temp_delta);

func is_player()->bool: return true;

func is_enemy_to_node(_node:Node)->bool: return false;
