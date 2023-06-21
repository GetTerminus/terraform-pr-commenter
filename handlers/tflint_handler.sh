execute_tflint () {
  # shellcheck disable=SC2016
  delete_existing_comments 'tflint' '### Linter `tflint` .* for Workspace: `'"$WORKSPACE"'`.*'

  debug "Exit Code: $EXIT_CODE"

  # Exit Code: 0, 2
  # Meaning: 0 = Linter succeeded with no issues. 2 = Linter succeeded with issues.
  # Actions: If exit code 0 then Exit. If exit code 2 Build PR Comment
  if [[ $EXIT_CODE -eq 0 || $EXIT_CODE -eq 2 ]]; then
    if [[ $EXIT_CODE -eq 0 ]]; then
      info "Linter tflint completed with no errors. Continuing."
    else
      info "Linter tflint completed with issues."
      tflint_success
    fi
  fi

  # Exit Code: 1
  # Meaning: Errors occured.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 ]]; then
    tflint_fail
  fi
}

tflint_success () {
  post_tflint_comments
}

post_tflint_comments () {
  debug "Input: $INPUT"
  local clean_input
  local comment

  #clean_input=$(echo "$INPUT" | perl -pe'$_="" unless /(Planning failed. Terraform encountered an error while generating this plan.)/ .. 1')
  clean_input="$INPUT"
  comment=$(make_details_with_header "Linter \`tflint\` Failed for Workspace: \`$WORKSPACE\`" "$clean_input")

  # Add comment to PR.
  make_and_post_payload "tflint failure" "$comment"
}

tflint_fail () {
  local clean_input
  local comment

  #clean_input=$(echo "$INPUT" | perl -pe'$_="" unless /(Planning failed. Terraform encountered an error while generating this plan.)/ .. 1')
  clean_input="$INPUT"
  comment=$(make_details_with_header "Linter \`tflint\` Failed for Workspace: \`$WORKSPACE\`" "$clean_input")

  # Add init failure comment to PR.
  make_and_post_payload "tflint failure" "$comment"
}