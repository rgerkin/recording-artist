// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Experiment%20Browser.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

Function EB_MakeWindow()
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:Packages
	NewDataFolder /O/S root:Packages:ExperimentBrowser 
	DoWindow /K EB_Window
	NewPanel /K=1  /N=EB_Window as "Experiment Browser"
	MoveWindow /W=EB_Window 0.59*win_right,0.65*win_bottom,0.72*win_right,win_bottom
	Button LoadExp proc=EB_Load, title="Load"
	Checkbox No_Save value=1, title="No save"
	Button SaveExp proc=EB_Save, title="Save"
	String /G directory=data_dir+"Simplified:"
	String ls_str=LS(directory,mask="*.pxp")
	ls_str=SortList(ls_str,";",16)
	String curr_file_name=IgorInfo(1)+".pxp"
	Variable curr_file_index=WhichListItem(curr_file_name,ls_str)
	Make /o/T/n=(ItemsInList(ls_str)) Dir_Contents=StringFromList(p,ls_str)
	Make /o/n=(numpnts(Dir_Contents)) Dir_Select=0
	ListBox Dir_ListBox,widths={100,50},size={200,250},pos={0,25}, listWave=Dir_Contents,selWave=Dir_Select,frame=2,mode=2,proc=EB_ListBox,title="Experiments"
	ListBox Dir_ListBox, row=max(0,curr_file_index-2), selrow=max(0,curr_file_index)
	SetDataFolder $curr_folder
End

Function EB_Load(ctrlName)
	String ctrlName
	String curr_folder=GetDataFolder(1)
	SetDataFolder root:Packages:ExperimentBrowser
	SVar directory
	Wave /T Dir_Contents
	//Wave Dir_Select
	//Extract /O/T Dir_Contents,Dir_Selected,Dir_Select & 1 // Cell is selected.  
	//String file_name=Dir_Selected[0]
	ControlInfo /W=EB_Window Dir_ListBox
	String file_Name=Dir_Contents[V_Value]
	if(strlen(file_name))
		ControlInfo No_Save
		if(V_Value)
			Execute /P/Q "SetIgorHook IgorStartOrNewHook=$\"\""
			Execute /P/Q "NEWEXPERIMENT "
		endif
		String command="LOADFILE "+directory+file_name
		Execute /P/Q command
		Execute /P/Q "SetIgorHook IgorStartOrNewHook=IgorStartOrNewHook"
	endif
	SetDataFolder $curr_folder
End

Function EB_Save(ctrlName)
	String ctrlName
	SaveExperiment
End

Function EB_ListBox(EB_Struct) : ListBoxControl
	STRUCT WMListboxAction &EB_Struct
	
	switch(EB_Struct.eventCode)
		case 1: // Clicking the mouse.  
			// Pass through to case 4.  
		case 4: // Picking a new sweep.  			
			break
		case 8: // Vertical scrolling.  Used to keep listboxes in sync (always scrolled vertically to the same degree).  
			break
	endswitch
End