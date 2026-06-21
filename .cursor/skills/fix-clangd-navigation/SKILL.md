---
name: fix-clangd-navigation
description: >-
  Diagnoses and fixes clangd "Go to Definition" / code navigation failures in
  C/C++ projects, especially colcon/ROS2 CMake workspaces. Use when the user
  reports clangd cannot jump to definition, broken IntelliSense, unresolved
  headers in editor, compile_commands.json issues, or asks to fix Cursor/VSCode
  C++ navigation.
---

# 修复 clangd 代码跳转

## 核心原则

clangd 跳转依赖 **有效的 `compile_commands.json`**（编译数据库）。编辑器插件配置正确但数据库缺失、断链或过期时，跳转、补全、诊断都会失效。

**排查顺序**：先验证编译数据库 → 再验证 clangd 配置 → 最后验证单文件解析。

## 快速诊断清单

复制并逐项执行：

```
- [ ] 1. 确认 compile_commands.json 存在且非断链
- [ ] 2. 确认目标源文件出现在 compile_commands 中
- [ ] 3. 确认 clangd 扩展已启用，Microsoft C/C++ IntelliSense 已禁用
- [ ] 4. 确认 --compile-commands-dir 指向正确目录
- [ ] 5. 用 clangd --check 验证单文件可解析
- [ ] 6. 修复后执行 clangd: Restart language server
```

## 第一步：检查 compile_commands.json

### 1.1 定位文件

在工作区根目录查找：

```bash
# 是否存在（含符号链接）
ls -la compile_commands.json

# 各 build 目录下的实际文件
find build -name 'compile_commands.json' -type f 2>/dev/null
```

### 1.2 判断是否有效

| 现象 | 含义 |
|------|------|
| `compile_commands.json` 不存在 | 构建时未导出，需重新构建 |
| 符号链接指向的路径不存在（断链） | 链接目标包未构建或未开启导出 |
| 文件存在但行数极少（如 < 10） | 可能是空壳或错误路径 |
| 文件很旧，远早于最近 CMake 改动 | 可能过期，需 `--cmake-force-configure` 重建 |

验证断链：

```bash
test -e compile_commands.json && echo "OK" || echo "BROKEN or MISSING"
readlink -f compile_commands.json
```

### 1.3 确认目标文件在数据库中

```bash
grep -c '目标文件名.cpp' build/<package>/compile_commands.json
# 或
grep 'diversity_component' build/application/compile_commands.json | head -3
```

若 grep 无结果，说明该 `.cpp` 不在当前 compile_commands 覆盖范围内（见「跨包跳转」）。

## 第二步：检查编辑器 / clangd 配置

读取以下文件（按优先级）：

1. `.vscode/settings.json`（工作区）
2. `~/.config/Cursor/User/settings.json`（用户级，勿随意改）
3. `.clangd`（clangd 项目配置）
4. `.vscode/extensions.json`（推荐扩展）

### 2.1 扩展冲突（必查）

Microsoft **C/C++** 与 **clangd** 会争抢同一语言服务。正确做法：

```json
{
  "C_Cpp.intelliSenseEngine": "Disabled",
  "clangd.path": "/usr/bin/clangd"
}
```

确认已安装 `llvm-vs-code-extensions.vscode-clangd`：

```bash
cursor --list-extensions 2>/dev/null | grep clangd
```

### 2.2 compile-commands-dir 一致性

`.vscode/settings.json` 与 `.clangd` 必须指向**同一**编译数据库目录：

```json
// .vscode/settings.json
"clangd.arguments": [
  "--compile-commands-dir=${workspaceFolder}/build/<package>",
  "--background-index"
]
```

```yaml
# .clangd
CompileFlags:
  CompilationDatabase: build/<package>
```

**常见错误**：根目录有 `compile_commands.json` 符号链接，但 `clangd.arguments` 指向另一个不存在的 `build/<other>` 目录。

### 2.3 确认 clangd 可执行

```bash
which clangd && clangd --version | head -1
```

## 第三步：用 clangd --check 验证

在修复配置或重建后，**必须**用命令行验证（比编辑器更可靠）：

```bash
clangd --check=/path/to/source.cpp \
  --compile-commands-dir=/path/to/build/<package> 2>&1 | tail -30
```

期望结果：

- 末尾出现 `All checks passed` 或仅有少量无关 warning
- **不应**大量 `E[...]` 且伴随 `file not found`

若 `--check` 失败但 colcon build 成功，通常是 compile_commands 缺失/过期，而非代码本身有问题。

## 第四步：修复（colcon / ROS2 工作区）

### 4.1 标准修复：重新导出 compile_commands

```bash
cd <workspace_root>
source /opt/ros/$ROS2_DISTRO/setup.bash
source install/setup.bash 2>/dev/null

colcon build --packages-select <package> \
  --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  --cmake-force-configure
```

验证生成：

```bash
test -f build/<package>/compile_commands.json && wc -l build/<package>/compile_commands.json
grep -c '<target>.cpp' build/<package>/compile_commands.json
```

### 4.2 根目录符号链接

若工作区根目录使用符号链接（常见模式）：

```bash
ln -sf build/<package>/compile_commands.json compile_commands.json
```

修复后再次确认非断链。

### 4.3 重启 clangd

配置或 compile_commands 变更后，**必须**重启语言服务：

1. `Ctrl+Shift+P` → `clangd: Restart language server`
2. 等待 background-index 完成（右下角状态）
3. 再试 `F12` / `Ctrl+Click`

## 第五步：向用户报告

修复完成后，用以下结构汇报：

1. **根因**：一句话（如「compile_commands 断链，application 包未开启导出」）
2. **已执行操作**：重建命令、符号链接修复等
3. **验证结果**：`wc -l compile_commands.json`、`clangd --check` 摘要
4. **用户需做**：重启 clangd
5. **预防建议**：见下方

## 常见根因速查

| 症状 | 最可能原因 | 修复 |
|------|-----------|------|
| 所有 `.cpp` 都无法跳转 | compile_commands 缺失/断链 | 4.1 重建 |
| 头文件能跳、`.cpp` 不能跳 | compile_commands 只含部分包 | 合并多包或切换 package |
| 改 CMake 后突然失效 | compile_commands 过期 | `--cmake-force-configure` 重建 |
| 编辑器报 file not found 但 build 成功 | compile_commands 问题，非代码问题 | 先修数据库，勿改源码 |
| 跳转随机/补全重复 | C/C++ 与 clangd 冲突 | 禁用 IntelliSense |
| 仅个别符号跳不过去 | 宏生成代码、模板实例化、未索引完 | 等索引完成；查 `--check` |

## 预防（避免反复出现）

### 推荐：colcon 默认开启导出

写入 `~/.colcon/defaults.yaml`：

```yaml
build:
  cmake-args:
    - -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

### 工作区 build 脚本

若项目有 `scripts/build.sh`，检查 `colcon build` 是否包含 `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`；若无，建议用户加入（**仅当用户明确要求改脚本时**才修改）。

### .vscode/settings.json

已有 `cmake.configureSettings.CMAKE_EXPORT_COMPILE_COMMANDS: ON` 时，仅对 CMake Tools 扩展生效；**colcon 构建仍需显式传 cmake-args**。

## 进阶场景

跨包跳转、合并多个 compile_commands、CompilationDatabase 路径策略，见 [reference.md](reference.md)。

## 禁止事项

- 不要因 clangd 报 `file not found` 就修改正确的 `#include` 或业务代码
- 不要同时启用 C/C++ IntelliSense 与 clangd
- 不要在没有 compile_commands 的情况下仅靠 `clangd.fallbackFlags` 期望完整跳转
- 修复后不要忘记让用户重启 clangd
