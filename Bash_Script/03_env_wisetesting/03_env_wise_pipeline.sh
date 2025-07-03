#!/bin/bash
source var.txt

# This script is used to set up the environment for the pipeline.
set -euo pipefail
set -x

ENVIRONMENT="${1:-usv1}"
ENVIRONMENT1="${2:-usdev}" 

PIP="pipeline"
VAR_FILE="var.txt"

copy_templates_to_perm_bucket() {
  echo "Processing template for: $app_name"
  local s3_path="s3://${dest_bucket}/${app_name}-${PIP}"

  aws s3 cp "$template_dir/main.yaml"    "$s3_path/${app_name}-${PIP}-main.yaml" --region "$REGION"
  aws s3 cp "$template_dir/pipeline.yaml" "$s3_path/${app_name}-${PIP}.yaml" --region "$REGION"
  aws s3 cp "$template_dir/roles.yaml"   "$s3_path/${app_name}-${PIP}-roles.yaml" --region "$REGION"

  echo "✅ Templates uploaded directly to: $s3_path"
}

create_or_update_pipeline() {
    # List of application names
    local app_names=(
      "$ENVIRONMENT-generic-be-ec2-create" 
      "$ENVIRONMENT-generic-ec2-create" 
      "$ENVIRONMENT-generic-fe-create"
      "$ENVIRONMENT-generic-be-create"
      "$ENVIRONMENT-generic-init-create"
    )
    for app_name in "${app_names[@]}"; do
        # Copy templates to the destination bucket
        copy_templates_to_perm_bucket "$app_name"
        local roles_template_url="https://${dest_bucket}.s3.${REGION}.amazonaws.com/${app_name}-${PIP}/${app_name}-${PIP}-roles.yaml"
        local codepipeline_template_url="https://${dest_bucket}.s3.${REGION}.amazonaws.com/${app_name}-${PIP}/${app_name}-${PIP}.yaml"
        local template_url="https://${dest_bucket}.s3.${REGION}.amazonaws.com/${app_name}-${PIP}/${app_name}-${PIP}-main.yaml"

        local stack_name="${app_name}-${PIP}"
        echo "Processing pipeline for: $app_name"

        aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-url "$template_url" \
            --region "$REGION" \
            --parameters \
                ParameterKey=AppName,ParameterValue="$app_name" \
                ParameterKey=CodeBuildImage,ParameterValue="$codebuild_image" \
                ParameterKey=CodePipelineTemplateURL,ParameterValue="$codepipeline_template_url" \
                ParameterKey=GitHubRepoBranch,ParameterValue="$github_repo_branch" \
                ParameterKey=GitHubRepoName,ParameterValue="$github_repo_name" \
                ParameterKey=GitHubUser,ParameterValue="$github_user" \
                ParameterKey=GitHubToken,ParameterValue="$github_token" \
                ParameterKey=BuildSpecFileName,ParameterValue="$buildspec_file" \
                ParameterKey=BucketName,ParameterValue="$bucket_name" \
                ParameterKey=ObjectKey,ParameterValue="$objectkey" \
                ParameterKey=RolesTemplateURL,ParameterValue="$roles_template_url" \
            --tags $tags \
            --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

        printf '%s\n' "Sleeping 30 seconds after create-stack for stack: $stack_name"
        sleep 30
    done
}

main() {
  if [[ ! -f "$VAR_FILE" ]]; then
    printf '❌ Error: Variable file %s not found\n' "$VAR_FILE" >&2
    return 1
  fi
  create_or_update_pipeline

}

# Start script
main
