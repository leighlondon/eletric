#!/usr/bin/env bash
# vim: ts=4 et sw=4

# Audit script.
# This script requires Bash 4 due to the associative arrays.

# Declare variables for the programs to be used.
SHA256SUM="sha256sum"
TIMEOUT="timeout"
# Set the timeout duration.
TIMEOUT_DURATION=40
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
    echo -e "\n"{a..z}{a..z}{a..z}{a..z}{a..z} > $BRUTE_FORCE_FILENAME
}

# brute_force the passwords.
brute_force() {
    local input_hash=$1
    local try=""
    while read -r PLAINTEXT; do
        # Sleep to not trip the runaway process countermeasures. (?)
        sleep 0.1
        # Calculate the attempted hash.
        try=$(sha_hash "$PLAINTEXT")
        # If it matches, echo and return.
        if [ "$try" == "$input_hash" ]; then
            echo "$PLAINTEXT"
            return
        fi
    done < "$BRUTE_FORCE_FILENAME"
}

# Export the function to make it callable with a timeout.
export -f sha_hash brute_force
export BRUTE_FORCE_FILENAME
read_input_file

# Only generate the brute force file if it doesn't already exist.
if [ ! -f $BRUTE_FORCE_FILENAME ]; then
    gen_brute_force
fi

# Iterate the dictionary and display it.
for i in "${!users[@]}"; do
    # Echo and enable tabs (-e)
    att=$($TIMEOUT $TIMEOUT_DURATION bash -c "brute_force ${users[$i]}")
    echo $att
done
