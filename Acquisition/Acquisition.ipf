// $Author$
// $Rev$
// $Date$

#pragma rtGlobals=1		// Use modern global access method.

#include "Basics"

#include ":Acquisition Settings"
#include ":Acquisition Wave Functions"
#include ":Acquisition Windows"
#include ":Analysis"
#include ":DAQ Interface"
#include ":Experiment Facts"
#include ":Seal Test"
#include ":SuperClamp"
#include ":Values"

static strconstant module=Acq

// --------------------------------------------------------Menu Procedures ----------------------------------------------------------------------
Menu "Ac&quisition" , dynamic			
	"Initialize Experiment From Scratch",/Q,Initialization()
	SubMenu "&Initialize Experiment From Saved Settings"
		Core#ListPackageInstances("Acq","Acq",quiet=0,load=1,onDisk=1),/Q,GetLastUserMenuInfo;Initialization(acqInstance=s_value) // TO DO: Add acqInstance="last"
	End
	SelectString(GetAcqInited(),"","Super&Clamp"),/Q,SuperClamp()
	SelectString(GetAcqInited(),"","&Log Panel"),/Q,MakeLogPanel()
	SelectString(GetAcqInited(),"","&Selector"),/Q,DoWindow /F Selector
//	SubMenu "Load Channel Config"
//		UnloadedPackageInstances("channelConfigs"),/Q,LoadPackageInstanceFromMenu("channelConfigs")
//	End
//	SubMenu "Load Stimulus"
//		UnloadedPackageInstances("stimuli"),/Q,LoadPackageInstanceFromMenu("stimuli")
//	End
End

Function GetAcqInited()
	variable result=0
	dfref df=GetStatusDF(create=0)
	if(datafolderrefstatus(df))
		nvar /z/sdfr=df acqInit
		if(NVar_Exists(acqInit) && acqInit)
			result=1
		endif
	endif
	return result
End

Function SetAcqInited(val)
	variable val
	variable err=0
	dfref df=GetStatusDF(create=0)
	if(datafolderrefstatus(df))
		nvar /z/sdfr=df acqInit
		if(nvar_exists(acqInit))
			acqInit=val
		else
			printf "Could not find the variable %s in data folder %s.\r","acqInit",getdatafolder(1,df)
			err=-2
		endif
	else
		printf "Could not find the status data folder to mark acquisition as initialized.\r"
		err=-1
	endif
	return err
End

// --------------------------------------------------------Initialization Routines ------------------------------------------------------
Function Initialization([profileName,acqInstance])
	string profileName
	string acqInstance // Name of an acquisition instance to load.  
	
	// Don't let initialization begin if the current experiment contains data.  
	if(GetCurrSweep()>0)
		DoAlert 0,"You must select 'File/New Experiment' from the Igor Menu or 'Reset' from the 'Selector' window to clear the current data."
		return -1
	endif
	
	profileName=selectstring(!paramisdefault(profileName),Core#CurrProfileName(),profileName)
	struct core#profileInfo profile
	Core#GetProfileInfo(profile)
	acqInstance=selectstring(!paramisdefault(acqInstance),"_default_",acqInstance)
	acqInstance=InitializeVariables(acqInstance=acqInstance)			// Calls profile-defined parameters in Values.ipf
	Core#SetSelectedInstance(module,"Acq",acqInstance)
	
	variable defaults=stringmatch(acqInstance,"_default_")

	variable fsize=GetFontSize()
	DefaultGuiFont all= {"Arial",fsize,0}
	Make /o/D/n=0 root:SweepT // Time of each sweep, in minutes since experiment start.  
	BoardInit() // Initializes A/D Interface.  
	DoWindow /K Selector
	
	string sweepsWinInstance = Core#StrPackageSetting(module,"Acq",acqInstance,"sweepsWin")
	SweepsWindow(instance=sweepsWinInstance)
	
	string analysisWinInstance = Core#StrPackageSetting(module,"Acq",acqInstance,"analysisWin")
	AnalysisWindow(instance=analysisWinInstance)
	
	string defaultDataDir=SpecialDirPath("Desktop",0,0,0)+"Data"
	string dataDir=Core#StrPackageSetting(module,"random","","dataDir",default_=defaultDataDir)
	NewPath /C/Z/O/Q Data, dataDir
	if(v_flag)
		NewPath /C/O/Q Data, defaultDataDir
	endif
	string extension=".pxp"
	PutScrapText NewFileName(path="Data")+extension
	SaveExperiment /P=Data //as NewFileName()+".uxp"//  Sets experiment name
	
#if exists("Sutter#Init")==6
	Sutter#Init()
#endif
#if exists("AxonTelegraphFindServers") && exists("InitAxon")
	InitAxon()
#endif
// Urban Legend initialization hooks.  	
#ifdef UL
	UL#AcqInit()
#endif
	Variable /G root:status:acqInit=1
	string how,init_msg = "Initialized experiment %s @ %s\r"
	if(defaults)
		how = "using default acquisition settings"
	else
		sprintf how,"from Acquisition instance %s",acqInstance
	endif
	printf init_msg,how,time()
End

Function /s InitializeVariables([acqInstance,noContainers,quiet])
	string acqInstance // Name of an acquisition instance to load.  
	variable noContainers,quiet
	
	if(paramisdefault(acqInstance) || stringmatch(acqInstance,"_default_") || !strlen(Core#InstanceDiskLocation(module,module,acqInstance,quiet=quiet)))
		variable default_=1
		acqInstance="_default_"
	endif
	
	// Status variables.  
	variable i,j
	dfref df=GetStatusDF()						// This folder contains data that describe the status of the current experiment.  
	variable /g df:currSweep = 0					// The number of the current sweep.  
	variable /g df:waveformSweeps = 0				// The number of sweeps under the current stimulation conditions.  
	variable /g df:newWaveForms					// (1) if the waveForms of the current sweep are different from those of the last sweep.  
	variable /g df:expStartT						// Start time of the experiment, in seconds since 1/1/1904.  
	variable /g df:bootT							// Start time relative to the computer being booted up in microseconds.  
	variable /g df:waveformStartT = 0				// Time when the most recent waveforms were selected,  in seconds relative to the experiment start time. 
	variable /g df:lastSweepT = 0					// Time of most recent sweep, in microseconds since boot.     
	
	variable /g df:lastSaveSweep=0					// The sweep number when the experiment was last saved.  
	variable /g df:lastSaveT=0						// The time since boot (in microseconds) when the experiment was last saved.  
	variable /g df:cursorSweepNum_A=0			// The sweep number for cursor A.  
	variable /g df:cursorSweepNum_B=0			// The sweep number for cursor B.  
	variable /g df:codeVersion=Core#SVNVersion()	// The version of the code used in this experiment.  
	
	dfref drugsDF=GetDrugsDF()					// This folder keeps track of pharamacology.  	
	make /O/T/N=0 drugsDF:info					// A wave containing all the information about when drugs were added and washed out.  
	make /O/T/N=1 drugsDF:history=""				// A wave contains the drug state during each sweep.  

	// Load all packages for this profile.    
	String packages=Core#ListPackages(modules=module,quiet=quiet)
	if(default_)
		Core#LoadDefaultPackages(module,packages=packages,quiet=quiet)
	endif
	String packageInstancesLoaded=Core#LoadPackages(module,packages=packages,quiet=quiet)
	
	// Load current DAQs.  
	variable chan=0
	if(default_)
		make /free/t/n=1 acqInstanceDAQs="_default_"
	else
		wave /t acqInstanceDAQs=Core#WavPackageSetting(module,module,acqInstance,"DAQs",quiet=quiet)
	endif
	for(i=0;i<numpnts(acqInstanceDAQs);i+=1)
		string DAQ=Core#InstanceOrDefault(module,"DAQs",acqInstanceDAQs[i],quiet=quiet)
		InitDAQ(i,instance=DAQ,quiet=quiet)
		if(default_)
			make /free/t/n=1 daqInstanceChannelConfigs="_default_"
		else
			wave /t daqInstanceChannelConfigs=Core#WavPackageSetting(module,"DAQs",DAQ,"channelConfigs",quiet=quiet)	
		endif
		DAQ=GetDaqName(i)
		for(j=0;j<numpnts(daqInstanceChannelConfigs);j+=1)
			string channelConfigInstance=Core#InstanceOrDefault(module,"channelConfigs",daqInstanceChannelConfigs[j],quiet=quiet)
			string chanName=GetChanName(chan)
			InitChan(chan,DAQ=DAQ,instance=selectstring(default_,channelConfigInstance,"_default_"),noContainer=noContainers,quiet=quiet)
			chan+=1
		endfor
		for(j=chan-1;j>=0;j-=1)
			SetUniqueChanLabel(j,quiet=quiet)
			SetUniqueChanColor(j,quiet=quiet)
		endfor
	endfor
	
	return acqInstance
End

// ------ Constants ------

Function SetNumChannels(info) : SetVariableControl
	STRUCT WMSetVariableAction &info
	
	if(!SVInput(info.eventCode))
		return -1
	endif
	string DAQs=GetDAQs()
	String DAQ=GetUserData(info.win,"","DAQ")
	dfref daqDF=GetDaqDF(DAQ)
	
	variable targetNumDAQChannels=info.dval // The global variable that is tied to this SetVariable.  	
	variable oldNumDAQChannels=str2num(GetUserData("","NumChannels",""))
	variable deltaChannels=targetNumDAQChannels-oldNumDAQChannels
	if(deltaChannels==0)
		return 0 // No more channels to add or remove.  
	endif
	//Wave ActiveChannels, ChannelSaveMode
	//Wave /T ChannelDAQ
	Do
		oldNumDAQChannels=str2num(GetUserData(info.win,"NumChannels",""))
		deltaChannels=targetNumDAQChannels-oldNumDAQChannels
		if(deltaChannels==0)
			break // No more channels to add or remove.  
		endif
		Variable numDAQChannels=oldNumDAQChannels+sign(targetNumDAQChannels-oldNumDAQChannels) // Add or remove at most one channel in each iteration of the loop.  
		SetVariable NumChannels, userData=num2str(numDAQChannels), win=$info.win
		wave /t DAQchannelConfigs=Core#WavTPackageSetting(module,"DAQs",DAQ,"channelConfigs")
		redimension /n=(numDAQChannels) DAQchannelConfigs
		
		Variable i,j
		if(deltaChannels>0) // Increase in the number of channels.  
			Variable chan=GetNumChannels()-1
			Variable add=1
		elseif(numDAQChannels<oldNumDAQChannels) // Decrease in the number of channels.  
			chan=GetNumChannels()
			add=0
		else
			break // No change in the number of channels.  
		endif
		
		// Fix the part below.  Doesn't work if you remove "ch2", because "ch3" will become "ch2".  
		if(add) // Add channel.  
			DAQchannelConfigs[chan]=Core#DefaultInstance(module,"DAQs")
			ActivateChan(chan,DAQ=DAQ)
			i+=1
		else // Remove channel.  
			//if(numpnts(Labels)>chan) // To avoid killing data folders we just created.  
			RemoveFolderFromGraph(chanDF,win="AnalysisWin")
			PossiblyKillOldChannelFolder(GetChanLabel(chan))
			//endif
		endif
	While(1)
	
	// Redraw all selector windows.  
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String oneDAQ=StringFromList(i,DAQs)
		Variable winExist=WinType(oneDAQ+"_Selector")
		if(winExist)
			
			RedrawSelector(win=oneDAQ+"_Selector")
		endif
	endfor
	DoWindow /F $(DAQ+"_Selector") // Bring current selector window back to the front.  
	
	// Update Sweeps Window.  
	ControlBar /T/W=SweepsWin max(3,GetNumChannels())*18+3 
	SwitchView("")
	
	struct wmwinhookstruct info2
	info2.winname = "sweepsWin"
	info2.eventName = "resize"
	SweepsWinHook(info2) // Mark Sweeps window as resized.  
End

function ActivateChan(chan[,DAQ])
	variable chan
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ) && strlen(DAQ),Chan2DAQ(chan),DAQ)
	//dfref chanDF=GetChanDF(chan,create=1)
	InitChan(chan,DAQ=DAQ)
	Core#SetVarPackageSetting(module,"channelConfigs",GetChanName(chan),"active",1)
	Checkbox $("Show_"+num2str(chan)), value=1, win=SweepsWin
	dfref daqDF=GetDaqDF(DAQ)
	//wave /z input=daqDF:$("input_"+num2str(chan))
	//if(!waveexists(input))
	variable duration=GetDuration(DAQ)
	variable kHz=GetKhz(DAQ)
	make /o/n=(round(kHz*duration*1000)) daqDF:$("input_"+num2str(chan)) /WAVE=NewInput
	SetScale x,0,duration,NewInput
	NewInput=0
	//endif
end

Function InitChan(chan[,DAQ,instance,noContainer,label_,quiet])
	Variable chan
	string DAQ,instance,label_
	variable noContainer,quiet
	
	string name=GetChanName(chan)
	string instance_label = Core#StrPackageSetting(module,"channelConfigs",name,"label_")
	label_ = selectstring(!paramisdefault(label_),instance_label,label_)
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(quiet=quiet),DAQ)
	string context
	sprintf context,"_chan_:%d",chan
	if(paramisdefault(instance) || stringmatch(instance,"_default_"))
		Core#InheritInstancesOrDefault(module,"DAQs","channelConfigs",{name},parentInstance=DAQ,context=context,quiet=quiet)
	else
		Core#CopyInstance(module,"channelConfigs",instance,name,context=context,quiet=quiet)
	endif
	Core#SetStrPackageSetting(module,"channelConfigs",name,"DAQ",DAQ,quiet=quiet)
	Core#InheritInstancesOrDefault(module,"channelConfigs","stimuli",{name},parentInstance=name,context=context,quiet=quiet)
	Core#InheritInstancesOrDefault(module,"channelConfigs","filters",{name},parentInstance=name,context=context,quiet=quiet)
	//SetAcqSetting("channelConfigs",name,"DAQ",DAQ)
	SetUniqueChanLabel(chan,label_=label_,quiet=quiet)
	SetUniqueChanColor(chan,quiet=quiet)
	wave /z chanHistory=GetChanHistory(chan,quiet=quiet)
	if(!waveexists(chanHistory) && !noContainer)
		InitChanContainer(chan,quiet=quiet)
	endif
End

function InitChanContainer(chan[,quiet])
	variable chan,quiet
	
	dfref df=GetChanDF(chan,create=1)
	string label_=Chan2Label(chan)
	// For saving all of the parameters of each sweep.  
	// Format is rows=sweepNum, columns=param, layers=pulse_set.  
	nvar /sdfr=GetStatusDF() currSweep
	make /o/n=(max(1,currSweep),ItemsInList(pulseParams),1) df:$chanHistoryName /wave=w=NaN
	LabelChanHistory(w)
	
	// Make waves to hold the analysis values for analysis methods active on this channel.  
	wave /t analysisMethods=Core#WavTPackageSetting(module,"channelConfigs",GetChanName(chan),"analysisMethods")
	variable i
	for(i=0;i<numpnts(analysisMethods);i+=1)
		string method=analysisMethods[i]
		wave /z w=df:$method
		if(!waveexists(w) && strlen(method))
			make /o/n=0 df:$method
		endif
	endfor
end

Function LabelChanHistory(w)
	wave w
	
	variable j
	SetDimLabel 0,-1,Sweep,w
	for(j=0;j<ItemsInList(pulseParams);j+=1)
		String pulse_param=StringFromList(j,pulseParams)
		SetDimLabel 1,j,$pulse_param,w
	endfor
	SetDimLabel 2,-1,Pulse_Set,w
End

// Kill the default folder for this channel if it has not been used.  
Function PossiblyKillOldChannelFolder(oldLabel[,secondTry])
	string oldLabel
	variable secondTry
	
	dfref df=GetChannelDF(oldLabel)
	if(datafolderrefstatus(df))	
		variable i
		for(i=0;i<CountObjectsDFR(df,4);i+=1)
			string name=GetIndexedObjNameDFR(df,4,i)
			if(stringmatch(name,chanHistoryName))
				wave w=df:$name
				if(dimsize(w,0)>0) // Some stimulus information has been stored.  
					return 0
				endif
			elseif(stringmatch(name,"sweep*")) // Possibly a sweep wave.  
				wave w=df:$name
				if(dimsize(w,1)<=1) // Not a stimulus history wave.  
					return 0
				endif
			endif
		endfor
		if(datafolderrefstatus(df))
			KillDataFolder /Z df
			variable killed=!v_flag
			if(!killed && secondTry==0) // Not killed because folder could not be killed (waves in use).  
				AnalysisWindow() // Reload the analysis window so that old data is cleared from it.  
				killed=PossiblyKillOldChannelFolder(oldLabel,secondTry=1) // Try again.  
			endif
		endif
	endif
	return killed // A folder was killed.  
End

Function SetInputWaves([DAQ])
	String DAQ
	
	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())
	
	dfref df=GetDaqDF(DAQ)
	svar /sdfr=df inputWaves; inputWaves=""
	variable i,numChannels=GetNumChannels()
	variable input_scaling_factor
	for(i=0;i<numChannels;i+=1)
		if(!IsChanActive(i) || IsChild(i)>=0 || !StringMatch(Chan2DAQ(i),DAQ))
			continue
		endif	
		if(StringMatch(Chan2ADC(i),"N")) // If the physical channel is set to NULL, don't acquire input on this channel.  
			inputWaves+="Null,N;"
			continue
		endif
		//String name=Labels[i]
		ControlInfo /W=$(DAQ+"_Selector") $("Mode_"+num2str(i))
		String mode=S_Value
		Variable mode_num=V_Value-1
		Variable inputGain=GetModeInputGain(mode)
		input_scaling_factor=1000 / inputGain // 1000 comes from converting from mV (units for inputGain numerator) to V (actual digitizer output).  
		strswitch(DAQType(DAQ))
			case "NIDAQmx":
				String isf=",-10,10,"+num2str(input_scaling_factor) // If using a NIDAQ MX board, minimum (-10) and maximum (10) voltages must be in the string	
				break
			default:
				isf=""
				break
		endswitch
		String str=joinpath({getdatafolder(1,df),"input_"+num2str(i)})+","+Chan2ADC(i)+isf
		inputWaves+=str+";" 
	endfor
End

Function SetOutputWaves([sweepNum,DAQ])
	Variable sweepNum
	String DAQ
	
	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())
	dfref df=GetDaqDF(DAQ)
	svar /sdfr=df outputWaves; outputWaves=""
	variable currSweep=GetCurrSweep()
	sweepNum=ParamIsDefault(sweepNum) ? currSweep : sweepNum
	
	variable i,numChannels=GetNumChannels()
	string channel
	wave /sdfr=df LCM_
	for(i=0;i<numChannels;i+=1)
		if(!IsChanActive(i) || IsChild(i)>=0 || !StringMatch(Chan2DAQ(i),DAQ))
			continue
		endif
		if(StringMatch(Chan2DAC(i),"N")) // If the physical channel is set to NULL, don't use this channel for output.  
			outputWaves+=",N;"
			continue
		endif
		Variable remain=mod(sweepNum,LCM_[i])
		ControlInfo /W=$(DAQ+"_Selector") $("Mode_"+num2str(i))
		String mode=S_Value
		Variable mode_num=V_Value-1
		Variable outputGain=GetModeOutputGain(mode)
		string type=DAQType(DAQ)
		if(StringMatch(type,"NIDAQmx"))
			outputGain*=1000 // Convert from a denominator of mV to a denominator of V.  
		endif
		
		outputWaves+=joinpath({getdatafolder(1,df),"Stimulus_"+num2str(i)})+","+Chan2DAC(i)+";" 
		// Channels must be added to output waves in the correct order, e.g. channel 0, channel 1, etc.
		wave raw=df:$("Raw_"+num2str(i))
		duplicate /o raw,df:$("Stimulus_"+num2str(i)) /WAVE=stim
		if(dimsize(raw,0) && dimsize(raw,1))
			matrixop /o stim=rotatecols(raw,-sweepNum)
		else
			stim=raw
		endif
		if(stringmatch(DAQ,"NIDAQmx"))
			redimension /n=(dimsize(stim,0)) stim // Only keep first column.  
		else
			variable lcm=wavemax(LCM_,0,numChannels-1)
			redimension /n=(dimsize(stim,0),lcm) stim
			stim=stim[p][mod(dimsize(raw,1),q)]
		endif
		if(!StringMatch(Chan2DAC(i),"D")) // Unless this command is being sent to a digital channel.  
			Stim/=outputGain // Scale according to the command gain
			// Alternatively, set the acquisition mode to "Unity" in the Selector panel so that gains will be 1.  
		endif
		WaveClear Stim
	endfor
End

function /s GetListenHook(DAQ)
	string DAQ
	
	if(!strlen(DAQ))
		DAQ=MasterDAQ()
	endif
	return Core#StrPackageSetting(module,"DAQs",DAQ,"listenHook")
end

// If the given Igor channel is a child of another channel (same raw data, different filter settings), returns the channel number; otherwise returns -1.    
Function IsChild(chan)
	variable chan
	wave /T Labels=GetChanLabels()
	variable i
	string childLabel=Labels[chan]
	for(i=0;i<numpnts(Labels);i+=1)
		String labell=Labels[i]
		if(StringMatch(childLabel,labell+"_*"))
			return i
		endif
	endfor
	return -1
End

Function FinalUpdate([DAQ])
	String DAQ
	
	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())
	variable err=0
	err+=1*WaveUpdate(DAQ=DAQ)
	err+=10*SetInputWaves(DAQ=DAQ)
	err+=100*SetOutputWaves(DAQ=DAQ)
	variable startTrigger=Core#VarPackageSetting("Acq","DAQs",DAQ,"startTrigger",default_=6)
	err+=1000*SetupTriggers(startTrigger,DAQs=DAQ) // Setup pin 6 to be the trigger for starting stimulation
	err+=10000*SwitchView("") // Update the window "Sweeps"
	SetListenHook("CollectSweep(\"_daq_\")",DAQ=DAQ)
	
	if(err)
		printf "%s returned with error code %d",GetRTStackInfo(1),err
		return err
	else
		return 0
	endif
End

// ----------------------------------------------------Data Collection ----------------------------------------------------
Function StartSweep([DAQ])
	String DAQ
	
	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())
	
	nvar /sdfr=GetStatusDF() currSweep,waveformSweeps,waveformStartT,expStartT
	dfref df=GetDaqDF(DAQ)
	variable /g df:chanBits=0
	nvar /z/sdfr=df acquiring,boardGain,isi,continuous,chanBits
	if(!nvar_exists(acquiring)) // This DAQ may have come online after the experiment was initialized.  
		string DAQs=GetDAQs()
		variable daqNum=WhichListItem(DAQ,DAQs)
		InitDAQ(daqNum)
	endif
	svar /sdfr=df outputWaves,inputWaves 
	variable i,numChannels=GetNumChannels(DAQ=DAQ)
	for(i=0;i<numChannels;i+=1)
		chanBits+=2^i *IsChanActive(i) * !StringMatch(Chan2ADC(i),"N") * StringMatch(Chan2DAQ(i),DAQ) 
	endfor
	
	if(waveformSweeps)
		waveformStartT= datetime - expStartT
		waveformSweeps = 0
	endif
	
	Variable err=FinalUpdate(DAQ=DAQ)
	if(err)
		return err
	endif
	acquiring=1
	Speak(1,outputWaves,SelectNumber(continuous,32,0),DAQs=DAQ)
	Listen(1,boardGain,inputWaves,5,continuous,"CollectSweep("+DAQ+")","ErrorSweep()","",DAQs=DAQ)
	if(InDynamicClamp())
		LoadDynamicClampMode()
	endif
	
	if(currSweep==0)
		ResetExperimentClock()
	endif
#ifdef Img
	AcquireMovie(now=0)
#endif
	if(StartClock(isi,DAQs=DAQ)) // If Start_Clock returns an error.  
		StopAcquisition(DAQ=DAQ) // Stop acquisition.  
	endif
End

Function CollectSweep(DAQ) // This function is called when the input data has been collected.  
	string DAQ
	
	nvar /sdfr=GetStatusDF() currSweep,bootT,waveformSweeps,lastSweepT,lastSaveSweep,lastSaveT
	dfref df=GetDaqDF(DAQ)
	nvar /sdfr=df ISI,duration,continuous,realTime,chanBits,sweepsLeft,lastDAQSweepT
	svar /sdfr=df inputWaves,outputWaves,saveMode
	wave /sdfr=root: SweepT
	variable dynamic=InDynamicClamp()
	if(!realTime && stringmatch(DAQType(DAQ),"ITC") && !dynamic)
		InDemultiplex(inputWaves,DAQs=DAQ) // Only applies to ITC.  
	endif
	variable i; string channel=""
	variable numChannels=GetNumChannels()
	for(i=0;i<numChannels;i+=1)
		if(chanBits & 2^i)
			CollectSweepIndividual(i,currSweep,DAQ)
		endif
	endfor
	
	//Wave DAQsCompleted=root:DAQ:DAQsCompleted
	//Redimension /n=(currSweepNum+1,ItemsInList(DAQs))DAQsCompleted
	//DAQsCompleted[currSweepNum][FindDimLabel(DAQsCompleted,1,daqType)]+=1
	//MatrixOp /o sweepDAQsCompleted=row(DAQsCompleted,currSweepNum)
	//WaveStats /Q/M=1 sweepDAQsCompleted
	//KillWaves /Z sweepDAQsCompleted
	//if(V_min>=1) // If all the DAQs have completed and gotten through CollectSweep, it is finally time to run this last section.  
	if(sweepsLeft==1)
		StopAcquisition(DAQ=DAQ)
	else
		FuncRef Speak DAQ_Speak=$(DAQType(DAQ)+"#Speak")
		FuncRef Listen DAQ_Listen=$(DAQType(DAQ)+"#Listen")
		if(continuous && !dynamic)
			if(NumOutputs(DAQ))
				if(StringMatch(DAQType(DAQ),"NIDAQmx"))
					lastDAQSweepT+=duration*1000000
				endif
				wave Divisor=GetDAQDivisor(DAQ)
				WaveStats /Q/M=1 Divisor
				if(V_max>1) // If there are different stimuli for each sweep.  
					SetOutputWaves(sweepNum=currSweep+2) // Must be two sweeps ahead because currSweepNum hasn't been incremented and stimulus buffer is being padded one sweep ahead.  
				endif
				//if(!stringmatch(DAQ,"LIH"))
				//	DAQ_Speak(1,outputWaves,64,now=1) // Add the next stimulus to the stimulus buffer.  (ITC18 only).  
				//endif
			endif
		else
			//SpeakReset(1) // Really slow on ITC (and unnecessary).  
			string feedbackProcess=Core#StrPackageSetting(module,"random","","feedbackProcess")
			if(strlen(feedbackProcess))
				FeedbackProc(feedbackProcess)
			endif
			if(!stringmatch(DAQType(DAQ),"LIH") && !dynamic)
				SetOutputWaves(sweepNum=currSweep+1)
				DAQ_Speak(1,outputWaves,32,DAQs=DAQ) // For NIDAQ
				DAQ_Listen(1,1,inputWaves,5,0,"CollectSweep(\""+DAQ+"\")","ErrorSweep(\""+DAQ+"\")","",DAQs=DAQ) // For NIDAQ
			endif
			// This should come as early as possible to avoid large gaps between sweeps when the duration is almost as large as the ISI
		endif
		sweepsLeft=(sweepsLeft==0) ? 0 : sweepsLeft-1
	endif
		
	if(WhichListItem(DAQ,MasterDAQ())==0) // If this is the master DAQ.  
		// Finish up tasks for this sweep.  
		lastSweepT=lastDAQSweepT // Set the sweep time to be the sweep time for the master DAQ. 
		SweepT [currSweep] = {(lastSweepT-bootT) / (60*1000000)} // Convert from microseconds to minutes.  
		//UpdateDrugs() // TO DO: Add this back.  
		SaveSweepParameters()
		OnlineAnalysis(ISI)
		currSweep+=1
		BumpRemainderBoxes(DAQ=DAQ)
		waveformSweeps+=1
		if(wintype("SweepIndexWin"))
			variable val=CtrlNumValue("sweepIndex",win="SweepIndexWin")
			setvariable sweepIndex value=_NUM:mod(val+1,100), win=SweepIndexWin
		endif
		variable saveMode_=whichlistitem(saveMode,SaveModes(DAQ))
		if(saveMode_==3 && lastSaveSweep<currSweep && lastSaveT<(StopMSTimer(-2)-1000000)) // If auto_save is on and if the experiment has not been saved since the last sweep was collected
			SaveExperiment
			lastSaveSweep=currSweep
			lastSaveT=StopMSTimer(-2)
		endif
	else
		SlaveHook(DAQ)
	endif
#ifdef Rick
	//ISI=10+floor(abs(enoise(10)))
#endif
#ifdef Aryn
	//printf "We injected %d pA\r",GetCurrent()
#endif
	//endif
End

Function CollectSweepIndividual(chan,currSweepNum,DAQ)
	variable chan,currSweepNum
	string DAQ
	
	dfref daqDF=GetDaqDF(DAQ)
	nvar /sdfr=daqDF realTime
	svar /sdfr=daqDF saveMode
	string inputWaveTemplate="input_%d"
	string inputWaveName
	sprintf inputWaveName,inputWaveTemplate,chan
	inputWaveName=joinpath({getdatafolder(1,daqDF),inputWaveName})
	wave InputWave=$inputWaveName
	variable parent=IsChild(chan)
	
	// Finally copy a hidden sweep onto the current sweep, so the visible sweep is always all-filtered or all-unfiltered.  
	if(!realTime && stringmatch(DAQType(DAQ),"LIH"))
		wave /z Clone=$(inputWaveName+"_buff")
		if(waveexists(Clone))
			duplicate /o Clone $inputWaveName
		endif
	endif
	
	// If this channel is a child of a parent channel.  
	if(parent>=0)
		string parentWaveName
		sprintf parentWaveName,inputWaveTemplate,parent
		Duplicate /o $parentWaveName $inputWaveName // Copy data from the parent channel.  
	endif	
	
	string chanSaveMode=GetChanSaveMode(chan)
	if(stringmatch(chanSaveMode,"Filtered")) // Filter before saving.  
		ApplyFilters(InputWave,chan)
	endif
	
	// Save the sweep to the corresponding channel folder.  
	strswitch(Chan2ADC(chan))
		case "N": // Null input channel.  
			break // Do nothing.  
		default:
			dfref chanDF=GetChanDF(chan)
			if(parent<0 && !stringmatch(chanSaveMode,"No Save") && !stringmatch(saveMode,"Nothing"))
				string destName="sweep"+num2str(currSweepNum)
				wave /Z Sweep=chanDF:$destName
				if(WaveExists(Sweep) && WhichListItem(DAQ,MasterDAQ())!=0) // If the sweep exists and this is not the master DAQ.  
					redimension /n=(-1,dimsize(Sweep,1)+1) Sweep // Add a column to the destination wave.  
					Sweep[][dimsize(Sweep,1)-1]=InputWave[p] // And fill it.  
				else	
					Duplicate /O InputWave chanDF:$destName /WAVE=Sweep // Create a new destination wave.  
				endif
				string timeStamp
				sprintf timeStamp "TIME=%f",StopMSTimer(-2) // Time since boot. 
				Note Sweep timeStamp
#ifdef UL
				UL#AcqBind(Sweep,"scope")
#endif
			endif
			break
	endswitch
	
	if(!stringmatch(chanSaveMode,"Filtered")) // Filter after saving.  
		ApplyFilters(inputWave,chan)
	endif
End

function /df GetDrugsDF()
	dfref df=GetStatusDF()
	string name="drugs"
	newdatafolder /o df:$name
	dfref drugsDF=df:$name
	return drugsDF
end

// Assumes there are 4 rows in the drug window (maximum 4 drugs at once)
Function UpdateDrugs()
	string drugs=""
	dfref df=GetDrugsDF()
	wave /sdfr=df drug,conc
	wave /t/sdfr=df name,units,history
	variable i
	for(i=0;i<=numpnts(drug);i+=1)
		if(drug)
			drugs+=name[i]+","+num2str(conc[i])+" "+units[i]+";"
		endif
	endfor
	variable sweep=GetCurrSweep()
	Redimension /n=(sweep+1) history
	history[sweep]=drugs
End

// Save parameters for the last sweep
Function SaveSweepParameters()
	variable sweep=GetCurrSweep()
	string channel
	variable i,j,k,numChannels=GetNumChannels()
	string acqModes=Core#ListPackageInstances(module,"acqModes")
	string params=Core#ListPackageObjects(module,"stimuli")
	for(i=0;i<numChannels;i+=1)
		wave chanHistory=GetChanHistory(i)	
		string DAQ=Chan2DAQ(i)
		variable pulseSets=GetNumPulseSets(DAQ)
		variable rows=max(dimsize(chanHistory,0),sweep+1)
		variable cols=ItemsInList(pulseParams) // TO DO: Make columns equal to the number of wave objects in the stimulus package.  
		variable layers=max(dimsize(chanHistory,2),pulseSets)
		Redimension/n=(rows,cols,layers) chanHistory
		if(IsChanActive(i))
			string name=GetChanName(i)
			dfref stimDF=Core#InstanceHome(module,"stimuli",name)
			for(j=0;j<pulseSets;j+=1)
				for(k=0;k<ItemsInList(params);k+=1)
					string param=StringFromList(k,params)
					string type=Core#ObjectType(joinpath({getdatafolder(1,stimDF),param}))
					variable col=FindDimLabel(chanHistory,1,param)
					strswitch(type)
						case "WAV":
							wave /z w=Core#WavPackageSetting(module,"stimuli",name,param)
							if(waveexists(w))
								chanHistory[sweep][col][j]=w[j] // Fill in the current sweep's parameter values
							endif
							break
					endswitch
				endfor
			endfor
			SetDimLabel 0,sweep,$GetAcqMode(i),chanHistory
		else
			chanHistory[sweep][][]=NaN
		endif
	endfor
#if exists("VDT2")==4 && exists("UpdateCoords")==6
	df=PackageHome(module,"Sutter")
	if(datafolderrefstatus(df))
		wave /z/sdfr=df xWave,yWave,zWave
		nVar /z/sdfr x1,y1,z1
		xWave[sweep]={x1}
		yWave[sweep]={y1}
		zWave[sweep]={z1}
	endif
#endif
End

Function OnlineAnalysis(ISI[,DAQ])
	Variable ISI
	String DAQ
	
	variable minimumAnalysisISI=Core#VarPackageSetting(module,"random","","minimumAnalysisISI",default_=0)
	if(ISI>=minimumAnalysisISI)
		variable sweepNum=GetCurrSweep()
		string sweep=num2str(sweepNum)
		variable i,j,numChannels=GetNumChannels()
		for(i=0;i<numChannels;i+=1)
			if(IsChanActive(i) && (ParamIsDefault(DAQ) || StringMatch(Chan2DAQ(i),DAQ)))
				for(j=0;j<numChannels;j+=1)
					if(IsChanActive(j))
						Analyze(i,j,sweep)
					endif
				endfor
			endif
		endfor
	endif
End

function IsAcquiring([DAQ])
	string DAQ
	
	if(paramisdefault(DAQ))
		DAQ=GetDAQs()
	endif
	variable i
	for(i=0;i<itemsinlist(DAQ);i+=1)
		DAQ=stringfromlist(i,DAQ)
		dfref df=GetDaqDF(DAQ)
		nvar /z/sdfr=df acquiring
		if(nvar_exists(acquiring) && acquiring)
			return 1
		endif
	endfor
	return 0
end

Function RestartAcquisition([DAQ])
	String DAQ
	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())
	StopAcquisition(DAQ=DAQ)
	StartAcquisition(DAQ=DAQ)
End

Function StopAcquisition([DAQ])
	String DAQ
	
	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())
	dfref df=GetDaqDF(DAQ)
	nvar /sdfr=df inPoints,outPoints,sweepsLeft
	svar /sdfr=df saveMode
	nvar /sdfr=GetStatusDF() lastSaveSweep,lastSaveT,currSweep
	
	StopClock(DAQs=DAQ)
	ZeroAll(DAQs=DAQ)
	if(StringMatch(DAQ,"NIDAQmx"))
		BoardReset(1,DAQs=DAQ) // For some reason the NIDAQ also needs this.  
	endif
	inPoints=0
	outPoints=0
	
	// If the experiment has not been saved since the last sweep was collected and multiple sweeps were collected, save the experiment.  
	if(lastSaveSweep<currSweep && sweepsLeft!=1 && whichlistItem(saveMode,SaveModes(DAQ))>=2)
		SaveExperiment
		lastSaveSweep=currSweep
		lastSaveT=ticks
	endif
	Variable sweepsLeftInit=str2num(GetUserData(DAQ+"_Selector","SweepsLeft",""))
	if(numtype(sweepsLeftInit)==0)
		sweepsLeft=sweepsLeftInit
	endif
	if(InDynamicClamp())
		UnloadDynamicClampMode()
	endif
// Urban Legend Stop Hooks.
#ifdef UL
	UL#AcqStop()
#endif
	Button Start title="\\Z10Start", win=$(DAQ+"_Selector")
	variable /g df:acquiring=0
End

Function StartAcquisition([DAQ])
	String DAQ
	
	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())

	dfref daqDF=GetDaqDF(DAQ)
	nvar /sdfr=daqDF acquiring,duration,ISI,continuous
	svar /sdfr=daqDF saveMode
	variable sealTestOn=IsSealTestOn()
	
	Variable i; String alert_text,channel
	if(sealTestOn)
		DoWindow /K SealTest
		String infoStr="EVENT:kill"
		SealTestHook(infoStr)
	endif
	
	if(acquiring==0)
		variable saveMode_=whichlistitem(saveMode,SaveModes(DAQ))
		// In case the settings might cause unreliable behavior due to timing issues, warn the profile.  
		if(saveMode_==3 && ((duration<2 && continuous) || ((ISI-duration)<1 && !continuous)))
			alert_text=""
			alert_text+="Under the current configuration, autosave may cause difficulties.\r"
			alert_text+="Do you want to turn Autosave off before starting the stimulation?\r"
			alert_text+="Data will still be stored."
			DoAlert 2, alert_text
			switch(V_flag)
				case 1: // Yes
					saveMode=stringfromlist(2,SaveModes(DAQ))
					break
				case 2: // No
					break
				case 3: // Cancel
					return -1
					break
			endswitch
		endif
		
		// Guard against a large stimulus in voltage clamp
		variable numChannels=GetNumChannels()
		for(i=0;i<numChannels;i+=1)
			wave Ampl=Core#WavPackageSetting(module,"stimuli",GetChanName(i),"Ampl")
			if(StringMatch(GetModeOutputUnits(GetAcqMode(i)),"mV") && wavemax(Ampl)>300)
				string alert
				sprintf alert,"Are you sure you want to stimulate with %d mV in voltage clamp?",wavemax(Ampl)
				DoAlert 1, alert
				switch(V_flag)
					case 1: // Yes
						break
					case 2: // No
						return -2
						break
				endswitch
			endif
		endfor
		
		// Guard against sweep durations so long that they would cause buffer overflow.  
		variable kHz=GetKHz(DAQ)
		variable numSamples=0
		for(i=0;i<numChannels;i+=1)
			numSamples+=kHz*1000*duration
		endfor
		if(numSamples>2^20)
			alert="This sweep is too long.  Number of channels * Number of points per channel cannot exceed 2^20.\r"
			alert="You must reduce the sweep duration, the number of channels, or use a lower sampling frequency."
			DoAlert 0,alert
			return -3
		endif
		
		// Guard against intervals so short that auto-save might cause sweeps to be missed.  
		if(continuous==0 && (duration >= ISI || (duration>ISI-0.25 && saveMode_==3)))
			alert="Because the interval between the end of one sweep and the beginning of another is so small, you may miss sweeps.\r"
			alert+="Would you like to collect data in continuous (gap-free) mode?"
			DoAlert 2,alert
			switch(V_flag)
				case 1: // Yes
					continuous=1
					break
				case 2: // No
					break
				case 3: // Cancel
					return -4
					break
			endswitch
		endif
		
//		if(Core#IsCurrprofile("Rick"))
//			SetAcqModeFromTelegraph(0)
//		endif
// Urban Legend start hooks.  	
#ifdef UL
	UL#AcqStart()
#endif
		Button Start title="\\Z10Stop", win=$(DAQ+"_Selector")
		StartSweep(DAQ=DAQ)
	else	
		//variable /g root:LIH:acquiring=0
		//CtrlNamedBackground Acquisition stop
		//LIH_Halt()
		//Button Start title="Start", win=LIH_Selector
		StopAcquisition(DAQ=DAQ)
	endif
End

// Resets an experiment so that while parameters are the same, all status variables are reset and old sweeps are deleted.  
Function ResetExperiment()
	// Reset status data.
	wave sweepT=GetSweepT()  
	Redimension /n=0 sweepT
	dfref statusDF=GetStatusDF()
	string varsToZero="currSweep;waveformSweeps;waveFormStartT;lastSweepT;"
	varsToZero+="cursorSweepNum_A;cursorSweepNum_B"
	variable i,j
	for(i=0;i<ItemsInList(varsToZero);i+=1)
		String item=StringFromList(i,varsToZero)
		nvar /z/sdfr=statusDF var=$item
		if(nvar_exists(var))
			var=0
		endif
	endfor
	string DAQs=GetDAQs()
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		dfref daqDF=GetDaqDF(DAQ)
		varsToZero="sweepsLeft;lastDAQSweepT;"
		for(j=0;j<ItemsInList(varsToZero);j+=1)
			item=StringFromList(j,varsToZero)
			nvar /z/sdfr=daqDF var=$item
			if(nvar_exists(var))
				var=0
			endif
		endfor
	endfor
	ResetExperimentClock()
	SetAcqInited(1)
	
	// Reset drug data.  
	dfref drugsDF=GetDrugsDF()
	redimension /n=(0,-1,-1,-1) drugsDF:info,drugsDF:history
	drugsDF=Core#PackageHome(module,"drugs")
	i=1
	do // Washout.  f
		dfref df=drugsDF:$("drug"+num2str(i+1))
		if(!datafolderrefstatus(df))
			break
		endif
		nvar /z/sdfr=df active
		if(nvar_exists(active))
			active=0
		endif
		i+=1
	while(1)
	
	// Reset data for each channel.  Only works for current channels.  
	variable numChannels=GetNumChannels()
	make /free/df/n=0 chanDFs
	for(i=0;i<numChannels;i+=1)
		DAQ=Chan2DAQ(i)
		dfref daqDF=GetDaqDF(DAQ)
		Wave input=daqDF:$("input_"+num2str(i))
		input=0
		dfref chanDF=GetChanDF(i)
		chanDFs[i]={chanDF}
		if(datafolderrefstatus(chanDF))
			wave chanHistory=GetChanHistory(i)
			Redimension /n=(0,-1,-1,-1) chanHistory
			
			// Delete all other waves, including all sweeps, from this folder.  
			string channelWaves=WaveList2(df=chanDF)
			channelWaves=RemoveFromList(nameofwave(chanHistory),channelWaves)
			for(j=0;j<ItemsInList(channelWaves);j+=1)
				string channelWave=StringFromList(j,channelWaves)
				wave w=chanDF:$channelWave
				redimension /n=0 w
				killwaves /Z w
			endfor			
		endif
	endfor
	
	// Delete all other root level folders that have sweeps in them, that are not current channel names.  
	wave labels=GetChanLabels()
	dfref rootDF=root:
	for(i=0;i<CountObjectsDFR(rootDF,4);i+=1)
		string folderName=GetIndexedObjNameDFR(rootDF,4,i)
		df=root:$folderName
		string waves=wavelist2(df=df)
		if(whichlistitem(chanHistoryName,waves)>=0) // A channel folder
			variable keep=0
			for(j=0;j<numChannels;j+=1)
				dfref keepDF=chanDFs[j]
				if(datafolderrefsequal(df,keepDF))
					keep=1
					break
				endif
			endfor
			if(!keep)
				KillDataFolder /Z df
			endif
		endif
	endfor
	printf "Reset Experiment @ %s.\r",time()
End

Function ResetExperimentClock()
	variable err
	dfref statusDF=GetStatusDF()
	if(datafolderrefstatus(statusDF))
		nvar /sdfr=statusDF expStartT,bootT
		if(nvar_exists(expStartT))
			expStartT=datetime
			bootT=StopMSTimer(-2)
		else
			printf "Could not find %s in %s.\r","expStartT",getdatafolder(1,statusDF)
		endif
	else
		printf "Could not find status data folder.\r"
		err=-1
	endif
	return err
End

