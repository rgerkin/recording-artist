// $Author: rick $
// $Rev: 633 $
// $Date: 2013-03-28 15:53:22 -0700 (Thu, 28 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.

#include ":Logging"
static strconstant module="Acq"

constant waveSelectorBaseWidth=1052

Function WaveSelector([coords2,DAQ,instance])
	STRUCT rect &coords2
	String DAQ
	string instance

	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())
	String win=DAQ+"_Selector"
	instance=selectstring(!paramisdefault(instance) && strlen(instance),Core#DefaultInstance(module,"DAQs"),instance)
	
	String currFolder=GetDataFolder(1)
	if(ParamIsDefault(coords2))
		STRUCT rect coords
		dfref df = Core#InstanceHome(module,"DAQs",instance,sub="position")
		nvar /z/sdfr=df left,top,right,bottom
		if(NVar_Exists(left) && (left+top)>0)
			coords.left=left
			coords.top=top
			//coords.right=right
			//coords.bottom=bottom
		elseif(StringMatch(DAQ,MasterDAQ()))
			coords.left=200
			coords.top=105
		else
			Core#GetWinCoords(MasterDAQ()+"_Selector",coords)
			coords.left=coords.left ? coords.left : 200
			coords.top=coords.bottom ? coords.bottom+35 : 505
		endif
	else
		coords=coords2
	endif
	variable acquiring=IsAcquiring(DAQ=DAQ)
	
	Variable i
	variable numChannels=GetNumChannels()
	nvar numDAQChannels=$Core#PackageSettingLoc(module,"DAQs",DAQ,"numChannels")
	wave divisor=GetDAQDivisor(DAQ)
	if(numpnts(divisor))
		WaveStats /Q divisor
	endif
	Variable remainderSpace=V_max>1 ? V_max : 0
	ControlInfo /W=$win $("Remainder_0_0_0")
	Variable checkboxWidth=21//V_width
	coords.right=coords.left+waveSelectorBaseWidth+60*(remainderSpace>0)+(remainderSpace>3)*(remainderSpace-3)*checkboxWidth
	Variable y_height=28, y_offset=50,xpos=0
	Variable height=35+y_offset+y_height*numDAQChannels
	
	DoWindow /K $win
	string titleStr=instance+" Selector ("+Core#VarNameToTitle(DAQ)+")"
	titleStr=replacestring("Daq",titleStr,"DAQ")
	NewPanel /K=2 /N=$win /W=(coords.left,coords.top,coords.right,coords.top+35+y_offset+y_height*numDAQChannels) as titleStr
	SetWindow kwTopWin userData(y_height)=num2str(y_height)
	SetWindow kwTopWin userData(y_offset)=num2str(y_offset)
	setwindow kwTopWin userData(instance)=instance
	SetWindow kwTopWin hook(main)=SelectorHook
	SetWindow kwTopWin userData(DAQ)=DAQ
	SetDrawLayer ProgBack; SetDrawEnv fillfgc= (39321,1,1); SetDrawLayer UserBack
	
	TabControl ParamSets tablabel(0)="Stimuli", size={115,20}, pos={120,5}, proc=WaveSelectorTabs
	TabControl ParamSets tablabel(1)="Filters"
	
	Button SuperClamp title="SuperClamp", size={100,20}, proc=WaveSelectorButtons

	// Pulse sets.  
	ControlInfo /W=$win PulseSets
	TabControl PulseSets value=(V_flag ? V_Value : 1)
	STRUCT WMTabControlAction info
	info.eventCode=2; info.tab=1; info.win=win
	PulseSetTab(info)
	Variable titleBoxSize=10

	variable DAQchan=0	
	for(i=0;i<numChannels;i+=1)
		if(!StringMatch(Chan2DAQ(i),DAQ))
			continue
		endif
		variable ypos=y_offset+y_height*DAQChan // The y position of the corresponding channel
		// Channel settings.  
		xpos=5
		xpos+=3
		string chanName=GetChanName(i)
		nvar active=$Core#PackageSettingLoc(module,"channelConfigs",chanName,"active")
		CheckBox $("AcquireOn_"+num2str(i)),pos={xpos,ypos+3},size={65,13},title=" ",proc=WaveSelectorCheckboxes,variable=active
		TitleBox Title_On, frame=0,fSize=titleBoxSize,title="On",pos={xpos,y_offset-18}, win=$win
		xpos+=18
		variable red,green,blue
		GetChanColor(i,red,green,blue)
		PopupMenu $("Color_"+num2str(i)), pos={xpos,ypos},mode=0,size={10,10},value="*COLORPOP*",popColor=(red,green,blue),proc=WaveSelectorPopupMenus
		xpos+=55
		SetVariable $("Label_"+num2str(i)),pos={xpos,ypos+2},size={90,18},title=" "
		svar label_=$Core#PackageSettingLoc(module,"channelConfigs",chanName,"label_")
		SetVariable $("Label_"+num2str(i)),limits={-Inf,Inf,1},value=label_,proc=WaveSelectorSetVariables, userData(oldLabel)=label_
		TitleBox TitleLabel, frame=0,fSize=titleBoxSize,title="Label",pos={xpos+10,y_offset-18}, win=$win
		xpos+=90
		string channelInstances
		sprintf channelInstances,"Core#ListPackageInstances(\"%s\",\"%s\",saver=1)",module,"channelConfigs"
		PopupMenu $("Labels_"+num2str(i)),pos={xpos,ypos-1},size={21,21},proc=WaveSelectorPopupMenus
		PopupMenu $("Labels_"+num2str(i)),mode=0,value=#channelInstances
		xpos+=25
		svar ADC=$Core#PackageSettingLoc(module,"channelConfigs",chanName,"ADC")
		string ADCOptions="InputChannelList(DAQ=\""+DAQ+"\")"
		PopupMenu $("ADC_"+num2str(i)),mode=1,popValue=Chan2ADC(i),value=#ADCOptions,Proc=WaveSelectorPopupMenus
		TitleBox TitleADC, frame=0,fSize=titleBoxSize,title="ADC",pos={xpos+5,y_offset-18}, win=$win
		xpos+=40
		svar DAC=$Core#PackageSettingLoc(module,"channelConfigs",chanName,"DAC")
		string DACOptions="OutputChannelList(DAQ=\""+DAQ+"\")"
		PopupMenu $("DAC_"+num2str(i)),mode=1,popvalue=Chan2DAC(i),pos={xpos,ypos-1},value=#DACOptions,Proc=WaveSelectorPopupMenus
		TitleBox TitleDAC, frame=0,fSize=titleBoxSize,title="DAC",pos={xpos+5,y_offset-18}, win=$win
		xpos+=40
		PopupMenu $("Mode_"+num2str(i)),pos={xpos,ypos-1},Proc=WaveSelectorPopupMenus,userData(oldMode)=GetAcqMode(i)
		string modeInstances
		sprintf modeInstances,"Core#ListPackageInstances(\"%s\",\"%s\",editor=1)",module,"acqModes"
		PopupMenu $("Mode_"+num2str(i)),mode=max(1,1+WhichListItem(GetAcqMode(i),AcquisitionModes())),value=#modeInstances
		TitleBox TitleMode, frame=0,fSize=titleBoxSize,title="Mode",pos={xpos+5,y_offset-18}, win=$win
		xpos+=75
		SetDrawEnv fillpat=0; DrawRect 5,ypos-3,xpos-5,ypos+22
		
		// Stimulus settings.  
		PopupMenu $("Assembler_"+num2str(i)),pos={xpos,ypos-1},size={21,21},proc=WaveSelectorPopupMenus		
		PopupMenu $("Assembler_"+num2str(i)),mode=0,value=#("AssemblerList("+num2str(i)+")")
		xpos+=21
		svar stimulus=$Core#PackageSettingLoc(module,"channelConfigs",chanName,"stimulus")
		SetVariable $("Stimulus_"+num2str(i)),pos={xpos,ypos+2},size={65,18},title=" ",proc=WaveSelectorSetVariables
		SetVariable $("Stimulus_"+num2str(i)),limits={-Inf,Inf,1},value=stimulus
		TitleBox TitleStimulus, frame=0,fSize=titleBoxSize,title="Stimulus",pos={xpos+10,y_offset-18}, win=$win
		xpos+=65
		string stimulusInstances
		sprintf stimulusInstances,"Core#ListPackageInstances(\"%s\",\"%s\",saver=1,except=\"%s\")",module,"stimuli","ch*"
		PopupMenu $("Stimuli_"+num2str(i)),pos={xpos,ypos-1},size={21,21},proc=WaveSelectorPopupMenus		
		PopupMenu $("Stimuli_"+num2str(i)),mode=0,value=#stimulusInstances
		xpos+=27
		ControlInfo ParamSets
		Button $("SealTest_"+num2str(i)),pos={xpos,ypos},size={75,20},title="\\Z10Seal Test",disable=V_Value,proc=WaveSelectorButtons
		
		DAQChan+=1
		// Continued in PulseSetTabs.  
	endfor
	SetVariable NumChannels, limits={1,Inf,1}, pos={5,5}, variable=numDAQChannels, size={90,20}, title="# Channels", proc=WaveSelectorSetVariables, userData=num2str(DAQChan)
	Variable Universal_ypos=5+y_offset+numDAQChannels*y_height
	SetDrawEnv fillpat=0; DrawRect 5,Universal_ypos-4,865,Universal_ypos+24
	Button Preview,pos={605,Universal_ypos},size={75,20},title="\\Z10Preview",proc=WaveSelectorButtons
	Button Start,pos={690,Universal_ypos},size={75,20},title="\\Z10Start",proc=WaveSelectorButtons
	Button Reset,pos={775,Universal_ypos},size={75,20},title="\\Z10Reset",proc=WaveSelectorButtons
	Button Advanced,pos={907,Universal_ypos},size={90,20},title="\\Z10Advanced",proc=WaveSelectorButtons
	if(acquiring==1)
		Button Start,title="\\Z10Stop"
	endif
	if(!StringMatch(DAQ,MasterDAQ()))
		Button Copy,pos={905,Universal_ypos},size={75,20},title="\\Z09Copy from "+MasterDAQ(),proc=WaveSelectorButtons
	endif
	
	nvar /z/sdfr=GetDaqDF(DAQ) duration,isi,continuous,realTime,sweepsLeft,kHz,saveMode
	SetVariable Duration,pos={8,Universal_ypos+2},size={95,17},title="Duration",limits={0,Inf,0.1},value=duration
	SetVariable ISI,pos={113,Universal_ypos+2},size={65,17},title="ISI",limits={0,Inf,1},value=isi
	Checkbox Continuous,pos={190,Universal_ypos+3},size={65,17},title="Continuous",variable=continuous,proc=WaveSelectorCheckboxes
	Checkbox RealTime,pos={270,Universal_ypos+3},size={65,17},title="Real Time", variable=realTime
	SetVariable SweepsLeft,pos={358,Universal_ypos+2},size={65,17},title="Left",variable=sweepsLeft,proc=WaveSelectorSetVariables
	SetVariable KHz,pos={438,Universal_ypos+2},size={65,17},title="KHz",variable=kHz,limits={0.1,Inf,1},proc=WaveSelectorSetVariables
	PopupMenu SaveMode,pos={518,Universal_ypos},size={65,17},mode=0,title="Save",value=#("SaveModes(\""+DAQ+"\",brackets=1)"),proc=WaveSelectorPopupMenus
End

Function WaveSelectorTabs(info)
	STRUCT WMTabControlAction &info
	
	if(info.eventCode==2) // Mouse up.  ) : TabControl
		string DAQ=getuserdata(info.win,"","DAQ")
		variable pulseSets=GetNumPulseSets(DAQ)
		switch(info.tab)
			case 0:
				PulseSetTabs(pulseSets,0,win=info.win) // Show stimulus parameters.  
				FilterWin(1,win=info.win) // Hide filter controls.  
				break;
			case 1:
				PulseSetTabs(pulseSets,1,win=info.win) // Hides stimulus parameters.  
				FilterWin(0,win=info.win) // Show filter controls.  
				break;
		endswitch
	endif
End

Function WaveSelectorCheckboxes(info)
	Struct WMCheckboxAction &info
	
	if(info.eventCode<0)
		return -1
	endif
	String ctrlName=info.ctrlName
	Variable value=info.checked
	String win=info.win
	
	string effect
	variable chan,pulseSet,remainderBit
	sscanf ctrlName,"%[a-zA-Z]_%d_%d_%d",effect,chan,pulseSet,remainderBit
	string name=GetChanName(chan)
	strswitch(effect)
		case "AcquireOn":
			variable active=info.checked
			Checkbox $"Show_"+num2str(chan), value=active, win=SweepsWin
			variable i,numChannels=GetNumChannels()
			for(i=0;i<numChannels;i+=1)
				ControlInfo /W=$win $("Synapse_"+num2str(chan)+"_"+num2str(i)); Variable synapse=V_Value
				Checkbox $("Synapse_"+num2str(i)+"_"+num2str(chan)) value=active*synapse, win=SweepsWin
			endfor
			SwitchView("")
			PossiblyShowAnalysis()	 
			break
		case "TestPulse":
			wave TestPulseOn=Core#WavPackageSetting(module,"stimuli",name,"TestPulseOn")
			TestPulseOn[pulseSet]=value
			break
		case "AddStimulus":
			Core#SetVarPackageSetting(module,"channelConfigs",name,"AddStimulus",value)
			break
		case "Remainder":
			wave Remainder=Core#WavPackageSetting(module,"stimuli",name,"remainder")
			Remainder[pulseSet] = value ? (Remainder[pulseSet] | 2^remainderBit) : (Remainder[pulseSet] & ~2^remainderBit) // Bit wise remainder.  
			break
		case "Continuous":
			SetVariable ISI disable=value*2
			break
	endswitch
End

Function WaveSelectorSetVariables(info) : SetVariableControl
	Struct WMSetVariableAction &info
	
	if(!SVInput(info.eventCode))
		return 0
	endif
	string type=StringFromList(0,info.ctrlName,"_")
	variable chan=str2num(StringFromList(1,info.ctrlName,"_"))
	string DAQ=GetUserData(info.win,"","DAQ")
	strswitch(type)
		case "NumChannels":
			SetNumChannels(info)
			break
		case "Label":
			string oldLabel=Core#GetControlUserData(info.ctrlName,"oldLabel",win=info.win)
			string label_=info.sval
			//SetStrPackageSetting(module,"channelConfigs",GetChanName(chan),"label_",label_) // Can't use GetChanLabels because we need
			if(!DataFolderExists(GetChannelFolder(label_)))
				InitChanContainer(chan)
			endif
			variable killFlag=PossiblyKillOldChannelFolder(oldLabel)
			SweepsWinControlsUpdate()
			break
		case "Stimulus":
			if(!strlen(info.sval))
				string stimName="stim"+num2str(chan)
			else
				stimName=CleanupName(info.sval,0)
			endif
			Core#SetStrPackageSetting(module,"channelConfigs",GetChanName(chan),"stimulus",stimName)
			//SetStimulus(chan,stimName)
			break
		case "SweepsLeft":
			SetVariable SweepsLeft userData=num2str(info.dval)
			break
	endswitch
End

Function WaveSelectorPopupMenus(info) : PopupMenuControl
	Struct WMPopupAction &info
	
	if(!PopupInput(info.eventCode))
		return 0
	endif
	string type=StringFromList(0,info.ctrlName,"_")
	variable chan=str2num(StringFromList(1,info.ctrlName,"_"))
	string DAQ=GetUserData(info.win,"","DAQ")
	string name=GetChanName(chan)
	string special
	sprintf special,"CHAN:%d;DAQ:%s;",chan,DAQ
	
	variable err=0
	strswitch(type)
		case "Labels":
			info.ctrlName=ReplaceString("Labels",info.ctrlName,"Label")
			string oldLabel=Chan2Label(chan)
			string newLabel=info.popStr
			strswitch(newLabel)
				case "_Save_":
					string toSave=cleanupname(Chan2Label(chan),0)
					Core#CopyInstance(module,"channelConfigs",name,toSave)
					err=Core#SavePackageInstance(module,"channelConfigs",toSave,special="CHAN:"+num2str(chan))
					if(!err)
						printf "Channel configuration %s was saved successfully.\r",toSave
					endif
					break
				default:
					// Check for a conflict with an existing label.  
					Wave /T Labels=GetChanLabels()
					if(!stringmatch(oldLabel,newLabel))
						SetUniqueChanLabel(chan)
						string newLabelBase=newLabel
						variable i=0		
						variable oldFolderKilled=PossiblyKillOldChannelFolder(oldLabel)
						string oldFolderName=GetChannelFolder(oldLabel)
						string newFolderName=GetChannelFolder(newLabel)
						if(!oldFolderKilled) // If the old folder was not killed.    
							if(DataFolderExists(newFolderName))
								string alert
								sprintf alert,"There is already a folder in use at %s.  Delete it or change its name.\r",newFolderName
								DoAlert 0,alert
								break
							elseif(DataFolderExists(oldFolderName) && strlen(oldFolderName))
								RenameDataFolder $oldFolderName, $newLabel
							endif
						endif
						Core#SetControlUserData(info.ctrlName,"oldLabel",newLabel)
						Core#SetStrPackageSetting(module,"channelConfigs",name,"label_",newLabel) // Update the channel label.  
					endif
					SelectPackageInstance("channelConfigs",newLabel,special=special)
					SetVariable $info.ctrlName userData(oldLabel)=Labels[chan]
					string chanName=GetChanName(chan)
					if(!stringmatch(newLabel,chanName))
						wave /t DAQChannels=Core#WavTPackageSetting(module,"DAQs",DAQ,"channelConfigs")
						DAQChannels[chan]={newLabel}
					endif
					wave /z chanHistory=GetChanHistory(chan)
					if(!waveexists(chanHistory))
						InitChanContainer(chan)
					endif
					SweepsWinControlsUpdate()
					break  
			endswitch
			break
		case "Color":
			wave colors=Core#WavPackageSetting(module,"channelConfigs",name,"color")
			variable red,green,blue
			sscanf info.popStr,"(%d,%d,%d)",red,green,blue
			colors[0]={red}
			Colors[1]={green}
			Colors[2]={blue}
			SwitchView("")
			break
		case "Assembler":
			string assembler=ClearBrackets(info.popStr)
			variable curr_pulse_set = CurrPulseSet(DAQ)
			SetAssembler(chan,assembler,curr_pulse_set)
			break
		case "Stimuli":
			strswitch(info.popStr)
				case "_Save_":
					SaveStimulus(chan)
					break
				default:
					string stimName=info.popStr
					SelectPackageInstance("stimuli",stimName,special=special)
			endswitch
			break
		case "SaveMode":
			Core#SetStrPackageSetting(module,"DAQs",DAQ,"saveMode",ClearBrackets(info.popStr))
			break
		case "ChannelSaveMode":
			Core#SetVarPackageSetting(module,"channelConfigs",name,"saveMode",info.popNum-1)
			break
		case "Mode":
			String newMode=info.popStr
			String oldMode=GetUserData("",info.ctrlName,"oldMode")
			string acqModes=Core#ListPackageInstances(module,"acqModes")
			strswitch(newMode)
				case "_Edit_":
					PopupMenu $(info.ctrlName) mode=max(1,WhichListItem(oldMode,acqModes)+1)
					Core#EditModule(module,package="acqModes")
					break
				case "------":
					PopupMenu $(info.ctrlName) mode=max(1,WhichListItem(oldMode,acqModes)+1)
					break
				default:
					SetAcqMode(newMode,chan)
					return 0
					break
			endswitch
			break
		case "ADC":
			Core#SetStrPackageSetting(module,"channelConfigs",name,"ADC",info.popStr)
			SwitchView("")
			break
		case "DAC":
			Core#SetStrPackageSetting(module,"channelConfigs",name,"DAC",info.popStr)
			break
	endswitch
End

Function SweepsWinControlsUpdate()
	Variable redPre,greenPre,bluePre
	Variable redPost,greenPost,bluePost
	Variable i,j,chan,pre,post
	String titleStr
	
	string win="SweepsWin"
	variable numChannels=GetNumChannels()
	String view=GetUserData(win,"SwitchView","")
	Variable focused=StringMatch(view,"Focused")
	
	// Kill old controls.  
	string controls=ControlNameList(win,";","Show_*")
	variable numShowControls=itemsinlist(controls)
	controls+=ControlNameList(win,";","Synapse_*")
	for(i=0;i<itemsinlist(controls);i+=1)
		string control=stringfromlist(i,controls)
		if(i<numShowControls)
			sscanf control,"Show_%d",chan
		elseif(stringmatch(control,"Synapse_*"))
			sscanf control,"Synapse_%d_%d",pre,post
		endif
		if(chan>=numChannels || pre>=numChannels || post>=numChannels)
			killcontrol /w=$win $control
		endif
	endfor
	
	// Add new controls.  
	for(i=0;i<numChannels;i+=1)
		GetChanColor(i,redPost,greenPost,bluePost)
		sprintf titleStr,"\K(%d,%d,%d)%s",redPost,greenPost,bluePost,GetChanLabel(i)
		Checkbox $("Show_"+num2str(i)), pos={1,1+18*i}, title=titleStr, proc=SweepsWinCheckboxes, win=SweepsWin
		for(j=0;j<numChannels;j+=1)
			GetChanColor(j,redPre,greenPre,bluePre)
			sprintf titleStr,"\K(%d,%d,%d)ch %d\K(0,0,0) -> \K(%d,%d,%d)ch %d",redPre,greenPre,bluePre,j,redPost,greenPost,bluePost,i
			Checkbox $("Synapse_"+num2str(j)+"_"+num2str(i)), pos={95+75*i,1+18*j}, title=titleStr, disable=!focused, proc=SweepsWinCheckboxes, win=SweepsWin
		endfor
	endfor		
	
	// Fix TitleBar
	ControlBar /T max(3,numChannels)*18					
End

function SweepIndexWindow()
	string win="SweepIndexWin"
	variable sweepIndex=wintype(win) ? CtrlNumValue("sweepIndex",win=win)  : 0
	dowindow /k $win
	newpanel /n=$win /w=(100,100,375,150)
	setvariable sweepIndex value=_NUM:sweepIndex,limits={0,99,25},fSize=24
	button reset, proc=SweepIndexWinButtons, size={85,40}, fsize=24, title="Reset"
	button timerReset, proc=SweepIndexWinButtons, title="Fix Timer"
end

function SweepIndexWinButtons(ctrlName)
	string ctrlName
	
	string DAQ=MasterDAQ()
	strswitch(ctrlName)
		case "Reset":
			setvariable sweepIndex value=_NUM:0
			break
		case "TimerReset":
			nvar /sdfr=GetDaqDF(DAQ) lastDAQSweepT
			lastDAQSweepT=stopmstimer(-2)
			break
	endswitch
end

Function RedrawSelector([resize,win])
	Variable resize
	String win
	
	win=SelectString(ParamIsDefault(win),win,WinName(0,64))
	String DAQ=GetWinDAQ(win=win)
	STRUCT rect coords
	
	Core#GetWinCoords(win,coords,forcePixels=0)
	wave divisor=GetDAQDivisor(DAQ)
	if(numpnts(divisor))
		WaveStats /Q divisor
		Variable remainderSpace=V_max>1 ? V_max : 0
	else
		remainderSpace=0
	endif
	//ControlInfo /W=$win $("Remainder_0_0_0")
	Variable checkbox_width=21//V_width
	coords.right=coords.Left+waveSelectorBaseWidth+60*(remainderSpace>0)+(remainderSpace>3)*(remainderSpace-3)*checkbox_width
	if(resize)
		MovePanel(win,coords)
	else
		string instance=GetUserData(win,"","instance")
		instance=selectstring(strlen(instance),Core#DefaultInstance(module,"DAQs"),instance)
		DoWindow /K $win
		WaveSelector(coords2=coords,DAQ=DAQ,instance=instance)
	endif
End

Function FilterWin(hide[,win]) : Panel
	Variable hide // 0 to show, 1 to hide filter controls. 
	String win
	
	win=SelectString(ParamIsDefault(win),win,WinName(0,64))
	String DAQ=GetUserData(win,"","DAQ")
	
	Variable y_offset=str2num(GetUserData(win,"","y_offset"))
	Variable y_height=str2num(GetUserData(win,"","y_height"))
	variable numChannels=GetNumChannels()
	DoWindow /F Selector
	Variable xstart=waveSelectorBaseWidth-553	
	
	Variable i,DAQchan=0
	for(i=0;i<numChannels;i+=1)
		if(!StringMatch(Chan2DAQ(i),DAQ))
			continue
		endif
		Variable ypos=y_offset+y_height*DAQchan // The y position of the corresponding channel.  
		Variable xpos=xstart
		dfref filtersDF=Core#InstanceHome(module,"filters",GetChanName(i))
		nvar /sdfr=filtersDF notch,notchFreq,notchHarmonics,wyldpoint,wyldpointWidth,wyldpointThresh,low,lowFreq,high,highFreq,zero,powerSpec,leakSubtract
	
		Checkbox $("notch_"+num2str(i)),pos={xpos,ypos+1},title=" ",disable=hide,proc=FilterWinCheckboxes,variable=notch
		SetVariable $("notchFreq_"+num2str(i)),pos={xpos+20,ypos},size={35,20},title=" ",limits={0,inf,1},disable=hide,value=notchFreq
		SetVariable $("notchHarmonics_"+num2str(i)),pos={xpos+65,ypos},size={30,20},title=" ",limits={1,inf,1},disable=hide,value=notchHarmonics
		
		Checkbox $("wyldpoint_"+num2str(i)),pos={xpos+120,ypos+1},title=" ",disable=hide,proc=FilterWinCheckboxes,variable=wyldpoint
		SetVariable $("wyldpointWidth_"+num2str(i)),pos={xpos+143,ypos},size={35,20},title=" ",limits={3,inf,1},disable=hide,value=wyldpointWidth
		SetVariable $("wyldpointThresh_"+num2str(i)),pos={xpos+188,ypos},size={35,20},title=" ",limits={0,inf,0.1},disable=hide,value=wyldpointThresh
		
		Checkbox $("low_"+num2str(i)),pos={xpos+240,ypos+1},title=" ",disable=hide,proc=FilterWinCheckboxes,variable=low
		SetVariable $("lowFreq_"+num2str(i)),pos={xpos+263,ypos},title=" ",limits={1,inf,1},disable=hide,value=lowFreq
		
		Checkbox $("high_"+num2str(i)),pos={xpos+325,ypos+1},title=" ",disable=hide,proc=FilterWinCheckboxes,variable=high
		SetVariable $("highFreq_"+num2str(i)),pos={xpos+348,ypos},title=" ",limits={1,inf,1},disable=hide,value=highFreq
		
		CheckBox $("zero_"+num2str(i)),pos={xpos+417,ypos+1},size={50,20},title=" ",disable=hide,proc=FilterWinCheckboxes,variable=zero	
		Checkbox $("powerSpec_"+num2str(i)),pos={xpos+451,ypos+1},title=" ",disable=hide,proc=FilterWinCheckboxes,variable=powerSpec
		Checkbox $("leakSubtract_"+num2str(i)),pos={xpos+485,ypos+1},title=" ",disable=hide,proc=FilterWinCheckboxes,variable=leakSubtract
		string options
		sprintf options,"Core#PopupMenuOptions(\"%s\",\"%s\",\"%s\",\"%s\")",module,"channelConfigs",GetChanName(i),"saveMode"
		PopupMenu $("channelSaveMode_"+num2str(i)),pos={xpos+522,ypos-3},title="",mode=0, disable=hide,proc=WaveSelectorPopupMenus,value=#options
	
		DAQChan+=1
	endfor
	
	xpos=xstart-25
	ypos=10
	if(numChannels==1)
		 ypos+=5 // Don't let the rectangles run into the setvariable captions.  
	endif
	TitleBox NotchTitle pos={xpos+52, ypos}, disable=hide, title="Notch Filter", frame=0
	TitleBox MedianTitle pos={xpos+173, ypos}, disable=hide, title="Median Filter", frame=0
	TitleBox LowPassTitle pos={xpos+269, ypos}, disable=hide, title="Low-Pass Filter", frame=0
	TitleBox HighPassTitle pos={xpos+352, ypos}, disable=hide, title="High-Pass Filter", frame=0
	
	xpos=xstart-18
	ypos=y_offset-20
	SetDrawEnv fsize=10,fillpat=0,textxjust=1,save
	TitleBox FreqTitle0 pos={xpos+40, ypos}, disable=hide, title="Freq", frame=0
	TitleBox HarmonicsTitle pos={xpos+73, ypos}, disable=hide, title="Harmonics", frame=0
	TitleBox WidthTitle pos={xpos+161, ypos}, disable=hide, title="Width", frame=0
	TitleBox ThreshTitle pos={xpos+204, ypos}, disable=hide, title="Thresh", frame=0
	TitleBox FreqTitle1 pos={xpos+288, ypos}, disable=hide, title="Freq", frame=0
	TitleBox FreqTitle2 pos={xpos+373, ypos}, disable=hide, title="Freq", frame=0
	TitleBox ZeroTitle pos={xpos+432, ypos}, disable=hide, title="Zero", frame=0
	TitleBox PowerTitle pos={xpos+460, ypos}, disable=hide, title="Power", frame=0	
	TitleBox LeakTitle pos={xpos+500, ypos}, disable=hide, title="Leak", frame=0	
	TitleBox SaveTitle pos={xpos+542, ypos}, disable=hide, title="Save", frame=0
	
	xpos+=12
	ypos-=15
	Variable y_size=DAQchan*y_height+45
	GroupBox frame0, frame=0, pos={xpos+2,2}, size={117,y_size}, disable=hide
	GroupBox frame1, frame=0, pos={xpos+122,2}, size={117,y_size}, disable=hide
	GroupBox frame2, frame=0, pos={xpos+242,2}, size={82,y_size}, disable=hide
	GroupBox frame3, frame=0, pos={xpos+327,2}, size={82,y_size}, disable=hide
	//GroupBox frame4, frame=0, pos={xpos+455,2}, size={20,y_size}, disable=hide
	//GroupBox frame5, frame=0, pos={xpos+485,2}, size={20,y_size}, disable=hide
End

Function FilterWinCheckboxes(ctrlName,value) : CheckboxControl
	String ctrlName; Variable value
	Variable chan=str2num(StringFromList(ItemsInList(ctrlName,"_")-1,ctrlName,"_"))
	String name=ReplaceString("_"+num2str(chan),ctrlName,"")
	Core#SetVarPackageSetting(module,"filters",GetChanName(chan),name,value)
	strswitch(name)
		case "powerSpec":
			if(value==1)
				ShowPower(chan)
			endif
			break
		case "leakSubtract":
			if(value==1)
				//ShowLeakSubtraction(chan)
			endif
	endswitch
End

Function PulseSetTab(info)
	STRUCT WMTabControlAction &info
	if(info.eventCode==2) // Mouse up.  
		String win=info.win
		string DAQ=getuserdata(info.win,"","DAQ")
		variable pulseSets=GetNumPulseSets(DAQ)
		if(info.tab == 0)
			variable minPulseSets=InDynamicClamp() ? 3 : 1
			pulseSets=max(minPulseSets,pulseSets-1)
			TabControl /Z PulseSets value=1, win=$win
		elseif(info.tab == pulseSets+1)
			pulseSets+=1
		else
			TabControl /Z PulseSets value=info.tab, win=$win
		endif
		PulseSetTabs(pulseSets,0,win=win)
	endif
End

Function PulseSetTabs(num,hide[,win])
	variable num // The number of the pulse set tab.   
	variable hide // 0 to show, 1 to hide controls.
	string win
	
	win=SelectString(ParamIsDefault(win),win,WinName(0,64))  
	if(num>100)
		return -1
	endif
	if(!WinType(win))
		return -2
	endif
		
	String DAQ=GetUserData(win,"","DAQ")
	Variable /G $Core#PackageSettingLoc(module,"DAQs",DAQ,"pulseSets")=num
	Variable i,j,k,m,size=1
	Variable y_height=str2num(GetUserData(win, "", "y_height"))
	Variable y_offset=str2num(GetUserData(win, "", "y_offset"))
	Variable x_offset=waveSelectorBaseWidth-419
	Variable x_width=60
	variable numChannels=GetNumChannels()
	
	TabControl PulseSets, disable=hide, win=$win
	ControlInfo /W=$win PulseSets
	Variable curr_tab=V_Value
	//string pulseParams=ListPackageObjects(module,"stimuli") // Doesn't give the preferred order of objects.  
	string pulseParams="Begin;Ampl;dAmpl;Width;IPI;Pulses;Divisor;Remainder;testPulseOn;assembler" // ListPackageObjects() doesn't give the preferred order of objects.  
	
	for(i=0;i<numChannels;i+=1)
		if(stringmatch(Chan2DAQ(i),DAQ))
			string channel = GetChanName(i)
			dfref instanceDF=Core#InstanceHome(module,"stimuli",channel)
			if(!datafolderrefstatus(instanceDF)) // If this stimulus instance could not be found. 
				// Create it from the default template.  
				instanceDF = Core#CopyDefaultInstance(module,"stimuli",channel)
			endif
			for(j=0;j<itemsinlist(pulseParams);j+=1)
				string pulseParam=stringfromlist(j,pulseParams)
				string pulseParamLoc=Core#PackageSettingLoc(module,"stimuli",channel,pulseParam)
				if(!stringmatch(Core#ObjectType(pulseParamLoc),"WAV") && !stringmatch(Core#ObjectType(pulseParamLoc),"WAVT"))
					continue
				endif
				wave w=$pulseParamLoc
				variable oldNumPulseSets=dimsize(w,0)
				if(oldNumPulseSets!=num)
					redimension /n=(num,-1) w
					if(oldNumPulseSets<num)
						// Nonsense that must be done because Igor can't handle different wave types assigned to the same wave reference.  
						if(wavetype(w)>0)
						 	wave wn = $pulseParamLoc
							w[num-1][]=w[num-2][q]
						else
							wave /t wt = $pulseParamLoc
							wt[num-1][]=wt[num-2][q]
						endif
					endif
				endif
			endfor
		endif
	endfor
	
	for(i=0;i<=(num+1);i+=1)
		if(i==0)
			String pulse_set="-"
		elseif(i==num+1)
			pulse_set="+"
			for(k=0;k<ItemsInList(pulseParams);k+=1)
				pulseParam=StringFromList(k,pulseParams)
				String controls_to_hide=ControlNameList(win, ";",pulseParam+"*");
				for(j=0;j<ItemsInList(controls_to_hide);j+=1)
					String control_name=StringFromList(j,controls_to_hide)
					variable pulse_set2=str2num(StringFromList(2,control_name,"_"))
					if(pulse_set2==i-1)
						KillControl /W=$win $control_name
					endif
				endfor
			endfor
		else
			pulse_set=num2str(i-1)
			Variable DAQchan=0
			variable max_divisor=1	
			for(j=0;j<numChannels;j+=1)
				if(!StringMatch(Chan2DAQ(j),DAQ))
					continue
				endif
				wave Divisor=GetChanDivisor(j)
				max_divisor = max(Divisor[i-1],max_divisor)
				wave Remainder=GetChanRemainder(j)
				Variable ypos=y_offset+DAQchan*y_height
				nvar addStimulus=$Core#PackageSettingLoc(module,"channelConfigs",GetChanName(j),"addStimulus")
				Checkbox $("AddStimulus"+"_"+num2str(j)),pos={x_offset-54,ypos+3},title=" ",variable=addStimulus,disable=(2), win=$win, proc=WaveSelectorCheckboxes
				TitleBox TitleAddStimulus, frame=0,fSize=10,title="Add",pos={x_offset-56,y_offset-18},disable=(hide),win=$win
				TitleBox TitleTestPulse, frame=0,fSize=10,title="TP",pos={x_offset-27,y_offset-18},disable=(hide),win=$win
				
				for(k=0;k<ItemsInList(pulseParams);k+=1)
					pulseParam=StringFromList(k,pulseParams)
					pulseParamLoc=Core#PackageSettingLoc(module,"stimuli",GetChanName(j),pulseParam)
					if(!stringmatch(Core#ObjectType(pulseParamLoc),"WAV"))
						continue
					endif
					wave w=$pulseParamLoc
					if(StringMatch(pulseParam,"Divisor")==1 && w[i-1]==0) // If this is a divisor value, and the current value is 0.  
						w[i-1]=1 // Set it to 1.  
					endif
					strswitch(pulseParam)
						case "ampl":
							Variable low_limit=-Inf
							Variable high_limit=Inf
							break
						case "dampl":
							low_limit=-Inf
							high_limit=Inf
							break
						case "divisor":
							low_limit=1
							high_limit=100
							break
						default:
							low_limit=0
							high_limit=Inf
							break
					endswitch
					
					if(StringMatch(pulseParam,"remainder"))
						//Checkbox $("Remainder"+"_"+num2str(j)+"_"+num2str(i-1)+"_0"),pos={x_offset+x_width*k,ypos+1},title=" ",value=(Remainder[j][i-1] & 2^0),disable=(hide || Divisor[j][i-1]<=1 || (i!=curr_tab)), win=$win, proc=WaveSelectorCheckboxes
						variable sweep = GetCurrSweep()
						for(m=0;m<Divisor[i-1];m+=1)
							Checkbox $("Remainder_"+num2str(j)+"_"+num2str(i-1)+"_"+num2str(m)),pos={x_offset+x_width*k+20*m,ypos+1},size={15,15},title=" ",value=(w[i-1] & 2^m),disable=(hide || Divisor[i-1] <=1 || Divisor[i-1]<(m+1) || (i!=curr_tab)), win=$win, proc=WaveSelectorCheckboxes
						endfor
						for(m=0;m<Divisor[i-1];m+=1) // Separate loop to make sure GroupBoxes get drawn on top.  
							if(mod(sweep,Divisor[i-1])==m)
									variable xx = x_offset+x_width*k-3
									variable dxx = 20
									variable yy = ypos-2
									string pos_data
									sprintf pos_data,"xx:%d;dxx:%d,yy:%d;",xx,dxx,yy
									GroupBox $("CurrentRemainder_"+num2str(j)+"_"+num2str(i-1)) frame=0,pos={xx+dxx*m,yy},size={20,20},disable=(hide || Divisor[i-1] == 1 || (i!=curr_tab)),userData(pos_data)=pos_data,win=$win				
							endif
						endfor
						if(j==(numChannels-1))
							Button $("RotateL_"+num2str(i-1)),pos={x_offset+x_width*k-3,ypos+26},size={20,15},title="<",disable=(hide || max_divisor ==1 || (i!=curr_tab)), win=$win, proc=WaveSelectorButtons
							Button $("RotateR_"+num2str(i-1)),pos={x_offset+x_width*k+20*(max_divisor-1)-3,ypos+26},size={20,15},title=">",disable=(hide || max_divisor == 1 || (i!=curr_tab)), win=$win, proc=WaveSelectorButtons
						endif
						Do
							ControlInfo /W=$win $("Remainder_"+num2str(j)+"_"+num2str(i-1)+"_"+num2str(m))
							if(V_Flag!=2) // No such checkbox.
								break
							else // This checkbox is for a remainder higher than the current divisor supports.  
								KillControl /W=$win $("Remainder_"+num2str(j)+"_"+num2str(i-1)+"_"+num2str(m))
							endif
							m+=1
						While(1)
					elseif(StringMatch(pulseParam,"testPulseOn"))
						Checkbox $("TestPulse"+"_"+num2str(j)+"_"+num2str(i-1)),pos={x_offset-27,ypos+3},title=" ",value=w[i-1],disable=(hide || (i!=curr_tab)), win=$win, proc=WaveSelectorCheckboxes
						continue
					else
						SetVariable $(pulseParam+"_"+num2str(j)+"_"+num2str(i-1)),pos={x_offset+x_width*k,ypos+1},title=" ",value=w[i-1],disable=(hide || (i!=curr_tab)),limits={low_limit,high_limit,1}, help={PulseParamHelp(pulseParam)}, proc=WaveValuesProc, win=$win
					endif
					if(i==1 && j==0)
						WaveStats /Q Divisor
						Variable text_centering=1-FontSizeStringWidth("default", 10, 0, pulseParam)/2+StringMatch(pulseParam,"Remainder")*(V_max*10-20)+18
						TitleBox $("Title_"+pulseParam) frame=0,fSize=10,title=selectstring(stringmatch(pulseParam,"dAmpl"),pulseParam,"\F'Symbol'D\F'Default'Ampl")
						TitleBox $("Title_"+pulseParam) pos={x_offset+x_width*k+text_centering,y_offset-18},disable=(hide),win=$win
					endif
				endfor
				Button $("SealTest_"+num2str(j)),disable=hide
				DAQchan+=1
			endfor
		endif
		size+=FontSizeStringWidth("default", 12, 0, pulse_set)+23
		string DAQs=GetDAQs()
		for(j=0;j<ItemsInList(DAQs);j+=1)
			String oneDAQ=StringFromList(j,DAQs)
			if(i<20) // Igor limits on the number of tabs in a tab control.  
				TabControl /Z PulseSets tablabel(i)=pulse_set, size={size,20}, pos={360,5}, proc=PulseSetTab, win=$(oneDAQ+"_Selector")
			endif
		endfor
	endfor
	
	ControlInfo /W=$win PulseSets
	if(V_Value==0)
		TabControl PulseSets value=1, win=$win
	endif
	wave Divisor=GetDAQDivisor(DAQ)
	if(numpnts(Divisor))
		WaveStats /Q Divisor
	endif
	TitleBox Title_Remainder disable=(hide || V_max<=1)
	PulseSetTabLabels()
End

function CurrPulseSet(DAQ)
	string DAQ
	
	string win =GetDAQWin(DAQ=DAQ)
	ControlInfo /W=$win PulseSets
	return v_flag==8 ? v_value-1 : nan
end

Function BumpRemainderBoxes([DAQ])
	string DAQ
	
	DAQ=SelectString(!ParamIsDefault(DAQ),MasterDAQ(),DAQ)
	string win = GetDAQWin(DAQ=DAQ)
	ControlInfo /W=$win PulseSets
	variable curr_tab=V_Value
	variable num_channels = GetNumChannels()
	variable sweep_num = GetCurrSweep()
	
	variable j
	for(j=0;j<num_channels;j+=1)
		if(stringmatch(Chan2DAQ(j),DAQ))
			string name = "CurrentRemainder_"+num2str(j)+"_"+num2str(curr_tab-1)
			string pos_data = GetUserData(win,name,"pos_data")
			variable xx,dxx,yy
			sscanf pos_data,"xx:%d;dxx:%d,yy:%d;",xx,dxx,yy
			wave Divisor = GetChanDivisor(j)
			variable m = mod(sweep_num,Divisor[curr_tab-1])
			GroupBox $name pos={xx+m*dxx,yy},win=$win				
		endif
	endfor
End

Function PulseSetTabLabels()
	string labels="-;"
	string DAQ=GetWinDAQ()
	variable pulseSets=GetNumPulseSets(daq)
	if(InDynamicClamp())
		variable i,j
		for(i=1;i<=pulseSets;i+=1)
			switch(mod(i-1,3))
				case 0: 
					labels+="Bias;"
					break
				case 1:
					labels+="gE;"
					break
				case 2:
					labels+="gI;"
					break
			endswitch
		endfor
	else
		for(i=1;i<=pulseSets;i+=1)
			labels+=num2str(i-1)+";"
		endfor
	endif
	labels+="+"
	variable width=0
	for(i=0;i<=pulseSets+1;i+=1)
		string text=stringfromlist(i,labels)
		TabControl PulseSets tabLabel(i)=text
		width+=FontSizeStringWidth("Default", 9, 0, text)+25
	endfor
	for(j=99;j>=i;j-=1)
		TabControl PulseSets tabLabel(j)=""
	endfor
	TabControl PulseSets size={width,20}
End

Function MakeQuickPulseSetsPanel([DAQ])
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(),DAQ)
	string selectorWin=DAQ+"_Selector"
	DoWindow /K QuickPulseSetsPanel
	NewPanel /K=1 /W=(200,200,350,450) /N=QuickPulseSetsPanel
	setwindow kwTopWin userData(selectorWin)=selectorWin // Selector window that this quick pulse set panel will be updating.  
	popupmenu chan, title="Channel", value=ChanLabels()
	setvariable pulseSets, pos={2,30}, size={120,25}, title="# of Pulse Sets",value=_NUM:1
	variable i
	for(i=0;i<6;i+=1)
		string paramName=stringfromlist(i,pulseParams)
		setvariable $("inc"+paramName), pos={2,55+25*i}, size={120,25}, title=paramName+" Increment",value=_NUM:0
	endfor
	button SetQuickPulseSets, pos={2,55+25*i}, proc=WaveSelectorButtons, title="Create"
	AutoPositionWindow /M=1/R=$selectorWin
End

Function SetQuickPulseSets()
	string selectorWin=getuserdata("","","selectorWin")
	string labell=ctrlstrvalue("chan")
	variable chan=Label2Chan(labell)
	dfref stimulusDF=Core#InstanceHome(module,"stimuli",GetChanName(chan))
	string DAQ = Chan2DAQ(chan)
	dfref daqDF = Core#InstanceHome(module,"DAQs",DAQ)
	wave /sdfr=stimulusDF width,ampl,dampl,pulses,ipi,begin,divisor,remainder,testpulseon
	nvar /sdfr=daqDF pulseSets
	pulseSets=ctrlnumvalue("pulseSets")
	//PulseSetTabs(num,hide[,win])
	variable i
	for(i=0;i<6;i+=1)
		string paramName=stringfromlist(i,pulseParams)
		wave param=stimulusDF:$paramName
		redimension /n=(pulseSets) param
		param=numtype(param) ? 0 : param
		param[]=param[0]+p*ctrlnumvalue("inc"+paramName)
	endfor
	redimension /n=(pulseSets) divisor,remainder
	divisor=pulseSets
	remainder=2^p
	testPulseOn=TestPulseOn[0]
	RedrawSelector(win=selectorWin)
End

function /s GetWinDAQ([win])
	string win
	
	win=selectstring(!paramisdefault(win),winname(0,65),win)
	string DAQ=""
	if(strlen(win))
		DAQ=getuserdata(win,"","DAQ")
	endif
	return DAQ
end

function /s GetDAQWin([DAQ])
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(),DAQ)
	string panels = winlist("*",";","WIN:64") // All panels.  
	variable i
	string win = ""
	for(i=0;i<itemsinlist(panels);i+=1)
		string panel = stringfromlist(i,panels)
		string panelDAQ = GetWinDAQ(win=panel)
		if(stringmatch(DAQ,panelDAQ))
			win = panel
			break
		endif
	endfor  
	return win
end

function GetWinDAQNum([win])
	string win
	
	win=selectstring(!paramisdefault(win),winname(0,65),win)
	string DAQ=GetWinDAQ(win=win)
	variable num=GetDAQNum(DAQ)
	return num
end

Function /S PulseParamHelp(param)
	String param
	
	strswitch(param)
		case "Width":
			return "Pulse width (ms)."
			break
		case "Ampl":
			return "Pulse amplitude (units of the output mode)."
			break
		case "IPI":
			return "Inter-pulse interval (ms)."
			break
		case "dAmpl":
			return "Increase in pulse amplitude with each pulse (units of the output mode)."
			break
		case "Begin":
			return "Time of the first pulse (ms)."
			break
		case "Divisor":
			return "This pulse set will occur whenever the sweep number divided by this divisor is equal to the remainder."
			break
		case "Remainder":
			return "This pulse set will occur whenever the sweep number divided by this divisor is equal to the remainder."
			break
	endswitch
	return ""
End

Function PreviewStimuli([sweep_num,no_show])
	Variable sweep_num, no_show
	
	variable currSweep=GetCurrSweep()
	if(ParamIsDefault(sweep_num))
		sweep_num=currSweep
	endif
	
	WaveUpdate(sweep_num=sweep_num) // Build the stimuli from the settings on the selector panel.  
	variable i,numChannels=GetNumChannels()
	string channel
	if(wintype("PreviewStimuliWin"))
		if(!no_show)
			DoWindow /F PreviewStimuliWin
		endif
	else
		Display /K=1/N=PreviewStimuliWin/W=(100,100,600,350) as "Stimulus Preview"
		ControlBar /W=PreviewStimuliWin /T 55
		Button SaveStimulus, proc=PreviewStimuliButtons, size={100,20}, title="Save Stimulus", win=PreviewStimuliWin
		PopupMenu StimChan value=#"ChanLabels()", title="on",proc=PreviewStimuliPopups, win=PreviewStimuliWin
		svar stimulus=$Core#PackageSettingLoc(module,"channelConfigs",GetChanName(0),"stimulus")
		SetVariable StimName value=stimulus, title="as", disable=0, pos={280,3},size={100,15}, win=PreviewStimuliWin
		PopupMenu StimType value="Pulses;IBW", title="as type", pos={390,0}, win=PreviewStimuliWin
	endif
	if(!paramisdefault(sweep_num))
		SaveAxes("default_",win="PreviewStimuliWin")
	endif
	RemoveTraces(win="PreviewStimuliWin")
	//Wave LCM_=root:parameters:LCM_
	
	// Make a list of modes used by the current stimuli.  
	String modeList=""
	Variable numModes=NumDistinctAcqModes(modeList,withOutput=1)
	
	// Add preview traces for stimuli of the same mode to a common axis.  
	for(i=0;i<numChannels;i+=1)
		if(IsChanActive(i) && !StringMatch(Chan2DAC(i),"N"))
			string DAQ=Chan2DAQ(i)
			dfref daqDF=GetDAQdf(DAQ)
			wave /sdfr=daqDF LCM_
			variable red,green,blue; GetChanColor(i,red,green,blue)
			wave /sdfr=daqDF Raw=$("Raw_"+num2str(i))
			Variable remainder=mod(sweep_num,LCM_[i])
			string acqMode=GetAcqMode(i)
			Variable modeNum=max(0,WhichListItem(acqMode,modeList))
			if(IsDynamicClamp(acqMode))
				wave /sdfr=daqDF forcingWave,eWave,iWave
				AppendToGraph /W=PreviewStimuliWin /L=$("axis_forcing") /c=(0,0,65535) forcingWave[][remainder]
				AppendToGraph /W=PreviewStimuliWin /R=$("axis_conductance") /c=(0,65535,0) eWave[][remainder][1]
				AppendToGraph /W=PreviewStimuliWin /R=$("axis_conductance") /c=(65535,0,0) iWave[][remainder][2]
			else
				if(mod(modeNum,2))
					AppendToGraph /W=PreviewStimuliWin /R=$("axis_"+num2str(modeNum)) /c=(red,green,blue) Raw[][remainder]
				else
					AppendToGraph /W=PreviewStimuliWin /L=$("axis_"+num2str(modeNum)) /c=(red,green,blue) Raw[][remainder]
				endif
			endif
		endif
	endfor
	
	// Align and label axes.  
	string axes=AxisList2("vertical",win="PreviewStimuliWin")
	for(i=0;i<itemsinlist(axes);i+=1)
		string axis=stringfromlist(i,axes)
		ModifyGraph /W=PreviewStimuliWin freePos($axis)={0.05,kwFraction},axisEnab($axis)={i/itemsinlist(axes),(i+1)/itemsinlist(axes)-0.02}
		SetAxis /W=PreviewStimuliWin /A/Z $axis
		ModifyGraph /Z/W=PreviewStimuliWin lblMargin($axis)=8
		modeNum=str2num(stringfromlist(1,axis,"_"))
		string modeName=StringFromList(modeNum,modeList)
		string outputUnits=GetModeOutputUnits(modeName)
		Label /Z/W=PreviewStimuliWin $axis outputUnits 
	endfor
	ModifyGraph /Z/W=PreviewStimuliWin axisEnab(bottom)={0.05,0.95}
	SetAxis /Z/W=PreviewStimuliWin /A/Z bottom
	Label /Z/W=PreviewStimuliWin bottom "Time (s)"
	ModifyGraph /Z/W=PreviewStimuliWin lblPos=100
	
	if(!paramisdefault(sweep_num))
		RestoreAxes("default_",win="PreviewStimuliWin")
	endif
	
	SetVariable PossibleSweepNum, value=_NUM:sweep_num, limits={0,Inf,1}, pos={5,30}, size={160,20}, proc=PreviewStimuliSetVariables, title="Preview Sweep Number", win=PreviewStimuliWin
	ControlInfo /W=PreviewStimuliWin Stagger
	if(V_flag<=0)
		Checkbox Stagger, value=0, pos={170,30}, title="Stagger View",proc=PreviewStimuliCheckboxes, win=PreviewStimuliWin
	endif
	
	// Offset each successive channel of the same mode (on the same axis) by 1% in the x and y directions so overlapping stimuli can be discriminated.  
	ControlInfo /W=PreviewStimuliWin Stagger
	PreviewStimuliCheckboxes("Stagger",V_Value)
End

Function PreviewStimuliPopups(info)
	Struct WMPopupAction &info
	
	if(!PopupInput(info.eventCode))
		return 0
	endif
	strswitch(info.ctrlName)
		case "StimChan":
			String chanName=info.popStr
			Wave /T Labels=GetChanLabels()
			FindValue /TEXT=chanName /TXOP=4 Labels
			Variable chan=V_Value
			if(chan>=0)
				svar stimulus=$Core#PackageSettingLoc(module,"channelConfigs",GetChanName(chan),"stimulus")
				SetVariable StimName value=stimulus
			endif
			break
	endswitch
End

Function PreviewStimuliCheckboxes(ctrlName,val)
	String ctrlName
	Variable val
	
	strswitch(ctrlName)
		case "Stagger":
			if(val)
				String dummy=""
				Variable i,numModes=NumDistinctAcqModes(dummy)
				DoUpdate
				GetAxis /Q bottom
				if(!V_flag)
					Variable x_range=(V_max-V_min)
				endif
				String traces=TraceNameList("",";",3)
				Variable modeNum
				for(modeNum=0;modeNum<numModes;modeNum+=1)
					Variable offsetAmount=0
					String modeAxis="Axis_"+num2str(modeNum)
					GetAxis /Q $modeAxis
					if(!V_flag)
						Variable y_range=(V_max-V_min)
					endif
					for(i=0;i<ItemsInList(traces);i+=1)
						String trace=StringFromList(i,traces)
						String trace_info=TraceInfo("",trace,0)
						String traceAxis=StringByKey("YAXIS",trace_info)
						if(StringMatch(traceAxis,modeAxis))
							ModifyGraph /Z offset($("Raw_"+num2str(i)))={offsetAmount*x_range/100,offsetAmount*y_range/100}
							offsetAmount+=1
						endif
					endfor
				endfor
			else
				ModifyGraph /Z offset={0,0}
			endif
			break
	endswitch
End

Function PreviewStimuliSetVariables(info)
	STRUCT WMSetVariableAction &info
	if(info.eventCode>0)
		PreviewStimuli(sweep_num=info.dval)
	endif
End

Function PreviewStimuliButtons(ctrlName)
	String ctrlName
	
	variable err
	strswitch(ctrlName)
		case "SaveStimulus":
			Wave /t Labels=GetChanLabels()
			ControlInfo StimChan; string labell=S_Value
			FindValue /TEXT=labell /TXOP=4 Labels
			variable chan=V_Value
			string stimName=GetStimulusName(chan)
			ControlInfo /W=PreviewStimuliWin StimType
			if(StringMatch(S_Value,"IBW"))
				WaveSave(chan,as=stimName)
			else
				err = SaveStimulus(chan)
				//string chanName=GetChanName(chan)
				//if(!stringmatch(stimName,chanName))
				//	Core#CopyInstance(module,"stimuli",chanName,stimName)
				//endif
				//err=Core#SavePackageInstance("Acq","stimuli",stimName,special="CHAN:"+num2str(chan))
				if(!err)
					printf "Stimulus '%s' on channel '%s' saved successfully.\r",stimName,labell
				endif
			endif
			break
	endswitch
End

Function WaveSelectorButtons(info)
	STRUCT WMButtonAction &info
	if(info.eventCode==2)
		String action=StringFromList(0,info.ctrlName,"_")
		Variable chan=str2num(StringFromList(1,info.ctrlName,"_"))
		String DAQ=GetUserData(info.win,"","DAQ")
		strswitch(action)
			case "SealTest":
				SealTest(2^chan)
				break
			case "Preview":
				PreviewStimuli()
				break
			case "Start":
				StartAcquisition(DAQ=DAQ)
				break
			case "Reset":
				DoAlert 1, "Are you sure you want to reset?  This will erase acquisition data for this experiment from memory."
				if(V_flag==1)
					ResetExperiment()
				endif
				break
			case "Copy":
				String items="VAR:duration;VAR:isi;VAR:continuous;VAR:realTime;VAR:sweepsLeft;"
				DFRef masterDAQDF=GetDaqDF(MasterDAQ())
				string thisDAQ=GetUserData(info.win,"","DAQ")
				DFRef thisDAQDF=GetDaqDF(thisDAQ)
				MoveObjects(items,masterDAQDF,thisDAQDF,saveSource=1)
				break
			case "SuperClamp":
				SuperClamp()
				break
			case "SetQuickPulseSets":
				SetQuickPulseSets()
				break
			case "RotateL":
			case "RotateR":
				variable pulse_set = chan // The number after the underscore is actually a pulse set number in this case.  
				variable num_channels = GetNumChannels()
				variable i
				for(i=0;i<num_channels;i+=1)
					wave divisor = GetChanDivisor(i)
					wave remainder = GetChanRemainder(i)
					// Rotate remainder bits.  
					if(stringmatch(action[6],"R"))
						remainder *= 2
						remainder += remainder & 2^(Divisor[p]) ? -2^(Divisor[p])+1 : 0
					else
						remainder /= 2
						remainder += mod(remainder,1)==0.5 ? 2^(Divisor[p]-1)-0.5 : 0
					endif
				endfor
				variable numPulseSets = GetNumPulseSets(DAQ)
				PulseSetTabs(numPulseSets,0,win=info.win)
				//RedrawSelector()
				break
			case "Advanced":
				PopupContextualMenu /N "SelectorContext"
				break
		endswitch
	endif
End

Function WaveValuesProc(info) : SetVariableControl
	Struct WMSetVariableAction &info
	
	if(!SVInput(info.eventCode))
		return 0
	endif
	nvar /sdfr=GetStatusDF() waveformSweeps
	waveFormSweeps=0
	if(StringMatch(info.ctrlName,"Divisor*"))
		ControlInfo PulseSets; Variable currTab=V_Value
		if(WinType(info.win))
			RedrawSelector(resize=1,win=info.win)
			STRUCT WMTabControlAction info2
			info2.eventCode=2; info2.tab=currTab; info2.win=info.win
			PulseSetTab(info2)
		endif
	endif
End

function /df WinRecMacrosDF()
	string loc="root:Packages:Profiles:Macros"
	dfref df=NewFolder(loc) 
	return df
end

// The window that plots the values of interest (like the peak amplitude of an EPSC)
Function AnalysisWindow([instance]) : Graph
	string instance
	
	string win = "analysisWin"
	string package = win
	dfref df = Core#CopyInstance(module,package,"_default_","win0")
	DoWindow /K $win
	SetDataFolder root:
	Struct rect coords
	variable use_default_coords = 1
	if(!paramisdefault(instance) && Core#InstanceExists(module,package,instance))
		coords.left = Core#VarPackageSetting(module,package,instance,"left",sub="position")
  	coords.top = Core#VarPackageSetting(module,package,instance,"top",sub="position")
  	coords.right = Core#VarPackageSetting(module,package,instance,"right",sub="position")
  	coords.bottom = Core#VarPackageSetting(module,package,instance,"bottom",sub="position")
		if(coords.right > 10 && coords.bottom > 10) // Sane coordinates.  
			use_default_coords = 0  
  	endif
  endif
  if(use_default_coords)
  	IgorWinCoords(coords)
		coords.left+=1
  	coords.right-=1
  	coords.top=(coords.bottom-coords.top)*0.6
  endif
	
	svar /z/sdfr=df lastMethod
	if(!svar_exists(lastMethod))
		string /g df:lastMethod=""
		svar /z/sdfr=df lastMethod
	endif
	
	AnalysisMethodListBoxUpdate() // Create a bunch of variables that will be used in the next section.  
	Variable axisPaddingLeft=0.04
	Display /N=AnalysisWin /K=2 /W=(coords.left,coords.top,coords.right,coords.bottom) /L=Ampl_axis /B=Time_axis as "Analysis"
	ControlBar /W=AnalysisWin /T 25
	Button AnalysisSelect, title="Analysis", proc=AnalysisWinButtons, win=AnalysisWin
	PopupMenu Trend, size={55,20},proc=AnalysisWinPopupMenus,mode=0,value="Linear Regression;Decimation;Loess;----;Remove", title="Trend", win=AnalysisWin
  Button Normalize, size={65,20},proc=AnalysisWinButtons,title="Normalize", win=AnalysisWin
  Button Scale, size={55,20},proc=AnalysisWinButtons,title="Scale",win=AnalysisWin
  Button Recalculate, size={110,20},proc=AnalysisWinButtons,title="Recalculate", win=AnalysisWin
  wave /sdfr=df parameter
  SetVariable Parameter, disable=1,size={80,20},value=parameter[0], win=AnalysisWin
  PopupMenu Minimum, title="Minimum", value=#"ChannelCombos(\"minimum\",\"\")", mode=0, proc=AnalysisWinPopupMenus, win=AnalysisWin
  SetVariable SweepNum_A,pos={685,3},title="A",value=root:status:cursorSweepNum_A,proc=AnalysisWinSetVariables,limits={0,inf,1}, win=AnalysisWin
  SetVariable SweepNum_B,title="B",value=root:status:cursorSweepNum_B,proc=AnalysisWinSetVariables,limits={0,inf,1}, win=AnalysisWin
  SetDrawEnv fsize=6,save
  DoUpdate
  GetWindow $win, gsizeDC
  Variable graph_height=V_bottom-V_top-50

  variable numChannels=GetNumChannels()
	Wave /T Labels=GetChanLabels()
	
	Variable plotNum=0,numPlots=0,axisSizeTotal=0,axisSizeSoFar=0,i,j,k
	String axisSizeStr=""
	wave /sdfr=df SelWave
	wave /t/sdfr=df ListWave
	wave /sdfr=df AxisIndex; AxisIndex=NaN
	
	string analysisMethods=Core#ListPackageInstances(module,"analysisMethods")
	for(i=0;i<ItemsInList(analysisMethods);i+=1) // Over all the available analysis methods.  
		string analysisMethod=StringFromList(i,analysisMethods)
		variable plot=Core#VarPackageSetting(module,"analysisMethods",analysisMethod,"show") // 1 if the "Show" checkbox is checked; 0 otherwise.  
		numPlots+=plot // Plot it.  
	endfor
	
	variable currSweep=GetCurrSweep()
	
	for(k=0;k<ItemsInList(analysisMethods);k+=1)
		analysisMethod=StringFromList(k,analysisMethods)
		plot=Core#VarPackageSetting(module,"analysisMethods",analysisMethod,"show") // 1 if the "Show" checkbox is checked; 0 otherwise.  
		if(!plot) // If this plot does not have its "Show" checkbox checked.  
			continue // Skip it.  
		endif
		dfref instanceDF=Core#InstanceHome(module,"analysisMethods",analysisMethod)
		nvar /sdfr=instanceDF axisSize,crossChannel,axisMin,axisMax,logScale
		wave /z/sdfr=instanceDF marker,msize
		string color,axisName="Axis_"+num2str(plotNum),axisTName="Time_Axis"
	     	variable appended=0
	      	for(i=0;i<numChannels;i+=1)
	               for(j=0;j<numChannels;j+=1)
	                       if(!IsChanAnalysisMethod(j,analysisMethod)) // Not selected for this channel
	                       	continue
	                       endif
	                      
	                       if(crossChannel==0)
	                       	if(i!=j)
	                       		continue
	                       	else
	                       		Variable layer=0
	                       	endif
	                       else
	                       	layer=i
	                       	ControlInfo /W=SweepsWin $("Synapse_"+num2str(i)+"_"+num2str(j))
	                       	if(!V_Value)
	                       		continue
	                       	endif
	                       endif
	                       variable red,green,blue
	                       GetChanColor(j,red,green,blue)
	                       string measurementName=CleanupName(analysisMethod,0)
	                       dfref postChanDF=GetChanDF(j)        
	                       wave /z/sdfr=postChanDF measurementWave=$measurementName
	                       if(!waveexists(measurementWave))
	                       	Make /o/n=(currSweep+1,2,numChannels) postChanDF:$measurementName /wave=measurementWave=NaN
	                       endif
	                       variable col
	                       for(col=0;col<2;col+=1)
	                       	string traceName
	                       	sprintf traceName,"%s_col%d_lyr%d",measurementName,col,layer
	                       	if(mod(plotNum,2)==0)
	                       		AppendToGraph /W=AnalysisWin /L=$axisName /B=$axisTName /c=(red,green,blue) MeasurementWave[][col][layer] /tn=$traceName vs root:SweepT
	                       	else
	                       		AppendToGraph /W=AnalysisWin /R=$axisName /B=$axisTName /c=(red,green,blue) MeasurementWave[][col][layer] /tn=$traceName vs root:SweepT
	                       	endif
	                       	variable n_traces = itemsinlist(tracenamelist("AnalysisWin",";",1))
	                       	variable top_trace_num = n_traces - 1
	                       	ModifyGraph /Z /W=AnalysisWin marker[top_trace_num]=marker[col] ? marker[col] : 19-col*11
	                       	ModifyGraph /Z /W=AnalysisWin msize[top_trace_num]=(WaveExists(msize) && msize[col]) ? msize[col] : 3
	                       endfor
	                       appended+=1
	               endfor
	      	endfor
	      	AxisIndex[k]=plotNum
	      	if(!appended) // Selected for plotting, but no data to plot.  
	      		 	if(mod(plotNum,2)==0)
	      		 		NewFreeAxis /W=AnalysisWin /L $axisName
	            else
	              NewFreeAxis /W=AnalysisWin /R $axisName
	      			endif
	      	endif
	      	axisSize=(axisSize>0) ? axisSize : 1
					axisSizeTotal+=axisSize
					axisSizeStr=ReplaceNumberByKey(axisName,axisSizeStr,axisSize)
	      	if(axisMin==axisMax)
	      		SetAxis /A/Z /W=AnalysisWin  $axisName
	      	else
	      		SetAxis /Z/W=AnalysisWin $axisName axisMin,axisMax;
	      	endif
	      	ModifyGraph /Z/W=AnalysisWin  log($axisName)=logScale 
	      	variable fsize=GetFontSize()
	      	variable lblpos=GetAxisLabelPos()
	      	ModifyGraph /Z /W=AnalysisWin lblPos($axisName)=100,fSize($axisName)=fsize
					ModifyGraph /Z /W=AnalysisWin freePos($axisName)={axisPaddingLeft,kwFraction}, lblPos($axisName)=lblpos
					ModifyGraph /Z /W=AnalysisWin btLen($axisName)=1
					Label /Z /W=AnalysisWin $axisName analysisMethod
					String enab_info=GetAxisEnab(axisName,win="AnalysisWin")
	      	AnalysisMethodSubSelections(plotNum)
	      	plotNum+=1
	endfor
	
	String axisBottomCoords="",axisTopCoords=""
	for(i=0;i<numPlots;i+=1)
		axisName="Axis_"+num2str(i)
		Variable axisSize_=NumberByKey(axisName,axisSizeStr)
		Variable axisPadding=0.03
		Variable axisBottomCoord=axisSizeSoFar/axisSizeTotal+(i>0)*axisPadding
		Variable axisTopCoord=(axisSizeSoFar+axisSize_)/axisSizeTotal
		j=0
		Do
			axisBottomCoord-=j
			j+=0.01
		While(axisBottomCoord>=axisTopCoord)
		ModifyGraph /Z /W=AnalysisWin axisEnab($axisName)={axisBottomCoord,axisTopCoord}
		
		axisSizeSoFar+=axisSize_
		axisBottomCoords+=num2str(axisBottomCoord)+";"
		axisTopCoords+=num2str(axisTopCoord)+";"
	endfor
	
	// Draw dividing lines betwween the plots (axes).  
	for(i=0;i<numPlots-1;i+=1)
		axisBottomCoord=str2num(StringFromList(i+1,axisBottomCoords))
		axisTopCoord=str2num(StringFromList(i,axisTopCoords))
		Variable lineCoord=1-(axisBottomCoord+axisTopCoord)/2
	  SetDrawEnv xcoord=prel,ycoord=prel
	  DrawLine /W=AnalysisWin axisPaddingLeft,lineCoord,1-axisPaddingLeft,lineCoord 
	endfor
	
  SetAxis /Z /W=AnalysisWin Time_axis 0,30
  ModifyGraph /Z /W=AnalysisWin mode=3
  ModifyGraph /Z /W=AnalysisWin fSize=fsize, btLen=2
  ModifyGraph /Z /W=AnalysisWin freePos(Time_axis)=0,axisEnab(Time_axis)={axisPaddingLeft,1-axisPaddingLeft},lblpos(Time_axis)=100
  Label /Z /W=AnalysisWin Time_axis "Time (min)"

  Cursors(win="AnalysisWin")
  variable A = GetCursorSweepNum("A")
  variable B = GetCursorSweepNum("B")
  string A_trace = CsrWave(A,"AnalysisWin",1)
  string B_trace = CsrWave(B,"AnalysisWin",1)
  if(strlen(A_trace))
		Cursor /W=AnalysisWin A, $A_trace, A
		if(strlen(B_trace))
			Cursor /W=AnalysisWin B, $B_trace, B
		else
			Cursor /W=AnalysisWin B, $A_trace, B
  	endif
  endif
       
  // What does this do?  
	for(i=0;i<ItemsInList(analysisMethods);i+=1)
		analysisMethod=StringFromList(i,analysisMethods)
	 	if(StringMatch(analysisMethod,lastMethod))
    	Variable axisNum=AxisIndex[i]
      if(numtype(axisNum)==0)
       	break
      endif
    endif
  endfor
  
  AnalysisMethodListBoxUpdate()
  AnalysisMethodSubSelections(axisNum)  
  DrugTags()
  SetWindow $win hook(mainHook)=AnalysisWinHook
	struct wmwinhookstruct info
	info.eventName="resize"
	AnalysisWinHook(info)
End

Function AnalysisWinSetVariables(info)
	Struct WMSetVariableAction &info
	
	if(!SVInput(info.eventCode))
		return 0
	endif
	String name=StringFromList(0,info.ctrlName,"_")
	String index=StringFromList(1,info.ctrlName,"_")
	strswitch(name)
		case "SweepNum":
			MoveCursor(index,info.dval)
			break
		case "Parameter":
			string analysisMethod=SelectedMethod()
			Core#SetWavPackageSetting(module,"analysisMethods",analysisMethod,"Parameter",{info.dval},sub="analysisWin")
			break
	endswitch
End

Function AnalysisWinPopupMenus(info)
	Struct WMPopupAction &info
	
	if(!PopupInput(info.eventCode))
		return 0
	endif
	dfref analysisWinDF=Core#InstanceHome(module,"analysisWin","win0")
	variable i
	strswitch(info.ctrlName)
		case "Minimum":
			wave /sdfr=analysisWinDF selWave
			wave /t/sdfr=analysisWinDF listWave
			for(i=0;i<dimsize(SelWave,0);i+=1)
				if(SelWave[i][0] & 1) // If this method is selected.  
					break
				endif
			endfor
			Variable var=info.popNum-1
			String analysisMethod=SelectedMethod()
			variable numChannels=GetNumChannels()
			dfref instanceAnalysisWinDF=Core#InstanceHome(module,"analysisMethods",analysisMethod,sub="analysisWin",create=1)
			make /o/n=(numChannels) instanceAnalysisWinDF:Minimum /WAVE=Minimum
			duplicate /free Minimum OldMinimum
			OldMinimum=numtype(OldMinimum) ? 0.5 : OldMinimum // Deal with NaNs.  
			for(i=0;i<numChannels;i+=1)
				Minimum[i]=(var & 2^i)>0
			endfor
			OldMinimum-=Minimum
			Wave /T Labels=GetChanLabels()
			String text=""
			for(i=0;i<numpnts(OldMinimum);i+=1)
				String minimumStr=""
				if(OldMinimum[i]<0)
					minimumStr="minimum"
				elseif(OldMinimum[i]>0)
					minimumStr="maximum"
				endif
				if(strlen(minimumStr))
					text+="Began analyzing "+minimumStr+" on channel "+Labels[i]+" for method "+analysisMethod+"\r"
				endif
			endfor
			if(strlen(text))
				nvar /sdfr=GetStatusDF() expStartT,currSweep
				Variable time_since_start=(currSweep>0) ? datetime - expStartT : 0
				
				text="After sweep "+num2str(currSweep)+" ("+Secs2MinsAndSecs(time_since_start)+"): \r"+text
				if(wintype("LogPanel#ExperimentLog"))
					Notebook LogPanel#ExperimentLog text=text
				endif
			endif
			KillWaves /Z OldMinimum
			break
		case "Trend":
			string method=info.popStr
			string options=""
			strswitch(method)
				case "Decimation":
				case "Loess":
					variable neighbors=5
					prompt neighbors,"Enter a "+method+" factor:"
					doprompt "Trend Settings",neighbors
					if (V_Flag)
						return -1								// User canceled
					endif
					options="neighbors:"+num2str(neighbors)
					break
			endswitch
			TrendRegion(method,options)
			break
	endswitch
End

Function AnalysisMethodListBoxUpdate()
	String currFolder=GetDataFolder(1)
	dfref df=Core#InstanceHome(module,"analysisWin","win0")
	variable i=0,j
	variable numChannels=GetNumChannels()
	String analysisMethods=Core#ListPackageInstances(module,"analysisMethods")
	Variable numMethods=ItemsInList(analysisMethods)
	
	Make /o/T/n=(numMethods,numChannels+2) df:ListWave /wave=ListWave=""
	Make /o/n=(numMethods,numChannels+2) df:SelWave /wave=SelWave =32
	Make /o/n=(numMethods,numChannels) df:Parameter /wave=Parameter=NaN
	Make /o/n=(numMethods) df:AxisIndex /wave=AxisIndex, df:Minimum /wave=Minimum
	Make /o/T/n=(numChannels+2) df:Titles /wave=Titles
	for(i=0;i<numChannels;i+=1)
		Variable red,green,blue; String titleStr
		GetChanColor(i,red,green,blue)
		sprintf titleStr,"\K(%d,%d,%d)%s",red,green,blue,GetChanLabel(i)
		Titles[i]=titleStr
	endfor
	
	Titles[numChannels]="All"
	Titles[numChannels+1]="Show"
	sVar /z/sdfr=df methodSelected=selected
	i=0
	do
		String analysisMethod=StringFromList(i,analysisMethods)
		dfref instanceDF=Core#InstanceHome(module,"analysisMethods",analysisMethod)
		if(datafolderrefstatus(instanceDF))
			variable active=Core#VarPackageSetting(module,"analysisMethods",analysisMethod,"active",default_=1)
			if(!active)
				deletepoints i,1,ListWave,SelWave,Parameter,AxisIndex,Minimum
			else
				ListWave[i][numChannels]=analysisMethod
				variable numChannelsWithMethod=0
				for(j=0;j<numChannels;j+=1)
					wave /t chanAnalysisMethods=Core#WavTPackageSetting(module,"channelConfigs",GetChanName(j),"analysisMethods")
					findvalue /text=analysisMethod /txop=4 chanAnalysisMethods
					if(v_value>=0 && strlen(analysisMethod))
						SelWave[i][j]+=16
						numChannelsWithMethod+=1
					endif
				endfor
				SelWave[i][numChannels]=32+16*(numChannelsWithMethod==numChannels) // Set "All" box.  
				//AxisIndex[i]=i
				Minimum[i]=0
				Parameter[i]=0
				nvar /z/sdfr=instanceDF show
				if(NVar_Exists(show) && show) 
					SelWave[i][numChannels+1]=SelWave[p][q] | 16 // Check the box for "Show".  
				else
					SelWave[i][numChannels+1]=SelWave[p][q] & ~16 // Uncheck the box for "Show".  
				endif
				//extract /free Active,TempActive,p<numChannels
				//SelWave[i][numChannels]=32+16*(sum(TempActive)==numChannels)
				if(SVar_Exists(methodSelected) && StringMatch(analysisMethod,methodSelected))
					SelWave[i][] = SelWave | 1 // Set to selected.
				else
					SelWave[i][] = SelWave & ~1 // Set to unselected.
				endif
			endif
			i+=1
		endif
	while(i<dimsize(ListWave,0))
	return 0
End

Function AnalysisWinListBoxes(info)
	struct WMListBoxAction &info
	
	if(info.eventCode==2)
		wave /T ListWave=info.listWave
		wave SelWave=info.selWave
	
		variable numChannels=GetNumChannels()
		string analysisMethod=ListWave[info.row][dimsize(ListWave,1)-2]
		//wave Active=WavPackageSetting(module,"analysisMethods",instance,"Active")
		variable checked=selWave[info.row][info.col] & 16
		if(info.col<numChannels)
			string chanName=GetChanName(info.col)
			wave /t chanAnalysisMethods=Core#WavTPackageSetting(module,"channelConfigs",chanName,"analysisMethods")
			FindValue /TEXT=analysisMethod /TXOP=4 chanAnalysisMethods
			if(v_value>=0 && !checked && strlen(analysisMethod))
				deletepoints v_value,1,chanAnalysisMethods
			elseif(v_value<0 && checked && strlen(analysisMethod))
				chanAnalysisMethods[numpnts(chanAnalysisMethods)]={analysisMethod}
			endif
			variable i=0
			do // Cleanup.  
				if(!strlen(chanAnalysisMethods[i]) || stringmatch(chanAnalysisMethods[i]," "))
					deletepoints i,1,chanAnalysisMethods
				else
					i+=1
				endif
			while(i<numpnts(chanAnalysisMethods))
			if(!numpnts(chanAnalysisMethods))
				chanAnalysisMethods[0]={" "}
			endif
			//Active[info.col]=checked>0
		elseif(info.col==numChannels) // All was checked or unchecked.  
			//Active=checked>0
			for(i=0;i<info.col;i+=1)
				struct WMListBoxAction info2
				info2=info
				info2.col=i
				if(checked) // If all is checked.  
					selWave[info.row][i]=selWave[info.row][i] | 16 // Set channel checked.  
				else // If all is unchecked.  
					selWave[info.row][i]=selWave[info.row][i] & ~16 // Set channel unchecked.  
				endif
				AnalysisWinListBoxes(info2)
			endfor
			info.selWave[info.row][0,info.col-1]=32+checked
		elseif(info.col==numChannels+1) // Show was checked or unchecked.  
			Core#SetVarPackageSetting(module,"analysisMethods",analysisMethod,"show",checked>0)
		endif
	endif
End

Function AnalysisSelector(flag)
	Variable flag
	
	dfref analysisWin=Core#InstanceHome(module,"analysisWin","win0")
	variable numChannels=GetNumChannels()
	Wave /T Labels=GetChanLabels()
	Make /o/T/n=(numChannels+2) analysisWin:Titles /wave=Titles
	Variable i,j
	for(i=0;i<numChannels;i+=1)
		Variable red,green,blue; String titleStr
		GetChanColor(i,red,green,blue)
		sprintf titleStr,"\K(%d,%d,%d)%s",red,green,blue,Labels[i]
		Titles[i]=titleStr
	endfor
	Titles[numChannels]="All"
	Titles[numChannels+1]="Show"
	Wave /t/sdfr=analysisWin listWave,Titles
	Wave /sdfr=analysisWin selWave,axisIndex
	
	if(flag)
		KillControl AnalysisSelector
		struct rect coords
		Core#GetWinCoords("AnalysisWin",coords)
		string axisCoords=GetAxes(graph="AnalysisWin")
		duplicate /free axisIndex oldAxisIndex
		KillWindow AnalysisWin
		AnalysisWindow()
		MoveWindow /W=AnalysisWin coords.left,coords.top,coords.right,coords.bottom
		for(i=0;i<numpnts(axisIndex);i+=1)
			if(oldAxisIndex[i]==axisIndex[i] && numtype(axisIndex[i])==0) // If old and new axis correspond to the same measurement.  
				string axisCoord = stringfromlist(axisIndex[i],axisCoords)
				SetAxes(axisCoord,graph="AnalysisWin")
			endif
		endfor
	else
		AnalysisMethodListBoxUpdate()
		ControlInfo AnalysisSelect
		variable fsize=GetFontSize()
		Button EditAnalysisMethods pos={V_left,25}, proc=AnalysisWinButtons, size={100,25}, title="Edit Methods", win=AnalysisWin
		ListBox AnalysisSelector listWave=ListWave, selWave=SelWave, pos={V_left,50}, mode=4, titleWave=Titles, win=AnalysisWin
		i=0
		Variable widthSoFar=0
		Do
			Variable width=2*FontSizeStringWidth("default",9,0,Labels[0])
			Listbox AnalysisSelector widths+={width}, win=AnalysisWin
			widthSoFar+=width
			i+=1
		While(i<numChannels)
		string analysisMethods=Core#ListPackageInstances(module,"analysisMethods")
		width=30+WidestString(analysisMethods,"Default",fsize,0); widthSoFar+=width
		Listbox AnalysisSelector widths+={width}, win=AnalysisWin
		width=35; widthSoFar+=width// For "Show"
		Listbox AnalysisSelector widths+={width}, win=AnalysisWin
		Listbox AnalysisSelector proc=AnalysisWinListBoxes, size={40+widthSoFar,max(100,20+20*dimsize(ListWave,0))}, win=AnalysisWin
	endif
End

// The window that plots the region right after stimulation, as well as the stimulus artifact (sodium current), and the beginning of the test pulse.  
Function SweepsWindow([instance])
	string instance
	
	instance = selectstring(!paramisdefault(instance),"_default_",instance)
	string win = "sweepsWin"
	string package = win
	Core#CopyInstance(module,package,instance,"win0")
	DoWindow /K $win
	SetDataFolder root:
	Struct rect coords
	variable use_default_coords = 1
	if(!paramisdefault(instance) && Core#InstanceExists(module,package,instance))
		coords.left = Core#VarPackageSetting(module,package,instance,"left",sub="position")
  	coords.top = Core#VarPackageSetting(module,package,instance,"top",sub="position")
  	coords.right = Core#VarPackageSetting(module,package,instance,"right",sub="position")
  	coords.bottom = Core#VarPackageSetting(module,package,instance,"bottom",sub="position")
		if(coords.right > 10 && coords.bottom > 10) // Sane coordinates.  
			use_default_coords = 0  
  	endif
  endif
  if(use_default_coords)
  	IgorWinCoords(coords)
		coords.left+=1
  	coords.right-=1
  	coords.bottom=(coords.bottom-coords.top)*0.6-1
  endif
  	
  variable fsize=GetFontSize()
	Display /N=$win /W=(coords.left,coords.top,coords.right,coords.bottom) /K=2 as "Sweeps"
	Button SetBaselineRegion,pos={575,3},size={75,23},fsize=fsize+1, proc=SweepsWinButtons,title="Set Baseline"
	Checkbox AutoBaseline,pos={655,4},title="Auto"
	string default_view=Core#StrPackageSetting(module,"random","","defaultView",default_="Broad")
	Checkbox SwitchView, pos={655,21},size={100,29},proc=SweepsWinCheckboxes,title="Focus",userData=default_view
	Button ResetSweepAxes,pos={575,20},size={75,23},fsize=fsize+1,proc=SweepsWinButtons,title="Restore Axes"
	PopupMenu SweepOverlay,pos={655,20},title="Sweep Overlay",mode=0,value=#("PopupOptions(\""+win+"\",\"SweepOverlay\",\"Stack;By Mode;Split\")"),userData(selected)="Split",proc=SweepsWinPopupMenus
	PopupMenu PulseOverlay,pos={755,20},title="Pulse Overlay",mode=0,value=#("PopupOptions(\""+win+"\",\"PulseOverlay\",\"None;Stacked\")"),userData(selected)="None",proc=SweepsWinPopupMenus
	//Button SaveWin, pos={725,3},size={75,15},proc=SweepsWinButtons,title="Save Window"
	//Button LoadWin, pos={725,20},size={75,15},proc=SweepsWinButtons,title="Load Window"
	
	variable numChannels=GetNumChannels()
	ControlBar /T max(3,numChannels)*18+3 
	Checkbox SweepShow_A,pos={488,1}, title=" ",value=0,proc=SweepsWinCheckboxes
	Checkbox SweepShow_B,pos={488,18},title=" ",value=0,proc=SweepsWinCheckboxes
	SetVariable SweepNum_A,pos={504,1},title="A",value=root:status:cursorSweepNum_A,proc=SweepsWinSetVariables,limits={0,inf,1}
	SetVariable SweepNum_B,pos={504,18},title="B",value=root:status:cursorSweepNum_B,proc=SweepsWinSetVariables,limits={0,inf,1}
	Checkbox Range,pos={405,1}, title="Range",value=0,disable=0,proc=SweepsWinCheckboxes
	Checkbox LastSweep,pos={405,18},title="Last Sweep",value=1,proc=SweepsWinCheckboxes
	SetVariable Inc,pos={504,35},title="Inc",value=_NUM:1, limits={1,Inf,1},disable=1,proc=SweepsWinSetVariables
	DoUpdate; GetWindow $win,wsizeDC
	
	//Button RemoveAllTraces pos={V_right-284,5}, size={100,29}, title="Remove Traces", proc=RemoveTracesWrap
	Button WaveSelector,pos={V_right-303,5},size={100,22},fsize=fsize+2,proc=SweepsWinButtons,title="Selector"
	Button Logger,pos={V_right-101,5},size={100,22},fsize=fsize+2,proc=SweepsWinButtons,title="Log"
	//Textbox/N=Recording/F=0/X=7/Y=1 "\\Z08Waiting..."
	//NVar testPulsestart=root:parameters:testPulsestart
	//Variable stim_point_start,test_point_start
	variable i,j,numBoxes=0
	for(i=0;i<numChannels;i+=1)
		String pre=num2str(i)
		Checkbox $("Show_"+num2str(i)), value=1
		for(j=0;j<numChannels;j+=1)
			String post=num2str(j)
			Checkbox $("Synapse_"+num2str(i)+"_"+num2str(j)), value=1
			numBoxes+=1
		endfor
	endfor
	Textbox/A=LT/N=TimeStamp/F=0/V=1/X=25/Y=1
	SweepsWinTextBoxUpdate()
	//WaveSelector();DoWindow /B Selector
	WaveUpdate()
	SweepsChooserUpdate()
	SwitchView(default_view) // Set broad or focused (check user data for SwitchView button)	
	ResetSweepAxes(default_view)
	SweepsWinControlsUpdate()
	SetWindow $win hook(mainHook)=SweepsWinHook
	struct wmwinhookstruct info
	info.eventName="resize"
	SweepsWinHook(info)
	//KillVariables /Z red,green,blue
End

Function SweepsWinButtons(info) : ButtonControl
	struct WMButtonAction &info
	
	switch(info.eventCode)
		case 1:
			if(info.eventMod & 16)
				PopupContextualMenu /N "DAQ Instance"
			endif
			break
		case 2:
			string win=info.win
			dfref df = Core#InstanceHome(module,"SweepsWin","win0")
			strswitch(info.ctrlName)
				case "WaveSelector":
					string daqInstance = Core#GetSelectedInstance(module,"DAQs",noDefault=1)
					if(!strlen(daqInstance))
						string acqInstance = Core#GetSelectedInstance(module,"Acq")
						wave /t daqs = Core#WavTPackageSetting(module,"Acq",acqInstance,"DAQs")
						daqInstance=daqs[0]
					endif
					WaveSelector(instance=daqInstance)
					break
				case "Logger":
					MakeLogPanel()
					break
				case "ChooseSweeps":
					ControlInfo SweepChooser
					if(v_flag!=11) // No SweepChooser.  
						variable numChannels = GetNumChannels()
						variable hasAllColumn = numChannels >= 1
						ListBox SweepChooser listWave=df:ListWave, selWave=df:SelWave, pos={385,55}, size={40+40*(numChannels+hasAllColumn+1),250}, widths={4,3}, mode=4
						ListBox SweepChooser titleWave=df:Titles, win=SweepsWin, proc=SweepsWinListBoxes
					else
						KillControl SweepChooser
					endif
					break
				case "Export":
					dfref df=Core#InstanceHome(module,"sweepsWin","win0")
					wave /sdfr=df SelWave
					variable first = GetCursorSweepNum("A")
					variable last = GetCursorSweepNum("B")
					if(CursorExists("A") && CursorExists("B"))
						variable start = xcsr(A)
						variable finish = xcsr(B)
					else
						start = 0
						finish = Inf
					endif
					variable i,j,k,num_channels = GetNumChannels()
					for(i=0;i<num_channels;i+=1)
						if(StringMatch(Chan2ADC(i),"N")) // If input data is not being collected on this channel.  
							continue // Skip it.  
						endif
						dfref chanDF = GetChanDF(i)
						string export_loc = getdatafolder(1,chanDF)+"export"
						ControlInfo /W=SweepsWin Inc; variable inc=V_Value
						variable made_export = 0
						if(!numtype(first) && !numtype(last))
							for(k=min(first,last);k<=max(first,last);k+=inc)
								if(SelWave[k][i+1] & 16)
									wave sweep = GetChanSweep(i,k)
									if(!made_export)
										finish = min(finish,rightx(sweep))
										duplicate /o/r=(start,finish) sweep, $export_loc /wave=export
										redimension /n=(-1,1) export
										made_export = 1
									else
										wave /z export = $export_loc
										redimension /n=(-1,dimsize(export,1)+1) export
										duplicate /free/r=(start,finish) sweep,piece
										export[][dimsize(export,1)-1] = piece[p]
									endif
									SetDimLabel 1,dimsize(export,1)-1,$GetSweepName(k),export 
								endif
							endfor
							for(j=0;j<dimsize(export,0);j+=1)
								SetDimLabel 0,j,$num2str(start+j*deltax(sweep)),export 
							endfor
							dowindow /k $getdatafolder(0,chanDF)
							edit /k=1/n=$getdatafolder(0,chanDF) export.ld
						endif
					endfor
					break
				case "SetBaselineRegion":
					if(CursorExists("A") && CursorExists("B"))
						String trace=CsrWave(A)
						Variable chan
						sscanf trace,"input_%d",chan
						string acqMode=GetAcqMode(chan)
						// Set the baseline for this method.  
						String analysisMethod=SelectedMethod()
						if(strlen(analysisMethod))
							Core#SetVarPackageSetting(module,"analysisMethods",analysisMethod,"baselineLeft",xcsr(a),create=1)
							Core#SetVarPackageSetting(module,"analysisMethods",analysisMethod,"baselineRight",xcsr(b),create=1)
						endif
						// Set the baseline for this mode, which will only be used in cases where a method baseline cannot be found.  
						if(!exists(Core#PackageSettingLoc(module,"acqModes",acqMode,"baselineLeft",quiet=1)))
							AcqModeDefaults(acqMode)
						endif
						Core#SetVarPackageSetting(module,"acqModes",acqMode,"baselineLeft",xcsr(a))
						Core#SetVarPackageSetting(module,"acqModes",acqMode,"baselineRight",xcsr(b))
						SwitchView("")
					else
						DoAlert 0,"You must place cursors on the graph to set the baseline region."
						break
					endif
					break
				case "ResetSweepAxes":
					ResetSweepAxes("")
					break
				case "SaveWin":
					Core#SetStrPackageSetting(module,win,"","recMacro",WinRecreation(win,0))
					Core#SavePackage(module,win)
					break
				case "LoadWin":
					DoWindow /K $win
					Core#ExecuteProfileMacro(module,win,"",1)
					break
			endswitch
			break
	endswitch
End

function SweepsWinListboxes(info)
	struct WMListboxAction &info
	
	if(info.eventCode==2)
		wave selWave = info.selWave
		variable i,numChannels = GetNumChannels()
		if(info.col==(numChannels+1)) // All was checked or unchecked.  
			variable checked=selWave[info.row][info.col] & 16
			for(i=1;i<info.col;i+=1)
				struct WMListBoxAction info2
				info2=info
				info2.col=i
				info2.userData = "noSwitchView"
				if(checked) // If all is checked.  
					selWave[info.row][i]=selWave[info.row][i] | 16 // Set channel checked.  
				else // If all is unchecked.  
					selWave[info.row][i]=selWave[info.row][i] & ~16 // Set channel unchecked.  
				endif
				SweepsWinListBoxes(info2)
			endfor
			info.selWave[info.row][1,info.col-1] = 32+checked
		endif
		if(!stringmatch(info.userData,"noSwitchView"))
			SwitchView("")
		endif
	endif
end

function SweepsChooserUpdate([matrix])
	wave matrix
	
	String currFolder=GetDataFolder(1)
	dfref df=Core#InstanceHome(module,"sweepsWin","win0")
	variable i,j
	variable numChannels = GetNumChannels()
	variable numSweeps = GetCurrSweep()
	variable hasAllColumn = numChannels > 1
	
	Make /o/T/n=(numSweeps,numChannels+1+hasAllColumn) df:ListWave /wave=ListWave= selectstring(q==0,"","Sweep "+num2str(p)) // Sweep numbers for column 0.  
	Make /o/n=(numSweeps,numChannels+1+hasAllColumn) df:SelWave /wave=SelWave = q==0 ? 0 : 48 // Check boxes for column >= 1.
	SelWave[][1,numChannels] *= ChanSweepExists(q-1,p) // Remove checkbox if sweep does not exist for the channel.  
	if(!paramisdefault(matrix))
		SelWave[][1,] = 32+16*matrix[p][q]
		SelWave[][1,numChannels-1] = SelWave[p][1]
	endif
	Make /o/T/n=(numChannels+1+hasAllColumn) df:Titles /wave=Titles
	for(i=0;i<numChannels;i+=1)
		Variable red,green,blue; String titleStr
		GetChanColor(i,red,green,blue)
		sprintf titleStr,"\K(%d,%d,%d)%s",red,green,blue,GetChanLabel(i)
		Titles[i+1]=titleStr
	endfor
	
	Titles[0] = " " // Sweep number column title.  
	if(hasAllColumn)
		Titles[numChannels+1] = "All"
	endif
	//for(i=0;i<numSweeps;i+=1)
	//endfor
	return 0
End

end

Function SweepsWinPopupMenus(info)
	Struct WMPopupAction &info
	
	if(!PopupInput(info.eventCode))
		return 0
	endif
	String name=StringFromList(0,info.ctrlName,"_")
	String index=StringFromList(1,info.ctrlName,"_")
	strswitch(name)
		case "SweepOverlay":
		case "PulseOverlay":
			PopupMenu $info.ctrlName userData(selected)=info.popStr, win=SweepsWin
			SwitchView("")
			break
	endswitch
End

Function SweepsWinSetVariables(info)
	Struct WMSetVariableAction &info
	
	if(!SVInput(info.eventCode))
		return 0
	endif
	String name=StringFromList(0,info.ctrlName,"_")
	String index=StringFromList(1,info.ctrlName,"_")
	strswitch(name)
		case "SweepNum":
			MoveCursor(index,info.dval)
			break
		case "Inc":
			SwitchView("")
			break
	endswitch
End

//Function /S MinimumPossibilities()
//	Variable i,j
//	Wave /T Labels=root:parameters:Labels
//	Wave SelWave=root:parameters:analysisWin:SelWave
//	for(i=0;i<dimsize(SelWave,0);i+=1)
//		if(SelWave[i][0] & 1) // If this analysis method is selected.  
//			break
//		endif
//	endfor
//	Wave Minimum=root:parameters:analysisWin:Minimum
//	NVar numChannels=root:parameters:numChannels
//	String possibilities=""
//	for(j=0;j<numChannels;j+=1)
//		 if(Minimum[i] & 2^j)
//		 	possibilities+=Labels[j]+" Minimum;"
//		 else
//		 	possibilities+=Labels[j]+" Maximum;"
//		 else
//		 endif
//	endfor
//	return possibilities
//End

function /s GetSweepsWinView()
	string view=""
	ControlInfo /W=SweepsWin SwitchView   
	if(v_flag>0)
		view=S_userdata
	endif
	return view
end

// Returns the number of the selected (bold axis).  
Function SelectedAxis()
	String axes=AxisList("AnalysisWin")
	Variable i
	for(i=0;i<ItemsInList(axes);i+=1)
		String axis=StringFromList(i,axes)
		String axis_info=AxisInfo("AnalysisWin",axis)
		Variable thickness=NumberByKey("axThick(x)",axis_info,"=")
		if(thickness==2)
			Variable axisNum
			sscanf axis,"Axis_%d",axisNum
			return axisNum
		endif
	endfor
	return -1
End

function GetFontSize()
	return Core#VarPackageSetting(module,"random","","fsize",default_=9)
end

function GetAxisLabelPos()
	return Core#VarPackageSetting(module,"random","","lblpos",default_=35)
end

Function ResetSweepAxes(mode)
	String mode
	
	if(StringMatch(mode,"SwitchView"))
		mode=GetUserData("SweepsWin","SwitchView","")
	endif
	if(WhichListItem(mode,"Broad;Focused;SwitchView")<0)
		ControlInfo /W=SweepsWin SwitchView
		mode=S_userdata
	endif
	//ModifyGraph /Z/W=SweepsWin axisEnab(VC_axis)={0.01,0.98},axisEnab(CC_axis)={0.01,0.98}
	variable fsize=GetFontSize()
	variable lblpos=GetAxisLabelPos()      
	ModifyGraph /Z/W=SweepsWin marker=3, fSize=fsize,btLen=2
	Label /Z/W=SweepsWin time_axis SelectString(StringMatch(mode,"Focused"),"s","ms")
	ControlInfo /W=SweepsWin SweepOverlay
	string sweepOverlay=""
	if(v_flag>0)
		sweepOverlay=ClearBrackets(S_Value)
	endif
	
	String acqModes=Core#ListPackageInstances(module,"acqModes")
	String axes=AxisList("SweepsWin")
	Variable i,j,verticalAxes=0
	for(i=0;i<ItemsInList(axes);i+=1)
		String axis=StringFromList(i,axes)
		String axisPrefix=StringFromList(0,axis,"_")
		if(WhichListItem(axisPrefix,acqModes)>=0)
			string inputUnits=GetModeInputUnits(axisPrefix)
			Label /Z/W=SweepsWin $axis inputUnits
		endif
		String axis_info=AxisInfo("SweepsWin",axis)
		String axisType=StringByKey("AXTYPE",axis_info)
		if((StringMatch(axisType,"left") || StringMatch(axisType,"right")) && !StringMatch(axis,"TestPulse*") && !StringMatch(axis,"StimMag*"))
			verticalAxes+=1
		endif
	endfor
	Label /Z/W=SweepsWin stimTime_axis " "
	Label /Z/W=SweepsWin testPulsetime_axis " "
	
	// Reset range for each axis.  
	string axis_list=AxisList("SweepsWin")
	for(i=0;i<ItemsInList(axis_list);i+=1)
		axis=StringFromList(i,axis_list)
		string acqMode=RemoveEnding(axis,"_axis")
		string ending=acqMode[strlen(acqMode)-1]
		if(numtype(str2num(ending))==0) // If the axis name ends with a number.  
			acqMode=removeending(acqMode,"_"+ending) // Remove the number.  
		endif
		strswitch(acqMode)
			case "time":
				break
			default:
				if(Core#InstanceExists(module,"acqModes",acqMode))
					string units=GetModeInputUnits(acqMode)
				else
					units=""
				endif
				strswitch(units)
					case "pA":
						SetAxis /Z/W=SweepsWin $axis -500,50
						break
					case "mV":
						SetAxis /Z/W=SweepsWin $axis -80,40
						break
					default:
						SetAxis /A/Z/W=SweepsWin $axis
						break
				endswitch
				break
		endswitch
	endfor
	
	SetDrawLayer /W=SweepsWin /K UserFront
	strswitch(mode)
		case "Broad":
			Variable axisRight=0.98
			SetAxis/Z/W=SweepsWin /A time_axis
			ModifyGraph /Z/W=SweepsWin freePos(time_axis)={0,$TraceYAxis(TopTrace(win="SweepsWin"),win="SweepsWin")}
			ModifyGraph /Z/W=SweepsWin axisEnab(time_axis)={0.02,axisRight-0.005}
			//ModifyGraph /Z/W=SweepsWin axisEnab(stimmag_axis)={0.99,1}, axisEnab(testPulsemag_axis)={0.99,1}
			//ModifyGraph /Z/W=SweepsWin axisEnab(stimTime_axis)={0.99,1}, axisEnab(testPulsetime_axis)={0.99,1}
			Textbox /W=SweepsWin/C/N=TimeStamp /X=40
			//HideAxes(1,axes="testPulsemag_axis;testPulsetime_axis;stimmag_axis;stimTime_axis")
			//DoUpdate; GetAxis /Q time_axis
			SetAxis /Z/W=SweepsWin/A time_axis;
			break
		case "Focused":
			axisRight=0.67
			// Get the maximum IPI across all presynaptic channels that have sweeps shown.  
			Variable maxIPI=0
			variable numChannels=GetNumChannels()
			for(i=0;i<numChannels;i+=1)
				for(j=0;j<numChannels;j+=1)
					ControlInfo /W=SweepsWin $("Synapse_"+num2str(i)+"_"+num2str(j))
					if(V_flag>0 && V_Value)
						maxIPI=max(maxIPI,MaxStimParam("IPI",i)/1000)
					endif
				endfor
			endfor
			//maxIPI=(maxIPI==0) ? MaxStimParam("IPI",-1)/1000 : maxIPI
			
			SetAxis /Z/W=SweepsWin time_axis,-0.005,maxIPI+0.025
			SetAxis /Z/W=SweepsWin stimTime_axis,-0.001,0.005; SetAxis /Z/W=SweepsWin stimmag_axis,-2000,5000
			SetAxis /Z/W=SweepsWin testPulsetime_axis,-0.001,0.020; SetAxis /Z/W=SweepsWin testPulsemag_axis,-300,10
			ModifyGraph /Z/W=SweepsWin freePos(stimmag_axis)={0.02,kwFraction}, freePos(testPulsemag_axis)={0.02,kwFraction}
			ModifyGraph /Z/W=SweepsWin freePos(stimTime_axis)={0,stimmag_axis}, freePos(testPulsetime_axis)={0,testPulsemag_axis}
			String top_trace=TopTrace(win="SweepsWin",xaxis="Time_Axis",visible=1)
			ModifyGraph /Z/W=SweepsWin freePos(time_axis)={0,$TraceYAxis(top_trace,win="SweepsWin")}
			ModifyGraph /Z/W=SweepsWin tick(stimmag_axis)=2, tick(testPulsemag_axis)=2
			ModifyGraph /Z/W=SweepsWin nticks(testPulsetime_axis)=3
			ModifyGraph /Z/W=SweepsWin axisEnab(time_axis)={0.02,axisRight}
			ModifyGraph /Z/W=SweepsWin axisEnab(stimmag_axis)={0.52,1}, axisEnab(testPulsemag_axis)={0,0.48}
			ModifyGraph /Z/W=SweepsWin axisEnab(stimTime_axis)={0.71,0.98}, axisEnab(testPulsetime_axis)={0.71,0.98}
			ModifyGraph /Z/W=SweepsWin freePos(VC_axis)={-0.010,time_axis}, freePos(CC_axis)={0.15,time_axis}
			Textbox /W=SweepsWin/C/N=TimeStamp /X=25
			SetDrawEnv /W=SweepsWin xcoord=prel, ycoord=prel, dash=1
			DrawLine /W=SweepsWin axisRight+0.04,0.5,0.98-0.005,0.5
			break
	endswitch
	Variable axisCounter=0,traceCounter=0
	
	if(StringMatch(sweepOverlay,"Split"))
		DoUpdate // Update axis values for use in GetAxis command in SweepsWinVertAxisOffsets.  
	endif
	for(i=0;i<ItemsInList(axes);i+=1)
		axis=StringFromList(i,axes)
		axis_info=AxisInfo("SweepsWin",axis)
		axisType=StringByKey("AXTYPE",axis_info)
		if((StringMatch(axisType,"left") || StringMatch(axisType,"right")) && !StringMatch(axis,"TestPulse*") && !StringMatch(axis,"StimMag*"))
			if(StringMatch(axisType,"left"))
				Variable axisStart=0.02
			else
				axisStart=1-axisRight
			endif
			ModifyGraph /Z/W=SweepsWin freePos($axis)={axisStart,kwFraction},lblPos($axis)=30//mod(axisCounter,2) ? 50 : -5
			strswitch(sweepOverlay)
				case "Split":
					String traces=YAxisTraces(axis,win="SweepsWin")
					Variable numTraces=ItemsInList(traces)
					Variable low=axisCounter/verticalAxes
					Variable high=(axisCounter+1)/verticalAxes
					high=low+(high-low)/numTraces
					ModifyGraph /Z/W=SweepsWin axisEnab($axis)={low,high},axisClip($axis)=1
					SweepsWinVertAxisOffsets(axis)
					break
				case "By Mode":
					low=axisCounter/verticalAxes
					high=(axisCounter+1)/verticalAxes
					ModifyGraph /Z/W=SweepsWin axisEnab($axis)={low,high}
					break
				default: // Stack, or "", or anything else.  
					ModifyGraph /Z/W=SweepsWin axisEnab($axis)={0,1}
			endswitch
			if(low)
				SetDrawEnv /W=SweepsWin xcoord=prel, ycoord=prel, dash=1
				DrawLine /W=SweepsWin 0.02,low,axisRight-0.005,low
			endif
			axisCounter+=1
		endif
	endfor
End

Function SweepsWinVertAxisOffsets(axis)
	String axis
	
	//return 0 // Temporarily disable this function.  
	 
	String traces=YAxisTraces(axis,win="SweepsWin")
	Variable numTraces=ItemsInList(traces)
	GetAxis /Q/W=SweepsWin $axis
	//SetAxis /W=SweepsWin $axis v_min,v_max // Disable autoscaling to avoid positive feedback.  
	variable j
	for(j=0;j<numTraces;j+=1)
		String trace=StringFromList(j,traces)
		Variable x_offset=XOffset(trace,win="SweepsWin")
		Variable y_offset=0//YOffset(trace,win="SweepsWin")
		ModifyGraph /Z offset($trace)={x_offset,y_offset+j*(V_max-V_min)}
	endfor
End

function /s GetCurrSweepsView()
	return GetUserData("SweepsWin","SwitchView","")
end

// A window that show whole sweeps.  By default it shows the last sweep from each channel, and other
// sweeps can be shown, too.  
Function SwitchView(view)
	String view
	
	if(!WinType("SweepsWin"))
		return -1
	endif
	dfref df=Core#InstanceHome(module,"sweepsWin","win0")
	Variable i,j,k,sweepNum,pulse,appended=0

	variable numChannels=GetNumChannels()
	wave /T Labels=GetChanLabels()
	
	// Determine requested view and save current view.  
	string curr_view=GetCurrSweepsView()
	SaveCursors(curr_view,win="SweepsWin")
	SaveAxes(curr_view,win="SweepsWin")
	if(StringMatch(view,"SwitchView"))
		view=GetUserData("SweepsWin","SwitchView","")
		view=SelectString(StringMatch(view,"*Focused*"),"Focused","Broad") // If Broad, go to Focused; If Focused, go to Broad
	endif
	if(WhichListItem(view,"Focused;Broad;SwitchView")<0) // For all other cases, just restore the view according to the current settings
		ControlInfo /W=SweepsWin SwitchView
		view=S_userdata
	endif
	if(!strlen(view))
		view="Focused"
	endif
	Checkbox SwitchView win=SweepsWin, userData=view
	
	String acqModes=Core#ListPackageInstances(module,"acqModes")
	for(i=0;i<numChannels;i+=1)
		if(strlen(GetAcqMode(i))==0)
			string defaultAcqMode=stringFromList(0,acqModes)
			// Don't call SetAcqMode, because it calls SwitchView(), which causes recursion.  
			Core#SetStrPackageSetting(module,"channelConfigs",GetChanName(i),"acqMode",defaultAcqMode) // Fixing blanks in this wave if if there are any.  
		endif
	endfor
	variable currSweep=GetCurrSweep()
	
	// Remove the old traces
	ControlInfo /W=SweepsWin Range; Variable range=V_Value
	String traces_shown=TraceNameList("SweepsWin",";",3)
	string traces_to_remove=""
	wave /t chan_labels = GetChanLabels()
	for(i=0;i<itemsinlist(traces_shown);i+=1)
		string trace = stringfromlist(i,traces_shown)
		if(!range)
			traces_to_remove += trace+";"
		else
			for(j=0;j<numpnts(chan_labels);j+=1)
				if(grepstring(trace,chan_labels[j]+"_Sweep[0-9]+") || grepstring(trace,chan_labels[j]+"_Stim[0-9]+") || grepstring(trace,chan_labels[j]+"_TestPulse[0-9]+"))
					traces_to_remove += trace+";"
				endif
			endfor
		endif
	endfor
	string sweepsToRemove=SortList(traces_to_remove,";",16)
	for(i=ItemsInList(sweepsToRemove)-1;i>=0;i-=1)
		String sweep=StringFromList(i,sweepsToRemove)
		Wave RemovedWave=TraceNameToWaveRef("SweepsWin",sweep)
		RemoveFromGraph /W=SweepsWin $sweep
		if(StringMatch(sweep,"*_filt")) // If this is a filtered version of the original wave.  
			KillWaves /Z RemovedWave // Delete is since we have the original.  
		endif
	endfor
	
	wave /sdfr=df SelWave
	strswitch(view)
		case "Focused": 
			controlinfo /w=sweepsWin PulseOverlay
			variable pulsesStacked=v_flag>0 && stringmatch(ClearBrackets(s_value),"Stacked")
			variable first=GetCursorSweepNum("A")
			variable last=GetCursorSweepNum("B")
			// Append all the traces
			for(i=0;i<numChannels;i+=1)
				ControlInfo /W=SweepsWin $("Show_"+num2str(i)); Variable pre_active=V_Value
				if(StringMatch(Chan2DAC(i),"N") || !pre_active) // If there is not output on this channel.  
					continue // Skip it.  
				endif
				Variable red,green,blue
				GetChanColor(i,red,green,blue)
				ControlInfo /W=SweepsWin LastSweep; Variable lastSweep=V_Value
				
				// Existing sweeps (cursors A and B).  
				ControlInfo /W=SweepsWin Range; range=V_Value
				if(range) // Append all the sweeps in the range between the cursors.  
					ControlInfo /W=SweepsWin Inc; Variable inc=V_Value
					if(!numtype(first) && !numtype(last))
						for(sweepNum=min(first,last);sweepNum<=max(first,last);sweepNum+=inc)
							appended+=AppendAndOffsetSweep(-1,i,sweepNum,0,"TestPulse",0,red,green,blue,rightAxis=1)
							appended+=AppendAndOffsetSweep(i,-1,sweepNum,0,"Stim",0,red,green,blue,rightAxis=1)
						endfor
					endif
				else // Append only the sweeps indicated by the cursors.  
					for(k=0;k<2;k+=1)
						String curs=StringFromList(k,"A;B")
						ControlInfo /W=SweepsWin $("SweepShow_"+curs); Variable cursShow=V_Value
						variable cursorSweepNum=GetCursorSweepNum(curs)
						if(cursShow)
							appended+=AppendAndOffsetSweep(-1,i,cursorSweepNum,0,"TestPulse",1,red,green,blue,rightAxis=1)
							appended+=AppendAndOffsetSweep(i,-1,cursorSweepNum,0,"Stim",1,red,green,blue,rightAxis=1)
						endif
					endfor
				endif
				
				// Current sweep
				if(lastSweep)
					appended+=AppendAndOffsetSweep(-1,i,currSweep,0,"TestPulse",0,red,green,blue,rightAxis=1)
					appended+=AppendAndOffsetSweep(i,-1,currSweep,0,"Stim",0,red,green,blue,rightAxis=1)
				endif
				
				for(j=0;j<numChannels;j+=1)
					dfref postChanDF=GetChanDF(j)
					ControlInfo /W=SweepsWin $("Show_"+num2str(j)); Variable post_active=V_Value
					//Checkbox $("Synapse_"+num2str(i)+"_"+num2str(j)), disable=0, win=SweepsWin
					ControlInfo /W=SweepsWin $("Synapse_"+num2str(i)+"_"+num2str(j)); Variable synapse=V_Value
					if(StringMatch(Chan2ADC(j),"N") || !post_active || !synapse) // If input data is not being collected on this channel or the synapse is not selected.    
						continue // Skip it.  
					endif
					GetChanColor(j,red,green,blue); 
					
					// Current synapse (channel interactions).  
					if(lastSweep)
						variable maxPulses=pulsesStacked ? MaxStimParam("Pulses",i) : 1
						for(pulse=0;pulse<maxPulses;pulse+=1)
							appended+=AppendAndOffsetSweep(i,j,Inf,pulse,"Response",0,red,green,blue)
						endfor
					endif
					
					// Existing synapses (cursors A and B, channel interactions).  
					wave SweepParamsPost=GetChanHistory(j)
					ControlInfo /W=SweepsWin Range; range=V_Value
					if(range) // Append all the sweeps in the range between the cursors. 
						ControlInfo /W=SweepsWin Inc; inc=V_Value
						if(!numtype(first) && !numtype(last))
							for(sweepNum=min(first,last);sweepNum<=max(first,last);sweepNum+=inc)
								if(SelWave[k][i+1] & 16)
									maxPulses=pulsesStacked ? MaxStimParam("Pulses",i,sweep=sweepNum) : 1
									for(pulse=0;pulse<maxPulses;pulse+=1)
										appended+=AppendAndOffsetSweep(i,j,sweepNum,pulse,"Response",0,red,green,blue)
									endfor
								endif
							endfor
						endif
					else // Append only the sweeps indicated by the cursors.  
						for(k=0;k<2;k+=1)
							curs=StringFromList(k,"A;B")
							ControlInfo /W=SweepsWin $("SweepShow_"+curs); cursShow=V_Value
							cursorSweepNum=GetCursorSweepNum(curs)
							if(cursShow && synapse)
								maxPulses=pulsesStacked ? MaxStimParam("Pulses",i,sweep=sweepNum) : 1
								for(pulse=0;pulse<maxPulses;pulse+=1)
									appended+=AppendAndOffsetSweep(i,j,cursorSweepNum,pulse,"Response",1,red,green,blue)
								endfor
							endif
						endfor
					endif
				endfor
			endfor
			ModifyGraph /Z/W=SweepsWin prescaleExp(stimTime_axis)=3
			ModifyGraph /Z/W=SweepsWin prescaleExp(testPulseTime_axis)=3
			ModifyGraph /Z/W=SweepsWin prescaleExp(Time_Axis)=3
			// Set all the axes
			break
		case "Broad":
			// Append all the traces
			for(i=0;i<numChannels;i+=1)
				dfref chanDF=GetChanDF(i)
				first=GetCursorSweepNum("A")
				last=GetCursorSweepNum("B")
				ControlInfo /W=SweepsWin $("Show_"+num2str(i)); pre_active=V_Value
				if(StringMatch(Chan2ADC(i),"N") || !pre_active) // If input data is not being collected on this channel.  
					continue // Skip it.  
				endif
//				for(j=0;j<numChannels;j+=1)
//					Checkbox $("Synapse_"+num2str(i)+"_"+num2str(j)) disable=1, win=SweepsWin
//				endfor
				ControlInfo /W=SweepsWin LastSweep; lastSweep=V_Value
				GetChanColor(i,red,green,blue); 
				// Current sweep
				if(lastSweep)
					appended+=AppendAndOffsetSweep(-1,i,Inf,0,"Sweep",0,red,green,blue)
				endif
				
				// Existing sweeps
				wave /z SweepParams = GetChanHistory(i)
				if(waveexists(SweepParams))
					ControlInfo /W=SweepsWin Range; range=V_Value
					if(range) // Append all the sweeps in the range between the cursors.  
						ControlInfo /W=SweepsWin Inc; inc=V_Value
						if(!numtype(first) && !numtype(last))
							for(k=min(first,last);k<=max(first,last);k+=inc)
								if(SelWave[k][i+1] & 16)
									appended+=AppendAndOffsetSweep(-1,i,k,0,"Sweep",0,red,green,blue)
								endif
							endfor
						endif
					else // Append only the sweeps indicated by the cursors.  
						for(j=0;j<2;j+=1)
							curs=StringFromList(j,"A;B")
							ControlInfo /W=SweepsWin $("SweepShow_"+curs); cursShow=V_Value
							cursorSweepNum=GetCursorSweepNum(curs)
							if(cursShow)
								appended+=AppendAndOffsetSweep(-1,i,cursorSweepNum,0,"Sweep",1,red,green,blue)
							endif
						endfor
					endif
				endif
			endfor
			ModifyGraph /Z/W=SweepsWin prescaleExp(Time_Axis)=0
			// Set all the axes
			break
	endswitch
	ControlInfo /W=SweepsWin Range; range=V_Value
	if(range)
		traces_shown=TraceNameList("SweepsWin",";",3)
		string trace_sweeps=""
		for(i=0;i<itemsinlist(traces_shown);i+=1)
			trace = stringfromlist(i,traces_shown)
			if(grepstring(trace,"Sweep[0-9]+"))
				trace_sweeps += trace+";"
			endif
		endfor
		ChannelColorCode(win="SweepsWin",traces=trace_sweeps)
		LightenTraces(2,traces=trace_sweeps,except="input*",win="SweepsWin")
	endif
	String top_trace=TopAxisTrace("Time_Axis",win="SweepsWin")
	RestoreCursors(view,trace=top_trace,win="SweepsWin")
	ResetSweepAxes(view)
	RestoreAxes(view,win="SweepsWin")
	SweepsWinControlsUpdate()
	
	ModifyGraph /W=SweepsWin tickUnit=1
	
	// TO DO: Determine if this section is still useful.  
	i=0
	Do // Clean up unused waves from the SweepsWin folder.  
		dfref sweepsWinDF=Core#PackageHome(module,"SweepsWin")
		String wavName=GetIndexedObjNameDFR(sweepsWinDF,1,i)
		if(strlen(wavName))
			Wave /sdfr=sweepsWinDF PossiblyUnusedWave=$wavName
			KillWaves /Z PossiblyUnusedWave // Kills if ununused.  Leaves alone if still in the graph.  
			i+=1
		else
			break
		endif
	While(1)
	
	SweepsWinTextBoxUpdate()
End

function SweepsWinTextBoxUpdate()
	String timeStamp="\\Z08"
	ControlInfo /W=SweepsWin LastSweep; Variable lastOn=V_Value
	if(lastOn)
		timeStamp += "\\{root:status:waveformSweeps} (\\{root:status:currSweep}) -- "
		timeStamp += "\\{secs2time(60*GetSweepTime(GetCurrSweep()),3)} -- \\{time()}"
	endif
	string cursors="A;B"
	variable j,cursorOn=0
	for(j=0;j<ItemsInList(cursors);j+=1)
		string curs=StringFromList(j,cursors)
		ControlInfo /W=SweepsWin $("SweepShow_"+curs)
		if(V_Value)
			cursorOn=1
			timeStamp += "\r"+curs+": \\{root:status:cursorSweepNum_"+curs+"} -- "
			timeStamp += "\\{secs2time(60*GetSweepTime(GetCursorSweepNum(\""+curs+"\")),3)} -- "
			timeStamp += "\\{secs2time(root:status:expStartT+60*GetSweepTime(GetCursorSweepNum(\""+curs+"\")),1)}"
		endif
	endfor
	ControlInfo /W=SweepsWin Range; Variable range_on=V_Value
	string highlighted_sweep = GetUserData("SweepsWin","","highlighted_sweep")
	if(range_on && strlen(highlighted_sweep))
		timeStamp += "\r[*]: "+highlighted_sweep
	endif
	if(lastOn && cursorOn)
		timeStamp="\\Z08Last: "+timeStamp
	endif
	Textbox /C/W=SweepsWin /N=TimeStamp timeStamp	
end

Function AppendAndOffsetSweep(pre,post,sweepNum,pulse,type,filtered,red,green,blue[,rightAxis])
	Variable pre // Presynaptic channel number.  -1 if there is nothing "presynaptic" because we are in "Broad" view.  
	Variable post,sweepNum,filtered
	variable pulse // Which pulse number to show a response for (only relevant in Focused mode).  
	String type // "Response", "Stim", or "TestPulse"
	Variable red,green,blue // Colors for the appended sweep.  
	Variable rightAxis // (1) for right axis instead of left, (-1) for left axis instead of right.  rightAxis=0 (default) will make it a right axis only if the number of vertical axes so far is odd, or the existing mode Axis is a right axis.  
	
	String DAQ=Chan2DAQ(post)
	variable kHz=GetKhz(DAQ)
	
	Wave /T Labels=GetChanLabels()
	variable currSweepNum=GetCurrSweep()
	controlinfo /w=sweepswin sweepOverlay
	variable sweepsSplit=v_flag > 0 && stringmatch(ClearBrackets(s_value),"Split")
	controlinfo /w=sweepswin pulseOverlay
	variable pulsesSplit=v_flag > 0 && stringmatch(ClearBrackets(s_value),"Split")
	variable pulsesStacked=v_flag > 0 && stringmatch(ClearBrackets(s_value),"Stacked")
	
	Variable appended=0
	strswitch(type)
		case "Sweep":
		case "Response":
			Variable chan=post	
			String modeStr=SweepAcqMode(post,sweepNum)
			modeStr=selectstring(strlen(modeStr),"Mode",modeStr)
			if(sweepsSplit)
				variable axisNum=ChanNumInMode(post,sweepNum)
				String vertAxis=modeStr+"_"+num2str(axisNum)+"_axis"
			else
				vertAxis=modeStr+"_axis"
			endif
			String horizAxis="Time_Axis"
			variable maxIPI=pre>=0 ? MaxStimParam("IPI",pre,sweep=sweepNum) : Inf
			Variable stimStart=pre>=0 ? 1000*EarliestStim(sweepNum,chan=pre,ignoreRemainder=(sweepNum>=currSweepNum)) + pulse*maxIPI : 0
			if(pre>=0 && (numtype(stimStart) || stimStart<=0)) // No stimulus on this channel.  
				return 0
			endif
			variable left=(pre<0) ? 0 : (stimStart-5)*kHz
			variable maxWidth=pre>=0 ? MaxStimParam("Width",pre,sweep=sweepNum) : Inf
			variable maxPulses=pre>=0 ? MaxStimParam("Pulses",pre,sweep=sweepNum) : Inf
			maxPulses = pulsesStacked ? 0 : maxPulses // If pulses are split, only show one pulse response per trace.  
			variable right=(pre<0) ? Inf : (stimStart+maxWidth+25+maxIPI*maxPulses)*kHz	
			Variable xOffset=-stimStart/1000
			break
		case "Stim":
			chan=pre
			DAQ=Chan2DAQ(pre)
			vertAxis="StimMag_axis"
			horizAxis="StimTime_Axis"
			stimStart=1000*EarliestStim(sweepNum,chan=pre)
			stimStart=(stimStart<0 || numtype(stimStart)) ? 0 : stimStart
			left=(stimStart-1)*kHz
			right=(stimStart+5)*kHz
			xOffset=-stimStart/1000
			break
		case "TestPulse":
			chan=post
			string acqMode=SweepAcqMode(post,sweepNum)
			variable testPulseStart=Core#VarPackageSetting(module,"acqModes",acqMode,"testPulseStart",default_=0)
			vertAxis="TestPulseMag_axis"
			horizAxis="TestPulseTime_Axis"
			left=(testPulseStart*1000-1)*kHz
			right=(testPulseStart*1000+20)*kHz
			xOffset=-testPulseStart
			break
		default:
			type="Sweep"
			chan=post
			vertAxis="vert_axis"
			horizAxis="horiz_Axis"
	endswitch
	if(pre>=0 && post>=0)
		string traceName=Labels[pre]+"_"+Labels[post]
	elseif(post>=0)
		traceName=Labels[post]
	elseif(pre>=0)
		traceName=Labels[pre]
	else
		traceName="error"
	endif
	traceName+="_"+type
	if(sweepNum<currSweepNum)
		wave /z sweepWave=GetChanSweep(chan,sweepNum,quiet=1)
		traceName+=num2str(sweepNum)
	else
		DAQ=Chan2DAQ(chan)
		dfref daqDF=GetDaqDF(DAQ)
		wave /z/sdfr=daqDF SweepWave=$("input_"+num2str(chan))
	endif
	if(!WaveExists(SweepWave))
		return 0
	endif
	if(filtered && FiltersOn(chan))
		Core#PackageHome(module,"SweepsWin",create=1)
		String filtName=GetWavesDataFolder(SweepWave,2)+"_filt"
		Duplicate /O SweepWave $filtName
		Wave SweepWave=$filtName
		ApplyFilters(SweepWave,chan)
	endif
	
	String axes=AxisList("SweepsWin")
	if(rightAxis==0)
		rightAxis=0
		if(WhichListItem(vertAxis,axes)>=0)
			String axis=vertAxis
			String axis_info=AxisInfo("SweepsWin",axis)
			String axisType=StringByKey("AXTYPE",axis_info)
			if((StringMatch(axisType,"right")) && !StringMatch(axis,"TestPulse*") && !StringMatch(axis,"StimMag*"))
				rightAxis=1
			endif
		else
			Variable i,axisCount=0
			for(i=0;i<ItemsInList(axes);i+=1)
				axis=StringFromList(i,axes)
				axis_info=AxisInfo("SweepsWin",axis)
				axisType=StringByKey("AXTYPE",axis_info)
				if((StringMatch(axisType,"left") || StringMatch(axisType,"right")) && !StringMatch(axis,"TestPulse*") && !StringMatch(axis,"StimMag*"))
					axisCount+=1
				endif
			endfor
			if(mod(axisCount,2)==1)
				rightAxis=1
			endif
		endif
	endif
	right = right>dimsize(SweepWave,0) ? dimsize(SweepWave,0)-1 : right
	if(rightAxis)
		AppendToGraph /W=SweepsWin /c=(red,green,blue) /R=$vertAxis /B=$horizAxis SweepWave[left,right] /tn=$traceName
	else
		AppendToGraph /W=SweepsWin /c=(red,green,blue) /L=$vertAxis /B=$horizAxis SweepWave[left,right] /tn=$traceName
	endif
	
	// Zero the traces if needed.  This is in addition to the ApplyFilters above because ApplyFilters is turned off when looking at a sweep range, 
	// because it would be very slow to filter all the sweeps if e.g. low pass and high pass filters were on.  
	Variable yOffset
	variable zero=Core#VarPackageSetting(module,"filters",GetChanName(chan),"zero")
	if(zero) 
		string mode=GetAcqMode(chan)
		variable baselineLeft=Core#VarPackageSetting(module,"acqModes",mode,"baselineLeft")
		variable baselineRight=Core#VarPackageSetting(module,"acqModes",mode,"baselineRight")
		if(baselineLeft != baselineRight)
			WaveStats /Q/M=1/R=(baselineLeft,baselineRight) SweepWave
		else
			WaveStats /Q/M=1 SweepWave
		endif
		yOffset=-V_avg
	endif
	
	ModifyGraph /W=SweepsWin offset($TopTrace(win="SweepsWin"))={xOffset,yOffset}
	appended+=1
	return appended
End

// Show/hide traces in the analysis window according to the state of the synapse checkboxes in the sweep window.  
Function SweepsWinCheckboxes(ctrlName,val)
	String ctrlName
	Variable val
	
	String type=StringFromList(0,ctrlName,"_")
	Variable chan=str2num(StringFromList(1,ctrlName,"_"))
	strswitch(type)
		case "SwitchView":
			SwitchView("SwitchView")
			break
		case "SweepShow":
			Checkbox $ctrlName win=SweepsWin, value=val
			String curs=StringFromList(1,ctrlName,"_")
			variable cursor_sweep_number=GetCursorSweepNum(curs)
			Wave SweepT=root:SweepT
			SwitchView("")
			break
		case "Show":
			Checkbox $ctrlName value=val,win=SweepsWin
			if(val==0)
				variable numChannels=GetNumChannels()
				Variable i
				for(i=0;i<numChannels;i+=1)
					Checkbox $("Synapse_"+num2str(i)+"_"+num2str(chan)), value=0
				endfor
			endif	
			PossiblyShowAnalysis()
			SwitchView("")
			break
		case "Synapse":
			PossiblyShowAnalysis()
			SwitchView("")
			break
		case "LastSweep":
			// Adds or removes the last sweep(s) the window Sweeps and removes or lightens other sweeps.  
			ControlInfo /W=SweepsWin LastSweep
			Checkbox LastSweep win=SweepsWin, value=val
			val=1 // Until the Igor 6.10 beta bug is fixed, I must force this to be 1.  
			TextBox /C/V=(val)/N=TimeStamp
			SwitchView("")
			break
		case "Range":
			SetVariable Inc, disable=!val, pos={504,35}, title="Inc", value=_NUM:1, limits={1,Inf,1}, win=SweepsWin, proc=SweepsWinSetVariables
			Button ChooseSweeps, disable=!val, pos={424,32}, title="Choose", win=SweepsWin, proc=SweepsWinButtons
			Button Export, disable=!val, pos={571,32}, title="Export", win=SweepsWin, proc=SweepsWinButtons
			if(val)
				SweepsChooserUpdate()
			endif
			if(numChannels<=2)
				ControlBar /W=SweepsWin/T 3*18+3  
			endif
			SwitchView("")
			break
	endswitch
End

Function PossiblyShowAnalysis()
	variable numChannels=GetNumChannels()
	Variable pre,post,k
	Wave /T Labels=GetChanLabels()
	String traces=TraceNameList("AnalysisWin",";",3)
	//String activeAxis=GetUserData("","","activeAxis") // The currently selected (bold) axis.
	//String activeTraces=YAxisTraces(activeAxis,win="AnalysisWin")
	for(k=0;k<ItemsInList(traces);k+=1)
		string trace=StringFromList(k,traces)
		string analysisMethod=StringFromList(0,trace,"#")	// The old way.  
		analysisMethod=StringFromList(0,analysisMethod,"_col") // The new way (doing both should be safe).  
			
		// Get postsynaptic channel for this trace.  
		Wave TraceWave=TraceNameToWaveRef("AnalysisWin",trace) // Measurement wave that this trace corresponds to.  
		String channelName=GetWavesDataFolder(TraceWave,0)
		FindValue /TEXT=channelName /TXOP=4 Labels
		post=V_Value
		
		// Get presynaptic channel and measurement column for this trace.  
		string trace_info=TraceInfo("AnalysisWin",trace,0)
		string yRange=StringByKey("YRANGE",trace_info)
		variable column // Column in the measurement wave that this trace corresponds to.  
		sscanf yRange,"[%*[0-9\*]][%d][%d]",column,pre
		string columnControl = "Column_"+num2str(column)+"_"+cleanupname(analysisMethod,0)
		ControlInfo /W=AnalysisWin $columnControl
		variable columnOn=V_flag==2 ? V_Value : 1
		
		variable crossChannel=Core#VarPackageSetting(module,"analysisMethods",analysisMethod,"crossChannel")
		if(!crossChannel) // For analyses that are not cross-channel.  
			if(pre!=0)
				continue // Only consider traces that are in the first layer (should be the only ones on the plot).  
			else
				pre=post // And set pre and post equal for the purposes of checking the state of the Synapse checkbox.  
			endif
		endif
		ControlInfo /W=SweepsWin $("Synapse_"+num2str(pre)+"_"+num2str(post))
		Variable synapseOn=!crossChannel || V_Value || V_disable
		ControlInfo /W=SweepsWin $("Show_"+num2str(post))
		Variable showOn=V_Value
		Variable show=synapseOn && showOn && columnOn // If this trace has the same pre- and post-synaptic channel as the checkbox that was checked/unchecked and the value is checked in the analysis window.  
		ModifyGraph /Z/W=AnalysisWin hideTrace($trace)=!show // Show/hide it.  
	endfor
End

// ----------------------- Functions to alter the content of the windows -------------------------

Function AnalysisMethodSubSelections(axisNum)
	variable axisNum
	
	dfref analysisWinDF=Core#InstanceHome(module,"analysisWin","win0")
	wave /t/sdfr=analysisWinDF ListWave
	wave /sdfr=analysisWinDF SelWave,AxisIndex
	
	MarkSelected(axisNum) // Bold the active axis.  
	String analysisMethods=Core#ListPackageInstances(module,"analysisMethods")
	
	// Mark method corresponding to the selected axis as active.  
	SelWave = SelWave & ~1 // Set all plots to unselected.  
	FindValue /V=(axisNum) AxisIndex
	Variable index=V_Value
	Variable j,shown=0
	variable numChannels=GetNumChannels()
	SelWave[index][]+=1 // Mark this row as selected.   
	
	
	String axisName="Axis_"+num2str(axisNum)
	String analysisMethod=StringFromList(index,analysisMethods)
	if(index>=ItemsInList(analysisMethods) || dimsize(ListWave,1)==0 || !strlen(analysisMethod))
		return -1
	endif
	string /g analysisWinDF:selected=analysisMethod
	
	dfref instanceDF=Core#InstanceHome(module,"analysisMethods",analysisMethod)
	if(WinType("SweepsWin"))
		String view=GetUserData("SweepsWin","SwitchView","")
		wave /z cursor_locs = Core#WavPackageSetting(module,"analysisMethods",analysisMethod,"cursorLocs")
		if(waveexists(cursor_locs))
			//Variable focused=StringMatch(view,"Focused")
			String trace=LongestVisibleTrace(win="SweepsWin")
			if(strlen(trace))
				Variable offset=XOffset(trace,win="SweepsWin")
				SetWindow SweepsWin hook=$""
				Cursor /W=SweepsWin A,$trace,cursor_locs[0]-offset
				Cursor /W=SweepsWin B,$trace,cursor_locs[1]-offset
			endif
		endif
	endif	
		
	variable chan=0,analysis_chan
	for(analysis_chan=0;analysis_chan<numChannels;analysis_chan+=1)
		if(IsChanAnalysisMethod(analysis_chan,analysisMethod))
			chan = analysis_chan
			break
		endif
	endfor
	String acqMode=GetAcqMode(chan)
	SetVariable Parameter, disable=1
	Checkbox Exclude_Stimuli, disable=1
	PopupMenu Minimum, disable=1
	Variable value=NaN
	string limits="-Inf;1;Inf"
	string descriptionShort=""
	string descriptionLong=""
	String labell="",titles=""
	String availableMethodCases=GetCases("MakeMeasurement")
	if(WhichListItem(analysisMethod,availableMethodCases)>=0)
		String methodCase=analysisMethod
	else
		methodCase=Core#StrPackageSetting(module,"analysisMethods",analysisMethod,"method",default_="")
	endif
	strswitch(methodCase)
		case "Peak":
			labell="Peak Value"
			titles="Pulse 1;Pulse 2"
			PopupMenu Minimum, disable=0
			break
		case "PeakWX":
			labell="Peak Value"
			titles="Pulse 1;Pulse 2"
			limits="0;Inf;0.1"
			descriptionShort="Width (ms)"
			descriptionLong="Half-width for peak-averaging (ms)"
			value=0.1
			break
		case "Charge":
			titles="Pulse 1;Pulse 2"
			PopupMenu Minimum, disable=0
			break
		case "Slope":
			titles="Pulse 1;Pulse 2"
			PopupMenu Minimum, disable=0
			break
		case "Ratio":
			labell="Pulse Ratio"
			titles="Ratio"
			PopupMenu Minimum, disable=0
		case "Average":
			titles="Pulse 1;Pulse 2"
			break
		case "Standard_Deviation":
			labell="Standard\rDeviation"
			titles="St. Dev.;Skewness"
			break
		case "Meann":
			labell="Mean"
			titles="Mean;Median"
			break
		case "Median-Mean":
			labell="Median - Mean"
			titles="Median - Mean;Mode - Mean"
			break
		case "Spike_Rate":
		case "Spike_Rate_EC":
			titles="Rate;Count"
			limits="0;Inf;0.5"
			value=1
			descriptionShort="Thresh"
			descriptionLong="Ampliude threshold for counting a spike"
			break
		case "Heart_Rate":
			titles="Rate;CV"
			break
		case "Minis":
			labell="Mini\rSize/Freq."
			titles="Size;Freq"
			NewDataFolder /O root:Minis
			if(!exists("root:Minis:mini_thresh"))
				Variable /G root:Minis:mini_thresh=5
			endif
			limits="-Inf;Inf;0.5"
			value=5
			descriptionShort="Thresh"
			descriptionLong="Mini amplitude threshold (pA)"
			//Checkbox Exclude_Stimuli title="XS", disable=0, win=AnalysisWin
			break
		case "Bek-Clem":
			labell="BC Frequency/Noise"
			titles="Frequency;Noise"
			NewDataFolder /O root:Minis
			if(!exists("root:Minis:BC_thresh"))
				Variable /G root:Minis:BC_thresh=5
			endif
			limits="0;Inf;0.5"
			value=1
			descriptionShort="Thresh"
			descriptionLong="Bekkers-Clements score threshold for identifying an event"
			//Checkbox Exclude_Stimuli title="XS", disable=0, win=AnalysisWin // For excluding analysis of sweeps with stimuli.  
			break
		case "Events":
			labell="Spontaneous Event Rate"
			titles="Frequency"
			break
		case "Power":
			labell="Signal\rPower"
			titles="Power;Phase"
			limits="0;Inf;0.5"
			value=60
			descriptionShort="Freq"
			descriptionLong="Frequency (Hz)"
			break
		case "Access_Resistance":
			labell="Access\rResistance"
			titles="R_a;Tau"
			break
		case "Input_Resistance":
			labell="Input\rResistance"
			titles="R_in"
			break
		case "Resistance":
			labell="Resistance"
			titles="Pulse 1;Pulse 2;"
			break
		case "Time_Constant":
			labell="Time\rConstant"
			titles="Pulse 1;Pulse 2;"
			descriptionShort="Time Constant (ms)"
			descriptionLong="Time constant for an exponential fit (ms)"
			break
		case "Baseline":
			titles="Mean;StDev"
			//limits="0;Inf;0.01"
			//value=0.025
			//description="End"
			break
		case "AMPA_NMDA":
			labell="AMPA & NMDA"
			titles="AMPA;NMDA"
			limits="0;Inf;1"
			descriptionShort="Delay (ms)"
			descriptionLong="Time after the cursor to make NMDA measurement (ms)"
			value=60
			break
		case "Latency":
			descriptionShort="Latency (ms)"
			break
		default:
			printf "Method case '%s' not found.\r",methodCase
			//return -1
			break
	endswitch
	
	if(!strlen(labell))
		labell=ReplaceString("_",analysisMethod," ")
	endif
	if(!strlen(titles))
		titles=analysisMethod
	endif
	
	string modeUnits=GetModeInputUnits(acqMode)
	string methodUnits=GetMethodUnits(analysisMethod)//,acqMode=acqMode)
	string units=ReplaceString("#",methodUnits,modeUnits)
	variable linefeedLabels=Core#VarPackageSetting(module,"random","","linefeedLabels",default_=1)
	if(!lineFeedLabels) // If the user preference is to not have "\r" in axis labels.  
		labell=ReplaceString("\r",labell," ") // Replace "\r" with space.  
	endif
	labell+=SelectString(strlen(units),"","\r("+units+")")
	
	Label /Z/W=AnalysisWin $axisName, labell
	variable lblpos=GetAxisLabelPos()
	ModifyGraph /W=AnalysisWin /Z lblPos($axisName)=lblpos+10*(ItemsInList(labell,"\r")-1)
	dfref analysisWinDF=Core#InstanceHome(module,"analysisMethods",analysisMethod,sub="analysisWin",create=1)
	wave /z/sdfr=analysisWinDF Parameter,Features
	if(!waveexists(Features))
		make /o/n=2 analysisWinDF:Features /wave=Features=1
	endif
	if(sum(Features)==0)
		Features[0]=1
	endif
	Features = Features[p] || numtype(Features[p]) ? 1 : 0
	
	string columnControls = ControlNameList("AnalysisWin",";","Column_*")
	ModifyControlList /Z columnControls disable=1
	variable i
	if(itemsinlist(titles)>=2) // Analysis methods, i=0 is primary, i>=1 are auxiliary.  
		for(i=0;i<itemsinlist(titles);i+=1)
			string name = "Column_"+num2str(i)+"_"+CleanupName(analysisMethod,0)
			Checkbox $name title=StringFromList(i,titles), disable=0, value=Features[i], proc=AnalysisWinCheckboxes, win=AnalysisWin // An analysis method.  
			AnalysisWinCheckboxes(name,Features[i])
		endfor
	endif
	
	if(numtype(value)==0)
		Make /o/n=3/FREE lim=str2num(StringFromList(p,limits))
		if(waveexists(Parameter) && numtype(Parameter[index])==0) // If it has previously been set.
			value=Parameter[index] // Use the old value.  
		endif
		SetVariable Parameter, disable=0, limits={lim[0],lim[1],lim[2]}, bodywidth=40, value=_NUM:(value), help={descriptionLong}, proc=AnalysisWinSetVariables, win=AnalysisWin,title=descriptionShort+":"
	endif
End

Function AnalysisWinCheckboxes(ctrlName,val) : CheckboxControl
	String ctrlName
	Variable val
	
	dfref analysisWinDF=Core#InstanceHome(module,"analysisWin","win0")
	wave /t/sdfr=analysisWinDF ListWave
	wave /sdfr=analysisWinDF SelWave,Parameter
	variable methodIndex=0
	Do
		if(SelWave[methodIndex][0] & 1) // This is the selected method.  
			break
		endif
		methodIndex+=1
	While(methodIndex<dimsize(ListWave,0))
	if(methodIndex==dimsize(ListWave,0)) // Gone too far.  
		return -1
	endif
	
	string method=SelectedMethod()
	variable i
	string name = StringFromList(0,ctrlName,"_")
	variable num = str2num(StringFromList(1,ctrlName,"_")) // Probably measurement wave column.  
	strswitch(name)
		case "Column":
			PossiblyShowAnalysis()
//			String traces=TraceNameList("AnalysisWin",";",1)
//			traces=ListMatch(traces,CleanupName(method,0)+"*")
//			for(i=0;i<ItemsInList(traces);i+=1)
//				String trace=StringFromList(i,traces)
//				String trace_info=TraceInfo("AnalysisWin",trace,0)
//				String range=StringByKey("YRANGE",trace_info)
//				Variable index
//				sscanf range,"[%*[0-9\*]][%d][&*[0-9\*]]",index
//				if(num==index)
//					//controlinfo /w=SweepsWin 
//					ModifyGraph /Z/W=AnalysisWin hideTrace($trace)=!val
//				endif
//			endfor
//			
			Core#SetWavPackageSetting(module,"analysisMethods",method,"Features",{val},indices={num},sub="analysisWin")
			break
	endswitch
End

// Moves cursors in the graph to match the value of the cursor variables
Function MoveCursor(curs,num)
	String curs
	Variable num
	
	variable currSweep=GetCurrSweep()
	string cursorInfo=""
	if(wintype("AnalysisWin"))
		if(!CursorExists("A",win="AnalysisWin"))
			Cursors(win="AnalysisWin")
		endif
		cursorInfo=CsrInfo($curs,"AnalysisWin")
	endif
	dfref statusDF=GetStatusDF()
	nvar /sdfr=statusDF cursorSweepNum=$("cursorSweepNum_"+curs)
	if(num>=currSweep)
		cursorSweepNum=currSweep-1
		return 0
	else
		cursorSweepNum=num
	endif
	if(!strlen(cursorInfo))
		SwitchView("New Sweep") // Since we didn't go through SweepsWinHook, let's do SwitchView from here.  
	else
		String cursorTrace=StringByKey("TName",cursorInfo)
		// If the cursor's trace is hidden, move to the cursor to the top visible trace
		if(!IsTraceVisible(cursorTrace,win="AnalysisWin"))
			cursorTrace=TopVisibleTrace(win="AnalysisWin")
		endif
		// If the new value is a NaN or beyond the range of the trace, move the cursor to another trace
		if(!IsTraceValued(num,cursorTrace,win="AnalysisWin"))
			cursorTrace=TopValuedTrace(num,win="AnalysisWin")
		endif
		// If no trace can be found to move the cursor to, don't move the cursor.  
		if(WhichListItem(curs,"A;B")>=0)
			Cursor /W=AnalysisWin /P $curs $cursorTrace num
		endif
		struct wmwinhookstruct info
		info.winname = "analysisWin"
		info.eventName = "cursormoved"
		info.cursorName = curs
		info.pointNumber = num
		AnalysisWinHook(info)
	endif
	// There is a hook function in AnalysisWin that checks to see if the cursor has moved.  
	// If it has, it updates the window "SweepsWin".  
End

// Resizes a window that has zoom buttons.  
Function Zoom(ctrlName): ButtonControl
	String ctrlName
	String direction=StringFromList(ItemsInList(ctrlName,"_")-1,ctrlName,"_")
	String axis_name=RemoveFromList(direction,ctrlName,"_")
	axis_name=axis_name[0,strlen(axis_name)-2] // Remove the last "_".  
	String win_name=WinName(0,1)
	String axis_list=AxisList(win_name)
	if(WhichListItem(axis_name,axis_list)<0)
		if(WhichListItem("CC_Axis",axis_list)>=0)
			axis_name="CC_Axis"
		endif
	endif
	GetAxis/Q /W=$win_name $axis_name
	String axis_type=AxisInfo(win_name,axis_name)
	axis_type=StringByKey("AxType",axis_type)
	Variable new_Top, new_Bottom
	strswitch(direction)
		case "Up":
			new_Top=V_max+(V_max-V_min)/10
			new_Bottom=V_min+(V_max-V_min)/10
			break
		case "Down":
			new_Top=V_max-(V_max-V_min)/10
			new_Bottom=V_min-(V_max-V_min)/10
			break
		case "Larger":
			new_Top=V_max>0 ? V_max*1.25 : V_max+abs(V_max-V_min)/4
			if(WhichListItem(axis_type,"bottom;top")>-1)
				new_Bottom=V_min
			else
				new_Bottom=V_min<0 ? V_min*1.25 : V_min-abs(V_max-V_min)/4
				//new_Bottom=V_min-abs(V_min)/4
			endif
			break
		case "Smaller":
			new_Top=V_max>0 ? V_max*0.8 : V_max-abs(V_max-V_min)/5
			if(WhichListItem(axis_type,"bottom;top")>-1)
				new_Bottom=V_min
			else
				new_Bottom=V_min<0 ? V_min*0.8 : V_min+abs(V_max-V_min)/5
				//new_Bottom=V_min+abs(V_min)/5
			endif
			break
	endswitch
	if(strlen(AxisInfo(win_name,axis_name)))
		SetAxis /W=$win_name $axis_name new_Bottom,new_Top
		if(StringMatch(axis_name,"Time_Axis") && StringMatch(win_name,"AnalysisWin"))
			//SetAxis /W=Membrane_Constants bottom new_Bottom, new_Top
		endif
		if(StringMatch(axis_name,"Time_Axis") && StringMatch(win_name,"SweepsWin"))
			ModifyGraph /Z freePos(VC_Axis)={new_Bottom,Time_Axis}
		endif
	endif
End

// Resizes a window that has zoom buttons.  
Function Zoom2(info) : SliderControl
	STRUCT WMSliderAction &info
	if(info.eventcode & 4)
//		String direction=StringFromList(ItemsInList(ctrlName,"_")-1,ctrlName,"_")
//		String axis_name=RemoveFromList(direction,ctrlName,"_")
//		axis_name=axis_name[0,strlen(axis_name)-2] // Remove the last "_".  
//		String win_name=WinName(0,1)
//		String axis_list=AxisList(win_name)
//		if(WhichListItem(axis_name,axis_list)<0)
//			if(WhichListItem("CC_Axis",axis_list)>=0)
//				axis_name="CC_Axis"
//			endif
//		endif
		String axis_name="VC_Axis"
		String win_name=info.win
		GetAxis/Q/W=$win_name $axis_name
		ControlInfo /W=$win_name  $info.ctrlName; Variable mag=10^V_Value
		Variable center=(V_max+V_min)/2
		Variable new_Top=center+(V_max-center)*mag
		Variable new_Bottom=center-(center-V_min)*mag
		SetAxis /W=$win_name $axis_name new_Bottom,new_Top
		if(StringMatch(axis_name,"Time_Axis") && StringMatch(win_name,"AnalysisWin"))
			SetAxis /W=Membrane_Constants bottom new_Bottom, new_Top
		endif
		if(StringMatch(axis_name,"Time_Axis") && StringMatch(win_name,"SweepsWin"))
			ModifyGraph /Z freePos(VC_Axis)={new_Bottom,Time_Axis}
		endif
		SliderCenter(info.ctrlName,win=info.win,quick=3)
	endif
End

// Adds linear regression lines between the cursors on all active traces
Function RegressionLine()
	String currFolder=GetDataFolder(1)
	String activeAxis=GetUserData("","","activeAxis") // The currently selected (bold) axis.
	String traces=YAxisTraces(activeAxis,win="AnalysisWin")
	String fitTraces=ListMatch(traces,"regress_*")
	String dataTraces=RemoveFromList(fitTraces,traces)
	
	if(ItemsInList(fitTraces))
		Variable removeFits=1
	endif
	Variable i
	// Clear all fits first.  
	Do // Must do this way to account for traces changing names from #2 to #1, etc. as traces are removed.  
		if(ItemsInList(fitTraces)>0)
			for(i=0;i<ItemsInList(fitTraces);i+=1)
				String fitTrace=StringFromList(i,fitTraces)
				RemoveFromGraph /Z $fitTrace
			endfor
			traces=YAxisTraces(activeAxis,win="AnalysisWin")
			fitTraces=ListMatch(traces,"regress_*")
		else
			break
		endif
	While(1)
	if(removeFits) // If any first were cleared.  
		return 0 // Assume the user just wanted to clear the existing fits.  
	endif

	String visible_traces=VisibleTraces(graph="AnalysisWin")
	
	// Now append new fits. 
	if(!strlen(CsrInfo(A)))
		DoAlert 0,"You must place cursors on your data first."
		return -1
	endif
	Variable first=xcsr(A)
	Variable last=xcsr(B)
	Variable red,green,blue
	for(i=0;i<ItemsInList(dataTraces);i+=1)
		String trace=StringFromList(i,dataTraces)
		if(WhichListItem(trace,visible_traces)<0) // If trace is not visible.  
			continue // Don't fit it.  
		endif
		Wave TraceWave=TraceNameToWaveRef("",trace)
		Wave XTraceWave=XWaveRefFromTrace("",trace)
		String folder=GetWavesDataFolder(TraceWave,1)
		SetDataFolder $folder
		if(last<=first)
			last=numpnts(TraceWave)-1
			if(last==first)
				first=last-1
			endif
		endif
		if(x2pnt(TraceWave,last)-x2pnt(TraceWave,first)>=2)
			String trace_info=TraceInfo("AnalysisWin",trace,0)
			String yRange=StringByKey("YRANGE",trace_info)
			Variable value,pre
			sscanf yRange,"[%*[0-9\*]][%d][%d]",value,pre
			String fitName=CleanUpName("regress_"+trace,0)
			Duplicate /o/R=[first,last][value][pre] TraceWave $fitName
			Redimension /n=(numpnts($fitName)) $fitName
			SetScale /P x,first,1,$fitName
			Wave /Z FitWave=$fitName
			Variable V_FitError=0
			CurveFit /Q line $fitName /X=XTraceWave[first,last] /D=$fitName
			Variable error=GetRTError(1)
			if(!error)
				String trace_colors=GetTraceColor(trace,red,green,blue)
				AppendToGraph /c=(red,green,blue) /L=$activeAxis /B=time_axis $fitName vs XTraceWave[first,last]
				ModifyGraph /Z lsize($fitName)=0.5
				Wave W_Coef=W_coef; Wave W_Sigma=W_Sigma
				//printf "For trace %s, the slope is %f +/- %f\r",trace,W_Coef(2),W_Sigma(2)
			endif
		endif
	endfor
	
	SetDataFolder $currFolder
End

// Normalizes the trace to the mean of the region between the cursors (e.g. the region between the cursors will have a new mean of 1).  
Function NormalizeToRegion()
	String normed=(GetUserData("","","normed"))
	String activeAxis=GetUserData("","","activeAxis")
	DoUpdate
	GetAxis /Q /W=AnalysisWin $activeAxis
	Variable minn=V_min,maxx=V_max
	Variable normDegree=NumberByKey(activeAxis,normed)
	if(normDegree)
		ModifyGraph muloffset={0,0}
		SetWindow kwTopWin userData(normed)=ReplaceNumberByKey(activeAxis,normed,0)
		SetAxis /W=AnalysisWin $activeAxis, minn*normDegree,maxx*normDegree
	else
		if(strlen(CsrInfo(A)) && abs(pcsr(B)-pcsr(A))>=1) // If the Cursor A is in the top graph and the range is sufficient.  
			WaveStats /Q /R=(xcsr(A),xcsr(B)) CsrWaveRef(A)
			Variable avg=V_avg
			SetWindow kwTopWin userData(normed)=ReplaceNumberByKey(activeAxis,normed,avg)
			
			String traces=YAxisTraces(activeAxis)
			Variable i
			for(i=0;i<ItemsInList(traces);i+=1)
				SetAxis /W=AnalysisWin $activeAxis,minn/avg,maxx/avg
				ModifyGraph muloffset={0,1/avg}
			endfor
		endif
	endif
End

// Applies smoothing to the data in a region of a trace specified by the cursors.  
Function TrendRegion(method,options)
	string method,options
	
	if(!strlen(csrinfo(a)) || !strlen(csrinfo(b))) // If one or more of the cursors is not present.  
		return -1
	endif
	variable start=pcsr(a), finish=pcsr(b)
	if(abs(finish-start)<=3) // If the range is insufficient.  
		return -2
	endif
	wave /z data=CsrWaveRef(A,"AnalysisWin")
	if(!waveexists(data))
		return -3
	endif
	string trace = csrwave(A,"AnalysisWIn",1)
	dfref df=getwavesdatafolderdfr(data)
	wave /z Trend=df:$(nameofwave(data)+"_trend")
	if(!waveexists(Trend))
		duplicate /o data,df:$(nameofwave(data)+"_trend") /wave=Trend
		trend=NaN
	else
		redimension /n=(dimsize(data,0),dimsize(data,1),dimsize(data,2)) Trend
	endif
	wave sweepT=GetSweepT()
	String trends=(GetUserData("","","trends"))
	String activeAxis=GetUserData("","","activeAxis")
	DoUpdate
	string trace_info=TraceInfo("AnalysisWin",trace,0)
	string yRange=StringByKey("YRANGE",trace_info)
	variable value,pre
	sscanf yRange,"[%*[0-9\*]][%d][%d]",value,pre
	Duplicate /free/R=[start,finish][value][pre] data trendY
	Redimension /n=(numpnts(trendY)) trendY
	Duplicate /free/R=[start,finish] sweepT trendX
	make /o/n=(finish-start+1) tempTrend
	variable order=nan
	variable neighbors=numberbykey("neighbors",options)
	neighbors=numtype(neighbors) ? 5 : neighbors
	
	strswitch(method)
		case "Remove":
			Trend=NaN
			variable red,green,blue
			string channel = GetDataFolder(0,df)
			GetChannelColor(channel,red,green,blue)
			modifygraph /Z/w=AnalysisWIn rgb($trace)=(red,green,blue)
			removefromgraph /z/w=AnalysisWIn $(nameofwave(trend))
			return 0
			break
		case "Linear Regression":
			//SetScale /P x,first,1,$fitName
			//Wave /Z FitWave=$fitName
			variable V_FitError=0
			CurveFit /Q line trendY /X=trendX /D=tempTrend
			variable error=GetRTError(1)
			break
		case "Decimation":
			tempTrend = mean(trendY,pnt2x(trendY,p-neighbors/2),pnt2x(trendY,p+neighbors/2))
			order=numtype(order) ? 0 : order
			break
		case "Lowess":
			order=numtype(order) ? 1 : order
		case "Loess":
			order=numtype(order) ? 2 : order
			variable orig_neighbors = neighbors
			do
				Loess /dest=tempTrend /N=(neighbors) /ORD=(order) /R=0 /Z=1 srcWave=trendY, factors={trendX}
				error=v_flag
				neighbors+=1
			while(error && neighbors<(finish-start+1))
			//SetWindow kwTopWin userData(loessed)=ReplaceNumberByKey(activeAxis,loessed,pcsr(A)+pcsr(B)/10000)
			break
		case "----":
			error=1
			break
		default:
			Post_("Unknown trend case: "+method)
	endswitch
	
	if(!error)
		if(stringmatch(method,"Decimation"))
			Trend[start,finish][value][pre] = mod(p,neighbors)==floor((neighbors-1)/2) ? tempTrend[p-start] : nan
		else
			Trend[start,finish][value][pre]=tempTrend[p-start]
		endif
		string appendedTrends=AppendedWave(Trend,dim1=value,dim2=pre,axis=activeAxis,win="AnalysisWin")
		if(!strlen(appendedTrends))
			GetTraceColor(trace,red,green,blue)
			string y_axis_name = TraceYAxis(trace,win="AnalysisWin")
			appendToGraph /c=(red,green,blue) /L=$y_axis_name /B=time_axis Trend[][value][pre] vs sweepT
			string trend_trace = TopTrace(win="AnalysisWin")
			modifyGraph /Z lsize($trend_trace)=0.5
			if(stringmatch(method,"Decimation"))
				modifygraph /Z rgb($trace)=(65535-(65535-red)/2,65535-(65535-green)/2,65535-(65535-blue)/2)
				variable marker = numberbykey("marker(x)",trace_info,"=")
				modifyGraph /Z mode($trend_trace)=3,marker($trend_trace)=marker,lsize($trend_trace)=5
			endif
		endif
	endif
	killwaves /z tempTrend
End

Function /s AppendedWave(w[,dim0,dim1,dim2,axis,win])
	wave w
	variable dim0,dim1,dim2 // dim0 is not used.  
	string axis,win
	
	win=selectstring(paramisdefault(win),win,winname(0,1))
	axis=selectstring(paramisdefault(axis),axis,"*")
	string traces=YAxisTraces(axis,win=win)
	string matchingTraces=""
	variable i
	for(i=0;i<itemsinlist(traces);i+=1)
		string trace=stringfromlist(i,traces)
		string info=traceinfo(win,trace,0)
		wave w_=TraceNameToWaveRef(win,trace)
		if(stringmatch(getwavesdatafolder(w,2),getwavesdatafolder(w_,2)))
			string yRange=StringByKey("YRANGE",info)
			variable dim0_,dim1_,dim2_
			sscanf yRange,"[%*[0-9\*]][%d][%d]",dim1_,dim2_
			if(!paramisdefault(dim1) && dim1!=dim1_)
				continue
			endif
			if(!paramisdefault(dim2) && dim2!=dim2_)
				continue
			endif
			matchingTraces+=trace+";"
		endif
	endfor
	return matchingTraces
End

// Handles all hooks for windows

function SweepsWinHook(info)
	struct WMWinHookStruct &info
	if(info.eventCode==4)
		return 0
	endif
	variable quiet = !Core#IsDev()
	strswitch(info.eventName)
		case "cursormoved":
			string method=SelectedMethod()
			if(strlen(method))
				dfref instanceDF=Core#InstanceHome(module,"analysisMethods",method,create=1)
				ControlInfo /W=$info.winname SwitchView; String view=S_userdata
				Variable focused=StringMatch(view,"Focused")
				dfref instanceDF=Core#InstanceHome(module,"analysisMethods",method)
				wave /z cursor_locs = Core#WavPackageSetting(module,"analysisMethods",method,"cursorLocs",quiet=quiet)
				if(waveexists(cursor_locs))
					variable loc = focused ? xcsr2(info.cursorName,win=info.winname) : xcsr($(info.cursorName),info.winname)
					redimension /n=(max(numpnts(cursor_locs),2)) cursor_locs
					strswitch(info.cursorName)
						case "A":
							cursor_locs[0] = loc
							break
						case "B":
							cursor_locs[1] = loc
							break
					endswitch
				endif
			endif
			break
		case "resize":
			if(!WinType(info.winname))
				return -1
			endif
			GetWindow $info.winname,wsizeDC
			variable narrow = (v_right-v_left<1100)
			ControlBar /W=$info.winname /L 125*narrow
			SetWindow $info.winname, userData(isNarrow)=num2str(narrow)
			String controls="SetBaselineRegion;ResetSweepAxes;SwitchView;AutoBaseline;SweepOverlay;PulseOverlay;WaveSelector;Logger;"
			if(!narrow)
				controls = ReverseListOrder(controls)
			endif
			variable numControls=itemsinlist(controls)
			variable numChannels=GetNumChannels()
			variable xx = narrow ? 2 : v_right
			variable yy = narrow ? max(3,numChannels)*18 : 2
			variable i,j
			for(i=0;i<numControls;i+=1)
				string controlName = stringfromlist(i,controls)
				ControlInfo /W=$info.winname $controlName
				if(v_disable != 1) // If visible.  
					variable isPopup=(V_flag==3)
					variable isCheckbox=(V_flag==2)
					if(narrow)
						yy += i==0 ? 10 : 30
					else
						if(mod(i,2)==0)
							xx -= 120+isPopup*25-isCheckbox*25
							yy = 2
						else
							yy = 26
						endif
					endif
					ModifyControl /Z $controlName pos={xx,yy+isPopup*3+isCheckbox*4}, win=$info.winname
				endif
			endfor
			break
		case "modified":
			ControlInfo /W=$info.winname sweepOverlay
			if(v_flag<=0 || !StringMatch(ClearBrackets(s_value),"Split"))
				break
			endif
			String axes=AxisList(info.winname)
			for(i=0;i<ItemsInList(axes);i+=1)
				String axis=StringFromList(i,axes)
				String axis_info=AxisInfo(info.winname,axis)
				String axisType=StringByKey("AXTYPE",axis_info)
				if((StringMatch(axisType,"left") || StringMatch(axisType,"right")) && !StringMatch(axis,"Stim*") && !StringMatch(axis,"TestPulse*"))
					SweepsWinVertAxisOffsets(axis)
				endif
			endfor
		case "mousedown":
			string str
			structput /s info.mouseLoc str
			SetWindow $info.winname userData(mouseDown)=str
			if(info.mouseLoc.v<0 && (info.eventMod & 16))
				PopupContextualMenu Core#ListPackageInstances(module,info.winname)+"_Save_"
				if(v_flag>=0)
					SelectPackageInstance(info.winname,s_selection)
				endif
			endif
			break
		case "mouseup":
			structput /s info.mouseLoc str
			SetWindow $info.winname userData(mouseUp)=str
			break
		case "keyboard":
			ControlInfo /W=$info.winName Range
			variable range_checked = v_value
			if(range_checked)
				variable highlighted_sweep = str2num(GetUserData(info.winName, "", "highlighted_sweep"))
				string traces = TraceNameList(info.winName,";",1)
				if(info.keyCode == 30 || info.keyCode == 31) // Up or down arrow.  This will change the thickness of a sweep and set it to full channel color.   
					if(numtype(highlighted_sweep))
						highlighted_sweep = GetCursorSweepNum("A")
					else
						highlighted_sweep += -(info.keyCode*2 - 61)
						highlighted_sweep = limit(highlighted_sweep,GetCursorSweepNum("A"),GetCursorSweepNum("B"))
					endif
					setwindow $info.winName userData(highlighted_sweep) = num2str(highlighted_sweep)
					string traces_shown=TraceNameList(info.winName,";",3)
					string trace_sweeps=""
					for(i=0;i<itemsinlist(traces_shown);i+=1)
						string trace = stringfromlist(i,traces_shown)
						if(grepstring(trace,"Sweep[0-9]+"))
							trace_sweeps += trace+";"
						endif
					endfor
					ChannelColorCode(win=info.winName,traces=trace_sweeps)
					LightenTraces(2,traces=trace_sweeps,except="input*",win=info.winName)
					for(i=0;i<itemsinlist(trace_sweeps);i+=1)
						string trace_sweep = stringfromlist(i,trace_sweeps)
						modifygraph /w=$info.winName lsize($trace_sweep)=1
					endfor
					string matching_traces = listmatch(traces,"*sweep"+num2str(highlighted_sweep)+"*")
					for(i=0;i<itemsinlist(matching_traces);i+=1)
						string matching_trace = stringfromlist(i,matching_traces)
						string channel = Trace2Channel(matching_trace,win=info.winName)
						variable red,green,blue
						GetChannelColor(channel,red,green,blue)
						modifygraph /w=$info.winName rgb($matching_trace)=(red,green,blue), lsize($matching_trace)=2
						Trace2Top(matching_trace,win=info.winName)
					endfor
					SweepsWinTextBoxUpdate()
					if(WinType("PreviewStimuliWin"))
						PreviewStimuli(sweep_num=highlighted_sweep,no_show=1)
					endif
				elseif(info.keyCode == 8) // Delete key.  This will remove a sweep from the plot.  
					if(!numtype(highlighted_sweep))
						matching_traces = listmatch(traces,"*sweep"+num2str(highlighted_sweep)+"*")
						for(i=0;i<itemsinlist(matching_traces);i+=1)
							matching_trace = stringfromlist(i,matching_traces)
							RemoveFromGraph /z/w=$info.winName $matching_trace
							Execute /P/Q "DoWindow /F "+info.winName // Move the Sweeps window back to the front at the very end, since the command window gets in the way.  
						endfor
					endif
				endif
			endif
			//print info.eventCode,info.eventName,info.eventMod,info.keyCode
			//if(stringm
			break
	endswitch
end

function AnalysisWinHook(info)
	struct WMWinHookStruct &info
	if(info.eventCode==4)
		return 0
	endif
	variable lock_cursors=Core#VarPackageSetting(module,"random","","lockCursors")
	strswitch(info.eventName)
		case "cursormoved":
			string cursorName=info.cursorname
			nvar /z/sdfr=GetStatusDF() cursorNum=$("cursorSweepNum_"+cursorName)
			Variable value
			Variable sweepNum=info.pointnumber
			if(NVar_exists(cursorNum) && strlen(CsrInfo($cursorName,info.winname)))
				cursorNum=sweepNum
				value=xcsr($cursorName,info.winname)
				//Cursor /H=2/W=Membrane_Constants $cursor_name,$LongestVisibleTrace(win="Membrane_Constants"),value
			endif
			SwitchView("New Sweep")
			if(lock_cursors && StringMatch(cursorName,"A"))
				Variable spacing=10
				Cursor /W=$info.winname B,$LongestVisibleTrace(win=info.winname),value+spacing
				//Cursor /H=2/W=Membrane_Constants B,$LongestVisibleTrace(win="Membrane_Constants"),value+spacing
			endif
			string csr_info = CsrInfo($cursorName)
			string trace = stringbykey("TNAME",csr_info)
			string trace_info = TraceInfo(info.winname,trace,0)
			string y_axis = stringbykey("YAXIS",trace_info)
			variable axis_num
			sscanf y_axis,"Axis_%d",axis_num
			if(strlen(y_axis) && axis_num>=0)
				AnalysisMethodSubSelections(axis_num) // Set analysis method.  
			endif
			break
		case "mouseup":
			Variable xpixel=info.mouseLoc.h
			GetWindow $info.winname wsizeDC
			Variable width=(V_right-V_left)
			variable isNarrow=str2num(getuserdata(info.winname,"","isNarrow"))
			Variable xFrac=(xpixel-105*isNarrow)/(width-105*isNarrow)
			if(xFrac>0 && (xFrac<0.04 || xFrac>0.96)) // Outside the plot area but not in the control bar.  
				Variable ypixel=info.mouseLoc.v
				String axisName=GetYAxisFromClick(ypixel,win=info.winname)
				Variable axisNum
				sscanf axisName,"Axis_%d",axisNum
				if(strlen(axisName) && axisNum>=0)
					AnalysisMethodSubSelections(axisNum) // Set analysis method.  
				endif
			endif
			break
		case "mousedown":
			if(info.mouseLoc.v<0 && (info.eventMod & 16))
				PopupContextualMenu Core#ListPackageInstances(module,info.winname)+"_Save_"
				if(v_flag>=0)
					SelectPackageInstance(info.winname,s_selection)
				endif
			endif
		case "resize":
			if(!WinType(info.winname))
				return -1
			endif
			GetWindow $info.winname,wsizeDC
			variable narrow = (V_right-V_left<900)
			ControlBar /W=$info.winname /L 105*narrow
			SetWindow $info.winname, userData(isNarrow)=num2str(narrow)
			String analysisWinControls="Parameter;Minimum;Value_0;Value_1;SweepNum_A;SweepNum_B"
			if(!narrow)
				analysisWinControls = ReverseListOrder(analysisWinControls)
			endif
			variable numControls=itemsinlist(analysisWinControls)
			variable xx = v_right
			variable i,j
			for(i=0;i<ItemsInList(analysisWinControls);i+=1)
				String controlNames=StringFromList(i,analysisWinControls)
				strswitch(controlNames)
					case "Value_0":
						controlNames = ControlNameList(info.winname,";","column_0_*")
						break
					case "Value_1":
						controlNames = ControlNameList(info.winname,";","column_1_*")
						break
					default:
				endswitch
				for(j=0;j<itemsinlist(controlNames);j+=1)
					string controlName = stringfromlist(j,controlNames)
					ControlInfo /W=$info.winname $controlName
					if(v_disable != 1) // If visible.  
						variable isPopup=(V_flag==3)
						xx -= 80+isPopup*25
						ModifyControl /Z $controlName pos={narrow ? 2 : xx,narrow ? 30+i*25 : numControls-isPopup*3}, win=$info.winname
					endif
				endfor
			endfor
			break
	endswitch
end

Function SelectorHook(info)
	struct WMWinHookStruct &info
	
	if(info.eventCode==4)
		return 0
	endif
	string win = info.winName
	variable i,fsize=GetFontSize()
	string DAQ=GetUserData(win,"","DAQ")
	strswitch(info.eventName)
		case "killvote":
//					if(stringmatch(winname(0,65),fullWin))
//						DoAlert 1,"Are you sure you want to kill this DAQ?\rIt's acquisition will stop.  It can be re-added from the menu."
//						if(v_flag==1)
//							StopAcquisition(DAQ=DAQ)
//							DoWindow /K $fullWin
//						endif
//					endif
			break
		case "moved":
			Struct rect coords
			Struct rect igorCoords
			Core#GetWinCoords(win,coords)
			IgorWinCoords(igorCoords)
			if(coords.top+100<(igorCoords.bottom)*ScreenResolution/72) // If window was not just minimized.  
				if(strlen(DAQ))
					dfref df=GetDaqDF(DAQ)
					variable /g df:left=coords.left, df:top=coords.top, df:right=coords.right, df:bottom=coords.bottom
				endif
			endif
			break
		case "mousedown":
			if(info.eventMod & 16)
				//string DAQs=GetDAQs()
				PopupContextualMenu /N "SelectorContext"
//						if(V_flag==1)
//							MakeQuickPulseSetsPanel(selectorWin=fullWin)
//						elseif(V_flag>=3)
//							DAQ=StringFromList(V_flag-3,DAQs) // Selected DAQ. 
//							String currDAQ=GetUserData(fullWin,"","DAQ") // DAQ of current panel.  
//							if(!StringMatch(DAQ,currDAQ)) // If a different DAQ was selected.  
//								WaveSelector(DAQ=DAQ)
//								DoWindow /B $(currDAQ+"_Selector")
//							endif
//						endif
			endif
			break
	endswitch
End

// Achieves the same function as a scroll bar, by moving all controls up and down together when the scroll wheel moves.  
Function SlideHook(info)
	Struct WMWinHookStruct &info
	
	if(info.eventCode == 22)
		string controls = ControlNameList(info.winName)
		variable i
		for(i=0;i<itemsinlist(controls);i+=1)
			string control = stringfromlist(i,controls)
			ModifyControl $control pos+={0,info.wheelDy}
		endfor
	endif
End

Menu "SelectorContext",contextualmenu, dynamic
	"Quick Pulse Set Maker",/Q,MakeQuickPulseSetsPanel(DAQ=GetWinDAQ())
	"---"
	SubMenu "Show Selector"
		GetDAQInfo(""),/Q,GetLastUserMenuInfo;WaveSelector(DAQ=stringfromlist(0,s_value,","))
	End
	SubMenu "DAQ Instance"
		Core#ListPackageInstances("Acq","DAQs",quiet=1)+"_Save_",/Q,GetLastUserMenuInfo;Core#SelectPackageInstance("Acq","DAQs",s_value)
	End
	SubMenu "Change DAQ Type"
		Core#PopupMenuOptions("Acq","DAQs",GetWinDAQ(),"type",brackets=1,quiet=1),/Q,GetLastUserMenuInfo;Core#SetStrPackageSetting("Acq","DAQs",GetWinDAQ(),"type",ClearBrackets(s_value))
	End
End

Menu "DAQ Instance",contextualmenu, dynamic
	Core#ListPackageInstances("Acq","DAQs",quiet=1),/Q,GetLastUserMenuInfo;Core#SelectPackageInstance("Acq","DAQs",s_value); Core#SetSelectedInstance("Acq","DAQs",s_value)
End

Function MarkSelected(axisNum)
	Variable axisNum
	ModifyGraph /Z axThick=1
	String activeAxis="Axis_"+num2str(axisNum)
	ModifyGraph /Z axThick($activeAxis)=2
	SetWindow kwTopWin userData(activeAxis)=activeAxis
End

// Applies tags in AnalysisWin where the drugs were added and washed out.  
Function DrugTags()
	Wave /Z/T drugInfo=root:status:drugs:info
	Variable i,j,conc,multiplier,thyme; String entry,subentry,name,units,tag_text
	if(!waveexists(drugInfo))
		return 0
	endif
	Variable fsize=GetFontSize()
	for(i=0;i<numpnts(drugInfo);i+=1)
		entry=drugInfo[i]
		tag_text=""
		for(j=0;j<ItemsInList(entry);j+=1)
			subentry=StringFromList(j,entry)
			units=StringFromList(3,subentry,",")
			if(strlen(units)>2)
				multiplier=str2num(units[0,strlen(units)-4])
				units=units[strlen(units)-2,strlen(units)-1]
			else
				multiplier=1
			endif
			conc=str2num(StringFromList(2,subentry,","))
			name=StringFromList(1,subentry,",")
			thyme=str2num(StringFromList(0,subentry,","))
			tag_text+=num2str(conc*multiplier)+" "+units+" "+name+"\r"
		endfor
		tag_text=tag_text[0,strlen(tag_text)-2]
		if(StringMatch(tag_text,"*Washout*"))
			tag_text="All drugs washed out"
		endif
		if(strlen(axisInfo("AnalysisWin","time_axis")))
			Tag /W=AnalysisWin /F=0/B=1/X=0/Y=40 time_axis,thyme,"\Z"+num2ndigits(fsize-1,2)+tag_text
		endif
	endfor
End

// Makes all traces on the graph containing "R1" red, "L2" blue, and "B3" green
Function ChannelColorCode([traces,win])
	String win,traces
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	traces = selectstring(!paramisdefault(traces),TraceNameList(win,";",3),traces)
	Variable i
	String trace,channel
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		channel=Trace2Channel(trace,win=win)
		Variable red,green,blue; GetChannelColor(channel,red,green,blue)
		ModifyGraph /W=$win rgb($trace)=(red,green,blue)
	endfor
	KillVariables /Z red,green,blue
End

Function AnalysisWinButtons(info) : ButtonControl
	struct wmbuttonaction &info
	
	if(info.eventCode!=2)
		return 0
	endif
	strswitch(info.ctrlName)
		case "AnalysisSelect":
			ControlInfo AnalysisSelector
			AnalysisSelector(V_flag)
			break
		case "EditAnalysisMethods":
			Core#EditModule(module,package="AnalysisMethods")
			break
		case "RegressionLine":
			RegressionLine()
			break
		case "Normalize":
			NormalizeToRegion()
			break
		case "Scale":
			Variable axisNum=SelectedAxis()
			if(axisNum<0)
				DoAlert 0,"No axis is active."
				return -1
			endif
			string csr_trace = CursorTrace("A",win=info.win)
			string axis = TraceYAxis(csr_trace,win=info.win)
			string target_axis = "axis_"+num2str(axisNum)
			if(stringmatch(axis,target_axis))
				wave w = TraceNameToWaveRef(info.win,csr_trace)
				wavestats /q/r=(xcsr(A),xcsr(B)) w
				variable range = v_max-v_min
				SetAxis /W=$info.win $target_axis,v_min-range/5,v_max+range/5
			else	
				SetAxis /W=$info.win /A=2 $target_axis
			endif
			break
		case "Recalculate":
			Recalculate()
			break
	endswitch
	SetDataFolder root:
End

Function Colorize(chan,trace[,win])
	variable chan
	string trace,win
	
	win=selectstring(!ParamIsDefault(win),WinName(0,1),win)
	variable red,green,blue; GetChanColor(chan,red,green,blue); 
	ModifyGraph /W=$win rgb($trace)=(red,green,blue)
End

Function /S Trace2Channel(trace[,win])
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String folder=GetTraceDataFolder(trace,win=win)
	Wave /T Labels=GetChanLabels()
	if(StringMatch(trace,"input_*"))
		variable chan
		sscanf trace,"input_%d",chan
		return Labels[chan]
	else
		FindValue /TEXT=(folder) /TXOP=4 Labels
		if(V_Value>=0)
			return Labels[V_Value]
		else
			return Labels[0] // Error condition.  
		endif
	endif
End

//Function /S Direction2Color(pre,post)
//	String pre,post
//	Variable red1,green1,blue1,red2,green2,blue2
//	Channel2Colour(pre,red1,green1,blue1)
//	Channel2Colour(post,red2,green2,blue2)
//	Variable red=0.5*red1 + red2
//	Variable green=0.5*green1 + green2
//	Variable blue=0.5*blue1 + blue2
//	return num2str(red)+";"+num2str(blue)+";"+num2str(green)
//End

Function Channel2Marker(channel)
	String channel
	strswitch(channel)
		case "R1":
			return 19 // Circle
			break
		case "L2":
			return 16 // Square
			break
		case "B3":
			return 17 // Triangle
			break
		default:
			return 1
			break
	endswitch
End

