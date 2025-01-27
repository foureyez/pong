package game

import "core:log"
import "core:time"
import "engine:core"
import "engine:renderer"

MAX_ENTITY_COUNT :: 10
SPEED :: 0.5

Paddle :: struct {
	mesh:      renderer.Mesh,
	transform: core.Transform,
}

GameState :: struct {
	camera:       renderer.Camera2D,
	left_paddle:  Paddle,
	right_paddle: Paddle,
}

game_state: GameState

init :: proc() {
	game_state = GameState{}
	game_state.camera = renderer.new_camera_2d(-10, 10, {0, 0, 0})
	game_state.left_paddle = create_paddle(core.Transform{position = {0, -1, 0}, scale = {0.3, 0.3, 0.3}})
	game_state.right_paddle = create_paddle(core.Transform{position = {0, 0, 0}, scale = {0.3, 0.3, 0.3}})
	// core.event_register(.INPUT_KEYUP, nil, handle_keyup)
}

handle_keyup :: proc(listener: rawptr, event: core.Event) -> bool {
	log.info(event.data)
	return false
}

update :: proc(dt: f64) {
	if core.is_key_down(.Key_W) {
		game_state.left_paddle.transform.position.y -= SPEED * f32(dt)
	} else if core.is_key_down(.Key_S) {
		game_state.left_paddle.transform.position.y += SPEED * f32(dt)
	}

	if core.is_key_down(.Key_I) {
		game_state.right_paddle.transform.position.y -= SPEED * f32(dt)
	} else if core.is_key_down(.Key_K) {
		game_state.right_paddle.transform.position.y += SPEED * f32(dt)
	}
}

render :: proc() {
	renderer.render_begin(&game_state.camera)
	renderer.clear_background({0.6, 0.1, 0.2, 1})
	renderer.draw_mesh(game_state.left_paddle.mesh, game_state.left_paddle.transform)
	renderer.draw_mesh(game_state.right_paddle.mesh, game_state.right_paddle.transform)
	renderer.render_end()
}

create_paddle :: proc(transform: core.Transform) -> (paddle: Paddle) {
	paddle.transform = transform
	paddle.mesh = renderer.mesh_create_quad()
	return paddle
}
