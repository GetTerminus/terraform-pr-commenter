#!/usr/bin/env bash
# shellcheck source=handler/
for HF in handlers/*; do source "$HF"; done
# shellcheck source=utilities/
for UF in utilities/*; do source "$UF"; done

if [ -n "${COMMENTER_ECHO+x}" ]; then
  set -x
fi

###################
# Procedural body #
###################
validate_inputs "$@"
parse_args "$@"

if [[ $COMMAND == 'fmt' ]]; then
  execute_fmt
  exit 0
fi

if [[ $COMMAND == 'init' ]]; then
  execute_init
  exit 0
fi

if [[ $COMMAND == 'plan' ]]; then
  execute_plan
  exit 0
fi

if [[ $COMMAND == 'validate' ]]; then
  execute_validate
  exit 0
fi

if [[ $COMMAND == 'tflint' ]]; then
  execute_tflint
  exit 0
fi
