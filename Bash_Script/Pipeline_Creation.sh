#!/bin/bash

# Set the environment (dev, stg, qa, etc.)
ENVIRONMENT="${1:-dev}"  # Default to 'dev' if no argument is provided

# Source and destination S3 buckets
#SOURCE_BUCKET="template-yaml/be-pipeline"
SOURCE_BUCKET="ravi-pipeline-template"
DEST_BUCKET="ravi-artifact-bucket"

# Function to copy templates from source to destination S3 bucket
copy_templates_to_perm_bucket() {
  local APP_NAME="$1"
  # Copy templates to the destination bucket
  aws s3 cp "s3://${SOURCE_BUCKET}/generic-be-codepipline-main.yaml" "s3://${DEST_BUCKET}/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline-main.yaml"
  aws s3 cp "s3://${SOURCE_BUCKET}/generic-be-codepipline-roles.yaml" "s3://${DEST_BUCKET}/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline-roles.yaml"
  aws s3 cp "s3://${SOURCE_BUCKET}/generic-be-codepipline.yaml" "s3://${DEST_BUCKET}/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline.yaml"
}

# Function to create or update a pipeline using parameters
create_or_update_pipeline() {
  local APP_NAME="$1"
  local CODEBUILD_IMAGE="$2"
  local BUILDSPEC_FILE="$3"
  local GITHUB_REPO_NAME="$4"
  local GITHUB_REPO_BRANCH="$5"
  local GITHUB_USER="$6"
  local GITHUB_TOKEN="${7}"  # Object key for the S3 bucket
  local TAGS="${8}"  # Tags as Key=Value pairs
  local PIPELINE_TYPE="${9}"  # Either "frontend" or "backend"

  # Parameters for frontend pipeline
  local BUCKET_NAME="${10}"
  local OBJECTKEY="${11}"

  # Parameters for backend pipeline
  local PARAMETERS_FILE="${12}"
  local SAM_INPUT_FILE="${13}"
  local SAM_OUTPUT_FILE="${14}"

# Print all the variables
echo "APP_NAME: $APP_NAME"
echo "BUCKET_NAME: $BUCKET_NAME"
echo "CODEBUILD_IMAGE: $CODEBUILD_IMAGE"
echo "BUILDSPEC_FILE: $BUILDSPEC_FILE"
echo "GITHUB_REPO_NAME: $GITHUB_REPO_NAME"
echo "GITHUB_REPO_BRANCH: $GITHUB_REPO_BRANCH"
echo "GITHUB_USER: $GITHUB_USER"
echo "GITHUB_TOKEN: $GITHUB_TOKEN"
echo "OBJECTKEY: $OBJECTKEY"
echo "TAGS: $TAGS"
echo "PIPELINE_TYPE: $PIPELINE_TYPE"
echo "PARAMETERS_FILE: $PARAMETERS_FILE"
echo "SAM_INPUT_FILE: $SAM_INPUT_FILE"  
echo "SAM_OUTPUT_FILE: $SAM_OUTPUT_FILE"


  # Construct S3 URLs based on APP_NAME
  local ROLES_TEMPLATE_URL="https://${DEST_BUCKET}.s3.us-east-1.amazonaws.com/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline-roles.yaml"
  local CODEPIPELINE_TEMPLATE_URL="https://${DEST_BUCKET}.s3.us-east-1.amazonaws.com/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline.yaml"
  local TEMPLATE_URL="https://${DEST_BUCKET}.s3.us-east-1.amazonaws.com/dev-pipeline-yaml/${APP_NAME}-pipeline/${APP_NAME}-pipeline-main.yaml"

  echo "Calling the URLs: ${ROLES_TEMPLATE_URL}, ${CODEPIPELINE_TEMPLATE_URL}, ${TEMPLATE_URL}"
  
  local STACK_NAME="${APP_NAME}-pipeline"

  local CONDITIONAL_PARAMETERS=""
  if [ "$PIPELINE_TYPE" == "frontend" ]; then
    CONDITIONAL_PARAMETERS+="ParameterKey=BucketName,ParameterValue=$BUCKET_NAME "
    CONDITIONAL_PARAMETERS+="ParameterKey=ObjectKey,ParameterValue=$OBJECTKEY "
  elif [ "$PIPELINE_TYPE" == "backend" ]; then
    CONDITIONAL_PARAMETERS+="ParameterKey=ParametersFile,ParameterValue=$PARAMETERS_FILE "
    CONDITIONAL_PARAMETERS+="ParameterKey=SamInputFile,ParameterValue=$SAM_INPUT_FILE "
    CONDITIONAL_PARAMETERS+="ParameterKey=SamOutputFile,ParameterValue=$SAM_OUTPUT_FILE "
  fi

  echo "Checking if stack exists: $STACK_NAME"
  
  # Check if the stack exists
  if aws cloudformation describe-stacks --stack-name "$STACK_NAME-stack" >/dev/null 2>&1; then
    echo "Updating stack: $STACK_NAME-stack"
    # Update the CloudFormation stack
    aws cloudformation update-stack \
      --stack-name "$STACK_NAME-stack" \
      --template-url "$TEMPLATE_URL" \
      --parameters ParameterKey=AppName,ParameterValue="$APP_NAME" \
                   ParameterKey=BuildSpecFileName,ParameterValue="$BUILDSPEC_FILE" \
                   ParameterKey=CodeBuildImage,ParameterValue="$CODEBUILD_IMAGE" \
                   ParameterKey=CodePipelineTemplateURL,ParameterValue="$CODEPIPELINE_TEMPLATE_URL" \
                   ParameterKey=GitHubRepoBranch,ParameterValue="$GITHUB_REPO_BRANCH" \
                   ParameterKey=GitHubRepoName,ParameterValue="$GITHUB_REPO_NAME" \
                   ParameterKey=GitHubUser,ParameterValue="$GITHUB_USER" \
                   ParameterKey=GitHubToken,ParameterValue="$GITHUB_TOKEN" \
                   $CONDITIONAL_PARAMETERS \
                   ParameterKey=RolesTemplateURL,ParameterValue="$ROLES_TEMPLATE_URL" \
      --tags $TAGS \
      --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
    echo "Stack updated: $STACK_NAME"
  
else
    echo "Creating stack: $STACK_NAME"
    # Create the CloudFormation stack
    echo "================================================================="
    echo "Updating stack with TEMPLATE_URL: $TEMPLATE_URL)"
    echo "================================================================="
    echo "CODEPIPELINE_TEMPLATE_URL: $CODEPIPELINE_TEMPLATE_URL, ROLES_TEMPLATE_URL: $ROLES_TEMPLATE_URL"
    
        aws cloudformation create-stack \
            --stack-name "$STACK_NAME-stack" \
            --template-url "$TEMPLATE_URL" \
            --parameters ParameterKey=AppName,ParameterValue="$APP_NAME" \
                        ParameterKey=BuildSpecFileName,ParameterValue="$BUILDSPEC_FILE" \
                        ParameterKey=CodeBuildImage,ParameterValue="$CODEBUILD_IMAGE" \
                        ParameterKey=CodePipelineTemplateURL,ParameterValue="$CODEPIPELINE_TEMPLATE_URL" \
                        ParameterKey=GitHubRepoBranch,ParameterValue="$GITHUB_REPO_BRANCH" \
                        ParameterKey=GitHubRepoName,ParameterValue="$GITHUB_REPO_NAME" \
                        ParameterKey=GitHubUser,ParameterValue="$GITHUB_USER" \
                        ParameterKey=GitHubToken,ParameterValue="$GITHUB_TOKEN" \
                        $CONDITIONAL_PARAMETERS \
                        ParameterKey=RolesTemplateURL,ParameterValue="$ROLES_TEMPLATE_URL" \
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
        create_or_update_pipeline "$APP_NAME" "$CODEBUILD_IMAGE"  "$BUILDSPEC_FILE" "$GITHUB_REPO_NAME" "$GITHUB_REPO_BRANCH" "$GITHUB_USER" "$GITHUB_TOKEN" "$TAGS" "$PIPELINE_TYPE" "$BUCKET_NAME" "$OBJECTKEY" "$PARAMETERS_FILE" "$SAM_INPUT_FILE" "$SAM_OUTPUT_FILE" &
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
    create_or_update_pipeline "$APP_NAME" "$CODEBUILD_IMAGE"  "$BUILDSPEC_FILE" "$GITHUB_REPO_NAME" "$GITHUB_REPO_BRANCH" "$GITHUB_USER" "$GITHUB_TOKEN" "$TAGS" "$PIPELINE_TYPE" "$BUCKET_NAME" "$OBJECTKEY" "$PARAMETERS_FILE" "$SAM_INPUT_FILE" "$SAM_OUTPUT_FILE" &
            
  fi
  
  # Wait for all background jobs to complete
  wait
}


# Process all pipeline blocks in sample-var.txt
process_pipeline_blocks