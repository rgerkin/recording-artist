
// $Author: rick $
// $Rev: 429 $
// $Date: 2010-05-08 15:05:43 -0400 (Sat, 08 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

// Using the NIDAQ nonMX procedure file
Function MX()
	return 0
End

//Function CounterControl(Device,Counter,Param)
//	Variable device,counter,param
//	return fNIDAQ_GPCTR_Control(device,counter,param)
//End
//
//Function CounterChange(device,counter,param,value)
//	Variable device,counter,param,value
//	return fNIDAQ_GPCTR_Change_Parameter(device,counter,param,value)
//End
//
//Function CounterSet(device,counter,param)
//	Variable device,counter,param
//	return fNIDAQ_GPCTR_Set_Application(device,counter,param)
//End

Function SelectSignal(device,param1,param2,direction)
	Variable device,param1,param2,direction
	return fNIDAQ_Select_Signal(device,param1,param2,direction)
End

Function SetupTriggers(pin)
	Variable pin // Hardcoded to pin 6
	Variable In_Start_trigger = fnidaq_param_constant("ND_in_start_trigger")
	Variable Out_Start_trigger = fnidaq_param_constant("ND_out_start_trigger")
	Variable Output0 = fnidaq_param_constant("ND_GPCTR0_OUTPUT")
	Variable Output1 = fNIDAQ_Param_Constant("ND_PFI_6") // Pin 6
	Variable LowToHigh = fnidaq_param_constant("ND_low_to_high")
	fNIDAQ_Select_Signal(1,Out_Start_Trigger,Output1,LowToHigh)
	fNIDAQ_Select_Signal(1,In_Start_trigger,Output0,LowToHigh)
End

Function SpeakReset(device)
	Variable device
	return fNIDAQ_WFReset(device)
End

Function ZeroAll()
	fnidaq_wfstop(1)
	fnidaq_wfreset(1)
	fnidaq_resetscan(1)
	fnidaq_writechan(1,0,0)
	fnidaq_writechan(1,1,0)
End

Function BoardReset(Device)
	Variable device
	return fNIDAQ_BoardReset(device)
End

Function BoardInit()
	fNIDAQ_BoardReset(1)
	fNIDAQ_SetInputChans(1, 8, 12, 1, 1)
	fNIDAQ_SetInputTrigger(1, 0, 1, 1, 1, 0)
	fNIDAQ_InputConfig(1, 0, 0, 20.000000)
	fNIDAQ_SetOutputChans(1, 2, 12, 0, 0, 0)
	fNIDAQ_OutputConfig(1, 0, 0, 10.000000); fNIDAQ_OutputConfig(1, 1, 0, 10.000000)
	fNIDAQ_SetCounters(1, 0, 0, 0)
	fnidaq_writechan(1,0,0)
	fnidaq_writechan(1,1,0)
End

Function /S NIDAQError()
	return fNIDAQ_ErrorString()
End

Function Listen(device,gain,list,param,endHook,errorHook,other)
	Variable device,gain
	String list
	Variable param
	String endHook,errorHook,other
	return fNIDAQ_ScanAsyncStart(device,gain,list,param,endHook,errorHook,other)
End

Function Speak(device,list,param)
	Variable device
	String list
	Variable param
	return fNIDAQ_WaveformGen(device,list,param)
End

Function Read(channel)
	Variable channel
	return fNIDAQ_ReadChan(1,channel,1)
End

Function Write(channel,value)
	Variable channel,value
	return fNIDAQ_WriteChan(1,channel,value)
End

Function Start_clock (isi)
	Variable isi 
	Variable Output0 = fnidaq_param_constant("ND_GPCTR0_OUTPUT")
	Variable LowToHigh = fnidaq_param_constant("ND_low_to_high")
	Variable Counter0 = fnidaq_param_constant("ND_counter_0")
	Variable PulseTrainGen = fnidaq_param_constant("ND_pulse_train_gnr")
	Variable Source = fnidaq_param_constant("ND_source")
	Variable HundredKClock = fnidaq_param_constant("ND_Internal_100_Khz")
	Variable Count1 = fnidaq_param_constant("ND_count_1")
	Variable Count2 = fnidaq_param_constant("ND_count_2")
	Variable Program = fnidaq_param_constant("ND_program")
	Variable Reset = fnidaq_param_constant("ND_reset")
// will send trigger pulse to CTR0OUT pin
	fNIDAQ_GPCTR_Control(1,Counter0,Reset)
	fNIDAQ_Select_Signal(1,Output0,Output0,LowToHigh)
	fNIDAQ_GPCTR_Set_Application(1,Counter0,PulseTrainGen)
	fNIDAQ_GPCTR_Change_Parameter(1,Counter0,Source,HundredKClock)
	fNIDAQ_GPCTR_Change_Parameter(1,Counter0,Count2,10)
	fNIDAQ_GPCTR_Change_Parameter(1,Counter0,Count1,isi*100000-10)
	//fNIDAQ_GPCTR_Change_Parameter(1,Counter0,Count1,isi*100000)
// starts counter
	fNIDAQ_GPCTR_Control(1,Counter0,Program)
End

Function Stop_clock ()
	Variable Counter0 = fnidaq_param_constant("ND_counter_0")
	Variable Counter1 = fnidaq_param_constant("ND_counter_1")
	Variable reset = fnidaq_param_constant("ND_reset")
// Stops counters
	fNIDAQ_GPCTR_Control(1,Counter0,Reset)
	fNIDAQ_GPCTR_Control(1,Counter1,Reset)
End

Function ErrorSweep () // This function is called by ScanAsyncStart when it makes an error
	NVar stop_code = root:stop_code
	Print "ErrorSweep"
	DoAlert 0, fNIDAQ_ErrorString()
	fNIDAQ_Boardreset(1)
	DoWindow /f Cell_Window
	Button start_btn title="Start"
	stop_code = 1
End

// This function reports the numeric value of an error reported by the NIDAQ board.  
Function CheckError() 
	NVar error=root:packages:nidaqtools:NIDAQ_ERROR
	print "NIDAQ Error is "+num2str(error)
End

// Returns the time until the next sweep is started.
Function Time2Next()
	Variable counter_ID=fnidaq_param_constant("ND_counter_0")
	Variable time_left= fNIDAQ_GPCTR_Watch(1, counter_ID, fnidaq_param_constant("ND_Count"))
	time_left=round(time_left/1000)/100
	return time_left
End

// Returns whether or not Igor is in the middle of collecting a sweep.  
Function Collecting()
	Variable time_left=Time2Next()
	NVar ISI=root:variables:ISI
	NVar duration=root:variables:duration
	NVar stop_code=root:stop_code
	print time_left, ISI, duration
	if(time_left>ISI-duration && stop_code==0)
		return 1
	else
		return 0
	endif
End