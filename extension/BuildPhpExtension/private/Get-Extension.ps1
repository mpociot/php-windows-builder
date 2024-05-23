function Get-Extension {
    <#
    .SYNOPSIS
        Get the PHP extension.
    .PARAMETER ExtensionUrl
        Extension URL
    .PARAMETER ExtensionRef
        Extension Reference
    #>
    [OutputType()]
    param (
        [Parameter(Mandatory = $true, Position=0, HelpMessage='Extension URL')]
        [string] $ExtensionUrl,
        [Parameter(Mandatory = $true, Position=1, HelpMessage='Extension Reference')]
        [string] $ExtensionRef
    )
    begin {
    }
    process {
        if(
            ($null -eq $ExtensionUrl -or $null -eq $ExtensionRef) -or
            ($ExtensionUrl -eq '' -or $ExtensionRef -eq '')
        ) {
            throw "Both Extension URL and Extension Reference are required."
        }
        $currentDirectory = (Get-Location).Path
        if($null -ne $ExtensionUrl -and $null -ne $ExtensionRef) {
            if ($ExtensionUrl -like "*pecl.php.net*") {
                $extension = Split-Path -Path $ExtensionUrl -Leaf
                Invoke-WebRequest -Uri "https://pecl.php.net/get/$extension-$ExtensionRef.tgz" -OutFile "$extension-$ExtensionRef.tgz" -UseBasicParsing
                & tar -xzf "$extension-$ExtensionRef.tgz" -C $currentDirectory
                Copy-Item -Path "$extension-$ExtensionRef\*" -Destination $currentDirectory -Recurse -Force
                Remove-Item -Path "$extension-$ExtensionRef" -Recurse -Force
            } else {
                if($null -ne $env:AUTH_TOKEN) {
                    $ExtensionUrl = $ExtensionUrl -replace '^https://', "https://${Env:AUTH_TOKEN}@"
                }
                git init > $null 2>&1
                git remote add origin $ExtensionUrl
                git fetch --depth=1 origin $ExtensionRef
                git checkout main
            }
        }
        
        dir

        $configW32 = Get-ChildItem (Get-Location).Path -Recurse -Filter "config.w32" -ErrorAction SilentlyContinue
        if($null -eq $configW32) {
            throw "No config.w32 found"
        }
        $subDirectory = $configW32.DirectoryName
        if((Get-Location).Path -ne $subDirectory) {
            Copy-Item -Path "${subDirectory}\*" -Destination $currentDirectory -Recurse -Force
            Remove-Item -Path $subDirectory -Recurse -Force
        }
        $extensionLine = Get-Content -Path "config.w32" | Select-String -Pattern '\s+(ZEND_)?EXTENSION\(' | Select-Object -First 1
        if($null -eq $extensionLine) {
            throw "No extension found in config.w32"
        }
        $name = ($extensionLine -replace '.*EXTENSION\(([^,]+),.*', '$1') -replace '["'']', ''

        # Apply patches only for php/php-windows-builder and shivammathur/php-windows-builder
        if($null -ne $env:GITHUB_REPOSITORY) {
            if($env:GITHUB_REPOSITORY -eq 'php/php-windows-builder' -or $env:GITHUB_REPOSITORY -eq 'shivammathur/php-windows-builder') {
                if(Test-Path -PATH $PSScriptRoot\..\patches\$name.ps1) {
                    . $PSScriptRoot\..\patches\$name.ps1
                }
            }
        }
        return $name
    }
    end {
    }
}
