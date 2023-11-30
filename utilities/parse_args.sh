##################
# Shared Variables
##################
parse_args () {
  # Arg 1 is command
  COMMAND=$1
  debug "COMMAND: $COMMAND"

  # Arg 3 is the Terraform CLI exit code
  EXIT_CODE=$2
  debug "EXIT_CODE: $EXIT_CODE"

  # Arg 2 is input file. We strip ANSI colours.
  RAW_INPUT="$COMMENTER_INPUT"
  debug "COMMENTER_INPUT: $COMMENTER_INPUT"

  if [[ $COMMAND == 'plan' ]]; then
    if test -f "workspace/${COMMENTER_PLAN_FILE}"; then
      info "Found commenter plan file."
      pushd workspace > /dev/null || (error "Failed to push workspace dir" && exit 1)
      RAW_INPUT="$( cat "${COMMENTER_PLAN_FILE}" 2>&1 )"
      popd > /dev/null || (error "Failed to pop workspace dir" && exit 1)
    else
      info "Found no tfplan file. Using input argument."
    fi
  else
    info "Not terraform plan. Using input argument."
  fi

  # change diff character, a red '-', into a high unicode character \U1f605 (literally 😅)
  # if not preceded by a literal "/" as in "+/-".
  # this serves as an intermediate representation representing "diff removal line" as distinct from
  # a raw hyphen which could *also* indicate a yaml list entry.
  INPUT=$(echo "$RAW_INPUT" | perl -pe "s/(?<!\/)\e\[31m-\e\[0m/😅/g")

  # now remove all ANSI colors
  INPUT=$(echo "$INPUT" | sed -r 's/\x1b\[[0-9;]*m//g')

  # remove terraform debug lines
  INPUT=$(echo "$INPUT" | sed '/^::debug::Terraform exited with code/,$d')

  # shellcheck disable=SC2034
  WARNING=$(echo "$INPUT" | grep "│ Warning: " -q && echo "TRUE" || echo "FALSE")

  # Read TF_WORKSPACE environment variable or use "default"
  # shellcheck disable=SC2034
  WORKSPACE=${TF_WORKSPACE:-default}

  # Read EXPAND_SUMMARY_DETAILS environment variable or use "true"
  if [[ ${EXPAND_SUMMARY_DETAILS:-false} == "true" ]]; then
    DETAILS_STATE=" open"
  else
    # shellcheck disable=SC2034
    DETAILS_STATE=""
  fi

  # Read HIGHLIGHT_CHANGES environment variable or use "true"
  # shellcheck disable=SC2034
  COLOURISE=${HIGHLIGHT_CHANGES:-true}

  # support multiple-module plan outputs (e.g., when running Terragrunt)
  MULTIPLE_MODULES=${COMMENTER_MULTIPLE_MODULES:-true}
  # Read COMMENTER_POST_PLAN_OUTPUTS environment variable or use "true"
  # shellcheck disable=SC2034
  POST_PLAN_OUTPUTS=${COMMENTER_POST_PLAN_OUTPUTS:-true}

  # shellcheck disable=SC2034
  ACCEPT_HEADER="Accept: application/vnd.github+json"
  # shellcheck disable=SC2034
  AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
  # shellcheck disable=SC2034
  CONTENT_HEADER="X-GitHub-Api-Version: 2022-11-28"

  PR_COMMENTS_URL=$(echo "$GITHUB_EVENT" | jq -r ".pull_request.comments_url")
  PR_COMMENTS_URL+="?per_page=100"

  # shellcheck disable=SC2034
  PR_COMMENT_URI=$(echo "$GITHUB_EVENT" | jq -r ".repository.issue_comment_url" | sed "s|{/number}||g")
}