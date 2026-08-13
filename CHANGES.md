# Changelog

All notable changes to the Azure Local Inventory Dashboard are documented in this file.

---

## [1.2.0] - 2026-08-06

### Security
- **XSS fix (dashboard)**: all Azure-sourced values (cluster/node/VM/network names, resource groups, versions, statuses, error messages, WAF messages, explanations) are now HTML-escaped via a new `escapeHtml()` helper before being rendered with `innerHTML`
- **JS injection fix**: inline `onclick` handlers that interpolated resource names into JavaScript strings were replaced with `data-*` attributes and a single delegated click listener
- **CORS**: removed the `Access-Control-Allow-Origin: *` header from all API responses — the dashboard is same-origin and no longer readable by other websites open in the browser
- **CSRF / DNS-rebinding defense**: every request is validated — the request host must be `localhost`/loopback and, when an `Origin` header is present, it must match `http://localhost:<port>`; anything else gets `403`
- **Login endpoint**: `/api/auth/login` now accepts `POST` only, and the device-code login is no longer triggered automatically on page load — it requires an explicit click on the sign-in button
- **Module install**: missing Az modules are no longer installed silently — the server asks for consent first, pins the repository to PSGallery, and no longer uses `-AllowClobber`
- **Supply chain**: added Subresource Integrity (`integrity` + `crossorigin`) attributes to the jsPDF, jsPDF-AutoTable, and html2canvas CDN script tags

### Changed
- **PDF footer**: removed the confidential marking; exported pages retain only the page number and visual divider.
- **PDF export styling**: added the GetToTheCloud wordmark, branded paper-toned cover, navy and Azure section styling, and updated table defaults.
- **Logo delivery**: packaged and served the wordmark as binary WebP data; the browser decodes it before converting it in memory for jsPDF.
- **Ctrl+C shutdown**: replaced the blocking listener wait with an async, cancellation-aware loop and native console handler.
- **Az module startup**: reused modules already loaded in the current PowerShell session and added a clear recovery message for conflicting assemblies.

---

## [1.1.135] - 2026-03-20

### Changed
- Changed the filtering for Azure Stack HCI Github issue #1

---

## [1.1.130] - 2026-03-16

### Changed
- Graceful Ctrl+C shutdown: replaced blocking `GetContext()` with `GetContextAsync()` + 500 ms polling and a `CancelKeyPress` handler so the server stops immediately on Ctrl+C
- PSGallery packaging: added `documenter-azure-local.psd1` module manifest and `documenter-azure-local.psm1` root module; `FunctionsToExport` declares `Get-AzureLocalInventory` and `Start-AzureLocalServer`
- `Start-AzureLocalServer` refactored from a runnable script into an exported function; removed script-level `param`, shebang, and `PSScriptInfo` block

---

## [1.1.124] - 2026-03-13

### Added

#### Cross-Subscription Support
- Inventory collection now iterates across **all Azure subscriptions** the authenticated account has access to
- Arc machines are pre-collected across subscriptions with `_SubscriptionId` stamp for context switching
- Automatic subscription context switching during VM and resource collection
- Removed the previous single-subscription limitation

#### VM-to-Cluster Mapping via Logical Network
- Virtual machines are now mapped to clusters using **logical network subnet prefix matching**
- Arc agent NIC IPv4 addresses are matched against inventoried logical network subnets
- `logicalNetwork` field added to VM data for network association visibility
- VM collection moved **outside the cluster loop** for better performance and accuracy

#### Cluster-Level Azure Hybrid Benefit Detection
- Azure Hybrid Benefit is now detected at the **cluster level** via `softwareAssuranceProperties.softwareAssuranceStatus`
- Nodes **inherit** the Hybrid Benefit status from their parent cluster
- Replaced the previous per-node license profile detection approach
- More accurate AHB status reflecting the actual Azure Local licensing model

#### VM Data Enrichment
- `cpuCount` extracted from `DetectedProperty['logicalCoreCount']`
- `memoryMB` extracted from `DetectedProperty['totalPhysicalMemoryInBytes']` (converted to MB)
- IPv4 address extracted from `NetworkProfileNetworkInterface[].ipAddress[Version='IPv4'].address`
- `resourceGroup` added to VM data
- `clusterName` derived from logical network mapping

#### Executive PDF Export
- **Cover page** with Azure blue branded header, executive summary box, and resource inventory counts
- **Branded table theme** with Azure blue headers and alternating row colors
- **Section headers** with colored bars for visual structure
- **Page footers** with page numbers and "CONFIDENTIAL" marking
- Cluster table enriched with Resource Group, Software Version, and Hybrid Benefit columns
- Node table enriched with OS Version and Hybrid Benefit columns
- Logical Network table enriched with Address Prefix column
- Arc Resource Bridge table enriched with Provider column
- VM table updated with Resource Group, IP Address, Logical Network, and OS columns
- Cost analysis rendered as a formatted table instead of plain text
- Removed old plain-text Summary section (replaced by executive summary on cover page)

### Changed

#### Web UI
- VM table: Replaced `Node` column with `Resource Group` column
- VM table: Added `IP Address`, `Logical Network`, `CPUs`, and `Memory` columns
- Removed non-functional `vm.nodeName` and `vm.location` references

#### Data Collection
- Arc machine collection now happens in a pre-collection phase across all subscriptions
- Machines split by `Kind = 'HCI'` (guest VMs) vs non-HCI (physical nodes)
- VM collection runs independently after the cluster loop
- Post-VM-loop updates `vmsByCluster` counts and `clusterEntry.vmCount`
- Cost calculations use cluster-level AHB status instead of per-node license profiles

### Fixed
- Parser error: Missing `catch`/`finally` block on `try` statement for VM REST API call
- VM collection no longer dependent on being inside the cluster iteration loop
- Subscription context correctly restored after cross-subscription resource queries

---

## [1.0.0] - Initial Release

### Features
- Complete Azure Local cluster and node inventory
- Hardware specifications tracking (manufacturer, model, serial, cores, memory)
- Virtual machine inventory with placement details
- Logical networks and storage paths documentation
- Azure Arc ecosystem integration (Custom Locations, Resource Bridges, Gateways)
- License compliance tracking with ESU profiles
- Azure Hybrid Benefit detection and cost analysis
- Per-node cost breakdown with savings calculations
- Well-Architected Framework (WAF) assessment with external configuration
- Automatic PowerShell module installation and updates
- Interactive web dashboard with dark theme
- PDF export functionality
- PowerShell 7.0+ requirement validation
