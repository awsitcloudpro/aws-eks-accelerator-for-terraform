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
# This script can be used to create an external data source for AMP scraper
# until the AWS provider provides it
# Example input format: {"scraper_id": "s-xx-xx-xx-xx-xx"}
###########################################################################

# jq is required for this script to work, exit if it isn't present
which jq &> /dev/null

if [ $? -ne 0 ]
then
  echo "The json parsing package 'jq' is required to run this script, please install it before continuing"
  exit 1
fi

set -e #fail if any of our subcommands fail

# Load the JSON passed in from Terraform into a variable
eval "$(jq -r '@sh "scraperId=\(.scraper_id)"')"

scraperData=$( aws amp describe-scraper --scraper-id $scraperId )

echo $scraperData | jq '{id: .scraper.scraperId, arn: .scraper.arn, role_arn: .scraper.roleArn}'
