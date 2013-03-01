#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1.00-dev	//Feb. 22, 2008

//Tab control procedures written by B. Cramer

Function MakeTabDynamic(windowName,tabCtrlName[,PreferredProcedureName])
	string windowName,tabCtrlName,PreferredProcedureName
	
	if(!DynamiTab_Exists(windowName,tabCtrlName))
		return 0
	endif
	
	if(paramisDefault(PreferredProcedureName))
		PreferredProcedureName=""
	endif
	TabControl $tabCtrlName,proc=DynamiTabAction,win=$windowName		//attach action procedure
	TabControl $tabCtrlName,userdata(DT_PrefProc)=StringByKey("PROCWIN",FunctionInfo(GetRTStackInfo(2)))	//store primary procedure window
	TabControl $tabCtrlName,userdata(DT_TabList)="",win=$windowName			//store initially blank tab list
//Fill the Igor TabControl action structure:
	struct WMTabControlAction TCs
	TCs.win=windowName
	TCs.ctrlName=tabCtrlName
	TCs.tab=0			//when first drawn, the 0th tab will be selected
	TCs.eventcode=2
	DynamiTabAction(TCs)
end

Function DynamiTabAction(TCs)
	struct WMTabControlAction &TCs

//Strips all controls from the window and redraws the ones for the selected tab
	string prefix=TCs.ctrlName+"AddTab_"
	if(TCs.eventcode==2)
//gathers available tab functions, finds selected tab in new tab list
		string oldTabList=GetUserData(TCs.win,TCs.ctrlName,"DT_TabList")						//Get names of previously drawn tabs
		string PreferredProcedureName=GetUserData(TCs.win,TCs.ctrlName,"DT_PrefProc")		//Get name of procedure file to search first
		if(strlen(PreferredProcedureName))	//if there is one....
			string TabList=FunctionList(prefix+"*",";","NPARAMS:1,VALTYPE:1,KIND:6,WIN:"+PreferredProcedureName)	//load from preferred procedure file first
		else
			TabList=""
		endif
		TabList+=removefromlist(TabList,FunctionList(prefix+"*",";","NPARAMS:1,VALTYPE:1,KIND:18"))		//load from other procedure files
		TabList=ReplaceString(prefix,removefromlist("AddDynamicTab_prototype",TabList),"")			//removes prototype function and strips prefix

		string selectedTab=stringfromlist(TCs.tab,oldTabList)		//Get current tab name
		TCs.tab=max(0,whichListItem(selectedTab,TabList))		//Get number of current tab in new tab list - default to 0 if current tab name is absent
		selectedTab=stringfromlist(TCs.tab,TabList)				//repeat - in case selected tab is no longer available this will give 0th tab name

//kill current controls, including tab control to make sure all defunct tabs are removed
		ControlInfo/W=$TCs.Win $TCs.ctrlName	//get size and position before killing
		String ControlList=ControlNameList(TCs.win)
		variable i,nitems=itemsinlist(ControlList)
		for(i=0;i<itemsinlist(ControlList);i+=1)
			KillControl/W=$TCs.Win $stringfromlist(i,ControlList)
		endfor
		
//Tabs
		TabControl $TCs.ctrlName,pos={v_left,v_top},size={v_width,v_height},proc=DynamiTabAction,win=$TCs.Win	//redraw tab control
		nitems=itemsinlist(TabList)
		for(i=0;i<nitems;i+=1)
			TabControl $TCs.ctrlName,tablabel(i)=stringfromlist(i,TabList),win=$TCs.Win
		endfor
		TabControl $TCs.ctrlName userdata(DT_TabList)=TabList,userdata(DT_PrefProc)=PreferredProcedureName,value=TCs.tab,win=$TCs.Win

//build controls for current tab
		FuncRef AddDynamicTab_prototype TabFunc=$(prefix+selectedTab)
		TabFunc(TCs.win)
	endif
End

Function RedrawDynamicTab(windowName,tabCtrlName)
	string windowName,tabCtrlName
	
	if(!DynamiTab_Exists(windowName,tabCtrlName))
		return 0
	endif
	
//Fill the Igor TabControl action structure:
	struct WMTabControlAction TCs
	TCs.win=windowName
	TCs.ctrlName=tabCtrlName
	controlInfo/W=$TCs.win $tabCtrlName
	TCs.tab=v_value			//set to current tab
	TCs.eventcode=2
	DynamiTabAction(TCs)
end

Function AddDynamicTab_prototype(windowName)
	string windowName
	
end

Function DynamiTab_Exists(windowName,tabCtrlName)
	string windowName,tabCtrlName

	ControlInfo/w=$windowName $tabCtrlName
	return v_flag==8
end	