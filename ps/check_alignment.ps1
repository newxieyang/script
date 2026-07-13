# NDK and target configuration
$ndkPath = "D:\apps\Android\Sdk\ndk\28.2.13676358"
$readelf = "$ndkPath\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe"
# $targetDir = "D:\git\oxi\g6\A910\A910_Android\libFAP\src\main\cpp\arm64-v8a"
$targetDir = "D:\git\oxi\g6\A910\A910_Android\libFAP\src\main\cpp\armeabi-v7a"

$soFiles = Get-ChildItem -Path $targetDir -Filter "*.so"

Write-Host "Checking directory: $targetDir" -ForegroundColor Cyan
Write-Host "------------------------------------------------"

foreach ($file in $soFiles) {
    # Extract LOAD segments alignment info
    $result = & $readelf -l $file.FullName | Select-String "LOAD"
    
    $isAligned = $false
    foreach ($line in $result) {
        # Check for 0x4000 (16KB) at the end of the line
        if ($line -match "0x4000\s*$") {
            $isAligned = $true
            break
        }
    }

    if ($isAligned) {
        Write-Host " [PASS] $($file.Name): 16KB Aligned (0x4000)" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] $($file.Name): NOT 16KB Aligned" -ForegroundColor Red
        foreach ($line in $result) {
            Write-Host "        $line" -ForegroundColor Yellow
        }
    }
}