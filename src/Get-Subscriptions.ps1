function Get-Subscriptions {
<#
    .SYNOPSIS
    This script can be used to get all subscriptions from a topic.
            
    .DESCRIPTION
    This script can be used to get all subscriptions from a topic.

    .PARAMETER  TopicPath
    Specifies the path of the topic that this subscription description belongs to.
    
    .PARAMETER  Namespace
    Specifies the name of the Service Bus namespace.

#>

[CmdletBinding(PositionalBinding=$True)]
Param(
    [Parameter(Mandatory = $true)]
    [String]$TopicPath,                 # required    needs to be alphanumeric
    [ValidatePattern("^[a-z0-9]*$")]
	[alias("NamespaceName")]
    [String]$Namespace = $biz_dfch_PS_Azure_ServiceBus_Setup.DefaultNameSpace
    )
	
BEGIN 
{
	$datBegin = [datetime]::Now;
	[string] $fn = $MyInvocation.MyCommand.Name;
	
	$PSDefaultParameterValues.'Log-Debug:fn' = $fn;
	$PSDefaultParameterValues.'Log-Debug:fac' = 0;
	$PSDefaultParameterValues.'Log-Info:fn' = $fn;
	$PSDefaultParameterValues.'Log-Error:fn' = $fn;

}
# BEGIN

PROCESS 
{

# Default test variable for checking function response codes.
[Boolean] $fReturn = $false;
# Return values are always and only returned via OutputParameter.
$OutputParameter = $null;

try 
{
	# Parameter validation
	if(!$PSCmdlet.ShouldProcess(($PSBoundParameters | Out-String)))
	{
		throw($gotoSuccess);
	}
	
	# Set the output level to verbose and make the script stop on error
	$VerbosePreference = "Continue";
	$ErrorActionPreference = "Stop";

	# Create Service Bus namespace
	$CurrentNamespace = Get-SBNamespace -Name $Namespace;

	# Check if the namespace already exists or needs to be created
	if ($CurrentNamespace)
	{
		Log-Debug -msg "The namespace [$Namespace] already exists.";
	}
	else
	{
		Log-Debug -msg "The [$Namespace] namespace does not exist.";
		Log-Debug -msg "Creating the [$Namespace] namespace...";
		New-SBNamespace -Name $Namespace;
		$CurrentNamespace = Get-SBNamespace -Name $Namespace;
		Log-Debug -msg "The [$Namespace] namespace has been successfully created.";
	}

	# Get namespace connections string
	$ConnectionString = Get-SBClientConfiguration -Namespaces $Namespace;
	Log-Debug -msg "ConnectionString of [$Namespace] namespace: [$ConnectionString]";

	# Create the NamespaceManager object to create the subscription
	Log-Debug -msg "Creating a NamespaceManager object for the [$Namespace] namespace..."
	$NamespaceManager = [Microsoft.ServiceBus.NamespaceManager]::CreateFromConnectionString($ConnectionString);
	Log-Debug -msg "NamespaceManager object for the [$Namespace] namespace has been successfully created.";

	# Check if the topic exists
	if (!$NamespaceManager.TopicExists($TopicPath))
	{
		Log-Error -msg "The [$TopicPath] topic does not exit in the [$Namespace] namespace.";
		throw($gotoSuccess);
	}

	# Get subscriptions
	$OutputParameter = $NamespaceManager.GetSubscriptions($TopicPath);

	$fReturn = $true;

}
catch 
{
	if($gotoSuccess -eq $_.Exception.Message) 
	{
		$fReturn = $true;
	} 
	else 
	{
		[string] $ErrorText = "catch [$($_.FullyQualifiedErrorId)]";
		$ErrorText += (($_ | fl * -Force) | Out-String);
		$ErrorText += (($_.Exception | fl * -Force) | Out-String);
		$ErrorText += (Get-PSCallStack | Out-String);
		
		if($_.Exception -is [System.Net.WebException]) 
		{
			Log-Critical $fn ("[WebException] Request FAILED with Status '{0}'. [{1}]." -f $_.Status, $_);
			Log-Debug $fn $ErrorText -fac 3;
		}
		else 
		{
			Log-Error $fn $ErrorText -fac 3;
			if($gotoError -eq $_.Exception.Message) 
			{
				Log-Error $fn $e.Exception.Message;
				$PSCmdlet.ThrowTerminatingError($e);
			} 
			elseif($gotoFailure -ne $_.Exception.Message) 
			{ 
				Write-Verbose ("$fn`n$ErrorText"); 
			} 
			else 
			{
				# N/A
			}
		}
		$fReturn = $false;
		$OutputParameter = $null;
	}
}
finally 
{
	# Clean up
	# N/A
}

}
# PROCESS

END 
{

$datEnd = [datetime]::Now;
Log-Debug -fn $fn -msg ("RET. fReturn: [{0}]. Execution time: [{1}]ms. Started: [{2}]." -f $fReturn, ($datEnd - $datBegin).TotalMilliseconds, $datBegin.ToString('yyyy-MM-dd HH:mm:ss.fffzzz')) -fac 2;

# Return values are always and only returned via OutputParameter.
return $OutputParameter;

}
# END

} # function

if($MyInvocation.ScriptName) { Export-ModuleMember -function Get-Subscriptions; }