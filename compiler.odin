package main

import "core:unicode"
import "core:unicode/utf8/utf8string"
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
	type: string,
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
	for document in asts {
		for i in 0..<len(document.content) {
			element := (&document.content[i].(Element)) or_continue
			if element.name != "template" {
				continue
			}
			id, found := try_get_attribute_value(element.attributes[:], "id")
			if found && is_valid_custom_element_name(id) {
				append(&templates, {id, element})
				fmt.printfln("%sFound component template: %s%s",
					ANSI_INFO, id, ANSI_RESET
				)
			}
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

collect_slots :: proc(
	t: Template_Declaration, allocator := context.allocator
) -> (slots: [dynamic]string) {
	slots.allocator = allocator
	append_slots(&slots, &t.element.content)
	return slots
}

append_slots :: proc(slots: ^[dynamic]string, content: ^[dynamic]Node) {
	for i in 0..<len(content) {
		element := (&content[i].(Element)) or_continue
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

collect_parameters :: proc(
	t: Template_Declaration, allocator := context.allocator
) -> (parameters: [dynamic]Prop) {
	parameters.allocator = allocator
	// Logic goes here
	ids: [dynamic]string
	ids.allocator = allocator
	for attribute in t.element.attributes {
		for i in 0..<len(attribute.name_slices) {
			slice := attribute.name_slices[i].(Placeholder) or_continue
			append_identifiers_in_placeholder(slice.expression, &ids)
		}
	}
	return parameters
}

get_props_in_placeholder :: proc(expression: string) {
	previous, current: rune
	for r, i in expression {
		if r == 'p' && (i == 0 || unicode.is_white_space(previous))  {

		}
	}
}
append_identifiers_in_placeholder :: proc(
	expression: string, ids: ^[dynamic]string
) {
	source: utf8string.String
	utf8string.init(&source, expression)
	scanner: Scanner = {&source, 0}

	for !at_end(&scanner) {
		next := peek(&scanner)
		switch {
		case is_quoted(next):
			read_es_string(&scanner)
		case next == '/':
			_, is_comment := read_any(&scanner, {"/", "*"})
			if is_comment {
				read_es_comment(&scanner)
			}
			else {
				panic(fmt.tprintfln("Unimplemented ES syntax: %v",
					mark_source(&scanner, scanner.pos)
				))
			}
		case is_digit_ASCII(next):
			read_es_number(&scanner)
		case:
			id := read_es_identifier(&scanner)
			fmt.printfln("%sFound identifier: %s%s", ANSI_OK, id, ANSI_RESET)
			append(ids, id)
		}
	}
}

read_es_identifier :: proc(scan: ^Scanner) -> string {
	fmt.println("Entered read_es_identifier.")
	start := scan.pos
	assert(is_es_ident_start(peek(scan)))
	read_while(scan, is_es_ident_continue)
	identifier := utf8string.slice(scan.source, start, scan.pos)
	fmt.printfln("\t%sIdentifier: %s%s", ANSI_OK, identifier, ANSI_RESET)
	return identifier
}

read_es_string :: proc(scan: ^Scanner) -> string {
	fmt.println("Entered read_es_string.")
	start := scan.pos
	delimiter := read(scan)
	assert(is_quoted(delimiter))
	for {
		read_until(scan, delimiter, inclusive = true)
		if peek(scan, -2) !='\\' {
			break
		}
	}
	reading := utf8string.slice(scan.source, start, scan.pos)
	fmt.printfln("%sString: %s%s", ANSI_OK, reading, ANSI_RESET)
	return reading
}

read_es_number :: proc(scan: ^Scanner) -> string {
	fmt.println("Entered read_es_number.")
	number := read_while(scan, is_es_numeric_literal_char)
	fmt.printfln("%sNumber: %s%s", ANSI_OK, number, ANSI_RESET)
	return number
}

read_es_comment :: proc(scan: ^Scanner) -> (string, bool) {
	start := scan.pos
	expect(scan, '/')
	switch read(scan) {
	case '/':
		read_until(scan, is_es_line_terminator, "line terminator", true)
	case '*':
		read_until(scan, "*/", inclusive = true)
	case:
		return "", false
	}
	return utf8string.slice(scan.source, start, scan.pos), true
}

// Return type here is some kind of union probably.
// read_es_template :: proc(scan: ^Scanner) -> []string {
//
// }