#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion=6.01		// SetWindow/GetWindow hide, needUpdate require Igor 6.0+
#pragma version = 1.0.2.0
#pragma IndependentModule=ACL_WindowDesktops

// ********************
//  LICENSE
// ********************
//	Copyright (c) 2007 by Adam Light
//	
//	Permission is hereby granted, free of charge, to any person
//	obtaining a copy of this software and associated documentation
//	files (the "Software"), to deal in the Software without
//	restriction, including without limitation the rights to use,
//	copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the
//	Software is furnished to do so, subject to the following
//	conditions:
//	
//	The above copyright notice and this permission notice shall be
//	included in all copies or substantial portions of the Software.
//	
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//	OTHER DEALINGS IN THE SOFTWARE.
//
// *************************
//  VERSION HISTORY
// *************************
//	Date			Version #				Changes
//	Mar 30, 2007		Version 1.0.0.0			Initial release
//	Apr 3, 2007		Version 1.0.1.0			Fixed length of kPreferencesFileName (on Mac Igor filenames are limited to 31 chars)
//											Changed width of a few buttons of control panel so they look better on the mac
//											Since XOP windows can't be controlled by SetWindow/GetWindow, they are now excluded from being set to a desktop
//	Apr 10, 2007		Version 1.0.2.0			Before, (on Windows) if a window was minimized when it was hidden and then
//											un-hidden, the size of the window would be restored to its previous size.  This has now been fixed.
//
//

// ********************
//  CONSTANTS
// ********************
static StrConstant kPackageName = "ACL_WindowDesktops"
static StrConstant kPreferencesFileName = "ACL_WindowDesktopsPrefs.bin"
static Constant kPreferencesRecordID = 0
static Constant K_CURRENTPREFSVERSION = 100
static Constant default_num_desktops = 4

// ********************
//  STRUCTURES
// ********************
Structure ACL_WindowDesktopsStr
	uint32 version
	double panelCoords[4]		// left, top, right, bottom
	uint32 reserved[100]		// reserved for future use
EndStructure

// ********************
//  MENUS
// ********************
Menu "Misc", hideable
	"Desktop Control Panel",/Q,Initialize_pnlDesktopControl()
End

// ********************
//  PANEL
// ********************
Function BuildpnlDesktopControl([fresh])
	Variable fresh // Completely just regnerate it (1) or just add/remove buttons (0).  
	fresh=ParamIsDefault(fresh) ? 1 : fresh
	NVar /Z num_desktops=root:Packages:ACL_WindowDesktops:num_desktops
	if(fresh)
		PauseUpdate; Silent 1		// building window...
		DoWindow pnlDesktopControl
		if(V_flag)
			KillWindow pnlDesktopControl
		endif
		NewPanel /W=(702,503,875+24*default_num_desktops,550)/FLT=1/K=1/N=pnlDesktopControl as "Desktop Control"
		Button buttonAssignDefault,pos={48,2},size={70,20},proc=ButtonAssignDesktop,title="Default"
		Button buttonAssignDefault,userdata(desktop)=  "0"
		
		if(!NVar_Exists(num_desktops))
			Variable /G root:Packages:ACL_WindowDesktops:num_desktops=default_num_desktops
		endif
	endif
	Variable i
	for(i=1;i<=num_desktops;i+=1)
		Button $("buttonAssign"+num2str(i)),pos={98+22*i,2},size={20,20},proc=ButtonAssignDesktop,title=num2str(i)+" ",win=pnlDesktopControl
		Button $("buttonAssign"+num2str(i)),userdata(desktop)=num2str(i),win=pnlDesktopControl
		Button $("buttonShow"+num2str(i)),pos={98+22*i,25},size={20,20},proc=ButtonShowDesktop,title=num2str(i)+" ",win=pnlDesktopControl
		Button $("buttonShow"+num2str(i)),userdata(desktop)=num2str(i),win=pnlDesktopControl
	endfor
	// Get rid of old buttons.  
	KillControl /W=pnlDesktopControl $("buttonAssign"+num2str(i))
	KillControl /W=pnlDesktopControl $("buttonShow"+num2str(i))
	
	DoWindow /F pnlDesktopControl
	Button buttonShowAll,pos={98+22*i,25},size={30,20},proc=ButtonShowDesktop,title="All",win=pnlDesktopControl
	Button buttonShowAll,userdata(desktop)=  "-1",win=pnlDesktopControl
	Button buttonShowDefault,pos={48,25},size={70,20},proc=ButtonShowDesktop,title="Default",win=pnlDesktopControl
	Button buttonShowDefault,userdata(desktop)=  "0",win=pnlDesktopControl
	Button buttonHelp,pos={130+22*i,25},size={20,20},proc=ButtonHelp,title="?",fSize=14,win=pnlDesktopControl
	Button buttonHelp,fStyle=1,win=pnlDesktopControl
	TitleBox titleAssign,pos={4,6},size={41,13},title="Assign:",frame=0,fStyle=1,win=pnlDesktopControl
	TitleBox titleShow,pos={4,29},size={35,13},title="Show:",frame=0,fStyle=1,win=pnlDesktopControl
	SetVariable NumDesktops pos={85+22*(i+1),5},size={35,25},title=" ",value=root:Packages:ACL_WindowDesktops:num_desktops,proc=RegenDesktopControl,win=pnlDesktopControl
	if(fresh)
		MoveWindow /W=pnlDesktopControl 102, 203, 240+16*num_desktops,240
	else
		GetWindow pnlDesktopControl wsize
		MoveWindow /W=pnlDesktopControl V_left, V_top, V_left+138+16*num_desktops,V_bottom
	endif
	SetActiveSubwindow _endfloat_
EndMacro

Function RegenDesktopControl(SV_Struct) : SetVariableControl
	STRUCT WMSetVariableAction &SV_Struct
	NVar /Z num_desktops=root:Packages:ACL_WindowDesktops:num_desktops
	BuildpnlDesktopControl(fresh=0)
End

// ********************
//  INITIALIZATION
// ********************
Function Initialize_pnlDesktopControl()
	String panelName = "pnlDesktopControl"
	DoWindow $(panelName)
	//if (!V_flag)
		String curDataFolder = GetDataFolder(1)
		if (!DataFolderExists("root:Packages:ACL_WindowDesktops"))
			NewDataFolder/O/S root:Packages
			NewDataFolder/O/S root:Packages:ACL_WindowDesktops
		else
			SetDataFolder root:Packages:ACL_WindowDesktops
		endif
		
		NVAR/Z currentDisplayedDesktop = root:Packages:ACL_WindowDesktops:currentDisplayedDesktop
		if (!NVAR_Exists(currentDisplayedDesktop))
			Variable/G currentDisplayedDesktop = 0
		endif
		
		BuildpnlDesktopControl()
		SetWindow pnlDesktopControl hook(ACL_DesktopControlHook)=ACL_DesktopControlHook
		STRUCT ACL_WindowDesktopsStr prefs
		LoadDesktopControlPrefs(prefs)
		//MoveWindow/W=pnlDesktopControl prefs.panelCoords[0], prefs.panelCoords[1], prefs.panelCoords[2], prefs.panelCoords[3] 	
		Variable errorNum = ChangeDisplayedDesktop(currentDisplayedDesktop)
		if (errorNum != 0)
			printf "Error %d in Initialize_pnlDesktopControl.\r", errorNum
		endif	
		SetDataFolder curDataFolder	
	//else
	//	BuildpnlDesktopControl()
	//endif
End


// ********************
//  ACTION FUNCTIONS
// ********************
Function ButtonAssignDesktop(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			Variable desktopNum = str2num(GetUserData(ba.win, ba.ctrlName, "desktop"))
			String topWindowName = WinName(0, 4183)	// include all window types EXCEPT procedure windows, since they don't have names
			Variable errorNum = SetWindowDesktop(topWindowName, desktopNum)
			if (errorNum != 0)
				printf "Error %d in ButtonAssignDesktop().\r", errorNum
			endif

			break
	endswitch

	return 0
End

Function ButtonShowDesktop(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable desktopNum = str2num(GetUserData(ba.win, ba.ctrlName, "desktop"))
			Variable errorNum = ChangeDisplayedDesktop(desktopNum)
			if (errorNum != 0)
				printf "Error %d in ButtonShowDesktop().\r", errorNum
			endif
			break
	endswitch

	return 0
End

Function ButtonHelp(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			DisplayHelpTopic/Z "Window Desktops"
			if (V_Flag != 0)	// help topic not found
				DoAlert 0, "The ACL_WindowDesktops.ihf help file could not be found.  It should be in the same directory as the ACL_WindowDesktops.ipf procedure file."
			endif
			break
	endswitch

	return 0
End

// ********************
//  AUXILLARY FUNCTIONS
// ********************
Function GetWindowDesktop(windowName)
	String windowName
	Variable desktopNum
	
	// check to see if window exists
	Variable type = WinType(windowName)
	if (type && type != 13)		// exclude XOP target windows
		desktopNum = str2num(GetUserData(windowName, "", "ACL_desktopNum"))
		if (numtype(desktopNum) != 0)		// value is undefined
			desktopNum = 0		// show on all desktops
		else
			desktopNum = round(desktopNum)
		endif
	else
		desktopNum = -1		// window doesn't exist
	endif
	
	return desktopNum
End

Function SetWindowDesktop(windowName, desktopNum)
	String windowName
	Variable desktopNum
	Variable errorValue
	
	// desktopNum explanation:
	// 0: window will be displayed on all desktops
	// >= 1:  sets the specific desktop where a window will be displayed
	
	// make sure desktopNum parameter is valid
	if (numtype(desktopNum) == 0)		// value is a real number
		if (desktopNum >= 0)
			desktopNum = round(desktopNum)		// desktopNum must be an integer
		endif
	else
		errorValue = -1
		return errorValue
	endif
	
	// check to see if window exists
	Variable type = WinType(windowName)
	if (type)	
		if (type == 13)	// exclude XOP target windows
			printf "Can't assign a target window of an XOP to a desktop.\r"
			return 0
		else
			SetWindow $(windowName) userdata(ACL_desktopNum)=num2str(desktopNum)
		endif
	else
		errorValue = -1		// window doesn't exist
	endif	
	
	if (errorValue == 0)		// if there is no error, call ChangeDisplayedDesktop so the window just set is hidden or visible as approrriate
		NVAR/Z currentDisplayedDesktop = root:Packages:ACL_WindowDesktops:currentDisplayedDesktop
		if (NVAR_Exists(currentDisplayedDesktop))
			errorValue = 	ChangeDisplayedDesktop(currentDisplayedDesktop, forceUpdate=1)
			if (errorValue != 0)
				printf "Error %d in SetWindowDesktop().\r", errorValue
			endif
		endif
	endif
	
	return errorValue		// 0 if successful
End

Function ChangeDisplayedDesktop(newDesktopNum, [forceUpdate])
	Variable newDesktopNum
	Variable forceUpdate		// set to 1 if the desktop should be changed even if currentDesktop = newDesktopNum

	// newDesktopNum explanation
	// -1 	show all windows, regardless of which desktop they are on.
	// 0 		show all windows that are present on any desktop.  The default desktop of all windows is 0,
	//			so unless the window has been assigned to another desktop it will be shown if newDesktopNum = 0
	// >= 1	show windows assigned to that specific desktop.

	if (ParamIsDefault(forceUpdate))
		forceUpdate = 0
	endif
	
	NVAR/Z currentDisplayedDesktop = root:Packages:ACL_WindowDesktops:currentDisplayedDesktop
	if (!NVAR_Exists(currentDisplayedDesktop))
		forceUpdate = 1
	elseif (currentDisplayedDesktop != newDesktopNum)
		forceUpdate = 1
	endif
	
	Variable errorValue
	// make sure newDesktopNum is valid
	if (numtype(newDesktopNum) != 0)		// newDesktopNum is invalid
		errorValue = -1
		return errorValue		// error: invalid newDesktopNum
	elseif (newDesktopNum < -1)
		errorValue = -1
		return errorValue		// error: invalid newDesktopNum
	else
		newDesktopNum = round(newDesktopNum)
	endif

	// With Igor601B09a, Wavemetrics(LH) introduced the possibility with SetWindow to set bit 1 of hide to high, and doing so would cause
	// windows that were minimized before they were hidden to still be minimized when they were un-hidden.  Prior to this addition,
	// setting hide=0 would cause a window to be unhidden and restored to its previous size regardless of whether the window
	// was minimized before hiding or not.
	// Caveat #1:  Unfortunately, if the user is using a version of Igor prior to Igor601B09a, SetWindow will throw an error if it is passed
	// the value 2.  So, we need to see if the version of Igor is new enough to have this feature.  If not, everything will still work, but
	// minimized windows will be restored upon un-hiding.
	// Caveat #2:  On the Macintosh (for now), Bit 1 of hide is ignored, so the only behavior is for minimized windows to be restored
	// upon un-hiding.  But since the Mac is freakish in it's window handling, Mac users get what they pay for.  And if you are a mac user
	// and have read this long comment completely, I appologize :)
	Variable isIgorNewEnough
	Variable IgorVersion = NumberByKey("IGORVERS", IgorInfo(0))
	if (IgorVersion >= 6.01)		// this doesn't check for the beta version, but we will assume that the user is using B09a+
		isIgorNewEnough = 1
	endif	
	
	if (forceUpdate == 1)
		// get a list of all windows that GetWindow/SetWindow can be used with
		String windowList = WinList("*", ";", "WIN:87")	// include all window types EXCEPT procedure windows, since they don't have names
		Variable numWindows = ItemsInList(windowList, ";")
		Variable n, winDesktopNum, hide
		String currentWinName
		For (n=0; n<numWindows; n+=1)
			currentWinName = StringFromList(n, windowList, ";")
			winDesktopNum = GetWindowDesktop(currentWinName)
			if (winDesktopNum >= 0)	// no error
				if (newDesktopNum == -1)		// show ALL windows
					hide = 0
				elseif (winDesktopNum == 0 || winDesktopNum == newDesktopNum)
					hide = 2	* isIgorNewEnough	// show this window
				else
					hide = 1		// hide this window
				endif
				SetWindow $(currentWinName) hide=hide, needUpdate=1
				if(hide!=1)
					GetWindow $currentWinName hide
					if(!(V_Value & 2)) 
						DoWindow /F $currentWinName
					endif
				endif
			endif
		EndFor
	Endif
	
	if (errorValue == 0)
		if (NVAR_Exists(currentDisplayedDesktop))
			currentDisplayedDesktop = newDesktopNum
		endif
		SetShowButtonColors(newDesktopNum, "pnlDesktopControl")
	endif	
	return errorValue
End

Function SetShowButtonColors(desktopNum, windowName)
	// sets the colors of the buttons on pnlDesktopControl so that the desktop that is currently displayed
	// is indicated
	Variable desktopNum
	String windowName		// name of Desktop Control panel window
	
	Variable errorNum
	DoWindow pnlDesktopControl
	if (V_Flag)
		String buttonList, currentCtrlName
		Variable n, numButtons
		Variable desktopControlled		// the number of the desktop controlled by the button
		buttonList = ControlNameList(windowName, ";", "ButtonShow*")
		numButtons = ItemsInList(buttonList, ";")
		For (n=0; n<numButtons; n+=1)
			currentCtrlName = StringFromList(n, buttonList, ";")
			ControlInfo/W=$(windowName) $(currentCtrlName)
			if (abs(V_flag) == 1)	// control is a button
				desktopControlled = str2num(GetUserData(windowName, currentCtrlName, "desktop"))
				if (numtype(desktopControlled) == 0)
					if (desktopControlled == desktopNum)
						Button $(currentCtrlName) win=$(windowName), fColor=(0,43520,65280)		// blue button
					else
						Button $(currentCtrlName) win=$(windowName), fColor=(0,0,0)				// normal colored button
					endif
				endif
			endif			
		EndFor
	endif
End
 
// ********************
//  HOOK FUNCTIONS
// ********************
Function ACL_DesktopControlHook(str)
	STRUCT WMWinHookStruct &str
	Variable statusCode = 0
	Switch (str.eventCode)
		Case 2:		// window is being killed
//			// delete the panel's data folder
//			ControlUpdate/A/W=$(str.winName)
//			if (DataFolderExists("root:Packages:ACL_WindowDesktops"))
//				Execute/P/Q/Z "KillDataFolder root:Packages:ACL_WindowDesktops"
//			endif
//
//			return 0
			break
		Case 12:	// window was moved: store new coordinates
			STRUCT ACL_WindowDesktopsStr prefs
			SaveDesktopControlPrefs(prefs)
			break
		default:			
	EndSwitch
	return statusCode
End

// ********************
//  PACKAGE PREFS LOADING/SAVING
// ********************
Function LoadDesktopControlPrefs(s)
	STRUCT ACL_WindowDesktopsStr &s
	
	// This loads preferences from disk if they exist on disk.
	LoadPackagePreferences kPackageName, kPreferencesFileName, kPreferencesRecordID, s

	// If error, prefs not found or not compatible, initialize them.
	if (V_flag!=0 || V_bytesRead==0 || s.version!=K_CURRENTPREFSVERSION)
		SaveDesktopControlPrefs(s)	// Create default prefs file.
	endif
	
	// code that loads prefs
	
	
End

Function SaveDesktopControlPrefs(s)
	STRUCT ACL_WindowDesktopsStr &s
	
	// fill in structure with current values
	s.version = K_CURRENTPREFSVERSION
	GetWindow pnlDesktopControl wsize			// get current window coordinates
	s.panelCoords[0] = V_left		// Left
	s.panelCoords[1] = V_top		// Top
	s.panelCoords[2] = V_right		// Right
	s.panelCoords[3] = V_bottom		// Bottom
	
	Variable i
	for(i=0; i<100; i+=1)
		s.reserved[i] = 0
	endfor

	SavePackagePreferences kPackageName, kPreferencesFileName, kPreferencesRecordID, s
	return 0	
End