// $URL: svn://raptor.cnbc.cmu.edu/rick/recording-artist/Recording%20Artist/Other/Minis.ipf $
// $Author: rick $
// $Rev: 632 $
// $Date: 2013-03-15 17:17:39 -0700 (Fri, 15 Mar 2013) $

#pragma moduleName=Minis
#pragma rtGlobals=1		// Use modern global access method.
#include "Batch Wave Functions"
#include "Fit Functions"
//#include "Utilities"
//#include "List Functions"
#include "Progress Window"

strconstant minisFolder="root:Minis:"
strconstant miniFitCoefs="Rise Time;Decay Time;Offset Time;Baseline;Amplitude;" // Rise_Time will be fixed to 1 ms.  
strconstant miniRankStats="Chi-Squared;Event Size;Event Time;R2;Log(1-R2);Cumul Error;Mean Error;MSE;Score;Rise 10%-90%;Interval;Plausability;pFalse;"
strconstant miniOtherStats="Fit Time Before;Fit_Time_After;"
//strconstant miniFitCoefs="Decay_Time;Offset_Time;y0;Amplitude"
constant miniFitBefore=3 // In ms. Set to approximately the rise time constant.  
constant miniFitAfter=9 // In ms. Set to approximately twice the decay time constant.   

#ifdef SQL
	override constant SQL_=1
#endif
constant SQL_=0
constant fitOffset=25

#if exists("SQLHighLevelOp") && strlen(functionlist("SQLConnekt",";",""))
#define SQL
#endif

// Static functions that replace those found in the Acq package, if it is not present.  
#ifndef Acq
// Returns a list of used channels.   
#if !exists("UsedChannels")
static Function /S UsedChannels()
	String currFolder=GetDataFolder(1)
	Variable i,j
	String str1,str2,channelsUsed=""
	for(i=0;i<CountObjects("root:",4);i+=1)
		String folder=GetIndexedObjName("root:",4,i)
		for(j=0;j<CountObjects("root:"+folder,1);j+=1)
			String wave_name=GetIndexedObjName("root:"+folder,1,j)
			sscanf wave_name,"%[sweep]%s",str1,str2
			if(StringMatch(str1,"sweep") && numtype(str2num(str2))==0)
				channelsUsed+=folder+";"
				break
			endif
		endfor
	endfor
	return channelsUsed
End
#endif

// Returns a list of methods using the code in case 'method'.  Usually this will be a list with one element, the same as the input.  
static Function /S MethodList(method)
	String method
	
	Variable i
	String methods=ListPackageInstances(module,"analysisMethods")
	String matchingMethods=""
	for(i=0;i<ItemsInList(methods);i+=1)
		String oneMethod=StringFromList(i,methods)
		string sourceMethod=StrPackageSetting(module,"analysisMethods",oneMethod,"method")
		if(stringMatch(sourceMethod,method))
			matchingMethods+=oneMethod+";"
		endif
	endfor
	return matchingMethods
End

// Returns the name of the top-most trace on a graph.  
// Simplified version of function in 'Experiment Facts.ipf', reproduced here for simplicity.  
static Function /S TopTrace()
	String traces=TraceNameList("",";",1)
	String topTrace=StringFromList(ItemsInList(traces)-1,traces)
	return topTrace
End

static Function RemoveTraces()
	String traces=TraceNameList("",";",1)
	traces=SortList(traces,";",16)
	Variable i=ItemsInList(traces)-1
	Do
		String trace=StringFromList(i,traces)
		RemoveFromGraph /Z $trace
		i-=1
	While(i>=0)
End
#endif

Menu "Analysis"
	"Minis",/Q,InitMiniAnalysis() 
End

Function InitMiniAnalysis()
	variable err=0
	variable lastSweep=GetCurrSweep()
	if(!lastSweep)
		DoAlert 0,"No experiment data to use."
		err=-1
	else
		dfref df=NewFolder(minisFolder)
		string /g df:sweeps="0-"+num2str(lastSweep-1)
		variable /g df:threshold=-5
		MiniAnalysisPanel()
	endif
	return err
End

function /s GetUsedMiniChannels()
	string channels=UsedChannels()
	variable i
	do
		string channel=stringfromlist(i,channels)
		dfref df=GetMinisChannelDF(channel,proxy=0)
		if(!datafolderrefstatus(df))
			channels=removefromlist(channel,channels)
		else
			i+=1
		endif
	while(i<itemsinlist(channels))
	return channels
end

function /df GetMinisDF()
	dfref df=newfolder(minisFolder)
	string variables
	sprintf variables,"currMini=0;fit_before=%f;fit_after=%f",miniFitBefore,miniFitAfter
	string strings
	sprintf strings,"channels=%s;",""//GetUsedMiniChannels()
	InitVars(df=df,vars=variables,strs=strings)
	return df
end

function /df GetMinisChannelDF(channel[,create,proxy])
	string channel
	variable create,proxy
	
	if(paramisdefault(proxy))
		proxy=GetMinisProxyState()
	endif
	string suffix=""
	if(proxy)
		suffix="_"+cleanupname(stringfromlist(proxy,proxies),0)
	endif
	dfref df=GetMinisDF()
	if(create)
		newdatafolder /o df:$(channel+suffix)
	endif
	dfref df_=df:$(channel+suffix)
	return df_
end

function /df GetMinisSweepDF(channel,sweep[,create,proxy])
	string channel
	variable sweep,create,proxy
	
	proxy = paramisdefault(proxy) ? GetMinisProxyState() : proxy
	
	dfref df=GetMinisChannelDF(channel,proxy=proxy)
	string name="sweep"+num2str(sweep)
	if(create)
		newdatafolder /o df:$name
	endif
	dfref df_=df:$name
	return df_
end

function /df GetMinisOptionsDF([create])
	variable create
	
	dfref df=GetMinisDF()
	if(create)
		newdatafolder /o df:options
	endif
	dfref df_=df:options
	return df_
end

Function MiniAnalysisPanel()
	DoWindow /K MiniAnalysisWin
	NewPanel /K=1 /N=MiniAnalysisWin as "Mini Analysis"
	Variable xStart=0,yStart=0,xx=xStart,yy=yStart,xJump=65,yJump=25
	PopupMenu Channels, pos={xx,yy}, value=#("ListCombos(\""+UsedChannels()+"\")"),title="Channels",mode=ItemsInList(ListCombos(UsedChannels())),proc=MiniAnalysisWinPopupMenus
	yy+=yJump
	
	dfref df=GetMinisDF()
	svar /sdfr=df sweeps
	nvar /sdfr=df threshold
	
	SetVariable Sweeps, pos={xx,yy}, size={200,20}, title="Sweeps", value=_STR:sweeps,proc=MiniAnalysisWinSetVariables
	yy+=yJump
	Checkbox Clean, pos={xx,yy}, value=0,title="Clean",proc=MiniAnalysisWinCheckboxes
	xx+=xJump
	Checkbox Search, pos={xx,yy}, value=1,title="Search",proc=MiniAnalysisWinCheckboxes
	xx+=xJump
	Checkbox UseCursors, pos={xx,yy}, value=0,title="Cursors",proc=MiniAnalysisWinCheckboxes
#ifdef SQL
	xx+=xJump
	Checkbox DB, pos={xx,yy}, value=0,title="Database",proc=MiniAnalysisWinCheckboxes
#endif
	xx+=xJump
	PopupMenu proxy, pos={xx,yy-3}, mode=1,value=proxies,title="Proxy",proc=MiniAnalysisWinPopupMenus
	xx=xStart; yy+=yJump
	SetVariable Threshold, pos={xx,yy}, size={95,20}, title="Threshold", limits={-Inf,Inf,0.5}, value=threshold,proc=MiniAnalysisWinSetVariables
	xx=xStart; yy+=yJump
	Button Start, pos={xx,yy}, title="Start", proc=MiniAnalysisWinButtons
End

Function MiniAnalysisWinButtons(ctrlName)
	String ctrlName
	
	string type=StringFromList(0,ctrlName,"_")
	string channel=ctrlName[strlen(type)+1,strlen(ctrlName)-1]
	strswitch(type)
		case "Start":
			Controlinfo Clean; Variable clean=V_Value
			Controlinfo Search; Variable miniSearch=V_Value
			ControlInfo Channels; String channels=ReplaceString(",",S_Value,";")
			Controlinfo DB; Variable DB=V_Value
			Controlinfo proxy; Variable proxy=V_Value-1
			Controlinfo Threshold; Variable threshold=V_Value
			Controlinfo Sweeps; String sweeps=S_Value
			ControlInfo UseCursors; Variable useCursors=V_Value
			Variable tStart=(useCursors && strlen(csrinfo(A,"SweepsWin")) ? xcsr(A,"SweepsWin") : 0
			Variable tStop=(useCursors && strlen(csrinfo(B,"SweepsWin")) ? xcsr(B,"SweepsWin") : Inf
			CompleteMiniAnalysis(clean=clean,miniSearch=miniSearch,channels=channels,threshold=threshold,noDB=!DB,sweeps=sweeps,tStart=tStart,tStop=tStop,proxy=proxy)
			break
		case "ShowMinis":
			dfref df=GetMinisDF()
			svar /sdfr=df channelsUsed
			//Wave /T Baseline_Sweeps,Post_Activity_Sweeps
			//String regions=Baseline_Sweeps[0]+Post_Activity_Sweeps[0]
			Variable i
			for(i=0;i<ItemsInList(channelsUsed);i+=1)
				channel=StringFromList(i,channelsUsed)
				dfref chanDF=GetMinisChannelDF(channel)
				wave /t/sdfr=chanDF MiniCounts,MiniNames
				wave /sdfr=chanDF MC_SelWave
				MiniCounts[][2]=SelectString(MC_SelWave[p][2] & 16,"Ignore","Use") // Update MiniCounts to reflect the value of the Checkbox.  May not be necessary.  
				if(!waveexists(miniNames))
					InitMiniStats(channel)
				endif
			endfor
			ShowMinis(channels=channelsUsed)//,regions=regions)
			break
		case "Ignore":
			dfref chanDF=GetMinisChannelDF(channel)
			wave /t/sdfr=chanDF MiniCounts
			wave /sdfr=chanDF MC_SelWave
			variable sweepNum
			for(i=0;i<numpnts(MC_SelWave);i+=1)
				if(MC_SelWave[i][0]>0)
					MC_SelWave[i][2] = 32
					MiniCounts[i][2]="Ignore"  
				endif
			endfor
			break
	endswitch
End

Function MiniAnalysisWinCheckboxes(ctrlName,value)
	String ctrlName
	Variable value
	
	dfref df=GetMinisDF()
	strswitch(ctrlName)
		case "DB":
			SetVariable Sweeps, disable=value
			break
	endswitch
End

Function MiniAnalysisWinSetVariables(info)
	Struct WMSetVariableAction &info
	
	if(info.eventCode<0)
		return 0
	endif
	dfref df=GetMinisDF()
	strswitch(info.ctrlName)
		case "Sweeps":
			string /g df:sweeps=ListExpand(info.sval)
			break
	endswitch
End

Function MiniAnalysisWinPopupMenus(info)
	Struct WMPopupAction &info
	
	if(!PopupInput(info.eventCode))
		return 0
	endif
	dfref df=GetMinisDF()
	strswitch(info.ctrlName)
		case "Channels":
			//Wave Channels=root:Minis:Channels
			//String used=UsedChannels()
			//Channels=WhichListItem(StringFromList(p,used),info.popStr)>=0
			break
		case "Proxy":
			variable /g df:proxy=whichlistitem(info.popStr,proxies)
			nvar /sdfr=df proxy
			string suffix=""
			if(proxy)
				suffix="_"+cleanupname(info.popStr,0)
			endif
			string channels=UsedChannels()
			variable i
			for(i=0;i<itemsinlist(channels);i+=1)
				string channel=stringfromlist(i,channels)
				string ctrlName="MiniCounts_"+channel
				controlinfo $ctrlName
				if(v_flag>0)
					variable create=0
					df=GetMinisChannelDF(channel)
					if(datafolderrefstatus(df))
						wave /z/sdfr=df MC_SelWave
						if(!waveexists(MC_SelWave))
							create=1
						endif
					else
						create=1
					endif
					if(create)
						InitMiniCounts(channel)
						df=GetMinisChannelDF(channel)
						if(!datafolderrefstatus(df))
							break
						endif
					endif
					wave /sdfr=df MC_SelWave
					wave /t/sdfr=df MiniCounts
					Listbox $ctrlName,listWave=MiniCounts,selWave=MC_SelWave
				endif
			endfor
			break
	endswitch
End

// Keeps the listboxes in sync 
Function MiniAnalysisWinListboxes(info) : ListBoxControl
	STRUCT WMListboxAction &info
	
	variable numChannels=GetNumChannels()
	Wave /T Labels=GetChanLabels()
	
	String type=StringFromList(0,info.ctrlName,"_")
	String channel=info.ctrlName
	channel=channel[strlen(type)+1,strlen(channel)-1]
	String listboxName="MiniCounts_"+channel
	dfref df=GetMinisChannelDF(channel)
	if(!DataFolderRefStatus(df))
		return -1
	endif
	
	switch(info.eventCode)
		case 2: // Clicking the mouse.  
			// Pass through to case 4.  
		case 4: // Picking a new sweep.  			
			Wave /T/sdfr=df MiniCounts
			Wave /sdfr=df MC_SelWave
			variable i,sweepNum=str2num(MiniCounts[info.row][0])	
			variable numMinis=str2num(MiniCounts[info.row][1])
			variable numSweeps=dimsize(MiniCounts,0)
			if(numtype(numMinis))
				MC_SelWave[info.row][2]=MC_SelWave[info.row][2] & ~16
			endif
			if(info.col==2)
				MiniCounts[info.row][2]=SelectString(MC_SelWave[info.row][2] & 16,"Ignore","Use") // Update MiniCounts to reflect the value of the Checkbox.  
				wave /z/sdfr=df Use,Index
				if(waveexists(Use) && info.eventCode==2)
					make /free/n=(numSweeps) counts=str2num(MiniCounts[p][1])
					insertpoints 0,1,counts
					counts[0]=0
					integrate counts
					variable start=counts[info.row]
					variable finish=counts[info.row+1]-1
					if(finish>=start)
						variable yes=stringmatch(MiniCounts[info.row][2],"Use")
						Use[start,finish]=yes
						for(i=start;i<=finish;i+=1)
							FindValue /V=(i) Index
							if(yes && v_value<0)
								insertpoints 0,1,Index
								Index[0]=i
							elseif(!yes && v_value>=0)
								deletepoints i,1,index
							endif
						endfor
					endif
				endif
			endif
			if(info.eventCode==2)
				break
			endif
			Variable chan=Label2Chan(channel)
			if(WinType("SweepsWin"))
				Checkbox $("Show_"+num2str(chan)) value=1, win=SweepsWin
			endif
			//sweepNum=str2num(MiniCounts[info.row][0])
#if exists("MoveCursor")==6
			MoveCursor("A",sweepNum)
#endif
			break
		case 8: // Vertical scrolling.  Used to keep listboxes in sync (always scrolled vertically to the same degree).  
			for(i=0;i<numChannels;i+=1)
				String otherChannel=Labels[i]
				if(!StringMatch(channel,otherChannel))
					String otherListboxName="MiniCounts_"+otherChannel
					ControlInfo $otherListboxName
					if(V_flag !=0 && V_startRow != info.row) // If the listbox exists and is not at the same row as the selected listbox.  
						Listbox $otherListboxName,row=info.row
						ControlUpdate $listboxName
					endif
				endif
			endfor
			break
	endswitch
End

// ----------------------------- Other mini analysis functions.  ---------------------------------

Function CompleteMiniAnalysis([clean,miniSearch,channels,threshold,skip,noDB,sweeps,tStart,tStop,proxy])
	Variable clean // Clean the sweeps first (remove noise).
	Variable miniSearch // Proceed with the search for minis, (after cleaning if clean=1).    
	String channels // Channels to analyze.  
	Variable threshold // Threshold for minis (in pA).  
	String skip // Regions to skip in the format "channel: region".  Not yet implemented.  
	Variable noDB // Don't look for a list of sweeps in the database.  Just use the cursors in Ampl_Analysis.  
	String sweeps // A manual sweeps.  
	variable tStart,tStop // Start and stop time values within each sweep to search.  
	variable proxy // Search time-reversed sweeps, to serve as a control.  
	
	if(!paramisdefault(proxy))
		SetMinisProxyState(proxy)
	else
		proxy=GetMinisProxyState()
	endif
	clean=ParamIsDefault(clean) ? 0 : clean
	miniSearch=ParamIsDefault(miniSearch) ? 1 : miniSearch
	if(ParamIsDefault(channels))
		channels=UsedChannels()
	endif
	threshold=ParamIsDefault(threshold) ? 7.5 : threshold
	if(ParamIsDefault(sweeps))
		sweeps=""
	endif
	
	variable i,j,currSweep=GetCurrSweep()
	dfref df=NewFolder(minisFolder)
	variable /g df:miniThresh=threshold
	string fileName=IgorInfo(1)
	
	if(noDB || !ParamIsDefault(sweeps))
		if(!ParamIsDefault(sweeps))
		elseif(WinType("AnalysisWin") && strlen(CsrInfo(A,"AnalysisWin")))
			sweeps=num2str(xcsr(A,"Ampl_Analysis"))+","+num2str(xcsr(B,"Ampl_Analysis"))
		else
			printf"You must provide a database entry, or an Ampl_Analysis window with cursors, or a sweep list.\r"  
			return 0
		endif
		sweeps=ListExpand(sweeps)
	else
#ifdef SQL
		// Connect to the database and get the information about which sweeps should be searched for minis.  
		SQLConnekt("Reverb")
		SQLc("SELECT * FROM Mini_Sweeps WHERE Experimenter='RCG' AND File_Name='"+fileName+"'")
		SQLDisconnekt()
		Wave /T Baseline_Sweeps,Post_Activity_Sweeps
		
		// Add all of the sweeps from the lists contained in the database to 'sweeps', a list of sweeps that will be processed.  
		for(i=0;i<ItemsInList(Baseline_Sweeps[0]);i+=1)
			string temp_list=StringFromList(i,Baseline_Sweeps[0])
			sweeps+=ListExpand(temp_list)
		endfor
		for(i=0;i<ItemsInList(Post_Activity_Sweeps[0]);i+=1)
			temp_list=StringFromList(i,Post_Activity_Sweeps[0])
			sweeps+=ListExpand(temp_list)
		endfor
#endif
	endif
	
	// Prepare to measure the progress of the subsequent operations.  
	variable numChannels=itemsinlist(channels)
	make /free/n=(numChannels) channelSweeps
	for(i=0;i<numChannels;i+=1)
		string channel=StringFromList(i,channels)
		for(j=0;j<ItemsInList(sweeps);j+=1)
			variable sweepNum=NumFromList(j,sweeps)
			wave /Z sweep=GetChannelSweep(channel,sweepNum)
			if(WaveExists(Sweep))
				channelSweeps[i]+=1
			endif
		endfor
	endfor
	
	// Cleaning up the sweeps.  
	if(clean)
#ifdef Acq
		for(i=0;i<numChannels;i+=1)
			channel=StringFromList(i,channels)
			if(numChannels>1)
				Prog("Channel",i,numChannels,msg=channel)
			endif
			variable sweepsCompleted=0
			for(j=0;j<ItemsInList(sweeps);j+=1)
				sweepNum=NumFromList(j,sweeps)
				wave /Z sweep=GetChannelSweep(channel,sweepNum)
				if(WaveExists(Sweep))
					Prog("Removing noise...",sweepsCompleted,channelSweeps[i],msg="Sweep "+num2str(sweepNum))
					CleanWaves(channel,num2str(sweepNum))
					sweepsCompleted+=1
				endif
			endfor
		endfor
#endif
	endif
	
	// Searching for minis.  
	if(miniSearch)
		//sweepsCompleted=0
		string /G df:sweeps=sweeps
		for(i=0;i<numChannels;i+=1)
			channel=StringFromList(i,channels)
			if(numChannels>1)
				Prog("Channel",i,itemsinlist(channels),msg=channel)
			endif
			InitMiniCounts(channel)
			SetMinisChannel(channel)
			dfref df=GetMinisChannelDF(channel)
			wave /t/sdfr=df MiniCounts
			sweepsCompleted=0
			string formattedChannel=selectstring(proxy,channel,channel+" ("+stringfromlist(proxy,proxies)+")")
			for(j=0;j<ItemsInList(sweeps);j+=1)
				sweepNum=str2num(StringFromList(j,sweeps))
				MiniCounts[j][0]=num2str(sweepNum)
				wave /z sweep=GetChannelSweep(channel,sweepNum)
				if(WaveExists(Sweep))
					string msg
					sprintf msg,"%s sweep %d",formattedChannel,sweepNum
					Prog("Searching for minis...",sweepsCompleted,channelSweeps[i],msg=msg,parent="Channel")
					tStart=paramisdefault(tStart) ? leftx(Sweep) : tStart
					tStop=paramisdefault(tStop) ? rightx(Sweep) : tStop
					variable count=MiniAnalysis(sweepNum,channel,thresh=threshold,clean=0,tStart=tStart,tStop=tStop,proxy=proxy)
					MiniCounts[j][1]=num2str(count)
					MiniCounts[j][2]="Use"
					sweepsCompleted+=1
				endif
			endfor
			//WaveStats /Q/M=1 MiniCounts
			//Variable /G root:Minis:$(channel):raw_mini_count=round(V_avg*V_npnts)
		endfor
		MiniCountReview(channels)
	endif
End

Function MiniCountReview(channels)
	String channels
	if(!WinType("MiniAnalysisWin"))
		return -1
	endif
	
	Struct rect coords
	Core#GetWinCoords("MiniAnalysisWin",coords,forcePixels=1)
	MoveWindow /W=MiniAnalysisWin coords.left,coords.top,coords.left+125*(max(2,ItemsInList(channels))),coords.top+350
	DoWindow /F MiniAnalysisWin
	Variable xStart=0,yStart=150,xx=xStart,yy=yStart,xJump=165
	Variable i;String channel
	Variable num_channels=ItemsInList(channels)
	dfref df=GetMinisDF()
	for(i=0;i<num_channels;i+=1)
		yy=yStart
		channel=StringFromList(i,channels)
		dfref chanDF=GetMinisChannelDF(channel,create=1)
		InitMiniStats(channel)
		svar /sdfr=df sweeps
		wave /t/sdfr=chanDF MiniCounts
		make /o/n=(dimsize(MiniCounts,0),dimsize(MiniCounts,1)) chanDF:MC_SelWave /wave=MC_SelWave
		MC_SelWave=0
		MC_SelWave[][2]=32+16*StringMatch(MiniCounts[p][2],"Use")//*(WhichListItem(num2str(p),sweeps)>=0)
		DrawText xx,yy,"Sweep"; xx+=47
		DrawText xx,yy,"Minis"; xx+=57
		DrawText xx,yy,"Use"; xx=xStart+i*xJump
		yy+=5
		ListBox $("MiniCounts_"+channel),widths={35,40,60},size={160,100},pos={xx,yy},listWave=MiniCounts,selWave=MC_SelWave,frame=2,mode=4,proc=MiniAnalysisWinListboxes
		//String /G ignore_sweeps=""
		yy+=100
		Button $("Ignore_"+channel),pos={xx,yy},size={160,20},title=channel+" ignore",proc=MiniAnalysisWinButtons
		xx+=xJump
	endfor
	string /g df:channelsUsed=channels
	xx=xStart; yy+=35
	Button ShowMinis,pos={xx,yy},size={100,20},proc=MiniAnalysisWinButtons,title="Show Minis"
	xx+=120; yy+=3
	Checkbox IgnoreStimulusSweeps,pos={xx,yy},size={100,20},title="Ignore Sweeps with Stimuli",value=0
End

Function MiniTimeCoursePlot(channel)
	String channel
	dfref df=GetMinisChannelDF(channel)
	make /o/n=0 df:AllLocs /wave=AllLocs,df:AllVals /wave=AllVals
	Variable i
	wave Sweep_t=GetSweepT()
	for(i=0;i<numpnts(Sweep_t);i+=1)
		Variable sweep_time=Sweep_t[i]
		Variable sweepNum=i+1
		String mini_folder="Sweep"+num2str(sweepNum)
		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
		if(DataFolderRefStatus(sweepDF))
			wave /z/sdfr=sweepDF Locs,Vals
			Variable index=numpnts(AllLocs)
			if(waveexists(Locs) && numtype(sweep_time)==0)
				Locs+=sweep_time*60
				Concatenate /NP {Locs},AllLocs
				Locs-=sweep_time*60
				Concatenate /NP {Vals},AllVals
			endif
		endif
	endfor
	AllLocs/=60
	Display /K=1 AllVals vs AllLocs
	ModifyGraph mode=2
	ModifyGraph lsize=3
	Duplicate /o AllVals AvgVals
	AvgVals=mean(AllVals,p-35,p+35)
	AppendToGraph /c=(65535,0,0) AvgVals vs AllLocs
End

// Average the minis currently available in the Mini Browser and display the average waveform.  
Function AverageMinis([peak_align,peak_scale])
	variable peak_align // Aligns to fitted peak.  Otherwise, aligns to fitted offset.  
	variable peak_scale // Scales all minis so that fitted event size equals 1.  
	
	removefromgraph /z AverageMini
	controlinfo Channel; string channel=s_value
	//Display /K=1 /N=$("AllMinis_"+channel)
	dfref df=GetMinisChannelDF(channel)
	wave /sdfr=df /T MiniNames
	wave /z/sdfr=df Event_Size,Offset_Time,Baseline
	variable i,miniNum,sweepNum
	variable red,green,blue; GetChannelColor(channel,red,green,blue)
	string traces=TraceNameList("",";",1)
	variable minis=0
	for(i=0;i<itemsinlist(traces);i+=1)
		string trace=stringfromlist(i,traces)
		FindValue /TEXT=trace /TXOP=4 MiniNames
		if(v_value<0)
			printf "Couldn't find index for mini in trace %s.\r",trace
			continue
		else
			variable index=v_value
		endif
		sscanf trace, "Sweep%d_Mini%d", sweepNum, miniNum
		wave sweep=GetChannelSweep(channel,sweepNum)
		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
		wave /z/sdfr=sweepDF Locs
		wave /z MiniIndex=sweepDF:Index
		if(numtype(Locs[index]*Offset_Time[index]*Event_Size[index]*Baseline[index]))
			printf "No fit available for %s.\r",trace
			continue
		endif
		if(!peak_align)
			variable loc=Offset_Time[index]/1000//Locs[miniNum]
		elseif(peak_align)
			wave /sdfr=sweepDF Fit=$("Fit_"+num2str(miniNum))
			wavestats /Q/M=1 Fit
			FindValue /V=(miniNum) MiniIndex
			loc=Locs[V_Value]+V_minloc
		endif
		variable scale=peak_scale ? 1/Event_Size[index] : 1
		if(minis==0)
			duplicate /o/r=(loc-0.015,loc+0.03) sweep, df:AverageMini /wave=AverageMini
			setscale x,-0.015,0.03,AverageMini
			AverageMini=(AverageMini-Baseline[index])*scale
		else
			AverageMini+=(sweep(loc+x)-Baseline[index])*scale
		endif
		minis+=1
	endfor
	if(minis)
		AverageMini/=minis
		red=min(60000,65535-red); green=min(60000,65535-green); blue=min(60000,65535-blue)
		appendtograph /c=(65535-red,65535-green,65535-blue) AverageMini
		ModifyGraph lsize($TopTrace())=2
	else
		printf "No traces with minis were found.\r"
	endif
End


// Score a wave for minis according to the Bekkers and Clements method.  
Function MiniScore(Data,Template)
	Wave Data,Template
	Variable length=numpnts(Template)
	Make /o/n=(numpnts(Data)-length+1) MiniScores=NaN
	Duplicate/o Template Fitted_Template
	Variable i
	//Duplicate/o/R=[0,0+length-1] Data, $"Piece"; Wave Piece
	for(i=0;i<numpnts(MiniScores);i+=1)
		Duplicate/o/R=[i,i+length-1] Data, $"Piece"; Wave Piece
		MatrixOp /o ScaleWave=(Template.Piece-sum(Template)*sum(Piece)/length)/(Template.Template-sum(Template)*sum(Template)/length)
		Variable Offset=(sum(Piece)-ScaleWave[0]*sum(Template))/length;
		//MatrixOp /o Fitted_Template=Template*Scale[0]+Offset;
    		MatrixOp /o SSE=sumsqr(Piece-Fitted_Template)
		Variable Standard_Error=sqrt(SSE[0]/(length-1)) // Should this be -1 or not?  
		MiniScores[i]=ScaleWave/Standard_Error
    	endfor
    	CopyScales /P Data,MiniScores
End

Function PlotAllMiniFits(channel)
	String channel
	Variable i,j
	Variable red,green,blue; GetChannelColor(channel,red,green,blue)
	dfref df=GetMinisChannelDF(channel)
	wave /t/sdfr=df MiniNames
	wave /sdfr=df Index
	Display /K=1
	for(i=0;i<numpnts(Index);i+=1)
		String mini_name=MiniNames[Index[i]]
		Variable sweepNum,miniNum
		sscanf mini_name, "Sweep%d_Mini%d", sweepNum,miniNum
		String fit
		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
		wave /sdfr=sweepDF FitWave=$("Fit_"+num2str(miniNum))
		wave /sdfr=df Baseline,Offset_Time,Event_Size
		variable x1=Offset_Time[Index[i]]
		variable y1=Baseline[Index[i]]
		variable ampl=Event_Size[Index[i]]
		wave /sdfr=sweepDF Locs,Index
		FindValue /V=(miniNum) Index
		variable mini_loc=Locs[V_Value]*1000
		variable fit0=FitWave[0]
		FitWave-=fit0
		AppendToGraph /c=(red,green,blue) FitWave
		String top_trace=TopTrace()
	endfor
End

// Analyzes a sweep for minis.  
Function MiniAnalysis(sweepNum,channel[,thresh,clean,tStart,tStop,proxy])
	Variable sweepNum
	String channel
	Variable thresh
	Variable clean // Remove line noise(s)
	Variable tStart,tStop // Start and stop times within the sweep to search
	variable proxy
	
	if(!paramisdefault(proxy))
		SetMinisProxyState(proxy)
	else
		proxy=GetMinisProxyState()
	endif
	thresh=ParamIsDefault(thresh) ? 5 : thresh
	wave /z Sweep=GetChannelSweep(channel,sweepNum,proxy=proxy)
	if(!WaveExists(Sweep))
		return -1
	endif
	string sweepName=getwavesdatafolder(sweep,2)
	tStart=ParamIsDefault(tStart) ? leftx(Sweep) : tStart
	tStop=(ParamIsDefault(tStop) || numtype(tStop)) ? rightx(Sweep) : tStop
	dfref df=GetMinisDF()
	dfref df=GetMinisSweepDF(channel,sweepNum,create=1)
#ifdef Acq  
	duplicate /free Sweep w
	string stim_regions=StimulusRegionList(channel,sweepNum,includeGaps=1)
	SuppressRegions(w,stim_regions,factor=10000,method="Squash")
	if(clean)
		NewNotchFilter(w,60,10)
		//RemoveWiggleNoise(SweepCopy)
	endif
	Wave Sweep=w
#endif
	// Flip time if the reverse proxy is being used.  
	variable start=(proxy==1) ? rightx(Sweep)-tStop : tStart
	variable stop=(proxy==1) ? rightx(Sweep)-tStart : tStop
	FindMinis(Sweep,df=df,thresh=thresh,within_median=10,tStart=start,tStop=stop,sweepName=sweepName)
	WaveStats /Q/M=1 Sweep
	wave /sdfr=df Locs,Vals
	nvar /sdfr=df net_duration
	Note /K Locs num2str(net_duration)
	variable count=numpnts(Locs)
	return count
End

// Finds minis in a sweep.  
Function /wave FindMinis(w0[,df,thresh,tStart,tStop,within_median,print_stats,sweepName])
	wave w0
	variable thresh,tStart,tStop
	variable within_median // Mini onset must occur at no less than 'within_median' + the median current of the sweep in order to be counted.  This excludes most events that occur during PSC groups.  
	variable print_stats
	dfref df
	string sweepName
	
	if(paramisdefault(df))
		df=GetDataFolderDFR()
	endif
	thresh=ParamIsDefault(thresh) ? 5 : thresh
	tStart=ParamIsDefault(tStart) ? leftx(w0) : tStart
	tStop=ParamIsDefault(tStop) ? rightx(w0) : tStop
	within_median=ParamIsDefault(within_median) ? Inf : within_median
	
	if(tStop-tStart<=0)
		return NULL
	endif
	duplicate /free/r=(tStart,tStop) w0 w,w_smooth
	variable /g df:net_duration=tStop-tStart
	nvar /sdfr=df net_duration
	variable kHz=0.001/dimdelta(w,0)
	// High-pass
		//smooth /m=0 100*kHz+1,w_smooth // 100 ms median smoothing (for removal of low frequency components).  
		resample /rate=10 w_smooth
		//smooth /b=1 100*kHz+1,w_smooth // 100 ms boxcar smoothing (for removal of low frequency components).  
		w-=w_smooth(x)
	// Low-pass
		resample /rate=1000 w
		//tac()
		//resample /rate=(kHz*1000) w
		//smooth /b=1 2*kHz+1,w // 2 ms box-car smoothing.  
	make /free/n=(dimsize(w,0)) Peak=0
	SetScale/P x 0,dimdelta(w,0), Peak
	Make /o/n=0 df:Locs,df:Vals,df:Index
	wave /sdfr=df Locs,Vals,Index
	variable i,rise_time=0.0015 // seconds
	variable refract=0.01 // 10 ms minimum interval between minis. 
	duplicate /free w,Jumps
	Jumps-=w(x-rise_time)
	FindLevels /Q/M=(refract)/EDGE=(thresh > 0 ? 1 : 2) Jumps,thresh; Wave W_FindLevels
	for(i=0;i<numpnts(W_FindLevels);i+=1)
		variable loc=W_FindLevels[i]	
		if(w(loc-rise_time)<-within_median)
			continue // Ignore events that start at a value < 'within_median' from the median current.  
		endif
	      WaveStats /Q/M=1/R=(loc-rise_time,loc+rise_time*3) w
		variable magnitude=(thresh>0) ? (V_max-V_min) : (V_min-V_max)
		Peak[x2pnt(theWave,loc)]=magnitude
		InsertPoints 0,1,Locs,Vals,Index
		Locs[0]=(thresh>0 ? V_maxloc : V_minloc)
		Vals[0]=magnitude
	endfor
	Index=x
	
	WaveTransform /O flip, Locs
	WaveTransform /O flip, Vals
	KillWaves /Z W_FindLevels
	if(print_stats)
		printf "%d minis in %.2f seconds = %.2f Hz.",numpnts(Locs),net_duration,numpnts(Locs)/net_duration
		printf "Median amplitude = %.2f pA.\r",StatsMedian(Vals)
	endif
	return Locs
End

// Assumes Minis have already been identified and locations and amplitudes are stored in root:Minis.  
Function ShowMinis([channels])
	string channels
	
	if(!WinType("ShowMinisWin"))
		variable init=1 // If the Mini Browser window doesn't exist, we will initialize all the statistics.  Otherwise, we will just update them with changes made in the Mini Count Reviewer window.  
	endif
	variable i,numChannels=GetNumChannels()
	
	 // Set as the default channels those that are checked in the Sweeps window.  
	if(ParamIsDefault(channels))
		channels=""
		if(wintype("SweepsWin"))
			for(i=0;i<numChannels;i+=1)
				string channel=Chan2Label(i)
				ControlInfo /W=Sweeps $channel
				if(V_Value)
					channels+=channel+";"
				endif
			endfor
			if(strlen(channels)==0)
				DoAlert 0,"No channels selected in the window 'Sweeps'"
				return -1
			endif
		endif
		if(!strlen(channels))
			channels=UsedChannels()
		endif
	endif
	if(!strlen(channels))
		DoAlert 0,"No channels available for use."
		return -2
	endif
	if(!DataFolderExists(minisFolder))
		printf "Must calculate Minis first using Recalculate() or CompleteMiniAnalysis().\r"
		return -3
	endif	
		
	// The main loop
	for(i=0;i<itemsinlist(channels);i+=1)
		channel=stringfromlist(i,channels)//Chan2Label(i)
		dfref df=GetMinisChannelDF(channel)
		wave /z/T/sdfr=df MiniNames
		if(!waveexists(MiniNames))
			init=1
			InitMiniStats(channel) // Initialize all mini statistics.  
			wave /T/sdfr=df MiniNames	
		endif
	endfor

	// Display the minis that were found.  
	if(init)
		Display /K=1 /N=ShowMinisWin /W=(150,150,850,400) as "Mini Browser"
		TextBox /MT/N=info/X=0/Y=0/F=0 "" 
		SetWindow ShowMinisWin hook(select)=ShowMinisHook
		dfref df=GetMinisDF()
		Variable /G df:currMini=0
		Variable /G df:fit_before=miniFitBefore
		Variable /G df:fit_after=miniFitAfter
	else
		DoWindow /F ShowMinisWin
	endif
	SwitchMiniView("Browse")
End

function InitMiniCounts(channel)
	string channel 
	
	dfref df=GetMinisChannelDF(channel,create=1)
	svar /z/sdfr=GetMinisDF() sweeps
	string sweeps_=ListExpand(sweeps)
	variable numSweeps=itemsinlist(sweeps_)
	make /o/t/n=(numSweeps,3) df:MiniCounts /wave=MiniCounts
	MiniCounts[][0]=stringfromlist(p,sweeps)
	MiniCounts[][1]="0"
	MiniCounts[][2]="Use"
	make /o/n=(numSweeps,3) df:MC_SelWave=(q==2) ? 48 : 0 
end

function InitMiniStats(channel)
	string channel

	dfref df=GetMinisChannelDF(channel)
	wave /z/t/sdfr=df MiniCounts
	if(!waveexists(MiniCounts))
		printf "No such wave %sMiniCounts.\r",getdatafolder(1,df)
	endif
	ControlInfo /W=MiniAnalysisWin IgnoreStimulusSweeps
	variable ignore_stimulus_sweeps=v_flag>0 ? v_value : 0
	wave /sdfr=df MC_SelWave // The wave indicating the status of the entries in MiniCountReviewer.  
	variable i,j,numMinis=0,numSweeps=dimsize(MiniCounts,0)
	for(i=0;i<dimsize(MiniCounts,0);i+=1)
		numMinis+=str2num(MiniCounts[i][1])
	endfor
	make /o/n=(numMinis) df:Use /wave=Use, df:Index /wave=Index=p
	make /o/t/n=(numMinis) df:MiniNames /wave=MiniNames
	string stats=miniFitCoefs+miniRankStats+miniOtherStats
	for(i=0;i<ItemsInList(stats);i+=1)
		string name=stringfromlist(i,stats)
		make /o/n=(numMinis) df:$cleanupname(name,0) /wave=stat=nan
	endfor
	numMinis=0
	for(i=0;i<dimsize(MiniCounts,0);i+=1)
		variable hasStim=0
		variable sweepNum=str2num(MiniCounts[i][0])
#if exists("HasStimulus")==6
		
		hasStim=HasStimulus(sweepNum)
#endif
		variable start=numMinis
		numMinis+=str2num(MiniCounts[i][1])
		variable finish=numMinis-1
		if(finish>=start)
			if(!(MC_SelWave[i][2] & 16) || (ignore_stimulus_sweeps && hasStim)) // If the box for that stimulus is unchecked or that sweep has a stimulus and is to be ignored.  
				variable include=0
			else
				include=1
			endif
			Use[start,finish]=include // Remove that sweep from the sweep list.  
			MiniNames[start,finish]=GetMiniName(sweepNum,p-start)
		endif
	endfor
	string /g df:direction="Down"
end

function /s GetMiniName(sweep,sweepMini)
	variable sweep,sweepMini
	
	string name
	sprintf name,"Sweep%d_Mini%d",sweep,sweepMini
	return name
end

Function ShowMinisHook(info)
	struct WMWinHookStruct &info
	
	dfref df=GetMinisDF()
	nvar /sdfr=df currMini
	switch(info.eventCode)
		case 3: // Mouse down.  
			string str
			structput /s info.mouseLoc str
			SetWindow ShowMinisWin userData(mouseDown)=str
			if(!(info.eventMod & 1)) // If not the left mouse button.  
				return 0
			endif 
			string mode=getuserdata("","","mode")
			if(!stringmatch(mode,"All"))
				return 0
			endif
			variable h=info.mouseLoc.h
			variable v=info.mouseLoc.v
			string trace=stringbykey("TRACE",TraceFromPixel(h,v,"WINDOW:ShowMinisWin"))
			controlinfo Channel; string channel=s_value
			variable red,green,blue
			GetChannelColor(channel,red,green,blue)
		
			if(strlen(trace))
				modifygraph rgb=((65535+red)/2,(65535+green)/2,(65535+blue)/2)
				modifygraph rgb($trace)=(red,green,blue),lsize($trace)=3
				ReorderTraces $TopTrace(), {$trace} 
				dfref chanDF=GetMinisChannelDF(channel)
				wave /t/sdfr=chanDF miniNames
				findvalue /text=trace /txop=4 MiniNames
				currMini=v_value
				setwindow ShowMinisWin userData(selected)=trace
			else
				modifygraph rgb=(red,green,blue),lsize=0.5
				setwindow ShowMinisWin userData(selected)=""
				currMini=nan
			endif
			break
		case 11: // Key down.  
			switch(info.keyCode)
				case 8: // Delete.  
					RejectMini()
				case 28: // Left arrow.  
					GotoMini(currMini-1)
					break
				case 29: // Right arrow.  
					GotoMini(currMini+1)
					break	
			endswitch
			break
		case 22: // Mouse wheel:
			controlinfo Channel; channel=s_value
			variable mini=currMini+info.wheelDy
			if(mini>=0 && mini<NumMinis(channel))
				GoToMini(mini)
			endif
			break
	endswitch
End

Function NumMinis(channel)
	string channel
	
	dfref df=GetMinisChannelDF(channel)
	wave /sdfr=df Index
	return numpnts(Index)
End

Function SwitchMiniView(mode)
	String mode
	
	Variable all=StringMatch(mode,"All")
	Variable browse=StringMatch(mode,"Browse")
	if(!all && !browse)
		return -1
	endif
	SetWindow ShowMinisWin userData(mode)=mode
	dfref df=GetMinisDF()
	nvar /sdfr=df currMini
	svar /sdfr=df sweeps,channel=currChannel
	variable i,j,sweepNum,miniNum
	
	// Remove old traces.  
	string traces=TraceNameList("",";",1)
	traces=SortList(traces,";",16)
	
	do
		string trace=StringFromList(i,traces)
		if(!strlen(trace))
			RemoveFromGraph /Z $trace	
		endif
		i-=1
	while(i>0)
	
	dfref chanDF=GetMinisChannelDF(channel)
	if(!datafolderrefstatus(chanDF))
		return -1
	endif
	string mini_name
	wave /t/sdfr=chanDF MiniNames
	wave /sdfr=chanDF Index
	sscanf MiniNames[Index[currMini]],"sweep%d_mini%d",sweepNum,miniNum
	string /G chanDF:direction="Down"
	svar /sdfr=chanDF direction
	wave /t Labels=GetChanLabels()
	variable xx=3,yy=9
	PopupMenu Channel pos={xx,yy}, mode=1+WhichListItem(channel,UsedChannels()), size={75,20}, proc=ShowMinisPopupMenus,value=#"UsedChannels()"
	xx+=67
	GroupBox FitBox pos={xx,yy-6}, size={343,31}
	Button FitOneMini disable=!browse, pos={xx+6,yy-1}, size={30,20}, proc=ShowMinisButtons, title="Fit"
	xx+=41
	nvar /sdfr=df fit_before,fit_after
	SetVariable Left disable=!browse, pos={xx,yy+1}, size={50,20}, value=fit_before, title="L:"
	xx+=53
	SetVariable Right disable=!browse, pos={xx,yy+1}, size={50,20}, value=fit_after, title="R:"
	xx+=58
	Button FitLesser disable=!browse, pos={xx,yy-1}, size={30,20}, proc=ShowMinisButtons, title="<="
	Button FitGreater disable=!browse, size={30,20}, proc=ShowMinisButtons, title=">="
	Button FitAll disable=!browse, size={40,20}, proc=ShowMinisButtons, title="Fit All" // Apply curve fits to all minis.  
	Button Template disable=!browse, proc=ShowMinisButtons, title="Template", help={"Use the current curve fit as a template for Bekkers-Clements scoring."} 
	
	xx+=200
	GroupBox RankBox pos={xx,yy-6}, size={210,31}
	xx+=6
	ValDisplay RankValue, disable=!browse, pos={xx,yy+1}, value=_NUM:0
	xx+=55
	Button RankMinis disable=!browse, pos={xx,yy-1}, size={52,20}, proc=ShowMinisButtons, title="Rank by: "
	controlinfo RankChoices
	variable popMode=v_flag>0 ? v_value : 1
	xx+=60
	PopupMenu RankChoices disable=!browse, pos={xx,yy-1}, fsize=8, mode=popMode,value=miniRankStats+miniFitCoefs,proc=ShowMinisPopupMenus
	Variable num_minis=NumMinis(channel)
	xx+=100
	controlinfo sweepNum
	if(GetMinisProxyState())//channel,sweepNum))
		//Button StoreTimeReversed disable=!browse, pos={xx,yy-1}, size={100,20}, proc=ShowMinisButtons,title="Reversed"	
	else
		Button UseTimeReversed disable=!browse, pos={xx,yy-1},size={100,20},proc=ShowMinisButtons,title="Reject Reversed"
		nvar /z/sdfr=chanDF timeRevThresh
		if(!nvar_exists(timeRevThresh))
			variable /g chanDF:timeRevThresh
			nvar /z/sdfr=chanDF timeRevThresh
		endif
		xx+=110
		SetVariable UseTimeRevThresh disable=!browse, pos={xx,yy+1},size={100,20},value=_NUM:0.01,limits={0,1,0.01},title="Threshold"
	endif

	xx=3; yy+=27
	GroupBox SummaryBox, pos={xx,yy}, size={303,30}
	xx+=5; yy+=5
	Button Store disable=2*(!SQL_ || !browse),pos={xx,yy},proc=ShowMinisButtons, title="Review"
	Button UpdateAnalysis disable=!browse,proc=ShowMinisButtons, title="Update"
	Button SwitchView disable=0, proc=ShowMinisButtons, title=SelectString(StringMatch(mode,"All"),"All","Browse")
	//Checkbox Scale disable=!all, proc=ShowMinisCheckboxes, title="Scale" // Scaling looks shitty.  Not advisable.  
	Button Summary disable=!browse, proc=ShowMinisButtons,title="Summary"
	controlinfo Summary
	Button Average pos={v_left,v_top},disable=browse, proc=ShowMinisButtons,title="Average"
	Button Options, proc=ShowMinisButtons, title="Options"
	
	xx+=310
	GroupBox BrowseBox, pos={xx,yy-5}, size={273,30}
	xx+=7
	Button FirstMini disable=!browse,pos={xx,yy}, size={20,20},proc=ShowMinisButtons,title="<<"//,pos={375,27}
	xx+=27
	SetVariable CurrMini disable=!browse,pos={xx,yy+2}, size={80,20}, limits={0,num_minis-1,1}, proc=ShowMinisSetVariables, variable=currMini,title="Mini #"//,pos={405,30}
	xx+=84
	Button LastMini disable=!browse,pos={xx,yy},size={20,20},proc=ShowMinisButtons,title=">>"//,pos={495,27}
	xx+=35
	SetVariable SweepNum, pos={xx,yy+2}, size={80,20}, proc=ShowMinisSetVariables, title="Sweep"
	xx+=70
	SetVariable SweepMiniNum, pos={xx,yy+2}, size={40,20}, proc=ShowMinisSetVariables, title=""
	
	xx+=55
	GroupBox RejectBox pos={xx,yy-5}, size={122,31}
	xx+=6
	Button Reject disable=0, pos={xx,yy}, proc=ShowMinisButtons, title="Reject:"
	Button RejectBelow disable=!browse, size={20,20}, proc=ShowMinisButtons, title="<="
	Button RejectAbove disable=!browse, size={20,20}, proc=ShowMinisButtons, title=">="
	Button Locate disable=!browse, size={50,20}, pos+={25,0}, proc=ShowMinisButtons, title="Locate"
	
	ControlBar /T 69
	strswitch(mode)
		case "All":
			Variable count=dimsize(MiniNames,0)
			if(count>500)
				DoAlert 1,"There are more than 500 minis to plot.  Are you sure you want to do this?"
				if(V_flag==2)
					SwitchMiniView("Browse")
					return -1
				endif
			endif
			all=1
			RemoveTraces()
			variable traceIndex=ItemsInList(TraceNameList("ShowMinisWin",";",1))
			
			dfref df=GetMinisOptionsDF(create=1)
			variable scale=numvarordefault(joinpath({getdatafolder(1,df),"scale"}),0)
			for(i=0;i<num_minis;i+=1)
				AppendMini(MiniNames[Index[i]],channel,noFit=1,traceIndex=traceIndex,zero=1,scale=scale)
				traceIndex+=1
			endfor
			SetVariable SweepNum, disable=1
			SetVariable SweepMiniNum, disable=1
			break
		case "Browse":
			browse=1
			if(numtype(currMini))
				currMini=0
			endif
			//RankMinis("RankByQuality") // Rank the minis by quality first. 
			GoToMini(currMini) // Start with mini 0.
			//Wave /T Mini_Names=$("root:Minis:"+channel+":Mini_Names") 
			//mini_name=Mini_Names[currMini]
			
			string miniName=MiniNames[Index[currMini]]
			
			SetVariable SweepNum, disable=0
			SetVariable SweepMiniNum, disable=0
			break
	endswitch
	String text=SelectString(numpnts(MiniNames),"No minis on channel "+channel,"")
	TextBox /W=ShowMinisWin/C/N=info text

	Button SwitchView userData=mode
	Label /Z/W=ShowMinisWin left, "pA"
End

Function ShowMinisButtons(ctrlName)
	String ctrlName
	
	dfref df=GetMinisDF()
	nvar /z/sdfr=df currMini
	strswitch(ctrlName)
		case "FitOneMini":
			FitMinis(first=currMini,last=currMini)
			break
		case "FitLesser":
			FitMinis(last=currMini)
			break
		case "FitGreater":
			FitMinis(first=currMini)
			break
		case "FitAll":
			//currMini=0
			FitMinis()
			break
		case "UpdateAnalysis":
			UpdateMiniAnalysis()
			break
		case "Locate":
			ShowMinisOnSweep()
			break
		case "Template":
			PickTemplate()
			break
		case "RankMinis":
			ControlInfo RankChoices
			RankMinis(S_Value)
			break
		case "Average":
			AverageMinis()
			break
		case "Reject":
			RejectMini()
			break
		case "RejectBelow":
			RejectMinis("Below")
			break
		case "RejectAbove":
			RejectMinis("Above")
			break
		case "Summary":
			MiniSummary()
			break
		case "Store":
			SQLStoreMinis()
			break
//		case "StoreTimeReversed":
//			svar /sdfr=df channel=currChannel
//			dfref chanDF=GetMinisChannelDF(channel)
//			string reversedName=removeending(getdatafolder(1,chanDF),":")+"_reversed"
//			dfref reversedChanDF=$reversedName
//			if(datafolderrefstatus(reversedChanDF))
//				killdatafolder /z reversedChanDF
//			endif
//			duplicatedatafolder chanDF $reversedName 
//			break
		case "FirstMini":
			GoToMini(0)
			break
		case "LastMini":
			svar /sdfr=df channel=currChannel
			dfref chanDF=GetMinisChannelDF(channel)
			GoToMini(NumMinis(channel)-1)
			break
		case "SwitchView":
			String currView=GetUserData("","SwitchView","")
			String mode=SelectString(StringMatch(currView,"Browse"),"Browse","All")
			SwitchMiniView(mode)
			break
		case "Options":
			DoWindow /K MiniOptions
			NewPanel /K=1 /N=MiniOptions /W=(100,100,150,180)
			AutoPositionWindow /M=1/R=ShowMinisWin
			dfref df=GetMinisDF()
			NewDataFolder /O df:Options
			dfref optionsDF=df:Options
			string options="Scale;Offset Fits;Zero"
			variable i
			for(i=0;i<ItemsInList(options);i+=1)
				String option=StringFromList(i,options)
				String option_=CleanupName(option,0)
				Variable /G optionsDF:$option_
				Checkbox $option_, pos={5,i*25+2}, variable=optionsDF:$option_, title=option, proc=ShowMinisCheckboxes
			endfor
	endswitch
End

Function ShowMinisCheckboxes(ctrlName,val)
	String ctrlName
	Variable val
	
	strswitch(ctrlName)
		case "Scale":
			DoWindow /F ShowMinisWin
			SwitchMiniView("All")
			break
		case "Offset_Fits":
			DoWindow /F ShowMinisWin
			SwitchMiniView("Browse")
			break
		case "Zero":
			DoWindow /F ShowMinisWin
			SwitchMiniView("Browse")
			break
	endswitch
End

Function ShowMinisSetVariables(info)
	Struct WMSetVariableAction &info
	
	if(!SVInput(info.eventCode))
		return 0
	endif
	dfref df=GetMinisDF()
	nvar /sdfr=df currMini
	svar /sdfr=df channel=currChannel
	dfref chanDF=GetMinisChannelDF(channel)
	wave /t/sdfr=chanDF MiniNames
	wave /sdfr=chanDF Use
	strswitch(info.ctrlName)
		case "CurrMini":
			GoToMini(currMini)
			break
		case "SweepNum":
		case "SweepMiniNum":
			ControlInfo SweepNum; variable sweepNum=V_Value
			ControlInfo SweepMiniNum; Variable sweepMiniNum=V_Value
			variable lastSweepNum=str2num(GetUserData("","SweepNum",""))
			variable lastSweepMiniNum=str2num(GetUserData("","SweepMiniNum",""))
			strswitch(info.ctrlName)
				case "SweepNum":
					variable direction=sign(sweepNum-lastSweepNum)
					break
				case "SweepMiniNum":
					direction=sign(sweepMiniNum-lastSweepMiniNum)
					break
			endswitch
			svar /sdfr=df sweeps
			if(sweepNum<MinList(sweeps) || sweepNum>MaxList(sweeps))
				SetVariable SweepNum value=_NUM:lastSweepNum
			endif
			FindValue /TEXT="Sweep"+num2str(sweepNum)+"_Mini"+num2str(sweepMiniNum) /TXOP=4 MiniNames
			variable num_minis=NumMinis(channel)
			do	
				if(!Use[V_Value] && currMini>=0 && currMini<num_minis)
					v_value+=direction
				else
					break
				endif
			while(1)
			currMini=limit(currMini,0,num_minis-1)
			GoToMini(currMini)
			break
	endswitch
End

Function ShowMinisPopupMenus(info)
	Struct WMPopupAction &info
	
	if(!SVInput(info.eventCode))
		return 0
	endif
	dfref df=GetMinisDF()
	nvar /sdfr=df currMini
	svar /sdfr=df channel=currChannel
	dfref chanDF=GetMinisChannelDF(channel)
	strswitch(info.ctrlName)
		case "Channel":
			channel=info.popStr
			string mode=GetUserData("ShowMinisWin","","mode")
			SwitchMiniView(mode)
			break
		case "RankChoices":
			RankMinis(info.popStr)
			break
		case "Direction":
			string /g chanDF:direction=info.popStr
			break
	endswitch
End

Function PickTemplate()
	String traces=TraceNameList("", ";", 3)
	traces=ListMatch(traces,"Fit*")
	if(ItemsInList(traces))
		String trace=StringFromList(0,traces)
		wave /z Template=TraceNameToWaveRef("",trace)
		ControlInfo /W=ShowMinisWin Channel
		String channel=S_Value
		if(waveexists(Template))
			dfref df=GetMinisChannelDF(channel)
			Duplicate /o Template df:BC_Template
		endif
	endif
End

function ShowMinisOnSweep()
	if(!WinType("SweepsWin"))
		return -1
	endif
	dfref df=GetMinisDF()
	nvar /sdfr=df currMini
	svar /sdfr=df channel=currChannel
	dfref chanDF=GetMinisChannelDF(channel)
	wave /t/sdfr=chanDF MiniNames
	wave /sdfr=chanDF index
	string mini_name = MiniNames[index[currMini]]
	variable thisSweepNum,thisMiniNum
	sscanf mini_name,"Sweep%d_Mini%d",thisSweepNum,thisMiniNum
	extract /free index, sweepIndex, stringmatch(MiniNames[index[p]],"Sweep"+num2str(thisSweepNum)+"_*") // Minis in the current sweep.  
	dfref sweepDF = GetMinisSweepDF(channel,thisSweepNum)
	wave /sdfr=sweepDF Locs,Vals
	make /o/n=(numpnts(Locs)) chanDF:sweepMinisMask /wave=mask=0, chanDF:sweepMinisMarkers /wave=markers=10 // Marker 10 is a vertical line.  
	variable i
	for(i=0;i<numpnts(sweepIndex);i+=1)
		mini_name = MiniNames[sweepIndex[i]]
		variable sweepNum,miniNum
		sscanf mini_name,"Sweep%d_Mini%d",sweepNum,miniNum
		mask[miniNum] = 1
		if(miniNum == thisMiniNum)
			markers[miniNum] = 23 // Marker 23 is an upside-down filled triangle.  
		endif
	endfor
	string left_axes=AxisList2("left",win="SweepsWin")
	string left_axis = stringfromlist(0,left_axes)
	MoveCursor("A",thisSweepNum)
	removefromgraph /z/w=SweepsWin vals
	appendtograph /w=SweepsWin /l=$(left_axis) /b=time_axis /c=(0,0,0) vals vs locs
	modifygraph /w=SweepsWin mode(vals)=3, lsize(vals)=3
	modifygraph /w=SweepsWin mask(vals)={mask,0,0}
	modifygraph /w=SweepsWin zmrknum(vals)={markers}
end

// Updates the values for mini amplitude and frequency in the Amplitude Analysis window to reflect Minis that have been removed in the Mini Browser.  
Function UpdateMiniAnalysis()
	ControlInfo /W=ShowMinisWin Channel
	String channel=S_Value
	if(!WinType("AnalysisWin"))
		DisplayMiniRateAndAmpl(channel) // A simpler version of the same thing.  
		return -1
	endif
	String methodStr="Minis"
	//Variable num=1+WhichListItem(method_str,analysis_methods)
	//PopupMenu Method mode=nu32m, win=Ampl_Analysis
	//AnalysisMethodProc("Method",num,method_str)
	
	Variable i,j,k
	String miniMethods=MethodList(methodStr) // Methods that are based on the Minis code.  
	if(!strlen(miniMethods))
		miniMethods = "Minis"
	endif
	dfref df=GetMinisDF()
	svar /sdfr=df sweeps	
	nvar /sdfr=df threshold
	dfref df=GetMinisChannelDF(channel)
	wave /t/sdfr=df MiniCounts
	wave /sdfr=df Use
	make /free/n=(dimsize(MiniCounts,0)) MiniSweepIndeks=str2num(MiniCounts[p][0])
	for(j=0;j<ItemsInList(sweeps);j+=1)
		string sweep=StringFromList(j,sweeps)
		variable sweepNum=str2num(sweep)
		wave /z/sdfr=GetMinisSweepDF(channel,sweepNum) Locs,Vals
		wave /z/sdfr=df Index,Event_Size
		if(waveexists(Locs))
			variable net_duration=str2num(note(Locs))
			for(i=0;i<numpnts(Vals);i+=1)
				string mini_name=GetMiniName(sweepNum,i)
				wave /t/sdfr=df MiniNames
				FindValue /TEXT=mini_name /TXOP=4 MiniNames
				if(V_Value>=0 && Use[v_value])
					if(threshold>0)
						Vals[i]=Event_Size[V_Value]
					else
						Vals[i]=-Event_Size[V_Value]
					endif
				else
					Vals[i]=nan
				endif
			endfor
			for(k=0;k<ItemsInList(miniMethods);k+=1)
				string miniMethod=StringFromList(k,miniMethods)
				MiniLocsAndValsToAnalysis(sweepNum,channel,Locs,Vals,duration=net_duration,miniMethod=miniMethod) // Creates its own MiniSweepIndex and kills it.  
			endfor
		endif
	endfor
End

Function MiniSummary([channel])
	string channel
	
	channel = selectstring(!paramisdefault(channel),GetMinisChannel(),channel)
	dfref df=GetMinisChannelDF(channel)
	wave /sdfr=df index
	variable numMinis = numpnts(index)
	make /o/n=(numMinis) Summary=nan
	MoreMiniStats(channel)
	variable i
	string stats=miniRankStats+miniOtherStats
	for(i=0;i<itemsinlist(stats);i+=1)
		string name=stringfromlist(i,stats)
		wave /z w=df:$cleanupname(name,0)
		if(waveexists(w))
			redimension /n=(-1,dimsize(Summary,1)+1) Summary
			Summary[][i] = w[index[p]]
			SetDimLabel 1,dimsize(Summary,1)-1,$name,Summary 
			//appendtotable w
		endif
	endfor
	DoWindow /K MiniSummaryWin
	Edit /K=1 /N=MiniSummaryWin Summary.ld as "Mini Summary for channel "+channel
End

// Builds event times and inter-event intervals.  
Function MoreMiniStats(channel[,proxy])
	string channel
	variable proxy
	
	proxy = paramisdefault(proxy) ? GetMinisProxyState() : proxy	
	dfref df=GetMinisChannelDF(channel,proxy=proxy)
	wave /t/sdfr=df MiniNames
	wave /sdfr=df Use,Index
	make /free/n=(numpnts(df:Event_Size)) TempIndex
	wave /z sweepT=GetSweepT()
	wave /sdfr=df baseline,event_size,amplitude,Event_Time,Interval,Rise_10_90=$cleanupname("Rise 10%-90%",0)
	Event_Time=nan; Rise_10_90=nan
	variable i,mini_num
	
	// Compute absolute event times, and 10%-90% rise times.  
	for(i=0;i<numpnts(MiniNames);i+=1)
		String name=MiniNames[i]
		if(!Use[i])
			continue
		endif
		variable sweepNum,miniNum
		sscanf name,"Sweep%d_Mini%d",sweepNum,miniNum
		dfref sweepDF=GetMinisSweepDF(channel,sweepNum,proxy=proxy)
		
		// Event Time.  
		Wave /sdfr=sweepDF Locs,Vals,Index
		FindValue /V=(miniNum) Index
		Variable j=V_Value
		if(WaveExists(sweepT))
			Variable time_=sweepT[sweepNum]*60+Locs[j] // Time since experiments start.  
			Event_Time[i]=time_
		endif
		
		// Rise 10%-90%.  
		wave /z/sdfr=sweepDF Fit=$("Fit_"+num2str(miniNum))
		variable tenThresh=Baseline[i]+0.1*(Event_Size[i]*sign(Amplitude[i])
		variable ninetyThresh=Baseline[i]+0.9*(Event_Size[i]*sign(Amplitude[i])
		if(WaveExists(Fit))
			FindLevel /Q Fit,tenThresh // Search from 5 ms before the peak until the peak. 
			Variable ten=V_LevelX
			FindLevel /Q/R=(ten,) Fit,ninetyThresh
			Variable ninety=V_LevelX
		else
			wave sweep=GetChannelSweep(channel,sweepNum,proxy=proxy)
			FindLevel /B=3/Q/R=(Locs[j]-0.005,Locs[j]+0.001) Sweep,tenThresh // Search from 5 ms before the peak until the peak. 
			ten=V_LevelX
			FindLevel /B=3/Q/R=(ten,Locs[j]+0.001) Sweep,ninetyThresh
			ninety=V_LevelX
		endif
		Rise_10_90[i]=(ninety-ten)*1000 // Report in ms. 
		//Rise_10_90[i]=numtype(Rise_10_90[i]) ? Inf : Rise_10_90[i]
	endfor
	
	// Compute intervals.  
if(0)
	TempIndex=x
	Sort Event_Time,Event_Time,TempIndex
	Interval=Event_Time[p]-Event_Time[p-1]
	Sort TempIndex,Event_Time,Interval
	for(i=0;i<numpnts(MiniNames);i+=1)
		name=MiniNames[i]
		sscanf name,"Sweep%d_Mini%d",sweepNum,miniNum
		Wave Index=root:Minis:$(channel):$("Sweep"+num2str(sweepNum)):Index
		FindValue /V=(miniNum) Index
		j=V_Value
		if(j==0) // First mini of the sweep.  
			Wave Sweep=root:$(channel):$("Sweep"+num2str(sweepNum))
			variable lastSweepDuration=rightx(Sweep)
			variable unrecordedDuration=60*(sweepT[sweepNum]-sweepT[sweepNum-1])-lastSweepDuration
			Interval[i]+=unrecordedDuration
		endif
	endfor	
	
	KillWaves /Z TempIndex
	//SetDataFolder $curr_folder
else
	duplicate /o Event_Time,Interval
	//make /free/n=(numpnts(Interval)) TempInterval,TempIndex=p
	extract /free/indx Interval,TempIndex,Use[p]==1
	extract /free Interval,TempInterval,Use[p]==1
	differentiate /meth=2 TempInterval
	TempInterval[0]=nan
	Interval=nan
	for(i=0;i<numpnts(TempIndex);i+=1)
		Interval[TempIndex[i]]=TempInterval[i]
	endfor
endif
End

function /s GetMinisChannel()
	dfref df=GetMinisDF()
	svar /sdfr=df currChannel
	return currChannel
end

function SetMinisChannel(channel)
	string channel
	
	dfref df=GetMinisDF()
	string /g df:currChannel=channel
end

function GetCurrMini()
	dfref df=GetMinisDF()
	nvar /z/sdfr=df currMini
	if(nvar_exists(currMini))
		return currMini
	else
		variable /g df:currMini=0
		return 0
	endif
end

Function FitMinis([channel,first,last,proxy])
	string channel
	variable first,last // First and last mini to fit, by index.  
	variable proxy
	
	DoWindow /F ShowMinisWin
	variable i,error,num_errors=0
	string mode=""
	if(stringmatch(TopGraph(),"ShowMinisWin"))
		mode=GetUserData("ShowMinisWin","SwitchView","")
	endif
	String trace,traces
	if(paramisdefault(channel))
		channel=GetMinisChannel()
	endif
	if(!paramisdefault(proxy))
		SetMinisProxyState(proxy)
	else
		proxy=GetMinisProxyState()
	endif
	dfref df=GetMinisChannelDF(channel)
	wave /t/sdfr=df MiniNames
	wave /sdfr=df Index
	first=paramisdefault(first) ? 0 : first
	last=paramisdefault(last) ? NumMinis(channel)-1 : last
	
	//strswitch(mode)
	//	case "All":
	//		traces=TraceNameList("ShowMinisWin",";",3)
	//		traces=RemoveFromList2("fit_*",traces) // Remove fits from the list of traces to fit.  
	//		//make /free/n=(itemsinlist(traces)) MinisToFit=stringfromlist(p,traces)
	//		break
	//	case "Browse":
			//duplicate /free/t/r= MiniNames MinisToFit
			
	//		break
	//endswitch
	
	variable red,green,blue; GetChannelColor(channel,red,green,blue)
	variable sweepNum,miniNum
	dfref df=GetMinisDF()
	variable /g df:paused=0
	variable minisToFit=last-first+1
	//nvar /sdfr=df currMini
	string formattedChannel=selectstring(proxy,channel,channel+" ("+stringfromlist(proxy,proxies)+")")
	for(i=first;i<=last;i+=1)
		//string miniName=MiniNames[i]
		//trace=StringFromList(i,traces)
		if(StringMatch(mode,"Browse"))
			GoToMini(i)
		endif
	
		error=FitMini(i,channel=channel)//trace)
		num_errors+=error
		string msg
		sprintf msg,"%s mini %s",formattedChannel,MiniNames[Index[i]]
		Prog("Fitting Minis...",i-first,minisToFit,msg=msg)
	endfor
	if(first==last)
		if(error)
			printf "Fit error for this trace.\r"
		endif
	else
		printf "%d errors out of %d traces.\r",num_errors,minisToFit//num_traces
	endif
End

Function FitMinisPause(buttonNum, buttonName)
	Variable buttonNum
	String buttonName
	dfref df=GetMinisDF()
	nvar /sdfr=df paused
	paused=!paused
	if(!paused)
		FitMinis()
	endif
End

// Try adding /G so that the guesses from W_Coef are actually used.  
Function FitMini(num[,channel])//trace)
	variable num
	string channel
	
	variable winIsTop=stringmatch(TopGraph(),"ShowMinisWin")
	if(paramisdefault(channel))
		if(winIsTop)
			ControlInfo /W=ShowMinisWin Channel
			channel=S_Value
		else
			channel=GetMinisChannel()
		endif
	endif
	if(winIsTop)
		GoToMini(num)
	endif
	variable sweepNum,miniNum
	dfref df=GetMinisDF()
	dfref chanDF=GetMinisChannelDF(channel)
	variable currMini=GetCurrMini()
	wave /t/sdfr=chanDF MiniNames
	wave /sdfr=chanDF Index
	variable index_=Index[num]
	string mini_name=MiniNames[Index[num]]//currMini]
	sscanf mini_name,"Sweep%d_Mini%d",sweepNum,miniNum
	dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
	variable proxy=GetMinisProxyState()//channel,sweepNum)
	variable V_FitMaxIters=500,error,i
	wave sweep=GetChannelSweep(channel,sweepNum,proxy=proxy)//TraceWave=TraceNameToWaveRef("",trace)
	variable delta=dimdelta(sweep,0)
	variable kHz=0.001/delta
	//KillWaves $FitLocation(trace,win="ShowMinisWin")
	wave /sdfr=sweepDF Locs,Vals
	wave SweepIndex=sweepDF:Index
	FindValue /V=(miniNum) SweepIndex
	variable peak_loc=Locs[V_Value]
	variable peak_val=Vals[V_Value]
	nvar /sdfr=df fit_before,fit_after
	variable offset_fits=NumVarOrDefault(joinpath({getdatafolder(1,df),"Options","offset_fits"}),0)
	variable peak_point=x2pnt(Sweep,peak_loc)
	variable first_point=peak_point-fit_before*kHz // This corresonds to, e.g., 5 ms before the peak.  
	variable last_point=peak_point+fit_after*kHz // This corresponds to, e.g., 10 ms after the peak.  
	variable bump=0
	if(fit_before<=0)
		bump=(fit_before/1000 - 0.005)
		peak_loc-=bump
	endif
	svar /sdfr=chanDF direction
	variable amplGuess=peak_val>0 ? 50 : -50
	string amplInequality=SelectString(peak_val>0,"<0",">0")
	make /o/t df:T_Constraints /wave=Constraints
	string fit_name="Fit_"+num2str(miniNum)
	if(winIsTop)
		removeFromGraph /Z $fit_name
	endif
	make /o/n=(last_point-first_point+1) sweepDF:$fit_name /wave=Fit=0
	setScale /I x,-fit_before/1000,fit_after/1000,Fit
	peak_loc+=bump
	DebuggerOptions
	variable debugOn=v_debugOnError
	DebuggerOptions debugOnError=0
	if(last_point>=numpnts(Sweep))
		variable V_FitError=7, V_FitQuitReason=4
	else  
		variable tries=0
		do
			v_fiterror=0; V_FitQuitReason=0
			switch(tries)
				case 0: // On the first try.  
					string fitType="Synapse3"
					variable v_fitoptions=4 // Minimize the squared error.  
					break
				case 1: // On the second try, if the first try fails.  
					v_fitoptions=6 // Minimize the absolute error.  
					break
				case 2: 
					fitType="Synapse"
					break
				case 3: // Now do the same 3 tries with the fit region moved in by 1 ms on each side.    
					fitType="Synapse3"
					v_fitoptions=4 // Minimize the squared error. 
					first_point = peak_point-max(1,min(fit_before-1,round(fit_before/2)))*kHz
					last_point = peak_point+max(1,min(fit_after-1,round(fit_after/2)))*kHz
					break
				case 4: 
					v_fitoptions=6 // Minimize the absolute error.  
					break
				case 5: 
					fitType="Synapse"
					break
				case 6: // Now do the same 3 tries with the fit region moved in by 2 ms on each side.  
					fitType="Synapse3"
					v_fitoptions=4 // Minimize the squared error. 
					first_point = peak_point-max(1,min(fit_before-2,round(fit_before/3)))*kHz
					last_point = peak_point+max(1,min(fit_after-2,round(fit_after/3)))*kHz
					break
				case 7: 
					v_fitoptions=6 // Minimize the absolute error.  
					break
				case 8: 
					fitType="Synapse"
					break
			endswitch
			//if(proxy)
			//	fitType+="_Reversed"
			//endif
			Make /o/D chanDF:W_coef /wave=Coefs
			strswitch(fitType)
				case "Synapse":
				//case "Synapse_Reversed":
					redimension /n=5 Coefs,Constraints
					Constraints={"K0<=0.003","K1<=0.05","K2<"+num2str(peak_loc),"K4"+amplInequality} // Fit constraints for fit function 'Synapse'.  
					Coefs={0.001,0.003,peak_loc-0.0025,Sweep[first_point],amplGuess} // Initial guesses for fitting coefficients for fit function 'Synapse'.  
					break
				case "Synapse3":
					redimension /n=6 Coefs,Constraints
					Constraints={"K0<=0.003","K1<=0.05","K2<"+num2str(peak_loc),"K4"+amplInequality,"K5>1"} // Fit constraints for fit function 'Synapse3.  
					Coefs={0.002,0.003,peak_loc-0.0015,Sweep[first_point],amplGuess,2}
					//Coefs= {0.0002,0.003,peak_loc,-29.126,-27.1913,2.06805}
					break
			endswitch
			FuncFit /H="00000"/N/Q $fitType kwcWave=Coefs Sweep[first_point,last_point] /C=Constraints /D=Fit[0,last_point-first_point]
			Variable err = GetRTError(0)
			if (err != 0)
				string errMessage=GetErrMessage(err)
				printf "Error in Curvefit: %s\r", errMessage
				err = GetRTError(1)						// Clear error state
			endif
			tries+=1
			wavestats /q/m=1 Fit
			if(v_fiterror == 0 && v_max == v_min) // If no error was reported but fit is still a flat line.  
				v_fiterror = -1 // Consider it an error so that a new fit is attempted.   
			endif
		while(v_fiterror && tries<9)
		if(winIsTop)
			AppendToGraph /c=(0,0,0) Fit
			ModifyGraph offset($fit_name)={,0+offset_fits*fitOffset}
		endif
	endif
	DebuggerOptions debugOnError=debugOn
	if(winIsTop)
		ModifyGraph /W=ShowMinisWin rgb($TopTrace())=(0,0,0)
	endif
	// Fitting error:
	duplicate /free Fit,Residual
	Residual=Sweep[first_point+p]-Fit[p]
	
	if(V_FitError!=0)
		printf "%s: Fit Error = %d; %d.\r",MiniNames[Index[num]],V_FitError,V_FitQuitReason
		error=1
	endif
	string stats=miniFitCoefs+miniRankStats+miniOtherStats
	if(index_<0)
		for(i=0;i<itemsinlist(stats);i+=1)
			string name=stringfromlist(i,stats)
			wave w=chanDF:$cleanupname(name,0)
			InsertPoints 0,1,w
			index_=0
		endfor
	endif
	for(i=0;i<ItemsInList(miniFitCoefs);i+=1)
		name=stringFromList(i,miniFitCoefs)
		wave w=chanDF:$cleanupname(name,0)
		w[index_]=error ? nan : Coefs[i]
		if(StringMatch(name,"*Time*"))
			w[index_]*=1000 // Convert from seconds to milliseconds.  
		endif
	endfor
	for(i=0;i<itemsinlist(stats);i+=1)
		name=stringfromlist(i,stats)
		wave w=chanDF:$cleanupname(name,0)
		wave /z/sdfr=chanDF Event_Size=$cleanupname("Event Size",0)
		strswitch(name)
			case "Chi-Squared":
				w[index_]=(v_fiterror || numtype(v_chisq)) ? Inf : V_chisq/numpnts(Fit)
				break
			case "Fit Time Before":
				w[index_]=fit_before
				break
			case "Fit Time After":
				w[index_]=fit_after
				break
			case "Score":
				// Bekkers-Clements scoring
				string BC_Template=joinpath({getdatafolder(1,chanDF),"BC_Template"})
				variable BC_score=NaN
				if(waveexists($BC_Template))
					duplicate /o/R=[peak_point-100,peak_point+150] Sweep BC_Match
					if(abs(1-(BC_Match[inf]/BC_Match[0]))<0.0001)
						BC_Match[0]*=1.0001 // This is necessary to keep MatchTemplate /C from crashing.  
					endif
					execute /Q/Z "MatchTemplate /C "+BC_Template+", BC_Match"
					wavestats /Q/M=1 BC_Match
					killwaves /Z BC_Match
					BC_score=V_max
				endif
				w[index_]=BC_score
				break
			case "Cumul Error":
				duplicate /free Residual,CumulResidual
				CumulResidual=Residual
				Integrate /P CumulResidual
				wavestats /q/m=1 CumulResidual
				w[index_]=abs(V_max-V_min)/sqrt(last_point-first_point+1)
				w[index_]=(numtype(w[index_])==2) ? Inf : w[index_]
				break
			case "Mean Error":
				duplicate /free Residual,absResidual
				absResidual=abs(Residual)
				w[index_]=mean(absResidual)
				//printf "Mean "+num2str(w[index_])
				break
			case "MSE":
				w[index_]=norm(Residual)^2
				//printf "Mean "+num2str(w[index_])
				break
			case "R2":
				variable ssTot=variance(Sweep,peak_loc-fit_before/1000,peak_loc+fit_after/1000)
				variable ssRed=variance(Residual)
				w[index_]=max(0,1-ssRed/ssTot)
				break
			case "Log(1-R2)":
				wave /sdfr=chanDF R2=$cleanupname("R2",0)
				w[index_]=log(1-R2[index_])
				break
			case "Event Size":
				wavestats /q/m=1 Fit
				if(v_max == v_min) // If the fit is a flat line.  
					w[index_] = abs(peak_val) // Then use the original estimate of the amplitude.  
				else // Otherwise use the estimate from the fit.  
					w[index_] = abs(V_max-V_min)
					//nvar /sdfr=GetMinisDF() threshold
					//if(threshold > 0)
					//	w[index_] = V_max-V_min
					//else
					//  w[index_] = V_min-V_max
					//endif
				endif
				break
			case "Plausability":
				wave /sdfr=chanDF Cumul_Error=$cleanupname("Cumul Error",0),Mean_Error=$cleanupname("Mean Error",0),MSE=$cleanupname("MSE",0)
				w[index_]=sqrt(Event_Size[index_])/MSE[index_]
				w[index_]=(numtype(w[index_])==2) ? -Inf : w[index_]
				break
		endswitch
	endfor
	//endif
	V_fitoptions=4
	return error
End

// Remove the current mini from the graph and delete it, so it doesn't get included in the final analysis.  
Function RejectMini()
	dfref df=GetMinisDF()
	nvar /z/sdfr=df currMini,traversal_direction
	if(numtype(currMini))
		return -1
	endif
	RemoveCurrMiniFromGraph()
	KillMini(currMini)
	svar /sdfr=df currChannel
	variable proxy=GetMinisProxyState()
	dfref df=GetMinisChannelDF(currChannel)
	variable num_minis=NumMinis(currChannel)
	if(NVar_exists(traversal_direction) && traversal_direction<0)
		currMini=limit(currMini-1,0,num_minis-1)
	else
		currMini=limit(currMini,0,num_minis-1)
	endif
	string mode=getuserdata("","","mode")
	if(stringmatch(mode,"browse"))	
		GoToMini(currMini)
	endif
End

// Remove the current mini from the graph
Function RemoveCurrMiniFromGraph()
	String ctrlName
	String traces=TraceNameList("",";",3)
	traces=RemoveFromList2("fit_*",traces)
	string mode=getuserdata("","","mode")
	dfref df=GetMinisDF()
	strswitch(mode)
		case "Browse":
			string trace=StringFromList(0,traces)
			break
		case "All":
			nvar /sdfr=df currMini
			controlinfo /w=ShowMinisWin Channel; string channel=s_value
			dfref chanDF=GetMinisChannelDF(channel)
			wave /t/sdfr=chanDF miniNames
			wave /sdfr=chanDF Index
			trace=miniNames[Index[currMini]]
			break
	endswitch
	RemoveFromGraph /Z $trace
	RemoveFromGraph /Z $("fit_"+trace)
End

// Same as RejectMini, but for all minis less than the current index (Mini #).  
Function RejectMinis(direction)
	String direction
	RemoveCurrMiniFromGraph()
	dfref df=GetMinisDF()
	nvar /sdfr=df currMini
	Variable i
	String trace,mini_name,fit_name
	String curr_folder=GetDataFolder(1)
	ControlInfo /W=ShowMinisWin Channel
	String channel=S_Value
	dfref df=GetMinisChannelDF(channel)
	wave /t/sdfr=df MiniNames
	strswitch(direction)
		case "Below": 
			for(i=currMini;i>=0;i-=1)
				GoToMini(i)
				KillMini(i)
			endfor
			currMini=0
			break
		case "Above":
			for(i=currMini;i<numpnts(MiniNames);i+=0)
				GoToMini(i)
				if(KillMini(i))
					break
				endif
			endfor
			currMini=limit(currMini,0,NumMinis(channel)-1)
			break
	endswitch
	
	GoToMini(currMini)
End

Function KillMini(miniNum[,channel,proxy,preserve_loc])
	variable miniNum,proxy
	string channel
	variable preserve_loc // Preserve a knowledge of its location (and amplitude) in the corresponding Sweep folder.  
	
	if(numtype(miniNum))
		return -1
	endif
	if(ParamIsDefault(channel))
		ControlInfo /W=ShowMinisWin Channel
		channel=S_Value
	endif
	proxy = paramisdefault(proxy) ? GetMinisProxyState() : proxy
	dfref df=GetMinisChannelDF(channel,proxy=proxy)
	if(!datafolderrefstatus(df))
		return -2
	endif
	wave /t/sdfr=df MiniNames
	wave /sdfr=df Use,Index
	if(miniNum<0 || miniNum>=numpnts(Index))
		printf "miniNum = %d out of range; KillMini().\r",miniNum
		return -3
	endif
	variable i
	string stats=miniFitCoefs+miniRankStats+miniOtherStats
//	for(i=0;i<itemsinlist(stats);i+=1)
//		string name=stringfromlist(i,stats)
//		wave /z w=df:$cleanupname(name,0)
//		if(waveexists(w))
//			DeletePoints miniNum,1,w
//		endif
//	endfor
//	deletepoints miniNum,1,MiniNames
	
	// Fix the mini locations and value for the sweep in which this mini occurred.  
	Variable sweepNum,sweepMiniNum // miniNum2 is the number of the mini for that sweep, as opposed to miniNum, which is the number of the mini overall.  
	print miniNum,Index[miniNum],miniNames[index[miniNum]]
	sscanf MiniNames[Index[miniNum]], "Sweep%d_Mini%d", sweepNum,sweepMiniNum
	dfref sweepDF=GetMinisSweepDF(channel,sweepNum,proxy=proxy)
//	wave /sdfr=sweepDF Locs,Vals,Index
//	FindValue /V=(miniNum2) Index
//	if(v_value==-1)
//		printf "Could not find the value %d in %s; KillMini().\r",miniNum2,getwavesdatafolder(Index,2)
//	elseif(!preserve_loc)
//		DeletePoints v_value,1,Locs,Vals,Index
//	endif
	string fit_name="Fit_"+num2str(sweepMiniNum)
	KillWaves /Z sweepDF:$fit_name
	
	Use[Index[miniNum]]=0
	deletepoints miniNum,1,Index
	
	// Cleanup.  
	Variable num_minis=numpnts(Index)
	if(wintype("ShowMinisWin"))
		SetVariable CurrMini limits={0,num_minis-1,1}, win=ShowMinisWin
	endif
End

Function /S GoToMini(miniNum)
	variable miniNum
	
	string traces=TraceNameList("ShowMinisWin",";",1)
	traces=SortList(traces,";",16)
	ControlInfo /W=ShowMinisWin Channel
	string channel=S_Value
	dfref chanDF=GetMinisChannelDF(channel)
	if(!DataFolderRefStatus(chanDF))
		return ""
	endif
	wave /t/sdfr=chanDF MiniNames
	wave /sdfr=chanDF Index
	String miniName=""
	variable num_minis=NumMinis(channel)
	miniNum=limit(miniNum,0,num_minis)
	SetVariable currMini limits={0,num_minis,1}, win=ShowMinisWin
	dfref optionsDF=GetMinisOptionsDF(create=1)
	variable zero=NumVarOrDefault(joinpath({getdatafolder(1,optionsDF),"zero"}),0)
	if(numpnts(Index)>0)
		variable sweepNum,sweepMiniNum
		miniName=MiniNames[Index[miniNum]]
		sscanf miniName,"Sweep%d_Mini%d",sweepNum,sweepMiniNum
		if(strlen(miniName))
			AppendMini(miniName,channel,zero=zero) // Appends the mini and the fit, if it exists.  
		endif
	endif
	dfref df=GetMinisDF()
	nvar /z/sdfr=df currMini,last_mini
	currMini=miniNum
	if(nvar_exists(last_mini))
		variable /g df:traversal_direction=currMini-last_mini
	endif
	variable /g df:last_mini=currMini
	svar /sdfr=df sweeps
	SetVariable SweepNum,value=_NUM:sweepNum, userData=num2str(sweepNum), limits={MinList(sweeps),MaxList(sweeps),1}, win=ShowMinisWin
	wave /sdfr=GetMinisSweepDF(channel,sweepNum) Locs
	SetVariable SweepMiniNum,value=_NUM:sweepMiniNum, userData=num2str(sweepMiniNum), limits={0,numpnts(Locs)-1,1}, win=ShowMinisWin
	controlinfo /w=ShowMinisWin RankChoices
	if(v_flag>0)
		wave /z/sdfr=chanDF w=$cleanupname(s_value,0)
		if(waveexists(w))
			//string val=joinpath({getdatafolder(1,chanDF),nameofwave(w)})+"["+num2str(miniNum)+"]"
			ValDisplay RankValue, value=_NUM:w[Index[miniNum]], format="%3.3f"
			//SetVariable RankValue,value=_NUM:w[miniNum]
		endif
	endif
	variable i=ItemsInList(traces)-1
	do
		string trace=StringFromList(i,traces)
		if(strlen(trace))
			RemoveFromGraph $trace
		endif
		i-=1
	while(i>=0)
	return miniName
End

Function AppendMini(mini_name,channel[,noFit,traceIndex,zero,scale])
	String mini_name,channel
	Variable noFit // Do not append the fit.  
	Variable traceIndex // Index of the trace being appended.  
	Variable zero // Zero the baseline.  
	Variable scale // Scale so that the baseline to the peak spans 1 unit.  Also zeroes the baseline.  
	
	zero = scale ? 1 : zero // If we are scaling, zero regardless of whether the user has selected the 'zero' option.  
	
	Variable sweepNum,miniNum
	sscanf mini_name, "Sweep%d_Mini%d", sweepNum,miniNum
	dfref df=GetMinisSweepDF(channel,sweepNum)
	wave /z/sdfr=df Fit=$("Fit_"+num2str(miniNum))
	wave /sdfr=df Locs,Index
	FindValue /V=(miniNum) Index
	if(V_Value<0)
		printf "Could not find the value %d in %s; AppendMini().\r",miniNum,getdatafolder(1,df)+"Index"
	endif
	Variable loc=Locs[V_Value]
	//Variable loc=Locs[miniNum]
	variable proxy=GetMinisProxyState()//channel,sweepNum)
	Wave Sweep=GetChannelSweep(channel,sweepNum,proxy=proxy)
	dfref df=GetMinisDF()
	variable before=-0.015
	variable after=0.030
	Variable start=x2pnt(Sweep,loc+before)
	Variable finish=x2pnt(Sweep,loc+after)
	Variable red,green,blue; GetChannelColor(channel,red,green,blue)
	if(zero)
		WaveStats /M=1/Q/R=[start,start+100] Sweep
		Variable baseline=V_avg
	endif
	if(scale)
		WaveStats /M=1/Q/R=(loc-0.0005,loc+0.0005) Sweep // 1 second area centered at the peak.  
		Variable peak=abs(V_avg-baseline)
	else
		peak=1
	endif
	AppendToGraph /c=(red,green,blue) Sweep[start,finish] /tn=$mini_name
	setaxis bottom before,after
	if(ParamIsDefault(traceIndex))
		String top_trace=TopTrace()
		ModifyGraph offset($top_trace)={-loc,-zero*baseline/peak}
	else	
		ModifyGraph offset[traceIndex]={-loc,-zero*baseline/peak}
	endif
	if(!noFit && waveexists(Fit))
		AppendToGraph /c=(0,0,0) Fit /tn=$("Fit_"+mini_name)
		top_trace=TopTrace()
		Variable offset_fits=NumVarOrDefault(joinpath({getdatafolder(1,df),"Options","offset_fits"}),0)
		ModifyGraph offset($top_trace)={,-zero*baseline/peak+offset_fits*fitOffset} // Why does the fit have an index of 3?  There are only two traces on the graph, the data and the fit.  
	endif
End

function GetMinisProxyState()//channel,sweepNum)
	//string channel
	//variable sweepNum
	variable result=0
	dfref df=GetMinisDF()//SweepDF(channel,sweepNum)
	nvar /z/sdfr=df proxy
	if(nvar_exists(proxy) && proxy)
		result=proxy
	endif
	return result
end

function SetMinisProxyState(state)
	variable state
	
	dfref df=GetMinisDF()//SweepDF(channel,sweepNum)
	variable /g df:proxy=state
end

Function RankMinis(rankKey[,channel,reversed])
	string rankKey,channel
	variable reversed
	
	channel=selectstring(!paramisdefault(channel),GetMinisChannel(),channel)
	dfref df=GetMinisChannelDF(channel)
	if(!DataFolderRefStatus(df))
		return -1
	endif
	dfref minisDF=GetMinisDF()
	nvar /z/sdfr=minisDF reverseSort
	if(!nvar_exists(reverseSort))
		variable /g minisDF:reverseSort=1
		nvar /z/sdfr=minisDF reverseSort
	endif
	reverseSort=paramisdefault(reversed) ? !reverseSort : reversed
	
	wave rawKey=df:$cleanupname(rankKey,0)
	wave /sdfr=df Index
	make /free/n=(numpnts(Index)) key=rawKey[Index[p]]
	if(reverseSort)
		Sort /R key,Index
	else
		Sort key,Index
	endif
	if(wintype("ShowMinisWin"))
		SetWindow ShowMinisWin userData(rank)=rankKey
	endif
	variable currMini=GetCurrMini()
	if(stringmatch(TopGraph(),"ShowMinisWin"))
		GoToMini(currMini) // Start with mini 0.
	endif
End

//// Returns a sorted, scaled distribution of values for fitting coefficient 'coef_num' across all fitted minis.  
//Function /S MiniCoefDistribution(coef_num)
//	Variable coef_num
//	// Make waves for each coefficient, so that the distribution of values for each coefficient can be analyzed.  
//	String coef
//	Duplicate /o/R=[][coef_num,coef_num] AllCoefs $(StringFromList(coef_num,miniFitCoefs))
//	Wave CoefWave=$(StringFromList(coef_num,miniFitCoefs))
//	Redimension /n=(numpnts(CoefWave)) CoefWave
//	Sort CoefWave,CoefWave
//	SetScale x,0,1,CoefWave
//	return GetWavesDataFolder(CoefWave,2)
//End

// Assumed Minis have already been calculated and are stored in root:Minis.  
Function RegionMinis([to_append])
	Variable to_append
	String top_graph=TopGraph()
	DoWindow /F Ampl_Analysis
	if(!strlen(CsrInfo(A)) || !strlen(CsrInfo(B)))
		printf "Put cursors on region in Amplitude Analysis window first.\r"  
		return 0
	endif
	String channel=GetWavesDataFolder(CsrWaveRef(A),0)
	Variable sweepNum
	dfref df=GetMinisDF()
	if(!DataFolderExists(minisFolder))
		printf "Must calculate Minis first using Recalculate() or CompleteMiniAnalysis().\r"
		return -1
	endif
	dfref chanDF=GetMinisChannelDF(channel)
	Variable first=xcsr(A)+1,last=xcsr(B)+1
	String locs_name="Locs_"+num2str(first)+"_"+num2str(last)
	String vals_name="Vals_"+num2str(first)+"_"+num2str(last)
	String intervals_name="Intervals_"+num2str(first)+"_"+num2str(last)
	String hist_vals_name="Hist_Vals_"+num2str(first)+"_"+num2str(last)
	Make /o /n=0 chanDF:$locs_name /wave=All_Locs
	Make /o /n=0 chanDF:$vals_name /wave=All_Vals
	Variable cumul_time=0,duration
	//Make /o /n=0 OtherTemp2
	for(sweepNum=first;sweepNum<=last;sweepNum+=1)
		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
		wave /sdfr=sweepDF Locs,Vals
		Duplicate /free Locs Mini_Locs_temp
		Mini_Locs_temp+=cumul_time
		//WaveTransform /O flip,Mini_Locs_temp
		//OtherTemp=cumul_time
		Concatenate /NP {Mini_Locs_temp}, All_Locs
		Concatenate /NP {Vals}, All_Vals
		//Concatenate /NP {OtherTemp}, OtherTemp2
		wave Sweep=GetChannelSweep(channel,sweepNum)
		duration=numpnts(Sweep)*deltax(Sweep)
		cumul_time+=duration
	endfor
	
	DoWindow /F $top_graph
	if(!to_append || !WinExist("Mini_Ampls"))
		Display /K=1 /N=Mini_Ampls
	endif
	if(!to_append || !WinExist("Mini_Intervals"))
		Display /K=1 /N=Mini_Intervals
	endif
	
	String mode="Time"
	strswitch(mode)
		case "Time":
			Differentiate /METH=1 All_Locs /D=chanDF:$intervals_name; Wave All_Intervals=chanDF:$intervals_name
			AppendToGraph /W=Mini_Intervals All_Intervals vs All_Locs
			AppendToGraph /W=Mini_Ampls All_Vals vs All_Locs
			ModifyGraph mode=3//,marker($locs_name)=8,marker($vals_name)=17
			break
		case "Cumul":	
			Differentiate /METH=1 All_Locs /D=chanDF:$intervals_name; Wave All_Intervals=chanDF:$intervals_name
			DeletePoints 0,1,All_Intervals
			Sort All_Intervals,All_Intervals
			Sort All_Vals,All_Vals
			SetScale x,0,1, All_Intervals,All_Vals
			AppendToGraph /W=Mini_Ampls /c=(65535,0,0) All_Vals
			AppendToGraph /W=Mini_Intervals /c=(0,0,65535) All_Intervals
			ModifyGraph /W=Mini_Ampls swapXY=1
			ModifyGraph /W=Mini_Intervals swapXY=1
			break
		case "Hist":
			Make /o/n=0 chanDF:$hist_vals_name; Wave Hist_Vals=chanDF:$hist_vals_name
			Histogram /B={0,2.5,100} All_Vals,Hist_Vals
			AppendToGraph /c=(65535,0,0) Hist_Vals
			ModifyGraph mode=5
			break
	endswitch
End

Function ScaleMinis()
	Variable i,x_scale,y_scale
	String trace,traces=TraceNameList("",";",3)
	String the_note,muloffset,intended_muloffset,trace_info
	Variable scaleFlag=str2num(GetUserData("","Scale","scaled"))
	if(!scaleFlag) // Not currently scaled.  Time to scale.  
		for(i=0;i<ItemsInList(traces);i+=1)
			trace=StringFromList(i,traces)
			Wave TraceWave=TraceNameToWaveRef("",trace)
			the_note=note(TraceWave)
			trace_info=TraceInfo("",trace,0)
			muloffset=StringByKey("muloffset(x)",trace_info,"=")
			intended_muloffset=StringByKey("muloffset(x)",the_note,"=")
			sscanf muloffset, "{%f,%f}", x_scale,y_scale
			if(y_scale!=0) // Currently scaled.  Time to unscale. 
				WaveStats /Q/R=(-0.015,0.005) TraceWave
				ModifyGraph muloffset($trace)={0,0}
			else
				sscanf intended_muloffset, "{%f,%f}", x_scale,y_scale
				ModifyGraph muloffset($trace)={0,y_scale}
			endif
		endfor		
	endif
End

// Used for adding the locations and values of minis to mean/median values in the analysis window.  
// Also for updating the variables used by the Mini Reviewer for rejecting bogus minis.  
Function MiniLocsAndValsToAnalysis(sweepNum,channel,Locs,Vals[,duration,miniMethod])
	Variable sweepNum
	String channel
	Wave /Z Locs,Vals
	Variable duration
	String miniMethod
	
	if(ParamIsDefault(duration))
		Wave /Z SweepWave=GetChannelSweep(channel,sweepNum)
		if(WaveExists(SweepWave))
			duration=numpnts(SweepWave)*deltax(SweepWave)
		endif
	endif
	if(ParamIsDefault(miniMethod))
		miniMethod="Minis"
	endif
	
	dfref df=GetMinisChannelDF(channel,create=1)
	dfref dataDF=GetChannelDF(channel)
	wave /z/sdfr=dataDF MinisAnalysisWave=$miniMethod
	if(!WaveExists(MinisAnalysisWave))
		wave /t/sdfr=df MiniCounts
		variable maxSweep=str2num(MiniCounts[dimsize(MiniCounts,0)-1][0])
		make /o/n=(maxSweep+1,3) dataDF:$miniMethod /WAVE=MinisAnalysisWave
	else
		redimension /n=(-1,3) MinisAnalysisWave
	endif
	if(!WaveExists(Locs) || !WaveExists(Vals))
		MinisAnalysisWave[sweepNum][]=NaN
		return -1
	endif
	
	Variable count=numpnts(Locs)
	
	if(numpnts(Vals))
		WaveStats /Q/M=1 Vals
		MinisAnalysisWave[sweepNum][0] = abs(V_avg) // Mean mini amplitude.  
	else
		MinisAnalysisWave[sweepNum][0] = NaN
	endif
	//ampl[sweep-1] = StatsMedian(Vals) // Median mini amplitude.  
	MinisAnalysisWave[sweepNum][1] = count/duration // Mini frequency.  
	MinisAnalysisWave[sweepNum][2] = count // Mini count.  
	Note /K Locs num2str(duration)
	
	//String /G root:Minis:sweeps=sweeps
	variable currSweep=GetCurrSweep()
	string sweeps=StrVarOrDefault(joinpath({minisFolder,"sweeps"}),"0,"+num2str(currSweep-1))
	sweeps=ListExpand(sweeps)
	wave /z/t/sdfr=df MiniCounts
	if(!waveexists(MiniCounts))
		Make /o/T/n=(ItemsInList(sweeps),3) df:MiniCounts=""
		MiniCounts[][0]=StringFromList(p,sweeps)
		MiniCounts[][1]=""
		MiniCounts[][2]="Use"
	endif
	wave /t/sdfr=df MiniCounts
	Make /free/n=(dimsize(MiniCounts,0)) MiniSweepIndex=str2num(MiniCounts[p][0])
	FindValue /V=(sweepNum) MiniSweepIndex
	if(V_Value>=0)
		MiniCounts[V_Value][1]=num2str(count)
	endif
End

Function DisplayMiniRateAndAmpl(channel)
	String channel
	
	dfref df=GetMinisDF()
	svar /sdfr=df sweeps
	sweeps=ListExpand(sweeps)
	df=GetMinisChannelDF(channel)
	wave /t/sdfr=df MiniCounts
	Variable i, numSweeps=dimsize(MiniCounts,0),totalDuration=0
	make /free/n=0 AmplConcat
	for(i=0;i<numSweeps;i+=1)
		String sweepStr=MiniCounts[i][0]
		Variable sweepNum=str2num(sweepStr)
		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
		if(DataFolderRefStatus(sweepDF) && StringMatch(MiniCounts[i][2],"Use"))
			nvar /sdfr=sweepDF net_duration
			wave /sdfr=sweepDF Locs,Vals
			MiniLocsAndValsToAnalysis(sweepNum,channel,Locs,Vals,duration=net_duration)
			Concatenate /NP {Vals},AmplConcat
			totalDuration+=net_duration
		else
			MiniLocsAndValsToAnalysis(sweepNum,channel,$"",$"")
		endif
	endfor
	WaveStats /Q AmplConcat
	Display /K=1
	AppendToGraph root:$(channel):Minis[][0]
	ModifyGraph marker($TopTrace())=19
	AppendToGraph root:$(channel):Minis[][1]
	ModifyGraph marker($TopTrace())=8, mode=3
	Label left "Mini Ampl / Rate"
	Label bottom "Sweep Number"
	printf "%d Minis at a rate of %f Hz with a mean amplitude of %f +/- %f pA.", V_npnts,V_npnts/totalDuration,V_avg,V_sdev/sqrt(V_npnts)
End

// Stores approved minis in the SQL database (uses the SQLBulkCommand method... faster but the code is more unreadable).   
Function SQLStoreMinis()
#ifdef SQL
	String curr_folder=GetDataFolder(1)
	SVar chan=root:Minis:currChannel
	SetDataFolder root:Minis:$chan
	Wave /T MiniNames

	Make /o/n=(numpnts(MiniNames)) Segment,Sweep,Event_Num,Event_Time
	
	// Figure out the next available SegmentID.  
	SQLConnekt("Reverb")
	SQLc("SELECT SegmentID FROM Mini_Segments"); Wave SegmentID
	Execute /Q "SQLDisconnect"
	Variable id=FirstOpen(SegmentID,0)
	
	// Fill in the metadata for the minis.  
	Segment=id
	Variable i; Variable sweepNum,miniNum
	for(i=0;i<numpnts(MiniNames);i+=1)
		sscanf MiniNames[i],"Sweep%d_Mini%d",sweepNum,miniNum
		Sweep[i]=sweepNum
		Event_Num[i]=miniNum
		Wave MiniLocs=$(":Sweep"+num2str(sweepNum)+":Locs")
		Wave MiniIndex=$(":Sweep"+num2str(sweepNum)+":Index")
		FindValue /V=(miniNum) MiniIndex
		Event_Time[i]=MiniLocs[V_Value]
	endfor
	
	// Create a table showing all the data for the minis.  
	String column_names="Segment,Sweep,Event_Num,"
	column_names+=replacestring(";",miniRankStats+miniOtherStats,",")
	Variable num_columns=ItemsInList(column_names,",")
	if(!WinExist("Mini_Review_Table"))
		NewPanel /K=1 /N=Mini_Review /W=(100,100,1000,630)
		Edit /HOST=Mini_Review /N=Mini_Table /W=(0.01,0.1,0.99,0.99)
		for(i=0;i<ItemsInList(column_names,",");i+=1)
			Wave Column=$StringFromList(i,column_names,",")
			AppendToTable Column
		endfor
		Button Accept pos={0,0}, size={100,25}, proc=SQLInsertMinis,title="Add to Database"
		ModifyTable /W=Mini_Review#Mini_Table width=50, sigDigits=3
	endif
	
	// Prepare the entry for the SQL table Mini_Analysis.  
	String /G root:Minis:sql_str,root:Minis:xop_str; SVar sql_str=::sql_str; SVar xop_str=::xop_str
	sql_str="INSERT INTO Mini_Analysis ("+column_names+") "
	sql_str+="VALUES ("+RepeatList(num_columns,"?",sep=",")+")"
	xop_str=num2str(num_columns)+","+num2str(numpnts(MiniNames))+","+column_names
	
	// Prepare the entry for the SQL table Mini_Segments.  
	String /G root:Minis:sql_str2; SVar sql_str2=::sql_str2
	Variable first_sweep=xcsr(A,"Ampl_Analysis")+1
	Variable last_sweep=xcsr(B,"Ampl_Analysis")+1
	String used_sweeps=ListExpand(num2str(first_sweep)+","+num2str(last_sweep))
	Variable rs=0,leak=0,duration=0
	Wave RsWave=$("root:cell"+chan+":series_res")
	Wave LeakWave=$("root:cell"+chan+":holding_i")
	for(i=0;i<ItemsInList(used_sweeps);i+=1)
		rs+=RsWave[str2num(StringFromList(i,used_sweeps))-1]
		leak+=LeakWave[str2num(StringFromList(i,used_sweeps))-1]
		Wave SweepWave=$("root:cell"+chan+":sweep"+StringFromList(i,used_sweeps))
		duration+=(numpnts(SweepWave)*dimdelta(SweepWave,0))
	endfor
	Rs/=i; Leak/=i
	String experimenter="RCG"
	String file_name=IgorInfo(1)
	NVar threshold=root:Minis:mini_thresh
	sql_str2="INSERT INTO Mini_Segments (SegmentID,Experimenter,File_Name,Channel,First_Sweep,Last_Sweep,Duration,sweepNumbers,Threshold,Rs,Leak) VALUES "
	sql_str2+="('"+num2str(id)+"','"+experimenter+"','"+file_name+"','"+chan+"','"+num2str(first_sweep)+"','"+num2str(last_sweep)+"','"
	sql_str2+=num2str(duration)+"','"+used_sweeps+"','"+num2str(threshold)+"','"+num2str(Rs)+"','"+num2str(Leak)+"')"
	
	SetDataFolder $curr_folder
#endif
End

Function SQLInsertMinis()
#ifdef SQL
	String ctrlName
	SVar sql_str=root:Minis:sql_str; SVar xop_str=root:Minis:xop_str; SVar sql_str2=root:Minis:sql_str2
	ControlInfo /W=ShowMinisWin Channel
	String channel=S_Value
	SetDataFolder root:Minis:$channel
	Execute /Q "SQLConnect \"Reverb\",\"\",\"\""
	SQLc(sql_str2)
	SQLbc(sql_str,xop_str)
	Execute /Q "SQLDisconnect"
	DoWindow /K Mini_Review_Table
	SetDataFolder ::
#endif
End

// ----------------------- Totally optional functions that may or may not be useful. ---------------------------------------

#ifdef Rick
function CompareMinisToReversed(channel[,graph])
	string channel
	variable graph
	
	dfref forDF=GetMinisChannelDF(channel,proxy=0)
	dfref revDF=$(removeending(getdatafolder(1,forDF),":")+"_reversed")
	newdatafolder /o forDF:thresholds
	dfref df=forDF:thresholds
	
	variable red,green,blue
	GetChannelColor(channel,red,green,blue)
	variable i,j
	string miniRankStats_=miniRankStats+miniFitCoefs+miniOtherStats+"ultimate;"
	for(i=0;i<itemsinlist(miniRankStats_);i+=1)
		string stat=stringfromlist(i,miniRankStats_)
		duplicate /o forDF:$cleanupname(stat,0) df:$("for_"+cleanupname(stat,0)) /wave=forward
		duplicate /o revDF:$cleanupname(stat,0) df:$("rev_"+cleanupname(stat,0)) /wave=reversed
		sort forward,forward
		sort reversed,reversed
		setscale x,0,1,forward,reversed
		duplicate /free reversed,reversedNoNans
		ecdf(reversedNoNans)
		//if(numpnts(reversed)<alpha*numpnts(forward)) // Already less than alpha.  
		variable points=1000
		make /o/n=(points) df:$("thresh_"+cleanupname(stat,0)) /wave=threshold
		setscale x,0,1,threshold
		strswitch(stat)
			case "Plausability":
			case "MSE1":
				variable increasing=1 // Increasing value is better.  
				break
			default:
				increasing=0
		endswitch
		threshold=reversedNoNans(x)
		threshold[0]=-Inf
		threshold[numpnts(threshold)]={Inf}
		points+=2
		make /o/n=(points) df:$("sensitivity_"+cleanupname(stat,0)) /wave=sensitivity
		make /o/n=(points) df:$("specificity_"+cleanupname(stat,0)) /wave=specificity
		make /o/n=(points) df:$("fdr_"+cleanupname(stat,0)) /wave=fdr
		for(j=0;j<points;j+=1)
			if(increasing)
				extract /free forward,forwardHits,forward>=threshold[j]
				extract /free reversed,reversedHits,reversed>=threshold[j]
			else
				extract /free forward,forwardHits,forward<=threshold[j]
				extract /free reversed,reversedHits,reversed<=threshold[j]
			endif
			specificity[j]=1-numpnts(reversedHits)/(numpnts(reversedHits)+numpnts(forward)-numpnts(forwardHits))
			sensitivity[j]=numpnts(forwardHits)/(numpnts(forward))
			fdr[j]=numpnts(reversedHits)/(numpnts(forwardHits)+numpnts(reversedHits))
		endfor
		printf "%s: %4.4f\r",stat,-log(1-areaXY(Specificity,Sensitivity))
		string topWin=WinName(0,1)
		if(graph)
			display /k=1 as stat
			//appendtograph /c=(0,0,0) reversed
			appendtograph /c=(red,green,blue) sensitivity vs specificity
			setaxis /R bottom 1,0.9; setaxis left 0.5,1
			SetDrawEnv xcoord= bottom, dash=3;DelayUpdate
			DrawLine 0.99,1,0.99,0
			autopositionwindow /R=$topWin $winname(0,1)
			doupdate
		endif
		//setaxis /R bottom 0,1
		//appendtograph /c=(red,green,blue) specificity vs threshold
		//appendtograph /c=(red,green,blue) sensitivity vs threshold 
	endfor
end

function AllMiniStats(channel[,proxy,stats])
	string channel
	variable proxy
	string stats
	
	stats = selectstring(!paramisdefault(stats),miniRankStats+miniFitCoefs,stats)
	stats=removefromlist2("Score;pFalse;Event Time;Interval",stats)
	dfref df=GetMinisChannelDF(channel,proxy=0)
	dfref proxy_df=GetMinisChannelDF(channel,proxy=proxy)
	wave /sdfr=df index
	wave index_proxy=proxy_df:index
	variable i
	for(i=0;i<itemsinlist(stats);i+=1)
		string stat=stringfromlist(i,stats)
		wave /sdfr=df w=$cleanupname(stat,0)
		wavestats /q w
	 	if(v_npnts==0)
	 		continue
	 	endif
	 	make /free/n=(numpnts(index)) score=w[index[p]]
	 	
		wave /sdfr=proxy_df w_proxy=$cleanupname(stat,0)
	 	make /free/n=(numpnts(index_proxy)) score_proxy=w_proxy[index_proxy[p]]
	 		
	 	make /free/n=0 is_non_positive
	 	concatenate {score,score_proxy},is_non_positive
	 	is_non_positive = is_non_positive<=0
	 	//if(sum(is_non_positive)==0) // If there are non-positives, then log-transform.  
	 	//	score=ln(score)
	 	//	score_proxy=ln(score_proxy)
	 	//else
	 		score=sign(score)*abs(score)^(1/3)
	 		score_proxy=sign(score_proxy)*abs(score_proxy)^(1/3)
	 	//endif
	 	
	 	// Center the data around the candidate median.  
	 	wavestats /q score
	 	statsquantiles /q score
	 	variable center = v_median, normalize = v_iqr
	 	
	 	//if(i==0)
	 	//	duplicate /o score,caca
	 	//endif
	 	score = (score[p]-center)/normalize
	 	score_proxy = (score_proxy[p]-center)/normalize
	 	
	 	if(i==0)
			make /o/n=(numpnts(index_proxy),itemsinlist(stats)) proxy_df:ultimate=nan
		endif
	 	wave /sdfr=proxy_df ultimate
	 	ultimate[][i]=score_proxy[p]
	 	SetDimLabel 1,i,$stat,ultimate 
	endfor
end

function /wave LogIfPositive(w)
	wave w
	
	duplicate /free w,non_positive,transformed
	non_positive = w<=0
	if(sum(non_positive)==0)
		transformed = ln(w)
	endif
	return transformed
end

function MiniProbFalse(channel,proxy[,method,stats])
	string channel
	variable proxy
	string method,stats
	
	if(proxy==0)
		return 0
	endif
	method = selectstring(!paramisdefault(method),"PCA",method)
	
	//stats = selectstring(!paramisdefault(stats),"Log(1-R2);Rise 10%-90%;",stats)
	stats = selectstring(!paramisdefault(stats),miniRankStats+miniFitCoefs,stats)
	stats=removefromlist2("Score;pFalse;Event Time;Interval",stats)
	variable num_stats=min(50,itemsinlist(stats))
	
	AllMiniStats(channel,proxy=0,stats=stats)
	dfref df=GetMinisChannelDF(channel,proxy=0)
	wave /sdfr=df ultimate,use,index
	variable i,j,num_minis=dimsize(ultimate,0)
	variable num_minis_original = dimsize(use,0)
	
	AllMiniStats(channel,proxy=proxy,stats=stats)
	dfref df=GetMinisChannelDF(channel,proxy=proxy)
	wave ultimate_proxy=df:ultimate
	variable num_minis_proxy=dimsize(ultimate_proxy,0)
	
	make /o/n=(num_minis_original) df:pFalse /wave=pFalse=(Use[p] ? 0 : nan)
	if(num_minis_proxy)
		make /free/n=(0,num_stats) ultimate_combined
		concatenate /np=0 {ultimate,ultimate_proxy},ultimate_combined
		
		//variable cols_=dimsize(ultimate_forward,1)
		duplicate /o ultimate,df:lambdas /wave=lambdas
		duplicate /o ultimate_proxy,df:lambdas_proxy /wave=lambdas_proxy
		
		strswitch(method)
			case "ICA":
				MatrixOp /free ultimate_combined_=subtractmean(subtractmean(ultimate_combined,2),1)
				simpleICA(ultimate_combined_,num_stats,$"")
				wave ICARes
				lambdas=ICARes[p][q]
				lambdas_proxy=ICARes[p+num_minis][q]
				break
			case "PCA":
				matrixtranspose ultimate_combined
				MatrixOp /free ultimate_combined_=subtractmean(ultimate_combined,2)
				//MatrixOp /free ultimate_combined_=subtractmean(subtractmean(ultimate_combined,2),1)
				PCA /LEIV /SCMT /SRMT /VAR ultimate_combined_
				//wave M_R // Each column of this matrix is a principal component.  NormalizedData=M_R*M_C
				wave M_C // Each row of this matrix is the coefficients for one principal component.
				lambdas=M_C[q][p] // Lambdas for all tetrodes, with 'num_PCs' columns per tetrode.  
				lambdas_proxy=M_C[q][p+num_minis] // Lambdas for all tetrodes, with 'num_PCs' columns per tetrode.  	
				break
			case "Raw":
			default:
				if(!stringmatch(method,"Raw"))
					printf "Unknown method.  Using 'Raw'.\r"
				endif
				lambdas=ultimate_combined[p][q]
				lambdas_proxy=ultimate_combined[p+num_minis][q]
		endswitch
		make /o/n=(0,num_stats) all_lambdas
		concatenate /np=0 {lambdas,lambdas_proxy}, all_lambdas
		variable max_rank=min(dimsize(all_lambdas,0)-1,dimsize(all_lambdas,1))
		redimension /n=(-1,max_rank) all_lambdas // Ensure that there are more minis than stats.  
		
		variable prior=max(0.001,num_minis_proxy/num_minis)
		make /free/n=(num_stats,2) maxes,mins,means,stdevs
		make /free/n=(num_stats,2)/wave histograms
		for(i=0;i<max_rank;i+=1) // Iterate over all principal components.  
			for(j=0;j<2;j+=1)
				if(j==0)
					wave w=col(lambdas_proxy,i)
					//duplicate /o w,lambdas_proxy_
				else
					wave w=col(lambdas,i)
					//duplicate /o w,lambdas_
				endif
				wavestats /q w
				maxes[i][j]=v_max
				mins[i][j]=v_min
				//statsquantiles /q w
				//means[i][j]=v_median
				//stdevs[i][j]=v_iqr/(2*statsinvnormalcdf(0.75,0,1))
				variable bins = 100
				make /free/d/n=(bins) hist
				wave all=col(all_lambdas,i)
				wavestats /q all
				variable delta = (v_max-v_min)/bins
				setscale x,v_min-delta,v_max+delta,hist
				histogram /b=2/p w,hist
				smooth /e=2 200,hist
				duplicate /o hist $("hist_"+num2str(i)+selectstring(j,"_proxy",""))
				histograms[i][j]=hist
			endfor
		endfor
		
		for(j=0;j<num_minis;j+=1) // Iterate over candidate minis.  
			Prog("pFalse",j,num_minis)
			variable prob=prior
			for(i=0;i<max_rank;i+=1) // Iterate over all principal components.  
				variable yy=lambdas[j][i]
				
				// Likelihood.  
				wave hist_f=histograms[i][0]
				
				// Marginal.  
				wave hist=histograms[i][1]
				
				prob*=hist_f(yy)/hist(yy)
				if(numtype(prob))
					duplicate /o hist_f,$"hist_f"
					duplicate /o hist,$"hist"
					print i,yy
					abort
				endif
				prob=min(prob,1)
			endfor
			pFalse[index[j]]=min(prob,1)
			//wave /sdfr=GetMinisChannelDF(channel,proxy=0) Log_1_R2_,Rise_10__90_
		endfor
		make /o/d/n=(100,100) df:pFalse2D /wave=pFalse2D=prior
		setscale /i x,mins[0][1],maxes[0][1],pFalse2D
		setscale /i y,mins[1][1],maxes[1][1],pFalse2D
		for(i=0;i<max_rank;i+=1) // Iterate over all principal components.  
			wave hist_f=histograms[i][0]
			wave hist=histograms[i][1]
			if(i==0)
				pFalse2D *= hist_f(x)/hist(x)
			elseif(i==1)
				pFalse2D *= hist_f(y)/hist(y)
			endif
		endfor
		//pFalse2D *= statsnormalpdf(x,means[0][0],stdevs[0][0])/statsnormalpdf(x,means[0][1],stdevs[0][1])
		//pFalse2D *= statsnormalpdf(y,means[1][0],stdevs[1][0])/statsnormalpdf(y,means[1][1],stdevs[1][1])
		pFalse2D = min(1,pFalse2D)
	endif
end

function /wave MiniStatsGivenProxy(channel,proxy,fpr[,stats])
	string channel,stats
	variable proxy
	variable fpr // False positive rate.  
	
	if(paramisdefault(stats))
		stats="Event Size;Interval"
	endif
	dfref df=GetMinisChannelDF(channel,proxy=0)
	wave /sdfr=df use
	variable num_minis_raw=dimsize(use,0)
	dfref proxyDF=GetMinisChannelDF(channel,proxy=proxy)
	wave /sdfr=proxyDF use
	variable num_minis_proxy_raw=dimsize(use,0)
	if(num_minis_raw<3)
		make /o/n=(num_minis_raw) proxyDF:pFalse=0
	elseif(num_minis_proxy_raw<3)
		make /o/n=(num_minis_raw) proxyDF:pFalse=0	
	else
		MiniProbFalse(channel,proxy)
	endif
	make /free/n=(itemsinlist(stats)) statsWave
	wave /sdfr=df use
	wave /sdfr=proxyDF pFalse
	extract /free pFalse,pFalse_,use==1
	if(numpnts(pFalse_))
		sort pFalse_,pFalse_
		setscale x,0,1,pFalse_
		duplicate /free pFalse_ pFalse_cumul
		integrate pFalse_cumul
		findlevel /q pFalse_cumul,fpr
		if(v_flag)
			variable fractUse=1
		else
			fractUse=v_levelx
		endif
		variable pFalse_thresh = pFalse_(fractUse)
		variable numUse=fractUse*numpnts(pFalse_)
		//RankMinis("pFalse",channel=channel,reversed=0)
		newdatafolder /o df:Stats
		dfref statsDF=df:Stats
		wave /sdfr=df Event_Size
		variable i
		string results=""
		printf "%d/%d Minis Used.\r",numUse,numpnts(pFalse_)		
		for(i=0;i<itemsinlist(stats);i+=1)
			string stat=stringfromlist(i,stats)
			setdimlabel 0,i,$stat,statsWave
			wave w=df:$CleanupName(stat,0)
			extract /free w,w_Used,use==1 && pFalse_<=pFalse_thresh && numtype(w)==0
			printf "%s: %f\r",stat,statsmedian(w_Used)
			statsWave[%$stat]=statsmedian(w_Used)
		endfor
	else
		statsWave=nan
	endif
	return statsWave
end

function FormatMiniStats(proxy)
	variable proxy // Set to 0 to use the median of all the proxies.  
	
	cd root:
	string conditions="ctl;ttx"
	wave /t/sdfr=root:db file_name,drug_incubated,channel,experimenter
	wave /sdfr=root:db div,div_drug_added
	make /o/n=0 Size,Interval,DIV_Added,DIV_Recorded,Days_In_Drug
	make /o/t/n=0 Condition,File,Person
	variable i,j,count=0
	for(i=0;i<itemsinlist(conditions);i+=1)
		string condition_=stringfromlist(i,conditions)
		wave Stats=$("Stats_"+condition_)
		for(j=0;j<dimsize(Stats,2);j+=1)
			string file_channel=GetDimLabel(Stats,2,j)
			string file_=removeending(file_channel,"_cellR1")
			file_=removeending(file_,"_cellL2")
			file_=removeending(file_,"_cellL2-1")
			file_=removeending(file_,"_cellL2-2")
			findvalue /text=file_ /txop=4 file_name
			if(v_value<0)
				printf "Could not find file %s in xf_filename.\r",file_
				continue
			endif
			variable index=v_value
			if(div_drug_added[index]>11)
				continue
			endif
			File[count]={file_name[index]}
			Person[count]={experimenter[index]}
			if(!stringmatch(drug_incubated[index],condition_))
				printf "Drug incubated doesn't match condition!\r"
			endif
			Condition[count]={drug_incubated[index]}
			if(proxy)
				Size[count]={Stats[0][proxy-1][j]}
				Interval[count]={Stats[1][proxy-1][j]}
			else
				duplicate /free/r=[0,0][][j,j] Stats, temp
				Size[count]={statsmedian(temp)}
				duplicate /free/r=[1,1][][j,j] Stats, temp
				Interval[count]={statsmedian(temp)}
			endif
			DIV_Recorded[count]={div[index]}
			DIV_Added[count]={div_drug_added[index]}
			Days_In_Drug[count]={div[index]-div_drug_added[index]}
			count+=1
		endfor
	endfor
end

function MinisBatch(proxy,[fdr,stats,files,clean,search,analyze,messiness_thresh,save_,use_copy])
	wave proxy
	variable fdr,messiness_thresh,clean,search,analyze
	variable save_ // Save a copy after processing.  
	variable use_copy // Start with the processed copy, rather than the raw experiment file.  
	string stats,files
	
	files=selectstring(!paramisdefault(files),"*",files)
	messiness_thresh = paramisdefault(messiness_thresh) ? 20 : fdr
	stats=selectstring(!paramisdefault(stats),"Event Size;Interval;",stats)
	fdr = paramisdefault(fdr) ? 0.01 : fdr
	//clean = paramisdefault(clean) ? 0 : clean
	string suffix = selectstring(!paramisdefault(use_copy) && use_copy,"","_analyzed")
	
	ProgReset()
	string db="reverb2"
	newpath /o/q Desktop,SpecialDirPath("Desktop",0,0,0)
	newpath /o/q XFMinisPath "E:GQB Projects:Xu Fang mEPSC Data"
	newpath /o/q RCGMinisPath "E:GQB Projects:Reverberation:Data:2007"
	
	close /a 
	variable i,j,k,ref_num
	KillAll("windows")
	newdatafolder /o/s root:DB
	SQLc("SELECT A1.File_Name,A1.Experimenter,A1.Drug_Incubated,A1.DIV,A1.DIV_Drug_Added,A2.Channel,A2.Sweep_Numbers,A3.Baseline_Sweeps FROM ((Island_Record A1 INNER JOIN Mini_Segments A2 ON A1.File_Name=A2.File_Name) INNER JOIN Mini_Sweeps A3 ON A1.File_Name=A3.File_Name) WHERE A1.Experimenter",db=db)
	wave /t File_Name,Drug_Incubated,Channel,Sweep_Numbers,Baseline_Sweeps,Experimenter
	wave DIV,DIV_Drug_Added
	setdatafolder root:
	string curr_file=""
	string curr_experimenter=""
	variable sweepInfo,miniResults
	Open /P=Desktop sweepInfo as "sweepInfo.txt"
	Open /P=Desktop miniResults as "MinisResults.txt"
	variable processed=0
	for(i=0;i<numpnts(File_Name);i+=1)
		string file=File_Name[i]
		if(!stringmatch2(file,files))
			continue
		endif
		prog("Cell",i,numpnts(File_Name),msg=file)
		string channel_="cell"+stringfromlist(0,Channel[i],"-")
		if(stringmatch(Experimenter[i],"RCG")) // If Rick did the experiment, check to see that the sweeps in question are baseline sweeps.  
			string baseline_sweeps_=listexpand(Baseline_Sweeps[i])
			string first_sweep=stringfromlist(0,Sweep_Numbers[i])
			if(whichlistitem(first_sweep,baseline_sweeps_)>=0) // The sweeps to analyze are baseline sweeps.  
				string sweeps = baseline_sweeps_
				k=0
				do // Start analysis with sweep10.  
					sweeps = removefromlist(num2str(k),sweeps)
					k+=1
				while(minlist(sweeps)<=10)
				if(itemsinlist(sweeps)<5)
					printf "Only %d sweeps to analyze for channel %s of file %s.\r", itemsinlist(sweeps),channel_,file
				endif	
			else // They are not baseline sweeps.  
				continue
			endif
		else
			sweeps=Sweep_Numbers[i]
		endif
		if(!stringmatch(file,curr_file))
			if(processed>0 && save_)
				saveexperiment /c/p=$(curr_experimenter+"MinisPath") as curr_file+"_analyzed.pxp"
			endif
			cd root:
			KillAll("windows",except="MiniStatsTable*")//;Messiness*")
			KillRecurse("*",except="Packages;DB")
			GetFileFolderInfo /Q/P=$(Experimenter[i]+"MinisPath")/Z=1 file+suffix+".pxp"
			if(v_flag || !v_isfile)
				printf "No such file: %s.\r",file
				continue
			endif
			cd root:
			printf "Loading data for %s.\r",file
			fprintf sweepInfo, "%s\r", file
			svar /z/sdfr=root: textProgStatus
			LoadData /O/Q/R/P=$(Experimenter[i]+"MinisPath") file+suffix+".pxp"
			ProgReset()
			prog("Cell",i,numpnts(File_Name),msg=file)
			if(clean)
				BackwardsCompatibility(quiet=1,dontMove="XuFangStats*;DB",recompile=(i==0))
				SuppressTestPulses()
			endif
		endif
		dfref channelDF=GetChannelDF(channel_)
		if(!datafolderrefstatus(channelDF))
			printf "Channel %s not found.\r",channel_
			continue
		endif
		sweeps=ListExpand(sweeps)
		sweeps=AddConstantToList(sweeps,-1)
		printf "Channel %s.\r",channel_
		fprintf sweepInfo, "\tChannel %s\r", channel_
		string good_sweeps=""
		wave /z Messiness_=root:$(channel_):Messiness
		if(!waveexists(Messiness_))
			make /o/n=0 root:$(channel_):Messiness /wave=Messiness_
		else
		endif
		for(j=0;j<itemsinlist(sweeps);j+=1)
			variable sweep_num=str2num(stringfromlist(j,sweeps))
			if(clean)
				Prog("Messy?",j,itemsinlist(sweeps))
				wave /z Sweep=GetChannelSweep(channel_,sweep_num)
				if(waveexists(sweep))
					variable messiness=SweepMessiness(Sweep)
					Messiness_[sweep_num]={messiness}
					fprintf sweepInfo, "\t\tSweep %d: Messiness = %.1f\r",sweep_num,messiness
				endif
			else
				messiness=Messiness_[sweep_num]
			endif
			if(messiness<messiness_thresh)
				good_sweeps+=num2str(sweep_num)+";"
			else
				printf "Sweep %d is too messy: %.1f\r",sweep_num,messiness
			endif
		endfor
		if(clean)
			Prog("Messy?",0,0)
		endif
		fprintf miniResults,"%s (%s)\r",file,channel_
		if(search)		
			MiniSearch(proxy,channel_,good_sweeps,miniResults)
		endif
		if(analyze)
			wave statsMatrix=MiniStats(proxy,fdr,channel_,miniResults,stats=stats)
			wave /z w=root:$("Stats_"+Drug_Incubated[i])
			if(!waveexists(w))
				duplicate /o statsMatrix root:$("Stats_"+Drug_Incubated[i]) /wave=w
				dowindow /k $("MiniStatsTable_"+Drug_Incubated[i])
				edit /n=$("MiniStatsTable_"+Drug_Incubated[i]) w.ld
				variable index=0
			else
				index=dimsize(w,2)
			endif
			redimension /n=(-1,-1,index+1) w
			w[][][index]=statsMatrix[p][q]
			setdimlabel 2,index,$(file+"_"+channel_),w
			save /o/p=Desktop w as "MiniResults_"+Drug_Incubated[i]+".ibw"
		endif
		curr_file=file
		curr_experimenter=Experimenter[i]
		processed+=1
		//abort
	endfor
	if(save_)
		saveexperiment /c/p=$(Experimenter[i]+"MinisPath") as curr_file+"_analyzed.pxp"
	endif
	close sweepInfo
	close miniResults
end

function MiniSearch(proxy,channel,sweeps,miniResults)
	wave proxy
	string channel,sweeps
	variable miniResults // A file reference.  
	
	SetMinisChannel(channel)
	duplicate /free proxy,proxies
	findvalue /V=0 proxy
	if(v_value<0)
		insertpoints 0,1,proxies
		proxies[0]=0
	endif
	
	variable i,j
	for(i=0;i<numpnts(proxies);i+=1)
		variable currProxy=proxies[i]
		SetMinisProxyState(currProxy)
		if(miniResults>=0)
			fprintf miniResults, "\t[Proxy = %d]\r",currProxy
		endif
		CompleteMiniAnalysis(miniSearch=1,channels=channel,threshold=-5,sweeps=sweeps)
		dfref df=GetMinisChannelDF(channel)
		wave /t/sdfr=df MiniCounts
		if(miniResults>=0)
			for(j=0;j<dimsize(MiniCounts,0);j+=1)
				fprintf miniResults, "\t\tSweep %d: %d minis\r",str2num(MiniCounts[j][0]),str2num(MiniCounts[j][1])
			endfor
		endif
		InitMiniStats(channel)
		FitMinis()
		MoreMiniStats(channel)
		KillFailedMinis(channel)
	endfor
	SetMinisProxyState(0)
end

function /wave MiniStats(proxy,fdr,channel,miniResults[,stats])
	wave proxy
	variable fdr
	string channel,stats
	variable miniResults // A file reference.  
	
	if(paramisdefault(stats))
		stats="Event Size;Interval"
	endif
	
	SetMinisChannel(channel)
	
	// Stats by which to automatically exclude certain minis from consideration.  
	string kill_stats = miniRankStats+miniFitCoefs
	kill_stats=removefromlist2("Score;pFalse;Event Time;Interval",kill_stats)
	
	variable i,j
	for(i=0;i<numpnts(proxy);i+=1)
		Prog("Proxy",i,numpnts(proxy),msg=num2str(proxy[i]))
		wave proxyResults=MiniStatsGivenProxy(channel,proxy[i],fdr,stats=stats)
		if(i==0)
			duplicate /free proxyResults statsMatrix
		endif
		redimension /n=(-1,i+1) statsMatrix
		setdimlabel 1,i,$num2str(proxy[i]),statsMatrix
		statsMatrix[][i]=proxyResults[p] 
		fprintf miniResults,"\t[Proxy %d]\r",proxy[i]
		for(j=0;j<itemsinlist(stats);j+=1)
			fprintf miniResults,"\t\t%s:%d\r",stringfromlist(j,stats),proxyResults[j]
		endfor
	endfor
	fprintf miniResults,"\r"
	return statsMatrix
end

function KillFailedMinis(channel[,proxy,stats])
	string channel,stats
	variable proxy

	proxy = paramisdefault(proxy) ? GetMinisProxyState() : proxy
	stats = selectstring(!paramisdefault(stats),miniRankStats+miniFitCoefs,stats)
	stats=removefromlist2("Score;pFalse;Event Time;Interval",stats)
	
	dfref df=GetMinisChannelDF(channel,proxy=proxy)
	wave /sdfr=df Index
	variable j=0,k
	if(numpnts(Index))
		do
			variable safe=1
			for(k=0;k<itemsinlist(stats);k+=1)
				string stat = stringfromlist(k,stats)
				wave /sdfr=df w=$cleanupname(stat,0)
				variable kill=0
				strswitch(stat)
					case "Event Size":
						if(w[Index[j]]<5) // Kill any mini less than 5 pA in size.  
							kill=1
						endif
						break
				endswitch
				if(numtype(w[Index[j]]))
					kill=1
				endif
				if(kill)
					KillMini(j,channel=channel,proxy=proxy)
					safe = 0
					break
				endif
			endfor
			if(safe)
				j+=1
			endif
		while(j<numpnts(Index))
	endif
end

function SweepMessiness(w)
	wave w
	
	duplicate /free/r=(0.3,) w,w_
	resample /rate=100 w_
	smooth /m=0 15,w_
	wavestats /q w_
	return v_sdev^2
end

function SuppressTestPulses()
	variable i,j,currSweep=GetCurrSweep()
	string channels=UsedChannels()
	for(i=0;i<currSweep;i+=1)
		Prog("Supressing test pulses...",i,currSweep,msg="Sweep "+num2str(i))
		for(j=0;j<itemsinlist(channels);j+=1)
			string channel=stringfromlist(j,channels)
			SuppressTestPulse(channel,i)
		endfor
	endfor
	Prog("Supressing test pulses...",0,0) // Hide this progress bar.  
end

function test124(channel)
	string channel
	
	dfref fdf=GetMinisChannelDF(channel,proxy=0)
	dfref rdf=GetMinisChannelDF(channel,proxy=1)
	wave /sdfr=fdf fTime=Offset_Time
	wave /sdfr=rdf rTime=Offset_Time
	wave /t/sdfr=fdf fName=MiniNames
	wave /t/sdfr=rdf rName=MiniNames
	variable i,sweepNum,miniNum
	
	make /free/n=(numpnts(fTime)) fSweep
	for(i=0;i<numpnts(fSweep);i+=1)
		sscanf fName[i],"Sweep%d_Mini%d",sweepNum,miniNum
		fSweep[i]=sweepNum
	endfor
	make /free/n=(numpnts(rTime)) rSweep
	for(i=0;i<numpnts(rSweep);i+=1)
		sscanf rName[i],"Sweep%d_Mini%d",sweepNum,miniNum
		rSweep[i]=sweepNum
	endfor
	
	make /free/n=(numpnts(fTime),numpnts(rTime)) test=fTime[p] - (30000-rTime[q])
	test=(fSweep[p] == rSweep[q]) ? abs(test[p][q]) : Inf
	make /o/n=(numpnts(rTime)) relTime_
	for(i=0;i<numpnts(rTime);i+=1)
		wave w=col(test,i)
		relTime_[i]=wavemin(w)
	endfor
end

function MiniPCA(channel)
	string channel
	
	dfref df=GetMinisChannelDF(channel)
	wave w=MakeMiniMatrix(channel)
	matrixop /o w=subtractmean(subtractmean(w,1),2)
	//matrixop /o w=normalizecols(w)
	//matrixop /o w=normalizerows(w)
	//matrixop /o w=normalizerows(subtractmean(w,1))
	//matrixop /o w=normalizerows(subtractmean(subtractmean(w,1),2))
	PCA /LEIV /SCMT /SRMT /VAR w
	Wave M_R // Each column of this matrix is a principal component.  NormalizedData=M_R*M_C
	Wave M_C // Each row of this matrix is the coefficients for one principal component.  
	variable numMinis=dimsize(w,1)
	variable numPoints=dimsize(w,0)
	make /o/n=(numPoints,3) df:PCs=M_R[p][q]  
	make /o/n=(numMinis,3) df:Lambdas=M_C[q][p]  
	killwaves /z M_R,M_C
end

function /wave MakeMiniMatrix(channel)
	string channel
	
	dfref df=GetMinisChannelDF(channel)
	wave /t/sdfr=df MiniNames
	wave /sdfr=df Index,Offset_Time
	variable numMinis=numpnts(Index)
	variable kHz=10
	variable start=-7,finish=15 // In ms.  
	make /o/n=(1,numMinis) MiniMatrix
	variable i,sweepNum,miniNum
	for(i=0;i<numMinis;i+=1)
		sscanf MiniNames[Index[i]],"Sweep%d_Mini%d",sweepNum,miniNum
		wave sweep=GetChannelSweep(channel,sweepNum)
		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
		wave /sdfr=sweepDF Locs
		if(i==0)
			variable numPoints=0.001*(finish-start)/dimdelta(sweep,0)
			make /o/n=(numPoints,numMinis) df:MiniMatrix /wave=MiniMatrix
			setscale /p x,0,dimdelta(sweep,0),MiniMatrix
		endif
		variable start_=(Locs[miniNum]+start/1000-dimoffset(sweep,0))/dimdelta(sweep,0)
		MiniMatrix[][i]=sweep[start_+p]
	endfor
	return MiniMatrix
end

// Create inter-mini distributions for each of several size cutoffs.  
Function MiniDistributions()
	root()
	Variable i,j;String folder
	Wave /T FileName
	String mins="6;8;10;15;20"; Variable minn
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:VC:"+FileName[i]+"_VC"
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave /Z MiniLocs
			if(waveexists(MiniLocs))
				for(j=0;j<ItemsInList(mins);j+=1)
					minn=NumFromList(j,mins)
					Wave Ampls=:MiniAmpls	
					Duplicate /o MiniLocs :MiniLocsTemp
					Wave Locs=:MiniLocsTemp
					Locs=(Ampls>minn) ? Ampls : NaN
					Extract/O Locs,Locs,numtype(Locs) == 0
					Duplicate/ o Locs :$("MiniIntervals_"+num2str(minn))
					Wave Intervals=:$("MiniIntervals_"+num2str(minn))
					Intervals=Locs[p]-Locs[p-1]
					DeletePoints 0,1,Intervals
					KillWaves /Z Locs
				endfor
			endif
			//Wave U_Intervals,UpstateOn,UpstateOff
			//U_Intervals=UpstateOn-UpstateOff[p-1]
			//U_Intervals[0]=NaN
		endif
	endfor
End

#ifdef SQL
// Collect mini statistics for each of the regions specified in the table Mini_Sweeps in the Reverberation database.  
// Creates a folder hierarchy of cell:channel, and each wave has a point for each epoch, where epoch 0 is the baseline, 
// epoch 1 is early in the post-activity baseline, epoch 2 is late in the post-activity baseline, and subsequent epochs are in
// subsequent baseline periods.  
Function CollectMiniStats()
	root()
	SQLConnekt("Reverb")
	SQLc("SELECT A1.DIV,A1.Drug_Incubated,A2.* FROM Island_Record A1, Mini_Sweeps A2 WHERE A1.File_Name=A2.File_Name") 
	// Get all the data from Mini_Sweeps and info about whether it was a TTX incubated or a control experiment.  
	Wave /T File_Name,Baseline_Sweeps,Post_Activity_Sweeps,Intervening_Drugs,Drug_Incubated
	Variable i,j,k
	String channels="R1;L2"
	
	for(i=0;i<numpnts(File_Name);i+=1)
		String file=File_Name[i]
		String before=Baseline_Sweeps[i]
		String after=StringFromList(0,Post_Activity_Sweeps[i]) // The sweep range of the baseline after the first region of activity.  
		String after2=StringFromList(1,Post_Activity_Sweeps[i])  // The sweep range of the baseline after the second region of activity.  
		if(strlen(after2)==0)
			after2="9999999"
		endif
		NewDataFolder /O/S root:$file
		for(j=0;j<ItemsInList(channels);j+=1)
			String channel=StringFromList(j,channels)
			NewDataFolder /O/S root:$(file):$channel
			SQLc("SELECT * FROM Mini_Segments WHERE Channel='"+channel+"' AND File_Name='"+file+"'")
			Make /o/n=5 MeanSize=NaN,MedianSize=NaN,Frequency=NaN
			Wave MeanSize,MedianSize,Frequency
			Wave First_Sweep,Last_Sweep,SegmentID,Duration,Rs
			for(k=0;k<numpnts(SegmentID);k+=1)
				variable id=SegmentID[k]
				SQLc("SELECT * FROM Mini_Analysis WHERE Segment="+num2str(id)) // What about a maximum value for the decay time constant?  
				wave Event_Size,Duration, Decay_Time
				
				Variable med_sweep=round((First_Sweep[k]+Last_Sweep[k])/2) // The median sweep of this segment.    
				Variable before_after_cutoff=20 // Number of sweeps separating "early" (epoch 1) from "late" (epoch 2).  Won't matter much if segments in the database are far from this value.  
				Variable first_sweep_after=NumFromList(0,ListExpand(after)) // The first sweep after the first region of activity.  
				Variable first_sweep_after2=NumFromList(0,ListExpand(after2)) // The first sweep after the second region of activity.  
				
				if(InRegion(med_sweep,before))
					Variable epoch=0 // Before activity.  
				elseif(InRegion(med_sweep,after))
					if(med_sweep<first_sweep_after+before_after_cutoff)
						epoch=1 // 5-10 minutes after activity.  
					else
						epoch=2 // 25-30 minutes after activity.  
					endif
				elseif(InRegion(med_sweep,after2)) // In the region after the second baseline, i.e. after a second round of activity.  
					if(med_sweep<first_sweep_after2+before_after_cutoff)
						epoch=3 // 5-10 minutes after activity.  
					else
						epoch=4 // 25-30 minutes after activity.  
					endif
				else
					epoch=-1
					printf "Epoch could not be identified for id %d.\r",k
				endif
				if(epoch>=0)
					Event_Size*=exp(0.005*Rs[k])/exp(0.005*25) // Normalize for access resistance.  
					//Extract /O Event_Size,Event_Size,Decay_Time<10
					//Extract /O Event_Size,Event_Size,Event_Size>5
					WaveStats /Q Event_Size
					MeanSize[epoch]=V_avg
					MedianSize[epoch]=StatsMedian(Event_Size)
					Frequency[epoch]=numpnts(Event_Size)/Duration
				endif
			endfor
		endfor
	endfor
	root()
	SQLDisconnekt()
End

// One data point for each experiment for each stat.  
Function BaselineSummaryStats()
	setdatafolder root:
	newdatafolder /o/s sql
	SQLConnekt("Reverb")
	SQLc("SELECT A1.DIV,A1.DIV_Drug_Added,A1.Drug_Incubated,A2.* FROM Island_Record A1, Mini_Sweeps A2 WHERE A1.File_Name=A2.File_Name") 
	// Get all the data from Mini_Sweeps and info about whether it was a TTX incubated or a control experiment.  
	wave /t/sdfr=root:sql Experimenter,File_Name,Baseline_Sweeps,Post_Activity_Sweeps,Intervening_Drugs,Drug_Incubated
	wave /sdfr=root:sql DIV,DIV_Drug_Added
	setdatafolder root:
	variable i,j,k,m
	string channels="R1;L2"
	string conditions="CTL;TTX"
	
	make /o/n=0 Amplitude,Amplitudes,Frequency,Count,Duration,Interval,Intervals,Threshold,DIV_Recorded,DIV_Added,Days_In_Drug
	make /o/t/n=0 File,Person,Condition,Analysis
	
	make /free/n=(itemsinlist(conditions)) count=0
	variable countt=0
	for(i=0;i<numpnts(File_Name);i+=1)
		prog("File",i,numpnts(File_Name))
		string file_=File_Name[i]
		string condition_=Drug_Incubated[i]
		variable conditionNum=whichlistitem(condition_,conditions)
		if(conditionNum<-1)
			printf "Invalid condition: %s.\r",condition_
		endif
		string Sweeps=Baseline_Sweeps[i]
		string FirstSweep=StringFromList(0,Baseline_Sweeps[i],",")
		string LastSweep=StringFromList(1,Baseline_Sweeps[i],",")
		if(!strlen(FirstSweep))
			printf "No first sweep for file %s.\r",file_
			continue
		endif
		//String after=StringFromList(0,Post_Activity_Sweeps[i]) // The sweep range of the  after the first region of activity.  
		//String after2=StringFromList(1,Post_Activity_Sweeps[i])  // The sweep range of the  after the second region of activity.  
		//if(strlen(after2)==0)
		//	after2="9999999"
		//endif
		SQLc("SELECT Sweep as File_Sweep,Sweep_Dur FROM sweep_record WHERE File_Name='"+file_+"' AND Sweep>="+FirstSweep+" AND Sweep<="+LastSweep)
		wave File_Sweep,Sweep_Dur
		wavestats /Q/M=1 File_Sweep
		make/o/n=(V_max+1) SweepDurations=NaN
		for(j=0;j<numpnts(File_Sweep);j+=1)
			SweepDurations[File_Sweep[j]]=Sweep_Dur[j]
		endfor
		newdatafolder /O/S root:$file_
		variable CNQX=StringMatch(File_Name[i],"2008*")
		for(j=0;j<ItemsInList(channels);j+=1)
			Prog("Channel",j,itemsinlist(channels))
			String channel=StringFromList(j,channels)
			NewDataFolder /O/S root:$(file_):$channel
			
			// Pairwise Evoked Connectivity.  
			SQLc("SELECT ConnectivityID FROM Connectivity WHERE File_Name='"+file_+"' AND Channel='"+channel+"'")
			wave /z ConnectivityID
			if(waveexists(ConnectivityID) && numpnts(ConnectivityID))
				variable /g connID=ConnectivityID[0]
				SQLc("SELECT Autapse_Value,Partner_1,Synapse_1,Partner_2,Synapse_2,Partner_3,Synapse_3 FROM Connectivity WHERE Phenotype<>'GABA' AND ConnectivityID="+num2str(connID)) 
				make /o/n=0 Incoming,Outgoing
				wave /z Autapse_Value
				if(waveexists(Autapse_Value))
					Incoming[0]={Autapse_Value[0]*(CNQX+1)}
					Outgoing[0]={Autapse_Value[0]*(CNQX+1)}
					for(k=1;k<=3;k+=1)
						wave Partner=$("Partner_"+num2str(k))
						wave Synapse=$("Synapse_"+num2str(k))
						if(Partner[0]>0)
							Outgoing[numpnts(Outgoing)]={Synapse[0]*(CNQX+1)}
						endif
					endfor
				endif
				for(k=1;k<=3;k+=1)
					SQLc("SELECT Synapse_1,Synapse_2,Synapse_3 FROM Connectivity WHERE Phenotype<>'GABA' AND Partner_"+num2str(k)+"="+num2str(connID))
					wave Synapse=$("Synapse_"+num2str(k))
					for(m=0;m<numpnts(Synapse);m+=1)
						Incoming[numpnts(Incoming)]={Synapse[m]*(CNQX+1)}
					endfor
				endfor 
			endif	
			
			SQLc("SELECT * FROM Mini_Segments WHERE Channel='"+channel+"' AND File_Name='"+file_+"' AND First_Sweep>="+FirstSweep+" AND Last_Sweep<="+LastSweep)
			wave /Z First_Sweep,Last_Sweep,SegmentID,Duration,Rs,Threshold
			if(!waveexists(First_Sweep))
				printf "No first sweep for file %s, channel %s.\r",file_,channel
				continue
			else
				printf "OK: File %s, Channel %s.\r",file_,channel
			endif
			//wave /sdfr=df Amplitude,Amplitudes,Frequency,Count,Duration,Interval,Intervals,Threshold,DIV_Recorded,DIV_Added,Days_In_Drug
			variable /g totalMinis=0, totalDuration=0, totalFreq=NaN
			make /o/n=0 Sizes
			for(k=0;k<numpnts(SegmentID);k+=1)
				SQLc("SELECT * FROM Mini_Analysis WHERE Segment="+num2str(SegmentID[k]))
				wave Event_Size,Event_Time,Sweep
				Sweep*=30
				Event_Time+=Sweep
				sort Event_Time,Event_Time,Event_Size
				differentiate /METH=1 Event_Time /D=$"Event_Interval"
				wave Event_Interval=$"Event_Interval"
				redimension /n=(numpnts(Event_Interval)-1) Event_Interval
				//Extract /O Event_Time,Event_Time,Event_Time>0
				concatenate /NP {Event_Interval}, Intervals // For the entire condition.  
				concatenate /NP {Event_Size}, Amplitudes // For the entire condition.  
				concatenate /NP {Event_Size}, Sizes // Just for this channel.  
				totalMinis+=numpnts(Event_Size)
				totalDuration+=Duration[k]
			endfor
			if(totalDuration>0)
				totalFreq=totalMinis/totalDuration
				wavestats /q/m=1 Event_Size
				if(v_npnts != totalMinis)
					printf "Number of minis not equal to number of points in Event_Size!\r"
				endif
				Amplitude[countt]={statsmedian(Event_Size)}
				Count[countt]={totalMinis}
				Duration[countt]={totalDuration}
				Interval[countt]={statsmedian(Event_Interval)}
				Frequency[countt]={totalMinis/totalDuration}
				Threshold[countt]={Threshold[0]} // Assume only one segment.  
				DIV_Recorded[countt]={DIV[i]}
				DIV_Added[countt]={DIV_Drug_Added[i]}
				Days_In_Drug[countt]={DIV[i]-DIV_Drug_Added[i]}
				File[countt]={File_Name[i]}
				Condition[countt]={condition_}
				Person[countt]={Experimenter[i]}
				Analysis[countt]={"0"} // Manual
				count[conditionNum]+=1
				countt+=1
			endif
			ECDF(Intervals)
		endfor
	endfor
	root()
	SQLDisconnekt()
End

Function ConnectivityStats()
	SQLConnekt("Reverb")
	root();
	SQLc("SELECT File_Name,Channel,ConnectivityID,Autapse_Value,Partner_1,Synapse_1,Partner_2,Synapse_2,Partner_3,Synapse_3 From Connectivity")
	//abort
	wave ConnectivityID
	wave /T File_Name,Channel,Phenotype
	variable i,k,m
	wavestats /q ConnectivityID
	make /o/n=(v_max+1) meanIncoming=nan,meanOutgoing=nan
	for(i=0;i<numpnts(ConnectivityID);i+=1)
		if(mod(i,10)==0)
			Prog("Connection",i,numpnts(ConnectivityID))
		endif
		if(stringmatch(Phenotype[i],"*GABA*"))
			continue
		endif
		variable /g connID=ConnectivityID[i]
		newdatafolder /o/s root:$File_Name[i]
		newdatafolder /o/s $Channel[i]
		make /o/n=0 Incoming,Outgoing
		variable CNQX=StringMatch(File_Name[i],"*2008*")
		wave /sdfr=root: Autapse_Value
		Incoming[0]={Autapse_Value[i]*(CNQX+1)}
		Outgoing[0]={Autapse_Value[i]*(CNQX+1)}
		for(k=1;k<=3;k+=1)
			wave Partner=root:$("Partner_"+num2str(k))
			wave Synapse=root:$("Synapse_"+num2str(k))
			if(Partner[i]>0)
				Outgoing[numpnts(Outgoing)]={Synapse[i]*(CNQX+1)}
			endif
		endfor					
		for(k=1;k<=3;k+=1)
			SQLc("SELECT Synapse_1,Synapse_2,Synapse_3 FROM Connectivity WHERE Phenotype<>'GABA' AND Partner_"+num2str(k)+"="+num2str(connID))
			wave Synapse=$("Synapse_"+num2str(k))
			for(m=0;m<numpnts(Synapse);m+=1)
				Incoming[numpnts(Incoming)]={Synapse[m]*(CNQX+1)}
			endfor
		endfor
		extract /o Incoming,$"Incoming",Incoming>0
		extract /o Outgoing,$"Outgoing",Outgoing>0
		if(numpnts(Incoming)>1)
			meanIncoming[connID]={mean(Incoming,1,numpnts(meanIncoming)-1)}
		endif
		if(numpnts(Outgoing)>1)
			meanOutgoing[connID]={mean(Outgoing,1,numpnts(meanOutgoing)-1)}
		endif
	endfor
	root()
	meanIncoming=log(meanIncoming)//meanIncoming,numtype(meanIncoming)==0
	meanOutgoing=log(meanOutgoing)//extract /o meanOutgoing,meanOutgoing,numtype(meanOutgoing)==0
	SQLDisconnekt()
End

Function EvokedVsMinis()
	root()
	variable i,j,count=0
	make /o EvokedVsMinisData
	for(i=0;i<CountObjectsDFR(root:,4);i+=1)
		string file_name=GetIndexedObjNameDFR(root:,4,i)
		if(!stringmatch(file_name,"*200*"))
			continue
		endif
		dfref df=root:$file_name
		string channels="R1;L2"
		for(j=0;j<itemsinlist(channels);j+=1)
			string channel=stringfromlist(j,channels)
			dfref df1=df:$channel
			if(!datafolderrefstatus(df1))
				continue
			endif
			wave /z/sdfr=df1 Sizes,Incoming,Outgoing
			nvar /z/sdfr=df1 totalMinis,totalDuration,totalFreq
			if(waveexists(Sizes) && (waveexists(Incoming) || waveexists(Outgoing)))
				redimension /n=(count+1,4) EvokedVsMinisData
				EvokedVsMinisData[count][0]=mean(Sizes)
				EvokedVsMinisData[count][1]=totalFreq
				EvokedVsMinisData[count][2]=mean(Incoming)
				EvokedVsMinisData[count][3]=mean(Outgoing) 	
				count+=1
			endif
		endfor
	endfor
End

Function PlasticityVsReverberation(time_point,parameter)
	String time_point,parameter
	root()
	SQLConnekt("Reverb")
	String sql_cmd="SELECT A1.DIV,A3.Transition,A3.Reverberation,A1.Drug_Incubated,A2.* FROM Island_Record A1, Mini_Sweeps A2, Transitions A3 "
	sql_cmd+="WHERE A1.File_Name=A2.File_Name AND A2.File_Name=A3.File_Name AND A1.File_Name=A3.File_Name"
	SQLc(sql_cmd)
	// Get all the data from Mini_Sweeps and info about whether it was a TTX incubated or a control experiment.  
	Wave /T File_Name,Baseline_Sweeps,Post_Activity_Sweeps,Intervening_Drugs,Drug_Incubated
	Wave Reverberation,Transition
	Variable i,j,k
	String channels="R1;L2"
	String time_points="early;late"
	String conditions="ctl;ttx"
	if(StringMatch(time_point,"early"))
		Variable tp=1
	elseif(StringMatch(time_point,"late"))
		tp=2
	endif
	SQLDisconnekt()
	NewDataFolder /O/S root:$(time_point+"_"+parameter+"2")
	Make /o/n=0 Reverb=NaN,Trans=NaN,Plasticity=NaN
	Make /o/T/n=0 Source 
	root()
	Display /K=1 /N=$(time_point+"_"+parameter)
	for(i=0;i<numpnts(File_Name);i+=1)
		String file=File_Name[i]  
		String condition=Drug_Incubated[i]
		for(j=0;j<ItemsInList(channels);j+=1)
			String channel=StringFromList(j,channels)
			SetDataFolder root:$(file):$channel
			Condition2Color(condition); NVar red,green,blue
			InsertPoints 0,1,Reverb,Trans,Plasticity,Source
			Source[0]=file+"_"+channel
			Reverb[0]=Reverberation[i]
			Trans[0]=Transition[i]
			Wave Stat=$parameter
			Duplicate /o Stat :Normed; Wave Normed
			Normed/=Stat[0]
			Plasticity[0]=Normed[tp]
			KillVariables /Z red,green,blue
		endfor
	endfor
	AppendToGraph /c=(65535,0,0) Plasticity vs Reverb
	AppendToGraph /T=top_axis /c=(0,0,65535) Plasticity vs Trans
	BigDots()
	root()
End

Function PlotAllMiniPlasticity(time_point,parameter)
	String time_point,parameter
	root()
	SQLConnekt("Reverb")
	String sql_cmd="SELECT A1.DIV,A1.Drug_Incubated,A2.* FROM Island_Record A1, Mini_Sweeps A2, Transitions A3 WHERE A1.File_Name=A2.File_Name"
	SQLc(sql_cmd)
	// Get all the data from Mini_Sweeps and info about whether it was a TTX incubated or a control experiment.  
	Wave /T File_Name,Baseline_Sweeps,Post_Activity_Sweeps,Intervening_Drugs,Drug_Incubated
	Variable i,j,k
	String channels="R1;L2"
	String used_drugs=";None;AP5;MPEP,LY367385;Wortmannin;TNP-ATP;MPEP"
	String time_points="early;late"
	String conditions="ctl;ttx"
	if(StringMatch(time_point,"early"))
		Variable tp=1
	elseif(StringMatch(time_point,"late"))
		tp=2
	endif
	SQLDisconnekt()
	NewDataFolder /O/S root:$(time_point+"_"+parameter)
	Make /o/n=0 XAxis=NaN,YAxis=NaN
	Make /o/T/n=0 Source 
	Make /o/T/n=(ItemsInList(used_drugs)) XAxisLabels=StringFromList(p,used_drugs)
	Make /o/n=(ItemsInList(used_drugs)) XAxisValues=p
	Wave XAxis,YAxis,XAxisValues; Wave /T Source,XAxisLabels
	root()
//	for(i=0;i<ItemsInList(used_drugs);i+=1)
//		String drug=CleanupName(StringFromList(i,used_drugs),0)
//		//Display /K=1/N=$("Sizes_"+drug)
//		//Display /K=1/N=$("Frequencies_"+drug)
//	endfor
//	
//	for(i=0;i<ItemsInList(time_points);i+=1)
//		String time_point=StringFromList(i,time_points)
//		for(j=0;j<ItemsInList(conditions);j+=1)
//			String condition=StringFromList(j,conditions)
//			Make /o/n=0 $(time_point+"_"+condition)
//			Make /o/T/n=0 $(time_point+"_"+condition+"_Labels")
//		endfor
//	endfor
	
	Display /K=1 /N=$(time_point+"_"+parameter)
	for(i=0;i<numpnts(File_Name);i+=1)
		String file=File_Name[i]
		String drugs=Intervening_Drugs[i]
		String drug1=StringFromList(0,drugs); // Drug list during the first period of activity.  
		drug1=SelectString(StringMatch(drug1,"[Null]"),drug1,"None")
		String drug2=StringFromList(1,drugs); // Drug list during the second period of activity (if there was one).
		drug2=SelectString(StringMatch(drug1,"[Null]"),drug2,"None")  
		String condition=Drug_Incubated[i]
		// Identify which graph this case should be on (which of 'used_drugs' was present during the activity period.  
//		for(j=0;j<ItemsInList(used_drugs);j+=1)
//			drug=StringFromList(j,used_drugs)
//			if(WhichListItem(drug, drug1, ",")>=0)
//				break
//			else
//				drug=""
//			endif
//		endfor
		
		//if(StringMatch(drug,"AP5"))
			//drug=CleanupName("",0) // Regardless of the drug, just append it to the graph corresponding to no drug.  
			for(j=0;j<ItemsInList(channels);j+=1)
				String channel=StringFromList(j,channels)
				SetDataFolder root:$(file):$channel
				//Wave MeanSize,MedianSize,Frequency
				Condition2Color(condition); NVar red,green,blue
				//AppendToGraph /c=(red,green,blue) MeanSize_norm
				//Tag /F=0 $TopTrace(),1,"\Z07"+drug1
				//Tag /F=0 $TopTrace(),3,"\Z07"+drug2
				InsertPoints 0,1,XAxis,YAxis,Source
				Variable item=WhichListItem(drug1,used_drugs)
				if(item==6)
					item=3
				endif
				if(StringMatch(condition,"CTL"))
					item=0
				endif
				Source[0]=file+"_"+channel
				XAxis[0]=item
				Wave Stat=$parameter
				Duplicate /o Stat :Normed; Wave Normed
				Normed/=Stat[0]
				YAxis[0]=Normed[tp]
				if(item==1 && YAxis[0]>0.8)
					//printf file,channel,Normed[2],"\r"
				endif
				//AppendToGraph /W=$("Sizes_"+drug) /c=(red,green,blue) MedianSize
				//AppendToGraph /W=$("Frequencies_"+drug) /c=(red,green,blue) Frequency
				KillVariables /Z red,green,blue
//				for(k=0;k<ItemsInList(time_points);k+=1)
//					time_point=StringFromList(k,time_points)
//					Wave TimePoint=root:$(time_point+"_"+condition)
//					Wave /T Labels=root:$(time_point+"_"+condition+"_Labels")
//					InsertPoints 0,1,TimePoint,Labels
//					TimePoint[0]=MedianSize[1+k]/MedianSize[0]//Frequency[1+k]/Frequency[0]
//					Labels[0]=file+"_"+channel
//				endfor
				//if(numtype(Frequency[0])==0 && numtype(Frequency[1])==0)
				//	z+=1
				//endif
			endfor
		//endif
	endfor
	AppendToGraph YAxis vs XAxis
	ModifyGraph userticks(bottom)={XAxisValues,XAxisLabels}
	BigDots()
	root()
End

// Computes the non-stationary mean and variance using the method in the Noceti paper on the traces in the top graph.  
// Looks up info about the traces in MiniNames.  
Function Noceti(channel)
	String channel
	//AverageMinis(channel,peak_scale=0)
	String traces=TraceNameList("",";",3)
	traces=RemoveFromList2("*_Matrix_Mean",traces)
	String top_trace=StringFromList(0,traces)
	Wave TopMini=TraceNameToWaveRef("",top_trace)
	Variable points=numpnts(TopMini)
	Wave /T MiniNames=$("root:Minis:"+channel+":MiniNames")
	Wave Event_Size=$("root:Minis:"+channel+":Event_Size")
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S $("root:Minis:"+channel+":Noceti")
	Make /o/n=(ItemsInList(traces),points) NocetiMatrix
	Make /o/n=(ItemsInList(traces)) TraceAmplitudes
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		String mini_name=StringFromList(i,traces)
		FindValue /TEXT=mini_name MiniNames; Variable index=V_Value
		if(index>=0) // This should always be the case unless there are extra traces plotted on the graph.  
			Wave Mini=$("root:Minis:"+channel+":Minis:"+mini_name)
			TraceAmplitudes[i]=Event_Size[index]
			NocetiMatrix[i][]=Mini[q]
		endif
	endfor
	Make /o/n=(points) NocetiMean,NocetiVariance
	for(i=0;i<points;i+=1)
		Duplicate /o/R=[][i] NocetiMatrix $"NocetiColumn"; Wave NocetiColumn
		Sort TraceAmplitudes,NocetiColumn
		Differentiate /METH=1 NocetiColumn /D=NocetiDiff
		NocetiDiff/=2
		Redimension /n=(numpnts(NocetiDiff)-1) NocetiDiff
		WaveStats /Q NocetiColumn
		Variable meann=V_avg
		NocetiMean[i]=meann
		//NocetiDiff/=meann
		WaveStats /Q NocetiDiff
		NocetiVariance[i]=V_sdev^2
	endfor
	SetScale /P x,dimoffset(TopMini,0),dimdelta(TopMini,0),NocetiMean,NocetiVariance
	Display /K=1 NocetiVariance[66,198] vs NocetiMean[66,198]
	//Display /K=1 NocetiVariance vs NocetiMean
	ModifyGraph mode=2, lsize=3
	//Edit /K=1 NocetiMean,NocetiVariance
	Wave NocetiMean,NocetiVariance
	ModifyGraph rgb($TopTrace())=(0,0,0)
	SetDataFolder $curr_folder
	//Edit /K=1 NocetiMatrix
End

// Doesn't assume anything about where the traces came from.  
Function NocetiTraces([TraceAmplitudes,left,right])
	Wave TraceAmplitudes // A wave of amplitudes of the traces.  
	Variable left // The left-most point to plot.  
	Variable right // The right-most point to plot.  
	String traces=TraceNameList("",";",3)
	traces=RemoveFromList2("*_Matrix_Mean",traces)
	String top_trace=StringFromList(0,traces)
	Wave TopMini=TraceNameToWaveRef("",top_trace)
	left=ParamIsDefault(left) ? leftx(TopMini) : left
	right=ParamIsDefault(right) ? rightx(TopMini): right
	Variable points=numpnts(TopMini)
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:Noceti
	Make /o/n=(ItemsInList(traces),points) NocetiMatrix
	Variable i
	if(ParamIsDefault(TraceAmplitudes))
		Make /o/n=(ItemsInList(traces)) TraceAmplitudes
		for(i=0;i<ItemsInList(traces);i+=1)
			String trace_name=StringFromList(i,traces)
			Wave TraceWave=TraceNameToWaveRef("",trace_name)
			WaveStats /Q/M=1 TraceWave
			TraceAmplitudes[i]=V_max//-V_min
		endfor
	endif
	for(i=0;i<ItemsInList(traces);i+=1)
		trace_name=StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef("",trace_name)
		NocetiMatrix[i][]=TraceWave[q]
	endfor
	Make /o/n=(points) NocetiMean,NocetiVariance
	Duplicate /o/R=[][0] NocetiMatrix NocetiMasterColumn
	for(i=0;i<points;i+=1)
		Duplicate /o/R=[][i] NocetiMatrix $"NocetiColumn"; Wave NocetiColumn
		Sort TraceAmplitudes,NocetiColumn
		//Sort NocetiMasterColumn,NocetiColumn
		//Sort NocetiColumn,NocetiColumn
		Differentiate /METH=1 NocetiColumn /D=NocetiDiff
		Redimension /n=(numpnts(NocetiDiff)-1) NocetiDiff
		WaveStats /Q NocetiColumn
		Variable meann=V_avg
		NocetiMean[i]=meann
		//NocetiDiff/=meann
		WaveStats /Q NocetiDiff
		NocetiVariance[i]=(V_sdev^2)/2
	endfor
	SetScale /P x,dimoffset(TopMini,0),dimdelta(TopMini,0),NocetiMean,NocetiVariance
	Variable x1=x2pnt(TopMini,left)
	Variable x2=x2pnt(TopMini,right)
	Display /K=1 NocetiVariance[x1,x2] vs NocetiMean[x1,x2]
	ModifyGraph mode=2, lsize=3
	ModifyGraph rgb($TopTrace())=(0,0,0)
	SetDataFolder $curr_folder
	//Edit /K=1 NocetiMatrix
End
#endif

