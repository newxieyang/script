# G6010 驱动层在四个项目中的差异清单

> 数据来源：`D:/git/oxi/g6/{A910/A910, MIAXIS/MIAXIS, Thales/Thales, huantian/huantian}` 四个
> `libFAP` submodule 的**实际 checkout**（不是远端分支），只读扫描，未修改任何文件。
> 生成：2026-10-09

---

## 0. 一句话结论

`G6010` 是 libFAP 里的 **USB 设备驱动类**（`libFAP/include/G6010.h` + `libFAP/src/G6010.cpp`），
四个项目各有一份**互不相同的实现**：`A910`（1268 行）是功能最全的定制版，`MIAXIS`（1147 行）是
被抽干的通用版，`Thales`（415 行）已把传输层抽成 `UsbTransport` 只留壳，`huantian`（850 行）
是**上一代 API 代**（错误码 `SCANNER_*`、MCU 结构体无 `OXi_` 前缀）。

**关键结论：`open()` 被标为"4 个都不一样"，但实际只有 3 套逻辑** ——
A910 是定制版（按 SN 匹配 + 多设备限流 + Android 10 兼容），
MIAXIS 与 huantian **逐行同构、只差错误码词汇表**（同一套逻辑的两份拷贝），
Thales 是**推倒重写的精简版**（30 行，丢掉了若干防御性处理，见 4.1）。
剩下真正各自演化的，是 flash 系列和错误码体系。

---

## 1. 规模与整体差异量

| 项目 | libFAP 分支 | G6010.h | G6010.cpp | 私有成员模型 |
|---|---|---|---|---|
| A910 | `aratek` | 137 行 | **1268 行** | 自带 `flashBuff` + 静态 `s_openCount` |
| MIAXIS | `miaxis0317` | 143 行 | 1147 行 | `usb_fd`，含私有 `eraseFlashCommon` |
| Thales | `OXi` | 112 行 | **415 行** | 只有一个 `UsbTransport _transport` |
| huantian | `new` | 129 行 | 850 行 | `usb_fd` |

两两差异（`diff` 出的 `<`/`>` 行数，越大越不同）：

| | A910 | MIAXIS | Thales | huantian |
|---|---|---|---|---|
| **A910** | — | cpp **1635** / h 98 | cpp 1033 / h 109 | cpp 1562 / h 94 |
| **MIAXIS** | | — | cpp 1104 / h 101 | cpp **849** / h 108 |
| **Thales** | | | — | cpp 855 / h 87 |
| **huantian** | | | | — |

> `MIAXIS ↔ huantian` 是最近的一对（cpp 仅 849 行差异），`A910 ↔ MIAXIS` 最远（1635 行）。
> `Thales` 跟谁都远，但那是**重构造成的远**（代码被搬进 `UsbTransport.cpp`），不是功能多。

**另外：`shenzhen/oxiscansdk`（GSER）里完全没有 G6010**——它走另一套 `base/export/OXiScan_Api.h`
布局，不在本次对比范围内。

---

## 2. `G6010.h` 差异

### 2.1 依赖、宏、类型

| 项 | A910 | MIAXIS | Thales | huantian |
|---|---|---|---|---|
| 引入的对外头 | `"OXiScanAPI.h"` | `"OXiScanAPI.h"` | `"UsbTransport.h"`<br>`"ScanUltimate.h"` | `"ScanUltimate.h"` |
| 其它 include | `<G6Default.h>`, `<map>`, `<vector>` | — | — | — |
| `usb_target` / `usb_request` 枚举 | ✗ | ✓ 本文件定义 | ✓（在 `UsbTransport.h`） | ✓ 本文件定义 |
| `usb_direction` | 2 值 | 2 值 | ✓（在 `UsbTransport.h`） | **4 值**（多 `USB_DIR_HOST_TO_MCU=0x40` / `USB_DIR_MCU_TO_HOST=0xC0`） |
| `MAX_TRANS_LEN`（`_WIN32` 分支） | **0x8000** | 0x10000 | 0x10000 | 0x10000 |
| `DELAY_TIME_RESET` | 由 `3rd/libUtils/G6Default.h` 提供 | 由 `OXiScanAPI.h` 提供 | 本文件定义 50/100 | 本文件定义 50/100 |
| `EPIN` / `EPOUT` | 外部 `G6Default.h` → `0x86` / `0x02` | 同左 | **本文件定义 `0x81` / `0x02`** | 同 A910 → `0x86` / `0x02` |

> `MAX_TRANS_LEN` 在 Windows 下 A910 是 **0x8000（32 KB）**，其余三个是 **0x10000（64 KB）**。
> 这是 `bulkTransfer` 单次传输上限，是会真实影响行为的一处硬差异。

### 2.2 类接口清单（✗ = 该成员不存在）

| 方法 | A910 | MIAXIS | Thales | huantian |
|---|---|---|---|---|
| `G6010()` 构造 | **保留 1 MB `flashBuff`**<br>`resize(IMG_SIZE_FULL+418)` | 空 | 空 | 空 |
| `open(...)` | **`open(OXi_DevInfo)`** | `open(vid,pid,usbSN,fd)` | 同 MIAXIS（委托 `_transport`） | 同 MIAXIS |
| `openWithSerialNumber()` | ✗ | ✗ | ✗ | **✓ 独有** |
| `isOpen()` / `disconnected()` | 头内联（查 `_handle`/`_disconnected`） | **cpp 实现** | 头内联（委托 `_transport`） | **cpp 实现** |
| `close()` | ✓（含 `s_openCount--`） | ✓ | 头内联委托 | ✓ |
| `flashControl` / `flashControlFrom` | ✓ | ✓（`long buffLen`） | ✓ | ✓（`long buffLen`） |
| `bulkTransfer` | ✓（默认 `timeout=5000`） | ✓（**无默认值**） | 头内联委托（默认 5000） | ✓（默认 5000） |
| `controlTransfer` | 1 个签名 | 加 `target_type`/`req_type` | **2 个重载**（均内联委托） | 1 个签名 |
| `listDevices` | **✓ 独有** | ✗ | ✗ | ✗ |
| `SpiSwitch` | ✓ | ✓ | ✓ | ✓ |
| `SendRecvMCU` | ✓ `OXi_MCU_TransferData*` | ✓ `OXi_MCU_TransferData*` | ✗ | ✓ **`MCU_TransferData*`** |
| `SetLed` | ✓ | ✓ | ✓ | **✗ 缺失** |
| `setBeep` | ✓ | ✓ | ✓ | **✗ 缺失** |
| `queryTouch` | ✓ | ✓ | ✗ | ✗ |
| `MCUCtl` | ✗ | ✗ | ✗ | **✓ 独有** |
| `flashReadImage` / `getCompressGainSize` / `flashRead` | ✓ | ✓ | ✓ | ✓ |
| 写 flash | `flashwrite_new`<br>`flashwrite_FW` | `flashWrite` / `flashWriteNew`<br>`flashWriteFW` | ✗ | ✗ |
| 擦 flash | `_drv_flash_erase`<br>`_drv_flash_erase_img` | `flashErase` / `flashEraseImg`<br>+ 私有 `eraseFlashCommon` | ✗ | ✗ |
| 使能 flash | `enable_flash` | `flashEnable` | ✗ | ✗ |
| 复位 | `reset_sensor` | `resetSensor` | `resetSensor` | `reset_sensor` |

> **命名风格分裂**：A910 用蛇形（`flashwrite_new`、`_drv_flash_erase`、`reset_sensor`），
> MIAXIS 用驼峰（`flashWriteNew`、`flashErase`、`resetSensor`），Thales 跟驼峰，huantian 又回蛇形。
> 同一个类里连"复位设备"都有两个拼法。

---

## 3. `G6010.cpp` 函数级矩阵

`S` = 实现完全相同（已忽略注释与空白差异）　`D` = 实现不同　`-` = 不存在

| 函数 | A910 | MIAXIS | Thales | huantian | 实现版本数 |
|---|---|---|---|---|---|
| `open` | D | D | D | D | **4** |
| `flashRead` | D | D | D | D | **4** |
| `SpiSwitch` | S | S | D | D | 3 |
| `flashControl` / `flashControlFrom` | S | D | S | D | 3 |
| `flashReadImage` | S | D | D | S | 3 |
| `getCompressGainSize` | D | S | S | D | 3 |
| `setBeep` | D | D | D | - | 3 |
| `controlTransfer` | D | D | - | D | 3 |
| `SendRecvMCU` | S | S | - | D | 2 |
| `SetLed` | S | S | D | - | 2 |
| `bulkTransfer` | S | D | - | S | 2 |
| `close` | D | S | - | S | 2 |
| `resetSensor` | - | D | D | - | 2 |
| `reset_sensor` | D | - | - | D | 2 |
| `G6010()` | D | S | S | S | 2 |
| `queryTouch` | S | S | - | - | 1 |
| `_drv_flash_erase` / `_drv_flash_erase_img` / `enable_flash` / `listDevices` | S | - | - | - | 1（A910 独有） |
| `flashwrite_FW` / `flashwrite_new` | S | - | - | - | 1（A910 独有） |
| `eraseFlashCommon` / `flashWrite*` / `flashErase*` / `flashEnable` | - | S | - | - | 1（MIAXIS 独有） |
| `openWithSerialNumber` / `MCUCtl` | - | - | - | S | 1（huantian 独有） |

---

## 4. 关键行为差异（逐项）

### 4.1 `open()` —— 4 份代码，3 套逻辑

| | 打开策略 | 特殊处理 |
|---|---|---|
| **A910**<br>（定制版） | `open(OXi_DevInfo)`：自行 `libusb_get_device_list` 遍历，**VID+PID 先筛、再逐个开句柄比序列号** | ★ 同 VID/PID **最多开 2 个**（静态 `s_openCount`，超了直接 `OXI_ERR_INIT`）<br>★ Android 10 专门重试：`wrap_sys_device` 失败 sleep 200 ms 重试一次；`isAndroid10()` 再 `reset_device` + 300/400 ms 延时<br>★ Android weak-authority：`libusb_set_option(nullptr, LIBUSB_OPTION_WEAK_AUTHORITY)`<br>★ `clear_halt(EPIN/EPOUT)`<br>★ `close()` 里 `s_openCount--` |
| **MIAXIS**<br>（通用版） | `open(vid,pid,usbSN,fd)`：`libusb_open_device_with_vid_pid` 一发命中 | `usbSN` 反向回填给调用方；Android 分支 `dup(fd)` 存 `usb_fd`；`clear_halt` 清 4 个端点；`isOpen()` 早退 |
| **huantian**<br>（同构拷贝） | 与 MIAXIS **逐行同构** | 唯一差别是错误码词汇表（`OXI_ERR_INIT` → `SCANNER_ERROR_NO_DEVICE`）与多一句注释 |
| **Thales**<br>（重写版） | 30 行精简实现：`fd>0` 走 `wrap_sys_device`，否则 `open_device_with_vid_pid`；错误码直接用裸 `-1/-2/-3/-4` | **丢掉了**：`libusb_set_option(WEAK_AUTHORITY)`、`usbSN` 回填、`clear_halt`、`isOpen()` 早退 |

> **Thales 的重写是本次对比里风险最高的一处**：`UsbTransport::open` 只有 30 行，
> 用 `-1/-2/-3/-4` 当返回码（与全库 `OXI_*` 体系脱节），且不再 `clear_halt` 端点。
> Android 下还需确认 weak-authority 是否在别处补上——`UsbTransport.cpp` 里没有。

### 4.2 `flashRead()` —— 4 份，差在内存管理

| 项目 | 缓冲区策略 | 传参 |
|---|---|---|
| A910 | **复用成员 `flashBuff`**（构造时 `resize(IMG_SIZE_FULL+418)`，全程零分配） | `bulkTransfer(EPOUT, buf, 12)`（吃默认 timeout） |
| MIAXIS | 每次 `new uint8_t[should_transfer_size]` + 显式 `delete[]`（3 处释放点） | 显式传 `5000` |
| Thales | 同 MIAXIS（`new[]`） | `bulkTransfer(EPOUT, ..., 12, 5000)` |
| huantian | 同 MIAXIS 系 | 同 MIAXIS |

> A910 的"预分配"是为了避免大图（16 MB 级）反复分配——**MIAXIS/huantian/Thales 都没有这个优化**。
> 反过来 A910 是把整个 4.8 MB（`IMG_SIZE_FULL`）常驻在对象里，一个进程开 2 个设备就是 ~10 MB 常驻。

### 4.3 错误码词汇表 —— 实际是两套

| 项目 | 主用词 | 例 |
|---|---|---|
| A910 / MIAXIS / Thales | `OXi_STATUS_OK` + `OXI_ERR_*` + `OXI_LIBUSB_*` | `OXI_ERR_NOT_OPEN`、`OXI_LIBUSB_SPI_SWITCH` |
| **huantian** | `SCANNER_SUCCESS` + `SCANNER_ERROR_*` | `SCANNER_ERROR_NO_DEVICE`、`SCANNER_ERROR_DEVICE_NOT_OPEN` |

> huantian 的 `G6010.cpp` 里同时**混用**两套：17 次 `SCANNER_SUCCESS` 与 4 次 `OXI_LIBUSB_WRITE_ERR` 并存。
> 这是上一代错误码迁移到一半的痕迹。

### 4.4 `SendRecvMCU` 的数据结构

`A910`/`MIAXIS` 用 `OXi_MCU_TransferData`（定义在 `OXiScanUltimate.h:102`），
`huantian` 用 `MCU_TransferData`（定义在 `ScanUltimate.h:108`）——
**字段名、顺序、类型逐个核对完全一致**（`proj` / `pack_len` / `pack_data[64]` / `cmd_rsp_delay` / `data_len` / `data[64]` / `data_in` / `data_out` …），
只是 **typedef 名和宿主头文件不同**。ABI 上等价，源码上不兼容。

### 4.5 ★ 端点宏 `EPIN` / `EPOUT` 的隐藏重定义（值得优先处理）

- A910 / MIAXIS / huantian 从共享头 `D:/git/3rd/libUtils/include/G6Default.h` 取：
  ```c
  #define EPIN   0x86
  #define EPOUT  0x02 // Address of endpoint assuming the OUT direction
  ```
  该文件**没有 `#ifndef` 保护**（整体是 `#if 1 ... #endif`）。
- Thales 在自己的 `G6010.h:49-50` 又定义了一次：
  ```c
  #define EPOUT   (2 | LIBUSB_ENDPOINT_OUT)   // = 0x02
  #define EPIN    (1 | LIBUSB_ENDPOINT_IN)    // = 0x81  ← 与 0x86 不同
  ```
  而 `G6010.cpp` 的顺序是 **先 `#include "G6010.h"`（第 1 行）再 `#include "G6Default.h"`（第 7 行）**。

**后果**：Thales 里 `EPIN` 的最终取值**取决于包含顺序**——只要 `G6Default.h` 后到就变成 0x86（伴随宏重定义告警）。
同一个宏在两个值之间摇摆，而 `EPIN` 是读图的端点。这属于必查项，建议统一由一处定义并加保护宏。

### 4.6 项目内残留的不一致（顺手发现）

- **MIAXIS 自己也没统一**：`G6010` 用 `resetSensor`，而同仓库的 `FPScan.h:118` 仍是 `reset_sensor(int delay = DELAY_TIME_RESET)`——同一个库里两个类两套命名。
- **Thales `G6010.cpp` 里有一行损坏的中文注释**：第 164 行 `// ��ԭ`（编码损坏，原文应是"还原"之类）。
- **Thales 的 `G6010.h` 有两个 `#pragma once`**（第 1 行与第 52 行，后者夹在中间），无害但说明是拼接产物。
- huantian 的 `G6010.cpp` 依赖 `OXiScan_err.h`，Thales 依赖 `ScanUltimateApi_err.h`，A910/MIAXIS 依赖 `OXiScanAPI.h` 传递进来的 `OXiScanUltimateApi_err.h`——**错误码头文件的引入路径四家全不一样**。

---

## 5. 四个项目的 G6010 画像

| | 定位 | 特征 |
|---|---|---|
| **A910** `aratek` | **功能最全的定制版** | 唯一有 `listDevices` / `queryTouch` / `open(OXi_DevInfo)` / 多设备限流 / Android 10 兼容 / `flashBuff` 零分配 / 蛇形命名 + `MAX_TRANS_LEN=0x8000` |
| **MIAXIS** `miaxis0317` | **被抽干的"通用版"** | 驼峰命名、`flashWrite/Erase` 拆成 4 个公开方法 + 1 个私有 `eraseFlashCommon`、`usb_fd`；提交信息叫"统一函数名" |
| **Thales** `OXi` | **重构试点版（未回灌）** | 传输层抽到 `UsbTransport`（99 行），`G6010` 退化成薄壳（415 行）。但 `UsbTransport::open` 是**另写的精简版**，丢了 weak-authority / SN 回填 / `clear_halt`；并引入 `EPIN/EPOUT` 重定义与一行损坏的中文注释 |
| **huantian** `new` | **上一代 API 代** | `SCANNER_*` 错误码、`MCU_TransferData`（无 `OXi_` 前缀）、`openWithSerialNumber`/`MCUCtl` 独有、**缺 `SetLed`/`setBeep`**、`ScanAPI.h`/`ScanUltimate.h` 老命名 |

---

## 6. 风险清单

| # | 风险 | 影响 | 建议 |
|---|---|---|---|
| **1** | **Thales `UsbTransport::open` 是另写的精简版**：无 `libusb_set_option(WEAK_AUTHORITY)`、无 `usbSN` 回填、无 `clear_halt`、返回裸 `-1/-2/-3/-4` | Android 高版本可能拿不到设备权限；端点残留 halt 状态；调用方按 `OXI_*` 判断返回值会全部落空 | **优先**：对比 MIAXIS 版逐条补齐，或直接改成 MIAXIS 版 |
| 2 | `EPIN` 在 Thales 存在 `0x81` / `0x86` 双定义，无保护宏 | 端点位可能随包含顺序变化 → 读图失败 | 统一到一处 + `#ifndef` 保护 |
| 3 | `MAX_TRANS_LEN` A910 为 `0x8000`，其余 `0x10000` | 单次 USB 传输量差 2 倍 | 确认是有意为之还是漏改 |
| 4 | huantian 缺 `SetLed` / `setBeep` | 该机型无灯/蜂鸣能力（若非产品要求则是漏实现） | 与产品确认 |
| 5 | huantian 错误码两套混用 | 上层判断返回值时可能漏分支 | 归一到单套词汇表 |
| 6 | Thales `G6010.cpp:164` 有一行编码损坏的中文注释 `// ��ԭ` | 无害，但说明该文件经历过非 UTF-8 编辑 | 顺手重写这行注释 |
| 7 | `_drv_flash_erase` / `flashErase` 命名分裂 | 跨项目复用代码时编译期失败（同名不同拼写 → 链接错误） | 若走统一路线，先统一类内命名 |
| 8 | 比对工具按名字前缀匹配的脆弱性（上一轮的 `apiDiff.py` 在 `mantra` 分支漏过 `OXi_`） | 会静默漏项 | 按"签名集合"而非名字前缀判定 |

---

## 7. 与"版本化"的关系

`G6010` 的差异**与对外 API 头的差异不是一回事**，别合并处理：

- `ScanAPI.h` / `OXiScanAPI.h` 那批是**对外契约**，差异必须靠"版本线 + tag"冻结（老客户要保 ABI）。
- `G6010` 是**内部驱动实现**，不对外暴露，理论上完全可以统一成一份 + 编译期开关。
  当前的四份分叉里，只有 A910 的多设备限流、Android 10 兼容、`flashBuff` 复用这三项是**真实功能增量**，
  其余大部分是命名风格和错误码词汇表的无意义漂移。
  要注意的是 **Thales 的 `UsbTransport` 重构方向是对的，但目前是"减法"**（丢了三项 Android/端点处理），
  不能直接拿它当基线。

**建议的合并顺序**（成本从低到高）：
1. 统一命名（`flashWrite*` / `resetSensor` 驼峰版）+ 统一错误码（`OXI_*` 一套）——纯机械改写，零行为变化。
2. 统一 `MCU_TransferData` 的 typedef 名与宿主头。
3. 修 `EPIN/EPOUT` 双定义。
4. 以 **MIAXIS 版 `open()`** 为基线抽 `UsbTransport`（不是 Thales 版），把 Thales 缺的三项补回。
5. 把 A910 的三项增量（多设备限流、Android 10 兼容、`flashBuff` 复用）做成 `#if` 开关回灌主干。

---

*报告由只读静态分析生成：函数体比对已忽略注释与空白；`S` 判定基于归一化后逐字节相同。*
