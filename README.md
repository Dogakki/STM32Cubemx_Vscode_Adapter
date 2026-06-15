# STM32 CubeMX to VS Code CMake Adapter

这是一个用于将 **STM32CubeMX 生成的 CMake 工程** 自动适配为 **VS Code + CMake + OpenOCD + ST-Link** 开发环境的后处理脚本。

它适合这样的工作流：

```text
STM32CubeMX 配置芯片和外设
→ Generate Code
→ 运行适配脚本
→ VS Code 中编译 / 烧录
```

本项目不替代 STM32CubeMX，而是对 CubeMX 生成的 CMake 工程进行补充，使其更适合在 VS Code 和 MSYS2 环境中开发。

---

## 1. 功能特点

该适配器可以自动生成或补充以下文件：

```text
CMakeLists.txt
CMakePresets.json
cmake/arm-none-eabi-toolchain.cmake
cmake/device.cmake
cmake/stm32-common.cmake
build.sh
flash.sh
.vscode/tasks.json
.vscode/settings.json
.gitignore
```

主要解决以下问题：

```text
CMake 找不到 arm-none-eabi-gcc
HAL 编译时 dsb / isb / wfi / wfe 指令报错
链接时报 _estack / _sidata / _sdata 未定义
手动写 OpenOCD 烧录命令麻烦
VS Code 中不能直接 Build / Flash
CubeMX 重新生成代码后 CMake 配置容易丢失
```

---

## 2. 环境要求

当前方案基于 Windows + MSYS2 MINGW64 环境。

需要提前安装：

```text
MSYS2 MINGW64
CMake
mingw32-make
OpenOCD
Arm GNU Toolchain
STM32CubeMX
VS Code
ST-Link 驱动
```

建议在 MSYS2 MINGW64 中安装：

```bash
pacman -S --needed mingw-w64-x86_64-cmake
pacman -S --needed mingw-w64-x86_64-make
pacman -S --needed mingw-w64-x86_64-openocd
```

Arm GNU Toolchain 示例路径：

```text
D:/toolchain/arm-gnu-toolchain-15.2.rel1-mingw-w64-i686-arm-none-eabi/bin
```

如果你的工具链路径不同，需要修改 `apply_stm32_vscode.sh` 中的：

```bash
TOOLCHAIN_PATH="D:/toolchain/arm-gnu-toolchain-15.2.rel1-mingw-w64-i686-arm-none-eabi/bin"
```

---

## 3. CubeMX 工程生成要求

在 STM32CubeMX 中生成工程时，建议这样设置：

```text
Project Manager
→ Toolchain / IDE
→ CMake
```

生成后的工程目录中应包含：

```text
Core/
Drivers/
cmake/stm32cubemx/
startup_xxx.s
xxx_FLASH.ld
xxx.ioc
```

其中：

```text
Core/ 和 Drivers/ 由 CubeMX 管理
cmake/stm32cubemx/ 由 CubeMX 生成
startup_xxx.s 是启动文件
xxx_FLASH.ld 是链接脚本
```

---

## 4. 安装适配器

建议将适配器放在固定目录：

```text
D:/Emb.dev/stm32-cmake-adapter/
```

在 MSYS2 MINGW64 中执行：

```bash
mkdir -p /d/Emb.dev/stm32-cmake-adapter
cd /d/Emb.dev/stm32-cmake-adapter
```

将 `apply_stm32_vscode.sh` 放入该目录，然后赋予执行权限：

```bash
chmod +x /d/Emb.dev/stm32-cmake-adapter/apply_stm32_vscode.sh
```

---

## 5. 使用方法

假设 CubeMX 生成的新工程路径为：

```text
D:/Emb.dev/My_STM32_Project/
```

进入工程根目录：

```bash
cd /d/Emb.dev/My_STM32_Project
```

运行适配脚本：

```bash
/d/Emb.dev/stm32-cmake-adapter/apply_stm32_vscode.sh
```

编译：

```bash
./build.sh
```

烧录：

```bash
./flash.sh
```

或者打开 VS Code：

```bash
code .
```

在 VS Code 中使用：

```text
Terminal → Run Task → STM32: Build
Terminal → Run Task → STM32: Flash
Terminal → Run Task → STM32: Build and Flash
```

---

## 6. 适配后的工程结构

运行脚本后，工程结构大致如下：

```text
My_STM32_Project/
├── Core/
├── Drivers/
├── cmake/
│   ├── stm32cubemx/
│   ├── arm-none-eabi-toolchain.cmake
│   ├── device.cmake
│   └── stm32-common.cmake
├── .vscode/
│   ├── tasks.json
│   └── settings.json
├── CMakeLists.txt
├── CMakePresets.json
├── build.sh
├── flash.sh
├── startup_xxx.s
├── xxx_FLASH.ld
├── My_STM32_Project.ioc
└── .gitignore
```

其中：

```text
CubeMX 管理：
Core/
Drivers/
cmake/stm32cubemx/
startup_xxx.s
xxx_FLASH.ld

适配器管理：
CMakeLists.txt
CMakePresets.json
cmake/arm-none-eabi-toolchain.cmake
cmake/device.cmake
cmake/stm32-common.cmake
build.sh
flash.sh
.vscode/tasks.json
.vscode/settings.json
.gitignore
```

---

## 7. 推荐开发习惯

建议将用户业务代码放在单独的 `App/` 目录中，避免 CubeMX 重新生成代码时覆盖自己的逻辑。

推荐结构：

```text
App/
├── Inc/
│   └── app.h
└── Src/
    └── app.c
```

适配器生成的 `CMakeLists.txt` 已经自动包含：

```text
App/Src/*.c
App/Src/*.cpp
App/Inc
```

在 `Core/Src/main.c` 中，只在 CubeMX 的用户代码区加入调用。

示例：

```c
/* USER CODE BEGIN Includes */
#include "app.h"
/* USER CODE END Includes */
```

初始化部分：

```c
/* USER CODE BEGIN 2 */
App_Init();
/* USER CODE END 2 */
```

主循环部分：

```c
while (1)
{
    App_Loop();

    /* USER CODE BEGIN 3 */
}
```

这样 CubeMX 重新生成代码后，主要业务逻辑不会被覆盖。

---

## 8. 支持的芯片配置

当前脚本已内置以下识别规则：

```text
startup_stm32f103xe.s → STM32F103xE / Cortex-M3 / stm32f1x.cfg
startup_stm32f103xb.s → STM32F103xB / Cortex-M3 / stm32f1x.cfg
startup_stm32f407xx.s → STM32F407xx / Cortex-M4F / stm32f4x.cfg
startup_stm32g431xx.s → STM32G431xx / Cortex-M4F / stm32g4x.cfg
```

对于 STM32F103ZET6，生成的 MCU 参数为：

```cmake
set(STM32_MCU_FLAGS
    -mcpu=cortex-m3
    -mthumb
    -mfloat-abi=soft
)

set(STM32_DEFINES
    USE_HAL_DRIVER
    STM32F103xE
)
```

对应 OpenOCD 目标配置：

```text
target/stm32f1x.cfg
```

如果使用其他芯片，需要在 `apply_stm32_vscode.sh` 的 `case "$STARTUP_BASE"` 部分中增加对应规则。

---

## 9. 编译与烧录命令

编译：

```bash
./build.sh
```

烧录：

```bash
./flash.sh
```

`flash.sh` 默认使用 ST-Link：

```bash
openocd -f interface/stlink.cfg \
        -f target/stm32f1x.cfg \
        -c "adapter speed 100; program build/工程名.elf verify reset exit"
```

如果使用其他调试器，例如 CMSIS-DAP，需要修改 `flash.sh`：

```bash
openocd -f interface/cmsis-dap.cfg \
        -f target/stm32f1x.cfg \
        -c "adapter speed 100; program build/工程名.elf verify reset exit"
```

---

## 10. 常见问题

### 10.1 CMake 找不到编译器

典型错误：

```text
No CMAKE_C_COMPILER could be found
No CMAKE_CXX_COMPILER could be found
```

检查：

```bash
which cmake
which arm-none-eabi-gcc
```

确认 `cmake/arm-none-eabi-toolchain.cmake` 中的工具链路径正确。

---

### 10.2 HAL 编译时报 dsb / isb / wfi / wfe 错误

典型错误：

```text
selected processor does not support `dsb 0xF' in ARM mode
selected processor does not support `wfi' in ARM mode
```

原因是 HAL 驱动库没有拿到 MCU 编译参数。

最终方案中需要保证 `CMakeLists.txt` 中存在：

```cmake
if(TARGET STM32_Drivers)
    stm32_configure_library(STM32_Drivers)
endif()
```

并且它必须位于：

```cmake
add_subdirectory(cmake/stm32cubemx)
```

之后。

---

### 10.3 链接时报 _estack / _sidata 未定义

典型错误：

```text
undefined reference to `_estack'
undefined reference to `_sidata'
undefined reference to `_sdata'
undefined reference to `_sbss'
undefined reference to `_ebss'
```

原因是没有正确传入 `.ld` 链接脚本。

检查：

```bash
find . -name "*.ld"
```

确认 `cmake/device.cmake` 中的路径正确：

```cmake
set(STM32_LINKER_SCRIPT
    ${CMAKE_SOURCE_DIR}/xxx_FLASH.ld
)
```

---

### 10.4 OpenOCD 找不到 ELF 文件

典型错误：

```text
couldn't open build/工程名.elf
```

原因通常是执行烧录命令时所在目录不对。

建议统一从工程根目录执行：

```bash
./flash.sh
```

不要在 `build/` 目录中执行 `program build/xxx.elf`。

---

### 10.5 OpenOCD 无法打开 ST-Link

典型错误：

```text
Error: open failed
```

检查：

```text
ST-Link 是否被设备管理器识别
ST-Link 驱动是否正常
STM32CubeProgrammer 是否占用了 ST-Link
ST-Link 与目标板是否共地
目标板是否有 3.3V 供电
SWDIO / SWCLK 是否接反
```

测试 OpenOCD 是否能连接：

```bash
openocd -f interface/stlink.cfg -f target/stm32f1x.cfg
```

成功时应看到类似：

```text
Info : STLINK V2J...
Info : Target voltage: ...
Info : Cortex-M3 processor detected
Info : Listening on port 3333 for gdb connections
```

---

## 11. 重新生成 CubeMX 代码后的处理

如果在 CubeMX 中修改了外设、时钟或引脚，并重新 Generate Code，建议重新运行适配脚本：

```bash
cd /d/Emb.dev/My_STM32_Project
/d/Emb.dev/stm32-cmake-adapter/apply_stm32_vscode.sh
```

然后重新编译：

```bash
./build.sh
```

烧录：

```bash
./flash.sh
```

---

## 12. 设计思想

该适配器遵循以下分工：

```text
CubeMX：
负责芯片初始化、外设配置、HAL 驱动、启动文件、链接脚本

CMake Adapter：
负责工具链、MCU 编译参数、链接参数、构建产物、VS Code 任务、OpenOCD 烧录

App 层：
负责用户业务逻辑、控制算法、驱动封装、应用代码
```

最终目标是形成稳定流程：

```text
CubeMX Generate Code
→ apply_stm32_vscode.sh
→ ./build.sh
→ ./flash.sh
```

避免每个新工程都重复手动配置 CMake、链接脚本和 OpenOCD。

---

## 13. 推荐版本管理

建议提交到 Git 的文件：

```text
Core/
Drivers/
cmake/
.vscode/tasks.json
.vscode/settings.json
CMakeLists.txt
CMakePresets.json
build.sh
flash.sh
*.ioc
*.ld
startup_*.s
App/
```

建议忽略：

```text
build/
*.elf
*.hex
*.bin
*.map
*.list
*.o
*.obj
```

---

## 14. 快速命令备忘

新工程适配：

```bash
cd /d/Emb.dev/工程名
/d/Emb.dev/stm32-cmake-adapter/apply_stm32_vscode.sh
```

编译：

```bash
./build.sh
```

烧录：

```bash
./flash.sh
```

VS Code 打开：

```bash
code .
```

OpenOCD 手动连接测试：

```bash
openocd -f interface/stlink.cfg -f target/stm32f1x.cfg
```

手动烧录：

```bash
openocd -f interface/stlink.cfg \
        -f target/stm32f1x.cfg \
        -c "adapter speed 100; program build/工程名.elf verify reset exit"
```

---

## 15. 当前状态

当前方案已在以下环境中验证：

```text
Windows
MSYS2 MINGW64
Arm GNU Toolchain 15.2.Rel1
OpenOCD 0.12.0
ST-Link V2
STM32F103ZET6 / STM32F103xE
STM32CubeMX CMake 工程
VS Code
```
