package main

Element :: struct {
	name: string,
	attributes: [dynamic]Attribute,
	content: [dynamic]Node,
	type: Element_Type
}
Element_Type :: enum {
	Normal, Void, Foreign
}
Attribute :: struct {
	name: string,
	name_slices: [dynamic]AttributeSlice,
	value: string,
	value_slices: [dynamic]AttributeSlice
}
AttributeSlice :: union #no_nil {
	Text, Placeholder
}

Text :: struct {
	source: string
}
Placeholder :: struct {
	expression: string
}
Node :: union #no_nil {
	Element, Text, Placeholder
}