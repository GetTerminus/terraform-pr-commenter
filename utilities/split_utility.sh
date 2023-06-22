split_string () {
  local -n split=$1
  local entire_string=$2
  local remaining_string=$entire_string
  local processed_length=0
  split=()

  debug "Total length to split: ${#remaining_string}"
  # trim to the last newline that fits within length
  while [ ${#remaining_string} -gt 0 ] ; do
    debug "Remaining input: \n${remaining_string}"

    local current_iteration=${remaining_string::65300} # GitHub has a 65535-char comment limit - truncate and iterate
    if [ ${#current_iteration} -ne ${#remaining_string} ] ; then
      debug "String is over 64k length limit.  Splitting at index ${#current_iteration} of ${#remaining_string}."
      current_iteration="${current_iteration%$'\n'*}" # trim to the last newline
      debug "Trimmed split string to index ${#current_iteration}"
    fi
    processed_length=$((processed_length+${#current_iteration})) # evaluate length of outbound comment and store

    debug "Processed string length: ${processed_length}"
    split+=("$current_iteration")

    remaining_string=${entire_string:processed_length}
  done
}

get_page_count () {
  local link_header
  local last_page=1

  link_header=$(curl -sSI -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENTS_URL" | grep -i ^link)

  # if I find a matching link header...
  if grep -Fi 'rel="next"' <<< "$link_header"; then
    # we found a next page -> find the last page
    IFS=',' read -ra links <<< "$link_header"
    for link in "${links[@]}"; do
      # process "$i"
      local regex
      page_regex='^.*page=([0-9]+).*$'

      # if this is the 'last' ref...
      if grep -Fi 'rel="last"' <<< "$link" ; then
        if [[ $link =~ $page_regex ]]; then
          last_page="${BASH_REMATCH[1]}"
          break
        fi
      fi
    done
  fi

  eval "$1"="$last_page"
}