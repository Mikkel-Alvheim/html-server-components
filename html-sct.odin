package main
import "core:os"
import "core:unicode/utf8/utf8string"
import "core:unicode"
import "core:terminal/ansi"
import "core:math"
import "core:unicode/utf8"
import "core:fmt"
import "core:strings"

/*
EBNF:
document = {template | text}
template = template_open content template_close
template_open = "<" template \s {\s} "id=" '"' cust_el_name '"' {\s} ">"
template_close = "</" {\s} "template" {\s} ">"
content = {text-content | placeholder | element}
element = normal_el | void_el | self_closing_el
text = "..." - {"<" | ">" | "%"}
normal_element = open_tag {content} close_tag
-- This is not a shorthand in odin's regex --
ASCII_NUL = \0
\s = space | \t | \n | \f | \r
\d = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
int = \d {\d}
upper_alpha = "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H"
| "I" | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R"
| "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z"
lower_alpha = "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h"
| "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r"
| "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
alpha = lower_alpha | upper_alpha
\w = \d | lower_alpha | upper_alpha
space = " "

attribute_name = lower_alpha {valid_el_char}
attribute = attribute-name ["=" '"' "... '"']

open_tag = "<" "..." {space attribute} ">"
close_tag = "</" "..." ">"
tag = open_tag | close_tag

parameter = "p." "..." {"." "..."}
placeholder = "%{" "..." | "parameter" {"..." | parameter} "}"

-- This is simplified, char can also be U+0080 to U+10FFFF inclusive --
element_local_name = \w | ":" {\w | ":" | "-" | "."}
valid_el_char = {lower_alpha | "-" | "_" | ":" | "."}
reserved_hyphenated_el_names = "annotation-xml"
| "color-profile"
| "font-face"
| "font-face-src"
| "font-face-uri"
| "font-face-format"
| "font-face-name"
| "missing-glyph"
cust_el_name = (lower_alpha {valid_el_char} - {valid_el_char}) - reserved_hyphenated_el_names
-- Here I've got a circular dependency. How does that affect a recursive descent parser? --


ds_case_mod = "__case." ["camel" | "kebab" | "snake" | "pascal"]
ds_mod_timing = "." int ("s" | "ms")
ds_delay_mod = "__delay" ds_mod_timing
ds_debounce_mod = "__debounce" (ds_mod_timing | ".leading" | ".notrailing")
ds_throttle_mod = "__throttle" (ds_mod_timing | ".noleading" | ".trailing")
ds_duration_mod = "__duration" (ds_mod_timing | ".leading")
ds_bind_mod = ds_case_modifier | "__prop." property | "__event." event
ds_init_mod =  [ds_case_modifier] ["__viewtransition"]
ds_viewtransition_mod = "__viewtransition"
ds_on_mod =
| "__once"
| "__passive"
| "__capture"
| ds_case_mod
| ds_delay_mod
| ds_debounce_mod
| ds_throttle_mod
| ds_viewtransition_mod
| "__window"
| "__document"
| "__outside"
| "__prevent"
| "__stop"
ds_on_intersect_mod =
| "__once"
| "__exit"
| "__half"
| "__full"
| "treshold." \d [\d]
| ds_delay_mod
| ds_debounce_bod
| ds_throttle_mod
| ds_viewtransition_mod
ds_on_interval_mod = ds_duration_mod | ds_viewtransition_mod
ds_on_signal-patch_mod = ds_delay_mod | ds_debounce_mod | ds_throttle_mod

ds_attr_signal = ":" "attribute_name"
ds_expr = '"' "..." '"'

ds_need_expr_attr = (
	| "attr" [ds_attr_signal]
	| "class" [ds_attr_signal] [ds-case-mod]
	| "computed" [ds_attr_signal] [ds-case-mod]
	| "effect"
	| "init" [ds_init_mod]
	| "on" ((":" event {ds_on_mod}) | ("-" (
		| "intersect" {ds_on_intersect_mod}
		| "interval" {ds_on_interval_mod}
		| "signal-patch" [ {ds_on_signal_patch_mod} | "-filter"]
	))
	| "preserve-attr"
	| "show"
	| "signals" [ds_attr_signal] {ds_case_mod | "__ifmissing"}
	| "style" [ds_attr_signal]
	| "text"
) "=" ds_expr
ds_maybe_expr_attr = "data-" {
	| "bind" ([ds_attr_signal] {ds_bind_mod}) | ({ds_bind_mod} "=" ds_expr)
	| "ignore" ["-morph" | "__self"]
	| "indicator" (ds_attr_signal [ds_case_mod]) | ([ds_case_mod] "=" ds_expr)
	| "json-signals" ["__terse"] ["=" ds_expr]
	| "ref" (ds_attr_signal [ds_case_mod]) | ([ds_case_mod] "=" ds_expr)
}
ds-attr = ds_need_expr_attr | ds_maybe_expr_attr
*/

PLACEHOLDER_DELIM :: '%'
START_TAG_OPEN :: "<"
END_TAG_OPEN :: "</"
TAG_CLOSE :: '>'
INVALID_TAG_SELF_CLOSE :: "/>"
BRACKET_OPEN :: '{'
BRACKET_CLOSE :: '}'
ATTR_INFIX :: "="
ATTR_VALUE_DELIM :: '"'

WHITESPACE :: []string {" ", "\t", "\n", "\r", "\f"}
CHARACTER := []string { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
	"N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
	"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
	"_", "-", ":", "."
}
DIGIT := CHARACTER[0:10]
UPPER_ALPHA := CHARACTER[10:36]
LOWER_ALPHA :=  CHARACTER[36:62]
VALID_EL_CHAR := CHARACTER[36:66]
VALID_EL_SYMBOL := CHARACTER[62:66]

is_digit_ASCII :: proc(c: rune) -> bool {
	return c >= '0' && c <='9'
}
is_upper_ASCII :: proc(c: rune) -> bool {
	return c >= 'A' && c <= 'Z'
}
is_lower_ASCII :: proc(c: rune) -> bool {
	return c >= 'a' && c <= 'z'
}
is_alpha_ASCII :: proc(c: rune) -> bool {
	return is_upper_ASCII(c) || is_lower_ASCII(c)
}
is_alpha_numeric_ASCII :: proc(c: rune) -> bool {
	return is_alpha_ASCII(c) || is_digit_ASCII(c)
}
is_name_symbol_HTML :: proc(c: rune) -> bool {
	return c == '-' || c == '_' || c == ':' || c == '.'
}
is_name_char_HTML :: proc(c: rune) -> bool {
	return is_lower_ASCII(c) || is_digit_ASCII(c) || is_name_symbol_HTML(c)
}

print_token_sets :: proc() {
	fmt.printfln("Digits: %v", DIGIT)
	fmt.printfln("Uppercase: %v", UPPER_ALPHA)
	fmt.printfln("Lowercase: %v", LOWER_ALPHA)
	fmt.printfln("Valid element symbols: %v", VALID_EL_SYMBOL)
	fmt.printfln("Valid element name characters: %v", VALID_EL_CHAR)
}

Parser :: struct {
	source: ^utf8string.String,
	pos: int,
}

Attribute :: struct {
	name: string,
	value: string
}
Element :: struct {
	name: string,
	attributes: [dynamic]Attribute,
	content: [dynamic]Node
}
Text :: struct {
	source: string
}
Placeholder :: struct {
	expression: string
}
Node :: union #no_nil {Element, Text, Placeholder}

main :: proc() {
	for arg, i in os.args {
		fmt.printf("%d: %s\n", i, arg)
	}

	print_token_sets()
	input_dir := os.args[1]
	output_dir := os.args[2]

	files, err := os.read_all_directory_by_path(input_dir, context.temp_allocator)
	if err == nil {
		for file, i in files {
			fmt.printf("%d: %s\n", i, file.name)
			if os.ext(file.fullpath) != ".html" {
				fmt.printf("%s does not have .html extension\n", file.name)
				continue
			}
			data, err := os.read_entire_file_from_path(file.fullpath, context.temp_allocator)
			if err != nil {
				fmt.printf("Could not read file...\n")
			}
			content := strings.clone_from_bytes(data)
			utf8_string: utf8string.String
			parse_document(&{source = utf8string.init(&utf8_string, content), pos = 0})
		}
	}
}

parse_document :: proc(parser: ^Parser) {
	document: Element = {
		name = "document"
	}
	for !at_end(parser) {
		read_all(parser, WHITESPACE)
		if at_end(parser) {
			break
		}
		parse_children(parser, &document)
		fmt.printfln("Left parse_children in parse_document. current pos: %d", parser.pos)
	}
	fmt.printf("%v", document)
}

parse_element :: proc(parser: ^Parser, element: ^Element) {
	parse_open_tag(parser, element)
	fmt.printfln("Left parse_open_tag. current pos: %d", parser.pos)
	parse_children(parser, element)
	fmt.printfln("Left parse_children. current pos: %d", parser.pos)
}

parse_children :: proc(parser: ^Parser, parent: ^Element) {
	placeholder_delim_char := utf8.runes_to_string({PLACEHOLDER_DELIM})
	defer delete(placeholder_delim_char)

	iteration := 0
	fmt.printfln("Starting loop in comment section of parse_non_html_tag.")
	for {
		if at_end(parser) {
			break
		}
		char, ok := peek(parser)
		fmt.printfln("iteration: %d, pos: %s (%d)\n%v",
			iteration, char, parser.pos, parent
		)
		switch char {
		case START_TAG_OPEN:
			next_token, ok := peek(parser, 1)
			if next_token == "/" {
				parse_close_tag(parser, parent)
				fmt.printfln("Left parse_close_tag. current pos: %d", parser.pos)
				return
			}
			else if next_token == "!" {
				append(&parent.content, parse_non_html_tag(parser))
				fmt.printfln("Left parse_non_html_tag. current pos: %d", parser.pos)
			}
			else {
				child: Element
				parse_element(parser, &child)
				append(&parent.content, child)
				fmt.printfln("Left parse_element. current pos: %d", parser.pos)
			}
		case placeholder_delim_char:
			append(&parent.content, parse_placeholder(parser))
			fmt.printfln("Left parse_placeholder. current pos: %d", parser.pos)
		case:
			append(&parent.content, parse_text(parser))
			fmt.printfln("Left parse_text. current pos: %d", parser.pos)
		}
		iteration += 1
	}
}

parse_non_html_tag :: proc(parser: ^Parser) -> Text {
	fmt.printfln("Entered parse_non_html_tag. current pos: %d", parser.pos)
	tag_close_char := utf8.runes_to_string({TAG_CLOSE})
	defer delete(tag_close_char)

	start := parser.pos
	_, comment_opened := read(parser, "<!--")
	if comment_opened {
		fmt.printfln("Starting loop in comment section of parse_non_html_tag.")
		for comment_closed := false; !comment_closed; {
			read_until(parser, '-')
			_, comment_closed = read(parser, "-->")
			if !comment_closed {
				parser.pos += 1
			}
		}
		source, in_bounds := strings.substring(parser.source, start, parser.pos)
		if !in_bounds {
			panic("parse_non_html_tag comment section tried to return invalid source range!")
		}
		return {source}
	}

	return {
		source = fmt.tprintf("<!%s>", read_until(parser, TAG_CLOSE, inclusive = true))
	}
}

parse_open_tag :: proc(parser: ^Parser, element: ^Element) {
	fmt.printfln("Entered parse_open_tag. current pos: %d", parser.pos)
	expect(parser, START_TAG_OPEN)
	name := parse_tag_name(parser)
	element.name = name
	tag_close_char := utf8.runes_to_string({TAG_CLOSE})
	defer delete(tag_close_char)
	for {
		read_all(parser, WHITESPACE)
		_, consumed_close_tag := read_any(parser, []string {tag_close_char, INVALID_TAG_SELF_CLOSE})
		if consumed_close_tag {
			return
		}
		append(&element.attributes, parse_attribute(parser))
	}
}

parse_close_tag :: proc(parser: ^Parser, element: ^Element) {
	fmt.printfln("Entered parse_close_tag. current pos: %d", parser.pos)
	expect(parser, END_TAG_OPEN)
	name := read_until(parser, TAG_CLOSE)
	if name != element.name {
		panic(fmt.tprintfln("Closing tag %v tried to close element %v", name, element.name))
	}
}

parse_tag_name :: proc(parser: ^Parser) -> (string) {
	fmt.printfln("Entered parse_tag_name. current pos: %d", parser.pos)
	start_pos: = parser.pos
	expect(parser, LOWER_ALPHA)
	read_all(parser, VALID_EL_CHAR)
	name, ok := strings.substring(parser.source, start_pos, parser.pos)
	if !(ok && name != "") {
		panic("could not parse tag name")
	}
	return name
}

parse_attribute :: proc(parser: ^Parser) -> Attribute {
	fmt.printfln("Entered parse_attribute. current pos: %d", parser.pos)
	name := parse_tag_name(parser)
	value := ""
	next_token, in_bounds := peek(parser)
	if next_token == ATTR_INFIX {
		expect(parser, ATTR_INFIX)
		expect(parser, ATTR_VALUE_DELIM)
		value = read_until(parser, ATTR_VALUE_DELIM)
		expect(parser, ATTR_VALUE_DELIM)
	}
	return {name, value}
}

parse_placeholder :: proc(parser: ^Parser) -> Placeholder {
	fmt.printfln("Entered parse_placeholder. current pos: %d", parser.pos)
	bracket_open_char := utf8.runes_to_string({BRACKET_OPEN})
	bracket_close_char:= utf8.runes_to_string({BRACKET_CLOSE})
	defer delete(bracket_open_char)
	defer delete(bracket_close_char)

	expect(parser, PLACEHOLDER_DELIM)
	expect(parser, BRACKET_OPEN)
	start := parser.pos
	nesting :u8 = 0
	fmt.printfln("Starting loop in parse_placeholder.")
	for token, in_bounds := read_next(parser); token != "}" || nesting != 0; {
		if !in_bounds {
			panic("Missing closing bracket for placeholder.")
		}

		if token == bracket_open_char {
			nesting += 1
		}
		else if token == bracket_close_char {
			nesting -= 1
		}
		token, in_bounds = read_next(parser)
	}
	expression, in_bounds := strings.substring(parser.source, start, parser.pos)
	if !in_bounds {
		panic("Invalid source range")
	}
	return {expression}
}

parse_text :: proc(parser: ^Parser) -> Text {
	fmt.printfln("Entered parse_text. current pos: %d", parser.pos)
	ph_delim_char := utf8.runes_to_string({PLACEHOLDER_DELIM})
	defer delete(ph_delim_char)

	start := parser.pos
	fmt.printfln("Starting loop in parse_text.")
	for char, ok := peek(parser); char != START_TAG_OPEN && char != ph_delim_char; char, ok = peek(parser) {
		fmt.printfln("char: %s", char)
		if at_end(parser) {
			break
		}
		read(parser)
	}
	source, in_bounds := strings.substring(parser.source, start, parser.pos)
	if !in_bounds {
		panic("Invalid source range")
	}
	return {source}
}

at_end :: proc(parser: ^Parser, offset := 0) -> bool {
	return parser.pos + offset >= parser.source.rune_count
}

peek :: proc(p: ^Parser, offset := 0) -> rune {
	return at_end(p, offset) ? utf8.RUNE_EOF : utf8string.at(p.source, p.pos + offset)
}

read_next :: proc(parser: ^Parser) -> rune {
	if at_end(parser) {
		return utf8.RUNE_EOF
	}
	pos += 1
	return utf8string.at(p.source, p.pos)
	char := peek(parser)
	if char != utf8.RUNE_EOF {
		parser.pos += 1
	}
	return char, ok
}
read_string :: proc(parser: ^Parser, value: string) -> (string, bool) {
	length := utf8.rune_count(value)
	reading, in_bounds := strings.substring(
		parser.source, parser.pos, parser.pos + length
	)
	if !in_bounds || reading != value {
		return "", false
	}
	parser.pos += length
	return reading, true
}
read_rune :: proc(parser: ^Parser, value: rune) -> (string, bool) {
	char, err := utf8.runes_to_string({value})
	defer delete(char)
	return read_string(parser, char)
}
read :: proc{read_next, read_string, read_rune}

read_until :: proc(parser: ^Parser, delimiter: rune, inclusive := false) -> string {
	delim_string, err := utf8.runes_to_string({delimiter})
	defer delete(delim_string)
	start := parser.pos
	char, ok := "", true
	fmt.printfln("Starting loop in read_until.")
	for char != delim_string {
		char, ok = read_next(parser)
		if !ok {
			panic(fmt.tprintfln("Missing %v in:\n%s", delimiter, strings.substring_from(parser.source, start)))
		}
	}
	if !inclusive {
		parser.pos -= 1
	}
	reading, in_bounds := strings.substring(parser.source, start, parser.pos)
	if !in_bounds {
		panic("Invalid source range")
	}
	return reading
}

read_any :: proc(parser: ^Parser, values: []string) -> (sub: string, consumed: bool) {
	fmt.printfln("Starting loop in read_any.")
	for value in values {
		consumed_string, ok := read(parser, value)
		if ok {
			return consumed_string, true
		}
	}
	return "", false
}
read_all :: proc(parser: ^Parser, values: []string) -> (sub: string, ok: bool) {
	start := parser.pos
	fmt.printfln("Starting loop in read_all.")
	for {
		_, ok := read_any(parser, values)
		// TODO: Introduce hard limit on iteration
		if !ok {
			return strings.substring(parser.source, start, parser.pos)
		}
	}
}

starts_with :: proc(parser: ^Parser, prefix: string) -> bool {
	slice, ok := strings.substring_from(parser.source, parser.pos)
	if !ok {
		return false
	}
	return strings.has_prefix(slice, prefix)
}

expect_string :: proc(parser: ^Parser, value: string) {
	_, ok := read(parser, value)
	if !ok {
		panic(fmt.tprintfln("Parsing failed. Did not get expected %s", value))
	}
}
expect_rune :: proc(parser: ^Parser, value: rune) {
	char, err := utf8.runes_to_string({value})
	defer delete(char)
	expect_string(parser, char)
}
expect :: proc{expect_string, expect_rune, expect_any}

expect_any :: proc(parser: ^Parser, values: []string) {
	_, ok := read_any(parser, values)
	if !ok {
		panic(fmt.tprintfln("Parsing failed. Did not get expected %v:\n%s", values, mark_source(parser)))
	}
}

mark_source :: proc(parser: ^Parser, length := 1) -> string {
	ANSI_BOLD :: ansi.CSI + ansi.BOLD + ansi.SGR
	ANSI_RED:: ansi.CSI + ansi.FG_RED + ansi.SGR
	ANSI_RESET :: ansi.CSI + ansi.RESET + ansi.SGR
	COLUMNS :: 80
	MARKING_SYMBOLS :: 2
	padding := (COLUMNS - MARKING_SYMBOLS - length) / 2
	start := math.max(0, parser.pos - padding)
	end := math.min(parser.rune_count, parser.pos + padding)

	prefix, postfix: string
	if start >= 3 {
		start += 3
		prefix = "..."
	}
	if end <= parser.rune_count - 3 {
		end -= 3
		postfix = "..."
	}

	pre_slice, pre_ok := strings.substring(parser.source, start, parser.pos)
	current_slice, curr_ok := strings.substring(parser.source, parser.pos, parser.pos + 1)
	post_slice, post_ok := strings.substring(parser.source, parser.pos + 1, end)
	if !pre_ok || !curr_ok || !post_ok {
		panic("mark_source tried to mark invalid range!")
	}
	return fmt.tprintf("%s%s%s%s[%s]%s%s%s%s%s",
		prefix, ANSI_RED, pre_slice,
		ANSI_BOLD, current_slice, ANSI_RESET,
		ANSI_RED, post_slice, ANSI_RESET, postfix,
	)
}

mark_unclosed_tag :: proc(parser: ^Parser, tag_start: int) -> string {
	ANSI_RED:: ansi.CSI + ansi.FG_RED + ansi.SGR
	ANSI_RESET:: ansi.CSI + ansi.RESET + ansi.SGR
	COLUMNS :: 80
	SPLICE_INFIX :: " ... "

	if tag_start - parser.pos <= 80 {
		slice, ok := strings.substring(parser.source, tag_start, parser.pos)
		if !ok {
			panic("mark_unclosed_tag tried to mark invalid range!")
		}
		return slice
	}
	length := (COLUMNS / 2) - utf8.rune_count(SPLICE_INFIX)
	start_slice, start_ok := strings.substring(parser.source, tag_start, tag_start + length)
	end_slice, end_ok := strings.substring(parser.source, parser.pos - length, parser.pos)
	if !start_ok || !end_ok {
		panic("mark_unclosed_tag tried to mark invalid ranges!")
	}
	return fmt.tprintf("%s%s%s%s%s",
		ANSI_RED, start_slice, SPLICE_INFIX, end_slice, ANSI_RESET
	)
}