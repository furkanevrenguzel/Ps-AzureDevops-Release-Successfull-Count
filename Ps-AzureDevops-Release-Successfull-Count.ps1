$token = "*" # Token code.
$Organization = "*" # Organization name.

$Header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":"+$token))}
$Type = "application/json"
$Url = "https://dev.azure.com/"+ $Organization + '/_apis/projects?$top=300&api-version=6.0'


$ProjectItemHolder = (Invoke-RestMethod -Uri $Url -Headers $Header -Method GET -ContentType $Type)
$ProjectItems = ($ProjectItemHolder.value) 

$deploymentsCount = 0
$continuationToken = $null
$releaseDetailList = New-Object System.Collections.ArrayList

# For loop for scanning all projects under the Azure DevOps organization.

foreach ($projectItem in $ProjectItems){

    # It is the field where the date is entered from whichever date we want to retrieve the data.
   
    $UrlDList = "https://vsrm.dev.azure.com/" + $Organization + "/" + $projectItem.name + '/_apis/release/deployments?minStartedTime=2020-08-01T00:00:00.00Z&$top=10000000000&api-version=6.0'

    $ProgressPreference = 'SilentlyContinue' # Surpress Powershell info for faster performance.
    $projectDeploymentsHolder = (Invoke-WebRequest -Uri $UrlDList -Headers $Header -Method GET -ContentType $Type)
    $continuationToken=$projectDeploymentsHolder.Headers.'x-ms-continuationtoken'
    $deployments = $projectDeploymentsHolder.content | ConvertFrom-Json
    $deploymentsCount=$deploymentsCount+$deployments.count
  
    # For loop for all the deployments under the specific project.
    
    foreach($deployment in $deployments.value)
    {
        # Boxing up all necessary information in a object
        $object = New-Object psobject
        Write-Host $deployments.id
        $object | Add-Member -MemberType NoteProperty -Name DeploymentName -Value $deployment.releaseDefinition.name
        $object | Add-Member -MemberType NoteProperty -Name ReleaseName -Value $deployment.release.name
        $object | Add-Member -MemberType NoteProperty -Name StageName -Value $deployment.releaseEnvironment.name
        $object | Add-Member -MemberType NoteProperty -Name ProjectName -Value $ProjectItem.name
        $object | Add-Member -MemberType NoteProperty -Name ReleaseDate -Value $deployment.startedOn
        $object | Add-Member -MemberType NoteProperty -Name SuccessCount -Value 0
        $object | Add-Member -MemberType NoteProperty -Name OtherCount -Value 0

        # Checking the succeeded deployment via their status attiribute.
        if($deployment.deploymentStatus -eq "succeeded")
        {
                    $object.SuccessCount = $object.SuccessCount + 1
        }
        else 
        {
                    $object.OtherCount = $object.OtherCount + 1
        }
        # Adding all the information under a list in the name of releaseDetailsList.
        $releaseDetailList.Add($object) > $null
        Write-Host $object

    }
    # Checks if # continuationToken is still empty. If it has values adds it to the request url below and continue using it.
    while ($continuationToken -ne $null)
    {
        $UrlDList = "https://vsrm.dev.azure.com/" + $Organization + "/" + $projectItem.name + '/_apis/release/deployments?minStartedTime=2021-09-01T00:00:00.00Z&$top=10000000000&continuationToken='+$continuationToken+'&api-version=6.0'
        
        $ProgressPreference = 'SilentlyContinue' # Surpress Powershell info for faster performance.
        $projectDeploymentsHolder = (Invoke-WebRequest -Uri $UrlDList -Headers $Header -Method GET -ContentType $Type)
        $continuationToken=$projectDeploymentsHolder.Headers.'x-ms-continuationtoken'
        $deployments = $projectDeploymentsHolder.content | ConvertFrom-Json
        $deploymentsCount=$deploymentsCount+$deployments.count
    
        # For loop for all the deployments under the specific project.
        foreach($deployment in $deployments.value)
        {
            $object = New-Object psobject
            Write-Host $deployments.id
            $object | Add-Member -MemberType NoteProperty -Name DeploymentName -Value $deployment.releaseDefinition.name
            $object | Add-Member -MemberType NoteProperty -Name ReleaseName -Value $deployment.release.name
            $object | Add-Member -MemberType NoteProperty -Name StageName -Value $deployment.releaseEnvironment.name
            $object | Add-Member -MemberType NoteProperty -Name ProjectName -Value $ProjectItem.name
            $object | Add-Member -MemberType NoteProperty -Name ReleaseDate -Value $deployment.startedOn
            $object | Add-Member -MemberType NoteProperty -Name SuccessCount -Value 0
            $object | Add-Member -MemberType NoteProperty -Name OtherCount -Value 0
       
            # Checking the succeeded deployment via their status attiribute.
            if($deployment.deploymentStatus -eq "succeeded")
            {
                        $object.SuccessCount = $object.SuccessCount + 1
            }
            else 
            {
                        $object.OtherCount = $object.OtherCount + 1
            }
            # Adding all the information under a list in the name of releaseDetailsList
            $releaseDetailList.Add($object) > $null
            Write-Host $object
          }
       }
    
}

# Console outputs

#Write-Host "Release Details: "; $releaseDetailList | Format-Table -Property DeploymentName, ReleaseName, StageName, ProjectName, ReleaseDate, SuccessCount, OtherCount

# CSV Creation
$releaseDetailList | Export-Csv -Delimiter ";" -Path ..\..\Users\MONSTER\Desktop/AzureDevOps.csv