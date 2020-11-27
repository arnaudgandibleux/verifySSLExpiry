<#
.SYNOPSIS
  Add NSX-T tags with NSX-T REST API based on collected CSV input
.DESCRIPTION
  <Brief description of script>
.INPUTS
  vCenter IP/FQDN
  NSX-T Manager IP/FQDN
.OUTPUTS
.NOTES
  Version:        1.0
  Author:         Arnaud Gandibleux
  Creation Date:  10/04/2020
  Purpose/Change: Add Tags with NSX-T REST API
  Based on https://rutgerblom.com/2019/06/09/add-nsx-t-tags-to-virtual-machines-with-powershell/
.EXAMPLE
#>

$timeout = 15
$RetryInterval = 2
$watch = New-Object System.Diagnostics.Stopwatch


Function verifySSLExpiry{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string[]]$sites
    )
    Write-Host List of sites to check: $sites
    $results = @()
    
    foreach ($site in $sites) {
        $watch.Start()
                
            Write-Host "Validating..." $site

            $scriptBlock = {
                $condition = 0
                $url = $args[0]
                Write-Host $url":443"

                #$getExpiryDate = openssl s_client -servername gandibleux.eu -connect "gandibleux.eu:443" 2>/dev/null | openssl x509 -noout -enddate | cut -f2- -d=
                $getExpiryDate = openssl s_client -servername $args[0] -connect $url":443" 2>/dev/null | openssl x509 -noout -enddate | cut -f2- -d=

                $expiryDateFormat = $getExpiryDate.Split(" ")
                $expiryDateFormat = $expiryDateFormat | Where-Object {$_}
                $expiryDate = $expiryDateFormat[0]+" "+$expiryDateFormat[1]+" "+$expiryDateFormat[3]+" "+$expiryDateFormat[2]
                $expiryDate = [DateTime] $expiryDate
        
                $now = Get-Date
                
                $daysLeft = NEW-TIMESPAN –Start $now –End $expiryDate
        
                $siteResult = New-Object -TypeName psobject
                $siteResult | Add-Member -MemberType NoteProperty -Name Name -Value $url
                $siteResult | Add-Member -MemberType NoteProperty -Name expirySpan -Value $daysLeft

        
                <# if ($siteResult.expirySpan.Days -le "71") {
                    Write-Host -ForegroundColor Red "NOK"
                }
                else {
                    Write-Host -ForegroundColor Green "OK"
                } #>
                $testObject =  New-Object -TypeName psobject
                $testObject | Add-Member -MemberType NoteProperty -Name condition -Value 1
                $testObject | Add-Member -MemberType NoteProperty -Name result -Value $siteResult

                return $testObject
            }

            Start-Job -Name job1 -ScriptBlock $scriptBlock -ArgumentList $site
            $test = Receive-Job -Name 'job1'

            while ($watch.Elapsed.TotalSeconds -lt $timeout -and $test.condition -ne 1) {
                Start-Sleep -Seconds $RetryInterval
                Write-Host "Still waiting for action to complete after "$watch.Elapsed.TotalSeconds "seconds..."
            }
            $watch.Stop()

            if ($watch.Elapsed.TotalSeconds -gt $timeout) {
                Write-Host 'Action did not complete before timeout period..'
                Write-Host $test.condition
            } else {
                Write-Host 'Action completed before the timeout period.'
                Write-Host $test
            }

            #Remove-job -Name 'job1'
            write-host "--- End of validation in" $watch.Elapsed.TotalSeconds "seconds ---"
        $watch.Reset()
    

<#         $getExpiryDate = openssl s_client -servername gandibleux.eu -connect "gandibleux.eu:443" 2>/dev/null | openssl x509 -noout -enddate | cut -f2- -d=
        #$getExpiryDate = openssl s_client -servername $site -connect "${site}:443" 2>/dev/null | openssl x509 -noout -enddate | cut -f2- -d=
        $expiryDateFormat = $getExpiryDate.Split(" ")
        $expiryDateFormat = $expiryDateFormat | Where-Object {$_}
        $expiryDate = $expiryDateFormat[0]+" "+$expiryDateFormat[1]+" "+$expiryDateFormat[3]+" "+$expiryDateFormat[2]
        $expiryDate = [DateTime] $expiryDate
        
        $now = Get-Date
                
        $daysLeft = NEW-TIMESPAN –Start $now –End $expiryDate
        
        $siteResult = New-Object -TypeName psobject
        $siteResult | Add-Member -MemberType NoteProperty -Name Name -Value $site
        $siteResult | Add-Member -MemberType NoteProperty -Name expirySpan -Value $daysLeft

        $results +=$siteResult

        if ($siteResult.expirySpan.Days -le "71") {
               Write-Host -ForegroundColor Red "NOK"
        }
        else {
               Write-Host -ForegroundColor Green "OK"
        } #>


    }

    Write-Host -ForegroundColor Yellow "---RESULTS---"
    foreach ($r in $results) {
        
        if ($r.expirySpan.Days -le "71") {
            Write-Host -ForegroundColor Red $r.Name - $r.expirySpan.Days "Days Left"
        }
        else {
            Write-Host $r.Name - $r.expirySpan.Days "Days Left"
        }
    }
    Write-Host -ForegroundColor Yellow "---END OF RESULTS---"


}
Export-ModuleMember -Function ‘verifySSLExpiry’


