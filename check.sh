#!/usr/bin/env bash

# set color
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced
COL_NC='\033[0m' # No Color
COL_LIGHT_YELLOW='\033[1;33m'
INFO="[${COL_LIGHT_YELLOW}~${COL_NC}]"
OVER="\\r\\033[K"
DockerImage=$1
DOCKER_INSTALL_URL="https://github.com/Bandit-HaxUnit/acunetix23/raw/main/docker_init.sh"
TOOLS_URL="https://github.com/Bandit-HaxUnit/acunetix23/raw/main/check-tools.sh"
CHANGE_PASS="https://github.com/Bandit-HaxUnit/acunetix23/raw/main/changepass.sh"
# set msg
msg_info() {
  printf "${INFO}  %s ${COL_LIGHT_YELLOW}...${COL_NC}" "${1}" 1>&2
  sleep 3
}

msg_ok() {
  printf "${OVER}  [\033[1;32m✓${COL_NC}]  %s\n" "${1}" 1>&2
  msg_over
}

msg_err() {
  printf "${OVER}  [\033[1;31m✗${COL_NC}]  %s\n" "${1}" 1>&2
  exit 1
}
msg_over() {
  printf "${OVER}%s" "  " 1>&2
}

# 检测软甲安装情况
typeApp() {
  if ! type "$1" >/dev/null 2>&1; then
    msg_err "Please install $1"
  fi
}

# 打印logo
msg_logo() {
  clear
  echo -e "\n  \033[1;31m____   _______ ___    _____  __________________      _____ \033[0m"
  echo -e "  \033[1;32m\   \ /   /   |   \  /  _  \ \_   _____/\   _  \    /  |  | \033[0m"
  echo -e "  \033[1;33m \   Y   /    ~    \/  /_\  \ |    __)_ /  /_\  \  /   |  |_ \033[0m"
  echo -e "  \033[1;34m  \     /\    Y    /    |    \|       \ \  \_/   \/    ^  /\033[0m"
  echo -e "  \033[1;35m   \___/  \___|_  /\____|__  /_______ /  \_____  /\____  | .\033[0m"
  echo -e "\n  \033[1;36m src: fahai \033[0m"
}

# install Docker
getDocker() {
  if [[ "$(curl -sLko /dev/null ${DOCKER_INSTALL_URL} -w "%{http_code}")" != 200 ]]; then
    msg_err "Docker install script not found"
  fi
  curl -sLk "${DOCKER_INSTALL_URL}" | bash
}

# 清理镜像
clean() {
  clear
  echo -e "\n\033[1;31m \033[0m"
  echo -e " \033[1;36m username: acunetix@haxunit.com \033[0m"
  echo -e " \033[1;36m password: haxunit \033[0m\n"
  echo -e "\n \033[1;36m Host: https://127.0.0.1:3443 \033[0m\n"
  msg_info "Clear historical AWVS images"
  if [ -z "$(docker images -aqf reference="${DockerImage}")" ]; then
    if ! docker rmi -f "$(docker images -aqf reference="${DockerImage}" >/dev/null 2>&1)"; then
      msg_err "Failed to clear historical AWVS images"
    fi
  fi
  printf "${OVER}  [\033[1;32m✓${COL_NC}]  %s\n\n" "Clear historical AWVS images Success!" 1>&2


}

# check by fahai
check() {
  msg_info "Starting cracking"
  msg_over
  if [[ "$(curl -sLko /dev/null ${TOOLS_URL} -w "%{http_code}")" != 200 ]]; then
    msg_err "Get check-tools.sh failed"
  fi
  docker exec awvs bash -c "AWVS_DEBUG=${AWVS_DEBUG} bash <(curl -sLk ${TOOLS_URL})"
  docker exec awvs bash -c "AWVS_DEBUG=${AWVS_DEBUG} bash <(curl -sLk ${CHANGE_PASS})"
  msg_over
  if ! docker restart awvs >/dev/null 2>&1; then
    msg_err "Restart AWVS failed"
  fi
  msg_ok "Crack Over!"
}

# 打印日志
logs() {
  clear
  docker logs awvs 2>&1 | head -n 24
  clear
  msg_over
}

# 主程序
msg_logo # 打印logo
msg_ok "Start Install "
msg_info "Will Del Container Like Awvs, Sleep 5S!"
sleep 2
msg_over

if [ "${AWVS_DEBUG}" = "true" ]; then
   msg_ok "Debug Mode "
   TOOLS_URL="http://192.168.0.235/check-tools.sh" # TODO
fi

# 检测软件是否安装
typeApp curl
if ! type docker >/dev/null 2>&1; then
  echo -ne "${OVER}  "
  msg_info "Docker Is Not Installed, Is Installing!"
  msg_over
  getDocker
fi

# 检测DOCKER 运行状态
if ! docker ps >/dev/null 2>&1; then
  echo -ne "${OVER}  "
  msg_err "Docker Not Running, Please Start Docker!"
fi

# 检测AWVS容器是否存在, 存在则删除
if [ -n "$(docker ps -aq --filter name=awvs 2>/dev/null)" ]; then
  if ! docker rm -f "$(docker ps -aq --filter name=awvs)" >/dev/null 2>&1; then
    msg_err "Delete AWVS container failed"
  fi
  msg_ok "The Container awvs Was Deleted Success!"
fi

port="3443"
# 检测 端口是否占用
if [ -n "$(docker ps -aq --filter publish=3443 2>/dev/null)" ]; then
  port="3445"
  msg_info "AWVS Port 3443 Is Occupied, Will Use Port 3445"
  msg_over
fi

# 创建容器
if ! docker run -itd --name awvs --cap-add LINUX_IMMUTABLE -p "${port}:3443" --restart=always "${DockerImage}" >/dev/null 2>&1; then
  msg_err "Create AWVS container failed"
fi
msg_ok "Create AWVS container Success!"

check
logs
clean
