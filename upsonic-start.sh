#!/bin/bash
set -e

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
UPSONIC_GREEN='\033[38;2;3;212;126m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Symbols
CHECK_MARK="${GREEN}✓${NC}"
CROSS_MARK="${RED}✗${NC}"
WARNING="${YELLOW}⚠${NC}"
INFO="${BLUE}ℹ${NC}"

# Banner
print_banner() {
    clear
    echo ""
    echo -e "${UPSONIC_GREEN}${BOLD}"
    cat << "EOF"
██╗   ██╗██████╗ ███████╗ ██████╗ ███╗   ██╗██╗ ██████╗
██║   ██║██╔══██╗██╔════╝██╔═══██╗████╗  ██║██║██╔════╝
██║   ██║██████╔╝███████╗██║   ██║██╔██╗ ██║██║██║
██║   ██║██╔═══╝ ╚════██║██║   ██║██║╚██╗██║██║██║
╚██████╔╝██║     ███████║╚██████╔╝██║ ╚████║██║╚██████╗
 ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝ ╚═════╝
EOF
    echo -e "${NC}"
    echo -e "${BOLD} █████╗  ██████╗ ███████╗███╗   ██╗████████╗ ██████╗ ███████╗${NC}"
    echo -e "${BOLD}██╔══██╗██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗██╔════╝${NC}"
    echo -e "${BOLD}███████║██║  ███╗█████╗  ██╔██╗ ██║   ██║   ██║   ██║███████╗${NC}"
    echo -e "${BOLD}██╔══██║██║   ██║██╔══╝  ██║╚██╗██║   ██║   ██║   ██║╚════██║${NC}"
    echo -e "${BOLD}██║  ██║╚██████╔╝███████╗██║ ╚████║   ██║   ╚██████╔╝███████║${NC}"
    echo -e "${BOLD}╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚══════╝${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Delete function
delete_platform() {
    print_banner
    echo -e "${RED}${BOLD}⚠  WARNING: DESTRUCTIVE OPERATION  ⚠${NC}"
    echo ""
    echo -e "${YELLOW}This will completely remove Upsonic Platform:${NC}"
    echo -e "  ${RED}•${NC} All Docker containers"
    echo -e "  ${RED}•${NC} All Docker volumes (including databases)"
    echo -e "  ${RED}•${NC} All Docker networks"
    echo -e "  ${RED}•${NC} Configuration files (.env)"
    echo ""
    echo -e "${RED}${BOLD}THIS ACTION CANNOT BE UNDONE!${NC}"
    echo ""

    if ! confirm "Are you absolutely sure you want to delete everything?" "n"; then
        print_info "Deletion cancelled"
        exit 0
    fi

    echo ""
    echo -e "${YELLOW}Last chance to cancel!${NC}"
    if ! confirm "Type 'yes' to confirm deletion" "n"; then
        print_info "Deletion cancelled"
        exit 0
    fi

    print_step "Deleting Upsonic Platform"

    # Find agent containers
    print_info "Finding deployed agent containers..."
    AGENT_CONTAINERS=$(docker ps -a --filter "name=upsonic-" --format "{{.Names}}" | grep -v -E "upsonic-api|upsonic-db|upsonic-redis|upsonic-celery|ams-project|ams-db" || true)

    if [ -n "$AGENT_CONTAINERS" ]; then
        echo ""
        echo -e "${YELLOW}${BOLD}The following agent containers will be deleted:${NC}"
        echo ""
        echo "$AGENT_CONTAINERS" | while read container; do
            echo -e "  ${RED}•${NC} $container"
        done
        echo ""

        if ! confirm "Delete these agent containers?" "y"; then
            print_info "Skipping agent containers deletion"
            AGENT_CONTAINERS=""
        fi
    else
        print_info "No agent containers found"
    fi

    # Stop and remove Platform containers
    print_info "Stopping Platform containers..."
    if [ -f "compose-demo.yml" ]; then
        docker compose -f compose-demo.yml down --remove-orphans 2>/dev/null || true
    fi
    if [ -f "docker-compose.yml" ]; then
        docker compose -f docker-compose.yml down --remove-orphans 2>/dev/null || true
    fi
    print_success "Platform containers stopped"

    # Stop and remove agent containers
    if [ -n "$AGENT_CONTAINERS" ]; then
        print_info "Stopping and removing agent containers..."
        echo "$AGENT_CONTAINERS" | while read container; do
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        done
        print_success "Agent containers removed"
    fi

    # Remove volumes
    print_info "Removing volumes..."
    docker volume rm platform_upsonic-db-data 2>/dev/null || true
    docker volume rm platform_redis_data 2>/dev/null || true
    docker volume rm platform_ams-db-data 2>/dev/null || true
    docker volume rm platform_ams-repos-data 2>/dev/null || true
    print_success "Volumes removed"

    # Remove networks
    print_info "Removing networks..."
    docker network rm platform_upsonic-network 2>/dev/null || true
    print_success "Networks removed"

    # Backup and remove .env
    if [ -f ".env" ]; then
        print_info "Backing up .env file..."
        BACKUP_NAME=".env.backup.$(date +%Y%m%d_%H%M%S)"
        mv .env "$BACKUP_NAME"
        print_success "Configuration backed up to $BACKUP_NAME"
    fi

    echo ""
    print_success "Upsonic Platform has been completely removed!"
    echo ""
    print_info "To reinstall, run this script again and choose 'Setup'"
    echo ""
}

# Print info message
print_info() {
    echo -e "${INFO} ${CYAN}$1${NC}"
}

# Print success message
print_success() {
    echo -e "${CHECK_MARK} ${GREEN}$1${NC}"
}

# Print error message
print_error() {
    echo -e "${CROSS_MARK} ${RED}$1${NC}"
}

# Print warning message
print_warning() {
    echo -e "${WARNING} ${YELLOW}$1${NC}"
}

# Print step header
print_step() {
    echo ""
    echo -e "${BOLD}${MAGENTA}▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Generate random password (alphanumeric only, safe for URLs)
generate_password() {
    local length=${1:-20}
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# Generate random secret key
generate_secret_key() {
    LC_ALL=C tr -dc 'a-zA-Z0-9!@#$%^&*()-_=+' < /dev/urandom | head -c 50
}

# Generate UUID
generate_uuid() {
    if command_exists uuidgen; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c 32 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/'
    fi
}

# Validate email
validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Read input with default
read_with_default() {
    local prompt=$1
    local default=$2
    local var_name=$3

    if [ -n "$default" ]; then
        echo -ne "${prompt} ${YELLOW}[${default}]${NC}: "
    else
        echo -ne "${prompt}: "
    fi

    read input
    if [ -z "$input" ]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input'"
    fi
}

# Read password securely
read_password() {
    local prompt=$1
    local var_name=$2
    local allow_generate=${3:-true}

    if [ "$allow_generate" = true ]; then
        echo -ne "${prompt} ${YELLOW}[press Enter to auto-generate]${NC}: "
    else
        echo -ne "${prompt}: "
    fi

    read -s input
    echo ""

    if [ -z "$input" ] && [ "$allow_generate" = true ]; then
        local generated=$(generate_password 20)
        eval "$var_name='$generated'"
        print_info "Generated: ${generated}"
    else
        eval "$var_name='$input'"
    fi
}

# Confirm action
confirm() {
    local prompt=$1
    local default=${2:-n}

    if [ "$default" = "y" ]; then
        echo -ne "${prompt} ${YELLOW}[Y/n]${NC}: "
    else
        echo -ne "${prompt} ${YELLOW}[y/N]${NC}: "
    fi

    read answer

    if [ -z "$answer" ]; then
        answer=$default
    fi

    case ${answer:0:1} in
        y|Y )
            return 0
        ;;
        * )
            return 1
        ;;
    esac
}

# Progress bar
show_progress() {
    local duration=$1
    local message=$2
    local steps=20
    local step_duration=$(echo "$duration / $steps" | bc -l)

    echo -ne "${message} ["
    for ((i=0; i<steps; i++)); do
        echo -n "#"
        sleep "$step_duration"
    done
    echo -e "] Done"
}

# Main setup function
setup_platform() {
print_banner

print_step "System Requirements Check"

# Check Docker
print_info "Checking Docker..."
if ! command_exists docker; then
    print_error "Docker is not installed!"
    echo -e "   Please install Docker: ${CYAN}https://docs.docker.com/get-docker/${NC}"
    exit 1
fi
DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
print_success "Docker installed: $DOCKER_VERSION"

# Check Docker Compose
print_info "Checking Docker Compose..."
if ! docker compose version &>/dev/null; then
    print_error "Docker Compose V2 is not installed!"
    echo -e "   Please install Docker Compose V2"
    exit 1
fi
COMPOSE_VERSION=$(docker compose version --short)
print_success "Docker Compose installed: $COMPOSE_VERSION"

# Check Docker daemon
print_info "Checking Docker daemon..."
if ! docker info &>/dev/null; then
    print_error "Docker daemon is not running!"
    echo -e "   Please start Docker daemon"
    exit 1
fi
print_success "Docker daemon is running"

# Check port availability
print_info "Checking port availability..."
PORT_80_IN_USE=false
if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ':80 '; then
    PORT_80_IN_USE=true
    print_warning "Port 80 is already in use"
else
    print_success "Port 80 is available"
fi

print_step "Configuration Wizard"

# Check if .env already exists
if [ -f ".env" ]; then
    print_warning ".env file already exists!"
    echo ""
    if confirm "Do you want to use existing configuration?" "y"; then
        print_success "Using existing .env configuration"
        print_info "Skipping configuration wizard..."

        # Update version numbers in existing .env
        print_info "Updating image versions to latest..."

        # Detect platform architecture
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            VERSION_TAG="v0.1.13-amd64"
        elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
            VERSION_TAG="v0.1.13-arm64"
        else
            VERSION_TAG="v0.1.13-amd64"
        fi

        # Update versions in .env file
        sed -i.bak "s/PLATFORM_VERSION=.*/PLATFORM_VERSION=${VERSION_TAG}/" .env
        sed -i.bak "s/AMS_VERSION=.*/AMS_VERSION=${VERSION_TAG}/" .env

        print_success "Updated to version ${VERSION_TAG}"

        # Skip to deployment
        print_step "Starting Deployment"

        # Determine compose file
        if [ -f "compose-demo.yml" ]; then
            COMPOSE_FILE="compose-demo.yml"
        else
            print_error "compose-demo.yml not found!"
            exit 1
        fi

        print_info "Stopping existing containers..."
        docker compose -f "$COMPOSE_FILE" down --remove-orphans

        print_info "Pulling latest Docker images..."
        echo -e "${INFO} This may take several minutes depending on your connection..."
        echo ""

        if docker compose -f "$COMPOSE_FILE" pull --ignore-pull-failures || true; then
            print_success "Images pull attempted"
        fi

        print_info "Starting services with latest images (force recreate)..."
        docker compose -f "$COMPOSE_FILE" up -d --force-recreate --pull always --remove-orphans

        print_step "Deployment Complete"

        echo ""
        print_success "Upsonic Platform is starting up!"
        echo ""
        print_info "Access the platform at: ${CYAN}${BOLD}http://localhost${NC}"
        print_info "It may take 1-2 minutes for all services to be ready"
        echo ""

        exit 0
    else
        print_info "Creating backup of existing .env..."
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        print_success "Backup created"
    fi
fi

# Admin Configuration
print_info ""
print_info "${BOLD}Admin Account Configuration${NC}"
echo ""

while true; do
    read_with_default "Admin Email" "admin@upsonic.com" ADMIN_EMAIL
    if validate_email "$ADMIN_EMAIL"; then
        break
    else
        print_error "Invalid email format!"
    fi
done

ADMIN_USERNAME="$ADMIN_EMAIL"

while true; do
    read_password "Admin Password (min 8 chars)" ADMIN_PASSWORD false
    if [ ${#ADMIN_PASSWORD} -lt 8 ]; then
        print_error "Password must be at least 8 characters!"
        continue
    fi
    break
done

# Email Configuration
print_info ""
print_info "${BOLD}Email Configuration (for notifications)${NC}"
echo ""

if confirm "Do you want to configure SMTP now?" "n"; then
    CONFIGURE_SMTP=true

    read_with_default "SMTP Host" "smtp.gmail.com" SMTP_HOST
    read_with_default "SMTP Port" "587" SMTP_PORT

    while true; do
        read_with_default "SMTP Username (email)" "" SMTP_USER
        if validate_email "$SMTP_USER"; then
            break
        else
            print_error "Invalid email format!"
        fi
    done

    read_password "SMTP Password" SMTP_PASSWORD false
    read_with_default "From Email" "$SMTP_USER" SMTP_FROM
    read_with_default "Use TLS" "True" SMTP_TLS

    EMAIL_BACKEND="django.core.mail.backends.smtp.EmailBackend"
else
    CONFIGURE_SMTP=false
    EMAIL_BACKEND="django.core.mail.backends.console.EmailBackend"
    print_info "Email will be logged to console (no actual sending)"
fi

# Database Configuration
print_info ""
print_info "${BOLD}Database Configuration${NC}"
echo ""

print_info "Generating secure database passwords..."
DB_PASSWORD=$(generate_password 24)
AMS_DB_PASSWORD=$(generate_password 24)
print_success "Database passwords generated"

# Security Configuration
print_info ""
print_info "${BOLD}Security Configuration${NC}"
echo ""

print_info "Generating SECRET_KEY..."
SECRET_KEY=$(generate_secret_key)
print_success "SECRET_KEY generated"

print_info "Generating Bearer Tokens..."
AMS_BEARER_TOKEN=$(generate_uuid)
PLATFORM_BEARER_TOKEN=$(generate_uuid)
print_success "Bearer tokens generated"

# Platform Selection
print_info ""
print_info "${BOLD}Platform Selection${NC}"
echo ""

echo "Select your platform:"
echo "  1) Linux (AMD64) - For production servers"
echo "  2) Mac (ARM64) - For Mac M1/M2"
echo ""

while true; do
    read -p "Enter your choice [1-2]: " PLATFORM_CHOICE
    case $PLATFORM_CHOICE in
        1)
            PLATFORM_ARCH="amd64"
            VERSION_TAG="v0.1.13-amd64"
            print_success "Selected: Linux (AMD64)"
            break
            ;;
        2)
            PLATFORM_ARCH="arm64"
            VERSION_TAG="v0.1.13-arm64"
            print_success "Selected: Mac (ARM64)"
            break
            ;;
        *)
            print_error "Invalid choice. Please enter 1 or 2."
            ;;
    esac
done

# Use single compose file for all platforms
COMPOSE_FILE="compose-demo.yml"

# Server Configuration
print_info ""
print_info "${BOLD}Server Configuration${NC}"
echo ""

if [ "$PORT_80_IN_USE" = true ]; then
    read_with_default "Platform Port (80 is in use)" "8080" PLATFORM_PORT
else
    read_with_default "Platform Port" "80" PLATFORM_PORT
fi

echo ""
print_info "Server IP/Domain Configuration:"
echo "  - For local development: Use 0.0.0.0"
echo "  - For internal network: Use server's IP (e.g., 192.168.1.50)"
echo "  - For public access: Use your domain or public IP"
echo ""
read_with_default "Server IP or Domain (without port)" "0.0.0.0" SERVER_IP

# Construct SERVER_BASE_ADDRESS with http:// prefix
if [[ "$SERVER_IP" == http://* ]] || [[ "$SERVER_IP" == https://* ]]; then
    SERVER_BASE_ADDRESS="$SERVER_IP"
else
    SERVER_BASE_ADDRESS="http://$SERVER_IP"
fi

# Docker Registry Configuration
print_info ""
print_info "${BOLD}Docker Registry Configuration${NC}"
echo ""

read_with_default "Docker Registry" "getupsonic" DOCKER_REGISTRY

# Docker Hub login for private registry
if [ -n "$DOCKER_TOKEN" ]; then
    print_info "Logging in to Docker Hub with provided token..."
    if echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_REGISTRY" --password-stdin >/dev/null 2>&1; then
        print_success "Docker Hub authentication successful"
    else
        print_error "Docker Hub login failed"
        exit 1
    fi
else
    print_warning "DOCKER_TOKEN not set - skipping Docker Hub login"
    print_info "For private registries, set DOCKER_TOKEN environment variable:"
    print_info "  ${CYAN}export DOCKER_TOKEN='your_token_here'${NC}"
    echo ""
fi

# Create .env file
print_step "Creating Configuration File"

cat > .env << EOF
# ===================================
# Upsonic Platform Configuration
# Generated: $(date)
# ===================================

# ===================================
# Admin Configuration
# ===================================
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ADMIN_EMAIL=${ADMIN_EMAIL}

# ===================================
# Platform Database (PostgreSQL)
# ===================================
POSTGRES_USER=upsonic
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=upsonic
db_name=upsonic
db_user=upsonic
db_pass=${DB_PASSWORD}
db_host=upsonic-db
db_port=5432

# ===================================
# AMS Database (PostgreSQL)
# ===================================
AMS_DB_USER=ams_user
AMS_DB_PASSWORD=${AMS_DB_PASSWORD}
AMS_DB_NAME=ams_db

# ===================================
# Security
# ===================================
SECRET_KEY=${SECRET_KEY}
DEBUG=True
ALLOWED_HOSTS=*

# ===================================
# Server Configuration
# ===================================
SERVER_BASE_ADDRESS=${SERVER_BASE_ADDRESS}
PLATFORM_PORT=${PLATFORM_PORT}

# ===================================
# AMS Integration
# ===================================
AMS_BASE_URL=http://ams-project:7329
AMS_BEARER_TOKEN=${AMS_BEARER_TOKEN}
PLATFORM_BEARER_TOKEN=${PLATFORM_BEARER_TOKEN}

# ===================================
# Redis & Celery
# ===================================
CELERY_BROKER_URL=redis://upsonic-redis:6379/0
CELERY_RESULT_BACKEND=redis://upsonic-redis:6379/1
CACHE_REDIS_URL=redis://upsonic-redis:6379/1

# ===================================
# Email Configuration
# ===================================
EMAIL_BACKEND=${EMAIL_BACKEND}
EOF

if [ "$CONFIGURE_SMTP" = true ]; then
    cat >> .env << EOF
EMAIL_HOST=${SMTP_HOST}
EMAIL_PORT=${SMTP_PORT}
EMAIL_USE_TLS=${SMTP_TLS}
EMAIL_HOST_USER=${SMTP_USER}
EMAIL_HOST_PASSWORD=${SMTP_PASSWORD}
DEFAULT_FROM_EMAIL=${SMTP_FROM}
EOF
else
    cat >> .env << EOF
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
DEFAULT_FROM_EMAIL=noreply@upsonic.co
EOF
fi

cat >> .env << EOF

# ===================================
# Docker Configuration
# ===================================
DOCKER_REGISTRY=${DOCKER_REGISTRY}
PLATFORM_VERSION=${VERSION_TAG}
AMS_VERSION=${VERSION_TAG}
REGISTRY_STRATEGY=docker_compose

# ===================================
# Additional Settings
# ===================================
PYTHONUNBUFFERED=1
EOF

chmod 600 .env
print_success ".env file created successfully"

# Cleanup old containers and networks
print_step "Cleaning Up Old Resources"

print_info "Cleaning up any existing containers..."
docker compose -f compose-local.yml down --remove-orphans 2>/dev/null || true
docker compose -f compose-demo.yml down --remove-orphans 2>/dev/null || true

print_info "Removing old networks..."
docker network rm platform_upsonic-network-local 2>/dev/null || true
docker network rm platform_upsonic-network 2>/dev/null || true
docker network rm upsonic-network 2>/dev/null || true

print_success "Cleanup completed (volumes preserved)"

# Create shared Docker network for Platform and Agents
print_step "Network Setup"

print_info "Creating shared Docker network..."
if ! docker network inspect upsonic-network >/dev/null 2>&1; then
    docker network create upsonic-network
    print_success "Network 'upsonic-network' created"
else
    print_success "Network 'upsonic-network' already exists"
fi

# Summary
print_step "Configuration Summary"

echo ""
echo -e "${BOLD}Admin Credentials:${NC}"
echo -e "  Email/Username: ${CYAN}${ADMIN_USERNAME}${NC}"
echo -e "  Password: ${CYAN}********${NC} ${YELLOW}(saved securely)${NC}"
echo ""
echo -e "${BOLD}Access URLs:${NC}"
echo -e "  External: ${CYAN}${SERVER_BASE_ADDRESS}:${PLATFORM_PORT}${NC}"
echo -e "  Internal: ${CYAN}http://localhost:${PLATFORM_PORT}${NC}"
echo ""
echo -e "${BOLD}Services:${NC}"
echo -e "  Platform:  ${CYAN}Port ${PLATFORM_PORT}${NC}"
echo -e "  AMS API:   ${CYAN}Port 7329${NC}"
echo ""

if [ "$CONFIGURE_SMTP" = true ]; then
    echo -e "${BOLD}Email:${NC}"
    echo -e "  ${GREEN}SMTP Configured${NC}"
    echo ""
else
    echo -e "${BOLD}Email:${NC}"
    echo -e "  ${YELLOW}Console Only (no actual sending)${NC}"
    echo ""
fi

# Start confirmation
echo ""
if ! confirm "Do you want to start Upsonic Platform now?" "y"; then
    print_info "You can start later with: ${CYAN}docker compose -f ${COMPOSE_FILE} up -d${NC}"
    exit 0
fi

# Pull images
print_step "Pulling Docker Images"

print_info "This may take several minutes depending on your connection..."
echo ""

if docker compose -f ${COMPOSE_FILE} pull; then
    print_success "Images pulled successfully"
else
    print_error "Failed to pull some images"
    print_warning "You may need to build locally or check registry access"
    if confirm "Do you want to continue anyway?" "n"; then
        print_info "Continuing..."
    else
        exit 1
    fi
fi

# Start services
print_step "Starting Services"

print_info "Starting Docker Compose services..."
echo ""

if docker compose -f ${COMPOSE_FILE} up -d --force-recreate --pull always; then
    print_success "Services started successfully"
else
    print_error "Failed to start services"
    print_info "Check logs with: ${CYAN}docker compose -f ${COMPOSE_FILE} logs${NC}"
    exit 1
fi

# Wait for services
print_step "Waiting for Services to Be Ready"

print_info "Waiting for databases..."
sleep 5

RETRY_COUNT=0
MAX_RETRIES=30

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec upsonic-db pg_isready -U upsonic >/dev/null 2>&1; then
        print_success "Platform database is ready"
        break
    fi
    echo -ne "."
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    print_error "Timeout waiting for platform database"
fi

RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec ams-db pg_isready -U ams_user >/dev/null 2>&1; then
        print_success "AMS database is ready"
        break
    fi
    echo -ne "."
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    print_error "Timeout waiting for AMS database"
fi

print_info "Waiting for platform API to be ready (this may take 1-2 minutes)..."
sleep 10

RETRY_COUNT=0
MAX_RETRIES=60

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:${PLATFORM_PORT} >/dev/null 2>&1; then
        print_success "Platform is ready!"
        break
    fi
    echo -ne "."
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

echo ""

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    print_warning "Platform may still be initializing"
    print_info "Check status with: ${CYAN}docker compose ps${NC}"
    print_info "Check logs with: ${CYAN}docker compose logs -f upsonic-api${NC}"
else
    # Success banner
    echo ""
    echo -e "${GREEN}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════╗
║                                               ║
║     ✓  Upsonic AgentOS is Running!           ║
║                                               ║
╚═══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    # Construct URL with port
    ACCESS_URL="${SERVER_BASE_ADDRESS}"
    if [ "$PLATFORM_PORT" != "80" ] && [ "$PLATFORM_PORT" != "443" ]; then
        ACCESS_URL="${SERVER_BASE_ADDRESS}:${PLATFORM_PORT}"
    fi

    echo -e "${BOLD}Quick Start:${NC}"
    echo -e "  1. Open: ${CYAN}${ACCESS_URL}${NC}"
    echo -e "  2. Login with email: ${CYAN}${ADMIN_USERNAME}${NC}"
    echo -e "  3. Add your Git provider credentials in Settings"
    echo -e "  4. Deploy your first agent!"
    echo ""
    echo -e "${BOLD}Useful Commands:${NC}"
    echo -e "  View logs:     ${CYAN}docker compose -f ${COMPOSE_FILE} logs -f${NC}"
    echo -e "  Stop services: ${CYAN}docker compose -f ${COMPOSE_FILE} down${NC}"
    echo -e "  Restart:       ${CYAN}docker compose -f ${COMPOSE_FILE} restart${NC}"
    echo ""
    echo -e "${BOLD}Need Help?${NC}"
    echo -e "  Documentation: ${CYAN}https://docs.upsonic.ai${NC}"
    echo -e "  Support:       ${CYAN}support@upsonic.ai${NC}"
    echo ""
fi

print_info "${YELLOW}Note: It may take another minute for all services to fully initialize${NC}"
echo ""
}

# Main menu
show_menu() {
    print_banner
    echo -e "${BOLD}What would you like to do?${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Setup / Install Upsonic Platform"
    echo -e "  ${RED}2)${NC} Delete / Uninstall Upsonic Platform"
    echo -e "  ${BLUE}3)${NC} Exit"
    echo ""
    echo -n -e "${CYAN}Enter your choice [1-3]: ${NC}"
    read -r choice

    case $choice in
        1)
            setup_platform
            ;;
        2)
            delete_platform
            ;;
        3)
            echo ""
            print_info "Goodbye!"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            print_error "Invalid choice. Please select 1, 2, or 3."
            sleep 2
            show_menu
            ;;
    esac
}

# Start the wizard
show_menu
