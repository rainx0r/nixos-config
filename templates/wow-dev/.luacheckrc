---@diagnostic disable: lowercase-global
---@diagnostic disable: global-element
std = "lua51"
max_line_length = false
exclude_files = {
	"**/Libs/**/*.lua",
	".luacheckrc",
}
ignore = {
	"1..", -- Everything related to globals, the LuaLS check is better because it doesn't require us to define every single API functions
	"43.", -- Shadowing an upvalue, an upvalue argument, an upvalue loop variable.
}
