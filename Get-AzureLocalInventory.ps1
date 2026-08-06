<#PSScriptInfo
.VERSION 1.2.0
.GUID a3f7b2c1-4d8e-4f6a-9b0c-1e2d3f4a5b6c
.AUTHOR Alex ter Neuzen
.COMPANYNAME GetToTheCloud
.COPYRIGHT (c) 2026 Alex ter Neuzen. All rights reserved.
.TAGS Azure AzureLocal AzureStackHCI Inventory HCI Arc
.LICENSEURI https://github.com/GetToThe-Cloud/documenter-azure-local/blob/main/LICENSE
.PROJECTURI https://github.com/GetToThe-Cloud/documenter-azure-local
.ICONURI
.EXTERNALMODULEDEPENDENCIES Az.Accounts, Az.Resources, Az.StackHCI, Az.ConnectedMachine, Az.ArcGateway
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
    v1.2.0 - Security hardening release (dashboard XSS fixes, server request validation)
    v1.1.135 - Changed filtering for OSSku to look for "Azure Stack HCI"
    v1.1.130 - Changed filtering for OSSku to look for "Azure Stack HCI"
    v1.1.124 - Cross-subscription scanning, cluster-level AHB detection, VM-to-cluster mapping via logical network, executive PDF export
    v1.0.0 - Initial release
.PRIVATEDATA
#>

<#
.SYNOPSIS
    Azure Local (Azure Stack HCI) Inventory Collection Module
.DESCRIPTION
    Collects comprehensive inventory data from Azure Local environments including
    clusters, nodes, agent versions, software versions, logical networks, images, and virtual machines.
#>

# Script version
$script:Version = "1.2.0"

# Progress tracking
$script:CollectionProgress = @{
    Message = ""
    Percent = 0
    LastUpdate = (Get-Date)
}

# Update collection progress
function Update-CollectionProgress {
    param(
        [string]$Message,
        [int]$Percent
    )
    
    $script:CollectionProgress.Message = $Message
    $script:CollectionProgress.Percent = $Percent
    $script:CollectionProgress.LastUpdate = (Get-Date)
    
    Write-Host "    $('{0,3}' -f $Percent)% $Message" -ForegroundColor Cyan
}

# Get current progress
function Get-CollectionProgress {
    return @{
        message = $script:CollectionProgress.Message
        percent = $script:CollectionProgress.Percent
        lastUpdate = $script:CollectionProgress.LastUpdate.ToString('o')
    }
}

# Check PowerShell version requirement
function Test-PowerShellVersion {
    $minimumVersion = [version]"7.0.0"
    $currentVersion = $PSVersionTable.PSVersion
    
    if ($currentVersion -lt $minimumVersion) {
        Write-Error "PowerShell 7.0 or higher is required. Current version: $currentVersion"
        Write-Host "Please install PowerShell 7 from: https://aka.ms/powershell" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "✓ PowerShell Version: $currentVersion" -ForegroundColor Green
    return $true
}

# Check required PowerShell modules
function Test-RequiredModules {
    $requiredModules = @(
        @{ Name = 'Az.Accounts'; MinVersion = '2.0.0' },
        @{ Name = 'Az.Resources'; MinVersion = '6.0.0' },
        @{ Name = 'Az.StackHCI'; MinVersion = '2.0.0' },
        @{ Name = 'Az.ConnectedMachine'; MinVersion = '0.5.0' },
        @{ Name = 'Az.ArcGateway'; MinVersion = '0.1.0' }
    )
    
    $missingModules = @()
    $outdatedModules = @()
    $updateAvailable = @()
    
    Write-Host "\n    ○ Checking required PowerShell modules and latest versions..." -ForegroundColor Gray
    
    foreach ($module in $requiredModules) {
        # Get installed version
        $installed = Get-Module -ListAvailable -Name $module.Name | 
            Sort-Object Version -Descending | 
            Select-Object -First 1
        
        # Try to get latest version from PowerShell Gallery
        $latestVersion = $null
        try {
            $galleryModule = Find-Module -Name $module.Name -ErrorAction SilentlyContinue
            $latestVersion = $galleryModule.Version
        } catch {
            Write-Host "      ⚠️  Unable to check PowerShell Gallery for $($module.Name)" -ForegroundColor Yellow
        }
        
        if (-not $installed) {
            $missingModules += @{
                Name = $module.Name
                Latest = if ($latestVersion) { $latestVersion.ToString() } else { "Unknown" }
            }
            Write-Host "      ❌ $($module.Name): Not installed" -ForegroundColor Red
        } elseif ($installed.Version -lt [version]$module.MinVersion) {
            $outdatedModules += @{
                Name = $module.Name
                Required = $module.MinVersion
                Current = $installed.Version.ToString()
                Latest = if ($latestVersion) { $latestVersion.ToString() } else { "Unknown" }
            }
            Write-Host "      ⚠️  $($module.Name): v$($installed.Version) is below minimum v$($module.MinVersion)" -ForegroundColor Yellow
        } elseif ($latestVersion -and $installed.Version -lt $latestVersion) {
            $updateAvailable += @{
                Name = $module.Name
                Current = $installed.Version.ToString()
                Latest = $latestVersion.ToString()
            }
            Write-Host "      ⚠️  $($module.Name): v$($installed.Version) installed, v$latestVersion available" -ForegroundColor Yellow
        } else {
            $versionInfo = "v$($installed.Version)"
            if ($latestVersion -and $installed.Version -eq $latestVersion) {
                $versionInfo += " (latest)"
            }
            Write-Host "      ✓ $($module.Name): $versionInfo" -ForegroundColor Green
        }
    }
    
    # Install missing modules automatically
    if ($missingModules.Count -gt 0) {
        Write-Host "\n    📦 Installing missing modules..." -ForegroundColor Cyan
        foreach ($module in $missingModules) {
            try {
                Write-Host "      → Installing $($module.Name)..." -ForegroundColor Gray
                Install-Module -Name $module.Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                Write-Host "      ✓ $($module.Name) installed successfully" -ForegroundColor Green
            } catch {
                Write-Host "      ❌ Failed to install $($module.Name): $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
        }
    }
    
    # Update outdated modules (below minimum version)
    if ($outdatedModules.Count -gt 0) {
        Write-Host "\n    🔄 Updating outdated modules to meet minimum requirements..." -ForegroundColor Cyan
        foreach ($module in $outdatedModules) {
            try {
                Write-Host "      → Updating $($module.Name) from v$($module.Current) to latest..." -ForegroundColor Gray
                Update-Module -Name $module.Name -Force -ErrorAction Stop
                Write-Host "      ✓ $($module.Name) updated successfully" -ForegroundColor Green
            } catch {
                Write-Host "      ❌ Failed to update $($module.Name): $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "      ⚠️  Continuing with current version, but some features may not work..." -ForegroundColor Yellow
            }
        }
    }
    
    # Update modules that have newer versions available
    if ($updateAvailable.Count -gt 0) {
        Write-Host "\n    🔄 Updating modules to latest versions..." -ForegroundColor Cyan
        foreach ($module in $updateAvailable) {
            try {
                Write-Host "      → Updating $($module.Name) from v$($module.Current) to v$($module.Latest)..." -ForegroundColor Gray
                Update-Module -Name $module.Name -Force -ErrorAction Stop
                Write-Host "      ✓ $($module.Name) updated successfully" -ForegroundColor Green
            } catch {
                Write-Host "      ⚠️  Could not update $($module.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "      ℹ️  Continuing with v$($module.Current)..." -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "\n    ✓ All required modules are ready" -ForegroundColor Green
    return $true
}

function Get-AzureLocalInventory {
    [CmdletBinding()]
    param()
    
    # Reset progress tracking at the start
    $script:CollectionProgress.Message = ""
    $script:CollectionProgress.Percent = 0
    $script:CollectionProgress.LastUpdate = (Get-Date)
    
    # Check PowerShell version first
    if (-not (Test-PowerShellVersion)) {
        throw "PowerShell 7.0 or higher is required. Please install from: https://aka.ms/powershell"
    }
    
    # Check modules
    if (-not (Test-RequiredModules)) {
        throw "Required PowerShell modules are missing. Please install them and try again."
    }
    
    Write-Host "\n    ○ Gathering Azure Local inventory (v$script:Version)..." -ForegroundColor Gray
    Update-CollectionProgress "Initializing inventory collection..." 5
    
    $inventory = @{
        version = $script:Version
        collectionTime = (Get-Date).ToString('o')
        tenantId = (Get-AzContext).Tenant.Id
        subscription = (Get-AzContext).Subscription.Name
        subscriptionId = (Get-AzContext).Subscription.Id
        clusters = @()
        nodes = @()
        agentVersions = @()
        softwareVersions = @()
        logicalNetworks = @()
        images = @()
        virtualMachines = @()
        storagePaths = @()
        customLocations = @()
        arcResourceBridges = @()
        arcGateways = @()
        licenses = @()
        costAnalysis = @{
            pricingDate = "2024-03-04"
            currency = "USD"
            # Azure Local pricing per physical core per month
            # Source: https://azure.microsoft.com/en-us/pricing/details/azure-local/
            corePrice = 10.0  # Base price per core/month
            corePriceWithHybridBenefit = 0.0  # Free with Azure Hybrid Benefit
            totalCores = 0
            nodesWithHybridBenefit = 0
            nodesWithoutHybridBenefit = 0
            estimatedMonthlyCost = 0.0
            estimatedMonthlyCostWithFullHybridBenefit = 0.0
            potentialMonthlySavings = 0.0
            estimatedYearlyCost = 0.0
            potentialYearlySavings = 0.0
        }
        summary = @{
            totalClusters = 0
            totalNodes = 0
            totalLogicalNetworks = 0
            totalImages = 0
            totalVirtualMachines = 0
            totalStoragePaths = 0
            totalCustomLocations = 0
            totalArcResourceBridges = 0
            totalArcGateways = 0
            totalLicensedMachines = 0
            clustersByStatus = @{}
            nodesByStatus = @{}
            vmsByCluster = @{}
        }
        explanations = @{
            overview = @"
Azure Local (formerly Azure Stack HCI) is a hyperconverged infrastructure solution that combines compute, storage, and networking 
in a single cluster. It enables you to run virtualized workloads on-premises while managing them from Azure.

Key Components:
• Clusters: Collections of physical servers working together as a single system
• Nodes: Individual physical servers within a cluster
• Logical Networks: Software-defined networking configurations
• Images: Virtual machine OS templates and images
• Virtual Machines: Workloads running on the infrastructure

Azure Local provides cloud-native management, automatic updates, and hybrid capabilities through Azure Arc.
"@
            clusters = @"
Azure Local Clusters are collections of physical servers (nodes) that work together to provide high availability and scalability.

Characteristics:
• Resource Pool: Shared compute, storage, and networking resources
• High Availability: Workloads automatically failover between nodes
• Scale-Out Architecture: Add nodes to increase capacity
• Azure Arc Integration: Managed from Azure portal with hybrid benefits
• Software-Defined Storage: Storage Spaces Direct for resilient storage
• Automatic Updates: Cloud-managed patching and updates

Each cluster can host multiple virtual machines and provides enterprise-grade availability for mission-critical workloads.
"@
            nodes = @"
Nodes are the individual physical servers that make up an Azure Local cluster.

Node Roles:
• Cluster Member: Active participant in the cluster providing compute and storage
• Infrastructure Nodes: Can be dedicated for management workloads
• Status Monitoring: Health and performance tracked through Azure Arc

Hardware Information:
• Manufacturer & Model: Physical server vendor and model number
• Physical Cores: Number of CPU cores available
• Memory (GB): Total RAM installed on the server
• Location: Azure region for management

Software & Updates:
• Solution Version: Azure Local software version installed
• Update Status: Current update state (Up-to-date, Updating, Available)
• Last Updated: Timestamp of last update or sync
• Agent Version: Azure Arc agent version
• OS Version: Operating system and version

Current Workload:
• Virtual Machines: Number of VMs running on this node
• Kubernetes Clusters: Number of Arc-enabled K8s clusters hosted
• Resource Utilization: CPU, memory, and storage usage

Arc Gateway Connection:
• Gateway Enabled: Whether the node connects through an Azure Arc gateway
• Gateway ID: Resource ID of the Arc gateway (if connected)
• Benefits: Reduced public endpoints, centralized connectivity management

Nodes can be added or removed from clusters for maintenance or capacity changes.
"@
            agentVersions = @"
Azure Arc agents enable Azure management capabilities on Azure Local infrastructure.

Agent Types:
• Azure Arc Resource Bridge: Connects cluster to Azure Resource Manager
• Azure Connected Machine Agent: Provides Azure Arc capabilities
• Guest Configuration Agent: Policy and compliance monitoring
• Log Analytics Agent: Monitoring and diagnostics

Version Management:
• Automatic Updates: Agents updated through Azure Arc
• Version Tracking: Monitor agent versions across infrastructure
• Compatibility: Ensures agents work with cluster software version

Keeping agents up-to-date ensures access to latest features and security updates.
"@
            logicalNetworks = @"
Logical Networks define software-defined networking configurations for Azure Local environments.

Network Types:
• VM Networks: Networks for virtual machine connectivity
• Management Networks: Infrastructure management traffic
• Storage Networks: Storage communication between nodes
• Live Migration Networks: VM migration traffic

Configuration:
• IP Address Pools: DHCP or static IP ranges for VMs
• VLAN Tagging: Network segmentation and isolation
• DNS Settings: Name resolution configuration
• Gateway and Routes: Network routing rules

Logical networks enable flexible, software-defined networking without physical reconfiguration.
"@
            images = @"
Images are templates used to create virtual machines on Azure Local infrastructure.

Image Types:
• Marketplace Images: Pre-built images from Azure Marketplace
• Custom Images: Organization-specific VM templates
• Gallery Images: Shared images across environments
• Operating System Images: Windows Server, Linux distributions

Image Management:
• Azure Storage: Images stored in Azure or local storage
• Version Control: Track multiple versions of images
• Replication: Sync images across clusters
• Updates: Refresh images with patches and updates

Using images accelerates VM deployment and ensures consistency across workloads.
"@
            virtualMachines = @"
Virtual Machines (VMs) are the compute workloads running on Azure Local infrastructure.

VM Characteristics:
• Azure Management: Managed through Azure portal like Azure VMs
• High Availability: Automatic failover between cluster nodes
• Live Migration: Move VMs between nodes without downtime
• Performance: Hardware-accelerated compute and storage
• Hybrid Benefits: Use existing licenses with Azure Hybrid Benefit

VM Distribution:
• Per Cluster: Total VMs running on each cluster
• Per Node: VM placement across individual nodes
• Load Balancing: Automatic or manual VM placement

VMs on Azure Local provide on-premises performance with cloud management capabilities.
"@
            storagePaths = @"
Storage Paths define the storage locations used by Azure Local clusters for virtual machine storage.

Path Types:
• CSV (Cluster Shared Volumes): Shared storage accessible by all nodes
• SMB Shares: Network storage paths
• Local Storage: Node-specific storage locations

Configuration:
• Path Location: Physical or network path
• Provisioning State: Deployment status
• Associated Cluster: Which cluster uses the storage

Storage paths enable flexible storage configurations and support for hybrid storage scenarios.
"@
            customLocations = @"
Custom Locations extend Azure management capabilities to on-premises and edge infrastructure.

Characteristics:
• Azure Arc Integration: Enables Azure Resource Manager on Azure Local
• Resource Deployment: Deploy Azure services to on-premises clusters
• Management Plane: Single control plane for hybrid resources
• Authentication: Azure RBAC and identity management

Usage:
• Target for resource deployments (VMs, networks, storage)
• Namespace for cluster resources
• Connection point between Azure and on-premises infrastructure

Custom locations bridge the gap between cloud and on-premises management.
"@
            arcResourceBridges = @"
Azure Arc Resource Bridges enable Azure management plane connectivity for on-premises infrastructure.

Characteristics:
• Resource Connector: Lightweight Kubernetes-based appliance
• Management Proxy: Facilitates communication between Azure and on-premises resources
• Self-Hosted: Runs on the Azure Local infrastructure
• High Availability: Can be deployed in HA configuration

Capabilities:
• VM Management: Enable Azure portal management of on-premises VMs
• Resource Provisioning: Deploy resources from Azure to on-premises
• Identity Integration: Azure Active Directory authentication
• Monitoring & Diagnostics: Azure Monitor integration

Configuration:
• Version: Resource bridge software version
• Distro: Kubernetes distribution used
• Provider: Infrastructure provider (Azure Stack HCI, VMware, etc.)
• Status: Operational state and health

Resource bridges are essential for full Azure Arc capabilities on Azure Local.
"@
            licenses = @"
Azure Arc License Management allows you to apply and track software licenses for Arc-enabled machines.

License Types:
• Windows Server: Core-based or datacenter licenses
• SQL Server: Core-based licensing with Software Assurance
• Extended Security Updates (ESU): Security patches for legacy systems
• Azure Hybrid Benefit: Use on-premises licenses in Azure

License Properties:
• License Type: The specific license product (Windows Server, SQL Server, etc.)
• License State: Active, Inactive, or Expired
• Core Count: Number of cores covered by the license
• Edition: License edition (Standard, Datacenter, Enterprise, etc.)
• Assigned Date: When the license was applied to the machine

Licenses help optimize costs and ensure compliance across your hybrid infrastructure.
"@
        }
    }
    
    try {
        # Get all Arc Gateways first
        Write-Host "    ○ Collecting Arc Gateways..." -ForegroundColor Gray
        Update-CollectionProgress "Collecting Arc Gateways..." 10
        $arcGateways = @{}
        try {
            $gateways = Get-AzArcGateway -ErrorAction SilentlyContinue
            if ($gateways) {
                foreach ($gateway in $gateways) {
                    $gatewayInfo = @{
                        name = $gateway.Name
                        resourceGroup = $gateway.ResourceGroupName
                        location = $gateway.Location
                        resourceId = $gateway.Id
                        provisioningState = if ($gateway.ProvisioningState) { $gateway.ProvisioningState } else { "Unknown" }
                        gatewayId = $gateway.Id
                    }
                    
                    $arcGateways[$gateway.Id] = $gatewayInfo
                    $inventory.arcGateways += $gatewayInfo
                    $inventory.summary.totalArcGateways++
                }
                Write-Host "      ✓ Found $($gateways.Count) Arc Gateway(s)" -ForegroundColor Green
            } else {
                Write-Host "      ○ No Arc Gateways found" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "      ⚠️  Failed to collect Arc Gateways: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---------------------------------------------------------------
        # Pre-collect Arc machines and VM resources across ALL accessible
        # subscriptions so that clusters whose nodes or Arc VMs reside in
        # a different subscription or resource group are still discovered.
        # ---------------------------------------------------------------
        Write-Host "    ○ Discovering accessible subscriptions for cross-subscription inventory..." -ForegroundColor Gray
        Update-CollectionProgress "Discovering subscriptions..." 12
        $currentSubscriptionId = (Get-AzContext).Subscription.Id
        $allAccessibleSubscriptions = @(Get-AzSubscription -ErrorAction SilentlyContinue |
            Where-Object { $_.State -eq 'Enabled' })

        $allArcMachinesList = [System.Collections.Generic.List[object]]::new()

        # Helper: gather all Arc machines (nodes + HCI VMs) from the current Az context
        function Invoke-CollectMachinesFromCurrentSubscription {
            $machines = Get-AzConnectedMachine -ErrorAction SilentlyContinue
            if ($machines) {
                $subId = (Get-AzContext).Subscription.Id
                foreach ($m in $machines) {
                    # Stamp the subscription ID so we can switch context when needed later
                    $m | Add-Member -NotePropertyName '_SubscriptionId' -NotePropertyValue $subId -Force -ErrorAction SilentlyContinue
                    $allArcMachinesList.Add($m)
                }
            }
        }

        # Collect Arc machines from all accessible subscriptions
        Invoke-CollectMachinesFromCurrentSubscription

        foreach ($sub in $allAccessibleSubscriptions) {
            if ($sub.Id -eq $currentSubscriptionId) { continue }
            try {
                $null = Set-AzContext -SubscriptionId $sub.Id -ErrorAction Stop -WarningAction SilentlyContinue
                Write-Host "      ○ Discovering resources in subscription: $($sub.Name)..." -ForegroundColor Gray
                Invoke-CollectMachinesFromCurrentSubscription
            } catch {
                Write-Host "      ⚠️  Cannot access subscription $($sub.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            } finally {
                $null = Set-AzContext -SubscriptionId $currentSubscriptionId -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
        }

        # On Azure Local, guest VMs running on a cluster are registered as
        # Microsoft.HybridCompute/machines with Kind = 'HCI'.
        # Physical cluster nodes (the hypervisor hosts) have a different Kind value.
        $allHCIArcVMs = @($allArcMachinesList | Where-Object { $_.Kind -eq 'HCI' })
        $allArcNodes  = @($allArcMachinesList | Where-Object { $_.Kind -ne 'HCI' })

        Write-Host "      ✓ Pre-collected $($allArcMachinesList.Count) Arc machine(s): $($allHCIArcVMs.Count) HCI VM(s) + $($allArcNodes.Count) node/server(s) across $($allAccessibleSubscriptions.Count) subscription(s)" -ForegroundColor Green

        # Get all Azure Local clusters
        Write-Host "    ○ Collecting Azure Local clusters..." -ForegroundColor Gray
        Update-CollectionProgress "Collecting Azure Local clusters..." 15
        $hciClusters = Get-AzResource -ResourceType "Microsoft.AzureStackHCI/clusters" -ErrorAction SilentlyContinue
        
        if ($hciClusters) {
            foreach ($cluster in $hciClusters) {
                try {
                    # Get detailed cluster information
                    $clusterDetail = Get-AzResource -ResourceId $cluster.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
                    
                    $clusterInfo = @{
                        name = $cluster.Name
                        resourceGroup = $cluster.ResourceGroupName
                        location = $cluster.Location
                        resourceId = $cluster.ResourceId
                        status = if ($clusterDetail.Properties -and $clusterDetail.Properties.status) { $clusterDetail.Properties.status } else { "Unknown" }
                        provisioningState = if ($clusterDetail.Properties -and $clusterDetail.Properties.provisioningState) { $clusterDetail.Properties.provisioningState } else { "Unknown" }
                        cloudId = if ($clusterDetail.Properties -and $clusterDetail.Properties.cloudId) { $clusterDetail.Properties.cloudId } else { "N/A" }
                        desiredVersion = if ($clusterDetail.Properties -and $clusterDetail.Properties.desiredProperties -and $clusterDetail.Properties.desiredProperties.version) { $clusterDetail.Properties.desiredProperties.version } else { "N/A" }
                        softwareVersion = if ($clusterDetail.Properties -and $clusterDetail.Properties.reportedProperties -and $clusterDetail.Properties.reportedProperties.clusterVersion) { $clusterDetail.Properties.reportedProperties.clusterVersion } else { "N/A" }
                        lastSyncTimestamp = if ($clusterDetail.Properties -and $clusterDetail.Properties.lastSyncTimestamp) { $clusterDetail.Properties.lastSyncTimestamp } else { "N/A" }
                        nodeCount = 0
                        vmCount = 0
                        # Azure Hybrid Benefit for Azure Local is a cluster-level setting
                        # controlled via softwareAssuranceProperties on the cluster resource.
                        azureHybridBenefitEnabled = if ($clusterDetail.Properties -and
                            $clusterDetail.Properties.softwareAssuranceProperties -and
                            $clusterDetail.Properties.softwareAssuranceProperties.softwareAssuranceStatus -eq 'Enabled') { $true } else { $false }
                        tags = $cluster.Tags
                    }
                    
                    # Track cluster status
                    $statusKey = $clusterInfo.status
                    if (-not $inventory.summary.clustersByStatus.ContainsKey($statusKey)) {
                        $inventory.summary.clustersByStatus[$statusKey] = 0
                    }
                    $inventory.summary.clustersByStatus[$statusKey]++
                    
                    # Get Arc machines (nodes) for this cluster.
                    # Physical nodes have Kind != 'HCI'; VMs have Kind = 'HCI'.
                    Write-Host "      ○ Collecting nodes for cluster: $($cluster.Name)..." -ForegroundColor Gray
                    Update-CollectionProgress "Collecting nodes for cluster: $($cluster.Name)..." 25

                    # Pass 1: nodes in the same resource group as the cluster
                    $arcMachines = @($allArcNodes | Where-Object { $_.ResourceGroupName -eq $cluster.ResourceGroupName -and $_.OSSku -eq "Azure Stack HCI"})

                    # Pass 2: cross-subscription/RG fallback using tags or OS identity
                    if (-not $arcMachines -or $arcMachines.Count -eq 0) {
                        Write-Host "        ○ No nodes in cluster RG, searching across all subscriptions..." -ForegroundColor Yellow
                        $arcMachines = @($allArcNodes | Where-Object {
                            ($_.Tags -and $_.Tags['ClusterName'] -eq $cluster.Name) -or
                            ($_.Tags -and $_.Tags['Cluster'] -eq $cluster.Name) -or
                            ($_.OSType -eq 'Windows' -and $_.OSName -like '*Azure Stack HCI*')
                        })
                        if ($arcMachines.Count -gt 0) {
                            Write-Host "        ✓ Found $($arcMachines.Count) node(s) across subscriptions" -ForegroundColor Green
                        }
                    }
                    
                    foreach ($machine in $arcMachines) {
                        # Extract agent and OS version with fallbacks
                        $agentVer = if ($machine.AgentVersion) { $machine.AgentVersion } 
                                   elseif ($machine.AgentConfiguration -and $machine.AgentConfiguration.GuestConfigurationAgentVersion) { $machine.AgentConfiguration.GuestConfigurationAgentVersion }
                                   else { "Not Available" }
                        
                        $osVer = if ($machine.OSVersion) { $machine.OSVersion }
                                elseif ($machine.DetectedProperty -and $machine.DetectedProperty['OSVersion']) { $machine.DetectedProperty['OSVersion'] }
                                else { "Not Available" }
                        
                        $osNameVal = if ($machine.OSName) { $machine.OSName }
                                    elseif ($machine.DetectedProperty -and $machine.DetectedProperty['OSName']) { $machine.DetectedProperty['OSName'] }
                                    else { "Unknown" }
                        
                        # Extract hardware information from Arc machine properties
                        $manufacturer = if ($machine.Manufacturer) { $machine.Manufacturer }
                                       elseif ($machine.DetectedProperty -and $machine.DetectedProperty['Manufacturer']) { $machine.DetectedProperty['Manufacturer'] }
                                       elseif ($machine.DetectedProperty -and $machine.DetectedProperty['manufacturer']) { $machine.DetectedProperty['manufacturer'] }
                                       else { "Unknown" }
                        
                        $model = if ($machine.Model) { $machine.Model }
                                elseif ($machine.DetectedProperty -and $machine.DetectedProperty['Model']) { $machine.DetectedProperty['Model'] }
                                elseif ($machine.DetectedProperty -and $machine.DetectedProperty['model']) { $machine.DetectedProperty['model'] }
                                else { "Unknown" }
                        
                        $serialNumber = if ($machine.DetectedProperty -and $machine.DetectedProperty['SerialNumber']) { $machine.DetectedProperty['SerialNumber'] }
                                       elseif ($machine.DetectedProperty -and $machine.DetectedProperty['serialNumber']) { $machine.DetectedProperty['serialNumber'] }
                                       else { "Unknown" }
                        
                        $physicalCores = if ($machine.DetectedProperty -and $machine.DetectedProperty['coreCount']) { $machine.DetectedProperty['coreCount'] }
                                        elseif ($machine.DetectedProperty -and $machine.DetectedProperty['LogicalCoreCount']) { $machine.DetectedProperty['LogicalCoreCount'] }
                                        elseif ($machine.DetectedProperty -and $machine.DetectedProperty['ProcessorCount']) { $machine.DetectedProperty['ProcessorCount'] }
                                        else { "Unknown" }
                        
                        $memoryGB = if ($machine.DetectedProperty -and $machine.DetectedProperty['totalPhysicalMemoryInGigabytes']) { 
                                       $machine.DetectedProperty['totalPhysicalMemoryInGigabytes']
                                   }
                                   elseif ($machine.DetectedProperty -and $machine.DetectedProperty['TotalPhysicalMemoryInBytes']) { 
                                       [math]::Round($machine.DetectedProperty['TotalPhysicalMemoryInBytes'] / 1GB, 2)
                                   }
                                   elseif ($machine.DetectedProperty -and $machine.DetectedProperty['MemoryInMB']) {
                                       [math]::Round($machine.DetectedProperty['MemoryInMB'] / 1024, 2)
                                   }
                                   else { "Unknown" }
                        
                        # Extract update information
                        $updateStatus = if ($machine.DetectedProperty -and $machine.DetectedProperty['UpdateStatus']) { $machine.DetectedProperty['UpdateStatus'] }
                                       elseif ($machine.DetectedProperty -and $machine.DetectedProperty['updateStatus']) { $machine.DetectedProperty['updateStatus'] }
                                       else { "Unknown" }
                        
                        $solutionVersion = if ($machine.DetectedProperty -and $machine.DetectedProperty['azurelocal.solutionversion']) { 
                                             $machine.DetectedProperty['azurelocal.solutionversion'] 
                                          }
                                          elseif ($clusterDetail.Properties -and $clusterDetail.Properties.reportedProperties -and $clusterDetail.Properties.reportedProperties.clusterVersion) { 
                                             $clusterDetail.Properties.reportedProperties.clusterVersion 
                                          }
                                          else { "Unknown" }
                        
                        $lastUpdated = if ($machine.DetectedProperty -and $machine.DetectedProperty['LastUpdated']) { $machine.DetectedProperty['LastUpdated'] }
                                      elseif ($machine.LastStatusChange) { $machine.LastStatusChange }
                                      elseif ($clusterDetail.Properties -and $clusterDetail.Properties.lastSyncTimestamp) { $clusterDetail.Properties.lastSyncTimestamp }
                                      else { "Unknown" }
                        
                        # Collect license information and Azure Hybrid Benefit status
                        $licenseInfo = @()
                        $hasLicense = $false
                        # Nodes inherit Azure Hybrid Benefit from their cluster's
                        # softwareAssuranceProperties.softwareAssuranceStatus.
                        $azureHybridBenefitEnabled = $clusterInfo.azureHybridBenefitEnabled
                        
                        if ($machine.LicenseProfile) {
                            $hasLicense = $true
                            
                            if ($machine.LicenseProfile.EsuProfile -and $machine.LicenseProfile.EsuProfile.LicenseAssignmentState) {
                                $licenseInfo += @{
                                    type = "ESU (Extended Security Updates)"
                                    state = $machine.LicenseProfile.EsuProfile.LicenseAssignmentState
                                    assignedDate = if ($machine.LicenseProfile.EsuProfile.AssignedLicenseImmutableId) { "Assigned" } else { "N/A" }
                                }
                            }
                            if ($machine.LicenseProfile.ProductProfile -and $machine.LicenseProfile.ProductProfile.ProductType) {
                                $licenseInfo += @{
                                    type = $machine.LicenseProfile.ProductProfile.ProductType
                                    state = if ($machine.LicenseProfile.ProductProfile.SubscriptionStatus) { $machine.LicenseProfile.ProductProfile.SubscriptionStatus } else { "Active" }
                                    edition = if ($machine.LicenseProfile.ProductProfile.ProductFeatures) { $machine.LicenseProfile.ProductProfile.ProductFeatures.Edition } else { "N/A" }
                                }
                            }
                        }
                        
                        # Collect installed extensions
                        # If the machine is in a different subscription, temporarily switch context.
                        $extensions = @()
                        try {
                            $machineSubId = ""
                            if ($machine.ResourceId -match '/subscriptions/([^/]+)/') { $machineSubId = $matches[1] }
                            $needsSubSwitch = $machineSubId -and $machineSubId -ne $currentSubscriptionId
                            if ($needsSubSwitch) {
                                $null = Set-AzContext -SubscriptionId $machineSubId -ErrorAction Stop -WarningAction SilentlyContinue
                            }
                            $machineExtensions = Get-AzConnectedMachineExtension -ResourceGroupName $machine.ResourceGroupName -MachineName $machine.Name -ErrorAction SilentlyContinue
                            if ($machineExtensions) {
                                foreach ($ext in $machineExtensions) {
                                    $extensions += @{
                                        name = $ext.Name
                                        type = $ext.MachineExtensionType
                                        publisher = $ext.Publisher
                                        version = $ext.TypeHandlerVersion
                                        status = if ($ext.ProvisioningState) { $ext.ProvisioningState } else { "Unknown" }
                                        autoUpgrade = if ($ext.EnableAutomaticUpgrade) { "Enabled" } else { "Disabled" }
                                    }
                                }
                            }
                        } catch {
                            Write-Host "        ⚠️  Could not retrieve extensions for $($machine.Name): $($_.Exception.Message)" -ForegroundColor Yellow
                        } finally {
                            # Always restore the primary context
                            $null = Set-AzContext -SubscriptionId $currentSubscriptionId -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                        }
                        
                        $nodeInfo = @{
                            name = $machine.Name
                            clusterName = $cluster.Name
                            resourceGroup = $machine.ResourceGroupName
                            status = $machine.Status
                            provisioningState = $machine.ProvisioningState
                            agentVersion = $agentVer
                            osType = $machine.OSType
                            osName = $osNameVal
                            osSku = if ($machine.OSSku) { $machine.OSSku } else { "N/A" }
                            osVersion = $osVer
                            location = $machine.Location
                            resourceId = $machine.ResourceId
                            lastStatusChange = if ($machine.LastStatusChange) { $machine.LastStatusChange } else { "N/A" }
                            # Hardware information
                            manufacturer = $manufacturer
                            model = $model
                            serialNumber = $serialNumber
                            physicalCores = $physicalCores
                            memoryGB = $memoryGB
                            # Update information
                            updateStatus = $updateStatus
                            solutionVersion = $solutionVersion
                            lastUpdated = $lastUpdated
                            # Workload tracking (will be populated later)
                            vmCount = 0
                            vmNames = @()
                            k8sClusterCount = 0
                            k8sClusterNames = @()
                            detectedProperty = $machine.DetectedProperty
                            # License information
                            hasLicense = $hasLicense
                            azureHybridBenefitEnabled = $azureHybridBenefitEnabled
                            licenses = $licenseInfo
                            # Extensions
                            extensions = $extensions
                        }
                        
                        $inventory.nodes += $nodeInfo
                        
                        # Track cost calculation data
                        $nodeCores = 0
                        if ($physicalCores -and $physicalCores -ne "Unknown") {
                            try {
                                $nodeCores = [int]$physicalCores
                                $inventory.costAnalysis.totalCores += $nodeCores
                            } catch {
                                Write-Host "        ⚠️  Could not parse core count for $($machine.Name): $physicalCores" -ForegroundColor Yellow
                            }
                        }
                        
                        if ($azureHybridBenefitEnabled) {
                            $inventory.costAnalysis.nodesWithHybridBenefit++
                        } else {
                            $inventory.costAnalysis.nodesWithoutHybridBenefit++
                        }
                        
                        # Track licensed machines
                        if ($hasLicense -and $licenseInfo.Count -gt 0) {
                            $inventory.licenses += @{
                                machineName = $machine.Name
                                clusterName = $cluster.Name
                                resourceGroup = $machine.ResourceGroupName
                                location = $machine.Location
                                licenses = $licenseInfo
                                azureHybridBenefitEnabled = $azureHybridBenefitEnabled
                                physicalCores = if ($nodeCores -gt 0) { $nodeCores } else { "Unknown" }
                                resourceId = $machine.ResourceId
                            }
                            $inventory.summary.totalLicensedMachines++
                        }
                        $clusterInfo.nodeCount++
                        
                        # Track agent version
                        if ($agentVer -and $agentVer -ne "Not Available") {
                            $existingAgent = $inventory.agentVersions | Where-Object { $_.version -eq $agentVer }
                            if (-not $existingAgent) {
                                $inventory.agentVersions += @{
                                    version = $agentVer
                                    nodeCount = 1
                                    nodes = @($machine.Name)
                                }
                            } else {
                                $existingAgent.nodeCount++
                                $existingAgent.nodes += $machine.Name
                            }
                        }
                        
                        # Track software version
                        if ($osVer -and $osVer -ne "Not Available") {
                            $existingSoftware = $inventory.softwareVersions | Where-Object { 
                                $_.version -eq $osVer -and $_.osName -eq $osNameVal 
                            }
                            if (-not $existingSoftware) {
                                $inventory.softwareVersions += @{
                                    osName = $osNameVal
                                    osSku = if ($machine.OSSku) { $machine.OSSku } else { "N/A" }
                                    version = $osVer
                                    nodeCount = 1
                                    nodes = @($machine.Name)
                                }
                            } else {
                                $existingSoftware.nodeCount++
                                $existingSoftware.nodes += $machine.Name
                            }
                        }
                        
                        # Track node status
                        $nodeStatusKey = $machine.Status
                        if (-not $inventory.summary.nodesByStatus.ContainsKey($nodeStatusKey)) {
                            $inventory.summary.nodesByStatus[$nodeStatusKey] = 0
                        }
                        $inventory.summary.nodesByStatus[$nodeStatusKey]++
                    }
                    
                    # Get logical networks for this cluster
                    Write-Host "      ○ Collecting logical networks for cluster: $($cluster.Name)..." -ForegroundColor Gray
                    Update-CollectionProgress "Collecting logical networks for cluster: $($cluster.Name)..." 40
                    $networks = Get-AzResource -ResourceType "Microsoft.AzureStackHCI/logicalnetworks" -ResourceGroupName $cluster.ResourceGroupName -ErrorAction SilentlyContinue

                    foreach ($network in $networks) {
                        $networkDetail = Get-AzResource -ResourceId $network.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
                        
                        $networkInfo = @{
                            name = $network.Name
                            clusterName = $cluster.Name
                            resourceGroup = $network.ResourceGroupName
                            location = $network.Location
                            resourceId = $network.ResourceId
                            provisioningState = if ($networkDetail.Properties -and $networkDetail.Properties.provisioningState) { $networkDetail.Properties.provisioningState } else { "Unknown" }
                            vmSwitchName = if ($networkDetail.Properties -and $networkDetail.Properties.vmSwitchName) { $networkDetail.Properties.vmSwitchName } else { "N/A" }
                            dhcpEnabled = if ($networkDetail.Properties -and $null -ne $networkDetail.Properties.dhcpOptions) { $true } else { $false }
                            subnets = @()
                            tags = $network.Tags
                        }
                        
                        # Get subnets if available
                        if ($networkDetail.Properties -and $networkDetail.Properties.subnets) {
                            foreach ($subnet in $networkDetail.Properties.subnets) {
                                $prefix = if ($subnet.properties -and $subnet.properties.addressPrefix) { $subnet.properties.addressPrefix } else { $null }
                                $networkInfo.subnets += @{
                                    name          = if ($subnet.name) { $subnet.name } else { "Default" }
                                    addressPrefix = if ($prefix) { $prefix } else { "N/A" }
                                    vlan          = if ($subnet.properties.vlan) { $subnet.properties.vlan } else { "N/A" }
                                    ipPools       = if ($subnet.properties.ipPools) { $subnet.properties.ipPools } else { @() }
                                }
                            }
                        }
                        
                        $inventory.logicalNetworks += $networkInfo
                    }
                    
                    # Get gallery images for this cluster
                    Write-Host "      ○ Collecting gallery images for cluster: $($cluster.Name)..." -ForegroundColor Gray
                    Update-CollectionProgress "Collecting gallery images for cluster: $($cluster.Name)..." 50
                    $galleryImages = Get-AzResource -ResourceType "Microsoft.AzureStackHCI/galleryimages" -ResourceGroupName $cluster.ResourceGroupName -ErrorAction SilentlyContinue
                    
                    foreach ($image in $galleryImages) {
                        $imageDetail = Get-AzResource -ResourceId $image.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
                        
                        $imageInfo = @{
                            name = $image.Name
                            clusterName = $cluster.Name
                            resourceGroup = $image.ResourceGroupName
                            location = $image.Location
                            resourceId = $image.ResourceId
                            provisioningState = if ($imageDetail.Properties -and $imageDetail.Properties.provisioningState) { $imageDetail.Properties.provisioningState } else { "Unknown" }
                            osType = if ($imageDetail.Properties -and $imageDetail.Properties.osType) { $imageDetail.Properties.osType } else { "Unknown" }
                            hyperVGeneration = if ($imageDetail.Properties -and $imageDetail.Properties.hyperVGeneration) { $imageDetail.Properties.hyperVGeneration } else { "N/A" }
                            sourceImageId = if ($imageDetail.Properties -and $imageDetail.Properties.identifier -and $imageDetail.Properties.identifier.publisher) { 
                                "$($imageDetail.Properties.identifier.publisher):$($imageDetail.Properties.identifier.offer):$($imageDetail.Properties.identifier.sku)" 
                            } else { "Custom" }
                            version = if ($imageDetail.Properties -and $imageDetail.Properties.version -and $imageDetail.Properties.version.name) { $imageDetail.Properties.version.name } else { "N/A" }
                            sizeInGB = if ($imageDetail.Properties -and $imageDetail.Properties.version -and $imageDetail.Properties.version.sizeInGB) { $imageDetail.Properties.version.sizeInGB } else { 0 }
                            tags = $image.Tags
                        }
                        
                        $inventory.images += $imageInfo
                    }
                    
                    # Also check for marketplace gallery images
                    $marketplaceImages = Get-AzResource -ResourceType "Microsoft.AzureStackHCI/marketplacegalleryimages" -ResourceGroupName $cluster.ResourceGroupName -ErrorAction SilentlyContinue
                    
                    foreach ($image in $marketplaceImages) {
                        $imageDetail = Get-AzResource -ResourceId $image.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
                        
                        $imageInfo = @{
                            name = $image.Name
                            clusterName = $cluster.Name
                            resourceGroup = $image.ResourceGroupName
                            location = $image.Location
                            resourceId = $image.ResourceId
                            provisioningState = if ($imageDetail.Properties -and $imageDetail.Properties.provisioningState) { $imageDetail.Properties.provisioningState } else { "Unknown" }
                            osType = if ($imageDetail.Properties -and $imageDetail.Properties.osType) { $imageDetail.Properties.osType } else { "Unknown" }
                            hyperVGeneration = if ($imageDetail.Properties -and $imageDetail.Properties.hyperVGeneration) { $imageDetail.Properties.hyperVGeneration } else { "N/A" }
                            sourceImageId = if ($imageDetail.Properties -and $imageDetail.Properties.identifier -and $imageDetail.Properties.identifier.publisher) { 
                                "$($imageDetail.Properties.identifier.publisher):$($imageDetail.Properties.identifier.offer):$($imageDetail.Properties.identifier.sku)" 
                            } else { "Marketplace" }
                            version = if ($imageDetail.Properties -and $imageDetail.Properties.version -and $imageDetail.Properties.version.name) { $imageDetail.Properties.version.name } else { "Latest" }
                            sizeInGB = 0
                            tags = $image.Tags
                        }
                        
                        $inventory.images += $imageInfo
                    }
                    
                    # Get storage paths for this cluster
                    Write-Host "      ○ Collecting storage paths for cluster: $($cluster.Name)..." -ForegroundColor Gray
                    Update-CollectionProgress "Collecting storage paths for cluster: $($cluster.Name)..." 55
                    # Try multiple resource types for storage
                    $storagePaths = @()
                    $storagePaths += Get-AzResource -ResourceType "Microsoft.AzureStackHCI/storagepaths" -ResourceGroupName $cluster.ResourceGroupName -ErrorAction SilentlyContinue
                    $storagePaths += Get-AzResource -ResourceType "Microsoft.AzureStackHCI/storagecontainers" -ResourceGroupName $cluster.ResourceGroupName -ErrorAction SilentlyContinue
                    
                    foreach ($path in $storagePaths) {
                        $pathDetail = Get-AzResource -ResourceId $path.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
                        
                        $pathInfo = @{
                            name = $path.Name
                            clusterName = $cluster.Name
                            resourceGroup = $path.ResourceGroupName
                            location = $path.Location
                            resourceId = $path.ResourceId
                            resourceType = $path.ResourceType
                            provisioningState = if ($pathDetail.Properties -and $pathDetail.Properties.provisioningState) { $pathDetail.Properties.provisioningState } else { "Unknown" }
                            path = if ($pathDetail.Properties -and $pathDetail.Properties.path) { $pathDetail.Properties.path } 
                                   elseif ($pathDetail.Properties -and $pathDetail.Properties.containerPath) { $pathDetail.Properties.containerPath }
                                   else { "N/A" }
                            tags = $path.Tags
                        }
                        
                        $inventory.storagePaths += $pathInfo
                    }
                    
                    # Get Arc Resource Bridges for this cluster
                    Write-Host "      ○ Collecting Arc Resource Bridges for cluster: $($cluster.Name)..." -ForegroundColor Gray
                    Update-CollectionProgress "Collecting Arc Resource Bridges..." 60
                    $arcBridges = Get-AzResource -ResourceType "Microsoft.ResourceConnector/appliances" -ResourceGroupName $cluster.ResourceGroupName -ErrorAction SilentlyContinue
                    
                    foreach ($bridge in $arcBridges) {
                        $bridgeDetail = Get-AzResource -ResourceId $bridge.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
                        
                        $bridgeInfo = @{
                            name = $bridge.Name
                            clusterName = $cluster.Name
                            resourceGroup = $bridge.ResourceGroupName
                            location = $bridge.Location
                            resourceId = $bridge.ResourceId
                            provisioningState = if ($bridgeDetail.Properties -and $bridgeDetail.Properties.provisioningState) { $bridgeDetail.Properties.provisioningState } else { "Unknown" }
                            status = if ($bridgeDetail.Properties -and $bridgeDetail.Properties.status) { $bridgeDetail.Properties.status } else { "Unknown" }
                            version = if ($bridgeDetail.Properties -and $bridgeDetail.Properties.version) { $bridgeDetail.Properties.version } else { "N/A" }
                            distro = if ($bridgeDetail.Properties -and $bridgeDetail.Properties.distro) { $bridgeDetail.Properties.distro } else { "N/A" }
                            infrastructureConfig = if ($bridgeDetail.Properties -and $bridgeDetail.Properties.infrastructureConfig -and $bridgeDetail.Properties.infrastructureConfig.provider) { 
                                $bridgeDetail.Properties.infrastructureConfig.provider 
                            } else { "N/A" }
                            tags = $bridge.Tags
                        }
                        
                        $inventory.arcResourceBridges += $bridgeInfo
                    }
                    
                    # Get custom locations for this cluster
                    Write-Host "      ○ Collecting custom locations for cluster: $($cluster.Name)..." -ForegroundColor Gray
                    Update-CollectionProgress "Collecting custom locations..." 65
                    $customLocs = Get-AzResource -ResourceType "Microsoft.ExtendedLocation/customLocations" -ResourceGroupName $cluster.ResourceGroupName -ErrorAction SilentlyContinue
                    
                    foreach ($customLoc in $customLocs) {
                        $locDetail = Get-AzResource -ResourceId $customLoc.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
                        
                        $locInfo = @{
                            name = $customLoc.Name
                            clusterName = $cluster.Name
                            resourceGroup = $customLoc.ResourceGroupName
                            location = $customLoc.Location
                            resourceId = $customLoc.ResourceId
                            provisioningState = if ($locDetail.Properties -and $locDetail.Properties.provisioningState) { $locDetail.Properties.provisioningState } else { "Unknown" }
                            hostResourceId = if ($locDetail.Properties -and $locDetail.Properties.hostResourceId) { $locDetail.Properties.hostResourceId } else { "N/A" }
                            namespace = if ($locDetail.Properties -and $locDetail.Properties.namespace) { $locDetail.Properties.namespace } else { "N/A" }
                            tags = $customLoc.Tags
                        }
                        
                        $inventory.customLocations += $locInfo
                    }
                    
                    # Virtual machines are collected after the cluster loop (no cluster matching)
                    
                    # Get Kubernetes clusters for this cluster (Arc-enabled Kubernetes)
                    Write-Host "      ○ Collecting Kubernetes clusters for cluster: $($cluster.Name)..." -ForegroundColor Gray
                    $k8sClusters = Get-AzResource -ResourceType "Microsoft.Kubernetes/connectedClusters" -ResourceGroupName $cluster.ResourceGroupName -ErrorAction SilentlyContinue
                    
                    foreach ($k8s in $k8sClusters) {
                        # Try to determine if this K8s cluster is related to this HCI cluster
                        # K8s clusters on Azure Local typically have tags or properties linking them
                        $k8sDetail = Get-AzResource -ResourceId $k8s.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
                        
                        # Check if infrastructure field points to this cluster
                        $isOnCluster = $false
                        $k8sNodeName = "Unknown"
                        
                        if (($k8sDetail.Properties -and $k8sDetail.Properties.infrastructure -eq "azure_stack_hci") -or 
                            ($k8s.Tags -and $k8s.Tags['ClusterName'] -eq $cluster.Name) -or
                            ($k8s.Tags -and $k8s.Tags['Cluster'] -eq $cluster.Name)) {
                            $isOnCluster = $true
                            
                            # Try to find which node hosts this K8s cluster
                            # This might be in custom properties or tags
                            if ($k8s.Tags -and $k8s.Tags['NodeName']) {
                                $k8sNodeName = $k8s.Tags['NodeName']
                            } elseif ($k8s.Tags -and $k8s.Tags['HostName']) {
                                $k8sNodeName = $k8s.Tags['HostName']
                            }
                        }
                        
                        if ($isOnCluster) {
                            # Update node K8s count
                            if ($k8sNodeName -ne "Unknown") {
                                $nodeEntry = $inventory.nodes | Where-Object { $_.name -eq $k8sNodeName -and $_.clusterName -eq $cluster.Name }
                                if ($nodeEntry) {
                                    $nodeEntry.k8sClusterCount++
                                    $nodeEntry.k8sClusterNames += $k8s.Name
                                }
                            }
                        }
                    }
                    
                    # Update cluster VM count in summary
                    $inventory.summary.vmsByCluster[$cluster.Name] = $clusterInfo.vmCount
                    
                    $inventory.clusters += $clusterInfo
                    
                } catch {
                    Write-Warning "Failed to get details for cluster $($cluster.Name): $_"
                }
            }
        }

        # Collect all HCI Arc VMs (Kind = 'HCI') without cluster matching
        Write-Host "    ○ Collecting virtual machines..." -ForegroundColor Gray
        Update-CollectionProgress "Collecting virtual machines..." 70
        foreach ($vm in $allHCIArcVMs) {
            $vmInst = $null
            $clusterName = 'N/A'
            $logicalNetworkName = 'N/A'
            $vmSubId = $vm._SubscriptionId
            $vmNeedsSwitch = $vmSubId -and $vmSubId -ne $currentSubscriptionId
            try {
                if ($vmNeedsSwitch) { $null = Set-AzContext -SubscriptionId $vmSubId -ErrorAction Stop -WarningAction SilentlyContinue }
                $vmInstRest = Invoke-AzRestMethod -Path "$($vm.ResourceId)/providers/Microsoft.AzureStackHCI/virtualMachineInstances/default?api-version=2024-02-01-preview" -Method GET -ErrorAction SilentlyContinue
                if ($vmInstRest -and $vmInstRest.StatusCode -eq 200) {
                    $vmInst = ($vmInstRest.Content | ConvertFrom-Json).properties
                }
            } catch {}
            finally {
                if ($vmNeedsSwitch) { $null = Set-AzContext -SubscriptionId $currentSubscriptionId -ErrorAction SilentlyContinue -WarningAction SilentlyContinue }
            }

                # Map VM to cluster via HCI network interface -> logical network resource ID.
                # The NIC lookup runs inside the try block so we are still in the VM's
                # subscription context (important for cross-subscription VMs).
            #     if ($vmInst -and $vmInst.networkProfile -and $vmInst.networkProfile.networkInterfaces) {
            #         :nicLoop foreach ($vmNic in $vmInst.networkProfile.networkInterfaces) {
            #             if (-not $vmNic.id) { continue }
            #             try {
            #                 $nicRest = Invoke-AzRestMethod -Path "$($vmNic.id)?api-version=2024-02-01-preview" -Method GET -ErrorAction SilentlyContinue
            #                 if ($nicRest -and $nicRest.StatusCode -eq 200) {
            #                     $nicProps = ($nicRest.Content | ConvertFrom-Json).properties
            #                     if ($nicProps.ipConfigurations) {
            #                         foreach ($ipCfg in $nicProps.ipConfigurations) {
            #                             $lnId = if ($ipCfg.properties -and $ipCfg.properties.subnet -and $ipCfg.properties.subnet.id) { $ipCfg.properties.subnet.id } else { $null }
            #                             if ($lnId) {
            #                                 $matchedNet = $inventory.logicalNetworks | Where-Object { $_.resourceId -eq $lnId } | Select-Object -First 1
            #                                 if ($matchedNet) {
            #                                     $clusterName = $matchedNet.clusterName
            #                                     $logicalNetworkName = $matchedNet.name
            #                                     break nicLoop
            #                                 }
            #                             }
            #                         }
            #                     }
            #                 }
            #             } catch {}
            #         }
            #     }
            # } catch {}
            # finally {
            #     if ($vmNeedsSwitch) { $null = Set-AzContext -SubscriptionId $currentSubscriptionId -ErrorAction SilentlyContinue -WarningAction SilentlyContinue }
            # }

            $powerState = switch ($vm.Status) {
                'Connected'    { 'Running' }
                'Disconnected' { 'Stopped' }
                default        { if ($vm.Status) { $vm.Status } else { 'Unknown' } }
            }
            if ($vmInst -and $vmInst.instanceView -and $vmInst.instanceView.powerState) {
                $powerState = $vmInst.instanceView.powerState
            }

            # Extract IP address from Arc agent NIC data
            $ipAddress = 'N/A'
            if ($vm.NetworkProfileNetworkInterface) {
                foreach ($nic in $vm.NetworkProfileNetworkInterface) {
                    $ipv4 = $nic.ipAddress | Where-Object { $_.Version -eq 'IPv4' } | Select-Object -First 1
                    if ($ipv4 -and $ipv4.address) { $ipAddress = $ipv4.address; break }
                }
            }

            # Fallback: match Arc agent NIC subnet prefix against inventoried logical network subnets
            if ($clusterName -eq 'N/A' -and $vm.NetworkProfileNetworkInterface) {
                foreach ($nic in $vm.NetworkProfileNetworkInterface) {
                    foreach ($ipEntry in $nic.ipAddress) {
                        if ($ipEntry.Version -eq 'IPv4' -and $ipEntry.SubnetAddressPrefix) {
                            $matchedNet = $inventory.logicalNetworks.Subnets | Where-Object { $_.addressPrefix -eq $ipEntry.SubnetAddressPrefix }
                            | Select-Object -First 1
                            if ($matchedNet) {
                                $filter = $inventory.logicalNetworks | Where-Object { $_.subnets.name -contains $matchedNet.name } | Select -first 1
                                $clusterName = $filter.clusterName
                                $logicalNetworkName = $filter.name
                                break
                            }
                        }
                    }
                    if ($clusterName -ne 'N/A') { break }
                }
            }

            $inventory.virtualMachines += @{
                name              = $vm.Name
                clusterName       = $clusterName
                logicalNetwork    = $logicalNetworkName
                resourceGroup     = $vm.ResourceGroupName
                location          = $vm.Location
                resourceId        = $vm.ResourceId
                arcStatus         = $vm.Status
                powerState        = $powerState
                ipAddress         = $ipAddress
                provisioningState = if ($vm.ProvisioningState) { $vm.ProvisioningState } else { 'Unknown' }
                osType            = if ($vm.OSType) { $vm.OSType } else { 'Unknown' }
                osName            = if ($vm.OSName) { $vm.OSName } else { 'Unknown' }
                osVersion         = if ($vm.OSVersion) { $vm.OSVersion } else { 'N/A' }
                agentVersion      = if ($vm.AgentVersion) { $vm.AgentVersion } else { 'N/A' }
                vmSize            = if ($vmInst -and $vmInst.hardwareProfile -and $vmInst.hardwareProfile.vmSize) { $vmInst.hardwareProfile.vmSize } else { 'Custom' }
                cpuCount          = if ($vmInst -and $vmInst.hardwareProfile -and $vmInst.hardwareProfile.processors) { $vmInst.hardwareProfile.processors }
                                    elseif ($vm.DetectedProperty -and $vm.DetectedProperty['logicalCoreCount']) { [int]$vm.DetectedProperty['logicalCoreCount'] }
                                    elseif ($vm.DetectedProperty -and $vm.DetectedProperty['coreCount']) { [int]$vm.DetectedProperty['coreCount'] }
                                    else { 0 }
                memoryMB          = if ($vmInst -and $vmInst.hardwareProfile -and $vmInst.hardwareProfile.memoryMB) { $vmInst.hardwareProfile.memoryMB }
                                    elseif ($vm.DetectedProperty -and $vm.DetectedProperty['totalPhysicalMemoryInBytes']) { [math]::Round([double]$vm.DetectedProperty['totalPhysicalMemoryInBytes'] / 1MB) }
                                    elseif ($vm.DetectedProperty -and $vm.DetectedProperty['totalPhysicalMemoryInGigabytes']) { [math]::Round([double]$vm.DetectedProperty['totalPhysicalMemoryInGigabytes'] * 1024) }
                                    else { 0 }
                imageReference    = if ($vmInst -and $vmInst.storageProfile -and $vmInst.storageProfile.imageReference -and $vmInst.storageProfile.imageReference.id) { $vmInst.storageProfile.imageReference.id } else { 'N/A' }
                tags              = $vm.Tags
            }
        }
        Write-Host "      ✓ Found $($inventory.virtualMachines.Count) virtual machine(s)" -ForegroundColor Green

        # Update per-cluster VM counts now that clusterName is resolved via logical network mapping
        foreach ($vmEntry in $inventory.virtualMachines) {
            if ($vmEntry.clusterName -and $vmEntry.clusterName -ne 'N/A') {
                if (-not $inventory.summary.vmsByCluster.ContainsKey($vmEntry.clusterName)) {
                    $inventory.summary.vmsByCluster[$vmEntry.clusterName] = 0
                }
                $inventory.summary.vmsByCluster[$vmEntry.clusterName]++
                $clusterEntry = $inventory.clusters | Where-Object { $_.name -eq $vmEntry.clusterName }
                if ($clusterEntry) { $clusterEntry.vmCount++ }
            }
        }

        $inventory.summary.totalClusters = $inventory.clusters.Count
        $inventory.summary.totalNodes = $inventory.nodes.Count
        $inventory.summary.totalLogicalNetworks = $inventory.logicalNetworks.Count
        $inventory.summary.totalImages = $inventory.images.Count
        $inventory.summary.totalVirtualMachines = $inventory.virtualMachines.Count
        $inventory.summary.totalStoragePaths = $inventory.storagePaths.Count
        $inventory.summary.totalCustomLocations = $inventory.customLocations.Count
        $inventory.summary.totalArcResourceBridges = $inventory.arcResourceBridges.Count
        
        Write-Host "    ✓ Inventory collection complete" -ForegroundColor Green
        Update-CollectionProgress "Processing collected data..." 75
        Write-Host "      • Clusters: $($inventory.summary.totalClusters)" -ForegroundColor Gray
        Write-Host "      • Nodes: $($inventory.summary.totalNodes)" -ForegroundColor Gray
        Write-Host "      • Logical Networks: $($inventory.summary.totalLogicalNetworks)" -ForegroundColor Gray
        Write-Host "      • Images: $($inventory.summary.totalImages)" -ForegroundColor Gray
        Write-Host "      • Virtual Machines: $($inventory.summary.totalVirtualMachines)" -ForegroundColor Gray
        Write-Host "      • Storage Paths: $($inventory.summary.totalStoragePaths)" -ForegroundColor Gray
        Write-Host "      • Custom Locations: $($inventory.summary.totalCustomLocations)" -ForegroundColor Gray
        Write-Host "      • Arc Resource Bridges: $($inventory.summary.totalArcResourceBridges)" -ForegroundColor Gray
        
        # Calculate costs based on Azure Local pricing
        Write-Host "\n    ○ Calculating cost estimates..." -ForegroundColor Gray
        Update-CollectionProgress "Analyzing Azure Hybrid Benefit savings..." 80
        
        $costAnalysis = $inventory.costAnalysis
        $totalCores = $costAnalysis.totalCores
        $nodesWithHybrid = $costAnalysis.nodesWithHybridBenefit
        $nodesWithoutHybrid = $costAnalysis.nodesWithoutHybridBenefit
        $corePrice = $costAnalysis.corePrice
        
        if ($totalCores -gt 0) {
            # Calculate cores with and without hybrid benefit
            # Assuming even distribution of cores across nodes for simplicity
            $avgCoresPerNode = if ($inventory.summary.totalNodes -gt 0) { 
                [math]::Round($totalCores / $inventory.summary.totalNodes, 2) 
            } else { 0 }
            
            # Calculate costs
            # Nodes with Hybrid Benefit pay $0/core (free with Windows Server licenses)
            # Nodes without Hybrid Benefit pay $10/core/month
            
            $coresWithHybrid = 0
            $coresWithoutHybrid = 0
            
            # Calculate actual cores with/without hybrid benefit based on node data
            foreach ($node in $inventory.nodes) {
                $nodeCoreCount = 0
                if ($node.physicalCores -and $node.physicalCores -ne "Unknown") {
                    try {
                        $nodeCoreCount = [int]$node.physicalCores
                    } catch {
                        $nodeCoreCount = 0
                    }
                }
                
                if ($node.azureHybridBenefitEnabled) {
                    $coresWithHybrid += $nodeCoreCount
                } else {
                    $coresWithoutHybrid += $nodeCoreCount
                }
            }
            
            # Current monthly cost (what you're currently paying)
            $currentMonthlyCost = ($coresWithoutHybrid * $corePrice)
            
            # Potential monthly cost if all had hybrid benefit (best case)
            $monthlyCostWithFullHybrid = 0.0  # Free with Azure Hybrid Benefit
            
            # Potential savings
            $potentialMonthlySavings = $currentMonthlyCost - $monthlyCostWithFullHybrid
            
            # Yearly calculations
            $currentYearlyCost = $currentMonthlyCost * 12
            $potentialYearlySavings = $potentialMonthlySavings * 12
            
            # Update cost analysis
            $costAnalysis.estimatedMonthlyCost = [math]::Round($currentMonthlyCost, 2)
            $costAnalysis.estimatedMonthlyCostWithFullHybridBenefit = [math]::Round($monthlyCostWithFullHybrid, 2)
            $costAnalysis.potentialMonthlySavings = [math]::Round($potentialMonthlySavings, 2)
            $costAnalysis.estimatedYearlyCost = [math]::Round($currentYearlyCost, 2)
            $costAnalysis.potentialYearlySavings = [math]::Round($potentialYearlySavings, 2)
            
            Write-Host "      ✓ Total Physical Cores: $totalCores" -ForegroundColor Green
            Write-Host "      • Cores with Azure Hybrid Benefit: $coresWithHybrid (FREE)" -ForegroundColor Green
            Write-Host "      • Cores without Azure Hybrid Benefit: $coresWithoutHybrid" -ForegroundColor $(if ($coresWithoutHybrid -gt 0) { "Yellow" } else { "Green" })
            Write-Host "      • Estimated Monthly Cost: `$$($costAnalysis.estimatedMonthlyCost)" -ForegroundColor Cyan
            Write-Host "      • Estimated Yearly Cost: `$$($costAnalysis.estimatedYearlyCost)" -ForegroundColor Cyan
            
            if ($potentialMonthlySavings -gt 0) {
                Write-Host "      💰 Potential Monthly Savings with Full Hybrid Benefit: `$$($costAnalysis.potentialMonthlySavings)" -ForegroundColor Yellow
                Write-Host "      💰 Potential Yearly Savings: `$$($costAnalysis.potentialYearlySavings)" -ForegroundColor Yellow
            } else {
                Write-Host "      ✓ All nodes using Azure Hybrid Benefit - Maximum savings achieved!" -ForegroundColor Green
            }
            Update-CollectionProgress "Building summary..." 85
        } else {
            Write-Host "      ⚠️  Unable to calculate costs: No core count information available" -ForegroundColor Yellow
            Update-CollectionProgress "Building summary..." 85
        }
        
        Update-CollectionProgress "Finalizing inventory..." 95
        
    } catch {
        Write-Error "Error collecting inventory: $_"
        throw
    }
    
    Update-CollectionProgress "Inventory collection complete!" 100
    return $inventory
}
