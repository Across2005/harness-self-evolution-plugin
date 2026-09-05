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
    # moon 解析顺序：$env:MOON_EXE > ~/.moon/bin/moon.exe > PATH。
    # PATH 上可能并存多个 moon 安装（实测 .moonbit\bin 里有旧版 0.1.20260713，
    # 它按旧布局在 ~/.moon/lib/ 下找 runtime.c，而新版布局在 lib\runtime\ 下
    # —— BuildRuntimeLib 直接报 "input ... runtime.c missing"，test/build 全挂）。
    # 因此锚定本项目验证过的 ~/.moon/bin/moon.exe，并始终打印实际版本，
    # 让装错的工具链在第一屏可见，而不是以一条裸路径缺失报错收场。
    $cmd = $null
    if ($env:MOON_EXE) {
        # 显式覆盖是硬承诺：设了却不存在就直接报错，而不是静默回退
        # （回退会把「指错了工具链」掩盖成「恰好用了默认的」）。
        if (-not (Test-Path $env:MOON_EXE)) {
            throw "MOON_EXE 指向的文件不存在：$env:MOON_EXE"
        }
        $cmd = $env:MOON_EXE
    } elseif (Test-Path (Join-Path $env:USERPROFILE '.moon\bin\moon.exe')) {
        $cmd = Join-Path $env:USERPROFILE '.moon\bin\moon.exe'
    } else {
        $fromPath = Get-Command moon -ErrorAction SilentlyContinue
        if ($null -ne $fromPath) { $cmd = $fromPath.Source }
    }
    if ($null -eq $cmd) {
        throw "找不到 moon：$env:USERPROFILE\.moon\bin\moon.exe 不存在，PATH 上也没有 moon。请先安装 MoonBit 工具链。"
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
    # 版本查询必须**完整收住输出**再取首行。若写成一行的
    # `& $cmd version 2>&1 | Select-Object -First 1`，-First 会提前终止管道，
    # PS 5.1 会把还在写输出的原生进程一并掐断 —— $LASTEXITCODE 于是变成
    # 被杀进程的非零码，'all' 分支据此误判 build 失败（假红，同本文件头
    # 注释警告的那一类）。moon version 至少输出两行，必然触发。
    $verLines = & $cmd version 2>&1
    $LASTEXITCODE = 0
    Write-Host "[build] moon  = $cmd ($(@($verLines)[0]))" -ForegroundColor DarkGray
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
