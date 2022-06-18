<#
.SYNOPSIS
Searches for regular expressions across files and directories.

.PARAMETER Pattern
One or more patterns to search for.

.PARAMETER FilePath
One or more file paths to search. Can be combined with Directory.

.PARAMETER Directory
One or more directory paths to search. Can be combined with FilePath.
If not files or directories are specified, the current working directory will be searched.

.PARAMETER NotRecurse
If a Directory is searched, do not search with recurse. Defaults to Recursive searching.

.PARAMETER Filter
If a Directory is searched, an array of filters to apply.
This is forwarded to -Filter on Get-ChildItem.

.PARAMETER Exclude
If a Directory is searched, an array of globs to exclude.
This is forwarded to -Exclude on Get-ChildItem.
Default: @('*.exe', '*.dll', '*.pdb', '*.jar')

.PARAMETER ExcludeAdditional
If a Directory is searched, adds additional exclusions to Exclude.
If Exclude is not provided, this parameter allows you to use all the defaults
and additional ones, which is useful.

.PARAMETER Literal
Search for the exact pattern, not as a regular expression.

.PARAMETER RegexOptions
A [System.Text.RegularExpressions.RegexOptions] value.

.PARAMETER CaseSensitive
Process with case sensitivity. Defaults to case insensitive.

.PARAMETER OutputType
One or more output types to provide:
* Pretty - Beautiful console output with before and after matching lines for context.
* Simple - One-liner console output per match.
* Object - Return an PSArray of matches.

.LINK
https://github.com/davidknise/psrep
#>
function Invoke-PSRep
{
    Param
    (
        [Parameter(Position=0, Mandatory=$true)]
        [String[]] $Pattern,

        [String[]] $FilePath,

        [String[]] $Directory,

        [Switch] $NotRecurse,

        [String] $Filter,

        [String[]] $Exclude,

        [String[]] $ExcludeAdditional,

        [Switch] $Literal,

        [System.Text.RegularExpressions.RegexOptions] $RegexOptions = [System.Text.RegularExpressions.RegexOptions]::None,

        [Switch] $CaseSensitive,

        [String] $OutputType,

        [String] $MatchFileColor,

        [String] $MatchColor,

        [String] $MatchLineNumberColor,

        [String] $NotMatchLineNumberColor,

        [String] $MatchIdentifier,

        [String] $IndentChar = ' ',

        [Int] $IndentSize = 2,

        [Int] $MinimumIndent = 5,

        [String] $LineSeparator,

        [Int] $LinesPadding = 2,

        [Int] $LinesBefore = 0,

        [Int] $LinesAfter = 0
    )

    if (-not $FilePath -and -not $Directory -or [String]::IsNullOrWhiteSpace($Directory[0]))
    {
        $Directory = @($PWD)
    }

    if (-not $Exclude)
    {
        $Exclude = @('*.exe', '*.dll', '*.pdb', '*.jar')
    }

    $regexPatterns = $Pattern

    if ($Literal.IsPresent)
    {
        $regexPatterns = @()
        $Pattern | ForEach-Object {
            $regexPatterns += [System.Text.RegularExpressions.Regex]::Escape($_)
        }
    }

    if ($RegexOptions -eq [System.Text.RegularExpressions.RegexOptions]::None -and -not $CaseSensitive.IsPresent)
    {
        $RegexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    }

    if ([String]::IsNullOrWhiteSpace($OutputType))
    {
        $OutputType = 'Pretty'
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

    $regexes = @()

    $regexPatterns | ForEach-Object {
        $regexes += New-Object 'System.Text.RegularExpressions.Regex' -ArgumentList @($_, $RegexOptions)
    }

    $script:fileCount = 0
    $script:matchCount = 0

    $matchInfos = @()

    if ($FilePath)
    {
        $FilePath | ForEach-Object {
            Write-Host "Searching for '$Pattern' in file: $_"
            Write-Host ''

            $matchInfosForFile = Find-RegexInFile -FilePath $_
            $matchInfos += $matchInfosForFile
        }
    }

    if ($Directory)
    {
        Write-Host "Searching for '$($Pattern -join ''', ''')' in directory: $Directory"
        Write-Host ''

        $Directory | ForEach-Object {
            Get-ChildItem -Path $Directory -Filter $Filter -Attributes !Directory -Recurse:(!$NotRecurse.IsPresent) -Exclude $Exclude | % {
                if (-not $_.IsContainer)
                {
                    $matchInfosForFile = Find-RegexInFile -FilePath $_.FullName
                    $matchInfos += $matchInfosForFile
                }
            }
        }
    }

    switch ($OutputType)
    {
        { $_ -icontains @('Simple') -or $_ -icontains 'Pretty' }
        {
            Write-Host "Found $matchCount matches in $fileCount files" 
        }
        { $_ -icontains @('Object') }
        {
            Write-Output $matchInfos
        }
    }

    if ($OutputType -iin @('Simple', 'Pretty'))
    {
        Write-Host "Found $matchCount matches in $fileCount files" 
    }
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
        $matchInfo = $null

        $regexes | ForEach-Object {
            $matchCollection = $_.Matches($lines[$i])

            if ($matchCollection.Success)
            {
                if (-not $matchInfo)
                {
                    $matchInfo = @{
                        LineIndex = $i
                        LineNumber = $i + 1
                        Matches = @()
                    }
                    $matchInfo.LineNumberString = $matchInfo.LineNumber.ToString()

                    if ($matchInfo.LineNumber -gt $longestLineNumber)
                    {
                        $longestLineNumber = $matchInfo.LineNumber
                    }
                }

                foreach ($match in $matchCollection)
                {
                    $matchInfo.Matches += @{
                        Index = $match.Index
                        Length = $match.Length
                    }
                }

                $matchInfos += $matchInfo
            }
        }
    }

    if ($OutputType -icontains 'Object')
    {
        Write-Output $matchInfos
    }

    if ($matchInfos.Count -gt 0)
    {
        $script:fileCount += 1
        $script:matchCount += $matchInfos.Count

        if ($OutputType -ieq 'Pretty')
        {
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