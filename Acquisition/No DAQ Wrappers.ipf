
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

static function /s InputChannelList([DAQ])
	string DAQ
	
	string list = ""
	variable i
	for(i=0;i<num_inputs;i+=1)
		list+=num2str(i)+";"
	endfor
	//list += "D;N;"
	return list
end

static function /s OutputChannelList([DAQ])
	string DAQ
	
	string list = ""
	variable i
	for(i=0;i<num_outputs;i+=1)
		list+=num2str(i)+";"
	endfor
	//list += "D;N;"
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
	struct wmbackgroundstruct &s
	
	dfref df = $input_path
	string input_waves = Core#StrPackageSetting(module,"DAQs",MasterDAQ(),"inputWaves")
	variable i
	for(i=0;i<min(num_inputs,itemsinlist(input_waves));i+=1)
		string input_wave = stringfromlist(i,input_waves)
		string name = stringfromlist(0,input_wave,",")
		variable chan = str2num(stringfromlist(1,input_wave,","))
		wave w = $name
		wave /sdfr=df buffer = $("ch"+num2str(i))
		nvar /sdfr=df xx = $("x"+num2str(i))
		if(numpnts(buffer)-xx >=numpnts(w))
			w = buffer[p+xx]
			xx += numpnts(w)
			//printf "Listening read from the buffer...\r"
		endif
		if(numpnts(buffer)>max_buffer_size)
			PurgeInput(i)
		endif
	endfor
	return 0
end

static function Waiting(s)
	struct wmbackgroundstruct &s
	
	Speak(1,"",0)
	
	string DAQ=MasterDAQ(type=DAQtype)
	dfref df = GetDAQdf(DAQ)
	nvar /sdfr=df lastDAQSweepT
	lastDAQSweepT=StopMSTimer(-2)
	
	nvar /sdfr=$noDAQ_path t_init,t_update
	variable first_sweep = t_update==0
	variable then = (t_update - t_init)/1e6
	variable now = (lastDAQSweepT - t_init)/1e6
	variable elapsed = now - then
	
	//variable points = Hz*elapsed/1e6
	dfref inDF = $input_path
	dfref outDF = $output_path
	variable i,j
	
	// Inputs matched up one-to-one to outputs.  
	for(i=0;i<min(num_inputs,num_outputs);i+=1)	
		wave /sdfr=outDF out = $("ch"+num2str(i))
		nvar /sdfr=outDF out_x = $("x"+num2str(i))
		wave response = IO(out,out_x)
		out_x += numpnts(response)
		wave /sdfr=inDF in = $("ch"+num2str(i))
		concatenate /np {response},in
		//printf "Added %d points to the input buffer.\r",numpnts(response)
	endfor
	
	// Extra inputs not matched up to any output.  
	for(j=i;j<num_inputs;j+=1)	
		wave /sdfr=inDF in = $("ch"+num2str(j))
		in = gnoise(1)
	endfor	
	
	//printf "Waiting executed once...\r"
	t_update = now*1e6 + t_init
	if(!first_sweep)
		CollectSweep(DAQ)
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

static function /wave IO(w,start)
	wave w
	variable start
	
	duplicate /free w,convolved
	make /free/n=(1000) expo = exp(-x/200)
	variable summ = sum(expo)
	expo /= summ // Normalize to a sum of 1.  
	Convolve expo,convolved
	copyscales /p w,convolved
	duplicate /free/r=[start,] convolved,result
	result += gnoise(0.0001)
	result *= 1000
	return result
end