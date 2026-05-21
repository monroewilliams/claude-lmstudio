# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed
- SC1087 (error): `${ESC}[` notation used throughout terminal control helpers
  to prevent shell from interpreting `$ESC[` as an array index
- SC2053 (warning): Quoted right-hand side of `==` in `[[ ]]` to prevent glob
  matching (`[[ $key == "$ESC" ]]`)
- SC2086 (info): Quoted `"$lastrow"` in `cursor_to` calls to prevent word
  splitting and globbing
- SC2155 (warning): Separated `local` declarations from command substitution
  assignments for `lastrow`, `current_branch`, and `recent_commits`
- SC2292 (style): Replaced `[ ]` with `[[ ]]` for integer comparisons in
  `select_option`
- SC2248 (style): Quoted integer variables in `[[ ]]` comparisons
- SC2059 (info): `print_option` and `print_selected` pass option text via `%s`
  argument rather than in the format string; escape-sequence `printf` calls
  annotated with `# shellcheck disable=SC2059`
- SC2034 (warning): `COL` in `get_cursor_row` annotated with
  `# shellcheck disable=SC2034,SC2162`; it is intentionally consumed by `read`
  to discard the terminal column value
- SC2162 (info): Intentional `read` without `-r` in terminal control code
  annotated with `# shellcheck disable=SC2162`
- SC2006 (style): Replaced backtick command substitution with `$()` in
  `lastrow` assignment and `case` statement
- SC2249 (info): Added silent default `*) ;;` case to `key_input` `case`
  statement

### Changed
- Reformatted with `shfmt -i 4 -w`: consistent 4-space indentation, `case`
  arms on separate lines, minor whitespace normalisation
