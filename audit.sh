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
BRUTE_FORCE_ARG_COUNT=1
# Expected number of arguments for the file_crack function.
FILE_CRACK_ARG_COUNT=2
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
        # Sanity check, skip if null.
        if [ -z "$USER" -o -z "$PASSWORD" ]; then
            continue
        fi
        # Remove duplicates (because some people are crazy).
        if [ "${users[$USER]+is_set}" ]; then
            continue
        fi
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

# brute_force attempts to use a 'trivial' brute force attack against the
# provided password in the [a-z]{0,5} space.
# Pre-computation was not allowed so test data is generated "live".
brute_force() {
    # Make sure that the correct number of arguments are present.
    if [ $# -ne "$BRUTE_FORCE_ARG_COUNT" ]; then
        log "Invalid number of arguments to file_crack."
        return
    fi
    # Grab the input value into something with a better name.
    local input=$1
    # Use iterative brace expansions to generate the set, since the
    # computation of the expansion is handled before the first element
    # is accessed.
    #
    # Iteratively expanding the sets allows us to amortize the cost
    # for generating the larger sets, which is especially useful if the
    # password is found in a smaller set.
    for plaintext in {a..z}; do
        calculated=$(sha_hash "$plaintext")
        if [ "$calculated" == "$input" ]; then
            echo "$plaintext"
            return
        fi
    done
    for plaintext in {a..z}{a..z}; do
        calculated=$(sha_hash "$plaintext")
        if [ "$calculated" == "$input" ]; then
            echo "$plaintext"
            return
        fi
    done
    for plaintext in {a..z}{a..z}{a..z}; do
        calculated=$(sha_hash "$plaintext")
        if [ "$calculated" == "$input" ]; then
            echo "$plaintext"
            return
        fi
    done
    for plaintext in {a..z}{a..z}{a..z}{a..z}; do
        calculated=$(sha_hash "$plaintext")
        if [ "$calculated" == "$input" ]; then
            echo "$plaintext"
            return
        fi
    done
    for plaintext in {a..z}{a..z}{a..z}{a..z}{a..z}; do
        calculated=$(sha_hash "$plaintext")
        if [ "$calculated" == "$input" ]; then
            echo "$plaintext"
            return
        fi
    done
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
    # This is a super efficient "hashing" of the input file with no wasted
    # memory allocations or CPU cycles spent on processing and then
    # re-processing the same data. It's streamed directly.
    while read -r PLAINTEXT; do
        # Calculate the attempted hash.
        calculated=$(sha_hash "$PLAINTEXT")
        # If it matches, echo and return.
        if [ "$calculated" == "$input" ]; then
            echo "$PLAINTEXT"
            return
        fi
    done < "$filename"
}

# Export the function to make it callable with a timeout.
export -f sha_hash file_crack log logn
export FILE_CRACK_ARG_COUNT SHA256SUM

# The main loop for our little script.
main() {
    # Read the data in first.
    read_users_from_stdin

    # Results storage for cracked passwords. { hash => cleartext }
    declare -A passwords

    # Attempt to use the dictionary to crack the password.
    for user in "${!users[@]}"; do
        local password="${users[$user]}"
        log "Attempting: $password"
        cracked=$(file_crack "$password" "$DICTIONARY")
        # If the result is not empty add it to the results.
        if [ -n "$cracked" ]; then
            passwords+=(["$password"]="$cracked")
        fi
    done

    # Attempt to brute force the password.
    for user in "${!users[@]}"; do
        local password="${users[$user]}"
        # Check if the password was already cracked.
        if [ "${passwords[$password]+is_set}" ]; then
            continue
        fi
        cracked=$($TIMEOUT $TIMEOUT_DURATION bash -c "brute_force $password")
        # If the result is not empty add it to the results.
        if [ -n "$cracked" ]; then
            passwords+=(["$password"]="$cracked")
        fi
    done

    # Consolidate found passwords and map them to users.
    for user in "${!users[@]}"; do
        local pass="${users[$user]}"
        # If the hash has been cracked, map it to the user and echo the result.
        if [ "${passwords[$pass]+is_set}" ]; then
            # Display the output for cracked passwords.
            echo -e "[FOUND] User: $user\tPassword: ${passwords[$pass]}"
        fi
    done
}

# Execute the script.
main
