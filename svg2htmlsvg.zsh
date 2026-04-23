#!/usr/bin/env zsh

# -*- mode: zsh; sh-shell: zsh; -*-

# zsh-specific: shellcheck does not apply to zsh scripts

# 

# Template: v3.0 (20260124)

# svg2htmlsvg(1)

# 

# Created by jason c. kay [j@son-kay.com](mailto:j@son-kay.com)

# Copyright 2026 jason c. kay

# Some rights reserved.

# 

# This work is licensed under the Creative Commons

# Attribution-ShareAlike 4.0 International License. To

# view a copy of this license, visit

# http://creativecommons.org/licenses/by-sa/4.0/.

# 

# Description:

# Converts a standalone SVG file to an inline HTML-embeddable <svg> element.

# Strips XML declarations, DOCTYPEs, and optionally strips comments, metadata,

# and unnecessary whitespace.  Can optionally wrap output in a minimal HTML

# document and inject class/id attributes on the root <svg> element.

# 

# Usage:

# svg2htmlsvg [OPTIONS] <input.svg>

# 

# Options:

# -h, –help             Show this help message and exit

# -V, –version          Show version information and exit

# -v, –verbose          Increase verbosity (can be repeated: -vvv)

# -q, –quiet            Suppress all non-error output

# -n, –dry-run          Show what would be done without doing it

# -d, –debug            Enable debug mode (implies -vvv)

# -o, –output FILE      Write output to FILE instead of stdout

# -c, –config FILE      Use specified configuration file

# –strip-comments   Remove XML/SVG comments from output

# –strip-metadata   Remove <metadata> elements from output

# –minify           Collapse unnecessary whitespace

# –wrap-html        Wrap output in a minimal HTML5 document

# –class CLASS      Add a CSS class to the root <svg> element

# –id ID            Add an id attribute to the root <svg> element

# –title TITLE      Set the <title> in HTML wrapper (implies –wrap-html)

# –no-xmldecl       (Default) Strip <?xml ...?> declaration

# –keep-xmldecl     Preserve the <?xml ...?> declaration

# –no-doctype       (Default) Strip <!DOCTYPE ...> declaration

# –keep-doctype     Preserve the <!DOCTYPE ...> declaration

# 

# Examples:

# svg2htmlsvg logo.svg

# svg2htmlsvg –strip-comments –minify -o inline.html logo.svg

# svg2htmlsvg –wrap-html –title “My Icon” –class “icon-lg” icon.svg

# svg2htmlsvg -vv –dry-run diagram.svg

# 

# Compilation:

# This script is designed to be compatible with zcompile.

# To compile: zcompile svg2htmlsvg.zsh

# This creates svg2htmlsvg.zsh.zwc (zsh word code) for faster loading.

# 

# IMPORTANT: Zsh variable naming caveat:

# Do NOT use ‘path’ as a local variable name in functions that invoke

# subshells (e.g., $(…)). In zsh, ‘local path’ shadows the global $PATH

# and causes command lookups to fail in subshells. Use ‘cmd_path’ or

# similar instead.

# ==============================================================================

# ZSH STRICT MODE AND SHELL OPTIONS

# ==============================================================================

emulate -L zsh

# Core strict mode options (equivalent to bash set -euo pipefail)

setopt ERR_EXIT
setopt NO_UNSET
setopt PIPE_FAIL

# Additional safety options

setopt WARN_CREATE_GLOBAL
setopt NO_CLOBBER
setopt LOCAL_OPTIONS
setopt LOCAL_TRAPS
setopt LOCAL_PATTERNS

# Useful zsh options for scripting

setopt EXTENDED_GLOB
setopt NO_NOMATCH
setopt NUMERIC_GLOB_SORT
setopt RC_QUOTES
setopt FUNCTION_ARGZERO
setopt C_BASES
setopt MULTIOS

# Check zsh version (5.0+ required for full feature set)

if [[ ${ZSH_VERSION%%.*} -lt 5 ]]; then
print -u2 “Error: This script requires zsh 5.0 or later (found: ${ZSH_VERSION})”
exit 1
fi

# ==============================================================================

# CONSTANTS AND DEFAULTS

# ==============================================================================

typeset -gr SCRIPT_NAME=”${${(%):-%x}:t}”
typeset -gr SCRIPT_DIR=”${${(%):-%x}:A:h}”
typeset -gr SCRIPT_VERSION=“1.0.0”
typeset -gr SCRIPT_AUTHOR=“jason c. kay [j@son-kay.com](mailto:j@son-kay.com)”

# Exit codes (BSD sysexits.h compatible)

typeset -gri E_SUCCESS=0
typeset -gri E_GENERAL=1
typeset -gri E_USAGE=2
typeset -gri E_NOINPUT=66
typeset -gri E_NOUSER=67
typeset -gri E_NOHOST=68
typeset -gri E_UNAVAILABLE=69
typeset -gri E_SOFTWARE=70
typeset -gri E_OSERR=71
typeset -gri E_OSFILE=72
typeset -gri E_CANTCREAT=73
typeset -gri E_IOERR=74
typeset -gri E_TEMPFAIL=75
typeset -gri E_PROTOCOL=76
typeset -gri E_NOPERM=77
typeset -gri E_CONFIG=78

# Verbosity levels

typeset -gri V_QUIET=0
typeset -gri V_NORMAL=1
typeset -gri V_VERBOSE=2
typeset -gri V_DEBUG=3
typeset -gri V_TRACE=4

# Colors (populated in init_colors)

typeset -gA COLORS

# ==============================================================================

# GLOBAL VARIABLES (mutable state)

# ==============================================================================

typeset -gi VERBOSITY=$V_NORMAL
typeset -g DRY_RUN=false
typeset -ga TEMP_FILES=()
typeset -g TEMP_DIR=””
typeset -gA REQUIRED_BINARIES=()
typeset -gA OPTIONAL_BINARIES=()
typeset -ga POSITIONAL_ARGS=()
typeset -g CONFIG_FILE=””
typeset -g OUTPUT_FILE=””

# — svg2htmlsvg-specific options —

typeset -g OPT_STRIP_COMMENTS=false
typeset -g OPT_STRIP_METADATA=false
typeset -g OPT_MINIFY=false
typeset -g OPT_WRAP_HTML=false
typeset -g OPT_CLASS=””
typeset -g OPT_ID=””
typeset -g OPT_TITLE=””
typeset -g OPT_KEEP_XMLDECL=false
typeset -g OPT_KEEP_DOCTYPE=false

# ==============================================================================

# LOGGING AND OUTPUT

# ==============================================================================

init_colors() {
emulate -L zsh
if [[ -t 1 ]] && [[ -z “${NO_COLOR:-}” ]]; then
COLORS=(
reset   $’\033[0m’
bold    $’\033[1m’
dim     $’\033[2m’
red     $’\033[0;31m’
green   $’\033[0;32m’
yellow  $’\033[0;33m’
blue    $’\033[0;34m’
magenta $’\033[0;35m’
cyan    $’\033[0;36m’
white   $’\033[0;37m’
)
else
COLORS=(
reset ‘’ bold ‘’ dim ‘’
red ‘’ green ‘’ yellow ‘’ blue ‘’
magenta ‘’ cyan ‘’ white ‘’
)
fi
}

_log() {
emulate -L zsh
local level=$1
shift
local message=”$*”
local timestamp
zmodload -F zsh/datetime b:strftime
strftime -s timestamp ‘%Y-%m-%d %H:%M:%S’

```
local color prefix min_verbosity output_fd=1

case $level in
    trace)
        color=${COLORS[dim]}
        prefix="TRACE"
        min_verbosity=$V_TRACE
        ;;
    debug)
        color=${COLORS[cyan]}
        prefix="DEBUG"
        min_verbosity=$V_DEBUG
        ;;
    info)
        color=${COLORS[green]}
        prefix="INFO"
        min_verbosity=$V_NORMAL
        ;;
    warn)
        color=${COLORS[yellow]}
        prefix="WARN"
        min_verbosity=$V_NORMAL
        output_fd=2
        ;;
    error)
        color=${COLORS[red]}
        prefix="ERROR"
        min_verbosity=$V_QUIET
        output_fd=2
        ;;
    fatal)
        color="${COLORS[red]}${COLORS[bold]}"
        prefix="FATAL"
        min_verbosity=$V_QUIET
        output_fd=2
        ;;
esac

if (( VERBOSITY >= min_verbosity )); then
    print -u $output_fd "${color}[${timestamp}] [${prefix}] ${message}${COLORS[reset]}"
fi
```

}

trace() { _log trace “$@” }
debug() { _log debug “$@” }
info()  { _log info “$@” }
warn()  { _log warn “$@” }
error() { _log error “$@” }

fatal() {
emulate -L zsh
_log fatal “$1”
exit ${2:-$E_GENERAL}
}

msg() {
emulate -L zsh
if (( VERBOSITY >= V_NORMAL )); then
print – “$*”
fi
}

msgn() {
emulate -L zsh
if (( VERBOSITY >= V_NORMAL )); then
print -n – “$*”
fi
}

# ==============================================================================

# ERROR HANDLING AND CLEANUP

# ==============================================================================

print_stack_trace() {
emulate -L zsh
error “Stack trace:”
local i
for (( i = 1; i <= ${#funcstack[@]}; i++ )); do
local func=”${funcstack[$i]}”
local source=”${funcsourcetrace[$i]}”
error “  at ${func}() in ${source}”
done
}

TRAPZERR() {
emulate -L zsh
local exit_code=$?
[[ -o ERR_EXIT ]] || return 0
error “Command failed with exit code ${exit_code}”
error “  Function: ${funcstack[2]:-main}”
error “  Source: ${funcsourcetrace[2]:-unknown}”
if (( VERBOSITY >= V_DEBUG )); then
print_stack_trace
fi
}

TRAPEXIT() {
emulate -L zsh
local exit_code=$?
local temp_file
for temp_file in “${TEMP_FILES[@]}”; do
if [[ -f “$temp_file” ]]; then
debug “Removing temp file: ${temp_file}”
rm -f “$temp_file” 2>/dev/null
fi
done
if [[ -n “${TEMP_DIR:-}” ]] && [[ -d “$TEMP_DIR” ]]; then
debug “Removing temp directory: ${TEMP_DIR}”
rm -rf “$TEMP_DIR” 2>/dev/null
fi
debug “Cleanup complete, exiting with code ${exit_code}”
return $exit_code
}

TRAPINT() {
emulate -L zsh
error “Caught signal: INT”
return $(( 128 + 2 ))
}

TRAPTERM() {
emulate -L zsh
error “Caught signal: TERM”
return $(( 128 + 15 ))
}

TRAPHUP() {
emulate -L zsh
error “Caught signal: HUP”
return $(( 128 + 1 ))
}

setup_traps() {
emulate -L zsh
debug “Trap handlers configured”
}

# ==============================================================================

# DEPENDENCY VALIDATION

# ==============================================================================

command_exists() {
emulate -L zsh
(( $+commands[$1] ))
}

get_command() {
emulate -L zsh
local cmd
for cmd in “$@”; do
if (( $+commands[$cmd] )); then
print – “${commands[$cmd]}”
return 0
fi
done
return 1
}

require_binary() {
emulate -L zsh
local name=$1
shift
local -a alternatives=(”$name” “$@”)
local cmd_path

```
if cmd_path=$(get_command "${alternatives[@]}"); then
    REQUIRED_BINARIES[$name]=$cmd_path
    debug "Found required binary: ${name} -> ${cmd_path}"
    return 0
fi

error "Required binary not found: ${name}"
error "Tried: ${(j:, :)alternatives}"
error "Please install one of these packages:"
case $name in
    gawk|awk)
        error "  - Debian/Ubuntu: apt install gawk"
        error "  - macOS: brew install gawk"
        error "  - RHEL/CentOS: yum install gawk"
        ;;
    gsed|sed)
        error "  - Debian/Ubuntu: apt install sed"
        error "  - macOS: brew install gnu-sed"
        ;;
    *)
        error "  - Check your distribution's package manager"
        ;;
esac
exit $E_UNAVAILABLE
```

}

optional_binary() {
emulate -L zsh
local name=$1
shift
local -a alternatives=(”$name” “$@”)
local cmd_path

```
if cmd_path=$(get_command "${alternatives[@]}"); then
    OPTIONAL_BINARIES[$name]=$cmd_path
    debug "Found optional binary: ${name} -> ${cmd_path}"
    return 0
fi

OPTIONAL_BINARIES[$name]=""
debug "Optional binary not found: ${name}"
return 1
```

}

validate_dependencies() {
emulate -L zsh
debug “Validating dependencies…”

```
# sed is required for all SVG transformations
require_binary sed gsed

# awk is used for multi-line processing (comment/metadata stripping)
require_binary awk gawk mawk

# Optional: xmllint for well-formedness validation
optional_binary xmllint || debug "xmllint not found; SVG validation disabled"

debug "All required dependencies satisfied"
```

}

# ==============================================================================

# TEMP FILE MANAGEMENT

# ==============================================================================

create_temp_file() {
emulate -L zsh
local suffix=${1:-}
local temp_file

```
temp_file=$(mktemp "${TMPDIR:-/tmp}/${SCRIPT_NAME}.XXXXXX${suffix}") || {
    fatal "Failed to create temporary file" $E_CANTCREAT
}

TEMP_FILES+=("$temp_file")
debug "Created temp file: ${temp_file}"
print -- "$temp_file"
```

}

create_temp_dir() {
emulate -L zsh
if [[ -n “${TEMP_DIR:-}” ]]; then
print – “$TEMP_DIR”
return 0
fi
TEMP_DIR=$(mktemp -d “${TMPDIR:-/tmp}/${SCRIPT_NAME}.XXXXXX”) || {
fatal “Failed to create temporary directory” $E_CANTCREAT
}
debug “Created temp directory: ${TEMP_DIR}”
print – “$TEMP_DIR”
}

# ==============================================================================

# INPUT VALIDATION

# ==============================================================================

validate_integer() {
emulate -L zsh
local value=$1
local min=${2:-}
local max=${3:-}
[[ $value == <-> ]] || [[ $value == -<-> ]] || return 1
[[ -z $min ]] || (( value >= min )) || return 1
[[ -z $max ]] || (( value <= max )) || return 1
return 0
}

validate_string() {
emulate -L zsh
local value=$1
local min_len=${2:-1}
local max_len=${3:-}
local len=${#value}
(( len >= min_len )) || return 1
[[ -z $max_len ]] || (( len <= max_len )) || return 1
return 0
}

validate_file_readable() {
emulate -L zsh
local file=$1
if [[ ! -e $file ]]; then
error “File does not exist: ${file}”
return 1
fi
if [[ ! -f $file ]]; then
error “Not a regular file: ${file}”
return 1
fi
if [[ ! -r $file ]]; then
error “File is not readable: ${file}”
return 1
fi
return 0
}

validate_dir_writable() {
emulate -L zsh
local dir=$1
if [[ ! -e $dir ]]; then
error “Directory does not exist: ${dir}”
return 1
fi
if [[ ! -d $dir ]]; then
error “Not a directory: ${dir}”
return 1
fi
if [[ ! -w $dir ]]; then
error “Directory is not writable: ${dir}”
return 1
fi
return 0
}

sanitize_filename() {
emulate -L zsh
local input=$1
local sanitized=${input//[^[:alnum:].*-]/*}
sanitized=${sanitized//*(#c2,)/*}
print – “$sanitized”
}

# ==============================================================================

# USAGE AND HELP

# ==============================================================================

usage() {
emulate -L zsh
print -u2 “Usage: ${SCRIPT_NAME} [OPTIONS] <input.svg>”
print -u2 “Try ‘${SCRIPT_NAME} –help’ for more information.”
}

show_help() {
emulate -L zsh
print -r – “  
${SCRIPT_NAME} - Convert standalone SVG files to inline HTML <svg> elements

Usage:
${SCRIPT_NAME} [OPTIONS] <input.svg>

Options:
-h, –help              Show this help message and exit
-V, –version           Show version information and exit
-v, –verbose           Increase verbosity level (can be repeated)
-q, –quiet             Suppress all non-error output
-n, –dry-run           Show what would be done without doing it
-d, –debug             Enable debug mode (implies maximum verbosity)
-c, –config FILE       Use specified configuration file
-o, –output FILE       Write output to FILE instead of stdout

SVG Transformation Options:
–strip-comments    Remove XML/SVG comments from output
–strip-metadata    Remove <metadata>…</metadata> elements
–minify            Collapse unnecessary whitespace
–wrap-html         Wrap output in a minimal HTML5 document
–class CLASS       Add a CSS class to the root <svg> element
–id ID             Add an id attribute to the root <svg> element
–title TITLE       Set <title> in HTML wrapper (implies –wrap-html)
–keep-xmldecl      Preserve the <?xml ...?> declaration (stripped by default)
–keep-doctype      Preserve the <!DOCTYPE ...> declaration (stripped by default)

Arguments:
input.svg               Path to the standalone SVG file to convert

Examples:
${SCRIPT_NAME} logo.svg
Convert logo.svg and print inline SVG to stdout

```
${SCRIPT_NAME} --strip-comments --minify -o inline.html logo.svg
    Strip comments, minify, and write to inline.html

${SCRIPT_NAME} --wrap-html --title \"My Icon\" --class \"icon-lg\" icon.svg
    Wrap in HTML5 boilerplate with a title and CSS class

${SCRIPT_NAME} -vv --dry-run diagram.svg
    Show what transformations would be applied without writing output
```

Exit Codes:
0   Success
1   General error
2   Usage/syntax error
66  Input file not found or not an SVG
73  Cannot create output file
77  Permission denied
78  Configuration error

Platform Support:
macOS       Tested with system zsh and Homebrew GNU coreutils
Linux       Tested with zsh 5.0+ on Debian, Ubuntu, RHEL, Arch
Windows     Supported via WSL2 or MSYS2/Git-for-Windows with zsh

Report bugs to: ${SCRIPT_AUTHOR}
Repository:     https://github.com/soren42/svg2htmlsvg”
}

show_version() {
emulate -L zsh
print “${SCRIPT_NAME} version ${SCRIPT_VERSION}”
}

# ==============================================================================

# ARGUMENT PARSING (using zparseopts)

# ==============================================================================

parse_arguments() {
emulate -L zsh

```
zmodload zsh/zutil

local -a opt_help opt_version opt_verbose opt_quiet opt_dry_run opt_debug
local -a opt_config opt_output
local -a opt_strip_comments opt_strip_metadata opt_minify opt_wrap_html
local -a opt_class opt_id opt_title
local -a opt_keep_xmldecl opt_keep_doctype

zparseopts -D -E -F -K -- \
    h=opt_help          -help=opt_help \
    V=opt_version       -version=opt_version \
    v+=opt_verbose      -verbose+=opt_verbose \
    q=opt_quiet         -quiet=opt_quiet \
    n=opt_dry_run       -dry-run=opt_dry_run \
    d=opt_debug         -debug=opt_debug \
    c:=opt_config       -config:=opt_config \
    o:=opt_output       -output:=opt_output \
    -strip-comments=opt_strip_comments \
    -strip-metadata=opt_strip_metadata \
    -minify=opt_minify \
    -wrap-html=opt_wrap_html \
    -class:=opt_class \
    -id:=opt_id \
    -title:=opt_title \
    -keep-xmldecl=opt_keep_xmldecl \
    -keep-doctype=opt_keep_doctype \
    || {
        usage
        exit $E_USAGE
    }

# --- Standard options ---
if (( ${#opt_help} )); then
    show_help
    exit $E_SUCCESS
fi

if (( ${#opt_version} )); then
    show_version
    exit $E_SUCCESS
fi

if (( ${#opt_verbose} )); then
    VERBOSITY=$(( V_NORMAL + ${#opt_verbose} ))
    (( VERBOSITY > V_TRACE )) && VERBOSITY=$V_TRACE
fi

(( ${#opt_quiet} ))   && VERBOSITY=$V_QUIET
(( ${#opt_dry_run} )) && DRY_RUN=true

if (( ${#opt_debug} )); then
    VERBOSITY=$V_TRACE
    setopt XTRACE
fi

(( ${#opt_config} )) && CONFIG_FILE=${opt_config[-1]}
(( ${#opt_output} )) && OUTPUT_FILE=${opt_output[-1]}

# --- SVG-specific options ---
(( ${#opt_strip_comments} )) && OPT_STRIP_COMMENTS=true
(( ${#opt_strip_metadata} )) && OPT_STRIP_METADATA=true
(( ${#opt_minify} ))         && OPT_MINIFY=true
(( ${#opt_wrap_html} ))      && OPT_WRAP_HTML=true
(( ${#opt_keep_xmldecl} ))   && OPT_KEEP_XMLDECL=true
(( ${#opt_keep_doctype} ))   && OPT_KEEP_DOCTYPE=true

if (( ${#opt_class} )); then
    OPT_CLASS=${opt_class[-1]}
fi

if (( ${#opt_id} )); then
    OPT_ID=${opt_id[-1]}
fi

if (( ${#opt_title} )); then
    OPT_TITLE=${opt_title[-1]}
    # --title implies --wrap-html
    OPT_WRAP_HTML=true
fi

# Remaining arguments are positional
if [[ ${1:-} == '--' ]]; then
    shift
fi
POSITIONAL_ARGS=("$@")

debug "Verbosity level: ${VERBOSITY}"
debug "Dry run: ${DRY_RUN}"
debug "Strip comments: ${OPT_STRIP_COMMENTS}"
debug "Strip metadata: ${OPT_STRIP_METADATA}"
debug "Minify: ${OPT_MINIFY}"
debug "Wrap HTML: ${OPT_WRAP_HTML}"
debug "CSS class: ${OPT_CLASS:-<none>}"
debug "Element ID: ${OPT_ID:-<none>}"
debug "HTML title: ${OPT_TITLE:-<none>}"
debug "Keep XML decl: ${OPT_KEEP_XMLDECL}"
debug "Keep DOCTYPE: ${OPT_KEEP_DOCTYPE}"
debug "Positional arguments: ${(j:, :)POSITIONAL_ARGS:-none}"
```

}

validate_arguments() {
emulate -L zsh

```
# Require exactly one positional argument (the input SVG file)
if (( ${#POSITIONAL_ARGS} < 1 )); then
    error "Missing required argument: input SVG file"
    usage
    exit $E_USAGE
fi

if (( ${#POSITIONAL_ARGS} > 1 )); then
    error "Too many arguments; expected exactly one input SVG file"
    error "  Got: ${(j:, :)POSITIONAL_ARGS}"
    usage
    exit $E_USAGE
fi

# Validate the input file exists and is readable
local input_file="${POSITIONAL_ARGS[1]}"
if ! validate_file_readable "$input_file"; then
    exit $E_NOINPUT
fi

# Basic SVG sniff: check for an <svg tag in the first 50 lines
if ! head -n 50 "$input_file" | grep -qi '<svg'; then
    error "Input file does not appear to be an SVG: ${input_file}"
    error "  No <svg> element found in the first 50 lines."
    exit $E_NOINPUT
fi

# If an output file is specified, verify the parent directory is writable
if [[ -n "${OUTPUT_FILE}" ]]; then
    local output_dir="${OUTPUT_FILE:h}"
    # :h gives the directory part; if there is none, use current dir
    [[ "$output_dir" == "$OUTPUT_FILE" ]] && output_dir="."
    if ! validate_dir_writable "$output_dir"; then
        exit $E_CANTCREAT
    fi
fi

# Validate --class value doesn't contain quotes or angle brackets
if [[ -n "$OPT_CLASS" ]]; then
    if [[ "$OPT_CLASS" =~ [\"\'\<\>] ]]; then
        error "Invalid characters in --class value: ${OPT_CLASS}"
        exit $E_USAGE
    fi
fi

# Validate --id value doesn't contain quotes or angle brackets
if [[ -n "$OPT_ID" ]]; then
    if [[ "$OPT_ID" =~ [\"\'\<\>] ]]; then
        error "Invalid characters in --id value: ${OPT_ID}"
        exit $E_USAGE
    fi
fi

debug "Arguments validated successfully"
```

}

# ==============================================================================

# DRY RUN SUPPORT

# ==============================================================================

run() {
emulate -L zsh
if [[ $DRY_RUN == true ]]; then
info “[DRY-RUN] Would execute: $*”
return 0
fi
debug “Executing: $*”
“$@”
}

# ==============================================================================

# CONFIGURATION

# ==============================================================================

load_config() {
emulate -L zsh
local config_file=$1
if [[ ! -f $config_file ]]; then
debug “Configuration file not found: ${config_file}”
return 1
fi
if [[ ! -r $config_file ]]; then
warn “Configuration file not readable: ${config_file}”
return 1
fi
debug “Loading configuration from: ${config_file}”
if ! zsh -n “$config_file” 2>/dev/null; then
error “Syntax error in configuration file: ${config_file}”
return 1
fi
source “$config_file”
return 0
}

load_configuration() {
emulate -L zsh
local config_name=${SCRIPT_NAME%.zsh}
config_name=${config_name%.sh}

```
local -a config_locations=(
    "/etc/${config_name}/${config_name}.conf"
    "/etc/${config_name}.conf"
    "${HOME}/.config/${config_name}/${config_name}.conf"
    "${HOME}/.${config_name}.conf"
    "./${config_name}.conf"
)

local env_var="${(U)config_name//[^A-Za-z0-9]/_}_CONFIG_FILE"
if [[ -n "${(P)env_var:-}" ]]; then
    config_locations+=("${(P)env_var}")
fi

if [[ -n "${CONFIG_FILE:-}" ]]; then
    if ! load_config "$CONFIG_FILE"; then
        fatal "Cannot load specified configuration file: ${CONFIG_FILE}" $E_CONFIG
    fi
    return 0
fi

local config
for config in "${config_locations[@]}"; do
    load_config "$config" || true
done
```

}

# ==============================================================================

# SVG TRANSFORMATION ENGINE

# ==============================================================================

# Strip the XML declaration line (<?xml ... ?>)

# Arguments:

# $1 - Input text (via stdin)

# Outputs: Transformed text to stdout

_strip_xml_declaration() {
emulate -L zsh
“${REQUIRED_BINARIES[sed]}” ‘s/<[?]xml[^?]*[?]>//g’
}

# Strip the DOCTYPE declaration (<!DOCTYPE ... >)

# Handles single-line and multi-line DOCTYPE declarations.

# Arguments: stdin

# Outputs: Transformed text to stdout

_strip_doctype() {
emulate -L zsh
“${REQUIRED_BINARIES[awk]}” ’
BEGIN { in_doctype = 0 }
{
if (in_doctype) {
# Look for the closing >
if (match($0, />/)) {
$0 = substr($0, RSTART + RLENGTH)
in_doctype = 0
if (length($0) > 0) print
}
next
}
# Match start of DOCTYPE
if (match($0, /<!DOCTYPE/)) {
before = substr($0, 1, RSTART - 1)
rest = substr($0, RSTART)
if (match(rest, />/)) {
after = substr(rest, RSTART + RLENGTH)
line = before after
if (length(line) > 0) print line
} else {
in_doctype = 1
if (length(before) > 0) print before
}
next
}
print
}’
}

# Strip XML/SVG comments (<!-- ... -->), including multi-line

# Arguments: stdin

# Outputs: Transformed text to stdout

_strip_comments() {
emulate -L zsh
“${REQUIRED_BINARIES[awk]}” ’
BEGIN { in_comment = 0 }
{
line = $0
result = “”
while (length(line) > 0) {
if (in_comment) {
idx = index(line, “–” “>”)
if (idx > 0) {
in_comment = 0
line = substr(line, idx + 3)
} else {
break
}
} else {
idx = index(line, “<” “!–”)
if (idx > 0) {
result = result substr(line, 1, idx - 1)
line = substr(line, idx + 4)
in_comment = 1
} else {
result = result line
break
}
}
}
if (!in_comment || length(result) > 0) print result
}’
}

# Strip <metadata>…</metadata> elements, including multi-line

# Arguments: stdin

# Outputs: Transformed text to stdout

_strip_metadata() {
emulate -L zsh
“${REQUIRED_BINARIES[awk]}” ’
BEGIN { in_meta = 0 }
{
line = $0
result = “”
while (length(line) > 0) {
if (in_meta) {
idx = index(line, “<” “/metadata>”)
if (idx > 0) {
in_meta = 0
line = substr(line, idx + 11)
} else {
break
}
} else {
idx = index(line, “<metadata”)
if (idx > 0) {
result = result substr(line, 1, idx - 1)
line = substr(line, idx)
# Check for self-closing <metadata … />
if (match(line, //>/) && !match(line, /</metadata>/)) {
line = substr(line, RSTART + 2)
} else if (match(line, /</metadata>/)) {
line = substr(line, RSTART + 11)
in_meta = 0
} else {
in_meta = 1
break
}
} else {
result = result line
break
}
}
}
if (!in_meta || length(result) > 0) print result
}’
}

# Inject class and/or id attributes into the root <svg> element.

# Arguments:

# $1 - CSS class to inject (may be empty)

# $2 - Element id to inject (may be empty)

# stdin - SVG content

# Outputs: Transformed text to stdout

_inject_attributes() {
emulate -L zsh
local css_class=”$1”
local elem_id=”$2”

```
if [[ -z "$css_class" ]] && [[ -z "$elem_id" ]]; then
    cat
    return
fi

# Build the injection string
local inject=""
[[ -n "$elem_id" ]]   && inject="${inject} id=\"${elem_id}\""
[[ -n "$css_class" ]] && inject="${inject} class=\"${css_class}\""

# Insert attributes right after the opening <svg (before the first >)
# Only modifies the FIRST <svg tag encountered.
"${REQUIRED_BINARIES[awk]}" -v attrs="$inject" '
BEGIN { done_inject = 0 }
{
    if (!done_inject && match($0, /<svg/)) {
        sub(/<svg/, "<svg" attrs)
        done_inject = 1
    }
    print
}'
```

}

# Minify SVG: collapse runs of whitespace, trim lines, remove blank lines.

# Arguments: stdin

# Outputs: Minified text to stdout

_minify() {
emulate -L zsh
“${REQUIRED_BINARIES[sed]}”   
-e ‘s/^[[:space:]]*//’   
-e ’s/[[:space:]]*$//’   
-e ‘/^$/d’   
| tr -s ’ ’
}

# Wrap inline SVG content in a minimal HTML5 document.

# Arguments:

# $1 - Title for the HTML document (may be empty)

# stdin - SVG content

# Outputs: Complete HTML5 document to stdout

_wrap_html() {
emulate -L zsh
local title=”${1:-Inline SVG}”

```
print -r -- '<!DOCTYPE html>'
print -r -- '<html lang="en">'
print -r -- '<head>'
print -r -- '  <meta charset="UTF-8">'
print -r -- '  <meta name="viewport" content="width=device-width, initial-scale=1.0">'
print -r -- "  <title>${title}</title>"
print -r -- '</head>'
print -r -- '<body>'
cat
print -r -- '</body>'
print -r -- '</html>'
```

}

# ==============================================================================

# MAIN LOGIC

# ==============================================================================

# Validate the SVG with xmllint if available (informational only)

# Arguments:

# $1 - SVG file path

# Outputs: Warnings to stderr if malformed

_validate_svg() {
emulate -L zsh
local svg_file=”$1”

```
if [[ -n "${OPTIONAL_BINARIES[xmllint]:-}" ]]; then
    debug "Validating SVG well-formedness with xmllint..."
    if ! "${OPTIONAL_BINARIES[xmllint]}" --noout "$svg_file" 2>/dev/null; then
        warn "Input SVG may not be well-formed XML; proceeding anyway."
        warn "  Run 'xmllint ${svg_file}' for details."
    else
        debug "SVG is well-formed XML"
    fi
fi
```

}

main() {
emulate -L zsh
debug “Starting main execution”

```
local input_file="${POSITIONAL_ARGS[1]}"
info "Input:  ${input_file}"
[[ -n "$OUTPUT_FILE" ]] && info "Output: ${OUTPUT_FILE}" || info "Output: <stdout>"

# Optionally validate the SVG first
_validate_svg "$input_file"

# --- Dry-run mode: describe what would happen and exit ---
if [[ "$DRY_RUN" == true ]]; then
    info "[DRY-RUN] Transformation pipeline for: ${input_file}"
    [[ "$OPT_KEEP_XMLDECL" == false ]] && info "[DRY-RUN]   1. Strip <?xml ...?> declaration"
    [[ "$OPT_KEEP_DOCTYPE" == false ]]  && info "[DRY-RUN]   2. Strip <!DOCTYPE ...> declaration"
    [[ "$OPT_STRIP_COMMENTS" == true ]] && info "[DRY-RUN]   3. Strip XML comments"
    [[ "$OPT_STRIP_METADATA" == true ]] && info "[DRY-RUN]   4. Strip <metadata> elements"
    if [[ -n "$OPT_CLASS" ]] || [[ -n "$OPT_ID" ]]; then
        info "[DRY-RUN]   5. Inject attributes: class=${OPT_CLASS:-<none>} id=${OPT_ID:-<none>}"
    fi
    [[ "$OPT_MINIFY" == true ]]    && info "[DRY-RUN]   6. Minify output"
    [[ "$OPT_WRAP_HTML" == true ]]  && info "[DRY-RUN]   7. Wrap in HTML5 document (title: ${OPT_TITLE:-Inline SVG})"
    [[ -n "$OUTPUT_FILE" ]]         && info "[DRY-RUN]   -> Write to: ${OUTPUT_FILE}"
    info "[DRY-RUN] No output written."
    return $E_SUCCESS
fi

# --- Build the transformation pipeline ---
# We pipe through each transformation stage.  Stages that are disabled
# are replaced by 'cat' (identity/pass-through).

local pipeline_desc=""

{
    cat "$input_file"
} | {
    # Stage 1: Strip XML declaration
    if [[ "$OPT_KEEP_XMLDECL" == false ]]; then
        trace "Pipeline stage: strip XML declaration"
        _strip_xml_declaration
    else
        cat
    fi
} | {
    # Stage 2: Strip DOCTYPE
    if [[ "$OPT_KEEP_DOCTYPE" == false ]]; then
        trace "Pipeline stage: strip DOCTYPE"
        _strip_doctype
    else
        cat
    fi
} | {
    # Stage 3: Strip comments
    if [[ "$OPT_STRIP_COMMENTS" == true ]]; then
        trace "Pipeline stage: strip comments"
        _strip_comments
    else
        cat
    fi
} | {
    # Stage 4: Strip metadata
    if [[ "$OPT_STRIP_METADATA" == true ]]; then
        trace "Pipeline stage: strip metadata"
        _strip_metadata
    else
        cat
    fi
} | {
    # Stage 5: Inject class/id attributes
    trace "Pipeline stage: inject attributes"
    _inject_attributes "$OPT_CLASS" "$OPT_ID"
} | {
    # Stage 6: Minify
    if [[ "$OPT_MINIFY" == true ]]; then
        trace "Pipeline stage: minify"
        _minify
    else
        cat
    fi
} | {
    # Stage 7: Wrap in HTML
    if [[ "$OPT_WRAP_HTML" == true ]]; then
        trace "Pipeline stage: wrap in HTML5"
        _wrap_html "$OPT_TITLE"
    else
        cat
    fi
} | {
    # Final output: write to file or stdout
    if [[ -n "$OUTPUT_FILE" ]]; then
        # Use >| to override NO_CLOBBER for intentional writes
        cat >| "$OUTPUT_FILE"
        info "Output written to: ${OUTPUT_FILE}"
    else
        cat
    fi
}

info "Conversion complete"
return $E_SUCCESS
```

}

# ==============================================================================

# INITIALIZATION AND ENTRY POINT

# ==============================================================================

init() {
emulate -L zsh
init_colors
setup_traps
debug “Initializing ${SCRIPT_NAME} v${SCRIPT_VERSION}”
debug “Running on: $(uname -s) $(uname -r)”
debug “Zsh version: ${ZSH_VERSION}”
debug “Script directory: ${SCRIPT_DIR}”
}

_main() {
emulate -L zsh

```
init
parse_arguments "$@"
load_configuration
validate_dependencies
validate_arguments

{
    main
} always {
    :
}

exit $E_SUCCESS
```

}

# ==============================================================================

# SOURCE GUARD AND EXECUTION

# ==============================================================================

if [[ “${(%):-%x}” == “$0” ]] || [[ -n “${ZSH_SCRIPT:-}” ]]; then
_main “$@”
fi

# ==============================================================================

# ZSH COMPLETION FUNCTION SCAFFOLD

# ==============================================================================

# To enable command completion, create a file named _svg2htmlsvg in your fpath

# with the following content (uncomment and customize):

# 

# #compdef svg2htmlsvg svg2htmlsvg.zsh

# 

# _svg2htmlsvg() {

# local -a options

# options=(

# ‘(-h –help)’{-h,–help}’[Show help message]’

# ‘(-V –version)’{-V,–version}’[Show version]’

# ‘*’{-v,–verbose}’[Increase verbosity]’

# ‘(-q –quiet)’{-q,–quiet}’[Suppress output]’

# ‘(-n –dry-run)’{-n,–dry-run}’[Dry run mode]’

# ‘(-d –debug)’{-d,–debug}’[Enable debug mode]’

# ‘(-c –config)’{-c,–config}’[Config file]:config file:_files’

# ‘(-o –output)’{-o,–output}’[Output file]:output file:_files’

# ‘–strip-comments[Remove XML comments]’

# ‘–strip-metadata[Remove metadata elements]’

# ‘–minify[Collapse whitespace]’

# ‘–wrap-html[Wrap in HTML5 document]’

# ‘–class[CSS class for root svg]:class name:’

# ‘–id[Element id for root svg]:element id:’

# ‘–title[HTML title (implies –wrap-html)]:title:’

# ‘–keep-xmldecl[Preserve XML declaration]’

# ‘–keep-doctype[Preserve DOCTYPE declaration]’

# )

# 

# _arguments -s $options ‘*:SVG file:_files -g “*.svg(-.)”’

# }

# 

# _svg2htmlsvg “$@”
