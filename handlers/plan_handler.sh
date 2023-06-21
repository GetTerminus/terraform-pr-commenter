execute_plan () {
  # shellcheck disable=SC2016
  delete_existing_comments 'plan' '### Terraform `plan` .* for Workspace: `'"$WORKSPACE"'`.*'
  delete_existing_comments 'outputs' '### Changes to outputs for Workspace: `'"$WORKSPACE"'`.*'

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

plan_success () {
  post_plan_comments
  if [[ $POST_PLAN_OUTPUTS == 'true' ]]; then
    post_outputs_comments
  fi
}

plan_fail () {
  local clean_input
  local comment
  local delimiter_strings=()

  delimiter_strings+="Planning failed. Terraform encountered an error while generating this plan."
  delimiter_strings+="Terraform planned the following actions, but then encountered a problem:"

  debug "Test Delimiter"


  local delimiter=$(delimiter_builder "${delimiter_strings[@]}")

  clean_input=$(echo "$INPUT" | perl -pe$delimiter)
  comment=$(make_details_with_header "Terraform \`plan\` Failed for Workspace: \`$WORKSPACE\`" "$clean_input" "diff")

  # Add comment to PR.
  #make_and_post_payload "plan failure" "$comment"
  post_diff_comments "plan" "Terraform \`plan\` Failed for Workspace: \`$WORKSPACE\`" "$clean_input"
}

post_plan_comments () {
  local clean_input

  clean_input=$(echo "$INPUT" | perl -pe'$_="" unless /(An execution plan has been generated and is shown below.|Terraform used the selected providers to generate the following execution|No changes. Infrastructure is up-to-date.|No changes. Your infrastructure matches the configuration.)/ .. 1') # Strip refresh section
  clean_input=$(echo "$clean_input" | sed -r '/Plan: /q') # Ignore everything after plan summary

  post_diff_comments "plan" "Terraform \`plan\` Succeeded for Workspace: \`$WORKSPACE\`" "$clean_input"
}

post_outputs_comments() {
  local clean_input

  clean_input=$(echo "$INPUT" | perl -pe'$_="" unless /Changes to Outputs:/ .. 1') # Skip to end of plan summary
  clean_input=$(echo "$clean_input" | sed -r '/------------------------------------------------------------------------/q') # Ignore everything after plan summary

  post_diff_comments "outputs" "Changes to outputs for Workspace: \`$WORKSPACE\`" "$clean_input"
}