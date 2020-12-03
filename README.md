# PowerShell verifySSLExpiry

Powershell script to verify SSL Expiry Date of given sites
  - Check multiple sites at once
  - Send report e-mail when SSL expires within X days
  
## Installation

Install PowerShell.
Download this PowerShell Module and import it

```sh
$ git clone https://github.com/arnaudgandibleux/verifySSLExpiry.git
$ Import-Module ./verifySSLExpiry.psm1
```
## Usage

Open PowerShell and run

```sh
$ verifySSLExpiry -sites SITE 1, SITE 2, SITE 3,...,SITE X
```
###Example

Use URL without specifying port or protocol. Ex. Use gandibleux.eu instead of https://gandibleux.eu

```sh
$ verifySSLExpiry -sites gandibleux.eu
```

### Send mail report

To send a mail with the results of the validation, you first need to configure mail.

Fill in the following parameters with the pwsh module (verifySSLExpiry.psm1):
* $smtp_user
* $smtp_server
* $smtp_port
* $from_email
* $to_email

Run the following command to save the SMTP password
```sh
$ save_smtp_credentials
```
Fill in the username and password which will be used for the smtp server. The password will get saved in the file: smtp_password.txt
It's not saved plain text, but be carefull as the password can easily be retrieved within PowerShell. Recommendation: Use a dedicated and unique password for this 

#### Test your email configuration
```sh
$ test_email
```

#### Usage of mail

Specify the mail_report flag. Use the value 1 to enable mail. 
```sh
$ verifySSLExpiry -sites SITE 1, SITE 2, SITE 3,...,SITE X -mail_report 1
```

## Development

See any bugs or do you want to improve it?
Feel free to contribute!

