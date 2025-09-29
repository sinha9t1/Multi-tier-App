#!/bin/bash
set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/infra/terraform"
ANSIBLE_DIR="$PROJECT_ROOT/infra/ansible_mta"

# Configuration
PROJECT_NAME="multi-tier-app"
AWS_REGION="us-east-1"
KEY_NAME="${PROJECT_NAME}-dev-key"
DEFAULT_ENV="dev"
 
# Usage function
usage() {
    cat << EOF
Usage: $0 COMMAND [OPTIONS]

Commands:
    deploy      Deploy infrastructure
    destroy     Destroy infrastructure
    plan        Show deployment plan
    validate    Validate terraform configuration
    setup       Setup .gitignore file for Terraform
    ansible     Setup/test Ansible dynamic inventory
    status      Show infrastructure status

Options:
    --env ENV_NAME   Specify environment name (default: $DEFAULT_ENV)
    --skip-ansible  Skip Ansible setup/test

Examples:
    $0 setup
    $0 deploy
    $0 plan
    $0 destroy
    $0 validate
    $0 ansible
    $0 status
EOF
}

#Parse command line arguments
parse_args() {
    COMMAND=""
    ENV_NAME="$DEFAULT_ENV"
    SKIP_ANSIBLE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            deploy|destroy|plan|validate|setup|ansible|status)
                COMMAND="$1"
                ;;
            --env)
                ENV_NAME="$2"
                shift
                ;;
            --skip-ansible)
                SKIP_ANSIBLE=true
                ;;
            -h|--help)
                usage
                exit 0
                ;;    
            *)  
                echo "ERROR: Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done
    if [[ -z "$COMMAND" ]]; then
        echo "ERROR: No command specified"
        usage
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    command -v aws >/dev/null 2>&1 || missing_tools+=("aws-cli")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")

    #Only check Ansible if not skipped
    if [[ "$SKIP_ANSIBLE" == false ]]; then
        command -v ansible >/dev/null 2>&1 || missing_tools+=("ansible")
        command -v ansible-playbook >/dev/null 2>&1 || missing_tools+=("ansible-playbook")
    fi
    
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

    #Root project level .gitignore
    local root_gitignore_file="$PROJECT_ROOT/.gitignore"

    if [ ! -f "$root_gitignore_file" ]; then
        echo "INFO: Creating .gitignore at $root_gitignore_file"
        touch "$root_gitignore_file"
        echo "$root_ignore_content" > "$root_gitignore_file"
    else
        echo "INFO: .gitignore already exists at $root_gitignore_file, appending entries!" 
        # Append only if not already present
        echo "$root_ignore_content" | while IFS= read -r line; do
            if ! grep -Fxq "$line" "$root_gitignore_file" 2>/dev/null; then
                echo "$line" >> "$root_gitignore_file"
            fi
        done
    fi

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
    export TF_VAR_environment="$ENVIRONMENT"
    export TF_VAR_project_name="$PROJECT_NAME"
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

#Ansible setup
setup_ansible() {
    echo "INFO: Setting up/testing Ansible dynamic inventory"
    #Create directory structure if exists
    

    # Check if inventory file exists
    if [[ ! -f "inventory.ini" ]]; then
        echo "ERROR: Ansible inventory file not found: $ANSIBLE_DIR/inventory.ini"
        exit 1
    fi

    echo "INFO: Testing Ansible connectivity with inventory"
    ansible all -i inventory.ini -m ping

    echo "INFO: Running Ansible playbook to setup application"
    ansible-playbook -i inventory.ini site.yml --private-key "$PROJECT_ROOT/keys/${KEY_NAME}.pem" --user ec2-user

    echo "INFO: Ansible setup/test completed successfully"
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