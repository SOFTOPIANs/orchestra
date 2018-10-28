#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set -e

source "$SCRIPT_PATH/lfs-helpers.sh"

set_diff <(git lfs ls-files | awk '{ print $3 }') \
         <(find * -type l | while read FILE; do
               echo $FILE;
               readlink -f "$FILE" | sed 's|^'"$PWD"'||; s|^/||';
           done) | while read FILE; do if test -e "$FILE"; then git rm "$FILE"; fi; done
