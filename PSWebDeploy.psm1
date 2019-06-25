Set-StrictMode -Version Latest;

$Defaults = @{
	MSDeployExePath = 'C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe' 
}

if (-not (Test-Path -Path $Defaults.MSDeployExePath -PathType Leaf)) {
	throw 'MSDeploy was not found. In order to use the MSDeploy module, you must have Web Deploy installed. It can be found at https://www.microsoft.com/en-us/download/details.aspx?id=43717'
}

function NewMsDeployCliArgumentString
{
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Sync')]
		[string]$Verb,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[Alias('SourcePath')]
		[Alias('SourcePackage')]
		[string]$SourceContent,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[Alias('TargetPath')]
		[string]$TargetContent,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		$Credential,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('DoNotDelete')]
		[string[]]$EnableRule,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$RetryAttempts,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$RetryInterval,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$AuthType = 'Basic'
	)

	$connHt = @{
		ComputerName = $Computername
		UserName = $Credential.UserName
		Password = $Credential.GetNetworkCredential().Password
		AuthType = $AuthType
	}

	$deployArgs = @{
		verb = $Verb
	}

	if ($PSBoundParameters.ContainsKey('RetryInterval'))
	{
		$deployArgs.retryInterval = $RetryInterval
	}

	if ($PSBoundParameters.ContainsKey('RetryAttempts'))
	{
		$deployArgs.RetryAttempts = $RetryAttempts	
	}

	if ($PSBoundParameters.ContainsKey('EnableRule'))
	{
		$deployArgs.EnableRule = $EnableRule -join ','
	}

	## If this is a ZIP file, it needs to be Package otherwise assuming it's a file path or a web service path
	if (Test-Path -Path $SourceContent -PathType Leaf) {
		$sourceProvider = 'Package'
	} else {
		$sourceProvider = 'ContentPath'
	}
	$targetProvider = 'ContentPath'

	if (Test-Path -Path $SourceContent) {

		## No authentication needed if source is a folder/file path
		$deployArgs.source = @{
			$sourceProvider = '"{0}"' -f $SourceContent
		}

		## Assuming that destination is a web service if source is not. Authentication needed.
		$deployArgs.dest = ($connHt + @{
			$targetProvider = '"{0}"' -f $TargetContent
		})

	} else {
		## Assuming this is a web service. Authenticate here
		$deployArgs.source = $connHt + @{
			$sourceProvider = '"{0}"' -f $SourceContent
		}
		## Assuming that destination is a file/folder path. No authentication needed.
		$deployArgs.dest = @{
			$targetProvider = '"{0}"' -f $TargetContent
		}
	}

	$argString = '' 
	$deployArgs.GetEnumerator().foreach({ 
		if ($_.Value -is 'hashtable') { 
			$val = '' 
			$_.Value.GetEnumerator().foreach({ 
				$val += "$($_.Key)=$($_.Value),"  
			})
			$val = $val.TrimEnd(',')
		} else { 
			$val = $_.Value
		}
		$argString += " -$($_.Key):$val" 
	})
	$argString
}

function Invoke-MSDeploy
{
	[OutputType([string])]
	[CmdletBinding()]
	param
	(
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$Arguments
	)

	$stdOutTempFile = New-TemporaryFile
	$stdErrTempFile = New-TemporaryFile

	$startProcessParams = @{
    	FilePath                = $Defaults.MSDeployExePath
		ArgumentList            = $Arguments
		RedirectStandardError    = $stdErrTempFile.FullName
		RedirectStandardOutput    = $stdOutTempFile.FullName
		Wait                    = $true;
		PassThru                = $true;
		NoNewWindow                = $true;
	}

	$cmd = Start-Process @startProcessParams
	$cmdOutput = Get-Content -Path $stdOutTempFile.FullName -Raw
	$cmdError = Get-Content -Path $stdErrTempFile.FullName -Raw
	if ([string]::IsNullOrEmpty($cmdOutput) -eq $false)
	{
		Write-Verbose -Message $cmdOutput
	}
	if ($cmd.ExitCode -ne 0)
	{
		throw $cmdError
	}
	Remove-Item -Path $stdOutTempFile.FullName,$stdErrTempFile.FullName -Force

}

#region function Sync-Website
function Sync-Website {
	<#
		.SYNOPSIS
			This function uses msdeploy to copy files from a source location to a destination folder path or URL.
	
		.EXAMPLE
			PS> Sync-Website -SourcePath C:\TestSite -TargetPath wwwroot -ComputerName https://azureurl.com
		
		.PARAMETER SourcePath
			 A mandatory string parameter (if not using SourcePackage) representing the location where the files are located.

		.PARAMETER SourcePackage
			 A mandatory string parameter (if not using SourcePath) representing the location of a zip file that contains the
			 website files/folders.

		.PARAMETER TargetPath
			 A mandatory string parameter representing the folder location to copy the files.

		.PARAMETER ComputerName
			 A mandatory string parameter representing a computer name or a deployment URL.

		.PARAMETER DoNotDelete
			 By default, any files/folders in the destination path will be removed if not in the SourcePath. Use this
			 parameter if you'd simply like to copy the contents from SourcePath to TargetPath without removing TargetPath
			 files/folders.

		.PARAMETER RetryInterval
			 A optional int parameter representing the interval (in seconds) in which MSDeploy will attempt to retry the action. By default,
			 this is 10 seconds. This parameter is expressed in milliseconds.

		.PARAMETER Credential
			Specifies a user account that has permission to perform this action. The default is the current user.
			
			Type a user name, such as 'User01' or 'Domain01\User01', or enter a variable that contains a PSCredential
			object, such as one generated by the Get-Credential cmdlet. When you type a user name, you will be prompted for a password.
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory,ParameterSetName = 'BySourcePath')]
		[ValidateNotNullOrEmpty()]
		[string]$SourcePath,

		[Parameter(Mandatory,ParameterSetName = 'BySourcePackage')]
		[ValidateNotNullOrEmpty()]
		[string]$SourcePackage,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$TargetPath,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[switch]$DoNotDelete,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$RetryInterval = 10,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$Timeout = 60,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		$Credential
	)
	begin {
		$ErrorActionPreference = 'Stop'
	}
	process {
		try
		{
			$cliArgStringParams = @{
				Verb = 'sync'
				TargetPath = ($TargetPath -replace '/','\')
				ComputerName = $ComputerName
				Credential = $Credential
				RetryInterval = ($RetryInterval * 10)
			}

			if ($PSCmdlet.ParameterSetName -eq 'BySourcePath') {
				$cliArgStringParams.SourcePath = $SourcePath
			} else {
				$cliArgStringParams.SourcePackage = $SourcePackage
			}
			if ($DoNotDelete.IsPresent) {
				$cliArgStringParams.EnableRule = 'DoNotDelete'
			}

			$argString = NewMsDeployCliArgumentString @cliArgStringParams
			Write-Verbose -Message "Using the MSDeploy CLI string: [$($argString)]"
			try {
				Invoke-MSDeploy -Arguments $argString
			} catch {
				$timer = [Diagnostics.Stopwatch]::StartNew()
				while ($timer.Elapsed.TotalSeconds -lt $Timeout) {
					try {
						Invoke-MSDeploy -Arguments $argString
					} catch {
						Write-Verbose -Message "MSdeploy failed. Retrying after [$($RetryInterval)] seconds..."
						Start-Sleep -Seconds $RetryInterval
					}
				}
				$timer.Stop()
				if ($timer.Elapsed.TotalSeconds -gt $Timeout) {
					throw 'Msdeploy timed out attempting to sync website.'
				}
			}
		}
		catch
		{
			$PSCmdlet.ThrowTerminatingError($_)
		}
	}
}
#endregion function Sync-Website
