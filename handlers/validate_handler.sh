execute_validate () {
  delete_existing_comments "validate" '### OpenTofu `validate` Failed'

  # Exit Code: 0
  # Meaning: OpenTofu successfully validated.
  # Actions: Exit.
  if [[ $EXIT_CODE -eq 0 ]]; then
    validate_success
  fi

  # Exit Code: 1
  # Meaning: OpenTofu validate failed or malformed OpenTofu CLI command.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 ]]; then
    validate_fail
  fi
}

validate_success () {
  info "OpenTofu validate completed with no errors. Continuing."
}

validate_fail () {
  local pr_comment

  pr_comment=$(make_details_with_header "OpenTofu \`validate\` Failed" "$INPUT" "diff")

  make_and_post_payload "validate failure" "$pr_comment"
}