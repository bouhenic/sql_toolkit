#!/bin/bash

# Charge les variables et fonctions globales
source "$(dirname "${BASH_SOURCE[0]}")/globals.sh"

# Logo SQL CIEL 
display_sql_logo() {
   echo "███████╗ ██████╗ ██╗          ██████╗██╗███████╗██╗     "
   echo "██╔════╝██╔═══██╗██║         ██╔════╝██║██╔════╝██║     "
   echo "███████╗██║   ██║██║         ██║     ██║█████╗  ██║     "
   echo "╚════██║██║▄▄ ██║██║         ██║     ██║██╔══╝  ██║     "
   echo "███████║╚██████╔╝███████╗    ╚██████╗██║███████╗███████╗"
   echo "╚══════╝ ╚══▀▀═╝ ╚══════╝     ╚═════╝╚═╝╚══════╝╚══════╝"
}

# Bannière principale
display_banner() {
   # Nettoie l'écran
   clear

   # Affiche le titre
   echo -e "${BRIGHT_BLUE}"
   echo "╔══════════════════════════════════ SQL INJECTION TOOLKIT ═══════════════════════════════╗"
   echo -e "${DEFAULT}"

   # Affiche le logo
   echo -e "${BRIGHT_CYAN}${BOLD}"
   display_sql_logo
   echo -e "${DEFAULT}"

   # Affiche les informations système
   echo -e "${BLUE}"
   echo "╔═════════════════════════════ SYSTEM INFORMATION ══════════════════════════╗"
   echo "║                                                                           ║"
   printf "║  %-20s %-52s ║\n" "Version:" "v1.0.0"
   printf "║  %-20s %-52s ║\n" "Last Update:" "$(date '+%d-%m-%Y %H:%M:%S')"
   printf "║  %-20s %-52s ║\n" "Author:" "Samuel BOUHENIC"
   echo "║                                                                           ║"
   echo "╚═══════════════════════════════════════════════════════════════════════════╝"
   echo -e "${DEFAULT}\n"

   # Message d'avertissement
   echo -e "${RED}${BOLD}[!] Outil à but éducatif uniquement - Usage responsable requis${DEFAULT}\n"
}
