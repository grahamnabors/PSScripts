<# 
Created by Graham Nabors 03/15/2018
.Synopsis
This script is used to create a new User Account in Active Directory.  
.Description
Through User input this script will create a new User Account in Active Directory. Simply run the script and follow the prompts within PowerShell.
#>

#Define ADM Creds to be called in Script
$ADMUserName = "CORP\admgraham.nabors"
$ADMPassword = Get-Content 'C:\mysecureadmstring.txt' | ConvertTo-SecureString <#
Run the following command to get your ADM credentials in a secure string text file: 
Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File C:\mysecureadmstring.txt 
#>
$ADMCred = New-Object -Typename System.Management.Automation.PSCredential -ArgumentList $ADMUserName, $ADMPassword

#Ensures AD Module is installed in PS
Import-Module ActiveDirectory -ErrorAction SilentlyContinue


#Prompt for input for new User Account
Write-Host "Is the new User a Contractor? (Default is No)" -ForegroundColor Yellow
$IsContractor = Read-Host "( Y / N )"
$FirstName = Read-Host  'Enter new User First Name' 
$LastName = Read-Host 'Enter new User Last Name' 
$Name = "$FirstName $LastName"
$sAMAccountName = Read-Host -Prompt "Please enter login name (firstname.lastname)" 
$Email = Read-Host -Prompt 'Please enter E-mail Address' 
$Password = (Read-Host -Prompt "Please enter a password for the account") 
$Department = Read-Host -Prompt 'Please enter Department for User' 
$Title = Read-Host -Prompt 'Please enter Job Title' 
$Manager = Read-Host -Prompt 'Please enter a Manager for the User. (Example: james.gillette)' 

Write-Host "Would you like to copy Group Membership from an existing User? (Default is No)" -ForegroundColor Yellow
$ReadHost = Read-Host "( Y / N )"
Switch ($ReadHost)
{
Y {$UserGroupCopyFrom = Read-Host -Prompt 'Please enter an existing User to copy Group Membership from. (Example: james.gillette)'; $GroupCopy=$True;}
N {Write-Host "No, do not copy Group Membership from an existing User"; $GroupCopy=$False}
Default {Write-Host "Default, do not copy Group Membership from an existing User"; $GroupCopy=$False}

}

#Set additional variables
$DisplayName = "$FirstName $LastName"
$OUPath = 'OU=Users,OU=Austin,OU=US,DC=corp,DC=volusion,DC=com'
$Company = "Volusion"
$Office = "Kramer"
$UPNSuffix = "@volusion.com"
$ContractorUPNSuffix = "@corp.volusion.com"

#Create a hash table with parameters, use to "splat" parameters to the New-ADUser cmdlet
$Parameters = @{
'sAMAccountName' = $sAMAccountName
'Name' = $Name
'GivenName' = $FirstName
'Surname' = $LastName
'EmailAddress' = $Email
'DisplayName' = "$DisplayName"
'AccountPassword' = $Password
'ChangePasswordAtLogon' = $true
'Enabled' = $true
'Path' = $OUPath
'Department' = $Department
'Title' = $Title
'Manager' = $Manager
'Company' = $Company
'Description' = $Title
'Office' = $Office
}

#Call New-ADUser with the parameters set above
New-ADUser @Parameters -Credential $ADMCred

<#Set new User UPN
Set-ADUser -UserPrincipalName "$sAMAAccountName@volusion.com" -Identity $sAMAccountName#>

#Copy Group Membership from an existing User to the new User
if ($GroupCopy=$True) {
Get-ADUser -Identity $UserGroupCopyFrom -Properties memberof -Credential $ADMCred | Select-Object -ExpandProperty memberof | Add-ADGroupMember -Members $sAMAccountName -Credential $ADMCred}
else {
Write-Host "Did not copy Group Membership"}

#Sets UserPrincipalName based on previous input (whether the Account is a Contractor or Full Account)
if ($IsContractor -eq 'y') {
Set-ADUser -Identity $sAMAccountName -UserPrincipalName "$sAMAccountName$ContractorUPNSuffix" -Credential $ADMCred
}
if ($IsContractor -eq 'n') {
Set-ADUser -Identity $sAMAccountName -UserPrincipalName "$sAMAccountName$UPNSuffix" -Credential $ADMCred
}

<#
if ($IsContractor=$False) {
Set-ADUser -Identity $sAMAccountName -UserPrincipalName "$sAMAccountName$UPNSuffix"}
else {
Set-ADUser -Identity $sAMAccountName -UserPrincipalName "$sAMAccountName$ContractorUPNSuffix"}
#>

#Set extensionAttribute9
$ThisUser = Get-ADUser -Identity "$sAMAccountName" -Properties extensionAttribute9
Set-ADUser -Identity $ThisUser -add @{"extensionAttribute9"= "$Email"}

#Sleep actions in PowerShell for 20 seconds so you can take a sip of tea and feel cool while things catch up to you
Sleep -Seconds 15

#Ensures gShell Module is installed in PS
Import-Module gShell

$G4WAccountName = Read-Host -Prompt "Please enter G4W Account name for the new User (firstname.lastname)" 
$G4WUserGroupCopyFrom = Read-Host -Prompt 'Please enter an existing User to copy Group Membership from. (Example: james.gillette)'


#Creates a new User Account in G4W 
New-GAUser -UserName "$G4WAccountName" -GivenName "$FirstName" -FamilyName "$LastName"

#Causes PowerShell to wait 30 seconds after the new User's Account is created before proceeding to the Group copy step
Start-Sleep -Seconds 30

#Queries an existing User's Groups and copies them to the new User that is being created
$G4WGroups = Get-GAGroup -UserName "$G4WUserGroupCopyFrom" -Domain volusion.com
Foreach ($G4WGroup in $G4WGroups) {Add-GAGroupMember -GroupName $G4WGroup.Email -UserName "$G4WAccountName" -Role Member

$counter += 1

#Waits 5 seconds before attempting to add new User to another Group copied from an existing User
if($counter -eq 1){
    Sleep -Seconds 3
	
    #Sets the counter back to 0 so it will run the 'Foreach' action again.
    $counter = 0
}
 }