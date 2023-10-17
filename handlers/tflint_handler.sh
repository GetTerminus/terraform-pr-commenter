execute_tflint() {
  # shellcheck disable=SC2016
  delete_existing_comments 'tflint' '### Linter `TFLint` .* for Workspace: `'"$WORKSPACE"'`.*'

  # Exit Code: 0
  # Meaning: TFLint found 0 issues.
  # Actions: Exit.
  if [[ $EXIT_CODE -eq 0 ]]; then
    tflint_success
  fi

  # Exit Code: 1, 2
  # Meaning: 1 = Malformed TFLint CLI command. 2 = TFLint found issues.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 || $EXIT_CODE -eq 2 ]]; then
    tflint_fail
  fi
}

tflint_success() {
  info "TFLint completed with no errors. Continuing."
}

tflint_fail() {
  local pr_comment

  pr_comment=$(make_details_with_header "Linter \`TFLint\` Failed for Workspace: \`$WORKSPACE\` ❌" "$INPUT")

  make_and_post_payload "tflint failure" "$pr_comment"
}
