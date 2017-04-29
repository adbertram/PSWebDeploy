@{
	RootModule = 'PSWebDeploy.psm1'
	ModuleVersion = '1.0'
	GUID = '261952d9-cd6f-424f-b0b4-4c409675b365'
	Description = 'A PowerShell module to provide an easier interface to msdeploy'
	Author = 'Adam Bertram'
	PowerShellVersion = '4.0'
	CLRVersion = '4.0'
	PrivateData = @{
		PSData = @{
			ProjectUri = 'https://github.com/adbertram/PSWebDeploy'
		}
	}
	FunctionsToExport = 'Sync-Website','Get-WebsiteFile'
}
