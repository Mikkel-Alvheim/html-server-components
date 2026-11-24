package main

import "core:unicode"

OTHER_ID_START :: unicode.Range {
	single_16 = {0x2118, 0x212E},
	ranges_16 = {
		0x1885, 0x1886,
		0x309B, 0x309C
	}
}
OTHER_ID_CONTINUE :: unicode.Range {
	single_16 = {0x00B7, 0x0387, 0x19DA, 0x30FB, 0xFF65},
	ranges_16 = {
		0x1369, 0x1371,
		0x200C, 0x200D
	}
}
PATTERN_WHITESPACE :: unicode.Range {
    single_16 = {0x0020, 0x0085},
    ranges_16 = {
    	0x0009, 0x000D,
     	0x200E, 0x200F,
      	0x2028, 0x2029
    }
}
PATTERN_SYNTAX :: unicode.Range {
    single_16 = {
        0x0060, 0x00A9, 0x00AE, 0x00B6,
        0x00BB, 0x00BF, 0x00D7, 0x00F7,
        0x3030, 0xFD3E, 0xFD3F,
    },
    ranges_16 = {
        0x0021, 0x002F,
        0x003A, 0x0040,
        0x005B, 0x005E,
        0x007B, 0x007E,
        0x00A1, 0x00A7,
        0x00AB, 0x00AC,
        0x00B0, 0x00B1,
        0x2010, 0x2027,
        0x2030, 0x203E,
        0x2041, 0x2053,
        0x2055, 0x205E,
        0x2190, 0x245F,
        0x2500, 0x2775,
        0x2794, 0x2BFF,
        0x2E00, 0x2E7F,
        0x3001, 0x3003,
        0x3008, 0x3020,
        0xFE45, 0xFE46,
    },
}
NON_CHARACTER :: unicode.Range {
	ranges_16 = {0xFDD0, 0xFDEF, 0xFFFE, 0xFFFF},
	single_32 = {
		0x1FFFE, 0x1FFFF, 0x2FFFE, 0x2FFFF, 0x3FFFE, 0x3FFFF, 0x4FFFE, 0x4FFFF,
		0x5FFFE, 0x5FFFF, 0x6FFFE, 0x6FFFF, 0x7FFFE, 0x7FFFF, 0x8FFFE, 0x8FFFF,
		0x9FFFE, 0x9FFFF, 0xAFFFE, 0xAFFFF, 0xBFFFE, 0xBFFFF, 0xCFFFE, 0xCFFFF,
		0xDFFFE, 0xDFFFF, 0xEFFFE, 0xEFFFF, 0xFFFFE, 0xFFFFF, 0x10FFFE, 0x10FFFF,
	}
}
C0_CONTROL :: unicode.Range {
	ranges_16 = {0x0000, 0x001F}
}

is_control :: proc(c: rune) -> bool {
	return unicode.in_range(c, C0_CONTROL) || (c >= '\u007f' && c <= '\u009f')
}
is_noncharacter :: proc(c: rune) -> bool {
	return unicode.in_range(c, NON_CHARACTER)
}
is_attr_name_char :: proc(c: rune) -> bool {
	return !unicode.is_control(c) && !is_noncharacter(c) && !is_quoted(c) &&
	!is_el_close_delim(c) && c != ' ' && c != PLACEHOLDER_DELIM && c != ATTR_INFIX
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
is_alphanumeric_ASCII :: proc(c: rune) -> bool {
	return is_alpha_ASCII(c) || is_digit_ASCII(c)
}
is_el_close_delim :: proc(c: rune) -> bool {
	return c == '>' || c == '/'
}
is_name_symbol_HTML :: proc(c: rune) -> bool {
	return c == '-' || c == '_' || c == ':' || c == '.'
}
is_el_name_char :: proc(c: rune) -> bool {
	return is_lower_ASCII(c) || is_digit_ASCII(c) || is_name_symbol_HTML(c)
}
is_quoted :: proc(c: rune) -> bool {
	return c == '"' || c == '\''
}
is_unquoted_attr_value_delim :: proc(c: rune) -> bool {
	return is_whitespace_ASCII(c) || is_quoted(c) ||
	c == '=' || c == '<' || c == '>' || c == '`'
}
is_placeholder_delim :: proc(next: rune, following: rune) -> bool {
	return next == '%' && following == '{'
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

is_valid_custom_element_name :: proc(name: string) -> bool {
	contains_hyphen := false
	for r, i in name {
		if i == 0 ? !is_lower_ASCII(r) : !is_el_name_char(r) {
			return false
		}
		else if !contains_hyphen && r == '-' {
			contains_hyphen = true
		}
	}
	return contains_hyphen
}

is_id_start :: proc(c: rune) -> bool {
	if unicode.in_range(c, PATTERN_WHITESPACE) || unicode.in_range(c, PATTERN_SYNTAX) {
		return false
	}
	return unicode.is_letter(c) ||
	unicode.in_range(c, unicode.nl_ranges) || unicode.in_range(c, OTHER_ID_START)
}
is_id_continue :: proc(c: rune) -> bool {
	if unicode.in_range(c, PATTERN_WHITESPACE) || unicode.in_range(c, PATTERN_SYNTAX) {
		return false
	}
	return is_id_start(c) || unicode.is_nonspacing_mark(c) || unicode.is_decimal(c) ||
	unicode.in_range(c, unicode.mc_ranges) ||
	unicode.in_range(c, unicode.pc_ranges) ||
	unicode.in_range(c, OTHER_ID_CONTINUE)
}

is_es_ident_start :: proc(c: rune) -> bool {
	return is_id_start(c) || c == '$' || c == '_'
}
is_es_ident_continue :: proc(c: rune) -> bool {
	return is_id_continue(c) || c == '$'
}
is_es_line_terminator :: proc(c: rune) -> bool {
	return c == '\n' || c == '\r' || c == 0x2028 || c == 0x2029
}