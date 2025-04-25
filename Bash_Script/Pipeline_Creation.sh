#!/bin/bash

set -euo pipefail
set -x

ENVIRONMENT="${1:-us}"
SOURCE_BUCKET="ravi-pipeline-template"
DEST_BUCKET="ravi-artifact-bucket"
VAR_FILE="var.txt"

copy_templates_to_perm_bucket() {
  local app_name="$1"

  case "$app_name" in
    "usdev-usw2-common-initial-setup")
      printf '%s\n' "--------------------------------------------------------------------"
      printf '%s\n'"APP_NAME exists: %s, updating source_bucket location\n" "$app_name"
      SOURCE_BUCKET="ravi-pipeline-template/usw2-common-initial-setup-pipeline"
      ;;
    "usv1-generic-init-create")
      printf '%s\n' "--------------------------------------------------------------------"
      printf '%s\n'"APP_NAME exists: %s, updating source_bucket location\n" "$app_name"
      SOURCE_BUCKET="ravi-pipeline-template/generic-init-create-pipeline"
      ;;
    *)
      echo "--------------------------------------------------------------------\n"
      SOURCE_BUCKET="ravi-pipeline-template"
      printf '%s\n'"APP_NAME does not match special cases: %s, using default source_bucket\n" "$app_name"
      ;;
  esac

  local dest_prefix="s3://${DEST_BUCKET}/dev-pipeline-yaml/${app_name}-pipeline"
  local source_prefix="s3://${SOURCE_BUCKET}"

  if [[ "$app_name" == "usdev-usw2-common-initial-setup" ]]; then
    aws s3 cp "${source_prefix}/usdev-usw2-common-initial-setup-pipeline-main.yaml" "${dest_prefix}/${app_name}-pipeline-main.yaml"
    aws s3 cp "${source_prefix}/usdev-usw2-common-initial-setup-pipeline-roles.yaml" "${dest_prefix}/${app_name}-pipeline-roles.yaml"
    aws s3 cp "${source_prefix}/usdev-usw2-common-initial-setup-pipeline.yaml" "${dest_prefix}/${app_name}-pipeline.yaml"
  elif [[ "$app_name" == "usv1-generic-init-create" ]]; then
    aws s3 cp "${source_prefix}/generic-init-codepipline-main.yaml" "${dest_prefix}/${app_name}-pipeline-main.yaml"
    aws s3 cp "${source_prefix}/generic-init-codepipline-roles.yaml" "${dest_prefix}/${app_name}-pipeline-roles.yaml"
    aws s3 cp "${source_prefix}/generic-init-codepipline.yaml" "${dest_prefix}/${app_name}-pipeline.yaml"
  else
    aws s3 cp "${source_prefix}/generic-be-codepipline-main.yaml" "${dest_prefix}/${app_name}-pipeline-main.yaml"
    aws s3 cp "${source_prefix}/generic-be-codepipline-roles.yaml" "${dest_prefix}/${app_name}-pipeline-roles.yaml"
    aws s3 cp "${source_prefix}/generic-be-codepipline.yaml" "${dest_prefix}/${app_name}-pipeline.yaml"
  fi
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

  local artifact_bucket_name="usdev-cloudformation-artifacts"
  local bucket_object_path="dev/${app_name}/terraform.tfstate"
  local buildspec_file_name_apply="config/common_initial_setup/buildspec-apply.yaml"
  local buildspec_file_name_plan="config/common_initial_setup/buildspec-plan.yaml"
  local country_env="usdev"
  local deployment_region="usw2"
  local dynamodb_table_name="usnp-usw2-terraform-state-locking-table"
  local region="us"
  local statefile_bucket="usnp-usw2-terraform-statefile-bucket"
  local variable_file_path="tfvars_file/us_account/usw2/${app_name}.tfvars"

  local roles_template_url="https://${DEST_BUCKET}.s3.us-east-1.amazonaws.com/dev-pipeline-yaml/${app_name}-pipeline/${app_name}-pipeline-roles.yaml"
  local codepipeline_template_url="https://${DEST_BUCKET}.s3.us-east-1.amazonaws.com/dev-pipeline-yaml/${app_name}-pipeline/${app_name}-pipeline.yaml"
  local template_url="https://${DEST_BUCKET}.s3.us-east-1.amazonaws.com/dev-pipeline-yaml/${app_name}-pipeline/${app_name}-pipeline-main.yaml"
  local stack_name="${app_name}-pipeline-stack"

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
  fi

  if aws cloudformation describe-stacks --stack-name "$stack_name" >/dev/null 2>&1; then
    aws cloudformation update-stack \
      --stack-name "$stack_name" \
      --template-url "$template_url" \
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
  local pattern="^\[PIPELINE\]"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ $pattern ]]; then
      if [[ -n "$block" ]]; then
        eval "$block"
        copy_templates_to_perm_bucket "$APP_NAME"
        create_or_update_pipeline "$APP_NAME" "$CODEBUILD_IMAGE" "$BUILDSPEC_FILE" "$GITHUB_REPO_NAME" "$GITHUB_REPO_BRANCH" "$GITHUB_USER" "$GITHUB_TOKEN" "$TAGS" "$PIPELINE_TYPE" "$BUCKET_NAME" "$OBJECTKEY" "$PARAMETERS_FILE" "$SAM_INPUT_FILE" "$SAM_OUTPUT_FILE"
        block=""
      fi
    else
      block+="${line}"$'\n'
    fi
  done < "$VAR_FILE"

  if [[ -n "$block" ]]; then
    eval "$block"
    copy_templates_to_perm_bucket "$APP_NAME"
    create_or_update_pipeline "$APP_NAME" "$CODEBUILD_IMAGE" "$BUILDSPEC_FILE" "$GITHUB_REPO_NAME" "$GITHUB_REPO_BRANCH" "$GITHUB_USER" "$GITHUB_TOKEN" "$TAGS" "$PIPELINE_TYPE" "$BUCKET_NAME" "$OBJECTKEY" "$PARAMETERS_FILE" "$SAM_INPUT_FILE" "$SAM_OUTPUT_FILE"
  fi
}

main() {
  if ! validate_var_file; then
    printf '%s\n'"Validation failed. Check var.txt\n" >&2
    return 1
  fi

  if [[ ! -f "$VAR_FILE" ]]; then
    printf '%s\n'"Error: Variable file %s not found\n" "$VAR_FILE" >&2
    return 1
  fi

  process_pipeline_blocks
}


validate_var_file() {
  local file="var.txt"
  local app_names=()
  local current_block=""
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^\[PIPELINE\] ]]; then
      if [[ -n "$current_block" ]]; then
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
    else
      current_block+="$line"$'\n'
    fi
  done < "$file"

  # Check last block
  if [[ -n "$current_block" ]]; then
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


main "$@"
