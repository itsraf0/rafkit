#!/usr/bin/env bash

COLOR_DIR="\033[97m"
COLOR_FILE="\033[36m"
COLOR_LINK="\033[35m"
COLOR_RESET="\033[0m"
depth="${1:-4}"

if ! [[ "$depth" =~ ^[0-9]+$ ]]; then
  echo "Error: depth must be a non-negative integer." >&2
  exit 1
fi

shopt -s dotglob nullglob

#-----------------#

print_tree() {
  local prefix="$1"
  local path="$2"
  local level="$3"


  if (( level > depth )); then
    return
  fi

  local entries=("$path"/*)
  local count=${#entries[@]}

  for i in "${!entries[@]}"; do
    local entry="${entries[$i]}"
    local name="${entry##*/}"

    if [[ "$name" == "." || "$name" == ".." ]]; then
      continue
    fi

    local is_last=false
    if (( i == count - 1 )); then
      is_last=true
    fi

    local branch
    if $is_last; then
      branch="└──"
      new_prefix="${prefix}    "
    else
      branch="├──"
      new_prefix="${prefix}│   "
    fi

    local color
    if [ -L "$entry" ]; then
      color="$COLOR_LINK"
    elif [ -d "$entry" ]; then
      color="$COLOR_DIR"
    else
      color="$COLOR_FILE"
    fi

    echo -e "${prefix}${branch} ${color}${name}${COLOR_RESET}"

    if [ -d "$entry" ] && ! [ -L "$entry" ]; then
      print_tree "$new_prefix" "$entry" $((level + 1))
    fi
  done
}

# start
echo -e "${COLOR_DIR}.${COLOR_RESET}"
print_tree "" "." 1
