
// $Author: rick $
// $Rev: 429 $
// $Date: 2010-05-08 15:05:43 -0400 (Sat, 08 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

Function NoDaq_InDemultiplex(input_waves)
	String input_waves
End

// Obsolete for NIDAQmx
Function NoDaq_SelectSignal(device,param1,param2,direction)
	Variable device,param1,param2,direction
End

// Obsolete for NIDAQmx
Function NoDaq_SetupTriggers(pin)
	Variable pin // Hardcoded to pin 6
End

Function NoDaq_SpeakReset(device)
	Variable device
	//return fDAQmx_WaveformStop("dev"+num2str(device))
End

Function NoDaq_ZeroAll()
//	fDAQmx_WaveformStop("dev1")
//	fDAQmx_ScanStop("dev1")
//	fDAQmx_WriteChan("dev1",0,0,-10,10)
//	fDAQmx_WriteChan("dev1",1,0,-10,10)
End

Function NoDaq_BoardReset(Device)
	Variable device
	//return fDAQmx_ResetDevice("dev"+num2str(device))
End

Function NoDaq_BoardInit()
	NoDAQ_BoardReset(1)
	NoDAQ_ZeroAll()
End

Function /S NoDaq_NIDAQError()
	//return fDAQmx_ErrorString()
End

Function NoDaq_Listen(device,gain,list,param,continuous,endHook,errorHook,other[,now])
	Variable device,gain
	String list
	Variable param,continuous
	String endHook,errorHook,other
	Variable now
	
	// Figure out what the difference is between /BKG=0 and /BKG=1 (right now /BKG=0 doesn't work)
	// Alternatively, set /BKG=0 and /STRT=0 and uncomment the line below it.  
	// Consider using /RPT, which is still sensitive to triggers, for continuous collection
	if(continuous)
		//DAQmx_Scan /DEV="dev1" /BKG=1 /ERRH=errorHook /EOSH=endHook /RPTC /RPTH=endHook /STRT=1 /TRIG={"/dev1/PFI6",1,1} WAVES=list
	else
		//DAQmx_Scan /DEV="dev1" /BKG=1 /ERRH=errorHook /EOSH=endHook /STRT=1 /TRIG={"/dev1/PFI6",1,1} WAVES=list
	endif
	//fDAQmx_ScanStart("dev1",1)
End

Function NoDaq_Speak(device,list,param[,now])
	Variable device
	String list
	Variable param // 0 is continuous, 32 is only one time
	Variable now
	
	if(param!=0)
		param=1
	endif
	//DAQmx_WaveformGen /DEV="dev1" /ERRH="ErrorHook()" /NPRD=(param) /STRT=1 /TRIG={"/dev1/PFI6",1,1} list
	//DAQmx_WaveformGen /DEV="dev1" /CLK={"/dev1/ai/sampleclock",1} /ERRH="ErrorHook()" /NPRD=1 /STRT=1 /TRIG={"/dev1/PFI6",1,1} list
End

Function NoDaq_Read(channel)
	Variable channel
	//return fDAQmx_ReadChan("dev1",channel,-10,10,-1)
End

Function NoDaq_Write(channel,value)
	Variable channel,value
	//return fDAQmx_WriteChan("dev1",channel,value,-10,10)
End

Function NoDaq_Start_clock(isi)
	Variable isi 
	//DAQmx_CTR_OutputPulse /DEV="dev1" /DELY=0  /FREQ={1/isi,1/(1000*isi)} /NPLS=0 /STRT=0 0
	//return fDAQmx_CTR_Start("dev1",0)
End

Function NoDaq_Stop_clock ()
	//return fDAQmx_CTR_Finished("dev1",0)
End

Function NoDaq_ErrorHook() // This function is called when a scanning or waveform generation error is encountered
	NVar acquiring = root:acquiring
	Print "ErrorSweep"
	//DoAlert 0, fDAQmx_ErrorString()
	//fDAQmx_ResetDevice("dev1")
	DoWindow /f Cell_Window
	Button start_btn title="Start"
	acquiring=0
End

// This function reports the numeric value of an error reported by the NIDAQ board.  
Function NoDaq_CheckError() 
//	NVar error=root:packages:nidaqtools:NIDAQ_ERROR
//	print "NIDAQ Error is "+num2str(error)
End