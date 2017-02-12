# PSWebDeploy
PSWebDeploy is a PowerSHell module that wraps PowerShell around msdeploy.exe. This greatly eases figuring out the long syntax required for msdeploy.exe.

## Sync-Website

This function uses the msdeploy `sync` verb to sync local contents to a remote web server.

## Get-WebsiteFile

This function uses the msdeploy `dump` verb to retrieve a list of files from a remote web server.
