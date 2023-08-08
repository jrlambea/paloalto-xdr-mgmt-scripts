# --- Classes
class EndpointRequestData {
    $request_data = @{
        "search_from" = 0
        "search_to" = 99
        "sort" = @{
            "field" = "first_seen"
            "keyword" = "DESC"
        }
    }
}

class PolicyRequestData {
    $request_data = @{
        "endpoint_id" = $null
    }
    PolicyRequestData ([string]$endpoint_id) {
        $this.request_data.endpoint_id = $endpoint_id
    }
}

class DeleteEndpointsRequestData {
    $request_data = @{
        "filters" = @(@{
            "field" = "endpoint_id_list"
            "operator" = "in"
            "value" = @()
        })
    }
    PolicyRequestData ([string[]]$endpoint_id) {
        $this.request_data.filters[0].value = $endpoint_id
    }
}

# --- Helpers
function Convert-UnixDatetime([long]$uDateTime) {
    $date_offset = [datetimeoffset]::FromUnixTimeMilliseconds($uDateTime)
    return $date_offset.Datetime
}

function Get-RandomString ([int]$length) {
    $rnd = [random]::new()
    $pool = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    $builder=[system.text.stringbuilder]::new()

    for ($i=0; $i -lt $length;$i++)
    {
        $c=$pool[$rnd.Next(0,$pool.Length)]
        $builder.Append($c) | Out-Null
    }

    return $builder.ToString()
}

function Get-SHA256 ([string]$text) {
    $hasher = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
    $hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text))

    $hashString = [System.BitConverter]::ToString($hash)
    $hashString.Replace('-', '').tolower()
}

function Get-XDRAPIHeaders () {
    $credentials = Import-CliXML "$($env:userprofile)\.creds\xdr\api.xml"
    $api_key_id = $credentials.Username
    $api_key = $credentials.GetNetworkCredential().Password

    # Generate a 64 bytes random string
    $nonce = Get-RandomString 64
    # Get the current timestamp as milliseconds.
    $timestamp = [Math]::Round(([datetime]::UtcNow - [datetime]::New(1970,1,1,0,0,0,0)).TotalMilliseconds)
    # Generate the auth key
    $auth_key = "${api_key}${nonce}${timestamp}"
    # Convert to bytes object
    $bytes = [System.Text.Encoding]::Default.GetBytes($auth_key)
    $auth_key = [System.Text.Encoding]::UTF8.GetString($bytes)
    # Calculate sha256
    $api_key_hash = Get-SHA256 $auth_key

    return @{
        "x-xdr-timestamp"= "$timestamp"
        "x-xdr-nonce"= "$nonce"
        "x-xdr-auth-id"= "$api_key_id"
        "Authorization"= "$api_key_hash"
        'Content-Type' = "application/json"
    }
}

# --- XDR Functions
# --- XDR Functions --- EndpointManagement
function Get-XDREndpoint () {

    $headers = Get-XDRAPIHeaders
    
    $body = [EndpointRequestData]::New()
    $current_endpoints = 0
    
    while ($true) {
        $body_string = $body | ConvertTo-json

        $result = Invoke-RestMethod https://api-xxx.xdr.eu.paloaltonetworks.com/public_api/v1/endpoints/get_endpoint `
            -Headers $headers `
            -Method Post `
            -Body $body_string

        if (!$result.reply.endpoints) { break }

        $current_endpoints += $result.reply.result_count
        $result.reply.endpoints | select endpoint_id, endpoint_name | out-host
        $result.reply.endpoints

        if ($current_endpoints -eq $result.reply.total_count) {
            Write-Host "Total returned $current_endpoints objects."
            break
        }

        $body.request_data["search_from"] = $current_endpoints
        $body.request_data["search_to"] = $current_endpoints + 99
        $body_string | out-Host

        $percent = [Math]::Round((100/$result.reply.total_count)*$current_endpoints)
        Write-Progress -Activity "Fetching Cortex API..." -Status "${percent}% complete:" -PercentComplete $percent
    }
}

function Get-XDREndpoints () {

    $headers = Get-XDRAPIHeaders

    $current_endpoints = 0
    
    $result = Invoke-RestMethod https://api-xxx.xdr.eu.paloaltonetworks.com/public_api/v1/endpoints/get_endpoints `
        -Headers $headers `
        -Method Post 

    $result.reply
    
}

function Get-XDRDistributionVersion () {

    $headers = Get-XDRAPIHeaders

    $current_endpoints = 0
    
    $result = Invoke-RestMethod https://api-xxx.xdr.eu.paloaltonetworks.com/public_api/v1/distributions/get_versions `
        -Headers $headers `
        -Method Post 

    $result.reply
    
}

function Get-XDRPolicy ([string]$endpoint_id) {

    $headers = Get-XDRAPIHeaders

    $current_endpoints = 0
    
    $body = [PolicyRequestData]::New($endpoint_id)
    $body_string = $body | ConvertTo-json

    $result = Invoke-RestMethod https://api-xxx.xdr.eu.paloaltonetworks.com/public_api/v1/endpoints/get_policy `
        -Headers $headers `
        -Method Post `
        -Body $body_string

    $result.reply
}

function Remove-XDREndpoint ([string[]]$endpoint_id) {

    $headers = Get-XDRAPIHeaders

    $current_endpoints = 0
    
    $body = [DeleteEndpointsRequestData]::New($endpoint_id)
    $body_string = $body | ConvertTo-json

    $result = Invoke-RestMethod https://api-xxx.xdr.eu.paloaltonetworks.com/public_api/v1/endpoints/get_policy `
        -Headers $headers `
        -Method Post `
        -Body $body_string

    $result.reply
}
