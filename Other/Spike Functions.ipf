// $URL: svn://raptor.cnbc.cmu.edu/rick/recording-artist/Recording%20Artist/Other/Spike%20Functions.ipf $
// $Author: rick $
// $Rev: 632 $
// $Date: 2013-03-15 17:17:39 -0700 (Fri, 15 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.
#include "Stats Plot"
#include "Batch Plotting"

// The order so far: 
//String judys_files="ISIHW021105d_PTX;ISIHW021105e_PTX;ISIHW021205c_CTL;ISIHW021505b_CTL;ISIHW022105c_PTX;ISIHW022105e_PTX;ISIHW022105h_PTX;ISIHW022305c_CTL;ISIHW022305d_CTL;ISIHW022305e_59_CTL;ISIHW022305f_CTL;ISIHW022305g_CTL;ISIHW022405a_61_CTL;ISIHW022405b_CTL;ISIHW022505b_PTX;ISIHW022505c_PTX;ISIHW022505d_PTX;ISIHW022505e_PTX;ISIHW022805c_PTX;ISIHW022805d_PTX"
//PerformFunctionOnThese("LoadJudyData",judys_files,"","","")
//PerformFunctionOnThese("MakeBurstMatrix",judys_files,"0,1,","","_isi") // Make the 1 a zero if you want to do the other method
//CountExperiments(judys_files)
//PlotAllBurstCounts(judys_files)
//TTestPlot(CTLBurstMatrix,PTXBurstMatrix)

Function ShowSpikes()
	if(!WinType("SpikeWindow"))
		Display /K=1 /N=SpikeWindow
	endif
	Duplicate /o root:DAQ:input_0 SpikeWave
	Variable start=SpikeWave[0]
	SpikeWave-=start
	FilterIIR /LO=(5000*deltax(SpikeWave)) /HI=(500*deltax(SpikeWave)) SpikeWave
	FindLevels /Q /EDGE=1 SpikeWave,0.25; Wave W_FindLevels
	Variable i,delta_x=deltax(SpikeWave)
	NVar sweepNum=root:currSweep
	for(i=0;i<numpnts(W_FindLevels);i+=1)
		Variable crossLoc=W_FindLevels[i]
		Duplicate /o/R=(crossLoc-0.0005,crossLoc+0.0015) SpikeWave $("Spike_"+num2str(sweepNum)+"_"+num2str(i))
		Wave Spike=$("Spike_"+num2str(sweepNum)+"_"+num2str(i))
		SetScale /P x,-0.0005,delta_x,Spike
		AppendToGraph /W=SpikeWindow Spike
	endfor
End

Function /WAVE SpikeTriggeredAverage(signal_channel,spikes_channel[,sweeps,range,plot])
	string signal_channel,spikes_channel // Signal and Spikes data folders.  
	string sweeps // List of sweeps to search.  
	variable range // Time window +/- the spike time.  
	variable plot // Plot the result.  
	
	variable last_sweep = GetCurrSweep()
	sweeps = selectstring(!paramisdefault(sweeps),"0-"+num2str(last_sweep),sweeps)
	range = paramisdefault(range) ? 0.1 : range
	plot = paramisdefault(plot) ? 1 : plot
	dfref signalDF = root:$signal_channel
	dfref spikesDF = root:$spikes_channel
	if(!DataFolderRefStatus(spikesDF) || !DataFolderRefStatus(signalDF))
		printf "Data folder reference(s) invalid.\r"
		return $""
	endif
	
	variable i,j
	sweeps = ListExpand(sweeps)
	make /free/n=0 STM // Spike-triggered matrix.  
	newdatafolder /o root:temp
	variable num_sweeps = itemsinlist(sweeps)
	for(i=0;i<num_sweeps;i+=1)
		variable sweep_num = str2num(stringfromlist(i,sweeps))
		wave /z w_signal = GetChannelSweep(signal_channel,sweep_num)
		wave /z w_spikes = GetChannelSweep(spikes_channel,sweep_num)
		if(!waveexists(w_signal) || !waveexists(w_spikes))
			continue
		endif
		Spikes(w=w_spikes,start=leftx(w_spikes),finish=rightx(w_spikes),folder="root:temp")
		dfref temp = root:temp
		wave peak_x = temp:peak_locs
		variable x_scale = deltax(w_signal)
		for(j=0;j<numpnts(peak_x);j+=1)
			variable xx = peak_x[j]
			variable pp = x2pnt(w_signal,xx) - range/x_scale
			variable cumul_spikes = dimsize(STM,1)
			if(cumul_spikes)
				redimension /n=(-1,cumul_spikes+1) STM
			else
				make /o/n=(2*range/x_scale,1) STM
				setscale x,-range,range,STM
			endif
			STM[][cumul_spikes] = w_signal[pp+p]
			cumul_spikes += 1
		endfor
	endfor
	
	if(cumul_spikes>0)	
		matrixop /free STM2 = subtractmean(STM,1) // Subtract the mean from each column (from each spike-triggered waveform).  
		duplicate /o STM2 crap
		matrixop /o signalDF:$("STA_"+spikes_channel)=sumcols(STM2^t)^t/numcols(STM2)
		wave STA=signalDF:$("STA_"+spikes_channel)
		matrixop /o signalDF:$("STA_"+spikes_channel+"_sem")=sqrt(varcols(STM2^t)^t/numcols(STM2))
		wave STA_SEM=signalDF:$("STA_"+spikes_channel+"_sem")
		setscale x,-range,range,STA,STA_SEM
		if(plot)
			ShadedErrorBars(STA)
			ModifyGraph prescaleexp(bottom) = 3
			Label bottom "Time since spike (ms)"
			Label left "Amplitude ("+GetInputUnits(Label2Chan(signal_channel))+")"
			DoWindow /T kwTopWin "STA for "+spikes_channel+" -> "+signal_channel
		endif
	else
		print "No spikes were found."
	endif
	return STA
End


Function MakePSTH(sweepList[,modulus,remainder])
	String sweepList
	Variable modulus,remainder
	
	modulus=ParamIsDefault(modulus) ? 1 : modulus
	remainder=ParamIsDefault(remainder) ? 0 : remainder
	sweepList=ListExpand(sweepList)
	Variable i
	String prefix="root:cell0:sweep"
	Variable count=0,thyme=0,numSweeps=0
	Variable binWidth=0.05 // Bin width in seconds.  
	for(i=0;i<ItemsInList(sweepList);i+=1)
		String sweepNum=StringFromList(i,sweepList)
		Variable num=str2num(sweepNum)
		if(mod(num,modulus)!=remainder)
			continue
		endif
		String sweepName=prefix+sweepNum
		Wave Sweep=$sweepName
		Duplicate /o Sweep $"Filtered"
		Wave Filtered
		FilterIIR /HI=(500*deltax(Filtered)) Filtered
		FindLevels /Q/EDGE=1 /M=0.005 Filtered,0.5
		Wave W_FindLevels
		count+=numpnts(W_FindLevels)
		Variable sweepDuration=deltax(Filtered)*numpnts(Filtered)
		thyme+=sweepDuration
		Make /o/n=(sweepDuration/binWidth) Hist
		SetScale x,0,sweepDuration,Hist
		Histogram /B=2 W_FindLevels,Hist
		if(numSweeps==0)
			Duplicate /o Hist,MasterHist
		else
			MasterHist+=Hist
		endif
		numSweeps+=1
	endfor
	MasterHist/=numSweeps // Normalize by number of trials.  
	MasterHist/=binWidth // Convert to Hz.  
End

Function SpikePhases(sweepList,lo,hi[,modulus,remainder,restrict])
	String sweepList
	Variable lo,hi // Low and Hi pass filter cutoffs.  
	Variable modulus,remainder
	String restrict // Restrict to a given region of time in each sweep, e.g. "4,6" is 4 to 6 seconds.  
	
	modulus=ParamIsDefault(modulus) ? 1 : modulus
	remainder=ParamIsDefault(remainder) ? 0 : remainder
	if(ParamIsDefault(restrict))
		Variable start=0, finish=Inf
	else
		start=str2num(StringFromList(0,restrict,",")); finish=str2num(StringFromList(1,restrict,","))
	endif
	sweepList=ListExpand(sweepList)
	Variable i
	String prefix="root:cell0:sweep"
	Variable count=0,thyme=0,numSweeps=0
	Variable binWidth=0.05 // Bin width in seconds.  
	for(i=0;i<ItemsInList(sweepList);i+=1)
		String sweepNum=StringFromList(i,sweepList)
		Variable num=str2num(sweepNum)
		if(mod(num,modulus)!=remainder)
			continue
		endif
		String sweepName=prefix+sweepNum
		Wave Sweep=$sweepName
		
		// Get sweep phase.  
		Duplicate /o Sweep $"Filtered"
		Wave Filtered
		WaveStats /Q/M=1 Filtered; Filtered-=V_avg
		FilterIIR /LO=(lo*deltax(Filtered)) /HI=(hi*deltax(Filtered)) Filtered
		HilbertTransform /DEST=Hilbert Filtered
		Duplicate /o Filtered,Phase
		Phase=atan2(-Hilbert,Filtered)
		
		// Get spike times.  
		Duplicate /o Sweep $"Filtered"
		Wave Filtered
		WaveStats /Q/M=1 Filtered; Filtered-=V_avg
		FilterIIR /HI=(500*deltax(Filtered)) Filtered
		FindLevels /Q/EDGE=1 /R=(start,finish) /M=0.005 Filtered,0.5
		Wave W_FindLevels
		
		count+=numpnts(W_FindLevels)
		Variable sweepDuration=deltax(Filtered)*numpnts(Filtered)
		thyme+=sweepDuration
		Make /o/n=(100) Hist
		SetScale x,-pi,pi,Hist
		Duplicate /o W_FindLevels SpikePhase
		SpikePhase=Phase(W_FindLevels)
		Histogram /B=2 SpikePhase,Hist
		if(numSweeps==0)
			Duplicate /o Hist,MasterHist,MasterHistVar
			MasterHistVar*=MasterHistVar
		else
			MasterHist+=Hist
			MasterHistVar+=Hist^2
		endif
		numSweeps+=1
	endfor
	
	MasterHist/=numSweeps // Normalize by number of trials.  
	MasterHistVar/=numSweeps
	MasterHistVar-=MasterHist^2 // Convert from squares to variance.  
	MasterHistVar=sqrt(MasterHistVar)/numSweeps
	MasterHist/=binWidth // Convert to Hz. 
	MasterHistVar/=binWidth
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
	
	// Determine a path.  
	root()
	PathInfo IBWpath
	if(!ParamIsDefault(path))
		NewPath /O/Q IBWpath,path
	elseif(!strlen(S_path))
		NewPath /O/Q IBWpath
	endif
	PathInfo IBWpath
	path=S_path
	
	if(!from_last_success)
		String /G root:waves_treated=""
	endif
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,folder,wave_name
	SVar waves_treated=root:waves_treated
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0 && WhichListItem(FileName[i],waves_treated)<=0)
			IBW2Spikes(ibw,no_kill=0)
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
		String path=StrVarOrDefault("root:parameters:random:dataDir","")
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
	Wave w=$name
	Spikes(w=w,start=leftx(w),finish=rightx(w),folder="root:Spikes")
	DuplicateFolderContents("root:Spikes","root:Cells:"+name,except="SmoothWave;DiffWave")
	KillWaves w
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
			printf "Experiment %s not labeled as ctl or ptx.\r",entry
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
		printf "Matrices must have equal numbers of rows and columns.\r"
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
		printf "You said there are %d but there are %d experiments listed!\r",num_experiments,itemsinlist(exp_list)
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
				KSSofar=max(KSsofar,abs(ctl_level-nonctl_level))
			endif
			
		endfor
		KSStats[j]=KSSofar
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
			KSSofar=max(KSsofar,abs(ctl_level-nonctl_level))
		endif	
	endfor
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

function CellSpikes(cell)
    string cell
    
    dfref df=root:$cell
    if(!datafolderrefstatus(df))
        DoAlert 0,"There is no folder for cell "+cell
        return -1
    endif
    variable i,j,index=0,max_spikes=1
    string stats="Peak;Peak_locs;Threshold;Threshold_locs;Trough;Trough_locs;Width;Width_locs;ISI"
    
    // Fill matrix with spike stats.  
    for(i=0;i<CountObjectsDFR(df,1);i+=1)
        string name=GetIndexedObjNameDFR(df,1,i)
        if(grepstring(name,"sweep[0-9]+"))
        	if(stringmatch(name,"*_filt"))
			continue
		endif
            wave w=df:$name
            string folder=getdatafolder(1,df)+"Spikes_"+name
            Spikes(w=w,folder=folder)
            dfref subDF=$folder
            wave /sdfr=subDF peak
            variable num_spikes = numpnts(peak)
            max_spikes = max(num_spikes,max_spikes)
            if(index==0)
                make /o/n=(1,max_spikes,itemsinlist(stats)) df:AllSpikes /wave=AllSpikes
            endif
            Redimension /n=(index+1,max_spikes,-1) AllSpikes
            SetDimLabel 0,index,$name,AllSpikes
            for(j=0;j<itemsinlist(stats);j+=1)
                string stat=stringfromlist(j,stats)
                SetDimLabel 2,j,$stat,AllSpikes
                wave w_stat=subDF:$stat
                AllSpikes[index][][j]=nan
                AllSpikes[index][0,num_spikes-1][j]=w_stat[q]
            endfor
            index+=1
        endif
    endfor
    
    // Go back and fill extra space with NaN's.  
    index = 0
    for(i=0;i<CountObjectsDFR(df,1);i+=1)
        name=GetIndexedObjNameDFR(df,1,i)
        if(grepstring(name,"sweep[0-9]+"))
            folder=getdatafolder(1,df)+"Spikes_"+name
            dfref subDF=$folder
            wave /sdfr=subDF peak
            num_spikes = numpnts(peak)
            AllSpikes[index][num_spikes,max_spikes-1][]=nan
            index+=1
        endif
    endfor
    
    for(j=0;j<dimsize(AllSpikes,1);j+=1)
    	SetDimLabel 1,j,$("#"+num2str(j+1)),AllSpikes
    endfor
    Edit /K=1 AllSpikes.ld
end

// Find spikes and store information about those spikes.  Only scans the region between the cursors (must have cursors on the trace).  
Function Spikes([w,start,finish,cross_val,refract,thresh_fraction,minHeight,folder,keepOffset]) // FYI, variables in brackets (all of them here) are optional.  
	Wave w // Wave to analyze.  
	Variable start,finish // Start and end times (s).  
	Variable cross_val // Minimum membrane potential required to count as a spike (mV).  
	Variable refract // Minimum refractory period (s).  
	Variable thresh_fraction // The fraction of maximum dV/dt that must be reached to be called threshold.  
	variable minHeight // The smallest difference between peak and trough (before and after) that a spike must have to be retained.  
	String folder // Folder in which to put the results.  
	Variable keepOffset // If a wave is scaled to start at t=200, and the first spike is 1 second, the spike time will be reported as 201.  Otherwise, it will be reported as 1.  
	
	Variable cursors=strlen(csrinfo(A))*strlen(csrinfo(B)) // Non-zero if both cursors are on the graph, zero if either or both are absent.  
	
	// Set defaults for variables not explicitly specified when the function is called.  
	if(ParamIsDefault(w))
		if(cursors)
			Wave w=CsrWaveRef(A) // The trace on which cursor A is placed on the top graph. 
		else
			Wave w=TraceNameToWaveRef("",StringFromList(0,TraceNameList("",";",1))) // The top trace on the top graph.  
		endif
	endif
	if(ParamIsDefault(folder))
		folder="root:"+CleanUpName("Spikes_"+GetWavesDataFolder(w,0)+"_"+NameOfWave(w),0) // Default folder.  
	endif
	start=ParamIsDefault(start) ? (cursors ? xcsr(A) : dimoffset(w,0)) : start // Defaults: the location of the circular cursor (cursor A) or the left edge of the wave.  
	finish=ParamIsDefault(finish) ? (cursors ? xcsr(B) : dimoffset(w,0)+dimdelta(w,0)*dimsize(w,0)) : finish // Defaults: the location of the square cursor (cursor B) or the right edge of the wave. 
	cross_val=ParamIsDefault(cross_val) ? -10 : cross_val // -10 mV.  
	refract=ParamIsDefault(refract) ? 0.01 : refract // 0.01 s.  
	thresh_fraction=ParamIsDefault(thresh_fraction) ? 0.2 : thresh_fraction // 1/50 of the maximum value of dV/dt during each spike.  
	minHeight=paramisdefault(minHeight) ? 2 : minHeight
	Variable offset=keepOffset ? dimoffset(w,0) : 0
	
	String curr_folder=GetDataFolder(1) // Mark the current data folder so we can go back to it at the end.  
	NewDataFolder /O/S $folder // Make the folder to put the analyzed data into.  
	Duplicate /o/FREE w SmoothWave,DiffWave // Make a copy of the source wave so we can smooth the copy.  /FREE means it will automatically be killed at the end (i.e. not global).  
	Smooth 5,SmoothWave
	
	// Enforce the offset (useful for preserving sig figs).  
	start-=offset
	finish-=offset
	if(keepOffset)
		SetScale /P x,0,dimdelta(w,0),SmoothWave // Rescale the smoothed wave so that the first point is at time 0.  
	endif
	
	// Find the crossings of cross_val (where spikes will be counted)
	Make /o/FREE/n=0 Cross_locs // FREE means don't store it for later.  It will only be used in this function.  
	FindLevels /D=Cross_locs /EDGE=1 /Q /M=0.001 /R=(start,finish) SmoothWave, cross_val
  	
  	// Pad Cross_Locs for searching to the left and right of the first and last spike, respectively.  Used for finding the threshold of the first spike and the AHP of the last spike.  
	InsertPoints 0, 1, Cross_locs  // Pad so that I can search up to the left boundary of the sweep
	Cross_locs[0]=start
	Cross_locs[numpnts(cross_locs)]={finish} // Braces notation allows you to append a point to the end of the wave.  
	
	Make /o/n=(numpnts(cross_locs)) Peak,Peak_locs
 	
  	// Find the peak location and value of each spike
  	Variable i
  	for(i=1;i<numpnts(Cross_locs)-1;i+=1)  
		WaveStats /Q /R=(Cross_locs[i]-0.001,Cross_locs[i+1]) SmoothWave // Compute statistics for 1 ms from the trigger crossing all the way to the next trigger crossing.  
		Peak_locs[i]=V_maxloc // Location of the maximum.  
		Peak[i]=V_max // Value of the maximum.  
  	endfor
  	
  	// Remove all spikes whose peaks have too little contrast from the background (blips from depolarization block, not spikes)
  	Peak_locs[0]=0; Peak_locs[numpnts(Peak_locs)-1]=finish-start // Set the locations of the first peak and the last peak to the start and end time of the wave, for padding purposes.  
  	i=1
  	Do
		WaveStats /Q /R=(Peak_locs[i-1],Peak_locs[i]) SmoothWave
		Variable min_before=V_min
		WaveStats /Q /R=(Peak_locs[i],Peak_locs[i+1]) SmoothWave
		Variable min_after=V_min
		 // If this spike exceeds the minimum between the last spike and this spike or the minimum between this spike and the next spike by < 2 mV, get rid of it.  
		if(min_before > Peak[i]-minHeight || min_after > Peak[i]-minHeight)
			printf "Deleting wannabe spike @ %.3f\r",Peak_locs[i]
			DeletePoints i,1,Peak,Peak_locs,Cross_locs
		else
			i+=1 // Otherwise, keep it and move to the next crossing
		endif
	While(i<numpnts(Cross_Locs)-1)
	
	Make /o/n=(numpnts(Peak)) Trough,Trough_locs,Threshold,Threshold_locs,Width,Width_locs,ISI
	
	Variable num_spikes=numpnts(cross_locs)-2 // -2 because of the fake ones padding the start and end time.  
  	printf "Spikes Found = %d in %.2f seconds (%.2f Hz)\r",num_spikes,finish-start,num_spikes/(finish-start)
  	
  	// Find the location and value of the trough after the spike and the threshold of the spike
  	Differentiate SmoothWave /D=DiffWave // A differentiated version of the smoothed wave, used for computing thresholds.  
  	Trough_locs[0]=start
  	for(i=1;i<numpnts(cross_locs)-1;i+=1)
  		Variable cross_loc=cross_locs[i] // Location of the cross_val crossings
  		Variable next_cross_loc=min(cross_locs[i+1],cross_loc+0.25) // Location of the next cross_val crossing or 250 ms, whichever comes first (i.e. AHP trough cannot be more than 250 ms away).  
  		WaveStats /Q /R=(cross_loc,next_cross_loc) SmoothWave
  		Trough_locs[i]=V_minloc
  		Trough[i]=V_min
		WaveStats /Q /R=(cross_loc-refract,cross_loc+refract) DiffWave
		FindLevel /Q/EDGE=1/R=(Peak_locs[i],Trough_locs[i-1]) DiffWave, V_Max*thresh_fraction // Find where the first derivative reaches thresh_fraction of its maximum value, searching backwards from the spike peak to the trough of the last spike.  
		Threshold_locs[i]=V_LevelX // Set the threshold location to the result.  
		Threshold[i]=SmoothWave(V_LevelX) // Se the threshold voltage to the value at that location.  
		if(Threshold[i]<-70) // If the threshold is less than -70 mV.  
			printf "Threshold was too low for spike @ %.3f\r",cross_loc
		endif
  	endfor
  	
  	// Find the width of the spike at half-max, and where (left side of the spike) this was measured from.  
  	for(i=1;i<numpnts(Cross_locs)-1;i+=1)
  		cross_loc=cross_locs[i] // Location of the cross_val crossings.  
  		Variable threshold_loc=Threshold_locs[i] // Location of the threshold.  
  		FindLevel /Q /R=(threshold_loc,Peak_locs[i]) SmoothWave, (Peak[i]+Threshold[i])/2 // Find where between the threshold time and the peak time the spike reaches the membrane potential reached halfway between threshold and peak.  
  		Variable left=V_LevelX // The left position of the spike half-height
  		FindLevel /Q /R=(Peak_locs[i],Trough_locs[i]) SmoothWave, (Peak[i]+Threshold[i])/2 // Ditto for the other side of the spike.  
  		Width[i]=V_LevelX-left // Spike width is the difference between the two crossings of that halfway point.  
  		Width_locs[i]=left
  		if(numtype(Width[i]) || numtype(Width_locs[i])) // If either of these values are Inf or NaN.  
  			printf "Width could not be calculated @ %.3f\r",cross_loc
  		endif
  	endfor
	
	// Remove the padded boundaries
  	DeletePoints numpnts(cross_locs)-1,1,Peak,Peak_locs,Threshold,Threshold_locs,Trough,Trough_locs,Width,Width_locs,Cross_locs,ISI // Remove the paddings on the right
  	DeletePoints 0,1,Peak,Peak_locs,Threshold,Threshold_locs,Trough,Trough_locs,Width,Width_locs,Cross_locs,ISI // Remove the padding on the left
	
	// Restore the original offset (if any).  
  	Cross_Locs+=offset
  	Peak_Locs+=offset
  	Threshold_Locs+=offset
  	Trough_Locs+=offset
  	Width_Locs+=offset
	
	// Calculate a few new things, and store some analysis parameters.  
	ISI[0]=NaN // No ISI for the first spike.  
	for(i=1;i<numpnts(Peak_locs);i+=1)
		ISI[i]=Peak_locs[i]-Peak_locs[i-1] // The ISI is the difference between this spike time and the last spike time.  
	endfor
	Duplicate /O Trough,AHP
	AHP=Trough-Threshold // AHP is the difference between spike threshold and the minimum after the spike.  
	Duplicate /O Peak,Height
	Height=Peak-Threshold // Height is the difference between the highest point of the spike and the threshold.  
	Duplicate /O Width,Rise_Time,Decay_Time
      Rise_Time=Peak_Locs-Threshold_Locs // Time to rise from threshold to peak.  
      Decay_Time=Trough_Locs-Peak_Locs // Time to decay from peak to trough.  

	Variable /G spikes_start=start+offset // Store the start and end times of analysis for future reference.  
	Variable /G spikes_finish=finish+offset
	String /G spikes_wave=GetWavesDataFolder(w,2) // Store the location of the wave that was analyzed.  
	
	//edit /k=1 Peak,Peak_locs,Threshold
	SetDataFolder $curr_folder // Go back to the original folder.  
	String /G root:last_spikes_folder=folder // Mark the folder of the last analysis (for debugging purposes).  
	return num_spikes // Return the number of spikes found.  
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
	Wave SweepT=root:SweepT
	//Wave sweep=CsrWaveRef(A)
	//Variable duration=rightx(sweep)-leftx(sweep)
	Wave peak_locs=root:reanalysis:peak_locs; Wave peak_vals=root:reanalysis:peak_vals; 
	Wave thresh_locs=root:reanalysis:thresh_locs; Wave thresh_vals=root:reanalysis:thresh_vals
	Wave ahp_locs=root:reanalysis:ahp_locs; Wave ahp_vals=root:reanalysis:ahp_vals
	Wave width_locs=root:reanalysis:width_locs; Wave width_vals=root:reanalysis:width_vals
	Wave ISI=root:reanalysis:ISI
	Variable i
	Variable num_spikes=dimsize(StoredSpikes,0)
	Redimension /n=(num_spikes+numpnts(peak_locs),10) StoredSpikes
	Redimension /n=(num_spikes+numpnts(peak_locs)) FileName
	
	for(i=0;i<numpnts(peak_locs);i+=1)
		FileName[num_spikes+i]=IgorInfo(1)
		//StoredSpikes[num_spikes+i][0]=RoundTo(SweepT[sweep_num-1]*60,2) // Time of sweep (in seconds)
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
	String curr_folder=GetDataFolder(1)
	SVar folder=root:last_spikes_folder
	SetDataFolder $folder
	
	Variable i,j,red,green,blue,color
	Variable scale=10000 // Number of points per second
	Variable avg_range=0.3 // Number of milliseconds to average from the left point for aligning spikes vertically
	Variable smoothing=0 // Optional smoothing of the spikes; 0 is no smoothing
	Variable num_spikes=numpnts(Peak_locs)
	SVar spikes_wave
	Wave Sweep=$spikes_wave
	if(StringMatch(align,"half-height"))
		Wave Threshold,Peak,Threshold_locs,Peak_locs,Width_locs
		Duplicate /o Threshold HalfHeight
		Wave Vals=HalfHeight
		Vals=(Peak+Threshold)/2
		Duplicate /o Vals root:reanalysis:HalfHeight_Locs
		Wave Locs=Width_Locs
	else
		Wave Locs=$(align+"_locs")
		Wave Vals=$(align)
	endif
	
	Duplicate /o ISI TransformedISIs
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
		Duplicate /O/R=(Locs(i)-left/1000,Locs(i)+right/1000) Sweep $("Spike"+num2str(i))
		Wave Spike=$("Spike"+num2str(i))
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
			Smooth smoothing,Spike
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
	KillWaves /Z TransformedISIs,HalfHeight
	SetDataFolder $curr_folder
End

Function FIData()
	NVar total_sweeps=root:currSweep
	Variable i,j,pulse_start,pulse_length,pulse_amplitude; String channel
	Edit /K=1 /N=FI_Table
	String curr_folder=GetDataFolder(1)
	SVar allChannels=root:parameters:allChannels
	for(j=0;j<ItemsInList(allChannels);j+=1)
		channel=StringFromList(j,allChannels)
		SetDataFolder $("root:cell"+channel)
		Make /o/T/n=(total_sweeps+1,7) FI_Data=""
		AppendToTable FI_Data
		Variable /G FI_index=0
	endfor
	NVar testPulsestart=root:parameters:testPulsestart
	for(i=1;i<=total_sweeps;i+=1)
//		MoveCursor("A",i)
		DoUpdate
		for(j=0;j<ItemsInList(allChannels);j+=1)
			channel=StringFromList(j,allChannels)
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
					FI_Data[index][4]=num2str(Spikes(w=sweep,start=pulse_start/1000,finish=(pulse_start+pulse_length)/1000)) // Number of spikes
					FI_Data[index][5]=num2str(pulse_length) // Duration of pulse
					FI_Data[index][6]=num2str(mean(sweep,0,testPulsestart)) // Initial Membrane Potential
					index+=1
				endif
			endif
		endfor
	endfor
	Display /K=1 /N=FI_Graph
	for(j=0;j<ItemsInList(allChannels);j+=1)
		channel=StringFromList(j,allChannels)
		Variable red,green,blue; GetChannelColor(channel,red,green,blue)
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

Function SpikesOutputToUsable()
	root()
	Variable i; String folder
	Wave /T FileName
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			if(waveexists(AHP_Vals))
				Duplicate /o AHP_Vals $("root:"+folder+":Trough"); KillWaves AHP_Vals
			endif
			if(waveexists(Peak_Vals))
				Duplicate /o Peak_Vals $("root:"+folder+":Peak"); KillWaves Peak_Vals
			endif
			if(waveexists(Thresh_Vals))
				Duplicate /o Thresh_vals $("root:"+folder+":Threshold"); KillWaves Thresh_Vals
			endif
			if(waveexists(Thresh_locs))
				Duplicate /o Thresh_locs $("root:"+folder+":Threshold_locs"); KillWaves Thresh_locs
			endif
			if(waveexists(Width_Vals))
				Duplicate /o Width_vals $("root:"+folder+":Width"); KillWaves Width_Vals
			endif
			Wave Trough=$("root:"+folder+":Trough")
			Wave Threshold=$("root:"+folder+":Threshold")
			Wave Peak=$("root:"+folder+":Peak")
			Make /o/n=(numpnts(Trough)) AHP=Trough-Threshold
			Make /o/n=(numpnts(Peak)) Height=Peak-Threshold
		endif
	endfor
	root()
End

Function WidthNorm2([new])
	Variable new // Use new widths (see WidthNorm for description)
	if(ParamIsDefault(new))
		new=0
	endif
	root()
	Variable i;String folder
	Wave /T FileName
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			WidthNorm(new=new)
		endif
	endfor
	root()
End

Function HeightNorm2([new])
	Variable new // Use new widths (see WidthNorm for description)
	if(ParamIsDefault(new))
		new=0
	endif
	root()
	Variable i;String folder
	Wave /T FileName
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			HeightNorm(new=new)
		endif
	endfor
	root()
End

Function Spikes3([path])
	String path
	root()
	if(ParamIsDefault(path))
		path=StrVarOrDefault("root:parameters:random:dataDir","")
	endif
	path=Windows2IgorPath(path)
	NewPath /O/Q IBWPath path
	Wave /T FileName,Condition
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		root()
		ibw=FileName[i]+".ibw"
		folder="root:Cells:"+FileName[i]
		if(DataFolderExists(folder))
			name=LoadIBW(ibw)
			Wave w=$name
			Spikes(w=w,start=leftx(w),finish=rightx(w))
			KillWaves w
		endif
	endfor
	root()
	//KillPath IBWPath
End

// Make a new wave of spike widths for each cell, based upon the threshold of the first spike in the upstate, rather than the threshold of the spike itself.  
Function GetNewWidths2([path])
	String path
	root()
	if(ParamIsDefault(path))
		path=StrVarOrDefault("root:parameters:random:dataDir","")
	endif
	path=Windows2IgorPath(path)
	NewPath /O/Q IBWPath path
	Wave /T FileName,Condition
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		root()
		folder="root:Cells:"+FileName[i]
		if(DataFolderExists(folder))
			SetDataFolder $folder
			ibw=FileName[i]+".ibw"
			GetNewWidths(ibw)
		endif
	endfor
	root()
	//KillPath IBWPath
End

Function GetNewWidths(ibw)
	String ibw
	String name=LoadIBW(ibw)
	Wave w=$name
	Wave Peak_Locs,Peak,Threshold_Locs,Threshold,Trough_Locs,ISI
	Duplicate /o Width NewWidth
	Wave Width,NewWidth
	Variable i,j,left
	for(i=0;i<numpnts(Width);i+=1)
		if(ISI[i]<1)
			j=i
			Do
				j-=1
			While(ISI[j]>0 && ISI[j]<1)
  			FindLevel /Q /R=(Peak_locs[i],Threshold_Locs[j]) w, (Peak[i]+Threshold[j])/2 // Yes this should be i and j
  			left=V_LevelX
  			FindLevel /Q /R=(Peak_locs[i],Trough_locs[i]) w, (Peak[i]+Threshold[j])/2
  			NewWidth[i]=V_LevelX-left
		else
			NewWidth[i]=Width[i]
		endif
	endfor
	KillWaves /Z w
End

Function AllThreshes()
	root()
	Variable i,j;String folder
	Wave /T FileName
	Make /o /n=0 /T Names; Wave /T Names
	Make /o /n=0 Thymes,ThreshZah; Wave Thymes,ThreshZah
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave Threshold_locs,Threshold,Peak_locs
			for(j=0;j<numpnts(Threshold);j+=1)
				if(Threshold[j]>-15)
					InsertPoints 0,1,Names,Thymes,ThreshZah
					Names[0]=folder
					Thymes[0]=Peak_locs[j]
					ThreshZah[0]=Threshold[j]
				endif
			endfor
		endif
	endfor
	Edit /K=1 Names,ThreshZah,Thymes
	root()
End

// Normalize widths to the intial width
Function WidthNorm([new])
	Variable new // Use new widths (see GetNewWidth for description)
	if(ParamIsDefault(new))
		new=0
	endif
	if(new)
		Wave Width=NewWidth
	else
		Wave Width=Width
	endif
	Duplicate /o Width WidthNormed
	Wave ISI
	Variable i,last_width=Width[0]
	for(i=0;i<numpnts(Width);i+=1)
		if(ISI[i]<5)
			WidthNormed[i]=Width[i]/last_width
			if(WidthNormed[i]==0)
				WidthNormed[i]=NaN
			endif
		else
			WidthNormed[i]=1
			last_width=Width[i]
		endif
	endfor
End

// Normalize widths to the intial width
Function HeightNorm([new])
	Variable new // Use new widths (see GetNewWidth for description)
	if(ParamIsDefault(new))
		new=0
	endif
	if(new)
		Wave Height=NewHeight
	else
		Wave Height=Height
	endif
	Duplicate /o Height HeightNormed
	Wave ISI
	Variable i,last_height=Height[0]
	for(i=0;i<numpnts(Height);i+=1)
		if(ISI[i]<5)
			HeightNormed[i]=Height[i]-last_height
			if(HeightNormed[i]==0)
				HeightNormed[i]=NaN
			endif
		else
			HeightNormed[i]=0
			last_height=Height[i]
		endif
	endfor
End

// Compute ISI Histograms for all the spikes in each condition
Function ISIHistograms([mode,auto,logg,events])
	Variable mode,auto,logg
	String events // The kind of event you want to study the ISI histogram of.  It could be any ascending wave, for example 'Peak_locs' to study spikes
	// or 'UpstateBegins' to study Upstates.  
	
	String curr_folder=GetDataFolder(1)
	root()
	mode=ParamIsDefault(mode) ? 0 : mode // Mode 0 to normalize by time, mode=1 to normalize by firing rate.  
	auto=ParamIsDefault(auto) ? 0 : auto // Compute the autocorrelograms instead of the ISI histograms.  
	logg=ParamIsDefault(logg) ? 1 : logg
	if(ParamIsDefault(events))
		events="Peak_Locs" // The times of spikes
	endif
	
	Variable i,j,loc;String folder,condition_str,conditions="Control;Seizure"
	String name=SelectString(auto,"ISI","Auto")+"_"+num2str(mode)+"_"+events
	Wave /T FileName,Condition
	String dest_folder=UniqueName("ISIHistograms",11,0)
	NewDataFolder /O/S $dest_folder
	dest_folder=GetDataFolder(1)
	Make /o/n=(ItemsInList(conditions)) TotalTime=0
	Make /o/n=(ItemsInList(conditions)) TotalEvents=0
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Make /o/n=0 $(condition_str+"All_"+name+"_Hist")=0
		if(auto==0)
			Make /o/n=0 $(condition_str+"_DiffEventTimes")=0
		elseif(auto==1)
			Make /o/n=0 $(condition_str+"_AutoEventTimes")=0
		endif
	endfor
	
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			//if(WaveExists($events))
				Wave EventTimes=$events
				if(auto==0)
					Differentiate /METH=1 EventTimes /D=DiffEventTimes
					Concatenate /NP {DiffEventTimes}, $(dest_folder+condition_str+"_DiffEventTimes")
				elseif(auto==1)
					Make/o/n=(numpnts(EventTimes),numpnts(EventTimes)) AutoEventTimes
					AutoEventTimes=EventTimes[p]-EventTimes[q]
					Redimension /n=(numpnts(EventTimes)^2) AutoEventTimes
					DeleteNans(AutoEventTimes)
					Concatenate /NP {AutoEventTimes}, $(dest_folder+condition_str+"_AutoEventTimes")
				endif
				NVar start=spikes_start,finish=spikes_finish
				TotalTime[WhichListItem(condition_str,conditions)]+=finish-start
				TotalEvents[WhichListItem(condition_str,conditions)]+=numpnts(EventTimes)
				KillWaves /Z DiffEventTimes,AutoEventTimes
			//endif
		endif
	endfor
	
	SetDataFolder $dest_folder
	Display /K=1
	Variable last,first
	Variable left=0.01,right=1000
	Variable bin_size=0.02 // Bin size in log units
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave AllHist=$(condition_str+"All_"+name+"_Hist")
		if(auto==0)
			Wave All=$(condition_str+"_DiffEventTimes")
		elseif(auto==1)
			Wave All=$(condition_str+"_AutoEventTimes")
		endif
		if(logg)
			All=log(All)
			Redimension /n=(1+(log(right)-log(left))/bin_size) AllHist
			SetScale /I x,log(left),log(right),AllHist
		else
			Redimension /n=(1+(right-left)/bin_size) AllHist
			SetScale /I x,(left),(right),AllHist
		endif
		Histogram /B=2 All,AllHist
		AllHist /= bin_size
		if(logg)
			AllHist/=10^x // Normalize because larger values haver wider windows using the log scale.  
		endif
		if(mode==0)
			AllHist*=(1/TotalTime[WhichListItem(condition_str,conditions)]) // Convert to an average ISI per unit time.  
		elseif(mode==1)
			AllHist*=(1/TotalEvents[WhichListItem(condition_str,conditions)]) // Convert to an average ISI per Event.  
		endif
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) AllHist
		//KillWaves /Z All
	endfor
	if(logg)
		Make /o/n=5 TickWave={-2,-1,0,1,2}
		Make /o/T/n=5 TickWaveLabels={"10 ms","100 ms","1 s","10 s","100 s"}
		ModifyGraph userTicks(bottom)={TickWave,TickWaveLabels}
		SetAxis bottom log(left),log(right)
	else
		SetAxis bottom left,right
	endif
	SmoothTraces(2)
	KillVariables red,green,blue
	KillWaves /Z TotalEvents,TotalTime
	SetDataFolder $curr_folder
End

// Compute ISI Histograms for all the spikes in each condition, averaging across each cell first.  
Function ISIHistograms2([mode,auto,logg,events])
	Variable mode,auto,logg
	String events // The kind of event you want to study the ISI histogram of.  It could be any ascending wave, for example 'Peak_locs' to study spikes
	// or 'UpstateBegins' to study Upstates.  
	mode=ParamIsDefault(mode) ? 0 : mode // Mode 0 to normalize by time, mode=1 to normalize by firing rate.  
	auto=ParamIsDefault(auto) ? 0 : auto // Compute the autocorrelograms instead of the ISI histograms.  
	logg=ParamIsDefault(logg) ? 1 : logg
	if(ParamIsDefault(events))
		events="Peak_Locs" // The times of spikes
	endif
	root()
	Variable i,j,loc;String folder,condition_str,conditions="Control;Seizure"
	String name=SelectString(auto,"ISI","Auto")+"_"+events
	Wave /T FileName,Condition
	Make /o/n=(ItemsInList(conditions)) TotalTime=0
	Make /o/n=(ItemsInList(conditions)) TotalEvents=0
	Make /o/n=(ItemsInList(conditions)) ConditionCount=0
	Wave ConditionCount
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Make /o/n=0 root:$(condition_str+"All"+name+"Hist")=0
	endfor
	Variable last,first
	Variable left=0.01,right=1000
	Variable bin_size=0.1 // Bin size in log units
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Make /o/n=0 $(name+"Hist")=0
			Wave Hist=$(name+"Hist")
			Wave EventTimes=$events
			if(numpnts(EventTimes)>0)
				Duplicate /o EventTimes $name
				Wave All=$name
				if(auto==0)
					Differentiate /METH=1 All
				elseif(auto==1)
					Make/o/n=(numpnts(All),numpnts(All)) TempAuto
					TempAuto=All[p]-All[q]
					Redimension /n=(numpnts(All)^2) TempAuto
					DeleteNans(TempAuto)
					Wave All=TempAuto
				endif
				Wave AllHist=root:$(condition_str+"All"+name+"Hist")
				if(logg)
					All=log(All)
					Redimension /n=(1+(log(right)-log(left))/bin_size) Hist,AllHist
					SetScale /I x,log(left),log(right),Hist,AllHist
				else
					Redimension /n=(1+((right)-(left))/bin_size) Hist,AllHist
					SetScale /I x,(left),(right),Hist,AllHist
				endif
				Histogram /B=2 All,Hist
				Hist/=bin_size
				if(logg)
					Hist/=10^x // Normalize because larger values haver wider windows using the log scale.  
				endif
				if(mode==0)
					NVar spikes_start,spikes_finish
					Hist/=(spikes_finish-spikes_start) // Convert to an average ISI per unit time.  
				elseif(mode==1)
					Hist/=(numpnts(EventTimes)) // Convert to an average ISI per spike.  
				endif
				AllHist+=Hist
				ConditionCount[WhichListItem(condition_str,conditions)]+=1
				KillWaves /Z All
			endif
		endif
	endfor
	Display /K=1
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave AllHist=root:$(condition_str+"All"+name+"Hist")
		AllHist/=ConditionCount[WhichListItem(condition_str,conditions)]
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) AllHist
	endfor
	if(logg)
		Make /o/n=5 TickWave={-2,-1,0,1,2}
		Make /o/T/n=5 TickWaveLabels={"10 ms","100 ms","1 s","10 s","100 s"}
		ModifyGraph userTicks(bottom)={TickWave,TickWaveLabels}
		SetAxis bottom log(left),log(right)
	else
		SetAxis bottom (left),(right)
	endif
	//SmoothTraces(1)
	KillVariables red,green,blue
End

// Plot the width vs peak amplitude for all spikes that come more than 'min_isi after the last spike
Function WidthvsHeight([min_isi])
	Variable min_isi
	min_isi=ParamIsDefault(min_isi) ? 5 : min_isi
	root()
	Variable i,j;String folder,condition_str,conditions="Control;Seizure"
	Wave /T FileName,Condition
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Make /o/n=0 root:$(condition_str+"Width")=0
		Make /o/n=0 root:$(condition_str+"Height")=0
	endfor
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		Wave AllWidth=root:$(condition_str+"Width")
		Wave AllHeight=root:$(condition_str+"Height")
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave Width,ISI,Peak
			for(j=0;j<numpnts(Width);j+=1)
				if(ISI[j]<min_isi || Width[j]==0)
				else
					InsertPoints 0,1,AllWidth,AllHeight
					AllWidth[0]=Width[j]
					AllHeight[0]=Peak[j]
				endif
			endfor
		endif
	endfor
	root()
	Display /K=1
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave AllWidth=root:$(condition_str+"Width")
		Wave AllHeight=root:$(condition_str+"Height")
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) AllWidth vs AllHeight
	endfor
	BigDots(size=2)
	KillVariables /Z red,green,blue
End

// Plot the width vs peak amplitude for all spikes that come more than 'min_isi after the last spike, averaged for each cell
Function WidthvsHeight2([min_isi])
	Variable min_isi
	min_isi=ParamIsDefault(min_isi) ? 1 : min_isi
	root()
	Variable i,j;String folder,condition_str,conditions="Control;Seizure"
	Wave /T FileName,Condition
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Make /o/n=0 root:$(condition_str+"Width")=0
		Make /o/n=0 root:$(condition_str+"Height")=0
	endfor
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		Wave AllWidth=root:$(condition_str+"Width")
		Wave AllHeight=root:$(condition_str+"Height")
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave Width,ISI,Peak
			Duplicate /o Width Width2
			Duplicate /o Peak Peak2
			Width2=(ISI>min_ISI) ? NaN : Width2
			Peak2=(ISI>min_ISI) ? NaN : Peak2
			DeleteNans(Width2)
			DeleteNans(Peak2)
			if(numpnts(Width2)>0 && numpnts(Peak2)>0)		
				InsertPoints 0,1,AllWidth,AllHeight
				WaveStats /Q Width2				
				AllWidth[0]=V_avg
				WaveStats /Q Peak2
				AllHeight[0]=V_avg
			endif
			KillWaves /Z Width2,Peak2
		endif
	endfor
	root()
	Display /K=1
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave AllWidth=root:$(condition_str+"Width")
		Wave AllHeight=root:$(condition_str+"Height")
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) AllWidth vs AllHeight
	endfor
	BigDots(size=2)
	KillVariables /Z red,green,blue
End

// Compute the relationship between the width and the ISI
Function WidthvsISI()
	root()
	Variable i,j,first_peak,recent_peak,first_width,recent_width,min_width;String folder,condition_str,conditions="Control;Seizure"
	String temp1,temp2
	Wave /T FileName,Condition
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Make /o/n=0 root:$(condition_str+"WidthVsISICoeff")=0
	endfor
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		Wave Coeff=root:$(condition_str+"WidthVsISICoeff")
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave Width,ISI,Peak
			Make /o/n=0 Width2=0,ISI2=0
			if(numpnts(Peak)>0)
				first_peak=Peak[0]; first_width=Width[0]
				recent_peak=first_peak; recent_width=first_width
				WaveStats /Q Width
				min_width=min(1.5,V_min)
			endif
			for(j=0;j<numpnts(Width);j+=1)
				if(ISI[j]<1)
					InsertPoints 0,1,Width2,ISI2
					Width2[0]=(Width[j]-recent_width)//-(first_peak-recent_peak)*0.00005
					if(Width2[0]<0)
					endif
					ISI2[0]=ISI[j]; 
				elseif(ISI[j]>1)
					recent_peak=Peak[j]
					recent_width=Width[j]
					//if(abs(recent_peak-first_peak)>10)
						//break
					//endif					
				endif
			endfor
			ISI2=log(ISI2)
			//Width2=log(Width2)
			//Variable V_FitOptions=6
			//DeleteNans(ISI2,companions="Width2")
			//DeleteNans(Width2,companions="ISI2")
			//Display /K=1 /N=$folder Width2 vs ISI2
			
			BigDots(size=2)
			if(numpnts(Width2)>=35)
				WaveStats /Q Peak;
				if(V_max>15)
					K0 = 0;
					Variable /G V_Fitoptions=4,V_FitError=0
					CurveFit /N/Q/H="100" line Width2 /X=ISI2 
					if(V_FitError==0)//KillVariables V_fitoptions
					//KillWaves ISI2,Width2
						InsertPoints 0,1,Coeff
						Coeff[0]=k1
					endif
				endif
			endif
			//KillVariables V_fitoptions
		endif
	endfor
	root()
	//Display /K=1
	Make /o/n=(ItemsInList(conditions)) WidthVsISICoeffAvg,WidthVsISICoeffSEM
	Make /o/T/n=(ItemsInList(conditions)) WidthVsISICoeffLabels
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave Coeff=root:$(condition_str+"WidthVsISICoeff")
		Sort Coeff,Coeff
		SetScale x,0,1,Coeff
		WaveStats /Q Coeff
		WidthVsISICoeffAvg[i]=V_avg
		WidthVsISICoeffSEM[i]=V_sdev/sqrt(V_npnts)
		WidthVsISICoeffLabels[i]=condition_str
		//Condition2Color(condition_str); NVar red,green,blue
		//AppendToGraph /c=(red,green,blue) Coeff
	endfor
	Display /K=1 WidthVsISICoeffAvg vs WidthVsISICoeffLabels
	ErrorBars WidthVsISICoeffAvg, Y wave=(WidthVsISICoeffSEM,WidthVsISICoeffSEM)
	ModifyGraph zColor(WidthVsISICoeffAvg)={Colors,*,*,directRGB}
	//printf BootMean(ControlWidthvsISICoeff,SeizureWidthvsISICoeff)
	//ModifyGraph 
	//ModifyGraph swapXY=1
	KillVariables /Z red,green,blue
End

Function WidthVsISI2([cell,to_append])
	String cell
	Variable to_append
	//Spikes()
	String folder
	if(ParamIsDefault(cell))
		folder="reanalysis"
	else
		folder=cell+"_Folder"
	endif
	Wave Width=$("root:'"+folder+"':width_vals")
	Wave ISI=$("root:'"+folder+"':ISI")
	if(!to_append)
		Display /K=1 Width vs ISI
	else
		AppendToGraph Width vs ISI
	endif
	BigDots(size=3)
	String condition=Cell2Condition(cell)
	Condition2Color(condition)
	NVar red,green,blue
	ModifyGraph log(bottom)=1,rgb($TopTrace())=(red,green,blue)
	SetAxis bottom 0.01,100
	SetAxis left 0.002,0.008
End


// Plot the relationship between the normalized width and the ISI
Function NormXvsISI(param)
	String param // e.g. "Width"
	root()
	Variable i,j,first_peak,recent_peak,first_x,recent_width,min_x;String folder,condition_str,conditions="Control;Seizure"
	String temp1,temp2
	Wave /T FileName,Condition
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Make /o/n=0 root:$(condition_str+"Normed"+param)=0
		Make /o/n=0 root:$(condition_str+"ISIforNormed"+param)=0
	endfor
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		Wave Normed=root:$(condition_str+"Normed"+param)
		Wave ISIfor=root:$(condition_str+"ISIforNormed"+param)
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave XNormed=$(param+"Normed"),ISI
			for(j=0;j<numpnts(XNormed);j+=1)
				InsertPoints 0,1,Normed,ISIfor
				Normed[0]=XNormed[j]
				ISIfor[0]=ISI[j]
			endfor
		endif
	endfor
	root()
	Display /K=1
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave Normed=root:$(condition_str+"Normed"+param)
		Wave ISIfor=root:$(condition_str+"ISIforNormed"+param)
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) Normed vs ISIfor
	endfor
	BigDots(size=2)
	SetAxis bottom 0,1
	KillVariables /Z red,green,blue
End

Function PlotSpikesvsISI()
	Variable i
	Wave /T File_Name=File_Name
	Wave /T Condition=Condition
	Wave ISIs=ISIs
	Wave Rs=Rs
	Wave Width_Vals=Width_Vals
	Wave Height_Vals=Peak_Vals
	String name,isi_name,width_name,height_name,Rs_name,displayed
	for(i=0;i<numpnts(File_Name);i+=1)
		name=File_Name[i]+"_"+Condition[i]
		isi_name=name+"_isi"
		width_name=name+"_width"
		height_name=name+"_height"
		Rs_name=name+"_Rs"
		if(!exists(isi_name))
			Make /o/n=0 $isi_name,$width_name,$height_name,$Rs_name
		endif
		InsertPoints numpnts($isi_name),1,$isi_name,$width_name,$height_name,$Rs_name
		Wave isi=$isi_name; Wave width=$width_name; Wave height=$height_name; Wave Access=$Rs_name
		isi[numpnts(isi)-1]=ISIs[i]
		width[numpnts(isi)-1]=Width_Vals[i]
		height[numpnts(isi)-1]=Height_Vals[i]
		access[numpnts(isi)-1]=Rs[i]
	endfor
	displayed=""
	for(i=0;i<numpnts(File_Name);i+=1)
		if(WhichListItem(File_Name[i],displayed)==-1)
			name=File_Name[i]+"_"+Condition[i]
			isi_name=name+"_isi"
			width_name=name+"_width"
			Display /K=1 /N=$("W_"+name) $width_name vs $isi_name
			ModifyGraph log(bottom)=1, log(left)=1,mode=2, lsize=3
			strswitch(Condition[i])
				case "Control":
					ModifyGraph rgb=(0,0,0)
					break
				case "PTX":
					ModifyGraph rgb=(65535,0,0)
					break
				case "PTZ":
					ModifyGraph rgb=(65535,32767,32767)
					break
				default:
					break
			endswitch
			WaveStats /Q $isi_name
			SetAxis bottom, 0.01,600
			displayed+=File_Name[i]+";"
		endif
	endfor
End

// Extracts various information about the spikes observed in a recording.  
Function VariousCellStats()
	Wave /T FileName,Condition,Experimenter
	Variable i; String name
	root()
	for(i=0;i<numpnts(FileName);i+=1)
		root()
		name=FileName[i]
		if(DataFolderExists("root:Cells:"+name))
			SetDataFolder root:Cells:$name
			Make /o/n=1 MinISI
			Wave ISI
			if(numpnts(ISI)>0)
				WaveStats /Q ISI
				MinISI=V_min
			else
				MinISI=NaN
			endif
		endif
	endfor
	root()
End

// Computes mean firing rate for each cell.  Requires FileRecord() to be run first.  
Function FiringRates()
	SVar file_list
	Wave /T File_Name
	Wave CellDuration
	Variable i,cell
	String sweep,sweep_list=""
	Duplicate /o CellDuration CellSpikes
	CellSpikes=0
	for(i=0;i<numpnts(File_Name);i+=1)
		cell=WhichListItem(File_Name[i],file_list)
		if(cell==-1)
			printf "Cell was not found in File_Name.\r"  
			return 0
		endif
		CellSpikes[cell]+=1;
	endfor
	Duplicate /o CellSpikes CellRate
	CellRate=CellSpikes/CellDuration
End

Function PlotHeightsvsWidths(conditions)
	String conditions
	Variable i,j
	SVar file_names=file_names
	Display /K=1 /N=HeightsvsWidths
	Variable red,green,blue
	Variable min_isi=1
	for(j=0;j<ItemsInList(conditions);j+=1)  
		string condition=StringFromList(j,conditions)
		for(i=0;i<ItemsInList(file_names);i+=1)
			string name=StringFromList(i,file_names)
			if(StringMatch(name,"*"+condition+"*"))
				Wave ISI = $(name+"_isi")
				string heights=(name+"_height")
				string widths=(name+"_width")
				Duplicate /o $heights $(heights+"_"+num2str(min_isi))
				Wave heights2=$(heights+"_"+num2str(min_isi))
				Duplicate /o $widths $(widths+"_"+num2str(min_isi))
				Wave widths2=$(widths+"_"+num2str(min_isi))
				heights2=ISI[p]>min_isi ? heights2[p]:NaN
				widths2=ISI[p]>min_isi ? widths2[p]:NaN
				string color=Condition2Color(condition)
				red=str2num(StringFromList(0,color,","))
				green=str2num(StringFromList(1,color,","))
				blue=str2num(StringFromList(2,color,","))
				AppendToGraph /c=(red,green,blue) heights2 vs widths2
			endif
		endfor
	endfor
End

Function ISIcompare(list)
	String list // e.g. "Control;PTX;PTZ;PT*"
	Variable i,j
	Wave /T Condition=ConditionExperimenter
	//Wave /T Condition=Condition
	Wave ISIs=ISIs
	String cond,actual_cond
	for(j=0;j<ItemsInList(list);j+=1)
		cond=StringFromList(j,list)
		cond=ReplaceString("*",cond,"star")
		Make /o/n=0 $(cond+"_allISIs")
	endfor
	for(i=0;i<numpnts(Condition);i+=1)
		actual_cond=Condition[i]
		for(j=0;j<ItemsInList(list);j+=1)
			cond=StringFromList(j,list)
			if(StringMatch(actual_cond,cond))
				cond=ReplaceString("*",cond,"star")
				Wave allISIs=$(cond+"_allISIs")
				Redimension /n=(numpnts(allISIs)+1) allISIs
				allISIs[numpnts(allISIs)-1]=ISIs[i]
			endif
		endfor
	endfor
	Display /K=1
	for(j=0;j<ItemsInList(list);j+=1)
		cond=StringFromList(j,list)
		cond=ReplaceString("*",cond,"star")
		Wave allISIs=$(cond+"_allISIs")
		Histogram3(10000,allISIs,log10=1,graph=2) // Append a histogram
		Condition2Color(StringFromList(j,list)); NVar red,green,blue
		ModifyGraph rgb($(cond+"_allISIs_hist"))=(red,green,blue)
		WaveTransform /O normalizeArea $(cond+"_allISIs_hist")
	endfor
	SmoothTraces(20000)
	// Make the bottom axis shows seconds instead of log(seconds)
	NewFreeAxis /B log
	GetAxis bottom; SetAxis log 10^V_min,10^V_max
	ModifyGraph log(log)=1
	ModifyGraph axRGB(bottom)=(65535,65535,65535),tlblRGB(bottom)=(65535,65535,65535),alblRGB(bottom)=(65535,65535,65535)
	ModifyGraph freePos(log)={0,left},lblPos(log)=35
	Label log "seconds"
	Label left "Probability"
End

// Produces an autocorrelogram for spikes, given the input spike train (wave of spike times) 'train'
Function AutoCorrelogram(train,[cutoff,logg])
	Wave train
	Variable cutoff,logg // Compute in log coordinates or not
	Variable i,entry
	cutoff=ParamIsDefault(cutoff) ? Inf : cutoff
	// Use the following only for enormous spike trains (N points), for which an NxN matrix would take up too much memory.  
//	Make /o/n=0 $("Autoraw_"+NameOfWave(train))
//	Wave Autoraw=$("Autoraw_"+NameOfWave(train))
//	for(i=0;i<numpnts(train);i+=1)
//		Duplicate /o train Auto_One
//		entry=Auto_One[i]
//		Auto_One-=entry
//		Concatenate /NP {Auto_One},Autoraw
//	endfor
	Variable bin_size=0.01 // Size in seconds of each bin
	Make /o/n=(numpnts(train),numpnts(train)) $("Autoraw_"+NameOfWave(train))=train[p]-train[q]
	Wave Autoraw=$("Autoraw_"+NameOfWave(train))
	Redimension /n=(numpnts(train)^2) Autoraw
	Autoraw=abs(Autoraw)
	Make /o/n=0 $("Auto_"+NameOfWave(train));
	Wave Auto=$("Auto_"+NameOfWave(train));
	if(logg)
		Autoraw=log(Autoraw)
		Histogram /B={-2,bin_size,5/bin_size} Autoraw, Auto; 
		Auto/=10^x
		Display /K=1 Auto; ModifyGraph mode=0; SetAxis bottom, -2,2.5
		Make /o log_ticks={-2,-1,0,1,2}
		Make /o/T log_tick_labels={"10 ms","100 ms","1 s","10 s","100 s"}
		ModifyGraph userTicks(bottom)={log_ticks,log_tick_labels}
	else
		Histogram /B={0,bin_size,600/bin_size} Autoraw, Auto; 
		Auto[0]=0 // Set the self-correlation bin to zero.  
		Display /K=1 Auto; ModifyGraph mode=0,log(bottom)=1; SetAxis bottom, 0.01,600
	endif
	//NVar cumul_duration // The total amount of time during which spikes were recorded from all of these cells
	//Auto/=cumul_duration // Also, you could divide by a factor of 2 is since the absolute value is used 
	Auto/=2 // Normalize so only forward spikes are counted, not forward and reverse (taking the absolute value earlier made this necessary).  
	Auto/=numpnts(train) // Normalize so that the autocorrelogram is per spike
	Auto/=bin_size // Normalize so that the autocorrelation is in Hz
	Label bottom, "s"; Label left, "Hz"
	KillWaves /Z Autoraw,Auto_One
End

// Produces an ISI Histogram for spikes, given the input spike train (wave of spike times) 'train'
Function ISI_Histogram(train,[logg,cutoff])
	Wave train
	Variable logg,cutoff
	Variable i,entry
	cutoff=ParamIsDefault(cutoff) ? Inf : cutoff
	Make /o/n=(numpnts(train)-1) $("ISIraw_"+NameOfWave(train))=train[p+1]-train[p]
	Wave ISIraw=$("ISIraw_"+NameOfWave(train))
	Make /o/n=0 $("ISI_"+NameOfWave(train));
	Wave ISI=$("ISI_"+NameOfWave(train));
	Display /K=1 ISI; ModifyGraph mode=5
	if(logg)
		ISIraw=Log(ISIraw)
		Histogram /B={-2,0.01,500} ISIraw, ISI; 
		Make /o log_ticks={-2,-1,0,1,2}
		Make /o/T log_tick_labels={"10 ms","100 ms","1 s","10 s","100 s"}
		ModifyGraph userTicks(bottom)={log_ticks,log_tick_labels}
		ISI/=10^x
	else
		Histogram /B={0,0.01,60000} ISIraw, ISI; 
	endif
	NVar cumul_duration // The total amount of time during which spikes were recorded from all of these cells
	ISI/=cumul_duration
	KillWaves /Z ISIraw
End

// Take the file name and PeakX columns from an access query and turn into a giant spike train
// Spikes from one cell offset from spikes in another cell.
Function SpikeTrainFromCellSpikeTimes(FileNameWave,SpikeTimes)
	Wave /T FileNameWave
	Wave SpikeTimes
	Variable i
	String name=FileNameWave[0]
	for(i=0;i<numpnts(FileNameWave);i+=1)
		if(!StringMatch(FileNameWave[i],name))
			SpikeTimes[i,]+=1000
			name=FileNameWave[i]
		endif
	endfor
End

// Concatenates spike trains (assumed to have the names 'cell'_PeakX) into one spike train called 'name'
Function ConcatTrains(name,list,indices)
	String name,list,indices
	Variable i; String cell,index
	Make /o/n=0 $name
	Wave dest=$name
	Variable duration=0
	Variable /G cumul_duration=0
	Wave CellDuration
	for(i=0;i<ItemsInList(list);i+=1)
		cell=StringFromList(i,list)
		index=StringFromList(i,indices)
		Wave train=$(cell+"_PeakX")
		WaveStats /Q train
		if(V_numNans>0)
		endif
		Concatenate /NP {train},dest
		duration=CellDuration[str2num(index)]
		if(i<ItemsInList(list)-1)
			dest+=duration // Add the duration of the previous one to this one (except for the last time)
		endif
		cumul_duration+=duration
	endfor
	Sort dest,dest
End

// The ISI (spike B minus spike A) vs the number of spikes in a given time window that preceded spike A
Function ISIvsCumulSpikes(Train)
	Wave Train
	Duplicate /o Train,SpikeTrain
	DeleteNans(SpikeTrain)
	Variable windoe=0.5 // Window width in seconds
	Duplicate /o SpikeTrain $("ISI_"+NameOfWave(Train)),$("CumulSpikes_"+NameOfWave(Train))
	Wave ISI=$("ISI_"+NameOfWave(Train)); ISI=NaN
	Wave CumulSpikes=$("CumulSpikes_"+NameOfWave(Train)); CumulSpikes=NaN
	Variable i,loc
	for(i=1;i<numpnts(SpikeTrain);i+=1)
		ISI[i]=SpikeTrain[i]-SpikeTrain[i-1]
		loc=BinarySearch(SpikeTrain,SpikeTrain[i-1]-windoe)
		loc=(loc<0) ? 0 : loc // If windoe stretches back before the first spike, then start with the first spike
		CumulSpikes[i]=(i-1-loc+enoise(0.5))
	endfor
	Display /K=1 CumulSpikes vs ISI
	ModifyGraph log(bottom)=1
	ModifyGraph mode=2,lsize=2
	KillWaves SpikeTrain
End

// Plots the number of spikes after each spike versus the number of spikes before each spike.  
Function AfterVsBefore(Train)
	Wave Train
	Duplicate /o Train,SpikeTrain
	DeleteNans(SpikeTrain)
	Variable windoe=1 // Window width in seconds
	Duplicate /o SpikeTrain $("Before_"+NameOfWave(Train)),$("After_"+NameOfWave(Train))
	Wave Before=$("Before_"+NameOfWave(Train)); Before=NaN
	Wave After=$("After_"+NameOfWave(Train)); After=NaN
	Variable i,loc
	for(i=1;i<numpnts(SpikeTrain);i+=1)
		loc=BinarySearch(SpikeTrain,SpikeTrain[i]-windoe)
		loc=(loc<0) ? 0 : loc // If windoe stretches back before the first spike, then start with the first spike
		//Before[i]=(i-loc+abs(enoise(1))) // Add noise.  
		loc=BinarySearch(SpikeTrain,SpikeTrain[i]+windoe)
		loc=(loc<0) ? i : loc // If windoe stretches back before the first spike, then start with the first spike
		//After[i]=(loc-i+abs(enoise(1))) // Add noise.  
	endfor
	Display /K=1 After vs Before
	ModifyGraph log=1
	ModifyGraph mode=2,lsize=2
	KillWaves SpikeTrain
End

// For Roger's paper: Does the firing rate run down during the time that the cell is patched?  
Function SpikesVsTime([bin_size,interval])
	Variable bin_size,interval
	bin_size=ParamIsDefault(bin_size) ? 60 : bin_size
	interval=ParamIsDefault(interval) ? 60 : interval
	SetDataFolder root:
	String folder_list=StringByKey("Folders",DataFolderDir(1))
	folder_list=ReplaceString(",",folder_list,";")
	Make /o/n=0 BinTimes,SpikeFractions
	Wave BinTimes=BinTimes; Wave SpikeFractions=SpikeFractions
	Display /K=1
	Variable i,j,thyme,effective_bin_size; String name//,spike_rate_name
	for(i=0;i<ItemsInList(folder_list);i+=1)
		name=StringFromList(i,folder_list)
		SetDataFolder $name
		name=StringFromList(0,name,"_")
		Wave SpikeTimes=Peak_Locs
		NVar start_time=spikes_start
		NVar finish_time=spikes_finish
		Make /o /n=(floor((finish_time-start_time)/interval)) RelSpikeRate
		if(interval-mod(finish_time-start_time,interval)<interval*0.01)
			InsertPoints 0,1,RelSpikeRate // Because floor of an integer is the next lowest integer.  
		endif
		SetScale /P x,(start_time+interval/2)/60,interval/60,RelSpikeRate // Divide by 60 to get minutes instead of seconds
		for(j=0;j<numpnts(RelSpikeRate);j+=1)
			thyme=start_time+j*interval+interval/2
			InsertPoints 0,1,BinTimes;BinTimes[0]=thyme
			//effective_bin_size=min(bin_size,finish_time-j)
			RelSpikeRate[j]=NumBetweenXandY(SpikeTimes,thyme-bin_size/2,thyme+bin_size/2)/numpnts(SpikeTimes)
			InsertPoints 0,1,SpikeFractions;SpikeFractions[0]=RelSpikeRate[j]
		endfor
		AppendToGraph RelSpikeRate
		SetDataFolder ::
	endfor
	ScrambleColors()
	AverageTraces()
	ModifyGraph mode=4,marker=8
	ModifyGraph lsize($TopTrace())=3, rgb($TopTrace())=(0,0,0)
End

Function CountSpikes([w,start,finish,thresh]) 
	//NVar sweep_num=root:reanalysis:wave_number
	Wave w
	Variable start,finish,thresh
	NewDataFolder /O/S root:reanalysis
	if(ParamIsDefault(w))
		Wave w=CsrWaveRef(A)
	endif
	Duplicate /o w sweep
	start=ParamIsDefault(start) ? xcsr(A) : start
	finish=ParamIsDefault(finish) ? xcsr(B) : finish
	thresh=ParamIsDefault(thresh) ? -10 : thresh // The action potential must reach this level to be counted
	//refract=ParamIsDefault(refract) ? 0.01 : refract // Two action potentials cannot occur within this number of seconds
	Make /o/n=0 root:reanalysis:cross_locs
	FindLevels /P/Q /R=(start,finish) sweep, thresh; Wave CrossLocs=W_FindLevels
	Variable i=0
	Do
		if(w[floor(CrossLocs[i])] > w[ceil(CrossLocs[i])])
			DeletePoints i,1,CrossLocs
		else
			i+=1
		endif
	While(i<numpnts(CrossLocs))
	Variable num_spikes=numpnts(CrossLocs)
	KillWaves CrossLocs
	return num_spikes
End


//Sweep-by-sweep fxn to get time of the first spike (for Brett)
Function FirstSpike(range)
        String range
        //UpstateLocations()
        Wave UpstateOn,UpstateOff
        range=ListExpand(range)
        Variable i
        Make /o/n=(ItemsInList(range)) SweepNums=NaN,SpikeTimes=NaN,SpikeInUpstate=NaN
        for(i=0;i<ItemsInList(range);i+=1)
                String item=StringFromList(i,range)
                item="root:cellR1:sweep"+item
                if(!exists(item))
                        printf "Could not find %s.\r",item
                else
                        Wave Sweep=$item
                        Spikes(w=sweep)
                  
                        SVar folder=root:last_spikes_folder
                        Wave Peaks=$(folder+":Peak_locs")
                        Variable sweep_num=str2num(StringFromList(i,range))
                       
                        SweepNums[i]=sweep_num
                        SpikeTimes[i]=Peaks[0]
                  	    SpikeInUpstate[i]=InUpstate((sweep_num-42)*10+SpikeTimes[i],UpstateOn,UpstateOff)
                endif
        endfor
        Edit /K=1 SweepNums,SpikeTimes,SpikeInUpstate
end

Function InUpstate(thyme,UpstateOn,UpstateOff)
	Variable thyme
	Wave UpstateOn,UpstateOff
	Variable i
	for(i=0;i<numpnts(UpstateOn);i+=1)
		if(thyme>UpstateOn[i] && thyme<UpstateOff[i])
			return 1
		endif
	endfor
	return 0
End

