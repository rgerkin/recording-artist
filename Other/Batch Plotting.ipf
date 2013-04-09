// $URL: svn://raptor.cnbc.cmu.edu/rick/recording-artist/Recording%20Artist/Other/Batch%20Plotting.ipf $
// $Author: rick $
// $Rev: 633 $
// $Date: 2013-03-28 15:53:22 -0700 (Thu, 28 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.
#include "Batch Wave Functions"

// Does stuff to all graphs
Function DoToGraphs([match_str])
	String match_str
	if(ParamIsDefault(match_str))
		match_str="*"
	endif
	//match_str=SelectString(ParamIsDefault(match_str),match_str,"*")
	String graphs=WinList(match_str,";","WIN:1")
	Variable i; String graph
	for(i=0;i<ItemsInList(graphs);i+=1)
		graph=StringFromList(i,graphs)
		DoWindow /F $graph
		// Do the following to all matching graphs
		SetAxis left -2,100
	endfor
End

Function KillTables([match])
	string match
	if(ParamIsDefault(match))
		match="*"
	endif
	
	KillAll("tables",match=match)
End

Function KillGraphs([match])
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	KillAll("graphs",match=match)
End

// Do fits on every open graph
Function AllFits(first,last,bad_list[,to_store,to_append,use_current])
	Variable first,last // Left and right boundary of the fitting region, in milliseconds
	String bad_list
	Variable to_store // Whether to store data in the data string (and waves) (default does not store)
	Variable to_append // Whether to append the data in the data string (and waves) instead of clearing it first (default is clearing)
	Variable use_current // Use the current graphs, bypassing any replotting
	Variable i,j
	String wave_list
	String curr_folder=GetDataFolder(1)
	bad_list="thyme;M_colors;*fit*;"+bad_list
	String graph_list=ListGraphs()
	String graph
	for(i=0;i<ItemsInList(graph_list);i+=1)
		graph=StringFromList(i,graph_list)
		DoWindow /F $graph
		Fits(first,last,store=to_store,name=graph+"_"+num2str(first*1000)+"_"+num2str(last*1000),append=to_append)
	endfor
	SetDataFolder curr_folder
End

// Puts exponential fits on all graphs with the time window x_min to x_max
Function FitPlots(x_min,x_max)
	Variable x_min,x_max
	String graph_list=ListGraphs()
	Variable i
	String graph_name
	for(i=0;i<ItemsInList(graph_list);i+=1)
		graph_name=StringFromList(i,graph_list)
		DoWindow /F $graph_name
		RemoveTraces(match="*fit*") // Removes the fits
		Fits(x_min,x_max,fit_prefix="fit_"+graph_name+"_")
		ColorCode(names="NMDA;NVP;Ro25;NVPDif;Ro25Dif",colors="0,0,0;0,0,65535;65535,0,0;65535,0,65535;65535,32678,0")
	endfor
End

// For plotting all instances of one property vs another, whether it be for spike or upstates
Function PropertyvsProperty(property1,property2[,ConditionWave,conditions,low_error1,high_error1,low_error2,high_error2,log_left])
	String property1 // e.g. "UpstateSpikeCounts"
	String property2 // e.g. "UpstateAHPs"
	Wave /T ConditionWave // e.g. Drug
	String conditions
	String low_error1,high_error1,low_error2,high_error2 // Error bar waves (one point for each point in the property waves).  
	Variable log_left
	
	root()
	if(ParamIsDefault(ConditionWave))
		Wave /T ConditionWave=Drug
	endif
	if(ParamIsDefault(conditions))
		conditions="Control;Seizure"
	endif
	
	Wave /T FileName,Experimenter,Pre_Cell,Post_Cell
	Wave File_Pairing_Num
	Variable i,j; String folder,cond,id,graph_name,folder_name
	graph_name=UniqueName(CleanUpName(property1+"vs"+property2,0),6,0)
	folder_name=UniqueName(CleanUpName(property1+"vs"+property2,0),11,0)
	NewDataFolder root:$folder_name
	Display /K=1 /N=$graph_name
	for(i=0;i<ItemsInList(conditions);i+=1)
		cond=StringFromList(i,conditions)
		cond=ReplaceString(",",cond,";")
		root();SetDataFolder $folder_name
		Make /o/n=0 $(CleanupName(cond+"_"+property1,0)),$(CleanupName(cond+"_"+property2,0))
		Make /o/n=0 $(CleanupName("LowError1_"+cond+"_"+property1,0)),$(CleanupName("LowError2_"+cond+"_"+property2,0))
		Make /o/n=0 $(CleanupName("HighError1_"+cond+"_"+property1,0)),$(CleanupName("HighError2_"+cond+"_"+property2,0))
		Make /o/T/n=0 $(CleanupName(cond,0))
		Wave Prop1=$(CleanupName(cond+"_"+property1,0)), Prop2=$(CleanupName(cond+"_"+property2,0))
		Wave Prop1ErrorLow=$(CleanupName("LowError1_"+cond+"_"+property1,0)), Prop2ErrorLow=$(CleanupName("LowError2_"+cond+"_"+property2,0))
		Wave Prop1ErrorHigh=$(CleanupName("HighError1_"+cond+"_"+property1,0)), Prop2ErrorHigh=$(CleanupName("HighError2_"+cond+"_"+property2,0))
		Wave /T Name=$(CleanupName(cond,0)) 	
		for(j=0;j<numpnts(FileName);j+=1)
			id=CleanUpName(FileName[j]+"_"+Experimenter[j]+"_"+num2str(File_Pairing_Num[j])+"_"+Pre_Cell[j]+"_"+Post_Cell[j],0)
			folder="root:Inductions:"+id
			if(DataFolderExists(folder) && AnyMatch(ConditionWave[j],cond))
				SetDataFolder $folder
				Wave /Z Property1Wave=$property1
				Wave /Z Property2Wave=$property2
				if(waveexists(Property1Wave) && waveexists(Property2Wave))
					Concatenate /NP {Property1Wave}, Prop1
					Concatenate /NP {Property2Wave}, Prop2
					Redimension /n=(numpnts(Prop1)) Name
					Name[numpnts(Name)-1]=id
				endif
				if(!ParamIsDefault(low_error1) && !ParamIsDefault(high_error1))
					Wave /Z LowError1Wave=$low_error1
					Wave /Z HighError1Wave=$high_error1
					if(waveexists(LowError1Wave) && waveexists(HighError1Wave))
						Concatenate /NP {LowError1Wave}, Prop1ErrorLow
						Concatenate /NP {HighError1Wave}, Prop1ErrorHigh
					endif
				endif
				if(!ParamIsDefault(low_error2) && !ParamIsDefault(high_error2))
					Wave /Z LowError2Wave=$low_error2
					Wave /Z HighError2Wave=$high_error2
					if(waveexists(LowError2Wave) && waveexists(HighError2Wave))
						Concatenate /NP {LowError2Wave}, Prop2ErrorLow
						Concatenate /NP {HighError2Wave}, Prop2ErrorHigh
					endif
				endif
			endif
		endfor
		
		root();SetDataFolder $folder_name
		Condition2Color(cond); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) Prop1 vs Prop2
		KillVariables /Z red,green,blue
		if(log_left)
			Prop1=Log(Prop1)
			Prop1ErrorLow=Log(Prop1ErrorLow)
			Prop1ErrorHigh=Log(Prop1ErrorHigh)
			Make /o/n=0 LogTicks
			Make /o/T/n=0 LogTickLabels
			for(j=0.125;j<=4;j*=2)
				InsertPoints 0,1,LogTicks,LogTickLabels
				LogTicks[0]=log(j)
				LogTickLabels[0]=num2str(j)
			endfor
			ModifyGraph userTicks(left)={LogTicks,LogTickLabels}
		endif
		
		if(!ParamIsDefault(low_error1) && !ParamIsDefault(high_error1))
			Prop1ErrorLow=Prop1-Prop1ErrorLow
			Prop1ErrorHigh=Prop1ErrorHigh-Prop1
			ErrorBars $NameOfWave(Prop1),Y wave=(Prop1ErrorHigh,Prop1ErrorLow) 
		endif
		if(!ParamIsDefault(low_error2) && !ParamIsDefault(high_error2))
			Prop2ErrorLow=Prop2-Prop2ErrorLow
			Prop2ErrorHigh=Prop2ErrorHigh-Prop2
			ErrorBars $NameOfWave(Prop2),Y wave=(Prop2ErrorHigh,Prop2ErrorLow) 
		endif
	endfor
	Label left property1
	Label bottom property2
	root()
	BigDots(size=5)
	SetWindow $graph_name, hook=WindowKillHook,userData="KillFolder="+folder_name
End

// Sets the waves for all visible traces equal to NaN between the cursors.  
Function NanifyTraces([match,win])
	String match,win
	if(ParamIsDefault(match))
		match="*"
	endif
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	traces=ListMatch(traces,match)
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace=StringFromList(i,traces)
		if(IsTraceVisible(trace,win=win))
			Wave theWave=TraceNameToWaveRef(win,trace)
			theWave[pcsr(A),pcsr(B)]=NaN
		endif
	endfor
End

Function Plot(waves)
	String waves
	String wave_list=WaveList(waves,";",""),theWave
	Display /K=1
	Variable i
	ColorTab2Wave Rainbow; Wave M_Colors
	Variable num_colors=dimsize(M_Colors,0), num_waves=ItemsInList(wave_list),color
	for(i=0;i<num_waves;i+=1)
		theWave=StringFromList(i,wave_list)
		color=round(num_colors*i/num_waves)
		AppendToGraph /c=(M_Colors[color][0],M_Colors[color][1],M_Colors[color][2]) $theWave
	endfor
End

// Copies offsets from one trace to all the others
Function CopyOffsets([source_trace,dest_traces,win])
	String source_trace,dest_traces,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	if(ParamIsDefault(source_trace))
		source_trace=CsrWave(A,win)
	endif
	if(ParamIsDefault(dest_traces))
		dest_traces=TraceNameList(win,";",3)
	endif
	Variable x=XOffset(source_trace,win=win)
	Variable y=yOffset(source_trace,win=win)
	Variable i; String dest_trace
	for(i=0;i<ItemsInList(dest_traces);i+=1)
		dest_trace=StringFromList(i,dest_traces)
		ModifyGraph /W=$win offset={x,y}
	endfor
End

Function Do2Images(F)
	FuncRef ECDF F
	String waves=WaveList("*",";","DIMS:2"),whave
	Variable i
	for(i=0;i<ItemsInList(waves);i+=1)
		whave=StringFromList(i,waves)
		F($whave)
	endfor
End

Function Do2Window([f,command,match])
	FuncRef LogOn F
	String command
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	String wins=WinList("*",";","WIN:1"),win
	Variable i
	for(i=0;i<ItemsInList(wins);i+=1)
		win=StringFromList(i,wins)
		if(StringMatch(win,match))
			DoWindow /F $win
			if(!ParamIsDefault(f))
				F()
			elseif(!ParamIsDefault(command))
				Execute /Q command
			endif
		endif
	endfor
End

// Set the color scale (rainbow) for the top image in all figures
Function ImageScale2(minn,maxx)
	Variable minn,maxx
	String win_list=WinList("*",";","WIN:1")
	Variable i; String win
	for(i=0;i<ItemsInList(win_list);i+=1)
		win=StringFromList(i,win_list)
		if(!IsEmptyString(TopImage(win=win))) // If there is an image in the window
			ModifyImage /W=$win $TopImage(win=win) ctab={minn,maxx,Rainbow,0}
		endif
	endfor
End

// Display all the waves in a folder, putting them all on different y axes, offset from one another.  
Function DisplayDirWaves2([folder])
	String folder
	String curr_folder=GetDataFolder(1)
	if(ParamIsDefault(folder))
		folder=""
	endif
	SetDataFolder $folder
	String waves=WaveList("*",";","")
	waves=SortList(waves,";",16)
	Variable i; String wave_name
	Variable num_waves=ItemsInList(waves)
	Display /K=1 /N=$CleanUpName(folder,0)
	for(i=0;i<num_waves;i+=1)
		wave_name=StringFromList(i,waves)
		folder=GetDataFolder(1)
		AppendToGraph /c=(0,0,0) /L=$("ampl_"+num2str(i)) $wave_name
		ModifyGraph axisEnab($("ampl_"+num2str(i)))={(i/num_waves)+0.01,((i+1)/num_waves)-0.01}
		Textbox /A=LB/F=0/Y=(100*i/num_waves)/N=$CleanupName(("Textbox_"+wave_name),0) wave_name
		SetAxis $("ampl_"+num2str(i)) -1,1
		HideAxes(axes="ampl_"+num2str(i))
		ModifyGraph nticks($("ampl_"+num2str(i)))=2,freePos($("ampl_"+num2str(i)))={0,bottom}
		Label $("ampl_"+num2str(i)) "mV"
	endfor
	Label bottom "s"
	//SetAxis bottom 0,300
	ModifyGraph tickUnit(bottom)=1
	ScaleBar(10,1,"s","mV",y_axis="ampl_0")
	SetDataFolder $curr_folder
End

// Display all the waves in a folder
Function DisplayDirWaves(foldername,[versus,mask]) // Display all the waves in a directory
	String foldername // Name of a folder, leave as "" for current directory
	String versus // Name of a wave to plot against (versus)
	String mask // A mask to restrict plotted waves to, e.g. "sweep*" for waves starting with "sweep" 
		
	String currFolder=GetDataFolder(1)
	if(!cmpstr(foldername,""))
		foldername=currFolder
	endif		
	SetDataFolder $foldername
	String windowname=GetDataFolder(0)
	DoWindow /K $windowname
	Display /K=1 /N=$windowname
	
	if(ParamIsDefault(mask))
		mask="*"
	endif
	String list=Wavelist(mask,";","")
	Variable i
	if(ParamIsDefault(versus))
		for(i=0;i<ItemsInList(list);i+=1)
			AppendToGraph $(StringFromList(i,list))
		endfor
	elseif(exists(versus))
		for(i=0;i<ItemsInList(list);i+=1)
			AppendToGraph $(StringFromList(i,list)) vs $versus
		endfor
		RemoveFromGraph /Z $versus
	else
		printf "There is no wave called %s in the directory %s.\r",versus,foldername
		DoWindow /K $windowname
		return 0
	endif
	SetDataFolder $currFolder
	Cursors()
End  

Function FitsforAllPlots([mask]) // Get fits of a certain type for each plot in the top window, and store the values
	// You must manually change the type of curvefit if you want something different than the default choice
	// You must manually change the holding string
	// You must have cursors on the plot for this to work
	//String type // Curvefit type, e.g. "exp"
	String mask // A mask to restrict plotted waves to, e.g. "sweep*" for waves starting with "sweep" 
	String hold="000" // Which parameters to hold, e.g. "1010" for first and third parameter
	
	if(ParamIsDefault(mask))
		mask="*"
	endif
	SetDataFolder root:
	
	if(!exists("FitCoeffs"))
		Make /o/n=3 FitCoeffs
		FitCoeffs=0
	endif
	
	Make /o/n=1 $("ParamEvolution_"+WinName(0,1))=NaN
	Wave ParamEvolution=$("ParamEvolution_"+WinName(0,1))
	Variable /G $("AverageParam_"+WinName(0,1))
	NVar ParamOfAverage=$("ParamOfAverage_"+WinName(0,1))
	Variable wave_number
	Variable i
	String list=ListMatch(TraceNameList("",";",1),mask)
	String trace_name
	Variable V_fitOptions=4 // Suppresses Curve Fitting Window
	for(i=0;i<ItemsInlist(list);i+=1)
		trace_name=StringFromList(i,list)
		if(!StringMatch(trace_name,"fit_*")) // Don't try to fit the fits
			Wave ToFit=TraceNameToWaveRef("",trace_name)
			Wave XWave=XWaveRefFromTrace("",trace_name)
			if(waveexists(XWave))
				CurveFit /N/W=0/Q/H=hold exp kwCWave=root:FitCoeffs,  ToFit(xcsr(A),xcsr(B)) /X=XWave /D 
			else
				CurveFit /N/W=0/Q/H=hold exp kwCWave=root:FitCoeffs,  ToFit(xcsr(A),xcsr(B)) /D
			endif
			ModifyGraph rgb($("fit_"+trace_name))=(0,65535,0)
			wave_number=str2num(StringFromList(1,NameOfWave(toFit),"_"))
			if(wave_number > 0)
				Redimension /n=(wave_number+1) ParamEvolution
				ParamEvolution[wave_number]=1/K2
			else
				ParamOfAverage=1/K2
			endif
		endif
	endfor
	for(i=0;i<numpnts(ParamEvolution);i+=1)
		if(ParamEvolution[i]==0)
			ParamEvolution[i]=NaN
		endif
	endfor
	//Display /K=1 ParamEvolution
	//ModifyGraph mode=3,marker=19,mrkThick=3
	printf "%f\r",1000/K2 // Prints a parameter (in the case of exp fit, the time constant)
End

//// Plot all combinations of list1 against list2 (data pairs with lines connecting them)
Function PlotPairsWithLinesMany(list1,list2,bad_list)//,suffix)
	String list1,list2//,suffix
	String bad_list // Makes sure nothing on the bad list (e.g. current too small) is on the returned list
	String prefix="time_constants_"
	String suffix="_40_340"
	Variable i,j
	String item1,item2,difs,name
	KillWaves2(folders="root:pairswithlines:")
	for(i=0;i<ItemsInList(list1);i+=1)
		item1=StringFromList(i,list1)
		for(j=0;j<ItemsInList(list2);j+=1)
			item2=StringFromList(j,list2)
			if(cmpstr(item1,item2))		
				SVar list1a=$(prefix+item1+suffix)
				SVar list2a=$(prefix+item2+suffix)
				difs=GetDifs(list1a,list2a,bad_list)
				name=item1+"_"+item2
				ListTTest2(difs,name)
				PlotPairsWithLines($("root:t_test:"+name+"_1"),$("root:t_test:"+name+"_2"))
			endif
		endfor
	endfor
End

// Plots a cumulative histogram of the waves in the list
Function Cumul(wave_list)
	String wave_list
	Variable i
	String wave_name
	Display /K=1
	for(i=0;i<ItemsInList(wave_list);i+=1)
		wave_name=StringFromList(i,wave_list)
		Duplicate /o $wave_name $("C_"+wave_name)
		Sort $("C_"+wave_name) $("C_"+wave_name)
		AppendToGraph $("C_"+wave_name)
	endfor
End

// Plots a list of Y's vs. a list of X's on the same graph
Function PlotYvsX(y,x,list[,bad])
	String y,x
	String list // A list of strings contained by the names of waves in the current folder
	String bad
	String bad_list
	list=WildList(list) // Add wildcards to each side of each entry in list
	Variable i
	String name,wave_list,x_wave,y_wave
	Display /K=1 /N=$(y+"_vs_"+x)
	for(i=0;i<ItemsInList(list);i+=1)
		name=StringFromList(i,list)
		wave_list=WaveList(name,";","")
		if(!ParamIsDefault(bad))
			bad_list=WaveList(bad,";","")
			wave_list=RemoveFromList(bad_list,wave_list)
		endif
		x_wave=StringFromList(0,ListMatch(wave_list,Wild(x)))
		y_wave=StringFromList(0,ListMatch(wave_list,Wild(y)))
		AppendToGraph $y_Wave vs $x_Wave
	endfor
	ColorCode(names="NMDA;NVP;Ro25;NVPDif;Ro25Dif",colors="0,0,0;0,0,65535;65535,0,0;65535,0,65535;65535,32678,0") // For NR2
	BigDots() // To see big dots instead of lines
End

Function ColorizeAll(channel[,win_name])
	String channel,win_name
	if(ParamIsDefault(win_name))
		win_name=WinName(0,1)
	endif
	Variable red,green,blue; GetChannelColor(channel,red,green,blue); 
	ModifyGraph /W=$win_name rgb=(red,green,blue)
End

Function ColorCode([names,colors])
	String names
	String colors
	if(ParamIsDefault(names))
		names="NMDA;NVP;Ro25;NVPDif;Ro25Dif"
	endif
	if(ParamIsDefault(colors))
		colors="0,0,0;0,0,65535;65535,0,0;65535,0,65535;65535,32678,0"
	endif
	String traces=TraceNameList("",";",3)
	Variable i,j,index
	String some_traces,trace,name,color
	Variable red,green,blue
	for(i=0;i<ItemsInList(names);i+=1)
		name=StringFromList(i,names)
		some_traces=ListMatch(traces,"*"+name+"*")
		for(j=0;j<ItemsInList(some_traces);j+=1)
			trace=StringFromList(j,some_traces)
			color=StringFromList(i,colors)
			red=str2num(StringFromList(0,color,","))
			green=str2num(StringFromList(1,color,","))
			blue=str2num(StringFromList(2,color,","))
			ModifyGraph rgb($trace)=(red,green,blue)
		endfor
	endfor
End

Function KillAllFits() // Removes Fits from every graph there is and then deletes them
	String list=WinList("*",";","")
	Variable i,j
	String window_name
	String traces,fit_traces,this_trace
	for(i=0;i<ItemsInList(list);i+=1)
		window_name=StringFromList(i,list)
		traces=TraceNameList(window_name,";",1)
		fit_traces=ListMatch(traces,"fit*")
		//DoWindow /F $window_name
		for(j=0;j<ItemsInList(fit_traces);j+=1)
			this_trace=StringFromList(j,fit_traces)
			Wave ToDelete=TraceNameToWaveRef(window_name,this_trace)
			Execute("RemoveFromGraph /W="+window_name+" "+this_trace)
			KillWaves ToDelete
		endfor
	endfor
	KillMatch("fit_*")
End

function KillAllGraphs()
	KillAll("graphs")
End

// Plot traces for each cell that appear on the bad lists
Function PlotUnused(folder_list,bad_list,should_contain,should_not_contain)
	String folder_list,bad_list
	String should_contain, should_not_contain // "*'" for contain anything
	Variable i,j
	String folder
	String curr_folder=GetDataFolder(1)
	String no_use_list
	String wave_list, wave_name
	no_use_list=bad_list
	for(i=0;i<ItemsInList(folder_list);i+=1)
		SetDataFolder root:
		no_use_list=bad_list
		SetDataFolder curr_folder
		folder=StringFromList(i,folder_list)
		FindFolder(folder)
		wave_list=WaveList("*",";","")
		Display /K=1 /N=$(folder+"_unused")
		for(j=0;j<ItemsInList(wave_list);j+=1)
			wave_name=StringFromList(j,wave_list)
			if(FindListItem(folder+"_"+wave_name,no_use_list)!=-1)
				if(StringMatch(wave_name,should_contain) && !StringMatch(wave_name,should_not_contain))
					AppendToGraph $wave_name
				endif
			endif
		endfor
		ColorCode(names="NMDA;NVP;Ro25;NVPDif;Ro25Dif",colors="0,0,0;0,0,65535;65535,0,0;65535,0,65535;65535,32678,0")
	endfor
	SetDataFolder curr_folder
End

Function PlotUsed(folder_list,plot_list,bad_list[,fits])
	String folder_list,plot_list,bad_list // A list of folders that contain traces to normalize, and a list of traces not to normalize
	Variable fits
	Variable i,j
	String folder
	String curr_folder=GetDataFolder(1)
	String no_use_list
	String wave_list, wave_name
	for(i=0;i<ItemsInList(folder_list);i+=1)
		SetDataFolder root:
		no_use_list="Thyme;"+bad_list // Thyme added for NR2 project
		SetDataFolder curr_folder
		folder=StringFromList(i,folder_list)
		FindFolder(folder)
		wave_list=WaveList("*",";","")
		no_use_list=ListMatch(no_use_list,"*"+folder+"*")
		Display /K=1 /N=$folder
		for(j=0;j<ItemsInList(wave_list);j+=1)
			wave_name=StringFromList(j,wave_list)
			if(!cmpstr("",ListMatch(no_use_list,"*"+wave_name)))
				if(FindListItem(wave_name,plot_list)!=-1)
					AppendToGraph $wave_name
				endif
			endif
		endfor
		ColorCode(names="NMDA;NVP;Ro25;NVPDif;Ro25Dif",colors="0,0,0;0,0,65535;65535,0,0;65535,0,65535;65535,32678,0")
	endfor
	SetDataFolder curr_folder
End

// Plots all the items matching entries in the list names.  Each folder will be plotted on a separate graph.
Function PlotFolders(names,folder_list,bad_list)
	String names,folder_list,bad_list // Names of waves to plot (can include wildcards), a list of folders, and a list of waves not to plot
	Variable i,j
	String wave_list, name, folder
	String curr_folder=GetDataFolder(1)
	bad_list="thyme;M_colors;*fit*;"+bad_list
	for(j=0;j<ItemsInList(folder_list);j+=1)
		folder=StringFromList(j,folder_list)
		Display /K=1 /N=$folder
		SetDataFolder curr_folder
		FindFolder(folder)
		for(i=0;i<ItemsInList(names);i+=1)
			name=StringFromList(i,names)
			wave_list=WaveList2(match=name,except=bad_list)
			AppendListToGraph(wave_list)
		endfor
	endfor
	SetDataFolder curr_folder
End

// Plots all the items matching entries in the list names.  Each item will be plotted on a separate graph.
Function PlotFolders2(names,folder_list,bad_list)
	String names,folder_list,bad_list // Names of waves to plot (can include wildcards), a list of folders, and a list of waves not to plot
	Variable i,j
	String wave_list, name, folder
	String curr_folder=GetDataFolder(1)
	bad_list="thyme;M_colors;*fit*;"+bad_list
	for(i=0;i<ItemsInList(names);i+=1)
		name=StringFromList(i,names)
		Display /K=1 /N=$name
		name="*"+name // For NR2 only
		for(j=0;j<ItemsInList(folder_list);j+=1)
			folder=StringFromList(j,folder_list)
			SetDataFolder curr_folder
			FindFolder(folder)
			wave_list=WaveList2(match=name,except=bad_list)
			AppendListToGraph(wave_list)
		endfor
	endfor
	SetDataFolder curr_folder
End

// Plots all waves in current folder
Function PlotFolder()
	Display /K=1
	String wave_list=wavelist("*",";","")
	AppendListToGraph(wave_list)
End

// A window that can show the waves of a folder, and in which those waves can be browsed.  
Function BrowseFolder(df[,prefix])
	dfref df // Data folder reference. 
	String prefix // e.g. "Sweep".   
	if(ParamIsDefault(prefix))
		prefix=""
	endif
	
	string folder=getdatafolder(1,df)
	NewDataFolder /O root:Packages
	String package_folder="root:Packages:BrowseFolder"
	NewDataFolder /O $package_folder
	if(WinExist("FolderBrowser"))
		DoWindow/F FolderBrowser
	else
		Display /K=1 /N=FolderBrowser /W=(0,0,400,300)
		ControlBar /T 35
		//Cursors()
		Variable /G $(package_folder+":folder_sweep_num")
		Variable /G $(package_folder+":folder_sweep_index")
		SetVariable SweepByNum,pos={25,10},size={100,10},title="Sweep",value=$(package_folder+":folder_sweep_num"),proc=BrowseFolderSV,limits={0,inf,1}
		//PopUpMenu sweep_names,pos={100,10},size={100,10},title="",value=#("WaveList2(folder=\""+folder+"\")")
		SetVariable SweepByIndex,pos={150,10},size={100,10},title="Index",value=$(package_folder+":folder_sweep_index"),proc=BrowseFolderSV,limits={0,inf,1}
		Variable pop_num=WhichListItem(folder,AllFolders(top_folder="root:"))
		PopupMenu Folder,pos={300,10},size={120,10},title="Folder",value=#"\"root:;\"+AllFolders(top_folder=\"root:\")",mode=pop_num+1
		//Checkbox transpose,pos={435,10},size={120,10},title="Transpose"
		SetWindow FolderBrowser, userData(folder)=folder
		SetWindow FolderBrowser, userData(prefix)=prefix
		NVar num=$(package_folder+":folder_sweep_num"); num=0
		//NewFolderSweep("SweepByNum",0,"","")
		Button Custom1,pos={400,5},title="Add",proc=BrowseFolderButton
		Button Custom2,pos={455,5},title="No",proc=BrowseFolderButton
	endif
	Struct WMSetVariableAction info
	info.dval=0
	info.ctrlName="SweepByIndex"
	info.eventCode=1
	BrowseFolderSV(info)
End

Function BrowseFolderButton(info) : ButtonControl
	Struct WMButtonAction &info
	if(info.eventCode==2) //Mouse up.  
		strswitch(info.ctrlName)
			case "Custom1":
#if exists("Synapse2Database")
				Synapse2Database() // The function that we will execute this time.  This can be changed at any time to reflect current analysis needs.  
#endif
				break
			case "Custom2":
#if exists("Synapse2Database")
				Synapse2Database(no_synapse=1) // The function that we will execute this time.  This can be changed at any time to reflect current analysis needs.  
#endif
				break
		endswitch
		
		// Advance the SweepByIndex SetVariable by 1.  
		Struct WMSetVariableAction info2
		ControlInfo SweepByIndex
		info2.dval=V_Value+1
		info2.ctrlName="SweepByIndex"
		info2.eventCode=1
		BrowseFolderSV(info2)
	endif
End

// An auxiliary function for BrowseFolder()
Function BrowseFolderSV(info) : SetVariableControl
	Struct WMSetVariableAction &info
	String package_folder="root:Packages:BrowseFolder"
	if(info.eventCode>=0)
		ControlInfo /W=FolderBrowser Folder
		SetWindow FolderBrowser, userData(folder)=S_Value
		String folder=GetUserData("FolderBrowser","","folder") 
		String prefix=GetUserData("FolderBrowser","","prefix")
		strswitch(info.ctrlName)
			case "SweepByNum":
				String sweep_name=RemoveEnding(folder,":")+":"+prefix+num2str(info.dval)
				String wave_name=sweep_name
				break
			case "SweepByIndex":
				String wave_list=WaveList2(folder=folder)
				if(info.dval>=ItemsInList(wave_list))
					NVar folder_sweep_index=$(package_folder+":folder_sweep_index")
					folder_sweep_index=ItemsInList(wave_list)-1
					return 0
				endif
				wave_name=StringFromList(info.dval,wave_list)
				sweep_name=RemoveEnding(folder,":")+":"+wave_name
				break
		endswitch		
		sweep_name=Quote(sweep_name)
		Wave /Z FolderSweep=$sweep_name
		if(waveexists(FolderSweep) && WaveType(FolderSweep))
			//PopUpMenu sweep_names,popValue=wave_name
			AppendToGraph FolderSweep
			String notes=note(FolderSweep)
			if(strlen(notes))
				TextBox /C/N=wavenote wave_name+"; "+notes
			else
				TextBox /C/N=wavenote wave_name
			endif
			// Also append a matching image
#if(exists("MatchingImage")) // The name of a function.  
		MatchingImage(FolderSweep)
#endif
		else
			return 0
		endif
		// Kill waves for traces that are downsampled versions of the real thing.  
		Variable i
		String traces=TraceNameList("",";",3)
		for(i=0;i<ItemsInList(traces);i+=1)
			String trace=StringFromList(i,traces)
			if(StringMatch(trace,"*ds*"))
				Wave /Z DS=TraceNameToWaveRef("",trace)
			endif
		endfor
		Wave /Z OffTrigger=TraceNameToWaveRef("","OffTrigger")
		SaveCursors("FolderBrowser")
		Variable old_offset=dimoffset(CsrWaveRef(A),0)
		String top_trace=TopTrace()
		RemoveTraces(except=top_trace)
		Wave TopWave=TraceNameToWaveRef("",top_trace)
		Variable new_offset=dimoffset(TopWave,0)
		RestoreCursors("FolderBrowser",offset=new_offset-old_offset)
		KillWaves /Z DS,OffTrigger
		String type
		sscanf info.ctrlName,"SweepBy%s",type
		NVar sv_value=$(package_folder+":folder_sweep_"+type)
		sv_value=info.dval
		new_offset=TopWave[0]
		ModifyGraph offset($top_trace)={0,-new_offset}
#if exists("Synapse2Database")
		SetAxis /A bottom
		WaveStats /Q/R=[100,] TopWave
		SetAxis left, V_min-20-new_offset,V_max+20-new_offset
		String command; Variable id
		sscanf top_trace,"X%d",id
		sprintf command,"SELECT Amplitude,Latency,Leak FROM ConnSynapses WHERE Synapse_ID=%d",id
		SQLc(command)
		Wave Amplitude,Latency,Leak
		String more_notes
		sprintf more_notes,"Amplitude=%.1f; Latency=%.1f, Leak=%d",Amplitude[0],Latency[0],Leak[0]
		AppendText /N=wavenote more_notes
		DrawAction delete
		SetDrawEnv xcoord=bottom, ycoord=left, linethick=3, linefgc=(0,65535,0), arrow=1, save
		DrawLine 0.3+Latency[0]/1000,0,0.3+Latency[0]/1000,-Amplitude[0]
		DrawLine 0.8+Latency[0]/1000,0,0.8+Latency[0]/1000,-Amplitude[0]
#endif
//		String file_name=wave_name
//		String channel=ShedSpaces(StringFromList(0,note(FolderSweep)))
//		String sweep_num_str=ShedSpaces(StringFromList(1,note(FolderSweep)))
//		LoadStimulusRegions(file_name,channel,str2num(sweep_num_str))
//		SVar stim_regions
//		DoUpdate
//		Wave /Z TopMostWave=$TopWave()
//		if(waveexists(TopMostWave))
//			Variable new_length=LongestReverbVC(TopMostWave,stim_regions=stim_regions,show_filtered=1)
//		else
//			new_length=0
//		endif
//		TextBox /A=RB/C/N=new_length num2str(new_length)
	endif
End

// Removes all traces with "fit" (or optional fit_name) in the title from all graphs
Function RemoveAllFits([fit_name])
	String fit_name
	String graph_list=ListGraphs()
	Variable i
	String graph
	if(ParamIsDefault(fit_name))
		fit_name="*fit*"
	endif
	for(i=0;i<ItemsInList(graph_list);i+=1)
		graph=StringFromList(i,graph_list)
		DoWindow /F $graph
		RemoveTraces(match=fit_name)
	endfor
End

// Append a list of waves to a graph
Function /S AppendListToGraph(list [,graph_name])
	String list
	String graph_name
	if(ParamIsDefault(graph_name))
		graph_name=WinName(0,1) // The top graph
	endif
	if(!cmpstr(graph_name,""))
		Display /K=1 /N=SomeWaves
	endif
	Variable i
	String wave_name
	list=RemoveEmpties(list)
	for(i=0;i<ItemsInList(list);i+=1)
		wave_name=StringFromList(i,list)
		AppendToGraph /W=$graph_name $wave_name
	endfor
	ScrambleColors()
	return list
End

Function ScrambleColors([color_table])
	String color_table
	if(ParamIsDefault(color_table))
		color_table="rainbow"
	endif
	ColorTab2Wave $color_table
	String list=TraceNameList("",";",1)
	Variable num_traces=ItemsInList(list)
	Variable i,red,green,blue
	Wave colors=M_colors
	Variable num_colors=dimsize(colors,0)
	Variable color
	String color_list=""
	Variable offset=0.5*num_colors/num_traces
	for(i=0;i<num_traces;i+=1)
		color_list+=num2str(floor(offset+num_colors*i/num_traces))+";" // Add evenly spaced color indices to this list
	endfor
	Variable random_int
	for(i=0;i<num_traces;i+=1)
		String trace=StringFromList(i,list)
		random_int=floor(UnifRnd(0,num_traces-i)) // Pick a random number within the range of the list
		color=str2num(StringFromList(random_int,color_list)) // Pick a color using that random number
		ModifyGraph rgb($trace)=(colors[color][0],colors[color][1],colors[color][2])
		color_list=RemoveFromList(num2str(color),color_list) // Remove that color from the list so it is not used again.  
	endfor
	KillWaves /Z colors
End

// Plot mean values as a function of the area cutoff.  Only useful for NR2
Function PlotMeans(first,last,list)
	Variable first,last
	String list
	Variable i,j
	String type
	first*=1000; last*=1000 // Converts from s to ms
	SetDataFolder root:
	KillWaves pooled_areas
	Make /o /n=1 pooled_areas
	for(i=0;i<ItemsInList(list);i+=1)
		type=StringFromList(i,list)
		Wave areas=$("root:W_areas_"+type+"_"+num2str(first)+"_"+num2str(last))
		for(j=0;j<numpnts(areas);j+=1)
			Redimension /n=(numpnts(pooled_areas)+1) pooled_areas
			pooled_areas[numpnts(pooled_areas)-1]=areas[j]
		endfor
	endfor
	Variable cutoff
	String answers
	KillWaves /Z cutoffs
	Make /o/n=(numpnts(pooled_areas)) cutoffs
	for(i=0;i<numpnts(cutoffs);i+=1)
		cutoffs[i]=pooled_areas[i]+0.0001
	endfor
	Sort cutoffs,cutoffs
	Display /K=1
	for(i=0;i<ItemsInList(list);i+=1)
		type=StringFromList(i,list)
		Wave areas=$("root:W_areas_"+type+"_"+num2str(first)+"_"+num2str(last))
		Make /o/n=(numpnts(cutoffs)) $("root:"+type+"_means"), $("root:"+type+"_SEMs")
		Wave means=$("root:"+type+"_means")
		Wave SEMs=$("root:"+type+"_SEMs")
		Wave data=$("root:W_time_constants_"+type+"_"+num2str(first)+"_"+num2str(last))
		for(j=0;j<numpnts(pooled_areas);j+=1)
			answers=WaveStats2(data,areas,cutoffs[j])
			means[j]=str2num(StringByKey("MEAN",answers))
			SEMs[j]=str2num(StringByKey("SEM",answers))
		endfor
		Sort cutoffs,means
		Sort cutoffs,SEMs
		AppendToGraph means vs cutoffs
		ErrorBars $(type+"_means"),Y wave=(SEMs,SEMs)
	endfor
	//ModifyGraph rgb(NMDA_means)=(0,0,0), rgb(NVP_means)=(0,0,65535), rgb(Ro25_means)=(65535,0,0)
	//ModifyGraph rgb(NVPDif_means)=(65535,0,65535), rgb(Ro25Dif_means)=(65535,32678,0)
	ColorCode(names="NMDA;NVP;Ro25;NVPDif;Ro25Dif",colors="0,0,0;0,0,65535;65535,0,0;65535,0,65535;65535,32678,0")
End

// Fit every trace in the top graph to a single exponential in the region from x1 to x2, except traces with "fit" in the name
Function Fits(x1,x2 [,fit_prefix,store,name,append])
	Variable x1,x2 // Fit between x1 and x2 (in seconds)
	String fit_prefix // An optional prefix for fitted traces (prepended to the wave name)
	Variable store // Whether to store data in the data string (and waves) (default does not store)
	String name // Name to give to the fitted data
	Variable append // Whether to append the data instead of clearing it first  (default is to clear)
	String trace_names=TraceNameList("",";",1)
	//String bad_traces=ListMatch(trace_names,"*fit*")
	//RemoveFromList2
	trace_names=RemoveFromList2("*fit*;*norm*",trace_names) // Remove anything with "fit" in it so it doesn't get included
	Variable i,baseline,average
	String trace_name
	if(ParamIsDefault(name))
		name=""
	endif
	if(!ParamIsDefault(store))
		if((ParamIsDefault(append) || append==0) || !exists("root:time_constants_"+name) || !exists("root:areas_"+name))
			String /G $("root:time_constants_"+name)=""
			String /G $("root:areas_"+name)=""
		endif
		SVar time_constants=$("root:time_constants_"+name)
		SVar areas=$("root:areas_"+name)
	endif
	if(ParamIsDefault(fit_prefix))
		fit_prefix="fit_"
	endif	
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:Fits
	for(i=0;i<ItemsInList(trace_names);i+=1)
		trace_name=StringFromList(i,trace_names)
		Wave trace=TraceNameToWaveRef("",trace_name)
		CurveFit /Q/W=0 exp trace(x1,x2) /D
		Wave fit=$("fit_"+trace_name)
		KillWaves /Z $(fit_prefix+trace_name)
		Rename fit, $(fit_prefix+trace_name)
		if(store)
			time_constants+=trace_name+":"+num2str(1000/K2)+";"
			WaveStats /Q/R=(x1,x2) trace; average=V_avg
			WaveStats /Q/R=(-0.01,-0.002) trace; baseline=V_avg
			areas+=trace_name+":"+num2str((x1-x2)*(average-baseline))+";"
		endif
	endfor
	SetDataFolder root:
	if(store)
		WaveFromKeyList("*","time_constants_"+name,bad_list_name="bad_list")
		WaveFromKeyList("*","areas_"+name,bad_list_name="bad_list")
	endif
	SetDataFolder curr_folder
End

Function ColorCode2([win_name])
	String win_name
	if(ParamIsDefault(win_name))
		win_name=WinName(0,1)
	endif
	String entry,key,value,color_key="*CTL*:0,0,0;*TTX*:65535,0,0"
	String trace,traces,trace_list=TraceNameList(win_name,";",3)
	Variable i,j,red,green,blue
	for(i=0;i<ItemsInList(color_key);i+=1)
		entry=StringFromList(i,color_key)
		key=StringFromList(0,entry,":")
		value=StringFromList(1,entry,":")
		traces=ListMatch(trace_list,key)
		red=str2num(StringFromList(0,value,","))
		green=str2num(StringFromList(1,value,","))
		blue=str2num(StringFromList(2,value,","))
		for(j=0;j<ItemsInList(traces);j+=1)
			trace=StringFromList(j,traces)
			ModifyGraph /W=$win_name rgb($trace)=(red,green,blue)
		endfor
	endfor
End

Function DifferentiateTraces([match])
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	String traces=TraceNameList("",";",3)
	traces=ListMatch(traces,match)
	Variable i; String trace
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave theWave=TraceNameToWaveRef("",trace)
		Differentiate theWave
	endfor	
End

Function SmoothTraces(smooth_factor[,left,right,cursors,match,method])
	Variable smooth_factor,left,right,cursors
	String match,method
	if(ParamIsDefault(match))
		match="*"
	endif
	if(ParamIsDefault(method))
		method="binomial"
	endif
	String traces=TraceNameList("",";",3)
	traces=ListMatch(traces,match)
	Variable i; String trace
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		variable column=TraceColumn(trace)
		Wave theWave=TraceNameToWaveRef("",trace)
		left=ParamIsDefault(left) ? leftx(theWave) : left
		right=ParamIsDefault(right) ? rightx(theWave) : right
		left=ParamIsDefault(cursors) ? left : xcsr(A)
		right=ParamIsDefault(cursors) ? right : xcsr(B)
		Duplicate /o/FREE/R=(left,right)[column] theWave segment
		strswitch(method)
			case "binomial":
				Smooth smooth_factor, segment
				break
			case "boxcar":
				Smooth /B=1 smooth_factor, segment
				break
		endswitch
		variable leftp=(left-dimoffset(theWave,0))/dimdelta(theWave,0)
		variable rightp=(right-dimoffset(theWave,0))/dimdelta(theWave,0)
		theWave[leftp,rightp][column]=segment[p]
	endfor	
End

Function LoessTraces(smooth_factor[,left,right,cursors,match])
	Variable smooth_factor,left,right,cursors
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	String traces=TraceNameList("",";",3)
	traces=ListMatch(traces,match)
	Variable i; String trace
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave theWave=TraceNameToWaveRef("",trace)
		left=ParamIsDefault(left) ? leftx(theWave) : left
		right=ParamIsDefault(right) ? rightx(theWave) : right
		left=ParamIsDefault(cursors) ? left : xcsr(A)
		right=ParamIsDefault(cursors) ? right : xcsr(B)
		Duplicate /o/R=(left,right) theWave segment
		Loess /N=(smooth_factor) srcWave=segment
		theWave=(x>=left && x<=right) ? segment(x) : theWave
	endfor	
	KillWaves /Z segment
End

Function IntegrateTraces([match])
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	String traces=TraceNameList("",";",3)
	traces=ListMatch(traces,match)
	Variable i; String trace
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave theWave=TraceNameToWaveRef("",trace)
		Integrate theWave
	endfor	
End

Function DifferentiateSweeps(channel)
	Variable channel
	String cellFolder
	Wave access_res=root:cellL2:access_res
	switch(channel)
		case 1:
			cellFolder="root:cellR1:"
			break
		case 2:
			cellFolder="root:cellL2:"
			break
		default:
			printf "Not a valid channel.\r"
	endswitch
	Variable n=1
	Do
		if(access_res[n-1]!=0) // In other words, if it is not a pairing sweep
			Duplicate/o $(cellFolder+"sweep"+num2str(n)) waveToDifferentiate
			//FFT waveToCompensate
			//waveToCompensate[x2pnt(waveToCompensate,60)]=0 // Remove the 60 Hz noise
			//IFFT waveToCompensate
			smooth 25,waveToDifferentiate
			Differentiate waveToDifferentiate /D=$(cellFolder+"sweep"+num2str(n)+"D")
		endif
		n+=1
	While(waveexists($(cellFolder+"sweep"+num2str(n))))
End

// Plots X vs each of a list of parameters on a separate graph.  Will look for mean and sem wave for each item on the list
Function PlotKeyFeaturevsList(key_feature,conditions,param_list)
	String key_feature,conditions,param_list
	Wave /T CellExperimenter,CellCondition,CellBath_Drug
	String avg_name,sem_name,key_name,param,condition,person,injected,bath_applied,file,graph_name
	SVar file_list
	Variable i,j,k,index
	//NewLayout /K=1 /N=$(CleanUpName(key_feature+"VS"+param_list+"_Layout",0))
	for(i=0;i<ItemsInList(param_list);i+=1)
		param=StringFromList(i,param_list)
		graph_name=CleanUpName(key_feature+"VS"+param+"_Win",0)
		Display /K=1 /N=$graph_name
		for(j=0;j<ItemsInList(conditions);j+=1)
			condition=StringFromList(j,conditions)
			person=StringFromList(0,condition,",")
			injected=StringFromList(1,condition,",")
			bath_applied=StringFromList(2,condition,",")
			condition=ReplaceString(",",condition,"_")
			avg_name=UniqueName("A_"+param+"_"+condition,1,0)
			sem_name=UniqueName("S_"+param+"_"+condition,1,0)
			key_name=UniqueName(key_feature+param+"_"+condition,1,0)
			Make /o/n=1 $avg_name,$sem_name,$key_name
			Make /o/n=1 $(CleanupName("A"+avg_name,1)),$(CleanupName("S"+avg_name,1))
			Make /o/n=1 $(CleanupName("A"+key_name,1)),$(CleanupName("S"+key_name,1))
			Wave avg=$avg_name
			Wave sem=$sem_name
			Wave key=$key_name
			Wave AvgAvg=$(CleanupName("A"+avg_name,1))
			Wave AvgSEM=$(CleanupName("S"+avg_name,1))
			Wave KeyAvg=$(CleanupName("A"+key_name,1))
			Wave KeySEM=$(CleanupName("S"+key_name,1))
			index=0
			for(k=0;k<ItemsInList(file_list);k+=1)
				file=StringFromList(k,file_list)
				if(StringMatch(CellExperimenter[k],person) && StringMatch(CellCondition[k],injected) && StringMatch(CellBath_Drug[k],bath_applied))
					Redimension /n=(index+1) avg,sem,key
					Wave params= $(file+"_"+param)
					Wave cellkey=$("Cell"+key_feature)
					WaveStats /Q params
					//avg[k]=V_avg
					avg[index]=V_npnts>0 ? Median1(params,-Inf,Inf) : NaN // Use median instead of mean
					sem[index]=V_sdev/sqrt(V_npnts)
					key[index]=cellkey[k]
					index+=1
				endif
			endfor
			Condition2Color(injected); NVar red,green,blue
			AppendToGraph /c=(red,green,blue)  Avg vs Key
			ModifyGraph mode=3,marker($NameOfWave(Avg))=8,msize($NameOfWave(Avg))=2
			ErrorBars $NameOfWave(Avg),Y wave=(SEM,SEM)
			WaveStats /Q Avg; AvgAvg=V_avg; AvgSEM=V_sdev/sqrt(V_npnts)
			WaveStats /Q Key; KeyAvg=V_avg; KeySEM=V_sdev/sqrt(V_npnts)
			AppendToGraph /c=(red,green,blue)  AvgAvg vs KeyAvg
			ModifyGraph mode=3,marker($NameOfWave(AvgAvg))=19,msize($NameOfWave(AvgAvg))=4
			ErrorBars $NameOfWave(AvgAvg),Y wave=(AvgSEM,AvgSEM)
		endfor
		ModifyGraph log(bottom)=1, swapXY=1
		Label bottom param+SelectString(StringMatch(param,"Width")," (mV)"," (ms)")
		Label left key_feature+SelectString(StringMatch(key_feature,"Rate"),""," (Hz)")
		//AppendLayoutObject graph $graph_name
	endfor
	//Execute /Q "Tile"
End

// Will append the last num_graphs graphs to a new layout
Function LayoutGraphs(num_graphs,[name])
	Variable num_graphs
	String name
	if(ParamIsDefault(name))
		name="Layout"
	endif
	NewLayout /K=1 /N=$CleanUpName(name,1)
	Variable i
	String graph_list=WinList("*",";","WIN:1"), graph
	for(i=num_graphs-1;i>=0;i-=1)
		AppendLayoutObject graph $StringFromList(i,graph_list)
	endfor
	Execute "Tile"
End

Function KeyFeatureLayout(param)
	String param
	PlotKeyFeaturevsList("Rate","Roger,Control,;Roger,PTX,",param)
	PlotKeyFeaturevsList("Rate","Rick,Control,;Rick,PTX,;Rick,PTZ,",param) 
	PlotKeyFeaturevsList("Rate","Roger,Control,Iberiotoxin;Roger,PTX,Iberiotoxin",param)
	LayoutGraphs(3,name=param)
End

Function ScaleAll([left_min,left_max,bottom_min,bottom_max])
	Variable left_min,left_max,bottom_min,bottom_max
	String list=WinList("*",";","WIN:1")
	Variable i; String win
	DoUpdate
	for(i=0;i<ItemsInList(list);i+=1)
		win=StringFromList(i,list)
		GetAxis /Q/W=$win left
		left_min=ParamIsDefault(left_min) ? V_min : left_min
		left_max=ParamIsDefault(left_max) ? V_max : left_max
		GetAxis /Q/W=$win bottom
		bottom_min=ParamIsDefault(bottom_min) ? V_min : bottom_min
		bottom_max=ParamIsDefault(bottom_max) ? V_max : bottom_max
		SetAxis /W=$win left,left_min,left_max
		SetAxis /W=$win bottom,bottom_min,bottom_max
	endfor
End
