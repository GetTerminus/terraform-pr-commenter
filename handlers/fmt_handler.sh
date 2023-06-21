execute_fmt () {
  delete_existing_comments 'fmt' '### Terraform `fmt` Failed'

  # Exit Code: 0
  # Meaning: All files formatted correctly.
  # Actions: Exit.
  if [[ $EXIT_CODE -eq 0 ]]; then
    fmt_success
  fi

  # Exit Code: 1, 2
  # Meaning: 1 = Malformed Terraform CLI command. 2 = Terraform parse error.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 || $EXIT_CODE -eq 2 || $EXIT_CODE -eq 3 ]]; then
    fmt_fail
  fi
}

fmt_success () {
  info "Terraform fmt completed with no errors. Continuing."
}

fmt_fail () {
  local pr_comment

  # Exit Code: 1, 2
  # Meaning: 1 = Malformed Terraform CLI command. 2 = Terraform parse error.
  # Actions: Build PR comment.
  if [[ $EXIT_CODE -eq 1 || $EXIT_CODE -eq 2 ]]; then
    pr_comment=$(make_details_with_header "Terraform \`fmt\` Failed" "$INPUT")
  fi

  # Exit Code: 3
  # Meaning: One or more files are incorrectly formatted.
  # Actions: Iterate over all files and build diff-based PR comment.
  if [[ $EXIT_CODE -eq 3 ]]; then
    pr_comment=$(make_details_with_header "Terraform \`fmt\` Failed" "$INPUT" "diff")
  fi

  # Add fmt failure comment to PR.
  make_and_post_payload "fmt failure" "$pr_comment"
}