#Requires -pssnapin quest.activeroles.admanagement
#Requires -Version 2.0
#Author:	Jason Walker
#Last Modified Date: 		6/3/2011
Function Get-LockedOutLocation
{
<#
.Synopsis
	Get a user last lock out location from the event logs on a domain controller
	
.Parameter (User)
	The User paramerter is the SamAccount name of the user who is locked out.

.Parameter (EventCombDir)
	The EvenCombDir is the directory that eventcombmt.exe is located in.
	This is 'D:\Tools\AccountLockout' by default.
	
.Parameter (LogsDirectory)
	The LogsDirectory is the directory that the report of the security logs will be created in.
		
.Description
	The Get-LockedOutLocation funcion queries all the domain controllers in the environment for a user's last
	BadPwdCount, LockOutTime, and BadPassWordTime properties.  The script then passes the hostname of the domain
	controller that has the most bad password attempts to eventcombMT.exe to find the event log that has the source
	of the bad password attempt.
	
	This script requires the Quest AD cmdlets and eventcombMT.exe.  The default location for eventcombMT.exe
	is 'D:\Tools\AccountLockout'.
	The Default log directory is D:\Tools.
	However these can be changed with with the EventCombDir and LogsDirectory parameters.
	
	EventCombMT.exe can be downloaded at this link:
	http://www.microsoft.com/downloads/en/details.aspx?FamilyID=7AF2E69C-91F3-4E63-8629-B999ADDE0B9E&displaylang=en
	
	Quest AD cmdlets can be downloaded at this link:
	http://www.quest.com/powershell/activeroles-server.aspx
	
.Example
	Get-LockedOutLocation -User afg012
	
.Example
	Get-LockedOutLocation -User afg002 -EventCombDir 'D:\EventComb' -LogsDirectory 'D:\Logs'
	
#>
Param
	(
		[parameter(Mandatory=$true)]             
	    [string]$User,               
		[string]$EventCombDir = "D:\Tools\AccountLockout",
		[string]$LogsDirectory = $PWD			
	)


Begin
	{
		$EventIDs = "529 644 675 676 681"
		$PasswordStats = @()
		#Calculate UTC Offset
		$Date = Get-Date
		$UTC = $date.ToUniversalTime()
		$Offset = ($Date - $UTC).hours
		$User = $User.ToUpper()
	    	
	    #Verify EventCombMT.exe exists
	    $VerifyEventCombMT = Test-Path -Path $EventCombDir\EventCombMT.exe
    If (-not($VerifyEventCombMT))
        {
			Write-Warning "EventCombMT.exe not found in $EventCombDir"
	        Write-Warning "This Script requires EventCombMT.exe.  Please enter correct path"
	        Write-Warning "or google Account Lockout Tools on Bing.com for a download link." 
	        Break
        }#end verify EventCombMT
		
		""
        Write-Host "EventCombMT.exe found" -ForegroundColor Green
		
    #Verify $LogDir
    $VerifyLogsDir = Test-Path -Path $LogsDirectory
    If (-not($VerifyLogsDir))
        {
			 ""
			 Write-Host "LogsDirectory : $LogsDirectory not found" -Foregroundcolor Red
	         Break
        } #end verify Logs directory
        Write-Host "Logs Directory $LogsDirectory found" -ForegroundColor Green
		
    #Verify User exists
    $VerifyUser = Get-QADUser -SamAccountName $User    
	If (-not($VerifyUser))
        {Write-Warning "User $User not found"
         Break
         }#end verify user
    }

	Process
	{	
		$DomainControlers = Get-QADComputer -ComputerRole DomainController | Select-Object -ExpandProperty Name
	
	""
	"Collecting Data from Domain Controllers"
    	ForEach($DC in $DomainControlers)
    		{
	    		"Looking for LockOutTime for user $User on $DC"			
			
	        	$LockOutTime,$BadPasswordTime,$BadPwdCount = Get-QADUser -Service $DC -SamAccountName $User -IncludedProperties 'LockoutTime','BadPasswordTime','BadPwdCount' | 
	        												ForEach{ ($_.lockouttime),($_.BadPasswordTime),($_.BadPwdCount)} 
        			
        			Try
					{
        				$PasswordStats += New-Object -TypeName PSObject -Property @{
        					LockOutTime=$LockOutTime.AddHours($offset)
        					BadPasswordTime=$BadPasswordTime.AddHours($offset)
        					BadPwdCount=$BadPwdCount
        					DomainController=$DC
        			}					
        			}#end try
        			Catch
					{
        				Write-Warning "$DC does not have a BadPasswordTime, BadPwdCount, or LockOutTime property for $User"
             		}

			} #foreach	
					
	#Find last lockout time
	$LastLockOut = $PasswordStats | Sort-Object BadPasswordTime -Descending | Select -First 2
	$LastLockOut
	
	$DCs = $LastLockOut | Select-Object -ExpandProperty DomainController
	
		
	
	If(-not($DCs))
    {
		Write-Host "$User does not have a bad password count on any Domain Controllers or" -ForegroundColor Red
		Write-Host "does not have a LockOutTime parameter.  Lock $User's account and run script again." -ForegroundColor Red
	    Break
    }
		
	$DC1 = $DCs[0]
	$DC2 = $DCs[1]
	#Laucnh EventCombMT
   	cmd /c $EventCombDir\EventcombMT.exe /s:$DC1 /s:$DC2 /text:$User /log:sec /evt:$EventIDs /et:safa /outdir:$LogsDirectory /start
    #If scan generated log file open it
    $VerifyLogFile1 = Test-path "$logsDirectory\$DC1-Security_log.txt"
	$VerifyLogFile2 = Test-Path "$logsDirectory\$DC2-Security_log.txt"
    If($VerifyLogFile1 -or $VerifyLogFile2)
    {
	    $DC1Report = "notepad.exe $logsDirectory\$DC1-Security_log.txt"
		$DC2Report = "notepad.exe $LogsDirectory\$DC2-Security_log.txt"
		#Open reports
	    Invoke-Expression $DC1Report
		Invoke-Expression $DC2Report
    }
        Else
        {
	        Write-Warning "No event logs containing $User were found.  Depending when lockout occured event logs may be overwritten."
	        		}
	}#end process
}