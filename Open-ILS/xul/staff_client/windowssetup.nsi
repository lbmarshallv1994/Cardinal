; Script generated by the HM NIS Edit Script Wizard.

; HM NIS Edit Wizard helper defines
; Old versions of makensis don't like this, moved to Makefile
;!define /file PRODUCT_VERSION "client/VERSION"
!define PRODUCT_TAG "3.3"
!define PRODUCT_INSTALL_TAG "${PRODUCT_TAG}"
!define UI_IMAGESET "beta"
;!define UI_IMAGESET "release"
!define PRODUCT_NAME "Evergreen Staff Client ${PRODUCT_TAG}"
!define PRODUCT_PUBLISHER "Evergreen Community"
!define PRODUCT_WEB_SITE "http://evergreen-ils.org/"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\evergreen.exe"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"
!define PRODUCT_STARTMENU_REGVAL "NSIS:StartMenuDir"
!ifndef PRODUCT_LICENSE
  !define PRODUCT_LICENSE
!endif

!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "custom_images\${UI_IMAGESET}\header.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "custom_images\${UI_IMAGESET}\install.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "custom_images\${UI_IMAGESET}\uninstall.bmp"

; This should improve compression, and solves some zlib related issues with extensions
SetCompressor /SOLID lzma

; MUI 1.67 compatible ------
!include "MUI.nsh"

; File Functions
!include "FileFunc.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

; Language Selection Dialog Settings
!define MUI_LANGDLL_REGISTRY_ROOT "${PRODUCT_UNINST_ROOT_KEY}"
!define MUI_LANGDLL_REGISTRY_KEY "${PRODUCT_UNINST_KEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "NSIS:Language"

; Make the welcome page a tad less verbose on the name
; Note: The title bar will still be verbose (full product name + version + "Setup")
!define MUI_WELCOMEPAGE_TITLE "Welcome to the Evergreen Staff Client ${PRODUCT_VERSION} Setup Wizard"

; Welcome page
!insertmacro MUI_PAGE_WELCOME
; License page, if we have one
!if "${PRODUCT_LICENSE}" != ""
  !insertmacro MUI_PAGE_LICENSE "${PRODUCT_LICENSE}"
!endif
; Components page
!ifdef AUTOUPDATE | DEVELOPER | PERMACHINE
!insertmacro MUI_PAGE_COMPONENTS
!endif
; Directory page
!insertmacro MUI_PAGE_DIRECTORY
; Start menu page
var ICONS_GROUP
!define MUI_STARTMENUPAGE_NODISABLE
!define MUI_STARTMENUPAGE_DEFAULTFOLDER "Evergreen Staff Client ${PRODUCT_TAG}"
!define MUI_STARTMENUPAGE_REGISTRY_ROOT "${PRODUCT_UNINST_ROOT_KEY}"
!define MUI_STARTMENUPAGE_REGISTRY_KEY "${PRODUCT_UNINST_KEY}"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "${PRODUCT_STARTMENU_REGVAL}"
!insertmacro MUI_PAGE_STARTMENU Application $ICONS_GROUP
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES
; Finish page
!define MUI_FINISHPAGE_RUN "$INSTDIR\evergreen.exe"
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!insertmacro MUI_LANGUAGE "English"

; MUI end ------

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "evergreen_staff_client_setup.exe"
InstallDir "$PROGRAMFILES\Evergreen Staff Client ${PRODUCT_INSTALL_TAG}"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" "${PRODUCT_INSTALL_TAG}"
ShowInstDetails show
ShowUnInstDetails show
RequestExecutionLevel admin

Section "Staff Client" SECMAIN
  SetShellVarContext All ; All Users (for shortcuts)
  ; Uninstall old (inno) variant?
  IfFileExists "$INSTDIR/unin000.exe" 0 +3
    ExecWait '"$INSTDIR/unins000.exe" /VERYSILENT'
    Sleep 5000 ; Wait five seconds in case the uninstaller returned before it was done
  ; Uninstall old (nsis) version?
  IfFileExists "$INSTDIR/uninst.exe" 0 +4
    ExecWait '"$INSTDIR/uninst.exe" /S _?="$INSTDIR"'
    Sleep 5000 ; Wait five seconds in case the uninstaller returned before it was done
    Delete "$INSTDIR/uninst.exe"
  SetOutPath "$INSTDIR"
  File /r /x "autoupdate.js" /x "autochannel.js" /x "developers.js" /x "aa_per_machine.js" "client\*"

  ; Shortcuts
  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
  CreateDirectory "$SMPROGRAMS\$ICONS_GROUP"
  !ifdef WICON
  CreateShortCut "$SMPROGRAMS\$ICONS_GROUP\Evergreen Staff Client.lnk" "$INSTDIR\evergreen.exe" "" "$INSTDIR\evergreen.ico"
  CreateShortCut "$SMPROGRAMS\$ICONS_GROUP\Evergreen Staff Client (Standalone).lnk" "$INSTDIR\evergreen.exe" "-ILSoffline" "$INSTDIR\evergreen.ico"
  !ifdef PROFILES
  CreateShortCut "$SMPROGRAMS\$ICONS_GROUP\Evergreen Staff Client Profile Manager.lnk" "$INSTDIR\evergreen.exe" "-profilemanager" "$INSTDIR\evergreen.ico"
  !endif
  !else
  CreateShortCut "$SMPROGRAMS\$ICONS_GROUP\Evergreen Staff Client.lnk" "$INSTDIR\evergreen.exe"
  CreateShortCut "$SMPROGRAMS\$ICONS_GROUP\Evergreen Staff Client (Standalone).lnk" "$INSTDIR\evergreen.exe" "-ILSoffline"
  !ifdef PROFILES
  CreateShortCut "$SMPROGRAMS\$ICONS_GROUP\Evergreen Staff Client Profile Manager.lnk" "$INSTDIR\evergreen.exe" "-profilemanager"
  !endif
  !endif
  CreateShortCut "$DESKTOP\Evergreen Staff Client ${PRODUCT_TAG}.lnk" "$INSTDIR\evergreen.exe"
  
  ; External script for extra things.
  !ifdef EXTRAS
  !define EXTERNAL_EXTRAS_SECMAIN
  !include /NONFATAL "extras.nsi"
  !undef EXTERNAL_EXTRAS_SECMAIN
  !endif

  !insertmacro MUI_STARTMENU_WRITE_END

  !ifdef AUTOUPDATE | PERMACHINE
  ; For autoupdate and/or registering per machine, make sure we can write to the install directory.
  !addplugindir AccessControl/Plugins
  AccessControl::GrantOnFile "$INSTDIR" "Everyone" "FullAccess"
  !endif
SectionEnd

!ifdef AUTOUPDATE
Section /o "Automatic Update" SECAUTO
  SetOutPath "$INSTDIR\defaults\preferences"
  File "client\defaults\preferences\autoupdate.js"
  File "client\defaults\preferences\autochannel.js"
  SetOutPath "$INSTDIR"
SectionEnd
!endif

!ifdef DEVELOPER
Section /o "Developer Options" SECDEV
  SetOutPath "$INSTDIR\defaults\preferences"
  File "client\defaults\preferences\developers.js"
  SetOutPath "$INSTDIR"
SectionEnd
!endif

!ifdef PERMACHINE
Section /o "Registration Per Machine" SECPERMAC
  SetOutPath "$INSTDIR\defaults\preferences"
  File "client\defaults\preferences\aa_per_machine.js"
  SetOutPath "$INSTDIR"
SectionEnd
!endif

Function .onInit
  !insertmacro MUI_LANGDLL_DISPLAY
  SectionSetFlags ${SECMAIN} 17
  ; This is mainly for silent installs
  !ifdef AUTOUPDATE | DEVELOPER | PERMACHINE
    Var /GLOBAL CMD_ARGS
    StrCpy $CMD_ARGS ""
    ${GetParameters} $CMD_ARGS
    !ifdef AUTOUPDATE
      !ifdef AUTOUPDATE_NODEFAULT
        ${GetOptions} $CMD_ARGS "/autoupdate" $0
        IfErrors +2 0
      !else
        ${GetOptions} $CMD_ARGS "/noautoupdate" $0
        IfErrors 0 +2
      !endif
      SectionSetFlags ${SECAUTO} 1
    !endif
    !ifdef PERMACHINE
      !ifdef PERMACHINE_NODEFAULT
        ${GetOptions} $CMD_ARGS "/permachine" $0
        IfErrors +2 0
      !else
        ${GetOptions} $CMD_ARGS "/nopermachine" $0
        IfErrors 0 +2
      !endif
      SectionSetFlags ${SECPERMAC} 1
    !endif
    !ifdef DEVELOPER
      ${GetOptions} $CMD_ARGS "/developer" $0
      IfErrors +2 0
      SectionSetFlags ${SECDEV} 1
    !endif
  !endif
FunctionEnd

Section -AdditionalIcons
  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
  WriteIniStr "$INSTDIR\${PRODUCT_NAME}.url" "InternetShortcut" "URL" "${PRODUCT_WEB_SITE}"
  CreateShortCut "$SMPROGRAMS\$ICONS_GROUP\Website.lnk" "$INSTDIR\${PRODUCT_NAME}.url"
  CreateShortCut "$SMPROGRAMS\$ICONS_GROUP\Uninstall.lnk" "$INSTDIR\uninst.exe"
  !insertmacro MUI_STARTMENU_WRITE_END
SectionEnd

Section -Post
  WriteUninstaller "$INSTDIR\uninst.exe"
  WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\evergreen.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\evergreen.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
SectionEnd

; Section descriptions
!ifdef AUTOUPDATE | DEVELOPER | PERMACHINE
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SECMAIN} "The Evergreen Staff Client with XULRunner, Required"
  !ifdef AUTOUPDATE
  !insertmacro MUI_DESCRIPTION_TEXT ${SECAUTO} "Automatic Update Functionality"
  !endif
  !ifdef DEVELOPER
  !insertmacro MUI_DESCRIPTION_TEXT ${SECDEV}  "Developer Options"
  !endif
  !ifdef PERMACHINE
  !insertmacro MUI_DESCRIPTION_TEXT ${SECPERMAC}  "Default registration and offline storage to per machine instead of per user"
  !endif
!insertmacro MUI_FUNCTION_DESCRIPTION_END
!endif

Function un.onUninstSuccess
  HideWindow
  MessageBox MB_ICONINFORMATION|MB_OK "$(^Name) was successfully removed from your computer." /SD IDOK
FunctionEnd

Function un.onInit
!insertmacro MUI_UNGETLANGUAGE
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Are you sure you want to completely remove $(^Name) and all of its components?" /SD IDYES IDYES +2
  Abort
FunctionEnd

Function "un.RemoveFileCheck"
  StrCmp $R7 "open_ils_staff_client" +5
  StrCmp $R6 "" +3
  Delete "$R9"
  Goto +2
  RmDir /r "$R9"
  Push $0
FunctionEnd

Section Uninstall
  SetShellVarContext All ; All Users (for shortcuts)
  !insertmacro MUI_STARTMENU_GETFOLDER "Application" $ICONS_GROUP
  Delete "$INSTDIR\${PRODUCT_NAME}.url"
  Delete "$INSTDIR\uninst.exe"
  Delete "$INSTDIR\evergreen.exe"
  Delete "$INSTDIR\application.ini"
  Delete "$INSTDIR\BUILD_ID"
  Delete "$INSTDIR\STAMP_ID"
  Delete "$INSTDIR\VERSION"
  Delete "$INSTDIR\install.rdf"
  Delete "$INSTDIR\active-update.xml"
  Delete "$INSTDIR\chrome.manifest"
  Delete "$INSTDIR\updates.xml"
  Delete "$INSTDIR\log.txt"
  Delete "$INSTDIR\evergreen.ico"

  Delete "$SMPROGRAMS\$ICONS_GROUP\Uninstall.lnk"
  Delete "$SMPROGRAMS\$ICONS_GROUP\Website.lnk"
  Delete "$DESKTOP\Evergreen Staff Client ${PRODUCT_TAG}.lnk"
  Delete "$SMPROGRAMS\$ICONS_GROUP\Evergreen Staff Client.lnk"
  Delete "$SMPROGRAMS\$ICONS_GROUP\Evergreen Staff Client (Standalone).lnk"

  ; External script for removing extra files before we wipe out the install directory
  !ifdef EXTRAS
  !define EXTERNAL_EXTRAS_UNINSTALL
  !include /NONFATAL "extras.nsi"
  !undef EXTERNAL_EXTRAS_UNINSTALL
  !endif

  RMDir "$SMPROGRAMS\$ICONS_GROUP"
  RMDir /r "$INSTDIR\updates"
  RMDir /r "$INSTDIR\xulrunner"
  RMDir /r "$INSTDIR\extensions"
;  RMDir /r "$INSTDIR\chrome" ; We can't wipe out the chrome directory normally. Per-machine info would be lost on upgrade.
  RMDir /r "$INSTDIR\components"
  RMDir /r "$INSTDIR\defaults"

  ; Basically, we want to remove everything but "open_ils_staff_client" from the chrome dir
  ; So we pass over every file and folder in it. If it matches, we leave it alone.
  ${Locate} "$INSTDIR\chrome" "/G=0" "un.RemoveFileCheck"
  ; Then, we remove the folder non-recursively, which won't wipe out the folder if it is still there.
  RMDir "$INSTDIR\chrome"

  RMDir "$INSTDIR"

  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
  DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
  SetAutoClose true
SectionEnd
