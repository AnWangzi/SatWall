# 卫星云图副屏壁纸

定时抓向日葵9号（Himawari-9）云图，自动设成副屏壁纸。
**白天用可见光真彩，天黑后自动切增强红外。**

![SatWall 副屏效果](docs/screenshot.jpg)

*夜间增强红外，2752×2752，每 30 分钟刷新一次。*

## 依赖

- Windows 10 / 11
- Windows PowerShell 5.1（系统自带，不用装）
- **不需要**：Python、WSL、管理员权限、任何第三方库

## 安装到新机器

1. 把整个文件夹拷过去（例如 `D:\Tools\SatWall`）
2. 在那个目录里右键 →「在终端中打开」，执行：

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\setup.ps1
   ```

   也可以直接传参跳过交互：

   ```powershell
   .\setup.ps1 -MonitorIndex 1 -Latitude 30 -IntervalMinutes 30
   ```

3. 脚本会：列出现有显示器让你选一台 → 写 `config.json` → 建定时任务 `SatWallpaper` → 在启动文件夹放托盘快捷方式 → 立即抓第一张

> `setup.ps1` 不会请求管理员权限。如果 `AtLogOn` 那类任务报 Access denied，本项目用的是启动文件夹方案，不受影响。

## 文件说明

| 文件 | 作用 |
|---|---|
| `setup.ps1` | 安装/重装，写配置、建任务、放快捷方式 |
| `sat-auto.ps1` | **一次刷新**：判断昼夜 → 抓图 → 设壁纸 → 写 `status.json` |
| `sat-ir.ps1` | 抓增强红外（CIRA band_13），拼 2752×2752 |
| `set-wall.ps1` | 抓可见光真彩（himawari.asia），拼 4400×4400 |
| `set-wp.ps1` | 只做"设壁纸"这一件事，可单独调用 |
| `sat-tray.ps1` | 托盘图标（图标是当前云图缩略图），右键菜单 |
| `config.json` | 配置，`setup.ps1` 生成，也可手改 |

## 配置项

```json
{
  "root": "C:\\Users\\<你>\\Pictures\\SatWall",
  "monitorIndex": 1,
  "latitude": 32.0,
  "intervalMinutes": 30,
  "trueColorGrid": 8,
  "infraredZoom": 2
}
```

- `monitorIndex`：显示器序号，跟 `setup.ps1` 列出来的一致。`-1` = 自动选"非主屏"
- `latitude`：纬度，只影响几点切红外。北京 39.9 / 上海 31.2 / 广州 23.1 / 哈尔滨 45.8
- `intervalMinutes`：刷新间隔
- `trueColorGrid`：真彩瓦片网格，8 → 4400px
- `infraredZoom`：红外层，2 → 2752px；3 → 5504px（每张多花约 2 分钟）

## 图源

| 用途 | 来源 | 说明 |
|---|---|---|
| 可见光真彩 | `himawari.asia`（日本 NICT） | 8×8 瓦片拼接，10 分钟一档，延迟约 20 分钟 |
| 增强红外 | `slider.cira.colostate.edu`（CIRA/科罗拉多州立） | band_13 红外通道，冷云顶自动标红黄绿 |

两个源都在境外。国内多数线路**可以直连**（实测单张瓦片 1~4 秒），不通的话挂代理即可。

## 已知限制

- **托盘图标需要用户已登录**，用的是启动文件夹快捷方式（登录后自动出现）
- 白天窗口按太阳赤纬估算，误差十几分钟；想手动控制就右键托盘「强制切到可见光 / 红外」
- 可见光在夜半球是纯黑（物理限制，不是 bug），所以夜里必须切红外
- 拼图是固定尺寸，跟显示器分辨率无关，1080p 屏一样能用

## 卸载

```powershell
Unregister-ScheduledTask -TaskName SatWallpaper -Confirm:$false
Remove-Item "$([Environment]::GetFolderPath('Startup'))\SatelliteWallpaper.lnk"
```

再从任务管理器结束 `powershell.exe`（那只是托盘），最后删文件夹。
