
// $Author: rick $
// $Rev: 632 $
// $Date: 2013-03-15 17:17:39 -0700 (Fri, 15 Mar 2013) $

// Test...

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=NIDAQmx

//override strconstant NIDAQmx_trigIn="PFI0" // If the ITC18 XOP is also present and we want it to control the start times of each sweep.    
//override strconstant NIDAQmxTrigOut="CTR0"

static strconstant pin_prefix = "PFI"

// If we want the NIDAQ device to control the start times of each sweep. 
// Overridden in Acq/DAQs/[name]/startTrigger  

static constant pin_in=4 

// Device timer will send pulses out to this pin.  
static constant pin_out=6 

strconstant DAQType="NIDAQmx"
strconstant module="Acq"

static function /s GetDAQDevices([types])
	string types
	
	return fDAQmx_DeviceNames()
end

static function /s DAQType(DAQ[,quiet])
	string DAQ
	variable quiet
	
	return "NIDAQmx"
end


static function /s DAQ2Device(DAQ) // TO DO: Make DAQ map onto a device number.  
	string DAQ
	
	string devices=GetDAQDevices()
	return stringfromlist(0,devices)
end

static Function BoardGain(DAQ)
	String DAQ
	
	return 3.2
End

static Function /s InputChannelList([DAQ])
	string DAQ
	
	return "0;1;2;3;4;5;6;7;D;N;"
end

static Function /s OutputChannelList([DAQ])
	string DAQ
	
	string device=DAQ2Device(DAQ)
	if(fDAQmx_NumAnalogOutputs(device))
		string list="0;1;2;3;4;5;6;7;D;N;"
	else // No analog outputs.  
		list="D;N;" 
	endif
	return list
end

static Function SpeakReset([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQtype),DAQ)
	if(!paramisdefault(DAQ))
		string deviceName=DAQ2Device(DAQ)
	else
		deviceName="dev1"
	endif
	return fDAQmx_WaveformStop(deviceName)
End

static Function SetupTriggers(pin[,DAQ])
	Variable pin
	String DAQ
End

static Function ZeroAll([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQtype),DAQ)
	string device=DAQ2Device(DAQ)
	fDAQmx_WaveformStop(device)
	fDAQmx_ScanStop(device)
	fDAQmx_WriteChan(device,0,0,-10,10)
	fDAQmx_WriteChan(device,1,0,-10,10)
End

static Function BoardReset(device[,DAQ])
	variable device
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQtype),DAQ)
	if(!paramisdefault(DAQ))
		string deviceName=DAQ2Device(DAQ)
	else
		deviceName="dev1"
	endif
	return fDAQmx_ResetDevice(deviceName)
End

static Function BoardInit([DAQ])
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQtype),DAQ)
	BoardReset(1,DAQ=DAQ)
	ZeroAll(DAQ=DAQ)
End

static Function /S DAQError([DAQ])
	String DAQ
	
	return fDAQmx_ErrorString()
End

// Default sampling frequency in kHz.  
static Function DefaultKHz(DAQ)
	String DAQ
	
	dfref df=Core#ObjectManifest(module,"DAQs","kHz")
	nvar /sdfr=df value
	return value
End

static Function InDemultiplex(inputWaves[,DAQ])
	String inputWaves
	String DAQ
End

static Function Listen(device,gain,list,param,continuous,endHook,errorHook,other[,now,DAQ])
	Variable device,gain
	String list
	Variable param,continuous,now // 'now' is non-functional
	String endHook,errorHook,other,DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=daqType),DAQ)
	// Figure out what the difference is between /BKG=0 and /BKG=1 (right now /BKG=0 doesn't work)
	// Alternatively, set /BKG=0 and /STRT=0 and uncomment the line below it.  
	// Consider using /RPT, which is still sensitive to triggers, for continuous collection
	
	// Exclude channels meant for another device (e.g. the ITC).  
	String newList=""
	Variable i,j
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		String inputMap=StringFromList(1,item,",")
		if(StringMatch(inputMap,"N")) // If it is a null output.  
			// Don't add it to the list.  
		elseif(StringMatch(inputMap,"D")) // If it is a null output.  
			print "Digital output on a NIDAQmx is not yet supported in this code."  
			// TO DO: Handle digital inputs on the NIDAQmx.  
		else
			newList+=item+";"
		endif
	endfor
	list=newList
	if(!strlen(list))
		return -1	
	endif
	
	dfref daqDF=GetDaqDF(DAQ)
	NVar /sdfr=daqDF lastDAQSweepT
	lastDAQSweepT=StopMSTimer(-2)
	if(!paramisdefault(DAQ))
		string deviceName=DAQ2Device(DAQ)
	else
		deviceName="dev1"
	endif
	variable pin = Core#VarPackageSetting("Acq","DAQs","Generic","StartTrigger",default_=pin_in)
	string trig_in
	sprintf trig_in,"/%s/%s%d",deviceName,pin_prefix,pin
	if(continuous)
		DAQmx_Scan /DEV=deviceName /BKG=1 /ERRH=errorHook /RPTC /RPTH=endHook /STRT=1 /TRIG={trig_in,1,1} WAVES=list
	else
		DAQmx_Scan /DEV=deviceName /BKG=1 /ERRH=errorHook /EOSH=endHook /STRT=1 /TRIG={trig_in,1,1} WAVES=list
	endif
	//fDAQmx_ScanStart("dev1",1)
End

static Function Speak(device,list,param[,now,DAQ])
	Variable device
	String list
	Variable param // 0 is continuous, 32 is only one time
	Variable now // 'now' is non-functional
	String DAQ
	
	if(param & 64) // Meant for the ITC18 only.  
		return 0
	endif
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	
	// Exclude channels meant for another device (e.g. the ITC), or channels with 'N' output, since this does not even need to be sent from a NIDAQ board.  
	String newList=""
	Variable i,j
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		String outputMap=StringFromList(1,item,",")
		if(StringMatch(outputMap,"N")) // If it is a null output.  
			// Don't add it to the list.  
		elseif(StringMatch(outputMap,"D")) // If it is a null output.  
			print "Digital output on a NIDAQmx is not yet supported in this code."  
			// TO DO: Handle digital outputs on the NIDAQmx.  
		else
			newList+=item+";"
		endif
	endfor

	list=newList
	if(!strlen(list))
		return -1	
	endif
	
	if(param!=0)
		param=1
	endif
	if(strlen(list)<=ItemsInList(list)) // If there is no information about wave names and channels (probably because no output is being sent).  
		return -1
	endif
	if(!paramisdefault(DAQ))
		string deviceName=DAQ2Device(DAQ)
	else
		deviceName="dev1"
	endif
	variable pin = Core#VarPackageSetting("Acq","DAQs","Generic","StartTrigger",default_=pin_in)
	string trig_in
	sprintf trig_in,"/%s/%s%d",deviceName,pin_prefix,pin
	DAQmx_WaveformGen /DEV=deviceName /ERRH="ErrorHook()" /NPRD=(param) /STRT=1 /TRIG={trig_in,1,1} list
	//DAQmx_WaveformGen /DEV="dev1" /CLK={"/dev1/ai/sampleclock",1} /ERRH="ErrorHook()" /NPRD=1 /STRT=1 /TRIG={"/dev1/"+trigChan,1,1} list
End

static Function Read(channel[,DAQ])
	Variable channel
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	if(!paramisdefault(DAQ))
		string deviceName=DAQ2Device(DAQ)
	else
		deviceName="dev1"
	endif
	return fDAQmx_ReadChan(deviceName,channel,-10,10,-1)
End

static Function Write(channel,value[,DAQ])
	Variable channel,value
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	if(!paramisdefault(DAQ))
		string deviceName=DAQ2Device(DAQ)
	else
		deviceName="dev1"
	endif
	return fDAQmx_WriteChan(deviceName,channel,value,-10,10)
End

static Function StartClock(isi[,DAQ])
	Variable isi
	String DAQ
	 
	if(strlen(fDAQmx_DeviceNames())==0)
		print "No NIDAQmx device attached."
		return -1
	endif
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	if(!paramisdefault(DAQ))
		string deviceName=DAQ2Device(DAQ)
	else
		deviceName="dev1"
	endif
	fDAQmx_CTR_Finished(deviceName,0)
	string trig_out
	sprintf trig_out,"%s%d",pin_prefix,pin_out
	DAQmx_CTR_OutputPulse /DEV=deviceName /DELY=0 /FREQ={1/isi,0.5} /NPLS=0 /STRT=0 /OUT=trig_out 0
	return fDAQmx_CTR_Start(deviceName,0)
End

static Function StopClock([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	if(!paramisdefault(DAQ))
		string deviceName=DAQ2Device(DAQ)
	else
		deviceName="dev1"
	endif
	return fDAQmx_CTR_Finished(deviceName,0)
End

static Function ErrorHook([DAQ]) // This static Functionis called when a scanning or waveform generation error is encountered
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	if(!paramisdefault(DAQ))
		string deviceName=DAQ2Device(DAQ)
	else
		deviceName="dev1"
	endif
	dfref daqDF=GetDaqDF(DAQ)
	printf "Error Sweep on DAQ '%s',\r",DAQ
	DoAlert 0, fDAQmx_ErrorString()
	fDAQmx_ResetDevice(deviceName)
	DoWindow /f Cell_Window
	Button Start title="Start",win=$(DAQ+"_Selector")
	variable /g daqDF:acquiring=0
End

static Function SlaveHook(DAQ)
	String DAQ
	
	variable chan=Label2Chan("Respiration")
	if(numtype(chan)==0 && chan>=0)
		dfref daqDF=GetDaqDF(DAQ)
		wave /sdfr=daqDF Sweep=$("input_"+num2str(chan))
		if(0)
			Duplicate /free Sweep CardiacTemp
			Wave Sweep=CardiacTemp
			Sweep*=-1
			Variable length=dimdelta(Sweep,0)*dimsize(Sweep,0)
			WaveStats /Q/R=(length/4,3*length/4) Sweep
			//StatsQuantiles /Q Sweep
			FindLevels /Q/M=0.1 /EDGE=1 Sweep,V_avg+(V_max-V_avg)/2
			//FindLevels /Q/M=0.1 /EDGE=1 Sweep,V_median+(V_Q75-V_median)*10
			Wave W_FindLevels
			Differentiate /METH=1 W_FindLevels
			if(numpnts(W_FindLevels)>2)
				WaveStats /Q/R=[0,numpnts(W_FindLevels)-2] W_FindLevels
				Variable Hz=1/V_avg
			else
				Hz=NaN
			endif
			//print 60*Hz // Pulses per minute.  
		else
			Duplicate /free Sweep,CardiacCorr
			Correlate /NODC /AUTO CardiacCorr,CardiacCorr
			//Display CardiacCorr
			WaveStats /Q/R=(0.1,0.6) CardiacCorr
			Hz=1/V_maxloc
		endif
		if(!WinType("CardiacWin"))
			Display /K=1 /N=CardiacWin
			Make /o/n=(100) daqDF:CardiacHistory /WAVE=CardiacHistory=NaN
			AppendToGraph CardiacHistory
			ModifyGraph mode=3,marker=19
			SetAxis bottom 99,0
			SetAxis left 150,350
			ControlBar /T 62
		endif
		wave /sdfr=daqDF CardiacHistory
		Rotate 1,CardiacHistory
		SetScale /P x,0,1,CardiacHistory
		CardiacHistory[0]=round(60*Hz)
		ValDisplay CardiacRate fsize=48,size={112,56},value=#(joinpath({getdatafolder(1,daqDF),"CardiacHistory[0]"})),win=CardiacWin
		//ValDisplay CardiacRate value=num2str(60*Hz)
		KillWaves /Z CardiacTemp,TempCorr,W_FindLevels
	endif
End

static Function DynamicClamp(DAQ)
	string DAQ
	
	string device=DAQ2Device(DAQ)
	DAQmx_AI_SetupReader/DEV=device "0;"
	DAQmx_AO_SetOutputs/DEV=device/KEEP=1 "0;"
	make /o/n=10000 myData
	setscale x,0,1,myData // Scale to 10 kHz
	variable i,lastWrite=StopMsTimer(-2)
	make /o/n=1 oneData
	do
		fDAQmx_AI_GetReader(device,oneData)
		oneData+=gnoise(1)
		fDAQmx_AO_UpdateOutputs(device,oneData)
		variable thisWrite=StopMsTimer(-2)
		if(thisWrite>lastWrite + 100) // more than 100 microseconds (1 / 10kHz) since the last write.  
			myData[i]=oneData[0]
			lastWrite=thisWrite
			i+=1
		endif
	while(i<10000)
End

static Function DynamicClampLagTest(tau)
	variable tau // ms
	variable t,c=10,g0=1,g1=1
	make /o/n=(5000) vm=0; vm[0]=0
	setscale x,0,0.05,"s",vm
	//vm=vm[p-1]-+cos(2*pi*10*x)*vm(x-tau))/c
	make /o/n=2 params={1000,tau/1000}
	IntegrateODE dcODE, params, vm 
	//for(t=1;t<numpnts(vm);t+=1)
	//	vm[t]=vm[t-1]+((cos(2*pi*100*x)-0)*vm[t-1])/c
	//endfor
	fft /out=3 /dest=mag /rx=(0.025,0.05) vm
	fft /out=5 /dest=phase  /rx=(0.025,0.05) vm
	print mag(params[0]),phase(params[0])
	if(tau==0)
		duplicate /o vm,vm2
	endif
	return phase(params[0])
End

Function dcODE(pw, xx, yw, dydx)
	Wave pw	// parameter wave (input)
	Variable xx	// x value at which to calculate derivatives
	Wave yw	// wave containing y[i] (input)	
	Wave dydx	// wave to receive dy[i]/dx (output)	

	wave vm
	//print xx,pw[1],vm(xx-pw[1])
	dydx[0] = 1000*cos(2*pi*pw[0]*xx) + 1000*vm(xx-pw[1])*sin(2*pi*pw[0]*xx) - 100*vm(xx-pw[1])
	
	return 0
End

function DynamicClampLagTests()
	variable tau
	make /o/n=0 taus,phases
	//progwinopen()
	for(tau=0;tau<=2;tau+=0.01)
		//progwin(tau,0)
		variable phase=DynamicClampLagTest(tau)
		taus[numpnts(taus)]={tau}
		phases[numpnts(phases)]={phase}
	endfor
	//progwinclose()
end