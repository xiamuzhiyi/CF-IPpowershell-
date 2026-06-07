CF优选IP powershell工具

这是一个基于 powershell的CF优选工具，解决按照一大堆运行环境的问题，一键启动，如需自动上传至GITHUB版本，将在后续放出！

🎯 基本介绍
通过powershell自定义优选，执行批处理文件.bat文件即可
测试环境：PowerShell 7.5.5 版本

✨ 使用方法：
1、下载后解压文件夹
2、直接运行run_XXXXXX.bat文件即可
3、run_IPGeoFormat.bat  对IP.TXT文件进行格式化  🇭🇺 | Budapest | CF优选，单独功能提取，方便对本身存在的文件进行格式化
4、run_SelectIP-github.bat 支持上传github版本，请修改github相关资料
5、run_SelectiP-port.bat 支持上传github，自定义端口 如：443、2096端口等
6、run_SelectiP.bat 初始版本，功能不完善，请注意，只能实现IP扫描和格式输出

🚀 项目截图
<img width="1103" height="424" alt="image" src="https://github.com/user-attachments/assets/63a25835-1104-4793-8ff3-330f01c93d45" />
<img width="1129" height="635" alt="image" src="https://github.com/user-attachments/assets/99cc9370-f23b-4c2a-987c-b7be925273cb" />
<img width="1129" height="635" alt="image" src="https://github.com/user-attachments/assets/5f28c857-6b8c-4915-b46c-72bb0ebab205" />

🙏 特别注意与致谢

❇️ 特别注意：下载后，须将文件夹解压至：D:\CF优选IP 文件目录下。如需自定义目录可自行修改 

❇️ 扫描器注释：SelectIP-port.ps1 为最新版本，可自定义端口扫描，文件目录修改为自定义，无需一定要在D:\CF优选IP目录下。

❇️ 众多IP段：内含CF官方IP库与部分网上搜集IP段，总计2w9个IP

❇️ 如需自行调节参数，请参看https://github.com/XIU2/CloudflareSpeedTest 参数设定。

❇️ 自带格式输出：IP国家国旗 | 城市名称 | 自定义名称  例如：🇭🇺 | Budapest | CF优选  

🛠️ 系统要求

Windows 10/11

无需安装任何程序，直接运行

🔍 运行常见问题

扫描结果出现下载速度测试为零时，请去 https://github.com/XIU2/CloudflareSpeedTest 下载最新的版本后，修改扫描器名称为CloudflareSpeedTest.exe进行替换即可

⚖️ 免责声明
本项目仅供技术交流与学习使用，请勿用于非法用途。使用本程序产生的任何后果由使用者自行承担。

## Star History

<a href="https://www.star-history.com/?repos=xiamuzhiyi%2FCF-IPpowershell-&type=date&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=xiamuzhiyi/CF-IPpowershell-&type=date&theme=dark&legend=bottom-right" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=xiamuzhiyi/CF-IPpowershell-&type=date&legend=bottom-right" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=xiamuzhiyi/CF-IPpowershell-&type=date&legend=bottom-right" />
 </picture>
</a>
