#Obtain user

$User = Read-Host -Prompt "Please enter a user name"



#Specify PDCe

$PDC = Get-ADDomainController -Discover -Service PrimaryDC



#Collect lockout events for user from last hour

Get-WinEvent -ComputerName $PDC ` -Logname Security ` -FilterXPath "*[System[EventID=4740 and TimeCreated[timediff(@SystemTime) <= 3600000]] and EventData[Data[@Name='TargetUserName']='$User']]" |Select-Object TimeCreated,@{Name='User Name';Expression={$_.Properties[0].Value}},@{Name='Source Host';Expression={$_.Properties[1].Value}}

#Collect bad password events for user from last hour

Get-WinEvent -ComputerName $PDC ` -Logname Security ` -FilterXPath "*[System[EventID=4771 and TimeCreated[timediff(@SystemTime) <= 36000000]] and EventData[Data[@Name='TargetUserName']='$User']]" |Select-Object TimeCreated,@{Name='User Name';Expression={$_.Properties[0].Value}},@{Name='Source Host';Expression={$_.Properties[1].Value}}