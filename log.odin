package main

import "core:strings"
import "core:fmt"
import "core:terminal/ansi"
ANSI_MSG :: ansi.FG_MAGENTA
ANSI_INFO :: ansi.FG_BLUE
ANSI_OK :: ansi.FG_GREEN
ANSI_WARN :: ansi.FG_YELLOW
ANSI_ERR :: ansi.FG_RED

sgr :: proc(
	args: ..string, allocator := context.allocator, loc := #caller_location
) -> (control_sequence: string) {
	display_attributes := strings.join(args, ";", allocator)
	return fmt.tprintf("%s%s%s", ansi.CSI, display_attributes, ansi.SGR)
}