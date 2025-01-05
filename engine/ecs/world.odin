package ecs

World :: struct {}

add_entities :: proc(world: World, e: ..Entity) {

}

add_systems :: proc(world: World, systems: ..system) {

}

query :: proc(world: World, query: string) -> []Component {
	return nil
}

add_component :: proc(world: World, e: Entity, component: Component) {

}
