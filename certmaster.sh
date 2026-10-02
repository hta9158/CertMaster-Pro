#!/usr/bin/env bash

# =========================================================
#              CERTMASTER ENTERPRISE
#        Ultimate Commercial SSL Management Suite
#                 (Modern CLI Edition)
# =========================================================

VERSION="0.0.2 CLI"

# =========================================================
# PATHS
# =========================================================
BASE_DIR="/opt/CertMaster-Pro"
CONFIG_DIR="$BASE_DIR/config"
LOG_DIR="$BASE_DIR/logs"
BACKUP_DIR="$BASE_DIR/backups"
CONFIG_FILE="$CONFIG_DIR/settings.json"
LOG_FILE="$LOG_DIR/activity.log"
UPDATE_URL="https://raw.githubusercontent.com/hta9158/CertMaster-Pro/main/certmaster.sh"
GITHUB_URL="https://github.com/hta9158/CertMaster-Pro"
TELEGRAM_HANDLE="@hta9158"

# =========================================================
# NEON COLORS
# =========================================================
RESET='\033[0m'
BOLD='\033[1m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NEON_BLUE='\033[38;5;45m'
NEON_GREEN='\033[38;5;46m'
NEON_PINK='\033[38;5;213m'
GRAY='\033[38;5;245m'

# =========================================================
# ROOT CHECK & INIT
# =========================================================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Please run as root.${RESET}"
    exit 1
fi

# Keep the shell execution PATH intact. Runtime variables must never be named PATH.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"


mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR"
touch "$LOG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
cat > "$CONFIG_FILE" <<EOF
{
  "telegram_bot_token": "",
  "telegram_chat_id": "",
  "cloudflare_email": "",
  "cloudflare_api_key": "",
  "domains": []
}
EOF
fi

# =========================================================
# UI COMPONENTS - CERTMASTER SIGNATURE CLI
# =========================================================
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[1;31m'
BRIGHT_RED='\033[38;5;196m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[38;5;51m'
MAGENTA='\033[38;5;213m'
WHITE='\033[1;37m'
GRAY='\033[38;5;245m'
DARK_GRAY='\033[38;5;239m'
BLUE='\033[38;5;39m'

term_width() {
    local w
    w=$(tput cols 2>/dev/null || echo 100)
    (( w < 80 )) && w=80
    (( w > 116 )) && w=116
    echo "$w"
}

box_width() {
    local w
    w=$(term_width)
    echo $((w-4))
}

strip_ansi() {
    sed $'s/\\033\\[[0-9;]*m//g'
}

repeat_char() {
    local char="$1" count="$2"
    (( count < 0 )) && count=0
    printf '%*s' "$count" '' | tr ' ' "$char"
}

rule() {
    local color="${1:-$DARK_GRAY}"
    echo -e "${color}$(repeat_char '─' "$(box_width)")${RESET}"
}

center_text() {
    local text="$1" width visible pad
    width=$(term_width)
    visible=$(printf '%b' "$text" | strip_ansi | awk '{print length}')
    pad=$(( (width - visible) / 2 ))
    (( pad < 0 )) && pad=0
    printf '%*s%b\n' "$pad" '' "$text"
}

status_chip() {
    local label="$1" value="$2" color="$3"
    printf "  ${DARK_GRAY}│${RESET} ${GRAY}%-11s${RESET} ${color}${BOLD}%-12s${RESET}" "$label" "$value"
}

ui_header() {
    clear

    local os_name web_status cert_count renew_status

    os_name=$( . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}" )

    if systemctl is-active nginx >/dev/null 2>&1; then
        web_status="NGINX"
    elif systemctl is-active apache2 >/dev/null 2>&1; then
        web_status="APACHE"
    else
        web_status="NONE"
    fi

    cert_count=$(find /etc/letsencrypt/live -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)

    if crontab -l 2>/dev/null | grep -q 'certbot renew'; then
        renew_status="ON"
    else
        renew_status="OFF"
    fi

    echo
    center_text "${BRIGHT_RED}${BOLD}██████╗███████╗██████╗ ████████╗███╗   ███╗ █████╗ ███████╗████████╗███████╗██████╗${RESET}"
    center_text "${BRIGHT_RED}${BOLD}██╔════╝██╔════╝██╔══██╗╚══██╔══╝████╗ ████║██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗${RESET}"
    center_text "${BRIGHT_RED}${BOLD}██║     █████╗  ██████╔╝   ██║   ██╔████╔██║███████║███████╗   ██║   █████╗  ██████╔╝${RESET}"
    center_text "${BRIGHT_RED}${BOLD}██║     ██╔══╝  ██╔══██╗   ██║   ██║╚██╔╝██║██╔══██║╚════██║   ██║   ██╔══╝  ██╔══██╗${RESET}"
    center_text "${BRIGHT_RED}${BOLD}╚██████╗███████╗██║  ██║   ██║   ██║ ╚═╝ ██║██║  ██║███████║   ██║   ███████╗██║  ██║${RESET}"
    center_text "${BRIGHT_RED}${BOLD} ╚═════╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝${RESET}"

    center_text "${CYAN}◆  SSL CERTIFICATE MANAGEMENT  ◆${RESET}"
    center_text "${MAGENTA}Enterprise CLI${RESET}  ${DARK_GRAY}•${RESET}  ${WHITE}v${VERSION}${RESET}"

    echo
    printf "  ${GRAY}Telegram:${RESET} ${MAGENTA}${TELEGRAM_HANDLE}${RESET}  ${DARK_GRAY}|${RESET}  ${GRAY}GitHub:${RESET} ${CYAN}${GITHUB_URL}${RESET}\n"
    printf "  ${GRAY}OS:${RESET} ${WHITE}${os_name}${RESET}  ${DARK_GRAY}|${RESET}  ${GRAY}WEB:${RESET} ${BLUE}${web_status}${RESET}  ${DARK_GRAY}|${RESET}  ${GRAY}CERTS:${RESET} ${WHITE}${cert_count}${RESET}  ${DARK_GRAY}|${RESET}  ${GRAY}AUTO-RENEW:${RESET} "

    if [[ "$renew_status" == "ON" ]]; then
        printf "${GREEN}ON${RESET}"
    else
        printf "${YELLOW}OFF${RESET}"
    fi

    printf "  ${DARK_GRAY}|${RESET}  ${GRAY}STATUS:${RESET} ${GREEN}● ONLINE${RESET}\n"

    # One subtle separator only — intentionally no boxes or extra horizontal lines.
    echo -e "${DARK_GRAY}$(repeat_char '─' 78)${RESET}"
    echo
}

section_title() {
    local title="$1" subtitle="$2"
    echo -e "${DARK_GRAY}──${RESET} ${WHITE}${BOLD}${title}${RESET} ${DARK_GRAY}──${RESET}"
    [[ -n "$subtitle" ]] && echo -e "${GRAY}   $subtitle${RESET}"
    echo
}

success() { echo -e "  ${GREEN}●${RESET} ${WHITE}$1${RESET}"; }
error()   { echo -e "  ${RED}●${RESET} ${WHITE}$1${RESET}"; }
warning() { echo -e "  ${YELLOW}●${RESET} ${WHITE}$1${RESET}"; }
info()    { echo -e "  ${CYAN}◆${RESET} ${WHITE}$1${RESET}"; }
log()     { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" >> "$LOG_FILE"; }

pause_screen() {
    echo
    rule "$DARK_GRAY"
    read -r -p "  Press ENTER to return to the main menu... "
}

progress_bar() {
    local duration="$1" title="$2" i percent filled empty
    echo -e "  ${MAGENTA}◆${RESET} ${WHITE}${title}${RESET}"
    for ((i=0; i<=duration; i++)); do
        percent=$((i * 100 / duration))
        filled=$((i * 32 / duration))
        empty=$((32-filled))
        printf "\r  ${BRIGHT_RED}["
        (( filled > 0 )) && printf '%0.s█' $(seq 1 "$filled" 2>/dev/null)
        (( empty > 0 )) && printf '%0.s░' $(seq 1 "$empty" 2>/dev/null)
        printf "] ${CYAN}%3d%%${RESET}" "$percent"
        sleep 0.05
    done
    echo
}

menu_item() {
    local n="$1" title="$2" desc="$3"
    printf "  ${BRIGHT_RED}${BOLD}%-3s${RESET} ${WHITE}${BOLD}%-23s${RESET} ${DARK_GRAY}·${RESET} ${CYAN}%s${RESET}\n" "$n)" "$title" "$desc"
}

# =========================================================
# CORE FUNCTIONS
# =========================================================
detect_webserver() {
    if systemctl is-active nginx >/dev/null 2>&1; then WEBSERVER="nginx"
    elif systemctl is-active apache2 >/dev/null 2>&1; then WEBSERVER="apache2"
    else WEBSERVER=""
    fi
}

ssl_grade() {
    DAYS=$1
    if ! [[ "$DAYS" =~ ^-?[0-9]+$ ]]; then
        echo -e "${RED}ERR${RESET}"
        return
    fi

    if [ $DAYS -gt 60 ]; then echo -e "${NEON_GREEN}A+${RESET}"
    elif [ $DAYS -gt 30 ]; then echo -e "${GREEN}A${RESET}"
    elif [ $DAYS -gt 15 ]; then echo -e "${YELLOW}B${RESET}"
    else echo -e "${RED}C${RESET}"
    fi
}

telegram_alert() {
    TOKEN=$(jq -r '.telegram_bot_token' "$CONFIG_FILE" 2>/dev/null)
    CHAT_ID=$(jq -r '.telegram_chat_id' "$CONFIG_FILE" 2>/dev/null)
    if [[ ! -z "$TOKEN" && ! -z "$CHAT_ID" && "$TOKEN" != "null" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$1" >/dev/null
    fi
}

# =========================================================
# 1. INSTALL SSL
# =========================================================
install_certificate() {
    ui_header
    section_title "INSTALL SSL" "Simple setup — choose a panel, enter your domains, and CertMaster handles the rest."

    echo -e "  ${CYAN}1)${RESET} ${WHITE}${BOLD}Pasarguard${RESET}  ${GRAY}/var/lib/pasarguard/certs${RESET}"
    echo -e "  ${CYAN}2)${RESET} ${WHITE}${BOLD}Marzban${RESET}     ${GRAY}/var/lib/marzban/certs${RESET}"
    echo -e "  ${CYAN}3)${RESET} ${WHITE}${BOLD}Rebecca${RESET}     ${GRAY}/var/lib/rebecca/certs${RESET}"
    echo -e "  ${CYAN}4)${RESET} ${WHITE}${BOLD}Custom${RESET}      ${GRAY}Custom certificate directory${RESET}"
    echo
    echo -e "  ${BRIGHT_RED}0)${RESET} ${GRAY}Back to main menu${RESET}"
    echo
    read -r -p "Select panel [0-4]: " panel_choice

    case $panel_choice in
        0)
            return
            ;;
        1)
            TARGET_BASE_DIR="/var/lib/pasarguard/certs"
            PANEL_NAME="Pasarguard"
            ;;
        2)
            TARGET_BASE_DIR="/var/lib/marzban/certs"
            PANEL_NAME="Marzban"
            ;;
        3)
            TARGET_BASE_DIR="/var/lib/rebecca/certs"
            PANEL_NAME="Rebecca"
            ;;
        4)
            read -r -p "Custom certificate directory: " TARGET_BASE_DIR
            [[ -z "$TARGET_BASE_DIR" || "$TARGET_BASE_DIR" != /* ]] && {
                error "Custom path must be an absolute path."
                pause_screen
                return
            }
            PANEL_NAME="Custom"
            ;;
        *)
            error "Invalid panel choice."
            pause_screen
            return
            ;;
    esac

    echo
    success "Selected panel: ${PANEL_NAME}"
    info "Certificates will be saved under: ${TARGET_BASE_DIR}"
    echo

    # -----------------------------------------------------
    # SIMPLE MULTI-DOMAIN INPUT
    # -----------------------------------------------------
    echo -e "${WHITE}${BOLD}DOMAINS${RESET}"
    echo -e "  ${GRAY}Enter all domains in one line, separated by commas or spaces.${RESET}"
    echo -e "  ${GRAY}Example: panel.example.com, vpn.example.com, api.example.com${RESET}"
    echo

    read -r -p "Domains: " DOMAIN_INPUT

    [[ -z "$DOMAIN_INPUT" ]] && {
        warning "No domains entered."
        pause_screen
        return
    }

    DOMAIN_INPUT=${DOMAIN_INPUT//,/ }
    read -ra INPUT_DOMAINS <<< "$DOMAIN_INPUT"

    DOMAINS=()
    for DOMAIN in "${INPUT_DOMAINS[@]}"; do
        DOMAIN="${DOMAIN#https://}"
        DOMAIN="${DOMAIN#http://}"
        DOMAIN="${DOMAIN%%/*}"
        [[ -z "$DOMAIN" ]] && continue

        if [[ "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
            if [[ ! " ${DOMAINS[*]} " =~ " $DOMAIN " ]]; then
                DOMAINS+=("$DOMAIN")
            fi
        else
            warning "Invalid domain skipped: $DOMAIN"
        fi
    done

    if (( ${#DOMAINS[@]} == 0 )); then
        error "No valid domains were entered."
        pause_screen
        return
    fi

    echo
    echo -e "${WHITE}${BOLD}DOMAINS TO INSTALL${RESET}"
    for i in "${!DOMAINS[@]}"; do
        printf "  ${GREEN}●${RESET} %s\n" "${DOMAINS[$i]}"
    done
    echo

    # -----------------------------------------------------
    # SIMPLE CHALLENGE SELECTION
    # -----------------------------------------------------
    detect_webserver

    echo -e "${WHITE}${BOLD}SSL VALIDATION${RESET}"
    echo -e "  ${CYAN}1)${RESET} ${WHITE}Automatic${RESET}      ${GRAY}Choose the best available method${RESET}"
    echo -e "  ${CYAN}2)${RESET} ${WHITE}Cloudflare DNS${RESET} ${GRAY}No downtime — requires Cloudflare API${RESET}"
    echo -e "  ${CYAN}3)${RESET} ${WHITE}Webroot${RESET}       ${GRAY}Works with Nginx/Apache${RESET}"
    echo -e "  ${CYAN}4)${RESET} ${WHITE}Standalone${RESET}    ${GRAY}Temporarily uses port 80${RESET}"
    echo
    read -r -p "Validation method [1-4, default 1]: " challenge_choice
    challenge_choice=${challenge_choice:-1}

    WEBROOT_PATH=""
    STOPPED_WEBSERVER=""
    CF_EMAIL=""
    CF_KEY=""

    # Automatic selection:
    # Cloudflare credentials -> Cloudflare DNS
    # otherwise active webserver -> Webroot
    # otherwise -> Standalone
    if [[ "$challenge_choice" == "1" ]]; then
        CF_EMAIL=$(jq -r '.cloudflare_email // empty' "$CONFIG_FILE" 2>/dev/null)
        CF_KEY=$(jq -r '.cloudflare_api_key // empty' "$CONFIG_FILE" 2>/dev/null)

        if [[ -n "$CF_EMAIL" && -n "$CF_KEY" ]]; then
            challenge_choice="2"
            info "Automatic method selected: Cloudflare DNS"
        elif [[ -n "$WEBSERVER" ]]; then
            challenge_choice="3"
            info "Automatic method selected: Webroot (${WEBSERVER})"
        else
            challenge_choice="4"
            info "Automatic method selected: Standalone"
        fi
    fi

    case $challenge_choice in
        2)
            CF_EMAIL=$(jq -r '.cloudflare_email // empty' "$CONFIG_FILE" 2>/dev/null)
            CF_KEY=$(jq -r '.cloudflare_api_key // empty' "$CONFIG_FILE" 2>/dev/null)

            if [[ -z "$CF_EMAIL" || -z "$CF_KEY" ]]; then
                echo
                info "Cloudflare API details are needed once. They will be saved securely for future use."
                read -r -p "Cloudflare Email: " CF_EMAIL
                read -r -p "Cloudflare API Key: " CF_KEY

                if [[ -z "$CF_EMAIL" || -z "$CF_KEY" ]]; then
                    error "Cloudflare credentials cannot be empty."
                    pause_screen
                    return
                fi

                TMP=$(jq --arg e "$CF_EMAIL" --arg k "$CF_KEY" \
                    '.cloudflare_email=$e | .cloudflare_api_key=$k' "$CONFIG_FILE")
                echo "$TMP" > "$CONFIG_FILE"
            fi

            mkdir -p /root/.secrets
            printf 'dns_cloudflare_email = %s\ndns_cloudflare_api_key = %s\n' \
                "$CF_EMAIL" "$CF_KEY" > /root/.secrets/cloudflare.ini
            chmod 600 /root/.secrets/cloudflare.ini
            ;;
        3)
            WEBROOT_PATH="/var/www/html"
            if [[ -z "$WEBSERVER" ]]; then
                warning "No active Nginx/Apache detected."
                read -r -p "Webroot path [/var/www/html]: " WEBROOT_PATH_INPUT
                WEBROOT_PATH=${WEBROOT_PATH_INPUT:-/var/www/html}
            else
                info "Using ${WEBSERVER} with webroot: ${WEBROOT_PATH}"
            fi
            ;;
        4)
            if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null 2>&1; then
                detect_webserver
                if [[ -n "$WEBSERVER" ]]; then
                    warning "Port 80 is currently used by ${WEBSERVER}."
                    read -r -p "Stop ${WEBSERVER} temporarily? [y/N]: " stop_web
                    if [[ "$stop_web" =~ ^[Yy]$ ]]; then
                        systemctl stop "$WEBSERVER"
                        STOPPED_WEBSERVER="$WEBSERVER"
                    else
                        error "Operation cancelled."
                        pause_screen
                        return
                    fi
                else
                    error "Port 80 is already in use by another service."
                    pause_screen
                    return
                fi
            fi
            ;;
        *)
            error "Invalid validation method."
            pause_screen
            return
            ;;
    esac

    echo
    section_title "ISSUING CERTIFICATES" "One independent SSL certificate will be created for each domain."

    SUCCESS_COUNT=0
    FAILED_COUNT=0
    RESULTS=()

    for DOMAIN in "${DOMAINS[@]}"; do
        CURRENT_INDEX=$((SUCCESS_COUNT + FAILED_COUNT + 1))
        echo
        echo -e "${WHITE}${BOLD}[${CURRENT_INDEX}/${#DOMAINS[@]}] ${DOMAIN}${RESET}"

        case $challenge_choice in
            2)
                certbot certonly \
                    --dns-cloudflare \
                    --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
                    -d "$DOMAIN" \
                    --non-interactive --agree-tos \
                    --register-unsafely-without-email >/dev/null 2>&1
                ;;
            3)
                certbot certonly \
                    --webroot -w "$WEBROOT_PATH" \
                    -d "$DOMAIN" \
                    --non-interactive --agree-tos \
                    --register-unsafely-without-email >/dev/null 2>&1
                ;;
            4)
                certbot certonly \
                    --standalone \
                    -d "$DOMAIN" \
                    --non-interactive --agree-tos \
                    --register-unsafely-without-email >/dev/null 2>&1
                ;;
        esac

        CERTBOT_STATUS=$?

        if [[ $CERTBOT_STATUS -eq 0 && -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
            FINAL_PATH="$TARGET_BASE_DIR/$DOMAIN"
            mkdir -p "$FINAL_PATH"
            cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$FINAL_PATH/fullchain.pem"
            cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$FINAL_PATH/privkey.pem"
            chmod 644 "$FINAL_PATH/fullchain.pem"
            chmod 600 "$FINAL_PATH/privkey.pem"

            TMP=$(jq --arg d "$DOMAIN" --arg p "$FINAL_PATH" --arg pn "$PANEL_NAME" \
                '.domains = (.domains // []) + [{"main_domain":$d,"install_path":$p,"panel":$pn}]' \
                "$CONFIG_FILE" 2>/dev/null)
            [[ -n "$TMP" ]] && echo "$TMP" > "$CONFIG_FILE"

            ((SUCCESS_COUNT++))
            RESULTS+=("OK|$DOMAIN|$FINAL_PATH")
            success "SSL installed: $DOMAIN"
        else
            ((FAILED_COUNT++))
            RESULTS+=("FAIL|$DOMAIN|")
            error "SSL failed: $DOMAIN"
        fi
    done

    if [[ -n "$STOPPED_WEBSERVER" ]]; then
        systemctl start "$STOPPED_WEBSERVER"
    fi

    echo
    section_title "INSTALLATION COMPLETE" "Installation summary"

    printf "  ${GRAY}Panel:${RESET}       ${WHITE}%s${RESET}\n" "$PANEL_NAME"
    printf "  ${GRAY}Base path:${RESET}   ${WHITE}%s${RESET}\n" "$TARGET_BASE_DIR"
    printf "  ${GRAY}Domains:${RESET}     ${WHITE}%d${RESET}\n" "${#DOMAINS[@]}"
    printf "  ${GRAY}Successful:${RESET}  ${GREEN}%d${RESET}\n" "$SUCCESS_COUNT"
    printf "  ${GRAY}Failed:${RESET}      ${RED}%d${RESET}\n" "$FAILED_COUNT"
    echo

    for RESULT in "${RESULTS[@]}"; do
        IFS='|' read -r RESULT_STATUS RESULT_DOMAIN RESULT_PATH <<< "$RESULT"
        if [[ "$RESULT_STATUS" == "OK" ]]; then
            echo -e "  ${GREEN}●${RESET} ${WHITE}${RESULT_DOMAIN}${RESET}"
            echo -e "      ${GRAY}Certificate:${RESET} ${RESULT_PATH}/fullchain.pem"
            echo -e "      ${GRAY}Private key:${RESET} ${RESULT_PATH}/privkey.pem"
        else
            echo -e "  ${RED}●${RESET} ${WHITE}${RESULT_DOMAIN}${RESET} ${RED}FAILED${RESET}"
        fi
    done

    echo
    if (( FAILED_COUNT == 0 )); then
        success "All requested domains were completed successfully."
    else
        warning "Some domains failed. Review the failed entries above."
    fi

    pause_screen
}

# =========================================================
# 2. WILDCARD SSL
# =========================================================
wildcard_ssl() {
    ui_header
    echo -e "${NEON_PINK}--- GENERATE WILDCARD SSL ---${RESET}"
    read -r -p "Base domain: " DOMAIN
    [[ -z "$DOMAIN" ]] && return

    CF_EMAIL=$(jq -r '.cloudflare_email' "$CONFIG_FILE")
    CF_KEY=$(jq -r '.cloudflare_api_key' "$CONFIG_FILE")
    if [[ -z "$CF_EMAIL" || "$CF_EMAIL" == "null" ]]; then
        read -r -p "Cloudflare Email: " CF_EMAIL
        read -r -p "Cloudflare API Key: " CF_KEY
        TMP=$(jq --arg e "$CF_EMAIL" --arg k "$CF_KEY" '.cloudflare_email=$e | .cloudflare_api_key=$k' "$CONFIG_FILE")
        echo "$TMP" > "$CONFIG_FILE"
    fi
    mkdir -p ~/.secrets
    echo -e "dns_cloudflare_email = $CF_EMAIL\ndns_cloudflare_api_key = $CF_KEY" > ~/.secrets/cloudflare.ini
    chmod 600 ~/.secrets/cloudflare.ini

    echo
    progress_bar 25 "Requesting Wildcard Certificate..."
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/cloudflare.ini -d "*.$DOMAIN" -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        success "Wildcard SSL generated successfully for *.$DOMAIN!"
    else
        error "Failed to generate Wildcard SSL."
    fi
    pause_screen
}

# =========================================================
# GET DOMAINS CORE (Shared by List and Delete)
# =========================================================
get_scanned_domains() {
    CERTS_LIST=()
    SEEN_DOMAINS=()
    
    # اولویت اسکن تغییر یافت: ابتدا پنل‌ها اسکن می‌شوند تا مسیر و هویت دقیق ثبت شود
    SEARCH_DIRS=(
        "/var/lib/rebecca/certs"
        "/var/lib/marzban/certs"
        "/var/lib/pasarguard/certs"
        "/var/lib/marzneshin/certs"
        "/etc/letsencrypt/live"
    )

    for base_dir in "${SEARCH_DIRS[@]}"; do
        [ -d "$base_dir" ] || continue
        for cert_dir in "$base_dir"/*; do
            [ -d "$cert_dir" ] || continue
            DOMAIN=$(basename "$cert_dir")
            [ "$DOMAIN" == "README" ] && continue
            
            if [[ " ${SEEN_DOMAINS[@]} " =~ " ${DOMAIN} " ]]; then continue; fi

            CERT_FILE="$cert_dir/fullchain.pem"
            if [ ! -f "$CERT_FILE" ]; then
                CERT_FILE=$(find "$cert_dir" -maxdepth 1 -name "*.crt" -o -name "*.pem" 2>/dev/null | head -n 1)
            fi
            
            [ -z "$CERT_FILE" ] || [ ! -f "$CERT_FILE" ] && continue

            EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
            if [ -z "$EXPIRY_DATE" ]; then continue; fi
            
            EXP_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
            CUR_EPOCH=$(date +%s)
            
            if [[ -z "$EXP_EPOCH" ]]; then continue; fi
            DAYS_LEFT=$(( (EXP_EPOCH - CUR_EPOCH) / 86400 ))
            
            # بررسی دیتابیس لوکال
            PANEL_INFO=$(jq -r --arg d "$DOMAIN" '.domains[] | select(.main_domain==$d) | .panel' "$CONFIG_FILE" 2>/dev/null)
            
            # تشخیص هوشمند پنل از روی آدرس پوشه در صورت نبود در دیتابیس
            if [[ -z "$PANEL_INFO" || "$PANEL_INFO" == "null" ]]; then
                if [[ "$base_dir" == *"/rebecca/"* ]]; then PANEL_INFO="Rebecca"
                elif [[ "$base_dir" == *"/marzban/"* ]]; then PANEL_INFO="Marzban"
                elif [[ "$base_dir" == *"/pasarguard/"* ]]; then PANEL_INFO="Pasarguard"
                elif [[ "$base_dir" == *"/marzneshin/"* ]]; then PANEL_INFO="Marzneshin"
                else PANEL_INFO="Certbot/Standalone"
                fi
            fi

            SEEN_DOMAINS+=("$DOMAIN")
            CERTS_LIST+=("$DOMAIN|$DAYS_LEFT|$PANEL_INFO|$CERT_FILE") 
        done
    done
}

# =========================================================
# 3. LIST CERTIFICATES
# =========================================================
list_certificates() {
    while true; do
        ui_header
        echo -e "${NEON_PINK}--- MANAGED CERTIFICATES ---${RESET}"
        echo

        get_scanned_domains

        if [ ${#CERTS_LIST[@]} -eq 0 ]; then
            warning "No valid SSL certificates found on the server."
            echo
            echo -e "${BRIGHT_RED}0)${RESET} Return to Main Menu"
            echo
            read -r -p "Select option [0=Back]: " EMPTY_CHOICE
            return
        fi

        printf "${CYAN}%-4s %-65s %-15s %-10s %-8s${RESET}\n" "ID" "DOMAIN" "PANEL" "DAYS LEFT" "GRADE"
        echo -e "${GRAY}-------------------------------------------------------------------------------------------------------------${RESET}"

        INDEX=1
        for item in "${CERTS_LIST[@]}"; do
            IFS='|' read -r d_name d_days d_panel d_file <<< "$item"
            GRADE=$(ssl_grade "$d_days")
            printf "%-4s %-65s %-15s %-10s %-8b\n" "[$INDEX]" "$d_name" "$d_panel" "$d_days" "$GRADE"
            ((INDEX++))
        done

        echo
        echo -e "${BRIGHT_RED}0)${RESET} Return to Main Menu"
        echo
        read -r -p "Select ID [0=Back]: " CHOICE

        # 0 from the certificate list -> main menu
        if [[ "$CHOICE" == "0" ]]; then
            return
        fi

        # Invalid certificate selection -> stay in Managed Certificates
        if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || \
           [ "$CHOICE" -lt 1 ] || \
           [ "$CHOICE" -gt ${#CERTS_LIST[@]} ]; then
            error "Invalid certificate ID."
            sleep 1
            continue
        fi

        SELECTED_INDEX=$((CHOICE - 1))
        IFS='|' read -r d_name d_days d_panel d_file <<< "${CERTS_LIST[$SELECTED_INDEX]}"
        CERT_DIR=$(dirname "$d_file")

        # =====================================================
        # CERTIFICATE DETAILS
        # =====================================================
        while true; do
            ui_header
            echo -e "${NEON_PINK}--- CERTIFICATE DETAILS ---${RESET}"
            echo
            echo -e "${CYAN}🌐 Domain:${RESET}       $d_name"
            echo -e "${CYAN}📦 Active Panel:${RESET} $d_panel"
            echo -e "${CYAN}📂 Cert File:${RESET}    $CERT_DIR/fullchain.pem"
            echo -e "${CYAN}🔑 Private Key:${RESET}  $CERT_DIR/privkey.pem"
            echo -e "${CYAN}⏳ Days Left:${RESET}    $d_days days"
            echo -e "${CYAN}🏆 SSL Grade:${RESET}    $(ssl_grade "$d_days")"

            echo
            if [[ -f "$CERT_DIR/fullchain.pem" ]]; then
                echo -e "${GREEN}●${RESET} Certificate: ${GREEN}FOUND${RESET}"
            else
                echo -e "${RED}●${RESET} Certificate: ${RED}MISSING${RESET}"
            fi

            if [[ -f "$CERT_DIR/privkey.pem" ]]; then
                echo -e "${GREEN}●${RESET} Private Key:  ${GREEN}FOUND${RESET}"
            else
                echo -e "${RED}●${RESET} Private Key:  ${RED}MISSING${RESET}"
            fi

            echo
            echo -e "${BRIGHT_RED}0)${RESET} Back to Managed Certificates"
            echo
            read -r -p "Select option [0=Back]: " DETAIL_CHOICE

            if [[ "$DETAIL_CHOICE" == "0" ]]; then
                # IMPORTANT: go back to certificate list, NOT main menu
                break
            fi

            error "Invalid option. Select 0 to return to Managed Certificates."
            sleep 1
        done
    done
}

# =========================================================
# 4. DELETE CERTIFICATE (DEEP CLEAN)
# =========================================================
delete_certificate() {
    ui_header
    echo -e "${NEON_PINK}--- DELETE CERTIFICATES ---${RESET}"
    echo
    
    get_scanned_domains

    if [ ${#CERTS_LIST[@]} -eq 0 ]; then
        warning "No SSL certificates found to delete."
        pause_screen
        return
    fi

    printf "${CYAN}%-4s %-65s %-15s${RESET}\n" "ID" "DOMAIN TO DELETE" "DETECTED IN"
    echo -e "${GRAY}-----------------------------------------------------------------------------------------${RESET}"

    INDEX=1
    for item in "${CERTS_LIST[@]}"; do
        IFS='|' read -r d_name d_days d_panel d_file <<< "$item"
        printf "%-4s %-65s %-15s\n" "[$INDEX]" "$d_name" "$d_panel"
        ((INDEX++))
    done

    echo
    echo -e "${GRAY}0) Cancel and Return${RESET}"
    echo
    read -r -p "Certificate ID [0=Cancel]: " CHOICE

    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -gt 0 ] && [ "$CHOICE" -le ${#CERTS_LIST[@]} ]; then
        SELECTED_INDEX=$((CHOICE - 1))
        IFS='|' read -r d_name d_days d_panel d_file <<< "${CERTS_LIST[$SELECTED_INDEX]}"
        
        echo
        warning "You are about to completely wipe: $d_name"
        read -r -p "Confirm deletion [y/N]: " confirm
        
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            progress_bar 15 "Purging $d_name from server..."
            
            certbot delete --cert-name "$d_name" --non-interactive >/dev/null 2>&1
            
            rm -rf "/etc/letsencrypt/live/$d_name" 2>/dev/null
            rm -rf "/etc/letsencrypt/archive/$d_name" 2>/dev/null
            rm -f "/etc/letsencrypt/renewal/$d_name.conf" 2>/dev/null
            
            rm -rf "/var/lib/rebecca/certs/$d_name" 2>/dev/null
            rm -rf "/var/lib/marzban/certs/$d_name" 2>/dev/null
            rm -rf "/var/lib/pasarguard/certs/$d_name" 2>/dev/null
            rm -rf "/var/lib/marzneshin/certs/$d_name" 2>/dev/null
            
            INSTALL_PATH=$(jq -r --arg d "$d_name" '.domains[] | select(.main_domain==$d) | .install_path' "$CONFIG_FILE" 2>/dev/null)
            if [[ ! -z "$INSTALL_PATH" && "$INSTALL_PATH" != "null" && -d "$INSTALL_PATH" ]]; then
                rm -rf "$INSTALL_PATH" 2>/dev/null
            fi

            TMP=$(jq --arg d "$d_name" '.domains |= map(select(.main_domain != $d))' "$CONFIG_FILE" 2>/dev/null)
            [[ ! -z "$TMP" ]] && echo "$TMP" > "$CONFIG_FILE"

            success "Domain $d_name completely obliterated from the server."
            log "DELETE" "Wiped domain $d_name"
        else
            info "Deletion cancelled."
        fi
    fi
    pause_screen
}

# =========================================================
# 5. HEALTH MONITOR
# =========================================================
health_monitor() {
    ui_header
    echo -e "${NEON_PINK}--- SYSTEM HEALTH MONITOR ---${RESET}"
    echo
    
    command -v certbot >/dev/null && success "Certbot: Installed" || error "Certbot: Missing"
    systemctl is-active cron >/dev/null 2>&1 && success "Cron: Active" || warning "Cron: Inactive"
    ping -c 1 google.com >/dev/null 2>&1 && success "Internet: Connected" || error "Internet: Disconnected"
    
    if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null ; then warning "Port 80: IN USE"
    else success "Port 80: Available"
    fi

    detect_webserver
    if [[ ! -z "$WEBSERVER" ]]; then success "Webserver: $WEBSERVER (Active)"
    else warning "Webserver: None Detected"
    fi

    pause_screen
}

# =========================================================
# 6. AUTO REPAIR
# =========================================================
auto_repair() {
    ui_header
    echo -e "${NEON_PINK}--- SYSTEM AUTO REPAIR ---${RESET}"
    read -r -p "Start system repair [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || return

    echo
    progress_bar 25 "Repairing System Packages..."
    apt --fix-broken install -y >/dev/null 2>&1
    
    detect_webserver
    [[ ! -z "$WEBSERVER" ]] && systemctl restart $WEBSERVER
    
    certbot renew --dry-run >/dev/null 2>&1
    
    success "Auto repair completed successfully."
    log "REPAIR" "Auto repair completed"
    pause_screen
}

# =========================================================
# 7. AUTO RENEW
# =========================================================
setup_auto_renew() {
    ui_header
    echo -e "${NEON_PINK}--- SMART AUTO RENEW ---${RESET}"
    echo -e "This will automatically renew certs and sync files to panels."
    read -r -p "Enable Auto-Renew [y/N]: " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        CRON_JOB="0 3 * * * certbot renew --quiet --deploy-hook \"/usr/local/bin/certmaster --sync\" >> $LOG_FILE 2>&1"
        crontab -l 2>/dev/null | grep -v "certmaster" | crontab -
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        success "Smart Auto-Renew is now Active."
        log "INFO" "Smart Auto-Renew Enabled"
    fi
    pause_screen
}

sync_certificates() {
    jq -c '.domains[]' "$CONFIG_FILE" | while read i; do
        DOMAIN=$(echo "$i" | jq -r '.main_domain')
        INSTALL_PATH=$(echo "$i" | jq -r '.install_path')
        if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
            mkdir -p "$INSTALL_PATH"
            cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$INSTALL_PATH/"
            cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$INSTALL_PATH/"
            chmod 644 "$INSTALL_PATH/fullchain.pem"
            chmod 600 "$INSTALL_PATH/privkey.pem"
            log "SYNC" "Synced SSL for $DOMAIN"
        fi
    done
    detect_webserver
    [[ ! -z "$WEBSERVER" ]] && systemctl reload $WEBSERVER >/dev/null 2>&1
}

if [[ "$1" == "--sync" ]]; then
    sync_certificates
    telegram_alert "🔄 CertMaster: Auto-Renew & Sync Hook Executed!"
    exit 0
fi

# =========================================================
# 8. DASHBOARD
# =========================================================
dashboard() {
    ui_header
    TOTAL=$(find /etc/letsencrypt/live -maxdepth 1 -type d 2>/dev/null | wc -l)
    [[ $TOTAL -gt 0 ]] && TOTAL=$((TOTAL - 1))
    
    echo -e "${NEON_PINK}--- LIVE DASHBOARD ---${RESET}"
    echo
    echo -e "${CYAN}📦 Managed Certificates:${RESET} $TOTAL"
    echo -e "${CYAN}⚡ Software Version:${RESET}     v$VERSION"
    echo -e "${CYAN}📄 Log File Path:${RESET}        $LOG_FILE"
    pause_screen
}

# =========================================================
# 9. UPDATE SCRIPT
# =========================================================
update_script() {
    ui_header
    echo -e "${NEON_PINK}--- SOFTWARE UPDATE ---${RESET}"
    read -r -p "Install latest update [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || return

    echo
    progress_bar 20 "Connecting to GitHub..."
    HTTP_CODE=$(curl -H 'Cache-Control: no-cache' -s -w "%{http_code}" -o /tmp/certmaster_new.sh "$UPDATE_URL")
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        mv /tmp/certmaster_new.sh /opt/CertMaster-Pro/certmaster.sh
        chmod +x /opt/CertMaster-Pro/certmaster.sh
        cp /opt/CertMaster-Pro/certmaster.sh /usr/local/bin/certmaster
        chmod +x /usr/local/bin/certmaster
        
        success "CertMaster updated successfully! Run 'certmaster' to see changes."
        exit 0
    else
        error "Update failed. GitHub returned HTTP Code: $HTTP_CODE"
    fi
    pause_screen
}

# =========================================================
# MAIN MENU
# =========================================================
main_menu() {
    while true; do
        ui_header

        echo -e "  ${GRAY}MAIN MENU${RESET}"
        echo -e "  ${DARK_GRAY}Choose a module to manage your SSL infrastructure${RESET}"
        echo

        menu_item "1"  "Install SSL"           "Issue & install a certificate"
        menu_item "2"  "Wildcard SSL"          "Generate wildcard certificates"
        menu_item "3"  "Manage Certificates"   "Inspect, list & manage SSL"
        menu_item "4"  "Delete / Wipe SSL"     "Remove certificate data"
        menu_item "5"  "Health Check"          "Diagnose server & SSL health"
        menu_item "6"  "Auto Repair"           "Repair SSL & system services"
        menu_item "7"  "Auto Renew"            "Configure automatic renewal"
        menu_item "8"  "Live Dashboard"        "View live CertMaster status"
        menu_item "9"  "Update"                "Update from GitHub"

        echo
        printf "  ${BRIGHT_RED}0)${RESET} ${WHITE}Exit${RESET}  ${GRAY}Close CertMaster safely${RESET}\n"
        echo
        read -r -p "Select option [0-9]: " OPTION

        case $OPTION in
            1) install_certificate ;;
            2) wildcard_ssl ;;
            3) list_certificates ;;
            4) delete_certificate ;;
            5) health_monitor ;;
            6) auto_repair ;;
            7) setup_auto_renew ;;
            8) dashboard ;;
            9) update_script ;;
            0) clear; exit 0 ;;
            *) error "Invalid option. Please select a number from 0 to 9."; sleep 1 ;;
        esac
    done
}

# =========================================================
# START
# =========================================================
main_menu
