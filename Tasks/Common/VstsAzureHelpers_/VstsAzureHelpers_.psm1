﻿# Private module-scope variables.
$script:azureModule = $null
$script:azureRMProfileModule = $null

# Override the DebugPreference.
if ($global:DebugPreference -eq 'Continue') {
    Write-Verbose '$OVERRIDING $global:DebugPreference from ''Continue'' to ''SilentlyContinue''.'
    $global:DebugPreference = 'SilentlyContinue'
}

# Import the loc strings.
Import-VstsLocStrings -LiteralPath $PSScriptRoot/module.json

Import-Module $PSScriptRoot/../TlsHelper_
Add-Tls12InSession

# Dot source the private functions.
. $PSScriptRoot/InitializeFunctions.ps1
. $PSScriptRoot/ImportFunctions.ps1

# This is the only public function.
function Initialize-Azure {
    [CmdletBinding()]
    param( [string] $azurePsVersion,
           [switch] $strict )
    Trace-VstsEnteringInvocation $MyInvocation
    try {
        # Get the inputs.
        $serviceNameInput = Get-VstsInput -Name ConnectedServiceNameSelector -Default 'ConnectedServiceName'
        $serviceName = Get-VstsInput -Name $serviceNameInput -Default (Get-VstsInput -Name DeploymentEnvironmentName)
        if (!$serviceName) {
            # Let the task SDK throw an error message if the input isn't defined.
            Get-VstsInput -Name $serviceNameInput -Require
        }

        $endpoint = Get-VstsEndpoint -Name $serviceName -Require
        $storageAccount = Get-VstsInput -Name StorageAccount

        # Determine which modules are preferred.
        $preferredModules = @( )
        if ($endpoint.Auth.Scheme -eq 'ServicePrincipal') {
            $preferredModules += 'AzureRM'
        } elseif ($endpoint.Auth.Scheme -eq 'UserNamePassword' -and $strict -eq $false) {
            $preferredModules += 'Azure'
            $preferredModules += 'AzureRM'
        } else {
            $preferredModules += 'Azure'
        }

        # Import/initialize the Azure module.
        Import-AzureModule -PreferredModule $preferredModules -azurePsVersion $azurePsVersion -strict:$strict
        Initialize-AzureSubscription -Endpoint $endpoint -StorageAccount $storageAccount
    } finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

# Export only the public function.
Export-ModuleMember -Function Initialize-Azure