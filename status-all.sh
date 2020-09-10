#!/usr/bin/env bash

for path in *; do
  if [ -d "$path" ]; then
    cd "$path"
    ## use script to maintain color output
    if [[ "$OSTYPE" =~ "linux" ]]; then
      status=$(script -q -c "git status -s" /dev/null | cat)
    else
      status=$(script -q /dev/null git status -s | cat)
    fi
    if [ "${status}x" != "x" ]; then
      ## pretty output with path name
      printf "[%s]\n%s\n" "$path" "$status"
    fi
    fetch=$(git fetch --dry-run 2>&1 | grep ' -> ' | wc -l)
    if [ $fetch -gt "0" ]; then
      printf "fetch would update %s branches\n" "$fetch"
    fi
    cd ..
  fi
done
