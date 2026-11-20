package main

is_c0_control :: proc(c: rune) -> bool {
	return c >= '\u0000' && c <= '\u001f'
}
is_control :: proc(c: rune) -> bool {
	return is_c0_control(c) || (c >= '\u007f' && c <= '\u009f')
}
is_noncharacter :: proc(c: rune) -> bool {
	return (c >= '\ufdd0' && c <= '\ufdef') || c == '\ufffe' || c == '\uffff' ||
	c == '\U0001fffe' || c == '\U0001ffff' || c == '\U0002fffe' || c == '\U0002ffff' ||
	c == '\U0003fffe' || c == '\U0003ffff' || c == '\U0004fffe' || c == '\U0004ffff' ||
	c == '\U0005fffe' || c == '\U0005ffff' || c == '\U0006fffe' || c == '\U0006ffff' ||
	c == '\U0007fffe' || c == '\U0007ffff' || c == '\U0008fffe' || c == '\U0008ffff' ||
	c == '\U0009fffe' || c == '\U0009ffff' || c == '\U000afffe' || c == '\U000affff' ||
	c == '\U000bfffe' || c == '\U000bffff' || c == '\U000cfffe' || c == '\U000cffff' ||
	c == '\U000dfffe' || c == '\U000dffff' || c == '\U000efffe' || c == '\U000effff' ||
	c == '\U000ffffe' || c == '\U000fffff' || c == '\U0010fffe' || c == '\U0010ffff'
}
is_attr_name_char :: proc(c: rune) -> bool {
	return !is_control(c) && !is_noncharacter(c) && !is_attr_value_delim(c) &&
	!is_el_close_delim(c) && c != ' ' && c != PLACEHOLDER_DELIM
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
is_attr_value_delim :: proc(c: rune) -> bool {
	return c == '"' || c == '\''
}
is_unquoted_attr_value_delim :: proc(c: rune) -> bool {
	return is_whitespace_ASCII(c) || is_attr_value_delim(c) ||
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