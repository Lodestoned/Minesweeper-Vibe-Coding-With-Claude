extends Control

# Game settings
const GRID_WIDTH = 16
const GRID_HEIGHT = 16
const MINE_COUNT = 40
const CELL_SIZE = 30

# Cell states
enum CellState {
	HIDDEN,
	REVEALED,
	FLAGGED
}

# Game states
enum GameState {
	PLAYING,
	WON,
	LOST
}

# Grid data structure
class Cell:
	var is_mine: bool = false
	var state: CellState = CellState.HIDDEN
	var adjacent_mines: int = 0
	var button: Button

var grid: Array = []
var game_state: GameState = GameState.PLAYING
var flags_remaining: int = MINE_COUNT
var cells_to_reveal: int = (GRID_WIDTH * GRID_HEIGHT) - MINE_COUNT

# Timer variables
var game_timer: Timer
var start_time: float = 0.0
var elapsed_time: float = 0.0
var first_click: bool = false

# UI elements
var grid_container: GridContainer
var status_label: Label
var reset_button: Button
var flags_label: Label
var timer_label: Label

func _ready():
	setup_ui()
	setup_timer()
	initialize_game()

func setup_ui():
	# Main container
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Top panel with status and reset
	var top_panel = HBoxContainer.new()
	vbox.add_child(top_panel)
	
	flags_label = Label.new()
	flags_label.text = "Flags: " + str(flags_remaining)
	top_panel.add_child(flags_label)
	
	# Timer label
	timer_label = Label.new()
	timer_label.text = "Time: 0"
	top_panel.add_child(timer_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_panel.add_child(spacer)
	
	status_label = Label.new()
	status_label.text = "Playing"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_panel.add_child(status_label)
	
	# Another spacer
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_panel.add_child(spacer2)
	
	reset_button = Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(_on_reset_pressed)
	top_panel.add_child(reset_button)
	
	# Grid container
	grid_container = GridContainer.new()
	grid_container.columns = GRID_WIDTH
	grid_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid_container)

func setup_timer():
	game_timer = Timer.new()
	game_timer.wait_time = 0.1  # Update every 100ms
	game_timer.timeout.connect(_on_timer_timeout)
	add_child(game_timer)

func initialize_game():
	# Clear existing grid
	for child in grid_container.get_children():
		child.queue_free()
	
	# Reset game state
	game_state = GameState.PLAYING
	flags_remaining = MINE_COUNT
	cells_to_reveal = (GRID_WIDTH * GRID_HEIGHT) - MINE_COUNT
	
	# Reset timer
	first_click = false
	elapsed_time = 0.0
	game_timer.stop()
	
	update_ui()
	
	# Initialize grid
	grid = []
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			var cell = Cell.new()
			
			# Create button for cell
			var button = Button.new()
			button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			button.text = ""
			button.pressed.connect(_on_cell_left_click.bind(x, y))
			
			# Connect right click for flagging
			button.gui_input.connect(_on_cell_input.bind(x, y))
			
			cell.button = button
			grid_container.add_child(button)
			row.append(cell)
		grid.append(row)
	
	# Place mines randomly
	place_mines()
	
	# Calculate adjacent mine counts
	calculate_adjacent_mines()

func place_mines():
	var mines_placed = 0
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	while mines_placed < MINE_COUNT:
		var x = rng.randi() % GRID_WIDTH
		var y = rng.randi() % GRID_HEIGHT
		
		if not grid[y][x].is_mine:
			grid[y][x].is_mine = true
			mines_placed += 1

func calculate_adjacent_mines():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if not grid[y][x].is_mine:
				var count = 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx = x + dx
						var ny = y + dy
						if is_valid_position(nx, ny) and grid[ny][nx].is_mine:
							count += 1
				grid[y][x].adjacent_mines = count

func is_valid_position(x: int, y: int) -> bool:
	return x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT

func _on_cell_input(event: InputEvent, x: int, y: int):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_on_cell_right_click(x, y)

func _on_cell_left_click(x: int, y: int):
	if game_state != GameState.PLAYING:
		return
	
	# Start timer on first click
	if not first_click:
		first_click = true
		start_time = Time.get_ticks_msec() / 1000.0
		game_timer.start()
	
	var cell = grid[y][x]
	if cell.state == CellState.FLAGGED:
		return
	
	if cell.is_mine:
		# Game over
		game_timer.stop()
		reveal_all_mines()
		game_state = GameState.LOST
		status_label.text = "Game Over!"
		status_label.modulate = Color.RED
	else:
		reveal_cell(x, y)
		check_win_condition()

func _on_cell_right_click(x: int, y: int):
	if game_state != GameState.PLAYING:
		return
	
	var cell = grid[y][x]
	if cell.state == CellState.REVEALED:
		return
	
	if cell.state == CellState.HIDDEN:
		# Flag the cell
		cell.state = CellState.FLAGGED
		cell.button.text = "🚩"
		cell.button.modulate = Color.RED
		flags_remaining -= 1
	elif cell.state == CellState.FLAGGED:
		# Unflag the cell
		cell.state = CellState.HIDDEN
		cell.button.text = ""
		cell.button.modulate = Color.WHITE
		flags_remaining += 1
	
	update_ui()

func reveal_cell(x: int, y: int):
	var cell = grid[y][x]
	if cell.state == CellState.REVEALED or cell.state == CellState.FLAGGED:
		return
	
	cell.state = CellState.REVEALED
	cells_to_reveal -= 1
	
	# Update button appearance
	cell.button.disabled = true
	cell.button.modulate = Color.LIGHT_GRAY
	
	if cell.adjacent_mines > 0:
		cell.button.text = str(cell.adjacent_mines)
		# Color code the numbers
		match cell.adjacent_mines:
			1: cell.button.modulate = Color.BLUE
			2: cell.button.modulate = Color.GREEN
			3: cell.button.modulate = Color.RED
			4: cell.button.modulate = Color.PURPLE
			5: cell.button.modulate = Color.YELLOW
			6: cell.button.modulate = Color.PINK
			7: cell.button.modulate = Color.BLACK
			8: cell.button.modulate = Color.GRAY
	else:
		# If no adjacent mines, reveal all adjacent cells
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx = x + dx
				var ny = y + dy
				if is_valid_position(nx, ny):
					reveal_cell(nx, ny)

func reveal_all_mines():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell = grid[y][x]
			if cell.is_mine:
				cell.button.text = "💣"
				cell.button.modulate = Color.RED

func check_win_condition():
	if cells_to_reveal == 0:
		game_timer.stop()
		game_state = GameState.WON
		status_label.text = "You Win! Time: " + format_time(elapsed_time)
		status_label.modulate = Color.GREEN
		
		# Flag all remaining mines
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				var cell = grid[y][x]
				if cell.is_mine and cell.state != CellState.FLAGGED:
					cell.state = CellState.FLAGGED
					cell.button.text = "🚩"
					cell.button.modulate = Color.GREEN

func update_ui():
	flags_label.text = "Flags: " + str(flags_remaining)
	timer_label.text = "Time: " + format_time(elapsed_time)

func format_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func _on_timer_timeout():
	if game_state == GameState.PLAYING and first_click:
		elapsed_time = (Time.get_ticks_msec() / 1000.0) - start_time
		update_ui()

func _on_reset_pressed():
	initialize_game()
	status_label.text = "Playing"
	status_label.modulate = Color.WHITE
