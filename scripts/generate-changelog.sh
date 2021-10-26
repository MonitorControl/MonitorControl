#!/bin/bash

# Note: Make sure to only run this script after posting release notes in Github with a release!
# Could be expanded to also do appcast.xml updates?

exists() {
  type "$1" &>/dev/null && return 0 || return 1
} 

show_error() {
  local msg="Error!"
  if [ ! -z "$1" ]; then
    msg="$1"
  fi
  echo -e "\033[0;31m${msg}\033[0m"
}

show_warning() {
  local msg="Warning!"
  if [ ! -z "$1" ]; then
    msg="$1"
  fi
  echo -e "\033[0;33m${msg}\033[0m"
}

show_success() {
  local msg="Success!"
  if [ ! -z "$1" ]; then
    msg="$1"
  fi
  echo -e "\033[0;32m${msg}\033[0m"
}

if ! exists jq; then
        show_error "\`jq\` is required but not installed. Install using: brew install jq"
        exit 127
fi

if ! exists pandoc; then
        show_error "\`pandoc\` is required but not installed. Install using: brew install pandoc"
        exit 127
fi

# TODO: Expand to check last x (per_page) releases (input parameter or fallback)
URL="https://api.github.com/repos/MonitorControl/MonitorControl/releases?per_page=1"

# store the whole response
HTTP_RESPONSE=$(curl --fail -s $URL)

if [ $? != 0 ]; then
        show_error "Something went wrong getting Github Release info. Exiting..."
        exit 1
fi

TAG=`echo $HTTP_RESPONSE | jq '.[0].tag_name' -r`
DIR="`dirname $0`/../docs/changelogs/"
FILE_NAME="${TAG}.html"
FILE="$DIR$FILE_NAME"

if [ -f $FILE ]; then
        show_warning "\"$FILE_NAME\" Already exists! Will be overwritten.."
fi

echo $HTTP_RESPONSE | jq '.[0].body' -r | pandoc --template $DIR/template.html --metadata title="$TAG" -o $FILE 

if [ $? -eq 0 ]; then
        show_success "\"$FILE_NAME\" Created at \"$DIR\""
fi

exit