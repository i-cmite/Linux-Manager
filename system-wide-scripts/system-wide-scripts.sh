#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Check if user is root
if [ $(id -u) != "0" ]; then
  echo "Error: You must be root to run this script"
  exit 1
fi

INFO="\e[0;32m[INFO]\e[0m"
ERROR="\e[0;31m[ERROR]\e[0m"

determine_path() {
  Startup_Current_PATH="$(dirname $0)"

  if [[ "$Startup_Current_PATH" != /* ]]; then
    echo -e "${ERROR} ${Startup_Current_PATH} 不是绝对路径，尝试获取绝对路径"
    Startup_Current_PATH="$(pwd)/$(dirname $0)"
  fi

  if [[ "$Startup_Current_PATH" == /* ]] && [[ -n "$Startup_Current_PATH" ]]; then
    echo -e "${INFO} ${Startup_Current_PATH}"
  else
    echo -e "${ERROR} 获取绝对路径失败"
    exit 1
  fi
}

print_version() {
  echo "+------------------------------------------------------------------------+"
  echo "|         LM-SWS for Ubuntu Linux Server, Written by Echocolate          |"
  echo "+------------------------------------------------------------------------+"
  echo "|       Scripts to install automatically sourced scripts on Linux        |"
  echo "+------------------------------------------------------------------------+"
  echo "|                Version: 1.0.0  Last Updated: 2026-03-10                |"
  echo "+------------------------------------------------------------------------+"
  echo "|                      https://repos.echocolate.xyz                      |"
  echo "+------------------------------------------------------------------------+"
}

backup() {
  cd /etc/profile.d/
  find "." -maxdepth 1 -type f -name 'lm-*' -print0 -exec cp {} ${HOME}/lm-backup/profile.d/{}$(date "+%F_%N") \;
  echo ""
  cd -
}

copy() {
  cp -a "${Startup_Current_PATH}"/profile.d/*sh /etc/profile.d/
}

config() {
  chmod 644 /etc/profile.d/lm-*.sh
  chown root:root /etc/profile.d/lm-*.sh
  find "/etc/profile.d/" -maxdepth 1 -type f -name 'lm-*' -print
}

install() {
  clear
  print_version
  determine_path
  backup
  copy
  config
}

[ ! -d "${HOME}/lm-backup/profile.d" ] && mkdir -p ${HOME}/lm-backup/profile.d
[ ! -d "${HOME}/logs" ] && mkdir ${HOME}/logs
install 2>&1 | tee "${HOME}/logs/LM-$(date '+%F').log"
