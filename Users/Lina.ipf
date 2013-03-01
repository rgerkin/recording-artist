// $URL: svn://churro.cnbc.cmu.edu/igorcode/Users/Lina.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

#ifdef Acq
#include "Upstates"
#include "Spike Functions"
#include "Stats Plot"

Menu "More"
	"Copy Region To IBW",Region2IBW()
	"Paired Upstates",UpstateLocationsZ()
End

Menu "Upstate Analysis"
	"Spikes",Spikes()//;MoveStuffForLina()
	"Upstate Locations",UpstateLocations()
	"Upstate Stats",UpstateStats();VariousUpstateStatsLina()
	"Everything for the cursor channel",Everything()
	"Everything for all channels",Everything2()
End

Function Everything([Wav])
	Wave Wav
	
	if(ParamIsDefault(Wav))
		Wave Wav=CsrWaveRef(A)
	endif
	
	Spikes(theWave=Wav)
	UpstateLocations()
	UpstateStats()
	VariousUpstateStatsLina(theWave=Wav)
End

Function Everything2()
	String traces=TraceNameList("",";",1)
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace=StringFromList(i,traces)
		if(!StringMatch(trace,"Sweep*"))
			continue
		endif
		Wave Wav=TraceNameToWaveRef("",trace)
		print GetWavesDataFolder(Wav,0)
		Cursor A,$trace,-Inf
		Cursor B,$trace,Inf
		Everything(Wav=Wav)
	endfor
End

Function UpstateLocationsZ()
	root()
	String win=WinName(0,1)
	Variable i
	if(!CursorExists("A") || !CursorExists("B"))
		DoAlert 0,"Put cursors on the graph to mark the region of interest first"
		return 0
	endif
	Variable x1=xcsr(A)
	Variable x2=xcsr(B)
	String traces=TraceNameList(win,";",3),trace
	String /G target_dir="root:PairedUpstates"
	NewDataFolder /O $target_dir
	// Get the upstate locations for each wave.  
	print "\r"
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave theWave=TraceNameToWaveRef(win,trace)
		Cursor /W=$win A,$trace,x1
		Cursor /W=$win B,$trace,x2
		print trace+":"
		UpstateLocations()
		Sort UpstateOn,UpstateOn,UpstateOff
		Duplicate /o UpstateOn $(target_dir+":"+CleanupName("UpstateOn_"+trace,1))
		Duplicate /o UpstateOff $(target_dir+":"+CleanupName("UpstateOff_"+trace,1))
		KillWaves /Z UpstateOn,UpstateOff
		Spikes(folder=target_dir+":Spikes_"+trace)
		print "\r"
	endfor
	
	// Cleanup.  
	root()
	KillDataFolder /Z root:MeanStDevPlot_F
	KillWaves /Z ZMeans,ZStDevs,MahalDistances
	
	NewPanel /K=1 /N=UpstateManager /W=(0,0,350,100)
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Variable red,green,blue
		TraceColor(trace,red,green,blue,win=win)
		Wave UpstateOn=$(target_dir+":"+CleanupName("UpstateOn_"+trace,1))
		Wave UpstateOff=$(target_dir+":"+CleanupName("UpstateOff_"+trace,1))
		Variable /G $(target_dir+":upstate_number_"+trace)
		Variable num_upstates=numpnts(UpstateOn)
		SetVariable $("UpstateNumber_"+trace),limits={0,num_upstates-1,1}, size={100,20}, value=$(target_dir+":upstate_number_"+trace),proc=MoveUpstate,title=trace
		Button $("Add_"+trace), proc=AddUpstate,size={100,20},title="Add Upstate"
		Button $("Remove_"+trace), proc=RemoveUpstate,size={100,20},title="Remove Upstate"
		SetWindow UpstateManager userData+=trace+";"
	endfor
	Button CombineUpstates, proc=CombineUpstates,size={100,20},title="Combine Upstates"
	KillVariables /Z red,green,blue
End

Function MoveUpstate(ctrlName,varNum,varStr,varName)
	String ctrlName
	Variable varNum	
	String varStr,varName	
	String trace=RemoveListItem(0,ctrlName,"_")
	SVar target_dir=root:target_dir
	print target_dir+":"+CleanupName("UpstateOn_"+trace,1)
	Wave UpstateOn=$(target_dir+":"+CleanupName("UpstateOn_"+trace,1))
	Wave UpstateOff=$(target_dir+":"+CleanupName("UpstateOff_"+trace,1))
	if(!StringMatch(trace,"combined"))
		Cursor A,$trace,UpstateOn(varNum)
		Cursor B,$trace,UpstateOff(varNum)
	else
		String top_trace=TopTrace()
		Cursor A,$top_trace,UpstateOn(varNum)
		Cursor B,$top_trace,UpstateOff(varNum)
	endif
End

Function AddUpstate(ctrlName)
	String ctrlName
	String trace=RemoveListItem(0,ctrlName,"_")
	SVar target_dir=root:target_dir
	Wave UpstateOn=$(target_dir+":"+CleanupName("UpstateOn_"+trace,1))
	Wave UpstateOff=$(target_dir+":"+CleanupName("UpstateOff_"+trace,1))
	InsertPoints 0,1,UpstateOn,UpstateOff
	UpstateOn[0]=xcsr(A)
	UpstateOff[0]=xcsr(B)
	Sort UpstateOn,UpstateOn,UpstateOff
	Variable num_upstates=numpnts(UpstateOn)
	SetVariable $("UpstateNumber_"+trace),limits={0,num_upstates-1,1}
End

Function RemoveUpstate(ctrlName)
	String ctrlName
	String trace=RemoveListItem(0,ctrlName,"_")
	SVar target_dir=root:target_dir
	Wave UpstateOn=$(target_dir+":"+CleanupName("UpstateOn_"+trace,1))
	Wave UpstateOff=$(target_dir+":"+CleanupName("UpstateOff_"+trace,1))
	NVar upstate_number=$(target_dir+":upstate_number_"+trace)
	DeletePoints upstate_number,1,UpstateOn,UpstateOff
	Variable num_upstates=numpnts(UpstateOn)
	SetVariable $("UpstateNumber_"+trace),limits={0,num_upstates-1,1}
End

Function CombineUpstates(ctrlName)
	String ctrlName
	SVar target_dir=root:target_dir
	Variable i,j
	SetDataFolder $target_dir
	String wavesOn=WaveList("UpstateOn_*",";","")
	String wavesOff=WaveList("UpstateOff_*",";","")
	Concatenate /NP/O wavesOn, AllUpstateOn
	Concatenate /NP/O wavesOff, AllUpstateOff
	Concatenate /NP/O {AllUpstateOn,AllUpstateOff}, AllTransitions
	Make /o/T/n=(numpnts(AllTransitions)) AllTransitionTypes
	AllTransitionTypes[0,numpnts(AllUpstateOn)-1]="on"
	AllTransitionTypes[numpnts(AllUpstateOn),numpnts(AllTransitions)-1]="off"
	Sort AllTransitions,AllTransitions,AllTransitionTypes
	Make /o/n=0 CombinedUpstateOn,CombinedUpstateOff
	Variable count=0,transition_time,candidate_on=NaN; String transition_type,state="Down"
	for(j=0;j<numpnts(AllTransitions);j+=1)
		transition_time=AllTransitions[j]
		transition_type=AllTransitionTypes[j]
		strswitch(transition_type)
			case "on": 
				count+=1
				if(numtype(candidate_on)!=0)
					candidate_on=transition_time
				endif
				break
			case "off":
				count-=1
				if(count<1)
					candidate_on=NaN
				endif
				break
		endswitch
		if(count>=2 && StringMatch(state,"Down"))
			state="Up"
			InsertPoints 0,1,CombinedUpstateOn
			CombinedUpstateOn[0]=candidate_on
		elseif(count<1 && StringMatch(state,"Up"))
			state="Down"
			InsertPoints 0,1,CombinedUpstateOff
			CombinedUpstateOff[0]=transition_time
		endif
	endfor
	KillWaves /Z AllUpstateOn,AllUpstateOff,AllTransitions,AllTransitionTypes
	WaveTransform /O flip CombinedUpstateOn
	WaveTransform /O flip CombinedUpstateOff
	Variable /G $(target_dir+":upstate_number_combined")
	SetVariable $("UpstateNumber_combined"),limits={0,numpnts(CombinedUpstateOn)-1,1}, size={100,20}
	SetVariable $("UpstateNumber_combined"),value=$(target_dir+":upstate_number_combined"),proc=MoveUpstate,title="Combined"
	root()
End

Function SpikesRelativeToUpstates()
	String traces=GetUserData("UpstateManager","","")
	SVar target_dir=root:target_dir
	SetDataFolder $target_dir
	Variable i,j,spike_index,spike_time; String trace
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave UpstateOn=$("UpstateOn_"+trace)
		Wave UpstateOff=$("UpstateOff_"+trace)
		Wave CombinedUpstateOn=$("CombinedUpstateOn")
		Wave CombinedUpstateOff=$("CombinedUpstateOff")
		Wave Peak_Locs=$(":Spikes_"+trace+":Peak_locs")
		Duplicate /o UpstateOn $("T2SpikeSelf_"+trace);Wave T2SpikeSelf=$("T2SpikeSelf_"+trace)
		T2SpikeSelf=NaN
		for(j=0;j<UpstateOn;j+=1)
			spike_index=BinarySearch(Peak_Locs,UpstateOn[j])
			if(spike_index>=-1)
				spike_time=Peak_Locs[spike_index+1]
				if(spike_time<UpstateOff[j])
					T2SpikeSelf[j]=Peak_Locs[spike_index+1]-UpstateOn[j]
				endif
			endif
		endfor
		Duplicate /o CombinedUpstateOn $("T2SpikeComb_"+trace);Wave T2SpikeCombined=$("T2SpikeComb_"+trace)
		T2SpikeCombined=NaN
		for(j=0;j<CombinedUpstateOn;j+=1)
			spike_index=BinarySearch(Peak_Locs,CombinedUpstateOn[j])
			if(spike_index>=-1)
				spike_time=Peak_Locs[spike_index+1]
				if(spike_time<CombinedUpstateOff[j])
					T2SpikeCombined[j]=Peak_Locs[spike_index+1]-CombinedUpstateOn[j]
				endif
			endif
		endfor
	endfor
	root()
End

// Extracts various information about upstates.   
Function VariousUpstateStatsLina([theWave])
	Wave theWave
	
	if(ParamIsDefault(theWave))
		Wave theWave=CsrWaveRef(A)
	endif
	root()
	Variable index,i,j,on,off,num_spikes,spike_time,spike_time2; String name
	Wave /Z UpstateOn,UpstateOff,Peak_Locs
	DFRef f=root:$CleanUpName("Spikes_"+GetWavesDataFolder(theWave,0)+"_"+NameOfWave(theWave),0)
	if(!WaveExists(Peak_Locs))
		Wave /Z Peak_Locs=f:Peak_Locs
	endif
	if(!WaveExists(Peak_Locs))
		return -1
	endif
	f=root:$CleanUpName("U_"+GetWavesDataFolder(theWave,0)+"_"+NameOfWave(theWave),0)
	
	DFRef currFolder=GetDataFolderDFR()
	SetDataFolder f
	if(!WaveExists(UpstateOn))
		Wave /Z UpstateOn,UpstateOff
	endif
	Make /o/n=(numpnts(UpstateOn)) U_TimeBeforeFirstSpike,U_TimeAfterLastSpike,U_FirstISI,U_LastISI
	U_TimeBeforeFirstSpike=NaN;U_TimeAfterLastSpike=NaN;U_FirstISI=NaN;U_LastISI=NaN
	
	for(i=0;i<numpnts(UpstateOn);i+=1)
		on=UpstateOn[i]; off=UpstateOff[i]
		
		for(j=0;j<numpnts(Peak_Locs);j+=1)
			spike_time=Peak_Locs[j]
			if(spike_time>on && spike_time<off)
				U_TimeBeforeFirstSpike[i]=spike_time-on
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
				U_TimeAfterLastSpike[i]=off-spike_time
				spike_time2=Peak_Locs[j-1]
				if(spike_time2<spike_time && spike_time2>on)
					U_LastISI[i]=spike_time-spike_time2
				endif
				break
			endif
		endfor
	endfor
	SetDataFolder currFolder
End

Macro L2Concat()
	Execute "Concat(\"\",root:cellL2)"
End

Macro R1Concat()
	Execute "Concat(\"\",root:cellR1)"
End

// Concatenates traces to show the whole experiment on one graph
Macro TraceSummary3()
	//Concat("1,"+num2str(root:current_sweep_number),directory="root:cellR1:",split=1,downscale=10)
	//Concat("1,"+num2str(root:current_sweep_number),directory="root:cellL2:",split=1,to_append=1,downscale=10)
	TraceSummary2()
	CursorTraceToggleBar()
End

Function TraceSummary2()
	NVar last_sweep=root:current_sweep_number
	String wave_list="1,"+num2str(last_sweep)
	wave_list=ListExpand(wave_list)
	
	NewDataFolder /O/S root:ConcatenatedTraces
	Variable i,j,sweep_points,deficit,delta; String channel,long_channel
	
	// Figure out which channel has the longest sweep for any given sweep number.  
	Make /o/n=(last_sweep+1) SweepDurations=0
	Make /o/n=0 OldSweep
	SVar allChannels=root:parameters:allChannels
	for(j=1;j<=last_sweep;j+=1)
		Redimension /n=0 OldSweep
		for(i=0;i<ItemsInList(allChannels);i+=1)
			channel=StringFromList(i,allChannels)
			Wave /Z NewSweep=$("root:cell"+channel+":sweep"+num2str(j))
			if(WaveExists(NewSweep) && numpnts(NewSweep) > numpnts(OldSweep))
				SweepDurations[j]=numpnts(NewSweep)
				Duplicate /o NewSweep,OldSweep
			endif
		endfor	
	endfor
	//print SweepDurations; return 0
	// Concatenate the traces and display them.  
	Display /K=1 /N=TraceSummaries
	for(i=0;i<ItemsInList(allChannels);i+=1)
		channel=StringFromList(i,allChannels)
		Variable red,green,blue
		Channel2Colour(channel,red,green,blue)
		Make /o/n=0 $(channel+"_Summary"); Wave Summary=$(channel+"_Summary")
		for(j=1;j<=last_sweep;j+=1)
			Wave /Z sweep=$("root:cell"+channel+":sweep"+num2str(j))
			if(WaveExists(sweep))
				Concatenate /NP {sweep},Summary
				delta=dimdelta(sweep,0)
				sweep_points=numpnts(sweep)
			else
				sweep_points=0
			endif
			deficit=SweepDurations[j]-sweep_points
			if(deficit>0)
				Redimension /n=(numpnts(Summary)+deficit) Summary
				Summary[numpnts(Summary)-deficit,numpnts(Summary)-1]=NaN
			endif
		endfor	
		AppendToGraph /c=(red,green,blue) Summary
	endfor
	for(i=0;i<ItemsInList(allChannels);i+=1)
		channel=StringFromList(i,allChannels)
		Wave Summary=$(channel+"_Summary")
		SetScale /P x,0,delta,Summary
	endfor
	SetWindow kwTopWin userData="ConcatenatedTraces",hook=WindowKillHook
	KillVariables /Z red,green,blue
	KillWaves /Z DummySweep,OldSweep,SweepDurations
	root()
	Cursors()
End

Function KillConcats()
	Variable i; String folders=""
	SVar allChannels=root:parameters:allChannels
	for(i=0;i<ItemsInList(allChannels);i+=1)
		folders+="root:cell"+StringFromList(i,allChannels)+";"
	endfor
	KillWaves2(folders=folders,match="Sweep_*") // Kill all the waves containing "Sweep_", which should be concatenated waves
End

Function MoveStuffForLina()
	DuplicateFolderContents("root:Spikes_"+CsrWave(A),"root")
	KillDataFolder /Z $("root:Spikes_"+CsrWave(A))
	root()
End
#endif