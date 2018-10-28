#!/bin/bash

function filter_lfs() {
    while read FILE; do
        if test "$(head -n1 $FILE)" = "version https://git-lfs.github.com/spec/v1"; then
            echo "$FILE";
        fi;
    done
}

function get_lfs_hashes() {
    while read COMMIT; do
        git checkout $COMMIT >& /dev/null;
        git ls-files | filter_lfs | while read FILE; do
            head -2 $FILE | tail -1;
        done;
    done | sed 's|oid sha256:||; s|^\(..\)\(..\)\(.*\)$|\1/\2/\3|' | sort -u;
}

function set_diff() {
    python -c 'import sys; to_set = lambda x: set([y.strip() for y in open(x).readlines()]); print "\n".join(to_set(sys.argv[1]) - to_set(sys.argv[2]))' "$1" "$2"
}
