﻿function New-Queue {
<#
    .SYNOPSIS
    This script can be used to provision a namespace and queue.
            
    .DESCRIPTION
    This script can be used to provision a namespace and a queue. 
    
    .PARAMETER  Path
    Specifies the full path of the queue.

    .PARAMETER  AutoDeleteOnIdle
    Specifies after how many minutes the queue is automatically deleted. The minimum duration is 5 minutes.

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
    
    .PARAMETER  EnableDeadLetteringOnMessageExpiration
    Specifies whether this queue has dead letter support when a message expires.
         
    .PARAMETER  EnablePartitioning
    Specifies whether the queue to be partitioned across multiple message brokers is enabled. 
        
    .PARAMETER  ForwardTo
    Specifies the path to the recipient to which the message is forwarded.
    
    .PARAMETER  IsAnonymousAccessible
    Specifies whether the message is anonymous accessible.

    .PARAMETER  LockDuration
    Specifies the duration of a peek lock in seconds; that is, the amount of time that the message is locked for other receivers. 
    The maximum value for LockDuration is 5 minutes; the default value is 1 minute.
    
    .PARAMETER  MaxDeliveryCount
    Specifies the maximum delivery count. A message is automatically deadlettered after this number of deliveries.
    
    .PARAMETER  MaxSizeInMegabytes
    Specifies the maximum size of the queue in megabytes, which is the size of memory allocated for the queue.
    
    .PARAMETER  RequiresDuplicateDetection
    Specifies whether the queue requires duplicate detection.
    
    .PARAMETER  RequiresSession
    Specifies whether the queue supports the concept of session.
    
    .PARAMETER  SupportOrdering
    Specifies whether the queue supports ordering.
    
    .PARAMETER  UserMetadata
    Specifies the user metadata.

    .PARAMETER  Namespace
    Specifies the name of the Service Bus namespace.

#>

[CmdletBinding(PositionalBinding=$True)]
Param(
    [Parameter(Mandatory = $true)]
	[alias("queue")]
    [String]$Path,                                           # required    needs to be alphanumeric    
    [ValidateNotNullorEmpty()]
	[Int]$AutoDeleteOnIdle = -1,                             # optional    default to -1
    [ValidateNotNullorEmpty()]
	[Int]$DefaultMessageTimeToLive = -1,                     # optional    default to -1
    [ValidateNotNullorEmpty()]
	[Int]$DuplicateDetectionHistoryTimeWindow = 10,          # optional    default to 10
	[Bool]$EnableBatchedOperations = $True,                  # optional    default to true
	[Bool]$EnableDeadLetteringOnMessageExpiration = $False,  # optional    default to false
    [Bool]$EnablePartitioning = $False,                      # optional    default to false
    [String]$ForwardTo = $Null,                              # optional    default to null
    [Bool]$IsAnonymousAccessible = $False,                   # optional    default to false
	[ValidateNotNullorEmpty()]
    [Int]$LockDuration = 60,                                 # optional    default to 60
	[ValidateNotNullorEmpty()]
    [Int]$MaxDeliveryCount = 10,                             # optional    default to 10
    [ValidateNotNullorEmpty()]
	[Int]$MaxSizeInMegabytes = 1024,                         # optional    default to 1024
    [Bool]$RequiresDuplicateDetection = $False,              # optional    default to false
    [Bool]$RequiresSession = $False,                         # optional    default to false
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

	# Create the NamespaceManager object to create the queue
	Log-Debug -msg "Creating a NamespaceManager object for the [$Namespace] namespace...";
	$NamespaceManager = [Microsoft.ServiceBus.NamespaceManager]::CreateFromConnectionString($ConnectionString);
	Log-Debug -msg "NamespaceManager object for the [$Namespace] namespace has been successfully created.";

	# Check if the queue already exists
	try {
		if ($NamespaceManager.TopicExists($Path))
		{
			$msg = "A [$Path] topic with same name already exists in the [$Namespace] namespace.";
			$e = New-CustomErrorRecord -m $msg -cat InvalidData -o $NamespaceManager;
			Log-Error -msg $msg;
			$PSCmdlet.ThrowTerminatingError($e);
		}
	} catch {}
	if ($NamespaceManager.QueueExists($Path))
	{
		$msg = "The [$Path] queue already exists in the [$Namespace] namespace.";
		$e = New-CustomErrorRecord -m $msg -cat InvalidData -o $NamespaceManager;
		Log-Error -msg $msg;
		$PSCmdlet.ThrowTerminatingError($e);
	} 
	else
	{
		Log-Debug -msg "Creating the [$Path] queue in the [$Namespace] namespace...";
		$QueueDescription = New-Object -TypeName Microsoft.ServiceBus.Messaging.QueueDescription -ArgumentList $Path;
		if ($AutoDeleteOnIdle -ge 5)
		{
			$QueueDescription.AutoDeleteOnIdle = [System.TimeSpan]::FromMinutes($AutoDeleteOnIdle);
		}
		if ($DefaultMessageTimeToLive -gt 0)
		{
			$QueueDescription.DefaultMessageTimeToLive = [System.TimeSpan]::FromMinutes($DefaultMessageTimeToLive);
		}
		if ($DuplicateDetectionHistoryTimeWindow -gt 0)
		{
			$QueueDescription.DuplicateDetectionHistoryTimeWindow = [System.TimeSpan]::FromMinutes($DuplicateDetectionHistoryTimeWindow);
		}
		$QueueDescription.EnableBatchedOperations = $EnableBatchedOperations;
		$QueueDescription.EnableDeadLetteringOnMessageExpiration = $EnableDeadLetteringOnMessageExpiration;
		if ( $QueueDescription.EnablePartitioning ) {
			$QueueDescription.EnablePartitioning = $EnablePartitioning;
		}
		$QueueDescription.ForwardTo = $ForwardTo;
		$QueueDescription.IsAnonymousAccessible = $IsAnonymousAccessible;
		if ($LockDuration -gt 0)
		{
			$QueueDescription.LockDuration = [System.TimeSpan]::FromSeconds($LockDuration);
		}
		$QueueDescription.MaxDeliveryCount = $MaxDeliveryCount;
		$QueueDescription.MaxSizeInMegabytes = $MaxSizeInMegabytes;
		$QueueDescription.RequiresDuplicateDetection = $RequiresDuplicateDetection;
		$QueueDescription.RequiresSession = $RequiresSession;
		if ($EnablePartitioning)
		{
			$QueueDescription.SupportOrdering = $False;
		}
		else
		{
			$QueueDescription.SupportOrdering = $SupportOrdering;
		}
		$QueueDescription.UserMetadata = $UserMetadata;
		$OutputParameter = $NamespaceManager.CreateQueue($QueueDescription);
		Log-Info -msg "The [$Path] queue in the [$Namespace] namespace has been successfully created.";
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

if($MyInvocation.ScriptName) { Export-ModuleMember -function New-Queue; }
# SIG # Begin signature block
# MIIXDwYJKoZIhvcNAQcCoIIXADCCFvwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUsLEptCgEX/ROyvTRjUBEU7fN
# U3+gghHCMIIEFDCCAvygAwIBAgILBAAAAAABL07hUtcwDQYJKoZIhvcNAQEFBQAw
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
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSi7wRt5+qlqmH9
# wPqCfBsOw1ie6jANBgkqhkiG9w0BAQEFAASCAQAGBr83y5NU3dhvTjYWFww7E2lo
# 0FX3/rfnMnaxB7Gqd5/TEMpxTnOsA9q+e7xXGGFzzdTKAGAWiu+tVT16U8j4c1av
# 6iDEyyGMytJjqC1Mnm8ASEIqjNGqTWMdV0mLR+D0BEQMbtaBMwBrI/vKY/Hs3oHJ
# yQl45PcsG9MrAIzgm209MPHT7DiRQ2Fr5++gmepv2UuOJVuA8xb2csS9rFueABCz
# wjxh2OX4CwaxuXp2GlJrSnG5gbKapI6VAJWSUHgmAj5woUFwLDtufsP2P9/3yrGz
# EJ6P6BDB+MPNh2OuBB11BBXiSNcNhEnf8x4ny3YHykgarNMcUMG5/qFUODpooYIC
# ojCCAp4GCSqGSIb3DQEJBjGCAo8wggKLAgEBMGgwUjELMAkGA1UEBhMCQkUxGTAX
# BgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGlt
# ZXN0YW1waW5nIENBIC0gRzICEhEhBqCB0z/YeuWCTMFrUglOAzAJBgUrDgMCGgUA
# oIH9MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE1
# MTIwMzExNTMyNVowIwYJKoZIhvcNAQkEMRYEFMloLqaeK7l9ASUOdRcxMWzOwKCj
# MIGdBgsqhkiG9w0BCRACDDGBjTCBijCBhzCBhAQUs2MItNTN7U/PvWa5Vfrjv7Es
# KeYwbDBWpFQwUjELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYt
# c2ExKDAmBgNVBAMTH0dsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gRzICEhEh
# BqCB0z/YeuWCTMFrUglOAzANBgkqhkiG9w0BAQEFAASCAQBrmLDvf7ijlF0EqJVQ
# 9cvP+2Bq0YGYkJqOJhx/pOQCBAKLfnRJq9zzqgFUOd7D4MBhaibGA+TsUGbdjYJZ
# 1EUJUFDKnZUE7j5jFiB4/1JPf6zES2ff0PUwigCdakoQxQWWkLZm0V8RQTX8Mt2c
# FkDav1BGFIhmkZNCyLW9i7xcLUeRdyqVTLSG5V6K9p0MfF/YNB/IIuVUxQMnTmjs
# WkKl8NnA6VxBaqre+PfAbDmCeQ3+3b8Jh8OKuffOwo1Xli5obhk5tSY9K582xHX9
# WHXRNIUc8C9yRUXUSdqfHPUZ/i61JPfRBPAFrw6BjiXIpCvtyjtdvE+wIPCmajfe
# 7c69
# SIG # End signature block
