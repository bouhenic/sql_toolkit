# SQL Toolkit

Un outil pédagogique pour l'apprentissage et la compréhension des injections SQL. Ce projet sert de support de cours pour enseigner :
* Les mécanismes des injections SQL
* Les techniques de détection
* Les bonnes pratiques de sécurité
* Les méthodes de prévention

## 🎓 Contexte éducatif

Ce toolkit est conçu comme matériel pédagogique pour les cours de sécurité informatique. Il permet aux étudiants de :
* Comprendre comment fonctionnent les injections SQL dans un environnement contrôlé
* Apprendre à identifier les vulnérabilités SQL
* Pratiquer la sécurisation des requêtes SQL
* Se familiariser avec les outils d'audit de sécurité

## 📁 Structure du projet

```
sql_toolkit/
├── config/         # Configurations pour les différents scénarios pédagogiques
├── modules/        # Modules d'apprentissage et exercices
└── sqlmap.py      # Script principal
```

## 🔧 Installation

```bash
# Cloner le dépôt
git clone https://github.com/bouhenic/sql_toolkit.git
cd sql_toolkit

# Donner les droits d'exécution
chmod +x sqlmap.py
```

## 🚀 Utilisation dans un cadre pédagogique

```bash
./sqlmap.py
```

## ⚠️ Avertissement pédagogique

Cet outil est exclusivement destiné à un usage éducatif dans le cadre d'un cours sur la sécurité des applications web. Les techniques présentées ne doivent être pratiquées que dans l'environnement de test fourni. Toute utilisation sur des systèmes réels sans autorisation est interdite.
