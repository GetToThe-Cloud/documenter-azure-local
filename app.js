// Azure Local Inventory - Client Application

const APP_VERSION = '1.2.0';
console.log(`🚀 Azure Local Inventory app.js loaded - Version ${APP_VERSION}`);

let inventoryData = null;
let wafConfig = null;

console.log('⏳ WAF configuration will be loaded from server...');

// Escape untrusted values (Azure resource names etc.) before inserting into HTML
function escapeHtml(value) {
    if (value === null || value === undefined) return '';
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}
const esc = escapeHtml;

// Delegated click handling avoids injecting data into inline onclick attributes
document.addEventListener('click', (event) => {
    const target = event.target.closest('[data-action]');
    if (!target) return;
    event.preventDefault();
    switch (target.dataset.action) {
        case 'filter-cluster': filterNodesByCluster(target.dataset.name); break;
        case 'show-node': showNodeExtensions(target.dataset.name); break;
        case 'show-section': showSection(target.dataset.section); break;
        case 'show-subnets': showSubnetModal(parseInt(target.dataset.index, 10)); break;
    }
});

// Load WAF configuration from server
async function loadWAFConfiguration() {
    try {
        console.log('📋 Loading WAF configuration from server...');
        const response = await fetch('/api/waf/config');
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        wafConfig = await response.json();
        console.log('✅ WAF configuration loaded successfully from server');
        console.log(`   Version: ${wafConfig.version}`);
        console.log(`   Pillars: ${Object.keys(wafConfig.pillars || {}).length}`);
        return true;
    } catch (error) {
        console.error('❌ Failed to load WAF configuration:', error);
        console.warn('⚠️  WAF Assessment features may not work properly');
        return false;
    }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', async () => {
    console.log('📄 DOM Content Loaded - Initializing app...');
    
    // Load WAF configuration from server
    await loadWAFConfiguration();
    
    const versionElement = document.getElementById('appVersion');
    if (versionElement) {
        versionElement.textContent = `Version: ${APP_VERSION}`;
    }
    checkAuthStatus();
});

// Check authentication status
async function checkAuthStatus() {
    try {
        console.log('🔐 Checking Azure authentication status...');
        const response = await fetch('/api/auth/status');
        const data = await response.json();
        
        console.log('📡 Auth status response:', data);
        
        const authStatusDiv = document.getElementById('authStatus');
        
        if (data.authenticated) {
            console.log('✅ Authenticated as:', data.context.account);
            authStatusDiv.className = 'auth-status authenticated';
            authStatusDiv.innerHTML = `✓ Connected to Azure as <strong>${esc(data.context.account)}</strong> | Subscription: <strong>${esc(data.context.subscription)}</strong>`;
            
            document.getElementById('authRequired').style.display = 'none';
            await loadInventoryData();
        } else {
            console.log('⚠️ Not authenticated - user action required');
            authStatusDiv.className = 'auth-status not-authenticated';
            authStatusDiv.innerHTML = '⚠ Not authenticated with Azure. Click the sign-in button below to start the device login.';
            
            document.getElementById('authRequired').style.display = 'flex';
        }
    } catch (error) {
        console.error('❌ Error checking auth status:', error);
    }
}

// Request Azure login
let loginInProgress = false;
async function requestAzureLogin() {
    if (loginInProgress) {
        console.log('Login already in progress, skipping duplicate request');
        return;
    }
    
    loginInProgress = true;
    const authStatusDiv = document.getElementById('authStatus');
    
    try {
        authStatusDiv.innerHTML = '🔐 Requesting Azure login... Please check your browser or terminal for authentication instructions.';
        
        const response = await fetch('/api/auth/login', { method: 'POST' });
        const data = await response.json();
        
        if (data.success) {
            authStatusDiv.innerHTML = '✓ Authentication successful! Loading data...';
            await checkAuthStatus();
        } else {
            authStatusDiv.className = 'auth-status not-authenticated';
            authStatusDiv.innerHTML = `⚠ Authentication required. ${esc(data.message) || 'Please sign in to Azure.'}`;
        }
    } catch (error) {
        console.error('Error requesting Azure login:', error);
        authStatusDiv.className = 'auth-status not-authenticated';
        authStatusDiv.innerHTML = '⚠ Authentication request failed. Please check the server console or click the button below to retry.';
    } finally {
        loginInProgress = false;
    }
}

// Authenticate with Azure (manual trigger)
async function authenticateAzure() {
    await requestAzureLogin();
}

// Load inventory data
async function loadInventoryData() {
    try {
        console.log('🔄 Starting inventory data load...');
        showProgress();
        
        // Simulate progress while waiting for server
        const progressInterval = simulateProgress();
        
        console.log('📡 Fetching inventory data from /api/inventory/data');
        const response = await fetch('/api/inventory/data');
        
        clearInterval(progressInterval);
        updateProgress(95, 'Processing data...');
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        inventoryData = await response.json();
        console.log('✅ Inventory data loaded:', inventoryData);
        
        updateProgress(100, 'Complete!');
        updateLastRefreshTime(inventoryData.collectionTime);
        renderInventory();
        
        setTimeout(() => hideProgress(), 500);
    } catch (error) {
        console.error('❌ Error loading inventory data:', error);
        hideProgress();
        alert('Failed to load inventory data. See console for details.');
    }
}

// Show loading state
function showLoading() {
    document.querySelectorAll('.content-section tbody').forEach(tbody => {
        tbody.innerHTML = '<tr><td colspan="10" class="loading">Loading</td></tr>';
    });
}

// Progress bar functions
function showProgress() {
    const overlay = document.getElementById('progressOverlay');
    if (overlay) {
        overlay.style.display = 'flex';
        updateProgress(0, 'Initializing...');
    }
}

function hideProgress() {
    const overlay = document.getElementById('progressOverlay');
    if (overlay) {
        setTimeout(() => {
            overlay.style.display = 'none';
        }, 300);
    }
}

function updateProgress(percentage, status) {
    const fill = document.getElementById('progressBarFill');
    const percentageEl = document.getElementById('progressPercentage');
    const statusEl = document.getElementById('progressStatus');
    
    if (fill) fill.style.width = percentage + '%';
    if (percentageEl) percentageEl.textContent = Math.round(percentage) + '%';
    if (statusEl) statusEl.textContent = status;
}

function simulateProgress() {
    let progress = 0;
    const stages = [
        { max: 10, status: 'Connecting to Azure...' },
        { max: 15, status: 'Collecting Arc Gateways...' },
        { max: 25, status: 'Gathering Clusters...' },
        { max: 40, status: 'Analyzing Nodes...' },
        { max: 50, status: 'Retrieving Networks...' },
        { max: 60, status: 'Collecting Images...' },
        { max: 70, status: 'Scanning Storage...' },
        { max: 80, status: 'Checking Virtual Machines...' },
        { max: 90, status: 'Calculating Costs...' }
    ];
    
    let stageIndex = 0;
    
    return setInterval(() => {
        if (progress < 90 && stageIndex < stages.length) {
            const currentStage = stages[stageIndex];
            progress += (currentStage.max - progress) * 0.1;
            
            if (progress >= currentStage.max * 0.9) {
                stageIndex++;
            }
            
            updateProgress(progress, stages[Math.min(stageIndex, stages.length - 1)].status);
        }
    }, 200);
}

// Update last refresh time
function updateLastRefreshTime(timestamp) {
    const lastUpdate = document.getElementById('lastUpdate');
    if (lastUpdate && timestamp) {
        const date = new Date(timestamp);
        lastUpdate.textContent = `Last updated: ${date.toLocaleString()}`;
    }
}

// Refresh inventory
async function refreshInventory() {
    console.log('🔄 Refreshing inventory...');
    const refreshBtn = document.getElementById('refreshBtn');
    refreshBtn.disabled = true;
    refreshBtn.innerHTML = '<span class="icon">⏳</span> Refreshing...';
    
    try {
        await loadInventoryData();
        refreshBtn.innerHTML = '<span class="icon">✓</span> Refreshed!';
        setTimeout(() => {
            refreshBtn.innerHTML = '<span class="icon">🔄</span> Refresh';
            refreshBtn.disabled = false;
        }, 2000);
    } catch (error) {
        console.error('Error refreshing inventory:', error);
        refreshBtn.innerHTML = '<span class="icon">🔄</span> Refresh';
        refreshBtn.disabled = false;
    }
}

// Render inventory
function renderInventory() {
    if (!inventoryData) {
        console.error('No inventory data to render');
        return;
    }
    
    console.log('🎨 Rendering inventory...');
    
    // Update explanations
    updateExplanations();
    
    // Render overview
    renderOverview();
    
    // Render sections
    renderClusters();
    renderNodes();
    renderVersions();
    renderNetworks();
    renderStoragePaths();
    renderCustomLocations();
    renderArcResourceBridges();
    renderArcGateways();
    renderLicenses();
    renderCostAnalysis();
    renderImages();
    renderVirtualMachines();
    renderWAF();
}

// Update explanations
function updateExplanations() {
    if (inventoryData.explanations) {
        const explanationFields = [
            { id: 'overviewExplanation', key: 'overview' },
            { id: 'clustersExplanation', key: 'clusters' },
            { id: 'nodesExplanation', key: 'nodes' },
            { id: 'versionsExplanation', key: 'agentVersions' },
            { id: 'networksExplanation', key: 'logicalNetworks' },
            { id: 'storagePathsExplanation', key: 'storagePaths' },
            { id: 'customLocationsExplanation', key: 'customLocations' },
            { id: 'arcResourceBridgesExplanation', key: 'arcResourceBridges' },
            { id: 'licensesExplanation', key: 'licenses' },
            { id: 'imagesExplanation', key: 'images' },
            { id: 'vmsExplanation', key: 'virtualMachines' }
        ];
        
        explanationFields.forEach(field => {
            const element = document.getElementById(field.id);
            if (element && inventoryData.explanations[field.key]) {
                // Convert bullet points to HTML
                element.innerHTML = convertToHTML(inventoryData.explanations[field.key]);
            }
        });
    }
}

// Convert text with bullet points to HTML
function convertToHTML(text) {
    // Split into paragraphs
    const paragraphs = text.split('\n\n');
    let html = '';
    
    paragraphs.forEach(para => {
        const lines = para.split('\n');
        let isList = false;
        let listItems = [];
        let regularText = '';
        
        lines.forEach(line => {
            const trimmed = line.trim();
            if (trimmed.startsWith('• ') || trimmed.startsWith('- ')) {
                isList = true;
                listItems.push(trimmed.substring(2));
            } else if (trimmed) {
                regularText += (regularText ? ' ' : '') + trimmed;
            }
        });
        
        if (regularText) {
            html += `<p>${esc(regularText)}</p>`;
        }
        
        if (isList && listItems.length > 0) {
            html += '<ul>';
            listItems.forEach(item => {
                html += `<li>${esc(item)}</li>`;
            });
            html += '</ul>';
        }
    });
    
    return html;
}

// Render overview
function renderOverview() {
    const summary = inventoryData.summary || {};
    
    // Update summary cards
    document.getElementById('totalClusters').textContent = summary.totalClusters || 0;
    document.getElementById('totalNodes').textContent = summary.totalNodes || 0;
    document.getElementById('totalNetworks').textContent = summary.totalLogicalNetworks || 0;
    document.getElementById('totalImages').textContent = summary.totalImages || 0;
    document.getElementById('totalStoragePaths').textContent = summary.totalStoragePaths || 0;
    document.getElementById('totalCustomLocations').textContent = summary.totalCustomLocations || 0;
    document.getElementById('totalArcResourceBridges').textContent = summary.totalArcResourceBridges || 0;
    document.getElementById('totalArcGateways').textContent = summary.totalArcGateways || 0;
    document.getElementById('totalLicenses').textContent = summary.totalLicensedMachines || 0;
    document.getElementById('totalVMs').textContent = summary.totalVirtualMachines || 0;
    
    // Render cluster status chart
    renderStatusChart('clusterStatusChart', summary.clustersByStatus || {}, 'Cluster Status');
    
    // Render node status chart
    renderStatusChart('nodeStatusChart', summary.nodesByStatus || {}, 'Node Status');
    
    // Render VMs by cluster chart
    renderVMsByClusterChart(summary.vmsByCluster || {});
}

// Render status chart
function renderStatusChart(containerId, statusData, title) {
    const container = document.getElementById(containerId);
    if (!container) return;
    
    if (Object.keys(statusData).length === 0) {
        container.innerHTML = '<p>No data available</p>';
        return;
    }
    
    let html = '<div class="chart-bars">';
    const total = Object.values(statusData).reduce((a, b) => a + b, 0);
    
    for (const [status, count] of Object.entries(statusData)) {
        const percentage = total > 0 ? (count / total * 100).toFixed(1) : 0;
        html += `
            <div class="chart-bar-item">
                <div class="chart-bar-label">${esc(status)}: ${esc(count)} (${percentage}%)</div>
                <div class="chart-bar">
                    <div class="chart-bar-fill" style="width: ${percentage}%"></div>
                </div>
            </div>
        `;
    }
    
    html += '</div>';
    container.innerHTML = html;
}

// Render VMs by cluster chart
function renderVMsByClusterChart(vmsByCluster) {
    const container = document.getElementById('vmsByClusterChart');
    if (!container) return;
    
    if (Object.keys(vmsByCluster).length === 0) {
        container.innerHTML = '<p>No data available</p>';
        return;
    }
    
    let html = '<div class="chart-bars">';
    const maxVMs = Math.max(...Object.values(vmsByCluster));
    
    for (const [cluster, count] of Object.entries(vmsByCluster)) {
        const percentage = maxVMs > 0 ? (count / maxVMs * 100).toFixed(1) : 0;
        html += `
            <div class="chart-bar-item">
                <div class="chart-bar-label">${esc(cluster)}: ${esc(count)} VMs</div>
                <div class="chart-bar">
                    <div class="chart-bar-fill" style="width: ${percentage}%"></div>
                </div>
            </div>
        `;
    }
    
    html += '</div>';
    container.innerHTML = html;
}

// Render clusters
function renderClusters() {
    const container = document.getElementById('clustersList');
    if (!container) return;
    
    const clusters = inventoryData.clusters || [];
    
    if (clusters.length === 0) {
        container.innerHTML = '<p>No clusters found</p>';
        return;
    }
    
    let html = '<table id="clustersTable" class="data-table"><thead><tr>';
    html += '<th>Name</th><th>Resource Group</th><th>Location</th><th>Status</th>';
    html += '<th>Software Version</th><th>Nodes</th><th>VMs</th><th>Last Sync</th></tr></thead><tbody>';
    
    clusters.forEach(cluster => {
        const clusterName = esc(cluster.name);
        const nodeCountText = cluster.nodeCount > 0 
            ? `<a href="#" data-action="filter-cluster" data-name="${clusterName}" class="clickable-link">${esc(cluster.nodeCount)}</a>`
            : esc(cluster.nodeCount);
        
        html += '<tr>';
        html += `<td><strong><a href="#" data-action="filter-cluster" data-name="${clusterName}" class="clickable-link">${clusterName}</a></strong></td>`;
        html += `<td>${esc(cluster.resourceGroup)}</td>`;
        html += `<td>${esc(cluster.location)}</td>`;
        html += `<td><span class="badge badge-${getStatusColor(cluster.status)}">${esc(cluster.status)}</span></td>`;
        html += `<td>${esc(cluster.softwareVersion)}</td>`;
        html += `<td>${nodeCountText}</td>`;
        html += `<td>${esc(cluster.vmCount)}</td>`;
        html += `<td>${esc(formatDate(cluster.lastSyncTimestamp))}</td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

// Render nodes
function renderNodes() {
    const container = document.getElementById('nodesList');
    if (!container) return;
    
    const nodes = inventoryData.nodes || [];
    
    if (nodes.length === 0) {
        container.innerHTML = '<p>No nodes found</p>';
        return;
    }
    
    let html = '<table id="nodesTable" class="data-table"><thead><tr>';
    html += '<th>Name</th><th>Cluster</th><th>Status</th>';
    html += '<th>Manufacturer</th><th>Model</th><th>Serial Number</th>';
    html += '<th>Cores</th><th>Memory (GB)</th>';
    html += '<th>Solution Version</th><th>Last Updated</th>';
    html += '<th>Workload</th>';
    html += '<th>Agent Version</th><th>Location</th></tr></thead><tbody>';
    
    nodes.forEach(node => {
        // Build workload summary
        let workload = [];
        if (node.vmCount > 0) {
            workload.push(`${node.vmCount} VM${node.vmCount > 1 ? 's' : ''}`);
        }
        if (node.k8sClusterCount > 0) {
            workload.push(`${node.k8sClusterCount} K8s`);
        }
        const workloadText = workload.length > 0 ? workload.join(', ') : 'None';
        
        html += '<tr>';
        html += `<td><strong><a href="#" data-action="show-node" data-name="${esc(node.name)}" class="clickable-link" title="Click to view extensions">${esc(node.name)}</a></strong></td>`;
        html += `<td><a href="#" data-action="show-section" data-section="clusters" class="clickable-link">${esc(node.clusterName)}</a></td>`;
        html += `<td><span class="badge badge-${getStatusColor(node.status)}">${esc(node.status)}</span></td>`;
        html += `<td>${esc(node.manufacturer || 'Unknown')}</td>`;
        html += `<td>${esc(node.model || 'Unknown')}</td>`;
        html += `<td>${esc(node.serialNumber || 'Unknown')}</td>`;
        html += `<td>${esc(node.physicalCores || 'Unknown')}</td>`;
        html += `<td>${esc(node.memoryGB || 'Unknown')}</td>`;
        html += `<td>${esc(node.solutionVersion || 'Unknown')}</td>`;
        html += `<td>${esc(formatDate(node.lastUpdated) || 'Unknown')}</td>`;
        html += `<td>${esc(workloadText)}</td>`;
        html += `<td>${esc(node.agentVersion)}</td>`;
        html += `<td>${esc(node.location)}</td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

// Render versions
function renderVersions() {
    // Render agent versions
    const agentContainer = document.getElementById('agentVersionsList');
    if (agentContainer) {
        const agentVersions = inventoryData.agentVersions || [];
        
        if (agentVersions.length === 0) {
            agentContainer.innerHTML = '<p>No agent version data available</p>';
        } else {
            let html = '<table class="data-table"><thead><tr>';
            html += '<th>Agent Version</th><th>Node Count</th><th>Nodes</th></tr></thead><tbody>';
            
            agentVersions.forEach(agent => {
                html += '<tr>';
                html += `<td><strong>${esc(agent.version)}</strong></td>`;
                html += `<td>${esc(agent.nodeCount)}</td>`;
                html += `<td>${esc(agent.nodes.join(', '))}</td>`;
                html += '</tr>';
            });
            
            html += '</tbody></table>';
            agentContainer.innerHTML = html;
        }
    }
    
    // Render software versions
    const softwareContainer = document.getElementById('softwareVersionsList');
    if (softwareContainer) {
        const softwareVersions = inventoryData.softwareVersions || [];
        
        if (softwareVersions.length === 0) {
            softwareContainer.innerHTML = '<p>No software version data available</p>';
        } else {
            let html = '<table class="data-table"><thead><tr>';
            html += '<th>OS Name</th><th>OS SKU</th><th>Version</th><th>Node Count</th><th>Nodes</th></tr></thead><tbody>';
            
            softwareVersions.forEach(software => {
                html += '<tr>';
                html += `<td><strong>${esc(software.osName)}</strong></td>`;
                html += `<td>${esc(software.osSku || 'N/A')}</td>`;
                html += `<td>${esc(software.version)}</td>`;
                html += `<td>${esc(software.nodeCount)}</td>`;
                html += `<td>${esc(software.nodes.join(', '))}</td>`;
                html += '</tr>';
            });
            
            html += '</tbody></table>';
            softwareContainer.innerHTML = html;
        }
    }
}

// Render networks
function renderNetworks() {
    const container = document.getElementById('networksList');
    if (!container) return;
    
    const networks = inventoryData.logicalNetworks || [];
    
    if (networks.length === 0) {
        container.innerHTML = '<p>No logical networks found</p>';
        return;
    }
    
    let html = '<table id="networksTable" class="data-table"><thead><tr>';
    html += '<th>Name</th><th>Cluster</th><th>Resource Group</th><th>VM Switch</th>';
    html += '<th>DHCP Enabled</th><th>Subnets</th><th>Status</th></tr></thead><tbody>';
    
    networks.forEach((network, index) => {
        html += '<tr>';
        html += `<td><strong>${esc(network.name)}</strong></td>`;
        html += `<td>${esc(network.clusterName)}</td>`;
        html += `<td>${esc(network.resourceGroup)}</td>`;
        html += `<td>${esc(network.vmSwitchName)}</td>`;
        html += `<td>${network.dhcpEnabled ? '✓ Yes' : '✗ No'}</td>`;
        if (network.subnets && network.subnets.length > 0) {
            html += `<td><a href="#" data-action="show-subnets" data-index="${index}" class="subnet-link">${network.subnets.length} subnet(s) - View Details</a></td>`;
        } else {
            html += `<td>0 subnets</td>`;
        }
        html += `<td><span class="badge badge-${getStatusColor(network.provisioningState)}">${esc(network.provisioningState)}</span></td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

// Show subnet modal
function showSubnetModal(networkIndex) {
    const network = inventoryData.logicalNetworks[networkIndex];
    if (!network) return;
    
    document.getElementById('modalNetworkName').textContent = `Subnets for ${network.name}`;
    
    let html = '<table class="data-table"><thead><tr>';
    html += '<th>Name</th><th>Address Prefix</th><th>VLAN</th><th>IP Pools</th></tr></thead><tbody>';
    
    network.subnets.forEach(subnet => {
        html += '<tr>';
        html += `<td><strong>${esc(subnet.name)}</strong></td>`;
        html += `<td>${esc(subnet.addressPrefix)}</td>`;
        html += `<td>${esc(subnet.vlan)}</td>`;
        const ipPoolCount = subnet.ipPools ? subnet.ipPools.length : 0;
        html += `<td>${ipPoolCount} pool(s)</td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    document.getElementById('modalSubnetContent').innerHTML = html;
    document.getElementById('subnetModal').style.display = 'block';
}

// Close subnet modal
function closeSubnetModal() {
    document.getElementById('subnetModal').style.display = 'none';
}

// Close modal when clicking outside
window.onclick = function(event) {
    const subnetModal = document.getElementById('subnetModal');
    const nodeModal = document.getElementById('nodeExtensionsModal');
    if (event.target == subnetModal) {
        closeSubnetModal();
    }
    if (event.target == nodeModal) {
        closeNodeExtensionsModal();
    }
}

// Render storage paths
function renderStoragePaths() {
    const container = document.getElementById('storagePathsList');
    if (!container) return;
    
    const paths = inventoryData.storagePaths || [];
    
    if (paths.length === 0) {
        container.innerHTML = '<p>No storage paths found</p>';
        return;
    }
    
    let html = '<table id="storagePathsTable" class="data-table"><thead><tr>';
    html += '<th>Name</th><th>Cluster</th><th>Resource Group</th><th>Type</th><th>Path</th><th>Status</th></tr></thead><tbody>';
    
    paths.forEach(path => {
        const resourceType = path.resourceType ? path.resourceType.split('/').pop() : 'N/A';
        html += '<tr>';
        html += `<td><strong>${esc(path.name)}</strong></td>`;
        html += `<td>${esc(path.clusterName)}</td>`;
        html += `<td>${esc(path.resourceGroup)}</td>`;
        html += `<td>${esc(resourceType)}</td>`;
        html += `<td>${esc(path.path)}</td>`;
        html += `<td><span class="badge badge-${getStatusColor(path.provisioningState)}">${esc(path.provisioningState)}</span></td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

// Render custom locations
function renderCustomLocations() {
    const container = document.getElementById('customLocationsList');
    if (!container) return;
    
    const locations = inventoryData.customLocations || [];
    
    if (locations.length === 0) {
        container.innerHTML = '<p>No custom locations found</p>';
        return;
    }
    
    let html = '<table id="customLocationsTable" class="data-table"><thead><tr>';
    html += '<th>Name</th><th>Cluster</th><th>Namespace</th><th>Location</th><th>Status</th></tr></thead><tbody>';
    
    locations.forEach(loc => {
        html += '<tr>';
        html += `<td><strong>${esc(loc.name)}</strong></td>`;
        html += `<td>${esc(loc.clusterName)}</td>`;
        html += `<td>${esc(loc.namespace)}</td>`;
        html += `<td>${esc(loc.location)}</td>`;
        html += `<td><span class="badge badge-${getStatusColor(loc.provisioningState)}">${esc(loc.provisioningState)}</span></td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

// Render Arc Resource Bridges
function renderArcResourceBridges() {
    const container = document.getElementById('arcBridgesList');
    if (!container) return;
    
    const bridges = inventoryData.arcResourceBridges || [];
    
    if (bridges.length === 0) {
        container.innerHTML = '<p>No Arc Resource Bridges found</p>';
        return;
    }
    
    let html = '<table id="arcBridgesTable" class="data-table"><thead><tr>';
    html += '<th>Name</th><th>Cluster</th><th>Status</th><th>Version</th><th>Distro</th><th>Provider</th><th>Location</th></tr></thead><tbody>';
    
    bridges.forEach(bridge => {
        html += '<tr>';
        html += `<td><strong>${esc(bridge.name)}</strong></td>`;
        html += `<td>${esc(bridge.clusterName)}</td>`;
        html += `<td><span class="badge badge-${getStatusColor(bridge.status)}">${esc(bridge.status)}</span></td>`;
        html += `<td>${esc(bridge.version || 'N/A')}</td>`;
        html += `<td>${esc(bridge.distro || 'N/A')}</td>`;
        html += `<td>${esc(bridge.infrastructureConfig || 'N/A')}</td>`;
        html += `<td>${esc(bridge.location)}</td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

// Render Arc Gateways
function renderArcGateways() {
    const container = document.getElementById('arcGatewaysList');
    if (!container) return;
    
    const gateways = inventoryData.arcGateways || [];
    
    if (gateways.length === 0) {
        container.innerHTML = '<p>No Arc Gateways found</p>';
        return;
    }
    
    let html = '<table id="arcGatewaysTable" class="data-table"><thead><tr>';
    html += '<th>Name</th><th>Resource Group</th><th>Location</th><th>Status</th></tr></thead><tbody>';
    
    gateways.forEach(gateway => {
        html += '<tr>';
        html += `<td><strong>${esc(gateway.name)}</strong></td>`;
        html += `<td>${esc(gateway.resourceGroup)}</td>`;
        html += `<td>${esc(gateway.location)}</td>`;
        html += `<td><span class="badge badge-${getStatusColor(gateway.provisioningState)}">${esc(gateway.provisioningState)}</span></td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

// Render licenses
function renderLicenses() {
    const container = document.getElementById('licensesList');
    if (!container) return;
    
    const licenses = inventoryData.licenses || [];
    
    if (licenses.length === 0) {
        container.innerHTML = '<p>No licensed machines found</p>';
        return;
    }
    
    let html = '<table id="licensesTable" class="data-table"><thead><tr>';
    html += '<th>Machine Name</th><th>Cluster</th><th>Resource Group</th><th>License Type(s)</th><th>License State</th><th>Azure Hybrid Benefit</th><th>Physical Cores</th><th>Location</th></tr></thead><tbody>';
    
    licenses.forEach(license => {
        const licenseTypes = license.licenses.map(l => l.type).join(', ');
        const licenseStates = [...new Set(license.licenses.map(l =>l.state))].join(', ');
        const hasHybridBenefit = license.azureHybridBenefitEnabled || false;
        const cores = license.physicalCores || 'N/A';
        
        html += '<tr>';
        html += `<td><strong><a href="#" data-action="show-node" data-name="${esc(license.machineName)}" class="clickable-link">${esc(license.machineName)}</a></strong></td>`;
        html += `<td><a href="#" data-action="show-section" data-section="clusters" class="clickable-link">${esc(license.clusterName)}</a></td>`;
        html += `<td>${esc(license.resourceGroup)}</td>`;
        html += `<td>${esc(licenseTypes)}</td>`;
        html += `<td><span class="badge badge-success">${esc(licenseStates)}</span></td>`;
        html += `<td><span class="badge badge-${hasHybridBenefit ? 'success' : 'warning'}">${hasHybridBenefit ? '✓ Enabled' : '✗ Not Enabled'}</span></td>`;
        html += `<td>${esc(cores)}</td>`;
        html += `<td>${esc(license.location)}</td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

// Render cost analysis
function renderCostAnalysis() {
    const container = document.getElementById('costAnalysisSummary');
    if (!container) return;
    
    const costAnalysis = inventoryData.costAnalysis || {};
    
    if (!costAnalysis.totalCores) {
        container.innerHTML = '<p>No cost data available</p>';
        return;
    }
    
    const hybridPercentage = costAnalysis.totalCores > 0 
        ? Math.round((costAnalysis.nodesWithHybridBenefit / inventoryData.nodes.length) * 100)
        : 0;
    
    const coresWithHybrid = inventoryData.nodes
        .filter(n => n.azureHybridBenefitEnabled)
        .reduce((sum, n) => sum + parseInt(n.physicalCores || 0), 0);
    
    const coresWithoutHybrid = costAnalysis.totalCores - coresWithHybrid;
    
    let html = '<div class="cost-cards">';
    
    // Total Cores Card
    html += '<div class="overview-card">';
    html += '<div class="card-header">Total Physical Cores</div>';
    html += `<div class="card-value">${costAnalysis.totalCores}</div>`;
    html += `<div class="card-footer"><span class="badge badge-success">${coresWithHybrid} with Hybrid Benefit</span> <span class="badge badge-warning">${coresWithoutHybrid} without</span></div>`;
    html += '</div>';
    
    // Current Monthly Cost Card
    html += '<div class="overview-card">';
    html += '<div class="card-header">Current Monthly Cost</div>';
    html += `<div class="card-value">$${costAnalysis.estimatedMonthlyCost.toFixed(2)}</div>`;
    html += `<div class="card-footer">Based on $${esc(costAnalysis.corePrice)}/core/month</div>`;
    html += '</div>';
    
    // Current Yearly Cost Card
    html += '<div class="overview-card">';
    html += '<div class="card-header">Current Yearly Cost</div>';
    html += `<div class="card-value">$${costAnalysis.estimatedYearlyCost.toFixed(2)}</div>`;
    html += `<div class="card-footer">${costAnalysis.estimatedMonthlyCost.toFixed(2)} × 12 months</div>`;
    html += '</div>';
    
    // Hybrid Benefit Adoption Card
    html += '<div class="overview-card">';
    html += '<div class="card-header">Hybrid Benefit Adoption</div>';
    html += `<div class="card-value">${hybridPercentage}%</div>`;
    html += `<div class="card-footer">${costAnalysis.nodesWithHybridBenefit} of ${inventoryData.nodes.length} nodes enabled</div>`;
    html += '</div>';
    
    html += '</div>'; // close cost-cards
    
    // Potential Savings Section
    if (costAnalysis.potentialMonthlySavings > 0) {
        html += '<div class="savings-banner">';
        html += '<h3>💡 Cost Optimization Opportunity</h3>';
        html += '<p>By enabling <strong>Azure Hybrid Benefit</strong> on all nodes, you could save:</p>';
        html += '<div class="savings-values">';
        html += `<div class="savings-item"><strong>Monthly:</strong> $${costAnalysis.potentialMonthlySavings.toFixed(2)}</div>`;
        html += `<div class="savings-item"><strong>Yearly:</strong> $${costAnalysis.potentialYearlySavings.toFixed(2)}</div>`;
        html += '</div>';
        html += '<p class="savings-note">💡 <strong>Action:</strong> Assign Windows Server licenses with Software Assurance to nodes without Hybrid Benefit.</p>';
        html += '</div>';
    } else {
        html += '<div class="success-banner">';
        html += '<h3>✅ Fully Optimized!</h3>';
        html += '<p>All nodes are using Azure Hybrid Benefit. You\'re running Azure Local at NO additional software cost.</p>';
        html += '</div>';
    }
    
    // Node Cost Breakdown Table
    html += '<h3>Node Cost Breakdown</h3>';
    html += '<table class="data-table"><thead><tr>';
    html += '<th>Node Name</th><th>Cluster</th><th>Physical Cores</th><th>Azure Hybrid Benefit</th><th>Monthly Cost</th></tr></thead><tbody>';
    
    inventoryData.nodes.forEach(node => {
        const cores = parseInt(node.physicalCores || 0);
        const hasHybrid = node.azureHybridBenefitEnabled;
        const monthlyCost = hasHybrid ? 0 : (cores * costAnalysis.corePrice);
        
        html += '<tr>';
        html += `<td><strong><a href="#" data-action="show-node" data-name="${esc(node.name)}" class="clickable-link">${esc(node.name)}</a></strong></td>`;
        html += `<td>${esc(node.clusterName || 'N/A')}</td>`;
        html += `<td>${cores}</td>`;
        html += `<td><span class="badge badge-${hasHybrid ? 'success' : 'warning'}">${hasHybrid ? '✓ Enabled' : '✗ Not Enabled'}</span></td>`;
        html += `<td>$${monthlyCost.toFixed(2)}</td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    
    // Pricing Information Footer
    html += '<div class="pricing-footer">';
    html += `<p><strong>Pricing as of ${esc(costAnalysis.pricingDate)}:</strong> Azure Local is charged at $${esc(costAnalysis.corePrice)} USD per physical core per month. `;
    html += `With Azure Hybrid Benefit, customers can use existing Windows Server licenses with Software Assurance to run Azure Local at $${esc(costAnalysis.corePriceWithHybridBenefit)} per core (FREE). `;
    html += `<a href="https://azure.microsoft.com/en-us/pricing/details/azure-local/" target="_blank">View official pricing</a></p>`;
    html += '</div>';
    
    container.innerHTML = html;
}

// Show node extensions modal
function showNodeExtensions(nodeName) {
    const node = inventoryData.nodes.find(n => n.name === nodeName);
    if (!node) {
        console.error('Node not found:', nodeName);
        return;
    }
    
    const modal = document.getElementById('nodeExtensionsModal');
    const modalTitle = document.getElementById('modalNodeName');
    const modalContent = document.getElementById('modalNodeExtensionsContent');
    
    modalTitle.textContent = `Extensions for ${nodeName}`;
    
    let html = '<div class="node-details">';
    
    // Node basic info
    html += '<h3>Node Information</h3>';
    html += '<table class="data-table"><tbody>';
    html += `<tr><td><strong>Cluster:</strong></td><td>${esc(node.clusterName)}</td></tr>`;
    html += `<tr><td><strong>Status:</strong></td><td><span class="badge badge-${getStatusColor(node.status)}">${esc(node.status)}</span></td></tr>`;
    html += `<tr><td><strong>Resource Group:</strong></td><td>${esc(node.resourceGroup)}</td></tr>`;
    html += `<tr><td><strong>Location:</strong></td><td>${esc(node.location)}</td></tr>`;
    html += '</tbody></table>';
    
    // Extensions
    html += '<h3>Installed Extensions</h3>';
    if (node.extensions && node.extensions.length > 0) {
        html += '<table class="data-table"><thead><tr>';
        html += '<th>Name</th><th>Type</th><th>Publisher</th><th>Version</th><th>Status</th><th>Auto Upgrade</th>';
        html += '</tr></thead><tbody>';
        
        node.extensions.forEach(ext => {
            html += '<tr>';
            html += `<td><strong>${esc(ext.name)}</strong></td>`;
            html += `<td>${esc(ext.type)}</td>`;
            html += `<td>${esc(ext.publisher)}</td>`;
            html += `<td>${esc(ext.version)}</td>`;
            html += `<td><span class="badge badge-${getStatusColor(ext.status)}">${esc(ext.status)}</span></td>`;
            html += `<td><span class="badge badge-${ext.autoUpgrade === 'Enabled' ? 'success' : 'secondary'}">${esc(ext.autoUpgrade)}</span></td>`;
            html += '</tr>';
        });
        
        html += '</tbody></table>';
    } else {
        html += '<p>No extensions installed on this node.</p>';
    }
    
    // License information
    if (node.hasLicense && node.licenses && node.licenses.length > 0) {
        html += '<h3>Licenses</h3>';
        html += '<table class="data-table"><thead><tr>';
        html += '<th>License Type</th><th>State</th><th>Details</th>';
        html += '</tr></thead><tbody>';
        
        node.licenses.forEach(lic => {
            html += '<tr>';
            html += `<td><strong>${esc(lic.type)}</strong></td>`;
            html += `<td><span class="badge badge-success">${esc(lic.state)}</span></td>`;
            html += `<td>${esc(lic.edition || lic.assignedDate || 'N/A')}</td>`;
            html += '</tr>';
        });
        
        html += '</tbody></table>';
    }
    
    html += '</div>';
    modalContent.innerHTML = html;
    modal.style.display = 'block';
}

// Close node extensions modal
function closeNodeExtensionsModal() {
    const modal = document.getElementById('nodeExtensionsModal');
    modal.style.display = 'none';
}

// Render images
function renderImages() {
    const container = document.getElementById('imagesList');
    if (!container) return;
    
    const images = inventoryData.images || [];
    
    if (images.length === 0) {
        container.innerHTML = '<p>No images found</p>';
        return;
    }
    
    let html = '<table id="imagesTable" class="data-table"><thead><tr>';
    html += '<th>Name</th><th>Cluster</th><th>OS Type</th><th>Source</th>';
    html += '<th>Version</th><th>Size (GB)</th><th>Status</th></tr></thead><tbody>';
    
    images.forEach(image => {
        html += '<tr>';
        html += `<td><strong>${esc(image.name)}</strong></td>`;
        html += `<td>${esc(image.clusterName)}</td>`;
        html += `<td>${esc(image.osType)}</td>`;
        html += `<td>${esc(image.sourceImageId)}</td>`;
        html += `<td>${esc(image.version)}</td>`;
        html += `<td>${esc(image.sizeInGB)}</td>`;
        html += `<td><span class="badge badge-${getStatusColor(image.provisioningState)}">${esc(image.provisioningState)}</span></td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

// Render virtual machines
function renderVirtualMachines() {
    const container = document.getElementById('vmsList');
    if (!container) return;
    
    const vms = inventoryData.virtualMachines || [];
    
    // Populate cluster filter dropdown
    const clusterFilter = document.getElementById('clusterFilter');
    if (clusterFilter) {
        const clusters = [...new Set(vms.map(vm => vm.clusterName))];
        clusterFilter.innerHTML = '<option value="">All Clusters</option>';
        clusters.forEach(cluster => {
            clusterFilter.innerHTML += `<option value="${esc(cluster)}">${esc(cluster)}</option>`;
        });
    }
    
    if (vms.length === 0) {
        container.innerHTML = '<p>No virtual machines found</p>';
        return;
    }
    
    renderVMTable(vms);
}

// Render VM table
function renderVMTable(vms) {
    const container = document.getElementById('vmsList');
    if (!container) return;
    
    let html = '<table id="vmsTable" class="data-table"><thead><tr>';
    html += '<th>Name</th><th>Cluster</th><th>Resource Group</th><th>IP Address</th><th>Logical Network</th><th>Power State</th>';
    html += '<th>OS Type</th><th>CPUs</th><th>Memory (MB)</th><th>Status</th></tr></thead><tbody>';
    
    vms.forEach(vm => {
        html += '<tr>';
        html += `<td><strong>${esc(vm.name)}</strong></td>`;
        html += `<td>${esc(vm.clusterName || 'N/A')}</td>`;
        html += `<td>${esc(vm.resourceGroup || 'N/A')}</td>`;
        html += `<td>${esc(vm.ipAddress || 'N/A')}</td>`;
        html += `<td>${esc(vm.logicalNetwork || 'N/A')}</td>`;
        html += `<td><span class="badge badge-${getPowerStateColor(vm.powerState)}">${esc(vm.powerState)}</span></td>`;
        html += `<td>${esc(vm.osType)}</td>`;
        html += `<td>${esc(vm.cpuCount)}</td>`;
        html += `<td>${esc(vm.memoryMB)}</td>`;
        html += `<td><span class="badge badge-${getStatusColor(vm.provisioningState)}">${esc(vm.provisioningState)}</span></td>`;
        html += '</tr>';
    });
    
    html += '</tbody></table>';
    container.innerHTML = html;
}

// Filter VMs by cluster
function filterVMsByCluster() {
    const clusterFilter = document.getElementById('clusterFilter');
    const selectedCluster = clusterFilter.value;
    
    let vms = inventoryData.virtualMachines || [];
    
    if (selectedCluster) {
        vms = vms.filter(vm => vm.clusterName === selectedCluster);
    }
    
    renderVMTable(vms);
}

// Filter table
function filterTable(searchId, tableId) {
    const input = document.getElementById(searchId);
    const filter = input.value.toUpperCase();
    const table = document.getElementById(tableId);
    
    if (!table) return;
    
    const tr = table.getElementsByTagName('tr');
    
    for (let i = 1; i < tr.length; i++) {
        const row = tr[i];
        let found = false;
        const td = row.getElementsByTagName('td');
        
        for (let j = 0; j < td.length; j++) {
            const cell = td[j];
            if (cell) {
                const txtValue = cell.textContent || cell.innerText;
                if (txtValue.toUpperCase().indexOf(filter) > -1) {
                    found = true;
                    break;
                }
            }
        }
        
        row.style.display = found ? '' : 'none';
    }
}

// Get status color
function getStatusColor(status) {
    if (!status) return 'secondary';
    
    const statusLower = status.toLowerCase();
    if (statusLower.includes('success') || statusLower.includes('connected') || 
        statusLower.includes('available') || statusLower.includes('running')) {
        return 'success';
    } else if (statusLower.includes('warn') || statusLower.includes('updating')) {
        return 'warning';
    } else if (statusLower.includes('fail') || statusLower.includes('error') || 
               statusLower.includes('disconnect') || statusLower.includes('unavailable')) {
        return 'danger';
    }
    return 'secondary';
}

// Get power state color
function getPowerStateColor(state) {
    if (!state) return 'secondary';
    
    const stateLower = state.toLowerCase();
    if (stateLower.includes('running') || stateLower.includes('start')) {
        return 'success';
    } else if (stateLower.includes('stop') || stateLower.includes('deallocat')) {
        return 'danger';
    }
    return 'secondary';
}

// Get update status color
function getUpdateStatusColor(status) {
    if (!status || status === 'Unknown' || status === 'Not Available') return 'secondary';
    
    const statusLower = status.toLowerCase();
    if (statusLower.includes('uptodate') || statusLower.includes('up-to-date') || 
        statusLower.includes('current') || statusLower.includes('success')) {
        return 'success';
    } else if (statusLower.includes('available') || statusLower.includes('pending') || 
               statusLower.includes('updating')) {
        return 'warning';
    } else if (statusLower.includes('fail') || statusLower.includes('error')) {
        return 'danger';
    }
    return 'secondary';
}

// Format date
function formatDate(dateString) {
    if (!dateString || dateString === 'N/A' || dateString === 'Unknown') return 'N/A';
    
    try {
        const date = new Date(dateString);
        return date.toLocaleString();
    } catch {
        return dateString;
    }
}

// Show section
function showSection(sectionId) {
    // Hide all sections
    document.querySelectorAll('.content-section').forEach(section => {
        section.classList.remove('active');
    });
    
    // Show selected section
    const section = document.getElementById(sectionId);
    if (section) {
        section.classList.add('active');
    }
    
    // Update nav links
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
    });
    
    const activeLink = document.querySelector(`[data-section="${sectionId}"]`);
    if (activeLink) {
        activeLink.classList.add('active');
    }
}

// Export to PDF
async function exportToPDF() {
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('p', 'mm', 'a4');
        
        let yPos = 20;
        const pageWidth = doc.internal.pageSize.width;
        const pageHeight = doc.internal.pageSize.height;
        const margin = 20;
        const contentWidth = pageWidth - margin * 2;

        const brandColors = {
            navy: [14, 42, 71],
            navyMedium: [32, 68, 111],
            azure: [31, 143, 255],
            azureDark: [11, 95, 216],
            paperTint: [246, 248, 251],
            divider: [228, 234, 241],
            muted: [91, 114, 144]
        };
        const brandBlue = brandColors.azure;
        const darkGray = brandColors.navyMedium;
        const lightGray = brandColors.paperTint;
        const white = [255, 255, 255];

        doc.setProperties({
            title: 'Azure Local Inventory Report',
            subject: 'Azure Local inventory and Well-Architected assessment',
            author: 'GetToTheCloud',
            creator: 'Azure Local Documenter'
        });

        const tableTheme = {
            styles: {
                font: 'helvetica',
                textColor: brandColors.navy,
                lineColor: brandColors.divider,
                lineWidth: 0.1,
                fontSize: 8,
                cellPadding: 2.4,
                overflow: 'linebreak'
            },
            headStyles: {
                fillColor: brandColors.navy,
                textColor: white,
                fontStyle: 'bold'
            },
            alternateRowStyles: { fillColor: brandColors.paperTint },
            margin: { left: margin, right: margin }
        };

        async function loadReportLogo() {
            try {
                const response = await fetch('gettothecloud-logo.webp', { cache: 'force-cache' });
                if (!response.ok) return null;
                const logoBlob = await response.blob();
                const objectUrl = URL.createObjectURL(logoBlob);
                try {
                    const logoImage = await new Promise((resolve, reject) => {
                        const image = new Image();
                        image.onload = () => resolve(image);
                        image.onerror = reject;
                        image.src = objectUrl;
                    });
                    const canvas = document.createElement('canvas');
                    canvas.width = logoImage.naturalWidth;
                    canvas.height = logoImage.naturalHeight;
                    canvas.getContext('2d').drawImage(logoImage, 0, 0);
                    return canvas.toDataURL('image/png');
                } finally {
                    URL.revokeObjectURL(objectUrl);
                }
            } catch (error) {
                console.warn('Report logo could not be loaded:', error);
                return null;
            }
        }

        const logoDataUrl = await loadReportLogo();

        // Helper: add page footer with page numbers
        function addPageFooter() {
            const totalPages = doc.internal.getNumberOfPages();
            for (let i = 1; i <= totalPages; i++) {
                doc.setPage(i);
                doc.setFontSize(7);
                doc.setTextColor(...brandColors.muted);
                doc.text(`Page ${i} of ${totalPages}`, pageWidth - margin, pageHeight - 10, { align: 'right' });
                doc.setDrawColor(...brandColors.azure);
                doc.setLineWidth(0.5);
                doc.line(margin, pageHeight - 14, pageWidth - margin, pageHeight - 14);
            }
            doc.setTextColor(0, 0, 0);
        }

        // Helper: section header with colored bar
        function addSectionHeader(title) {
            checkPageBreak(30);
            doc.setFillColor(...brandBlue);
            doc.rect(margin, yPos - 5, contentWidth, 9, 'F');
            doc.setFontSize(13);
            doc.setTextColor(...white);
            doc.text(title, margin + 3, yPos + 1);
            doc.setTextColor(0, 0, 0);
            yPos += 10;
        }

        // Helper: check page break
        function checkPageBreak(requiredSpace = 20) {
            if (yPos + requiredSpace > pageHeight - margin - 15) {
                doc.addPage();
                yPos = margin;
                return true;
            }
            return false;
        }

        // ===== COVER PAGE =====
        doc.setFillColor(...brandColors.paperTint);
        doc.rect(0, 0, pageWidth, pageHeight, 'F');
        doc.setFillColor(...brandColors.navy);
        doc.rect(0, 0, pageWidth, 4, 'F');
        doc.setFillColor(...brandColors.azure);
        doc.rect(0, 4, pageWidth, 1.5, 'F');

        if (logoDataUrl) {
            doc.addImage(logoDataUrl, 'PNG', margin, 16, 100, 20.5);
        }

        yPos = 70;
        doc.setFontSize(24);
        doc.setFont(undefined, 'bold');
        doc.setTextColor(...brandColors.navy);
        doc.text('Azure Local', margin, yPos);
        yPos += 10;
        doc.setTextColor(...brandColors.azureDark);
        doc.text('Infrastructure Inventory Report', margin, yPos);
        yPos += 15;

        const summary = inventoryData.summary || {};
        const costAnalysisData = inventoryData.costAnalysis || {};
        const reportDate = new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });

        doc.setFontSize(11);
        doc.setTextColor(...darkGray);
        doc.text(`Report Date:`, margin, yPos); doc.text(reportDate, margin + 50, yPos); yPos += 7;
        doc.text(`Subscription:`, margin, yPos); doc.text(inventoryData.subscription || 'N/A', margin + 50, yPos); yPos += 7;
        doc.text(`Tenant ID:`, margin, yPos); doc.text(inventoryData.tenantId || 'N/A', margin + 50, yPos); yPos += 15;

        // Executive summary box
        doc.setFillColor(...lightGray);
        doc.roundedRect(margin, yPos - 3, contentWidth, 55, 3, 3, 'F');
        doc.setFontSize(13);
        doc.setTextColor(...brandBlue);
        doc.text('Executive Summary', margin + 5, yPos + 5);
        doc.setFontSize(10);
        doc.setTextColor(...darkGray);
        yPos += 14;
        const execLines = [
            `Infrastructure: ${summary.totalClusters || 0} cluster(s), ${summary.totalNodes || 0} node(s), ${costAnalysisData.totalCores || 0} physical cores`,
            `Workloads: ${summary.totalVirtualMachines || 0} virtual machine(s) across ${summary.totalLogicalNetworks || 0} logical network(s)`,
            `Storage & Services: ${summary.totalStoragePaths || 0} storage path(s), ${summary.totalArcResourceBridges || 0} Arc Resource Bridge(s)`,
            `Licensing: ${summary.totalLicensedMachines || 0} licensed machine(s), ${costAnalysisData.nodesWithHybridBenefit || 0} node(s) with Azure Hybrid Benefit`,
            `Estimated Monthly Cost: $${costAnalysisData.estimatedMonthlyCost?.toFixed(2) || '0.00'}  |  Potential Savings: $${costAnalysisData.potentialMonthlySavings?.toFixed(2) || '0.00'}/month`
        ];
        execLines.forEach(line => { doc.text(line, margin + 5, yPos); yPos += 6; });
        yPos += 10;

        // Resource count cards (two-column layout)
        doc.setFontSize(13);
        doc.setTextColor(...brandBlue);
        doc.text('Resource Inventory', margin + 5, yPos + 3);
        yPos += 10;
        const resourceItems = [
            ['Clusters', summary.totalClusters || 0],
            ['Nodes', summary.totalNodes || 0],
            ['Virtual Machines', summary.totalVirtualMachines || 0],
            ['Logical Networks', summary.totalLogicalNetworks || 0],
            ['Images', summary.totalImages || 0],
            ['Storage Paths', summary.totalStoragePaths || 0],
            ['Custom Locations', summary.totalCustomLocations || 0],
            ['Arc Resource Bridges', summary.totalArcResourceBridges || 0],
            ['Arc Gateways', summary.totalArcGateways || 0],
            ['Licensed Machines', summary.totalLicensedMachines || 0]
        ];
        doc.setFontSize(9);
        doc.setTextColor(...darkGray);
        const colWidth = contentWidth / 2;
        resourceItems.forEach((item, i) => {
            const col = i % 2;
            const x = margin + col * colWidth + 5;
            if (col === 0 && i > 0) yPos += 6;
            doc.text(`${item[0]}:`, x, yPos);
            doc.setFont(undefined, 'bold');
            doc.text(`${item[1]}`, x + 55, yPos);
            doc.setFont(undefined, 'normal');
        });
        yPos += 15;
        doc.setTextColor(0, 0, 0);

        // ===== START DETAIL PAGES =====
        doc.addPage();
        yPos = margin;
        
        // WAF Assessment (moved to beginning)
        if (wafConfig) {
            doc.setFontSize(16);
            doc.text('Well-Architected Framework Assessment', margin, yPos);
            yPos += 8;
            
            // Calculate WAF data
            const dataPoints = calculateWAFDataPoints(
                inventoryData.clusters || [],
                inventoryData.nodes || [],
                inventoryData.costAnalysis || {},
                inventoryData.summary || {}
            );
            
            // Evaluate all checks
            const wafResults = {};
            let totalWeight = 0;
            let achievedWeight = 0;
            
            Object.keys(wafConfig.pillars).forEach(pillarKey => {
                const pillar = wafConfig.pillars[pillarKey];
                wafResults[pillarKey] = {
                    name: pillar.name,
                    checks: []
                };
                
                pillar.checks.forEach(check => {
                    const result = evaluateWAFCheck(check, dataPoints);
                    wafResults[pillarKey].checks.push(result);
                    
                    totalWeight += check.weight;
                    if (result.pass) {
                        achievedWeight += check.weight;
                    } else if (result.warning) {
                        achievedWeight += check.weight * 0.5;
                    }
                });
            });
            
            const wafScore = totalWeight > 0 ? Math.round((achievedWeight / totalWeight) * 100) : 0;
            
            // Overall score
            doc.setFontSize(12);
            doc.text(`Overall WAF Score: ${wafScore}%`, margin, yPos);
            yPos += 10;
            
            // Add pillars
            const pillarOrder = Object.keys(wafConfig.pillars).sort((a, b) => 
                wafConfig.pillars[a].order - wafConfig.pillars[b].order
            );
            
            pillarOrder.forEach(pillarKey => {
                const pillar = wafResults[pillarKey];
                
                checkPageBreak(30);
                doc.setFontSize(11);
                doc.setFont(undefined, 'bold');
                doc.text(pillar.name, margin, yPos);
                doc.setFont(undefined, 'normal');
                yPos += 6;
                
                doc.setFontSize(9);
                pillar.checks.forEach(check => {
                    checkPageBreak(10);
                    // Use simple text icons instead of emoji to avoid encoding issues
                    const icon = check.pass ? 'PASS' : (check.warning ? 'WARN' : 'FAIL');
                    const statusText = `[${icon}] ${check.name}`;
                    const color = check.pass ? [0, 128, 0] : (check.warning ? [255, 140, 0] : [255, 0, 0]);
                    
                    doc.setTextColor(...color);
                    doc.text(statusText, margin + 2, yPos);
                    doc.setTextColor(0, 0, 0);
                    yPos += 5;
                    
                    // Add message as smaller text (strip any HTML entities or special chars)
                    doc.setFontSize(8);
                    const cleanMessage = check.message
                        .replace(/[✓✗⚠️✅❌]/g, '')
                        .replace(/&[a-z]+;/gi, '')
                        .trim();
                    const messageLines = doc.splitTextToSize(cleanMessage, 170);
                    messageLines.forEach(line => {
                        checkPageBreak(5);
                        doc.text(line, margin + 5, yPos);
                        yPos += 4;
                    });
                    doc.setFontSize(9);
                    yPos += 2;
                });
                
                yPos += 5;
            });
            
            yPos += 10;
        }
        
        // Clusters
        addSectionHeader('Clusters');
        const clusters = inventoryData.clusters || [];
        if (clusters.length > 0) {
            doc.autoTable({
                ...tableTheme,
                startY: yPos,
                head: [['Name', 'Resource Group', 'Location', 'Status', 'Software Version', 'Nodes', 'VMs', 'Hybrid Benefit']],
                body: clusters.map(c => [
                    c.name,
                    c.resourceGroup,
                    c.location,
                    c.status,
                    c.softwareVersion || 'N/A',
                    c.nodeCount.toString(),
                    c.vmCount.toString(),
                    c.azureHybridBenefitEnabled ? 'Enabled' : 'Not Enabled'
                ]),
            });
            yPos = doc.lastAutoTable.finalY + 10;
        } else {
            doc.setFontSize(9);
            doc.text('No clusters found', margin, yPos);
            yPos += 10;
        }
        
        // Nodes
        addSectionHeader('Nodes — Hardware & Status');
        const nodes = inventoryData.nodes || [];
        if (nodes.length > 0) {
            doc.autoTable({
                ...tableTheme,
                startY: yPos,
                head: [['Name', 'Cluster', 'Status', 'Manufacturer', 'Model', 'Serial Number', 'Cores', 'Memory (GB)']],
                body: nodes.map(n => [
                    n.name,
                    n.clusterName,
                    n.status,
                    n.manufacturer || 'Unknown',
                    n.model || 'Unknown',
                    n.serialNumber || 'Unknown',
                    n.physicalCores || 'Unknown',
                    n.memoryGB || 'Unknown'
                ]),
            });
            yPos = doc.lastAutoTable.finalY + 8;
            
            addSectionHeader('Nodes — Software & Workload');
            doc.autoTable({
                ...tableTheme,
                startY: yPos,
                head: [['Name', 'Solution Version', 'OS Version', 'VMs', 'K8s Clusters', 'Agent Version', 'Hybrid Benefit']],
                body: nodes.map(n => [
                    n.name,
                    n.solutionVersion || 'Unknown',
                    n.osVersion || 'Unknown',
                    n.vmCount || '0',
                    n.k8sClusterCount || '0',
                    n.agentVersion,
                    n.azureHybridBenefitEnabled ? 'Enabled' : 'Not Enabled'
                ]),
            });
            yPos = doc.lastAutoTable.finalY + 10;
        } else {
            doc.setFontSize(9);
            doc.text('No nodes found', margin, yPos);
            yPos += 10;
        }
        
        // Logical Networks
        addSectionHeader('Logical Networks');
        const networks = inventoryData.logicalNetworks || [];
        if (networks.length > 0) {
            doc.autoTable({
                ...tableTheme,
                startY: yPos,
                head: [['Name', 'Cluster', 'VM Switch', 'Subnets', 'Address Prefix', 'Status']],
                body: networks.map(n => [
                    n.name,
                    n.clusterName,
                    n.vmSwitchName,
                    `${n.subnets.length} subnet(s)`,
                    n.subnets.map(s => s.addressPrefix).filter(p => p && p !== 'N/A').join(', ') || 'N/A',
                    n.provisioningState
                ]),
            });
            yPos = doc.lastAutoTable.finalY + 10;
        }
        
        // Storage Paths
        addSectionHeader('Storage Paths');
        const paths = inventoryData.storagePaths || [];
        if (paths.length > 0) {
            doc.autoTable({
                ...tableTheme,
                startY: yPos,
                head: [['Name', 'Cluster', 'Path', 'Status']],
                body: paths.map(p => [p.name, p.clusterName, p.path, p.provisioningState || 'N/A']),
            });
            yPos = doc.lastAutoTable.finalY + 10;
        }
        
        // Custom Locations
        addSectionHeader('Custom Locations');
        const customLocs = inventoryData.customLocations || [];
        if (customLocs.length > 0) {
            doc.autoTable({
                ...tableTheme,
                startY: yPos,
                head: [['Name', 'Cluster', 'Namespace', 'Status']],
                body: customLocs.map(l => [l.name, l.clusterName, l.namespace, l.provisioningState]),
            });
            yPos = doc.lastAutoTable.finalY + 10;
        }
        
        // Arc Resource Bridges
        addSectionHeader('Arc Resource Bridges');
        const arcBridges = inventoryData.arcResourceBridges || [];
        if (arcBridges.length > 0) {
            doc.autoTable({
                ...tableTheme,
                startY: yPos,
                head: [['Name', 'Cluster', 'Status', 'Version', 'Provider', 'Distro']],
                body: arcBridges.map(b => [
                    b.name,
                    b.clusterName,
                    b.status,
                    b.version || 'N/A',
                    b.infrastructureConfig || 'N/A',
                    b.distro || 'N/A'
                ]),
            });
            yPos = doc.lastAutoTable.finalY + 10;
        }
        
        // Licenses
        addSectionHeader('Licensed Machines');
        const licenses = inventoryData.licenses || [];
        if (licenses.length > 0) {
            doc.autoTable({
                ...tableTheme,
                startY: yPos,
                head: [['Machine Name', 'Cluster', 'License Type(s)', 'License State', 'Azure Hybrid Benefit']],
                body: licenses.map(l => [
                    l.machineName,
                    l.clusterName,
                    l.licenses.map(lic => lic.type).join(', '),
                    [...new Set(l.licenses.map(lic => lic.state))].join(', '),
                    l.azureHybridBenefitEnabled ? 'Enabled' : 'Not Enabled'
                ]),
            });
            yPos = doc.lastAutoTable.finalY + 10;
        }
        
        // Cost Analysis
        addSectionHeader('Cost Analysis & Azure Hybrid Benefit');
        const costAnalysis = inventoryData.costAnalysis || {};
        if (costAnalysis.totalCores) {
            // Pricing reference
            doc.setFontSize(9);
            doc.setTextColor(100, 100, 100);
            doc.text(`Pricing: $${costAnalysis.corePrice}/core/month (standard)  |  $${costAnalysis.corePriceWithHybridBenefit}/core/month (with Azure Hybrid Benefit)`, margin, yPos);
            doc.setTextColor(0, 0, 0);
            yPos += 8;
            
            // Cost summary as a table
            const costRows = [
                ['Total Physical Cores', costAnalysis.totalCores.toString()],
                ['Nodes with Azure Hybrid Benefit', costAnalysis.nodesWithHybridBenefit.toString()],
                ['Nodes without Azure Hybrid Benefit', costAnalysis.nodesWithoutHybridBenefit.toString()],
                ['Current Monthly Cost', `$${costAnalysis.estimatedMonthlyCost.toFixed(2)}`],
                ['Current Yearly Cost', `$${costAnalysis.estimatedYearlyCost.toFixed(2)}`]
            ];
            if (costAnalysis.potentialMonthlySavings > 0) {
                costRows.push(['Potential Monthly Savings', `$${costAnalysis.potentialMonthlySavings.toFixed(2)}`]);
                costRows.push(['Potential Yearly Savings', `$${costAnalysis.potentialYearlySavings.toFixed(2)}`]);
            }
            doc.autoTable({
                ...tableTheme,
                startY: yPos,
                head: [['Metric', 'Value']],
                body: costRows,
                columnStyles: { 0: { fontStyle: 'bold' } }
            });
            yPos = doc.lastAutoTable.finalY + 10;
        }
        
        // Virtual Machines
        addSectionHeader('Virtual Machines');
        const vms = inventoryData.virtualMachines || [];
        if (vms.length > 0) {
            doc.autoTable({
                ...tableTheme,
                startY: yPos,
                head: [['Name', 'Cluster', 'Resource Group', 'IP Address', 'Logical Network', 'OS', 'CPUs', 'Memory (MB)', 'Power State']],
                body: vms.map(v => [
                    v.name,
                    v.clusterName || 'N/A',
                    v.resourceGroup || 'N/A',
                    v.ipAddress || 'N/A',
                    v.logicalNetwork || 'N/A',
                    v.osName || v.osType || 'Unknown',
                    v.cpuCount.toString(),
                    v.memoryMB.toString(),
                    v.powerState
                ]),
            });
            yPos = doc.lastAutoTable.finalY + 10;
        }

        // Add page footers on all pages
        addPageFooter();
        
        // Save PDF with date in filename
        const now = new Date();
        const dateStr = now.toISOString().split('T')[0];
        const filename = `azure-local-inventory-${dateStr}.pdf`;
        doc.save(filename);
        
        console.log('✅ PDF exported successfully');
    } catch (error) {
        console.error('❌ Error exporting PDF:', error);
        alert('Failed to export PDF. See console for details.');
    }
}
// Filter nodes by cluster
function filterNodesByCluster(clusterName) {
    showSection('nodes');
    
    // Wait for section to be visible
    setTimeout(() => {
        const searchInput = document.getElementById('nodeSearch');
        if (searchInput) {
            searchInput.value = clusterName;
            filterTable('nodeSearch', 'nodesTable');
        }
    }, 100);
}

// Render WAF Assessment
function renderWAF() {
    if (!wafConfig) {
        console.error('❌ WAF configuration not loaded');
        document.getElementById('wafScore').textContent = 'N/A';
        document.getElementById('wafSummary').innerHTML = '<p style="color: var(--warning-color);">⚠️ WAF configuration not available. Please reload the page.</p>';
        return;
    }

    const clusters = inventoryData.clusters || [];
    const nodes = inventoryData.nodes || [];
    const costAnalysis = inventoryData.costAnalysis || {};
    const summary = inventoryData.summary || {};
    
    if (clusters.length === 0) {
        document.getElementById('wafScore').textContent = 'N/A';
        document.getElementById('wafSummary').innerHTML = '<p>No data available for assessment</p>';
        return;
    }
    
    // Calculate data points for WAF checks
    const dataPoints = calculateWAFDataPoints(clusters, nodes, costAnalysis, summary);
    
    // Evaluate all checks across all pillars
    const wafChecks = {};
    let totalWeight = 0;
    let achievedWeight = 0;
    
    Object.keys(wafConfig.pillars).forEach(pillarKey => {
        const pillar = wafConfig.pillars[pillarKey];
        wafChecks[pillarKey] = [];
        
        pillar.checks.forEach(check => {
            const result = evaluateWAFCheck(check, dataPoints);
            wafChecks[pillarKey].push(result);
            
            totalWeight += check.weight;
            if (result.pass) {
                achievedWeight += check.weight;
            } else if (result.warning) {
                achievedWeight += check.weight * 0.5;
            }
        });
    });
    
    // Calculate overall score
    const score = totalWeight > 0 ? Math.round((achievedWeight / totalWeight) * 100) : 0;
    
    // Count results
    let passedChecks = 0;
    let warningChecks = 0;
    let failedChecks = 0;
    
    Object.values(wafChecks).forEach(checks => {
        checks.forEach(check => {
            if (check.pass) passedChecks++;
            else if (check.warning) warningChecks++;
            else failedChecks++;
        });
    });
    
    // Get score message
    const thresholds = wafConfig.scoring.thresholds;
    const messages = wafConfig.scoring.messages;
    let scoreMessage = messages.poor;
    if (score >= thresholds.excellent) {
        scoreMessage = messages.excellent;
    } else if (score >= thresholds.good) {
        scoreMessage = messages.good;
    } else if (score >= thresholds.needsImprovement) {
        scoreMessage = messages.needsImprovement;
    }
    
    // Update UI
    document.getElementById('wafScore').textContent = score;
    document.getElementById('wafSummary').innerHTML = `
        <p><strong>${passedChecks}</strong> checks passed, <strong>${warningChecks}</strong> warnings, <strong>${failedChecks}</strong> failed</p>
        <p>Your Azure Local deployment scores <strong>${score}%</strong> on the Well-Architected Framework assessment.</p>
        <p>${esc(scoreMessage)}</p>
    `;
    
    // Render each pillar
    const pillarOrder = Object.keys(wafConfig.pillars).sort((a, b) => 
        wafConfig.pillars[a].order - wafConfig.pillars[b].order
    );
    
    pillarOrder.forEach(pillarKey => {
        const elementMap = {
            'reliability': 'wafReliability',
            'security': 'wafSecurity',
            'costOptimization': 'wafCost',
            'performance': 'wafPerformance',
            'operationalExcellence': 'wafOperational'
        };
        
        const elementId = elementMap[pillarKey];
        if (elementId) {
            renderWAFCategory(elementId, wafChecks[pillarKey]);
        }
    });
}

function calculateWAFDataPoints(clusters, nodes, costAnalysis, summary) {
    // Calculate multi-node clusters
    const multiNodeClusters = clusters.filter(c => c.nodeCount >= 2).length;
    const totalClusters = clusters.length;
    
    // Calculate connected nodes
    const connectedNodes = nodes.filter(n => n.status === 'Connected').length;
    const totalNodes = nodes.length;
    
    // Calculate up-to-date nodes
    const upToDateNodes = nodes.filter(n => n.updateStatus !== 'UpdateAvailable' && n.updateStatus !== 'Unknown').length;
    
    // Calculate nodes with agents
    const nodesWithAgents = nodes.filter(n => n.agentVersion !== 'Not Available').length;
    const nodesWithMonitoring = nodesWithAgents; // Same as monitoring
    
    // Calculate nodes with extensions (check if extensions property exists and > 0)
    const nodesWithExtensions = nodes.filter(n => n.extensions && n.extensions.length > 0).length;
    
    // Calculate average cores per node
    const avgCoresPerNode = totalNodes > 0 ? 
        nodes.reduce((sum, n) => sum + (parseInt(n.physicalCores) || 0), 0) / totalNodes : 0;
    
    // Calculate memory sufficiency
    const nodesWithSufficientMemory = nodes.filter(n => {
        const mem = parseFloat(n.memoryGB);
        return !isNaN(mem) && mem >= 64;
    }).length;
    
    // Calculate CPU cores sufficiency
    const nodesWithMultipleCores = nodes.filter(n => {
        const cores = parseInt(n.physicalCores);
        return !isNaN(cores) && cores >= 16;
    }).length;
    
    // VM distribution
    const vmDistribution = calculateVMDistribution(nodes);
    
    // Clusters with version
    const clustersWithVersion = clusters.filter(c => c.softwareVersion !== 'N/A' && c.softwareVersion !== 'Unknown').length;
    
    // Cost optimization
    const nodesWithHybridBenefit = costAnalysis.nodesWithHybridBenefit || 0;
    const potentialMonthlySavings = costAnalysis.potentialMonthlySavings || 0;
    
    return {
        totalClusters,
        multiNodeClusters,
        totalNodes,
        connectedNodes,
        upToDateNodes,
        nodesWithAgents,
        nodesWithMonitoring,
        nodesWithExtensions,
        avgCoresPerNode: avgCoresPerNode.toFixed(0),
        nodesWithSufficientMemory,
        nodesWithMultipleCores,
        vmDistributionBalanced: vmDistribution.balanced,
        clustersWithVersion,
        nodesWithHybridBenefit,
        potentialMonthlySavings: potentialMonthlySavings.toFixed(2),
        hasStoragePaths: (summary.totalStoragePaths || 0) > 0,
        totalStoragePaths: summary.totalStoragePaths || 0,
        hasArcBridges: (summary.totalArcResourceBridges || 0) > 0,
        totalArcBridges: summary.totalArcResourceBridges || 0,
        hasLogicalNetworks: (summary.totalLogicalNetworks || 0) > 0,
        totalLogicalNetworks: summary.totalLogicalNetworks || 0,
        hasCustomLocations: (summary.totalCustomLocations || 0) > 0,
        totalCustomLocations: summary.totalCustomLocations || 0
    };
}

function evaluateWAFCheck(check, dataPoints) {
    // Evaluate the main condition
    let pass = false;
    let warning = false;
    
    try {
        // Simple condition evaluation
        const condition = check.condition;
        pass = evaluateCondition(condition, dataPoints);
        
        // Check warning condition if main condition fails
        if (!pass && check.warningCondition) {
            warning = evaluateCondition(check.warningCondition, dataPoints);
        }
    } catch (error) {
        console.error(`Error evaluating check ${check.id}:`, error);
    }
    
    // Get the appropriate message
    let message = check.failMessage || '';
    if (pass) {
        message = check.passMessage || '';
    } else if (warning) {
        message = check.warningMessage || check.failMessage || '';
    }
    
    // Replace placeholders in message
    message = replacePlaceholders(message, dataPoints);
    
    return {
        id: check.id,
        name: check.name,
        desc: check.description,
        pass,
        warning,
        message,
        recommendation: check.recommendation || ''
    };
}

function evaluateCondition(condition, dataPoints) {
    try {
        // Replace data point references in the condition
        let evalCondition = condition;
        Object.keys(dataPoints).forEach(key => {
            const regex = new RegExp(`\\b${key}\\b`, 'g');
            evalCondition = evalCondition.replace(regex, dataPoints[key]);
        });
        
        // Safely evaluate the condition
        // Note: Using Function constructor for evaluation (be careful with untrusted input)
        return new Function('return ' + evalCondition)();
    } catch (error) {
        console.error('Error evaluating condition:', condition, error);
        return false;
    }
}

function replacePlaceholders(message, dataPoints) {
    let result = message;
    Object.keys(dataPoints).forEach(key => {
        const placeholder = `{${key}}`;
        result = result.replace(new RegExp(placeholder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), dataPoints[key]);
    });
    return result;
}

function renderWAFCategory(elementId, checks) {
    const container = document.getElementById(elementId);
    if (!container) return;
    
    let html = '';
    checks.forEach(check => {
        const status = check.pass ? 'pass' : (check.warning ? 'warning' : 'fail');
        const icon = check.pass ? '✅' : (check.warning ? '⚠️' : '❌');
        
        html += `
            <div class="waf-check-item waf-check-${status}">
                <div class="waf-check-icon">${icon}</div>
                <div class="waf-check-content">
                    <div class="waf-check-title">${esc(check.name)}</div>
                    <div class="waf-check-desc">${esc(check.message)}</div>
                    ${!check.pass && check.recommendation ? `<div class="waf-check-recommendation" style="font-size: 0.85em; color: var(--text-secondary); margin-top: 5px; font-style: italic;">💡 ${esc(check.recommendation)}</div>` : ''}
                </div>
            </div>
        `;
    });
    
    container.innerHTML = html || '<p>No checks available</p>';
}

function calculateVMDistribution(nodes) {
    if (nodes.length === 0) return { balanced: true };
    
    const vmCounts = nodes.map(n => n.vmCount || 0);
    const maxVMs = Math.max(...vmCounts);
    const minVMs = Math.min(...vmCounts);
    const avgVMs = vmCounts.reduce((a, b) => a + b, 0) / vmCounts.length;
    
    // Consider balanced if difference between max and avg is less than 50%
    const balanced = maxVMs === 0 || (maxVMs - minVMs) <= avgVMs * 0.5;
    
    return { balanced };
}