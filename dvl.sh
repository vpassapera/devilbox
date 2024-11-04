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
  PURPLE=$(tput setaf 5)
  CYAN=$(tput setaf 6)
  LIGHT_GRAY=$(tput setaf 7)
  DARK_GRAY=$(tput setaf 0)
  BOLD="$(tput bold)"
  NORMAL="$(tput sgr0)"
else
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  PURPLE=""
  CYAN=""
  LIGHT_GRAY=""
  DARK_GRAY=""
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
  printf "%s %s\n" "${CYAN}[?]" "${NORMAL}$message"
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

function get_yq_version() {
  printf %s "$( \
    curl -sS 'https://github.com/mikefarah/yq/releases' \
    | grep -Eo '/mikefarah/yq/releases/tag/v?[.0-9]+"' \
    | grep -Eo 'v?[.0-9]+' \
    | sort -V \
    | tail -1 \
  )"
}

function download_yq() {
  local uname
  local aarch
  local DEB_HOST_ARCH

  uname="$(uname)"
  aarch="$(uname -m)"

  if [ "${uname}" = "Linux" ]; then
    if ! command -v dpkg-architecture 2>&1 >/dev/null; then
      DEB_HOST_ARCH="$aarch"
    else
      DEB_HOST_ARCH="$( dpkg-architecture --query DEB_HOST_ARCH )"
    fi
  elif [ "${uname}" = "Darwin" ]; then
    DEB_HOST_ARCH="$aarch"
  fi

  if [ "${aarch}" = "i386" ] || [ "$aarch" = "x86_64" ]; then
    DEB_HOST_ARCH="amd64"
  fi

  if [ "${DEB_HOST_ARCH}" = "amd64" ] || [ "${DEB_HOST_ARCH}" = "arm64" ]; then
    YQ_UNAME=$(echo "$uname" | tr '[:upper:]' '[:lower:]')
    if [[ ! -d "$DEVILBOX_PATH/.tests/binaries/" ]]; then
      mkdir -p "$DEVILBOX_PATH/.tests/binaries/"
    fi
    YQ_URL="https://github.com/mikefarah/yq/releases/download/$(get_yq_version)/yq_${YQ_UNAME}_${DEB_HOST_ARCH}" \
    && curl -sS -L --fail "${YQ_URL}" > "$DEVILBOX_PATH/.tests/binaries/yq"
  fi

  chmod +x "$DEVILBOX_PATH/.tests/binaries/yq";
}

# Checker
if [[ -z "$DEVILBOX_PATH" ]]; then
  error "Devilbox not found, please make sure it is installed in your home directory or use DEVILBOX_PATH in your profile."
fi
#safe_cd "$(get_workspace_path)" "Devilbox not found, please make sure it is installed in your home directory or use DEVILBOX_PATH in your profile."

DVLBOX_PATH="$( cd "${DEVILBOX_PATH}" && pwd -P )"
SCRIPT_PATH="$( cd "${DVLBOX_PATH}/.tests/scripts" && pwd -P )"
# shellcheck disable=SC1090
source "${SCRIPT_PATH}/.lib.sh"

# Check and download yq binary
if [[ ! -f "$DEVILBOX_PATH/.tests/binaries/yq" ]]; then
  download_yq
fi

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
WEBAPP_DIR="$(get_workspace_path)/data/www"
HTTPD_WORKDIR="/shared/httpd"
WEBAPP_STACK=""
MAGE_MODE=""
MAGE_INFRA=""
WEB_MULTI="N"
APPNAME="$$$"
PARENT_APPNAME="$$$"
APPREPOSITORY=""
DBNAME="$$$"
APPDOMAINS=""
APPDOMAINS_CRT=""
PUBLICPATH="current"
PHP_VERSION=""
PROXY_PORT="3000"
CURRENT_DIR="$(pwd)"
PROJECT_DIR="${CURRENT_DIR/$WEBAPP_DIR\///}"
TARGET_WORKDIR="$HTTPD_WORKDIR$PROJECT_DIR"
CONFIG_FILE=".devilbox.yaml"
YQ_BINARY="$DEVILBOX_PATH/.tests/binaries/yq"

# Read-only variables
readonly VERSION="1.1.0"

function main {
  if [[ $# -eq 0 ]] ; then
      Usage --ansi
      echo "${BOLD}"
      $YQ_BINARY --version
      echo "${NORMAL}"
  else
    case "$1" in
      up|start)
        shift;
        StartServices "$@"
      ;;
      down|stop)
        shift;
        StopServices "$@"
      ;;
      restart)
        shift;
        RestartServices "$@"
      ;;
      reset)
        ResetServices "$@"
      ;;
      init)
        shift;
        InitializeProject "$@"
      ;;
      exec)
        shift;
        ExecShell "$@"
      ;;
      magento)
        shift;
        MagentoCommand "$@"
      ;;
      magerun)
        shift;
        MagerunCommand "$@"
      ;;
      composer)
        shift;
        ComposerCommand "$@"
      ;;
      shell)
        shift;
        OpenShell "$@"
      ;;
      sync-httpd)
        shift;
        SyncHttpdConf "$@"
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
    printf %s "bind httpd php php74 php81 php82 php83 mysql redis elastic mailhog"
  fi
}

function BaseCommand {
  (cd "$DEVILBOX_PATH"; docker "$@")
}

function BaseComposeCommand {
  if hash docker-compose 2>/dev/null; then
    (cd "$DEVILBOX_PATH"; docker-compose "$@")
  else
    (cd "$DEVILBOX_PATH"; docker compose "$@")
  fi
}

function StartServices {
  BaseComposeCommand up $(__get_default_containers) -d
}

function StopServices {
  BaseComposeCommand down && BaseComposeCommand rm -f
}

function RestartServices {
  if [[ -n "$*" ]]; then
    BaseCommand restart "$@"
  else
    StopServices && StartServices
  fi
}

function OpenShell {
  if [[ -z "$*" ]]; then
    BaseComposeCommand exec --user devilbox php bash -l
  else
    BaseComposeCommand exec --user devilbox "$1" bash -l
  fi
}

function ExecShell() {
  BaseComposeCommand exec --user devilbox php bash -c "$@"
}

function MagentoCommand() {
  BaseComposeCommand exec --workdir "$TARGET_WORKDIR" --user devilbox php bash -c "php -dmemory_limit=-1 bin/magento $*"
}

function MagerunCommand() {
  BaseComposeCommand exec --workdir "$TARGET_WORKDIR" --user devilbox php bash -c "php -dmemory_limit=-1 magerun $*"
}

function ComposerCommand() {
  BaseComposeCommand exec --workdir "$TARGET_WORKDIR" --user devilbox php bash -c "composer $*"
}

function InitializeProject() {
  # Define the app name
  while [[ $APPNAME =~ [^-.a-z0-9] ]] || [[ $APPNAME == '' ]]
  do
    read -r -p "${CYAN}Please enter your webapp name (lowercase, alphanumeric):${NORMAL} " APPNAME
  done
  APPDOMAINS="https://$APPNAME.$TLD_SUFFIX"
  echo -ne "${YELLOW}Your webapp name set to: $APPNAME"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  echo -ne "${YELLOW}Domain of webapp set to: $APPDOMAINS"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  # Choose a web application stack
  read -r -p "${CYAN}Please choose web application stack (magento, nodejs, laravel, shopify, bigcommerce, phpweb)? [magento]${NORMAL} " response
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
  read -r -p "${CYAN}Is this webapp a sub-domain of another web application (Y/N)? [N]${NORMAL} " response
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
    while [[ $PARENT_APPNAME =~ [^-.a-z0-9] ]] || [[ $PARENT_APPNAME == '' ]]
    do
      read -r -p "${CYAN}What is the main-entry webapp name?${NORMAL} " PARENT_APPNAME
    done
    echo -ne "${YELLOW}Your parent webapp name set to: $PARENT_APPNAME"
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi

  if [[ "$WEBAPP_STACK" == "magento" ]]; then
    # Set Magento Mode
    read -r -p "${CYAN}Which deploy mode you would like to setup (developer, production)? [production]${NORMAL} " response
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

    # Set Infra Mode
    read -r -p "${CYAN}What is the infrastructure of your Magento project (aws, cloud)? [cloud]${NORMAL} " response
    case "$response" in
      aws)
        MAGE_INFRA="aws"
        echo -ne "${YELLOW}Your infrastructure type has been set to ${MAGE_INFRA}"
        echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
        echo ""
        ;;
      cloud|*)
        MAGE_INFRA="cloud"
        echo -ne "${YELLOW}Your infrastructure type has been set to ${MAGE_INFRA}"
        echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
        echo ""
        ;;
    esac
  fi

  if [[ "$WEB_MULTI" == "N" ]]; then
    # Define the app repository
    while [[ $APPREPOSITORY == '' ]]
    do
      read -r -p "${CYAN}Please enter your webapp repository (git@github.com:org/repo.git):${NORMAL} " APPREPOSITORY
    done
    echo -ne "${YELLOW}Your webapp repository set to: $APPREPOSITORY"
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi

  # Choose PHP version
  read -r -p "${CYAN}Please choose PHP version of your webapp? [8.1]${NORMAL} " response
  case "$response" in
    5.2|52|5.3|53|5.4|54|5.5|55|5.6|56)
      PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
      ;;
    7.0|70|7.1|71|7.2|72|7.3|73|7.4|74)
      PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
      ;;
    8.0|80|8.2|82|8.3|83)
      PHP_VERSION=$(awk '{gsub(/[.]/,"");print $NF}' <<< "php$response")
      ;;
    8.1|81|*)
      PHP_VERSION="php81"
      ;;
  esac

  echo -ne "${YELLOW}PHP version of webapp set to $PHP_VERSION"
  echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
  echo ""

  if [[ "$WEBAPP_STACK" != "magento" ]] && [[ "$WEBAPP_STACK" != "phpweb" ]] && [[ "$WEBAPP_STACK" != "laravel" ]]; then
    # Define port proxy
    read -r -p "${CYAN}Please choose port proxy of your webapp? [3000]${NORMAL} " response
    PROXY_PORT=$response

    echo -ne "${YELLOW}Proxy port of webapp set to $PROXY_PORT"
    echo -ne "...${NORMAL} ${GREEN}DONE${NORMAL}"
    echo ""
  fi

  BootstrapWebApplication "$WEBAPP_STACK"
}

function GenerateYamlConf() {
  local php_version
  local proxy_port
  local current_stack
  local infra_type
  local repo_url
  local is_subdomain
  local app_name

  local filePath="$WEBAPP_DIR/$APPNAME/$CONFIG_FILE"
}

function BootstrapWebApplication() {
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

  if [[ "$WEB_MULTI" == "N" ]] && [[ "$MAGE_INFRA" == "aws" ]]; then
    git clone --quiet "$APPREPOSITORY" "$WEBAPP_DIR/$APPNAME" > /dev/null
  fi

  mkdir -p "$WEBAPP_DIR/$APPNAME"
  mkdir -p "$devilboxConfDir"

  # General Configuration
  if [[ -f "$DEVILBOX_PATH/cfg/vhost-gen/backend.cfg-example-php-multi" ]] && [[ $currentStack != "nodejs" ]] && [[ $currentStack != "bigcommerce" ]] && [[ $currentStack != "shopify" ]]; then
    cat "$DEVILBOX_PATH/cfg/vhost-gen/backend.cfg-example-php-multi" | sed "s/PHP_VERSION/$PHP_VERSION/g" > "$devilboxConfDir/backend.cfg"
  fi

  if [[ -f "$DEVILBOX_PATH/cfg/vhost-gen/backend.cfg-example-rproxy-multi" ]] && [[ $currentStack != "magento" ]] && [[ $currentStack != "laravel" ]] && [[ $currentStack != "phpweb" ]]; then
    cat "$DEVILBOX_PATH/cfg/vhost-gen/backend.cfg-example-rproxy-multi" | sed "s/PHP_VERSION/$PHP_VERSION/g" | sed "s/PROXY_PORT/$PROXY_PORT/g" > "$devilboxConfDir/backend.cfg"
  fi

  if [[ "$WEB_MULTI" == "N" ]]; then
    if [[ "$MAGE_INFRA" == "cloud" ]] || [[ "$MAGE_INFRA" == "" ]]; then
      git clone --quiet "$APPREPOSITORY" "$WEBAPP_DIR/$APPNAME/$HTTPD_DOCROOT_DIR" > /dev/null
    fi
  elif [[ "$WEB_MULTI" == "Y" ]]; then
    (cd "$WEBAPP_DIR" || exit; ln -snf "../$PARENT_APPNAME/$HTTPD_DOCROOT_DIR" "$WEBAPP_DIR/$APPNAME/$HTTPD_DOCROOT_DIR" > /dev/null)
  fi

  case "$currentStack" in
    magento)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-magento2" "$devilboxConfDir/nginx.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-magento2" "$devilboxConfDir/apache22.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-magento2" "$devilboxConfDir/apache24.yml"
      fi
      ;;
    nodejs)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-rproxy" "$devilboxConfDir/nginx.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-rproxy" "$devilboxConfDir/apache22.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-rproxy" "$devilboxConfDir/apache24.yml"
      fi
      ;;
    shopify)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-rproxy" "$devilboxConfDir/nginx.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-rproxy" "$devilboxConfDir/apache22.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-rproxy" "$devilboxConfDir/apache24.yml"
      fi
      ;;
    bigcommerce)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-rproxy" "$devilboxConfDir/nginx.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-rproxy" "$devilboxConfDir/apache22.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-rproxy" "$devilboxConfDir/apache24.yml"
      fi
      ;;
    laravel)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-laravel" "$devilboxConfDir/nginx.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-laravel" "$devilboxConfDir/apache22.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-laravel" "$devilboxConfDir/apache24.yml"
      fi
      ;;
    phpweb|*)
      if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-vhost" "$devilboxConfDir/nginx.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-vhost" "$devilboxConfDir/apache22.yml"
      elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
        cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-vhost" "$devilboxConfDir/apache24.yml"
      fi
      ;;
  esac

  echo -ne "...${NORMAL} ${GREEN}DONE ✔${NORMAL}"
  echo ""
}

function SyncHttpdConf() {
  echo -ne "${YELLOW}Please wait, we are syncing your Httpd configuration"

  for appName in "$WEBAPP_DIR"/*; do
    if [[ "$HTTPD_SERVER" =~ "nginx" ]]; then
      \cp "$DEVILBOX_PATH/cfg/vhost-gen/nginx.yml-example-magento2" "$appName/$HTTPD_TEMPLATE_DIR/nginx.yml"
    elif [[ "$HTTPD_SERVER" = "apache-2.2" ]]; then
      \cp "$DEVILBOX_PATH/cfg/vhost-gen/apache22.yml-example-magento2" "$appName/$HTTPD_TEMPLATE_DIR/apache22.yml"
    elif [[ "$HTTPD_SERVER" = "apache-2.4" ]]; then
      \cp "$DEVILBOX_PATH/cfg/vhost-gen/apache24.yml-example-magento2" "$appName/$HTTPD_TEMPLATE_DIR/apache24.yml"
    fi
  done

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
      echo "${GREEN}" "magento${NORMAL}          Run Magento command from the current project directory"
      echo "${GREEN}" "magerun${NORMAL}          Run Magerun2 command from the current project directory"
      echo "${GREEN}" "composer${NORMAL}         Run Composer command from the current project directory"
      echo "${GREEN}" "sync-httpd${NORMAL}       Sync Httpd configuration to all current webapps"
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
      echo " magento${NORMAL}          Run Magento command from the current project directory"
      echo " magerun${NORMAL}          Run Magerun2 command from the current project directory"
      echo " composer${NORMAL}         Run Composer command from the current project directory"
      echo " sync-httpd${NORMAL}       Sync Httpd configuration to all current webapps"
    ;;
  esac
}

main "$@"
