targetScope = 'subscription'

param _artifactsLocation string = 'https://github.com/Azure/azure-monitor-baseline-alerts/blob/main/patterns/avd/scripts/'
@secure()
param _artifactsLocationSasToken string = ''

param AllResourcesSameRG bool
param AVDResourceGroupId string
@description('Array of objects with the Resource ID for colHostPoolName and colVMresGroup for each Host Pool.')
param HostPoolInfo array = []
param Location string
param LogAnalyticsWorkspaceResourceId string
param ResourceGroupId string
param StorageAccountResourceIds array
param Tags object


var AutomationAccountName = 'aa-avdmetrics-hostpool-storage'
var CloudEnvironment = environment().name
var ResourceGroupName = split(ResourceGroupId, '/')[4]
var RunbookNameGetStorage = 'AvdStorageLogData'
var RunbookNameGetHostPool = 'AvdHostPoolLogData'
var RunbookScriptGetStorage = 'Get-StorAcctInfo.ps1${_artifactsLocationSasToken}'
var RunbookScriptGetHostPool = 'Get-HostPoolInfo.ps1${_artifactsLocationSasToken}'
var SubscriptionId = split(ResourceGroupId, '/')[2]

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


module automationAccount '_automationAccount.bicep' = {
  name: 'linked_AutomationAccountCreation'
  scope: resourceGroup(SubscriptionId, ResourceGroupName)
  params: {
    Location: Location
    Tags: Tags
    LogAnalyticsWorkspaceResourceId: LogAnalyticsWorkspaceResourceId
    AutomationAccountName: AutomationAccountName
  }
}

module automationHostPool '_rg-aaHostPool.bicep' = {
  name: 'linked_AutomationAccountSetupHostPool'
  scope: resourceGroup(SubscriptionId, ResourceGroupName)
  params: {
    Location: Location
    Tags: Tags
    _artifactsLocation: _artifactsLocation
    RunbookNameGetHostPool: RunbookNameGetHostPool
    RunbookScriptGetHostPool: RunbookScriptGetHostPool
    CloudEnvironment: CloudEnvironment
    SubscriptionId: SubscriptionId
    AutomationAccountName: AutomationAccountName
  }
  dependsOn: [
    automationAccount
  ]
}


module automationStorage '_rg-aaStorage.bicep' =  if (!empty(StorageAccountResourceIds)) {
  name: 'linked_AutomationAccountSetupStorage'
  scope: resourceGroup(SubscriptionId, ResourceGroupName)
  params: {
    Location: Location
    Tags: Tags
    AutomationAccountName: AutomationAccountName
    _artifactsLocation: _artifactsLocation
    RunbookNameGetStorage: RunbookNameGetStorage
    RunbookScriptGetStorage: RunbookScriptGetStorage
    CloudEnvironment: CloudEnvironment
    SubscriptionId: SubscriptionId
  }
  dependsOn: [
    automationAccount
  ]
}

module roleAssignDesktopReadMulti '_rg-roleAssign.bicep' =  [for RG in HostPoolInfo: if (!AllResourcesSameRG) {
  scope: resourceGroup(split(RG.colVMResGroup, '/')[2],split(RG.colVMResGroup, '/')[4])
  name: 'linked_DsktpRead_VMRG_${split(RG.colVMResGroup, '/')[4]}'
  params: {
    AAPrincipalId: automationAccount.outputs.automationAccountPrincipalId
    RoleAssignmentId: RoleAssignments.DesktopVirtualizationRead.GUID
    RoleName: RoleAssignments.DesktopVirtualizationRead.Name
  }
  dependsOn: [
    automationAccount
  ]
}]

module roleAssignDesktopReadSingle '_rg-roleAssign.bicep' =  if (AllResourcesSameRG) {
  scope: resourceGroup(split(AVDResourceGroupId, '/')[2],split(AVDResourceGroupId, '/')[4])
  name: 'linked_DsktpRead_VMRG_${split(AVDResourceGroupId, '/')[4]}'
  params: {
    AAPrincipalId: automationAccount.outputs.automationAccountPrincipalId
    RoleAssignmentId: RoleAssignments.DesktopVirtualizationRead.GUID
    RoleName: RoleAssignments.DesktopVirtualizationRead.Name
  }
  dependsOn: [
    automationAccount
  ]
}

module roleAssignLAWContrib '_rg-roleAssign.bicep' = {
  scope: resourceGroup(split(LogAnalyticsWorkspaceResourceId, '/')[2], split(LogAnalyticsWorkspaceResourceId, '/')[4])
  name: 'linked_LAWContrib_${split(LogAnalyticsWorkspaceResourceId, '/')[4]}'
  params: {
    AAPrincipalId: automationAccount.outputs.automationAccountPrincipalId
    RoleAssignmentId: RoleAssignments.LogAnalyticsContributor.GUID
    RoleName: RoleAssignments.LogAnalyticsContributor.Name
  }
  dependsOn: [
    automationAccount
  ]
}

module roleAssignStorage '_rg-roleAssign.bicep' = [for StorAcct in StorageAccountResourceIds: {
  scope: resourceGroup(split(StorAcct, '/')[2], split(StorAcct, '/')[4])
  name: 'linked_StorContrib_${split(StorAcct,'/')[4]}'
  params: {
    AAPrincipalId: automationAccount.outputs.automationAccountPrincipalId
    RoleAssignmentId: RoleAssignments.StoreAcctContrib.GUID
    RoleName: RoleAssignments.StoreAcctContrib.Name
  }
  dependsOn: [
    automationAccount
  ]
}]
