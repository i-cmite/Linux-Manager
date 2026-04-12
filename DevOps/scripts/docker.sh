#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Check if user is root
if [ $(id -u) != "0" ]; then
  echo "Error: You must be root to run this script"
  exit 1
fi

INFO="\e[0;32m[INFO]\e[0m"
ERROR="\e[0;31m[ERROR]\e[0m"

print_version() {
  clear
  echo "+------------------------------------------------------------------------+"
  echo "|        LM-docker for Ubuntu Linux Server, Written by Echocolate        |"
  echo "+------------------------------------------------------------------------+"
  echo "|               Scripts to install Docker Engine on Ubuntu               |"
  echo "+------------------------------------------------------------------------+"
  echo "|                Version: 1.1.1  Last Updated: 2026-04-12                |"
  echo "+------------------------------------------------------------------------+"
  echo "|                      https://repos.echocolate.xyz                      |"
  echo "+------------------------------------------------------------------------+"
  sleep 2
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    armv7l|armv6l)
      echo "arm32"
      ;;
    i386|i686)
      echo "386"
      ;;
    s390x)
      echo "s390x"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

get_distrib_info() {
  ARCH=$(detect_arch)
  RELEASE=$(cat /etc/lsb-release | grep "DISTRIB_RELEASE" | cut -d"=" -f 2)
  CODENAME=$(cat /etc/lsb-release | grep "DISTRIB_CODENAME" | cut -d"=" -f 2)
}

download_docker() {
  # 从环境变量获取安装的版本
  local containerd_io_version="${containerd_io_ver:-2.2.1-1}"
  local docker_ce_version="${docker_ce_ver:-29.1.4-1}"
  local docker_ce_cli_version="${docker_ce_cli_ver:-29.1.4-1}"
  local docker_buildx_plugin_version="${docker_buildx_plugin_ver:-0.30.1-1}"
  local docker_compose_plugin_version="${docker_compose_plugin_ver:-5.0.1-1}"

  # 打印版本信息
  header=$(printf "%-22s : %s\n" 'Package' 'Version')
  echo -e "\e[0;32m${header}\e[0m"
  printf "%-22s : %s\n" 'containerd.io' "$containerd_io_version"
  printf "%-22s : %s\n" 'docker-ce' "$docker_ce_version"
  printf "%-22s : %s\n" 'docker-ce-cli' "$docker_ce_cli_version"
  printf "%-22s : %s\n" 'docker-buildx-plugin' "$docker_buildx_plugin_version"
  printf "%-22s : %s\n" 'docker-compose-plugin' "$docker_compose_plugin_version"

  docker_base="https://download.docker.com/linux/ubuntu/dists/noble/pool/stable/${ARCH}"
  local status=0

  wget -nv ${docker_base}/containerd.io_${containerd_io_version}~ubuntu.${RELEASE}~${CODENAME}_${ARCH}.deb -O /tmp/containerd.io.deb
  status=$((status + $?))
  wget -nv ${docker_base}/docker-ce-cli_${docker_ce_cli_version}~ubuntu.${RELEASE}~${CODENAME}_${ARCH}.deb -O /tmp/docker-ce.deb
  status=$((status + $?))
  wget -nv ${docker_base}/docker-ce_${docker_ce_version}~ubuntu.${RELEASE}~${CODENAME}_${ARCH}.deb -O /tmp/docker-ce-cli.deb
  status=$((status + $?))
  wget -nv ${docker_base}/docker-buildx-plugin_${docker_buildx_plugin_version}~ubuntu.${RELEASE}~${CODENAME}_${ARCH}.deb -O /tmp/docker-buildx-plugin.deb
  status=$((status + $?))
  wget -nv ${docker_base}/docker-compose-plugin_${docker_compose_plugin_version}~ubuntu.${RELEASE}~${CODENAME}_${ARCH}.deb -O /tmp/docker-compose-plugin.deb
  status=$((status + $?))
  [ "$status" -ne 0 ] && {
    echo -e "${ERROR} Cannot download docker packages."
    exit 1
  }
}

install_docker() {
  dpkg -i /tmp/containerd.io.deb \
          /tmp/docker-ce.deb \
          /tmp/docker-ce-cli.deb \
          /tmp/docker-buildx-plugin.deb \
          /tmp/docker-compose-plugin.deb
}

clean() {
  rm -f /tmp/containerd.io.deb \
        /tmp/docker-ce.deb \
        /tmp/docker-ce-cli.deb \
        /tmp/docker-buildx-plugin.deb \
        /tmp/docker-compose-plugin.deb
}

create_docker_user() {
  # 创建无法登录的系统用户，专门启动不同的docker容器
  getent group docker
  if [ $? -eq 0 ]; then
    dockerGid=$(getent group docker | awk -F ':' '{print $3}')
    id ${dockerGid}
    if [ $? -ne 0 ]; then
      uidConfig="-u ${dockerGid}"
    fi
    groupConfig="-g docker"
  fi
  if id docker > /dev/null 2>&1; then
    echo -e "${INFO} docker 用户已存在"
  else
    useradd ${uidConfig} ${groupConfig} -d /home/docker -r -s /sbin/nologin docker
  fi
  [ ! -d '/home/docker' ] && {
    echo -e "${INFO} Create Docker HOME"
    mkdir /home/docker
    chown -R docker:docker /home/docker
  }
}

add_docker_user() {
  # [Deprecated] 将指定用户加入到docker用户组
  getent passwd $1
  if [ $? -eq 0 ]; then
    uid=$(getent passwd $1 | awk -F ':' '{print $3}')
  fi
  usermod -aG docker $uid
}

determine_max_id() {
  [ -z $1 ] && return 1
  local file="$1"

  [ ! -f "$file" ] && cat /dev/null > "$file"
  if grep -q "^dockremap:" "$file"; then
    echo -e "${INFO} $1 中已经存在 dockremap 条目"
    return 0
  fi
  local next_id=$(awk -F: '
    NF >= 3 && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ {
      end = $2 + $3
      if (end > max) max = end
    }
    END {
      max += 0
      print (max < 100000 ? 100000 : max)
    }' "$file"
  )
  echo -e "${INFO} 下一个可用 UID 起始值: $next_id"
  echo -e "dockremap:$next_id:65536" >> "$file"
}

userns_remap() {
  [ -z $1 ] && local remap_user="default" || local remap_user="$1"
  determine_max_id "/etc/subuid"
  determine_max_id "/etc/subgid"
  cat > /etc/docker/daemon.json <<EOF
{
  "userns-remap": "$remap_user"
}
EOF
}

configure_docker() {
  # 配置 docker
  systemctl stop docker
  sleep 2
  userns_remap
  systemctl start docker
  sleep 8

  systemctl stop docker
  sleep 2
  userns_remap "dockremap"
  systemctl start docker
}

install() {
  print_version
  get_distrib_info
  download_docker
  install_docker
  clean
  create_docker_user
  configure_docker
}

[ ! -d "${HOME}/logs" ] && mkdir ${HOME}/logs
install 2>&1 | tee ${HOME}/logs/docker.log
