// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Upstates.ipf $
// $Author: rick $
// $Rev: 616 $
// $Date: 2012-12-05 14:46:20 -0700 (Wed, 05 Dec 2012) $

#pragma rtGlobals=1		// Use modern global access method.

#include "Progress Window"

strconstant IMW_Folder_=""

// Colorizes them according to ISI (red shift equals short ISI, violet shift equals long ISI)
Function PlotUpStates(ibw[,align,left,right,path]) // Requires running Spikes() and UpstateLocations() first.  
	String ibw
	String align // Align up-states according to upstate onset.  [No other options implemented].  
	Variable left,right // The up-states will be displayed this many seconds to the left and right of the alignment point.  
	String path
	left=ParamIsDefault(left) ? 1 : left
	right=ParamIsDefault(right) ? 10 : right
	if(ParamIsDefault(path))
		path=StrVarOrDefault("root:parameters:random:dataDir","")
	endif
	String wave_name=LoadIBW(ibw,path=path)
	Wave w=$wave_name
	Wave UpstateOn,UpstateOff
	String graph_name=UniqueName(CleanUpName(wave_name,0),6,0)
	Display /K=1 /N=$graph_name
	Variable i,on,off
	for(i=0;i<numpnts(UpstateOn);i+=1)
		on=UpstateOn[i];off=UpstateOff[i]
		AppendToGraph w[x2pnt(w,on-left),x2pnt(w,off+right)] 
		ModifyGraph offset($TopTrace())={-on,0}
	endfor
	SetAxis bottom -left,right
	SetWindow $graph_name hook=WindowKillHook, userData="KillWave="+wave_name
	Textbox name
	Cursors()
	root()
End

// Makes a variant of UpstateDurations so that durations are calculated starting using 
// Begin and Finish (changes in membrane potential), rather than Start and End (first and last spike times).  
// Also makes a variant of UpstateSpikeRates using the same time points.  
Function UpstateDurations2()
	root()
	Variable i;String folder
	Wave /T FileName
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave UpstateDurations,UpstateFirstSpikes,UpstateLastSpikes,UpstateBegins,UpstateEnds			
			Duplicate /o UpstateDurations $("root:"+folder+":UpstateDurationsB"); Wave UpstateDurationsB
			Duplicate /o UpstateSpikeRates $("root:"+folder+":UpstateSpikeRatesB"); Wave UpstateSpikeRatesB
			UpstateDurationsB=UpstateEnds-UpstateBegins
			Wave UpstateSpikeCounts
			UpstateSpikeRatesB=IsNaN(UpstateEnds) ? 0 : UpstateSpikeCounts/UpstateDurationsB
		endif
	endfor
	root()
End

Function Upstates2()
	root()
	Variable i;String folder
	Wave /T FileName
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Upstates()
		endif
	endfor
	root()
End

Function DownstateDuration()
	root()
	Variable i,j;String folder
	Wave /T FileName
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave UpstateOn,UpstateOff
			Make /o/n=0 DownstateDurations
			for(j=0;j<numpnts(UpstateOn);j+=1)
				InsertPoints 0,1,DownstateDurations
				DownstateDurations[0]=UpstateOn[j]-UpstateOff[j-1]
			endfor
			Redimension /n=(numpnts(DownstateDurations)-1) DownstateDurations // Get rid of the first one, since the true value is unknown.  
			WaveTransform /O flip DownstateDurations
			NVar spikes_start,spikes_finish
			InsertPoints 0,1,DownstateDurations
			DownstateDurations[0]=UpstateOn[0]-spikes_start
			DownstateDurations[numpnts(DownstateDurations)-1]=spikes_finish-UpstateOff[numpnts(UpstateOff)-1]
		endif
	endfor
	root()
End

// Calculate upstate beginnings (by voltage measurements, not first spike time) for all the data.  
Function UpstateBegin2([path])
	String path
	
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
	
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0)
			UpstateBegin(ibw)
		endif
	endfor
	root()
	//KillPath IBWPath
End

// Calculate upstate ends (by voltage measurements, not last spike time) for all the data.  
Function UpstateEnd2([path])
	String path
	
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
	
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0)
			UpstateEnd(ibw)
		endif
	endfor
	root()
	//KillPath IBWPath
End

// Calculate upstate beginnings (by voltage measurements, not first spike time) for all the data.  
Function UpstateAHP2([path])
	String path
	
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
	
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0)
			UpstateAHP(ibw)
		endif
	endfor
	root()
	//KillPath IBWPath
End

// Calculate upstate beginnings (by voltage measurements, not first spike time) for all the data.  
Function UpstateLocationsVC2([path])
	String path
	
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
	
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	NewDataFolder /O root:Cells:VC
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+"_VC"+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0)
			UpstateLocationsVC(ibw=ibw,path=path)
		endif
	endfor
	root()
	//KillPath IBWPath
End

// Calculate upstate beginnings (by voltage measurements, not first spike time) for all the data.  
Function UpstateLocations2([path])
	String path
	
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
	
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		Prog("UpstateLocations",i,numpnts(FileName))
		ibw=FileName[i]+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0)
			//UpstateLocationsB(ibw=ibw) // Fixed threshold.  
			//UpstateLocations(ibw=ibw) // Original adaptive method.  
			NewUpstateLocs(ibw=ibw) // New adaptive method.  
		endif
	endfor
	root()
	//KillPath IBWPath
End

Function NewUpstateLocs([ibw,theWave])
	String ibw
	Wave theWave
	
	if(ParamIsDefault(theWave))
		// Get the signal.  
		if(ParamIsDefault(ibw))
			Wave theWave=CsrWaveRef(A)
			ibw=NameOfWave(theWave)
			String folder=CleanupName("U_"+GetWavesDataFolder(theWave,0)+"_"+NameOfWave(theWave),0)
			NewDataFolder /O/S root:$folder
		else
			Wave theWave=$LoadIBW(ibw) // Load the IBW and change the data folder.  
		endif
		Wave originalWave=theWave
	endif
	
	WaveStats /Q theWave
	if(V_numNaNs>0)
		printf "There are still NaNs in this wave: %s\r",NameOfWave(theWave)
	endif
	Resample /RATE=(analysisSamplingFreq) theWave
	LineRemove(theWave)
	if(StringMatch(ibw,"*Roger*") || StringMatch(ibw,"*Sonal*"))
		RemoveTestPulses(theWave,interval=10,preserve_spikes=1)
	else
		RemoveTestPulses(theWave,interval=30,preserve_spikes=1)
	endif
	
	AdaptiveThreshold(theWave,cmplx(2,2))
	Wave Ups,Downs
	Duplicate /o Ups ::UpstateOn /WAVE=UpstateOn
	Duplicate /o Downs ::UpstateOff /WAVE=UpstateOff
	KillWaves Ups,Downs
End

// Locate upstates using the ultimate method.  
Function UpstateLocationsVC([ibw,path])
	String ibw,path
	
	// Get the signal.  
	if(ParamIsDefault(ibw))
		Wave theWave=CsrWaveRef(A)
	else
		Wave theWave=$LoadIBW(ibw,path=path,type="VC") // Load the IBW and change the data folder.  
	endif
	Wave originalWave=theWave
	String name=NameOfWave(theWave)
	name=StringFromList(0,name,".")
	SetDataFolder root:Cells:VC:$name
	
	// Prepare the variables.  
	Make /o/n=0 UpstateOn,UpstateOff
	Variable i,j,x_value,on=0,on_for=0,off_for=0
	Variable sigma=20,bin_size=0.5,shift=0.1,on_time=bin_size+0.5,off_time=bin_size+0.5,min_V=5 
	// on_time and off_time would usually be twice the bin_size
	// This is because a transient big enough to pull the trigger would exist in bin_size/shift consecutive bins.  
	// By setting on_time and off_time equal to twice the bin_size, a transient has to be at least bin_size in width
	// to be in enough consecutive bins to be counted as the onset/offset of an upstate.  
	Variable mahal_cutoff=5
	
	// Downsample, remove 60 Hz, remove test pulses, remove NaNs, and high-pass filter the signal.  
	WaveStats /Q theWave
	if(V_numNaNs>0)
		printf "There are still NaNs in this wave: %s\r",NameOfWave(theWave)
	endif
	String ds_name=Downsample(theWave,10); Wave theWave=$ds_name
	RemoveTestPulses(theWave,interval=30,down=1,up=1)
	LineRemove(theWave)
	FilterFIR /HI={0.0015,0.015,101} theWave;//theWave*=-1
	theWave*=-1 // Because voltage clamp signals go downwards, this allows me to keep using a positive z-statistic cutoff.  
	//Bandpass(theWave,low=0.1,steep=0.1)
	if(ParamIsDefault(ibw))
		AppendToGraph /c=(0,0,65535) theWave
		ModifyGraph muloffset($NameOfWave(theWave))={0,-1}
	endif
	// Compute mean and standard deviation for each bin of the signal (determined by bin_size).  
	MeanStDevPlot(theWave,bin_size=bin_size,shift=shift,non_stationary=1,no_plot=1)
	//Duplicate /O Meann MeannBackup
	//Downsample(theWave,100); Wave theWave=theWaveFiltered_ds
	//Differentiate theWave /D=theWaveDiff; Wave theWaveDiff
	//MeanStDevPlot(theWaveDiff,bin_size=bin_size,shift=0.1,non_stationary=1,no_plot=1)
	//Duplicate /o theWave BinCenters; BinCenters=x
	String curr_folder=GetDataFolder(1)
	SetDataFolder root:MeanStDevPlot_F
	Wave Meann, StanDev, BinCenters
	SetDataFolder $curr_folder
	SetScale /P x,BinCenters[0],shift,Meann,StanDev,BinCenters
	//Wave Meann=MeannBackup, StanDev, BinCenters
	Duplicate /o BinCenters MahalDistances,ZMeans,ZStDevs
	
	// Determine the mean and standard deviation of two distributions.  One distribution is the mean value in each bin of noise (the downstate).  
	// The other is the standard deviation in each bin of noise.  
	String value,location1,location2
	value=ValueFromSignalAndNoise(Meann)
	Variable mean_xbar=NumFromList(0,value)
	Variable mean_sigma=NumFromList(1,value)
	value=ValueFromSignalAndNoise(StanDev)
	Variable stdev_xbar=NumFromList(0,value)
	Variable stdev_sigma=NumFromList(1,value)
	String location,center=num2str(mean_xbar)+";"+num2str(mean_sigma)
	String stdevs=num2str(stdev_xbar)+";"+num2str(stdev_sigma)
	Variable z_mean,z_stdev
	
	// Find significant values in the signal.  
	Variable mahal // A Mahalanobis distance of the data from the distribution of the noise in two dimensions (mean and standard deviation).  
	for(i=0;i<numpnts(BinCenters);i+=1)
		x_value=BinCenters[i]
		z_mean=(Meann[i]-mean_xbar)/mean_sigma
		z_stdev=(StanDev[i]-stdev_xbar)/stdev_sigma
		z_mean=z_mean>0 ? z_mean : 0
		z_stdev=z_stdev>0 ? z_stdev : 0
		mahal=sqrt(z_mean^2+z_stdev^2)
		ZMeans[i]=z_mean
		ZStDevs[i]=z_stdev
		MahalDistances[i]=mahal
		if(z_mean>-Inf && z_stdev>5 && on==0)
			on_for+=shift
			if(on_for>=on_time)
				InsertPoints 0,1,UpstateOn
				UpstateOn[0]=BinCenters[i-1]-on_time
				on=1
				on_for=0;off_for=0
			endif
		elseif(z_mean<3 && z_stdev<5 && on==1)
			off_for+=shift
			if(off_for>=off_time)
				InsertPoints 0,1,UpstateOff
				UpstateOff[0]=BinCenters[i-1]-off_time
				on=0
				on_for=0;off_for=0
			endif
		else
			on_for=0;off_for=0
		endif
	endfor
	WaveTransform /O flip,UpstateOn
	WaveTransform /O flip,UpstateOff
	i=0
//	Do
//		WaveStats /Q /R=(UpstateOn[i],UpstateOff[i]) theWaveFiltered
//		//Display /K=1 Filtered
//		if(V_max<min_V)
//			DeletePoints i,1,UpstateOn,UpstateOff
//		else
//			i+=1
//		endif
//	While(i<numpnts(UpstateOn))
	//Smooth 10,MahalDistances
//	Display /K=1 originalWave
//	AppendToGraph /c=(0,0,65535) theWaveFiltered
//	ZStDevs/=10 // For visualization
//	//MahalDistances/=10 // For visualization
//	WaveStats /Q theWaveFiltered; theWaveFiltered-=V_avg
//	AppendToGraph /c=(0,65535,0) ZMeans
//	AppendToGraph /c=(65535,0,65535) ZStDevs
	KillWaves /Z originalWave,theWave
	root()
End

// Locate upstates using the ultimate method.  
Function UpstateLocations([ibw,theWave])
	String ibw
	Wave theWave
	
	if(ParamIsDefault(theWave))
		// Get the signal.  
		if(ParamIsDefault(ibw))
			Wave theWave=CsrWaveRef(A)
			ibw=NameOfWave(theWave)
			String folder=CleanupName("U_"+GetWavesDataFolder(theWave,0)+"_"+NameOfWave(theWave),0)
			NewDataFolder /O/S root:$folder
		else
			Wave theWave=$LoadIBW(ibw) // Load the IBW and change the data folder.  
		endif
		Wave originalWave=theWave
	else
		ibw=NameOfWave(theWave)
	endif
		
	// Prepare the variables.  
	Make /o/n=0 UpstateOn,UpstateOff
	Variable i,j,x_value,on=0,on_for=0,off_for=0
	Variable bin_size=0.5,shift=0.1,on_time=bin_size+0.5,off_time=bin_size+0.5
	// on_time and off_time would usually be twice the bin_size
	// This is because a transient big enough to pull the trigger would exist in bin_size/shift consecutive bins.  
	// By setting on_time and off_time equal to twice the bin_size, a transient has to be at least bin_size in width
	// to be in enough consecutive bins to be counted as the onset/offset of an upstate.  
	//Variable mahal_cutoff=5,sigma=20,min_V=5
	
	// Downsample, remove 60 Hz, remove test pulses, and high-pass filter the signal.  
	WaveStats /Q theWave
	if(V_numNaNs>0)
		printf "There are still NaNs in this wave: %s.\r",NameOfWave(theWave)
	endif
	String ds_name=Downsample(theWave,10); Wave theWave=$ds_name
	LineRemove(theWave)
	if(StringMatch(ibw,"*Roger*") || StringMatch(ibw,"*Sonal*"))
		RemoveTestPulses(theWave,interval=10,preserve_spikes=1)
	else
		RemoveTestPulses(theWave,interval=30,preserve_spikes=1)
	endif
	FilterFIR /HI={0.002,0.02,101} theWave; theWave*=-1
	//AppendToGraph /c=(65535,0,65535) theWave
	//Display /K=1 originalWave,theWave
	//Bandpass(theWave,low=0.1,steep=0.1)
	
	// Compute mean and standard deviation for each bin of the signal (determined by bin_size).  
	MeanStDevPlot(theWave,bin_size=bin_size,shift=shift,non_stationary=1,no_plot=1)
	
	//abort
	//Duplicate /O Meann MeannBackup
	//Downsample(theWave,100); Wave theWave=theWaveFiltered_ds
	//Differentiate theWave /D=theWaveDiff; Wave theWaveDiff
	//MeanStDevPlot(theWaveDiff,bin_size=bin_size,shift=0.1,non_stationary=1,no_plot=1)
	//Duplicate /o theWave BinCenters; BinCenters=x
	String curr_folder=GetDataFolder(1)
	SetDataFolder root:MeanStDevPlot_F
	Wave Meann, StanDev, BinCenters
	SetDataFolder $curr_folder
	SetScale /P x,BinCenters[0],shift,Meann,StanDev,BinCenters
	//Wave Meann=MeannBackup, StanDev, BinCenters
	Duplicate /o BinCenters MahalDistances,ZMeans,ZStDevs
	
	// Determine the mean and standard deviation of two distributions.  One distribution is the mean value in each bin of noise (the downstate).  
	// The other is the standard deviation in each bin of noise.  
	String value,location1,location2
	value=ValueFromSignalAndNoise(Meann)
	Variable mean_xbar=NumFromList(0,value)
	Variable mean_sigma=NumFromList(1,value)
	value=ValueFromSignalAndNoise(StanDev)
	Variable stdev_xbar=NumFromList(0,value)
	Variable stdev_sigma=NumFromList(1,value)
	String location,center=num2str(mean_xbar)+";"+num2str(mean_sigma)
	String stdevs=num2str(stdev_xbar)+";"+num2str(stdev_sigma)
	Variable z_mean,z_stdev
	
	// Find significant values in the signal.  
	Variable mahal // A Mahalanobis distance of the data from the distribution of the noise in two dimensions (mean and standard deviation).  
	for(i=0;i<numpnts(BinCenters);i+=1)
		x_value=BinCenters[i]
		z_mean=(Meann[i]-mean_xbar)/mean_sigma
		z_stdev=(StanDev[i]-stdev_xbar)/stdev_sigma
		z_mean=z_mean>0 ? z_mean : 0
		z_stdev=z_stdev>0 ? z_stdev : 0
		mahal=sqrt(z_mean^2+z_stdev^2)
		ZMeans[i]=z_mean
		ZStDevs[i]=z_stdev
		MahalDistances[i]=mahal
		if(z_mean>1 && z_stdev>3 && on==0)
			on_for+=shift
			if(on_for>=on_time)
				InsertPoints 0,1,UpstateOn
				UpstateOn[0]=BinCenters[i-1]-on_time
				on=1
				on_for=0;off_for=0
			endif
		elseif(z_mean<3 && z_stdev<5 && on==1)
			off_for+=shift
			if(off_for>=off_time)
				InsertPoints 0,1,UpstateOff
				UpstateOff[0]=BinCenters[i-1]-off_time
				on=0
				on_for=0;off_for=0
			endif
		else
			on_for=0;off_for=0
		endif
	endfor
	WaveTransform /O flip,UpstateOn
	WaveTransform /O flip,UpstateOff
	CopyScales Meann ZMeans
	CopyScales StanDev ZStDevs
	i=0
//	Do
//		WaveStats /Q /R=(UpstateOn[i],UpstateOff[i]) theWaveFiltered
//		//Display /K=1 Filtered
//		if(V_max<min_V)
//			DeletePoints i,1,UpstateOn,UpstateOff
//		else
//			i+=1
//		endif
//	While(i<numpnts(UpstateOn))
	//Smooth 10,MahalDistances
//	Display /K=1 originalWave
//	AppendToGraph /c=(0,0,65535) theWaveFiltered
//	ZStDevs/=10 // For visualization
//	//MahalDistances/=10 // For visualization
//	WaveStats /Q theWaveFiltered; theWaveFiltered-=V_avg
//	AppendToGraph /c=(0,65535,0) ZMeans
//	AppendToGraph /c=(65535,0,65535) ZStDevs
	KillWaves /Z originalWave,theWave
	root()
End

// Shitty fixed threshold.  
Function UpstateLocationsB([ibw,theWave])
	String ibw
	Wave theWave
	
	if(ParamIsDefault(theWave))
		// Get the signal.  
		if(ParamIsDefault(ibw))
			Wave theWave=CsrWaveRef(A)
			ibw=NameOfWave(theWave)
		else
			Wave theWave=$LoadIBW(ibw) // Load the IBW and change the data folder.  
		endif
		Wave originalWave=theWave
	else
		ibw=NameOfWave(theWave)
	endif
		
	// Prepare the variables.  
	Make /o/n=0 UpstateOn,UpstateOff
	Variable i,j,x_value,on=0,on_for=0,off_for=0
	Variable bin_size=0.5,shift=0.1,on_time=bin_size+0.5,off_time=bin_size+0.5
	// on_time and off_time would usually be twice the bin_size
	// This is because a transient big enough to pull the trigger would exist in bin_size/shift consecutive bins.  
	// By setting on_time and off_time equal to twice the bin_size, a transient has to be at least bin_size in width
	// to be in enough consecutive bins to be counted as the onset/offset of an upstate.  
	//Variable mahal_cutoff=5,sigma=20,min_V=5
	
	// Downsample, remove 60 Hz, remove test pulses, and high-pass filter the signal.  
	WaveStats /Q theWave
	if(V_numNaNs>0)
		printf "There are still NaNs in this wave: %s\r",NameOfWave(theWave)
	endif
	String ds_name=Downsample(theWave,10); Wave theWave=$ds_name
	LineRemove(theWave)
	if(StringMatch(ibw,"*Roger*") || StringMatch(ibw,"*Sonal*"))
		RemoveTestPulses(theWave,interval=10,preserve_spikes=1)
	else
		RemoveTestPulses(theWave,interval=30,preserve_spikes=1)
	endif
	FilterFIR /HI={0.002,0.02,101} theWave; theWave*=-1
	
	String curr_folder=GetDataFolder(1)
	
	MeanStDevPlot(theWave,bin_size=bin_size,shift=shift,non_stationary=1,no_plot=1)
	
	SetDataFolder root:MeanStDevPlot_F
	Wave Meann, StanDev, BinCenters
	SetDataFolder $curr_folder

	Variable baseline=StatsMedian(theWave)
	// Find significant values in the signal.  
	Variable mahal // A Mahalanobis distance of the data from the distribution of the noise in two dimensions (mean and standard deviation).  
	for(i=0;i<numpnts(BinCenters);i+=1)
		x_value=BinCenters[i]
		if(Meann[i]>(Baseline+1) && on==0)
			on_for+=shift
			if(on_for>=on_time)
				InsertPoints 0,1,UpstateOn
				UpstateOn[0]=BinCenters[i-1]-on_time
				on=1
				on_for=0;off_for=0
			endif
		elseif(Meann[i]<(Baseline+1) && on==1)
			off_for+=shift
			if(off_for>=off_time)
				InsertPoints 0,1,UpstateOff
				UpstateOff[0]=BinCenters[i-1]-off_time
				on=0
				on_for=0;off_for=0
			endif
		else
			on_for=0;off_for=0
		endif
	endfor
	WaveTransform /O flip,UpstateOn
	WaveTransform /O flip,UpstateOff
	i=0
//	Do
//		WaveStats /Q /R=(UpstateOn[i],UpstateOff[i]) theWaveFiltered
//		//Display /K=1 Filtered
//		if(V_max<min_V)
//			DeletePoints i,1,UpstateOn,UpstateOff
//		else
//			i+=1
//		endif
//	While(i<numpnts(UpstateOn))
	//Smooth 10,MahalDistances
//	Display /K=1 originalWave
//	AppendToGraph /c=(0,0,65535) theWaveFiltered
//	ZStDevs/=10 // For visualization
//	//MahalDistances/=10 // For visualization
//	WaveStats /Q theWaveFiltered; theWaveFiltered-=V_avg
//	AppendToGraph /c=(0,65535,0) ZMeans
//	AppendToGraph /c=(65535,0,65535) ZStDevs
	KillWaves /Z originalWave,theWave
	root()
End

Function GraphUpstates()
	Wave UpstateOn,UpstateOff
	String ug_name=CleanUpName("X"+CsrWave(A)+"UpstateGraph",0)
	Duplicate /o CsrWaveRef(A) $ug_name
	Wave UpstateGraph=$ug_name
	UpstateGraph=-50
	Variable i,on,off
	for(i=0;i<numpnts(UpstateOn);i+=1)
		on=x2pnt(UpstateGraph,UpstateOn[i])
		off=x2pnt(UpstateGraph,UpstateOff[i])
		UpstateGraph[on,off]=0
	endfor
	String traces=TraceNameList("",";",3)
	if(WhichListItem(ug_name,traces)<=0)
		AppendToGraph /c=(0,0,65535) UpstateGraph
	endif
End

Function GraphUpstates2()
	String win_list=WinList("*",";","WIN:1")
	Variable i
	for(i=0;i<ItemsInList(win_list);i+=1)
		String win=StringFromList(i,win_list)
		DoWindow /F $win
		UpstateLocations(); GraphUpstates()
	endfor
End


Function UpstateStats2([path])
	String path
	
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
	
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		Prog("X",i,numpnts(FileName))
		ibw=FileName[i]+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0)
			UpstateStats(ibw=ibw)
		endif
	endfor
	root()
	//KillPath IBWPath
End

Function UpstateStatsVC2([path])
	String path
	
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
	
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+"_VC"+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0)
			UpstateStatsVC(ibw=ibw,path=path)
		endif
	endfor
	root()
	//KillPath IBWPath
End

Function UpstateStats([ibw,path])
	String ibw
	String path

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
	
	// Get the signal.  
	if(ParamIsDefault(ibw))
		Wave theWave=CsrWaveRef(A)
		String folder=CleanupName("U_"+GetWavesDataFolder(theWave,0)+"_"+NameOfWave(theWave),0)
		NewDataFolder /O/S root:$folder
	else
		Wave theWave=$LoadIBW(ibw,path=path) // Load the IBW and change the data folder.  
		printf "Loaded %s.\r",NameOfWave(theWave)
	endif
	//Wave originalWave=theWave
	Wave UpstateOn,UpstateOff
	DFRef f=root:$CleanUpName("Spikes_"+GetWavesDataFolder(theWave,0)+"_"+NameOfWave(theWave),0)
	Wave /Z Peak_Locs
	if(!WaveExists(Peak_Locs))
		Wave /Z Peak_Locs=f:Peak_Locs
	endif
	if(!WaveExists(Peak_Locs))
		DoAlert 0,"Must run Spikes() first."
		return -1
	endif
	Variable num_upstates=min(numpnts(UpstateOn),numpnts(UpstateOff))
	Variable i,on,off,areaa,baseline
	Make /o/n=(num_upstates) U_Durations,U_Spikes,U_Areas,U_Averages,U_Intervals,U_SpikeRates
	Make /o/n=1 U_UpstateFreq
	for(i=0;i<num_upstates;i+=1)
		on=UpstateOn[i]; off=UpstateOff[i]
		U_Durations[i]=off-on
		U_Spikes[i]=NumBetween(Peak_Locs,on-0.25,off+0.25)
		WaveStats /Q/R=(on-1.25,on-0.25) theWave; baseline=V_avg
		WaveStats /Q/R=(on,off) theWave; 
		U_Averages[i]=(V_avg-baseline)
		U_Areas[i]=U_Averages[i]*(off-on)
		U_Intervals[i]=UpstateOn[i]-UpstateOff[i-1]
	endfor
	U_SpikeRates=U_Spikes/U_Durations
	U_Intervals[0]=NaN
	//NVar spikes_start,spikes_finish
	U_UpstateFreq=num_upstates/WaveDuration(theWave)//(spikes_finish-spikes_start) //Brett comments this out, don't use spikes_start, spikes_finish
		
	// Downstate Noise
	Make /o/n=0 D_Noise,D_NoiseNS
	Wave originalWave=theWave
	Wave theWave2=$Downsample(theWave,50)
	Wave theWave=theWave2
	Duplicate /o UpstateOn,U_On; InsertPoints numpnts(U_On),1,U_On; U_On[numpnts(U_On)-1]=rightx(theWave)-1
	Duplicate /o UpstateOn,U_Off; InsertPoints 0,1,U_off; U_Off[0]=leftx(theWave)+1
	for(i=0;i<num_upstates+1;i+=1)
		off=U_Off[i]; on=U_On[i]
		if(off<on-2)
			Duplicate /o /R=(off+0.25,on-0.25) theWave Segment
			// Remove spikes
			Do
				WaveStats /Q Segment
				if(V_max>-10)
					DeletePoints x2pnt(Segment,V_maxloc-0.25),0.5/dimdelta(theWave,0),Segment
				endif
			While(V_max>-10)
			//
			Differentiate Segment /D=DiffSegment; WaveStats /Q DiffSegment; Variable noise_ns=V_sdev/sqrt(2) // Non-stationary noise of signal
			FilterFIR /HI={0.001,0.01,101} Segment ; WaveStats /Q Segment; Variable noise=V_sdev // Noise of high-pass filtered signal
			InsertPoints 0,1,D_Noise,D_NoiseNS
			D_Noise[0]=noise
			D_NoiseNS[0]=noise_ns
		endif
	endfor
	
	KillWaves /Z U_On,U_Off,Segment,DiffSegment,theWave,theWave2,originalWave
End

Function UpstateStatsVC([ibw,path])
	String ibw
	String path

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
	
	// Get the signal.  
	if(ParamIsDefault(ibw))
		Wave theWave=CsrWaveRef(A)
	else
		Wave theWave=$LoadIBW(ibw,path=path,type="VC") // Load the IBW and change the data folder.  
	endif
	Downsample(theWave,10,in_place=1)
	RemoveTestPulses(theWave,interval=30,up=1,down=1)
	//Wave originalWave=theWave
	Wave UpstateOn,UpstateOff
	Variable num_upstates=min(numpnts(UpstateOn),numpnts(UpstateOff))
	Variable i,on,off,areaa,baseline,noise
	Make /o/n=(num_upstates) U_Durations,U_Areas,U_Averages,U_Intervals
	Make /o/n=1 U_UpstateFreq
	for(i=0;i<num_upstates;i+=1)
		on=UpstateOn[i]; off=UpstateOff[i]
		U_Durations[i]=off-on
		WaveStats /Q/R=(on-1.25,on-0.25) theWave; baseline=V_avg
		WaveStats /Q/R=(on,off) theWave; 
		U_Averages[i]=(V_avg-baseline)
		U_Areas[i]=U_Averages[i]*(off-on)
		U_Intervals[i]=UpstateOn[i]-UpstateOff[i-1]
	endfor
	U_Intervals[0]=NaN
	U_UpstateFreq=num_upstates/(WaveDuration(theWave))
	
	Downsample(theWave,5,in_place=1)
	// Downstate Noise
	Make /o/n=0 D_Noise,D_NoiseNS,D_Skew,D_SkewNS
	Duplicate /o UpstateOn,U_On; InsertPoints numpnts(U_On),1,U_On; U_On[numpnts(U_On)-1]=rightx(theWave)-1
	Duplicate /o UpstateOn,U_Off; InsertPoints 0,1,U_off; U_Off[0]=leftx(theWave)+1
	for(i=0;i<num_upstates+1;i+=1)
		off=U_Off[i]; on=U_On[i]
		if(off<on-2)
			Duplicate /o /R=(off+0.25,on-0.25) theWave Segment
			Differentiate Segment /D=DiffSegment; WaveStats /Q DiffSegment; noise=V_sdev/sqrt(2) // Non-stationary noise of signal
			InsertPoints 0,1,D_NoiseNS,D_SkewNS
			D_NoiseNS[0]=noise
			D_SkewNS[0]=V_skew
			FilterFIR /HI={0.001,0.01,101} Segment; WaveStats /Q Segment; noise=V_sdev // Noise of high-pass filtered signal
			InsertPoints 0,1,D_Noise,D_Skew
			D_Noise[0]=noise
			D_Skew[0]=V_skew
		endif
	endfor
	
	// Upstate Noise
	Make /o/n=0 U_Noise,U_NoiseNS
	for(i=0;i<num_upstates;i+=1)
		off=UpstateOn[i]; on=UpstateOff[i]
		if(off<on-2)
			Duplicate /o /R=(off+0.25,on-0.25) theWave Segment
			Differentiate Segment /D=DiffSegment; WaveStats /Q DiffSegment; noise=V_sdev/sqrt(2) // Non-stationary noise of signal
			InsertPoints 0,1,U_NoiseNS
			U_NoiseNS[0]=noise
			FilterFIR /HI={0.001,0.01,101} Segment; WaveStats /Q Segment; noise=V_sdev // Noise of high-pass filtered signal
			InsertPoints 0,1,U_Noise
			U_Noise[0]=noise
		endif
	endfor
	
	KillWaves /Z U_On,U_Off,Segment,DiffSegment,theWave
End

Function InsertSpikeLessUpstates2()
	root()
	Variable i; String folder,slus_starts
	Wave /T FileName,SpikeLessUpstateStarts
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		slus_starts=SpikeLessUpstateStarts[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			InsertSpikeLessUpstates(slus_starts)
		endif
	endfor
	root()
End

Function InsertSpikeLessUpstates(slus_starts)
	String slus_starts
	NVar spikes_start,spikes_finish
	Wave UpstateFirstSpikes,UpstateLastSpikes,UpstateBegins,UpstateEnds,UpstateIntervals
	Wave UpstateFirstSpikeIndices,UpstateDurations,UpstateSpikeCounts,UpstateSpikeRates,UpstateSpikeTimes,UpstateRate
	Duplicate /o UpstateBegins UpstateBeginsBackup // Since UpstateBegins is time intensive to calculate.  
	Duplicate /o UpstateEnds UpstateEndsBackup // Since UpstateEnds is time intensive to calculate.  
	Variable j,thyme,loc;
	if(!StringMatch(slus_starts,"[NULL]") && !StringMatch(slus_starts,";"))
		for(j=0;j<ItemsInList(slus_starts);j+=1)
			thyme=NumFromList(j,slus_starts)
			loc=BinarySearch2(UpstateBegins,thyme)
			InsertPoints loc,1,UpstateFirstSpikes,UpstateLastSpikes,UpstateBegins,UpstateEnds,UpstateIntervals
			InsertPoints loc,1,UpstateFirstSpikeIndices,UpstateDurations,UpstateSpikeCounts,UpstateSpikeRates
			InsertPoints /M=1 loc,1,UpstateSpikeTimes
			UpstateBegins[loc]=thyme
			UpstateEnds[loc]=NaN
			UpstateFirstSpikes[loc]=NaN
			UpstateLastSpikes[loc]=NaN
			if(loc>0)
				UpstateIntervals[loc]=thyme-UpstateBegins[loc-1]
			else
				UpstateIntervals[loc]=NaN
			endif
			if(loc<numpnts(UpstateIntevals)-1)
				UpstateIntervals[loc+1]=UpstateBegins[loc+1]-thyme
			endif
			UpstateFirstSpikeIndices[loc]=NaN
			UpstateDurations[loc]=0
			UpstateSpikeCounts[loc]=0
			UpstateSpikeRates[loc]=0
			UpstateSpikeTimes[][loc]=NaN
		endfor
		UpstateRate=numpnts(UpstateBegins)/(spikes_finish-spikes_start)
	endif
End

Function UpstateBeginChunks(ibw)
	String ibw
	LoadWave /P=IBWPath ibw
	ibw=S_filename
	String loaded_name=StringFromList(0,S_Wavenames)
	String name=ibw[0,strlen(ibw)-5] // Remove ".ibw"
	Duplicate /o $loaded_name $("root:"+name+":"+name)
	KillWaves $loaded_name
	SetDataFolder root:Cells:$name
	Wave theWave=$name
	Wave UpstateBegins
	Display /K=1 /N=$("UpstateBegins_"+name)
	Variable i
	for(i=0;i<numpnts(UpstateBegins);i+=1)
		AppendToGraph theWave[x2pnt(theWave,UpstateBegins[i]-3),x2pnt(theWave,UpstateBegins[i]+5)]
		ModifyGraph offset($TopTrace())={-UpstateBegins[i],0}
	endfor
	SetAxis bottom -3,5
	//DoWindow /K $TopWindow()
	//KillWaves $name
	SetDataFolder root:
End

// Makes a histogram triggered to the first spike of the upstate.  
Function UpstateSpikeHistogram()
	Variable left=-2,right=10
	Variable bin_size=0.01 // Bin size in seconds
	Wave UpstateSpikeTimes,UpstateFirstSpikes,UpstateSpikeCounts
	Duplicate /o UpstateSpikeTimes UpstateSpikeTimesRFS // Upstate Spike Times relative to the first spike.  
	UpstateSpikeTimesRFS-=UpstateFirstSpikes[q]
	KillWaves /Z UpstateSpikeHist
	Variable i,subtract=0
	if(numpnts(UpstateFirstSpikes)>0)
		Make /o/n=(1+right/bin_size) UpstateSpikeHist=0; Wave Hist=UpstateSpikeHist
		SetScale /I x,0,right,Hist
		Histogram /B=2 UpstateSpikeTimesRFS,Hist
		for(i=0;i<numpnts(UpstateSpikeCounts);i+=1)
			if(UpstateSpikeCounts[i]>1)
				subtract+=1 // If there was a spike, we will need to subtract it off since the first spike cannot be part of the histrogram
				// when defining an upstate as the onset of a spike.  
			endif
		endfor
		Hist[0]-=subtract
		Hist*=(1/(bin_size*numpnts(UpstateFirstSpikes))) // Convert to an average firing rate
	endif
End

// Uses UpstateBegins (continuous beginnings, not first spike)
Function UpstateSpikeHistogramB() 
	Variable left=-2,right=10
	Variable bin_size=0.05 // Bin size in seconds
	Wave UpstateSpikeTimes,UpstateBegins,UpstateDurationsB
	Duplicate /o UpstateSpikeTimes UpstateSpikeTimesRMP // Upstate Spike Times relative to the membrane potential onset of the upstate.  
	UpstateSpikeTimesRMP-=UpstateBegins[q]
	KillWaves /Z UpstateSpikeHist
	Variable i,num=0
	if(numpnts(UpstateBegins)>0)
		Make /o/n=(1+right/bin_size) UpstateSpikeHist=0; Wave Hist=UpstateSpikeHist
		SetScale /I x,0,right,Hist
		Histogram /B=2 UpstateSpikeTimesRMP,Hist
		Hist*=(1/(bin_size*numpnts(UpstateBegins))) // Convert to an average firing rate
	endif
End

// Uses UpstateBegins (continuous beginnings, not first spike)
Function UpstateSpikeHistogramBest([mode])
	Variable mode // Mode 0 provides columns for each Upstate; Mode 1 just puts all spike times in one big column.   
	Variable i,j,on,off,spike_time
	Wave UpstateOn,UpstateOff,Peak_Locs
	Make /o/n=0 U_SpikeTimes
	for(i=0;i<numpnts(UpstateOn);i+=1)
		on=UpstateOn[i]; off=UpstateOff[i]
		Make /o/n=0 USHB_temp
		for(j=0;j<numpnts(Peak_Locs);j+=1)
			spike_time=Peak_Locs[j]
			if(spike_time>on && spike_time<off)
				InsertPoints 0,1,USHB_temp
				USHB_temp[0]=spike_time-on
			endif
		endfor
		if(mode==0)
			Concatenate /NP {USHB_temp},U_SpikeTimes
		elseif(mode==1)
			Concatenate {USHB_temp},U_SpikeTimes
		endif
	endfor
	KillWaves /Z USHB_temp
	Variable left=0,right=10,bin_size=0.1
	if(numpnts(UpstateOn)>0)
		Make /o/n=(1+(right-left)/bin_size) U_SpikeHistogram=0; Wave Hist=U_SpikeHistogram
		SetScale /I x,left,right,Hist
		if(numpnts(U_SpikeTimes)>0)
			Histogram /B=2 U_SpikeTimes,Hist
		endif
		Hist*=(1/(bin_size*numpnts(UpstateOn))) // Convert to an average firing rate
	endif
End

Function UpstateSpikeHistogramBest2([method,conditions])
	Variable method // 0 to concatentate all upstate spike times into a cell-independent histogram, 1 to honor the histograms constructed for individual cells.  
	String conditions
	root()
	Variable i,j,flag=0;
	if(ParamIsDefault(conditions))
		conditions="Control,None;Control,Paxilline;Control,Iberiotoxin;Seizure,None;Seizure,Paxilline;Seizure,Iberiotoxin;"
	endif
	String curr_folder=GetDataFolder(1)
	root()
	Wave /T FileName,Condition,BathDrug
	String dest_folder=UniqueName("USHB2",11,0)
	NewDataFolder /O/S $dest_folder
	dest_folder=GetDataFolder(1)
	Make /o/n=(ItemsInList(conditions)) ConditionCounts=0
	for(i=0;i<numpnts(FileName);i+=1)
		String folder="root:Cells:"+FileName[i]
		String condition_str=Condition[i]+","+BathDrug[i]
		String condition_str2=CleanUpName(condition_str,0)
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			UpstateSpikeHistogramBest()
			if(waveexists(U_SpikeHistogram))
				Wave U_SpikeHistogram
				if(!flag)
					for(j=0;j<ItemsInList(conditions);j+=1)
						condition_str=StringFromList(j,conditions)
						condition_str2=CleanUpName(condition_str,0)
						Duplicate /o U_SpikeHistogram $(dest_folder+condition_str2+"_U_SpikeHist") /wave=ConditionHist
						ConditionHist=0
						if(method==0)
							Make /o/n=0 $(dest_folder+condition_str2+"_U_SpikeT")
						endif
						WaveClear ConditionHist
					endfor
					flag=1
				endif
				condition_str=Condition[i]+","+BathDrug[i]
				condition_str2=CleanUpName(condition_str,0)
				if(WhichListItem(condition_str,conditions)<0)
					continue
				endif
				Wave ConditionHist=$(dest_folder+condition_str2+"_U_SpikeHist")
				if(method==0)
					Wave U_SpikeTimes
					Wave ConditionSpikeTimes=$(dest_folder+condition_str2+"_U_SpikeT")
					Concatenate /NP {U_SpikeTimes}, ConditionSpikeTimes
					ConditionCounts[WhichListItem(condition_str,conditions)]+=numpnts(UpstateOn)
				elseif(method==1)
					ConditionHist+=U_SpikeHistogram
					ConditionCounts[WhichListItem(condition_str,conditions)]+=1
				endif
			endif
		endif
	endfor
	root()
	Display /K=1
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		condition_str2=CleanUpName(condition_str,0)
		Wave ConditionHist=$(dest_folder+condition_str2+"_U_SpikeHist")
		if(method==0)
			Wave ConditionSpikeTimes=$(dest_folder+condition_str2+"_U_SpikeT")
			Histogram /B=2 ConditionSpikeTimes,ConditionHist
			ConditionHist/=dimdelta(ConditionHist,0) // Convert to a firing rate.  
		endif
		ConditionHist/=ConditionCounts[i]
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) ConditionHist
		//Duplicate /o ConditionHist $(dest_folder+condition_str+"_UpstateSpikeHistError")
		//Wave ConditionError=$(dest_folder+condition_str+"_UpstateSpikeHistError")
		//for(j=0;j<numpnts(ConditionHist);j+=1)
		//	ConditionError=(ConditionHist*ConditionCounts[i])*(1-ConditonHist*ConditionCounts[i])
		//endfor
	endfor
	Label left "Firing Rate (Hz)"
	Label bottom "Time (s)"
	KillVariables /Z red,green,blue
	SetAxis bottom -1,10
End

// Make a PSTH for upstates for each condition, using the average PSTH for each cell, and then averaging them together.   
Function UpstateSpikeHistogram2(method)
	String method
	root()
	Variable i,j;String folder,condition_str,conditions="Control;Seizure"
	Wave /T FileName,Condition
	Make /o/n=(ItemsInList(conditions)) ConditionCounts=0
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			strswitch(method)
				case "First Spike":
					UpstateSpikeHistogram()
					break
				case "Membrane Potential":
					UpstateSpikeHistogramB()
					break
				default:
					printf "Not a valid method [UpstateSpikeHistogam2].\r"
					abort
					break
			endswitch
			if(waveexists(UpstateSpikeHist))
				Wave UpstateSpikeHist
				if(i==0)
					for(j=0;j<ItemsInList(conditions);j+=1)
						condition_str=StringFromList(j,conditions)
						Duplicate /o UpstateSpikeHist root:$(condition_str+"UpstateSpikeHist")
						Wave ConditionHist=root:$(condition_str+"UpstateSpikeHist")
						ConditionHist=0
					endfor
				endif
				condition_str=Condition[i]
				Wave ConditionHist=root:$(condition_str+"UpstateSpikeHist")
				ConditionHist+=UpstateSpikeHist
				ConditionCounts[WhichListItem(condition_str,conditions)]+=1
			endif
		endif
	endfor
	root()
	Display /K=1
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave ConditionHist=root:$(condition_str+"UpstateSpikeHist")
		ConditionHist/=ConditionCounts[i]
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) ConditionHist
	endfor
	KillVariables /Z red,green,blue
	SetAxis bottom 0,10
End

// Make a PSTH for upstates for each condition, treating all upstates independently and making a PSTH for each condition.   
Function UpstateSpikeHistogram3(method)
	String method
	Variable left=-2,right=10
	Variable bin_size=0.05 // Bin size in seconds
	root()
	Variable i,j;String folder,condition_str,conditions="Control;Seizure"
	Wave /T FileName,Condition
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Make /o/n=0 $("root:UpstateSpikeTimesRel_"+condition_str)
	endfor
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			strswitch(method)
				case "First Spike":
					UpstateSpikeHistogram()
					Wave UpstateSpikeTimesRel=UpstateSpikeTimesRFS
					break
				case "Membrane Potential":
					UpstateSpikeHistogramB()
					Wave UpstateSpikeTimesRel=UpstateSpikeTimesRMP
					break
				default:
					printf "Not a valid method [UpstateSpikeHistogam2].\r"
					abort
					break
			endswitch
			Wave USTR=$("root:UpstateSpikeTimesRel_"+condition_str)
			Concatenate {UpstateSpikeTimesRel}, USTR
		endif
	endfor
	root()
	Display /K=1
	Variable num_upstates
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave USTR=$("root:UpstateSpikeTimesRel_"+condition_str)
		num_upstates=dimsize(USTR,1)
		Make /o/n=(1+right/bin_size) root:$(condition_str+"UpstateSpikeHist")
		Wave ConditionHist=root:$(condition_str+"UpstateSpikeHist")
		SetScale /I x,0,right,ConditionHist
		Histogram /B=2 USTR,ConditionHist
		ConditionHist*=(1/(bin_size*num_upstates)) // Convert to an average firing rate
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) ConditionHist
	endfor
	KillVariables /Z red,green,blue
	SetAxis bottom 0,10
End


// Plots the ISI vs the time since that start of the upstate (measured as the first spike in the upstate)
Function ISIvsUpstateTime()
	root()
	Variable i,j,k,temp;String folder,condition_str,conditions="Control;Seizure"
	Wave /T FileName,Condition
	Make /o/n=(ItemsInList(conditions)) ConditionCounts=0
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Make /o/n=0 root:$(condition_str+"ISIinUpstate")=0
		Make /o/n=0 root:$(condition_str+"UpstateSpikeTime")=0
	endfor
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		Wave ISIinUpstate=root:$(condition_str+"ISIinUpstate")
		Wave UpstateSpikeTime=root:$(condition_str+"UpstateSpikeTime")
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave UpstateSpikeTimes,UpstateFirstSpikes
			for(j=0;j<dimsize(UpstateSpikeTimes,1);j+=1)
				for(k=1;k<dimsize(UpstateSpikeTimes,0);k+=1)
					if(IsNaN(UpstateSpikeTimes[k][j]))
						break
					else
						InsertPoints 0,1,ISIinUpstate,UpstateSpikeTime
						ISIinUpstate[0]=UpstateSpikeTimes[k][j]-UpstateSpikeTimes[k-1][j]
						UpstateSpikeTime[0]=UpstateSpikeTimes[k][j]-UpstateFirstSpikes[j]
					endif
				endfor
			endfor
		endif
	endfor
	root()
	Display /K=1
	Variable left=-2,right=10
	Variable bin_size=0.1 // Bin size in seconds
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave ISIinUpstate=root:$(condition_str+"ISIinUpstate")
		Wave UpstateSpikeTime=root:$(condition_str+"UpstateSpikeTime")
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) ISIinUpstate vs UpstateSpikeTime
	endfor
	KillVariables /Z red,green,blue
	//SetAxis bottom 0,10
End


Function UpstateWaveforms([path,folder,clamp,show_all])
	String path,folder,clamp
	Variable show_all // Show all of them (superimposed) instead of just the average.  
	if(ParamIsDefault(clamp) || StringMatch(clamp,"CC"))
		clamp=""
	endif
	
	// Determine a path.  
	if(StringMatch(clamp,"VC"))
		String pathName="IBWVCpath"
	else
		pathName="IBWpath"
	endif
	root()
	PathInfo $pathName
		if(!ParamIsDefault(path))
		NewPath /O/Q $pathName,path
	elseif(!strlen(S_path))
		NewPath /O/Q $pathName
	endif
	PathInfo $pathName
	path=S_path
	
	if(ParamIsDefault(folder))
		folder="root:Cells"
	endif
	
	String clamp2=clamp
	if(!IsEmptyString(clamp))
		folder+=":"+clamp+":"
		clamp="_"+clamp
	else
		folder+=":"
	endif
	root()
	Wave /T FileName,Condition
	String name,condition_str,conditions="Control;Seizure",upstate_name
	Variable i,j,on,off,temp,interval,flag=0
	Make /o/n=(ItemsInList(conditions)) ConditionCounts=0; Wave ConditionCounts
	
	Display /N=$("AverageUpstate"+clamp)
	for(i=0;i<numpnts(FileName);i+=1)
		name=FileName[i]
		root()
		if(DataFolderExists(folder+name+clamp))
			name=LoadIBW(name+clamp,path=path,type=clamp2)
			Wave theWave=$name
			if(StringMatch(name,"*Roger*") || StringMatch(name,"*Sonal*"))
				interval=10
			else
				interval=30
			endif
			RemoveTestPulses(theWave,interval=10,preserve_spikes=1,up=StringMatch(clamp,"VC"))
			Wave UpstateOn,UpstateOff
			Downsample(theWave,100,in_place=1)
			if(!flag)
				for(j=0;j<ItemsInList(conditions);j+=1)
					condition_str=StringFromList(j,conditions)
					NewDataFolder /O root:AverageUpstate
					Duplicate /o/R=(leftx(theWave),leftx(theWave)+11) theWave $("root:AverageUpstate:"+condition_str+"_AverageUpstate"+clamp)
					Wave AverageUpstate=$("root:AverageUpstate:"+condition_str+"_AverageUpstate"+clamp)
					SetScale x,-1,10,AverageUpstate
					AverageUpstate=0
				endfor
				flag=1
			endif
			condition_str=Condition[i]
			Condition2Color(condition_str); NVar red,green,blue
			Wave AverageUpstate=$("root:AverageUpstate:"+condition_str+"_AverageUpstate"+clamp)
			for(j=0;j<numpnts(UpstateOn);j+=1)
				on=UpstateOn[j]; off=UpstateOff[j]
				upstate_name=NameOfWave(theWave)+"_U"+num2str(j)
				Duplicate /o /R=(on-1,on+10) theWave $upstate_name
				Wave UpstateName=$upstate_name
				SetScale x,-1,10,UpstateName
				if((off-on)>10)
					temp=mean(UpstateName,-1,0)
					UpstateName[x2pnt(UpstateName,off-on),x2pnt(UpstateName,10)]=temp
				endif
				AverageUpstate+=UpstateName
				ConditionCounts[WhichListItem(condition_str,conditions)]+=1
				if(show_all)
					AppendToGraph /c=(red,green,blue) UpstateName
				endif
			endfor
			KillWaves /Z UW_temp,theWave
		endif
		if(show_all)
			DoUpdate
		endif
	endfor
	
	Variable baseline,count
	for(j=0;j<ItemsInList(conditions);j+=1)
		condition_str=StringFromList(j,conditions)
		Wave AverageUpstate=$("root:AverageUpstate:"+condition_str+"_AverageUpstate"+clamp)
		count=ConditionCounts[WhichListItem(condition_str,conditions)]
		AverageUpstate/=count
		baseline=mean(AverageUpstate,-1,0)
		AverageUpstate-=baseline
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) AverageUpstate
		ModifyGraph lsize($TopTrace())=2
	endfor
	KillVariables /Z red,green,blue
	root()
End

Function UpstateAHPWaveforms([show_all])
	Variable show_all // Plot them all.  
	root()
	Wave /T FileName,Condition
	String name,condition_str,conditions="Control;Seizure"
	Variable i,j,on,off,next_on,prev_off,nullify
	Make /o/n=(ItemsInList(conditions)) ConditionCounts=0; Wave ConditionCounts
	NewDataFolder /O/S root:UpstateAHPWaveforms
	
	Variable range=5
	if(show_all)
		Display /N=UpstateAHPWaveformsBefore
		Display /N=UpstateAHPWaveformsAfter
	endif
	for(i=0;i<numpnts(FileName);i+=1)
		name=FileName[i]
		root()
		if(DataFolderExists("root:Cells:"+name))
			name=LoadIBW(name+".ibw")
			Wave UpstateOn,UpstateOff,theWave=$name
			Downsample(theWave,100,in_place=1)
			if(i==0)
				for(j=0;j<ItemsInList(conditions);j+=1)
					condition_str=StringFromList(j,conditions)
					Duplicate /o/R=(leftx(theWave),leftx(theWave)+range) theWave $("root:"+condition_str+"_AverageBeforeUpstate")
					Duplicate /o/R=(leftx(theWave),leftx(theWave)+range) theWave $("root:"+condition_str+"_AverageAfterUpstate")
					Wave AverageBeforeUpstate=$("root:"+condition_str+"_AverageBeforeUpstate")
					Wave AverageAfterUpstate=$("root:"+condition_str+"_AverageAfterUpstate")
					SetScale x,-range,0,AverageBeforeUpstate
					SetScale x,0,range,AverageAfterUpstate
					AverageBeforeUpstate=0; AverageAfterUpstate=0
				endfor
			endif
			condition_str=Condition[i]
			Wave AverageBeforeUpstate=$("root:"+condition_str+"_AverageBeforeUpstate")
			Wave AverageAfterUpstate=$("root:"+condition_str+"_AverageAfterUpstate")
			for(j=0;j<numpnts(UpstateOn);j+=1)
				on=UpstateOn[j]; off=UpstateOff[j]
				next_on=UpstateOn[j+1]; prev_off=UpstateOff[j-1]
				
				Duplicate /o/R=(on-range,on) theWave $(name+"_"+num2str(j)+"_before")
				Wave SegmentBefore=$(name+"_"+num2str(j)+"_before")
				SetScale x,-range,0,SegmentBefore
				if(prev_off>on-range && prev_off<on)
					nullify=on-prev_off
					SegmentBefore[x2pnt(SegmentBefore,-range),x2pnt(SegmentBefore,-nullify)]=SegmentBefore(-nullify)
				endif
				
				Duplicate /o/R=(off,off+range) theWave $(name+"_"+num2str(j)+"_after")
				Wave SegmentAfter=$(name+"_"+num2str(j)+"_after")
				SetScale x,0,range,SegmentAfter
				if(next_on<off+range && next_on>off)
					nullify=next_on-off
					SegmentAfter[x2pnt(SegmentAfter,nullify),x2pnt(SegmentAfter,range)]=SegmentAfter(nullify)
				endif
				
				AverageBeforeUpstate+=SegmentBefore
				AverageAfterUpstate+=SegmentAfter
				ConditionCounts[WhichListItem(condition_str,conditions)]+=1
				Condition2Color(Condition[i]); NVar red,green,blue
				if(show_all)
					AppendToGraph /W=UpstateAHPWaveformsBefore /c=(red,green,blue) SegmentBefore
					AppendToGraph /W=UpstateAHPWaveformsAfter /c=(red,green,blue) SegmentAfter
				endif
			endfor
			KillWaves /Z SegmentBefore,SegmentAfter,theWave
		endif
	endfor
	KillVariables /Z red,green,blue
	
	Variable baseline
	Display /K=1 /N=AverageUpstateBeforeAndAfter
	for(j=0;j<ItemsInList(conditions);j+=1)
		condition_str=StringFromList(j,conditions)
		Wave AverageBeforeUpstate=$("root:"+condition_str+"_AverageBeforeUpstate")
		Wave AverageAfterUpstate=$("root:"+condition_str+"_AverageAfterUpstate")
		AverageBeforeUpstate/=ConditionCounts[WhichListItem(condition_str,conditions)]
		AverageAfterUpstate/=ConditionCounts[WhichListItem(condition_str,conditions)]
		//baseline=mean(AverageBeforeUpstate,-range,0)
		//AverageBeforeUpstate-=baseline
		//AverageAfterUpstate-=baseline
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) AverageBeforeUpstate,AverageAfterUpstate
	endfor
	KillVariables /Z red,green,blue
	KillWaves /Z ConditionCounts
	root()
End


// Compute the average number of spikes in the first 'num' seconds.   
Function SpikesInTheFirst(num[,mode])
	Variable num,mode
	mode=ParamIsDefault(mode) ? 0 : mode // Mode 0 to average across cells first, mode 1 to not do so.  
	root()
	Variable i,j,count;String folder,condition_str,conditions="Control;Seizure"
	Wave /T FileName,Condition
	Make /o/n=(ItemsInList(conditions)) SpikesInAvg=0, SpikesInSEM=0,ConditionCounts=0
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Make /o/n=0 root:$(condition_str+"SpikesIn")=0
	endfor
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave UpstateSpikeTimes,UpstateBegins
			if(numpnts(UpstateBegins)>0)
				ConditionCounts[WhichListItem(condition_str,conditions)]+=numpnts(UpstateBegins)
				Wave SpikesIn=root:$(condition_str+"SpikesIn")
				UpstateSpikeTimes-=UpstateBegins[q]
				Duplicate /o UpstateSpikeTimes UpstateSpikeTimesUnwrapped
				UpstateSpikeTimes+=UpstateBegins[q]
				if(mode==0)	
					Redimension /n=(numpnts(UpstateSpikeTimesUnwrapped)) UpStateSpikeTimesUnwrapped
					DeleteNans(UpstateSpikeTimesUnwrapped)
					Sort UpstateSpikeTimesUnwrapped,UpstateSpikeTimesUnwrapped
					Redimension /n=(numpnts(SpikesIn)+1) SpikesIn
					count=BinarySearch(UpstateSpikeTimesUnwrapped,num)
					if(count>=0)
						SpikesIn[numpnts(SpikesIn)-1]=(1+count)/numpnts(UpstateBegins)
					elseif(count==-2)
						SpikesIn[numpnts(SpikesIn)-1]=1
					else
						printf "Error.\r"
					endif
				elseif(mode==1)
					for(j=0;j<numpnts(UpstateBegins);j+=1)
						Duplicate /o /R=[][j,j] UpstateSpikeTimesUnwrapped OneColumn
						Redimension /n=(numpnts(OneColumn)) OneColumn
						DeleteNans(OneColumn)
						Sort OneColumn,OneColumn
						Redimension /n=(numpnts(SpikesIn)+1) SpikesIn
						count=BinarySearch(OneColumn,num)
						if(count>=0)
							SpikesIn[numpnts(SpikesIn)-1]=(1+count)
						elseif(count==-2)
							SpikesIn[numpnts(SpikesIn)-1]=1
						else
							printf "Error.\r"
						endif
					endfor
				endif
				//Duplicate /o /R=[0,BinarySearch(UpstateSpikeTimesUnwrapped,num)] UpStateSpikeTimesUnwrapped tempTimes
				//Concatenate /NP {TempTimes}, root:$(condition_str+"SpikesIn")
				KillWaves UpstateSpikeTimesUnwrapped
			endif
		endif
	endfor
	Display /K=1
	Variable left=-2,right=10
	Variable bin_size=0.1 // Bin size in seconds
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave SpikesIn=root:$(condition_str+"SpikesIn")
		WaveStats /Q SpikesIn
		SpikesInAvg[WhichListItem(condition_str,conditions)]=V_avg
		SpikesInSEM[WhichListItem(condition_str,conditions)]=V_sdev/sqrt(V_npnts)
	endfor
	AppendToGraph SpikesInAvg vs $List2WavT(conditions,name="ConditionList")
	ErrorBars SpikesInAvg, Y wave=(SpikesInSEM,SpikesInSEM)
	
	Wave wave1=root:$(StringFromList(0,conditions)+"SpikesIn")
	Wave wave2=root:$(StringFromList(1,conditions)+"SpikesIn")
	//Variable p_val=BootMean(wave1,wave2)
	Variable p_val=imag(StatTTest(1,wave1,wave2))
	Textbox "p = "+num2str(p_val)
End

// Compute the average first ISI in an upstate, for each condition.
Function FirstISI([mode])
	Variable mode
	mode=ParamIsDefault(mode) ? 0 : mode // Mode 0 to average across cells first, mode 1 to not do so.  
	root()
	Variable i,j,ISI,count;String folder,condition_str,conditions="Control;Seizure"
	Wave /T FileName,Condition
	NewDataFolder /O/S root:FirstISIs
	Make /o/n=(ItemsInList(conditions)) FirstISIAvg=0, FirstISISEM=0,ConditionCounts=0
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Make /o/n=0 root:$(condition_str+"FirstISI")=0
	endfor
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		condition_str=Condition[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave UpstateSpikeTimes,UpstateBegins
			if(numpnts(UpstateBegins)>0)
				Wave FirstISI=root:$(condition_str+"FirstISI")
				Make /o/n=(dimsize(UpstateSpikeTimes,1)) UpstateFirstISIs
				UpstateFirstISIs=UpstateSpikeTimes[1][p]-UpstateSpikeTimes[0][p]
				ISI=0; count=0
				if(mode==0)	
					ConditionCounts[WhichListItem(condition_str,conditions)]+=1
					Redimension /n=(numpnts(FirstISI)+1) FirstISI
					WaveStats UpstateFirstISIs
					FirstISI[numpnts(FirstISI)-1]=V_avg
				elseif(mode==1)
					for(j=0;j<numpnts(UpstateFirstISIs);j+=1)
						ConditionCounts[WhichListItem(condition_str,conditions)]+=1
						Redimension /n=(numpnts(FirstISI)+1) FirstISI
						FirstISI[numpnts(FirstISI)-1]+=UpstateFirstISIs[j]
					endfor
				endif
			endif
		endif
	endfor
	SetDataFolder root:FirstISIs
	Display /K=1
	Variable left=-2,right=10
	Variable bin_size=0.1 // Bin size in seconds
	for(i=0;i<ItemsInList(conditions);i+=1)
		condition_str=StringFromList(i,conditions)
		Wave FirstISI=root:$(condition_str+"FirstISI")
		WaveStats /Q FirstISI
		FirstISIAvg[WhichListItem(condition_str,conditions)]=V_avg
		FirstISISEM[WhichListItem(condition_str,conditions)]=V_sdev/sqrt(V_npnts)
	endfor
	AppendToGraph FirstISIAvg vs $List2WavT(conditions,name="ConditionList")
	ErrorBars FirstISIAvg, Y wave=(FirstISISEM,FirstISISEM)
	ModifyGraph zColor={Colors,*,*,directRGB}
	Wave wave1=root:$(StringFromList(0,conditions)+"FirstISI")
	Wave wave2=root:$(StringFromList(1,conditions)+"FirstISI")
	//Variable p_val=BootMean(wave1,wave2)
	Variable p_val=imag(StatTTest(1,wave1,wave2))
	Textbox "p = "+num2str(p_val)
	root()
End

// Try to find where a cell's upstates "started" in the voltage sense, by going back from its first spike until there is a part that isn't noisy.  
Function UpstateBegin(ibw)
	String ibw
	root()
	String name=LoadIBW(ibw)
	Wave theWave=$name
	Wave UpstateFirstSpikes
	Variable i,j
	for(i=0;i<numpnts(UpstateFirstSpikes);i+=1)
		//AppendToGraph theWave[x2pnt(theWave,UpstateFirstSpikes[i]-5),x2pnt(theWave,UpstateFirstSpikes[i]+5)]
		//ModifyGraph offset($TopTrace())={-(UpstateFirstSpikes[i]),i*10}
	endfor
	//SetAxis bottom -5,5
	Variable loc,width=0.2,min_stdev=0.5
	Make /o/n=(numpnts(UpstateFirstSpikes)) UpstateBegins
	for(i=0;i<numpnts(UpstateFirstSpikes);i+=1)
		loc=UpstateFirstSpikes[i]
		Do
			Duplicate /o/R=(loc-width,loc) theWave Segment
			WaveStats /Q Segment
			if(V_sdev<min_stdev)
				break
			else
				loc-=width/2
			endif
		While(loc>UpstateFirstSpikes[i]-5 && loc>leftx(theWave))
		UpstateBegins[i]=loc
	endfor
	//ScrambleColors();DoUpdate
	for(i=0;i<numpnts(UpstateFirstSpikes);i+=1)
		//GetTraceColor(name+"#"+num2str(i)); NVar red,green,blue
		//Tag /G=(red,green,blue) $(name+"#"+num2str(i)),UpstateBegins[i],"*"
	endfor
	KillVariables /Z red,green,blue
	//DoWindow /K $TopWindow()
	KillWaves /Z theWave,Segment
	SetDataFolder root:
End

// Try to find where a cell's upstates "ended" in the voltage sense, by going forward from its last spike until there is a part that isn't noisy.
Function /S UpstateEnd(ibw)
	String ibw
	root()
	String name=LoadIBW(ibw)
	Wave theWave=$name
	Wave UpstateLastSpikes
	Variable i,j
	for(i=0;i<numpnts(UpstateEnds);i+=1)
		//AppendToGraph theWave[x2pnt(theWave,UpstateEnds[i]-5),x2pnt(theWave,UpstateEnds[i]+5)]
		//ModifyGraph offset($TopTrace())={-(UpstateEnds[i]),i*10}
	endfor
	//SetAxis bottom -5,5
	Variable loc,width=0.2,min_stdev=0.5
	Make /o/n=(numpnts(UpstateLastSpikes)) UpstateEnds
	for(i=0;i<numpnts(UpstateLastSpikes);i+=1)
		loc=UpstateLastSpikes[i]
		Do
			Duplicate /o/R=(loc,loc+width) theWave Segment
			WaveStats /Q Segment
			if(V_sdev<min_stdev)
				break
			else
				loc+=width/2
			endif
		While(loc<UpstateLastSpikes[i]+5 && loc<rightx(theWave))
		UpstateEnds[i]=loc
	endfor
	//ScrambleColors();DoUpdate
	for(i=0;i<numpnts(UpstateLastSpikes);i+=1)
		//GetTraceColor(name+"#"+num2str(i)); NVar red,green,blue
		//Tag /G=(red,green,blue) $(name+"#"+num2str(i)),UpstateEnds[i],"*"
	endfor
	KillVariables /Z red,green,blue
	//DoWindow /K $TopWindow()
	KillWaves /Z theWave,Segment
	SetDataFolder root:
End


// Compute the AHP that comes at the end of an upstate.  
Function UpstateAHP(ibw)
	String ibw
	root()
	String name=LoadIBW(ibw)
	Wave theWave=$name
	Downsample(theWave,10,in_place=1)
	Duplicate /o UpstateOn UpstateTroughs,UpstateTrough_Locs,UpstateThresholds,UpstateAHPs; 
	Wave UpstateOn,UpstateOff
	UpstateTroughs=Nan; UpstateTrough_Locs=NaN; UpstateThresholds=NaN; UpstateAHPs=NaN
	Variable i,j,spike
	Variable on,off,prev_off,next_on,mean_before,min_after,range
	for(i=0;i<numpnts(UpstateOn);i+=1)
		on=UpstateOn[i]; off=UpstateOff[i]
		prev_off=UpstateOff[i-1]; next_on=UpstateOn[i+1]
		
		range=1
		if(prev_off>on-range && prev_off<on)
			range=on-prev_off
		endif
		Duplicate /o/R=(on-range,on) theWave Segment1
		mean_before=mean(Segment1)
		
		range=1
		if(next_on<off+range && next_on>off)
			range=next_on-off
		endif
		Duplicate /o/R=(off,off+range) theWave Segment2
		WaveStats /Q Segment2; min_after=mean(Segment2,V_minloc-0.25,V_minloc+0.25)
		
		UpstateTrough_Locs[i]=V_minloc
		UpstateTroughs[i]=min_after
		UpstateAHPs[i]=mean_before-min_after
	endfor
	KillVariables /Z red,green,blue
	//DoWindow /K $TopWindow()
	KillWaves /Z theWave,Segment1,Segment2
	root()
End

Function Upstates([downtime])
	Variable downtime
	downtime=ParamIsDefault(downtime) ? 3 : downtime
	Variable i,j,u=0,up=0,upstate_start,upstate_end; 
	Wave SpikeTimes=Peak_locs
	Wave Threshold,AHP
	Make /o/n=0 UpstateFirstSpikes=NaN,UpstateLastSpikes=NaN,UpstateDurations=NaN,UpstateSpikeCounts=NaN,UpstateSpikeRates=NaN,UpstateFirstSpikeIndices=NaN
	Make /o/n=1 UpstateRate=NaN,SpikeRate=NaN
	Make /o/n=(numpnts(SpikeTimes),0) UpstateSpikeTimes=NaN
	for(j=0;j<numpnts(SpikeTimes);j+=1)
		if(up==0) // Not currently in an upstate
			Redimension /n=(u+1) UpstateFirstSpikes,UpstateLastSpikes,UpstateDurations,UpstateSpikeCounts,UpstateSpikeRates,UpstateFirstSpikeIndices
			Redimension /n=(-1,u+1) UpStateSpikeTimes
			UpstateFirstSpikes[u]=SpikeTimes[j]; 
			UpstateFirstSpikeIndices[u]=j
			UpstateSpikeTimes[0][u]=SpikeTimes[j]
			UpstateSpikeCounts[u]=1
			up=1
		elseif(up==1) // Currently in an upstate
			UpstateSpikeCounts[u]+=1
			UpStateSpikeTimes[UpStateSpikeCounts[u]-1][u]=SpikeTimes[j]
		endif
		if(j==numpnts(SpikeTimes)-1 || SpikeTimes[j+1]-SpikeTimes[j]>downtime) // The next spike is too far, so this spike was the last one of the upstate
			UpstateLastSpikes[u]=SpikeTimes[j]; 
			up=0
			if(UpStateSpikeCounts[u]==1) // If the upstate contained only a single spike.  
				if(AHP[j]>-5) // And if that spike was not part of an EPSP barrage.  
					// Then it probably wasn't part of an upstate.
					DeletePoints numpnts(UpstateFirstSpikes)-1,1,UpstateFirstSpikes,UpstateLastSpikes,UpstateDurations,UpstateSpikeCounts,UpstateSpikeRates,UpstateFirstSpikeIndices
					u-=1
				endif
			endif
			if(UpstateLastSpikes[u]-UpstateFirstSpikes[u]<1) // If upstate is less then one second long.  
				//DeletePoints numpnts(UpstateFirstSpikes)-1,1,UpstateFirstSpikes,UpstateLastSpikes,UpstateDurations,UpstateSpikeCounts,UpstateSpikeRates,UpstateStartSpikeIndices
				//u-=1
			endif
			u+=1
		endif
	endfor
	UpstateDurations=UpstateLastSpikes-UpstateFirstSpikes
	UpstateSpikeRates=UpStateDurations>0 ? (UpstateSpikeCounts/UpstateDurations) : NaN
	if(numpnts(UpstateSpikeCounts)>0)
		WaveStats /Q UpstateSpikeCounts
		Redimension /n=(V_max,-1) UpstateSpikeTimes	
	endif
	UpstateSpikeTimes=(UpstateSpikeTimes==0) ? NaN : UpstateSpikeTimes
	NVar start=spikes_start
	NVar finish=spikes_finish
	UpStateRate=numpnts(UpstateFirstSpikes)/(finish-start)
	SpikeRate=numpnts(SpikeTimes)/(finish-start)
	Duplicate /o UpstateFirstSpikes UpstateIntervals
	UpstateIntervals=UpstateFirstSpikes-UpstateLastSpikes[p-1]
	UpstateIntervals[0]=NaN
End

Function DownstateNoise2([path])
	String path
	root()
	if(ParamIsDefault(path))
		path=StrVarOrDefault("root:parameters:random:dataDir","")
	endif
	path=Windows2IgorPath(path)
	NewPath /O IBWPath path
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0)
			DownstateNoise(ibw=ibw)
		endif
	endfor
	root()
	//KillPath IBWPath
End

Function DownstateNoise([ibw])
	String ibw
	String name
	if(ParamIsDefault(ibw))
		Wave theWave=CsrWaveRef(A)
	else
		name=LoadIBW(ibw)
		Wave theWave=$name
	endif
	
	if(0.001/dimdelta(theWave,0) !=10)
		printf "%d kHz\r",0.001/dimdelta(theWave,0)
	endif
	DownSample(theWave,0.001/dimdelta(theWave,0),in_place=1)
	
	//Differentiate theWave
	FilterF(theWave,lo=1,width=0.3) // Filter out the low frequency drift.  
	MeanStDevPlot(theWave,bin_size=0.1,shift=0.1,no_plot=1)
	Wave StanDev=root:MeanStDevPlot_F:StanDev
	Make /o/n=100 Hist; SetScale x,0,1,Hist // Assumes the peak of the downstate standard deviations will be less than 2 (always is so far).  
	//Make /o/n=100 Hist // Assumes the peak of the differentiated downstate standard deviations will be less than 100 (always is so far).  
	Histogram /B=2 StanDev,Hist
	Smooth 5,Hist
	WaveStats /Q Hist
	Make /o/n=1 Noise=V_maxloc
	//Make /o/n=1 NonStationaryNoise=V_maxloc/sqrt(2)
	//Make /o/n=1 NonStationaryNoise=Median2(StanDev)/sqrt(2)
	KillWaves /Z theWave,Hist
	
//	Wave Downsampled=$Downsample(theWave,100)
//	KillWaves /Z theWave
//	Wave theWave=Downsampled
//	Wave UpstateBegins,UpstateEnds
//	Duplicate /o UpstateBegins UpstateOn; Wave UpstateOn
//	Duplicate /o UpstateEnds UpstateOff; Wave UpstateOff
//	UpstateOff=IsNaN(UpstateEnds) ? UpstateBegins : UpstateEnds
//	UpstateOn-=1 // Make some room so as to not run into the beginning or end of an upstate
//	UpstateOff+=1
//	NVar spikes_start,spikes_finish
//	InsertPoints 0,1,UpstateOff; UpstateOff[0]=spikes_start
//	InsertPoints numpnts(UpstateOn),1,UpstateOn; UpstateOn[numpnts(UpstateOn)-1]=spikes_finish
//	Make /o/n=(numpnts(UpstateOff)) NonStationaryNoise=NaN
//	//LineRemove(Downstate)
//	Variable i,on,off,diff,cumul=0
//	// Get rid of upstates
//	for(i=numpnts(UpstateOn)-1;i>=0;i-=1)
//		off=UpstateOff[i]
//		on=UpstateOn[i]
//		Duplicate /o /R=(off,on) theWave Downstate
//		Do
//			WaveStats /Q Downstate
//			if(V_max>-10)
//				DeletePoints x2pnt(Downstate,V_maxloc)-1,2,Downstate
//			else
//				break
//			endif
//		While(1)
//		NonStationaryNoise[i]=StDevNoise(Downstate)
//	endfor
//	KillWaves /Z theWave,Downstate,UpstateOn,UpstateOff
	
//	// Get rid of any other spikes
//	Do
//		if(numpnts(Downstate)>=1)
//			WaveStats /Q Downstate
//		else
//			break
//		endif
//		if(V_max>-10)
//			on=x2pnt(Downstate,V_maxloc-0.5)
//			off=x2pnt(Downstate,V_maxloc+0.5)
//			DeletePoints on,off-on,Downstate
//			diff=Downstate[on-1]-Downstate[on]
//			Downstate[on,]+=diff
//		else
//			break
//		endif
//	While(1)
//	KillWaves /Z UpstateOn,UpstateOff
//	//Display /K=1 /N=DSWin Downstate
//	Make /o/n=1 NonStationaryNoise=NaN
//	if(numpnts(Downstate)>10000) // At least 1 second of data
//		Smooth /B=1 100,Downstate
////		WaveStats /Q Downstate
////		Downstate-=V_avg
////		BandPass(Downstate,low=0.2,steep=0.3)
//		NonStationaryNoise[0]=StDevNoise(Downstate)
////		WaveStats /Q Downstate
////		NonStationaryNoise[0]=V_sdev
//	endif
//	KillWaves /Z Downstate
//	//DoWindow /K DSWin
End

// Extracts various information about upstates.   
Function VariousUpstateStats()
	root()
	Wave /T FileName,Condition,Experimenter
	Variable index,i,j,on,off,num_spikes,spike_time,spike_time2; String name
	
	for(index=0;index<numpnts(FileName);index+=1)
		root()
		name=FileName[index]
		if(DataFolderExists("root:Cells:"+name))
			SetDataFolder root:Cells:$name
			Wave UpstateOn,UpstateOff,Peak_Locs,U_Spikes
			Make /o/n=(numpnts(UpstateOn)) U_TBFS=NaN,U_TALS=NaN,U_FirstISI=NaN,U_LastISI=NaN,U_Spikeless=NaN,U_SpikesG0=NaN
			NVar spikes_start,spikes_finish
			Make /o/n=1 SpikeRate=numpnts(Peak_Locs)/(spikes_finish-spikes_start)
			Make /o/n=1 UpstateRate=numpnts(UpstateOn)/(spikes_finish-spikes_start)
			U_Spikeless=U_Spikes==0 ? 1 : 0
			U_SpikesG0=U_Spikes==0 ? NaN : U_Spikes
			
			for(i=0;i<numpnts(UpstateOn);i+=1)
				on=UpstateOn[i]; off=UpstateOff[i]
				
				for(j=0;j<numpnts(Peak_Locs);j+=1)
					spike_time=Peak_Locs[j]
					if(spike_time>on && spike_time<off)
						U_TBFS[i]=spike_time-on
						spike_time2=Peak_Locs[j+1]
						if(spike_time2>spike_time && spike_time2<off)
							U_FirstISI[i]=spike_time2-spike_time
						endif
						break
					endif
				endfor
				
				for(j=numpnts(Peak_Locs)-1;j>=0;j-=1)
					spike_time=Peak_Locs[j]
					if(spike_time<off && spike_time>on)
						U_TALS[i]=off-spike_time
						spike_time2=Peak_Locs[j-1]
						if(spike_time2<spike_time && spike_time2>on)
							U_LastISI[i]=spike_time-spike_time2
						endif
						break
					endif
				endfor
			endfor
		endif
	endfor
	root()
End

#pragma rtGlobals=1		// Use modern global access method.

#include "Manual Upstate Detection"

constant analysisSamplingFreq=100 // New sampling frequency in Hz.  
constant consolidationWidth=2 // Twice the minimum width of a state, in seconds.  
constant adaptiveBinSize=2
//strconstant recordingsFolder="root:Recordings"
constant numSamplesToPause=1
constant numSamplesToContinue=1
strconstant defaultMethods="Fixed;Adaptive"
constant ROCTolerance=0.2
#if StringMatch(IgorInfo(2),"Macintosh")
	strconstant simsDir="Macintosh HD:Users:rgerkin:Desktop:upstates:Simulations"
	strconstant recordingsDir="Macintosh HD:Users:rgerkin:Desktop:upstates:Data"
#else
	strconstant simsDir="Z:Upstates:Simulations"
	strconstant recordingsDir="Z:media:disk:Upstates:Data:Lina Pairs Folder"
#endif

Function RenameFolders()
	Variable i
	
	for(i=0;i<CountObjects("root:Recordings",4);i+=1)
		String folder=GetIndexedObjName("root:Recordings",4,i)
		SetDataFolder root:Recordings:$folder
		if(exists(folder+".ibw"))
			Rename $(folder+".ibw") $folder
		endif
	endfor
End

Function LoadRecordings()
	NewPath /O/Q UpstateIBWs,recordingsDir
	Variable i=0
	Do
		String fileName=IndexedFile(UpstateIBWs,i,".ibw")
		if(!strlen(fileName))
			break
		endif
		LoadRecording(fileName)
		i+=1
	While(1)
End

Function LoadRecording(fileName)
	String fileName
	
	LoadWave /O/P=UpstateIBWs fileName
	String waveName_=StringFromList(0,S_WaveNames)
	Wave theWave=$waveName_
	Resample /RATE=(analysisSamplingFreq) theWave
	String name=RemoveEnding(fileName,".ibw") 
	NewDataFolder /O/S root:Recordings:$name
	Duplicate /o theWave,$name
	KillWaves /Z theWave
End

//Function AnalyzeWave(theWave)
//	Wave theWave
//	
//	NVar fixedThresh,adaptiveThresh
//	FixedThreshold(theWave,fixedThresh)
//	AdaptiveThreshold(theWave,adaptiveThresh)
//	Volgushev(theWave,0)
//	Seamari(theWave,0)
//End

Threadsafe Function StateDetect(method,theWave,threshold)
	String method
	Wave theWave
	Variable /C threshold
	
	strswitch(method)
		case "Fixed":
			FixedThreshold(theWave,real(threshold))
			break
		case "Fixed2D":
			Fixed2DThreshold(theWave,threshold)
			break
		case "Adaptive":
			if(numtype(imag(threshold))) // If the imaginary component (for the st. dev threshold) is NaN or Inf, make it the same as the real component (for the mean threshold).  
				threshold=cmplx(real(threshold),real(threshold))
			endif
			AdaptiveThreshold(theWave,threshold)
			break
		case "Seamari":
			Seamari(theWave,threshold)
			break
		case "Volgushev":
			//Volgushev(theWave,real(threshold)) // Non-interactive.  Must have been done interactively at least once per recording.  
			break
	endswitch
End

Function AnalyzeWaves(type,thresholds,[wave_list,methods])
	String wave_list
	String type // Simulations or Recordings.  
	String methods // Fixed or Adaptive.  
	String thresholds // e.g. "3;7" if there are two methods or just "3" if there is only one.  
	
	if(ParamIsDefault(methods))
		methods=defaultMethods
	endif
	if(ParamIsDefault(wave_list))
		wave_list=""
	endif
	strswitch(type)
		case "Simulations":
			String dataFolder="root:Simulations"
			break
		case "Recordings":
			dataFolder="root:Recordings"
			break
	endswitch
	
	Variable i,k
	for(i=0;i<ItemsInList(methods);i+=1)
		Prog("X",i,ItemsInList(methods))
		String method=StringFromList(i,methods)
		NewDataFolder /O/S root:$method	
		FuncRef FixedThreshold f=$(method+"Threshold") 
		for(k=0;k<CountObjects(dataFolder,4);k+=1)
			Prog("X",k,CountObjects(dataFolder,4))
			String folder=GetIndexedObjName(dataFolder,4,k)
			if(strlen(wave_list) && strlen(ListMatch(folder,wave_list))==0) // This wave is not in the provided wave list.  
				continue
			endif
			SetDataFolder dataFolder+":"+folder
			Variable threshold=str2num(StringFromList(i,thresholds))
			Variable /G $(method+"Thresh")=threshold
			Wave theWave=$folder
			f(theWave,threshold)
			EvaluateStateSelection(theWave,method)
		endfor
	endfor
End

// Analyze recordings with a fixed threshold (mV above the median membrane potential).  
Threadsafe Function FixedThreshold(theWave,threshold)
	Wave theWave
	Variable threshold
	
	NewDataFolder /O/S $(GetWavesDataFolder(theWave,1)+"Fixed")
	Make /o/n=1000 Hist
	SetScale x,-55,-45,Hist
	Histogram /B=2 theWave,Hist
	Smooth 100,Hist
	WaveStats /Q Hist
	Variable mode=V_maxloc
	Duplicate /o theWave, StateWave
	StateWave=theWave>(mode+threshold) ? 1 : 0
	ConsolidateStates(StateWave,consolidationWidth)
	Extract /O/INDX StateWave,Ups,(StateWave[p]-StateWave[p-1])==1
	Extract /O/INDX StateWave,Downs,(StateWave[p]-StateWave[p-1])==-1
	Redimension /S Ups,Downs
	Ups*=deltax(StateWave)
	Downs*=deltax(StateWave)
	KillWaves /Z Hist//,StateWave
End

// Analyze recordings with a fixed threshold (mV above/below the median membrane potential and mV for the standard deviation).  
Threadsafe Function Fixed2DThreshold(theWave,threshold)
	Wave theWave
	Variable /C threshold
	
	NewDataFolder /O/S $(GetWavesDataFolder(theWave,1)+"Fixed2D")
	RunningMeanStDev(theWave,winSize=0.25,winShape="Rect")
	Wave Meann,StanDev
	Make /o/n=1000 Hist
	
	Variable median=StatsMedian(Meann)
	
	Duplicate /o theWave, StateWave
	StateWave=(Meann>(median+real(threshold)) && StanDev>(imag(threshold))) ? 1 : 0
	ConsolidateStates(StateWave,consolidationWidth)
	Extract /O/INDX StateWave,Ups,(StateWave[p]-StateWave[p-1])==1
	Extract /O/INDX StateWave,Downs,(StateWave[p]-StateWave[p-1])==-1
	Redimension /S Ups,Downs
	Ups*=deltax(StateWave)
	Downs*=deltax(StateWave)
	KillWaves /Z Hist//,StateWave
End

// Analyze recordings with a fixed threshold (mV above the median membrane potential).  
Threadsafe Function AdaptiveThreshold(theWave,threshold)
	Wave theWave
	Variable /C threshold
	
	NewDataFolder /O/S $(GetWavesDataFolder(theWave,1)+"Adaptive")
	String pauseUpdateStr
	sprintf pauseUpdateStr,"%f,%f,%d;%f,%f,%d",real(threshold),imag(threshold),numSamplesToPause,real(threshold),imag(threshold),numSamplesToContinue
	//NVar adaptiveBinSize=root:adaptiveBinSize
	RunningMeanStDev(theWave,winSize=adaptiveBinSize,pauseOn={{real(threshold),numSamplesToPause},{imag(threshold),numSamplesToContinue}})
	Wave Updating
	Duplicate /o Updating StateWave; Wave StateWave
	StateWave=1-StateWave
	//abort
	ConsolidateStates(StateWave,consolidationWidth)
	Extract /O/INDX StateWave,Ups,(StateWave[p]-StateWave[p-1])==1
	Extract /O/INDX StateWave,Downs,(StateWave[p]-StateWave[p-1])==-1
	Redimension /S Ups,Downs
	Ups=leftx(theWave)+Ups*deltax(StateWave)
	Downs=leftx(theWave)+Downs*deltax(StateWave)
	KillWaves /Z Meann,StanDev,Updating,Hist//,StateWave
End

// Analyze recordings with the method from Seamari ... Sanchez-Vives, PLOS One, 2007.  
Threadsafe Function Seamari(theWave,threshold[,online])
	Wave theWave
	Variable /C threshold // In this case, let's have it be the log of the time constant of the slow window (real) and fast window (imaginary).    
	Variable online // Use the online method.  This eliminates the search for slope thresholds, which are more accurate, but can only be done offline.  
	
	NewDataFolder /O/S $(GetWavesDataFolder(theWave,1)+"Seamari")
	//SetDataFolder $GetWavesDataFolder(theWave,1)
	Duplicate /o/FREE theWave,Corr,SlopeUp,SlopeDown
	Correlate /AUTO/NODC Corr,Corr
	FFT /PAD=(NextPowerOf2(numpnts(Corr)))/MAGS/DEST=FFTD Corr
	WaveStats /Q FFTD
	Variable period=1/V_maxloc
	KillWaves /Z FFTD
	//printf "Period = %f\r",period
	Duplicate /o theWave, StateWave
	Duplicate /o/FREE theWave,SlowMean,FastMean
	Variable freq=1/dimdelta(theWave,0)
	Variable W_slow=10^real(threshold) // W_slow=2*(4-period) doesn't work since the period is usually > 4 s for these recordings.  
	Variable W_fast=10^imag(threshold) // /W_slow=2*(4-period) and Wf=Ws/60 with period = 1, as in the paper and in emails with Daniel Lobo, would give Wf=6/60. 
	Variable alpha_slow=(W_slow*freq)/(1+W_slow*freq)
	Variable alpha_fast=(W_fast*freq)/(1+W_fast*freq)
	SlowMean[1,]=(alpha_slow)*SlowMean[p-1]+(1-alpha_slow)*SlowMean[p]
	FastMean[1,]=(alpha_fast)*FastMean[p-1]+(1-alpha_fast)*FastMean[p]
	StateWave=(FastMean-SlowMean)>0 ? 1 : 0
	//ConsolidateStates(StateWave,0.08) // 40 ms minimum state width * 2 = 80 ms.  
	ConsolidateStates(StateWave,consolidationWidth) // Increased from 0.08 because our data has longer states than used in Seamari.  
	Extract /O/INDX StateWave,Ups,(StateWave[p]-StateWave[p-1])==1
	Extract /O/INDX StateWave,Downs,(StateWave[p]-StateWave[p-1])==-1
	Redimension /S Ups,Downs
	Ups=pnt2x(StateWave,Ups)
	Downs=pnt2x(StateWave,Downs)
	if(Downs[0]<Ups[0])
		DeletePoints 0,1,Downs
	endif
	Redimension /n=(min(numpnts(Ups),numpnts(Downs))) Ups
	if(!online)
		Variable points=0.03*freq // 30 ms according to Daniel Lobo.  
		SlopeUp=(theWave[p]-theWave[p-points])/0.03
		points=0.01*freq // 10 ms according to Daniel Lobo.  
		SlopeDown=(theWave[p]-theWave[p-points])/0.01
		Variable i,slopeThresh=3
		for(i=0;i<numpnts(Ups);i+=1)
			FindLevel /Q/EDGE=1/R=(Ups[i],i==0 ? 0 : Downs[i-1]) SlopeUp,5 // 5 mV/s according to Daniel Lobo.  
			if(!V_flag && V_LevelX>Ups[i]-1)
				Ups[i]=V_LevelX
				//printf "New Up[%d]\r",i
			else
				//printf "No new Up[%d]\r",i
			endif
		endfor
		for(i=0;i<numpnts(Downs);i+=1)
			FindLevel /Q/EDGE=1/R=(Downs[i],Ups[i]) SlopeDown,-5 // 100 mV/s according to Daniel Lobo.  But this is ridiculous, so I am changing it to 5 mV/s.  
			if(!V_flag && V_LevelX>Downs[i]-1)
				Downs[i]=V_LevelX
				//printf "New Down[%d]\r",i
			else
				//printf "No new Down[%d]\r",i
			endif
		endfor
		Duplicate /o/FREE StateWave,NewStateWave
		NewStateWave=0
		Variable j=0
		for(i=0;i<numpnts(Ups);i+=1)
			Variable start=x2pnt(NewStateWave,Ups[i])
			Variable finish=x2pnt(NewStateWave,Downs[i])
			NewStateWave[start,finish]=1
		endfor
		StateWave=NewStateWave
	endif
End

// Analyze recordings with the method from Mukovski ... Volgushev, Cereb. Cortex, 2007.  
// Draw a boundary at the trough of the membrane potential histrogram.  
// Also describes a coincidence index and this should be implemented and cited.  
// This paper has indicates that UP states occur "at about the same time" in all cells.  
Function Mukovski(theWave,threshold[,auto])
	Wave theWave
	Variable threshold
	Variable auto // Proceed automatically without going through the user interface.  
	
	NewDataFolder /O/S $(GetWavesDataFolder(theWave,1)+"Mukovski")
	Volgushev(theWave,0,dims=1,interactive=!auto)
End

// Analyze recordings with the method from Vogulshev ... Timofeev, J. Neurosci., 2006.  Use the mean and the standard deviation.  
// Requires user interaction at least once.  Continued in VolgushevHook().  
Function Volgushev(theWave,threshold[,interactive,dims])
	Wave theWave
	Variable threshold // Fraction of the distance between modes where the cutoffs will be placed.  1/3 for Volgushev.  1/4 for Anderson ... Ferster, Nat. Neurosci., 2000.  
					// Use 0 to use the trough between the modes as the sole threshold (in each dimension), as in Mukovski ... Volgushev, Cereb. Cortex, 2007.  
	Variable interactive // Show the histogram so that the up state mode can be clicked on.  An error results if this has not been done at least once.  
	Variable dims // 1 to use only the mean (1 dimension); 2 to use the mean and the standard deviation (2 dimensions).  
	
	dims=ParamIsDefault(dims) ? 2 : dims
	NewDataFolder /O/S $(GetWavesDataFolder(theWave,1)+"Volgushev")
	if(interactive)
		Duplicate /o theWave, StateWave
		RunningMeanStDev(theWave,winSize=0.25,winShape="Rect")
		Wave Meann,StanDev
		Make /o/n=(100,100) Hist
		WaveStats /Q Meann
		SetScale x,-55,-35,Hist
		WaveStats /Q StanDev
		SetScale y,0,5,Hist
		JointHistogram_(Meann,StanDev,Hist)
		MatrixFilter /n=10 gauss Hist
		Hist=log(1+Hist)
		if(!WinType("VolgushevHistWin"))
			NewImage /K=1 /N=VolgushevHistWin Hist
			MoveWindow /W=VolgushevHistWin 100,100,700,500 
		endif
		DoWindow /F VolgushevHistWin
		ImageStats /Q Hist
		Variable /G downMeanMax=dimoffset(Hist,0)+dimdelta(Hist,0)*V_maxRowLoc
		Variable /G downStDevMax=dimoffset(Hist,1)+dimdelta(Hist,1)*V_maxColLoc
		SetWindow kwTopWin hook(Click)=VolgushevHook, userData(folder)=GetDataFolder(1)
		String /G source=GetWavesDataFolder(theWave,2)
		Variable /G $"dims"=dims
		Variable /G $"threshold"=threshold
		ControlBar /T 40
		SetVariable Dims, size={75,20}, pos={5,5}, variable=$"dims", limits={1,2,1}
		SetVariable threshold, size={80,20}, pos={100,5}, variable=$"threshold", limits={0,1,0.05}
		KillWaves /Z Meann,StanDev,Hist
	else
		Wave /Z Hist
		if(!WaveExists(Hist))
			printf "You must run this method interactively at least once on each recording.\r"
		endif
		VolgushevCompute(Hist,dims,threshold)
	endif
End

Function VolgushevHook(info)
	Struct WMWinHookStruct &info
	
	switch(info.eventCode)
		case 5: // Mouse up.  
			String folder=GetUserData(info.winName,"","folder")
			SetDataFolder $folder
			SVar source
			NVar dims,threshold
			Wave theWave=$source
			Variable /G upMeanMax=AxisValFromPixel("","top",info.mouseLoc.h)
			Variable /G upStDevMax=AxisValFromPixel("","left",info.mouseLoc.v)
			Wave Hist=ImageNameToWaveRef("VolgushevHistWin","Hist")
			VolgushevCompute(Hist,dims,threshold)
			NVar downMeanBoundary,downStDevBoundary,upMeanBoundary,upStDevBoundary
			
			if(!WinType("VolgushevProfileWin"))
				Display /K=1 /N=VolgushevProfileWin W_ImageLineProfile
			endif
			DoWindow /F VolgushevProfileWin
			if(threshold==0) // Use the trough between the modes.
				NVar lineTrough
				Tag /K/N=DownBoundary
				Tag /C/N=UpBoundary/X=0, bottom, lineTrough,"Boundary"
			else // Use a threshold distance between the modes.  
				NVar sampling
				Tag /C/N=DownBoundary/X=0, bottom, threshold*sampling,"Down Boundary"
				Tag /C/N=UpBoundary/X=0, bottom, (1-threshold)*sampling,"Up Boundary"
			endif
			
			DoWindow /F VolgushevHistWin
			DrawAction delete
			SetDrawEnv xcoord=top,yCoord=left,linefgc=(65535,0,0),save
			GetAxis /Q left
			DrawLine downMeanBoundary,V_max,downMeanBoundary,downStDevBoundary
			GetAxis /Q top
			DrawLine V_min,downStDevBoundary,downMeanBoundary,downStDevBoundary
			SetDrawEnv linefgc=(0,65535,0),save
			GetAxis /Q top
			DrawLine V_max,upStDevBoundary,upMeanBoundary,upStDevBoundary
			GetAxis /Q left
			DrawLine upMeanBoundary,V_min,upMeanBoundary,upStDevBoundary
			break
		case 2: // Window closed.  
			NVar /Z AllVolgushevs=root:AllVolgushevs
			if(NVar_Exists(AllVolgushevs))
				NVar threshold
				SetDataFolder ::
				String last=GetDataFolder(0)
				SetDataFolder ::
				String folders=ListFolders(GetDataFolder(1))
				Variable num=WhichListItem(last,folders)
				if(num<ItemsInList(folders)-1)
					String next=StringFromList(num+1,folders)
					Wave Data=:$(next):$next
					Execute /Q/P "Volgushev("+GetWavesDataFolder(Data,2)+","+num2str(threshold)+",interactive=1)"
				endif
			endif
			break
	endswitch
End

Function VolgushevCompute(Hist,dims,threshold)
	Wave Hist // The image histogram (orjust a wave for the 1D case). 
	Variable dims,threshold
	
	String folder=GetWavesDataFolder(Hist,1)
	NVar downMeanMax,downStDevMax,upMeanMax,upStDevMax
	Variable /G sampling=1000
	Make /o/n=(sampling+1)/FREE xWave=downMeanMax+(upMeanMax-downMeanMax)*p/sampling
	Make /o/n=(sampling+1)/FREE yWave=downStDevMax+(upStDevMax-downStDevMax)*p/sampling
	ImageLineProfile xWave=xWave, yWave=yWave, srcWave=Hist
	WaveStats /Q W_ImageLineProfile
	Variable /G lineTrough=V_minLoc
	Variable meanTrough=xWave[V_minLoc]
	Variable stDevTrough=yWave[V_minLoc]
			
	// Now we need to construct the boundaries.  	
	if(threshold==0) // Use the trough between the modes.  
		Variable /G upMeanBoundary=meanTrough
		Variable /G upStDevBoundary=stDevTrough
		Variable /G downMeanBoundary=meanTrough
		Variable /G downStDevBoundary=stDevTrough
	else // Use a threshold distance between the modes.  
		Variable /G upMeanBoundary=(1-threshold)*upMeanMax+threshold*downMeanMax
		Variable /G upStDevBoundary=(1-threshold)*upStDevMax+threshold*downStDevMax
		Variable /G downMeanBoundary=threshold*upMeanMax+(1-threshold)*downMeanMax
		Variable /G downStDevBoundary=threshold*upStDevMax+(1-threshold)*downStDevMax
	endif
			
	Wave StateWave
	Wave Meann=$(folder+"Meann")
	Wave StanDev=$(folder+"StanDev")
	switch(dims)
		case 1:
			StateWave=(Meann>upMeanBoundary) ? 1 : ((Meann<downMeanBoundary) ? 0 : 0.5)
			break
		case 2:
			StateWave=(Meann>upMeanBoundary && StanDev>upStDevBoundary ) ? 1 : ((Meann<downMeanBoundary && StanDev<downStDevBoundary ) ? 0 : 0.5)
			break
		default:
			break
	endswitch
	//ConsolidateStates(StateWave,0.08) // 40 ms minimum state width * 2 = 80 ms.  
	ConsolidateStates(StateWave,consolidationWidth) // Increased from 0.08 because our data has longer states than used in Volgushev.  
	Extract /O/INDX StateWave,Ups,(StateWave[p]-StateWave[p-1])==1
	Extract /O/INDX StateWave,Downs,(StateWave[p]-StateWave[p-1])==-1
	Redimension /S Ups,Downs
	Ups*=deltax(StateWave)
	Downs*=deltax(StateWave)
End

// Analyze recordings with the method from Anderson ... Ferster, Nat. Neurosci., 2000. 
// Same as the first method from Volgushev, except with threshold set at 1/4 and 3/4 instead of 1/3 and 2/3.  
Function Anderson(theWave,threshold)
	Wave theWave
	Variable threshold
	
	Volgushev(theWave,1/4,dims=1)
End

// Use successive median smoothing to cause a region of UP and DOWN to unanimously reflect the majority state in that region.  
Threadsafe Function ConsolidateStates(StateWave,minWidth_,[,quantile])
	Wave StateWave
	Variable minWidth_,quantile
	
	Do
		Variable minWidth=minWidth_
		Duplicate /o/FREE StateWave ComparisonWave
		quantile=ParamIsDefault(quantile) ?  0.5 : quantile
		quantile=0.5
		
		Variable i
		minWidth=round(minWidth/deltax(StateWave)) // Convert from units to points.  
		minWidth+=(mod(minWidth,2)==0) ? 1 : 0 // Make odd.  
		//start=min(start,minWidth) 
		for(i=2;i<minWidth;i*=2)
			//Smooth /M=0 i+1,StateWave
		endfor
		if(quantile==0.5)
			Smooth /M=0 minWidth,StateWave
			//Smooth /M=0 minWidth,StateWave
		else
			Smooth /B=1 minWidth,StateWave
			StateWave=StateWave>quantile
			Smooth /B=1 minWidth,StateWave
			StateWave=StateWave>quantile
		endif
	While(!equalWaves(StateWave,ComparisonWave,1))
End

// Compares the UP state and DOWN state transitions found to the true values.  
// Pos looks at all the transitions found by a method and tries to find the closest true transitions (specificity).  Neg is the reverse (sensitivity).  
Threadsafe Function EvaluateStateSelection(theWave,method)
	Wave theWave
	String method
	
	String waveName_=NameOfWave(theWave)
	DFRef tdf=$GetWavesDataFolder(theWave,1)
	DFRef tdmf=tdf:$method
	DFRef tdManualf=tdf:Manual

	Variable i,j
	Make /o/n=0 tdmf:UpMatchesPos,tdmf:UpMatchesNeg,tdmf:DownMatchesPos,tdmf:DownMatchesNeg
	
	Wave ObservedUps=tdmf:Ups
	for(i=0;i<numpnts(ObservedUps);i+=1)
		for(j=0;j<2;j+=1)
			String upDown=StringFromList(j,"Up;Down")
			Wave True=tdManualF:$(upDown+"s")
			Wave Observed=tdmf:$(upDown+"s")
			InsertPoints 0,1,True
			True[numpnts(True)]={10000}
			Variable index=round(BinarySearchInterp(True,Observed[i])) // Nearest entry in the true list.  .  
			Wave MatchesPos=tdmf:$(upDown+"MatchesPos")
			if(numtype(index)==0)
				MatchesPos[numpnts(MatchesPos)]={Observed[i]-True[index]}
			endif
			DeletePoints 0,1,True
			DeletePoints numpnts(True)-1,1,True
		endfor
	endfor
	
	Wave TrueUps=tdManualF:Ups
	for(i=0;i<numpnts(TrueUps);i+=1)
		for(j=0;j<2;j+=1)
			upDown=StringFromList(j,"Up;Down")
			Wave True=tdManualF:$(upDown+"s")
			Wave Observed=tdmf:$(upDown+"s")
			InsertPoints 0,1,Observed
			Observed[numpnts(Observed)]={10000}
			index=round(BinarySearchInterp(Observed,True[i])) // Nearest entry in the observed list.  .  
			Wave MatchesNeg=tdmf:$(upDown+"MatchesNeg")
			if(numtype(index)==0)
				MatchesNeg[numpnts(MatchesNeg)]={True[i]-Observed[index]}
			endif
			DeletePoints 0,1,Observed
			DeletePoints numpnts(Observed)-1,1,Observed
		endfor
	endfor
	
	Wave /Z TrueStateWave=tdManualf:StateWave
	if(!WaveExists(TrueStateWave))
		UpsDowns2StateWave(theWave,tdManualf)
		Wave TrueStateWave=tdManualf:StateWave
	endif
	TrueStateWave=TrueStateWave>0 ? 1 : 0
	Wave ObservedStateWave=tdmf:StateWave
	Variable TrueFrac=mean(TrueStateWave)
	Duplicate /o ObservedStateWave tdmf:ErrorStateWave /WAVE=ErrorStateWave
	ErrorStateWave-=TrueStateWave
End

Function AccuracyReport(tolerance,type[,wave_list,methods])
	Variable tolerance // Time error that can still be counted as a correctly identified state transition.  
	String wave_list,type,methods
	
	if(ParamIsDefault(methods))
		methods=defaultMethods
	endif
	DFRef tf=root:$type
	
	Variable i,j,k,m,count=0,interpPoints=1000
	for(i=0;i<ItemsInList(methods);i+=1)
		String method=StringFromList(i,methods)
		NewDataFolder /O root:$method
		DFRef mf=root:$method
		Make /o/T/n=0 mf:DataUsed /WAVE=DataUsed
		Variable /G mf:totalPoints=0
		NVar totalPoints=mf:totalPoints
		for(j=0;j<CountObjectsDFR(mf,1);j+=1)
			Wave Report=mf:$GetIndexedObjNameDFR(mf,1,j)
			Redimension /n=0 Report // Delete all point for reports that corrrespond to previous tolerance values.  
		endfor
		Variable numData=CountObjectsDFR(tf,4)
		Make /o/n=0 mf:UpSpecificity=NaN,mf:DownSpecificity=NaN,mf:UpSensitivity=NaN,mf:DownSensitivity=NaN
		Make /o/n=0 mf:ROCAreasState /WAVE=ROCAreasState
		Make /o/n=(interpPoints) mf:MeanSensitivity=0, mf:MeanSpecificity=0
		for(j=0;j<numData;j+=1)
			String dataFolder=GetIndexedObjNameDFR(tf,4,j)
			if(!ParamIsDefault(wave_list) && strlen(wave_list)>0 && strlen(ListMatch(dataFolder,wave_list))==0) // This wave is not in the provided wave list.  
				continue
			endif
			DFRef tdf=tf:$dataFolder
			DFRef tdManualf=tdf:Manual
			if(!DataFolderRefStatus(tdManualf) || numpnts(tdManualf:Ups)==0) // No manual analysis available or no UP states in the manual analysis.  
				continue
			endif
			DFRef tdmf=tdf:$method
			
			// Analyze quality of state transition timing.  Only applies to the last threshold used.  
			for(k=0;k<2;k+=1)
				String upDown=StringFromList(k,"Up;Down")
				for(m=0;m<2;m+=1)
					String posNeg=StringFromList(m,"Pos;Neg")
					
					// For each recording.  
					Wave Matches=tdmf:$(upDown+"Matches"+posNeg)
					Extract /O Matches,tdmf:$(upDown+"Misses"+posNeg),abs(Matches)>tolerance*(3*k+1)
					Extract /O Matches,tdmf:$(upDown+"Hits"+posNeg),abs(Matches)<tolerance*(3*k+1)
					Wave Hits=tdmf:$(upDown+"Hits"+posNeg)
					Wave Misses=tdmf:$(upDown+"Misses"+posNeg)	
					
					// Overall.  
					Concatenate /NP {Matches}, mf:$(upDown+"Matches"+posNeg)
					Concatenate /NP {tdmf:$(upDown+"Misses"+posNeg)}, mf:$(upDown+"Misses"+posNeg)
					Concatenate /NP {tdmf:$(upDown+"Hits"+posNeg)}, mf:$(upDown+"Hits"+posNeg)
					Wave ROCTiming=mf:$(upDown+SelectString(StringMatch(posNeg,"Pos"),"Sensitivity","Specificity"))
					ROCTiming[numpnts(ROCTiming)]={numpnts(Hits)/(numpnts(Hits)+numpnts(Misses))}
				endfor
			endfor
			
			// Analyze quality of state classification.  
			Wave Sensitivity=tdmf:Sensitivity, Specificity=tdmf:Specificity
			Duplicate /O/FREE Sensitivity,SensitivitySorted
			Duplicate /O/FREE Specificity,SpecificitySorted
			Sort /R SensitivitySorted,SensitivitySorted
			Sort SpecificitySorted,SpecificitySorted
			InsertPoints 0,1,SensitivitySorted,SpecificitySorted
			SensitivitySorted[0]=1
			SpecificitySorted[0]=0
			SensitivitySorted[numpnts(SensitivitySorted)]={0}
			SpecificitySorted[numpnts(SpecificitySorted)]={1}
			Interpolate2 /N=(interpPoints) /T=1/Y=tdmf:SensitivityInterp SensitivitySorted; Wave SensitivityInterp=tdmf:SensitivityInterp
			Interpolate2 /N=(interpPoints) /T=1/Y=tdmf:SpecificityInterp SpecificitySorted; Wave SpecificityInterp=tdmf:SpecificityInterp
			SensitivityInterp=limit(SensitivityInterp,0,1)
			SpecificityInterp=limit(SpecificityInterp,0,1)
			
			// Compute ROC Area for this recording.  
			count+=1
			ROCAreasState[numpnts(ROCAreasState)]={1-areaXY(SpecificityInterp,SensitivityInterp,0,1)}
			if(StringMatch(dataFolder,"Roger_022105f"))
				//printz ROCAreasState[j],areaXY(SpecificityInterp,SensitivityInterp,0,1)
			endif
			Wave ErrorStateWave=tdmf:ErrorStateWave
			totalPoints+=numpnts(ErrorStateWave)
			
			// Add to mean ROC.  
			//Sort SpecificityInterp,SpecificityInterp
			Wave MeanSensitivity=mf:MeanSensitivity
			Wave MeanSpecificity=mf:MeanSpecificity
			MeanSensitivity+=SensitivityInterp
			MeanSpecificity+=SpecificityInterp
			
			DataUsed[numpnts(DataUsed)]={dataFolder}
		endfor
		MeanSensitivity/=count
		MeanSpecificity/=count
		MeanSensitivity=1-MeanSensitivity
		MeanSpecificity=1-MeanSpecificity
		
		// Sort and scale the resultant waves for a cumulative histogram.  
		//ECDF(ROCAreasState)
		for(k=0;k<2;k+=1)
			upDown=StringFromList(k,"Up;Down")
			for(m=0;m<2;m+=1)
				posNeg=StringFromList(m,"Pos;Neg")
				Wave ROCTiming=mf:$(upDown+SelectString(StringMatch(posNeg,"Pos"),"Sensitivity","Specificity"))
				//ECDF(ROCTiming)
			endfor
		endfor
	endfor
End

Function AllROCs(method)
	String method
	
	Display /K=1
	DFRef tf=root:Recordings
	Variable i,j,k,m,count=0
	DFRef mf=root:$method
	Variable numData=CountObjectsDFR(tf,4)
	for(j=0;j<numData;j+=1)
		String dataFolder=GetIndexedObjNameDFR(tf,4,j)
		DFRef tdf=tf:$dataFolder
		DFRef tdmf=tdf:$method
		Interpolate2 /N=1000 /Y=SensitivityInterp tdmf:Sensitivity
		Interpolate2 /N=1000 /Y=SpecificityInterp tdmf:Specificity
		Wave SensitivityInterp,SpecificityInterp
		SensitivityInterp=limit(SensitivityInterp,0,1)
		SpecificityInterp=limit(SpecificityInterp,0,1)
		Variable ROCarea=1-areaXY(SpecificityInterp,SensitivityInterp,0,1)
		AppendToGraph tdmf:SensitivityInterp vs tdmf:SpecificityInterp
		if(ROCarea<0)
			//AppendToGraph tdmf:SensitivityInterp vs tdmf:SpecificityInterp
			printf "Negative ROC Area %f for %s.\r",ROCArea,dataFolder
		endif
	endfor
End

Function ROC(wave_list,tolerance,type[,methods,step])
	String wave_list
	String type // Simulations or Recordings.  
	String methods // Fixed or Adaptive.  
	Variable tolerance,step
	
	if(ParamIsDefault(methods))
		methods=defaultMethods
	endif
	DFRef tf=root:$type
	
	String ranges="Fixed:0.2,15;Fixed2D:-5,10|1,3;Adaptive:0,10;Seamari:2,0|-1,-3;Volgushev:0.1,0.9;Mukovski:0"
	step=ParamIsDefault(step) ? 0.01 : step // The threshold range will be recursively bisected until the change in both Sensitivity and Specificity is < 'step'.  
	Variable minThreshDelta=1/1000 // Minimum change in the threshold, as fraction of the threshold range provided in 'ranges'.  
	Variable i,j,k,m
	Variable numMethods=ItemsInList(methods)
	for(i=0;i<numMethods;i+=1)
		Prog("i",i,numMethods,msg="Methods:"+num2str(numMethods))
		String method=StringFromList(i,methods)
		NewDataFolder /O root:$method	
		DFRef mf=root:$method
		String threshRange=StringByKey(method,ranges)
		String threshRangeReal=StringFromList(0,threshRange,"|") // Threshold in a primary parameters, such as mean.  
		String threshRangeImag=StringFromList(1,threshRange,"|") // Threshold in a secondary parameter, such as standard deviation.  

		Variable threshRealLow=str2num(StringFromList(0,threshRangeReal,","))
		Variable threshRealHigh=str2num(StringFromList(1,threshRangeReal,","))
		Variable threshImagLow=str2num(StringFromList(0,threshRangeImag,","))
		Variable threshImagHigh=str2num(StringFromList(1,threshRangeImag,","))
		if(numtype(threshImagLow))
			threshImagLow=threshRealLow
		endif
		if(numtype(threshImagHigh))
			threshImagHigh=threshRealHigh
		endif
		
		Variable numData=4//CountObjectsDFR(tf,4)
		Variable numThreads=ThreadProcessorCount
		Variable tgID=ThreadGroupCreate(numThreads)
		for(j=0;j<numThreads;j+=1)
			ThreadStart tgID,j,RecursiveROC(method,step,minThreshDelta*(threshRealHigh-threshRealLow))
		endfor
		for(j=0;j<numData;j+=1)
			Prog("j",j,numData,msg="Data:"+num2str(numData))
			String dataFolder=GetIndexedObjNameDFR(tf,4,j)
			if(strlen(wave_list) && strlen(ListMatch(dataFolder,wave_list))==0) // This wave is not in the provided wave list.  
				continue
			endif	
			DFRef tdf=tf:$dataFolder
			String tdf_=GetDataFolder(1,tdf)
			DFRef tdManualf=tdf:Manual
			if(DataFolderRefStatus(tdManualf)==0) // No manual analysis available.  
				continue
			endif
			Wave theWave=tdf:$dataFolder
//			WaveClear theWave
//			NewDataFolder /O tdf:$method
//			DFRef tdmf=tdf:$method
//			Make /o/n=0 tdmf:Specificity /WAVE=Specificity,tdmf:Sensitivity /WAVE=Sensitivity
//			Make /o/C/n=2 tdmf:Thresholds /WAVE=Thresholds={cmplx(threshRealLow,threshImagLow),cmplx(threshRealHigh,threshImagHigh)}
//				
//			Variable /C low=ROCPoint(method,theWave,tdmf,Thresholds[0])
//			Variable /C high=ROCPoint(method,theWave,tdmf,Thresholds[1])
//			Sensitivity[0]={real(low)}
//			Specificity[0]={imag(low)}
//			Sensitivity[1]={real(high)}
//			Specificity[1]={imag(high)}
		endfor
		for(j=0;j<numData;j+=1)
			dataFolder=GetIndexedObjNameDFR(tf,4,j)
			DFRef tdf=tf:$dataFolder
			tdf_=GetDataFolder(1,tdf)
			printf "Putting: %s\r",tdf_
			SetDataFolder tdf
			ThreadGroupPutDF tgID,:
		endfor
		for(j=0;j<numData;j+=1)
			Prog("j",j,numData,msg="Data:"+num2str(numData))
			Do
				tdf_= ThreadGroupGetDF(tgID,1000)
				if(strlen(tdf_)==0)
					printf "Main still waiting for worker thread results.\r"
				else
					break
				endif
			while(1)
		endfor
		//WaitForThreads(tgID)
		AccuracyReport(tolerance,type,wave_list=wave_list,methods=method)
		Variable dummy=ThreadGroupRelease(tgID)
	endfor
	SetDataFolder root:
End

Threadsafe Function RecursiveROC(method,step,minDelta)
	String method
	Variable step,minDelta 
	
	Do
		String tdf_= ThreadGroupGetDF(0,1000)
		if(strlen(tdf_) == 0)
			//printz "worker thread still waiting for input queue"
		else
			break
		endif
	While(1)
	printf "Getting: %s\r",tdf_

//	DFRef tdf=$tdf_
//	DFRef tdmf=tdf:$method	
//	Wave theWave=tdf:$tdf_
//	
//	Wave Sensitivity=tdmf:Sensitivity, Specificity=tdmf:Specificity
//	Wave /C Thresholds=tdmf:Thresholds
//	Variable i=1
//	Do
//		Variable /C lowThresh=Thresholds[i-1]
//		Variable /C highThresh=Thresholds[i]
//		Variable lowSens=Sensitivity[i-1]
//		Variable highSens=Sensitivity[i]
//		Variable lowSpec=Specificity[i-1]
//		Variable highSpec=Specificity[i]
//		if(real(highThresh)-real(lowThresh)>minDelta && highSens<1 && lowSpec<1)	
//			if(lowSens-highSens>step*(1-highSens) && highSpec-lowSpec>step*(1-lowSpec))
//				Variable /C thresh=(lowThresh+highThresh)/2
//				Variable /C oneROCpoint=ROCPoint(method,theWave,tdmf,thresh)
//				Variable sens=real(oneROCpoint)
//				Variable spec=imag(oneROCpoint)
//				//if(sens>highSens || spec>lowSpec) // Check to make sure point is not inferior to other points in both sensitivity and specificity.  
//					InsertPoints i,1,Thresholds,Sensitivity,Specificity
//					Thresholds[i]=thresh
//					Sensitivity[i]=sens
//					Specificity[i]=spec
//				//endif
//				continue
//			endif
//		endif
//		i+=1
//	While(i<numpnts(Thresholds))
//	i=0
//	Variable j,inc
//	Do
//		inc=1
//		for(j=0;j<numpnts(Thresholds);j+=1)
//			if(Sensitivity[i]<Sensitivity[j] && Specificity[i]<Specificity[j])
//				DeletePoints i,1,Sensitivity,Specificity,Thresholds
//				inc=0
//				break
//			endif
//		endfor
//		i+=inc
//	While(i<numpnts(Thresholds))
//	Variable /G tdmf:poop=3
//	WaveClear theWave,Sensitivity,Specificity,Thresholds
	SetDataFolder $tdf_
	ThreadGroupPutDF 0,:
	return 0
End

Function Test347745()
	SetDataFolder root:Temp
	Wave Se=Sensitivity,Sp=Specificity
	Wave /C Th=Thresholds
	SetDataFolder root:Recordings:Rick_2006_07_19_b_C:Adaptive
	Wave Sensitivity,Specificity
	Wave /C Thresholds
	Duplicate /o Se,Sensitivity
	Duplicate /o Sp,Specificity
	Duplicate /C/o Th,Thresholds
	Variable i=0,j,flag
	Do
		flag=0
		for(j=0;j<numpnts(Thresholds);j+=1)
			if(Sensitivity[i]<Sensitivity[j] && Specificity[i]<Specificity[j])
				DeletePoints i,1,Sensitivity,Specificity,Thresholds
				flag=1
				break
			endif
		endfor
		if(!flag)
			i+=1
		endif
	While(i<numpnts(Thresholds))
End

Function Test346734()
	Wave Test
	Variable i=0
	Do
		if(Test[i]<Test[i-1])
			DeletePoints i,1,Test
		elseif(Test[i]<Test[i+1])
			DeletePoints i,1,Test
		else
			i+=1
		endif
	While(i<numpnts(Test))
End

Threadsafe Function /C ROCPoint(method,theWave,tdmf,threshold)
	String method
	Wave theWave
	DFRef tdmf
	Variable /C threshold
	
	StateDetect(method,theWave,threshold)
	EvaluateStateSelection(theWave,method)
	Wave ErrorStateWave=tdmf:ErrorStateWave
	Extract /O/INDX ErrorStateWave,tdmf:FalsePosWave,ErrorStateWave>0
	Extract /O/INDX ErrorStateWave,tdmf:FalseNegWave,ErrorStateWave<0
	
	Variable spec=1-(numpnts(tdmf:FalsePosWave)/numpnts(ErrorStateWave))
	Variable sens=1-(numpnts(tdmf:FalseNegWave)/numpnts(ErrorStateWave))
	KillWaves /Z FalsePosWave,FalseNegWave
	return cmplx(sens,spec)
End

Function LoadUpstateData(type)
	String type
	
	strswitch(type)
		case "Simulations":
			String folder=simsDir
			break
		case "Recordings":
			folder=recordingsDir
			break
	endswitch
	Variable i=0
	NewDataFolder /O/S root:$type
	NewPath /O/Q Folder,folder
	Do
		String file=IndexedFile(Folder,i,".ibw")
		if(strlen(file)==0)
			break
		endif
		String name=RemoveEnding(file,".ibw")
		NewDataFolder /O/S $name
		LoadWave /O/Q/P=Folder file
		Wave Loaded=$name
		Resample /RATE=(analysisSamplingFreq) Loaded
		String states=note(Loaded)
		NewDataFolder /O/S Manual // In the case of simulations this will be the true values from the simulation.  
		Make /o/n=0 Ups,Downs
		Duplicate /o Loaded $"StateWave"; Wave StateWave; StateWave=0
		Variable j
		for(j=0;j<ItemsInList(states);j+=1)
			String stateTimes=StringFromList(j,states)
			Variable up=str2num(StringFromList(0,stateTimes,","))
			Variable down=str2num(StringFromList(1,stateTimes,","))
			if(down<up)
				down=rightx(Loaded)
			endif
			Ups[numpnts(Ups)]={up}
			Downs[numpnts(Downs)]={down}
			StateWave[x2pnt(StateWave,up)]+=1
			StateWave[x2pnt(StateWave,down)]-=1
		endfor
		Integrate /P StateWave
		ConsolidateStates(StateWave,consolidationWidth)
		Extract /O/INDX StateWave,Ups,(StateWave[p]-StateWave[p-1])==1
		Extract /O/INDX StateWave,Downs,(StateWave[p]-StateWave[p-1])==-1
		if(numpnts(Downs)<numpnts(Ups))
			Downs[numpnts(Downs)]={numpnts(Loaded)}
		endif
		Redimension /S Ups,Downs
		Ups*=deltax(StateWave)
		Downs*=deltax(StateWave)
		i+=1
		SetDataFolder :::
	While(1)
	SetDataFolder root:
End

Threadsafe Function UpsDowns2StateWave(Data,f)
	Wave Data
	DFRef f
	
	Wave Ups=f:Ups, Downs=f:Downs
	Duplicate /o Data f:StateWave /WAVE=StateWave; StateWave=0
	Variable j
	for(j=0;j<numpnts(Ups);j+=1)
		StateWave[x2pnt(StateWave,Ups[j])]+=1
		StateWave[x2pnt(StateWave,Downs[j])]-=1
	endfor
	Integrate /P StateWave
	ConsolidateStates(StateWave,consolidationWidth)
//	Extract /O/INDX StateWave,Ups,(StateWave[p]-StateWave[p-1])==1
//	Extract /O/INDX StateWave,Downs,(StateWave[p]-StateWave[p-1])==-1
//	if(numpnts(Downs)<numpnts(Ups))
//		Downs[numpnts(Downs)]={numpnts(Loaded)}
//	endif
//	Redimension /S Ups,Downs
//	Ups*=deltax(StateWave)
//	Downs*=deltax(StateWave)
End

static Function Test124()
	Variable k
	for(k=0;k<10;k+=1)
		Variable /G root:adaptiveBinSize=0.25+0.2*k
		ROC("",0.5,"Recordings",methods="Adaptive")
		Duplicate /o root:Adaptive:Sensitivity root:$("Sensitivity_"+num2str(k))
		Duplicate /o root:Adaptive:Specificity root:$("Specificity_"+num2str(k))
		DoUpdate
	endfor
End

static Function Test125()
	Variable k
	Display /K=1
	for(k=0;k<10;k+=1)
		AppendToGraph root:$("Sensitivity_"+num2str(k)) vs root:$("Specificity_"+num2str(k))
	endfor
	SetAxis left 0.75,1
	SetAxis bottom 1,0.75
End

////////////////////////////////////////////////

Function MakeFig(name,panelsStr,args)
	String name, panelsStr, args
	
	NewFolder(IMW_Folder_,go=1)
	Make /o/T/n=(ItemsInList(panelsStr)) Panels="Fig"+StringFromList(p,panelsStr), Folders
	Folders="root:"+(Panels[p])[0,strlen(Panels[p])-2]+":"+(Panels[p])[strlen(Panels[p])-1,strlen(Panels[p])-1]
	
	// Kill old graphs and create new blank ones.  
	Variable i
	for(i=0;i<numpnts(Panels);i+=1)
		DoWindow /K $Panels[i]
		Display /N=$Panels[i]
		SetWindow kwTopWin userData+="MakeFig("+name+","+panelsStr+","+args+")"
	endfor
	
	strswitch(name)
		default: 
			FuncRef ProtoFig f=$name
			f(args)
			break
	endswitch	
	
	// Apply preferences to new panels.  
	for(i=0;i<numpnts(Panels);i+=1)
		ModifyGraph /W=$Panels[i] fsize=9, fstyle=1 
	endfor
End

Function ProtoFig(args)
	String args
End

Function ROCMethods(args)
	String args
	
	SetDataFolder $IMW_Folder_
	Wave /T Panels,Folders
	Variable i
	
	// Initialize folders and waves.  
	String folder=Folders[0]
	NewFolder(folder+":Fixed",go=1)
	NewFolder(folder+":Adaptive",go=1)
	
	String type=StringByKey("TYPE",args)
	ROC("",1,type,methods="Fixed;Adaptive") // Uncomment this line if it hasn't been run before.  
	NewDataFolder /O Fixed
	NewDataFolder /O Adaptive
	Duplicate /o root:Fixed:Sensitivity $(folder+":Fixed:Sensitivity")
	Duplicate /o root:Fixed:Specificity $(folder+":Fixed:Specificity")
	Duplicate /o root:Adaptive:Sensitivity $(folder+":Adaptive:Sensitivity")
	Duplicate /o root:Adaptive:Specificity $(folder+":Adaptive:Specificity")
	
	SetDataFolder $folder
	AppendToGraph /c=(0,0,0) :Fixed:Sensitivity vs :Fixed:Specificity
	AppendToGraph /c=(65535,0,0) :Adaptive:Sensitivity vs :Adaptive:Specificity
	ModifyGraph mode=4,marker=19
	Label left "Sensitivity"
	Label bottom "Specificity"
	SetAxis left 0.92,1
	SetAxis bottom 1,0.45
End

Function HitsMatches(args)
	String args
	String type=StringByKey("TYPE",args)
	AnalyzeWaves(type,"2.5;3") // Must uncomment this line if it has not already been run.   
	
	SetDataFolder $IMW_Folder_
	Wave /T Panels,Folders
	Variable i
	
	// Initialize folders and waves.  
	NewFolder(Folders[0],go=1)
	Make /o/n=(2,2) FixedErrors,FixedErrorsSEM,AdaptiveErrors,AdaptiveErrorsSEM // First column is false positive errors, second column is false negative errors.  
	Make /o/n=2/T Labels={"UP","DOWN"}
	
	NewFolder(Folders[1],go=1)
	Make /o/n=(2,2) FixedDeviation,FixedDeviationSEM,AdaptiveDeviation,AdaptiveDeviationSEM
	Make /o/n=2/T Labels={"UP","DOWN"}
	
	// Begin processing.  
	Variable k,m,tolerance=NumberByKey("TOLERANCE",args)
	tolerance=numtype(tolerance) ? 1 : tolerance
	AccuracyReport(tolerance,type)
	
	String methods="Fixed;Adaptive"
	for(i=0;i<ItemsInList(methods);i+=1)
		String method=StringFromList(i,methods)
		for(k=0;k<2;k+=1)
			String upDown=StringFromList(k,"Up;Down")
			for(m=0;m<2;m+=1)
				SetDataFolder root:$method
				String posNeg="Pos";//StringFromList(m,"Pos;Neg") // WE ARE ONLY USING FALSE NEGATIVE ERRORS.  
				Wave Hits=$(upDown+"Hits"+posNeg)
				Wave Misses=$(upDown+"Misses"+posNeg)
				Wave Matches=$(upDown+"Matches"+posNeg)
				SetDataFolder $Folders[0]
				Wave ErrorRate=$(method+"Errors")
				Wave ErrorRateSEM=$(method+"ErrorsSEM")
				ErrorRate[k][m]=numpnts(Misses)/numpnts(Matches)
				ErrorRateSEM[k][m]=sqrt(ErrorRate[k][m]*(1-ErrorRate[k][m])/numpnts(Matches))
				SetDataFolder $Folders[1]
				Wave Deviation=$(method+"Deviation")
				Wave DeviationSEM=$(method+"DeviationSEM")
				if(numpnts(Hits))
					WaveStats /Q Hits
					Deviation[k][m]=V_avg
					DeviationSEM[k][m]=V_sdev/sqrt(V_npnts)
				else
					Deviation[k][m]=0
					DeviationSEM[k][m]=0
				endif
			endfor
			// Consolidate false positive and false negative errors into the first column.  
			ErrorRate[k][0]+=ErrorRate[k][1]
			ErrorRateSEM[k][0]=(ErrorRateSEM[k][0]+ErrorRateSEM[k][1])/2
			Deviation[k][0]+=Deviation[k][1]
			DeviationSEM[k][0]+=(DeviationSEM[k][0]+DeviationSEM[k][1])/2
		endfor
	endfor
	
	// Append data to graphs.
	DoWindow /F $Panels[0]  
	AppendToGraph /c=(0,0,0) FixedErrors[][0] vs $(Folders[0]+":Labels")
	AppendToGraph /c=(65535,0,0) AdaptiveErrors[][0] vs $(Folders[0]+":Labels")
	ErrorBars FixedErrors Y,wave=(FixedErrorsSEM[][0],FixedErrorsSEM[][0])
	ErrorBars AdaptiveErrors Y,wave=(AdaptiveErrorsSEM[][0],AdaptiveErrorsSEM[][0])
	SetAxis left 0,0.4
	Label left "Error Rate (%)"
	ModifyGraph prescaleExp(left)=2
	
	DoWindow /F $Panels[1]  
	AppendToGraph /c=(0,0,0) FixedDeviation[][0] vs $(Folders[1]+":Labels")
	AppendToGraph /c=(65535,0,0) AdaptiveDeviation[][0] vs $(Folders[1]+":Labels")
	ErrorBars FixedDeviation Y,wave=(FixedDeviationSEM[][0],FixedDeviationSEM[][0])
	ErrorBars AdaptiveDeviation Y,wave=(AdaptiveDeviationSEM[][0],AdaptiveDeviationSEM[][0])
	SetAxis left -0.4,1.2
	Label left "Deviation (ms)"
	ModifyGraph prescaleExp(left)=3
End

Function ComparePairs(args)
	String args
	
	SetDataFolder $IMW_Folder_
	Wave /T Panels,Folders
	Variable i
	
	// Initialize folders and waves.  
	NewFolder(Folders[0],go=1)
	Make /o/n=(2,2) OnlyOne // First column is mean, second column is SEM.  First row is fixed, second row is adaptive.  
	Make /o/n=2/T Labels={"Fixed","Adaptive"}
	Make /o/n=(2,3) Colors={{0,65535},{0,0},{0,0}}
	
	NewFolder(Folders[1],go=1)
	Make /o/n=(2,2) FixedDifference,AdaptiveDifference // First row is UP, second row is DOWN.  
	Make /o/n=2/T Labels={"UP","DOWN"}
	
	// Determine which pairs of recordings belong together (paired recordings).  
	SetDataFolder $Folders[0]
	SetDataFolder ::
	Make /o/T/n=(0,2) Pairs // Each row will be one simultaneously recorded pair.  
	SetDataFolder root:Recordings
	Variable j,recordings=CountObjects("",4)
	for(i=0;i<recordings;i+=1)
		String recording=GetIndexedObjName("",4,i)
		if(StringMatch(recording,"*_G"))
			String pair=RemoveEnding(recording,"_G")
		elseif(StringMatch(recording,"*_NG"))
			pair=RemoveEnding(recording,"_NG")
		else
			continue
		endif
		Variable paired=0
		for(j=0;j<dimsize(Pairs,0);j+=1)
			if(StringMatch(Pairs[j][0],pair+"*"))
				Pairs[j][1]=recording
				paired=1
			endif
		endfor
		if(!paired)
			Pairs[j][0]={recording}
		endif
	endfor
	
	// Determine what the conflict rate is between UP and DOWN occupancies in pairs.  
	//AnalyzeWaves("recordings","2",methods="adaptive") // Must uncomment this line if it has not already been run.   
	String methods="Fixed;Adaptive"
	SetDataFolder $Folders[0]
	for(i=0;i<ItemsInList(methods);i+=1)
		String method=StringFromList(i,methods)
		Make /o/n=0 $(method+"ConflictRate"); Wave ConflictRate=$(method+"ConflictRate")
		for(j=0;j<dimsize(Pairs,0);j+=1)
			String cell1=Pairs[j][0]
			String cell2=Pairs[j][1]
			Wave StateWave1=root:Recordings:$(cell1):$(method):StateWave
			Wave StateWave2=root:Recordings:$(cell2):$(method):StateWave
			Variable numPoints=numpnts(StateWave1)+numpnts(StateWave2)
			Extract /o/INDX StateWave1,$"ConflictWave",StateWave1!=StateWave2
			Wave ConflictWave=$"ConflictWave"
			ConflictRate[j]={numpnts(ConflictWave)/(numpnts(StateWave1))}
		endfor
		WaveStats /Q ConflictRate
		OnlyOne[i][0]=V_avg
		OnlyOne[i][1]=V_sdev/sqrt(V_npnts)
	endfor
	KillWaves /Z ConflictWave
	
	// Determine the difference in UP and DOWN transition times in pairs.  
	AnalyzeWaves("recordings","1.3",methods="adaptive") // Must uncomment this line if it has not already been run.   
	SetDataFolder $Folders[1]
	Variable k
	for(i=0;i<ItemsInList(methods);i+=1)
		method=StringFromList(i,methods)
		Wave Difference=$(method+"Difference")
		for(k=0;k<2;k+=1)
			String upDown=StringFromList(k,"Up;Down")
			Make /o/n=0 $(method+upDown+"Deviations"); Wave Deviations=$(method+upDown+"Deviations")
			for(j=0;j<dimsize(Pairs,0);j+=1)
				cell1=Pairs[j][0]
				cell2=Pairs[j][1]
				Wave Trans1=root:Recordings:$(cell1):$(method):$(upDown+"s")
				Wave Trans2=root:Recordings:$(cell2):$(method):$(upDown+"s")
				Make /o/n=(numpnts(Trans1),numpnts(Trans2)) $(upDown+"sMatrix")=Trans1[p]-Trans2[q]
				Wave TransMatrix=$(upDown+"sMatrix")
				//Edit TransMatrix
				//abort
				Extract /o TransMatrix,$(upDown+"Deviants"),abs(TransMatrix)<(1+2*k)
				Wave Deviants=$(upDown+"Deviants")
				Deviants=abs(Deviants)
				Concatenate /NP {Deviants}, $(method+upDown+"Deviations")
				KillWaves /Z TransMatrix,$(upDown+"Deviants")
			endfor
			WaveStats /Q Deviations
			Difference[k][0]=V_avg
			Difference[k][1]=V_sdev/sqrt(V_npnts)
		endfor
	endfor
	
	//WaveStat2(root:Fig3:D:AdaptiveUpDeviations)
	//WaveStat2(root:Fig3:D:AdaptiveDownDeviations)
	//return 0
	
	DoWindow /F $Panels[0]
	AppendToGraph OnlyOne[][0] vs $(Folders[0]+":Labels")
	ErrorBars OnlyOne Y,wave=(OnlyOne[][1],OnlyOne[][1]) 
	ModifyGraph zColor(OnlyOne)={Colors,*,*,directRGB,0}
	SetAxis left 0,0.65
	ModifyGraph prescaleExp(left)=2
	Label left "Conflict Rate (%)"
	
	DoWindow /F $Panels[1]
	AppendToGraph /c=(0,0,0) FixedDifference[][0] vs $(Folders[1]+":Labels")
	AppendToGraph /c=(65535,0,0) AdaptiveDifference[][0] vs $(Folders[1]+":Labels")
	ErrorBars FixedDifference Y,wave=(FixedDifference[][1], FixedDifference[][1])
	ErrorBars AdaptiveDifference Y,wave=(AdaptiveDifference[][1], AdaptiveDifference[][1])
	SetAxis left 0,1.2
	ModifyGraph prescaleExp(left)=3
	Label left "Deviation from partner (ms)"
End

// Makes two panels, one with Z-score distribution for recordings, one with Z-score distribution for first differences of those recordings.  
Function OverlappingGaussians(args)
	String args
	
	SetDataFolder $IMW_Folder_
	Wave /T Panels,Folders
	Variable i
	
	// Initialize folders and waves.  
	NewFolder(Folders[0],go=1)
	NewFolder(Folders[1],go=1)
	NewFolder(Folders[2],go=1)
	NewFolder(Folders[3],go=1)
	
	String wave_list=StringByKey("WAVES",args,"=")
	for(i=0;i<ItemsInList(wave_list,",");i+=1)
		String wave_name=StringFromList(i,wave_list,",")
		Wave theWave=$wave_name
		SetDataFolder $Folders[0]
		String name=NameOfWave(theWave)
		Duplicate /o theWave $(name+"_ds"); Wave WorkingWave=$(name+"_ds")
		Resample /RATE=100 WorkingWave
		
		// Non-differentiated wave.  
		Make /o/n=1000 $(name+"_Hist"),$(name+"_HistRaw"); Wave Hist=$(name+"_Hist"),HistRaw=$(name+"_HistRaw")
		Differentiate /METH=1 WorkingWave /D=$(name+"_dds"); Wave WorkingWaveD=$(name+"_dds")
		RunningMeanStDev(WorkingWave,winSize=1,pauseOn={{2,1},{2,1}})
		Wave Meann,StanDev,DMeann,DStanDev
		SetScale x,-57,-45,HistRaw
		Histogram /B=2 WorkingWave, HistRaw
		WorkingWave=(WorkingWave-Meann)/StanDev
		//Duplicate /o Updating $(name+"_Updating")
		SetScale x,-10,10,Hist
		Histogram /B=2 WorkingWave, Hist
		AppendToGraph /c=(65535*(i==0),65535*(i==1),65535*(i==2)) /W=$Panels[0] HistRaw
		AppendToGraph /c=(65535*(i==0),65535*(i==1),65535*(i==2)) /W=$Panels[1] Hist
		
		// Differentiated wave.  
		SetDataFolder $Folders[1]
		Make /o/n=1000 $(name+"_dHist"),$(name+"_dHistRaw"); Wave dHist=$(name+"_dHist"),dHistRaw=$(name+"_dHistRaw")
		//Wave DMeann=$(Folders[0]+":DMeann"),DStanDev=$(Folders[0]+":DStanDev")
		SetScale x,-150,150,dHistRaw
		Histogram /B=2 WorkingWaveD, dHistRaw
		WorkingWaveD=(WorkingWaveD-DMeann)/DStanDev
		SetScale x,-10,10,dHist
		Histogram /B=2 WorkingWaveD, dHist
		AppendToGraph /c=(65535*(i==0),65535*(i==1),65535*(i==2)) /W=$Panels[2] dHistRaw
		AppendToGraph /c=(65535*(i==0),65535*(i==1),65535*(i==2)) /W=$Panels[3] dHist
	endfor
	ModifyGraph /Z/W=$Panels[1] muloffset(SpikeLessExample_Hist)={0,1.6}, muloffset(ControlExample_Hist)={0,0.9}
	ModifyGraph /Z/W=$Panels[3] muloffset(SpikeLessExample_dHist)={0,1.6}, muloffset(ControlExample_dHist)={0,0.9}
	Label /W=$Panels[0] left "p(V\Bm\M)"
	Label /W=$Panels[0] bottom "V\Bm\M (mV)"
	Label /W=$Panels[1] left "p(Z)*p(UP)"
	Label /W=$Panels[1] bottom "Z"
	Label /W=$Panels[2] left "p(dV\Bm\M/dt)"
	Label /W=$Panels[2] bottom "dV\Bm\M/dt (mV/s)"
	Label /W=$Panels[3] left "p(Z') * p(UP)"
	Label /W=$Panels[3] bottom "Z'"
	SetAxis /W=$Panels[1] bottom,-5,10
	SetAxis /W=$Panels[3] bottom,-10,10
End



