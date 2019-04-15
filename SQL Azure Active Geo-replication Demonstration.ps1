
# Logar no Azure
Add-AzureRmAccount

$SubscriptionId = 'Sua assinatura do Azure'
$primaryResourceGroupName = "Nome do seu Grupo de Recursos Primário"
$primaryLocation = "Localização do Datacenter primário"
$secondaryResourceGroupName = "Nome do seu Grupo de Recursos Secundário"
$secondaryLocation = "Localização do Datacenter secundário"
$adminSqlLogin = "Nome do login"
$password = "senha forte"
$primaryServerName = "nome do server primário"
$secondaryServerName = "nome do server secundário"
$databaseName = "nome do seu banco de dados"
$primaryStartIp = "Range de IP inicial do server primário"
$primaryEndIp = "Range de IP final do server primario"
$secondaryStartIp = "Range de IP inicial do server secundário"
$secondaryEndIp = "Range de IP final do server secundário"

Set-AzureRmContext -SubscriptionId $subscriptionId

# Criando dois novo Resource Groups
$primaryResourceGroup = New-AzureRmResourceGroup -Name $primaryResourceGroupName -Location $primaryLocation
$secondaryResourceGroup = New-AzureRmResourceGroup -Name $secondaryResourceGroupName -Location $secondaryLocation

# Criando dois novo Resource Groups
$primaryResourceGroup = Get-AzureRmResourceGroup -Name $primaryResourceGroupName -Location $primaryLocation
$secondaryResourceGroup = Get-AzureRmResourceGroup -Name $secondaryResourceGroupName -Location $secondaryLocation


# Criado dois novos servidores lógicos com um nome de servidor exclusivo em todo o sistema
$primaryServer = New-AzureRmSqlServer -ResourceGroupName $primaryResourceGroupName `
    -ServerName $primaryServerName `
    -Location $primaryLocation `
    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminSqlLogin, $(ConvertTo-SecureString -String $password -AsPlainText -Force))

$secondaryServer = New-AzureRMSqlServer -ResourceGroupName $secondaryResourceGroupName `
    -ServerName $secondaryServerName `
    -Location $secondaryLocation `
    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminSqlLogin, $(ConvertTo-SecureString -String $password -AsPlainText -Force))


# Criando uma regra de firewall do servidor para cada servidor que permite acesso a partir do intervalo de IP especificado
$primaryserverfirewallrule = New-AzureRMSqlServerFirewallRule -ResourceGroupName $primaryResourceGroupName `
    -ServerName $primaryservername `
    -FirewallRuleName "AllowedIPs" -StartIpAddress $primaryStartIp -EndIpAddress $primaryEndIp

$secondaryserverfirewallrule = New-AzureRMSqlServerFirewallRule -ResourceGroupName $secondaryResourceGroupName `
    -ServerName $secondaryservername `
    -FirewallRuleName "AllowedIPs" -StartIpAddress $secondaryStartIp -EndIpAddress $secondaryEndIp

# Crie um banco de dados vazio com nível de desempenho S0 no servidor principal
$database = New-AzureRMSqlDatabase  -ResourceGroupName $primaryResourceGroupName `
    -ServerName $primaryServerName `
    -DatabaseName $databaseName -RequestedServiceObjectiveName "S0"

# Estabelecer a Geo-replicação ativa
$database = Get-AzureRmSqlDatabase -DatabaseName $databaseName -ResourceGroupName $primaryResourceGroupName -ServerName $primaryServerName
$database | New-AzureRMSqlDatabaseSecondary -PartnerResourceGroupName $secondaryResourceGroupName -PartnerServerName $secondaryServerName -AllowConnections "All"

# Iniciar o teste de Failover manualmente
$database = Get-AzureRMSqlDatabase -DatabaseName $databaseName -ResourceGroupName $secondaryResourceGroupName -ServerName $secondaryServerName
$database | Set-AzureRMSqlDatabaseSecondary -PartnerResourceGroupName $primaryResourceGroupName -Failover

# Monitorar a Geo-replicação após failover
$database = Get-AzureRMSqlDatabase -DatabaseName $databaseName -ResourceGroupName $secondaryResourceGroupName -ServerName $secondaryServerName
$database | Get-AzureRMSqlDatabaseReplicationLink -PartnerResourceGroupName $primaryResourceGroupName -PartnerServerName $primaryServerName

# Remover o link de replicação após o Failover
$database = Get-AzureRMSqlDatabase -DatabaseName $databaseName -ResourceGroupName $secondaryResourceGroupName -ServerName $secondaryServerName
$secondaryLink = $database | Get-AzureRMSqlDatabaseReplicationLink -PartnerResourceGroupName $primaryResourceGroupName -PartnerServerName $primaryServerName
$secondaryLink | Remove-AzSqlDatabaseSecondary

# Deletar o deployment 
#Remove-AzureRmResourceGroup -ResourceGroupName $primaryResourceGroupName
#Remove-AzureRmResourceGroup -ResourceGroupName $secondaryResourceGroupName

