# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0](https://github.com/soren42/svg2htmlsvg/releases/tag/v1.0.0) - 2026-04-23

### Added

- Initial release of `svg2htmlsvg`
- Core transformation pipeline: XML declaration stripping, DOCTYPE stripping
- Optional comment stripping (`--strip-comments`), including multi-line comments
- Optional metadata element stripping (`--strip-metadata`), including multi-line
- CSS class injection on root `<svg>` element (`--class`)
- Element id injection on root `<svg>` element (`--id`)
- Whitespace minification (`--minify`)
- HTML5 document wrapper (`--wrap-html`, `--title`)
- Flags to preserve XML declaration (`--keep-xmldecl`) and DOCTYPE (`--keep-doctype`)
- Output to file (`-o` / `--output`) or stdout
- Dry-run mode (`-n` / `--dry-run`) with pipeline description
- Multi-level verbosity (`-v`, `-vv`, `-vvv`, `-q`, `-d`)
- Hierarchical configuration file support
- SVG well-formedness validation via `xmllint` (when available)
- Input validation: file existence, readability, SVG sniff check
- Cross-platform support: macOS, Linux, Windows (WSL2/MSYS2)
- Comprehensive `--help` documentation
- zsh completion function scaffold
- Built on Shell-Script-Templates v3.0 framework
