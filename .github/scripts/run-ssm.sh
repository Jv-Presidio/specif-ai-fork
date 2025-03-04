#!/bin/bash

# Environment Variables Used:
# TENANT                      - The tenant name, used to identify the specific tenant for the deployment.
# ENV                         - The environment (e.g., dev, qa, prod) for which the deployment is being done.
# INSTANCE_NAME               - The name tag of the EC2 instance to retrieve the instance ID.
# AWS_ACCOUNT_ID              - The AWS account ID used to log in to ECR and identify Docker images.
# AWS_DEFAULT_REGION          - The AWS region where resources (ECR, EC2, etc.) are located.
# IMAGE_NAME                  - The name of the Docker image stored in ECR.
# TAG                         - The specific tag of the Docker image to pull from ECR.
# SENTRY_DSN                  - The DSN for Sentry to enable error tracking in the application.
# SENTRY_ENVIRONMENT          - The environment (e.g., dev, qa, prod) for which Sentry should log.
# SENTRY_RELEASE              - The release version to track in Sentry.
# ENABLE_SENTRY               - Flag to enable or disable Sentry error tracking.
# DEFAULT_API_PROVIDER        - The default API provider for the application, dynamically constructed as "${ENV}_${TENANT}_DEFAULT_API_PROVIDER".
# DEFAULT_MODEL               - The default model to be used by the application, dynamically constructed as "${ENV}_${TENANT}_DEFAULT_MODEL".
# AZURE_OPENAI_API_KEY        - The API key for accessing Azure OpenAI services, dynamically constructed as "${ENV}_${TENANT}_AZURE_OPENAI_API_KEY".
# OPENAI_API_VERSION          - The version of the OpenAI API to use, dynamically constructed as "${ENV}_${TENANT}_OPENAI_API_VERSION".
# OPENAI_API_KEY              - The API key for accessing OpenAI services, dynamically constructed as "${ENV}_${TENANT}_OPENAI_API_KEY".
# OPENAI_BASE_URL             - The base URL for the OpenAI API, dynamically constructed as "${ENV}_${TENANT}_OPENAI_BASE_URL".
# ANTHROPIC_BASE_URL          - The base URL for Anthropic services, dynamically constructed as "${ENV}_${TENANT}_ANTHROPIC_BASE_URL".
# ANTHROPIC_API_KEY           - The API key for accessing Anthropic services, dynamically constructed as "${ENV}_${TENANT}_ANTHROPIC_API_KEY".
# ANTHROPIC_BEDROCK_BASE_URL  - The base URL for Anthropic Bedrock services, dynamically constructed as "${ENV}_${TENANT}_ANTHROPIC_BEDROCK_BASE_URL".
# AWS_BEDROCK_ACCESS_KEY      - The AWS access key for Bedrock services, dynamically constructed as "${ENV}_${TENANT}_AWS_BEDROCK_ACCESS_KEY".
# AWS_BEDROCK_SECRET_KEY      - The AWS secret key for Bedrock services, dynamically constructed as "${ENV}_${TENANT}_AWS_BEDROCK_SECRET_KEY".
# AWS_BEDROCK_SESSION_TOKEN   - The AWS session token for Bedrock services, dynamically constructed as "${ENV}_${TENANT}_AWS_BEDROCK_SESSION_TOKEN".
# AWS_BEDROCK_REGION          - The AWS region for Bedrock services, dynamically constructed as "${ENV}_${TENANT}_AWS_BEDROCK_REGION".
# UI_LOGGER_NAME              - The logger name used by the UI.

# Construct the variable names

# Default Provider and Model Var
DEFAULT_API_PROVIDER_VAR="${ENV}_${TENANT}_DEFAULT_API_PROVIDER"
DEFAULT_MODEL_VAR="${ENV}_${TENANT}_DEFAULT_MODEL"

# OpenAI Config
AZURE_OPENAI_API_KEY_VAR="${ENV}_${TENANT}_AZURE_OPENAI_API_KEY"
OPENAI_API_VERSION_VAR="${ENV}_${TENANT}_OPENAI_API_VERSION"
OPENAI_API_KEY_VAR="${ENV}_${TENANT}_OPENAI_API_KEY"
OPENAI_BASE_URL_VAR="${ENV}_${TENANT}_OPENAI_BASE_URL"

# Anthropic config
ANTHROPIC_BASE_URL_VAR="${ENV}_${TENANT}_ANTHROPIC_BASE_URL"
ANTHROPIC_API_KEY_VAR="${ENV}_${TENANT}_ANTHROPIC_API_KEY"

# Bedrock config
ANTHROPIC_BEDROCK_BASE_URL_VAR="${ENV}_${TENANT}_ANTHROPIC_BEDROCK_BASE_URL"
AWS_BEDROCK_ACCESS_KEY_VAR="${ENV}_${TENANT}_AWS_BEDROCK_ACCESS_KEY"
AWS_BEDROCK_SECRET_KEY_VAR="${ENV}_${TENANT}_AWS_BEDROCK_SECRET_KEY"
AWS_BEDROCK_SESSION_TOKEN_VAR="${ENV}_${TENANT}_AWS_BEDROCK_SESSION_TOKEN"
AWS_BEDROCK_REGION_VAR="${ENV}_${TENANT}_AWS_BEDROCK_REGION"

# App related config
APP_PASSCODE_KEY_VAR="${ENV}_${TENANT}_APP_PASSCODE_KEY"
SENTRY_ENVIRONMENT_VAR="${ENV}_${TENANT}_SENTRY_ENVIRONMENT"
IMAGE_NAME="${ENV}-${TENANT}-jarvis-backend" 
TAG=$CI_COMMIT_SHA

# Check if the environment variables are set
for VAR_NAME in "$SENTRY_ENVIRONMENT_VAR" "$DEFAULT_API_PROVIDER_VAR" "$DEFAULT_MODEL_VAR"; do
    if [ -z "${!VAR_NAME}" ]; then
        echo "The environment variable $VAR_NAME is not set."
        exit 1
    fi
done

# Step 1: Get the Instance ID using the Instance Name
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
  --query "Reservations[].Instances[].[InstanceId]" \
  --output text)

# Check if INSTANCE_ID was retrieved
if [ -z "$INSTANCE_ID" ]; then
  echo "Instance ID not found for instance name: $INSTANCE_NAME"
  exit 1
fi

# Step 2: Send the SSM Command to Execute Docker Operations
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters commands="[
    'aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com',
    'sudo docker images | grep $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_NAME | awk \"{print \$3}\" | xargs -r sudo docker rmi',
    'sudo docker pull $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_NAME:$TAG',
    'sudo docker stop jarvis-backend || true',
    'sudo docker rm jarvis-backend || true',
    'sudo docker run -d --name jarvis-backend -p 80:5001 \
    -e APP_PASSCODE_KEY=${!APP_PASSCODE_KEY_VAR} \
    -e DEFAULT_API_PROVIDER=${!DEFAULT_API_PROVIDER_VAR} \
    -e DEFAULT_MODEL=${!DEFAULT_MODEL_VAR} \
    -e AZURE_OPENAI_API_KEY=${!AZURE_OPENAI_API_KEY_VAR} \
    -e OPENAI_API_VERSION=${!OPENAI_API_VERSION_VAR} \
    -e OPENAI_API_KEY=${!OPENAI_API_KEY_VAR} \
    -e OPENAI_BASE_URL=${!OPENAI_BASE_URL_VAR} \
    -e ANTHROPIC_BASE_URL=${!ANTHROPIC_BASE_URL_VAR} \
    -e ANTHROPIC_API_KEY=${!ANTHROPIC_API_KEY_VAR} \
    -e ANTHROPIC_BEDROCK_BASE_URL=${!ANTHROPIC_BEDROCK_BASE_URL_VAR} \
    -e AWS_BEDROCK_ACCESS_KEY=${!AWS_BEDROCK_ACCESS_KEY_VAR} \
    -e AWS_BEDROCK_SECRET_KEY=${!AWS_BEDROCK_SECRET_KEY_VAR} \
    -e AWS_BEDROCK_SESSION_TOKEN=${!AWS_BEDROCK_SESSION_TOKEN_VAR} \
    -e AWS_BEDROCK_REGION=${!AWS_BEDROCK_REGION_VAR} \
    -e ENABLE_SENTRY=$ENABLE_SENTRY \
    -e SENTRY_DSN=$SENTRY_DSN \
    -e SENTRY_ENVIRONMENT=${!SENTRY_ENVIRONMENT_VAR} \
    -e SENTRY_RELEASE=$SENTRY_RELEASE \
    -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
    -e UI_LOGGER_NAME=$UI_LOGGER_NAME \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_NAME:$TAG'
  ]" \
  --query "Command.CommandId" \
  --output text)

# Check if the Command ID was retrieved
if [ -z "$COMMAND_ID" ]; then
  echo "Failed to send SSM command."
  exit 1
fi

# Step 3: Wait for the Command to Complete
aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --output text --query 'Status'
