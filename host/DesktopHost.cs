// IconScape · desktop host
// IconScape is a modified version of the Deskland Preview host (https://github.com/BLEZZ0102/Deskland, GPL-3.0);
// it uses its own name, icon, data folder and instance identity, as the Deskland authors ask of modified distributions (see TRADEMARKS.md).
//
// It does four things:
//   1. Attaches one borderless window per monitor beneath the desktop icons (the wallpaper layer) and uses WebView2 to show the current theme's page (e.g. prototype/flat.html?wallpaper=1)
//   0. Settings window (prototype/settings.html): pick a theme and tune its parameters, synced live to the wallpaper and saved to settings.json; one-click sharing (the wallpaper page draws a desktop picture with the icons already pixelated)
//   2. Every 400 ms reads the real positions of the desktop icons (cross-process messages to the desktop ListView) and sends them to the page only when they change
//   3. Pauses a monitor's animation while a maximized / fullscreen window hides it; the tray icon can pause, reload and exit (exiting restores the original wallpaper)
//   4. When Explorer rebuilds the wallpaper layer (e.g. on Win+D) our window is destroyed with it → it is re-attached automatically
//
// Built with the .NET Framework compiler that ships with Windows (C# 5 syntax); see build.ps1.

using System;
using System.Diagnostics;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using Microsoft.Win32;

static class Program
{
    public static readonly string ExitEventName = "IconScape_Exit" + InstallProfile.Suffix;
    public static readonly string MenuEventName = "IconScape_Menu" + InstallProfile.Suffix;
    public static readonly string SettingsEventName = "IconScape_Settings" + InstallProfile.Suffix;

    // Signal the running instance (exit / show menu)
    static void Signal(string name)
    {
        Native.AllowSetForegroundWindow(-1);            // lets the running instance bring its menu to the foreground
        EventWaitHandle ev;
        if (EventWaitHandle.TryOpenExisting(name, out ev)) ev.Set();
    }

    [STAThread]
    static void Main(string[] args)
    {
        // IconScape.exe --exit: tell the running instance to exit cleanly (restores the original wallpaper)
        // IconScape.exe --menu: make the running instance pop up its menu at the mouse position
        // IconScape.exe --settings: make the running instance open the settings window
        if (args.Length > 0 && args[0] == "--exit") { Signal(ExitEventName); return; }
        if (args.Length > 0 && args[0] == "--menu") { Signal(MenuEventName); return; }
        if (args.Length > 0 && args[0] == "--settings") { Signal(SettingsEventName); return; }
        if (args.Length > 0 && args[0] == "--exit-installed") { Environment.ExitCode = InstallProfile.StopInstalled(); return; }
        Migration.FromDesklandPreview();                  // before anything writes to the data folder: it only runs while that folder does not exist yet
        bool fromAutostart = Array.IndexOf(args, "--autostart") >= 0;
        if (fromAutostart) AutoStartCheck.MarkLaunched();  // the autostart launch did run (whether or not an instance was already running)
        bool created;
        var mutex = new Mutex(true, "IconScape_Singleton" + InstallProfile.Suffix, out created);
        if (!created)
        {
            if (!fromAutostart) Signal(SettingsEventName); // already running: double-clicking the program again = open settings (the autostart launch just exits quietly)
            return;
        }
        // Work in physical pixels: desktop icon coordinates and screen sizes are all physical pixels
        if (!Native.SetProcessDpiAwarenessContext(new IntPtr(-4))) Native.SetProcessDPIAware();
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        // Any unexpected error goes to the log: no message box, no silent exit
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += delegate(object s, ThreadExceptionEventArgs e) { Log.Write("未处理的异常：" + e.Exception); };
        AppDomain.CurrentDomain.UnhandledException += delegate(object s, UnhandledExceptionEventArgs e) { Log.Write("致命异常：" + e.ExceptionObject); };
        string exeDir = AppDomain.CurrentDomain.BaseDirectory;
        string pageDir = Path.GetFullPath(Path.Combine(exeDir, @"..\..\prototype"));
        // How we attach on 24H2+: by default as a layered child window of Progman (flickers briefly when the system wallpaper changes);
        //   --defview: attach inside the icon layer, below the icon list (experimental: in practice nothing gets drawn); --legacy: attach inside WorkerW (destroyed along with it when the wallpaper changes)
        string attach = "progman";
        bool autostart = false;                           // --autostart: launched at sign-in, do not open the settings window
        foreach (string a in args)
        {
            if (a == "--legacy") attach = "legacy";
            else if (a == "--defview") attach = "defview";
            else if (a == "--autostart") autostart = true;
            else if (!a.StartsWith("--")) pageDir = a;
        }
        WallpaperForm.AttachMode = attach;
        Application.Run(new HostContext(pageDir, !autostart));
        GC.KeepAlive(mutex);
    }
}

static class Log
{
    public static readonly string DataDir = InstallProfile.DataDir;
    public static readonly string FilePath = Path.Combine(DataDir, "host.log");

    public static void Write(string msg)
    {
        try
        {
            Directory.CreateDirectory(DataDir);
            File.AppendAllText(FilePath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss ") + msg + "\r\n");
        }
        catch { }
    }
}

// 2026-11-11 rename (this local copy of Deskland Preview → IconScape): the user keeps their settings and their autostart choice
//   - Settings are copied (not moved) from %LOCALAPPDATA%\DesklandPreview while the IconScape data folder does not exist yet;
//     the WebView2 cache and the logs stay behind, and an installed Deskland Preview keeps working with its own folder
//   - Autostart: only an entry that starts Deskland.exe from this very program folder (the old build of this copy) is removed;
//     the host then creates its own entry. An installed Deskland Preview elsewhere is never touched
static class Migration
{
    public static bool MovedAutoStart;              // read by HostContext, which creates the IconScape autostart entry

    public static void FromDesklandPreview()
    {
        if (InstallProfile.Isolated) return;
        var notes = new List<string>();
        string oldDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DesklandPreview");
        if (!Directory.Exists(InstallProfile.DataDir) && Directory.Exists(oldDir))
        {
            try
            {
                Directory.CreateDirectory(InstallProfile.DataDir);
                foreach (string name in new[] { "settings.json", "welcome.shown", "autostart.enabled", "autostart.last" })
                {
                    string src = Path.Combine(oldDir, name);
                    if (File.Exists(src)) File.Copy(src, Path.Combine(InstallProfile.DataDir, name), false);
                }
                notes.Add("Settings copied from " + oldDir);
            }
            catch (Exception ex) { notes.Add("Copying the settings from " + oldDir + " failed: " + ex.Message); }
        }
        string oldExe = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "Deskland.exe");
        try
        {
            string lnk = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Startup), "Deskland.lnk");
            if (File.Exists(lnk) && string.Equals(ShortcutTarget(lnk), oldExe, StringComparison.OrdinalIgnoreCase))
            {
                File.Delete(lnk);
                MovedAutoStart = true;
                notes.Add("Removed the old autostart shortcut " + lnk);
            }
            using (RegistryKey k = Registry.CurrentUser.OpenSubKey(HostContext.RunKey, true))
            {
                string v = k == null ? null : k.GetValue("DesklandPreview") as string;
                if (v != null && v.IndexOf(oldExe, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    k.DeleteValue("DesklandPreview", false);
                    MovedAutoStart = true;
                    notes.Add("Removed the old autostart entry DesklandPreview");
                }
            }
        }
        catch (Exception ex) { notes.Add("Moving the old autostart entry failed: " + ex.Message); }
        foreach (string n in notes) Log.Write(n);
    }

    static string ShortcutTarget(string path)
    {
        object shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell")), link = null;
        try
        {
            link = shell.GetType().InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { path });
            return link.GetType().InvokeMember("TargetPath", BindingFlags.GetProperty, null, link, null) as string;
        }
        finally
        {
            if (link != null) Marshal.FinalReleaseComObject(link);
            Marshal.FinalReleaseComObject(shell);
        }
    }
}

// Was the autostart launch blocked? (E.g. disabled by the "startup manager" of Huorong or 360: the startup entry is still in the registry but is not allowed to run at sign-in.)
// Each launch with --autostart records the time; when the user opens the program manually, if autostart is on and this sign-in is more than 3 minutes old
// but there is no autostart record after this sign-in → the launch at sign-in did not happen
static class AutoStartCheck
{
    static string LastPath { get { return Path.Combine(Log.DataDir, "autostart.last"); } }
    static string EnabledPath { get { return Path.Combine(Log.DataDir, "autostart.enabled"); } }

    static void Stamp(string path)
    {
        try { Directory.CreateDirectory(Log.DataDir); File.WriteAllText(path, DateTime.UtcNow.Ticks.ToString()); } catch { }
    }
    static DateTime ReadStamp(string path)
    {
        try { return new DateTime(long.Parse(File.ReadAllText(path).Trim()), DateTimeKind.Utc); } catch { return DateTime.MinValue; }
    }
    public static void MarkLaunched() { Stamp(LastPath); }
    public static void MarkEnabled() { Stamp(EnabledPath); }

    // Time of the current sign-in (UTC): LogonTime from WTSQuerySessionInformation(WTSSessionInfo)
    public static DateTime LogonTimeUtc()
    {
        IntPtr buf; int bytes;
        if (!Native.WTSQuerySessionInformation(IntPtr.Zero, -1, 24, out buf, out bytes)) return DateTime.MinValue;
        try { return bytes >= 216 ? DateTime.FromFileTimeUtc(Marshal.ReadInt64(buf, 200)) : DateTime.MinValue; }
        catch { return DateTime.MinValue; }
        finally { Native.WTSFreeMemory(buf); }
    }

    // Security software currently running (only named in the hint so the user knows where to change it)
    public static string SecuritySoftware()
    {
        string[,] known = { { "HipsTray", "火绒" }, { "HipsDaemon", "火绒" }, { "360Tray", "360 安全卫士" }, { "360sd", "360 杀毒" },
                            { "QQPCTray", "腾讯电脑管家" }, { "kxetray", "金山毒霸" }, { "2345SafeTray", "2345 安全卫士" } };
        for (int i = 0; i < known.GetLength(0); i++)
            if (Process.GetProcessesByName(known[i, 0]).Length > 0) return known[i, 1];
        return "";
    }

    // Returns null when all is well; when blocked, returns the name of the running security software ("" if not recognized). The settings page builds the hint text in the UI language
    public static string Detect(bool autoStartOn)
    {
        if (!autoStartOn) return null;
        DateTime logon = LogonTimeUtc();
        if (logon == DateTime.MinValue || (DateTime.UtcNow - logon).TotalMinutes < 3) return null;   // just signed in: startup entries may not have run yet
        if (ReadStamp(EnabledPath) > logon) return null;                                           // autostart was turned on only after this sign-in
        if (ReadStamp(LastPath) > logon) return null;                                              // the autostart launch did run at this sign-in
        string sw = SecuritySoftware();
        Log.Write("这次登录时开机自启没有运行（登录于 " + logon.ToLocalTime().ToString("yyyy-MM-dd HH:mm") + "）" + (sw != "" ? "，正在运行的安全软件：" + sw : ""));
        return sw;
    }
}

static class Json
{
    static readonly JavaScriptSerializer S = new JavaScriptSerializer();
    public static object Parse(string s) { return S.DeserializeObject(s); }
    public static string Stringify(object o) { return S.Serialize(o); }
    public static Dictionary<string, object> Obj(params object[] kv)
    {
        var d = new Dictionary<string, object>();
        for (int i = 0; i + 1 < kv.Length; i += 2) d[(string)kv[i]] = kv[i + 1];
        return d;
    }
}

// User settings: current theme + each theme's parameters (only values the user changed are stored; the rest use the theme defaults)
// Saved to settings.json in the data folder (Log.DataDir)
static class Settings
{
    static readonly string FilePath = Path.Combine(Log.DataDir, "settings.json");
    public static string Theme = "beach";
    public static string Lang = "auto";                // UI language: "auto" (follow the system) or one of I18n.Supported
    public static Dictionary<string, Dictionary<string, object>> Params = new Dictionary<string, Dictionary<string, object>>();

    public static void Load()
    {
        try
        {
            if (!File.Exists(FilePath)) return;
            var root = Json.Parse(File.ReadAllText(FilePath, Encoding.UTF8)) as Dictionary<string, object>;
            if (root == null) return;
            object v;
            if (root.TryGetValue("theme", out v) && v is string) Theme = (string)v;
            if (root.TryGetValue("lang", out v) && v is string) Lang = (string)v;
            if (root.TryGetValue("params", out v) && v is Dictionary<string, object>)
                foreach (var kv in (Dictionary<string, object>)v)
                {
                    var d = kv.Value as Dictionary<string, object>;
                    if (d != null) Params[kv.Key] = d;
                }
            Log.Write("已读取设置：主题 " + Theme);
        }
        catch (Exception ex) { Log.Write("读取设置失败（将使用默认值）：" + ex.Message); }
    }

    public static void Save()
    {
        try
        {
            Directory.CreateDirectory(Log.DataDir);
            File.WriteAllText(FilePath, Json.Stringify(Json.Obj("version", 1, "theme", Theme, "lang", Lang, "params", Params)), new UTF8Encoding(false));
        }
        catch (Exception ex) { Log.Write("保存设置失败：" + ex.Message); }
    }

    public static Dictionary<string, object> For(string theme)
    {
        Dictionary<string, object> d;
        if (!Params.TryGetValue(theme, out d)) Params[theme] = d = new Dictionary<string, object>();
        return d;
    }
}

// UI language (2026-10-14): the string tables live in prototype/i18n/<language>.json: ui for the settings page, host for the tray menu and message boxes, themes for theme names and parameters (the Simplified Chinese theme texts are themes.json itself).
// The "Language" setting defaults to "System default": use the Windows display language; unsupported languages fall back to English
static class I18n
{
    // When adding a language, also update LANGS in the settings page and the language list exported with the Preview edition.
    public static readonly string[] Supported = { "zh-CN", "en", "it" };
    public static string Code = "zh-CN", Sys = "en";     // language in use; language that "System default" would use
    static Dictionary<string, object> cur, en, zh;

    public static string FromCulture(System.Globalization.CultureInfo c)
    {
        string n = c.Name.ToLowerInvariant(), two = c.TwoLetterISOLanguageName;
        bool zhHant = n.StartsWith("zh") && (n.Contains("hant") || n.EndsWith("-tw") || n.EndsWith("-hk") || n.EndsWith("-mo"));
        string want = n.StartsWith("zh") ? (zhHant ? "zh-TW" : "zh-CN") : two == "pt" ? "pt-BR" : two;
        if (Array.IndexOf(Supported, want) >= 0) return want;
        return n.StartsWith("zh") ? "zh-CN" : "en";       // Traditional Chinese is not done yet: use Simplified for now
    }

    public static void Load(string pageDir, string setting)
    {
        Sys = FromCulture(System.Globalization.CultureInfo.CurrentUICulture);
        Code = Array.IndexOf(Supported, setting) >= 0 ? setting : Sys;
        zh = Read(pageDir, "zh-CN");
        en = Read(pageDir, "en");
        cur = Code == "zh-CN" ? zh : Code == "en" ? en : Read(pageDir, Code);
        Log.Write("界面语言：" + Code + "（设置：" + setting + "，系统：" + Sys + "）");
    }

    static Dictionary<string, object> Read(string pageDir, string code)
    {
        try
        {
            var root = Json.Parse(File.ReadAllText(Path.Combine(Path.Combine(pageDir, "i18n"), code + ".json"), Encoding.UTF8)) as Dictionary<string, object>;
            object h;
            return root != null && root.TryGetValue("host", out h) ? h as Dictionary<string, object> : null;
        }
        catch (Exception ex) { Log.Write("读取语言文件失败（" + code + "）：" + ex.Message); return null; }
    }

    // Get a string: current language → English → Simplified Chinese; {name} is replaced by the values given in pairs afterwards
    public static string T(string key, params string[] kv)
    {
        object v = null;
        bool found = (cur != null && cur.TryGetValue(key, out v)) || (en != null && en.TryGetValue(key, out v)) || (zh != null && zh.TryGetValue(key, out v));
        string str = found ? (v as string ?? key) : key;
        for (int i = 0; i + 1 < kv.Length; i += 2) str = str.Replace("{" + kv[i] + "}", kv[i + 1]);
        return str;
    }
}

// Lifetime of the whole program: the tray icon stays; if the wallpaper window goes away a new one is created
// Ways to open the menu: left / right click on the tray icon, the Ctrl+Alt+H hotkey (or --menu)
// Ways to open settings: double-click the program (starts it first if not running), double-click the tray icon, menu → Settings… (or --settings)
class HostContext : ApplicationContext
{
    public const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run", RunName = InstallProfile.AppName;
    static readonly MethodInfo ShowTrayMenu =
        typeof(NotifyIcon).GetMethod("ShowContextMenu", BindingFlags.Instance | BindingFlags.NonPublic);

    readonly string pageDir;
    readonly NotifyIcon tray;
    readonly MenuItem pauseItem, autoStartItem, settingsItem, reloadItem, exitItem;
    readonly System.Windows.Forms.Timer watch, iconTimer;
    readonly EventWaitHandle exitEvent, menuEvent, settingsEvent;
    readonly HotkeyWindow hotkey = new HotkeyWindow();
    readonly Queue<DateTime> restarts = new Queue<DateTime>();
    readonly List<WallpaperForm> forms = new List<WallpaperForm>();   // one wallpaper window per monitor
    readonly List<WallpaperForm> dead = new List<WallpaperForm>();
    readonly IconReader icons = new IconReader();       // shared: the icons are read once and each window keeps the ones on its own monitor
    string syncedScreens = "", pendingScreens = "";     // monitor layout the windows were built for / changed layout seen on the last tick
    Size previewScreen;                                 // primary monitor size last sent to the settings page
    SettingsForm settingsWin;
    DateTime nextStart = DateTime.MaxValue, saveDue = DateTime.MaxValue;
    bool manualPause, exiting;
    string autoStartSw;                                 // autostart did not run (checked only when opened manually): name of the running security software ("" if not recognized); null when all is well
    string updateVersion, updateUrl, updateStatus = "", updateError = "";
    double updateProgress = -1;                         // -1 = no percentage to show in the current phase

    public HostContext(string pageDir, bool showSettings)
    {
        this.pageDir = pageDir;
        Log.Write("启动，页面目录：" + pageDir + (showSettings ? "" : "（开机自动启动）"));
        if (showSettings) autoStartSw = AutoStartCheck.Detect(IsAutoStart());
        Settings.Load();
        I18n.Load(pageDir, Settings.Lang);
        exitEvent = new EventWaitHandle(false, EventResetMode.AutoReset, Program.ExitEventName);
        menuEvent = new EventWaitHandle(false, EventResetMode.AutoReset, Program.MenuEventName);
        settingsEvent = new EventWaitHandle(false, EventResetMode.AutoReset, Program.SettingsEventName);

        // Hotkey Ctrl+Alt+H: pop up the menu at the mouse position
        bool hotkeyOk = hotkey.Register(Native.MOD_CONTROL | Native.MOD_ALT | Native.MOD_NOREPEAT, Keys.H);
        hotkey.Pressed += delegate { ShowMenu(); };
        Log.Write(hotkeyOk ? "快捷键 Ctrl+Alt+H 已注册" : "快捷键 Ctrl+Alt+H 注册失败（可能被其他程序占用）");

        pauseItem = new MenuItem(I18n.T("trayPause"), delegate
        {
            manualPause = !manualPause;
            pauseItem.Checked = manualPause;
            foreach (WallpaperForm f in forms.ToArray()) f.SetManualPause(manualPause);
        });
        autoStartItem = new MenuItem(I18n.T("trayAutostart"), delegate { SetAutoStart(!autoStartItem.Checked); });
        autoStartItem.Checked = IsAutoStart();
        if (Migration.MovedAutoStart && !autoStartItem.Checked)
        {
            SetAutoStart(true);                         // the old build of this copy started at sign-in: IconScape keeps that choice
            Log.Write("Autostart moved from Deskland.exe to " + Application.ExecutablePath);
        }
        if (autoStartItem.Checked && AutoStartValue() != "")
        {
            try
            {
                if (CreateAutoStartShortcut())
                {
                    DeleteRunAutoStart();
                    Log.Write("开机自动启动已迁移到当前用户启动文件夹");
                }
                else if (AutoStartValue().IndexOf("--autostart") < 0)
                    using (RegistryKey k = Registry.CurrentUser.CreateSubKey(RunKey))   // add the argument when the fallback entry lacks it
                        k.SetValue(RunName, "\"" + Application.ExecutablePath + "\" --autostart");
            }
            catch (Exception ex) { Log.Write("迁移开机自动启动失败，保留原启动项：" + ex.Message); }
        }
        settingsItem = new MenuItem(I18n.T("traySettings"), delegate { OpenSettings(); });
        settingsItem.DefaultItem = true;                // bold: the main entry point

        tray = new NotifyIcon();
        tray.Icon = AppIcon.Create();
        tray.Text = InstallProfile.AppName;
        tray.ContextMenu = new ContextMenu(new[] {
            settingsItem,
            pauseItem,
            reloadItem = new MenuItem(I18n.T("trayReload"), delegate { foreach (WallpaperForm f in forms.ToArray()) f.Reload(); }),
            autoStartItem,
            new MenuItem("-"),
            exitItem = new MenuItem(I18n.T("trayExit"), delegate { Exit(); }),
        });
        tray.MouseUp += delegate(object s, MouseEventArgs e) { if (e.Button == MouseButtons.Left) ShowMenu(); };
        tray.DoubleClick += delegate { OpenSettings(); };   // double-click the tray icon: open settings directly
        tray.Visible = true;
        ShowWelcomeOnce(hotkeyOk);

        watch = new System.Windows.Forms.Timer();
        watch.Interval = 500;
        watch.Tick += delegate { Watch(); };
        watch.Start();
        iconTimer = new System.Windows.Forms.Timer();
        iconTimer.Interval = 400;
        iconTimer.Tick += delegate { PollIcons(); };
        iconTimer.Start();
        SyncForms();
        if (showSettings) OpenSettings();                // the user started the program by double-clicking: open settings directly
    }

    // UI language changed: update the tray menu texts
    void ApplyTrayTexts()
    {
        settingsItem.Text = I18n.T("traySettings");
        pauseItem.Text = I18n.T("trayPause");
        reloadItem.Text = I18n.T("trayReload");
        autoStartItem.Text = I18n.T("trayAutostart");
        exitItem.Text = I18n.T("trayExit");
    }

    // ---------------------------------------------------------------- Settings window
    public void OpenSettings()
    {
        if (exiting) return;
        if (settingsWin == null || settingsWin.IsDisposed)
        {
            settingsWin = new SettingsForm(pageDir, this);
            settingsWin.FormClosed += delegate { settingsWin = null; };
            Log.Write("打开设置窗口");
        }
        if (settingsWin.WindowState == FormWindowState.Minimized) settingsWin.WindowState = FormWindowState.Normal;
        settingsWin.Show();
        // When launched externally with SW_HIDE, the WinForms Visible state may already be true
        // while the native window is still hidden; Activate / another Show does not fix it, so it must be restored explicitly.
        // SW_RESTORE handles both hidden and minimized; SW_SHOW does not expand a minimized window.
        Native.ShowWindow(settingsWin.Handle, Native.SW_RESTORE);
        settingsWin.Activate();
    }

    string SettingsMessage()
    {
        return Json.Stringify(Json.Obj("t", "settings", "v", Settings.For(Settings.Theme)));
    }

    string UpdateStateMessage()
    {
        return Json.Stringify(Json.Obj("t", "updateState", "version", updateVersion,
            "status", updateStatus, "progress", updateProgress, "error", updateError));
    }

    void PostUpdateState()
    {
        if (settingsWin != null) settingsWin.Post(UpdateStateMessage());
    }

    // Only for development testing or non-Store update sources; the Store edition always uses StoreContext and never accepts an address passed in by the web page.
    public void OfferUpdate(string version, string url)
    {
        Uri uri;
        if (string.IsNullOrWhiteSpace(version) || !Uri.TryCreate(url, UriKind.Absolute, out uri) || uri.Scheme != Uri.UriSchemeHttps)
            throw new ArgumentException("更新信息需要版本号和有效的 HTTPS 地址");
        updateVersion = version.Trim();
        updateUrl = uri.AbsoluteUri;
        updateStatus = "available";
        updateProgress = -1;
        updateError = "";
        PostUpdateState();
    }

    // Initial state for the settings page; its preview shows the primary monitor (size and icons)
    void PostInit()
    {
        if (settingsWin == null) return;
        Rectangle scr = Screen.PrimaryScreen.Bounds;
        previewScreen = scr.Size;
        settingsWin.Post(Json.Stringify(Json.Obj("t", "init", "theme", Settings.Theme, "params", Settings.Params,
            "screen", Json.Obj("w", scr.Width, "h", scr.Height), "autostart", IsAutoStart(),
            "autostartWarn", autoStartSw != null, "autostartSw", autoStartSw ?? "",
            "lang", Settings.Lang, "langEff", I18n.Code, "langSys", I18n.Sys)));
        WallpaperForm form = PrimaryForm();
        if (form != null && form.LastIcons != "") settingsWin.Post(form.LastIcons);
    }

    // The wallpaper window on the primary monitor (the first one if the primary has none yet); null when there is no window
    WallpaperForm PrimaryForm()
    {
        string primary = Screen.PrimaryScreen.DeviceName;
        foreach (WallpaperForm f in forms) if (f.Device == primary) return f;
        return forms.Count > 0 ? forms[0] : null;
    }

    // Same message to every monitor's page (a snapshot of the list: a dead WebView2 tears its window down while posting)
    void PostToForms(string json)
    {
        foreach (WallpaperForm f in forms.ToArray()) f.Post(json);
    }

    void SaveSoon() { saveDue = DateTime.Now.AddMilliseconds(600); }

    bool ThemeAllowed(string id)
    {
        return Themes.Allowed(pageDir, id, delegate(string product) { return false; });
    }

    // Messages from the settings page: hello / set / reset / theme / autostart / lang / updateProgram
    public void OnSettingsMessage(string s)
    {
        var m = Json.Parse(s) as Dictionary<string, object>;
        if (m == null || settingsWin == null) return;
        object t;
        m.TryGetValue("t", out t);
        switch (t as string)
        {
            case "hello":
                PostInit();
                if (updateVersion != null) PostUpdateState();
                break;
            case "set":
            {
                string theme = m["theme"] as string, key = m["key"] as string;
                if (theme == null || key == null) return;
                Settings.For(theme)[key] = m["value"];
                if (theme == Settings.Theme)
                    PostToForms(Json.Stringify(Json.Obj("t", "settings", "v", Json.Obj(key, m["value"]))));
                SaveSoon();
                break;
            }
            case "reset":
            {
                string theme = m["theme"] as string;
                if (theme == null) return;
                Settings.Params.Remove(theme);
                if (theme == Settings.Theme) PostToForms("{\"t\":\"reset\"}");
                SaveSoon();
                Log.Write("恢复默认设置：" + theme);
                break;
            }
            case "theme":
            {
                string id = m["id"] as string;
                if (id == null || !ThemeAllowed(id))
                {
                    settingsWin.Post(Json.Stringify(Json.Obj("t", "themeChanged", "id", Settings.Theme)));
                    Log.Write("拒绝未授权或未知主题切换：" + (id ?? "null"));
                    return;
                }
                string page = Themes.PageFor(pageDir, id);
                if (page == null || id == Settings.Theme) return;
                Settings.Theme = id;
                SaveSoon();
                foreach (WallpaperForm f in forms.ToArray()) f.LoadPage(page);
                Log.Write("切换主题：" + id);
                break;
            }
            case "autostartWarnSeen":
                autoStartSw = null;
                break;
            case "lang":                                    // UI language change: save it, update the tray menu, and tell the settings page which language is actually in use
            {
                object v;
                if (!m.TryGetValue("v", out v) || !(v is string)) return;
                Settings.Lang = (string)v;
                SaveSoon();
                I18n.Load(pageDir, Settings.Lang);
                ApplyTrayTexts();
                settingsWin.Post(Json.Stringify(Json.Obj("t", "lang", "v", Settings.Lang, "eff", I18n.Code, "sys", I18n.Sys)));
                break;
            }
            case "share":                                   // sharing draws the primary monitor, the one the settings preview shows
            {
                WallpaperForm form = PrimaryForm();
                if (form == null) { PostShareResult(false, null, I18n.T("errNotReady")); break; }
                form.RequestSnapshot(OnShareImage);
                break;
            }
            case "shareVideo":
            {
                WallpaperForm form = PrimaryForm();
                if (form == null) { PostShareResult(false, null, I18n.T("errNotReady")); break; }
                form.RequestRecording(OnShareVideo);
                break;
            }
            case "openShare":
                if (lastShare != null && File.Exists(lastShare)) Process.Start(lastShare);
                break;
            case "revealShare":
                if (lastShare != null && File.Exists(lastShare)) Process.Start("explorer.exe", "/select,\"" + lastShare + "\"");
                break;
            case "updateProgram":
                if (updateUrl != null) Process.Start(updateUrl);
                break;
            case "autostart":
                SetAutoStart(m["v"] is bool && (bool)m["v"]);
                settingsWin.Post(Json.Stringify(Json.Obj("t", "autostart", "v", IsAutoStart())));
                break;
        }
    }

    // ---- One-click share: image drawn by the wallpaper page → saved to "Pictures\IconScape", copied to the clipboard, thumbnail sent back to the settings page ----
    string lastShare;                                   // path of the most recent share file (the settings page can only ask us to open this one)
    void OnShareImage(string thumb, string png, string err)
    {
        if (err != null || png == null) { PostShareResult(false, null, err ?? I18n.T("errNoImage")); Log.Write("生成分享图失败：" + err); return; }
        try
        {
            int comma = png.IndexOf(',');
            byte[] bytes = Convert.FromBase64String(comma >= 0 ? png.Substring(comma + 1) : png);
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyPictures), InstallProfile.AppName);
            Directory.CreateDirectory(dir);
            string path = Path.Combine(dir, InstallProfile.AppName + " " + DateTime.Now.ToString("yyyy-MM-dd HHmmss") + ".png");
            File.WriteAllBytes(path, bytes);
            lastShare = path;
            try
            {
                using (var ms = new MemoryStream(bytes))
                using (var img = Image.FromStream(ms))
                {
                    var data = new DataObject();
                    data.SetImage(new Bitmap(img));                       // what ordinary programs (chat apps etc.) understand
                    data.SetData("PNG", false, new MemoryStream(bytes));  // programs that understand PNG (browsers, Office) use this one; it is sharper
                    Clipboard.SetDataObject(data, true);
                }
            }
            catch (Exception ex) { Log.Write("复制分享图到剪贴板失败：" + ex.Message); }
            Log.Write("已生成分享图：" + path);
            if (settingsWin != null)
                settingsWin.Post(Json.Stringify(Json.Obj("t", "shareResult", "ok", true, "thumb", thumb, "path", path)));
        }
        catch (Exception ex)
        {
            Log.Write("保存分享图失败：" + ex);
            PostShareResult(false, null, ex.Message);
        }
    }
    void PostShareResult(bool ok, string path, string msg)
    {
        if (settingsWin != null) settingsWin.Post(Json.Stringify(Json.Obj("t", "shareResult", "ok", ok, "path", path, "msg", msg)));
    }
    // Share animation: saved as MP4 (WebM when unsupported); the file is put on the clipboard (paste it straight into a chat window to send it),
    // and the settings page plays it directly from https://share.local/<file name>
    void OnShareVideo(string mime, string poster, string video, string err)
    {
        if (err != null || video == null) { PostShareResult(false, null, err ?? I18n.T("errNoVideo")); Log.Write("录分享动画失败：" + err); return; }
        try
        {
            int comma = video.IndexOf(',');
            byte[] bytes = Convert.FromBase64String(comma >= 0 ? video.Substring(comma + 1) : video);
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyPictures), InstallProfile.AppName);
            Directory.CreateDirectory(dir);
            string name = InstallProfile.AppName + " " + DateTime.Now.ToString("yyyy-MM-dd HHmmss") + (mime == "video/webm" ? ".webm" : ".mp4");
            string path = Path.Combine(dir, name);
            File.WriteAllBytes(path, bytes);
            lastShare = path;
            try
            {
                var files = new System.Collections.Specialized.StringCollection();
                files.Add(path);
                Clipboard.SetFileDropList(files);
            }
            catch (Exception ex) { Log.Write("复制分享动画到剪贴板失败：" + ex.Message); }
            Log.Write("已录好分享动画：" + path + "（" + (bytes.Length / 1024) + " KB）");
            if (settingsWin != null)
            {
                settingsWin.MapShareFolder(dir);
                settingsWin.Post(Json.Stringify(Json.Obj("t", "shareResult", "ok", true, "kind", "video", "thumb", poster, "path", path,
                    "url", "https://share.local/" + Uri.EscapeDataString(name))));
            }
        }
        catch (Exception ex)
        {
            Log.Write("保存分享动画失败：" + ex);
            PostShareResult(false, null, ex.Message);
        }
    }

    // Pop up the tray menu at the mouse position (NotifyIcon's built-in popup logic handles the foreground window, so the menu closes properly when clicking elsewhere)
    void ShowMenu()
    {
        if (exiting) return;
        autoStartItem.Checked = IsAutoStart();
        if (ShowTrayMenu != null) ShowTrayMenu.Invoke(tray, null);
    }

    // On first run show one system notification telling the user where the menu is
    void ShowWelcomeOnce(bool hotkeyOk)
    {
        try
        {
            string flag = Path.Combine(Log.DataDir, "welcome.shown");
            if (File.Exists(flag)) return;
            Directory.CreateDirectory(Log.DataDir);
            tray.ShowBalloonTip(10000, I18n.T("welcomeTitle"),
                I18n.T("welcomeBody", "hotkey", hotkeyOk ? I18n.T("welcomeHotkey") : ""), ToolTipIcon.Info);
            File.WriteAllText(flag, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
        }
        catch (Exception ex) { Log.Write("首次提示失败：" + ex.Message); }
    }

    // Start at sign-in: prefer a shortcut in the current user's Startup folder; an old Run entry is migrated on launch.
    // Task Scheduler is not used because it needs extra privileges; if creating the shortcut fails the Run entry is kept as a fallback.
    static string AutoStartShortcutPath
    {
        get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Startup), InstallProfile.AppName + ".lnk"); }
    }

    static object OpenAutoStartShortcut()
    {
        object shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
        try
        {
            return shell.GetType().InvokeMember("CreateShortcut", BindingFlags.InvokeMethod,
                null, shell, new object[] { AutoStartShortcutPath });
        }
        finally { Marshal.FinalReleaseComObject(shell); }
    }

    static bool AutoStartShortcutEnabled()
    {
        if (!File.Exists(AutoStartShortcutPath)) return false;
        object link = null;
        try
        {
            link = OpenAutoStartShortcut();
            string target = link.GetType().InvokeMember("TargetPath", BindingFlags.GetProperty,
                null, link, null) as string;
            string arguments = link.GetType().InvokeMember("Arguments", BindingFlags.GetProperty,
                null, link, null) as string;
            return string.Equals(target, Application.ExecutablePath, StringComparison.OrdinalIgnoreCase)
                && arguments != null && arguments.IndexOf("--autostart", StringComparison.OrdinalIgnoreCase) >= 0;
        }
        catch { return false; }
        finally { if (link != null) Marshal.FinalReleaseComObject(link); }
    }

    static bool CreateAutoStartShortcut()
    {
        object link = null;
        try
        {
            link = OpenAutoStartShortcut();
            link.GetType().InvokeMember("TargetPath", BindingFlags.SetProperty,
                null, link, new object[] { Application.ExecutablePath });
            link.GetType().InvokeMember("Arguments", BindingFlags.SetProperty,
                null, link, new object[] { "--autostart" });
            link.GetType().InvokeMember("WorkingDirectory", BindingFlags.SetProperty,
                null, link, new object[] { Path.GetDirectoryName(Application.ExecutablePath) });
            link.GetType().InvokeMember("IconLocation", BindingFlags.SetProperty,
                null, link, new object[] { Application.ExecutablePath + ",0" });
            link.GetType().InvokeMember("Description", BindingFlags.SetProperty,
                null, link, new object[] { InstallProfile.AppName });
            link.GetType().InvokeMember("Save", BindingFlags.InvokeMethod, null, link, null);
            return File.Exists(AutoStartShortcutPath);
        }
        catch (Exception ex) { Log.Write("创建启动文件夹快捷方式失败：" + ex.Message); return false; }
        finally { if (link != null) Marshal.FinalReleaseComObject(link); }
    }

    static string AutoStartValue()
    {
        if (InstallProfile.Isolated) return "";
        using (RegistryKey k = Registry.CurrentUser.OpenSubKey(RunKey))
        {
            string v = k == null ? null : k.GetValue(RunName) as string;
            return v ?? "";
        }
    }

    static void DeleteRunAutoStart()
    {
        using (RegistryKey k = Registry.CurrentUser.OpenSubKey(RunKey, true))
            if (k != null) k.DeleteValue(RunName, false);
    }

    static bool IsAutoStart()
    {
        return AutoStartShortcutEnabled()
            || AutoStartValue().IndexOf(Application.ExecutablePath, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    void SetAutoStart(bool on)
    {
        if (InstallProfile.Isolated) return;
        try
        {
            if (on)
            {
                bool shortcut = CreateAutoStartShortcut();
                if (shortcut) DeleteRunAutoStart();
                else
                    using (RegistryKey k = Registry.CurrentUser.CreateSubKey(RunKey))
                        k.SetValue(RunName, "\"" + Application.ExecutablePath + "\" --autostart");
                AutoStartCheck.MarkEnabled();
                Log.Write(shortcut ? "已开启开机自动启动（当前用户启动文件夹）" : "已开启开机自动启动（传统启动项回退）");
            }
            else
            {
                DeleteRunAutoStart();
                if (File.Exists(AutoStartShortcutPath)) File.Delete(AutoStartShortcutPath);
                Log.Write(IsAutoStart() ? "关闭开机自动启动失败，启动项仍存在" : "已关闭开机自动启动");
            }
        }
        catch (Exception ex) { Log.Write("设置开机自动启动失败：" + ex.Message); }
        autoStartItem.Checked = IsAutoStart();
    }

    // Monitor layout in one string (device names, bounds in physical pixels, which one is primary): compared to notice changes
    static string ScreensSignature()
    {
        var sb = new StringBuilder();
        foreach (Screen s in Screen.AllScreens) sb.Append(s.DeviceName).Append(s.Bounds).Append(s.Primary ? "*" : "").Append(';');
        return sb.ToString();
    }

    // One wallpaper window per monitor. Runs at startup, after a window was destroyed and when the monitor layout changes:
    // windows whose monitor is gone are closed, the others are moved to their monitor's current bounds, monitors without a window get one
    void SyncForms()
    {
        nextStart = DateTime.MaxValue;
        if (!ThemeAllowed(Settings.Theme)) Settings.Theme = ThemeAllowed("beach") ? "beach" : "meadow";
        string page = ThemeAllowed(Settings.Theme) ? Themes.PageFor(pageDir, Settings.Theme) : null;
        if (page == null)
        {
            Log.Write("没有可加载的已授权主题，5 秒后重试");
            nextStart = DateTime.Now.AddSeconds(5);
            return;
        }
        Screen[] screens = Screen.AllScreens;
        syncedScreens = pendingScreens = ScreensSignature();
        foreach (WallpaperForm f in forms.ToArray())
        {
            Screen on = null;
            foreach (Screen s in screens) if (s.DeviceName == f.Device) on = s;
            if (on != null) { f.Place(on.Bounds); continue; }
            forms.Remove(f);                             // removed first, so that OnFormGone does not take it for a window destroyed by the system
            Log.Write("Monitor " + f.Device + " is gone: closing its wallpaper window");
            f.Shutdown();
        }
        foreach (Screen s in screens)
        {
            bool have = false;
            foreach (WallpaperForm f in forms) if (f.Device == s.DeviceName) have = true;
            if (have) continue;
            var form = new WallpaperForm(pageDir, page, manualPause, s.DeviceName, s.Bounds, icons);
            form.SettingsJson = SettingsMessage;
            form.IconsChanged += delegate(string json) { if (settingsWin != null && form == PrimaryForm()) settingsWin.Post(json); };
            form.RecordProgress += delegate(string p) { if (settingsWin != null) settingsWin.Post("{\"t\":\"recProgress\",\"p\":" + p + "}"); };
            form.HandleDestroyed += OnFormGone;
            forms.Add(form);
            form.Show();
        }
    }

    void OnFormGone(object sender, EventArgs e)
    {
        var f = (WallpaperForm)sender;
        dead.Add(f);                                     // disposed later from the timer, to avoid re-entrancy inside the destroy callback
        if (!forms.Remove(f)) return;                    // closed on purpose (its monitor is gone)
        if (exiting) return;
        if (f.Fatal) { Exit(); return; }
        if (nextStart != DateTime.MaxValue) return;      // Explorer destroys the windows of all monitors together: that is one rebuild, already scheduled

        // Destroyed repeatedly within 1 minute: stop retrying, to avoid fighting with Explorer
        restarts.Enqueue(DateTime.Now);
        while (restarts.Count > 0 && (DateTime.Now - restarts.Peek()).TotalSeconds > 60) restarts.Dequeue();
        if (restarts.Count > 5)
        {
            Log.Write("壁纸窗口 1 分钟内被销毁超过 5 次，停止重试");
            MessageBox.Show(I18n.T("errRebuilt") + "\n\n" + I18n.T("errSeeLog", "path", Log.FilePath), InstallProfile.AppName);
            Exit();
            return;
        }
        Log.Write("壁纸窗口被销毁（资源管理器重建了壁纸层），1 秒后重新挂载");
        nextStart = DateTime.Now.AddSeconds(1);
    }

    // Every 400 ms: keep every window on its monitor and in the right layer, read the desktop icons once and give each monitor its own
    void PollIcons()
    {
        if (exiting || forms.Count == 0) return;
        foreach (WallpaperForm f in forms.ToArray()) f.EnsurePlacement();
        bool visible;
        List<Native.RECT> rects = icons.Read(out visible);
        if (rects == null) return;
        foreach (WallpaperForm f in forms.ToArray()) f.SetIcons(rects, visible);
    }

    // Monitor plugged in / unplugged, resolution or arrangement changed. The layout changes in several steps, so wait until two ticks in a row see the same one
    void WatchScreens()
    {
        string now = ScreensSignature();
        if (now == syncedScreens || now != pendingScreens) { pendingScreens = now; return; }
        Log.Write("Monitor layout changed: " + now);
        Size preview = previewScreen;
        SyncForms();
        if (settingsWin == null) return;
        WallpaperForm primary = PrimaryForm();
        if (Screen.PrimaryScreen.Bounds.Size != preview) PostInit();          // the preview is laid out at the primary monitor's size
        else if (primary != null && primary.LastIcons != "") settingsWin.Post(primary.LastIcons);
    }

    void Watch()
    {
        WallpaperForm[] gone = dead.ToArray();
        dead.Clear();
        foreach (WallpaperForm f in gone) { try { f.Dispose(); } catch { } }
        if (exitEvent.WaitOne(0)) { Exit(); return; }
        if (menuEvent.WaitOne(0)) ShowMenu();
        if (settingsEvent.WaitOne(0)) OpenSettings();
        if (DateTime.Now >= saveDue) { saveDue = DateTime.MaxValue; Settings.Save(); }
        if (exiting) return;
        if (DateTime.Now >= nextStart) SyncForms();
        else if (nextStart == DateTime.MaxValue) WatchScreens();
    }

    void Exit()
    {
        if (exiting) return;
        exiting = true;
        watch.Stop();
        iconTimer.Stop();
        if (saveDue != DateTime.MaxValue) Settings.Save();
        if (settingsWin != null) { try { settingsWin.Close(); } catch { } }
        hotkey.Dispose();
        tray.Visible = false;
        foreach (WallpaperForm f in forms.ToArray()) f.Shutdown();
        icons.Dispose();
        Log.Write("退出");
        ExitThread();
    }
}

// Hidden window that receives the global hotkey (message-only, never shown)
class HotkeyWindow : NativeWindow, IDisposable
{
    public event EventHandler Pressed;
    bool registered;

    public HotkeyWindow()
    {
        var cp = new CreateParams();
        cp.Parent = new IntPtr(-3);                     // HWND_MESSAGE: message-only window
        CreateHandle(cp);
    }

    public bool Register(uint modifiers, Keys key)
    {
        registered = Native.RegisterHotKey(Handle, 1, modifiers, (uint)key);
        return registered;
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x0312 /* WM_HOTKEY */ && Pressed != null) Pressed(this, EventArgs.Empty);
        base.WndProc(ref m);
    }

    public void Dispose()
    {
        if (registered) Native.UnregisterHotKey(Handle, 1);
        registered = false;
        if (Handle != IntPtr.Zero) DestroyHandle();
    }
}

// The tray and the settings window share the IconScape icon (drawn by tools/make-icon.ps1); the build script copies it into the program folder.
static class AppIcon
{
    public static Icon Create()
    {
        return new Icon(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, InstallProfile.AppName + ".ico"));
    }

    static GraphicsPath RoundRect(Rectangle r, int radius)
    {
        int d = radius * 2;
        var p = new GraphicsPath();
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }
}

// Settings window: an ordinary desktop window that shows prototype/settings.html in WebView2
class SettingsForm : Form
{
    readonly WebView2 web;
    readonly HostContext host;
    readonly string pageDir;

    public SettingsForm(string pageDir, HostContext host)
    {
        this.pageDir = pageDir;
        this.host = host;
        Text = InstallProfile.AppName;
        AccessibleName = InstallProfile.AppName;
        ShowIcon = true;
        Icon = AppIcon.Create();
        StartPosition = FormStartPosition.CenterScreen;
        float s = Native.GetDpiForSystem() / 96f;       // the process works in physical pixels, so window sizes must be scaled by hand
        ClientSize = new Size((int)(1120 * s), (int)(800 * s));     // themes in three columns on the left; on the right the preview on top and the parameters below
        MinimumSize = new Size((int)(940 * s), (int)(680 * s));
        BackColor = Color.White;

        web = new WebView2();
        web.Dock = DockStyle.Fill;
        web.DefaultBackgroundColor = BackColor;
        web.CreationProperties = new CoreWebView2CreationProperties();
        web.CreationProperties.UserDataFolder = Path.Combine(Log.DataDir, "WebView2");
        Controls.Add(web);
    }

    // Paint the (native) title bar the same color as the page background: settings.html follows the system light/dark mode (light #ffffff / dark #171717),
    // and the title bar takes the same color for the system mode. DWMWA_CAPTION_COLOR / dark mode need Win11; on older systems the call fails and the title bar stays as is
    void ThemeTitleBar()
    {
        bool light = true;
        try
        {
            object v = Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1);
            light = v == null || Convert.ToInt32(v) != 0;
        }
        catch { }
        int dark = light ? 0 : 1;
        int color = light ? 0x00FFFFFF : 0x00171717;      // COLORREF is 0x00BBGGRR
        Native.DwmSetWindowAttribute(Handle, 20, ref dark, 4);    // DWMWA_USE_IMMERSIVE_DARK_MODE: title text and buttons follow light/dark mode
        Native.DwmSetWindowAttribute(Handle, 35, ref color, 4);   // DWMWA_CAPTION_COLOR
    }
    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); ThemeTitleBar(); }
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x001A /* WM_SETTINGCHANGE */) ThemeTitleBar();   // the title bar follows when the system switches light/dark mode
        base.WndProc(ref m);
    }

    protected override async void OnShown(EventArgs e)
    {
        base.OnShown(e);
        try
        {
            await web.EnsureCoreWebView2Async(null);
            if (IsDisposed) return;
            var core = web.CoreWebView2;
            core.SetVirtualHostNameToFolderMapping("app.local", pageDir, CoreWebView2HostResourceAccessKind.Allow);
            core.Settings.AreDefaultContextMenusEnabled = false;
            core.Settings.IsStatusBarEnabled = false;
            core.Settings.IsZoomControlEnabled = false;
            core.WebMessageReceived += delegate(object s, CoreWebView2WebMessageReceivedEventArgs a)
            {
                try { host.OnSettingsMessage(a.TryGetWebMessageAsString()); }
                catch (Exception ex) { Log.Write("处理设置消息失败：" + ex.Message); }
            };
            string settingsUrl = "https://app.local/settings.html?v=" + Uri.EscapeDataString(Application.ProductVersion);
            Log.Write("设置页面：" + settingsUrl);
            core.Navigate(settingsUrl);
        }
        catch (Exception ex)
        {
            Log.Write("设置窗口启动失败：" + ex);
            MessageBox.Show(I18n.T("errSettings", "msg", ex.Message), InstallProfile.AppName);
            Close();
        }
    }

    public void Post(string json)
    {
        // The settings window is temporary: if its WebView2 is gone just skip the message (closing and reopening recovers); do not throw back into the wallpaper's polling
        try { if (!IsDisposed && web.CoreWebView2 != null) web.CoreWebView2.PostWebMessageAsString(json); }
        catch { }
    }

    // Folder holding the shared images / clips: mapped to https://share.local/ so the settings page can show and play them directly
    bool shareMapped;
    public void MapShareFolder(string dir)
    {
        if (shareMapped || IsDisposed || web.CoreWebView2 == null) return;
        web.CoreWebView2.SetVirtualHostNameToFolderMapping("share.local", dir, CoreWebView2HostResourceAccessKind.Allow);
        shareMapped = true;
    }
}

class WallpaperForm : Form
{
    readonly WebView2 web;
    readonly System.Windows.Forms.Timer fgTimer;
    readonly string pageDir;
    readonly IconReader reader;                         // shared with the windows of the other monitors; owned by HostContext
    Rectangle screen;                                   // this window's monitor: physical pixels, virtual-screen coordinates
    IntPtr parentHwnd, insertAfter;
    string lastIcons = "";
    int lastPause = -1;
    bool manualPause, shuttingDown;

    public readonly string Device;                      // device name of the monitor (\\.\DISPLAY1 …): tells the windows apart across layout changes
    public bool Fatal { get; private set; }

    string page;                                        // page of the current theme ("page" in themes.json)
    public Func<string> SettingsJson;                   // settings message sent first when the page is ready
    public event Action<string> IconsChanged;           // forwarded to the settings window preview when the icons change
    public string LastIcons { get { return lastIcons; } }
    protected override bool ShowWithoutActivation { get { return true; } }

    public WallpaperForm(string pageDir, string page, bool manualPause, string device, Rectangle bounds, IconReader reader)
    {
        this.pageDir = pageDir;
        this.page = page;
        this.manualPause = manualPause;
        this.reader = reader;
        Device = device;
        screen = bounds;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        BackColor = Color.FromArgb(26, 163, 196);
        Text = "IconScapeWindow";

        web = new WebView2();
        web.Dock = DockStyle.Fill;
        web.DefaultBackgroundColor = BackColor;
        web.CreationProperties = new CoreWebView2CreationProperties();
        web.CreationProperties.UserDataFolder = Path.Combine(Log.DataDir, "WebView2");
        Controls.Add(web);

        fgTimer = new System.Windows.Forms.Timer();
        fgTimer.Interval = 500;
        fgTimer.Tick += delegate { PollForeground(); };
    }

    public void SetManualPause(bool v) { manualPause = v; PollForeground(); }

    // ---- One-click share: ask the page to draw a desktop picture with the icons pixelated (the page takes no screenshot; it only uses the icon positions) ----
    Action<string, string, string> snapshotDone;           // (thumbnail, full PNG, error message)
    System.Windows.Forms.Timer snapshotTimeout;
    public void RequestSnapshot(Action<string, string, string> done)
    {
        if (web.CoreWebView2 == null) { done(null, null, I18n.T("errNotReady")); return; }
        if (snapshotDone != null) { done(null, null, I18n.T("errBusyImage")); return; }
        snapshotDone = done;
        snapshotTimeout = new System.Windows.Forms.Timer();
        snapshotTimeout.Interval = 20000;
        snapshotTimeout.Tick += delegate { FinishSnapshot(null, null, I18n.T("errImageTimeout")); };
        snapshotTimeout.Start();
        try { web.CoreWebView2.PostWebMessageAsString("{\"t\":\"snapshot\"}"); }
        catch (InvalidOperationException ex) { FinishSnapshot(null, null, I18n.T("errNotReady")); WebDead(ex); }
        catch (COMException ex) { FinishSnapshot(null, null, I18n.T("errNotReady")); WebDead(ex); }
    }
    void OnSnapshot(string msg)
    {
        string[] p = msg.Split(new[] { '|' }, 3);
        if (p.Length < 3) FinishSnapshot(null, null, I18n.T("errBadData"));
        else if (p[1] == "error") FinishSnapshot(null, null, p[2]);
        else FinishSnapshot(p[1], p[2], null);
    }
    void FinishSnapshot(string thumb, string png, string err)
    {
        if (snapshotTimeout != null) { snapshotTimeout.Stop(); snapshotTimeout.Dispose(); snapshotTimeout = null; }
        var done = snapshotDone;
        snapshotDone = null;
        if (done != null) done(thumb, png, err);
    }

    // ---- Share animation: record the theme animation with the current icon layout, send progress along the way, then send "record|format|poster|full video" ----
    Action<string, string, string, string> recordDone;    // (format, poster, full video, error message)
    System.Windows.Forms.Timer recordTimeout;
    public event Action<string> RecordProgress;            // 0..1 (as a string)
    public void RequestRecording(Action<string, string, string, string> done)
    {
        if (web.CoreWebView2 == null) { done(null, null, null, I18n.T("errNotReady")); return; }
        if (recordDone != null) { done(null, null, null, I18n.T("errBusyVideo")); return; }
        recordDone = done;
        recordTimeout = new System.Windows.Forms.Timer();
        recordTimeout.Interval = 45000;
        recordTimeout.Tick += delegate { FinishRecord(null, null, null, I18n.T("errVideoTimeout")); };
        recordTimeout.Start();
        try { web.CoreWebView2.PostWebMessageAsString("{\"t\":\"record\"}"); }
        catch (InvalidOperationException ex) { FinishRecord(null, null, null, I18n.T("errNotReady")); WebDead(ex); }
        catch (COMException ex) { FinishRecord(null, null, null, I18n.T("errNotReady")); WebDead(ex); }
    }
    void OnRecord(string msg)
    {
        string[] p = msg.Split(new[] { '|' }, 4);
        if (p.Length >= 3 && p[1] == "error") FinishRecord(null, null, null, msg.Substring(13));
        else if (p.Length < 4) FinishRecord(null, null, null, I18n.T("errBadData"));
        else FinishRecord(p[1], p[2], p[3], null);
    }
    void FinishRecord(string mime, string poster, string video, string err)
    {
        if (recordTimeout != null) { recordTimeout.Stop(); recordTimeout.Dispose(); recordTimeout = null; }
        var done = recordDone;
        recordDone = null;
        if (done != null) done(mime, poster, video, err);
    }
    public void Reload()
    {
        if (web.CoreWebView2 == null) return;
        try { web.CoreWebView2.Reload(); }
        catch (InvalidOperationException ex) { WebDead(ex); }
        catch (COMException ex) { WebDead(ex); }
    }
    public void Post(string json)
    {
        if (web.CoreWebView2 == null) return;
        try { web.CoreWebView2.PostWebMessageAsString(json); }
        catch (InvalidOperationException ex) { WebDead(ex); }
        catch (COMException ex) { WebDead(ex); }
    }

    // After a background WebView2 runtime update / the browser process being killed, CoreWebView2 is non-null but already disposed, and every call throws
    // (the null checks above do not catch this state). Handle it through the existing "wallpaper window destroyed by the system" path: tear down this window and HostContext rebuilds it after 1 second
    void WebDead(Exception ex)
    {
        if (shuttingDown) return;
        Log.Write("WebView2 失效（运行时更新或进程退出），重新挂载壁纸窗口：" + ex.Message);
        Shutdown();
    }
    string PageUrl { get { return "https://app.local/" + page + "?wallpaper=1"; } }

    // Switch theme: load the other page; once the new page is ready it receives the settings and icons again
    public void LoadPage(string newPage)
    {
        page = newPage;
        if (web.CoreWebView2 == null) return;
        try { web.CoreWebView2.Navigate(PageUrl); }
        catch (InvalidOperationException ex) { WebDead(ex); }
        catch (COMException ex) { WebDead(ex); }
    }

    protected override async void OnShown(EventArgs e)
    {
        base.OnShown(e);
        try
        {
            if (!File.Exists(Path.Combine(pageDir, page)))
            {
                Fail(I18n.T("errNoPage", "path", Path.Combine(pageDir, page)));
                return;
            }
            if (!AttachToDesktop())
            {
                Fail(I18n.T("errNoDesktop"));
                return;
            }
            await web.EnsureCoreWebView2Async(null);
            if (shuttingDown || IsDisposed) return;
            var core = web.CoreWebView2;
            core.SetVirtualHostNameToFolderMapping("app.local", pageDir, CoreWebView2HostResourceAccessKind.Allow);
            core.Settings.AreDefaultContextMenusEnabled = false;
            core.Settings.AreDevToolsEnabled = true;
            core.Settings.IsStatusBarEnabled = false;
            // Page ready (it sends "ready"): send the settings first, then the icons and pause state (the shoreline depends on the shore distance in the settings)
            // One-click share: when the page has drawn the share image it sends "snapshot|thumbnail|full PNG" (both data URLs; the full image is large, so it does not go through JSON)
            core.WebMessageReceived += delegate(object s, CoreWebView2WebMessageReceivedEventArgs a)
            {
                string msg = null;
                try { msg = a.TryGetWebMessageAsString(); } catch { }
                if (msg != null && msg.StartsWith("snapshot|")) { OnSnapshot(msg); return; }
                if (msg != null && msg.StartsWith("recprogress|")) { if (RecordProgress != null) RecordProgress(msg.Substring(12)); return; }
                if (msg != null && msg.StartsWith("record|")) { OnRecord(msg); return; }
                if (SettingsJson != null) core.PostWebMessageAsString(SettingsJson());
                lastIcons = ""; lastPause = -1; PollIcons(); PollForeground();
            };
            core.Navigate(PageUrl);
            fgTimer.Start();
            Log.Write("WebView2 就绪（" + Device + "）：" + core.Environment.BrowserVersionString);
        }
        catch (Exception ex)
        {
            if (shuttingDown || IsDisposed) return;       // window destroyed by the system during startup: leave the retry to HostContext
            Log.Write("启动失败：" + ex);
            Fail(I18n.T("errStart", "msg", ex.Message));
        }
    }

    static bool failShown;                              // the same failure on every monitor is reported once
    void Fail(string msg)
    {
        Log.Write(msg);
        Fatal = true;
        if (!failShown)
        {
            failShown = true;
            MessageBox.Show(msg + "\n\n" + I18n.T("errSeeLog", "path", Log.FilePath), InstallProfile.AppName);
        }
        Shutdown();
    }

    // ---------------------------------------------------------------- Attaching to the wallpaper layer
    // Two desktop structures:
    //   · From Windows 11 24H2 (the "raised desktop"): under Progman come the icon layer (SHELLDLL_DefView) → the system wallpaper layer (WorkerW).
    //     The system wallpaper layer is destroyed and rebuilt whenever the wallpaper changes (slideshow / Spotlight), so we do not attach inside it; instead we are a
    //     layered child window of Progman (WS_EX_LAYERED, alpha 255), placed right below the icon layer and above the system wallpaper layer, and we keep enforcing that order.
    //     (Progman has no surface that ordinary child windows can draw on, so it must be a layered window; layered child windows require app.manifest to declare Win8+ support)
    //   · Older versions: the icon layer sits in some top-level WorkerW, immediately followed by the top-level WorkerW that paints the wallpaper → attach inside that WorkerW
    public static string AttachMode = "progman";
    static readonly List<IntPtr> Attached = new List<IntPtr>();   // the attached wallpaper windows of all monitors (siblings under the same parent)
    IntPtr attachedHandle;
    bool raised;
    IntPtr zAnchor;                                     // the window we must stay right below (icon list / icon layer)
    IntPtr winEventHook;
    Native.WinEventDelegate winEventProc;               // keep a reference so the GC does not collect it

    static IntPtr FindClassicWorker()
    {
        IntPtr host = IntPtr.Zero;
        Native.EnumWindows(delegate(IntPtr h, IntPtr l)
        {
            if (Native.FindWindowEx(h, IntPtr.Zero, "SHELLDLL_DefView", null) != IntPtr.Zero) { host = h; return false; }
            return true;
        }, IntPtr.Zero);
        return host != IntPtr.Zero ? Native.FindWindowEx(IntPtr.Zero, host, "WorkerW", null) : IntPtr.Zero;
    }

    // Ask Explorer to create the wallpaper layer (send 0xD,1 only once; sending 0xD,0 afterwards would delete the layer just created), waiting up to 2 seconds
    static void RequestWorkerW(IntPtr progman, Func<bool> ready)
    {
        IntPtr res;
        Native.SendMessageTimeout(progman, 0x052C, new IntPtr(0xD), new IntPtr(1), 0, 1000, out res);
        for (int i = 0; i < 20 && !ready(); i++) Thread.Sleep(100);
    }

    bool AttachToDesktop()
    {
        // screen: this monitor's bounds; the process is DPI-aware → physical pixels
        IntPtr progman = Native.FindWindow("Progman", null);
        if (progman == IntPtr.Zero) { Log.Write("找不到 Progman"); return false; }
        IntPtr defView = Native.FindWindowEx(progman, IntPtr.Zero, "SHELLDLL_DefView", null);
        string mode;
        raised = defView != IntPtr.Zero;

        if (raised)
        {
            if (Native.FindWindowEx(progman, IntPtr.Zero, "WorkerW", null) == IntPtr.Zero)
                RequestWorkerW(progman, delegate { return Native.FindWindowEx(progman, IntPtr.Zero, "WorkerW", null) != IntPtr.Zero; });
            IntPtr listView = Native.FindWindowEx(defView, IntPtr.Zero, "SysListView32", null);
            if (AttachMode == "legacy")
            {
                parentHwnd = Native.FindWindowEx(progman, IntPtr.Zero, "WorkerW", null);
                if (parentHwnd == IntPtr.Zero) { Log.Write("找不到 WorkerW"); return false; }
                insertAfter = IntPtr.Zero; raised = false; mode = "24H2+ 旧做法：WorkerW 子窗口";
            }
            else if (AttachMode == "defview" && listView != IntPtr.Zero)
            {
                // Experimental: attach inside the icon layer, below the icon list (not reordered when the wallpaper changes, but in practice nothing gets drawn on 24H2)
                parentHwnd = defView; insertAfter = listView; zAnchor = listView;
                mode = "24H2+：图标层（DefView）的分层子窗口，位于图标列表之下";
            }
            else
            {
                parentHwnd = progman; insertAfter = defView; zAnchor = defView;
                mode = "24H2+：Progman 的分层子窗口，位于图标层之下";
            }
            if (raised)
            {
                int ex = Native.GetWindowLong(Handle, Native.GWL_EXSTYLE);
                Native.SetWindowLong(Handle, Native.GWL_EXSTYLE, ex | Native.WS_EX_LAYERED);
                Native.SetLayeredWindowAttributes(Handle, 0, 255, Native.LWA_ALPHA);
            }
        }
        else
        {
            IntPtr worker = FindClassicWorker();
            if (worker == IntPtr.Zero)
            {
                RequestWorkerW(progman, delegate { return FindClassicWorker() != IntPtr.Zero; });
                worker = FindClassicWorker();
            }
            if (worker == IntPtr.Zero) { Log.Write("找不到 WorkerW / SHELLDLL_DefView"); return false; }
            parentHwnd = worker; insertAfter = IntPtr.Zero; mode = "经典：顶层 WorkerW 子窗口";
        }

        int style = Native.GetWindowLong(Handle, Native.GWL_STYLE);
        style = (style & ~(Native.WS_POPUP | Native.WS_CAPTION | Native.WS_THICKFRAME)) | Native.WS_CHILD | Native.WS_VISIBLE;
        Native.SetWindowLong(Handle, Native.GWL_STYLE, style);
        Native.SetParent(Handle, parentHwnd);
        attachedHandle = Handle;
        Attached.Add(attachedHandle);

        // The parent (Progman / WorkerW) spans all monitors: place this window over its own monitor
        var pt = new Native.POINT { X = screen.X, Y = screen.Y };
        Native.ScreenToClient(parentHwnd, ref pt);
        Native.SetWindowPos(Handle, insertAfter, pt.X, pt.Y, screen.Width, screen.Height,
            Native.SWP_NOACTIVATE | Native.SWP_SHOWWINDOW | Native.SWP_FRAMECHANGED);
        EnsureZOrder();

        if (raised)
        {
            // Fix the order as soon as Explorer creates / reorders the wallpaper layer (when the wallpaper changes it inserts the new WorkerW above us)
            uint pid;
            Native.GetWindowThreadProcessId(progman, out pid);
            winEventProc = delegate(IntPtr hook, uint ev, IntPtr hwnd, int idObject, int idChild, uint thread, uint time)
            {
                if (idObject == 0 && !shuttingDown && IsHandleCreated) EnsureZOrder();
            };
            winEventHook = Native.SetWinEventHook(0x8000 /* OBJECT_CREATE */, 0x8004 /* OBJECT_REORDER */, IntPtr.Zero,
                winEventProc, pid, 0, 0 /* WINEVENT_OUTOFCONTEXT */);
        }
        Log.Write(string.Format("已挂载（{0}），屏幕 {1} {2}", mode, Device, screen));
        return true;
    }

    // Cover the monitor. Called again when the monitor layout changes (resolution, arrangement, another monitor added or removed)
    public void Place(Rectangle bounds)
    {
        if (bounds != screen) { screen = bounds; lastIcons = ""; lastPause = -1; }   // icons and pause are relative to the monitor: send them again
        if (attachedHandle == IntPtr.Zero || shuttingDown || !IsHandleCreated) return;
        var pt = new Native.POINT { X = screen.X, Y = screen.Y };
        Native.ScreenToClient(parentHwnd, ref pt);
        Native.SetWindowPos(Handle, IntPtr.Zero, pt.X, pt.Y, screen.Width, screen.Height, Native.SWP_NOACTIVATE | Native.SWP_NOZORDER);
    }

    // Explorer resizes the parent a moment after the layout changes, and its child windows shift with it: put ours back over its monitor (only when it moved)
    int placeFixes;
    public void EnsurePlacement()
    {
        if (attachedHandle == IntPtr.Zero || shuttingDown || !IsHandleCreated) return;
        Native.RECT r;
        if (Native.GetWindowRect(Handle, out r) && (r.Left != screen.Left || r.Top != screen.Top || r.Right != screen.Right || r.Bottom != screen.Bottom))
        {
            Place(screen);
            if (++placeFixes <= 20) Log.Write("Wallpaper window moved back over its monitor: " + Device + " " + screen);
        }
        EnsureZOrder();
    }

    // Keep the order: the wallpaper windows of all monitors form one block right below zAnchor (icon list / icon layer), in any order;
    // with the Progman attach mode also push the system wallpaper layer to the very bottom (only fixed when disturbed)
    int zFixes;
    void EnsureZOrder()
    {
        if (!raised || zAnchor == IntPtr.Zero || !Native.IsWindow(zAnchor)) return;
        bool fixedAny = false, inBlock = false;
        for (IntPtr w = Native.GetWindow(zAnchor, 2 /* GW_HWNDNEXT */); w != IntPtr.Zero && Attached.Contains(w); w = Native.GetWindow(w, 2))
            if (w == Handle) { inBlock = true; break; }
        if (!inBlock)
        {
            Native.SetWindowPos(Handle, zAnchor, 0, 0, 0, 0, Native.SWP_NOMOVE | Native.SWP_NOSIZE | Native.SWP_NOACTIVATE);
            fixedAny = true;
        }
        if (AttachMode == "progman")
        {
            for (IntPtr w = Native.FindWindowEx(parentHwnd, IntPtr.Zero, "WorkerW", null); w != IntPtr.Zero;
                 w = Native.FindWindowEx(parentHwnd, w, "WorkerW", null))
            {
                if (Native.GetWindow(w, 2) != IntPtr.Zero)   // not at the bottom → push it to the bottom
                {
                    Native.SetWindowPos(w, new IntPtr(1) /* HWND_BOTTOM */, 0, 0, 0, 0, Native.SWP_NOMOVE | Native.SWP_NOSIZE | Native.SWP_NOACTIVATE);
                    fixedAny = true;
                }
            }
        }
        if (fixedAny && ++zFixes <= 20) Log.Write("修正了桌面层级（资源管理器重排了窗口）");
    }

    // ---------------------------------------------------------------- Reading the desktop icons
    // The page just became ready: read the icons right away instead of waiting for the next shared poll
    void PollIcons()
    {
        bool visible;
        List<Native.RECT> rects = reader.Read(out visible);
        if (rects != null) SetIcons(rects, visible);
    }

    // Icons of the whole desktop (screen coordinates) → the ones that touch this monitor, relative to its top-left corner; sent to the page only when they change
    public void SetIcons(List<Native.RECT> rects, bool visible)
    {
        if (web.CoreWebView2 == null || shuttingDown) return;
        var sb = new StringBuilder();
        sb.Append("{\"t\":\"icons\",\"vis\":").Append(visible ? "true" : "false").Append(",\"r\":[");
        int n = 0;
        foreach (Native.RECT r in rects)
        {
            if (r.Right <= screen.Left || r.Left >= screen.Right || r.Bottom <= screen.Top || r.Top >= screen.Bottom) continue;
            if (n++ > 0) sb.Append(',');
            sb.Append('[').Append(r.Left - screen.X).Append(',').Append(r.Top - screen.Y).Append(',')
              .Append(r.Right - screen.X).Append(',').Append(r.Bottom - screen.Y).Append(']');
        }
        sb.Append("]}");
        string json = sb.ToString();
        if (json == lastIcons) return;
        lastIcons = json;
        if (IconsChanged != null) IconsChanged(json);
        Post(json);
        Log.Write(string.Format("图标变化（{2}）：{0} 个，可见={1}", n, visible, Device));
    }

    // ---------------------------------------------------------------- Pause while a maximized / fullscreen window hides this monitor
    void PollForeground()
    {
        if (web.CoreWebView2 == null) return;
        bool pause = manualPause;
        string pauseBy = "";
        if (!pause)
        {
            // The foreground window first (the usual case); otherwise any window that hides this monitor: with several monitors
            // one often stays covered by a maximized window while the user works on another
            IntPtr fg = Native.GetForegroundWindow();
            if (fg != IntPtr.Zero && Hides(fg, true, out pauseBy)) pause = true;
            else
            {
                string by = "";
                Native.EnumWindows(delegate(IntPtr w, IntPtr l)
                {
                    if (w == fg || !Hides(w, false, out by)) return true;
                    pause = true;
                    return false;
                }, IntPtr.Zero);
                pauseBy = by;
            }
        }
        int p = pause ? 1 : 0;
        if (p == lastPause) return;
        lastPause = p;
        Post("{\"t\":\"pause\",\"v\":" + (pause ? "true" : "false") + "}");
        Log.Write(pause ? "暂停（" + Device + "：有窗口最大化 / 全屏，或手动暂停）" + (pauseBy == "" ? "" : "，窗口类 " + pauseBy) : "继续播放（" + Device + "）");
    }

    // Does this top-level window hide the monitor's wallpaper? It must be visible, not minimized, not cloaked (other virtual desktop, suspended app),
    // not part of the shell, centered on this monitor, and either maximized or covering the whole monitor (fullscreen).
    // A window that is not in the foreground counts as fullscreen only if it is an ordinary opaque one:
    // overlays (transparent to the mouse, layered, tool or no-activate windows) span the screen without hiding anything
    bool Hides(IntPtr w, bool foreground, out string cls)
    {
        cls = "";
        if (w == Handle || !Native.IsWindowVisible(w) || Native.IsIconic(w)) return false;
        Native.RECT wr;
        if (!Native.GetWindowRect(w, out wr) || !screen.Contains((wr.Left + wr.Right) / 2, (wr.Top + wr.Bottom) / 2)) return false;
        bool zoomed = Native.IsZoomed(w);
        if (!zoomed && !(wr.Left <= screen.Left && wr.Top <= screen.Top && wr.Right >= screen.Right && wr.Bottom >= screen.Bottom)) return false;
        int cloaked = 0;
        if (Native.DwmGetWindowAttribute(w, 14 /* DWMWA_CLOAKED */, out cloaked, 4) == 0 && cloaked != 0) return false;
        var sb = new StringBuilder(64);
        Native.GetClassName(w, sb, 64);
        string c = sb.ToString();
        if (c == "Progman" || c == "WorkerW" || c == "Shell_TrayWnd" || c == "Shell_SecondaryTrayWnd") return false;
        if (!zoomed && !foreground
            && (Native.GetWindowLong(w, Native.GWL_EXSTYLE) & (Native.WS_EX_TRANSPARENT | Native.WS_EX_TOOLWINDOW | Native.WS_EX_NOACTIVATE | Native.WS_EX_LAYERED)) != 0)
            return false;
        cls = c;
        return true;
    }

    // ---------------------------------------------------------------- Exit: tear down the window and let Explorer repaint the original wallpaper
    public void Shutdown()
    {
        if (shuttingDown) return;
        shuttingDown = true;
        fgTimer.Stop();
        Attached.Remove(attachedHandle);
        IntPtr parent = parentHwnd;
        try { web.Dispose(); } catch { }
        if (IsHandleCreated) { Native.SetParent(Handle, IntPtr.Zero); Hide(); }
        // Do not touch the wallpaper settings (slideshow / Spotlight wallpapers are unaffected); just let Explorer repaint
        if (parent != IntPtr.Zero && Native.IsWindow(parent))
            Native.RedrawWindow(parent, IntPtr.Zero, IntPtr.Zero, 0x1 | 0x4 | 0x80 | 0x100);
        Close();
    }

    protected override void OnHandleDestroyed(EventArgs e)
    {
        if (winEventHook != IntPtr.Zero) { Native.UnhookWinEvent(winEventHook); winEventHook = IntPtr.Zero; }
        fgTimer.Stop();
        Attached.Remove(attachedHandle);
        attachedHandle = IntPtr.Zero;
        base.OnHandleDestroyed(e);
    }
}

// Reads the icon rectangles (icon + label, physical pixels, screen coordinates) through cross-process messages to the desktop ListView.
// The desktop has a single ListView spanning all monitors, so one reader serves every wallpaper window
class IconReader : IDisposable
{
    IntPtr listView, proc, mem;

    static IntPtr FindListView()
    {
        IntPtr defView = IntPtr.Zero;
        IntPtr progman = Native.FindWindow("Progman", null);
        if (progman != IntPtr.Zero) defView = Native.FindWindowEx(progman, IntPtr.Zero, "SHELLDLL_DefView", null);
        if (defView == IntPtr.Zero)
        {
            Native.EnumWindows(delegate(IntPtr h, IntPtr l)
            {
                IntPtr d = Native.FindWindowEx(h, IntPtr.Zero, "SHELLDLL_DefView", null);
                if (d != IntPtr.Zero) { defView = d; return false; }
                return true;
            }, IntPtr.Zero);
        }
        return defView == IntPtr.Zero ? IntPtr.Zero : Native.FindWindowEx(defView, IntPtr.Zero, "SysListView32", null);
    }

    bool Open()
    {
        Close();
        listView = FindListView();
        if (listView == IntPtr.Zero) return false;
        uint pid;
        Native.GetWindowThreadProcessId(listView, out pid);
        proc = Native.OpenProcess(0x0008 | 0x0010 | 0x0020, false, pid);   // VM_OPERATION | VM_READ | VM_WRITE
        if (proc == IntPtr.Zero) return false;
        mem = Native.VirtualAllocEx(proc, IntPtr.Zero, new IntPtr(64), 0x1000 | 0x2000, 0x04);
        return mem != IntPtr.Zero;
    }

    public List<Native.RECT> Read(out bool visible)
    {
        visible = false;
        if (listView == IntPtr.Zero || mem == IntPtr.Zero || !Native.IsWindow(listView)) { if (!Open()) return null; }
        visible = Native.IsWindowVisible(listView);
        var result = new List<Native.RECT>();
        if (!visible) return result;                   // the user hid the desktop icons → it is all sea
        int count = (int)Native.SendMessage(listView, 0x1004 /* LVM_GETITEMCOUNT */, IntPtr.Zero, IntPtr.Zero);
        var origin = new Native.POINT();
        Native.ClientToScreen(listView, ref origin);
        for (int i = 0; i < count; i++)
        {
            var r = new Native.RECT();                 // Left = LVIR_BOUNDS (0): the overall bounds of icon + label
            IntPtr n;
            if (!Native.WriteProcessMemory(proc, mem, ref r, 16, out n)) { Close(); return null; }
            Native.SendMessage(listView, 0x100E /* LVM_GETITEMRECT */, new IntPtr(i), mem);
            if (!Native.ReadProcessMemory(proc, mem, out r, 16, out n)) { Close(); return null; }
            r.Left += origin.X; r.Right += origin.X; r.Top += origin.Y; r.Bottom += origin.Y;
            result.Add(r);
        }
        return result;
    }

    void Close()
    {
        if (mem != IntPtr.Zero && proc != IntPtr.Zero) Native.VirtualFreeEx(proc, mem, IntPtr.Zero, 0x8000);
        if (proc != IntPtr.Zero) Native.CloseHandle(proc);
        mem = proc = IntPtr.Zero;
    }

    public void Dispose() { Close(); }
}

static class Native
{
    public const int GWL_STYLE = -16, GWL_EXSTYLE = -20, WS_EX_LAYERED = 0x00080000;
    public const int WS_EX_TRANSPARENT = 0x00000020, WS_EX_TOOLWINDOW = 0x00000080, WS_EX_NOACTIVATE = 0x08000000;
    public const uint LWA_ALPHA = 0x2, SWP_NOSIZE = 0x0001, SWP_NOMOVE = 0x0002, SWP_NOZORDER = 0x0004;
    public const uint MOD_ALT = 0x1, MOD_CONTROL = 0x2, MOD_NOREPEAT = 0x4000;
    public const int SW_SHOW = 5, SW_RESTORE = 9;
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr h, int id, uint modifiers, uint vk);
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int val, int size);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(int pid);
    [DllImport("user32.dll")] public static extern uint GetDpiForSystem();
    [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode)] public static extern bool WTSQuerySessionInformation(IntPtr server, int session, int infoClass, out IntPtr buffer, out int bytes);
    [DllImport("wtsapi32.dll")] public static extern void WTSFreeMemory(IntPtr p);
    public delegate void WinEventDelegate(IntPtr hook, uint ev, IntPtr hwnd, int idObject, int idChild, uint thread, uint time);
    [DllImport("user32.dll")] public static extern bool SetLayeredWindowAttributes(IntPtr h, uint key, byte alpha, uint flags);
    [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll")] public static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr mod, WinEventDelegate proc, uint pid, uint tid, uint flags);
    [DllImport("user32.dll")] public static extern bool UnhookWinEvent(IntPtr hook);
    public const int WS_CHILD = 0x40000000, WS_VISIBLE = 0x10000000, WS_POPUP = unchecked((int)0x80000000);
    public const int WS_CAPTION = 0x00C00000, WS_THICKFRAME = 0x00040000;
    public const uint SWP_NOACTIVATE = 0x0010, SWP_SHOWWINDOW = 0x0040, SWP_FRAMECHANGED = 0x0020;

    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SetParent(IntPtr child, IntPtr parent);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int index);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int index, int value);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool RedrawWindow(IntPtr h, IntPtr rect, IntPtr rgn, uint flags);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attribute, out int value, int size);
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr proc, IntPtr addr, IntPtr size, uint type, uint protect);
    [DllImport("kernel32.dll")] public static extern bool VirtualFreeEx(IntPtr proc, IntPtr addr, IntPtr size, uint type);
    [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr proc, IntPtr addr, ref RECT buf, int size, out IntPtr written);
    [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr proc, IntPtr addr, out RECT buf, int size, out IntPtr read);
}

// IconScape has its own name, data and instance identity (separate from Deskland Preview); isolated profiles support installation QA.
static class InstallProfile
{
    public const string AppName = "IconScape";
    public static readonly string Override = Environment.GetEnvironmentVariable("ICONSCAPE_PROFILE_DIR");
    public static readonly bool Isolated = !string.IsNullOrEmpty(Override);
    public static readonly string DataDir = Isolated ? Path.GetFullPath(Override) : Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), AppName);
    public static readonly string Suffix = MakeSuffix();
    static string MakeSuffix()
    {
        if (!Isolated) return "";
        using (var hash = System.Security.Cryptography.SHA256.Create())
            return "_" + BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(DataDir.ToUpperInvariant()))).Replace("-", "").Substring(0, 24);
    }

    // An installer may only close the instance using this exact executable path.
    public static int StopInstalled()
    {
        foreach (Process process in Process.GetProcessesByName(AppName))
        {
            using (process)
            {
                if (process.Id == Process.GetCurrentProcess().Id) continue;
                try
                {
                    if (!string.Equals(process.MainModule.FileName, Application.ExecutablePath, StringComparison.OrdinalIgnoreCase)) continue;
                    EventWaitHandle ev;
                    if (!EventWaitHandle.TryOpenExisting(Program.ExitEventName, out ev)) return 1;
                    using (ev) ev.Set();
                    if (!process.WaitForExit(10000)) return 1;
                }
                catch (InvalidOperationException) { }
                catch { return 1; }
            }
        }
        return 0;
    }
}
