# SAP LogServ PowerShell Script
# Windows PowerShell version of the bash script

# TODO: Replace these placeholder values with your actual Azure configuration
$TENANT_ID = "YOUR-TENANT-ID-HERE"
$CLIENT_ID = "YOUR-CLIENT-ID-HERE"
$CLIENT_SECRET = "YOUR-CLIENT-SECRET-HERE"
$DCE_URI = "YOUR-DCE-HOSTNAME-HERE"
$DCR_ID = "YOUR-DCR-IMMUTABLE-ID-HERE"

$SCOPE = "https://monitor.azure.com/.default"

# Calculate timestamp (current time in Unix format)
$TIMESTAMP = [int][double]::Parse((Get-Date -UFormat %s))

Write-Host "Getting authentication token for Data Collection Endpoint from Entra ID..."

# Get the token
$tokenBody = @{
    client_id     = $CLIENT_ID
    client_secret = $CLIENT_SECRET
    scope         = $SCOPE
    grant_type    = "client_credentials"
}

$tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" `
    -Method Post `
    -ContentType "application/x-www-form-urlencoded" `
    -Body $tokenBody

$MONITOR_JWT_TOKEN = $tokenResponse.access_token

$UPLOAD_URI = "https://$DCE_URI.ingest.monitor.azure.com/dataCollectionRules/$DCR_ID/streams/Custom-SAPLogServ_CL?api-version=2023-01-01"

Write-Host "Posting sample LogServ JSON data with current time($TIMESTAMP) to $UPLOAD_URI"

# Create JSON payload
$jsonPayload = @(
    @{
        "_time"         = $TIMESTAMP
        "host"          = "hec53v013858"
        "_raw"          = "2023-05-15T01:15:19.548148+00:00 hec53v013858 kernel: [217869.768664] FWD_DROP IN=eth0 OUT=vti1 MAC=02:6f:66:44:44:cc:02:81:12:21:97:60:08:00 SRC=10.186.74.172 DST=147.204.150.31 LEN=60 TOS=0x00 PREC=0x00 TTL=63 ID=26760 DF PROTO=TCP SPT=15080 DPT=8065 WINDOW=26883 RES=0x00 SYN URGP=0 "
        "source"        = "/var/log/firewall"
        "cribl_breaker" = "fallback"
        "index"         = "hec53_os"
        "sourcetype"    = "linux_secure"
        "clz_dir"       = "linux"
        "clz_subdir"    = "linux_secure"
        "cribl_pipe"    = "CGS_filemonitor_P"
    }
)

# Convert to JSON
$jsonBody = $jsonPayload | ConvertTo-Json -Depth 10

# Send the request
try {
    $headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $MONITOR_JWT_TOKEN"
    }
    
    $response = Invoke-WebRequest -Uri $UPLOAD_URI `
        -Method Post `
        -Headers $headers `
        -Body $jsonBody
    
    Write-Host "Success!" -ForegroundColor Green
    Write-Host "HTTP Status Code: $($response.StatusCode) - $($response.StatusDescription)" -ForegroundColor Green
    Write-Host "Response Content:" -ForegroundColor Green
    if ($response.Content) {
        try {
            $responseJson = $response.Content | ConvertFrom-Json
            Write-Host ($responseJson | ConvertTo-Json -Depth 10)
        }
        catch {
            Write-Host $response.Content
        }
    } else {
        Write-Host "No response content"
    }
}
catch {
    Write-Host "Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    
    # Handle different types of HTTP errors
    if ($_.Exception -is [Microsoft.PowerShell.Commands.HttpResponseException]) {
        Write-Host "HTTP Status Code: $($_.Exception.Response.StatusCode)"
        Write-Host "Response content: $($_.ErrorDetails.Message)"
    }
    elseif ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode)"
        if ($_.ErrorDetails) {
            Write-Host "Error Details: $($_.ErrorDetails.Message)"
        }
    }
}
