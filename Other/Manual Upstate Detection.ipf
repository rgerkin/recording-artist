// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Manual%20Upstate%20Detection.ipf $
// $Author: rick $
// $Rev: 509 $
// $Date: 2011-02-18 00:20:26 -0500 (Fri, 18 Feb 2011) $

#pragma rtGlobals=1		// Use modern global access method.

Menu "Analysis"
	"Manual Upstate Detection", UpstateManualDetection()
End

Function UpstateManualDetection([sourceFolder])
	String sourceFolder
	
	sourceFolder=SelectString(ParamIsDefault(sourceFolder),sourceFolder,"root:")
	NewDataFolder /O/S root:ManualUpstateDetection
	Make /o/n=0 Ups,Downs
	Variable /G upstateNum=0
	sourceFolder=RemoveEnding(sourceFolder,":")+":"
	SetDataFolder $sourceFolder
	
	//Make /o/n=100000 Test=gnoise(1); SetScale x,0,100,Test
	//Wave Data=Test
	//Display /K=1 /N=UpstateViewer /W=(100,100,800,500) Data
	DoWindow /K UpstateViewer
	String wave_list=ListFolders(sourceFolder)
	String first=StringFromList(0,wave_list)
	Wave /Z FirstWave=$(sourceFolder+first+":"+first)
	if(!WaveExists(FirstWave))
		DoAlert 0,"No wave '"+first+"' in the folder '"+first+"' in the folder '"+sourceFolder+"' to display"
		return -1
	endif
	Display /N=UpstateViewer FirstWave
	MoveWindow /W=UpstateViewer 100,100,800,500
	
	SetWindow UpstateViewer hook=UpstateClickHook,hookEvents=1,userData(sourceFolder)=sourceFolder
	ControlBar /T 25
	Button UpDown, title="Up", proc=UpstateManualDetectionButtons,userData="Up"
	SetVariable UpstateNum, limits={0,Inf,1}, value=root:ManualUpstateDetection:upstateNum, proc=UpstateManualDetectionSetVars,size={75,20},title="Num",userData=num2str(0)
	Checkbox Live, value=1, title="Live", proc=UpstateManualDetectionChecks
	Button KillState, proc=UpstateManualDetectionButtons, size={75,20}, title="Kill State"
	Button LogStates, proc=UpstateManualDetectionButtons, size={75,20}, title="Log States"
	SetVariable WaveSelectUpDown, proc=UpstateManualDetectionSetVars, value=_NUM:0, title=" "
	PopupMenu WaveSelect, proc=UpstateManualDetectionPopups, value=#("ListFolders(\""+sourceFolder+"\")")
	
	NewPanel /K=1 /W=(0,0,200,300) /HOST=UpstateViewer /N=UpstateViewerPanel /EXT=0 /FLT
	Edit /HOST=UpstateViewerPanel /W=(0,0,1,1) /N=UpstateRecords Ups,Downs 
	ModifyTable /W=UpstateViewer#UpstateViewerPanel#UpstateRecords size=10, width=45
End

Function UpstateManualDetectionChecks(ctrlName,val)
	String ctrlName
	Variable val
	strswitch(ctrlName)
		case "Live":
			SetWindow UpstateViewer hookEvents=val
			if(val)
				CtrlNamedBackground CheckKeyboard period=5, proc=UMD_CheckKeyboard, start
			else
				CtrlNamedBackground CheckKeyboard stop
			endif
			break
	endswitch
End

Function UMD_CheckKeyboard(info)
	Struct WMBackgroundStruct &info

#if exists("KeyboardState")	
	if(!StringMatch(WinName(0,1),"UpstateViewer"))
		return 0
	endif

	String state=KeyboardState("")
	Variable lastKeyT=str2num(GetUserData("UpstateViewer","","lastKeyT"))
	if(!(ticks-lastKeyT<5) && (str2num(state[5]) || str2num(state[6])))
		String infoStr
		Variable /C mousePos=mouseposition("coords=local")
		//sprintf infoStr,"EVENT:MOUSEDOWN;MOUSEX:%d;MOUSEY:%d",real(mousePos),imag(mousePos)
		//UpstateClickHook(infoStr)
		//sprintf infoStr,"EVENT:MOUSEUP;MOUSEX:%d;MOUSEY:%d",real(mousePos),imag(mousePos)
		//UpstateClickHook(infoStr)
		Variable mouseX=real(mousePos)
		Variable mouseY=imag(mousePos)
		if(mouseY<0) // In the control bar
			return 0
		endif
		String trace=StringFromList(0,TraceNameList("",";",1))
		String trace_info=TraceInfo("",trace,0)
		String offsetStr=StringByKey("offset(x)",trace_info,"=")
		Variable xOffset,yOffset
		sscanf offsetStr,"{%f,%f}",xOffset,yOffset
		Variable xVal=AxisValFromPixel("","bottom",mouseX)-xOffset
		Wave Ups=root:ManualUpstateDetection:Ups
		Wave Downs=root:ManualUpstateDetection:Downs
		Variable nearestUpNum=xval>wavemax(Ups) ? numpnts(Ups)-1 : (xval<wavemin(Ups) ? 0 : round(BinarySearchInterp(Ups,xVal)))
		Variable nearestDownNum=xval>wavemax(Downs) ? numpnts(Downs)-1 : (xval<wavemin(Downs) ? 0 : round(BinarySearchInterp(Downs,xVal)))
		Variable nearestUp=Ups[nearestUpNum]
		Variable nearestDown=Downs[nearestDownNum]
		GetAxis /Q bottom
		Variable axisRange=V_max-V_min
		Variable step=axisRange/250
		if(abs(nearestUp-xVal)<abs(nearestDown-xval))
			String upDown="Up"
			Variable upstateNum=nearestUpNum
			xval=nearestUp-str2num(state[5])*step+str2num(state[6])*step
		else
			upDown="Down"
			upstateNum=nearestDownNum
			xval=nearestDown-str2num(state[5])*step+str2num(state[6])*step
		endif
		MarkState(upDown,xVal,upstateNum)
		SetWindow UpstateViewer userData(lastkeyT)=num2str(ticks)
	endif
	return 0
#endif
End

Function UpstateManualDetectionButtons(ctrlName)
	String ctrlName
	
	Wave Ups=root:ManualUpstateDetection:Ups
	Wave Downs=root:ManualUpstateDetection:Downs
	
	strswitch(ctrlName)
		case "UpDown":
			String str=GetUserData("","UpDown","")
			str=SelectString(StringMatch(str,"Up"),"Up","Down")
			Button UpDown, title=str,userData=str
			ControlInfo UpstateNum; Variable upstateNum=V_Value
			String currTagName=str+"_"+num2str(upstateNum)
			String tags=AnnotationList("")
			Variable i
			for(i=0;i<ItemsInList(tags);i+=1)
				String tagName=StringFromList(i,tags)
				if(StringMatch(tagName,currTagName))
					Tag/C/N=$tagName/F=2 
				else
					Tag/C/N=$tagName/F=0 
				endif
			endfor
			break
		case "KillState":
			ControlInfo UpstateNum; upstateNum=V_Value
			DeletePoints upstateNum,1,Ups,Downs
			tagName="Up_"+num2str(upstateNum)
			Tag /K/N=$tagName
			tagName="Down_"+num2str(upstateNum)
			Tag /K/N=$tagName
			i=upStateNum+1
			Do
				if(i>numpnts(Ups))
					break
				endif
				tagName="Up_"+num2str(i)
				String newTagName="Up_"+num2str(i-1)
				Tag /C/R=$newTagName /N=$tagName "\Z09"+newTagName
				tagName="Down_"+num2str(i)
				newTagName="Down_"+num2str(i-1)
				Tag /C/R=$newTagName /N=$tagName "\Z09"+newTagName
				i+=1
			While(1)
			Button UpDown, title="Up",userData="Up"
			SetWindow kwTopWin userData(edited)="1"
			break
		case "LogStates":
			String trace=StringFromList(0,TraceNameList("",";",1))
			Wave theWave=TraceNameToWaveRef("",trace)
			Variable j
			
			Note /K/NOCR theWave,""
			Sort Ups,Ups,Downs
			for(i=0;i<numpnts(Ups);i+=1)
				String states
				sprintf states,"%.3f,%.3f;",Ups[i],Downs[i]
				Note /NOCR theWave, states
			endfor
			SetWindow kwTopWin userData(edited)="0"
			break
	endswitch
End

Function UpstateManualDetectionSetVars(info)
	Struct WMSetVariableAction &info
	if(info.eventCode!=1)
		return -1
	endif
	strswitch(info.ctrlName)
		case "UpstateNum":
			Variable oldVal=str2num(GetUserData("","UpstateNum",""))
			Variable newVal=info.dval
			if(oldVal==newVal)
				return -2
			endif
			String str=GetUserData("","UpDown","")
			if(newVal>oldVal)
				Button UpDown, title="Up",userData="Up"
				str="Up"
			elseif(newVal<oldVal)
				Button UpDown, title="Down",userData="Down"
				str="Down"
			endif
			SetVariable UpstateNum, userData=num2str(newVal)
			String currTagName=str+"_"+num2str(newVal)
			String tags=AnnotationList("")
			Variable i
			for(i=0;i<ItemsInList(tags);i+=1)
				String tagName=StringFromList(i,tags)
				if(StringMatch(tagName,currTagName))
					Tag/C/N=$tagName/F=2 
				else
					Tag/C/N=$tagName/F=0 
				endif
			endfor
			break
		case "WaveSelectUpDown":
			Variable edited=str2num(GetUserData(info.win,"","edited"))
			if(edited)
				DoAlert 1,"Continue without logging edited states?"
				if(V_flag!=1)
					return -2
				endif
			endif
			String sourceFolder=GetUserData(info.win,"","sourceFolder")
			String folders=ListFolders(sourceFolder)
			ControlInfo WaveSelectUpDown
			String folder=StringFromList(V_Value,folders)
			PopupMenu WaveSelect mode=V_Value+1
			Struct WMPopupAction info2
			info2.eventCode=1
			info2.popStr=folder
			UpstateManualDetectionPopups(info2)
			break
	endswitch
End

Function UpstateManualDetectionPopups(info)
	Struct WMPopupAction &info
	if(info.eventCode<0)
		return -1
	endif
	String currTrace=StringFromList(0,TraceNameList("",";",1))
	//Wave currWave=TraceNameToWaveRef("UpstateViewer",currTrace)
	String sourceFolder=GetUserData(info.win,"","sourceFolder")
	Wave newWave=$(sourceFolder+info.popStr+":"+info.popStr)
	ReplaceWave /W=UpstateViewer trace=$currTrace,newWave
	String states=note(newWave)
	Wave Ups=root:ManualUpstateDetection:Ups
	Wave Downs=root:ManualUpstateDetection:Downs
	Redimension /n=0 Ups,Downs
	Variable i,j
	String tags=AnnotationList("UpstateViewer")
	for(i=0;i<ItemsInList(tags);i+=1)
		String tagg=StringFromList(i,tags)
		String taggInfo=AnnotationInfo("UpstateViewer",tagg)
		if(StringMatch(StringByKey("TYPE",taggInfo),"Tag")) // If it is in fact a tag and not some other kind of annotation.  
			Tag /K/N=$tagg /W=UpstateViewer
		endif
	endfor
	String newTrace=StringFromList(0,TraceNameList("",";",1))
	for(i=0;i<ItemsInList(states);i+=1)
		String state=StringFromList(i,states)
		for(j=0;j<2;j+=1)
			String upDown=StringFromList(j,"Up;Down")
			Variable xVal=str2num(StringFromList(j,state,","))
			MarkState(upDown,xVal,i)
		endfor
	endfor
	NVar stateNum=root:ManualUpstateDetection:upstateNum
	stateNum=0
	Button UpDown, title="Up",userData="Up"
	SetWindow kwTopWin userData(edited)="0"
End

Function UpstateClickHook(info_str)
	String info_str
	ControlInfo Live
	if(!V_Value)
		return 0
	endif
	String event=StringByKey("EVENT",info_str)
	if(StringMatch(event,"mousedown"))
		Variable /G root:ManualUpstateDetection:mouseDownX=str2num(StringByKey("MOUSEX",info_str))
		Variable /G root:ManualUpstateDetection:mouseDownY=str2num(StringByKey("MOUSEY",info_str))
	endif
	if(StringMatch(event,"mouseup"))
		Variable mouseX=str2num(StringByKey("MOUSEX",info_str))
		Variable mouseY=str2num(StringByKey("MOUSEY",info_str))
		if(mouseY<0) // In the control bar
			return -1
		endif
		NVar mouseDownX=root:ManualUpstateDetection:mouseDownX
		NVar mouseDownY=root:ManualUpstateDetection:mouseDownX
		if(mouseX!=mouseDownX && mouseY!=mouseDownY) // Mouse up and down coords do not match; assume user is trying to draw a marquee.  
			return -2
		endif
		String trace=StringFromList(0,TraceNameList("",";",1))
		String info=TraceInfo("",trace,0)
		String offsetStr=StringByKey("offset(x)",info,"=")
		Variable xOffset,yOffset
		sscanf offsetStr,"{%f,%f}",xOffset,yOffset
		Variable xVal=AxisValFromPixel("","bottom",mouseX)-xOffset
		Variable yVal=AxisValFromPixel("","left",mouseY)
		NVar upstateNum=root:ManualUpstateDetection:upstateNum
		ControlInfo UpDown; String UpDown=S_userData
		MarkState(upDown,xVal,upstateNum)
		upstateNum+=StringMatch(UpDown,"Down")
		UpstateManualDetectionButtons("UpDown")
	endif
End

Function MarkState(upDown,xVal,stateNum[,trace])
	String upDown,trace
	Variable xVal,stateNum
	
	if(ParamIsDefault(trace))
		trace=StringFromList(0,TraceNameList("",";",1))
	endif
	Wave Starts=root:ManualUpstateDetection:$(upDown+"s")
	Starts[stateNum]={xVal}
	Variable tagY=-25+50*StringMatch(upDown,"Down")
	String tagStr=upDown+"_"+num2str(stateNum)
	Tag /C/N=$(tagStr) /F=0 /X=0 /Y=(tagY) $trace,xVal,"\Z09"+tagStr
	SetWindow kwTopWin userData(edited)="1"
End

Function KillAllWaveNotes()
	String wave_list=WaveList("*",";","MINROWS:1000")
	Variable i
	for(i=0;i<ItemsInList(wave_list);i+=1)
		String wave_name=StringFromList(i,wave_list)
		Wave theWave=$wave_name
		Note /K theWave
	endfor
End