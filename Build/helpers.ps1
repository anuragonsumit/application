﻿function Find-PackagePath


function Prepare-Tests
{
	[CmdletBinding()]

	$projects = Get-ChildItem $publishedTestsDirectory

	if ($projects.Count -eq 1) 
	{
		Write-Host "1 $testRunnerName project has been found:"
	}
	else 
	{
		Write-Host $projects.Count " $testRunnerName projects have been found:"
	}
	
	Write-Host ($projects | Select $_.Name )

	# Create the test results directory if needed

	# Get the list of test DLLs

	$testAssemblies = [string]::Join(" ", $testAssembliesPaths)

	return $testAssemblies
}