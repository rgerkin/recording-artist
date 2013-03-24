
// $Author: rick $
// $Rev: 632 $
// $Date: 2013-03-15 17:17:39 -0700 (Fri, 15 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=ITC
static strconstant module="Acq"
static strconstant type="ITC"

static function /s DAQType(DAQ[,quiet])
	string DAQ
	variable quiet
	
	return "ITC"
end

static function /s InputChannelList([DAQ])
	string DAQ
	
	return "0;1;2;3;4;5;6;7;D;N;"
end

static function /s OutputChannelList([DAQ])
	string DAQ
	
	return "0;1;2;3;D;N;"
end

static Function BoardGain(DAQ)
	string DAQ
	
	return 3.2
End

static Function SpeakReset([DAQ])
	String DAQ
	
	Execute /Q "ITC18StimClear 0"
End

static Function Start(period,bits[,clock])
	variable period,bits,clock
	string cmd
	sprintf cmd,"ITC18StartAcq %d,%d,%d",period,bits,clock
	Execute /Q cmd
End

static Function Stop()
	Execute /Q "ITC18StopAcq"
End

static Function SetupTriggers(pin[,DAQ])
	Variable pin
	String DAQ
End

static Function ZeroAll([DAQ])
	String DAQ
	
	String command=""
	command+="ITC#Stop();"
	//command+="ITC18StimClear 0;" // This command takes a long time, so I'm going to skip it.  
	//NVar boardGain=root:$(ITC):boardGain
	variable i
	for(i=0;i<4;i+=1)
		Variable volts=0
		if(WinType("SuperClampWin")) // If Super Clamp Commodore is open.  
			variable chan=DAC2Chan(num2str(i))
			if(chan>=0 && StringMatch(Chan2DAQ(chan),DAQ)) // If it is there and it is a channel belonging to this DAQ.  
				volts=0.001*SuperClampCheck(chan)/GetOutputGain(chan,Inf) // Set the offset to the current super clamp value.  
			endif
		endif
		command+="ITC18SetDAC "+num2str(i)+","+num2str(volts)+";"
		command+="ITC18WriteDigital1 0;"
	endfor
	variable dynamic=InDynamicClamp() && !IsSealTestOn()
	if(dynamic)
		command+="ITC18Reset;" // Takes a while, but may be important to clear the buffers.  
		command+="ITC#SetupDynamicClamp();"
	endif
	Execute /Q command
End

static Function BoardReset(Device[,DAQ])
	variable device
	string DAQ
	
	execute /Q "ITC18Reset"
End

static Function BoardInit([DAQ])
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	BoardReset(1,DAQ=DAQ)
	ZeroAll(DAQ=DAQ)
	GetDaqDF(DAQ) // Create the DAQ data folder.  
End

static Function /S DAQError([DAQ])
	String DAQ
	
	return "There appears to be no error checking provided by the ITC18 XOP."  
End

static Function DefaultKHz(DAQ)
	String DAQ
	
	dfref df=Core#ObjectManifest(module,"DAQs","kHz")
	nvar /sdfr=df value
	return value
End

static Function Listen(device,gain,list,param,continuous,endHook,errorHook,other[,now,DAQ])
	Variable device,gain
	String list
	Variable param,continuous
	String endHook,errorHook,other
	Variable now
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	// Exclude channels meant for another device (e.g. the NIDAQ).  
	String newList=""
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		String inputMap=StringFromList(1,item,",")
		if(StringMatch(inputMap[0],"N") && strlen(inputMap)>1) // If it is a channel not intended for the ITC.  
		else
			newList+=item+";"
		endif
	endfor
	list=newList
	if(!strlen(list))
		return -1	
	endif

//	String input_0=StringFromList(0,StringFromList(0,list),",")
	// Set the sampling period.  
	i=0
	do
		string inputWaveName=StringFromList(0,StringFromList(i,list),",")
		wave /Z inputWave=$inputWaveName
		variable per=GetPeriod(DAQ,w=inputWave)
		i+=1
	while(numtype(per)==2 && i<ItemsInlist(list))
	//Variable per=dimdelta($input_0,0)/0.00000125
	dfref daqDF=GetDaqDF(DAQ)
	variable /g daqDF:period=per
	Execute /Q "ITC18SetPeriod "+num2str(per)
	
	MakeInputMultiplex(list,DAQ=DAQ)

	if(now)
		String inputs=StringFromList(0,list)
		wave w=$inputs
		if(continuous)
			Samp(DAQ,in=w)
		else
			Samp(DAQ,in=w)
		endif
	endif
End

static Function GetPeriod(DAQ[,w])
	wave /z w // Optional input wave whose scaling should be used to compute the period.  
	string DAQ
	
	if(!paramisdefault(w) && waveexists(w))
		variable period=dimdelta(w,0)
	else
		period=0.001/GetKHz(DAQ)
	endif
	period/=0.00000125
	return period
End

static Function OutMultiplex(outputWaves[,DAQ])
	String outputWaves
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	Variable numOutputs=ItemsInList(outputWaves)
	dfref df=GetDaqDF(DAQ)
	svar /sdfr=df inputWaves
	variable sealTest=IsSealTestOn()
	Variable numInputs=ItemsInList(inputWaves) // This is the important number since it may be larger.   
	Variable plexFactor=max(numInputs,numOutputs)
	nvar /sdfr=df boardGain
	Make /o/n=0 df:OutputMultiplex /WAVE=OutputMultiplex
		
	variable i; string usedSlots=""
	for(i=0;i<numOutputs;i+=1)
		String wave_info=StringFromList(i,outputWaves)
		String output_wave=StringFromList(0,wave_info,",")
		if(strlen(output_wave))
			if(sealtest)
				wave /z OutputWave=$output_wave
				string chanName=getwavesdatafolder(OutputWave,0)
				variable chan=GetChannelNum(chanName)
				string channel=num2str(chan)
			else
				channel=StringFromList(1,output_wave,"_") // A channel number, e.g. "0", "1", etc.  
				chan=str2num(channel)
			endif
			string map=Chan2ADC(chan)
		else
			map="N" // No output wave specified, so assume null output.  
		endif
		variable usedSlot=WhichListItem(map,usedSlots)
		if(usedSlot>=0)// && !StringMatch(OutputMap[chan],"D")) // If this output channel was already used (not counting D, which can be used by multiple channels).  
			Variable slot=usedSlot // Add these output values to the multiplex slot originally used for that channel.  
		else
			slot=ItemsInList(usedSlots) // Use a new slot.  
			usedSlots+=Chan2ADC(chan)+";" // Add this to the list of used slots.  
		endif
		
		wave /Z OutputWave=$output_wave
		if(!WaveExists(OutputWave))
			continue
		endif	
		if(numpnts(OutputMultiplex)==0 && WaveExists(OutputWave))
			variable points=dimsize(OutputWave,0)
			Make /o/n=(points*plexFactor) df:OutputMultiplex=0
		endif
		
		Variable j
		strswitch(Chan2DAC(chan))
			case "D": // Digital Output
				OutputMultiplex[slot,*;plexFactor]+=round((OutputWave[(p-slot)/plexFactor] >= 2^15 || OutputWave[(p-slot)/plexFactor] < 0) ? 0 : OutputWave[(p-slot)/plexFactor])  // Values below 0 or above 255 will be set to 0.  
				break
			case "N": // Null output.  
				OutputMultiplex[slot,*;plexFactor]+=0
				break
			default:
				variable superClampOffset=SuperClampCheck(chan)/GetOutputGain(chan,Inf)
				OutputMultiplex[slot,*;plexFactor]+=(OutputWave[(p-slot)/plexFactor]+superClampOffset)*boardGain
				break
		endswitch
	endfor
End

static Function InDemultiplex(inputWaves[,DAQ])
	String inputWaves
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	dfref df=GetDaqDF(DAQ)
	wave /sdfr=df InputMultiplex
	variable numInputs=ItemsInList(inputWaves)
	nvar /sdfr=df boardGain,inPoints
	InputMultiplex/=boardGain
	variable range=numpnts(InputMultiplex)/numInputs
	variable start=inPoints/numInputs
	variable finish=start+range-1
	variable i,sealTest=IsSealTestOn()
	for(i=0;i<numInputs;i+=1)
		String wave_info=StringFromList(i,inputWaves)
		String input_wave=StringFromList(0,wave_info,",")
		wave /z/sdfr=df InputWave=$input_wave
		if(WaveExists(InputWave))
			if(sealtest)
				string chanName=getwavesdatafolder(InputWave,0)
				variable chan=GetChannelNum(chanName)
				string channel=num2str(chan)
			else
				channel=StringFromList(1,input_wave,"_") // A channel number, e.g. "0", "1", etc.  
				chan=str2num(channel)
			endif
			// Adjust for gain and A/D conversion (non-MX board)
			ControlInfo /W=$(DAQ+"_Selector") $("Mode_"+channel)
			Variable mode_num=V_Value-1
			String mode=S_Value
			if(StringMatch(input_wave,"*PressureSweep*")) // Seal test pressure will be acquired in unity mode.  
				mode="Unity"
				Variable inputGain=1000
			else
				inputGain=GetInputGain(chan,Inf)
			endif
			Variable superClampOffset=SuperClampOffsetCheck(chan)
			InputWave[start,finish]=InputMultiplex[i+(p-start)*numInputs]/inputGain// + superClampOffset
		endif
	endfor
End

static Function MakeInputMultiplex(input_waves[,DAQ])
	String input_waves
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	dfref df=GetDaqDF(DAQ)
	nvar /sdfr=df realTime
	variable sealtestOn=IsSealTestOn()
	Variable i,num_inputs=ItemsInList(input_waves)
	for(i=0;i<num_inputs;i+=1)
		String wave_info=StringFromList(i,input_waves)
		String input_wave=StringFromList(0,wave_info,",")
		wave /z/sdfr=df InputWave=$input_wave
		if(WaveExists(InputWave))
			break
		endif
	endfor
	if(realTime && !sealTestOn)
		variable points=min(realTimeSize,numpnts(InputWave))
	else
		points=numpnts(InputWave)
	endif
	Variable /G df:acqPoints=numpnts(InputWave)*num_inputs
	if(points==0)
		nvar /sdfr=df kHz,duration
		points=1000*kHz*duration
	endif
	Make /o/n=(points*num_inputs) df:InputMultiplex
End

static Function Speak(device,list,param[,now,DAQ])
	Variable device
	String list
	Variable param // 0 is continuous, 32 is only one time
	Variable now // Don't wait for SpeakAndListen, just start output now.  
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	OutMultiplex(list,DAQ=DAQ)
	dfref df=GetDaqDF(DAQ)
	if(now && numpnts(df:OutputMultiplex))
		if(param & 32)
			Stim(DAQ)
		else // For continuous acquisition.  
			Stim(DAQ,append_=1)
		endif
	endif
End

static Function SpeakAndListen([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	dfref df=GetDaqDF(DAQ)
	dfref statusDF=GetStatusDF()
	nvar /sdfr=df inPoints,acqPoints,duration,continuous,realTime,lastDAQSweepT
	variable sealTestOn=IsSealTestOn()
	variable dynamic=InDynamicClamp() && !sealtestOn
	
	if(!dynamic)
		variable FifoInSize=ReadAvailable(DAQ)
		variable FifoOutSize=WriteAvailable(DAQ)
	endif
	
	wave /sdfr=df in=InputMultiplex, out=OutputMultiplex 
	if(!dynamic && FifoInSize>numpnts(in)+10) // +6 because there is a weird overhead of 6 points for ITC18Samp calls.  
		svar /sdfr=df inputWaves,outputWaves
		string listenHook=GetListenHook(DAQ)
		nvar /sdfr=statusDF first,currSweep
		
		if(continuous || sealTestOn)
			if(sealTestOn && FifoInSize>4*numpnts(in)) // Too many points have accumulated.  .  
				//printf "Starting over.\r"
				SealTestStart(1,DAQ) // So just start over.  
				return 0
			endif
			if(sealTestOn && 2^20-FifoOutSize<0) // Output buffer is messed up.  
				//printf "Starting over.\r"
				SealTestStart(1,DAQ) // So just start over.  
				return 0
			endif
			if(first)
				Samp(DAQ)
				first=0
			else
				Samp(DAQ,append_=1)
			endif
			if(numpnts(out))
				if(!sealtestOn)
					wave divisor=GetDAQDivisor(DAQ)
					WaveStats /Q/M=1 Divisor
					if(V_max>1) // If there are different stimuli for each sweep.  
						SetOutputWaves(sweepNum=currSweep+2,DAQ=DAQ)
						Speak(1,outputWaves,32) // Update the stimulus for the next sweep.  
					endif
				endif
				Stim(DAQ,append_=1)
			endif
			if(realTime && !sealTestOn)
				InDemultiplex(inputWaves,DAQ=DAQ)
				DoUpdate
			endif
			
			inPoints+=numpnts(in)
			if((!realTime || sealTestOn) || inPoints>=acqPoints)
				inPoints=0
				Execute /Q listenHook
				lastDAQSweepT+=duration*1000000
			endif
		else
			if(realTime && !sealTestOn)
				if(first)
					Samp(DAQ)
					first=0
				else
					Samp(DAQ,append_=1)
				endif
				InDemultiplex(inputWaves,DAQ=DAQ)
				DoUpdate
			endif
			inPoints+=numpnts(in)
			if((!realTime || sealTestOn) || inPoints>=acqPoints)
				inPoints=0
				first=1
				Stop()
				if(!realTime || sealTestOn)
					Samp(DAQ)
				endif
				FifoInSize=ReadAvailable(DAQ)
				if(FifoInSize>6)
					Make /o/n=(FifoInSize-6) Garbage // Even though the wave size is six less than the FIFO size, somehow this clears the ITC FIFO.    
					Samp(DAQ,in=Garbage,append_=1) // Clear the remaining samples out of the ITC Fifo so they aren't in the next sweep.  
				endif
				Execute /Q listenHook
				Sequence(DAQ)
				if(sealTestOn)
					dfref sealDF=SealTestDF()
					nvar /sdfr=sealDF zap,freq
					if(zap)
						ControlInfo /W=SealTestWin $("ZapDuration_0"); Variable zapDuration=V_Value
						svar /sdfr=sealDF channels
						variable numSealTestChannels=ItemsInList(channels)
						variable zapPoints=zapDuration*freq*SealTestPoints(DAQ)*numSealTestChannels/1000
						variable zapChannel=round(log(zap)/log(2))
						if(zap>0)
							out[zapChannel,zapPoints-1;numSealTestChannels]+=32000
							zap*=-1
						elseif(zap<0)
							out[zapChannel,zapPoints-1;numSealTestChannels]-=32000
							zap=0
						endif
					endif
				endif
				if(numpnts(out))
					Stim(DAQ)
				endif
			endif
		endif
	elseif(dynamic || (!continuous && !sealtestOn))
		nvar /sdfr=df ISI,period,reassemble
		variable currTime=StopMSTimer(-2)
		variable interval=(currTime-lastDAQSweepT)/1000000
		if(interval>ISI || sealtestOn)
			if(dynamic && !sealtestOn)
				if(reassemble)
					SetupDynamicClamp(DAQ)
				endif
				lastDAQSweepT=StopMSTimer(-2)
				ExecuteDynamicClamp(DAQ)
			else
				svar /sdfr=df inputWaves
				variable numInputs=max(1,ItemsInList(inputWaves))
				variable bits=2//+(strlen(ListMatch(DAQs,"NIDAQmx"))>0) // Set the the first bit if the NIDAQmx is present, so it can control the start time of the sweep.  
				lastDAQSweepT=StopMSTimer(-2)
				Start(period/numInputs,bits)
			endif
		endif
	endif
	KillWaves /Z Garbage//,FifoInSize,FifoOutSize
	return 0
End

static Function ReadAvailable(DAQ)
	string DAQ
	
	dfref df=GetDAQDF(DAQ)
	Make /o/n=1/I df:FifoInSize /wave=FifoInSize
	Execute /Q "ITC18ReadAvailable "+getwavesdatafolder(FifoInSize,2)
	return FifoInSize[0]
End

static Function WriteAvailable(DAQ)
	string DAQ
	
	dfref df=GetDAQDF(DAQ)
	Make /o/n=1/I df:FifoOutSize /WAVE=FifoOutSize
	Execute /Q "ITC18WriteAvailable "+getwavesdatafolder(FifoOutSize,2)
	return FifoOutSize[0]
End

static Function Samp(DAQ[,in,append_])
	string DAQ
	wave in
	variable append_
	
	if(paramisdefault(in))
		wave /sdfr=GetDaqDF(DAQ) in=InputMultiplex
	endif
	string cmd
	sprintf cmd,"ITC18Samp%s %s",selectstring(append_,"","Append"),getwavesdatafolder(in,2)
	Execute /Q cmd
End

static Function Stim(DAQ[,out,append_])
	string DAQ
	wave out
	variable append_
	
	if(paramisdefault(out))
		wave /sdfr=GetDaqDF(DAQ) out=OutputMultiplex
	endif
	string cmd
	sprintf cmd,"ITC18Stim%s %s",selectstring(append_,"","Append"),getwavesdatafolder(out,2)
	Execute /Q cmd 
End

static Function DynamicClampTest([vE,vI])
	variable vE,vI // Reversal potentials in mV  
	
	vE=paramisdefault(vE) ? 0.1 : vE
	vI=paramisdefault(vI) ? -0.05 : vI
	
	vE/=1000 // Convert from mV to V.  
	vI/=1000 // Convert from mV to V.  
	
	string DAQ=MasterDAQ(type=type)
	dfref daqDF=GetDaqDF(DAQ)
	newdatafolder /o daqDF:DynamicClamp
	dfref df=daqDF:DynamicClamp
	
	variable chan=ADC2Chan("0")
	if(chan != DAC2Chan("0")) // Dynamic clamp only works on ADC=0 and DAC=0.  	
		DoAlert 0,"Dynamic clamp only works when the same Igor channel reads from DAC0 and writes to ADC0."
		return -1
	endif
	
	variable inputGain=GetInputGain(chan,inf)
	variable outputGain=GetOutputGain(chan,inf)
	
	nvar /sdfr=daqDF duration
	variable kHz=50
	variable points=round(duration*kHz*1000) 
	make /o/n=(points) df:forcingWave /wave=forcingWave,df:eWave /wave=eWave, df:iWave /wave=iWave
	make /o/n=(points*4) df:inWave /wave=inWave
	setscale x,0,duration,forcingWave,eWave,iWave
	setscale x,0,duration*4,inWave
	
	setoutputwaves()
	nvar /sdfr=daqDF boardGain
	wave /sdfr=daqDF raw_0,input_0
	forcingWave=raw_0(x)/1e9 // Convert pA to A.  
	eWave=(x>0.6 && x<0.7) ? 1e-6 : 0 // in uA/mV.  
	iWave=(x>0.8) ? 0.001*(x-0.8)*exp(-(x-0.8)/0.003) : 0 // in uA/mV
	
	variable forcingGain=1
	variable eGain=1
	variable iGain=1
	
	// I(t) = sum(uA/mV * V) = mA
	// inputGain = mV / mV = V / V
	// outputGain = pA / mV = nA / V
	// outputGain/1e6 = mA / V  
	
	Execute /Q "ITC18LoadDynamicClampMode"
	string cmd
	sprintf cmd,"ITC18RunDynamicClamp NIL, NIL, NIL, forcingWave, eWave, iWave, inWave, 4, 2, 0, 10, %f, %f, %f, %f, %f, %f, %f",inputGain,outputGain/1e6,vE,vI,forcingGain,eGain,iGain
	Execute /Q cmd
	redimension /n=(points) input_0
	setscale x,0,duration,input_0
	input_0=inWave[p*4+2]/(boardGain*inputGain*10.24) // I don't know why this 10 needs to be here, but for now it's the way to get the right value.  
	smooth 1000,input_0
	Execute /Q "ITC18Reset"	// reset ITC-18 to normal mode
End

// Loads dynamic clamp mode on the ITC.  Cleared by UnloadDynamicClampMode().  
static Function LoadDynamicClampMode([DAQ])
	string DAQ
	
	Execute /Q "ITC18LoadDynamicClampMode"
End

// Goes back to normal mode on the ITC.  
static Function UnloadDynamicClampMode([DAQ])
	string DAQ
	
	BoardReset(1)
End

// Setup the stimulation/acquisition waves for use in dynamic clamp mode.  
static Function SetupDynamicClamp(DAQ)
	string DAQ
	
	variable chan_=ADC2Chan("0")
	if(chan_ != DAC2Chan("0")) // Dynamic clamp only works on ADC=0 and DAC=0.  	
		DoAlert 0,"Dynamic clamp only works when the same Igor channel reads from DAC0 and writes to ADC0."
		return -1
	endif
	
	string mode=GetAcqMode(chan_)
	dfref df=Core#InstanceHome(module,"acqModes",mode)
	variable duration=GetAcqDuration()
	variable kHz=GetAcqFreq()
	variable /g df:points=round(duration*kHz*1000) 
	
	nvar /sdfr=df vE,vI,points // Reversal potentials in mV and # of acquisition points.    
	variable /g df:chan=chan_
	variable inputGain=GetInputGain(chan_,inf)
	variable outputGain=GetOutputGain(chan_,inf)
	
	dfref daqDF=GetDaqDF(DAQ)
	make /o/n=(points) daqDF:forcingWave /wave=forcingWave,daqDF:eWave /wave=eWave,daqDF:iWave /wave=iWave
	make /o/n=(points*4) daqDF:InputMultiplex /wave=InputMultiplex
	setscale x,0,duration,forcingWave,eWave,iWave
	setscale x,0,duration*4,InputMultiplex
	
	setoutputwaves()
	variable /g df:forcingGain=1
	variable /g df:eGain=1
	variable /g df:iGain=1
	
	// Assemble dynamic clamp channel.  
	Assemble(chan_,forcingWave,triparity=0)
	Assemble(chan_,eWave,triparity=1)
	Assemble(chan_,iWave,triparity=2)
	string outputUnits=GetOutputUnits(chan_)
	variable conversion=ConversionFactor(outputUnits,"S")
	forcingWave*=conversion // nA to A (somehow actually pA to A).  
	conversion=ConversionFactor(outputUnits,"mS")
	eWave*=conversion // nS to mS
	iWave*=conversion // nS to mS
	
	// Assemble other channels.  
	string channels="1;2;D"
	variable i
	for(i=0;i<itemsinlist(channels);i+=1)
		string channel=stringfromlist(i,channels)
		chan_ =DAC2Chan(channel) 
		if(numtype(chan_))
			continue
		endif
		wave /sdfr=daqDF Raw=$("Raw_"+num2str(chan_))
		Assemble(chan_,Raw)
		duplicate /o Raw,daqDF:$("Stimulus_"+num2str(chan_)) /wave=Stim
		if(!stringmatch(channel,"D")) // If it is an analog output channel.  
			conversion=ConversionFactor(outputUnits,"S") // Same conversion as for forcing wave above.  Therefore other outputs must be in the same units as the forcing wave.    
			Stim*=conversion
		endif	
	endfor
	
	//Execute /Q "ITC18LoadDynamicClampMode"
End

// Execute a dynamic clamp stimulation/acquisition, followed by demultiplexing of the collected data, and execution of a listen hook (e.g. CollectSweep()).  
static Function ExecuteDynamicClamp(DAQ)
	string DAQ
	// Build stimulus from parameters.  
	//forcingWave=raw_0(x)/1e9 // Convert pA to A.  
	//eWave=(x>0.6 && x<0.7) ? 1e-6 : 0 // in uA/mV (mS).  
	//iWave=(x>0.8) ? 0.001*(x-0.8)*exp(-(x-0.8)/0.003) : 0 // in uA/mV (mS).  
	
	string listenHook=GetListenHook(DAQ)
	variable chan=ADC2Chan("0")
	string mode=GetAcqMode(chan)
	dfref df=Core#InstanceHome(module,"acqModes",mode)
	nvar /sdfr=df vE,vI,forcingGain,eGain,iGain
	variable inputGain=GetInputGain(chan,inf)
	variable outputGain=GetOutputGain(chan,inf)
	dfref daqDF=GetDaqDF(DAQ)
	nvar /sdfr=itc lastDAQSweepT

	variable currSweep=GetCurrSweep()
	wave divisor=GetDAQDivisor(DAQ)
	variable lcm_=LCM(divisor)
	lcm_=numtype(lcm_) ? 1 : lcm_
	variable column=mod(currSweep,divisor)
	duplicate /o/r=()(column,column) daqDF:forcingWave daqDF:forcingWaveNow /wave=forcingWaveNow
	duplicate /o/r=()(column,column) daqDF:eWave daqDF:eWaveNow /wave=eWaveNow
	duplicate /o/r=()(column,column) daqDF:iWave daqDF:iWaveNow /wave=iWaveNow
	redimension /n=(dimsize(forcingWaveNow,0)) forcingWaveNow,eWaveNow,iWaveNow
	
	string forcingWave=getwavesdatafolder(forcingWaveNow,2)
	string eWave=getwavesdatafolder(eWaveNow,2)
	string iWave=getwavesdatafolder(iWaveNow,2)
	string inWave=getwavesdatafolder(daqDF:InputMultiplex,2)
	variable out1=DAC2Chan("1")
	variable out2=DAC2Chan("2")
	variable outD=DAC2Chan("D")
	if(numtype(out1))
		string outWave1="NIL"
	else
		wave stim=daqDF:$("Stimulus_"+num2str(out1))
		outWave1=getwavesdatafolder(stim,2)
	endif
	if(numtype(out2))
		string outWave2="NIL"
	else
		wave stim=daqDF:$("Stimulus_"+num2str(out2))
		outWave2=getwavesdatafolder(stim,2)
	endif
	if(numtype(outD) || (!stringmatch(outWave1,"NIL") && !stringmatch(outWave2,"NIL"))) // If there is no diigital output channel or if the both analog outputs are set.  
		string outWaveD="NIL"
	else
		wave stim=daqDF:$("Stimulus_"+num2str(outD))
		outWaveD=getwavesdatafolder(stim,2)
	endif
	
	string cmd
	sprintf cmd,"ITC18RunDynamicClamp %s,%s,%s,%s,%s,%s, %s, 4, 2, 0, 10, %f, %f, %f, %f, %f, %f, %f",outWave1,outWave2,outWaveD,forcingWave,eWave,iWave,inWave,inputGain,outputGain/1e6,vE/1000,vI/1000,forcingGain,eGain,iGain
	Execute /Q cmd
	DemultiplexDynamicClamp(DAQ)
	Execute /Q listenHook
End

// Demultiplex the 4 channels collected in dynamic clamp mode.  
Function DemultiplexDynamicClamp(DAQ)
	string DAQ
	
	variable chan=ADC2Chan("0")
	string mode=GetAcqMode(chan)
	dfref df=Core#InstanceHome(module,"acqModes",mode)
	make /free/n=4 chans=ADC2Chan(num2str(p))
	dfref daqDF=GetDaqDF(DAQ)
	wave /sdfr=daqDF InputMultiplex
	variable boardGain=GetBoardGain()
	variable duration=GetAcqDuration()
	nvar /sdfr=df points
	variable i
	for(i=0;i<4;i+=1)
		chan=chans[i]
		if(numtype(chan))
			continue
		endif
		wave input=daqDF:$("input_"+num2str(chan))
		redimension /n=(points) input
		setscale x,0,duration,input
		variable inputGain=GetInputGain(chan,inf)
		input=InputMultiplex[p*4+mod(i+2,4)]/(boardGain*inputGain*(chan==0 ? inputGain : 1)) // I don't know why this extra inputGain needs to be here, but it is needed to get the right value on the dynamic clamp channel.  
	endfor
	//smooth 1000,input_0
End

static Function SamplesWritten(DAQ)
	string DAQ
	
	return 2^20-WriteAvailable(DAQ)
End

static Function /S Sequence(DAQ)
	String DAQ
	
	Wave /T InputMap=GetInputMap()
	Wave /T OutputMap=GetOutputMap()
	Wave ActiveChannels=GetActiveChannels()
	String DAC="",ADC=""
	variable i,numChannels=GetNumChannels()
	variable sealTestOn=IsSealTestOn()
		
	if(sealTestOn)
		dfref sealDF=SealTestDF()
		nvar /sdfr=sealDF chanBits
		for(i=0;i<numChannels;i+=1)
			if(!StringMatch(Chan2DAQ(i),DAQ))
				continue
			endif
			if(sealTestOn && (chanBits & 2^i))
				ADC+=InputMap[i]
				DAC+=OutputMap[i]
				nvar /sdfr=sealDF pressureOn
				if(pressureOn)
					ADC+=num2str(str2num(InputMap[i])+4) // Assume input for pressure signal is 4 slots over from input for electrode signal.  
					DAC+="N"
				endif
			endif
		endfor
	else
		for(i=0;i<numChannels;i+=1)
			if(!ActiveChannels[i] || !StringMatch(Chan2DAQ(i),DAQ))
				continue
			endif
			ADC+=InputMap[i]
			DAC+=OutputMap[i]
		endfor
	endif
	if(!strlen(DAC) || !strlen(ADC))
		printf "ITC Sequencing failed for DAQ '%s'.\r",DAQ
		return ""	
	endif
	DAC=ReplaceRepetitionsWithN(DAC) // Guard against overwriting acquisition on one channel by replacing the second instance of an input channel with "N".  
	ADC=ReplaceRepetitionsWithN(ADC)
	String command="ITC18Seq \"" +DAC+ "\","+ "\"" +ADC+"\""
#ifdef Rick2 // Use ITC18WriteSequence for finer control.  Must do this to enable Trig Out on BNC front panel.  
		make/free/I/n=(strlen(DAC)) SeqTemp=2^14+2^15 + (p==0) // Always update input and output on every tick, and update bit 0 on the first tick.  
		for(i=0;i<strlen(DAC);i+=1)
			//SeqTemp[i] +=2^6 // 1 is the bit that indicates that updating is occurring.  
			String val=DAC[i]
			if(StringMatch(val,"N"))
				SeqTemp[i]+=2^11+2^12+2^13
			elseif(StringMatch(val,"D"))
				SeqTemp[i]+=2^11+2^13
			elseif(StringMatch(val,"T"))
				SeqTemp[i]+=2^13
			else 
				SeqTemp[i]+=2^11*str2num(val)
			endif
		endfor
		for(i=0;i<strlen(ADC);i+=1)
			val=ADC[i]
			if(StringMatch(val,"N"))
				SeqTemp[i]+=2^7+2^8+2^9+2^10
			elseif(StringMatch(val,"D"))
				SeqTemp[i]+=2^10
			else 
				SeqTemp[i]+=2^7*str2num(val)
			endif
		endfor
		//SeqTemp[0] = 2^14+2^15
		//SeqTemp[1] = 2^7+2^14+2^15
		//seq[2] = 2^7 + 2^11 
		//seq[3] = 1 | 2^11 | 2^10
		command="ITC18WriteSequence SeqTemp"
#endif
	Execute /Q command
	return command
End

static Function /S ReplaceRepetitionsWithN(str[,DAQ])
	String str,DAQ
	
	Variable i
	String used=""
	for(i=0;i<strlen(str);i+=1)
		String char=str[i]
		if(WhichListItem(char,used)>=0 && !StringMatch(char,"N"))
			str[i,i]="N"
		else
			used+=char+";"
		endif
	endfor
	return str
End

static Function Read(channel[,DAQ])
	Variable channel
	String DAQ
	
	Make /o/n=1 TempRead
	Execute /Q "ITC18ReadADC "+num2str(channel)+",TempRead"
	Variable value=TempRead[0]
	KillWaves /Z TempRead
	return value
	//return fDAQmx_ReadChan("dev1",channel,-10,10,-1)
End

static Function Write(chan,value[,DAQ])
	variable chan,value
	String DAQ
	
	string cmd
	sprintf cmd,"ITC18SetDAC %d,%f",chan,value
	Execute /Q cmd 
End

static Function StartClock(isi[,DAQ])
	Variable isi
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	//SetBackground SpeakAndListen()
	//CtrlBackground period=1, dialogsOK=0, start
	string bkgName=DAQ
	CtrlNamedBackground $bkgName, period=1, burst=1, proc=ITC#SpeakAndListenBkg//, start
	dfref statusDF=GetStatusDF()
	Variable /g statusDF:first=1
	dfref df=GetDaqDF(DAQ)
	nvar /sdfr=df period
	variable sealtestOn=IsSealTestOn()
	variable i
	// Consider only ITC inputs.  
	sVar /sdfr=df inputWaves,outputWaves
	variable numInputs=max(1,ItemsInList(inputWaves))
	
	string outputName=stringfromlist(0,outputWaves)
	wave /z output=$stringfromlist(0,outputName,",")
	if(sealTestOn && waveexists(output))
		period=GetPeriod(DAQ,w=output)
	else
		period=GetPeriod(DAQ)
	endif
	String out=joinpath({getdatafolder(1,df),"OutputMultiplex"})
	
	//NVar inPoints=root:status:inPoints
	//inPoints=0
	//Execute /Q "ITC18Reset"
	
	String seq=Sequence(DAQ)
	nvar /sdfr=df continuous
	
	variable dynamic=InDynamicClamp() && !sealTestOn
	if(!dynamic && numpnts($out))
		Stim(DAQ)
		if(continuous || sealTestOn)
			variable currSweep=GetCurrSweep()
			if(!sealTestOn)
				SetOutputWaves(sweepNum=currSweep+1,DAQ=DAQ)
			endif
			Speak(1,outputWaves,32,DAQ=DAQ) // Update the stimulus for the next sweep.  
			Stim(DAQ,append_=1) // Need to pad the buffer with an extra stimulus wave so we never stop the stimulus waves.   
			if(sealTestOn) // Pad even more if it is a sealtest.  
				for(i=0;i<3;i+=1)
					Stim(DAQ,append_=1)
				endfor
			endif
		endif
	endif
	CtrlNamedBackground $bkgName,start
	Variable bits=2//+(strlen(ListMatch(DAQs,"NIDAQmx"))>0) // Set the the first bit if the NIDAQmx is present, so it can control the start time of the sweep.  
	String command
	nvar /sdfr=df lastDAQSweepT
	sprintf command,"ITC18StartAcq %d,%d,0",period/numInputs,bits
	lastDAQSweepT=StopMSTimer(-2)
	if(dynamic)
		SetupDynamicClamp(DAQ)
		ExecuteDynamicClamp(DAQ)
	else
		Execute /Q command
	endif
End

static Function SpeakAndListenBkg(s)
	Struct WMBackgroundStruct &s
	
	SpeakAndListen(DAQ=s.name)
	return 0
End

static Function StopClock([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	string bkgName=DAQ
	CtrlNamedBackground $bkgName, period=1, stop
	Execute /Q "ITC18StopAcq"
End

// This static Function is called when a scanning or waveform generation error is encountered.  
static Function ErrorHook([DAQ])
	String DAQ
	printf "Error Sweep.\r"
End

static Function SlaveHook(DAQ)
	String DAQ
End

// For testing digital outputs.  
function ToggleDigitalLoop(bitCode[,interval])
	variable bitCode
	variable interval // Interval in seconds.  
	
	interval=paramisdefault(interval) ? 2 : interval
	interval*=60 // Convert to ticks.  
	CtrlNamedBackground DigitalLoop, status
	variable running=numberbykey("RUN",s_info)
	if(running)
		CtrlNamedBackground DigitalLoop, stop
	else
		variable /g $"bitCode"=bitCode
		variable /g state=0
		Execute /Q "ITC18WriteDigital1 0"
		CtrlNamedBackground DigitalLoop, proc=DigitalLoopBkg, start, period=interval
	endif
end

function DigitalLoopBkg(s)
	struct WMBackgroundStruct &s
	
	variable bitCode=numvarordefault("bitCode",0)
	variable state=numvarordefault("state",0)
	variable /g $"state"=bitCode-state
	print ticks,state
	Execute /Q "ITC18WriteDigital1 "+num2str(state)
	return 0
end

static function WriteDigital(line,value[,DAQ])
	string line
	variable value
	string DAQ
	
	string cmd
	sprintf cmd,"ITC18WriteDigital%s %d",line,value
	Execute /Q cmd
end