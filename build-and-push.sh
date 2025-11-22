#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_step() {
    echo ""
    echo -e "${BOLD}${CYAN}==>${NC} ${BOLD}$1${NC}"
    echo ""
}

# Banner
print_banner() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Upsonic Platform - Image Builder${NC}   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if version is provided
if [ -z "$1" ]; then
    print_error "Version number is required!"
    echo ""
    echo "Usage: $0 <version> [--push]"
    echo ""
    echo "Examples:"
    echo "  $0 0.1.0              # Build only (test mode)"
    echo "  $0 0.1.0 --push       # Build and push to Docker Hub"
    echo ""
    exit 1
fi

VERSION="$1"
PUSH_MODE=false

# Check if --push flag is provided
if [ "$2" = "--push" ]; then
    PUSH_MODE=true
fi

# Docker registry configuration
DOCKER_REGISTRY="getupsonic"
AMS_IMAGE="${DOCKER_REGISTRY}/ams"
AGENTOS_IMAGE="${DOCKER_REGISTRY}/agentos"

# Architecture targets
ARCHS=("amd64" "arm64")

print_banner

print_info "Building version: ${BOLD}v${VERSION}${NC}"
if [ "$PUSH_MODE" = true ]; then
    print_warning "Push mode: ${BOLD}ENABLED${NC} - Images will be pushed to Docker Hub"
else
    print_info "Push mode: ${BOLD}DISABLED${NC} - Test mode (build only)"
fi

# Check Docker
print_step "Checking Prerequisites"

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    exit 1
fi
print_success "Docker is installed"

# Check if logged in to Docker Hub (only if pushing)
if [ "$PUSH_MODE" = true ]; then
    print_info "Checking Docker Hub authentication..."

    # Check if DOCKER_TOKEN is set
    if [ -n "$DOCKER_TOKEN" ]; then
        print_info "Using DOCKER_TOKEN for authentication..."
        if echo "$DOCKER_TOKEN" | docker login -u "${DOCKER_REGISTRY}" --password-stdin >/dev/null 2>&1; then
            print_success "Authenticated to Docker Hub with token"
        else
            print_error "Failed to authenticate with DOCKER_TOKEN!"
            exit 1
        fi
    elif docker info 2>/dev/null | grep -q "Username"; then
        print_success "Already authenticated to Docker Hub"
    else
        print_error "Not logged in to Docker Hub!"
        echo ""
        print_info "Please set DOCKER_TOKEN or login manually:"
        echo "  ${CYAN}export DOCKER_TOKEN='your_token'${NC}"
        echo "  ${CYAN}docker login${NC}"
        exit 1
    fi
fi

# Build AMS images
print_step "Building AMS Images"

print_info "Building AMS for multiple architectures..."

for ARCH in "${ARCHS[@]}"; do
    print_info "Building AMS for ${BOLD}${ARCH}${NC}..."

    TAG="${AMS_IMAGE}:v${VERSION}-${ARCH}"

    docker build \
        --platform linux/${ARCH} \
        -t ${TAG} \
        -f ams_project/Dockerfile \
        ams_project/ || {
        print_error "Failed to build AMS for ${ARCH}"
        exit 1
    }

    print_success "Built: ${TAG}"
done

# Build AgentOS images
print_step "Building AgentOS Images"

print_info "Building AgentOS for multiple architectures..."

for ARCH in "${ARCHS[@]}"; do
    print_info "Building AgentOS for ${BOLD}${ARCH}${NC}..."

    TAG="${AGENTOS_IMAGE}:v${VERSION}-${ARCH}"

    docker build \
        --platform linux/${ARCH} \
        -t ${TAG} \
        -f Dockerfile \
        . || {
        print_error "Failed to build AgentOS for ${ARCH}"
        exit 1
    }

    print_success "Built: ${TAG}"
done

# Show built images
print_step "Built Images Summary"

echo ""
echo -e "${BOLD}AMS Images:${NC}"
for ARCH in "${ARCHS[@]}"; do
    TAG="v${VERSION}-${ARCH}"
    SIZE=$(docker images ${AMS_IMAGE}:${TAG} --format "{{.Size}}")
    echo -e "  ${CYAN}${AMS_IMAGE}:${TAG}${NC} - ${SIZE}"
done

echo ""
echo -e "${BOLD}AgentOS Images:${NC}"
for ARCH in "${ARCHS[@]}"; do
    TAG="v${VERSION}-${ARCH}"
    SIZE=$(docker images ${AGENTOS_IMAGE}:${TAG} --format "{{.Size}}")
    echo -e "  ${CYAN}${AGENTOS_IMAGE}:${TAG}${NC} - ${SIZE}"
done
echo ""

# Push images if --push flag is provided
if [ "$PUSH_MODE" = true ]; then
    print_step "Pushing Images to Docker Hub"

    print_warning "Pushing images to ${DOCKER_REGISTRY}..."
    echo ""

    # Push AMS images
    print_info "Pushing AMS images..."
    for ARCH in "${ARCHS[@]}"; do
        TAG="${AMS_IMAGE}:v${VERSION}-${ARCH}"
        print_info "Pushing ${TAG}..."

        docker push ${TAG} || {
            print_error "Failed to push ${TAG}"
            exit 1
        }

        print_success "Pushed: ${TAG}"
    done

    # Push AgentOS images
    print_info "Pushing AgentOS images..."
    for ARCH in "${ARCHS[@]}"; do
        TAG="${AGENTOS_IMAGE}:v${VERSION}-${ARCH}"
        print_info "Pushing ${TAG}..."

        docker push ${TAG} || {
            print_error "Failed to push ${TAG}"
            exit 1
        }

        print_success "Pushed: ${TAG}"
    done

    print_step "Push Complete"

    echo ""
    print_success "All images pushed successfully!"
    echo ""
    echo -e "${BOLD}Published Images:${NC}"
    echo ""
    echo -e "${BOLD}AMS:${NC}"
    for ARCH in "${ARCHS[@]}"; do
        echo -e "  ${CYAN}docker pull ${AMS_IMAGE}:v${VERSION}-${ARCH}${NC}"
    done
    echo ""
    echo -e "${BOLD}AgentOS:${NC}"
    for ARCH in "${ARCHS[@]}"; do
        echo -e "  ${CYAN}docker pull ${AGENTOS_IMAGE}:v${VERSION}-${ARCH}${NC}"
    done
    echo ""

else
    print_step "Test Build Complete"

    echo ""
    print_success "All images built successfully!"
    echo ""
    print_info "To push these images to Docker Hub, run:"
    echo -e "  ${CYAN}$0 ${VERSION} --push${NC}"
    echo ""
fi

print_success "Done!"
echo ""