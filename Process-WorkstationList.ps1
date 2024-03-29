#Requires -Version 3.0
<#
  .SYNOPSIS
  .DESCRIPTION
  .PARAMETER <Parameter-Name>
  .EXAMPLE
  .INPUTS
  .OUTPUTS
  .NOTES
    Script ProcList.ps1 Version 1.0 by Thanatos on 3/21/2014
  .LINK
#>
[CmdletBinding()]
param (
)

#$ErrorActionPreference = "Stop"

# Comment Out $VerbosePreference Line for Production Deployment
#$VerbosePreference = "Continue"

# Comment Out $DebugPreference Line for Production Deployment
#$DebugPreference = "Continue"

$ScriptName = "Process My Workstation List"
$ScriptVersion = "3.22"
$ScriptAuthor = "Kenneth D. Sweet"

#region Show / Hide PowerShell Window
$WindowDisplay = @"
using System;
using System.Runtime.InteropServices;

namespace Window
{
  public class Display
  {
    [DllImport("Kernel32.dll")]
    private static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    private static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    public static bool Hide()
    {
      return ShowWindowAsync(GetConsoleWindow(), 0);
    }

    public static bool Show()
    {
      return ShowWindowAsync(GetConsoleWindow(), 5);
    }
  }
}
"@
Add-Type -TypeDefinition $WindowDisplay -Debug:$False
if ($VerbosePreference -eq "SilentlyContinue")
{
  [Void][Window.Display]::Hide()
}
#endregion

[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')

$FormSpacer = 4
$FormComponents = New-Object -TypeName System.ComponentModel.Container

#region ******** Multiple Thread Functions ********

<#
  # Single Thread
  ForEach ($Item in $List)
  {
    if ((Create-MyRunspace))
    {
      $CurrentThread = Start-MyThread -ScriptBlock $ThreadScript -Parameters @{ "Item"=$Item }
      $ReturnedData = Wait-MyThread -Threads $CurrentThread
    }
  }

  # Multiple Threads
  if ((Create-MyRunspace -MaxPools 4))
  {
    $CurrentThreads = @()
    ForEach ($Item in $List)
    {
      $CurrentThreads += Start-MyThread -ScriptBlock $ThreadScript -Parameters @{ "Item"=$Item }
    }
    $ReturnedData = Wait-MyThread -Threads $CurrentThreads
  }
  
  if (-not (Kill-MyThread))
  {
    # Error Killing Threads
  }
 
  Add Kill-MyThread to Form Closing Event
#>

#region function Create-MyRunspace
function Create-MyRunspace() 
{
  <#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER MinPools
    .PARAMETER MaxPools
    .INPUTS
    .OUTPUTS
    .EXAMPLE
      Create-MyRunspace
    .EXAMPLE
      Create-MyRunspace -MaxPools 8
    .EXAMPLE
      Create-MyRunspace -MinPools 1 -MaxPools 8
    .NOTES
      Original Script By Ken Sweet
    .LINK
  #>
  [CmdletBinding(DefaultParameterSetName="LocalRunspace")]
  param (
    [parameter(Mandatory=$False, ParameterSetName="RunspacePool")]
    [Int]$MinPools = 1,
    [parameter(Mandatory=$True, ParameterSetName="RunspacePool")]
    [Int]$MaxPools
  )
  Write-Verbose -Message "Start Create-MyRunspace Function"
  Try
  {
    if ($PSCmdLet.ParameterSetName -eq "LocalRunspace")
    {
      $Script:MyRunspace = [PSCustomObject]@{"Runspace" = ([Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($Host, [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()));
                                             "AllowClose" = $True}
    }
    else
    {
      $Script:MyRunspace = [PSCustomObject]@{"Runspace" = ([Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool($MinPools, $MaxPools, [Management.Automation.Runspaces.InitialSessionState]::CreateDefault(), $Host));
                                             "AllowClose" = $True}
    }
    $Script:MyRunspace.RunSpace.Open()
    $True
  }
  Catch
  {
    $False
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Finish Create-MyRunspace Function"
}
#endregion

#region function Start-MyThread
function Start-MyThread() 
{
  <#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER Value
    .INPUTS
    .OUTPUTS
    .EXAMPLE
      Start-MyThread -Value "String"
    .NOTES
      Original Script By Ken Sweet
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [ScriptBlock]$ScriptBlock,
    [HashTable]$Parameters,
    [Object]$Runspace = $Script:MyRunspace
  )
  Write-Verbose -Message "Start Start-MyThread Function"
  Try
  {
    if (($Runspace.Runspace.RunspacePoolStateInfo.State -eq [System.Management.Automation.Runspaces.RunspacePoolState]::Opened) -or ($Runspace.Runspace.RunspaceStateInfo.State -eq [System.Management.Automation.Runspaces.RunspaceState]::Opened))
    {
      $NewThread = New-Object -TypeName PSObject -Property @{"Shell"=$([Management.Automation.PowerShell]::Create());"Result"=$Null}
      [Void]$NewThread.Shell.AddScript($ScriptBlock)
      if ($PSBoundParameters.ContainsKey("Parameters"))
      {
        [Void]$NewThread.Shell.AddParameters($Parameters)
      }
      if ($Runspace.Runspace.GetType().Name -eq "RunspacePool")
      {
        $NewThread.Shell.RunSpacePool = $Runspace.Runspace
      }
      else
      {
        $NewThread.Shell.RunSpace = $Runspace.Runspace
      }
      $NewThread.Result = $NewThread.Shell.BeginInvoke()
      $NewThread
    }
  }
  Catch
  {
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Finish Start-MyThread Function"
}
#endregion

#region function Wait-MyThread
function Wait-MyThread() 
{
  <#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER Value
    .INPUTS
    .OUTPUTS
    .EXAMPLE
      Wait-MyThread -Value "String"
    .NOTES
      Original Script By Ken Sweet
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object[]]$Threads,
    [Int]$Wait = [Int]::MaxValue,
    [Int]$Pause = 100,
    [Object]$Runspace = $Script:MyRunspace
  )
  Write-Verbose -Message "Start Wait-MyThread Function"
  Try
  {
    $StartTime = [DateTime]::Now
    $TimeSpan = New-Object -TypeName System.TimeSpan(0, 0, $Wait)
    While (([DateTime]::Now - $StartTime) -lt $TimeSpan)
    {
      $IsDone = $True
      ForEach ($Thread in $Threads)
      {
        $IsDone = $IsDone -and $Thread.Result.IsCompleted
      }
      if ($IsDone)
      {
        break
      }
      [System.Windows.Forms.Application]::DoEvents()
      [System.Threading.Thread]::Sleep($Pause)
    }
    $Runspace.AllowClose = $False
    if (($Runspace.Runspace.RunspacePoolAvailability -eq [System.Management.Automation.Runspaces.RunspacePoolAvailability]::Available) -or ($Runspace.Runspace.RunspaceAvailability -eq [System.Management.Automation.Runspaces.RunspaceAvailability]::Available))
    {
      ForEach ($Thread in $Threads)
      {
        if ($Thread.Result.IsCompleted) {
          $Thread.Shell.EndInvoke($Thread.Result)
        }
      }
      $Runspace.Runspace.Close()
    }
    ForEach ($Thread in $Threads)
    {
      $Thread.Shell.Stop()
      $Thread.Shell.Dispose()
    }
  }
  Catch
  {
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Finish Wait-MyThread Function"
}
#endregion

#region function Kill-MyThread
function Kill-MyThread() 
{
  <#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER Value
    .INPUTS
    .OUTPUTS
    .EXAMPLE
      Kill-MyThread -Value "String"
    .NOTES
      Original Script By Ken Sweet
    .LINK
  #>
  [CmdletBinding()]
  param (
    [Object]$Runspace = $Script:MyRunspace
  )
  Write-Verbose -Message "Start Kill-MyThread Function"
  Try
  {
    if ($Runspace.AllowClose)
    {
      $Runspace.Runspace.Close()
    }
    $True
  }
  Catch
  {
    $False
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Finish Kill-MyThread Function"
}
#endregion

#endregion

#region ******** $Script:ThreadScript ScriptBlock ********
$Script:ThreadScript = @'
  [CmdletBinding()]
  param (
    [Object]$Item,
    [Object]$ThreadCommand
  )
 
  if ($ThreadCommand.Kill)
  {
    $Item.SubItems[10].Text = "Terminated"
    Return
  }

  [Void][Reflection.Assembly]::LoadWithPartialName("System.DirectoryServices.AccountManagement")

  #region function Get-MyLocalComputer
  function Get-MyLocalComputer() 
  {
    <#
      .SYNOPSIS
        Get the Local or Remote Computer
      .DESCRIPTION
        Get the Local or Remote Computer
      .PARAMETER ComputerName
      .PARAMETER UserName
      .PARAMETER Password
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        $LocalComputer = Get-MyLocalComputer -ComputerName "RemoteComputer"
      .NOTES
        Original Script By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding(DefaultParameterSetName="Default")]
    param (
      [Parameter(Mandatory=$True, ParameterSetName="Default")]
      [Parameter(Mandatory=$True, ParameterSetName="AltUser")]
      [String]$ComputerName,
      [Parameter(Mandatory=$False, ParameterSetName="AltUser")]
      [String]$UserName=$Null,
      [Parameter(Mandatory=$False, ParameterSetName="AltUser")]
      [String]$Password=$Null
    )
    Try
    {
      Switch ($PSCmdlet.ParameterSetName)
      {
        "AltUser"
        {
          $Script:LocalComputer = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine, $ComputerName, $UserName, $Password)
          Break
        }
        "Default"
        {
          $Script:LocalComputer = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine, $ComputerName)
          Break
        }
      }
      Return $True
    }
    Catch
    {
      Return $False
    }
  }
  #endregion

  #region function Get-MyLocalUsers
  function Get-MyLocalUsers() 
  {
    <#
      .SYNOPSIS
        Get Local Users
      .DESCRIPTION
        Get Local Users
      .PARAMETER UserID
      .PARAMETER DisplayName
      .PARAMETER Description
      .PARAMETER Disabled
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        $Users = Get-MyLocalUsers -UserID "LocalUser"
      .NOTES
        Original Script By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding()]
    param (
      [String]$UserID="*",
      [String]$DisplayName="*",
      [String]$Description="*",
      [Switch]$Disabled
    )
    Try
    {
      $Searcher = New-Object System.DirectoryServices.AccountManagement.PrincipalSearcher
      $UserPrincipal = New-Object System.DirectoryServices.AccountManagement.UserPrincipal($Script:LocalComputer)
      $UserPrincipal.SamAccountName = $UserID
      $UserPrincipal.DisplayName = $DisplayName
      $UserPrincipal.Description = $Description
      $UserPrincipal.Enabled = (-Not $Disabled)
      $Searcher.QueryFilter = $UserPrincipal
      $Searcher.FindAll()
    }
    Catch
    {
    }
  }
  #endregion

  #region function Get-MyLocalGroups
  function Get-MyLocalGroups() 
  {
    <#
      .SYNOPSIS
        Get Local Groups
      .DESCRIPTION
        Get Local Groups
      .PARAMETER GroupName
      .PARAMETER DisplayName
      .PARAMETER Description
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        $Groups = Get-MyLocalGroups -GroupName "LocalGroup"
      .NOTES
        Original Script By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding()]
    param (
      [String]$GroupName="*",
      [String]$Description="*"
    )
    Try
    {
      $Searcher = New-Object System.DirectoryServices.AccountManagement.PrincipalSearcher
      $GroupPrincipal = New-Object System.DirectoryServices.AccountManagement.GroupPrincipal($Script:LocalComputer)
      $GroupPrincipal.SamAccountName = $GroupName
      $GroupPrincipal.Description = $Description
      $Searcher.QueryFilter = $GroupPrincipal
      $Searcher.FindAll()
    }
    Catch
    {
    }
  }
  #endregion

  #region function New-MyLocalUser
  function New-MyLocalUser() 
  {
    <#
      .SYNOPSIS
        Creates a New Local User
      .DESCRIPTION
        Creates a New Local User
      .PARAMETER UserID
      .PARAMETER Password
      .PARAMETER DisplayName
      .PARAMETER Description
      .PARAMETER Enabled
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        $NewUser = New-MyLocalUser -UserID "NewUser" -Password "Password"
      .EXAMPLE
        $NewUser = New-MyLocalUser -UserID "NewUser" -Password "Password" -Enabled
      .NOTES
        Original Script By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding()]
    param (
      [Parameter(Mandatory=$True)]
      [String]$UserID,
      [Parameter(Mandatory=$True)]
      [String]$Password,
      [String]$DisplayName=$Null,
      [String]$Description=$Null,
      [Switch]$Enabled
    )
    Try
    {
      $Searcher = New-Object System.DirectoryServices.AccountManagement.PrincipalSearcher
      $UserPrincipal = New-Object System.DirectoryServices.AccountManagement.UserPrincipal($Script:LocalComputer, $UserID, $Password, $Enabled)
      if ([String]::IsNullOrEmpty($DisplayName))
      {
        $UserPrincipal.DisplayName = $UserID
      }
      else
      {
        $UserPrincipal.DisplayName = $DisplayName
      }
      $UserPrincipal.Description = $Description
      $UserPrincipal.Save()
      $UserPrincipal
    }
    Catch
    {
    }
  }
  #endregion

  #region function New-MyLocalGroup
  function New-MyLocalGroup() 
  {
    <#
      .SYNOPSIS
        Creates a New Local Group
      .DESCRIPTION
        Creates a New Local Group
      .PARAMETER GroupName
      .PARAMETER Description
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        $NewGroup = New-MyLocalGroup -GroupName "NewGroup"
      .EXAMPLE
        $NewGroup = New-MyLocalGroup -GroupName "NewGroup" -Description "Description"
      .NOTES
        Original Script By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding()]
    param (
      [Parameter(Mandatory=$True)]
      [String]$GroupName,
      [String]$Description=$Null
    )
    Try
    {
      $Searcher = New-Object System.DirectoryServices.AccountManagement.PrincipalSearcher
      $GroupPrincipal = New-Object System.DirectoryServices.AccountManagement.GroupPrincipal($Script:LocalComputer, $GroupName)
      $GroupPrincipal.Description = $Description
      $GroupPrincipal.Save()
      $GroupPrincipal
    }
    Catch
    {
    }
  }
  #endregion

  #region function Get-MyDomain
  function Get-MyDomain() 
  {
    <#
      .SYNOPSIS
        Get the Local or Remote Domain
      .DESCRIPTION
        Get the Local or Remote Domain
      .PARAMETER DomainName
      .PARAMETER UserName
      .PARAMETER Password
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        $CurrentDomain = Get-MyDomain
      .EXAMPLE
        $CurrentDomain = Get-MyDomain -DomainName "MyDomain.Local"
      .NOTES
        Original Script By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding(DefaultParameterSetName="Default")]
    param (
      [Parameter(Mandatory=$True, ParameterSetName="Default")]
      [Parameter(Mandatory=$True, ParameterSetName="AltUser")]
      [String[]]$DomainName,
      [Parameter(Mandatory=$False, ParameterSetName="AltUser")]
      [String]$UserName=$Null,
      [Parameter(Mandatory=$False, ParameterSetName="AltUser")]
      [String]$Password=$Null
    )
    Try
    {
      Switch ($PSCmdlet.ParameterSetName)
      {
        "AltUser"
        {
          $Script:LocalDomain = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $DomainName, $UserName, $Password)
          Break
        }
        "Default"
        {
          $Script:LocalDomain = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $DomainName)
          Break
        }
      }
      Return $True
    }
    Catch
    {
      Return $False
    }
  }
  #endregion

  #region function Get-MyDomainUsers
  function Get-MyDomainUsers() 
  {
    <#
      .SYNOPSIS
        Get Domain Users
      .DESCRIPTION
        Get Domain Users
      .PARAMETER UserID
      .PARAMETER FirstName
      .PARAMETER LastName
      .PARAMETER DisplayName
      .PARAMETER Description
      .PARAMETER Disabled
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        $Users = Get-MyDomainUsers -UserID "DomainUser"
      .NOTES
        Original Script By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding()]
    param (
      [String]$UserID="*",
      [String]$FirstName="*",
      [String]$LastName="*",
      [String]$DisplayName="*",
      [String]$Description="*",
      [Switch]$Disabled
    )
    Try
    {
      $Searcher = New-Object System.DirectoryServices.AccountManagement.PrincipalSearcher
      $UserPrincipal = New-Object System.DirectoryServices.AccountManagement.UserPrincipal($Script:LocalDomain)
      $UserPrincipal.SamAccountName = $UserID
      $UserPrincipal.GivenName = $FirstName
      $UserPrincipal.Surname = $LastName
      $UserPrincipal.DisplayName = $DisplayName
      $UserPrincipal.Description = $Description
      $UserPrincipal.Enabled = (-Not $Disabled)
      $Searcher.QueryFilter = $UserPrincipal
      $Searcher.FindAll()
    }
    Catch
    {
    }
  }
  #endregion

  #region function Get-MyDomainComputers
  function Get-MyDomainComputers() 
  {
    <#
      .SYNOPSIS
        Get Domain Computers
      .DESCRIPTION
        Get Domain Computers
      .PARAMETER ComputerName
      .PARAMETER Description
      .PARAMETER Disabled
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        $Computers = Get-MyDomainComputers -ComputerName "ComputerName"
      .NOTES
        Original Script By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding()]
    param (
      [String]$ComputerName="*",
      [String]$Description="*",
      [Switch]$Disabled
    )
    Try
    {
      $Searcher = New-Object System.DirectoryServices.AccountManagement.PrincipalSearcher
      $ComputerPrincipal = New-Object System.DirectoryServices.AccountManagement.ComputerPrincipal($Script:LocalDomain)
      $ComputerPrincipal.Name = $ComputerName
      $ComputerPrincipal.Description = $Description
      $ComputerPrincipal.Enabled = (-Not $Disabled)
      $Searcher.QueryFilter = $ComputerPrincipal
      $Searcher.FindAll()
    }
    Catch
    {
    }
  }
  #endregion

  #region function Get-MyDomainGroups
  function Get-MyDomainGroups() 
  {
    <#
      .SYNOPSIS
        Get Domain Groups
      .DESCRIPTION
        Get Domain Groups
      .PARAMETER GroupName
      .PARAMETER GroupScope
      .PARAMETER GroupType
      .PARAMETER Description
      .PARAMETER Disabled
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        $Groups = Get-MyDomainGroups -GroupName "GroupName" -GroupScope "Local" -GroupType "Security"
      .NOTES
        Original Script By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding()]
    param (
      [String]$GroupName="*",
      [ValidateSet("Global", "Local", "Universal")]
      [System.DirectoryServices.AccountManagement.GroupScope]$GroupScope,
      [ValidateSet("Security", "Distribution")]
      [String]$GroupType,
      [String]$Description="*"
    )
    Begin
    {
    }
    Process
    {
      $Searcher = New-Object System.DirectoryServices.AccountManagement.PrincipalSearcher
      $GroupPrincipal = New-Object System.DirectoryServices.AccountManagement.GroupPrincipal($Script:LocalDomain)
      $GroupPrincipal.SamAccountName = $GroupName
      if (-not [String]::IsNullOrEmpty($GroupScope))
      {
        $GroupPrincipal.GroupScope = $GroupScope
      }
      Switch ($GroupType)
      {
        "Security"
        {
          $GroupPrincipal.IsSecurityGroup = $True
          break
        }
        "Distribution"
        {
          $GroupPrincipal.IsSecurityGroup = $False
          break
        }
      }
      $GroupPrincipal.Description = $Description
      $Searcher.QueryFilter = $GroupPrincipal
      $Searcher.FindAll()
    }
    End
    {
    }
  }
  #endregion

  #region function Search-MyADObject
  function Search-MyADObject() {
    <#
      .SYNOPSIS
        Searches AD and returns an AD SearchResult 
      .DESCRIPTION
        Searches AD and returns an AD SearchResult
      .PARAMETER filter
        AD Search filter
      .PARAMETER SearchRoot
        Starting Search OU
      .PARAMETER SearchScope
        Search Scope
      .PARAMETER PropertiesToLoad
        Properties to load
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Search-MyADObject -LDAPFilter [<String>]
      .LINK
    #>
    [CmdletBinding(DefaultParameterSetName="ByCurrent")]
    param (
      [parameter(Mandatory=$True)]
      [String]$LDAPFilter,
      [parameter(Mandatory=$False, ParameterSetName="ByGC")]
      [switch]$UseGC,
      [parameter(Mandatory=$False, ParameterSetName="ByGC")]
      [String]$Forest=$Null,
      [parameter(Mandatory=$False, ParameterSetName="ByCurrent")]
      [String]$SearchRoot=$($([ADSI]"").distinguishedName),
      [parameter(Mandatory=$False, ParameterSetName="ByCurrent")]
      [ValidateSet("Base", "OneLevel", "Subtree")]
      [System.DirectoryServices.SearchScope]$SearchScope="SubTree",
      [String[]]$PropertiesToLoad,
      [String]$UserName=$Null,
      [String]$Password=$Null
    )
    Try
    {
      $MySearcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
      $MySearcher.PageSize = 1000
      $MySearcher.SizeLimit = 1
      $MySearcher.Filter = $LDAPFilter
      if ($UseGC)
      {
        if ([String]::IsNullOrEmpty($Forest))
        {
          $SearchRoot = $([System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest() | Select-Object -Property @{"Name"="Value";"Expression"={"GC://$($_.Name)"}}).Value
        }
        else
        {
          if ($SearchRoot.StartsWith("GC://", [System.StringComparison]::OrdinalIgnoreCase))
          {
            $SearchRoot = $SearchRoot.ToUpper()
          } 
          else 
          {
            $SearchRoot = "GC://$($SearchRoot.ToUpper())"
          }
        }
      }
      else
      {
        if ($SearchRoot.StartsWith("LDAP://", [System.StringComparison]::OrdinalIgnoreCase))
        {
          $SearchRoot = $SearchRoot.ToUpper()
        } 
        else 
        {
          $SearchRoot = "LDAP://$($SearchRoot.ToUpper())"
        }
      }
      if ([String]::IsNullOrEmpty($UserName) -or [String]::IsNullOrEmpty($Password))
      {
        $MySearcher.SearchRoot = New-Object -TypeName System.DirectoryServices.DirectoryEntry($SearchRoot)
      }
      else
      {
        $MySearcher.SearchRoot = New-Object -TypeName System.DirectoryServices.DirectoryEntry($SearchRoot, $UserName, $Password)
      }
      $MySearcher.SearchScope = $SearchScope
      if (-not [String]::IsNullOrEmpty($PropertiesToLoad))
      {
        $MySearcher.PropertiesToLoad.AddRange($PropertiesToLoad)
      }
      $MySearcher.FindOne()
    }
    Catch
    {
    }
  }
  #endregion

  #Registry Hives
  $Script:RegistryHives = @{"HKLM"=2147483650; "HKU"=2147483651}

  #region function Connect-MyRegistry
  function Connect-MyRegistry() 
  {
    <#
      .SYNOPSIS
        Connecto to Local or Remote Registry via WMI
      .DESCRIPTION
        Connecto to Local or Remote Registry via WMI
      .PARAMETER ComputerName
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Connect-MyRegistry -ComputerName 
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True, ValueFromPipeline=$True)]
      [String]$ComputerName
    )
    Begin{
    }
    Process
    {
      Try 
      {
        $Script:RegProv = [WMIClass]"\\$ComputerName\Root\Default:StdRegProv"
        Return $True
      }
      Catch 
      {
        Return $False
      }
    }
    End 
    {
    }
  }
  #endregion

  #region function Enum-MyRegKey
  function Enum-MyRegKey()
  {
    <#
      .SYNOPSIS
        Enumerate Regsitry Sub Keys
      .DESCRIPTION
        Enumerate Regsitry Sub Keys
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Enum-MyRegKey -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey
    )
    Try 
    {
      $Script:RegProv.EnumKey($Script:RegistryHives[$Hive], $RegKey) | Select-Object -Property @{Name="Values";Expression={$_.sNames}}, @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Values"=@(); "Success"=-1}
    }
  }
  #endregion

  #region function Enum-MyRegValue
  function Enum-MyRegValue()
  {
    <#
      .SYNOPSIS
        Enumerate Regsitry Key Values
      .DESCRIPTION
        Enumerate Regsitry Key Values
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Enum-MyRegValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey
    )
    Try 
    {
      $Script:RegProv.EnumValues($Script:RegistryHives[$Hive], $RegKey) | Select-Object -Property @{Name="Values";Expression={$_.sNames}}, @{Name="Types";Expression={$_.Types}}, @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Values"=@(); "Types"=@(); "Success"=-1}
    }
  }
  #endregion

  #region function Create-MyRegKey
  function Create-MyRegKey() 
  {
    <#
      .SYNOPSIS
        Creates a Registry Key
      .DESCRIPTION
        Creates a Registry Key
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Create-MyRegKey -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey
    )
    Try 
    {
      $Script:RegProv.CreateKey($Script:RegistryHives[$Hive], $RegKey) | Select-Object -Property @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Success"=-1}
    }
  }
  #endregion

  #region function Remove-MyRegKey
  function Remove-MyRegKey() 
  {
    <#
      .SYNOPSIS
        Removes a Registry Key
      .DESCRIPTION
        Removes a Registry Key
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Remove-MyRegKey -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey
    )
    Try {
      $Script:RegProv.DeleteKey($Script:RegistryHives[$Hive], $RegKey) | Select-Object -Property @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Success"=-1}
    }
  }
  #endregion

  #region function Set-MyRegBinaryValue
  function Set-MyRegBinaryValue() 
  {
    <#
      .SYNOPSIS
        Sets a Registry Binary Value
      .DESCRIPTION
        Sets a Registry Binary Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .PARAMETER Value
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Set-MyRegBinaryValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "Binary" -Value 0, 1, 2, 3
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName,
      [parameter(Mandatory=$True)]
      [AllowEmptyCollection()]
      [AllowNull()]
      [Byte[]]$Value
    )
    Try 
    {
      $Script:RegProv.SetBinaryValue($Script:RegistryHives[$Hive], $RegKey, $ValueName, $Value) | Select-Object -Property @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Success"=-1}
    }
  }
  #endregion

  #region function Set-MyRegDWORDValue
  function Set-MyRegDWORDValue() 
  {
    <#
      .SYNOPSIS
        Sets a Registry DWord Value
      .DESCRIPTION
        Sets a Registry DWord Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .PARAMETER Value
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Set-MyRegDWordValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "DWord" -Value 0
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName,
      [parameter(Mandatory=$True)]
      [Int]$Value
    )
    Try 
    {
      $Script:RegProv.SetDWORDValue($Script:RegistryHives[$Hive], $RegKey, $ValueName, $Value) | Select-Object -Property @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Success"=-1}
    }
  }
  #endregion

  #region function Set-MyRegQWORDValue
  function Set-MyRegQWORDValue() 
  {
    <#
      .SYNOPSIS
        Sets a Registry QWord Value
      .DESCRIPTION
        Sets a Registry QWord Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .PARAMETER Value
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Set-MyRegQWordValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "QWord" -Value 0
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName,
      [parameter(Mandatory=$True)]
      [Long]$Value
    )
    Try 
    {
      $Script:RegProv.SetQWORDValue($Script:RegistryHives[$Hive], $RegKey, $ValueName, $Value) | Select-Object -Property @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Success"=-1}
    }
  }
  #endregion

  #region function Set-MyRegExpandedStringValue
  function Set-MyRegExpandedStringValue() 
  {
    <#
      .SYNOPSIS
        Sets a Registry Expanded String Value
      .DESCRIPTION
        Sets a Registry Expanded String Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .PARAMETER Value
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Set-MyRegExpandedStringValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "Epanded" -Value "%UserName% on %ComputerName%"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName,
      [parameter(Mandatory=$True)]
      [AllowEmptyString()]
      [AllowNull()]
      [String]$Value
    )
    Try 
    {
      $Script:RegProv.SetExpandedStringValue($Script:RegistryHives[$Hive], $RegKey, $ValueName, $Value) | Select-Object -Property @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Success"=-1}
    }
  }
  #endregion

  #region function Set-MyRegMultiStringValue
  function Set-MyRegMultiStringValue() 
  {
    <#
      .SYNOPSIS
        Sets a Registry Multi-String Value
      .DESCRIPTION
        Sets a Registry Multi-String Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .PARAMETER Value
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Set-MyRegMultiStringValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "Multi-String" -Value "String", "String"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName,
      [parameter(Mandatory=$True)]
      [AllowEmptyCollection()]
      [AllowNull()]
      [String[]]$Value
    )
    Try 
    {
      $Script:RegProv.SetMultiStringValue($Script:RegistryHives[$Hive], $RegKey, $ValueName, $Value) | Select-Object -Property @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Success"=-1}
    }
  }
  #endregion

  #region function Set-MyRegStringValue
  function Set-MyRegStringValue()
  {
    <#
      .SYNOPSIS
        Sets a Registry String Value
      .DESCRIPTION
        Sets a Registry String Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .PARAMETER Value
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Set-MyRegStringValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "String" -Value "String"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName,
      [parameter(Mandatory=$True)]
      [AllowEmptyString()]
      [AllowNull()]
      [String]$Value
    )
    Try 
    {
      $Script:RegProv.SetStringValue($Script:RegistryHives[$Hive], $RegKey, $ValueName, $Value) | Select-Object -Property @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Success"=-1}
    }
  }
  #endregion

  #region function Get-MyRegBinaryValue
  function Get-MyRegBinaryValue() 
  {
    <#
      .SYNOPSIS
        Gets a Registry Binary Value
      .DESCRIPTION
        Gets a Registry Binary Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Get-MyRegBinaryValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "Binary"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName
    )
    Try 
    {
      $Script:RegProv.GetBinaryValue($Script:RegistryHives[$Hive], $RegKey, $ValueName) | Select-Object -Property @{Name="Value";Expression={$_.uValue}}, @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Value"=@(0); "Success"=-1}
    }
  }
  #endregion

  #region function Get-MyRegDWORDValue
  function Get-MyRegDWORDValue() 
  {
    <#
      .SYNOPSIS
        Gets a Registry DWord Value
      .DESCRIPTION
        Gets a Registry DWord Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Get-MyRegDWordValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "DWord"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName
    )
    Try 
    {
      $Script:RegProv.GetDWORDValue($Script:RegistryHives[$Hive], $RegKey, $ValueName) | Select-Object -Property @{Name="Value";Expression={$_.uValue}}, @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Value"=0; "Success"=-1}
    }
  }
  #endregion

  #region function Get-MyRegQWORDValue
  function Get-MyRegQWORDValue() 
  {
    <#
      .SYNOPSIS
        Gets a Registry QWord Value
      .DESCRIPTION
        Gets a Registry QWord Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Get-MyRegQWordValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "QWord"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName
    )
    Try 
    {
      $Script:RegProv.GetQWORDValue($Script:RegistryHives[$Hive], $RegKey, $ValueName) | Select-Object -Property @{Name="Value";Expression={$_.uValue}}, @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Value"=0; "Success"=-1}
    }
  }
  #endregion

  #region function Get-MyRegExpandedStringValue
  function Get-MyRegExpandedStringValue() {
    <#
      .SYNOPSIS
        Gets a Registry Expanded String Value
      .DESCRIPTION
        Gets a Registry Expanded String Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Get-MyRegExpandedStringValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "Expanded"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName
    )
    Try 
    {
      $Script:RegProv.GetExpandedStringValue($Script:RegistryHives[$Hive], $RegKey, $ValueName) | Select-Object -Property @{Name="Value";Expression={$_.sValue}}, @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Value"=""; "Success"=-1}
    }
  }
  #endregion

  #region function Get-MyRegMultiStringValue
  function Get-MyRegMultiStringValue() 
  {
    <#
      .SYNOPSIS
        Gets a Registry Multi-String Value
      .DESCRIPTION
        Gets a Registry Multi-String Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Get-MyRegMultiStringValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "Multi-String"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName
    )
    Try 
    {
      $Script:RegProv.GetMultiStringValue($Script:RegistryHives[$Hive], $RegKey, $ValueName) | Select-Object -Property @{Name="Value";Expression={$_.sValue}}, @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Value"=@(""); "Success"=-1}
    }
  }
  #endregion

  #region function Get-MyRegStringValue
  function Get-MyRegStringValue() 
  {
    <#
      .SYNOPSIS
        Gets a Registry String Value
      .DESCRIPTION
        Gets a Registry String Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Get-MyRegStringValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "String"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$False)]
      [String]$ValueName
    )
    Try 
    {
      $Script:RegProv.GetStringValue($Script:RegistryHives[$Hive], $RegKey, $ValueName) | Select-Object -Property @{Name="Value";Expression={$_.sValue}}, @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Value"=""; "Success"=-1}
    }
  }
  #endregion

  #region function Remove-MyRegistryValue
  function Remove-MyRegistryValue()
  {
    <#
      .SYNOPSIS
        Removes a Registry Value
      .DESCRIPTION
        Removes a Registry Value
      .PARAMETER RegProv
      .PARAMETER Hive
      .PARAMETER RegKey
      .PARAMETER ValueName
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Remove-MyRegistryValue -RegProv $Script:RegProv -Hive "HKLM" -RegKey "Software\MyTestKey" -ValueName "Test"
      .NOTES
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [ValidateSet("HKLM", "HKU")]
      [String]$Hive,
      [parameter(Mandatory=$True)]
      [String]$RegKey,
      [parameter(Mandatory=$True)]
      [String]$ValueName
    )
    Try 
    {
      $Script:RegProv.DeleteValue($Script:RegistryHives[$Hive], $RegKey, $ValueName) | Select-Object -Property @{Name="Success";Expression={$_.ReturnValue}}
    }
    Catch 
    {
      New-Object -TypeName PSObject -Property @{"Success"=-1}
    }
  }
  #endregion

  #region function Get-MyNetworkSettings
  function Get-MyNetworkSettings()
  {
    <#
      .SYNOPSIS
        Command to do something specific
      .DESCRIPTION
        Command to do something specific
      .PARAMETER Value
        Value Command Line Parameter
      .INPUTS
        What type of input does the command accepts
      .OUTPUTS
        What type of data does the command output
      .EXAMPLE
        Get-MyNetworkSettings -Value "String"
      .EXAMPLE
        $Value | Get-MyNetworkSettings
      .NOTES
        Original Script By Ken Sweet
      .LINK
    #>
    [CmdletBinding(DefaultParameterSetName="ByValue")]
    param (
      [parameter(Mandatory=$False, ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True, HelpMessage="Enter Value", ParameterSetName="ByValue")]
      [String[]]$ComputerName = [System.Environment]::MachineName
    )
    Begin
    {
      Write-Verbose -Message "Start Get-MyNetworkSettings Function Begin Block"
     
      $HKLM = 2147483650
      $RegKey = "System\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}"
      $Duplex = @{"DS0" = "Auto Detect";
                  "DS1" = "10Mbps / Half Duplex";
                  "DS2" = "10Mbps / Full Duplex";
                  "DS3" = "100Mbps / Half Duplex";
                  "DS4" = "100Mbps / Full Duplex";
                  "DS5" = "1000Mbps / Auto Detect"}
      $Media = @{"PM0" = "Unspecified";
                 "PM9" = "Wireless";
                 "PM14" = "Ethernet"}
   
      Write-Verbose -Message "Finish Get-MyNetworkSettings Function Begin Block"
    }
    Process
    {
      Write-Verbose -Message "Start Get-MyNetworkSettings Function Process Block"
     
      ForEach ($Computer in $ComputerName)
      {
        Try
        {
          $StdRegProv = [WMIClass]"\\$Computer\Root\Default:StdRegProv"
          $NetworkAdapterConfigurations = @(Get-WmiObject -ComputerName $Computer -Query "Select * From Win32_NetworkAdapterConfiguration Where IPEnabled = $True")
          if ($NetworkAdapterConfigurations.Count)
          {
            ForEach ($Config in $NetworkAdapterConfigurations)
            {
              $SubKey = "$RegKey\$(($$ = $Config.Caption.Split(@("[", "]"), [System.StringSplitOptions]::RemoveEmptyEntries)[0]).Substring(($$.Length) - 4, 4))"
              Try
              {
                $PM = "PM$(($StdRegProv.GetDwordValue($HKLM, $SubKey, "*PhysicalMediaType").uValue).ToString())"
              }
              Catch
              {
                $PM = "PM"
              }
              Try
              {
                $DS = "DS$($StdRegProv.GetStringValue($HKLM, $SubKey, "*SpeedDuplex").sValue)"
              }
              Catch
              {
                $DS = "DS"
              }
              Try
              {
                $DV = $StdRegProv.GetStringValue($HKLM, $SubKey, "DriverVersion").sValue
              }
              Catch
              {
                $DV = "Unknown"
              }
              $NetworkAdapter = $Config.GetRelated("Win32_NetworkAdapter")
              [PSCustomObject][Ordered]@{"Name" = $NetworkAdapter.Name;
                                         "AdapterType" = $NetworkAdapter.AdapterType;
                                         "DriverVersion" = $DV;
                                         "MACAddress" = $NetworkAdapter.MACAddress;
                                         "NetConnectionID" = $NetworkAdapter.NetConnectionID;
                                         "NetConnectionStatus" = $NetworkAdapter.NetConnectionStatus;
                                         "NetEnabled" = $NetworkAdapter.NetEnabled;
                                         "PhysicalMediaType" = $(if ($Media.Contains($PM)) { $Media[$PM] } else { "Unknown" });
                                         "ServiceName" = $NetworkAdapter.ServiceName;
                                         "Speed" = $NetworkAdapter.Speed;
                                         "SpeedDuplex" = $(if ($Duplex.Contains($DS)) { $Duplex[$DS] } else { "Unknown" });
                                         "Computer" = $Computer}
            }
          }
        }
        Catch
        {
        }
        $Config = $Null
        $NetworkAdapterConfigurations = $Null
        $NetworkAdapter = $Null
        $PM = $Null
        $DS = $Null
        $DVS = $Null
        $StdRegProv = $Null
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
      }
     
      Write-Verbose -Message "Finish Get-MyNetworkSettings Function Process Block"
    }
    End
    {
      Write-Verbose -Message "Start Get-MyNetworkSettings Function End Block"
     
      $HKLM = $Null
      $RegKey = $Null
      $Duplex = $Null
      $Media = $Null
     
      [System.GC]::Collect()
      [System.GC]::WaitForPendingFinalizers()
     
      Write-Verbose -Message "Finish Get-MyNetworkSettings Function End Block"
    }
  }
  #endregion

  #region function Get-MyComputer
  function Get-MyComputer()
  {
    <#
      .SYNOPSIS
        Searches AD and returns an AD SearchResult 
      .DESCRIPTION
        Searches AD and returns an AD SearchResult
      .PARAMETER filter
        AD Search filter
      .PARAMETER SearchRoot
        Starting Search OU
      .PARAMETER SearchScope
        Search Scope
      .PARAMETER PropertiesToLoad
        Properties to load
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Search-MyADObject -LDAPFilter [<String>]
      .LINK
    #>
    [CmdletBinding(DefaultParameterSetName="ByCurrent")]
    param (
      [parameter(Mandatory=$True)]
      [String]$ComputerName,
      [parameter(Mandatory=$False, ParameterSetName="ByGC")]
      [switch]$UseGC,
      [parameter(Mandatory=$False, ParameterSetName="ByGC")]
      [String]$Forest=$Null,
      [parameter(Mandatory=$False, ParameterSetName="ByCurrent")]
      [String]$SearchRoot=$($([ADSI]"").distinguishedName),
      [parameter(Mandatory=$False, ParameterSetName="ByCurrent")]
      [ValidateSet("Base", "OneLevel", "Subtree")]
      [System.DirectoryServices.SearchScope]$SearchScope="SubTree",
      [String[]]$PropertiesToLoad
    )
    $Params = $PSCmdlet.MyInvocation.BoundParameters
    [Void]$Params.Remove("ComputerName")
    Search-MyADObject -LDAPFilter "(&(objectClass=user)(objectCategory=computer)(samaccounttype=805306369)(name=$ComputerName))" @Params
  }
  #endregion

  #region function Get-MyWMIObject
  function Get-MyWMIObject() 
  {
    <#
      .SYNOPSIS
        Get-WmiObject as Job
      .DESCRIPTION
        Get-WmiObject as Job
      .PARAMETER Computer
      .PARAMETER Class
      .PARAMETER Query
      .PARAMETER List
      .PARAMETER ListNS
      .PARAMETER Wait
      .INPUTS
      .OUTPUTS
        System.Management.ManagementObject
      .EXAMPLE
        Get-MyWMIObject
      .NOTES
        By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding(DefaultParameterSetName="ByClass")]
    param (
      [String]$ComputerName=[System.Environment]::MachineName,
      [String]$NameSpace="Root\CimV2",
      [parameter(Mandatory=$True, ParameterSetName="ByClass")]
      [String]$Class,
      [parameter(Mandatory=$True, ParameterSetName="ByQuery")]
      [String]$Query,
      [parameter(Mandatory=$True, ParameterSetName="ByList")]
      [switch]$List,
      [parameter(Mandatory=$True, ParameterSetName="ByListNS")]
      [switch]$ListNS,
      [int]$Wait=120
    )
    Try 
    {
      switch ($PSCmdlet.ParameterSetName)
      {
        "ByClass"
        {
          $TempJob = Start-Job -Name $ComputerName -ScriptBlock $([ScriptBlock]::Create("Get-WmiObject -NameSpace $NameSpace -Class $Class -ComputerName '$ComputerName'"))
          break
        }
        "ByQuery"
        {
          $TempJob = Start-Job -Name $ComputerName -ScriptBlock $([ScriptBlock]::Create("Get-WmiObject -NameSpace $NameSpace -Query $Query -ComputerName '$ComputerName'"))
          break
        }
        "ByList"
        {
          $TempJob = Start-Job -Name $ComputerName -ScriptBlock $([ScriptBlock]::Create("Get-WmiObject -NameSpace $NameSpace -List -ComputerName '$ComputerName'"))
          break
        }
        "ByListNS"
        {
          $TempJob = Start-Job -Name $ComputerName -ScriptBlock $([ScriptBlock]::Create("Get-WmiObject -NameSpace $NameSpace -Class '__NameSpace' -ComputerName '$ComputerName'"))
          break
        }
      }
      $DoneJob = $TempJob | Wait-Job -Timeout $Wait
      if ($DoneJob) 
      {
        $TempJob | Receive-Job -Wait -AutoRemoveJob
      } 
      else 
      {
        $TempJob.StopJob()
      }
      Try
      {
        $TempJob.Dispose()
      }
      Catch
      {
      }
      $TempJob = $Null
      [System.GC]::Collect()
      [System.GC]::WaitForPendingFinalizers()
    }
    Catch 
    {
    }
  }
  #endregion

  #region function Check-WMIWorking
  function Check-WMIWorking () {
    <#
      .SYNOPSIS
        Test if current user is an Administrator
      .DESCRIPTION
        Test if current user is an Administrator
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Test-IsAdmin
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$False)]
      [string]$ComputerName=[System.Environment]::MachineName
    )
    Try
    {
      $WMIWorking = $(![String]::IsNullOrEmpty(($ComputerSystem = Get-MyWMIObject -ComputerName $ComputerName -Class "Win32_ComputerSystem")))
      if ($WMIWorking)
      {
        $WMIWorking = $($(![String]::IsNullOrEmpty(($OperatingSystem = Get-MyWMIObject -ComputerName $ComputerName -Class "Win32_OperatingSystem"))) -and $WMIWorking)
      }
      New-Object -TypeName PSObject -Property @{"Working"=$WMIWorking; "ComputerSystem"=$ComputerSystem; "OperatingSystem"=$OperatingSystem}
    }
    Catch
    {
      New-Object -TypeName PSObject -Property @{"Working"=$False; "ComputerSystem"=""; "OperatingSystem"=""}
    }
    $WMIWorking = $Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
  }
  #endregion

  #region function Do-MyWork
  function Do-MyWork() 
  {
    <#
      .SYNOPSIS
        Command to do something specific
      .DESCRIPTION
        Command to do something specific
      .PARAMETER ComputerName
        Value Command Line Parameter
      .INPUTS
      .OUTPUTS
      .EXAMPLE
        Do-MyWork -ComputerName "String"
      .NOTES
        Original Script By Kenneth D. Sweet
      .LINK
    #>
    [CmdletBinding()]
    param (
      [parameter(Mandatory=$True)]
      [String]$ComputerName,
      [String]$IPAddress,
      [String]$OperatingSystem,
      [String]$ServicePack,
      [String]$Architecture
    )
    Write-Verbose -Message "Start Do-MyWork Function"

    Try
    {
#CodeBlock#      
      New-Object -TypeName PSObject -Property @{"JobStatus"=$JobStatus; "Simon"=$Simon; "Garfunkel"=$Garfunkel; "Parsley"=$Parsley; "Sage"=$Sage; "Rosemary"=$Rosemary; "ErrorMessage"=""}
    }
    Catch
    {
      New-Object -TypeName PSObject -Property @{"JobStatus"="Error - Do-MyWork"; "Simon"=""; "Garfunkel"=""; "Parsley"=""; "Sage"=""; "Rosemary"=""; "ErrorMessage"=$Error[0].ToString()}
    }
    $JobStatus = $Null
    $Parsley = $Null
    $Sage = $Null
    $Rosemary = $Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Write-Verbose -Message "Finish Do-MyWork Function"
  }
  #endregion
  
  Try
  {
    $Error.Clear()
    # Clear Previous Result Messages
    ForEach ($Count in 1..18)
    {
      $Item.SubItems[$Count].Text = ""
    }
    # Flag Current Line
    $Item.SubItems[10].Text = "Processing..."

    Try
    {
      if ([String]::IsNullOrEmpty(($DNSEntries = [System.Net.Dns]::GetHostAddresses($Item.SubItems[0].Text) | Where-Object -FilterScript { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork })))
      {
        $Item.SubItems[2].Text = "Unknown"
        $Item.SubItems[10].Text = "Off Line"
      }
      else
      {
        ForEach ($DNSEntry in $DNSEntries)
        {
          # Set IP Address
          $Item.SubItems[2].Text = $DNSEntry.IPAddressToString
          
          # Check if Workstation is On-Line
          if (Test-Connection -Count 2 -Quiet -ComputerName $Item.SubItems[2].Text)
          {
            # Set On-Line Status to Yes
            $Item.SubItems[1].Text = "Yes"
            $WMIWorking = Check-WMIWorking -ComputerName $DNSEntry.ToString()
            if ($WMIWorking.Working)
            {
              # Set WMI Working to Good
              $Item.SubItems[3].Text = "Good"
              $Item.SubItems[18].Text = ""
              
              # Set Returned WMI Name and User Name
              $Item.SubItems[4].Text = "DCOM"
              $Item.SubItems[5].Text = "$($WMIWorking.ComputerSystem.Name)".ToUpper()
              $Item.SubItems[6].Text = "$($WMIWorking.ComputerSystem.UserName)".ToUpper()
              
              if ($WMIWorking.ComputerSystem.Name -eq ($Item.SubItems[0].Text).Split(".")[0])
              {
                # Set Returned Operating System and Service Pack
                $Item.SubItems[7].Text = $WMIWorking.OperatingSystem.Caption
                #$Item.SubItems[8].Text = $WMIWorking.OperatingSystem.CSDVersion
                $Item.SubItems[8].Text = $WMIWorking.OperatingSystem.BuildNumber
                Try
                {
                  $Item.SubItems[9].Text = $WMIWorking.OperatingSystem.OSArchitecture
                  if ([String]::IsNullOrEmpty($Item.SubItems[9].Text))
                  {
                    $Item.SubItems[9].Text = "32-bit"
                  }
                }
                Catch
                {
                  $Item.SubItems[9].Text = "32-bit"
                }
                
                if ($ThreadCommand.Kill)
                {
                  $Item.SubItems[10].Text = "Terminated"
                  Return
                }

                $MyReturn = Do-MyWork -ComputerName "$($Item.SubItems[0].Text)" -IPAddress "$($Item.SubItems[2].Text)" -OperatingSystem "$($Item.SubItems[7].Text)" -ServicePack "$($Item.SubItems[8].Text)" -Architecture "$($Item.SubItems[9].Text)"
                $Item.SubItems[10].Text = $MyReturn.JobStatus
                $Item.SubItems[11].Text = $MyReturn.Simon
                $Item.SubItems[12].Text = $MyReturn.Garfunkel
                $Item.SubItems[13].Text = $MyReturn.Parsley
                $Item.SubItems[14].Text = $MyReturn.Sage
                $Item.SubItems[15].Text = $MyReturn.Rosemary
                $Item.SubItems[18].Text = $MyReturn.ErrorMessage

                # Set Completed Date & Time
                $Item.SubItems[16].Text = [DateTime]::Now.ToShortTimeString()
                $Item.SubItems[17].Text = [DateTime]::Now.ToShortDateString()
                
                Break
              }
              else
              {
                $Item.SubItems[10].Text = "Wrong Workstation"
              }
            }
            else
            {
              # Set WMI Working to Bad
              $Item.SubItems[3].Text = "Bad"
              $Item.SubItems[18].Text = $Error[0].ToString()
              $Item.SubItems[10].Text = "Broken WMI"
            }
          }
          else
          {
            # Set On-Line Status to No
            $Item.SubItems[1].Text = "No"
            $Item.SubItems[10].Text = "Off Line"
          }
        }
      }
    }
    Catch
    {
      $Item.SubItems[10].Text = "DNS Error"
    }
  }
  Catch
  {
    # Set Error Message Text
    $Item.SubItems[18].Text = $Error[0].ToString()
    $Item.SubItems[10].Text = "Error - Catch"
  }
  # Clear Current Line
  if ($Item.SubItems[10].Text -eq "Processing...")
  {
    $Item.SubItems[10].Text = "Error - Unknown"
  }
  $WMIWorking = $Null
  $Count = $Null
  $Item = $Null
  $DNSEntries = $Null
  $DNSEntry = $Null
  $MyReturn = $Null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
'@
#endregion

#region ******** $Script:CodeBlock ScriptBlock ********
$Script:CodeBlock = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

$Simon = ""
$Garfunkel = ""
$Parsley = ""
$Sage = ""
$Rosemary = ""

$JobStatus = "Done"
'@
#endregion

#region ******** Sample Thread Scripts ********

#region ******** $Script:Blank ********
$Script:Blank = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

$Simon = ""
$Garfunkel = ""
$Parsley = ""
$Sage = ""
$Rosemary = ""

$JobStatus = "Done"
'@
#endregion

#region ******** $Script:DriveInfo ********
$Script:DriveInfo = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

$Data = Get-WmiObject -ComputerName $ComputerName -Class Win32_LogicalDisk -Filter "DeviceID = 'C:'"

$Simon = $Data.DeviceID
$Garfunkel = $Data.Size
$Parsley = $Data.FreeSpace
$Sage = [Math]::Round(($Data.FreeSpace / $Data.Size) * 100, 2)
$Rosemary = $Data.FileSystem

$JobStatus = "Done"
'@
#endregion

#region ******** $Script:ADInfo ********
$Script:ADInfo = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

# Get-MyComputer -ComputerName <String> [-SearchRoot <String>] [-SearchScope {Base | OneLevel | Subtree}] [-PropertiesToLoad <String[]>]
# Get-MyComputer -ComputerName <String> [-UseGC] [-Forest <String>] [-PropertiesToLoad <String[]>]

$Computer = Get-MyComputer -ComputerName $ComputerName -PropertiesToLoad "operatingsystem", "operatingsystemservicepack","pwdlastset", "whencreated", "whenchanged"

$Simon = $Computer.Properties["operatingsystem"][0]
$Garfunkel = $Computer.Properties["operatingsystemservicepack"][0]
$Parsley = [DateTime]::FromFileTime($Computer.Properties["pwdlastset"][0])
$Sage = $Computer.Properties["whencreated"][0]
$Rosemary = $Computer.Properties["whenchanged"][0]

$JobStatus = "Done"
'@
#endregion

#region ******** $Script:FileInfo ********
$Script:FileInfo = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

Switch ($OperatingSystem)
{
  {$_.Contains("Windows 7") -or $_.Contains("Windows 8")}
  {
    if ($Architecture -eq "32-Bit")
    {
      $FilePath = "\\$ComputerName\C`$\Windows\explorer.exe"
    }
    else
    {
      $FilePath = "\\$ComputerName\C`$\Windows\explorer.exe"
    }
    break
  }
  {$_.Contains("Windows XP")}
  {
    $FilePath = "\\$ComputerName\C`$\Windows\explorer.exe"
    break
  }
}
if ([System.IO.File]::Exists($FilePath))
{
  $FileInfo = New-Object -TypeName System.IO.FileInfo($FilePath)
  $Simon = $FileInfo.VersionInfo.ProductVersion
  $Garfunkel = $FileInfo.CreationTime
  $Parsley = $FileInfo.Length
  $Sage = $FileInfo.VersionInfo.FileDescription
  $Rosemary = $FileInfo.Attributes.ToString()
  $JobStatus = "Done"
}
else
{
  $Simon = "Missing"
  $Garfunkel = ""
  $Parsley = ""
  $Sage = ""
  $Rosemary = ""
  $JobStatus = "Missing"
}
'@
#endregion

#region ******** $Script:Execute ********
$Script:Execute = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

Switch ($OperatingSystem)
{
  {$_.Contains("Windows 7") -or $_.Contains("Windows 8")}
  {
    if ($Architecture -eq "32-Bit")
    {
      $RemoteCommand = "C:\windows\System32\cmd.exe /c echo %Time%>C:\Time.txt"
    }
    else
    {
      $RemoteCommand = "C:\windows\System32\cmd.exe /c echo %Time%>C:\Time.txt"
    }
    break
  }
  {$_.Contains("Windows XP")}
  {
    $RemoteCommand = "C:\windows\System32\cmd.exe /c echo %Time%>C:\Time.txt"
    break
  }
}
$Processes = [WMIClass]"\\$ComputerName\root\CimV2:Win32_Process"
$Result = $Processes.Create($RemoteCommand)
$Simon = $Result.ReturnValue
$Garfunkel = $Result.ProcessId
$Parsley = ""
$Sage = ""
$Rosemary = ""
if ($Result.ReturnValue -eq 0)
{
  $JobStatus = "Done"
}
else
{
  $JobStatus = "Error"
}
'@
#endregion

#region ******** $Script:StartStopService ********
$Script:StartStopService = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

$Service = "CCMEXEC"

$MyService = Get-Service -computer $ComputerName -Name $Service
if ($MyService.Status.ToString() -eq "Running")
{
  $MyService.Stop()
  $Count = 0
  While (($MyService.Status.ToString() -ne "Stopped") -and ($Count -le 120))
  {
    [System.Threading.Thread]::Sleep(500)
    $MyService.Refresh()
    $Count+= 1
  }
}
if ($MyService.Status.ToString() -eq "Stopped")
{
  $MyService.Start()
  $Count = 0
  While (($MyService.Status.ToString() -ne "Running") -and ($Count -le 120))
  {
    [System.Threading.Thread]::Sleep(500)
    $MyService.Refresh()
    $Count+= 1
  }
}
$MyService.Refresh()
$Simon = $MyService.Status.ToString()
$Garfunkel = ""
$Parsley = ""
$Sage = ""
$Rosemary = ""
if ($MyService.Status.ToString() -eq "Running")
{
  $JobStatus = "Done"
}
else
{
  $JobStatus = "Wrong"
}
'@
#endregion

#region ******** $Script:SCCMClientPolicy ********
$Script:SCCMClientPolicy = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

#  Hardware Inventory={00000000-0000-0000-0000-000000000001}
#  Software Inventory={00000000-0000-0000-0000-000000000002}
#  Data Discovery={00000000-0000-0000-0000-000000000003}
#  Machine Policy Assignment Request={00000000-0000-0000-0000-000000000021}
#  Machine Policy Evaluation={00000000-0000-0000-0000-000000000022}
#  Refresh Default Management Point={00000000-0000-0000-0000-000000000023}
#  Refresh Location (AD site or Subnet)={00000000-0000-0000-0000-000000000024}
#  Software Metering Usage Reporting={00000000-0000-0000-0000-000000000031}
#  Sourcelist Update Cycle={00000000-0000-0000-0000-000000000032}
#  Cleanup policy={00000000-0000-0000-0000-000000000040}
#  Validate assignments={00000000-0000-0000-0000-000000000042}
#  Certificate Maintenance={00000000-0000-0000-0000-000000000051}
#  Branch DP Scheduled Maintenance={00000000-0000-0000-0000-000000000061}
#  Branch DP Provisioning Status Reporting={00000000-0000-0000-0000-000000000062}
#  Refresh proxy management point={00000000-0000-0000-0000-000000000037}
#  Software Update Deployment={00000000-0000-0000-0000-000000000108}
#  Software Update Scan={00000000-0000-0000-0000-000000000113}
#  Software Update Deployment Re-eval={00000000-0000-0000-0000-000000000114}
#  State Message Upload={00000000-0000-0000-0000-000000000111}
#  State Message Cache Cleanup={00000000-0000-0000-0000-000000000112}

$PolicyID = "{00000000-0000-0000-0000-000000000003}"

$([WMIClass]"\\$ComputerName\Root\CCM:SMS_Client").TriggerSchedule($PolicyID)

$Simon = ""
$Garfunkel = ""
$Parsley = ""
$Sage = ""
$Rosemary = ""
$JobStatus = "Done"
'@
#endregion

#region ******** $Script:SCCMClientInCache ********
$Script:SCCMClientInCache = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

# Sample Code by Matt A.

$PackageID = "Package / Content ID"
$Version = "Version"


# Check if Package is in Cache
$Packages = Get-WmiObject -ComputerName $ComputerName -NameSpace "Root\CCM\SoftMgmtAgent" -Query "Select * from CacheInfoEx Where ContentID = '$PackageID' And ContentVer = '$Version'"
if ($Packages)
{
  ForEach ($Package in $Packages)
  {
    $Simon = $Package.ContentType
    $Garfunkel = $Package.ConvertToDateTime($Package.LastReferenced)
    $Parsley = ("{0:F1} KB" -f ($Package.ContentSize / 1024))
    $Sage = $Package.Location
    $Rosemary = $Package.PersistInCache
    $JobStatus = "Done"
  }
}
Else
{
  # Check if Package is downloading
  $Downloads = Get-WmiObject -ComputerName $ComputerName -NameSpace "Root\CCM\ContentTransferManager" -Query "Select * from CCM_CTM_JobStateEx4 Where ContentID = '$PackageID' and ContentVersion = '$Version'"
  If ($Downloads)
  {
    ForEach ($Download in $Downloads)
    {
      $Simon = $Download.ConvertToDateTime($Download.CreationTime)
      $Garfunkel = $Download.ConvertToDateTime($Download.LastProgressTime)
      $Parsley = ("{0:F1} KB" -f ($Download.KBytesTransferred / 1024))
      $Sage = $Download.DestinationPath
      $Rosemary = $Download.SourceURL
      $JobStatus = "Downloading"
    }
  }
  Else
  {
    # Check if Package is in Software Center
    $RAP = Get-WmiObject -ComputerName $ComputerName -NameSpace "Root\CCM\Policy\Machine\RequestedConfig" -Query "Select * from CCM_SoftwareDistribution Where PKG_PackageID = '$PackageID' AND PKG_SourceVersion = '$Version'"
    if ($RAP)
    {
      ForEach ($Item in $RAP)
      {
        $Simon = $Item.ADV_AdvertisementID
        $Garfunkel = $Item.PKG_PackageID
        $Parsley = $Item.PRG_ProgramID
        $Sage = $Item.ADV_RepeatRunBehavior
        $Rosemary = $Item.ADV_MandatoryAssignments
        $JobStatus = "Software Center"
      }
    }
    else
    {
      $Simon = ""
      $Garfunkel = ""
      $Parsley = ""
      $Sage = ""
      $Rosemary = ""
      $JobStatus = "Not Found"
    }
  }
}
'@
#endregion

#region ******** $Script:SCCMClientAdvert ********
$Script:SCCMClientAdvert = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

$AdvertisementID = "ABC00001"

$RAP = Get-WmiObject -ComputerName $ComputerName -NameSpace "Root\CCM\Policy\Machine\RequestedConfig" -Query "Select * from CCM_SoftwareDistribution Where ADV_AdvertisementID = '$AdvertisementID'"
if ($RAP)
{
  ForEach ($Item in $RAP)
  {
    $Simon = $Item.ADV_AdvertisementID
    $Garfunkel = $Item.PKG_PackageID
    $Parsley = $Item.PRG_ProgramID
    $Sage = $Item.ADV_RepeatRunBehavior
    $Rosemary = $Item.ADV_MandatoryAssignments
    $JobStatus = "Done"
  }
}
else
{
  $Simon = ""
  $Garfunkel = ""
  $Parsley = ""
  $Sage = ""
  $Rosemary = ""
  $JobStatus = "None"
}
'@
#endregion

#region ******** $Script:Registry ********
$Script:Registry = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

#  Connect-MyRegistry [-ComputerName] <String>
#
#  Create-MyRegKey [-Hive] <String> [-RegKey] <String>
#  Remove-MyRegKey [-Hive] <String> [-RegKey] <String>
#
#  Get-MyRegBinaryValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>]
#  Get-MyRegDWORDValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>] [<CommonParameters>]
#  Get-MyRegExpandedStringValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>]
#  Get-MyRegMultiStringValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>]
#  Get-MyRegQWORDValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>]
#  Get-MyRegStringValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>]
#
#  Set-MyRegBinaryValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>] [-Value] <Byte[]>
#  Set-MyRegDWORDValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>] [-Value] <Int32>
#  Set-MyRegExpandedStringValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>] [-Value] <String>
#  Set-MyRegMultiStringValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>] [-Value] <String[]>
#  Set-MyRegQWORDValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>] [-Value] <Int64>
#  Set-MyRegStringValue [-Hive] <String> [-RegKey] <String> [[-ValueName] <String>] [-Value] <String>
#
#  Remove-MyRegistryValue [-Hive] <String> [-RegKey] <String> [-ValueName] <String>
#
#
#  For use with Enum-MyRegValue So you can tell What Datatype each value is
#
#  Enum-MyRegKey [-Hive] <String> [-RegKey] <String>
#
#  $ReturnedData = Enum-MyRegKey -Hive "HKLM" -RegKey "Software"
#  if ($ReturnedData.Success -eq 0)
#  {
#    ForEach ($Value in $ReturnedData.Values)
#    {
#      $Temp = $Value
#    }
#  }
#
#  Enum-MyRegValue [-Hive] <String> [-RegKey] <String>
#
#  $ReturnedData = Enum-MyRegValue -Hive "HKLM" -RegKey "Software"
#  if ($ReturnedData.Success -eq 0)
#  {
#    $MaxValues = @($ReturnedData.Values).Count
#    For ($Index=0; $Index -lt $MaxValues; $Index++)
#    {
#      Switch ($ReturnedData.Types($Index))
#      {
#        1
#        {
#          # REG_SZ
#          $Temp = $ReturnedData.Values($Index)
#          Break
#        }
#        2
#        {
#          # REG_EXPAND_SZ
#          $Temp = $ReturnedData.Values($Index)
#          Break
#        }
#        3
#        {
#          # REG_BINARY
#          $Temp = $ReturnedData.Values($Index)
#          Break
#        }
#        4
#        {
#          # REG_DWORD
#          $Temp = $ReturnedData.Values($Index)
#          Break
#        }
#        7
#        {
#          # REG_MULTI_SZ
#          $Temp = $ReturnedData.Values($Index)
#          Break
#        }
#        11
#        {
#          # REG_QWORD
#          $Temp = $ReturnedData.Values($Index)
#          Break
#        }
#      }
#    }
#  }

# Set Registry Keys You want to return values from
if ($Architecture -eq "64-Bit")
{
  $RegistryKey01 = "SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion"
}
else
{
  $RegistryKey01 = "SOFTWARE\Microsoft\Windows NT\CurrentVersion"
}
$RegistryKey02 = ".DEFAULT\Control Panel\Colors"

# Have to make sure you can Connect to the Remote Registry
if (Connect-MyRegistry -ComputerName $ComputerName)
{
  $ReturnedRegValue = Get-MyRegStringValue -Hive "HKLM" -RegKey $RegistryKey01 -ValueName "RegisteredOrganization"
  if ($ReturnedRegValue.Success -eq 0)
  {
    $Simon = $ReturnedRegValue.Value
  }
  else
  {
    $Simon = "ERROR: $($ReturnedRegValue.Success)"
  }
  $ReturnedRegValue = Get-MyRegStringValue -Hive "HKLM" -RegKey $RegistryKey01 -ValueName "RegisteredOwner"
  if ($ReturnedRegValue.Success -eq 0)
  {
    $Garfunkel = $ReturnedRegValue.Value
  }
  else
  {
    $Garfunkel = "ERROR: $($ReturnedRegValue.Success)"
  }

  $Parsley = ""

  $ReturnedRegValue = Get-MyRegStringValue -Hive "HKU" -RegKey $RegistryKey02 -ValueName "WindowFrame"
  if ($ReturnedRegValue.Success -eq 0)
  {
    $Sage = $ReturnedRegValue.Value
  }
  else
  {
    $Sage = "ERROR: $($ReturnedRegValue.Success)"
  }
  $ReturnedRegValue = Get-MyRegStringValue -Hive "HKU" -RegKey $RegistryKey02 -ValueName "InactiveTitle"
  if ($ReturnedRegValue.Success -eq 0)
  {
    $Rosemary = $ReturnedRegValue.Value
  }
  else
  {
    $Rosemary = "ERROR: $($ReturnedRegValue.Success)"
  }
  $JobStatus = "Done"
}
else
{
  $Simon = ""
  $Garfunkel = ""
  $Parsley = ""
  $Sage = ""
  $JobStatus = "Unknown"
}
'@
#endregion

#region ******** $Script:LocalUsers ********
$Script:LocalUsers = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

If (Get-MyLocalComputer -ComputerName $ComputerName)
{
  $LocalGroup = Get-MyLocalGroups -GroupName "Administrators"
  if ($LocalGroup)
  {
    $Simon = $LocalGroup.Name
    $Garfunkel = $LocalGroup.Description
    $Parsley = ($LocalGroup.Members | Select-Object -ExpandProperty Name) -Join ","
    $Sage = $LocalGroup.GroupScope
    $Rosemary = $LocalGroup.IsSecurityGroup
    $JobStatus = "Done"
  }
  else
  {
    $Simon = ""
    $Garfunkel = ""
    $Parsley = ""
    $Sage = ""
    $Rosemary = ""
    $JobStatus = "No Group"
  }
}
else
{
    $Simon = ""
    $Garfunkel = ""
    $Parsley = ""
    $Sage = ""
    $Rosemary = ""
    $JobStatus = "Connect Error"
}

#
#  # Get Local Computer
#  If (Get-MyLocalComputer -ComputerName $ComputerName)
#  {
#    # Create and Return New Local User
#    $NewLocalUser = New-MyLocalUser -UserID "NewLocalUser" -Password "!2MyPassword2!" -Enabled
#
#    # Create and Return New Local Group
#    $NewLocalGroup = New-MyLocalGroup -GroupName "New Local Group"
#
#    # Return Local User
#    $LocalUser = Get-MyLocalUsers -UserID "NewLocalUser"
#
#    # Return Local Group
#    $LocalGroup = Get-MyLocalGroups -GroupName "New Local Group"
#
#    # Add Local User to Local Group
#    $LocalGroup.Members.Add($LocalUser)
#    $LocalGroup.Save()
#
#    # Get Current Domain
#    If (Get-MyDomain -DomainName "MyDomain")
#    {
#      # Get Domain User
#      $DomainUser = Get-MyDomainUsers -UserID $ENV:USERNAME
#
#      # Get Domain Computer
#      $DomainComputer = Get-MyDomainComputers -ComputerName $ENV:COMPUTERNAME
#
#      # Get Domain Group
#      $DomainGroup = Get-MyDomainGroups -GroupName "Domain Users"
#
#      # Add Domain User, Computer, and Group to Local Group
#      $LocalGroup.Members.Add($DomainUser)
#      $LocalGroup.Members.Add($DomainComputer)
#      $LocalGroup.Members.Add($DomainGroup)
#      $LocalGroup.Save()
#
#      # Remove Members of Local Group
#      [Void]$LocalGroup.Members.Remove($DomainUser)
#      [Void]$LocalGroup.Members.Remove($DomainComputer)
#      [Void]$LocalGroup.Members.Remove($DomainGroup)
#    }
#    [Void]$LocalGroup.Members.Remove($LocalUser)
#    $LocalGroup.Save()
#
#    # Delete Local User
#    $LocalUser.Delete()
#
#    # Delete Local group
#    $LocalGroup.Delete()
#  }
#
#  $LocalUser = Get-MyLocalUsers -UserID "Administrator"
#    Enabled
#    AccountLockoutTime
#    LastLogon
#    HomeDirectory
#    HomeDrive
#    ScriptPath
#    LastPasswordSet
#    PasswordNotRequired
#    PasswordNeverExpires
#    UserCannotChangePassword
#    Description
#    DisplayName
#    Name
#
#  $LocalGroup = Get-MyLocalGroups -GroupName "Administrators"
#    IsSecurityGroup
#    GroupScope
#    Members
#    Description
#    Name
#
#  $DomainUser = Get-MyDomainUsers -UserID $ENV:USERNAME
#    GivenName
#    MiddleName
#    Surname
#    EmailAddress
#    VoiceTelephoneNumber
#    EmployeeId
#    Enabled
#    AccountLockoutTime
#    LastLogon
#    AccountExpirationDate
#    HomeDirectory
#    HomeDrive
#    ScriptPath
#    LastPasswordSet
#    PasswordNotRequired
#    PasswordNeverExpires
#    UserCannotChangePassword
#    Description
#    DisplayName
#    SamAccountName
#    UserPrincipalName
#    Sid
#    DistinguishedName
#    Name
#
#  $DomainComputer = Get-MyDomainComputers -ComputerName $ENV:COMPUTERNAME
#    Enabled
#    LastLogon
#    LastPasswordSet
#    Description
#    Sid
#    Guid
#    DistinguishedName
#    Name
#
#  $DomainGroup = Get-MyDomainGroups -GroupName "Domain Users"
#    IsSecurityGroup
#    GroupScope
#    Members
#    Description
#    DisplayName
#    Sid
#    DistinguishedName
#    Name
'@
#endregion

#region ******** $Script:NetworkSetting ********
$Script:NetworkSetting = @'
# $ComputerName
# $IPAddress
# $OperatingSystem
# $ServicePack
# $Architecture

if ([String]::IsNullOrEmpty(($NICData = @(Get-MyNetworkSettings -ComputerName $ComputerName)[0])))
{
  $Simon = ""
  $Garfunkel = ""
  $Parsley = ""
  $Sage = ""
  $Rosemary = ""
  $JobStatus = "No Data"
}
else
{
  $Simon = $NICData.Name
  $Garfunkel = $NICData.MACAddress
  #$Parsley = $NICData.PhysicalMediaType
  $Parsley = $NICData.DriverVersion
  $Sage = $NICData.Speed
  $Rosemary = $NICData.SpeedDuplex
  $JobStatus = "Done"
}
'@
#endregion

#endregion

#region ******** Process Workstation List ********

#region $ProcList_ToolTip = System.Windows.Forms.ToolTip
Write-Verbose -Message "Creating Form Control `$ProcList_ToolTip"
$ProcList_ToolTip = New-Object -TypeName System.Windows.Forms.ToolTip($FormComponents)
$ProcList_ToolTip.ToolTipTitle = "$ScriptName - $ScriptVersion"
#endregion

#region $ProcList_Form_ico
# Icons for Forms are 16x16
$ProcList_Form_ico = @"
AAABAAEAEBAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACOj5A2kpOUTpiamyMAAAAA5e7qL+fv60vh7OcsAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAnJ2fNaGio6GYmZoEra2vsN7e3/+7v76ixObV03zYsP9f0KD/f9ix/8bn183R5tssAAAAAAAAAAAAAAAAhISHDLy8ve++v7//pKWmcLW2t7fs7Oz/pt7B/yrBhP8swob/S8SG/yTB
g/8swYP/qt/C68vh1B0AAAAAo6OlSqCgohitrq91x8jI/9HR0v7h4uL/3Ozg/y7AgP8tw4f/x+7c/9Xr0v8nvXr/JMGD/zLAfv/J4dCanZ2fGL2+v/K+v8Dyvr/AstnZ2v/e3t//4ODg/6DYs/8+yZH/yu/e/+n3
7v/4/Pr/idCY/zDBg/84x43/odSw352eoC64ubrTwMHB/8jJyf/l5eX/6urr/9DR0eiY0qb6VMmN/73lxv9oxYb/qt+8//L47v9mvnD/U8mN/53PpOiTlJUQoKCiFcDBwsXY2Nn/6urq/9PU1LTJzcoIttaxwlWx
S/9du2f/YcB0/2XCef/g8uP/z+bH/1WvRv+106+2r7Cx78PExP/T1NT/4ODh/+vr6//Cw8QxAAAAAMzbx0x5tVj+XKo5/1ywRv9csUv/dbtf/6XOjf+AuGL9v8+4QKqrrO/BwsP/1NTV/93d3v/m5ub/t7e4MQAA
AAAAAAAAxtS/cYy6cPpVnCj/U5sk/1edKv+OunT/tbuztwAAAACOj5EQnJyeFbS0tcXl5eb/6enp/7e3uLSrrK0IAAAAAMLFwRzU1tTh3eDd/8bQwv/Cx8HArLWpKJmdmgwAAAAAiYmLLra3uNPp6en/9PT0/97e
3v/t7u7/ycnK6MjIycLc3Nz139/g/9PU1P+7vLz/vb6+/6+vsbORkpQQAAAAAIyNjxjHyMny0dHS8rGys7Lv7/D/4+Tk/97e3//f4OD/39/g/9PU1P/Q0dH6urq7rLy9vvyys7TKmZqcAQAAAAAAAAAAkZKUSpmZ
mxinqKl1+fn5/+Li4/7i4uP/4eHh/9nZ2v7Gx8f+wsLC/ausrTehoqQypKSmMAAAAAAAAAAAAAAAAAAAAAB5enwMyMjJ7/T09P+mp6hwtre4t9bW1/+trq96srOzrbe4uf+ztLW9AAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAJydnzWgoKKhnp+hBK2ur7DLzMz/paancpqbnCGvr7Gfo6SlGgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACSk5Q2mJmaTpWWlyMAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAA/EesQeABrEHAAKxBgACsQQAArEEAAKxBAACsQQIArEEDAaxBAQGsQQABrEEAAaxBgAOsQcAPrEHgD6xB/H+sQQ==
"@
#endregion

#region $ProcList_Form = System.Windows.Forms.Form
Write-Verbose -Message "Creating Form Control `$ProcList_Form"
$ProcList_Form = New-Object -TypeName System.Windows.Forms.Form
$ProcList_Form.BackColor = [System.Drawing.Color]::Black
$ProcList_Form.Font = New-Object -TypeName System.Drawing.Font("Verdana", (8 * (96 / ($ProcList_Form.CreateGraphics()).DpiX)), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
$ProcList_Form.ForeColor = [System.Drawing.Color]::White
$ProcList_Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$ProcList_Form.Icon = ([System.Drawing.Icon](New-Object -TypeName System.Drawing.Icon((New-Object -TypeName System.IO.MemoryStream(($$ = [System.Convert]::FromBase64String($ProcList_Form_ico)), 0, $$.Length)))))
$ProcList_Form.KeyPreview = $True
$ProcList_Form.Name = "ProcList_Form"
$ProcList_Form.Size = New-Object -TypeName System.Drawing.Size(1024, 768)
$ProcList_Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$ProcList_Form.Tag = $False
$ProcList_Form.Text = "$ScriptName - $ScriptVersion"
#endregion
$ProcList_ToolTip.SetToolTip($ProcList_Form, "Help for Control $($ProcList_Form.Name)")

#region function Closing-ProcList_Form
function Closing-ProcList_Form()
{
  <#
    .SYNOPSIS
      Closing event for the ProcList_Form Control
    .DESCRIPTION
      Closing event for the ProcList_Form Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Closing-ProcList_Form -Sender $ProcList_Form -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object]$Sender,
    [parameter(Mandatory=$True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Closing Event for `$ProcList_Form"
  Try
  {
    Kill-MyThread
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit Closing Event for `$ProcList_Form"
}
#endregion
$ProcList_Form.add_Closing({Closing-ProcList_Form -Sender $ProcList_Form -EventArg $_})

#region function KeyDown-ProcList_Form
function KeyDown-ProcList_Form()
{
  <#
    .SYNOPSIS
      KeyDown event for the ProcList_Form Control
    .DESCRIPTION
      KeyDown event for the ProcList_Form Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       KeyDown-ProcList_Form -Sender $ProcList_Form -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object]$Sender,
    [parameter(Mandatory=$True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter KeyDown Event for `$ProcList_Form"
  Try
  {
    if ($EventArg.Control -and $EventArg.Alt -and $EventArg.KeyCode -eq "F10")
    {
      $EventArg.Handled = $True
      if ($ProcList_Form.Tag)
      {
        $Script:VerbosePreference = "SilentlyContinue"
        $Script:DebugPreference = "SilentlyContinue"
        [Void][Window.Display]::Hide()
        $ProcList_Form.Tag = $False
      }
      else
      {
        $Script:VerbosePreference = "Continue"
        $Script:DebugPreference = "Continue"
        [Void][Window.Display]::Show()
        $ProcList_Form.Tag = $True
      }
      $ProcList_Form.Activate()
    }
    elseif ($EventArg.KeyCode -eq "F1")
    {
      $EventArg.Handled = $True
      $ProcList_ToolTip.Active = (-not $ProcList_ToolTip.Active)
    }  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit KeyDown Event for `$ProcList_Form"
}
#endregion
$ProcList_Form.add_KeyDown({KeyDown-ProcList_Form -Sender $ProcList_Form -EventArg $_})

#region function Load-ProcList_Form
function Load-ProcList_Form()
{
  <#
    .SYNOPSIS
      Load event for the ProcList_Form Control
    .DESCRIPTION
      Load event for the ProcList_Form Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Load-ProcList_Form -Sender $ProcList_Form -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Load Event for `$ProcList_Form"
  Try
  {
    Resize-ProcList_Form -Sender $Sender -EventArg $EventArg
    $ProcList_Form.add_Resize({ Resize-ProcList_Form -Sender $ProcList_Form -EventArg $_ })
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit Load Event for `$ProcList_Form"
}
#endregion
$ProcList_Form.add_Load({ Load-ProcList_Form -Sender $ProcList_Form -EventArg $_ })

#region function Resize-ProcList_Form
function Resize-ProcList_Form()
{
  <#
    .SYNOPSIS
      Resize event for the ProcList_Form Control
    .DESCRIPTION
      Resize event for the ProcList_Form Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Resize-ProcList_Form -Sender $ProcList_Form -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Resize Event for `$ProcList_Form"
  Try
  {
    $ProcList_Label.Size = New-Object -TypeName System.Drawing.Size(($ProcList_Form.ClientSize.Width - ($FormSpacer * 2)), $ProcList_Label.Height)
    
    $ProcList_Add_Button.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($ProcList_Form.ClientSize.Height - ($ProcList_Add_Button.Height + $FormSpacer)))
    $ProcList_Add_Button.Width = [Math]::Floor(($ProcList_Form.ClientSize.Width - ($FormSpacer * 8)) / 7)

    $ProcList_Load_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Add_Button.Right + $FormSpacer), ($ProcList_Form.ClientSize.Height - ($ProcList_Load_Button.Height + $FormSpacer)))
    $ProcList_Load_Button.Width = $ProcList_Add_Button.Width
    
    $ProcList_Script_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Load_Button.Right + $FormSpacer), ($ProcList_Form.ClientSize.Height - ($ProcList_Add_Button.Height + $FormSpacer)))
    $ProcList_Script_Button.Width = $ProcList_Add_Button.Width
    
    $ProcList_Process_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Script_Button.Right + $FormSpacer), ($ProcList_Form.ClientSize.Height - ($ProcList_Process_Button.Height + $FormSpacer)))
    $ProcList_Process_Button.Width = $ProcList_Add_Button.Width + ($ProcList_Form.ClientSize.Width - ((($ProcList_Add_Button.Width + $FormSpacer) * 7) + $FormSpacer))
    
    $ProcList_Export_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Process_Button.Right + $FormSpacer), ($ProcList_Form.ClientSize.Height - ($ProcList_Export_Button.Height + $FormSpacer)))
    $ProcList_Export_Button.Width = $ProcList_Add_Button.Width
    
    $ProcList_Clear_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Export_Button.Right + $FormSpacer), ($ProcList_Form.ClientSize.Height - ($ProcList_Clear_Button.Height + $FormSpacer)))
    $ProcList_Clear_Button.Width = $ProcList_Add_Button.Width
    
    $ProcList_Terminate_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Clear_Button.Right + $FormSpacer), ($ProcList_Form.ClientSize.Height - ($ProcList_Terminate_Button.Height + $FormSpacer)))
    $ProcList_Terminate_Button.Width = $ProcList_Add_Button.Width
    
    $ProcList_ListView.Size = New-Object -TypeName System.Drawing.Size(($ProcList_Form.ClientSize.Width - ($FormSpacer * 2)), (($ProcList_Add_Button.Top - $FormSpacer) - $ProcList_ListView.Top))
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit Resize Event for `$ProcList_Form"
}
#endregion

#region ******** $ProcList_Form Controls ********

#region $ProcList_Label = System.Windows.Forms.Label
Write-Verbose -Message "Creating Form Control `$ProcList_Label"
$ProcList_Label = New-Object -TypeName System.Windows.Forms.Label
$ProcList_Form.Controls.Add($ProcList_Label)
$ProcList_Label.AutoSize = $True
$ProcList_Label.BackColor = [System.Drawing.Color]::DarkGray
$ProcList_Label.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$ProcList_Label.Font = New-Object -TypeName System.Drawing.Font($ProcList_Form.Font.FontFamily, ($ProcList_Form.Font.Size + 4), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$ProcList_Label.ForeColor = [System.Drawing.Color]::Black
$ProcList_Label.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, $FormSpacer)
$ProcList_Label.Name = "ProcList_Label"
$ProcList_Label.Text = "$ScriptName - $ScriptVersion by $ScriptAuthor"
$ProcList_Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#endregion
$TempHeight = $ProcList_Label.Height
$ProcList_Label.AutoSize = $False
$ProcList_Label.Size = New-Object -TypeName System.Drawing.Size(($ProcList_Form.ClientSize.Width - ($FormSpacer * 2)), $TempHeight)

#region ListView Sort
$MyCustomListViewSort = @"
using System;
using System.Windows.Forms;
using System.Collections;

namespace MyCustom
{
  public class ListViewSort : IComparer
  {
    private int _SortColumn = 0;
    private bool _SortAscending = true;
    private bool _SortEnable = true;

    public ListViewSort()
    {
      _SortColumn = 0;
      _SortAscending = true;
    }

    public ListViewSort(int Column)
    {
      _SortColumn = Column;
      _SortAscending = true;
    }

    public ListViewSort(int Column, bool Order)
    {
      _SortColumn = Column;
      _SortAscending = Order;
    }

    public int SortColumn
    {
      get { return _SortColumn; }
      set { _SortColumn = value; }
    }

    public bool SortAscending
    {
      get { return _SortAscending; }
      set { _SortAscending = value; }
    }

    public bool SortEnable
    {
      get { return _SortEnable; }
      set { _SortEnable = value; }
    }

    public int Compare(object RowX, object RowY)
    {
      if (_SortEnable)
      {
        if (_SortAscending)
        {
          return String.Compare(((System.Windows.Forms.ListViewItem)RowX).SubItems[_SortColumn].Text, ((System.Windows.Forms.ListViewItem)RowY).SubItems[_SortColumn].Text);
        }
        else
        {
          return String.Compare(((System.Windows.Forms.ListViewItem)RowY).SubItems[_SortColumn].Text, ((System.Windows.Forms.ListViewItem)RowX).SubItems[_SortColumn].Text);
        }
      }
      else
      {
        return 0;
      }
    }
  }
}
"@
Add-Type -TypeDefinition $MyCustomListViewSort -ReferencedAssemblies "System.Windows.Forms" -Debug:$False
#endregion

#region $ProcList_ListView = System.Windows.Forms.ListView
Write-Verbose -Message "Creating Form Control `$ProcList_ListView"
$ProcList_ListView = New-Object -TypeName System.Windows.Forms.ListView
$ProcList_Form.Controls.Add($ProcList_ListView)
$ProcList_ListView.AllowColumnReorder = $True
$ProcList_ListView.AutoSize = $True
$ProcList_ListView.BackColor = [System.Drawing.Color]::White
#[Void]$ProcList_ListView.Columns.Add($ListViewColumns)
$ProcList_ListView.Font = New-Object -TypeName System.Drawing.Font($ProcList_Form.Font.FontFamily, $ProcList_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$ProcList_ListView.ForeColor = [System.Drawing.Color]::Black
$ProcList_ListView.FullRowSelect = $True
$ProcList_ListView.GridLines = $True
#[Void]$ProcList_ListView.Groups.Add($ListViewGroups)
#[Void]$ProcList_ListView.Items.Add($ListViewItems)
$ProcList_ListView.ListViewItemSorter = New-Object -TypeName MyCustom.ListViewSort
$ProcList_ListView.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($ProcList_Label.Bottom + $FormSpacer))
$ProcList_ListView.MultiSelect = $True
$ProcList_ListView.Name = "ProcList_ListView"
$ProcList_ListView.Size = New-Object -TypeName System.Drawing.Size(($ProcList_Form.ClientSize.Width - ($FormSpacer * 2)), 200)
$ProcList_ListView.Tag = @()
$ProcList_ListView.Text = "ProcList_ListView"
$ProcList_ListView.View = [System.Windows.Forms.View]::Details
#endregion
$ProcList_ToolTip.SetToolTip($ProcList_ListView, "Help for Control $($ProcList_ListView.Name)")

#region function New-ListViewItem
function New-ListViewItem()
{
  <#
    .SYNOPSIS
      Command to do something specific
    .DESCRIPTION
      Command to do something specific
    .PARAMETER ListView
      ListView to Add Items to
    .PARAMETER ComputerName
      Name of Computer to Add
    .PARAMETER OnLine
    .PARAMETER IPAddress
    .PARAMETER WMIStatus
    .PARAMETER WMIProtocol
    .PARAMETER WMIName
    .PARAMETER UserName
    .PARAMETER OperatingSystem
    .PARAMETER ServicePack 
    .PARAMETER Architecture
    .PARAMETER JobStatus
    .PARAMETER Simon
    .PARAMETER Garfunkel
    .PARAMETER Parsley
    .PARAMETER Sage
    .PARAMETER Rosemary
    .PARAMETER Time
    .PARAMETER Date
    .PARAMETER ErrorMessage
    .INPUTS
      What type of input does the command accepts
    .OUTPUTS
      What type of data does the command output
    .EXAMPLE
      New-ListViewItemPipe -Value "String"
    .NOTES
      Original Script By Kenneth D. Sweet
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [System.Windows.Forms.ListView]$ListView,
    [parameter(Mandatory = $True)]
    [String[]]$ComputerName,
    [String]$OnLine = "",
    [String]$IPAddress = "",
    [String]$WMIStatus = "",
    [String]$WMIProtocol = "",
    [String]$WMIName = "",
    [String]$UserName = "",
    [String]$OperatingSystem = "",
    [String]$ServicePack = "",
    [String]$Architecture = "",
    [String]$JobStatus = "",
    [String]$Simon = "",
    [String]$Garfunkel = "",
    [String]$Parsley = "",
    [String]$Sage = "",
    [String]$Rosemary = "",
    [String]$Time = "",
    [String]$Date = "",
    [String]$ErrorMessage = "",
    [System.Drawing.Font]$Font = $ProcList_Form.Font
  )
  Write-Verbose -Message "Start New-ListViewItem Function"
  ForEach ($Computer in $ComputerName)
  {
    #region $Temp_ListViewItem = System.Windows.Forms.ListViewItem
    $TempName = $Computer.ToUpper().Split(".")[0]
    if (-not $ListView.Tag.Contains($TempName))
    {
      Write-Verbose -Message "Creating Form Control `$Temp_ListViewItem"
      #$ListView.Tag += $TempName
      $Temp_ListViewItem = New-Object -TypeName System.Windows.Forms.ListViewItem
      [Void]$ListView.Items.Add($Temp_ListViewItem)
      $Temp_ListViewItem.BackColor = [System.Drawing.Color]::White
      $Temp_ListViewItem.Checked = $False
      $Temp_ListViewItem.Font = $Font
      $Temp_ListViewItem.ForeColor = [System.Drawing.Color]::Black
      $Temp_ListViewItem.Name = "ListViewItem_$Computer"
      $Temp_ListViewItem.Selected = $False
      $Temp_ListViewItem.SubItems.AddRange(@($OnLine, $IPAddress, $WMIStatus, $WMIProtocol, $WMIName, $UserName, $OperatingSystem, $ServicePack, $Architecture, $JobStatus, $Simon, $Garfunkel, $Parsley, $Sage, $Rosemary, $Time, $Date, $ErrorMessage))
      $Temp_ListViewItem.Tag = $Null
      $Temp_ListViewItem.Text = $Computer.ToUpper()
      $Temp_ListViewItem.ToolTipText = ""
      $Temp_ListViewItem.UseItemStyleForSubItems = $True
    }
    #endregion
  }
  Write-Verbose -Message "Finish New-ListViewItem Function"
}
#endregion

#region function ColumnClick-ProcList_ListView
function ColumnClick-ProcList_ListView()
{
  <#
    .SYNOPSIS
      ColumnClick event for the ProcList_ListView Control
    .DESCRIPTION
      ColumnClick event for the ProcList_ListView Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       ColumnClick-ProcList_ListView -Sender $ProcList_ListView -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter ColumnClick Event for `$ProcList_ListView"
  Try
  {
    if ($Sender.ListViewItemSorter.SortAscending -and $Sender.ListViewItemSorter.SortColumn -eq $EventArg.Column)
    {
      $Sender.ListViewItemSorter.SortAscending = $False
    }
    else
    {
      $Sender.ListViewItemSorter.SortColumn = $EventArg.Column
      $Sender.ListViewItemSorter.SortAscending = $True
    }
    $Sender.Sort()
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit ColumnClick Event for `$ProcList_ListView"
}
#endregion
$ProcList_ListView.add_ColumnClick({ ColumnClick-ProcList_ListView -Sender $ProcList_ListView -EventArg $_ })

#region function MouseClick-ProcList__ListView
function MouseClick-ProcList__ListView()
{
  <#
    .SYNOPSIS
      MouseClick event for the ProcList__ListView Control
    .DESCRIPTION
      MouseClick event for the ProcList__ListView Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       MouseClick-ProcList__ListView -Sender $ProcList_ListView -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object]$Sender,
    [parameter(Mandatory=$True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter MouseClick Event for `$ProcList_ListView"
  Try
  {
    if ($EventArg.Button -eq [System.Windows.Forms.MouseButtons]::Right)
    {
      $ProcList_ContextMenuStrip.Show($Sender, $EventArg.X, $EventArg.Y)
    }
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit MouseClick Event for `$ProcList_ListView"
}
#endregion
$ProcList_ListView.add_MouseClick({MouseClick-ProcList__ListView -Sender $ProcList_ListView -EventArg $_})

#region ******** $ProcList_ListView Column Headers ********

#region $ProcList_Workstation_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_Workstation_ColumnHeader"
$ProcList_Workstation_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_Workstation_ColumnHeader)
$ProcList_Workstation_ColumnHeader.Name = "ProcList_Workstation_ColumnHeader"
$ProcList_Workstation_ColumnHeader.Text = "Workstation"
$ProcList_Workstation_ColumnHeader.Width = -2
#endregion

#region $ProcList_OnLine_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_OnLine_ColumnHeader"
$ProcList_OnLine_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_OnLine_ColumnHeader)
$ProcList_OnLine_ColumnHeader.Name = "ProcList_OnLine_ColumnHeader"
$ProcList_OnLine_ColumnHeader.Text = "On-Line"
$ProcList_OnLine_ColumnHeader.Width = -2
#endregion

#region $ProcList_IPAddress_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_IPAddress_ColumnHeader"
$ProcList_IPAddress_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_IPAddress_ColumnHeader)
$ProcList_IPAddress_ColumnHeader.Name = "ProcList_IPAddress_ColumnHeader"
$ProcList_IPAddress_ColumnHeader.Text = "IP Address"
$ProcList_IPAddress_ColumnHeader.Width = -2
#endregion

#region $ProcList_WMIStatus_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_WMIStatus_ColumnHeader"
$ProcList_WMIStatus_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_WMIStatus_ColumnHeader)
$ProcList_WMIStatus_ColumnHeader.Name = "ProcList_WMIStatus_ColumnHeader"
$ProcList_WMIStatus_ColumnHeader.Text = "WMI Status"
$ProcList_WMIStatus_ColumnHeader.Width = -2
#endregion

#region $ProcList_WMIProtocol_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_WMIProtocol_ColumnHeader"
$ProcList_WMIProtocol_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_WMIProtocol_ColumnHeader)
$ProcList_WMIProtocol_ColumnHeader.Name = "ProcList_WMIProtocol_ColumnHeader"
$ProcList_WMIProtocol_ColumnHeader.Text = "WMI Protocol"
$ProcList_WMIProtocol_ColumnHeader.Width = -2
#endregion

#region $ProcList_WMIName_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_WMIName_ColumnHeader"
$ProcList_WMIName_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_WMIName_ColumnHeader)
$ProcList_WMIName_ColumnHeader.Name = "ProcList_WMIName_ColumnHeader"
$ProcList_WMIName_ColumnHeader.Text = "WMI Name"
$ProcList_WMIName_ColumnHeader.Width = -2
#endregion

#region $ProcList_UserName_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_UserName_ColumnHeader"
$ProcList_UserName_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_UserName_ColumnHeader)
$ProcList_UserName_ColumnHeader.Name = "ProcList_UserName_ColumnHeader"
$ProcList_UserName_ColumnHeader.Text = "UserName"
$ProcList_UserName_ColumnHeader.Width = -2
#endregion

#region $ProcList_OperatingSystem_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_OperatingSystem_ColumnHeader"
$ProcList_OperatingSystem_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_OperatingSystem_ColumnHeader)
$ProcList_OperatingSystem_ColumnHeader.Name = "ProcList_OperatingSystem_ColumnHeader"
$ProcList_OperatingSystem_ColumnHeader.Text = "Operating System"
$ProcList_OperatingSystem_ColumnHeader.Width = -2
#endregion

#region $ProcList_ServicePack_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_ServicePack_ColumnHeader"
$ProcList_ServicePack_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_ServicePack_ColumnHeader)
$ProcList_ServicePack_ColumnHeader.Name = "ProcList_ServicePack_ColumnHeader"
$ProcList_ServicePack_ColumnHeader.Text = "BuildNumber"
$ProcList_ServicePack_ColumnHeader.Width = -2
#endregion

#region $ProcList_OSArch_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_OSArch_ColumnHeader"
$ProcList_OSArch_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_OSArch_ColumnHeader)
$ProcList_OSArch_ColumnHeader.Name = "ProcList_OSArch_ColumnHeader"
$ProcList_OSArch_ColumnHeader.Text = "Architecture"
$ProcList_OSArch_ColumnHeader.Width = -2
#endregion

#region $ProcList_Status_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_Status_ColumnHeader"
$ProcList_Status_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_Status_ColumnHeader)
$ProcList_Status_ColumnHeader.Name = "ProcList_Status_ColumnHeader"
$ProcList_Status_ColumnHeader.Text = "Job Status"
$ProcList_Status_ColumnHeader.Width = -2
#endregion

#region $ProcList_Simon_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_Simon_ColumnHeader"
$ProcList_Simon_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_Simon_ColumnHeader)
$ProcList_Simon_ColumnHeader.Name = "ProcList_Simon_ColumnHeader"
$ProcList_Simon_ColumnHeader.Text = "Simon"
$ProcList_Simon_ColumnHeader.Width = -2
#endregion

#region $ProcList_Garfunkel_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_Garfunkel_ColumnHeader"
$ProcList_Garfunkel_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_Garfunkel_ColumnHeader)
$ProcList_Garfunkel_ColumnHeader.Name = "ProcList_Garfunkel_ColumnHeader"
$ProcList_Garfunkel_ColumnHeader.Text = "Garfunkel"
$ProcList_Garfunkel_ColumnHeader.Width = -2
#endregion

#region $ProcList_Parsley_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_Parsley_ColumnHeader"
$ProcList_Parsley_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_Parsley_ColumnHeader)
$ProcList_Parsley_ColumnHeader.Name = "ProcList_Parsley_ColumnHeader"
$ProcList_Parsley_ColumnHeader.Text = "Parsley"
$ProcList_Parsley_ColumnHeader.Width = -2
#endregion

#region $ProcList_Sage_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_Sage_ColumnHeader"
$ProcList_Sage_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_Sage_ColumnHeader)
$ProcList_Sage_ColumnHeader.Name = "ProcList_Sage_ColumnHeader"
$ProcList_Sage_ColumnHeader.Text = "Sage"
$ProcList_Sage_ColumnHeader.Width = -2
#endregion

#region $ProcList_Rosemary_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_Rosemary_ColumnHeader"
$ProcList_Rosemary_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_Rosemary_ColumnHeader)
$ProcList_Rosemary_ColumnHeader.Name = "ProcList_Rosemary_ColumnHeader"
$ProcList_Rosemary_ColumnHeader.Text = "Rosemary"
$ProcList_Rosemary_ColumnHeader.Width = -2
#endregion

#region $ProcList_Time_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_Time_ColumnHeader"
$ProcList_Time_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_Time_ColumnHeader)
$ProcList_Time_ColumnHeader.Name = "ProcList_Time_ColumnHeader"
$ProcList_Time_ColumnHeader.Text = "Time"
$ProcList_Time_ColumnHeader.Width = -2
#endregion

#region $ProcList_Date_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_Date_ColumnHeader"
$ProcList_Date_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_Date_ColumnHeader)
$ProcList_Date_ColumnHeader.Name = "ProcList_Date_ColumnHeader"
$ProcList_Date_ColumnHeader.Text = "Date"
$ProcList_Date_ColumnHeader.Width = -2
#endregion

#region $ProcList_Error_ColumnHeader = System.Windows.Forms.ColumnHeader
Write-Verbose -Message "Creating Form Control `$ProcList_Error_ColumnHeader"
$ProcList_Error_ColumnHeader = New-Object -TypeName System.Windows.Forms.ColumnHeader
[Void]$ProcList_ListView.Columns.Add($ProcList_Error_ColumnHeader)
$ProcList_Error_ColumnHeader.Name = "ProcList_Error_ColumnHeader"
$ProcList_Error_ColumnHeader.Text = "Error Message"
$ProcList_Error_ColumnHeader.Width = -2
#endregion

#endregion

#region ******** $ProcList_ListView Right Click Menu ********

#region $ProcList_ContextMenuStrip = System.Windows.Forms.ContextMenuStrip
Write-Verbose -Message "Creating Form Control `$ProcList_ContextMenuStrip"
$ProcList_ContextMenuStrip = New-Object -TypeName System.Windows.Forms.ContextMenuStrip($FormComponents)
#$ProcList_ContextMenuStrip.AutoClose = $True
#$ProcList_ContextMenuStrip.AutoSize = $True
#$ProcList_ContextMenuStrip.BackColor = [System.Drawing.SystemColors]::Control
#$ProcList_ContextMenuStrip.BackgroundImage = ([System.Drawing.Image]([System.Drawing.Image]::FromStream((New-Object -TypeName System.IO.MemoryStream(($$ = [System.Convert]::FromBase64String($ImageFile)), 0, $$.Length)))))
#$ProcList_ContextMenuStrip.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Tile
#$ProcList_ContextMenuStrip.Bounds = New-Object -TypeName System.Windows.Forms.Padding(0, 0, 61, 4)
#$ProcList_ContextMenuStrip.CanOverflow = $False
#$ProcList_ContextMenuStrip.Capture = $False
#$ProcList_ContextMenuStrip.CausesValidation = $False
#$ProcList_ContextMenuStrip.ClientSize = New-Object -TypeName System.Drawing.Size(61, 4)
#$ProcList_ContextMenuStrip.ContextMenu = System.Windows.Forms.ContextMenu
#$ProcList_ContextMenuStrip.ContextMenuStrip = System.Windows.Forms.ContextMenuStrip
#$ProcList_ContextMenuStrip.Cursor = [System.Windows.Forms.Cursors]::Default
#$ProcList_ContextMenuStrip.DefaultDropDownDirection = [System.Windows.Forms.ToolStripDropDownDirection]::Right
#$ProcList_ContextMenuStrip.Dock = [System.Windows.Forms.DockStyle]::None
#$ProcList_ContextMenuStrip.DropShadowEnabled = $False
#$ProcList_ContextMenuStrip.Enabled = $True
#$ProcList_ContextMenuStrip.Font = New-Object -TypeName System.Drawing.Font("Microsoft Sans Serif", 8.25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
#$ProcList_ContextMenuStrip.ForeColor = [System.Drawing.SystemColors]::ControlText
#$ProcList_ContextMenuStrip.GripMargin = New-Object -TypeName System.Windows.Forms.Padding(2, 2, 2, 2)
#$ProcList_ContextMenuStrip.GripStyle = [System.Windows.Forms.ToolStripGripStyle]::Hidden
#$ProcList_ContextMenuStrip.Height = 4
#$ProcList_ContextMenuStrip.BeginUpdate()
#[Void]$ProcList_ContextMenuStrip.Items.Add($ContextMenuStripItems)
#$ProcList_ContextMenuStrip.EndUpdate()
#$ProcList_ContextMenuStrip.Items.AddRange(@($ContextMenuStripItems))
#$ProcList_ContextMenuStrip.LayoutStyle = [System.Windows.Forms.ToolStripLayoutStyle]::Flow
#$ProcList_ContextMenuStrip.Left = 0
#$ProcList_ContextMenuStrip.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, $FormSpacer)
#$ProcList_ContextMenuStrip.Margin = New-Object -TypeName System.Windows.Forms.Padding(0, 0, 0, 0)
$ProcList_ContextMenuStrip.Name = "ProcList_ContextMenuStrip"
#$ProcList_ContextMenuStrip.Opacity = 1
#$ProcList_ContextMenuStrip.RightToLeft = [System.Windows.Forms.RightToLeft]::No
#$ProcList_ContextMenuStrip.ShowCheckMargin = $False
#$ProcList_ContextMenuStrip.ShowImageMargin = $True
#$ProcList_ContextMenuStrip.ShowItemToolTips = $True
#$ProcList_ContextMenuStrip.Size = New-Object -TypeName System.Drawing.Size(61, 4)
#$ProcList_ContextMenuStrip.Stretch = $False
#$ProcList_ContextMenuStrip.TabIndex = 0
#$ProcList_ContextMenuStrip.TabStop = $False
#$ProcList_ContextMenuStrip.Tag = System.Object
$ProcList_ContextMenuStrip.Text = "ProcList_ContextMenuStrip"
#$ProcList_ContextMenuStrip.Top = 0
#$ProcList_ContextMenuStrip.TopLevel = $True
#$ProcList_ContextMenuStrip.UseWaitCursor = $False
#$ProcList_ContextMenuStrip.Visible = $False
#$ProcList_ContextMenuStrip.Width = 61
#endregion

#region ******** $ProcList_ContextMenuStrip ToolStripButtons ********

#region $ProcList_Process_ToolStripButton = System.Windows.Forms.ToolStripButton
Write-Verbose -Message "Creating Form Control `$ProcList_Process_ToolStripButton"
$ProcList_Process_ToolStripButton = New-Object -TypeName System.Windows.Forms.ToolStripButton
[Void]$ProcList_ContextMenuStrip.Items.Add($ProcList_Process_ToolStripButton)
#$ProcList_Process_ToolStripButton.AccessibleDefaultActionDescription = ""
#$ProcList_Process_ToolStripButton.AccessibleDescription = ""
#$ProcList_Process_ToolStripButton.AccessibleName = ""
#$ProcList_Process_ToolStripButton.AccessibleRole = [System.Windows.Forms.AccessibleRole]::Default
#$ProcList_Process_ToolStripButton.Alignment = [System.Windows.Forms.ToolStripItemAlignment]::Left
#$ProcList_Process_ToolStripButton.AllowDrop = $False
#$ProcList_Process_ToolStripButton.Anchor = [System.Windows.Forms.AnchorStyles]([System.Windows.Forms.AnchorStyles]::None -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left)
#$ProcList_Process_ToolStripButton.AutoSize = $True
#$ProcList_Process_ToolStripButton.AutoToolTip = $True
#$ProcList_Process_ToolStripButton.Available = $True
#$ProcList_Process_ToolStripButton.BackColor = [System.Drawing.SystemColors]::Control
#$ProcList_Process_ToolStripButton.BackgroundImage = ([System.Drawing.Image]([System.Drawing.Image]::FromStream((New-Object -TypeName System.IO.MemoryStream(($$ = [System.Convert]::FromBase64String($ImageFile)), 0, $$.Length)))))
#$ProcList_Process_ToolStripButton.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Tile
#$ProcList_Process_ToolStripButton.Checked = $False
#$ProcList_Process_ToolStripButton.CheckOnClick = $False
#$ProcList_Process_ToolStripButton.CheckState = [System.Windows.Forms.CheckState]::Unchecked
$ProcList_Process_ToolStripButton.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
#$ProcList_Process_ToolStripButton.Dock = [System.Windows.Forms.DockStyle]::None
#$ProcList_Process_ToolStripButton.DoubleClickEnabled = $False
#$ProcList_Process_ToolStripButton.Enabled = $True
#$ProcList_Process_ToolStripButton.Font = New-Object -TypeName System.Drawing.Font("Microsoft Sans Serif", 8.25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
#$ProcList_Process_ToolStripButton.ForeColor = [System.Drawing.SystemColors]::ControlText
#$ProcList_Process_ToolStripButton.Height = 23
#$ProcList_Process_ToolStripButton.Image = ([System.Drawing.Image]([System.Drawing.Image]::FromStream((New-Object -TypeName System.IO.MemoryStream(($$ = [System.Convert]::FromBase64String($ImageFile)), 0, $$.Length)))))
#$ProcList_Process_ToolStripButton.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#$ProcList_Process_ToolStripButton.ImageIndex = -1
#$ProcList_Process_ToolStripButton.ImageKey = ""
#$ProcList_Process_ToolStripButton.ImageScaling = [System.Windows.Forms.ToolStripItemImageScaling]::SizeToFit
#$ProcList_Process_ToolStripButton.ImageTransparentColor = $Null
#$ProcList_Process_ToolStripButton.Margin = New-Object -TypeName System.Windows.Forms.Padding(0, 1, 0, 2)
#$ProcList_Process_ToolStripButton.MergeAction = [System.Windows.Forms.MergeAction]::Append
#$ProcList_Process_ToolStripButton.MergeIndex = -1
$ProcList_Process_ToolStripButton.Name = "ProcList_Process_ToolStripButton"
#$ProcList_Process_ToolStripButton.Overflow = [System.Windows.Forms.ToolStripItemOverflow]::AsNeeded
#$ProcList_Process_ToolStripButton.Padding = New-Object -TypeName System.Windows.Forms.Padding(0, 0, 0, 0)
#$ProcList_Process_ToolStripButton.RightToLeft = [System.Windows.Forms.RightToLeft]::Inherit
#$ProcList_Process_ToolStripButton.RightToLeftAutoMirrorImage = $False
#$ProcList_Process_ToolStripButton.Size = New-Object -TypeName System.Drawing.Size(23, 23)
#$ProcList_Process_ToolStripButton.Tag = System.Object
$ProcList_Process_ToolStripButton.Text = "Process Selected Rows"
#$ProcList_Process_ToolStripButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#$ProcList_Process_ToolStripButton.TextImageRelation = [System.Windows.Forms.TextImageRelation]::ImageBeforeText
#$ProcList_Process_ToolStripButton.ToolTipText = ""
#$ProcList_Process_ToolStripButton.Visible = $False
#$ProcList_Process_ToolStripButton.Width = 23
#endregion

#region function Click-ProcList_Process_ToolStripButton
function Click-ProcList_Process_ToolStripButton()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Process_ToolStripButton Control
    .DESCRIPTION
      Click event for the ProcList_Process_ToolStripButton Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Process_ToolStripButton -Sender $ProcList_Process_ToolStripButton -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object]$Sender,
    [parameter(Mandatory=$True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Process_ToolStripButton"
  Try
  {
    Click-ProcList_Process_Button -Sender $Sender -EventArg $EventArg
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit Click Event for `$ProcList_Process_ToolStripButton"
}
#endregion
$ProcList_Process_ToolStripButton.add_Click({Click-ProcList_Process_ToolStripButton -Sender $ProcList_Process_ToolStripButton -EventArg $_})

#region $ProcList_Export_ToolStripButton = System.Windows.Forms.ToolStripButton
Write-Verbose -Message "Creating Form Control `$ProcList_Export_ToolStripButton"
$ProcList_Export_ToolStripButton = New-Object -TypeName System.Windows.Forms.ToolStripButton
[Void]$ProcList_ContextMenuStrip.Items.Add($ProcList_Export_ToolStripButton)
#$ProcList_Export_ToolStripButton.AccessibleDefaultActionDescription = ""
#$ProcList_Export_ToolStripButton.AccessibleDescription = ""
#$ProcList_Export_ToolStripButton.AccessibleName = ""
#$ProcList_Export_ToolStripButton.AccessibleRole = [System.Windows.Forms.AccessibleRole]::Default
#$ProcList_Export_ToolStripButton.Alignment = [System.Windows.Forms.ToolStripItemAlignment]::Left
#$ProcList_Export_ToolStripButton.AllowDrop = $False
#$ProcList_Export_ToolStripButton.Anchor = [System.Windows.Forms.AnchorStyles]([System.Windows.Forms.AnchorStyles]::None -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left)
#$ProcList_Export_ToolStripButton.AutoSize = $True
#$ProcList_Export_ToolStripButton.AutoToolTip = $True
#$ProcList_Export_ToolStripButton.Available = $True
#$ProcList_Export_ToolStripButton.BackColor = [System.Drawing.SystemColors]::Control
#$ProcList_Export_ToolStripButton.BackgroundImage = ([System.Drawing.Image]([System.Drawing.Image]::FromStream((New-Object -TypeName System.IO.MemoryStream(($$ = [System.Convert]::FromBase64String($ImageFile)), 0, $$.Length)))))
#$ProcList_Export_ToolStripButton.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Tile
#$ProcList_Export_ToolStripButton.Checked = $False
#$ProcList_Export_ToolStripButton.CheckOnClick = $False
#$ProcList_Export_ToolStripButton.CheckState = [System.Windows.Forms.CheckState]::Unchecked
$ProcList_Export_ToolStripButton.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
#$ProcList_Export_ToolStripButton.Dock = [System.Windows.Forms.DockStyle]::None
#$ProcList_Export_ToolStripButton.DoubleClickEnabled = $False
#$ProcList_Export_ToolStripButton.Enabled = $True
#$ProcList_Export_ToolStripButton.Font = New-Object -TypeName System.Drawing.Font("Microsoft Sans Serif", 8.25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
#$ProcList_Export_ToolStripButton.ForeColor = [System.Drawing.SystemColors]::ControlText
#$ProcList_Export_ToolStripButton.Height = 23
#$ProcList_Export_ToolStripButton.Image = ([System.Drawing.Image]([System.Drawing.Image]::FromStream((New-Object -TypeName System.IO.MemoryStream(($$ = [System.Convert]::FromBase64String($ImageFile)), 0, $$.Length)))))
#$ProcList_Export_ToolStripButton.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#$ProcList_Export_ToolStripButton.ImageIndex = -1
#$ProcList_Export_ToolStripButton.ImageKey = ""
#$ProcList_Export_ToolStripButton.ImageScaling = [System.Windows.Forms.ToolStripItemImageScaling]::SizeToFit
#$ProcList_Export_ToolStripButton.ImageTransparentColor = $Null
#$ProcList_Export_ToolStripButton.Margin = New-Object -TypeName System.Windows.Forms.Padding(0, 1, 0, 2)
#$ProcList_Export_ToolStripButton.MergeAction = [System.Windows.Forms.MergeAction]::Append
#$ProcList_Export_ToolStripButton.MergeIndex = -1
$ProcList_Export_ToolStripButton.Name = "ProcList_Export_ToolStripButton"
#$ProcList_Export_ToolStripButton.Overflow = [System.Windows.Forms.ToolStripItemOverflow]::AsNeeded
#$ProcList_Export_ToolStripButton.Padding = New-Object -TypeName System.Windows.Forms.Padding(0, 0, 0, 0)
#$ProcList_Export_ToolStripButton.RightToLeft = [System.Windows.Forms.RightToLeft]::Inherit
#$ProcList_Export_ToolStripButton.RightToLeftAutoMirrorImage = $False
#$ProcList_Export_ToolStripButton.Size = New-Object -TypeName System.Drawing.Size(23, 23)
#$ProcList_Export_ToolStripButton.Tag = System.Object
$ProcList_Export_ToolStripButton.Text = "Export Selected Results"
#$ProcList_Export_ToolStripButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#$ProcList_Export_ToolStripButton.TextImageRelation = [System.Windows.Forms.TextImageRelation]::ImageBeforeText
#$ProcList_Export_ToolStripButton.ToolTipText = ""
#$ProcList_Export_ToolStripButton.Visible = $False
#$ProcList_Export_ToolStripButton.Width = 23
#endregion

#region function Click-ProcList_Export_ToolStripButton
function Click-ProcList_Export_ToolStripButton()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Export_ToolStripButton Control
    .DESCRIPTION
      Click event for the ProcList_Export_ToolStripButton Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Export_ToolStripButton -Sender $ProcList_Export_ToolStripButton -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object]$Sender,
    [parameter(Mandatory=$True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Export_ToolStripButton"
  Try
  {
    Click-ProcList_Export_Button -Sender $Sender -EventArg $EventArg
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit Click Event for `$ProcList_Export_ToolStripButton"
}
#endregion
$ProcList_Export_ToolStripButton.add_Click({Click-ProcList_Export_ToolStripButton -Sender $ProcList_Export_ToolStripButton -EventArg $_})

#region $ProcList_Clear_ToolStripButton = System.Windows.Forms.ToolStripButton
Write-Verbose -Message "Creating Form Control `$ProcList_Clear_ToolStripButton"
$ProcList_Clear_ToolStripButton = New-Object -TypeName System.Windows.Forms.ToolStripButton
[Void]$ProcList_ContextMenuStrip.Items.Add($ProcList_Clear_ToolStripButton)
#$ProcList_Clear_ToolStripButton.AccessibleDefaultActionDescription = ""
#$ProcList_Clear_ToolStripButton.AccessibleDescription = ""
#$ProcList_Clear_ToolStripButton.AccessibleName = ""
#$ProcList_Clear_ToolStripButton.AccessibleRole = [System.Windows.Forms.AccessibleRole]::Default
#$ProcList_Clear_ToolStripButton.Alignment = [System.Windows.Forms.ToolStripItemAlignment]::Left
#$ProcList_Clear_ToolStripButton.AllowDrop = $False
#$ProcList_Clear_ToolStripButton.Anchor = [System.Windows.Forms.AnchorStyles]([System.Windows.Forms.AnchorStyles]::None -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left)
#$ProcList_Clear_ToolStripButton.AutoSize = $True
#$ProcList_Clear_ToolStripButton.AutoToolTip = $True
#$ProcList_Clear_ToolStripButton.Available = $True
#$ProcList_Clear_ToolStripButton.BackColor = [System.Drawing.SystemColors]::Control
#$ProcList_Clear_ToolStripButton.BackgroundImage = ([System.Drawing.Image]([System.Drawing.Image]::FromStream((New-Object -TypeName System.IO.MemoryStream(($$ = [System.Convert]::FromBase64String($ImageFile)), 0, $$.Length)))))
#$ProcList_Clear_ToolStripButton.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Tile
#$ProcList_Clear_ToolStripButton.Checked = $False
#$ProcList_Clear_ToolStripButton.CheckOnClick = $False
#$ProcList_Clear_ToolStripButton.CheckState = [System.Windows.Forms.CheckState]::Unchecked
$ProcList_Clear_ToolStripButton.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
#$ProcList_Clear_ToolStripButton.Dock = [System.Windows.Forms.DockStyle]::None
#$ProcList_Clear_ToolStripButton.DoubleClickEnabled = $False
#$ProcList_Clear_ToolStripButton.Enabled = $True
#$ProcList_Clear_ToolStripButton.Font = New-Object -TypeName System.Drawing.Font("Microsoft Sans Serif", 8.25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
#$ProcList_Clear_ToolStripButton.ForeColor = [System.Drawing.SystemColors]::ControlText
#$ProcList_Clear_ToolStripButton.Height = 23
#$ProcList_Clear_ToolStripButton.Image = ([System.Drawing.Image]([System.Drawing.Image]::FromStream((New-Object -TypeName System.IO.MemoryStream(($$ = [System.Convert]::FromBase64String($ImageFile)), 0, $$.Length)))))
#$ProcList_Clear_ToolStripButton.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#$ProcList_Clear_ToolStripButton.ImageIndex = -1
#$ProcList_Clear_ToolStripButton.ImageKey = ""
#$ProcList_Clear_ToolStripButton.ImageScaling = [System.Windows.Forms.ToolStripItemImageScaling]::SizeToFit
#$ProcList_Clear_ToolStripButton.ImageTransparentColor = $Null
#$ProcList_Clear_ToolStripButton.Margin = New-Object -TypeName System.Windows.Forms.Padding(0, 1, 0, 2)
#$ProcList_Clear_ToolStripButton.MergeAction = [System.Windows.Forms.MergeAction]::Append
#$ProcList_Clear_ToolStripButton.MergeIndex = -1
$ProcList_Clear_ToolStripButton.Name = "ProcList_Clear_ToolStripButton"
#$ProcList_Clear_ToolStripButton.Overflow = [System.Windows.Forms.ToolStripItemOverflow]::AsNeeded
#$ProcList_Clear_ToolStripButton.Padding = New-Object -TypeName System.Windows.Forms.Padding(0, 0, 0, 0)
#$ProcList_Clear_ToolStripButton.RightToLeft = [System.Windows.Forms.RightToLeft]::Inherit
#$ProcList_Clear_ToolStripButton.RightToLeftAutoMirrorImage = $False
#$ProcList_Clear_ToolStripButton.Size = New-Object -TypeName System.Drawing.Size(23, 23)
#$ProcList_Clear_ToolStripButton.Tag = System.Object
$ProcList_Clear_ToolStripButton.Text = "Clear Selected Results"
#$ProcList_Clear_ToolStripButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#$ProcList_Clear_ToolStripButton.TextImageRelation = [System.Windows.Forms.TextImageRelation]::ImageBeforeText
#$ProcList_Clear_ToolStripButton.ToolTipText = ""
#$ProcList_Clear_ToolStripButton.Visible = $False
#$ProcList_Clear_ToolStripButton.Width = 23
#endregion

#region function Click-ProcList_Clear_ToolStripButton
function Click-ProcList_Clear_ToolStripButton()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Clear_ToolStripButton Control
    .DESCRIPTION
      Click event for the ProcList_Clear_ToolStripButton Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Clear_ToolStripButton -Sender $ProcList_Clear_ToolStripButton -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object]$Sender,
    [parameter(Mandatory=$True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Clear_ToolStripButton"
  Try
  {
    if ($ProcList_ListView.SelectedItems.Count -gt 0)
    {
      $Script:TempLoad = @()
      if ([System.Windows.Forms.MessageBox]::Show("Clear Workstation List too?", "Clear Results", "YesNo", "Question") -eq [System.Windows.Forms.DialogResult]::No)
      {
        $Script:TempLoad = @($ProcList_ListView.SelectedItems | Select-Object -ExpandProperty Text)
      }
      $ProcList_ListView.SelectedItems | ForEach-Object -Process { $_.Remove() }
      $ProcList_ListView.Tag = @($ProcList_ListView.Items | Select-Object -ExpandProperty Text)
      if ($Script:TempLoad.Count -gt 0)
      {
        $ProcList_ListView.ListViewItemSorter.SortEnable = $False
        $Loading_Form.Tag = 0
        $Loading_Form.ShowDialog()
        $ProcList_ListView.ListViewItemSorter.SortEnable = $True
      }
    }
    #$Host.EnterNestedPrompt()
    #$ProcList_ListView.Items | ForEach-Object -Process { $_.Selected = -Not  $_.Selected }
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit Click Event for `$ProcList_Clear_ToolStripButton"
}
#endregion
$ProcList_Clear_ToolStripButton.add_Click({Click-ProcList_Clear_ToolStripButton -Sender $ProcList_Clear_ToolStripButton -EventArg $_})

#region $ProcList_Terminate_ToolStripButton = System.Windows.Forms.ToolStripButton
Write-Verbose -Message "Creating Form Control `$ProcList_Terminate_ToolStripButton"
$ProcList_Terminate_ToolStripButton = New-Object -TypeName System.Windows.Forms.ToolStripButton
[Void]$ProcList_ContextMenuStrip.Items.Add($ProcList_Terminate_ToolStripButton)
#$ProcList_Terminate_ToolStripButton.AccessibleDefaultActionDescription = ""
#$ProcList_Terminate_ToolStripButton.AccessibleDescription = ""
#$ProcList_Terminate_ToolStripButton.AccessibleName = ""
#$ProcList_Terminate_ToolStripButton.AccessibleRole = [System.Windows.Forms.AccessibleRole]::Default
#$ProcList_Terminate_ToolStripButton.Alignment = [System.Windows.Forms.ToolStripItemAlignment]::Left
#$ProcList_Terminate_ToolStripButton.AllowDrop = $False
#$ProcList_Terminate_ToolStripButton.Anchor = [System.Windows.Forms.AnchorStyles]([System.Windows.Forms.AnchorStyles]::None -bor [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left)
#$ProcList_Terminate_ToolStripButton.AutoSize = $True
#$ProcList_Terminate_ToolStripButton.AutoToolTip = $True
#$ProcList_Terminate_ToolStripButton.Available = $True
#$ProcList_Terminate_ToolStripButton.BackColor = [System.Drawing.SystemColors]::Control
#$ProcList_Terminate_ToolStripButton.BackgroundImage = ([System.Drawing.Image]([System.Drawing.Image]::FromStream((New-Object -TypeName System.IO.MemoryStream(($$ = [System.Convert]::FromBase64String($ImageFile)), 0, $$.Length)))))
#$ProcList_Terminate_ToolStripButton.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Tile
#$ProcList_Terminate_ToolStripButton.Checked = $False
#$ProcList_Terminate_ToolStripButton.CheckOnClick = $False
#$ProcList_Terminate_ToolStripButton.CheckState = [System.Windows.Forms.CheckState]::Unchecked
$ProcList_Terminate_ToolStripButton.DisplayStyle = [System.Windows.Forms.ToolStripItemDisplayStyle]::Text
#$ProcList_Terminate_ToolStripButton.Dock = [System.Windows.Forms.DockStyle]::None
#$ProcList_Terminate_ToolStripButton.DoubleClickEnabled = $False
$ProcList_Terminate_ToolStripButton.Enabled = $False
#$ProcList_Terminate_ToolStripButton.Font = New-Object -TypeName System.Drawing.Font("Microsoft Sans Serif", 8.25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
#$ProcList_Terminate_ToolStripButton.ForeColor = [System.Drawing.SystemColors]::ControlText
#$ProcList_Terminate_ToolStripButton.Height = 23
#$ProcList_Terminate_ToolStripButton.Image = ([System.Drawing.Image]([System.Drawing.Image]::FromStream((New-Object -TypeName System.IO.MemoryStream(($$ = [System.Convert]::FromBase64String($ImageFile)), 0, $$.Length)))))
#$ProcList_Terminate_ToolStripButton.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#$ProcList_Terminate_ToolStripButton.ImageIndex = -1
#$ProcList_Terminate_ToolStripButton.ImageKey = ""
#$ProcList_Terminate_ToolStripButton.ImageScaling = [System.Windows.Forms.ToolStripItemImageScaling]::SizeToFit
#$ProcList_Terminate_ToolStripButton.ImageTransparentColor = $Null
#$ProcList_Terminate_ToolStripButton.Margin = New-Object -TypeName System.Windows.Forms.Padding(0, 1, 0, 2)
#$ProcList_Terminate_ToolStripButton.MergeAction = [System.Windows.Forms.MergeAction]::Append
#$ProcList_Terminate_ToolStripButton.MergeIndex = -1
$ProcList_Terminate_ToolStripButton.Name = "ProcList_Terminate_ToolStripButton"
#$ProcList_Terminate_ToolStripButton.Overflow = [System.Windows.Forms.ToolStripItemOverflow]::AsNeeded
#$ProcList_Terminate_ToolStripButton.Padding = New-Object -TypeName System.Windows.Forms.Padding(0, 0, 0, 0)
#$ProcList_Terminate_ToolStripButton.RightToLeft = [System.Windows.Forms.RightToLeft]::Inherit
#$ProcList_Terminate_ToolStripButton.RightToLeftAutoMirrorImage = $False
#$ProcList_Terminate_ToolStripButton.Size = New-Object -TypeName System.Drawing.Size(23, 23)
#$ProcList_Terminate_ToolStripButton.Tag = System.Object
$ProcList_Terminate_ToolStripButton.Text = "Terminate"
#$ProcList_Terminate_ToolStripButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#$ProcList_Terminate_ToolStripButton.TextImageRelation = [System.Windows.Forms.TextImageRelation]::ImageBeforeText
#$ProcList_Terminate_ToolStripButton.ToolTipText = ""
#$ProcList_Terminate_ToolStripButton.Visible = $False
#$ProcList_Terminate_ToolStripButton.Width = 23
#endregion

#region function Click-ProcList_Terminate_ToolStripButton
function Click-ProcList_Terminate_ToolStripButton()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Terminate_ToolStripButton Control
    .DESCRIPTION
      Click event for the ProcList_Terminate_ToolStripButton Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Terminate_ToolStripButton -Sender $ProcList_Terminate_ToolStripButton -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object]$Sender,
    [parameter(Mandatory=$True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Terminate_ToolStripButton"
  Try
  {
    Click-ProcList_Terminate_Button -Sender $Sender -EventArg $EventArg
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit Click Event for `$ProcList_Terminate_ToolStripButton"
}
#endregion
$ProcList_Terminate_ToolStripButton.add_Click({Click-ProcList_Terminate_ToolStripButton -Sender $ProcList_Terminate_ToolStripButton -EventArg $_})

#endregion

#endregion

#region ******** $ProcList_Form Buttons ********

#region $ProcList_Add_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$ProcList_Add_Button"
$ProcList_Add_Button = New-Object -TypeName System.Windows.Forms.Button
$ProcList_Form.Controls.Add($ProcList_Add_Button)
$ProcList_Add_Button.AutoSize = $True
$ProcList_Add_Button.BackColor = [System.Drawing.Color]::LightGray
$ProcList_Add_Button.Font = New-Object -TypeName System.Drawing.Font($ProcList_Form.Font.FontFamily, $ProcList_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$ProcList_Add_Button.ForeColor = [System.Drawing.Color]::Black
$ProcList_Add_Button.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($ProcList_ListView.Bottom + $FormSpacer))
$ProcList_Add_Button.Name = "ProcList_Add_Button"
$ProcList_Add_Button.Text = "Add"
$ProcList_Add_Button.Width = ($ProcList_Form.ClientSize.Width - ($FormSpacer * 8)) / 7
#$ProcList_Add_Button.Width = ($ProcList_Form.ClientSize.Width - ($FormSpacer * 7)) / 6
#endregion
$ProcList_ToolTip.SetToolTip($ProcList_Add_Button, "Help for Control $($ProcList_Add_Button.Name)")

#region function Click-ProcList_Add_Button
function Click-ProcList_Add_Button()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Add_Button Control
    .DESCRIPTION
      Click event for the ProcList_Add_Button Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Add_Button -Sender $ProcList_Add_Button -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Add_Button"
  Try
  {
    if ($AddList_Form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
    {
      $ProcList_ListView.ListViewItemSorter.SortEnable = $False
      $Script:TempLoad = @($AddList_TextBox.Text.Split(@(" ", ",", "`t", "`r", "`n"), [System.StringSplitOptions]::RemoveEmptyEntries))
      if ($Script:TempLoad.Count -gt 0)
      {
        $Loading_Form.Tag = 0
        $Loading_Form.ShowDialog()
      }
    }
    $ProcList_ListView.ListViewItemSorter.SortEnable = $True
    $ProcList_ListView.Sort()
    [System.Media.SystemSounds]::Exclamation.Play()
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
    [System.Media.SystemSounds]::Beep.Play()
    $ProcList_ListView.EndUpdate()
    $ProcList_ListView.ListViewItemSorter.SortEnable = $True
  }
  $Script:TempLoad = $Null
  $Item = $Null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
  Write-Verbose -Message "Exit Click Event for `$ProcList_Add_Button"
}
#endregion
$ProcList_Add_Button.add_Click({ Click-ProcList_Add_Button -Sender $ProcList_Add_Button -EventArg $_ })

#region $ProcList_Load_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$ProcList_Load_Button"
$ProcList_Load_Button = New-Object -TypeName System.Windows.Forms.Button
$ProcList_Form.Controls.Add($ProcList_Load_Button)
$ProcList_Load_Button.AutoSize = $True
$ProcList_Load_Button.BackColor = [System.Drawing.Color]::LightGray
$ProcList_Load_Button.Font = New-Object -TypeName System.Drawing.Font($ProcList_Form.Font.FontFamily, $ProcList_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$ProcList_Load_Button.ForeColor = [System.Drawing.Color]::Black
$ProcList_Load_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Add_Button.Right + $FormSpacer), ($ProcList_ListView.Bottom + $FormSpacer))
$ProcList_Load_Button.Name = "ProcList_Load_Button"
$ProcList_Load_Button.Text = "Load"
$ProcList_Load_Button.Width = $ProcList_Add_Button.Width
#endregion
$ProcList_ToolTip.SetToolTip($ProcList_Load_Button, "Help for Control $($ProcList_Load_Button.Name)")

#region function Click-ProcList_Load_Button
function Click-ProcList_Load_Button()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Load_Button Control
    .DESCRIPTION
      Click event for the ProcList_Load_Button Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Load_Button -Sender $ProcList_Load_Button -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Load_Button"
  Try
  {
    $ProcList_OpenFileDialog.FileName = $Null
    $ProcList_ListView.ListViewItemSorter.SortEnable = $False
    if ($ProcList_ListView.Items.Count -gt 0)
    {
      if ([System.Windows.Forms.MessageBox]::Show("Clear Process Workstation List Results Window?", "Clear Results", "YesNo", "Question") -eq [System.Windows.Forms.DialogResult]::Yes)
      {
        $ProcList_ListView.Items.Clear()
        $ProcList_ListView.Tag = @()
      }
    }
    if ($ProcList_OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
    {
      Switch ([System.IO.Path]::GetExtension($ProcList_OpenFileDialog.FileName))
      {
        ".txt"
        {
          $Script:TempLoad = @(Get-Content -Path $ProcList_OpenFileDialog.FileName)
          if ($Script:TempLoad.Count -gt 0)
          {
            $Loading_Form.Tag = 0
            $Loading_Form.ShowDialog()
          }
          break
        }
        ".csv"
        {
          $Script:TempLoad = @(Import-Csv -Path $ProcList_OpenFileDialog.FileName)
          if ($Script:TempLoad.Count -gt 0)
          {
            $Loading_Form.Tag = 1
            $Loading_Form.ShowDialog()
          }
          break
        }
        ".xml"
        {
          $Script:TempLoad = @(Import-Clixml -Path $ProcList_OpenFileDialog.FileName)
          if ($Script:TempLoad.Count -gt 0)
          {
            $Loading_Form.Tag = 1
            $Loading_Form.ShowDialog()
          }
          break
        }
      }
    }
    $ProcList_ListView.ListViewItemSorter.SortEnable = $True
    $ProcList_ListView.Sort()
    [System.Media.SystemSounds]::Exclamation.Play()
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
    [System.Media.SystemSounds]::Beep.Play()
    $ProcList_ListView.EndUpdate()
    $ProcList_ListView.ListViewItemSorter.SortEnable = $True
  }
  $Script:TempLoad = $Null
  $Item = $Null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
  Write-Verbose -Message "Exit Click Event for `$ProcList_Load_Button"
}
#endregion
$ProcList_Load_Button.add_Click({ Click-ProcList_Load_Button -Sender $ProcList_Load_Button -EventArg $_ })

#region $ProcList_Script_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$ProcList_Script_Button"
$ProcList_Script_Button = New-Object -TypeName System.Windows.Forms.Button
$ProcList_Form.Controls.Add($ProcList_Script_Button)
$ProcList_Script_Button.AutoSize = $True
$ProcList_Script_Button.BackColor = [System.Drawing.Color]::LightGray
$ProcList_Script_Button.Font = New-Object -TypeName System.Drawing.Font($ProcList_Form.Font.FontFamily, $ProcList_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$ProcList_Script_Button.ForeColor = [System.Drawing.Color]::Black
$ProcList_Script_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Load_Button.Right + $FormSpacer), ($ProcList_ListView.Bottom + $FormSpacer))
$ProcList_Script_Button.Name = "ProcList_Script_Button"
$ProcList_Script_Button.Text = "Configure"
$ProcList_Script_Button.Width = $ProcList_Add_Button.Width
#endregion
$ProcList_ToolTip.SetToolTip($ProcList_Script_Button, "Help for Control $($ProcList_Script_Button.Name)")

#region function Click-ProcList_Script_Button
function Click-ProcList_Script_Button()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Script_Button Control
    .DESCRIPTION
      Click event for the ProcList_Script_Button Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Script_Button -Sender $ProcList_Script_Button -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Script_Button"
  Try
  {
    if ($Config_Form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
    {
      $Script:CodeBlock = $Config_TextBox.Text
      $Config_Form.Tag = $Config_GroupBox.Tag
      if ([String]::IsNullOrEmpty($Config_Simon_TextBox.Text.Trim()))
      {
        $Config_Simon_TextBox.Tag = "Simon"
      }
      else
      {
        $Config_Simon_TextBox.Tag = $Config_Simon_TextBox.Text.Trim()
      }
      if ([String]::IsNullOrEmpty($Config_Garfunkel_TextBox.Text.Trim()))
      {
        $Config_Garfunkel_TextBox.Tag = "Garfunkel"
      }
      else
      {
        $Config_Garfunkel_TextBox.Tag = $Config_Garfunkel_TextBox.Text.Trim()
      }
      if ([String]::IsNullOrEmpty($Config_Parsley_TextBox.Text.Trim()))
      {
        $Config_Parsley_TextBox.Tag = "Parsley"
      }
      else
      {
        $Config_Parsley_TextBox.Tag = $Config_Parsley_TextBox.Text.Trim()
      }
      if ([String]::IsNullOrEmpty($Config_Sage_TextBox.Text.Trim()))
      {
        $Config_Sage_TextBox.Tag = "Sage"
      }
      else
      {
        $Config_Sage_TextBox.Tag = $Config_Sage_TextBox.Text.Trim()
      }
      if ([String]::IsNullOrEmpty($Config_Rosemary_TextBox.Text.Trim()))
      {
        $Config_Rosemary_TextBox.Tag = "Rosemary"
      }
      else
      {
        $Config_Rosemary_TextBox.Tag = $Config_Rosemary_TextBox.Text.Trim()
      }
      $ProcList_Simon_ColumnHeader.Text = $Config_Simon_TextBox.Tag
      $ProcList_Garfunkel_ColumnHeader.Text = $Config_Garfunkel_TextBox.Tag
      $ProcList_Parsley_ColumnHeader.Text = $Config_Parsley_TextBox.Tag
      $ProcList_Sage_ColumnHeader.Text = $Config_Sage_TextBox.Tag
      $ProcList_Rosemary_ColumnHeader.Text = $Config_Rosemary_TextBox.Tag
      ForEach ($Column in $ProcList_ListView.Columns)
      {
        $Column.AutoResize("HeaderSize")
      }
    }
    $ProcList_ListView.Sort()
    [System.Media.SystemSounds]::Exclamation.Play()
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
    [System.Media.SystemSounds]::Beep.Play()
  }
  $Item = $Null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
  Write-Verbose -Message "Exit Click Event for `$ProcList_Script_Button"
}
#endregion
$ProcList_Script_Button.add_Click({ Click-ProcList_Script_Button -Sender $ProcList_Script_Button -EventArg $_ })

#region $ProcList_Process_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$ProcList_Process_Button"
$ProcList_Process_Button = New-Object -TypeName System.Windows.Forms.Button
$ProcList_Form.Controls.Add($ProcList_Process_Button)
$ProcList_Process_Button.AutoSize = $True
$ProcList_Process_Button.BackColor = [System.Drawing.Color]::LightGray
$ProcList_Process_Button.Font = New-Object -TypeName System.Drawing.Font($ProcList_Form.Font.FontFamily, $ProcList_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$ProcList_Process_Button.ForeColor = [System.Drawing.Color]::Black
$ProcList_Process_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Script_Button.Right + $FormSpacer), ($ProcList_ListView.Bottom + $FormSpacer))
$ProcList_Process_Button.Name = "ProcList_Process_Button"
$ProcList_Process_Button.Text = "Process"
$ProcList_Process_Button.Width = $ProcList_Add_Button.Width
#endregion
$ProcList_ToolTip.SetToolTip($ProcList_Process_Button, "Help for Control $($ProcList_Process_Button.Name)")

#region function Click-ProcList_Process_Button
function Click-ProcList_Process_Button()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Process_Button Control
    .DESCRIPTION
      Click event for the ProcList_Process_Button Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Process_Button -Sender $ProcList_Process_Button -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Process_Button"
  Try
  {
    if ($ProcList_ListView.Items.Count -gt 0)
    {
      if ([System.Windows.Forms.MessageBox]::Show("Process Workstation List?", "Process List", "YesNo", "Question") -eq [System.Windows.Forms.DialogResult]::Yes)
      {
        $ProcList_ListView.ListViewItemSorter.SortEnable = $False
        $FormText = $ProcList_Form.Text
        $ProcList_Add_Button.Enabled = $False
        $ProcList_Load_Button.Enabled = $False
        $ProcList_Script_Button.Enabled = $False
        $ProcList_Process_Button.Enabled = $False
        $ProcList_Export_Button.Enabled = $False
        $ProcList_Clear_Button.Enabled = $False
        $ProcList_Process_ToolStripButton.Enabled = $False
        $ProcList_Export_ToolStripButton.Enabled = $False
        $ProcList_Clear_ToolStripButton.Enabled = $False
        
        # 01 - OnLine
        # 02 - IP Address
        # 03 - WMI Status
        # 04 - WMI Protocol
        # 05 - WMI Name
        # 06 - UserName
        # 07 - Operating System
        # 08 - Serivce Pack
        # 09 - Architecture
        # 10 - Job Status
        # 11 - Simon
        # 12 - Garfunkel
        # 13 - Parsley
        # 14 - Sage
        # 15 - Rosemary
        # 16 - Time
        # 17 - Date
        # 18 - Error Message
        
        if ($Sender.GetType().Name -eq "Button")
        {
          $TempProcList = @($ProcList_ListView.Items | Where-Object -FilterScript { $_.SubItems[10].Text -ne "Done" })
        }
        else
        {
          $TempProcList = @($ProcList_ListView.SelectedItems | Where-Object -FilterScript { $_.SubItems[10].Text -ne "Done" })
        }

        if ($TempProcList.Count)
        {
          $ProcList_Form.Text = "$FormText - Working..."
          $Script:ThreadCommand = @{"Kill"=$False}
          if ((Create-MyRunspace -MaxPools $Config_Form.Tag))
          {
            $ListThreads = @()
            $TempThreadScript = [System.Management.Automation.ScriptBlock]::Create(($Script:ThreadScript.Replace("#CodeBlock#", $Script:CodeBlock)))
            ForEach ($Item in $TempProcList)
            {
              $ListThreads += Start-MyThread -ScriptBlock $TempThreadScript -Parameters @{ "Item"=$Item; "ThreadCommand"=$Script:ThreadCommand }
            }
            $ProcList_Terminate_Button.Enabled = $True
            $ProcList_Terminate_ToolStripButton.Enabled = $True
            $ReturnedData = Wait-MyThread -Threads $ListThreads
          }
        }

        $ProcList_Terminate_ToolStripButton.Enabled = $False
        $ProcList_Terminate_Button.Enabled = $False

        $ProcList_Process_ToolStripButton.Enabled = $True
        $ProcList_Export_ToolStripButton.Enabled = $True
        $ProcList_Clear_ToolStripButton.Enabled = $True
        
        $ProcList_Script_Button.Enabled = $True
        $ProcList_Load_Button.Enabled = $True
        $ProcList_Add_Button.Enabled = $True
        $ProcList_Process_Button.Enabled = $True
        $ProcList_Export_Button.Enabled = $True
        $ProcList_Form.Text = $FormText
        $ProcList_Clear_Button.Enabled = $True
        $ProcList_ListView.ListViewItemSorter.SortEnable = $True
      }
    }
    [System.Media.SystemSounds]::Exclamation.Play()
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
    [System.Media.SystemSounds]::Beep.Play()
    $ProcList_ListView.ListViewItemSorter.SortEnable = $True
  }
  $TempThreadScript = $Null
  $TempProcList = $Null
  $Item = $Null
  $Script:MyRunspace = $Null
  $ListThreads = $Null
  $ReturnedData = $Null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
  Write-Verbose -Message "Exit Click Event for `$ProcList_Process_Button"
}
#endregion
$ProcList_Process_Button.add_Click({ Click-ProcList_Process_Button -Sender $ProcList_Process_Button -EventArg $_ })

#region $ProcList_Export_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$ProcList_Export_Button"
$ProcList_Export_Button = New-Object -TypeName System.Windows.Forms.Button
$ProcList_Form.Controls.Add($ProcList_Export_Button)
$ProcList_Export_Button.AutoSize = $True
$ProcList_Export_Button.BackColor = [System.Drawing.Color]::LightGray
$ProcList_Export_Button.Font = New-Object -TypeName System.Drawing.Font($ProcList_Form.Font.FontFamily, $ProcList_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$ProcList_Export_Button.ForeColor = [System.Drawing.Color]::Black
$ProcList_Export_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Process_Button.Right + $FormSpacer), ($ProcList_ListView.Bottom + $FormSpacer))
$ProcList_Export_Button.Name = "ProcList_Export_Button"
$ProcList_Export_Button.Text = "Export"
$ProcList_Export_Button.Width = $ProcList_Add_Button.Width
#endregion
$ProcList_ToolTip.SetToolTip($ProcList_Export_Button, "Help for Control $($ProcList_Export_Button.Name)")

#region function Click-ProcList_Export_Button
function Click-ProcList_Export_Button()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Export_Button Control
    .DESCRIPTION
      Click event for the ProcList_Export_Button Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Export_Button -Sender $ProcList_Export_Button -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Export_Button"
  Try
  {
    if ($ProcList_ListView.Items.Count -gt 0)
    {
      if ([System.Windows.Forms.MessageBox]::Show("Export Results with Alternate Column Names?`r`n`r`nResults Exported using the Configured Alternate Column Names can not be Re-Loaded Unless the Alternate Column Names have been Re-Configured to Match the Export Prior to Loading.", "Export Results", "YesNo", "Question") -eq [System.Windows.Forms.DialogResult]::Yes)
      {
        $AltExport = $True
      }
      else
      {
        $AltExport = $False
      }
      $ProcList_SaveFileDialog.FileName = $Null
      if ($ProcList_SaveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
      {
        $TempExport = @()
        if ($Sender.GetType().Name -eq "Button")
        {
          if ($AltExport)
          {
            $TempExport = @($ProcList_ListView.Items | ForEach-Object -Process {[PSCustomObject][Ordered]@{ "Workstation" = $($PSItem.SubItems[0].Text); "OnLine" = $($PSItem.SubItems[1].Text); "IPAddress" = $($PSItem.SubItems[2].Text); "WMIStatus" = $($PSItem.SubItems[3].Text); "WMIProtocol" = $($PSItem.SubItems[4].Text); "WMIName" = $($PSItem.SubItems[5].Text); "UserName" = $($PSItem.SubItems[6].Text); "OperatingSystem" = $($PSItem.SubItems[7].Text); "ServicePack" = $($PSItem.SubItems[8].Text); "Architecture" = $($PSItem.SubItems[9].Text); "JobStatus" = $($PSItem.SubItems[10].Text); "$($Config_Simon_TextBox.Tag)" = $($PSItem.SubItems[11].Text); "$($Config_Garfunkel_TextBox.Tag)" = $($PSItem.SubItems[12].Text); "$($Config_Parsley_TextBox.Tag)" = $($PSItem.SubItems[13].Text); "$($Config_Sage_TextBox.Tag)" = $($PSItem.SubItems[14].Text); "$($Config_Rosemary_TextBox.Tag)" = $($PSItem.SubItems[15].Text); "Time" = $($PSItem.SubItems[16].Text); "Date" = $($PSItem.SubItems[17].Text); "ErrorMessage" = $($PSItem.SubItems[18].Text) }})
          }
          else
          {
            $TempExport = @($ProcList_ListView.Items | ForEach-Object -Process {[PSCustomObject][Ordered]@{ "Workstation" = $($PSItem.SubItems[0].Text); "OnLine" = $($PSItem.SubItems[1].Text); "IPAddress" = $($PSItem.SubItems[2].Text); "WMIStatus" = $($PSItem.SubItems[3].Text); "WMIProtocol" = $($PSItem.SubItems[4].Text); "WMIName" = $($PSItem.SubItems[5].Text); "UserName" = $($PSItem.SubItems[6].Text); "OperatingSystem" = $($PSItem.SubItems[7].Text); "ServicePack" = $($PSItem.SubItems[8].Text); "Architecture" = $($PSItem.SubItems[9].Text); "JobStatus" = $($PSItem.SubItems[10].Text); "Simon" = $($PSItem.SubItems[11].Text); "Garfunkel" = $($PSItem.SubItems[12].Text); "Parsley" = $($PSItem.SubItems[13].Text); "Sage" = $($PSItem.SubItems[14].Text); "Rosemary" = $($PSItem.SubItems[15].Text); "Time" = $($PSItem.SubItems[16].Text); "Date" = $($PSItem.SubItems[17].Text); "ErrorMessage" = $($PSItem.SubItems[18].Text)}})
          }
        }
        else
        {
          if ($AltExport)
          {
            $TempExport = @($ProcList_ListView.SelectedItems | ForEach-Object -Process {[PSCustomObject][Ordered]@{ "Workstation" = $($PSItem.SubItems[0].Text); "OnLine" = $($PSItem.SubItems[1].Text); "IPAddress" = $($PSItem.SubItems[2].Text); "WMIStatus" = $($PSItem.SubItems[3].Text); "WMIProtocol" = $($PSItem.SubItems[4].Text); "WMIName" = $($PSItem.SubItems[5].Text); "UserName" = $($PSItem.SubItems[6].Text); "OperatingSystem" = $($PSItem.SubItems[7].Text); "ServicePack" = $($PSItem.SubItems[8].Text); "Architecture" = $($PSItem.SubItems[9].Text); "JobStatus" = $($PSItem.SubItems[10].Text); "$($Config_Simon_TextBox.Tag)" = $($PSItem.SubItems[11].Text); "$($Config_Garfunkel_TextBox.Tag)" = $($PSItem.SubItems[12].Text); "$($Config_Parsley_TextBox.Tag)" = $($PSItem.SubItems[13].Text); "$($Config_Sage_TextBox.Tag)" = $($PSItem.SubItems[14].Text); "$($Config_Rosemary_TextBox.Tag)" = $($PSItem.SubItems[15].Text); "Time" = $($PSItem.SubItems[16].Text); "Date" = $($PSItem.SubItems[17].Text); "ErrorMessage" = $($PSItem.SubItems[18].Text) }})
          }
          else
          {
            $TempExport = @($ProcList_ListView.SelectedItems | ForEach-Object -Process {[PSCustomObject][Ordered]@{ "Workstation" = $($PSItem.SubItems[0].Text); "OnLine" = $($PSItem.SubItems[1].Text); "IPAddress" = $($PSItem.SubItems[2].Text); "WMIStatus" = $($PSItem.SubItems[3].Text); "WMIProtocol" = $($PSItem.SubItems[4].Text); "WMIName" = $($PSItem.SubItems[5].Text); "UserName" = $($PSItem.SubItems[6].Text); "OperatingSystem" = $($PSItem.SubItems[7].Text); "ServicePack" = $($PSItem.SubItems[8].Text); "Architecture" = $($PSItem.SubItems[9].Text); "JobStatus" = $($PSItem.SubItems[10].Text); "Simon" = $($PSItem.SubItems[11].Text); "Garfunkel" = $($PSItem.SubItems[12].Text); "Parsley" = $($PSItem.SubItems[13].Text); "Sage" = $($PSItem.SubItems[14].Text); "Rosemary" = $($PSItem.SubItems[15].Text); "Time" = $($PSItem.SubItems[16].Text); "Date" = $($PSItem.SubItems[17].Text); "ErrorMessage" = $($PSItem.SubItems[18].Text)}})
          }
        }
        Switch ([System.IO.Path]::GetExtension($ProcList_SaveFileDialog.FileName))
        {
          ".csv"
          {
            $TempExport | Export-Csv -NoTypeInformation -Encoding Ascii -Force -Path $ProcList_SaveFileDialog.FileName
            break
          }
          ".xml"
          {
            $TempExport | Export-Clixml -Encoding Ascii -Force -Path $ProcList_SaveFileDialog.FileName
            break
          }
          Default
          {
            Switch ($ProcList_SaveFileDialog.FilterIndex)
            {
              1
              {
                $TempExport | Export-Csv -NoTypeInformation -Encoding Ascii -Force -Path "$($ProcList_SaveFileDialog.FileName).csv"
                break
              }
              2
              {
                $TempExport | Export-Clixml -Encoding Ascii -Force -Path "$($ProcList_SaveFileDialog.FileName).xml"
                break
              }
            }
            break
          }
        }
      }
    }
    [System.Media.SystemSounds]::Exclamation.Play()
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
    [System.Media.SystemSounds]::Beep.Play()
  }
  $TempExport = $Null
  $Item = $Null
  [System.GC]::Collect()
  [System.GC]::WaitForPendingFinalizers()
  Write-Verbose -Message "Exit Click Event for `$ProcList_Export_Button"
}
#endregion
$ProcList_Export_Button.add_Click({ Click-ProcList_Export_Button -Sender $ProcList_Export_Button -EventArg $_ })

#region $ProcList_Clear_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$ProcList_Clear_Button"
$ProcList_Clear_Button = New-Object -TypeName System.Windows.Forms.Button
$ProcList_Form.Controls.Add($ProcList_Clear_Button)
$ProcList_Clear_Button.AutoSize = $True
$ProcList_Clear_Button.BackColor = [System.Drawing.Color]::LightGray
$ProcList_Clear_Button.Font = New-Object -TypeName System.Drawing.Font($ProcList_Form.Font.FontFamily, $ProcList_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$ProcList_Clear_Button.ForeColor = [System.Drawing.Color]::Black
$ProcList_Clear_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Export_Button.Right + $FormSpacer), ($ProcList_ListView.Bottom + $FormSpacer))
$ProcList_Clear_Button.Name = "ProcList_Clear_Button"
$ProcList_Clear_Button.Text = "Clear"
$ProcList_Clear_Button.Width = $ProcList_Add_Button.Width
#endregion
$ProcList_ToolTip.SetToolTip($ProcList_Clear_Button, "Help for Control $($ProcList_Clear_Button.Name)")

#region function Click-ProcList_Clear_Button
function Click-ProcList_Clear_Button()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Clear_Button Control
    .DESCRIPTION
      Click event for the ProcList_Clear_Button Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Clear_Button -Sender $ProcList_Clear_Button -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Clear_Button"
  Try
  {
    if ($ProcList_ListView.Items.Count -gt 0)
    {
      $Script:TempLoad = @()
      if ([System.Windows.Forms.MessageBox]::Show("Clear Workstation List too?", "Clear Results", "YesNo", "Question") -eq [System.Windows.Forms.DialogResult]::No)
      {
        $Script:TempLoad = @($ProcList_ListView.Items | Select-Object -ExpandProperty Text)
      }
      $ProcList_ListView.Items.Clear()
      $ProcList_ListView.Tag = @()
      if ($Script:TempLoad.Count -gt 0)
      {
        $ProcList_ListView.ListViewItemSorter.SortEnable = $False
        $Loading_Form.Tag = 0
        $Loading_Form.ShowDialog()
        $ProcList_ListView.ListViewItemSorter.SortEnable = $True
      }
    }
    [System.Media.SystemSounds]::Exclamation.Play()
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
    [System.Media.SystemSounds]::Beep.Play()
  }
  Write-Verbose -Message "Exit Click Event for `$ProcList_Clear_Button"
}
#endregion
$ProcList_Clear_Button.add_Click({ Click-ProcList_Clear_Button -Sender $ProcList_Clear_Button -EventArg $_ })

#region $ProcList_Terminate_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$ProcList_Terminate_Button"
$ProcList_Terminate_Button = New-Object -TypeName System.Windows.Forms.Button
$ProcList_Form.Controls.Add($ProcList_Terminate_Button)
$ProcList_Terminate_Button.AutoSize = $True
$ProcList_Terminate_Button.BackColor = [System.Drawing.Color]::LightGray
$ProcList_Terminate_Button.Enabled = $False
$ProcList_Terminate_Button.Font = New-Object -TypeName System.Drawing.Font($ProcList_Form.Font.FontFamily, $ProcList_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$ProcList_Terminate_Button.ForeColor = [System.Drawing.Color]::Black
$ProcList_Terminate_Button.Location = New-Object -TypeName System.Drawing.Point(($ProcList_Clear_Button.Right + $FormSpacer), ($ProcList_ListView.Bottom + $FormSpacer))
$ProcList_Terminate_Button.Name = "ProcList_Terminate_Button"
$ProcList_Terminate_Button.Text = "Terminate"
$ProcList_Terminate_Button.Width = $ProcList_Add_Button.Width
#endregion
$ProcList_ToolTip.SetToolTip($ProcList_Terminate_Button, "Help for Control $($ProcList_Terminate_Button.Name)")

#region function Click-ProcList_Terminate_Button
function Click-ProcList_Terminate_Button()
{
  <#
    .SYNOPSIS
      Click event for the ProcList_Terminate_Button Control
    .DESCRIPTION
      Click event for the ProcList_Terminate_Button Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Click-ProcList_Terminate_Button -Sender $ProcList_Terminate_Button -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Click Event for `$ProcList_Terminate_Button"
  Try
  {
    $Script:ThreadCommand.Kill = $True
    $ProcList_Terminate_Button.Enabled = $False
    $ProcList_Terminate_ToolStripButton.Enabled = $False
    $ProcList_Form.Text = "$($ProcList_Form.Text) - Terminating..."
    [System.Media.SystemSounds]::Exclamation.Play()
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
    [System.Media.SystemSounds]::Beep.Play()
  }
  Write-Verbose -Message "Exit Click Event for `$ProcList_Terminate_Button"
}
#endregion
$ProcList_Terminate_Button.add_Click({Click-ProcList_Terminate_Button -Sender $ProcList_Terminate_Button -EventArg $_})

#endregion


$ProcList_Form.ClientSize = New-Object -TypeName System.Drawing.Size(($($ProcList_Form.Controls[$ProcList_Form.Controls.Count - 1]).Right + $FormSpacer), ($($ProcList_Form.Controls[$ProcList_Form.Controls.Count - 1]).Bottom + $FormSpacer))
$ProcList_Form.MinimumSize = $ProcList_Form.Size

#region $ProcList_OpenFileDialog = System.Windows.Forms.OpenFileDialog
Write-Verbose -Message "Creating Form Control `$ProcList_OpenFileDialog"
$ProcList_OpenFileDialog = New-Object -TypeName System.Windows.Forms.OpenFileDialog
$ProcList_OpenFileDialog.Filter = "All Supported|*.txt;*.csv;*.xml|Text List|*.txt|CSV Export File|*.csv|XML Export File|*.xml"
$ProcList_OpenFileDialog.ShowHelp = $True
$ProcList_OpenFileDialog.SupportMultiDottedExtensions = $True
$ProcList_OpenFileDialog.Title = ""
#endregion

#region $ProcList_SaveFileDialog = System.Windows.Forms.SaveFileDialog
Write-Verbose -Message "Creating Form Control `$ProcList_SaveFileDialog"
$ProcList_SaveFileDialog = New-Object -TypeName System.Windows.Forms.SaveFileDialog
$ProcList_SaveFileDialog.Filter = "CSV Export File|*.csv|XML Export File|*.xml"
$ProcList_SaveFileDialog.ShowHelp = $True
$ProcList_SaveFileDialog.SupportMultiDottedExtensions = $True
#endregion

#endregion

#endregion

#region ******** Config Script Dialog ********

#region $Config_ToolTip = System.Windows.Forms.ToolTip
Write-Verbose -Message "Creating Form Control `$Config_ToolTip"
$Config_ToolTip = New-Object -TypeName System.Windows.Forms.ToolTip($FormComponents)
#$Config_ToolTip.Active = $True
#$Config_ToolTip.AutomaticDelay = 500
#$Config_ToolTip.AutoPopDelay = 5000
#$Config_ToolTip.BackColor = [System.Drawing.SystemColors]::Info
#$Config_ToolTip.ForeColor = [System.Drawing.SystemColors]::InfoText
#$Config_ToolTip.InitialDelay = 500
#$Config_ToolTip.IsBalloon = $False
#$Config_ToolTip.OwnerDraw = $False
#$Config_ToolTip.ReshowDelay = 100
#$Config_ToolTip.ShowAlways = $False
#$Config_ToolTip.StripAmpersands = $False
#$Config_ToolTip.Tag = System.Object
#$Config_ToolTip.ToolTipIcon = [System.Windows.Forms.ToolTipIcon]::None
$Config_ToolTip.ToolTipTitle = "$ScriptName - $ScriptVersion"
#$Config_ToolTip.UseAnimation = $True
#$Config_ToolTip.UseFading = $True
#endregion
#$Config_ToolTip.SetToolTip($FormControl, "Form Control Help")

#region $Config_Form = System.Windows.Forms.Form
Write-Verbose -Message "Creating Form Control `$Config_Form"
$Config_Form = New-Object -TypeName System.Windows.Forms.Form
$Config_Form.BackColor = [System.Drawing.Color]::Black
$Config_Form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$Config_Form.Font = New-Object -TypeName System.Drawing.Font("Verdana", (8 * (96 / ($Config_Form.CreateGraphics()).DpiX)), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
$Config_Form.ForeColor = [System.Drawing.Color]::White
$Config_Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
$Config_Form.Name = "Config_Form"
$Config_Form.ShowInTaskbar = $False
$Config_Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
$Config_Form.Tag = 8
$Config_Form.Text = "$ScriptName - $ScriptVersion"
#endregion
$Config_ToolTip.SetToolTip($Config_Form, "Help for Control $($Config_Form.Name)")

#region function Shown-Config_Form
function Shown-Config_Form()
{
  <#
    .SYNOPSIS
      Shown event for the Config_Form Control
    .DESCRIPTION
      Shown event for the Config_Form Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Shown-Config_Form -Sender $Config_Form -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Shown Event for `$Config_Form"
  Try
  {
    $Config_ComboBox.SelectedIndex = 0
    $Config_TextBox.Text = $Script:CodeBlock
    $Config_TrackBar.Value = $Config_Form.Tag
    $Config_Simon_TextBox.Text = $Config_Simon_TextBox.Tag
    $Config_Garfunkel_TextBox.Text = $Config_Garfunkel_TextBox.Tag
    $Config_Parsley_TextBox.Text = $Config_Parsley_TextBox.Tag
    $Config_Sage_TextBox.Text = $Config_Sage_TextBox.Tag
    $Config_Rosemary_TextBox.Text = $Config_Rosemary_TextBox.Tag
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit Shown Event for `$Config_Form"
}
#endregion
$Config_Form.add_Shown({ Shown-Config_Form -Sender $Config_Form -EventArg $_ })

#region ******** $Config_Form Controls ********

#region $Config_Label = System.Windows.Forms.Label
Write-Verbose -Message "Creating Form Control `$Config_Label"
$Config_Label = New-Object -TypeName System.Windows.Forms.Label
$Config_Form.Controls.Add($Config_Label)
$Config_Label.BackColor = [System.Drawing.Color]::Gray
$Config_Label.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$Config_Label.Font = New-Object -TypeName System.Drawing.Font($Config_Form.Font.FontFamily, ($Config_Form.Font.Size + 3), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$Config_Label.ForeColor = [System.Drawing.Color]::Black
$Config_Label.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, $FormSpacer)
$Config_Label.Name = "Config_Label"
$Config_Label.Text = "Configure Workstation Script"
$Config_Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#endregion
$TempHeight = $Config_Label.Height
$Config_Label.AutoSize = $False
$Config_Label.Size = New-Object -TypeName System.Drawing.Size(800, $TempHeight)

#region $Config_TextBox = System.Windows.Forms.TextBox
Write-Verbose -Message "Creating Form Control `$Config_TextBox"
$Config_TextBox = New-Object -TypeName System.Windows.Forms.TextBox
$Config_Form.Controls.Add($Config_TextBox)
$Config_TextBox.BackColor = [System.Drawing.Color]::White
$Config_TextBox.Font = New-Object -TypeName System.Drawing.Font("Courier New", 8, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
$Config_TextBox.ForeColor = [System.Drawing.Color]::Black
$Config_TextBox.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($Config_Label.Bottom + $FormSpacer))
$Config_TextBox.MaxLength = 65535
$Config_TextBox.Multiline = $True
$Config_TextBox.Name = "Config_TextBox"
$Config_TextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
$Config_TextBox.Size = New-Object -TypeName System.Drawing.Size($Config_Label.Width, 200)
$Config_TextBox.Text = ""
$Config_TextBox.WordWrap = $False
#endregion
$Config_ToolTip.SetToolTip($Config_TextBox, "Help for Control $($Config_TextBox.Name)")

#region function KeyDown-Config_TextBox
function KeyDown-Config_TextBox()
{
  <#
    .SYNOPSIS
      KeyDown event for the Config_TextBox Control
    .DESCRIPTION
      KeyDown event for the Config_TextBox Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       KeyDown-Config_TextBox -Sender $Config_TextBox -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object]$Sender,
    [parameter(Mandatory=$True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter KeyDown Event for `$Config_TextBox"
  Try
  {
    if ($EventArg.Control -and $EventArg.KeyCode -eq "A")
    {
      $EventArg.Handled = $True
      $Config_TextBox.SelectionStart = 0
      $Config_TextBox.SelectionLength = $Config_TextBox.Text.Length
    }
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit KeyDown Event for `$Config_TextBox"
}
#endregion
$Config_TextBox.add_KeyDown({KeyDown-Config_TextBox -Sender $Config_TextBox -EventArg $_})

#region $Config_ComboBox = System.Windows.Forms.ComboBox
Write-Verbose -Message "Creating Form Control `$Config_ComboBox"
$Config_ComboBox = New-Object -TypeName System.Windows.Forms.ComboBox
$Config_Form.Controls.Add($Config_ComboBox)
$Config_ComboBox.AutoSize = $True
$Config_ComboBox.BackColor = [System.Drawing.Color]::Black
$Config_ComboBox.DisplayMember = "Text"
$Config_ComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$Config_ComboBox.ForeColor = [System.Drawing.Color]::White
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = " - Select Preconfigured Sample Script - "; "Value" = "$*$" }))
$Config_ComboBox.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($Config_TextBox.Bottom + $FormSpacer))
$Config_ComboBox.Name = "Config_ComboBox"
$Config_ComboBox.Sorted = $True
$Config_ComboBox.Text = "Config_ComboBox"
$Config_ComboBox.ValueMember = "Value"
$Config_ComboBox.Width = $Config_TextBox.Width
#endregion
$Config_ToolTip.SetToolTip($Config_ComboBox, "Help for Control $($Config_ComboBox.Name)")
$Config_ComboBox.SelectedIndex = 0

[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "Execute Task - Execute Command on Remote Workstation"; "Value" = "Execute" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "Query AD - Workstation Active Directory properties"; "Value" = "ADInfo" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "Query FileInfo - Local File Information Information"; "Value" = "FileInfo" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "Query WMI - Local C Drive Information"; "Value" = "DriveInfo" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "Service - Stop / Restart Remote Service"; "Value" = "StartStopService" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "SCCM - Refresh Client Policies"; "Value" = "SCCMClientPolicy" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "SCCM - SCCM Client Package In Cache"; "Value" = "SCCMClientInCache" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "SCCM - SCCM Client has Advertisement"; "Value" = "SCCMClientAdvert" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "Registry - Read and Write Remote Registry values"; "Value" = "Registry" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "Local Accounts - Get / Set Local Account Information"; "Value" = "LocalUsers" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "Network Settings - Get Network Card Settings"; "Value" = "NetworkSetting" }))
[Void]$Config_ComboBox.Items.Add((New-Object -TypeName PSObject -Property @{ "Text" = "Blank Empty Script"; "Value" = "BlankScript" }))

#region function SelectedIndexChanged-Config_ComboBox
function SelectedIndexChanged-Config_ComboBox()
{
  <#
    .SYNOPSIS
      SelectedIndexChanged event for the Config_ComboBox Control
    .DESCRIPTION
      SelectedIndexChanged event for the Config_ComboBox Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       SelectedIndexChanged-Config_ComboBox -Sender $Config_ComboBox -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter SelectedIndexChanged Event for `$Config_ComboBox"
  Try
  {
    if ($Config_ComboBox.SelectedIndex -gt 0)
    {
      Switch ($Config_ComboBox.SelectedItem.Value)
      {
        "DriveInfo"
        {
          $Config_TextBox.Text = $Script:DriveInfo
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "DeviceID"
          $Config_Garfunkel_TextBox.Text = "Size"
          $Config_Parsley_TextBox.Text = "Free Space"
          $Config_Sage_TextBox.Text = "Percent Free"
          $Config_Rosemary_TextBox.Text = "FileSystem"
          break
        }
        "ADInfo"
        {
          $Config_TextBox.Text = $Script:ADInfo
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "Operating System"
          $Config_Garfunkel_TextBox.Text = "Service Pack"
          $Config_Parsley_TextBox.Text = "PWD Last Set"
          $Config_Sage_TextBox.Text = "When Created"
          $Config_Rosemary_TextBox.Text = "When Changed"
          break
        }
        "FileInfo"
        {
          $Config_TextBox.Text = $Script:FileInfo
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "Path"
          $Config_Garfunkel_TextBox.Text = "Version"
          $Config_Parsley_TextBox.Text = "Creation Time"
          $Config_Sage_TextBox.Text = "Length"
          $Config_Rosemary_TextBox.Text = "Attributes"
          break
        }
        "Execute"
        {
          $Config_TextBox.Text = $Script:Execute
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "Return Value"
          $Config_Garfunkel_TextBox.Text = "Process ID"
          $Config_Parsley_TextBox.Text = "Parsley"
          $Config_Sage_TextBox.Text = "Sage"
          $Config_Rosemary_TextBox.Text = "Rosemary"
          break
        }
        "StartStopService"
        {
          $Config_TextBox.Text = $Script:StartStopService
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "Status"
          $Config_Garfunkel_TextBox.Text = "Garfunkel"
          $Config_Parsley_TextBox.Text = "Parsley"
          $Config_Sage_TextBox.Text = "Sage"
          $Config_Rosemary_TextBox.Text = "Rosemary"
          break
        }
        "BlankScript"
        {
          $Config_TextBox.Text = $Script:Blank
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "Simon"
          $Config_Garfunkel_TextBox.Text = "Garfunkel"
          $Config_Parsley_TextBox.Text = "Parsley"
          $Config_Sage_TextBox.Text = "Sage"
          $Config_Rosemary_TextBox.Text = "Rosemary"
          break
        }
        "SCCMClientPolicy"
        {
          $Config_TextBox.Text = $Script:SCCMClientPolicy
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "Simin"
          $Config_Garfunkel_TextBox.Text = "Garfunkel"
          $Config_Parsley_TextBox.Text = "Parsley"
          $Config_Sage_TextBox.Text = "Sage"
          $Config_Rosemary_TextBox.Text = "Rosemary"
          break
        }
        "SCCMClientInCache"
        {
          $Config_TextBox.Text = $Script:SCCMClientInCache
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "Simin"
          $Config_Garfunkel_TextBox.Text = "Garfunkel"
          $Config_Parsley_TextBox.Text = "Parsley"
          $Config_Sage_TextBox.Text = "Sage"
          $Config_Rosemary_TextBox.Text = "Rosemary"
          break
        }
        "SCCMClientAdvert"
        {
          $Config_TextBox.Text = $Script:SCCMClientAdvert
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "AdvertisementID"
          $Config_Garfunkel_TextBox.Text = "PackageID"
          $Config_Parsley_TextBox.Text = "ProgramID"
          $Config_Sage_TextBox.Text = "RepeatRunBehavior"
          $Config_Rosemary_TextBox.Text = "MandatoryAssignments"
          break
        }
        "Registry"
        {
          $Config_TextBox.Text = $Script:Registry
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "RegisteredOrganization"
          $Config_Garfunkel_TextBox.Text = "RegisteredOwner"
          $Config_Parsley_TextBox.Text = "Parsley"
          $Config_Sage_TextBox.Text = "WindowFrame"
          $Config_Rosemary_TextBox.Text = "InactiveTitle"
          break
        }
        "LocalUsers"
        {
          $Config_TextBox.Text = $Script:LocalUsers
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "Name"
          $Config_Garfunkel_TextBox.Text = "Description"
          $Config_Parsley_TextBox.Text = "Members"
          $Config_Sage_TextBox.Text = "GroupScope"
          $Config_Rosemary_TextBox.Text = "IsSecurityGroup"
          break
        }
        "NetworkSetting"
        {
          $Config_TextBox.Text = $Script:NetworkSetting
          $Config_TrackBar.Value = 8
          $Config_Simon_TextBox.Text = "Name"
          $Config_Garfunkel_TextBox.Text = "MACAddress"
          $Config_Parsley_TextBox.Text = "DriverVersion"
          $Config_Sage_TextBox.Text = "Speed"
          $Config_Rosemary_TextBox.Text = "SpeedDuplex"
          break
        }
      }
    }
    else
    {
      $Config_TextBox.Text = $Script:CodeBlock
      $Config_TrackBar.Value = $Config_Form.Tag
      $Config_Simon_TextBox.Text = $Config_Simon_TextBox.Tag
      $Config_Garfunkel_TextBox.Text = $Config_Garfunkel_TextBox.Tag
      $Config_Parsley_TextBox.Text = $Config_Parsley_TextBox.Tag
      $Config_Sage_TextBox.Text = $Config_Sage_TextBox.Tag
      $Config_Rosemary_TextBox.Text = $Config_Rosemary_TextBox.Tag
    }
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit SelectedIndexChanged Event for `$Config_ComboBox"
}
#endregion
$Config_ComboBox.add_SelectedIndexChanged({ SelectedIndexChanged-Config_ComboBox -Sender $Config_ComboBox -EventArg $_ })

#region $Config_Simon_Label = System.Windows.Forms.Label
Write-Verbose -Message "Creating Form Control `$Config_Simon_Label"
$Config_Simon_Label = New-Object -TypeName System.Windows.Forms.Label
$Config_Form.Controls.Add($Config_Simon_Label)
#$Config_Simon_Label.AutoSize = $False
$Config_Simon_Label.BackColor = [System.Drawing.Color]::Gray
$Config_Simon_Label.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Config_Simon_Label.Font = New-Object -TypeName System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$Config_Simon_Label.ForeColor = [System.Drawing.Color]::Black
$Config_Simon_Label.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($Config_ComboBox.Bottom + $FormSpacer))
$Config_Simon_Label.Name = "Config_Simon_Label"
#$Config_Simon_Label.Size = New-Object -TypeName System.Drawing.Size(100, 23)
$Config_Simon_Label.Text = "Simon"
$Config_Simon_Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#endregion
$TempHeight = $Config_Simon_Label.Height
$Config_Simon_Label.AutoSize = $False
$Config_Simon_Label.Size = New-Object -TypeName System.Drawing.Size((($Config_ComboBox.Width - ($FormSpacer * 4)) / 5), $TempHeight)

#region $Config_Simon_TextBox = System.Windows.Forms.TextBox
Write-Verbose -Message "Creating Form Control `$Config_Simon_TextBox"
$Config_Simon_TextBox = New-Object -TypeName System.Windows.Forms.TextBox
$Config_Form.Controls.Add($Config_Simon_TextBox)
#$Config_Simon_TextBox.AutoSize = $True
#$Config_Simon_TextBox.BackColor = [System.Drawing.SystemColors]::Window
$Config_Simon_TextBox.Font = New-Object -TypeName System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
#$Config_Simon_TextBox.ForeColor = [System.Drawing.SystemColors]::WindowText
$Config_Simon_TextBox.Location = New-Object -TypeName System.Drawing.Point($Config_Simon_Label.Left, ($Config_Simon_Label.Bottom + $FormSpacer))
$Config_Simon_TextBox.MaxLength = 20
$Config_Simon_TextBox.Name = "Config_Simon_TextBox"
$Config_Simon_TextBox.Tag = "Simon"
$Config_Simon_TextBox.Text = "Simon"
$Config_Simon_TextBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$Config_Simon_TextBox.Width = $Config_Simon_Label.Width
#endregion

#region $Config_Garfunkel_Label = System.Windows.Forms.Label
Write-Verbose -Message "Creating Form Control `$Config_Garfunkel_Label"
$Config_Garfunkel_Label = New-Object -TypeName System.Windows.Forms.Label
$Config_Form.Controls.Add($Config_Garfunkel_Label)
#$Config_Garfunkel_Label.AutoSize = $False
$Config_Garfunkel_Label.BackColor = [System.Drawing.Color]::Gray
$Config_Garfunkel_Label.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Config_Garfunkel_Label.Font = $Config_Simon_Label.Font
$Config_Garfunkel_Label.ForeColor = [System.Drawing.Color]::Black
$Config_Garfunkel_Label.Location = New-Object -TypeName System.Drawing.Point(($Config_Simon_Label.Right + $FormSpacer), $Config_Simon_Label.Top)
$Config_Garfunkel_Label.Name = "Config_Garfunkel_Label"
$Config_Garfunkel_Label.Size = $Config_Simon_Label.Size
$Config_Garfunkel_Label.Text = "Garfunkel"
$Config_Garfunkel_Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#$Config_Garfunkel_Label.Width = 100
#endregion

#region $Config_Garfunkel_TextBox = System.Windows.Forms.TextBox
Write-Verbose -Message "Creating Form Control `$Config_Garfunkel_TextBox"
$Config_Garfunkel_TextBox = New-Object -TypeName System.Windows.Forms.TextBox
$Config_Form.Controls.Add($Config_Garfunkel_TextBox)
#$Config_Garfunkel_TextBox.AutoSize = $True
#$Config_Garfunkel_TextBox.BackColor = [System.Drawing.SystemColors]::Window
$Config_Garfunkel_TextBox.Font = New-Object -TypeName System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
#$Config_Garfunkel_TextBox.ForeColor = [System.Drawing.SystemColors]::WindowText
$Config_Garfunkel_TextBox.Location = New-Object -TypeName System.Drawing.Point($Config_Garfunkel_Label.Left, ($Config_Garfunkel_Label.Bottom + $FormSpacer))
$Config_Garfunkel_TextBox.MaxLength = 20
$Config_Garfunkel_TextBox.Name = "Config_Garfunkel_TextBox"
$Config_Garfunkel_TextBox.Tag = "Garfunkel"
$Config_Garfunkel_TextBox.Text = "Garfunkel"
$Config_Garfunkel_TextBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$Config_Garfunkel_TextBox.Width = $Config_Garfunkel_Label.Width
#endregion

#region $Config_Parsley_Label = System.Windows.Forms.Label
Write-Verbose -Message "Creating Form Control `$Config_Parsley_Label"
$Config_Parsley_Label = New-Object -TypeName System.Windows.Forms.Label
$Config_Form.Controls.Add($Config_Parsley_Label)
#$Config_Parsley_Label.AutoSize = $False
$Config_Parsley_Label.BackColor = [System.Drawing.Color]::Gray
$Config_Parsley_Label.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Config_Parsley_Label.Font = $Config_Simon_Label.Font
$Config_Parsley_Label.ForeColor = [System.Drawing.Color]::Black
$Config_Parsley_Label.Location = New-Object -TypeName System.Drawing.Point(($Config_Garfunkel_Label.Right + $FormSpacer), $Config_Garfunkel_Label.Top)
$Config_Parsley_Label.Name = "Config_Parsley_Label"
$Config_Parsley_Label.Size = $Config_Simon_Label.Size
$Config_Parsley_Label.Text = "Parsley"
$Config_Parsley_Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#endregion

#region $Config_Parsley_TextBox = System.Windows.Forms.TextBox
Write-Verbose -Message "Creating Form Control `$Config_Parsley_TextBox"
$Config_Parsley_TextBox = New-Object -TypeName System.Windows.Forms.TextBox
$Config_Form.Controls.Add($Config_Parsley_TextBox)
#$Config_Parsley_TextBox.AutoSize = $True
#$Config_Parsley_TextBox.BackColor = [System.Drawing.SystemColors]::Window
$Config_Parsley_TextBox.Font = New-Object -TypeName System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
#$Config_Parsley_TextBox.ForeColor = [System.Drawing.SystemColors]::WindowText
$Config_Parsley_TextBox.Location = New-Object -TypeName System.Drawing.Point($Config_Parsley_Label.Left, ($Config_Parsley_Label.Bottom + $FormSpacer))
$Config_Parsley_TextBox.MaxLength = 20
$Config_Parsley_TextBox.Name = "Config_Parsley_TextBox"
$Config_Parsley_TextBox.Tag = "Parsley"
$Config_Parsley_TextBox.Text = "Parsley"
$Config_Parsley_TextBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$Config_Parsley_TextBox.Width = $Config_Parsley_Label.Width
#endregion

#region $Config_Sage_Label = System.Windows.Forms.Label
Write-Verbose -Message "Creating Form Control `$Config_Sage_Label"
$Config_Sage_Label = New-Object -TypeName System.Windows.Forms.Label
$Config_Form.Controls.Add($Config_Sage_Label)
#$Config_Sage_Label.AutoSize = $False
$Config_Sage_Label.BackColor = [System.Drawing.Color]::Gray
$Config_Sage_Label.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Config_Sage_Label.Font = $Config_Simon_Label.Font
$Config_Sage_Label.ForeColor = [System.Drawing.Color]::Black
$Config_Sage_Label.Location = New-Object -TypeName System.Drawing.Point(($Config_Parsley_Label.Right + $FormSpacer), $Config_Parsley_Label.Top)
$Config_Sage_Label.Name = "Config_Sage_Label"
$Config_Sage_Label.Size = $Config_Simon_Label.Size
$Config_Sage_Label.Text = "Sage"
$Config_Sage_Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter#endregion
#endregion

#region $Config_Sage_TextBox = System.Windows.Forms.TextBox
Write-Verbose -Message "Creating Form Control `$Config_Sage_TextBox"
$Config_Sage_TextBox = New-Object -TypeName System.Windows.Forms.TextBox
$Config_Form.Controls.Add($Config_Sage_TextBox)
#$Config_Sage_TextBox.AutoSize = $True
#$Config_Sage_TextBox.BackColor = [System.Drawing.SystemColors]::Window
$Config_Sage_TextBox.Font = New-Object -TypeName System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
#$Config_Sage_TextBox.ForeColor = [System.Drawing.SystemColors]::WindowText
$Config_Sage_TextBox.Location = New-Object -TypeName System.Drawing.Point($Config_Sage_Label.Left, ($Config_Sage_Label.Bottom + $FormSpacer))
$Config_Sage_TextBox.MaxLength = 20
$Config_Sage_TextBox.Name = "Config_Sage_TextBox"
$Config_Sage_TextBox.Tag = "Sage"
$Config_Sage_TextBox.Text = "Sage"
$Config_Sage_TextBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$Config_Sage_TextBox.Width = $Config_Sage_Label.Width
#endregion

#region $Config_Rosemary_Label = System.Windows.Forms.Label
Write-Verbose -Message "Creating Form Control `$Config_Rosemary_Label"
$Config_Rosemary_Label = New-Object -TypeName System.Windows.Forms.Label
$Config_Form.Controls.Add($Config_Rosemary_Label)
#$Config_Rosemary_Label.AutoSize = $False
$Config_Rosemary_Label.BackColor = [System.Drawing.Color]::Gray
$Config_Rosemary_Label.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Config_Rosemary_Label.Font = $Config_Simon_Label.Font
$Config_Rosemary_Label.ForeColor = [System.Drawing.Color]::Black
$Config_Rosemary_Label.Location = New-Object -TypeName System.Drawing.Point(($Config_Sage_Label.Right + $FormSpacer), $Config_Sage_Label.Top)
$Config_Rosemary_Label.Name = "Config_Rosemary_Label"
$Config_Rosemary_Label.Size = $Config_Simon_Label.Size
$Config_Rosemary_Label.Text = "Rosemary"
$Config_Rosemary_Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#endregion

#region $Config_Rosemary_TextBox = System.Windows.Forms.TextBox
Write-Verbose -Message "Creating Form Control `$Config_Rosemary_TextBox"
$Config_Rosemary_TextBox = New-Object -TypeName System.Windows.Forms.TextBox
$Config_Form.Controls.Add($Config_Rosemary_TextBox)
#$Config_Rosemary_TextBox.AutoSize = $True
#$Config_Rosemary_TextBox.BackColor = [System.Drawing.SystemColors]::Window
$Config_Rosemary_TextBox.Font = New-Object -TypeName System.Drawing.Font("Tahoma", 10, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
#$Config_Rosemary_TextBox.ForeColor = [System.Drawing.SystemColors]::WindowText
$Config_Rosemary_TextBox.Location = New-Object -TypeName System.Drawing.Point($Config_Rosemary_Label.Left, ($Config_Rosemary_Label.Bottom + $FormSpacer))
$Config_Rosemary_TextBox.MaxLength = 20
$Config_Rosemary_TextBox.Name = "Config_Rosemary_TextBox"
$Config_Rosemary_TextBox.Tag = "Rosemary"
$Config_Rosemary_TextBox.Text = "Rosemary"
$Config_Rosemary_TextBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$Config_Rosemary_TextBox.Width = $Config_Rosemary_Label.Width
#endregion

#region function KeyDown-Config_XXXX_TextBox
function KeyDown-Config_XXXX_TextBox()
{
  <#
    .SYNOPSIS
      KeyDown event for the Config_TextBox Control
    .DESCRIPTION
      KeyDown event for the Config_TextBox Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       KeyDown-Config_XXXX_TextBox -Sender $Config_TextBox -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object]$Sender,
    [parameter(Mandatory=$True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter KeyDown Event for `$Config_XXXX_TextBox"
  Try
  {
    if (-not ([Char]::IsLetterOrDigit(([Char]($EventArg.KeyValue))) -or [Char]::IsWhiteSpace(([Char]($EventArg.KeyValue)))))
    {
      $EventArg.Handled = $True
    }
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit KeyDown Event for `$Config_XXXX_TextBox"
}
#endregion
$Config_Simon_TextBox.add_KeyDown({KeyDown-Config_XXXX_TextBox -Sender $Config_Simon_TextBox -EventArg $_})
$Config_Garfunkel_TextBox.add_KeyDown({KeyDown-Config_XXXX_TextBox -Sender $Config_Garfunkel_TextBox -EventArg $_})
$Config_Parsley_TextBox.add_KeyDown({KeyDown-Config_XXXX_TextBox -Sender $Config_Parsley_TextBox -EventArg $_})
$Config_Sage_TextBox.add_KeyDown({KeyDown-Config_XXXX_TextBox -Sender $Config_Sage_TextBox -EventArg $_})
$Config_Rosemary_TextBox.add_KeyDown({KeyDown-Config_XXXX_TextBox -Sender $Config_Rosemary_TextBox -EventArg $_})



#region $Config_GroupBox = System.Windows.Forms.GroupBox
Write-Verbose -Message "Creating Form Control `$Config_GroupBox"
$Config_GroupBox = New-Object -TypeName System.Windows.Forms.GroupBox
# Location of First Control New-Object -TypeName System.Drawing.Point($FormSpacer, ([System.Math]::Floor($Config_GroupBox.CreateGraphics().MeasureString($Config_GroupBox.Text, $Config_GroupBox.Font).Height + $FormSpacer)))
$Config_Form.Controls.Add($Config_GroupBox)
$Config_GroupBox.BackColor = [System.Drawing.Color]::Black
$Config_GroupBox.ForeColor = [System.Drawing.Color]::White
$Config_GroupBox.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($Config_Simon_TextBox.Bottom + $FormSpacer))
$Config_GroupBox.Name = "Config_GroupBox"
$Config_GroupBox.ClientSize = New-Object -TypeName System.Drawing.Size($Config_TextBox.Width, $FormSpacer)
$Config_GroupBox.Tag = 8
$Config_GroupBox.Text = "Total Processing Threads"
$Config_GroupBox.Width = $Config_TextBox.Width

#endregion

#region ******** $Config_GroupBox Controls ********

#region $Config_TrackBar = System.Windows.Forms.TrackBar
Write-Verbose -Message "Creating Form Control `$Config_TrackBar"
$Config_TrackBar = New-Object -TypeName System.Windows.Forms.TrackBar
$Config_TrackBar.AutoSize = $False
$Config_GroupBox.Controls.Add($Config_TrackBar)
$Config_TrackBar.BackColor = [System.Drawing.Color]::Black
#$Config_TrackBar.Font = New-Object -TypeName System.Drawing.Font("Microsoft Sans Serif", 8.25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
$Config_TrackBar.ForeColor = [System.Drawing.Color]::White
#$Config_TrackBar.Height = 30
$Config_TrackBar.LargeChange = 1
$Config_TrackBar.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ([System.Math]::Floor($Config_GroupBox.CreateGraphics().MeasureString($Config_GroupBox.Text, $Config_GroupBox.Font).Height + $FormSpacer)))
$Config_TrackBar.Maximum = 11
$Config_TrackBar.Minimum = 1
$Config_TrackBar.Name = "Config_TrackBar"
$Config_TrackBar.SmallChange = 1
$Config_TrackBar.Text = "Config_TrackBar"
#$Config_TrackBar.TickFrequency = 1
$Config_TrackBar.TickStyle = [System.Windows.Forms.TickStyle]::Both
$Config_TrackBar.Value = 8
$Config_TrackBar.Width = $Config_GroupBox.ClientSize.Width - ($FormSpacer * 2)
#endregion
$Config_ToolTip.SetToolTip($Config_TrackBar, "8")

#region function ValueChanged-Config_TrackBar
function ValueChanged-Config_TrackBar()
{
  <#
    .SYNOPSIS
      ValueChanged event for the Config_TrackBar Control
    .DESCRIPTION
      ValueChanged event for the Config_TrackBar Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       ValueChanged-Config_TrackBar -Sender $Config_TrackBar -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter ValueChanged Event for `$Config_TrackBar"
  Try
  {
    $Config_GroupBox.Tag = $Config_TrackBar.Value
    $Config_ToolTip.SetToolTip($Config_TrackBar, $Config_TrackBar.Value)
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit ValueChanged Event for `$Config_TrackBar"
}
#endregion
$Config_TrackBar.add_ValueChanged({ ValueChanged-Config_TrackBar -Sender $Config_TrackBar -EventArg $_ })

$Config_GroupBox.ClientSize = New-Object -TypeName System.Drawing.Size($Config_TextBox.Width, ($Config_TrackBar.Bottom + $FormSpacer))

#endregion

#region $Config_Update_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$Config_Update_Button"
$Config_Update_Button = New-Object -TypeName System.Windows.Forms.Button
$Config_Form.Controls.Add($Config_Update_Button)
$Config_Update_Button.BackColor = [System.Drawing.Color]::LightGray
$Config_Update_Button.DialogResult = [System.Windows.Forms.DialogResult]::OK
$Config_Update_Button.Font = New-Object -TypeName System.Drawing.Font($Config_Form.Font.FontFamily, $Config_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$Config_Update_Button.ForeColor = [System.Drawing.Color]::Black
$Config_Update_Button.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($Config_GroupBox.Bottom + $FormSpacer))
$Config_Update_Button.Name = "Config_Update_Button"
$Config_Update_Button.Text = "Update Script"
$Config_Update_Button.Width = ($Config_Label.Width - $FormSpacer) / 2
#endregion
$Config_ToolTip.SetToolTip($Config_Update_Button, "Help for Control $($Config_Update_Button.Name)")

#region $Config_Cancel_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$Config_Cancel_Button"
$Config_Cancel_Button = New-Object -TypeName System.Windows.Forms.Button
$Config_Form.Controls.Add($Config_Cancel_Button)
$Config_Cancel_Button.BackColor = [System.Drawing.Color]::LightGray
$Config_Cancel_Button.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$Config_Cancel_Button.Font = New-Object -TypeName System.Drawing.Font($Config_Form.Font.FontFamily, $Config_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$Config_Cancel_Button.ForeColor = [System.Drawing.Color]::Black
$Config_Cancel_Button.Location = New-Object -TypeName System.Drawing.Point(($Config_Update_Button.Right + $FormSpacer), ($Config_GroupBox.Bottom + $FormSpacer))
$Config_Cancel_Button.Name = "Config_Cancel_Button"
$Config_Cancel_Button.Text = "Cancel"
$Config_Cancel_Button.Width = ($Config_Label.Width - $FormSpacer) / 2
#endregion
$Config_ToolTip.SetToolTip($Config_Cancel_Button, "Help for Control $($Config_Cancel_Button.Name)")

$Config_Form.ClientSize = New-Object -TypeName System.Drawing.Size(($($Config_Form.Controls[$Config_Form.Controls.Count - 1]).Right + $FormSpacer), ($($Config_Form.Controls[$Config_Form.Controls.Count - 1]).Bottom + $FormSpacer))

#endregion

#endregion

#region ******** Add Workstations Dialog ********

#region $AddList_ToolTip = System.Windows.Forms.ToolTip
Write-Verbose -Message "Creating Form Control `$AddList_ToolTip"
$AddList_ToolTip = New-Object -TypeName System.Windows.Forms.ToolTip($FormComponents)
$AddList_ToolTip.ToolTipTitle = "$ScriptName - $ScriptVersion"
#endregion

#region $AddList_Form = System.Windows.Forms.Form
Write-Verbose -Message "Creating Form Control `$AddList_Form"
$AddList_Form = New-Object -TypeName System.Windows.Forms.Form
$AddList_Form.BackColor = [System.Drawing.Color]::Black
$AddList_Form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$AddList_Form.Font = New-Object -TypeName System.Drawing.Font("Verdana", (8 * (96 / ($AddList_Form.CreateGraphics()).DpiX)), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
$AddList_Form.ForeColor = [System.Drawing.Color]::White
$AddList_Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
$AddList_Form.Name = "AddList_Form"
$AddList_Form.ShowInTaskbar = $False
$AddList_Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
$AddList_Form.Text = "$ScriptName - $ScriptVersion"
#endregion
$AddList_ToolTip.SetToolTip($AddList_Form, "Help for Control $($AddList_Form.Name)")

#region function Shown-AddList_Form
function Shown-AddList_Form()
{
  <#
    .SYNOPSIS
      Shown event for the AddList_Form Control
    .DESCRIPTION
      Shown event for the AddList_Form Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Shown-AddList_Form -Sender $AddList_Form -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Shown Event for `$AddList_Form"
  Try
  {
    $AddList_TextBox.Text = ""
    $AddList_TextBox.Select()
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit Shown Event for `$AddList_Form"
}
#endregion
$AddList_Form.add_Shown({ Shown-AddList_Form -Sender $AddList_Form -EventArg $_ })

#region ******** $AddList_Form Controls ********

#region $AddList_Label = System.Windows.Forms.Label
Write-Verbose -Message "Creating Form Control `$AddList_Label"
$AddList_Label = New-Object -TypeName System.Windows.Forms.Label
$AddList_Form.Controls.Add($AddList_Label)
$AddList_Label.BackColor = [System.Drawing.Color]::Gray
$AddList_Label.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$AddList_Label.Font = New-Object -TypeName System.Drawing.Font($AddList_Form.Font.FontFamily, ($AddList_Form.Font.Size + 3), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$AddList_Label.ForeColor = [System.Drawing.Color]::Black
$AddList_Label.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, $FormSpacer)
$AddList_Label.Name = "AddList_Label"
$AddList_Label.Text = "Add Workstations"
$AddList_Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#endregion
$TempHeight = $AddList_Label.Height
$AddList_Label.AutoSize = $False
$AddList_Label.Size = New-Object -TypeName System.Drawing.Size(200, $TempHeight)

#region function DoubleClick-AddList_Label
function DoubleClick-AddList_Label()
{
  <#
    .SYNOPSIS
      DoubleClick event for the AddList_Label Control
    .DESCRIPTION
      DoubleClick event for the AddList_Label Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       DoubleClick-AddList_Label -Sender $AddList_Label -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True)]
    [Object]$Sender,
    [parameter(Mandatory=$True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter DoubleClick Event for `$AddList_Label"
  Try
  {
    $AddList_TextBox.Text += "`r`n$([System.Environment]::MachineName )`r`n"
    $AddList_Form.DialogResult = [System.Windows.Forms.DialogResult]::OK
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit DoubleClick Event for `$AddList_Label"
}
#endregion
$AddList_Label.add_DoubleClick({DoubleClick-AddList_Label -Sender $AddList_Label -EventArg $_})

#region $AddList_TextBox = System.Windows.Forms.TextBox
Write-Verbose -Message "Creating Form Control `$AddList_TextBox"
$AddList_TextBox = New-Object -TypeName System.Windows.Forms.TextBox
$AddList_Form.Controls.Add($AddList_TextBox)
$AddList_TextBox.BackColor = [System.Drawing.Color]::White
$AddList_TextBox.ForeColor = [System.Drawing.Color]::Black
$AddList_TextBox.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($AddList_Label.Bottom + $FormSpacer))
$AddList_TextBox.Multiline = $True
$AddList_TextBox.Name = "AddList_TextBox"
$AddList_TextBox.Size = New-Object -TypeName System.Drawing.Size($AddList_Label.Width, 200)
$AddList_TextBox.Text = ""
#endregion
$AddList_ToolTip.SetToolTip($AddList_TextBox, "Help for Control $($AddList_TextBox.Name)")

#region $AddList_Add_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$AddList_Add_Button"
$AddList_Add_Button = New-Object -TypeName System.Windows.Forms.Button
$AddList_Form.Controls.Add($AddList_Add_Button)
$AddList_Add_Button.BackColor = [System.Drawing.Color]::LightGray
$AddList_Add_Button.DialogResult = [System.Windows.Forms.DialogResult]::OK
$AddList_Add_Button.Font = New-Object -TypeName System.Drawing.Font($AddList_Form.Font.FontFamily, $AddList_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$AddList_Add_Button.ForeColor = [System.Drawing.Color]::Black
$AddList_Add_Button.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($AddList_TextBox.Bottom + $FormSpacer))
$AddList_Add_Button.Name = "AddList_Add_Button"
$AddList_Add_Button.Text = "Add"
$AddList_Add_Button.Width = ($AddList_Label.Width - $FormSpacer) / 2
#endregion
$AddList_ToolTip.SetToolTip($AddList_Add_Button, "Help for Control $($AddList_Add_Button.Name)")

#region $AddList_Cancel_Button = System.Windows.Forms.Button
Write-Verbose -Message "Creating Form Control `$AddList_Cancel_Button"
$AddList_Cancel_Button = New-Object -TypeName System.Windows.Forms.Button
$AddList_Form.Controls.Add($AddList_Cancel_Button)
$AddList_Cancel_Button.BackColor = [System.Drawing.Color]::LightGray
$AddList_Cancel_Button.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$AddList_Cancel_Button.Font = New-Object -TypeName System.Drawing.Font($AddList_Form.Font.FontFamily, $AddList_Form.Font.Size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
$AddList_Cancel_Button.ForeColor = [System.Drawing.Color]::Black
$AddList_Cancel_Button.Location = New-Object -TypeName System.Drawing.Point(($AddList_Add_Button.Right + $FormSpacer), ($AddList_TextBox.Bottom + $FormSpacer))
$AddList_Cancel_Button.Name = "AddList_Cancel_Button"
$AddList_Cancel_Button.Text = "Cancel"
$AddList_Cancel_Button.Width = ($AddList_Label.Width - $FormSpacer) / 2
#endregion
$AddList_ToolTip.SetToolTip($AddList_Cancel_Button, "Help for Control $($AddList_Cancel_Button.Name)")

$AddList_Form.ClientSize = New-Object -TypeName System.Drawing.Size(($($AddList_Form.Controls[$AddList_Form.Controls.Count - 1]).Right + $FormSpacer), ($($AddList_Form.Controls[$AddList_Form.Controls.Count - 1]).Bottom + $FormSpacer))

#endregion

#endregion

#region ******** Loading Workstations Dialog ********

#region $Loading_Form = System.Windows.Forms.Form
Write-Verbose -Message "Creating Form Control `$Loading_Form"
$Loading_Form = New-Object -TypeName System.Windows.Forms.Form
$Loading_Form.BackColor = [System.Drawing.Color]::Gray
$Loading_Form.Font = New-Object -TypeName System.Drawing.Font("Verdana", (8 * (96 / ($Loading_Form.CreateGraphics()).DpiX)), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
$Loading_Form.ForeColor = [System.Drawing.Color]::White
$Loading_Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$Loading_Form.Name = "Loading_Form"
$Loading_Form.ShowInTaskbar = $False
$Loading_Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
$Loading_Form.Tag = 0
$Loading_Form.UseWaitCursor = $True
#endregion

#region function Shown-Loading_Form
function Shown-Loading_Form()
{
  <#
    .SYNOPSIS
      Shown event for the Loading_Form Control
    .DESCRIPTION
      Shown event for the Loading_Form Control
    .PARAMETER Sender
       The Form Control that fired the Event
    .PARAMETER EventArg
       The Event Arguments for the Event
    .EXAMPLE
       Shown-Loading_Form -Sender $Loading_Form -EventArg $_
    .INPUTS
    .OUTPUTS
    .NOTES
    .LINK
  #>
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $True)]
    [Object]$Sender,
    [parameter(Mandatory = $True)]
    [Object]$EventArg
  )
  Write-Verbose -Message "Enter Shown Event for `$Loading_Form"
  Try
  {
    $Loading_Form.Refresh()
    $Loading_ProgressBar.Value = 0
    $Loading_ProgressBar.Maximum = @($Script:TempLoad).Count
    $ProcList_ListView.BeginUpdate()
    ForEach ($Item in $Script:TempLoad)
    {
      $Loading_ProgressBar.Value += 1
      if ($Loading_Form.Tag -eq 0)
      {
        $Loading_Label.Text = $Item
        New-ListViewItem -ListView $ProcList_ListView -ComputerName $Item
      }
      else
      {
        $Loading_Label.Text = $Item.Workstation
        New-ListViewItem -ListView $ProcList_ListView -ComputerName $Item.Workstation -OnLine $Item.OnLine -IPAddress $Item.IPAddress -WMIStatus $Item.WMIStatus -WMIProtocol $Item.WMIProtocol -WMIName $Item.WMIName -UserName $Item.UserName -OperatingSystem $Item.OperatingSystem -ServicePack $Item.ServicePack -Architecture $Item.Architecture -JobStatus $Item.JobStatus -Simon $Item."$($Config_Simon_TextBox.Tag)" -Garfunkel $Item."$($Config_Garfunkel_TextBox.Tag)" -Parsley $Item."$($Config_Parsley_TextBox.Tag)" -Sage $Item."$($Config_Sage_TextBox.Tag)" -Rosemary $Item."$($Config_Rosemary_TextBox.Tag)" -Time $Item.Time -Date $Item.Date -ErrorMessage $Item.ErrorMessage
      }
      [System.Windows.Forms.Application]::DoEvents()
    }
    $ProcList_ListView.EndUpdate()
    $Loading_Form.Close()
  }
  Catch
  {
    # Debugging Code, Comment Lines for Production Deployment
    Write-Debug -Message ($Error[0].Exception | Out-String)
    Write-Debug -Message "Line: $($Error[0].InvocationInfo.ScriptLineNumber)"
    Write-Debug -Message "Code:$($Error[0].InvocationInfo.Line)"
  }
  Write-Verbose -Message "Exit Shown Event for `$Loading_Form"
}
#endregion
$Loading_Form.add_Shown({ Shown-Loading_Form -Sender $Loading_Form -EventArg $_ })

#region ******** $Loading_Form Controls ********

#region $Loading_Label = System.Windows.Forms.Label
Write-Verbose -Message "Creating Form Control `$Loading_Label"
$Loading_Label = New-Object -TypeName System.Windows.Forms.Label
$Loading_Form.Controls.Add($Loading_Label)
$Loading_Label.AutoSize = $True
$Loading_Label.BackColor = [System.Drawing.Color]::Black
$Loading_Label.ForeColor = [System.Drawing.Color]::White
$Loading_Label.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, $FormSpacer)
$Loading_Label.Name = "Loading_Label"
$Loading_Label.Text = "Loading_Label"
$Loading_Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
#endregion
$TempHeight = $Loading_Label.Height
$Loading_Label.AutoSize = $False
$Loading_Label.Size = New-Object -TypeName System.Drawing.Size(400, $TempHeight)

#region $Loading_ProgressBar = System.Windows.Forms.ProgressBar
Write-Verbose -Message "Creating Form Control `$Loading_ProgressBar"
$Loading_ProgressBar = New-Object -TypeName System.Windows.Forms.ProgressBar
$Loading_Form.Controls.Add($Loading_ProgressBar)
$Loading_ProgressBar.BackColor = [System.Drawing.Color]::Black
$Loading_ProgressBar.ForeColor = [System.Drawing.Color]::Red
$Loading_ProgressBar.Location = New-Object -TypeName System.Drawing.Point($FormSpacer, ($Loading_Label.Bottom + $FormSpacer))
$Loading_ProgressBar.Name = "Loading_ProgressBar"
$Loading_ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$Loading_ProgressBar.Text = "Loading_ProgressBar"
$Loading_ProgressBar.Value = 0
$Loading_ProgressBar.Width = $Loading_Label.Width
#endregion

$Loading_Form.ClientSize = New-Object -TypeName System.Drawing.Size(($($Loading_Form.Controls[$Loading_Form.Controls.Count - 1]).Right + $FormSpacer), ($($Loading_Form.Controls[$Loading_Form.Controls.Count - 1]).Bottom + $FormSpacer))

#endregion

#endregion

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($ProcList_Form)

#[Void][Window.Display]::Show()

[Environment]::Exit(0)
