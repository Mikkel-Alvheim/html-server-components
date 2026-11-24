package main
import "core:unicode/utf8/utf8string"
import "core:terminal/ansi"
import "core:math"
import "core:unicode/utf8"
import "core:fmt"

ANSI_MAGENTA :: ansi.CSI + ansi.FG_MAGENTA + ansi.SGR
ANSI_INFO :: ansi.CSI + ansi.FG_BLUE + ansi.SGR
ANSI_OK :: ansi.CSI + ansi.FG_GREEN + ansi.SGR
ANSI_WARN :: ansi.CSI + ansi.FG_YELLOW + ansi.SGR
ANSI_ERR :: ansi.CSI + ansi.FG_RED + ansi.SGR
ANSI_BOLD :: ansi.CSI + ansi.BOLD + ansi.SGR
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

Parser :: struct {
	source: ^utf8string.String, pos: int
}

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

print_tab :: proc(depth: int) {
	for _ in 0..<depth {
		fmt.print("\t")
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

print_element :: proc(el: Element, depth := 0, formatting := ANSI_RESET) {
	print_tab(depth)

	if el.name == "document" {
		fmt.printfln("Document")
	} else {
		fmt.printf("%sElement:%s <%s> (%v)\n",
			formatting, ANSI_RESET, el.name, el.type
		)
	}

	for attr in el.attributes {
		print_tab(depth + 1)
		fmt.printf("%sAttribute:%s %s = ", formatting, ANSI_RESET, attr.name)
		print_escaped(attr.value)
		fmt.print("\n")
	}

	for node in el.content {
		print_node(node, depth + 1)
	}
}

print_node :: proc(node: Node, depth := 0, formatting := ANSI_RESET) {
	switch value in node {
	case Element:
		print_element(value, depth, formatting)
	case Text:
		print_tab(depth)
		fmt.printf("%sText:%s ", formatting, ANSI_RESET)
		print_escaped(value.source)
		fmt.print("\n")
	case Placeholder:
		print_tab(depth)
		fmt.printf("%sPlaceholder:%s ", formatting, ANSI_RESET)
		print_escaped(value.expression)
		fmt.print("\n")
	}
}

parse_document :: proc(parser: ^Parser) -> Element {
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
	print_element(document, formatting = ANSI_INFO)
	return document
}

parse_element :: proc(parser: ^Parser, element: ^Element) {
	parse_start_tag(parser, element)
	if element.type == .Normal {
		parse_children(parser, element)
	}
	print_element(element^, formatting = ANSI_OK)
}

parse_children :: proc(p: ^Parser, parent: ^Element) {
	iteration := 0
	fmt.printfln("Starting loop in parse_children.")
	for {
		if at_end(p) {
			break
		}
		char := peek(p)
		subsequent_char := peek(p, 1)

		char_string := utf8.runes_to_string({char})
		defer delete(char_string)
		fmt.printf("\n%siteration: %d, pos: %d (", ANSI_MAGENTA, iteration, p.pos)
		print_escaped(char_string)
		fmt.printf(")%s\n", ANSI_RESET)

		switch {
		case char == START_TAG_OPEN && subsequent_char == SOLIDUS:
			parse_end_tag(p, parent)
			return
		case char == START_TAG_OPEN && subsequent_char == '!':
			append(&parent.content, parse_non_html_tag(p))
		case char == START_TAG_OPEN:
			child: Element
			parse_element(p, &child)
			append(&parent.content, child)
		case char == PLACEHOLDER_DELIM && subsequent_char == BRACKET_OPEN:
			append(&parent.content, parse_placeholder(p))
		case:
			append(&parent.content, parse_text(p))
		}
		iteration += 1
	}
}

parse_non_html_tag :: proc(p: ^Parser) -> Text {
	fmt.printfln("Entered parse_non_html_tag. current pos: %d", p.pos)
	tag_close_char := utf8.runes_to_string({TAG_CLOSE})
	defer delete(tag_close_char)
	text: Text

	start := p.pos
	opens_comment := read(p, "<!--")
	if opens_comment {
		fmt.printfln("Starting loop in comment section of parse_non_html_tag.")
		for closes_comment := false; !closes_comment; p.pos += 1 {
			read_until_rune(p, '-')
			closes_comment = read(p, "-->")
		}
		text.source = utf8string.slice(p.source, start, p.pos)
	}
	else {
		text.source = read_until_rune(p, TAG_CLOSE, inclusive = true)
	}
	fmt.printfln("%sNon-html tag:%s %s", ANSI_OK, ANSI_RESET, text.source)
	return text
}

parse_start_tag :: proc(p: ^Parser, el: ^Element) {
	fmt.printfln("Entered parse_start_tag. current pos: %d", p.pos)
	start := p.pos
	expect(p, START_TAG_OPEN)
	el.name = parse_el_name(p)
	el.type = is_in(VOID_EL_NAMES, el.name) ? .Void : .Normal
	for {
		space := read_while(p, is_whitespace_ASCII)
		switch peek(p) {
		case TAG_CLOSE:
			expect(p, TAG_CLOSE)
			fmt.printfln("%sStart tag:%s %v\n\ttype: %v\n\tattr:%v",
				ANSI_OK, ANSI_RESET, el.name, el.type, el.attributes[:],
			)
			return
		case SOLIDUS:
			expect(p, START_TAG_SELF_CLOSE)
			if el.type == .Void {
				fmt.printfln(
					"%sElement %s has a solidus before its closing. This marks foreign elements as self closing, but <%s> is a void element where, although permitted, has no effect and may cause bugs if directly preceded by an unquoted attribute value. %s\n:%s",
					ANSI_WARN, el.name, el.name, ANSI_RESET, mark_source(p, start)
				)
			}
			else {
				// TODO: We assume that the element is foreign here, but it might be a
				// normal element, in which case self closing is invalid HTML.
				el.type = .Foreign
			}
		case:
			if space == "" {
				panic(fmt.tprintfln(
					"Missing closing tag or space between attributes:\n%v",
					mark_source(p, start)
				))
			}
			append(&el.attributes, parse_attribute(p))
		}
	}
}

parse_end_tag :: proc(p: ^Parser, el: ^Element) {
	fmt.printfln("Entered parse_close_tag. current pos: %d", p.pos)
	expect(p, END_TAG_OPEN)
	name := parse_el_name(p)
	if name != el.name {
		panic(fmt.tprintfln("Closing tag %v tried to close element %v", name, el.name))
	}
	read_while(p, is_whitespace_ASCII)
	expect(p, TAG_CLOSE)
	fmt.printfln("%sClosing tag:%s %s", ANSI_OK, ANSI_RESET, name)
}

parse_el_name :: proc(p: ^Parser) -> string {
	fmt.printfln("Entered parse_name_html. current pos: %d", p.pos)
	start_pos := p.pos
	expect(p, is_lower_ASCII, "lowercase")
	read_while(p, is_el_name_char)
	name := utf8string.slice(p.source, start_pos, p.pos)
	fmt.printfln("%sElement name:%s %s", ANSI_OK, ANSI_RESET, name)
	return name
}

parse_attribute_name :: proc(p: ^Parser, a: ^Attribute) {
	fmt.printfln("Entered parse_attribute_name. current pos: %d", p.pos)
	start := p.pos
	prev_end := p.pos
	for {
		read_while(p, is_attr_name_char)
		if peek(p) == PLACEHOLDER_DELIM {
			if p.pos != prev_end {
				slice: Text = {source = utf8string.slice(
					p.source, prev_end, p.pos
				)}
				append(&a.name_slices, slice)
			}
			append(&a.name_slices, parse_placeholder(p))
			prev_end = p.pos
		}
		else {
			break
		}
	}
	if start == p.pos {
		panic("Parse_attribute_name got 0 valid characters.")
	}
	else if p.pos != prev_end {
		slice: Text = {source = utf8string.slice(
			p.source, prev_end, p.pos
		)}
		append(&a.name_slices, slice)
	}
	a.name = utf8string.slice(p.source, start, p.pos)
	fmt.printfln("%sAttribute%s name: %s\nSlices:%v",
		ANSI_OK, ANSI_RESET, a.name, a.name_slices[:]
	)
}

parse_attribute :: proc(p: ^Parser) -> Attribute {
	fmt.printfln("Entered parse_attribute. current pos: %d", p.pos)
	attribute: Attribute
	parse_attribute_name(p, &attribute)
	read_while(p, is_whitespace_ASCII)
	char := peek(p)
	if peek(p) == ATTR_INFIX {
		expect(p, ATTR_INFIX)
		read_while(p, is_whitespace_ASCII)
		if is_quoted(peek(p)) {
			parse_quoted(p, &attribute)
		}
		else {
			parse_unqoted(p, &attribute)
		}
	}
	fmt.printfln("%sAttribute:%s %v", ANSI_OK, ANSI_RESET, attribute)
	return attribute
}

parse_quoted :: proc(p: ^Parser, a: ^Attribute) {
	delim_char := read(p)
	start := p.pos
	previous_end := p.pos
	fmt.printfln("Entered parse_quoted. Delimiter: [%v]. Current pos: %d",
		delim_char, start
	)
	next := peek(p)
	following := peek(p, 1)
	fmt.println("Starting loop in parse_quoted")
	for {
		if is_placeholder_delim(next, following) {
			if p.pos != previous_end {
				// Store preceeding section.
				slice: Text = {source = utf8string.slice(
					p.source, previous_end, p.pos
				)}
				append(&a.value_slices, slice)
			}
			append(&a.value_slices, parse_placeholder(p))
			previous_end = p.pos
		}
		else if next == delim_char {
			break
		}
		else {
			p.pos += 1
		}
		next = peek(p)
		following = peek(p, 1)
	}
 	if p.pos != previous_end {
		slice: Text = {source = utf8string.slice(
			p.source, previous_end, p.pos
		)}
		append(&a.value_slices, slice)
	}
	a.value = utf8string.slice(p.source, start, p.pos)
	expect(p, delim_char)
	fmt.printfln("%sQuoted attribute value: %s%s", ANSI_OK, a.value, ANSI_RESET)
}

parse_unqoted :: proc(p: ^Parser, a: ^Attribute) {
	fmt.printfln("Entered parse_unquoted. current pos: %d", p.pos)
	a.value = read_until(p, is_unquoted_attr_value_delim,
		"unquoted attribute value delimiter"
	)
	slice: Text = {source = a.value}
	append(&a.value_slices, slice)
	// '<' should be consumed by caller.
	if !is_el_close_delim(peek(p)) {
		p.pos += 1
	}
	fmt.printfln("%sUnqoted attribute value: %s%s", ANSI_OK, a.value, ANSI_RESET)
}

parse_placeholder :: proc(p: ^Parser) -> Placeholder {
	fmt.printfln("Entered parse_placeholder. current pos: %d", p.pos)

	expect(p, PLACEHOLDER_DELIM)
	expect(p, BRACKET_OPEN)
	start := p.pos
	nesting :u8 = 0
	fmt.println("Starting loop in parse_placeholder")
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
	placeholder : Placeholder = {
		expression = utf8string.slice(p.source, start, p.pos - 1)
	}
	print_node(placeholder, formatting = ANSI_OK)
	// fmt.printfln("%sPlaceholder expression:%s %s", ANSI_OK, ANSI_RESET, placeholder.expression)
	return placeholder
}

parse_text :: proc(p: ^Parser) -> Text {
	fmt.printfln("Entered parse_text. current pos: %d", p.pos)

	start := p.pos
	fmt.println("Starting loop in parse_text")
	for char := peek(p); char != START_TAG_OPEN && (char != PLACEHOLDER_DELIM && peek(p, 1) != BRACKET_OPEN); char = peek(p) {
		if at_end(p) {
			break
		}
		p.pos += 1
	}
	text: Text = {source = utf8string.slice(p.source, start, p.pos)}
	print_node(text, formatting = ANSI_OK)
	// fmt.printfln("%sParsed text:%s \"%s\"", ANSI_OK, ANSI_RESET, text.source)
	return text
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
	fmt.println("Starting loop in read_until_rune")
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
	consumed := utf8string.slice(p.source, start, p.pos)
	fmt.printf("%sRead:%s ", ANSI_INFO, ANSI_RESET)
	print_escaped(consumed)
	fmt.print("\n")
	return consumed
}
read_until_predicate :: proc(
	p: ^Parser, predicate: proc(rune) -> bool, name: string, inclusive := false
) -> string {
	start := p.pos
	fmt.printfln("Starting loop in read_until_predicate for %s", name)
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
	consumed := utf8string.slice(p.source, start, p.pos)
	fmt.printf("%sRead:%s ", ANSI_INFO, ANSI_RESET)
	print_escaped(consumed)
	fmt.print("\n")
	return consumed
}
read_until :: proc{read_until_rune, read_until_predicate}

read_any :: proc(p: ^Parser, values: []string) -> (string, bool) {
	fmt.println("Starting loop in read_any")
	for value in values {
		consumed := read(p, value)
		if consumed {
			fmt.printf("%sRead:%s ", ANSI_INFO, ANSI_RESET)
			print_escaped(value)
			fmt.print("\n")
			return value, true
		}
	}
	fmt.printfln("%sDid not read anything%s", ANSI_INFO, ANSI_RESET)
	return "", false
}
read_all :: proc(p: ^Parser, values: []string) -> string {
	start := p.pos
	fmt.println("Starting loop in read_all")
	for {
		reading, consumed := read_any(p, values)
		// TODO: Introduce hard limit on iteration
		if !consumed {
			consumed_text := utf8string.slice(p.source, start, p.pos)
			fmt.printf("%sRead:%s ", ANSI_INFO, ANSI_RESET)
			print_escaped(consumed_text)
			fmt.print("\n")
			return consumed_text
		}
	}
}
read_while :: proc(p: ^Parser, predicate: proc(rune) -> bool) -> string {
	start := p.pos
	fmt.println("Starting loop in read_while")
	for char := peek(p); char != utf8.RUNE_EOF && predicate(char); char = peek(p) {
		p.pos += 1
	}
	consumed_text := utf8string.slice(p.source, start, p.pos)
	if consumed_text != "" {
		fmt.printf("%sRead:%s ", ANSI_INFO, ANSI_RESET)
		print_escaped(consumed_text)
		fmt.print("\n")
	}
	else {
		fmt.printfln("%sDid not read anything%s", ANSI_INFO, ANSI_RESET)
	}
	return consumed_text
}

expect_string :: proc(p: ^Parser, s: string) {
	if !read(p, s) {
		panic(fmt.tprintfln("Parsing failed. Did not get expected %s", s))
	}
}
expect_rune :: proc(p: ^Parser, c: rune) {
	if !read(p, c) {
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
expect_any :: proc(p: ^Parser, values: []string) -> string {
	reading, consumed := read_any(p, values)
	if !consumed {
		panic(fmt.tprintfln("Parsing failed. Did not get expected %v:\n%s", values, mark_source(p, p.pos)))
	}
	return reading
}
expect :: proc{expect_string, expect_rune, expect_if, expect_any}

mark_source :: proc(p: ^Parser, syntax_start: int, mark_length: int = 1) -> string {
	COLUMNS :: 80
	MARKING_SYMBOLS :: 2
	padding := (COLUMNS - MARKING_SYMBOLS - mark_length) / 2
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

	pre_slice := utf8string.slice(p.source, start, syntax_start)
	unmarked_slice := utf8string.slice(p.source, syntax_start, p.pos)
	current_slice := utf8string.slice(p.source, p.pos, p.pos + mark_length)
	post_slice := utf8string.slice(p.source, p.pos + mark_length, end)

	return fmt.tprintf("%s%s%s%s%s[%s]%s%s%s",
		prefix, pre_slice, ANSI_ERR, unmarked_slice, ANSI_BOLD,
		current_slice, ANSI_RESET, post_slice, postfix,
	)
}

mark_unclosed_tag :: proc(p: ^Parser, tag_start: int) -> string {
	COLUMNS :: 80
	SPLICE_INFIX :: " ... "

	if p.pos - tag_start <= 80 {
		return utf8string.slice(p.source, tag_start, p.pos)
	}
	length := (COLUMNS / 2) - utf8.rune_count(SPLICE_INFIX)
	start_slice := utf8string.slice(p.source, tag_start, tag_start + length)
	end_slice := utf8string.slice(p.source, p.pos - length, p.pos)

	return fmt.tprintf("%s%s%s%s%s",
		ANSI_ERR, start_slice, SPLICE_INFIX, end_slice, ANSI_RESET
	)
}