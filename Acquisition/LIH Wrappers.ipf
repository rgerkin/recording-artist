
// $Author: rick $
// $Rev: 517 $
// $Date: 2011-02-23 00:19:11 -0500 (Wed, 23 Feb 2011) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=LIH
static strconstant module="Acq"
static strconstant type=LIH

static function /s DAQType(DAQ[,quiet])
	string DAQ
	variable quiet
	
	return "LIH"
end


static function /s InputChannelList([DAQ])
	string DAQ
	
	return "0;1;2;3;4;5;6;7;D;N;"
end

static function /s OutputChannelList([DAQ])
	string DAQ
	
	return "0;1;2;3;D;N;"
end
constant LIH_kHz=10

Structure ChannelsParam
    int16 channels[17]
EndStructure

static Function BoardGain(DAQ)
	String DAQ
	
	return 3.2
End

static Function SpeakReset([DAQ])
	String DAQ
	
	//printf "SpeakReset() is not available for this device.\r"
End

static Function SetupTriggers(pin[,DAQ])
	Variable pin
	String DAQ

	//printf "SetupTriggers() is not available for this device.\r"
End

static Function ZeroAll([DAQ])
	String DAQ
	
	LIH_Halt()
	WriteDig(0)
	
	Variable i
	for(i=0;i<4;i+=1)
		Variable volts=0
		if(WinType("SuperClampWin")) // If Super Clamp Commodore is open.  
			variable chan=DAC2Chan(num2str(i))
			if(chan>=0 && StringMatch(Chan2DAQ(chan),DAQ)) // If it is there and it is a channel belonging to this DAQ.  
				volts=0.001*SuperClampCheck(chan)/GetOutputGain(chan,Inf) // Set the offset to the current super clamp value.  
			endif
		endif
		Write(i,volts)
	endfor
	//BoardReset() // Takes a while, but may be important to clear the buffers.  
End

static Function BoardReset(Device[,DAQ])
	Variable device
	String DAQ
	
	LIH_InitInterface(device)
End

static Function BoardInit([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	BoardReset(1,DAQ=DAQ)
	ZeroAll(DAQ=DAQ)
	GetDaqDF(DAQ) // Create the DAQ data folder.  
End

static Function BoardStatus([DAQ])
	String DAQ
	
	return LIH_Status()
End

static Function /S DAQError([DAQ])
	String DAQ
	
	return "There appears to be no error checking provided by the LIH18 XOP."  
End

static Function DefaultKHz(DAQ)
	String DAQ
	
	dfref df=ObjectManifest(module,"DAQs","kHz")
	nvar /sdfr=df value
	return value
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
	nvar /sdfr=df boardGain,kHz
	Make /o/d/n=0 df:OutputMultiplex /WAVE=OutputMultiplex
	
	variable i,chan,length=0,numRealOutputs=0; string usedSlots="",map=""
	for(i=0;i<numOutputs;i+=1)
		wave /Z OutputWave=ParseWavesInfo(outputWaves,i,map,chan)
		if(!waveexists(OutputWave))
			continue
		endif
		numRealOutputs+=1
		redimension /n=(numpnts(OutputWave),numRealOutputs) OutputMultiplex
		duplicate /free OutputWave OutputWave1D
		redimension /n=(numpnts(OutputWave)) OutputWave1D
		variable usedSlot=WhichListItem(map,usedSlots)
		if(usedSlot>=0)// && !StringMatch(OutputMap[chan],"D")) // If this output channel was already used (not counting D, which can be used by multiple channels).  
			Variable slot=usedSlot // Add these output values to the multiplex slot originally used for that channel.  
		else
			slot=ItemsInList(usedSlots) // Use a new slot.  
			usedSlots+=Chan2ADC(chan)+";" // Add this to the list of used slots.  
		endif
		
		strswitch(Chan2ADC(chan))
			case "D": // Digital Output
				OutputMultiplex[][slot]+=round((OutputWave1D[p] >= 2^15 || OutputWave1D[p] < 0) ? 0 : OutputWave1D[p])  // Values below 0 or above 255 will be set to 0.  
				break
			case "N": // Null output.  Should have been skipped.  
				break
			default:
				variable superClampOffset=SuperClampCheck(chan)/GetOutputGain(chan,Inf)
				OutputMultiplex[][slot]+=(OutputWave1D[p]+superClampOffset)*boardGain
				break
		endswitch
	endfor
	SetScale /P x,0,0.001/kHz,OutputMultiplex
End

static Function InDemultiplex(inputWaves[,DAQ])
	String inputWaves
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	dfref df=GetDaqDF(DAQ)
	wave /sdfr=df InputMultiplex
	variable numInputs=ItemsInList(inputWaves)
	nvar /sdfr=df boardGain,inPoints,realTime
	InputMultiplex/=boardGain
	variable size=dimsize(InputMultiplex,0)
	variable range=numpnts(InputMultiplex)/numInputs
	variable start=inPoints/numInputs
	variable finish=start+range-1
	variable i,sealTest=IsSealTestOn()
	string map=""
	variable chan,numRealInputs=0
	for(i=0;i<numInputs;i+=1)
		wave /Z InputWave=ParseWavesInfo(inputWaves,i,map,chan)
		if(!waveexists(InputWave))
			continue
		endif
		if(sealtest)
			string chanName=getwavesdatafolder(InputWave,0)
			chan=GetChannelNum(chanName)
			string channel=num2str(chan)
		else
			string input_wave=stringfromlist(i,inputWaves)
			channel=StringFromList(1,input_wave,",") // A channel number, e.g. "0", "1", etc.  
			chan=str2num(channel)
		endif
		if(!realTime) // If not real time, use the clone instead so that filtered pieces of the last sweep are not overwritten by unfiltered pieces of the current sweep.  
			string cloneName=GetWavesDataFolder(InputWave,2)+"_buff"
			wave /z Clone=$cloneName
			if(!waveexists(Clone))
				duplicate /o InputWave $cloneName /wave=Clone
			endif
			wave InputWave=Clone
		endif
		numRealInputs+=1
		// Adjust for gain and A/D conversion (non-MX board)
		ControlInfo /W=$(DAQ+"_Selector") $("Mode_"+channel)
		variable mode_num=V_Value-1
		string mode=S_Value
		if(StringMatch(nameofwave(InputWave),"*PressureSweep*")) // Seal test pressure will be acquired in unity mode.  
			mode="Unity"
			variable inputGain=1000
		else
			inputGain=GetInputGain(chan,Inf)
		endif
		variable superClampOffset=SuperClampOffsetCheck(chan)
		InputWave[start,finish]=InputMultiplex[p-start][numRealInputs-1]/inputGain// + superClampOffset
	endfor
	inPoints+=size
End

static Function MakeInputMultiplex(inputWaves[,DAQ])
	String inputWaves
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	dfref df=GetDaqDF(DAQ)
	nvar /sdfr=df realTime,kHz
	variable sealtest=IsSealTestOn()
	Variable i,numInputs=ItemsInList(inputWaves)
	variable chan,numRealInputs=0; string map=""
	for(i=0;i<numInputs;i+=1)
		wave /Z InputWave=ParseWavesInfo(inputWaves,i,map,chan)
		if(!waveexists(InputWave))
			continue
		endif
		if(!sealTest)
			variable points=min(realTimeSize,numpnts(InputWave)) // Make a small InputMultiplex wave to regularly pull samples from the device.  
		else
			points=numpnts(InputWave)
		endif
		numRealInputs+=1
		Variable /G df:acqPoints=numpnts(InputWave)*numRealInputs
	endfor
	if(points==0)
		points=realTimeSize
	endif
	Make /o/d/n=(points,numRealInputs) df:InputMultiplex /wave=InputMultiplex
	SetScale /P x,0,0.001/kHz,InputMultiplex
End

static Function /wave ParseWavesInfo(waves,i,map,chan)
	string waves,&map
	variable i,&chan
	
	string info=StringFromList(i,waves)
	string name=StringFromList(0,info,",")
	if(strlen(name))
		string channel=StringFromList(1,name,"_")
		chan=str2num(channel)
		if(stringmatch(name,"*input*"))
			string direction="input"
		elseif(stringmatch(name,"*sweep*"))
			direction="input"
		elseif(stringmatch(name,"*stim*"))
			direction="output"
		elseif(stringmatch(name,"*pulse*"))
			direction="output"
		else
			direction="null"
		endif
		strswitch(direction)
			case "input":
				map=Chan2ADC(chan)
				break
			case "output":
				map=Chan2DAC(chan)
				break
			default:
				map="N"
		endswitch
	else
		chan=NaN
		map="N" // No output wave specified, so assume null output.  
	endif
	wave /z w=$name
	return w	
End

static Function Speak(device,list,param[,now,DAQ])
	Variable device
	String list
	Variable param // 0 is continuous, 32 is only one time
	Variable now // Don't wait for SpeakAndListen, just start output now.  
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	OutMultiplex(list,DAQ=DAQ)
	//printf "Speak() is not available for this device.\r"		
End

static Function Listen(device,gain,list,param,continuous,endHook,errorHook,other[,now,DAQ])
	Variable device,gain
	String list
	Variable param,continuous
	String endHook,errorHook,other
	Variable now
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	MakeInputMultiplex(list,DAQ=DAQ)
	//printf "Listen() is not available for this device.\r"		
End

static Function SpeakAndListen([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	dfref df=GetDaqDF(DAQ)
	dfref statusDF=GetStatusDF()
	nvar /sdfr=df inPoints,outPoints,acqPoints,duration,continuous,realTime,lastDAQSweepT,kHz,ISI
	variable sealTest=IsSealTestOn()
	variable dynamic=InDynamicClamp() && !sealtest
	if(!dynamic)
		variable FifoInSize=SamplesAvailable2Read(DAQ)
		//variable FifoOutSize=SamplesAvailable2Write(DAQ)
	endif
	
	struct ChannelsParam DAC
	struct ChannelsParam ADC
	wave in=df:InputMultiplex, out=df:OutputMultiplex
	variable buffer=dimsize(in,0)
	
	if(FifoInSize>2^14)
		printf "Too many points in the input buffer!\r"
		abort
	endif
	if(FifoInSize>buffer+10) // Over the buffer limit.  
		svar /sdfr=df inputWaves,outputWaves
		string listenHook=GetListenHook(DAQ)
		nvar /sdfr=statusDF first,currSweep
		funcref CollectSweep f=$listenHook
		if(sealTest && FifoInSize>2*buffer) // Way too many points have accumulated.  .  
			SealTestStart(1,DAQ) // So just start over.  
			return 0
		endif
		ReadStimAndSample(in, 0, buffer)
		if(!sealTest)
			InDemultiplex(inputWaves)
			DoUpdate
		else
			dfref sealDF=SealTestDF()
			nvar /sdfr=sealDF zap
			if(zap)
				SealTestZap(out,DAQ)
			endif
		endif
		if(continuous || sealtest || outPoints<acqPoints)
			WriteStimAndSample(out,0,buffer)
		endif
		if(sealTest || inPoints>=acqPoints)
			inPoints=0
			outPoints=0
			if(!sealTest && !continuous)
				LIH_Halt()
				//Sequence(DAC,ADC) // Sequence the next sweep in advance.  
			endif
			f(DAQ) // Hook function to run after data is collected.  
			if(continuous)
				lastDAQSweepT+=duration*1000000
			endif
		endif
	elseif(!continuous && !sealtest) // Non-continuous and not over the buffer limit.  
		Variable currTime=StopMSTimer(-2)
		Variable interval=(currTime-lastDAQSweepT)/1000000
		if(interval>ISI || sealtest) // Time for a new sweep.  
			OneStimAndSample(out,in,DAQ=DAQ)
		endif
	endif
	return 0
End

static Function OneStimAndSample(out,in[,DAQ])
	wave /d out,in
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	dfref df=GetDaqDF(DAQ)
	nvar /sdfr=df lastDAQSweepT,kHz,outPoints
	lastDAQSweepT=StopMSTimer(-2)
	variable bits=1//+8*(strlen(ListMatch(DAQs,"NIDAQmx"))>0) // Set the the third bit if the NIDAQmx is present, so it can control the start time of the sweep.  
	variable inSize=dimsize(in,0)
	variable outSize=2*inSize
	struct ChannelsParam DAC
	struct ChannelsParam ADC
	Sequence(DAC,ADC)
	variable samplingInterval=0.001/kHz
	
	// If the Output Multiplex wave is not long enough, pad it with repeats of itself.  
	variable outLength=dimsize(out,0)
	if(outLength<outSize)	
		redimension /n=(outSize,-1) out
		out=out[mod(p,outLength)][q]
	endif
	
	LIH_StartStimAndSample(out,in,outSize,inSize,DAC,ADC,samplingInterval,bits)
	matrixop /o out=rotaterows(out,-outSize)
	redimension /n=(-1,max(1,dimsize(out,1))) out // Needed because rotaterows squeezes out singleton column.  
	outPoints+=outSize
End

static Function ReadStimAndSample(in,stop,size)
	wave /d in
	variable stop,size
	
	LIH_ReadStimAndSample(in,stop,size)
End

static Function WriteStimAndSample(out,last,size[,DAQ])
	wave /d out
	variable last,size
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	dfref df=GetDaqDF(DAQ)
	nvar /sdfr=df outPoints
	LIH_AppendToFIFO(out,last,size)
	matrixop /o out=rotaterows(out,-size)
	redimension /n=(-1,max(1,dimsize(out,1))) out // Needed because rotaterows squeezes out singleton column.  
	outPoints+=size
	//if(outPoints>2*dimsize(out,0)) // rotaterows will perform modular arithmetic, but keep outPoints reasonable anyway.  
	//	outPoints=mod(outPoints,dimsize(out,0))
	//endif
End

static Function SamplesAvailable2Read(DAQ)
	string DAQ
	
	variable stillRunning
	variable samples=LIH_AvailableStimAndSample(stillRunning)
	return samples
End

static Function /S Sequence(DAC,ADC[,DAQ])
	struct ChannelsParam &DAC
	struct ChannelsParam &ADC
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	dfref df=GetDaqDF(DAQ)
	Wave /T InputMap=GetInputMap()
	Wave /T OutputMap=GetOutputMap()
	variable channels=GetNumChannels()
	variable sealTest=IsSealTestOn()
	
	Variable i,adcNum=0,dacNum=0
	for(i=0;i<channels;i+=1)
		if(!StringMatch(Chan2DAQ(i),DAQ) || (sealTest && !(sealTest & 2^i)) || (!sealTest && !IsChanActive(i)))
			continue
		endif
		if(!stringmatch(InputMap[i],"N"))
			ADC.channels[adcNum]=stringmatch(InputMap[i],"D") ? 16 : str2num(InputMap[i]) // The numeric value of the channel or 16 for digital input.  
			dfref sealDF=SealTestDF()
			nvar /z/sdfr=sealDF pressureOn
			adcNum+=1
			if(sealTest && nvar_exists(pressureOn) && pressureOn)
				// Assume input for pressure signal is 4 slots over from input for electrode signal.  
				// Use the unlikely-to-be used channel 15 to ignore pressure signals on digital channels.  
				ADC.channels[adcNum]=stringmatch(InputMap[i],"D") ? 15 : str2num(InputMap[i])+4
				adcNum+=1
			endif
		endif
		if(!stringmatch(OutputMap[i],"N"))
			DAC.channels[dacNum]=stringmatch(OutputMap[i],"D") ? 16 : str2num(OutputMap[i]) // The numeric value of the channel or 16 for digital ouput.  
			dacNum+=1
		endif
	endfor
	ReplaceRepetitionsWithN(DAC) // Guard against overwriting acquisition on one channel by replacing the second instance of an input channel with "N".  
	ReplaceRepetitionsWithN(ADC)
	string /g df:ADC_, df:DAC_
	svar /z/sdfr=df ADC_,DAC_
	
	//svar ADC_=df:ADC_,DAC_=df:DAC_
	StructPut /S ADC, ADC_
	StructPut /S DAC, DAC_
	
	// Return an easily readable string with the sequence.  
	string result="|"
	for(i=0;i<17;i+=1)
		result+=num2str(ADC.channels[i])+","+num2str(DAC.channels[i])+"|"
	endfor
	return result
End

static Function /S ReplaceRepetitionsWithN(ChannelsParam[,DAQ])
	struct ChannelsParam &ChannelsParam
	String DAQ
	
	variable i,j
	for(i=0;i<17;i+=1)
		variable chan1=ChannelsParam.channels[i]
		for(j=i+1;j<17;j+=1)
			variable chan2=ChannelsParam.channels[j]
			if(chan2==chan1)
				ChannelsParam.channels[j]=15 // An unlikely channel, which probably won't be used.  
			endif
		endfor
	endfor
End

static Function Read(channel[,DAQ])
	Variable channel
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	return LIH_ReadADC(channel)
End

static Function ReadDig([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	return LIH_GetDigital()
End

static Function Write(channel,value[,DAQ])
	Variable channel,value
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	LIH_SetDac(channel,value)
End

static Function WriteDig(value[,DAQ])
	variable value
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	LIH_SetDigital(value)
End

static Function StartClock(isi[,DAQ])
	Variable isi
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	LIH_InitInterface(1)
	dfref df=GetDaqDF(DAQ)
	CtrlNamedBackground Acquisition, period=1, burst=1, proc=LIH#SpeakAndListenBkg//, start
	dfref statusDF=GetStatusDF()
	variable /g statusDF:first=1
	
	variable i,numInputs=0
	nvar /sdfr=df kHz,continuous
	
	// Consider only LIH inputs and outputs.  
	svar /sdfr=df inputWaves,outputWaves
	numInputs=max(1,ItemsInList(inputWaves))
	
	wave /d/sdfr=df in=InputMultiplex, out=OutputMultiplex
	CtrlNamedBackground Acquisition, start
	OneStimAndSample(out,in)
End

static Function SpeakAndListenBkg(s)
	Struct WMBackgroundStruct &s
	
	SpeakAndListen(DAQ=MasterDAQ(type=type))
	return 0
End

static Function StopClock([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	CtrlNamedBackground Acquisition, stop
	LIH_Halt()
End

static Function Version([DAQ])
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	return LIH_GetDllVersion()
end

static Function /s Info([DAQ])
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	variable V_SecPerTick,MinSamplingTime,MaxSamplingTime,FIFOLength,NumberOfDacs,NumberOfAdcs
	LIH_GetBoardInfo(V_SecPerTick,MinSamplingTime,MaxSamplingTime,FIFOLength,NumberOfDacs,NumberOfAdcs)
	string str
	sprintf str,"Seconds per Tick: %f\rMinimum Sampling Time: %f\rMaximum Sampling Time: %f\rFIFO Length: %d\r# of DACs: %d\r# of ADCs: %d\r",V_SecPerTick,MinSamplingTime,MaxSamplingTime,FIFOLength,NumberOfDacs,NumberOfAdcs
	return str
end

// This static Function is called when a scanning or waveform generation error is encountered.  
static Function ErrorHook([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=type),DAQ)
	printf "Error Sweep.\r"
End

static Function SlaveHook(DAQ)
	String DAQ
End

