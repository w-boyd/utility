function Get-Diff {
    <#
    .SYNOPSIS
        Returns the difference between two objects (as json) in a git diff format
    .PARAMETER ReferenceObject
        The object used as a reference for comparison.
    .PARAMETER DifferenceObject
        The object used to compare against the reference object and show changes
    .EXAMPLE
        PS> $proc = Get-Process
        PS> Get-Diff -ReferenceObject $proc[0] -DifferenceObject $proc[1]
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

            if ($Object -is [hashtable] -or $Object -is [ordered]) {
                $sortedHashtable = [ordered]@{}
                foreach ($key in $Object.Keys | Sort-Object) {
                    if ($Object[$key]) {
                        $sortedHashtable[$key] = Format-ObjectForDiff -Object $Object[$key]
                    }
                }
                return $sortedHashtable
            }

            if ($Object.GetType().Name -eq 'PSCustomObject') {
                $sortedHashtable = [ordered]@{}
                foreach ($key in $Object.PSObject.Properties.Name | Sort-Object) {
                    if ($Object.$key) {
                        $sortedHashtable[$key] = Format-ObjectForDiff -Object $Object.$key
                    }
                }
                return $sortedHashtable
            }

            if ($Object -is [array]) {
                return $Object | Sort-Object | ForEach-Object { Format-ObjectForDiff -Object $_ }
            }

            return $Object
        }
    }
    process {
        try {
            $referenceObjectTempFile = New-TemporaryFile -WhatIf:$false -Confirm:$false
            $differenceObjectTempFile = New-TemporaryFile -WhatIf:$false -Confirm:$false

            if ($ReferenceObject -isnot [string]) {
                $ReferenceObject = Format-ObjectForDiff $ReferenceObject | ConvertTo-Json -Depth 100
            }
            if ($DifferenceObject -isnot [string]) {
                $DifferenceObject = Format-ObjectForDiff $DifferenceObject | ConvertTo-Json -Depth 100
            }

            $ReferenceObject | Set-Content -Path $referenceObjectTempFile -Force -WhatIf:$false -Confirm:$false
            $DifferenceObject | Set-Content -Path $differenceObjectTempFile -Force -WhatIf:$false -Confirm:$false

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
            Remove-Item -Path $referenceObjectTempFile -Force -WhatIf:$false -Confirm:$false
            Remove-Item -Path $differenceObjectTempFile -Force -WhatIf:$false -Confirm:$false
        }
    }
}