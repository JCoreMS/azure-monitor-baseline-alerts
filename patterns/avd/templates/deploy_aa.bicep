targetScope = 'subscription'

@description('Location of needed scripts to deploy solution.')
param _ArtifactsLocation string = 'https://raw.githubusercontent.com/Azure/azure-monitor-baseline-alerts/main/patterns/alz/scripts/'
// https://raw.githubusercontent.com/Azure/avdaccelerator/main/workload/scripts/alerts/  OLD from AVD Accelerator Repo

@description('SaS token if needed for script location.')
@secure()
param _ArtifactsLocationSasToken string = ''

@description('Alert Name Prefix (Dash will be added after prefix for you.)')
param AlertNamePrefix string = 'AVD'

@description('Flag to determine if AVD VMs and AVD resources are all in the same Resource Group.')
param AllResourcesSameRG bool = true

@allowed([
  'd'
  'p'
  't'
])
@description('The environment is which these resources will be deployed, i.e. Test, Production, Development.')
param Environment string = 't'

@description('Array of objects with the Resource ID for colHostPoolName and colVMresGroup for each Host Pool.')
param HostPoolInfo array = []

@description('Azure Region for Resources.')
param Location string = deployment().location

@description('The Resource ID for the Log Analytics Workspace.')
param LogAnalyticsWorkspaceResourceId string

@description('Resource Group to deploy the Alerts Solution in.')
param ResourceGroupName string

//placeholder needed for template validation when VMs in separate RG selected - desktop reader deployment fails otherwise
@description('AVD Resource Group ID with ALL resources including VMs')
param AVDResourceGroupId string = '/subscriptions/<subscription ID>/resourceGroups/<Resource Group Name>' 

@description('The Resource IDs for the Azure Files Storage Accounts used for FSLogix profile storage.')
param StorageAccountResourceIds array = []

@description('ISO 8601 timestamp used for the deployment names and the Automation runbook schedule.')
param time string = utcNow()

param Tags object = {}

var AutomationAccountName = 'aa-avdmetrics-${Environment}-${Location}-${AlertNamePrefix}'
var CloudEnvironment = environment().name
var RunbookNameGetStorage = 'AvdStorageLogData'
var RunbookNameGetHostPool = 'AvdHostPoolLogData'
var RunbookScriptGetStorage = 'Get-StorAcctInfo.ps1${_ArtifactsLocationSasToken}'
var RunbookScriptGetHostPool = 'Get-HostPoolInfo.ps1${_ArtifactsLocationSasToken}'
var StorAcctRGsAll = [for item in StorageAccountResourceIds: split(item, '/')[4]]
var StorAcctRGs = union(StorAcctRGsAll, [])
// var UsrManagedIdentityName = 'id-ds-avdAlerts-Deployment'

var RoleAssignments = {
  DesktopVirtualizationRead: {
    Name: 'Desktop-Virtualization-Reader'
    GUID: '49a72310-ab8d-41df-bbb0-79b649203868'
  }
  StoreAcctContrib: {
    Name: 'Storage-Account-Contributor'
    GUID: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  }
  LogAnalyticsContributor: {
    Name: 'LogAnalytics-Contributor'
    GUID: '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
  }
}
// '49a72310-ab8d-41df-bbb0-79b649203868'  // Desktop Virtualization Reader
// '17d1049b-9a84-46fb-8f53-869881c3d3ab'  // Storage Account Contributor
// '92aaf0da-9dab-42b6-94a3-d43ce8d16293'  // Log Analtyics Contributor - allows writing to workspace for Host Pool and Storage Logic Apps


var varJobScheduleParamsHostPool = {
    CloudEnvironment: CloudEnvironment
    SubscriptionId: SubscriptionId
  }
// fixes issue with array not being in JSON format
var varStorAcctResIDsString = StorageAccountResourceIds
var varJobScheduleParamsAzFiles = {
    CloudEnvironment: CloudEnvironment
    StorageAccountResourceIDs: string(varStorAcctResIDsString)
}

var SubscriptionId = subscription().subscriptionId
var varScheduleName = 'AVD_Chk-'
var varTimeZone = varTimeZones[Location]
var varTimeZones = {
  australiacentral: 'AUS Eastern Standard Time'
  australiacentral2: 'AUS Eastern Standard Time'
  australiaeast: 'AUS Eastern Standard Time'
  australiasoutheast: 'AUS Eastern Standard Time'
  brazilsouth: 'E. South America Standard Time'
  brazilsoutheast: 'E. South America Standard Time'
  canadacentral: 'Eastern Standard Time'
  canadaeast: 'Eastern Standard Time'
  centralindia: 'India Standard Time'
  centralus: 'Central Standard Time'
  chinaeast: 'China Standard Time'
  chinaeast2: 'China Standard Time'
  chinanorth: 'China Standard Time'
  chinanorth2: 'China Standard Time'
  eastasia: 'China Standard Time'
  eastus: 'Eastern Standard Time'
  eastus2: 'Eastern Standard Time'
  francecentral: 'Central Europe Standard Time'
  francesouth: 'Central Europe Standard Time'
  germanynorth: 'Central Europe Standard Time'
  germanywestcentral: 'Central Europe Standard Time'
  japaneast: 'Tokyo Standard Time'
  japanwest: 'Tokyo Standard Time'
  jioindiacentral: 'India Standard Time'
  jioindiawest: 'India Standard Time'
  koreacentral: 'Korea Standard Time'
  koreasouth: 'Korea Standard Time'
  northcentralus: 'Central Standard Time'
  northeurope: 'GMT Standard Time'
  norwayeast: 'Central Europe Standard Time'
  norwaywest: 'Central Europe Standard Time'
  southafricanorth: 'South Africa Standard Time'
  southafricawest: 'South Africa Standard Time'
  southcentralus: 'Central Standard Time'
  southindia: 'India Standard Time'
  southeastasia: 'Singapore Standard Time'
  swedencentral: 'Central Europe Standard Time'
  switzerlandnorth: 'Central Europe Standard Time'
  switzerlandwest: 'Central Europe Standard Time'
  uaecentral: 'Arabian Standard Time'
  uaenorth: 'Arabian Standard Time'
  uksouth: 'GMT Standard Time'
  ukwest: 'GMT Standard Time'
  usdodcentral: 'Central Standard Time'
  usdodeast: 'Eastern Standard Time'
  usgovarizona: 'Mountain Standard Time'
  usgoviowa: 'Central Standard Time'
  usgovtexas: 'Central Standard Time'
  usgovvirginia: 'Eastern Standard Time'
  westcentralus: 'Mountain Standard Time'
  westeurope: 'Central Europe Standard Time'
  westindia: 'India Standard Time'
  westus: 'Pacific Standard Time'
  westus2: 'Pacific Standard Time'
  westus3: 'Mountain Standard Time'
}

// =========== //
// Deployments //
// =========== //

// Deploy new automation account
module automationAccount 'carml/1.3.0/Microsoft.Automation/automationAccounts/deploy.bicep' = {
  name: 'c_AutomtnAcct-${AutomationAccountName}'
  scope: resourceGroup(ResourceGroupName)
  params: {
    diagnosticLogCategoriesToEnable: [
      'JobLogs'
      'JobStreams'
    ]
    enableDefaultTelemetry: false
    diagnosticWorkspaceId: LogAnalyticsWorkspaceResourceId
    name: AutomationAccountName
    jobSchedules: !empty(StorageAccountResourceIds) ? [
      {
        parameters: varJobScheduleParamsHostPool
        runbookName: RunbookNameGetHostPool
        scheduleName: '${varScheduleName}HostPool-0'
      }
      {
        parameters: varJobScheduleParamsHostPool
        runbookName: RunbookNameGetHostPool
        scheduleName: '${varScheduleName}HostPool-1'
      }
      {
        parameters: varJobScheduleParamsHostPool
        runbookName: RunbookNameGetHostPool
        scheduleName: '${varScheduleName}HostPool-2'
      }
      {
        parameters: varJobScheduleParamsHostPool
        runbookName: RunbookNameGetHostPool
        scheduleName: '${varScheduleName}HostPool-3'
      }
      {
        parameters:  varJobScheduleParamsAzFiles
        runbookName: RunbookNameGetStorage
        scheduleName: '${varScheduleName}AzFilesStor-0'
      }
      {
        parameters: varJobScheduleParamsAzFiles
        runbookName: RunbookNameGetStorage
        scheduleName: '${varScheduleName}AzFilesStor-1'
      }
      {
        parameters: varJobScheduleParamsAzFiles
        runbookName: RunbookNameGetStorage
        scheduleName: '${varScheduleName}AzFilesStor-2'
      }
      {
        parameters: varJobScheduleParamsAzFiles
        runbookName: RunbookNameGetStorage
        scheduleName: '${varScheduleName}AzFilesStor-3'
      }
    ] :[
      {
        parameters: varJobScheduleParamsHostPool
        runbookName: RunbookNameGetHostPool
        scheduleName: '${varScheduleName}HostPool-0'
      }
      {
        parameters: varJobScheduleParamsHostPool
        runbookName: RunbookNameGetHostPool
        scheduleName: '${varScheduleName}HostPool-1'
      }
      {
        parameters: varJobScheduleParamsHostPool
        runbookName: RunbookNameGetHostPool
        scheduleName: '${varScheduleName}HostPool-2'
      }
      {
        parameters: varJobScheduleParamsHostPool
        runbookName: RunbookNameGetHostPool
        scheduleName: '${varScheduleName}HostPool-3'
      }
    ]
    location: Location
    runbooks: !empty(StorageAccountResourceIds) ? [
      {
        name: RunbookNameGetHostPool
        description: 'AVD Metrics Runbook for collecting related Host Pool statistics to store in Log Analytics for specified Alert Queries'
        type: 'PowerShell'
        uri: '${_ArtifactsLocation}${RunbookScriptGetHostPool}'
        version: '1.0.0.0'
      }
      {
        name: RunbookNameGetStorage
        description: 'AVD Metrics Runbook for collecting related Azure Files storage statistics to store in Log Analytics for specified Alert Queries'
        type: 'PowerShell'
        uri: '${_ArtifactsLocation}${RunbookScriptGetStorage}'
        version: '1.0.0.0'
      }
    ] : [
      {
        name: RunbookNameGetHostPool
        description: 'AVD Metrics Runbook for collecting related Host Pool statistics to store in Log Analytics for specified Alert Queries'
        type: 'PowerShell'
        uri: '${_ArtifactsLocation}${RunbookScriptGetHostPool}'
        version: '1.0.0.0'
      }
    ]
    schedules: !empty(StorageAccountResourceIds) ? [
      {
        name: '${varScheduleName}HostPool-0'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT15M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}HostPool-1'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT30M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}HostPool-2'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT45M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}HostPool-3'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT60M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}AzFilesStor-0'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT15M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}AzFilesStor-1'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT30M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}AzFilesStor-2'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT45M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}AzFilesStor-3'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT60M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
    ] :[
      {
        name: '${varScheduleName}HostPool-0'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT15M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}HostPool-1'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT30M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}HostPool-2'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT45M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
      {
        name: '${varScheduleName}HostPool-3'
        frequency: 'Hour'
        interval: 1
        startTime: dateTimeAdd(time, 'PT60M')
        TimeZone: varTimeZone
        advancedSchedule: {}
      }
    ]
    skuName: 'Free'
    tags: contains(Tags, 'Microsoft.Automation/automationAccounts') ? Tags['Microsoft.Automation/automationAccounts'] : {}
    systemAssignedIdentity: true
  }
}

module roleAssignment_AutoAcctDesktopRead 'carml/1.3.0/Microsoft.Authorization/roleAssignments/resourceGroup/deploy.bicep' = [for RG in HostPoolInfo: if(!AllResourcesSameRG) {
  scope: resourceGroup(split(RG.colVMResGroup, '/')[4])
  name: 'c_DsktpRead_${split(RG.colVMResGroup, '/')[4]}'
  params: {
    enableDefaultTelemetry: false
    principalId: automationAccount.outputs.systemAssignedPrincipalId
    roleDefinitionIdOrName: 'Desktop Virtualization Reader'
    principalType: 'ServicePrincipal'
    resourceGroupName: split(RG.colVMResGroup, '/')[4]
  }
  dependsOn: [
    automationAccount
  ]
}]

module roleAssignment_AutoAcctDesktopReadSameRG 'carml/1.3.0/Microsoft.Authorization/roleAssignments/resourceGroup/deploy.bicep' = if(AllResourcesSameRG) {
  scope: resourceGroup(split(AVDResourceGroupId, '/')[4])
  name: 'c_DsktpRead_${split(AVDResourceGroupId, '/')[4]}'
  params: {
    enableDefaultTelemetry: false
    principalId: automationAccount.outputs.systemAssignedPrincipalId
    roleDefinitionIdOrName: 'Desktop Virtualization Reader'
    principalType: 'ServicePrincipal'
    resourceGroupName: split(AVDResourceGroupId, '/')[4]
  }
  dependsOn: [
    automationAccount
  ]
}

module roleAssignment_LogAnalytics 'carml/1.3.0/Microsoft.Authorization/roleAssignments/resourceGroup/deploy.bicep' = {
  scope: resourceGroup(split(LogAnalyticsWorkspaceResourceId, '/')[2], split(LogAnalyticsWorkspaceResourceId, '/')[4])
  name: 'c_LogContrib_${split(LogAnalyticsWorkspaceResourceId, '/')[4]}'
  params: {
    enableDefaultTelemetry: false
    principalId: automationAccount.outputs.systemAssignedPrincipalId
    roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/${RoleAssignments.LogAnalyticsContributor.GUID}'
    principalType: 'ServicePrincipal'
    resourceGroupName: split(LogAnalyticsWorkspaceResourceId, '/')[4]
  }
  dependsOn: [
    automationAccount
  ]
}

module roleAssignment_Storage 'carml/1.3.0/Microsoft.Authorization/roleAssignments/resourceGroup/deploy.bicep' = [for StorAcctRG in StorAcctRGs: {
  scope: resourceGroup(StorAcctRG)
  name: 'c_StorAcctContrib_${StorAcctRG}'
  params: {
    enableDefaultTelemetry: false
    principalId: automationAccount.outputs.systemAssignedPrincipalId
    roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/${RoleAssignments.StoreAcctContrib.GUID}'
    principalType: 'ServicePrincipal'
    resourceGroupName: StorAcctRG
  }
  dependsOn: [
    automationAccount
  ]
}]


