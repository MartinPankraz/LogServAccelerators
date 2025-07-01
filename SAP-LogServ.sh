#!/usr/bin/bash

# TODO: Replace these placeholder values with your actual Azure configuration
TENANT_ID="YOUR-TENANT-ID-HERE"
CLIENT_ID="YOUR-CLIENT-ID-HERE"
CLIENT_SECRET="YOUR-CLIENT-SECRET-HERE"
DCE_URI="YOUR-DCE-HOSTNAME-HERE"
DCR_ID="YOUR-DCR-IMMUTABLE-ID-HERE"

SCOPE="https://monitor.azure.com/.default"  

# Calculate timestamp (current time in Unix format)
TIMESTAMP=$(date +%s)

echo "Getting authentication token for Data Collection Endpoint from Entra ID..."

# Get the token
MONITOR_JWT_TOKEN=$(curl -s -X POST \
    "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "scope=${SCOPE}" \
    -d "grant_type=client_credentials" \
    | jq -r '.access_token')

UPLOAD_URI="https://$DCE_URI.ingest.monitor.azure.com/dataCollectionRules/$DCR_ID/streams/Custom-SAPLogServ_CL?api-version=2023-01-01"

echo "Posting sample LogServ JSON data with current time($TIMESTAMP) to $UPLOAD_URI"

# Create JSON payload inline
JSON_PAYLOAD='[
    {
        "_time": '$TIMESTAMP',
        "host": "hec53v013858",
        "_raw": "2023-05-15T01:15:19.548148+00:00 hec53v013858 kernel: [217869.768664] FWD_DROP IN=eth0 OUT=vti1 MAC=02:6f:66:44:44:cc:02:81:12:21:97:60:08:00 SRC=10.186.74.172 DST=147.204.150.31 LEN=60 TOS=0x00 PREC=0x00 TTL=63 ID=26760 DF PROTO=TCP SPT=15080 DPT=8065 WINDOW=26883 RES=0x00 SYN URGP=0 ",
        "source": "/var/log/firewall",
        "cribl_breaker": "fallback",
        "index": "hec53_os",
        "sourcetype": "linux_secure",
        "clz_dir": "linux",
        "clz_subdir": "linux_secure",
        "cribl_pipe": "CGS_filemonitor_P"
    }
]'

curl \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${MONITOR_JWT_TOKEN}" \
    -d "$JSON_PAYLOAD" \
    -w "HTTP Status Code: %{http_code}\nResponse Time: %{time_total}s\n" \
    -s \
    "$UPLOAD_URI"

# Check the exit status of curl
if [ $? -eq 0 ]; then
    echo "Success! Data posted successfully."
else
    echo "Error: Failed to post data to Azure Monitor endpoint."
    exit 1
fi
 