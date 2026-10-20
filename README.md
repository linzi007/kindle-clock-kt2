# Kindle Clock KT2 · 厦门天气时钟

为 Kindle Basic 2014 / KT2 适配的 KUAL 时钟：大字时间、英文日期、厦门天气（摄氏度）和电量。参考 [mattzzw/kindle-clock](https://github.com/mattzzw/kindle-clock) 的 Shell + KUAL + FBInk 方案，按实机硬件重新适配。

## 支持的设备

- Kindle Basic 2014 / KT2，型号代码 C6，固件 5.12.2.2。
- 600×800 竖屏，设备自带 Palatino 字体。
- 设备已完成越狱，并安装可用的 KUAL。越狱、hotfix、MRInstaller 和 KUAL 安装包不在本仓库中。

尚未验证其他机型或固件。这里的 PW2 FBInk 构建是经 KT2 实机验证的 ARMv7 版本，不代表时钟脚本适用于所有 PW2 设备。

## 安装

在 Mac 或 Linux 上安装 Python 3、curl 和 Git，然后运行：

```sh
git clone https://github.com/linzi007/kindle-clock-kt2.git
cd kindle-clock-kt2
sh scripts/fetch-fbink.sh
```

下载脚本从 FBInk 原作者附件取得 1.25.0 PW2 构建，校验压缩包及可执行文件的 SHA-256，只提取 `PW2/bin/fbink` 到 `clock/bin/fbink`。仓库不存放第三方二进制；不会覆盖设备的 hotfix FBInk。

将整个 `clock/` 文件夹复制到 Kindle USB 存储的 `extensions/clock/`，安全弹出后拔线。开始前在 Kindle 设置中连接 Wi-Fi，并确认日期和时间正确。

## 使用

从 KUAL 选择：

- **Clock: Test (2 min)**：显示约两分钟后自动重新加载 Kindle 主界面。建议先用它检查显示和天气。
- **Clock: Start**：持续运行，每分钟刷新，每五分钟完整刷新减少残影。
- **Clock: Stop**：写入停止请求；仅在仍能进入 KUAL 时可用。持续时钟会暂停主界面，通常需要长按电源键直到设备重启退出；可能需要约 40 秒。没有开机自启。

时钟进程使用北京时间 `TZ=CST-8`，读取设备系统时钟，不自动校时。固定地点为中国厦门，城市、日期和天气以英文显示；没有室温传感器显示或前光控制。

天气来自 `https://wttr.in/Xiamen?m&format=%C%7C%t`。成功后每小时更新，失败后最多每五分钟重试；连接超时 5 秒、单次请求最多 12 秒，连接 Wi-Fi 最多等待 20 秒。离线时仍显示时间；保留上次成功天气并显示更新时间，无缓存时显示 `Weather unavailable`。

## 实机验证与已知限制

时间、日期、电量及连接 Wi-Fi 后的厦门天气已在 KT2 上确认显示；普通两分钟测试有完整自动恢复主界面的日志。

RTC 深度休眠测试未能在预期的 20 秒内自动返回，日志记录等待 111 秒。本版本已移除休眠测试入口和所有深度休眠调用，即使存在旧的 `runtime/rtc-tested` 标记也不会启用。普通等待模式耗电更高，续航尚未测量。

持续运行时曾出现 Wi-Fi 状态持续为 `PENDING`，网络重连问题仍待调查。天气可能保留旧值，应查看其更新时间。移除休眠后的版本已通过本地模拟回归并部署，仍待用户完成新一轮实机预览；不能据此认定长期运行稳定。

正常退出会恢复 Kindle 主界面和原屏保属性；这次界面重新加载可能出现启动画面。日志位于 `extensions/clock/runtime/clock.log`，天气错误在同目录 `weather-error.txt`。

## 诊断和本地检查

可选：把 `diagnostics/` 复制为 Kindle 的 `extensions/clock-setup/`，在 KUAL 点击 **Clock: Check Device**。它读取硬件状态并写入 USB 根目录的 `clock-device-check.txt`，不修改系统配置。

```sh
sh -n clock/clock.sh
sh -n clock/launch.sh
sh -n scripts/fetch-fbink.sh
python3 tests/verify-clock.py
```

模拟检查覆盖正常/负温天气、畸形响应、离线、Wi-Fi 未连接、字体预检失败、遗留 RTC 标记和旧休眠测试入口拒绝。模拟不能替代真实设备的网络、耗电及唤醒验证。`installation-manifest.json` 记录本次部署的七个时钟文件的大小和 SHA-256，包含下载后得到的 FBInk。

## 来源与许可说明

- 方案参考：[mattzzw/kindle-clock](https://github.com/mattzzw/kindle-clock)。未直接附带上游脚本；上游未提供可检测到的根目录许可证，本仓库不代替上游授予许可。
- FBInk：[NiLuJe/FBInk](https://github.com/NiLuJe/FBInk)，[1.25.0 源码](https://github.com/NiLuJe/FBInk/tree/v1.25.0)，[原作者发布帖](https://www.mobileread.com/forums/showthread.php?t=299620)。保留 `clock/FBInk-LICENSE.txt` 和 `clock/FBInk-CREDITS.txt`；相关依赖许可见致谢文件。

仓库仅包含适配代码、说明、诊断工具及模拟检查；不包含设备备份、账号资料、Wi-Fi 配置、原始运行日志或越狱安装包。
