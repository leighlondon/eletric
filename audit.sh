#!/usr/bin/env bash
# vim: ts=4 et sw=4

# Audit script.
# This script requires Bash 4 due to the associative arrays.

# Declare variables for the programs to be used.
SHA256SUM="sha256sum"
TIMEOUT="timeout"
# Set the timeout duration.
TIMEOUT_DURATION=2
# Expected number of arguments for the brute_force function.
BRUTE_FORCE_ARG_COUNT=2
# Brute force filename.
BRUTE_FORCE_FILENAME="eletric-brute-force.txt"
# Default dictionary to use.
DICTIONARY="/usr/share/dict/words"
# Backup dictionary because the core teaching servers lack the real dictionary.
if [ ! -f $DICTIONARY ]; then
    DICTIONARY="~e20925/linux.words"
fi

# Create a dictionary or associative array to store user details.
declare -A users

# Log a message to stderr.
log() { echo -e "$1" >&2; }

# read_input_file reads the user:password file that is provided over stdin
# into a data structure that we can use.
read_input_file() {
    # Read from stdin and split based on the IFS (internal field separator)
    # and take the fields as user and password in order.
    while IFS=':' read -r USER PASSWORD; do
        # Add the fields to the associative array.
        users+=(["${USER}"]="${PASSWORD}")
    done < /dev/stdin
}

# sha_hash calculates the sha256 hash of the first argument.
sha_hash() {
    # Echo with no newline into the stdin of our sha program, and select
    # the first field from the output.
    echo -n "$1" | $SHA256SUM | awk '{ print $1 }'
}

# gen_brute_force generates the alphabet to use for the brute force;
# it's computationally very expensive to generate and we are going to
# iterate it many times over.
#
# It is approximately 80 MB in total on disk.
gen_brute_force() {
    log "Generating brute force dataset."
    # Use brace expansions to generate the set [a-z]{5} into the file.
    # TODO: Brute force range is [a-z]{0,5}
    echo -e "\n"{a..z}{a..z}{a..z}{a..z}{a..z} > $BRUTE_FORCE_FILENAME
}

# brute_force the passwords.
brute_force() {
    local input=$1
    local calculated=""
    while read -r PLAINTEXT; do
        # Sleep to not trip the runaway process countermeasures. (?)
        sleep 0.1
        # Calculate the attempted hash.
        calculated=$(sha_hash "$PLAINTEXT")
        # If it matches, echo and return.
        if [ "$calculated" == "$input" ]; then
            log "$input -> $PLAINTEXT"
            echo "$PLAINTEXT"
            return
        fi
    done < $BRUTE_FORCE_FILENAME
}

# Export the function to make it callable with a timeout.
export -f sha_hash brute_force log
export BRUTE_FORCE_FILENAME

main() {
    # The main loop for our little script.
    log "Reading input"
    read_input_file

    # Only generate the brute force file if it doesn't already exist.
    if [ ! -f $BRUTE_FORCE_FILENAME ]; then
        gen_brute_force
    else
        log "Using brute force data file: $BRUTE_FORCE_FILENAME"
    fi

    # Iterate the dictionary and display it.
    for i in "${!users[@]}"; do
        # Attempt to brute force the password using the brute force
        # key space [a-z]{5}, with a timeout duration.
        $TIMEOUT $TIMEOUT_DURATION bash -c "brute_force ${users[$i]}"
    done
}
