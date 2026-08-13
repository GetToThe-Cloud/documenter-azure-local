@{
    # Module metadata
    RootModule        = 'documenter-azure-local.psm1'
  ModuleVersion     = '1.2.0'
    GUID              = 'fc8d6b4a-14cf-48c1-a312-046c34d4b3cc'
    Author            = 'Alex ter Neuzen'
    CompanyName       = 'GetToTheCloud'
    Copyright         = '(c) 2025 Alex ter Neuzen. All rights reserved.'
    Description       = 'Comprehensive inventory and documentation tool for Azure Local (Azure Stack HCI) environments. Collects cluster, node, VM, logical network, Arc, and storage inventory and presents it in a local web-based dashboard with WAF assessment, cost analysis with Azure Hybrid Benefit tracking, and executive PDF export.'
    PowerShellVersion = '7.0'

    # Required modules (installed from PSGallery on demand by the module)
    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts';       ModuleVersion = '2.0.0'  }
        @{ ModuleName = 'Az.Resources';      ModuleVersion = '6.0.0'  }
        @{ ModuleName = 'Az.StackHCI';       ModuleVersion = '2.0.0'  }
        @{ ModuleName = 'Az.ConnectedMachine'; ModuleVersion = '0.5.0' }
        @{ ModuleName = 'Az.ArcGateway';     ModuleVersion = '0.1.0'  }
    )

    # Exports
    FunctionsToExport = @('Get-AzureLocalInventory', 'Start-AzureLocalServer')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # All files that are part of the module package
    FileList = @(
        'documenter-azure-local.psd1'
        'documenter-azure-local.psm1'
        'Get-AzureLocalInventory.ps1'
        'Start-AzureLocalServer.ps1'
        'index.html'
        'app.js'
        'styles.css'
        'gettothecloud-logo.webp'
        'waf-config.json'
        'LICENSE'
        'README.md'
        'CHANGES.md'
        'WAF-CONFIG-GUIDE.md'
        'start.sh'
    )

    PrivateData = @{
        PSData = @{
            Tags        = @(
                'Azure'
                'AzureLocal'
                'AzureStackHCI'
                'StackHCI'
                'Inventory'
                'HCI'
                'Arc'
                'Dashboard'
                'Documentation'
                'WAF'
                'WellArchitectedFramework'
                'AzureHybridBenefit'
                'Documenter'
            )
            LicenseUri  = 'https://github.com/GetToThe-Cloud/documenter-azure-local/blob/main/LICENSE'
            ProjectUri  = 'https://github.com/GetToThe-Cloud/documenter-azure-local'
            IconUri     = ''
            ReleaseNotes = @'
v1.2.0
  - Security hardening release
  - XSS fix: all Azure-sourced values are HTML-escaped before rendering in the dashboard
  - Replaced inline onclick handlers built from data with delegated event handling (data-* attributes)
  - Removed wildcard CORS header (Access-Control-Allow-Origin: *) from all API responses
  - Added Host and Origin validation on every request (DNS-rebinding / CSRF defense)
  - /api/auth/login now accepts POST only; device-code login requires an explicit button click
  - Module auto-install now asks for consent and no longer uses -AllowClobber
  - Added Subresource Integrity (SRI) hashes to CDN scripts in index.html

v1.1.136
  - Updated module version to 1.1.136
  - Minor bug fixes and improvements
  - Ready for republish to PowerShell Gallery
  
v1.1.135
  - Updated module version to 1.1.135
  - Changed filtering for OSSku to look for "Azure Stack HCI" Github issue #1
  - Minor bug fixes and improvements

v1.1.130
  - Graceful Ctrl+C / server shutdown via async GetContextAsync polling and CancelKeyPress handler
  - PSGallery module packaging: psd1 manifest, psm1 root module, FunctionsToExport

v1.1.124
  - Cross-subscription inventory scanning across all accessible Azure subscriptions
  - Cluster-level Azure Hybrid Benefit detection via softwareAssuranceProperties
  - VM-to-cluster mapping via logical network subnet prefix matching
  - Executive PDF export with branded cover page, section headers, and page footers
  - Arc Resource Bridge provider enrichment
  - VM data enriched with CPU count, memory, IP address, resource group, and cluster name

v1.0.0
  - Initial release
'@
        }
    }
}
