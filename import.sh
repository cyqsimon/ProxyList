#!/usr/bin/env bash

# usage: cat new-lines.txt | ./import.sh blocked|redirect|slow

set -e

# inputs
##############################

GIT_ROOT="$(git rev-parse --show-toplevel)"

# handle arguments
if [[ -z "$*" ]]; then
    echo "A category must be provided"
    exit 1
fi
# flags must come before positional argument
for ARG in "$@"; do
    case "$ARG" in
        # flags
        --allow-dirty)
            ALLOW_DIRTY=1
            ;;
        # unknown flag
        --*)
            echo "Unknown flag: \"$ARG\""
            exit 1
            ;;

        # positional
        blocked)
            SOURCE_PATH="$GIT_ROOT/gfw.sorl"
            BEGIN_TAG="BEGIN-BLOCKED-SECTION"
            END_TAG="END-BLOCKED-SECTION"
            break
            ;;
        redirect)
            SOURCE_PATH="$GIT_ROOT/gfw.sorl"
            BEGIN_TAG="BEGIN-REDIRECT-SECTION"
            END_TAG="END-REDIRECT-SECTION"
            break
            ;;
        slow)
            SOURCE_PATH="$GIT_ROOT/slow.sorl"
            BEGIN_TAG="BEGIN-SLOW-SECTION"
            END_TAG="END-SLOW-SECTION"
            break
            ;;
        # unknown positional
        *)
            echo "Unknown category: \"$ARG\""
            exit 1
            ;;
    esac
done

# exit if source is dirty
if [[ -z "$ALLOW_DIRTY" ]] && git ls-files --modified --error-unmatch "$SOURCE_PATH" >/dev/null 2>&1; then
    echo "$SOURCE_PATH is dirty; refusing to edit."
    exit 2
fi

# processing
##############################

# create write buffer
TARGET_BUFFER="$(mktemp -t 'ProxyList-target.XXXXX')"

# before begin tag
sed "/$BEGIN_TAG/q" "$SOURCE_PATH" >> "$TARGET_BUFFER"

# update date
DATE="$(date +%m/%d/%Y)"
sed -Ei "\\|; Date: [[:digit:]]+(/[[:digit:]]+){2}| s|[[:digit:]]+(/[[:digit:]]+){2}|$DATE|" "$TARGET_BUFFER"

# preprocess, append, and sort
PREPROCESS_BUFFER="$(mktemp -t 'ProxyList-preprocess.XXXXX')"
cut -d ' ' -f 1 - > "$PREPROCESS_BUFFER"
sed -n "/$BEGIN_TAG/,/$END_TAG/{//!p}" "$SOURCE_PATH" | cat - "$PREPROCESS_BUFFER" | sort >> "$TARGET_BUFFER"
rm -f "$PREPROCESS_BUFFER"

# after end tag
sed -n "/$END_TAG/,\${p}" "$SOURCE_PATH" >> "$TARGET_BUFFER"

# write back
mv -f "$TARGET_BUFFER" "$SOURCE_PATH"
