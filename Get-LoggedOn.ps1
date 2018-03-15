## /u/omers - reddit /r/PowerShell

<#
	.SYNOPSIS
		List the users that are logged on to a computer or check for a specific user.

	.DESCRIPTION
		This function uses the CMD application query.exe to list the users on the local system, a remote system, or a group of remote systems. It converts the query.exe objects.

		When using the -CheckFor parameter you are able to check for a specific user and the function will return true/false.

	.PARAMETER  Name
		The computer name to be queried. 

	.PARAMETER  CheckFor
		A specific username to look for.

	.EXAMPLE
		PS C:\> Get-LoggedOn

		ComputerName Username SessionState SessionType
		------------ -------- ------------ -----------
		JDOE-Laptop  JohnD    Active       console

		- Description - 
		In this example without parameters the command returns locally logged in users.

	.EXAMPLE
		PS C:\> Get-LoggedOn -Name TERMSERV01

		ComputerName Username  SessionState SessionType
		------------ --------  ------------ -----------
		TERMSERV01   JaneD     Disconnected
		TERMSERV01   JamesR    Disconnected
		TERMSERV01   ToddQ     Active        rdp-tcp
		TERMSERV01   BrianZ    Disconnected

		- Description - 
		When a computer name is specific you will se a list of users that are connected to that machine.

	.EXAMPLE
		PS C:\> Get-LoggedOn -Name TERMSERV01 -CheckFor JaneD

		ComputerName IsLoggedOn
		------------ ----------
		TERMSERV01         True

		- Description - 
		CheckFor allows you to check for a specific user on a remote machine.

	.EXAMPLE
		PS C:\> Get-LoggedOn -Name NONEXISTENT -CheckFor JaneD

		ComputerName IsLoggedOn
		------------ ----------
		NONEXISTENT  [ERROR]

		- Description - 
		If query.exe cannot access the compute for any reason it will return [ERROR]

	.EXAMPLE
		PS C:\> Get-ADComputer -Filter 'name -like "TERMSERV*"' | Get-LoggedOn -CheckFor JaneD

		ComputerName   IsLoggedOn
		------------   ----------
		TERMSERV01          False
		TERMSERV02           True
		TERMSERV03          False

		- Description - 
		You can pipe a list of computers to check multiple machines at the same time.

	.INPUTS
		System.String

	.OUTPUTS
		PSCustomObject

#>

function Get-LoggedOn
{
	[CmdletBinding()]
	[Alias('loggedon')]
	[OutputType([PSCustomObject])]
	
	Param
	(
		# Computer name to check
		[Parameter(ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
			       Position = 0)]
		[Alias('ComputerName')]
		[string]
		$Name = $env:COMPUTERNAME,
		
		# Username to check against logged in users.
		[parameter()]
		[string]
		$CheckFor
	)
	
	Process
	{
		function QueryToObject ($Computer)
		{
			$Output = @()
			$Users = query user /server:$Computer 2>&1
			if ($Users -like "*No User exists*")
			{
				$Output += [PSCustomObject]@{
					ComputerName = $Computer
					Username = $null
					SessionState = $null
					SessionType = "[None Found]"
				}
			}
			elseif ($Users -like "*Error*")
			{
				$Output += [PSCustomObject]@{
					ComputerName = $Computer
					Username = $null
					SessionState = $null
					SessionType = "[Error]"
				}
			}
			else
			{
				$Users = $Users | ForEach-Object {
					(($_.trim() -replace ">" -replace "(?m)^([A-Za-z0-9]{3,})\s+(\d{1,2}\s+\w+)", '$1  none  $2' -replace "\s{2,}", "," -replace "none", $null))
				} | ConvertFrom-Csv
				
				foreach ($User in $Users)
				{
					$Output += [PSCustomObject]@{
						ComputerName = $Computer
						Username = $User.USERNAME
						SessionState = $User.STATE.Replace("Disc", "Disconnected")
						SessionType = $($User.SESSIONNAME -Replace '#','' -Replace "[0-9]+","")
					}
					
				}
			}
			return $Output | Sort-Object -Property ComputerName
		}
		
		if ($CheckFor)
		{
			$Usernames = @()
			$Sessions = @()
			$Result = @()
			$Users = QueryToObject -Computer $Name
			
			foreach ($User in $Users) {
				$Usernames += $User.Username
				$Sessions += $User.SessionType
			}
			
			if ("[Error]" -in $Sessions)
			{
				$Result += [PSCustomObject]@{
					ComputerName = $Name
					IsLoggedOn = "[ERROR]"
				}
			}
			elseif ($CheckFor -in $Usernames -and "[*]" -notin $Sessions)
			{
				$Result += [PSCustomObject]@{
					ComputerName = $Name
					IsLoggedOn = $true
				}
			}
			else
			{
				$Result += [PSCustomObject]@{
					ComputerName = $Name
					IsLoggedOn = $false
				}
			}
			return $Result | select ComputerName,IsLoggedOn
		}
		elseif (!$CheckFor)
		{
			$Result = QueryToObject -Computer $Name
			return $Result
		}
	}

}