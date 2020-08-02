Include ".\helpers.ps1"

properties {
	$testMessage = 'Executed Test!'
	$cleanMessage = 'Executed Clean!'

	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory= "$solutionDirectory\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"

	$publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
	$publishedxUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedxUnitTests"
	$publishedMSTestTestsDirectory = "$temporaryOutputDirectory\_PublishedMSTestTests"

	$testResultsDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
	$xUnitTestResultsDirectory = "$testResultsDirectory\xUnit"
	$MSTestTestResultsDirectory = "$testResultsDirectory\MSTest"

	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"

	$packagesPath = "$solutionDirectory\packages"
	$NUnitExe = (Find-PackagePath $packagesPath "NUnit.Runners" ) + "\Tools\nunit-console-x86.exe"
	$xUnitExe = (Find-PackagePath $packagesPath "xUnit.Runner.Console" ) + "\Tools\xunit.console.exe"
	$vsTestExe = (Get-ChildItem ("C:\Program Files (x86)\Microsoft Visual Studio*\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe")).FullName | Sort-Object $_ | select -last 1
}

task default -depends Test

FormatTaskName "`r`n`r`n-------- Executing {0} Task --------"

task Init `
	-description "Initialises the build by removing previous artifacts and creating output directories" `
	-requiredVariables outputDirectory, temporaryOutputDirectory `
{
	Assert ("Debug", "Release" -contains $buildConfiguration) `
		   "Invalid build configuration '$buildConfiguration'. Valid values are 'Debug' or 'Release'"

	Assert ("x86", "x64", "Any CPU" -contains $buildPlatform) `
		   "Invalid build platform '$buildPlatform'. Valid values are 'x86', 'x64' or 'Any CPU'"

	# Check that all tools are available
	Write-Host "Checking that all required tools are available"
 
	Assert (Test-Path $NUnitExe) "NUnit Console could not be found"
	Assert (Test-Path $xUnitExe) "xUnit Console could not be found"
	Assert (Test-Path $vsTestExe) "VSTest Console could not be found"

	# Remove previous build results
	if (Test-Path $outputDirectory) 
	{
		Write-Host "Removing output directory located at $outputDirectory"
		Remove-Item $outputDirectory -Force -Recurse
	}

	Write-Host "Creating output directory located at $outputDirectory"
	New-Item $outputDirectory -ItemType Directory | Out-Null

	Write-Host "Creating temporary output directory located at $temporaryOutputDirectory" 
	New-Item $temporaryOutputDirectory -ItemType Directory | Out-Null
}
 
task Compile `
	-depends Init `
	-description "Compile the code" `
	-requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
{ 
	Write-Host "Building solution $solutionFile"
	#msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"

	Exec { msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory" }
}

task TestNUnit `
	-depends Compile `
	-description "Run NUnit tests" `
	-precondition { return Test-Path $publishedNUnitTestsDirectory } `
	-requiredVariable publishedNUnitTestsDirectory, NUnitTestResultsDirectory `
{
	$testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
									-publishedTestsDirectory $publishedNUnitTestsDirectory `
									-testResultsDirectory $NUnitTestResultsDirectory

	Exec { &$nunitExe $testAssemblies /xml:$NUnitTestResultsDirectory\NUnit.xml /nologo /noshadow }
}

task TestXUnit `
	-depends Compile `
	-description "Run xUnit tests" `
	-precondition { return Test-Path $publishedxUnitTestsDirectory } `
	-requiredVariable publishedxUnitTestsDirectory, xUnitTestResultsDirectory `
{
	$testAssemblies = Prepare-Tests -testRunnerName "xUnit" `
									-publishedTestsDirectory $publishedxUnitTestsDirectory `
									-testResultsDirectory $xUnitTestResultsDirectory

	Exec { &$xUnitExe $testAssemblies -xml $xUnitTestResultsDirectory\xUnit.xml -nologo -noshadow }
}

task TestMSTest `
	-depends Compile `
	-description "Run MSTest tests" `
	-precondition { return Test-Path $publishedMSTestTestsDirectory } `
	-requiredVariable publishedMSTestTestsDirectory, MSTestTestResultsDirectory `
{
	$testAssemblies = Prepare-Tests -testRunnerName "MSTest" `
									-publishedTestsDirectory $publishedMSTestTestsDirectory `
									-testResultsDirectory $MSTestTestResultsDirectory

	# vstest console doesn't have any option to change the output directory
	# so we need to change the working directory
	Push-Location $MSTestTestResultsDirectory
	Exec { &$vsTestExe $testAssemblies /Logger:trx }
	Pop-Location

	# move the .trx file back to $MSTestTestResultsDirectory
	Move-Item -path $MSTestTestResultsDirectory\TestResults\*.trx -destination $MSTestTestResultsDirectory\MSTest.trx

	Remove-Item $MSTestTestResultsDirectory\TestResults
}

task Test `
    -depends Compile, TestNUnit, TestXUnit, TestMSTest  `
	-description "Run unit tests"
{
  Write-Host $testMessage
}

task Clean -description "Remove temporary files" { 
  Write-Host $cleanMessage
}