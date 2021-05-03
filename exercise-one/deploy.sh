#!/usr/bin/bash

# Fail hard, fail fast!
set -euo pipefail
IFS=$'\n\t'

# Direct entry to script path dir
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Custom Variables - Modify accordingly to needs
DATE=$(date '+%m%d%Y')
S3_BUCKET_NAME="fortune-exercise-${DATE}"
TEMPLATE_PATH="${SCRIPT_DIR}/deplyment/template.yaml"
OUTPUT_TEMPLATE_NAME="fortune-exercise-pkg"

# Move to deployment dir
echo "Moving to deployment dir..."
cd "${SCRIPT_DIR}"/deployment

echo "Checking bucket existance..."
# Create tmp file to grep from
aws s3 ls > tmp.txt

# Generate an S3 Bucket to store lambda package & remove tmp.txt
if [[ -n $(grep "${S3_BUCKET_NAME}" tmp.txt) ]]
then
    echo -e "\033[1;33mS3 bucket (\033[0;1m${S3_BUCKET_NAME}\033[1;33m) already exists\033[0m"
else
    aws s3 mb "s3://${S3_BUCKET_NAME}"
    aws s3 
    echo -e "\033[1;32mCreated S3 bucket:\n\033[0;1m${S3_BUCKET_NAME}\033[0m"
fi
rm -rf tmp.txt

# Install requirements before packaging files
cd "${SCRIPT_DIR}/fortune_handler"
if [[ ! -d "${SCRIPT_DIR}/deployment/deps/python" ]]
then
    mkdir -p "${SCRIPT_DIR}/deployment/deps/python/lib/python3.8/site-packages"
fi

# Install python dependencies
python3 -m pip install --target="${SCRIPT_DIR}/deployment/deps/python/lib/python3.8/site-packages" \
-r "${SCRIPT_DIR}/fortune_handler/requirements.txt"
python3 -m pip install --target="${SCRIPT_DIR}/deployment/deps/python/" \
-r "${SCRIPT_DIR}/fortune_handler/requirements.txt"


if [[ ${1} == "-pkg" ]] || [[ ${1} == "--package" ]] 
then 
    echo "Packaging Lambda files to S3"
    # Use provided template to package lambda if desired
    aws cloudformation package \
        --template /"${TEMPLATE_PATH}" \
        --s3-bucket "${S3_BUCKET_NAME}" \
        --output yaml > ${OUTPUT_TEMPLATE_NAME}.yaml
    rm -rf ./*.zip

elif [[ ${1} == "--sam-build" ]] || [[ ${1} == "-sam" ]];
then
    sam build -t "${SCRIPT_DIR}/deployment/template.yaml" -b "${SCRIPT_DIR}/fortune_handler"
    echo "Completed the SAM build command within local environ"
else
    # copy packages over manually to S3 instead
    zip -r deployment.zip -x "${SCRIPT_DIR}/deployment/deps/"*
    cd "${SCRIPT_DIR}/deployment/deps"
    zip -r "${SCRIPT_DIR}"/layers_pyv38.zip "./python"
    aws s3 cp ./layers_pyv38.zip "s3://${S3_BUCKET_NAME}"
    cd "${SCRIPT_DIR}" && rm -rf "${SCRIPT_DIR}/deployment/deps"
    aws s3 cp ./deployment/*.yml
    zip -r cfn.zip "${SCRIPT_DIR}/deployment"
    aws s3 cp ./cfn.zip "s3://${S3_BUCKET_NAME}"
    aws s3 cp ./deployment.zip "s3://${S3_BUCKET_NAME}" && rm -rf "${SCRIPT_DIR}"/*.zip
fi


