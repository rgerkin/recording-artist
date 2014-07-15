// $Author: rick $
// $Rev: 633 $
// $Date: 2013-03-28 15:53:22 -0700 (Thu, 28 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.
static strconstant module="Acq"
strconstant chanHistoryName="StimulusHistory"
strconstant proxies="None;Reverse Time;Flip Sign;Random Phase;"
constant NUM_LEAK_PULSES=4

//Function /S AcqModes([brackets])
//	variable brackets
//End

function GetCursorSweepNum(cursorName)
	string cursorName
	
	dfref df=GetStatusDF()
	nvar /z/sdfr=df num=$("cursorSweepNum_"+cursorName)
	if(nvar_exists(num))
		return num
	else
		return nan
	endif
end

Function /S SaveModes(DAQ[,brackets])
	string DAQ
	variable brackets
	
	return Core#PopupMenuOptions(module,"DAQs",DAQ,"saveMode",brackets=brackets)
End

Function /S SaveModesChannel(chan)
	variable chan
	
	return Core#PopupMenuOptions(module,"channelConfigs",GetChanName(chan),"saveMode")
End

function /S GetChanSaveMode(chan)
	variable chan
	
	return Core#StrPackageSetting(module,"channelConfigs",GetChanName(chan),"saveMode",default_="Raw")
end

Function /S GetChanLabel(chan)
	variable chan
	
	return Core#StrPackageSetting(module,"channelConfigs",GetChanName(chan),"label_",default_="ch"+num2str(chan),quiet=1)
End

function GetLabelChan(labell)
	string labell
	
	variable numChannels = GetNumChannels()
	wave /t labels = GetChanLabels()
	variable i
	for(i=0;i<numpnts(labels);i+=1)
		if(stringmatch(labell,labels[i]))
			return i
		endif
	endfor
	return -1
end

function /wave GetChanLabels()
	variable numChannels=GetNumChannels()
	make /free/t/n=(numChannels) labels
	variable i
	for(i=0;i<numChannels;i+=1)
		labels[i]=GetChanLabel(i)
	endfor
	return labels
end

function /S ChanLabels()
	variable numChannels=GetNumChannels()
	string labels=""
	variable i
	for(i=0;i<numChannels;i+=1)
		labels+=GetChanLabel(i)+";"
	endfor
	return labels	
End

//Function ChannelActivate(chan,active)
//	Variable chan,active
//	
//	Wave ActiveChannels=root:parameters:ActiveChannels
//	ActiveChannels[chan]=active
//End

Function ChanNumInMode(chan,sweep)
	variable chan,sweep
	
	string thisMode=SweepAcqMode(chan,sweep)
	variable i=0
	string channelsInMode=""
	do
		string mode=SweepAcqMode(i,sweep,quiet=1)
		if(stringmatch(mode,thisMode))
			channelsInMode+=num2str(i)+";"
		endif
		i+=1
	while(strlen(mode))
	return whichlistitem(num2str(chan),channelsInMode)
End

Function /S SweepAcqMode(chan,sweep[,quiet])
	variable chan,sweep,quiet
	
	string mode=""
	wave /T Labels=GetChanLabels()
	variable currSweep=GetCurrSweep()
	if(chan>dimsize(Labels,0))
		return ""
	endif
	if(sweep<currSweep)
		dfref chanDF=GetChanDF(chan,quiet=quiet)
		if(datafolderrefstatus(chanDF))
			wave /z chanHistory=GetChanHistory(chan)
			if(WaveExists(chanHistory))
				mode=GetDimLabel(chanHistory,0,sweep)
				if(!strlen(mode))
					//mode=GetDimLabel(chanHistory,0,-1)
					//if(!strlen(mode))
						mode=Core#DefaultInstance(module,"acqModes")
					//endif
				endif
			endif
		endif
	endif
	if(!strlen(mode))
		mode=GetAcqMode(chan,quiet=quiet)
		if(!strlen(mode))
			String acqModes=Core#ListPackageInstances(module,"acqModes")
			mode=StringFromList(0,acqModes)
		endif
	endif
	return mode
End

function IsChanActive(chan[,quiet])
	variable chan,quiet
	
	return Core#VarPackageSetting(module,"channelConfigs",GetChanName(chan),"active",quiet=quiet)
end

function IsChanAnalysisMethod(chan,method)
	variable chan
	string method
	
	variable result=0
	string name=GetChanName(chan)
	wave /z/t w=Core#WavTPackageSetting(module,"channelConfigs",name,"analysisMethods")
	if(waveexists(w) && strlen(method))
		findvalue /text=method /txop=4 w
		if(v_value>=0)
			result=1
		endif
	endif
	return result
end

Function GetBoardGain([DAQ])
	string DAQ
	
	DAQ=selectstring(paramisdefault(DAQ),DAQ,MasterDAQ())
	dfref daqDF=GetDaqDF(DAQ)
	nvar /sdfr=daqDF boardGain
	return boardGain
End

Function GetInputGain(chan,sweep)
	Variable chan,sweep
	
	return GetGain(chan,sweep,"input")
End

Function GetOutputGain(chan,sweep)
	Variable chan,sweep
	
	return GetGain(chan,sweep,"output")
End

Function GetGain(chan,sweep,direction)
	variable chan,sweep
	string direction
	
	string mode=SweepAcqMode(chan,sweep)
	variable gain=GetModeGain(mode,direction)
	return gain
End

Function GetModeInputGain(mode)
	String mode
	
	return GetModeGain(mode,"input")
End

Function GetModeOutputGain(mode)
	String mode
	
	return GetModeGain(mode,"output")
End

Function GetModeGain(mode,direction)
	string mode,direction
	
	return Core#VarPackageSetting(module,"acqModes",mode,direction+"Gain")
End

function /s GetModeInputType(acqMode[,fundamental])
	string acqMode
	variable fundamental
	
	return GetModeQuantity(acqMode,"input",fundamental=fundamental)
end

function /s GetModeOutputType(acqMode[,fundamental])
	string acqMode
	variable fundamental
	
	return GetModeQuantity(acqMode,"output",fundamental=fundamental)
end

function /s GetModeQuantity(acqMode,direction[,fundamental])
	string acqMode,direction
	variable fundamental
	
	string type=Core#StrPackageSetting(module,"acqModes",acqMode,direction+"Type")
	if(fundamental)
		type=Core#StrPackageSetting(module,"quantities",type,"type",default_=type) 
	endif
	return type
end

function /s GetMethodQuantity(analysisMethod[,fundamental])
	string analysisMethod
	variable fundamental
	
	string type=Core#StrPackageSetting(module,"analysisMethods",analysisMethod,"units")
	if(fundamental)
		type=Core#StrPackageSetting(module,"quantities",type,"type",default_=type) 
	endif
	return type
end

Function /s GetModeInputUnits(acqMode)
	String acqMode
	
	return GetModeUnits(acqMode,"input")
End

Function /s GetModeOutputUnits(acqMode)
	String acqMode
	
	return GetModeUnits(acqMode,"output")
End

function /s GetModeUnits(acqMode,direction)
	string acqMode,direction
	string type=GetModeQuantity(acqMode,direction)
	string units=Core#StrPackageSetting(module,"quantities",type,"units") // A unit label, e.g. "V" for volts.  
	if(!strlen(units))
		units=type // Input quantity, e.g. "Voltage"
	endif
	string prefix=GetModePrefix(acqMode,direction) // Unit prefix, e.g. "p" for "1e-12".  
	return prefix+units
End

function /s GetModeInputPrefix(acqMode)
	string acqMode
	
	return GetModePrefix(acqMode,"input") // Unit prefix, e.g. "p" for "1e-12".  
end

function /s GetModeOutputPrefix(acqMode)
	string acqMode
	
	return GetModePrefix(acqMode,"output") // Unit prefix, e.g. "p" for "1e-12".  
end

function /s GetModePrefix(acqMode,direction)
	string acqMode,direction
	
	string quantity=GetModeQuantity(acqMode,direction)
	string prefix=Core#StrPackageSetting(module,"quantities",quantity,"prefix",quiet=1,default_="Error")
	if(stringmatch(prefix,"Error"))
		prefix=Core#StrPackageSetting(module,"acqModes",acqMode,direction+"Prefix") // Unit prefix, e.g. "p" for "1e-12".
	endif
	if(stringmatch(prefix," "))
		prefix = ""
	endif
	return prefix
end

function /s GetMethodPrefix(analysisMethod[,acqMode])
	string analysisMethod,acqMode
	
	acqMode=selectstring(!paramisdefault(acqMode),"",acqMode)
	string quantity=GetMethodQuantity(analysisMethod)
	string prefix=Core#StrPackageSetting(module,"quantities",quantity,"prefix",quiet=1,default_="Error")
	if(stringmatch(prefix,"Error"))
		if(strlen(acqMode))
			prefix=Core#StrPackageSetting(module,"acqModes",acqMode,"inputPrefix") // Unit prefix, e.g. "p" for "1e-12".
		else
			prefix=""
		endif
	endif
	return prefix
end

function /s GetMethodUnits(analysisMethod[,acqMode])
	string analysisMethod,acqMode
	
	acqMode=selectstring(!paramisdefault(acqMode),"",acqMode)
	string type=GetMethodQuantity(analysisMethod)
	string units=""
	if(!stringmatch(type,"#"))
		units=Core#StrPackageSetting(module,"quantities",type,"units") // A unit label, e.g. "V" for volts.  
	endif
	if(!strlen(units))
		units=type // Input quantity, e.g. "Voltage"
	endif
	string prefix=GetMethodPrefix(analysisMethod,acqMode=acqMode) // Unit prefix, e.g. "p" for "1e-12".  
	return prefix+units
	return units // Output quantity, e.g. "Voltage"
end

function GetStimParam(param,chan,pulseSet)
	string param
	variable chan,pulseSet
	
	wave w=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),param)
	return dimsize(w,0)>pulseSet ? w[pulseSet] : 0
end

function SetStimParam(param,chan,pulseSet,value)
	string param
	variable chan,pulseSet,value
	
	wave w=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),param)
	w[pulseSet] = value
end

function /wave GetChanHistory(chan[,quiet])
	variable chan,quiet
	
	string channel=Chan2Label(chan)
	wave /z w=GetChannelHistory(channel)
	if(waveexists(w))
		return w
	else
		return NULL
	endif
end

function /wave GetChannelHistory(channel)
	string channel
	
	dfref df=GetChannelDF(channel)
	if(datafolderrefstatus(df))
		wave /z/sdfr=df w=$chanHistoryName
		if(waveexists(w))
			return w
		else
			return NULL
		endif
	else
		return NULL
	endif
end

function /wave GetChanSweepParam(chan,sweep,param)
	variable chan,sweep
	string param
	
	make /free/n=0 result
	wave w=GetChanHistory(chan)
	variable col=FindDimLabel(w,1,param)
	if(col==-2)
		printf "The value %s is not stored in the channel history.\r",param
	else
		make /free/n=(dimsize(w,2)) result=w[sweep][col][p] // Number of points equal to the number of pulse sets.  
	endif
	return result
end

function ChanSweepExists(chan,sweep)
	variable chan,sweep
	
	wave /z w = GetChanSweep(chan,sweep,quiet=1)
	return waveexists(w)
end

function /wave GetChanSweep(chan,sweep[,quiet])
	variable chan,sweep,quiet
	
	string channel=Chan2Label(chan)	
	return GetChannelSweep(channel,sweep,quiet=quiet)
end

function /wave GetChannelSweep(channel,sweep[,proxy,renew,quiet])
	string channel
	variable sweep,quiet,proxy,renew
	
	dfref df=GetChannelDF(channel)
	if(!DataFolderRefStatus(df))
		if(!quiet)
			printf "There is no folder for channel %s.\r",channel
		endif
		return NULL
	endif
	wave /z/sdfr=df w=$GetSweepName(sweep)
	if(!waveexists(w))
		if(!quiet)
			printf "There is no sweep number %d on channel %s.\r",sweep,channel
		endif
		return NULL
	elseif(proxy)
		string proxyName=stringfromlist(proxy,proxies)
		string name=nameofwave(w)+"_"+cleanupname(proxyName,0)  
		wave /z/sdfr=df wProxy=$name
		if(!waveexists(wProxy) || renew)
			switch(proxy)
				case 1:
					duplicate /o w,df:$name /wave=wProxy
					wavetransform /o flip,wProxy
					break
				case 2:
					duplicate /o w,df:$name /wave=wProxy
					wProxy*=-1
					break
				case 3:
					wave w_random = RandomPhases(w,width=1)
					duplicate /o w_random,df:$name /wave=wProxy // Evaluate in 1 second segments.    
					break
			endswitch
		endif
		wave w=wProxy
	endif
	return w
end

function /s GetSweepName(sweep)
	variable sweep
	
	return "sweep"+num2str(sweep)
end

// Finds the Igor channel corresponding to ADC connection number 'adc'.  
Function ADC2Chan(adc)
	string adc
	
	variable i,numChannels=GetNumChannels()
	wave InputMap = GetInputMap()
	//make /free/t/n=(numChannels) InputMap
	//for(i=0;i<numChannels;i+=1)
	//	InputMap[i]=Core#StrPackageSetting(module,"channelConfigs",GetChanName(i),"inputMap")
	//endfor
	findvalue /text=adc /txop=4 InputMap
	if(v_value>=0)
		return v_value
	else
		return nan
	endif
End

// Finds the Igor channel corresponding to DAC connection number 'dac'.  
Function DAC2Chan(dac)
	string dac
	
	variable i,numChannels=GetNumChannels()
	wave OutputMap = GetOutputMap()
	//make /free/t/n=(numChannels) OutputMap
	//for(i=0;i<numChannels;i+=1)
	//	OutputMap[i]=Core#StrPackageSetting(module,"channelConfigs",GetChanName(i),"OutputMap")
	//endfor
	findvalue /text=dac /txop=4 OutputMap
	if(v_value>=0)
		return v_value
	else
		return nan
	endif
End

// Finds the ADC connection number (from the InputMap) corresponding to Igor channel 'chan'.  
Function /s Chan2ADC(chan)
	variable chan
	
	return Core#StrPackageSetting(module,"channelConfigs",GetChanName(chan),"ADC")
End

// Finds the DAC connection number (from the OutputMap) corresponding to Igor channel 'chan'.  
Function /s Chan2DAC(chan)
	variable chan
	
	return Core#StrPackageSetting(module,"channelConfigs",GetChanName(chan),"DAC")
End

function /wave GetChannelColor(channel,red,green,blue)
	string channel
	variable &red,&green,&blue
	
	variable chan=Label2Chan(channel)
	wave color=GetChanColor(chan,red,green,blue)
	return color
end

function /wave GetChanColor(chan,red,green,blue)
	variable chan
	variable &red,&green,&blue
	
	string name=GetChanName(chan)
	wave /z color=Core#WavPackageSetting(module,"channelConfigs",name,"color",quiet=1)
	if(!waveexists(color))
		make /free/n=3 color
		switch(chan)
			case 0:
				color={65535,0,0}
				break
			case 1:
				color={0,0,65535}
				break
			case 2:
				color={0,65535,0}
				break
			default:
				color={0,0,0}
		endswitch
	endif
	red=color[0]
	green=color[1]
	blue=color[2]
	return color
end

//Function /S Channel2Colour(channel,red,green,blue)
//	String channel
//	Variable &red,&green,&blue
//	
//	Wave /Z Colors=root:parameters:Colors
//	Wave /T/Z Labels=root:parameters:Labels
//	
//	if(str2num(channel)>=0) // If channel was passed as a string like "1"
//		Variable chan=str2num(channel)
//	else	 // If channel was passed as a string like "R1"
//		if(WaveExists(Labels))
//			FindValue /TEXT=(channel) /TXOP=4 Labels
//			chan=V_Value
//		else
//			return "0;0;0"
//		endif
//	endif
//		
//	red=Colors[chan][0]
//	green=Colors[chan][1]
//	blue=Colors[chan][2]
//	return num2str(red)+";"+num2str(green)+";"+num2str(blue)
//End

Function /S Num2Chan(num)
	Variable num
	switch(num)
		case 1:
			return "R1"
			break
		case 2:
			return "L2"
			break
		case 3:
			return "B3"
			break
		default:
			printf "Invalid channel passed into function Num2Chan.\r"
			return ""
	endswitch
End

function /s SetUniqueChanLabel(chan[,label_,quiet])
	variable chan,quiet
	string label_
	
	wave /t Labels=GetChanLabels() // This is a copy of the current set of channel labels.  
	if(paramisdefault(label_) || !strlen(label_))
		label_=Chan2Label(chan)
	endif
	string newLabel=label_
	Labels[chan]=""
	variable i
	do
		if(InWavT(Labels,newLabel))
			newLabel += "_"+num2str(chan)
			i+=1
		else
			break
		endif
	while(i<10)
	Core#SetStrPackageSetting(module,"channelConfigs",GetChanName(chan),"label_",newLabel,quiet=quiet)
	return newLabel
end

function /wave SetUniqueChanColor(chan[,quiet])
	variable chan,quiet
	
	variable red,green,blue
	wave color=GetChanColor(chan,red,green,blue)
	variable i,tries=0,numChannels=GetNumChannels()
	do
		variable changedColor=0
		for(i=0;i<numChannels;i+=1)
			if(i==chan)
				continue
			endif
			wave otherColor=GetChanColor(i,red,green,blue)
			duplicate /free otherColor,diff
			diff-=color
			diff=abs(diff)
			if(sum(diff)<2000)
				ColorTab2Wave Rainbow
				wave m_colors
				switch(tries)				
					case 0:
						color = {65535,0,0}
						break
					case 1:
						color = {0,0,65535}
						break
					case 2:
						color = {0,65535,0}
						break
					default:
						color=m_colors[floor(abs(enoise(100)))][p]
						break
				endswitch
				changedColor=1
			endif
		endfor
		tries+=1
	while(changedColor && tries<10)
	Core#SetWavPackageSetting(module,"channelConfigs",GetChanName(chan),"color",color)
	killwaves /z m_colors
	return newLabel
end

//Function SetStimulus(chan,name)
//	Variable chan // Stimulation channel.  
//	String name // Name of stimulus.  
//	
//	Wave /T StimulusName=root:parameters:StimulusName
//	Wave AddStimulus=root:parameters:AddStimulus
//	String currFolder=GetDataFolder(1)
//	SetDataFolder root:parameters
//	if(strlen(name))
//		Wave /T StimulusName=root:parameters:StimulusName
//		StimulusName[chan]=name
//		String DAQ=Chan2DAQ(chan)
//		Variable stimType=SerialOrIBW(name)
//		switch(stimType)
//			case 0: //Serialized stimulus (pulse sets).  
//				string special
//				sprintf special,"CHAN:%d",chan
//				SelectPackageInstance(module,"stimuli",name,special=special)
//				break
//			case 1:  // IBW.  
//				AddStimulus[chan]=0
//				Checkbox /Z $("AddStimulus_"+num2str(chan)), value=AddStimulus[chan], win=$(DAQ+"_Selector")
//				break
//			default:  // New name.  
//				break
//		endswitch
//	endif
//	SetDataFolder $currFolder
//End

// Iterates through the DAQs until it gets to 'DAQ', and then returns the channel number that would follow the last channel in the DAQ.  
Function NextChannelNum(DAQ)
	string DAQ
	
	string DAQs=GetDAQs()
	variable DAQpos=WhichListItem(DAQ,DAQs)
	variable numChannels=GetNumChannels(DAQ=DAQ)
	return numChannels
End

// Iterates through the DAQs until it gets to 'DAQ', and then returns the last channel number in the DAQ.  
Function LastChannelNum(DAQ)
	String DAQ
	
	Variable chan=NextChannelNum(DAQ)-1
	return chan
End

function ConvertModeUnits(value,acqMode,direction)
	variable value // e.g. 58.3  
	string acqMode // e.g. "VC"
	string direction // "input" or "output"
	
	strswitch(direction)
		case "input":
			string type=GetModeInputType(acqMode)
			break
		case "output":
			type=GetModeInputType(acqMode)
			break
		default:
			printf "Not a valid direction: %s; %s.\r",direction,getrtstackinfo(1)
			return 0
	endswitch
	string prefix=Core#StrPackageSetting(module,"acqModes",acqMode,direction+"prefix") // Units, e.g. "p".  
	string prefixes="f;p;n;u;m;;k;M;G;T;"
	variable index=whichlistitem(prefix,prefixes)
	if(index>=0)
		variable factor=10^(-15+3*index)
	else
		factor=1
	endif
	return value*factor
end

function UnitsRatio(num,denom)
	string num,denom
	
	string prefixes="f;p;n;u;m;;k;M;G;T;"
	variable index=whichlistitem(num,prefixes)
	if(index>=0)
		variable numVal=10^(-15+3*index)
	else
		numVal=1
	endif
	index=whichlistitem(denom,prefixes)
	if(index>=0)
		variable denomVal=10^(-15+3*index)
	else
		denomVal=1
	endif
	return numVal/denomVal
end

Function ApplyFilters(w,chan)
	Wave w
	Variable chan
	
	dfref df=Core#InstanceHome(module,"filters",GetChanName(chan))
	if(!datafolderrefstatus(df))
		return -1
	endif
	
	String DAQ=Chan2DAQ(chan)
	dfref daqDF=GetDaqDF(DAQ)
	nVar /sdfr=daqDF kHz
	nvar /z/sdfr=df low,lowFreq,high,highFreq,wyldpoint,wyldpointWidth,wyldpointThresh
	nvar /z/sdfr=df notch,notchFreq,notchHarmonics,zero,powerSpec,leakSubtract
	svar /z/sdfr=df notchFunc
	string data,noteStr=note(w)
	
	// Apply filters.
	  
	// Median Filter.    
	if(wyldpoint)
		smooth /M=(wyldpointThresh) wyldpointWidth,w
		sprintf data "MEDIAN={%f,%f}",wyldpointThresh,wyldpointWidth
		noteStr=ReplaceStringByKey(StringFromList(0,data,"="),noteStr,StringFromList(1,data,"="),"=","\r")
	endif
	
	// Low-pass Filter.  
	if(low)
		//WaveStats /Q/M=1 w
		//variable avg=V_avg
		//w-=avg
		//FilterIIR /LO=(lowFreq/(1000*kHz)) w // Low-pass filter.  
		//w+=avg
		BandPassFilter(w,lowFreq,0)
		sprintf data "LO=%f",lowFreq
		noteStr=ReplaceStringByKey(StringFromList(0,data,"="),noteStr,StringFromList(1,data,"="),"=","\r")
	endif
	
	// High-pass Filter.  
	if(high)
		//WaveStats /Q/M=1 w
		//variable first=w[0]
		//w-=first
		//FilterIIR /HI=(highFreq/(1000*kHz)) w // High-pass filter.  
		//w+=first
		BandPassFilter(w,Inf,highFreq)
		sprintf data "HI=%f",highFreq
		noteStr=ReplaceStringByKey(StringFromList(0,data,"="),noteStr,StringFromList(1,data,"="),"=","\r")
	endif
	
	// Zero (set mean to zero).  
	if(zero) // This should be done after all filtering to make sure the final mean is zero.  
		String acqMode=GetAcqMode(chan)
		dfref acqModeDF=Core#InstanceHome(module,"acqModes",acqMode)
		nvar /z/sdfr=acqModeDF baselineLeft,baselineRight
		if(nvar_exists(baselineLeft) && nvar_exists(baselineRight))
			WaveStats /Q/M=1/R=(baselineLeft,baselineRight) w
		else
			WaveStats /Q/M=1 w
		endif
		w-=v_avg
		sprintf data "ZERO=1"
		noteStr=ReplaceStringByKey(StringFromList(0,data,"="),noteStr,StringFromList(1,data,"="),"=","\r")
	endif
	
	// Notch Filter.  
	if(notch)
		funcref NewNotchFilter f=NewNotchFilter
		if(svar_exists(notchFunc))
			funcref NewNotchFilter f=$notchFunc
		endif	
		f(w,notchFreq,notchHarmonics) // Get rid of 60 Hz and harmonics.  
		sprintf data "NOTCH={%f,%d}",notchFreq,notchHarmonics
		noteStr=ReplaceStringByKey(StringFromList(0,data,"="),noteStr,StringFromList(1,data,"="),"=","\r")
	endif
	
	// Power Spectrum.  
	if(powerSpec)
		String channel=Chan2Label(chan)
		dfref chanDF=GetChanDF(chan)
		duplicate /free w Corr
		wavestats /Q corr; corr-=V_avg
		correlate Corr,Corr  
		redimension /n=(numpnts(Corr)+1) Corr
		string name="Power"//+channel
		FFT /MAG /DEST=chanDF:$name Corr
		//FFT /MAGS /DEST=$("Power_"+num2str(chan)) /WINF=Hanning input_Wave
		wave power=chanDF:$name
		variable currSweep=GetCurrSweep()
		make /o/n=(currSweep) chanDF:PowerHistory /wave=PowerHistory
		variable noiseFreq=Core#VarPackageSetting(module,"random","","noiseFreq",default_=60)
		PowerHistory[currSweep-1]=log(Power(noiseFreq))
		killwaves /z Power
	endif
	
	// Leak Subtraction.  
	if(leakSubtract)
		channel=Chan2Label(chan)
		dfref chanDF=GetChanDF(chan)
		
		variable pulseSet=0
		variable begin=GetStimParam("Begin",chan,pulseSet)
		variable IPI=GetStimParam("IPI",chan,pulseSet)
		variable Ampl=GetStimParam("Ampl",chan,pulseSet)
		variable dAmpl=GetStimParam("dAmpl",chan,pulseSet)
		variable numPulses=GetStimParam("Pulses",chan,pulseSet)
		
		// Create leak wave (leak based on auxiliary hyperpolarizing pulses).    
		variable leak_begin=begin+numPulses*IPI
		make/o/n=(IPI*kHz) chanDF:Leak /wave=Leak=0
		setscale /p x,0,0.001/kHz,leak
		variable i
		for(i=0;i<NUM_LEAK_PULSES;i+=1)
			leak+=w((begin+(numPulses+i)*IPI)/1000+x) // Each of these had -1/NUM_LEAK_PULSES the amplitude of the depolarizing pulses.  
		endfor
		wavestats /q/m=1/r=(begin+numPulses*IPI-0.01,begin+numPulses*IPI-0.001) leak
		leak-=v_avg
		smooth 3*kHz,leak
	
		// Create leak-subtracted wave (source wave minus leak wave, i.e. with leak subtracted).  
		if(0) // Separate leak subtraction wave.  
			duplicate /o/r=(0,(begin+IPI*(numPulses+NUM_LEAK_PULSES))/1000) w,chanDF:LeakSubtracted /wave=LeakSubtracted
		else // Apply to the source wave itself.  
			wave LeakSubtracted=w
		endif
		for(i=0;i<numPulses;i+=1)
			variable ampl_ratio=1+(dAmpl*i)/Ampl
			LeakSubtracted[(begin+i*IPI)*kHz,(begin+(i+1)*IPI)*kHz-1]+=ampl_ratio*leak[p-(begin+i*IPI)*kHz]
		endfor
		for(i=0;i<NUM_LEAK_PULSES;i+=1)
			ampl_ratio=1/NUM_LEAK_PULSES
			LeakSubtracted[(begin+(numPulses+i)*IPI)*kHz,(begin+(numPulses+i+1)*IPI)*kHz-1]-=ampl_ratio*leak[p-(begin+(numPulses+i)*IPI)*kHz]
		endfor
	endif
	
	Note /K w noteStr
End

Function ShowPower(chan)
	Variable chan
	String channel=Chan2Label(chan)
	Variable red,green,blue
	if(WinExist("PowerSpectrumWin"))
		DoWindow /F PowerSpectrumWin
	else
		Display /K=1 /N=PowerSpectrumWin as "Power Spectrum"
	endif
	SaveAxes("PowerSpectrumWin")
	dfref df=GetChanDF(chan)
	wave /z/sdfr=df Power
	if(!WaveExists(Power))
		Make /o df:Power /wave=Power=0
	endif
	string traceName="Power_"+channel
	RemoveFromGraph /Z $traceName
	GetChanColor(chan,red,green,blue)
	AppendToGraph /c=(red,green,blue) Power /tn=$traceName
	SetAxis bottom 0,100
	RestoreAxes("PowerSpectrumWin")
	ModifyGraph mode=5
End

Function ShowLeakSubtraction(chan)
	Variable chan
	String channel=Chan2Label(chan)
	Variable red,green,blue
	if(WinExist("LeakSubtractionWin"))
		DoWindow /F LeakSubtractionWin
	else
		Display /K=1 /N=LeakSubtractionWin as "LeakSubtraction"
	endif
	//SaveAxes("LeakSubtractionWin")
	dfref df=GetChanDF(chan)
	wave /z/sdfr=df LeakSubtracted
	if(!WaveExists(LeakSubtracted))
		Make /o df:LeakSubtracted /wave=LeakSubtracted=0
	endif
	string traceName="LeakSubtracted_"+channel
	RemoveFromGraph /Z $traceName
	GetChanColor(chan,red,green,blue)
	AppendToGraph /c=(red,green,blue) LeakSubtracted /tn=$traceName
	SetAxis /a
	//RestoreAxes("LeakSubtractionWin")
	ModifyGraph mode=0
End

//Function /S StimWaveList()
//	String stim_wave_list=""
//	String stimuli=""
//	Variable i=0
//	Do
//		String name=GetIndexedObjName("root:parameters:stimuli",1,i)
//		if(strlen(name))
//			stimuli+=name+";"
//			i+=1
//		else
//			break
//		endif
//	While(1)
//	stimuli+=ListFolders("root:parameters:stimuli")
//	return stimuli
//End

Function /s ChannelList(chanBits)
	variable chanBits
	
	string list=""
	variable i
	for(i=0;i<25;i+=1)
		if(chanBits & 2^i)
			list=list+GetChanLabel(i)+";"
		endif
	endfor
	
	return list
End

Function /S AssemblerList(chan)
	variable chan
	
	string funcs=functionlist("*_stim",";","")
	string goodFuncs=""//"Normal;"
	string daq = MasterDAQ()
	variable pulse_set = CurrPulseSet(daq)
	if(chan>=0)
		string assembler=GetAssembler(chan,pulse_set=pulse_set)
	else
		assembler = ""
	endif
	variable i
	for(i=0;i<itemsinlist(funcs);i+=1)
		string func=stringfromlist(i,funcs)
		funcref Default_stim f=$func
		if(strlen(stringbykey("NAME",funcrefinfo(f)))) // If function matches the prototype.  
			string goodFunc = removeending(func,"_stim")
			if(stringmatch(goodFunc,assembler))
				goodFunc = "["+goodFunc+"]"
			endif
			goodFuncs+=goodFunc+";"
		endif
	endfor
	return goodFuncs
End

function /s GetAssembler(chan[,pulse_set])
	variable chan,pulse_set
	
	wave /t w_assembler = Core#WavTPackageSetting(module,"stimuli",GetChanName(chan),"assembler")
	string assembler = "Default_stim"
	if(numpnts(w_assembler) && strlen(w_assembler[pulse_set]))
		assembler = w_assembler[pulse_set]
	endif
	
	return removeending(assembler,"_stim")
end

Function /S AcquisitionModes()
	string acqModes=Core#ListPackageInstances(module,"acqModes",editor=1)
	return RemoveEnding(acqModes,";")+";------;Edit"
End

Function /S GetAcqMode(chan[,quiet])
	variable chan,quiet
	
	return Core#StrPackageSetting(module,"channelConfigs",GetChanName(chan),"acqMode",quiet=quiet)
End

Function /S GetAcqModeOutputQuantity(modeName)
	string modeName
	
	return Core#StrPackageSetting(module,"acqModes",modeName,"outputType")
End

Function /S GetAcqModeInputQuantity(modeName)
	string modeName
	
	return Core#StrPackageSetting(module,"acqModes",modeName,"inputType")
End

function /s GetOutputUnits(chan)
	variable chan
	
	string quantity=GetOutputQuantity(chan)
	string units = Core#StrPackageSetting(module,"quantities",quantity,"units")
	string prefix = Core#StrPackageSetting(module,"quantities",quantity,"prefix")
	return prefix+units
end

function /s GetInputUnits(chan)
	variable chan
	
	string quantity=GetInputQuantity(chan)
	string units = Core#StrPackageSetting(module,"quantities",quantity,"units")
	string prefix = Core#StrPackageSetting(module,"quantities",quantity,"prefix")
	return prefix+units
end

Function /S GetOutputQuantity(chan)
	Variable chan
	
	string type=""
	string DAC=Chan2DAC(chan)
	strswitch(DAC)
		case "D":
		case "N":
			break
		default:
			string modeName=GetAcqMode(chan)
			type=GetAcqModeOutputQuantity(modeName)
	endswitch
	return type
End

Function /S GetInputQuantity(chan)
	Variable chan
	
	string type=""
	string DAC=Chan2ADC(chan)
	strswitch(DAC)
		case "D":
		case "N":
			break
		default:
			string modeName=GetAcqMode(chan)
			type=GetAcqModeInputQuantity(modeName)
	endswitch
	return type
End

function /S GetInputType(chan)
	variable chan
	
	string quantity = GetInputQuantity(chan)
	string type = Core#StrPackageSetting(module,"quantities",quantity,"type")
	return type
end

function /S GetOutputType(chan)
	variable chan
	
	string quantity = GetOutputQuantity(chan)
	string type = Core#StrPackageSetting(module,"quantities",quantity,"type")
	return type
end

Function /S SelectedMethod()
	string result=""
	dfref analysisWinDF=Core#InstanceHome(module,"analysisWin","win0")
	if(datafolderrefstatus(analysisWinDF))
		wave /z/sdfr=analysisWinDF selWave
		wave /z/t/sdfr=analysisWinDF listWave
		if(waveexists(selWave) && waveexists(listWave))
			variable i
			for(i=0;i<dimsize(SelWave,0);i+=1)
				if(SelWave[i][0] & 1) // If this analysis method is selected.  
					result=ListWave[i][dimsize(ListWave,1)-2]
					break
				endif
			endfor
		endif
	endif
	return result
End

Function SetAcqMode(mode,chan)
	String mode
	Variable chan 
	
	if(StringMatch(mode,"Edit"))
		Core#EditModule(module,package="AcqModes")
		return 1
	endif
	
	String currFolder=GetDataFolder(1)
	String modes=ListAcqModes()
	string oldMode=GetAcqMode(chan)
	variable ADC=str2num(Chan2ADC(chan))
	if(stringmatch(oldMode,mode) && !IsDynamicClamp(mode))
		return -1
	endif
	String DAQ=Chan2DAQ(chan)
	string win=DAQ+"_Selector"
	
	if(IsDynamicClamp(mode)) // Set dynamic clamp.  
		if(!stringmatch(DAQType(DAQ),"ITC"))
			PopupMenu $("Mode_"+num2str(chan)) mode=WhichListItem(oldMode,modes)+1
			DoAlert 0,"Dynamic clamp is only supported on ITC devices."
			return -2
		elseif(ADC!=0) // Must be ADC 0.  
			PopupMenu $("Mode_"+num2str(chan)) mode=WhichListItem(oldMode,modes)+1
			DoAlert 0,"Only ADC 0 can be dynamically clamped."
			return -3
		else  // Dynamic clamp must occur at 50 Hz.  
			if(!IsDynamicClamp(oldMode))
				SetVariable kHz disable=2,userData(oldFreq)=num2str(GetAcqFreq()),win=$win
				SetAcqFreq(50)
			endif
			dfref dc=Core#InstanceHome(module,"acqModes",mode)
			variable vE=numvarordefault(getdatafolder(1,dc)+":vE",0)
			variable vI=numvarordefault(getdatafolder(1,dc)+":vI",-80)
			prompt vE,"Excitatory (mV)"; prompt vI,"Inhibitory (mv)"; doPrompt "Set the values of the reversal potentials for dynamic clamp.",vE,vI 
			variable /g dc:vE=vE, dc:vI=vI
		endif
	elseif(IsDynamicClamp(oldMode)) // Leaving dynamic clamp.  
		SetVariable kHz disable=0
		variable oldFreq=str2num(GetUserData(win,"kHz","oldFreq"))
		oldFreq=numtype(oldFreq) ? DefaultKHz(DAQ) : oldFreq
		SetAcqFreq(oldFreq)
		//Execute /Q "ITC18Reset"	
	endif
	
	if(WhichListItem(mode,modes)>=0) // Existing mode.  
		Core#SetPackageSetting(module,"channelConfigs",GetChanName(chan),"acqMode",mode)
		if(IsDynamicClamp(mode))
			SetupDynamicClamp(DAQs=DAQ)
		endif
		SwitchView("")
	else
		AcqModeDefaults(mode) // Set values for input resistance measurement, access resistance measurements, etc.  
	endif
	
	PopupMenu /Z $("Mode_"+num2str(chan)) mode=WhichListItem(mode,modes)+1,userData(oldMode)=mode,win=$win
	PulseSetTabLabels()
End

Function GetAcqFreq([DAQ])
	string DAQ
	
	DAQ=selectstring(paramisdefault(DAQ),DAQ,MasterDAQ())
	dfref daqDF = GetDAQdf(DAQ)
	nvar kHz=daqDF:kHz
	return kHz
End

Function SetAcqFreq(kHz_[,DAQ])
	variable kHz_
	string DAQ
	
	DAQ=selectstring(paramisdefault(DAQ),DAQ,MasterDAQ())
	dfref daqDF = GetDAQdf(DAQ)
	nvar kHz=daqDF:kHz
	kHz=kHz_
End

Function GetAcqDuration([DAQ])
	string DAQ
	
	DAQ=selectstring(paramisdefault(DAQ),DAQ,MasterDAQ())
	dfref daqDF = GetDAQdf(DAQ)
	nvar duration=daqDF:duration
	return duration
End

Function InDynamicClamp()
	variable chan=ADC2Chan("0")
	if(numtype(chan))
		variable result=0
	else
		string mode=GetAcqMode(chan)
		result=IsDynamicClamp(mode)
	endif
	return result
End

Function IsDynamicClamp(mode)
	string mode
	
	return Core#VarPackageSetting(module,"acqModes",mode,"dynamic",default_=0)
End

Function /S ListAcqModes()
	 return Core#ListPackageInstances("Acq","acqModes")
End

Function /S ListAcqMethods()
	 return Core#ListPackageInstances("Acq","analysisMethods")
End

Function NumDistinctAcqModes(modeList[,withInput,withOutput])
	String &modelist
	Variable withInput // 1 to only include modes where input is being delivered.  
	Variable withOutput // 1 to only include modes where output is being delivered.  

	Variable i
	variable numChannels=GetNumChannels()
	
	// Make a list of modes used by the current stimuli. 
	modeList=""
	for(i=0;i<numChannels;i+=1)
		string acqMode=GetAcqMode(i)
		if(IsChanActive(i) && WhichListItem(acqMode,modeList)<0 && (!withInput || !StringMatch(Chan2ADC(i),"N")) && (!withOutput || !StringMatch(Chan2DAC(i),"N")))
			modeList+=acqMode+";"
		endif
	endfor
	Variable numModes=ItemsInList(modeList)
	return numModes
End

// Returns 0 if the wave is a folder with settings, 1 if it is a binary wave, and -1 if neither.  
Function SerialOrIBW(stimName)
	string stimName
	
	variable result
	if(Core#InstanceExists(module,"stimuli",stimName))
		result=0
	else
		dfref df=Core#PackageHome(module,"stimuli")
		wave /z/sdfr=df w=$stimName
		if(waveexists(w))
			result=1
		else
			result=-1
		endif
	endif
	return result
End

function SetAssembler(chan,assembler,pulse_set)
	variable chan,pulse_set
	string assembler
	
	string daq=Chan2DAQ(chan)
	string win=DAQ+"_Selector"
	Core#SetWavTPackageSetting(module,"stimuli",GetChanName(chan),"assembler",{assembler},indices={pulse_set})
	variable err = 0
	string ampl_title="Ampl"
	string dAmpl_title="\F'Symbol'D\F'Default'Ampl"
	strswitch(assembler)
		case "Ramp":
			ampl_title="Min"
			dAmpl_title="Max"
			break
		case "Sine":
			dAmpl_title="Freq"
			break
		case "Noisy":
			dampl_title="StDev"
			break
		case "Template":
		case "PoissonTemplate":
			err = LoadTemplate(chan,"template")
			break
		case "Frozen":
		case "FrozenPlusNegative":
			err = LoadTemplate(chan,"frozen")
			dampl_title="Multiplier"
			break
		case "Optimus2":
			SweepIndexWindow()
		default:
			break
	endswitch
	if(!err)
		Titlebox Title_Ampl title=ampl_title, win=$win
		Titlebox Title_dAmpl title=dampl_title, win=$win
	endif
	return err
end

function LoadTemplate(chan,w_name)
	variable chan
	string w_name
	
	dfref df=Core#InstanceHome(module,"stimuli",GetChanName(chan))
	wave /z/sdfr=df w = $w_name
	if(!waveexists(w))
		printf "Could not find a %s wave in %s.\r",w_name,joinpath({getdatafolder(1,df),"Frozen"})
		LoadWave /O/Q
		if(v_flag)
			string name=stringfromlist(0,s_waveNames)
			if(strlen(name))
				duplicate /o $name df:$w_name
				killwaves /z $name
			endif
		endif
		wave /z/sdfr=df w = $w_name
		if(!waveexists(w))
			string DAQ = Chan2DAQ(chan)
			variable curr_pulse_set = CurrPulseSet(DAQ)
			SetAssembler(chan,"Default",curr_pulse_set)
			return -1
		endif
	endif
	return 0
end

function SetListenHook(hook[,DAQ])
	string hook,DAQ
	
	DAQ=SelectString(!ParamIsDefault(DAQ),MasterDAQ(),DAQ)
	hook=replacestring("_daq_",hook,DAQ)
	dfref df=GetDaqDF(DAQ)
	string /g df:listenHook=hook
end
	
Function WaveUpdate([DAQ])
	String DAQ
	
	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())
	variable i,numChannels=GetNumChannels()
	wave /T Labels=GetChanLabels()
	dfref daqDF=GetDaqDF(DAQ)
	variable /g daqDF:reassemble=0 // Do not reassemble stimuli each sweep (i.e. use frozen stimuli).  
	make /o/n=(numChannels) daqDF:LCM_ /wave=LCM_
	for(i=0;i<numChannels;i+=1)
		if(!StringMatch(Chan2DAQ(i),DAQ))
			continue
		endif
		variable active=Core#VarPackageSetting(module,"channelConfigs",GetChanName(i),"active")
		if(!active)
			continue
		endif
		variable duration=GetDuration(DAQ)
		variable kHz=GetKhz(DAQ)
		wave /sdfr=daqDF input=$("input_"+num2str(i))
		redimension /n=(round(duration*kHz*1000)) input // Round because default action is to floor.  
		
		wave channelDivisor=GetChanDivisor(i)
		LCM_[i]=LCM(channelDivisor)
		LCM_[i]=numtype(LCM_[i]) ? 1 : LCM_[i]
		make /o/n=(0,LCM_[i]) daqDF:$("Raw_"+num2str(i)) /wave=Raw
		if(IsDynamicClamp(GetAcqMode(i)))
			wave /sdfr=daqDF forcingWave,eWave,iWave
			Assemble(i,forcingWave,triparity=0)
			Assemble(i,eWave,triparity=1)
			Assemble(i,iWave,triparity=2)
		else
			Assemble(i,raw)
		endif
		//if(WaveExists(StimulusName))
		//	String stim_name=StimulusName[i]
		//	Wave /Z StimWave=root:parameters:stimuli:$stim_name
		//endif
		//if(WaveExists(StimWave))
		//	AddStimulus[i]=1
		//	RawWave+=StimWave
		//else // Create the stimulus so it can be used later.  
		//	AddStimulus[i]=0
		//endif
		if(WinType(DAQ+"_Selector"))
			nvar addStimulus=$Core#PackageSettingLoc(module,"channelConfigs",GetChanName(i),"addStimulus")
			Checkbox $("AddStimulus_"+num2str(i)) variable=addStimulus,win=$(DAQ+"_Selector")
		endif
		SetScale x,0,duration,input
	endfor
End

function /wave GetSweepT()
	string loc="root:sweepT"
	wave /z w=$loc
	if(!waveexists(w))
		printf "Could not find SweepT at %s.\r",loc
		make /free/n=0 w 
	endif
	return w
end

function GetSweepTime(sweep)
	variable sweep
	
	wave SweepT = GetSweepT()
	sweep = limit(sweep,0,numpnts(SweepT)-1)
	variable result = SweepT[sweep]
	result = numtype(result)==2 ? 0 : result
	return result
end

function /s GetDAQName(daqNum)
	variable daqNum
	
	return "daq"+num2str(daqNum)
end

function GetDAQNum(daqName)
	string daqName
	
	variable num
	sscanf daqName,"daq%d",num
	return num
end

function /s GetChanName(chan)
	variable chan
	
	return "ch"+num2str(chan)
end

function GetChannelNum(name)
	string name
	
	variable chan
	sscanf name,"ch%d",chan
	return chan
end

function /df GetChanDF(chan[,create,quiet])
	variable chan,create,quiet
	
	string label_=Chan2Label(chan,quiet=quiet)
	return GetChannelDF(label_,create=create,quiet=quiet)
end

function /df GetChannelDF(channel[,create,quiet])
	string channel // A channel label.  
	variable create,quiet
	
	if(strlen(channel))
		string folder=GetChannelFolder(channel,create=create)
		dfref df=$folder
	else
		df=$""
	endif
	return df
end

function /s GetChanFolder(chan[,quiet])
	variable chan,quiet
	
	string name=Chan2Label(chan,quiet=quiet)
	return GetChannelFolder(name)
end

function /s GetChannelFolder(channel[,create])
	string channel
	variable create
	
	string result=""
	if(strlen(channel))
		result="root:"+PossiblyQuoteName(channel)
		if(create)
			newdatafolder /o $result
		endif
	endif
	return result
end

function GetNumChannels([DAQ,quiet])
	string DAQ
	variable quiet
	
	if(paramisdefault(DAQ))
		string DAQs=GetDAQs(quiet=quiet) 
	else
		DAQs=stringfromlist(0,DAQ)
	endif
	variable i,numChannels=0
	for(i=0;i<itemsinlist(DAQs);i+=1)
		DAQ=stringfromlist(i,DAQs)
		wave /z/t DAQchannelConfigs=Core#WavTPackageSetting(module,"DAQs",DAQ,"channelConfigs",quiet=quiet)
		if(waveexists(DAQchannelConfigs))
			numChannels+=numpnts(DAQchannelConfigs)
		endif
	endfor
	return numChannels
end

function /df GetStatusDF([create])
	variable create
	
	create=paramisdefault(create) ? 1 : create
	string folder="root:status"
	if(create)
		newdatafolder /o $folder
	endif
	dfref df=$folder
	return df
end

function SetAcqSetting(package,instance,object,value[,indices])
	string package,instance,object,value
	wave indices
	
	if(paramisdefault(indices))
		make /free/n=0 indices
	endif
	Core#SetPackageSetting(module,package,instance,object,value,indices=indices)
end

function /s GetStimulusName(chan)
	variable chan
	
	string channel = GetChanName(chan)
	return Core#StrPackageSetting(module,"channelConfigs",channel,"stimulus")
end

function /wave GetDAQDivisor(daq)
	string daq
	
	variable i,numChannels=GetNumChannels(daq=daq)
	variable numPulseSets=GetNumPulseSets(daq)
	for(i=0;i<numChannels;i+=1)
		if(i==0)
			make /free/n=(numChannels,numPulseSets) daqDivisor
		endif
		wave chanDivisor = GetChanDivisor(i)
		daqDivisor[i][]=chanDivisor[q]
	endfor
	return daqDivisor
end

function /wave GetChanDivisor(chan[,sweepNum])
	variable chan,sweepNum
	
	string channel = GetChanName(chan)
	if(paramisdefault(sweepNum))
		wave /z divisor = Core#WavPackageSetting(module,"stimuli",channel,"divisor")
		if(!waveexists(divisor))
			string daq = Chan2DAQ(chan)
			variable numPulseSets=GetNumPulseSets(daq)
			make /free/n=(numPulseSets) divisor = 1
		endif
	else
		wave chanHistory = GetChanHistory(chan)
		make /free/n=(dimsize(chanHistory,2)) divisor=chanHistory[sweepNum][%$"divisor"][p]
	endif
	return divisor
end

function /wave GetChanRemainder(chan[,sweepNum])
	variable chan,sweepNum
	
	string channel = GetChanName(chan)
	if(paramisdefault(sweepNum))
		wave /z remainder = Core#WavPackageSetting(module,"stimuli",channel,"remainder")
		if(!waveexists(remainder))
			string daq = Chan2DAQ(chan)
			variable numPulseSets=GetNumPulseSets(daq)
			make /free/n=(numPulseSets) remainder = 2^p
		endif
	else
		wave chanHistory = GetChanHistory(chan)
		make /free/n=(dimsize(chanHistory,2)) remainder=chanHistory[sweepNum][%$"remainder"][p]
	endif
	return remainder
end

function /wave GetNumPulses(chan[,sweepNum])
	variable chan,sweepNum
	
	if(paramisdefault(sweepNum))
		wave numPulses=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"pulses")
	else
		wave chanHistory=GetChanHistory(chan)
		make /free/n=(dimsize(chanHistory,2)) numPulses=chanHistory[sweepNum][%$"pulses"][p]
	endif
	return numPulses
end

function /wave GetAmpl(chan[,sweepNum])
	variable chan,sweepNum
	
	if(paramisdefault(sweepNum))
		wave ampl=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"ampl")
	else
		wave chanHistory=GetChanHistory(chan)
		make /free/n=(dimsize(chanHistory,2)) ampl=chanHistory[sweepNum][%$"ampl"][p]
	endif
	return ampl
end

function /wave GetdAmpl(chan[,sweepNum])
	variable chan,sweepNum
	
	if(paramisdefault(sweepNum))
		wave dAmpl=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"dAmpl")
	else
		wave chanHistory=GetChanHistory(chan)
		make /free/n=(dimsize(chanHistory,2)) dAmpl=chanHistory[sweepNum][%$"dAmpl"][p]
	endif
	return dAmpl
end

function GetEffectiveAmpl(chan[,sweepNum,pulseSet,pulseNum])
	variable chan,sweepNum,pulseSet,pulseNum
	
	wave ampl = GetAmpl(chan,sweepNum=sweepNum)
	wave dampl = GetdAmpl(chan,sweepNum=sweepNum)
	wave pulses = GetNumPulses(chan,sweepNum=sweepNum)
	if(paramisdefault(pulseSet))
		wave livePulseSets = GetLivePulseSets(chan,sweepNum=sweepNum)
	else
		make /free/n=1 livePulseSets = pulseSet
	endif
	variable k,result = 0
	for(k=0;k<numpnts(livePulseSets);k+=1)
		result +=  (pulseNum<pulses[k]) * (ampl[livePulseSets[k]] +pulseNum*dampl[livePulseSets[k]])
	endfor
	return result
end

function /wave GetLivePulseSets(chan[,sweepNum])
	variable chan,sweepNum
	
	wave divisor = GetChanDivisor(chan,sweepNum=sweepNum)
	wave remainder = GetChanRemainder(chan,sweepNum=sweepNum)
	make /free/n=(numpnts(divisor)) pulseSetState = 2^mod(divisor[p],sweepNum) & remainder[p]
	if(numpnts(divisor)==1)
		pulseSetState = 1
	endif
	extract /free/indx pulseSetState,livePulseSets,pulseSetState>0
	return livePulseSets
end

function GetCurrSweep()
	variable result=nan
	dfref df=GetStatusDF(create=0)
	if(datafolderrefstatus(df))
		nvar /z/sdfr=df currSweep
		if(!nvar_exists(currSweep))
			printf "Could not determine current sweep number.\r"
		else
			result=currSweep
		endif
	endif
	return result
end

function /wave GetInputMap()
	variable numChannels=GetNumChannels()
	make /free/t/n=(numChannels) map=Chan2ADC(p)
	return map
end

function /wave GetOutputMap()
	variable numChannels=GetNumChannels()
	make /free/t/n=(numChannels) map=Chan2DAC(p)
	return map
end

function /wave GetActiveChannels()
	variable numChannels=GetNumChannels()
	make /free/n=(numChannels) active=IsChanActive(p)
	return active
end

// Assemble the stimulus from components.  
Function /S Assemble(chan,Stimulus[,triparity])
	variable chan
	wave Stimulus // The wave that will be overwritten with the stimulus.  
	variable triparity // Even (0) or odd (1).  
	
	//print getrtstackinfo(2), triparity, getwavesdatafolder(Stimulus,2)
	string stimulusName=GetStimulusName(chan)
	
	//dfref df=root:parameters
	//nvar /sdfr=df pulseSets
	//wave /sdfr=df begin,pulses,width,ampl,dampl,IPI,divisor,Remainder,testPulseOn,lcm_
	//wave /t/sdfr=df AcqMode
	String DAQ=Chan2DAQ(chan)
	//dfref df=daqDF
	//nvar /sdfr=df kHz,duration
	//string mode=AcqMode[channel]
	variable duration=GetDuration(DAQ)
	variable kHz=GetKhZ(DAQ)
	wave LCM_=Core#WavPackageSetting(module,"DAQs",DAQ,"LCM_")
	variable pulseSets=GetNumPulseSets(DAQ)
	dfref df=Core#InstanceHome(module,"stimuli",GetChanName(chan))
	wave /sdfr=df divisor,remainder,pulses,begin,IPI,width,testPulseOn
	Redimension /n=(duration*kHz*1000,LCM_[chan]) Stimulus
	SetScale /P x,0,1/(1000*kHz),Stimulus
	Stimulus=0
	
	variable i,j,k,testPulseFound=0,testPulseApplied=0
	dfref df=Core#InstanceHome(module,"acqModes",GetAcqMode(chan))
	if(DataFolderRefStatus(df)==1)
		testPulseFound=1
		nvar /sdfr=df testPulsestart,testPulselength,testPulseampl
	else
		return "" 
	endif
	
	// Regular stimulus features.  
	for(k=0;k<LCM_[chan];k+=1)
		for(j=0;j<pulseSets;j+=1)
			if(!paramisdefault(triparity) && mod(j,3)!=triparity)
				continue
			endif
			variable remain=mod(k,divisor[j])
			if(Divisor[j]<=1 || (Remainder[j] & 2^remain)) // If this pulse set is active on this sweep number.  
				string assembler = GetAssembler(chan,pulse_set=j)
				funcref Default_stim stimFunc=$(assembler+"_stim")
				if(!strlen(stringbykey("NAME",funcrefinfo(stimFunc))) || stringmatch(Assembler,"Normal") || stringmatch(Assembler,"Default")) // Invalid or plain stimulus Assembler function.  
					funcref Default_stim stimFunc=Default_stim // Use the normal stimulus Assembler function.  
				endif
				
				variable numPulses=pulses[j]
				if(stringmatch(Assembler,"Optimus*") && !stringmatch(nameofwave(Stimulus),"forcingWave")) // Brent / Anne-Marie / Ashok stimuli with random pulse number.  
					numPulses=poissonnoise(numPulses)
				endif
				//SetWavPackageSetting(module,"stimuli",GetChanName(chan),"pulses",{numPulses},indices={k})
				for(i=0;i<numPulses;i+=1)
					Variable firstX=begin[j]/1000+i*IPI[j]/1000
					Variable lastX=begin[j]/1000+i*IPI[j]/1000+width[j]/1000
					Variable firstSample=round((firstX-dimOffset(Stimulus,0))/dimdelta(Stimulus,0))
					Variable lastSample=round((lastX-dimOffset(Stimulus,0))/dimdelta(Stimulus,0))
					// Not using x2pnt because of a rounding bug in that function.  
					if(lastSample>firstSample) // Pulse is at least one sample in duration and occurs before the end of the sweep.  
						if(lastSample<dimsize(Stimulus,0))
							StimFunc(Stimulus,chan,firstSample,lastSample,i,j,k)
						else
							printf "A non-zero component to the stimulus extends beyond the stimulus duration.  Zeroing this component.\r" 
						endif
					endif
				endfor
			endif
		endfor
	endfor
	
	// Test pulse.  
	for(k=0;k<LCM_[chan];k+=1)
		testPulseApplied=0
		for(j=0;j<pulseSets;j+=1)
			if(!paramisdefault(triparity) && mod(j,3)!=triparity)
				continue
			endif
			remain=mod(k,divisor[j])
			if(Divisor[j]<=1 || (Remainder[j] & 2^remain)) // If this pulse set is active on this sweep number.  
				if(testPulseFound && !testPulseApplied && TestPulseOn[j] && (paramisdefault(triparity) || mod(j,3)==0))
					firstSample=x2pnt(Stimulus,testPulsestart)
					lastSample=x2pnt(Stimulus,testPulsestart+testPulselength)
					lastSample=min(dimsize(Stimulus,0)-2,lastSample)
					Stimulus[firstSample,lastSample][k]-=testPulseampl
					testPulseApplied=1 // Mark the test pulse as having been appled so that it is applied at most once per channel per sweep.  
				endif
			endif
		endfor
	endfor
	
	//if(WinType("SuperClampWin"))
	//	Variable holdingVal=SuperClampCheck(channel)
	//	Stimulus+=holdingVal
	//endif
	return GetWavesDataFolder(Stimulus,2)
End

Function ConversionFactor(units1,units2)
	String units1,units2
	
	if(StringMatch(units1,units2))
		return 1
	endif
	strswitch(units1+" to "+units2)
		case "mV to V":
			return 0.001
		case "V to mV":
			return 1000
		case "pA to nA":
			return 0.001
		case "nA to pA":
			return 1000
		case "pS to S":
			return 1e-12
		case "pS to mS":
			return 1e-9
		case "pS to uS":
			return 1e-6	
		case "nS to S":
			return 1e-9
		case "nS to mS":
			return 1e-6
		case "nS to uS":
			return 1e-3	
		default:
			return 0
	endswitch
End

// Returns the maximum stimulus parameter (e.g. "IPI") on the presynaptic channel 'pre'.  
Function MaxStimParam(param,pre[,sweep])
	string param // Stimulus parameter, e.g. "IPI" or "Width".  
	Variable pre // Use -1 for all channels.  Only works for current sweep.  
	variable sweep
	
	variable numChannels=GetNumChannels()
	variable currSweep=GetCurrSweep()
	sweep=paramisdefault(sweep) ? currSweep : sweep
	if(pre==-1 && sweep!=currSweep)
		sweep=currSweep
		printf "MaxStimParam() was called with sweep number less than the current sweep number and pre=-1.\r"
	endif
	
	if(sweep<currSweep)
		dfref chanDF=GetChanDF(pre)
		wave chanHistory=GetChanHistory(pre)
		Extract /free chanHistory,Temp,(p==sweep && q==FindDimLabel(chanHistory,1,param))
	else
		make /free/n=0 Temp
		variable i
		for(i=0;i<numChannels;i+=1) // TO DO: Fix to reflect the fact that there may be fewer channels at this points than earlier in the experiment.  
			if((pre==-1 || pre==i) && IsChanActive(i))
				wave ParamWave=Core#WavPackageSetting(module,"stimuli",GetChanName(i),param)
				concatenate {ParamWave},Temp
			endif
		endfor
	endif
	if(numpnts(Temp))
		WaveStats /Q/M=1 Temp
		Variable maxx=V_max
	else
		strswitch(param)  // Default values so that windows don't get screwed up.  
			case "IPI":
				maxx=0//50
				break
			case "Pulses":
				maxx=1
				break
			case "Width":
				maxx=1
				break
			default: 
				maxx=1
		endswitch
	endif
	return maxx
End

// Doesn't take into account the possibility of channels being inactive, or widths, amplitudes, or pulse numbers being zero.  
Function EarliestStim(sweep[,chan,channel_label,ignoreRemainder])
	Variable sweep,chan
	String channel_label
	Variable ignoreRemainder // Consider stimulation that shouldn't actually occur because the remainder doesn't match mod(sweep,divisor).  
	
	Variable i,earliest_stim=Inf
	Wave /T Labels=GetChanLabels()
	if(ParamIsDefault(chan))
		if(ParamIsDefault(channel_label)) // All channnels.  
			Variable checkAllChannels=1
		else
			FindValue /TEXT=channel_label /TXOP=4 Labels
			if(V_Value>=0)
				chan=V_Value
			else
				printf "No channel with Label %s/r",channel_label
			endif
		endif
	endif
	
	variable currSweep=GetCurrSweep()
	variable numChannels=GetNumChannels()
	dfref df=Core#InstanceHome(module,"stimuli",GetChanName(chan))
	if(sweep>=currSweep) // Next sweep.  
		sweep=currSweep
		wave /sdfr=df Begin,Ampl,dAmpl,Width,Pulses,Divisor,Remainder
		make /free/n=0 TempBeginNoZeroes
		if(checkAllChannels)
			for(i=0;i<numChannels;i+=1)
				if(IsChanActive(i))
					if(ignoreRemainder)
						Extract /O Begin,TempBeginNoZeroes_,(Width!=0 && ((Ampl!=0 && Pulses!=0) || (dAmpl!=0 && Pulses>1)))
					else
						Extract /O Begin,TempBeginNoZeroes_,(Width!=0 && ((Ampl!=0 && Pulses!=0) || (dAmpl!=0 && Pulses>1))) && (Divisor<=1 || (Remainder & 2^mod(sweep,Divisor)))
					endif
					concatenate {TempBeginNoZeroes_},TempBeginNoZeroes
				endif
			endfor			
		else//if(IsChanActive(chan))
			if(ignoreRemainder)
				Extract /O Begin,TempBeginNoZeroes,(Width!=0 && ((Ampl!=0 && Pulses!=0) || (dAmpl!=0 && Pulses>1)))
			else
				Extract /O Begin,TempBeginNoZeroes,(Width!=0 && ((Ampl!=0 && Pulses!=0) || (dAmpl!=0 && Pulses>1))) && (Divisor<=1 || (Remainder & 2^mod(sweep,Divisor)))
			endif
		endif
		if(numpnts(TempBeginNoZeroes))
			WaveStats /Q TempBeginNoZeroes
			earliest_stim=V_min
		endif
	else // A sweep that was already acquired.  
		String channelList=""
		for(i=0;i<numChannels;i+=1)
			if(checkAllChannels || i==chan)
				channelList+=num2str(i)+";"
			endif
		endfor
		for(i=0;i<ItemsInList(channelList);i+=1)
			chan=str2num(StringFromList(i,channelList))
			dfref chanDF=GetChanDF(chan)
			wave /z SP=GetChanHistory(chan)
			Variable beginCol=FindDimLabel(SP,1,"Begin")
//			Variable amplCol=FindDimLabel(SP,1,"Ampl")
//			Variable widthCol=FindDimLabel(SP,1,"Width")
//			Variable pulsesCol=FindDimLabel(SP,1,"Pulses")
//			Variable divisorCol=FindDimLabel(SP,1,"Divisor")
//			Variable remainderCol=FindDimLabel(SP,1,"Remainder")
			if(waveexists(SP))
				Extract /O SP,TempBeginNoZeroes,(p==sweep && q==beginCol && SP[p][%Width][r]>0 && ((SP[p][%Ampl][r]!=0 && SP[p][%Pulses][r]>0) || ((SP[p][%dAmpl][r]!=0 && SP[p][%Pulses][r]>1))) && (SP[p][%Divisor][r]<=1 || (SP[p][%Remainder][r] & 2^mod(sweep,SP[p][%Divisor][r]))))
				if(numpnts(TempBeginNoZeroes))
					WaveStats /Q TempBeginNoZeroes
					earliest_stim=min(earliest_stim,V_min)
				endif
			endif
		endfor
	endif
	KillWaves /Z TempBegin,TempAmpl,TempWidth,TempPulses,TempBeginNoZeroes
	return earliest_stim/1000 // Convert from ms to s.  
End

Function Label2Chan(labell)
	String labell
	wave Labels=GetChanLabels()
	FindValue /TEXT=labell /TXOP=4 Labels
	if(V_Value>=0)
		return V_Value
	else
		printf "There is no label %s in the Labels wave.\r",labell
	endif
End

Function /S Chan2Label(chan[,quiet])
	variable chan,quiet
	
	return Core#StrPackageSetting(module,"channelConfigs",GetChanName(chan),"label_",default_="Chan_"+num2str(chan),quiet=quiet)
End

// Returns a positive value if any filters are on.  
Function FiltersOn(chan)
	Variable chan
	
	string filters="notch;wyldpoint;low;high;zero;leakSubtract"
	dfref df=Core#InstanceHome(module,"filters",GetChanName(chan))
	variable i,val=0
	if(datafolderrefstatus(df))
		for(i=0;i<itemsinlist(filters);i+=1)
			string filter=stringfromlist(i,filters)
			nvar /z/sdfr=df filterOn=$filter
			if(nvar_exists(filterOn))
				val+=filterOn*(2^i)
			else
				printf "Could not find filter value '%s' on channel %d.\r",filter,chan
			endif
		endfor
	endif
	return val
End

Function WaveSave(chan[,path,as])
	variable chan
	 string path,as
	if(ParamIsDefault(path))
		path=Core#ProfilePath(package="Stimuli")
	endif
	newpath /o/q waveSavePath path
	string name
	sprintf name,"Raw_%d",chan
	if(paramisdefault(as))
		as="myWave"
		prompt as, "Save wave on channel "+num2str(chan)		// Set prompt for x param
		DoPrompt "Save", as
		if (V_Flag)
			return -1								// User canceled
		endif
	endif
	variable i
	string DAQs=GetDAQs()
	for(i=0;i<itemsinlist(DAQs);i+=1)
		string DAQ=stringfromlist(i,DAQs)
		dfref daqDF=GetDaqDF(DAQ)
		wave /Z toSave=daqDF:$name
		if(waveexists(toSave))
			break
		endif
	endfor
	if(waveexists(toSave))
		dfref df=Core#PackageHome("Acq","stimuli")
		string tempLoc="root:Temp"+num2str(abs(enoise(100000))) // Create a temporary folder for the renamed wave.  
		dfref temp=newfolder(tempLoc)
		duplicate /o toSave temp:$as /wave=tempSave
		Save /O/P=waveSavePath tempSave as as+".ibw"
		killwaves /z tempSave
		killdatafolder temp
	else
		DoAlert 0,name+" does not exist in root:"+DAQ
		return -2
	endif
End

Function WaveLoad(name[,path])
	String name,path
	if(!strlen(name))
		return 0
	endif
	if(ParamIsDefault(path))
		path=Core#ProfilePath(package="Stimuli")
		NewPath /O/Q/Z WaveLoadPath path
		path="WaveLoadPath"
	endif
	dfref currDF= GetDataFolderDFR()		// save
	dfref df=Core#PackageHome("Acq","stimuli")
	setdatafolder df
	LoadWave /H/O/Q/P=$path name+".ibw"
	SetDataFolder currDF					// and restore
	return V_flag>0 ? 0 : -1
End

Function MeanPowerSpectrum(chan,sweepList)
	Variable chan
	String sweepList
	
	dfref df=GetChanDF(chan)
	sweepList=ListExpand(sweepList)
	variable i
	for(i=0;i<ItemsInList(sweepList);i+=1)
		string sweepNum=StringFromList(i,sweepList)
		string sweepName="sweep"+sweepNum
		wave /sdfr=df w=$sweepName
		FFT /MAGS /DEST=fftd w
		if(i==0)
			Duplicate /o fftd MasterFFT
		else
			MasterFFT+=fftd
		endif
	endfor
	MasterFFT/=i
End

Function AverageSweeps(chan,sweep_list)
	Variable chan
	String sweep_list
	String full_list=ListExpand(sweep_list)
	Variable i,flag=0,count=0
	Wave /T Labels=GetChanLabels()
	dfref df=GetChanDF(chan)
	for(i=0;i<ItemsInList(full_list);i+=1)
		string sweep_name="sweep"+StringFromList(i,full_list)
		wave /z/sdfr=df Sweep=$sweep_name
		if(waveexists(Sweep))
			if(!flag)
				String avg_name=CleanupName("Average_"+Labels[chan]+"_"+sweep_list,0)
				Duplicate /o Sweep df:$avg_name /wave=avg
				avg=0
				flag=1
			endif
			avg+=Sweep
			count+=1
		endif
	endfor
	Avg/=Count
	Display
	Variable red,green,blue; GetChanColor(chan,red,green,blue)
	AppendToGraph /c=(red,green,blue) Avg
End

Function Concat(wave_list,df[,prefix,split,to_append,downscale])
	String wave_list // A list like "5,17;23,28".
	dfref df
	String prefix // e.g. "root:cellL2:" and "sweep".
	Variable split // If there are splits in the list, i.e. it is non-contiguous, make multiple waves.
	Variable to_append // To append on the topmost graph, rather than make a new graph.
	Variable downscale // A factor to downscale the concatenated trace by, in order to make display faster and to save memory.  
	
	if(IsEmptyString(wave_list))
		variable last_sweep=GetCurrSweep()
		wave_list="1,"+num2str(last_sweep)
	endif
	split=ParamIsDefault(split) ? 0 : split
	downscale=ParamIsDefault(downscale) ? 0 : downscale
	if(ParamIsDefault(prefix))
		prefix="sweep"
	endif
	string folderName=getdatafolder(1,df)
	prefix=joinpath({folderName,prefix})
	String wave_name,name,old_name,new_name
	Variable i=0,j,start_sweep_num,end_sweep_num,wave_num,duration,last_start_time,this_start_time,time_diff
	Variable allowable_gap = 2 // The allowable gap between sweeps (in seconds) required to consider them continuous
	wave /t Labels=GetChanLabels()
	FindValue /TEXT=(getdatafolder(0,df)) /TXOP=4 Labels
	variable chan=v_value
	variable red,green,blue; GetChanColor(chan,red,green,blue)
	wave_list=ListExpand(wave_list)
	
	// Remove non-existent waves from the list
	Do
		wave_name=prefix+StringFromList(i,wave_list)
		if(!waveexists($wave_name))
			wave_list=RemoveListItem(i,wave_list)
		else
			i+=1
		endif
	While(i<ItemsInList(wave_list))
	if(IsEmptyString(wave_list))
		printf "There are no waves to concatenate of the form %s\r.",prefix
		return 0
	endif
	
	if(!to_append)
		Display /N=ConcatenatedSweeps /K=1
	endif
	
	if(!split)
		wave_list=ListContract(wave_list)
		name=ReplaceString(",",wave_list,"to")
		name=ReplaceString(";",name,"and")
		name=CleanupName("Sweep_"+name,1)
		wave_list=ListExpand(wave_list)
		wave_list=AddPrefix(wave_list,prefix)
		if(!IsEmptyString(wave_list))
			if(!StringMatch(wave_list[strlen(wave_list)-1],";"))
				wave_list+=";"
			endif
			Concatenate /O/NP wave_list, df:$name
			AppendToGraph /c=(red,green,blue) df:$name
		endif
	else
		String append_list="",offset_list="",sweep_name
		Variable offset
		Wave SweepT=GetSweepT()
		old_name=folderName+"TempConcat"
		start_sweep_num=NumFromList(0,wave_list)
		for(i=0;i<ItemsInList(wave_list);i+=1)
			wave_num=NumFromList(i,wave_list)
			wave_name=prefix+num2str(wave_num)
			Wave Sweep=$wave_name
			duration=rightx(sweep)-leftx(sweep)
			this_start_time=SweepT[wave_num-1]
			time_diff=(this_start_time - last_start_time)*60
			if(i==0 || abs(duration - time_diff)>allowable_gap) // If the gap between sweeps exceeds allowable_gap seconds
				if(i != 0)
					new_name=folderName+"Sweep_"+num2str(start_sweep_num)+"to"+num2str(end_sweep_num)
					Duplicate /o $old_name $new_name; KillWaves $old_name
					append_list+=new_name+";"; offset_list+=num2str(SweepT[start_sweep_num-1]*60)+";"
				endif
				Concatenate /O/NP {$wave_name},$old_name
				start_sweep_num=wave_num
			else
				Concatenate /NP {$wave_name},$old_name
			endif
			end_sweep_num=wave_num
			last_start_time=SweepT[wave_num-1]
		endfor
		new_name=folderName+"Sweep_"+num2str(start_sweep_num)+"to"+num2str(end_sweep_num)
		Duplicate /o $old_name $new_name; KillWaves $old_name
		append_list+=new_name+";"; offset_list+=num2str(SweepT[start_sweep_num-1]*60)+";"
		for(j=0;j<ItemsInList(append_list);j+=1)
			sweep_name=StringFromList(j,append_list)
			offset=NumFromList(j,offset_list)
			if(downscale>1)
				Downsample($sweep_name,downscale,in_place=1)
			endif
			AppendToGraph /c=(red,green,blue) $sweep_name
			ModifyGraph offset($TopTrace())={offset,0} 
		endfor
	endif
	Cursors()
End

// Stimulus assembler prototype.  
Function Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	variable ampl=GetStimParam("Ampl",chan,pulseSet)
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet)
	Stimulus[firstSample,lastSample][sweepParity][pulseSet]+=ampl+dampl*pulseNum
End

// ------------------------ Some custom stimulus functions. ----------------------------------

function AlphaSynapse_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	variable ampl=GetStimParam("Ampl",chan,pulseSet)
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet)
	Stimulus[firstSample,lastSample][sweepParity][pulseSet]+=ampl+dampl*pulseNum
	variable pulses=GetStimParam("Pulses",chan,pulseSet)
	if(pulseNum==pulses-1)
		wave template = AlphaSynapso(1,3,0,50)
		Convolve2(template,Stimulus,col=sweepParity)
	endif
end

function Template_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	variable ampl=GetStimParam("Ampl",chan,pulseSet)
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet)
	variable begin = GetStimParam("Begin",chan,pulseSet)
	
	Stimulus[firstSample][sweepParity][pulseSet]+=ampl+dampl*pulseNum // Pulse of only one sample, to be convolved below.  
	variable pulses=GetStimParam("Pulses",chan,pulseSet)
	if(pulseNum==pulses-1)
		wave /z template=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"template")
		if(waveexists(template))
			Convolve2(template,Stimulus,col=sweepParity)
		endif
	endif
end

function PoissonTemplate_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	variable pulses=GetStimParam("Pulses",chan,pulseSet)
	if(pulseNum == pulses - 1)
		variable ampl=GetStimParam("Ampl",chan,pulseSet)
		variable dAmpl=GetStimParam("dAmpl",chan,pulseSet)
		variable begin = GetStimParam("Begin",chan,pulseSet)
		variable width = GetStimParam("Width",chan,pulseSet)
		variable delta_x = dimdelta(Stimulus,0)
		make /free/n=(pulses) locs=abs(enoise(0.001*width/delta_x))
		locs += 0.001*begin/delta_x
		variable i
		for(i=0;i<numpnts(locs);i+=1)
			Stimulus[floor(locs[i])][sweepParity]+=ampl+dampl*i
		endfor
		wave /z template=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"template")
		if(waveexists(template))
			Convolve2(template,Stimulus,col=sweepParity)
		endif
	endif
end

function Noisy_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet)
	Stimulus[firstSample,lastSample][sweepParity][pulseSet]+=gnoise(dAmpl)
end

function Frozen_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	variable multiplier=GetStimParam("dAmpl",chan,pulseSet)
	SetStimParam("dAmpl",chan,pulseSet,0) // Set dAmpl to be 0 because we are not using this parameter as intended in Default_stim.  
	Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	SetStimParam("dAmpl",chan,pulseSet,multiplier) // Set it back to its original value.  
	wave /z frozen=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"frozen")
	if(waveexists(frozen))
		lastSample = min(lastSample,firstSample+numpnts(frozen)-1) // Only extend to the end of the pulse or the end of the frozen wave, whichever comes first.  
		Stimulus[firstSample,lastSample][sweepParity][pulseSet]+=multiplier*frozen[p-firstSample][sweepParity]
	endif
end

function FrozenPlusNegative_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	variable multiplier=GetStimParam("dAmpl",chan,pulseSet)
	SetStimParam("dAmpl",chan,pulseSet,0) // Set dAmpl to be 0 because we are not using this parameter as intended in Default_stim.  
	Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	SetStimParam("dAmpl",chan,pulseSet,multiplier) // Set it back to its original value.  
	string daq=Chan2DAQ(chan)
	variable IPI=GetStimParam("IPI",chan,pulseSet)
	variable numPulses=GetStimParam("pulses",chan,pulseSet)
	variable kHz=GetKHz(daq)
	wave /z frozen=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"frozen")
	if(waveexists(frozen))
		lastSample = min(lastSample,firstSample+numpnts(frozen)-1) // Only extend to the end of the pulse or the end of the frozen wave, whichever comes first.  
		Stimulus[firstSample,lastSample][sweepParity][pulseSet]+=multiplier*frozen[p-firstSample][sweepParity]
		Stimulus[firstSample+numPulses*IPI*kHz,lastSample+numPulses*IPI*kHz][sweepParity][pulseSet]-=multiplier*frozen[p-firstSample-numPulses*IPI*kHz]
	endif
end

function PoissonAlpha_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	variable ampl=GetStimParam("Ampl",chan,pulseSet)
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet)
	variable width=lastSample-firstSample
	variable start=abs(enoise(dimsize(Stimulus,0)))
	Stimulus[start,start+width][sweepParity][pulseSet]+=ampl+dampl*pulseNum
	variable pulses=GetStimParam("Pulses",chan,pulseSet)
	if(pulseNum==pulses-1)
		wave template = AlphaSynapso(1,3,0,50)
		Convolve2(template,Stimulus,col=sweepParity)
	endif
end

//sin function added by AG 3-21-13
function Sine_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	variable freq=GetStimParam("dAmpl",chan,pulseSet)		//Set frequency (Hz)
	variable ampl=GetStimParam("Ampl",chan,pulseSet)		//Set amplitude
	variable kHz=GetKHz(MasterDAQ())
	variable start = firstSample/(1000*kHz)
	
	Stimulus[firstSample,lastSample][sweepParity][pulseSet]+= ampl * sin(2*pi*(x-start)*freq)
end

//sin function added by AG 3-21-13
function Ramp_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	variable amplEnd=GetStimParam("dAmpl",chan,pulseSet)		//Set frequency (Hz)
	variable amplStart=GetStimParam("Ampl",chan,pulseSet)		//Set amplitude
	variable kHz=GetKHz(MasterDAQ())
	variable start = firstSample/(1000*kHz)
	variable width = (lastSample-firstSample+1)/(1000*kHz)
	variable slope = (amplEnd-amplStart)/width
	
	Stimulus[firstSample,lastSample][sweepParity][pulseSet]+= amplStart + slope*(x-start)
end

#ifndef Aryn
function Optimus1_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	if(!exists("root:sharedE"))
		variable activeWidth=GetStimParam("Width",chan,0)
#if exists("MakeSharedInputs1")
		MakeSharedInputs1()
#else
		DoAlert 0,"You need to get the function MakeSharedInputs() first!  Ask Rick."
		abort
#endif
	endif
	string DAQ=MasterDAQ()
	dfref df=GetDAQdf(DAQ)
	variable /g df:reassemble=1 // Reassemble the stimulus each sweep.  
	variable sampling=50000 // In dynamic clamp, must sample at 50000 Hz due to hardware.  
	variable kHz=sampling/1000
	wave w_num_pulses = GetNumPulses(chan)
	variable numPulses = w_num_pulses[pulseSet]
	if(mod(pulseSet,3)!=0) // If not pulse set 0, i.e. not the bias, i.e. E or I.  
		//wave sharedE=root:sharedE, sharedI=root:sharedI
		variable ampl=GetStimParam("Ampl",chan,pulseSet)
		variable dAmpl=GetStimParam("dAmpl",chan,pulseSet)
		variable begin=GetStimParam("Begin",chan,pulseSet)
		activeWidth=GetStimParam("Width",chan,pulseSet)
		variable width=lastSample-firstSample
		variable start=begin*kHz+abs(enoise(activeWidth*kHz))
		Stimulus[start,start][sweepParity]+=1
		variable pulses=GetStimParam("Pulses",chan,pulseSet)
		variable length=dimsize(Stimulus,0)
		if(pulseNum==numPulses-1)
			wave alpha=AlphaSynapso(ampl+dampl*pulseNum,width/kHz,0,width*10/kHz)
			start=begin*kHz
			variable finish=(begin+activeWidth)*kHz-1
			strswitch(nameofwave(Stimulus))
				case "eWave":
					wave /z sharedE=root:sharedE
					Stimulus[start,finish]+=sharedE[p-start]
					break
				case "iWave":
					wave /z sharedI=root:sharedI
					Stimulus[start,finish]+=sharedI[p-start]
					break
			endswitch
			Convolve2(alpha,Stimulus,col=sweepParity)
		endif
		Redimension /n=(length,-1) Stimulus
	else // For the bias, do the normal stuff.  
		Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	endif
end

// Auxiliary function for Optimus1_stim
static Function MakeSharedInputs1()
	variable ePulses=GetStimParam("Pulses",0,1)
	variable iPulses=GetStimParam("Pulses",0,2)
	variable activeWidth=GetStimParam("Width",0,0)/1000 // In seconds.  
	variable eRate=ePulses/activeWidth
	variable iRate=iPulses/activeWidth
	setdatafolder root:
	make /o/n=(activeWidth*50000) sharedE,sharedI
	SetScale x,0,activeWidth,sharedE,sharedI
	sharedE=poissonnoise(eRate/50000)
	sharedI=poissonnoise(iRate/50000)
End

function Optimus2_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	string stimName=GetStimulusName(chan)
	if(!exists("root:"+stimName+"_sharedE") || !exists("root:"+stimName+"_sharedE"))
		MakeSharedInputs2(stimName)
	endif
	string DAQ=MasterDAQ()
	dfref df=daqDF
	variable /g df:reassemble=1 // Reassemble the stimulus each sweep.  
	variable sampling=50000 // In dynamic clamp, must sample at 50000 Hz due to hardware.  
	variable kHz=sampling/1000
	nvar /sdfr=daqDF numPulses
	if(mod(pulseSet,3)!=0) // If not pulse set 0, i.e. not the bias, i.e. E or I.  
		//wave sharedE=root:sharedE, sharedI=root:sharedI
		variable ampl=GetStimParam("Ampl",chan,pulseSet)
		variable dAmpl=GetStimParam("dAmpl",chan,pulseSet)
		variable begin=GetStimParam("Begin",chan,0)
		variable activeWidth=GetStimParam("Width",chan,0)
		variable width=lastSample-firstSample
		variable start=begin*kHz+abs(enoise(activeWidth*kHz))
		Stimulus[start,start][sweepParity]+=1
		variable pulses=GetStimParam("Pulses",chan,pulseSet)
		variable length=dimsize(Stimulus,0)
		if(pulseNum==numPulses-1)
			nvar /z/sdfr=root: useShared,poissonOnly
			if(!nvar_exists(useShared) || useShared)
				start=begin*kHz
				variable finish=(begin+activeWidth)*kHz-1
				variable sweepIndex=CtrlNumValue("sweepIndex",win="SweepIndexWin")
				wave /z/sdfr=root: sharedE=$(stimName+"_sharedE"), sharedI=$(stimName+"_sharedI")
				strswitch(nameofwave(Stimulus))
					case "eWave":
						Stimulus[start,finish]+=sharedE[p-start][sweepIndex]
						break
					case "iWave":
						Stimulus[start,finish]+=sharedI[p-start][sweepIndex]
						break
				endswitch
			endif
			if(!nvar_exists(poissonOnly) || !poissonOnly)
				wave alpha=AlphaSynapso(ampl+dampl*pulseNum,width/kHz,0,width*10/kHz)
				Convolve2(alpha,Stimulus,col=sweepParity)
			endif
		endif
		Redimension /n=(length,-1) Stimulus
	else // For the bias, do the normal stuff.  
		Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	endif
end

// Auxiliary function for Optimus2_stim
function MakeSharedInputs2(stimName)
	string stimName
	
	variable chan=DAC2Chan("0")
	dfref df=root:ITC
	wave /sdfr=df eWave,iWave
	variable i
	variable begin=GetStimParam("Begin",chan,0)
	variable kHz=50
	variable activeWidth=GetStimParam("Width",chan,0)
	make /o/n=(kHz*activeWidth,100) root:$(stimName+"_sharedE") /wave=sharedE,root:$(stimName+"_sharedI") /wave=sharedI
	variable /g root:useShared=0, root:poissonOnly=1
	for(i=0;i<dimsize(sharedE,1);i+=1)
		prog("Shared",i,dimsize(sharedE,1))
		Assemble(chan,eWave,triparity=1)
		Assemble(chan,iWave,triparity=2)
		sharedE[][i]=eWave[p+begin*kHz]
		sharedI[][i]=iWave[p+begin*kHz]
	endfor
	variable /g root:useShared=1,root:poissonOnly=0
	newpath /o/q desktop specialdirpath("Desktop",0,0,0)
	save /p=desktop sharedE as stimName+"_sharedE_"+Timestamp()+".ibw"
	save /p=desktop sharedI as stimName+"_sharedI_"+Timestamp()+".ibw"
end

function /s AssemblerNames(name)
	string name
	
	strswitch(name)
		case "DefaultPlusNegative":
			return "Default + Negative/4"
			break
		case "FrozenPlusNegative":
			return "Frozen + Negative"
			break
		default:
			return name
	endswitch
end

function DefaultPlusNegative4_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity
	
	Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity)
	variable IPI=GetStimParam("IPI",chan,pulseSet)
	variable Ampl=GetStimParam("Ampl",chan,pulseSet)
	variable numPulses=GetStimParam("Pulses",chan,pulseSet)
	string daq = MasterDAQ()
	variable kHz=GetKHz(daq)
	if(pulseSet==0 && pulseNum==(numPulses-1)) // Last pulse of first pulse set.  
		variable i
		for(i=0;i<NUM_LEAK_PULSES;i+=1)
			Stimulus[firstSample+(i+1)*kHz*IPI,lastSample+(i+1)*kHz*IPI][sweepParity][pulseSet]=-Ampl/NUM_LEAK_PULSES
		endfor
	endif
end

// PSC Noise (alpha-filtered poisson process) as in Galan et al, 2006.  
Function /wave MakePSCNoise(duration,stepBegin,stepDuration,stepDC,ampl,rate,tau,kHz)
	Variable duration,stepBegin,stepDuration,stepDC,ampl,rate,tau,kHz
	
	if(rate<0)
		printf "Rate must be > 0.\r"
		return NULL
	endif
	Variable points=kHz*duration*1000
	dfref df=Core#PackageHome(module,"stimuli")
	Make /o/n=(points) df:PSCNoise /WAVE=Noise=0
	SetScale x,0,duration,Noise
	Variable start=x2pnt(Noise,stepBegin)
	Variable finish=x2pnt(Noise,stepBegin+stepDuration)
	
	Variable t=stepBegin+expnoise(1/rate)
	Do
		Noise[x2pnt(PSCNoise,t)]+=ampl
		t+=expnoise(1/rate)
	While(t<stepBegin+stepDuration)
	Wave Alpha=MakeAlpha(0.1,1/(1000*kHz),tau)
	Convolve Alpha,Noise
	Noise[start,finish]+=stepDC
	Noise[finish,]=0
	Redimension /n=(points) Noise
	//KillWaves /Z Alpha
	return Noise
End

// Alpha-filtered white noise as in Galan et al, 2006.  
Function /wave MakeAlphaNoise(duration,stepBegin,stepDuration,stepDC,ampl,tau,kHz)
	Variable duration,stepBegin,stepDuration,stepDC,ampl,tau,kHz
	
	Variable points=kHz*duration*1000
	dfref df=Core#PackageHome(module,"stimuli")
	Make /o/n=(points) df:AlphaNoise /WAVE=Noise=0
	SetScale x,0,duration,Noise
	Variable start=x2pnt(Noise,stepBegin)
	Variable finish=x2pnt(Noise,stepBegin+stepDuration)
	
	Noise[start,finish]+=gnoise(ampl)
	Wave Alpha=MakeAlpha(0.1,1/(1000*kHz),tau)
	Convolve Alpha,Noise
	Noise[start,finish]+=stepDC
	Noise[finish,]=0
	Redimension /n=(points) Noise
	//KillWaves /Z Alpha
	return Noise
End

// Returns an alpha function with a sum of 1.  Can be used for convolution with another signal.  
static Function /WAVE MakeAlpha(duration,delta,tau)
	Variable duration,delta,tau
	Make /FREE/o/n=(duration/delta) Alpha
	SetScale x,0,duration,Alpha
	Alpha=x*exp(-x/tau)
	Variable summ=sum(Alpha)
	Alpha/=summ
	return Alpha
End