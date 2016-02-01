function New-Subscription {
<#
    .SYNOPSIS
    This script can be used to provision a namespace and subscription.
            
    .DESCRIPTION
    This script can be used to provision a namespace and a subscription. 

    .PARAMETER  TopicPath
    Specifies the path of the topic that this subscription description belongs to.
    
    .PARAMETER  Name
    Specifies the name of the subscription.

    .PARAMETER  AutoDeleteOnIdle
    Specifies after how many minutes the subscription is automatically deleted. The minimum duration is 5 minutes.

    .PARAMETER  DefaultMessageTimeToLive
    Specifies default message time to live value in minutes. This is the duration after which the message expires, 
    starting from when the message is sent to Service Bus. This is the default value used when TimeToLive is not set on a message itself.
    Messages older than their TimeToLive value will expire and no longer be retained in the message store. 
    Subscribers will be unable to receive expired messages.A message can have a lower TimeToLive value than that specified here, 
    but by default TimeToLive is set to MaxValue. Therefore, this property becomes the default time to live value applied to messages.
    
    .PARAMETER  EnableBatchedOperations
    Specifies whether server-side batched operations are enabled.
    
    .PARAMETER  EnableDeadLetteringOnFilterEvaluationExceptions
    Specifies whether this subscription has dead letter support on Filter evaluation exceptions.

    .PARAMETER  EnableDeadLetteringOnMessageExpiration
    Specifies whether this subscription has dead letter support when a message expires.

    .PARAMETER  ForwardTo
    Specifies the name to the recipient to which the message is forwarded.

    .PARAMETER  LockDuration
    Specifies the duration of a peek lock in seconds; that is, the amount of time that the message is locked for other receivers. 
    The maximum value for LockDuration is 5 minutes; the default value is 1 minute.
    
    .PARAMETER  MaxDeliveryCount
    Specifies the maximum delivery count. A message is automatically deadlettered after this number of deliveries.
    
    .PARAMETER  RequiresSession
    Specifies whether the subscription supports the concept of session.
    
    .PARAMETER  SupportOrdering
    Specifies whether the subscription supports ordering.
    
    .PARAMETER  UserMetadata
    Specifies the user metadata.

    .PARAMETER SqlFilter
    Specifies a filter expression written in SQL language-based syntax.

    .PARAMETER SqlRuleAction
    Specifies a set of actions written in SQL language-based syntax that is performed against a BrokeredMessage.

    .PARAMETER  Namespace
    Specifies the name of the Service Bus namespace.

#>

[CmdletBinding(PositionalBinding=$True)]
Param(
    [Parameter(Mandatory = $true)]
    [String]$TopicPath,                                              # required    needs to be alphanumeric
    [Parameter(Mandatory = $true)]
    [String]$Name,                                                   # required    needs to be alphanumeric    
    [ValidateNotNullorEmpty()]
	[Int]$AutoDeleteOnIdle = -1,                                     # optional    default to -1
    [ValidateNotNullorEmpty()]
	[Int]$DefaultMessageTimeToLive = -1,                             # optional    default to -1
    [Bool]$EnableBatchedOperations = $True,                          # optional    default to true
    [Bool]$EnableDeadLetteringOnFilterEvaluationExceptions = $True,  # optional    default to true
    [Bool]$EnableDeadLetteringOnMessageExpiration = $False,          # optional    default to false
    [String]$ForwardTo = $Null,                                      # optional    default to null
    [ValidateNotNullorEmpty()]
	[Int]$LockDuration = 30,                                         # optional    default to 30
    [ValidateNotNullorEmpty()]
	[Int]$MaxDeliveryCount = 10,                                     # optional    default to 10
    [Bool]$RequiresSession = $False,                                 # optional    default to false
    [Bool]$SupportOrdering = $True,                                  # optional    default to true
    [String]$UserMetadata = $Null,                                   # optional    default to null
    [ValidateNotNullorEmpty()]
	[String]$SqlFilter = "1=1",                                      # optional    default to null
    [String]$SqlRuleAction = $Null,                                  # optional    default to null
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

	# Check if the topic exists
	if (!$NamespaceManager.TopicExists($TopicPath))
	{
		Log-Error -msg "The [$TopicPath] topic does not exit in the [$Namespace] namespace.";
		throw($gotoSuccess);
	}

	# Check if the subscription already exists
	if ($NamespaceManager.SubscriptionExists($TopicPath, $Name))
	{
		$msg = "The [$Name] subscription already exists in the [$Namespace] namespace.";
		$e = New-CustomErrorRecord -m $msg -cat InvalidData -o $NamespaceManager;
		Log-Error -msg $msg;
		$PSCmdlet.ThrowTerminatingError($e);
	}
	else
	{
		Log-Debug -msg "Creating the [$Name] subscription for the [$TopicPath] topic in the [$Namespace] namespace...";
		Log-Debug -msg " - SqlFilter: [$SqlFilter]";
		Log-Debug -msg " - SqlRuleAction: [$SqlRuleAction]";
		$SubscriptionDescription = New-Object -TypeName Microsoft.ServiceBus.Messaging.SubscriptionDescription -ArgumentList $TopicPath, $Name;
		if ($AutoDeleteOnIdle -ge 5)
		{
			$SubscriptionDescription.AutoDeleteOnIdle = [System.TimeSpan]::FromMinutes($AutoDeleteOnIdle);
		}
		if ($DefaultMessageTimeToLive -gt 0)
		{
			$SubscriptionDescription.DefaultMessageTimeToLive = [System.TimeSpan]::FromMinutes($DefaultMessageTimeToLive);
		}
		$SubscriptionDescription.EnableBatchedOperations = $EnableBatchedOperations;
		$SubscriptionDescription.EnableDeadLetteringOnFilterEvaluationExceptions = $EnableDeadLetteringOnFilterEvaluationExceptions;
		$SubscriptionDescription.EnableDeadLetteringOnMessageExpiration = $EnableDeadLetteringOnMessageExpiration;
		$SubscriptionDescription.ForwardTo = $ForwardTo;
		if ($LockDuration -gt 0)
		{
			$SubscriptionDescription.LockDuration = [System.TimeSpan]::FromSeconds($LockDuration);
		}
		$SubscriptionDescription.MaxDeliveryCount = $MaxDeliveryCount;
		$SubscriptionDescription.RequiresSession = $RequiresSession;
		$SubscriptionDescription.UserMetadata = $UserMetadata;
		
		if ( $SqlRuleAction ) {
			$SqlFilterObject = New-Object -TypeName Microsoft.ServiceBus.Messaging.SqlFilter -ArgumentList $SqlFilter;
			$SqlRuleActionObject = New-Object -TypeName Microsoft.ServiceBus.Messaging.SqlRuleAction -ArgumentList $SqlRuleAction;
			$RuleDescription = New-Object -TypeName Microsoft.ServiceBus.Messaging.RuleDescription;
			$RuleDescription.Filter = $SqlFilterObject;
			$RuleDescription.Action = $SqlRuleActionObject;
			$OutputParameter = $NamespaceManager.CreateSubscription($SubscriptionDescription, $RuleDescription);
		} else {
			$OutputParameter = $NamespaceManager.CreateSubscription($SubscriptionDescription);
		}
		Log-Info -msg "The [$Name] subscription for the [$TopicPath] topic has been successfully created.";
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
			Log-Critical $fn ("[WebException] Request FAILED with Status '{0}'. [{1}]." -f $_.Exception.Status, $_);
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

if($MyInvocation.ScriptName) { Export-ModuleMember -function New-Subscription; }
# SIG # Begin signature block
# MIIXDwYJKoZIhvcNAQcCoIIXADCCFvwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQULenxUkwwahjjWZ3SDdvcoNwt
# ZV2gghHCMIIEFDCCAvygAwIBAgILBAAAAAABL07hUtcwDQYJKoZIhvcNAQEFBQAw
# VzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNV
# BAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw0xMTA0
# MTMxMDAwMDBaFw0yODAxMjgxMjAwMDBaMFIxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMSgwJgYDVQQDEx9HbG9iYWxTaWduIFRpbWVzdGFt
# cGluZyBDQSAtIEcyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlO9l
# +LVXn6BTDTQG6wkft0cYasvwW+T/J6U00feJGr+esc0SQW5m1IGghYtkWkYvmaCN
# d7HivFzdItdqZ9C76Mp03otPDbBS5ZBb60cO8eefnAuQZT4XljBFcm05oRc2yrmg
# jBtPCBn2gTGtYRakYua0QJ7D/PuV9vu1LpWBmODvxevYAll4d/eq41JrUJEpxfz3
# zZNl0mBhIvIG+zLdFlH6Dv2KMPAXCae78wSuq5DnbN96qfTvxGInX2+ZbTh0qhGL
# 2t/HFEzphbLswn1KJo/nVrqm4M+SU4B09APsaLJgvIQgAIMboe60dAXBKY5i0Eex
# +vBTzBj5Ljv5cH60JQIDAQABo4HlMIHiMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMB
# Af8ECDAGAQH/AgEAMB0GA1UdDgQWBBRG2D7/3OO+/4Pm9IWbsN1q1hSpwTBHBgNV
# HSAEQDA+MDwGBFUdIAAwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFs
# c2lnbi5jb20vcmVwb3NpdG9yeS8wMwYDVR0fBCwwKjAooCagJIYiaHR0cDovL2Ny
# bC5nbG9iYWxzaWduLm5ldC9yb290LmNybDAfBgNVHSMEGDAWgBRge2YaRQ2XyolQ
# L30EzTSo//z9SzANBgkqhkiG9w0BAQUFAAOCAQEATl5WkB5GtNlJMfO7FzkoG8IW
# 3f1B3AkFBJtvsqKa1pkuQJkAVbXqP6UgdtOGNNQXzFU6x4Lu76i6vNgGnxVQ380W
# e1I6AtcZGv2v8Hhc4EvFGN86JB7arLipWAQCBzDbsBJe/jG+8ARI9PBw+DpeVoPP
# PfsNvPTF7ZedudTbpSeE4zibi6c1hkQgpDttpGoLoYP9KOva7yj2zIhd+wo7AKvg
# IeviLzVsD440RZfroveZMzV+y5qKu0VN5z+fwtmK+mWybsd+Zf/okuEsMaL3sCc2
# SI8mbzvuTXYfecPlf5Y1vC0OzAGwjn//UYCAp5LUs0RGZIyHTxZjBzFLY7Df8zCC
# BCkwggMRoAMCAQICCwQAAAAAATGJxjfoMA0GCSqGSIb3DQEBCwUAMEwxIDAeBgNV
# BAsTF0dsb2JhbFNpZ24gUm9vdCBDQSAtIFIzMRMwEQYDVQQKEwpHbG9iYWxTaWdu
# MRMwEQYDVQQDEwpHbG9iYWxTaWduMB4XDTExMDgwMjEwMDAwMFoXDTE5MDgwMjEw
# MDAwMFowWjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2Ex
# MDAuBgNVBAMTJ0dsb2JhbFNpZ24gQ29kZVNpZ25pbmcgQ0EgLSBTSEEyNTYgLSBH
# MjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKPv0Z8p6djTgnY8YqDS
# SdYWHvHP8NC6SEMDLacd8gE0SaQQ6WIT9BP0FoO11VdCSIYrlViH6igEdMtyEQ9h
# JuH6HGEVxyibTQuCDyYrkDqW7aTQaymc9WGI5qRXb+70cNCNF97mZnZfdB5eDFM4
# XZD03zAtGxPReZhUGks4BPQHxCMD05LL94BdqpxWBkQtQUxItC3sNZKaxpXX9c6Q
# MeJ2s2G48XVXQqw7zivIkEnotybPuwyJy9DDo2qhydXjnFMrVyb+Vpp2/WFGomDs
# KUZH8s3ggmLGBFrn7U5AXEgGfZ1f53TJnoRlDVve3NMkHLQUEeurv8QfpLqZ0BdY
# Nc0CAwEAAaOB/TCB+jAOBgNVHQ8BAf8EBAMCAQYwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAdBgNVHQ4EFgQUGUq4WuRNMaUU5V7sL6Mc+oCMMmswRwYDVR0gBEAwPjA8BgRV
# HSAAMDQwMgYIKwYBBQUHAgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29tL3Jl
# cG9zaXRvcnkvMDYGA1UdHwQvMC0wK6ApoCeGJWh0dHA6Ly9jcmwuZ2xvYmFsc2ln
# bi5uZXQvcm9vdC1yMy5jcmwwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHwYDVR0jBBgw
# FoAUj/BLf6guRSSuTVD6Y5qL3uLdG7wwDQYJKoZIhvcNAQELBQADggEBAHmwaTTi
# BYf2/tRgLC+GeTQD4LEHkwyEXPnk3GzPbrXsCly6C9BoMS4/ZL0Pgmtmd4F/ximl
# F9jwiU2DJBH2bv6d4UgKKKDieySApOzCmgDXsG1szYjVFXjPE/mIpXNNwTYr3MvO
# 23580ovvL72zT006rbtibiiTxAzL2ebK4BEClAOwvT+UKFaQHlPCJ9XJPM0aYx6C
# WRW2QMqngarDVa8z0bV16AnqRwhIIvtdG/Mseml+xddaXlYzPK1X6JMlQsPSXnE7
# ShxU7alVrCgFx8RsXdw8k/ZpPIJRzhoVPV4Bc/9Aouq0rtOO+u5dbEfHQfXUVlfy
# GDcy1tTMS/Zx4HYwggSfMIIDh6ADAgECAhIRIQaggdM/2HrlgkzBa1IJTgMwDQYJ
# KoZIhvcNAQEFBQAwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24g
# bnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzIw
# HhcNMTUwMjAzMDAwMDAwWhcNMjYwMzAzMDAwMDAwWjBgMQswCQYDVQQGEwJTRzEf
# MB0GA1UEChMWR01PIEdsb2JhbFNpZ24gUHRlIEx0ZDEwMC4GA1UEAxMnR2xvYmFs
# U2lnbiBUU0EgZm9yIE1TIEF1dGhlbnRpY29kZSAtIEcyMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAsBeuotO2BDBWHlgPse1VpNZUy9j2czrsXV6rJf02
# pfqEw2FAxUa1WVI7QqIuXxNiEKlb5nPWkiWxfSPjBrOHOg5D8NcAiVOiETFSKG5d
# QHI88gl3p0mSl9RskKB2p/243LOd8gdgLE9YmABr0xVU4Prd/4AsXximmP/Uq+yh
# RVmyLm9iXeDZGayLV5yoJivZF6UQ0kcIGnAsM4t/aIAqtaFda92NAgIpA6p8N7u7
# KU49U5OzpvqP0liTFUy5LauAo6Ml+6/3CGSwekQPXBDXX2E3qk5r09JTJZ2Cc/os
# +XKwqRk5KlD6qdA8OsroW+/1X1H0+QrZlzXeaoXmIwRCrwIDAQABo4IBXzCCAVsw
# DgYDVR0PAQH/BAQDAgeAMEwGA1UdIARFMEMwQQYJKwYBBAGgMgEeMDQwMgYIKwYB
# BQUHAgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29tL3JlcG9zaXRvcnkvMAkG
# A1UdEwQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwQgYDVR0fBDswOTA3oDWg
# M4YxaHR0cDovL2NybC5nbG9iYWxzaWduLmNvbS9ncy9nc3RpbWVzdGFtcGluZ2cy
# LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYBBQUHMAKGOGh0dHA6Ly9zZWN1cmUu
# Z2xvYmFsc2lnbi5jb20vY2FjZXJ0L2dzdGltZXN0YW1waW5nZzIuY3J0MB0GA1Ud
# DgQWBBTUooRKOFoYf7pPMFC9ndV6h9YJ9zAfBgNVHSMEGDAWgBRG2D7/3OO+/4Pm
# 9IWbsN1q1hSpwTANBgkqhkiG9w0BAQUFAAOCAQEAgDLcB40coJydPCroPSGLWaFN
# fsxEzgO+fqq8xOZ7c7tL8YjakE51Nyg4Y7nXKw9UqVbOdzmXMHPNm9nZBUUcjaS4
# A11P2RwumODpiObs1wV+Vip79xZbo62PlyUShBuyXGNKCtLvEFRHgoQ1aSicDOQf
# FBYk+nXcdHJuTsrjakOvz302SNG96QaRLC+myHH9z73YnSGY/K/b3iKMr6fzd++d
# 3KNwS0Qa8HiFHvKljDm13IgcN+2tFPUHCya9vm0CXrG4sFhshToN9v9aJwzF3lPn
# VDxWTMlOTDD28lz7GozCgr6tWZH2G01Ve89bAdz9etNvI1wyR5sB88FRFEaKmzCC
# BNYwggO+oAMCAQICEhEhDRayW4wRltP+V8mGEea62TANBgkqhkiG9w0BAQsFADBa
# MQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEwMC4GA1UE
# AxMnR2xvYmFsU2lnbiBDb2RlU2lnbmluZyBDQSAtIFNIQTI1NiAtIEcyMB4XDTE1
# MDUwNDE2NDMyMVoXDTE4MDUwNDE2NDMyMVowVTELMAkGA1UEBhMCQ0gxDDAKBgNV
# BAgTA1p1ZzEMMAoGA1UEBxMDWnVnMRQwEgYDVQQKEwtkLWZlbnMgR21iSDEUMBIG
# A1UEAxMLZC1mZW5zIEdtYkgwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDNPSzSNPylU9jFM78Q/GjzB7N+VNqikf/use7p8mpnBZ4cf5b4qV3rqQd62rJH
# RlAsxgouCSNQrl8xxfg6/t/I02kPvrzsR4xnDgMiVCqVRAeQsWebafWdTvWmONBS
# lxJejPP8TSgXMKFaDa+2HleTycTBYSoErAZSWpQ0NqF9zBadjsJRVatQuPkTDrwL
# eWibiyOipK9fcNoQpl5ll5H9EG668YJR3fqX9o0TQTkOmxXIL3IJ0UxdpyDpLEkt
# tBG6Y5wAdpF2dQX2phrfFNVY54JOGtuBkNGMSiLFzTkBA1fOlA6ICMYjB8xIFxVv
# rN1tYojCrqYkKMOjwWQz5X8zAgMBAAGjggGZMIIBlTAOBgNVHQ8BAf8EBAMCB4Aw
# TAYDVR0gBEUwQzBBBgkrBgEEAaAyATIwNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93
# d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wCQYDVR0TBAIwADATBgNVHSUE
# DDAKBggrBgEFBQcDAzBCBgNVHR8EOzA5MDegNaAzhjFodHRwOi8vY3JsLmdsb2Jh
# bHNpZ24uY29tL2dzL2dzY29kZXNpZ25zaGEyZzIuY3JsMIGQBggrBgEFBQcBAQSB
# gzCBgDBEBggrBgEFBQcwAoY4aHR0cDovL3NlY3VyZS5nbG9iYWxzaWduLmNvbS9j
# YWNlcnQvZ3Njb2Rlc2lnbnNoYTJnMi5jcnQwOAYIKwYBBQUHMAGGLGh0dHA6Ly9v
# Y3NwMi5nbG9iYWxzaWduLmNvbS9nc2NvZGVzaWduc2hhMmcyMB0GA1UdDgQWBBTN
# GDddiIYZy9p3Z84iSIMd27rtUDAfBgNVHSMEGDAWgBQZSrha5E0xpRTlXuwvoxz6
# gIwyazANBgkqhkiG9w0BAQsFAAOCAQEAAApsOzSX1alF00fTeijB/aIthO3UB0ks
# 1Gg3xoKQC1iEQmFG/qlFLiufs52kRPN7L0a7ClNH3iQpaH5IEaUENT9cNEXdKTBG
# 8OrJS8lrDJXImgNEgtSwz0B40h7bM2Z+0DvXDvpmfyM2NwHF/nNVj7NzmczrLRqN
# 9de3tV0pgRqnIYordVcmb24CZl3bzpwzbQQy14Iz+P5Z2cnw+QaYzAuweTZxEUcJ
# bFwpM49c1LMPFJTuOKkUgY90JJ3gVTpyQxfkc7DNBnx74PlRzjFmeGC/hxQt0hvo
# eaAiBdjo/1uuCTToigVnyRH+c0T2AezTeoFb7ne3I538hWeTdU5q9jGCBLcwggSz
# AgEBMHAwWjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2Ex
# MDAuBgNVBAMTJ0dsb2JhbFNpZ24gQ29kZVNpZ25pbmcgQ0EgLSBTSEEyNTYgLSBH
# MgISESENFrJbjBGW0/5XyYYR5rrZMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBS3pccVZ38h9fSA
# JnM7fI7HXgVB5TANBgkqhkiG9w0BAQEFAASCAQAMq2lQH6QJ7EnDqZIi3FQzyU3g
# 7yCcqP6jhrV+ViA8FCmUZ4EqO4sG/c97TDomJmg+Sy32TrUOXbhaBOHYrGtSqYjz
# ZcdEDq3CUHRKfTc2xV4qekfj1c6FSe6V68qJnRxRwKdsB5Xaq26vY1u3m0uJZd84
# 6iZNTGKjQ/pQb9PV9WK6qP2eOIzIis7NcAfUL6EJNKcsXC0XwIWaCMP82ybotG8P
# hJrWyPN9XG5xA47C398RO06t3TWHEPrNKIoXWVZ4RHfiNjVWT6zp0573eCoVbYLh
# 1/5/A7AA1adk19ogm7InuVjB1w1UIH/a0IY85B+qw6RF+vzmMyCmsJRBlcPboYIC
# ojCCAp4GCSqGSIb3DQEJBjGCAo8wggKLAgEBMGgwUjELMAkGA1UEBhMCQkUxGTAX
# BgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGlt
# ZXN0YW1waW5nIENBIC0gRzICEhEhBqCB0z/YeuWCTMFrUglOAzAJBgUrDgMCGgUA
# oIH9MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE1
# MTIwMzExNTMyNVowIwYJKoZIhvcNAQkEMRYEFLD1A2cDiWMCL91jr7ZJjS8LVMZG
# MIGdBgsqhkiG9w0BCRACDDGBjTCBijCBhzCBhAQUs2MItNTN7U/PvWa5Vfrjv7Es
# KeYwbDBWpFQwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYt
# c2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzICEhEh
# BqCB0z/YeuWCTMFrUglOAzANBgkqhkiG9w0BAQEFAASCAQAc3jHeFdBvu+9yBXtC
# R3MtSANykzXXogGgU979LLmGhvoSEPYjqlfepIIu3NaUF0kdoGdYMJzA2+nFytJE
# 2zLA7i4N/zJNMbZGZNGv6zDGQC48pnR5CRqQVwR1jpq9KjnYqWbM9vAW8oTgp2IB
# L/AWEojBA6s82NXqXgIzeQQQ6C4/GdUC+BvEtFh/ZDAkkyYRTSzRtZ6yONPcGOUy
# MHRYi7Iv/r+QFKWXEXA2LT4BF/PneVm2QDAdxQcDcjTK4OUyMvaD4iexWJlgxfIn
# k7JsIdqjgsDbN60A+k3vYQt/EC5M5fyqxKtKsssfQ1SyCTnTa+0GcogVLuenfXKQ
# tfkD
# SIG # End signature block
