
// $Author: rick $
// $Rev: 600 $
// $Date: 2012-02-07 14:47:40 -0500 (Tue, 07 Feb 2012) $

#pragma rtGlobals=1		// Use modern global access method.

//#include ":Batch Plotting"
//#include ":Batch Wave Functions"

Function AdoptAllWaves()
	string allWaves=wavelist2(folder="root:",recurse=1,fullPath=1)
	exx("Save/P=home/O ##",{allWaves})
End

// Adds sweep numbers and relative times to the notebook wherever times of day are found.  
Function NotebookSweepsAndTimes()
	Notebook LogPanel#ExperimentLog selection={startOfFile,endOfFile}
	GetSelection notebook, LogPanel#ExperimentLog,2
	Variable i
	String newNotebookStr=""
	for(i=0;i<ItemsInList(S_Selection,"\r");i+=1)
		String line=StringFromList(i,S_Selection,"\r")
		String newStr=""
		String hours,minutes,secs
		sscanf line,"%*[^@]@ %[0-9]:%[0-9?]:%[0-9?]",hours,minutes,secs
		if(str2num(hours)>=0 || str2num(minutes)>=0 || str2num(secs)>=0)
			String timeOfDay = hours+":"+minutes+":"+secs
			Variable deltaSeconds=TimeOfDay2SweepT(timeOfDay)
			Variable sweepNum=TimeOfDay2SweepNum(timeOfDay)
			if(sweepNum<0)
				String sweepTime=Secs2Time(-deltaSeconds,3)
				sprintf newStr," [-%s]",sweepTime
			else
				sweepTime=Secs2Time(deltaSeconds,3)
				sprintf newStr," [%s Sweep %d]",sweepTime,sweepNum
			endif
		endif
		newNotebookStr+=line+newStr+"\r"
	endfor
	Notebook LogPanel#ExperimentLog text=newNotebookStr
End

// Converts all 60 and 120 second sweeps into multiple 30 second sweeps and updates all other waves accordingly with duplicated points.  
Function SplitSweeps([max_duration])
	Variable max_duration
	max_duration=ParamIsDefault(max_duration) ? 30 : max_duration
	NVar last_sweep=root:status:currentSweepNum
	Variable i,j,k,total_new_sweeps=0
	
	// Establish how many new sweeps will be needed.  
	for(i=1;i<=last_sweep;i+=1)
		Variable sweep_duration=SweepDuration(i)
		total_new_sweeps+=ceil((sweep_duration-max_duration)/max_duration)
	endfor
	Variable extra_sweeps=total_new_sweeps
	wave Labels=GetChanLabels()
	variable numChannels=GetNumChannels()
	
	// Split sweeps and other waves to reflect the new maximum duration.  
	for(i=last_sweep;i>=1 && total_new_sweeps>0;i-=1)
		sweep_duration=SweepDuration(i)
		Variable new_sweeps=ceil((sweep_duration-max_duration)/max_duration)
		
		// Update the sweep times and the drug history.  
		Wave Sweep_t=GetSweepT()
		Variable old_time=Sweep_t[i-1]
		InsertPoints i,new_sweeps,Sweep_t
		Sweep_t[i-1,i-1+new_sweeps]=old_time-(max_duration/60)*((i-1+new_sweeps-p))
		dfref drugsDF=GetDrugsDF()
		Wave /t/sdfr=drugsDF DrugHistory=history
		if(numpnts(DrugHistory))
			String old_history=DrugHistory[i]
		else
			old_history=""
		endif
		InsertPoints i+1,new_sweeps,DrugHistory 
		DrugHistory[i,i+new_sweeps]=old_history
		SS_SplitAnalysis(i,max_duration,new_sweeps)
		
		for(j=0;j<numChannels;j+=1)
			String channel=Chan2Label(j)
			SS_SplitSweepParameters(channel,i,max_duration,new_sweeps) // Update sweep parameters.  
			SS_SplitSweeps(channel,i,max_duration,new_sweeps,total_new_sweeps) // Split the sweeps themselves.  
		endfor
		total_new_sweeps-=new_sweeps
	endfor
	
	last_sweep+=extra_sweeps
End

// Auxiliary function for SplitSweeps().  
Function SS_SplitSweeps(channel,index,max_duration,new_sweeps,total_new_sweeps)
	String channel
	Variable index,max_duration,new_sweeps,total_new_sweeps
	variable chan=Label2Chan(channel)
	dfref chanDF=GetChanDF(chan)
	Wave /Z Sweep=GetChanSweep(chan,index)
	if(waveexists(Sweep))
		Variable k,no_kill
		for(k=new_sweeps;k>=0;k-=1)
			Variable left=k*max_duration/dimdelta(Sweep,0)
			Variable right=(k+1)*max_duration/dimdelta(Sweep,0) 
			right-=1 // To make sure that new sweeps don't overlap at the edges.   
			string new_name=GetSweepName(index+total_new_sweeps-new_sweeps+k)
			if(StringMatch(new_name,nameofwave(Sweep))) // If we are overwriting the wave itself.  
				Redimension /n=(right) Sweep
				no_kill=1
			else
				Duplicate /o/R=[left,right] Sweep chanDF:$new_name
				no_kill=0
			endif
			SetScale /P x,0,dimdelta(Sweep,0),$new_name
		endfor
		if(!no_kill)
			KillWaves /Z Sweep
		endif
	endif
End

// Auxiliary function for SplitSweeps().  Assumes that a given stimulus doesn't cross the new sweep boundary.  
Function SS_SplitSweepParameters(channel,index,max_duration,new_sweeps)
	String channel
	Variable index,max_duration,new_sweeps
	Wave /Z SweepParams=root:$("sweep_parameters_"+channel)
	if(!waveexists(SweepParams))
		return 0
	endif
	Variable start=SweepParams[index][4]
	Variable rel_start=mod(start,max_duration*1000)
	Variable start_sweep=(start-rel_start)/(max_duration*1000)
	Duplicate /o SweepParams TempSSPWave
	InsertPoints index,new_sweeps,SweepParams
	//Variable latest=(SweepParams[index][4]+SweepParams[index][3]*SweepParams[index][2])/1000
	Variable i
	for(i=index;i<=index+new_sweeps;i+=1)
		if(i==index+start_sweep)
			SweepParams[i][]=TempSSPWave[index][q]
			SweepParams[i][4]=rel_start
		else
			SweepParams[i][]=0
			SweepParams[i][5]=TempSSPWave[index][5]
		endif
	endfor
End

// Auxiliary function for SplitSweeps().  
Function SS_SplitAnalysis(index,max_duration,new_sweeps)
	Variable index,max_duration,new_sweeps
	Variable j,k
	
	Wave /T Labels=GetChanLabels()
	variable numChannels=GetNumChannels()
	for(j=0;j<numChannels;j+=1)
		String channel_post=Labels[j]
		Wave input_res=$("root:cell"+channel_post+":input_res")
		Wave series_res=$("root:cell"+channel_post+":series_res")
		Wave timeConstant=$("root:cell"+channel_post+":timeConstant")
		Wave holding_i=$("root:cell"+channel_post+":holding_i")
		InsertPoints index+1,new_sweeps,input_res,series_res,timeConstant,holding_i
		input_res[index,index+new_sweeps]=input_res[index]
		series_res[index,index+new_sweeps]=series_res[index]
		timeConstant[index,index+new_sweeps]=timeConstant[index]
		holding_i[index,index+new_sweeps]=holding_i[index]
		
		for(k=0;k<numChannels;k+=1)
			String channel_pre=Labels[k]
			Wave /Z ampl=$("root:cell"+channel_post+":ampl_"+channel_pre+"_"+channel_post)
			Wave /Z ampl2=$("root:cell"+channel_post+":ampl2_"+channel_pre+"_"+channel_post)
			if(waveexists(ampl))
				InsertPoints index+1,new_sweeps,ampl,ampl2
				ampl[index,index+new_sweeps]=ampl[index]
				ampl2[index,index+new_sweeps]=ampl2[index]
			endif
		endfor
	endfor
End

Function SaveFilteredWaves(firstSweep,lastSweep,folder,chan)
	variable firstSweep,lastSweep,chan
	string folder
	
	variable i
	NewPath /O/C/Q SavePath, SpecialDirPath("Desktop",0,0,0)+":FilteredWaves"
	for(i=firstSweep;i<=lastSweep;i+=1)
		wave raw=GetChanSweep(chan,i)
		duplicate /free raw filtered
		ApplyFilters(filtered,chan)
		Save /O/P=SavePath filtered as "fwave"+num2str(i)+".ibw"
	endfor
End

Function DefaultColors(xx,yy)
	Variable xx,yy
	
	if((xx==0 && yy==0) || (xx==1 && yy==2) || (xx==2 && yy==1)) // Red, green, blue.  
		return 65535
	else
		return 0
	endif
End

// Attempt to fill root:sweep_parameters for each channel based on information that can be
// recovered from the sweeps themselves, the log, and the lab notebook.  
Function FillSweepParams()
	Variable i; String channel
	variable numChannels=GetNumChannels()
	for(i=0;i<numChannels;i+=1)
		Wave /Z Sweep_Params=GetChanHistory(i)
		if(waveexists(Sweep_Params))
			Sweep_Params[][4]=300+i*500
			Sweep_Params[][3]=(mod(p,2)==0) ? 50 : 150 // 50 ms for even sweeps; 150 ms for odd sweeps.  
			Sweep_Params[0][]=NaN // There is no zeroth sweep, so set this to NaN.  
		endif
	endfor
End

//Function RecalcMembraneConstants(ctrlName)
//	String ctrlName
//	Variable i,j,left=xcsr(A),right=xcsr(B)
//	String sweeps="",channel
//       for(i=left;i<=right;i+=1)
//              sweeps=sweeps+num2str(i+1)+";" // One is added because sweep1 is at index 0.
//       endfor
//       Wave /T Labels=root:parameters:Labels
//       NVar numChannels=root:parameters:numChannels
//       for(i=0;i<numChannels;i+=1)
//       	channel=Labels[i]
//       endfor
//End

//Function RedimensionAmpls()
//	Variable i,j,last_sweep=0,sweep_num
//	String channel,pre,post,sweeps
//	NVar numChannels=root:parameters:numChannels
//	Wave /T Labels=root:parameters:Labels
//	for(i=0;i<numChannels;i+=1)
//		channel=Labels[i]
//		SetDataFolder root:$("cell"+channel)
//		sweeps=WaveList("sweep*",";","")
//		for(j=0;j<ItemsInList(sweeps);j+=1)
//			sscanf StringFromList(j,sweeps), "sweep%d", sweep_num 
//			if(sweep_num>last_sweep)
//				last_sweep=sweep_num
//			endif
//		endfor
//	endfor
//	for(i=0;i<numChannels;i+=1)
//		post=Labels[i]
//		SetDataFolder root:$("cell"+post)
//		for(j=0;j<numChannels;j+=1)
//			pre=Labels[j]
//			Redimension /n=(last_sweep) $("ampl_"+pre+"_"+post)
//			Redimension /n=(last_sweep) $("ampl2_"+pre+"_"+post)
//		endfor
//	endfor
//	NVar curr_sweep=root:status:currentSweepNum
//	curr_sweep=last_sweep
//	root()
//End

Function LoadSweepParamPanel()
	string ctrlname
	if(cmpstr(WinList("SweepParamPanel",";",""),""))
		DoWindow/f SweepParamPanel
	else
		if(!exists("root:parameters:all_channels")) // In case this variable doesn't exist for some reason
			String /G root:parameters:all_channels="R1;L2"
		endif
		NewPanel /K=1 /N=SweepParamPanel /W=(1,1,171,101) as "Sweep Param Panel"
		NVar active_trace=root:parameters:active_trace
		Variable /G root:parameters:last_trace=active_trace
		SetVariable sweep,pos={1,1},fsize=24,size={150,50},title="Sweep",value=root:parameters:active_trace,proc=SweepParamPanelProc
		String channels="R1;L2"; 
		Variable i; String channel
		for(i=0;i<ItemsInList(channels);i+=1)
			channel=StringFromList(i,channels)
			NewDataFolder /o $("root:reanalysis:SweepReductions")
			Variable /G $("root:parameters:"+channel+"_cell")=0
			String /G $("root:parameters:"+channel+"_pheno")="Glut"
			Make /o/n=0 $("root:reanalysis:SweepReductions:"+channel+"Nums")=NaN
			Make /o/T/n=0 $("root:reanalysis:SweepReductions:"+channel+"Phenos")="Unknown"
			SetVariable $(channel+"Num"),pos={1,50+30*i},size={75,20},title=channel+" Cell",value=$("root:parameters:"+channel+"_cell"),limits={1,inf,1}
			PopUpMenu $(channel+"Pheno"),pos={90,48+30*i},size={75,20},title=" ",value="Glut;GABA;Unknown"
		endfor
	endif
End

Function SweepParamPanelProc(ctrlName,active_trace,str,other)
	String ctrlName; Variable active_trace; String str,other
	NVar temp=root:parameters:last_trace
	Variable last_trace=temp
	SVar active_channels=root:parameters:active_channels
	Variable i,active,even_odd
	String channel,pheno
	//NVar last_sweep_param=root:last_sweep_param
	for(i=0;i<ItemsInList(active_channels);i+=1)
		channel=StringFromList(i,active_channels)
		Wave SweepParams=$("root:sweep_parameters_"+channel)
		Wave CellNums=$("root:reanalysis:SweepReductions:"+channel+"Nums")
		Wave /T CellPhenos=$("root:reanalysis:SweepReductions:"+channel+"Phenos")
		if(dimsize(SweepParams,0)<last_trace+1)
			Redimension /n=(last_trace+1,6) SweepParams
		endif
		Redimension /n=(dimsize(SweepParams,0)) CellNums,CellPhenos
		NVar cell_num=$("root:parameters:"+channel+"_cell"); CellNums[last_trace-1]=cell_num
		ControlInfo /W=SweepParamPanel $(channel+"Pheno"); CellPhenos[last_trace-1]=S_Value
		NVar odd=$("root:StimWaves:"+channel+"_odd")
		NVar even=$("root:StimWaves:"+channel+"_even")
		even_odd=mod(last_trace,2)
		SweepParams[0][]=NaN
		SweepParams[last_trace][2,5]=NaN
		if(SweepParams[last_trace][0]==0)
			SweepParams[last_trace][0,1]=NaN
		endif
		active=(1-even_odd)*even +even_odd*odd
		//NVar width=$("root:parameters:"+channel+"_width")
		//SweepParams[last_trace+1][0]=active*width // Fill in the current sweep's parameter values
		//NVar ampl=$("root:parameters:"+channel+"_ampl")
		//SweepParams[last_trace+1][1]=active*ampl
		NVar pulses=$("root:parameters:"+channel+"_pulses")
		SweepParams[last_trace][2]=active*pulses
		NVar IPI=$("root:parameters:"+channel+"_IPI")
		SweepParams[last_trace][3]=active*IPI
		NVar begin=$("root:parameters:"+channel+"_begin")
		SweepParams[last_trace][4]=active*begin
		NVar VC=$("root:parameters:"+channel+"_VC")
		SweepParams[last_trace][5]=VC
	endfor
	//last_sweep_param=active_trace
End

//Function DrugHistory(str)
//	String str
//	Wave /T history=root:drugs:history
//	history=""
//	Variable i,j,sweep
//	String item,drug,conc
//	for(i=0;i<ItemsInList(str);i+=1)
//		item=StringFromList(i,str)
//		sweep=str2num(StringFromList(0,item,","))
//		drug=StringFromList(1,item,",")
//		conc=StringFromList(2,item,",")
//		for(j=sweep;j<=numpnts(history);j+=1)
//			history[j]=drug+","+conc
//		endfor
//	endfor
//End

Function DrugInfo2DrugWaves()
	String curr_folder=GetDataFolder(1)
	SetDataFolder root:Drugs
	Wave /T info
	Wave sweep_t=root:sweep_t
	Variable i,j,thyme,conc,sweep=0; String entry,sub_entry,new_entry,name,units
	Make /o/T/n=(numpnts(sweep_t)) history="";//",0"
	Make /o/n=(numpnts(info)+1) DrugSweeps
	for(i=0;i<numpnts(info);i+=1)
		entry=info[i]
		thyme=str2num(StringFromList(0,entry,","))
		DrugSweeps[i]=BinarySearch(sweep_t,thyme)+2
	endfor
	NVar last_sweep=root:status:currentSweepNum
	DrugSweeps[i]=last_sweep
	for(i=0;i<numpnts(info);i+=1)
		entry=info[i]
		new_entry=""
		for(j=0;j<ItemsInList(entry);j+=1)
			sub_entry=StringFromList(j,entry)
			name=StringFromList(1,sub_entry,",")
			if(StringMatch(name,"Washout"))
				new_entry=""
			else
				conc=str2num(StringFromList(2,sub_entry,","))
				units=StringFromList(3,sub_entry,",")
				conc*=Units2Num(units)
				new_entry=name+","+num2str(conc)+";"
			endif
			for(sweep=DrugSweeps[i];sweep<DrugSweeps[i+1];sweep+=1)
				history[sweep]+=new_entry // Write new_entry into all points after the time of drug addition
			endfor
		endfor	
	endfor
	SetDataFolder $curr_folder
End

// Appends BMI to the drug history wave
Function BMI()
	Wave /T Drug,Conc
	Variable i
	for(i=0;i<numpnts(Drug);i+=1)
		if(IsEmptyString(Drug[i]))
			Drug[i]+="BMI"
			Conc[i]+="5"
		else
			Drug[i]+=";BMI"
			Conc[i]+=";5"
		endif
	endfor
End

// Compensate the amplitude of the synaptic strength of pathway 'synapse' according to series resistance by 'degree', using 'Rs' as a baseline series resistance.  
Function RsCompensate(degree,[synapse,Rs])
	Variable degree // Degree is basically the negative of the slope of a plot of log(synaptic strength) vs. series resistance.  Typically about 0.005.  String synapse // e.g. "R1_L2"
	String synapse // The pathway, e.g. "R1_L2"
	Variable Rs // Target resistance to normalize to.  
	Rs=ParamIsDefault(Rs) ? 25 : Rs // Use 25 Megaohms as a baseline value of Rs
	if(ParamIsDefault(synapse))
		Wave theWave=CsrWaveRef(A,"Ampl_Analysis")
		synapse=Wave2Pathway(theWave)
	endif
	String post=StringFromList(1,synapse,"_")
	Wave ampl=$("root:cell"+post+":ampl_"+synapse)
	Wave ampl2=$("root:cell"+post+":ampl2_"+synapse)
	Wave series_res=$("root:cell"+post+":series_res")
	ampl *= exp(-degree*Rs)/exp(-degree*series_res)
	ampl2 *= exp(-degree*Rs)/exp(-degree*series_res)	
	printf "%s Rs compensated (%f).\r",synapse,degree
End

Function PhenoSet(chan,num,pheno)
	String chan
	Variable num
	String pheno
	Wave Nums=$(chan+"nums")
	Wave /T Phenos=$(chan+"phenos")
	Variable i
	for(i=0;i<numpnts(Phenos);i+=1)
		if(Nums[i]==num)
			Phenos[i]=pheno
		endif
	endfor
End

// Autofill recorded cells as cell number 1
Function Ones()
	Wave R1_Num,L2_Num
	Wave R1_Start,L2_Start
	R1_Num=R1_Start>-1
	L2_Num=L2_Start>-1
End

// Autofill cell number 1 and above as Glutamatergic
Function Glut()
	Wave R1_Num,L2_Num
	Wave /T R1_Phenotype,L2_Phenotype
	Variable i
	for(i=0;i<numpnts(R1_Num);i+=1)
		R1_Phenotype[i]=SelectString(R1_Num[i],"","Glut")
		L2_Phenotype[i]=SelectString(L2_Num[i],"","Glut")
	endfor
End

// Makes waves for the reduced versions of every sweep.  Preserves the originals.  
Function ReduceExperiment()
	Variable i,j
	DoWindow /F SweepsWin
	NVar numChannels=root:parameters:numChannels
	Wave /T Labels=root:parameters:Labels
	for(i=0;i<numChannels;i+=1)
		String channel=Labels[i]
		for(j=0;j<numChannels;j+=1)
			String chan=Labels[j]
		endfor
		SetDataFolder root:$("cell"+channel)
		String sweep_list=WaveList("sweep*",";","")
		sweep_list=RemoveFromList2("*denoised",sweep_list)
		sweep_list=SortList(sweep_list,";",16)
		Wave SweepParams=$("root:sweep_parameters_"+channel)
		NewDataFolder /O Reductions
		for(j=0;j<ItemsInList(sweep_list);j+=1)
			String sweep_name=StringFromList(j,sweep_list)
			NVar sweep_num=root:status:cursor_A_sweep_number
			sscanf sweep_name,"sweep%d", sweep_num 
			Wave Sweep=$sweep_name
			
			// Check clamp type.  
			if(SweepParams[sweep_num][5]==1) // Voltage Clamp
				Variable threshold=50
				String clamp="VC"
			elseif(SweepParams[sweep_num][5]==0) // Current Clamp
				threshold=5
				clamp="CC"
			else
				printf "Clamp for sweep %d is unknown.\r",sweep_num
				threshold=50
				clamp="VC"
			endif
			
			// Subtract off the average and store it.  Also store the point scaling of the sweep.  
			WaveStats /Q Sweep
			Sweep-=V_avg
			Variable /G :Reductions:$(sweep_name+"_avg")=V_avg
			Variable /G :Reductions:$(sweep_name+"_delta")=dimdelta(Sweep,0)
			Variable /G :Reductions:$(sweep_name+"_offset")=dimoffset(Sweep,0)
			Variable /G :Reductions:$(sweep_name+"_points")=numpnts(Sweep)	
			
			// Remove 60 Hz.  
			LineRemove(Sweep,freqs="60",width=1,harmonics=20)
			
			// Perform the DWT and overlay it.  
			
			Wave Denoised=$DWTDenoise(Sweep,threshold)
			Wave AllLocs,AllVals
			Duplicate /o AllLocs :Reductions:$(sweep_name+"_Locs")
			Duplicate /o AllVals :Reductions:$(sweep_name+"_Vals")
			AppendToGraph /T=time_axis /L=$(clamp+"_axis") /c=(0,0,0) Denoised
			SetAxis /A Time_Axis
			DoUpdate
			RemoveFromGraph $NameOfWave(Denoise)
			KillWaves /Z Denoised
			//abort
		endfor
	endfor
End

// Downsamples every sweep to 'freq' Hz.  
Function DownsampleExperiment(freq)
	Variable freq
	Variable i,j
	NVar numChannels=root:parameters:numChannels
	Wave /T Labels=root:parameters:Labels
	for(i=0;i<numChannels;i+=1)
		String channel=Labels[i]
		SetDataFolder root:$("cell"+channel)
		String sweep_list=WaveList("sweep*",";","")
		sweep_list=SortList(sweep_list,";",16)
		for(j=0;j<ItemsInList(sweep_list);j+=1)
			String sweep_name=StringFromList(j,sweep_list)
			Wave Sweep=$sweep_name
			Variable factor=round(1/(dimdelta(Sweep,0)*freq))
			DownSample(Sweep,factor,in_place=1)
		endfor
	endfor
	KillDataFolder root:stimWaves
End

// Kills all waves larger than 'size', except those matching 'except'.
Function KillBigWaves(size,[except])
	Variable size
	String except // Can have wild cards.
	if(ParamIsDefault(except))
		except=""
	endif  
	FindBigWaves(size)
	Wave /T BigWaveNames=root:FindBigWaves_f:BigWaveNames
	Wave BigWaveSizes=root:FindBigWaves_f:BigWaveSizes
	Variable i
	for(i=0;i<numpnts(BigWaveNames);i+=1)
		String wave_name=BigWaveNames[i]
		if(StringMatch(wave_name,except))
			continue
		else
			Wave /Z BigWave=$wave_name
			KillWaves /Z BigWave
		endif
	endfor
End

// Downsamples all waves larger than 'size' by 'factor', except those matching 'except'.
Function DownsampleBigWaves(size,factor[,except])
	Variable size,factor
	String except // Can have wild cards.  
	if(ParamIsDefault(except))
		except=""
	endif  
	FindBigWaves(size,noShow=1)
	Wave /T BigWaveNames=root:FindBigWaves_f:BigWaveNames
	Wave BigWaveSizes=root:FindBigWaves_f:BigWaveSizes
	Variable i
	for(i=0;i<numpnts(BigWaveNames);i+=1)
		String wave_name=BigWaveNames[i]
		if(StringMatch(wave_name,except))
			continue
		else
			Wave BigWave=$wave_name
			DownSample(BigWave,factor,in_place=1)
		endif
	endfor
End

// Deletes all of the raw sweeps.  Only to be used to on backups, in order to save memory.  
Function DeleteSweeps()
	Variable i,j
	NVar numChannels=root:parameters:numChannels
	Wave /T Labels=root:parameters:Labels
	for(i=0;i<numChannels;i+=1)
		String channel=Labels[i]
		SetDataFolder root:$("cell"+channel)
		String sweep_list=WaveList("sweep*",";","")
		//sweep_list=RemoveFromList2("*denoised",sweep_list)
		sweep_list=SortList(sweep_list,";",16)
		for(j=0;j<ItemsInList(sweep_list);j+=1)
			String sweep_name=StringFromList(j,sweep_list)
			Wave Sweep=$sweep_name
			KillWaves /Z Sweep
		endfor
	endfor
End

// Gets rid of the crap and downsamples all the sweeps.  
Function SimplifyExperiment()
	KillAll("windows")
	//BackwardsCompatibility()
	KillDataFolder /Z root:Packages
	KillDataFolder /Z root:stimWaves
	DownsampleBigWaves(9999,10)
End