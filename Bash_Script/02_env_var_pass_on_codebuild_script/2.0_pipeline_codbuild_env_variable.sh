#!/bin/bash

# ----------- Pipeline to Type Mapping -----------
declare -A PIPELINE_TYPE_MAP=(
  [first]="fe"
  # Add real pipeline names below:
  # [usdev-usw2-generic-fe-create-pipeline]="fe"
  # [usdev-usw2-generic-be-create-pipeline]="be"
  # [usdev-usw2-generic-ec2-create-pipeline]="ec2"
)

# ----------- FE Vars -----------
declare -A FE_VARS=(
  [REGION]="us"
  [environment_variable]="stg"
  [PIPELINE_PROJECT]="usw2-vlt-be"
  [BUILDSPECFILENAME]="config/buildspec/vlt-codebuild.yml"
  [PARAMETERSFILE]="config/properties/code/lambda.properties"
  [SAMINPUT]="config/yaml/vlt-code.yaml"
  [SAMOUTPUT]="config/yaml/post-vlt-code.yaml"
  [OHPROJECT]="vlt"
  [OHAPPLICATION]="vlt-mobile"
  [OHMODULE]="vlt-mobile-be"
  [OHENVIRONMENT]="usstg-usw2"
  [OHSTACKNAME]="usstg-usw2-vlt-be-server"
  [COUNTRY_CODE]="us"
  [ENVIRONMENT]="stg"
  [DEPLOYMENT_REGION]="usw2"
  [PROJECT]="vlt"
  [PROJECT_DETAILS]="generic"
)

# ----------- BE Vars -----------
declare -A BE_VARS=("${FE_VARS[@]}")  # Same as FE_VARS

# ----------- EC2 Vars -----------
declare -A EC2_VARS=(
  [REGION]="us"
  [environment_variable]="stg"
  [PIPELINE_PROJECT]="usw2-common-static-code"
  [BUILDSPECFILENAME]="config/buildspec/common-code.yml"
  [OHPROJECT]="common"
  [OHAPPLICATION]="common-static-code"
  [OHMODULE]="common-static-code-service"
  [OHENVIRONMENT]="usstg-usw2"
  [OHSTACKNAME]="N/A"
  [COUNTRY_CODE]="us"
  [ENVIRONMENT]="stg"
  [DEPLOYMENT_REGION]="usw2"
  [PROJECT]="common"
  [ENV_NAMES]="usstg"
  [PROJECT_NAME]="usw2-common-static-code"
  [CONFIG]="config"
  [SCRIPTS_FOLDER]="scripts"
  [APPSPEC_FOLDER]="appspec"
  [EMAIL]="awsalert.staging@ohiomail.com"
  [CRON_TIME]="N/A"
  [DATA_DIR]="static_code_analysis_report"
  [PROJECT_DETAILS]="generic"
  [EC2SERVER]="stg-ofs-user-report"
)

# ----------- Check for jq -----------
if ! command -v jq &>/dev/null; then
  echo "❌ jq is required. Please install it."
  exit 1
fi

# ----------- Main Loop -----------
for PIPELINE_NAME in "${!PIPELINE_TYPE_MAP[@]}"; do
  PIPELINE_TYPE="${PIPELINE_TYPE_MAP[$PIPELINE_NAME]}"
  echo -e "\n🔄 Processing pipeline: $PIPELINE_NAME (type: $PIPELINE_TYPE)"

  # Get correct VAR set
  declare -n VARS
  case "$PIPELINE_TYPE" in
    fe) VARS=FE_VARS ;;
    be) VARS=BE_VARS ;;
    ec2) VARS=EC2_VARS ;;
    *) echo "❌ Unknown pipeline type '$PIPELINE_TYPE'"; continue ;;
  esac

  # Get CodeBuild projects from pipeline
  pipeline_json=$(aws codepipeline get-pipeline --name "$PIPELINE_NAME")
  codebuild_projects=$(echo "$pipeline_json" | jq -r '.pipeline.stages[].actions[] | select(.actionTypeId.provider == "CodeBuild") | .configuration.ProjectName' | sort -u)

  # Loop over CodeBuild projects
  for project in $codebuild_projects; do
    echo "📦 Updating CodeBuild project: $project"

    # Get current environment settings
    current_config=$(aws codebuild batch-get-projects --names "$project")
    environment=$(echo "$current_config" | jq '.projects[0].environment')
    current_vars=$(echo "$environment" | jq '.environmentVariables')

    # Append missing vars
    updated_vars="$current_vars"
    for key in "${!VARS[@]}"; do
      value="${VARS[$key]}"
      if echo "$current_vars" | jq -e --arg name "$key" '.[] | select(.name == $name)' > /dev/null; then
        echo "  🔁 $key already exists, skipping"
      else
        echo "  ➕ Adding $key=$value"
        updated_vars=$(echo "$updated_vars" | jq --arg name "$key" --arg value "$value" \
          '. += [{"name": $name, "value": $value, "type": "PLAINTEXT"}]')
      fi
    done

    # Required fields
    type=$(echo "$environment" | jq -r '.type')
    image=$(echo "$environment" | jq -r '.image')
    computeType=$(echo "$environment" | jq -r '.computeType')

    # Update CodeBuild with new env block
    aws codebuild update-project \
      --name "$project" \
      --environment "$(jq -n \
        --arg type "$type" \
        --arg image "$image" \
        --arg computeType "$computeType" \
        --argjson environmentVariables "$updated_vars" \
        '{
          type: $type,
          image: $image,
          computeType: $computeType,
          environmentVariables: $environmentVariables
        }')" >/dev/null

    if [[ $? -eq 0 ]]; then
      echo "  ✅ $project updated successfully"
    else
      echo "  ❌ Failed to update $project"
    fi
  done
done
