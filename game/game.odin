package game

import "core:log"
import "core:time"
import "engine:core"
import "engine:renderer"

MAX_ENTITY_COUNT :: 10


Entity :: struct {
	mesh:      renderer.Mesh,
	transform: core.Transform,
}

GameState :: struct {
	camera:   renderer.Camera2D,
	entities: [dynamic]Entity,
}

init :: proc(game_state: ^GameState) {
	game_state.camera = renderer.new_camera_2d(-1, 1, -1, 1, {0, 0, 0})
	create_entity(game_state, core.Transform{position = {0, 0, 0}, scale = {0.3, 0.3, 0.3}})
}

update :: proc(game_state: ^GameState, dt: f64) {
}

render :: proc(game_state: ^GameState) {
	renderer.render_begin(&game_state.camera)
	renderer.clear_background({0.6, 0.1, 0.2, 1})
	for e in game_state.entities {
		renderer.draw_mesh(e.mesh, e.transform)
	}
	renderer.render_end()
}

create_entity :: proc(game_state: ^GameState, transform: core.Transform) -> ^Entity {
	entity := Entity{}
	if len(game_state.entities) >= MAX_ENTITY_COUNT {
		log.panic("max entity reached")
	}

	entity.transform = transform
	entity.mesh = renderer.mesh_create_quad()

	append(&game_state.entities, entity)
	return nil
}
