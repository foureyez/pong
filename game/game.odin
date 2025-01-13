package game

import "core:log"
import "engine:core"
import "engine:renderer"

MAX_ENTITY_COUNT :: 10


Entity :: struct {
	transform: core.Transform,
}

GameState :: struct {
	entity_count: u32,
	entities:     [MAX_ENTITY_COUNT]Entity,
}

init :: proc(game_state: ^GameState) {
	create_entity(game_state, core.Transform{pos = {100, 100}, size = {100, 100}})
}

update :: proc(game_state: ^GameState, dt: f64) {
}

create_entity :: proc(game_state: ^GameState, transform: core.Transform) -> ^Entity {
	entity := new(Entity)
	if game_state.entity_count >= MAX_ENTITY_COUNT {
		log.panic("max entity reached")
	}

	game_state.entity_count += 1
	e := &game_state.entities[game_state.entity_count]
	e.transform = transform
	return e
}
