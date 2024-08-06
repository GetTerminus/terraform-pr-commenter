execute_init () {
  delete_existing_comments "init" '### OpenTofu `init` Failed'

  # Exit Code: 0
  # Meaning: OpenTofu successfully initialized.
  # Actions: Exit.
  if [[ $EXIT_CODE -eq 0 ]]; then
    init_success
  fi

  # Exit Code: 1
  # Meaning: OpenTofu initialize failed or malformed OpenTofu CLI command.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 ]]; then
    init_fail
  fi
}

init_success () {
  info "OpenTofu init completed with no errors. Continuing."
}

init_fail () {
  local pr_comment=$(make_details_with_header "OpenTofu \`init\` Failed" "$INPUT")

  make_and_post_payload "init failure" "$pr_comment"
}