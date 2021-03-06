#!/bin/bash

# Extract opcodes from an ELF binary
# Needed: file, readelf, objdump, sed
# Output: '\x41\x42...'

# Written by `zionlion`

# Output error on stderr
error()
{
	[ "$#" -eq 1 ] && echo -e >&2 "$1"
}

usage()
{
	error "Usage:\t$0 [options] <elf_file>\n"
	error "Options:\t-h, --help                  'print this help'"
	error "        \t-r, --raw                   'print all on a single line'"
	error "        \t-s, --start-symbol <symbol> 'start at given label (_start by default)'"
	error "        \t-e, --end-symbol   <symbol> 'stop at given label'\n\n"
	error "Examples:\t$0 ./file"
	error "        \t$0 -s _start -e main ./file"
	exit 0
}

# Check we have something that looks like ELF
elf_checks()
{
	ELF="$1"
	if [ ! -f "$ELF" ]
	then
		error "$0: File '$ELF' does not exists"
		exit 1
	else
		readelf -h "$ELF" &>/dev/null
		[ "$?" -ne 0 ] && error "$0: File '$ELF' is not an ELF" \
		&& exit 1
	fi
}

# -------- ENTRY POINT ---------
# Check that we have an argument
[ "$#" -lt 1 ] && usage

LABEL="<_start>:"
END='$'
FILE=
RAW=0

while [ "$#" -gt 0 ] ; do
	case "$1" in
	-h|--help)
		usage
		;;
	-r|--raw)
		RAW=1
		shift
		;;
	-s|--start|--start-sym|--start-symbol)
		LABEL="<$2>:"
		shift 2
		;;
	-e|--end|--end-sym|--end-symbol)
		END="<$2>:"
		shift 2
		;;
	-*)
		error "$0: Unknown option '$1'"
		usage
		;;
	*)
		FILE="$1"
		shift
		;;
	esac
done

elf_checks "$FILE"

# If binary is stripped, use <.text> as entry point for opcodes
file "$FILE" | grep 'not stripped' &>/dev/null
[ "$?" -ne 0 ] && LABEL="<.text>:"

[ "$END" != "$" ] && END="/$END/"

RANGE="/$LABEL/, $END"

# Stop if objdump or sed fails now
set -e

OBJDUMP=$(objdump -d "$FILE")
OUT=$(echo -n "$OBJDUMP" | sed -rn "
				$RANGE {
					/$LABEL/n
					s/(.*:\t)([a-z0-9 ]{1,50})(.*)/\2/p
				}
			  " \
		| sed -r "s/[ ]+$//" \
	        | sed -e 's/^/\\x/' -e 's/ /\\x/g' \
		| sed -e ':a' -e 'N' -e '$!ba' -e 's/\n//g' \
     )

if [ "$RAW" -eq 1 ] ; then
	echo "$OUT"
else
	echo -n "$OUT" | sed -r 's/.{4,44}/"&"\n/g'
fi
