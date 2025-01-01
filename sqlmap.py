#!/bin/bash
# Import des configurations
source "$(dirname "${BASH_SOURCE[0]}")/config/globals.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config/banner.sh"

# Menu principal
main_menu() {
    while true; do
        echo -e "\n${BLUE}[+] Menu Principal${DEFAULT}"
        echo "1. Configurer la cible"
        echo "2. Afficher la configuration"
        echo "3. Extraire les bases de données"
        echo "4. Extraire les tables"
        echo "5. Extraire les colonnes"
        echo "6. Extraire les données"
        echo "7. Quitter"
        
        read -p $'\n\e[33m[?]\e[0m Choix: ' choice
        
        case $choice in
            1) 
                configure_target
                ;;
            2) 
                display_config
                ;;
            3)
                source "modules/databases.sh"
                extract_databases
                ;;
            4)
                if [[ ${#FOUND_DATABASES[@]} -eq 0 ]]; then
                    sql_log "ERROR" "Aucune base trouvée. Lancez d'abord l'extraction des bases."
                    continue
                fi
                source "modules/tables.sh"
                select_database_and_extract_tables
                ;;
            5)
                if [[ ${#FOUND_TABLES[@]} -eq 0 ]]; then
                    sql_log "ERROR" "Aucune table trouvée. Lancez d'abord l'extraction des tables."
                    continue
                fi
                source "modules/columns.sh"
                select_table_and_extract_columns
                ;;
            6)
                if [[ ${#FOUND_COLUMNS[@]} -eq 0 ]]; then
                    sql_log "ERROR" "Aucune colonne trouvée. Lancez d'abord l'extraction des colonnes."
                    continue
                fi
                source "modules/data.sh"
                select_columns_and_extract_data
                ;;
            7) 
                echo -e "${GREEN}[+] Au revoir !${DEFAULT}"
                exit 0 
                ;;
            *)
                echo -e "${RED}[!] Option invalide${DEFAULT}"
                ;;
        esac
    done
}

# Sélection de la base de données
select_database_and_extract_tables() {
    echo -e "\n${BLUE}[+] Bases disponibles :${DEFAULT}"
    select db in "${FOUND_DATABASES[@]}"; do
        if [[ -n $db ]]; then
            CURRENT_DATABASE="$db"
            extract_tables "$db"
            break
        fi
        echo "Sélection invalide"
    done
}

# Sélection de la table
select_table_and_extract_columns() {
    echo -e "\n${BLUE}[+] Tables disponibles :${DEFAULT}"
    select table in "${FOUND_TABLES[@]}"; do
        if [[ -n $table ]]; then
            CURRENT_TABLE="$table"
            extract_columns "$CURRENT_DATABASE" "$table"
            break
        fi
        echo "Sélection invalide"
    done
}

# Sélection des colonnes
select_columns_and_extract_data() {
    echo -e "\n${BLUE}[+] Colonnes disponibles :${DEFAULT}"
    
    # Afficher les colonnes numérotées pour l'utilisateur
    for i in "${!FOUND_COLUMNS[@]}"; do
        echo "$((i + 1)). ${FOUND_COLUMNS[$i]}"
    done

    echo -e "\n${YELLOW}Sélectionnez les colonnes (séparées par des espaces) :${DEFAULT}"
    read -a selected_columns
    
    # Convertir les numéros en noms de colonnes et valider
    local final_columns=()
    for col_num in "${selected_columns[@]}"; do
        if [[ $col_num =~ ^[0-9]+$ ]] && [[ $col_num -ge 1 ]] && [[ $col_num -le ${#FOUND_COLUMNS[@]} ]]; then
            final_columns+=("${FOUND_COLUMNS[$((col_num - 1))]}")
        else
            sql_log "ERROR" "Numéro de colonne invalide: $col_num"
            return
        fi
    done

    # Vérifier que des colonnes ont été sélectionnées
    if [[ ${#final_columns[@]} -eq 0 ]]; then
        sql_log "ERROR" "Aucune colonne sélectionnée"
        return
    fi

    extract_data "$CURRENT_DATABASE" "$CURRENT_TABLE" "${final_columns[@]}"
}

# Démarrage
check_dependencies
load_config
display_banner
main_menu
