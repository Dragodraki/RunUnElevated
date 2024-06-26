!define Name "RunasMe"
!define Version "2.0.0.0"
!define Productversion "2.0.0"
Icon "..\Icon.ico"
Name ${Name}
Caption "${Name}"
OutFile "..\..\Kompiliert\${Name}.exe"
SetCompress off
RequestExecutionLevel user
SetOverWrite on
ManifestDPIAware true
Unicode true
SilentInstall silent		; warning: silent without FakeSilent in .onInit skips MessageBox or deleting of temp files at end!
AutoCloseWindow true	; alternative to SilentInstall silent (don't forget moving window with System::Call in .onGUIInit)
ShowInstDetails nevershow	; alternative to SilentInstall silent (don't forget moving window with System::Call in .onGUIInit)
WindowIcon on
VIProductVersion "${Version}"
VIAddVersionKey "ProductName" "${Name}"
VIAddVersionKey "ProductVersion" "${Productversion}"
VIAddVersionKey "CompanyName" "Dreamland"
VIAddVersionKey "FileVersion" "${Version}"
VIAddVersionKey "InternalName" "${Name}.exe"
VIAddVersionKey "FileDescription" "Run unelevated logged-on user instance"
VIAddVersionKey "LegalCopyright" "Drago Yoshagi © 2024"
VIAddVersionKey "LegalTrademarks" "This app is obviously designed by me."
VIAddVersionKey "OriginalFilename" "${Name}.exe"

!define Script "RunUnElevated.nsi"
!define /IfNDef KEYEVENTF_KEYUP 2



!define CSIDL_MUSIC '0xD' ;My Music path
!define CSIDL_DESKTOPDIR '0x10' ;Desktop Directory path
!define CSIDL_COMPUTER '0x11' ;My Computer path
!define CSIDL_LOCALAPPDATA '0x1C' ;Local Application Data path
!define CSIDL_INTERNETCACHE '0x20' ;Internet Cache path
!define CSIDL_COMMONAPPDATA '0x23' ;Common Application Data path
!define CSIDL_PROGRAMFILES '0x26' ;Program Files path
!define CSIDL_COMMONPROGRAMFILES '0x2B' ;Common Program Files pat
; !Include: falls Pfadangabe fehlt, wird sowohl in Source-Pfad als auch im NSIS-Pfad nachgesehen
!include "WinMessages.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "WinVer.nsh"
!include "..\Include\x64.nsh"
!include "..\Include\WMI.nsh"
!include "..\Include\System.nsh"
!addplugindir AccessControl
Var Parameters
Var CurrentUser
Var ActualUser
Var ActualDomainBackslashUser
Var ActualSID
Var ActualProfilePath
Var Silent
Var systemdrive
Var Param1
Var Param2
Var NirSoftParam1
Var NirSoftParam2
Var NirSoftDoubleParam2
Var NirSoftSolelyParam2
Var MacroParam2
Var ProcessRunParam2
Var NirSoftByMacroParam2
Var CommandLineUsed
Var NirSoftCommandLineUsed
Var IntegrityLevel
Var WaitParam
Var ArchitectureNumber
Var app
Var RunAsNumber
Var Fallback
Var UACmode
Var RunMode
Var WaitMode
Var DebugMode
Var FlagSearchString
Var CollectedFlags
Var ImproperFlagFound



Function .onInit
; Prevent "SilentInstall silent" skips MessageBox or deleting of temp files
${If} ${Silent}
    SetSilent Normal ; Turn off real silent mode
    SetAutoClose True
    StrCpy $Silent 1 ; Fake silent mode
${EndIf}
FunctionEnd



!macro MsgBox out text title flags
   System::Call "user32::MessageBox(i $HWNDPARENT, t '${text}', t '${title}', i ${flags}) i.s"
   Pop ${out}
!macroend



!define StrStr "!insertmacro StrStr"
!macro StrStr ResultVar String SubString
  Push `${String}`
  Push `${SubString}`
  Call StrStr
  Pop `${ResultVar}`
!macroend
Function StrStr
/*After this point:
  ------------------------------------------
  $R0 = SubString (input)
  $R1 = String (input)
  $R2 = SubStringLen (temp)
  $R3 = StrLen (temp)
  $R4 = StartCharPos (temp)
  $R5 = TempStr (temp)*/
  ;Get input from user
  Exch $R0
  Exch
  Exch $R1
  Push $R2
  Push $R3
  Push $R4
  Push $R5
  ;Get "String" and "SubString" length
  StrLen $R2 $R0
  StrLen $R3 $R1
  ;Start "StartCharPos" counter
  StrCpy $R4 0
  ;Loop until "SubString" is found or "String" reaches its end
  loop:
    ;Remove everything before and after the searched part ("TempStr")
    StrCpy $R5 $R1 $R2 $R4
    ;Compare "TempStr" with "SubString"
    StrCmp $R5 $R0 done
    ;If not "SubString", this could be "String"'s end
    IntCmp $R4 $R3 done 0 done
    ;If not, continue the loop
    IntOp $R4 $R4 + 1
    Goto loop
  done:
/*After this point:
  ------------------------------------------
  $R0 = ResultVar (output)*/
  ;Remove part before "SubString" on "String" (if there has one)
  StrCpy $R0 $R1 `` $R4
  ;Return output to user
  Pop $R5
  Pop $R4
  Pop $R3
  Pop $R2
  Pop $R1
  Exch $R0
FunctionEnd



!define StrCount "!insertmacro StrCount"
 
!macro StrCount str look si
    Push ${str}
    Push ${look}
    Push ${si}
    Call StrCount
!macroend
 
Function StrCount 
	;takes the following parameters by the stack:
	; case sensitive ('s') or insensitive
    ; string to lookup
    ; string where to search
 
	Exch $2	;Stack = ($2 test str)
    Exch	;Stack = (test $2 str)
    Exch $1	;Stack = ($1 $2 str)
    Exch	;Stack = ($2 $1 str)
    Exch 2	;Stack = (str $1 $2)
    Exch $0	;Stack = ($0 $1 $2)
    Exch 2	;Stack = ($2 $1 $0) just to pop in natural order
    Push $3
    Push $4
    Push $5	
    Push $6	;Stack = ($6 $5 $4 $3 $2 $1 $0)
 
	StrLen $4 $1    
    StrCpy $5 0
    StrCpy $6 0
 
    ;now $0=str, $1=test, $2=s/i, $3=tmp str, $4=lookup len, $5=index, $6=count
 
    loop:
    StrCpy $3 $0 $4 $5
    StrCmp $3 "" end
    ${if} $2 == 's'
    	StrCmpS $3 $1 count ignore
    ${else}
    	StrCmp $3 $1 count ignore
    ${endif}
    count:
    IntOp $6 $6 + 1	;count++
    ignore:
    IntOp $5 $5 + 1 ;index++
	goto loop
	end:
 
    Exch 6	;Stack = ($0 $5 $4 $3 $2 $1 $6)
	Pop $0
    Pop $5
    Pop $4
    Pop $3
    Pop $2
    Pop $1	;Stack = ($6)
    Exch $6	;count is on top stack
FunctionEnd


!define StrRep "!insertmacro StrRep"
!macro StrRep output string old new
    Push `${string}`
    Push `${old}`
    Push `${new}`
    !ifdef __UNINSTALL__
        Call un.StrRep
    !else
        Call StrRep
    !endif
    Pop ${output}
!macroend
!macro Func_StrRep un
    Function ${un}StrRep
        Exch $R2 ;new
        Exch 1
        Exch $R1 ;old
        Exch 2
        Exch $R0 ;string
        Push $R3
        Push $R4
        Push $R5
        Push $R6
        Push $R7
        Push $R8
        Push $R9
        StrCpy $R3 0
        StrLen $R4 $R1
        StrLen $R6 $R0
        StrLen $R9 $R2
        loop:
            StrCpy $R5 $R0 $R4 $R3
            StrCmp $R5 $R1 found
            StrCmp $R3 $R6 done
            IntOp $R3 $R3 + 1 ;move offset by 1 to check the next character
            Goto loop
        found:
            StrCpy $R5 $R0 $R3
            IntOp $R8 $R3 + $R4
            StrCpy $R7 $R0 "" $R8
            StrCpy $R0 $R5$R2$R7
            StrLen $R6 $R0
            IntOp $R3 $R3 + $R9 ;move offset by length of the replacement string
            Goto loop
        done:
        Pop $R9
        Pop $R8
        Pop $R7
        Pop $R6
        Pop $R5
        Pop $R4
        Pop $R3
        Push $R0
        Push $R1
        Pop $R0
        Pop $R1
        Pop $R0
        Pop $R2
        Exch $R1
    FunctionEnd
!macroend
!insertmacro Func_StrRep ""



Function TrimQuotes	; das normale Trim der Leerzeichen ist weiter unten
Exch $R0
Push $R1
  StrCpy $R1 $R0 1
  StrCmp $R1 `"` 0 +2
    StrCpy $R0 $R0 `` 1
  StrCpy $R1 $R0 1 -1
  StrCmp $R1 `"` 0 +2
    StrCpy $R0 $R0 -1
Pop $R1
Exch $R0
FunctionEnd
!macro _TrimQuotes Input Output
  Push `${Input}`
  Call TrimQuotes
  Pop ${Output}
!macroend
!define TrimQuotes `!insertmacro _TrimQuotes`



!macro GET_STRING_TOKEN INPUT PART
  Push $R0
  Push $R1
  Push $R2
; R0 = indice di scorrimento stringa
; R0 = index of current position in the string
  StrCpy 	$R0 -1
; R1 = indice del carattere " da trovare
; R1 = index of '"' character to be found
  IntOp  	$R1 ${PART} * 2
  IntOp  	$R1 $R1 - 1
; cerco il " che indica l'inizio della sottostringa di interesse
; searching '"' character beginning the sub-string
findStart_loop_${PART}:						
  IntOp  	$R0 $R0 + 1 					; i++
  StrCpy	$R2 ${INPUT} 1 $R0				; getting next character
  StrCmp 	$R2 "" error_${PART}
  StrCmp 	$R2 '"' 0 findStart_loop_${PART}
  IntOp 	$R1 $R1 - 1
  IntCmp 	$R1 0 0 0 findStart_loop_${PART}		
; salvo in R1 l'indice di inizio della sottostringa di interesse
; storing in R1 the index beginning the sub-string
  IntOp 	$R1 $R0 + 1
; cerco il " successivo, che indica la fine della stringa di interesse
; searching '"' character ending the sub-string
findEnd_loop_${PART}:						
  IntOp  	$R0 $R0 + 1 					; i++
  StrCpy	$R2 ${INPUT} 1 $R0				; getting next character
  StrCmp 	$R2 "" error_${PART}
  StrCmp 	$R2 '"' 0 findEnd_loop_${PART}
; R0 = indice di fine della sottostringa di interesse
; R0 = the index ending the sub-string
  IntOp 	$R0 $R0 - $R1					
; salvo in R0 la lunghezza della sottostringa di interesse
; storing in R0 the sub-string's length
  StrCpy 	$R0 ${INPUT} $R0 $R1
  Goto 		done_${PART}
error_${PART}:
  StrCpy 	$R0 error
done_${PART}:
  Pop 		$R2
  Pop 		$R1
  Exch 		$R0
!macroend



Function StrStrip
Exch $R0 #string
Exch
Exch $R1 #in string
Push $R2
Push $R3
Push $R4
Push $R5
 StrLen $R5 $R0
 StrCpy $R2 -1
 IntOp $R2 $R2 + 1
 StrCpy $R3 $R1 $R5 $R2
 StrCmp $R3 "" +9
 StrCmp $R3 $R0 0 -3
  StrCpy $R3 $R1 $R2
  IntOp $R2 $R2 + $R5
  StrCpy $R4 $R1 "" $R2
  StrCpy $R1 $R3$R4
  IntOp $R2 $R2 - $R5
  IntOp $R2 $R2 - 1
  Goto -10
  StrCpy $R0 $R1
Pop $R5
Pop $R4
Pop $R3
Pop $R2
Pop $R1
Exch $R0
FunctionEnd
!macro StrStrip Str InStr OutVar
 Push '${InStr}'
 Push '${Str}'
  Call StrStrip
 Pop '${OutVar}'
!macroend
!define StrStrip '!insertmacro StrStrip'



; --- Example for how to remove all double quotes from string
; ${StrStrip}  "$\"" $String $String
; --- Example for how to verify existing substring in a string
; Push "$StringWithSubstring"
; Push "Substring"
; Call StrContains
; Pop $0
; ${If} $0 != ""
; ${Else}
; ${EndIf}



Function .onGUIInit
InitPluginsDir
; Get systemdrive variable (comes in handy always)
StrCpy $systemdrive $sysdir 2
DetailPrint $systemdrive
${If} ${RunningX64}
  ${DisableX64FSRedirection}
${EndIf} 
; Wichtige Info: Setze $app als Variable, wo meine entpackten Dateien liegen
; Ziel der beim Ausführen entpackten Dateien:
StrCpy $app $PLUGINSDIR
;;;ReadEnvStr $0 "SYSTEMROOT"
;;;${StrRep} `$app` `$app` `$0\Temp` `$systemdrive\Temp`
SetOutPath $app
; Quelle aller beim Kompilieren zu packenden Elemente:
File /r "$%systemdrive%\InnoSetup-Software\Source\*"
${If} $Silent != 1
    ; move window off screen (.onGUIInit as alternative to "SilentInstall silent" - short flicker remain visible)
    System::Call "User32::SetWindowPos(i, i, i, i, i, i, i) b ($HWNDPARENT, 0, -10000, -10000, 0, 0, ${SWP_NOOWNERZORDER}|${SWP_NOSIZE})"
${EndIf}
    Delete "$app\${Script}"
    SetOutPath "$EXEDIR"
FunctionEnd



Function .onGUIEnd
; Get defined parameters
${GetParameters} $Parameters
; Fake InStr to avoid warnings StrContains/StrStrip not referenced
StrCpy $R9 ""
${If} $R9 != ""
${StrStrip}  "Substring" $R9 $R9
Push "$R9"
Push "Substring"
Call StrContains
Pop $0
${If} $0 != ""
${Else}
${EndIf}
${Else}
${EndIf}
; Fake end
${If} $Parameters == ""
${OrIf} $Parameters == "/h"
${OrIf} $Parameters == "/help"
${OrIf} $Parameters == "/?"
${OrIf} $Parameters == "-h"
${OrIf} $Parameters == "-help"
${OrIf} $Parameters == "-?"
${OrIf} $Parameters == "h"
${OrIf} $Parameters == "help"
${OrIf} $Parameters == "?"
    !insertmacro MsgBox $0 `Invoke program as logged-in desktop user, no matter parent process''s administrator/system/other-user context. Extra useful on post-installations run or in general to ignore UAC manifest.$\n$\n$\nSyntax usage:$\n  $(^Name).exe [/Flags] [Path]File [Args]$\n$\nFlags:$\n  /wait = Run until (associated) program is terminated$\n  /fb=[mc/cu/off] = Fallback to macro / current user / exit$\n  /uac=[off/on/force] = UAC behavior (default $\"uac=off$\")$\n  /debug = Display result as MsgBox (reveals error cause)$\n$\nExamples:$\n  $(^Name).exe cmd$\n  $(^Name).exe $\"$systemdrive\Windows\system32\devmgmt.msc$\"$\n  $(^Name).exe /uac=off /fb=mc sysdm.cpl$\n  $(^Name).exe /wait /fb=off MyApp.exe$\n  $(^Name).exe $\"cmd.exe$\" $\"/c explorer.exe %userprofile%$\n  $(^Name).exe /debug $\"WhyTheFail$\" AndHelp$\"$\n$\nHint:$\n  You can also drag''n''drop files/shortcuts on the program.` `$(^Name)` 0x40|0x0
    ;MessageBox MB_OK "Return Code: $0"
    StrCpy $Parameters ""
    Abort
${Else}		; wenn die Parameter nicht den Vorgaben entsprechen...
; Trim Paramters
Push ' $Parameters '
Call Trim
StrCpy $Parameters ""
Pop $Parameters ;$Parameters now contains the trimmed string.
    ;MessageBox MB_OK "Parameter: $Parameters"
	
; Erfrage Privilegien (User/Admin)
UserInfo::GetAccountType
pop $IntegrityLevel
${If} $IntegrityLevel != "admin"
  ;MessageBox MB_OK "Eingeschränkte Rechte"
${EndIf}
	
; --- Kritischer Fix für NSIS für Windows Vista/7/8!!! ---
; Ermöglicht das Zugreifen auf temporäre Dateien auch dann, falls als anderer Benutzer ausgeführt
; Benutzerinformationen der aktuell eingeloggten Windows-Sitzung über GetSessionUser erhalten:
; Falls das nicht funktionieren sollte, kann NSIS danach noch direkt über WMIC eine Abfrage starten
${If} ${AtLeastWinVista}
${OrIf} $IntegrityLevel == "admin"
  StrCpy $0 -1
  nsExec::ExecToStack `"$app\GetSessionUser.exe"`
  Pop $0
  Pop $1
  StrCpy $0 $1
  Push ' $0 '
  Call Trim
  Pop $0
${EndIf}
; Die getrimmte Roh-Ausgabe des Strings der ausgeführten Konsolen-Anwendung:
;MessageBox MB_OK "$0"
; Ermittle hier Domäne\AccountName:
StrCpy $1 $0
${StrStr} "$1" "$1" "SID: "
${StrStrip} $1 $0 $1
${StrRep} `$1` `$1` `UserName: ` ``
Push ' $1 '
Call Trim
Pop $1
StrCpy $ActualDomainBackslashUser $1
;MessageBox MB_OK "---$ActualDomainBackslashUser---"
; Ermittle hier die SID:
StrCpy $2 $0
${StrStr} "$2" "$2" "UserProfile: "
${StrStrip} $2 $0 $2
${StrStr} "$2" "$2" "SID: "
${StrRep} `$2` `$2` `SID: ` ``
Push ' $2 '
Call Trim
Pop $2
StrCpy $ActualSID $2
;MessageBox MB_OK "---$ActualSID---"
; Ermittle hier den Profilpfad:
StrCpy $3 $0
${StrStr} "$3" "$3" "UserProfile: "
${StrRep} `$3` `$3` `UserProfile: ` ``
Push ' $3 '
Call Trim
Pop $3
ReadEnvStr $systemdrive "SYSTEMDRIVE"
${StrRep} `$3` `$3` `%SystemDrive%` `$systemdrive`
StrCpy $ActualProfilePath $3
;MessageBox MB_OK "---$ActualProfilePath---"
; Alternative Methode direkt über WMIC funktioniert nur von Windows Vista bis Windows 8:
StrCpy $0 ""
${If} ${AtLeastWinVista}
  ${WMIGetInfo} root\CIMV2 Win32_ComputerSystem UserName wmi_callback_Function
${EndIf}  
;Trim das Ergebnis
Push $0
Call Trim
Pop $0
${If} $0 != ""
  StrCpy $ActualDomainBackslashUser ""
  StrCpy $ActualDomainBackslashUser $0
${EndIf}
${StrStr} "$1" "$ActualDomainBackslashUser" "\"
StrCpy $ActualUser $1 "" 1
System::Call "advapi32::GetUserName(t .r0, *i ${NSIS_MAX_STRLEN} r1) i.r2"
StrCpy $CurrentUser $0
; Gebe aktuellem Benutzer und SYSTEM Zugriff auf entpackte Dateien von NSIS, um UnElevator auszuführen...
  nsExec::Exec 'icacls.exe "$PLUGINSDIR" /inheritance:d /grant "*$ActualSID":(OI)(CI)F'
  nsExec::Exec 'icacls.exe "$PLUGINSDIR" /inheritance:d /grant "$ActualUser":(OI)(CI)F'
  nsExec::Exec 'icacls.exe "$PLUGINSDIR" /inheritance:d /grant "$CurrentUser":(OI)(CI)F'
  ;Methode 2 - Gebe SYSTEM-Account Vollzugriff auf entpacktes Verzeichnis, weil SYSTEM keinen Zugriff auf Userumgebung hat
  AccessControl::SetFileOwner "$PLUGINSDIR" "$CurrentUser"
  AccessControl::GrantOnFile "$PLUGINSDIR" "(S-1-5-18)" "FullAccess"
  AccessControl::GrantOnFile "$PLUGINSDIR" "($ActualSID)" "FullAccess"
  ${IfNot} ${AtLeastWinVista}
    AccessControl::GrantOnFile "$PLUGINSDIR" "(S-1-1-0)" "FullAccess"
  ${EndIf}  
Pop $0
;MessageBox mb_ok "Ergebnis letzter Befehl: $0 - icacls.exe $PLUGINSDIR /inheritance:r /grant $ActualUser:(OI)(CI)F"
; --- Ende Fix für NSIS ---

; Benutzerdefinierte Variablen für die Umgebungsvariablen deklarieren
Var /GLOBAL MY_USERPROFILE
Var /GLOBAL MY_APPDATA
Var /GLOBAL MY_LOCALAPPDATA
Var /GLOBAL MY_ALLUSERSPROFILE
Var /GLOBAL MY_TEMP
Var /GLOBAL MY_SYSTEMROOT
Var /GLOBAL MY_USERNAME
; Umgebungsvariablen für eingeloggte Windows-Sitzung ermitteln (dieser bleibt auch nach einer Namensumbenennung gleich)
; Der String $ActualProfilePath ist bereits korrekt durch GetSessionUser vorgegeben
; Username
${GetParent} $ActualProfilePath $0
StrCpy $0 "$0\"
${StrStrip} $0 $ActualProfilePath $0
StrCpy $MY_USERNAME $0
${If} $MY_USERNAME != ""
  System::Call 'Kernel32::SetEnvironmentVariable(t, t)i ("USERNAME", "$MY_USERNAME").r0'
${EndIf}
ReadEnvStr $MY_USERNAME "USERNAME"
; Userprofile
${If} $ActualProfilePath != ""
  System::Call 'Kernel32::SetEnvironmentVariable(t, t)i ("USERPROFILE", "$ActualProfilePath").r0'
${EndIf}
ReadEnvStr $MY_USERPROFILE "USERPROFILE"
; Auslesen der übrigen Umgebungsvariablen (Windows 2000/XP können teils nur SHGetSpecialFolderPath)
; AppData
StrCpy $1 ""
System::Call 'shell32::SHGetSpecialFolderPath(i $HWNDPARENT, t .r1, i ${CSIDL_APPDATA}, i0)i.r0'
${If} $1 == ""
  ReadEnvStr $1 "APPDATA"
  ${StrRep} `$1` `$1` `$systemdrive\WINDOW\SysWOW64\config\systemprofile` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\WINDOWs\system32\config\systemprofile` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\WINDOWS\config\systemprofile` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\Windows\syswow64\config` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\Windows\system32\config` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\Windows\config` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\WINDOWS\SysWOW64\config\systemprofile` `$MY_USERPROFILE`
${EndIf}
StrCpy $MY_APPDATA $1
System::Call 'Kernel32::SetEnvironmentVariable(t, t)i ("APPDATA", "$MY_APPDATA").r0'
ReadEnvStr $MY_APPDATA "APPDATA"
; Localappdata
StrCpy $1 ""
System::Call 'shell32::SHGetSpecialFolderPath(i $HWNDPARENT, t .r1, i ${CSIDL_LOCALAPPDATA}, i0)i.r0'
${If} $1 == ""
  ReadEnvStr $1 "LOCALAPPDATA"
  ${StrRep} `$1` `$1` `$systemdrive\WINDOW\SysWOW64\config\systemprofile` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\WINDOWs\system32\config\systemprofile` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\WINDOWS\config\systemprofile` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\Windows\syswow64\config` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\Windows\system32\config` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\Windows\config` `$MY_USERPROFILE`
  ${StrRep} `$1` `$1` `$systemdrive\WINDOWS\SysWOW64\config\systemprofile` `$MY_USERPROFILE`
${EndIf}
StrCpy $MY_LOCALAPPDATA $1
System::Call 'Kernel32::SetEnvironmentVariable(t, t)i ("LOCALAPPDATA", "$MY_LOCALAPPDATA").r0'
ReadEnvStr $MY_LOCALAPPDATA "LOCALAPPDATA"
; Systemroot
ReadEnvStr $MY_SYSTEMROOT "SYSTEMROOT"
; Temp
StrCpy $1 ""
ReadEnvStr $1 "TEMP"
StrCpy $2 $MY_LOCALAPPDATA
${IfNot} ${AtLeastWinVista}
  ${GetParent} $2 $2
${EndIf}
${StrRep} `$1` `$1` `$MY_SYSTEMROOT` `$2`
StrCpy $MY_TEMP $1
System::Call 'Kernel32::SetEnvironmentVariable(t, t)i ("TEMP", "$MY_TEMP").r0'
ReadEnvStr $MY_TEMP "TEMP"
; Allusersprofile
ReadEnvStr $MY_ALLUSERSPROFILE "ALLUSERSPROFILE"
; Anzeigen aller Umgebungsvariablen und des Benutzernamens der aktuellen Sitzung
; Call ThisToFront
; MessageBox MB_OK|MB_TOPMOST "Alle Variablen:$\nUSERPROFILE: $MY_USERPROFILE$\nAPPDATA: $MY_APPDATA$\nLOCALAPPDATA: $MY_LOCALAPPDATA$\nALLUSERSPROFILE: $MY_ALLUSERSPROFILE$\nTEMP: $MY_TEMP$\nSYSTEMROOT: $MY_SYSTEMROOT$\nSession Benutzername: $MY_USERNAME"

; Kompatibilitätseinstellung, damit de-elavierte App nicht erneut die UAC aufruft:
; Methode 1 - dies funktioniert nicht für SYSTEM/ROOT-Prozesse
System::Call 'Kernel32::SetEnvironmentVariable(t, t)i ("__COMPAT_LAYER", "RunAsInvoker").r0'
; Methode 2 - dies erledigt das Tool "AdvancedRun.exe" von NirSoft

; Architektur ermitteln
${If} ${RunningX64}
    ; 64 bit code
    ;MessageBox MB_OK "64-Bit"
    StrCpy $ArchitectureNumber `64`
${Else}
    ; 32 bit code
    ;MessageBox MB_OK "32-Bit"
    StrCpy $ArchitectureNumber `32`
${EndIf}

; Benutze -ExecWait- für GUI und -nsExec::Exec- für super-unsichtbare Befehle oder um Ausgabe abzufangen

; Flags in parameter erkennen und dementsprechend Variablen setzen
StrCpy $WaitParam 0				; für AdvancedRun.exe, ob auf Prozessende gewartet wird oder nicht
StrCpy $WaitMode "/nowait"	; -WaitParam- für Run.exe
StrCpy $Fallback "macro"			; zu verwende Methode bei Fail mit "macro", "currentuser" oder "exit"
StrCpy $UACmode "/none"		; "none" wird mit AdvancedRun.exe umgesetzt, "inherit" und "force" mit Run.exe
StrCpy $RunMode 1					; wird individuell anhand Berechtigung und Windows-Version bestimmt
StrCpy $CommandLineUsed ""	; standardmäßig gehe davon aus, dass kein Argument (Param2) verwendet wird
StrCpy $DebugMode 0				; falls 1 werden eventuelle Fehler in einer MessageBox angezeigt
StrCpy $CollectedFlags ""
Strcpy $ImproperFlagFound ""

CheckFlagsStart:
; Bitte nur Flags mit Schrägstrich/Slash (/) suchen, weil andere wie Minus (-) auch Dateinamen sein können
; Parameter /wait suchen und in Variable $WaitParam speichern (0 = nicht warten; 1 = warten)
StrCpy $FlagSearchString "/wait"
Push $Parameters
Push "$FlagSearchString "
Call StrContains
Pop $0
${If} $0 != ""
  StrCpy $1 $Parameters 6
  ${If} $1 == "$FlagSearchString "
    StrCpy $WaitParam 1
    StrCpy $WaitMode "$FlagSearchString"
    StrCpy $Parameters $Parameters "" 6
	StrCpy $CollectedFlags "$CollectedFlags$FlagSearchString$\n"
	goto CheckFlagsStart
  ${EndIf}
${EndIf}
; Parameter /fb=mc suchen und in Variable $Fallback speichern (mc = "macro"; cur = "currentuser"; off = "exit")
StrCpy $FlagSearchString "/fb=mc"
Push $Parameters
Push "$FlagSearchString "
Call StrContains
Pop $0
${If} $0 != ""
  StrCpy $1 $Parameters 7
  ${If} $1 == "$FlagSearchString "
    StrCpy $Fallback "macro"
    StrCpy $Parameters $Parameters "" 7
    StrCpy $CollectedFlags "$CollectedFlags$FlagSearchString$\n"
    goto CheckFlagsStart
  ${EndIf}
${EndIf}
; Parameter /fb=cu suchen und in Variable $Fallback speichern (mc = "macro"; cur = "currentuser"; off = "exit")
StrCpy $FlagSearchString "/fb=cu"
Push $Parameters
Push "$FlagSearchString "
Call StrContains
Pop $0
${If} $0 != ""
  StrCpy $1 $Parameters 7
  ${If} $1 == "$FlagSearchString "
    StrCpy $Fallback "currentuser"
    StrCpy $Parameters $Parameters "" 7
    StrCpy $CollectedFlags "$CollectedFlags$FlagSearchString$\n"
    goto CheckFlagsStart
  ${EndIf}
${EndIf}
; Parameter /fb=off suchen und in Variable $Fallback speichern (mc = "macro"; cur = "currentuser"; off = "exit")
StrCpy $FlagSearchString "/fb=off"
Push $Parameters
Push "$FlagSearchString "
Call StrContains
Pop $0
${If} $0 != ""
  StrCpy $1 $Parameters 8
  ${If} $1 == "$FlagSearchString "
    StrCpy $Fallback "exit"
    StrCpy $Parameters $Parameters "" 8
    StrCpy $CollectedFlags "$CollectedFlags$FlagSearchString$\n"
    goto CheckFlagsStart
  ${EndIf}
${EndIf}
; Parameter /uac=off suchen und in Variable $UACmode speichern (off = "none"; on = "inherit" manifest; force = forciere UAC)
StrCpy $FlagSearchString "/uac=off"
Push $Parameters
Push "$FlagSearchString "
Call StrContains
Pop $0
${If} $0 != ""
  StrCpy $1 $Parameters 9
  ${If} $1 == "$FlagSearchString "
    StrCpy $UACmode "/none"
    StrCpy $RunMode 1
    StrCpy $Parameters $Parameters "" 9
	StrCpy $CollectedFlags "$CollectedFlags$FlagSearchString$\n"
    goto CheckFlagsStart
  ${EndIf}
${EndIf}
; Parameter /uac=on suchen und in Variable $UACmode speichern (off = "none"; on = "inherit" manifest; force = forciere UAC)
StrCpy $FlagSearchString "/uac=on"
Push $Parameters
Push "$FlagSearchString "
Call StrContains
Pop $0
${If} $0 != ""
  StrCpy $1 $Parameters 8
  ${If} $1 == "$FlagSearchString "
    StrCpy $UACmode "/inherit"
	StrCpy $RunMode 2
    StrCpy $Parameters $Parameters "" 8
	StrCpy $CollectedFlags "$CollectedFlags$FlagSearchString$\n"
    goto CheckFlagsStart
  ${EndIf}
${EndIf}
; Parameter /uac=force suchen und in Variable $UACmode speichern (off = "none"; on = "inherit" manifest; force = forciere UAC)
StrCpy $FlagSearchString "/uac=force"
Push $Parameters
Push "$FlagSearchString "
Call StrContains
Pop $0
${If} $0 != ""
  StrCpy $1 $Parameters 11
  ${If} $1 == "$FlagSearchString "
    StrCpy $UACmode "/force"
    StrCpy $Parameters $Parameters "" 11
    StrCpy $CollectedFlags "$CollectedFlags$FlagSearchString$\n"
    goto CheckFlagsStart
  ${EndIf}
${EndIf}
; Parameter /debug suchen und in Variable $DebugMode speichern (yes = Debug; no = kein Debug)
StrCpy $FlagSearchString "/debug"
Push $Parameters
Push "$FlagSearchString "
Call StrContains
Pop $0
${If} $0 != ""
  StrCpy $1 $Parameters 7
  ${If} $1 == "$FlagSearchString "
    StrCpy $DebugMode 1
    StrCpy $Parameters $Parameters "" 7
	StrCpy $CollectedFlags "$CollectedFlags$FlagSearchString$\n"
    goto CheckFlagsStart
  ${EndIf}
${EndIf}
; Gültige Flags alle herausextrahiert
; Bei noch verbleibenden (=ungültigen) Flags Setup beenden
; (erst ganz zum Schluss aller Flags einsetzen!!!)
StrCpy $FlagSearchString "/"
Push $Parameters
Push "$FlagSearchString"
Call StrContains
Pop $0
${If} $0 != ""
  StrCpy $1 $Parameters 1
  ${If} $1 == $FlagSearchString
    ${StrStr} "$0" "$Parameters" " "
	${StrStrip} $0 $Parameters $2
	StrCpy $ImproperFlagFound $2 	; falschen Flag für später markieren und erst noch weitersuchen
	StrLen $5 $2
	StrCpy $Parameters $Parameters "" $5
    Push ' $Parameters '
    Call Trim
    Pop $Parameters
    goto CheckFlagsStart
  ${EndIf}
${EndIf}
${If} $ImproperFlagFound != ""
  ${If} $DebugMode == 1
    Call ThisToFront
    MessageBox MB_OK|MB_ICONSTOP "Improper flag used:$\n$ImproperFlagFound"
  ${EndIf}
  Abort
${EndIf}
; Flags (/) wurden alle entfernt
StrCpy $Parameters ` $Parameters`
; Parameter voneinander trennen:
; Dateipfad in $Param1 und alle folgenden Argumente in $Param2  
; Trim Paramters
Push ' $Parameters '
Call Trim
Pop $Parameters
; Prüfe, ob mit/ohne Anführungszeichen beginnt und vollführe Splitting dementsprechend
StrCpy $0 "$Parameters"
StrCpy $5 $0
StrCpy $0 $0 1
${If} $0 == `"`
  StrCpy $3 `"`
  StrCpy $2 1
  StrCpy $1 `"`
${Else}
  StrCpy $3 ` `
  StrCpy $2 0
  StrCpy $1 ``
${EndIf}
Push $3 ; divider character
${If} $0 == `"`
  StrCpy $0 $5 -1 $2
${Else}
  StrCpy $0 $5 $4
${EndIf}
Push $0 ; input string
Call SplitFirstStrPart
Pop $R0 ; 1st part
Pop $R1 ; rest part
StrCpy $R0 `$1$R0$1`
StrCpy $Param1 $R0 
${StrStrip} $Param1 $Parameters $Param2
; Trim Param2
Push ' $Param2 '
Call Trim
StrCpy $Param2 ""
Pop $Param2 ;$Parameters now contains the trimmed string.
; Breche ab, wenn Anzahl aller Anführungszeichen aus Parametern ungerade Zahl ergibt 
StrCpy $0 `"`
StrCpy $1 0
${StrCount} $Parameters $0 s
Pop $1
IntOp $2 $1 % 2		; Division mit Rest (Bsp.: IntOp $1 5 % 2 will set $1 to 1; IntOp $1 4 % 2 will set $1 to 0)
${If} $2 != 0				; Falls Rest ungleich 0
  ${If} $DebugMode == 1
    Call ThisToFront
    MessageBox MB_OK|MB_ICONSTOP "Parameters occurrence of quotation marks is uneven!"
  ${EndIf}
  Abort
${EndIf}
; Reduziere Anführungszeichen von zwei auf eins
StrCpy $1 $Param1 2
${If} $1 == `""`
  StrCpy $0 `$Parameters`
  ${StrRep} `$0` `$0` `$Param2` `"$Param2"`
  StrCpy $1 "/execute $0"
  ClearErrors
  ${GetOptions} $1 "/execute" $Param1
  ${IfNot} ${Errors}
    ${StrStrip} $Param1 $Parameters $Param2
    ${StrRep} `$Param1` `$Param1` `""` `"`
	${StrRep} `$Param1` `$Param1` `""` `"`
  ${EndIf}
  StrCpy $1 $Param2 2
  ${If} $1 == `""`
    StrCpy $Param2 $Param2 "" 2
  ${EndIf}
${EndIf}
; Falls kein Backslash vorhanden + Ziel-Datei liegt in diesem Verzeichnis, verwende aktuellen Pfad
; Wichtig: Alle anderen Korrekturen zuvor müssen z.B. den genauen Pfad verwenden (z.B. $SYSDIR),
; weil ansonsten bei Eingabe von "explorer.exe" als Präfix der aktuelle Pfad gesetzt würde (das wäre fatal)
Push "$Param1"
Push "\"
Call StrContains
Pop $0
${If} $0 == ""
  ${StrRep} `$0` `$Param1` `"` ``
  IfFileExists `$EXEDIR\$0*.*` FOUND_ExecuteWithinThisPath NOTFOUND_TryWithinPowershell
  FOUND_ExecuteWithinThisPath:
  StrCpy $Param1 `"$EXEDIR\$0"`
  goto SearchForExecuteWithinPathFinish ;<== important for not continuing on the else branch
  NOTFOUND_TryWithinPowershell:
  IfFileExists `$SYSDIR\WindowsPowerShell\v1.0\$0*.*` FOUND_ExecuteWithinPowershell NOTFOUND_TryWithinWbem
  FOUND_ExecuteWithinPowershell:
  StrCpy $Param1 `"$SYSDIR\WindowsPowerShell\v1.0\$0"`
  goto SearchForExecuteWithinPathFinish ;<== important for not continuing on the else branch
  NOTFOUND_TryWithinWbem:
  IfFileExists `$SYSDIR\wbem\$0*.*` FOUND_ExecuteWithinWbem NOTFOUND_TryWithinOpenSSH
  FOUND_ExecuteWithinWbem:
  StrCpy $Param1 `"$SYSDIR\wbem\$0"`
  goto SearchForExecuteWithinPathFinish ;<== important for not continuing on the else branch
  NOTFOUND_TryWithinOpenSSH:
  IfFileExists `$SYSDIR\OpenSSH\$0*.*` FOUND_ExecuteWithinOpenSSH NOTFOUND_TryWithinWindows
  FOUND_ExecuteWithinOpenSSH:
  StrCpy $Param1 `"$SYSDIR\OpenSSH\$0"`
  goto SearchForExecuteWithinPathFinish ;<== important for not continuing on the else branch
  NOTFOUND_TryWithinWindows:
  IfFileExists `$WINDIR\$0*.*` FOUND_ExecuteWithinWindows NOTFOUND_ExecuteWithinSystem32
  FOUND_ExecuteWithinWindows:
  StrCpy $Param1 `"$WINDIR\$0"`
  goto SearchForExecuteWithinPathFinish ;<== important for not continuing on the else branch
  NOTFOUND_ExecuteWithinSystem32:
  StrCpy $Param1 `"$SYSDIR\$0"`
  SearchForExecuteWithinPathFinish:
${EndIf}
; Korrigiere *.lnk-Aufrufe
StrCpy $1 $Param1
${StrStrip} `"` $1 $1
StrCpy $0 $1 "" -4
${If} $0 == `.lnk`
  Push $Param1
  Push "\"
  Call StrContains
  Pop $0
  ${If} $0 == ""
    StrCpy $Param1 `$EXEDIR\$Param1`
  ${EndIf}
  StrCpy $1 $Param1
  ${GetFileName} "$Param1" $1
  ${StrRep} `$4` `$Param1` `"` ``
  nsExec::ExecToStack `xcopy "$4" "$app\" /Y`
  StrCpy $3 `$app\$1`
  ${TrimQuotes} $3 $3
  ShellLink::GetShortCutArgs $3
  Pop $3
  StrCpy $Param2 `"$3"`
  StrCpy $2 `$app\$1`
  ${TrimQuotes} $2 $2
  ShellLink::GetShortCutTarget $2
  Pop $2
  StrCpy $Param1 `"$2"`
  ${If} $Param2 == `""`
    StrCpy $Param2 $Param2 "" 2
  ${EndIf}
${EndIf}
; Korrigiere *.msi-Aufrufe
StrCpy $1 $Param1
${StrStrip} `"` $1 $1
StrCpy $0 $1 "" -4
${If} $0 == `.msi`
  StrCpy $Param2 `/i $Param1 $Param2`
  Push ' $Param2 '
  Call Trim
  Pop $Param2
  StrCpy $Param1 `"$SYSDIR\msiexec.exe"`
${EndIf}
; Korrigiere *.msc-Aufrufe
StrCpy $1 $Param1
${StrStrip} `"` $1 $1
StrCpy $0 $1 "" -4
${If} $0 == `.msc`
  StrCpy $Param2 `$Param1 -$ArchitectureNumber $Param2`
  Push ' $Param2 '
  Call Trim
  Pop $Param2
  StrCpy $Param1 `"$SYSDIR\mmc.exe"`
${EndIf}
; Korrigiere *.dll-Aufrufe
Push $Param1
Push ".dll,"
Call StrContains
Pop $0
${If} $0 != ""
  StrCpy $Param2 `$Param1 $Param2`
  Push ' $Param2 '
  Call Trim
  Pop $Param2
  StrCpy $Param1 `"$SYSDIR\rundll32.exe"`  
${EndIf}
; Korrigiere *.cpl-Aufrufe
StrCpy $1 $Param1
${StrStrip} `"` $1 $1
StrCpy $0 $1 "" -9
${If} $0 == `sysdm.cpl`
  StrCpy $Param2 `$Param1 $Param2`
  Push ' $Param2 '
  Call Trim
  Pop $Param2
  StrCpy $Param1 `"$SYSDIR\SystemPropertiesComputerName.exe"`
${Else}
  StrCpy $0 $1 "" -4
  ${If} $0 == `.cpl`
    StrCpy $Param2 `$Param1 $Param2`
    Push ' $Param2 '
    Call Trim
    Pop $Param2
    StrCpy $Param1 `"$SYSDIR\control.exe"`
  ${EndIf}
${EndIf}
; Falls keine Dateiendung angegeben ist, setze Suffix ".exe"
  ${StrRep} `$0` `$Param1` `"` ``
  StrCpy $1 $0 "" -4
  ${If} $1 != `.exe`
 StrCpy $Param1 `"$0.exe"`
${EndIf} 
; Trim Paramters
Push ' $Param1 '
Call Trim
Pop $Param1
Push ' $Param2 '
Call Trim
Pop $Param2
; In Parameter 2 alle Vorkommen von Usernamen an die des LoggedOn-Users anpassen
${If} $Fallback != "currentuser"
  ${StrRep} `$Param2` `$Param2` `\$CurrentUser\` `\$MY_USERNAME\`
  ${StrRep} `$Param2` `$Param2` `$PROFILE` `$MY_USERPROFILE`
${EndIf}
${IfNot} $Param2 == ""
  StrCpy $CommandLineUsed " "
${EndIf}
;MessageBox MB_OK "Alle Params: $Parameters"
;MessageBox MB_OK "Erster: ---$Param1---"
;MessageBox MB_OK "Zweiter: ---$Param2---"

; Escapen der Zeichen speziell für "AdvancedRun" (NirSoft), "MacroRun" und "Run"
${IfNot} $Param1 == ""
  StrCpy $NirSoftParam1 $Param1
  ${StrRep} `$NirSoftParam1` `$NirSoftParam1` `$NirSoftParam1` `"'$NirSoftParam1'"`
${EndIf}
${IfNot} $Param2 == ""
  StrCpy $NirSoftParam2 $Param2
  StrCpy $NirSoftDoubleParam2 $Param2
  StrCpy $NirSoftSolelyParam2 $Param2
  StrCpy $MacroParam2 $Param2
  StrCpy $ProcessRunParam2 $Param2
  StrCpy $NirSoftByMacroParam2 $Param2
  StrCpy $NirSoftCommandLineUsed " /CommandLine "
  ${StrRep} `$NirSoftParam2` `$NirSoftParam2` `"` `"'"""'"`
  ${StrRep} `$NirSoftDoubleParam2` `$NirSoftDoubleParam2` `"` `"'"'"'"'"`
  StrCpy $NirSoftDoubleParam2 `"'"$NirSoftDoubleParam2"'"`
  ${StrRep} `$NirSoftSolelyParam2` `$NirSoftSolelyParam2` `"` `"'"'"`
  ${StrRep} `$NirSoftByMacroParam2` `$NirSoftByMacroParam2` `"` `""'""`
  ${StrRep} `$MacroParam2` `$MacroParam2` `"` `""""""""`
  ${StrRep} `$ProcessRunParam2` `$ProcessRunParam2` `"` `"""` 
${Else}
  StrCpy $NirSoftCommandLineUsed ""
${EndIf}
; Fertig abgeschlossen mit Escapen für das Programm "AdvancedRun" von NirSoft

; Prüfe, ob Programm wirklich existiert - andernfalls breche mit dezenter Konsolen-Fehlermeldung ab:
${StrRep} `$0` `$Param1` `"` ``
IfFileExists `$0` FOUND_StartProgram NOTFOUND_ReturnError
FOUND_StartProgram:
; RunAs LoggedOn-Session braucht mindestens eines der folgenden Kriterien:
; 1. Administrative Rechte (Impersonation)
; 2. Benutzerkontext derselbe wie eingeloggte Windows-Sitzung (normale Ausführung)
; 3. Verwendung von Makro (Hotkey)
${IfNot} $IntegrityLevel == "admin"		;   Falls nur eingeschränkte Berechtigungen vorliegen
  ; Normale Ausführung: Daher nur UAC-Aufruf verhindern...
  StrCpy $RunAsNumber 2
${Else}
  ; Falls erhöhte Rechte vorhanden UND Betriebssystem Vista oder höher:
  ; DeElevation: Ausführen als Logged-In-Benutzer + UAC-Aufruf verhindern..."
  ${IfNot} ${AtLeastWinVista}
    StrCpy $RunAsNumber 6			; funktioniert auch auf früheren OS, unterstützt aber kein /WaitProcess
  ${Else}
    StrCpy $RunAsNumber 5			; funktioniert erst ab Windows Vista, unterstützt /WaitProcess
  ${EndIf}
${EndIf}
${If} $IntegrityLevel == "admin"
${OrIf} $ActualUser == $CurrentUser
  ${If} $UACmode == "/none"
    ExecWait `"$app\AdvancedRun_x$ArchitectureNumber\AdvancedRun.exe" /EXEFilename "$app\AdvancedRun_x$ArchitectureNumber\AdvancedRun.exe" /CommandLine """/EXEFilename "'$NirSoftParam1'"$NirSoftCommandLineUsed$NirSoftDoubleParam2 /UseSearchPath 1 /RunAs 2 /WaitProcess $WaitParam /Run""" /RunAs $RunAsNumber /RunAsProcessName "explorer.exe" /WaitProcess $WaitParam /Run` $0
	${If} $0 != 0		; falls Errorlevel ungleich 0...
    ${AndIf} $ActualUser != "SYSTEM"		; ... und Konto ungleich "SYSTEM" (für OS bei Fehler wegen nicht ausreichendem Speicherin Verbindung mit o.g. Methode)
	  ${If} $Fallback == "macro"
	  	  ${If} $DebugMode == 1
          Call ThisToFront
          MessageBox MB_OK|MB_ICONEXCLAMATION "Impersonation failed (often explicit on Windows XP) - falling back to macro. It imitates the user mouse/keyboard behavior to access the defined application as logged-in user."
        ${EndIf}
	    StrCpy $4 `"$app\AdvancedRun_x$ArchitectureNumber\AdvancedRun.exe" "/EXEFilename """$NirSoftParam1"""$NirSoftCommandLineUsed'$NirSoftByMacroParam2' /RunAs 2 /Run`
        StrLen $0 $4
	    IntOp $0 $0 - 7
	    ${If} $0 > 259
	      ${If} $DebugMode == 1
	        Call ThisToFront
            MessageBox MB_OK|MB_ICONSTOP "This macro invokes application through Run Dialog Box. Added up with escape characters your parameter is longer than the maximum available 259 characters now so the call would fail!$\nShorten your path and parameters and try again."
		  ${EndIf}
	  	  Abort
	    ${EndIf}
        nsExec::ExecToStack `"$app\MacroRun.exe" $4`		; Ausführen per Makro
	  ${EndIf} 	
	  ${If} $Fallback == "currentuser"
	    ${If} $DebugMode == 1
	      Call ThisToFront
          MessageBox MB_OK|MB_ICONEXCLAMATION "Impersonation failed (often explicit on Windows XP) - so according to your preferred fallback method the process is starting under current process owner now."
	    ${EndIf}
        ExecWait `"$app\AdvancedRun_x$ArchitectureNumber\AdvancedRun.exe" /EXEFilename "$NirSoftParam1" $NirSoftCommandLineUsed"$NirSoftSolelyParam2" /UseSearchPath 1 /RunAs 2 /RunAsProcessName "explorer.exe" /WaitProcess $WaitParam /WindowState 1 /Run`	
	  ${EndIf} 	
	  ${If} $Fallback == "exit"
	    ${If} $DebugMode == 1
	      Call ThisToFront
          MessageBox MB_OK|MB_ICONSTOP "Impersonation failed, what is typical for some older Windows versions. You chose to use no fallback so termination is on the only option left."
	    ${EndIf}
		Abort
	  ${EndIf}
	${EndIf} 
  ${EndIf}  
  ${If} $UACmode == "/inherit"
  ${OrIf} $UACmode == "/force"  
    ExecWait `"$app\AdvancedRun_x$ArchitectureNumber\AdvancedRun.exe" /EXEFilename "$app\Run.exe" /CommandLine "$UACMode $WaitMode "'$NirSoftParam1'"$CommandLineUsed$NirSoftParam2" /RunAs $RunAsNumber /RunAsProcessName "explorer.exe" /WaitProcess $WaitParam /WindowState 0 /Run` $0
    ${If} $0 != 0		; falls Errorlevel ungleich 0...
    ${AndIf} $ActualUser != "SYSTEM"		; ... und Konto ungleich "SYSTEM" (für OS bei Fehler wegen nicht ausreichendem Speicherin Verbindung mit o.g. Methode)
	  ${If} $Fallback == "macro"
	  	${If} $DebugMode == 1
          Call ThisToFront
          MessageBox MB_OK|MB_ICONEXCLAMATION "Impersonation failed (often explicit on Windows XP) - falling back to macro. It imitates the user mouse/keyboard behavior to access the defined application as logged-in user."
        ${EndIf}
	    StrCpy $4 `"$app\Run.exe" $UACMode $WaitMode ""$Param1""$CommandLineUsed$MacroParam2`
	    StrLen $0 $4
	    IntOp $0 $0 - 2
	    ${If} $0 > 259
	      ${If} $DebugMode == 1
	        Call ThisToFront
            MessageBox MB_OK|MB_ICONSTOP "This macro invokes application through Run Dialog Box. Added up with escape characters your parameter is longer than the maximum available 259 characters now so the call would fail!$\nShorten your path and parameters and try again."
	      ${EndIf}
          Abort
	    ${EndIf}
        nsExec::ExecToStack `"$app\MacroRun.exe" $4`		; Ausführen per Makro
        StrCpy $RunAsNumber 6		; (nur dummy-weise, damit Kriterium für -FindProcDLL::WaitProcEnd- erfüllt ist)
	  ${EndIf}
	  ${If} $Fallback == "currentuser"
	  	${If} $DebugMode == 1
          Call ThisToFront
          MessageBox MB_OK|MB_ICONEXCLAMATION "Without elevated rights, impersonation not work, so according to your preferred fallback method the process is starting under current process owner now."
        ${EndIf}	  
        ExecWait `"$app\Run.exe" $UACMode $WaitMode $Param1$CommandLineUsed$ProcessRunParam2`
      ${EndIf}
	  ${If} $Fallback == "exit"
	    ${If} $DebugMode == 1
	      Call ThisToFront
          MessageBox MB_OK|MB_ICONSTOP "Impersonation failed, what is typical for some older Windows versions. You chose to use no fallback so termination is on the only option left."
	    ${EndIf}
		Abort
	  ${EndIf}  
    ${EndIf}	
  ${EndIf}
${Else}
  ${If} $Fallback == "macro"
    ${If} $UACmode == "/none"
	  ${If} $DebugMode == 1
        Call ThisToFront
        MessageBox MB_OK|MB_ICONEXCLAMATION "Impersonation failed because of no elevated rights - falling back to macro. It imitates the user mouse/keyboard behavior to access the defined application as logged-in user."
      ${EndIf}
	  StrCpy $4 `"$app\AdvancedRun_x$ArchitectureNumber\AdvancedRun.exe" "/EXEFilename """$NirSoftParam1"""$NirSoftCommandLineUsed'$NirSoftByMacroParam2' /RunAs 2 /Run`
      StrLen $0 $4
	  IntOp $0 $0 - 7
	  ${If} $0 > 259
	  	${If} $DebugMode == 1
	      Call ThisToFront
          MessageBox MB_OK|MB_ICONSTOP "Without elevated rights, a macro invokes application through Run Dialog Box. Added up with escape characters your parameter is longer than the maximum available 259 characters now so the call would fail!$\nShorten your path and parameters and try again."
		${EndIf}
		Abort
	  ${EndIf}
      nsExec::ExecToStack `"$app\MacroRun.exe" $4`		; Ausführen per Makro
	${EndIf}
    ${If} $UACmode == "/inherit"
	${OrIf} $UACmode == "/force" 
	  ${If} $DebugMode == 1
        Call ThisToFront
        MessageBox MB_OK|MB_ICONEXCLAMATION "Impersonation failed because of no elevated rights - falling back to macro. It imitates the user mouse/keyboard behavior to access the defined application as logged-in user."
      ${EndIf}	
	  StrCpy $4 `"$app\Run.exe" $UACMode $WaitMode ""$Param1""$CommandLineUsed$MacroParam2`
	  StrLen $0 $4
	  IntOp $0 $0 - 2
	  ${If} $0 > 259
	    ${If} $DebugMode == 1
	      Call ThisToFront
          MessageBox MB_OK|MB_ICONSTOP "Without elevated rights, a macro invokes application through Run Dialog Box. Added up with escape characters your parameter is longer than the maximum available 259 characters now so the call would fail!$\nShorten your path and parameters and try again."
	    ${EndIf}
        Abort
	  ${EndIf}
      nsExec::ExecToStack `"$app\MacroRun.exe" $4`		; Ausführen per Makro
	${EndIf}	
    StrCpy $RunAsNumber 6		; (nur dummy-weise, damit Kriterium für -FindProcDLL::WaitProcEnd- erfüllt ist)
  ${EndIf}
  ${If} $Fallback == "currentuser"
    ${If} $UACmode == "/none"
	  ${If} $DebugMode == 1
        Call ThisToFront
        MessageBox MB_OK|MB_ICONEXCLAMATION "Without elevated rights, impersonation not work, so according to your preferred fallback method the process is starting under current process owner now."
      ${EndIf}
      ExecWait `"$app\AdvancedRun_x$ArchitectureNumber\AdvancedRun.exe" /EXEFilename "$Param1" $NirSoftCommandLineUsed"$NirSoftSolelyParam2" /UseSearchPath 1 /RunAs 2 /RunAsProcessName "explorer.exe" /WaitProcess $WaitParam /WindowState 1 /Run`
	${EndIf}
    ${If} $UACmode == "/inherit"
	${OrIf} $UACmode == "/force"
      ExecWait `"$app\Run.exe" $UACMode $WaitMode $Param1$CommandLineUsed$ProcessRunParam2`	  
	${EndIf}
  ${EndIf}
  ${If} $Fallback == "exit"
    ${If} $DebugMode == 1
	  Call ThisToFront
      MessageBox MB_OK|MB_ICONSTOP "Running as another account without credentials requires either elevated rights (impersonation) or a macro (sendkeys)! You chose to use no fallback so termination is on the only option left."
    ${EndIf}
	Abort
  ${EndIf}
${EndIf}
Sleep 500
${If} $WaitParam == 1
${AndIf} $RunAsNumber == 6
  ${TrimQuotes} $Param1 $1
  FindProcDLL::WaitProcEnd "Run.exe" -1 
  FindProcDLL::WaitProcEnd "$1" -1 
${EndIf}
${If} $DebugMode == 1
    Call ThisToFront
    MessageBox MB_OK|MB_ICONINFORMATION "Successfully invoked as unelevated self.$\n$\nFlags used:$\n$CollectedFlags$\nFilepath used:$\n$Param1$\n$\nArguments used:$\n$Param2"
${EndIf}	
goto FinishProgramRun
NOTFOUND_ReturnError:
${If} $DebugMode == 1
  StrCpy $0 0
  StrCpy $1 `"`
  ${StrCount} $Param1 $1 i
  Pop $0
  ${If} $0 > 2
    Call ThisToFront
    MessageBox MB_OK|MB_ICONSTOP "More than two quotation marks defined in [Path]File, which leads to [Args] could not be separated from it correctly:$\n$\n$Param1"
  ${Else}
    StrCpy $1 "Program does not exist:$\n$Param1"
    Push $Param1
    Push `"`
    Call StrContains
    Pop $0
    ${If} $0 == ""
	  StrCpy $1 "$1$\nDid you forget quotation marks?"
    ${EndIf} 	
	Call ThisToFront
    MessageBox MB_OK|MB_ICONSTOP "$1"
  ${EndIf}
${EndIf}
FinishProgramRun:

${EndIf}		; ab hier ist es wieder egal, ob die Parameter den Richtlinien entsprechen oder nicht

FunctionEnd



; StrContains
; This function does a case sensitive searches for an occurrence of a substring in a string. 
; It returns the substring if it is found. 
; Otherwise it returns null(""). 
; Written by kenglish_hi
; Adapted from StrReplace written by dandaman32
Var STR_HAYSTACK
Var STR_NEEDLE
Var STR_CONTAINS_VAR_1
Var STR_CONTAINS_VAR_2
Var STR_CONTAINS_VAR_3
Var STR_CONTAINS_VAR_4
Var STR_RETURN_VAR
Function StrContains
  Exch $STR_NEEDLE
  Exch 1
  Exch $STR_HAYSTACK
  ; Uncomment to debug
  ;MessageBox MB_OK 'STR_NEEDLE = $STR_NEEDLE STR_HAYSTACK = $STR_HAYSTACK '
    StrCpy $STR_RETURN_VAR ""
    StrCpy $STR_CONTAINS_VAR_1 -1
    StrLen $STR_CONTAINS_VAR_2 $STR_NEEDLE
    StrLen $STR_CONTAINS_VAR_4 $STR_HAYSTACK
    loop:
      IntOp $STR_CONTAINS_VAR_1 $STR_CONTAINS_VAR_1 + 1
      StrCpy $STR_CONTAINS_VAR_3 $STR_HAYSTACK $STR_CONTAINS_VAR_2 $STR_CONTAINS_VAR_1
      StrCmp $STR_CONTAINS_VAR_3 $STR_NEEDLE found
      StrCmp $STR_CONTAINS_VAR_1 $STR_CONTAINS_VAR_4 done
      Goto loop
    found:
      StrCpy $STR_RETURN_VAR $STR_NEEDLE
      Goto done
    done:
   Pop $STR_NEEDLE ;Prevent "invalid opcode" errors and keep the
   Exch $STR_RETURN_VAR  
FunctionEnd
!macro _StrContainsConstructor OUT NEEDLE HAYSTACK
  Push `${HAYSTACK}`
  Push `${NEEDLE}`
  Call StrContains
  Pop `${OUT}`
!macroend
!define StrContains '!insertmacro "_StrContainsConstructor"'



; Trim
;   Removes leading & trailing whitespace from a string
; Usage:
;   Push 
;   Call Trim
;   Pop 
Function Trim
	Exch $R1 ; Original string
	Push $R2
Loop:
	StrCpy $R2 "$R1" 1
	StrCmp "$R2" " " TrimLeft
	StrCmp "$R2" "$\r" TrimLeft
	StrCmp "$R2" "$\n" TrimLeft
	StrCmp "$R2" "$\t" TrimLeft
	GoTo Loop2
TrimLeft:	
	StrCpy $R1 "$R1" "" 1
	Goto Loop
Loop2:
	StrCpy $R2 "$R1" 1 -1
	StrCmp "$R2" " " TrimRight
	StrCmp "$R2" "$\r" TrimRight
	StrCmp "$R2" "$\n" TrimRight
	StrCmp "$R2" "$\t" TrimRight
	GoTo Done
TrimRight:	
	StrCpy $R1 "$R1" -1
	Goto Loop2
Done:
	Pop $R2
	Exch $R1
FunctionEnd



Function SplitFirstStrPart
  Exch $R0
  Exch
  Exch $R1
  Push $R2
  Push $R3
  StrCpy $R3 $R1
  StrLen $R1 $R0
  IntOp $R1 $R1 + 1
  loop:
    IntOp $R1 $R1 - 1
    StrCpy $R2 $R0 1 -$R1
    StrCmp $R1 0 exit0
    StrCmp $R2 $R3 exit1 loop
  exit0:
  StrCpy $R1 ""
  Goto exit2
  exit1:
    IntOp $R1 $R1 - 1
    StrCmp $R1 0 0 +3
     StrCpy $R2 ""
     Goto +2
    StrCpy $R2 $R0 "" -$R1
    IntOp $R1 $R1 + 1
    StrCpy $R0 $R0 -$R1
    StrCpy $R1 $R2
  exit2:
  Pop $R3
  Pop $R2
  Exch $R1 ;rest
  Exch
  Exch $R0 ;first
FunctionEnd



Function ThisToFront
StrCpy $0 $HWNDPARENT
System::Call 'user32::SetForegroundWindow(i r0)'
FunctionEnd

	

Function wmi_callback_Function
#$R0 = result number, $R1 = total results, $R2 = result name
detailprint "$R0/$R1=$R2"
Push ' $R2 '
Call Trim
Pop $R2
${If} $R2 != ""
  StrCpy $ActualUser $R2
${EndIf}
FunctionEnd



Section
SectionEnd