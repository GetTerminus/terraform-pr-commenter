debug () {
  if [ -n "${COMMENTER_DEBUG+x}" ]; then
    echo -e "\033[33;1mDEBUG:\033[0m $1"
  fi
}

info () {
  echo -e "\033[34;1mINFO:\033[0m $1"
}

error () {
  echo -e "\033[31;1mERROR:\033[0m $1"
}