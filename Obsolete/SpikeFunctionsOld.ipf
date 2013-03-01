#pragma rtGlobals=1		// Use modern global access method.

// The order so far: 
//String judys_files="ISIHW021105d_PTX;ISIHW021105e_PTX;ISIHW021205c_CTL;ISIHW021505b_CTL;ISIHW022105c_PTX;ISIHW022105e_PTX;ISIHW022105h_PTX;ISIHW022305c_CTL;ISIHW022305d_CTL;ISIHW022305e_59_CTL;ISIHW022305f_CTL;ISIHW022305g_CTL;ISIHW022405a_61_CTL;ISIHW022405b_CTL;ISIHW022505b_PTX;ISIHW022505c_PTX;ISIHW022505d_PTX;ISIHW022505e_PTX;ISIHW022805c_PTX;ISIHW022805d_PTX"
//PerformFunctionOnThese("LoadJudyData",judys_files,"","","")
//PerformFunctionOnThese("MakeBurstMatrix",judys_files,"0,1,","","_isi") // Make the 1 a zero if you want to do the other method
//CountExperiments(judys_files)
//PlotAllBurstCounts(judys_files)
//TTestPlot(CTLBurstMatrix,PTXBurstMatrix)

Function PerformFunctionOnThese(function_name,list,args_before,args_after,to_append)
	String function_name
	String list // Semicolon separated list of things to perform the function on
	String args_before,args_after // Other arguments for the function you want to call, must include preceding and following commas
	String to_append // Something to append to each thing in the list
	Variable i=0
	String thing
	Do
		thing=StringFromList(i,list,";")+to_append
		Execute(function_name+"("+args_before+"\""+thing+"\""+args_after+")")
		i+=1
	While(cmpstr("",StringFromList(i,list,";")))
End

Function LoadJudyData(file_name)
	String file_name
	LoadWave /A=poop /G "C:\Documents and Settings\Rick\Desktop\Spike Data\Judy's Data\\"+file_name+".dat"
	Rename poop0 $(file_name+"_increase")
	Rename poop1 $(file_name+"_peak")
	Rename poop2 $(file_name+"_trough")
	//Rename poop3 $(file_name+"_threshold)
	Rename poop4 $(file_name+"_threshold")
	Rename poop5 $(file_name+"_height")
	Rename poop6 $(file_name+"_halfwidth")
	Rename poop7 $(file_name+"_isi")
	Wave isi=$(file_name+"_isi")
	isi[0]=NaN
End

// Produces a matrix where columns are time bin sizes, columns are spike counts, and entries are number of instances of each combination.  
// Note: isi_wave should give isi's in seconds.  
Function MakeBurstMatrix(step,reset,isi_wave_name) 
	Variable step // What is the step size (in ms) for this matrix?
	Variable reset // Determines how you count subsequent spikes if previous spikes are already part of a burst.  
	String isi_wave_name // The name of the wave of isi values
	Wave isi_wave=$isi_wave_name
	Variable max_binsize=500 // Maximum bin size in ms.  
	Variable max_spikecount=10 // Maximum spike count per bin
	String file_name=RemoveFromList("isi",isi_wave_name,"_")
	Make /o/n=(max_binsize+1,max_spikecount+1) $(file_name+"BurstMatrix")
	Wave BurstMatrix=$(file_name+"BurstMatrix")
	BurstMatrix=0 // Force all entries to not exist (for now)
	Variable i=0,spike_count=0,bin=0
	Variable count=0 // The current count for that combination
	Variable isi_sum=0 // The sum of the last n isi's
	Variable n=0
	//KillWaves isi_waves
	Make /o/n=(numpnts(isi_wave),max_spikecount+1) isi_waves // A wave of cumulative isi's over the last n spikes
	isi_waves=NaN;isi_waves[][1]=isi_wave[x]*1000 // Converts seconds to milliseconds
	for(spike_count=2;spike_count<=max_spikecount;spike_count+=1)
		isi_waves[][spike_count]=isi_waves[x][spike_count-1]+isi_waves[x+spike_count-1][1] // Fill in the cumulative isi's
		for(i=1;i<spike_count;i+=1)
			isi_waves[numpnts(isi_wave)-i][spike_count]=NaN // Get rid of all the nonsensical entries at the end of each column
		endfor
	endfor
	
	Variable bin_size=0
	for(spike_count=2;spike_count<=max_spikecount;spike_count+=1)
		for(bin_size=1;bin_size<=max_binsize;bin_size+=1)
			bin=0
			Do 
				if(isi_waves[bin][spike_count-1]<bin_size)
					BurstMatrix[bin_size][spike_count]+=1 // Add one to the count for that combination
					if(reset)
						bin+=(spike_count-1) // Skip ahead to avoid counting a burst more than once
					endif
				endif
				bin+=1
			While(bin<dimsize(isi_waves,0))
		endfor
	endfor
End

Function PlotAllBurstCounts(list)
	String list // List of all experiment names
	CountExperiments(list)
	NVar num_experiments=root:num_experiments; NVar num_ctl=root:num_ctl; NVar num_ptx=root:num_ptx
	String file_name
	Variable i=0
	file_name=StringFromList(0,list)
	Wave BurstMatrix=$(file_name+"_BurstMatrix")
	Make /o/n=(dimsize(BurstMatrix,0),dimsize(BurstMatrix,1),num_ctl) CTLBurstMatrix
	Make /o/n=(dimsize(BurstMatrix,0),dimsize(BurstMatrix,1),num_ptx) PTXBurstMatrix
	Wave ctl_indices=root:ctl_indices
	Wave ptx_indices=root:ptx_indices
	for(i=0;i<num_ctl;i+=1)
		file_name=StringFromList(ctl_indices[i],list)
		Wave BurstMatrix=$(file_name+"_BurstMatrix")
		//print dimsize(BurstMatrix,0)
		CTLBurstMatrix[][][i]=BurstMatrix[p][q]
	endfor
	for(i=0;i<num_ptx;i+=1)
		file_name=StringFromList(ptx_indices[i],list)
		Wave BurstMatrix=$(file_name+"_BurstMatrix")
		PTXBurstMatrix[][][i]=BurstMatrix[p][q]
	endfor
	
End

// Loads all IBWs in the IBW directory and extracts spike information
Function IBWs2Spikes([path,from_last_success])
	String path
	Variable from_last_success
	root()
	if(ParamIsDefault(path))
		path=spontaneous_ibw_dir
	endif
	if(!from_last_success)
		String /G root:waves_treated=""
	endif
	path=Windows2IgorPath(path)
	NewPath /O/Q IBWPath path
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,folder,wave_name
	SVar waves_treated=root:waves_treated
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0 && WhichListItem(FileName[i],waves_treated)<=0)
			IBW2Spikes(ibw,no_kill=1)
			waves_treated+=FileName[i]+";"
		endif
	endfor
	waves_treated=""
	KillDataFolder /Z root:Spikes
	root()
End

// Extracts spike information from one IBW file
Function IBW2Spikes(ibw[,no_kill])
	String ibw
	Variable no_kill // Don't kill left over waves made by Spikes()
	PathInfo IBWPath
	if(!V_flag)
		String path=spontaneous_ibw_dir
		path=Windows2IgorPath(path)
		NewPath /O/Q IBWPath path
	endif
	LoadWave /N=SpikesWave/O/P=IBWPath ibw
	String loaded_name=StringFromList(0,S_Wavenames)
	String name=ibw[0,strlen(ibw)-5] // Remove ".ibw"
	if(!StringMatch(loaded_name,name))
		KillWaves /Z $name
		Rename $loaded_name $name
	endif
	Wave theWave=$name
	Spikes(theWave=theWave,start=leftx(theWave),finish=rightx(theWave),no_kill=1)
	DuplicateFolderContents("root:Spikes","root:Cells:"+name,except="SmoothWave;DiffWave")
	KillWaves theWave
End

Function CountExperiments(list)
	String list
	Variable i=0;
	Variable /G num_ctl=0
	Variable /G num_ptx=0
	Variable /G num_experiments=0
	Make /o/n=(num_ctl) ctl_indices
	Make /o/n=(num_ptx) ptx_indices
	String entry
	for(i=0;i<ItemsInList(list);i+=1)
		entry=StringFromList(i,list)
		if(FindListItem("CTL",entry,"_")>=1)
			num_ctl+=1
			Redimension /n=(num_ctl) ctl_indices
			ctl_indices[num_ctl-1]=i
		elseif(FindListItem("PTX",entry,"_")>=1)
			num_ptx+=1
			Redimension /n=(num_ptx) ptx_indices
			ptx_indices[num_ptx-1]=i
		else
			Print "Experiment "+entry+" not labeled as ctl or ptx."
		endif
		num_experiments+=1
	endfor
	Make /o/n=(num_ctl) ctl_indices
	Make /o/n=(num_ptx) ptx_indices
End

Function TTestPlot(matrix1,matrix2) // Finds t and p values for Zx1x1 sections of one matrix against the other
								// and returns an XxY matrix of those values as complex numbers.  
	Wave matrix1,matrix2
	if(dimsize(matrix1,0)!=dimsize(matrix2,0) || dimsize(matrix1,1)!=dimsize(matrix2,1))
		print "Matrices must have equal numbers of rows and columns"
	endif
	Make /c/o/n=(dimsize(matrix1,0),dimsize(matrix1,1)) TandPmatrix // A complex matrix of t and p values
	TandPmatrix=NaN
	Variable i,j
	Make/o/n=(dimsize(matrix1,2)) matrix1segment
	Make/o/n=(dimsize(matrix2,2)) matrix2segment
	for(i=0;i<dimsize(matrix1,0);i+=1)
		for(j=0;j<dimsize(matrix1,1);j+=1)
			matrix1segment=matrix1[i][j][p]
			matrix2segment=matrix2[i][j][p]
			TandPmatrix[i][j]=StatTTest(1,matrix1segment,matrix2segment)
		endfor
	endfor
	KillWaves matrix1segment,matrix2segment
	Make /o/n=(dimsize(matrix1,0),dimsize(matrix1,1)) Tmatrix
	Make /o/n=(dimsize(matrix1,0),dimsize(matrix1,1)) Pmatrix
	Tmatrix=real(TandPmatrix)
	Pmatrix=imag(TandPmatrix)
End

Function BootStrapKS(num_experiments,parameter,exp_list,ctl_indices,nonctl_indices)
	 // To see if two samples of cumulative distribution functions differ
	Variable num_experiments // Should usually be the sum of these two
	String parameter // The parameter that you want to look at, e.g. ISI in the waves 092205A_ISI
	String exp_list // A string with a semicolon separated list of experiments
	Wave ctl_indices
	Wave nonctl_indices
	Variable num_ctl=numpnts(ctl_indices) // Number in the control condition
	Variable num_nonctl=numpnts(nonctl_indices) // Number in the non-control condition
	Variable quantiles=100
	Variable bootstrap_samples=500
	KillDataFolder root:bootstrap
	NewDataFolder /o root:bootstrap
	//Make /o/n=0 greenAmpls, nonGreenAmpls
	SetDataFolder root:bootstrap
	Make /o/n=(bootstrap_samples) KSStats
	SetScale /I x, 0, 1, KSStats
	KSStats=0;
	if(num_experiments!=ItemsInList(exp_list))
		Print "You said there are "+num2str(num_experiments)+" but there are "+num2str(ItemsInList(exp_list))+ " experiments listed!"
		return 0
	endif
	Variable j;
	//Make /o/n=0 greenAmpls, nonGreenAmpls
	Make /o/n=(quantiles) ctl_mean, ctl_SEM, nonctl_mean, nonctl_SEM
	Variable ctl_level=0,nonctl_level=0,flag=0,KSSoFar=0
	//SetDataFolder root:
	//Make /o/n=(100,1) greenMat; greenMat=0
	//Make /o/n=(100,1) nongreenMat; nongreenMat=0
	for(j=0;j<bootstrap_samples;j+=1)
		//Wave greenness=root:greenness
		Make /o/n=(quantiles,num_ctl) ctl_samples; //Wave ctl_samples=root:bootstrap:ctl_samples
		Make /o/n=(quantiles,num_nonctl) nonctl_samples; //Wave nonctl_samples=root:bootstrap:nonctl_samples
		//SetScale /I x, 0, 1, ctl_samples,nonctl_samples
		//greenAmpls=0; nonGreenAmpls=0
		//greenMean=0; nongreenMean=0; greenMat=0; nongreenMat=0
		//Display /K=1
		Variable n,rando
		for(n=0;n<num_ctl;n+=1)
			rando=floor(abs(enoise(num_ctl))) // Pick a random experiment
			Duplicate /O/R=()(2,2) $("root:"+StringFromList(rando,exp_list)+"_"+parameter) $("ctl_"+num2str(n))
			if(!cmpstr("ISI",parameter))
				DeletePoints 0,1,$("ctl_"+num2str(n))
			endif
			Wave ctl_values=$("root:bootstrap:ctl_"+num2str(n))
			Sort ctl_values,ctl_values
			SetScale /I x, 0, 1, ctl_values
			//AppendToGraph /c=(0,65535,0) ctl_values
			ctl_samples[,][n]=ctl_values(x/quantiles)	
		endfor
		//print num_nonctl
		for(n=0;n<num_nonctl;n+=1)
			rando=floor(abs(enoise(num_nonctl))) // Pick a random experiment
			Duplicate /O/R=()(2,2) $("root:"+StringFromList(rando,exp_list)+"_"+parameter) $("nonctl_"+num2str(n))
			if(!cmpstr("ISI",parameter))
				DeletePoints 0,1,$("nonctl_"+num2str(n))
			endif
			Wave nonctl_values=$("root:bootstrap:nonctl_"+num2str(n))
			Sort nonctl_values,nonctl_values
			SetScale /I x, 0, 1, nonctl_values
			//AppendToGraph /c=(0,65535,0) nonctl_values
			nonctl_samples[,][n]=nonctl_values(x/quantiles)	
		endfor
		//ModifyGraph swapXY=1
		Variable i
		//SetDataFolder root:bootstrap
		for(i=0;i<=quantiles;i+=1)
			Duplicate /O/R=[i,i][] ctl_samples ctl_quantile
			WaveStats/Q ctl_quantile
			ctl_mean[i]=V_Avg
			//ctl_SEM[i]=V_sdev/sqrt(V_npnts)
			Duplicate /O/R=[i,i][] nonctl_samples nonctl_quantile
			WaveStats/Q nonctl_quantile
			nonctl_mean[i]=V_Avg
			//nonctlSEM[i]=V_sdev/sqrt(V_npnts)
		endfor
		KillWaves ctl_quantile, nonctl_quantile
		SetScale /I x, 0, 1, ctl_mean, nonctl_mean//, greenSEM, nongreenSEM
		//Display /K=1
		//AppendToGraph greenMean
		//AppendToGraph nongreenMean
		//ModifyGraph swapXY=1
		//ModifyGraph rgb(greenMean)=(0,65535,0), lsize(greenMean)=3
		//ModifyGraph rgb(nongreenMean)=(0,0,0), lsize(nongreenMean)=3
		//ErrorBars /T=0 greenMean,Y wave=(greenSEM,greenSEM)
		//ErrorBars /T=0 nongreenMean,Y wave=(nongreenSEM,nongreenSEM)
		//print num_green, num_nongreen	
		KSsoFar=0
		for(i=0;i<60;i+=0.005)	// Max should be the maximum possible value of the parameter, 
							// and the increment should be the fineness you want to be able to discriminate in the parameter
			ctl_level=0; nonctl_level=0; flag=0;		
			FindLevel /Q ctl_mean,i
			if(V_flag==0)
				ctl_level=V_LevelX
				flag+=1;
			endif
			FindLevel /Q nonctl_mean,i
			if(V_flag==0)
				nonctl_level=V_LevelX
				flag+=1;
			endif
			if(flag==2)
				//print ctl_level-nonctl_level
				KSSofar=max(KSsofar,abs(ctl_level-nonctl_level))
			endif
			
			//print flag
		endfor
		//print KSSofar
		//print "KS Stat is "+num2str(KSSofar/100)
		KSStats[j]=KSSofar
		print j
		DoUpdate
	endfor	
	
	//Now do the actual data
	Make /o/n=(quantiles,num_ctl) ctl_samples; //Wave ctl_samples=root:bootstrap:ctl_samples
	Make /o/n=(quantiles,num_nonctl) nonctl_samples; //Wave nonctl_samples=root:bootstrap:nonctl_samples
	for(n=0;n<num_ctl;n+=1)
		Duplicate /O/R=()(2,2) $("root:"+StringFromList(ctl_indices[n],exp_list)+"_"+parameter) $("real_ctl_"+num2str(n))
		if(!cmpstr("ISI",parameter))
			DeletePoints 0,1,$("real_ctl_"+num2str(n))
		endif
		Wave ctl_values=$("root:bootstrap:real_ctl_"+num2str(n))
		Sort ctl_values,ctl_values
		SetScale /I x, 0, 1, ctl_values
		//AppendToGraph /c=(0,65535,0) ctl_values
		ctl_samples[,][n]=ctl_values(x/quantiles)	
	endfor
	for(n=0;n<num_nonctl;n+=1)
		Duplicate /O/R=()(2,2) $("root:"+StringFromList(nonctl_indices[n],exp_list)+"_"+parameter) $("real_nonctl_"+num2str(n))
		if(!cmpstr("ISI",parameter))
			DeletePoints 0,1,$("real_nonctl_"+num2str(n))
		endif
		Wave nonctl_values=$("root:bootstrap:real_nonctl_"+num2str(n))
		Sort nonctl_values,nonctl_values
		SetScale /I x, 0, 1, nonctl_values
		//AppendToGraph /c=(0,65535,0) nonctl_values
		nonctl_samples[,][n]=nonctl_values(x/quantiles)	
	endfor
	for(i=0;i<=quantiles;i+=1)
		Duplicate /O/R=[i,i][] ctl_samples ctl_quantile
		WaveStats/Q ctl_quantile
		ctl_mean[i]=V_Avg
		//ctl_SEM[i]=V_sdev/sqrt(V_npnts)
		Duplicate /O/R=[i,i][] nonctl_samples nonctl_quantile
		WaveStats/Q nonctl_quantile
		nonctl_mean[i]=V_Avg
		//nonctlSEM[i]=V_sdev/sqrt(V_npnts)
	endfor
	KSsoFar=0
	for(i=0;i<60;i+=0.005)	// Max should be the maximum possible value of the parameter, 
						// and the increment should be the fineness you want to be able to discriminate in the parameter
		ctl_level=0; nonctl_level=0; flag=0;		
		FindLevel /Q ctl_mean,i
		if(V_flag==0)
			ctl_level=V_LevelX
			flag+=1;
		endif
		FindLevel /Q nonctl_mean,i
		if(V_flag==0)
			nonctl_level=V_LevelX
			flag+=1;
		endif
		if(flag==2)
			//print ctl_level-nonctl_level
			KSSofar=max(KSsofar,abs(ctl_level-nonctl_level))
		endif	
		//print flag
	endfor
	print KSSofar
	//print "KS Stat is "+num2str(KSSofar/100)
	Sort KSStats,KSStats
	Display /K=1 KSStats
End 

Function PlotShifted(exp_number,exp_list,parameter1,parameter2,offset)
	Variable exp_number
	String exp_list
	String parameter1
	String parameter2
	Variable offset // The number of events to look ahead or behind
	//exp_list="root:"+exp_list
	NewDataFolder/O root:plots
	SetDataFolder root:plots
	print (StringFromList(exp_number,exp_list)+"_"+parameter1)
	print (StringFromList(exp_number,exp_list)+"_"+parameter2)
	Duplicate /o $("root:"+StringFromList(exp_number,exp_list)+"_"+parameter1) yaxis
	Duplicate /o $("root:"+StringFromList(exp_number,exp_list)+"_"+parameter2) xaxis
	if(offset>0)
		DeletePoints 0,abs(offset),yaxis
	elseif(offset<0)
		DeletePoints 0,abs(offset),xaxis
	else
	endif
	Display /K=1 yaxis vs xaxis
	ModifyGraph mode=2,lsize=5
	SetAxis bottom 0,0.1 
	SetDataFolder root:
End

// Find spikes and store information about those spikes.  Only scans the region between the cursors (must have cursors on the trace).  
Function Spikes([theWave,start,finish,cross_val,refract,thresh_fraction,folder,no_kill])
	Wave theWave
	Variable start,finish,cross_val,refract,thresh_fraction
	String folder
	Variable no_kill // Don't kill waves made in this function, since it is part of a loop, and we don't want to fragment memory.  
	if(ParamIsDefault(theWave))
		Wave theWave=CsrWaveRef(A)
	endif
	if(ParamIsDefault(folder))
		folder="root:Spikes"
	endif
	start=ParamIsDefault(start) ? xcsr(A) : start
	finish=ParamIsDefault(finish) ? xcsr(B) : finish
	cross_val=ParamIsDefault(cross_val) ? -10 : cross_val // The action potential must reach this level to be counted
	refract=ParamIsDefault(refract) ? 0.01 : refract // It is expected that two action potentials cannot occur within this number of seconds
	thresh_fraction=ParamIsDefault(thresh_fraction) ? 0.02 : thresh_fraction // The fraction of maximum dV/dt that must be reached to be called threshold
	
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S $folder
	Duplicate /o theWave SmoothWave
	Smooth 5,SmoothWave
	String except=NameOfWave(theWave)+";SmoothWave;DiffWave"
	// Change the offset to start the wave at time zero (useful for preserving sig figs).  
	Variable offset=0//dimoffset(theWave,0)
	//start-=offset
	//finish-=offset
	//SetScale /P x,0,dimdelta(theWave,0),SmoothWave
	
	// Find the crossings of cross_val (where spikes will be counted)
	Make /o/n=0 Cross_locs
	FindLevels /D=Cross_locs /Q /M=0.001 /R=(start,finish) SmoothWave, cross_val
	Variable i=0,prev_val,next_val,cross_loc
  	Differentiate SmoothWave /D=DiffWave; Wave DiffWave
	Do // Keeps only crossings up through cross_val (spike onset times)
		cross_loc=cross_locs[i]
		if(DiffWave(cross_loc)<0) // If it is a crossing down through the cross_val
			DeletePoints i,1,cross_locs // Get rid of it
		else
			i+=1 // Otherwise, keep it and move to the next crossing
		endif
	While(i<numpnts(cross_locs))
	//KillWaves /Z DiffWave

  	// Pad Cross_Locs for searching to the left and right of the first and last spike, respectively.  
  	Variable prev_cross_loc,next_cross_loc
	InsertPoints numpnts(cross_locs), 1, cross_locs // Pad so that I can search up to the right boundary of the sweep
	InsertPoints 0, 1, cross_locs  // Pad so that I can search up to the left boundary of the sweep
	cross_locs[0]=start
	cross_locs[numpnts(cross_locs)-1]=finish
	
	Make /o/n=(numpnts(cross_locs)) Peak,Peak_locs,Trough,Trough_locs,Threshold,Threshold_locs,Width,Width_locs,ISI
 	
  	// Find the peak location and value of each spike
  	for(i=1;i<numpnts(cross_locs)-1;i+=1)
  		cross_loc=cross_locs[i]
  		
		WaveStats /Q /R=(cross_locs[i]-0.001,cross_locs[i+1]) SmoothWave
		Peak_locs[i]=V_maxloc
		Peak[i]=V_max
//  		FindLevel /Q /R=(cross_loc,cross_loc-0.01) SmoothWave, cross_val-10
//  		if(V_flag)
//  			print "No previous crossing of cross_val-10 for x="+num2str(cross_loc+offset)
//  			print "Using -10 instead"
//  			V_LevelX=cross_loc
//  		endif
//  		FindPeak /M=(cross_val) /Q /R=(V_LevelX,cross_loc+refract) SmoothWave
//  		Peak_locs[i]=V_PeakLoc
//  		Peak[i]=V_PeakVal
//  		ISI[i]=Peak_locs[i]-Peak_locs[i-1]
//  		if(IsNaN(V_PeakVal))
//  			print "No peak found for x="+num2str(cross_loc+offset)
//  			DeletePoints2(i,1,except=except)
//  			i-=1
//  		endif
  	endfor
  	
  	// Remove all spikes whose peaks have too little contrast from the background (blips from depolarization block, not spikes)
  	Variable min_before,min_after
  	i=1; Peak_locs[0]=0; Peak_locs[numpnts(Peak_locs)-1]=finish-start
  	Do // Keeps only crossings up through cross_val (spike onset times)
		WaveStats /Q /R=(Peak_locs[i-1],Peak_locs[i]) SmoothWave
		min_before=V_min
		WaveStats /Q /R=(Peak_locs[i],Peak_locs[i+1]) SmoothWave
		min_after=V_min
		if(min_before > Peak[i]-2 || min_after > Peak[i]-2) // If it is a little blip instead of a spike
			print Peak_locs[i],min_before,min_after
			DeletePoints2(i,1,except=except) // Get rid of it
		else
			i+=1 // Otherwise, keep it and move to the next crossing
		endif
	While(i<numpnts(Cross_Locs)-1)
	
	Variable num_spikes=numpnts(cross_locs)-2
  	print "Spikes Found = "+num2str(num_spikes)+" in "+num2str(finish-start)+" seconds = "+num2str(num_spikes/(finish-start))+" Hz"
  	
  	// Find the location and value of the trough after the spike and the threshold of the spike
  	//Duplicate /o theWave diffWave
  	//Smooth 5,diffWave
  	//Differentiate diffWave
  	Trough_locs[0]=start
  	for(i=1;i<numpnts(cross_locs)-1;i+=1)
  		cross_loc=cross_locs[i] // Location of the cross_val crossings
  		next_cross_loc=min(cross_locs[i+1],cross_loc+0.25) // Location of the next cross_val crossing or 250 ms, whichever comes first
  		WaveStats /Q /R=(cross_loc,next_cross_loc) SmoothWave
  		Trough_locs[i]=V_minloc
  		Trough[i]=V_min
		WaveStats /Q /R=(cross_loc-refract,cross_loc+refract) DiffWave
		FindLevel /Q/R=(Peak_locs[i],Trough_locs[i-1]) DiffWave, V_Max*thresh_fraction // Find where the first derivative reaches thresh_fraction of its maximum value
		if(diffWave[x2pntbefore(DiffWave,V_LevelX)]>DiffWave[x2pntafter(diffWave,V_LevelX)])
			FindLevel /Q/R=[PrevPoint(DiffWave,V_LevelX),NextPoint(DiffWave,Trough_locs[i-1])] DiffWave, V_Max*thresh_fraction // If the crossing was the wrong direction, you found the top of the peak.  Repeat from there to find the threshold.  
		endif
		Threshold_locs[i]=V_LevelX
		Threshold[i]=SmoothWave(V_LevelX)
		if(Threshold[i]<-70)
			print "Threshold was too low for x="+num2str(cross_loc+offset)
		endif
  	endfor
  	
  	// Find the width of the spike at half-max, and where (left side of the spike) this was measured from.  
  	Variable left // The left position of the spike half-height
  	Variable threshold_loc
  	for(i=1;i<numpnts(Cross_locs)-1;i+=1)
  		cross_loc=cross_locs[i] // Location of the cross_val crossings
  		threshold_loc=Threshold_locs[i]
  		FindLevel /Q /R=(threshold_loc,Peak_locs[i]) SmoothWave, (Peak[i]+Threshold[i])/2
  		left=V_LevelX
  		FindLevel /Q /R=(Peak_locs[i],Trough_locs[i]) SmoothWave, (Peak[i]+Threshold[i])/2
  		Width[i]=V_LevelX-left
  		Width_locs[i]=left
  		if(IsNaN(Width[i]) || IsNaN(Width_locs[i]))
  			print "Width could not be calculated at x="+num2str(cross_loc+offset)
  		endif
  	endfor
	
	
	// Remove the boundaries
  	DeletePoints numpnts(cross_locs)-1,1,Peak,Peak_locs,Threshold,Threshold_locs,Trough,Trough_locs,Width,Width_locs,Cross_locs,ISI // Remove the paddings on the right
  	DeletePoints 0,1,Peak,Peak_locs,Threshold,Threshold_locs,Trough,Trough_locs,Width,Width_locs,Cross_locs,ISI // Remove the padding on the left
	
	// Restore the original offset
  	Cross_Locs+=offset
  	Peak_Locs+=offset
  	Threshold_Locs+=offset
  	Trough_Locs+=offset
  	Width_Locs+=offset
	
	// Calculate a few new things, and store some analysis parameters.  
	ISI[0]=NaN
	for(i=1;i<numpnts(Peak_locs);i+=1)
		ISI[i]=Peak_locs[i]-Peak_locs[i-1]
	endfor
	Duplicate /O Trough,AHP
	AHP=Trough-Threshold
	Duplicate /O Peak,Height
	Height=Peak-Threshold
	Variable /G spikes_start=start+offset
	Variable /G spikes_finish=finish+offset
	String /G spikes_wave=GetWavesDataFolder(theWave,2)
	
	if(!no_kill)
		KillWaves /Z SmoothWave
		KillWaves /Z DiffWave
	endif
	SetDataFolder $curr_folder
	return num_spikes
End

Function StoreSpikes([no_reset])
	Variable no_reset // Leave as 0 to store new spike data, or set to 1 to append to existing spike data
	if(ParamIsDefault(no_reset) || no_reset==0)
		if(abs(cmpstr("",WinList("AllSpikes",";",""))))
			KillWindow AllSpikes
		endif
		if(exists("root:reanalysis:StoredSpikes"))
			KillWaves root:reanalysis:StoredSpikes
		endif
		if(exists("root:reanalysis:FileName"))
			KillWaves root:reanalysis:FileName
		endif
	endif
	if(!waveexists(root:reanalysis:StoredSpikes))
		Make /n=(0,13) root:reanalysis:StoredSpikes
	endif
	if(!waveexists(root:reanalysis:FileName))
		Make /T/n=0 root:reanalysis:FileName
	endif
	Wave StoredSpikes=root:reanalysis:StoredSpikes
	Wave /T FileName=root:reanalysis:FileName
	Variable num_events=numpnts(StoredSpikes)
	Wave peak_locs=root:reanalysis:peak_locs
	//NVar sweep_num=root:reanalysis:wave_number
	Wave sweep_t=root:sweep_t
	//Wave sweep=CsrWaveRef(A)
	//Variable duration=rightx(sweep)-leftx(sweep)
	Wave peak_locs=root:reanalysis:peak_locs; Wave peak_vals=root:reanalysis:peak_vals; 
	Wave thresh_locs=root:reanalysis:thresh_locs; Wave thresh_vals=root:reanalysis:thresh_vals
	Wave ahp_locs=root:reanalysis:ahp_locs; Wave ahp_vals=root:reanalysis:ahp_vals
	Wave width_locs=root:reanalysis:width_locs; Wave width_vals=root:reanalysis:width_vals
	Wave ISI=root:reanalysis:ISI
	Variable i
	Variable num_spikes=dimsize(StoredSpikes,0)
	//print num_spikes
	Redimension /n=(num_spikes+numpnts(peak_locs),10) StoredSpikes
	Redimension /n=(num_spikes+numpnts(peak_locs)) FileName
	
	for(i=0;i<numpnts(peak_locs);i+=1)
		FileName[num_spikes+i]=IgorInfo(1)
		//StoredSpikes[num_spikes+i][0]=RoundTo(sweep_t[sweep_num-1]*60,2) // Time of sweep (in seconds)
		//StoredSpikes[num_spikes+i][0]=duration // Duration of sweep (in seconds)
		StoredSpikes[num_spikes+i][0]=i+1
		StoredSpikes[num_spikes+i][1]=peak_locs[i]
		SetDimLabel 1,1,PeakLoc,StoredSpikes
		StoredSpikes[num_spikes+i][2]=peak_vals[i]
		SetDimLabel 1,2,PeakVal,StoredSpikes
		StoredSpikes[num_spikes+i][3]=thresh_locs[i]
		SetDimLabel 1,3,ThreshLoc,StoredSpikes
		StoredSpikes[num_spikes+i][4]=thresh_vals[i]
		SetDimLabel 1,4,ThreshVal,StoredSpikes
		StoredSpikes[num_spikes+i][5]=ahp_locs[i]
		SetDimLabel 1,5,AHPLoc,StoredSpikes
		StoredSpikes[num_spikes+i][6]=ahp_vals[i]
		SetDimLabel 1,6,AHPVal,StoredSpikes
		StoredSpikes[num_spikes+i][7]=width_locs[i]
		SetDimLabel 1,7,WidthLoc,StoredSpikes
		StoredSpikes[num_spikes+i][8]=RoundTo(width_vals[i]*1000,2)
		SetDimLabel 1,8,WidthVal,StoredSpikes
		StoredSpikes[num_spikes+i][9]=ISI[i]
		SetDimLabel 1,9,ISI,StoredSpikes
	endfor
	if(!cmpstr("",WinList("AllSpikes",";","")))
		//Edit /K=1 /N=AllSpikes root:reanalysis:FileName
		Edit /K=1 /N=AllSpikes root:reanalysis:StoredSpikes.ld
	endif
End

// Colorizes them according to ISI (red shift equals short ISI, violet shift equals long ISI)
Function PlotSpikes([align,left,right,order,min_colorval,max_colorval,cell]) // Requires running Spikes() first
	String align // Align spikes around peaks,thresholds,or ahps
	Variable left,right // The spikes will be displayed this many milliseconds to the left and right of the alignment point
	String order // Traces can be plotted in order of occurence (default), or ISI
	Variable min_colorval,max_colorval // The edge of the color spectrum will be determined by this minimum and maximum ISI
	String cell // For analyzing data in a folder other than root:reanalysis [Not implemented]
	// The circular cursor must be in the same place that it was when Spikes() was executed.  
	if(ParamIsDefault(align))
		align="peak"
	endif
	left=ParamIsDefault(left) ? 5 : left
	right=ParamIsDefault(right) ? 10 : right
	if(ParamIsDefault(order))
		order="occurence"
	endif
	Variable i,j,red,green,blue,color
	Variable scale=10000 // Number of points per second
	Variable avg_range=0.3 // Number of milliseconds to average from the left point for aligning spikes vertically
	Variable smoothing=0 // Optional smoothing of the spikes; 0 is no smoothing
	Variable num_spikes=numpnts(root:reanalysis:peak_locs)
	SVar spikes_wave=root:reanalysis:spikes_wave
	Wave Sweep=$spikes_wave
	if(StringMatch(align,"half-height"))
		Wave ThreshVals=root:reanalysis:thresh_vals
		Wave PeakVals=root:reanalysis:peak_vals
		Wave ThreshLocs=root:reanalysis:thresh_locs
		Wave PeakLocs=root:reanalysis:peak_locs
		Duplicate /o Thresh_Vals root:reanalysis:HalfHeight_Vals
		Wave Vals=root:reanalysis:HalfHeight_Vals
		Vals=(PeakVals+ThreshVals)/2
		Duplicate /o Vals root:reanalysis:HalfHeight_Locs
		Wave Locs=root:reanalysis:HalfHeight_Locs
		for(i=0;i<num_spikes;i+=1)
			FindLevel /Q/R=(ThreshLocs[i],PeakLocs[i]) Sweep,Vals[i]
			Locs[i]=V_LevelX
		endfor
	else
		Wave Locs=$("root:reanalysis:"+align+"_locs")
		Wave Vals=$("root:reanalysis:"+align+"_vals")
	endif
	Duplicate /o root:reanalysis:ISI TransformedISIs
	TransformedISIs=log(TransformedISIs); //recISIs=1/recISIs
	WaveStats /Q TransformedISIs
	min_colorval=ParamIsDefault(min_colorval) ? V_min : log(min_colorval)
	max_colorval=ParamIsDefault(max_colorval) ? V_max : log(max_colorval)
	Variable range=max_colorval-min_colorval
	
	Display /K=1 /N=$("SpikeOverlay_"+StringFromList(0,IgorInfo(1),"-"))
	String sorted_list=ListExpand("0,"+num2str(num_spikes-1)) // Make a list from 0 to num_spikes-1
	if(StringMatch(order,"ISI"))
		sorted_list=SortList2(sorted_list,NumWave2List(TransformedISIs))
	endif
	for(j=0;j<num_spikes;j+=1)
		i=NumFromList(j,sorted_list)
		Duplicate /O/R=(Locs(i)-left/1000,Locs(i)+right/1000) Sweep $("root:reanalysis:spike"+num2str(i))
		Wave Spike=$("root:reanalysis:spike"+num2str(i))
		SetScale /P x,-left/1000,1/scale,Spike
		ColorTab2Wave rainbow
		Wave M_Colors
		color=99*(TransformedISIs[i]-min_colorval)/range
		red=M_Colors[color][0]; green=M_Colors[color][1]; blue=M_Colors[color][2]
		AppendToGraph /c=(red,green,blue) spike
		if(StringMatch(align,"half-height"))
			spike-=Vals[i]
			FindLevel /Q spike,0
			ModifyGraph offset($NameOfWave(spike))={-V_LevelX,0}
		else
			WaveStats /Q/R=(-left/1000,-left/1000+avg_range/1000) Spike
			spike-=V_avg
		endif
		if(smoothing>0)
			Smooth smoothing,spike
		endif
	endfor
	
	Label left "mV"
	Label bottom "ms"
	ModifyGraph tickUnit(bottom)=1
	ModifyGraph prescaleExp(bottom)=3
	Make /o colorScalePosWave={-2,-1,0,1,2}; 
	Make /o/T colorScaleLabelWave={"10 ms","100 ms","1 s","10 s","100 s"};
	//TextBox /N=Name NameOfWave(Sweep)
	ColorScale/N=ColorKey ctab={min_colorval,max_colorval,Rainbow,0}
	ColorScale/C/N=ColorKey /A=LT/X=0/Y=0 widthPct=2,heightPct=75,ticklen=2,fsize=8
	ColorScale /C/N=ColorKey userTicks={colorScalePosWave,colorScaleLabelWave}
	KillWaves /Z TransformedISIs
End

// Colorizes them according to ISI (red shift equals short ISI, violet shift equals long ISI)
Function PlotUpStates(ibw[,align,left,right,path]) // Requires running Spikes() and UpstateLocations() first.  
	String ibw
	String align // Align up-states according to upstate onset.  [No other options implemented].  
	Variable left,right // The up-states will be displayed this many seconds to the left and right of the alignment point.  
	String path
	left=ParamIsDefault(left) ? 1 : left
	right=ParamIsDefault(right) ? 10 : right
	if(ParamIsDefault(path))
		path=spontaneous_ibw_dir
	endif
	String wave_name=LoadIBW(ibw,path=path)
	Wave theWave=$wave_name
	Wave UpstateOn,UpstateOff
	String graph_name=UniqueName(CleanUpName(wave_name,0),6,0)
	Display /K=1 /N=$graph_name
	Variable i,on,off
	for(i=0;i<numpnts(UpstateOn);i+=1)
		on=UpstateOn[i];off=UpstateOff[i]
		AppendToGraph theWave[x2pnt(theWave,on-left),x2pnt(theWave,off+right)] 
		ModifyGraph offset($TopTrace())={-on,0}
	endfor
	SetAxis bottom -left,right
	SetWindow $graph_name hook=WindowKillHook, userData="KillWave="+wave_name
	Textbox name
	Cursors()
	root()
End

Function FIData()
	NVar total_sweeps=root:current_sweep_number
	Variable i,j,pulse_start,pulse_length,pulse_amplitude; String channel
	Edit /K=1 /N=FI_Table
	String curr_folder=GetDataFolder(1)
	for(j=0;j<ItemsInList(all_channels);j+=1)
		channel=StringFromList(j,all_channels)
		SetDataFolder $("root:cell"+channel)
		Make /o/T/n=(total_sweeps+1,7) FI_Data=""
		AppendToTable FI_Data
		Variable /G FI_index=0
	endfor
	NVar test_pulse_start=root:parameters:test_pulse_start
	for(i=1;i<=total_sweeps;i+=1)
		MoveCursor("A_sweep",i,"","")
		DoUpdate
		for(j=0;j<ItemsInList(all_channels);j+=1)
			channel=StringFromList(j,all_channels)
			Wave /Z sweep=$("root:cell"+channel+":sweep"+num2str(i))
			if(waveexists(sweep))
				Wave parameters=$("root:sweep_parameters_"+channel)
				Wave /T FI_Data=$("root:cell"+channel+":FI_Data")
				pulse_start=parameters[i][4]
				pulse_length=parameters[i][0]
				pulse_amplitude=parameters[i][1]
				if(pulse_amplitude > 0 && pulse_length >= 100)
					NVar index=$("root:cell"+channel+":FI_index")
					FI_Data[index][0]=IgorInfo(1)
					FI_Data[index][1]=num2str(i)
					FI_Data[index][2]=channel
					FI_Data[index][3]=num2str(pulse_amplitude) // Amplitude of pulse
					FI_Data[index][4]=num2str(Spikes(theWave=sweep,start=pulse_start/1000,finish=(pulse_start+pulse_length)/1000)) // Number of spikes
					FI_Data[index][5]=num2str(pulse_length) // Duration of pulse
					FI_Data[index][6]=num2str(mean(sweep,0,test_pulse_start)) // Initial Membrane Potential
					index+=1
				endif
			endif
		endfor
	endfor
	Display /K=1 /N=FI_Graph
	for(j=0;j<ItemsInList(all_channels);j+=1)
		channel=StringFromList(j,all_channels)
		Channel2Color(channel); NVar red,green,blue
		SetDataFolder $("root:cell"+channel)
		KillWaves /Z FI_Spikes,FI_Current
		Wave /T FI_Data=$("root:cell"+channel+":FI_Data")
		Duplicate /o /R=[][4,4] FI_Data FI_Spikes
		TextWave2NumWave(FI_Spikes)
		Duplicate /o /R=[][3,3] FI_Data FI_Current
		TextWave2NumWave(FI_Current)
		AppendToGraph /c=(red,green,blue) $("root:cell"+channel+":FI_Spikes") vs $("root:cell"+channel+":FI_Current")
		KillVariables $("root:cell"+channel+":FI_index")
	endfor
	Label bottom "pA"
	Label left "Spikes"
	KillVariables /Z red,green,blue
	SetDataFolder $curr_folder
End

Function TextWave2NumWave(textWave)
	Wave /T textWave
	String temp_name=UniqueName("tempWave",1,1)
	String wave_folder=GetWavesDataFolder(textWave,1)
	String wave_name=NameOfWave(textWave)
	Make /o/n=(numpnts(textWave)) $(wave_folder+temp_name)
	Wave tempWave=$(wave_folder+temp_name)
	Variable i
	for(i=0;i<numpnts(tempWave);i+=1)
		tempWave[i]=str2num(textWave[i])
	endfor
	KillWaves textWave
	Rename tempWave $wave_name
End