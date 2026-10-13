# libFAP 对外 API 头文件差异看板

- 项目配置：`D:\git\script\py\api_config.json`（5 个：A910, MIAXIS, Thales, huantian, GSER）
- libFAP 仓库：`D:\git\oxi\g6\A910\A910\libFAP`
- 远程分支：**22** 条

- 拷贝层漂移：**19** 处（详见最后一节）

> 本报告由 `py/apiDiff.py` 生成，只读、不修改任何文件。

## 1. 分支版本矩阵

libFAP 每条分支上三个头文件的版本。哈希相同 = 内容逐字节相同。

| 分支 | ScanAPI | 行 | ScanUltimate | 行 | ScanUltimateApi_err | 行 |
|---|---|---|---|---|---|---|
| `1.0.54` | `7de4784e` | 395 | `5152d9a9` | 133 | `c700ed97` | 76 |
| `51.25` | `cc176d3e` | 388 | `5152d9a9` | 133 | `c700ed97` | 76 |
| `51.67` | `81bdb513` | 296 | `a45ca3c0` | 202 | `08e33917` | 77 |
| `MIAXIS` | `671ce9e7` | 402 | `3f543905` | 135 | `c700ed97` | 76 |
| `OXi` | `9ee1edb0` | 307 | `d6edf62c` | 161 | `08e33917` | 77 |
| `aratek` | `81bdb513` | 296 | `a45ca3c0` | 202 | `08e33917` | 77 |
| `fangzheng` | `d4a8ab2b` | 285 | `348cfe77` | 184 | `c700ed97` | 76 |
| `huantian` | `2735c2b7` | 290 | `2a65e975` | 206 | `697f0e12` | 76 |
| `italy` | `55ed591b` | 347 | `3f543905` | 135 | `c700ed97` | 76 |
| `kejin` | `4df87c13` | 275 | `e16dff22` | 203 | `c700ed97` | 76 |
| `mantra` | `62eea457` | 251 | `a0b14e32` | 176 | `07d1ea80` | 108 |
| `master` | `56164433` | 383 | `85d0b879` | 131 | `c700ed97` | 76 |
| `miaxis0317` | `671e1e5b` | 317 | `641500d3` | 186 | `08e33917` | 77 |
| `new` | `ea4c7f93` | 264 | `19f7e2f1` | 191 | `3797f7a6` | 71 |
| `old25` | `1b2cd4a1` | 315 | `c2cf22af` | 206 | `c700ed97` | 76 |
| `old25LibAI` | `1649b9cb` | 390 | `5152d9a9` | 133 | `c700ed97` | 76 |
| `shenzhou` | `7f255f78` | 282 | `2c9fe885` | 211 | `c700ed97` | 76 |
| `thales` | `9ee1edb0` | 307 | `d6edf62c` | 161 | `08e33917` | 77 |
| `v54.0.0` | `7de4784e` | 395 | `5152d9a9` | 133 | `c700ed97` | 76 |
| `ver47` | `4e7a4b0b` | 286 | `22519ed0` | 194 | `c700ed97` | 76 |
| `ver51.76` | `ccb9ff0a` | 303 | `22519ed0` | 194 | `c700ed97` | 76 |
| `win7` | `059ca604` | 275 | `89e5192e` | 202 | `c700ed97` | 76 |

**小计**

| 头文件 | 分支数 | 不同版本数 | 只出现在单条分支上的版本 |
|---|---|---|---|
| ScanAPI | 22 | **19** | 16 |
| ScanUltimate | 22 | **15** | 10 |
| ScanUltimateApi_err | 22 | **5** | 3 |

## 2. API 契约分组（按 ScanAPI 导出函数指纹聚类）

把每条分支的 ScanAPI 导出函数集合+签名做指纹，指纹相同的分支 = 同一份对外契约。
分组结果就是「版本化路线」里该打几个 tag 的依据：同组可以共用一个版本号。

| 契约指纹 | 分支数 | 导出函数数 | 函数命名样本 | 分支 |
|---|---|---|---|---|
| `38852982` | 2 | 19 | `OXi_RollImgCenter` | `1.0.54`, `v54.0.0` |
| `e206ee97` | 2 | 20 | `OXiScan_GetDevices` | `51.67`, `aratek` |
| `d80d8cf1` | 2 | 21 | `OXi_RollImgCenter` | `MIAXIS`, `miaxis0317` |
| `393c8a52` | 2 | 18 | `OXi_GetDevices` | `OXi`, `thales` |
| `c00c2ef4` | 2 | 19 | `OXi_RollImgCenter` | `old25`, `shenzhou` |
| `33186f40` | 1 | 17 | `OXi_RollImgCenter` | `51.25` |
| `5f23ccfb` | 1 | 15 | `OXi_cancelCaptureImage` | `fangzheng` |
| `6c53919a` | 1 | 17 | `OXi_cancelCaptureImage` | `huantian` |
| `6e38f3d4` | 1 | 15 | `OXi_cancelCaptureImage` | `italy` |
| `bafc43e6` | 1 | 14 | `OXi_calculateNFIQScore` | `kejin` |
| `dc1480bf` | 1 | 13 | `CaptureORG` | `mantra` |
| `38a2b02b` | 1 | 19 | `OXi_RollImgCenter` | `master` |
| `af561f15` | 1 | 16 | `OXi_capture` | `new` |
| `233dc5b1` | 1 | 18 | `OXi_RollImgCenter` | `old25LibAI` |
| `1dea7fad` | 1 | 19 | `OXi_RollImgCenter` | `ver47` |
| `35945371` | 1 | 19 | `OXi_RollImgCenter` | `ver51.76` |
| `c4d4ab04` | 1 | 16 | `OXi_cancelCaptureImage` | `win7` |

## 3. 同名函数签名差异

按项目实际编译时会吃进去的那份头文件对比。只列出「同名但签名不一致」的函数。
**注意**：如果某项目给函数改了名（例如 `GetVersionInfo` vs `OXi_getVersion`），
工具无法自动判定它们是同一个函数，会落到下面的「独有函数」清单里，需人工确认。

| 项目 | 头文件目录 | 用到的文件 | 提取函数数 |
|---|---|---|---|
| `A910` | `libFAP\include` | OXiScanAPI.h, OXiScanUltimate.h, OXiScanUltimateApi_err.h | 20 |
| `MIAXIS` | `libFAP\include` | OXiScanAPI.h, OXiScanUltimate.h, OXiScanUltimateApi_err.h | 21 |
| `Thales` | `libFAP\include` | ScanAPI.h, ScanUltimate.h, ScanUltimateApi_err.h | 18 |
| `huantian` | `libFAP\include` | ScanAPI.h, ScanUltimate.h, ScanUltimateApi_err.h | 16 |
| `GSER` | `base\export` | OXiScan_Api.h | 20 |

共 48 个导出函数，其中 **13 个**在不同项目里签名不一致。

| 函数 | 变体数 | A910 | MIAXIS | Thales | huantian | GSER |
|---|---|---|---|---|---|---|
| `OXi_cancelCaptureImage` | 2 | v1 | v2 | v2 | — | — |
| `OXi_captureImage` | 2 | v1 | v1 | v1 | v2 | — |
| `OXi_closeDevice` | 2 | v1 | v1 | v1 | v2 | — |
| `OXi_getSerialNumber` | 2 | v1 | v1 | v1 | v2 | — |
| `OXi_getUUID` | 2 | v1 | v1 | v1 | v2 | — |
| `OXi_getVersion` | 3 | v1 | v1 | v2 | v3 | — |
| `OXi_initCapture` | 3 | v1 | v1 | v2 | v3 | — |
| `OXi_openDevice` | 3 | v1 | v1 | v2 | v3 | — |
| `OXi_readFlash2k` | 2 | v1 | v1 | v1 | v2 | — |
| `OXi_setBeep` | 2 | v1 | v1 | v1 | v2 | — |
| `OXi_setLED` | 2 | v1 | v1 | v1 | v2 | — |
| `OXi_setPIDVID` | 2 | v1 | v1 | v1 | v2 | — |
| `OXi_writeFlash2k` | 2 | v1 | v1 | v1 | v2 | — |

各变体的完整签名：

**`OXi_cancelCaptureImage`**

- `v1` (A910) ： `OXISCAN_API int OXi_cancelCaptureImage(OXIHANDLE oxiHandle)`
- `v2` (MIAXIS, Thales) ： `OXISCAN_API int OXi_cancelCaptureImage(EmRegIndicatorVal printType)`

**`OXi_captureImage`**

- `v1` (A910, MIAXIS, Thales) ： `OXISCAN_API int OXi_captureImage(OXIHANDLE oxiHandle, CapCallbacks callback)`
- `v2` (huantian) ： `OXISCAN_API int OXi_captureImage(SCANNER_HANDLE sHandle, CapCallbacks callback)`

**`OXi_closeDevice`**

- `v1` (A910, MIAXIS, Thales) ： `OXISCAN_API int OXi_closeDevice(OXIHANDLE oxiHandle)`
- `v2` (huantian) ： `OXISCAN_API int OXi_closeDevice(SCANNER_HANDLE sHandle)`

**`OXi_getSerialNumber`**

- `v1` (A910, MIAXIS, Thales) ： `OXISCAN_API int OXi_getSerialNumber(OXIHANDLE oxiHandle, void* pBuffer)`
- `v2` (huantian) ： `OXISCAN_API int OXi_getSerialNumber(SCANNER_HANDLE sHandle, void *pBuffer)`

**`OXi_getUUID`**

- `v1` (A910, MIAXIS, Thales) ： `OXISCAN_API int OXi_getUUID(OXIHANDLE oxiHandle, unsigned char *data)`
- `v2` (huantian) ： `OXISCAN_API int OXi_getUUID(SCANNER_HANDLE sHandle, unsigned char *data)`

**`OXi_getVersion`**

- `v1` (A910, MIAXIS) ： `OXISCAN_API int OXi_getVersion(OXIHANDLE oxiHandle, POXISCAN_VERSION_INFO pVersionInfo)`
- `v2` (Thales) ： `OXISCAN_API int OXi_getVersion(OXIHANDLE oxiHandle, PSCAN_VERSION_INFO pVersionInfo)`
- `v3` (huantian) ： `OXISCAN_API int OXi_getVersion(SCANNER_HANDLE sHandle, PSCAN_VERSION_INFO pVersionInfo)`

**`OXi_initCapture`**

- `v1` (A910, MIAXIS) ： `OXISCAN_API int OXi_initCapture(OXIHANDLE oxiHandle, POXISCAN_CAP_PARA cap_para)`
- `v2` (Thales) ： `OXISCAN_API int OXi_initCapture(OXIHANDLE oxiHandle, PSCAN_CAP_PARA cap_para)`
- `v3` (huantian) ： `OXISCAN_API int OXi_initCapture(SCANNER_HANDLE sHandle, PSCAN_CAP_PARA cap_para)`

**`OXi_openDevice`**

- `v1` (A910, MIAXIS) ： `OXISCAN_API OXIHANDLE OXi_openDevice(POXISCAN_INIT_PARAM initParam)`
- `v2` (Thales) ： `OXISCAN_API OXIHANDLE OXi_openDevice(PSCAN_INIT_PARAM initParam)`
- `v3` (huantian) ： `OXISCAN_API SCANNER_HANDLE OXi_openDevice(PSCAN_INIT_PARAM initParam)`

**`OXi_readFlash2k`**

- `v1` (A910, MIAXIS, Thales) ： `OXISCAN_API int OXi_readFlash2k(OXIHANDLE oxiHandle, unsigned char *data, int size)`
- `v2` (huantian) ： `OXISCAN_API int OXi_readFlash2k(SCANNER_HANDLE sHandle, unsigned char *data, int size)`

**`OXi_setBeep`**

- `v1` (A910, MIAXIS, Thales) ： `OXISCAN_API int OXi_setBeep(OXIHANDLE oxiHandle, int beepCount)`
- `v2` (huantian) ： `OXISCAN_API int OXi_setBeep(SCANNER_HANDLE sHandle, int beepCount)`

**`OXi_setLED`**

- `v1` (A910, MIAXIS, Thales) ： `OXISCAN_API int OXi_setLED(OXIHANDLE oxiHandle, unsigned short btLedIndex, unsigned int btState)`
- `v2` (huantian) ： `OXISCAN_API int OXi_setLED(SCANNER_HANDLE sHandle, unsigned short btLedIndex, unsigned int btState)`

**`OXi_setPIDVID`**

- `v1` (A910, MIAXIS, Thales) ： `OXISCAN_API int OXi_setPIDVID(OXIHANDLE oxiHandle, unsigned short PID, unsigned short VID)`
- `v2` (huantian) ： `OXISCAN_API int OXi_setPIDVID(SCANNER_HANDLE sHandle, unsigned short PID, unsigned short VID)`

**`OXi_writeFlash2k`**

- `v1` (A910, MIAXIS, Thales) ： `OXISCAN_API int OXi_writeFlash2k(OXIHANDLE oxiHandle, unsigned char *data, int size)`
- `v2` (huantian) ： `OXISCAN_API int OXi_writeFlash2k(SCANNER_HANDLE sHandle, unsigned char *data, int size)`

**某项目独有的导出函数**（其它项目完全没有同名函数）

- `A910` （1 个）： `OXi_queryTouch`
- `MIAXIS` （1 个）： `OXi_calculateNFIQScore`
- `Thales` （2 个）： `OXi_GetDevices`, `OXi_IDScan`
- `huantian` （4 个）： `OXi_capture`, `OXi_captureOrg`, `OXi_getDeviceList`, `OXi_stopCapture`
- `GSER` （19 个）： `OXiScan_CloseDevice`, `OXiScan_OpenDevice`, `OXiScan_calibration`, `OXiScan_getChipID`, `OXiScan_getCustomerSerialNumber`, `OXiScan_getLicense`, `OXiScan_getSaveImagePath`, `OXiScan_getSerialNumber`, `OXiScan_getUSBSerialNumber`, `OXiScan_getVersion`, `OXiScan_initCali`, `OXiScan_initCapture`, `OXiScan_setBeep`, `OXiScan_setCustomerSerialNumber`, `OXiScan_setLED`, `OXiScan_setLicense`, `OXiScan_startCapture`, `OXiScan_stopCapture`, `OXiScan_strerror`

## 4. 拷贝层一致性

主本 = 各项目的 API 头目录（G6 机型是 `libFAP/include`，来自 submodule）。
同一个 demo 目录下可能**存在多处副本**（根目录 / `include/` / `libFAP/…`），
它们的同步状态可能各不相同，所以逐处列出。

| 项目 | 副本位置 | ScanAPI | ScanUltimate | Api_err |
|---|---|---|---|---|
| `A910` | `A910_win` / include | 同源 | 同源 | 同源 |
| `A910` | `A910_qt` / 根目录 | **漂移 177 行** | **漂移 38 行** | **漂移 16 行** |
| `A910` | `A910_Android` / libFAP/src/main/cpp/include | 同源 | 同源 | 同源 |
| `A910` | `A910_Android` / 根目录 | **漂移 28 行** | **漂移 219 行** | **漂移 1 行** |
| `MIAXIS` | `MIAXIS_win` / 根目录 | 同源 | 同源 | 同源 |
| `MIAXIS` | `MIAXIS_qt` / 根目录 | **漂移 258 行** | **漂移 158 行** | **漂移 16 行** |
| `MIAXIS` | `MIAXIS_Android` / libFAP/src/main/cpp/include | 同源 | **漂移 213 行** | **漂移 1 行** |
| `Thales` | `Thales_win` / 根目录 | 同源 | 同源 | 同源 |
| `Thales` | `Thales_qt` / 根目录 | **漂移 280 行** | **漂移 147 行** | **漂移 16 行** |
| `Thales` | `Thales_Android` / libFAP/src/main/cpp/include | 同源 | 同源 | 同源 |
| `huantian` | `huantian_win` / 根目录 | 同源 | **漂移 37 行** | **漂移 1 行** |
| `huantian` | `huantian_qt` / 根目录 | **漂移 253 行** | **漂移 153 行** | **漂移 21 行** |

**同目录下并存多份同后缀头文件**（比较时取了规范名，其余需人工确认是否是废弃副本）：

- `huantian` / `huantian_win` / 根目录 —— 取 `ScanAPI.h`，另有 `HTScanAPI.h`
- `huantian` / `huantian_win` / 根目录 —— 取 `ScanUltimateApi_err.h`，另有 `HTScanUltimateApi_err.h`

**需要处理的漂移（19 处）：**

- `Thales` / `Thales_qt` / 根目录 / ScanAPI —— 差 280 行
  - `D:\git\oxi\g6\Thales\Thales_qt\OXiScanAPI.h`
- `MIAXIS` / `MIAXIS_qt` / 根目录 / ScanAPI —— 差 258 行
  - `D:\git\oxi\g6\MIAXIS\MIAXIS_qt\OXiScanAPI.h`
- `huantian` / `huantian_qt` / 根目录 / ScanAPI —— 差 253 行
  - `D:\git\oxi\g6\huantian\huantian_qt\OXiScanAPI.h`
- `A910` / `A910_Android` / 根目录 / ScanUltimate —— 差 219 行
  - `D:\git\oxi\g6\A910\A910_Android\OXiScanUltimate.h`
- `MIAXIS` / `MIAXIS_Android` / libFAP/src/main/cpp/include / ScanUltimate —— 差 213 行
  - `D:\git\oxi\g6\MIAXIS\MIAXIS_Android\libFAP\src\main\cpp\include\OXiScanUltimate.h`
- `A910` / `A910_qt` / 根目录 / ScanAPI —— 差 177 行
  - `D:\git\oxi\g6\A910\A910_qt\OXiScanAPI.h`
- `MIAXIS` / `MIAXIS_qt` / 根目录 / ScanUltimate —— 差 158 行
  - `D:\git\oxi\g6\MIAXIS\MIAXIS_qt\OXiScanUltimate.h`
- `huantian` / `huantian_qt` / 根目录 / ScanUltimate —— 差 153 行
  - `D:\git\oxi\g6\huantian\huantian_qt\OXiScanUltimate.h`
- `Thales` / `Thales_qt` / 根目录 / ScanUltimate —— 差 147 行
  - `D:\git\oxi\g6\Thales\Thales_qt\OXiScanUltimate.h`
- `A910` / `A910_qt` / 根目录 / ScanUltimate —— 差 38 行
  - `D:\git\oxi\g6\A910\A910_qt\OXiScanUltimate.h`
- `huantian` / `huantian_win` / 根目录 / ScanUltimate —— 差 37 行
  - `D:\git\oxi\g6\huantian\huantian_win\ScanUltimate.h`
- `A910` / `A910_Android` / 根目录 / ScanAPI —— 差 28 行
  - `D:\git\oxi\g6\A910\A910_Android\OXiScanAPI.h`
- `huantian` / `huantian_qt` / 根目录 / ScanUltimateApi_err —— 差 21 行
  - `D:\git\oxi\g6\huantian\huantian_qt\OXiScanUltimateApi_err.h`
- `A910` / `A910_qt` / 根目录 / ScanUltimateApi_err —— 差 16 行
  - `D:\git\oxi\g6\A910\A910_qt\OXiScanUltimateApi_err.h`
- `MIAXIS` / `MIAXIS_qt` / 根目录 / ScanUltimateApi_err —— 差 16 行
  - `D:\git\oxi\g6\MIAXIS\MIAXIS_qt\OXiScanUltimateApi_err.h`
- `Thales` / `Thales_qt` / 根目录 / ScanUltimateApi_err —— 差 16 行
  - `D:\git\oxi\g6\Thales\Thales_qt\OXiScanUltimateApi_err.h`
- `A910` / `A910_Android` / 根目录 / ScanUltimateApi_err —— 差 1 行
  - `D:\git\oxi\g6\A910\A910_Android\OXiScanUltimateApi_err.h`
- `MIAXIS` / `MIAXIS_Android` / libFAP/src/main/cpp/include / ScanUltimateApi_err —— 差 1 行
  - `D:\git\oxi\g6\MIAXIS\MIAXIS_Android\libFAP\src\main\cpp\include\OXiScanUltimateApi_err.h`
- `huantian` / `huantian_win` / 根目录 / ScanUltimateApi_err —— 差 1 行
  - `D:\git\oxi\g6\huantian\huantian_win\ScanUltimateApi_err.h`
