<#
.SYNOPSIS
Searches for regular expressions across files and directories.

.LINK
https://github.com/davidknise/psrep
#>
function Invoke-PSRep
{
    [CmdletBinding(DefaultParameterSetName="Directory")]
    Param
    (
        [Parameter(ParameterSetName="File", Mandatory=$true)]
        [String] $FilePath,

        [Parameter(ParameterSetName="Directory")]
        [String] $Directory,

        [Parameter(ParameterSetName="Directory")]
        [Switch] $NotRecurse,

        [Parameter(ParameterSetName="Directory")]
        [String] $Filter,

        [Parameter(ParameterSetName="Directory")]
        [String[]] $Exclude,

        [Parameter(ParameterSetName="File", Position=0, Mandatory=$true)]
        [Parameter(ParameterSetName="Directory", Position=0, Mandatory=$true)]
        [String] $Pattern,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [Switch] $String,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [System.Text.RegularExpressions.RegexOptions] $RegexOptions = [System.Text.RegularExpressions.RegexOptions]::None,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [Switch] $CaseSensitive,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [String] $OutputType,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [String] $MatchFileColor,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [String] $MatchColor,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [String] $MatchLineNumberColor,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [String] $NotMatchLineNumberColor,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [String] $MatchIdentifier,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [String] $IndentChar = ' ',

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [Int] $IndentSize = 2,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [Int] $MinimumIndent = 5,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [String] $LineSeparator,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [Int] $LinesPadding = 2,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [Int] $LinesBefore = 0,

        [Parameter(ParameterSetName="File")]
        [Parameter(ParameterSetName="Directory")]
        [Int] $LinesAfter = 0
    )

    if ($PSCmdlet.ParameterSetName -ieq 'Directory' -and [String]::IsNullOrWhiteSpace($Directory))
    {
        $Directory = $PWD
    }

    if (-not $Exclude)
    {
        $Exclude = @('*.exe', '*.dll', '*.pdb', '*.jar')
    }

    $regexPattern = $Pattern

    if ($String.IsPresent)
    {
        $regexPattern = [System.Text.RegularExpressions.Regex]::Escape($Pattern)
    }

    if ($RegexOptions -eq [System.Text.RegularExpressions.RegexOptions]::None -and -not $CaseSensitive.IsPresent)
    {
        $RegexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    }

    if ([String]::IsNullOrWhiteSpace($MatchFileColor))
    {
        $MatchFileColor = 'Cyan'
    }

    if ([String]::IsNullOrWhiteSpace($MatchColor))
    {
        $MatchColor = 'Cyan'
    }

    if ([String]::IsNullOrWhiteSpace($MatchLineNumberColor))
    {
        $MatchLineNumberColor = 'Green'
    }

    if ([String]::IsNullOrWhiteSpace($NotMatchLineNumberColor))
    {
        $NotMatchLineNumberColor = 'DarkGreen'
    }

    if ([String]::IsNullOrWhiteSpace($MatchIdentifier))
    {
        $MatchIdentifier = '>'
    }

    if ($IndentChar -eq $null)
    {
        $IndentChar = ''
    }

    if ($IndentSize -lt 0)
    {
        $IndentSize = 0
    }

    if ([String]::IsNullOrWhiteSpace($LineSeparator))
    {
        $LineSeparator = '...'
    }

    if ($LinesPadding -lt 0)
    {
        $LinesPadding = 0
    }

    if ($LinesBefore -le 0)
    {
        $LinesBefore = $LinesPadding
    }

    if ($LinesAfter -le 0)
    {
        $LinesAfter = $LinesPadding
    }

    $regex = New-Object 'System.Text.RegularExpressions.Regex' -ArgumentList @($regexPattern, $RegexOptions)

    $match = $null

    $script:fileCount = 0
    $script:matchCount = 0

    switch ($PSCmdlet.ParameterSetName)
    {
        'File'
        {
            Write-Host "Searching for '$Pattern' in file: $FilePath"
            Write-Host ''

            Find-RegexInFile -FilePath $FilePath

            # TODO: Not a match
            break
        }
        'Directory'
        {
            Write-Host "Searching for '$Pattern' in directory: $Directory"
            Write-Host ''

            Get-ChildItem -Path $Directory -Filter $Filter -Attributes !Directory -Recurse:(!$NotRecurse.IsPresent) -Exclude $Exclude | % {
                if (-not $_.IsContainer)
                {
                    Find-RegexInFile -FilePath $_.FullName
                }
            }

            # TODO: Not a match
            break
        }
        default
        {
            Write-Host "ParameterSetName not recognized: $($PSCmdlet.ParameterSetName)" -ForegroundColor 'Red'
        }
    }

    Write-Host "Found $matchCount matches in $fileCount files" 
}

function Find-RegexInFile
{
    Param
    (
        [String] $FilePath
    )

    $lines = Get-Content -Path $FilePath

    if (-not $lines)
    {
        return
    }

    $fileMatch = $false
    $matchInfos = @()
    $longestLineNumber = 0

    for ($i = 0; $i -lt $lines.Count; $i++)
    {
        $matchCollection = $regex.Matches($lines[$i])

        # TODO: Multiple matches per line

        if ($matchCollection.Success)
        {
            $matchInfo = @{
                LineIndex = $i
                LineNumber = $i + 1
                Matches = @()
            }

            $matchInfo.LineNumberString = $matchInfo.LineNumber.ToString()

            foreach ($match in $matchCollection)
            {
                $matchInfo.Matches += @{
                    Index = $match.Index
                    Length = $match.Length
                }
            }

            $matchInfos += $matchInfo

            if ($matchInfo.LineNumber -gt $longestLineNumber)
            {
                $longestLineNumber = $matchInfo.LineNumber
            }
        }
    }

    if ($matchInfos.Count -gt 0)
    {
        $script:fileCount += 1
        $script:matchCount += $matchInfos.Count
        Write-Host $FilePath -ForegroundColor $MatchFileColor

        $lastMatch = $null
        $match = $null
        $nextMatch = $matchInfos[0]
        $afterInex = 0
        
        $rightAlignLength = $IndentSize + $longestLineNumber.ToString().Length
        if ($rightAlignLength -lt $MinimumIndent)
        {
            $rightAlignLength = $MinimumIndent
        }

        for ($i = 0; $i -lt $matchInfos.Count; $i++)
        {
            $match = $nextMatch
            $line = $lines[$match.LineIndex]

            # Write out lines before
            $beforeCount = 0
            $beforeIndex = $match.LineIndex - $LinesBefore
            if ($beforeIndex -lt 0)
            {
                $beforeIndex = 0
            }
            while ($beforeCount -lt $LinesBefore -and $beforeIndex -lt $match.LineIndex)
            {
                if ($beforeIndex -ge $afterIndex)
                {
                    Write-Host ($IndentChar * ($rightAlignLength - $beforeIndex.ToString().Length)) -NoNewLine
                    Write-Host ($beforeIndex + 1) -ForegroundColor $NotMatchLineNumberColor -NoNewLine
                    Write-Host "  " -NoNewLine
                    Write-Host $lines[$beforeIndex] -ForegroundColor 'DarkGray'
                }

                $beforeCount++
                $beforeIndex++
            }

            Write-Host ($IndentChar * ($rightAlignLength - $match.LineNumberString.Length)) -NoNewLine
            Write-Host $match.LineNumber -ForegroundColor $MatchLineNumberColor -NoNewLine
            Write-Host "$MatchIdentifier " -NoNewLine
            $matchLineIndex = 0
            for ($mi = 0; $mi -lt $match.Matches.Count; $mi++)
            {
                $matchInstance = $match.Matches[$mi]
                Write-Host $line.SubString($matchLineIndex, $matchInstance.Index - $matchLineIndex) -NoNewLine
                Write-Host $line.SubString($matchInstance.Index, $matchInstance.Length) -ForegroundColor $MatchColor -NoNewLine

                $matchLineIndex = $matchInstance.Index + $matchInstance.Length
                if (($mi + 1) -eq $match.Matches.Count)
                {
                    # Remaining line
                    Write-Host $line.SubString($matchLineIndex)
                }
            }

            # Write out lines after
            $nextMatch = $null
            if (($i + 1) -lt $matchInfos.Count)
            {
                $lastMatch = $match
                $nextMatch = $matchInfos[$i + 1]
            }

            $afterCount = 0
            $afterIndex = $match.LineIndex + 1
            while ($afterCount -lt $LinesAfter -and $afterIndex -lt $lines.Count -and ($nextMatch -eq $null -or $afterIndex -lt $nextMatch.LineIndex))
            {
                Write-Host ($IndentChar * ($rightAlignLength - ($afterIndex + 1).ToString().Length)) -NoNewLine
                Write-Host ($afterIndex + 1) -ForegroundColor $NotMatchLineNumberColor -NoNewLine
                Write-Host "  " -NoNewLine
                Write-Host $lines[$afterIndex] -ForegroundColor 'DarkGray'

                $afterCount++
                $afterIndex++
            }

            if ($nextMatch -and $nextMatch.LineIndex -gt ($afterIndex))
            {
                Write-Host "$($IndentChar * ($rightAlignLength - $LineSeparator.Length))$LineSeparator"
            }
        }
        
        Write-Host ''
    }
}

Set-Alias -Name 'psrep' -Value 'Invoke-PSRep'

Export-ModuleMember -Function 'Invoke-PSRep' -Alias 'psrep'