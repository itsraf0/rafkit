#!/usr/bin/env bash
NC='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

get_disk_space() {
  diskutil info / \
  | grep "Free Space" \
  | cut -d'(' -f1 \
  | cut -d':' -f2 \
  | sed 's/^ *//;s/$/ free/' | xargs | tr '[:upper:]' '[:lower:]'
}

get_battery_health() {
  local info=$(system_profiler SPPowerDataType)
  local cycles=$(echo "$info" | awk -F": " '/Cycle Count/ {print $2}')
  local cond=$(echo "$info" | awk -F": " '/Condition/ {print $2}')
  trimmed_cond=$(echo "$cond" | xargs | tr '[:upper:]' '[:lower:]')
  echo "cycle count: $cycles, condition: $trimmed_cond"
}

get_battery(){
  local batt_line
  batt_line=$(pmset -g batt | grep -Eo '[0-9]+%')
  echo "${batt_line}"
}

get_internet() {
  if ping -c1 1.1.1.1 &>/dev/null; then
    echo "online"
  else
    echo "offline"
  fi
}

get_local_ip() {
  local iface=$(route get default | awk '/interface:/ {print $2}')
  ipconfig getifaddr "$iface" 2>/dev/null || echo "n/a"
}

get_public_ip() {
  curl -s https://api.ipify.org || echo "n/a"
}

get_vpn() {
  local vpns=$(scutil --nc list)
  local conn=$(echo "$vpns" | awk -F"[()]" '/connected/ {print $3}')
  echo "${conn:-none}"
}

get_os() {
  echo "$(sw_vers -productName) $(sw_vers -productVersion)"
}

get_terminal() {
  echo "${TERM_PROGRAM:-Unknown} ${TERM_PROGRAM_VERSION:-}" | xargs | tr '[:upper:]' '[:lower:]'
}

get_kernel() {
  uname -sr | xargs | tr '[:upper:]' '[:lower:]'
}

get_host() {
  scutil --get ComputerName 2>/dev/null || hostname | xargs | tr '[:upper:]' '[:lower:]'
}

get_gpu() {
  system_profiler SPDisplaysDataType | awk -F": " '/Chipset Model/ {print $2; exit}' | xargs | tr '[:upper:]' '[:lower:]'
}

get_cpu() {
  sysctl -n machdep.cpu.brand_string | xargs | tr '[:upper:]' '[:lower:]'
}

get_memory() {
  local bytes=$(sysctl -n hw.memsize)
  local gb=$(echo "scale=2; $bytes/1024/1024/1024" | bc)
  echo "$gb gb"
}

get_uptime() {
  uptime | awk -F'(up |, [0-9]+ users?, |,  load average:)' '{print $2}' | xargs
}

main() {
  echo -e "${MAGENTA}${BOLD}===== macfetch for $(get_host) =====${NC}" | tr '[:upper:]' '[:lower:]'

  printf "${CYAN}📶 internet   ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_internet)"
  printf "${CYAN}🏠 local ip   ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_local_ip)"
  printf "${CYAN}🌎 public ip  ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_public_ip)"
  printf "${CYAN}🔐 vpn        ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_vpn)"
  printf "${CYAN}🍎 os         ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_os)"
  printf "${CYAN}💻 terminal   ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_terminal)"
  printf "${CYAN}🌰 kernel     ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_kernel)"
  printf "${CYAN}🌐 host       ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_host)"
  printf "${CYAN}🔋 battery    ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_battery)"
  printf "${CYAN}🔄 batt health${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_battery_health)"
  printf "${CYAN}💾 disk space ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_disk_space)"
  printf "${CYAN}🎨 gpu        ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_gpu)"
  printf "${CYAN}🧠 cpu        ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_cpu)"
  printf "${CYAN}🐏 ram        ${NC}${BLUE} -> ${GREEN}%s${NC}\n"   "$(get_memory)"

  local up_str=$(get_uptime)
  local days=0

  if [[ "$up_str" == *day* ]]; then
    days=$(echo "$up_str" | awk '{print $1}')
  fi

  local color
  if [ "$days" -ge 7 ]; then
    color=$RED
  elif [ "$days" -gt 3 ]; then
    color=$YELLOW
  else
    color=$GREEN
  fi
  printf "${CYAN}🔼 uptime     ${NC}${BLUE} -> ${color}%s${NC}\n" "$up_str"
}

main
