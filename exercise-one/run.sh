#!/usr/bin/bash

# Fail hard, fail fast!
set -euo pipefail
IFS=$'\n\t'

# Direct entry to script path dir
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Custom Variables - Modify accordingly to needs
DATE=$(date '+%m%d%Y')
S3_BUCKET_NAME="fortune-exercise-${DATE}"
TEMPLATE_PATH="${SCRIPT_DIR}/exercise-one/PackageLambda.yaml"
OUTPUT_TEMPLATE_NAME="fortune-exercise-pkg"



# Move to deployment dir
echo "Moving to exercise-one dir..."
cd "${SCRIPT_DIR}"/exercise-one

echo "Checking bucket existance..."
# Create tmp file to grep from
aws s3 ls > tmp.txt

# Generate an S3 Bucket to store lambda package & remove tmp.txt
if [[ -n $(grep "${S3_BUCKET_NAME}" tmp.txt) ]]
then
    echo -e "\033[1;33mS3 bucket (\033[0;1m${S3_BUCKET_NAME}\033[1;33m) already exists\033[0m"
else
    aws s3 mb "s3://${S3_BUCKET_NAME}"
    echo -e "\033[1;32mCreated S3 bucket:\n\033[0;1m${S3_BUCKET_NAME}\033[0m"
fi
rm -rf tmp.txt

# Install requirements before packaging files
cd "${SCRIPT_DIR}/../exercise_1"
if [[ ! -d "${SCRIPT_DIR}"/../exercise_1/packages ]]
then
    mkdir packages
fi
python3 -m pip install --target="./packages" \
-r "./fortune_handler/requirements.txt"
zip -r "${SCRIPT_DIR}"/fortune-deps.zip ./packages
cd "${SCRIPT_DIR}/exercise_one"

echo "Packaging Lambda files to S3"
# Use provided template to package lambda 
aws cloudformation package \
    --template /"${TEMPLATE_PATH}" \
    --s3-bucket "${S3_BUCKET_NAME}" \
    --output yaml > ${OUTPUT_TEMPLATE_NAME}.yaml