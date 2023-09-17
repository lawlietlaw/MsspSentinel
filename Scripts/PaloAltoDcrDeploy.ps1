#Used to ensure that the user is not in the context of the customer
Connect-AzAccount -Tenant 
$Subscriptions = @((Get-AzSubscription).Id)
$pattern = "^H\d+AzureSentinel$"
#Need to grab our JSON config file from Github then modify with .notation
$JsonConfigFile = Invoke-RestMethod -Uri https://raw.githubusercontent.com/lawlietlaw/MsspSentinel/DcrScripting/ConfigFiles/PaloAltoDcr.json
$CusttableUri = "/subscriptions/'$subscription'/resourcegroups/$ResourceGroup/providers/microsoft.operationalinsights/workspaces/$Workspace/tables/$Global:CustTable?api-version=2021-12-01-preview"

$facilities = @(
    "Emergency",
    "Alert",
    "Critical",
    "Error",
    "Warning",
    "Notice",
    "Info",
    "Debug"
)



<# 
    The following conversion is made below to allow more consistent modifiction of our starting template.

    This allows for us to modify the necessary properties to customize everything that we need for the template. This allows for modular on demand creation of the DCR.
#>
 $HashTableConfig = ConvertTo-Json -Depth 10 $JsonConfigFile | ConvertFrom-HashTable -AsHashTable -Depth 10

 function DcrCreateSyslog{
    #We will now configure the DCR itself 

    $TableDest = Read-Host "What is the name of the table you will be shipping logs to? Example(Microsoft-CommonSecurityLog) Please enter the name here: 
    "
    if($TableDest -ne $null){
        #We append the existing template that we have

        $HashTable['properties']['dataSources']['syslog']['streams'] = $TableDest
    }
    
    #Prints out our Facility options.
    for ($i = 0; $i -lt $facilities.Length; $i++) {
        Write-Host ("$($i + 1). " + $facilities[$i])
    }
    
    $SelectedFacilities = @()
    while ($true) {
        $selectedOption = Read-Host "Select an option (1-8), or type 'done' to finish"
        
        if ($selectedOption -eq 'done') {
            break
        }
        
        if ($selectedOption -match '^[1-8]$') {
            $selectedFacilityNames += $facilityNamesOptions[[int]$selectedOption - 1]
        }
        else {
            Write-Host "Invalid option. Please try again."
        }
    }
    
    Write-Host "You selected: $($selectedFacilityNames -join ', ')"

    #Now that we know the Facilities that we care about lets add them.
    $HashTable = ['properties']['dataSources']['syslog'][0]['streams'][facilityNames] = $SelectedFacilities

    #Modification of the name value
    $TableName = Read-Host "Please enter the name of the DCR"
    if($TableName){
        $HashTable['properties']['dataSources']['syslog'][0]['name'] = $TableName
    }


    #Now we need too modify the log analytics workspace we will be forwarding to 

    Write-Host "Please select the workspace that you need the logs delivered to"
    (Get-AzOperationalInsightsWorkspace).name

    $WorkspaceName = Read-Host "Please enter the name of the workspace you would like to select"

    Get-AzOperationalInsightsWorkspace -Name $WorkspaceName

    $DcrLogAnalytics = @{
        workspaceResourceId = $WorkspaceName.CustomerId.Guid
        workspaceId = $WorkspaceName.ResourceId
        name = 'DataCollectionEvent'
    }

    $HashTable['properties']['destinations']['logAnalytics'] += $DcrLogAnalytics

    #Now we need to to determine if we need any additional filtering of the log messages that are being brought in
    $DcrFilteringMod Read-Host "Do you have any KQL filtering that will need to be used to change the data? For Example do you need to filter out traffic logs? This can be done by entering in the necessary KQL 
    yes/no
    "
    if($DcrFilteringMod -eq 'yes'){
        $CustTable = Read-Host "You will now need to enter your custom table. Please note that the custom table must already exist."

        $kql = Read-Host "Please enter your KQL, note that this will be modified for the use with JSON formatting."
        $ParsedKql = ConvertTo-Json $kql -Depth 10

        #Add our variables collected above to our JSON config file. 
        $dataFlows = @(
    @{
        streams = $TableName
        destinations = $destinations1
    },
    @{
        streams = $TableName
        destinations = $destinations
        transformKql = $ParsedKql
        outputStream = $CustTable
    }
)
    #Now append this to our json variable
    $HashTable['properties']['dataFlows'] += $DataFlows

}else{
    $dataFlows = @(
        @{
            streams = $TableName
            destinations = $destinations
        }
    )

    #Now we need to complete the deployment process.
    ConvertTo-Json -Depth 10 $HashTable -OutFile Dcr.json


    New-AzDataCollectionRule -Location $LogAnalyticsWorkspace.location -ResourceGroupName $ResourceGroup -RuleName $RuleName -RuleFile 'Dcr.json'
}

 }

function AllCustomerDcr{
    #This will loop through all customers subscriptions & deploy the DCR to all customers. 

    Write-Host "This script will now walk you through the deployment of this DCR to all customers. Please keep this in mind when creating the DCR rules"

    $RuleName = Read-Host "Enter the name of the DCR"

    $TableDest = Read-Host "What is the name of the table you will be shipping logs to? Example(Microsoft-CommonSecurityLog,Custom-CommonSecurityLog_CL) Please enter the name here:"
    #Need to add a regex choice to make sure the the table is in the correct format.
    $HashTable['properties']['dataSources']['syslog']['streams'] = $TableDest


    $DcrFilteringMod = Read-Host "Do you have any KQL filtering that will need to be used to change the data? For Example do you need to filter out traffic logs? This can be done by entering in the necessary KQL 
    yes/no
    "
    if($DcrFilteringMod -eq 'yes'){
        $Global:CustTable = Read-Host "You will now need to enter your custom table. Please note that the custom table must already exist."

        $kql = Read-Host "Please enter your KQL, note that this will be modified for the use with JSON formatting."
        $ParsedKql = ConvertTo-Json $kql -Depth 10

        #Add our variables collected above to our JSON config file. 
        $dataFlows = @(
    @{
        streams = $TableName
        destinations = $destinations1
    },
    @{
        streams = $TableName
        destinations = $destinations
        transformKql = $ParsedKql
        outputStream = "Custom-$CustTable"
    }
    )
    #Now append this to our json variable
    $HashTable['properties']['dataFlows'] += $DataFlows


    #Find where our table lives.

    Get-AzOperationalInsightsWorkspace
    
    $WorkspaceName = Read-Host "Please enter the workspace from above which contains your custom table."

    $WorkspaceCustTable = Get-AzOperationalInsightsWorkspace -Name $WorkspaceName


    #Create our file path to store our JSON file for the configuration of the rule.
    $DirectoryName = "/home/Sentinel" + (Get-Date -Format "MMddyyyyHHmm")
    $FilePath = New-Item -ItemType Directory $DirectoryName
    #Fetch our custom table schema and save it in JSON format
    ConvertTo-Json (Get-AzOperationalInsightsTable -ResourceGroupName $WorkspaceCustTable.ResourceGroupName -WorkspaceName $WorkspaceCustTable.Name -Name $Global:CustTable).Schema -OutFile $FilePath/DcrRuleFile.json
    

    }else{
    $dataFlows = @(
        @{
            streams = $TableName
            destinations = $destinations
        }
        )
    }

    #Now that we populated as many values as we can that apply to all customers we now need to start our loop
    foreach($Subscription in $Subscriptions){
    #Now we need to add the subscription specific bits.

    #Collect our local variables for the API post
    $ResourceGroupName = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -match $pattern}
    $subscription = $_
    $WorkspaceName = Get-AzOperationalInsightsWorkspace | Where-Object {$_.Name -match $pattern}
    
    #Check to see if we need to generate the custom table.

    $CustTablePresent = Get-AzOperationalInsightsTable -ResourceGroupName $ResourceGroupName.Name -WorkspaceName $WorkspaceName.Name -Name $Global:CustTable

    

    if($null -ne $CustTablePresent){
        #Generate the custom table that is required
        Invoke-RestMethod -Path $CusttableUri -Method PUT -Payload $Global:CustTableJson
        $l = Get-AzOperationalInsightsTable -ResourceGroupName $ResourceGroupName.Name -WorkspaceName $WorkspaceName.Name -ErrorAction SilentlyContinue
        #Check that the table is created 
        while($null -ne $l){
            Invoke-RestMethod -Path $CusttableUri -Method PUT -Payload $Global:CustTableJson
            $l = Get-AzOperationalInsightsTable -ResourceGroupName $ResourceGroupName.Name -WorkspaceName $WorkspaceName.Name -ErrorAction SilentlyContinue
        }
        #Generate our DCR now that we have our DCR put together.
        New-AzDataCollectionRule -Location $LogAnalyticsWorkspace.Location -ResourceGroupName $ResourceGroup -RuleName $RuleName -RuleFile $FilePath
    }else{
        #Table already exist we just need to create the DCR
        New-AzDataCollectionRule -Location $LogAnalyticsWorkspace.location -ResourceGroupName $ResourceGroup -RuleName $RuleName -RuleFile $FilePath
        }
    
    }
   
}

 function DcrCreationMenu{
    Write-Host "We will now walk you through the necessary steps to create our DCR"
    Clear-Host

    #This will prompt the user in order to select the necessary DCR creation function
    do {
        Write-Host "1.) Linux System Dcr Collection
                    2.) Windows system Dcr Collection
                    3.) Syslog Dcr Collection
                    4.) Exit"
    $Choice = Read-Host "Please selection from one of the above options 1-3 or exit by selecting 4"

    switch($Choice)
    '1'{
        Write-Host "Starting configuration of Linux DCR"
        LinuxDcrCreation
    }
    '2'{
        Write-Host "Starting configuration of Windows System logs"
        WindowsDcrCreation
    }
    '3'{
        Write-Host "Starting configuration of Syslog DCR"
    }
    default {
        Write-Host "Invalid Choice please select a option 1-4"
    }

    } while ($Choice -ne '4')
    
}