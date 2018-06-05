
// $Author: rick $
// $Rev: 633 $
// $Date: 2013-03-28 15:53:22 -0700 (Thu, 28 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.
static strconstant module=Acq

Menu "Analysis", dynamic
	"----------------------"
	"Quick Stats", WaveStat()
	"Cut", Cut()
	SubMenu "Cursors"
		"New",  /Q, Cursors()
		"Save", /Q, SaveCursorsDialog()
		ListSavedCursors(), /Q, RestoreCursors("*menu*")
	End
	"Simple Wave Average", /Q, AverageWaves()
End

Menu "Table"
	Submenu "CDF"
		"New", ShowECDF()
		"Append",ShowECDF(append_=1)
	End
End

Menu "Notebook"
	"Add line to analysis", Notebook_AddLineToAnalysis()
End

//Menu "More", dynamic
//	"Cursors",  /Q, Cursors()
//	"Cursor Statistics", /Q, CursorStats()
//	"Full Sampling", /Q, ReplaceWithFullSampling()
//	"Log2Clip", /Q, Log2Clip()
//	"Show Minis", ShowMinis()
//	"Complete Mini Analysis", CompleteMiniAnalysis(sweep_list=AllSweepsWithoutStimuli())
//	"Reverberation Printout", /Q, ReverbPrintoutManager()
//	//"Reverberation Analysis Panel", ReverbAnalysisPanel()
//	"Create Printout",Printout()
//	//"Sweep Param Panel", /Q, LoadSweepParamPanel()
//	"Reduce All",ReduceAllDWT()
//	"Reductions -> Access",Reductions2Access()
//	"Experiment Browser",/Q,EB_MakeWindow()
//	"Backwards Compatibility",BackwardsCompatibility()
//	//"Printout",PrintoutManager()
//End

Function /wave Sweeps2Matrix2(df)
	dfref df
	
	variable i
	make /o/n=0 df:sweeps /wave=sweeps,df:sweepNums /wave=sweepNums
	string list=Core#Dir2("waves",df=df,match="sweep*")
	list=sortlist(list,";",16)
	list=RemoveFromList("sweeps",list)
	list=RemoveFromList("sweepNums",list)
	for(i=0;i<itemsinlist(list);i+=1)
		string item=stringfromlist(i,list)
		wave sweep=df:$item
		variable num
		sscanf item,"sweep%d",num
		variable maxPoints=max(dimsize(sweeps,0),dimsize(sweep,0))
		redimension /n=(maxPoints,i+1) sweeps
		sweeps[][i]=sweep[p]
		sweepNums[i]={num}
	endfor
	return sweeps
End

Function Notebook_AddLineToAnalysis()
	GetSelection notebook,LogPanel#ExperimentLog,2
	Notebook LogPanel#ExperimentLog selection={(V_startParagraph,0),(V_endParagraph,0)}
	if(V_startParagraph==V_endParagraph && V_startPos==V_endPos) // If nothing is selected.  
		Notebook LogPanel#ExperimentLog selection={startOfParagraph,endOfParagraph}
		GetSelection notebook,LogPanel#ExperimentLog,2 // Select the line where the cursor is.  
	endif
	
End

Function ShowECDF([append_])
	Variable append_ // 1 to append to the top graph, 0 to make a new graph.  
	
	String info=SelectedColumns()
	Variable i
	if(!append_)
		Display /K=1 /N=ECDF
	endif
	for(i=0;i<ItemsInList(info);i+=1)
		String wave_info=StringFromList(i,info)
		String wave_name=StringFromList(0,wave_info,"=")
		String wave_range=StringFromList(1,wave_info,"=")
		Variable left,right
		sscanf wave_range,"%d,%d",left,right
		Duplicate /o/R=[left,right] $wave_name $(wave_name+"_cdf") /WAVE=CDF
		ECDF(CDF)
		AppendToGraph /VERT CDF
		WaveClear CDF
	endfor
	if(!append_)
		Label left "Cumulative Probability"
	endif
End

// Returns a list of columns selected in the table 'table'.  
Function /S SelectedColumns([table])
	String table
	
	if(ParamIsDefault(table))
		table=WinName(0,2)
	endif
	String info=TableInfo(table,-2)
	String selection=StringByKey("SELECTION",info)
	Variable left,top,right,bottom
	sscanf selection,"%d,%d,%d,%d",top,left,bottom,right
	Variable i
	String selected=""
	for(i=left;i<=right;i+=1)
		info=TableInfo(table,i)
		String wave_name=StringByKey("WAVE",info)
		selected=ReplaceStringByKey(wave_name,selected,num2str(top)+","+num2str(bottom),"=")
	endfor
	return selected
End

// Extract spikes (waveforms and times) from patch-clamp recording.  
Function PatchSpikes(sweepList[,channel,eventChannel,wholeCell])
	String sweepList // List of sweeps to use, e.g. "25-34;37-58"
	String channel // e.g. "Patch"
	String eventChannel // e.g. "Odor"
	Variable wholeCell // 1 if whole-cell, 0 if cell-attached.  
	
	channel=SelectString(ParamIsDefault(channel),channel,"Patch")
	eventChannel=SelectString(ParamIsDefault(channel),channel,"Odor")
	sweepList=ListExpand(sweepList)
	Wave SweepT=root:SweepT
	Make /o/n=(32,0) $(channel+"_Spikes") /WAVE=Spikes
	Make /o/n=0 $(channel+"_Spikes_t") /WAVE=Times
	Make /o/n=0 $(channel+"_Spikes_e") /WAVE=Events
	Wave StimulusHistory=root:$(eventChannel):StimulusHistory
	Variable i,j
	for(i=0;i<ItemsInList(sweepList);i+=1)
		Variable sweepNum=NumFromList(i,sweepList)
		Wave /Z RawSweep=root:$(channel):$("sweep"+num2str(sweepNum))
		if(!WaveExists(RawSweep))
			continue
		endif
		if(wholeCell)
		else
			Duplicate /o/FREE RawSweep,Sweep
			Variable meann=mean(Sweep)
			Sweep-=meann
			Variable Hz=1/dimdelta(Sweep,0)
			FilterIIR /LO=(2000/Hz) /HI=(200/Hz) Sweep // 200-2000 Hz
			Smooth /M=0 5,Sweep // Median filter to remove blips.  
			Variable med=StatsMedian(Sweep)
			Sweep-=med
			WaveStats /Q/M=1 Sweep
			FindLevels /Q/EDGE=2 Sweep,V_min/2 // 1/2 the amplitude of the largest spike.    
			Wave W_FindLevels
			for(j=0;j<numpnts(W_FindLevels);j+=1)
				Variable point=x2pnt(Sweep,W_FindLevels[j])
				Redimension /n=(32,dimsize(Spikes,1)+1) Spikes
				Spikes[][dimsize(Spikes,1)-1]=Sweep[point-8+p]
			endfor
			W_FindLevels+=SweepT[sweepNum]*60
			Concatenate /NP {W_FindLevels}, Times
			Events[numpnts(Events)]={SweepT[sweepNum]*60 + StimulusHistory[sweepNum][%Begin][0]/1000}
		endif
	endfor
	Duplicate /o Times $(channel+"_Spikes_c") /WAVE=Clusters
	Clusters=0 // All the same cell.  
End

function PatchSpikes2(w,thresh)
	wave w
	variable thresh
	
	duplicate /free w, absw
	absw=abs(w)
	findlevels /q/edge=1/m=0.0025 absw, thresh
	wave w_findlevels
	variable kHz=0.001/dimdelta(w,0)
	variable numSpikes=numpnts(w_findlevels)
	variable spikeWindow=0.002 // Spike window (snippet) size in s.  
	make /o/n=(spikeWindow*1000*kHz,numSpikes) spikeMatrix  
	setscale x,-spikeWindow/2,spikeWindow/2,spikeMatrix
	spikeMatrix=w(w_findlevels[q]-x)
	make /o/n=(numSpikes,4) features
	variable i,j
	for(i=0;i<numSpikes;i+=1)
		variable start=w_findlevels[i]-spikeWindow/2
		variable stop=w_findlevels[i]+spikeWindow/2-0.001/kHz
		wavestats /q/r=(start,stop) w
		features[i][0]=v_max
		features[i][1]=v_min
		features[i][2]=v_maxloc-v_minloc
		features[i][3]=v_rms^2
	endfor
	
	string featureList="Max;Min;Width;Energy"
	display /k=1
	for(i=0;i<dimsize(features,1);i+=1)
		for(j=0;j<i;j+=1)
			appendtograph /l=$("left"+num2str(i)) /b=$("bottom"+num2str(j)) features[][i] vs features[][j]
			label $("left"+num2str(i)) stringfromlist(i,featureList)
			label $("bottom"+num2str(j)) stringfromlist(j,featureList)
		endfor
	endfor
	ModifyGraph mode=2,lsize=2
	ModifyGraph lblPos=90
	TileAxes(pad={0.1,0,0,0.1},box=1)
end

Function StimHistory()
	String used_channels=UsedChannels()
	Variable i
	for(i=0;i<ItemsInList(used_channels);i+=1)
		string channel=StringFromList(i,used_channels)
		variable chan=Label2Chan(channel)
		wave /Z w=GetChanHistory(chan)
		if(WaveExists(w))
			Edit /K=1 w.ld as "History for "+channel
			wave sweepT=GetSweepT()
			AppendToTable sweepT
			ModifyTable size=7, width=35
		endif
	endfor
End

// Creates a list of regions (in x-values) for which there could be a stimulus artifact, e.g. "0.299,0.305;0.799,0.805;"
Function /S StimulusRegionList(channel,sweepNum[,includeGaps,left,right1,right2])
	String channel
	Variable includeGaps // Include the regions between pulses.  
	Variable sweepNum,left,right1,right2
	
	String allChannels=UsedChannels()
	left=ParamIsDefault(left) ? 0.001 : left // left should be about 1 ms before the stimulus to ensure that the artifact is blocked, or more if there is downsampling.  
	right1=ParamIsDefault(right1) ? 0.001 : right2 // right1 should be about 1 ms to block the small off-channel artifact.  
	right2=ParamIsDefault(right2) ? 0.03 : right2 // right2 should be about 0.03 seconds to block the whole artifact, or less if you really want to see responses immediately after the stimulus.  
	variable i,stim,right // right1 is to block the stimulus artifacts on other channels, and right2 on the channel on which the stimulus was given.  
	string maskList=""
	for(i=0;i<ItemsInList(allChannels);i+=1)
		string oneChannel=StringFromList(i,allChannels)
		dfref chanDF=GetChannelDF(oneChannel)
		variable chan=Label2Chan(oneChannel)
		wave /z SweepParams=GetChanHistory(chan)
		if(!waveexists(SweepParams))
			continue
		endif	
		if(StringMatch(channel,oneChannel))
			right=right2
			chan=Label2Chan(channel)
			string mode=SweepAcqMode(chan,sweepNum)
			dfref df=Core#InstanceHome(module,"acqModes",mode)
			if(!datafolderrefstatus(df))
				printf "Could not find stimulus regions for mode %s.\r",mode
			else
				nvar /z/sdfr=df testPulseAmpl,testPulseLength,testPulseStart
				if(nvar_exists(testPulseAmpl) && testPulseAmpl!=0)
					maskList=AddRegionToMaskList(maskList,testPulseStart,1,0,testPulseLength,left,right,includeGaps) // Add the test pulse to the stimulus region.  
				endif
			endif
		else
			right=right1
		endif
		if(SweepParams[sweepNum][%Ampl]>0)
			Variable pulses=SweepParams[sweepNum][%Pulses]
			Variable begin=SweepParams[sweepNum][%Begin]/1000
			Variable IPI=SweepParams[sweepNum][%IPI]/1000
			Variable width=SweepParams[sweepNum][%Width]/1000
			maskList=AddRegionToMaskList(maskList,begin,pulses,IPI,width,left,right,includeGaps)
		endif
		
	endfor
	return maskList
End

Function /S AddRegionToMaskList(maskList,begin,pulses,IPI,width,left,right,includeGaps)
	String maskList
	Variable begin,pulses,IPI,width,left,right,includeGaps
	
	if(includeGaps) // Include intra-pulse regions in the mask list.  
		Variable start=begin-left
		Variable finish=begin+IPI*(pulses-1)+width+right	
		maskList+=num2str(start)+","+num2str(finish)+";"
	else
		Variable stim
		for(stim=0;stim<pulses;stim+=1)
			start=begin+IPI*stim-left
			finish=begin+IPI*stim+width+right
			maskList+=num2str(start)+","+num2str(finish)+";"
		endfor
	endif
	return maskList
End

// Replaces stimulus artifacts with interpolated values from adjacent areas of the wave.  
Function RemoveStimulusArtifacts(channel,sweep[,w,left,right,channels])
	string channel
	variable sweep,left,right
	string channels // Remove stimulus artifacts from stimulation of cell 'channel'; by default, remove stimulus artifacts produced by all cells.    
	wave /z w // Optional wave to operate on, instead of the wave determined by 'channel' and 'sweep'.  
	
	if(paramisdefault(w))
		wave w=GetChannelSweep(channel,sweep)
	endif
	if(paramisdefault(channels))
		channels=channel
	elseif(stringmatch(channels,"All"))
		channels=ChanLabels()
	endif
	variable numChannels=GetNumChannels()
	left=ParamIsDefault(left) ? 0.001 : left
	right=ParamIsDefault(right) ? 0.010 : right
	WaveStats /Q/M=1 w
	variable i,j,count,duration_clipped=V_numNaNs
	make /free/n=0 starts,finishes
	for(i=0;i<itemsinlist(channels);i+=1)
		string source=stringfromlist(i,channels)
		dfref df=GetChannelDF(source)
		wave SweepParams=GetChannelHistory(source)
		if(SweepParams[sweep][%Ampl]>0)
			variable pulses=SweepParams[sweep][%Pulses]
			variable begin=SweepParams[sweep][%Begin]/1000
			variable IPI=SweepParams[sweep][%IPI]/1000
			variable width=SweepParams[sweep][%Width]/1000
			for(j=0;j<pulses;j+=1)
				starts[count]={begin+IPI*j-left}
				finishes[count]={begin+IPI*j+width+right}
				count+=1
				//w[start,finish]=NaN
			endfor	
		endif
	endfor
	dfref df=GetChannelDF(channel)
	wave SweepParams=GetChannelHistory(channel)
	if(SweepParams[sweep][%TestPulseOn]>0)
		variable chan=Label2Chan(channel)
		string mode=SweepAcqMode(chan,sweep)
		variable testPulseLength=Core#VarPackageSetting(module,"acqModes",mode,"testPulseLength")
		variable testPulseAmpl=Core#VarPackageSetting(module,"acqModes",mode,"testPulseAmpl")
		variable testPulseStart=Core#VarPackageSetting(module,"acqModes",mode,"testPulseStart")
		if(testPulseAmpl)
			starts[count]={testPulseStart-left}
			finishes[count]={testPulseStart+testPulseLength+right}
			count+=1
		endif
	endif
	
	// Consolidate regions.  
	do
		variable changes=0
		do
			do
				if(starts[j]>=starts[i])
					if(finishes[j]<=finishes[i])
						deletepoints j,1,starts,finishes			
						changes+=1
					elseif(starts[j]<=finishes[i])
						finishes[i]=max(finishes[i],finishes[j])
						deletepoints j,1,starts,finishes			
						changes+=1
					endif
				endif
			while(j<numpnts(starts))
		while(i<numpnts(starts))
	while(changes>0)
	
	for(i=0;i<numpnts(starts);i+=1)
		SuppressRegion(100,w=w,x1=starts[i],x2=finishes[i])
		duration_clipped+=finishes[i]-starts[i]
	endfor			
	return duration_clipped
End

Function SuppressTestPulse(channel,sweep)
	string channel
	variable sweep
	
	wave /z w=GetChannelSweep(channel,sweep,quiet=1)
	if(!waveexists(w))
		return -1
	endif
	
	SuppressRegion(100,w=w,x1=0.03,x2=0.05)
	SuppressRegion(100,w=w,x1=0.13,x2=0.15)
	wavestats /q/m=1/r=(0,0.03) w
	variable before=v_avg
	wavestats /q/m=1/r=(0.05,0.13) w
	variable during=v_avg
	wavestats /q/m=1/r=(0.15,0.18) w
	variable after=v_avg
	Bend(before-during,w=w,x1=0.03,x2=0.05)
	Bend(during-after,w=w,x1=0.13,x2=0.15)
End

// Returns a list of methods using the code in case 'method'.  Usually this will be a list with one element, the same as the input.  
Function /S MethodList(method)
	string method
	
	variable i
	string methods=ListAcqMethods()
	string matchingMethods=""
	for(i=0;i<ItemsInList(methods);i+=1)
		string oneMethod=StringFromList(i,methods)
		string sourceMethod=Core#StrPackageSetting(module,"analysisMethods",oneMethod,"method")
		if(stringMatch(sourceMethod,method))
			matchingMethods+=oneMethod+";"
		endif
	endfor
	return matchingMethods
End

Function AverageWaves()
	if(!StringMatch(WinName(0,1),"AverageWavesWin*")) // If an average wave window is not already in front.   
		Display /K=1 /N=AverageWavesWin as "Average Waves" // Make a new one.  
	else
		// Do nothing.  Append to the average window which is currently in front.  
	endif
	
	String analysisWin="AnalysisWin"
	
	variable first=GetCursorSweepNum("A")
	variable last=GetCursorSweepNum("B")
	if(last<first)
		Variable temp=first
		first=last
		last=temp
	endif
	Wave /Z Ampl=CsrWaveRef(A,analysisWin)
	if(!waveexists(Ampl))
		DoAlert 0,"Please place a cursor on a plot in the Analysis Window."
		return -1
	endif
	Variable red,green,blue
	GetTraceColor(CsrWave(A,analysisWin),red,green,blue,win=analysisWin)
	String folder=GetWavesDataFolder(Ampl,1)
	Variable i,j,count=0
	ControlInfo /W=SweepsWin range
	variable use_range = v_value
	for(i=first;i<=last;i+=1)
		Wave /Z Sweep=$(folder+"sweep"+num2str(i))
		if(WaveExists(Sweep))
			if(use_range)
				variable present = 0
				string traces = tracenamelist("SweepsWin",";",1)
				for(j=0;j<itemsinlist(traces);j+=1)
					string trace = stringfromlist(j,traces)
					wave w = TraceNameToWaveRef("SweepsWin",trace)
					if(stringmatch(getwavesdatafolder(w,2),getwavesdatafolder(sweep,2)))
						present = 1
					endif
				endfor
				if(!present)
					continue
				endif
			endif
			AppendToGraph /c=((65535+red)/2,(65535+green)/2,(65535+blue)/2) Sweep
			if(count==0)
				String avgSweepName
				sprintf avgSweepName,"AvgSweep_%d_%d",first,last
				Duplicate /o Sweep $(folder+CleanUpName(avgSweepName,0)) /WAVE=AvgSweep
			else
				AvgSweep+=Sweep
			endif
			count+=1
		endif
	endfor
	if(count>1)
		AvgSweep/=count
		AppendToGraph /c=(red,green,blue) AvgSweep
	endif	
	ControlBar /T 30
	Button CopyCursors, size={120,25}, proc=AverageWavesButtons, title="Copy Cursors to Sweeps"
End

Function AverageWavesButtons(ctrlName)
	string ctrlName
	
	strswitch(ctrlName)
		case "CopyCursors":
			if(!strlen(CsrInfo(A,"")) && !strlen(CsrInfo(B,"")))
				DoAlert 0,"You must place at least one cursor first."
				return -1
			endif
			string trace=CsrWave(A,"SweepsWin")
			if(!strlen(trace))
				trace=TopTrace(win="SweepsWin")
			endif
			if(strlen(CsrInfo(A,"")))
				Cursor /W=SweepsWin A,$trace,xcsr(A)
			endif
			if(strlen(CsrInfo(B,"")))
				Cursor /W=SweepsWin B,$trace,xcsr(B)
			endif
			break
	endswitch
End

Function /S AcqPackageObjectHelp(package,object)
	String package,object
	
	strswitch(package)
		case "acqModes":
			strswitch(object)
				case "inputGain":
					return "Amplifier reporting gain (Amp -> Digitizer -> Igor) in mV/<inputUnits>"
					break
				case "outputGain":
					return "Amplifier command gain (Igor -> Digitizer -> Amp) in <outputUnits>/mV"
					break
				case "testPulseStart":
					return "Start time of test pulse (s)."  
					break
				case "testPulseLength":
					return "Duration of test pulse (s)."  
					break
				case "testPulseAmpl":
					return "Amplitude of test pulse in <outputUnits>"
					break
				case "inputUnits":
					return "Natural units of recording, e.g. pA for voltage clamp"
					break
				case "outputUnits":
					return "Natural units of stimulation, e.g. mV for voltage clamp"
					break
				case "dynamic":
					return "Check if this mode is to be used for dynamic clamp on an Instrutech device."
					break
			endswitch
			break
	endswitch
	return ""
End

// Split the data on a postsynaptic channel according to the identity of the presynaptic stimulus on each sweep.  
// INCOMPLETE.  
Function SplitChannelsByPathway()
	variable i,j,k
	string labels=ChanLabels()
	for(i=0;i<itemsinlist(labels);i+=1)
		string labell=stringfromlist(i,labels)
		variable chan=Label2Chan(labell)
		setdatafolder root:$labell
		
		// Split (or copy) data.  
		string sweeps=wavelist("sweep*",";","")
		for(j=0;j<itemsinlist(sweeps);j+=1)
			string sweepName=stringfromlist(j,sweeps)
			wave sweep=$sweepName
			variable sweepNum
			sscanf sweepName,"sweep%d",sweepNum
			for(k=0;k<itemsinlist(labels);k+=1)
				string pathway=stringfromlist(k,labels)
				wave pathwayStimulusHistory=GetChannelHistory(pathway)
				if(HasStimulus(sweepNum,channel_label=pathway))
					newdatafolder root:$(pathway+"_"+labell)
					duplicate /o sweep,root:$(pathway+"_"+labell):$sweepName
				endif
			endfor
		endfor
		
		// Split (or copy) analyses.  
		string analysisMethods=Core#ListPackageInstances(module,"analysisMethods")
		for(j=0;j<itemsinlist(analysisMethods);j+=1)
			string analysisMethod=stringfromlist(j,analysisMethods)
			wave /z measurement=$analysisMethod
			if(waveexists(measurement))
				if(dimsize(measurement,2)>1) // Contains multiple layers, therefore depends on the pathway.  
					for(k=0;k<dimsize(measurement,2);k+=1)
						pathway=stringfromlist(k,labels)
						newdatafolder root:$(pathway+"_"+labell)
						duplicate /o measurement root:$(pathway+"_"+labell):$analysisMethod /wave=newMeasurement
						redimension /n=(-1,-1,0) newMeasurement
						newMeasurement=measurement[p][q][k]
					endfor
				else
					duplicate /o measurement root:$(pathway+"_"+labell):$analysisMethod /wave=newMeasurement
				endif
			endif
		endfor
	endfor
	setdatafolder root:
End

Function NormBin5(sweepNum[,channel])
	Variable sweepNum
	String channel
	
	if(ParamIsDefault(channel))
		channel="R1"
	endif
	Wave Ampl=root:$("cell"+channel):$("ampl_"+channel+"_"+channel)
	Variable i
	Wave SweepT=root:sweep_t
	Variable endBaselineT=ceil(SweepT[sweepNum-1]*100)/100
	Variable endBaseline=BinarySearch(SweepT,endBaselineT)
	//Variable endBaselineT=SweepT[sweepNum1-1]
	//Variable endBaseline=BinarySearch(SweepT,endBaselineT)
	Make /o/n=0 Meann,StanDev,SweepTime
	Variable t=endBaselineT,counter=0
	
	KillWaves /Z BinValues,BinTimes
	
	// Pre-induction.  
	for(i=0;i<5;i+=1)
		Variable finish=BinarySearch(SweepT,endBaselineT-i)
		Variable start=BinarySearch(SweepT,endBaselineT-i-1)
		if(start+1<0)
			break
		endif
		WaveStats /Q/R=[start+1,finish] Ampl
		Meann[numpnts(Meann)]={V_avg}
		StanDev[numpnts(StanDev)]={V_sdev}
		WaveStats /Q/R=[start,finish] SweepT
		SweepTime[numpnts(SweepTime)]={V_avg}
	endfor
	
	// Post-induction.  
	for(i=0;i<Inf;i+=1)
		start=BinarySearch(SweepT,endBaselineT+i)
		finish=BinarySearch(SweepT,endBaselineT+i+1)
		if(start==-2 || finish==-2) // Beyond the range of SweepT.  
			break
		elseif(start==finish)
			continue
		endif
		WaveStats /Q/R=[start+1,finish] Ampl
		Meann[numpnts(Meann)]={V_avg}
		StanDev[numpnts(StanDev)]={V_sdev}
		WaveStats /Q/R=[start+1,finish] SweepT
		SweepTime[numpnts(SweepTime)]={V_avg}
	endfor
	
	Sort SweepTime,SweepTime,Meann,StanDev
	SweepTime-=endBaselineT
	Display /K=1 Meann vs SweepTime
	ErrorBars Meann, Y wave=(StanDev,StanDev)
	ModifyGraph mode=3,marker=8
	Edit /K=1 Meann,StanDev,SweepTime
End

Function /S ChannelCombos(object,instance)
	String object // Object for comparison to determine selected value.  
	String instance // Package instance.  
	
	String combos=""
	
	string analysisMethod=SelectString(strlen(instance),SelectedMethod(),instance)
	dfref instanceDF=Core#InstanceHome(module,"analysisMethods",analysisMethod,quiet=1)
	strswitch(object)
		case "minimum":
			dfref analysisWinDF=instanceDF:analysisWin
			if(datafolderrefstatus(analysisWinDF))
				wave /z/sdfr=analysisWinDF comparison=Minimum
			endif
			break
		case "active":
			Wave /z/sdfr=instanceDF comparison=Active
			break
		case "minis":
			Wave /z/sdfr=root:Minis comparison=Channels
		case "sealtest":
			Wave /z/sdfr=SealTestDF() compariosn=Channels
	endswitch
	
	variable i,j
	variable numChannels=GetNumChannels()
	for(i=0;i<2^numChannels;i+=1)
		Variable true=1
		String combo=""
		for(j=0;j<numChannels;j+=1)
			combo+=SelectString(i & 2^j,"",GetChanLabel(j)+",")
			if(WaveExists(Comparison))
				true*=((i & 2^j)>0)==Comparison[j]
			else
				true=0
			endif
		endfor
		combo=RemoveEnding(combo,",")
		combo=SelectString(strlen(combo)," ",combo)
		if(true)
			combo="["+combo+"]"
		endif	
		combos+=RemoveEnding(combo,",")+";"
	endfor
	return combos
End

Function /wave GetAnalysisParameter(analysisMethod,chan)
	string analysisMethod
	variable chan
	
	return Core#WavPackageSetting(module,"analysisMethods",analysisMethod,"parameter",sub="analysisWin")
End

// Recalculates the data points in the Analysis window
Function Recalculate()
	variable left = GetCursorSweepNum("A")
	variable right = GetCursorSweepNum("B")
	if(numtype(left) || left<0)
		left=0
	endif
	if(numtype(right) || right<0)
		right=GetCurrSweep()
  endif
	variable i,j,previous_ISI,next_ISI; string pre,post,sweeps=""
	wave sweepT=GetSweepT()
	for(i=left;i<=right;i+=1)
		sweeps=sweeps+num2str(i)+";" // One is added because sweep1 is at index 0.
  endfor
  variable numChannels=GetNumChannels()
  wave /T Labels=GetChanLabels()
  string method=SelectedMethod()
  variable crossChannel=Core#VarPackageSetting(module,"analysisMethods",method,"crossChannel",default_=0)
  for(i=0;i<numChannels;i+=1)
	  if(!crossChannel)
	    ControlInfo /W=SweepsWin $("Show_"+num2str(i))
	    if(v_value>0 && !Analyze(i,i,sweeps,analysisMethod=method))
	      printf "%s recalculated for %s @ %s.\r",method,Labels[i],Secs2Time(DateTime,3)
	    endif
	  else
			for(j=0;j<numChannels;j+=1)
				ControlInfo /W=SweepsWin $("Synapse_"+num2str(i)+"_"+num2str(j))
				if(v_value>0 && !Analyze(i,j,sweeps,analysisMethod=method))
	      	printf "%s recalculated for %s->%s @ %s.\r",method,Labels[i],Labels(j),Secs2Time(DateTime,3)
	      endif
	    endfor
		endif
	endfor
End

Function Analyze(pre,post,sweeps[,analysisMethod])
	Variable pre,post
	String sweeps,analysisMethod
	
	variable noise_freq=Core#VarPackageSetting(module,"random","","noiseFreq",default_=60)
	if(ParamIsDefault(analysisMethod)) // analyze all analysis methods
		string analysisMethods=Core#ListPackageInstances(module,"analysisMethods")
	else
		analysisMethods = analysisMethod // analysis is restricted to the argument.  
	endif
	wave /T Labels=GetChanLabels()
	dfref df=Core#InstanceHome(module,"analysisWin","win0")
	wave /t/sdfr=df ListWave
	wave /sdfr=df SelWave
	string measurementCompleted=""
	
	variable index,numChannels=GetNumChannels()
	string DAQ=Chan2DAQ(post)
	dfref daqDF=GetDaqDF(DAQ)
	variable err=-1
	for(index=0;index<ItemsInList(analysisMethods);index+=1)
		analysisMethod=StringFromList(index,analysisMethods)
		if(!strlen(analysisMethod))
			continue
		endif
		wave /t chanAnalysisMethods=Core#WavPackageSetting(module,"channelConfigs",GetChanName(post),"analysisMethods")
		if(paramisdefault(analysisMethod))
			if(!InWavT(chanAnalysisMethods,analysisMethod)) // If this measurement does not have its box checked in the listbox of possible measurements.  
				continue
			endif
			if(StringMatch(analysisMethod,"Selected")) // If we are only analyzing the method that is currently selected (bold vertical axis).  
				if(!StringMatch(SelectedMethod(),analysisMethod)) // If the current measurement on the list is not this method.  
					continue // Skip it.  
				endif
			endif
		endif
		
		dfref df=Core#InstanceHome(module,"analysisMethods",analysisMethod)
		dfref analysisWinDF=df:analysisWIn
		wave /sdfr=analysisWinDF Minimum
		nvar /sdfr=df crossChannel
		
		if(crossChannel==0)
			if(pre!=post)
				continue
			else
				Variable layer=0
			endif
		else
			layer=pre
		endif
		
		//String measurementInfo=StringFromList(0,ListMatch(measurements))
		variable currSweep=GetCurrSweep()
		dfref preDF=GetChanDF(pre)
		dfref postDF=GetChanDF(post)
		string amplName=CleanupName(analysisMethod,0)
		wave /z/sdfr=postDF ampl=$amplName
		if(!waveexists(ampl))
	   	make /o/n=(currSweep) postDF:$amplName /wave=ampl=NaN
	   endif
	   if(layer>=dimsize(ampl,2))
	   	Redimension /n=(-1,-1,layer+1) ampl
	   endif
	   string view=GetSweepsWinView()
	   variable i,j,k,x1,x2
		if(!strlen(CsrInfo(A,"SweepsWin")))
			printf "Cursor A is not in the Sweeps window.  Adding cursors.\r"
			Cursors(win="SweepsWin")
			return -1
		endif
		wave /z cursor_locs = Core#WavPackageSetting(module,"analysisMethods",analysisMethod,"cursorLocs")
		if(!waveexists(cursor_locs)) // If there is no analysis region set for this measurement method.  
			// Use the current cursor positions.  
			variable focused=StringMatch(view,"Focused")
			x1=focused ? xcsr2("A",win="SweepsWin") : xcsr(A,"SweepsWin")
			x2=focused ? xcsr2("B",win="SweepsWin") : xcsr(B,"SweepsWin")
		else
			x1=cursor_locs[0]
			x2=cursor_locs[1]
		endif
		Variable flip_sign=max(0,Minimum[post]) // Flip the sign of the measurement if the bit is set.  
		//Execute /Q "ProgressWindow open"
		wave SweepParamsPre=GetChanHistory(pre)
		wave SweepParamsPost=GetChanHistory(post)
		//string postMode=GetAcqMode(post)
		for(i=0;i<ItemsInList(sweeps);i+=1)
			Variable sweepNum=str2num(StringFromList(i,sweeps))
			Variable oldNumRows=dimsize(Ampl,0)
			redimension /n=(max(oldNumRows,sweepNum+1),max(2,dimsize(Ampl,1)),-1) Ampl
			wave /z/sdfr=postDF sweep=$("sweep"+num2str(sweepNum))
         if(FiltersOn(post) && WaveExists(Sweep)) // If any filters are on.  
     		   if(sweepNum==currSweep)
     			   Wave Sweep=daqDF:$("input_"+num2str(post)) // Don't both filtering again, since we just filtered when we displayed this sweep.  
     		   else
     			    duplicate /free Sweep, FilteredSweep
     			    ApplyFilters(FilteredSweep,post)
     			    wave Sweep=FilteredSweep
     		    endif
         endif
	             
	      if(!WaveExists(Sweep)) // If the sweep cannot be found.  
			    if(sweepNum==currSweep) // But it was the most recently acquired sweep.  
					wave Sweep=daqDF:$("input_"+num2str(post)) // Try the DAQ version of it, which might be all that was been saved. 
				endif
				if(!WaveExists(Sweep)) // If it still doesn't exist.   .  
					ampl[sweepNum][0][layer]=NaN // Set the analysis values to NaN.  
					ampl[sweepNum][1][layer]=NaN
					continue
				endif
			endif
			
			// First sets baseline regions and regions of interest for analyzing peaks and average values of EPSCs and test pulses.  
			// Most of this based on finding regions such the noise cancels out when the baseline is subtracted from the region of interest
			variable numPulses = GetEffectiveStimParam("pulses",pre,sweepNum=sweepNum)
			numPulses = numtype(numPulses) ? 1 : numPulses
			variable IPI = GetEffectiveStimParam("IPI",pre,sweepNum=sweepNum)
			IPI = numtype(IPI) ? 100 : IPI
			Variable earliestChannelStim=EarliestStim(sweepNum,chan=pre)
			if(StringMatch(view,"Focused"))
				if(numtype(earliestChannelStim)!=0) // If there was not stimulation on this presynaptic channel.  
					ampl[sweepNum][0][layer]=NaN
					ampl[sweepNum][1][layer]=NaN
					continue
				else
					Variable x_left=x1+earliestChannelStim
					Variable x_right=x2+earliestChannelStim
				endif
			else
				x_left=x1
				x_right=x2
			endif
			
			string acqMode = GetAcqMode(post,sweep_num=sweepNum)
         // Compute baseline region.  
         ControlInfo /W=SweepsWin AutoBaseline
         if(V_Value)
				Variable baselineRight_=x_right
				for(baselineRight_=baselineRight_;baselineRight_>earliestChannelStim;baselineRight_-=1/noise_freq)
				endfor
				Variable baselineLeft_=baselineRight_-1/noise_freq // Make the total length of the baseline equal to one cycle of noise.  
            Variable noiseCorrection=0
            if(noiseCorrection)
               	Variable diff=mod(x_right-x_left,1/noise_freq)
					Variable baselineCenter_=baselineLeft_
					baselineLeft_=baselineCenter_-diff // Make the total length of the baseline equal to one cycle of noise plus the remainder diff.  
					//Variable num_cycles=floor((x_right-x_left)*noise_freq) // The number of cycles of noise between the cursors.  
					//Variable cycle_phase=diff*noise_freq
					//divisor=num_cycles+cycle_phase
					//Variable baselineA=faverage(sweep,baselineCenter,baselineRight) // mean baseline.  
		       	 	//Variable baselineB=faverage(sweep,baselineLeft,baselineCenter) // component from left over phase in the noise cycle.  
					//Variable baselineVal=(num_cycles*baselineA+cycle_phase*baselineB)/divisor // weighted component from phase relative to the noise.  
 				endif
 			else
 				nvar /z/sdfr=df baselineLeft,baselineRight
 				if(!nvar_exists(baselineLeft)) // If there is no baseline set for this analysis method.  
 					// Use the baseline for this acquisition mode.  
 					dfref modeDF=Core#InstanceHome("Acq","acqModes",acqMode)
 					nvar /z/sdfr=modeDF baselineLeft,baselineRight
 				endif
 				baselineLeft_=!nvar_exists(baselineLeft) ? 0 : baselineLeft
 				baselineRight_=!nvar_exists(baselineRight) ? 0.1 : baselineRight
 			endif
 			svar /z/sdfr=df method
 			if(!svar_exists(method) || !strlen(method))
 				string /g df:method=analysisMethod
 				svar /sdfr=df method
 			endif
 			err = MakeMeasurement(analysisMethod,method,Sweep,Ampl,sweepNum,post,layer,baselineLeft_,baselineRight_,x_left,x_right,IPI,numPulses,flip_sign)
			//UpdateProgressWin(frac=i/ItemsInList(sweeps),text="Sweep "+num2str(sweepNum))
		endfor	
	//Execute /Q "ProgressWindow close"
	endfor
	return err
End

Function MakeMeasurement(measurement,method,Sweep,Result,sweepNum,chan,layer,baselineLeft,baselineRight,x_left,x_right,IPI,numPulses_,flip_sign)
	string measurement,method
	wave Sweep,Result
	variable sweepNum,chan,layer,baselineLeft,baselineRight,x_left,x_right,IPI,numPulses_,flip_sign
	wave /T Labels=GetChanLabels()
	string mode=SweepAcqMode(chan,sweepNum)
	wave param=GetAnalysisParameter(measurement,chan)
	strswitch(method)
 		case "Peak": 
 		   // The maximum/minimum value between the cursors (normalized to baseline).  
 			redimension /n=(-1,max(dimsize(result,1),numPulses_),-1) result
 			variable i
 			for(i=0;i<numPulses_;i+=1)
 				waveStats /Q/M=1 /R=(baselineLeft+i*IPI,baselineRight+i*IPI) Sweep
 				variable baseline=v_avg
 				wavestats/M=1/Q/R=(x_left+i*IPI,x_right+i*IPI) Sweep
 				//print flip_sign,v_min,v_max
 				result[sweepNum][i][layer] = (IPI || i==0) ? (flip_sign ? baseline-V_min : v_max-baseline) : 0
 			endfor
 			break
 		case "PeakWX": 
 		   // The maximum/minimum value between the cursors (normalized to baseline).  
 			variable width=param[0]
 			width=(numtype(width) || width==0) ? 0.0001 : width/1000 // Convert from ms to seconds.  
 			WaveStats /Q/M=1 /R=(baselineLeft,baselineRight) Sweep
 			variable baseline0=V_avg
 			WaveStats /Q/M=1 /R=(baselineLeft+IPI,baselineRight+IPI) Sweep
 			variable baseline1=V_avg
 			result[sweepNum][0][layer] = baseline0 - mean(Sweep,x_left-width,x_left+width)
			result[sweepNum][1][layer] = IPI ? baseline1 - mean(Sweep,x_left+IPI-width,x_left+IPI+width) : 0
 			break
 		case "Charge": 
 		   // The charge between the cursors (normalized to baseline).  
			WaveStats /Q/M=1 /R=(baselineLeft,baselineRight) Sweep
			baseline0=V_avg
			WaveStats /Q/M=1 /R=(baselineLeft+IPI,baselineRight+IPI) Sweep
			baseline1=V_avg
			Wavestats/M=1/Q/R=(x_left,x_right) Sweep
			result[sweepNum][0][layer] = (baseline0-V_avg)*(x_right-x_left)
			Wavestats/M=1/Q/R=(x_left+IPI,x_right+IPI) Sweep
			result[sweepNum][1][layer] = IPI ? (baseline1-V_avg)*(x_right-x_left) : 0
			if(flip_sign)//StringMatch(Mode[chan],"VC") %^ (flip_sign & 2^chan))
				result[sweepNum][0][layer]  *= -1
				result[sweepNum][1][layer] *= -1
			 endif
			 break
    case "Slope": 
         // Maximum/Minimum slope within the region between the cursors.
			Duplicate /O/R=(x_left,x_right) Sweep slope_piece1
			Duplicate /O/R=(x_left+IPI,x_right+IPI) Sweep slope_piece2
 			Smooth 2,slope_piece1,slope_piece2
 			Differentiate slope_piece1,slope_piece2
 			Wavestats/M=1/Q slope_piece1
 			result[sweepNum][0][layer] = abs(SelectNumber(flip_sign,V_max,V_min))/1000
 			Wavestats/M=1/Q slope_piece2
 			result[sweepNum][1][layer] =  IPI ? abs(SelectNumber(flip_sign,V_max,V_min))/1000 : 0
 			KillWaves /Z slope_piece1,slope_piece2
 			break
 		case "Ratio": 
 		   // The ratio of the second to the first pulse.  
 			WaveStats /Q/M=1 /R=(baselineLeft,baselineRight) Sweep
 			baseline0=V_avg
 			WaveStats /Q/M=1 /R=(baselineLeft+IPI,baselineRight+IPI) Sweep
 			baseline1=V_avg
 			if(flip_sign)//StringMatch(Mode[chan],"VC") %^ flip_sign)
 				Wavestats/M=1/Q/R=(x_left,x_right) Sweep
 				Variable firstPulse=baseline0-V_min
 				Wavestats/M=1/Q/R=(x_left+IPI,x_right+IPI) Sweep
 				Variable secondPulse=baseline1-V_min
 			else
 				Wavestats/M=1/Q/R=(x_left,x_right) Sweep
 				firstPulse=V_max-baseline0
				Wavestats/M=1/Q/R=(x_left+IPI,x_right+IPI) Sweep
				secondPulse=V_max-baseline1
 			endif
 			result[sweepNum][0][layer] = secondPulse/firstPulse
			result[sweepNum][1][layer] = NaN
 			break
		case "Average": 
		   // The average value after and before the earliest stimulus (ignores the cursors, normalized to baseline).   
			WaveStats /Q/M=1 /R=(baselineLeft,baselineRight) Sweep
 			baseline0=V_avg
 			WaveStats /Q/M=1 /R=(baselineLeft+IPI,baselineRight+IPI) Sweep
 			baseline1=V_avg
 			Wavestats/M=1/Q/R=(x_left,x_right) Sweep
 			result[sweepNum][0][layer] = (baseline0-V_avg)
 			Wavestats/M=1/Q/R=(x_left+IPI,x_right+IPI) Sweep
       		result[sweepNum][1][layer] = IPI ? (baseline1-V_avg) : 0
       		if(flip_sign)//StringMatch(Mode[chan],"VC") %^ (2^chan && flip_sign))
       			result[sweepNum][0][layer]  *= -1
       			result[sweepNum][1][layer] *= -1
       		endif
       		break
		case "Standard_Deviation": 
		   // The standard deviation between the cursors (not normalized to baseline).  Second point is the skewness
			WaveStats /Q/R=(x_left,x_right) Sweep
			result[sweepNum][0][layer] = V_sdev
			result[sweepNum][1][layer] = V_skew
			break
		case "Meann": 
			// The mode - the mean
			Wavestats/M=1/Q/R=(x_left,x_right) Sweep
			result[sweepNum][0][layer] = V_avg
			result[sweepNum][1][layer] = NaN
			break
		case "Mode-Mean": 
			// The mode - the mean
			result[sweepNum][0][layer] = - MeanMinusMode(Sweep)
			result[sweepNum][1][layer] = NaN
			break
		case "Median-Mean": 
			// The median minus the median, which will generally be the average current, baseline subtracted, since the median typically occurs when there is no activity.  
			result[sweepNum][0][layer] = StatsMedian(Sweep)-mean(Sweep)
			result[sweepNum][1][layer]=NaN
			break
		case "Mode_Dev": 
			// The mode - the mean
			result[sweepNum][0][layer] = DeviationFromMode(Sweep)
			result[sweepNum][1][layer] = NaN
			break
		case "Spike_Rate": 
			// The number of spikes between the cursors.  
			variable threshold=param[0]
			WaveStats /Q/M=1 Sweep
			if(x_left!=x_right)
				FindLevels /Q/EDGE=1/M=0.0025 /R=(x_left,x_right) Sweep,threshold
			endif
			result[sweepNum][0][layer]=V_LevelsFound/(x_right-x_left)
			result[sweepNum][1][layer]=V_LevelsFound
			break
		case "Spike_Rate_EC": 
			// The number of spikes between the cursors.  
			threshold=param[0]
			Duplicate /FREE Sweep,Filtered
			FilterIIR /HI=(500*dimdelta(Sweep,0)) Filtered
			FindLevels /Q/EDGE=2/M=0.0025 Filtered,threshold
			result[sweepNum][0][layer]=V_LevelsFound/(WaveDuration(Sweep))
			result[sweepNum][1][layer]=V_LevelsFound
			break
		case "Heart_Rate":
			// Number of heart beats per minute
			WaveStats /Q Sweep
			FindLevels /Q/M=0.1 /EDGE=1 Sweep,(V_max+V_avg)/2
			Wave W_FindLevels
			Differentiate /METH=1 W_FindLevels
			if(numpnts(W_FindLevels)>2)
				WaveStats /Q/R=[0,numpnts(W_FindLevels)-2] W_FindLevels
				Variable Hz=1/V_avg
			else
				Hz=NaN
			endif
			result[sweepNum][0][layer]=60*Hz // Pulses per minute.  
			result[sweepNum][1][layer]=NaN
			KillWaves /Z TempCorr,W_FindLevels
			break
		case "Minis":
#if exists("FindMinis") && exists("NumChannelsStimulated")
			Variable num_stimuli=NumChannelsStimulated(sweepNum)
			Variable charge=StatsMedian(Sweep)-mean(Sweep)
			if(0)//num_stimuli && charge>1)
				result[sweepNum][0][layer] = NaN  
				result[sweepNum][1][layer] = NaN
			else
				String curr_folder=GetDataFolder(1)
				NewDataFolder /O/S root:Minis
				NewDataFolder /O/S $Labels[chan]
				NewDataFolder /O/S $("Sweep"+num2str(sweepNum))
				if(0)//earliest_global_stim<inf) // If there was a stimulus.
					Make /o/n=0 Locs,Vals // Ignore minis. 
				else // Otherwise calculated mini locations and sizes.  
					ControlInfo /W=AnalysisWin 	Parameter
					variable mini_thresh=v_value
					FindMinis(Sweep,thresh=mini_thresh,tStart=x_left,tStop=x_right,within_median=10)
					wave /Z Locs,Vals
					nvar net_duration
				endif
				if(WaveExists(Locs))
					MiniLocsAndValsToAnalysis(sweepNum,Labels[chan],Locs,Vals,duration=net_duration)
				endif
				SetDataFolder $curr_folder
			endif
#else
			DoAlert 0, "You must include the 'Minis' procedure file and the 'Experiment Facts' procedure file."
			return -1
#endif
			break
		case "Bek_Clem":
			// The rate of mPSCs according to the Bekker and Clements method
			Duplicate /o Sweep BC_Sweep
			wave template=AlphaSynapso(10,3,3,20)
			Execute /Q "MatchTemplate "+getwavesdatafolder(template,2)+",BC_Sweep"
			variable BC_thresh=param[0]
			FindLevels /Q/R=(x_left,x_right)/M=0.002 BC_Sweep, BC_thresh
			WaveStats /Q BC_Sweep
			result[sweepNum][0][layer] = numpnts(W_FindLevels)/(x_right-x_left) // Rate of events exceeding whose scores exceed the threshold.  
			result[sweepNum][1][layer] = V_sdev // Standard deviation of template match scores for reference.  
			KillWaves /Z BC_Sweep,W_FindLevels
			break
		case "Events":
#if exists("SpontaneousEventRate")
			result[sweepNum][0][layer]=SpontaneousEventRate(Labels[chan],num2str(sweepNum))
			result[sweepNum][1][layer]=NaN
#else							
			DoAlert 0,"You must include the 'More Analysis' procedure file"
			return -1
#endif
			break
		case "Power": 
			// The standard deviation between the cursors (not normalized to baseline).  Second point is the skewness
			FFT /MAGS /WINF=Hanning /DEST=$("root:Power2_"+num2str(chan))  Sweep
			Wave Power=$("root:Power2_"+num2str(chan))
			variable freq=param[0]
			result[sweepNum][0][layer]=Power(freq)
			result[sweepNum][1][layer]=NaN
			break
		case "Access_Resistance":
			// The access resistance of the recording (sometimes also called the series resistance), measured from the test pulse
			dfref df=Core#InstanceHome(module,"acqModes",mode)
			nvar /sdfr=df accessLeft,accessRight,rBaselineLeft,rBaselineRight,testPulseStart,testPulseampl,testPulselength
			if(!nvar_exists(accessLeft))
				AcqModeDefaults(mode)
				nvar /sdfr=df accessLeft,accessRight,rBaselineLeft,rBaselineRight,testPulseStart,testPulseampl,testPulselength
			endif
			baseline=mean(sweep,rBaselineLeft,rBaselineRight)
			variable out=abs(testPulseAmpl)
			wavestats /q/r=(accessLeft,accessRight)/m=1 sweep
			variable in=abs(v_min-baseline)
			variable ratioFactor=UnitsRatio(GetModeOutputPrefix(mode),GetModeInputPrefix(mode))
			variable ratio=ratioFactor*out/in
			string outputType=GetModeOutputType(mode,fundamental=1)
			string inputType=GetModeInputType(mode,fundamental=1)
			string ratioString=outputType+"/"+inputType
			if(stringmatch(ratioString,"Current/Voltage"))
				ratio=1/ratio // Convert from Siemens to Ohms.  
			elseif(stringmatch(ratioString,"Voltage/Current"))
				// Keep in Ohms.  
			else
				ratio=NaN
			endif
			result[sweepNum][0][layer] = ratio/1e6 // Convert from Ohms to Megaohms.  
			result[sweepNum][1][layer]=1000*GetOneTau(sweep,testPulsestart)
			break
		case "Time_Constant":
			// The time constant of a pulse response
			redimension /n=(-1,max(dimsize(result,1),numPulses_),-1) result
 			variable v_fitoptions=4
 			for(i=0;i<numPulses_;i+=1)
 				waveStats /Q/M=1 /R=(baselineLeft+i*IPI,baselineRight+i*IPI) Sweep // Baseline mean before the pulse.  
 				baseline = v_avg
 				duplicate /free/r=(x_left+i*IPI,x_right+i*IPI) Sweep, piece
 				setscale /p x,0,dimdelta(Sweep,0),piece
 				K0 = baseline
 				CurveFit/H="100"/NTHR=0/Q exp piece // Fit holding the y offset to be the mean of the baseline region.  
				result[sweepNum][i][layer] = 1000/K2 // Time constant in ms.  
 			endfor
 			break
 		case "Capacitance":
 			// The capacitance measured from the test pulse
 			nvar /sdfr=df accessLeft,accessRight,rBaselineLeft,rBaselineRight,testPulseStart,t
			variable input_resistance = ComputeInputResistance(sweep,mode) // Input resistance in Ohms
			variable time_constant = GetOneTau(sweep,testPulseStart) // Time constant of test pulse in seconds
			variable capacitance = time_constant/input_resistance // Capacitance of membrane in Farads
 			result[sweepNum][0][layer] = capacitance*1e12 // Capacitance of membrane in pF
 			result[sweepNum][1][layer] = NaN
 			break
 		case "Ten_Ninety": 
 			// The time to get from 10% to 90% of the peak amplitude between the cursors.  
			for(i=0;i<numPulses_;i+=1)
				waveStats /Q/M=1 /R=(baselineLeft+i*IPI,baselineRight+i*IPI) Sweep
 				baseline = V_avg
 				wavestats/M=1/Q/R=(x_left+i*IPI,x_right+i*IPI) Sweep
 				variable peak = (IPI || i==0) ? (flip_sign ? baseline-V_min : v_max-baseline) : 0
 				findlevel /q/r=(x_left+i*IPI,x_right+i*IPI) sweep,baseline+0.1*(peak-baseline)
 				variable ten = v_levelx
 				findlevel /q/r=(x_left+i*IPI,x_right+i*IPI) sweep,baseline+0.9*(peak-baseline)
 				variable ninety = v_levelx
 				result[sweepNum][i][layer] = ninety - ten
 			endfor
 			break
		case "Generic":
		case "Baseline":
			// The average of the baseline segment
			variable points=x2pnt(sweep,baselineRight)-x2pnt(sweep,baselineLeft)
			if(abs(points)>2)
				wavestats /q/r=(baselineLeft,baselineRight) sweep
				result[sweepNum][0][layer]=v_avg
				result[sweepNum][1][layer]=v_sdev
			else
				result[sweepNum][0][layer]=sweep(baselineLeft)
				result[sweepNum][1][layer]=nan
			endif
			break
		case "Input_Resistance":
			// The input resistance, measured from the test pulse
			input_resistance = ComputeInputResistance(sweep,mode)
			result[sweepNum][0][layer] = ratio/1e6 // Convert from Ohms to Megaohms.  
			result[sweepNum][1][layer] = NaN
			break
		case "AMPA_NMDA": 
			// The value at cursor A and the value a specified distance from cursors A
		 	width=param[0]
		 	variable delay=param[1]
 			width=(numtype(width) || width==0) ? 0.0001 : width/1000 // Convert from ms to seconds.  
 			WaveStats /Q/M=1 /R=(baselineLeft,baselineRight) Sweep
 			baseline=V_avg
 			result[sweepNum][0][layer] = baseline - mean(Sweep,x_left-width,x_left+width)
			result[sweepNum][1][layer] = baseline - mean(Sweep,x_left+delay-width,x_left+delay+width)
 			break
 		case "Resistance":
 			// The resistance, measured from a stimulus pulse response
 			wave numPulses=GetNumPulses(chan,sweepNum=sweepNum)
 			wave ampl=GetAmpl(chan,sweepNum=sweepNum)
 			wave dAmpl=GetdAmpl(chan,sweepNum=sweepNum)
 			if(numtype(numPulses[layer]))
 				break
 			endif
 		 	redimension /n=(-1,max(numPulses[layer],dimsize(result,1)),-1) result
 			for(i=0;i<numPulses[layer];i+=1)
 				wavestats /Q/M=1 /R=(baselineLeft+IPI*i,baselineRight+IPI*i) Sweep
 				baseline=v_avg
 				wavestats/Q/M=1/R=(x_left+IPI*i,x_right+IPI*i) Sweep
 				out=abs(v_avg-baseline)
 				in=ampl[layer]+i*dAmpl[layer]
 				ratioFactor=UnitsRatio(GetModeOutputPrefix(mode),GetModeInputPrefix(mode))
				ratio=ratioFactor*out/in
				outputType=GetModeOutputType(mode,fundamental=1)
				inputType=GetModeInputType(mode,fundamental=1)
				ratioString=outputType+"/"+inputType
				if(stringmatch(ratioString,"Current/Voltage"))
					ratio=1/ratio // Convert from Siemens to Ohms.  
				elseif(stringmatch(ratioString,"Voltage/Current"))
					// Keep in Ohms.  
				else
					ratio=NaN
				endif
				string prefix=GetMethodPrefix(measurement)
				if(strlen(prefix))
					variable multiplier=UnitsRatio("",prefix)
					ratio*=multiplier // e.g. convert from Ohms to Megaohms.  
 				endif
 				result[sweepNum][i][layer] = ratio
 			endfor
 			for(i=numPulses[layer];i<dimsize(result,1);i+=1)
 				result[sweepNum][i][layer] = nan
 			endfor
 			break
 		case "Latency": 
 			// Compute the location of the peak relative to the stimulus.  
 			variable stim_time = x_left
 			duplicate /o/r=(x_left+0.001,x_right) sweep, piece
 			differentiate piece /d=d_piece
 			smooth 10,piece,d_piece
 			setscale x,0.001,x_right-x_left,piece,d_piece
 			wavestats /m=1/q d_piece
 			variable max_slope=v_max
 			findlevel /q/r=(0.001,v_maxloc) d_piece,max_slope/3
 			//setscale x,0,x_right-x_left-0.01,piece
 			//wavestats/M=1/Q/R=(x_left+0.001,x_right) Sweep
 			wavestats /q piece
 			if((v_max-v_min)>10)
 				result[sweepNum][0][layer] = 1000*v_levelx
 			else
 				result[sweepNum][0][layer] = nan
 			endif
 			result[sweepNum][1][layer] = nan
 			break
		default:
			result[sweepNum][0][layer]=NaN
			result[sweepNum][1][layer]=NaN
	endswitch
	return 0
End

function ComputeInputResistance(sweep,mode[,ampl,baseline_left,baseline_right,input_left,input_right])
	// Computes the input resistance in Ohms
	wave sweep
	string mode
	variable ampl,baseline_left,baseline_right,input_left,input_right
	
	dfref df=Core#InstanceHome(module,"acqModes",mode)
	nvar /z/sdfr=df inputLeft,inputRight,rBaselineLeft,rBaselineRight,testPulsestart,testPulseampl,testPulselength
	if(!nvar_exists(inputLeft))
		AcqModeDefaults(mode)
		nvar /sdfr=df inputLeft,inputRight,rBaselineLeft,rBaselineRight,testPulsestart,testPulseampl,testPulselength
	endif
	if(paramisdefault(baseline_left) || paramisdefault(baseline_right))
		variable baseline = mean(sweep,rBaselineLeft,rBaselineRight)
	else
		baseline = mean(sweep,baseline_left,baseline_right)
	endif
	if(paramisdefault(ampl))
		variable out = abs(testPulseampl)
	else
		out = abs(ampl)
	endif
	if(paramisdefault(input_left) || paramisdefault(input_right))
		variable in = abs(mean(sweep,inputLeft,inputRight)-baseline)
	else
		in = abs(mean(sweep,input_left,input_right)-baseline)
	endif
	variable ratioFactor = UnitsRatio(GetModeOutputPrefix(mode),GetModeInputPrefix(mode))
	variable ratio = ratioFactor*out/in
	string outputType = GetModeOutputType(mode,fundamental=1)
	string inputType = GetModeInputType(mode,fundamental=1)
	string ratioString = outputType+"/"+inputType
	if(stringmatch(ratioString,"Current/Voltage"))
		ratio=1/ratio // Convert from Siemens to Ohms.  
	elseif(stringmatch(ratioString,"Voltage/Current"))
		// Keep in Ohms.  
	else
		ratio=NaN
	endif
	return ratio
end