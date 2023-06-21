make_and_post_payload () {
  # Add plan comment to PR.
  local kind=$1
  local pr_payload=$(echo '{}' | jq --arg body "$2" '.body = $body')

  info "Adding $kind comment to PR."

  if [[ $COMMENTER_DEBUG == true ]]; then
    post_comment
  else
    post_comment > /dev/null
  fi
}

post_comment () {
  curl -sS -L -X POST -H "$ACCEPT_HEADER" -H "$AUTH_HEADER" -H "$CONTENT_HEADER" "$PR_COMMENTS_URL" -d "$pr_payload"
}

delete_existing_comments () {
  # Look for an existing PR comment and delete
  # debug "Existing comments:  $(curl -sS -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L $PR_COMMENTS_URL)"

  local type=$1
  local regex=$2
  local last_page

  debug "Type: $type"
  debug "Regex: $regex"

  local jq='.[] | select(.body|test ("'
  jq+=$regex
  jq+='")) | .id'

  # gross, but... bash.
  get_page_count PAGE_COUNT
  last_page=$PAGE_COUNT
  info "Found $last_page page(s) of comments at $PR_COMMENTS_URL."

  info "Looking for an existing $type PR comment."
  local comment_ids=()
  for page in $(seq $last_page)
  do
    # first, we read *all* of the comment IDs across all pages.  saves us from the problem where we read a page, then
    # delete some, then read the next page, *after* our page boundary has moved due to the delete.
      # CAUTION.  this line assumes the PR_COMMENTS_URL already has at least one query parameter. (note the '&')
    readarray -t -O "${#comment_ids[@]}" comment_ids < <(curl -sS -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENTS_URL&page=$page" | jq "$jq")
  done

  for PR_COMMENT_ID in "${comment_ids[@]}"
  do
    FOUND=true
    info "Found existing $type PR comment: $PR_COMMENT_ID. Deleting."
    PR_COMMENT_URL="$PR_COMMENT_URI/$PR_COMMENT_ID"
    STATUS=$(curl -sS -X DELETE -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -o /dev/null -w "%{http_code}" -L "$PR_COMMENT_URL")
    debug "Status: $STATUS"
    if [ "$STATUS" != "204"  ]; then
      info "Failed to delete:  status $STATUS (most likely rate limited)"
    fi
  done

  if [ -z $FOUND ]; then
    info "No existing $type PR comment found."
  fi
}

post_diff_comments () {
  local type=$1
  local comment_prefix=$2
  local comment_string=$3

  debug "Total $type length: ${#comment_string}"
  local comment_split
  split_string comment_split "$comment_string"
  local comment_count=${#comment_split[@]}

  info "Writing $comment_count $type comment(s)"

  for i in "${!comment_split[@]}"; do
    local current="${comment_split[$i]}"
    local colorized_comment=$(substitute_and_colorize "$current")
    local comment_count_text=""
    if [ "$comment_count" -ne 1 ]; then
      comment_count_text=" ($((i+1))/$comment_count)"
    fi

    local comment=$(make_details_with_header "$comment_prefix$comment_count_text" "$colorized_comment" "diff")
    make_and_post_payload "$type" "$comment"
  done
}

make_details_with_header() {
  local header="### $1"
  local body=$2
  local format=$3
  local pr_comment="$header
$(make_details "Show Output" "$body" "$format")"
  echo "$pr_comment"
}

make_details() {
  local summary="$1"
  local body=$2
  local format=$3
  local details="<details$DETAILS_STATE><summary>$summary</summary>

\`\`\`$format
$body
\`\`\`
</details>"
  echo "$details"
}

substitute_and_colorize () {
  local current_plan=$1
    current_plan=$(echo "$current_plan" | sed -r 's/^([[:blank:]]*)([😅+~])/\2\1/g' | sed -r 's/^😅/-/')
  if [[ $COLOURISE == 'true' ]]; then
    current_plan=$(echo "$current_plan" | sed -r 's/^~/!/g') # Replace ~ with ! to colourise the diff in GitHub comments
  fi
  echo "$current_plan"
}

color_yellow () {
  echo "\033[33;1m$1\033[0m"
}

color_red () {
  echo "\033[31;1m$1\033[0m"
}

start_delimiter_builder () {
  local delimiter_string
  delimiter_string=$(print_array "$@")
  printf "$_="" unless /(%s)/ .. 1" "${delimiter_string}"
}

end_delimiter_builder () {
  printf "%s/q" "$1"
}

print_array ()
{
  # run through array and print each entry:
  local array
  array=("$@")
  for i in "${array[@]}" ; do
      printf '%s|' "$i"
  done
}