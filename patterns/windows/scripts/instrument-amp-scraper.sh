#!/bin/bash
###########################################################################
# © 2024 Amazon Web Services, Inc. or its affiliates. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License. 
###########################################################################

###########################################################################
# This script adds AWS IAM - K8s RBAC role mapping 
# for the AMP managed collector (scraper)
# See "Usage" below for arguments
###########################################################################

# jq is required for this script to work, exit if it isn't present
which jq &> /dev/null

if [ $? -ne 0 ]
then
  echo "The json parsing package 'jq' is required to run this script, please install it before continuing"
  exit 1
fi

if [[ $# -lt 2 ]]; then
  cat <<- EOF
    Usage: ./instrument-scraper.sh scraper-role-arn scraper-user-name
     E.g.: ./instrument-scraper.sh "arn:aws:iam::account-id:role/aws-service-role/scraper.aps.amazonaws.com/AWSServiceRoleForAmazonPrometheusScraper_xxxx" aps-collector-user
EOF
  exit 10
fi

roleArn=$1
userName=$2

accountId=$( echo $roleArn | cut -d':' -f5 )
roleName=$( echo $roleArn | cut -d'/' -f4 )

patchFile=./.aws-auth-patch.yaml

# Get existing role mappings from the aws-auth ConfigMap
awsAuthK8sRoleMap=$(kubectl get cm -n kube-system aws-auth -o json | jq -r '.data.mapRoles' | sed 's/^/    /')

# Add scraper role mapping
cat << EOF > $patchFile
data:
  mapRoles: |
$awsAuthK8sRoleMap
    - "rolearn": "arn:aws:iam::${accountId}:role/${roleName}"
      "username": "$userName"
EOF

# Patch the aws-auth ConfigMap
kubectl patch cm -n kube-system aws-auth --patch-file=$patchFile