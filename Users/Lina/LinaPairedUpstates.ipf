#pragma rtGlobals=1		// Use modern global access method.

Menu "More"
	
	"Copy Region To IBW",Region2IBW()
	"Paired Upstates",UpstateLocationsZ()
End

Menu "Upstate Analysis"
	"Spikes",Spikes();MoveStuffForLina()
	"Upstate Locations",UpstateLocations()
	"Upstate Stats",UpstateStats();VariousUpstateStatsLina()
	
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
		TraceColor(trace,win=win); NVar red,green,blue
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
Function VariousUpstateStatsLina()
	root()
	Variable index,i,j,on,off,num_spikes,spike_time,spike_time2; String name
	Wave UpstateOn,UpstateOff,Peak_Locs
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
	root()
End

Macro L2Concat()
	Execute "Concat(\"\",directory=\"root:cellL2:\")"
End

Macro R1Concat()
	Execute "Concat(\"\",directory=\"root:cellR1:\")"
End

Function Concat(wave_list[,directory,prefix,split,to_append,downscale])
	String wave_list // A list like "5,17;23,28".
	String directory,prefix // e.g. "root:cellL2:" and "sweep".
	Variable split // If there are splits in the list, i.e. it is non-contiguous, make multiple waves.
	Variable to_append // To append on the topmost graph, rather than make a new graph.
	Variable downscale // A factor to downscale the concatenated trace by, in order to make display faster and to save memory.  
	if(IsEmptyString(wave_list))
		NVar last_sweep=root:current_sweep_number
		wave_list="1,"+num2str(last_sweep)
	endif
	split=ParamIsDefault(split) ? 0 : split
	downscale=ParamIsDefault(downscale) ? 0 : downscale
	if(ParamIsDefault(directory))
		directory="root:cellR1:"
	else
		//directory+=":"
	endif
	if(ParamIsDefault(prefix))
		prefix=directory+"sweep"
	else
		prefix=directory+prefix
	endif
	String wave_name,name,old_name,new_name
	Variable i=0,j,start_sweep_num,end_sweep_num,wave_num,duration,last_start_time,this_start_time,time_diff
	Variable allowable_gap = 2 // The allowable gap between sweeps (in seconds) required to consider them continuous
	String channel=ExtractChannel(prefix,two_channels)
	Channel2Color(channel); NVar red,green,blue
	wave_list=ListExpand(wave_list)
	
	// Remove non-existent waves from the list
	Do
		wave_name=prefix+StringFromList(i,wave_list)
		if(!waveexists($wave_name))
			wave_list=RemoveListItem(i,wave_list)
		else
			i+=1
		endif
	While(i<ItemsInList(wave_list))
	if(IsEmptyString(wave_list))
		Print "There are no waves to concatenate of the form "+prefix
		return 0
	endif
	
	if(!to_append)
		Display /N=ConcatenatedSweeps /K=1
	endif
	
	if(!split)
		wave_list=ListContract(wave_list)
		name=ReplaceString(",",wave_list,"to")
		name=ReplaceString(";",name,"and")
		name=CleanupName("Sweep_"+name,1)
		wave_list=ListExpand(wave_list)
		wave_list=AddPrefix(wave_list,prefix)
		if(!IsEmptyString(wave_list))
			if(!StringMatch(wave_list[strlen(wave_list)-1],";"))
				wave_list+=";"
			endif
			Concatenate /O/NP wave_list, $(directory+name)
			AppendToGraph /c=(red,green,blue) $(directory+name)
		endif
	else
		String append_list="",offset_list="",sweep_name
		Variable offset
		Wave sweep_t=root:sweep_t
		old_name=directory+"TempConcat"
		start_sweep_num=NumFromList(0,wave_list)
		for(i=0;i<ItemsInList(wave_list);i+=1)
			wave_num=NumFromList(i,wave_list)
			wave_name=prefix+num2str(wave_num)
			Wave Sweep=$wave_name
			duration=rightx(sweep)-leftx(sweep)
			this_start_time=sweep_t[wave_num-1]
			time_diff=(this_start_time - last_start_time)*60
			if(i==0 || abs(duration - time_diff)>allowable_gap) // If the gap between sweeps exceeds allowable_gap seconds
				//print time_diff
				if(i != 0)
					new_name=directory+"Sweep_"+num2str(start_sweep_num)+"to"+num2str(end_sweep_num)
					Duplicate /o $old_name $new_name; KillWaves $old_name
					append_list+=new_name+";"; offset_list+=num2str(sweep_t[start_sweep_num-1]*60)+";"
				endif
				Concatenate /O/NP {$wave_name},$old_name
				start_sweep_num=wave_num
			else
				Concatenate /NP {$wave_name},$old_name
			endif
			end_sweep_num=wave_num
			last_start_time=sweep_t[wave_num-1]
		endfor
		new_name=directory+"Sweep_"+num2str(start_sweep_num)+"to"+num2str(end_sweep_num)
		Duplicate /o $old_name $new_name; KillWaves $old_name
		append_list+=new_name+";"; offset_list+=num2str(sweep_t[start_sweep_num-1]*60)+";"
		for(j=0;j<ItemsInList(append_list);j+=1)
			sweep_name=StringFromList(j,append_list)
			offset=NumFromList(j,offset_list)
			if(downscale>1)
				Downsample($sweep_name,downscale,in_place=1)
			endif
			AppendToGraph /c=(red,green,blue) $sweep_name
			ModifyGraph offset($TopTrace())={offset,0} 
		endfor
	endif
	Cursors()
End

// Concatenates traces to show the whole experiment on one graph
Macro TraceSummary()
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
	for(j=1;j<=last_sweep;j+=1)
		Redimension /n=0 OldSweep
		for(i=0;i<ItemsInList(all_channels);i+=1)
			channel=StringFromList(i,all_channels)
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
	for(i=0;i<ItemsInList(all_channels);i+=1)
		channel=StringFromList(i,all_channels)
		Channel2Color(channel); NVar red,green,blue
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
	for(i=0;i<ItemsInList(all_channels);i+=1)
		channel=StringFromList(i,all_channels)
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
	for(i=0;i<ItemsInList(all_channels);i+=1)
		folders+="root:cell"+StringFromList(i,all_channels)+";"
	endfor
	KillWaves2(folder_list=folders,match_str="Sweep_*") // Kill all the waves containing "Sweep_", which should be concatenated waves
End

// Cut out a region between the cursors.  
Function Cut()
	DeletePoints pcsr(A), pcsr(B)-pcsr(A), CsrWaveRef(A)
End

// Cut out a region between the cursors (a region according to the scale of the wave) for all waves in the specified folder.  
Function Cut2([folder,mask])
	String folder,mask
	if(ParamIsDefault(mask))
		mask="*"
	endif
	if(ParamIsDefault(folder))
		folder=""
	endif
	String curr_folder=GetDataFolder(1)
	SetDataFolder $folder
	String waves=WaveList(mask,";","")
	Variable i,start,finish
	for(i=0;i<ItemsInList(waves);i+=1)
		Wave theWave=$StringFromList(i,waves)
		start=x2pnt(theWave,xcsr(A))
		finish=x2pnt(theWave,xcsr(B))
		DeletePoints start, finish-start, theWave
	endfor
	SetDataFolder $curr_folder
End

Function MoveStuffForLina()
	DuplicateFolderContents("root:Spikes_"+CsrWave(A),"root")
	KillDataFolder /Z $("root:Spikes_"+CsrWave(A))
	root()
End
