<#
.SYNOPSIS
    MoonBit native 构建封装。

.DESCRIPTION
    本机 native 后端的构建链默认是断的，必须由本脚本注入 MSVC/SDK 环境：

      · `~\.moon\bin\internal\tcc.exe` 存在，但其 -print-search-dirs 报出的
        `include\` 与 `lib\` 目录**均不存在**，故 tcc 无法编译任何需要系统头的代码。
      · `cl` / `clang` / `clang-cl` / `gcc` / `cc` / `link` 在 PATH 上**全部缺失**。
      · 但 MSVC 14.51 与 Windows SDK 10.0.26100 已安装，只是未进 PATH。

    因此 moon 在 native 目标下会报 "no system C compiler found; tried cl, cc, gcc, clang"。
    本脚本探测 VS 安装并注入 INCLUDE / LIB / PATH，等价于 vcvars64.bat，
    但无需 cmd.exe（在纯 PowerShell 环境里也能用）。

.PARAMETER Task
    check  —— moon check --deny-warn --target native（不需 C 编译器，但仍注入以保持一致）
    test   —— moon test --target native
    build  —— moon build --target native --release，并把产物复制为 bin\harness-evolution.exe
    fmt    —— moon fmt
    all    —— check + test + build

.EXAMPLE
    .\build.ps1 -Task build
    .\build.ps1                 # 默认 all
#>
[CmdletBinding()]
param(
    [ValidateSet('check', 'test', 'build', 'fmt', 'all')]
    [string]$Task = 'all'
)

$ErrorActionPreference = 'Stop'

function Find-VsInstall {
    # 按新到旧探测；VS 18 (2026) / 2022 / BuildTools 均在候选内
    $candidates = @(
        'C:\Program Files\Microsoft Visual Studio\18',
        'C:\Program Files\Microsoft Visual Studio\2022',
        'C:\Program Files (x86)\Microsoft Visual Studio\2022',
        'C:\Program Files (x86)\Microsoft Visual Studio\2019'
    )
    foreach ($root in $candidates) {
        if (-not (Test-Path $root)) { continue }
        foreach ($edition in @('Community', 'Professional', 'Enterprise', 'BuildTools')) {
            $msvcRoot = Join-Path $root "$edition\VC\Tools\MSVC"
            if (-not (Test-Path $msvcRoot)) { continue }
            $ver = Get-ChildItem $msvcRoot -Directory |
                Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
            if ($null -eq $ver) { continue }
            $cl = Join-Path $ver.FullName 'bin\Hostx64\x64\cl.exe'
            if (Test-Path $cl) {
                return [pscustomobject]@{ Msvc = $ver.FullName; Edition = "$root\$edition" }
            }
        }
    }
    return $null
}

function Find-WindowsSdk {
    $root = 'C:\Program Files (x86)\Windows Kits\10'
    if (-not (Test-Path $root)) { return $null }
    $ver = Get-ChildItem "$root\Include" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^10\.' } |
        Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if ($null -eq $ver) { return $null }
    return [pscustomobject]@{ Root = $root; Version = $ver.Name }
}

function Initialize-NativeToolchain {
    $vs = Find-VsInstall
    if ($null -eq $vs) {
        throw @"
未找到 MSVC 工具链。native 后端需要一个 cl.exe 兼容的编译器/链接器驱动。
安装方式（任选其一）：
  winget install Microsoft.VisualStudio.2022.BuildTools --override "--passive --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.Windows11SDK.22621"
或在已装的 Visual Studio 里添加「使用 C++ 的桌面开发」工作负载。
"@
    }
    $sdk = Find-WindowsSdk
    if ($null -eq $sdk) { throw "未找到 Windows SDK（预期位于 C:\Program Files (x86)\Windows Kits\10）" }

    $env:INCLUDE = @(
        "$($vs.Msvc)\include",
        "$($sdk.Root)\Include\$($sdk.Version)\ucrt",
        "$($sdk.Root)\Include\$($sdk.Version)\um",
        "$($sdk.Root)\Include\$($sdk.Version)\shared"
    ) -join ';'

    $env:LIB = @(
        "$($vs.Msvc)\lib\x64",
        "$($sdk.Root)\Lib\$($sdk.Version)\ucrt\x64",
        "$($sdk.Root)\Lib\$($sdk.Version)\um\x64"
    ) -join ';'

    $env:PATH = "$($vs.Msvc)\bin\Hostx64\x64;$($sdk.Root)\bin\$($sdk.Version)\x64;$env:PATH"

    Write-Host "[build] MSVC  = $($vs.Msvc)" -ForegroundColor DarkGray
    Write-Host "[build] SDK   = $($sdk.Root)\$($sdk.Version)" -ForegroundColor DarkGray
    Write-Host "[build] cl    = $((Get-Command cl -ErrorAction SilentlyContinue).Source)" -ForegroundColor DarkGray
}

Initialize-NativeToolchain

# moon 把进度信息（包括 "Finished. moon: no work to do"）写到 stderr。
# PowerShell 在 $ErrorActionPreference='Stop' 下会把原生命令的 stderr 包成
# 终止错误抛出 —— 于是「moon 其实成功」也会让本脚本红着退出（假红）。
# 因此跑 moon 时把偏好降到函数作用域内的 Continue，成败一律以 $LASTEXITCODE 为准。
function Invoke-Moon {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$MoonArgs)
    # 先确定 moon.exe 的绝对路径：若只写裸 `moon` 而它不在 PATH，
    # CommandNotFoundException 会被 Continue 吞掉，$LASTEXITCODE 仍是上一次的旧值
    # —— 那会把「根本没跑」误判成成功（假绿，比假红更危险）。
    $cmd = Get-Command moon -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        $candidate = Join-Path $env:USERPROFILE '.moon\bin\moon.exe'
        if (-not (Test-Path $candidate)) {
            throw "找不到 moon：PATH 上没有 moon，$candidate 也不存在。请先安装 MoonBit 工具链。"
        }
        $cmd = $candidate
    } else {
        $cmd = $cmd.Source
    }
    $ErrorActionPreference = 'Continue'
    # 关键：`& $cmd` 的 stdout 会流入**本函数的输出流**，若直接 `return $LASTEXITCODE`
    # 就把「moon 的输出 + 退出码」打包成数组返回，调用处的 `-ne 0` 于是误判。
    # 所以先把输出收进变量、用 Write-Host 打到宿主，函数只返回退出码标量。
    $out = ''
    try {
        $out = & $cmd @MoonArgs 2>&1
    } catch {
        Write-Host $_
        return 1
    }
    $rc = $LASTEXITCODE
    foreach ($line in $out) { Write-Host "$line" }
    return $rc
}

# 允许在任意工作目录调用；moon 必须在模块根执行
$moduleRoot = $PSScriptRoot
Push-Location $moduleRoot
try {
    switch ($Task) {
        'fmt' {
            if ((Invoke-Moon fmt) -ne 0) { throw "moon fmt 失败" }
        }
        'check' {
            if ((Invoke-Moon check --deny-warn --target native) -ne 0) { throw "moon check 失败" }
        }
        'test' {
            if ((Invoke-Moon test --target native) -ne 0) { throw "moon test 失败" }
        }
        'build' {
            if ((Invoke-Moon build --target native --release) -ne 0) { throw "moon build 失败" }
            # 产物落在 _build\native\release\build\<pkg>\<pkg>.exe（实测，非 target\）
            $exe = Get-ChildItem "$moduleRoot\_build\native\release\build" -Recurse -Filter '*.exe' |
                Where-Object { $_.Name -eq 'harness_evolution.exe' } | Select-Object -First 1
            if ($null -eq $exe) { throw "未找到 harness_evolution.exe 产物" }
            New-Item -ItemType Directory -Force -Path "$moduleRoot\bin" | Out-Null
            Copy-Item $exe.FullName "$moduleRoot\bin\harness-evolution.exe" -Force
            Write-Host "[build] bin\harness-evolution.exe ($($exe.Length) bytes)" -ForegroundColor Green
        }
        'all' {
            # 逐步执行并显式核对退出码：子脚本失败时不要靠异常冒泡（假红的同源问题）
            $LASTEXITCODE = 0
            & $PSCommandPath -Task check
            if ($LASTEXITCODE -ne 0) { throw "check 未通过" }
            $LASTEXITCODE = 0
            & $PSCommandPath -Task test
            if ($LASTEXITCODE -ne 0) { throw "test 未通过" }
            $LASTEXITCODE = 0
            & $PSCommandPath -Task build
            if ($LASTEXITCODE -ne 0) { throw "build 未通过" }
        }
    }
}
finally {
    Pop-Location
}
