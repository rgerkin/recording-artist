// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/More%20Analysis.ipf $
// $Author: rick $
// $Rev: 626 $
// $Date: 2013-02-07 09:36:23 -0700 (Thu, 07 Feb 2013) $

#pragma rtGlobals=1		// Use modern global access method.

strconstant allChannels="R1;L2;B3"

// Put the channel into two wave, where each row is a sweep, and each is entry is a string of locs (first wave) and vals (second wave)
Function /S Reductions2Access([file_name_str,sweep_offset])
	String file_name_str // Name of the experiment file being used.  
	Variable sweep_offset // The first sweep should be labeled as sweep 1+sweep_offset, in case there were other files with data
						// from the same island.  
	if(ParamIsDefault(file_name_str))
		file_name_str=IgorInfo(1)
	endif
	Variable i,j,sweep_num
	//SVar channels=root:parameters:active_channels
	String channel_list=allChannels //"R1;L2" // For the time being, make it easy by considering only R1 and L2
	if(ParamIsDefault(sweep_offset))
		sweep_offset=0 
		Prompt sweep_offset,"Sweep Offset (default=0)"
		DoPrompt "Please enter the sweep offset (default=0)", sweep_offset
	endif
	String channel_str
	NVar final_sweep=root:current_sweep_number
	SVar compression_method_str=root:reanalysis:SweepReductions:compress_method
	//String compression_method_str="DWT"
	
	//The first window(s)	
	String used_channels=""
	for(i=0;i<ItemsInList(channel_list);i+=1)
		channel_str=StringFromList(i,channel_list)
		if(SweepsOnChannel(channel_str))
			NewDataFolder /O/S $("root:reanalysis:SweepReductions:"+channel_str)
			used_channels+=channel_str+";"
		else
			continue
		endif
		Make /o/n=1 Baseline,Sweep,Use=NaN,Flag=NaN
		Make /o/T /n=1 Experimenter,File_Name,File_Sweep,Channel,Locs,Vals,Compression_Method,Clamp,Average,Scale,Points,Comments=""
		Wave SweepParams=$("root:sweep_parameters_"+channel_str)
		Wave /Z OldAverages=$("root:reanalysis:SweepReductions:SweepAverages"+channel_str)
		Wave /Z OldScales=$("root:reanalysis:SweepReductions:SweepScales"+channel_str)
		Wave /Z OldPoints=$("root:reanalysis:SweepReductions:SweepPoints"+channel_str)
		j=1
		for(sweep_num=1;sweep_num<=final_sweep;sweep_num+=1)
			if(exists("locs_"+num2str(sweep_num)) && exists("root:cell"+channel_str+":sweep"+num2str(sweep_num)))
				//j=numpnts(sweep_nums)
				Redimension /n=(j) Experimenter,File_Name,Sweep,File_Sweep,Channel,Locs,Vals,Compression_Method,Clamp,Baseline,Average,Scale,Points
				Experimenter[j-1]="RCG"
				File_Name[j-1]=file_name_str
				Sweep[j-1]=sweep_num+sweep_offset
				File_Sweep[j-1]=file_name_str[strlen(file_name_str)-1]+num2str(sweep_num)
				//print file_name_str[strlen(file_name_str)-1]+num2str(sweep_num)
				Channel[j-1]=channel_str
				Locs[j-1]=NumWave2String($("locs_"+num2str(sweep_num)))
				Vals[j-1]=NumWave2String($("vals_"+num2str(sweep_num)))
				Compression_Method=compression_method_str
				Clamp[j-1]=Num2Clamp(SweepParams[sweep_num][5])
				Wave sweepWave=$("root:cell"+channel_str+":sweep"+num2str(sweep_num))
				Baseline[j-1]=mean(sweepWave,0,min(0.25,SweepParams[sweep_num][4]/1000 - 0.01))
				if(waveexists(OldAverages)) // Should only exists for channels that have sweeps.  
					Average[j-1]=num2str(OldAverages[sweep_num-1])
					Scale[j-1]=num2str(OldScales[sweep_num-1])
					Points[j-1]=num2str(OldPoints[sweep_num-1])
				endif
				// End period for baseline is the minimum of 250 ms and the time of the first pulse - 10 ms
				j+=1
			endif
		endfor
		Baseline=(Baseline<=-10000) ? -9999 : Baseline // Do not allow to be less than or equal to -10000.  
		TestReductionLengths()
		Wave /Z OldAverages=$("root:reanalysis:SweepReductions:SweepAverages"+channel_str)
		Wave /Z OldScales=$("root:reanalysis:SweepReductions:SweepScales"+channel_str)
		Wave /Z OldPoints=$("root:reanalysis:SweepReductions:SweepPoints"+channel_str)
		if(waveexists(OldAverages)) // Should only exists for channels that have sweeps.  
			Edit /K=1 /N=$(channel+"_Sweeps_Locs_Vals")
			AppendToTable Experimenter,File_Name,Sweep,File_Sweep,Channel,Locs,Vals,Compression_Method,Average,Scale,Points,Clamp,Baseline
			ModifyTable size=8
		endif
	endfor

	// The last window
	SetDataFolder root:reanalysis:SweepReductions
	Make /o/n=1 Sweep,Last,Sweep_Dur,Use=NaN
	for(i=0;i<ItemsInList(channel_list);i+=1)
		channel_str=StringFromList(i,channel_list)
		Make /o/n=1 $(channel_str+"_Start"),$(channel_str+"_Pulses"),$(channel_str+"_Interval"),$(channel_str+"_Ampl"),$(channel_str+"_Width")
	endfor
	Make /o/T /n=1 Experimenter,File_Name,File_Sweep,Drug,Conc,Comments=""
	i=1
	Wave sweep_t=root:sweep_t
	String R1="root:cellR1:sweep"; String L2="root:cellL2:sweep"; String B3="root:cellB3:sweep"
	NVar kHz=root:parameters:kHz
	DrugInfo2DrugWaves(); 
	Wave /T DrugHistory=root:drugs:history; String drug_list,conc_num,conc_units
	for(i=1;i<=final_sweep;i+=1)
		Redimension /n=(i) Experimenter,File_Name,Sweep,File_Sweep,Drug,Conc,Last,Sweep_Dur
		Experimenter[i-1]="RCG"
		File_Name[j-1]=file_name_str
		Sweep[i-1]=i+sweep_offset
		File_Sweep[i-1]=file_name_str[strlen(file_name_str)-1]+num2str(i)
		if(strlen(DrugHistory[i])>0)
			drug_list=NthEntries2List(DrugHistory[i],0)
			conc_num=NthEntries2List(DrugHistory[i],1)
		else
			drug_list=""; conc_num="";
		endif
		Drug[i-1]=drug_list[0,strlen(drug_list)-2] // Get rid of trailing semicolon
		Conc[i-1]=conc_num[0,strlen(conc_num)-2]
		if(i==1)
			Last[i-1]=300
		else
			Last[i-1]=DecimalPlaces(60*(sweep_t[i-1]-sweep_t[i-2]),1)
		endif
		Wave /Z R1Wave=$(R1+num2str(i)); Wave /Z L2Wave=$(L2+num2str(i)); Wave /Z B3Wave=$(B3+num2str(i))
		Sweep_Dur[i-1]=DecimalPlaces(max(numpnts(B3Wave),max(numpnts(R1Wave),numpnts(L2Wave)))/(1000*kHz),1)
		for(j=0;j<ItemsInList(channel_list);j+=1)
			channel_str=StringFromList(j,channel_list)
			Wave Start=$(channel_str+"_Start")
			Wave Interval=$(channel_str+"_Interval")
			Wave Pulses=$(channel_str+"_Pulses")
			Wave Ampl=$(channel_str+"_Ampl")
			Wave Width=$(channel_str+"_Width")
			Redimension /n=(i) Start,Interval,Pulses,Ampl,Width
			Wave SweepParams=$("root:sweep_parameters_"+channel_str)
			//print j
			Start[i-1]=SweepParams[i][4]
			Interval[i-1]=SweepParams[i][3]
			Pulses[i-1]=SweepParams[i][2]
			Ampl[i-1]=SweepParams[i][1]
			Width[i-1]=SweepParams[i][0]
		endfor
	endfor
	Edit /K=1 /N=SweepRecords
	AppendToTable Sweep,File_Sweep,Drug,Conc,Last,Sweep_Dur
	for(i=0;i<ItemsInList(channel_list);i+=1)
		channel_str=StringFromList(i,channel_list)
		AppendToTable $(channel_str+"_Start"),$(channel_str+"_Pulses"),$(channel_str+"_Interval"),$(channel_str+"_Ampl"),$(channel_str+"_Width")
	endfor
	if(!waveexists(R1_Num) && !waveexists(L2_Num) && !waveexists(B3_Num))
		Make /n=1 R1_Num,L2_Num,B3_Num
		Make /T /n=1 R1_Phenotype,L2_Phenotype,B3_Phenotype
	endif
	Redimension /n=(max(numpnts(R1_Start),numpnts(L2_Start))) R1_Num,L2_Num,B3_Num,R1_Phenotype,L2_Phenotype,B3_Phenotype
	AppendToTable R1_Num,L2_Num,B3_Num,R1_Phenotype,L2_Phenotype,B3_Phenotype
	ModifyTable size=8,width=40
	Ones()
	Glut()
	//BMI()
	root()
	return used_channels
End

// Puts experiment information into a table for exporting to Access.  
Function /S Info2Access([file_name_str,sweep_offset])
	String file_name_str // Name of the experiment file being used.  
	Variable sweep_offset // The first sweep should be labeled as sweep 1+sweep_offset, in case there were other files with data
						// from the same island.  
	if(ParamIsDefault(file_name_str))
		file_name_str=IgorInfo(1)
	endif
	Variable i,j,sweep_num
	//SVar channels=root:parameters:active_channels
	String channel_list=all_channels //"R1;L2" // For the time being, make it easy by considering only R1 and L2
	if(ParamIsDefault(sweep_offset))
		sweep_offset=0 
		//Prompt sweep_offset,"Sweep Offset (default=0)"
		//DoPrompt "Please enter the sweep offset (default=0)", sweep_offset
	endif
	String channel_str
	NVar final_sweep=root:current_sweep_number
	
	// Legacy folders from when I was storing compressed versions of sweeps in the database.  
	NewDataFolder /O root:reanalysis
	NewDataFolder /O root:reanalysis:SweepReductions
	
	//The first window(s)	
	String used_channels=""
	for(i=0;i<ItemsInList(channel_list);i+=1)
		channel_str=StringFromList(i,channel_list)
		if(SweepsOnChannel(channel_str))
			NewDataFolder /O/S $("root:reanalysis:SweepReductions:"+channel_str)
			used_channels+=channel_str+";"
		else
			continue
		endif
		Make /o/n=1 Baseline,Sweep,Use=NaN,Flag=NaN
		Make /o/T /n=1 Experimenter,File_Name,File_Sweep,Channel,Locs,Vals,Compression_Method,Clamp,Average,Scale,Points,Comments=""
		Wave SweepParams=$("root:sweep_parameters_"+channel_str)
		Wave /Z OldAverages=$("root:reanalysis:SweepReductions:SweepAverages"+channel_str)
		Wave /Z OldScales=$("root:reanalysis:SweepReductions:SweepScales"+channel_str)
		Wave /Z OldPoints=$("root:reanalysis:SweepReductions:SweepPoints"+channel_str)
		j=1
		for(sweep_num=1;sweep_num<=final_sweep;sweep_num+=1)
			if(exists("root:cell"+channel_str+":sweep"+num2str(sweep_num)))
				//j=numpnts(sweep_nums)
				Redimension /n=(j) Experimenter,File_Name,Sweep,File_Sweep,Channel,Locs,Vals,Compression_Method,Clamp,Baseline,Average,Scale,Points
				Experimenter[j-1]="RCG"
				File_Name[j-1]=file_name_str
				Sweep[j-1]=sweep_num+sweep_offset
				File_Sweep[j-1]=file_name_str[strlen(file_name_str)-1]+num2str(sweep_num)
				//print file_name_str[strlen(file_name_str)-1]+num2str(sweep_num)
				Channel[j-1]=channel_str
				Locs[j-1]=""
				Vals[j-1]=""
				Compression_Method=""
				Clamp[j-1]=Num2Clamp(SweepParams[sweep_num][5])
				Wave sweepWave=$("root:cell"+channel_str+":sweep"+num2str(sweep_num))
				Baseline[j-1]=mean(sweepWave,0,min(0.25,SweepParams[sweep_num][4]/1000 - 0.01))
				if(waveexists(OldAverages)) // Should only exists for channels that have sweeps.  
					Average[j-1]=num2str(OldAverages[sweep_num-1])
					Scale[j-1]=num2str(OldScales[sweep_num-1])
					Points[j-1]=num2str(OldPoints[sweep_num-1])
				else
					Average[j-1]=num2str(NaN)
					Scale[j-1]=num2str(NaN)
					Points[j-1]=num2str(NaN)
				endif
				// End period for baseline is the minimum of 250 ms and the time of the first pulse - 10 ms
				j+=1
			endif
		endfor
		Baseline=(Baseline<=-10000) ? -9999 : Baseline // Do not allow to be less than or equal to -10000.  
		TestReductionLengths()
		Wave /Z OldAverages=$("root:reanalysis:SweepReductions:SweepAverages"+channel_str)
		Wave /Z OldScales=$("root:reanalysis:SweepReductions:SweepScales"+channel_str)
		Wave /Z OldPoints=$("root:reanalysis:SweepReductions:SweepPoints"+channel_str)
		if(SweepsOnChannel(channel_str)) // Should only exists for channels that have sweeps.  
			Edit /K=1 /N=$(channel_str+"_Sweeps_Locs_Vals")
			AppendToTable Experimenter,File_Name,Sweep,File_Sweep,Channel,Locs,Vals,Compression_Method,Average,Scale,Points,Clamp,Baseline
			ModifyTable size=8
		endif
	endfor

	// The last window
	SetDataFolder root:reanalysis:SweepReductions
	Make /o/n=1 Sweep,Last,Sweep_Dur,Use=NaN
	for(i=0;i<ItemsInList(channel_list);i+=1)
		channel_str=StringFromList(i,channel_list)
		Make /o/n=1 $(channel_str+"_Start"),$(channel_str+"_Pulses"),$(channel_str+"_Interval"),$(channel_str+"_Ampl"),$(channel_str+"_Width")
	endfor
	Make /o/T /n=1 Experimenter,File_Name,File_Sweep,Drug,Conc,Comments=""
	i=1
	Wave sweep_t=root:sweep_t
	String R1="root:cellR1:sweep"; String L2="root:cellL2:sweep"; String B3="root:cellB3:sweep"
	NVar kHz=root:parameters:kHz
	DrugInfo2DrugWaves(); 
	Wave /T DrugHistory=root:drugs:history; String drug_list,conc_num,conc_units
	for(i=1;i<=final_sweep;i+=1)
		Redimension /n=(i) Experimenter,File_Name,Sweep,File_Sweep,Drug,Conc,Last,Sweep_Dur
		Experimenter[i-1]="RCG"
		File_Name[j-1]=file_name_str
		Sweep[i-1]=i+sweep_offset
		File_Sweep[i-1]=file_name_str[strlen(file_name_str)-1]+num2str(i)
		if(strlen(DrugHistory[i])>0)
			drug_list=NthEntries2List(DrugHistory[i],0)
			conc_num=NthEntries2List(DrugHistory[i],1)
		else
			drug_list=""; conc_num="";
		endif
		Drug[i-1]=drug_list[0,strlen(drug_list)-2] // Get rid of trailing semicolon
		Conc[i-1]=conc_num[0,strlen(conc_num)-2]
		if(i==1)
			Last[i-1]=300
		else
			Last[i-1]=DecimalPlaces(60*(sweep_t[i-1]-sweep_t[i-2]),1)
		endif
		Wave /Z R1Wave=$(R1+num2str(i)); Wave /Z L2Wave=$(L2+num2str(i)); Wave /Z B3Wave=$(B3+num2str(i))
		Sweep_Dur[i-1]=DecimalPlaces(max(numpnts(B3Wave),max(numpnts(R1Wave),numpnts(L2Wave)))/(1000*kHz),1)
		for(j=0;j<ItemsInList(channel_list);j+=1)
			channel_str=StringFromList(j,channel_list)
			Wave Start=$(channel_str+"_Start")
			Wave Interval=$(channel_str+"_Interval")
			Wave Pulses=$(channel_str+"_Pulses")
			Wave Ampl=$(channel_str+"_Ampl")
			Wave Width=$(channel_str+"_Width")
			Redimension /n=(i) Start,Interval,Pulses,Ampl,Width
			Wave /Z SweepParams=$("root:sweep_parameters_"+channel_str)
			if(waveexists(SweepParams)) 
				Start[i-1]=SweepParams[i][4]
				Interval[i-1]=SweepParams[i][3]
				Pulses[i-1]=SweepParams[i][2]
				Ampl[i-1]=SweepParams[i][1]
				Width[i-1]=SweepParams[i][0]
			else
				Start[i-1]=NaN
				Interval[i-1]=NaN
				Pulses[i-1]=NaN
				Ampl[i-1]=NaN
				Width[i-1]=NaN
			endif
		endfor
	endfor
	Edit /K=1 /N=SweepRecords
	AppendToTable Sweep,File_Sweep,Drug,Conc,Last,Sweep_Dur
	for(i=0;i<ItemsInList(channel_list);i+=1)
		channel_str=StringFromList(i,channel_list)
		AppendToTable $(channel_str+"_Start"),$(channel_str+"_Pulses"),$(channel_str+"_Interval"),$(channel_str+"_Ampl"),$(channel_str+"_Width")
	endfor
	if(!waveexists(R1_Num) && !waveexists(L2_Num) && !waveexists(B3_Num))
		Make /n=1 R1_Num,L2_Num,B3_Num
		Make /T /n=1 R1_Phenotype,L2_Phenotype,B3_Phenotype
	endif
	Redimension /n=(max(numpnts(R1_Start),numpnts(L2_Start))) R1_Num,L2_Num,B3_Num,R1_Phenotype,L2_Phenotype,B3_Phenotype
	AppendToTable R1_Num,L2_Num,B3_Num,R1_Phenotype,L2_Phenotype,B3_Phenotype
	ModifyTable size=8,width=40
	Ones()
	Glut()
	//BMI()
	root()
	return used_channels
End

Function STDP2Access(pairings[,pathway,start,finish])
	Variable pairings // The number of pairings to find (e.g. 1 or 2)
	String pathway // The synaptic pathway, e.g. "R1_L2"
	Variable start // Start from the specified sweep (point actually, meaning sweep number - 1)
	Variable finish // End at the specified sweep (point actually, meaning sweep number - 1)
	
	if(ParamIsDefault(pathway))
		Wave theWave=CsrWaveRef(A,"Ampl_Analysis")
		pathway=Wave2Pathway(theWave)
	endif
	start=ParamIsDefault(start) ? pcsr(A) : start
	finish=ParamIsDefault(finish) ? pcsr(B) : finish
	String pre=StringFromList(0,pathway,"_")
	String post=StringFromList(1,pathway,"_")
	Wave SweepParams=root:$("sweep_parameters_"+pre)
	NewDataFolder /O/S root:AccessData
	Variable i,j,pre_induction_end,post_induction_start,cutoff,relative_place=start,absolute_place=start,sweep_time_offset
	String folder
	for(j=1;j<=pairings;j+=1)
		folder="root:AccessData:Pairing"+num2str(j)
		NewDataFolder /O/S $folder
		Duplicate /o $("root:cell"+post+":ampl_"+pathway) $(folder+":Ampl1"); Wave Ampl1
		Duplicate /o $("root:cell"+post+":ampl2_"+pathway)  $(folder+":Ampl2"); Wave Ampl2
		Duplicate /o root:sweep_t $(folder+":Sweep_Time"),$(folder+":File_Sweep_Time"); Wave Sweep_Time,File_Sweep_Time
		Make /o/n=(numpnts(root:sweep_t)) Sweep_Number,File_Sweep_Number,IPI,PPR
		Sweep_Number=x+1;File_Sweep_Number=x+1
		IPI=SweepParams[x+1][3]
		DoWindow /K $("Pairing"+num2str(j))
		Edit /N=$("Pairing"+num2str(j)) /K=1 Sweep_Number,File_Sweep_Number,Sweep_Time,File_Sweep_Time,IPI,Ampl1,Ampl2,PPR
		i=absolute_place
		// Find the start of the pairing in question.
		Do
			if(Ampl1[i] > 1)
				i+=1
			else
				pre_induction_end=File_Sweep_Time[i-1]
				break
			endif
		While(1)
		Sweep_Number-=(i+1);Sweep_Time-=pre_induction_end
		absolute_place=i; relative_place=i
		// Only include the first 15 minutes before the start of that pairing.  
		i=0
		cutoff = (j==1) ? File_Sweep_Time[start] : pre_induction_end-15
		Do
			if(File_Sweep_Time[i] < cutoff)
				i+=1
			else
				break
			endif
		While(1)
		DeletePoints2(0,i)
		relative_place-=i
		i=0
		// Find the end of that pairing and delete points that occur during the pairing.
		Do	
			if(Ampl1[i+relative_place] > 1)
				post_induction_start=File_Sweep_Time[i+relative_place+1]
				break
			else
				i+=1
			endif
		While(1)
		DeletePoints2(relative_place,i)
		Sweep_Number[relative_place,]-=(i-1);
		sweep_time_offset=Sweep_Time[relative_place]-1
		Sweep_Time[relative_place,]-=sweep_time_offset
		absolute_place+=i; relative_place-=i; 
		// Find the end of the post-pairing baseline and delete points beyond it.
		if(j<pairings) // If this is not the last pairing.  
			Do
				if(Ampl1[i] > 1)
					i+=1
				else
					break
				endif
			While(1)
			DeletePoints2(i,numpnts(File_Sweep_Time)-i)
		else
			i=1
			Do
				if(File_Sweep_Number[i] < finish+1)
					i+=1
				else
					break
				endif
			While(1)
			DeletePoints2(i+1,numpnts(File_Sweep_Time)-i)
		endif
		PPR=Ampl2/Ampl1
	endfor
	root()
End

// Assumes data has been set using printout manager.  
Function Printout(ctrlName)
	String ctrlName
	Preferences 1 // Turn preferences on so that Page Setup can be preserved across layouts
	
	Wave /T PreBaselineSweeps=root:PrintoutInfo:PreBaselineSweeps
	Wave /T PostBaselineSweeps=root:PrintoutInfo:PostBaselineSweeps
	Wave /T InductionSweeps=root:PrintoutInfo:InductionSweeps
	Wave sweep_t=root:sweep_t
	Wave theWave=CsrWaveRef(A,"Ampl_Analysis")
	String pathway=NameOfWave(theWave)
	pathway=pathway[strlen(pathway)-5,strlen(pathway)-1]
	Variable i,start,stop,right,bottom,med,thyme,offset,margins; String win_name,sweep_list
	Variable num_inductions=numpnts(InductionSweeps)
	String layout_name=CleanupName(IgorInfo(1)+"_"+pathway,0)
	DoWindow /K $layout_name
	NewLayout /K=1/N=$layout_name
	String layout_info=StringByKey("PAPER",LayoutInfo("","Layout"))
	right=str2num(StringFromList(2,layout_info,","))
	bottom=str2num(StringFromList(3,layout_info,","))
	margins=36
	String channel,name
	sscanf GetWavesDataFolder(theWave,0),"cell%s",channel
	// Add diary plots.  
	AppendLayoutObject /F=0 /R=(margins,margins,right-margins-150*num_inductions,0.48*bottom) /T=1 graph Membrane_Constants
	AppendLayoutObject /F=0 /R=(margins,0.52*bottom,right-margins-150*num_inductions,bottom-margins) /T=1 graph Ampl_Analysis
	//Make tags transparent
	String info,annotation,annotations=AnnotationList("Ampl_Analysis")
	for(i=0;i<ItemsInList(annotations);i+=1)
		annotation=StringFromList(i,annotations)
		info=AnnotationInfo("Ampl_Analysis",annotation)
		info=StringByKey("TYPE",info)
		if(StringMatch(info,"Tag"))
			Tag /C/N=$annotation /B=1
		endif
	endfor
	//
	// Harmonize Axes
	GetAxis /Q/W=Ampl_Analysis Time_Axis
	SetAxis /W=Membrane_Constants bottom, V_min,V_max
	ModifyGraph /W=Ampl_Analysis axisEnab(Time_axis)={0.06,1},freePos(Ampl_axis)={0.06,kwFraction}
	ModifyGraph /W=Membrane_Constants logTicks(input_axis)=4
	//
	
	// Add baselines.
	GetAxis /Q/W=Ampl_Analysis Ampl_Axis; Variable vert=V_max
	for(i=0;i<num_inductions;i+=1)
		sweep_list=PreBaselineSweeps[i]
		win_name=AverageWave(sweep_list=sweep_list,no_append=1)
		DoWindow /F $win_name
		sweep_list=PostBaselineSweeps[i]
		win_name=AverageWave(sweep_list=PostBaselineSweeps[i])
		SetAxis bottom,-0.005,0.025
		SetAxis left -V_max,10
		ModifyGraph fsize=8,btlen=2//,axRGB(left)=(65535,65535,65535),tlblRGB(left)=(65535,65535,65535),alblRGB(left)=(65535,65535,65535)
		AppendLayoutObject /F=0 /R=(right-margins-(num_inductions-i)*150,bottom/2-150,right-margins-(num_inductions-i-1)*150,bottom/2) /T=1 graph $win_name
	endfor
	
	// Add inductions.
	for(i=0;i<num_inductions;i+=1)
		print i, num_inductions
		win_name=AverageWave(sweep_list=InductionSweeps[i],no_append=1,presynaptic=1,post_vertical_align=0)
		SetAxis bottom,-0.01,0.025
		start=str2num(StringFromList(0,InductionSweeps[i],","))
		stop=str2num(StringFromList(1,InductionSweeps[i],","))
		thyme=RoundTo((sweep_t[start-1]+sweep_t[stop-1])/2,1)
		TextBox /A=LT/F=0/B=1/W=$win_name num2str(thyme)+" min."
		ModifyGraph fsize=8,btlen=2,axRGB(left)=(65535,65535,65535),tlblRGB(left)=(65535,65535,65535),alblRGB(left)=(65535,65535,65535)
		AppendLayoutObject /F=0 /R=(right-margins-(num_inductions-i)*150,bottom-margins-150,right-margins-(num_inductions-i-1)*150,bottom-margins) /T=1 graph $win_name
	endfor
	DoWindow /F $layout_name
	
	// Add text and clean up.  
	Textbox/N=Experiment/F=0/A=RT/X=0.5/Y=0.5 "\\JC\\Z16"+IgorInfo(1)+" ("+pathway+")"+"\r\\Z10\JCPrinted: "+date()
	SVar /Z simplified_notebook_text=root:PrintoutInfo:simplified_notebook_text
	if(!SVar_Exists(simplified_notebook_text))
		Notebook Experiment_Log selection={startOfFile, endOfFile}
		GetSelection notebook, Experiment_Log, 2
		String /G root:PrintoutInfo:simplified_notebook_text=S_selection
		SVar simplified_notebook_text=root:PrintoutInfo:simplified_notebook_text
	endif
	TextBox/A=LC/N=Logg/F=0/A=LB/X=1/Y=1 simplified_notebook_text
	TextBox /W=Ampl_Analysis/K/N=TimeStamp // There is a weird empty textbox here for some reason that needs to be deleted.  
	ModifyLayout trans=1,frame=0
	
	KillVariables /Z red,green,blue
End

// Applies tags onto an x-axis that corresponds to cumulative recorded time.  Absolute times coded in root:Drugs:Info are converted into cumulative
// recorded times.  
Function DrugTags2()
	Wave /Z/T info=root:drugs:info
	Variable i,j,conc,multiplier,thyme; String entry,subentry,name,units,tag_text
	if(!waveexists(info))
		return 0
	endif
	for(i=0;i<numpnts(info);i+=1)
		entry=info[i]
		tag_text=""
		for(j=0;j<ItemsInList(entry);j+=1)
			subentry=StringFromList(j,entry)
			units=StringFromList(3,subentry,",")
			if(strlen(units)>2)
				multiplier=str2num(units[0,strlen(units)-4])
				units=units[strlen(units)-2,strlen(units)-1]
			else
				multiplier=1
			endif
			conc=str2num(StringFromList(2,subentry,","))
			name=StringFromList(1,subentry,",")
			thyme=str2num(StringFromList(0,subentry,","))
			Wave sweep_t=root:sweep_t
			Variable sweep_num=2+BinarySearch(sweep_t,thyme)
			thyme=SweepNum2CumulativeDuration(sweep_num)/60
			tag_text+=num2str(conc*multiplier)+" "+units+" "+name+"\r"
		endfor
		tag_text=tag_text[0,strlen(tag_text)-2]
		if(StringMatch(tag_text,"*Washout*"))
			tag_text="All drugs washed out"
		endif
		Tag /F=0/B=1/X=0/Y=(25-2*i) bottom,thyme,"\Z"+num2ndigits(7,2)+tag_text
	endfor
End

// Compares two conditons, e.g. control and TTX, whose values are given in DataWave and whose
// conditions are given in condition wave.  
Function CompareSubsets(DataWave,ConditionWave,conditions[,min_val,RestrictionWave,restriction_min,restriction_condition,no_plot])
	Wave DataWave
	Wave /T ConditionWave
	String conditions
	Variable min_val
	Wave RestrictionWave // A companion wave whose values will be used for restricting the subset.  
	Variable restriction_min // The RestrictionWave must be at least this value.  
	String restriction_condition // The restriction will only apply when the condition matches this value.  
	Variable no_plot
	
	min_val=ParamIsDefault(min_val) ? -Inf : min_val
	restriction_min=ParamIsDefault(restriction_min) ? -Inf : restriction_min
	Variable i
	String wave_list=""
	for(i=0;i<ItemsInList(conditions);i+=1)
		String condition=StringFromList(i,conditions)
		String subset_name=NameOfWave(DataWave)+"_"+condition
		Make /o/n=(numpnts(DataWave)) CompareSubsetsWave=0
		CompareSubsetsWave=StringMatch(ConditionWave,condition) && numtype(DataWave)==0 && DataWave>min_val
		if(!ParamIsDefault(RestrictionWave))
			CompareSubsetsWave=CompareSubsetsWave && (RestrictionWave>restriction_min || !StringMatch(ConditionWave,restriction_condition))
		endif
		Extract /O DataWave,$subset_name,CompareSubsetsWave
		Wave Subset=$subset_name
		//Sort Subset,Subset
		SetScale x,0,1,Subset
		wave_list+=subset_name+";"
	endfor
	KillWaves /Z CompareSubsetsWave
	KillVariables /Z red,green,blue
	if(!no_plot)
		CumulPlot(wave_list,graph_name=GetDataFolder(0))
	endif
End

// Puts the cursors in logical positons, based on the beginning of the stimulus for the sweep they are currently on
Function LogicalCursorPos()
	String sweep=CsrWave(A,"Sweeps")
	String channel; Variable sweep_num,start_time
	if(StringMatch(sweep,"*sweep*"))
	// Not sure how to get the channel from the sweep name if it is a previous sweep (like input_A).  
//		sscanf sweep,"sweep%d",sweep_num
//		start_time=EarliestStim(labell=channel)
//		channel=Wave2Channel(CsrWaveRef(A,"Sweeps"))
//		Wave SweepParams=$("root:sweep_parameters_"+channel)
//		start_time=SweepParams[sweep_num][4]/1000
	else
		sscanf sweep,"input_%s'",channel
		NVar curr_sweep=root:current_sweep_number
		start_time=EarliestStim(curr_sweep+1,channel_label=channel)
//		NVar begin=root:parameters:$(channel+"_begin")
//		start_time=begin/1000
	endif
	
	//print start_time
	Cursor A $CsrWave(A,"Sweeps",1) start_time+0.005 // Add 5 ms to avoid the stimulus artifact
End

// Displays the cumulative charge passed vs. time elapsed since the beginning of 'first_sweep'.  
Function CumulChargeOverTime([channel,first_sweep,last_sweep])
	String channel
	Variable first_sweep,last_sweep
	if(ParamIsDefault(channel))
		channel=Cursor2Channel(win="Ampl_Analysis")
	endif
	first_sweep=ParamIsDefault(first_sweep) ? 1+xcsr(A,"Ampl_Analysis") : first_sweep
	last_sweep=ParamIsDefault(last_sweep) ? 1+xcsr(B,"Ampl_Analysis") : last_sweep
	Wave sweep_t=root:sweep_t
	Make /o/n=1 $(channel+"_CCOT_Charge")=0,$(channel+"_CCOT_Thyme")=0
	Wave CCOT_Charge=$(channel+"_CCOT_Charge")
	Wave CCOT_Thyme=$(channel+"_CCOT_Thyme")
	Variable i
	for(i=first_sweep;i<=last_sweep;i+=1)
		InsertPoints 0,1,CCOT_Charge,CCOT_Thyme
		Wave /Z Sweep=$("root:cell"+channel+":sweep"+num2str(i))
		if(waveexists(Sweep))
			WaveStats /Q Sweep
			Variable charge=StatsMedian(Sweep)-V_avg
			Variable thyme=SweepDuration(i)
		else
			charge=0
			thyme=0
		endif
		CCOT_Charge[0]=CCOT_Charge[1]+charge
		CCOT_Thyme[0]=CCOT_Thyme[1]+thyme
	endfor
	WaveTransform /O flip CCOT_Charge
	WaveTransform /O flip CCOT_Thyme
	//Display /K=1 CCOT_Charge vs CCOT_Thyme
	//Channel2Color(channel); NVar red,green,blue
	//ModifyGraph rgb(CCOT_Charge)=(red,green,blue)
	//KillVariables /Z red,green,blue
End

// Displays the cumulative charge passed vs. time elapsed since the beginning of 'first_sweep'.  Resolution is much better than one sweep, e.g. 10 ms.  
Function CumulChargeOverTime2([channel,first_sweep,last_sweep,downsample])
	String channel
	Variable first_sweep,last_sweep
	Variable downsample
	if(ParamIsDefault(channel))
		channel=Cursor2Channel(win="Ampl_Analysis")
	endif
	first_sweep=ParamIsDefault(first_sweep) ? 1+xcsr(A,"Ampl_Analysis") : first_sweep
	last_sweep=ParamIsDefault(last_sweep) ? 1+xcsr(B,"Ampl_Analysis") : last_sweep
	downsample=ParamIsDefault(downsample) ? 100 : downsample
	Wave sweep_t=root:sweep_t
	Wave /Z SweepParams=$("root:Sweep_Parameters_"+channel)
	Make /o/n=0 $(channel+"_CCOT_Charge")=0
	Wave CCOT_Charge=$(channel+"_CCOT_Charge")
	if(!waveexists(SweepParams))
		return 0
	endif
	Variable i
	for(i=first_sweep;i<=last_sweep;i+=1)
		Wave /Z Sweep=$("root:cell"+channel+":sweep"+num2str(i))
		Variable VC=(SweepParams[i][5]==1)
		if(waveexists(Sweep) && VC) // If the sweep exists and was recorded in voltage clamp.  
			Wave Downsampled=$Downsample(Sweep,downsample)
			Variable MedianValue=StatsMedian(Sweep)
			Downsampled-=MedianValue
		else
			Make /o/n=((10000/downsample)*SweepDuration(i)) Downsampled=0
		endif
		Concatenate /NP {Downsampled},CCOT_Charge
		KillWaves Downsampled
	endfor
	Integrate CCOT_Charge
	CCOT_Charge*=-1
	CCOT_Charge*=(downsample/10000) // Convert to picoCoulombs.  
	SetScale /P x,0,(0.0001*downsample/60),CCOT_Charge
	//Display /K=1 CCOT_Charge vs CCOT_Thyme
	//Channel2Color(channel); NVar red,green,blue
	//ModifyGraph rgb(CCOT_Charge)=(red,green,blue)
	//KillVariables /Z red,green,blue
End

// Make a color plot where the horizontal axis is event size, the vertical axis is time, and the color represents the density of events of that size at that time.  
Function EventValuesOverTime(EventTimes,EventSizes,time_periods,smallest,largest[,time_interval,size_interval,time_width,size_width])
	Wave EventTimes,EventSizes
	String time_periods // e.g. "10,15; 28,47"
	Variable smallest,largest // All units in seconds.  
	Variable time_interval,size_interval
	Variable time_width,size_width // The width of the bins (they can overlap).  
	
	time_interval=ParamIsDefault(time_interval) ? 60 : time_interval
	size_interval=ParamIsDefault(size_interval) ? 2.5 : size_interval 
	time_width=ParamIsDefault(time_width) ? 4*time_interval : time_width
	//size_width=ParamIsDefault(size_width) ? *size_interval : size_width 
	
	Variable i,start,finish
	start=str2num(StringFromList(0,StringFromList(0,time_periods),","))
	finish=str2num(StringFromList(1,StringFromList(ItemsInList(time_periods)-1,time_periods),","))
	Make /o/n=(floor((largest-smallest)/size_interval),floor((finish-start)/time_interval)) EVOT=0
	SetScale /P y,start,time_interval,EVOT
	SetScale /P x,smallest,size_interval,EVOT
	Duplicate /o /R=[][0,0] EVOT,SomeSizesHist
	
	Sort EventTimes,EventTimes,EventSizes
	
	Variable time_,left,right,first,last
	for(i=0;i<dimsize(EVOT,1);i+=1)
		time_=start+i*time_interval
		if(InRegion(time_,time_periods))
			left=max(start,time_-time_width/2)
			right=min(finish,time_+time_width/2)
			first=1+BinarySearch(EventTimes,left)
			last=BinarySearch(EventTimes,right)
			Duplicate /o /R=[first,last] EventSizes SomeSizes
			Histogram /B=2 SomeSizes SomeSizesHist
			Integrate SomeSizesHist
			Smooth 1,SomeSizesHist
			SomeSizesHist/=(right-left) // Normalize to time range.  
			SomeSizesHist/=size_interval
			EVOT[][i]=SomeSizesHist[p]
			//print left,right,first,last
		endif
	endfor
	
	NewWaterfall /K=1 /N=EVOT_Waterfall EVOT
	Duplicate /o/R=[][0,0] EVOT EVOT_Baseline; EVOT_Baseline=0
	for(i=0;i<1;i+=1)
		Duplicate /o/R=[][i,i] EVOT EVOT_Section
		EVOT_Baseline+=EVOT_Section
	endfor
	EVOT_Baseline/=i
	EVOT/=EVOT_Baseline[p]
	//EVOT=log(EVOT)
//	Display /K=1 /N=EVOT_Image
//	AppendImage /L=time_axis /T=size_axis EVOT
//	ModifyGraph axisEnab(size_axis)={0.05,1},axisEnab(time_axis)={0,0.90}
//	ModifyGraph freePos(size_axis)={0.1,kwFraction}
//	ModifyGraph freePos(time_axis)={0.05,kwFraction}
//	Label time_axis "s"
//	Label size_axis "pA"
//	//EVOT=log(EVOT)
//	//EVOT+=3*log(x)
//	ModifyGraph log(size_axis)=1
//	SetAxis size_axis smallest,largest
//	SetAxis/A/R time_axis
//	ModifyImage EVOT ctab= {*,*,Geo,0}
//	ModifyGraph lblPos=50
	//Variable num_log_ticks=ceil(log(largest/smallest))
	//Make /o/n=(num_log_ticks) LogTicks=floor(log(smallest))+p
	//Make /o/T/n=(num_log_ticks) LogTickLabels=num2str(10^(LogTicks[p]))
	//ModifyGraph userticks(top)={LogTicks,LogTickLabels}
	//ModifyGraph swapXY=1
	
	KillWaves SomeSizes,SomeSizesHist
End

// Make a color plot where the horizontal axis is event size, the vertical axis is time, and the color represents the density of events of that size at that time.  
Function EventValuesOverTimeLog(EventTimes,EventSizes,time_periods,smallest,largest[,time_interval,size_interval,time_width,size_width])
	Wave EventTimes,EventSizes
	String time_periods // e.g. "10,15; 28,47"
	Variable smallest,largest // All units in seconds.  
	Variable time_interval,size_interval
	Variable time_width,size_width // The width of the bins (they can overlap).  
	
	time_interval=ParamIsDefault(time_interval) ? 120 : time_interval
	size_interval=ParamIsDefault(size_interval) ? 0.05 : size_interval // Log units
	time_width=ParamIsDefault(time_width) ? 4*time_interval : time_width
	size_width=ParamIsDefault(size_width) ? 2*size_interval : size_width // Log units
	
	Variable i,start,finish
	start=str2num(StringFromList(0,StringFromList(0,time_periods),","))
	finish=str2num(StringFromList(1,StringFromList(ItemsInList(time_periods)-1,time_periods),","))
	Make /o/n=(floor(log(largest/smallest)/size_interval),floor((finish-start)/time_interval)) EVOT_Log=NaN
	SetScale /P y,start,time_interval,EVOT_Log
	SetScale /P x,log(smallest),size_interval,EVOT_Log
	Duplicate /o /R=[][0,0] EVOT_Log,SomeSizesHist
	
	Sort EventTimes,EventTimes,EventSizes
	
	Variable time_,left,right,first,last
	for(i=0;i<dimsize(EVOT_Log,1);i+=1)
		time_=start+i*time_interval
		if(InRegion(time_,time_periods))
			left=max(start,time_-time_width/2)
			right=min(finish,time_+time_width/2)
			first=1+BinarySearch(EventTimes,left)
			last=BinarySearch(EventTimes,right)
			Duplicate /o /R=[first,last] EventSizes SomeSizes
			SomeSizes=log(SomeSizes)
			Histogram /B=2 SomeSizes SomeSizesHist
			Smooth 2,SomeSizesHist
			SomeSizesHist/=(right-left) // Normalize to time range.  
			SomeSizesHist/=((10^(x+size_interval)) - (10^x))
			EVOT_Log[][i]=SomeSizesHist[p]
			//print left,right,first,last
		endif
	endfor
	
	NewWaterfall /K=1 /N=EVOT_Waterfall EVOT_Log
	Duplicate /o EVOT_Log EVOT_Colors
	EVOT_Colors=q
	ModifyGraph zColor(EVOT_Log)={EVOT_Log,*,*,Rainbow,0}
	Duplicate /o/R=[][0,0] EVOT_Log EVOT_Baseline; EVOT_Baseline=0
	for(i=0;i<1;i+=1)
		Duplicate /o/R=[][i,i] EVOT_Log EVOT_Section
		EVOT_Baseline+=EVOT_Section
	endfor
	EVOT_Baseline/=i
	EVOT_Log/=EVOT_Baseline[p]
	EVOT_Log=log(EVOT_log)
//	Display /K=1 /N=EVOT_Log_Image
//	AppendImage /L=time_axis /T=size_axis EVOT_Log
//	ModifyGraph axisEnab(size_axis)={0.05,1},axisEnab(time_axis)={0,0.90}
//	ModifyGraph freePos(size_axis)={0.1,kwFraction}
//	ModifyGraph freePos(time_axis)={0.05,kwFraction}
//	Label time_axis "s"
//	Label size_axis "pA"
//	//SetAxis size_axis log(smallest),log(largest)
//	SetAxis/A/R time_axis
//	ModifyImage EVOT_Log ctab= {*,*,Rainbow,1}
//	ModifyGraph lblPos=50
//	Variable num_log_ticks=ceil(log(largest/smallest))+1
//	Make /o/n=(num_log_ticks) LogTicks=floor(log(smallest))+p
//	Make /o/T/n=(num_log_ticks) LogTickLabels=num2str(10^(LogTicks[p]))
//	ModifyGraph userticks(size_axis)={LogTicks,LogTickLabels}
//	//ModifyGraph swapXY=1
	KillWaves SomeSizes,SomeSizesHist
End

Function IdentifyBarrages(theWave[,thresh])
	Wave theWave
	Variable thresh
	thresh=ParamIsDefault(thresh) ? 5 : thresh
	Duplicate /o theWave,BarrageTemp
	RemoveTestPulses(BarrageTemp,interval=10)
	BarrageTemp = BarrageTemp > -40 ? -40 : BarrageTemp
	Smooth 10000,BarrageTemp;Differentiate BarrageTemp;BarrageTemp=abs(BarrageTemp)
	Smooth 10000,BarrageTemp;Differentiate BarrageTemp;BarrageTemp=abs(BarrageTemp);
	Smooth 10000,BarrageTemp;BarrageTemp=BarrageTemp^2
	DownSample(BarrageTemp,10)
	Variable i,summ=0
	for(i=0;i<numpnts(BarrageTemp);i+=1)
		summ+=BarrageTemp[i]
		BarrageTemp[i]=summ
		summ*=(1-0.01)
	endfor
	BarrageTemp/=10000
	FindLevels /Q BarrageTemp,thresh; Wave Levels=W_FindLevels
	i=0
	// Discard level-crossings if they are down through the level rather than up.  
	Do
		if(BarrageTemp[x2pnt(BarrageTemp,Levels[i])]>BarrageTemp[x2pnt(BarrageTemp,Levels[i])+1])
			DeletePoints i,1,Levels
		else
			i+=1
		endif
	While(i<numpnts(Levels))
End

// Params should be something like "Rs;ISIs;Width;WidthX;Peak;PeakX;Thresh;ThreshX;AHP;AHPX"
Function FileParamSummaries(params)
	String params
	Variable i,j
	Wave /T File_Name=File_Name
	Wave /T Condition=Condition	
	String name_stem,name,param,displayed
	for(j=0;j<ItemsInList(params);j+=1)
		param=StringFromList(j,params)
		Wave ParamWave=$param
		String files_left=FileRecord()
		for(i=0;i<numpnts(File_Name);i+=1)
			name_stem=File_Name[i]//+"_"+Condition[i]
			name=name_stem+"_"+param
			if(WhichListItem(name_stem,files_left)!=-1) // If File_Name[i] is not in the list of files for whom a wave has
												   // already been made for that parameter
				Make /o/n=0 $name
				files_left=RemoveFromList(name_stem,files_left)
			endif
			InsertPoints numpnts($name),1,$name
			Wave theWave=$name
			theWave[numpnts(theWave)-1]=ParamWave[i]
		endfor
		print j
	endfor
End

// Stores basic data for each cell, according to what is in record_list
Function /S FileRecord()
	String /G file_list=""
	String record_list="Experimenter;File_Name;Condition;Bath_Drug;Duration;Rs"
	String is_text="1;1;1;1;0;0",record	
	Variable i,j,text,index
	// Make the waves that will store the basic data for each cell
	for(i=0;i<ItemsInList(record_list);i+=1)
		record=StringFromList(i,record_list)
		text=NumFromList(i,is_text)
		if(text)
			Make /o/n=0 /T $("Cell"+record)
		else
			Make /o/n=0 $("Cell"+record)
		endif
	endfor
	
	// Store the data
	Wave /T File_Name=File_Name
	for(i=0;i<numpnts(File_Name);i+=1)
		if(WhichListItem(File_Name[i],file_list)==-1)
			file_list+=File_Name[i]+";"
			for(j=0;j<ItemsInList(record_list);j+=1)
				record=StringFromList(j,record_list)
				text=NumFromList(j,is_text)
				Redimension /n=(index+1) $("Cell"+record)
				if(text)
					Wave /T TextRecord=$record
					Wave /T CellTextRecord=$("Cell"+record)
					CellTextRecord[index]=TextRecord[i]
				else
					Wave /Z NumRecord=$record
					Wave /Z CellNumRecord=$("Cell"+record)
					CellNumRecord[index]=NumRecord[i]
				endif
			endfor
			index+=1
		endif
	endfor
	return file_list
End

// To load an excel file of a query saved from Access
//XLLoadWave/S="Query1"/R=(A1,L6357)/COLT="2T10N"/W=1/O/D/T/V=0 "C:Documents and Settings:Rick:Desktop:Query1.xls"
// Change the COLT flag if there is something other than two text columns followed by 10 numeric columns

// Perform a CV analysis (using 1/CV^2) and plot the results.  
// NOTE: Correction no longer works as of 4/28/2011.  
Function CVAnalysis2(wave_names[,correction])
	String wave_names // A list of waves, each containing the synaptic strength for each trial of one experiment.    
	Variable correction // Correct for slow variations in the signal that artificially increase the standard deviation.  
	NewDataFolder /O/S root:CV_Analysis
	Make /o/n=(ItemsInList(wave_names)) MeanChange,CVSquaredChange
	SetDataFolder root:Raw
	Display /K=1 
	Variable before,after
	Variable before1=0,before2=19,after1=61,after2=80 // Determines the regions of the baseline to use.  
	Variable i; String wave_name
	for(i=0;i<ItemsInList(wave_names);i+=1)
		wave_name=StringFromList(i,wave_names)
		Wave theWave=$wave_name
		WaveStats /Q /R=(before1,before2) theWave
		before=V_avg
		WaveStats /Q /R=(after1,after2) theWave
		after=V_avg
		MeanChange[i]=after/before
		duplicate /free/r=(before1,before2) theWave,beforeWave
		duplicate /free/r=(before1,before2) theWave,afterWave
		before=1/(CV(beforeWave))
		after=1/(CV(afterWave))
		CVSquaredChange[i]=after/before
		print wave_name+" STDP Ratio: "+num2str(MeanChange[i])+"; 1/CV^2 change: "+num2str(CVSquaredChange[i])
	endfor
	AppendToGraph CVSquaredChange vs MeanChange
	Label bottom "Change in Mean"
	Label left "Change in 1/CV^2"
	BigDots()
	SetAxis bottom 0,1.5
	SetAxis /A left
	SetDrawEnv xcoord=bottom, ycoord=left
	DrawLine 0,0,2,2
End

Function TestReductionLengths()
	Variable i
	Wave /T Locs,Vals
	for(i=0;i<numpnts(Vals);i+=1)
		if(strlen(Locs[i])>65535 || strlen(Vals[i])>65535)
			print "Too many characters: Sweep "+num2str(i+1)
			print "Locs="+num2str(strlen(Locs[i]))
			print "Vals="+num2str(strlen(Vals[i]))
			print "\r"
		endif
	endfor
End

// Refractory =0.005, Smooth_Val=100 is good for storing lots of data
Function /S PeakFinderOld(first,last,smooth_val[,refractory])
	Variable first,last,smooth_val
	Variable refractory
	//print first,last
	SetDataFolder root:reanalysis:SweepSummaries
	NVar VC=VC
	Wave CursorWave=CsrWaveRef(A)
	Duplicate /o CursorWave theWave
	Variable i,baseline,thresh
	if(ParamIsDefault(refractory))
		refractory=0.005 // The refractory period for peaks (s)
	endif
	String /G peak_locs=""; String /G peak_vals=""; String /G trough_locs=""; String /G trough_vals=""
	if(VC==0) // Current Clamp
		baseline=-65 // The typical baseline in current clamp (mV)
		thresh=-20 // The threshold for counting a spike (mV)
		//refractory=0.01 
		first=leftx(theWave) // Ignore the passed value of the parameter and start with the left edge of the wave
		last=rightx(theWave) // Ignore the passed value of the parameter and scan to the right edge of the wave
		FindLevels /Q/R=(first,last) theWave,thresh // Find crossings
		Wave levels=W_FindLevels
		for(i=0;i<numpnts(levels)-1;i+=1)
			if(mean(theWave,levels[i],levels[i+1]) > thresh)
				//print levels[i],levels[i+1]
				WaveStats /Q/R=(levels[i],levels[i+1]) theWave // Search for a maximum in between those crossings.  
				//if(!V_flag) // If a peak was found
					peak_locs+=num2str(V_maxloc)+";"
					peak_vals+=num2str(V_max)+";"
				//endif
			endif
		endfor
	else // Voltage Clamp
		baseline=0 // The typical baseline for voltage clamp (pA)
		//refractory=0.01
		theWave*=-1
		first=leftx(theWave) // Ignore the passed value of the parameter and start with the left edge of the wave
		last=rightx(theWave) // Ignore the passed value of the parameter and scan to the right edge of the wave
		String hpf_str=HighPassFilter(theWave,2,1) // High pass filter to remove the slow component
		Wave hpf=$hpf_str
		Duplicate /o hpf smoothed
		Smooth smooth_val, smoothed 
		Differentiate smoothed
		Smooth smooth_val, smoothed
		FindLevels /Q/R=(first,last) smoothed,0 // Find zero crossings in the first derivative
		//Display smoothed
		Differentiate smoothed
		Smooth smooth_val, smoothed
		Wave levels=W_FindLevels
		//Display smoothed
		//print levels
		for(i=0;i<numpnts(levels);i+=1)			
			if(smoothed(levels[i])<0) // If the second derivative is negative (concave up, since the wave was flipped, indicating a peak in voltage clamp)
				//Display hpf
				levels[i]=AscendGradient(theWave,levels[i]) // Move around to find the real peak
				if(theWave(levels[i])>-vcsr(A)) // and if the peak is above the original cutoff (larger than the point indicated by Cursor A)
					peak_locs+=num2str(levels[i])+";" // Add it to the list
					peak_vals+=num2str(theWave(levels[i]))+";" // ...
					if(i<4)
						//print levels[i]
						//print theWave(levels[i])
					endif
				endif
			endif
		endfor
	endif
	//print peak_locs
	SpacePeaks(refractory)
	Variable left,right
	for(i=1;i<ItemsInList(peak_locs);i+=1)
		left=str2num(StringFromList(i-1,peak_locs))
		right=str2num(StringFromList(i,peak_locs))
		WaveStats /Q/R=(left,right) theWave // Search for a maximum in between those crossings.  
		trough_locs+=num2str(V_minloc)+";"
		trough_vals+=num2str(min(theWave(V_minloc-0.0001),theWave(V_minloc+0.0001)))+";"
		//trough_vals+=num2str(V_min)+";"
	endfor
	if(VC)
		peak_vals=NegList(peak_vals); // Flip the sign of the amplitudes since the analysis was done with the negative of the original voltage clamp signal.  
		trough_vals=NegList(trough_vals);
	endif
	ImpulseFromList(theWave,peak_locs,vals=peak_vals,destName="PeakWave",baseline=baseline)
	ImpulseFromList(theWave,trough_locs,vals=trough_vals,destName="TroughWave",baseline=baseline)
	KillWaves theWave
	return peak_locs+"::"+peak_vals
End

Function Analyzer(ctrlname) : ButtonControl // A master control window for doing analysis of experiments.
	String ctrlname
	PauseUpdate; Silent 1		// building window...
	if(cmpstr(WinList("AnalyzerWin",";",""),""))
		DoWindow/f AnalyzerWin
	else
		Execute "NewPanel /K=1 /W=(625,100,1015,310) as \"AnalyzerGUI\""
		SetDrawLayer ProgBack
		SetDrawEnv fillfgc= (39321,1,1)
		SetDrawLayer UserBack
		SetDrawEnv fillpat= 0
		SetDrawEnv fillpat= 0
		if(!DataFolderExists("root:reanalysis"))
			newdatafolder /o/s root:reanalysis
		endif 
		SetDataFolder root:reanalysis
		Duplicate /o root:cellR1:ampl_L2_R1 root:cellR1:ampl
		Duplicate /o root:cellL2:ampl_R1_L2 root:cellL2:ampl
		String /G sweepString=""
		String /G infoString=""
		String /G whichCells="R1->L2"
		String /G inductionOrder="64;16"
		Variable /G offset=0
		Variable /G plotMethod=1
		Variable /G ovalSize=10
		Variable /G version=3 // This is the version of the data storage method I use; 2 means only 2 channels; 3 means 3 channels.  
		Variable /G firstInduction=0
		Variable /G lastInduction=10
		Variable /G lowerTiming=0
		Variable /G upperTiming=100
	
		SetVariable sweepstringSet,pos={2,2},size={300,18},title="Sweeps2Analyze",value=sweepString
		SetVariable sweepstringSet,help={"The beginnings and ends of the analysis periods, separated by commas (between start and endpoints) and semicolons (between analysis periods)"}
	
		SetVariable infostringSet,pos={2,23},size={200,18},title="InfoString",value=infoString
		SetVariable infostringSet,help={"Information to allow the program to redetermine the amplitudes of the first and second pulses for each sweep"}
	
		SetVariable whichCellSet,pos={2,44},size={125,18},title="Pathway",value=whichCells
		SetVariable whichCellSet,help={"The presynaptic cell followed by the postsynaptic cell"}
		PopupMenu whichCellMenu,pos={125,44},size={75,19},Proc=PickCell,mode=0,value="R1->L2;L2->R1;R1->B3;B3->R1;L2->B3;B3->L2"
		
		SetVariable offsetSet,pos={305,2},size={80,17},title="Offset",value=offset,limits={0,10,1}
		SetVariable plotMethodSet,pos={305,25},size={80,17},title="Method",value=plotMethod,limits={1,3,1}
		SetVariable ovalSizeSet,pos={305,48},size={80,17},title="Oval",value=ovalSize,limits={0,100,0.1}
		SetVariable versionSet,pos={275,71},size={110,17},title="Data Version",value=version,limits={0,100,0.1}
		SetVariable firstIndSet,pos={275,94},size={110,19},title="First Induction",value=firstInduction,limits={0,10,1}
		SetVariable lastIndSet,pos={275,117},size={110,19},title="Last Induction",value=lastInduction,limits={0,10,1}
		SetVariable lowerTimSet,pos={275,140},size={110,19},title="Lower Timing",value=lowerTiming,limits={0,100,1}
		SetVariable upperTimSet,pos={275,163},size={110,19},title="Upper Timing",value=upperTiming,limits={0,100,1}
		SetVariable indOrderSet,pos={270,186},size={115,19},title="Induction Order",value=inductionOrder
	
		Button Data2Access,pos={5,63},size={75,18},title="\\Z10Data 2 Access",proc=AnalysisProc
		Button RedoAmps,pos={85,63},size={75,18},title="\\Z10Redo Amps",proc=AnalysisProc
		Button HistoryGraph,pos={165,63},size={75,18},title="\\Z10HistoryGraph",proc=AnalysisProc
		
		Button RemoveAll,pos={5,86},size={75,18},title="\\Z10RemoveAll",proc=AnalysisProc
		Button TimeDif,pos={85,86},size={75,18},title="\\Z10TimeDif",proc=AnalysisProc
		Button Access2Igor,pos={165,86},size={75,18},title="\\Z10Access 2 Igor",proc=AnalysisProc
		
		Button SelectN,pos={5,109},size={75,18},title="\\Z10SelectN",proc=AnalysisProc
		Button SelectOrder,pos={85,109},size={75,18},title="\\Z10SelectOrder",proc=AnalysisProc
		Button ImpulseFuncs,pos={165,109},size={75,18},title="\\Z10ImpulseFuncs",proc=AnalysisProc
		
		Button RsComp,pos={5,132},size={75,18},title="\\Z10RsCompensate",proc=AnalysisProc
		Button Redo1Amp,pos={85,132},size={75,18},title="\\Z10Redo1Amp",proc=AnalysisProc
		Button Rid,pos={165,132},size={75,18},title="\\Z10Rid",proc=AnalysisProc
	endif
EndMacro

Proc PickCell(ctrlName,popNum,popStr) : PopupMenuControl // Which pathway do you want to analyze (under what version)?
	String ctrlName
	Variable popNum
	String popStr
	SetDataFolder root:reanalysis
	DoWindow/F reanalysis_window
	Make /o/n=1 NanWave; NanWave=Nan
	AppendToGraph /L=ampl_left_axis/B=ampl_bottom_axis NanWave
	RemoveFromGraph/Z ampl
	whichCells=popStr[4,5]
	AppendToGraph/W=reanalysis_window /L=ampl_left_axis/B=ampl_bottom_axis/C=(65535*!cmpstr(popStr[4,5],"R1"),65535*!cmpstr(popStr[4,5],"B3"),65535*!cmpstr(popStr[4,5],"L2")) $("root:cell"+popStr[4,5]+":ampl")
	ModifyGraph/Z mode(ampl)=2
	ModifyGraph/Z /W=reanalysis_window lsize(ampl)=3
	Duplicate /o $("root:cell"+popStr[4,5]+":ampl_"+popStr[0,1]+"_"+popStr[4,5]) $("root:cell"+popStr[4,5]+":ampl")
End

//Function AnalysisProc(ctrlName) : ButtonControl // Route the button press to the appropriate function.  
//	String ctrlName
//	SVar whichCells=root:reanalysis:whichCells
//	SVar sweepString=root:reanalysis:sweepString
//	NVar offset=root:reanalysis:offset
//	NVar whichPulse=root:reanalysis:whichPulse
//	NVar method=root:reanalysis:method
//	NVar firstInduction=root:reanalysis:firstInduction
//	NVar lastInduction=root:reanalysis:lastInduction
//	NVar lowerTiming=root:reanalysis:lowerTiming
//	Nvar upperTiming=root:reanalysis:upperTiming
//	Svar inductionOrder=root:reanalysis:inductionOrder
//	
//	strswitch(ctrlName)		
//		case "Data2Access":
//			print whichCells+";"+sweepString
//			print offset
//			Data2Access(whichCells+";"+sweepString,offset)
//		break
//		case "RedoAmps":
//			RedoAmps(whichCells,whichPulse,method)
//		break
//		case "HistoryGraph":
//			HistoryGraph("poop",method)
//		break
//		case "RemoveAll":
//			RemoveGraphsAndTables()
//		break
//		case "TimeDif":
//			TimeDif()
//		break
//		case "Access2Igor":
//			Access2Igor()
//		break
//		case "SelectN":
//			SelectN(firstInduction,lastInduction,lowerTiming,upperTiming,poop)
//		break
//		case "SelectOrder":
//			SelectOrder(inductionOrder,firstInduction,lastInduction,inputOrig)
//		break
//		case "ImpulseFuncs":
//			GetImpulseResponses(str2num(whichCells[1]),method,offset)
//			break
//		case "RsComp":
//			RsCompensateAll(str2num(whichCells[1]),method)
//			break
//		case "Redo1Amp":
//			Redo1Amp(str2num(whichCells[1]))
//			break
//		case "Rid":
//			Rid(offset,whichCells)
//			break
//		default:
//			Print "Default case executed [AnalysisProc()]"
//	endswitch
//End

Function Redo1Amp(channel)
	Variable channel
	NVar sweep_num=root:reanalysis:wave_number
	string appendString=""
	Wave series_res=root:cellL2:series_res
	Wave amplL2=root:cellL2:ampl
	Wave amplR1=root:cellR1:ampl
	NVar ampl_zero_R1=root:cellR1:ampl_1_zero
	NVar ampl_zero_L2=root:cellL2:ampl_1_zero
	Variable cursorX1=hcsr(A,"reanalysis_window")
	Variable cursorX2=hcsr(B,"reanalysis_window")
	Variable n
	switch(channel)
		case 1:
			Duplicate /o $("root:cellR1:sweep"+num2str(sweep_num)+appendString), smoothed
			Smooth 15, smoothed
			Wavestats/Q/R=(cursorX1,cursorX2) smoothed
			amplR1 [(sweep_num-1)] = mean(smoothed,ampl_zero_R1,ampl_zero_R1+0.04)-V_min
			break
		case 2:
			Duplicate /o $("root:cellL2:sweep"+num2str(sweep_num)+appendString), smoothed
			Smooth 15, smoothed
			Wavestats/Q/R=(cursorX1,cursorX2) smoothed
			print V_min
			amplL2 [(sweep_num-1)] = mean(smoothed,ampl_zero_L2,ampl_zero_L2+0.04)-V_min
			break
		default:
			print "Not a valid channel"
			return 0
	endswitch
End

Function RedoAmps(whichCell,pulse,method) // Channel Number (1 or 2), Pulse number (1 or 2), Normal or Compensated or Integral or Differentiated (0 or 1 or 2 or 3)
	String whichCell
	Variable pulse
	Variable method
	Wave fitCoefs=root:fitCoefs
	string cellString, appendString
	NVar total_sweeps = root:sweep_number1 // Correct this to reflect new names of sweep counting variables
	NVar width_findPeak = root:width_findPeak
	NVar width_scanMax = root:width_scanMax
	Variable cursorX1=hcsr(A)
	Variable cursorX2=hcsr(B)
	Variable n
	
	print whichCell
	
	cellString="root:cell"+whichCell[4,5]+":sweep"
	Wave/Z ampl = $("root:cell"+whichCell[4,5]+":ampl_"+whichCell[0,1]+"_"+whichCell[4,5])//; Wave/Z ampl = $("root:cell"+whichCell[4,5]+":ampl") 
	Wave/Z ampl2 = $("root:cell"+whichCell[4,5]+":ampl2"+whichCell[0,1]+"_"+whichCell[4,5])//; Wave/Z ampl = $("root:cell"+whichCell[4,5]+":ampl2") 
	Wave series_res=$("root:cell"+whichCell[0,1]+":series_res")
	NVar ampl_zero = $("root:cell"+whichCell[0,1]+":ampl_1_zero")
	
	Display ampl
	
	switch(method)
		case 0:
			appendString=""
			break
		case 1:
			appendString="A"
			break
		case 2: 
			appendString=""
			for(n=1;n<=total_sweeps;n+=1)
				ampl2[(n-1)]=0
				Redimension/n=(total_sweeps) ampl2
				if(waveExists($(cellString+num2str(n)+appendString)) && series_res[n-1]!=0)
					ampl2 [(n-1)] = 50*TotalCharge($(cellString+num2str(n)+appendString),pulse,whichCell[0,1],whichCell[4,5])
				endif
			endfor
			return 0
			break
		case 3:
			appendString="D"
			break
		case 4:
			//print "poop"
			if(!waveExists(root:impact) || !waveExists(root:fitCoefs))
				Print "Run ImpactRs() first"
				return 0
			endif
			appendString=""
			// Compare with a simple lookup table for the impact of Rs on EPSC magnitude
			Make/o/n=1000 timeConstants
			timeConstants=fitCoefs[p][2]
			//ImpactRs()
			Wave impact=root:impact
			//Display timeConstants
			for(n=1;n<=numpnts(ampl);n+=1)
				timeConstants[n]=round(10000*timeConstants[n])
				ampl[n-1]/=impact[timeConstants[n]]
				print impact[timeConstants[n]]
			endfor
			return 0
			break
		default:
			print "Not a valid adjustment value"
			return 0
	endswitch
	
	String waveN
	waveN=cellString+num2str(n)+appendString
	
	// Analyze and save amplitude around peak near the cursor
	switch(pulse)
		case 1:
			for(n=1;n<=total_sweeps;n+=1)
				ampl[(n-1)]=0
				Redimension/n=(total_sweeps) ampl
				waveN=cellString+num2str(n)+appendString
				if(waveExists($waveN) )//&& series_res[n-1]!=0)
					print n
					//Duplicate /o $(cellString+num2str(n)+appendString), smoothed
					//Smooth 25, smoothed
					Wavestats/Q/R=(cursorX1,cursorX2) $waveN
					ampl [(n-1)] = mean($waveN,ampl_zero,ampl_zero+0.04)-V_min
				endif
			endfor
		break
		case 2:
			for(n=1;n<=total_sweeps;n+=1)
				ampl2[(n-1)]=0
				Redimension/n=(total_sweeps) ampl2
				waveN=cellString+num2str(n)+appendString
				if(waveExists($waveN) )//&& series_res[n-1]!=0)
					//Duplicate /o $(cellString+num2str(n)+appendString), smoothed
					//Smooth 25, smoothed
					Wavestats/Q/R=(cursorX1,cursorX2) $waveN
					ampl2 [(n-1)] = mean($waveN,ampl_zero,ampl_zero+0.04)-V_min
				endif
			endfor
		default:
			print "Not a valid pulse number"
			return 0
	endswitch
End

// Constructs a wave that is average of the waves from first to last, inclusive.  
Function /S MeanOfSweeps([channel,sweep_list,csr_win])
	String channel,sweep_list,csr_win // The channel, the list of sweeps, and the window where the cursors are (that have the amplitude values).  
	Variable i
	if(ParamIsDefault(sweep_list))
		sweep_list=""
		for(i=xcsr(A,csr_win)+1;i<=xcsr(B,csr_win)+1;i+=1) // For all the sweep between the cursors (inclusive)
			// +1 is there because sweep1 corresponds to point 0 in the amplitude plot
			sweep_list=sweep_list+num2str(i)+";"	// Add them to the list
		endfor
	else
		sweep_list=ListExpand(sweep_list)
	endif
	String first=StringFromList(0,sweep_list)
	String last=StringFromList(ItemsInList(sweep_list)-1,sweep_list)
	if(ParamIsDefault(channel))
		String pathway=CsrWave(A,csr_win)
		channel=StringFromList(2,pathway,"_")
	endif
	if(!cmpstr(channel,"")) // This probably means that the cursor was not on a trace whose name was of the form "x_y_z"
		DoAlert 0,"The circular cursor (A) must be on the trace for the channel you want to average."
		return ""
	endif
	String prefix="root:cell"+channel+":sweep"
	Duplicate/o $(prefix+first) $(prefix+"_mean"+"_"+first+"_"+last)
	Wave meanWave=$(prefix+"_mean"+"_"+first+"_"+last)
	meanWave=0
	String sweep; Variable no_exist=0
	for(i=0;i<ItemsInList(sweep_list);i+=1)
		sweep=StringFromList(i,sweep_list)
		Wave /Z toAdd=$(prefix+sweep)
		if(waveexists(toAdd))
			meanWave+=toAdd
		else
			no_exist+=1
		endif
	endfor
	meanWave/=(ItemsInList(sweep_list)-no_exist)
	return GetWavesDataFolder(meanWave,2)
End

// Average the sweeps corresponding to the points between the cursors (inclusive) in Ampl_Analysis
Function /S AverageWave([sweep_list,no_append,pathway,presynaptic,postsynaptic,alignment_range,post_vertical_align])
	String sweep_list
	Variable no_append
	String pathway // e.g. "R1_L2".  
	Variable presynaptic // e.g. Plot presynaptic channel as well.  
	Variable postsynaptic // e.g. Plot postsynaptic channel as well.  
	String alignment_range // What time range to average and subtract off.  
	Variable post_vertical_align // Should the postsynaptic cell traces have their grand mean subtracted off?  They will all still be aligned with one another.  
	
	// Defaults and initialization.
	presynaptic=ParamIsDefault(presynaptic) ? 0 : presynaptic
	postsynaptic=ParamIsDefault(postsynaptic) ? 1 : postsynaptic
	post_vertical_align=ParamIsDefault(post_vertical_align) ? 1 : post_vertical_align
	NVar test_pulse_start=root:parameters:test_pulse_start
	if(ParamIsDefault(alignment_range))
		alignment_range="0;"+num2str(test_pulse_start-0.001)
	endif
	Variable left=NumFromList(0,alignment_range), right=NumFromList(1,alignment_range)
	Variable i,j,baseline,post_mean,is_post,sweep_num,temp
	String first,last,pre,post,channel,channels="",csr_win="ampl_analysis",sweep_name
	String trace_name,actual_name,base_name,win_name,curr_folder=GetDataFolder(1)
	
	// Pick the sweeps and the channels.
	if(ParamIsDefault(sweep_list))
		sweep_list=""
		for(i=xcsr(A,csr_win)+1;i<=xcsr(B,csr_win)+1;i+=1) // For all the sweeps between the cursors (inclusive)
			// +1 is there because sweep1 corresponds to point 0 in the amplitude plot
			sweep_list=sweep_list+num2str(i)+";"	// Add them to the list
		endfor
	else
		sweep_list=ListExpand(sweep_list)
	endif
	first=StringFromList(0,sweep_list)
	last=StringFromList(ItemsInList(sweep_list)-1,sweep_list)
	if(ParamIsDefault(pathway))
		pathway=CsrWave(A,csr_win)
		pre=StringFromList(1,pathway,"_")
		post=StringFromList(2,pathway,"_")
	else
		pre=StringFromList(0,pathway,"_")
		post=StringFromList(1,pathway,"_")
	endif
	if(!StringMatch(pre,post))
		if(presynaptic)
			channels+=pre+";"
		endif
		if(postsynaptic)
			channels+=post+";"
		endif
	else
		channels+=post+";"
	endif
	
	// Make (or append to) a graph.
	base_name="Traces_"+pre+"_"+post
	win_name=FindGraph(base_name+"0")
	if(IsEmptyString(win_name) || no_append)
		win_name=UniqueName(base_name,6,0)
		Display /K=1 /N=$win_name
	else
		ModifyGraph /Z/W=$win_name rgb=(0,0,0) // Makes all existing traces black
	endif
	
	// For each channel (only one if only plotting the postsynaptic traces).  
	for(i=0;i<ItemsInList(channels);i+=1)
		channel=StringFromList(i,channels)
		String prefix="root:cell"+channel+":sweep"
		sweep_name=MeanOfSweeps(channel=channel,sweep_list=sweep_list,csr_win=csr_win)
		Wave /Z meanWave=$sweep_name // Get the mean of those traces.  
		if(!waveexists(meanWave))
			DoAlert 0,sweep_name+" is an invalid wave reference (probably not a valid trace)"
			return win_name
		endif
		
		// Plot all the traces.  
		Variable red,green,blue; GetChannelColor(channel,red,green,blue); 
		for(j=0;j<ItemsInList(sweep_list);j+=1)
			sweep_num=NumFromList(j,sweep_list)
			Wave /Z Trace=$(prefix+num2str(sweep_num))
			if(waveexists(Trace))
				if(i==0)
					AppendToGraph /W=$win_name /L /C=(red,green,blue) Trace
				else
					AppendToGraph /W=$win_name /R /C=(red,green,blue) Trace
				endif
			endif
		endfor
		ModifyGraph /W=$win_name lsize=0.5
		
		// Plot the mean trace.  
		if(i==0)
			AppendToGraph /W=$win_name /L /C=(red,green,blue) MeanWave
		else
			AppendToGraph /W=$win_name /R /C=(red,green,blue) MeanWave
		endif
		SetWindow $win_name userdata+=TopTrace(win=win_name)+";" // Add the name of the meanWave to the window's userdata
	endfor
	
	// Lighten the traces that aren't the mean, and figure out which one is the postsynaptic channel mean.  
	GetWindow $win_name userdata; String mean_trace,mean_traces=S_Value // Puts userdata into mean_traces (so they can be left alone)
	LightenTraces(2,win=win_name,except=mean_traces)
	String traces=TraceNameList(win_name,";",3)
	for(j=0;j<ItemsInList(mean_traces);j+=1)
		mean_trace=StringFromList(j,mean_traces) // Postsynaptic mean_trace
		Wave PostMeanWave=TraceNameToWaveRef(win_name,mean_trace)	
		channel=GetWavesDataFolder(PostMeanWave,0); channel=channel[strlen(channel)-2,strlen(channel)-1]
		if(StringMatch(channel,post)) // If this is indeed the PostMeanWave
			post_mean=mean(PostMeanWave,left,right)
			break
		endif
	endfor
	
	// Offset the traces according to their means, except for the postsynaptic traces if applicable (still align them).  
	for(i=0;i<ItemsInList(traces);i+=1)
		trace_name=StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef(win_name,trace_name)
		channel=GetWavesDataFolder(TraceWave,0); channel=channel[strlen(channel)-2,strlen(channel)-1]
		is_post=StringMatch(channel,post) ? 1 : 0
		baseline=mean(TraceWave,left,right)
		actual_name=NameOfWave(TraceNameToWaveRef(win_name,trace_name))
		if(StringMatch(actual_name,"*mean*"))
			sscanf actual_name, "sweep_mean_%d_%d", temp,sweep_num
		else
			sscanf actual_name, "sweep%d", sweep_num
		endif
		Variable stim_start=EarliestStim(sweep_num,channel_label=pre)
		//print channel,sweep_num,stim_start
		ModifyGraph /W=$win_name offset($trace_name)={-stim_start,-baseline+(is_post*post_mean*(1-post_vertical_align))}
	endfor
	
	// Clean up the graph by replotting the mean traces so that they are on top.  
	DoUpdate
	for(i=0;i<ItemsInList(mean_traces);i+=1)
		trace_name=StringFromList(i,mean_traces)
		BringToFront(trace_name,win=win_name)
		ModifyGraph /W=$win_name lsize($trace_name)=2
	endfor
	
	// Cleanup.  
	Label /W=$win_name left "pA"
	SetDataFolder curr_folder
	return win_name
End

Function PlotMovingAvg(path,left,right)
	String path
	Variable left,right
	String cell=StringFromList(1,path,"_")
	Make /o/n=1000 $("root:reanalysis:movingAvg:ampl_VC_"+path)
	Make /o/n=1000 $("root:reanalysis:movingAvg:ampl_CC_"+path)
	Wave ampl_VC=$("root:reanalysis:movingAvg:ampl_VC_"+path)
	Wave ampl_CC=$("root:reanalysis:movingAvg:ampl_CC_"+path)
	ampl_VC=0; ampl_CC=0
	Variable i
	Variable first_sweep=xcsr(A,"Ampl_Analysis")+1
	Variable last_sweep=xcsr(B,"Ampl_Analysis")+1
	Variable baseline
	for(i=first_sweep;i<=last_sweep;i+=1)
		Wave original=$("root:cell"+cell+":sweep"+num2str(i))
		Wave new=$("root:reanalysis:movingAvg:"+cell+"_"+num2str(i))
		if(numpnts(original)==2000)
			WaveStats /Q/R=(0.05,0.1) new
			baseline=V_avg
			WaveStats /Q/R=(0.14,0.19) new
			ampl_CC[i-1]=V_avg-baseline
			ampl_VC[i-1]=nan
		else
			WaveStats /Q/R=(left-(1/15),right-(1/15)) new
			baseline=V_avg
			WaveStats /Q/R=(left,right) new
			ampl_VC[i-1]=baseline-V_avg
			ampl_CC[i-1]=nan
		endif
	endfor
	DoWindow/K $("MovingAvg_"+path+"_graph")
	Display /K=1 /N=$("MovingAvg_"+path+"_graph") ampl_VC vs root:sweep_t
	AppendToGraph /R=right ampl_CC vs root:sweep_t
	ModifyGraph rgb($("ampl_CC_"+path))=(0,0,65535)
	ModifyGraph mode=2,lsize=3
End

Function UltimateAvgLayout(pre,post,baselinestart,baselineend) // Go through a bunch of plots made from Avg and get averages between cursors
	String pre,post
	Variable baselinestart,baselineend // Where in each wave to average prior to the stimulus
	//NVar cursA=root:cursA
	//NVar cursB=root:cursB
	
	DoWindow/K AvgSweeps
	DoWindow/K AvgKey
	DoWindow/K AvgLayout
	
	if(!exists("root:cursA"))
		print "Store cursor values with StoreCurs() first."
		return 0
	endif
	
	// Find the average values from each average sweep, and make a lists of the waves' names and their average values
	AvgAmplitudes(baselinestart,baselineend)
	// Recalculate all the amplitudes from individual sweeps
	NVar cursA=root:cursA
	NVar cursB=root:cursB
	Variable i,baseline
	Wave ampl=$("root:cell"+post+":ampl_"+pre+"_"+post)
	Wave ampl2=$("root:cell"+post+":ampl2_"+pre+"_"+post)
	for(i=0;i<numpnts(ampl);i+=1)
		WaveStats /Q/R=(baselinestart,baselineend) $("root:cell"+post+":sweep"+num2str(i+1))
		baseline=V_avg
		WaveStats /Q/R=(cursA,cursB) $("root:cell"+post+":sweep"+num2str(i+1))
		ampl[i]=baseline-V_min
		ampl2[i]=baseline-V_avg
	endfor
	
	// Make a window showing all the average sweeps from each epoch and where the averaging was done
	// within each sweep
	Wave /T AvgWaveList=root:reanalysis:AvgWaveList
	ColorTab2Wave BlueRedGreen
	Variable color_entry
	Display /K=1 /N=AvgSweeps
	String axis_name, curr_color
	Variable totalpoints=numpnts(AvgWaveList)
	for(i=0;i<totalpoints;i+=1)
		//axis_name=AvgWaveList(i)
		axis_name="left"
		color_entry=floor(abs(enoise(dimsize(M_colors,0))))
		Wave M_colors=$(GetDataFolder(1)+"M_colors")
		AppendToGraph /L=$axis_name $("root:reanalysis:avgwaves:"+AvgWaveList(i))
		ModifyGraph rgb($AvgWaveList(i))=(M_colors(color_entry)(0),M_colors(color_entry)(1),M_colors(color_entry)(2))
		SetDrawEnv ycoord=$axis_name, xcoord=bottom, dash=0, save
		SetAxis $axis_name -400,100
		GetAxis /Q $axis_name 
		DrawLine cursA,V_min,cursA,V_max
		DrawLine cursB,V_min,cursB,V_max
		SetDrawEnv dash=4, save
		DrawLine baselinestart,V_min,baselinestart,V_max
		DrawLine baselineend,V_min,baselineend,V_max
		//ModifyGraph axisenab($axis_name)={i/totalpoints,(i+1)/totalpoints}
	endfor
	KillWaves M_Colors
	SetAxis bottom baselinestart,cursB+0.02
	Legend
	
// Make a layout to show all this and more
	NewLayout /K=1 /N=AvgLayout
	AppendLayoutObject graph Ampl_Analysis
	AppendLayoutObject graph Membrane_Constants
	AppendLayoutObject table AvgKey
	AppendLayoutObject graph AvgSweeps
// Append the experiment log
	Notebook Experiment_Log selection={startOfFile, endOfFile}
	GetSelection notebook, Experiment_Log, 2
	TextBox/C/N=text2/F=0/A=LB/X=1/Y=35 S_selection
	DoWindow /F AvgLayout
	SetDataFolder root:reanalysis
	Textbox/N=text0/F=0/A=LB/X=5/Y=97. "\\Z16"+IgorInfo(1)
	Textbox/N=text1/F=0/A=LB/X=82/Y=97 "\\Z10\JCPrinted:\r"+date()
End

Function AvgAmplitudes(baselinestart,baselineend)
// Find the average values from each average sweep
	Variable baselinestart,baselineend
	NVar cursA=root:cursA
	NVar cursB=root:cursB
	print "ROI is "+num2str(cursA)+" to "+num2str(cursB)+" or "+num2str((cursB-cursA)/(1/60))+" wavelengths of 60 Hz"
	print "Baseline is "+num2str(baselinestart)+" to "+num2str(baselineend)+" or "+num2str((baselineend-baselinestart)/(1/60))+" wavelengths of 60 Hz"
	print "From Baseline start to ROI start is "+num2str((cursA-baselinestart)/(1/60))+" wavelengths of 60 Hz"
	SetDataFolder root:reanalysis:avgwaves
	String waves=DataFolderDir(2) // Get a list of the waves in that directory
	waves=StringFromList(0,RemoveListItem(0,waves,":")); // Clean up the list (remove the word WAVES and : and ;
	Make /o/T /n=(ItemsInList(waves,",")) root:reanalysis:AvgWaveList;  // Make a list of these waves
	Wave/T AvgWaveList=root:reanalysis:AvgWaveList
	Make /o /n=(ItemsInList(waves,",")) root:reanalysis:AvgWaveValues;  // Make a wave of their avg values
	Wave AvgWaveValues=root:reanalysis:AvgWaveValues
	Variable i,baseline
	for(i=0;i<ItemsInList(waves,",");i+=1)
		AvgWaveList[i]=StringFromList(i,waves,",")
		WaveStats /Q/R=(baselinestart,baselineend) $StringFromList(i,waves,",")
		baseline=V_avg
		WaveStats /Q/R=(cursA,cursB) $StringFromList(i,waves,",")
		AvgWaveValues[i]=baseline-V_avg	
	endfor
	Edit /N=AvgKey /K=1 root:reanalysis:AvgWaveList
	AppendToTable /W=AvgKey root:reanalysis:AvgWaveValues
End

// Takes a list of stimulation parameters and figures out the ranges where the stimulus artifacts are likely to fall
Function /S Stims2BadRanges(start,pulses,interval [,before,after])
	// Make sure that all the values (except pulses) passed to this function are in seconds.  
	Variable start,pulses,interval
	Variable before,after
	String ranges=""
	Variable i,loc
	if(ParamIsDefault(before))
		before=0.005 // The amount of time before the stimulus to include (ms)
	endif
	if(ParamIsDefault(after))
		after=0.010 // The amount of time after the stimulus to include (ms)
	endif
	for(i=0;i<pulses;i+=1)
		loc=start+i*interval
		ranges+=num2str(loc-before)+","+num2str(loc+after)+";"
	endfor
	return ranges
End

//Function PowerLawExponents()
//	String wins=WinList("PowerLaw*",";","WIN:1"),win,text,traces,mean_trace
//	Variable i,cutoff
//	Make /o/n=3 W_Coef
//	Make /o/n=(ItemsInList(wins),3) Exponents 
//	W_coef={0.1,10,0.1}
//	for(i=0;i<ItemsInList(wins);i+=1)
//		win=StringFromList(i,wins)
//		ModifyGraph /W=$win log=0, swapXY=0
//		text=StringByKey("TEXT",AnnotationInfo(win,"text0"))
//		text=StringFromList(ItemsInList(text,"_")-1,text,"_")
//		cutoff=str2num(text)
//		traces=TraceNameList(win,";",3)
//		mean_trace=ListMatch(traces,"*mean*")
//		Wave MeanWave=TraceNameToWaveRef(win,mean_trace)
//		DoWindow /F $win
//		if(numpnts(MeanWave)>5)
//			FuncFit /Q IntegratedPowerLaw W_coef  MeanWave[1,] /D 
//			print win,cutoff,W_Coef[0]
//			Exponents[i][log(cutoff/100000)/log(2)]=W_Coef[0]
//		endif
//	endfor
//End

Function CheckCompression()
	Wave /T Locs=Locs
	Variable i
	Make /o/n=(numpnts(Locs)) Compressions
	Variable length,duration
	for(i=0;i<numpnts(Locs);i+=1)
		length=ItemsInList(Locs[i])
		duration=str2num(StringFromList(length-1,Locs[i]))
		Compressions[i]=length/(10000*duration)
	endfor
	Compressions=log(Compressions)
	Histogram2(50,theWave=Compressions)
	Label bottom,"Log(Compression), e.g. -2 is 1% of original size"
	Label left,"Count"
End

Function GetImpulseResponses(channel,method,offset) // Method is 1=Time Constants or 0=Actual impulse responses; Offset is how far (in seconds) from 35 ms the test pulse starts.
	Variable channel
	Variable method
	Variable offset
	string cellFolder
	Wave/Z coefs=W_coefs
	Wave series_res=root:cellL2:series_res
	NVar kHz=root:kHz
	SetDataFolder root:
	Make/o/n=(2000,5) fitCoefs
	fitCoefs=0
	switch(channel)
		case 1:
			cellFolder="root:cellR1:"
			break
		case 2:
			cellFolder="root:cellL2:"
			break
		default:
			Print "Not a valid channel choice!"
	endswitch
	
	Variable V_fitOptions=4
	Variable n=3
	Do
		if(series_res[n-1]!=0)
			//Duplicate/o $(cellFolder+"sweep"+num2str(n-2)) waveToFit1
			//Duplicate/o $(cellFolder+"sweep"+num2str(n-1)) waveToFit2
			//Duplicate/o $(cellFolder+"sweep"+num2str(n)) waveToFit3
			Duplicate/o $(cellFolder+"sweep"+num2str(n)) waveToFit
			Duplicate/o waveToFit waveToFitA
			Duplicate/o waveToFit waveToFitB
			//Duplicate/o $(cellFolder+"sweep"+num2str(n+1)) waveToFit4
			//Duplicate/o $(cellFolder+"sweep"+num2str(n+2)) waveToFit5
			//waveToFit=((series_res[n-2]>0)*waveToFit1+([n-1]>0)*waveToFit2+(series_res[n]>0)*waveToFit3+(series_res[n+1]>0)*waveToFit4+(series_res[n+2]>0)*waveToFit5)/((series_res[n-2]>0)+(series_r[n-1]>0)+(series_res[n]>0)+(series_res[n+1]>0)+(series_res[n+2]>0))
			//FFT waveToFit
			//waveToFit[x2pnt(waveToFit,60)]=0 // Remove the 60 Hz noise
			//IFFT waveToFit
			//smooth 50,waveToFit
			//Duplicate/o /r=(0.0361,0.101) waveToFit smoothed // Take a segment long enough to represent the full decay
			//Duplicate/o /r=(0.5361,0.601) waveToFit smoothed // Take a segment long enough to represent the full decay
			//Setscale /p x, 0, 0.001/kHz, "s", smoothed
			switch(method)
				case 0: 
					Duplicate/o /r=(0.0361,0.101) waveToFit smoothed // Take a segment long enough to represent the full decay
					Setscale /p x, 0, 0.001/kHz, "s", smoothed
					//CurveFit /Q/N/W=0 dblexp, smoothed
					WaveStats/Q/R=(0.058,0.063) smoothed 
					smoothed-=V_avg // Make the impulse response function decay to zero
					smoothed=NormalizeToUnity(smoothed)
					Duplicate /o smoothed $(cellFolder+"impulse"+num2str(n))
					print n
					break
				case 1:
					DeletePoints 0,x2pnt(WaveToFitA,0.035),waveToFitA
					DeletePoints 0,x2pnt(WaveToFitB,0.135),waveToFitB
					//Setscale /p x, 0, 0.001/kHz, "s", smoothed
					//if(n==1)
					//waveToFit=waveToFitA
					waveToFit=(waveToFitA-waveToFitB)/2 //Averages the two impulse responses together
					CurveFit /Q/N/W=0 dblexp, waveToFit (0.0005,0.005)
					//else
						//CurveFit /G/Q/N/W=0 exp, smoothed
					//endif
					fitCoefs[n][0]=K0
					fitCoefs[n][1]=K1
					fitCoefs[n][2]=1/K2
					fitCoefs[n][3]=K3
					fitCoefs[n][4]=1/K4
					print n
					break
				endswitch
		endif
		n+=1
	While(waveexists($(cellFolder+"sweep"+num2str(n))))
End

Function RsCompensateAll(channel,method)
	Variable channel
	Variable method
	Wave fitCoefs=root:fitCoefs
	string cellFolder
	Wave series_res=root:cellL2:series_res
	NVar kHz=root:kHz
	switch(channel)
		case 1:
			cellFolder="root:cellR1:"
			break
		case 2:
			cellFolder="root:cellL2:"
			break
		default:
			Print "Not a valid channel choice!"
	endswitch
	
	Variable n=1
	Do
		if(series_res[n-1]!=0) // In other words, if it is not a pairing sweep
			Duplicate/o $(cellFolder+"sweep"+num2str(n)) waveToCompensate
			//FFT waveToCompensate
			//waveToCompensate[x2pnt(waveToCompensate,60)]=0 // Remove the 60 Hz noise
			//IFFT waveToCompensate
			//smooth 50,waveToCompensate
			switch(method)
				case 0:
					RsCompensateImpulse(waveToCompensate,$(cellFolder+"impulse"+num2str(n)))
					break
				case 1:
					RsCompensateTau(waveToCompensate,fitcoefs[n][2],n)
					break
				default:
					print "Not a valid method! (RsCompensateAll)"
					return 0
			endswitch
			Duplicate/o deconvoluted $(cellFolder+"sweep"+num2str(n)+"A")
		print n
		endif
		n+=1
	While(waveexists($(cellFolder+"sweep"+num2str(n))))
End

Function PairedPulseRatio(pre,post)
	String pre,post
	Wave ampl=$("root:cell"+post+":ampl_"+pre+"_"+post)
	Wave ampl2=$("root:cell"+post+":ampl2_"+pre+"_"+post)
	Duplicate /o ampl $("root:cell"+post+":PPR_"+pre+"_"+post) 
	Wave PPR=$("root:cell"+post+":PPR_"+pre+"_"+post) 
	PPR=ampl2/ampl
	Display /K=1 PPR vs root:sweep_t
	Edit /K=1 PPR; AppendToTable root:sweep_t
End

Function PutReverbChargeIntoDatabase()
	SQLConnekt("Reverb")
	String file_name=IgorInfo(1)
	String sql_str="SELECT File_Name,Baseline_Sweeps,Post_Activity_Sweeps FROM Mini_Sweeps WHERE File_Name='"+file_name+"'"
	SQLc(sql_str)
	//SQLDisconnekt()
	Wave /T Baseline_Sweeps,Post_Activity_Sweeps
	Variable first_sweep=str2num(StringFromList(1,Baseline_Sweeps[0],","))
	Variable last_sweep=str2num(StringFromList(0,Post_Activity_Sweeps[0],","))
	print first_sweep,last_sweep
	if(!numtype(first_sweep) && !numtype(last_sweep)) // If these values are both numbers.  
		Variable j,sweep
		for(j=0;j<ItemsInList(two_channels);j+=1)
			String channel=StringFromList(j,two_channels)
			Variable charge=0
			for(sweep=first_sweep;sweep<=last_sweep;sweep+=1)
				Wave /Z SweepWave=$("root:cell"+channel+":sweep"+num2str(sweep))
				if(waveexists(SweepWave))
					WaveStats /Q SweepWave
					charge+=StatsMedian(SweepWave)-V_avg
				endif
			endfor
			sql_str="INSERT INTO Activity_Summary (Experimenter, File_Name, Channel, Charge) VALUES ('RCG','"+file_name+"','"+channel+"',"+num2str(charge)+")"
			SQLc(sql_str)
		endfor
	endif
	//SQLConnekt("Reverb")
	SQLDisconnekt()
End

// Returns a list of cell names (starting with f, followed by the date) that match the criteria found in the argument
// After a ":", returns a list of indices corresponding to those cells, for use with other waves
Function /S CellList(condition,experimenter,bath_drug)
	String condition,experimenter,bath_drug
	Wave /T CellFile_Name,CellCondition,CellExperimenter,CellBath_Drug
	String list="",cell
	String /G indices=""
	Variable i
	for(i=0;i<numpnts(CellFile_Name);i+=1)
		cell=CellFile_Name[i]
		if(StringMatch(CellCondition[i],condition) && StringMatch(CellExperimenter[i],experimenter) && StringMatch(CellBath_Drug[i],bath_drug))
			list+=cell+";"
			indices+=num2str(i)+";"
		endif
	endfor
	return list
End  

Function ISIvsCumulSpikesAll(experimenter,condition,bath_drug)
	String experimenter,condition,bath_drug
	Wave CellFile_Name
	String list=CellList(condition,experimenter,bath_drug)
	Variable i; String cell
	for(i=0;i<ItemsInList(list);i+=1)
		cell=StringFromList(i,list)
		Wave spike_train=$(cell+"_PeakX")
		ISIvsCumulSpikes(spike_train)
		Condition2Color(condition); NVar red,green,blue
		ModifyGraph rgb=(red,green,blue)
	endfor
End

Function ShowAverageRegions([name,sweep_list,channels])
	String name
	String sweep_list
	String channels
	if(ParamIsDefault(channels))
		channels=two_channels
	endif
	String csr_win="Ampl_Analysis"
	if(ParamIsDefault(name))
		name="Average_Sweeps"
	endif
	if(ParamIsDefault(sweep_list))
		sweep_list=ListExpand(num2str(1+xcsr(A,csr_win))+","+num2str(1+xcsr(B,csr_win)))
	endif
	Display /K=1 /N=$CleanUpName(IgorInfo(1)+"_"+name,0)
	Variable i,j
	for(i=0;i<ItemsInList(channels);i+=1)
		String post=StringFromList(i,channels)
		Wave Sweep=$MeanOfSweeps(channel=post,sweep_list=sweep_list,csr_win=csr_win)
		Wave Rs=$("root:cell"+post+":series_res")
		Duplicate /o/R=(xcsr(A,csr_win),xcsr(B,csr_win)) Rs,RsPiece // Let's just assume that the sweep_list corresponds to the cursors.  
		Variable resistance=StatsMedian(RsPiece)
		KillWaves /Z RsPiece
		Variable red,green,blue; GetChannelColor(post,red,green,blue); 
		for(j=0;j<ItemsInList(channels);j+=1)
			String pre=StringFromList(j,channels)
			Variable stagger=0.5*(str2num(pre[1])-1)
			Duplicate /o/R=(0.295+stagger,0.500+stagger) Sweep root:$("cell"+post):$(NameOfWave(Sweep)+"_"+pre+"_"+post)
			Wave Synapse=root:$("cell"+post):$(NameOfWave(Sweep)+"_"+pre+"_"+post)
			SetScale /P x,-0.005,0.0001,Synapse
			AppendToGraph /c=(red,green,blue) Synapse
			Note synapse, "Rs="+num2str(resistance) 
		endfor
	endfor
	KillVariables /Z red,green,blue
End

Function NamedGraphs2IBWs(name)
	String name
	String desktop_dir=SpecialDirPath("Desktop",0,0,0)
	String graphs=WinList(name,";","WIN:1")
	NewPath /C/O/Q IBWs, desktop_dir+":IBWs"
	NewPath /C/O/Q TheseIBWs, desktop_dir+":IBWs:"+IgorInfo(1)
	Variable i,j
	for(i=0;i<ItemsInList(graphs);i+=1)
		String graph=StringFromList(i,graphs)
		NewPath /C/O/Q GraphIBWs, desktop_dir+":IBWs:"+IgorInfo(1)+":"+graph
		String traces=TraceNameList(graph,";",3)
		for(j=0;j<ItemsInList(traces);j+=1)
			String trace=StringFromList(j,traces)
			Wave theWave=TraceNameToWaveRef(graph,trace)
			Save /P=GraphIBWs theWave as NameOfWave(theWave)+".ibw"
		endfor
	endfor
End

// Returns the number of spontaneous network events (reverberations and isolated polysynaptic events) per second in a given recording.  
Function SpontaneousEventRate(channel,sweep_list)
	String channel,sweep_list
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
	
	WildPoint2(Segment,filter_width,0)
	StatsQuantiles /Q Segment
	Variable thresh=V_Q75-thresh_level
	FindLevels /Q Segment,thresh // Find all of the places where half of the maximum negative slope of the smoothed recording is reached.  
	Wave W_FindLevels
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
			if(in-out<down_time)
				DeletePoints i,2,W_FindLevels
			else
				DeletePoints i,1,W_FindLevels
				i+=1
			endif
		While(i<numpnts(W_FindLevels))
	While(numpnts(W_FindLevels)!=num_levels) // Iterate until the number of levels found is stable.  
	Variable num_events=numpnts(W_FindLevels)
	Variable /G threshold=thresh
	return num_events
End

Macro SaveSynapse()
	//AverageWave
End

// Parses experiment notebooks used in paired recordings to determine the identity and starting time of each neuron.  
// Writes to a text wave with one point for each entry, with each piece of information in that entry separated by |.  
// File name | Condition | R1 channel cell # | L2 channel cell # | first sweep | distance apart (percentage of field of view)
Function ParsePairNotebook(notebook_name,Entries[,file_name])
	Wave /T Entries // Overwritten with entries from the parsed notebook.  
	String notebook_name,file_name
	if(ParamIsDefault(file_name))
		file_name=IgorInfo(1)
	endif
	Redimension /n=0 Entries
	Variable DIV,sweep,R1_num=1,L2_num=1
	String exp_name,condition,channel,line,distance,dummy
	line=NotebookLine2String(notebook_name,0)
	sscanf line, "DIV: %d", DIV
	line=NotebookLine2String(notebook_name,1)
	sscanf line, "Culture Drug(s): %s", condition; condition=UpperStr(condition)
	line=NotebookLine2String(notebook_name,6)
	sscanf line, "%[^%]", distance
	if(StringMatch(distance,"*-*")) // If there is a hyphen, take the average value of the given range.  
		Variable first=str2num(StringFromList(0,distance,"-"))
		Variable last=str2num(StringFromList(1,distance,"-"))
		distance=num2str((first+last)/2)
	endif
	String entry
	sprintf entry, "%s|%s|1|1|1|%s|$%s",file_name,condition,distance,line
	Entries[]={entry}
	Variable line_num
	for(line_num=7; line_num<100; line_num+=1)
		line=NotebookLine2String(notebook_name,line_num)
		if(strlen(line)==0)
			break
		endif
		sscanf line, "New %s after %d%*[;.] %[^%]", channel,sweep,distance
		sweep+=1
		strswitch(channel)
			case "R1":
				R1_num+=1
				break
			case "L2":
				L2_num+=1
				break
		endswitch
		sprintf entry, "%s|%s|%d|%d|%d|%s|$%s",file_name,condition,R1_num,L2_num,sweep,distance,line
		Entries[numpnts(Entries)]={entry}
	endfor
End

//Order for NMDA Analysis:  
//Open a reanalysis window
//Go back to Ampl Analysis window
//First, for each epoch: 
//Cursors()
//Place cursors around area for analysis
//Run Avg(direction,name,autapse)
//Look to see which traces have problems (e.g. polysynaptic)
//Remove those traces from the graph
//Run CalcAvg() to recalculate the average
//Find good time window to do the average on the average wave
//Do CursorPlace(a,b) to put the cursors in such a good place
//Run StoreCurs() to store the cursor location
//Run MeanBetweenCursors() to get the mean value
//Repeat for other epochs being sure to use CursorPlace(a,b) or RecallCurs()
//to always put the cursors in the same place

//Loading waves from general text files into matrices:
//LoadWave /G/M "E:Documents and Settings:rick:Desktop:NMDA Rundown Study:05929000-NMDAr.atf"