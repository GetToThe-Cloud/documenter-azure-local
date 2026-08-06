#Requires -Version 7.0

<#
.SYNOPSIS
    Azure Local Inventory Dashboard module.
.DESCRIPTION
    Loads the private script components and exports the two public commands:
      - Get-AzureLocalInventory  : Collect inventory data from Azure Local environments.
      - Start-AzureLocalServer   : Launch the local web dashboard for the collected data.
#>

# Dot-source private script components so their functions are available in this module scope.
. (Join-Path $PSScriptRoot 'Get-AzureLocalInventory.ps1')
. (Join-Path $PSScriptRoot 'Start-AzureLocalServer.ps1')

Export-ModuleMember -Function 'Get-AzureLocalInventory', 'Start-AzureLocalServer'
