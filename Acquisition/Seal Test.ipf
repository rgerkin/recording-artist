

// $Rev: 626 $
// $Date: 2013-02-07 09:36:23 -0700 (Thu, 07 Feb 2013) $

#pragma rtGlobals=1		// Use modern global access method.

static strconstant module="Acq"

constant sealTestPoints=1000

// Constants for the pressure sensor.  
constant mBarPerPSI=68.9475729 // millibar per psi.  
constant voltsPerPSIat5volts=0.3 // Spec sheet for pressure sensor ASCX05DN says 0.9 V/psi for a 5 volt supply.  For ASCX15DN: 0.3 V/psi.  
constant offsetAt5volts=0.25  // Voltage when the pressure is zero.  Spec sheet for ASCX05DN says 0.25 V for a 5 volt supply.  For ASCX15DN: 0.25 V.  

// Initialize data for a seal test on the channels specified by 'chanBits'.  
Function SealTest(chanBits[,instance,DAQ])
	variable chanBits // 2^n for each channel on which a seal test is desired.    
	String instance,DAQ
	
	if(paramisdefault(instance))
		string instances=Core#ListPackageInstances(module,"sealTest")
		instance=stringfromlist(0,instances)
	endif
	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())
	
	if(numType(chanBits) || chanBits<=0)
		return -1
	endif
	dfref packageDF=Core#PackageHome(module,"sealTest")
	string /g packageDF:instance=instance
	dfref df=SealTestDF()
	dfref instanceDF = df:$instance
	dfref daqDF=GetDaqDF(DAQ)
	NVar /sdfr=daqDF acquiring
	if(acquiring==1) // If acquisition is in progress
		DoAlert 0,"You must stop data acquisition before starting a seal test."
		return -2
	endif
	
	nvar /sdfr=daqDF numChannels
	variable lastSweep=GetCurrSweep()
	variable kHz=GetKhz(DAQ)
	string /G daqDF:inputWaves=""
	string /G daqDF:outputWaves=""
	//make /o/n=(numChannels) daqDF:LCM_=1
	variable /G df:chanBits=chanBits
	variable i
	variable /g df:zap=0, df:thresholdCrossed=0
	nvar /sdfr=instanceDF freq,useTelegraph
	freq=max(0.1,freq)
	variable /G df:iteration=0
	variable /G df:sealTestOn=0
	nvar /sdfr=df sealTestOn
	variable /G df:thresholdOn=0
	variable /G df:pulseOn=1
	string /G df:modes="",df:sweeps,df:channels=""
	svar /sdfr=df modes,channels
	make/o/n=500 df:thyme /wave=thyme
	thyme=x/kHz
	make /o/n=(numChannels) df:Ampl /wave=Ampl=NaN
	variable numSealTests=0
	
	for(i=0;i<numChannels;i+=1)
		if(chanBits & 2^i) // Seal test requested on this channel.  
			string channel=num2str(i)
			dfref chanDF=SealTestChanDF(i)
			variable /G chanDF:inputRes
			variable /G chanDF:seriesRes
			variable /G chanDF:timeConstant
			variable /G chanDF:pressure
			variable /G chanDF:supplyVolts
			nvar /sdfr=chanDF supplyVolts
			if(supplyVolts==0)
				supplyVolts=9 // 9 volt battery hooked up to pressure sensor.  
			endif
			variable /G df:zap=0
			variable historyPoints=10000/freq
			make /D/o/n=(historyPoints) chanDF:InputHistory=nan,chanDF:SeriesHistory=nan,chanDF:PressureHistory=nan,chanDF:TimeConstantHistory=nan
			if(useTelegraph)
				SetAcqModeFromTelegraph(0)
			endif
			String mode=GetAcqMode(i)
			modes+=mode+";"
			
			// Output.  
			SealTestOutput(i)
	
			// Input.
			SealTestInput(i)
			
			sealtestOn+=2^i
			Variable modeCount=NumberByKey(mode,modes)
			modes=ReplaceNumberByKey(mode,modes,modeCount>0 ? modeCount+1 : 1)
			numSealTests+=1
			channels+=channel+";"
		endif
	endfor
	
	SealTestWindow()
	nvar /sdfr=GetStatusDF() expStartT
	variable /g df:sealTestT=datetime-expStartT
	SealTestStart(1,DAQ)
	if(StringMatch(DAQType(DAQ),"ITC"))
		SealTestStart(1,DAQ) // Initial seal test is messed up and a reset is needed.  
	endif
End

function SealTestInputsAndOutputs(DAQ)
	string DAQ
	
	dfref df=SealTestDF()
	dfref daqDF=GetDaqDF(DAQ)
	
	nvar /sdfr=df chanBits
	nvar /sdfr=daqDF numChannels
	svar /sdfr=daqDF inputWaves,outputWaves
	inputWaves=""
	outputWaves=""
	variable i
	for(i=0;i<numChannels;i+=1)
		if(chanBits & 2^i) // Seal test requested on this channel.  
			SealTestOutput(i)
			SealTestInput(i)
		endif
	endfor
end

function /df SealTestChanDF(chan)
	variable chan
	
	dfref df=SealTestDF()
	string name="ch"+num2str(chan)
	newdatafolder /o df:$name
	dfref chanDF=df:$name
	return chanDF
end

function /df SealTestDF()
	string instance
	
	dfref df=Core#PackageHome(module,"sealTest")
	return df
end

// Hard restart of seal test, including reconstruction of the pulse based on a consideration of gains.  
// A softer restart can be achieved with SealTestStart(1,DAQ).  
Function RestartSealTest(DAQ)
	String DAQ
	nvar /z/sdfr=GetDaqDF(DAQ) chanBits
	
	if(nvar_exists(chanBits))
		SealTestEnd(DAQ=DAQ)
		SealTest(chanBits,DAQ=DAQ)
	endif
End

Function SealTestPoints(DAQ)
	string DAQ
	
	nvar /z/sdfr=SealTestDF() points
	if(nvar_exists(points))
		variable points_=points
	else
		points_=1000
	endif
	return points_
End

function /s SealTestInstance()
	dfref packageDF=Core#PackageHome(module,"sealTest")
	svar /z/sdfr=packageDF instance
	if(svar_exists(instance))
		return instance
	endif
	return ""
	//selectstring(!svar_exists(instance),"",instance) 
end

Function SealTestOutput(chan)
	Variable chan
	
	String currFolder=GetDataFolder(1)
	
	dfref df=SealTestDF()
	svar instance = df:instance
	dfref instanceDF = df:$instance
	dfref chanDF=SealTestChanDF(chan)
	wave /sdfr=df ampl
	nvar /sdfr=instanceDF freq
	String channel=num2str(chan)
	String mode=GetAcqMode(chan)
	string outputType=GetModeOutputType(mode,fundamental=1)
	Ampl[chan]=numtype(Ampl[chan]) ? (StringMatch(outputType,"Current") ? -100 : 5) : Ampl[chan] // 5 mV or 100 pA.  
	Ampl=numtype(Ampl) ? Ampl[chan] : Ampl // Set remaining NaNs to the value of this channel's amplitude.  
	Variable outputGain=GetModeOutputGain(mode)
	String DAQ=Chan2DAQ(chan)
	if(StringMatch(DAQType(DAQ),"NIDAQmx"))
		outputGain*=1000 // Convert from a denominator of mV to a denominator of V.  
	endif
	String pulseName=CleanupName("pulse_"+channel,0)
	Make/o/n=(SealTestPoints(DAQ)) chanDF:Pulse /WAVE=Pulse
	SetScale x,0,1/freq,"s",Pulse
	
	pulse=0
	if(StringMatch(outputType,"Current"))
		pulse=x>=1/(4*freq) ? 1 : pulse
		pulse=x>=3/(4*freq) ? 0 : pulse
	else
		pulse=x>=1/(6*freq) ? -1 : pulse
		pulse=x>=3/(6*freq) ? 1 : pulse
		pulse=x>=5/(6*freq) ? 0 : pulse
	endif
	Duplicate /o Pulse chanDF:NullPulse /WAVE=NullPulse
	NullPulse=0
	
	Duplicate /o Pulse chanDF:BasePulse /WAVE=BasePulse
	BasePulse/=outputGain
	
	Pulse*=(Ampl[chan])
	//Pulse+=SuperClampCheck(chan)
	Pulse/=outputGain
	
	svar /sdfr=GetDaqDF(DAQ) outputWaves
	String outputWaveStr=JoinPath({getdatafolder(1,chanDF),"Pulse"})+","+Chan2DAC(chan)+";"
	if(WhichListItem(outputWaveStr,outputWaves)<0)
		outputWaves+=outputWaveStr
	endif
End

Function SealTestInput(chan)
	variable chan
	
	dfref df=SealTestDF()
	svar instance = df:instance
	dfref instanceDF = df:$instance
	nvar /sdfr=instanceDF freq
	String channel=num2str(chan)
	String mode=GetAcqMode(chan)
	
	Variable inputGain=GetModeInputGain(mode)
	String DAQ=Chan2DAQ(chan)
	strswitch(DAQType(DAQ))
		case "NIDAQmx": // If there is a NIDAQ in use.  
			String gainStr=",-10,10,"+num2str(1000/inputGain)+",0" // We need this information in the 'inputWaves' string.  
			break
		default:
			gainStr=""
			break
	endswitch
	dfref chanDF=SealTestChanDF(chan)
	Make/o/n=(SealTestPoints(DAQ)) chanDF:Sweep /WAVE=sweep=NaN, chanDF:pressureSweep /WAVE=pressureSweep=NaN
	SetScale x,0,1/freq,"s", Sweep, PressureSweep
	
	svar /sdfr=GetDaqDF(DAQ) inputWaves
	string inputWaveStr=getwavesdatafolder(sweep,2)+","+Chan2ADC(chan)+gainStr+";"
	nvar /sdfr=instanceDF pressureOn
	if(pressureOn)
		String pressureChan=num2str(str2num(Chan2ADC(chan))+4) // e.g. if the patch signal is plugged into ADC0, assume the pressure signal is plugged into ADC4.  
		inputWaveStr+=getwavesdatafolder(pressureSweep,2)+","+pressureChan+";"
	endif
	variable i
	for(i=0;i<itemsinlist(inputWaveStr);i+=1)
		string str=stringfromlist(i,inputWaveStr)
		if(whichlistitem(str,inputWaves)<0)
			inputWaves+=str+";"
		endif
	endfor
End

Function SealTestWindow([DAQ])
	String DAQ
	
	DAQ=SelectString(ParamIsDefault(DAQ),DAQ,MasterDAQ())
	dfref df=SealTestDF()
	svar instance = df:instance
	dfref instanceDF = df:$instance
	nvar /sdfr=instanceDF left,top,right,bottom,axisMin,axisMax,freq
	string win="SealTestWin"
	if(WinType(win))
		DoWindow /F $win
	else
		//string folder="root:parameters:sealtest:"
//		Variable left=NumVarOrDefault(folder+"left",10)
//		Variable top=NumVarOrDefault(folder+"top",10)
//		Variable right=NumVarOrDefault(folder+"right",800)
//		Variable bottom=NumVarOrDefault(folder+"bottom",600)
//		variable axisMax=NumVarOrDefault(folder+"axisMax",2500)
//		variable axisMin=NumVarOrDefault(folder+"axisMin",-2500)
		Display /K=1/W=(left,top,right,bottom)/N=$win as "Seal Test"
	endif
	SetWindow $win userData(DAQ)=DAQ 
	
//	if(!DataFolderExists("root:sealtest"))
//		return -1
//	endif
//	SetDataFolder root:sealtest
	nvar /sdfr=df chanBits
	variable numChannels=GetNumChannels(DAQ=DAQ)
	wave /t Labels=GetChanLabels()
	if(chanBits<1)
		return -1
	endif
	
	Variable xStart=0,yStart=0,xJump=0,yJump=25,xx=xStart,yy=yStart
	Variable i,count=0; String modes,mode="",sweepAxes=""
	for(i=0;i<numChannels;i+=1)
		if(chanBits & 2^i) // Seal test requested on this channel.  
			dfref chanDF=SealTestChanDF(i)
			String channel=num2str(i)
			mode=GetAcqMode(i)
			variable red,green,blue
			GetChanColor(i,red,green,blue)
			string sweepAxis="chan"+channel+"_axis"
			sweepAxes+=sweepAxis+";"
			AppendToGraph /L=$sweepAxis /C=(red,green,blue) chanDF:sweep
			ModifyGraph freepos($sweepAxis)={0,kwFraction}, btlen=3
			AppendToGraph /T=InputHistoryTaxis /R=InputHistoryAxis /C=(red,green,blue) chanDF:inputHistory vs df:thyme
			AppendToGraph /T=SeriesHistoryTaxis /R=SeriesHistoryAxis /C=(red,green,blue) chanDF:seriesHistory vs df:thyme
			AppendToGraph /T=PressureHistoryTaxis /R=PressureHistoryAxis /C=(red,green,blue) chanDF:pressureHistory vs df:thyme
			AppendToGraph /T=TimeConstantHistoryTaxis /R=TimeConstantHistoryAxis /C=(red,green,blue) chanDF:timeConstantHistory vs df:thyme
			String resistanceTitle,pressureTitle
			sprintf resistanceTitle,"\K(%d,%d,%d)"+"M\F'Symbol'W ",red,green,blue
			sprintf pressureTitle,"\K(%d,%d,%d)"+"mBar ",red,green,blue
			Button $("Zap_"+channel) title="Zap", pos={5,10+count*yJump}, size={30,20}, proc=SealTestWinButtons
			SetVariable $("ZapDuration_"+channel) title=" ", help={"Zap duration in ms"}, pos={38,12+count*yJump}, size={35,20}, limits={0.5,50,0.5}, value=_NUM:5
			
			string valName="inputRes_"+channel
			ValDisplay $valName pos={75,8+count*yJump}, format="%.1f", fsize=18, disable=0
			ValDisplay $valName bodywidth=60, size={100,30}, title=resistanceTitle, value=#JoinPath({getdatafolder(1,chanDF),"inputRes"})
			ValDisplay $("Aux_"+channel) pos={565,11}, format="%.1f", fsize=14, disable=1
			
			Button $("Baseline_"+channel) title="Baseline", pos={185,10+count*yJump}, proc=SealTestWinButtons
			SetVariable $("Range_"+channel) title="Range", pos={242,12+count*yJump}, size={85,20}, value=_NUM:1200, limits={200,2000,200}, proc=SealTestWinSetVariables
			//SetVariable $("Threshold_"+channel) title="Thresh %", pos={252,12+count*yJump}, size={85,20}, value=_NUM:0, proc=SealTestWinSetVariables
			valName="seriesRes_"+channel
			//ValDisplay $valName pos={855,8+count*yJump}, format="%.1f", fsize=18, disable=2
			//ValDisplay $valName bodywidth=100, size={100,30}, title=resistanceTitle,value=#JoinPath({getdatafolder(1,chanDF),"seriesRes"})
			valName="timeConstant_"+channel
			//ValDisplay $valName pos={855,8+count*yJump}, format="%.1f", fsize=18, disable=2
			//ValDisplay $valName bodywidth=100, size={100,30}, title="ms",value=#JoinPath({getdatafolder(1,chanDF),"timeConstant"})
			valName="pressure_"+channel
			//ValDisplay $valName pos={855,8+count*yJump}, format="%.1f", fsize=18, disable=2
			//ValDisplay $valName bodywidth=100, size={100,30}, title=pressureTitle,value=#JoinPath({getdatafolder(1,chanDF),"pressure"})
			Button $("ZeroPressure_"+channel), proc=SealTestWinButtons, title="Zero"
			string inputUnits=GetModeInputUnits(mode)
			
			Label $sweepAxis inputUnits
			if(abs(axisMin-axisMax)>0)  
				SetAxis $sweepAxis axisMin,axisMax
			else
				SetAxis /A $sweepAxis
			endif
			count+=1
		endif
	endfor
	
	ControlBar /T 40+(count-1)*yJump
	SetAxis /A/R InputHistoryTaxis// (0.5*(+100)/freq),(0.5*(-100)/freq)
	SetAxis /A/R SeriesHistoryTaxis// (0.5*(+100)/freq),(0.5*(-100)/freq)
	SetAxis /A/R TimeConstantHistoryTaxis// (0.5*(+100)/freq),(0.5*(-100)/freq)
	SetAxis /A/R PressureHistoryTaxis// (0.5*(+100)/freq),(0.5*(-100)/freq)
	SetWindow SealTestWin hook=SealTestHook, hookevents=1 // mouse down events
	//Wave AcqMode=root:parameters:AcqMode
	//AcqMode[
	if(RestoreAxes("View",win=win))	
		SetAxis /A/R/Z inputHistoryTaxis 
		SetAxis /A/R/Z seriesHistoryTaxis
		SetAxis /A/R/Z pressureHistoryTaxis
		SetAxis /A/R/Z timeConstantHistoryTAxis
		SetAxis /Z inputHistoryAxis 1,2000
		SetAxis /Z seriesHistoryAxis 1,200
		SetAxis /Z pressureHistoryAxis -25,250
		SetAxis /Z timeConstantHistoryAxis 0.1,100
	endif
	ModifyGraph /Z log(inputHistoryAxis)=1, log(seriesHistoryAxis)=1, log(timeConstantHistoryAxis)=1//, log(pressureHistoryAxis)=1
	for(i=0;i<count;i+=1)
		sweepAxis=stringfromlist(i,sweepAxes)
		modifygraph /Z axisEnab($sweepAxis)={0.6*i/count,0.6*(i+1)/count-(count>0)*0.03}, lblPos($sweepAxis)=50
	endfor
	ModifyGraph /Z axisEnab(inputHistoryAxis)={0.62,1}, axisEnab(seriesHistoryAxis)={0.62,1}, axisEnab(pressureHistoryAxis)={0.62,1}, axisEnab(timeConstantHistoryAxis)={0.62,1}
	ModifyGraph freePos(inputHistoryAxis)=0, freePos(inputHistoryTaxis)=-15
	ModifyGraph freePos(inputHistoryAxis)=0, freePos(seriesHistoryTaxis)=-15, freePos(pressureHistoryTaxis)=-15, freePos(timeConstantHistoryTAxis)=-15
	ModifyGraph /Z lblPos(inputHistoryAxis)=60, lblPos(seriesHistoryAxis)=60, lblPos(pressureHistoryAxis)=60, lblPos(timeConstantHistoryAxis)=42
	ModifyGraph nticks(inputHistoryTaxis)=0,axThick(inputHistoryTaxis)=0
	ModifyGraph nticks(seriesHistoryTaxis)=0,axThick(seriesHistoryTaxis)=0
	ModifyGraph nticks(timeConstantHistoryTaxis)=0,axThick(timeConstantHistoryTaxis)=0
	ModifyGraph nticks(pressureHistoryTaxis)=0,axThick(pressureHistoryTaxis)=0,btlen=2
	//ModifyGraph live=1
	Label inputHistoryAxis "Seal (M\\F'Symbol'W\\F'Default')"
	Label /Z seriesHistoryAxis "Series (M\\F'Symbol'W\\F'Default')"
	Label /Z timeConstantHistoryAxis "Time Constant (ms)"
	Label /Z pressureHistoryAxis "Pressure (mBar)"
	xx=335; yy=10
	GroupBox Controls frame=1, pos={xx,yy-5}, size={505,30}, title=""
	xx+=5
	PopupMenu Channels, pos={xx,yy}, userData(selected)=ChannelList(chanBits),mode=0, title="Channels",proc=SealTestWinPopupMenus
	PopupMenu Channels, value=#("PopupOptions(\"\",\"Channels\",ChannelCombos(\"sealtest\",\"\"),selected=ChannelList("+num2str(chanBits)+"))")
	xx+=90
	wave /sdfr=df ampl
	nvar /sdfr=instanceDF gridOn,seriesOn,pressureOn,timeConstantOn
	SetVariable Ampl,pos={xx,yy+2},size={60,20},value=ampl[0],proc=SealTestWinSetVariables,title="Ampl"
	xx+=65
	SetVariable Freq,pos={xx,yy+2},size={60,20},limits={0.1,20,1}, value=freq,proc=SealTestWinSetVariables,title="Freq"
	xx+=135
	Checkbox Grid, pos={xx,yy+3},variable=gridOn, title="Grid",proc=SealTestWinCheckboxes
	xx+=50
	Checkbox Series, pos={xx,yy+3},variable=seriesOn, title="Series",proc=SealTestWinCheckboxes
	xx+=50
	Checkbox TimeConstant, pos={xx,yy+3},variable=timeConstantOn, title="Tau",proc=SealTestWinCheckboxes
	xx+=50
	Checkbox Pressure, pos={xx,yy+3},variable=pressureOn, title="Pressure",proc=SealTestWinCheckboxes
	
	Struct WMCheckboxAction info
	info.ctrlName="Series"; info.checked=seriesOn; info.userData="noRestart"
	SealTestWinCheckboxes(info)
	info.ctrlName="TimeConstant"; info.checked=timeConstantOn; info.userData="noRestart"
	SealTestWinCheckboxes(info)
	info.ctrlName="Pressure"; info.checked=pressureOn; info.userData="noRestart"
	SealTestWinCheckboxes(info)
	
	// Axes are screwed up for some reason unless you force an update and do something (anything) to the graph.  
	DoUpdate
	Execute /Q/Z "SetAxis /W="+win+" /A bottom"
End

Function SealTestWinButtons(ctrlName)
	String ctrlName
	
	String channel=StringFromList(ItemsInList(ctrlName,"_")-1,ctrlName,"_")
	String action=RemoveEnding(ctrlName,"_"+channel)
	dfref df=SealTestDF()
	variable chan=str2num(channel)
	dfref chanDF=SealTestChanDF(chan)
	strswitch(action)
		case "Zap":
			Variable /G df:zap=2^str2num(channel)
			break
		case "Baseline":
			SealTestTracker(chan,1)
			break
		case "ZeroPressure":
			nvar /sdfr=chanDF supplyVolts
			wave /sdfr=chanDF pressureSweep
			WaveStats /Q/M=1 pressureSweep
			supplyVolts=5*V_avg/offsetAt5volts
			break
	endswitch
End

Function SealTestWinPopupMenus(info)
	Struct WMPopupAction &info
	
	if(!PopupInput(info.eventCode))
		return 0
	endif
	strswitch(info.ctrlName)
		case "Channels":
			SealTestEnd(noStore=1)
			Variable chanBits=0
			String channels=info.popStr
			Variable i
			if(!strlen(channels) || stringmatch(channels," "))
				break
			endif
			for(i=0;i<ItemsInList(channels,",");i+=1)
				String channel=StringFromList(i,channels,",")
				Variable chan=Label2Chan(channel)
				chanBits+=2^chan
			endfor
			//PopupMenu $info.ctrlName userData(selected)=info.popStr, win=$info.win
			SealTest(chanBits)
			break
	endswitch
End

Function SealTestWinCheckboxes(info)
	Struct WMCheckboxAction &info
	
	if(info.eventCode<0)
		return -1
	endif
	String DAQ=GetUserData(info.win,"","DAQ")
	dfref df=SealTestDF()
	dfref daqDF=GetDaqDF(DAQ)
	strswitch(info.ctrlName)
		case "Pulse":
			svar /sdfr=daqDF outputWaves
			if(info.checked)
				outputWaves=ReplaceString("nullPulse",outputWaves,"pulse")
			else
				outputWaves=ReplaceString("pulse",outputWaves,"nullPulse")
			endif
			if(info.checked)
				Label InputHistoryAxis "Seal (M\\F'Symbol'W\\F'Default')"
			else
				svar /sdfr=df modes
				string mode=StringFromList(0,modes) // Use the mode of the first channel in this seal test.  
				string inputUnits=GetModeInputUnits(mode)
				Label InputHistoryAxis "RMS Noise ("+inputUnits+")"
			endif
			SealTestStart(1,DAQ)
			break
		case "Grid":
			variable i
			string axes=AxisList(info.win)
			string sweepaxes=listmatch(axes,"chan*")
			for(i=0;i<itemsinlist(sweepAxes);i+=1)
				string sweepAxis=stringfromlist(i,sweepAxes)
				ModifyGraph grid($sweepAxis)=info.checked
			endfor
			break
		case "Series":
			SealTestAuxMeasurement("Series",info.checked)
			if(info.checked)
				SealTestAuxMeasurement("Pressure",0)
				SealTestAuxMeasurement("TimeConstant",0)
			endif
			break
		case "TimeConstant":
			SealTestAuxMeasurement("TimeConstant",info.checked)
			if(info.checked)
				SealTestAuxMeasurement("Series",0)
				SealTestAuxMeasurement("Pressure",0)
			endif
			break
		case "Pressure":
			SealTestAuxMeasurement("Pressure",info.checked)
			if(info.checked)
				SealTestAuxMeasurement("Series",0)
				SealTestAuxMeasurement("TimeConstant",0)
			endif
			//SealTestInput
			//nvar /sdfr=DAQdf numChannels
			//nvar /sdfr=df chanBits
			
			//for(i=0;i<numChannels;i+=1)
			//	if(chanBits & 2^i) // Seal test requested on this channel.  
			//		SealTestInput(i)
			//	endif
			//endfor
			if(!stringmatch(info.userData,"noRestart"))
				SealTestInputsAndOutputs(DAQ)
				SealTestStart(1,DAQ)
				//RestartSealTest(DAQ)
			endif
			break
	endswitch
End

Function SealTestAuxMeasurement(measurement,value)
	String measurement
	Variable value
	
	if(!value)
		Checkbox $measurement, value=0
	endif
	String DAQ=GetUserData("","","DAQ")
	variable num_channels=GetNumChannels(DAQ=DAQ)
	dfref df=SealTestDF()
	nvar /sdfr=df chanBits
	svar instance = df:instance
	dfref instanceDF = df:$instance
	String traces=TraceNameList("",";",1)
	Variable i,j
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace=StringFromList(i,traces)
		if(StringMatch(trace,measurement+"*"))
			ModifyGraph hideTrace($trace)=!value
		endif
	endfor
	String controls=ControlNameList("",";",measurement+"*")
	for(i=0;i<ItemsInList(controls);i+=1)
		String control=StringFromList(i,controls)
		if(!StringMatch(control,measurement))
			ModifyControl $control disable=!value
		endif
	endfor
	ModifyGraph tick($(measurement+"HistoryAxis"))=0*(value),noLabel($(measurement+"HistoryAxis"))=2*(!value),axThick($(measurement+"HistoryAxis"))=value
	
	nvar /sdfr=instanceDF pressureOn
	ModifyControlList controlnamelist("",";","zero*") disable=!pressureOn
	ModifyControlList controlnamelist("",";","Aux_*") disable=1
	
	string auxes = "series;timeConstant;pressure"
	variable any_aux = 0
	for(i=0;i<itemsinlist(auxes);i+=1)
		string aux = stringfromlist(i,auxes)
		nvar /sdfr=instanceDF on=$(aux+"On")		
		any_aux += on
		if(on)
			ModifyGraph axisEnab(inputHistoryTAxis)={0,0.45},axisEnab($(aux+"HistoryTAxis"))={0.55,1}
			ModifyGraph freePos(inputHistoryAxis)={0.55,kwFraction},freePos($(aux+"HistoryAxis"))={0,kwFraction}
			for(j=0;j<num_channels;j+=1)
				if(chanBits & 2^j) // Seal test requested on this channel.  
					dfref chanDF=SealTestChanDF(j)
					string channel=num2str(j)
					string var_name = aux
					if(stringmatch(aux,"series"))
						var_name = "seriesRes"
					endif
					ValDisplay $("Aux_"+channel) value=#JoinPath({getdatafolder(1,chanDF),var_name}), disable=0
				endif
			endfor
		else
			ModifyGraph freePos($(aux+"HistoryAxis"))={0.1,kwFraction} // Move it away so it is not overlapping the visible axis.  
		endif
	endfor		
	if(!any_aux)
		ModifyGraph axisEnab(inputHistoryTAxis)={0,1}
		ModifyGraph freePos(inputHistoryAxis)={0,kwFraction}
		//ModifyGraph axisEnab(inputHistoryTAxis)={0,0.45},axisEnab(seriesHistoryTAxis)={0.55,0.75},axisEnab(pressureHistoryTAxis)={0.8,1}
		//ModifyGraph freePos(inputHistoryAxis)={0.55,kwFraction},freePos(seriesHistoryAxis)={0.25,kwFraction},freePos(pressureHistoryAxis)={0,kwFraction}
	endif
	//NVar sealTestOn=root:sealtest:sealTestOn
	//if(sealTestOn) // If a seal test is running, restart it.  
	//	SealTestStart(1,DAQ)
	//endif
End

Function SealTestWinSetVariables(info)
	Struct WMSetVariableAction &info
	
	if(!SVInput(info.eventCode))
		return 0
	endif
	
	String DAQ=GetUserData(info.win,"","DAQ")
	dfref df=SealTestDF()
	String channel=StringFromList(ItemsInList(info.ctrlName,"_")-1,info.ctrlName,"_")
	variable chan=str2num(channel)
	String action=RemoveEnding(info.ctrlName,"_"+channel)
	variable numChannels=GetNumChannels(DAQ=DAQ)
	strswitch(action)
		case "Ampl":
			wave /T Labels=GetChanLabels()
			wave /sdfr=df Ampl
			Ampl=info.dval
			nvar /sdfr=df chanBits
			variable i
			for(i=0;i<numChannels;i+=1)
				if(chanBits & 2^i)
					dfref chanDF=SealTestChanDF(i)
					wave /sdfr=chanDF Pulse,BasePulse
					duplicate /o BasePulse chanDF:Pulse /wave=Pulse
					Pulse*=Ampl[i]
				endif
			endfor
			if(info.dval==0)
				Label InputHistoryAxis "Noise"
			else
				Label InputHistoryAxis "Seal (M\\F'Symbol'W\\F'Default')"
			endif
			SealTestStart(1,DAQ)
			break
		case "Freq":
			variable freq=info.dval
			nvar /sdfr=df chanBits
			for(i=0;i<numChannels;i+=1)
				if(chanBits & 2^i)
					dfref chanDF=SealTestChanDF(i)
					wave /sdfr=chanDF Pulse,Sweep,PressureSweep
					SetScale x,0,1/freq,"s",Pulse,Sweep,PressureSweep
				endif
			endfor
			SetAxis bottom 0,1/freq
			SealTestStart(1,DAQ)
			break
		case "Threshold":
			SealTestTracker(chan,0)
			break
		case "Range":
			dfref chanDF=SealTestChanDF(chan)
			wave /sdfr=chanDF Sweep
			variable center=statsmedian(Sweep)
			variable range = info.dval
			variable high = center + range/2
			variable low = center - range/2
			string axes=AxisList("SealTestWin")
			string sweepAxis="chan"+num2str(chan)+"_axis"
			SetAxis $sweepAxis,low,high
			break
	endswitch
End

Function SealTestTracker(chan,updateBaseline)
	variable chan
	Variable updateBaseline
	
	string channel=num2str(chan)
	dfref df=SealTestDF()
	dfref chanDF=SealTestChanDF(chan)
	wave /z/sdfr=chanDF Baseline
	if(updateBaseline || !waveexists(Baseline))
		Duplicate /o chanDF:InputHistory chanDF:Baseline /WAVE=Baseline
		Wavestats /Q/R=[0,10] chanDF:InputHistory
		Baseline=V_avg
		
		// Rescale response axis.  
		wave /z/sdfr=chanDF Sweep
		StatsQuantiles /Q Sweep
		string axes=AxisList("SealTestWin")
		string sweepaxes=listmatch(axes,"chan*")
		variable i
		string sweepAxis = "chan"+num2str(chan)+"_axis"
		variable center = v_median
		ControlInfo $("Range_"+num2str(chan))
		variable range = v_value
		variable low = center - range/2
		variable high = center + range/2
		SetAxis $sweepAxis,low,high
	endif
	Duplicate /o chanDF:InputHistory, chanDF:Threshold /WAVE=Threshold 
	ControlInfo $("Threshold_"+channel); Variable thresh=V_Value
	Threshold=Baseline[0]*(1+thresh/100)
	RemoveFromGraph /Z $NameOfWave(Baseline),$NameOfWave(Threshold)
	wave /sdfr=df Thyme
	AppendToGraph /R=InputHistoryAxis /T=InputHistoryTAxis /c=(0,0,0) Baseline,Threshold vs Thyme
	ModifyGraph lstyle($NameOfWave(Threshold))=2
	variable /g df:thresholdCrossed=0
	nvar /sdfr=df thresholdOn
	thresholdOn=thresholdOn | 2^chan
End

Function IsSealTestOn()
	nvar /z/sdfr=SealTestDF() sealTestOn
	return (nvar_exists(sealTestOn) && sealTestOn) ? 1 : 0
End

Function SealTestStart(reset,DAQ)
	Variable reset
	String DAQ
	//return 0
	
	if(reset)
		StopClock(DAQs=DAQ)
		ZeroAll(DAQs=DAQ)
		if(StringMatch(DAQ,"NIDAQmx"))
			BoardReset(1,DAQs=DAQ) // For some reason the NIDAQ also needs this.  
		endif
	endif
	
	// Start the seal test.  
	SetupTriggers(6) // Irrelevant except for pre-MX NIDAQ boards.  

	dfref daqDF=GetDaqDF(DAQ)
	dfref df=SealTestDF()
	svar instance = df:instance
	dfref instanceDF = df:$instance
	string /g daqDF:listenHook
	svar /sdfr=daqDF inputWaves,outputWaves,listenHook
	nvar /sdfr=df chanBits
	nvar /sdfr=instanceDF freq
	SetListenHook("SealTestCollectSweeps(\"_daq_\")",DAQ=DAQ)
	Speak(1,outputWaves,0,DAQs=DAQ)
	Listen(1,1,inputWaves,5,1,listenHook,"ErrorHook()","",DAQs=DAQ)
	StartClock(1/freq,DAQs=DAQ) // Includes starting stimulation.  
End

Function SealTestZap(OutputMultiplex,DAQ)
	wave OutputMultiplex
	string DAQ
	
	dfref df=SealTestDF()
	nvar /sdfr=df zap
	if(zap)
		ControlInfo /W=SealTestWin $("ZapDuration_0")
		variable zapDuration=V_Value
		svar /sdfr=df sealTestChannels=channels
		Variable numSealTestChannels=ItemsInList(sealTestChannels)
		nvar /sdfr=df freq
		
		variable zapChannel=round(log(zap)/log(2))
		variable zapPoints=zapDuration*freq*SealTestPoints(DAQ)/1000
		strswitch(DAQ)
			case "ITC":
				zapPoints*=numSealTestChannels
				OutputMultiplex[zapChannel,zapPoints/2-1;numSealTestChannels]+=32000
				OutputMultiplex[zapChannel+zapPoints/2,zapPoints-1;numSealTestChannels]-=32000
				break
			case "LIH":
				variable i
				for(i=0;i<dimsize(OutputMultiplex,0);i+=SealTestPoints(DAQ))
					OutputMultiplex[i,i+zapPoints/2-1][zapChannel]=32000*(zap>0 && i==0)
					OutputMultiplex[i+zapPoints/2,i+zapPoints-1][zapChannel]=-32000*(zap>0 && i==0)
				endfor
				break
		endswitch
		zap=(zap>0) ? -1 : 0
	endif
End

Function SealTestCollectSweeps(DAQ)
	String DAQ
	
	dfref daqDF=GetDaqDF(DAQ)
	dfref df=SealTestDF()
	svar instance = df:instance
	dfref instanceDF = df:$instance
	nvar /sdfr=df chanBits,iteration
	nvar /sdfr=instanceDF freq
	svar /sdfr=daqDF inputWaves,outputWaves
	wave /sdfr=df Ampl
	InDemultiplex(inputWaves)
	
	variable numChannels=GetNumChannels(DAQ=DAQ)
	iteration+=1
	
	FuncRef Speak DAQ_Speak=$(DAQType(DAQ)+"#Speak")
	//if(!stringmatch(DAQ,"LIH"))
	//	DAQ_Speak(1,outputWaves,64,now=1) // Add the next stimulus to the stimulus buffer.  (ITC18 only).  
	//endif
	Variable i,minn=Inf,maxx=-Inf
	for(i=0;i<numChannels;i+=1)
		if(chanBits & 2^i)
			string mode=GetAcqMode(i)
			dfref chanDF=SealTestChanDF(i)
			//string channel=num2str(i)
			wave /sdfr=chanDF Sweep,InputHistory,SeriesHistory,TimeConstantHistory,PressureHistory
			nvar /sdfr=chanDF inputRes,seriesRes,timeConstant,pressure
			variable inputGain=GetModeInputGain(mode)
		
			String DAQType=Chan2DAQ(i)
			if(StringMatch(DAQType,"NIDAQnonMX")) // pre-MX NIDAQ driver.  
				sweep *= (1000/inputGain)/32 // Is this right?  
			endif
			ControlInfo /W=SealTestWin Pulse; Variable pulse=V_Value
			if(Ampl[i]==0) // Noise Test
				WaveStats /Q Sweep
				inputRes=V_sdev // Compute RMS noise
				seriesRes=V_adev
			else // Seal Test
				string outputType=GetModeOutputType(mode,fundamental=1)
				string inputType=GetModeInputType(mode,fundamental=1)
				if(stringmatch(outputType,"Current"))
					variable in=abs(mean(sweep,0.20/freq,0.24/freq)-mean(sweep,0.70/freq,0.74/freq))
				else
					in=abs(mean(sweep,0.29/freq,0.49/freq)-mean(sweep,0.6233/freq,0.8233/freq))
				endif
				variable out=abs(2*Ampl[i])
				variable ratioFactor=UnitsRatio(GetModeOutputPrefix(mode),GetModeInputPrefix(mode))
				variable ratio=ratioFactor*out/in
				string ratioString=outputType+"/"+inputType
				if(stringmatch(ratioString,"Current/Voltage"))
					ratio=1/ratio // Convert from Siemens to Ohms.  
				elseif(stringmatch(ratioString,"Voltage/Current"))
					// Keep in Ohms.  
				else
					ratio=NaN
				endif
				inputRes=ratio/1e6 // Convert from Ohms to Megaohms.  
				nvar /sdfr=instanceDF seriesOn,timeConstantOn
				//ControlInfo /W=SealTestWin Series
				if(seriesOn && stringmatch(ratioString,"Voltage/Current"))
					Variable baseline=mean(sweep,0.01/freq,(1/6 - 0.01)/freq)
					Variable peak=WaveMin(sweep,(1/6 - 0.01)/freq,(1/6 + 0.01)/freq)
					Variable diff2=abs(peak-baseline)
					seriesRes=1000*Ampl[i]/diff2
				else
					seriesRes=NaN
				endif
				if(timeConstantOn)
					wavestats /q/m=1 sweep
					variable v_fitoptions=4
					variable start = x2pnt(sweep,v_minloc+0.005)
					variable finish = x2pnt(sweep,v_minloc+0.02)
					if(finish-start>10 && sweep[start])
						curvefit /q exp sweep[start,finish]
						timeConstant = 1000/K2
					else
						timeConstant = NaN
					endif
				else
					timeConstant = NaN
				endif
			endif
			
			nvar /sdfr=instanceDF pressureOn
			if(pressureOn)
				variable pressureChan=str2num(Chan2ADC(i))+4 // Assumes pressure sensor hooked up 4 ADC channels away from the patch signal.  
				wave /sdfr=chanDF pressureSweep
				variable volts=mean(PressureSweep)
				nvar /sdfr=chanDF supplyVolts // Should be a constant.  Equals 9 for a new 9 volt battery.  
				Variable voltsPerPSI=supplyVolts*VoltsPerPSIat5volts/5 // Spec sheet for pressure sensor ASCX05DN says 0.9 V/psi for a 5 volt supply.  
				Variable nullOffset=supplyVolts*offsetAt5Volts/5 // Voltage when the pressure is zero.  Spec sheet for ASCX05DN says 0.25 V for a 5 volt supply.  
				pressure=(mBarPerPSI/voltsPerPSI)*(volts-nullOffset) // Computes pressure in mbar.  Assumes 9 volt battery hooked up to pressure sensor ASCX05DN, with unity DAQ gain.  
				// Positive pressure is a positive number by the calculation used here and the electrode pressure port hooked up to port B on the sensor.  
				if(pressure>100 && WinType("SuperClampWin"))
					if(SuperClampGetV(i))
						SuperClampSetV(i,0)
					endif
					if(SuperClampGetI(i))
						SuperClampSetI(i,0)
					endif
				endif
			endif
			
#if(exists("Sutter#Init"))
			if(WinType("LogPanel"))
				String sutterMove=GetUserData("LogPanel","Sutter_Move","")
				nvar /sdfr=df thresholdCrossed
				wave /z/sdfr=chanDF Threshold
				if(!thresholdCrossed && ((WaveExists(Threshold) && inputRes>Threshold[0]) || pressure<0))
					//if(StringMatch(sutterMove,"Stop"))
						Sutter#Stop()
					//endif
					Beep
					thresholdCrossed=1
				endif
			endif
#endif
			
			if(iteration>0)
				Rotate 1, InputHistory,SeriesHistory,TimeConstantHistory,PressureHistory
				//SetScale /P x,0,1, InputHistory,SeriesHistory
				InputHistory[0]=inputRes
				SeriesHistory[0]=seriesRes
				TimeConstantHistory[0]=timeConstant
				PressureHistory[0]=pressure
			endif
			if(0) // Autoscale.  TODO: Make into a checkbox preference.  
				WaveStats /Q/M=1 Sweep
				minn=min(minn,V_min)
				maxx=max(maxx,V_max)
			endif
		endif
	endfor
	if(0) // Autoscale.  Only autoscales to the last channel in the seal test window.  
		Variable center=(minn+maxx)/2
		string axes=AxisList("SealTestWin")
		string sweepaxes=listmatch(axes,"chan*")
		for(i=0;i<itemsinlist(sweepAxes);i+=1)
			string sweepAxis=stringfromlist(i,sweepAxes)
			SetAxis $sweepAxis,center-(center-minn)*1.5,center+(maxx-center)*1.5
		endfor
	endif
End

Function SealTestHook(infostr)
	String infostr
	String event=StringByKey("EVENT",infoStr)
	
	strswitch(event)
		case "killVote":
			//
			break
		case "kill":
			dfref df=SealTestDF()
			
			// Store the seal test window coordinates.  
			struct rect coords
			Core#GetWinCoords("SealTestWin",coords)
			string DAQ=GetUserData("SealTestWin","","DAQ")
			variable /g df:left=coords.left, df:top=coords.top, df:right=coords.right, df:bottom=coords.bottom
			
			// Store the seal test sweep axis range.  
			variable i=0
			do
				GetAxis /Q $("chan"+num2str(i)+"_axis")
				i+=1
			while(i<100 && numtype(v_min)>0)
			SaveAxes("View",win="SealTestWin")
			variable modifiers=NumberByKey("MODIFIERS",infoStr) // 1 if it is programatically killed, 0 if it is killed by a mouse click.  
			SealTestEnd(noStore=modifiers,DAQ=DAQ)
			break
	endswitch
	SetDataFolder root:
End

Function SealTestEnd([noStore,DAQ])
	Variable noStore // Do not store information about this seal test.  
	String DAQ
	
	if(ParamIsDefault(DAQ) || strlen(DAQ)==0)
		DAQ=GetUserData("","","DAQ")
	endif
	StopClock(DAQs=DAQ)
	ZeroAll(DAQs=DAQ)
	dfref df=SealTestDF()
	nvar /z/sdfr=df sealtestOn,thresholdOn,sealTestT
	svar /z/sdfr=df channels // Channels on which a seal test was occurring at the time the window was closed.  
	
	sealtestOn=0
	DoWindow /K SealTestWin
	
	if(!noStore)
		// Store information about this seal test in its own subfolder.  
		variable i=0
		do
			dfref history=df:$("Seal_"+num2str(i))
			i+=1
		while(datafolderrefstatus(history))
		NewDataFolder /O df:$("Seal_"+num2str(i-1))
		dfref history=df:$("Seal_"+num2str(i-1))
		String waves=Core#Dir2("WAV",df=df,match="*History*")
		
		for(i=0;i<ItemsInList(channels);i+=1)
			string channel=StringFromList(i,channels)
			if(strlen(channel))
				variable chan=str2num(channel)
				dfref chanDF=SealTestChanDF(chan)
				string dest="ch"+channel
				newdatafolder /o history:$dest
				dfref destDF=history:$dest
				wave /sdfr=chanDF InputHistory,SeriesHistory
				if(wavemax(InputHistory))
					Duplicate /o chanDF:InputHistory destDF:InputHistory
				endif
				if(wavemax(SeriesHistory))
					Duplicate /o chanDF:SeriesHistory destDF:SeriesHistory
				endif
				if(thresholdOn & 2^str2num(channel))
					wave /sdfr=chanDF Threshold
					variable /g destDF:Threshold=Threshold[0]
				endif
				variable /g destDF:sealTestT=sealTestT/60
			endif
		endfor
	endif
End



