execute_plan() {
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

plan_success() {
  post_plan_comments
  if [[ $POST_PLAN_OUTPUTS == 'true' ]]; then
    post_outputs_comments
  fi
}

plan_fail() {
  local clean_input
  local delimiter_start_cmd
  local delimiter_start_strings=()

  delimiter_start_strings+=("Planning failed. Terraform encountered an error while generating this plan.")
  delimiter_start_strings+=("Terraform planned the following actions, but then encountered a problem:")

  delimiter_start_cmd=$(delimiter_start_cmd_builder "${delimiter_start_strings[@]}")

  debug "delimiter_start_cmd: $delimiter_start_cmd"

  clean_input=$(echo "$INPUT" | perl -pe "${delimiter_start_cmd}")

  post_diff_comments "plan" "Terraform \`plan\` Failed for Workspace: \`$WORKSPACE\` ❌" "$clean_input"
}

post_plan_comments() {
  local clean_input
  local delimiter_start_strings=()
  local delimiter_start_cmd
  local delimiter_end_cmd

  delimiter_start_strings+=("An execution plan has been generated and is shown below.")
  delimiter_start_strings+=("Terraform used the selected providers to generate the following execution")
  delimiter_start_strings+=("No changes. Infrastructure is up-to-date.")
  delimiter_start_strings+=("No changes. Your infrastructure matches the configuration.")

  delimiter_start_cmd=$(delimiter_start_cmd_builder "${delimiter_start_strings[@]}")
  delimiter_end_cmd=$(delimiter_end_cmd_builder "Plan: ")

  debug "delimiter_start_cmd: $delimiter_start_cmd"
  debug "delimiter_end_cmd: $delimiter_end_cmd"

  clean_input=$(echo "$INPUT" | perl -pe "${delimiter_start_cmd}")
  clean_input=$(echo "$clean_input" | sed -r "${delimiter_end_cmd}")

  post_diff_comments "plan" "Terraform \`plan\` Succeeded for Workspace: \`$WORKSPACE\` ✅" "$clean_input"
}

post_outputs_comments() {
  local clean_input
  local delimiter_start_strings=()
  local delimiter_start_cmd
  local delimiter_end_cmd

  delimiter_start_strings+=("Changes to Outputs:")

  delimiter_start_cmd=$(delimiter_start_cmd_builder "${delimiter_start_strings[@]}")
  delimiter_end_cmd=$(delimiter_end_cmd_builder "------------------------------------------------------------------------")

  debug "delimiter_start_cmd: $delimiter_start_cmd"
  debug "delimiter_end_cmd: $delimiter_end_cmd"

  clean_input=$(echo "$INPUT" | perl -pe "${delimiter_start_cmd}")
  clean_input=$(echo "$clean_input" | sed -r "${delimiter_end_cmd}")

  post_diff_comments "outputs" "Changes to outputs for Workspace: \`$WORKSPACE\` ⚠️" "$clean_input"
}
