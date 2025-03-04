#!/bin/bash

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

#delete image
docker images | grep "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${IMAGE_NAME}" | awk '{print $3}' | xargs -r docker rmi

# Pull the latest image
docker pull $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_NAME:$TAG

# Stop and remove the existing container
docker stop jarvis-backend || true
docker rm jarvis-backend || true

# Run the new container
# docker run -d --name jarvis-backend -p 5001:5001 -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e SENTRY_DSN=$SENTRY_DSN -e SENTRY_ENVIRONMENT=$SENTRY_ENVIRONMENT -e SENTRY_RELEASE=$SENTRY_RELEASE -e ENABLE_SENTRY=$ENABLE_SENTRY -e OPENAI_API_KEY=$OPENAI_API_KEY -e DYNAMODB_VERSION_TABLE_NAME=$DYNAMODB_VERSION_TABLE_NAME -e UI_LOGGER_NAME=$UI_LOGGER_NAME -e OPENAI_BASE_URL=$OPENAI_BASE_URL $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_NAME:$BITBUCKET_COMMIT

docker run -d \
  --name jarvis-backend \
  -p 80:5001 \
  -e APP_PASSCODE_KEY=$APP_PASSCODE_KEY \
  -e DEFAULT_API_PROVIDER=$DEFAULT_API_PROVIDER \
  -e DEFAULT_MODEL=$DEFAULT_MODEL \
  -e AZURE_OPENAI_API_KEY=$AZURE_OPENAI_API_KEY \
  -e OPENAI_API_VERSION=$OPENAI_API_VERSION \
  -e OPENAI_API_KEY=$OPENAI_API_KEY \
  -e OPENAI_BASE_URL=$OPENAI_BASE_URL \
  -e ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  -e ANTHROPIC_BEDROCK_BASE_URL=$ANTHROPIC_BEDROCK_BASE_URL \
  -e AWS_BEDROCK_ACCESS_KEY=$AWS_BEDROCK_ACCESS_KEY \
  -e AWS_BEDROCK_SECRET_KEY=$AWS_BEDROCK_SECRET_KEY \
  -e AWS_BEDROCK_SESSION_TOKEN=$AWS_BEDROCK_SESSION_TOKEN \
  -e AWS_BEDROCK_REGION=$AWS_BEDROCK_REGION \
  -e ENABLE_SENTRY=$ENABLE_SENTRY \
  -e SENTRY_DSN=$SENTRY_DSN \
  -e SENTRY_ENVIRONMENT=$SENTRY_ENVIRONMENT \
  -e SENTRY_RELEASE=$SENTRY_RELEASE \
  -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
  -e UI_LOGGER_NAME=$UI_LOGGER_NAME \
  --log-driver=awslogs \
  --log-opt awslogs-region=$AWS_DEFAULT_REGION \
  --log-opt awslogs-group=/jarvis/log/group/$SENTRY_ENVIRONMENT \
  --log-opt awslogs-stream=jarvis-backend \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_NAME:$TAG
  