package main

import "core:fmt"
// 3.1 Collect all top level templates in ASTs.
// 3.1.1 Scan the top level of ASTs for Elements with name = template.
// 3.1.2 Validate: Attribute id must exist.
// 3.1.3 Validate: id attribute value must be a legal custom el. name.
// 3.1.4 Validate: name must be unique.

// 3.2 Build a component registry of collected templates.
// 3.2.1 Reg. key = template id.
// 3.2.2 Reg. value = component declaration / metadata.

// 3.3 Analyse each server component declaration.
// 3.3.1 Find all placeholders.
// 3.3.2 Extract p.something accesses and infer parameter properties.
// 3.3.3 Validate parameter type consistency across accesses.
// 3.3.4 Find and register slot declarations.

// 3.4 Resolve component usage.
// 3.4.1 For every element in template:
// 3.4.2 Check if name includes hyphen.
// 3.4.2.1 If it does, check if it is in the component list.
// 3.4.2.2 If it is, resolve as server component.
// 3.4.2.3 Treat every attribute as component arguments.
// 3.4.2.4 Treat every children as supplide slot content.
// 3.4.2.5 Validate supplied slot names against declared slots.
// 3.4.2.6 Validate supplied arguments against inferred parameters.
// 3.4.2.5 Validate that server component usage have explicit closing tag.

// 3.5 Validate component relationships.
// 3.5.1 Detect recursive component dependencies.

Component_Registry :: map[string]^Server_Component

Template_Declaration :: struct {
	id: string,	element: ^Element
}

Server_Component :: struct {
	name: string,
	declaration: Template_Declaration,
	parameters: [dynamic]Prop,
	slots: [dynamic]string
}

Prop :: struct {
	name: string,
	children: [dynamic]Prop
}

Component_Usage :: struct {
	component: ^Server_Component,
	attributes: [dynamic]Attribute,
	content: [dynamic]Node
}

compile_components :: proc(
	asts: []^Element, allocator := context.allocator
) -> [dynamic]Server_Component {
	templates := collect_templates(asts)
	defer delete(templates)
	return build_component_registry(&templates, allocator)
}

collect_templates :: proc(
	asts: []^Element, allocator := context.allocator
) -> (templates: [dynamic]Template_Declaration) {
	templates.allocator = allocator
	for element in asts {
		if element.name != "template" {
			continue
		}
		id, found := try_get_attribute_value(element.attributes[:], "id")
		if found && is_valid_custom_element_name(id) {
			append(&templates, {id, element})
		}
	}
	return templates
}

build_component_registry :: proc(
	templates: ^[dynamic]Template_Declaration, allocator := context.allocator
) -> (components: [dynamic]Server_Component) {
	components.allocator = allocator
	for t in templates {
		append(&components, build_server_component(t))
	}
	return components
}

build_server_component :: proc(template: Template_Declaration) -> Server_Component {
	return {
		name = template.id,
		declaration = template,
		parameters = collect_parameters(template),
		slots = collect_slots(template)
	}
}

collect_parameters :: proc(
	t: Template_Declaration, allocator := context.allocator
) -> (parameters: [dynamic]Prop) {
	parameters.allocator = allocator
	// Logic goes here
	return parameters
}

collect_slots :: proc(
	t: Template_Declaration, allocator := context.allocator
) -> (slots: [dynamic]string) {
	slots.allocator = allocator
	append_slots(&slots, &t.element.content)
	return slots
}

append_slots :: proc(slots: ^[dynamic]string, content: ^[dynamic]Node) {
	for i in 0..<len(content) {
		element, ok := &content[i].(Element)
		if !ok {
			continue
		}
		if element.name == "slot" {
			slot_name, found := try_get_attribute_value(element.attributes[:], "name")
			if !found {
				slot_name = get_available_default_slot_name(slots[:])
			}
			append(slots, slot_name)
		}
		else {
			append_slots(slots, &element.content)
		}
	}
}

try_get_attribute_value :: proc(attributes: []Attribute, name: string) -> (string, bool) {
	for attribute in attributes {
		if attribute.name == name {
			return attribute.value, true
		}
	}
	return "", false
}

get_available_default_slot_name :: proc(slots: []string) -> string {
	i: u8 = 0
	for i < 255 {
		name := fmt.tprintf("default-%d", i)
		available := true
		for s in slots {
			if s == name {
				available = false
				break
			}
		}
		if available {
			return name
		}
		i += 1
	}
	panic("Tried to assign more than 255 unnamed slots to component.")
}