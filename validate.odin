package main

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

is_valid_custom_element_name :: proc(name: string) -> bool {
	contains_hyphen := false
	for r, i in name {
		if i == 0 ? !is_lower_ASCII(r) : !is_name_char_HTML(r) {
			return false
		}
		else if !contains_hyphen && r == '-' {
			contains_hyphen = true
		}
	}
	return contains_hyphen
}