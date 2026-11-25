package main
import "core:fmt"
import "core:terminal/ansi"
import "core:unicode/utf8"
import "core:unicode/utf8/utf8string"
import "core:math"

Scanner :: struct {
	source: ^utf8string.String, pos: int
}

at_end :: proc(scan: ^Scanner, offset := 0) -> bool {
	return scan.pos + offset >= scan.source.rune_count
}

peek :: proc(scan: ^Scanner, offset := 0) -> rune {
	return at_end(scan, offset) ? utf8.RUNE_EOF : utf8string.at(scan.source, scan.pos + offset)
}

read_next :: proc(scan: ^Scanner) -> rune {
	char := peek(scan)
	if char != utf8.RUNE_EOF {
		scan.pos += 1
	}
	return char

}
read_string :: proc(scan: ^Scanner, match: string) -> bool {
	length := utf8.rune_count(match)
	if at_end(scan, length) || utf8string.slice(scan.source, scan.pos, scan.pos + length) != match {
		return false
	}
	scan.pos += length
	return true
}
read_rune :: proc(scan: ^Scanner, match: rune) -> bool {
	if peek(scan) != match {
		return false
	}
	scan.pos += 1
	return true
}
read :: proc{read_next, read_string, read_rune}

read_until_rune :: proc(
	scan: ^Scanner, delimiter: rune, inclusive := false
) -> string {
	start := scan.pos
	fmt.println("Starting loop in read_until_rune")
	for char := peek(scan); char != delimiter; char = peek(scan) {
		if char == utf8.RUNE_EOF {
			panic(fmt.tprintfln("Missing closing delimiter: %v\n%s",
				delimiter, mark_unclosed_tag(scan, start)
			))
		}
		scan.pos += 1
	}
	if inclusive {
		scan.pos += 1
	}
	consumed := utf8string.slice(scan.source, start, scan.pos)
	fmt.printf("%sRead:%s ", sgr(sgr(ANSI_INFO)), sgr(ansi.RESET))
	print_escaped(consumed)
	fmt.print("\n")
	return consumed
}

read_until_string :: proc(
	scan: ^Scanner, delimiter: string, inclusive := false
) -> string {
	start := scan.pos
	fmt.println("Starting loop in read_until_string")
	for !read(scan, delimiter) {
		scan.pos += 1
	}
	if inclusive {
		scan.pos += utf8.rune_count_in_string(delimiter)
	}
	consumed := utf8string.slice(scan.source, start, scan.pos)
	fmt.printf("%sRead:%s ", sgr(ANSI_INFO), sgr(ansi.RESET))
	print_escaped(consumed)
	fmt.print("\n")
	return consumed
}

read_until_predicate :: proc(
	scan: ^Scanner, predicate: proc(rune) -> bool, name: string, inclusive := false
) -> string {
	start := scan.pos
	fmt.printfln("Starting loop in read_until_predicate for %s", name)
	for char := peek(scan); !predicate(char); char = peek(scan) {
		if char == utf8.RUNE_EOF {
			panic(fmt.tprintfln("Missing closing delimiter: %v\n%s",
				name, mark_unclosed_tag(scan, start)
			))
		}
		scan.pos += 1
	}
	if inclusive {
		scan.pos += 1
	}
	consumed := utf8string.slice(scan.source, start, scan.pos)
	fmt.printf("%sRead:%s ", sgr(ANSI_INFO), sgr(ansi.RESET))
	print_escaped(consumed)
	fmt.print("\n")
	return consumed
}
read_until :: proc{read_until_rune, read_until_string, read_until_predicate}

read_any :: proc(scan: ^Scanner, matches: []string) -> (string, bool) {
	fmt.println("Starting loop in read_any")
	for match in matches {
		consumed := read(scan, match)
		if consumed {
			fmt.printf("%sRead:%s ", sgr(ANSI_INFO), sgr(ansi.RESET))
			print_escaped(match)
			fmt.print("\n")
			return match, true
		}
	}
	fmt.printfln("%sDid not read anything%s", sgr(ANSI_INFO), sgr(ansi.RESET))
	return "", false
}
read_all :: proc(scan: ^Scanner, match: []string) -> string {
	start := scan.pos
	fmt.println("Starting loop in read_all")
	for {
		reading, consumed := read_any(scan, match)
		// TODO: Introduce hard limit on iteration
		if !consumed {
			consumed_text := utf8string.slice(scan.source, start, scan.pos)
			fmt.printf("%sRead:%s ", sgr(ANSI_INFO), sgr(ansi.RESET))
			print_escaped(consumed_text)
			fmt.print("\n")
			return consumed_text
		}
	}
}
read_while :: proc(scan: ^Scanner, predicate: proc(rune) -> bool) -> string {
	start := scan.pos
	fmt.println("Starting loop in read_while")
	for c := peek(scan); c != utf8.RUNE_EOF && predicate(c); c = peek(scan) {
		scan.pos += 1
	}
	consumed_text := utf8string.slice(scan.source, start, scan.pos)
	if consumed_text != "" {
		fmt.printf("%sRead:%s ", sgr(ANSI_INFO), sgr(ansi.RESET))
		print_escaped(consumed_text)
		fmt.print("\n")
	}
	else {
		fmt.printfln("%sDid not read anything%s", sgr(ANSI_INFO), sgr(ansi.RESET))
	}
	return consumed_text
}

expect_string :: proc(scan: ^Scanner, match: string) {
	if !read(scan, match) {
		panic(fmt.tprintfln("Parsing failed. Did not get expected %s", match))
	}
}
expect_rune :: proc(scanner: ^Scanner, match: rune) {
	if !read(scanner, match) {
		panic(fmt.tprintfln("Parsing failed. Did not get expected %v", match))
	}
}
expect_if :: proc(scanner: ^Scanner, predicate: proc(rune) -> bool, name: string) {
	char := peek(scanner)
	if char == utf8.RUNE_EOF || !predicate(char) {
		panic(fmt.tprintfln(
			"Parsing failed. Did not get expected %s", name
		))
	}
	scanner.pos += 1
}
expect_any :: proc(scan: ^Scanner, matches: []string) -> string {
	reading, consumed := read_any(scan, matches)
	if !consumed {
		panic(fmt.tprintfln("Parsing failed. Did not get expected %v:\n%s",
			matches, mark_source(scan, scan.pos)
		))
	}
	return reading
}
expect :: proc{expect_string, expect_rune, expect_if, expect_any}

mark_source :: proc(scan: ^Scanner, syntax_start: int, mark_length: int = 1) -> string {
	COLUMNS :: 80
	MARKING_SYMBOLS :: 2
	padding := (COLUMNS - MARKING_SYMBOLS - mark_length) / 2
	start := math.max(0, scan.pos - padding)
	end := math.min(scan.source.rune_count, scan.pos + padding)

	prefix, postfix: string
	if start >= 3 {
		start += 3
		prefix = "..."
	}
	if end <= scan.source.rune_count - 3 {
		end -= 3
		postfix = "..."
	}

	pre_slice := utf8string.slice(scan.source, start, syntax_start)
	unmarked_slice := utf8string.slice(scan.source, syntax_start, scan.pos)
	current_slice := utf8string.slice(scan.source, scan.pos, scan.pos + mark_length)
	post_slice := utf8string.slice(scan.source, scan.pos + mark_length, end)

	return fmt.tprintf("%s%s%s%s%s[%s]%s%s%s",
		prefix, pre_slice, sgr(ANSI_ERR), unmarked_slice, sgr(ansi.BOLD),
		current_slice, sgr(ansi.RESET), post_slice, postfix,
	)
}

mark_unclosed_tag :: proc(scan: ^Scanner, tag_start: int) -> string {
	COLUMNS :: 80
	SPLICE_INFIX :: " ... "

	if scan.pos - tag_start <= 80 {
		return utf8string.slice(scan.source, tag_start, scan.pos)
	}
	length := (COLUMNS / 2) - utf8.rune_count(SPLICE_INFIX)
	start_slice := utf8string.slice(scan.source, tag_start, tag_start + length)
	end_slice := utf8string.slice(scan.source, scan.pos - length, scan.pos)

	return fmt.tprintf("%s%s%s%s%s",
		sgr(ANSI_ERR), start_slice, SPLICE_INFIX, end_slice, sgr(ansi.RESET)
	)
}