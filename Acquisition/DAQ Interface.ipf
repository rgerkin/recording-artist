// $Author: rick $
// $Rev: 626 $
// $Date: 2013-02-07 09:36:23 -0700 (Thu, 07 Feb 2013) $

#pragma rtGlobals=1		// Use modern global access method.

//constant realTimeAcq=1
constant modeTelegraphADC=5
constant realTimeSize=2000 // Number of points between wave update in real time mode.  
static strconstant module="Acq"
static constant maxDAQs=10

// Even if the XOPs are present, these must be defined for each DAQ type to work.  

#ifdef Rick
//#define Neuralynx
#endif

// Data Acquisition.  

// The GetDAQs() constant will have a list of all DAQ interfaces.  The zeroth entry will be the master DAQ.  
// Sweep number will be augmented only when it finishes its sweep, and if synchrony across GetDAQs() is
// desired, all other GetDAQs() (slaves) should be triggered off of this DAQ, for example by connecting the Trigger Out 
// on the master DAQ to the Trigger In on the slave GetDAQs().  

#if exists("ITC18Init") // Can't remember the name of an actual pre-MX operation!  Fix this.  
#define ITC
#include ":ITC Wrappers"
#endif

#if exists("DAQmx_Scan")
#define NIDAQmx
#include ":NIDAQmx Wrappers"
#endif

#if exists("LIH_InitInterface")
#define LIH
#include ":LIH Wrappers"
#endif

#if exists("SIDXCameraInit") // TO DO: Change to name of actual SIDX Operation.
#define SIDX6
#include "SIDX6 Wrappers"
#endif

function /s DAQTypes()
	return "ITC;LIH;NIDAQmx;"
end

function /s GetDAQDevices([types])
	string types
	 
	types=SelectString(!ParamIsDefault(types),DAQTypes(),types) 
	variable i
	string devices=""
	for(i=0;i<ItemsInList(types);i+=1)
		string type=StringFromList(i,types)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef GetDAQDevices f=$funcName
			string typeDevices=f(types=types)
			devices+=removeending(typeDevices,";")+";"
		endif 
	endfor
	return devices
end

function /s GetDAQs([tries,quiet])
	variable tries,quiet
	
	dfref df=Core#PackageManifest(module,"DAQs",quiet=quiet)
	svar /z/sdfr=df ignore
	df=Core#PackageHome(module,"DAQs",quiet=quiet)
	string DAQs=""
	variable i
	for(i=0;i<CountObjectsDFR(df,4);i+=1)
		string DAQ=GetIndexedObjNameDFR(df,4,i)
		if(svar_exists(ignore) && grepstring(DAQ,ignore))
			DAQs+=DAQ+";"
		endif
	endfor
	if(!strlen(DAQs))
		string defaultDAQ=Core#DefaultInstance(module,"DAQs",quiet=quiet)
		if(strlen(defaultDAQ))
			Core#SetVarPackageSetting(module,"DAQs",defaultDAQ,"active",1,quiet=quiet)
			if(!quiet)
				printf "No selected DAQs were active.  Activating DAQ '%s'.\r",defaultDAQ
			endif
			InitDAQ(0,instance=defaultDAQ,quiet=quiet)
			DAQs=defaultDAQ
		endif
	endif
	return DAQs
end

function InitDAQ(daqNum[,instance,quiet])
	variable daqNum,quiet
	string instance
	
	string acqInstance=Core#GetSelectedInstance(module,module,quiet=quiet)
	string DAQ=GetDAQName(daqNum)
	string context
	sprintf context,"_daqNum_:%d",daqNum
	RemoveDAQTraces(DAQ,quiet=quiet)
	if(paramisdefault(instance) || stringmatch(instance,"_default_"))
		Core#InheritInstancesOrDefault(module,"Acq","DAQs",{DAQ},context=context,quiet=quiet)
	else
		Core#CopyInstance(module,"DAQs",instance,DAQ,context=context,quiet=quiet)
	endif
	dfref df=GetDaqDF(DAQ)
	variable i,numChannels=GetNumChannels(DAQ=DAQ,quiet=quiet)
	string variables="numChannels;acquiring;chanBits;inPoints;outPoints;acqPoints;period;lastDAQSweepT;listenHook"
	for(i=0;i<itemsinlist(variables);i+=1)
		string varName=stringfromlist(i,variables)
		strswitch(varName)
			case "numChannels":
				variable /g df:$varName=GetNumChannels(DAQ=DAQ,quiet=quiet)
				break
			case "listenHook":
				string /g df:$varName="CollectSweep(\""+DAQ+"\")"
			default:
				variable /g df:$varName=0
				break
		endswitch
	endfor
	
	string /g df:outputWaves,df:inputWaves 
	make /o/n=0 df:InputMultiplex,df:OutputMultiplex
	for(i=0;i<numChannels;i+=1)
		make /o/n=0 df:$("input_"+num2str(i))=0
	endfor
end

function RemoveDAQTraces(DAQ[,quiet])
	string DAQ
	variable quiet

	dfref df=GetDaqDF(DAQ,quiet=quiet)
	string sweepsWinTraces=tracenamelist("SweepsWin",";",1)
	if(datafolderrefstatus(df))
		do
			variable i,j,tries=0,removed=0
			for(i=0;i<CountObjectsDFR(df,1);i+=1)
				string name=GetIndexedObjNameDFR(df,1,i)
				wave objWave=df:$name
				for(j=0;j<itemsinlist(sweepsWinTraces);j+=1)
					string trace=stringfromlist(j,sweepsWinTraces)
					wave /z traceWave=TraceNameToWaveRef("sweepsWin",trace)
					if(waveexists(traceWave) && waverefsequal(objWave,traceWave))
						removefromgraph /z/w=SweepsWin $trace
					endif
				endfor
			endfor
			tries+=1
		while(removed && tries<10)
	endif
end

function IsDAQActive(DAQ)
	string DAQ
	
	return Core#VarPackageSetting(module,"DAQs",DAQ,"active")
end

Function /s MasterDAQ([type,quiet])
	string type
	variable quiet
	
	string DAQs=GetDAQs(quiet=quiet)
	if(paramisdefault(type))
		return stringfromlist(0,DAQs)
	else
		variable i
		for(i=0;i<itemsinlist(DAQs);i+=1)
			string DAQ=stringfromlist(i,DAQs)
			if(stringmatch(DAQType(DAQ),type))
				return DAQ
			endif
		endfor
	endif
	return ""
End

Function FeedbackProc(feedbackProcess)
	String feedbackProcess

End

function /df GetDAQdf(DAQ[,quiet])
	string DAQ
	variable quiet
	
	return Core#InstanceHome(module,"DAQs",daq,create=1,quiet=quiet)
end

function /s GetDAQInfo(DAQs)
	string DAQs
	
	DAQs = selectstring(strlen(DAQs),GetDAQs(quiet=1),DAQs)
	string info=""
	variable i
	for(i=0;i<itemsinlist(DAQs);i+=1)
		string DAQ=stringfromlist(i,DAQs)
		dfref df=Core#InstanceHome(module,"DAQs",DAQ,create=0)
		svar /z/sdfr=df type,device
		if(svar_exists(type))
			sprintf info,"%s%s,%s%s;"info,DAQ,type,device
		else
			sprintf info,"%s%s;"info,DAQ
		endif
	endfor
	return info
end

function /s DAQType(DAQ[,quiet])
	string DAQ
	variable quiet
	
	return Core#StrPackageSetting(module,"DAQs",DAQ,"type",quiet=quiet)
end

//// Returns 1 if this channel name is consistent with this type of DAQ.  
//Function DAQChan(DAQ,chan)
//	String DAQ,chan
//	if(StringMatch(chan[0,1],"I_") && !StringMatch(DAQ,"ITC")) // If it is a channel intended for the ITC.  
//		return 0
//	elseif(StringMatch(chan[0,1],"N_") && !StringMatch(DAQ,"NIDAQmx")) // If it is a NIDAQ channel but it is labeled to distinguish it from non-NIDAQ channels.  
//		return 0
//	else
//		return 1
//	endif
//End

function GetDuration(daq)
	string daq
	
	return Core#VarPackageSetting(module,"DAQs",DAQ,"duration")
end

function GetKHz(daq)
	string daq
	
	return Core#VarPackageSetting(module,"DAQs",DAQ,"kHz")
end

function GetNumPulseSets(daq)
	string daq
	
	return Core#VarPackageSetting(module,"DAQs",DAQ,"pulseSets")
end

Function /S Chan2DAQ(chan)
	Variable chan
	
	string name=GetChanName(chan)
	if(Core#InstanceExists(module,"channelConfigs",name))
		string DAQ=Core#StrPackageSetting(module,"channelConfigs",name,"DAQ",default_=MasterDAQ())
	else
		DAQ=MasterDAQ()
	endif
	return DAQ
End

function DaqVarSetting(DAQ,setting)
	string DAQ,setting
	
	return Core#VarPackageSetting(module,"DAQs",DAQ,setting)
end

function /s DaqStrSetting(DAQ,setting)
	string DAQ,setting
	
	return Core#StrPackageSetting(module,"DAQs",DAQ,setting)
end

//Function NumDAQChannels(DAQ)
//	String DAQ
//	
//	Wave /T ChannelDAQ=root:parameters:ChannelDAQ
//	Extract /O ChannelDAQ,TempNDC,StringMatch(ChannelDAQ,DAQ)
//	Variable numDAQChannels=numpnts(TempNDC)
//	KillWaves /Z TempNDC
//	return numDAQChannels
//End

Function /S InputChannelList([DAQ])
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(),DAQ)
	string type=DAQType(DAQ)
	funcref InputChannelList f=$(type+"#"+GetRTStackInfo(1))
	if(numberbykey("ISPROTO",FuncRefInfo(f)) || !strlen(type))
		return "N"
	endif
	return f(DAQ=DAQ)
End

Function /S OutputChannelList([DAQ])
	string DAQ
	
	DAQ=selectstring(!paramisdefault(DAQ),MasterDAQ(),DAQ)
	string type=DAQType(DAQ)
	funcref OutputChannelList f=$(type+"#"+GetRTStackInfo(1))
	if(numberbykey("ISPROTO",FuncRefInfo(f)) || !strlen(type))
		return "N"
	endif
	return f(DAQ=DAQ)
End

// Returns the number of real outputs in the current output wave list on the given DAQ, that are not on the null channel.  
Function NumOutputs(DAQ)
	String DAQ
	
	variable numOutputs=0
	dfref df=GetDaqDF(DAQ)
	svar /sdfr=df outputWaves
	variable i
	for(i=0;i<ItemsInList(outputWaves);i+=1)
		String outputWaveInfo=StringFromList(i,outputWaves)
		String outputChannel=StringFromList(1,outputWaveInfo,",")
		if(strlen(outputChannel) && !StringMatch(outputChannel,"N"))
			numOutputs+=1
		endif
	endfor
	return numOutputs
End

Function SlaveHook(DAQ)
	String DAQ
	
	string type=DAQType(DAQ)
	string funcName=type+"#"+GetRTStackInfo(1)
	if(exists(funcName) && strlen(type))
		FuncRef SlaveHook f=$funcName
		f(DAQ)
	endif
End

// Default sampling frequency in kHz.  
Function DefaultKHz(DAQ)
	String DAQ
	
	//String funcName=DAQType(DAQ)+"#DefaultKhz"
	//FuncRef DefaultKHz f=$funcName
	//if(!exists(funcName))
	//	return 10
	//else
	//	return f(DAQ)
	//endif
	Variable kHz=NumEval(DAQ+"_kHz")
	return numtype(kHz) ? 10 : kHz
End

Function BoardGain(DAQ)
	String DAQ
	
	string type=DAQType(DAQ)
	string funcName=type+"#"+GetRTStackInfo(1)
	if(exists(funcName) && strlen(type))
		funcref BoardGain f=$funcName
		return f(DAQ)
	else
		return 3.2
	endif
End

Function DAQExists(daqName)
	String daqName
	if(WhichListItem(daqName,GetDAQs())>=0)
		return 1
	else
		return 0
	endif
End

// Only for pre-MX NIDAQ boards.  
Function SetupTriggers(pin[,DAQs])
	Variable pin // Hardcoded to pin 6
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef SetupTriggers f=$funcName
			f(pin,DAQs=DAQ) 
		endif
	endfor
End

Function SpeakReset([DAQs])
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		if(StringMatch(type,"ITC"))
			continue // Skip device resetting on the ITC, because it is slow.  
		endif
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef SpeakReset f=$funcName
			f(DAQs=DAQ)
		endif 
	endfor
End

Function ZeroAll([DAQs])
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef ZeroAll f=$funcName
			f(DAQs=DAQ)
		endif 
	endfor
End

Function BoardReset(device[,DAQs])
	Variable device
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef BoardReset f=$funcName
			f(device,DAQs=DAQ)
		endif 
	endfor
End

Function BoardInit([DAQs])
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef BoardInit f=$funcName
			f(DAQs=DAQ)
		endif 
	endfor
End

Function /S DAQError([DAQs])
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef DAQError f=$funcName
			return f(DAQs=DAQ)
		endif 
	endfor
End

Function Listen(device,gain,list,param,continuous,endHook,errorHook,other[,now,DAQs])
	Variable device,gain
	String list
	Variable param,continuous
	String endHook,errorHook,other
	Variable now
	String DAQs

	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
	
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			if(StringMatch(endHook,"CollectSweep*"))
				sprintf endHook,"CollectSweep(\"%s\")",DAQ // Change the end hook.  
			endif
			FuncRef Listen f=$funcName
			f(device,gain,list,param,continuous,endHook,errorHook,other,now=now,DAQs=DAQ)
		endif 
	endfor
End

Function InDemultiplex(inputWaves[,DAQs])
	String inputWaves
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef InDemultiplex f=$funcName
			f(inputWaves,DAQs=DAQ)
		endif 
	endfor
End

Function MakeInputMultiplex(input_waves[,DAQs])
	String input_waves
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef MakeInputMultiplex f=$funcName
			f(input_waves,DAQs=DAQ)
		endif 
	endfor
End

Function Speak(device,list,param[,now,DAQs])
	Variable device
	String list
	Variable param // 0 is continuous, 32 is only one time
	Variable now // Don't wait for SpeakAndListen, just start output now.  
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef Speak f=$funcName
			f(device,list,param,now=now,DAQs=DAQ)
		endif 
	endfor
End

Function SpeakAndListen([DAQs])
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef SpeakAndListen f=$funcName
			f(DAQs=DAQ)
		endif 
	endfor
End

Function Read(channel[,DAQs])
	Variable channel
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef Read f=$funcName
			return f(channel,DAQs=DAQ)
		endif 
	endfor
End

Function Write(channel,value[,DAQs])
	Variable channel,value
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef Write f=$funcName
			f(channel,value,DAQs=DAQ)
		endif 
	endfor
End

Function StartClock(isi[,DAQs])
	Variable isi
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	
	Variable i,err
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef StartClock f=$funcName
			err+=f(isi,DAQs=DAQ)
		endif 
	endfor
	return err
End

Function StopClock([DAQs])
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef StopClock f=$funcName
			f(DAQs=DAQ)
		endif 
	endfor
End

// This function is called when a scanning or waveform generation error is encountered.  
Function ErrorHook([DAQs])
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif	
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef ErrorHook f=$funcName
			f(DAQs=DAQ)
		endif 
	endfor
End

// Set the acquisition mode based on the voltage of the "Mode" telegraph on the back of the Axopatch 200B.  
Function SetAcqModeFromTelegraph(chan)
	Variable chan
	
	Variable volts=round(Read(modeTelegraphADC))
	switch(volts)
		case 6: // V-Clamp.  
			String mode="VC"
			break
		case 1: // I-Clamp Fast.  
		case 2: // I-Clamp Normal.  
		case 3: // I=0.  
			mode="CC" 
			break
		default: // Track, or some other signal.  
			return -1 // Don't change mode.  
			break
	endswitch
	SetAcqMode(mode,chan)
End

Function LoadDynamicClampMode([DAQs])
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef LoadDynamicClampMode f=$funcName
			f(DAQs=DAQ)
		endif 
	endfor
End

Function UnloadDynamicClampMode([DAQs])
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef UnloadDynamicClampMode f=$funcName
			f(DAQs=DAQ)
		endif 
	endfor
End


Function SetupDynamicClamp([DAQs])
	String DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		String DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef SetupDynamicClamp f=$funcName
			f(DAQs=DAQ)
		endif 
	endfor
End

function WriteDigital(line,value[,DAQs])
	string line
	variable value
	string DAQs
	
	DAQs=SelectString(ParamIsDefault(DAQs),DAQs,GetDAQs()) 
	Variable i
	for(i=0;i<ItemsInList(DAQs);i+=1)
		string DAQ=StringFromList(i,DAQs)
		if(WhichListItem(DAQ,DAQs)<0) // If this DAQ is not in the specified DAQs.  
			continue // Skip it.  
		endif
		string type=DAQType(DAQ)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			FuncRef WriteDigital f=$funcName
			f(line,value,DAQs=DAQ)
		endif 
	endfor

end

