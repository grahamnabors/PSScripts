#Function to get computer's serial number, usage Get-SerialNumber [computer]
 
function Get-SerialNumber {
    param
    (
        [Parameter(Mandatory = $True)]
        [Object]$computer
    )
    $cred = Get-Credential
 
    $Serial = Get-WmiObject win32_bios -ComputerName $computer -Credential $cred | Select-Object -ExpandProperty SerialNumber
 
    return $Serial

}# close function