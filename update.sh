#!/usr/bin/env bash

# Synopsis: cat new-lines.txt | ./update.sh blocked|redirect|slow

set -e

# inputs
##############################

GIT_ROOT="$(git rev-parse --show-toplevel)"

# handle arguments
# flags must come before positional argument
for ARG in "$@"; do
    case "$ARG" in
        # flags
        --allow-dirty)
            ALLOW_DIRTY=1
            ;;
        --no-update-time)
            NO_UPDATE_TIME=1
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
if [[ -z "$SOURCE_PATH" ]]; then
    echo "A category must be provided"
    exit 1
fi

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
if [[ -z "$NO_UPDATE_TIME" ]]; then
    DATE="$(date +%m/%d/%Y)"
    sed -Ei "\\|; Date: [[:digit:]]+(/[[:digit:]]+){2}| s|[[:digit:]]+(/[[:digit:]]+){2}|$DATE|" "$TARGET_BUFFER"
fi

# buffer original
SORT_BUFFER="$(mktemp -t 'Proxylist-sort.XXXXX')"
sed -n "/$BEGIN_TAG/,/$END_TAG/{//!p}" "$SOURCE_PATH" >> "$SORT_BUFFER"

# preprocess and buffer if there is data on stdin
if read -t 0 -N 0; then
  cut -d ' ' -f 1 - >> "$SORT_BUFFER"
fi

# filter, sort, and append buffer
sed -E '/^\s*$/d' "$SORT_BUFFER" | sort >> "$TARGET_BUFFER"
rm -f "$SORT_BUFFER"

# after end tag
sed -n "/$END_TAG/,\${p}" "$SOURCE_PATH" >> "$TARGET_BUFFER"

# write back
mv -f "$TARGET_BUFFER" "$SOURCE_PATH"
