#!/bin/bash

# Vérification si Docker est installé
if ! [ -x "$(command -v docker)" ]; then
  echo "Erreur : Docker n'est pas installé. Veuillez l'installer et réessayer." >&2
  exit 1
fi

# Vérification si Composer est installé
if ! [ -x "$(command -v composer)" ]; then
  echo "Erreur : Composer n'est pas installé. Veuillez l'installer et réessayer." >&2
  exit 1
fi

# Demander le chemin d'installation ou utiliser le dossier courant par défaut
read -p "Entrez le chemin d'installation (par défaut : dossier courant) : " install_path
install_path=${install_path:-$(pwd)}

# Créer le dossier d'installation s'il n'existe pas
if [ ! -d "$install_path" ]; then
  mkdir -p "$install_path"
fi

# Demander le nom de l'application
read -p "Entrez le nom de l'application (par défaut : laravel-app) : " app_name
app_name=${app_name:-'laravel-app'}

# Demander la version de Laravel
read -p "Choisissez la version de Laravel (ex : 10.x ou laissez vide pour la version par défaut) : " laravel_version

# Télécharger Laravel dans un dossier temporaire pour récupérer les exigences
temp_dir=$(mktemp -d)
if [ -z "$laravel_version" ]; then
  composer create-project laravel/laravel "$temp_dir" --quiet
else
  composer create-project laravel/laravel:"$laravel_version" "$temp_dir" --quiet
fi

# Détecter la version PHP requise à partir du composer.json de Laravel
raw_php_version=$(awk -F'"' '/"php":/ {print $4}' "$temp_dir/composer.json" | head -1)

# Nettoyer la version pour enlever les caractères spéciaux (^, ~)
required_php=$(echo "$raw_php_version" | sed 's/[^0-9\.]//g')

# Afficher la version détectée ou une valeur par défaut
if [ -n "$required_php" ]; then
  echo "Laravel nécessite PHP version $required_php"
else
  echo "Impossible de détecter la version PHP requise. Utilisation de PHP 8.2 par défaut."
  required_php="8.2"
fi

# Supprimer le dossier temporaire
rm -rf "$temp_dir"

# Demander le type de base de données
echo "Choisissez la base de données :"
echo "1. MySQL"
echo "2. PostgreSQL"
read -p "Votre choix (1 ou 2) : " db_choice

if [ "$db_choice" == "1" ]; then
  db_type="mysql"
  db_image="mysql:8.0"
  db_port="3306"
  db_env="MYSQL_ROOT_PASSWORD=root"
elif [ "$db_choice" == "2" ]; then
  db_type="postgres"
  db_image="postgres:14"
  db_port="5432"
  db_env="  PGPASSWORD: '\${DB_PASSWORD:-root}'
        POSTGRES_MULTIPLE_DATABASES: '\${DB_DATABASE:-$app_name},\${DB_DATABASE_TEST:-$app_name-test}'
        POSTGRES_USER: '\${DB_USERNAME:-admin}'
        POSTGRES_PASSWORD: '\${DB_PASSWORD:-root}'"
else
  echo "Choix invalide. Par défaut, MySQL sera utilisé."
  db_type="mysql"
  db_image="mysql:8.0"
  db_port="3306"
  db_env="MYSQL_ROOT_PASSWORD=root"
fi

# Télécharger Laravel
echo "Téléchargement de Laravel..."
if [ -z "$laravel_version" ]; then
  composer create-project laravel/laravel "$install_path/$app_name"
else
  composer create-project laravel/laravel:"$laravel_version" "$install_path/$app_name"
fi

# Adapter le fichier .env
env_file="$install_path/$app_name/.env"
if [ -f "$env_file" ]; then
  echo "Configuration du fichier .env..."

  # Fonction pour gérer chaque variable
  update_or_add_env_var() {
    local var_name="$1"
    local var_value="$2"
    local file="$3"

    # Si la variable est commentée, décommenter et mettre à jour
    if grep -q "^#\s*${var_name}=" "$file"; then
      # sed -i.bak "s/^#\s*${var_name}=.*/${var_name}=${var_value}/" "$file"
      sed -i '' "s/^[[:space:]]*# ${var_name}=.*/${var_name}=${var_value}/" "$file"
    # Si la variable existe mais n'est pas commentée, simplement mettre à jour
    elif grep -q "^${var_name}=" "$file"; then
      sed -i.bak "s/^${var_name}=.*/${var_name}=${var_value}/" "$file"
    # Si la variable n'existe pas, l'ajouter
    else
      echo "${var_name}=${var_value}" >> "$file"
    fi
  }

  # Mettre à jour ou ajouter chaque variable
  update_or_add_env_var "APP_NAME" "$app_name" "$env_file"
  update_or_add_env_var "APP_LOCALE" "fr" "$env_file"
  update_or_add_env_var "APP_FALLBACK_LOCALE" "fr" "$env_file"
  update_or_add_env_var "APP_FAKER_LOCALE" "fr_FR" "$env_file"
  update_or_add_env_var "DB_CONNECTION" "$db_type" "$env_file"
  update_or_add_env_var "DB_HOST" "db" "$env_file"
  update_or_add_env_var "DB_PORT" "$db_port" "$env_file"
  update_or_add_env_var "DB_DATABASE" "laravel" "$env_file"
  update_or_add_env_var "DB_DATABASE_TEST" "laravel-test" "$env_file"
  update_or_add_env_var "DB_USERNAME" "root" "$env_file"
  update_or_add_env_var "DB_PASSWORD" "root" "$env_file"
  update_or_add_env_var "DOCKER_APP_PORT" "8000" "$env_file"

  echo "Fichier .env mis à jour avec succès."
else
  echo "Erreur : fichier .env introuvable dans $install_path/$app_name."
  exit 1
fi


# Se déplacer dans le dossier Laravel
cd "$install_path/$app_name" || exit

mkdir pg-init-scripts
cd "pg-init-scripts" || exit
cat <<EOL > create-multiple-postgresql-databases.sh
#!/bin/bash

set -e
set -u

function create_user_and_database() {
	local database=$1
	echo "  Creating user and database '$database'"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
	    CREATE USER $database;
	    CREATE DATABASE $database;
	    GRANT ALL PRIVILEGES ON DATABASE $database TO $database;
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
	echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
	for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
		create_user_and_database $db
	done
	echo "Multiple databases created"
fi
EOL

cd ..

# Créer un fichier docker-compose.yml
cat <<EOL > docker-compose.yml
services:

  app:
    build:
      context: .
      args:
        PHP_VERSION: "$required_php"
    volumes:
      - .:/var/www/html
    ports:
      - "${DOCKER_APP_PORT:-8000}:${DOCKER_APP_PORT:-8000}"
    depends_on:
      - db
  db:
    image: $db_image
    ports:
      - '${FORWARD_DB_PORT:-$db_port}:$db_port'
    environment:
      $db_env
    volumes:
      - './pg-init-scripts:/docker-entrypoint-initdb.d'
      - 'pgsql-$app_name:/var/lib/postgresql/data'
    healthcheck:
      test: [ "CMD", "pg_isready", "-q", "-d", "${DB_DATABASE}", "-U", "${DB_USERNAME}" ]

volumes:
  pgsql-$app_name:
    driver: local
EOL

# Créer un Dockerfile avec la version correcte de PHP
cat <<EOL > Dockerfile
ARG PHP_VERSION
FROM php:\${PHP_VERSION}-cli

LABEL maintainer="Belkaid Nohame <belkaid.nohame@gmail.com>" description="php:$required_php-cli optimisé pour Laravel"

RUN apt-get update && apt-get install -y unzip curl libzip-dev libpng-dev libonig-dev libxml2-dev libpq-dev && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-install pdo pdo_mysql pdo_pgsql mbstring zip exif pcntl

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY . /var/www/html/
WORKDIR /var/www/html

RUN composer install --no-interaction --optimize-autoloader
RUN echo "alias ll='ls -lisa'" >> ~/.bashrc

CMD ["php", "artisan", "serve", "--host=0.0.0.0"]
EOL

# Créer un fichier docker.sh
cat <<EOL > docker.sh
#!/usr/bin/env sh

# Variables globales
DOCKER_APP_PORT=\${DOCKER_APP_PORT:-8080}
APP_NAME=\${APP_NAME:-default-app}
WORKDIR='/var/www/html'

source /dev/stdin <<< "\$(curl -fsSL https://raw.githubusercontent.com/Nohame/shared-scripts/main/mac-sh/colors-messages.sh)"

# Vérification du fichier .env
check_env_vars() {
 env_sample_file=".env.example"
 env_file=".env"

 # Vérifie que les deux fichiers existent
 if [ ! -f "\$env_sample_file" ]; then
   display_error "Erreur : le fichier \$env_sample_file n'existe pas."
   return 1
 fi

 if [ ! -f "\$env_file" ]; then
   display_error "Erreur : le fichier \$env_file n'existe pas."
   return 1
 fi

 # Parcours des variables dans .env.example
 missing_vars=0
 while IFS= read -r line || [ -n "\$line" ]; do
   # Ignore les lignes vides ou les commentaires
   line=\$(echo "\$line" | xargs)
   if [[ -z "\$line" || "\$line" =~ ^# ]]; then
     continue
   fi

   # Extrait le nom de la variable
   var_name=\$(echo "\$line" | cut -d'=' -f1)

   # Vérifie si la variable est présente dans .env
   if ! grep -q "^\$var_name=" "\$env_file"; then
     display_error "Variable manquante dans \$env_file : \$var_name"
     missing_vars=\$((missing_vars + 1))
   fi
 done < "\$env_sample_file"

 # Affiche un message final
 if [ \$missing_vars -eq 0 ]; then
   display "Toutes les variables de \$env_sample_file sont présentes dans \$env_file."
   return 0
 else
   display_error "\$missing_vars variable(s) manquante(s) dans \$env_file."
   return 1
 fi
}

# Vérification de Docker Compose
detect_docker_compose() {
 if command -v docker compose > /dev/null 2>&1; then
   echo "docker compose"
 elif command -v docker-compose > /dev/null 2>&1; then
   echo "docker-compose"
 else
   display_error "Erreur : ni 'docker compose' ni 'docker-compose' n'est installé."
   exit 1
 fi
}

# Affichage des commandes disponibles
usage() {
 echo ""
 echo "################ \${YELLOW}AVAILABLE COMMANDS\${RESET_COLOR} ################"
 echo ""
 echo "start      - Démarrer l'environnement Docker"
 echo "stop       - Arrêter l'environnement Docker"
 echo "restart    - Redémarrer l'environnement Docker"
 echo "status     - Afficher l'état des conteneurs Docker"
 echo "ssh        - Se connecter en SSH au conteneur de l'application"
 echo "sql        - Se connecter à la base de données"
 echo ""
 exit 1
}

# Vérification et traitement des actions
handle_action() {
 local action=\$1
 local DOCKER_COMPOSE
 DOCKER_COMPOSE=\$(detect_docker_compose)

 case \$action in
   start)
     \$DOCKER_COMPOSE up -d
     display "Docker démarré sur http://localhost:\$DOCKER_APP_PORT"
     ;;
   stop)
     \$DOCKER_COMPOSE down
     display "Docker arrêté."
     ;;
   restart)
     \$DOCKER_COMPOSE down
     \$DOCKER_COMPOSE up -d
     display "Docker redémarré sur http://localhost:\$DOCKER_APP_PORT"
     ;;
   status)
     \$DOCKER_COMPOSE ps
     ;;
   ssh)
     docker exec -e COLUMNS="`tput cols`" -e LINES="`tput lines`" -ti "\$APP_NAME-app-1" bash -c "cd \$WORKDIR && /bin/bash"
     ;;
   sql)
     docker exec -ti \$APP_NAME-db-1 psql -U "\$DB_USERNAME" -d "\$DB_DATABASE"
     ;;
   *)
     display_error "Action inconnue : \$action"
     usage
     ;;
 esac
}

# Vérification initiale des fichiers et des variables
if [ ! -f .env ]; then
 display_error "Erreur : le fichier .env est manquant. Veuillez le configurer avant de démarrer l'environnement."
 exit 1
fi

source .env

if ! check_env_vars; then
 display_error "Le script est arrêté car des variables sont manquantes dans .env."
 exit 1
fi

# Exécuter l'action
action=\$1
if [ -z "\$action" ]; then
 usage
else
 handle_action "\$action"
fi

EOL

chmod +x docker.sh

# Lancer Docker
docker compose up -d

# Vérifier si les conteneurs sont bien démarrés
if [ $? -ne 0 ]; then
  echo "Erreur : Les conteneurs Docker n'ont pas pu être démarrés." >&2
  exit 1
fi

# Afficher les informations
echo "Laravel a été installé avec succès dans le dossier : $install_path/$app_name"
echo "Application disponible à l'adresse : http://localhost:8000"
echo "Base de données : $db_type sur le port $db_port."
