function New-Topic {
<#
    .SYNOPSIS
    This script can be used to provision a namespace and topic.
            
    .DESCRIPTION
    This script can be used to provision a namespace and a topic. 
    
    .PARAMETER  Path
    Specifies the full path of the topic.

    .PARAMETER  AutoDeleteOnIdle
    Specifies after how many minutes the topic is automatically deleted. The minimum duration is 5 minutes.

    .PARAMETER  DefaultMessageTimeToLive
    Specifies default message time to live value in minutes. This is the duration after which the message expires, 
    starting from when the message is sent to Service Bus. This is the default value used when TimeToLive is not set on a message itself.
    Messages older than their TimeToLive value will expire and no longer be retained in the message store. 
    Subscribers will be unable to receive expired messages.A message can have a lower TimeToLive value than that specified here, 
    but by default TimeToLive is set to MaxValue. Therefore, this property becomes the default time to live value applied to messages.
    
    .PARAMETER  DuplicateDetectionHistoryTimeWindow
    Specifies the duration of the duplicate detection history in minutes. The default value is 10 minutes.
    
    .PARAMETER  EnableBatchedOperations
    Specifies whether server-side batched operations are enabled.
    
    .PARAMETER  EnableFilteringMessagesBeforePublishing
    Specifies whether messages should be filtered before publishing.
    
    .PARAMETER  EnablePartitioning
    Specifies whether the topic to be partitioned across multiple message brokers is enabled. 
    
    .PARAMETER  IsAnonymousAccessible
    Specifies whether the message is anonymous accessible.
    
    .PARAMETER  MaxSizeInMegabytes
    Specifies the maximum size of the topic in megabytes, which is the size of memory allocated for the topic.
    
    .PARAMETER  RequiresDuplicateDetection
    Specifies whether the topic requires duplicate detection.
    
    .PARAMETER  SupportOrdering
    Specifies whether the topic supports ordering.
    
    .PARAMETER  UserMetadata
    Specifies the user metadata.

    .PARAMETER  Namespace
    Specifies the name of the Service Bus namespace.

#>

[CmdletBinding(PositionalBinding=$True)]
Param(
    [Parameter(Mandatory = $true)]
    [String]$Path,        	                                 # required    needs to be alphanumeric    
    [ValidateNotNullorEmpty()]
	[Int]$AutoDeleteOnIdle = -1,                             # optional    default to -1
    [ValidateNotNullorEmpty()]
	[Int]$DefaultMessageTimeToLive = -1,                     # optional    default to -1
    [ValidateNotNullorEmpty()]
	[Int]$DuplicateDetectionHistoryTimeWindow = 10,          # optional    default to 10
    [Bool]$EnableBatchedOperations = $True,                  # optional    default to true
    [Bool]$EnableFilteringMessagesBeforePublishing = $False, # optional    default to false
    [Bool]$EnablePartitioning = $False,                      # optional    default to false
    [Bool]$IsAnonymousAccessible = $False,                   # optional    default to false
    [ValidateNotNullorEmpty()]
	[Int]$MaxSizeInMegabytes = 1024,                         # optional    default to 1024
    [Bool]$RequiresDuplicateDetection = $False,              # optional    default to false
    [Bool]$SupportOrdering = $True,                          # optional    default to true
    [String]$UserMetadata = $Null,                           # optional    default to null
    [ValidatePattern("^[a-z0-9]*$")]
	[alias("NamespaceName")]
    [String]$Namespace = (Get-Variable -Name $MyInvocation.MyCommand.Module.PrivateData.MODULEVAR -ValueOnly).DefaultNameSpace
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

	# Check if the topic already exists
	try {
		if ($NamespaceManager.QueueExists($Path))
		{
			$msg = "A [$Path] queue with same name already exists in the [$Namespace] namespace.";
			$e = New-CustomErrorRecord -m $msg -cat InvalidData -o $NamespaceManager;
			Log-Error -msg $msg;
			$PSCmdlet.ThrowTerminatingError($e);
		}
	} catch {}
	if ($NamespaceManager.TopicExists($Path))
	{
		$msg = "The [$Path] topic already exists in the [$Namespace] namespace.";
		$e = New-CustomErrorRecord -m $msg -cat InvalidData -o $NamespaceManager;
		Log-Error -msg $msg;
		$PSCmdlet.ThrowTerminatingError($e);
	}
	else
	{
		$TopicDescription = New-Object -TypeName Microsoft.ServiceBus.Messaging.TopicDescription -ArgumentList $Path;
		Log-Debug -msg "Creating the [$Path] topic in the [$Namespace] namespace...";
		if ($AutoDeleteOnIdle -ge 5)
		{
			$TopicDescription.AutoDeleteOnIdle = [System.TimeSpan]::FromMinutes($AutoDeleteOnIdle);
		}
		if ($DefaultMessageTimeToLive -gt 0)
		{
			$TopicDescription.DefaultMessageTimeToLive = [System.TimeSpan]::FromMinutes($DefaultMessageTimeToLive);
		}
		if ($DuplicateDetectionHistoryTimeWindow -gt 0)
		{
			$TopicDescription.DuplicateDetectionHistoryTimeWindow = [System.TimeSpan]::FromMinutes($DuplicateDetectionHistoryTimeWindow);
		}
		$TopicDescription.EnableBatchedOperations = $EnableBatchedOperations;
		$TopicDescription.EnableFilteringMessagesBeforePublishing = $EnableFilteringMessagesBeforePublishing;
		if ($TopicDescription.EnablePartitioning) {
			$TopicDescription.EnablePartitioning = $EnablePartitioning;
		}
		$TopicDescription.IsAnonymousAccessible = $IsAnonymousAccessible;
		$TopicDescription.MaxSizeInMegabytes = $MaxSizeInMegabytes;
		$TopicDescription.RequiresDuplicateDetection = $RequiresDuplicateDetection;
		if ($EnablePartitioning)
		{
			$TopicDescription.SupportOrdering = $False;
		}
		else
		{
			$TopicDescription.SupportOrdering = $SupportOrdering;
		}
		$TopicDescription.UserMetadata = $UserMetadata;
		$OutputParameter = $NamespaceManager.CreateTopic($TopicDescription);
		Log-Info -msg "The [$Path] topic in the [$Namespace] namespace has been successfully created.";
	}

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

if($MyInvocation.ScriptName) { Export-ModuleMember -function New-Topic; } 