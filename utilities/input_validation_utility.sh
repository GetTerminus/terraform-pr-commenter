validate_inputs () {
  PR_NUMBER=$(echo "$GITHUB_EVENT" | jq -r ".pull_request.number")
  if [[ "$PR_NUMBER" == "null" ]]; then
    error "This isn't a PR."
    exit 0
  fi

  if [[ -z "$GITHUB_TOKEN" ]]; then
    error "GITHUB_TOKEN environment variable missing."
    exit 1
  fi

  if [[ -z $2 ]]; then
      error "There must be an exit code from a previous step."
      exit 1
  fi

  if [[ ! "$1" =~ ^(fmt|init|plan|validate|tflint)$ ]]; then
    error "Unsupported command \"$1\". Valid commands are \"fmt\", \"init\", \"plan\", \"validate\", \"tflint\"."
    exit 1
  fi

  if [[ $1 == "plan" ]]; then
    if [[ -z "$COMMENTER_INPUT" ]]; then
      if [[ -z "$COMMENTER_PLAN_FILE" ]]; then
        error "The commenter_plan_path input variable must be set if commenter_input is empty."
        exit 1
      fi
    fi
  else
    if [[ -z "$COMMENTER_INPUT" ]]; then
      error "The commenter_input input variable must be set for non plan commenter types."
      exit 1
    fi
  fi
}