#!/bin/bash
# Author: Ravi Kumar
# step 1. install awscli
# step 2. update the path in line 31.
# update the parameter for this pipeline usdev-usw2-common-initial-setup function name common_initial_setup

#pipeline name define
#pipeline1="usdev-usw2-common-initial-setup"
#pipeline2="usv1-generic-init-create"
#pipeline3="usv1-generic-be-ec2-create"
#pipeline4="usv1-generic-be-create"
#pipeline5="usv1-generic-fe-create"
#pipeline6="usv1-generic-ec2-create"


#script run command
    #./env_wise_pipeline_scrip.sh Environment Region
# Example: ./env_wise_pipeline_scrip.sh usdev usw2
#Environment = usdev or usv1 
#Region = usw2 or use1
# This script processes a variable file and creates or updates AWS CloudFormation stacks based on the defined pipelines.




set -euo pipefail
set -x

ENVIRONMENT="${1:-usv1}"
ENVIRONMENT1="${2:-usdev}" 
REGION="${3:-usw2}"
#pipeline1="usdev-usw2-common-initial-setup"
#pipeline2="usv1-generic-init-create"
#pipeline3="usv1-generic-be-ec2-create"
#pipeline4="usv1-generic-be-create"
#pipeline5="usv1-generic-fe-create"
#pipeline6="usv1-generic-ec2-create"

Pipeline1="$ENVIRONMENT1-$REGION-common-initial-setup"
Pipeline2="$ENVIRONMENT-generic-init-create"
Pipeline3="$ENVIRONMENT-generic-be-create"
Pipeline4="$ENVIRONMENT-generic-fe-create"
Pipeline5="$ENVIRONMENT-generic-ec2-create"
Pipeline6="$ENVIRONMENT-generic-be-ec2-create"
PIP="pipeline"
VAR_FILE="var.txt"

common_initial_setup() {
    local app_name="$1"
    
    # Ensure all variables are set with valid values
    local artifact_bucket_name="usdev-cloudformation-artifacts"
    local bucket_object_path="dev/usdev-usw2-common-initial-setup/terraform.tfstate"
    local buildspec_file_name_apply="config/common_initial_setup/buildspec-apply.yaml"
    local buildspec_file_name_plan="config/common_initial_setup/buildspec-plan.yaml"
    local dynamodb_table_name="usnp-usw2-terraform-state-locking-table"
    local region="us"
    local country_env="usdev"
    local deployment_region="usw2"
    local statefile_bucket="usnp-usw2-terraform-statefile-bucket"
    local variable_file_path="tfvars_file/us_account/usw2/usdev-usw2-common-initial-setup.tfvars"

    # Construct the conditional parameters string
    local conditional_parameters=""
    conditional_parameters+="ParameterKey=ArtifactBucketName,ParameterValue=${artifact_bucket_name} "
    conditional_parameters+="ParameterKey=BucketObjectPath,ParameterValue=${bucket_object_path} "
    conditional_parameters+="ParameterKey=BuildSpecFileNameApply,ParameterValue=${buildspec_file_name_apply} "
    conditional_parameters+="ParameterKey=BuildSpecFileNamePlan,ParameterValue=${buildspec_file_name_plan} "
    conditional_parameters+="ParameterKey=CountryEnv,ParameterValue=${country_env} "
    conditional_parameters+="ParameterKey=DeploymentRegion,ParameterValue=${deployment_region} "
    conditional_parameters+="ParameterKey=DynamoDBTableName,ParameterValue=${dynamodb_table_name} "
    conditional_parameters+="ParameterKey=Region,ParameterValue=${region} "
    conditional_parameters+="ParameterKey=StatefileBucket,ParameterValue=${statefile_bucket} "
    conditional_parameters+="ParameterKey=VariableFilePath,ParameterValue=${variable_file_path} "

    # Ensure conditional parameters are returned
    echo "$conditional_parameters"
}

copy_templates_to_perm_bucket() {
  local app_name="$1"
  echo "Processing template for: $app_name"

  # Path setup
  local template_dir="$TEMPLAT_DIR"
  local folder_name=""

  case "$app_name" in
    "$Pipeline1") folder_name="usw2-common-initial-setup-pipeline" ;;
    "$Pipeline2") folder_name="usv1-generic-init-create-pipeline" ;;
    "$Pipeline3") folder_name="usv1-generic-be-ec2-create-pipeline" ;;
    "$Pipeline4") folder_name="usv1-generic-default-pipeline" ;;
    "$Pipeline5") folder_name="usv1-generic-default-pipeline" ;;
    "$Pipeline6") folder_name="usv1-generic-default-pipeline" ;;
    *) 
      echo "❌ Error: Unrecognized pipeline name: $app_name"
      return 1
      ;;
  esac

  # Destination S3 folder
  local s3_path="s3://${DEST_BUCKET}/${app_name}-${PIP}"

  # Directly upload each file to S3 with renamed format
  aws s3 cp "$template_dir/$folder_name/main.yaml"    "$s3_path/${app_name}-${PIP}-main.yaml" --region "$REGION"
  aws s3 cp "$template_dir/$folder_name/pipeline.yaml" "$s3_path/${app_name}-${PIP}.yaml" --region "$REGION"
  aws s3 cp "$template_dir/$folder_name/roles.yaml"   "$s3_path/${app_name}-${PIP}-roles.yaml" --region "$REGION"

  echo "✅ Templates uploaded directly to: $s3_path"
}



create_or_update_pipeline() {
    local app_name="$1"
    local codebuild_image="$2"
    local buildspec_file="$3"
    local github_repo_name="$4"
    local github_repo_branch="$5"
    local github_user="$6"
    local github_token="$7"
    local tags="$8"
    local pipeline_type="$9"
    local bucket_name="${10}"
    local objectkey="${11}"
    local parameters_file="${12}"
    local sam_input_file="${13}"
    local sam_output_file="${14}"

    # template urls
    local roles_template_url="https://${DEST_BUCKET}.s3.${REGION}.amazonaws.com/${app_name}-$PIP/${app_name}-$PIP-roles.yaml"
    local codepipeline_template_url="https://${DEST_BUCKET}.s3.${REGION}.amazonaws.com/${app_name}-$PIP/${app_name}-$PIP.yaml"
    local template_url="https://${DEST_BUCKET}.s3.${REGION}.amazonaws.com/${app_name}-$PIP/${app_name}-$PIP-main.yaml"

    
    local conditional_parameters=""

    if [[ "$pipeline_type" == "frontend" ]]; then
        conditional_parameters+="ParameterKey=BuildSpecFileName,ParameterValue=${buildspec_file} "
        conditional_parameters+="ParameterKey=BucketName,ParameterValue=${bucket_name} "
        conditional_parameters+="ParameterKey=ObjectKey,ParameterValue=${objectkey} "
    elif [[ "$pipeline_type" == "backend" ]]; then
        conditional_parameters+="ParameterKey=BuildSpecFileName,ParameterValue=${buildspec_file} "
        conditional_parameters+="ParameterKey=ParametersFile,ParameterValue=${parameters_file} "
        conditional_parameters+="ParameterKey=SamInputFile,ParameterValue=${sam_input_file} "
        conditional_parameters+="ParameterKey=SamOutputFile,ParameterValue=${sam_output_file} "
    elif [[ "$pipeline_type" == "New_frontend" ]]; then
        conditional_parameters=$(common_initial_setup "$app_name")
    fi

    echo "Conditional Parameters: $conditional_parameters"

    # Stack name
    stack_name="${app_name}-${PIP}"
    if aws cloudformation describe-stacks --stack-name "$stack_name" >/dev/null 2>&1; then
        aws cloudformation update-stack \
        --stack-name "$stack_name" \
        --template-url "$template_url" \
        --region "$REGION" \
        --parameters ParameterKey=AppName,ParameterValue="$app_name" \
                    ParameterKey=CodeBuildImage,ParameterValue="$codebuild_image" \
                    ParameterKey=CodePipelineTemplateURL,ParameterValue="$codepipeline_template_url" \
                    ParameterKey=GitHubRepoBranch,ParameterValue="$github_repo_branch" \
                    ParameterKey=GitHubRepoName,ParameterValue="$github_repo_name" \
                    ParameterKey=GitHubUser,ParameterValue="$github_user" \
                    ParameterKey=GitHubToken,ParameterValue="$github_token" \
                    $conditional_parameters \
                    ParameterKey=RolesTemplateURL,ParameterValue="$roles_template_url" \
        --tags $tags \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
    else
        aws cloudformation create-stack \
        --stack-name "$stack_name" \
        --template-url "$template_url" \
        --region "$REGION" \
        --parameters ParameterKey=AppName,ParameterValue="$app_name" \
                    ParameterKey=CodeBuildImage,ParameterValue="$codebuild_image" \
                    ParameterKey=CodePipelineTemplateURL,ParameterValue="$codepipeline_template_url" \
                    ParameterKey=GitHubRepoBranch,ParameterValue="$github_repo_branch" \
                    ParameterKey=GitHubRepoName,ParameterValue="$github_repo_name" \
                    ParameterKey=GitHubUser,ParameterValue="$github_user" \
                    ParameterKey=GitHubToken,ParameterValue="$github_token" \
                    $conditional_parameters \
                    ParameterKey=RolesTemplateURL,ParameterValue="$roles_template_url" \
        --tags $tags \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
        printf '%s\n'"Sleeping 30 seconds after create-stack for stack: %s\n" "$stack_name"
        sleep 30
    fi
}


process_pipeline_blocks() {
  local block=""
  local inside_pipeline=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\[PIPELINE\] ]]; then
      if [[ $inside_pipeline -eq 1 && -n "$block" ]]; then
        eval "$block"
        copy_templates_to_perm_bucket "$APP_NAME"
        create_or_update_pipeline "$APP_NAME" "$CODEBUILD_IMAGE" "$BUILDSPEC_FILE" "$GITHUB_REPO_NAME" "$GITHUB_REPO_BRANCH" "$GITHUB_USER" "$GITHUB_TOKEN" "$TAGS" "$PIPELINE_TYPE" "$BUCKET_NAME" "$OBJECTKEY" "$PARAMETERS_FILE" "$SAM_INPUT_FILE" "$SAM_OUTPUT_FILE" "$SOURCE_BUCKET" "$DEST_BUCKET" "$TEMPLAT_DIR" "$REGION"
        block=""
      fi
      inside_pipeline=1
    elif [[ "$line" =~ ^\[.*\] ]]; then
      inside_pipeline=0
      block=""
    elif [[ $inside_pipeline -eq 1 ]]; then
      block+="${line}"$'\n'
    fi
  done < "$VAR_FILE"

  if [[ $inside_pipeline -eq 1 && -n "$block" ]]; then
    eval "$block"
    copy_templates_to_perm_bucket "$APP_NAME"
    create_or_update_pipeline "$APP_NAME" "$CODEBUILD_IMAGE" "$BUILDSPEC_FILE" "$GITHUB_REPO_NAME" "$GITHUB_REPO_BRANCH" "$GITHUB_USER" "$GITHUB_TOKEN" "$TAGS" "$PIPELINE_TYPE" "$BUCKET_NAME" "$OBJECTKEY" "$PARAMETERS_FILE" "$SAM_INPUT_FILE" "$SAM_OUTPUT_FILE" "$SOURCE_BUCKET" "$DEST_BUCKET" "$TEMPLAT_DIR" "$REGION"
  fi
}

main() {
  if [[ ! -f "$VAR_FILE" ]]; then
    printf 'Error: Variable file %s not found\n' "$VAR_FILE" >&2
    return 1
  fi

  # Load [GLOBAL] block variables
  extract_global_variables

  if ! validate_var_file; then
    printf 'Validation failed. Check var.txt\n' >&2
    return 1
  fi

  process_pipeline_blocks
}



validate_var_file() {
  local file="var.txt"
  local app_names=()
  local current_block=""
  local inside_pipeline=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\[PIPELINE\] ]]; then
      if [[ $inside_pipeline -eq 1 && -n "$current_block" ]]; then
        local app_name
        app_name=$(grep '^APP_NAME=' <<< "$current_block" | cut -d= -f2)
        if [[ -z "$app_name" ]]; then
          printf '%s\n'"Error: APP_NAME missing in block:\n%s\n" "$current_block" >&2
          return 1
        fi
        if [[ " ${app_names[*]} " =~ " ${app_name} " ]]; then
          printf '%s\n'"Error: Duplicate APP_NAME found: %s\n" "$app_name" >&2
          return 1
        fi
        app_names+=("$app_name")
      fi
      current_block=""
      inside_pipeline=1
    elif [[ "$line" =~ ^\[.*\] ]]; then
      inside_pipeline=0
      current_block=""
    elif [[ $inside_pipeline -eq 1 ]]; then
      current_block+="$line"$'\n'
    fi
  done < "$file"

  # Check the last block
  if [[ $inside_pipeline -eq 1 && -n "$current_block" ]]; then
    local app_name
    app_name=$(grep '^APP_NAME=' <<< "$current_block" | cut -d= -f2)
    if [[ -z "$app_name" ]]; then
      printf '%s\n' "Error: APP_NAME missing in last block:\n%s\n" "$current_block" >&2
      return 1
    fi
    if [[ " ${app_names[*]} " =~ " ${app_name} " ]]; then
      printf '%s\n' "Error: Duplicate APP_NAME found: %s\n" "$app_name" >&2
      return 1
    fi
  fi

  return 0
}

extract_global_variables() {
  local block=""
  local inside_global=0
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\[GLOBAL\] ]]; then
      inside_global=1
      continue
    elif [[ "$line" =~ ^\[.*\] ]]; then
      inside_global=0
    fi

    if [[ $inside_global -eq 1 ]]; then
      block+="$line"$'\n'
    fi
  done < "$VAR_FILE"

  if [[ -n "$block" ]]; then
    eval "$block"
  fi
}


main "$@"