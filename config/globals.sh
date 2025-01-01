#!/bin/bash

# Configuration fichier global
GLOBAL_CONFIG_FILE="$HOME/.sqlmap/config"

# Couleurs ANSI
DEFAULT='\033[0m'
BOLD='\033[1m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
BRIGHT_BLUE='\033[0;94m'
BRIGHT_CYAN='\033[0;96m'

# Vérification dépendances
check_dependencies() {
    local deps=("curl" "jq" "bc")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${RED}[!] Erreur: $dep n'est pas installé${DEFAULT}"
            exit 1
        fi
    done
}

# Chargement configuration
load_config() {
    if [[ -f "$GLOBAL_CONFIG_FILE" ]]; then
        source "$GLOBAL_CONFIG_FILE"
    else
        configure_target
    fi
}

# Configuration interactive
configure_target() {
    echo -e "\n${BLUE}[+] Configuration de la cible${DEFAULT}"
    
    # URL
    while true; do
        read -p $'\e[33m[?]\e[0m URL de la cible: ' TARGET_URL
        if [[ $TARGET_URL =~ ^https?:// ]]; then
            break
        else
            echo -e "${RED}[!] URL invalide${DEFAULT}"
        fi
    done

    # Méthode HTTP
    echo -e "\n${YELLOW}[?] Méthode HTTP:${DEFAULT}"
    select HTTP_METHOD in "GET" "POST" "PUT" "DELETE"; do
        [[ -n $HTTP_METHOD ]] && break
    done

    # Type contenu
    echo -e "\n${YELLOW}[?] Type de contenu:${DEFAULT}"
    select CONTENT_TYPE in "application/json" "application/x-www-form-urlencoded" "multipart/form-data"; do
        [[ -n $CONTENT_TYPE ]] && break
    done

    # Paramètres auth
    read -p "Champ utilisateur: " USERNAME_FIELD
    read -p "Champ mot de passe: " PASSWORD_FIELD

    # Paramètres injection
    read -p "Délai entre requêtes (s) [1]: " REQUEST_DELAY
    read -p "Seuil de détection (s) [5]: " THRESHOLD
    read -p "Tentatives max [10]: " MAX_ATTEMPTS

    REQUEST_DELAY=${REQUEST_DELAY:-1}
    THRESHOLD=${THRESHOLD:-5}
    MAX_ATTEMPTS=${MAX_ATTEMPTS:-10}

    save_config
}

# Sauvegarde configuration
save_config() {
    mkdir -p "$(dirname "$GLOBAL_CONFIG_FILE")"
    cat > "$GLOBAL_CONFIG_FILE" << EOF
# Configuration SQL Injection Toolkit - $(date)
export TARGET_URL="$TARGET_URL"
export HTTP_METHOD="$HTTP_METHOD"
export CONTENT_TYPE="$CONTENT_TYPE"
export USERNAME_FIELD="$USERNAME_FIELD"
export PASSWORD_FIELD="$PASSWORD_FIELD"
export REQUEST_DELAY="$REQUEST_DELAY"
export THRESHOLD="$THRESHOLD"
export MAX_ATTEMPTS="$MAX_ATTEMPTS"
export MAX_LENGTH=30
export CHARSET="abcdefghijklmnopqrstuvwxyz0123456789_"
EOF
}

# Construction requête
build_request() {
    local payload=$1
    case $CONTENT_TYPE in
        "application/json")
            echo "{\"$USERNAME_FIELD\": \"$payload\", \"$PASSWORD_FIELD\": \"pass\"}"
            ;;
        "application/x-www-form-urlencoded")
            echo "$USERNAME_FIELD=$payload&$PASSWORD_FIELD=pass"
            ;;
        "multipart/form-data")
            echo "--boundary
Content-Disposition: form-data; name=\"$USERNAME_FIELD\"

$payload
--boundary
Content-Disposition: form-data; name=\"$PASSWORD_FIELD\"

pass
--boundary--"
            ;;
    esac
}

# Envoi requête
send_request() {
    local payload=$1
    local data=$(build_request "$payload")
    local headers=(-H "Content-Type: $CONTENT_TYPE")
    [[ $CONTENT_TYPE == "multipart/form-data" ]] && headers+=(-H "Content-Type: multipart/form-data; boundary=boundary")

    curl -s -X "$HTTP_METHOD" "${headers[@]}" -d "$data" "$TARGET_URL"
}

# Test injection
test_injection() {
    local injection=$1
    local start=$(date +%s.%N)
    send_request "$injection" >/dev/null
    local end=$(date +%s.%N)
    echo "$(echo "$end - $start" | bc -l)"
}

# Animation chargement
loading_animation() {
    local chars="◐◓◑◒"
    local delay=0.1
    local text="$1"
    for (( i=0; i<${#chars}; i++ )); do
        echo -en "\r${CYAN}[${chars:$i:1}]${DEFAULT} $text"
        sleep $delay
    done
    echo -en "\r${GREEN}[◆]${DEFAULT} $text\n"
}

# Logs
sql_log() {
    local type=$1
    local message=$2
    local timestamp=$(date '+%H:%M:%S')
    
    case $type in
        "INFO") echo -e "${GREEN}[SQL]${DEFAULT} ${timestamp} - ${message}" ;;
        "WARNING") echo -e "${YELLOW}[WARN]${DEFAULT} ${timestamp} - ${message}" ;;
        "ERROR") echo -e "${RED}[ERR]${DEFAULT} ${timestamp} - ${message}" ;;
        "DEBUG") echo -e "${CYAN}[DBG]${DEFAULT} ${timestamp} - ${message}" ;;
        "QUERY") echo -e "${MAGENTA}[QRY]${DEFAULT} ${timestamp} - ${message}" ;;
    esac
}

# Affichage configuration
display_config() {
    echo -e "\n${BLUE}[+] Configuration actuelle${DEFAULT}"
    echo -e "${CYAN}URL:${DEFAULT} $TARGET_URL"
    echo -e "${CYAN}Méthode:${DEFAULT} $HTTP_METHOD"
    echo -e "${CYAN}Type:${DEFAULT} $CONTENT_TYPE"
    echo -e "${CYAN}Champ user:${DEFAULT} $USERNAME_FIELD"
    echo -e "${CYAN}Champ pass:${DEFAULT} $PASSWORD_FIELD"
    echo -e "${CYAN}Délai:${DEFAULT} ${REQUEST_DELAY}s"
    echo -e "${CYAN}Seuil:${DEFAULT} ${THRESHOLD}s"
    echo -e "${CYAN}Max tentatives:${DEFAULT} $MAX_ATTEMPTS"
}
