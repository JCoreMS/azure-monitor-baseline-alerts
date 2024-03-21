
param AutomationAccountName string
param Location string
param LogAnalyticsWorkspaceResourceId string
param Tags object


resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: AutomationAccountName
  location: Location
  tags: Tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Free'
    }
  }
}

resource automationAccountDiagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'automationAccountDiagnosticSettings'
  scope: automationAccount
  properties: {
    workspaceId: LogAnalyticsWorkspaceResourceId
    logs: [
      {
        category: 'JobLogs'
        enabled: true
      }
      {
        category: 'JobStreams'
        enabled: true
      }
    ]
  }
}

output automationAccountResourceId string = automationAccount.id
output automationAccountPrincipalId string = automationAccount.identity.principalId

