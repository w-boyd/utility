function Compare-ObjectGitDiff {
    <#
    .SYNOPSIS
        Returns the difference between two objects (as json) in a git diff format
    .PARAMETER ReferenceObject
        The object used as a reference for comparison.
    .PARAMETER DifferenceObject
        The object used to compare against the reference object and show changes
    .EXAMPLE
        PS> Compare-ObjectGitDiff -ReferenceObject @{"yo"="wassup"} -DifferenceObject @{"yo"="sup"}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$ReferenceObject,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$DifferenceObject
    )
    begin {
        function Format-ObjectForDiff {
            param (
                [Parameter(Mandatory = $true)]
                $Object
            )
        
            if ($null -eq $Object) {
                return
            }
            if ($Object -is [hashtable]) {
                $sortedHashtable = [ordered]@{}
                foreach ($key in $Object.Keys | Sort-Object) {
                    if ($Object[$key]) {
                        $sortedHashtable[$key] = Format-ObjectForDiff -Object $Object[$key]
                    }
                }
                return $sortedHashtable
            }
            elseif ($Object -is [array]) {
                return $Object | Sort-Object | ForEach-Object { Format-ObjectForDiff -Object $_ }
            }
            else {
                return $Object
            }
        }
    }
    process {
        try {
            $referenceObjectTempFile = New-TemporaryFile
            $differenceObjectTempFile = New-TemporaryFile

            if ($ReferenceObject -isnot [string]) {
                $ReferenceObject = Format-ObjectForDiff $ReferenceObject | ConvertTo-Json -Depth 100
            }
            if ($DifferenceObject -isnot [string]) {
                $DifferenceObject = Format-ObjectForDiff $DifferenceObject | ConvertTo-Json -Depth 100
            }

            $ReferenceObject | Set-Content -Path $referenceObjectTempFile -Force
            $DifferenceObject | Set-Content -Path $differenceObjectTempFile -Force

            $output = git diff --color --minimal --no-index $referenceObjectTempFile $differenceObjectTempFile | Out-String
            # Replace top 4 lines showing file paths and other metadata
            $n = [System.Environment]::NewLine
            $removeLines = $output.Split($n)[0..3] -join $n
            $output = $output -replace [regex]::Escape($removeLines)
            if (-not $output) {
                return Write-Verbose "No differences found" -Verbose
            }
            $output
        }
        finally {
            Remove-Item -Path $referenceObjectTempFile -Force
            Remove-Item -Path $differenceObjectTempFile -Force
        }
    }
}