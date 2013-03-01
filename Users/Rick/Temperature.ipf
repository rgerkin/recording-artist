#pragma rtGlobals=1		// Use modern global access method.

constant tempSetPoint=37
constant tempLogg=1
constant tempGain=1 // mV of EMF per V on DAQ input.  
constant defaultTempInputChan=2
constant defaultTempOutputChan=3
constant NIDAQmx_TempFeedbackCounterNum=1
strconstant NIDAQmx_TempFeedbackCounterOut=""//"PFI5"

// This will cause all other acquisition to stop. 

Function InitTempFeedback()
	String currFolder=GetDataFolder(1)
	NewDataFolder /O/S root:Packages
	NewDataFolder /O/S TempFeedback
	if(!exists("dutyCycle"))
		Variable /G dutyCycle=0.5
		Variable /G tempChanNum,tempInputChan,tempOutputChan,temp,setpoint=tempSetPoint
		Make /o/n=100 InputWave
	endif
	NVar tempChanNum
	//NVar tempInputChan,tempOutputChan
	Wave /T InputMap=root:parameters:InputMap
	Wave /T OutputMap=root:parameters:OutputMap
	Wave /T Labels=root:parameters:Labels
	FindValue /TEXT="Thermal" /TXOP=4 Labels
	tempChanNum=V_Value
	
	if(tempChanNum>=0)
		String directions="input;output"
		Variable i
		for(i=0;i<ItemsInList(directions);i+=1)
			String direction=StringFromList(i,directions)
			Wave /T Map=root:parameters:$(direction+"Map")
			String mapChan=Map[tempChanNum]
			if(StringMatch(mapChan[1],"_"))
				mapChan=mapChan[2,strlen(mapChan)-1]
			endif
			NVar tempChan=$("temp"+direction+"chan")
			tempChan=str2num(mapChan)
		endfor
	else
		NVar tempInputChan,tempOutputChan
		tempInputChan=defaultTempInputChan
		tempOutputChan=defaultTempOutputChan
	endif
	SetDataFolder $currFolder
End
 
Function BeginTempFeedback(period)
	Variable period // In seconds. 
	ControlInfo /W=VitalSignsPanel TempFeedback 
	if(V_Value) // A constant in DAQInterface.ipf.  
		if(!exists("root:Packages:TempFeedback"))
			InitTempFeedback()
		endif
		CtrlNamedBackground TempFeedback,proc=TempFeedback,period=60*period,start
	endif
End

Function EndTempFeedback()
	CtrlNamedBackground TempFeedback,stop
End

Function TempFeedback(s)
	STRUCT WMBackgroundStruct &s
	ControlTemp(tempLogg)
	return 0
End

// Switch an output channel on or off depending on whether the temperature being monitored on an input channel is below or above a setpoint.  
Function ControlTemp(logg[,setpoint])
	Variable setPoint,logg
	
	if(ParamIsDefault(setPoint))
		NVar globalSetPoint=root:Packages:tempFeedback:setpoint
		setPoint=globalSetPoint
	endif
	
	NVar tempChanNum=root:Packages:TempFeedback:tempChanNum // The Igor channel number.  
	NVar tempInputChan=root:Packages:TempFeedback:tempInputChan // The DAQ input channel number.  
	NVar tempOutputChan=root:Packages:TempFeedback:tempOutputChan // The DAQ output channel number.  
	NVar temp=root:Packages:TempFeedback:temp
	
	Make /o/n=1 root:Packages:TempFeedback:ThermocoupleEMF /WAVE=ThermocoupleEMF
	String command
	NVar acquiring=root:status:acquiring
	if(strlen(ListMatch(DAQs,"NIDAQmx"))) // If there is a NIDAQmx attached.    
#if exists("DAQmx_Scan")
		NVar acquiring=root:acquiring
		if(!acquiring) // If acquisition is currently stopped. 
			Wave InputWave=root:Packages:tempFeedback:InputWave
			SetScale x,0,0.01,InputWave

			DAQmx_Scan /DEV="dev1" /STRT=1 WAVES="root:Packages:tempFeedback:InputWave,"+num2str(tempInputChan)+";"
			ThermoCoupleEMF=mean(InputWave)//fDAQmx_ReadChan("dev1",tempInputChan,-10,10,-1) // Just read directly from the channel.  
		else // If acquisition is running.  
			ThermoCoupleEMF=mean(root:$("input_"+num2str(tempChanNum))) // You can't just read from the channel, so take the wave that was most recently read from the channel.  
		endif
#endif
	elseif(strlen(ListMatch(DAQs,"ITC"))) // If there is no NIDAQmx, but there is an ITC attached.  	
		if(!acquiring) // If acquisition is currently stopped. 
			sprintf command,"ITC18ReadADC %d,root:Packages:TempFeedback:ThermocoupleEMF",tempInputChan // Assumes that signal will be in mV, due to 1000x gain from an amplifier.  
			Execute /Q command 
		else // If acquisition is running.  
			ThermoCoupleEMF=mean(root:$("input_"+num2str(tempChanNum))) // You can't just read from the channel, so take the wave that was most recently read from the channel.  
		endif
	endif
	ThermocoupleEMF/=tempGain
	temp=KType2Temp(ThermoCoupleEMF)
	//print temp
	if(logg)
		NVar startTime=root:status:expStartT
		Variable currTime=datetime-startTime // Seconds since the beginning of the experiment.  Factor of 60 different from values in root:SweepT (which are in minutes).  
		Wave /Z TempHistory=root:status:Temp
		if(!WaveExists(TempHistory))
			Make /o/n=(0,2) root:status:Temp; Wave TempHistory=root:status:Temp
			SetDimLabel 1,0,Time,TempHistory
			SetDimLabel 1,1,Temperature,TempHistory
		endif
		TempHistory[dimsize(TempHistory,0)]={{currTime},{temp}}
	endif

	if(strlen(ListMatch(DAQs,"NIDAQmx")))
#ifdef NIDAQmx		
		Wave kHz=root:parameters:kHz
		Variable i,LCM_=kHz[0]
		for(i=1;i<numpnts(kHz);i+=1)
			LCM_=LCM2(LCM_,kHz[i]) // We want to get the least common multiple of the DAQ sampling frequencies.   
		endfor
		LCM_=min(200,LCM_) // Not to exceed 200 kHz.  
		Variable pulseInterval=1/(LCM_*1000) // The interval should be based on the DAQ sampling frequencies so that there will be an integer number of pulses in every sample, thus masking the counter artifact.  
		Variable diff=setpoint-temp
		NVar dutyCycle=root:Packages:tempFeedback:dutyCycle
		Variable rate=(abs(diff))/(0.5+abs(diff))
		if(diff>0) // Too cold.  
			dutyCycle+=rate*(1-dutyCycle)/2
		elseif(diff<0) // Too warm.  
			dutyCycle-=rate*dutyCycle/2
			//dutyCycle=0.01
		endif
		//print temp,oldDutyCycle,"->",dutyCycle
		dutyCycle=dutyCycle>0.99 ? 0.99 : dutyCycle
		dutyCycle=dutyCycle<0.01 ? 0.01 : dutyCycle
#if exists("DAQmx_Scan")
		fDAQmx_CTR_Finished("dev1",NIDAQmx_TempFeedbackCounterNum)
		DAQmx_CTR_OutputPulse /DEV="dev1" /DELY=0 /FREQ={1/pulseInterval,dutyCycle} /IDLE=1 /NPLS=0 /OUT=NIDAQmx_TempFeedbackCounterOut /STRT=0 NIDAQmx_TempFeedbackCounterNum
		fDAQmx_CTR_Start("dev1",NIDAQmx_TempFeedbackCounterNum)
#endif
		//print dutycycle
		//print 5*(temp<SetPoint)
		//print fDAQmx_WriteChan("dev1",tempOutputChan,5*(temp<SetPoint),-10,10) // Just read directly from the channel.  
#endif
	elseif(strlen(ListMatch(DAQs,"ITC")))
#if exists("DAQmx_Scan")
		sprintf command, "ITC18SetDAC %d,%d",tempOutputChan,5*(temp<SetPoint)
		//print command
		Execute /Q command
		if(!exists("root:parameters:ibw:thermal"))
			NewDataFolder /O root:parameters:ibw
			NVar duration=root:parameters:duration
			Wave kHz=root:parameters:kHz
			Variable kHz_=kHz[WhichListItem("ITC",DAQs)]
			Make /o/n=(round(kHz_*1000*duration)) root:parameters:ibw:thermal
			SetScale x,0,duration,root:parameters:ibw:thermal
		endif
		Wave Labels=root:parameters:Labels
		FindValue /TEXT="Thermal" /TXOP=4 Labels
		Wave Stimulus=root:DAQ:$("Raw_"+num2str(V_Value))
		//print GetWavesDataFolder(Stimulus,2)
		Stimulus=5000*(temp<SetPoint)
#endif
	endif
	KillWaves /Z ThermoCoupleEMF
End

// Convert potential measured on K-type thermocouple to a temperature in degrees C.  
Function KType2Temp(vWave)
	Wave vWave
	WaveStats /Q/M=1 vWave
	Variable EMF=-V_avg
	EMF+=0.905 // Set relative to potential difference at 0 degrees C as measured in ice water.  
	Make /o/n=10 KTypeCoeffs={0,25.08,0.0786011,-0.250313,0.0831527,0.0122803,0.000980404,-4.41303e-05,1.05773e-06,-1.05276e-08}
	Variable i,temp=0
	for(i=0;i<numpnts(KTypeCoeffs);i+=1)
		temp+=KTypeCoeffs[i]*EMF^i
	endfor
	KillWaves /Z KTypeCoeffs
	return temp
End

Function VitalPanel()
	InitTempFeedback()
	DoWindow /K VitalSignsPanel
	NewPanel /K=1 /N=VitalSignsPanel /W=(600,100,850,200)
	NVar setPoint=root:Packages:tempFeedback:setPoint
	ValDisplay Temp fsize=18, barmisc={0,40}, bodywidth=100, limits={setPoint*0.9,setPoint*1.1,setPoint}, value=#"round(10*root:Packages:TempFeedback:temp)/10", title="Temp. (C)"
	Checkbox TempFeedback, pos={200,7}, value=1,proc=VitalPanelCheckboxes, title="On"
	Wave Labels=root:parameters:Labels
	FindValue /TEXT="Cardiac" /TXOP=4 Labels
	ValDisplay Cardiac fsize=18, barmisc={0,40}, bodywidth=100, limits={0,1000,400}, value=#("round(root:cell"+num2str(V_Value)+":Heart_Rate[root:current_sweep_number][0])"), title="Heart Rate (Hz)"
	
	BeginTempFeedback(5)
	//ValDisplay TempDuty, bodywidth=0, 
End

Function VitalPanelCheckboxes(ctrlName,value) : CheckboxControl
	String ctrlName
	Variable value
	NVar acquiring=root:status:acquiring
	strswitch(ctrlName)
		case "TempFeedback":
			if(value && !acquiring) // If checkbox is checked and acquisition is not live.  
				BeginTempFeedback(5)
			else
				EndTempFeedback()
			endif
			break
	endswitch
End
