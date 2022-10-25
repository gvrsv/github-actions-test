[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ghOrganization,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $ghToken,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $sonarQubeDomainName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $sonarQubeToken
)

function Get-ArchivedGHRepo {
    [CmdletBinding()]
    Param
    (
        # GitHub organization name
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ghOrganization,

        # GitHub PAT token
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $ghToken
    )
    # Get organization repo pages number
    try {
        $reposUri = "https://api.github.com/orgs/" + $ghOrganization + "/repos?page=1&per_page=100"
        $headers = @{
            Authorization="Bearer $ghToken"
            Accept="application/vnd.github+json"
        }
        $ghWebRequest = Invoke-WebRequest -Method Get -Uri $reposUri -UseBasicParsing -Headers $headers
        $headersLink = ($ghWebRequest.Headers.Link).Split(',').Trim()[1]
        $selectMatches = $headersLink | Select-String "\?page=(\d*)"
        [int]$ghLastPage = $selectMatches.Matches.Groups[1].Value
        
        If($ghLastPage -eq 0){
            $Host.UI.WriteErrorLine("GitHub last page number is not correct")
            Write-Error -Message "$_.Exception.Message"
        }
    }
    catch {
        $Host.UI.WriteErrorLine("Failed to get organization repo pages number")
        Write-Error -Message "$_.Exception.Message"
    }

    # Iterate through pages - max 100 per page
    try {
        $archivedRepos = @()
        1..$ghLastPage | ForEach-Object {
        
            $pageNumber = $_
            Write-Verbose -Message "Iterate through pages: $pageNumber of $ghLastPage"
            $reposPage = "https://api.github.com/orgs/" + $ghOrganization + "/repos?page=$pageNumber&per_page=100"
            $response = Invoke-RestMethod -Method Get -Uri $reposPage -UseBasicParsing -Headers $headers
            $archivedRepos += $response | Where-Object {$_.archived -eq "true"} | Select-Object -ExpandProperty "name"
        }

        Write-Verbose "Archived repositories found: $($archivedRepos.Count)"
        return $archivedRepos
    }
    catch {
        $Host.UI.WriteErrorLine("Failed to iterate through pages")
        Write-Error -Message "$_.Exception.Message"
    }
}

function Get-SonarProjects {
    [CmdletBinding()]
    Param
    (
        # SonarQube domain name
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $sonarDomainName,

        # SonarQube user token
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $sonarToken

    )

    # Get SonarQube pages number
    try {
        $password = ''
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $sonarToken,$password)))
        [int]$pageSize = 500
        [int]$pageNumber = 1
        $sonarDomainName = $sonarDomainName.Trim()
        $response = Invoke-RestMethod -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method GET -Uri "https://$sonarDomainName/api/components/search?qualifiers=TRK&p=$pageNumber&ps=$pageSize"
        [int]$totalPages = [math]::Ceiling(($response.paging.total) / $pageSize)
        $sonarProjects = @()
        $sonarProjects += $response.components.key
        Write-Verbose -Message "Total pages: $totalPages"
    }
    catch{
        $Host.UI.WriteErrorLine("Failed to get page number")
        Write-Error -Message "$_.Exception.Message"
        throw
    }

    # Iterate through pages - max 500 per page
    try {
        2..$totalPages | ForEach-Object {
            $pageNumber = $_
            Write-Verbose -Message "Iterate through pages: $pageNumber of $totalPages"
            $response = Invoke-RestMethod -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method GET -Uri "https://$sonarDomainName/api/components/search?qualifiers=TRK&p=$pageNumber&ps=$pageSize"
            $sonarProjects += $response.components.key
        }
        Write-Verbose -Message "SonarQube $sonarURL total projects: $($sonarProjects.Count)"
        return $sonarProjects
    }
    catch{
        $Host.UI.WriteErrorLine("Failed to iterate through pages")
        Write-Error -Message "$_.Exception.Message"
        throw
    }
}

function Get-ArchivedSonarProjects {
    [CmdletBinding()]
    Param
    (
        # SonarQube project list
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $sonarProjects,

        # GitHub archived repo
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $archivedRepos
    )
    
    $archivedSonarProjects = @()
    $archivedRepos | ForEach-Object {

        $pattern = $_
        $projectMatch = $sonarProjects | Select-String -Pattern $pattern
        if($projectMatch){
        
            Write-Verbose -Message "$($projectMatch.count) match(es) for {$pattern} pattern"
            foreach($project in $projectMatch){

                Write-Verbose -Message "Match: $project"
                $archivedSonarProjects += $project.ToString().Trim()
            }    
        }
    }

    Write-Verbose -Message "$($archivedSonarProjects.count) archived projects found."
    return $archivedSonarProjects
}

$archivedGitHubRepos = Get-ArchivedGHRepo -ghOrganization $ghOrganization -ghToken $ghToken
$sonarQubeProjects = Get-SonarProjects -sonarDomainName $sonarQubeDomainName -sonarToken $sonarQubeToken
$archivedSonarQubeProjects = Get-ArchivedSonarProjects -sonarProjects $sonarQubeProjects -archivedRepos $archivedGitHubRepos

return $archivedSonarQubeProjects