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
$checkInterval = 2
$minDays = 60

$smtp_user = "arnaud.gandibleux@gmail.com"
$smtp_server = "smtp.gmail.com"
$smtp_port = "587"
$from_email = "arnaud.gandibleux@gmail.com"
$to_email = "arnaud.gandibleux@gmail.com"

Function verifySSLExpiry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string[]]$sites,
        [Parameter(Mandatory = $false)][boolean]$mail_report
    )
    $watch = New-Object System.Diagnostics.Stopwatch
    $watch.Start()

    Write-Host List of sites to check: $sites
    $results = @()
    
    foreach ($site in $sites) {
        $watch_per_site = New-Object System.Diagnostics.Stopwatch
        $watch_per_site.Start()
                
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

        while ($watch_per_site.Elapsed.TotalSeconds -lt $timeout -and $test.condition -ne 1 -and $test.error -ne 1) {
            Start-Sleep -Seconds $checkInterval
            $test = Receive-Job -Name $site
            Write-Host "Waiting"$($watch_per_site.Elapsed.TotalSeconds) "seconds for action to complete..."
            
        }

        $watch_per_site.Stop()

        if ($watch_per_site.Elapsed.TotalSeconds -gt $timeout) {
            Write-Host 'Action did not complete before timeout period'
        }
        else {
            Write-Host 'Action completed before the timeout period'
            $results += $test
            
           
        }

        Remove-job -Force -Name $site
        write-host -ForegroundColor DarkCyan "--- End of validation in"$($watch_per_site.Elapsed.TotalSeconds) "seconds ---"

        $watch_per_site.Reset()

    }

    Write-Host -ForegroundColor Yellow "---RESULTS---"

    $subject = "A SSL Certificate is almost expiring in your domain"

    $body = "<h1>$($subject)</h1><p>The following SSL certificates are almost expiring. Check the underneath list to see more details.</p>"
    $body += "<ul>"

    foreach ($r in $results) {
        if ($r.expirySpan.Days -le $minDays -and $r.error -eq $null) {
            Write-Host -ForegroundColor Red $r.Name - $r.expirySpan.Days "Days Left"
            $body += "<li>$($r.Name) - $($r.expirySpan.Days) Days left</li>"
        }
        elseif ($r.error -eq $null) {
            Write-Host -ForegroundColor Green $r.Name - $r.expirySpan.Days "Days Left"
            $body += "<li>$($r.Name) - $($r.expirySpan.Days) Days left</li>"
        }
        else {
            Write-Host -ForegroundColor Red $r.Name - "Failed"
        }

    }

    $body += "</ul>"

    if ($mail_report) {
        send_email -smtp_port $smtp_port -smtp_server $smtp_server -subject $subject -from_email $from_email -to_email $to_email -body $body
    }
    $watch.Stop()
    Write-Host -ForegroundColor Yellow "---END OF RESULTS in $($watch.Elapsed.TotalSeconds) seconds---"


}
function save_smtp_credentials {

    $cred = Get-Credential
    $cred.Password | ConvertFrom-SecureString | out-file ./smtp_password.txt

}

function send_email {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$smtp_server,
        [Parameter(Mandatory = $true)][string]$smtp_port,
        [Parameter(Mandatory = $true)][string]$from_email,
        [Parameter(Mandatory = $true)][string]$to_email,
        [Parameter(Mandatory = $true)][string]$subject,
        [Parameter(Mandatory = $true)][string]$body
    )
    
    $smtp_passwd = Get-Content ./smtp_password.txt | ConvertTo-SecureString 
    $credential = New-Object System.Management.Automation.PSCredential($smtp_user, $smtp_passwd) 
    
    Send-MailMessage -WarningAction SilentlyContinue -From $from_email -To $to_email -Subject $subject -BodyAsHtml $body -UseSsl -SmtpServer $smtp_server -Port $smtp_port -Credential $credential 

}

function test_email {
    send_email -smtp_port $smtp_port -smtp_server $smtp_server -subject "verifySSLExpiry - Test mail connectivity" -from_email $from_email -to_email $to_email -body "The verifySSLExpiry mail test has successful been executed."    
}

Export-ModuleMember -Function verifySSLExpiry, save_smtp_credentials, test_email


