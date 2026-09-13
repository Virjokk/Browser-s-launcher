#requires -Version 5.1

Set-StrictMode -Version 2

# ================================================================
# Add-DllImport
#
# PowerShell 5.1
#
# Назначение:
#   Добавление DLL в Import Table PE32/PE32+ EXE/DLL.
#
# Аналог:
#   setdll.exe /d:version.dll opera.exe
#
# По умолчанию используется IMPORT BY ORDINAL #1,
# как в Microsoft Detours setdll.
#
# Поддерживается:
#   PE32       / x86
#   PE32+      / x64
#
# Возможности:
#   - расширение PE headers;
#   - перенос таблицы секций;
#   - перенос raw data существующих секций;
#   - добавление нового .pimport section;
#   - добавление DLL в Import Directory;
#   - Certificate Table;
#   - перемещение Certificate Table;
#   - сохранение исходных certificate bytes;
#   - Authenticode hash до/после;
#   - PE checksum;
#   - автоматическая повторная проверка результата.
#
# ВАЖНО:
#   После изменения PE Authenticode-подпись становится
#   недействительной. Certificate Table при этом может быть
#   полностью сохранена физически.
# ================================================================


# ================================================================
# BASIC BINARY FUNCTIONS
# ================================================================

function Read-U16 {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    if ($Offset -lt 0 -or
        $Offset + 2 -gt $Bytes.Length) {
        throw "Read-U16: offset outside buffer: $Offset"
    }

    return [BitConverter]::ToUInt16($Bytes, $Offset)
}


function Read-U32 {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    if ($Offset -lt 0 -or
        $Offset + 4 -gt $Bytes.Length) {
        throw "Read-U32: offset outside buffer: $Offset"
    }

    return [BitConverter]::ToUInt32($Bytes, $Offset)
}


function Read-U64 {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    if ($Offset -lt 0 -or
        $Offset + 8 -gt $Bytes.Length) {
        throw "Read-U64: offset outside buffer: $Offset"
    }

    return [BitConverter]::ToUInt64($Bytes, $Offset)
}


function Write-U16 {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [UInt16]$Value
    )

    if ($Offset -lt 0 -or
        $Offset + 2 -gt $Bytes.Length) {
        throw "Write-U16: offset outside buffer: $Offset"
    }

    $x = [BitConverter]::GetBytes($Value)

    [Array]::Copy(
        $x,
        0,
        $Bytes,
        $Offset,
        2
    )
}


function Write-U32 {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [UInt32]$Value
    )

    if ($Offset -lt 0 -or
        $Offset + 4 -gt $Bytes.Length) {
        throw "Write-U32: offset outside buffer: $Offset"
    }

    $x = [BitConverter]::GetBytes($Value)

    [Array]::Copy(
        $x,
        0,
        $Bytes,
        $Offset,
        4
    )
}


function Write-U64 {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [UInt64]$Value
    )

    if ($Offset -lt 0 -or
        $Offset + 8 -gt $Bytes.Length) {
        throw "Write-U64: offset outside buffer: $Offset"
    }

    $x = [BitConverter]::GetBytes($Value)

    [Array]::Copy(
        $x,
        0,
        $Bytes,
        $Offset,
        8
    )
}


function Align-Up {
    param(
        [UInt64]$Value,
        [UInt32]$Alignment
    )

    if ($Alignment -eq 0) {
        throw "Alignment cannot be zero."
    }

    return [UInt64](
        (($Value + $Alignment - 1) / $Alignment) * $Alignment
    )
}


function Get-AsciiZ {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [int]$Maximum = 4096
    )

    if ($Offset -lt 0 -or
        $Offset -ge $Bytes.Length) {
        throw "Get-AsciiZ: invalid offset $Offset"
    }

    $list = New-Object System.Collections.Generic.List[char]

    for ($i = 0; $i -lt $Maximum; $i++) {

        $p = $Offset + $i

        if ($p -ge $Bytes.Length) {
            throw "Unterminated ASCII string."
        }

        $c = $Bytes[$p]

        if ($c -eq 0) {
            break
        }

        $list.Add([char]$c)
    }

    return (-join $list)
}


# ================================================================
# PE PARSER
# ================================================================

function Get-PEInfo {
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Bytes
    )

    if ($Bytes.Length -lt 0x100) {
        throw "File is too small to be a PE image."
    }

    # DOS MZ
    if ((Read-U16 $Bytes 0) -ne 0x5A4D) {
        throw "Invalid DOS signature."
    }

    $e_lfanew = [UInt32](Read-U32 $Bytes 0x3C)

    if ($e_lfanew + 4 -gt $Bytes.Length) {
        throw "Invalid e_lfanew."
    }

    # PE\0\0
    if ((Read-U32 $Bytes ([int]$e_lfanew)) -ne 0x00004550) {
        throw "Invalid PE signature."
    }

    $peOffset = [int]$e_lfanew

    # ------------------------------------------------------------
    # IMAGE_FILE_HEADER
    # ------------------------------------------------------------

    $fileHeader = $peOffset + 4

    $machine =
        Read-U16 $Bytes $fileHeader

    $numberOfSections =
        Read-U16 $Bytes ($fileHeader + 2)

    $sizeOfOptionalHeader =
        Read-U16 $Bytes ($fileHeader + 16)

    $optionalHeader =
        $fileHeader + 20

    if (
        $optionalHeader +
        $sizeOfOptionalHeader >
        $Bytes.Length
    ) {
        throw "Optional header exceeds file."
    }

    # ------------------------------------------------------------
    # PE32 / PE32+
    # ------------------------------------------------------------

    $magic =
        Read-U16 $Bytes $optionalHeader

    switch ($magic) {

        0x10B {

            $isPE32 = $true
            $isPE32Plus = $false

            $pointerSize = 4

            $imageBase =
                Read-U32 $Bytes ($optionalHeader + 28)

            $sectionAlignment =
                Read-U32 $Bytes ($optionalHeader + 32)

            $fileAlignment =
                Read-U32 $Bytes ($optionalHeader + 36)

            $sizeOfImageOffset =
                $optionalHeader + 56

            $sizeOfHeadersOffset =
                $optionalHeader + 60

            $checkSumOffset =
                $optionalHeader + 64

            $numberOfRvaAndSizesOffset =
                $optionalHeader + 92

            $dataDirectoryOffset =
                $optionalHeader + 96
        }

        0x20B {

            $isPE32 = $false
            $isPE32Plus = $true

            $pointerSize = 8

            $imageBase =
                Read-U64 $Bytes ($optionalHeader + 24)

            $sectionAlignment =
                Read-U32 $Bytes ($optionalHeader + 32)

            $fileAlignment =
                Read-U32 $Bytes ($optionalHeader + 36)

            $sizeOfImageOffset =
                $optionalHeader + 56

            $sizeOfHeadersOffset =
                $optionalHeader + 60

            $checkSumOffset =
                $optionalHeader + 64

            $numberOfRvaAndSizesOffset =
                $optionalHeader + 108

            $dataDirectoryOffset =
                $optionalHeader + 112
        }

        default {
            throw (
                "Unsupported OptionalHeader.Magic: 0x{0:X4}" -f $magic
            )
        }
    }

    if ($sectionAlignment -eq 0) {
        throw "Invalid SectionAlignment."
    }

    if ($fileAlignment -eq 0) {
        throw "Invalid FileAlignment."
    }

    if (
        $fileAlignment -lt 0x200 -and
        $fileAlignment -ne 1
    ) {
        throw "Suspicious FileAlignment: $fileAlignment"
    }

    $sizeOfImage =
        Read-U32 $Bytes $sizeOfImageOffset

    $sizeOfHeaders =
        Read-U32 $Bytes $sizeOfHeadersOffset

    $numberOfRvaAndSizes =
        Read-U32 $Bytes $numberOfRvaAndSizesOffset

    if ($numberOfRvaAndSizes -lt 5) {
        throw "PE has fewer than five data directories."
    }

    # ------------------------------------------------------------
    # Data directories
    #
    # 1 = IMPORT
    # 4 = SECURITY
    # ------------------------------------------------------------

    $importDirectoryOffset =
        $dataDirectoryOffset + (1 * 8)

    $securityDirectoryOffset =
        $dataDirectoryOffset + (4 * 8)

    $importRva =
        Read-U32 $Bytes $importDirectoryOffset

    $importSize =
        Read-U32 $Bytes ($importDirectoryOffset + 4)

    $certificateFileOffset =
        Read-U32 $Bytes $securityDirectoryOffset

    $certificateSize =
        Read-U32 $Bytes ($securityDirectoryOffset + 4)

    # ------------------------------------------------------------
    # Section table
    # ------------------------------------------------------------

    $sectionTable =
        $optionalHeader + $sizeOfOptionalHeader

    $sections = @()

    for ($i = 0; $i -lt $numberOfSections; $i++) {

        $offset =
            $sectionTable + ($i * 40)

        if ($offset + 40 -gt $Bytes.Length) {
            throw "Section header exceeds file."
        }

        $nameBytes =
            New-Object byte[] 8

        [Array]::Copy(
            $Bytes,
            $offset,
            $nameBytes,
            0,
            8
        )

        $nameEnd =
            [Array]::IndexOf(
                $nameBytes,
                [byte]0
            )

        if ($nameEnd -lt 0) {
            $nameEnd = 8
        }

        $name =
            [Text.Encoding]::ASCII.GetString(
                $nameBytes,
                0,
                $nameEnd
            )

        $virtualSize =
            Read-U32 $Bytes ($offset + 8)

        $virtualAddress =
            Read-U32 $Bytes ($offset + 12)

        $sizeOfRawData =
            Read-U32 $Bytes ($offset + 16)

        $pointerToRawData =
            Read-U32 $Bytes ($offset + 20)

        $pointerToRelocations =
            Read-U32 $Bytes ($offset + 24)

        $pointerToLinenumbers =
            Read-U32 $Bytes ($offset + 28)

        $numberOfRelocations =
            Read-U16 $Bytes ($offset + 32)

        $numberOfLinenumbers =
            Read-U16 $Bytes ($offset + 34)

        $characteristics =
            Read-U32 $Bytes ($offset + 36)

        if (
            $sizeOfRawData -gt 0 -and
            [UInt64]$pointerToRawData +
            [UInt64]$sizeOfRawData >
            [UInt64]$Bytes.Length
        ) {
            throw (
                "Section '{0}' raw data exceeds file." -f $name
            )
        }

        $sections += [PSCustomObject]@{
            Index                = $i
            HeaderOffset         = $offset
            Name                 = $name

            VirtualSize         = $virtualSize
            VirtualAddress      = $virtualAddress

            SizeOfRawData       = $sizeOfRawData
            PointerToRawData    = $pointerToRawData

            PointerToRelocations= $pointerToRelocations
            PointerToLinenumbers= $pointerToLinenumbers

            NumberOfRelocations = $numberOfRelocations
            NumberOfLinenumbers = $numberOfLinenumbers

            Characteristics     = $characteristics
        }
    }

    [PSCustomObject]@{

        IsPE32       = $isPE32
        IsPE32Plus   = $isPE32Plus

        Machine      = $machine
        Magic        = $magic

        PointerSize  = $pointerSize

        PEOffset     = $peOffset

        FileHeaderOffset =
            $fileHeader

        OptionalHeaderOffset =
            $optionalHeader

        SizeOfOptionalHeader =
            $sizeOfOptionalHeader

        SectionTableOffset =
            $sectionTable

        NumberOfSections =
            $numberOfSections

        SectionAlignment =
            $sectionAlignment

        FileAlignment =
            $fileAlignment

        ImageBase =
            $imageBase

        SizeOfImage =
            $sizeOfImage

        SizeOfImageOffset =
            $sizeOfImageOffset

        SizeOfHeaders =
            $sizeOfHeaders

        SizeOfHeadersOffset =
            $sizeOfHeadersOffset

        CheckSumOffset =
            $checkSumOffset

        DataDirectoryOffset =
            $dataDirectoryOffset

        ImportDirectoryOffset =
            $importDirectoryOffset

        ImportRva =
            $importRva

        ImportSize =
            $importSize

        SecurityDirectoryOffset =
            $securityDirectoryOffset

        CertificateOffset =
            $certificateFileOffset

        CertificateSize =
            $certificateSize

        Sections =
            $sections
    }
}


# ================================================================
# RVA <-> FILE OFFSET
# ================================================================

function Convert-RvaToFileOffset {
    param(
        $PE,

        [UInt32]$Rva
    )

    foreach ($section in $PE.Sections) {

        $start =
            [UInt64]$section.VirtualAddress

        $span =
            [Math]::Max(
                [UInt64]$section.VirtualSize,
                [UInt64]$section.SizeOfRawData
            )

        if (
            [UInt64]$Rva -ge $start -and
            [UInt64]$Rva -lt ($start + $span)
        ) {

            return (
                [UInt64]$section.PointerToRawData +
                ([UInt64]$Rva - $start)
            )
        }
    }

    # PE headers themselves are RVA-addressable.
    if (
        [UInt64]$Rva -lt
        [UInt64]$PE.SizeOfHeaders
    ) {
        return [UInt64]$Rva
    }

    return $null
}


function Convert-FileOffsetToRva {
    param(
        $PE,

        [UInt64]$Offset
    )

    if (
        $Offset -lt
        [UInt64]$PE.SizeOfHeaders
    ) {
        return [UInt32]$Offset
    }

    foreach ($section in $PE.Sections) {

        $start =
            [UInt64]$section.PointerToRawData

        $end =
            $start +
            [UInt64]$section.SizeOfRawData

        if (
            $Offset -ge $start -and
            $Offset -lt $end
        ) {

            return [UInt32](
                [UInt64]$section.VirtualAddress +
                ($Offset - $start)
            )
        }
    }

    return $null
}


function Get-SectionForRva {
    param(
        $PE,

        [UInt32]$Rva
    )

    foreach ($section in $PE.Sections) {

        $start =
            [UInt64]$section.VirtualAddress

        $span =
            [Math]::Max(
                [UInt64]$section.VirtualSize,
                [UInt64]$section.SizeOfRawData
            )

        if (
            [UInt64]$Rva -ge $start -and
            [UInt64]$Rva -lt ($start + $span)
        ) {
            return $section
        }
    }

    return $null
}


# ================================================================
# IMPORT TABLE
# ================================================================

function Get-PEImports {
    param(
        [byte[]]$Bytes,

        $PE
    )

    $imports = @()

    if ($PE.ImportRva -eq 0) {
        return @()
    }

    $directoryOffset =
        Convert-RvaToFileOffset `
            -PE $PE `
            -Rva $PE.ImportRva

    if ($null -eq $directoryOffset) {
        throw "Import Directory RVA is invalid."
    }

    $offset = [int]$directoryOffset

    for ($i = 0; $i -lt 65536; $i++) {

        if ($offset + 20 -gt $Bytes.Length) {
            throw "Import descriptor exceeds file."
        }

        $originalFirstThunk =
            Read-U32 $Bytes $offset

        $timeDateStamp =
            Read-U32 $Bytes ($offset + 4)

        $forwarderChain =
            Read-U32 $Bytes ($offset + 8)

        $nameRva =
            Read-U32 $Bytes ($offset + 12)

        $firstThunk =
            Read-U32 $Bytes ($offset + 16)

        if (
            $originalFirstThunk -eq 0 -and
            $timeDateStamp -eq 0 -and
            $forwarderChain -eq 0 -and
            $nameRva -eq 0 -and
            $firstThunk -eq 0
        ) {
            break
        }

        $nameOffset =
            Convert-RvaToFileOffset `
                -PE $PE `
                -Rva $nameRva

        if ($null -eq $nameOffset) {
            throw "Invalid DLL name RVA."
        }

        $dllName =
            Get-AsciiZ `
                -Bytes $Bytes `
                -Offset ([int]$nameOffset)

        $imports += [PSCustomObject]@{
            Name               = $dllName

            OriginalFirstThunk = $originalFirstThunk
            NameRva            = $nameRva
            FirstThunk         = $firstThunk

            DescriptorOffset   = $offset
        }

        $offset += 20
    }

    return $imports
}


# ================================================================
# PE CHECKSUM
# ================================================================

function Get-PEChecksum {
    param(
        [byte[]]$Bytes,

        [int]$ChecksumOffset
    )

    [UInt64]$sum = 0

    for (
        $i = 0;
        $i -lt $Bytes.Length;
        $i += 2
    ) {

        if ($i -eq $ChecksumOffset) {

            $word = 0
        }
        elseif (
            $i + 1 -lt
            $Bytes.Length
        ) {

            $word =
                [UInt32](
                    $Bytes[$i] -bor
                    ($Bytes[$i + 1] -shl 8)
                )
        }
        else {

            $word =
                [UInt32]$Bytes[$i]
        }

        $sum += $word

        $sum =
            ($sum -band 0xFFFFFFFF) +
            ($sum -shr 32)
    }

    while (($sum -shr 16) -ne 0) {

        $sum =
            ($sum -band 0xFFFF) +
            ($sum -shr 16)
    }

    $sum += [UInt64]$Bytes.Length

    return [UInt32]$sum
}


function Set-PEChecksum {
    param(
        [byte[]]$Bytes,

        $PE
    )

    Write-U32 `
        $Bytes `
        $PE.CheckSumOffset `
        0

    $checksum =
        Get-PEChecksum `
            -Bytes $Bytes `
            -ChecksumOffset $PE.CheckSumOffset

    Write-U32 `
        $Bytes `
        $PE.CheckSumOffset `
        $checksum

    return $checksum
}


# ================================================================
# CERTIFICATE TABLE
#
# Security directory is special:
#
# VirtualAddress field = FILE OFFSET
#
# NOT RVA.
# ================================================================

function Get-CertificateData {
    param(
        [byte[]]$Bytes,

        $PE
    )

    if (
        $PE.CertificateOffset -eq 0 -or
        $PE.CertificateSize -eq 0
    ) {
        return [PSCustomObject]@{
            Present = $false
            Offset = 0
            Size = 0
            Bytes = $null
            Hash = $null
        }
    }

    $offset =
        [UInt64]$PE.CertificateOffset

    $size =
        [UInt64]$PE.CertificateSize

    if (
        $offset + $size >
        [UInt64]$Bytes.Length
    ) {
        throw "Certificate Table extends outside file."
    }

    $data =
        New-Object byte[] ([int]$size)

    [Array]::Copy(
        $Bytes,
        [int]$offset,
        $data,
        0,
        [int]$size
    )

    $sha =
        [Security.Cryptography.SHA256]::Create()

    try {

        $digest =
            $sha.ComputeHash($data)

        $hex =
            (
                $digest |
                ForEach-Object {
                    $_.ToString('x2')
                }
            ) -join ''

    }
    finally {

        $sha.Dispose()
    }

    [PSCustomObject]@{
        Present = $true
        Offset  = $offset
        Size    = $size
        Bytes   = $data
        Hash    = $hex
    }
}


# ================================================================
# AUTHENTICODE HASH
#
# Hashing rules:
#
#   1. Everything before CheckSum
#   2. Skip CheckSum (4 bytes)
#   3. Hash everything after CheckSum up to Security Directory
#   4. Skip Security Directory entry itself (8 bytes)
#   5. Hash everything after Security Directory entry
#      up to Certificate Table
#   6. Skip Certificate Table
#   7. Hash remaining bytes after Certificate Table
#
# This implementation works with SHA-256.
# ================================================================

function Get-AuthenticodeHash {
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$Bytes,

        [Parameter(Mandatory=$true)]
        $PE
    )

    $sha =
        [Security.Cryptography.SHA256]::Create()

    try {

        $certOffset =
            [UInt64]$PE.CertificateOffset

        $certSize =
            [UInt64]$PE.CertificateSize

        if (
            $certOffset -eq 0 -or
            $certSize -eq 0
        ) {

            $certOffset =
                [UInt64]$Bytes.Length

            $certSize = 0
        }

        if (
            $certOffset +
            $certSize >
            [UInt64]$Bytes.Length
        ) {
            throw "Invalid Certificate Table range."
        }

        # --------------------------------------------------------
        # Part 1
        # Before CheckSum
        # --------------------------------------------------------

        if ($PE.CheckSumOffset -gt 0) {

            $partLength =
                $PE.CheckSumOffset

            if ($partLength -gt 0) {

                $sha.TransformBlock(
                    $Bytes,
                    0,
                    $partLength,
                    $Bytes,
                    0
                ) | Out-Null
            }
        }

        # --------------------------------------------------------
        # Part 2
        # Between CheckSum and Security Directory
        #
        # CheckSum itself excluded.
        # --------------------------------------------------------

        $afterChecksum =
            $PE.CheckSumOffset + 4

        $securityDirectory =
            $PE.SecurityDirectoryOffset

        if (
            $securityDirectory -gt
            $afterChecksum
        ) {

            $length =
                $securityDirectory -
                $afterChecksum

            $sha.TransformBlock(
                $Bytes,
                $afterChecksum,
                $length,
                $Bytes,
                $afterChecksum
            ) | Out-Null
        }

        # --------------------------------------------------------
        # Part 3
        #
        # Skip the 8-byte SECURITY data directory.
        # Hash from its end to Certificate Table.
        # --------------------------------------------------------

        $afterSecurityDirectory =
            $PE.SecurityDirectoryOffset + 8

        if (
            $certOffset -gt
            [UInt64]$afterSecurityDirectory
        ) {

            $length =
                [int](
                    $certOffset -
                    [UInt64]$afterSecurityDirectory
                )

            if ($length -gt 0) {

                $sha.TransformBlock(
                    $Bytes,
                    $afterSecurityDirectory,
                    $length,
                    $Bytes,
                    $afterSecurityDirectory
                ) | Out-Null
            }
        }

        # --------------------------------------------------------
        # Part 4
        #
        # Skip Certificate Table.
        # Hash anything after it.
        # --------------------------------------------------------

        $afterCertificate =
            [UInt64]$certOffset +
            [UInt64]$certSize

        if (
            $afterCertificate -
            [UInt64]$Bytes.Length -lt 0
        ) {
            throw "Certificate range invalid."
        }

        if (
            $afterCertificate -
            [UInt64]$Bytes.Length -lt 0
        ) {
            throw "Invalid file."
        }

        $remaining =
            [UInt64]$Bytes.Length -
            $afterCertificate

        if ($remaining -gt 0) {

            $remainingInt =
                [int]$remaining

            $afterCertificateInt =
                [int]$afterCertificate

            $sha.TransformFinalBlock(
                $Bytes,
                $afterCertificateInt,
                $remainingInt
            ) | Out-Null
        }
        else {

            $sha.TransformFinalBlock(
                [byte[]]@(),
                0,
                0
            ) | Out-Null
        }

        $digest =
            $sha.Hash

        return (
            (
                $digest |
                ForEach-Object {
                    $_.ToString('x2')
                }
            ) -join ''
        )
    }
    finally {

        $sha.Dispose()
    }
}


# ================================================================
# TEST CERTIFICATE TABLE
# ================================================================

function Test-CertificateTable {
    param(
        [byte[]]$Bytes,

        $PE
    )

    $cert =
        Get-CertificateData `
            -Bytes $Bytes `
            -PE $PE

    if (-not $cert.Present) {

        return [PSCustomObject]@{
            Present = $false
            Valid = $true
            Offset = 0
            Size = 0
            Hash = $null
        }
    }

    $valid =
        (
            [UInt64]$cert.Offset +
            [UInt64]$cert.Size
        ) -le
        [UInt64]$Bytes.Length

    [PSCustomObject]@{
        Present = $true
        Valid   = $valid
        Offset  = $cert.Offset
        Size    = $cert.Size
        Hash    = $cert.Hash
    }
}


# ================================================================
# COMPLETE PE STRUCTURE TEST
# ================================================================

function Test-PEImage {
    param(
        [byte[]]$Bytes
    )

    try {

        $pe =
            Get-PEInfo -Bytes $Bytes

        # --------------------------------------------------------
        # Sections
        # --------------------------------------------------------

        foreach ($section in $pe.Sections) {

            if (
                $section.SizeOfRawData -gt 0
            ) {

                if (
                    [UInt64]$section.PointerToRawData +
                    [UInt64]$section.SizeOfRawData >
                    [UInt64]$Bytes.Length
                ) {
                    throw (
                        "Section '{0}' exceeds file." -
                        $section.Name
                    )
                }
            }
        }

        # --------------------------------------------------------
        # Import table
        # --------------------------------------------------------

        $imports =
            @(Get-PEImports `
                -Bytes $Bytes `
                -PE $pe)

        # --------------------------------------------------------
        # Certificate
        # --------------------------------------------------------

        $cert =
            Test-CertificateTable `
                -Bytes $Bytes `
                -PE $pe

        if (-not $cert.Valid) {
            throw "Invalid Certificate Table."
        }

        # --------------------------------------------------------
        # Checksum
        # --------------------------------------------------------

        $stored =
            Read-U32 `
                $Bytes `
                $pe.CheckSumOffset

        $calculated =
            Get-PEChecksum `
                -Bytes $Bytes `
                -ChecksumOffset $pe.CheckSumOffset

        [PSCustomObject]@{
            Valid = $true

            PE32 =
                $pe.IsPE32

            PE32Plus =
                $pe.IsPE32Plus

            Machine =
                ('0x{0:X4}' -f $pe.Machine)

            Sections =
                $pe.NumberOfSections

            Imports =
                $imports

            Certificate =
                $cert

            StoredChecksum =
                ('0x{0:X8}' -f $stored)

            CalculatedChecksum =
                ('0x{0:X8}' -f $calculated)

            ChecksumValid =
                ($stored -eq $calculated)
        }
    }
    catch {

        [PSCustomObject]@{
            Valid = $false
            Error = $_.Exception.Message
        }
    }
}


# ================================================================
# MAIN
# ================================================================

function Add-DllImport {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(

        [Parameter(
            Mandatory=$true,
            Position=0
        )]
        [string]$Path,

        [Parameter(
            Mandatory=$true,
            Position=1
        )]
        [string]$DllName,

        [string]$OutputPath,

        # Аналог setdll:
        # DLL должна экспортировать ordinal #1.
        [UInt16]$Ordinal = 1,

        [switch]$Backup,

        [switch]$VerifyAuthenticodeHash
    )

    # ============================================================
    # INPUT
    # ============================================================

    if (-not [IO.File]::Exists($Path)) {
        throw "File not found: $Path"
    }

    $fullPath =
        [IO.Path]::GetFullPath($Path)

    if ([string]::IsNullOrWhiteSpace($DllName)) {
        throw "DllName is empty."
    }

    foreach ($c in $DllName.ToCharArray()) {

        if ([int][char]$c -gt 127) {
            throw "DLL name must contain ASCII characters only."
        }
    }

    if ($DllName.IndexOf([char]0) -ge 0) {
        throw "DLL name contains NUL."
    }

    if ($DllName.Length -gt 240) {
        throw "DLL name is too long."
    }

    if (-not $OutputPath) {
        $OutputPath = $fullPath
    }
    else {
        $OutputPath =
            [IO.Path]::GetFullPath($OutputPath)
    }

    # ============================================================
    # READ
    # ============================================================

    $original =
        [IO.File]::ReadAllBytes($fullPath)

    $pe =
        Get-PEInfo -Bytes $original

    if ($pe.IsPE32Plus) {
        $architecture = 'x64'
        $format = 'PE32+'
    }
    else {
        $architecture = 'x86'
        $format = 'PE32'
    }

    Write-Verbose "PE format: $format"
    Write-Verbose "Architecture: $architecture"
    Write-Verbose (
        "Sections: {0}" -f
        $pe.NumberOfSections
    )

    # ============================================================
    # ORIGINAL IMPORTS
    # ============================================================

    $importsBefore =
        @(Get-PEImports `
            -Bytes $original `
            -PE $pe)

    $existing =
        $importsBefore |
        Where-Object {
            $_.Name -ieq $DllName
        }

    if ($existing) {

        Write-Verbose (
            "DLL already imported: {0}" -f $DllName
        )

        if ($OutputPath -ne $fullPath) {

            [IO.File]::WriteAllBytes(
                $OutputPath,
                $original
            )
        }

        return [PSCustomObject]@{
            Success =
                $true

            Changed =
                $false

            AlreadyPresent =
                $true

            Path =
                $OutputPath

            DllName =
                $DllName

            Architecture =
                $architecture

            PEFormat =
                $format

            ImportVerified =
                $true
        }
    }

    # ============================================================
    # CERTIFICATE BEFORE
    # ============================================================

    $certificateBefore =
        Test-CertificateTable `
            -Bytes $original `
            -PE $pe

    if (-not $certificateBefore.Valid) {
        throw "Original Certificate Table is invalid."
    }

    # ============================================================
    # AUTHENTICODE HASH BEFORE
    # ============================================================

    $authHashBefore =
        Get-AuthenticodeHash `
            -Bytes $original `
            -PE $pe

    Write-Verbose (
        "Authenticode SHA256 before: {0}" -
        $authHashBefore
    )

    # ============================================================
    # FIND FIRST RAW SECTION
    # ============================================================

    $rawSections =
        @(
            $pe.Sections |
            Where-Object {
                $_.SizeOfRawData -gt 0
            } |
            Sort-Object {
                [UInt64]$_.PointerToRawData
            }
        )

    if ($rawSections.Count -eq 0) {
        throw "PE contains no raw sections."
    }

    $firstRawOffset =
        [UInt64]$rawSections[0].PointerToRawData

    # ============================================================
    # NEW SECTION HEADER LOCATION
    # ============================================================

    $oldSectionTableEnd =
        [UInt64]$pe.SectionTableOffset +
        ([UInt64]$pe.NumberOfSections * 40)

    $newSectionTableEnd =
        $oldSectionTableEnd + 40

    # ============================================================
    # DETERMINE HEADER SIZE
    #
    # If there is enough room inside SizeOfHeaders:
    #
    #   headerDelta = 0
    #
    # Otherwise:
    #
    #   enlarge headers
    #   shift ALL raw sections.
    # ============================================================

    $newSizeOfHeaders =
        [UInt64]$pe.SizeOfHeaders

    if (
        $newSectionTableEnd >
        $newSizeOfHeaders
    ) {

        $newSizeOfHeaders =
            Align-Up `
                $newSectionTableEnd `
                $pe.FileAlignment
    }

    $headerDelta =
        [Int64](
            $newSizeOfHeaders -
            [UInt64]$pe.SizeOfHeaders
        )

    Write-Verbose (
        "Old SizeOfHeaders: 0x{0:X}" -
        $pe.SizeOfHeaders
    )

    Write-Verbose (
        "New SizeOfHeaders: 0x{0:X}" -
        $newSizeOfHeaders
    )

    Write-Verbose (
        "Header delta: 0x{0:X}" -
        $headerDelta
    )

    # ============================================================
    # IMPORTANT:
    #
    # We require that the first raw section begins exactly at
    # or after SizeOfHeaders.
    #
    # Normal PE files satisfy:
    #
    #   PointerToRawData >= SizeOfHeaders
    # ============================================================

    if (
        $firstRawOffset <
        [UInt64]$pe.SizeOfHeaders
    ) {
        throw (
            "Invalid PE: first raw section starts before " +
            "SizeOfHeaders."
        )
    }

    # ============================================================
    # BUILD NEW SECTION INFORMATION
    # ============================================================

    $newSectionName =
        '.pimport'

    $newSectionNameBytes =
        [Text.Encoding]::ASCII.GetBytes(
            $newSectionName
        )

    # ============================================================
    # NEW SECTION PAYLOAD
    #
    # IMAGE_IMPORT_DESCRIPTOR
    # IMAGE_IMPORT_DESCRIPTOR terminator
    #
    # ILT
    # IAT
    #
    # Since this is setdll-compatible mode:
    #
    #   thunk = IMAGE_ORDINAL_FLAG | Ordinal
    #
    # For PE32:
    #   0x80000000 | ordinal
    #
    # For PE32+:
    #   0x8000000000000000 | ordinal
    #
    # DLL name follows.
    # ============================================================

    $descriptorSize =
        20

    $thunkEntrySize =
        $pe.PointerSize

    # ILT:
    #   ordinal
    #   zero
    $iltSize =
        $thunkEntrySize * 2

    # IAT:
    #   ordinal
    #   zero
    $iatSize =
        $thunkEntrySize * 2

    $dllNameBytes =
        [Text.Encoding]::ASCII.GetBytes(
            $DllName
        )

    $cursor = 0

    $descriptorOffset =
        $cursor

    $cursor += 20

    $terminatorOffset =
        $cursor

    $cursor += 20

    $cursor =
        [UInt32](
            Align-Up $cursor 8
        )

    $iltOffset =
        $cursor

    $cursor += $iltSize

    $cursor =
        [UInt32](
            Align-Up $cursor 8
        )

    $iatOffset =
        $cursor

    $cursor += $iatSize

    $cursor =
        [UInt32](
            Align-Up $cursor 2
        )

    $dllNameOffset =
        $cursor

    $cursor +=
        $dllNameBytes.Length + 1

    $payloadSize =
        [UInt32]$cursor

    # ============================================================
    # NEW SECTION RVA
    # ============================================================

    $sectionEndRva = 0

    foreach ($section in $pe.Sections) {

        $end =
            [UInt64]$section.VirtualAddress +
            [UInt64]$section.VirtualSize

        if (
            [UInt64]$section.SizeOfRawData >
            [UInt64]$section.VirtualSize
        ) {

            $end =
                [UInt64]$section.VirtualAddress +
                [UInt64]$section.SizeOfRawData
        }

        if ($end -gt $sectionEndRva) {
            $sectionEndRva = $end
        }
    }

    $newSectionRva =
        Align-Up `
            $sectionEndRva `
            $pe.SectionAlignment

    $newSectionVirtualSize =
        [UInt32]$payloadSize

    $newSectionRawSize =
        [UInt32](
            Align-Up `
                $payloadSize `
                $pe.FileAlignment
        )

    # ============================================================
    # DETERMINE NEW RAW POSITIONS
    # ============================================================

    $sectionPositions = @()

    foreach ($section in $pe.Sections) {

        if ($section.SizeOfRawData -eq 0) {

            $newRaw =
                [UInt32]$section.PointerToRawData
        }
        else {

            $newRaw =
                [UInt32](
                    [UInt64]$section.PointerToRawData +
                    [UInt64]$headerDelta
                )
        }

        $sectionPositions += [PSCustomObject]@{
            Original = $section
            NewRaw   = $newRaw
        }
    }

    # ============================================================
    # FIND END OF SHIFTED SECTION DATA
    # ============================================================

    $lastRawEnd =
        [UInt64]$newSizeOfHeaders

    foreach ($item in $sectionPositions) {

        $s = $item.Original

        if ($s.SizeOfRawData -eq 0) {
            continue
        }

        $end =
            [UInt64]$item.NewRaw +
            [UInt64]$s.SizeOfRawData

        if ($end -gt $lastRawEnd) {
            $lastRawEnd = $end
        }
    }

    # ============================================================
    # PLACE NEW SECTION AFTER EXISTING SECTIONS
    # ============================================================

    $newSectionRawOffset =
        Align-Up `
            $lastRawEnd `
            $pe.FileAlignment

    $newSectionRawEnd =
        $newSectionRawOffset +
        $newSectionRawSize

    # ============================================================
    # CERTIFICATE TABLE
    #
    # Put certificate after all PE sections.
    # This means the certificate physically moves if necessary.
    # ============================================================

    if ($certificateBefore.Present) {

        $newCertificateOffset =
            Align-Up `
                $newSectionRawEnd `
                8

        $newCertificateEnd =
            $newCertificateOffset +
            [UInt64]$certificateBefore.Size
    }
    else {

        $newCertificateOffset = 0
        $newCertificateEnd = 0
    }

    # ============================================================
    # ORIGINAL OVERLAY
    #
    # A normal Authenticode PE has certificate at EOF.
    #
    # If arbitrary overlay exists after Certificate Table,
    # preserve it too.
    # ============================================================

    $overlayBytes = $null
    $overlaySize = 0

    if ($certificateBefore.Present) {

        $oldCertificateEnd =
            [UInt64]$certificateBefore.Offset +
            [UInt64]$certificateBefore.Size

        if (
            $oldCertificateEnd <
            [UInt64]$original.Length
        ) {

            $overlaySize =
                [int](
                    [UInt64]$original.Length -
                    $oldCertificateEnd
                )

            $overlayBytes =
                New-Object byte[] $overlaySize

            [Array]::Copy(
                $original,
                [int]$oldCertificateEnd,
                $overlayBytes,
                0,
                $overlaySize
            )
        }
    }
    else {

        # No certificate.
        # Everything after the last section is overlay.
        $oldLastEnd = 0

        foreach ($section in $pe.Sections) {

            if ($section.SizeOfRawData -eq 0) {
                continue
            }

            $end =
                [UInt64]$section.PointerToRawData +
                [UInt64]$section.SizeOfRawData

            if ($end -gt $oldLastEnd) {
                $oldLastEnd = $end
            }
        }

        if (
            $oldLastEnd <
            [UInt64]$original.Length
        ) {

            $overlaySize =
                [int](
                    [UInt64]$original.Length -
                    $oldLastEnd
                )

            $overlayBytes =
                New-Object byte[] $overlaySize

            [Array]::Copy(
                $original,
                [int]$oldLastEnd,
                $overlayBytes,
                0,
                $overlaySize
            )
        }
    }

    if ($certificateBefore.Present) {

        $newOverlayOffset =
            $newCertificateEnd
    }
    else {

        $newOverlayOffset =
            $newSectionRawEnd
    }

    $finalLength =
        [UInt64]$newOverlayOffset +
        [UInt64]$overlaySize

    if (
        $finalLength >
        [UInt64][Int32]::MaxValue
    ) {
        throw "Resulting PE is too large."
    }

    # ============================================================
    # ALLOCATE NEW FILE
    # ============================================================

    $result =
        New-Object byte[] ([int]$finalLength)

    # ============================================================
    # COPY ORIGINAL HEADERS
    #
    # Only original SizeOfHeaders bytes are copied.
    # Expanded area remains zero-filled.
    # ============================================================

    [Array]::Copy(
        $original,
        0,
        $result,
        0,
        [int]$pe.SizeOfHeaders
    )

    # ============================================================
    # UPDATE SIZE OF HEADERS
    # ============================================================

    Write-U32 `
        $result `
        $pe.SizeOfHeadersOffset `
        ([UInt32]$newSizeOfHeaders)

    # ============================================================
    # COPY SECTION RAW DATA
    # ============================================================

    foreach ($item in $sectionPositions) {

        $section =
            $item.Original

        if ($section.SizeOfRawData -eq 0) {
            continue
        }

        [Array]::Copy(
            $original,
            [int]$section.PointerToRawData,
            $result,
            [int]$item.NewRaw,
            [int]$section.SizeOfRawData
        )

        # Update PointerToRawData in section header.
        Write-U32 `
            $result `
            ($section.HeaderOffset + 20) `
            $item.NewRaw
    }

    # ============================================================
    # BUILD .pimport
    # ============================================================

    $sectionData =
        New-Object byte[] ([int]$newSectionRawSize)

    # ------------------------------------------------------------
    # Relative offsets -> RVA
    # ------------------------------------------------------------

    $descriptorRva =
        [UInt32](
            $newSectionRva +
            $descriptorOffset
        )

    $iltRva =
        [UInt32](
            $newSectionRva +
            $iltOffset
        )

    $iatRva =
        [UInt32](
            $newSectionRva +
            $iatOffset
        )

    $dllNameRva =
        [UInt32](
            $newSectionRva +
            $dllNameOffset
        )

    # ------------------------------------------------------------
    # IMAGE_IMPORT_DESCRIPTOR
    # ------------------------------------------------------------

    Write-U32 `
        $sectionData `
        ($descriptorOffset + 0) `
        $iltRva

    Write-U32 `
        $sectionData `
        ($descriptorOffset + 4) `
        0

    Write-U32 `
        $sectionData `
        ($descriptorOffset + 8) `
        0

    Write-U32 `
        $sectionData `
        ($descriptorOffset + 12) `
        $dllNameRva

    Write-U32 `
        $sectionData `
        ($descriptorOffset + 16) `
        $iatRva

    # ------------------------------------------------------------
    # ORDINAL IMPORT
    # ------------------------------------------------------------

    if ($pe.PointerSize -eq 4) {

        $ordinalValue =
            [UInt32](
                0x80000000 -bor
                [UInt32]$Ordinal
            )

        Write-U32 `
            $sectionData `
            $iltOffset `
            $ordinalValue

        Write-U32 `
            $sectionData `
            ($iltOffset + 4) `
            0

        Write-U32 `
            $sectionData `
            $iatOffset `
            $ordinalValue

        Write-U32 `
            $sectionData `
            ($iatOffset + 4) `
            0
    }
    else {

        $ordinalValue =
            [UInt64](
                0x8000000000000000 -bor
                [UInt64]$Ordinal
            )

        Write-U64 `
            $sectionData `
            $iltOffset `
            $ordinalValue

        Write-U64 `
            $sectionData `
            ($iltOffset + 8) `
            0

        Write-U64 `
            $sectionData `
            $iatOffset `
            $ordinalValue

        Write-U64 `
            $sectionData `
            ($iatOffset + 8) `
            0
    }

    # ------------------------------------------------------------
    # DLL NAME
    # ------------------------------------------------------------

    [Array]::Copy(
        $dllNameBytes,
        0,
        $sectionData,
        $dllNameOffset,
        $dllNameBytes.Length
    )

    $sectionData[
        $dllNameOffset +
        $dllNameBytes.Length
    ] = 0

    # ============================================================
    # WRITE NEW SECTION DATA
    # ============================================================

    [Array]::Copy(
        $sectionData,
        0,
        $result,
        [int]$newSectionRawOffset,
        $sectionData.Length
    )

    # ============================================================
    # NEW SECTION HEADER
    # ============================================================

    $newSectionHeader =
        $pe.SectionTableOffset +
        ($pe.NumberOfSections * 40)

    for (
        $i = 0;
        $i -lt 40;
        $i++
    ) {
        $result[
            $newSectionHeader + $i
        ] = 0
    }

    [Array]::Copy(
        $newSectionNameBytes,
        0,
        $result,
        $newSectionHeader,
        $newSectionNameBytes.Length
    )

    Write-U32 `
        $result `
        ($newSectionHeader + 8) `
        $newSectionVirtualSize

    Write-U32 `
        $result `
        ($newSectionHeader + 12) `
        ([UInt32]$newSectionRva)

    Write-U32 `
        $result `
        ($newSectionHeader + 16) `
        $newSectionRawSize

    Write-U32 `
        $result `
        ($newSectionHeader + 20) `
        ([UInt32]$newSectionRawOffset)

    # Relocations
    Write-U32 `
        $result `
        ($newSectionHeader + 24) `
        0

    # Line numbers
    Write-U32 `
        $result `
        ($newSectionHeader + 28) `
        0

    Write-U16 `
        $result `
        ($newSectionHeader + 32) `
        0

    Write-U16 `
        $result `
        ($newSectionHeader + 34) `
        0

    # ------------------------------------------------------------
    # Characteristics
    #
    # CNT_INITIALIZED_DATA
    # MEM_READ
    # MEM_WRITE
    # ------------------------------------------------------------

    $characteristics =
        [UInt32]0xC0000040

    Write-U32 `
        $result `
        ($newSectionHeader + 36) `
        $characteristics

    # ============================================================
    # NUMBER OF SECTIONS
    # ============================================================

    $newNumberOfSections =
        [UInt16](
            $pe.NumberOfSections + 1
        )

    Write-U16 `
        $result `
        ($pe.FileHeaderOffset + 2) `
        $newNumberOfSections

    # ============================================================
    # IMPORT DIRECTORY
    # ============================================================

    Write-U32 `
        $result `
        $pe.ImportDirectoryOffset `
        $descriptorRva

    # descriptor + terminator
    Write-U32 `
        $result `
        ($pe.ImportDirectoryOffset + 4) `
        40

    # ============================================================
    # SIZE OF IMAGE
    # ============================================================

    $newImageEnd =
        [UInt64]$newSectionRva +
        [UInt64]$newSectionVirtualSize

    $newSizeOfImage =
        [UInt32](
            Align-Up `
                $newImageEnd `
                $pe.SectionAlignment
        )

    Write-U32 `
        $result `
        $pe.SizeOfImageOffset `
        $newSizeOfImage

    # ============================================================
    # MOVE CERTIFICATE TABLE
    # ============================================================

    if ($certificateBefore.Present) {

        [Array]::Copy(
            $certificateBefore.Bytes,
            0,
            $result,
            [int]$newCertificateOffset,
            [int]$certificateBefore.Size
        )

        # SECURITY directory:
        #
        # VirtualAddress is FILE OFFSET.
        #
        Write-U32 `
            $result `
            $pe.SecurityDirectoryOffset `
            ([UInt32]$newCertificateOffset)

        Write-U32 `
            $result `
            ($pe.SecurityDirectoryOffset + 4) `
            ([UInt32]$certificateBefore.Size)
    }
    else {

        Write-U32 `
            $result `
            $pe.SecurityDirectoryOffset `
            0

        Write-U32 `
            $result `
            ($pe.SecurityDirectoryOffset + 4) `
            0
    }

    # ============================================================
    # COPY ORIGINAL OVERLAY
    # ============================================================

    if ($overlaySize -gt 0) {

        [Array]::Copy(
            $overlayBytes,
            0,
            $result,
            [int]$newOverlayOffset,
            $overlaySize
        )
    }

    # ============================================================
    # WRITE PE CHECKSUM
    # ============================================================

    $newChecksum =
        Set-PEChecksum `
            -Bytes $result `
            -PE $pe

    # ============================================================
    # AUTHENTICODE HASH AFTER
    #
    # PE structure is now complete.
    # ============================================================

    $newPE =
        Get-PEInfo `
            -Bytes $result

    $authHashAfter =
        Get-AuthenticodeHash `
            -Bytes $result `
            -PE $newPE

    Write-Verbose (
        "Authenticode SHA256 after:  {0}" -
        $authHashAfter
    )

    # ============================================================
    # CERTIFICATE VALIDATION BEFORE WRITE
    # ============================================================

    $certificateAfter =
        Test-CertificateTable `
            -Bytes $result `
            -PE $newPE

    if (-not $certificateAfter.Valid) {
        throw "New Certificate Table is invalid."
    }

    if ($certificateBefore.Present) {

        if (
            $certificateBefore.Size -
            ne
            $certificateAfter.Size
        ) {
            throw (
                "Certificate size changed unexpectedly."
            )
        }

        if (
            $certificateBefore.Hash -
            ne
            $certificateAfter.Hash
        ) {
            throw (
                "Certificate bytes changed unexpectedly."
            )
        }
    }

    # ============================================================
    # WRITE
    # ============================================================

    if (
        -not $PSCmdlet.ShouldProcess(
            $OutputPath,
            "Add import '$DllName' ordinal #$Ordinal"
        )
    ) {
        return
    }

    if (
        $Backup -and
        ($OutputPath -eq $fullPath)
    ) {

        $backupPath =
            "$fullPath.bak"

        [IO.File]::WriteAllBytes(
            $backupPath,
            $original
        )

        Write-Verbose (
            "Backup: {0}" -f
            $backupPath
        )
    }

    [IO.File]::WriteAllBytes(
        $OutputPath,
        $result
    )

    # ============================================================
    # FINAL RE-READ
    # ============================================================

    $verifyBytes =
        [IO.File]::ReadAllBytes(
            $OutputPath
        )

    $verification =
        Test-PEImage `
            -Bytes $verifyBytes

    if (-not $verification.Valid) {

        throw (
            "FINAL PE VALIDATION FAILED: {0}" -
            $verification.Error
        )
    }

    # ============================================================
    # VERIFY DLL
    # ============================================================

    $verifyPE =
        Get-PEInfo `
            -Bytes $verifyBytes

    $verifyImports =
        @(
            Get-PEImports `
                -Bytes $verifyBytes `
                -PE $verifyPE
        )

    $found =
        $verifyImports |
        Where-Object {
            $_.Name -ieq $DllName
        }

    if (-not $found) {

        throw (
            "Verification failed: DLL '{0}' " +
            "was not found in Import Directory." -
            $DllName
        )
    }

    # ============================================================
    # VERIFY CERTIFICATE
    # ============================================================

    $verifyCertificate =
        Test-CertificateTable `
            -Bytes $verifyBytes `
            -PE $verifyPE

    $certificatePreserved =
        $true

    if ($certificateBefore.Present) {

        if (
            $certificateBefore.Size -
            ne
            $verifyCertificate.Size
        ) {
            $certificatePreserved = $false
        }

        if (
            $certificateBefore.Hash -
            ne
            $verifyCertificate.Hash
        ) {
            $certificatePreserved = $false
        }
    }

    if (-not $certificatePreserved) {
        throw (
            "Verification failed: " +
            "Certificate Table was modified."
        )
    }

    # ============================================================
    # VERIFY AUTHENTICODE HASH AFTER RE-READ
    # ============================================================

    $verifyAuthHash =
        Get-AuthenticodeHash `
            -Bytes $verifyBytes `
            -PE $verifyPE

    if (
        $verifyAuthHash -ne
        $authHashAfter
    ) {
        throw (
            "Verification failed: " +
            "Authenticode hash is unstable."
        )
    }

    # ============================================================
    # VERIFY CHECKSUM
    # ============================================================

    $storedChecksum =
        Read-U32 `
            $verifyBytes `
            $verifyPE.CheckSumOffset

    $calculatedChecksum =
        Get-PEChecksum `
            -Bytes $verifyBytes `
            -ChecksumOffset $verifyPE.CheckSumOffset

    $checksumOK =
        (
            $storedChecksum -
            eq
            $calculatedChecksum
        )

    if (-not $checksumOK) {
        throw "Verification failed: PE checksum mismatch."
    }

    # ============================================================
    # VERIFY ARCHITECTURE
    # ============================================================

    if ($pe.IsPE32Plus) {

        if (-not $verifyPE.IsPE32Plus) {
            throw "Verification failed: PE32+ changed."
        }

        if ($verifyPE.Machine -ne $pe.Machine) {
            throw "Verification failed: machine changed."
        }
    }
    else {

        if (-not $verifyPE.IsPE32) {
            throw "Verification failed: PE32 changed."
        }

        if ($verifyPE.Machine -ne $pe.Machine) {
            throw "Verification failed: machine changed."
        }
    }

    # ============================================================
    # VERIFY NEW SECTION
    # ============================================================

    $newSection =
        $verifyPE.Sections |
        Where-Object {
            $_.Name -eq $newSectionName
        }

    if (-not $newSection) {
        throw (
            "Verification failed: " +
            "$newSectionName section missing."
        )
    }

    # ============================================================
    # RESULT
    # ============================================================

    [PSCustomObject]@{

        Success =
            $true

        Changed =
            $true

        Path =
            $OutputPath

        SourcePath =
            $fullPath

        DllName =
            $DllName

        ImportOrdinal =
            $Ordinal

        Architecture =
            $architecture

        PEFormat =
            $format

        Machine =
            ('0x{0:X4}' -f $verifyPE.Machine)

        OriginalSections =
            $pe.NumberOfSections

        NewSections =
            $verifyPE.NumberOfSections

        HeaderExpanded =
            ($headerDelta -gt 0)

        HeaderDelta =
            ('0x{0:X}' -f $headerDelta)

        OriginalSizeOfHeaders =
            ('0x{0:X}' -f $pe.SizeOfHeaders)

        NewSizeOfHeaders =
            ('0x{0:X}' -f $verifyPE.SizeOfHeaders)

        NewSection =
            $newSectionName

        NewSectionRVA =
            ('0x{0:X8}' -f $newSectionRva)

        NewSectionRawOffset =
            ('0x{0:X8}' -f $newSectionRawOffset)

        NewSectionRawSize =
            $newSectionRawSize

        ImportDirectoryRVA =
            ('0x{0:X8}' -f $verifyPE.ImportRva)

        ImportDirectorySize =
            $verifyPE.ImportSize

        ImportVerified =
            $true

        CertificateTablePresent =
            $certificateBefore.Present

        OriginalCertificateOffset =
            ('0x{0:X8}' -f $certificateBefore.Offset)

        NewCertificateOffset =
            if ($certificateAfter.Present) {
                ('0x{0:X8}' -f $certificateAfter.Offset)
            }
            else {
                '0x00000000'
            }

        CertificateTableSize =
            $certificateAfter.Size

        CertificateTableMoved =
            (
                $certificateBefore.Present -and
                (
                    $certificateBefore.Offset -
                    ne
                    $certificateAfter.Offset
                )
            )

        CertificateTablePreserved =
            $certificatePreserved

        CertificateSHA256Before =
            $certificateBefore.Hash

        CertificateSHA256After =
            $certificateAfter.Hash

        AuthenticodeSHA256Before =
            $authHashBefore

        AuthenticodeSHA256After =
            $verifyAuthHash

        AuthenticodeHashChanged =
            (
                $authHashBefore -
                ne
                $verifyAuthHash
            )

        # Ожидаемо FALSE после изменения PE.
        AuthenticodeSignatureValidAfter =
            $false

        Checksum =
            ('0x{0:X8}' -f $storedChecksum)

        ChecksumValid =
            $checksumOK

        PEValidation =
            $verification.Valid

        BackupCreated =
            (
                $Backup -and
                ($OutputPath -eq $fullPath)
            )

        Imports =
            @(
                $verifyImports |
                ForEach-Object {
                    $_.Name
                }
            )
    }
}


# ================================================================
# OPTIONAL HELPER:
# Проверка DLL на наличие ordinal #1.
#
# Без изменения PE.
#
# Работает с PE-файлом DLL.
# ================================================================

function Test-DllExportOrdinal1 {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $bytes =
        [IO.File]::ReadAllBytes(
            [IO.Path]::GetFullPath($Path)
        )

    $pe =
        Get-PEInfo `
            -Bytes $bytes

    # IMAGE_DIRECTORY_ENTRY_EXPORT = 0
    $exportDirectoryOffset =
        $pe.DataDirectoryOffset

    $exportRva =
        Read-U32 `
            $bytes `
            $exportDirectoryOffset

    $exportSize =
        Read-U32 `
            $bytes `
            ($exportDirectoryOffset + 4)

    if (
        $exportRva -eq 0 -or
        $exportSize -eq 0
    ) {
        return $false
    }

    $exportFileOffset =
        Convert-RvaToFileOffset `
            -PE $pe `
            -Rva $exportRva

    if ($null -eq $exportFileOffset) {
        return $false
    }

    $o =
        [int]$exportFileOffset

    # IMAGE_EXPORT_DIRECTORY:
    #
    # +16 Base
    # +20 NumberOfFunctions
    # +24 NumberOfNames
    # +28 AddressOfFunctions
    # +32 AddressOfNames
    # +36 AddressOfNameOrdinals
    #

    $base =
        Read-U32 $bytes ($o + 16)

    $numberOfFunctions =
        Read-U32 $bytes ($o + 20)

    if ($numberOfFunctions -eq 0) {
        return $false
    }

    $ordinalIndex =
        [Int64]1 -
        [Int64]$base

    if (
        $ordinalIndex -lt 0 -or
        $ordinalIndex -ge $numberOfFunctions
    ) {
        return $false
    }

    return $true
}


# ================================================================
# EXAMPLES
# ================================================================

<#

# ------------------------------------------------------------
# 1. Полный аналог:
#
#    setdll-x64.exe /d:version.dll opera.exe
#
# ------------------------------------------------------------

$result =
    Add-DllImport `
        -Path '.\opera.exe' `
        -DllName 'version.dll' `
        -Ordinal 1 `
        -Backup `
        -VerifyAuthenticodeHash `
        -Verbose

$result | Format-List *


# ------------------------------------------------------------
# 2. Не меняется исходный opera.exe
# ------------------------------------------------------------

$result =
    Add-DllImport `
        -Path '.\opera.exe' `
        -OutputPath '.\opera_patched.exe' `
        -DllName 'version.dll' `
        -Ordinal 1 `
        -VerifyAuthenticodeHash `
        -Verbose

$result | Format-List *


# ------------------------------------------------------------
# 3. Проверить version.dll
# ------------------------------------------------------------

if (Test-DllExportOrdinal1 '.\version.dll') {
    Write-Host 'version.dll exports ordinal #1'
}
else {
    Write-Host 'version.dll DOES NOT export ordinal #1'
}


# ------------------------------------------------------------
# 4. По итогу в скрипте вместо setdll.exe можно использовать:
# ------------------------------------------------------------


$result = Add-DllImport `
    -Path "$tmpdir\$ExeName" `
    -DllName 'version.dll' `
    -Ordinal 1 `
    -VerifyAuthenticodeHash `
    -Verbose

if (-not $result.Success) {
    throw 'Add-DllImport failed'
}

if (-not $result.ImportVerified) {
    throw 'version.dll import verification failed'
}

if (-not $result.PEValidation) {
    throw 'PE validation failed'
}

if (-not $result.ChecksumValid) {
    throw 'PE checksum validation failed'
}

Write-Host "Inject version.dll: OK"

#>
