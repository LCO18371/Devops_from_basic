#!/bin/bash

# Set the environment (dev, stg, qa, etc.)
ENVIRONMENT="${1:-dev}"  # Default to 'dev' if no argument is provided

# Source and destination S3 buckets
SOURCE_BUCKET="template-yaml/be-pipeline"
DEST_BUCKET="pipeline-yaml-files"

# Function to copy templates from source to destination S3 bucket
copy_templates_to_perm_bucket() {
  local APP_NAME="$1"
  # Copy templates to the destination bucket
  aws s3 cp "s3://${SOURCE_BUCKET}/pipeline-roles.yaml" "s3://${DEST_BUCKET}/health-component/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline-roles.yaml"
  aws s3 cp "s3://${SOURCE_BUCKET}/dev-pipeline.yaml" "s3://${DEST_BUCKET}/health-component/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline.yaml"
  aws s3 cp "s3://${SOURCE_BUCKET}/pipeline-main.yaml" "s3://${DEST_BUCKET}/health-component/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline-main.yaml"
}

# Function to create or update a pipeline using parameters
create_or_update_pipeline() {
  local APP_NAME="$1"
  local PARAMETERS_FILE="$2"
  local SAM_INPUT_FILE="$3"
  local SAM_OUTPUT_FILE="$4"
  local CODEBUILD_IMAGE="$5"
  local BUILDSPEC_FILE="$6"
  local GITHUB_REPO_NAME="$7"
  local GITHUB_REPO_BRANCH="$8"
  local GITHUB_USER="$9"
  local GITHUB_TOKEN="${10}"
  local TAGS="${11}"  # Tags as Key=Value pairs

  # Construct S3 URLs based on APP_NAME
  local ROLES_TEMPLATE_URL="https://${DEST_BUCKET}.s3.us-east-1.amazonaws.com/health-component/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline-roles.yaml"
  local CODEPIPELINE_TEMPLATE_URL="https://${DEST_BUCKET}.s3.us-east-1.amazonaws.com/health-component/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline.yaml"
  local TEMPLATE_URL="https://${DEST_BUCKET}.s3.us-east-1.amazonaws.com/health-component/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline-main.yaml"

  echo "Calling the URLs: ${ROLES_TEMPLATE_URL}, ${CODEPIPELINE_TEMPLATE_URL}, ${TEMPLATE_URL}"
  
  local STACK_NAME="${APP_NAME}-pipeline"

  echo "Checking if stack exists: $STACK_NAME"
  
  # Check if the stack exists
  if aws cloudformation describe-stacks --stack-name "$STACK_NAME" >/dev/null 2>&1; then
    echo "Updating stack: $STACK_NAME"
    # Update the CloudFormation stack
    aws cloudformation update-stack \
      --stack-name "$STACK_NAME" \
      --template-url "$TEMPLATE_URL" \
      --parameters ParameterKey=AppName,ParameterValue="$APP_NAME" \
                   ParameterKey=ParametersFile,ParameterValue="$PARAMETERS_FILE" \
                   ParameterKey=SAMInputFile,ParameterValue="$SAM_INPUT_FILE" \
                   ParameterKey=SAMOutputFile,ParameterValue="$SAM_OUTPUT_FILE" \
                   ParameterKey=CodeBuildImage,ParameterValue="$CODEBUILD_IMAGE" \
                   ParameterKey=BuildSpecFileNameForAPI,ParameterValue="$BUILDSPEC_FILE" \
                   ParameterKey=GitHubRepoName,ParameterValue="$GITHUB_REPO_NAME" \
                   ParameterKey=GitHubRepoBranch,ParameterValue="$GITHUB_REPO_BRANCH" \
                   ParameterKey=GitHubUser,ParameterValue="$GITHUB_USER" \
                   ParameterKey=GitHubToken,ParameterValue="$GITHUB_TOKEN" \
                   ParameterKey=RolesTemplateURL,ParameterValue="$ROLES_TEMPLATE_URL" \
                   ParameterKey=CodePipelineTemplateURL,ParameterValue="$CODEPIPELINE_TEMPLATE_URL" \
      --tags $TAGS \
      --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
    echo "Stack updated: $STACK_NAME"
  
else
    echo "Creating stack: $STACK_NAME"
    # Create the CloudFormation stack
    aws cloudformation create-stack \
      --stack-name "$STACK_NAME" \
      --template-url "$TEMPLATE_URL" \
      --parameters ParameterKey=AppName,ParameterValue="$APP_NAME" \
                   ParameterKey=ParametersFile,ParameterValue="$PARAMETERS_FILE" \
                   ParameterKey=SAMInputFile,ParameterValue="$SAM_INPUT_FILE" \
                   ParameterKey=SAMOutputFile,ParameterValue="$SAM_OUTPUT_FILE" \
                   ParameterKey=CodeBuildImage,ParameterValue="$CODEBUILD_IMAGE" \
                   ParameterKey=BuildSpecFileNameForAPI,ParameterValue="$BUILDSPEC_FILE" \
                   ParameterKey=GitHubRepoName,ParameterValue="$GITHUB_REPO_NAME" \
                   ParameterKey=GitHubRepoBranch,ParameterValue="$GITHUB_REPO_BRANCH" \
                   ParameterKey=GitHubUser,ParameterValue="$GITHUB_USER" \
                   ParameterKey=GitHubToken,ParameterValue="$GITHUB_TOKEN" \
                   ParameterKey=RolesTemplateURL,ParameterValue="$ROLES_TEMPLATE_URL" \
                   ParameterKey=CodePipelineTemplateURL,ParameterValue="$CODEPIPELINE_TEMPLATE_URL" \
      --tags $TAGS \
      --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
  fi
  
  if [ $? -ne 0 ]; then
    echo "Error processing stack: $STACK_NAME"
  else
    echo "Stack processed: $STACK_NAME"
  fi
}

# Function to process each pipeline block in sample-var.txt
process_pipeline_blocks() {
  local BLOCK=""
  local PIPELINE_START_PATTERN="^\[PIPELINE\]"
  
  while IFS= read -r LINE; do
    if [[ $LINE =~ $PIPELINE_START_PATTERN ]]; then
      # Process the previous block if it exists
      if [ -n "$BLOCK" ]; then
        eval "$BLOCK"  # Evaluate the block to set environment variables
        # Copy templates to the permanent bucket
        copy_templates_to_perm_bucket "$APP_NAME"
        # Create or update the pipeline using the extracted parameters in the background
        create_or_update_pipeline "$APP_NAME" "$PARAMETERS_FILE" "$SAM_INPUT_FILE" "$SAM_OUTPUT_FILE" "$CODEBUILD_IMAGE" "$BUILDSPEC_FILE" "$GITHUB_REPO_NAME" "$GITHUB_REPO_BRANCH" "$GITHUB_USER" "$GITHUB_TOKEN" "$TAGS" &
        BLOCK=""  # Reset the block for the next iteration
      fi
    else
      BLOCK="$BLOCK$LINE"$'\n'  # Append line to the current block
    fi
  done < "var.txt"

  # Process the last block if it doesn't end with a delimiter
  if [ -n "$BLOCK" ]; then
echo "Evaluating BLOCK: $BLOCK"  
 eval "$BLOCK"
    # Copy templates to the permanent bucket
    copy_templates_to_perm_bucket "$APP_NAME"
    create_or_update_pipeline "$APP_NAME" "$PARAMETERS_FILE" "$SAM_INPUT_FILE" "$SAM_OUTPUT_FILE" "$CODEBUILD_IMAGE" "$BUILDSPEC_FILE" "$GITHUB_REPO_NAME" "$GITHUB_REPO_BRANCH" "$GITHUB_USER" "$GITHUB_TOKEN" "$TAGS" &
  fi
  
  # Wait for all background jobs to complete
  wait
}

# Process all pipeline blocks in sample-var.txt
process_pipeline_blocks