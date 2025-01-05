package tests

import "../"
import "core:testing"

Person :: struct {}
Name :: string

@(test)
ecs_test :: proc(t: ^testing.T) {
	world := ecs.World{}
	ecs.add_entities(world, {Person, Name})
}
