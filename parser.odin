package main
import "core:unicode/utf8/utf8string"
import "core:terminal/ansi"
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

parse_document :: proc(scan: ^Scanner) -> Element {
	document: Element = {
		name = "document"
	}
	for !at_end(scan) {
		read_while(scan, is_whitespace_ASCII)
		if at_end(scan) {
			break
		}
		parse_children(scan, &document)
		fmt.printfln("Left parse_children in parse_document. current pos: %d", scan.pos)
	}
	print_element(document, formatting = ANSI_INFO)
	return document
}

parse_element :: proc(scan: ^Scanner, element: ^Element) {
	parse_start_tag(scan, element)
	if element.type == .Normal {
		parse_children(scan, element)
	}
	print_element(element^, formatting = ANSI_OK)
}

parse_children :: proc(scan: ^Scanner, parent: ^Element) {
	iteration := 0
	fmt.printfln("Starting loop in parse_children.")
	for {
		if at_end(scan) {
			break
		}
		char := peek(scan)
		subsequent_char := peek(scan, 1)

		char_string := utf8.runes_to_string({char})
		defer delete(char_string)
		fmt.printf("\n%siteration: %d, pos: %d (", ANSI_MAGENTA, iteration, scan.pos)
		print_escaped(char_string)
		fmt.printf(")%s\n", ANSI_RESET)

		switch {
		case char == START_TAG_OPEN && subsequent_char == SOLIDUS:
			parse_end_tag(scan, parent)
			return
		case char == START_TAG_OPEN && subsequent_char == '!':
			append(&parent.content, parse_non_html_tag(scan))
		case char == START_TAG_OPEN:
			child: Element
			parse_element(scan, &child)
			append(&parent.content, child)
		case char == PLACEHOLDER_DELIM && subsequent_char == BRACKET_OPEN:
			append(&parent.content, parse_placeholder(scan))
		case:
			append(&parent.content, parse_text(scan))
		}
		iteration += 1
	}
}

parse_non_html_tag :: proc(scan: ^Scanner) -> Text {
	fmt.printfln("Entered parse_non_html_tag. current pos: %d", scan.pos)
	tag_close_char := utf8.runes_to_string({TAG_CLOSE})
	defer delete(tag_close_char)
	text: Text

	start := scan.pos
	opens_comment := read(scan, "<!--")
	if opens_comment {
		fmt.printfln("Starting loop in comment section of parse_non_html_tag.")
		for closes_comment := false; !closes_comment; scan.pos += 1 {
			read_until_rune(scan, '-')
			closes_comment = read(scan, "-->")
		}
		text.source = utf8string.slice(scan.source, start, scan.pos)
	}
	else {
		text.source = read_until_rune(scan, TAG_CLOSE, inclusive = true)
	}
	fmt.printfln("%sNon-html tag:%s %s", ANSI_OK, ANSI_RESET, text.source)
	return text
}

parse_start_tag :: proc(scan: ^Scanner, el: ^Element) {
	fmt.printfln("Entered parse_start_tag. current pos: %d", scan.pos)
	start := scan.pos
	expect(scan, START_TAG_OPEN)
	el.name = parse_el_name(scan)
	el.type = is_in(VOID_EL_NAMES, el.name) ? .Void : .Normal
	for {
		space := read_while(scan, is_whitespace_ASCII)
		switch peek(scan) {
		case TAG_CLOSE:
			expect(scan, TAG_CLOSE)
			fmt.printfln("%sStart tag:%s %v\n\ttype: %v\n\tattr:%v",
				ANSI_OK, ANSI_RESET, el.name, el.type, el.attributes[:],
			)
			return
		case SOLIDUS:
			expect(scan, START_TAG_SELF_CLOSE)
			if el.type == .Void {
				fmt.printfln(
					"%sElement %s has a solidus before its closing. This marks foreign elements as self closing, but <%s> is a void element where, although permitted, has no effect and may cause bugs if directly preceded by an unquoted attribute value. %s\n:%s",
					ANSI_WARN, el.name, el.name, ANSI_RESET, mark_source(scan, start)
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
					mark_source(scan, start)
				))
			}
			append(&el.attributes, parse_attribute(scan))
		}
	}
}

parse_end_tag :: proc(scan: ^Scanner, el: ^Element) {
	fmt.printfln("Entered parse_close_tag. current pos: %d", scan.pos)
	expect(scan, END_TAG_OPEN)
	name := parse_el_name(scan)
	if name != el.name {
		panic(fmt.tprintfln("Closing tag %v tried to close element %v", name, el.name))
	}
	read_while(scan, is_whitespace_ASCII)
	expect(scan, TAG_CLOSE)
	fmt.printfln("%sClosing tag:%s %s", ANSI_OK, ANSI_RESET, name)
}

parse_el_name :: proc(scan: ^Scanner) -> string {
	fmt.printfln("Entered parse_name_html. current pos: %d", scan.pos)
	start_pos := scan.pos
	expect(scan, is_lower_ASCII, "lowercase")
	read_while(scan, is_el_name_char)
	name := utf8string.slice(scan.source, start_pos, scan.pos)
	fmt.printfln("%sElement name:%s %s", ANSI_OK, ANSI_RESET, name)
	return name
}

parse_attribute_name :: proc(scan: ^Scanner, attr: ^Attribute) {
	fmt.printfln("Entered parse_attribute_name. current pos: %d", scan.pos)
	start := scan.pos
	prev_end := scan.pos
	for {
		read_while(scan, is_attr_name_char)
		if peek(scan) == PLACEHOLDER_DELIM {
			if scan.pos != prev_end {
				slice: Text = {source = utf8string.slice(
					scan.source, prev_end, scan.pos
				)}
				append(&attr.name_slices, slice)
			}
			append(&attr.name_slices, parse_placeholder(scan))
			prev_end = scan.pos
		}
		else {
			break
		}
	}
	if start == scan.pos {
		panic("Parse_attribute_name got 0 valid characters.")
	}
	else if scan.pos != prev_end {
		slice: Text = {source = utf8string.slice(
			scan.source, prev_end, scan.pos
		)}
		append(&attr.name_slices, slice)
	}
	attr.name = utf8string.slice(scan.source, start, scan.pos)
	fmt.printfln("%sAttribute%s name: %s\nSlices:%v",
		ANSI_OK, ANSI_RESET, attr.name, attr.name_slices[:]
	)
}

parse_attribute :: proc(scan: ^Scanner) -> Attribute {
	fmt.printfln("Entered parse_attribute. current pos: %d", scan.pos)
	attribute: Attribute
	parse_attribute_name(scan, &attribute)
	read_while(scan, is_whitespace_ASCII)
	char := peek(scan)
	if peek(scan) == ATTR_INFIX {
		expect(scan, ATTR_INFIX)
		read_while(scan, is_whitespace_ASCII)
		if is_quoted(peek(scan)) {
			parse_quoted(scan, &attribute)
		}
		else {
			parse_unqoted(scan, &attribute)
		}
	}
	fmt.printfln("%sAttribute:%s %v", ANSI_OK, ANSI_RESET, attribute)
	return attribute
}

parse_quoted :: proc(scan: ^Scanner, attr: ^Attribute) {
	delim_char := read(scan)
	start := scan.pos
	previous_end := scan.pos
	fmt.printfln("Entered parse_quoted. Delimiter: [%v]. Current pos: %d",
		delim_char, start
	)
	next := peek(scan)
	following := peek(scan, 1)
	fmt.println("Starting loop in parse_quoted")
	for {
		if is_placeholder_delim(next, following) {
			if scan.pos != previous_end {
				// Store preceeding section.
				slice: Text = {source = utf8string.slice(
					scan.source, previous_end, scan.pos
				)}
				append(&attr.value_slices, slice)
			}
			append(&attr.value_slices, parse_placeholder(scan))
			previous_end = scan.pos
		}
		else if next == delim_char {
			break
		}
		else {
			scan.pos += 1
		}
		next = peek(scan)
		following = peek(scan, 1)
	}
 	if scan.pos != previous_end {
		slice: Text = {source = utf8string.slice(
			scan.source, previous_end, scan.pos
		)}
		append(&attr.value_slices, slice)
	}
	attr.value = utf8string.slice(scan.source, start, scan.pos)
	expect(scan, delim_char)
	fmt.printfln("%sQuoted attribute value: %s%s", ANSI_OK, attr.value, ANSI_RESET)
}

parse_unqoted :: proc(scan: ^Scanner, attr: ^Attribute) {
	fmt.printfln("Entered parse_unquoted. current pos: %d", scan.pos)
	attr.value = read_until(scan, is_unquoted_attr_value_delim,
		"unquoted attribute value delimiter"
	)
	slice: Text = {source = attr.value}
	append(&attr.value_slices, slice)
	// '<' should be consumed by caller.
	if !is_el_close_delim(peek(scan)) {
		scan.pos += 1
	}
	fmt.printfln("%sUnqoted attribute value: %s%s", ANSI_OK, attr.value, ANSI_RESET)
}

parse_placeholder :: proc(scan: ^Scanner) -> Placeholder {
	fmt.printfln("Entered parse_placeholder. current pos: %d", scan.pos)

	expect(scan, PLACEHOLDER_DELIM)
	expect(scan, BRACKET_OPEN)
	start := scan.pos
	nesting :u8 = 0
	fmt.println("Starting loop in parse_placeholder")
	for char := read(scan); char != BRACKET_CLOSE || nesting != 0; char = read(scan) {
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
		expression = utf8string.slice(scan.source, start, scan.pos - 1)
	}
	print_node(placeholder, formatting = ANSI_OK)
	// fmt.printfln("%sPlaceholder expression:%s %s", ANSI_OK, ANSI_RESET, placeholder.expression)
	return placeholder
}

parse_text :: proc(scan: ^Scanner) -> Text {
	fmt.printfln("Entered parse_text. current pos: %d", scan.pos)

	start := scan.pos
	fmt.println("Starting loop in parse_text")
	for char := peek(scan); char != START_TAG_OPEN && (char != PLACEHOLDER_DELIM && peek(scan, 1) != BRACKET_OPEN); char = peek(scan) {
		if at_end(scan) {
			break
		}
		scan.pos += 1
	}
	text: Text = {source = utf8string.slice(scan.source, start, scan.pos)}
	print_node(text, formatting = ANSI_OK)
	// fmt.printfln("%sParsed text:%s \"%s\"", ANSI_OK, ANSI_RESET, text.source)
	return text
}