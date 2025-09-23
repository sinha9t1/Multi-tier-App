#!/bin/bash
set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/infra/terraform"

# Configuration
PROJECT_NAME="multi-tier-app"
AWS_REGION="us-east-1"
KEY_NAME="${PROJECT_NAME}-dev-key"

# Usage function
usage() {
    cat << EOF
Usage: $0 COMMAND

Commands:
    deploy      Deploy infrastructure
    destroy     Destroy infrastructure
    plan        Show deployment plan
    validate    Validate terraform configuration
    setup       Setup .gitignore file for Terraform

Examples:
    $0 setup
    $0 deploy
    $0 plan
    $0 destroy
EOF
}

# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    command -v aws >/dev/null 2>&1 || missing_tools+=("aws-cli")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "ERROR: Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
    
    # Check if Terraform directory exists
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        echo "ERROR: Terraform directory not found: $TERRAFORM_DIR"
        echo "Expected location: /home/devops/Multi-tier-App/infra/terraform"
        echo "Please make sure your Terraform files are in the correct location"
        exit 1
    fi
    
    # Verify Terraform files exist
    if ! ls "$TERRAFORM_DIR"/*.tf >/dev/null 2>&1; then
        echo "ERROR: No Terraform files (*.tf) found in $TERRAFORM_DIR"
        exit 1
    fi
    
    echo "INFO: Found Terraform files in $TERRAFORM_DIR"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo "ERROR: AWS credentials not configured or invalid"
        exit 1
    fi
    
    echo "INFO: Prerequisites check passed"
}

# Setup .gitignore for Terraform
setup_gitignore() {
    local gitignore_file="$TERRAFORM_DIR/.gitignore"
    
    # Terraform ignore rules
    local tf_ignore_content=$(cat <<'EOF'
# Local .terraform directories
.terraform/
.terraform.lock.hcl
# Terraform state files
*.tfstate
*.tfstate.*
crash.log
crash.*.log
# Terraform override files (not for production use)
override.tf
override.tf.json
*_override.tf
*_override.tf.json
# Sensitive variable files
terraform.tfvars
*.auto.tfvars
# Plan output files
*.plan
tfplan
# Module/package archives
*.zip
*.tar.gz
# OS/editor junk
.DS_Store
Thumbs.db
*.swp
*.bak
*.tmp
EOF
)
    
    # Create .gitignore if not exists
    if [ ! -f "$gitignore_file" ]; then
        echo "INFO: Creating $gitignore_file"
        touch "$gitignore_file"
    fi
    
    # Append ignore rules only if they're not already present
    echo "$tf_ignore_content" | while IFS= read -r line; do
        if ! grep -Fxq "$line" "$gitignore_file" 2>/dev/null; then
            echo "$line" >> "$gitignore_file"
        fi
    done
    
    echo "INFO: .gitignore updated successfully at $gitignore_file"
}

# Ensure key pair exists
ensure_key_pair() {
    local key_file="$PROJECT_ROOT/keys/${KEY_NAME}.pem"
    
    echo "INFO: Checking key pair: $KEY_NAME"
    
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        echo "INFO: Key pair $KEY_NAME already exists"
    else
        echo "INFO: Creating key pair: $KEY_NAME"
        
        # Ensure keys directory exists
        mkdir -p "$PROJECT_ROOT/keys"
        
        aws ec2 create-key-pair \
            --key-name "$KEY_NAME" \
            --query 'KeyMaterial' \
            --output text \
            --region "$AWS_REGION" > "$key_file"
        
        chmod 400 "$key_file"
        echo "INFO: Key pair created and saved as $key_file"
        
        # Add to .gitignore if not already there
        grep -qxF "keys/*.pem" "$PROJECT_ROOT/.gitignore" 2>/dev/null || echo "keys/*.pem" >> "$PROJECT_ROOT/.gitignore"
    fi
    
    export TF_VAR_key_name="$KEY_NAME"
}

# Initialize Terraform
terraform_init() {
    cd "$TERRAFORM_DIR"
    
    # Check if Terraform files exist
    if ! ls *.tf >/dev/null 2>&1; then
        echo "ERROR: No Terraform configuration files (*.tf) found in $TERRAFORM_DIR"
        echo "Please create your Terraform configuration files first (main.tf, variables.tf, etc.)"
        exit 1
    fi
    
    echo "INFO: Initializing Terraform"
    terraform init
}

# Terraform operations
terraform_plan() {
    terraform_init
    echo "INFO: Creating Terraform plan"
    terraform plan -out="tfplan"
}

terraform_apply() {
    terraform_plan
    echo "INFO: Applying Terraform configuration"
    terraform apply "tfplan"
    rm -f tfplan
    echo "INFO: Deployment completed successfully!"
}

terraform_destroy() {
    terraform_init
    echo "WARNING: This will destroy all infrastructure"
    read -p "Are you sure? Type 'yes' to confirm: " -r
    if [[ $REPLY == "yes" ]]; then
        terraform destroy -auto-approve
        echo "INFO: Infrastructure destroyed"
    else
        echo "INFO: Destroy cancelled"
    fi
}

terraform_validate() {
    terraform_init
    echo "INFO: Validating Terraform configuration"
    terraform validate
    terraform fmt -check=true
    echo "INFO: Terraform validation passed"
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    local command="$1"
    
    check_prerequisites
    
    case $command in
        setup)
            setup_gitignore
            ;;
        deploy)
            setup_gitignore
            ensure_key_pair
            terraform_apply
            ;;
        destroy)
            terraform_destroy
            ;;
        plan)
            setup_gitignore
            ensure_key_pair
            terraform_plan
            ;;
        validate)
            setup_gitignore
            terraform_validate
            ;;
        *)
            echo "ERROR: Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"