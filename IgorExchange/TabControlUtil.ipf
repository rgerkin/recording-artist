#pragma rtGlobals=2		// Use modern global access method.
#pragma version = 3.1		// last modified Aug 15 2007 - using new method to determine editiable state for a control that is hidden
#pragma IgorVersion = 5.0 

// The programmer is responsible  for showing the controls for the selected tab, and hiding controls for other tabs.  This can get out of hand quickly if your
// tab controls are complicated. These procedures provide three ways to automate the process of hiding and showing controls. They do no other tab-related
//  processing, but include the option of calling an extra function to do so. If you need to do any special things when a new tab is selected, other than showing
// and hiding the associated controls, provide  a function named with the  name  of the Tab Control plus "_proc".  This function will get passed the tabcontrol
// name and the number of the selected tab, so provide these as paramters to your function.

// My third attempt at a tabcontrol procedure.
// Goals:
// handle nested tabcontrols
// handle instances where controls are shown but not editable
//handle controls that belong to more than one tab
// allow adding and removing tabs and their associated controls from the tabcontrol 

//Implentation:
// New in Igor 5 is the userdata  field for controls. For various reasons this userdata is a nice place to put a database for a tabcontrol
// Each tab of a tabcontrol gets its own user userdata entry, which contains a list of controls belonging to that tab. A single control can belong to
// more than 1 tab of the same tab control, but should not belong to more than one tabcontrol.
// An additional userdata field for the tabcontrol, curTab, contains the number of the current tab

// Weakness: Tab userdata entries are named according to tabname, so if you change the names of the tabs, the TCU3 Tab Procedures won't work


//******************************************************************************************************
// The prototype for the extra updating function
Function TCU_ProtoFunc(name, tab)
	string name
	variable tab
	// Nothing happens here. If you don't need a special update function, this function runs in it's place and does nothing
End

//******************************************************************************************************
//The tab procedure for the TCU_3
Function TCU3_TabProc (name, tab) : TabControl
	String name		// name of tab control
	Variable tab		// number of tab
	
	controlinfo $name
	string OldTabStr, newTabStr
	//Read Previous tab
	oldTabStr = GetUserData("", name, "curTab" )
	// Read current tab string, or set to "" if -1 was passed
	if (tab != -1)
		newTabStr = S_value
	else
		NewTabStr = ""
	endif
	// if new tab = old tab, we are done
	if ((cmpstr (newTabStr, oldTabStr)) == 0)
		return 0
	endif
	// Hide controls for previous tab
	if ((cmpstr (oldTabStr, "")) != 0)
		string controlList = GetUserData("", name, oldTabStr)
		variable iControl, nControls = itemsinList (controlList, ";")
		string aControl
		for (iControl = 0; iControl < nControls; iControl += 1)
			aControl = stringFromList (iControl, controlList)
			TCU3_showOrHideControl (aControl, 0)
		endfor
	endif
	// Show Controls for New Tab
	if (tab != -1)
		controlList = GetUserData("", name, newTabStr)
		nControls = itemsinList (controlList, ";")
		for (iControl = 0; iControl < nControls; iControl += 1)
			aControl = stringFromList (iControl, controlList)
			TCU3_showOrHideControl (aControl, 1)
		endfor
	endif
	//Set current tab in the database.
	tabcontrol $name, UserData (CurTab) =newTabStr
	// If user wants extra update stuff to happen after the standard tab procedure, they must make a function named with the name  of the 
	//Tab Control plus "_proc"  This function will get passed the tabcontrol name and the number of the selected tab, like a normal tab control function
	// Yes, I know you could have your own tabcontrol function that calls TCU3_TabProc then does whatever else it needs to do, but that wouldn't use
	// function references, one of those keen new features of IGOR 4.
	FUNCREF TCU_ProtoFunc UpdateFunc = $(name + "_proc")
	UpdateFunc (name, tab)
end

//******************************************************************************************************
// Shows or Hides a control, setting or clearing the "hide" bit but remembering if a control is disabled or not
Function TCU3_showOrHideControl (name, showOrHide)
	string name //name of control
	variable showOrHide // 0 = hide control, 1 = show
	
	controlInfo $name
	variable type = abs (v_Flag)
	variable state
	if (showOrHide == 0)
		state= V_disable | 0x1    // set the hide bit
	else
		state= V_disable & ~0x1   // clear the hide bit
	endif
	switch (Type)
		case  1:
			Button $name disable=state
			break
		case 2:
			CheckBox $name disable=State
			break
		case 3:
			PopupMenu $name disable=State
			break
		case 4:
			ValDisplay $name disable=State
			break
		case 5:
			SetVariable $name disable=State
			break
		case 6:
			Chart $name disable=State
			break
		case 7:
			Slider $name disable=State
			break
		case 8:		// This one is special, as we want hiding to cascade through nested tab controls
			TabControl $name disable=State
			if (showOrHide == 1) // showing controls 
				TCU3_TabProc (name, V_value)
			else  // hiding controls
				TCU3_TabProc (name, -1)
			endif
			break
		case 9:
			GroupBox $name disable=State
			break
		case 10:
			TitleBox $name disable=State
			break
		case 11:
			ListBox $name disable=State
			break
	endswitch
end


// Use these next functions to  add, remove, rename, or modify the hide/show state of  controls belonging to a tabcontrol
//******************************************************************************************************
// adds the control to the list of controls for requested, removes it from the lists of controls for tabs not requested
Function TCU3_SetList (thePanel, theTabcontrol, Controlname, reqTablist)
	string thePanel	// Name of the conrolpanel/graph to modify
	string theTabcontrol // name of the tab control to modify
	string Controlname	// name of the control to add or modify
	string  reqTablist	// a semicolon-separated list of the names of the tabs for which you want the control to be be visible  e.g., "plot;move;align;"

	ControlInfo /W=$thePanel  $theTabcontrol
	//make sure tabcontrol exists
	if (V_Flag != 8) //not a tabcontrol, or control does not exist
		return 1
	endif
	//Make sure tabcontrol has correct userdata for Curtab, maybe we are adding 1st entry, e.g.
	string curTabStr = GetUserData (thePanel, theTabControl, "curTab" )
	if ((strlen(curTabStr)) == 0) // CurTab Not set
		tabcontrol $theTabcontrol, win = $thePanel,  UserData (curTab) = S_value
	endif
	//Get list of actual tabs on the tabcontrol to match against requested tabs by parsing control recreation string
	string theTabList = TCU_GetTabList (S_Recreation)
	// iterate through list of requested tabs, adding controls to the list for each tab
	variable iReqTab, nReqTabs = itemsinlist (reqTabList, ";"), tabPos
	string aReqTab
	string aControlList = "", aControl = ""
	for (iReqTab = 0; iReqTab < nReqTabs;iReqTab += 1)
		aReqTab = StringFromList (iReqTab, reqTabList, ";")
		// Does requested tab actually exist on tab control?
		tabPos = WhichListItem(aReqTab, theTabList, ";" , 0)
		if (tabPos == -1)
			printf "The requested tab, \"%s\", does not exist on the tabcontrol, \"%s\".\r",aReqTab, theTabcontrol
			continue
		endif
		// Remove tab from the tablist
		theTabList = RemoveListItem(tabPos, theTabList, ";")
		// Add control to database for the tab only if it is not there already
		aControlList = GetUserData (thePanel, theTabControl, aReqTab)
		if ((WhichListItem (controlName, aControlList, ";", 0)) == -1)
			tabcontrol $theTabcontrol, win = $thePanel,  UserData ($aReqTab) = aControlList + controlName + ";"
		endif
	endfor
	// now remove control from where tabs not in the list
	 nReqTabs = itemsinlist (theTabList, ";")
	for (iReqTab = 0; iReqTab < nReqTabs;iReqTab += 1)
		aReqTab = StringFromList (iReqTab, theTabList, ";")
		// Remove control from database for the tab only if it is  there already
		aControlList = GetUserData (thePanel, theTabControl, aReqTab)
		variable controlNum = WhichListItem (controlName, aControlList, ";", 0)
		if (controlNum != -1) // control is there
			tabcontrol $theTabcontrol, win = $thePanel,  UserData ($aReqTab) =  RemoveListItem(controlNum, aControlList, ";")
		endif
	endfor
	return 0
end

//******************************************************************************************************
// Adds a new entry to the List of controls for each requested tab. Does not remove the control from tabs not on the list
Function TCU3_AddToList (thePanel, theTabcontrol, Controlname, reqTablist)
	string thePanel	// Name of the conrolpanel/graph to modify
	string theTabcontrol // name of the tab control to modify
	string Controlname	// name of the control to add or modify
	string  reqTablist	// a semicolon-separated list of the names of the tabs for which you want the control to be be visible  e.g., "plot;move;align;"

	ControlInfo /W=$thePanel  $theTabcontrol
	//make sure tabcontrol exists
	if (V_Flag != 8) //not a tabcontrol, or control does not exist
		return 1
	endif
	//Make sure tabcontrol has correct userdata for Curtab, maybe we are adding 1st entry, e.g.
	string curTabStr = GetUserData (thePanel, theTabControl, "curTab" )
	if ((strlen(curTabStr)) == 0) // CurTab Not set
		tabcontrol $theTabcontrol, win = $thePanel,  UserData (curTab) = S_value
	endif
	//Get list of actual tabs on the tabcontrol to match against requested tabs by parsing control recreation string
	string theTabList = TCU_GetTabList (S_Recreation)
	// iterate through list of requested tabs, adding controls to the list for each tab
	variable iReqTab, nReqTabs = itemsinlist (reqTabList, ";")
	string aReqTab
	string controlList = "", aControl = ""
	for (iReqTab = 0; iReqTab < nReqTabs;iReqTab += 1)
		aReqTab = StringFromList (iReqTab, reqTabList, ";")
		// Does requested tab actually exist on tab control?
		if ((WhichListItem(aReqTab, theTabList, ";" , 0)) == -1)
			printf "The requested tab, \"%s\", does not exist on the tabcontrol, \"%s\".\r",aReqTab, theTabcontrol
			continue
		endif
		// Add control to database for the tab only if it is not there already
		controlList = GetUserData (thePanel, theTabControl, aReqTab)
		if ((WhichListItem (controlName, controlList, ";", 0)) == -1)
			tabcontrol $theTabcontrol, win = $thePanel,  UserData ($aReqTab) = controlList + controlName + ";"
		endif
	endfor
	return 0
end

//******************************************************************************************************
// Removes an entry from the List of controls for each requested tab
Function TCU3_RemoveFromList (thePanel, theTabcontrol, Controlname, reqTablist)
	string thePanel	// Name of the conrolpanel/graph to modify
	string theTabcontrol // name of the tab control to modify
	string Controlname	// name of the control to add or modify
	string  reqTablist	// a semi-colon list of the names of the tabs for which you want the control to no longer be visible. 
	
	ControlInfo /W=$thePanel  $theTabcontrol
	//make sure tabcontrol exists
	if (V_Flag != 8) //not a tabcontrol, or control does not exist
		return 1
	endif
	//Get list of actual tabs on the tabcontrol to match against requested tabs by parsing control recreation string
	 string theTabList = TCU_GetTabList (S_Recreation)
	// iterate through list of requested tabs, removing control from the list for each tab
	variable iReqTab, nReqTabs = itemsinlist (reqTabList, ";")
	string aReqTab
	string aControlList = "", aControl = ""
	for (iReqTab = 0; iReqTab < nReqTabs;iReqTab += 1)
		aReqTab = StringFromList (iReqTab, reqTabList, ";")
		// Does requested tab actually exist on tab control?
		if ((WhichListItem(aReqTab, theTabList, ";",  0)) == -1)
			printf "The requested tab, \"%s\", does not exist on the tabcontrol, \"%s\".\r",aReqTab, theTabcontrol
			continue
		endif
		// Remove control from database for the tab only if it is  there already
		aControlList = GetUserData (thePanel, theTabControl, aReqTab)
		variable controlNum = WhichListItem (controlName, aControlList, ";", 0)
		if (controlNum != -1) // control is there
			tabcontrol $theTabcontrol, win = $thePanel,  UserData ($aReqTab) =  RemoveListItem(controlNum, aControlList, ";")
		endif
	endfor
	return 0
end

//******************************************************************************************************
// Renames a control in the tab databases for a tabcontrol. returns 0 if succesful, returns 1 if control to be renamed is not found
// Because some people will persist in renaming controls to store status info, eg., ON/OFF
Function TCU3_RenameinList (thePanel, theTabcontrol, Controlname, NewControlName)
	string thePanel, theTabcontrol, Controlname, NewControlName
	
	ControlInfo /W=$thePanel  $theTabcontrol
	//make sure tabcontrol exists
	if (V_Flag != 8) //not a tabcontrol, or control does not exist
		return 1
	endif
	//Get list of  tabs on the tabcontrol to match against requested tabs by parsing control recreation string
	string theTabList = TCU_GetTabList (S_Recreation)
	//iterate through database for each tab
	variable iTab, nTabs = itemsinList (theTabList, ";")
	variable controlNum
	string aTab, aControlList
	for (iTab = 0; iTab < nTabs; iTab += 1)
		aTab = stringfromList (iTab, theTabList, ";")
		aControlList = GetUserData(thePanel, theTabControl, aTab)
		controlNum = WhichListItem (controlName, aControlList, ";", 0)
		if (controlNum != -1)
			aControlList = RemoveListItem(controlNum, aControlList, ";")
			aControlList = AddListItem(NewControlName, aControlList, ";", controlNum)
			tabcontrol $theTabcontrol, win = $thePanel, UserData ($aTab) = aControlList
		endif
	endfor
	return 0
end

//******************************************************************************************************
// Clears the control Database for a tabcontrol 
Function TCU3_ClearDBase (thePanel, theTabControl)
	string thepanel, theTabcontrol
	
	ControlInfo /W=$thePanel  $theTabcontrol
	//make sure tabcontrol exists
	if (V_Flag != 8) //not a tabcontrol, or control does not exist
		return 1
	endif
	//Get list of  tabs on the tabcontrol by parsing control recreation string
	string theTabList = TCU_GetTabList (S_Recreation)
	//iterate through database for each tab
	variable iTab, nTabs = itemsinList (theTabList, ";")
	variable controlNum
	string aTab, aControlList
	for (iTab = 0; iTab < nTabs; iTab += 1)
		aTab = stringfromList (iTab, theTabList, ";")
		tabcontrol $theTabcontrol, win = $thePanel,  UserData ($aTab) = ""
	endfor
	return 0
end

// Use these next functions when tabs will be added and removed from the tabcontrol by the user
// These functions modify the actual controls as well as the database
//******************************************************************************************************
Function TCU3_AddTab (thePanel, theTabControl, newTabName)
	string thePanel	// Name of the conrolpanel/graph to modify
	string theTabcontrol // name of the tab control to modify
	string newTabName // name of the new tab to add to the control panel
	
	ControlInfo /W=$thePanel  $theTabcontrol
	//make sure tabcontrol exists
	if (V_Flag != 8) //not a tabcontrol, or control does not exist
		return 1
	endif
	//iterate through tablist for the tabControl
	string theTabList = TCU_GetTabList (S_Recreation)
	variable iTab, nTabs = itemsinList (theTabList, ";")
	string aTab
	for (iTab = 0; iTab < nTabs; iTab += 1)
		aTab = stringfromList (iTab, theTabList, ";")
		if ((cmpstr (aTab, NewTabName)) == 0) // tab already there, so exit
			return 0
		endif
	endfor
	TabControl $theTabControl tabLabel (iTab)= NewTabName
end

//******************************************************************************************************
// Removes a tab from a tab control, and removes controls belonging only to the removed tab
Function TCU3_RemoveTab (thePanel, theTabControl,RemoveTabName)
	string thePanel	// Name of the conrolpanel/graph to modify
	string theTabcontrol // name of the tab control to modify
	string RemoveTabName // najme of the old tab to remove from the control panel

	ControlInfo /W=$thePanel  $theTabcontrol
	//make sure tabcontrol exists
	if (V_Flag != 8) //not a tabcontrol, or control does not exist
		return 1
	endif
	//Get list of  tabs on the tabcontrol by parsing control recreation string
	string theTabList = TCU_GetTabList (S_Recreation)
	// Quit with error if the tab to remove is not there
	variable RemoveTabPos = WhichListItem (RemoveTabName, theTabList, ";", 0)
	if (removeTabPos == -1)
		printf "The requested tab, \"%s\", was not found.\r", removeTabName
		return 1
	endif
	variable iTab, nTabs = itemsinList (theTabList, ";")
	//iterate through database for each tab, winnowing the list of remove controls if they also belong on another tab
	string aRemoveControl, removeControlList =  GetUserData(thePanel, theTabControl, RemoveTabName)
	variable iRemoveControl, iControl, nControls, nRemoveControls = itemsinList (removeControlList, ";")
	string aTab, aControlList, aControl
	variable foundPos
	for (iTab = 0; iTab < nTabs; iTab += 1)
		if (iTab == removeTabPos) // skip the tab to be removed for now
			continue
		endif
		aTab = stringfromlist (iTab, theTabList)
		aControlList = GetUserData(thePanel, theTabControl, aTab)
		nControls = itemsinList (aControlList, ";")
		for (iControl = 0; iControl < nControls; iControl += 1)
			aControl = stringfromlist (iControl, aControlList)
			foundPos = WhichListItem (aControl, removeControlList, ";", 0)
			if (foundPos != -1) // found, so don't remove this control
				removeControlList = RemoveListItem(iControl, removeControlList, ";")
			endif
		endfor
	endfor
	// Now remove controls that are only present on the tab to be removed
	nRemoveControls = itemsinList (removeControlList, ";")
	for (iRemoveControl = 0; iRemoveControl < nRemoveControls; iRemoveControl += 1)
		aControl = stringFromList (iRemoveControl, removeControlList, ";")
		KillControl /W=$thePanel $aControl
	endfor
	//Reset the database for the tab - is there a way to completely delete a userdata field?
	tabcontrol $theTabcontrol, win = $thePanel,  UserData ($removeTabName) = ""
	//remove the tab from the tabcontrol
	for (iTab = removeTabPos; iTab < nTabs-1; iTab+= 1)
		TabControl $theTabControl tablabel (iTab) = stringfromlist (iTab+1, theTabList, ";")
	endfor
	TabControl $theTabControl tablabel (nTabs -1) = ""
	// put tab control to the previous tab in the list, just to put things in a known state
	doupdate
	if (removeTabPos == 0)
		tabcontrol $theTabcontrol, win = $thePanel, value = 0
		TCU3_TabProc (theTabControl, 0)
	else
		tabcontrol $theTabcontrol, win = $thePanel, value = removeTabPos-1
		TCU3_TabProc (theTabControl, removeTabPos-1)
	endif
	//return success
	return 0
end

//******************************************************************************************************
// Utility function that gets a list of tabs from a tabControl re-creation string. Don't use on any other kind of string
Function/S TCU_GetTabList (S_recreation)
	string &S_recreation
	
	string theTabList = ""
	variable iTab, iPos, iEnd
	for (itab = 0; ; iTab += 1, iPos = iEnd)
		iPos = strsearch(S_recreation, "tabLabel(" + num2str (iTab) + ")", iPos) + 13
		if (iPos < 14)
			break
		endif
		iEnd = strsearch(S_recreation, "\"", iPos + 2) -1
		theTabList += S_recreation [iPos, iEnd] + ";"
	endfor
	return theTabList
end

//******************************************************************************************************
// Old versions included for backwards conpatibility

// A procedure file to simplify the management of the tab controls introduced in IGOR 4.

// The First Method (used when you set the procedure of your tab control to proc=TCU_TabProc) assigns controls to tabcontrols and tabs based on a 
// naming/numbering scheme, inspired by Kevin Boyce's original tab control functions. To be identified and processed, the name of each control must start with:  
// the first two letters in the name of the tab control to which it belongs, underscore, the number of the tab for which it should be shown, in two digit format, 00, 01, etc.

// If you need to do any special things when a new tab is selected, other than showing and hiding the associated controls, provide  a function named with the
// name  of the Tab Control plus "_proc".  This function will get passed the tabcontrol name and the number of the selected tab, so provide these as paramters
// to your function.

// In summary:
// 1) add  #include "TabControlUtil" to the top of your procedure file and put TabControlUtil.ipf in the igor:user procedures folder
// 2) set the procedure of your tab control to  proc=TCU_TabProc
// 3) name the controls of each tabcontrol and its tabs appropriately
// 4) optionally, write an extra procedure file for things other than showing and hiding controls

// There are a few caveats for this use of names to identify controls:
// 1) No other controls on the control panel can have names starting with the first two letters of the name of the tab control plus an underscore. 
// 2) It does not work well for tab controls within tab controls. You will need to give a nested tabcontrol its own name and hide and show it as a special case.
// 3) Situations where you want to have controls shown but not editible (disable = 2) are not handled. All controls are enabled when shown.
// 4) No provision exists for cases where you want to have a control showing for more than 1 tab

// Therefore, another method of managing tabcontrols was developed using the windownote for the panel or graph containing the tabcontrol to hold a database. 
// Set the procedure of your tab control to proc=TCU2_TabProc to use this method, and create a database in the Window note of your graph/panel using the
// functions provided (Addtolist, Renameinlist, SetAbleState, SetTabList), or edit the database manually according to the following specifications:
// The database statrs with the string "beginTCUDB.", and ends with the string "endTCUDB"
// For each tab control on the window, include a key=value entry as follows (that's "=" to separate keystring and value string and "." to separate key-value pairs)
// Nameoftabcontrol=CurrentTab:The currently selected tab for this tabcontrol;ControlList:List of Controls and options separated by "*"
// For each control, the options are separated by "/" from the name, in the following order. Multiple entries in the tabs showing option are separated by commas
// name of first control/variable for Type of 1st Control / state when active 0 or 2 / tablist e.g. 1,2,4 
//So a simple database might begin like this:

// beginTCUDB.NameofMyFirstTabControl=CurrentTab:1;ControlList:MyButton/1/2/1,2*MyotherButton/1/0/1,3*;.endTCUDB

// An array of functions is provided to make and manage the database in the WindowNote. You can use these to add and modify controls in the database
// A GUI control panel to make a database is provided in the procedure file "TabControlUtilManager"

// In summary
// 1) add  #include "TabControlUtil" to the top of your procedure file and put TabControlUtil.ipf in the igor:user procedures folder
// 2) set the procedure of your tab control to   proc=TCU2_TabProc
// 3) Make an appropriate database and put it in the windownote of the panel
// 4) optionally, write an extra procedure file for things other than showing and hiding controls


// Functions for Method 1
//******************************************************************************************************
//Finds controls belonging to the selected tab of the selected tabcontrol and shows them. It hides controls belonging to other tabs of the tabcontrol, but
// ignores controls belonging to other tabcontrols that might be on the same panel. Passing -1 as the tab will hide all controls of the tab control
Function TCU_TabProc (name, tab) : TabControl
	String name		// name of tab control
	Variable tab		// number of tab
	
	string tabStr
	// if a control belongs to this tab of this tabcontrol, it's name  should start with tabstr
	if (tab < 10)	// this will handle up to 99 tabs, which "should be enough for anyone"
		 tabStr = name [0,1] + "_" +  "0" + num2str (Tab)
	else
		tabStr = name [0,1] + "_" + num2str (tab)
	endif
	
	// Get a list of all the controls in the window, and iterate through them
	Variable ii
	String all = ControlNameList("")
	String thisControl
	variable numcntrls = itemsinlist (all)
	
	FOR (ii = 0; ii < numcntrls; ii += 1)
		thisControl = StringFromList( ii, all )
		// Found another control.  Does it belong to this tabcontrol? Is it this tabcontrol?
		if (((CmpStr (thisControl[0,2],  tabstr [0,2])) == 0) && ((CmpStr (thisControl,  name)) != 0))
			// If it matches the current tab, show it.  Otherwise, hide it
			if ((CmpStr (thisControl[3,4], tabStr [3,4])) == 0)
				TCU_ShowControl (thisControl, 0 )
			else
				TCU_ShowControl (thisControl, 1)
			endif
		endif
	ENDFOR
	
	// If user wants extra update stuff to happen after the standard tab procedure, they must make a function named with the name  of the 
	//Tab Control plus "_proc"  This function will get passed the tabcontrol name and the number of the selected tab,  like a normal tab control function
	// Yes, I know you could have your own tabcontrol function that calls TCU_TabProc then does whatever else it needs to do, but that wouldn't use
	// function references, one of those keen new features of IGOR 4.
	FUNCREF TCU_ProtoFunc UpdateFunc = $(name + "_proc")
	UpdateFunc (name, tab)
end


//******************************************************************************************************
// Shows or hides any kind of control in the top window
Function TCU_ShowControl( name, disable )
	String name
	Variable disable
	
	// What kind of control is it?
	ControlInfo $name
	Variable type = v_flag
	switch( abs(type) )
		case 1:		// button
			Button $name disable=disable
			break
		
		case 2:		// checkbox
			CheckBox $name disable=disable
			break
		
		case 3:		// popup menu
			PopupMenu $name disable=disable
			break
		
		case 4:
			ValDisplay $name disable=disable
			break
		
		case 5:
			SetVariable $name disable=disable
			break
		
		case 6:
			Chart $name disable=disable
			break
		
		case 7:
			Slider $name disable=disable
			break
		
		case 8:
			TabControl $name disable=disable
			break
		
		case 9:
			GroupBox $name disable=disable
			break
		
		case 10:
			TitleBox $name disable=disable
			break
		
		case 11:
			ListBox $name disable=disable
			break
	endswitch
End


//Functions for Method 2
//******************************************************************************************************
//Finds controls belonging to the selected tab of the selected tabcontrol and shows them. It hides controls belonging to other tabs of the tabcontrol, but
// ignores controls belonging to other tabcontrols that might be on the same panel. Passing -1 as the tab will hide all controls of the tab control
Function TCU2_TabProc (name, tab) : TabControl
	String name		// name of tab control
	Variable tab		// number of tab

	// Get the meta-Info for this TabControl
	GetWindow kwTopWin note
	variable startp = strsearch(S_Value, "beginTCUDB", 0)
	if (startp == -1)
		return -1
	endif
	startp  += 11
	variable endp = strsearch(S_Value, "endTCUDB", startp)
	if (endp < startp + 2)	// No database
		return -1
	endif
	
	string DBaseStr = S_Value [startP, endP-1]
	S_Value = S_Value [0, startP-1] + S_Value [endP, strlen (S_Value)-1]
	string TabControlInfo = stringbyKey (name, DBaseStr, "=", ".")
	variable PreviousTab =  numberbyKey ("CurrentTab", TabControlInfo,  ":", ";")
	string ControlList = stringbyKey ("ControlList", TabControlInfo, ":", ";")
	
	//iterate through the list of controls, showing and hiding
	variable  ii, iii
	string ctrlinfo, showforlist
	variable wasShown, shownow
	variable  numshownfor
	variable ashowntab
	variable numcontrols =  itemsinlist (ControlList, "*")
	For (ii = 0; ii < numcontrols; ii += 1)
		ctrlinfo = stringfromlist (ii, ControlList, "*")
		showforlist = stringfromlist (3, ctrlinfo, "/")
		numshownfor = itemsinlist (showforlist, ",")
		wasShown = 0
		shownow = 0
		For (iii = 0; iii < numshownfor; iii += 1)
			ashowntab = str2num (stringfromlist (iii, showforlist,","))
			if (ashowntab == PreviousTab)		// control was shown for the last tab
				wasshown = 1
			endif
			if (ashowntab == tab)
				shownow = 1
			endif
		endfor
		if ((wasshown == 0) && (shownow == 1))	// show the control
			TCU2_ShowControl(str2num (stringfromlist (1, ctrlinfo, "/")), stringfromlist (0, ctrlinfo, "/"), str2num(stringfromlist (2, ctrlinfo, "/")))
		else
			if ((wasshown == 1) && (shownow == 0))	// hide the control
				TCU2_ShowControl(str2num (stringfromlist (1, ctrlinfo, "/")), stringfromlist (0, ctrlinfo, "/"), 1)
			endif
		endif
	endfor
	
	// Update the CurrentTab, and replace the database
	TabControlInfo = ReplaceNumberByKey  ("CurrentTab", TabControlInfo, tab)
	DBaseStr = ReplaceStringbyKey (name, DBaseStr, TabControlInfo, "=", ".")
	S_Value [StartP] = DBaseStr
	SetWindow kwTopWin note = S_Value

	// If user wants extra update stuff to happen after the standard tab procedure, they must make a function named with the name  of the 
	//Tab Control plus "_proc"  This function will get passed the tabcontrol name and the number of the selected tab,  like a normal tab control function
	// Yes, I know you could have your own tabcontrol function that calls TCU_TabProc2 then does whatever else it needs to do, but that wouldn't use
	// function references, one of those keen new features of IGOR 4.
	FUNCREF TCU_ProtoFunc UpdateFunc = $(name + "_proc")
	UpdateFunc (name, tab)
end


//******************************************************************************************************
// Shows or hides any kind of control in the top window
Function TCU2_ShowControl (Type, name, State )
	Variable type
	String Name
	Variable State
	
	type = abs (type)
	switch (Type)
		case  1:
			Button $name disable=state
			break
		
		case 2:
			CheckBox $name disable=State
			break
		
		case 3:
			PopupMenu $name disable=State
			break
		
		case 4:
			ValDisplay $name disable=State
			break
		
		case 5:
			SetVariable $name disable=State
			break
		
		case 6:
			Chart $name disable=State
			break
		
		case 7:
			Slider $name disable=State
			break
		
		case 8:		// This one is special, as we want hiding/showing to cascade through nested tab controls
			TabControl $name disable=State
			TCU2_HideShowTabsControls (name, State)
			break
		
		case 9:
			GroupBox $name disable=State
			break
		
		case 10:
			TitleBox $name disable=State
			break
		
		case 11:
			ListBox $name disable=State
			break
	endswitch
End



//******************************************************************************************************
// Hides all controls for the currently selected tab (assuming they are showing) , or shows all controls for the selected tab (assuming they are hidden)
// Because Tabcontrols in Tabcontrols should just work, dammit
Function TCU2_HideShowTabsControls (name, State)
	string name
	variable State	// 1 means to hide, 0 or 2 means to show

	// Get the meta-Info for this TabControl
	GetWindow kwTopWin note
	variable startp = strsearch(S_Value, "beginTCUDB", 0)
	if (startp > -1)
	 	startp += 11
		variable endp = strsearch(S_Value, "endTCUDB", startp)
	else		// no database
		return -1
	endif
	
	string DBaseStr = S_Value [startP, endP-1]
	S_Value = S_Value [0, startP-1] + S_Value [endP, strlen (S_Value)-1]
	string TabControlInfo = stringbyKey (name, DBaseStr, "=", ".")
	variable PreviousTab =  numberbyKey ("CurrentTab", TabControlInfo,  ":", ";")
	string ControlList = stringbyKey ("ControlList", TabControlInfo, ":", ";")
	variable numcontrols =  itemsinlist (ControlList, "*")
	
	string ctrlinfo, showforlist
	variable ii, iii, numshownfor, ashowntab
	For (ii = 0; ii < numcontrols; ii += 1)
		ctrlinfo = stringfromlist (ii, ControlList, "*")
		showforlist = stringfromlist (3, ctrlinfo, "/")
		numshownfor = itemsinlist (showforlist, ",")
		For (iii = 0; iii < numshownfor; iii += 1)
			ashowntab = str2num (stringfromlist (iii, showforlist,","))
			if (ashowntab == PreviousTab)		// control is currently showing or shold be showing
				TCU2_ShowControl(str2num (stringfromlist (1, ctrlinfo, "/")), stringfromlist (0, ctrlinfo, "/"), State == 1 ? 1 : str2num(stringfromlist (2, ctrlinfo, "/")))
				break
			endif
		endfor
	endfor
end




//Sets the current tab of the tabcontrol. Good if do when first making a panel, and when changing controls from  user procedure
Function TCU2_SetCurrentTab (thePanel, theTabcontrol, CurrentTab)
	string thePanel	// Name of the conrolpanel/graph to modify
	string theTabcontrol // name of the tab control to modify
	variable CurrentTab	// Set the current tab to this value
	
	// Get the windownote  for this tabcontrol
	GetWindow $thePanel note
	
	// Does a database exist for this panel?, If not, make one
	variable startp, endp
	string S_valueTemp, DBaseStr
	startp = strsearch(S_Value, "beginTCUDB", 0)
	if (startp == -1)	// No DataBase
		S_valueTemp = S_Value
		startp = strlen (S_ValueTemp) + 11
		S_valueTemp += "beginTCUDB.endTCUDB"
		DBaseStr = ""
	else
		startp += 11
		endp = strsearch(S_Value, "endTCUDB", startp)
		DBaseStr = S_Value [startP, endP-1]
		S_ValueTemp = S_Value [0, startP-1] + S_Value [endP, strlen (S_Value)-1]
	endif
		
	// Does a record for the selected tabcontrol exist in the DataBase?, If not, make one
	string TabControlInfo = stringbyKey (theTabControl, DBaseStr, "=", ".")
	if ((cmpstr (TabControlInfo, "")) == 0)	// Record does not exists for this tabcontrol
		DBaseStr += theTabcontrol + "=CurrentTab:" + num2str (CurrentTab)  +  "*;."
	else
		DBaseStr =  ReplaceNumberByKey ("CurrentTab", "DBaseStr",CurrentTab)
	endif
	
	//replace the window note  with modified DBase
	S_ValueTemp [startP] = DBaseStr
	setwindow $thePanel note = S_ValueTemp

end

// Use these next functions to  add and remove tabs
//******************************************************************************************************
Function TCU2_AddTab (thePanel, theTabControl, newTabName)
	string thePanel	// Name of the conrolpanel/graph to modify
	string theTabcontrol // name of the tab control to modify
	string newTabName // najme of the new tab to add to the control panel
	
	//if thePanel window does not exist, exit with error
	if ((cmpstr(thePanel, WinList ( thePanel, "", "WIN:64"))) != 0)
		return 1
	endif
	// Get info about control, stores info in various globals used in following code
	controlinfo /W=$thePanel $theTabControl
	//if theTabcontrol does not exist, exit with error
	if (V_Flag == 0)
		return 1
	endif
	//see if tab is already there, and count how many tabs are on the control
	variable ii, sp, ep =1
	For (ii = 0; ; ii += 1)
		sp = strsearch(S_recreation, "tabLabel(" + num2str (ii) + ")", ep )
		if (sp == -1)
			break
		endif
		sp += 13
		ep = strsearch(S_recreation, "\"", sp )
		sp = ep
		if (cmpstr (newTabName, S_Recreation [sp, ep -1]) == 2)  //tab is already on the tab control, so exit with error
			return 1
		endif
	Endfor
	//add the new tab after all the other tabs
	TabControl AEStabControl tabLabel (ii)= NewTabName
	//exit with success
	return 0
end


Function TCU2_RemoveTab (thePanel, theTabControl, oldTabName)
	string thePanel	// Name of the conrolpanel/graph to modify
	string theTabcontrol // name of the tab control to modify
	string oldTabName // najme of the old tab to remove from the control panel
	
	
end

// Use these next functions to  add, remove, rename, or modify the hide/show state of  controls belonging to a tabcontrol
//******************************************************************************************************
// Adds a new entry to the List for each tab or changes it if it exists
Function TCU2_AddToList (thePanel, theTabcontrol, Controlname, Controltype, Tablist, AbleState)
	string thePanel	// Name of the conrolpanel/graph to modify
	string theTabcontrol // name of the tab control to modify
	string Controlname	// name of the control to add or modify
	string  Tablist	// a list of the tabs for which you want the control to be be visible. comma separated e.g., "1,2,4"
	variable Controltype	// the type of control (button, popup menu, etc.), the value returned by V_Value when doing controlinfo on the control
	variable AbleState	// The state of the control when it is shown (can be 0 for enabled or 2 for visible but disbaled)
	
	//Build a string for the new control
	string controlstr =  Controlname + "/" + num2str (Controltype) + "/" + num2str (ableState) + "/" + Tablist
	
	// Get the windownote  for this tabcontrol
	GetWindow $thePanel note
	
	// Does a database exist for this panel?, If not, make one
	variable startp, endp
	string S_valueTemp, DBaseStr
	startp = strsearch(S_Value, "beginTCUDB", 0)
	if (startp == -1)	// No DataBase
		S_valueTemp = S_Value
		startp = strlen (S_ValueTemp) + 11
		S_valueTemp += "beginTCUDB.endTCUDB"
		DBaseStr = ""
	else
		startp += 11
		endp = strsearch(S_Value, "endTCUDB", startp)
		DBaseStr = S_Value [startP, endP-1]
		S_ValueTemp = S_Value [0, startP-1] + S_Value [endP, strlen (S_Value)-1]
	endif
		
	// Does a record for the selected tabcontrol exist in the DataBase?, If not, make one
	string TabControlInfo = stringbyKey (theTabControl, DBaseStr, "=", ".")
	if ((cmpstr (TabControlInfo, "")) == 0)	// Record does not exists for this tabcontrol
		controlinfo /W = $thePanel theTabcontrol
		DBaseStr += theTabcontrol + "=CurrentTab:" + num2str (V_Value)  +  "*;."
	endif
		
	// Does the control currently exist in the database for this tabcontrol?, If so, remove the old copy
	string ControlList = stringbyKey ("controlList", TabControlInfo, ":", ";")
	variable ii,  numcontrols = itemsinlist (controllist, "*")
	for (ii =0; ii < numcontrols; ii += 1)
		if ((cmpstr (Controlname, stringfromlist (0, stringfromlist (ii, ControlList, "*"), "/"))) == 0)
			break
		endif
	endfor
	if (ii < numcontrols)	// then control was already present, so remove it
		ControlList = RemoveListItem(ii, ControlList, "*")
	endif
	
	// Add the new control to the control list
	ControlList = AddListItem (controlstr, ControlList, "*", ii)
	
	//Update and replace
	TabControlInfo = ReplaceStringByKey ("ControlList", TabControlInfo, ControlList)
	DBaseStr = ReplaceStringByKey (theTabcontrol, DBaseStr, TabControlInfo, "=", ".")
	S_ValueTemp [startP] = DBaseStr
	setwindow $thePanel note = S_ValueTemp
end

//******************************************************************************************************
// Renames a control in the database, leaving all the other attributes for that control intact. returns 0 if succesful, returns 1 if control to be renamed is not found
Function TCU2_RenameinList (thePanel, theTabcontrol, Controlname, NewControlName)
	string thePanel, theTabcontrol, Controlname, NewControlName
	
	// Get the windownote  for this tabcontrol
	GetWindow $thePanel note
	
	// Does a database exist for this panel?, If not, return 1
	variable startp, endp
	string S_valueTemp, DBaseStr
	startp = strsearch(S_Value, "beginTCUDB", 0)
	if (startp == -1)	// No DataBase
		return 1
	else
		startp += 11
		endp = strsearch(S_Value, "endTCUDB", startp)
		DBaseStr = S_Value [startP, endP-1]
		S_ValueTemp = S_Value [0, startP-1] + S_Value [endP, strlen (S_Value)-1]
	endif
	
	// Does a record for the selected tabcontrol exist in the DataBase?, If not, return 1
	string TabControlInfo = stringbyKey (theTabControl, DBaseStr, "=", ".")
	if ((cmpstr (TabControlInfo, "")) == 0)	// Record does not exists for this tabcontrol
		return 1
	endif
	
	// Does the control currently exist in the database for this tabcontrol?, If not return 1
	string ControlList = stringbyKey ("controlList", TabControlInfo, ":", ";")
	variable ii,  numcontrols = itemsinlist (controllist, "*")
	for (ii =0; ii < numcontrols; ii += 1)
		if ((cmpstr (Controlname, stringfromlist (0, stringfromlist (ii, ControlList, "*"), "/"))) == 0)
			break
		endif
	endfor
	if (ii < numcontrols)	// then control was already present, so remove it and replace with modified version
		string TheControl = stringfromlist (ii, ControlList, "*")
		TheControl =  RemoveListItem (0, TheControl, "/")
		TheControl = AddListItem (NewControlName, TheControl, "/", 0)
	else
		return 1
	endif
	
	// Add the revised control back to the control list
	ControlList = RemoveListItem (ii, ControlList, "*")
	ControlList = AddListItem (TheControl, ControlList, "*", ii)
	
	//Update and replace
	TabControlInfo = ReplaceStringByKey ("ControlList", TabControlInfo, ControlList)
	DBaseStr = ReplaceStringByKey (theTabcontrol, DBaseStr, TabControlInfo, "=", ".")
	S_ValueTemp [startP] = DBaseStr
	setwindow $thePanel note = S_ValueTemp
		
	return 0
end

//******************************************************************************************************
// Sets the enable state for a control in the database, leaving all the other attributes for that control intact. returns 0 if succesful, returns 1 if control to be renamed is not found
// Enabled state can be either enabled (0) or shown but disabled (2)	
Function TCU2_SetAbleState (thePanel, theTabcontrol, Controlname, NewAbleState)
	string thePanel, theTabcontrol, Controlname
	variable NewAbleState
	
	// AbleState has to be 0 or 2
	if (!((newAbleState == 2) || (newAbleState == 0)))
		return 1
	endif
	// Get the windownote  for this tabcontrol
	GetWindow $thePanel note
	
	// Does a database exist for this panel?, If not, return 1
	variable startp, endp
	string S_valueTemp, DBaseStr
	startp = strsearch(S_Value, "beginTCUDB", 0)
	if (startp == -1)	// No DataBase
		return 1
	else
		startp += 11
		endp = strsearch(S_Value, "endTCUDB", startp)
		DBaseStr = S_Value [startP, endP-1]
		S_ValueTemp = S_Value [0, startP-1] + S_Value [endP, strlen (S_Value)-1]
	endif
	
	// Does a record for the selected tabcontrol exist in the DataBase?, If not, return 1
	string TabControlInfo = stringbyKey (theTabControl, DBaseStr, "=", ".")
	if ((cmpstr (TabControlInfo, "")) == 0)	// Record does not exists for this tabcontrol
		return 1
	endif
	
	// Does the control currently exist in the database for this tabcontrol?, If not return 1
	string ControlList = stringbyKey ("controlList", TabControlInfo, ":", ";")
	variable ii,  numcontrols = itemsinlist (controllist, "*")
	for (ii =0; ii < numcontrols; ii += 1)
		if ((cmpstr (Controlname, stringfromlist (0, stringfromlist (ii, ControlList, "*"), "/"))) == 0)
			break
		endif
	endfor
	if (ii < numcontrols)	// then control was already present, so remove it and replace with modified version
		string TheControl = stringfromlist (ii, ControlList, "*")
		TheControl =  RemoveListItem (2, thecontrol, "/")
		TheControl = AddListItem (num2str (NewAbleState), theControl, "/", 2)
	else
		return 1
	endif
	
	// Add the revised control back to the control list
	ControlList = RemoveListItem (ii, ControlList, "*")
	ControlList = AddListItem (TheControl, ControlList, "*", ii)
	
	//Update and replace
	TabControlInfo = ReplaceStringByKey ("ControlList", TabControlInfo, ControlList)
	DBaseStr = ReplaceStringByKey (theTabcontrol, DBaseStr, TabControlInfo, "=", ".")
	S_ValueTemp [startP] = DBaseStr
	setwindow $thePanel note = S_ValueTemp
		
	return 0
end

//******************************************************************************************************
// Sets the tablist for a control in the database, leaving all the other attributes for that control intact. returns 0 if succesful, returns 1 if control to be renamed is not found
// should probably perform a sanity check on the new tablist (make sure it is a comma separated list of numbers, but it currently does not.
Function TCU2_SetTabList (thePanel, theTabcontrol, Controlname, NewTabList)
	string thePanel, theTabcontrol, Controlname, NewTabList
	
	// Get the windownote  for this tabcontrol
	GetWindow $thePanel note
	
	// Does a database exist for this panel?, If not, return 1
	variable startp, endp
	string S_valueTemp, DBaseStr
	startp = strsearch(S_Value, "beginTCUDB", 0)
	if (startp == -1)	// No DataBase
		return 1
	else
		startp += 11
		endp = strsearch(S_Value, "endTCUDB", startp)
		DBaseStr = S_Value [startP, endP-1]
		S_ValueTemp = S_Value [0, startP-1] + S_Value [endP, strlen (S_Value)-1]
	endif
	
	// Does a record for the selected tabcontrol exist in the DataBase?, If not, return 1
	string TabControlInfo = stringbyKey (theTabControl, DBaseStr, "=", ".")
	if ((cmpstr (TabControlInfo, "")) == 0)	// Record does not exists for this tabcontrol
		return 1
	endif
	
	// Does the control currently exist in the database for this tabcontrol?, If not return 1
	string ControlList = stringbyKey ("controlList", TabControlInfo, ":", ";")
	variable ii,  numcontrols = itemsinlist (controllist, "*")
	for (ii =0; ii < numcontrols; ii += 1)
		if ((cmpstr (Controlname, stringfromlist (0, stringfromlist (ii, ControlList, "*"), "/"))) == 0)
			break
		endif
	endfor
	if (ii < numcontrols)	// then control was already present, so remove it and replace with modified version
		string TheControl = stringfromlist (ii, ControlList, "*")
		TheControl =  RemoveListItem (3, TheControl, "/")
		TheControl = AddListItem (NewTabList, TheControl, "/", 3)
	else
		return 1
	endif
	
	// Add the revised control back to the control list
	ControlList = RemoveListItem (ii, ControlList, "*")
	ControlList = AddListItem (TheControl, ControlList, "*", ii)
	
	//Update and replace
	TabControlInfo = ReplaceStringByKey ("ControlList", TabControlInfo, ControlList)
	DBaseStr = ReplaceStringByKey (theTabcontrol, DBaseStr, TabControlInfo, "=", ".")
	S_ValueTemp [startP] = DBaseStr
	setwindow $thePanel note = S_ValueTemp
		
	return 0
end

//******************************************************************************************************
// Removes the given control from the list of controls that belong to the given tab control from the database of the given panel
Function TCU2_RemoveFromList (thePanel, theTabcontrol, ControlName)
	string thePanel, theTabcontrol, Controlname
	
	// Get the windownote  for this tabcontrol
	GetWindow $thePanel note
	
	// Does a database exist for this panel?, If not, return 1
	variable startp, endp
	string S_valueTemp, DBaseStr
	startp = strsearch(S_Value, "beginTCUDB", 0)
	if (startp == -1)	// No DataBase
		return 1
	else
		startp += 11
		endp = strsearch(S_Value, "endTCUDB", startp)
		DBaseStr = S_Value [startP, endP-1]
		S_ValueTemp = S_Value [0, startP-1] + S_Value [endP, strlen (S_Value)-1]
	endif
	
	// Does a record for the selected tabcontrol exist in the DataBase?, If not, return 1
	string TabControlInfo = stringbyKey (theTabControl, DBaseStr, "=", ".")
	if ((cmpstr (TabControlInfo, "")) == 0)	// Record does not exists for this tabcontrol
		return 1
	endif
	
	// Does the control currently exist in the database for this tabcontrol?, If not return 1
	string ControlList = stringbyKey ("controlList", TabControlInfo, ":", ";")
	variable ii,  numcontrols = itemsinlist (controllist, "*")
	for (ii =0; ii < numcontrols; ii += 1)
		if ((cmpstr (Controlname, stringfromlist (0, stringfromlist (ii, ControlList, "*"), "/"))) == 0)
			break
		endif
	endfor
	if (ii < numcontrols)	// then control was  present, so remove it
		ControlList = RemoveListItem (ii, ControlList, "*")
	else
		return 1
	endif
	
	//Update and replace
	TabControlInfo = ReplaceStringByKey ("ControlList", TabControlInfo, ControlList)
	DBaseStr = ReplaceStringByKey (theTabcontrol, DBaseStr, TabControlInfo, "=", ".")
	S_ValueTemp [startP] = DBaseStr
	setwindow $thePanel note = S_ValueTemp
		
	return 0

end

//******************************************************************************************************
// removes a tab control, and all of its entries, from the database
Function TCU2_RemoveTabControl (thePanel, theTabcontrol)
	string thePanel, theTabControl
	
	// Get the windownote  for this tabcontrol
	GetWindow $thePanel note
	
	// Does a database exist for this panel?, If not, return 1
	variable startp, endp
	string S_valueTemp, DBaseStr
	startp = strsearch(S_Value, "beginTCUDB", 0)
	if (startp == -1)	// No DataBase
		return 1
	else
		startp += 11
		endp = strsearch(S_Value, "endTCUDB", startp)
		DBaseStr = S_Value [startP, endP-1]
		S_ValueTemp = S_Value [0, startP-1] + S_Value [endP, strlen (S_Value)-1]
	endif
	
	// Does a record for the selected tabcontrol exist in the DataBase?, If not, return 1
	string TabControlInfo = stringbyKey (theTabControl, DBaseStr, "=", ".")
	if ((cmpstr (TabControlInfo, "")) == 0)	// Record does not exists for this tabcontrol
		return 1
	else
		DBaseStr = RemoveByKey(theTabcontrol, DBaseStr, "=", ".")
	endif
	
	//Update and replace
	S_ValueTemp [startP] = DBaseStr
	setwindow $thePanel note = S_ValueTemp
		
	return 0

end

//******************************************************************************************************
// Clears the TabControl Database for a panel 
Function TCU2_ClearDBase (thePanel)
	string thepanel
	
	// Get the windownote  for this panel or graph
	GetWindow $thePanel note
	
	// Does a database exist for this panel?, If not, return 1
	variable startp, endp
	startp = strsearch(S_Value, "beginTCUDB", 0)
	if (startp == -1)	// No DataBase
		return 1
	else
		endp = strsearch(S_Value, "endTCUDB", startp)
		S_Value = S_Value [0, startP-1] + S_Value [endP + 8, strlen (S_Value)-1]
		setwindow $thePanel note = S_Value
	endif
	return 0
end

