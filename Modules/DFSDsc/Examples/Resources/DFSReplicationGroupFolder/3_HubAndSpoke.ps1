<#
    .EXAMPLE
    Create a Hub and Spoke style DFS Replication Group called WebSite
    containing one Hub member and one or more Spoke members. The name of
    the Hub computer is passed in the HubComputerName parameter. The Hub
    member contains a folder called WebSiteFles with the path
    'd:\inetpub\wwwroot\WebSiteFiles'. This path is replicated to all
    members of the SpokeComputerName parameter array into the
    'd:\inetpub\wwwroot\WebSiteFiles' folder.
#>
Configuration Example
{
    param
    (
        [Parameter()]
        [System.String[]]
        $NodeName = 'localhost',

        [Parameter()]
        [PSCredential]
        $Credential,

        [Parameter(Mandatory = $true)]
        [System.String]
        $HubComputerName,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $SpokeComputerName
    )

    Import-DscResource -Module DFSDsc

    Node $NodeName
    {
        <#
            Install the Prerequisite features first
            Requires Windows Server 2012 R2 Full install
        #>
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = 'Present'
            Name = 'RSAT-DFS-Mgmt-Con'
        }

        # Configure the Replication Group
        DFSReplicationGroup RGWebSite
        {
            GroupName = 'WebSite'
            Description = 'Files for web server'
            Ensure = 'Present'
            Members = @() + $HubComputerName + $SpokeComputerName
            Folders = 'WebSiteFiles'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[WindowsFeature]RSATDFSMgmtConInstall'
        } # End of RGWebSite Resource

        DFSReplicationGroupFolder RGWebSiteFolder
        {
            GroupName = 'WebSite'
            FolderName = 'WebSiteFiles'
            Description = 'DFS Share for replicating web site files'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroup]RGWebSite'
        } # End of RGWebSiteFolder Resource

        DFSReplicationGroupMembership RGWebSiteMembershipHub
        {
            GroupName = 'WebSite'
            FolderName = 'WebSiteFiles'
            ComputerName = $HubComputerName
            ContentPath = 'd:\inetpub\wwwroot\WebSiteFiles'
            PrimaryMember = $true
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroupFolder]RGWebSiteFolder'
        } # End of RGWebSiteMembershipHub Resource

        # Configure the connection and membership for each Spoke
        foreach ($spoke in $SpokeComputerName) {
            DFSReplicationGroupConnection "RGWebSiteConnection$spoke"
            {
                GroupName = 'WebSite'
                Ensure = 'Present'
                SourceComputerName = $HubComputerName
                DestinationComputerName = $spoke
                PSDSCRunAsCredential = $Credential
                DependsOn = '[DFSReplicationGroupFolder]RGWebSiteFolder'
            } # End of RGWebSiteConnection$spoke Resource

            DFSReplicationGroupMembership "RGWebSiteMembership$spoke"
            {
                GroupName = 'WebSite'
                FolderName = 'WebSiteFiles'
                ComputerName = $spoke
                ContentPath = 'd:\inetpub\wwwroot\WebSiteFiles'
                PSDSCRunAsCredential = $Credential
                DependsOn = "[DFSReplicationGroupConnection]RGWebSiteConnection$spoke"
            } # End of RGWebSiteMembership$spoke Resource
        }
    } # End of Node
} # End of Configuration