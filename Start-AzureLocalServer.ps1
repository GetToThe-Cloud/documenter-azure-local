#!/usr/bin/env pwsh
<#PSScriptInfo
.VERSION 1.1.130
.GUID b4e8c3d2-5f9a-4e7b-8c1d-2f3e4a5b6c7d
.AUTHOR Alex ter Neuzen
.COMPANYNAME GetToTheCloud
.COPYRIGHT (c) 2025 Alex ter Neuzen. All rights reserved.
.TAGS Azure AzureLocal AzureStackHCI WebServer Dashboard
.LICENSEURI https://github.com/GetToThe-Cloud/documenter-azure-local/blob/main/LICENSE
.PROJECTURI https://github.com/GetToThe-Cloud/documenter-azure-local
.ICONURI
.EXTERNALMODULEDEPENDENCIES Az.Accounts
.REQUIREDSCRIPTS Get-AzureLocalInventory.ps1
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
    v1.1.135 - Changed filtering for OSSku to look for "Azure Stack HCI"
    v1.1.124 - Cross-subscription scanning, executive PDF export support
    v1.0.0 - Initial release
.PRIVATEDATA
#>

<#
.SYNOPSIS
    Azure Local Inventory Web Server
.DESCRIPTION
    Starts a web server that provides a live view of Azure Local (Azure Stack HCI) inventory
    with authentication, navigation, and PDF export capabilities.
.PARAMETER Port
    Port number for the web server (default: 8081)
#>

param(
    [int]$Port = 8081
)

# Check PowerShell version requirement
$minimumVersion = [version]"7.0.0"
$currentVersion = $PSVersionTable.PSVersion

if ($currentVersion -lt $minimumVersion) {
    Write-Error "PowerShell 7.0 or higher is required. Current version: $currentVersion"
    Write-Host "Please install PowerShell 7 from: https://aka.ms/powershell" -ForegroundColor Yellow
    exit 1
}

# Import required modules
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Azure Local Inventory Server..." -ForegroundColor Cyan
Write-Host "✓ PowerShell Version: $currentVersion" -ForegroundColor Green

# Check and import Azure modules
$requiredModules = @(
    'Az.Accounts', 
    'Az.Resources',
    'Az.StackHCI',
    'Az.ConnectedMachine'
)

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "⚠️  Module $module not found. Installing..." -ForegroundColor Yellow
        Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber
    }
    Import-Module $module -ErrorAction SilentlyContinue
}

# Import inventory collection module
$inventoryModulePath = Join-Path $PSScriptRoot "Get-AzureLocalInventory.ps1"
. $inventoryModulePath

# Check Azure connection
function Test-AzureConnection {
    try {
        $context = Get-AzContext
        if ($null -eq $context) {
            return $false
        }
        return $true
    }
    catch {
        return $false
    }
}

# Global state
$script:IsAuthenticated = Test-AzureConnection
$script:InventoryData = @{}
$script:LastUpdate = $null
$script:WafConfig = $null

# Load WAF Configuration
$wafConfigPath = Join-Path $PSScriptRoot "waf-config.json"
if (Test-Path $wafConfigPath) {
    try {
        $script:WafConfig = Get-Content $wafConfigPath -Raw | ConvertFrom-Json
        Write-Host "✓ WAF Configuration loaded (Version: $($script:WafConfig.version))" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Failed to load WAF configuration: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "⚠️  WAF configuration file not found at: $wafConfigPath" -ForegroundColor Yellow
}

Write-Host "🔐 Azure Authentication Status: $(if ($script:IsAuthenticated) { 'Connected ✓' } else { 'Not Connected ✗' })" -ForegroundColor $(if ($script:IsAuthenticated) { 'Green' } else { 'Yellow' })

# HTTP Listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "🌐 Server started at http://localhost:$Port" -ForegroundColor Green
Write-Host "📊 Access the Azure Local Inventory Dashboard in your browser" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $path = $request.Url.AbsolutePath
        $method = $request.HttpMethod
        
        Write-Host "$(Get-Date -Format 'HH:mm:ss') $method $path" -ForegroundColor Gray
        
        # Content type and response
        $content = ""
        $contentType = "text/html; charset=utf-8"
        
        # Route handling
        switch -Regex ($path) {
            '^/$' {
                # Serve main page
                $indexPath = Join-Path $PSScriptRoot "index.html"
                if (Test-Path $indexPath) {
                    $content = Get-Content $indexPath -Raw
                } else {
                    $content = "<html><body><h1>Azure Local Inventory Server</h1><p>index.html not found</p></body></html>"
                }
            }
            
            '^/styles\.css$' {
                $cssPath = Join-Path $PSScriptRoot "styles.css"
                if (Test-Path $cssPath) {
                    $content = Get-Content $cssPath -Raw
                    $contentType = "text/css"
                }
            }
            
            '^/app\.js$' {
                $jsPath = Join-Path $PSScriptRoot "app.js"
                if (Test-Path $jsPath) {
                    $content = Get-Content $jsPath -Raw
                    $contentType = "application/javascript"
                }
            }
            
            '^/api/auth/status$' {
                $script:IsAuthenticated = Test-AzureConnection
                $authStatus = @{
                    authenticated = $script:IsAuthenticated
                    context = if ($script:IsAuthenticated) {
                        $ctx = Get-AzContext
                        @{
                            account = $ctx.Account.Id
                            subscription = $ctx.Subscription.Name
                            tenant = $ctx.Tenant.Id
                        }
                    } else { $null }
                }
                $content = $authStatus | ConvertTo-Json
                $contentType = "application/json"
            }
            
            '^/api/auth/login$' {
                try {
                    Connect-AzAccount -UseDeviceAuthentication | Out-Null
                    $script:IsAuthenticated = $true
                    $content = @{ success = $true; message = "Authentication successful" } | ConvertTo-Json
                } catch {
                    $content = @{ success = $false; message = $_.Exception.Message } | ConvertTo-Json
                }
                $contentType = "application/json"
            }
            
            '^/api/waf/config$' {
                # Serve WAF configuration
                try {
                    if ($null -ne $script:WafConfig) {
                        Write-Host "  📋 Serving WAF configuration" -ForegroundColor Cyan
                        $content = $script:WafConfig | ConvertTo-Json -Depth 20 -Compress:$false
                        Write-Host "  ✅ WAF config sent ($(($content.Length / 1KB).ToString('N2')) KB)" -ForegroundColor Green
                    } else {
                        Write-Host "  ⚠️  WAF configuration not available" -ForegroundColor Yellow
                        $response.StatusCode = 503
                        $content = @{ error = "WAF configuration not loaded" } | ConvertTo-Json
                    }
                } catch {
                    Write-Host "  ❌ Error serving WAF config: $($_.Exception.Message)" -ForegroundColor Red
                    $response.StatusCode = 500
                    $content = @{ error = $_.Exception.Message } | ConvertTo-Json
                }
                $contentType = "application/json"
            }
            
            '^/api/inventory/progress$' {
                # Return current inventory collection progress
                try {
                    $progress = Get-CollectionProgress
                    $content = $progress | ConvertTo-Json
                } catch {
                    $response.StatusCode = 500
                    $content = @{ 
                        message = "Initializing..."
                        percent = 0
                        lastUpdate = (Get-Date).ToString('o')
                        error = $_.Exception.Message 
                    } | ConvertTo-Json
                }
                $contentType = "application/json"
            }
            
            '^/api/inventory/data$' {
                if ($script:IsAuthenticated) {
                    try {
                        Write-Host "  📊 Collecting Azure Local inventory..." -ForegroundColor Cyan
                        # Reset progress before starting
                        Update-CollectionProgress "Starting inventory collection..." 0
                        $script:InventoryData = Get-AzureLocalInventory
                        $script:LastUpdate = Get-Date
                        $content = $script:InventoryData | ConvertTo-Json -Depth 10
                    } catch {
                        $content = @{ error = $_.Exception.Message } | ConvertTo-Json
                    }
                } else {
                    $response.StatusCode = 401
                    $content = @{ error = "Not authenticated" } | ConvertTo-Json
                }
                $contentType = "application/json"
            }
            
            '^/api/inventory/refresh$' {
                if ($script:IsAuthenticated) {
                    try {
                        Write-Host "  🔄 Refreshing inventory..." -ForegroundColor Cyan
                        # Reset progress before starting
                        Update-CollectionProgress "Starting inventory refresh..." 0
                        $script:InventoryData = Get-AzureLocalInventory
                        $script:LastUpdate = Get-Date
                        $content = @{ 
                            success = $true
                            lastUpdate = $script:LastUpdate.ToString('o')
                        } | ConvertTo-Json
                    } catch {
                        $content = @{ success = $false; error = $_.Exception.Message } | ConvertTo-Json
                    }
                } else {
                    $response.StatusCode = 401
                    $content = @{ success = $false; error = "Not authenticated" } | ConvertTo-Json
                }
                $contentType = "application/json"
            }
            
            default {
                $response.StatusCode = 404
                $content = "<html><body><h1>404 - Not Found</h1></body></html>"
            }
        }
        
        # Send response
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
        $response.ContentLength64 = $buffer.Length
        $response.ContentType = $contentType
        $response.Headers.Add("Access-Control-Allow-Origin", "*")
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    }
}
finally {
    Write-Host "`n🛑 Stopping server..." -ForegroundColor Yellow
    $listener.Stop()
    $listener.Close()
    Write-Host "✓ Server stopped" -ForegroundColor Green
}
