
#!/usr/bin/env bash

set -e

PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

TOOLCHAIN_PATH="D:/toolchain/arm-gnu-toolchain-15.2.rel1-mingw-w64-i686-arm-none-eabi/bin"

echo "=========================================="
echo " STM32 CubeMX -> VS Code CMake Adapter"
echo " Project: ${PROJECT_DIR}"
echo "=========================================="

if [ ! -d "Core" ] || [ ! -d "Drivers" ]; then
    echo "Error: 当前目录不像 STM32CubeMX 工程，缺少 Core/ 或 Drivers/"
    exit 1
fi

if [ ! -d "cmake/stm32cubemx" ]; then
    echo "Error: 缺少 cmake/stm32cubemx/"
    echo "请确认 CubeMX 的 Toolchain / IDE 选择的是 CMake"
    exit 1
fi

LD_FILE="$(find . -maxdepth 2 -name "*.ld" | head -n 1)"
STARTUP_FILE="$(find . -maxdepth 2 -name "startup_*.s" | head -n 1)"

if [ -z "$LD_FILE" ]; then
    echo "Error: 没找到 .ld 链接脚本"
    exit 1
fi

if [ -z "$STARTUP_FILE" ]; then
    echo "Error: 没找到 startup_*.s 启动文件"
    exit 1
fi

STARTUP_BASE="$(basename "$STARTUP_FILE")"

echo "Project name: ${PROJECT_NAME}"
echo "Linker script: ${LD_FILE}"
echo "Startup file: ${STARTUP_FILE}"

MCU_FLAGS=""
MCU_DEFINE=""
OPENOCD_TARGET_CFG=""

case "$STARTUP_BASE" in
    *stm32f103xe*)
        MCU_FLAGS="-mcpu=cortex-m3 -mthumb -mfloat-abi=soft"
        MCU_DEFINE="STM32F103xE"
        OPENOCD_TARGET_CFG="target/stm32f1x.cfg"
        ;;
    *stm32f103xb*)
        MCU_FLAGS="-mcpu=cortex-m3 -mthumb -mfloat-abi=soft"
        MCU_DEFINE="STM32F103xB"
        OPENOCD_TARGET_CFG="target/stm32f1x.cfg"
        ;;
    *stm32f407xx*)
        MCU_FLAGS="-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard"
        MCU_DEFINE="STM32F407xx"
        OPENOCD_TARGET_CFG="target/stm32f4x.cfg"
        ;;
    *stm32g431xx*)
        MCU_FLAGS="-mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard"
        MCU_DEFINE="STM32G431xx"
        OPENOCD_TARGET_CFG="target/stm32g4x.cfg"
        ;;
    *)
        echo "Warning: 未识别启动文件 ${STARTUP_BASE}"
        echo "将使用 STM32F103xE 默认配置，请手动检查 cmake/device.cmake"
        MCU_FLAGS="-mcpu=cortex-m3 -mthumb -mfloat-abi=soft"
        MCU_DEFINE="STM32F103xE"
        OPENOCD_TARGET_CFG="target/stm32f1x.cfg"
        ;;
esac

mkdir -p cmake
mkdir -p .vscode

cat > cmake/arm-none-eabi-toolchain.cmake <<TOOLCHAIN_EOF
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(TOOLCHAIN_PATH "${TOOLCHAIN_PATH}")

set(CMAKE_C_COMPILER   "\${TOOLCHAIN_PATH}/arm-none-eabi-gcc.exe")
set(CMAKE_CXX_COMPILER "\${TOOLCHAIN_PATH}/arm-none-eabi-g++.exe")
set(CMAKE_ASM_COMPILER "\${TOOLCHAIN_PATH}/arm-none-eabi-gcc.exe")

set(CMAKE_OBJCOPY "\${TOOLCHAIN_PATH}/arm-none-eabi-objcopy.exe")
set(CMAKE_OBJDUMP "\${TOOLCHAIN_PATH}/arm-none-eabi-objdump.exe")
set(CMAKE_SIZE    "\${TOOLCHAIN_PATH}/arm-none-eabi-size.exe")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
TOOLCHAIN_EOF

cat > cmake/device.cmake <<DEVICE_EOF
set(STM32_MCU_FLAGS
    ${MCU_FLAGS}
)

set(STM32_DEFINES
    USE_HAL_DRIVER
    ${MCU_DEFINE}
)

set(STM32_LINKER_SCRIPT
    \${CMAKE_SOURCE_DIR}/${LD_FILE#./}
)

set(STM32_STARTUP_FILE
    \${CMAKE_SOURCE_DIR}/${STARTUP_FILE#./}
)

set(OPENOCD_INTERFACE_CFG
    interface/stlink.cfg
)

set(OPENOCD_TARGET_CFG
    ${OPENOCD_TARGET_CFG}
)
DEVICE_EOF

cat > cmake/stm32-common.cmake <<'COMMON_EOF'
function(stm32_configure_target TARGET_NAME)
    target_compile_options(${TARGET_NAME} PRIVATE
        ${STM32_MCU_FLAGS}
        -ffunction-sections
        -fdata-sections
        -Wall
    )

    target_compile_definitions(${TARGET_NAME} PRIVATE
        ${STM32_DEFINES}
    )

    target_link_options(${TARGET_NAME} PRIVATE
        ${STM32_MCU_FLAGS}
        -T${STM32_LINKER_SCRIPT}
        -Wl,-Map=${TARGET_NAME}.map
        -Wl,--gc-sections
        -Wl,--print-memory-usage
        --specs=nano.specs
        --specs=nosys.specs
    )

    set_target_properties(${TARGET_NAME} PROPERTIES
        SUFFIX ".elf"
    )

    add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
        COMMAND ${CMAKE_OBJCOPY} -O ihex
                $<TARGET_FILE:${TARGET_NAME}>
                ${TARGET_NAME}.hex

        COMMAND ${CMAKE_OBJCOPY} -O binary
                $<TARGET_FILE:${TARGET_NAME}>
                ${TARGET_NAME}.bin

        COMMAND ${CMAKE_SIZE}
                $<TARGET_FILE:${TARGET_NAME}>
    )
endfunction()

function(stm32_configure_library TARGET_NAME)
    target_compile_options(${TARGET_NAME} PUBLIC
        ${STM32_MCU_FLAGS}
        -ffunction-sections
        -fdata-sections
    )

    target_compile_definitions(${TARGET_NAME} PUBLIC
        ${STM32_DEFINES}
    )
endfunction()
COMMON_EOF

cat > CMakeLists.txt <<'CMAKE_EOF'
cmake_minimum_required(VERSION 3.20)

get_filename_component(PROJECT_NAME_FROM_DIR ${CMAKE_SOURCE_DIR} NAME)
project(${PROJECT_NAME_FROM_DIR} C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(cmake/device.cmake)
include(cmake/stm32-common.cmake)

# 必须先创建主目标。
# CubeMX 生成的 cmake/stm32cubemx/CMakeLists.txt 会向这个目标添加源文件、库和路径。
add_executable(${PROJECT_NAME})

# 用户自己的 App 层代码，可选。
file(GLOB_RECURSE APP_SOURCES CONFIGURE_DEPENDS
    App/Src/*.c
    App/Src/*.cpp
)

target_sources(${PROJECT_NAME} PRIVATE
    ${APP_SOURCES}
)

target_include_directories(${PROJECT_NAME} PRIVATE
    App/Inc
)

# CubeMX 生成的 CMake 配置。
add_subdirectory(cmake/stm32cubemx)

# CubeMX 生成的 HAL 驱动库也必须加 MCU 参数。
if(TARGET STM32_Drivers)
    stm32_configure_library(STM32_Drivers)
endif()

# 给最终 ELF 目标添加 MCU 参数、链接脚本、hex/bin 生成规则。
stm32_configure_target(${PROJECT_NAME})
CMAKE_EOF

cat > CMakePresets.json <<'PRESETS_EOF'
{
  "version": 3,
  "configurePresets": [
    {
      "name": "stm32-mingw",
      "displayName": "STM32 MinGW Makefiles",
      "generator": "MinGW Makefiles",
      "binaryDir": "${sourceDir}/build",
      "cacheVariables": {
        "CMAKE_TOOLCHAIN_FILE": "${sourceDir}/cmake/arm-none-eabi-toolchain.cmake"
      }
    }
  ],
  "buildPresets": [
    {
      "name": "stm32-build",
      "configurePreset": "stm32-mingw"
    }
  ]
}
PRESETS_EOF

cat > build.sh <<'BUILD_EOF'
#!/usr/bin/env bash

set -e

cmake --preset stm32-mingw
cmake --build --preset stm32-build -j
BUILD_EOF

cat > flash.sh <<FLASH_EOF
#!/usr/bin/env bash

set -e

openocd -f interface/stlink.cfg \\
        -f ${OPENOCD_TARGET_CFG} \\
        -c "adapter speed 100; program build/${PROJECT_NAME}.elf verify reset exit"
FLASH_EOF

cat > .vscode/tasks.json <<'TASKS_EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "STM32: Build",
      "type": "shell",
      "command": "./build.sh",
      "group": {
        "kind": "build",
        "isDefault": true
      },
      "problemMatcher": []
    },
    {
      "label": "STM32: Flash",
      "type": "shell",
      "command": "./flash.sh",
      "problemMatcher": []
    },
    {
      "label": "STM32: Build and Flash",
      "type": "shell",
      "command": "./build.sh && ./flash.sh",
      "problemMatcher": [],
      "dependsOrder": "sequence"
    },
    {
      "label": "STM32: Clean Build",
      "type": "shell",
      "command": "rm -rf build && ./build.sh",
      "problemMatcher": []
    }
  ]
}
TASKS_EOF

cat > .vscode/settings.json <<'SETTINGS_EOF'
{
  "cmake.configureOnOpen": false,
  "cmake.useCMakePresets": "always"
}
SETTINGS_EOF

printf '%s\n' \
'build/' \
'*.elf' \
'*.hex' \
'*.bin' \
'*.map' \
'*.list' \
'*.o' \
'*.obj' \
'.vscode/.browse.c_cpp.db*' \
> .gitignore

chmod +x build.sh
chmod +x flash.sh

echo "=========================================="
echo " Adaptation finished."
echo ""
echo " Generated:"
echo " - CMakeLists.txt"
echo " - CMakePresets.json"
echo " - cmake/arm-none-eabi-toolchain.cmake"
echo " - cmake/device.cmake"
echo " - cmake/stm32-common.cmake"
echo " - build.sh"
echo " - flash.sh"
echo " - .vscode/tasks.json"
echo " - .vscode/settings.json"
echo ""
echo " Next:"
echo "   ./build.sh"
echo "   ./flash.sh"
echo ""
echo " In VS Code:"
echo "   Terminal -> Run Task -> STM32: Build"
echo "   Terminal -> Run Task -> STM32: Flash"
echo "=========================================="