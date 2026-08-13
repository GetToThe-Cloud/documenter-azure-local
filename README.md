# Azure Local Inventory Dashboard

A comprehensive web-based inventory and documentation tool for Azure Local (Azure Stack HCI) environments. This tool provides detailed insights into your Azure Local infrastructure, including hardware specifications, cost analysis with Azure Hybrid Benefit tracking, Arc ecosystem integration, and compliance assessments.

## Overview

The Azure Local Inventory Dashboard automatically scans and documents your Azure Stack HCI infrastructure, providing:
- **Cross-subscription** inventory scanning across all Azure subscriptions
- Complete hardware inventory with manufacturer, model, and serial numbers
- Cost analysis with Azure Hybrid Benefit detection and savings calculations
- Arc-enabled services tracking (Custom Locations, Resource Bridges, Gateways)
- License compliance monitoring with ESU and Windows Server licensing
- Workload distribution across clusters and nodes
- VM-to-cluster mapping via logical network subnet matching
- Well-Architected Framework (WAF) assessment
- Interactive HTML reports with executive-ready PDF export

## Features

### Infrastructure Inventory
- 🔷 **Clusters**: Complete cluster configurations, resource groups, locations, node counts, and health status
- 🖥️ **Nodes**: Hardware specifications (manufacturer, model, serial number, cores, memory), agent versions, solution versions
- 💻 **Virtual Machines**: VM inventory with CPU, memory, power states, logical network, resource group, and cluster association via subnet matching
- 🌐 **Logical Networks**: Network configurations, subnets, VM switches, VLAN settings, and DNS
- 💾 **Storage Paths**: Storage inventory with provisioning states and capacity information
- 💿 **Images**: Marketplace and custom images with OS types, versions, and states

### Azure Arc Integration
- 🔗 **Arc Services**: Custom Locations, Resource Bridges, and Arc Gateways
- 🔌 **Node Extensions**: Clickable nodes display all installed Arc extensions with status and versions
- 📜 **Licensed Machines**: Comprehensive license tracking with ESU profiles and product licenses
- ✅ **Azure Hybrid Benefit**: Cluster-level detection via `softwareAssuranceProperties` with node inheritance

### Cost Analysis & Optimization
- 💰 **Cost Tracking**: Per-node cost calculation based on physical cores and Azure Local pricing ($10/core/month)
- 🎯 **Hybrid Benefit Analysis**: Automatic detection of Azure Hybrid Benefit activation
- 📊 **Savings Dashboard**: Real-time calculation of potential savings with detailed breakdown
- 📈 **Cost Projections**: Monthly and yearly cost estimates with optimization recommendations
- 🆓 **Free Licensing**: Cores with Azure Hybrid Benefit are FREE (vs $10/core/month)

### Analytics & Reporting
- 📊 **Visual Analytics**: Interactive charts showing status distributions and resource placement
- 🔍 **Search & Filter**: Quick search across all resource types with real-time filtering
- 📄 **PDF Export**: Executive-ready reports with the GetToTheCloud WebP wordmark, branded cover page, Azure-themed tables, section headers, and page numbers (includes WAF assessment)
- ⚡ **Auto-Refresh**: Real-time inventory updates with manual refresh option
- 🎯 **WAF Assessment**: Fully configurable Well-Architected Framework compliance checks
  - **NEW**: External configuration file (`waf-config.json`) for easy customization
  - **NEW**: Included in PDF exports with detailed scores and recommendations
  - Customize rules, weights, thresholds, and messages without code changes
  - See [WAF-CONFIG-GUIDE.md](WAF-CONFIG-GUIDE.md) for full documentation

## Prerequisites

### Required Software

1. **PowerShell 7.0 or higher** (REQUIRED)
   - The script will validate the version and exit if not met
   - Download from: https://aka.ms/powershell
   - Check your version: `$PSVersionTable.PSVersion`

2. **Azure PowerShell Modules** (Auto-installed/updated on first run)
   
   The following modules are required and will be automatically installed or updated to the latest version:
   
   | Module | Minimum Version | Purpose |
   |--------|----------------|---------|
   | **Az.Accounts** | 2.0.0+ | Azure authentication and context management |
   | **Az.Resources** | 6.0.0+ | Azure resource queries and Resource Graph |
   | **Az.StackHCI** | 2.0.0+ | Azure Local cluster and node management |
   | **Az.ConnectedMachine** | 0.5.0+ | Arc-enabled servers, extensions, and licensing |
   | **Az.ArcGateway** | 0.1.0+ | Arc Gateway connectivity and management |

   > **Note**: The script includes module management. On first run, it will:
   > - Detect missing modules and **ask for your consent** before installing them from the PowerShell Gallery (CurrentUser scope)
   > - Verify all modules meet minimum version requirements
   > - If you decline, the script exits and tells you how to install the module manually

### Azure Requirements

- **Azure Subscription** with Azure Local (Azure Stack HCI) resources
- **RBAC Permissions**: Reader role (or higher) on:
  - Azure Local clusters
  - Arc-enabled servers (nodes)
  - Logical networks and virtual machines
  - Arc Gateways and Custom Locations
- **Network Access**: Ability to connect to Azure management APIs

## Installation

### Step 1: Install PowerShell 7+

If you don't have PowerShell 7 or higher installed:

**macOS:**
```bash
brew install --cask powershell
```

**Windows:**
```powershell
# Using winget
winget install Microsoft.PowerShell

# Or download the MSI installer from:
# https://aka.ms/powershell
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y wget apt-transport-https software-properties-common
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell

# Or see: https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux
```

Verify installation:
```powershell
pwsh --version
# Should show 7.0.0 or higher
```

### Step 2: Choose an Installation Method

#### Option A: Install from PowerShell Gallery (recommended)

```powershell
Install-Module -Name documenter-azure-local -Repository PSGallery -Scope CurrentUser
Import-Module documenter-azure-local
Start-AzureLocalServer
```

To update an existing gallery installation:

```powershell
Update-Module -Name documenter-azure-local
```

#### Option B: Clone or Download Repository

```bash
git clone https://github.com/GetToThe-Cloud/documenter-azure-local.git
cd documenter-azure-local
```

Or download the files directly from the repository.

### Step 3: Azure PowerShell Modules (Optional - Auto-installed)

The required Azure modules will be automatically installed and updated when you run the script for the first time. However, if you prefer to install them manually:

```powershell
# Install all required modules
Install-Module -Name Az.Accounts, Az.Resources, Az.StackHCI, Az.ConnectedMachine, Az.ArcGateway -Scope CurrentUser -Force -AllowClobber

# Verify installation
Get-Module -Name Az.* -ListAvailable
```

### Step 4: Azure Authentication

Connect to your Azure subscription before running the inventory:

```powershell
# Connect to Azure
Connect-AzAccount

# Select the subscription containing your Azure Local resources
Set-AzContext -Subscription "Your-Subscription-Name"

# Verify context
Get-AzContext
```

## Usage

### Starting the Server

**Option 1: Using the shell script (macOS/Linux)**
```bash
./start.sh
```

**Option 2: Using PowerShell directly**
```powershell
pwsh Start-AzureLocalServer.ps1
```

**Option 3: Custom port**
```powershell
pwsh Start-AzureLocalServer.ps1 -Port 8082
```

### Accessing the Dashboard

1. The server will start on `http://localhost:8081` (default port)
2. Open your web browser and navigate to the URL
3. You'll be prompted to authenticate with Azure using device code authentication
4. Follow the prompts in your terminal or browser
5. Once authenticated, the dashboard will automatically load your Azure Local inventory

### Dashboard Navigation

The web interface provides intuitive navigation through all inventory sections:

- **Overview**: Summary statistics, distribution charts, and health dashboards
- **Clusters**: Detailed cluster configurations with node counts and locations
- **Nodes**: Hardware specifications, agent versions, and workload assignments
- **Virtual Machines**: Complete VM inventory with resource allocation and placement
- **Logical Networks**: Network configurations, subnets, and VLAN settings
- **Storage Paths**: Storage inventory with provisioning states
- **Images**: Marketplace and custom images with OS information
- **Arc Services**: Custom Locations, Resource Bridges, and Arc Gateways
- **Licensed Machines**: License compliance with ESU and Hybrid Benefit status
- **Cost Analysis**: Detailed cost breakdown with optimization recommendations
- **WAF Assessment**: Well-Architected Framework compliance checks

### Interactive Features

- **🔄 Refresh**: Click the refresh button to reload inventory data from Azure
- **🔍 Search**: Use search boxes to instantly filter resources across all tables
- **🖱️ Clickable Nodes**: Click any node to view detailed information including:
  - Hardware specifications (manufacturer, model, serial number)
  - Installed Arc extensions with versions and status
  - License information and Azure Hybrid Benefit status
  - Workload assignments (VMs and Kubernetes clusters)
- **📊 Subnet Details**: Click subnet information to view detailed network configurations
- **💾 Filter VMs**: Select specific clusters to filter virtual machine views
- 📄 Export PDF**: Generate executive-ready reports including:
  - **Cover page** with Azure-branded header and executive summary
  - **Resource inventory** overview with total counts
  - All inventory sections with Azure-themed table styling
  - **Section headers** with colored bars for visual structure
  - Cost analysis with Azure Hybrid Benefit savings
  - Well-Architected Framework (WAF) assessment with scores and recommendations
  - **Page footers** with page numbers and a visual divider

## What Gets Documented

The inventory tool automatically collects and documents the following information:

### 1. Cluster Information
- Cluster names, resource groups, and Azure locations
- Total node counts and cluster status
- Azure Arc integration status
- Cluster-level configurations and properties

### 2. Node Details (Arc-enabled Servers)
- **Hardware Specifications**:
  - Manufacturer, model, and serial numbers
  - Physical core counts and memory capacity
  - BIOS and firmware information
- **Software Versions**:
  - Operating system version and build
  - Azure Connected Machine agent version
  - Solution extension versions
- **Workload Tracking**:
  - Number of VMs hosted on each node
  - Kubernetes cluster assignments
- **Arc Status**: Connection state and last heartbeat

### 3. Virtual Machines
- VM names, resource groups, and power states
- CPU count (from `logicalCoreCount`) and memory (from `totalPhysicalMemoryInBytes`)
- IP addresses (IPv4 from Arc agent network profile)
- Logical network association via subnet prefix matching
- Cluster association derived from logical network mapping
- OS type and name

### 4. Logical Networks
- Network names and configurations
- Subnet details with address ranges
- VM switch associations
- VLAN IDs and DNS server configurations
- Provisioning states

### 5. Storage Paths
- Storage path names and types
- Provisioning states
- Associated resource groups

### 6. Images
- Marketplace images with publisher and offer details
- Custom images with OS types
- Image versions and states
- Storage locations

### 7. Azure Arc Ecosystem
- **Custom Locations**: Cluster extensions and namespace configurations
- **Resource Bridges**: Appliance connections and status
- **Arc Gateways**: Gateway configurations and connectivity status

### 8. License Compliance
- **Licensed Machines**: All Arc-enabled machines with license profiles
- **ESU Profiles**: Extended Security Update licensing status
- **Product Licenses**: Windows Server licensing information
- **Azure Hybrid Benefit**: Automatic detection of Hybrid Benefit activation

### 9. Cost Analysis & Optimization
- **Core Inventory**: Total physical cores across all nodes
- **Pricing Model**: Based on official Azure Local pricing ($10/core/month)
- **Hybrid Benefit Detection**: Identifies nodes with Azure Hybrid Benefit enabled
- **Cost Calculations**:
  - Current monthly costs based on actual configuration
  - Yearly projections
  - Potential savings with full Azure Hybrid Benefit adoption
  - Per-node cost breakdown
- **Optimization Recommendations**: Identifies opportunities for cost reduction

> **Azure Hybrid Benefit Savings**: Nodes with Windows Server licenses and Azure Hybrid Benefit activated are charged **$0/core/month** instead of the standard **$10/core/month**, providing significant cost savings.

### 10. Well-Architected Framework (WAF) Assessment

**NEW: Fully Configurable WAF Assessment**

The WAF assessment is now powered by an external configuration file (`waf-config.json`) that allows you to:
- ✅ **Customize assessment rules** without modifying code
- ✅ **Adjust check weights** to prioritize what matters to your organization
- ✅ **Modify conditions and thresholds** to match your standards
- ✅ **Update messages and recommendations** to fit your processes
- ✅ **Add or remove checks** as your requirements evolve
- ✅ **Export WAF results** in PDF reports

#### Assessment Pillars

1. **Reliability** - High availability, multi-node clusters, workload distribution
2. **Security** - System updates, Arc agents, monitoring deployment
3. **Cost Optimization** - Azure Hybrid Benefit utilization, resource efficiency
4. **Performance Efficiency** - Memory capacity, CPU cores, storage infrastructure
5. **Operational Excellence** - Version tracking, monitoring, Arc integration

#### WAF Configuration

- **File**: `waf-config.json` (loaded at server startup)
- **Documentation**: See [WAF-CONFIG-GUIDE.md](WAF-CONFIG-GUIDE.md) for full customization guide
- **API Endpoint**: `/api/waf/config` serves configuration to client
- **PDF Export**: WAF assessment included in all exported PDFs

#### Example Customizations

Modify check weights:
```json
{
  "weight": 3  // Change from 1-3 to adjust importance
}
```

Update conditions:
```json
{
  "condition": "nodesWithHybridBenefit >= totalNodes * 0.9"
}
```

Customize messages with data:
```json
{
  "passMessage": "✓ {connectedNodes} of {totalNodes} nodes are healthy"
}
```

For complete documentation on customizing the WAF assessment, see **[WAF-CONFIG-GUIDE.md](WAF-CONFIG-GUIDE.md)**.

## Cost Analysis Details

### Pricing Model

The cost analysis is based on official Azure Local pricing:
- **Base Price**: $10 USD per physical core per month
- **With Azure Hybrid Benefit**: $0 USD per core per month (FREE)
- **Source**: https://azure.microsoft.com/en-us/pricing/details/azure-local/

### Cost Dashboard Includes:

1. **Current Cost Overview**
   - Total monthly costs based on physical cores
   - Yearly cost projections
   - Cost breakdown by node

2. **Hybrid Benefit Analysis**
   - Number of cores with Azure Hybrid Benefit enabled
   - Number of cores paying standard pricing
   - Visual indicators for optimization opportunities

3. **Savings Calculations**
   - Potential monthly savings if all nodes enable Hybrid Benefit
   - Yearly savings projections
   - ROI timeline for license acquisition

4. **Per-Node Breakdown Table**
   - Node name and core count
   - Azure Hybrid Benefit status
   - Monthly cost per node
   - Potential savings per node

### How Azure Hybrid Benefit is Detected

The tool detects Azure Hybrid Benefit at the **cluster level** using the `softwareAssuranceProperties.softwareAssuranceStatus` property on the Azure Local cluster resource:
1. Queries each cluster's `softwareAssuranceProperties` via the Azure Resource Manager API
2. If `softwareAssuranceStatus` is `Enabled`, the cluster has Azure Hybrid Benefit active
3. All nodes within a cluster **inherit** the cluster's Hybrid Benefit status
4. Cost calculations use the cluster-level AHB status for accurate per-node pricing

### Features

- **Refresh**: Click the refresh button to reload inventory data
- **Search**: Use search boxes to filter resources
- **Filter VMs by Cluster**: Select a specific cluster to view its VMs
- **Export PDF**: Generate a PDF report of the inventory

## Architecture

The solution consists of three main layers working together to provide a comprehensive inventory experience:

### 1. Data Collection Layer - Get-AzureLocalInventory.ps1

**PowerShell module responsible for inventory collection** (1,099 lines)

**Key Functions:**
- `Test-PowerShellVersion`: Validates PowerShell 7.0+ requirement before execution
- `Test-RequiredModules`: Automatically installs and updates required Az modules
- `Get-AzureLocalInventory`: Main function orchestrating all data collection

**Data Collection Process:**
1. Validates PowerShell version (7.0+ required)
2. Checks and installs/updates Azure PowerShell modules
3. Iterates across all Azure subscriptions to pre-collect Arc machines
4. Queries Azure Resource Graph for clusters
5. Retrieves Arc-enabled servers with hardware details
6. Detects Azure Hybrid Benefit at the cluster level via `softwareAssuranceProperties`
7. Collects virtual machines (outside cluster loop) with logical network subnet matching
8. Maps VMs to clusters via logical network subnet prefix matching
9. Gathers logical networks and storage paths
10. Queries Arc ecosystem (Custom Locations, Resource Bridges, Gateways)
11. Collects license information from Arc machine profiles
12. Calculates costs based on physical cores and cluster-level AHB status
13. Performs WAF assessment checks
14. Aggregates all data into structured JSON

**Output:** Complete inventory object with 11 major sections plus cost analysis and WAF assessment

### 2. Web Server Layer - Start-AzureLocalServer.ps1

**HTTP server hosting the dashboard** (212 lines)

**Capabilities:**
- PowerShell 7 version validation at startup
- .NET HttpListener serving on localhost (default port 8081)
- Azure authentication flow management
- RESTful API endpoints for data access
- Real-time inventory refresh capabilities
- Static file serving (HTML, CSS, JavaScript)

**Security Features:**
- Localhost-only binding (not accessible from external networks)
- Host header validation on every request (DNS-rebinding defense)
- Origin header validation — cross-origin requests from other websites are rejected with `403`
- No CORS headers — the API is same-origin only
- Login endpoint accepts `POST` only; device-code sign-in requires an explicit user click
- Azure AD authentication required
- No credential storage or transmission
- Session-based context management

### 3. Frontend Layer - Web Interface

**Single-page application with responsive design**

**Files:**
- `index.html` (1,286 lines): Main application structure and layout
- `app.js` (1,617 lines): Data rendering, interactions, and PDF export
- `styles.css` (914 lines): Dark theme styling with custom components

**Key Features:**
- Dynamic data rendering with real-time search/filter
- Interactive modals for subnet details and node extensions
- Cost analysis dashboard with visual charts
- PDF generation using jsPDF library
- Responsive design for various screen sizes
- Custom scrollbars and tooltips

**Technology Stack:**
- Vanilla JavaScript (no external frameworks)
- jsPDF for PDF export functionality
- CSS Grid and Flexbox for layouts
- CSS custom properties for theming

## API Endpoints

- `GET /` - Main dashboard page
- `GET /api/auth/status` - Check authentication status
- `POST /api/auth/login` - Initiate Azure login
- `GET /api/inventory/data` - Retrieve inventory data
- `POST /api/inventory/refresh` - Refresh inventory data

## Troubleshooting

### PowerShell Version Issues

**Error: "PowerShell 7.0 or higher is required"**

The script will exit immediately if PowerShell 7.0+ is not detected.

**Solution:**
```powershell
# Check current version
$PSVersionTable.PSVersion

# If less than 7.0, install from:
# https://aka.ms/powershell

# macOS
brew install --cask powershell

# Windows
winget install Microsoft.PowerShell

# Then restart your terminal and verify
pwsh --version
```

### Module Installation Issues

**Error: "Module installation failed" or permission errors**

**Solutions:**
```powershell
# Option 1: Install for current user (recommended)
Install-Module -Name Az.StackHCI -Scope CurrentUser -Force -AllowClobber

# Option 2: Run as administrator (Windows) or with sudo (macOS/Linux)
# Then install globally
Install-Module -Name Az.StackHCI -Scope AllUsers -Force -AllowClobber

# Option 3: Update PowerShellGet first
Install-Module -Name PowerShellGet -Force -AllowClobber
Update-Module -Name PowerShellGet
```

**Error: "Module version mismatch" or outdated modules**

The script automatically updates modules, but you can manually force updates:
```powershell
# Update all Az modules
Update-Module -Name Az.* -Force

# Or update specific modules
Update-Module -Name Az.StackHCI, Az.ConnectedMachine, Az.ArcGateway -Force

# Verify versions
Get-Module -Name Az.* -ListAvailable | Select-Object Name, Version
```

**Error: "Assembly with same name is already loaded"**

Close the current PowerShell session, open a new PowerShell 7 session, and run the server again. The startup script reuses modules already loaded in a session to avoid loading conflicting Az assemblies.

### Authentication Issues

**Error: "Not authenticated to Azure" or context errors**

**Solutions:**
```powershell
# Clear existing context
Clear-AzContext -Force

# Re-authenticate
Connect-AzAccount

# Verify connection
Get-AzContext

# If needed, select specific subscription
Set-AzContext -Subscription "Your-Subscription-Name"

# List all available subscriptions
Get-AzSubscription
```

**Error: "Device code authentication not working"**

Try interactive browser authentication:
```powershell
Connect-AzAccount -UseDeviceAuthentication
```

### No Data Showing in Dashboard

**Verify Azure Local resources exist:**
```powershell
# Check for Azure Local clusters
Get-AzResource -ResourceType "Microsoft.AzureStackHCI/clusters"

# Check for Arc-enabled servers
Get-AzConnectedMachine

# Verify you're in the correct subscription
Get-AzContext | Select-Object Name, Subscription
```

**Check RBAC permissions:**
- Ensure you have at least **Reader** role on:
  - Azure Local clusters
  - Arc-enabled servers
  - Resource groups containing these resources

**Verify resource providers are registered:**
```powershell
# Check registration status
Get-AzResourceProvider -ProviderNamespace Microsoft.AzureStackHCI
Get-AzResourceProvider -ProviderNamespace Microsoft.HybridCompute

# If not registered, register them
Register-AzResourceProvider -ProviderNamespace Microsoft.AzureStackHCI
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridCompute
```

### Port Already in Use

**Error: "Port 8081 is already in use"**

**Solutions:**
```bash
# Option 1: Find and stop the process using port 8081
# macOS/Linux
lsof -ti:8081 | xargs kill -9

# Windows
netstat -ano | findstr :8081
# Then use Task Manager to stop the process

# Option 2: Use a different port
pwsh Start-AzureLocalServer.ps1 -Port 8082
```

### Cost Analysis Shows Zero

**If cost analysis shows $0 or no data:**

1. Verify nodes have core count information:
   ```powershell
   Get-AzConnectedMachine | Select-Object Name, @{N='Cores';E={$_.Properties.detectedProperties.coreCount}}
   ```

2. Check if Azure Hybrid Benefit is properly configured:
   ```powershell
   Get-AzConnectedMachine | Select-Object Name, @{N='LicenseProfile';E={$_.LicenseProfile}}
   ```

3. Ensure Arc agent is up to date on your nodes

### PDF Export Not Working

**If PDF export fails or produces blank pages:**

1. Ensure browser has JavaScript enabled
2. Try refreshing the page and re-exporting
3. Check browser console for errors (F12)
4. Try a different browser (Chrome/Edge recommended)

### Performance Issues

**If inventory collection is slow:**

1. This is normal for large environments with many VMs
2. Be patient - collecting extensions for many nodes takes time
3. Consider running during off-peak hours
4. Check your internet connection to Azure

**If web interface is slow:**

1. Clear browser cache and refresh
2. Reduce the number of resources displayed using filters
3. Export to PDF for offline viewing of large datasets

## Best Practices

### Regular Inventory Collection

- **Schedule regular scans** of your Azure Local environment to track changes over time
- **Compare reports** to identify drift in configurations or unexpected changes
- **Document baselines** for capacity planning and compliance

### Cost Optimization

- **Review Azure Hybrid Benefit status** regularly to ensure all eligible nodes are configured
- **Monitor core counts** as you add or remove nodes
- **Use cost projections** for budget planning and forecasting
- **Track savings** to demonstrate ROI of Azure Hybrid Benefit

### License Compliance

- **Audit license usage** monthly to ensure compliance
- **Track ESU profiles** for servers requiring Extended Security Updates
- **Document Hybrid Benefit** activation for audit purposes
- **Monitor license expiration** dates proactively

### Security and Compliance

- **Review WAF assessment** findings regularly
- **Address security recommendations** systematically
- **Keep Arc agents updated** on all nodes
- **Monitor agent connectivity** for security alerts
- **Export PDF reports** for compliance documentation

### Operational Excellence

- **Keep modules updated**: The script auto-updates, but verify periodically
- **Test in non-production first**: Validate the tool before production use
- **Document your environment**: Use the PDF export for disaster recovery planning
- **Monitor Arc Gateway health**: Regular checks of Arc connectivity
- **Track workload distribution**: Balance VMs across nodes for optimal performance

## Limitations and Known Issues

### Current Limitations

1. **Local Server Only**: The web server binds to localhost and is not accessible remotely
   - **Workaround**: Use SSH tunneling if remote access is needed

2. ~~**Single Subscription**~~: The tool now scans **all Azure subscriptions** the authenticated account has access to, automatically switching context as needed

3. **Read-Only Operations**: The tool only reads data and does not modify any Azure resources
   - This is by design for safety

4. **Cost Accuracy**: Cost calculations are based on publicly available pricing
   - Actual costs may vary based on Enterprise Agreements or other pricing models
   - Always verify with official Azure billing

5. **Extension Collection Time**: Gathering extensions for many nodes can take several minutes
   - This is due to API rate limiting and is expected behavior

### Known Issues

- **Large Environments**: Environments with 100+ VMs may experience longer collection times (5-10 minutes)
- **Browser Memory**: Very large datasets may consume significant browser memory
  - Recommendation: Use PDF export for large environments
- **PDF Generation**: Complex reports with many tables may take 30-60 seconds to generate

## Security Notes

- ✅ **Localhost Only**: The server runs on localhost (127.0.0.1) and is not accessible from external networks
- ✅ **Request Validation**: Every request is checked — the host must be localhost/loopback and any `Origin` header must match the dashboard's own origin; other requests receive `403` (defends against CSRF and DNS rebinding)
- ✅ **Same-Origin API**: No CORS headers are emitted — other websites open in your browser cannot read the inventory API
- ✅ **Output Encoding**: All Azure-sourced values (resource names, statuses, versions, error messages) are HTML-escaped before rendering, preventing XSS from maliciously named resources
- ✅ **Subresource Integrity**: Third-party CDN scripts (jsPDF, html2canvas) are pinned with SRI hashes — a tampered CDN file will not execute
- ✅ **Explicit Sign-In**: The Azure device-code login only starts when you click the sign-in button, never automatically
- ✅ **Consent-Based Module Install**: Missing Az modules are only installed from PSGallery after you approve
- ✅ **Azure AD Authentication**: All Azure access requires proper authentication through Az PowerShell
- ✅ **No Credential Storage**: No credentials are stored or transmitted by the application
- ✅ **Read-Only Operations**: The tool only performs read operations, no modifications to Azure resources
- ✅ **Real-Time Data**: All data is retrieved in real-time from your Azure subscription (no local caching of sensitive data)
- ✅ **RBAC Enforcement**: Respects Azure RBAC permissions - you only see what you have access to
- ⚠️ **Cost Data**: Cost calculations are estimates only and should not be used for billing purposes

**Security Best Practices:**
- Always run the tool from a secure, trusted workstation
- Keep PowerShell and Azure modules updated to the latest versions
- Review the source code before running in production environments
- Do not expose the local server to untrusted networks
- Use the tool with accounts that have appropriate (minimal) permissions

## Version and Changelog

**Current Version**: 1.2.0

See the [release information for v1.2.0](https://github.com/GetToThe-Cloud/documenter-azure-local/commits/v1.2.0) for the changelog.

### Features in v1.1.130
- ✅ **Cross-subscription scanning** across all Azure subscriptions
- ✅ **Cluster-level Azure Hybrid Benefit** detection via `softwareAssuranceProperties`
- ✅ **VM-to-cluster mapping** via logical network subnet prefix matching
- ✅ **Executive PDF export** with the GetToTheCloud WebP wordmark, branded cover page, Azure-themed tables, section headers, and page numbers
- ✅ **Immediate Ctrl+C shutdown** for the local inventory server
- ✅ Complete Azure Local cluster and node inventory
- ✅ Hardware specifications tracking (manufacturer, model, serial, cores, memory)
- ✅ Virtual machine inventory with resource group, IP address, logical network, and cluster association
- ✅ Logical networks and storage paths documentation
- ✅ Azure Arc ecosystem integration (Custom Locations, Resource Bridges, Gateways)
- ✅ License compliance tracking with ESU profiles
- ✅ Per-node cost breakdown with savings calculations
- ✅ Well-Architected Framework assessment
- ✅ Automatic PowerShell module installation and updates
- ✅ Interactive web dashboard with dark theme
- ✅ PowerShell 7.0+ requirement validation

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file in the parent repository for details.

## 👨‍💻 Author

**Alex ter Neuzen**  
IT Consultant with experience in Azure Local, Azure Landing Zones and Azure Virtual Desktop

🌐 Website: [GetToTheCloud](https://www.gettothe.cloud)  
📧 Contact: Through website  
💼 Specialties: Azure Landing Zones, Cloud Adoption, Infrastructure as Code

---

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow PowerShell best practices and style guidelines
- Test changes with multiple Azure Local environments
- Update documentation for any new features
- Ensure PowerShell 7.0+ compatibility
- Add error handling for new code paths

## Support and Resources

### Documentation and Learning

- **Azure Local (Azure Stack HCI)**: [Official Documentation](https://learn.microsoft.com/azure-stack/hci/)
- **Azure Arc**: [Arc Overview](https://learn.microsoft.com/azure/azure-arc/)
- **Azure PowerShell**: [Az Module Documentation](https://learn.microsoft.com/powershell/azure/)
- **PowerShell 7**: [PowerShell Documentation](https://learn.microsoft.com/powershell/)

### Getting Help

**For issues with this tool:**
- 🐛 [Report bugs or request features](https://github.com/GetToThe-Cloud/AzureDocumenter/issues)
- 💬 [Join discussions](https://github.com/GetToThe-Cloud/AzureDocumenter/discussions)
- 📧 Contact the maintainers through GitHub

**For Azure Local issues:**
- [Azure Stack HCI Community](https://techcommunity.microsoft.com/t5/azure-stack-hci/bd-p/AzureStackHCI)
- [Microsoft Support](https://support.microsoft.com/)

**For Azure PowerShell issues:**
- [Az PowerShell GitHub](https://github.com/Azure/azure-powershell)
- [PowerShell Documentation](https://learn.microsoft.com/powershell/azure/)

### Related Projects

- **[Azure Landing Zone Inventory](../azurelandingzone-inventory/)**: Comprehensive Azure subscription documentation
- **[Azure Virtual Desktop Inventory](../azurevirtualdesktop-inventory/)**: AVD environment documentation and analysis
- **[Azure Documenter](https://github.com/GetToThe-Cloud/AzureDocumenter)**: Parent project with all documenter tools

### Community and Updates

- 🌐 **Website**: [GetToThe.Cloud](https://www.gettothe.cloud)
- 💼 **GitHub**: [GetToThe-Cloud](https://github.com/GetToThe-Cloud)
- 📝 **Blog**: Check our website for articles and updates

## Acknowledgments

- Microsoft Azure team for the Az PowerShell modules
- Azure Stack HCI product team for comprehensive APIs
- jsPDF library for PDF export functionality
- Community contributors and testers

## Feedback

We value your feedback! If you have suggestions, find bugs, or want to request features:

1. **Open an issue** on GitHub with detailed information
2. **Start a discussion** for general questions or ideas
3. **Submit a pull request** with improvements

Your feedback helps make this tool better for everyone in the Azure Local community!
