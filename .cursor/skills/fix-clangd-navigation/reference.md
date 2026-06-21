# clangd 跳转修复 — 进阶参考

## 跨包跳转

单个包的 `compile_commands.json` 只包含该包内 `.cpp` 的编译命令。

典型工作区布局：

```
compile_commands.json -> build/application/compile_commands.json
src/application/   ← 可跳转 .cpp
src/framework/     ← 若不在 application 的 compile_commands 中，.cpp 无法跳转
install/include/   ← 头文件通常可跳转（通过 -I 路径）
```

**现象**：跳转到 install 头文件正常；跳转到 `src/framework/*.cpp` 失败。

**方案 A — 切换 compile-commands-dir**（简单，单包开发）

编辑 `.vscode/settings.json` 和 `.clangd`，将目录改为当前主要开发的包：

```json
"--compile-commands-dir=${workspaceFolder}/build/framework"
```

并为该包重建 compile_commands。

**方案 B — 合并多个 compile_commands**（多包同时开发）

```bash
# 需要 jq
jq -s 'add' \
  build/application/compile_commands.json \
  build/framework/compile_commands.json \
  > build/merged_compile_commands.json

ln -sf build/merged_compile_commands.json compile_commands.json
```

然后将 `--compile-commands-dir` 指向 `build`（含 merged 文件）或直接使用根目录 symlink。

**方案 C — 使用 compdb 工具**

```bash
# pip install compiledb  或  npm install -g compdb
compdb -p build/application list > /dev/null  # 验证
```

## compile_commands 条目结构

每条记录形如：

```json
{
  "directory": "/home/user/workspace/build/application",
  "command": "g++ ... -I/home/user/workspace/install/framework/include ... -c .../diversity_component.cpp",
  "file": "/home/user/workspace/src/application/src/application/diversity/diversity_component.cpp"
}
```

clangd 用 `file` 匹配当前打开文件，用 `command` 中的 `-I`、`-D`、`-std=` 解析符号。

排查「单文件不跳转」时，确认 `file` 路径与编辑器中打开的**绝对路径**一致（符号链接、bind mount 可能导致路径不匹配）。

## .clangd 常用补充配置

```yaml
CompileFlags:
  CompilationDatabase: build/application
  Add:
    - -Wno-unknown-warning-option

Index:
  Background: Build

Diagnostics:
  UnusedIncludes: None   # 若与项目 -Werror 策略冲突可关闭
```

`CompilationDatabase` 相对路径基于**工作区根目录**（含 `.clangd` 的目录）。

## clangd 日志

`.vscode/settings.json` 中 `"--log=verbose"` 时，查看输出面板 → **clangd** channel，搜索：

- `Loaded compilation database` — 确认加载路径
- `Could not find` — 数据库或条目缺失
- `indexing` — 后台索引进度

## CMake / colcon 细节

### CMAKE_EXPORT_COMPILE_COMMANDS

- 必须在 **cmake configure 阶段**生效
- 已有 build 目录但未导出时，需要 `--cmake-force-configure`
- 仅 `cmake.build` 而不 reconfigure 可能不会生成

### 与 BUILD_TEST 共存

```bash
colcon build --packages-select application \
  --cmake-args -DBUILD_TEST=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  --cmake-force-configure
```

### 检查 CMakeCache

```bash
grep CMAKE_EXPORT_COMPILE_COMMANDS build/<package>/CMakeCache.txt
# 期望: CMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON
```

## 非 colcon 项目（简要）

| 构建系统 | 生成 compile_commands |
|---------|----------------------|
| 纯 CMake | `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..` |
| Bear | `bear -- make` |
| compiledb | `compiledb make` |
| Bazel | `--compile_commands` / hedron |

排查流程相同：找到 compile_commands → 确认路径 → clangd --check → 重启 clangd。

## 本工作区已知配置（参考）

`/home/xr/workspace` 典型配置：

- 扩展：`llvm-vs-code-extensions.vscode-clangd`
- `C_Cpp.intelliSenseEngine`: `Disabled`
- `--compile-commands-dir`: `${workspaceFolder}/build/application`
- 根目录：`compile_commands.json` → `build/application/compile_commands.json`
- `.clangd`: `CompilationDatabase: build/application`
- `scripts/build.sh` **当前未**默认传 `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`（断链复现原因之一）

修复命令模板：

```bash
cd /home/xr/workspace
source /opt/ros/$ROS2_DISTRO/setup.bash
colcon build --packages-select application \
  --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  --cmake-force-configure
```
