# SatWall 卫星云图壁纸

**把实时的卫星云图挂在副屏上，定时自动更新。**

一个 PowerShell 小项目：定时拉取地球同步卫星的云图，把瓦片拼成整图，设成**指定那一台显示器**的壁纸——主屏毫发无损。白天用可见光真彩，日落之后自动换成增强红外。

![副屏效果](docs/screenshot.jpg)

*夜间增强红外，2752×2752，每 30 分钟自动刷新。*

## 特点

- **只动副屏** —— 走 `IDesktopWallpaper` 接口，选中的那块屏换壁纸，主屏完全不受影响
- **自动昼夜切换** —— 白天真彩（4400×4400），日落后自动切红外（2752×2752）。日出日落按太阳赤纬在本地计算，不联网、不调接口
- **托盘图标就是最新云图的缩略图** —— 瞄一眼就知道跑没跑、是不是新的。右键可立即刷新、强制切真彩/红外、暂停自动刷新
- **零依赖** —— 只用 Windows 自带的 PowerShell 5.1 和 .NET 的 `System.Drawing`。不用 Python、不用 WSL、不用编译、**不需要管理员权限**
- **目录随便挪** —— 脚本靠 `$PSScriptRoot` 定位自己，拷到哪都能跑
- **刷新全程无窗口** —— 通过 `wscript` + VBS 启动器拉起 PowerShell，连一闪而过的黑框都不会有

## 系统要求

- Windows 10 / 11
- Windows PowerShell 5.1（系统自带，不用装任何东西）

## 安装

在项目目录里执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

安装器会依次做这几件事：

1. 列出现有显示器，问你要把云图放哪一台
2. 写 `config.json`
3. 注册计划任务 `SatWallpaper`，按间隔自动刷新
4. 在启动文件夹放一个托盘快捷方式（登录后自动出现，不弹窗）
5. 立刻抓第一张

不想交互就直接传参：

```powershell
.\setup.ps1 -MonitorIndex 1 -Latitude 31.2 -IntervalMinutes 30
```

## 配置

`config.json`（安装器生成，也可以手改）：

```json
{
  "root": "C:\\Users\\你\\Pictures\\SatWall",
  "monitorIndex": 1,
  "latitude": 32.0,
  "intervalMinutes": 30,
  "trueColorGrid": 8,
  "infraredZoom": 2
}
```

| 键 | 说明 |
|---|---|
| `monitorIndex` | 显示器序号，跟 `setup.ps1` 打出来的一致；`-1` 表示"自动选非主屏" |
| `latitude` | 纬度，只影响**几点切红外**。北京 39.9 / 上海 31.2 / 广州 23.1 / 哈尔滨 45.8 |
| `intervalMinutes` | 刷新间隔（分钟） |
| `trueColorGrid` | 真彩瓦片网格；`8` → 4400×4400 |
| `infraredZoom` | 红外层级；`2` → 2752×2752，`3` → 5504×5504（更清晰但更慢） |

## 数据源

| 用途 | 来源 | 说明 |
|---|---|---|
| 可见光真彩 | [`himawari.asia`](https://himawari.asia)（日本 NICT） | 向日葵9号，10 分钟一档，延迟约 20 分钟 |
| 增强红外 | [CIRA SLIDER](https://slider.cira.colostate.edu)（科罗拉多州立大学） | `band_13` 10.4µm 窗口红外，冷云顶自动标红黄绿 |

两个源都不用 API key，直接拉瓦片在本地拼接。

## 已知限制

- **可见光的夜半球是纯黑的**。这是物理限制不是 bug——也正是要切红外的原因。实测夜侧平均亮度 0，调色/提亮都救不回来
- 托盘图标需要用户已登录（走启动文件夹快捷方式）
- 日出日落只用纬度估算，误差十几分钟；哪天估错了，右键托盘强制切换即可
- 上游瓦片服务偶尔抽风，脚本只做 3~5 次重试；彻底挂掉时托盘时间戳会停在旧值，一眼能看出来
- 可见光要访问 `himawari.asia`、红外要访问 `cira.colostate.edu`，国内多数家用宽带有线能直连（实测单张瓦片 1~4 秒）；不通再挂代理

## 卸载

```powershell
Unregister-ScheduledTask -TaskName SatWallpaper -Confirm:$false
Remove-Item "$([Environment]::GetFolderPath('Startup'))\SatelliteWallpaper.lnk"
```

然后在任务管理器里结束那个托盘 `powershell.exe`，最后删文件夹。

## 许可证

MIT — 见 [LICENSE](LICENSE)

---

[English](README.en.md)
