#!/bin/bash

# progTester: a test script for ProgTest
# Copyright (C) 2021 Prokop Hanzl

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

VERSION='0.7.0'

# ======================== TEXT FORMATTING PRESETS ========================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
LIGHTYELLOW='\033[0;93m'
PURPLE='\033[0;94m'
BLUE='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# ======================== FACTORY DEFAULT VALUES ========================

PROG=0 # source code

TESTDATA_DIR=testdata # test data directory
QUIET_MODE=0 # quiet mode
WRONGOUT_DIR=0 # wrong output directory
TIMEOUT=0 # timeout for kill-after
OUTPUT='/tmp/progtester/tester' # compiler output
UNSORTED_OUTPUT=0 # unsorted-output toggle
CLOCK=0 # clock toggle

CONFIGFILE=~/.progtester/progtester.config
[[ -f $CONFIGFILE ]] && . $CONFIGFILE # if it exists, include user config

# ======================== HELP SCREEN DEFAULTS DISPLAY HELPERS ========================

DEFAULTWORD="${GRAY}(default)${NC}"
 DEFAULTOFF="${GRAY}default: off${NC}"
  DEFAULTON="${GRAY}default: on${NC}"
 DEFAULTON1="${GRAY}default:"

if [[ $QUIET_MODE == 0 ]]; then
	VERBOSE_DEFAULT=$DEFAULTWORD
	QUIET_DEFAULT=""
else
	VERBOSE_DEFAULT=""
	QUIET_DEFAULT=$DEFAULTWORD
fi

[[ $WRONGOUT_DIR    == 0 ]] && WRONGOUT_DIR_DEFAULT=$DEFAULTOFF    || WRONGOUT_DIR_DEFAULT="${DEFAULTON1} ${WRONGOUT_DIR}${NC}"
[[ $TIMEOUT         == 0 ]] && TIMEOUT_DEFAULT=$DEFAULTOFF         || TIMEOUT_DEFAULT="${DEFAULTON1} ${TIMEOUT} seconds${NC}"
[[ $UNSORTED_OUTPUT == 0 ]] && UNSORTED_OUTPUT_DEFAULT=$DEFAULTOFF || UNSORTED_OUTPUT_DEFAULT=$DEFAULTON
[[ $CLOCK           == 0 ]] && CLOCK_DEFAULT=$DEFAULTOFF           || CLOCK_DEFAULT=$DEFAULTON

TESTDATA_DIR_DEFAULT="${DEFAULTON1} ${TESTDATA_DIR}${NC}"
OUTPUT_DEFAULT="${DEFAULTON1} ${OUTPUT}${NC}"

# ======================== SMALL FUNCTIONS ========================

ismac() {
	[[ $OSTYPE == 'darwin'* ]] && return 0 || return 1
}

error() {
	>&2 echo -e "${RED}ERROR: ${LIGHTYELLOW}$2${NC}"
	exit "$1"
}

vecho() { # verbose echo - echo only in verbose mode
	[[ $QUIET_MODE == 0 ]] && echo -e "$1"
}

qecho() { # silent echo - echo only in quiet mode
	[[ $QUIET_MODE == 1 ]] && echo -e "$1"
}

# ======================== INPUT CHECKS ========================

source_valid() {
	return $([[ -f "$PROG" ]])
}

testdata_valid() {
	return $([[ -d "$TESTDATA_DIR" ]])
}

mac_dependencies_installed() {
	ismac && return $([[ -x "$(command -v g++-11)" ]] && [[ -x "$(command -v gtimeout)" ]])
}

timeout_valid() {
	local VALIDNUMBER='^[0-9]+([.][0-9]+)?$' # regex for number with decimal dot
	return $([[ $TIMEOUT =~ $VALIDNUMBER ]])
}

# ======================== BODY FUNCTIONS ========================

initialize_success_vars() {
	SUCCESS=0 # number of successful runs
	FAIL=0 # number of unsuccessful runs
}

test_inputs() {
	! source_valid               && error 3 "Please specify valid source file."
	! testdata_valid             && error 4 "Invalid test data directory."
	! mac_dependencies_installed && error 5 "Missing dependencies."
	! timeout_valid              && error 6 "Timeout is not a number."
}

echo_help() { # displays help screen
	echo -e "${BLUE}${BOLD}              progTester v$VERSION${NC} ${BOLD}by Prokop Hanzl${NC}
${BOLD}       usage:${NC} progtester -s <source-code> [-t <testdata-dir>] [-v|-q]
                         [-w <wrongouts-dir>] [-k <seconds>] [-o <output>] [-u] [-c]
${BOLD}requirements:${NC} test data must be in the format ${YELLOW}SOMETHING_in.txt ${GREEN}SOMETHING_out.txt${NC}
${BOLD}dependencies:${NC} GNU coreutils - on macOS: brew install coreutils
              g++ (g++-11 on macOS - brew install g++)
${BOLD}       flags:${NC} ${BLUE}-h${NC} ${GRAY}// help${NC}
                 to show this screen
              ${BLUE}-s <source-code>${NC} ${GRAY}// source${NC}
                 to specify the source code file (required)
              ${BLUE}-t <testdata-dir>${NC} ${GRAY}// testdata${NC}
                 to specify the test data directory
                 $TESTDATA_DIR_DEFAULT
              ${BLUE}-v${NC} ${GRAY}// verbose${NC}
                 to run in verbose mode $VERBOSE_DEFAULT
              ${BLUE}-q${NC} ${GRAY}// quiet${NC}
                 to run in quiet mode $QUIET_DEFAULT
              ${BLUE}-w <wrongouts-dir>${NC} ${GRAY}// wrongouts${NC}
                 to specify a directory for wrong outputs
                 $WRONGOUT_DIR_DEFAULT
              ${BLUE}-k <seconds>${NC} ${GRAY}// kill-after${NC}
                 to specify a timeout (in seconds) after which the program is
                 killed. 0 for no timeout
                 $TIMEOUT_DEFAULT
              ${BLUE}-o <output>${NC} ${GRAY}// output${NC}
                 to specify where to save the output file
                 $OUTPUT_DEFAULT
              ${BLUE}-u${NC} ${GRAY}// unsorted-output${NC}
                 to allow outputs to be in any order
                 $UNSORTED_OUTPUT_DEFAULT
              ${BLUE}-c${NC} ${GRAY}// clock${NC}
                 to show runtime for each input
                 $CLOCK_DEFAULT

To change defaults, make a ${YELLOW}progtester.config${NC} file in ${YELLOW}~/.progtester${NC}. Download
a sample from the GitHub repository below.

${BOLD}Copyright (C) 2021 Prokop Hanzl${NC}
This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License, version 3.

This script is made and maintained by ${BOLD}Prokop Hanzl${NC} at
${GREEN}https://github.com/ProkopHanzl/progTester${NC}. Feel free to request features and
report bugs in the repository."
	exit 0
}

cleanup() {
	rm -r /tmp/progtester
}

compile_code() { # compiles code
	vecho "${LIGHTYELLOW}Compiling...${NC}"
	ismac && COMPILER=g++-11 || COMPILER=g++
	if ! $COMPILER "$PROG" -Wall -pedantic -O2 -o "$OUTPUT"; then
		cleanup
		error 1 "Error compiling."
	fi
}

do_timeout() { # handles timeout
	local TIME1
	local TIME2
	TIME1=$(gdate +%s%3N) # nanoseconds in Unix time
	if ismac; then # if on macOS, use gtimeout
		gtimeout $TIMEOUT $OUTPUT < "$IN_FILE" > /tmp/progtester/myout
	else
		timeout $TIMEOUT $OUTPUT < "$IN_FILE" > /tmp/progtester/myout
	fi
	local TIMEOUTRET=$? # return value of timeout, 124 means timed out
	TIME2=$(gdate +%s%3N)
	TIMEDIFF=$((TIME2-TIME1))
	return $([[ $TIMEOUTRET == 124 ]])
}

compare_outs() { # compares actual output with the reference
	if [[ $UNSORTED_OUTPUT == 1 ]]; then # if --unsorted-output, sort both the reference and actual output before comparing them
		sort "$REF_FILE" > /tmp/progtester/sortedRef
		sort /tmp/progtester/myout > /tmp/progtester/sortedMyOut
		diff /tmp/progtester/sortedRef /tmp/progtester/sortedMyOut > /dev/null
	else
		diff "$REF_FILE" /tmp/progtester/myout > /dev/null
	fi
}

print_time() { # helper for --clock
	local MS="000$1"
	>&2 vecho "    ${GRAY}> time elapsed: ${PURPLE}$(($1 / 1000)).${MS: -3}s${NC}"
}

test_code() { # runs the tests
	initialize_success_vars
	vecho "${LIGHTYELLOW}Testing...${NC}"
	for IN_FILE in "$TESTDATA_DIR"/*_in.txt; do # for each input file in test data directory
		REF_FILE="${IN_FILE%in\.txt}out.txt" # find the reference output counterpart
		if do_timeout; then # if timed out 
			>&2 vecho "${RED}FAIL: ${NC}$IN_FILE"
			>&2 vecho "    ${GRAY}> ${YELLOW}killed after ${PURPLE}${TIMEOUT}s${NC}"
			((FAIL++))
		else
			if ! compare_outs; then
				>&2 vecho "${RED}${BOLD}FAIL: ${NC}${BOLD}${IN_FILE}${NC}"
				((FAIL++))
				if [[ "$WRONGOUT_DIR" != 0 ]]; then 
					mkdir -p "$WRONGOUT_DIR"
					SHORTREF="${REF_FILE//$TESTDATA_DIR/}" # just the file name without the directory
					{
						echo "Input:"
						cat "$IN_FILE"
						echo
						echo "Expected output:"
						cat "$REF_FILE"
						echo
						echo "Your output:"
						cat /tmp/progtester/myout
					} > "${WRONGOUT_DIR}${SHORTREF}"
					>&2 vecho "    ${GRAY}> see ${PURPLE}${WRONGOUT_DIR}${SHORTREF}${NC}"
				fi
			else
				vecho "${GREEN}${BOLD}OK: ${NC}${BOLD}${IN_FILE}${NC}"
				((SUCCESS++))
			fi
			[[ $CLOCK == 1 ]] && print_time $TIMEDIFF
		fi
	done
}

print_stats() { # prints stats about successful/unsuccessful runs
	TOTAL=$((FAIL+SUCCESS))
	echo -e "${BLUE}${SUCCESS}/${TOTAL}${NC} ($SUCCESS successes and $FAIL failures)"
	[[ $WRONGOUT_DIR != 0 ]] && qecho "See ${PURPLE}${WRONGOUT_DIR}${NC} for wrong output data"
}

# ======================== BODY ========================

while getopts ":hs:t:qvw:k:o:uc" OPT; do
	case $OPT in
		h)	echo_help
			;;
		s)	PROG=$OPTARG
			;;
		t)	TESTDATA_DIR=$OPTARG
			;;
		q)	QUIET_MODE=1
			;;
		v)	QUIET_MODE=0
			;;
		w)	WRONGOUT_DIR=$OPTARG
			;;
		k)	TIMEOUT=$OPTARG
			;;
		o)	OUTPUT=./$OPTARG
			;;
		u)	UNSORTED_OUTPUT=1
			;;
		c)	CLOCK=1
			;;
		*)	error 7 "Unkown option used. See ${PURPLE}progtester -h${LIGHTYELLOW}."
			;;
	esac
done

test_inputs
mkdir -p /tmp/progtester
compile_code
test_code
print_stats
cleanup

[[ $TOTAL == "$SUCCESS" ]] && exit 0 || exit 2 # exit code 0 if all runs successful, 2 if not
