[CmdletBinding()]
param([string]$RepositoryRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path,[switch]$FullTests)
$ErrorActionPreference='Stop'; Set-Location $RepositoryRoot; $env:PYTHONPATH=Join-Path $RepositoryRoot 'src'
$Args=@('-m','sgoda.pmo.closure.closure_orchestrator','--root',$RepositoryRoot,'--output','artifacts/closure/spb-003.2')
if($FullTests){$Args+='--full-tests'}
python @Args
exit $LASTEXITCODE