# =========================================================
# 2. WILDCARD SSL
# =========================================================
wildcard_ssl() {
    ui_header
    section_title "WILDCARD SSL" "Generate and install a wildcard certificate for your selected panel."

    # -----------------------------------------------------
    # PANEL SELECTION
    # -----------------------------------------------------
    echo -e "  ${CYAN}1)${RESET} ${WHITE}${BOLD}Pasarguard${RESET}  ${GRAY}/var/lib/pasarguard/certs${RESET}"
    echo -e "  ${CYAN}2)${RESET} ${WHITE}${BOLD}Marzban${RESET}     ${GRAY}/var/lib/marzban/certs${RESET}"
    echo -e "  ${CYAN}3)${RESET} ${WHITE}${BOLD}Rebecca${RESET}     ${GRAY}/var/lib/rebecca/certs${RESET}"
    echo -e "  ${CYAN}4)${RESET} ${WHITE}${BOLD}Custom${RESET}      ${GRAY}Custom certificate directory${RESET}"
    echo
    echo -e "  ${BRIGHT_RED}0)${RESET} ${GRAY}Back to main menu${RESET}"
    echo

    read -r -p "Select panel [0-4]: " panel_choice

    case "$panel_choice" in
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

            if [[ -z "$TARGET_BASE_DIR" || "$TARGET_BASE_DIR" != /* ]]; then
                error "Custom path must be an absolute path."
                pause_screen
                return
            fi

            PANEL_NAME="Custom"
            ;;

        *)
            error "Invalid panel choice."
            pause_screen
            return
            ;;
    esac

    # -----------------------------------------------------
    # SELECTED PANEL INFO
    # -----------------------------------------------------
    echo
    success "Selected panel: ${PANEL_NAME}"
    info "Certificate base path: ${TARGET_BASE_DIR}"
    echo

    # -----------------------------------------------------
    # DOMAIN INPUT
    # -----------------------------------------------------
    echo -e "${WHITE}${BOLD}WILDCARD DOMAIN${RESET}"
    echo -e "  ${GRAY}Enter the base domain without *.${RESET}"
    echo -e "  ${GRAY}Example: example.com${RESET}"
    echo

    read -r -p "Domain: " DOMAIN

    # Remove protocol
    DOMAIN="${DOMAIN#https://}"
    DOMAIN="${DOMAIN#http://}"

    # Remove wildcard prefix
    DOMAIN="${DOMAIN#*.}"

    # Remove path
    DOMAIN="${DOMAIN%%/*}"

    # Lowercase
    DOMAIN="${DOMAIN,,}"

    if [[ -z "$DOMAIN" ]]; then
        error "No domain entered."
        pause_screen
        return
    fi

    # -----------------------------------------------------
    # DOMAIN VALIDATION
    # -----------------------------------------------------
    if [[ ! "$DOMAIN" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]]; then
        error "Invalid domain: $DOMAIN"
        pause_screen
        return
    fi

    WILDCARD_DOMAIN="*.${DOMAIN}"

    # Certificate destination
    FINAL_PATH="${TARGET_BASE_DIR}/${DOMAIN}"
    CERT_FILE="${FINAL_PATH}/fullchain.pem"
    KEY_FILE="${FINAL_PATH}/privkey.pem"

    echo
    echo -e "${WHITE}${BOLD}CERTIFICATE TARGET${RESET}"
    echo -e "  ${GRAY}Panel:${RESET}       ${WHITE}${PANEL_NAME}${RESET}"
    echo -e "  ${GRAY}Base path:${RESET}   ${WHITE}${TARGET_BASE_DIR}${RESET}"
    echo -e "  ${GRAY}Domain:${RESET}      ${WHITE}${DOMAIN}${RESET}"
    echo -e "  ${GRAY}Wildcard:${RESET}    ${WHITE}${WILDCARD_DOMAIN}${RESET}"
    echo

    # -----------------------------------------------------
    # CLOUDFLARE CONFIG
    # -----------------------------------------------------
    CF_EMAIL=$(jq -r '.cloudflare_email // empty' "$CONFIG_FILE" 2>/dev/null)
    CF_KEY=$(jq -r '.cloudflare_api_key // empty' "$CONFIG_FILE" 2>/dev/null)

    if [[ -z "$CF_EMAIL" || -z "$CF_KEY" ]]; then

        echo -e "${WHITE}${BOLD}CLOUDFLARE DNS${RESET}"
        echo -e "  ${GRAY}Wildcard SSL requires DNS validation.${RESET}"
        echo

        read -r -p "Cloudflare Email: " CF_EMAIL
        read -r -s -p "Cloudflare API Key: " CF_KEY
        echo

        if [[ -z "$CF_EMAIL" || -z "$CF_KEY" ]]; then
            error "Cloudflare credentials cannot be empty."
            pause_screen
            return
        fi

        # Save credentials to CertMaster config
        TMP=$(jq \
            --arg e "$CF_EMAIL" \
            --arg k "$CF_KEY" \
            '.cloudflare_email=$e | .cloudflare_api_key=$k' \
            "$CONFIG_FILE" 2>/dev/null)

        if [[ -n "$TMP" && "$TMP" != "null" ]]; then
            echo "$TMP" > "$CONFIG_FILE"
            chmod 600 "$CONFIG_FILE"
        fi
    fi

    # -----------------------------------------------------
    # CREATE CLOUDFLARE CREDENTIAL FILE
    # -----------------------------------------------------
    CF_DIR="/root/.secrets"
    CF_CREDENTIALS="${CF_DIR}/cloudflare.ini"

    mkdir -p "$CF_DIR"

    cat > "$CF_CREDENTIALS" <<EOF
dns_cloudflare_email = ${CF_EMAIL}
dns_cloudflare_api_key = ${CF_KEY}
EOF

    chmod 600 "$CF_CREDENTIALS"

    # -----------------------------------------------------
    # CREATE DESTINATION
    # -----------------------------------------------------
    mkdir -p "$FINAL_PATH"

    # -----------------------------------------------------
    # INSTALL WILDCARD CERTIFICATE
    # -----------------------------------------------------
    echo
    progress_bar 25 "Requesting Wildcard SSL for ${DOMAIN}..."

    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials "$CF_CREDENTIALS" \
        --preferred-challenges dns-01 \
        --non-interactive \
        --agree-tos \
        --register-unsafely-without-email \
        -d "$DOMAIN" \
        -d "$WILDCARD_DOMAIN" \
        >/tmp/certmaster_wildcard.log 2>&1

    CERTBOT_STATUS=$?

    # -----------------------------------------------------
    # SUCCESS
    # -----------------------------------------------------
    if [[ $CERTBOT_STATUS -eq 0 ]]; then

        LETSENCRYPT_PATH="/etc/letsencrypt/live/${DOMAIN}"

        if [[ ! -f "${LETSENCRYPT_PATH}/fullchain.pem" ||
              ! -f "${LETSENCRYPT_PATH}/privkey.pem" ]]; then

            error "Certbot completed but certificate files were not found."
            echo
            echo -e "  ${GRAY}Expected:${RESET}"
            echo -e "  ${GRAY}${LETSENCRYPT_PATH}/fullchain.pem${RESET}"
            echo -e "  ${GRAY}${LETSENCRYPT_PATH}/privkey.pem${RESET}"
            pause_screen
            return
        fi

        # Copy certificate to selected panel
        cp -L \
            "${LETSENCRYPT_PATH}/fullchain.pem" \
            "${CERT_FILE}"

        cp -L \
            "${LETSENCRYPT_PATH}/privkey.pem" \
            "${KEY_FILE}"

        chmod 644 "$CERT_FILE"
        chmod 600 "$KEY_FILE"

        # -------------------------------------------------
        # SAVE TO CERTMASTER CONFIG
        # -------------------------------------------------
        if command -v jq >/dev/null 2>&1; then

            TMP=$(jq \
                --arg d "$DOMAIN" \
                --arg p "$FINAL_PATH" \
                --arg pn "$PANEL_NAME" \
                '
                .domains = (
                    (.domains // [])
                    | map(select(.main_domain != $d or .panel != $pn))
                    + [{
                        "main_domain": $d,
                        "install_path": $p,
                        "panel": $pn,
                        "wildcard": true
                    }]
                )
                ' \
                "$CONFIG_FILE" 2>/dev/null)

            if [[ -n "$TMP" && "$TMP" != "null" ]]; then
                echo "$TMP" > "$CONFIG_FILE"
                chmod 600 "$CONFIG_FILE"
            fi
        fi

        # -------------------------------------------------
        # SUCCESS SUMMARY
        # -------------------------------------------------
        echo
        section_title "WILDCARD SSL INSTALLED" "Certificate installation completed successfully."

        echo -e "  ${GRAY}Panel:${RESET}        ${WHITE}${PANEL_NAME}${RESET}"
        echo -e "  ${GRAY}Base path:${RESET}    ${WHITE}${TARGET_BASE_DIR}${RESET}"
        echo -e "  ${GRAY}Domain:${RESET}       ${WHITE}${DOMAIN}${RESET}"
        echo -e "  ${GRAY}Wildcard:${RESET}     ${WHITE}${WILDCARD_DOMAIN}${RESET}"
        echo
        echo -e "  ${GRAY}Certificate:${RESET}  ${GREEN}${CERT_FILE}${RESET}"
        echo -e "  ${GRAY}Private key:${RESET}  ${GREEN}${KEY_FILE}${RESET}"
        echo
        echo -e "  ${GREEN}●${RESET} Certificate: ${GREEN}SUCCESS${RESET}"
        echo -e "  ${GREEN}●${RESET} Panel:       ${GREEN}${PANEL_NAME}${RESET}"
        echo

        success "Wildcard SSL installed successfully."

        log "SUCCESS" \
            "Wildcard SSL installed for ${WILDCARD_DOMAIN} | Panel: ${PANEL_NAME} | Path: ${FINAL_PATH}"

        telegram_alert \
            "✅ CertMaster Wildcard SSL Installed
Domain: ${WILDCARD_DOMAIN}
Panel: ${PANEL_NAME}
Path: ${FINAL_PATH}"

    else

        # -------------------------------------------------
        # FAILURE
        # -------------------------------------------------
        error "Failed to generate Wildcard SSL."

        echo
        echo -e "  ${GRAY}Domain:${RESET} ${WHITE}${WILDCARD_DOMAIN}${RESET}"
        echo -e "  ${GRAY}Panel:${RESET}  ${WHITE}${PANEL_NAME}${RESET}"
        echo
        echo -e "  ${GRAY}Certbot log:${RESET}"
        echo -e "  ${GRAY}/tmp/certmaster_wildcard.log${RESET}"
        echo

        # Show useful certbot error
        if [[ -f /tmp/certmaster_wildcard.log ]]; then
            echo -e "${RED}--- CERTBOT ERROR ---${RESET}"
            tail -n 15 /tmp/certmaster_wildcard.log
            echo -e "${RED}---------------------${RESET}"
        fi

        log "ERROR" \
            "Wildcard SSL failed for ${WILDCARD_DOMAIN} | Panel: ${PANEL_NAME}"

    fi

    # -----------------------------------------------------
    # RETURN TO MAIN MENU
    # -----------------------------------------------------
    pause_screen
}
