// $URL: svn://raptor.cnbc.cmu.edu/rick/recording-artist/Recording%20Artist/Acquisition/Logging.ipf $
// $Author: rick $
// $Rev: 632 $
// $Date: 2013-03-15 17:17:39 -0700 (Fri, 15 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.

Function /S AvailableDrugs()
	string instances=Core#ListPackageInstances("Acq","drugs",editor=1)
	variable i
	do	
		variable removed=0
		do
			string instance=stringfromlist(i,instances)
			if(grepstring(instance,"drug[0-9]+"))
				instances=removefromlist(instance,instances)
				removed+=1
			else
				i+=1
			endif
		while(i<itemsinlist(instances))
	while(removed)
	return instances
End

Function /S AvailableDrugPresets()
	string instances=Core#ListPackageInstances("Acq","drugPresets",editor=1)
	return "Washout;"+instances
End

Function DrugWinPopupMenus(info) : PopupMenuControl
	struct WMPopupAction &info
	
	if(info.eventCode>0)
		string name=stringfromlist(0,info.ctrlName,"_")
		variable num=str2num(stringfromlist(1,info.ctrlName,"_"))
		strswitch(name)
			case "DrugName":
				strswitch(info.popStr)
					case "_edit_":
						PopupMenu $("DrugName_"+num2str(num)) mode=1
						Core#EditModule("Acq",package="Drugs")
						break
					default:
						Core#SetStrPackageSetting("Acq","drugs","drug"+num2str(num),name,info.popStr)
						break
				endswitch
				break
			case "DrugPresets":
				variable i=1
				if(StringMatch(info.popStr,"Washout"))
					do
						controlinfo $("Drug_"+num2str(i))
						if(v_flag<=0)
							break
						endif
						Core#SetVarPackageSetting("Acq","drugs","drug"+num2str(i),"active",0)
						i+=1
					while(1)
	//			elseif(StringMatch(popStr,"Save*"))
	//				Variable index=str2num(popStr[strlen(popStr)-1])
	//				SVar drugPresets=root:parameters:drugPresets
	//				String presetStr=""
	//				for(i=1;i<=numDrugSlots;i+=1)
	//					ControlInfo $("Drug_"+num2str(i))
	//					if(V_Value)
	//						ControlInfo $("DrugName_"+num2str(i))
	//						String drugName=S_Value
	//						NVar conc=root:status:drugs:$("drugConcDisplay_"+num2str(i))
	//						//conc=str2num(StringFromList(1+3*(i-1),popStr,","))
	//						ControlInfo $("DrugUnits_"+num2str(i))
	//						String units=S_Value
	//						presetStr+=drugName+","+num2str(conc)+","+units+","
	//					endif
	//				endfor
	//				presetStr=RemoveEnding(presetStr,",")
	//				drugPresets=ReplaceListItem(presetStr,drugPresets,index)
				else
					wave /t drugPreset=Core#WavTPackageSetting("Acq","drugPresets",info.popStr,"drugs")
					do
						controlinfo $("Drug_"+num2str(i))
						if(v_flag<=0)
							break
						endif
						string drug=drugPreset[i-1]
						if(i<=dimsize(drugPreset,0) && strlen(drug))
							Core#CopyInstance("Acq","drugs",drug,"drug"+num2str(i))
						else
							Core#SetVarPackageSetting("Acq","drugs","drug"+num2str(i),"active",0)
						endif
						i+=1
					while(1)
				endif
				break
		endswitch
	endif
End

Function DrugWinButtons(ctrlName) : ButtonControl
	String ctrlName
	
	strswitch(ctrlName)
		case "UpdateDrugs":
			wave /t/sdfr=GetDrugsDF() info
			dfref statusDF=GetStatusDF()
			nvar /sdfr=statusDF expStartT,currSweep
			Variable time_since_start=(currSweep>0) ? datetime - expStartT : 0
			redimension /n=(numpnts(info)+1) info
			variable last=numpnts(info)-1
			info[last]=""
			string log_text_a,log_text_b="",tag_text=""
			if(currSweep==0)
				log_text_a="@ "+Secs2Time(DateTime,3)+" ("+Secs2MinsAndSecs(time_since_start)+")"
			else
				log_text_a="@ "+Secs2Time(DateTime,3)+" after sweep "+num2str(currSweep)+" ("+Secs2MinsAndSecs(time_since_start)+")"
			endif
			variable i=1
			do
				ControlInfo $("Drug_"+num2str(i))
				if(v_flag<=0)
					break
				endif
				dfref df=Core#InstanceHome("Acq","drugs","drug"+num2str(i))
				nvar /sdfr=df active,conc
				svar /sdfr=df units,name
				if(!strlen(name))
					name="Drug"+num2str(i)
				endif
				if(active) // If that drug box is active
					string str
					sprintf str,"%.3f,%s,%.3f,%s;",time_since_start/60,name,conc,units
					info[last]+=str
					sprintf str,"Drug: %g %s %s;",conc,units,name
					log_text_b+=str
					sprintf str,"%.3f %s\r%s\r\r",conc,units,name
					tag_text+=str
				endif
				i+=1
			while(1)
			if(strlen(log_text_b)==0) // If none of the boxes are checked.  
				log_text_b="All drugs washed out. "
				tag_text="All drugs\rwashed out\r\r"
				info[last]=num2str(time_since_start/60)+",Washout,,;"
			endif
			tag_text+="Sweep "+num2str(currSweep)
			String log_text=log_text_b+log_text_a+"\r"
			Notebook LogPanel#ExperimentLog text=log_text
			FirstBlankLine("LogPanel#ExperimentLog")
			if(strlen(AxisInfo("AnalysisWin","time_axis")))
				Tag /W=AnalysisWin /F=0/B=1/X=0/Y=25 time_axis,time_since_start/60,"\Z12"+tag_text
			endif
			variable /G statusDF:lastUpdate=currSweep
			break
	endswitch
End

//Function EditDrugs()
//	DoWindow /K DrugEditor
//	SVar drugList=root:parameters:drugList
//	NewPanel /K=1 /N=DrugEditor /W=(100,100,400,120+ItemsInList(drugList)*35) as "Drug Editor"
//	SVar drugList=root:parameters:drugList
//	Variable i
//	for(i=0;i<ItemsInList(drugList);i+=1)
//		String drug=StringFromList(i,drugList)
//		SetVariable $("DrugName_"+num2str(i)),pos={2,25*i}, size={125,20}, disable=2, value=_STR:drug
//		Button $("Delete_"+num2str(i)), title="Delete",proc=EditDrugsButtons
//	endfor
//	SetVariable NewDrugName,pos={2,25*i}, size={125,20}, value=_STR:""
//	Button $("Add_"+num2str(i)), title="Add",proc=EditDrugsButtons
//End

//Function EditDrugsButtons(ctrlName)
//	String ctrlName
//	
//	String name=StringFromList(0,ctrlName,"_")
//	Variable num=str2num(StringFromList(1,ctrlName,"_"))
//	SVar drugList=root:parameters:drugList
//	strswitch(name)
//		case "Save":
//			drugList=""
//			String drugNameSetVarList=ControlNameList("",";","DrugName*")
//			Variable i
//			for(i=0;i<ItemsInList(drugNameSetVarList);i+=1)
//				String drugNameSetVar=StringFromList(i,drugNameSetVarList)
//				ControlInfo $drugNameSetVar
//				String drugName=S_Value
//				drugList+=drugName+";"
//			endfor
//			break
//		case "Add":
//			ControlInfo NewDrugName
//			drugList=S_Value+";"+drugList
//			break
//		case "Delete":
//			ControlInfo $("DrugName_"+num2str(num))
//			drugList=RemoveFromList(S_Value,drugList)
//			break
//	endswitch	
//	EditDrugs()
//End

// ---- Logging from a panel ----

// For people who like a simple notebook instead of the log panel.  
#ifdef SimpleLogPanel
override function MakeLogPanel()
	if(WinType("LogPanel"))
		DoWindow /F LogPanel
		return 0
	else
		NewNotebook /F=1/N=LogPanel
	endif
end
#endif

Function MakeLogPanel() : Panel
	if(WinType("LogPanel"))
		DoWindow /F LogPanel
		return 0
	endif
#if exists("Sutter#Init")
	Sutter#Init()
#else
	//printf "The Sutter procedure file is not loaded.\r"
#endif
	NewPanel /K=2 /W=(150,100,950,323+ItemsInList(odors)*20) /N=LogPanel as "Experiment Logger"
	NewNotebook /f=1 /K=2 /n=ExperimentLog /HOST=LogPanel /W=(440,5,785,215+ItemsInList(odors)*20)
	Notebook LogPanel#ExperimentLog text = "", margins={0,0,300}
	string logDefault=Core#StrPackageSetting("Acq","random","","logDefault")
	Notebook LogPanel#ExperimentLog text = logDefault
	SetActiveSubwindow LogPanel
	
	Variable xx,yy,xStart=3,yStart=2
	xx=xStart; yy=yStart
	
	SetVariable LogEntry,pos={xx,yy+2},size={300,16},title="Log:",value= _STR:"",proc=LogPanelSetVariables
	Button LogEntrySubmit,pos={xx+304,yy},size={50,20},proc=LogPanelButtons,title="Submit"
	Checkbox LogEntryTimestamp,value=1,pos={xx+360,yy+3}, title="T-stamp"
	
	yy+=25
	GroupBox DOB frame=1, pos={xx,yy}, size={350,28}
	xx+=5; yy+=6
	String dait=ReplaceString("/",Secs2Date(DateTime,0),";")	
	SetVariable DOB_Month,pos={xx,yy},size={65,16},proc=LogPanelSetVariables, title="DOB:"
	SetVariable DOB_Month,limits={1,12,1},value=_NUM:str2num(StringFromList(0,dait))
	SetVariable DOB_Day,pos={xx+72,yy},size={40,16},proc=LogPanelSetVariables
	SetVariable DOB_Day,limits={1,31,1},value=_NUM:str2num(StringFromList(1,dait))
	SetVariable DOB_Year,pos={xx+120,yy},size={50,16},proc=LogPanelSetVariables
	SetVariable DOB_Year,value=_NUM:str2num(StringFromList(2,dait))
	
	xx+=210
	SetVariable Weight,pos={xx,yy},size={103,16},bodyWidth=50,proc=LogPanelSetVariables,title="Weight (g)"
	SetVariable Weight,value= _NUM:0
	
	xx=xStart
	yy+=28
	GroupBox Drugs frame=1, pos={xx,yy}, size={363,35+4*25}
	yy+=7
	//PopupMenu Drug,value=anaesthetics, pos={xx+3,yy+1}, size={120,20}, proc=LogPanelPopupMenus
	Variable i,j
	
	for(i=1;i<=4;i+=1)
		string name="drug"+num2str(i)
		Core#CopyDefaultInstance("Acq","drugs",name)
		dfref df=Core#InstanceHome("Acq","drugs",name)
		nvar /z/sdfr=df active,conc
		svar /z/sdfr=df units
		xx=xStart+5
		Checkbox $("Drug_"+num2str(i)), pos={xx,yy}, variable=active, title="Drug "+num2str(i)
		xx+=70
		SetVariable $("DrugConc_"+num2str(i)),pos={xx,yy-2},size={50,18},limits={0,1000,1},variable=conc, title=" "
		xx+=70
		PopupMenu $("DrugUnits_"+num2str(i)),pos={xx,yy-2},size={21,18},mode=1,value=#"PopupMenuOptions(\"Acq\",\"drugs\",\"\",\"units\")"
		xx+=70
		PopupMenu $("DrugName_"+num2str(i)),pos={xx,yy-2},size={21,18},mode=1,value=#"AvailableDrugs()",proc=DrugWinPopupMenus
		yy+=25
	endfor
	
	xx=xStart+5
	PopupMenu DrugPresets,pos={xx,yy},size={328,30},mode=0,value=#"AvailableDrugPresets()",proc=DrugWinPopupMenus,title="Presets"
	xx+=120
	Button UpdateDrugs,pos={xx,yy+1},size={100,20},title="Update",proc=DrugWinButtons

#ifdef Rick	
	Variable odor_channels=5
	xx=285
	yy=60
	GroupBox Odors frame=1, pos={xx,yy}, size={150,25*odor_channels+7}
	xx+=5; yy+=4
	Variable i0=1
	for(i=i0;i<i0+odor_channels;i+=1)
		PopupMenu $("OdorChannel"+num2str(i)) value=odors, mode=(i-i0+1), pos={xx,yy}, title="Odor "+num2str(i), proc=LogPanelPopupMenus
		Notebook LogPanel#ExperimentLog findtext={"Odor Channel "+num2str(i),8}
		if(!V_flag)
			Notebook LogPanel#ExperimentLog text="Odor Channel "+num2str(i)+": "+StringFromList(i,odors)+"\r"
		endif
		yy+=25
	endfor
#endif

	xx=xStart
	yy=200
	GroupBox Coordinates frame=1, pos={xx,yy}, size={423,100}
	yy+=30
	for(i=0;i<ItemsInList(sutterLocations);i+=1)
		String location=StringFromList(i,sutterLocations)
		xx=75
		for(j=0;j<ItemsInList(sutterAxes);j+=1)
			String axis=StringFromList(j,sutterAxes)
			if(i==0)
				TitleBox $("Title_"+axis),title=axis,pos={xx+15,yy-25}
			endif
			SetVariable $(location+"_"+axis),pos={xx,yy},bodywidth=50,title=SelectString(j==0,"",location)
			SetVariable $(location+"_"+axis),limits={0,25000,500},value= _NUM:12500
			xx+=75
		endfor
		xx-=18
		Button $("Set_"+location),pos={xx,yy-2},size={60,20},proc=LogPanelButtons,title=location
		if(exists("Sutter#Init"))
			xx+=65
			Button $("Sutter_"+location),proc=LogPanelButtons,title="S",size={20,20},pos={xx,yy-2}
			xx+=25
			if(i==0)
				TitleBox Title_Live,title="Live",pos={xx-3,yy-25}
			endif
			Checkbox $("Live_"+location),proc=LogPanelCheckboxes,value=0, title=" ",pos={xx,yy+2}
			xx-=45
		endif
		xx+=65
		if(i==0)
			TitleBox Title_Relative,title="Rel",pos={xx-3,yy-25}
		endif
		Checkbox $("Relative_"+location),proc=LogPanelCheckboxes,value=0, title=" ",pos={xx,yy+2}
		yy+=24
	endfor
	xx=xStart-3
	if(exists("Sutter#Init"))	
		Checkbox Diag, pos={xx+8,yy+1}, proc=LogPanelCheckboxes, title="Diag",value=1
		for(j=0;j<ItemsInList(sutterAxes);j+=1)
			axis=StringFromList(j,sutterAxes)
			xx+=75
			SetVariable $("d"+axis),pos={xx,yy},bodywidth=50,title="d"+axis,disable=1
			SetVariable $("d"+axis),limits={0,25000,10},value= _NUM:0,disable=1
		endfor
		xx=xStart+95
		SetVariable Angle,pos={xx,yy},bodywidth=50,title="Angle"
		SetVariable Angle,limits={0,90,1},value= _NUM:26.565,disable=0,proc=LogPanelSetVariables
		xx+=100
		SetVariable dDiag,pos={xx,yy},bodywidth=50,title="dDiag"
		SetVariable dDiag,limits={0,25000,10},value= _NUM:0,disable=0,proc=LogPanelSetVariables
		xx+=112
		SetVariable Sutter_Speed,value=_NUM:1,limits={0,25,0.5}, title="Speed",pos={xx,yy}, bodywidth=50
		xx+=60
		Button Sutter_Move proc=LogPanelButtons,title="Go",pos={xx,yy-2},userData="Go"
	endif
	
	Notebook LogPanel#ExperimentLog selection={endOfFile,endOfFile}
End

strconstant odors=";Mix A;Mix B;Mix E;Mix F;Isoamyl Acetate (10%)"
strconstant anaesthetics="Ketamine/Xylazine;Sevoflurane;Ketamine;Urethane/Xylazine;Urethane/Xylazine/Ace;Xylazine;Urethane;Phenobarbital"
strconstant anaestheticConcs="0;1;20;10;10;1;20;0"
strconstant anaestheticUnits="mg/ml;%;mg/ml;%;mg/ml;%;mg/ml"
strconstant sutterLocations="Midline;Penetrate;Record"
strconstant sutterAxes="X;Y;Z"

Function LogPanelButtons(ctrlName) : ButtonControl
	String ctrlName
	
	String sutter_loc="root:Packages:Sutter:"
	NVar /Z x1=$(sutter_loc+"x1")
	NVar /Z y1=$(sutter_loc+"y1")
	NVar /Z z1=$(sutter_loc+"z1")
	String action=StringFromList(0,ctrlName,"_")
	String detail=StringFromList(1,ctrlName,"_")
	strswitch(action)
		case "LogEntrySubmit":
			ControlInfo /W=LogPanel LogEntry
			String text=S_Value
			ControlInfo /W=LogPanel LogEntryTimestamp
			if(V_Value)
				text+=" @ "+Secs2Time(DateTime,3)
			endif
			FirstBlankLine("LogPanel#ExperimentLog")
			Notebook LogPanel#ExperimentLog text=text+"\r"
			break
		case "Drug":
			ControlInfo /W=LogPanel Anaesthetic; String anaesthetic=S_Value; String units=StringFromList(V_Value-1,anaestheticUnits)
			ControlInfo /W=LogPanel Concentration; Variable concentration=V_Value
			ControlInfo /W=LogPanel Dose; Variable dose=V_Value
			FirstBlankLine("LogPanel#ExperimentLog")
			Notebook LogPanel#ExperimentLog text="Drug: "+anaesthetic+" ("+num2str(concentration)+" "+units+") "
			if(!StringMatch(anaesthetic,"Sevoflurane"))
				Notebook LogPanel#ExperimentLog text=num2str(dose)+" "
				Notebook LogPanel#ExperimentLog font="Symbol", text="m"
				Notebook LogPanel#ExperimentLog font="default", text="L "
			endif
			Notebook LogPanel#ExperimentLog font="default", text="@ "+Secs2Time(DateTime,3)+"\r"
			break
		case "Set":
			ControlInfo /W=LogPanel $(detail+"_X"); Variable mx=V_Value
			ControlInfo /W=LogPanel $(detail+"_Y"); Variable my=V_Value
			ControlInfo /W=LogPanel $(detail+"_Z"); Variable mz=V_Value
			sprintf text,detail+": (%d,%d,%d) @ %s",mx,my,mz,Secs2Time(DateTime,3)
			FirstBlankLine("LogPanel#ExperimentLog")
			Notebook LogPanel#ExperimentLog text=text+"\r"
			break
		case "Sutter":
			if(StringMatch(detail,"move"))
#if exists("Sutter#SlowMove")==6
				ControlInfo /W=LogPanel Sutter_Move
				if(StringMatch(S_userData,"Go"))
					ControlInfo /W=LogPanel dX; Variable dx=V_Value
					ControlInfo /W=LogPanel dY; Variable dy=V_Value
					ControlInfo /W=LogPanel dZ; Variable dz=V_Value
					ControlInfo /W=LogPanel Sutter_Speed; Variable speed=V_Value
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
				UpdateLogPanelCoords(detail)
			endif
			break
		case "Vitals":
#if exists("VitalPanel")
			VitalPanel()
#endif
			break
	endswitch
	FirstBlankLine("LogPanel#ExperimentLog")
End

Function UpdateLogPanelCoords(location)
	String location
	Variable i
	String sutter_loc="root:Packages:Sutter:"
	ControlInfo /W=LogPanel $("Relative_"+location)
	if(V_Value)
		Variable relative=1
	endif
	for(i=0;i<ItemsInList(sutterAxes);i+=1)
		String axis=StringFromList(i,sutterAxes)
		NVar axis_coord=$(sutter_loc+axis+"1")
		if(relative==1)
			Variable j=WhichListItem(location,sutterLocations)
			ControlInfo /W=LogPanel $(StringFromList(j-1,sutterLocations)+"_"+axis)
			SetVariable $(location+"_"+axis) value=_NUM:(axis_coord-relative*V_Value), win=LogPanel
		else
			SetVariable $(location+"_"+axis) value=_NUM:axis_coord, win=LogPanel
		endif
	endfor
End

Function LogPanelSetVariables(info) : SetVariableControl
	STRUCT WMSetVariableAction &info
	if(info.eventCode<0)
		return 0
	endif
	strswitch(info.ctrlName)
		case "LogEntry":
			if(info.eventCode==2)
				ControlInfo /W=LogPanel LogEntry
				String text=S_Value
				if(strlen(text))
					FirstBlankLine("LogPanel#ExperimentLog")
					ControlInfo /W=LogPanel LogEntryTimestamp
					if(V_Value)
						text+=" @ "+Secs2Time(DateTime,3)
					endif
					Notebook LogPanel#ExperimentLog text=text+"\r"
				endif
			endif
			break
		case "Weight":
			ControlInfo /W=LogPanel Weight
			Variable weight=V_Value
			Notebook LogPanel#ExperimentLog findText={"Weight: ",9}
			if(V_flag)
				GetSelection notebook, LogPanel#ExperimentLog, 1
				Notebook LogPanel#ExperimentLog selection={(V_startparagraph,0),(V_startparagraph+1,0)}
			else
				FirstBlankLine("LogPanel#ExperimentLog")
			endif
			Notebook LogPanel#ExperimentLog text="Weight: "+num2str(weight)+" g\r"
			break
		case "DOB_Month":
		case "DOB_Day":
		case "DOB_Year":
			ControlInfo /W=LogPanel DOB_Month
			Variable month=V_Value
			ControlInfo /W=LogPanel DOB_Day
			Variable day=V_Value
			ControlInfo /W=LogPanel DOB_Year
			Variable year=V_Value
			Notebook LogPanel#ExperimentLog findText={"DOB: ",9}
			if(V_flag)
				GetSelection notebook, LogPanel#ExperimentLog, 1
				Notebook LogPanel#ExperimentLog selection={(V_startparagraph,0),(V_startparagraph+2,0)}
			else
				FirstBlankLine("LogPanel#ExperimentLog")
			endif
			Notebook LogPanel#ExperimentLog text="DOB: "+num2str(month)+"/"+num2str(day)+"/"+num2str(year)+"\r"
			Notebook LogPanel#ExperimentLog text="Age: P"+num2str(round((datetime-date2secs(year,month,day))/(60*60*24)))+"\r"
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
	FirstBlankLine("LogPanel#ExperimentLog")
End

Function LogPanelPopupMenus(info) : PopupMenuControl
	STRUCT WMPopupAction &info
	if(!SVInput(info.eventCode))
		return 0
	endif
	if(StringMatch(info.ctrlName,"Odor*"))
		ControlInfo /W=LogPanel $(info.ctrlName)
		String channel=info.ctrlName
		channel=channel[strlen(channel)-1]
		FirstBlankLine("LogPanel#ExperimentLog")
		Notebook LogPanel#ExperimentLog text="Odor Channel "+channel+": "+S_Value+" @ "+Secs2Time(DateTime,3)+"\r"
	endif
	strswitch(info.ctrlName)
		case "Anaesthetic":
			ControlInfo Anaesthetic
			SetVariable Concentration,value=_NUM:str2num(StringFromList(V_Value-1,anaestheticConcs)), title=StringFromList(V_Value-1,anaestheticUnits)
			//Titlebox Anaesthetic_Units, title=StringFromList(V_Value-1,anaesthetic_units)
			break
	endswitch
	FirstBlankLine("LogPanel#ExperimentLog")
End

Function LogPanelCheckboxes(info) : CheckboxControl
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

// --------------------

