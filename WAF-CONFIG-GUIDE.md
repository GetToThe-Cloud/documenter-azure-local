# Azure Local WAF Assessment Configuration Guide

## Overview

The Well-Architected Framework (WAF) assessment for Azure Local is now **fully configurable** through an external JSON file. The configuration is loaded from the server on startup, allowing you to customize assessment criteria, weights, thresholds, and messages without modifying code.

## Architecture

```
Server Startup → Load waf-config.json → Store in memory
Client Load → Fetch from /api/waf/config → Assessment begins
User Request → Evaluate checks → Calculate score → Display results
```

## Key Features

### ✅ Separable WAF Scoring
- **External Configuration**: All WAF rules defined in `waf-config.json`
- **Server-Side Loading**: Configuration loaded when server starts
- **API Endpoint**: `/api/waf/config` serves configuration to client
- **Version Control**: Track configuration changes with version field
- **No Code Changes**: Update assessment criteria without touching app.js

### ✅ WAF in PDF Export
- WAF assessment now included in exported PDFs
- Overall WAF score displayed
- All five pillars with check results
- Color-coded status (pass/warning/fail)
- Detailed messages and recommendations

### ✅ Customizable Assessment Rules
- Modify check conditions and thresholds
- Adjust weights to prioritize certain checks
- Customize pass/warning/fail messages
- Add or remove checks as needed
- Update recommendations for failed checks

## Configuration File Structure

### File Location
```
/azurelocal-inventory/waf-config.json
```

### Main Sections

```json
{
  "version": "1.0.0",
  "description": "Azure Local (Azure Stack HCI) Well-Architected Framework Assessment",
  "lastUpdated": "2026-03-09",
  "pillars": {
    "reliability": { ... },
    "security": { ... },
    "costOptimization": { ... },
    "performance": { ... },
    "operationalExcellence": { ... }
  },
  "scoring": {
    "method": "weighted",
    "thresholds": { ... },
    "messages": { ... }
  }
}
```

## Pillar Structure

### Five Pillars of Well-Architected Framework

1. **Reliability** - System resilience, HA, and failover
2. **Security** - Threat protection and compliance
3. **Cost Optimization** - Financial efficiency and licensing
4. **Performance Efficiency** - Resource capacity and optimization
5. **Operational Excellence** - Monitoring and management

### Pillar Configuration

```json
{
  "reliability": {
    "name": "Reliability",
    "order": 1,
    "description": "Ensuring system resilience and availability",
    "assessment": "Evaluation of high availability, redundancy, and failover capabilities",
    "checks": [ ... ]
  }
}
```

## Check Structure

### Check Properties

Each check contains:

- **id**: Unique identifier (e.g., `"rel-001"`)
- **name**: Short descriptive name
- **description**: What the check validates
- **weight**: Importance (1-3, where 3 is most important)
- **condition**: Expression to evaluate (returns true/false)
- **warningCondition**: Optional partial pass condition
- **dataPoints**: Array of data fields used
- **passMessage**: Message when check passes
- **warningMessage**: Message for partial pass
- **failMessage**: Message when check fails
- **recommendation**: Advice for failed checks

### Example Check

```json
{
  "id": "cost-001",
  "name": "Azure Hybrid Benefit utilization",
  "description": "Hybrid Benefit provides FREE licensing ($10/core saved per month)",
  "weight": 3,
  "condition": "nodesWithHybridBenefit >= totalNodes",
  "warningCondition": "nodesWithHybridBenefit >= totalNodes * 0.5",
  "dataPoints": ["totalNodes", "nodesWithHybridBenefit", "potentialMonthlySavings"],
  "passMessage": "✓ All nodes ({nodesWithHybridBenefit} of {totalNodes}) use Azure Hybrid Benefit",
  "warningMessage": "⚠ {nodesWithHybridBenefit} of {totalNodes} nodes use Hybrid Benefit - potential savings: ${potentialMonthlySavings}/month",
  "failMessage": "✗ Only {nodesWithHybridBenefit} of {totalNodes} nodes use Hybrid Benefit - enable to save ${potentialMonthlySavings}/month",
  "recommendation": "Enable Azure Hybrid Benefit on all eligible nodes to eliminate per-core licensing costs"
}
```

## Data Points

### Available Data Points

The following data points are calculated from your inventory and can be used in conditions:

#### Cluster & Node Metrics
- `totalClusters` - Total number of clusters
- `multiNodeClusters` - Clusters with 2+ nodes
- `totalNodes` - Total number of nodes
- `connectedNodes` - Nodes with "Connected" status
- `upToDateNodes` - Nodes without pending updates
- `nodesWithAgents` - Nodes with Arc agents
- `nodesWithMonitoring` - Nodes with monitoring capability
- `nodesWithExtensions` - Nodes with Arc extensions

#### Resource Metrics
- `avgCoresPerNode` - Average physical cores per node
- `nodesWithSufficientMemory` - Nodes with 64GB+ RAM
- `nodesWithMultipleCores` - Nodes with 16+ cores
- `vmDistributionBalanced` - Boolean: VMs evenly distributed

#### Operational Metrics
- `clustersWithVersion` - Clusters reporting software version
- `hasStoragePaths` - Boolean: Storage paths configured
- `totalStoragePaths` - Number of storage paths
- `hasArcBridges` - Boolean: Arc Resource Bridges present
- `totalArcBridges` - Number of Arc Resource Bridges
- `hasLogicalNetworks` - Boolean: Logical networks configured
- `totalLogicalNetworks` - Number of logical networks
- `hasCustomLocations` - Boolean: Custom Locations present
- `totalCustomLocations` - Number of Custom Locations

#### Cost Metrics
- `nodesWithHybridBenefit` - Nodes with Azure Hybrid Benefit enabled
- `potentialMonthlySavings` - Potential monthly savings ($)

## Condition Expressions

### Syntax

Conditions are JavaScript expressions that evaluate to `true` or `false`:

```javascript
// Simple comparison
"totalNodes >= 2"

// Percentage calculation
"connectedNodes >= totalNodes * 0.9"

// Equality check
"vmDistributionBalanced == true"

// Boolean check
"hasArcBridges == true"

// Complex condition
"multiNodeClusters > 0 && multiNodeClusters < totalClusters"
```

### Operators

- Comparison: `==`, `!=`, `>`, `>=`, `<`, `<=`
- Logical: `&&` (and), `||` (or), `!` (not)
- Arithmetic: `+`, `-`, `*`, `/`

### Examples

```json
// All nodes must be connected
"connectedNodes == totalNodes"

// At least 90% of nodes should be up to date
"upToDateNodes >= totalNodes * 0.9"

// Must have at least one Arc Resource Bridge
"hasArcBridges == true"

// Average cores should be 16 or more
"avgCoresPerNode >= 16"
```

## Message Placeholders

### Dynamic Content

Messages support placeholders that are replaced with actual values:

```json
{
  "passMessage": "✓ All nodes ({connectedNodes} of {totalNodes}) are connected",
  "failMessage": "✗ Only {connectedNodes} of {totalNodes} nodes connected"
}
```

### Placeholder Syntax

Use curly braces around any data point name: `{dataPointName}`

Examples:
- `{totalNodes}` → Replaced with actual node count
- `{potentialMonthlySavings}` → Replaced with calculated savings
- `{avgCoresPerNode}` → Replaced with average cores

## Scoring System

### Weighted Scoring

The scoring system uses **weighted** calculations:

```
Score = (Σ passed_weights + Σ warning_weights × 0.5) / Σ total_weights × 100
```

- **Pass**: Full weight awarded
- **Warning**: Half weight awarded
- **Fail**: Zero weight awarded

### Weight Guidelines

- **Weight 1**: Minor or informational checks
- **Weight 2**: Important checks affecting one pillar
- **Weight 3**: Critical checks affecting multiple areas

### Score Thresholds

```json
{
  "thresholds": {
    "excellent": 80,
    "good": 60,
    "needsImprovement": 40
  }
}
```

- **80-100**: Excellent (Green)
- **60-79**: Good (Yellow)
- **40-59**: Needs Improvement (Orange)
- **0-39**: Poor (Red)

## Customization Guide

### Change Check Conditions

To modify when a check passes or fails:

```json
{
  "condition": "nodesWithSufficientMemory >= totalNodes * 0.95",
  "warningCondition": "nodesWithSufficientMemory >= totalNodes * 0.8"
}
```

### Adjust Check Weights

To change importance of a check:

```json
{
  "weight": 3  // Change to 1 (low), 2 (medium), or 3 (high)
}
```

### Modify Messages

Update any message:

```json
{
  "passMessage": "✓ Custom success message with {dataPoint}",
  "failMessage": "✗ Custom failure message"
}
```

### Add New Checks

1. Add a new check object to the appropriate pillar
2. Provide unique ID
3. Define condition and data points
4. Set weight and messages
5. Restart server to load new configuration

Example:

```json
{
  "id": "sec-004",
  "name": "Security baseline compliance",
  "description": "Nodes should meet security baseline requirements",
  "weight": 2,
  "condition": "secureNodes >= totalNodes * 0.95",
  "dataPoints": ["totalNodes", "secureNodes"],
  "passMessage": "✓ {secureNodes} of {totalNodes} nodes meet security baseline",
  "failMessage": "✗ Only {secureNodes} of {totalNodes} nodes meet security baseline",
  "recommendation": "Apply security baseline configuration to all nodes"
}
```

## How to Update Configuration

### Method 1: Direct File Edit

1. Open `waf-config.json` in your editor
2. Make desired changes
3. Save the file
4. Restart the PowerShell server
5. Refresh the browser

### Method 2: Version Control

1. Commit changes to `waf-config.json`
2. Update the `version` and `lastUpdated` fields
3. Push to repository
4. Pull on target system
5. Restart server

## Troubleshooting

### Configuration Not Loading

**Problem**: WAF shows "Configuration not available"

**Solutions**:
- Verify `waf-config.json` exists in the same directory as Start-AzureLocalServer.ps1
- Check JSON syntax (use jsonlint.com to validate)
- Review server console for error messages
- Restart the PowerShell server

### Checks Always Failing

**Problem**: Checks show red even when conditions should pass

**Solutions**:
- Verify data point names match exactly (case-sensitive)
- Check that data points are calculated in `calculateWAFDataPoints()`
- Use browser console to inspect calculated values
- Review condition syntax for errors

### Score Seems Wrong

**Problem**: Score doesn't match expectations

**Solutions**:
- Remember: warning checks count as 0.5 × weight
- Verify all weights are set correctly
- Check that total weights match your intent
- Review which checks passed/warned/failed

## Best Practices

### 1. **Test Before Deploying**
Always test configuration changes in a dev environment before production

### 2. **Version Your Changes**
Update `version` and `lastUpdated` fields with each change

### 3. **Document Custom Checks**
Add comments (in a separate doc) explaining custom checks

### 4. **Keep Weights Balanced**
Don't overuse weight 3; reserve for truly critical checks

### 5. **Use Meaningful Messages**
Provide clear, actionable messages and recommendations

### 6. **Backup Original**
Keep a copy of the original configuration before extensive modifications

## Support

For questions or issues:
- Check this guide first
- Review the example configuration
- Inspect browser console for errors
- Check PowerShell server output
- Validate JSON syntax

---

**Configuration Version**: 1.0.0  
**Last Updated**: March 9, 2026  
**Compatibility**: Azure Local Inventory Dashboard v1.0.0+
