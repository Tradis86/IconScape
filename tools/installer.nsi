Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "WinVer.nsh"
!include "FileFunc.nsh"
!include "StrFunc.nsh"
${UnStrStr}
; IconScape is a modified version of Deskland Preview (GPL-3.0): own name, icon, install folder and registry keys
Name "IconScape"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\IconScape"
InstallDirRegKey HKCU "Software\IconScape\Installer" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "IconScape"
VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=1033 "ProductName" "IconScape"
VIAddVersionKey /LANG=1033 "FileDescription" "IconScape Installer"
VIAddVersionKey /LANG=1033 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright 2026 Deskland authors and IconScape contributors"
!define MUI_ABORTWARNING
!define MUI_ICON "${PAYLOAD}\host\bin\IconScape.ico"
!define MUI_UNICON "${PAYLOAD}\host\bin\IconScape.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\host\bin\IconScape.exe"
!define MUI_FINISHPAGE_RUN_TEXT "$(LaunchApp)"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${PAYLOAD}\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Italian"
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "German"
!insertmacro MUI_LANGUAGE "SimpChinese"
LangString LaunchApp ${LANG_ENGLISH} "Launch IconScape"
LangString LaunchApp ${LANG_ITALIAN} "Avvia IconScape"
LangString LaunchApp ${LANG_SPANISH} "Iniciar IconScape"
LangString LaunchApp ${LANG_FRENCH} "Lancer IconScape"
LangString LaunchApp ${LANG_GERMAN} "IconScape starten"
LangString LaunchApp ${LANG_SIMPCHINESE} "启动 IconScape"
LangString AppFiles ${LANG_ENGLISH} "IconScape (based on Deskland Preview)"
LangString AppFiles ${LANG_ITALIAN} "IconScape (basato su Deskland Preview)"
LangString AppFiles ${LANG_SPANISH} "IconScape (basado en Deskland Preview)"
LangString AppFiles ${LANG_FRENCH} "IconScape (basé sur Deskland Preview)"
LangString AppFiles ${LANG_GERMAN} "IconScape (basiert auf Deskland Preview)"
LangString AppFiles ${LANG_SIMPCHINESE} "IconScape（基于 Deskland Preview）"
LangString DesktopShortcut ${LANG_ENGLISH} "Desktop shortcut"
LangString DesktopShortcut ${LANG_ITALIAN} "Collegamento sul desktop"
LangString DesktopShortcut ${LANG_SPANISH} "Acceso directo en el escritorio"
LangString DesktopShortcut ${LANG_FRENCH} "Raccourci sur le Bureau"
LangString DesktopShortcut ${LANG_GERMAN} "Desktopverknüpfung"
LangString DesktopShortcut ${LANG_SIMPCHINESE} "桌面快捷方式"
LangString NeedX64 ${LANG_ENGLISH} "64-bit Windows 10 or later is required."
LangString NeedX64 ${LANG_ITALIAN} "È richiesto Windows 10 o successivo a 64 bit."
LangString NeedX64 ${LANG_SPANISH} "Se necesita Windows 10 o posterior de 64 bits."
LangString NeedX64 ${LANG_FRENCH} "Windows 10 ou version ultérieure 64 bits est requis."
LangString NeedX64 ${LANG_GERMAN} "Windows 10 oder neuer (64 Bit) ist erforderlich."
LangString NeedX64 ${LANG_SIMPCHINESE} "需要 64 位 Windows 10 或更高版本。"
LangString CloseFailed ${LANG_ENGLISH} "Please exit IconScape and retry."
LangString CloseFailed ${LANG_ITALIAN} "Chiudi IconScape e riprova."
LangString CloseFailed ${LANG_SPANISH} "Cierra IconScape y vuelve a intentarlo."
LangString CloseFailed ${LANG_FRENCH} "Quittez IconScape et réessayez."
LangString CloseFailed ${LANG_GERMAN} "Beende IconScape und versuche es erneut."
LangString CloseFailed ${LANG_SIMPCHINESE} "请退出正在运行的 IconScape 后重试。"
LangString RuntimeFailed ${LANG_ENGLISH} "WebView2 setup did not complete. Connect to the internet, install Microsoft Edge WebView2 Runtime, and retry."
LangString RuntimeFailed ${LANG_ITALIAN} "L'installazione di WebView2 non è stata completata. Connettiti a Internet, installa Microsoft Edge WebView2 Runtime e riprova."
LangString RuntimeFailed ${LANG_SPANISH} "La instalación de WebView2 no se completó. Conéctate a Internet, instala Microsoft Edge WebView2 Runtime y vuelve a intentarlo."
LangString RuntimeFailed ${LANG_FRENCH} "L'installation de WebView2 n'a pas abouti. Connectez-vous à Internet, installez Microsoft Edge WebView2 Runtime, puis réessayez."
LangString RuntimeFailed ${LANG_GERMAN} "Die WebView2-Einrichtung wurde nicht abgeschlossen. Stelle eine Internetverbindung her, installiere Microsoft Edge WebView2 Runtime und versuche es erneut."
LangString RuntimeFailed ${LANG_SIMPCHINESE} "WebView2 安装未完成。请连接网络，安装 Microsoft Edge WebView2 Runtime 后重试。"
LangString InstallingRuntime ${LANG_ENGLISH} "Installing Microsoft Edge WebView2 Runtime (internet required)..."
LangString InstallingRuntime ${LANG_ITALIAN} "Installazione di Microsoft Edge WebView2 Runtime (serve Internet)..."
LangString InstallingRuntime ${LANG_SPANISH} "Instalando Microsoft Edge WebView2 Runtime (se necesita Internet)..."
LangString InstallingRuntime ${LANG_FRENCH} "Installation de Microsoft Edge WebView2 Runtime (Internet requis)..."
LangString InstallingRuntime ${LANG_GERMAN} "Microsoft Edge WebView2 Runtime wird installiert (Internet erforderlich)..."
LangString InstallingRuntime ${LANG_SIMPCHINESE} "正在安装 Microsoft Edge WebView2 Runtime（需要联网）..."

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "$(NeedX64)"
    SetErrorLevel 1
    Abort
  ${EndIf}
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_ICONSTOP "$(NeedX64)"
    SetErrorLevel 1
    Abort
  ${EndIf}
  SetShellVarContext current
  SetRegView 64
  !insertmacro MUI_LANGDLL_DISPLAY
FunctionEnd

Function CheckRuntime
  StrCpy $0 ""
  SetRegView 32
  ReadRegStr $0 HKLM "Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
  ${If} $0 == ""
    ReadRegStr $0 HKCU "Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
  ${EndIf}
  SetRegView 64
  ${If} $0 == ""
    ReadRegStr $0 HKCU "Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
  ${EndIf}
FunctionEnd

Section "$(AppFiles)" SecApp
  SectionIn RO
  Call CheckRuntime
  ${If} $0 == ""
  ${OrIf} $0 == "0.0.0.0"
    InitPluginsDir
    SetOutPath "$PLUGINSDIR"
    File /oname=MicrosoftEdgeWebview2Setup.exe "${BOOTSTRAPPER}"
    DetailPrint "$(InstallingRuntime)"
    ExecWait '"$PLUGINSDIR\MicrosoftEdgeWebview2Setup.exe" /silent /install' $1
    Call CheckRuntime
    ${If} $0 == ""
    ${OrIf} $0 == "0.0.0.0"
      MessageBox MB_ICONSTOP "$(RuntimeFailed)"
      SetErrorLevel 2
      Abort
    ${EndIf}
  ${EndIf}
  IfFileExists "$INSTDIR\host\bin\IconScape.exe" 0 closed
  ExecWait '"$INSTDIR\host\bin\IconScape.exe" --exit-installed' $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "$(CloseFailed)"
    SetErrorLevel 3
    Abort
  ${EndIf}
  closed:
  !include "${FILE_LIST}"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\IconScape"
  CreateShortcut "$SMPROGRAMS\IconScape\IconScape.lnk" "$INSTDIR\host\bin\IconScape.exe"
  CreateShortcut "$SMPROGRAMS\IconScape\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\IconScape\Installer" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape" "DisplayName" "IconScape"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape" "Publisher" "IconScape contributors"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape" "DisplayIcon" "$INSTDIR\host\bin\IconScape.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape" "EstimatedSize" $0
SectionEnd

Function un.onInit
  SetShellVarContext current
  SetRegView 64
FunctionEnd
Section "Uninstall"
  IfFileExists "$INSTDIR\host\bin\IconScape.exe" 0 unclosed
  ExecWait '"$INSTDIR\host\bin\IconScape.exe" --exit-installed' $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "$(CloseFailed)"
    SetErrorLevel 3
    Abort
  ${EndIf}
  unclosed:
  ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "IconScape"
  ${UnStrStr} $1 $0 '$\"$INSTDIR\host\bin\IconScape.exe$\"'
  ${If} $1 != ""
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "IconScape"
  ${EndIf}
  !include "${DELETE_LIST}"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\IconScape\IconScape.lnk"
  Delete "$SMPROGRAMS\IconScape\Uninstall.lnk"
  RMDir "$SMPROGRAMS\IconScape"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\IconScape"
  DeleteRegKey HKCU "Software\IconScape\Installer"
SectionEnd
