#!/bin/bash
set -x

ACCEPT_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GH_TOKEN"
CONTENT_HEADER="Content-Type: application/json"

PR_COMMENTS_URL="https://api.github.com/repos/GetTerminus/eks-observability-infra/issues/4/comments"
PR_COMMENT_URI="https://api.github.com/repos/GetTerminus/eks-observability-infra/issues/comments/4"

PAGE_COUNT=1

###########
# Logging #
###########
debug () {
  if [ -n "${COMMENTER_DEBUG+x}" ]; then
    echo -e "\033[33;1mDEBUG:\033[0m $1"
  fi
}

info () {
  echo -e "\033[34;1mINFO:\033[0m $1"
}

error () {
  echo -e "\033[31;1mERROR:\033[0m $1"
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

delete_existing_comments () {
  # Look for an existing PR comment and delete
  # debug "Existing comments:  $(curl -sS -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L $PR_COMMENTS_URL)"

  local type=$1
  local regex=$2
  local last_page

  local jq='.[] | select(.body|test ("'
  jq+=$regex
  jq+='")) | .id'

  # gross, but... bash.
  get_page_count PAGE_COUNT
  last_page=$PAGE_COUNT
  info "Found $last_page page(s) of comments."

  info "Looking for an existing $type PR comment."
  for page in $(seq $last_page)
  do
    for PR_COMMENT_ID in $(curl -sS -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENTS_URL&page=$page" | jq "$jq")
    do
      FOUND=true
      info "Found existing $type PR comment: $PR_COMMENT_ID. Deleting."
      PR_COMMENT_URL="$PR_COMMENT_URI/$PR_COMMENT_ID"
      #curl -sS -X DELETE -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENT_URL" > /dev/null
    done
  done

  if [ -z $FOUND ]; then
    info "No existing $type PR comment found."
  fi
}

WORKSPACE=prod-east
delete_existing_comments 'plan' '### Terraform `plan` .* for Workspace: `'$WORKSPACE'`.*'