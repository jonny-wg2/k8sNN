#!/bin/bash

# K8sNN Command Line Version
# A temporary solution while you install Xcode for the full GUI app

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find kubectl
find_kubectl() {
    local paths=("/usr/local/bin/kubectl" "/opt/homebrew/bin/kubectl" "/usr/bin/kubectl")
    
    for path in "${paths[@]}"; do
        if [[ -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    # Try which
    if command -v kubectl &> /dev/null; then
        which kubectl
        return 0
    fi
    
    echo ""
    return 1
}

# Get all contexts
get_contexts() {
    local kubectl_path="$1"
    "$kubectl_path" config get-contexts -o name 2>/dev/null || echo ""
}

# Test cluster authentication
test_cluster_auth() {
    local kubectl_path="$1"
    local context="$2"

    # Try multiple authentication checks in order of preference

    # First try: List pods (most reliable)
    if "$kubectl_path" --context "$context" get pods --limit=1 --request-timeout=5s &>/dev/null; then
        return 0
    fi

    # Second try: List namespaces (less privileged)
    if "$kubectl_path" --context "$context" get namespaces --limit=1 --request-timeout=5s &>/dev/null; then
        return 0
    fi

    # Third try: Get cluster info
    if "$kubectl_path" --context "$context" cluster-info --request-timeout=5s &>/dev/null; then
        return 0
    fi

    # Fourth try: Auth can-i (fallback)
    if "$kubectl_path" --context "$context" auth can-i get pods --request-timeout=5s &>/dev/null; then
        return 0
    fi

    return 1
}

# Generate login URL
get_login_url() {
    local context="$1"

    # Parse the context name to extract components
    # Example: j0nny-echo.pdx.prod.wgtwo.com -> login.echo.pdx.prod.wgtwo.com
    if [[ "$context" =~ ^[^-]+-([^.]+)\.([^.]+)\.(prod|dev|infrasvc)\.wgtwo\.com$ ]]; then
        local cluster_name="${BASH_REMATCH[1]}"  # echo
        local region="${BASH_REMATCH[2]}"        # pdx
        local env="${BASH_REMATCH[3]}"           # prod
        echo "https://login.${cluster_name}.${region}.${env}.wgtwo.com"
    # Handle dub.dev and dub.prod patterns
    # Example: j0nny-dub.prod.wgtwo.com -> login.dub.prod.wgtwo.com
    elif [[ "$context" =~ ^[^-]+-([^.]+)\.(prod|dev)\.wgtwo\.com$ ]]; then
        local cluster_name="${BASH_REMATCH[1]}"  # dub
        local env="${BASH_REMATCH[2]}"           # prod
        echo "https://login.${cluster_name}.${env}.wgtwo.com"
    else
        echo ""
    fi
}

# Main function
main() {
    echo -e "${BLUE}🚀 K8sNN - Kubernetes Cluster Authentication Monitor${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo ""
    
    # Find kubectl
    echo "🔍 Finding kubectl..."
    local kubectl_path
    kubectl_path=$(find_kubectl)
    
    if [[ -z "$kubectl_path" ]]; then
        echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Found kubectl at: $kubectl_path${NC}"
    echo ""
    
    # Get contexts
    echo "📋 Getting cluster contexts..."
    local contexts
    contexts=$(get_contexts "$kubectl_path")
    
    if [[ -z "$contexts" ]]; then
        echo -e "${RED}❌ No kubectl contexts found. Please configure kubectl first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Found $(echo "$contexts" | wc -l | tr -d ' ') clusters${NC}"
    echo ""
    
    # Check each cluster
    echo "🔐 Checking authentication status..."
    echo ""
    
    local authenticated=0
    local total=0
    local unauthenticated_clusters=()
    
    while IFS= read -r context; do
        [[ -z "$context" ]] && continue
        
        total=$((total + 1))
        printf "%-50s " "$context"
        
        if test_cluster_auth "$kubectl_path" "$context"; then
            echo -e "${GREEN}🟢 Authenticated${NC}"
            authenticated=$((authenticated + 1))
        else
            echo -e "${RED}🔴 Not authenticated${NC}"
            unauthenticated_clusters+=("$context")
            
            # Show login URL if available
            local login_url
            login_url=$(get_login_url "$context")
            if [[ -n "$login_url" ]]; then
                echo -e "   ${YELLOW}🔗 Login: $login_url${NC}"
            fi
        fi
    done <<< "$contexts"
    
    echo ""
    echo -e "${BLUE}📊 Summary:${NC}"
    echo -e "   Total clusters: $total"
    echo -e "   ${GREEN}Authenticated: $authenticated${NC}"
    echo -e "   ${RED}Not authenticated: $((total - authenticated))${NC}"
    
    # Offer to open login pages
    if [[ ${#unauthenticated_clusters[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}🌐 Open login pages for unauthenticated clusters?${NC}"
        
        for context in "${unauthenticated_clusters[@]}"; do
            local login_url
            login_url=$(get_login_url "$context")
            
            if [[ -n "$login_url" ]]; then
                echo ""
                read -p "Open login page for $context? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${BLUE}🌐 Opening $login_url${NC}"
                    open "$login_url"
                fi
            fi
        done
    fi
    
    echo ""
    echo -e "${BLUE}💡 Tip: Install Xcode to get the beautiful menubar app version!${NC}"
}

# Handle Ctrl+C
trap 'echo -e "\n${YELLOW}👋 Goodbye!${NC}"; exit 0' INT

# Run main function
main "$@"
