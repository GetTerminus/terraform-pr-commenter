#!/usr/bin/env bash

if [ -n "${COMMENTER_ECHO+x}" ]; then
  set -x
fi

#############
# Validations
#############
PR_NUMBER=$(echo "$GITHUB_EVENT" | jq -r ".pull_request.number")
if [[ "$PR_NUMBER" == "null" ]]; then
	echo "This isn't a PR."
	exit 0
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "GITHUB_TOKEN environment variable missing."
	exit 1
fi

if [[ -z $3 ]]; then
    echo "There must be an exit code from a previous step."
    exit 1
fi

if [[ ! "$1" =~ ^(fmt|init|plan|validate)$ ]]; then
  echo -e "Unsupported command \"$1\". Valid commands are \"fmt\", \"init\", \"plan\", \"validate\"."
  exit 1
fi

#############
# Functions #
#############
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

make_and_post_payload () {
  # Add plan comment to PR.
  PR_PAYLOAD=$(echo '{}' | jq --arg body "$1" '.body = $body')
  info "Adding plan comment to PR."
  debug "PR payload:\n$PR_PAYLOAD"
  curl -sS -X POST -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$CONTENT_HEADER" -d "$PR_PAYLOAD" -L "$PR_COMMENTS_URL" > /dev/null
}

# usage:  split_plan target_array_name plan_text
split_plan () {
  local -n split=$1
  local remaining_plan=$2
  local processed_plan_length=0
  split=()
  # trim to the last newline that fits within length
  while [ ${#remaining_plan} -gt 0 ] ; do
    debug "Remaining plan: \n${remaining_plan}"

    local current_plan=${remaining_plan::65300} # GitHub has a 65535-char comment limit - truncate and iterate
    if [ ${#current_plan} -ne ${#remaining_plan} ] ; then
      debug "Plan is over 64k length limit.  Splitting at index ${#current_plan} of ${#remaining_plan}."
      current_plan="${current_plan%$'\n'*}" # trim to the last newline
      debug "Trimmed split string to index ${#current_plan}"
    fi
    processed_plan_length=$((processed_plan_length+${#current_plan})) # evaluate length of outbound comment and store

    debug "Processed plan length: ${processed_plan_length}"
    split+=("$current_plan")
    remaining_plan=${remaining_plan:processed_plan_length}
  done
}

substitute_and_colorize () {
  local current_plan=$1
    current_plan=$(echo "$current_plan" | sed -r 's/^([[:blank:]]*)([😅+~])/\2\1/g' | sed -r 's/^😅/-/')
  if [[ $COLOURISE == 'true' ]]; then
    current_plan=$(echo "$current_plan" | sed -r 's/^~/!/g') # Replace ~ with ! to colourise the diff in GitHub comments
  fi
  echo "$current_plan"
}

delete_existing_comments () {
  # Look for an existing PR comment and delete
  echo -e "TEST:  PRS $(curl -sS -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L $PR_COMMENTS_URL)"

  local type=$1
  local regex=$2

  local jq='.[] | select(.body|test ("'
  jq+=$regex
  jq+='")) | .id'
  echo -e "\033[34;1mINFO:\033[0m Looking for an existing $type PR comment."
  for PR_COMMENT_ID in $(curl -sS -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L $PR_COMMENTS_URL | jq "$jq")
  do
    FOUND=true
    echo -e "\033[34;1mINFO:\033[0m Found existing $type PR comment: $PR_COMMENT_ID. Deleting."
    PR_COMMENT_URL="$PR_COMMENT_URI/$PR_COMMENT_ID"
    curl -sS -X DELETE -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENT_URL" > /dev/null
  done
  if [ -z $FOUND ]; then
    echo -e "\033[34;1mINFO:\033[0m No existing $type PR comment found."
  fi
}

plan_success () {
  local clean_plan=$(echo "$INPUT" | perl -pe'$_="" unless /(An execution plan has been generated and is shown below.|Terraform used the selected providers to generate the following execution|No changes. Infrastructure is up-to-date.|No changes. Your infrastructure matches the configuration.)/ .. 1') # Strip refresh section
  clean_plan=$(echo "$clean_plan" | sed -r '/Plan: /q') # Ignore everything after plan summary

  debug "Total plan length: ${#clean_plan}"
  local plan_split
  split_plan plan_split "$clean_plan"

  echo "Writing ${#plan_split[@]} plan comment(s)"

  for plan in "${plan_split[@]}"; do
    local colorized_plan=$(substitute_and_colorize "$plan")
    local comment="### Terraform \`plan\` Succeeded for Workspace: \`$WORKSPACE\`
<details$DETAILS_STATE><summary>Show Output</summary>

\`\`\`diff
$colorized_plan
\`\`\`
</details>"
    make_and_post_payload "$comment"
  done
}

plan_fail () {
  local comment="### Terraform \`plan\` Failed for Workspace: \`$WORKSPACE\`
<details$DETAILS_STATE><summary>Show Output</summary>

\`\`\`
$INPUT
\`\`\`
</details>"

  # Add plan comment to PR.
  make_and_post_payload "$(echo '{}' | jq --arg body "$comment" '.body = $body')"
}

execute_plan () {
  delete_existing_comments 'plan' '### Terraform `plan` .* for Workspace: `'$WORKSPACE'`'

  # Exit Code: 0, 2
  # Meaning: 0 = Terraform plan succeeded with no changes. 2 = Terraform plan succeeded with changes.
  # Actions: Strip out the refresh section, ignore everything after the 72 dashes, format, colourise and build PR comment.
  if [[ $EXIT_CODE -eq 0 || $EXIT_CODE -eq 2 ]]; then
    plan_success
  fi

    # Exit Code: 1
  # Meaning: Terraform plan failed.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 ]]; then
    plan_fail
  fi
}

##################
# Shared Variables
##################
# Arg 1 is command
COMMAND=$1
# Arg 2 is input file. We strip ANSI colours.
RAW_INPUT="$COMMENTER_INPUT"
if test -f "/workspace/tfplan"; then
  info "Found tfplan; showing."
  pushd workspace > /dev/null || (error "Failed to push workspace dir" && exit 1)
  INIT_OUTPUT="$(terraform init 2>&1)"
  INIT_RESULT=$?
  if [ $INIT_RESULT -ne 0 ]; then
     error "Failed pre-plan init.  Init output: \n$INIT_OUTPUT"
     exit 1
  fi
  RAW_INPUT="$( terraform show "tfplan" 2>&1 )"
  SHOW_RESULT=$?
  if [ $SHOW_RESULT -ne 0 ]; then
     error "Plan failed to show.  Plan output: \n$RAW_INPUT"
     exit 1
  fi
  popd > /dev/null || (error "Failed to pop workspace dir" && exit 1)
  debug "Plan raw input: $RAW_INPUT"
else
  info "Found no tfplan.  Proceeding with input argument."
fi

# change diff character, a red '-', into a high unicode character \U1f605 (literally 😅)
# iff not preceded by a literal "/" as in "+/-".
# this serves as an intermediate representation representing "diff removal line" as distinct from
# a raw hyphen which could *also* indicate a yaml list entry.
INPUT=$(echo "$RAW_INPUT" | perl -pe "s/(?<!\/)\e\[31m-\e\[0m/😅/g")

# now remove all ANSI colors
INPUT=$(echo "$INPUT" | sed -r 's/\x1b\[[0-9;]*m//g')

# Arg 3 is the Terraform CLI exit code
EXIT_CODE=$3

# Read TF_WORKSPACE environment variable or use "default"
WORKSPACE=${TF_WORKSPACE:-default}

# Read EXPAND_SUMMARY_DETAILS environment variable or use "true"
if [[ ${EXPAND_SUMMARY_DETAILS:-true} == "true" ]]; then
  DETAILS_STATE=" open"
else
  DETAILS_STATE=""
fi

# Read HIGHLIGHT_CHANGES environment variable or use "true"
COLOURISE=${HIGHLIGHT_CHANGES:-true}

ACCEPT_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
CONTENT_HEADER="Content-Type: application/json"

PR_COMMENTS_URL=$(echo "$GITHUB_EVENT" | jq -r ".pull_request.comments_url")
PR_COMMENT_URI=$(echo "$GITHUB_EVENT" | jq -r ".repository.issue_comment_url" | sed "s|{/number}||g")


##############
# Handler: fmt
##############
if [[ $COMMAND == 'fmt' ]]; then
  # Look for an existing fmt PR comment and delete
  info "Looking for an existing fmt PR comment."
  PR_COMMENT_ID=$(curl -sS -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENTS_URL" | jq '.[] | select(.body|test ("### Terraform `fmt` Failed")) | .id')
  if [ "$PR_COMMENT_ID" ]; then
    info "Found existing fmt PR comment: $PR_COMMENT_ID. Deleting."
    PR_COMMENT_URL="$PR_COMMENT_URI/$PR_COMMENT_ID"
    curl -sS -X DELETE -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENT_URL" > /dev/null
  else
    info "No existing fmt PR comment found."
  fi

  # Exit Code: 0
  # Meaning: All files formatted correctly.
  # Actions: Exit.
  if [[ $EXIT_CODE -eq 0 ]]; then
    info "Terraform fmt completed with no errors. Continuing."

    exit 0
  fi

  # Exit Code: 1, 2
  # Meaning: 1 = Malformed Terraform CLI command. 2 = Terraform parse error.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 || $EXIT_CODE -eq 2 ]]; then
    PR_COMMENT="### Terraform \`fmt\` Failed
<details$DETAILS_STATE><summary>Show Output</summary>

\`\`\`
$INPUT
\`\`\`
</details>"
  fi

  # Exit Code: 3
  # Meaning: One or more files are incorrectly formatted.
  # Actions: Iterate over all files and build diff-based PR comment.
  if [[ $EXIT_CODE -eq 3 ]]; then
    ALL_FILES_DIFF=""
    for file in $INPUT; do
      THIS_FILE_DIFF=$(terraform fmt -no-color -write=false -diff "$file")
      ALL_FILES_DIFF="$ALL_FILES_DIFF
<details$DETAILS_STATE><summary><code>$file</code></summary>

\`\`\`diff
$THIS_FILE_DIFF
\`\`\`
</details>"
    done

    PR_COMMENT="### Terraform \`fmt\` Failed
$ALL_FILES_DIFF"
  fi

  # Add fmt failure comment to PR.
  PR_PAYLOAD=$(echo '{}' | jq --arg body "$PR_COMMENT" '.body = $body')
  info "Adding fmt failure comment to PR."
  curl -sS -X POST -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$CONTENT_HEADER" -d "$PR_PAYLOAD" -L "$PR_COMMENTS_URL" > /dev/null

  exit 0
fi

###############
# Handler: init
###############
if [[ $COMMAND == 'init' ]]; then
  # Look for an existing init PR comment and delete
  info "Looking for an existing init PR comment."
  PR_COMMENT_ID=$(curl -sS -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENTS_URL" | jq '.[] | select(.body|test ("### Terraform `init` Failed")) | .id')
  if [ "$PR_COMMENT_ID" ]; then
    info "Found existing init PR comment: $PR_COMMENT_ID. Deleting."
    PR_COMMENT_URL="$PR_COMMENT_URI/$PR_COMMENT_ID"
    curl -sS -X DELETE -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENT_URL" > /dev/null
  else
    info "No existing init PR comment found."
  fi

  # Exit Code: 0
  # Meaning: Terraform successfully initialized.
  # Actions: Exit.
  if [[ $EXIT_CODE -eq 0 ]]; then
    info "Terraform init completed with no errors. Continuing."

    exit 0
  fi

  # Exit Code: 1
  # Meaning: Terraform initialize failed or malformed Terraform CLI command.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 ]]; then
    PR_COMMENT="### Terraform \`init\` Failed
<details$DETAILS_STATE><summary>Show Output</summary>

\`\`\`
$INPUT
\`\`\`
</details>"
  fi

  # Add init failure comment to PR.
  PR_PAYLOAD=$(echo '{}' | jq --arg body "$PR_COMMENT" '.body = $body')
  info "Adding init failure comment to PR."
  curl -sS -X POST -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$CONTENT_HEADER" -d "$PR_PAYLOAD" -L "$PR_COMMENTS_URL" > /dev/null

  exit 0
fi

###############
# Handler: plan
###############
if [[ $COMMAND == 'plan' ]]; then
  execute_plan
  exit 0
fi

###################
# Handler: validate
###################
if [[ $COMMAND == 'validate' ]]; then
  # Look for an existing validate PR comment and delete
  info "Looking for an existing validate PR comment."
  PR_COMMENT_ID=$(curl -sS -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENTS_URL" | jq '.[] | select(.body|test ("### Terraform `validate` Failed")) | .id')
  if [ "$PR_COMMENT_ID" ]; then
    info "Found existing validate PR comment: $PR_COMMENT_ID. Deleting."
    PR_COMMENT_URL="$PR_COMMENT_URI/$PR_COMMENT_ID"
    curl -sS -X DELETE -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -L "$PR_COMMENT_URL" > /dev/null
  else
    info "No existing validate PR comment found."
  fi

  # Exit Code: 0
  # Meaning: Terraform successfully validated.
  # Actions: Exit.
  if [[ $EXIT_CODE -eq 0 ]]; then
    info "Terraform validate completed with no errors. Continuing."

    exit 0
  fi

  # Exit Code: 1
  # Meaning: Terraform validate failed or malformed Terraform CLI command.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 ]]; then
    PR_COMMENT="### Terraform \`validate\` Failed
<details$DETAILS_STATE><summary>Show Output</summary>

\`\`\`
$INPUT
\`\`\`
</details>"
  fi

  # Add validate failure comment to PR.
  PR_PAYLOAD=$(echo '{}' | jq --arg body "$PR_COMMENT" '.body = $body')
  info "Adding validate failure comment to PR."
  curl -sS -X POST -H "$AUTH_HEADER" -H "$ACCEPT_HEADER" -H "$CONTENT_HEADER" -d "$PR_PAYLOAD" -L "$PR_COMMENTS_URL" > /dev/null

  exit 0
fi
