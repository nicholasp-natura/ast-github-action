#!/bin/bash

output_file=./output.log

SCAN_TYPES="${INPUT_SCAN_TYPES}"
CONTAINER_IMAGES="${INPUT_CONTAINER_IMAGES}"

additional_args=()
if [ -n "${SCAN_TYPES}" ]; then
  additional_args+=("--scan-types" "${SCAN_TYPES}")
fi
if [ -n "${CONTAINER_IMAGES}" ]; then
  additional_args+=("--container-images" "${CONTAINER_IMAGES}")
fi

eval "arr=(${ADDITIONAL_PARAMS})"

/app/bin/cx scan create \
  --project-name "${PROJECT_NAME}" \
  -s "${SOURCE_DIR}" \
  --branch "${BRANCH#refs/heads/}" \
  "${additional_args[@]}" \
  --scan-info-format json \
  --agent "Github Action" \
  "${arr[@]}" | tee -i $output_file  
exitCode=${PIPESTATUS[0]}

scanId=(`grep -E '"(ID)":"((\\"|[^"])*)"' $output_file | cut -d',' -f1 | cut -d':' -f2 | tr -d '"'`)

echo "cxcli=$(cat $output_file | tr -d '\r\n')" >> $GITHUB_OUTPUT

if [ -n "$scanId" ] && [ -n "${PR_NUMBER}" ]; then
  echo "Creating PR decoration for scan ID:" $scanId
  /app/bin/cx utils pr github --scan-id "${scanId}" --namespace "${NAMESPACE}" --repo-name "${REPO_NAME}" --pr-number "${PR_NUMBER}" --token "${GITHUB_TOKEN}"
else
  echo "PR decoration not created."
fi


if [ -n "$scanId" ]; then
  /app/bin/cx results show --scan-id "${scanId}" --report-format markdown
  cat ./cx_result.md >$GITHUB_STEP_SUMMARY
  rm ./cx_result.md
  echo "cxScanID=$scanId" >> $GITHUB_OUTPUT
fi

if [ $exitCode -eq 0 ]
then
  echo "Scan completed"
else
  echo "Scan failed"
  exit $exitCode
fi