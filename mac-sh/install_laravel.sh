#!/bin/bash

# Charger le script distant pour les couleurs et les messages
source /dev/stdin <<< "$(curl -fsSL https://raw.githubusercontent.com/Nohame/shared-scripts/main/mac-sh/colors-messages.sh)"

# === Vérification de la disponibilité de Composer ===
function check_composer() {
    if ! command -v composer &> /dev/null; then
        display_red "Composer n'est pas installé ou n'est pas dans le PATH. Installez Composer avant de continuer."
        exit 1
    else
        display_green "Composer est disponible."
    fi
}

# === Installation de Laravel Installer ===
function install_laravel_installer() {
  echo ""
    if ! command -v laravel &> /dev/null; then
        display_green "Installation de Laravel Installer..."
        composer global require laravel/installer || { display_red "Échec de l'installation de Laravel Installer."; exit 1; }

        # Ajouter le dossier global de Composer au PATH si nécessaire
        COMPOSER_BIN_PATH="$HOME/.composer/vendor/bin"
        if [[ ":$PATH:" != *":$COMPOSER_BIN_PATH:"* ]]; then
            display_green "Ajout de Composer global bin au PATH..."
            export PATH="$PATH:$COMPOSER_BIN_PATH"
            echo "export PATH=\"\$PATH:$COMPOSER_BIN_PATH\"" >> ~/.bashrc
            source ~/.bashrc
        fi
    else
        display_green "Laravel Installer est déjà installé."
    fi
}

# === Demander les détails du projet ===
function ask_project_details() {
    echo ""
    read -p "Entrez le nom du projet Laravel que vous souhaitez créer : " PROJECT_NAME
    if [ -z "$PROJECT_NAME" ]; then
        display_red "Le nom du projet ne peut pas être vide. Relancez le script et entrez un nom valide."
        exit 1
    fi

    display_green "Choisissez le type de projet Laravel à créer :"
    echo "1. Projet standard (par défaut)"
    echo "2. Projet optimisé pour une API REST"
    read -p "Entrez votre choix (1 ou 2) : " PROJECT_TYPE

    read -p "Souhaitez-vous une version dockerisée du projet ? (y/n) : " DOCKERIZE
}

# === Création d'un projet Laravel ===
function create_laravel_project() {
   echo ""
    if [ "$PROJECT_TYPE" == "2" ]; then
        display_green "Création d'un projet optimisé pour une API REST : $PROJECT_NAME..."
        laravel new "$PROJECT_NAME" --api || { display_red "Échec de la création du projet Laravel."; exit 1; }
    else
        display_green "Création d'un projet Laravel standard : $PROJECT_NAME..."
        laravel new "$PROJECT_NAME" || { display_red "Échec de la création du projet Laravel."; exit 1; }
    fi
    cd "$PROJECT_NAME" || { display_red "Impossible de se déplacer dans le répertoire du projet."; exit 1; }
}

# === Configuration d'une API REST ===
function configure_api_project() {
   echo ""
    if [ "$PROJECT_TYPE" == "2" ]; then
        display_green "Configuration d'une API REST..."

        # Modifier la route par défaut
        cat <<EOL > routes/web.php
<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json(
      ["message" => "Bienvenue sur l'API $PROJECT_NAME ! (example: /api/example)"],
      200,
      [],
      JSON_UNESCAPED_SLASHES
    );
});
EOL

        # Suppression des fichiers inutiles pour une API REST
        rm -rf resources/views public/css public/js public/images

        # Création d'un contrôleur API
        php artisan make:controller Api/ExampleController --api

        # Ajouter des routes API
        echo "use App\Http\Controllers\Api\ExampleController;" >> routes/api.php
        echo "Route::get('/example', [ExampleController::class, 'index']);" >> routes/api.php

        # Modifier le contrôleur
        cat <<EOL > app/Http/Controllers/Api/ExampleController.php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;

class ExampleController extends Controller
{
    public function index()
    {
        return response()->json(['message' => 'Hello, this is your API!']);
    }
}
EOL
    fi
}

# === Générer les fichiers Docker ===
function generate_docker_files() {
  echo ""
    if [ "$DOCKERIZE" == "y" ]; then
        display_green "Génération des fichiers Docker..."
        # Générer le Dockerfile
        cat <<EOL > Dockerfile
LABEL maintainer="Belkaid Nohame <belkaid.nohame@gmail.com>" description="PHP:8.1-fpm optimisé pour Laravel"

# Image de base
FROM php:8.1-fpm

# Installation des dépendances
RUN apt-get update && apt-get install -y \\
    curl zip unzip git libpq-dev \\
    && docker-php-ext-install pdo pdo_pgsql pdo_mysql

# Installation de Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/html
COPY . .
RUN composer install
EXPOSE 9000
CMD ["php-fpm"]
EOL

        # Générer docker-compose.yml
        cat <<EOL > docker-compose.yml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}_app
    working_dir: /var/www/html
    volumes:
      - .:/var/www/html
    ports:
      - 8000:8000
    environment:
      - APP_ENV=local
      - APP_DEBUG=true
    command: php artisan serve --host=0.0.0.0 --port=8000
EOL

        display_green "Les fichiers Dockerfile et docker-compose.yml ont été générés."
    fi
}

function create_docker_script() {
   echo ""
    if [ "$DOCKERIZE" == "y" ]; then
        display_green "Création du script docker.sh ..."
        cat <<EOL > docker.sh
#!/bin/bash

# === Variables globales ===
DIRNAME="\$(dirname "\$0")"
WORKDIR='/usr/src/myapp'
APP_ENV=local
DOCKER_APP="${PROJECT_NAME}"

# Charger le script distant pour les couleurs et les messages
source /dev/stdin <<< "\$(curl -fsSL https://raw.githubusercontent.com/Nohame/shared-scripts/main/mac-sh/colors-messages.sh)"

# === Fonction : Détecter docker-compose ===
detect_docker_compose() {
    if command -v docker compose > /dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    elif command -v docker-compose > /dev/null 2>&1; then
        DOCKER_COMPOSE="docker-compose"
    else
        display_error "Erreur : ni 'docker compose' ni 'docker-compose' n'est installé."
        exit 1
    fi
}

# === Fonction : Afficher les commandes disponibles ===
usage() {
    echo ""
    echo "################ \${YELLOW}AVAILABLE COMMANDS\${RESET_COLOR} ################"
    echo "start                         Lancer l'application avec Docker Compose"
    echo "stop                          Arrêter les conteneurs Docker Compose"
    echo "restart                       Redémarrer les conteneurs Docker Compose"
    echo "ssh                           Se connecter au conteneur de l'application"
    echo ""
    exit 1
}

# === Fonction : Démarrer Docker Compose ===
start_docker_compose() {
    detect_docker_compose
    \$DOCKER_COMPOSE up -d
    display_success "Docker Compose a démarré avec succès."
    \$DOCKER_COMPOSE logs --tail=0 --follow
}

# === Fonction : Arrêter Docker Compose ===
stop_docker_compose() {
    detect_docker_compose
    \$DOCKER_COMPOSE down
    display_success "Docker Compose a été arrêté."
}

# === Fonction : Redémarrer Docker Compose ===
restart_docker_compose() {
    stop_docker_compose
    start_docker_compose
}

# === Fonction : Accéder au conteneur via SSH ===
ssh_to_container() {
    detect_docker_compose
    docker exec -e COLUMNS="\$(tput cols)" -e LINES="\$(tput lines)" -ti \$DOCKER_APP bash -c "cd \$WORKDIR && /bin/bash"
}

# === Fonction principale ===
main() {
    action="\$1"

    case "\$action" in
        start) start_docker_compose ;;
        stop) stop_docker_compose ;;
        restart) restart_docker_compose ;;
        ssh) ssh_to_container ;;
        *) usage ;;
    esac
}

# Lancement
main "\$@"
EOL

        chmod +x docker.sh
        display_green "Le script docker.sh a été créé et rendu exécutable."
    fi
}

# === Lancer le serveur de développement ===
function launch_server() {
   echo ""
    if [ "$DOCKERIZE" == "y" ]; then
        display_green "Lancement de l'application avec Docker..."
        ./docker.sh start
    else
        display_green "Lancement du serveur de développement..."
        php artisan serve
    fi
}

# === Main ===
function main() {
    check_composer
    install_laravel_installer
    ask_project_details
    create_laravel_project
    configure_api_project
    generate_docker_files
    create_docker_script
    launch_server
}

# Exécuter le script principal
main