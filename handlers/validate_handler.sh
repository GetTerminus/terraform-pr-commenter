execute_validate () {
  delete_existing_comments "validate" '### Terraform `validate` Failed'

  # Exit Code: 0
  # Meaning: Terraform successfully validated.
  # Actions: Exit.
  if [[ $EXIT_CODE -eq 0 ]]; then
    validate_success
  fi

  # Exit Code: 1
  # Meaning: Terraform validate failed or malformed Terraform CLI command.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 ]]; then
    validate_fail
  fi
}

validate_success () {
  info "Terraform validate completed with no errors. Continuing."
}

validate_fail () {
  local pr_comment=$(make_details_with_header "Terraform \`validate\` Failed" "$INPUT" "diff")
  make_and_post_payload "validate failure" "$pr_comment"
}