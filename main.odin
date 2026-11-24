package main
import "core:os"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8/utf8string"

// 1. Read source files.
// 2. Parse all files into ASTs.
// 3. Compile ASTs into components.
// 4. Generate TypeScript.
// 5. Write output files.

main :: proc() {
	for arg, i in os.args {
		fmt.printf("%d: %s\n", i, arg)
	}
	input_dir := os.args[1]
	output_dir := os.args[2]

	files, err := os.read_all_directory_by_path(input_dir, context.temp_allocator)
	if err != nil {
		panic("Could not read input directory.")
	}
	asts : [dynamic]^Element
	defer delete(asts)
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
		ast := parse_document(&{source = utf8string.init(&utf8_string, content), pos = 0})
		append(&asts, &ast)
	}
	components := compile_components(asts[:])
	defer delete(components)
}