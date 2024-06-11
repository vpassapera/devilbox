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

## Basic wrappers around exit codes

OK_CODE=0
KO_CODE=1

was_success() {
  local exit_code=$?
  [ "$exit_code" -eq "$OK_CODE" ]
}

was_error() {
  local exit_code=$?
  [ "$exit_code" -eq "$KO_CODE" ]
}

die() {
  local exit_code=$1
  if [ -n "$exit_code" ]; then
    exit "$exit_code"
  else
    exit "$?"
  fi
}

error() {
  local message=$1
  printf "%s %s\n" "${RED}[✘]" "${NORMAL}$message" >&2
  die "$KO_CODE"
}

success() {
  local message=$1
  printf "%s %s\n" "${GREEN}[✔]" "${NORMAL}$message"
}

info() {
  local message=$1
  printf "%s %s\n" "${YELLOW}[!]" "${NORMAL}$message"
}

question() {
  local message=$1
  printf "%s %s\n" "${BLUE}[?]" "${NORMAL}$message"
}

safe_cd() {
  local path=$1
  local error_msg=$2
  if [[ ! -d "$path" ]]; then
    error "$error_msg"
  fi
  cd "$path" >/dev/null || error "$error_msg"
}

function get_workspace_path() {
  if [[ ! -z "$DEVILBOX_PATH" ]]; then
    printf %s "${DEVILBOX_PATH}"
  else
    printf %s "$HOME/.devilbox"
  fi
}

# Checker
#if [[ ! -n "$DEVILBOX_PATH" ]]; then
#  error "Devilbox not found, please make sure it is installed in your home directory or use DEVILBOX_PATH in your profile."
#fi
safe_cd "$(get_workspace_path)" "Devilbox not found, please make sure it is installed in your home directory or use DEVILBOX_PATH in your profile."

DVLBOX_PATH="$( cd "${DEVILBOX_PATH}" && pwd -P )"
SCRIPT_PATH="$( cd "${DVLBOX_PATH}/.tests/scripts" && pwd -P )"
# shellcheck disable=SC1090
source "${SCRIPT_PATH}/.lib.sh"

# -------------------------------------------------------------------------------------------------
# ENTRYPOINT
# -------------------------------------------------------------------------------------------------

###
### Get required env values
###
HTTPD_SERVER="$( "${SCRIPT_PATH}/env-getvar.sh" "HTTPD_SERVER" )"
HTTPD_TEMPLATE_DIR="$( "${SCRIPT_PATH}/env-getvar.sh" "HTTPD_TEMPLATE_DIR" )"
HTTPD_DOCROOT_DIR="$( "${SCRIPT_PATH}/env-getvar.sh" "HTTPD_DOCROOT_DIR" )"
TLD_SUFFIX="$( "${SCRIPT_PATH}/env-getvar.sh" "TLD_SUFFIX" )"
WEBAPP_STACK=""
MAGE_MODE=""
WEB_MULTI="N"
APPNAME="$$$"
PARENT_APPNAME="$$$"
APPREPOSITORY=""
DBNAME="$$$"
APPDOMAINS=""
APPDOMAINS_CRT=""
PUBLICPATH="current"
PHP_VERSION=""
WEBAPP_DIR="$(get_workspace_path)/data/www"

# Read-only variables
readonly VERSION="1.0.0"

function main {
  if [[ $# -eq 0 ]] ; then
      Usage --ansi
  else
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
      init)
        InitializeProject "$@"
      ;;
      exec)
        shift;
        ExecShell "$@"
      ;;
      shell)
        OpenShell "$@"
      ;;
      --no-ansi)
        Usage --no-ansi
      ;;
      help|-h|--help|--ansi)
        Usage --ansi
      ;;
      *)
        error "Unknown command $1, see -h for help."
      ;;
    esac
  fi
}

function __get_default_containers() {
  if [[ ! -z "$DEVILBOX_CONTAINERS" ]]; then
    printf %s "${DEVILBOX_CONTAINERS}"
  else
    printf %s "bind httpd php php74 php81 php82 mysql redis elastic"
  fi
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
  BaseComposeCommand up $(__get_default_containers) -d
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

function ExecShell() {
  BaseComposeCommand exec --user devilbox php bash -c "$@"
}

function InitializeProject() {
  # Define the app name
  while [[ $APPNAME =~ [^-a-z0-9] ]] || [[ $APPNAME == '' ]]
  do
    read -r -p "${BLUE}Please enter your webapp name (lowercase, alphanumeric):${NORMAL} " APPNAME
  done
  APPDOMAINS="https://$APPNAME.$TLD_SUFFIX"
  echo -ne "${YELLOW}Your webapp name set to: $APPNAME"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  echo -ne "${YELLOW}Domain of webapp set to: $APPDOMAINS"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  # Choose a web application stack
  read -r -p "${BLUE}Please choose web application stack (magento, nodejs, laravel, shopify, bigcommerce, phpweb)? [magento]${NORMAL} " response
  case "$response" in
    nodejs)
      WEBAPP_STACK="nodejs"
      echo -ne "${YELLOW}Node.js General Application"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    laravel)
      WEBAPP_STACK="laravel"
      echo -ne "${YELLOW}Laravel"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    shopify)
      WEBAPP_STACK="shopify"
      echo -ne "${YELLOW}Shopify"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    bigcommerce)
      WEBAPP_STACK="bigcommerce"
      echo -ne "${YELLOW}BigCommerce"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    phpweb)
      WEBAPP_STACK="phpweb"
      echo -ne "${YELLOW}General PHP Application"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    magento|*)
      WEBAPP_STACK="magento"
      echo -ne "${YELLOW}Magento 2 (Pre-configured for production-grade Magento 2 application)"
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
  esac

  # Setup subdomain configuration
  read -r -p "${BLUE}Is this webapp a sub-domain of another web application? [Y/N]${NORMAL} " response
  case "$response" in
    [yY][eE][sS]|[yY])
      WEB_MULTI="Y"
      echo -ne "${YELLOW}Your current webapp is configured to be a sub-domain of another web application."
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
    [nN][oO]|[nN]|*)
      WEB_MULTI="N"
      echo -ne "${YELLOW}Your current webapp is not configured to be a sub-domain of another web application."
      echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
      echo ""
      ;;
  esac
  if [[ "$WEB_MULTI" == "Y" ]]; then
    while [[ $PARENT_APPNAME =~ [^-a-z0-9] ]] || [[ $PARENT_APPNAME == '' ]]
    do
      read -r -p "${BLUE}What is the main-entry Magento webapp name?${NORMAL} " PARENT_APPNAME
    done
    echo -ne "${YELLOW}Your parent webapp name set to: $PARENT_APPNAME"
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi

  if [[ "$WEBAPP_STACK" == "magento" ]]; then
    # Set Magento Mode
    read -r -p "${BLUE}Which deploy mode you would like to setup (developer, production)? [production]${NORMAL} " response
    case "$response" in
      developer|dev)
        MAGE_MODE="developer"
        echo -ne "${YELLOW}Your Magento application mode has been set to ${MAGE_MODE}"
        echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
        echo ""
        ;;
      production|prod|*)
        MAGE_MODE="production"
        echo -ne "${YELLOW}Your Magento application mode has been set to ${MAGE_MODE}"
        echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
        echo ""
        ;;
    esac
  fi

  # Define the app repository
  while [[ $APPREPOSITORY == '' ]]
  do
    read -r -p "${BLUE}Please enter your webapp repository (git@github.com:org/repo.git):${NORMAL} " APPREPOSITORY
  done
  echo -ne "${YELLOW}Your webapp repository set to: $APPREPOSITORY"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  # Choose PHP version
  read -r -p "${BLUE}Please choose PHP version of your webapp? [7.4]${NORMAL} " response
  case "$response" in
    5.2|52|5.3|53|5.4|54|5.5|55|5.6|56)
      PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
      ;;
    7.0|70|7.1|71|7.2|72|7.3|73)
      PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
      ;;
    8.0|80|8.1|81|8.2|82|8.3|83)
      PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
      ;;
    7.4|74|*)
      PHP_VERSION="php74"
      ;;
  esac

  echo -ne "${YELLOW}PHP version of webapp set to $PHP_VERSION"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  BootstrapWebApplication "$WEBAPP_STACK"
}

function BootstrapWebApplication {
  # Start configuring everything
  echo -ne "${YELLOW}Please wait, we are configuring your web application"
  local devilboxConfDir="$WEBAPP_DIR/$APPNAME/$HTTPD_TEMPLATE_DIR"
  local currentStack="$1"

  # Creating dirs
  if [[ ! -d "$WEBAPP_DIR" ]]; then
    mkdir -p "$WEBAPP_DIR"
  fi

  if [[ -d "$WEBAPP_DIR/$APPNAME" ]]; then
    echo -ne "... The target appname already exists in $WEBAPP_DIR${NORMAL} ${RED}FAILURE[✘]${NORMAL}"
    echo ""
    exit 1;
  fi

  mkdir -p "$WEBAPP_DIR/$APPNAME"
  mkdir -p "$devilboxConfDir"

  # General Configuration
  if [[ -f "$DEVILBOX_PATH/cfg/vhost-gen/backend.cfg-example-php-multi" ]]; then
    cat "$DEVILBOX_PATH/cfg/vhost-gen/backend.cfg-example-php-multi" | sed "s/PHP_VERSION/$PHP_VERSION/g" > "$devilboxConfDir/backend.cfg"
  fi

  if [[ "$WEB_MULTI" == "N" ]]; then
    git clone --quiet "$APPREPOSITORY" "$WEBAPP_DIR/$APPNAME/$HTTPD_DOCROOT_DIR" > /dev/null
  else
    (cd "$WEBAPP_DIR" || exit; ln -snf "../$PARENT_APPNAME/$HTTPD_DOCROOT_DIR" "$WEBAPP_DIR/$APPNAME/$HTTPD_DOCROOT_DIR" > /dev/null)
  fi

  case "$currentStack" in
    magento)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-magento2" "$devilboxConfDir/nginx.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-magento2" "$devilboxConfDir/apache22.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-magento2" "$devilboxConfDir/apache24.yml" > /dev/null
      fi
      ;;
    nodejs)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-rproxy" "$devilboxConfDir/nginx.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-rproxy" "$devilboxConfDir/apache22.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-rproxy" "$devilboxConfDir/apache24.yml" > /dev/null
      fi
      ;;
    laravel)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-laravel" "$devilboxConfDir/nginx.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-laravel" "$devilboxConfDir/apache22.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-laravel" "$devilboxConfDir/apache24.yml" > /dev/null
      fi
      ;;
    shopify)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-rproxy" "$devilboxConfDir/nginx.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-rproxy" "$devilboxConfDir/apache22.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-rproxy" "$devilboxConfDir/apache24.yml" > /dev/null
      fi
      ;;
    bigcommerce)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-rproxy" "$devilboxConfDir/nginx.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-rproxy" "$devilboxConfDir/apache22.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-rproxy" "$devilboxConfDir/apache24.yml" > /dev/null
      fi
      ;;
    phpweb|*)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-vhost" "$devilboxConfDir/nginx.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-vhost" "$devilboxConfDir/apache22.yml" > /dev/null
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-vhost" "$devilboxConfDir/apache24.yml" > /dev/null
      fi
      ;;
  esac

  echo -ne "...${NORMAL} ${GREEN}DONE ✔${NORMAL}"
  echo ""
}

function Usage {
  case "$1" in
    --ansi)
      echo "${YELLOW}DevilBox v${VERSION}${NORMAL}"

      echo

      echo "${YELLOW}Usage:"
      echo "${NORMAL}" "dvl [commands] [options]"

      echo

      echo "${YELLOW}Options:${NORMAL}"
      echo "${GREEN}" "--version${NORMAL}(-v)    Display current version."
      echo "${GREEN}" "--help${NORMAL}(-h)       Display this help message."
      echo "${GREEN}" "--quiet${NORMAL}(-q)      Do not output any message."
      echo "${GREEN}" "--ansi${NORMAL}           Force ANSI output."
      echo "${GREEN}" "--no-ansi${NORMAL}        Disable ANSI output."

      echo

      echo "${YELLOW}Available commands:${NORMAL}"
      echo "${GREEN}" "up${NORMAL}(start)        Start designated devilbox services."
      echo "${GREEN}" "down${NORMAL}(stop)       Stop all Devilbox services."
      echo "${GREEN}" "restart${NORMAL}          Restart Devilbox service(s). Leave empty to restart all."
      echo "${GREEN}" "reset${NORMAL}            Shutdown and reset everyhing (USE with CAUTION)."
      echo "${GREEN}" "init${NORMAL}             Initialize a new project using DevilBox."
      echo "${GREEN}" "shell${NORMAL}            Open shell (php version as args)"
      echo "${GREEN}" "exec${NORMAL}             Exec a command directly from shell (command executed on main PHP container)"
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
      echo " init${NORMAL}             Initialize a new project using DevilBox."
      echo " shell${NORMAL}            Open shell (php version as args)"
      echo " exec${NORMAL}             Exec a command directly from shell (command executed on main PHP container)"
    ;;
  esac
}

main "$@"
