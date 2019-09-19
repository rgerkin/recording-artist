#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName=copernicus
static strconstant module=copernicus

// Upper left corner of logging panel
static constant logging_x = 0
static constant logging_y = 40
static constant logging_width = 275
static constant logging_height = 325
static constant tab_width = 270
static strconstant logging_tabs = "Animal;Electrode;Pharma;Notebook"

static strconstant logging_win_name="LoggingPanel"
static strconstant logging_win_title="Logging"

static strconstant electrode_locations="Midline;Penetrate;Record"
static strconstant sutter_loc="root:Packages:Sutter:"


// Launch the logging panel
Function logging_panel([rebuild])
	variable rebuild
	build_panel(rebuild,logging_win_name,logging_win_title,logging_x,logging_y,logging_width,logging_height,float=0)
	logging_panel_controls()
End	


// Create the logging panel controls
function logging_panel_controls()	
	variable xx = logging_x
	variable yy = logging_y
	
	variable i
	for(i=0; i<itemsinlist(logging_tabs); i+=1)
		TabControl logging_tab_control, size={tab_width,125}, tablabel(i)=stringfromlist(i, logging_tabs), focusring=0, font="Arial Black", proc=set_logging_tab, win=$logging_win_name
	endfor
	
	// Animal specs
	logging_panel_animal_specs()
	
	// Drugs present
	logging_panel_drugs()
	
	// Cell coordinates
	logging_panel_coords()
	
	// Notebook and Timed Entry
	logging_panel_notebook()
	
	struct WMTabControlAction info
	info.tab=0
	set_logging_tab(info)
End

function set_logging_tab(info)
	STRUCT WMTabControlAction &info
	
	string tab = stringfromlist(info.tab, logging_tabs)
	variable i
	for(i=0; i<itemsinlist(logging_tabs);i+=1)
		string other_tab = stringfromlist(i, logging_tabs)
		string controls = ControlNameList(logging_win_name,";",other_tab+"*")
		variable self = stringmatch(tab, other_tab)
		ModifyControlList controls, disable=!self, win=$logging_win_name
	endfor
	Notebook $(logging_win_name)#ExperimentLog visible=stringmatch(tab, "Notebook")
	strswitch(tab)
		case "Animal":
			variable tab_height = 115
			break
		case "Electrode":
			tab_height = 180
			break
		case "Pharma":
			tab_height = 110
			break
		case "Notebook":
			tab_height = 320
			break
	endswitch
	TabControl logging_tab_control, size={tab_width, tab_height}
	GetWindow $logging_win_name wsize
	MoveWindow /W=$logging_win_name v_left, v_top, v_left+tab_width*0.9, v_top+tab_height*0.90
end


// Render the logging panel notebook
Function logging_panel_notebook([xx, yy])
	variable xx, yy
	
	xx = paramisdefault(xx) ? 0 : xx
	yy = paramisdefault(yy) ? 20 : yy
	
	//GroupBox Notebook_box frame=1, pos={xx,yy}, size={278,300}, title="", fstyle=1
	logging_panel_timed_entry(xx, yy)
	NewNotebook /f=1 /K=2 /n=ExperimentLog /HOST=$logging_win_name /W=(xx,yy+25,xx+260,yy+275)
	Notebook $(logging_win_name)#ExperimentLog text = "", margins={0,0,200}
	string log_default=Core#StrPackageSetting(module,"logging","","log_default")
	Notebook $(logging_win_name)#ExperimentLog text = log_default
	SetActiveSubwindow LoggingPanel#ExperimentLog
	Notebook $(logging_win_name)#ExperimentLog selection={endOfFile,endOfFile}
End


// Create a widget for timestamped log entries
function logging_panel_timed_entry(xx,yy)
	variable &xx,&yy
	
	xx += 5
	yy += 16
	SetVariable Notebook_Entry,pos={xx,yy},size={175,16},title="Entry:",value= _STR:"",proc=logging_panel_setvariables
	//Button Log_Submit,pos={xx+178,yy-2},size={40,20},proc=logging_panel_buttons,title="✔", help={"Your log entry here"}
	Checkbox Notebook_Timestamp,value=1,pos={xx+190,yy+3}, title="⏰"
end


// Create a widget for animal specifications (DOB, weight, etc.)
function logging_panel_animal_specs([xx,yy])
	variable xx,yy
	
	yy = paramisdefault(yy) ? 15 : 0
	
	// Animal DOB
	//GroupBox Animal frame=1, pos={xx,yy}, size={350,35}, title="Specs", fstyle=1
	xx+=5; yy+=14
	String dait=ReplaceString("/",Secs2Date(DateTime,0),";")	
	SetVariable Animal_DOB_Month,pos={xx,yy},size={65,16},proc=logging_panel_setvariables, title="DOB:"
	SetVariable Animal_DOB_Month,limits={1,12,1},value=_NUM:str2num(StringFromList(0,dait))
	SetVariable Animal_DOB_Day,pos={xx+72,yy},size={40,16},proc=logging_panel_setvariables
	SetVariable Animal_DOB_Day,limits={1,31,1},value=_NUM:str2num(StringFromList(1,dait))
	SetVariable Animal_DOB_Year,pos={xx+120,yy},size={50,16},proc=logging_panel_setvariables
	SetVariable Animal_DOB_Year,value=_NUM:str2num(StringFromList(2,dait))
	
	// Animal Weight
	yy+=30
	SetVariable Animal_Weight,pos={xx+6,yy},size={103,16},bodyWidth=50,proc=logging_panel_setvariables,title="Weight (g)"
	SetVariable Animal_Weight,value= _NUM:0
	
	// Cohort
	yy+=30
	PopupMenu Animal_Cohort, pos={xx,yy}, value="A;B;C", title="Cohort"
end


// Create a widget for drug specifications
function logging_panel_drugs([xx,yy])
	variable xx, yy
	
	xx = paramisdefault(xx) ? 10 : xx
	yy = paramisdefault(yy) ? 15 : yy
	variable x_start = xx
	
	variable max_drugs=3
	//GroupBox Pharma frame=1, pos={xx,yy}, size={181,12+max_drugs*25}, title="Drugs", fstyle=1
	yy+=17
	variable yy0 = yy
	variable i,j
	
	for(i=1;i<=max_drugs;i+=1)
		string name="drug"+num2str(i)
		Core#CopyDefaultInstance("Acq","drugs",name)
		dfref df=Core#InstanceHome("Acq","drugs",name)
		nvar /z/sdfr=df active,conc
		svar /z/sdfr=df units
		xx=x_start
		Checkbox $("Pharma_"+num2str(i)), pos={xx,yy+3}, variable=active, title=" "
		xx+=17
		SetVariable $("Pharma_Conc_"+num2str(i)),pos={xx,yy},size={30,18},limits={0,1000,1}, variable=conc, title=" "
		xx+=35
		PopupMenu $("Pharma_Units_"+num2str(i)),pos={xx,yy},size={21,18},mode=1,value=#"Core#PopupMenuOptions(\"copernicus\",\"drugs\",\"\",\"units\",brackets=0)"
		xx+=40
		PopupMenu $("Pharma_Name_"+num2str(i)),pos={xx,yy},size={21,18},mode=1,value=#"Core#PopupMenuOptions(\"copernicus\",\"drugs\",\"\",\"names\",brackets=0)"
		yy+=25
	endfor
	
	Button Pharma_Update,pos={xx+31,yy0+10},size={50,20},title="Update",proc=logging_panel_buttons
	PopupMenu Pharma_Presets pos={xx+31,yy0+35},size={328,30},mode=0,proc=logging_panel_popupmenus,title="Presets"
	PopupMenu Pharma_Presets value=#"Core#PopupMenuOptions(\"copernicus\",\"drugs\",\"\",\"presets\",brackets=0)"
end


// Create a widget for cell/electrode coordinate logging
function logging_panel_coords([xx, yy])
	variable xx, yy
	
	yy = paramisdefault(yy) ? 5 : yy
	
	wave /t names = Core#WavTPackageSetting(module, "coordinates", "", "names")
	wave coords = Core#WavTPackageSetting(module, "coordinates", "", "values")
	variable i,j
	for(i=0;i<numpnts(names);i+=1)
		if(!strlen(names[i]))
			deletepoints /m=0 i,1,names,coords
			i-=1
		endif
	endfor
	
	//GroupBox Electrode_box frame=1, pos={xx,yy}, size={285,90+26*numpnts(names)}, title="Coordinates", fstyle=1
	
	string axes = "X;Y;Z"
	xx = 10
	yy += 25
	GroupBox Electrode_current_box frame=1, pos={xx-2,yy+25}, size={235,30}
	for(j=0;j<ItemsInList(axes);j+=1)
		string axis=StringFromList(j,axes)
		TitleBox $("Electrode_Title_"+axis),title=axis,pos={xx+12,yy}
		ValDisplay $("Electrode_NowRel_"+axis),pos={xx,yy+30}, size={55,15},value= _NUM:12500
		SetVariable $("Electrode_Now_"+axis),pos={xx,yy+55}, size={55,15},value= _NUM:12500, proc=logging_panel_setvariables
		xx += 55
	endfor
	Titlebox Electrode_NowRel_Title, pos={xx+5,yy+28}, size={100,15}, title="Relative"
	SetVariable $("Electrode_Now_Name"), pos={xx+5,yy+56}, size={55,15}, value= _STR:""
	//Button Electrode_Now_Save, proc=logging_panel_buttons, title="Save"
	
	xx = 10
	yy += 80
	
	variable max_names = 3
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
			string ctrl_name = "Electrode_"+num2str(i)+"_"+axis
			SetVariable $ctrl_name, pos={xx,yy}, size={40,15}, limits={0,25000,500}, title=" "
			SetVariable $ctrl_name, value=coords[i][j], disable=disable, proc=logging_panel_setvariables
			xx+=60
		endfor
		Checkbox $("Electrode_"+num2str(i)+"_relative"), pos={xx-15,yy+3}, proc=logging_panel_checkboxes,value=0, title=" ",pos={xx-15,yy+2}, disable=disable, proc=main_panel_checkboxes
		Titlebox $("Electrode_"+num2str(i)+"_name"), pos={xx,yy}, bodywidth=50, title=name, disable=disable
		ControlInfo Electrode_Now_Name
		Button $("Electrode_"+num2str(i)+"_delete"), pos={v_left+10,yy+2}, size={15,15}, proc=logging_panel_buttons, title="✘", disable=disable
		yy += 23//*(!disable)
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
		case "Pharma_Update":
			// Only one detail: "Update"
			logging_panel_set_drug()
			break
		case "Electrode":
			logging_panel_set_coords(detail)
			break
	endswitch
	FirstBlankLine(logging_win_name+"#ExperimentLog")
End



// Handle timed log entries
function logging_panel_set_log_entry()
	ControlInfo /W=$logging_win_name Log_Entry
	String text=S_Value
	log_text(text)
end


// Handle changes to drugs
function logging_panel_set_drug()
   // Not implemented yet.
   string text = ""
   variable i=1,j
	do
		ControlInfo $("Pharma_"+num2str(i))
		if(v_flag && v_value)
			ControlInfo $("Pharma_Conc_"+num2str(i)); variable conc=v_value
			ControlInfo $("Pharma_Units_"+num2str(i)); string units=s_value
			ControlInfo $("Pharma_Name_"+num2str(i)); string name=s_value
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
		ControlInfo /W=$logging_win_name Log_Timestamp
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
		ControlInfo /W=$logging_win_name Log_Timestamp
		timestamp = v_value
	endif
	text = add_timestamp(text, timestamp=timestamp)
	FirstBlankLine(logging_win_name+"#ExperimentLog")
	Notebook $(logging_win_name)#ExperimentLog text=text+"\r"
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
					controlinfo Electrode_Now_Name
					names[num_saved] = S_value
					redimension /n=(num_saved+1,3) coords
					controlinfo Electrode_Now_Name
					variable i
					string axes = "X;Y;Z"
					for(i=0;i<3;i+=1)
						string axis = stringfromlist(i,axes)
						controlinfo $("Electrode_Now_"+axis)
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
				//print info
				logging_panel_set_log_entry()
			endif
			break
		case "Animal":
			strswitch(detail)
				case "Weight":
					logging_panel_set_weight()
					break
				case "DOB":
					logging_panel_set_dob()
					break
			endswitch
			break
		case "Pharma":
			break
		case "Electrode":
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
		ControlInfo $("Electrode_"+num2str(i)+"_relative")
		if(v_value)
			duplicate /free/r=[i,i][0,2] coords subtract
			redimension /n=3 subtract
		endif
	endfor
	variable xx=v_left
	variable yy=v_top
	for(i=0; i<3; i+=1)
		string axis = stringfromlist(i,"X;Y;Z")
		ControlInfo $("Electrode_Now_"+axis)
		ValDisplay $("Electrode_NowRel_"+axis),value= _NUM:(v_value - subtract[i])
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
		case "Pharma":
			// Not implemented yet
			break
	endswitch
	FirstBlankLine(logging_win_name+"#ExperimentLog")
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
		case "Electrode":
			logging_panel_update_coords()
			break
	endswitch
End


