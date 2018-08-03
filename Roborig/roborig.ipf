#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName=Roborig
static strconstant module=Roborig
static constant main_panel_xstart = 3
static constant main_panel_ystart = 2
static strconstant electrode_locations="Midline;Penetrate;Record"
static strconstant sutter_loc="root:Packages:Sutter:"

function init()
	Core#LoadModuleManifest(module)
	Core#LoadPackage(module,"Coordinates")
end

// Generate an alert dialog
function alert(msg, actions)
	string msg // Display this message
	string actions // Semicolon-separated list of actions (Igor commands)
						// to execute for each possible button press
	// If there is one action, the button title will be "OK"
	// If there are two actions, the button titles will be "Yes" and "No"
	// If there are three actions, the button titles will be "Yes", "No", and "Cancel"
	
	variable i
	string buttons
	for(i=0;i<itemsinlist(actions);i+=1)
		
	endfor
	DoAlert itemsinlist(actions)-1, msg
	string action = stringfromlist(v_flag-1,actions)
	Execute /Q/P action
end

// Launch the main panel
Function main_panel([rebuild])
	variable rebuild
	if(rebuild)
		DoWindow /K MainPanel
	else
		if(WinType("MainPanel"))
			DoWindow /F MainPanel
			return 0
		endif
	endif
	NewPanel /K=1 /W=(0,0,800,500) /N=MainPanel as module
	main_panel_notebook()
	main_panel_controls()
End	

// Render the main panel notebook
Function main_panel_notebook()	
	NewNotebook /f=1 /K=2 /n=ExperimentLog /HOST=MainPanel /W=(440,5,785,215)
	Notebook MainPanel#ExperimentLog text = "", margins={0,0,300}
	string log_default=Core#StrPackageSetting(module,"logging","","log_default")
	Notebook MainPanel#ExperimentLog text = log_default
	main_panel_controls()	
	SetActiveSubwindow MainPanel#ExperimentLog
	Notebook MainPanel#ExperimentLog selection={endOfFile,endOfFile}
End

// Create the main panel controls
function main_panel_controls()	
	variable xx = main_panel_xstart
	variable yy = main_panel_ystart
	
	// Timed Entry
	main_panel_timed_entry(xx,yy)
	
	// Animal Specs
	main_panel_animal_specs(xx,yy)
	
	// Drugs present
	main_panel_drugs(xx,yy)
	
	// Cell coordinates
	main_panel_coords(xx,yy)
End

// Create a widget for timestamped log entries
function main_panel_timed_entry(xx,yy)
	variable xx,yy
	
	SetVariable LogEntry,pos={xx,yy+2},size={300,16},title="Log:",value= _STR:"",proc=main_panel_setvariables
	Button LogEntrySubmit,pos={xx+304,yy},size={50,20},proc=main_panel_Buttons,title="Submit"
	Checkbox LogEntryTimestamp,value=1,pos={xx+360,yy+3}, title="T-stamp"
end

// Create a widget for animal specifications (DOB, weight, etc.)
function main_panel_animal_specs(xx,yy)
	variable &xx,&yy
	
	yy+=25
	
	// Animal DOB
	GroupBox DOB frame=1, pos={xx,yy}, size={350,28}
	xx+=5; yy+=6
	String dait=ReplaceString("/",Secs2Date(DateTime,0),";")	
	SetVariable DOB_Month,pos={xx,yy},size={65,16},proc=main_panel_setvariables, title="DOB:"
	SetVariable DOB_Month,limits={1,12,1},value=_NUM:str2num(StringFromList(0,dait))
	SetVariable DOB_Day,pos={xx+72,yy},size={40,16},proc=main_panel_setvariables
	SetVariable DOB_Day,limits={1,31,1},value=_NUM:str2num(StringFromList(1,dait))
	SetVariable DOB_Year,pos={xx+120,yy},size={50,16},proc=main_panel_setvariables
	SetVariable DOB_Year,value=_NUM:str2num(StringFromList(2,dait))
	
	// Animal Weight
	xx+=210
	SetVariable Weight,pos={xx,yy},size={103,16},bodyWidth=50,proc=main_panel_setvariables,title="Weight (g)"
	SetVariable Weight,value= _NUM:0
end

// Create a widget for drug specifications
function main_panel_drugs(xx,yy)
	variable &xx, &yy
	
	xx=main_panel_xstart
	yy+=28
	GroupBox Drugs frame=1, pos={xx,yy}, size={363,35+4*25}
	yy+=7
	variable i,j
	
	for(i=1;i<=3;i+=1)
		string name="drug"+num2str(i)
		Core#CopyDefaultInstance("Acq","drugs",name)
		dfref df=Core#InstanceHome("Acq","drugs",name)
		nvar /z/sdfr=df active,conc
		svar /z/sdfr=df units
		xx=main_panel_xstart+5
		Checkbox $("Drug_"+num2str(i)), pos={xx,yy}, variable=active, title="Drug "+num2str(i)
		xx+=70
		SetVariable $("DrugConc_"+num2str(i)),pos={xx,yy-2},size={50,18},limits={0,1000,1}, variable=conc, title=" "
		xx+=70
		PopupMenu $("DrugUnits_"+num2str(i)),pos={xx,yy-2},size={21,18},mode=1,value=#"Core#PopupMenuOptions(\"Roborig\",\"drugs\",\"\",\"units\",brackets=0)"
		xx+=70
		PopupMenu $("DrugName_"+num2str(i)),pos={xx,yy-2},size={21,18},mode=1,value=#"Core#PopupMenuOptions(\"Roborig\",\"drugs\",\"\",\"names\",brackets=0)"
		yy+=25
	endfor
	
	xx=main_panel_xstart+5
	PopupMenu DrugPresets,pos={xx,yy},size={328,30},mode=0,value=#"Core#PopupMenuOptions(\"Roborig\",\"drugs\",\"\",\"presets\",brackets=0)",proc=main_panel_popupmenus,title="Presets"
	xx+=120
	Button UpdateDrugs,pos={xx,yy+1},size={100,20},title="Update",proc=main_panel_buttons
end

// Create a widget for cell/electrode coordinate logging
function main_panel_coords(xx, yy)
	variable &xx, &yy
	
	xx = main_panel_xstart
	yy = 200
	
	wave /t names = Core#WavTPackageSetting(module, "coordinates", "", "names")
	wave coords = Core#WavTPackageSetting(module, "coordinates", "", "values")
	
	redimension /n=2 names
	redimension /n=(2,3) coords
	names = {"Here","There"}
	coords = {{1,2,3},{4,5,6}}
	
	GroupBox Coordinates frame=1, pos={xx,yy}, size={323,115+2*numpnts(names)}, title="Coordinates", fstyle=1
	variable i,j
	
	string axes = "X;Y;Z"
	xx = 10
	yy += 20
	GroupBox CurrCoordinates frame=1, pos={xx-2,yy+20}, size={314,25}
	for(j=0;j<ItemsInList(axes);j+=1)
		string axis=StringFromList(j,axes)
		TitleBox $("Title_"+axis),title=axis,pos={xx+12,yy}
		SetVariable $("Now_"+axis),pos={xx,yy+25}, size={40,15},value= _NUM:12500
		xx += 60
	endfor
	SetVariable $("Now_Name"), size={100,15}, value= _STR:""
	Button SaveLocation, proc=main_panel_buttons, title="Save"
	xx = main_panel_xstart
	yy += 50
	
	for(i=0;i<numpnts(names);i+=1)
		string name = names[i]
		xx = 10
		for(j=0;j<ItemsInList(axes);j+=1)
			axis=StringFromList(j,axes)
			SetVariable $(name+"_"+axis),pos={xx,yy}, size={40,15}, limits={0,25000,500}, value= _NUM:12500
			xx+=60
		endfor
		Checkbox $("Relative_"+name),proc=main_panel_checkboxes,value=0, title=" ",pos={xx-15,yy+2}
		Titlebox $(name+"_name"),pos={xx,yy}, bodywidth=50, title=name
		Button $(name+"_delete"), proc=main_panel_buttons, title="X"
		yy += 25
	endfor
//	xx=main_panel_xstart-3
//	if(exists("Sutter#Init"))	
//		Checkbox Diag, pos={xx+8,yy+1}, proc=main_panel_Checkboxes, title="Diag",value=1
//		for(j=0;j<ItemsInList(electrode_axes);j+=1)
//			axis=StringFromList(j,electrode_axes)
//			xx+=75
//			SetVariable $("d"+axis),pos={xx,yy},bodywidth=50,title="d"+axis,disable=1
//			SetVariable $("d"+axis),limits={0,25000,10},value= _NUM:0,disable=1
//		endfor
//		xx=main_panel_xstart+95
//		SetVariable Angle,pos={xx,yy},bodywidth=50,title="Angle"
//		SetVariable Angle,limits={0,90,1},value= _NUM:26.565,disable=0,proc=main_panel_SetVariables
//		xx+=100
//		SetVariable dDiag,pos={xx,yy},bodywidth=50,title="dDiag"
//		SetVariable dDiag,limits={0,25000,10},value= _NUM:0,disable=0,proc=main_panel_SetVariables
//		xx+=112
//		SetVariable Sutter_Speed,value=_NUM:1,limits={0,25,0.5}, title="Speed",pos={xx,yy}, bodywidth=50
//		xx+=60
//		Button Sutter_Move proc=main_panel_Buttons,title="Go",pos={xx,yy-2},userData="Go"
//	endif
end

// Handle all button presses
Function main_panel_buttons(ctrlName) : ButtonControl
	String ctrlName
	
	String action=StringFromList(0,ctrlName,"_")
	String detail=StringFromList(1,ctrlName,"_")
	strswitch(action)
		case "LogEntrySubmit":
			main_panel_set_log_entry()
			break
		case "Drug":
			main_panel_set_drug()
			break
		case "CoordinateSet":
			main_panel_set_coords(detail)
			break
		case "Manipulator":
			main_panel_set_manipulator(detail)
			break
	endswitch
	FirstBlankLine("MainPanel#ExperimentLog")
End

// Handle timed log entries
function main_panel_set_log_entry()
	ControlInfo /W=MainPanel LogEntry
	String text=S_Value
	ControlInfo /W=MainPanel LogEntryTimestamp
	if(V_Value)
		text+=" @ "+Secs2Time(DateTime,3)
	endif
	FirstBlankLine("MainPanel#ExperimentLog")
	Notebook MainPanel#ExperimentLog text=text+"\r"
end

// Handle changes to drugs
function main_panel_set_drug()
//	ControlInfo /W=MainPanel Drug; string drug=S_Value; string units=StringFromList(V_Value-1,conc_units)
//	ControlInfo /W=MainPanel Concentration; Variable concentration=V_Value
//	ControlInfo /W=MainPanel Dose; Variable dose=V_Value
//	FirstBlankLine("MainPanel#ExperimentLog")
//	Notebook MainPanel#ExperimentLog text="Drug: "+anaesthetic+" ("+num2str(concentration)+" "+units+") "
//	if(!StringMatch(anaesthetic,"Sevoflurane"))
//		Notebook MainPanel#ExperimentLog text=num2str(dose)+" "
//		Notebook MainPanel#ExperimentLog font="Symbol", text="m"
//		Notebook MainPanel#ExperimentLog font="default", text="L "
//	endif
//	Notebook MainPanel#ExperimentLog font="default", text="@ "+Secs2Time(DateTime,3)+"\r"
end

// Handle changes to cell/electrode coordinates
function main_panel_set_coords(detail)
	string detail
	
	ControlInfo /W=MainPanel $(detail+"_X"); Variable mx=V_Value
	ControlInfo /W=MainPanel $(detail+"_Y"); Variable my=V_Value
	ControlInfo /W=MainPanel $(detail+"_Z"); Variable mz=V_Value
	string text
	sprintf text,detail+": (%d,%d,%d) @ %s",mx,my,mz,Secs2Time(DateTime,3)
	FirstBlankLine("MainPanel#ExperimentLog")
	Notebook MainPanel#ExperimentLog text=text+"\r"
end

// Move the micromanipulator
function main_panel_set_manipulator(detail)
	string detail
	
	if(StringMatch(detail,"move"))
#if exists("Sutter#SlowMove")==6
		ControlInfo /W=MainPanel Sutter_Move
		if(StringMatch(S_userData,"Go"))
			ControlInfo /W=MainPanel dX; Variable dx=V_Value
			ControlInfo /W=MainPanel dY; Variable dy=V_Value
			ControlInfo /W=MainPanel dZ; Variable dz=V_Value
			ControlInfo /W=MainPanel Sutter_Speed; Variable speed=V_Value
			Button Sutter_Move,title="Stop",userData="Stop"
			Sutter#SlowMove(dx,dy,dz,speed)
		else
			Sutter#Stop()
		endif
#endif
	else
#if exists("Sutter#Update")==6
		Sutter#Update()
#endif
		update_main_panel_coords(detail)
	endif
end

//// Update cell/electrode coordinates from the micromanipulator
Function update_main_panel_coords(location)
	String location
//	Variable i
//	String sutter_loc="root:Packages:Sutter:"
//	ControlInfo /W=MainPanel $("Relative_"+location)
//	if(V_Value)
//		Variable relative=1
//	endif
//	for(i=0;i<ItemsInList(electrode_axes);i+=1)
//		String axis=StringFromList(i,electrode_axes)
//		NVar axis_coord=$(sutter_loc+axis+"1")
//		if(relative==1)
//			Variable j=WhichListItem(location,electrode_locations)
//			ControlInfo /W=MainPanel $(StringFromList(j-1,electrode_locations)+"_"+axis)
//			SetVariable $(location+"_"+axis) value=_NUM:(axis_coord-relative*V_Value), win=MainPanel
//		else
//			SetVariable $(location+"_"+axis) value=_NUM:axis_coord, win=MainPanel
//		endif
//	endfor
End

// Handle setvariable changes
Function main_panel_setvariables(info) : SetVariableControl
	STRUCT WMSetVariableAction &info
	if(info.eventCode<0)
		return 0
	endif
	strswitch(info.ctrlName)
		case "LogEntry":
		print info
			if(info.eventCode==2)
				//main_panel_set_log_entry()
			endif
			break
		case "Weight":
			main_panel_set_weight()
			break
		case "DOB_Month":
		case "DOB_Day":
		case "DOB_Year":
			main_panel_set_dob()
			break
		case "dDiag":
			// Pass through.  
		case "Angle":
			ControlInfo Angle; Variable angle=V_Value
			ControlInfo dDiag; Variable dDiag=V_Value
			SetVariable dX, value=_NUM:sin(angle*2*pi/360)*dDiag
			SetVariable dY, value=_NUM:0
			SetVariable dZ, value=_NUM:cos(angle*2*pi/360)*dDiag
			break
	endswitch
	FirstBlankLine("MainPanel#ExperimentLog")
End

// Handle DOB changes
function main_panel_set_dob()
	ControlInfo /W=MainPanel DOB_Month
	Variable month=V_Value
	ControlInfo /W=MainPanel DOB_Day
	Variable day=V_Value
	ControlInfo /W=MainPanel DOB_Year
	Variable year=V_Value
	Notebook MainPanel#ExperimentLog findText={"DOB: ",9}
	if(V_flag)
		GetSelection notebook, MainPanel#ExperimentLog, 1
		Notebook MainPanel#ExperimentLog selection={(V_startparagraph,0),(V_startparagraph+2,0)}
	else
		FirstBlankLine("MainPanel#ExperimentLog")
	endif
	Notebook MainPanel#ExperimentLog text="DOB: "+num2str(month)+"/"+num2str(day)+"/"+num2str(year)+"\r"
	Notebook MainPanel#ExperimentLog text="Age: P"+num2str(round((datetime-date2secs(year,month,day))/(60*60*24)))+"\r"
end

// Handle weight changes
function main_panel_set_weight()
	ControlInfo /W=MainPanel Weight
	Variable weight=V_Value
	Notebook MainPanel#ExperimentLog findText={"Weight: ",9}
	if(V_flag)
		GetSelection notebook, MainPanel#ExperimentLog, 1
		Notebook MainPanel#ExperimentLog selection={(V_startparagraph,0),(V_startparagraph+1,0)}
	else
		FirstBlankLine("MainPanel#ExperimentLog")
	endif
	Notebook MainPanel#ExperimentLog text="Weight: "+num2str(weight)+" g\r"
end

// Handle popup menu selections
Function main_panel_popup_menus(info) : PopupMenuControl
	STRUCT WMPopupAction &info
	if(!SVInput(info.eventCode))
		return 0
	endif
	strswitch(info.ctrlName)
		case "Drug":
			ControlInfo Drug
			//SetVariable Concentration,value=_NUM:str2num(StringFromList(V_Value-1,conc_units)), title=StringFromList(V_Value-1,conc_units)
			//Titlebox Anaesthetic_Units, title=StringFromList(V_Value-1,anaesthetic_units)
			break
	endswitch
	FirstBlankLine("MainPanel#ExperimentLog")
End

// Handle checkbox interactions
Function main_panel_checkboxes(info) : CheckboxControl
	STRUCT WMCheckboxAction &info
	if(info.eventCode<0)
		return -1
	endif
	String action=StringFromList(0,info.ctrlName,"_")
	String detail=StringFromList(1,info.ctrlName,"_")
	strswitch(action)
#if exists("Sutter#Init")
		case "Live":
			Sutter#ToggleLive()
			break
		case "Diag":
				ModifyControlList "dX;dY;dZ" disable=info.checked
				ModifyControlList "Angle;dDiag" disable=!info.checked
				break
		case "Relative":
			break
#endif
	endswitch
End