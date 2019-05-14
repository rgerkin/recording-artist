#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName=copernicus
static strconstant module=copernicus

// Upper left corner of logging panel
static constant logging_x = 0
static constant logging_y = 0
static constant logging_width = 650
static constant logging_height = 305

static strconstant logging_name="LoggingPanel"
static strconstant logging_title="Logging"

static strconstant electrode_locations="Midline;Penetrate;Record"
static strconstant sutter_loc="root:Packages:Sutter:"


// Launch the logging panel
Function logging_panel([rebuild])
	variable rebuild
	build_panel(rebuild,logging_name,logging_title,logging_x,logging_y,logging_width,logging_height)
	logging_panel_controls()
End	


// Create the logging panel controls
function logging_panel_controls()	
	variable xx = logging_x
	variable yy = logging_y
	
	// Animal specs
	logging_panel_animal_specs()
	
	// Drugs present
	logging_panel_drugs()
	
	// Cell coordinates
	logging_panel_coords()
	
	// Notebook and Timed Entry
	logging_panel_notebook()
End


// Render the logging panel notebook
Function logging_panel_notebook([xx, yy])
	variable xx, yy
	
	xx = paramisdefault(xx) ? 358 : xx
	yy = paramisdefault(yy) ? 3 : yy
	
	GroupBox Logg frame=1, pos={xx,yy}, size={278,300}, title="Log", fstyle=1
	logging_panel_timed_entry(xx, yy)
	NewNotebook /f=1 /K=2 /n=ExperimentLog /HOST=$logging_name /W=(xx+10,yy+25,xx+260,yy+275)
	Notebook $(logging_name)#ExperimentLog text = "", margins={0,0,200}
	string log_default=Core#StrPackageSetting(module,"logging","","log_default")
	Notebook $(logging_name)#ExperimentLog text = log_default
	SetActiveSubwindow LoggingPanel#ExperimentLog
	Notebook $(logging_name)#ExperimentLog selection={endOfFile,endOfFile}
End


// Create a widget for timestamped log entries
function logging_panel_timed_entry(xx,yy)
	variable &xx,&yy
	
	xx += 5
	yy += 16
	SetVariable Log_Entry,pos={xx,yy},size={175,16},title="Entry:",value= _STR:"",proc=logging_panel_setvariables
	Button Log_Submit,pos={xx+178,yy-2},size={40,20},proc=logging_panel_buttons,title="Submit"
	Checkbox Log_Timestamp,value=1,pos={xx+223,yy+3}, title="T-stamp"
end


// Create a widget for animal specifications (DOB, weight, etc.)
function logging_panel_animal_specs([xx,yy])
	variable xx,yy
	
	yy = paramisdefault(yy) ? 3 : 0
	
	// Animal DOB
	GroupBox Specs frame=1, pos={xx,yy}, size={350,35}, title="Specs", fstyle=1
	xx+=5; yy+=14
	String dait=ReplaceString("/",Secs2Date(DateTime,0),";")	
	SetVariable Specs_DOB_Month,pos={xx,yy},size={65,16},proc=logging_panel_setvariables, title="DOB:"
	SetVariable Specs_DOB_Month,limits={1,12,1},value=_NUM:str2num(StringFromList(0,dait))
	SetVariable Specs_DOB_Day,pos={xx+72,yy},size={40,16},proc=logging_panel_setvariables
	SetVariable Specs_DOB_Day,limits={1,31,1},value=_NUM:str2num(StringFromList(1,dait))
	SetVariable Specs_DOB_Year,pos={xx+120,yy},size={50,16},proc=logging_panel_setvariables
	SetVariable Specs_DOB_Year,value=_NUM:str2num(StringFromList(2,dait))
	
	// Animal Weight
	xx+=185
	SetVariable Specs_Weight,pos={xx,yy},size={103,16},bodyWidth=50,proc=logging_panel_setvariables,title="Weight (g)"
	SetVariable Specs_Weight,value= _NUM:0
	
	// Cohort
	xx+=120
	PopupMenu Cohort, pos={xx,yy}, value="A;B;C"
end


// Create a widget for drug specifications
function logging_panel_drugs([xx,yy])
	variable xx, yy
	
	yy = paramisdefault(yy) ? 45 : yy
	
	variable max_drugs=3
	GroupBox Drugs frame=1, pos={xx,yy}, size={181,12+max_drugs*25}, title="Drugs", fstyle=1
	yy+=17
	variable yy0 = yy
	variable i,j
	
	for(i=1;i<=max_drugs;i+=1)
		string name="drug"+num2str(i)
		Core#CopyDefaultInstance("Acq","drugs",name)
		dfref df=Core#InstanceHome("Acq","drugs",name)
		nvar /z/sdfr=df active,conc
		svar /z/sdfr=df units
		xx=logging_x+5
		Checkbox $("Drug_"+num2str(i)), pos={xx,yy+2}, variable=active, title=" "
		xx+=17
		SetVariable $("DrugConc_"+num2str(i)),pos={xx,yy},size={30,18},limits={0,1000,1}, variable=conc, title=" "
		xx+=35
		PopupMenu $("DrugUnits_"+num2str(i)),pos={xx,yy-2},size={21,18},mode=1,value=#"Core#PopupMenuOptions(\"copernicus\",\"drugs\",\"\",\"units\",brackets=0)"
		xx+=32
		PopupMenu $("DrugName_"+num2str(i)),pos={xx,yy-2},size={21,18},mode=1,value=#"Core#PopupMenuOptions(\"copernicus\",\"drugs\",\"\",\"names\",brackets=0)"
		yy+=25
	endfor
	
	Button UpdateDrugs,pos={xx+33,yy0+10},size={50,20},title="Update",proc=logging_panel_buttons
	PopupMenu DrugPresets pos={xx+33,yy0+35},size={328,30},mode=0,proc=logging_panel_popupmenus,title="Presets"
	PopupMenu DrugPresets value=#"Core#PopupMenuOptions(\"copernicus\",\"drugs\",\"\",\"presets\",brackets=0)"
end


// Create a widget for cell/electrode coordinate logging
function logging_panel_coords([xx, yy])
	variable xx, yy
	
	yy = paramisdefault(yy) ? 142 : yy
	
	wave /t names = Core#WavTPackageSetting(module, "coordinates", "", "names")
	wave coords = Core#WavTPackageSetting(module, "coordinates", "", "values")
	variable i,j
	for(i=0;i<numpnts(names);i+=1)
		if(!strlen(names[i]))
			deletepoints /m=0 i,1,names,coords
			i-=1
		endif
	endfor
	
	GroupBox Coordinates frame=1, pos={xx,yy}, size={285,90+26*numpnts(names)}, title="Coordinates", fstyle=1
	
	string axes = "X;Y;Z"
	xx = 10
	yy += 22
	GroupBox CurrCoordinates frame=1, pos={xx-2,yy+20}, size={230,25}
	for(j=0;j<ItemsInList(axes);j+=1)
		string axis=StringFromList(j,axes)
		TitleBox $("Coords_Title_"+axis),title=axis,pos={xx+12,yy}
		ValDisplay $("Coords_NowRel_"+axis),pos={xx,yy+27}, size={30,15},value= _NUM:12500
		SetVariable $("Coords_Now_"+axis),pos={xx,yy+50}, size={40,15},value= _NUM:12500, proc=logging_panel_setvariables
		xx += 45
	endfor
	Titlebox Coords_NowRel_Title, pos={xx,yy+25}, size={100,15}, title="Relative"
	SetVariable $("Coords_Now_Name"), pos={xx,yy+51}, size={95,15}, value= _STR:""
	Button Coords_Now_Save, proc=logging_panel_buttons, title="Save"
	
	xx = 10
	yy += 75
	
	variable max_names = 5
	for(i=0;i<max_names;i+=1)
		variable disable=1
		string name = ""
		if(i<numpnts(names)) // Create controls for any saved coordinate sets
			name = names[i]
			if(strlen(name))// Hide controls for any saved coordinate sets that do not currently exist
				disable=0
			endif
		endif
		xx = 10
		for(j=0;j<ItemsInList(axes);j+=1)
			axis=StringFromList(j,axes)
			string ctrl_name = "Coords_"+num2str(i)+"_"+axis
			SetVariable $ctrl_name, pos={xx,yy}, size={40,15}, limits={0,25000,500}, title=" "
			SetVariable $ctrl_name, value=coords[i][j], disable=disable, proc=logging_panel_setvariables
			xx+=60
		endfor
		Checkbox $("Coords_"+num2str(i)+"_relative"), pos={xx-15,yy+3}, proc=logging_panel_checkboxes,value=0, title=" ",pos={xx-15,yy+2}, disable=disable, proc=main_panel_checkboxes
		Titlebox $("Coords_"+num2str(i)+"_name"), pos={xx,yy}, bodywidth=50, title=name, disable=disable
		ControlInfo Coords_Now_Save
		Button $("Coords_"+num2str(i)+"_delete"), pos={v_left,yy}, proc=logging_panel_buttons, title="Delete", disable=disable
		yy += 25*(!disable)
	endfor
end


// Handle all button presses
Function logging_panel_buttons(ctrlName) : ButtonControl
	String ctrlName
	
	String action=StringFromList(0,ctrlName,"_") // First part of ctrlName
	String detail=ctrlName[strlen(action)+1,strlen(ctrlName)] // Remainder of ctrlName
	strswitch(action)
		case "Log":
			// Only one detail: "Submit"
			logging_panel_set_log_entry()
			break
		case "UpdateDrugs":
			// Only one detail: "Update"
			logging_panel_set_drug()
			break
		case "Coords":
			logging_panel_set_coords(detail)
			break
	endswitch
	FirstBlankLine(logging_name+"#ExperimentLog")
End



// Handle timed log entries
function logging_panel_set_log_entry()
	ControlInfo /W=$logging_name Log_Entry
	String text=S_Value
	log_text(text)
end


// Handle changes to drugs
function logging_panel_set_drug()
   // Not implemented yet.
   string text = ""
   variable i=1,j
	do
		ControlInfo $("Drug_"+num2str(i))
		if(v_flag && v_value)
			ControlInfo $("DrugConc_"+num2str(i)); variable conc=v_value
			ControlInfo $("DrugUnits_"+num2str(i)); string units=s_value
			ControlInfo $("DrugName_"+num2str(i)); string name=s_value
			string one_text
			sprintf one_text, "%.2g%s %s," conc, units, name
			text += one_text
		endif
		if(!v_flag)
			break
		endif
		i+=1	
	while(1)
	text = removeending(text,",")
   	log_text(text)
end

function /s add_timestamp(text [,timestamp])
	string text
	variable timestamp
	
	if(paramisdefault(timestamp))
		ControlInfo /W=$logging_name Log_Timestamp
		timestamp = v_value
	endif
	if(timestamp)
		text+=" @ "+Secs2Time(DateTime,3)
	endif
	return text
end

function log_text(text [,timestamp])
	string text
	variable timestamp
	
	if(paramisdefault(timestamp))
		ControlInfo /W=$logging_name Log_Timestamp
		timestamp = v_value
	endif
	text = add_timestamp(text, timestamp=timestamp)
	FirstBlankLine(logging_name+"#ExperimentLog")
	Notebook $(logging_name)#ExperimentLog text=text+"\r"
end



// Handle changes to cell/electrode coordinates
function logging_panel_set_coords(detail)
	string detail
	
	string coord_set = stringfromlist(0, detail, "_")
	string action = stringfromlist(1, detail, "_")
	variable xx, yy
	wave /t names = Core#WavTPackageSetting(module, "coordinates", "", "names")
	wave coords = Core#WavTPackageSetting(module, "coordinates", "", "values")
	variable num_saved = numpnts(names)
	strswitch(coord_set)
		case "Now":
			strswitch(action)
				case "Save": // Save coordinate set
					redimension /n=(num_saved+1) names
					controlinfo Coords_Now_Name
					names[num_saved] = S_value
					redimension /n=(num_saved+1,3) coords
					controlinfo Coords_Now_Name
					variable i
					string axes = "X;Y;Z"
					for(i=0;i<3;i+=1)
						string axis = stringfromlist(i,axes)
						controlinfo $("Coords_Now_"+axis)
						coords[num_saved][i] = v_value
						//string ctrl_name = "Coords_"+num2str(num_saved)+"_"+axis
						//SetVariable $ctrl_name, value=coords[num_saved][i]
					endfor
					logging_panel_coords()
					break
			endswitch
			break
		default:
			variable coord_set_num = str2num(coord_set)
			strswitch(action)
				case "Delete":
					deletepoints coord_set_num, 1, names
					deletepoints /m=0 coord_set_num, 1, coords 
					logging_panel_coords()
					break
			endswitch
	endswitch	
end


// Handle setvariable changes
Function logging_panel_setvariables(info) : SetVariableControl
	STRUCT WMSetVariableAction &info
	if(info.eventCode<0)
		return 0
	endif
	string section = stringfromlist(0, info.ctrlName, "_")
	string detail = stringfromlist(1, info.ctrlName, "_")
	strswitch(section)
		case "Log":
			if(info.eventCode==2)
				//main_panel_set_log_entry()
			endif
			break
		case "Specs":
			strswitch(detail)
				case "Weight":
					logging_panel_set_weight()
					break
				case "DOB":
					logging_panel_set_dob()
					break
			endswitch
			break
		case "Drugs":
			break
		case "Coords":
			// All set variables are coordinates, so recompute relative coordinates.  
			logging_panel_update_coords()
			break
	endswitch
	FirstBlankLine("LoggingPanel#ExperimentLog")
End


// Handle electrode coordinate updates
function logging_panel_update_coords()
	variable i, max_names=5
	make /free/n=3 subtract = {0,0,0}
	wave coords = Core#WavTPackageSetting(module, "coordinates", "", "values")
	for(i=0; i<max_names; i+=1)
		ControlInfo $("Coords_"+num2str(i)+"_relative")
		if(v_value)
			duplicate /free/r=[i,i][0,2] coords subtract
			redimension /n=3 subtract
		endif
	endfor
	variable xx=v_left
	variable yy=v_top
	for(i=0; i<3; i+=1)
		string axis = stringfromlist(i,"X;Y;Z")
		ControlInfo $("Coords_Now_"+axis)
		ValDisplay $("Coords_NowRel_"+axis),value= _NUM:(v_value - subtract[i])
	endfor
end


// Handle DOB changes
function logging_panel_set_dob()
	ControlInfo /W=LoggingPanel Specs_DOB_Month
	Variable month=V_Value
	ControlInfo /W=LoggingPanel Specs_DOB_Day
	Variable day=V_Value
	ControlInfo /W=LoggingPanel Specs_DOB_Year
	Variable year=V_Value
	Notebook LoggingPanel#ExperimentLog findText={"DOB: ",9}
	if(V_flag)
		GetSelection notebook, LoggingPanel#ExperimentLog, 1
		Notebook LoggingPanel#ExperimentLog selection={(V_startparagraph,0),(V_startparagraph+2,0)}
	else
		FirstBlankLine("LoggingPanel#ExperimentLog")
	endif
	Notebook LoggingPanel#ExperimentLog text="DOB: "+num2str(month)+"/"+num2str(day)+"/"+num2str(year)+"\r"
	Notebook LoggingPanel#ExperimentLog text="Age: P"+num2str(round((datetime-date2secs(year,month,day))/(60*60*24)))+"\r"
end


// Handle weight changes
function logging_panel_set_weight()
	ControlInfo /W=LoggingPanel Specs_Weight
	Variable weight=V_Value
	Notebook LoggingPanel#ExperimentLog findText={"Weight: ",9}
	if(V_flag)
		GetSelection notebook, LoggingPanel#ExperimentLog, 1
		Notebook LoggingPanel#ExperimentLog selection={(V_startparagraph,0),(V_startparagraph+1,0)}
	else
		FirstBlankLine("LoggingPanel#ExperimentLog")
	endif
	Notebook LoggingPanel#ExperimentLog text="Weight: "+num2str(weight)+" g\r"
end


// Handle popup menu selections
Function logging_panel_popup_menus(info) : PopupMenuControl
	STRUCT WMPopupAction &info
	if(!SVInput(info.eventCode))
		return 0
	endif
	strswitch(info.ctrlName)
		case "Drug":
			// Not implemented yet
			break
	endswitch
	FirstBlankLine(logging_name+"#ExperimentLog")
End



// Handle checkbox interactions
// TODO: Need to handle setting saved coordinates to be used 
// for computing relative current coordinates.  
Function logging_panel_checkboxes(info) : CheckboxControl
	STRUCT WMCheckboxAction &info
	if(info.eventCode<0)
		return -1
	endif
	String action=StringFromList(0,info.ctrlName,"_")
	strswitch(action)
		case "Coords":
			logging_panel_update_coords()
			break
	endswitch
End


