#!/bin/bash
#Script: nexus-secrets.sh
#########################################################################################################
#Description: Creates the Nexus admin credentials secret in AWS Secrets Manager securely.
#Usage: ./nexus-secret.sh
#########################################################################################################
#Variables
SECRET_NAME="admin-credentials"
SECRET_FILE=nexus-secret.json

#Create a JSON file non-interactively with the secret details with Here document
cat <<EOF > $SECRET_FILE
{
    "username": "admin",
    "password": "nexusArtifacts"
}
EOF
#Create the secret using the file.
echo "Creating secret '$SECRET_NAME' in AWS Secrets Manager..."
aws secretmanager create-secret --name $SECRET_NAME --secret-string file://$SECRET_FILE

#Check if the secret was created successfully
if [ $? -eq 0 ]; then
    echo "Secret '$SECRET_NAME' created successfully."
    
    #Verify the secret is created successfully.
    echo "Listing secrets to verify creation..."
    aws secretsmanager list-secrets --query "SecretList[?Name=='$SECRET_NAME'].Name" --output text
else
    echo "Failed to create secret '$SECRET_NAME', Check if already exists"
    #Cleanup the JSON file
    rm -f $SECRET_FILE
    exit 1
fi