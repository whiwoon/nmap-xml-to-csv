<#
.SYNOPSIS
    Nmap -oX / -oA XML 파일을 포트 단위 CSV로 변환합니다.

.DESCRIPTION
    한 행은 하나의 IP/Port를 나타냅니다.

    기본 출력 열:
      IP
      Hostname
      MAC
      MACVendor
      Port
      Protocol
      State
      Service
      Product
      Version
      ExtraInfo
      CPE
      OS
      OSAccuracy

    기본적으로 open 상태의 포트만 출력합니다.
    -IncludeAllStates 옵션을 사용하면 closed, filtered,
    open|filtered 등의 상태도 함께 출력합니다.

.EXAMPLE
    .\nmap-xml-to-csv.ps1 .\scan.xml

.EXAMPLE
    .\nmap-xml-to-csv.ps1 .\scan.xml .\scan.csv

.EXAMPLE
    .\nmap-xml-to-csv.ps1 .\scan.xml -IncludeAllStates
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateScript({
        if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
            throw "파일을 찾을 수 없습니다: $_"
        }
        $true
    })]
    [string] $InputPath,

    [Parameter(Position = 1)]
    [string] $OutputPath,

    [switch] $IncludeAllStates
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


# ------------------------------------------------------------
# 입력/출력 경로
# ------------------------------------------------------------

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path

if (-not $OutputPath) {
    $directory = Split-Path -LiteralPath $resolvedInput -Parent
    $baseName  = [System.IO.Path]::GetFileNameWithoutExtension($resolvedInput)
    $OutputPath = Join-Path $directory "$baseName-ports.csv"
}
else {
    $OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
}


# ------------------------------------------------------------
# XML 로드
# ------------------------------------------------------------

$nmap = [System.Xml.XmlDocument]::new()
$nmap.Load($resolvedInput)

if (
    -not $nmap.DocumentElement -or
    $nmap.DocumentElement.Name -ne 'nmaprun'
) {
    throw "Nmap XML의 루트 요소 <nmaprun>을 찾지 못했습니다."
}


# ------------------------------------------------------------
# 결과 저장
# ------------------------------------------------------------

$rows = [System.Collections.Generic.List[object]]::new()


foreach ($host in @($nmap.nmaprun.host)) {

    # --------------------------------------------------------
    # IPv4 주소
    # --------------------------------------------------------

    $ipv4 = @(
        $host.address |
        Where-Object { $_.addrtype -eq 'ipv4' } |
        Select-Object -First 1
    )

    if ($ipv4.Count -gt 0) {
        $ip = [string] $ipv4[0].addr
    }
    else {
        $firstAddress = @($host.address | Select-Object -First 1)

        if ($firstAddress.Count -gt 0) {
            $ip = [string] $firstAddress[0].addr
        }
        else {
            $ip = ''
        }
    }


    # --------------------------------------------------------
    # MAC 주소 / 제조사
    # Nmap이 MAC 정보를 수집하지 못한 경우 빈 값
    # --------------------------------------------------------

    $macNode = @(
        $host.address |
        Where-Object { $_.addrtype -eq 'mac' } |
        Select-Object -First 1
    )

    if ($macNode.Count -gt 0) {
        $mac       = [string] $macNode[0].addr
        $macVendor = [string] $macNode[0].vendor
    }
    else {
        $mac       = ''
        $macVendor = ''
    }


    # --------------------------------------------------------
    # Hostname
    # 여러 hostname이 있으면 ; 로 연결
    # --------------------------------------------------------

    $hostnames = @(
        $host.hostnames.hostname |
        ForEach-Object { [string] $_.name } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    $hostname = $hostnames -join '; '


    # --------------------------------------------------------
    # OS 정보
    # 가장 높은 accuracy의 osmatch 사용
    # --------------------------------------------------------

    $bestOS = @(
        $host.os.osmatch |
        Sort-Object { [int] $_.accuracy } -Descending |
        Select-Object -First 1
    )

    if ($bestOS.Count -gt 0) {
        $osName     = [string] $bestOS[0].name
        $osAccuracy = [string] $bestOS[0].accuracy
    }
    else {
        $osName     = ''
        $osAccuracy = ''
    }


    # --------------------------------------------------------
    # Port
    # --------------------------------------------------------

    foreach ($port in @($host.ports.port)) {

        $state = [string] $port.state.state

        # 기본은 open만 출력
        if (-not $IncludeAllStates -and $state -ne 'open') {
            continue
        }


        # ----------------------------------------------------
        # Service 정보
        # ----------------------------------------------------

        $serviceName = ''
        $product     = ''
        $version     = ''
        $extraInfo   = ''
        $cpe         = ''

        if ($null -ne $port.service) {
            $serviceName = [string] $port.service.name
            $product     = [string] $port.service.product
            $version     = [string] $port.service.version
            $extraInfo   = [string] $port.service.extrainfo

            $cpeValues = @(
                $port.service.cpe |
                ForEach-Object { [string] $_.'#text' } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )

            $cpe = $cpeValues -join '; '
        }


        # ----------------------------------------------------
        # CSV 한 행
        # ----------------------------------------------------

        $row = [PSCustomObject][ordered]@{
            IP         = $ip
            Hostname   = $hostname
            MAC        = $mac
            MACVendor  = $macVendor
            Port       = [string] $port.portid
            Protocol   = [string] $port.protocol
            State      = $state
            Service    = $serviceName
            Product    = $product
            Version    = $version
            ExtraInfo  = $extraInfo
            CPE        = $cpe
            OS         = $osName
            OSAccuracy = $osAccuracy
        }

        $rows.Add($row)
    }
}


# ------------------------------------------------------------
# 결과 확인
# ------------------------------------------------------------

if ($rows.Count -eq 0) {
    if ($IncludeAllStates) {
        throw "포트 결과를 찾지 못했습니다."
    }
    else {
        throw "open 상태의 포트를 찾지 못했습니다. 모든 상태를 출력하려면 -IncludeAllStates 옵션을 사용하세요."
    }
}


# ------------------------------------------------------------
# CSV 저장
# Windows PowerShell 5.1 / PowerShell 7 호환
# ------------------------------------------------------------

if ($PSVersionTable.PSVersion.Major -ge 6) {
    $rows |
        Export-Csv `
            -LiteralPath $OutputPath `
            -NoTypeInformation `
            -Encoding utf8BOM
}
else {
    # Windows PowerShell 5.1의 UTF8은 BOM 포함
    $rows |
        Export-Csv `
            -LiteralPath $OutputPath `
            -NoTypeInformation `
            -Encoding UTF8
}


Write-Host ""
Write-Host "완료: $OutputPath"
Write-Host "포트 행: $($rows.Count)"
