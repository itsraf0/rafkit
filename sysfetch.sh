#!/usr/bin/env bash
# Cross-platform system fetch script (macOS + Linux)
# Preserves styling/output similar to macfetch.sh but adapts per-OS and degrades gracefully.

set -euo pipefail

NC='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'

OS_NAME="$(uname -s)"
LOWER() { tr '[:upper:]' '[:lower:]'; }
TRIM() { xargs; }

have() { command -v "$1" >/dev/null 2>&1; }

get_disk_space() {
  case "$OS_NAME" in
    Darwin)
      if have diskutil; then
        diskutil info / \
          | grep "Free Space" \
          | cut -d'(' -f1 \
          | cut -d':' -f2 \
          | sed 's/^ *//;s/$/ free/' | TRIM | LOWER
      else
        echo "n/a"
      fi
      ;;
    Linux)
      if have df; then
        # Example: "23G free"
        df -h / | awk 'NR==2{print tolower($4) " free"}'
      else
        echo "n/a"
      fi
      ;;
    *) echo "n/a" ;;
  esac
}

get_battery_health() {
  case "$OS_NAME" in
    Darwin)
      if have system_profiler; then
        local info cycles cond
        info=$(system_profiler SPPowerDataType 2>/dev/null || true)
        cycles=$(echo "$info" | awk -F": " '/Cycle Count/ {print $2; exit}')
        cond=$(echo "$info" | awk -F": " '/Condition/ {print $2; exit}' | TRIM | LOWER)
        if [ -n "${cycles:-}" ] || [ -n "${cond:-}" ]; then
          echo "cycle count: ${cycles:-n/a}, condition: ${cond:-n/a}"
        else
          echo "n/a"
        fi
      else
        echo "n/a"
      fi
      ;;
    Linux)
      if have upower; then
        local dev; dev=$(upower -e 2>/dev/null | grep -m1 BAT || true)
        if [ -n "$dev" ]; then
          # capacity is closer to overall health than percentage
          local capacity state warn cycles
          capacity=$(upower -i "$dev" 2>/dev/null | awk -F": *" '/capacity/ {print tolower($2); exit}')
          state=$(upower -i "$dev" 2>/dev/null | awk -F": *" '/state/ {print tolower($2); exit}')
          warn=$(upower -i "$dev" 2>/dev/null | awk -F": *" '/warning-level/ {print tolower($2); exit}')
          cycles=$(upower -i "$dev" 2>/dev/null | awk -F": *" '/cycle count/ {print tolower($2); exit}')
          echo "cycle count: ${cycles:-n/a}, condition: ${warn:-${state:-n/a}}, capacity: ${capacity:-n/a}"
        else
          echo "n/a"
        fi
      elif have acpi; then
        # acpi -i sometimes shows design capacity
        acpi -i 2>/dev/null | TRIM | LOWER || echo "n/a"
      else
        echo "n/a"
      fi
      ;;
    *) echo "n/a" ;;
  esac
}

get_battery() {
  case "$OS_NAME" in
    Darwin)
      if have pmset; then
        pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -n1 || echo "n/a"
      else
        echo "n/a"
      fi
      ;;
    Linux)
      if have upower; then
        local dev; dev=$(upower -e 2>/dev/null | grep -m1 BAT || true)
        if [ -n "$dev" ]; then
          upower -i "$dev" 2>/dev/null | awk -F": *" '/percentage/ {print $2; exit}' | TRIM || echo "n/a"
        else
          echo "n/a"
        fi
      elif have acpi; then
        acpi -b 2>/dev/null | grep -Eo '[0-9]+%' | head -n1 || echo "n/a"
      else
        echo "n/a"
      fi
      ;;
    *) echo "n/a" ;;
  esac
}

get_internet() {
  if ping -c1 -W1 1.1.1.1 >/dev/null 2>&1; then
    echo "online"
  else
    echo "offline"
  fi
}

get_local_ip() {
  case "$OS_NAME" in
    Darwin)
      if have route && have ipconfig; then
        local iface
        iface=$(route get default 2>/dev/null | awk '/interface:/ {print $2; exit}')
        ipconfig getifaddr "${iface:-lo0}" 2>/dev/null || echo "n/a"
      else
        echo "n/a"
      fi
      ;;
    Linux)
      if have ip; then
        ip route get 1.1.1.1 2>/dev/null |
          awk '{for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}' || echo "n/a"
      elif have hostname; then
        hostname -I 2>/dev/null | awk '{print $1}' || echo "n/a"
      else
        echo "n/a"
      fi
      ;;
    *) echo "n/a" ;;
  esac
}

get_public_ip() {
  if have curl; then
    curl -s https://api.ipify.org || echo "n/a"
  elif have wget; then
    wget -qO- https://api.ipify.org || echo "n/a"
  else
    echo "n/a"
  fi
}

get_vpn() {
  case "$OS_NAME" in
    Darwin)
      if have scutil; then
        local vpns conn
        vpns=$(scutil --nc list 2>/dev/null || true)
        conn=$(echo "$vpns" | awk -F"[()]" '/connected/ {print $3; exit}')
        echo "${conn:-none}"
      else
        echo "none"
      fi
      ;;
    Linux)
      # Try NetworkManager, then WireGuard, then OpenVPN systemd units
      if have nmcli; then
        local nm
        nm=$(nmcli -t -f NAME,TYPE,DEVICE con show --active 2>/dev/null | awk -F: '$2=="vpn" {print $1; exit}')
        if [ -n "${nm:-}" ]; then echo "$nm"; else echo "none"; fi
      elif have wg; then
        wg show 2>/dev/null | awk '/interface:/{print $2; exit}' | TRIM || echo "none"
      else
        # Fallback check for openvpn or wireguard units
        if have systemctl; then
          systemctl list-units --type=service --state=active 2>/dev/null | awk '/openvpn|wg-quick/{print $1; found=1} END{if(!found) print "none"}'
        else
          echo "none"
        fi
      fi
      ;;
    *) echo "none" ;;
  esac
}

get_os() {
  case "$OS_NAME" in
    Darwin)
      if have sw_vers; then
        echo "$(sw_vers -productName) $(sw_vers -productVersion)"
      else
        echo "macos"
      fi
      ;;
    Linux)
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${NAME:-Linux} ${VERSION_ID:-}"
      else
        echo "linux"
      fi
      ;;
    *) uname -srm ;;
  esac | TRIM | LOWER
}

get_terminal() {
  local val
  val="${TERM_PROGRAM:-} ${TERM_PROGRAM_VERSION:-}"
  if [ -z "$(echo "$val" | TRIM)" ]; then
    val="${TERM:-unknown}"
  fi
  echo "$val" | TRIM | LOWER
}

get_kernel() {
  uname -sr | TRIM | LOWER
}

get_host() {
  case "$OS_NAME" in
    Darwin)
      if have scutil; then
        scutil --get ComputerName 2>/dev/null || hostname
      else
        hostname
      fi
      ;;
    Linux)
      if have hostnamectl; then
        hostnamectl --static 2>/dev/null || hostname
      else
        hostname
      fi
      ;;
    *) hostname ;;
  esac | TRIM | LOWER
}

get_gpu() {
  case "$OS_NAME" in
    Darwin)
      if have system_profiler; then
        system_profiler SPDisplaysDataType 2>/dev/null | awk -F": " '/Chipset Model/ {print $2; exit}' | TRIM | LOWER || echo "n/a"
      else
        echo "n/a"
      fi
      ;;
    Linux)
      if have lspci; then
        lspci 2>/dev/null | awk -F': ' '/VGA compatible controller|3D controller/ {print $2; exit}' | TRIM | LOWER || echo "n/a"
      elif have glxinfo; then
        glxinfo -B 2>/dev/null | awk -F": *" '/Device:/ {print $2; exit}' | TRIM | LOWER || echo "n/a"
      else
        echo "n/a"
      fi
      ;;
    *) echo "n/a" ;;
  esac
}

get_cpu() {
  case "$OS_NAME" in
    Darwin)
      if have sysctl; then
        sysctl -n machdep.cpu.brand_string 2>/dev/null | TRIM | LOWER || echo "n/a"
      else
        echo "n/a"
      fi
      ;;
    Linux)
      if have lscpu; then
        lscpu 2>/dev/null | awk -F": *" '/Model name:/ {print $2; exit}' | TRIM | LOWER || echo "n/a"
      elif [ -r /proc/cpuinfo ]; then
        awk -F": *" '/model name/ {print tolower($2); exit}' /proc/cpuinfo | TRIM || echo "n/a"
      else
        echo "n/a"
      fi
      ;;
    *) echo "n/a" ;;
  esac
}

get_memory() {
  case "$OS_NAME" in
    Darwin)
      if have sysctl && have bc; then
        local bytes gb
        bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
        if [ "${bytes}" != "0" ]; then
          gb=$(echo "scale=2; $bytes/1024/1024/1024" | bc)
          echo "$gb gb"
        else
          echo "n/a"
        fi
      elif have sysctl; then
        # Fallback: integer GiB without bc
        local bytes
        bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
        if [ "${bytes}" != "0" ]; then
          echo "$(( bytes / 1024 / 1024 / 1024 )) gb"
        else
          echo "n/a"
        fi
      else
        echo "n/a"
      fi
      ;;
    Linux)
      if have free; then
        free -h 2>/dev/null | awk '/^Mem:/ {print tolower($2) " total"; exit}'
      elif [ -r /proc/meminfo ]; then
        awk '/MemTotal:/ {printf "%.2f gb", $2/1024/1024}' /proc/meminfo
      else
        echo "n/a"
      fi
      ;;
    *) echo "n/a" ;;
  esac
}

get_uptime() {
  case "$OS_NAME" in
    Darwin|Linux)
      # Both have uptime and similar human output; but it's inconsistent across distros/locales.
      # Prefer a deterministic approach on Linux via /proc/uptime if available.
      if [ "$OS_NAME" = "Linux" ] && [ -r /proc/uptime ]; then
        awk '{secs=int($1); d=int(secs/86400); h=int((secs%86400)/3600); m=int((secs%3600)/60); printf "%d days, %d:%02d", d, h, m }' /proc/uptime
      else
        uptime | awk -F'(up |, [0-9]+ users?, |,  load average:)' '{print $2}' | TRIM
      fi
      ;;
    *) echo "n/a" ;;
  esac
}

main() {
  echo -e "${MAGENTA}${BOLD}===== sysfetch for $(get_host) =====${NC}" | LOWER

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

  local up_str days color
  up_str=$(get_uptime)
  days=0
  # Extract leading number of days if present
  if echo "$up_str" | grep -qE '^[0-9]+ day'; then
    days=$(echo "$up_str" | awk '{print $1}')
  fi

  if [ "$days" -ge 7 ]; then
    color=$RED
  elif [ "$days" -gt 3 ]; then
    color=$YELLOW
  else
    color=$GREEN
  fi
  printf "${CYAN}🔼 uptime     ${NC}${BLUE} -> ${color}%s${NC}\n" "$up_str"
}

main "$@"

