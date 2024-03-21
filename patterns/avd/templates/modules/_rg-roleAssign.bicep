targetScope = 'resourceGroup'

param AAPrincipalId string
param RoleAssignmentId string
param RoleName string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(AAPrincipalId,RoleAssignmentId)
  properties: {
    principalId: AAPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RoleAssignmentId)
  }
}
