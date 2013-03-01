#pragma rtGlobals=1		// Use modern global access method.

Function AutomatedTransitionAnalysis(sub_dir)
	String sub_dir
	Variable no_scratch // Start with the experiment that is already loaded.  
	
	String reverb_data_location="C:Reverberation Project:Data:"+sub_dir
	NewPath /O/Q ReverbDataFolder,reverb_data_location
	NewPath /O/Q Temp,desktop_dir+":Temp"
	String files=LS(reverb_data_location,mask="*.pxp")
	root()
	//SetWaveLock 0,allInCDF // Unlock previously locked waves.  
	Variable i,j,k
	
	SQLConnekt("Reverb")
	String sql_cmd="SELECT Transitions.*,Island_Record.Drug_Incubated FROM Transitions INNER JOIN Island_Record ON Transitions.File_Name=Island_Record.File_Name "
	sql_cmd+="WHERE Island_Record.Confidence>="+num2str(7)+" AND Usable=1 AND Started_Spontaneous=0"
	SQLc(sql_cmd)
	Wave /T File_Name,Channel_Analyzed,Sweeps_Analyzed
	Execute /Q "ProgressWindow open"
	for(i=0;i<numpnts(File_Name);i+=1)
		// Kill all the data to prepare for the next file. 
		root();
		UpdateProgressWin(frac=i/ItemsInList(files))
		// Load data from the next experiment.  
		String name=File_Name[i]
		print "Loading data from "+name
		String channel=Channel_Analyzed[i]
		String sweeps=Sweeps_Analyzed[i]
		if(!strlen(sweeps))
			continue
		endif	
		Variable first_sweep=str2num(StringFromList(0,sweeps,","))
		Variable last_sweep=str2num(StringFromList(1,sweeps,","))
		LoadWave /O/P=Temp "SER_"+name+"_"+channel+".ibw"
		Wave Loaded=$StringFromList(0,S_wavenames)
		WaveStats /Q/R=(first_sweep,last_sweep) Loaded
		sql_cmd="UPDATE Transitions SET Spontaneous_Rate = "+num2str(V_avg)+" WHERE File_Name='"+name+"'"
		SQLc(sql_cmd)
		KillWaves /Z Loaded
	endfor
	Execute /Q "ProgressWindow close"
	SQLDisconnekt()
End

// Gets a plot of spontaneous event rate vs time for every experiment in sub-directory 'sub_dir' and saves a jpeg of it.  
Function SER2(sub_dir[,no_scratch])
	String sub_dir
	Variable no_scratch // Start with the experiment that is already loaded.  
	
	String reverb_data_location="C:Reverberation Project:Data:"+sub_dir
	NewPath /O/Q ReverbDataFolder,reverb_data_location
	NewPath /O/Q Temp,desktop_dir+":Temp"
	String files=LS(reverb_data_location,mask="*.pxp")
	root()
	SetWaveLock 0,allInCDF // Unlock previously locked waves.  
	Variable i,j,k,sweep,downsample=100
	
	SQLConnekt("Reverb")
	string sql_cmd="SELECT Transitions.File_Name FROM Transitions INNER JOIN Island_Record ON Transitions.File_Name=Island_Record.File_Name "
	sql_cmd+="WHERE Island_Record.Confidence>="+num2str(7)+" AND Usable=1 AND Started_Spontaneous=0"
	SQLc(sql_cmd)
	Wave /T File_Name
	Execute /Q "ProgressWindow open"
	for(i=0;i<ItemsInList(files);i+=1)
		// Kill all the data to prepare for the next file. 
		root();
		KillAll("windows")
		if(!no_scratch)
			KillRecurse("*")
		endif
		UpdateProgressWin(frac=i/ItemsInList(files))
		// Load data from the next experiment.  
		String file=StringFromList(i,files)
		String /G name=RemoveEnding(file,".pxp")
	
		FindValue /TEXT=name /TXOP=4 File_Name
		if(V_Value<0)
			continue
		endif
		print name
		if(!no_scratch)
			print "Loading data from "+name
			LoadData /Q/O=2/R/P=ReverbDataFolder file 
		endif
		BackwardsCompatibility() // Create all the windows, etc.  
		// Show only R1_R1 and L2_L2 for the purposes of analysis.    
		for(j=0;j<ItemsInList(all_channels);j+=1)
			for(k=0;k<ItemsInList(all_channels);k+=1)
				TraceSelector(StringFromList(j,all_channels)+"_"+StringFromList(k,all_channels),0)
			endfor
		endfor
		TraceSelector("R1_R1",1)
		TraceSelector("L2_L2",1)
		PopUpMenu Method value="Events", win=Ampl_Analysis
		DoWindow /F Ampl_Analysis; AnalysisMethodProc("Method",0,"Events")
		Cursors()
		//Recalculate("")
		Wave ampl_R1=root:cellR1:ampl_R1_R1
		LoadWave /P=Temp "SER_"+name+"_R1.ibw"
		Wave Loaded=$StringFromList(0,S_wavenames)
		ampl_R1=Loaded
		Wave ampl_L2=root:cellL2:ampl_L2_L2
		LoadWave /P=Temp "SER_"+name+"_L2.ibw"
		Wave Loaded=$StringFromList(0,S_wavenames)
		ampl_L2=Loaded
		
		Checkbox Peak2 value=0
		PeakProc("",0)
		Variable points=max(numpnts(root:cellR1:ampl_R1_R1),numpnts(root:cellL2:ampl_L2_L2))
		Make /o/n=(points) Index=x+1
		//Save /P=Temp root:cellR1:ampl_R1_R1 as "SER_"+name+"_R1.ibw"
		//Save /P=Temp root:cellL2:ampl_L2_L2 as "SER_"+name+"_L2.ibw"
		Tags2SweepNumber()
		ReplaceWave /X trace=ampl_R1_R1,Index
		ReplaceWave /X trace=ampl_L2_L2,Index
		SetAxis /A Ampl_Axis
		SetAxis /A Time_Axis
		Label Time_Axis "Sweep Number"
		ModifyGraph lblPosMode(Time_axis)=1,lblLatPos=0
		//print "here4"
		SavePICT /O/B=288 /E=-6 /P=Temp as "Transition_"+name+".jpg"
		//print "here5"
		//abort
	endfor
	Execute /Q "ProgressWindow open"
	SQLDisconnekt()
End

// Returns the number of spontaneous network events (reverberations and isolated polysynaptic events) per second in a given recording.  
Function SpontaneousEventRate(channel,sweep_list)
	String channel,sweep_list
	print channel,sweep_list
	String sweep_list2=ListExpand(sweep_list)
	
	Variable i,num_stimuli=0
	String channels=all_channels
	for(i=0;i<ItemsInList(sweep_list2);i+=1)
		Variable sweep_num=NumFromList(i,sweep_list2)
		num_stimuli+=NumChannelsStimulated(sweep_num)
	endfor
	
	sweep_list2=AddPrefix(sweep_list2,"root:cell"+channel+":sweep") 
	sweep_list2=AddSemiColon(sweep_list2)
	
	Variable duration=0
	for(i=0;i<ItemsInList(sweep_list2);i+=1)
		String sweep_name=StringFromList(i,sweep_list2)
		Wave Sweep=$sweep_name
		duration+=WaveDuration(Sweep)
	endfor
	
	Variable num_events=EventRate(channel,sweep_list)
	return max(0,(num_events-num_stimuli)/duration)
End

Function EventRate(channel,sweep_list)
	String channel,sweep_list
	
	sweep_list=ListExpand(sweep_list)
	sweep_list=AddPrefix(sweep_list,"root:cell"+channel+":sweep") 
	sweep_list=AddSemiColon(sweep_list)
	
	NewDataFolder /O/S root:reanalysis
	NewDataFolder /O/S Transition
	String /G sweeps_analyzed
	Concatenate /O/NP sweep_list, Segment
	Variable num_events=Events(Segment)
	return num_events
End

Function Events(Segment)
	Wave Segment
	
	Variable down_time=0.8 // How long the the network has to be down before the next event is allowed (s).  0.5 for real reverberations, 0.8 for simulations.  
	Variable filter_width=50 // The running median filter width, in points.  // Use 500 for real reverberations, and 50 for simulations.  
	Variable thresh_level=100 // The number of pA more negative than the 75th percentile (100th is most positive) that the signal must cross to be a candidate event.  
	
	WildPoint /F Segment,filter_width,0
	StatsQuantiles /Q Segment
	Variable thresh=V_Q75-thresh_level
	FindLevels /Q Segment,thresh // Find all of the places where half of the maximum negative slope of the smoothed recording is reached.  
	Wave W_FindLevels
	//print thresh
	if(Segment[0]<thresh) // If we started out with more inward current than the threshold.  
		DeletePoints 0,1,W_FindLevels // Skip the first threshold crossing, which will be in the wrong direction.  
	endif
	Variable i=0
	InsertPoints 0,1,W_FindLevels
	W_FindLevels[0]=0
	Do
		Variable num_levels=numpnts(W_FindLevels)
		Do
			Variable out=W_FindLevels[i]
			Variable in=W_FindLevels[i+1]
			//print out,in
			if(in-out<down_time)
				//print "failed"
				DeletePoints i,2,W_FindLevels
			else
				//print "passed"
				DeletePoints i,1,W_FindLevels
				i+=1
			endif
		While(i<numpnts(W_FindLevels))
	While(numpnts(W_FindLevels)!=num_levels) // Iterate until the number of levels found is stable.  
	Variable num_events=numpnts(W_FindLevels)
	Variable /G threshold=thresh
	return num_events
End

// Analyzes whether a transition to spontaneous activity occurred for different reverberation durations, waiting times, and drugs acutely applied.  
Function TransitionAnalysis(mode[,method,min_confidence])
	Variable mode // mode=0 compares ctl vs ttx, and mode=1 compares various drug conditions.  
	Variable method // method=0 is the manual method for transtion values, and method=1 is the automated method.  
	Variable min_confidence // Minimum level of island isolation.  
	//root()
	SQLConnekt("Reverb")
	//SQLc("SELECT A1.DIV,A1.Drug_Incubated,A2.*,A3.Intervening_Drugs FROM Island_Record A1, Transitions A2, Mini_Sweeps A3 WHERE A1.File_Name=A2.File_Name AND A2.File_Name=A3.File_Name") 
	string sql_cmd="SELECT Transitions.*,Island_Record.Drug_Incubated FROM Transitions INNER JOIN Island_Record ON Transitions.File_Name=Island_Record.File_Name "
	sql_cmd+="WHERE Island_Record.Confidence>="+num2str(min_confidence)+" AND Usable=1 AND Started_Spontaneous=0"
	SQLc(sql_cmd)
	// Get all the data from Mini_Sweeps and info about whether it was a TTX incubated or a control experiment.  
	Wave /T File_Name,Intervening_Drugs,Drug_Incubated
	Wave Reverberation,Transition,Spontaneous_Rate
	Variable i,j,k,item
	String used_drugs=";None;APV;MPEP;Wortmannin;TNP-ATP;BMI"
	String conditions="ctl;ttx"
	SQLDisconnekt()
	Make /o/n=0 XAxis=NaN,YAxis=NaN; Wave XAxis,YAxis
	Make /o/T/n=0 Source; Wave /T Source
	Make /o/T/n=(ItemsInList(used_drugs)) XAxisLabels=StringFromList(p,used_drugs)
	Make /o/n=(ItemsInList(used_drugs)) XAxisValues=p
	Display /K=1 /N=AllTransitions
	
	for(i=0;i<numpnts(File_Name);i+=1)
		String file=File_Name[i]
		String drugs=Intervening_Drugs[i]
		for(j=1;j<ItemsInList(used_drugs);j+=1)
			String candidate_drug=StringFromList(j,used_drugs)
			//print i
			if(StringMatch(drugs,"*"+candidate_drug+"*"))
				break
			endif
		endfor
		if(!StringMatch(drugs,"*"+candidate_drug+"*"))
			print drugs,file
		endif
		if(j==6) // If only BMI was present...
			j=1 // Just make this a "None" condition.  
		endif
		String drug1=StringFromList(0,drugs); // Drug list during the first period of activity.  
		drug1=SelectString(StringMatch(drug1,"[Null]"),drug1,"None")
		String drug2=StringFromList(1,drugs); // Drug list during the second period of activity (if there was one).
		drug2=SelectString(StringMatch(drug1,"[Null]"),drug2,"None")  
		String condition=Drug_Incubated[i]
		if(StringMatch(condition,"CTL"))
			if(mode==0)
				item=0
			elseif(mode==1)
				continue
			endif
		endif
		if(StringMatch(condition,"TTX"))
			if(mode==0)
				item=1
			elseif(mode==1)
				item=j
			endif
		endif
		InsertPoints 0,1,Source,XAxis,YAxis
		Source[0]=file
		XAxis[0]=item
		if(method==0)
			YAxis[0]=Transition[i]
		elseif(method==1)
			YAxis[0]=Spontaneous_Rate[i]
		endif
		//print file,Spontaneous_Rate[i]
		KillVariables /Z red,green,blue
	endfor
	AppendToGraph YAxis vs XAxis
	ModifyGraph userticks(bottom)={XAxisValues,XAxisLabels}
	BigDots()
	//root()
End

Function TransitionVsReverbDuration([min_confidence])
	Variable min_confidence // Minimum level of island isolation.  
	root()
	SQLConnekt("Reverb")
	//SQLc("SELECT A1.DIV,A1.Drug_Incubated,A2.*,A3.Intervening_Drugs FROM Island_Record A1, Transitions A2, Mini_Sweeps A3 WHERE A1.File_Name=A2.File_Name AND A2.File_Name=A3.File_Name") 
	string sql_cmd="SELECT Transitions.*,Island_Record.Drug_Incubated FROM Transitions INNER JOIN Island_Record ON Transitions.File_Name=Island_Record.File_Name "
	sql_cmd+="WHERE Island_Record.Confidence>="+num2str(min_confidence)+" AND Usable=1 AND Started_Spontaneous=0"
	SQLc(sql_cmd)
	// Get all the data from Mini_Sweeps and info about whether it was a TTX incubated or a control experiment.  
	Wave /T File_Name,Drug_Incubated
	Wave Reverberation,Transition
	Variable i,j,k
	String conditions="ctl;ttx"
	SQLDisconnekt()
	
	Display /K=1 /N=TransitionVsDuration
	for(i=0;i<ItemsInList(conditions);i+=1)
		String condition=StringFromList(i,conditions)
		Make /o/n=0 $("ReverbDuration_"+condition),$("TransitionDegree_"+condition)
		Make /o/T/n=0 $("FileName_"+condition)
		AppendToGraph $("TransitionDegree_"+condition) vs $("ReverbDuration_"+condition)
	endfor
	
	
	for(i=0;i<numpnts(File_Name);i+=1)
		String file=File_Name[i]
		condition=Drug_Incubated[i]
		InsertPoints 0,1,Source,XAxis,YAxis
		Wave ReverbDuration=$("ReverbDuration_"+condition)
		Wave TransitionDegree=$("TransitionDegree_"+condition)
		Wave /T ConditionFileName=$("FileName_"+condition)
		InsertPoints 0,1,ReverbDuration,TransitionDegree,ConditionFileName
		ReverbDuration[0]=Reverberation[i]+enoise(0.5)
		TransitionDegree[0]=Transition[i]+enoise(0.05)
		ConditionFileName[0]=file
		KillVariables /Z red,green,blue
	endfor
	
	BigDots()
	root()
End

// Identify the start and end times for reverberations given a recording.  
Function ReverbIdentification(Sweep[,x1,x2,min_peak,thresh_frac,init,rando])
	Wave Sweep
	Variable x1,x2,min_peak,thresh_frac,init
	String rando
	if(ParamIsDefault(rando))
		rando=""
	endif
	rando+=num2str(abs(enoise(100)))+";"
	x1=ParamIsDefault(x1) ? leftx(Sweep) : x1
	x2=ParamIsDefault(x2) ? rightx(Sweep) : x2
	min_peak=ParamIsDefault(min_peak) ? -30 : min_peak
	thresh_frac=ParamIsDefault(thresh_frac) ? 0.1 : thresh_frac
	if(!waveexists(ReverbTimes) || init)
		Make /o/n=(0,2) ReverbTimes
	endif
	WaveStats /Q/R=(x1,x2) Sweep
	
	if(V_min<min_peak)
		Wave Termini=$RI_SearchFlanks(Sweep,V_minloc,x1,x2,min_peak*thresh_frac,0.5)			
	else
		return 0
	endif
	Variable index=numpnts(ReverbTimes)
	InsertPoints index,1,ReverbTimes
	Variable start=Termini[0],finish=Termini[1]
	ReverbTimes[index][]=Termini[q]
	//print x1,x2,V_minloc,V_min,Termini[0],Termini[1],rando
	ReverbIdentification(Sweep,x1=x1,x2=start,min_peak=min_peak,thresh_frac=thresh_frac,rando=rando)
	ReverbIdentification(Sweep,x1=finish,x2=x2,min_peak=min_peak,thresh_frac=thresh_frac,rando=rando)
	KillWaves /Z Termini
End

// Auxiliary function for ReverbIdentification.  
// Searches from both sides of a start point to determine the first and last threshold crossing.  
Function /S RI_SearchFlanks(Sweep,x_mid,x1,x2,thresh,max_gap)
	Wave Sweep
	Variable x_mid,x1,x2,thresh,max_gap
	Variable j,range=50
	Make /o/n=2 Termini
	for(j=0;j<2;j+=1)
		Variable direction=(j*2-1)*range // +range and -range.
		Variable end_point=x_mid+direction
		end_point=end_point<x1 ? x1 : end_point
		end_point=end_point>x2 ? x2 : end_point
		FindLevels /EDGE=(2-j) /Q /R=(x_mid,end_point) Sweep, thresh
		Variable i
		Wave W_FindLevels
		for(i=1;i<numpnts(W_FindLevels);i+=1)
			Variable gap=abs(W_FindLevels[i]-W_FindLevels[i-1])
			//print gap
			if(gap>max_gap)
				i-=1
				break
			endif
		endfor
		Variable terminus=W_FindLevels[i]
		Termini[j]=terminus
	endfor
	return GetWavesDataFolder(Termini,2)
End

// For a set of sweeps compute the reverberation onset and duration for each sweep, and make
// concatenated waves for each of these.  
Function ReverbCorrelations()
	String wave_list=AddPrefix(ListExpand("1,117"),"root:cellL2:sweep")
	Variable i
	Make /o/n=0 ReverbTimesAll,ReverbDurationsAll
	Variable elapsed_time=0
	for(i=0;i<ItemsInList(wave_list);i+=1)
		String wave_name=StringFromList(i,wave_list)
		Wave theWave=$wave_name
		ReverbTimesandDurations(theWave)
		Wave ReverbTimes
		ReverbTimes+=elapsed_time
		Concatenate /NP {ReverbTimes}, ReverbTimesAll
		Concatenate /NP {ReverbDurations}, ReverbDurationsAll
		elapsed_time+=WaveDuration(theWave)
	endfor
End

// Longest reverb for the shown sweep after filtering.  
Function LAF()
	Duplicate /o CsrWaveRef(A,"Sweeps") test; 
	WaveStats /Q/M=1 test; test-=V_avg; 
	FilterIIR /HI=0.00001 test; 
	Display /K=1 test; 
	print LongestReverbVC(test)
End

// Uses the history of the charge transfer to determine what fraction of the synaptic resources, i.e. vesicles, should be currently available.  
Function ExpectedVesicles(tau)
	//Wave theWave
	//Variable time_point // The time point for which the expected synaptic resources should be supported.  
	Variable tau // The recovery time for synaptic resources.
	//Variable depletion=0 // The fraction of synaptic resources that are assumed to remain after an event.  
	//ReverbTimesandDurations(theWave)
	//Wave ReverbTimes,ReverbDurations
	ReverbCorrelations()
	Wave ReverbTimes=ReverbTimesAll,ReverbDurations=ReverbDurationsAll
	Duplicate /o ReverbTimes ExpectedResources
	Variable i
	for(i=0;i<numpnts(ExpectedResources);i+=1)
		Make /o/n=(i) PreviousReverbs=ReverbTimes[i]-ReverbTimes
		PreviousReverbs=log(1-exp(-PreviousReverbs/tau))
		ExpectedResources[i]=exp(sum(PreviousReverbs))
	endfor
End

// Creates waves containing the onset time and duration of all the reverberations in a sweep.  
Function ReverbTimesandDurations(theWave)
	Wave theWave
	Variable baseline=StatsMedian(theWave)
	Variable on_trigger=200
	Variable off_trigger=10
	Variable off_duration=0.1 // Amount of time (s) the signal needs to be below off_trigger before it is considered off.  
	Variable down_sample=100
	Variable sampling_rate=10000
	Wave Downsampled=$Downsample(theWave,down_sample)
	Variable med=StatsMedian(Downsampled)
	Downsampled-=med // Subtract the median.  
	Downsampled*=-1 // Flip.  
	Variable i,j,on=0,on_time
	Make /o/n=0 ReverbTimes,ReverbDurations
	for(i=0;i<numpnts(Downsampled);i+=1)
		if(on && Downsampled[i]<off_trigger) // If we are in the middle of a reverb and the next sample is below the off trigger.    
			for(j=1;j<off_duration*sampling_rate/down_sample;j+=1)
				if(Downsampled[i+j]>off_trigger)
					break
				endif
			endfor
			if(j>=off_duration*sampling_rate/down_sample) // If we made it all the way through the loop, then none of the candidate sampled are above the off trigger.  
				on=0
				InsertPoints 0,1,ReverbTimes,ReverbDurations
				Variable off_time=i*down_sample/sampling_rate
				Variable length=off_time-on_time
				ReverbTimes[0]=on_time
				ReverbDurations[0]=length
			endif
		elseif(!on && Downsampled[i]>on_trigger)
			on=1
			on_time=i*down_sample/sampling_rate
			//print on_time
		endif
	endfor
	if(on)
		InsertPoints 0,1,ReverbTimes,ReverbDurations
		off_time=i*down_sample/sampling_rate
		length=off_time-on_time
		ReverbTimes[0]=on_time
		ReverbDurations[0]=length
	endif
	WaveTransform /O flip ReverbTimes
	WaveTransform /O flip ReverbDurations
	KillWaves /Z Downsampled
End

Function LoadBadSweepInfo()
	NewPath /O/Q Analysis_Dir,"C:Reverberation Project:Analysis:"
	Variable refNum
	Close /A
	Open /R/P=Analysis_Dir refNum as "BadSweepsSimplified.txt"
	Variable i=0
	String line,file_name,info
	Make /o/n=0/T BadSweepsFileNames
	Make /o/n=0/T BadSweepsInfo
	Do
		FReadLine refNum,line
		InsertPoints 0,1,BadSweepsFileNames,BadSweepsInfo
		file_name=StringFromList(0,line,"=")
		BadSweepsFileNames[0]=file_name
		info=StringFromList(1,line,"=")
		BadSweepsInfo[0]=RemoveEnding(info,num2char(13))
	While(strlen(line))
	Close refNum
End

// Goes through all experiments in a given directory and prints the sweep number (and channel) with the longest reverberation (for each experiment) in voltage clamp.  
Function LongestReverbs(sub_dir[,mask,no_clear,no_scratch,in_list,drug,no_drug,drug_inc,min_island_quality])
	String sub_dir
	String mask // File names must match this mask.
	Variable no_clear // Don't start with empty analysis waves (e.g. FilesZ, DurationsZ).  
	Variable no_scratch // Start with the experiment that is already loaded.  
	String in_list // Only check the files in the list 'in_list'.  
	String drug // The drug accutely applied (e.g. "BMI").  
	String no_drug // The drug is not accutely applied.  
	String drug_inc // The drug incubated (e.g. "CTL" or "TTX").  
	Variable min_island_quality // The minimum value, from 1 to 10, of the quality of the island (confidence in number of neurons and isolation).  
	
	if(ParamIsDefault(mask))
		mask="*"
	endif
	String reverb_data_location="C:Reverberation Project:Data:"+sub_dir
	NewPath /O/Q ReverbDataFolder,reverb_data_location
	NewPath /O/Q Desktop,desktop_dir
	//print reverb_data_location
	String files=LS(reverb_data_location,mask=mask+".pxp")
	root()
	SetWaveLock 0,allInCDF // Unlock previously locked waves.  
	LoadBadSweepInfo(); Wave /T BadSweepsFileNames,BadSweepsInfo
	Variable i
	//String only_these=LS("C:Documents and Settings:rick:Desktop:LongestReverbs:")
	if(no_clear)
		Wave /T FilesZ,ChannelsZ
		Wave DurationsZ,SweepsZ,IslandSizesZ
	else
		Make /o/T/n=0 FilesZ,ChannelsZ
		Make /o/n=0 DurationsZ,SweepsZ,IslandSizesZ
	endif
	SetWaveLock 1,BadSweepsFileNames,BadSweepsInfo,FilesZ,ChannelsZ,DurationsZ,SweepsZ,IslandSizesZ
	SQLConnekt("Reverb")
	for(i=0;i<ItemsInList(files);i+=1)
		// Kill all the data to prepare for the next file. 
		root();
		KillAll("windows")
		if(!no_scratch)
			KillRecurse("*",except="LongestReverbs_*")
		endif
		String file=StringFromList(i,files)
		String name=RemoveEnding(file,".pxp")
		name=RemoveEnding(name,"_simplified") // If we are using the simplified data files.  
		if(!ParamIsDefault(in_list) && WhichListItem(name,in_list)<0)
			//print "The file is not in the list."  
			continue // The file is not in the list 'in_list'.  
		endif
		// Screen to exclude analysis on experiments that don't match the criteria.  
		SQLc("SELECT Total_Cells,Drug_Incubated,Confidence FROM Island_Record WHERE File_Name='"+name+"'"); Wave Total_Cells,Confidence; Wave /T Drug_Incubated
		if(numpnts(Total_Cells)==0)
			continue // If this file isn't even listed in the Island_Record table, skip it.  
		endif
		if(numtype(Total_Cells[0])==2 || Total_Cells[0]==0)
			//continue // If there is no information about the number of cells on the island.  
		endif
		if(!ParamIsDefault(min_island_quality) && Confidence[0]<min_island_quality)
			continue // If min_island_quality is specified and this experiment does not meet this minimum island quality.  
		endif
		if(!ParamIsDefault(drug_inc) && !StringMatch(Drug_Incubated[0],drug_inc))
			continue // If drug_inc is specified and it is not the incubated drug for this experiment.  
		endif
		String sql_str="SELECT Experimenter FROM Sweep_Record WHERE Experimenter='RCG' AND File_Name='"+name+"'"
		if(!ParamIsDefault(drug) && !StringMatch(drug,"NULL"))
			if(strlen(drug)>0)
				sql_str+=" AND Drug LIKE '%"+drug+"%'"
			else
				sql_str+=" AND Drug IS NULL"
			endif
		endif
		SQLc(sql_str,show=0)
		if(numpnts(Experimenter)==0)
			continue // If there are no sweeps that contained that drug.  
		endif
		//if(WhichListItem(name+".jpg",only_these)==-1)
		//	continue
		//endif
		
		// Load data from the next experiment
		if(!no_scratch)
			print "Loading data from "+name
			LoadData /Q/O=2/R/P=ReverbDataFolder file 
		endif
		FindValue /TEXT=name BadSweepsFileNames; Variable bad_sweep_index=V_Value
		String bad_sweep_info=""
		if(bad_sweep_index>=0)
			bad_sweep_info=BadSweepsInfo[bad_sweep_index]
		endif
		//print "Bad Sweeps: "+bad_sweep_info
		
		// Find the longest reverberation and add information about it to the waves in root.  
			// Stupid stuff I have to do to avoid passing null values through optional parameters.  
			if(ParamIsDefault(drug))
				drug="NULL"
			endif
			if(ParamIsDefault(no_drug))
				no_drug="NULL"
			endif
			//
		LongestReverbExperiment(bad_sweep_info,drug=drug,no_drug=no_drug,file_name=name)
		NVar longest_reverb,longest_sweep
		SVar longest_channel
		root()
		SetWaveLock 0,FilesZ,DurationsZ,SweepsZ,ChannelsZ,IslandSizesZ
		Variable index
		if(!no_clear)
			InsertPoints 0,1,FilesZ,DurationsZ,SweepsZ,ChannelsZ,IslandSizesZ
			index=0
		else
			index=i
		endif
		FilesZ[index]=name
		DurationsZ[index]=longest_reverb
		SweepsZ[index]=longest_sweep
		ChannelsZ[index]=longest_channel
		IslandSizesZ[index]=Total_Cells[index]
		SetWaveLock 1,FilesZ,DurationsZ,SweepsZ,ChannelsZ,IslandSizesZ
		//BackwardsCompatibility() // Create all the windows, etc.  
	endfor
	SQLDisconnekt()
	root()
	KillRecurse("*",except="LongestReverbs_*")
End

Function LongestReverbExperiment(bad_sweep_info[,drug,no_drug,file_name])
	String bad_sweep_info
	String drug,no_drug,file_name
	if(ParamIsDefault(file_name))
		SQLConnekt("Reverb")
		file_name=IgorInfo(1)
	endif
	Variable /G longest_reverb=0,longest_sweep=NaN
	String /G longest_channel=""
	NVar /Z last_sweep=root:current_sweep_number
	Make /o/n=(last_sweep+1) ReverbDuration=NaN,Stimuli=NaN,ValidSweeps=NaN
	if(ParamIsDefault(drug))
		drug="NULL"
	endif
	if(ParamIsDefault(no_drug))
		no_drug="NULL"
	endif
	String drug_str=SQL_DrugStr(drug=drug,no_drug=no_drug)
	Variable i,j,k
	if(NVar_exists(last_sweep))
		//print "Here"
		for(j=0;j<ItemsInList(all_channels);j+=1)
			String channel=StringFromList(j,all_channels)
			Wave /Z SweepParams=root:$("sweep_parameters_"+channel)
			String bad_sweep_info_channel=StringByKey(channel,bad_sweep_info,":","|")
			bad_sweep_info_channel=ListExpand(bad_sweep_info_channel)
			if(waveexists(SweepParams))
				//print channel
				for(k=1;k<=last_sweep;k+=1)
					if(ValidSweeps[k]==0)
						continue
					endif
					String sweep_location="root:cell"+channel+":sweep"+num2str(k)
					Wave /Z SweepWave=$sweep_location
					Variable on_bad_list=WhichListItem(num2str(k),bad_sweep_info_channel)>=0
					Variable VC=SweepParams[k][5]
					Stimuli[k]=HasStimulus(k)
					if(waveexists(SweepWave) && VC==1 && !on_bad_list) // If the sweep exists and was recorded in voltage clamp and is not on the bad sweep list.    
						//print "Sweep "+num2str(k)
						String stim_regions=StimulusRegionList(channel,k,include_gaps=1,left=0.01,right1=0.01,right2=0.01) // 10 ms buffer from the stimulus locations.  
						//Variable length=LongestReverbVC(SweepWave,stim_regions=stim_regions)
						//ReverbDuration[k]=(ReverbDuration[k]>length) ? ReverbDuration[k] : length
						//print length
						if(1)//length>longest_reverb)
							if(!ParamIsDefault(drug) || StringMatch(drug,"NULL") || !ParamIsDefault(no_drug) || StringMatch(drug,"NULL"))
								String letter=file_name[strlen(file_name)-1]
								String file_sweep=letter+num2str(k)
								String sql_str="SELECT Sweep FROM Sweep_Record WHERE Experimenter='RCG' AND File_Name='"+file_name+"' AND File_Sweep='"+file_sweep+"'"
								SQLc(sql_str); Wave Sweep
								Variable sweep_num=Sweep[0]
								Variable num_sweeps_back=5 // The number of sweeps back for which the drug conditions should adhere to the conditions passed into the function.  
								sql_str="SELECT Experimenter FROM Sweep_Record WHERE Experimenter='RCG' AND File_Name='"+file_name+"' AND Sweep>"+num2str(sweep_num-num_sweeps_back)+" AND Sweep<="+num2str(sweep_num)
								SQLc(sql_str+drug_str,show=0)
								Wave Experimenter
								if(numpnts(Experimenter)<num_sweeps_back) // If the size of the result set is less than the minimum number of criteria-satisfying sweeps preceding the sweep in question.  
									Wave /T DrugInfo=root:drugs:info
									Variable first_drug_time=str2num(StringFromList(0,DrugInfo[0],","))
									if(k>num_sweeps_back || (first_drug_time>0 && first_drug_time<2.5))
										 // If the sweep number is high enough to have a large enough result set or the sweep number is low and a drug was added early on.  
										ValidSweeps[k]=0 // Don't count this sweep. 
										continue
									endif 
								endif
								ValidSweeps[k]=1
							endif
							Variable length=LongestReverbVC(SweepWave,stim_regions=stim_regions)
							ReverbDuration[k]=(ReverbDuration[k]>length) ? ReverbDuration[k] : length
							longest_reverb=length
							longest_channel=channel
							longest_sweep=k
						endif
					endif
				endfor
			endif
		endfor
	endif
	//print "Length: "+num2str(longest_reverb)+"; "+longest_channel+" : Sweep "+num2str(longest_sweep)
End

// Finds the longest reverberation of a given sweep in voltage clamp.  
// Assumes that x-scaling of 'theWave' is already in seconds.  
// Do not use with a chunk size smaller than the sampling rate.  
Function LongestReverbVC(theWave[,stim_regions,chunk_size,on_trigger,off_trigger,down_time,subtract_med])
	Wave theWave
	String stim_regions // Regions containing stimuli (in s).  
	Variable chunk_size // Size of chunks to average over (in ms).  
	Variable on_trigger // The amplitude in pA that will signal onset.  
	Variable off_trigger // The amplitude in pA that will signal a candidate offset.  
	Variable down_time // Downtime after offset to signify the end of a reverberation (ms).  
	Variable subtract_med // Subtract off the median first. 

	if(ParamIsDefault(stim_regions))
		stim_regions=""
	endif
	chunk_size=ParamIsDefault(chunk_size) ? 5 : chunk_size
	on_trigger=ParamIsDefault(on_trigger) ? 85 : on_trigger
	off_trigger=ParamIsDefault(off_trigger) ? 125 : off_trigger
	down_time=ParamIsDefault(down_time) ? 500 : down_time
	subtract_med=ParamIsDefault(subtract_med) ? 1 : subtract_med
	
	Variable downsample=0.001*chunk_size/dimdelta(theWave,0)
	downsample=downsample<1 ? 1 : round(downsample)
	Wave Downsampled=$Downsample(theWave,downsample)
	if(subtract_med)
		Variable med=StatsMedian(Downsampled)
		Downsampled-=med // Subtract the median.  
	endif
	Downsampled*=-1 // Flip.  
	//print med
	Variable i,j,length,longest=0,on=0,on_time,max_samples=down_time/chunk_size
	for(i=0;i<numpnts(Downsampled);i+=1)
		if(on)
			//print i*chunk_size,DownSampled[i]
		endif
		if(on && Downsampled[i]<off_trigger) // If we are in the middle of a reverb and the next sample is below the off trigger.    
			for(j=1;j<max_samples;j+=1)
				if(Downsampled[i+j]>off_trigger)
					break
				endif
			endfor
			if(j==max_samples) // If we made it all the way through the loop, then none of the candidate sampled are above the off trigger.  
				on=0
				length=i*chunk_size - on_time
				Variable on_time2=on_time/1000 // Convert to s.  
				Variable stim_region_num=InRegionList(on_time2,stim_regions)
				if(stim_region_num>=0)
					String stim_region=StringFromList(stim_region_num,stim_regions)
					Variable lower=str2num(StringFromList(0,stim_region,","))
					Variable upper=str2num(StringFromList(1,stim_region,","))
					Variable stim_length=1000*(upper-lower-0.02) // Subtract off 20 ms to account for the fact that stim_regions was buffered beyond the actual stimuli.  Convert to ms.  
					length-=stim_length
				endif
				//print on_time,length
				if(length>longest)
					longest=length
					//print on_time,length
				endif
			endif
		elseif(!on && Downsampled[i]>on_trigger)
			//print on_time
			on=1
			on_time=i*chunk_size
		endif
	endfor
	if(on)
		length=i*chunk_size - on_time
		if(length>longest)
			longest=length
		endif
	endif
	//Display /K=1 Downsampled
	KillWaves /Z Downsampled
	//print on_time
	return longest/1000 // Convert from ms to s.  
End

Function /S ListExperiments(drug_incubated,[drug,no_drug,min_island_quality,stimuli,min_sweeps])
	String drug_incubated,drug,no_drug
	Variable min_island_quality,stimuli,min_sweeps
	
	stimuli=ParamIsDefault(stimuli) ? 1 : stimuli // By default, there must be stimuli for those sweeps to count.  
	min_sweeps=ParamIsDefault(min_sweeps) ? 1 : min_sweeps // By default, there must be at least one sweep for an experiment to count
	SQLConnekt("Reverb")
	String curr_folder=GetDataFolder(1)
	
	Variable i
	Variable num_experiments=0
	String experiment_list=""
	String drug_str=""
	if(!ParamIsDefault(drug) && !StringMatch(drug,"NULL"))
		if(strlen(drug)>0)
			for(i=0;i<ItemsInList(drug);i+=1)
				String one_drug=StringFromList(i,drug)
				drug_str+=" AND Drug LIKE '%"+one_drug+"%'"
			endfor
		else
			drug_str+=" AND Drug IS NULL"
		endif
	endif
	if(!ParamIsDefault(no_drug) && !StringMatch(no_drug,"NULL"))
		if(strlen(no_drug)>0)
			drug_str+=" AND (Drug IS NULL OR ("
			for(i=0;i<ItemsInList(no_drug);i+=1)
				one_drug=StringFromList(i,no_drug)
				drug_str+="Drug NOT LIKE '%"+one_drug+"%' AND "
			endfor
			drug_str=RemoveEnding(drug_str," AND ")
			drug_str+="))"
		else
			drug_str+=" AND Drug IS NOT NULL"
		endif
	endif
	
	NewDataFolder /o/S root:NumExperiments_temp
	String sql_str="SELECT File_Name FROM Island_Record WHERE Drug_Incubated='"+drug_incubated+"'"
	if(!ParamIsDefault(min_island_quality))
		sql_str+=" AND Confidence>="+num2str(min_island_quality)
	endif
	SQLc(sql_str)
	Duplicate /o/T File_Name Master_File_Name; Wave /T Master_File_Name
	Variable rejects=0
	for(i=0;i<numpnts(Master_File_Name);i+=1)
		String file=Master_File_Name[i]
		Variable num_sweeps=0
		sql_str="SELECT * FROM Sweep_Record WHERE File_Name='"+file+"'"
		SQLc(sql_str+drug_str,show=0)
		Wave Sweep
		if((stimuli && NumSweepsWithStimuli()>=min_sweeps) || numpnts(Sweep)>=min_sweeps)
			experiment_list+=file+";"
			continue
		else
			rejects+=1
		endif
	endfor
	//print drug_str
	//print rejects
	KillDataFolder /Z root:NumExperiments_temp
	KillWaves /Z File_Name
	SQLDisconnekt()
	SetDataFolder $curr_folder
	return experiment_list
End

Function NumSweepsWithStimuli()
	Wave R1_Pulses,R1_Ampl,R1_Width
	Wave L2_Pulses,L2_Ampl,L2_Width
	Wave B3_Pulses,B3_Ampl,B3_Width
	Variable i
	Make /o/n=(numpnts(R1_Pulses)) TotalStims=0
	for(i=0;i<ItemsInList(three_channels);i+=1)
		String channel=StringFromList(i,three_channels)
		Wave Pulses=$(channel+"_Pulses")
		Wave Ampl=$(channel+"_Ampl")
		Wave Width=$(channel+"_Width")
		String stims_name=channel+"_Stims"
		Make /o/n=(numpnts(Pulses)) $stims_name=Pulses*(Ampl>0)*(Width>0)
		Wave Stims=$stims_name
		Stims=numtype(Stims)!=0 ? 0 : Stims
		TotalStims+=Stims
	endfor
	TotalStims=(TotalStims>0) ? 1 : 0
	return sum(TotalStims)
End

// Goes through all experiments in a given directory and constructs Pakming-style summary plots of the area
// in between baseline and post-activity period (as specified in a table in the database.  Also appends information
// about minis during the first t seconds of each sweep during that same period.  Saves images for each experiment.  
Function ReverbAndMiniPrintouts(sub_dir[,t,no_scratch])
	String sub_dir
	Variable t // The first t seconds (after the test pulse) will be analyzed for minis.  
	Variable no_scratch // Start with the experiment that is already loaded.  
	t=ParamIsDefault(t) ? 30 : t
	
	String reverb_data_location="C:Reverberation Project:Data:"+sub_dir
	NewPath /O/Q ReverbDataFolder,reverb_data_location
	NewPath /O/Q Desktop,desktop_dir
	String files=LS(reverb_data_location,mask="*.pxp")
	root()
	SetWaveLock 0,allInCDF // Unlock previously locked waves.  
	Variable i,j,k,sweep,downsample=100
	
	SQLConnekt("Reverb")
	for(i=0;i<ItemsInList(files);i+=1)
		// Kill all the data to prepare for the next file. 
		root();
		KillAll("windows")
		if(!no_scratch)
			KillRecurse("*")
		endif
		
		// Load data from the next experiment.  
		String file=StringFromList(i,files)
		String /G name=RemoveEnding(file,".pxp")
		if(!no_scratch)
			print "Loading data from "+name
			LoadData /Q/O=2/R/P=ReverbDataFolder file 
		endif
		BackwardsCompatibility() // Create all the windows, etc.  
		//abort
		SplitSweeps(max_duration=30) // Split all sweeps greater than 30 seconds duration into two sweeps and update the experiment accordingly.  
		
		// Show only R1_R1 and L2_L2 for the purposes of mini searching.  
		for(j=0;j<ItemsInList(all_channels);j+=1)
			for(k=0;k<ItemsInList(all_channels);k+=1)
				TraceSelector(StringFromList(j,all_channels)+"_"+StringFromList(k,all_channels),0)
			endfor
		endfor
		TraceSelector("R1_R1",1)
		TraceSelector("L2_L2",1)
		PopUpMenu Method value="Minis", win=Ampl_Analysis
		DoWindow /F Ampl_Analysis; AnalysisMethodProc("Method",0,"Minis")
		
		// Load information about the reverberatory period from the database.  
		SQLc("SELECT * FROM Mini_Sweeps WHERE File_Name='"+name+"'")
		Wave /T Baseline_Sweeps,Post_Activity_Sweeps
		Redimension /n=0 Baseline_Sweeps // I just want it to ignore the database and print the whole thing.  
		if(numpnts(Baseline_Sweeps)>0) // If there is even an entry for this experiment in the Mini_Sweeps database.  
			String baseline_sweeps_str=Baseline_Sweeps[0]
			String post_activity_sweeps_str=Post_Activity_Sweeps[0]
			String sweeps_to_use=""
			if(strlen(baseline_sweeps_str)==0)
				baseline_sweeps_str="25,25"
			endif
			if(strlen(post_activity_sweeps_str)==0)
				baseline_sweeps_str="80,80"
			endif
			for(j=-2+NumFromList(1,Baseline_Sweeps[0],sep=",");j<5+NumFromList(0,Post_Activity_Sweeps[0],sep=",");j+=1)
				// -2 and 5 are used to gives some indication of the "after" rerverberation state of the minis.  
				sweeps_to_use+=num2str(j)+";"
			endfor
		else // Just use all the sweeps
			NVar last_sweep=root:current_sweep_number
			sweeps_to_use=ListExpand("1,"+num2str(last_sweep))
		endif

		// Compute minis
		Variable first=NumFromList(0,sweeps_to_use)-1
		Variable last=NumFromList(ItemsInList(sweeps_to_use)-1,sweeps_to_use)-1
		String top_trace=TopVisibleTrace(win="Ampl_Analysis")
		Cursor /W=Ampl_Analysis A,$top_trace,first
		Cursor /W=Ampl_Analysis B,$top_trace,last
		top_trace=TopVisibleTrace(win="Sweeps")
		Cursor /W=Sweeps A,$top_trace,0.158
		Cursor /W=Sweeps B,$top_trace,t
		
		NewDataFolder /O root:Minis
		Variable /G root:Minis:mini_thresh=10
		
		// Remove line noise.  
		for(j=0;j<ItemsInList(all_channels);j+=1)
			String channel=StringFromList(j,all_channels)
			CleanWaves(channel,sweeps_to_use)
		endfor
		Recalculate("")
		
		ReverbPrintoutManager(base_name=CleanupName(name,0))
		Checkbox AppendAnalysis, value=1, win=ReverbPrintoutManagerWin // Set value to 1 to append the analysis values and 0 to not do so.  
		NVar rows_per_page=root:Packages:ReverbPrintout:rows_per_page
		rows_per_page=200
		for(j=0;j<ItemsInList(two_channels);j+=1)
			channel=StringFromList(j,two_channels)
			SVar sweep_list=root:Packages:ReverbPrintout:$(channel):sweep_list
			sweep_list=sweeps_to_use
		endfor
		ReverbPrintout("")
		RPM_Save("")
		//abort
	endfor
	SQLDisconnekt()
End

// Goes through all experiments in a given directory and constructs Pakming-style summary plots of each experiment.  
// Saves images for each experiment.  
Function ReverbPrintouts(sub_dir[,no_scratch])
	String sub_dir
	Variable no_scratch // Start with the experiment that is already loaded.  
	
	String reverb_data_location="C:Reverberation Project:Data:"+sub_dir
	NewPath /O/Q ReverbDataFolder,reverb_data_location
	NewPath /O/Q Desktop,desktop_dir
	String files=LS(reverb_data_location,mask="*.pxp")
	root()
	SetWaveLock 0,allInCDF // Unlock previously locked waves.  
	Variable i,j,k,sweep,downsample=100
	
	SQLConnekt("Reverb")
	for(i=0;i<ItemsInList(files);i+=1)
		// Kill all the data to prepare for the next file. 
		root();
		KillAll("windows")
		if(!no_scratch)
			KillRecurse("*")
		endif
		
		// Load data from the next experiment.  
		String file=StringFromList(i,files)
		String /G name=RemoveEnding(file,".pxp")
		if(!no_scratch)
			print "Loading data from "+name
			LoadData /Q/O=2/R/P=ReverbDataFolder file 
		endif
		BackwardsCompatibility() // Create all the windows, etc.  
		//abort
		SplitSweeps(max_duration=30) // Split all sweeps greater than 30 seconds duration into two sweeps and update the experiment accordingly.  
		String sweeps_to_use=AllSweeps()

		// Compute minis
		Variable first=NumFromList(0,sweeps_to_use)-1
		Variable last=NumFromList(ItemsInList(sweeps_to_use)-1,sweeps_to_use)-1
		
		ReverbPrintoutManager(base_name=CleanupName(name,0))
		Checkbox AppendAnalysis, value=0, win=ReverbPrintoutManagerWin // Set value to 1 to append the analysis values and 0 to not do so.  
		NVar rows_per_page=root:Packages:ReverbPrintout:rows_per_page
		rows_per_page=200
		for(j=0;j<ItemsInList(two_channels);j+=1)
			String channel=StringFromList(j,two_channels)
			SVar sweep_list=root:Packages:ReverbPrintout:$(channel):sweep_list
			sweep_list=sweeps_to_use
		endfor
		ReverbPrintout("")
		RPM_Save("")
		//abort
	endfor
End

// Goes through all experiments in a given directory and constructs cumulative charge over time
// plots starting with the washout of TTX and ending with the washin of TTX.  
Function ChargeBeforeAfterStimulus2(sub_dir)
	String sub_dir
	
	String reverb_data_location="C:Reverberation Project:Data:"+sub_dir
	NewPath /O/Q ReverbDataFolder,reverb_data_location
	NewPath /O/Q Desktop,desktop_dir
	String files=LS(reverb_data_location,mask="*.pxp")
	root()
	SetWaveLock 0,allInCDF // Unlock previously locked waves.  
	Variable i,j,sweep,downsample=100
	
	SQLConnekt("Reverb")
	for(i=0;i<ItemsInList(files);i+=1)
		root()
		// Load data from the next experiment.  
		String file=StringFromList(i,files)
		String name=ReplaceString(".pxp",file,"")
		print "Loading data from "+name
		LoadData /Q/O=2/R/P=ReverbDataFolder file 
		
		// Load information about the reverberatory period from the database.  
		SQLc("SELECT * FROM Mini_Sweeps WHERE File_Name='"+name+"'")
		Wave /T Baseline_Sweeps,Post_Activity_Sweeps
		if(numpnts(Baseline_Sweeps)>0) // If there is even an entry for this experiment in the Mini_Sweeps database.  
			String baseline_sweeps_str=Baseline_Sweeps[0]
			String post_activity_sweeps_str=Post_Activity_Sweeps[0]
			String reverb_sweeps=""
			for(j=1+NumFromList(1,Baseline_Sweeps[0],sep=",");j<NumFromList(0,Post_Activity_Sweeps[0],sep=",");j+=1)
				reverb_sweeps+=num2str(j)+";"
			endfor
			
			// --- Processing of the data for each file.  
			for(j=0;j<ItemsInList(two_channels);j+=1)
				String channel=StringFromList(j,two_channels)
				for(sweep=NumFromList(0,reverb_sweeps);sweep<=NumFromList(ItemsInList(reverb_sweeps)-1,reverb_sweeps);sweep+=1) // All reverb sweeps
					print "Acquiring values for sweep "+num2str(sweep)+" on channel "+channel
					Wave /Z SweepWave=$("root:cell"+channel+":sweep"+num2str(sweep))
					Variable charge0_3=NaN,charge3_30=NaN,charge30_33=NaN,charge33_60=NaN
					if(waveexists(SweepWave))
						charge0_3=MedianMinusMean(SweepWave,x1=0.15,x2=2.99)
						charge3_30=MedianMinusMean(SweepWave,x1=3.01,x2=29.99)
						if(WaveDuration(SweepWave)>=60)
							charge30_33=MedianMinusMean(SweepWave,x1=30.15,x2=32.99)
							charge33_60=MedianMinusMean(SweepWave,x1=33.01,x2=59.99)
						endif
					else
						print "Sweep "+num2str(sweep)+" could not be found for channel "+channel
					endif
					String sql_cmd="INSERT INTO ChargeBeforeAfter (File_Name,Channel,Sweep,Charge0_3,Charge3_30,Charge30_33,Charge33_60) "
					sql_cmd+="VALUES ('"+name+"','"+channel+"',"+num2str(sweep)+","+num2str(charge0_3)+","+num2str(charge3_30)+","+num2str(charge30_33)+","+num2str(charge33_60)+")"
					SQLc(sql_cmd,show=1)
				endfor
			endfor
		endif
		
		// Kill all the data to prepare for the next file. 
		root();
		KillAll("windows")
		KillRecurse("*")
	endfor
	SQLDisconnekt()
End

// Goes through all experiments in a given directory and constructs cumulative charge over time
// plots starting with the washout of TTX and ending with the washin of TTX.  
Function CumulChargeOverTime3(sub_dir)
	String sub_dir
	
	String reverb_data_location="C:Reverberation Project:Data:"+sub_dir
	NewPath /O/Q ReverbDataFolder,reverb_data_location
	NewPath /O/Q Desktop,desktop_dir
	String files=LS(reverb_data_location,mask="*.pxp")
	root()
	SetWaveLock 0,allInCDF // Unlock previously locked waves.  
	Variable i,j,downsample=100
	
	for(i=0;i<ItemsInList(files);i+=1)
		root()
		String file=StringFromList(i,files)
		String name=ReplaceString(".pxp",file,"")
		print "Loading data from "+name
		LoadData /Q/O=2/R/P=ReverbDataFolder file
		//BackwardsCompatibility()
		// --- Processing of the data for each file.  
			NVar final_sweep=root:current_sweep_number
			Display /K=1
			for(j=0;j<ItemsInList(all_channels);j+=1)
				String channel=StringFromList(j,all_channels)
				CumulChargeOverTime2(channel=channel,first_sweep=1,last_sweep=final_sweep,downsample=downsample)
				Wave CCOT_Charge=$(channel+"_CCOT_Charge")
				if(sum(CCOT_Charge)!=0)
					//Wave CCOT_Thyme=$(channel+"_CCOT_Thyme")
					Channel2Color(channel); NVar red,green,blue
					if(StringMatch(channel,"L2"))
						AppendToGraph /c=(red,green,blue) /L CCOT_Charge
					else
						AppendToGraph /c=(red,green,blue) /R CCOT_Charge
					endif
				endif
			endfor
			KillVariables /Z red,green,blue
			ModifyGraph lsize=0.5
			DrugTags2()
			Label bottom "Time (Minutes)"
			Label /Z left "\K(0,0,65535)Charge (pC)"
			Label /Z right "\K(65535,0,0)Charge (pC)"
			SetAxis /Z left 0,*
			SetAxis /Z right 0,*
			Textbox /A=RB/X=0/Y=0/F=0/B=1 "\Z08"+name
			SavePICT/O/P=Desktop/E=-6/B=288 as name+"_Cumul_Charge.jpg"
		// ---
		root();
		KillAll("windows")
		KillRecurse("*") // Kill all the data to prepare for the next file. 
	endfor
End

Function CNQXReverb([output])
	String output // 'Index', 'Duration', or 'Probability'.  Index is Duration*Probability.    
	if(ParamIsDefault(output))
		output="Index"
	endif
	root()
	Variable i,j,k
	
	String /G sql_select="SELECT DISTINCT A1.Experimenter,A1.File_Name,A1.Drug_Incubated "
	String /G sql_from="FROM Island_Record A1,CNQX A2 "
	String /G sql_where="WHERE A1.File_Name=A2.File_Name"
	SQLc(sql_select+sql_from+sql_where)
	
	Wave /T Experimenter,File_Name,Drug_Incubated
	NewDataFolder /O root:Islands
	String name,drug
	
	for(i=0;i<numpnts(File_Name);i+=1)
		root()
		name=Experimenter[i]+"_"+File_Name[i]
		NewDataFolder /O/S root:Islands:$name
		sql_select="SELECT Sweep_List,Channel,CNQX_Dose,Reverb_Duration,Reverb_Prob,Background_Drugs "
		sql_from="FROM CNQX "
		sql_where="WHERE Experimenter='"+Experimenter[i]+"' AND File_Name='"+File_Name[i]+"'"
		SQLc(sql_select+sql_from+sql_where)
		Wave Sweep_List,Channel,CNQX_Dose,Reverb_Duration,Reverb_Prob,Background_Drugs
	endfor
	root()
	
	Variable zero_dose_duration,zero_dose_prob,num_traces
	String match_drug,drug_list="CTL;TTX"
	Display /K=1 /N=ReverbCNQX
	for(j=0;j<ItemsInList(drug_list);j+=1)
		match_drug=StringFromList(j,drug_list)
		Condition2Color(match_drug); NVar red,green,blue
		//Display /K=1 /N=$match_drug
		for(i=0;i<numpnts(File_Name);i+=1)
			root()
			name=Experimenter[i]+"_"+File_Name[i]
			drug=Drug_Incubated[i]
			if(!StringMatch(drug,match_drug))
				continue
			endif
			SetDataFolder root:Islands:$name
			Wave Sweep_List,Channel,CNQX_Dose,Reverb_Duration,Reverb_Prob,Background_Drugs
			Duplicate /o Reverb_Duration,$"Reverb_Index"; Wave Reverb_Index
			Reverb_Index=Reverb_Duration*Reverb_Prob
			WaveStats /Q CNQX_Dose
			InsertPoints 0,2,CNQX_Dose,Reverb_Duration,Reverb_Prob,Reverb_Index,Sweep_List,Channel,Background_Drugs
			Reverb_Duration[0,1]=0
			Reverb_Prob[0,1]=0
			Reverb_Index[0,1]=0
			CNQX_Dose[0,1]={min(V_max*1.5,501),501}
			Sort CNQX_Dose,CNQX_Dose,Sweep_List,Channel,Reverb_Duration,Reverb_Prob,Reverb_Index,Background_Drugs
			Extract /INDX /O CNQX_Dose,$"Zero_Dose",CNQX_Dose==0
			Wave Zero_Dose
			if(numpnts(Zero_Dose)>0)
				zero_dose_duration=Reverb_Duration[Zero_Dose[0]]
				zero_dose_prob=Reverb_Prob[Zero_Dose[0]]
				Reverb_Duration/=zero_dose_duration
				Reverb_Prob/=zero_dose_prob
				Reverb_Index/=(zero_dose_prob*zero_dose_duration)
				//Interpolate2 /T=1/Y=Reverb_Duration_interp CNQX_Dose,Reverb_Duration
				//Interpolate2 /T=1/Y=Reverb_Prob_interp CNQX_Dose,Reverb_Prob
				Make /o CNQX_Interp={0,50,100,150,200,250,300,400,501}
				Interpolate2 /T=1 /I=3 /X=CNQX_Interp /Y=Reverb_Index_interp CNQX_Dose,Reverb_Index
				Interpolate2 /T=1 /I=3 /X=CNQX_Interp /Y=Reverb_Duration_interp CNQX_Dose,Reverb_Duration
				Interpolate2 /T=1 /I=3 /X=CNQX_Interp /Y=Reverb_Prob_interp CNQX_Dose,Reverb_Prob
				//AppendToGraph /c=(65535,0,0) Reverb_Duration_interp
				//ModifyGraph muloffset($TopTrace())={0,1/zero_dose_duration}
				//AppendToGraph /c=(0,0,65535) Reverb_Prob_interp
				//ModifyGraph muloffset($TopTrace())={0,1/zero_dose_prob}
				AppendToGraph /c=(red,green,blue) $("Reverb_"+output+"_interp") vs CNQX_Interp
			else
				print "No zero dose for "+name
			endif
		endfor
		ModifyGraph mode=0,gaps=0
		root()
	endfor
	AverageByColor()
	num_traces=ItemsInList(TraceNameList("",";",3))
	RemoveFirstNTraces(num_traces-2)
	DoWindow /T $WinName(0,1) output
	ModifyGraph fstyle=1
	Label left output
	Label bottom "CNQX Concentration (nM)"
	KillVariables /Z red,green,blue
	root()
End

// Returns the time of voltage clamp "events" for a given sweep
Function FindVCEvents(sweep[,threshold,no_prepare])
	Wave sweep
	Variable threshold,no_prepare
	Duplicate /o sweep smoothed
	if(!no_prepare) // This will proceed unless you already have the prepared wave from a previous iteration
		PrepareVCEvents(smoothed)
	endif
	threshold=ParamIsDefault(threshold) ? 200000 : threshold
	FindLevels /Q smoothed, threshold
	print V_LevelsFound
	if(smoothed[0]<threshold)
		DeletePoints 0,1,W_FindLevels // If the sweep starts out beyond the threshold, eliminate the first crossing
	endif
	Variable i=1
	// Delete the odd numbered points (leaving only the crossings down (increasing negative current) through level
	for(i=1;i<numpnts(W_FindLevels);i+=1)
		DeletePoints i,1,W_FindLevels
	endfor
	Duplicate /o W_FindLevels VCEvents
	//KillWaves smoothed, W_FindLevels
End

Function PrepareVCEvents(sweep)
	Wave sweep
	sweep=sweep > 50 ? 0 : sweep // Suppress all stimulus artifacts
	sweep=sweep < -1000 ? -1000 : sweep // Suppress all stimulus artifacts
	Smooth 10000,sweep
	Differentiate sweep
	sweep=(sweep > 0) ? 0 : sweep
	Differentiate sweep
	sweep=(sweep < 0) ? 0 : sweep
End

// Make a plot of events (spikes of VC events) vs time (on a log scale) using a matrix of data, where each column is a sweep
Function PowerLawPlot(experiment[,clamp,start_time,threshold,low,high,mode])
	Wave experiment
	String clamp
	Variable start_time,threshold,low,high,mode
	if(ParamIsDefault(clamp))
		clamp="VC"
	endif
	start_time=ParamIsDefault(start_time) ? StimTime(TopImage()) : start_time // The time of stimulation (when events begin)
	print NameOfWave(experiment),start_time
	if(StringMatch(clamp,"VC"))
		threshold=ParamIsDefault(threshold) ? TestCutoff(experiment) : threshold
	elseif(StringMatch(clamp,"CC"))
		threshold=ParamIsDefault(threshold) ? -10 : threshold
	endif
	low=ParamIsDefault(low) ? 0 : low
	high=ParamIsDefault(low) ? (DimSize(experiment,1)-1) : high
	Display /K=1 /N=$CleanupName("PL_"+NameOfWave(experiment),0)
	Variable i
	for(i=low;i<=high;i+=1)
		Duplicate /O/R=()(i,i) experiment, OneSweep
		strswitch(clamp)
			case "VC":
				FindVCEvents(OneSweep,threshold=threshold)
				Wave Events=VCEvents
				break
			case "CC":
				FindSpikeTimes(OneSweep,threshold=threshold)
				Wave Events=SpikeTimes
				break
			default:
				print "Invalid clamp"
				break
		endswitch
		String sweep_name=num2str(i)+"_"+NameOfWave(experiment)
		Duplicate /o Events $CleanupName("Events_"+sweep_name,1)
		Differentiate /METH=1 Events /D=$CleanupName("IEI_"+sweep_name,1) // Get IEIs
		Wave Events=$CleanupName("Events_"+sweep_name,1)
		Wave IEI=$CleanupName("IEI_"+sweep_name,1)
		Events-=start_time
		switch(mode)
			case 0:
				AppendToGraph Events
				break
			case 1:
				AppendToGraph IEI
				break
			case 2:
				AppendToGraph IEI vs Events
				break
			case 3:
				IEI=1/IEI
				AppendToGraph IEI vs Events
				break
			default:
				Print "Invalid mode"
				break
		endswitch
	endfor
	DoUpdate
	MeanTrace(name=NameOfWave(experiment),geometric=1,median=1,interpol=(mode>=2))
	Variable left_max,bottom_max
	switch(mode)
			case 0:
				GetAxis /Q left; left_max=V_max; GetAxis /Q bottom; bottom_max=V_max
				SetAxis left, 0.1, left_max; SetAxis bottom, 1, bottom_max
				ModifyGraph log=1,swapXY=1
				break
			case 1:
				GetAxis /Q left; left_max=V_max;
				ModifyGraph log(left)=1
				//SetAxis left, 0.1, left_max; SetAxis bottom, 0.1, bottom_max
				break
			case 2:
				GetAxis /Q left; left_max=V_max; GetAxis /Q bottom; bottom_max=V_max
				ModifyGraph log=1
				//SetAxis left, 0.1, left_max;
				break
			case 3:
				GetAxis /Q left; left_max=V_max; GetAxis /Q bottom; bottom_max=V_max
				//ModifyGraph log=1
				//SetAxis left, 0.1, left_max;
				break
			default:
				Print "Invalid mode"
				break
		endswitch
	KillWaves OneSweep
End

Function ManyPowerLawPlots(mask)
	String mask
	String cutoffs="200000"
	String experiments=WaveList("*"+mask+"*",";","DIMS:2"),experiment
	Variable i,j,cutoff
	for(i=0;i<ItemsInList(experiments);i+=1)
		experiment=StringFromList(i,experiments)
		for(j=0;j<ItemsInList(cutoffs);j+=1)
			cutoff=str2num(StringFromList(j,cutoffs))
			PowerLawPlot($experiment,clamp="VC",start_time=StimTime(experiment),threshold=cutoff,mode=2)
			TextBox experiment+"_"+num2str(cutoff)
		endfor
	endfor
End

// Calculates the time of stimulation for each sweep in a file based on the maximum value (should be the location of the artifact)
Function StimTime(file[,sweep_num])
	String file
	Variable sweep_num
	Variable i,first,last,maxx1=-10000,max_loc1,maxx2=-10000,max_loc2
	String name
	file=ReplaceString("chan1",file,"ZZZ")
	file=ReplaceString("chan2",file,"ZZZ")
	
	name=ReplaceString("ZZZ",file,"chan1")
	if(waveexists($name))
		first=ParamIsDefault(sweep_num) ? 0 : sweep_num 
		last=ParamIsDefault(sweep_num) ? (dimsize($name,1)-1) : sweep_num
		for(i=first;i<=last;i+=1)
			Duplicate /o /R=()(i,i) $name,column
			WaveStats /Q column; 
			if(V_max > maxx1)
				maxx1=V_max
				max_loc1=V_maxloc
			endif
		endfor
	endif
	
	name=ReplaceString("ZZZ",file,"chan2")
	if(waveexists($name))
		first=ParamIsDefault(sweep_num) ? 0 : sweep_num 
		last=ParamIsDefault(sweep_num) ? (dimsize($name,1)-1) : sweep_num
		for(i=first;i<=last;i+=1)
			Duplicate /o /R=()(i,i) $name,column
			WaveStats /Q column; 
			if(V_max > maxx2)
				maxx2=V_max
				max_loc2=V_maxloc
			endif
		endfor
	endif
	
	if(maxx1>maxx2)
		return max_loc1
	elseif(maxx2>maxx1)
		return max_loc2
	else
		Print "Maxes are equal"
		return 0
	endif
End

// Makes a waterfall plots of cumulative voltage clamp events over the sweeps of an experiment
Function FindAllVCEvents(ExperimentWave)
	Wave ExperimentWave // A matrix where each column is one sweep from an experiment
	Variable i,length,samp_freq=1/dimdelta(ExperimentWave,0),bin_freq=100 // We are downsampling to 100 Hz
	String vce_name=CleanupName(NameOfWave(ExperimentWave)+"_VCE",1)
	Make /o/n=(dimsize(ExperimentWave,0)*bin_freq/samp_freq,dimsize(ExperimentWave,1)) $vce_name=0 // Downsample to 1 kHz for binning
	Wave VCE=$vce_name
	SetScale /P x,0,1/bin_freq,VCE
	length=dimsize(ExperimentWave,0)/samp_freq
	for(i=0;i<dimsize(ExperimentWave,1);i+=1)
		Duplicate /o/R=()(i,i) ExperimentWave sweep
		FindVCEvents(sweep)
		Times2Bins(VCEvents,length=length,scale=bin_freq) // Bin events at 1 kHz
		Wave Bins=VCEvents_Bins
		//Integrate Bins
		VCE[][i]=Bins[p]
	endfor	
	NewImage /K=1 VCE
	KillWaves sweep
End

// Run through even detection to figure out where the cutoff should be
Function TestCutoff(Experiment)
	Wave Experiment
	Display /K=1 /N=CutoffTest
	Variable i,j,cutoff,thresh
	Make /o/n=20 Threshes=0
	Make /o/n=(numpnts(threshes)) NumEvents=0
	Variable rows=dimsize(experiment,0)
	Variable columns=dimsize(experiment,1)
	//Make /o/n=(rows*columns) Matrix=0
	//Matrix=experiment[mod(p,rows)][floor(p/rows)]
	//PrepareVCEvents(Matrix)
	//WaveStats /Q Matrix
	Threshes=((10000000)/(2^p))
	for(i=0;i<columns;i+=1)
		Duplicate /O/R=()(i,i) Experiment Column
		PrepareVCEvents(Column)
		for(j=0;j<numpnts(threshes);j+=1)
			thresh=Threshes[j]
			FindVCEvents(Column,threshold=thresh,no_prepare=1)
			NumEvents[j]+=numpnts(VCEvents)
		endfor
	endfor
	AppendToGraph NumEvents vs Threshes
	ModifyGraph log=1
	DoUpdate
	Interpolate2 /T=1 /Y=Interped Threshes, NumEvents
	Differentiate Interped
	WaveStats /Q Interped; //print V_maxloc
	cutoff=V_maxloc
	Prompt cutoff, "Enter Cutoff: "		
	DoPrompt "Enter Cutoff", cutoff
	if (V_Flag)
		return -1	// User canceled
	endif
	DoWindow /K CutoffTest
	KillWaves threshes,NumEvents,Column,Interped
	return cutoff
End

Function FindReverbPeaks(sweep,thresh)
	Wave sweep
	Variable thresh
	Duplicate /o sweep smoothed
	smoothed=(smoothed>50) ? 0 : smoothed // Suppress artifacts
	smoothed=(smoothed<-1000) ? -1000 : smoothed // Suppress artifacts
	Smooth 1000,smoothed; Differentiate smoothed
	Smooth 1000,smoothed; Differentiate smoothed
	FindLevels /Q smoothed,thresh; Duplicate /O W_FindLevels ReverbPeaks // Find places where the slope crosses a 2000 pA/s threshold
	Differentiate smoothed
	Variable i
	Do
		if(smoothed(ReverbPeaks[i])<0)
			DeletePoints i,1,ReverbPeaks // Get rid of downward level crossings
		else
			i+=1
		endif
	While(i<numpnts(ReverbPeaks))
	KillWaves smoothed,W_FindLevels
End

// Like New Image, but scales from -1000 pA to 0 pA.  To be used on a matrix where each column is a sweep.  
Function ReverbImage(theWave)
	Wave theWave
	NewImage /K=1 theWave
	ModifyImage $NameOfWave(theWave) ctab={0,-1000,Grays,0}
	ModifyGraph height={perUnit,3.6,left}
End

// Returns the fraction of cells that were glutamatergic and gabaergic for each condition
Function ConditionGlutGABA(conditions)
	String conditions
	Wave /T File_Name,Drug_Incubated
	Wave Cells_Stimulated,Glutamatergic_Cells_Stimulated,GABAergic_Cells_Stimulated
	Variable i,j,glut,gaba,total,glut_frac,glut_error,gaba_frac,gaba_error
	String condition
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		glut=0;gaba=0;total=0
		for(j=0;j<numpnts(File_Name);j+=1)
			if(StringMatch(Drug_Incubated[j],condition))
				glut+=Glutamatergic_Cells_Stimulated[j]
				gaba+=GABAergic_Cells_Stimulated[j]
				total+=Cells_Stimulated[j]
			endif
		endfor
		//print glut,gaba,total
		glut_frac=glut/total; glut_error=sqrt(glut_frac*(1-glut_frac)/total)
		gaba_frac=gaba/total; gaba_error=sqrt(gaba_frac*(1-gaba_frac)/total)
		print condition+" ("+num2str(total)+"):" 
		print "Glut "+num2str(glut_frac)+" +/- "+num2str(glut_error)
		print "GABA "+num2str(gaba_frac)+" +/- "+num2str(gaba_error)
	endfor
End

Function ReverbSound(theWave)
	Wave theWave
	WaveStats/Q theWave
	Variable amplitude= 32767 / max(V_Max-V_Avg,V_Avg-V_Min)
	Make/w/o/n=(numpnts(theWave)) root:soundWave = amplitude*(theWave[p+0]-V_Avg)
	Wave soundWave=root:soundWave
	Variable curr_delta=dimdelta(theWave,0)
	Variable fs=5/curr_delta
	SetScale/P x, 0, 1/fs, "", soundWave
	PlaySound soundWave
	KillWaves/Z soundWave
End

// Returns a text wave where each point i is a string containing the reverberations found for sweep i.  
// Assumes that the number of sweeps is the length of the text wave File_Name.    
Function AllReverbs()
	root()
	Wave /T File_Name,Experimenter
	Variable i,j,thresh,r_interval,method
	String sql_select,sql_from,sql_where,name,remove_list,chan 
	for(i=0;i<numpnts(File_Name);i+=1)
		root()
		name=Experimenter[i]+"_"+File_Name[i]
		NewDataFolder /O/S root:Islands:$name
		sql_select="SELECT A1.Experimenter,A1.File_Name,A1.Drug_Incubated,A2.Drug,A2.Conc,"
		sql_select+="A3.Sweep,A3.Channel,A3.Locs,A3.Vals,A3.Average,A3.Scale,A3.Points,A3.Clamp,A3.Baseline "
		sql_from="FROM Island_Record A1,Sweep_Record A2,Sweep_Analysis A3 "
		sql_where="WHERE A1.File_Name=A2.File_Name AND A2.File_Name=A3.File_Name AND A2.Sweep=A3.Sweep AND A3.File_Name='"+File_Name[i]+"' AND A3.Experimenter='"+Experimenter[i]+"'"
		SQLc(sql_select+sql_from+sql_where)
		for(j=0;j<ItemsInList(all_channels);j+=1)
			chan=StringFromList(j,all_channels)
			sql_select="SELECT A2."+chan+"_Start,A2."+chan+"_Pulses,A2."+chan+"_Interval,A2."+chan+"_Ampl,A2."+chan+"_Width "
			SQLc(sql_select+sql_from+sql_where)
		endfor
		Wave Baseline
		Wave /T Channel,Clamp,File_Name,Experimenter
		Make /o/T/n=(numpnts(File_Name)) Reverbs=""
		//Test2(); abort
		for(j=0;j<numpnts(File_Name);j+=1)
			Wave Reconstruction=$ReconstructGeneral(j)
			chan=Channel[j]
			Wave Start=$(chan+"_Start")
			Wave Pulses=$(chan+"_Pulses")
			Wave Interval=$(chan+"_Interval")
			remove_list=Stims2BadRanges(Start[j]/1000,Pulses[j],Interval[j]/1000,before=0.005,after=0.005) // Figure out where stimulus artifacts are likely to occur
			strswitch(Clamp[j])
			case "VC": // For traces recorded in voltage clamp
				thresh=100;r_interval=0.25;method=0
				break
			case "CC": // For traces recorded in current clamp
				thresh=-45;r_interval=0.4;method=0
				break
			default:  
				print "No clamp for index "+num2str(j)+" for file "+name
			endswitch
			Reverbs[j]=FindReverbs(Reconstruction,thresh,r_interval,Baseline[j],clamp=Clamp[j],remove_list=remove_list,method=method) // Find reverberation events for that trace
			print Reverbs[j]
			KillWaves /Z Reconstruction
		endfor
	endfor
End

// Returns a text wave where each point i is a string containing the reverberations found for sweep i.  
// Assumes that the number of sweeps is the length of the text wave File_Name.    
// Use while SQLXOP is still not working.  Run PrepareAccess() and CopyData2Islands() first.  
Function AllReverbs2()
	root()
	Wave /T File_Name,Experimenter
	Variable i,j,thresh,r_interval,method
	String sql_select,sql_from,sql_where,name,remove_list,chan 
	Variable num_files=numpnts(File_Name)
	for(i=0;i<num_files;i+=1)
		root()
		Wave /T File_Name,Experimenter
		name=Experimenter[i]+"_"+File_Name[i]
		SetDataFolder root:Islands:$name
		print name
		Wave Baseline,Sweep
		Wave /T Channel,Clamp
		Make /o/T/n=(numpnts(Sweep)) Reverbs=""
		//Test2(); abort
		for(j=0;j<numpnts(Sweep);j+=1)
			Wave Reconstruction=$ReconstructGeneral(j)
			chan=Channel[j]
			Wave Start=$(chan+"_Start")
			Wave Pulses=$(chan+"_Pulses")
			Wave Interval=$(chan+"_Interval")
			remove_list=Stims2BadRanges(Start[j]/1000,Pulses[j],Interval[j]/1000,before=0.005,after=0.005) // Figure out where stimulus artifacts are likely to occur
			strswitch(Clamp[j])
			case "VC": // For traces recorded in voltage clamp
				thresh=100;r_interval=0.25;method=0
				break
			case "CC": // For traces recorded in current clamp
				thresh=-45;r_interval=0.4;method=0
				break
			default:  
				print "No clamp for index "+num2str(j)+" for file "+name
			endswitch
			Reverbs[j]=FindReverbs(Reconstruction,thresh,r_interval,Baseline[j],clamp=Clamp[j],remove_list=remove_list,method=method) // Find reverberation events for that trace
			print Sweep[j],Reverbs[j]
			KillWaves /Z Reconstruction
		endfor
	endfor
End

// Use this to set flags in Access so I can get all the sweep records for the islands in which CNQX was used at some point.  
Function PrepareAccess()
	NewDataFolder /O root:AccessPaste
	root()
	Wave /T File_Name,Experimenter
	Variable i,j,thresh,r_interval,method
	String sql_select,sql_update,sql_from,sql_set,sql_where,name,remove_list,chan
	
	// Find all islands for which CNQX was used.  
	sql_select="SELECT DISTINCT A1.Experimenter,A1.File_Name,A1.Drug_Incubated "
	sql_from="FROM Island_Record A1,Sweep_Record A2 "
	sql_where="WHERE A1.File_Name=A2.File_Name AND A2.Drug LIKE '%CNQX%'"
	SQLc(sql_select+sql_from+sql_where)
	
	// Set the flag to zero for all sweeps.  
	sql_update="UPDATE Sweep_Analysis "
	sql_set="SET Flag=0 "
	sql_where=""
	SQLc(sql_update+sql_set+sql_where)
	
	// Mark all sweeps for islands in which CNQX was used for that island (but not necessarily that sweep).   
	for(i=0;i<numpnts(File_Name);i+=1)
		root()
		name=Experimenter[i]+"_"+File_Name[i]
		NewDataFolder /O/S root:Islands:$name
		//sql_select="SELECT A1.Experimenter,A1.File_Name,A1.Drug_Incubated,A2.Drug,A2.Conc,"
		//sql_select+="A3.Sweep,A3.Channel,A3.Locs,A3.Vals,A3.Average,A3.Scale,A3.Points,A3.Clamp,A3.Baseline "
		sql_set="SET Flag=1 "
		sql_where="WHERE File_Name='"+File_Name[i]+"' AND Experimenter='"+Experimenter[i]+"'"
		SQLc(sql_update+sql_set+sql_where)
	endfor
	
	// Now you can run a query on flag=1 in Access to get all the sweeps for islands in which CNQX was used.  
End

// Must use this stupid function until SQLXOP is fixed.  First run PrepareAccess().  
Function CopyData2Islands()
	root()
	Wave /T File_Name,Experimenter
	Variable i,j,k,on,off,thresh,r_interval,method
	String name,wave_name,wave_names="Experimenter;File_Name;Drug_Incubated;Drug;Conc;Sweep;Channel;Locs;Vals;Average;Scale;Points;Clamp;Baseline;Flag;"
	wave_names+="R1_Start;R1_Pulses;R1_Interval;R1_Ampl;R1_Width;L2_Start;L2_Pulses;L2_Interval;L2_Ampl;L2_Width;B3_Start;B3_Pulses;B3_Interval;B3_Ampl;B3_Width;"
	Variable num_files=numpnts(File_Name)
	for(i=0;i<num_files;i+=1)
		root()
		Wave /T Experimenter,File_Name
		name=Experimenter[i]+"_"+File_Name[i]
		print name
		SetDataFolder root:AccessPaste
		Wave /T Experimenter,File_Name
		on=-1
		Do
			on+=1
		While(!StringMatch(name,Experimenter[on]+"_"+File_Name[on]))
		off=on-1
		Do
			off+=1
			if(off==numpnts(Experimenter))
				break
			endif
		While(StringMatch(name,Experimenter[off]+"_"+File_Name[off]))
		off-=1
		print on,off
		for(j=0;j<ItemsInList(wave_names);j+=1)
			wave_name=StringFromList(j,wave_names)
			Duplicate /O/R=[on,off] $("root:AccessPaste:"+wave_name) $("root:Islands:"+name+":"+wave_name)
		endfor
	endfor
End

// Uses Reconstruct or ReconstructDWT, depending on the compression method used when the data was first put into the database.  
Function /S ReconstructGeneral(index)
	Variable index
	Wave Average,Scale,Points
	String reconstruction_name="Reconstruction_"+num2str(index)
	Wave /T Locs,Vals
	Variable items=ItemsInList(Locs[index])
	Make /o/n=(items) LocsN=str2num(StringFromList(p,Locs[index]))
	Make /o/n=(items) ValsN=str2num(StringFromList(p,Vals[index]))
	Variable the_scale=(scale>0) ? scale : 0.0001 // 10 kHz by default.  
	
	if(numtype(Average[index])!=0 || (Average[index]==0 && Scale[index]==0 && Points[index]==0)) // If there is no average value in the database, it is from the era when I was doing custom compression
		InterpFromPairs(ValsN,LocsN,reconstruction_name,kHz=0.001/the_scale)
	else // If there is a value, it from the (current) era where I am doing DWT compression.  
		ReconstructDWT(LocsN,ValsN,Average[index],the_scale,Points[index],reconstruction_name)
	endif
	KillWaves /Z LocsN,ValsN
	return reconstruction_name 
End

// In a single sweep, finds all the reverberations (usually 0 or 1) that exceed 'baseline'+'thresh'.  
// A reverberation ends when the signal drops below baseline+thresh when no more level crossings occur for 'interval'.  
Function /S FindReverbs(theWave,thresh,interval,baseline[left,right,clamp,remove_list,versus,method])
	Wave theWave
	Variable thresh // The number of pA/mV below/above baseline theWave has to go for a level crossing (the start of the reverberation).  This number should be positive for voltage clamp or current clamp
	Variable interval // The number of seconds between level crossings for the second crossing to be considered the start of another reverberation
	Variable baseline,left,right // Baseline current/voltage, and left and right edges of the region to scan.  Presumably this is negative for either voltage clamp or current clamp
	String clamp // "VC" for voltage clamp and "CC" for current clamp
	String remove_list // A list of regions to not search for level crossings, e.g. "0.034,0.050;0.98,1.10" represents two regions, one between 0.034 and 0.050, and the other between 0.98 and 1.10
	Wave versus // A wave providing the x-values for the y-values in theWave
	Variable method // Method 0 = using EPSC/EPSP values.  Method 1 = using spike locations only
	//Variable kHz=10 // The sampling rate in kHz
	
	// Get a usable wave
	if(ParamIsDefault(versus))
		Duplicate /o theWave toSearch 
	else // Interpolate theWave building from the x values of versus to create a represenation of the sweep
		InterpFromPairs(theWave,versus,"toSearch",kHz=10)
		Wave toSearch
	endif
	
	// Set the search area
	if(ParamIsDefault(left))
		left=leftx(toSearch) // Start at the left edge of the sweep
	endif
	if(ParamIsDefault(right))
		right=rightx(toSearch) // End at the right edge of the sweep
	endif
	
	// Set each point in a "bad region", i.e. a region that might contain stimulus artifacts, equal to the point immediately preceding that region.  
	if(!ParamIsDefault(remove_list) && !IsEmptyString(remove_list)) // If there are regions to remove from the list of level crossings
		FillBadRangesWithLeft(toSearch,remove_list)
	endif
	
	// Set parameters for voltage clamp or current clamp
	if(ParamIsDefault(clamp))
		clamp="VC"
	endif
	strswitch(clamp)
		case "VC": // Voltage clamp
			toSearch*=-1 // So that all events are upward going
			baseline*=-1 // Flip the baseline correspondingly
			thresh=baseline+thresh // Set the threshold to be the desired level + the baseline
			break 
		case "CC": // Current clamp
			break // Do none of these things for current clamp
		default:
			print "Not a valid clamp : "+clamp
			break
	endswitch
	
	String events="",event
	Variable i,j,mid_point,num_pnts,reverberating,first,last
	// Find events (reverberations) in voltage or current clamp
	if(ParamIsDefault(method))
		method=0
	endif
	switch(method)
		case 0: // Voltage clamp or Current Clamp, using analog levels
			// Search for level crossings
			FindLevels /Q/R=(left,right) toSearch thresh
			Wave levels=W_FindLevels
			num_pnts=numpnts(levels) 
			//print num_pnts
			if(num_pnts>0)
				events+=num2str(levels[0]) // Set the beginning of the first event to the first level crossing
				reverberating=1 // An event has begun (at the first level crossing)
				for(i=1;i<num_pnts-1;i+=1) // From the second to the next-to-last level crossing
					mid_point=(levels[i]+levels[i+1])/2
					if(reverberating==0 && toSearch(mid_point)>thresh) // If an event is not currently occuring and the subsequent region is above the threshold
						events+=num2str(levels[i]) // Mark the i crossing as the start of a new event
						reverberating=1
					elseif(reverberating==1 && levels[i+1]-levels[i]>interval && toSearch(mid_point)<thresh) 
					// If an event is occuring and the next crossing is 'interval' away and the intervening region is below the threshold
						events+=","+num2str(levels[i])+";" // Mark the i crossing as the end of the event
						reverberating=0
					endif
				endfor
				if(reverberating==1) // If a reverberation was still going on before the last level crossing
					if(levels[num_pnts-1]<rightx(toSearch)-interval) 
					// If the last level crossing was more than 'interval' away from the edge of the sweep
						events+=","+num2str(levels[num_pnts-1])+";" // The last level crossing is the end of the reverberation
					else
						events+=","+num2str(rightx(toSearch))+";" // The end of the sweep is the end of the reverberation
					endif
				else // If no reverberation was going on before the last level crossing
					events+=num2str(levels[num_pnts-1])+","+num2str(rightx(toSearch))+";" 
					// The last level crossing is the beginning of a reverberation and the end of the sweep will be taken as the end of that reverberation
				endif
			endif
			break 
		case 1: // Current clamp, using spikes times only
			FindSpikeTimes(toSearch,threshold=thresh,refractory=0.01,left=left,right=right)
			Wave SpikeTimes=SpikeTimes
			num_pnts=numpnts(SpikeTimes)
			// Compute reverberation locations from spike times.  Single spikes with no other spikes within 'interval' will not be their own reverberation.  
			for(i=0;i<num_pnts;i+=1) // If there is at least one spike
				first=SpikeTimes[i] // Set the beginning of the event as the time of the spike
				last=SpikeTimes[i] // Set the end of the event as the time of the spike
				for(i=i;SpikeTimes[i+1]<SpikeTimes[i]+interval && i+1<num_pnts;i+=1)
					last=SpikeTimes[i+1]
				endfor
				if(last!=first)
					if(last>rightX(toSearch)-interval)
						last=rightX(toSearch)
					endif
					events+=num2str(first)+","+num2str(last)+";"
				endif
			endfor
			break
		default:
			break
	endswitch
	return events
End

Function ReverbIslandSummaries()
	root()
	Wave /T Experimenter,File_Name
	Variable i,j,k
	Variable num_files=numpnts(File_Name)
	String event,name,min_durations="0.5;1;2",wave_name
	Variable left,right,mean_ampl,min_duration
	
	for(i=0;i<num_files;i+=1)
		root()
		Wave /T File_Name,Experimenter
		name=Experimenter[i]+"_"+File_Name[i]
		print name
		SetDataFolder root:Islands:$name
		Wave /T Reverbs
		
		for(j=0;j<ItemsInList(min_durations);j+=1)
			min_duration=NumFromList(j,min_durations)
			wave_name=CleanUpName("ReverbDurations"+num2str(min_duration),1)
			Make /o/n=(numpnts(Reverbs)) $wave_name
			Wave ReverbDurations=$wave_name
			ReverbDurations=0
		endfor
		
		for(j=0;j<numpnts(Reverbs);j+=1)
			print j
			for(k=0;k<ItemsInList(min_durations);k+=1)
				min_duration=NumFromList(k,min_durations)
				wave_name=CleanUpName("ReverbDurations"+num2str(min_duration),1)	
				Wave ReverbDurations=$wave_name
				ReverbDurations[j]=NumPairsOfSize(Reverbs[j],min_duration)
			endfor
//			for(j=0;j<ItemsInList(Reverbs[i]);j+=1)
//				event=StringFromList(j,Reverbs[i])
//				if(PairDiff(event)>0.5)
//					Wave locs=$("root:Sweeps:Locs_"+num2str(i))
//					Wave vals=$("root:Sweeps:Vals_"+num2str(i))
//					Wave Baseline=root:Baseline
//					InterpFromPairs(vals,locs,"theEvent",kHz=10)
//					left=str2num(StringFromList(0,event,","))
//					right=str2num(StringFromList(1,event,","))
//					mean_ampl=mean(theEvent,left,right)-Baseline[i]
//					//print left,right,mean_ampl
//					//Display /K=1 theEvent
//					//return 0
//					file[10]+=mean_ampl // Sum of average current in all the events of at least 500 ms duration
//					KillWaves theEvent
//				else
//				endif
//			endfor
		endfor
	endfor
End

Function MakeWavesForEachDrug()
	root()
	Wave /T Experimenter,File_Name,Drug_Incubated 
	Variable i,j,k
	Variable num_files=numpnts(File_Name)
	String event,name,min_durations="0.5;1;2",wave_name
	String curr_drug,curr_conc,last_drug,last_conc,drug_name
	Variable min_duration,sweeps_in_drug
	
	for(i=0;i<num_files;i+=1)
		root()
		Wave /T File_Name,Experimenter
		name=Experimenter[i]+"_"+File_Name[i]
		print name
		SetDataFolder root:Islands:$name
		Wave R1_Ampl,L2_Ampl,B3_Ampl
		
		for(j=0;j<ItemsInList(min_durations);j+=1)
			min_duration=NumFromList(j,min_durations)
			wave_name=CleanUpName("ReverbDurations"+num2str(min_duration),1)
			Make /o/n=(numpnts(Reverbs)) $wave_name
			Wave ReverbDurations=$wave_name
			Wave /T Drug; Wave /T Conc
			
			last_drug=Drug[0]
			last_conc=Conc[0]
			sweeps_in_drug=0
			for(k=0;k<numpnts(Drug);k+=1)
				curr_drug=Drug[k]
				curr_conc=Conc[k]
				if(StringMatch(curr_drug,last_drug) && StringMatch(curr_conc,last_conc))
					sweeps_in_drug+=1
					if(sweeps_in_drug>=5 && (R1_Ampl[k]>=100 || L2_Ampl[k]>=100 || B3_Ampl[k]>=100))
						drug_name=CleanUpName(curr_drug+"_"+curr_conc+"_"+num2str(min_duration),1)
						if(!waveexists($drug_name))
							Make /o/n=0 $drug_name
						endif
						Wave DrugConc=$drug_name
						Redimension /n=(numpnts(DrugConc)+1) DrugConc
						DrugConc[numpnts(DrugConc)-1]=ReverbDurations[k]
						//KillWaves /Z $drug_name
					endif
				else
					sweeps_in_drug=1
				endif
				last_drug=Drug[k]
				last_conc=Conc[k]
			endfor
		endfor
	endfor
End

// Compare drug sensitivity across conditions
Function DrugsAcrossConditions(conditions,drug_concs,min_duration)
	String conditions,drug_concs
	Variable min_duration
	// drug_concs, e.g ";CNQX,200;CNQX,300"
	root()
	Wave /T Experimenter,File_Name,Drug_Incubated 
	Variable i,j,k,m
	Variable num_files=numpnts(File_Name)
	String event,name,wave_name
	String drug_name,condition,drug_conc
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		Display /K=1 /N=condition
		for(j=0;j<num_files;j+=1)
			if(StringMatch(Drug_Incubated[j],condition))
				name=Experimenter[j]+"_"+File_Name[j]
				print name
				SetDataFolder root:Islands:$name
				Make /o/n=(ItemsInList(drug_concs)) DurationsDrugConcs=NaN
				for(k=0;k<ItemsInList(drug_concs);k+=1)
					drug_conc=StringFromList(k,drug_concs)
					wave_name=CleanUpName(StringFromList(0,drug_conc,",")+"_"+StringFromList(1,drug_conc,",")+"_"+num2str(min_duration),1)
					if(waveexists($wave_name))
						WaveStats /Q $wave_name
						DurationsDrugConcs[k]=V_avg
					endif
				endfor
				AppendToGraph DurationsDrugConcs
			endif
		endfor
		Label bottom "Condition"
		ModifyGraph mode=4,marker=8,gaps=0
		ScrambleColors()
		root()
		Make /o/n=(ItemsInList(drug_concs)) TickNums=p;
		Make /o/T/n=(ItemsInList(drug_concs)) TickLabels=StringFromList(p,drug_concs)
		ModifyGraph userticks(bottom)={TickNums,TickLabels}
		
	endfor
End

Function ReverbFileSummaries(conditions)
	String conditions
	Wave /T Reverbs=root:Reverbs
	Wave /T Drug_Incubated=root:Drug_Incubated
	Wave /T Drug_Applied=root:Drug
	Wave /T Clamp=root:Clamp
	Wave /T FileName=root:File_Name // A text wave of file names
	String files=FileList()
	SVar druginc_list=root:druginc_list
	String file_name,drug
	Variable i,j,index; String condition
	Variable num_file_attributes=11 // The number of attributes that will be listed for each file (island), e.g. mean duration, mean amplitude, etc. 
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:Summaries
	// Make a wave for each file listing its reverberation attributes
	for(i=0;i<ItemsInList(files);i+=1)
		file_name=StringFromList(i,files)
		KillWaves /Z $file_name
		Make /o/n=(num_file_attributes) $file_name=0
	endfor
	
	String event
	Variable left,right,mean_ampl
	// Go through each sweep, and if no drug was bath applied, add information to the file wave for the file that the sweep belongs to
	for(i=0;i<numpnts(Reverbs);i+=1)
		print i
		if(IsEmptyString(Drug_Applied[i]) && StringMatch(Clamp[i],"VC")) // If no drug was bath applied and sweep was collected in voltage clamp
			Wave file=$FileName[i]
			// There should now be a calculation of 'num_attributes' attributes
			file[0]+=1 // Total sweeps for that cell
			file[1]+=(ItemsInList(Reverbs[i])>0 ? 1 : 0) // Total sweeps with an event
			file[2]+=ItemsInList(Reverbs[i]) // Total events
			file[3]+=NumPairsOfSize(Reverbs[i],0.125)
			file[4]+=NumPairsOfSize(Reverbs[i],0.25)
			file[5]+=NumPairsOfSize(Reverbs[i],0.5) // Total events of at least 500 ms duration
			file[6]+=NumPairsOfSize(Reverbs[i],1) // Total events of at least 1s duration
			file[7]+=NumPairsOfSize(Reverbs[i],2) // Total events of at least 2s duration
			file[8]+=NumPairsOfSize(Reverbs[i],4) // Total events of at least 4s duration
			file[9]+=NumPairsOfSize(Reverbs[i],8) // Total events of at least 8s duration
			for(j=0;j<ItemsInList(Reverbs[i]);j+=1)
				event=StringFromList(j,Reverbs[i])
				if(PairDiff(event)>0.5)
					Wave locs=$("root:Sweeps:Locs_"+num2str(i))
					Wave vals=$("root:Sweeps:Vals_"+num2str(i))
					Wave Baseline=root:Baseline
					InterpFromPairs(vals,locs,"theEvent",kHz=10)
					left=str2num(StringFromList(0,event,","))
					right=str2num(StringFromList(1,event,","))
					mean_ampl=mean(theEvent,left,right)-Baseline[i]
					//print left,right,mean_ampl
					//Display /K=1 theEvent
					//return 0
					file[10]+=mean_ampl // Sum of average current in all the events of at least 500 ms duration
					KillWaves theEvent
				else
				endif
			endfor
		endif
	endfor
End

// Computes a statistic (to be changed manually) for the duration of reveberations, and plots a cumulative histogram showing that statistic.  
Function StatReverbDuration(conditions[,mode])
	String conditions
	Variable mode
	mode=ParamIsDefault(mode) ? 0 : mode // Mode is 0 to compute the statistics within a network first, and mode is 1 to just compute across all event.  
	Variable min_duration=0.2 // The minimum event (reverberation) duration to even be counted in this analysis.  
	Wave /T Reverbs=root:Reverbs
	Wave /T Drug_Incubated=root:Drug_Incubated
	Wave /T Drug_Applied=root:Drug
	Wave /T Clamp=root:Clamp
	Wave /T FileName=root:File_Name // A text wave of file names
	String files=FileList()
	SVar druginc_list=root:druginc_list
	String file_name,drug
	Variable i,j,k,index,stat; String condition
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:Summaries
	// Make a wave for each file listing its reverberation attributes
	for(i=0;i<numpnts(FileName);i+=1)
		Make /o/n=0 $(FileName[i]+"_ReverbDurations")
	endfor
	String event
	Variable left,right,mean_ampl
	// Go through each sweep, and if no drug was bath applied, add information to the file wave for the file that the sweep belongs to
	for(i=0;i<numpnts(Reverbs);i+=1)
		//print i
		if(IsEmptyString(Drug_Applied[i]) && StringMatch(Clamp[i],"VC")) // If no drug was bath applied and sweep was collected in voltage clamp
			Wave ReverbDurations=$(FileName[i]+"_ReverbDurations")
			for(j=0;j<ItemsInList(Reverbs[i]);j+=1)
				event=StringFromList(j,Reverbs[i])
				if(PairDiff(event)>min_duration)
					InsertPoints 0,1,ReverbDurations
					ReverbDurations[0]=PairDiff(event)
				endif
			endfor
		endif
	endfor
	Display /K=1 /N=gStatReverbDurations
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		Make /o/n=0 $(condition+"_StatReverbDurations")
		Wave StatReverbDurations=$(condition+"_StatReverbDurations")
		for(j=0;j<ItemsInList(files);j+=1)
			file_name=StringFromList(j,files)
			drug=StringFromList(j,druginc_list)
			if(StringMatch(condition,drug))
				Wave ReverbDurations=$(file_name+"_ReverbDurations")
				if(numpnts(ReverbDurations)>0)
					if(mode==0)
						InsertPoints 0,1,StatReverbDurations
						// Compute your statistic here
						WaveStats /Q ReverbDurations; stat=V_max
						//
						StatReverbDurations[0]=stat
					elseif(mode==1)
						for(k=0;k<numpnts(ReverbDurations);k+=1)
							InsertPoints 0,1,StatReverbDurations
							// Compute your statistic here
							stat=ReverbDurations[k]
							//
							StatReverbDurations[0]=stat
						endfor
					endif
				endif
			endif
		endfor
		Sort StatReverbDurations,StatReverbDurations
		SetScale x,0,1,StatReverbDurations
		Condition2Color(condition); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) StatReverbDurations
	endfor
	SetDataFolder $curr_folder
End


// For each file, add its information to the condition wave for the corresponding condition (e.g. incubated in TTX)
// Assumes ReverbFileSummaries has already been run.  
Function ReverbConditionSummaries(conditions)
	String conditions // List of conditions, e.g. "Ctl;TTX"
	Variable num_condition_attributes=22; // The number of attributes that will be listed for each condition, e.g. TTX, etc. 
	// Make a wave for each condition summarizing the average over all files in that condition
	Variable i,j; String condition,file_name
	SetDataFolder root:Summaries
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		Make /o/n=(0,num_condition_attributes) $condition=0
	endfor
	String files=FileList()
	SVar druginc_list=root:druginc_list
	Variable at_least=3
	for(i=0;i<ItemsInList(files);i+=1)
		file_name=StringFromList(i,files)
		Wave file=$file_name
		condition=StringFromList(i,druginc_list)
		Wave Cond=$condition
		Redimension /n=(dimsize(Cond,0)+1,num_condition_attributes) Cond
		Cond[dimsize(Cond,0)-1][0]=file[3]>=at_least
		Cond[dimsize(Cond,0)-1][1]=file[4]>=at_least
		Cond[dimsize(Cond,0)-1][2]=file[5]>=at_least
		Cond[dimsize(Cond,0)-1][3]=file[6]>=at_least
		Cond[dimsize(Cond,0)-1][4]=file[7]>=at_least // Attribute 7 will be whether or not an island had more than 2 reverberations.  
		Cond[dimsize(Cond,0)-1][5]=file[8]>=at_least
		Cond[dimsize(Cond,0)-1][6]=file[9]>=at_least	
		
		Cond[dimsize(Cond,0)-1][7]=file[3]>=2
		Cond[dimsize(Cond,0)-1][8]=file[4]>=2
		Cond[dimsize(Cond,0)-1][9]=file[5]>=2
		Cond[dimsize(Cond,0)-1][10]=file[6]>=2
		Cond[dimsize(Cond,0)-1][11]=file[7]>=2 // Attribute 7 will be whether or not an island had more than 2 reverberations.  
		Cond[dimsize(Cond,0)-1][12]=file[8]>=2
		Cond[dimsize(Cond,0)-1][13]=file[9]>=2	
		
		Cond[dimsize(Cond,0)-1][14]=file[3]>=1
		Cond[dimsize(Cond,0)-1][15]=file[4]>=1
		Cond[dimsize(Cond,0)-1][16]=file[5]>=1
		Cond[dimsize(Cond,0)-1][17]=file[6]>=1
		Cond[dimsize(Cond,0)-1][18]=file[7]>=1 // Attribute 7 will be whether or not an island had more than 2 reverberations.  
		Cond[dimsize(Cond,0)-1][19]=file[8]>=1
		Cond[dimsize(Cond,0)-1][20]=file[9]>=1	
		
		Cond[dimsize(Cond,0)-1][21]=-file[10]/file[5] // Mean current during a reverberation (at least 500 ms long)	
	endfor
	
	// Get stats for each condition 
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		for(j=0;j<num_condition_attributes;j+=1)
			Duplicate /O/R=[][j,j] $condition condition_attribute
			WaveStats /Q condition_attribute; print condition+" "+num2str(j)+": "+num2str(V_avg)+"+/-"+num2str(V_sdev/sqrt(V_npnts))
			KillWaves condition_attribute
		endfor
	endfor
	SetDataFolder root:
End

// Plots the mean and SEM of each attribute for each condition (one wave for each condition, each point is an attribute).  
// Good if the attributes are a sequence of cutoff values, for example.  
Function PlotReverbProbs(conditions)
	String conditions
	Variable i,j,k
	String condition
	SetDataFolder root:Summaries
	Make /o/n=7 AtLeast=2^(x-3)
	for(i=0;i<3;i+=1)
		Display /K=1 /N=$("At_Least_"+num2str(i))
		for(j=0;j<ItemsInList(conditions);j+=1)
			condition=StringFromList(j,conditions)
			Wave Cond=$condition
			Make /o/n=7 $("Condition_"+num2str(j)+"_Attribute_"+num2str(i)+"_Means")
			Wave means=$("Condition_"+num2str(j)+"_Attribute_"+num2str(i)+"_Means")
			Make /o/n=7 $("Condition_"+num2str(j)+"_Attribute_"+num2str(i)+"_SEMs")
			Wave sems=$("Condition_"+num2str(j)+"_Attribute_"+num2str(i)+"_SEMs")
			for(k=0;k<7;k+=1)
				Duplicate /o/R=[][7*i+k,7*i+k] Cond $("Condition_Attribute_"+num2str(i))
				WaveStats /Q $("Condition_Attribute_"+num2str(i))
				means[k]=100*V_avg // Get a percentage
				sems[k]=100*V_sdev/sqrt(V_npnts)
				KillWaves $("Condition_Attribute_"+num2str(i))
			endfor
			CleanAppend(NameOfWave(means),color=Condition2Color(condition),versus="AtLeast")
			ErrorBars $NameOfWave(means),Y wave=($NameOfWave(sems),$NameOfWave(sems)) 
		endfor
		Label left "% of Islands showing >= "+num2str(3-i)+" Reverberation(s)"
		Label bottom "Reverberation of at least this many seconds"
		ModifyGraph log(bottom)=2
	endfor
	SummarizeColumn(conditions,22,name="Mean_Ampl_500_ms")
	KillVariables /Z red,green,blue
	SetDataFolder root:
End

Function SummarizeColumn(conditions,column[,name])
	String conditions
	Variable column
	String name
	if(ParamIsDefault(name))
		name="Column "+num2str(column)+" Summary"
	endif
	SetDataFolder root:Summaries
	Display /K=1 /N=$name
	Make /o/n=(ItemsInList(conditions)) MeanCurrents,MeanCurrents_sems
	List2TextWave(conditions,name="W_Conditions"); Wave /T W_Conditions=W_Conditions
	Make /o/n=(ItemsInList(conditions),3) ColorWaveZ=0
	Variable i; String condition
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		Duplicate /o/R=[][column,column] $condition $(condition+"_"+name) // Mean currents for reverbs in voltage clamp of at least 500 ms duration
		Wave data=$(condition+"_"+name)
		//data*=-1 // For cases where I need to flip the sign
		WaveStats /Q data
		MeanCurrents[i]=V_Avg
		MeanCurrents_sems[i]=V_sdev/sqrt(V_npnts)
		Condition2Color(condition); NVar red,green,blue
		ColorWaveZ[i][]={{red},{green},{blue}}
		DeleteNaNs(data)
		Sort data,data
		SetScale /I x,1/numpnts(data),1,data
		AppendToGraph /c=(red,green,blue) /B=cumul_bottom /L=cumul_left data
	endfor
	AppendToGraph /B=bar_bottom /R=bar_right MeanCurrents vs W_Conditions
	ErrorBars MeanCurrents,Y wave=(MeanCurrents_sems,MeanCurrents_sems)
	SetAxis bar_right -300,0
	ModifyGraph zColor(MeanCurrents)={root:Summaries:ColorWaveZ,*,*,directRGB}
	ModifyGraph hbFill=2,axisenab(cumul_bottom)={0,0.49},axisenab(bar_bottom)={0.51,1}
	ModifyGraph freePos(cumul_left)={0,cumul_bottom}, freePos(bar_right)={i+1,bar_bottom}
	ModifyGraph fsize=8, btLen=1
	ModifyGraph freePos(cumul_bottom)={0,cumul_left}
	GetAxis /Q bar_right
	ModifyGraph freePos(bar_bottom)={V_min,cumul_left}
	Label cumul_bottom "Cumulative Probability"
	SetDataFolder root:
End

// Gives each sweep a Locs wave and Vals wave of its own.
// Takes the text waves Locs and the wave Vals as input.  Each of these has one entry (a string) for each sweep
Function LocsAndVals2Waves(Locs,Vals)
	Wave /T Locs,Vals
	Make /o/n=(numpnts(Locs)) TimeToMake=NaN,WaveMade=NaN,NumPoints=NaN
	Wave TimeToMake=root:TimeToMake
	Wave WaveMade=root:WaveMade
	Wave NumPoints=root:NumPoints
	NewDataFolder /O/S root:sweeps
	Variable i,thyme
	for(i=0;i<numpnts(Locs);i+=1)
		print i
		thyme=ticks
		Make /n=(ItemsInList(Locs[i])) $("Locs_"+num2str(i)) = str2num(StringFromList(p,Locs[i]))
		Make /n=(ItemsInList(Vals[i])) $("Vals_"+num2str(i)) = str2num(StringFromList(p,Vals[i]))
		//String2Wave(Locs[i],name="Locs_"+num2str(i))
		//String2Wave(Vals[i],name="Vals_"+num2str(i))
		timeToMake[i]=(ticks-thyme)/60
		waveMade[i]=i
		NumPoints[i]=ItemsInList(Locs[i])
	endfor
	Sort TimeToMake,TimeToMake,WaveMade,NumPoints
	SetScale /I x,0,1,timeToMake
	Display /K=1 TimeToMake vs NumPoints
	Edit /K=1 waveMade
	AppendToTable timeToMake,NumPoints
	SetDataFolder root:
End

// Tells what island, sweep, and channel a sweep came from
Function SweepInfo(num)
	Variable num
	Wave /T File_Name=root:File_Name
	Wave /T Channel=root:Channel
	Wave Sweep=root:Sweep
	print File_Name[num]+" "+num2str(Sweep[num])+" "+Channel[num]
End

// Returns a list of all files (islands)
Function /S FileList()
	Wave /T FileNames=root:File_Name
	Wave /T Drug_Incubated=root:Drug_Incubated
	String /G root:file_list=""; SVar file_list=root:file_list
	String /G root:druginc_list=""; SVar druginc_list=root:druginc_list
	Variable i
	for(i=0;i<numpnts(FileNames);i+=1)
		if(WhichListItem(FileNames[i],file_list)==-1)
			file_list+=FileNames[i]+";"
			druginc_list+=Drug_Incubated[i]+";"
		endif
	endfor
	return file_list
End

Function /S IncubateList()
	Wave /T FileNames=root:File_Name
	String list=""
	Variable i
	for(i=0;i<numpnts(FileNames);i+=1)
		if(WhichListItem(FileNames[i],list)==-1)
			list+=FileNames[i]+";"
		endif
	endfor
	return list
End

// Computes a statistic (to be changed manually) for the ISIs for each condition, and plots a cumulative histogram showing that statistic.  
// Assumes there is already a wave of ISIs for each island.  
Function StatReverbISIs(conditions[,mode])
	String conditions
	Variable mode
	mode=ParamIsDefault(mode) ? 0 : mode // Mode is 0 to compute the statistics within a network first, and mode is 1 to just compute across all event.  
	Wave /T Reverbs=root:Reverbs
	Wave /T Drug_Incubated=root:Drug_Incubated
	Wave /T Drug_Applied=root:Drug
	Wave /T Clamp=root:Clamp
	Wave /T FileName=root:File_Name // A text wave of file names
	String files=FileList()
	SVar druginc_list=root:druginc_list
	String file_name,drug
	Variable i,j,k,index,stat; String condition
	String curr_folder=GetDataFolder(1)
	SetDataFolder root:ISIs
	Display /K=1 /N=gStatISIs
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		Make /o/n=0 $(condition+"_StatISIs")
		Wave StatISIs=$(condition+"_StatISIs")
		for(j=0;j<ItemsInList(files);j+=1)
			file_name=StringFromList(j,files)
			drug=StringFromList(j,druginc_list)
			if(StringMatch(condition,drug))
				Wave /Z ISIs=$("ISIs_"+file_name)
				if(waveexists(ISIs) && numpnts(ISIs)>0)
					if(mode==0)
						InsertPoints 0,1,StatISIs
						// Compute your statistic here
						WaveStats /Q ISIs; stat=Median2(ISIs); print stat
						//
						StatISIs[0]=stat
					elseif(mode==1)
						for(k=0;k<numpnts(ISIs);k+=1)
							InsertPoints 0,1,StatISIs
							// Compute your statistic here
							stat=ISIs[k]
							//
							StatISIs[0]=stat
						endfor
					endif
				endif
			endif
		endfor
		Sort StatISIs,StatISIs
		SetScale x,0,1,StatISIs
		Condition2Color(condition); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) StatISIs
	endfor
	SetDataFolder $curr_folder
End

Function GetIslandISIs()
	String files=FileList()
	Wave /T FileNames=root:File_Name
	Wave /T Reverbs=root:Reverbs
	Wave /T Clamp=root:Clamp
	Variable i
	NewDataFolder /O/S root:ISIs
	String spike_times="",test=""
	for(i=0;i<numpnts(FileNames);i+=1)
	//for(i=1;i<2;i+=1)
		print i
		if(!cmpstr(Clamp[i],"CC"))
			if(WhichListItem(FileNames[i],files)!=-1) // If FileNames[i] is still on the list files
				Make /o/n=0 $("ISIs_"+FileNames[i])
				Make /o/n=0 $("ISIs_time_"+FileNames[i])
				files=RemoveFromList(FileNames[i],files) // Remove it
			endif
			Wave ISIs=$("ISIs_"+FileNames[i])
			Wave ISIs_time=$("ISIs_time_"+FileNames[i])
			spike_times=Reverbs2SpikeTimes(i,Reverbs[i])
			print spike_times
			ISIsfromList(spike_times); // Produces the wave of ISIs called listISIs
			Wave listISIs=listISIs
			Wave since_first=listISIs_time_since_first
			print listISIs
			Concatenate /NP {listISIs}, ISIs
			Concatenate /NP {since_first}, ISIs_time
			if(numpnts(listISIs)>0)
				WaveStats /Q listISIs;
				if(V_max>2)
					test+=num2str(i)+";"
				endif
			endif
		endif
	endfor
	SetDataFolder root:
	print test
End

// Gets time of spikes relative to reverberation onset
Function GetIslandSpikeTimes([relative,dimensionality])
	Variable relative // Relative to reverberation onset or not
	Variable dimensionality // Use 1 if you just want a column of spike times, and 2 if you care which reverberation each spike time came from
	if(ParamIsDefault(relative))
		relative=0
	endif
	if(ParamIsDefault(dimensionality))
		dimensionality=1
	endif
	String files=FileList()
	Wave /T FileNames=root:File_Name
	Wave /T Reverbs=root:Reverbs
	Wave /T Clamp=root:Clamp
	Variable i,j,rows,columns
	NewDataFolder /O/S root:SpikeTimes
	String spike_times="",sub_spike_times="",test="",file
	for(i=0;i<numpnts(FileNames);i+=1)
	//for(i=1;i<2;i+=1)
		print i
		if(!cmpstr(Clamp[i],"CC"))
			if(WhichListItem(FileNames[i],files)!=-1) // If FileNames[i] is still on the list files
				Make /o/n=0 $("SpikeTimes_"+FileNames[i])
				Make /o/n=0 $("SpikeTimes_"+FileNames[i])
				files=RemoveFromList(FileNames[i],files) // Remove it
			endif
			Wave SpikeTimes=$("SpikeTimes_"+FileNames[i])
			spike_times=Reverbs2SpikeTimes(i,Reverbs[i],relative=relative)
			//print spike_times
			for(j=0;j<ItemsInList(spike_times);j+=1)
				sub_spike_times=StringFromList(j,spike_times) // Spike times for reverberation j in sweep i
				sub_spike_times=ReplaceString(",",sub_spike_times,";") // Turn commas into semicolons
				String2Wave(sub_spike_times,name="listSpikes")
				Wave listSpikes
				if(dimensionality==1)
					Concatenate /NP {listSpikes}, SpikeTimes // Use this for a column of all spike times, independent of which reverberation they occurred in.  
				elseif(dimensionality==2)
					rows=dimsize(SpikeTimes,0); columns=dimsize(SpikeTimes,1)
					Redimension /n=(max(rows,numpnts(listSpikes)),columns+1) SpikeTimes
					SpikeTimes[][columns]=listSpikes[p] // Use this for a matrix of spike times, where each column has spike times for one reverberation 
					SpikeTimes[numpnts(listSpikes),][columns]=NaN
				else 
					Print "Not a valid dimensionality : "+num2str(dimensionality)+" (GetIslandSpikeTimes)"
				endif
			endfor
		endif
	endfor
	files=FileList()
	for(i=0;i<ItemsInList(files);i+=1)
		file=StringFromList(i,files)
		if(exists("SpikeTimes_"+file))
			Zeros2NaNs($("SpikeTimes_"+file)) // Turn all the zeros into NaNs so they don't screw up the statistics.  
		endif
	endfor
	SetDataFolder root:
End

// Makes a wave of all the spike times for each reveberation.  
// They can be relative to reverberation start time (relative=1) or to the start of the sweep (relative=0)
Function GetAllSpikeTimes([relative])
	Variable relative
	String files=FileList()
	Wave /T FileNames=root:File_Name
	Wave /T Reverbs=root:Reverbs
	Wave /T Clamp=root:Clamp
	Duplicate /o/T Reverbs SpikesTimes
	SpikesTimes=""
	Variable i
	for(i=0;i<numpnts(FileNames);i+=1)
		print i
		if(!cmpstr(Clamp[i],"CC"))
			SpikesTimes[i]=Reverbs2SpikeTimes(i,Reverbs[i],relative=relative)
		endif
	endfor
End

// Computes the firing rate for each condition in the first 'num' seconds
Function FiringRateInTheFirst(conditions,num[,mode])
	String conditions
	Variable num,mode
	mode=ParamIsDefault(mode) ? 0 : mode // Mode is 0 to compute the statistics within a network first, and mode is 1 to just compute across all event.  
	Wave /T Reverbs=root:Reverbs
	Wave /T Drug_Incubated=root:Drug_Incubated
	Wave /T Drug_Applied=root:Drug
	Wave /T Clamp=root:Clamp
	Wave /T FileName=root:File_Name // A text wave of file names
	String files=FileList()
	SVar druginc_list=root:druginc_list
	String file_name,drug
	Variable i,j,k,index1,index2,stat,num_reverbs; String condition
	String curr_folder=GetDataFolder(1)
	SetDataFolder root:SpikeTimes
	Display /K=1 /N=gFiringRateInTheFirst
	Variable min_duration=0.25 // Minimum duration of a reverberation.  
	Make /o/n=(ItemsInList(conditions)) FRITFMeans,FRITFSEMs
	Make /o/n=(ItemsInList(conditions),3) FRITFColors
	Wave FRITFLabels=$List2TextWave(conditions,name="FRITFLabels")
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		Make /o/n=0 $(condition+"_FRITF")
		Wave FRITF=$(condition+"_FRITF")
		for(j=0;j<ItemsInList(files);j+=1)
			file_name=StringFromList(j,files)
			drug=StringFromList(j,druginc_list)
			if(StringMatch(condition,drug))
				Wave /Z Spikes=$("SpikeTimes_"+file_name)
				// MUST BE the two dimensional form of spike times, with one row for each reverberation.  See dimensionality flag in GetIslandSpikeTimes
				if(waveexists(Spikes) && numpnts(Spikes)>0)
					if(mode==0)
						for(k=0;k<dimsize(Spikes,1);k+=1)
							Duplicate /o/R=[][k,k] Spikes Spikes2
							Redimension /n=(numpnts(Spikes2)) Spikes2
							WaveStats /Q Spikes2
							if(V_npnts>0 && V_max>min_duration)
								DeleteNans(Spikes2)
								Sort Spikes2,Spikes2
								stat+=NumBetween(Spikes2,0,num)
								num_reverbs+=1
							endif
						endfor
						InsertPoints 0,1,FRITF
						FRITF[0]=stat/num_reverbs
					elseif(mode==1)
						for(k=0;k<dimsize(Spikes,1);k+=1)
							Duplicate /o/R=[][k,k] Spikes Spikes2
							Redimension /n=(numpnts(Spikes2)) Spikes2
							WaveStats /Q Spikes2
							if(V_npnts>0 && V_max>min_duration)
								DeleteNans(Spikes2)
								Sort Spikes2,Spikes2
								stat=NumBetween(Spikes2,0,num)
								//print stat,Spikes2
								InsertPoints 0,1,FRITF
								FRITF[0]=stat
							endif
						endfor
					endif
					KillWaves Spikes2
				endif
			endif
		endfor
		Sort FRITF,FRITF
		SetScale x,0,1,FRITF
		FRITF/=num
		WaveStats /Q FRITF
		FRITFMeans[i]=V_avg
		FRITFSEMs[i]=V_sdev/sqrt(V_npnts)
		Condition2Color(condition); NVar red,green,blue
		FRITFColors[i][]={red,green,blue}
	endfor
	AppendToGraph /c=(red,green,blue) FRITFMeans vs FRITFLabels
	ErrorBars FRITFMeans,Y wave=(FRITFSEMs,FRITFSEMs)
	ModifyGraph zColor(FRITFMeans)={FRITFColors,*,*,directRGB}
	SetAxis left 0,25
	SetDataFolder $curr_folder
End

End

// Gets PSTHs for every reverberation
Function ReverbPSTHs(bin_size)
	Variable bin_size
	Wave /T Reverbs=root:Reverbs
	Wave /T Spikes=root:Spikes
	Wave /T Clamp=root:Clamp
	Variable i,j,left,right
	String reverb,spike_list
	NewDataFolder /O/S root:PSTHs
	for(i=0;i<numpnts(Reverbs);i+=1) // For each sweep
		if(StringMatch(Clamp[i],"CC")) // If it is in current clamp
			for(j=0;j<ItemsInList(Reverbs[i]);j+=1) // For each reverberation in that sweep
				reverb=StringFromList(j,Reverbs[i])
				left=str2num(StringFromList(0,reverb,",")) // Get the start time of the reverberation
				right=str2num(StringFromList(1,reverb,",")) // Get the end time of the reverberation
				Make /o/n=(ceil((right-left)/bin_size)) $("Hist_"+num2str(i)+"_"+num2str(j)) // Setup the bins
				Wave Hist=$("Hist_"+num2str(i)+"_"+num2str(j))
				SetScale /P x,0,bin_size,Hist // Scale the histogram wave to have units that match the bin sizes
				spike_list=StringFromList(j,Spikes[i])
				spike_list=ReplaceString(",",spike_list,";") // Changes commas to semicolons
				String2Wave(spike_list,name="SpikeWave")
				Wave SpikeWave // The output of String2Wave
				if(numpnts(SpikeWave)>0)
					Histogram /B=2 SpikeWave, Hist // Make the histogram
					if(Hist[0]>0)
						Hist[0]-=1 // Subtract the first spike, since it is probably due to the stimulus
					endif
					Hist/=bin_size
				endif
			endfor
		endif
		print i
	endfor
End

Function PSTHsByCondition(conditions[,min_duration])
	String conditions
	Variable min_duration // The minimum reverberation duration that will be used for these PSTHs
	Variable i,j,k,max_duration=0 // Max Duration is not the opposite of min_duration
	String condition,reverb_list,reverb,hist,PSTH_list
	SetDataFolder root:PSTHs
	Display /K=1 /N=PSTH_Avg
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		reverb_list=ListByCondition(condition,"CC") 
		// A list of all sweep numbers from that condition that are in Current Clamp
		PSTH_list=""; max_duration=0 // Reset
		Condition2Color(condition); NVar r,g,b
		Display /K=1 /N=$("PSTH_"+condition)
		for(j=0;j<ItemsInList(reverb_list);j+=1) // Scan through all the sweeps for that condition
			reverb=StringFromList(j,reverb_list)
			for(k=0;k<Inf;k+=1) // Scan through all the reverbs for that sweep
				if(exists("Hist_"+reverb+"_"+num2str(k)))
					hist="Hist_"+reverb+"_"+num2str(k)
					Wave Histo=$hist
					if(rightx(Histo)>min_duration)
						PSTH_list+=hist+";" // Put them on the list
						max_duration=max(max_duration,rightx($hist)) // Store the longest duration so far
						AppendToGraph /c=(r,g,b) $hist
					endif
				else
					break
				endif
			endfor
			print j
		endfor
		//print StringFromList(2,PSTH_list)
		Waves2Matrix(PSTH_list)
		//print PSTH_list
		Duplicate /o Matrix $(condition+"_Hist"); KillWaves /Z Matrix
		MatrixStats($(condition+"_Hist"))
		SetScale /I x,0,max_duration,$(condition+"_Hist_Mean")
		DoWindow /F PSTH_Avg
		AppendToGraph /c=(r,g,b) $(condition+"_Hist_Mean")
		ErrorBars $(condition+"_Hist_Mean"),Y wave=($(condition+"_Hist_SEM"),$(condition+"_Hist_SEM"))
	endfor
	Label bottom "Time Since Reverberation Onset"
	Label left "Firing Rate"
End

Function CumulHistOneBin(bin,conditions)
	Variable bin
	String conditions
	Variable i; String condition
	Display /K=1
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		Duplicate /o/R=[1,1][] $(condition+"_Hist") $(condition+"_"+num2str(bin))
		Wave BinWave=$(condition+"_"+num2str(bin))
		Redimension /n=(dimsize(BinWave,1)) BinWave
		DeleteNaNs(BinWave)
		Sort BinWave,BinWave
		SetScale /I x,0,1,BinWave
		Condition2Color(condition); NVar r,g,b
		AppendToGraph /c=(r,g,b) BinWave
	endfor 
End

// Returns a list of all the indices in Drug_Incubated that match condition
Function /S ListbyCondition(condition,clamp_type)
	String condition
	String clamp_type
	Wave /T Drug=root:Drug_Incubated
	Wave /T Clamp=root:Clamp
	Variable j
	String list=""
	for(j=0;j<numpnts(Drug);j+=1)
		if(StringMatch(Drug[j],condition) && StringMatch(Clamp[j],clamp_type))
			list+=num2str(j)+";"
		endif
	endfor
	return list
End

// Takes a list of reverb start and end times, e.g. "1,2;5,9" and gives a list of spike times for spikes that occurred in each of those times, e.g. "1,1.1,1.3,2;5,5.8,6.4,7,7.5,8.1,8.7,9"
Function /S Reverbs2SpikeTimes(sweep_num,reverbs[,relative])
	Variable sweep_num
	String reverbs
	Variable relative // If this is set to 1, Spike times will be relative to reverberation onset
	if(ParamIsDefault(relative))
		relative=0
	endif
	Wave locs=$("root:sweeps:locs_"+num2str(sweep_num))
	Wave vals=$("root:sweeps:vals_"+num2str(sweep_num))
	InterpFromPairs(vals,locs,"Sweep",kHz=10)
	Wave Sweep=Sweep
	Variable i,left,right
	String reverb,list,spike_times=""
	for(i=0;i<ItemsInList(reverbs);i+=1)
		reverb=StringFromList(i,reverbs)
		left=str2num(StringFromList(0,reverb,","))
		right=str2num(StringFromList(1,reverb,","))
		FindSpikeTimes(sweep,threshold=-20,refractory=0.01,left=left-0.010,right=right+0.010) // Find spike times that occur during that reverberation +/- 10 ms
		Wave SpikeTimes
		if(relative==1)
			SpikeTimes-=left
		endif
		list=NumWave2List(SpikeTimes) // A list of spike times for reverberation i in sweep sweep_num
		list=ReplaceString(";",list,",") // Replace semicolons with commas
		list=list[0,strlen(list)-2]; // Remove trailing comma
		spike_times+=list+";" // Add the list to spike_times.  Semicolons will separate reverberations.  
	endfor
	return spike_times
End

Function CompareConditions(conditions,parameters[,labels,mode])
	String conditions,parameters
	String labels // Axis labels (one for each parameter)
	Variable mode // Mode 0 is mean and sem for each file plotted in a cumulative histogram.  
				// Mode 1 is cumulative histograms for each file.
				// Mode 2 is a cumulative histogram for each condition  
	if(ParamIsDefault(mode))
		mode=0
	endif
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:Summaries
	Variable i,j,k,count,theMean
	String condition,parameter,file,druginc
	FileList(); SVar file_list; IncubateList(); SVar druginc_list
	for(i=0;i<ItemsInList(parameters);i+=1)
		parameter=StringFromList(i,parameters)
		Display /K=1 /N=$parameter
		for(j=0;j<ItemsInList(conditions);j+=1)
			condition=StringFromList(j,conditions)
			Make /o/n=0 $(condition+"_"+parameter+"_means")
			Make /o/n=0 $(condition+"_"+parameter+"_sems")
			Make /o/n=0 $(condition+"_"+parameter+"_Xs")
			Wave means=$(condition+"_"+parameter+"_means")
			Wave sems=$(condition+"_"+parameter+"_sems")
			Wave Xs=$(condition+"_"+parameter+"_Xs")
			count=0
			for(k=0;k<ItemsInList(file_list);k+=1)
				druginc=StringFromList(k,druginc_list)
				//print k
				if(!cmpstr(condition,druginc))
					file=StringFromList(k,file_list)
					//if(exists
					Wave /Z info=$("root:"+parameter+":"+parameter+"_"+file)
					if(waveexists(info) && numpnts(info)>0)
						WaveStats /Q info
						count+=1
						Redimension /n=(count) means,sems
						means[count-1]=V_avg
						sems[count-1]=V_sdev/sqrt(V_npnts)
						switch(mode)
							case 0:
								Redimension /n=(count) Xs
								break
							case 1:
								DeleteNaNs(info)
								//print numpnts(info)
								//WaveStats /Q info; print V_numNaNs
								Sort info,info
								Make /o/n=(numpnts(info)) $(parameter+"_"+file+"_Xs")=x/numpnts(info)
								Wave Xs=$(parameter+"_"+file+"_Xs")
								Condition2Color(condition); NVar r,g,b
								SetScale /I x,1/numpnts(Xs),1,info
								AppendToGraph /c=(r,g,b) info// vs Xs
								break
							case 2:
								if(count==1) // If this is the first time ISIs will be added
									Concatenate /o/NP {info}, $(condition+"_allISIs")
								else
									Concatenate /NP {info}, $(condition+"_allISIs")
								endif
						endswitch
					endif
				endif
			endfor
			WaveStats /Q means
			print condition+" : "+parameter+" : "+num2str(V_avg)+" +/- "+num2str(V_sdev/sqrt(V_npnts)) 
			Sort means,means,sems
			SetScale /I x,1/numpnts(means),1,means,sems
			switch(mode)
				case 0:
					Wave Xs=$(condition+"_"+parameter+"_Xs")
					Xs=x/numpnts(Xs)
					Condition2Color(condition); NVar r,g,b
					AppendToGraph /c=(r,g,b) means// vs Xs
					ErrorBars $NameOfWave(means),Y wave=($NameOfWave(sems),$NameOfWave(sems))
					break
				case 1:
					break
				case 2:
					Wave All_ISIs=$(condition+"_allISIs")
					DeleteNaNs(All_ISIs)
					Sort All_ISIs,All_ISIs
					Condition2Color(condition); NVar r,g,b
					SetScale /I x,1/numpnts(All_ISIs),1,All_ISIs
					AppendToGraph /c=(r,g,b) All_ISIs
					break
				default:
					Print "Not a valid mode : "+num2str(mode)
					break
			endswitch
		endfor
		SetAxis bottom 0,1
		Label bottom "Cumulative Probability"
		if(!ParamIsDefault(labels))
			Label left StringFromList(i,labels)
		endif
		ModifyGraph swapXY=1 
	endfor
	SetDataFolder curr_folder
End

// For each file (island), plots ISIs versus the time that they occur (second spike in the pair) relative to the first spike in the reverberation.  
// Plots Control as black and TTX as red.  
Function PlotISIvsISItime()
	String file_list=FileList()
	SVar druginc_list=root:druginc_list
	Variable i; String file,condition
	Display /K=1 /N=ISIvsISItime
	SetDataFolder root:ISIs
	for(i=0;i<ItemsInList(file_list);i+=1)
		file=StringFromList(i,file_list)
		condition=StringFromList(i,druginc_list)
		if(exists("ISIs_"+file))
			Sort $("ISIs_time_"+file),$("ISIs_time_"+file),$("ISIs_"+file) 
			// Sort so that both waves ascend with increasing time since the first spike in a reverberation
			Condition2Color(condition); NVar r,g,b
			AppendToGraph /c=(r,g,b) $("ISIs_"+file) vs $("ISIs_time_"+file)
		endif
	endfor
	SetDataFolder root:
End

Function PSTHs()
	String file_list=FileList()
	SVar druginc_list=root:druginc_list
	Variable i; String file,condition
	Display /K=1 /N=PSTH
	SetDataFolder root:SpikeTimes
	for(i=0;i<ItemsInList(file_list);i+=1)
		file=StringFromList(i,file_list)
		condition=StringFromList(i,druginc_list)
		if(exists("SpikeTimes_"+file))
			Wave SpikeTimes=$("SpikeTimes_"+file)
			DeleteNaNs($("SpikeTimes_"+file))
			//Sort SpikeTimes,SpikeTimes
			//SetScale /I x,0,1,SpikeTimes
			Make /o/n=200 $("SpikeTimes_Hist_"+file)=0
			Wave Hist=$("SpikeTimes_Hist_"+file)
			SetScale /P x,0,0.1,Hist
			Histogram /B=2 SpikeTimes,Hist
			Condition2Color(condition); NVar r,g,b
			AppendToGraph /c=(r,g,b) Hist
		endif
	endfor
	//ModifyGraph swapXY=1
	SetDataFolder root:
End

// List all traces with baseline (VC) > -150 pA or baseline (CC) > -45 mV
// This may list some reasonable sweeps that just happened to be reverberating when they started
Function ListBad()
	Variable i
	Wave /T File_Name=root:File_Name
	Wave Sweep=root:Sweep
	Wave /T Channel=root:Channel
	Wave /T Clamp=root:Clamp
	Variable VC_Cutoff=-150 // The most negative leak allowed in voltage clamp
	Variable CC_Cutoff=-45 // The most positive resting potential allowed in current clamp
	Display /K=1
	for(i=0;i<numpnts(File_Name);i+=1)
		Wave Vals=$("root:Sweeps:Vals_"+num2str(i))
		strswitch(Clamp[i])
			case "VC":
				if(Vals[0] < VC_Cutoff && Vals[numpnts(Vals)-1] < VC_Cutoff)
					print File_Name[i]+" "+Channel[i]+" "+num2str(Sweep[i])
					Reconstruct(num2str(i),graph=1)
				endif
				break
			case "CC":
				WaveStats /Q Vals
				if(V_min > CC_Cutoff)
					//print i
					//Reconstruct(num2str(i),existing_graph=1)
				endif
				break
			default:
				Print "Invalid Clamp"
				break
		endswitch
	endfor
End

// Summarizes the experiments from file list 'files'.  If 'files' is empty, it will use the current experiment.  
// If it is not, it will assume a database (within Igor) of data from many experiments is available to search
Function SweepSummaries(files[,mode])
	String files
	String mode
	if(ParamIsDefault(mode))
		mode="ColorMap"
	endif
	Variable database // 1 if the data is being loaded from the database, and 0 if it is being loaded from the file itself
	if(strlen(files)==0)
		if(!datafolderexists("root:cellR1")) // A simple indicator of whether or not this is an experimental file
			DoAlert 0,"The name of an experimental file must be provided if the current file is not an experiment file"
			return 0
		endif
		files=IgorInfo(1)
		NVar last_sweep=root:current_sweep_number
		database=0
	else
		database=1
	endif
	//Wave Sweep=root:Sweep
	Variable i,j,k,m,index,sweep_num,lower,upper,max_sweep,max_duration
	String file,chan,clamp,sweep,sweeps,island_sweeps,reconstruct_list,name
	String channels="R1;L2"; String clamps="VC;CC"
	SetDataFolder root:
	Make /o/n=0 NanWave=NaN
	Variable reconstruction_sampling_kHz=1
	for(i=0;i<ItemsInList(files);i+=1)
		file=StringFromList(i,files)
		DoWindow /K $("Summary_"+file)
		NewLayout /N=$("Summary_"+file)
		if(database)
			sweeps=Sweeps4File(file) // Gets all the absolute sweep numbers for that file
			island_sweeps=(IslandSweeps(sweeps)) // Gets the experiment sweep numbers for those sweeps
		else
			sweeps=ListExpand("1,"+num2str(last_sweep)) // 1 through last_sweep 
			island_sweeps=sweeps
		endif
		max_sweep=maxlist(island_sweeps) // Gets the maximum sweep number for that experiment.  
		for(j=0;j<ItemsInList(channels);j+=1)
			chan=StringFromList(j,channels)
			for(k=0;k<ItemsInList(clamps);k+=1)
				clamp=StringFromList(k,clamps)
				if(database)
					sweeps=Sweeps4File(file,chan=chan,clamp=clamp)
					island_sweeps=(IslandSweeps(sweeps))
				else
					sweeps=ClampSweeps(chan,clamp)
					island_sweeps=sweeps
				endif
				reconstruct_list=""
				for(m=0;m<=max_sweep;m+=1)
					index=WhichListItem(num2str(m),island_sweeps)
					if(index>=0) // m is in the list of sweeps
						sweep=StringFromList(index,sweeps)
						if(database)
							Reconstruct(sweep,graph=0,kHz=reconstruction_sampling_kHz)  // Reconstruct it
							reconstruct_list+="reconstruction_"+sweep+";" // Add it to the list
						else
							reconstruct_list+="root:cell"+chan+":sweep"+sweep+";"
						endif
					else
						reconstruct_list+="NaNWave;" // Add a blank wave to the list
					endif
				endfor
				if(ItemsInList(ListMatch(reconstruct_list,"NaNWave"))<ItemsInList(reconstruct_list))
					Waves2Matrix(reconstruct_list,down_sample=database ? 1 : 10)
				else // Every wave in the list is NaN Wave (no sweeps on this channel of this clamp type)
					Waves2Matrix(reconstruct_list)
				endif
				// Make a matrix from the list
				name="Summary_"+file+"_"+chan+"_"+clamp
				if(numpnts(Matrix)<5000000) // If the wave of all data for that clamp and channel is a reasonable size (less than 500 seconds)
					Duplicate /o Matrix $name Quantiles; KillWaves /Z Matrix // Rename the matrix to match the source data
					Redimension /n=(dimsize(Quantiles,0)*dimsize(Quantiles,1)) Quantiles // Make Quantiles a 1D wave
					Sort Quantiles,Quantiles // Sort to obtain actual quantiles
					DeleteNaNsAfterSort(Quantiles) // Gets rid of NaNs in the Quantiles wave
					SetScale /I x,0,1,Quantiles // Quantiles will go from 0 to 1
					strswitch(clamp)
						case "VC":
							lower=Quantiles(0.01); upper=Quantiles(0.99) // Scale to 5th and 95th percentile
							break
						case "CC":
							lower=Quantiles(0.01); upper=Quantiles(0.999)
							break
						default:
							break
					endswitch
				else // If it is too big, just make up reasonable quantiles for scaling
					strswitch(clamp)
						case "VC":
							lower=-500; upper=0 // Scale from -800 to 0 pA
							break
						case "CC":
							lower=-75; upper=0 // Scale from -75 to 0 mV
							break
						default:
							break
					endswitch
				endif
				SetScale /P x,0,0.001,$name // 1 kHz scaling (time points are still correct, but reconstructions will only have 1000 points per second)
				strswitch(mode)
					case "ColorMap":
						Display /K=1 /W=(0,0,300,10*dimsize($name,1)) /N=$name
						AppendImage $name
						ModifyImage '' ctab={lower,upper,Rainbow,0} 
						ModifyGraph fsize=8, btlen=2//, axisenab(bottom)={0,0.93}
						ColorScale/N=scale/A=MT/B=1/E=1/F=0/X=0/Y=0 fsize=8,vert=0,widthPct=50,heightPct=2,tickLen=2.00
						TextBox/N=clamp/A=MT/B=1/E=1/F=0/X=-25/Y=0 "\\Z12"+clamp
						TextBox/N=channel/A=MT/B=1/E=1/F=0/X=25/Y=0 "\\Z12"+chan
						break
					case "Waterfall":
						NewWaterfall /K=1 /N=$name $name
						SetAxis left,Quantiles(lower),Quantiles(upper)
						break
					default:
						Print "No such mode: "+mode
						break
				endswitch
				AppendLayoutObject /W=$("Summary_"+file) graph $(name+"0")
			endfor
		endfor
		DoWindow /F $name
		Execute("Tile")
	endfor
End

Function SaveSummaries([list])
	String list
	if(ParamIsDefault(list))
		list=FileList()
	endif
	Variable i; String file
	NewPath /O CDrive, "C:"
	for(i=0;i<ItemsInList(list);i+=1)
		file=StringFromList(i,list)
		SweepSummaries(file)
		DoWindow /F $("Summary_"+file)
		Sleep /S 5 // To give the computer a little bit of time to cool down in between files (5 seconds)
		SavePICT/O/P=CDrive/E=-6/B=288 as "Summary_"+file+".jpg"
		// Clean up
		DoWindow /K $("Summary_"+file)
		DoWindow /K $("Summary_"+file+"_R1_VC0")
		DoWindow /K $("Summary_"+file+"_R1_CC0")
		DoWindow /K $("Summary_"+file+"_L2_VC0")
		DoWindow /K $("Summary_"+file+"_L2_CC0")
		KillWaves NaNWave,Quantiles
		KillWaves2(match_str="Summary*")
		KillWaves2(match_str="reconstruction*")
	endfor
End

// Like SweepSummaries, but for one experiment when that experiment is open
Function ExperimentSummary()
	Variable i,j
	SVar channels=rootparameters:all_channels
	String channel,sweep_list,sweep_name; Variable sweep_num
	for(i=0;i<ItemsInList(channels);i+=1)
		channel=StringFromList(i,channels)
		SetDataFolder root:$("cell"+channel)
		sweep_list=WaveList("sweep*",";","")
		for(j=0;j<ItemsInList(sweep_list);j+=1)
			sweep_name=StringFromList(j,sweep_list)
			Duplicate /o $sweep_name test
			sweep_num=str2num(ReplaceString("sweep",sweep_name,""))
		endfor
	endfor
End

// Takes a list of sweeps from the Igor file (relative to the query) and returns the list of sweeps (relative to the Island) that they correspond to.  
Function /S IslandSweeps(sweeps)
	String sweeps
	Wave Sweep=root:Sweep
	String island_sweeps=""; Variable i,n
	for(i=0;i<ItemsInList(sweeps);i+=1)
		n=str2num(StringFromList(i,sweeps))
		island_sweeps+=num2str(Sweep[n])+";"
	endfor
	return island_sweeps
End

// Returns all the sweeps indices associated with file 'file' and optional channel 'chan'
Function /S Sweeps4File(file[,chan,clamp])
	String file
	String chan
	String clamp
	String sweeps=""
	if(ParamIsDefault(chan))
		chan="*"
	endif
	if(ParamIsDefault(clamp))
		clamp="*"
	endif
	Wave /T File_Name=root:File_Name
	Wave /T Channel=root:Channel
	Wave /T Clamps=root:Clamp
	//Wave Sweep=root:Sweep
	Variable i
	for(i=0;i<numpnts(File_Name);i+=1)
		if(StringMatch(File_Name[i],file) && StringMatch(Channel[i],chan) && StringMatch(Clamps[i],clamp))
			sweeps+=num2str(i)+";"
		endif
	endfor
	return sweeps
End

// Plots the number of spikes in a reverberation against the length of the reverberation.  
// Cutoffs are the ranges of each reverberation in which spikes are counted.  Each cutoff gets its own graph.  
Function NumSpikesvsReverbLength(conditions)
	String conditions
	String condition,reverb_list,reverb
	Wave /T Reverbs=root:Reverbs
	Variable h,i,j,k,cutoff,sweep,left,right,spikes,items=0
	Make /o Cutoffs={0.2,0.5,1,2,Inf}
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		Make /o/n=0 $("ReverbLengths_"+condition)
		Wave ReverbLengths=$("ReverbLengths_"+condition)
		for(h=0;h<numpnts(Cutoffs);h+=1)
			cutoff=Cutoffs[i]
			Make /o/n=0 $("SpikeNums_"+condition+"_"+num2str(cutoff*1000))
		endfor
		reverb_list=ListByCondition(condition,"CC") 
		// A list of all sweep numbers from that condition that are in Current Clamp
		for(j=0;j<ItemsInList(reverb_list);j+=1) // Scan through all the sweeps for that condition
			sweep=NumFromList(j,reverb_list)
			for(k=0;k<ItemsInList(Reverbs[sweep]);k+=1) // Scan through all the reverbs for that sweep
				reverb=StringFromList(k,Reverbs[sweep])
				items+=1
				Redimension /n=(items) ReverbLengths
				ReverbLengths[items-1]=PairDiff(reverb)
				Reconstruct(num2str(sweep),graph=0)
				Wave reconstruction=$("Reconstruction_"+num2str(sweep))
				reverb=ReplaceString(",",reverb,";")
				left=NumFromList(0,reverb)
				for(h=0;h<numpnts(Cutoffs);h+=1)
					cutoff=Cutoffs[h]
					Wave SpikeNums=$("SpikeNums_"+condition+"_"+num2str(cutoff*1000))
					Redimension /n=(items) SpikeNums
					right=min(NumFromList(1,reverb),left+cutoff)
					if(right-left>0)
						FindSpikeTimes(reconstruction,left=left,right=right)
						spikes=numpnts(SpikeTimes)
					else
						spikes=0
					endif
					SpikeNums[items-1]=spikes
				endfor
				KillWaves reconstruction
			endfor
			print j
		endfor
	endfor
	for(h=0;h<numpnts(Cutoffs);h+=1)
		cutoff=Cutoffs[h]
		Display /K=1 /N=$("ReverbLengthvsSpikeCount_"+num2str(1000*cutoff))
		for(i=0;i<ItemsInList(conditions);i+=1)
			condition=StringFromList(i,conditions)
			Wave ReverbLengths=$("ReverbLengths_"+condition)
			Wave SpikeNums=$("SpikeNums_"+condition+"_"+num2str(cutoff*1000))
			Condition2Color(condition); NVar r,g,b
			AppendToGraph /c=(r,g,b) SpikeNums vs ReverbLengths
			ModifyGraph mode=2,lsize=3
		endfor
	endfor
	KillWaves Cutoffs
End



// Used only for loading phenotypes into the connectivity table.  Generates the wave 'Phenos'.
Function PhenoLoad()
	// From connectivity table
	Wave /T File_Name,Channel
	Wave Number
	// From sweep record table
	Wave /T File_Name2,R1_Phenotype,L2_Phenotype
	Wave R1Num,L2Num
	
	Duplicate /T/o File_Name,Phenos
	Phenos=""
	Variable i,j,num
	String name,chan
	for(i=0;i<numpnts(Phenos);i+=1)
		name=File_Name[i]
		chan=Channel[i]
		num=Number[i]
		Wave ChanNum=$(chan+"Num")
		Wave /T Pheno=$(chan+"_Phenotype")
		for(j=0;j<numpnts(File_Name2);j+=1)
			if(StringMatch(File_Name2[j],name) && ChanNum[j]==num)
				Phenos[i]=Pheno[j]
				break
			endif
		endfor
	endfor
End

// Used for plotting connectivity histograms using the Connectivity table in the database
Function ConnectivityHist(drugs,pheno,autapse)
	String drugs,pheno
	Variable autapse // 0 is for no autapses, 1 is for only autapses, 2 is for both synapses and autapses
	Variable i,j,k,index
	String drug
	Wave /T File_Name,Channel,Drug_Incubated,Phenotype
	Wave DIV,Number,Autapse_Value,Partner_1,Synapse_1,Partner_2,Synapse_2,Partner_3,Synapse_3
	Display /K=1
	for(k=0;k<ItemsInList(drugs);k+=1)
		drug=StringFromList(k,drugs)
		String value_name=CleanupName(drug+"_"+pheno+"_"+num2str(autapse),1)
		String age_name=CleanupName(drug+"_"+pheno+"_"+num2str(autapse)+"_age",1)
		Make /o/n=0 $value_name; Wave Values=$value_name
		Make /o/n=0 $age_name; Wave Ages=$age_name
		for(i=0;i<numpnts(File_Name);i+=1)
			if(StringMatch(Drug_Incubated[i],drug) && StringMatch(Phenotype[i],pheno))
				if(autapse)
					InsertPoints 0,1,Values,Ages
					Ages[0]=DIV[i]==0 ? 11 : DIV[i]
					Values[0]=Autapse_Value[i]>0 ? Autapse_Value[i] : 0
					if(StringMatch(pheno,"*") && StringMatch(Phenotype[i],"GABA"))
						Values[0]=-abs(Values[0]) 
						// When you want to plot both phenotypes and you want to GABAergic synapses to be plotted with negative numbers
					endif
				endif
				if(autapse!=1)
					for(j=1;j<=3;j+=1)
						Wave Partner=$("Partner_"+num2str(j))
						Wave Synapse=$("Synapse_"+num2str(j))
						if(Partner[i]>0)
							InsertPoints 0,1,Values,Ages
							Ages[0]=DIV[i]==0 ? 11 : DIV[i]
							Values[0]=Synapse[i]>0 ? Synapse[i] : 0
							if(StringMatch(pheno,"*") && StringMatch(Phenotype[i],"GABA"))
								Values[0]=-abs(Values[0])
							endif
						endif
					endfor
				endif
			endif
		endfor
		//Make /o/n=0 $("Hist_"+drug+"_"+pheno+"_"+num2str(autapse))
		//Wave Hist=$("Hist_"+drug+"_"+pheno+"_"+num2str(autapse))
		//vals+=1
		//vals=log(vals)
		Sort Values,Values
		SetScale /I x,0,1,Values
		AppendToGraph Values //vs Ages
		//Histogram /B={0,0.02,160} vals,hist
		//Make /o LogTicks={0,1,2,3}
		//Make /o/T LogTickLabels={"0","10","100","1000"}
		//Display /K=1 hist
		//ModifyGraph userticks(bottom)={LogTicks,LogTickLabels}, mode=5
	endfor
	ModifyGraph swapXY=1//,log(bottom)=1
	Label left "Cumulative Fraction"
	Label bottom "Monosynaptic Strength (pA)"
	ColorCode2()
End

Function ReverbStats(Matrix)
	Wave Matrix
	Variable baselineX1=0,baselineX2=1,baseline
	Variable syncX1=1.035,syncX2=1.13,sync
	Variable asyncX1=1.13,asyncX2=1.19,async
	Variable amplX1=1.19,amplX2=10,ampl=0
	Variable duration,freq,interval
	Variable i,j,k
	Make /o/n=(dimsize(Matrix,1)) WBaseline=NaN,WSync=NaN,WAsync=NaN,WAmpl=NaN,WDuration=NaN,WFreq=NaN
	for(i=0;i<dimsize(Matrix,1);i+=1)
		if((i>27 && i<65) || (i>70 && i<105) || (i>110 && i<148))
		Duplicate /O/R=()(i,i) Matrix Column
		WaveStats /Q/R=(baselineX1,baselineX2) Column
		baseline=V_avg
		WaveStats /Q/R=(syncX1,syncX2) Column
		sync=V_min
		WaveStats /Q/R=(asyncX1,asyncX2) Column
		async=V_avg
		FindLevels /Q Column,baseline-200; Wave W_FindLevels
		duration=W_FindLevels[numpnts(W_FindLevels)-1]-baselineX2
		FindReverbPeaks(Column,400000); Wave ReverbPeaks
		//ampl=baseline
		k=0;ampl=0
		for(j=1;j<numpnts(ReverbPeaks);j+=1)
			WaveStats /Q/R=(ReverbPeaks[j]-0.05,ReverbPeaks[j]+0.05) Column
			if(!IsNan(V_min))
				k+=1
				ampl+=V_min
				//print ampl
			endif
		endfor
		ampl=duration>0.5 ? ampl/k : NaN
		Differentiate /METH=2 ReverbPeaks /D=IPI; DeletePoints 0,1,IPI // Get inter-peak-intervals
		freq=duration>0.5 ? 1/Median1(IPI,-Inf,Inf) : NaN
		//print i,freq
		WBaseline[i]=baseline
		WSync[i]=baseline-sync
		WAsync[i]=baseline-async
		WAmpl[i]=baseline-ampl
		WDuration[i]=duration
		WFreq[i]=freq
		endif
	endfor
	Display /K=1 WBaseline,WSync,WAsync,WAmpl,WDuration,WFreq
	ModifyGraph log(left)=1
	ModifyGraph rgb(WBaseline)=(0,0,0),rgb(WAsync)=(0,12800,52224);DelayUpdate
	ModifyGraph rgb(WAmpl)=(0,52224,0),rgb(WDuration)=(52224,52224,0);DelayUpdate
	ModifyGraph rgb(WFreq)=(26112,0,10240),mode=2,lsize=2
End

Function FIRheobase()
	String conditions="TTX;CTL;"
	Variable i,j; String cell_list=""
	SetDataFolder root:
	Wave /T FileName,Drug_Incubated,Channel
	Wave Sweep,Current_Injected,SpikesW,Duration,Comments,Baseline
	Duplicate /o Current_Injected AdjustedCurrent
	// Normalize all currents to -65 mV starting point, assuming input resistance of 0.8 GOhms.  
	AdjustedCurrent=(Baseline+65)/0.8+Current_Injected
	for(i=0;i<ItemsInList(conditions);i+=1)
		Make /n=0/o $StringFromList(i,Conditions)
	endfor
	NewDataFolder /O root:Cells
	KillWaves2(folder_list="root:Cells")
	for(i=0;i<numpnts(Sweep);i+=1)
		Wave ChanNum=$(Channel[i]+"__")
		if(Baseline[i]>-75 && Baseline[i]<-55)
			String cell_id=Drug_Incubated[i]+"_"+FileName[i]+"_"+Channel[i]+"_"+num2str(ChanNum[i])
			if(!waveexists(root:Cells:$cell_id))
				Make /o/n=(0,2) root:Cells:$cell_id
			endif
			Wave Cell=root:Cells:$cell_id
			InsertPoints /M=0 0,1,Cell
			Cell[0][0]=AdjustedCurrent[i]
			Cell[0][1]=SpikesW[i]
		endif
	endfor
	SetDataFolder root:Cells
	String cells=WaveList("*",";","")
	Variable rheobase
	String cell_name,condition
	for(i=0;i<ItemsInList(cells);i+=1)
		cell_name=StringFromList(i,cells)
		Wave Cell=$cell_name
		Duplicate /O/R=[][0,0] Cell CurrentSizes; Redimension /n=(dimsize(Cell,0)) CurrentSizes
		Duplicate /O/R=[][1,1] Cell SpikeCounts; Redimension /n=(dimsize(Cell,0)) SpikeCounts
		Sort CurrentSizes,SpikeCounts
		//print CurrentSizes,SpikeCounts
		FindLevel /Q SpikeCounts,0.5
		//print num2str(SpikeCounts)+"_"+num2str(V_flag)
		if(!V_flag)
			//print cell_name
			rheobase=CurrentSizes[V_LevelX]
			condition=StringFromList(0,cell_name,"_")
			Wave ConditionWave=root:$condition
			InsertPoints 0,1,ConditionWave
			ConditionWave[0]=rheobase
			if(rheobase>500)
				print cell_name
			endif
		endif
		KillWaves CurrentSizes,SpikeCounts
	endfor
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition=StringFromList(i,conditions)
		print condition
		WaveStat(theWave=root:$condition)
	endfor
	SetDataFolder root:
End

// Make a dose response curve for some reverberation measurement vs the dose of some drug
Function DoseResponse(drug,parameter,channel[,first,last])
	String drug,parameter,channel
	Variable first,last
	NewDataFolder /O/S root:reanalysis:dose_response
	NewDataFolder /O/S :$parameter
	first=ParamIsDefault(first) ? 1 : first
	NVar final_sweep=root:current_sweep_number
	last=ParamIsDefault(last) ? final_sweep : last
	Wave /T DrugHistory=root:drugs:history
	Make /o/n=(final_sweep+1) Dose
	Dose=str2num(StringByKey(drug,DrugHistory[x],","))
	Dose=IsNaN(Dose) ? 0 : Dose
	Duplicate /o Dose $parameter; Wave Param=$parameter; Param=NaN
	Variable i,j,baseline,threshold=100,interval=1,start,finish
	String reverbs,first_reverb
	for(i=first;i<=last;i+=1)
		Wave /Z Sweep=$("root:cell"+channel+":sweep"+num2str(i))
		if(waveexists(Sweep))
			baseline=mean(Sweep,0,0.03)
			WaveStats /Q/R=(3.005,) Sweep
			threshold=(baseline-V_min)/2
			reverbs=FindReverbs(Sweep,threshold,interval,baseline,left=3.005)
			print reverbs
			first_reverb=StringFromList(0,reverbs)
			strswitch(parameter)
				case "Duration":
					Param[i]=PairDiff(first_reverb)
					break
				case "Charge":
					start=str2num(StringFromList(0,first_reverb,","))
					finish=str2num(StringFromList(1,first_reverb,","))
					WaveStats /Q/R=(start,finish) Sweep
					Param[i]=(baseline-V_avg)*(finish-start)
					break
				case "First PSC Group Peak":
					WaveStats /Q/R=(3.005,3.1) Sweep
					Param[i]=(baseline-V_min)
					break
				case "First PSC Peak":
					WaveStats /Q/R=(3.005,3.012) Sweep
					Param[i]=(baseline-V_min)
					break
			endswitch
		endif
	endfor
	Make /O/n=0 DoseMean,ParamMean; 
	Variable dose_num,found,count
	for(i=first;i<=last;i+=1)
		dose_num=Dose[i]
		found=WaveSearch(DoseMean,dose_num)
		if(found<0)
			InsertPoints 0,1,DoseMean,ParamMean
			DoseMean[0]=dose_num
		endif
	endfor
	for(i=0;i<numpnts(DoseMean);i+=1)
		count=0
		for(j=first;j<=last;j+=1)
			if(Dose[j]==DoseMean[i])
				count+=1
				ParamMean[i]+=Param[j]
			endif
		endfor
		ParamMean[i]/=count
	endfor
	Display /K=1 
	AppendToGraph /c=(0,0,0) Param vs Dose
	AppendToGraph /c=(65535,0,0) ParamMean vs DoseMean
	BigDots(size=4)
	Label bottom drug+" concentration (nM)"
	Label left parameter
	SetDataFolder root:
End

// ------------------ Mostly obsolete, the following functions were used at one time evaluate reverberations manually on a sweep by sweep basis. -----------------------

// Finds the location of all level crossings of Cursor A, and returns the (relative) time of the last crossing that has no crossings
// within 500 ms after it.  Cursor B will denote the end of the activity (decayed back to baseline).  
Function ReverbLength(start_time)
	Variable start_time // The start time of the reverberation start (e.g. 1s)
	SetDataFolder root:reanalysis:SweepSummaries
	//stim_time+=0.005 // Add 5 ms for the synaptic delay and to avoid the stimulus artifact
	//Variable meanPSC=MeanBetweenCursors()
	//print meanPSC
	Wave CursorWave=CsrWaveRef(A)
	Duplicate /o CursorWave toSearch
	//Differentiate toSearch /D=d_toSearch
	Variable target_level=vcsr(A)
	NVar VC=VC
	if(VC==0)
		toSearch*=-1
		target_level*=-1
	endif
	FindLevels /Q /R=(start_time,rightx(toSearch)) toSearch,target_level
	Wave levels=W_FindLevels
	Variable i,current,previous
	current=levels[0]
	//print levels
	for(i=1;i<numpnts(levels);i+=1)
		previous=current
		current=levels[i]
		if(current-previous > 0.45)
			WaveStats /Q/R=(previous,current) toSearch
			if(V_avg>target_level)
				current=previous
				break
			endif
		endif
	endfor
	
	// Add a big dot showing where the reverberation ended
	Duplicate /o toSearch ReverbLoc
	ReverbLoc=NaN
	ReverbLoc[x2pnt(ReverbLoc,current)]=CursorWave(current)
	CleanAppend("ReverbLoc")
	ModifyGraph mode(ReverbLoc)=2,lsize(ReverbLoc)=5,rgb(ReverbLoc)=(0,0,0)
	KillWaves toSearch
	// Return the duration of the reverberation
	return current-start_time
End

// Gives you the mean current durring the reverberation.  
Function MeanPSC(stim_time,end_string)
	Variable stim_time
	String end_string
	SetDataFolder root:reanalysis
	strswitch(end_string)
		case "psc":
			Variable reverb_length=ReverbLength(stim_time)
			WaveStats /Q /R=(stim_time,stim_time+reverb_length) CsrWaveRef(A)
			break
		case "B":
			WaveStats /Q /R=(stim_time,xcsr(B)) CsrWaveRef(A)
			break
		default:
			Print "Not a known end string"
			break
	endswitch
	return V_avg
End

// This will give you the Gini coefficient for the reverberation determined by 'stim_time' and ReverbLength()
// end_string="psc" gives you the Gini for the reverberation not including the winding down at the end.  
// end_string="B" includes the winding down, where the end of the winding down is marked by Cursor B.  
Function GiniPSC(stim_time,end_string)
	Variable stim_time
	String end_string
	SetDataFolder root:reanalysis
	strswitch(end_string)
		case "psc":
			Variable reverb_length=ReverbLength(stim_time)
			return Gini(integrated_PSC,stim_time,stim_time+reverb_length)
			break
		case "B":
			return Gini(integrated_PSC,stim_time,xcsr(B))
			break
		default:
			Print "Not a known end string"
			break
	endswitch
End

// Computes the Gini coefficient of wave 'values' from 'first' to 'last'
// Not a true Gini coefficient, but more a measure of inequality and balance in the signal.  
// A signal large at the beginning will have a value closer to 1, large at the end will give -1, and more balanced will give a value near 0.  
Function Gini(values,first,last)
	Wave values
	Variable first,last
	Integrate values /D=integrated_values
	Variable area_under_curve=area(integrated_values,first,last)
	Variable area_under_lorentz=(last-first)*(integrated_values(last)+integrated_values(first))/2
	Variable area_between_curve_and_lorentz=area_under_curve-area_under_lorentz
	KillWaves integrated_values
	return area_between_curve_and_lorentz/area_under_lorentz
End

// Calculates the frequency (FFT-wise) of a reverberation
Function ReverbFreq(cutoff,width,left,right)
	Variable cutoff,width
	Variable left//=xcsr(A)
	Variable right//=xcsr(B)
	Wave toUse=CsrWaveRef(A)
	String filtered=HighPassFilter(toUse,cutoff,width)
	Duplicate /o /R=(left,right) $filtered correlated,correlated2 // Take the region between the cursors
	Correlate correlated2 correlated // Perform autocorrelation
	Variable range=(right-left)/2
	Duplicate /o/R=(left-range,left+range) correlated correlated_range
	MakeEven(correlated_range) // To make the number of rows in the autocorrelation even
	//FFT /MAG /PAD={NextPowerOf2(numpnts(correlated_range))} /DEST=correlated_fftd correlated_range // Take the FFT (faster but less accurate)
	FFT /MAG /DEST=correlated_fftd correlated_range // Take the FFT
	correlated_fftd*=x // Normalize by the frequency to account for natural 1/f nature of the spectrogram
	//Smooth 25,correlated_fftd
	WaveStats /Q correlated_fftd
	//Display correlated_fftd; ModifyGraph log(bottom)=1
	KillWaves correlated_fftd,correlated,correlated2,correlated_range//,$filtered
	return V_maxloc
End

// Appends values obtained in the manual Reverberation Analysis Panel to a wave of such values for all sweeps
Function AppendReverbValuesToWaves(channel,sweep)
	String channel
	Variable sweep
	NewDataFolder /O/S root:reanalysis:SweepSummaries
	Variable i
	
	// Set values of variables and strings that weren't already set in the panel
	Variable /G sweep_num=sweep
	Wave SweepParams=$("root:sweep_parameters_"+channel)	
	ControlInfo clamp
	String first=StringFromList(0,S_Value," ")
	String second=StringFromList(1,S_Value," ")
	String /G clamp=first[0]+second[0]//Num2Clamp(SweepParams[sweep][5])
	String channels="R1;L2;B3"; String chan
	for(i=0;i<ItemsInList(channels);i+=1)
		chan=StringFromList(i,channels)
		String /G $("stim_"+chan)=""
		if(exists("root:sweep_parameters_"+chan))
			Wave SweepParams=$("root:sweep_parameters_"+chan)	
			SVar Params=$("stim_"+chan)
			Params=num2str(SweepParams[sweep][4])+";"+num2str(SweepParams[sweep][2])+";"+num2str(SweepParams[sweep][3])
		endif
	endfor
	Wave sweep_t=root:sweep_t
	Variable /g last=60*(sweep_t[sweep-1]-sweep_t[sweep-2])
	Variable /g sweep_dur=rightx(CsrWaveRef(A))-leftx(CsrWaveRef(A))
	ControlInfo /W=ReverbPanel cutoff
	Variable /g cutoff=V_value
	
	// A list of all the waves that will be put into the table
	String wave_list="Sweep_Nums,0;Clamps,1;Stim_R1s,1;Stim_L2s,1;Stim_B3s,1;Drugs,1;Drug_Concs,0;Lasts,0;Sweep_Durs,0;Stim_Starts,0;"
	wave_list+="Rev_Starts,0;Rev_Durations,0;Cutoffs,0;Baselines,0;Charges,0;Variances,0;Counts,0;Freqs,0;Giniss,1;Peak_Locss,1;Peak_Valss,1;"
	wave_list+="Trough_Locss,1;Trough_Valss,1"
	String wave_name
	Variable is_text
	
	// Initialize the waves if they need it and redimension them to accomodate the new data
	if(!DataFolderExists("root:reanalysis:SweepSummaries:"+channel))
		NewDataFolder /O/S $("root:reanalysis:SweepSummaries:"+channel)
		for(i=0;i<ItemsInList(wave_list);i+=1)
			wave_name=StringFromList(0,StringFromList(i,wave_list),",") 
			is_text=str2num(StringFromList(1,StringFromList(i,wave_list),","))
			if(is_text)
				Make /O/T/N=1 $wave_name=""
			else
				Make /O/N=1 $wave_name=NaN
			endif
		endfor
	endif
	
	// Set all the wave values at index=sweep from the values of variables and strings
	SetDataFolder $("root:reanalysis:SweepSummaries:"+channel)
	Variable num_rows=numpnts(Sweep_Nums)
	for(i=0;i<ItemsInList(wave_list);i+=1)
		wave_name=StringFromList(0,StringFromList(i,wave_list),",") 
		is_text=str2num(StringFromList(1,StringFromList(i,wave_list),","))
		Redimension /N=(max(num_rows,sweep+1)) $wave_name
		if(is_text)
			Wave /T textWave=$wave_name
			SVar text=$("root:reanalysis:SweepSummaries:"+wave_name[0,strlen(wave_name)-2])
			textWave[sweep]=text
		else
			Wave numWave=$wave_name
			NVar num=$("root:reanalysis:SweepSummaries:"+wave_name[0,strlen(wave_name)-2])
			numWave[sweep]=num
		endif
	endfor
	RemoveFromGraph /Z /W=WholeTraces reverbloc,peakwave,troughwave
	KillWaves2(folder_list="root:reanalysis:sweepsummaries")
	// Show the table (or bring it to the front)
	EditFolder(GetDataFolder(1),sorter=ListSubSet(wave_list,0))
End

// A panel for manual analysis of a reverberations in a single sweep
Function ReverbAnalysisPanel() : ButtonControl
	string ctrlname
	NVar stop_code=root:stop_code
	//PauseUpdate; Silent 1		// building window...
	if(cmpstr(WinList("ReverbPanel",";",""),"")) // If a window called "ReverbPanel" exists
		DoWindow/f ReverbPanel // Bring it to the front
	else
		NewPanel /K=1 /N=ReverbPanel /W=(400,100,705,500) as "Reverberation Analysis Panel" // Make a panel
		String curr_folder=GetDataFolder(1)
		NewDataFolder /O/S root:reanalysis:SweepSummaries
		String /G drug,ginis,peak_locs,peak_vals
		Variable /G drug_conc,stim_start,rev_start,rev_duration,cutoff,baseline,charge,variance,peak,count,freq,crop,VC=1
		Button Reset,pos={1,1},size={75,20},title="\\Z10Reset",proc=ReverbAnalysisPanelBTProc
		Button Crop,pos={100,1},size={75,20},title="\\Z10Crop",proc=ReverbAnalysisPanelBTProc
		SetVariable crop_val,pos={200,1},size={75,20},title=" ",value=crop
		SetVariable drug_val,pos={1,30},size={75,20},title="Drug",value=drug
		SetVariable drug_conc_val,pos={100,30},size={75,20},title="Conc.",value=drug_conc
		SetVariable stim_start_val,pos={200,30},size={100,20},title="Stim Start",value=stim_start,proc=ReverbAnalysisPanelSVProc
		Button rev_start_do,pos={1,60},size={75,20},title="\\Z10Rev. Start",proc=ReverbAnalysisPanelBTProc
		SetVariable rev_start_val,pos={100,60},size={75,20},value=rev_start,title=" "//,proc=ReverbAnalysisPanelSVProc
		PopupMenu clamp,mode=1,value="Voltage Clamp;Current Clamp",proc=ReverbAnalysisPanelPMProc
		Button rev_duration_do,pos={1,90},size={75,20},title="\\Z10Rev. Duration",proc=ReverbAnalysisPanelBTProc
		SetVariable rev_duration_val,pos={100,90},size={75,20},value=rev_duration,proc=ReverbAnalysisPanelSVProc,title=" "
		Checkbox cutoff,pos={190,90},value=0,title="Cutoff"
		Button manual_rev_duration_do,pos={250,90},size={50,20},title="Manual",proc=ReverbAnalysisPanelBTProc
		Button baseline_do,pos={1,120},size={75,20},title="\\Z10Baseline",proc=ReverbAnalysisPanelBTProc
		SetVariable baseline_val,pos={100,120},size={75,20},value=baseline,title=" "
		Button Fill,pos={200,120},size={75,20},title="Fill",proc=ReverbAnalysisPanelBTProc
		//Button FillB,pos={200,150},size={75,20},title="Fill B",proc=ReverbAnalysisPanelBTProc
		Button charge_do,pos={1,150},size={75,20},title="\\Z10Charge",proc=ReverbAnalysisPanelBTProc
		SetVariable charge_val,pos={100,150},size={75,20},value=charge,title=" "
		Button variance_do,pos={1,180},size={75,20},title="\\Z10Variance",proc=ReverbAnalysisPanelBTProc
		SetVariable variance_val,pos={100,180},size={75,20},value=variance,title=" "
		//Button peak_do,pos={1,210},size={75,20},title="\\Z10Peak",proc=ReverbAnalysisPanelBTProc
		//SetVariable peak_val,pos={100,210},size={75,20},value=peak,title=" "
		Button count_do,pos={1,210},size={75,20},title="\\Z10Count Events",proc=ReverbAnalysisPanelBTProc
		SetVariable count_val,pos={100,210},size={75,20},value=count,title=" "
		Button gini_do,pos={1,240},size={75,20},title="\\Z10Gini",proc=ReverbAnalysisPanelBTProc
		SetVariable gini_val,pos={100,240},size={100,20},value=ginis,title=" "
		Button freq_do,pos={1,270},size={75,20},title="\\Z10Frequency",proc=ReverbAnalysisPanelBTProc
		SetVariable freq_val,pos={100,270},size={75,20},value=freq,title=" "
		Button Enter,pos={1,300},size={75,20},title="\\Z10Enter Record",proc=ReverbAnalysisPanelBTProc
		Button Delete,pos={200,300},size={75,20},title="\\Z10Delete Record",proc=ReverbAnalysisPanelBTProc
		Checkbox R1, pos={1,350},size={75,20},title="R1",proc=ReverbAnalysisPanelCBProc,value=1
		Checkbox L2, pos={100,350},size={75,20},title="L2",proc=ReverbAnalysisPanelCBProc,value=1
		Checkbox B3, pos={200,350},size={75,20},title="B3",proc=ReverbAnalysisPanelCBProc,value=1
		SetDataFolder curr_folder
	endif
End

// Commands executed from the Reverberation Panel Checkboxes
Function ReverbAnalysisPanelCBProc(ctrlName,var)
	String ctrlName
	Variable var
	Variable i
	//String all_channels="R1;L2;B3"
	String channel
	SVar active_channels=root:parameters:active_channels
	active_channels=""
	for(i=0;i<ItemsInList(all_channels);i+=1)
		channel=StringFromList(i,all_channels)
		ControlInfo $channel
		if(V_Value==1)
			active_channels+=channel+";"
		endif
	endfor
End

// Commands executed from the Reverberation Panel PopUp Menus
Function ReverbAnalysisPanelPMProc(ctrlName,var,str)
	String ctrlName
	Variable var
	String str
	strswitch(ctrlName)
		case "Clamp":
			NVar VC=root:reanalysis:SweepSummaries:VC; VC=2-var
			break
		default:
			break
	endswitch
End

// Commands executed from the Reverberation Panel SetVariables
Function ReverbAnalysisPanelSVProc(ctrlName,var,str1,str2)
	String ctrlName
	Variable var
	String str1,str2
	ReverbAnalysisPanelBTProc(ctrlName)
End

// Commands executed from the Reverberation Panel Buttons
Function ReverbAnalysisPanelBTProc(ctrlName)
	String ctrlName
	//ctrlName=StringFromList(0,ctrlName,"_")
	SetDataFolder root:reanalysis:SweepSummaries
	NVar stim_start=stim_start; NVar rev_duration=rev_duration; NVar baseline=baseline; NVar rev_start=rev_start
	NVar charge=charge;  NVar variance=variance; NVar peak=peak; NVar count=count; NVar freq=freq; NVar crop_val=crop
	SVar ginis=ginis; SVar peak_locs=peak_locs; SVar peak_vals=peak_vals
	String channel=StringFromList(0,CsrWave(A),"_")
	NVar sweep=root:parameters:active_trace
	Wave theWave=CsrWaveRef(A)
	Variable delay=0.005 // Synaptic delay so stimulus artifact is not counted and statistics begin with the first synaptic current
	strswitch(ctrlName)
		case "Reset":
			SetVars2Nan("rev_duration;baseline;rev_start;charge;variance;peak;count;freq")
			SetStrings2Empty("ginis;peak_locs;peak_vals")
			break
		case "Crop":
			Crop(crop_val)
			break
		case "stim_start_val":
			rev_start=stim_start+delay
			break
		case "Rev_Start_do":
			rev_start=xcsr(A)
			break
		case "rev_duration_do": 
			rev_duration=ReverbLength(rev_start)
			break
		case "manual_rev_duration_do":
			rev_duration=xcsr(B)-xcsr(A)
			break
		case "baseline_do":
			baseline=mean(theWave,stim_start-0.055,stim_start-0.005)
			break
		case "Fill":
			ReverbAnalysisPanelBTProc("baseline_do")
			ReverbAnalysisPanelBTProc("variance_do")
			ReverbAnalysisPanelBTProc("count_do")
			ReverbAnalysisPanelBTProc("charge_do")
			ReverbAnalysisPanelBTProc("gini_do")
			ReverbAnalysisPanelBTProc("freq_do")
			break
		case "charge_do":
			NVar charge=charge
			Variable mean_current=(mean(theWave,rev_start,xcsr(B)) // Mean current between the start of the stimulus and Cursor B
			mean_current=mean_current-baseline // Normalized to the baseline current
			charge=-mean_current*(xcsr(B)-(rev_start)) // Multiplied by the length of the region to give total charge (sign flipped to become positive)
			break
		case "variance_do":
			WaveStats /Q /R=(rev_start,rev_start+rev_duration) theWave
			variance=V_sdev^2
			break
		case "peak_do":
			WaveStats /Q /R=(xcsr(A),xcsr(B)) theWave
			peak=max(baseline-V_min,V_max-baseline) // The first would be for voltage clamp, the second for current clamp.  The maximum will arbitrate the issue.  
			break
		case "count_do":
			PeakFinder(rev_start,rev_start+rev_duration,100)
			CleanAppend("PeakWave")
			CleanAppend("TroughWave"); ModifyGraph rgb(TroughWave)=(65535,65535,0)
			//peak=-MinList(peak_vals)
			count=ItemsInList(peak_vals)
			break
		case "gini_do":
			Variable /G gini_b=Gini(theWave,rev_start,xcsr(B))
			Variable /G gini_psc=Gini(theWave,rev_start,rev_start+rev_duration)
			ginis=num2str(gini_psc)+";"+num2str(gini_b)
			break
		case "freq_do":
			freq=ReverbFreq(2,1,xcsr(A),rev_start+rev_duration)
			break
		case "enter":
			AppendReverbValuesToWaves(channel,sweep)
			break
		case "delete":
			String curr_folder=GetDataFolder(1)
			SetDataFolder $("root:reanalysis:SweepSummaries:"+channel)
			SetWaves2Nan(sweep,WaveList("*",";",""))
			SetDataFolder curr_folder
			break
		default:
			break
	endswitch
End