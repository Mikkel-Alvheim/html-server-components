package main
import "core:os"
import "core:unicode/utf8/utf8string"
import "core:terminal/ansi"
import "core:math"
import "core:unicode/utf8"
import "core:fmt"
import "core:strings"

ANSI_WARN :: ansi.CSI + ansi.FG_YELLOW + ansi.SGR
ANSI_RESET :: ansi.CSI + ansi.RESET + ansi.SGR

/*
void_el_name = "area" | "base" | "col" | "embed" | "hr" | "img"
| "input" | "link" | "meta" | "source" | "track" | "wbr"

EBNF:
document = {template | text}
template = template_open content template_close
template_open = "<" template \s {\s} "id=" '"' cust_el_name '"' {\s} ">"
template_close = "</" {\s} "template" {\s} ">"
content = {text-content | placeholder | element}
element = normal_el | void_el | foreign_el
text = "..." - {"<" | "%"}
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
attribute = attribute_name ["=" '"' "... '"']

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
ds_bind_mod = ds_case_mod | "__prop." property | "__event." event
ds_init_mod =  [ds_case_mod] ["__viewtransition"]
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
| "threshold." \d [\d]
| ds_delay_mod
| ds_debounce_mod
| ds_throttle_mod
| ds_viewtransition_mod
ds_on_interval_mod = ds_duration_mod | ds_viewtransition_mod
ds_on_signal_patch_mod = ds_delay_mod | ds_debounce_mod | ds_throttle_mod

ds_attr_signal = ":" "attribute_name"
ds_expr = '"' "..." '"'

ds_need_expr_attr = (
	| "attr" [ds_attr_signal]
	| "class" [ds_attr_signal] [ds_case_mod]
	| "computed" [ds_attr_signal] [ds_case_mod]
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
START_TAG_OPEN :: '<'
END_TAG_OPEN :: "</"
TAG_CLOSE :: '>'
SOLIDUS :: '/'
START_TAG_SELF_CLOSE :: "/>"
BRACKET_OPEN :: '{'
BRACKET_CLOSE :: '}'
ATTR_INFIX :: '='
VOID_EL_NAMES :: []string {"area", "base", "col", "embed", "hr", "img",
	"input", "link", "meta", "source", "track", "wbr"
}

is_whitespace_ASCII :: proc(c: rune) -> bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f'
}
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
is_attr_value_delim :: proc(c: rune) -> bool {
	return c == '"' || c == '\''
}
is_unquoted_attr_value_delim :: proc(c: rune) -> bool {
	return is_whitespace_ASCII(c) || is_attr_value_delim(c) ||
	c == '=' || c == '<' || c == '>' || c == '`'
}
is_in_string :: proc(set: []string, test: string) -> bool {
	for v in set {
		if v == test {
			return true
		}
	}
	return false
}
is_in_rune :: proc(set: []rune, test: rune) -> bool {
	for v in set {
		if v == test {
			return true
		}
	}
	return false
}
is_in :: proc{is_in_string, is_in_rune}

Parser :: struct {
	source: ^utf8string.String, pos: int
}

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
	name: string, value: string
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

print_ast :: proc(root: ^Element) {
	print_element(root^, 0)
}

print_indent :: proc(depth: int) {
	for _ in 0..<depth {
		fmt.print("  ")
	}
}

// Prints a string with visible whitespace and escaped control characters.
// UTF-8 bytes outside the ASCII control range are preserved.
print_escaped :: proc(s: string) {
	fmt.print("\"")

	for i in 0..<len(s) {
		b := s[i]

		switch b {
		case 0x22: // "
			fmt.print("\\\"")
		case 0x5c: // backslash
			fmt.print("\\\\")
		case 0x0a: // newline
			fmt.print("\\n")
		case 0x0d: // carriage return
			fmt.print("\\r")
		case 0x09: // tab
			fmt.print("\\t")
		case 0x00:
			fmt.print("\\0")
		case:
			if b < 0x20 || b == 0x7f {
				fmt.printf("\\x%02X", b)
			} else {
				fmt.print(s[i:i+1])
			}
		}
	}

	fmt.print("\"")
}

print_element :: proc(el: Element, depth: int) {
	print_indent(depth)

	if el.name == "document" {
		fmt.printfln("Document")
	} else {
		fmt.printf("Element: <%s> (%v)\n", el.name, el.type)
	}

	// Attributes
	for attr in el.attributes {
		print_indent(depth + 1)
		fmt.printf("Attribute: %s = ", attr.name)
		print_escaped(attr.value)
		fmt.print("\n")
	}

	// Child nodes
	for node in el.content {
		print_node(node, depth + 1)
	}
}

print_node :: proc(node: Node, depth: int) {
	switch value in node {
	case Element:
		print_element(value, depth)

	case Text:
		print_indent(depth)
		fmt.print("Text: ")
		print_escaped(value.source)
		fmt.print("\n")

	case Placeholder:
		print_indent(depth)
		fmt.print("Placeholder: ")
		print_escaped(value.expression)
		fmt.print("\n")
	}
}

main :: proc() {
	for arg, i in os.args {
		fmt.printf("%d: %s\n", i, arg)
	}
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
		read_while(parser, is_whitespace_ASCII)
		if at_end(parser) {
			break
		}
		parse_children(parser, &document)
		fmt.printfln("Left parse_children in parse_document. current pos: %d", parser.pos)
	}
	print_ast(&document)
}

parse_element :: proc(parser: ^Parser, element: ^Element) {
	parse_start_tag(parser, element)
	fmt.printfln("Left parse_start_tag. current pos: %d", parser.pos)
	if element.type == .Normal {
		parse_children(parser, element)
		fmt.printfln("Left parse_children. current pos: %d", parser.pos)
	}
}

parse_children :: proc(p: ^Parser, parent: ^Element) {
	iteration := 0
	fmt.printfln("Starting loop in comment section of parse_non_html_tag.")
	for {
		if at_end(p) {
			break
		}
		char := peek(p)
		subsequent_char := peek(p, 1)
		fmt.printfln("iteration: %d, pos: %v (%d)",
			iteration, char, p.pos
		)
		switch {
		case char == START_TAG_OPEN && subsequent_char == SOLIDUS:
			parse_end_tag(p, parent)
			fmt.printfln("Left parse_close_tag. current pos: %d", p.pos)
			return
		case char == START_TAG_OPEN && subsequent_char == '!':
			append(&parent.content, parse_non_html_tag(p))
			fmt.printfln("Left parse_non_html_tag. current pos: %d", p.pos)
		case char == START_TAG_OPEN:
			child: Element
			parse_element(p, &child)
			append(&parent.content, child)
			fmt.printfln("Left parse_element. current pos: %d", p.pos)
		case char == PLACEHOLDER_DELIM && subsequent_char == BRACKET_OPEN:
			append(&parent.content, parse_placeholder(p))
			fmt.printfln("Left parse_placeholder. current pos: %d", p.pos)
		case:
			append(&parent.content, parse_text(p))
			fmt.printfln("Left parse_text. current pos: %d", p.pos)
		}
		iteration += 1
	}
}

parse_non_html_tag :: proc(p: ^Parser) -> Text {
	fmt.printfln("Entered parse_non_html_tag. current pos: %d", p.pos)
	tag_close_char := utf8.runes_to_string({TAG_CLOSE})
	defer delete(tag_close_char)

	start := p.pos
	opens_comment := read(p, "<!--")
	if opens_comment {
		fmt.printfln("Starting loop in comment section of parse_non_html_tag.")
		for closes_comment := false; !closes_comment; p.pos += 1 {
			read_until_rune(p, '-')
			closes_comment = read(p, "-->")
		}
		return {source = utf8string.slice(p.source, start, p.pos)}
	}

	return {source = read_until_rune(p, TAG_CLOSE, inclusive = true)}
}

parse_start_tag :: proc(p: ^Parser, el: ^Element) {
	fmt.printfln("Entered parse_open_tag. current pos: %d", p.pos)
	expect(p, START_TAG_OPEN)
	el.name = parse_name_HTML(p)
	el.type = is_in(VOID_EL_NAMES, el.name) ? .Void : .Normal
	for {
		space := read_while(p, is_whitespace_ASCII)
		switch peek(p) {
		case TAG_CLOSE:
			expect(p, TAG_CLOSE)
			return
		case SOLIDUS:
			expect(p, START_TAG_SELF_CLOSE)
			if el.type == .Void {
				fmt.printfln(
					"%sElement %s has a solidus before its closing. This marks foreign elements as self closing, but <%s> is a void element where, although permitted, has no effect and may cause bugs if directly preceded by an unquoted attribute value. %s\n:%s",
					ANSI_WARN, el.name, el.name, ANSI_RESET, mark_source(p)
				)
			}
			else {
				// TODO: We assume that the element is foreign here, but it might be a
				// normal element, in which case self closing is invalid HTML.
				el.type = .Foreign
			}
			return
		case:
			if space == "" {
				panic(fmt.tprintfln(
					"Missing closing tag or space between attributes:\n%v",
					mark_source(p)
				))
			}
			append(&el.attributes, parse_attribute(p))
		}
	}
}

parse_end_tag :: proc(p: ^Parser, el: ^Element) {
	fmt.printfln("Entered parse_close_tag. current pos: %d", p.pos)
	expect(p, END_TAG_OPEN)
	name := parse_name_HTML(p)
	if name != el.name {
		panic(fmt.tprintfln("Closing tag %v tried to close element %v", name, el.name))
	}
	read_while(p, is_whitespace_ASCII)
	expect(p, TAG_CLOSE)
}

parse_name_HTML :: proc(p: ^Parser) -> string {
	fmt.printfln("Entered parse_name_html. current pos: %d", p.pos)
	start_pos: = p.pos
	expect(p, is_lower_ASCII, "lowercase")
	read_while(p, is_name_char_HTML)
	return utf8string.slice(p.source, start_pos, p.pos)
}

// TODO: does not capture placeholders atm.
parse_attribute :: proc(p: ^Parser) -> Attribute {
	fmt.printfln("Entered parse_attribute. current pos: %d", p.pos)
	name := parse_name_HTML(p)
	read_while(p, is_whitespace_ASCII)
	value: string
	char := peek(p)
	if peek(p) == ATTR_INFIX {
		expect(p, ATTR_INFIX)
		read_while(p, is_whitespace_ASCII)
		if is_attr_value_delim(peek(p)) {
			delim_char := read(p)
		 	value = read_until(p, delim_char)
			expect(p, delim_char)
		}
		else {
			value = read_until(p, is_unquoted_attr_value_delim,
				"unquoted attribute value delimiter"
			)
			p.pos += 1
		}
	}
	return {name, value}
}

parse_placeholder :: proc(p: ^Parser) -> Placeholder {
	fmt.printfln("Entered parse_placeholder. current pos: %d", p.pos)

	expect(p, PLACEHOLDER_DELIM)
	expect(p, BRACKET_OPEN)
	start := p.pos
	nesting :u8 = 0
	fmt.printfln("Starting loop in parse_placeholder.")
	for char := read(p); char != BRACKET_CLOSE || nesting != 0; char = read(p) {
		if char == utf8.RUNE_EOF {
			panic("Missing closing bracket for placeholder.")
		}
		if char == BRACKET_OPEN {
			nesting += 1
		}
		else if char == BRACKET_CLOSE {
			nesting -= 1
		}
	}
	// We avoid returning closing '}', but still consume it.
	return {expression = utf8string.slice(p.source, start, p.pos - 1)}
}

parse_text :: proc(p: ^Parser) -> Text {
	fmt.printfln("Entered parse_text. current pos: %d", p.pos)

	start := p.pos
	fmt.printfln("Starting loop in parse_text.")
	for char := peek(p); char != START_TAG_OPEN && (char != PLACEHOLDER_DELIM && peek(p, 1) != BRACKET_OPEN); char = peek(p) {
		fmt.printfln("char: %v", char)
		if at_end(p) {
			break
		}
		p.pos += 1
	}
	return {source = utf8string.slice(p.source, start, p.pos)}
}

at_end :: proc(p: ^Parser, offset := 0) -> bool {
	return p.pos + offset >= p.source.rune_count
}

peek :: proc(p: ^Parser, offset := 0) -> rune {
	return at_end(p, offset) ? utf8.RUNE_EOF : utf8string.at(p.source, p.pos + offset)
}

read_next :: proc(p: ^Parser) -> rune {
	char := peek(p)
	if char != utf8.RUNE_EOF {
		p.pos += 1
	}
	return char

}
read_string :: proc(p: ^Parser, s: string) -> bool {
	length := utf8.rune_count(s)
	if at_end(p, length) || utf8string.slice(p.source, p.pos, p.pos + length) != s {
		return false
	}
	p.pos += length
	return true
}
read_rune :: proc(parser: ^Parser, c: rune) -> bool {
	if peek(parser) != c {
		return false
	}
	parser.pos += 1
	return true
}
read :: proc{read_next, read_string, read_rune}

read_until_rune :: proc(p: ^Parser, delimiter: rune, inclusive := false) -> string {
	start := p.pos
	fmt.printfln("Starting loop in read_until_rune.")
	for char := peek(p); char != delimiter; char = peek(p) {
		if char == utf8.RUNE_EOF {
			panic(fmt.tprintfln("Missing closing delimiter: %v\n%s",
				delimiter, mark_unclosed_tag(p, start)
			))
		}
		p.pos += 1
	}
	if inclusive {
		p.pos += 1
	}
	return utf8string.slice(p.source, start, p.pos)
}
read_until_predicate :: proc(
	p: ^Parser, predicate: proc(rune) -> bool, name: string, inclusive := false
) -> string{
	start := p.pos
	fmt.printfln("Starting loop in read_until_predicate.")
	for char := peek(p); !predicate(char); char = peek(p) {
		if char == utf8.RUNE_EOF {
			panic(fmt.tprintfln("Missing closing delimiter: %v\n%s",
				name, mark_unclosed_tag(p, start)
			))
		}
		p.pos += 1
	}
	if inclusive {
		p.pos += 1
	}
	return utf8string.slice(p.source, start, p.pos)
}
read_until :: proc{read_until_rune, read_until_predicate}

read_any :: proc(p: ^Parser, values: []string) -> (string, bool) {
	fmt.printfln("Starting loop in read_any.")
	for value in values {
		consumed := read(p, value)
		if consumed {
			return value, true
		}
	}
	return "", false
}
read_all :: proc(p: ^Parser, values: []string) -> string {
	start := p.pos
	fmt.printfln("Starting loop in read_all.")
	for {
		reading, consumed := read_any(p, values)
		// TODO: Introduce hard limit on iteration
		if !consumed {
			return utf8string.slice(p.source, start, p.pos)
		}
	}
}
read_while :: proc(p: ^Parser, predicate: proc(rune) -> bool) -> string {
	start := p.pos
	fmt.printfln("Starting loop in read_while.")
	for char := peek(p); char != utf8.RUNE_EOF && predicate(char); char = peek(p) {
		p.pos += 1
	}
	return utf8string.slice(p.source, start, p.pos)
}
//
// starts_with :: proc(parser: ^Parser, prefix: string) -> bool {
// 	slice, ok := strings.substring_from(parser.source, parser.pos)
// 	if !ok {
// 		return false
// 	}
// 	return strings.has_prefix(slice, prefix)
// }

expect_string :: proc(p: ^Parser, s: string) {
	consumed := read(p, s)
	if !consumed {
		panic(fmt.tprintfln("Parsing failed. Did not get expected %s", s))
	}
}
expect_rune :: proc(p: ^Parser, c: rune) {
	consumed := read(p, c)
	if !consumed {
		panic(fmt.tprintfln("Parsing failed. Did not get expected %v", c))
	}
}
expect_if :: proc(p: ^Parser, predicate: proc(rune) -> bool, name: string) {
	c := peek(p)
	if c == utf8.RUNE_EOF || !predicate(c) {
		panic(fmt.tprintfln(
			"Parsing failed. Did not get expected %s", name
		))
	}
	p.pos += 1
}
expect_any :: proc(p: ^Parser, values: []string) {
	reading, consumed := read_any(p, values)
	if !consumed {
		panic(fmt.tprintfln("Parsing failed. Did not get expected %v:\n%s", values, mark_source(p)))
	}
}
expect :: proc{expect_string, expect_rune, expect_if, expect_any}

mark_source :: proc(p: ^Parser, length := 1) -> string {
	ANSI_BOLD :: ansi.CSI + ansi.BOLD + ansi.SGR
	ANSI_RED:: ansi.CSI + ansi.FG_RED + ansi.SGR
	ANSI_RESET :: ansi.CSI + ansi.RESET + ansi.SGR
	COLUMNS :: 80
	MARKING_SYMBOLS :: 2
	padding := (COLUMNS - MARKING_SYMBOLS - length) / 2
	start := math.max(0, p.pos - padding)
	end := math.min(p.source.rune_count, p.pos + padding)

	prefix, postfix: string
	if start >= 3 {
		start += 3
		prefix = "..."
	}
	if end <= p.source.rune_count - 3 {
		end -= 3
		postfix = "..."
	}

	pre_slice := utf8string.slice(p.source, start, p.pos)
	current_slice := utf8string.slice(p.source, p.pos, p.pos + length)
	post_slice := utf8string.slice(p.source, p.pos + length, end)

	return fmt.tprintf("%s%s%s%s[%s]%s%s%s%s%s",
		prefix, ANSI_RED, pre_slice,
		ANSI_BOLD, current_slice, ANSI_RESET,
		ANSI_RED, post_slice, ANSI_RESET, postfix,
	)
}

mark_unclosed_tag :: proc(p: ^Parser, tag_start: int) -> string {
	ANSI_RED:: ansi.CSI + ansi.FG_RED + ansi.SGR
	ANSI_RESET:: ansi.CSI + ansi.RESET + ansi.SGR
	COLUMNS :: 80
	SPLICE_INFIX :: " ... "

	if p.pos - tag_start <= 80 {
		return utf8string.slice(p.source, tag_start, p.pos)
	}
	length := (COLUMNS / 2) - utf8.rune_count(SPLICE_INFIX)
	start_slice := utf8string.slice(p.source, tag_start, tag_start + length)
	end_slice := utf8string.slice(p.source, p.pos - length, p.pos)

	return fmt.tprintf("%s%s%s%s%s",
		ANSI_RED, start_slice, SPLICE_INFIX, end_slice, ANSI_RESET
	)
}