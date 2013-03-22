
// $Author: rick $
// $Rev: 508 $
// $Date: 2011-02-16 15:57:32 -0500 (Wed, 16 Feb 2011) $

#pragma rtGlobals=1		// Use modern global access method.

Function SuperClamp()
	if(WinType("SuperClampWin"))
		DoWindow /F SuperClampWin
	else
		NewPanel /K=2 /N=SuperClampWin /W=(100,100,500,400) as "Super Clamp Commodore"
	endif
	DFRef currFolder=GetDataFolderDFR()
	NewDataFolder /O root:Packages
	NewDataFolder /O root:Packages:SuperClamp
	DFRef f=root:Packages:SuperClamp
	Variable low=-50, high=50
	Make /o/n=3 f:TickValues /WAVE=TickValues={low,0,high}
	Make /o/T/n=3 f:TickLabels={num2str(low)+" mV","0",num2str(high)+" mV"}
	Variable i,j,row=1,numChannels=GetNumChannels()
	String validChannels=""
	TitleBox OnTitle, pos={3,3}, title="On"
	TitleBox CommandTitle, pos={100,3},title="Command"
	TitleBox OffsetTitle, pos={242,3},title="Offset"
	for(i=0;i<numChannels;i+=1)
		if(WhichListItem(GetInputType(i),"Voltage;Current")>=0)
			ControlInfo $("Command_"+num2str(i))
			
			if(!V_flag) // No controls for this channel, so create them and intialize their values to zero.  
				Titlebox $("Title_"+num2str(i)), size={100,25}, win=SuperClampWin
				Checkbox $("Hold_"+num2str(i)) size={100,25}, value=0, proc=SuperClampCheckboxes, win=SuperClampWin
				SetVariable $("CommandMV_"+num2str(i)), size={65,25}, value=_NUM:0, limits={-Inf,Inf,5}, proc=SuperClampSetVariables, win=SuperClampWin
				SetVariable $("CommandPA_"+num2str(i)), size={65,25}, value=_NUM:0, limits={-Inf,Inf,5}, proc=SuperClampSetVariables, win=SuperClampWin
				Slider $("Offset_"+num2str(i)),size={100,25},limits={low,high,0.25},fsize=7,vert=0,title="Offset",userTicks={f:TickValues,f:TickLabels},win=SuperClampWin
			endif
			
			// Update control positions, units, and titles.  
			Variable red,green,blue
			GetChanColor(i,red,green,blue)
			String titleStr
			sprintf titleStr,"\K(%d,%d,%d)%s",red,green,blue,Chan2Label(i)
			Checkbox $("Hold_"+num2str(i)) pos={5,row*25+5},title=titleStr, win=SuperClampWin
			SetVariable $("CommandMV_"+num2str(i)) pos={65,row*25+5},title="mV", win=SuperClampWin
			SetVariable $("CommandPA_"+num2str(i)) pos={140,row*25+5},title="pA", win=SuperClampWin
			Slider $("Offset_"+num2str(i)) pos={220,row*25+2},win=SuperClampWin
			validChannels+=num2str(i)+";"
		else
			// Kill old controls for channels that no longer have the right acquisition mode.  
			String controls=ControlNameList("",";","*_"+num2str(i))
			for(j=0;j<ItemsInList(controls);j+=1)
				String controlName=StringFromList(j,controls)  
				KillControl /W=SuperClampWin $controlName
			endfor
		endif
		row+=1
	endfor
	SetDataFolder currFolder
End

Function SuperClampSetVariables(info)
	Struct WMSetVariableAction &info
	
	if(info.eventCode<0)
		return -1
	endif
	String name=StringFromList(0,info.ctrlName,"_")
	Variable chan=str2num(StringFromList(1,info.ctrlName,"_"))
	strswitch(name)
		case "CommandMV":
		case "CommandPA":
			ControlInfo /W=SuperClampWin $("Hold_"+num2str(chan))
			SuperClampSet(chan,V_Value)
			break
	endswitch
End

Function SuperClampCheckboxes(ctrlName,val)
	String ctrlName
	Variable val
	
	String name=StringFromList(0,ctrlName,"_")
	Variable chan=str2num(StringFromList(1,ctrlName,"_"))
	strswitch(name)
		case "Hold":
			SuperClampSet(chan,val)
			break
	endswitch
End

Function /S SuperClampSet(chan,on[,writeToDAQ])
	Variable chan,on,writeToDAQ
	
	writeToDAQ=ParamIsDefault(writeToDAQ) ? 1 : writeToDAQ
	Variable outputGain=GetOutputGain(chan,Inf)
	String outputUnits=GetOutputUnits(chan)
	Variable output=0
	
	// Check to see if mV command is set and this channel is in a mode where a mV command can be given.  
	Variable conversionFactor_=ConversionFactor("mV",outputUnits)
	if(conversionFactor_)
		ControlInfo /W=SuperClampWin $("CommandMV_"+num2str(chan))
		output=V_Value*conversionFactor_
	endif
	
	// Check to see if pA command is set and this channel is in a mode where a pA command can be given.  
	conversionFactor_=ConversionFactor("pA",outputUnits)
	if(conversionFactor_)
		ControlInfo /W=SuperClampWin $("CommandPA_"+num2str(chan))
		output=V_Value*conversionFactor_
	endif
	
	output=(0.001*output)/outputGain
	string DAC=Chan2DAC(chan)
	String DAQ=Chan2DAQ(chan)
	dfref daqDF=GetDaqDF(DAQ)
	NVar acquiring=daqDF:acquiring
	if(!numtype(str2num(DAC)) && writeToDAQ && !acquiring)
		Write(str2num(DAC),output,DAQs=DAQ)
	endif
	String returnStr
	sprintf returnStr,"%s,%f",DAC,output
	if(IsSealTestOn())
		//SealTestOutput(chan)
		SealTestStart(1,DAQ)
	endif
	return returnStr  
End

// Returns the the SuperClamp command on channel 'chan'.  
Function SuperClampCheck(chan)
	Variable chan
	if(!WinType("SuperClampWin"))
		return 0
	endif
	ControlInfo /W=SuperClampWin $("Hold_"+num2str(chan))
	if(V_Value)
		Variable command=0
		String outputUnits=GetOutputUnits(chan)
	
		// Check to see if mV command is set and this channel is in a mode where a mV command can be given.  
		Variable conversionFactor_=ConversionFactor("mV",outputUnits)
		if(conversionFactor_)
			ControlInfo /W=SuperClampWin $("CommandMV_"+num2str(chan))
			command=V_Value*conversionFactor_
		endif
	
		// Check to see if pA command is set and this channel is in a mode where a pA command can be given.  
		conversionFactor_=ConversionFactor("pA",outputUnits)
		if(conversionFactor_)
			ControlInfo /W=SuperClampWin $("CommandPA_"+num2str(chan))
			command=V_Value*conversionFactor_
		endif 
		
		// Now add the offset if the mV offset can be converted to the output units of the channel's mode.  
		conversionFactor_=ConversionFactor("mV",outputUnits) // Convert from mV for offset to the output units of the channel.  
		if(conversionFactor_) // If there is a sensible conversion.  
			ControlInfo /W=SuperClampWin $("Offset_"+num2str(chan))
			Variable offset=V_Value // Always in mV, like a pipette offset in Multiclamp Commander.  
			command+=offset*conversionFactor_
		endif
		return command
	else
		return 0
	endif
End

// Returns the SuperClamp offset if the inputUnits of the channel's mode are compatible with the offset units (mV), and zero otherwise.  
Function SuperClampOffsetCheck(chan)
	Variable chan
	if(!WinType("SuperClampWin"))
		return 0
	endif
	ControlInfo /W=SuperClampWin $("Offset_"+num2str(chan))
	if(!V_Value)
		return 0
	endif
	String inputUnits=GetInputUnits(chan)
	Variable conversionFactor_=ConversionFactor("mV",inputUnits) // Convert from mV for offset to the output units of the channel.  
	if(conversionFactor_) // If there is a sensible conversion.  
		ControlInfo /W=SuperClampWin $("Offset_"+num2str(chan))
		Variable offset=V_Value // Always in mV, like a pipette offset in Multiclamp Commander.  
		return offset*conversionFactor_ // Convert the offset to the inputUnits of the channel.  
	else
		return 0
	endif
End

Function SuperClampGetV(chan)
	Variable chan
	
	if(WinType("SuperClampWin"))
		ControlInfo /W=SuperClampWin $("CommandMV_"+num2str(chan))
		return V_Value
	endif
	return 0
End

Function SuperClampGetI(chan)
	Variable chan
	
	if(WinType("SuperClampWin"))
		ControlInfo /W=SuperClampWin $("CommandPA_"+num2str(chan))
		return V_Value
	endif
	return 0
End

Function SuperClampSetV(chan,voltage[,writeToDAQ])
	Variable chan,voltage,writeToDAQ
	
	writeToDAQ=ParamIsDefault(writeToDAQ) ? 1 : writeToDAQ
	
	if(WinType("SuperClampWin"))
		SetVariable $("CommandMV_"+num2str(chan)) value=_NUM:voltage, win=SuperClampWin
	endif
	ControlInfo /W=SuperClampWin $("Hold_"+num2str(chan))
	SuperClampSet(chan,V_Value,writeToDAQ=writeToDAQ)
End

Function SuperClampSetI(chan,current[,writeToDAQ])
	Variable chan,current,writeToDAQ
	
	writeToDAQ=ParamIsDefault(writeToDAQ) ? 1 : writeToDAQ
	
	if(WinType("SuperClampWin"))
		SetVariable $("CommandPA_"+num2str(chan)) value=_NUM:current, win=SuperClampWin
	endif
	ControlInfo /W=SuperClampWin $("Hold_"+num2str(chan))
	SuperClampSet(chan,V_Value,writeToDAQ=writeToDAQ)
End