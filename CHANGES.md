# Changelog

All notable changes to the Azure Local Inventory Dashboard are documented in this file.

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
