// $Author: rick $
// $Rev: 633 $
// $Date: 2013-03-28 15:53:22 -0700 (Thu, 28 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=Acq
static strconstant module=Acq

static Function EditPackagesSetVariables(info) : SetVariableControl
	Struct WMSetVariableAction &info
	
	string package=Core#GetControlUserData(info.ctrlName,"PACKAGE",win=info.win)
	string instance=Core#GetControlUserData(info.ctrlName,"INSTANCE",win=info.win)
	string object=Core#GetControlUserData(info.ctrlName,"OBJECT",win=info.win)
	string action=Core#GetControlUserData(info.ctrlName,"ACTION",win=info.win)
	
	strswitch(package)
		case "acqModes":
			strswitch(object)
				case "testPulseAmpl":
				case "testPulseStart":
				case "testPulseLength":
					AcqModeDefaults(instance,ignoreBaseline=1) // Update the acquisition mode default values for resistance measurements.  
					break
			endswitch
			break
	endswitch
End

static Function EditPackagesButtons(info) : ButtonControl
	struct wmbuttonaction &info
		
	if(info.eventCode != 2) // Not a mouse up.  
		return -1
	endif
	
	string package=Core#GetControlUserData(info.ctrlName,"PACKAGE",win=info.win)
	string instance=Core#GetControlUserData(info.ctrlName,"INSTANCE",win=info.win)
	string action=Core#GetControlUserData(info.ctrlName,"ACTION",win=info.win)

	strswitch(action)
		case "Save":
			if(stringmatch(package,"*Win"))
				Core#SaveProfileMacro(package)
			elseif(stringmatch(package,"analysisMethods"))
				AnalysisSelector(0)
			endif
			break
		case "Add":
			if(stringmatch(package,"acqModes"))
				AcqModeDefaults(instance) // Defaults based on the values set above.  
			endif
		case "Delete":
			if(stringmatch(package,"analysisMethods"))
				AnalysisMethodListBoxUpdate()
				AnalysisSelector(0)
			endif
			break
	endswitch
End

//Function SetDrugDefaults()
//	SetDataFolder root:parameters 
//	
//	String /G drugList="TTX;BMI;APV"			// A list of drugs that will be available from the pull-down menu in the 'Drugs' panel.  			
//	String /G concs="100;5;25"
//	String /G units="nM;然;然"
//	String /G unitlist=unitlistConstant			// The units for concentration.  
//	String /G drugPresets=";TTX,500,nM;BMI,5,然,APV,25,然;Dopamine,20,然" // A list of presets including multiple drugs and associated concentrations.  	
//End

static Function /S LoadDefaultPackageInstances(module,package[,special])
	String module,package,special
	
	strswitch(package)
		case "acqModes":
			string instances=Core#ListPackageInstances(module,package)
			variable i
			for(i=0;i<itemsinlist(instances);i+=1)
				string instance=stringfromlist(i,instances)
				AcqModeDefaults(instance)
			endfor
			break
	endswitch
	return instance
End

static function PackageHasWaves(module,package)
	string module,package
	
	variable hasWaves=0
	strswitch(package)
		case "stimuli":
			hasWaves=1
			break
	endswitch
	return hasWaves
end

// ------ Loading and Saving of Channel Configurations ------

function /wave GetDefaultChanColor(chan)
	variable chan
	
	make /free/n=3 w
	switch(chan)
		case 0:
			w={65535,0,0}
			break
		case 1:
			w={0,0,65535}
			break
		case 2:
			w={0,65535,0}
			break
		case 3:
			w={32768,32768,0}
			break
		case 4:
			w={32768,0,32768}
			break			
		case 5:
			w={0,32768,32768}
			break
		default:
			w={0,0,0}
	endswitch
	return w
end

// Applies a loaded package instance to the given channel.  Deals with some of the hierarchical application of package instances, e.g. selecting a channel configuration often implies selecting a stimulus.  
Function SelectPackageInstance(package,instance[,special])
	string package,instance,special
	
	special=selectstring(!paramisdefault(special),"",special)
	variable chan=NumberByKey("CHAN",special)
	chan=numtype(chan) ? 0 : chan
	string DAQ=StringByKey("DAQ",special)
	DAQ=selectstring(strlen(DAQ),MasterDAQ(),DAQ)
	String currFolder=GetDataFolder(1)
	
	if(!strlen(instance))
		return -1
	endif
	
	string name=GetChanName(chan)
	dfref chanDF=Core#InstanceHome(module,package,name,quiet=1) // Location of instance e.g. ch0, not the sweeps for ch0.  
	dfref packageDF=Core#PackageHome(module,package)
	//String DAQ=Chan2DAQ(chan)
	dfref daqDF=GetDaqDF(DAQ)
	dfref instanceDF=packageDF:$instance
	string context
	sprintf context,"_chan_:%d;",chan
	if(DataFolderRefStatus(instanceDF)) // A normal package instance.  
		if(!stringmatch(package,"DAQs"))
			Core#CopyInstance(module,package,instance,name,context=context)
		endif
	elseif(stringmatch(package,"stimuli"))
		wave /z stimulus=packageDF:$instance
		if(waveexists(stimulus)) // Pre-made stimulus wave.  
			nvar /sdfr=daqDF duration
			duration=WaveDuration(Stimulus)
		elseif(exists(instance+"_stim")==6) // A stimulus function.  
			funcref Default_stim f=$(instance+"_stim")
			if(!numberbykey("ISPROTO",funcrefinfo(f)))
				DoAlert 0,"The stimulus function "+instance+" does not match the stimulus function prototype StimFuncProto().  Using StimFuncProto() instead."
			endif
		else // Not a valid instance.  
			return -2
		endif
	elseif(stringmatch(instance,"_Save_")) // Not a valid instance.  
	else
		return -3
	endif
	
	strswitch(package)
		case "sweepsWin":
		case "analysisWin":
			string liveInstance = "win0"
			strswitch(instance)
				case "_Save_":
					do
						string targetInstance = Core#DefaultInstance(module,package)
						prompt targetInstance,"Name:"
						DoPrompt "Enter the desired name for this "+package+" instance",targetInstance
						if(!v_flag)
							// Save cursors and axes for current view.  
							string curr_view=GetCurrSweepsView()
							SaveAxes(curr_view,win=package) // Assumes package and window have the same name.  
							
							struct rect coords
							Core#CopyInstance(module,package,liveInstance,targetInstance)
							Core#GetWinCoords(package,coords) // Assumes package and window have the same name.  
							Core#SetVarPackageSetting(module,package,targetInstance,"left",coords.left,sub="position",create=1)
							Core#SetVarPackageSetting(module,package,targetInstance,"top",coords.top,sub="position",create=1)
							Core#SetVarPackageSetting(module,package,targetInstance,"right",coords.right,sub="position",create=1)
							Core#SetVarPackageSetting(module,package,targetInstance,"bottom",coords.bottom,sub="position",create=1)
							
							strswitch(package)
								case "sweepsWin":
									// Copy one of the vertical axes to the generic "Ampl_Axis".   
									dfref df = Core#InstanceHome(module,package,targetInstance,sub=curr_view)
									string acqModes = ListAcqModes()
									variable i
									for(i=0;i<itemsinlist(acqModes);i+=1)
										string acqMode = stringfromlist(i,acqModes)
										dfref sourceDF = df:$(acqMode+"_axis")
										if(datafolderrefstatus(sourceDF))
											break
										endif
									endfor
									if(datafolderrefstatus(sourceDF))
										string targetFolder = joinpath({getdatafolder(1,df),"Ampl_Axis"})
										Core#CopyData(sourceDF,targetFolder)
									endif
									break
							endswitch
							
							if(!Core#SavePackageInstance(module,package,targetInstance))
								printf "%s instance %s successfully saved.\r",package,targetInstance
							endif
						else
							break
						endif
					while(!strlen(targetInstance)) // User must supply an instance name of some length.  
					break	
				default:
					Core#CopyInstance(module,package,instance,liveInstance)
				endswitch
			break
		case "DAQs":
			strswitch(instance)
				case "_Save_":
					string winDAQ=GetWinDAQ()
					wave /t labels = GetChanLabels()
					do
						string targetDAQ = Core#DefaultInstance(module,package)
						prompt targetDAQ,"Name:"
						DoPrompt "Enter the desired name for this DAQ instance",targetDAQ
						if(!v_flag)
							if(strlen(targetDAQ))
								Core#CopyInstance(module,package,winDAQ,targetDAQ)
								Core#SetWavTPackageSetting(module,"DAQs",targetDAQ,"channelConfigs",labels)
								string win = GetDAQWin(DAQ = winDAQ)
								Core#GetWinCoords(win,coords)
								Core#SetVarPackageSetting(module,package,targetDAQ,"left",coords.left,sub="position")
								Core#SetVarPackageSetting(module,package,targetDAQ,"top",coords.top,sub="position")
								if(!Core#SavePackageInstance(module,package,targetDAQ))
									printf "%s instance %s successfully saved.\r",package,targetDAQ
								endif
							endif
						else
							break
						endif
					while(!strlen(targetDAQ))
					break	
				default:
					variable daqNum=GetWinDAQNum()
					if(numtype(daqNum) || daqNum<0)
						string daqName = Core#StrPackageSetting(module,package,instance,"device")
						daqNum = GetDAQNum(daqName)
					endif
					InitDAQ(daqNum,instance=instance)
					SweepsWindow()
					DAQ=GetDAQName(daqNum)
					WaveSelector(DAQ=DAQ,instance=instance)
					break
			endswitch
			break
		case "channelConfigs":
			InitChan(chan)
			Core#CopyInstance(module,package,instance,name)
			Core#SetStrPackageSetting(module,package,name,"DAQ",DAQ) // Set the DAQ for the current channel, e.g. ch0.
//			do // Use the default channel label, or a pick a new one if it is already taken.  
//				string label_ = Core#StrPackageSetting(module,"channelConfigs",name,"label_")
//				duplicate /free/t GetChanLabels() labels
//				extract /free/indx labels,matching_labels,stringmatch(labels[p],label_)
//				if(numpnts(matching_labels)>1) // If there was already a channel with this label: 
//					label_ += "_"+num2str(GetChannelNum(name))
//					Core#SetStrPackageSetting(module,"channelConfigs",name,"label_",label_)
//				else
//					break
//				endif
//			while(1)
//			if(!DataFolderExists(GetChannelFolder(label_))) // If there is no channel folder corresponding to this label...
//				InitChanContainer(chan) // ... create one.  
//			endif  
			//string adc = Core#StrPackageSetting(module,package,instance,"adc")
			//string dac = Core#StrPackageSetting(module,package,instance,"dac")
			acqMode=Core#StrPackageSetting(module,package,instance,"acqMode")
			SetAcqMode(acqMode,chan)
			string stimName=GetStimulusName(chan) // Get the stimulus for this channelConfig.  
			SelectPackageInstance("stimuli",stimName,special=special) // Set the stimulus name.  
			break
		case "stimuli":
			Core#SetStrPackageSetting(module,"channelConfigs",name,"stimulus",instance) // Set the stimulus name.  
			string vars="pulseSets;duration;ISI;sweepsLeft;"
			for(i=0;i<itemsinlist(vars);i+=1)
				string var=stringfromlist(i,vars)
				nvar /z/sdfr=instanceDF val=$var
				if(nvar_exists(val))
					Core#SetVarPackageSetting(module,"DAQs",DAQ,var,val)
				endif
			endfor
			acqMode=Core#StrPackageSetting(module,package,instance,"acqMode")
			if(strlen(acqMode) && !stringmatch(acqMode," "))
				acqModes=ListAcqModes()
				if(WhichListItem(acqMode,acqModes)<0)
					string default_acqMode = StringFromList(0,acqModes)
					string alert
					sprintf alert,"This stimulus calls for acquisition mode '%s', but no such mode exists.  Acquisition mode set to '%s'.",acqMode,default_acqMode
					DoAlert 0,alert
					acqMode = default_acqMode
				endif				
				SetAcqMode(acqMode,chan)
			endif
			Struct WMSetVariableAction info
			info.ctrlName="Divisor"; info.win=DAQ+"_Selector"
			WaveValuesProc(info)
			break
		case "filters":
			Core#SetStrPackageSetting(module,"channelConfigs",name,"filters",instance) // Set the filter instance name.  
			Core#CopyInstance(module,package,instance,name)
			break
	endswitch
	if(WinType(DAQ+"_Selector") && !stringmatch(package,"DAQs") && !copernicus())
		RedrawSelector(win=DAQ+"_Selector")
	endif
End

// ----------------------------------------

function SaveStimulus(chan[,stimName])
	variable chan
	string stimName
	
	variable err=0
	string chanName=GetChanName(chan)
	string DAQ=Chan2DAQ(chan)
	dfref daqDF=GetDaqDF(DAQ)
	string vars="continuous;duration;ISI;pulseSets;sweepsLeft;"
	string strs="acqMode;"
	variable i
	for(i=0;i<itemsinlist(vars);i+=1)
		string varName=stringfromlist(i,vars)
		nvar /sdfr=daqDF var=$varName
		Core#SetVarPackageSetting(module,"stimuli",chanName,varName,var)
	endfor
	dfref chanDF=Core#InstanceHome(module,"channelConfigs",chanName)
	for(i=0;i<itemsinlist(strs);i+=1)
		string strName=stringfromlist(i,strs)
		strswitch(strName)
			case "acqMode":
				dfref df=chanDF
				break
			default:
				df=daqDF
		endswitch
		svar /sdfr=df str=$strName
		Core#SetStrPackageSetting(module,"stimuli",chanName,strName,str)
	endfor
	stimName=selectstring(!paramisdefault(stimName),Core#StrPackageSetting(module,"channelConfigs",chanName,"Stimulus"),stimName)
	stimName=selectstring(strlen(stimName),"Dummy",stimName)
	dfref newDF=Core#CopyInstance(module,"stimuli",chanName,stimName)
	err-=!datafolderrefstatus(newDF)
	if(!err)
		err+=Core#SavePackage(module,"stimuli",quiet=1)
	endif
	if(!err)
		printf "Stimulus '%s' on channel '%s' saved successfully.\r",stimName,Chan2Label(chan)
	endif
end

// ------ Loading and Saving of Acqusition Modes ------

Function AcqModeDefaults(instance[,ignoreBaseline])
	String instance
	Variable ignoreBaseline
	
	variable noiseFreq=Core#VarPackageSetting("Acq","random","","noiseFreq",default_=60)
	dfref df=Core#InstanceHome("Acq","acqModes",instance)
	if(!datafolderrefstatus(df))
		return -1
	endif
	nvar /sdfr=df testPulseStart,testPulseLength
	variable /g df:rBaselineRight =  testPulsestart-0.001	// and input resistance measurements
	nvar /sdfr=df rBaselineRight,testPulseStart,testPulseLength
	variable /g df:rBaselineLeft = rBaselineRight-1/noiseFreq						// Initial position (in seconds) for the baseline for access
	variable /g df:accessLeft = testPulsestart-0.01			// Initial position (in seconds) for access resistance analysis
	variable /g df:accessRight = testPulsestart+0.01			// Final position for access resistance analysis
	variable /g df:inputLeft = testPulsestart+testPulselength-0.001-2/noiseFreq		// Initial position for input resistance analysis
	variable /g df:inputRight = testPulsestart+testPulselength-0.001				// Final position for input resistance analysis
	if(!ignoreBaseline)
		variable /g df:baselineLeft = 0						// The starting point of the baseline for amplitude analysis	
		variable /g df:baselineRight = 1
		nvar /sdfr=df baselineRight
		variable /g df:baselineCenter = baselineRight - 1/noiseFreq	// One noise cycle away from baselineRight
	endif
End

//Function LoadAcqDefaults(user)
//	Struct ProfileInfo &user
//	
//	String currFolder=GetDataFolder(1)
//	Variable i
//	for(i=0;i<ItemsInList(userSettings);i+=1)
//		String package=StringFromList(i,profilePackages)
//		NewDataFolder /O root:parameters
//		NewDataFolder /O/S root:parameters:$package
//		strswitch(userSetting)
//			case "Stimuli":
//				NewDataFolder /O/S Null
//				Variable /G pulseSets=1
//				Variable /G duration=1
//				Variable /G isi=2
//				break
//			case "ChannelConfigs":
//				NewDataFolder /O/S Generic
//				break
//			case "AcqModes":
//				NewDataFolder /O/S Unity
//				Variable /G inputGain=1000
//				Variable /G outputGain=1000
//				break
//			case "AnalysisMethods":
//				NewDataFolder /O/S Baseline
//				break
//		endswitch
//	endfor
//	SetDataFolder $currFolder
//End

Menu "Misc"
	"Backwards Compatibility", BackwardsCompatibility()
End

// Converts an experiment into a form that is compatible with the most recent code for the purposes of reanalysis.  
// Don't try collecting more data into such an experiment (why would you?).  
Function BackwardsCompatibility([quiet,dontMove,recompile])
	variable quiet
	string dontMove
	variable recompile
	
	string version = ""
	if(exists("root:sweep_number1"))
		version = "malenka1"
	endif
	recompile=paramisdefault(recompile) ? 1 : recompile
	printf "Making experiment compatible with latest version of code...\r"
	
	string profiles=Core#ListProfiles(init=1)
    	string lastProfileName=StringFromList(0,profiles)
    	Core#SetProfile(lastProfileName,recompile=recompile)
	
	variable i,j
	setdatafolder root:
	killvariables /Z r,g,b
	
	// Move old data and initialize new variables.  
	string usedChannels_=UsedChannels()
	variable numChannels=GetNumChannels(quiet=1)
	string DAQs=GetDAQs(quiet=1)
	
	string oldName=UniqueName("oldData",11,0)
	dfref oldRoot=NewFolder("root:"+oldName)
	string except=oldName+";Packages;"+usedChannels_
	if(!paramisdefault(dontMove))
		except=removeending(dontMove,";")+";"+except
	endif
	Core#MoveData(root:,"root:"+oldName,except=except,quiet=quiet)
	InitializeVariables(quiet=quiet,noContainers=1)
	
	// Parameters.  
	if(datafolderrefstatus(oldRoot:parameters))
		Core#CopyData(oldRoot:parameters,"root:parameters",quiet=quiet)
	endif
	// For very old experiments.  
	Core#MoveData(oldRoot:variables,"root:parameters",quiet=quiet)
	dfref oldParameters=oldRoot:parameters
	
	// Status variables.  
	string items="sweep_t,sweepT;sweepT,sweepT;"
	dfref status=GetStatusDF()
	MoveObjects(items,oldRoot,root:)
	items="current_sweep_number,currSweep;currentSweepNum,currSweep;sweep_number1,currSweep;"
	items+="cursor_A_sweep_number,cursorSweepNum_A;"
	items+="cursor_B_sweep_number,cursorSweepNum_B;"
	items+="sweeps_this_waveform,waveformSweeps;"
	items+="sweep_time,lastSweepT;"
	items+="exp_start_time,expStartT;"
	items+="waveform_start_time,waveformStartT;"
	dfref status=GetStatusDF()
	MoveObjects(items,oldRoot,status)
	MoveObjects(items,oldRoot:status,status)
	MoveObjects(items,oldRoot:reanalysis,status)
	items="info;history"
	NewDataFolder /O status:drugs
	MoveObjects(items,oldRoot:drugs,status:drugs)
	
	// Move and rename channel history waves.  
	for(i=0;i<itemsinlist(usedChannels_);i+=1)
		string channel=stringfromlist(i,usedChannels_)
		dfref oldChanDF=root:$channel
		dfref chanDF=GetChannelDF(channel)
		if(datafolderrefstatus(oldChanDF))
			wave /z/sdfr=oldChanDF SweepParameters
			if(waveexists(SweepParameters))
				duplicate /o SweepParameters,chanDF:$chanHistoryName
			else
				wave /z w=oldRoot:$("sweep_parameters_"+channel[4,5])
				if(waveexists(w))
					duplicate /o w,chanDF:$chanHistoryName
				endif
			endif
		endif
	endfor
	
	// Fix channel instances.  
	if(!numChannels)
		wave /z/t/sdfr=root:parameters labels,colors
		if(waveexists(labels))
			for(i=0;i<numpnts(labels);i+=1)
				InitChan(i,noContainer=1)
				Core#SetStrPackageSetting(module,"channelConfigs",GetChanName(i),"label_",labels[i])
				Core#SetWavPackageSetting(module,"channelConfigs",GetChanName(i),"color",row(colors,i))
			endfor
		else
			for(i=0;i<itemsinlist(usedChannels_);i+=1)
				InitChan(i,noContainer=1)
				Core#SetStrPackageSetting(module,"channelConfigs",GetChanName(i),"label_",stringfromlist(i,usedChannels_))
				Core#SetWavPackageSetting(module,"channelConfigs",GetChanName(i),"color",GetDefaultChanColor(i))
			endfor
		endif
	endif
	
	// Fix DAQ instances.  
	if(!strlen(DAQs))
		InitDAQ(0)
		string DAQ=GetDAQName(0)
		wave /t DAQchannelConfigs=Core#WavTPackageSetting(module,"DAQs",DAQ,"channelConfigs")
		redimension /n=(itemsinlist(UsedChannels())) DAQchannelConfigs
		numChannels=GetNumChannels()
		dfref daqDF=GetDaqDF(GetDaqName(0))
		for(j=0;j<numChannels;j+=1)
			make /o daqDF:$("input_"+num2str(j))
		endfor
		Core#SetVarPackageSetting(module,"DAQs",DAQ,"numChannels",numChannels)
	endif
	for(i=0;i<ItemsInList(DAQs);i+=1)
		DAQ=StringFromList(i,DAQs)
		dfref daqDF=GetDaqDF(DAQ)
		items="inputWaves;input_waves,inputWaves;outputWaves;output_waves,outputWaves;input_R1,input_0;input_0;input_L2,input_1;input_1;input_B3,input_2;input_2;"
		MoveObjects(items,oldRoot,daqDF) // Move from root if they are located there.  
		items+="InputMultiplex;OutputMultiplex;Raw_0;Raw_1;Raw_2;Stimulus_1;Stimulus_2;cumPoints;"
		MoveObjects(items,oldRoot:DAQ,daqDF) // Move from root:DAQ (generic DAQ folder) if they are located there.  
		items="kHz;duration;isi;continuous;real_time,realTime;realTime;sweeps_left,sweepsLeft;sweepsLeft"
		MoveObjects(items,oldParameters,daqDF)//,saveSource=(i<ItemsInList(DAQs)-1))
		MoveObjects("boardGain",oldParameters:random,daqDF)
		MoveObjects("sweepsLeft;lastSweepT,lastDAQSweepT",status,daqDF) // Move from root:DAQ (generic DAQ folder) if they are located there.  

	endfor	
	
	// Fix channel data folder.  
	variable firstSweepIs1=FirstSweepIsSweep1() // Is the first sweep called sweep1 (1) or sweep0 (0)?  
	if(firstSweepIs1)
		nvar /sdfr=status currSweep
	endif
	variable lastSweep=GetCurrSweep()//root:status:currentSweepNum // The number of the last sweep collected.  
	wave /t labels=GetChanLabels()//root:parameters:Labels
	numChannels=GetNumChannels()
	for(i=0;i<numChannels;i+=1)
		dfref df=GetChanDF(i)
		wave /z w=GetChanHistory(i)
		if(!waveexists(w)) // If the channel history wave can't be found.  
			InitChanContainer(i)
			wave w=GetChanHistory(i)
		endif
		variable amplCol=FindDimLabel(w,1,"Ampl")
		variable damplCol=FindDimLabel(w,1,"dAmpl")
		if(damplCol==-2) // dampl column not found.  
			InsertPoints /M=1 amplCol+1,1,w // This is for the dAmpl column.  
		endif
		variable VCcol=FindDimLabel(w,1,"VC")
		for(j=0;j<dimsize(w,0);j+=1)
			if(VCcol>=0)
				SetDimLabel 0,j,$SelectString(w[j][%VC],"CC","VC"),w 
			endif
			Redimension /n=(-1,ItemsInList(pulseParams),max(1,dimsize(w,2))) w
		endfor
		w[][%Divisor][]=(w>=1) ? w : 1
		w[][%TestPulseOn][]=1
		
		// Convert old amplitude waves into a modern analysis wave.  
		string oldChanNames="R1;L2;B3;"
		string chan=StringFromList(i,oldChanNames)
		for(j=0;j<numChannels;j+=1)
			String otherChan=StringFromList(j,oldChanNames)
			dfref df=root:$("cell"+chan)
			if(datafolderrefstatus(df))
				wave /z/sdfr=df Ampl=$("ampl_"+otherChan+"_"+chan)
				wave /z/sdfr=df Ampl2=$("ampl2_"+otherChan+"_"+chan)
				if(waveexists(Ampl))
					wave /z/sdfr=df Peak
					if(!waveexists(Peak))
						make /o/n=(dimsize(Ampl,0),2,numChannels) Peak
					endif
					Peak[][0][j]=Ampl[p]
					Peak[][1][j]=Ampl2[p]
				endif
			endif
		endfor
	endfor

	KillWindows("Dual_Resistance;WholeTraces;Membrane_Constants;Artifacts;Ampl_Analysis;Sweeps;Selector");
	AnalysisWindow()
	// Recreate the correct plots in the analysis window.  
	wave /z oldSelWave=root:$(oldName):parameters:analysisWin:SelWave
	if(waveexists(oldSelWave))
		wave /z/t oldListWave=root:$(oldName):parameters:analysisWin:ListWave
		numChannels=GetNumChannels()
		for(i=0;i<numChannels;i+=1)
			make /free/t/n=0 methods
			for(j=0;j<dimsize(oldListWave,0);j+=1)
				string method=oldListWave[j][dimsize(oldListWave,1)-2]
				if(oldSelWave[j][i] & 16)
					methods[numpnts(methods)]={method}
				endif
			endfor
			Core#SetWavTPackageSetting("Acq","channelConfigs",GetChanName(i),"analysisMethods",methods)
		endfor
		AnalysisMethodListBoxUpdate()
		AnalysisWindow()
	endif
	SweepsWindow()
	
	// Recreate the notebook.  
	string wins="Experiment_Log;ExperimentLog;"
	for(i=0;i<itemsinlist(wins);i+=1)
		string win=stringfromlist(i,wins)
		if(WinType(win))
			notebook $win getData=2 // Get plain text from notebook.  
			MakeLogPanel()
			notebook LogPanel#ExperimentLog text=s_value
		endif
	endfor
	
	// Deal with likely vestigial folder cellB3.  
	if(DataFolderExists("root:cellB3") && whichlistitem("cellB3",UsedChannels())<0)
		KillDataFolder root:cellB3
	endif

	// Renumber sweeps if necessary so that the first sweep is sweep 0.  
	for(i=0;i<ItemsInList(usedChannels_);i+=1)
		channel=StringFromList(i,usedChannels_)
		dfref oldChanDF=root:$channel
		dfref chanDF=GetChannelDF(channel)
		for(j=0;j<CountObjectsDFR(oldChanDF,1);j+=1)
			string name=GetIndexedObjNameDFR(oldChanDF,1,j)
			if(stringmatch(name,"sweep*"))
				wave /z sweep=oldChanDF:$name
				if(waveexists(sweep) && dimsize(sweep,1)<=1)
					variable sweepNum				
					sscanf name,"sweep%d",sweepNum
					string newName=GetSweepName(sweepNum-firstSweepIs1)
					if(!stringmatch(name,newName))
						wave /z w=chanDF:$newName
						if(!waveexists(w))
							rename sweep,$newName//movewave sweep,chanDF:$GetSweepName(sweepNum-firstSweepIs1)
						endif
					endif
				endif
			endif
		endfor
	endfor
	
	strswitch(version)
		case "malenka1":
			SetAcqMode("VC",0)
			break
	endswitch
End

