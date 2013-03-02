
// $Author: rick $
// $Rev: 626 $
// $Date: 2013-02-07 09:36:23 -0700 (Thu, 07 Feb 2013) $

#pragma rtGlobals=1		// Use modern global access method.
static strconstant module="Acq"

Function /wave StimulusWave(channel,sweepNum)
	string channel
	variable sweepNum
	
	// Get point scaling for the stimulus by looking at the collected sweep.  
	wave /z sweep=root:$(channel):$("sweep"+num2str(sweepNum))
	if(!waveexists(sweep))
		variable i
		string sweeps=WaveList2(df=root:,match="sweep"+num2str(sweepNum),recurse=1,fullPath=1)
		for(i=0;i<itemsinlist(sweeps);i+=1)
			string sweepName=stringfromlist(i,sweeps)
			wave /z sweep=$sweepName
			if(waveexists(sweep))
				break
			endif
		endfor
	endif
	if(!waveexists(sweep))
		string DAQ=Chan2DAQ(Label2Chan(channel))
		nvar kHz=daqDF:kHz
		nvar duration=daqDF:duration
		variable delta=1/(1000*kHz)
		variable points=duration/delta
	else
		delta=dimdelta(sweep,0)
		points=dimsize(sweep,0)
	endif
	
	make /free/n=(points) stimulus
	setscale /p x,0,delta,stimulus
	nvar lastSweepNum=root:status:currSweep
	
	wave w=GetChannelHistory(channel) // Wave containing the stimulus parameters for this channel.  
	
	string mode=GetDimLabel(w,0,min(sweepNum,lastSweepNum-1)) // Mode of that sweep, or if it is in the future, of the most recent sweep.  
	if(strlen(mode))
		dfref df=Core#InstanceHome(module,"acqModes",mode)
		nvar /sdfr=df testPulseStart,testPulseLength,testPulseAmpl
		if(nvar_exists(testPulseStart))
			variable testPulseFound=1
		endif
	endif
	
	variable value=0,pulse,pulseSet,testPulseApplied=0
	for(pulseSet=0;pulseSet<dimsize(w,2);pulseSet+=1)
		variable divisor=w[sweepNum][%divisor][pulseSet]
		variable remain=mod(sweepNum,divisor)
		variable remainder=w[sweepNum][%remainder][pulseSet]
		if(divisor>1 && !(remainder & 2^remain)) // If this pulse set is not active on this sweep number.  
			continue
		endif
		variable pulses=w[sweepNum][%pulses][pulseSet]
		variable begin=w[sweepNum][%begin][pulseSet]
		variable ampl=w[sweepNum][%ampl][pulseSet]
		variable dampl=w[sweepNum][%dampl][pulseSet]
		variable width=w[sweepNum][%width][pulseSet]
		variable ipi=w[sweepNum][%ipi][pulseSet]
		variable testPulseOn=w[sweepNum][%testPulseOn][pulseSet]
		for(pulse=0;pulse<pulses;pulse+=1)
			variable firstX=begin/1000+pulse*IPI/1000
			variable lastX=begin/1000+pulse*IPI/1000+width/1000
			Variable firstSample=round(firstX/delta)
			Variable lastSample=round(lastX/delta)
			// Not using x2pnt because of a rounding bug in that function.  
			stimulus[firstSample,lastSample]+=ampl+dampl*pulse
		endfor
		if(testPulseFound && !testPulseApplied && testPulseOn)
			firstSample=x2pnt(stimulus,testPulsestart)
			lastSample=x2pnt(stimulus,testPulsestart+testPulselength)
			lastSample=min(points-2,lastSample)
			stimulus[firstSample,lastSample]-=testPulseAmpl
			testPulseApplied=1 // Mark the test pulse as having been appled so that it is applied at most once per channel per sweep.  
		endif
	endfor
	return stimulus
End

Function StimulusValue(channel,sweep,t)
	string channel
	variable sweep,t
	
	wave w=StimulusWave(channel,sweep)
	return w(t)
End

Function /wave StimulusValues(channel,t)
	string channel
	variable t
	
	nvar lastSweepNum=root:status:currSweep
	string name=cleanupname("StimValues_"+channel+"_"+num2str(t),0)
	make /o/n=(lastSweepNum) $name /wave=w
	w=StimulusValue(channel,p,t)
	return w
End

// Returns the truth about whether the convention in which the data was collected was that the first collected sweep was sweep 1.  
Function FirstSweepIsSweep1()
	String used_channels=UsedChannels()
	Variable i
	NVar currSweepNum=root:status:currSweep
	for(i=0;i<ItemsInList(used_channels);i+=1)
		String channel=StringFromList(i,used_channels)
		if(exists("root:"+channel+":sweep"+num2str(currSweepNum)) && !exists("root:"+channel+":sweep0"))
			return 1
		endif
	endfor
	return 0
End

// Converts a time of day to a time (in seconds) relative to the start of the first sweep.   
Function TimeOfDay2SweepT(sweepTstr)
	String sweepTstr // e.g. "15:23:47"

	NVar expStartT=root:status:expStartT
	// If we were on daylight savings time then but not now (3600), now but not then (-3600), now and then (0), or not now and not then (0).  
	Variable DSTshift=3600*(DST(expStartT)-DST(DateTime))
	String startTstr=Secs2Time(expStartT+DSTshift,3,3)
	Variable startHours,startMinutes,startSecs,sweepHours,sweepMinutes,sweepSecs
	sscanf startTstr,"%d:%d:%f",startHours,startMinutes,startSecs 
	sscanf sweepTstr,"%d:%d:%f",sweepHours,sweepMinutes,sweepSecs
	Variable deltaSeconds=3600*(sweepHours-startHours)+60*(sweepMinutes-startMinutes)+(sweepSecs-startSecs) // H, M, S between the 0 time in SweepT and the time given in sweepTstr.  
	return deltaSeconds
End

// Converts a time of day to a sweep number.  
Function TimeOfDay2SweepNum(sweepTstr)
	String sweepTstr // e.g. "15:23:47"
	
	Variable deltaSeconds=TimeOfDay2SweepT(sweepTstr)
	Wave sweepT=root:sweepT // Times will be in minutes relative to bootT, which is coinitialized with expStartT.  
	Variable sweepNum=BinarySearch(SweepT,deltaSeconds/60) // The sweep number of the latest sweep that precedes the time given in sweepTstr.  
	return sweepNum
End

// Returns the number of channels (0-3) stimulated during sweep 'sweep_num'
Function NumChannelsStimulated(sweep)
	Variable sweep
	
	Variable i,j,numStimulated=0,numChannels=GetNumChannels()
	for(i=0;i<numChannels;i+=1)
		dfref chanDF=GetChanDF(i)
		wave w=GetChanSweep(i,sweep,quiet=1) 
		if(numpnts(w))
			wave ampl=GetChanSweepParam(i,sweep,"ampl")
			wave width=GetChanSweepParam(i,sweep,"width")
			wave pulses=GetChanSweepParam(i,sweep,"pulses")
			variable stimulated=0
			for(j=0;j<numpnts(ampl);j+=1)
				if(ampl[i]*width[i]*pulses[i]) // If it was set for stimulation
					stimulated=1
					break
				endif
			endfor
			numStimulated+=stimulated
		endif
	endfor
	return numStimulated
End

// Returns the duration of sweep 'sweep'.  
Function SweepDuration(sweep)
	variable sweep
	
	variable i,duration=0,numChannels=GetNumChannels()
	for(i=0;i<numChannels;i+=1)
		wave /z w=GetChanSweep(i,sweep,quiet=1)
		if(waveexists(w))
			duration=WaveDuration(w)
			break
		endif
	endfor
	return duration
End

// Returns the cumulative recorded time up to but not including sweep number 'num'
Function SweepNum2CumulativeDuration(num)
	Variable num
	Variable i,total_time=0
	for(i=1;i<num;i+=1)
		total_time+=SweepDuration(i)
	endfor
	return total_time
End

// Returns the number of the first full sweep that begins after the drug change described in 'drug_details', an entry from the wave root:Drugs:Info
Function SweepFromDrugInfo(drug_details)
	String drug_details
	drug_details=StringFromList(0,drug_details)
	Variable thyme=NumFromList(0,drug_details,sep=",")
	Wave SweepT=root:SweepT
	Variable sweep_num=2+BinarySearch(SweepT,thyme)
	if(sweep_num<1)
		printf "Couldn't figure out sweep number corresponding to time %f.\r",thyme
		sweep_num=NaN
	endif
	return sweep_num
End

Function /S Wave2Pathway(theWave)
	Wave theWave
	String wave_name=NameOfWave(theWave)
	String synapse=wave_name[strlen(wave_name)-5,strlen(wave_name)-1]
	return synapse
End

Function HasStimulus(sweepNum[,chan,channel_label,ignoreRemainder])
	Variable sweepNum,chan
	String channel_label
	Variable ignoreRemainder // Consider stimulation that shouldn't actually occur because the remainder doesn't match mod(sweep,divisor).  
	
	if(ParamIsDefault(chan))
		if(ParamIsDefault(channel_label)) // All channnels.  
			Variable stimT=EarliestStim(sweepNum,ignoreRemainder=ignoreRemainder)
		else
			stimT=EarliestStim(sweepNum,channel_Label=channel_Label,ignoreRemainder=ignoreRemainder)
		endif
	else
		stimT=EarliestStim(sweepNum,chan=chan,ignoreRemainder=ignoreRemainder)
	endif
	return (!numtype(stimT) && stimT>0)
End

// Returns a list of channels that were used in the current experiment.  
Function /S UsedChannels()
	Variable i
	String currFolder=GetDataFolder(1)
	String usedChannels=""
	for(i=0;i<CountObjects("root:",4);i+=1)
		String folder=GetIndexedObjName("root:",4,i)
		SetDataFolder $("root:"+folder)
		String sweepWaveList=WaveList("sweep*",";","DIMS:1")
		Variable numSweeps=ItemsInList(GrepList(sweepWaveList,"sweep[0-9]"))
		//Wave /Z StimulusHistory,SweepParameters
		if(numSweeps)
			usedChannels+=folder+";"
		endif
	endfor
	SetDataFolder $currFolder
	return usedChannels
End

// Returns a list of all the sweeps.  
Function /S AllSweeps()
	NVar currSweepNum=root:status:currSweep
	return ListExpand("0,"+num2str(currSweepNum-1))
End

// Returns a list of all sweeps without stimuli.  
Function /S AllSweepsWithoutStimuli()
	String all_sweeps=AllSweeps()
	return RemoveSweepsWithStimuli(all_sweeps)
End

// Removes the numbers from a list corresponding to sweeps in which at least one of the channels was stimulated.  
Function /S RemoveSweepsWithStimuli(list)
	String list // A list like "1;2;3;4"
	list=ListExpand(list)
	String new_list=""
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		Variable num=NumFromList(i,list)
		if(!HasStimulus(num))
			new_list+=num2str(num)+";"
		endif
	endfor
	return new_list
End

Function/S ChannelString(channelNum)
	Variable channelNum
	switch(channelNum)
		case 1: 
			return "R1"
			break
		case 2: 
			return "L2"
			break
		default:
			printf "Not a valid channel %d. [ChannelString()]\r",channelNum
	endswitch
End

Function TimeDif() // Prints the time between the two cursors in the main data plot window.  
	Wave SweepT=root:SweepT
	String ampl_X1=num2str(hcsr(A))
	String ampl_X2=num2str(hcsr(B))
	String sweept_X1=num2str(SweepT(hcsr(A)))
	String sweept_X2=num2str(SweepT(hcsr(B)))
	String diff_ampl=num2str(hcsr(B)-hcsr(A))
	String diff_t=num2str(SweepT(hcsr(B))-SweepT(hcsr(A)))
	printf "From A (%.3f,%.3f) to B (%.3f,%.3f) is (%.3f,%.3f)\r",hcsr(A),SweepT(hcsr(A)),hcsr(B),SweepT(hcsr(B)),hcsr(B)-hcsr(A),SweepT(hcsr(B))-SweepT(hcsr(A))
End

Function FractionFailures(left,right) // Prints the number of sweeps where the EPSC is below a certain threshold.  
	Variable left
	Variable right
	Variable i
	Variable failures=0
	Wave ampl=root:cellR1:ampl
	for(i=left;i<=right;i+=1)
		if(ampl[i]>-4)
			failures+=1
		endif
	endfor
	Variable fraction=failures/(1+right-left)
End  

// Determine periods of sweeps for which the type of clamp was constant for a given channel.  
// Output is two waves: Clamps (each entry contains VC or CC) and ClampSweepLists (each entry contains a list of sweeps).  
Function ClampRegions(channel,sweep_list)
	String channel
	String sweep_list 
	
	sweep_list=ListExpand(sweep_list)
	Wave SweepParams=root:$("sweep_parameters_"+channel)
	Make /T/o/n=1 ClampSweepLists="",Clamps=""
	Variable unique_clamps=1
	String clamp_sweeps=""
	Variable final_sweep=maxlist(sweep_list) // Gets the maximum sweep number for that experiment. 
	Variable initial_sweep=minlist(sweep_list) // Gets the maximum sweep number for that experiment.  
	Variable last_clamp=NaN
	Variable k
	for(k=initial_sweep;k<=final_sweep;k+=1)
		Variable clamp=SweepParams[k][5]
		Wave /Z Sweep=$("root:cell"+channel+":sweep"+num2str(k))
		if(waveexists(Sweep))
			if(IsNaN(clamp) || clamp==last_clamp || k==initial_sweep) // If clamps match or this is the first sweep
				clamp_sweeps+=num2str(k)+";"
			else
				clamp_sweeps=num2str(k)+";"
				unique_clamps+=1
				Redimension /n=(unique_clamps) ClampSweepLists,Clamps
			endif
			ClampSweepLists[unique_clamps-1]=clamp_sweeps
			Clamps[unique_clamps-1]=SelectString(clamp,"CC","VC")
			last_clamp=clamp
			//max_sweep_length=max(max_sweep_length,rightx(Sweep)-leftx(Sweep))
		else
			last_clamp=NaN // Pick a value so that neither VC nor CC will match it.  
		endif
	endfor
	
	// Remove any empty entries.  
	k=0
	Do
		if(strlen(ClampSweepLists[k])==0)
			DeletePoints k,1,ClampSweepLists,Clamps	
		else
			k+=1
		endif
	While(k<numpnts(ClampSweepLists))
End

// Returns "VC" for 1 and "CC" for 0
Function /S Num2Clamp(num)
	Variable num
	if(num==1)
		return "VC"
	elseif(num==0)
		return "CC"
	else
		printf "Number must be 0 or 1 [Num2Clamp(num)].\r"
		return ""
	endif
End

// For experimental files (not databases), returns a list of all the sweeps where 'channel' was in 'clamp'
Function /S ClampSweeps(channel,clamp)
	String channel,clamp
	Wave sweep_params=$("root:sweep_parameters_"+channel)
	String sweeps=""
	Variable i
	for(i=1;i<numpnts(sweep_params);i+=1)
		if(Clamp2Num(clamp)==sweep_params[i][5])
			sweeps+=num2str(i)+";"
		endif
	endfor
	return sweeps
End

Function Clamp2Num(clamp)
	String clamp
	if(StringMatch(clamp,"VC"))
		return 1
	elseif(StringMatch(clamp,"CC"))
		return 0
	else
		DoAlert 0,"Error in Clamp2Num... bad clamp passed."
		return -1
	endif
End

Function /S Log2Clip([notebook_name])
	String notebook_name
	if(ParamIsDefault(notebook_name))
		notebook_name="LogPanel#ExperimentLog"
	endif
	Notebook $notebook_name selection={startOfFile,endOfFile}
	GetSelection notebook,$notebook_name,2
	String selection=S_Selection
	selection=ReplaceString("\r",selection,"; ") // Eliminates the returns
	if(StringMatch(selection[0,1],"; "))
		selection=selection[2,strlen(selection)-1] // Gets rid of initial return
	endif
	selection=ReplaceString(";;",selection,";")
	selection=ReplaceString("; ;",selection,";")
	selection=ReplaceString(";  ;",selection,";")
	selection=ReplaceString(".;",selection,";")
	selection=ReplaceString(". ;",selection,";")
	selection=ReplaceString(".  ;",selection,";")
	PutScrapText selection
	Notebook $notebook_name selection={startOfFile,startOfFile}
	return selection
End

Function SweepsOnChannel(channel)
	String channel
	String curr_folder=GetDataFolder(1)
	if(!DataFolderExists("root:cell"+channel))
		return 0
	endif
	SetDataFolder $("root:cell"+channel)
	String sweep_list=WaveList("sweep*",";","")
	Variable sweeps=ItemsInList(sweep_list)
	SetDataFolder $curr_folder
	return sweeps
End

// Makes Control cells black and PTX cells red
Function /S Cell2Condition(cell)
	String cell
	if(WhichListItem(cell,PTX_list)>=0)
		return "PTX"
	elseif(WhichListItem(cell,Control_list)>=0)
		return "Control"
	else
		return "Unknown"
	endif
End

strconstant PTX_list="021105d;021105e;022105c;022105e;022105h;022505b;022505c;022505d;022505e;022805c;022805d"
strconstant Control_list="022105c;021505b;021505c;022305c;022305d;022305e;022305f;022305g;022405a;022405b"