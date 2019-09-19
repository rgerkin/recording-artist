
// $Author: rick $
// $Rev: 633 $
// $Date: 2013-03-28 15:53:22 -0700 (Thu, 28 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=NoDAQ

static strconstant module="Acq"
static strconstant daqType="NoDAQ"
static strconstant noDAQ_path="root:Packages:NoDAQ"
static strconstant input_path="root:Packages:NoDAQ:input"
static strconstant output_path="root:Packages:NoDAQ:output"
static constant num_inputs=2
static constant num_outputs=2
static constant Hz = 10000
static constant max_buffer_size = 1e6

static function /s GetDAQPath()
	return noDAQ_path
end

static function /s InputChannelList([DAQ])
	string DAQ
	
	string list = ""
	variable i
	for(i=0;i<num_inputs;i+=1)
		list+=num2str(i)+";"
	endfor
	list += "D;N;"
	return list
end

static function /s OutputChannelList([DAQ])
	string DAQ
	
	string list = ""
	variable i
	for(i=0;i<num_outputs;i+=1)
		list+=num2str(i)+";"
	endfor
	list += "D;N;"
	return list
end

static function /s GetDAQDevices([types])
	string types
	
	return "dev1"
end

static function /s DAQType(DAQ[,quiet])
	string DAQ
	variable quiet
	
	return "NoDAQ"
end

static function /s DAQ2Device(DAQ) // TO DO: Make DAQ map onto a device number.  
	string DAQ
	
	string devices=GetDAQDevices()
	return stringfromlist(0,devices)
end

static Function BoardGain(DAQ)
	String DAQ
	
	return 1
End

static Function SpeakReset([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	CtrlNamedBackground NoDAQSpeak, stop
End

static Function ListenReset([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	CtrlNamedBackground NoDAQListen, stop
End

static Function SetupTriggers(pin[,DAQ])
	Variable pin
	String DAQ
End

static Function ZeroAll([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQtype),DAQ)
	SpeakReset(DAQ=DAQ)
	ListenReset(DAQ=DAQ)
	variable i
	for(i=0;i<num_outputs;i+=1)
		//Write(i,0,DAQ=DAQ)
	endfor
End

static Function BoardReset(device[,DAQ])
	variable device
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQtype),DAQ)
	CtrlNamedBackground NoDAQSpeak, kill=1
	CtrlNamedBackground NoDAQListen, kill=1
End

static Function BoardInit([DAQ])
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQtype),DAQ)
	NewDataFolder /o root:Packages
	NewDataFolder /o root:Packages:NoDAQ
	dfref df = root:Packages:NoDAQ
	newdatafolder /o df:input
	newdatafolder /o df:output
	dfref input = df:input
	dfref output = df:output
	variable i
	for(i=0;i<num_inputs;i+=1)	
		PurgeInput(i)
	endfor
	for(i=0;i<num_outputs;i+=1)	
		PurgeOutput(i)
	endfor
	variable /g df:t_init = StopMsTimer(-2) // When the buffer was initialized.  	
	variable /g df:t_update = 0 // Last time the buffer was updated by Waiting(). 
	variable /g df:tau = 1 // Time consant in ms (e.g. the pipette in the bath) 
	variable /g df:r_in = 10 // Input resistance in MΩ (e.g. the pipette in the bath)
	variable /g df:r_a = 0 // Input resistance in MΩ (e.g. the pipette in the bath)
	variable /g df:noise = 3 // RMS Noise level (e.g. in pA)
	variable /g df:offset = 0 // Pipette offset (i.e leak) (e.g. in pA)
	string /g df:direction = TransferDirection()
	BoardReset(1,DAQ=DAQ)
	ZeroAll(DAQ=DAQ)
End

static Function /S DAQError([DAQ])
	String DAQ
	
	return "No error checking for the No DAQ testing interface."
End

// Default sampling frequency in kHz.  
static Function DefaultKHz(DAQ)
	String DAQ
	
	dfref df=Core#ObjectManifest(module,"DAQs","kHz")
	nvar /sdfr=df value
	return value
End

static Function Listen(device,gain,list,param,continuous,endHook,errorHook,other[,now,DAQ])
	Variable device,gain
	String list
	Variable param,continuous,now // 'now' is non-functional
	String endHook,errorHook,other,DAQ
	
	CtrlNamedBackground NoDAQListen, start, proc=NoDAQ#Listening
End

static Function Speak(device,list,param[,now,DAQ])
	Variable device
	String list
	Variable param // 0 is continuous, 32 is only one time
	Variable now // 'now' is non-functional
	String DAQ
	
	variable continuous = Core#VarPackageSetting(module,"DAQs",MasterDAQ(),"continuous")
	dfref df = $output_path
	string output_waves = Core#StrPackageSetting(module,"DAQs",MasterDAQ(),"outputWaves")
	variable i
	for(i=0;i<min(num_outputs,itemsinlist(output_waves));i+=1)
		string output_wave = stringfromlist(i,output_waves)
		string name = stringfromlist(0,output_wave,",")
		variable chan = str2num(stringfromlist(1,output_wave,","))
		if(!IsChanActive(chan))
			continue
		endif
		wave w = $name
		wave /sdfr=df buffer = $("ch"+num2str(chan))
		variable start = numpnts(buffer)
		redimension /n=(start+dimsize(w,0)) buffer
		buffer[start,] = w[p-start]
		//printf "Speaking wrote to the buffer...\r"
		if(numpnts(buffer)>max_buffer_size)
			PurgeOutput(i)
			buffer = w[0]
		endif
	endfor
End

static Function Read(channel[,DAQ])
	Variable channel
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	dfref df = $input_path
	wave /sdfr=df w = $("ch"+num2str(channel))
	return w[numpnts(w)-1]
End

static Function Write(channel,value[,DAQ])
	Variable channel,value
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	dfref df = $output_path
	wave /sdfr=df w = $("ch"+num2str(channel))
	w[numpnts(w)] = {value}
End

static Function StartClock(isi[,DAQ])
	Variable isi
	String DAQ
	 
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	StopClock()
	
	CtrlNamedBackground NoDAQClock, start, period=isi*60, proc=NoDAQ#Waiting
	return 0
End

static Function StopClock([DAQ])
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	CtrlNamedBackground NoDAQClock, stop
	
	variable i
	for(i=0;i<num_inputs;i+=1)	
		PurgeInput(i)
	endfor
	for(i=0;i<num_outputs;i+=1)	
		PurgeOutput(i)
	endfor
End

static Function ErrorHook([DAQ]) // This static Functionis called when a scanning or waveform generation error is encountered
	String DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(type=DAQType),DAQ)
	dfref daqDF=GetDaqDF(DAQ)
	printf "Error Sweep on DAQ '%s',\r",DAQ
	BoardReset(1,DAQ=DAQ)
	variable /g daqDF:acquiring=0
End

static Function SlaveHook(DAQ)
	String DAQ
	
End

static function Listening(s)
	// This background function checks the input buffer and writes
	// to the input waves(s) when there is enough data in the buffer
	struct wmbackgroundstruct &s
	
	dfref df = $input_path
	string input_waves = Core#StrPackageSetting(module,"DAQs",MasterDAQ(),"inputWaves")
	variable i
	for(i=0;i<min(num_inputs,itemsinlist(input_waves));i+=1)
		string input_wave = stringfromlist(i,input_waves)
		string name = stringfromlist(0,input_wave,",")
		variable chan = str2num(stringfromlist(1,input_wave,","))
		if(!IsChanActive(chan))
			continue
		endif
		wave w = $name
		wave /sdfr=df buffer = $("ch"+num2str(chan))
		nvar /sdfr=df xx = $("x"+num2str(i))
		if(numpnts(buffer)-xx >=numpnts(w))
			// Write to the wave with the last input wave duration worth of data
			w = buffer[p+xx]
			xx += numpnts(w)
			//redimension /n=(xx) buffer
			//printf "Reading from the buffer...\r"
		endif
		if(numpnts(buffer)>max_buffer_size)
			PurgeInput(i)
		endif
	endfor
	return 0
end

static function Waiting(s)
	// This function fills the input and output buffers with data
	// from a virtual A/D device, then calls CollectSweep()
	struct wmbackgroundstruct &s
	
	Speak(1,"",0)
	
	string DAQ=MasterDAQ(type=DAQtype)
	dfref df = GetDAQdf(DAQ)
	nvar /sdfr=df lastDAQSweepT
	nvar /z/sdfr=SealTestDF() sealTestOn
	lastDAQSweepT=StopMSTimer(-2)
	
	nvar /sdfr=$noDAQ_path t_init,t_update,tau,r_in,r_a,noise,offset
	svar /sdfr=$noDAQ_path direction
	variable first_sweep = t_update==0
	variable then = (t_update - t_init)/1e6
	variable now = (lastDAQSweepT - t_init)/1e6
	variable elapsed = now - then
	
	//variable points = Hz*elapsed/1e6
	dfref inDF = $input_path
	dfref outDF = $output_path
	variable chan
	
	// Inputs matched up one-to-one to outputs.  
	for(chan=0;chan<min(num_inputs,num_outputs);chan+=1)	
		if(!IsChanActive(chan))
			continue
		endif
		wave /sdfr=outDF out = $("ch"+num2str(chan))
		nvar /sdfr=outDF out_x = $("x"+num2str(chan))
		wave response = IO(out,out_x,tau,r_in,r_a,direction,noise)
		response += offset
		out_x += numpnts(response)
		wave /sdfr=inDF in = $("ch"+num2str(chan))
		if(numpnts(response))
			concatenate /np {response},in
		endif
		//printf "Added %d points to the input buffer.\r",numpnts(response)
	endfor
	
	// Extra inputs not matched up to any output.  
	for(chan=chan;chan<num_inputs;chan+=1)	
		if(!IsChanActive(chan))
			continue
		endif
		wave /sdfr=inDF in = $("ch"+num2str(chan))
		in = gnoise(1)
	endfor	
	
	//printf "Waiting executed once...\r"
	t_update = now*1e6 + t_init
	if(!first_sweep)
		if(nvar_exists(sealTestOn) && sealTestOn)
			SealTestCollectSweeps(DAQ)
		else
			CollectSweep(DAQ)
		endif
	endif
	return 0
end

static function PurgeInput(chan)
	variable chan
	
	dfref df = $input_path
	make /o/d/n=0 df:$("ch"+num2str(chan)) /wave=w = 0
	setscale /p x,0,1/Hz,w
	variable /g df:$("x"+num2str(chan)) = 0 // Buffer cursor.  
end

static function PurgeOutput(chan)
	variable chan
	
	dfref df = $output_path
	make /o/d/n=0 df:$("ch"+num2str(chan)) /wave=w = 0
	setscale /p x,0,1/Hz,w
	variable /g df:$("x"+num2str(chan)) = 0 // Buffer cursor.  
end

static function /s TransferDirection()	
	// Determine how to use the input resistance to scale the response
	string mode = GetAcqMode(0)
	string outputType=GetModeOutputType(mode,fundamental=1)
	string inputType=GetModeInputType(mode,fundamental=1)
	string ratioString=outputType+"/"+inputType
	if(stringmatch(ratioString,"Current/Voltage"))
		string direction = "multiply"
	else
		direction = "divide" // Just assume they want voltage clamp if it can't be determined
	endif
	return direction
end

static function /wave IO(w, start, tau, r_in, r_a, direction, noise)
	wave w
	variable start, tau, r_in, r_a, noise
	string direction
	
	// Override with result from TransferDirection()
	direction = TransferDirection()
	
	variable dt = dimdelta(w,0)
	
	
	duplicate /free w,convolved
	make /free/n=(1000) expo = exp(-x/(0.001*tau/dt))
	variable summ = sum(expo)
	expo /= summ // Normalize to a sum of 1.  
	Convolve expo,convolved
	copyscales /p w,convolved
	
	// Get scales right (i.e. pico, micro, etc.)
	
	// These two lines aren't needed because command output (igor->rig)
	// is already generated in base units, e.g. V or A.  
	//variable out_scale = GetChanScale(0, "output")
	//convolved *= out_scale // e.g. convert from mV to V
	
	//variable in_scale = GetChanScale(0, "input")
	//variable out_scale = GetChanScale(0, "output")
	//convolved *= in_scale
	//convolved /= out_scale
	
	
	strswitch(direction)
		case "multiply":
			convolved *= r_in*1e-3 // Multiply by GOhms (MOms * 1e-3)
			break
		case "divide":
			convolved /= r_in*1e-3 // Divide by GOhms (MOms * 1e-3)
			break
	endswitch
	
	//convolved /= in_scale // e.g. convert the input (rig->igor) from A to pA
	nvar noise_ = root:Packages:noDAQ:noise
	convolved += gnoise(noise_) // Add noise in e.g. mV or pA.  
	
	redimension /n=(numpnts(w)) convolved
	if(start<numpnts(convolved))
		duplicate /free/r=[start,] convolved,result
	else
		make /free/n=0 result
	endif
	return result
end

function NoDAQPanel()
	DoWindow /K NoDAQController
	NewPanel /K=1 /N=NoDAQController /W=(10,10,150,350) as "Demo Mode Controller"
	
	dfref df = root:Packages:NoDAQ
	nvar /sdfr=df r_in, tau, noise
	
	GroupBox r_in_group pos={2,2}, size={134,62}
	make /o/n=5 df:r_in_ticks /wave=tix = {0,1,2,3,4}
	make /o/t/n=5 df:r_in_tick_labels /wave=labels = {"1","10","100","1000","10000"} 	
	TitleBox r_in_name title="Input Resistance (MΩ)", pos={5,5}
	Slider r_in title="Input Resistance (MΩ)", value=log(r_in), limits={0,4,0.1}
	Slider r_in size={125,45}, vert=0, pos={4, 25}, proc=NoDAQSliderControls, userTicks={tix, labels}
	
	GroupBox tau_group pos={2,70}, size={134,62}
	make /o/n=5 df:tau_ticks /wave=tix = {-1,0,1,2,3} 
	make /o/t/n=5 df:tau_labels /wave=labels = {"0.1","1","10","100","1000"}
	TitleBox tau_name title="Time Constant (ms)", pos={5,75}
	Slider tau title="Time Constant (ms)", value=log(tau), limits={-1,3,0.1}
	Slider tau size={125,45}, vert=0, pos={4, 95}, proc=NoDAQSliderControls, userTicks={tix, labels}

	GroupBox noise_group pos={2,138}, size={134,62}
	make /o/n=5 df:noise_ticks /wave=tix = {-1,0,1,2,3} 
	make /o/t/n=5 df:noise_labels /wave=labels = {"0.01","0.1","1","10","100"}
	TitleBox noise_name title="RMS Noise", pos={5,145}
	Slider noise title="RMS Noise", value=log(noise), limits={-2,2,0.1}
	Slider noise size={125,45}, vert=0, pos={4, 165}, proc=NoDAQSliderControls, userTicks={tix, labels}
	
	GroupBox offset_group pos={2,206}, size={134,62}
	//make /o/n=5 df:offset_ticks /wave=tix = {-500,-250,0,250,500} 
	//make /o/t/n=5 df:offset_labels /wave=labels = {"-500","-250","0","250","500"}
	TitleBox offset_name title="Pipette Offset (pA)", pos={5,208}
	Slider offset title="Pipette Offset (pA)", variable=root:Packages:noDAQ:offset, limits={-500,500,10}//, userTicks={tix, labels}
	Slider offset size={125,45}, vert=0, pos={4, 228}
	
	GroupBox r_a_group pos={2,274}, size={134,62}
	//make /o/n=5 df:offset_ticks /wave=tix = {-500,-250,0,250,500} 
	//make /o/t/n=5 df:offset_labels /wave=labels = {"-500","-250","0","250","500"}
	TitleBox r_a__name title="Access Resistance (pA)", pos={5,280}
	Slider r_a title="Access Resistance (pA)", variable=root:Packages:noDAQ:r_a, limits={0,40,1}//, userTicks={tix, labels}
	Slider r_a size={125,45}, vert=0, pos={4, 300}
end

function NoDAQSliderControls(info)
	struct WMSliderAction &info
	
	//print(10^info.curval)
	string var_name = info.ctrlName
	dfref df = root:Packages:NoDAQ
	nvar /sdfr=df var = $var_name
	var = 10^info.curval
end