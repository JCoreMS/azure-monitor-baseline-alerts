targetScope = 'resourceGroup'

param _artifactsLocation string
param CloudEnvironment string
param SubscriptionId string
@secure()
param RunbookScriptGetHostPool string
param RunbookNameGetHostPool string
param AutomationAccountName string
param Location string
param Tags object
param time string = utcNow()

var varScheduleName = 'AVD_Chk-'
var varTimeIncrement = ['PT15M', 'PT30M', 'PT45M', 'PT60M']
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
var varTimeZone = varTimeZones[Location]

var varJobScheduleParamsHostPool = {
  CloudEnvironment: CloudEnvironment
  SubscriptionId: SubscriptionId
}

resource automationAccountExisting 'Microsoft.Automation/automationAccounts@2023-11-01' existing = {
  name: AutomationAccountName
}

resource runbookGetHostPool 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  name: RunbookNameGetHostPool
  location: Location
  tags: Tags
  parent: automationAccountExisting
  properties: {
    runbookType: 'PowerShell'
    description: 'AVD Metrics Runbook for collecting related Host Pool statistics to store in Log Analytics for specified Alert Queries'
    publishContentLink: {
      uri: '${_artifactsLocation}${RunbookScriptGetHostPool}'
      version: '7.2'
    }
  }
}

resource scheduleGetHostPool 'Microsoft.Automation/automationAccounts/schedules@2023-11-01' = [for i in range(0, length(varTimeIncrement)) :{
  name: '${varScheduleName}HostPool-${i}'
  parent: automationAccountExisting
  properties: {
    description: 'AVD Metrics Schedule for collecting related Host Pool statistics to store in Log Analytics for specified Alert Queries'
    frequency: 'Hour'
    interval: 1
    startTime: dateTimeAdd(time, varTimeIncrement[i])
    timeZone: varTimeZone
  }
}]

resource jobGetHostPool 'Microsoft.Automation/automationAccounts/jobSchedules@2023-11-01' = [for i in range(0, length(varTimeIncrement)) :{
  name: guid('setparams-HostPool-${i}')
  parent: automationAccountExisting
  properties: {
    runbook: {
      name: RunbookNameGetHostPool
    }
    schedule: {
      name: '${varScheduleName}HostPool-${i}'
    }
    parameters: varJobScheduleParamsHostPool
  }
  dependsOn: [
    runbookGetHostPool
    scheduleGetHostPool
  ]
}]
