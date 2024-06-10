#!/usr/bin/env bash
# Use colors, but only if connected to a terminal, and that terminal
# supports them.
if which tput >/dev/null 2>&1; then
  ncolors=$(tput colors)
fi
if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  BOLD="$(tput bold)"
  NORMAL="$(tput sgr0)"
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  BOLD=""
  NORMAL=""
fi

# Read-only variables
readonly VERSION="1.0.0"

function main {
  case "$1" in
    up|start)
      StartServices "$@"
    ;;
    down|stop)
      StopServices "$@"
    ;;
    restart)
      RestartServices "$@"
    ;;
    reset)
      ResetServices "$@"
    ;;
    shell)
      OpenShell "$@"
    ;;
    --no-ansi)
      Usage --no-ansi
    ;;
    *|help|-h|--help|--ansi)
      Usage --ansi
    ;;
  esac
}

function BaseCommand {
  docker "$@"
}

function BaseComposeCommand {
  if hash docker-compose 2>/dev/null; then
    docker-compose "$@"
  else
    docker compose "$@"
  fi
}

function StartServices {
  BaseComposeCommand up bind httpd php php74 mysql redis elastic -d
}

function StopServices {
  BaseComposeCommand down
}

function RestartServices {
  if [ ! -n "$2" ]; then
    StopServices && StartServices
  else
    BaseCommand restart "$2"
  fi
}

function OpenShell {
  if [ ! -n "$2" ]; then
    BaseComposeCommand exec --user devilbox php bash -l
  else
    BaseComposeCommand exec --user devilbox "$2" bash -l
  fi
}

function Usage {
  case "$1" in
    --ansi)
      echo "${YELLOW}DevilBox v${VERSION}${NORMAL}"

      echo

      echo "${YELLOW}Usage:"
      echo ${NORMAL} "dvl [commands] [options]"

      echo

      echo "${YELLOW}Options:${NORMAL}"
      echo ${GREEN} "--version${NORMAL}(-v)    Display current version."
      echo ${GREEN} "--help${NORMAL}(-h)       Display this help message."
      echo ${GREEN} "--quiet${NORMAL}(-q)      Do not output any message."
      echo ${GREEN} "--ansi${NORMAL}           Force ANSI output."
      echo ${GREEN} "--no-ansi${NORMAL}        Disable ANSI output."

      echo

      echo "${YELLOW}Available commands:${NORMAL}"
      echo ${GREEN} "up${NORMAL}(start)        Start designated devilbox services."
      echo ${GREEN} "down${NORMAL}(stop)       Stop all Devilbox services."
      echo ${GREEN} "restart${NORMAL}          Restart Devilbox service(s). Leave empty to restart all."
      echo ${GREEN} "reset${NORMAL}            Shutdown and reset everyhing (USE with CAUTION)."
      echo ${GREEN} "shell${NORMAL}            Open shell (php version as args)"
    ;;
    --no-ansi)
      echo "DevilBox v${VERSION}"

      echo

      echo "Usage:"
      echo " dvl [commands] [options]"

      echo

      echo "Options:"
      echo " --version${NORMAL}(-v)    Display current version."
      echo " --help${NORMAL}(-h)       Display this help message."
      echo " --quiet${NORMAL}(-q)      Do not output any message."
      echo " --ansi${NORMAL}           Force ANSI output."
      echo " --no-ansi${NORMAL}        Disable ANSI output."

      echo

      echo "Available commands:"
      echo " up${NORMAL}(start)        Start designated devilbox services."
      echo " down${NORMAL}(stop)       Stop all Devilbox services."
      echo " restart${NORMAL}          Restart Devilbox service(s). Leave empty to restart all."
      echo " reset${NORMAL}            Shutdown and reset everyhing (USE with CAUTION)."
      echo " shell${NORMAL}            Open shell (php version as args)"
    ;;
  esac
}

main "$@"
