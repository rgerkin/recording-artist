#pragma rtGlobals=1		// Use modern global access method.

constant axonTelegraphVersion=13

Function InitAxon()
	dfref currfolder=getdatafolderdfr()
	NewDataFolder /o root:packages
	newdatafolder /o/s root:packages:axon
	variable /g ready=0
	AxonTelegraphFindServers
	Wave /Z W_TelegraphServers
	if(!waveexists(W_TelegraphServers) || numtype(W_TelegraphServers[0][0]) || numtype(W_TelegraphServers[0][1]))
		ready=-1
	else
		ready=W_TelegraphServers[0][0]
		StartAxonBkg()
	endif
	setdatafolder currfolder
	return ready
End

Structure AxonTelegraph_DataStruct
	uint32 Version			// Structure version.  Value should always be 13.
	uint32 SerialNum
	uint32 ChannelID
	uint32 ComPortID
	uint32 AxoBusID
	uint32 OperatingMode
	String OperatingModeString
	uint32 ScaledOutSignal
	String ScaledOutSignalString
	double Alpha
	double ScaleFactor
	uint32 ScaleFactorUnits
	String ScaleFactorUnitsString
	double LPFCutoff
	double MembraneCap
	double ExtCmdSens
	uint32 RawOutSignal
	String RawOutSignalString
	double RawScaleFactor
	uint32 RawScaleFactorUnits
	String RawScaleFactorUnitsString
	uint32 HardwareType
	String HardwareTypeString
	double SecondaryAlpha
	double SecondaryLPFCutoff
	double SeriesResistance
EndStructure

Function PrintAxon([serial,channel,length])
	variable serial,channel // Note that channel is the multiclamp channel which is usually the Igor channel + 1.  
	variable length // length of returned info string.  
	
	Struct AxonTelegraph_DataStruct info
	CheckAxon(info,serial=serial,channel=channel,length=length)
	if(info.version>0)
		print info
	endif
End

Function CheckAxon(info[,serial,channel,length])
	Struct AxonTelegraph_DataStruct &info
	variable serial,channel // Note that channel is the multiclamp channel which is usually the Igor channel + 1.  
	variable length // length of returned info string.  
	variable noPrint // don't print the results.  
	
	info.version=axonTelegraphVersion
	dfref f=root:packages:axon
	wave /z servers=f:W_TelegraphServers
	nvar /z ready=f:ready
	if(!waveexists(servers) || ready<=0)
		return -1
	else
		serial=(paramisdefault(serial) || serial==0) ? servers[0][0] : serial
		channel=(paramisdefault(channel) || channel==0) ? servers[0][1] : channel
		variable debugOn=IsDebuggerOn()
		DebuggerOptions enable=0
		AxonTelegraphGetDataStruct(serial, channel, length, info)
		variable err=GetRTError(1)
		if(err)
			print GetErrMessage(err)
			info.version=-1
		endif
		DebuggerOptions enable=debugOn
	endif
End

Function /S GetAxonStrValue(name[,serial,channel,length])
	variable serial,channel // Note that channel is the multiclamp channel which is usually the Igor channel + 1.  
	variable length // length of returned info string.  
	string name // name of the property with the value to be returned.  
	
	Struct AxonTelegraph_DataStruct info
	CheckAxon(info,serial=serial,channel=channel,length=length)
	if(info.version<=0)
		return ""
	endif
	strswitch(name)
		case "mode":
		case "OperatingMode":
		case "OperatingModeString":
			return info.OperatingModeString
		default:
			return ""
	endswitch
End

Function GetAxonNumValue(name[,serial,channel,length])
	variable serial,channel // Note that channel is the multiclamp channel which is usually the Igor channel + 1.  
	variable length // length of returned info string.  
	string name // name of the property with the value to be returned.  
	
	Struct AxonTelegraph_DataStruct info
	CheckAxon(info,serial=serial,channel=channel,length=length)
	strswitch(name)
		case "mode":
		case "OperatingMode":
			return info.OperatingMode
		case "igorOutputGain":
		case "commandGain":
		case "ExtCmdSens":
			return info.ExtCmdSens
		case "igorInputGain":
		case "ScaleFactor":
			return info.ScaleFactor
		default:
			return NaN	
	endswitch
End

Function StartAxonBkg()
	CtrlNamedBackground Axon burst=0, period=60, proc=AxonBkg, start
End

Function StopAxonBkg()
	CtrlNamedBackground Axon stop
End

Function AxonBkg(s)
	STRUCT WMBackgroundStruct &s
	Variable chan=0 // Assume for now that channel 0 is the only patch channel.  
	String axonMode=GetAxonStrValue("mode")
	String currMode=GetAcqMode(0)
	Variable acquiring=IsAcquiring()
	String targetMode=""
	strswitch(axonMode)
		case "V-Clamp":
			targetMode="VC"
			if(StringMatch(currMode,targetMode))
				targetMode=""
			endif
			break
		case "I-Clamp":
		case "I = 0":
			targetMode="CC"
			if(StringMatch(currMode,targetMode))
				targetMode=""
			endif
			break
		default:
			print "No such axon mode"
			return -1
	endswitch
	//print axonMode,targetMode
	if(strlen(targetMode))
		SetAcqMode(targetMode,chan)
		String DAQ=Chan2DAQ(chan)
		if(IsAcquiring())
			StopAcquisition(DAQ=DAQ)
		elseif(IsSealTestOn())
			SealTestEnd(DAQ=DAQ)
		endif
	endif
	return 0
End

