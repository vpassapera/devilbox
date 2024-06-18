#!/usr/bin/env bash

# NOTE: Parsing curl to tac to circumnvent "failed writing body"
# https://stackoverflow.com/questions/16703647/why-curl-return-and-error-23-failed-writing-body

set -e
set -u
set -o pipefail

SCRIPT_PATH="$( cd "$(dirname "$0")" && pwd -P )"
DVLBOX_PATH="$( cd "${SCRIPT_PATH}/../.." && pwd -P )"
# shellcheck disable=SC1090
. "${SCRIPT_PATH}/../scripts/.lib.sh"

RETRIES=10


echo
echo "# --------------------------------------------------------------------------------------------------"
echo "# [modules] fetch external tests"
echo "# --------------------------------------------------------------------------------------------------"
echo

# -------------------------------------------------------------------------------------------------
# Pre-check
# -------------------------------------------------------------------------------------------------

PHP_OLD_GIT_VERSIONS=("5.6" "7.0" "7.1" "7.2")
PHP_VERSION="$( get_php_version "${DVLBOX_PATH}" )"

if [ "${#}" -ne "1" ]; then
	>&2 echo "Error, requires one argument: <TEST_DIR>"
	exit 1
fi


# -------------------------------------------------------------------------------------------------
# Download Test directory from PHP-FPM via SVN
# -------------------------------------------------------------------------------------------------

VHOST="${1}"

# SVN allows to download a specific directory from GitHub so it is used instead of git cmd.
# The following ensures to download the module test directory

# Where to download from
TEST_REPO="https://github.com/devilbox-community/docker-php-fpm"
TEST_PATH="tests/mods/modules"

# Get current PHP_FPM git tag or branch
PHP_FPM_GIT_SLUG="$( \
	grep -E '^[[:space:]]+image:[[:space:]]+devilboxcommunity/php-fpm:' "${DVLBOX_PATH}/docker-compose.yml" \
	| perl -p -e 's/.*(base|mods|prod|work|-)//g'
)"

if [ -z "${PHP_FPM_GIT_SLUG}" ]; then
	PHP_FPM_GIT_SLUG="$( run "git ls-remote --symref ${TEST_REPO} | head -1 | cut -f1 | sed 's!^ref: refs/heads/!!'" "${RETRIES}" )";
fi
#https://github.blog/2023-01-20-sunsetting-subversion-support/
CLONE_PATH="/shared/httpd/${VHOST}/htdocs"
GIT_CLONE_CMD="git clone --depth=1 --single-branch --branch=${PHP_FPM_GIT_SLUG} ${TEST_REPO} ${CLONE_PATH} && cd ${CLONE_PATH} && git sparse-checkout set --no-cone ${TEST_PATH}"
if [[ ${PHP_OLD_GIT_VERSIONS[*]} =~ ${PHP_VERSION} ]]; then
	GIT_CLONE_CMD="git clone --depth=1 --single-branch --branch=${PHP_FPM_GIT_SLUG} ${TEST_REPO} ${CLONE_PATH}/tmp && cp -r ${CLONE_PATH}/tmp/${TEST_PATH} ${CLONE_PATH} && rm -rf ${CLONE_PATH}/tmp"
fi

# Cleanup and fetch data
run "docker compose exec -T --user devilbox php rm -rf /shared/httpd/${VHOST} || true" "${RETRIES}" "${DVLBOX_PATH}"
run "docker compose exec -T --user devilbox php mkdir -p /shared/httpd/${VHOST}" "${RETRIES}" "${DVLBOX_PATH}"
run "docker compose exec -T --user devilbox php bash -c \"${GIT_CLONE_CMD}\"" "${RETRIES}" "${DVLBOX_PATH}"
