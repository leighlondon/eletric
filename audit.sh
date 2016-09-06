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
FILE_CRACK_ARG_COUNT=2
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
# Log a message with no newline.
logn() { echo -en "$1" >&2; }

# read_input_file reads the user:password file that is provided over stdin
# into a data structure that we can use.
read_users_from_stdin() {
    logn "Reading input... "
    # Read from stdin and split based on the IFS (internal field separator)
    # and take the fields as user and password in order.
    while IFS=':' read -r USER PASSWORD; do
        # Add the fields to the associative array.
        users+=(["${USER}"]="${PASSWORD}")
    done < /dev/stdin
    log "done."
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

# file_crack uses an input file as a source to test the passwords.
# The input file is hashed iteratively and compared with the input hash.
file_crack() {
    # Make sure that the correct number of arguments are present.
    if [ $# -ne "$FILE_CRACK_ARG_COUNT" ]; then
        log "Invalid number of arguments to file_crack."
        return
    fi
    # Grab the variables.
    local input=$1
    local filename=$2
    local calculated=""
    while read -r PLAINTEXT; do
        # Calculate the attempted hash.
        calculated=$(sha_hash "$PLAINTEXT")
        # If it matches, echo and return.
        if [ "$calculated" == "$input" ]; then
            log "$input -> $PLAINTEXT"
            echo "$PLAINTEXT"
            return
        fi
    done < "$filename"
}

# Export the function to make it callable with a timeout.
export -f sha_hash file_crack log
export BRUTE_FORCE_FILENAME FILE_CRACK_ARG_COUNT SHA256SUM

main() {
    # The main loop for our little script.
    read_users_from_stdin

    # Attempt to use the dictionary to crack the password.
    for i in "${!users[@]}"; do
        local password="${users[$i]}"
        log "Attempting: $password"
        # TODO: Store the password attempt from the dictionary.
        file_crack "$password" "$DICTIONARY"
    done

    # Check if password not found in results dict.

    # Attempt to brute force the password.
    for i in "${!users[@]}"; do
        # TODO: Make sure that it's only the ones that haven't been found yet.
        local password="${users[$i]}"
        # TODO: Store the password attempt from brute_force
        $TIMEOUT $TIMEOUT_DURATION bash -c "brute_force $password"
    done

    # Only generate the brute force file if it doesn't already exist.
    # The file is the plaintext alphabet and NOT a rainbow table.
    if [ ! -f $BRUTE_FORCE_FILENAME ]; then
        gen_brute_force
    else
        log "Using brute force data file: $BRUTE_FORCE_FILENAME"
    fi
}

# Execute the script.
main
