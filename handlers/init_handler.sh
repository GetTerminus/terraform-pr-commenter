execute_init () {
  delete_existing_comments "init" '### Terraform `init` Failed'

  # Exit Code: 0
  # Meaning: Terraform successfully initialized.
  # Actions: Exit.
  if [[ $EXIT_CODE -eq 0 ]]; then
    init_success
  fi

  # Exit Code: 1
  # Meaning: Terraform initialize failed or malformed Terraform CLI command.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 ]]; then
    init_fail
  fi
}

init_success () {
  info "Terraform init completed with no errors. Continuing."
}

init_fail () {
  local pr_comment=$(make_details_with_header "Terraform \`init\` Failed" "$INPUT")

  make_and_post_payload "init failure" "$pr_comment"
}