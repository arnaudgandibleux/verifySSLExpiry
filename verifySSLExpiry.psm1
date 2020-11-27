<#
.SYNOPSIS
  Verify SSL Expiry Date of given sites
.DESCRIPTION
  <Brief description of script>
.INPUTS
  SITE URL
.OUTPUTS
.NOTES
  Version:        0.2
  Author:         Arnaud Gandibleux
  Creation Date:  26/12/2020
  Purpose/Change: Verify SSL Expiry Date of given sites
.EXAMPLE
#>

$timeout = 15
$RetryInterval = 2
$watch = New-Object System.Diagnostics.Stopwatch
$totalTime = 0;


Function verifySSLExpiry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string[]]$sites
    )
    Write-Host List of sites to check: $sites
    $results = @()
    
    foreach ($site in $sites) {
        $watch.Start()
                
        Write-Host -ForegroundColor Cyan "Validating..." $site

        $scriptBlock = {
            $url = $args[0]

            $getExpiryDate = openssl s_client -servername $args[0] -connect $url":443" 2>/dev/null | openssl x509 -noout -enddate  | cut -f2- -d= 

            $siteResult = New-Object -TypeName psobject
            $siteResult | Add-Member -MemberType NoteProperty -Name Name -Value $url

            try {
                $expiryDateFormat = $getExpiryDate.Split(" ")
                $expiryDateFormat = $expiryDateFormat | Where-Object { $_ }
                $expiryDate = $expiryDateFormat[0] + " " + $expiryDateFormat[1] + " " + $expiryDateFormat[3] + " " + $expiryDateFormat[2]
                $expiryDate = [DateTime] $expiryDate
            
                $now = Get-Date
                    
                $daysLeft = NEW-TIMESPAN –Start $now –End $expiryDate
                $siteResult | Add-Member -MemberType NoteProperty -Name condition -Value 1

            }
            catch {
                Write-Error "Please verify URL: $url"
                $siteResult | Add-Member -MemberType NoteProperty -Name error -Value 1
                $daysLeft = 0
            }

            $siteResult | Add-Member -MemberType NoteProperty -Name expirySpan -Value $daysLeft


            return $siteResult
        }

        Start-Job -Name $site -ScriptBlock $scriptBlock -ArgumentList $site | Out-Null
        $test = Receive-Job -Name $site

        while ($watch.Elapsed.TotalSeconds -lt $timeout -and $test.condition -ne 1 -and $test.error -ne 1) {
            $test = Receive-Job -Name $site
            Write-Host "Waiting"$([math]::floor($watch.Elapsed.TotalSeconds)) "seconds for action to complete..."
            Start-Sleep -Seconds $RetryInterval
        }

        $watch.Stop()

        if ($watch.Elapsed.TotalSeconds -gt $timeout) {
            Write-Host 'Action did not complete before timeout period'
        }
        else {
            Write-Host 'Action completed before the timeout period'
            $results += $test
            
           
        }

        Remove-job -Force -Name $site
        write-host -ForegroundColor Cyan "--- End of validation in" $watch.Elapsed.TotalSeconds "seconds ---"

        $totalTime += $watch.Elapsed.TotalSeconds
        $watch.Reset()

    }

    Write-Host -ForegroundColor Yellow "---RESULTS---"
    foreach ($r in $results) {
        if ($r.expirySpan.Days -le "70" -and $r.error -eq $null) {
            Write-Host -ForegroundColor Red $r.Name - $r.expirySpan.Days "Days Left"
        }
        elseif ($r.error -eq $null) {
            Write-Host -ForegroundColor Green $r.Name - $r.expirySpan.Days "Days Left"
        }
        else {
            Write-Host -ForegroundColor Red $r.Name - "Failed"
        }
    }
    Write-Host -ForegroundColor Yellow "---END OF RESULTS in $totalTime seconds---"


}

Export-ModuleMember -Function ‘verifySSLExpiry’


