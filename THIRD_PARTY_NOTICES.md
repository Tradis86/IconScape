# 第三方依赖 / Third-party dependencies

## Microsoft Edge WebView2

Windows 宿主使用 Microsoft Edge WebView2 SDK 与 WebView2 Runtime。构建脚本从 NuGet 获取开发库，本仓库不提交 SDK 二进制文件。

- 包：`Microsoft.Web.WebView2`，构建版本 `1.0.4191.47`。
- 包与许可信息：https://www.nuget.org/packages/Microsoft.Web.WebView2/1.0.4191.47
- 文档：https://learn.microsoft.com/microsoft-edge/webview2/

WebView2 及 Windows / .NET Framework 组件适用各自的许可条款，不因本项目的 GPL-3.0 许可而变更。

The host uses the Microsoft Edge WebView2 SDK and Runtime. SDK binaries are downloaded by the build script and are not checked into this repository. Microsoft components retain their respective licenses.

## NSIS

Windows 安装包使用 NSIS 3.13 制作。便携编译器仅在构建时下载，不作为项目源码提交。NSIS 及其压缩模块适用各自许可，详见 https://nsis.sourceforge.io/License 。安装包附带项目对应源码 ZIP。

## 伦敦主题的照片 / Photographs in the London theme

伦敦主题（`prototype/london.html`）拍立得中的照片来自 Wikimedia Commons，均为自由许可。`prototype/assets/london/` 中的文件已裁成正方形并缩小到 480×480 像素；主题在显示时再为它们加上即时成像胶片的暖色褪色效果。每张照片仍适用其原作者的许可：CC BY-SA 照片的这些改编版本同样以 CC BY-SA 的相同版本提供。

The photographs in the London theme's polaroids (`prototype/london.html`) come from Wikimedia Commons under free licences. The files in `prototype/assets/london/` were cropped square and resized to 480×480 pixels; at display time the theme also gives them the warm, faded look of instant film. Each photograph remains under its author's licence; the adapted versions of the CC BY-SA photographs are shared under the same CC BY-SA version.

| File | Original | Author | Licence |
| --- | --- | --- | --- |
| `abbey.jpg` | [Westminster Abbey, Westminster.jpg](https://commons.wikimedia.org/wiki/File:Westminster_Abbey,_Westminster.jpg) | Antiquary | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `alberthall.jpg` | [Royal Albert Hall, London - Nov 2012.jpg](https://commons.wikimedia.org/wiki/File:Royal_Albert_Hall,_London_-_Nov_2012.jpg) | Diliff | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `albertmem.jpg` | [Albert Memorial, London - May 2008.jpg](https://commons.wikimedia.org/wiki/File:Albert_Memorial,_London_-_May_2008.jpg) | Diliff | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `battersea.jpg` | [Battersea Power Station from the river.jpg](https://commons.wikimedia.org/wiki/File:Battersea_Power_Station_from_the_river.jpg) | Alberto Pascual | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `bigben.jpg` | [Elizabeth Tower and the north front of the Palace of Westminster, London.jpg](https://commons.wikimedia.org/wiki/File:Elizabeth_Tower_and_the_north_front_of_the_Palace_of_Westminster,_London.jpg) | Christian David | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `britishmuseum.jpg` | [British Museum from NE 2.JPG](https://commons.wikimedia.org/wiki/File:British_Museum_from_NE_2.JPG) | Ham | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `buckingham.jpg` | [Buckingham Palace London Morning 2020 01 (cropped).jpg](https://commons.wikimedia.org/wiki/File:Buckingham_Palace_London_Morning_2020_01_(cropped).jpg) | Julian Herzog | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `camden.jpg` | [Camden markets entrance.JPG](https://commons.wikimedia.org/wiki/File:Camden_markets_entrance.JPG) | en:User:Grim23 | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `coventgarden.jpg` | [Covent Garden Interior May 2006 crop.jpg](https://commons.wikimedia.org/wiki/File:Covent_Garden_Interior_May_2006_crop.jpg) | Diliff (derivative work: SilkTork) | [CC BY 2.5](https://creativecommons.org/licenses/by/2.5/) |
| `cuttysark.jpg` | [Northeast View of the Cutty Sark in Greenwich.jpg](https://commons.wikimedia.org/wiki/File:Northeast_View_of_the_Cutty_Sark_in_Greenwich.jpg) | Ethan Doyle White | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `eye.jpg` | [London-Eye-2009.JPG](https://commons.wikimedia.org/wiki/File:London-Eye-2009.JPG) | Khamtran | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `globe.jpg` | [Restaurante The Swan, Londres, Inglaterra, 2014-08-11, DD 113.jpg](https://commons.wikimedia.org/wiki/File:Restaurante_The_Swan,_Londres,_Inglaterra,_2014-08-11,_DD_113.jpg) | Diego Delso | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `kensington.jpg` | [Kensington Palace, the South Front - geograph.org.uk - 287402.jpg](https://commons.wikimedia.org/wiki/File:Kensington_Palace,_the_South_Front_-_geograph.org.uk_-_287402.jpg) | Colin Smith | [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/) |
| `kew.jpg` | [Kew Gardens Palm House, London - July 2009.jpg](https://commons.wikimedia.org/wiki/File:Kew_Gardens_Palm_House,_London_-_July_2009.jpg) | Diliff | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `leadenhall.jpg` | [Leadenhall Market In London - Feb 2006 rotated.jpg](https://commons.wikimedia.org/wiki/File:Leadenhall_Market_In_London_-_Feb_2006_rotated.jpg) | Diliff | [CC BY 2.5](https://creativecommons.org/licenses/by/2.5/) |
| `marblearch.jpg` | [Marble Arch (29797251968).jpg](https://commons.wikimedia.org/wiki/File:Marble_Arch_(29797251968).jpg) | Wei-Te Wong from Taipei City, Taiwan, Republic of China | [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/) |
| `millennium.jpg` | [Millenium bridge 2015.jpg](https://commons.wikimedia.org/wiki/File:Millenium_bridge_2015.jpg) | Ibex73 | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `phonebox.jpg` | [Red telephone box, St Paul's Cathedral, London, England, GB, IMG 5182 edit.jpg](https://commons.wikimedia.org/wiki/File:Red_telephone_box,_St_Paul%27s_Cathedral,_London,_England,_GB,_IMG_5182_edit.jpg) | Christoph Braun | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `regent.jpg` | [Regent Street 2011-04-25.jpg](https://commons.wikimedia.org/wiki/File:Regent_Street_2011-04-25.jpg) | aurélien. | [CC BY-SA 2.0](https://creativecommons.org/licenses/by-sa/2.0/) |
| `routemaster.jpg` | [RM8 AEC Routemaster.jpg](https://commons.wikimedia.org/wiki/File:RM8_AEC_Routemaster.jpg) | Murgatroyd49 | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `shard.jpg` | [The Shard at sunset 2017 (cropped).jpg](https://commons.wikimedia.org/wiki/File:The_Shard_at_sunset_2017_(cropped).jpg) | Colin | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `stpauls.jpg` | [St Pauls aerial (cropped).jpg](https://commons.wikimedia.org/wiki/File:St_Pauls_aerial_(cropped).jpg) | Mark Fosh | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/) |
| `tate.jpg` | [Tate Modern - Bankside Power Station.jpg](https://commons.wikimedia.org/wiki/File:Tate_Modern_-_Bankside_Power_Station.jpg) | Acabashi | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `tower.jpg` | [Tower of London from the Shard (8515883950).jpg](https://commons.wikimedia.org/wiki/File:Tower_of_London_from_the_Shard_(8515883950).jpg) | [Duncan] from Nottingham, UK | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/) |
| `towerbridge.jpg` | [Tower Bridge at Dawn.jpg](https://commons.wikimedia.org/wiki/File:Tower_Bridge_at_Dawn.jpg) | Fuzzypiggy | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `trafalgar.jpg` | [Trafalgar Square, London 2 - Jun 2009.jpg](https://commons.wikimedia.org/wiki/File:Trafalgar_Square,_London_2_-_Jun_2009.jpg) | Diliff | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `westminster.jpg` | [Palace of Westminster as seen from Westminster Bridge.jpg](https://commons.wikimedia.org/wiki/File:Palace_of_Westminster_as_seen_from_Westminster_Bridge.jpg) | ThatsTheBoss | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
