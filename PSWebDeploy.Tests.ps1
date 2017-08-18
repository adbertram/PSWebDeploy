,#region import modules
$ThisModule = "$($MyInvocation.MyCommand.Path -replace '\.Tests\.ps1$', '').psd1"
$ThisModuleName = (($ThisModule | Split-Path -Leaf) -replace '\.psd1')
Get-Module -Name $ThisModuleName -All | Remove-Module -Force

Import-Module -Name $ThisModule -Force -ErrorAction Stop
#endregion

describe 'Module-level tests' {
	
	it 'should validate the module manifest' {
	
		{ Test-ModuleManifest -Path $ThisModule -ErrorAction Stop } | should not throw
	}

	it 'should pass all error-level script analyzer rules' {

		$excludedRules = @(
			'PSUseShouldProcessForStateChangingFunctions',
			'PSUseToExportFieldsInManifest',
			'PSAvoidInvokingEmptyMembers',
			'PSUsePSCredentialType',
			'PSAvoidUsingPlainTextForPassword'
		)

		Invoke-ScriptAnalyzer -Path $PSScriptRoot -ExcludeRule $excludedRules -Severity Error | Select-Object -ExpandProperty RuleName | should benullorempty
	}
}

InModuleScope $ThisModuleName {

    describe 'NewMsDeployCliArgumentString - Sync' {

        $commandName = 'NewMsDeployCliArgumentString'
        $command = Get-Command -Name $commandName

        $mockCred = New-MockObject -Type 'System.Management.Automation.PSCredential'
        $mockCred = $mockCred | Add-Member -MemberType NoteProperty -Name UserName -Value 'username' -PassThru -Force
        $mockCred = $mockCred | Add-Member -MemberType ScriptMethod -Name GetNetworkCredential -Value {[pscustomobject]@{Password = 'passwordname'}} -PassThru -Force

        $parameterSets = @(
            @{
                Verb = 'Sync'
                SourcePath = 'C:\Source'
                TargetPath = 'TargetHere'
                ComputerName = 'https://webapphere.scm.azurewebsites.net:443/msdeploy.axd?site=webapphere'
                Credential = $mockCred
                TestName = 'Azure web app / Sync / FolderPath'
            }
            @{
                Verb = 'Sync'
                SourceContent = 'C:\Source'
                TargetPath = 'TargetHere'
                ComputerName = 'https://webapphere.scm.azurewebsites.net:443/msdeploy.axd?site=webapphere'
                Credential = $mockCred
                TestName = 'Azure web app / Sync / SourceContent / FolderPath'
            }
            @{
                Verb = 'Sync'
                SourceContent = 'C:\Source.zip'
                TargetPath = 'TargetHere'
                ComputerName = 'https://webapphere.scm.azurewebsites.net:443/msdeploy.axd?site=webapphere'
                Credential = $mockCred
                TestName = 'Azure web app / Sync / SourceContent / Package'
            }
            @{
                Verb = 'Sync'
                SourcePackage = 'C:\Source.zip'
                TargetPath = 'TargetHere'
                ComputerName = 'https://webapphere.scm.azurewebsites.net:443/msdeploy.axd?site=webapphere'
                Credential = $mockCred
                TestName = 'Azure web app / Sync / Package'
            }
            @{
                Verb = 'Sync'
                SourcePath = 'C:\Source'
                TargetPath = 'TargetHere'
                ComputerName = 'https://webapphere.scm.azurewebsites.net:443/msdeploy.axd?site=webapphere'
                Credential = $mockCred
                EnableRule = 'DoNotDelete'
                TestName = 'adds the required rule'
            }
            @{
                Verb = 'Sync'
                SourcePackage = 'C:\Source.zip'
                TargetPath = 'TargetHere'
                ComputerName = 'https://webapphere.scm.azurewebsites.net:443/msdeploy.axd?site=webapphere'
                Credential = $mockCred
                EnableRule = 'DoNotDelete'
                TestName = 'adds the required rule'
            }
        )

        $testCases = @{
            All = $parameterSets
            EnableRule = $parameterSets.where({ $_.ContainsKey('EnableRule') })
            TargetPath = @{
                All = $parameterSets.where({ $_.ContainsKey('TargetPath') })
                EnableRule = $parameterSets.where({ $_.ContainsKey('EnableRule') -and $_.ContainsKey('TargetPath') })
                SourcePackage = $parameterSets.where({ $_.ContainsKey('SourcePackage') -and $_.ContainsKey('TargetPath') })
                SourcePath = $parameterSets.where({ $_.ContainsKey('SourcePath') -and $_.ContainsKey('TargetPath') })
            }
            TargetContent = @{
                All = $parameterSets.where({ $_.ContainsKey('TargetContent') })
                EnableRule = $parameterSets.where({ $_.ContainsKey('EnableRule') -and $_.ContainsKey('TargetContent') })
                SourcePackage = $parameterSets.where({ $_.ContainsKey('SourcePackage') -and $_.ContainsKey('TargetContent') })
                SourcePath = $parameterSets.where({ $_.ContainsKey('SourcePath') -and $_.ContainsKey('TargetContent') })
            }
            SourcePackage = @{
                All = $parameterSets.where({ $_.ContainsKey('SourcePackage') })
                Default = $parameterSets.where({ $_.ContainsKey('SourcePackage') -and (-not $_.ContainsKey('EnableRule')) })
                EnableRule = $parameterSets.where({ $_.ContainsKey('EnableRule') -and $_.ContainsKey('SourcePackage') })
            }
            SourcePath = @{
                All = $parameterSets.where({ $_.ContainsKey('SourcePath') })
                Default = $parameterSets.where({ $_.ContainsKey('SourcePath') -and (-not $_.ContainsKey('EnableRule')) })
                EnableRule = $parameterSets.where({ $_.ContainsKey('EnableRule') -and $_.ContainsKey('SourcePath') })
            }
            SourceContent = @{
                All = $parameterSets.where({ $_.ContainsKey('SourceContent') })
                EnableRule = $parameterSets.where({ $_.ContainsKey('EnableRule') -and $_.ContainsKey('SourceContent') })
                Package = $parameterSets.where({ $_.ContainsKey('SourceContent') -and $_.SourceContent -match '\.zip$' })
                Path = $parameterSets.where({ $_.ContainsKey('SourceContent') -and $_.SourceContent -notmatch '\.zip$' })
            }
        }

        context 'Source Package' {

            mock 'Test-Path' {
                $true
            } -ParameterFilter { $PSBoundParameters.PathType -eq 'Leaf' }

            it 'when EnableRule is used, it returns the expected string: <TestName>' -TestCases $testCases.SourcePackage.EnableRule -Skip {
                param($Verb,$SourceContent,$SourcePath,$SourcePackage,$TargetContent,$ComputerName,$TargetPath,$EnableRule,$Credential,$AuthType)
                
                $expectedString = " -dest:ContentPath=`"$TargetPath`" -source UserName=$($Credential.UserName),ComputerName=$ComputerName,AuthType=Basic,Password=$($Credential.GetNetworkCredential().Password),Package=`"C:\Source.zip`" -EnableRule:DoNotDelete -verb:Sync"
                & $commandName @PSBoundParameters | should be $expectedString
            }

            it 'when source is passed as SourceContent, it returns the expected string: <TestName>' -TestCases $testCases.SourceContent.Package -Skip {
                param($Verb,$SourceContent,$SourcePath,$SourcePackage,$TargetContent,$ComputerName,$TargetPath,$EnableRule,$Credential,$AuthType)
                
                $expectedString = " -dest:UserName=$($Credential.UserName),contentPath=`"$TargetPath`",ComputerName=$ComputerName,AuthType=Basic,Password=$($Credential.GetNetworkCredential().Password) -source:Package=`"$SourceContent`" -verb:Sync"
                & $commandName @PSBoundParameters | should be $expectedString
            }

            it 'when source is passed as SourcePackage, it returns the expected string: <TestName>' -TestCases $testCases.SourcePackage.Default -Skip {
                param($Verb,$SourceContent,$SourcePath,$SourcePackage,$TargetContent,$ComputerName,$TargetPath,$EnableRule,$Credential,$AuthType)
                
                $expectedString = " -dest:UserName=$($Credential.UserName),contentPath=`"$TargetPath`",ComputerName=$ComputerName,AuthType=Basic,Password=$($Credential.GetNetworkCredential().Password) -source:Package=`"$SourcePackage`" -verb:Sync"
                & $commandName @PSBoundParameters | should be $expectedString
            }

        }

        context 'Source Path' {

            mock 'Test-Path' {
                $true
            } -ParameterFilter { $PSBoundParameters.PathType -eq 'Container' }

            it 'when EnableRule is used, it returns the expected string: <TestName>' -TestCases $testCases.SourcePath.EnableRule -Skip {
                param($Verb,$SourceContent,$SourcePath,$SourcePackage,$TargetContent,$ComputerName,$TargetPath,$EnableRule,$Credential,$AuthType)
                
                $expectedString = " -dest:UserName=$($Credential.UserName),contentPath=`"$TargetPath`",ComputerName=$ComputerName,AuthType=Basic,Password=$($Credential.GetNetworkCredential().Password) -source:ContentPath=`"$SourcePath`" -EnableRule:DoNotDelete -verb:Sync"
                & $commandName @PSBoundParameters | should be $expectedString
            }

            it 'when source is passed as SourceContent, it returns the expected string: <TestName>' -TestCases $testCases.SourceContent.Path -Skip {
                param($Verb,$SourceContent,$SourcePath,$SourcePackage,$TargetContent,$ComputerName,$TargetPath,$EnableRule,$Credential,$AuthType)
                
                $expectedString = " -dest:UserName=$($Credential.UserName),contentPath=`"$TargetPath`",ComputerName=$ComputerName,AuthType=Basic,Password=$($Credential.GetNetworkCredential().Password) -source:ContentPath=`"$SourceContent`" -verb:Sync"
                & $commandName @PSBoundParameters | should be $expectedString
            }

            it 'when source is passed as SourcePackage, it returns the expected string: <TestName>' -TestCases $testCases.SourcePath.Default -Skip {
                param($Verb,$SourceContent,$SourcePath,$SourcePackage,$TargetContent,$ComputerName,$TargetPath,$EnableRule,$Credential,$AuthType)
                
                $expectedString = " -dest:UserName=$($Credential.UserName),contentPath=`"$TargetPath`",ComputerName=$ComputerName,AuthType=Basic,Password=$($Credential.GetNetworkCredential().Password) -source:ContentPath=`"$SourcePath`" -verb:Sync"
                & $commandName @PSBoundParameters | should be $expectedString
            }
        }

    }

    describe 'Invoke-MSDeploy' {
    
        $commandName = 'Invoke-MSDeploy'

        mock 'Start-Process'
    
        $parameterSets = @(
            @{
                Arguments = 'args here --and here'
                TestName = 'Default'
            }
        )
    
        $testCases = @{
            All = $parameterSets
        }
        
        context 'Execution' {
            
            it 'passes the right arguments to the MSDeploy process: <TestName>' -TestCases $testCases.All -Skip {
                param($Arguments)
            
                $null = & $commandName @PSBoundParameters

                $assMParams = @{
                    CommandName = 'Start-Process'
                    Times = 1
                    Exactly = $true
                    Scope = 'It'
                    ParameterFilter = {$PSBoundParameters.ArgumentList -eq $Arguments }
                }
                Assert-MockCalled @assMParams
            }
        }
    
        context 'Output' {
    
            $command = Get-Command -Name $commandName
            
            it 'has an outputType defined' {
                $command.OutputType | should not be $null
            }
    
            it 'returns nothing: <TestName>' -TestCases $testCases.All -Skip {
                param($Arguments)

                & $commandName @PSBoundParameters | should benullorempty

            }
        }
    }

    describe 'Sync-Website' {

        mock 'NewMsDeployCliArgumentString' {
            'string'
        }

        mock 'Invoke-MsDeploy'
        
        $mockCred = New-MockObject -Type 'System.Management.Automation.PSCredential'
        $mockCred = $mockCred | Add-Member -MemberType NoteProperty -Name UserName -Value 'username' -PassThru -Force
        $mockCred = $mockCred | Add-Member -MemberType ScriptMethod -Name GetNetworkCredential -Value {[pscustomobject]@{Password = 'passwordname'}} -PassThru -Force

        $parameterSets = @(
            @{
                SourcePath = 'c:\sourcepath'
                TargetPath = '\wwwroot'
                ComputerName = 'https://webapphere.scm.azurewebsites.net:443/msdeploy.axd?site=webapphere'
                Credential = $mockCred
                TestName = 'Azure web app'
            }
            @{
                SourcePath = 'c:\sourcepath'
                TargetPath = '/wwwroot'
                ComputerName = 'https://webapphere.scm.azurewebsites.net:443/msdeploy.axd?site=webapphere'
                Credential = $mockCred
                TestName = 'Forward slashes in TargetPath'
            }
            @{
                SourcePath = 'c:\sourcepath'
                TargetPath = '/wwwroot'
                ComputerName = 'https://webapphere.scm.azurewebsites.net:443/msdeploy.axd?site=webapphere'
                Credential = $mockCred
                DoNotDelete = $true
                TestName = 'does not remove TargetPath contents'
            }
            @{
                SourcePath = 'C:\sourcepath'
                TargetPath = '/wwwroot'
                ComputerName = 'https://webapphere.scm.azurewebsites.net:443/msdeploy.axd?site=webapphere'
                Credential = $mockCred
                TestName = 'does not remove TargetPath contents'
            }
        )
    
        $testCases = @{
            All = $parameterSets
            SiteSourcePath = $parameterSets.where({$_.SourcePath -notmatch ':'})
        }

        context 'Execution' {

             it 'when TargetPath contains forward slashes, it replaces them with back slashes: <TestName>' -TestCases $testCases.All {
                param($SourcePath, $TargetPath, $ComputerName, $Credential, $DoNotDelete)
    
                $null = & Sync-Website @PSBoundParameters

                $assMParams = @{
                    CommandName = 'NewMsDeployCliArgumentString'
                    Times = 1
                    Exactly = $true
                    Scope = 'It'
                    ParameterFilter = { 
                        $PSBoundParameters.TargetContent -eq '\wwwroot' }
                }
                Assert-MockCalled @assMParams
    
            }
        }

        context 'Output' {
    
            $command = Get-Command -Name Sync-Website
            
            it 'has an outputType defined' {
                $command.OutputType | should not be $null
            }
    
            it 'returns nothing: <TestName>' -TestCases $testCases.All {
                param($SourcePath, $TargetPath, $ComputerName, $Credential, $DoNotDelete)
    
                & Sync-Website @PSBoundParameters | should benullorempty
    
            }
        }
    }
}