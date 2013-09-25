// $URL: svn://raptor.cnbc.cmu.edu/rick/recording-artist/Recording%20Artist/IgorExchange/Neuralynx/Neuralynx%20Analysis.ipf $
// $Author: rick $
// $Rev: 632 $
// $Date: 2013-03-15 17:17:39 -0700 (Fri, 15 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma moduleName=NlxB
#if 1
strconstant NeuralynxDataBaseDir="~/Desktop"
strconstant NTT_NAMES="TT*;"
strconstant NTT_WAVES="Data;Times;Clusters;Features"

// --------------------------------------------------------------------------------------------------------------

// Concatenate data loaded from multiple Cheetah files which are from consecutive recording sessions
// (i.e. multiple disk folders in the CheetahData folder).  They must be loaded into Igor first, and into 
// separate folders.  For example, if folder A contained tetrode and event subfolders from one session, 
// and folder B contained subfolders from another session, you would call ConcatSessions({A,B}).  
// NOTE: This only works if Cheetah was not shut down between the sessions.  Otherwise, the Cheetah clock resets.  

Function ConcatSessions(sessions[,target])
	wave /df sessions
	string target // Folder in which to put the concatenated sessions.  
	
	target=selectstring(paramisdefault(target),target,"root:Concat")
	
	variable i,j
	dfref session=sessions[0]
	string folders=core#dir2("folders",df=session)
	for(j=0;j<itemsinlist(folders);j+=1)
		string folder=stringfromlist(j,folders)
		dfref df=session:$folder
		string type=Nlx#DataType(df)
		if(!strlen(type))
			continue
		endif
		make /df/free/n=0 dfs
		for(i=0;i<numpnts(sessions);i+=1)
			dfref session=sessions[i]
			dfref df=session:$folder
			if(datafolderrefstatus(df))
				dfs[i]={df}
			endif
		endfor
		
		string target_ = removeending(target,":")+folder
		ConcatData(type,dfs,target_)
	endfor
End

// Concatenate consecutive recording sessions for a set of data folders, e.g. all the "Events" folders for each session.  
// For example, ConcatData("nev",{root:session1:Events,root:session2:Events},"root:allSessions").  
// NOTE: This only works if Cheetah was not shut down between the sessions.  Otherwise, the Cheetah clock resets.  
Function ConcatData(type,dfs,target)
	string type
	wave /df dfs
	string target
	
	newdatafolder /o $target
	dfref dest = $target
	variable i,j
	for(i=0;i<numpnts(dfs);i+=1)
		dfref source=dfs[i]
		//string name=getdatafolder(0,source)
		//string destStr=name
		//newdatafolder /o targetDF:$name
		//dfref dest=targetDF:$name
		wave /sdfr=source times
		string waves=wavelist2(df=source)
		for(j=0;j<itemsinlist(waves);j+=1)
			string wave_name=stringfromlist(j,waves)
			wave w=source:$wave_name
			print getwavesdatafolder(w,2)
			if(dimsize(w,0) == dimsize(times,0))
				if(stringmatch(nameofwave(w),"times"))
					concatenate /d/np {w},dest:$wave_name
				else
					concatenate /np {w},dest:$wave_name
				endif
			endif
			if(stringmatch(type,"ntt") & stringmatch(wave_name,"data"))
				concatenate /np=1/w {w},dest:$wave_name
			endif
		endfor
		strswitch(type)
			case "ntt":
				
				break
			case "ncs":
				
				break
			case "nev":
				break
			default:
				Post_("The type "+type+" can't be concatenated.")
					return -1
				break
		endswitch
		string /g dest:type=type
	endfor
End

// ---------------------------------- Simple spike viewer for single electrode data. -----------------------------------------------
Function DisplayAllSpikes(Spikes)
	Wave Spikes
	
	Display /K=1
	Variable i
	for(i=0;i<min(1000,dimsize(Spikes,1));i+=1)
		AppendToGraph /c=(0,0,0) Spikes[][i]
	endfor
	Make /o/n=(i) SpikeTraceMap=p
	ControlBar /T 30
	SetVariable SpikeNum value=_NUM:0, proc=DisplayAllSpikesSetVariables, userData(previousValue)="0"
	Button Reject, proc=DisplayAllSpikesButtons, title="Reject"
	Make /o/n=(i) BadSpikes=0
	SetWindow kwTopWin hook(clickHook)=DisplayAllSpikesHook, userData(numSpikes)=num2str(i)
End

Function DisplayAllSpikesSetVariables(info)
	Struct WMSetVariableAction &info
	if(info.eventCode<0)
		return 0
	endif
	strswitch(info.ctrlName)
		case "SpikeNum":
			Variable spikeNum=info.dval
			String traces=TraceNameList("",";",1)
			String traceStem=StringFromList(0,traces)
			Variable numTraces=ItemsInList(traces)
			String spikeTrace=traceStem+"#"+num2str(spikeNum)
			String previousSpikeTrace=traceStem+"#"+GetUserData("","SpikeNum","previousValue")
			String lastTrace=traceStem+"#"+num2str(numTraces-1)
			ModifyGraph rgb($lastTrace)=(0,0,0)
			if(!StringMatch(lastTrace,spikeTrace))
				ReorderTraces $lastTrace, {$lastTrace,$spikeTrace}
			endif
			ModifyGraph rgb($lastTrace)=(65535,0,0)
			SetVariable SpikeNum userData(previousValue)=num2str(spikeNum)
			break
	endswitch
End

Function DisplayAllSpikesButtons(info)
	Struct WMButtonAction &info
	if(info.eventCode!=2)
		return 0
	endif
	String traces=TraceNameList("",";",1)
	String stem=StringFromList(0,traces)
	String lastTrace=StringFromList(ItemsInList(traces)-1,traces)
	strswitch(info.ctrlName)
		case "Reject":
			ControlInfo SpikeNum; Variable currSpikeNum=V_Value
			ModifyGraph hideTrace($lastTrace)=1
			Wave BadSpikes
			Variable spikeNum=WaveColumnFromTraceName(lastTrace)
			BadSpikes[spikeNum]=1
			break
	endswitch
End

// Removes bad spikes added using the "reject" button.  
Function RemoveBadSpikes(Data,BadSpikes)
	Wave Data,BadSpikes
	Variable i
	for(i=numpnts(BadSpikes)-1;i>=0;i-=1)
		if(BadSpikes[i]==1)
			DeletePoints /M=1 i,1,Data
		endif
	endfor
End

// Hook function for Display all spikes.  
Function DisplayAllSpikesHook(info)
	STRUCT WMWinHookStruct &info
	if(info.eventCode==5) // Mouse up.  
		String traceClicked=StringByKey("TRACE",TraceFromPixel(info.mouseLoc.h,info.mouseLoc.v,""))
		Variable instance
		sscanf traceClicked,"%*[a-zA-Z0-9]#%d",instance
		STRUCT WMSetVariableAction info2
		info2.ctrlName="SpikeNum"
		info2.dval=instance
		SetVariable SpikeNum value=_NUM:instance
		DisplayAllSpikesSetVariables(info2)
	endif
End

Function /S GetNlxPath(message[,path])
	string message
	string path
	
	path=selectstring(paramisdefault(path),path,"NlxPath")
	pathinfo $path
	if(!strlen(S_path))
		newpath /o/q/m=message $path
		pathinfo $path
	endif
	string pathStr=S_path
	return pathstr
End

// ------------------------------

// ---------------------- Begin non-Nlx functions (to put .ibw data into the analysis format used for Nlx files) ------------------------------------ //

// Exports all of the igor data waves as one or more concatenated data waves.  
Function ExportChannelData(channel [,stem,folder,Timestamps,max_piece_size,sayv,kill,hi])
	String channel,stem,folder
	Wave /Z Timestamps
	Variable max_piece_size // In x-scaling units (usually seconds).  Set this if you want to analyze smaller chunks of continuous data.  
	Variable sayv // Save to disk (as .ibw).  
	Variable kill // Kill concatentations when finished (not original data).  
	Variable hi // High-pass the exported data at this cutoff frequency.  
	
	max_piece_size=ParamIsDefault(max_piece_size) ? inf : max_piece_size
	sayv=ParamIsDefault(sayv) ? 1 : sayv
	kill=ParamIsDefault(kill) ? 1 : kill
	if(ParamIsDefault(stem))
		stem="sweep"
	endif
	if(ParamIsDefault(folder))
		folder="root"
	endif
	if(ParamIsDefault(Timestamps))
		Wave Timestamps=root:SweepT
	endif
	
	String curr_folder=GetDataFolder(1)
	SetDataFolder $(folder+":"+channel)
	String data_wave_names=WaveList(stem+"*",";","")
	Variable i,data_num,cumul_data_wave_duration=0, num_data_waves=ItemsInList(data_wave_names),epoch=0,piece=0,last_timestamp=Inf
	String data_wave_list=""
	NewPath /O/C/Q SaveLocation,SpecialDirPath("Desktop",0,0,0)+IgorInfo(1)
	
	for(i=0;i<num_data_waves;i+=1)
		String data_wave_name=StringFromList(i,data_wave_names)
		Wave DataWave=$data_wave_name
		sscanf data_wave_name,stem+"%d",data_num
		Variable timestamp=Timestamps[data_num-1] // e.g. sweep1 has its start time in Timestamps[0].  
		Variable data_wave_duration=dimdelta(DataWave,0)*dimsize(DataWave,0)
		if(data_wave_duration>max_piece_size)
			printf "%s was larger than the maximum piece size.\r",data_wave_name
			return -1
		endif
		if(last_timestamp+data_wave_duration<timestamp) // Non-contiguous recording.  
			ConcatPiece(channel,data_wave_list,epoch,piece,cumul_data_wave_duration-data_wave_duration,last_timestamp,sayv,kill,hi)
			cumul_data_wave_duration=data_wave_duration
			epoch+=1
			piece=0
			data_wave_list=data_wave_name+";" // Start a new list for concatenation.  
			last_timestamp=timestamp
		else // This beginning of this data wave is temporally contiguous with the end of the last.  
			if(cumul_data_wave_duration+data_wave_duration>max_piece_size) // The next concatenation would be too big.  
				ConcatPiece(channel,data_wave_list,epoch,piece,cumul_data_wave_duration,timestamp,sayv,kill,hi) // Make a data wave piece.  
				cumul_data_wave_duration=0
				data_wave_list=""
				piece+=1
				i-=1 // Process this data wave again in the next iteration of the loop.  
			else
				cumul_data_wave_duration+=data_wave_duration
				last_timestamp=timestamp
				data_wave_list+=data_wave_name+";" // Add this data wave to the list for concatenation.  
			endif
		endif
	endfor
	if(cumul_data_wave_duration>0)
		ConcatPiece(channel,data_wave_list,epoch,piece,cumul_data_wave_duration-data_wave_duration,timestamp,sayv,kill,hi)
	endif
	
	SetDataFolder $curr_folder
End

// Concatenates pieces of data.  
Function /wave ConcatPiece(channel,wave_list,epoch,piece,cumul_duration,timestamp,sayv,kill,hi)
	String channel,wave_list
	Variable epoch,piece,cumul_duration,timestamp,sayv,kill,hi
	String concat_name=channel+num2str(epoch)+"_"+num2str(piece)
	Concatenate /O/NP wave_list, $concat_name; Wave Concat=$concat_name
	if(hi>0)
		Variable offset=Concat[0]
		Concat-=offset // Must do this to prevent filtering from producing a ringing transient.  
		FilterIIR /HI=(hi) Concat
		Concat+=offset
		Note Concat, "FilterIIR="+num2str(hi/dimdelta(Concat,0))
	endif
	Note Concat, "Timestamp="+num2str(timestamp-cumul_duration)
	if(sayv)
		Save /P=SaveLocation Concat as concat_name+".ibw"
	endif
	if(kill)
		KillWaves /Z Concat
	else
		return Concat
	endif
End

// Extract only the parts of the data that contains the spikes.  Used on continuous data to extract peri-spike segments.   
Function ExtractChannelSpikes(channel,threshold[,polarity,epoch,winLeft,winRight])
	String channel
	Variable threshold,polarity,epoch,winLeft,winRight // polarity is 0 for up, 1 for down.  
	
	winLeft=ParamIsDefault(winLeft) ? 0.0003 : winLeft
	winRight=ParamIsDefault(winRight) ? 0.0012 : winRight
	
	String epochStr=SelectString(ParamIsDefault(epoch),num2str(epoch)+"*","*")
	String dataPieceNames=WaveList(channel+epochStr,";","")
	Variable i
	for(i=0;i<ItemsInList(dataPieceNames);i+=1)
		String dataPieceName=StringFromList(i,dataPieceNames)
		Wave DataPiece=$dataPieceName
		ExtractPieceSpikes(DataPiece,threshold,polarity,winLeft,winRight)
	endfor
End

// Auxiliary function for ExtractChannelSpikes, used on one piece of the data recorded on a channel.  
Function ExtractPieceSpikes(DataPiece,threshold,polarity,winLeft,winRight)
	Wave DataPiece
	Variable threshold,polarity,winLeft,winRight
	Variable epoch
	sscanf NameOfWave(DataPiece),"%*[A-Za-z]%d", epoch
	String spikesName,spikeTimesName
	sprintf spikesName "Spikes%d", epoch
	sprintf spikeTimesName "Spikes%d_t", epoch
	
	Make /o/n=0 $spikeTimesName
	FindLevels /EDGE=(polarity+1) /D=$spikeTimesName DataPiece, threshold
	Wave SpikeTimes=$spikeTimesName
	
	Variable i
	Variable rows=(winLeft+winRight)/dimdelta(DataPiece,0)
	Variable cols=numpnts(SpikeTimes)
	
	Make /o/n=(rows,cols) $spikesName; Wave Spikes=$spikesName
	for(i=0;i<cols;i+=1)
		Variable spikeTime=SpikeTimes[i]
		Variable startPoint=x2pnt(DataPiece,spikeTime-winLeft)
		Spikes[][i]=DataPiece[startPoint+p]
	endfor
End

// Delete spikes that are likely shadows of other spikes (ISI < 750 microseconds).  
Function DeleteShadowSpikes(SpikeWave,TimeWave)
	Wave SpikeWave,TimeWave
	Variable i=1
	Do
		if(TimeWave[i+1]-TimeWave[i]<750)
			DeletePoints i,1,TimeWave
			DeletePoints /M=1 i,1,SpikeWave
		else
			i+=1
		endif
	While(i<dimsize(SpikeWave,1))
End

// OBSOLETE.  
//Function DisplayNlxPSTH2(NlxPSTH[,ErrLow,ErrHigh])
//	Wave NlxPSTH
//	Wave ErrLow,ErrHigh
//	
//	if(ParamIsDefault(ErrLow))
//		Wave ErrLow=$(GetWavesDataFolder(NlxPSTH,2)+"_Low")
//	endif
//	if(ParamIsDefault(ErrHigh))
//		Wave ErrHigh=$(GetWavesDataFolder(NlxPSTH,2)+"_High")
//	endif
//	
//	Display /K=1 /W=(0,0,500,800)
//	
//	Variable i,numEventTypes=max(1,dimsize(NlxPSTH,2))
//	for(i=0;i<numEventTypes;i+=1)
//		Variable unit=i
//		String axisName="axis_"+num2str(unit)
//		AppendToGraph /L=$axisName ErrLow[][0][unit]
//		String last=TopTrace()
//		ModifyGraph mode($last)=7, toMode($last)=1, hbFill($last)=4
//		AppendToGraph /L=$axisName NlxPSTH[][0][unit]
//		last=TopTrace()
//		ModifyGraph mode($last)=7, toMode($last)=1, hbFill($last)=4, lsize($last)=2
//		AppendToGraph /L=$axisName ErrHigh[][0][unit]
//		ModifyGraph /Z axisEnab($axisName)={i/numEventTypes+min(0.01,1/numEventTypes),(i+1)/numEventTypes-min(0.01,1/numEventTypes)}, freePos($axisName)={0.05,kwFraction}
//		ImageStats /Q/G={0,dimsize(NlxPSTH,0)-1,unit,unit} NlxPSTH
//		SetAxis /Z $axisName, 0, V_max*1.5
//		//SetAxis $axisName 0.001,10
//		//ModifyGraph log($axisName)=1
//		Label $axisName, "Unit "+num2str(unit)
//		ModifyGraph lblPos($axisName)=20, lblPosMode($axisName)=1
//	endfor
//	Label bottom "Time (s)"
//	ModifyGraph axisEnab(bottom)={0.05,1}, zero(bottom)=2, offset={0.5*dimdelta($last,0),0}
//	KillWaves /Z TempActiveUnits
//End

// Compute CSC Epochs (based on timing of CSC wave) from Event Epochs (based on timing of Events wave).  
// Note: this changes the underlying data and times for the CSC.  
static function /WAVE CSCEpochs(df,epochs)
	dfref df // Folder containing CSC data.  
	wave Epochs // Usually root:Events:Events_ep.  
	
	wave /sdfr=df data,times
	duplicate /o Epochs,df:Epochs /wave=CSCEpochs
	variable i
	for(i=0;i<numpnts(epochs);i+=1)
		if(epochs[i]<Times[0])
			CSCEpochs[i]=0
		elseif(epochs[i]>Times[numpnts(Times)-1])
			CSCEpochs[i]=1
		else
			findlevel /q/p Times,epochs[i]
			CSCEpochs[i]=v_levelx/numpnts(Times)
			variable firstPoint=ceil(v_levelx)
			insertpoints firstPoint,1,data,times
			data[firstPoint]=nan
			times[firstPoint]=nan
		endif
	endfor
	CSCEpochs=leftx(CSC)+(rightx(CSC)-leftx(CSC))*CSCEpochs
	
	return CSCEpochs	
End

// Uses a continuously recorded Neuralynx wave to search for e.g. stimulus artifacts that could indicate stimulus times in the absence of a proper time series.  
static function StimEpochs2(ContinuousWave,threshold)
	Wave ContinuousWave // A continuous recording that will have stimulus artifacts that can be identified by a level crossing.  
	Variable threshold // The level crossing.  
	
	Variable expectedInterval=20
	Variable tolerance=0.5
	Variable minInterval=expectedInterval-tolerance
	
	FindLevels /Q /M=(minInterval) /EDGE=1 ContinuousWave,threshold
	Wave W_FindLevels
	Variable i,epochNum=0
	for(i=0;i<numpnts(W_FindLevels);i+=1)
		if(abs(W_FindLevels[i]-W_FindLevels[i-1]-expectedInterval)>tolerance)
			Make /o/n=0 $("Epoch"+num2str(epochNum)) /WAVE=Epoch
			epochNum+=1
		endif
		Epoch[numpnts(Epoch)]={W_FindLevels[i]}
	endfor
	KillWaves /Z W_FindLevels
End

static function ChopIgorData(df,guideDF)
	dfref df // A folder containing Igor sweeps.  
	dfref guideDF // A folder containing Neuralynx Data that has already been chopped.  This will be used to make sure the chopped data matches in time.  
	
	if(!exists("root:IgorT"))
		IgorTimes()
	endif
	wave /sdfr=root: IgorT
	
	variable i,j
	string epochs=core#Dir2("folders",df=guideDF)
	variable numEpochs=itemsinlist(epochs)
	
	for(i=0;i<numEpochs;i+=1)
		Prog("Epochs",i,numEpochs)
		string epoch=stringfromlist(i,epochs)
		if(!grepstring(epoch,"E[0-9]+")) // Not an epoch.  
			continue
		endif
		dfref epochDF=guideDF:$epoch
		wave /sdfr=epochDF Times,GuideData=data
		variable start=BinarySearch(IgorT,Times[0]) // The index of the last sweep that started before the beginning of the epoch.  
		variable finish=BinarySearch(IgorT,Times[inf]) // The index of the last sweep preceding the beginning of the next epoch (presumably the last sweep of this epoch).  
		if(start==-2) // Beyond the range of IgorT.  
			start=numpnts(IgorT)-1
		endif  
		if(finish==-2) // Beyond the range of IgorT.  
			finish=numpnts(IgorT)-1
		endif  
		wave sweep=df:$("sweep"+num2str(start))
		if(start>finish)
			continue
		endif
		newdatafolder /o df:$("E"+num2str(i))
		dfref newDF=df:$("E"+num2str(i))
		string /g newDF:type="igor"
		
		// Create a wave which will hold the concatenated sweeps.  
		make /o/n=(numpnts(Times)) newDF:data /wave=Data=0 // Not NaN because bad things happen if I leave NaNs here.  
		variable sourceSampling=Times[1]-Times[0]
		//setscale x,Times[0],Times[inf],Data
		//printf "%f %f\r ",leftx(Data),rightx(Data)
		setscale /p x,Times[0],sourceSampling,Data
		//printf "%f %f\r ",leftx(Data),rightx(Data)
		//copyscales Data,GuideData
		//printf "%f %f\r ",leftx(Data),rightx(Data)
		for(j=start;j<=finish;j+=1)
			//ProgWin((j-start)/(finish-start),1)
			wave sweep_=df:$("sweep"+num2str(j))
			duplicate /o/free sweep_ sweep
			resample /RATE=(1/sourceSampling) sweep
			variable points=dimsize(sweep,0)
			variable sweepDuration=points*dimdelta(sweep,0) // In seconds.  
			variable startIndex=BinarySearch(Times,IgorT[j])
			//printf startIndex,IgorT[j],Times[0],Times[inf],sweepDuration
			if(startIndex==-1) // Sweep starts before reference time.  
				if(IgorT[j]+sweepDuration<Times[0]) // Sweep ends before reference start time.  
					continue
				else // Sweep starts (but does not end) before reference start time.  
					variable endIndex=BinarySearch(Times,IgorT[j]+sweepDuration)
					Data[,endIndex]=sweep[p+points-endIndex]
				endif
			elseif(startIndex==-2) // Sweep starts after reference end time.  
				continue
			elseif(IgorT[j]+sweepDuration>Times[inf]) // Sweep starts (but does not end) before reference end time.  
				Data[startIndex,]=sweep[p-startIndex]
			else // Sweep starts and ends inside reference time.  
				endIndex=startIndex+points // Not startIndex+points-1 because this sometimes leaves blanks in the Data wave.  
				Data[startIndex,endIndex]=sweep[p-startIndex]
			endif
		endfor
	endfor
	
End

// ----------- Begin static helper functions ------------------

// Returns index of the the numeric value 'value' or -1 if not found.  
static Function FindValue2(Wav,value)
	Wave Wav
	Variable value
	FindValue /V=(value) Wav
	return V_Value
End

// Returns the name of the top-most trace on a graph.  
static Function /S TopTrace([win,xaxis,yaxis,visible,number])
	String win,xaxis,yaxis
	Variable visible,number
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	Variable i
	for(i=ItemsInList(traces)-1;i>=0;i-=1)
		String trace=StringFromList(i,traces)
		Variable match=1
		String trace_info=TraceInfo(win,trace,0)
		if(!ParamIsDefault(xaxis))
			String traceXAxis=StringByKey("XAXIS",trace_info)
			match*=StringMatch(xaxis,traceXAxis)
		endif
		if(!ParamIsDefault(yaxis))
			String traceYAxis=StringByKey("YAXIS",trace_info)
			match*=StringMatch(yaxis,traceYAxis)
		endif
		if(!ParamIsDefault(visible))
			Variable hidden=str2num(StringByKey("hideTrace(x)",trace_info,"="))
			match*=(visible!=hidden)
		endif
		if(match)
			if(number<=0)
				return trace
			else
				number-=1
			endif
		endif
	endfor
	return ""
End

// Reverses the order of the items in a string list.  
static Function /S ReverseListOrder(list)
	String list
	String new_list=""
	Variable i
	String item
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		new_list=AddListItem(item,new_list)
	endfor
	return new_list
End

// Returns a list after removing duplicate items.  
static Function /S RemoveDuplicates(list)
	String list
	String new_list=""
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		if(WhichListItem(item,new_list)<0)
			new_list+=item+";"
		endif
	endfor
	return new_list
End

// Returns the column of a wave used to plot a given trace.  
static Function WaveColumnFromTraceName(traceName[,win])
	String traceName,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String info=TraceInfo(win,traceName,0)
	String yRange=StringByKey("YRANGE",info)
	Variable column
	sscanf yRange,"[%*[*0-9,]][%d]",column
	return column
End

// ------------------------ Functions for Rick -----------------------------

Function /s NlxParent(name)
	string name
	
	variable items=itemsinlist(name,"_")
	string suffix=stringfromlist(items-1,name,"_")
	if(numtype(str2num(suffix))==0)
		name=removeending(name,"_"+suffix)
	endif
	return name
End

Function NlxChild(name)
	string name
	
	variable items=itemsinlist(name,"_")
	string suffix=stringfromlist(items-1,name,"_")
	return str2num(suffix)
End

// Determines StimulusTimes (one per sweep) in seconds since the start time of the Neuralynx file.  
static function /wave IgorTimes([OffsetVs])
	dfref OffsetVs // Wave of Neuralynx data against which to align stimulus times.  
	
	Wave sweepT=root:sweepT // The Igor wave that stores sweep times (in minutes).    
	string dataname=NameOfWave(Data)
	Duplicate /o sweepT root:IgorT /wave=IgorT
	NVar expStartT=root:status:expStartT // Start time of the Igor experiment, in seconds since 1/1/1904, which is the offset for the sweepT wave.  
	// If we were on daylight savings time then but not now (3600), now but not then (-3600), now and then (0), or not now and not then (0).  
	Variable DSTshift=0//3600*(DST(expStartT)-DST(DateTime))
	String IgorStartTstr=Secs2Time(expStartT+DSTshift,3,3) // A time string containing the time of day (relative to midnight).  
	Variable hours,minutes,secs
	sscanf IgorStartTstr,"%d:%d:%f",hours,minutes,secs  // Get H, M, S since midnight.  
	Variable IgorStartT=3600*hours+60*minutes+secs // Seconds since midnight that t=0 in sweepT represents. 	
	Variable NlxStartT,NlxEndT // variables to be written by reference with...
	Nlx#StartEndTime(NlxStartT,NlxEndT) // ...seconds since midnight that t=0 in the Nlx Data represents.   
	IgorT=(IgorT*60)+IgorStartT-NlxStartT // Set IgorT equal to the time of each sweep relative to t=0 in the Nlx Data.  
	variable IgorStartSweep=-1 // The first Igor sweep after Cheetah data collection began.  
	do
		IgorStartSweep+=1
	while(IgorT[IgorStartSweep]<0)
	//Extract /O IgorT,IgorT,IgorT>0 && IgorT<(NlxEndT-NlxStartT) // Only keep stimuli that occurred after the onset and before the offset of Neuralynx recording.  
	//SetScale /P x,IgorStartSweep,1,IgorT
	if(!paramisdefault(OffsetVs))
		variable offset=NlxEpochOffset(OffsetVs)
		IgorT+=offset
	endif
	return IgorT
End

static function /wave IgorSweeps(eventsDF)
	dfref eventsDF
	
	wave /sdfr=root: IgorT
	if(!waveexists(IgorT))
		wave IgorT=IgorTimes()
	endif
	
	wave /sdfr=eventsDF times
	make /o/n=(numpnts(times)) eventsDF:IgorSweep /wave=IgorSweep=binarysearch(IgorT,times[p])
	IgorSweep=(IgorSweep[p]==-2) ? numpnts(IgorT)-1 : IgorSweep[p]
	return IgorSweep
end

// Returns the offset of Neuralynx times in Data recorded during a particular epoch, relative to Igor times.  
// Uses stimulus times (found in both Igor's stimulus history wave and the Neuralynx event data) to determine the offset.  
Function NlxEpochOffset(df)
	dfref df // An events data folder.  
	
#ifdef Acq
	wave /sdfr=df times,TTL
	extract /free times,NlxStimT,TTL==32768
	
	// Get sweep start times for this epoch.  
	wave IgorT=IgorTimes()
	wavestats /q/m=1 times
	extract /free IgorT,IgorStimT,IgorT>v_min && IgorT<v_max
	
	// Add the stimulation time (relative to the beginning of the sweep) to the IgorStimT wave so that it corresponds to an absolute stimulation time rather than an absolute sweep start time.  
	wave chanHistory=GetChannelHistory("Odor")
	make /free/n=(dimsize(chanHistory,0)) Begin=chanHistory[p][%Begin][0]
	wavestats /q/m=1 begin
	variable stimT=v_max/1000
	printf "Odor pulse began %.2f seconds after sweep onset.\r",stimT
	IgorStimT+=stimT
	
	// Determine the offset between the Nlx stimulation times and the Igor stimulation times that is most commonly observed in this epoch.  
	make /free/n=(numpnts(NlxStimT),numpnts(IgorStimT)) offsets=NlxStimT[p]-IgorStimT[q]
	make /free/n=10000 hist
	setscale x,-5,5,hist
	histogram /b=2 offsets,hist
	smooth 10,hist
	wavestats /q/m=1 hist
	duplicate /o hist,poop
	return v_maxloc
#endif
End

Function /WAVE NlxStimulusTimesByOdor(Data,numOdors)
	Wave Data
	Variable numOdors
	Wave /Z Events=$(GetWavesDataFolder(Data,2)+"_stim")
	if(!WaveExists(Events))
		Wave /Z Events=root:Events:Events_stim
	endif
	if(!WaveExists(Events))
		printf "Extracting stimulation times from data.\r"
		if(exists("root:sweepT"))
			Wave Events=IgorTimes()
		else
			ControlInfo /W=NeuralynxPanel Trig
			Wave Events=$(GetWavesDataFolder(Data,1)+S_Value)
		endif
	endif
	Variable i
	Make /o/n=(ceil(dimsize(Events,0)/numOdors),numOdors) $(GetWavesDataFolder(Events,2)+"_md") /WAVE=Events_MD=NaN
	for(i=0;i<dimsize(Events,0);i+=1)
		Events_MD[floor(i/numOdors)][mod(i,numOdors)]=Events[i] // Not correct since point number is not the same as sweep number.  
	endfor
	return Events_MD
End

// Generate an odor tuning matrix that is numUnits x numOdors.  
Function NlxOdorTuning(NlxPSTH)
	wave NlxPSTH
	
	string name=removeending(getwavesdatafolder(NlxPSTH,2),"psth")+"tun"
	variable numUnits=dimsize(NlxPSTH,1)
	variable numOdors=dimsize(NlxPSTH,2)
	make /o/n=(numUnits,numOdors) $name /wave=Tuning
	variable i,j
	for(i=0;i<numUnits;i+=1)
		for(j=0;j<numOdors;j+=1)
			imagetransform /G=(i) /P=(j) getCol NlxPSTH
			wave psth=W_ExtractedCol
			copyscales NlxPSTH,psth
			Tuning[i][j]=log((1+mean(psth,0.1,1))/(1+mean(psth,-1,-0.1))) // log((1+evoked)/(1+spontaneous))
		endfor
	endfor
	newimage Tuning
	ModifyImage $TopImage() ctab= {-1,1,RedWhiteBlue,1}
	ColorScale
End

Function NlxOdorMovie(df)
	dfref df
	
	wave /z/sdfr=df PETH
	if(!waveexists(PETH))
		NlxA#MakePETHfromPanel(dataDF=df)
		wave /z/sdfr=df PETH
	endif
	string name=getdatafolder(0,df)
	variable numBins=dimsize(PETH,0)
	variable numUnits=dimsize(PETH,1)
	variable numOdors=dimsize(PETH,2)
	variable frameRate=2/numBins // Two times the actual speed.  
	GetNlxPath("")
	NewMovie /O/Z/P=NlxPath /O/L/F=(frameRate) as name+".mov"
	if(v_flag==-1)
		return 0
	endif
	make /free/n=(numBins/5,numUnits,numOdors) baseline=PETH[p][q][r]
	wave meanRates=MeanBeams(baseline,0)
	matrixop /free meanRates=meancols(meanRates^t)
	make /free/n=(numpnts(meanRates)) rateRanks=p
	sort meanRates,rateRanks
	variable i
	for(i=0;i<numBins;i+=1)
		Make /o/n=(numUnits,numOdors) df:frame /wave=frame=sqrt(PETH[i][rateRanks[p]][q])-sqrt(meanRates[rateRanks[p]][q])
		if(i==0)
			Display /K=1///N=MovieFrame
			AppendImage /L=odorsAxis/T=unitsAxis frame
			Label odorsAxis "Odors"
			Label unitsAxis "Units"
			ModifyGraph manTick=0,freepos(odorsAxis)={0.02,kwFraction},freepos(unitsAxis)={0.05,kwFraction},lblPosMode=1,lblMargin(odorsAxis)=1,axisEnab(odorsAxis)={0,0.95}, axisEnab(unitsAxis)={0.02,1},btlen=2
			wavestats /q PETH
			ModifyImage $TopImage() ctab= {0,sqrt(v_max),YellowHot,0}
			MoveWindow 100,100,500,500
		endif
		DoUpdate
		AddMovieFrame
	endfor
	CloseMovie
	//DoWindow /K $WinName(0,1)
	KillWaves /Z frame
	DoWindow /K MovieFrame
End

Function /WAVE UnitCorrelation(df,unit1,unit2[,width,binSize,significance])
	dfref df
	Variable unit1,unit2 // Cluster numbers.  
	Variable width,binSize
	Variable &significance // Input is p-value (e.g. 0.05), which will be overwritten with a degree of correlation which has that p-value.  
	
	width=ParamIsDefault(width) ? 1 : width
	binSize=ParamIsDefault(binSize) ? 0.02 : binSize
	string type=Nlx#DataType(df)
	dfref df1=$NlxA#ExtractClusters(df,num2str(unit1),type=type)
	dfref df2=$NlxA#ExtractClusters(df,num2str(unit2),type=type)
	wave times1=df1:times, times2=df2:times
	if(numpnts(Times1)*numpnts(Times2)==0)
		return NULL
	endif
	wavestats /q/m=1 Times1
	variable count1=V_npnts
	variable rate1=(count1-1)/(V_max-V_min)
	wavestats /q/m=1 Times2
	variable count2=V_npnts
	variable rate2=(count2-1)/(V_max-V_min)
	
	Make /FREE/n=(count1,count2) TempMatrix=Times1[p]-Times2[q]
	variable numBins=ceil(width/binSize)+1
	Make /o/n=(numBins) df:$("Corr_"+num2str(unit1)+"_"+num2str(unit2)) /WAVE=Correlation
	SetScale x,-width/2,width/2,Correlation
	Histogram /B=2 TempMatrix, Correlation
	variable expected=sqrt(count1*binSize*rate2*count2*binSize*rate1)
	Correlation-=expected
	Correlation/=sqrt(count1*count2)
	if(!ParamIsDefault(significance) && significance!=0)
		significance=significance/numBins // Bonferroni correction.  
		variable subdivide=0
		Do
			variable threshold=StatsInvBinomialCDF(1-significance, sqrt(binSize*rate2*binSize*rate1),sqrt(count1*count2)) // Expected count at p-value 'significance'
			binSize/=2
			subdivide+=1
		While(numtype(threshold)) // This loops addresses probabilities (binSize*rate2) greater than 1 by computing a threshold for a shorter bin.  
		threshold*=2^(subdivide-1)
		threshold-=expected
		threshold/=sqrt(count1*count2)
		significance=threshold // Update significance since it was passed by reference.  
	endif
	return Correlation
End

Function /WAVE UnitCorrelations(df,units[,width,binSize,significance])
	dfref df
	string units
	variable width,binSize,significance
	
	width=ParamIsDefault(width) ? 1 : width
	binSize=ParamIsDefault(binSize) ? 0.02 : binSize
	if(!strlen(units))
		wave /sdfr=df Clusters
		units="0-"+num2str(wavemax(Clusters))
	endif
	units=ListExpand(units)
	Display /K=1 /N=NlxUnitCorrelations
	string win=WinName(0,1)
	Variable i,j,numUnits=ItemsInList(units)
	Make /o/n=(numUnits,numUnits,1) df:Corrs /WAVE=Corrs
	
	for(i=0;i<numUnits;i+=1)
		Prog("Units i",i,numUnits)
		string unit1=StringFromList(i,units)
		for(j=0;j<numUnits;j+=1)
			Prog("Units j",j,numUnits)
			string unit2=StringFromList(j,units)
			Variable sig=significance
			Wave /Z Corr=UnitCorrelation(df,str2num(unit1),str2num(unit2),width=width,binSize=binSize,significance=sig)
			Redimension /n=(-1,-1,numpnts(Corr)) Corrs
			SetScale z,-width/2,width/2, Corrs
			Corrs[i][j][]=Corr[r]
			KillWaves /Z Corr
			string corrAxis,timeAxis
			sprintf corrAxis,"corr_%s",unit1
			sprintf timeAxis,"time_%s",unit2
			if(waveexists(Corrs))
				AppendToGraph /L=$corrAxis /B=$timeAxis Corrs[i][j][]
				SetAxis $corrAxis -0.2,1
				ModifyGraph mode=5,nticks($corrAxis)=2,nticks($timeAxis)=2,axOffset($corrAxis)=-4,axOffset($timeAxis)=-1,btLen=1
				ModifyGraph axisEnab($corrAxis)={1-(i+1)/numUnits+0.02,1-i/numUnits-0.02},axisEnab($timeAxis)={j/numUnits+0.02,(j+1)/numUnits-0.02},freepos={0.02,kwFraction}
				if(!numtype(sig))
					SetDrawEnv /W=$win xcoord=$timeAxis, ycoord=$corrAxis, dash=3
					DrawLine /W=$win -width/2,sig,width/2,sig
					DrawLine /W=$win 0,-0.02,0,1
				endif
			endif
		endfor
	endfor
	
	if(numUnits>5)
		ModifyGraph noLabel=1
	endif
End

// Computes the degree of correlation in spike counts, using a time range that spans from the first spike among each pair of units to the last.  
static Function /wave SpikeCountDegC(df,units[,binSize,nonstationary,pvalue,no_show])
	dfref df
	string units // Which units/clusters/neurons to use?  Semicolon-separated, e.g "3-5;7-10".  Use an empty string for all units.  
	variable binSize // Binsize in seconds.  
	variable nonstationary // Use spike count differences from the previous bin (effectively corrects for slow drifts in spike rate).  
	variable pvalue // Compute p-values from shuffling.  
	variable no_show
	
	binSize=ParamIsDefault(binSize) ? 0.1 : binSize
	wave /sdfr=df times,clusters
	if(!strlen(units))
		units="0-"+num2str(wavemax(Clusters))
	endif
	units=ListExpand(units)
	variable i,j,k,numUnits=ItemsInList(units)
	if(numUnits==0)
		return NULL
	endif
	string type=Nlx#DataType(df)
	Make /o/n=(numUnits,numUnits) df:degC /WAVE=DegC=nan, df:degCn /wave=degCn=nan
	if(pvalue)
		//duplicate /o DegC df:degCpVal /wave=degCpVal
		duplicate /o DegC df:degCpFish /wave=degCpFish
	endif
	
	make /free/wave/n=(numUnits) timesN
	for(i=0;i<numUnits;i+=1)
		variable unit=str2num(StringFromList(i,units))
		extract /free times,timesi,clusters[p]==unit
		timesN[i]=timesi
	endfor
	for(i=0;i<numUnits;i+=1)
		Prog("Units i",i,numUnits)
		variable unit1=str2num(StringFromList(i,units))
		wave times1=timesN[i]
		for(j=i+1;j<numUnits;j+=1)
			//Prog("Units j",j,numUnits)
			variable unit2=str2num(StringFromList(j,units))
			wave times2=timesN[j]
			if(min(numpnts(times1),numpnts(times2))<10) // Less than 10 spikes in one of the units.  
				continue
			endif
			if(1)	
				wavestats /q/m=1 Times1
				variable min1=v_min,max1=v_max
				wavestats /q/m=1 Times2
				variable min2=v_min,max2=v_max
				variable minn=min(min1,min2)
				variable maxx=max(max1,max2)
				if(max2-min1 < (max1-min1)/2 || max1-max2 < (max2-max2)/2) // Less then 50 % overlap in range of spike times.  
					continue
				endif
				if(maxx-minn<10*binSize) // Range of spike times doesn't even span 10 bins.  
					continue
				endif
				if(maxx-minn<1) // Range of spike times doesn't even span 1 second.  
					continue
				endif
			else
				//minn = 12952.8
				//maxx = 14003.6
			endif
			Make /free/n=(ceil(maxx-minn)/binSize+1) Raster1=0,Raster2=0
			SetScale x,minn-binSize/2,minn+ceil(maxx-minn)+binSize/2,Raster1,Raster2
			Histogram /B=2 Times1,Raster1
			Histogram /B=2 Times2,Raster2
			variable rasterSize=numpnts(Raster1)
			if(nonstationary)
				differentiate /meth=2 Raster1 /d=dRaster1,Raster2 /d=dRaster2
				deletepoints 0,1,dRaster1,dRaster2
				wave w1=dRaster1,w2=dRaster2
			else
				wave w1=raster1,w2=raster2
			endif
			if(numpnts(w1) && numpnts(w2))
				DegC[i][j]=spikeTrainDegC(w1,w2)
				DegC[j][i]=DegC[i][j]
				DegCn[i][j]=numpnts(w1)
				DegCn[j][i]=DegCn[i][j]
				//MatrixOp /o/FREE degCij=crossCovar(subtractMean(Raster1,0),subtractMean(Raster2,0),1)
				//degCij=degCij[(numpnts(degCij)+1)/2]
				if(pvalue)
					//degCpVal[i][j]=spikeTrainDegCpVal(w1,w2,degC=degC[i][j],iter=100)
					degCpFish[i][j]=spikeTrainDegCpVal(w1,w2,degC=degC[i][j],iter=0)
					degCpFish[j][i]=degCpFish[i][j]
				endif
			endif
		endfor
	endfor
	
	string name=getdatafolder(0,df)
	string fullName=Nlx#DF2FileName(df) 
	string win=cleanupname(name+"_degC",0)
	if(!wintype(win) && !no_show)
		NewImage /K=1/N=$win degC
		DoWindow /T $win fullName+": Degree of Correlation"
		svar /z notes=df:merged
		if(svar_exists(notes))
			ElectrodeSubMatrices(df)
		endif
		ModifyImage $TopImage() ctab= {-1,*,BlueBlackRed,0}
		ColorScale /F=0/B=1 tickLen=2
	endif
	return degC
End

function SpikeCountDegCByBinSize(df,[units,binSizes,nonstationary])
	dfref df
	string units
	wave binSizes
	variable nonstationary
	
	wave /sdfr=df times,clusters
	units = selectstring(!paramisdefault(units),"0-"+num2str(wavemax(clusters)),units)
	units=ListExpand(units)
	variable i,numBinSizes = numpnts(binSizes)
	make /o/n=(numBinSizes) df:degCForBinSize /wave=degCForBinSize=nan
	make /o/n=(numBinSizes) df:degCForBinSize_same /wave=degCForBinSize_same=nan
	make /o/n=(numBinSizes) df:degCForBinSize_diff /wave=degCForBinSize_diff=nan
	for(i=0;i<numBinSizes;i+=1)
		Prog("Bin Size",i,numBinSizes)
		if(1) // Compute.  
			wave degC = NlxB#SpikeCountDegC(df,units,binSize=binSizes[i],nonstationary=nonstationary,no_show=1)
			duplicate /o degC,df:$("degC_"+num2str(i))
		else // Read.  
			wave degC = df:$("degC_"+num2str(i))
		endif
		
		extract /free degC,all,p!=q && p>0 && q>0
		ecdf(all)
		statsquantiles /q all
		degCForBinSize[i] = v_q25//v_median
		
		extract /free degC,same,p!=q && SameElectrode(df,{p,q})==1
		ecdf(same)
		statsquantiles /q same
		degCForBinSize_same[i] = v_q25// v_median
		
		extract /free degC,diff,p!=q && SameElectrode(df,{p,q})==0
		ecdf(diff)
		statsquantiles /q diff
		degCForBinSize_diff[i] = v_q25//v_median
	endfor
end

// Draw lines on a matrix image to indicate which regions correspond to the same vs. different electrodes.  
// Merged data must not include clusters from the original data with zero spikes.  
function ElectrodeSubMatrices(df[,win,hasZero])
	dfref df
	string win
	variable hasZero // (1) if index 0 is the noise cluster.  (0) if index 0 is the first real cluster.  
	
	win=selectstring(!paramisdefault(win),winname(0,1),win)
	//wave clustersWithSpikez=NlxA#ClustersWithSpikes(df,exclude={0})
	svar /z notes=df:merged
	if(svar_exists(notes))
		string sources=StringByKey("sourceElectrodes",notes)
		variable i
		if(strlen(sources))
			for(i=0;i<itemsinlist(sources,",");i+=1)
				string source=stringfromlist(i,sources,",")
				variable boundary=str2num(stringfromlist(1,source,"="))
				boundary-=0.5+!hasZero
				SetDrawEnv xcoord=top, ycoord=prel,linethick=2
				DrawLine boundary,0,boundary,1
				SetDrawEnv xcoord=prel, ycoord=left,linethick=2
				DrawLine 0,boundary,1,boundary
			endfor
		endif
	endif
end

threadsafe static Function SpikeTrainDegC(w1,w2)
	wave w1,w2 // Waves of 1's and 0's representing bins with and without spikes.  
	
	//matrixop /free degC=(subtractMean(w1,0) . subtractMean(w2,0))/sqrt((subtractMean(w1,0) . subtractMean(w1,0))*(subtractMean(w2,0) . subtractMean(w2,0)))
	//return degC[0]
	return statscorrelation(w1,w2)
End

static Function SpikeTrainDegCpVal(w1,w2[,degC,iter])
	wave w1,w2
	variable degC
	variable iter // 0 to use Fisher's transformation to compute p.  Any other number to shuffle data to compute a p-value.  Default is 100.  
	
	if(paramisdefault(degC))
		degC=spikeTrainDegC(w1,w2)
	endif
	if(paramisdefault(iter) || iter>0) // Shuffle.  
		iter=paramisdefault(iter) ? 100 : iter
		make /o/n=(iter) degCshuffled=nan
		multithread degCshuffled=spikeTrainDegCshuffled(w1,w2)
		degCshuffled[iter]={-1}
		degCshuffled[iter+1]={1}
		sort /r degCshuffled,degCshuffled
		variable pp=binarysearch(degCshuffled,degC)/iter
	else // Fisher transformation.  
		if(degC==1)
			pp=0
		elseif(degC==-1)
			pp=1
		else
			pp=FisherP(degC,numpnts(w1))
		endif
	endif
	return pp
end

threadsafe static Function SpikeTrainDegCShuffled(w1,w2)
	wave w1,w2
	
	duplicate /free w2,w2shuffled
	make /free/n=(numpnts(w2)) index=p,random=enoise(1)
	sort random,index
	w2shuffled=w2[index[p]]
	variable degCshuffled=spikeTrainDegC(w1,w2shuffled)
	return degCshuffled
end

static Function DegCHist(degC)
	wave /z degC
	if(!waveexists(degC))
		return -1
	endif
	dfref df=getwavesdatafolderdfr(degC)
	make /free/n=(dimsize(degC,0)) unitTetrode=0
	
	// If these degC is from merged data (across tetrodes), we will want to distinguish between correlations between units within vs. across tetrodes.
	svar /z notes=df:merged
	if(svar_exists(notes))
		string sources=StringByKey("sourceElectrodes",notes)
		if(strlen(sources))
			variable i,lastBoundary=0
			for(i=0;i<itemsinlist(sources,",");i+=1)
				string source=stringfromlist(i,sources,",")
				variable boundary=str2num(stringfromlist(1,source,"="))
				unitTetrode[lastBoundary,boundary-1]=i
				lastBoundary=boundary
			endfor
		endif
	endif
	
	variable bins=100
	make /o/n=(bins) df:degCwithinHist /wave=withinHist
	make /o/n=(bins) df:degCacrossHist /wave=acrossHist
	setscale x,-1,1,withinHist,acrossHist
	extract /o degC,df:degC_within /wave=within,p!=q && unitTetrode[p]==unitTetrode[q] && numtype(degC)==0
	extract /o degC,df:degC_across /wave=across,p!=q && unitTetrode[p]!=unitTetrode[q] && numtype(degC)==0
	//ecdf(within)
	//ecdf(across)
	
	wave /z/sdfr=df degCn
	extract /o degCn,df:degCn_within /wave=withinN,p!=q && unitTetrode[p]==unitTetrode[q] && numtype(degC)==0
	extract /o degCn,df:degCn_across /wave=acrossN,p!=q && unitTetrode[p]!=unitTetrode[q] && numtype(degC)==0
	
	wave /z/sdfr=df degCpVal
	if(waveexists(degCpVal))
		extract /o degCpVal,df:degCpVal_within /wave=withinP,p!=q && unitTetrode[p]==unitTetrode[q] && numtype(degCpVal)==0
		extract /o degCpVal,df:degCpVal_across /wave=acrossP,p!=q && unitTetrode[p]!=unitTetrode[q] && numtype(degCpVal)==0
		//ecdf(withinP)
		//ecdf(acrossP)
	endif
	
	wave /z/sdfr=df degCpFish
	if(waveexists(degCpFish))
		extract /o degCpFish,df:degCpFish_within /wave=withinP,p!=q && unitTetrode[p]==unitTetrode[q] && numtype(degCpFish)==0
		extract /o degCpFish,df:degCpFish_across /wave=acrossP,p!=q && unitTetrode[p]!=unitTetrode[q] && numtype(degCpFish)==0
		//ecdf(withinP)
		//ecdf(acrossP)
	endif
	
	string name=getdatafolder(0,df)
	string fullName=Nlx#DF2FileName(df)
	
	if(numpnts(within)==0)
		return -1
	endif
	histogram /b=2 within,withinHist
	string win=cleanupname(name+"_degCwithin",0)
	if(!wintype(win))
		display /k=1/n=$win withinHist as fullName+": Degree of Correlation within Tetrodes"
		modifygraph mode=5
		label left "Count"; label bottom "R"
	endif
	
	if(stringmatch(name,"*Merged*"))
		histogram /b=2 across,acrossHist
		win=cleanupname(name+"_degCacross",0)
		if(!wintype(win))
			display /k=1/n=$win acrossHist as fullName+": Degree of Correlation across Tetrodes"
			modifygraph mode=5
			label left "Count"; label bottom "R"
		endif
		
		win=cleanupname(name+"_degCcompare",0)
		if(!wintype(win))
			display /k=1/n=$win within,across as fullName+": Degree of Correlation within vs. across"
			modifygraph rgb($nameofwave(within))=(0,0,0), rgb($nameofwave(across))=(65535,0,0), swapXY=1
			label left "Cumulative Probability"
			label bottom "R"
			legend
			setaxis bottom -1,1
			setaxis left 0,1
		endif
	endif
End

Function /wave AllISIs(df)
	dfref df
	
	wave /sdfr=df clusters,times
	wave clusterIndices=NlxA#ClustersWithSpikes(df)
	variable i
	make /free/n=64 hist
	setscale x,-4,4,hist
	make /o/n=(numpnts(hist),numpnts(clusterIndices)) ISIHist=0
	copyscales hist,ISIHist
	for(i=0;i<numpnts(clusterIndices);i+=1)
		variable index=clusterIndices[i]
		extract /free times,times_,clusters==index
		differentiate /meth=2 times_
		deletepoints 0,1,times_ // Delete first spike, where ISI is unknown.  
		times_=log(times_)
		histogram /b=2 times_,hist
		hist/=numpnts(times_)
		ISIHist[][i]=hist[p]
	endfor
	return ISIHist
End

Function /wave SpikeTimingHistogram(df,triggers,spikeIndex[,triggersName,usePhase])
	dfref df // Data folder with unit information.  
	wave /wave triggers // Wave of trigger waves.  For each point in the first trigger wave, compute the 'spikeIndex'th spike occurring after that point.  
	// When there are mutliple trigger waves, this becomes a joint histogram.  Only spikes which are 'spikeIndex'th after times in the first trigger wave will be counted.  
	variable spikeIndex // Indexed from 0.  
	string triggersName
	string usePhase // Use phases of spikes instead of times.  Specifies the name of a phase wave in df.  
	
	triggersName=selectstring(paramisdefault(triggersName),triggersName,nameofwave(triggers))
	
	wave /sdfr=df times
	if(!paramisdefault(usePhase))
		wave spikePhase=df:$usePhase
	endif
	variable i,j
	make /free/n=0 spikeTiming,spikeIndices
	for(j=0;j<numpnts(triggers);j+=1)
		wave trig=triggers[j]
		if(j==0)
			for(i=0;i<numpnts(trig);i+=1)
				variable index=binarysearch(times,trig[i])
				if(index==-2) // This trigger occurred after all spikes.  
					continue
				endif
				variable spikeNum=1+spikeIndex+index
				if(spikeNum<0 || spikeNum>=numpnts(times))
					continue
				endif
				if(paramisdefault(usePhase))
					variable spikeTime=times[spikeNum]-trig[i]
				else
					spikeTime=spikePhase[i]
				endif
				spikeIndices[numpnts(spikeIndices)]={spikeNum}
				spikeTiming[numpnts(spikeTiming)][0]={spikeTime}
			endfor
		else
			redimension /n=(-1,j+1) spikeTiming
			for(i=0;i<dimsize(spikeTiming,0);i+=1)
				index=binarysearch(trig,times[spikeIndices[i]])
				if(index==-1) // This spike occurred before all triggers.  
					spikeTiming[i][j]=nan
					continue
				endif
				spikeTime=times[spikeIndices[i]]-trig[index]
				spikeTiming[i][j]=spikeTime
			endfor
		endif
	endfor
	if(!paramisdefault(usePhase))
		StatsHodgesAjneTest /Q col(spikeTiming,0)
		wave W_HodgesAjne
		printf "The resulting phase histogram has a p-value of %.4f for the null-hypothesis of uniform phase distribution\r",W_HodgesAjne[%P] 
	endif
	make /o/n=0 df:$(triggersName+"_"+num2str(spikeIndex)+"thSpike_"+selectstring(paramisdefault(usePhase),usePhase+"_","")+"Hist") /wave=spikeTimingHist=nan
	make /free/n=(numpnts(triggers)) dims=32
	redim(spikeTimingHist,dims)
	if(paramisdefault(usePhase))
		setscale x,-4,1,spikeTimingHist
		setscale y,-4,1,spikeTimingHist
		setscale z,-4,1,spikeTimingHist
		spikeTiming=log(spikeTiming)
	else
		setscale x,-pi,pi,spikeTimingHist
		setscale y,-pi,pi,spikeTimingHist
		setscale z,-pi,pi,spikeTimingHist
	endif
	switch(numpnts(triggers))
			case 1:
				histogram /b=2 spikeTiming spikeTimingHist
				break
			case 2:
				jointhistogram3(col(spikeTiming,0),col(spikeTiming,1),spikeTimingHist)
				break
		endswitch
	return spikeTimingHist
End

Function PurgeSpikes(df,conditions)
	dfref df
	wave /t conditions
	
	wave /sdfr=df times
	duplicate /free times, purge
	purge=0
	variable i
	for(i=0;i<numpnts(conditions);i+=1)
		string condition=conditions[i]
		string test=stringfromlist(0,condition)
		string param=stringfromlist(1,condition)
		string response=stringfromlist(2,condition)
		strswitch(test)
			case "isi<":
				strswitch(response)
					case "purgeBoth":
						variable num=str2num(param)
						duplicate /free times, sorttimes, index
						index=p
						sort sorttimes,sorttimes,index
						duplicate /free sorttimes, dtimes
						differentiate /meth=1 dtimes
						sort index,index,dtimes
						purge+=(dtimes[p]<num || dtimes[p-1]<num)
						killwaves /z temp
						break
				endswitch
				break
		endswitch
	endfor
	
	for(i=0;i<itemsinlist(NTT_WAVES);i+=1)
		string wave_name=stringfromlist(i,NTT_WAVES)
		wave w=df:$wave_name
		extract /o df:$wave_name,df:$wave_name,purge==0
	endfor
End

Function /WAVE SpikeTriggeredSignal(spDF,sigDF[,range])
	dfref spDF,sigDF // Spikes and Signal data folders.  
	Variable range // Total time window +/- the spike time.  
	
	if(!DataFolderRefStatus(spDF) || !DataFolderRefStatus(sigDF))
		printf "Data folder reference(s) invalid.\r"
		return $""
	endif
	range=paramisdefault(range) ? 0.5 : range
	
	Wave SpikeTimes=spDF:Times
	wave /i/u Clusters=spDF:Clusters
	if(!waveexists(Clusters)) // If there is no 'Clusters' wave.  
		make /free /n=(numpnts(SpikeTimes))/i/u Clusters=0
	endif
	Wave /z SignalData=sigDF:Data, SignalTimes=sigDF:Times 
	if(!waveexists(SignalTimes)) // If there is no 'Times' wave.  
		wave SignalTimes=NlxA#TimesFromData(sigDF)
	endif
	
	Variable signalSampleFreq=1/dimdelta(SignalData,0) // LFP sampling frequency in Hz.  Should be sampleFreq divided by downsampling during loading.  
	Variable numSpikes=numpnts(SpikeTimes)
	string type=stringfromlist(1,getdatafolder(1,sigDF),":") // e.g. CSCA or Respiration.  
	do
		variable points=floor(range*2*signalSampleFreq)
		if(mod(points,2)!=0)
			range*=0.9999
		else
			break
		endif
	while(1) // Want points to be even for future FFTs.  
	Make /o/n=(points,numSpikes) spDF:$("st_"+type) /wave=stm=nan // Spike-triggered matrix.  
	Variable i,j
	for(i=0;i<numSpikes;i+=1)
		Variable spikeTime=SpikeTimes[i]
		Variable signalTimeIndex=BinarySearch(signalTimes,spikeTime) // LFP time index when the spike occurred.  
	
		// Error checking.  
		Variable signalTimeIndexStart=BinarySearch(signalTimes,spikeTime-range) // LFP time index 'range' seconds before that.   
		Variable signalTimeIndexStop=BinarySearch(signalTimes,spikeTime+range) // LFP time index 'range' seconds after that.   
		
		if(signalTimeIndex<0) // If it occurred before or after LFP recording.  
			continue // Skip it.  
		endif
		Variable rangeOffset=range*signalSampleFreq
		if(signalTimeIndexStop-signalTimeIndexStart>(2*rangeOffset+1)) // If the start and end of the range around this spike are from discontinuous recording segments.  
			continue // Skip it.  
		endif
		stm[][i]=SignalData[signalTimeIndex+p-rangeOffset] // The range of the LFP that is cotemporal with the spike.  
	endfor
	SetScale x,-range,range,stm
	matrixop /o stm=subtractmean(stm,1) // Subtract the mean from each column (from each spike-triggered waveform).  
	
	wavestats /q/m=1 clusters
	variable max_cluster = v_max
	variable rows = dimsize(stm,0)
	variable cols = max_cluster+1
	make /o/n=(rows,cols) spDF:$("st_"+type+"_avg") /wave=sta=nan
	make /o/n=(rows,cols) spDF:$("st_"+type+"_sd") /wave=stsd=nan
	make /o/n=(rows,cols) spDF:$("st_"+type+"_sem") /wave=stsem=nan
	for(j=0;j<=max_cluster;j+=1)
		extract /free/indx clusters,indices,clusters[p]==j
		if(numpnts(indices))
			make /free/n=(rows,numpnts(indices)) stm_cluster = stm[p][indices[q]]
			matrixop /free sta_cluster = sumcols(stm_cluster^t)^t/numcols(stm_cluster)
			sta[][j] = sta_cluster[p]
			matrixop /free stsd_cluster=sqrt(varcols(stm_cluster^t)^t)
			stsd[][j] = stsd_cluster[p]
			matrixop /free stsem_cluster=sqrt(varcols(stm_cluster^t)^t/numcols(stm_cluster))
			stsem[][j] = stsem_cluster[p]
		endif
	endfor
	setscale x,-range,range,sta,stsem
	return sta
End

Function /s SpikePhase(df,signalDF[,lo,hi,thresh,phase])
	dfref df
	dfref signalDF // Could be an LFP or a respiratory signal.  
	variable lo,hi // Low and Hi pass filter cutoffs.  
	variable thresh // hard threshold if the simple method is used.   
	wave phase // Optionally provide the phase of the signal at each point instead of recomputing it from the signal.  
	
	thresh=paramisdefault(thresh) ? 0.1 : thresh
	
	wave signal=signalDF:data
	Wave SpikeTimes=df:times
	if(stringmatch(getdatafolder(1,signalDF),"*resp*"))
		string type="rsp"
	else
		type="lfp"
		wave signalTimes=signalDF:times
	endif
	Variable bins=10
	
	// Get a chunk of the LFP recording that spans the spikes.  
	strswitch(type)
		case "lfp":
			Variable minn=BinarySearch(signalTimes,wavemin(SpikeTimes))
			Variable maxx=BinarySearch(signalTimes,wavemax(SpikeTimes))
			Duplicate /free /R=[minn,maxx] Signal, filtered
			SetScale x,signalTimes[minn],signalTimes[maxx],filtered
			break
		case "rsp":
			Duplicate /free Signal, filtered
			break
	endswitch
	
	if(mod(numpnts(filtered),2)!=0)
		DeletePoints 0,1,filtered // Make number of rows even.  
	endif
	
	// Filter it and compute the phase.  
	BandPassFilter(filtered,lo,hi)
	if(paramisdefault(Phase))
		strswitch(type)
			case "lfp": 
				wave Phase=PhaseWavelets(signalDF,1.8,2.5) // Using wavelets (MorletC) to estimate the phase within a given frequency range.   
			break
#if exists("RespiratoryPhaseSimple")
			case "rsp":
				//wave Phase=RespiratoryPhase(filtered) // Use the method in the J. Neurosci. Methods paper.  
				//wave Phase=RespiratoryPhaseSimple(signalDF,lo=lo,hi=hi,minAmpl=thresh) // Use a simple method interpolating between level crossings.  
				//wave Phase=RespiratoryPhaseNew(filtered) // A refined version of the J. Neurosci. Methods paper method.    
				wave Phase=PhaseWavelets(signalDF,1.8,2.5) // Using wavelets (MorletC) to estimate the phase within a given frequency range.     
				break
#endif
		endswitch
	endif
		
	// Get spike phases and make a histogram.   
	Make /o/n=(bins) df:$(type+"_PhaseTuning") /wave=SpikePhaseHist
	Duplicate /o SpikeTimes df:$(type+"_Phases") /wave=SpikePhases, df:$(type+"_Cycles") /wave=Cycles
	findlevels /q Phase,0.001; wave w_findlevels
	Cycles=BinarySearch(w_findlevels,SpikeTimes)
	Cycles=Cycles<0 ? NaN : Cycles
	SpikePhases=Phase(SpikeTimes)
	SpikePhases=SpikeTimes<leftx(Phase) || SpikeTimes>rightx(Phase) ? nan : SpikePhases
	wavestats /q/m=1 spikephases
	if(v_max<=pi && v_min>=-pi)
		setscale x,-pi,pi,SpikePhaseHist
	elseif(v_max<=2*pi && v_min>=0)
		setscale x,0,2*pi,SpikePhaseHist
	else
		printf "Error [SpikePhases]: range of phases was neither -pi to pi nor 0 to 2*pi.\r"  
	endif
	Histogram /B=2 SpikePhases,SpikePhaseHist
	
	SpikePhaseHist/=numpnts(SpikeTimes) // Normalize by number of spikes.  
	//SpikePhaseHist/=(2*pi/bins) // Normalize so histogram integrates to 1.    
	killwaves /z w_findlevels//,phase
	return removeending(getwavesdatafolder(SpikePhaseHist,2),"PhaseTuning") // The prefix of the waves generated in this function.  
End

static Function /wave PhaseCrossings(phase,value,sign_)
	wave phase
	variable value
	string sign_ // "up" or "down" through the crossing value.  
	
	strswitch(sign_)
		case "up":
			variable edge=1
			break
		case "down":
			edge=2
			break
		default:
			edge=0
			break
	endswitch
	variable i
	
	dfref df=getwavesdatafolderdfr(phase)
	make /o/n=0 df:$("crossings_"+replacestring(".",num2str(value),"-")+"_"+sign_) /wave=crossings
	findlevels /q/d=crossings/edge=(edge) phase,value
	if(dimoffset(phase,0)==0 && dimdelta(phase,1)==1) // Use Times wave as time base.  
		printf "Phase wave doesn't have time scaling so using Times wave as a time base.\r"
		wave /sdfr=df times
		crossings=times[crossings[p]]
	endif
	note /nocr crossings "PHASE="+num2str(value)
	return crossings
End

Function SpikePhaseRaster(df,phaseType)
	dfref df
	string phaseType
	
	Wave /sdfr=df Times
	Wave Phases=df:$(phaseType+"_Phases")
	display Times vs Phases
End

Function ISIHistogram(df)
	dfref df
	
	Wave /sdfr=df Times
	duplicate /o Times df:ISI /wave=ISI
	differentiate /meth=1 ISI
	redimension /n=(numpnts(ISI)-1) ISI
	make /o/n=128 df:ISIhist /wave=Hist
	duplicate /free ISI logISI
	logISI=log(ISI)
	setscale x,-3,3,Hist
	histogram /b=2 logISI,hist
	display /k=1 hist
	modifygraph mode=5
	label bottom "ISI (log seconds)"
	label left "Spike Count"
End

// Returns source electrode and unit number on that electrode for merged unit number 'unitNum'
function /s SourceElectrode(df,unitNum)
	dfref df
	variable unitNum
	
	svar /sdfr=df merged
	string sources=StringByKey("sourceClusters",merged)
	string source=stringbykey(num2str(unitNum),sources,"=",",")
	return source
end

// Returns 1 if all of the unit numbers in 'unitNums' come from the same source electrode, 0 if they do not, and -1 if at least one 'unitNum' cannot be found.  
function SameElectrode(df,unitNums)
	dfref df
	wave unitNums
	
	svar /sdfr=df merged
	string sources=StringByKey("sourceClusters",merged)
	variable i
	string lastElectrode=""
	for(i=0;i<numpnts(unitNums);i+=1)
		variable unitNum=unitNums[i]
		string source=stringbykey(num2str(unitNum),sources,"=",",")
		if(!strlen(source)) // No source for this unit number.  
			return -1
		endif
		string electrode=stringfromlist(0,source,":")
		if(i>0 && !stringmatch(electrode,lastElectrode))
			return 0
		endif
		lastElectrode=electrode
	endfor
	return 1
end

Function ArchiveCheetahFiles()
	NewPath /Q/O CheetahPath
	Variable i=0
	Make /o/T/n=0 FilesWithData
	Do
		String dirStr=IndexedDir(CheetahPath,i,0)
		if(!strlen(dirStr))
			break
		endif
		Variable j=0
		PathInfo CheetahPath
		NewPath /Q/O ExperimentPath, S_Path+dirStr
		Do
			String fileStr=IndexedFile(ExperimentPath,j,".ntt")
			if(!strlen(fileStr))
				break
			endif
			GetFileFolderInfo /Q/P=ExperimentPath fileStr
			if(V_logEOF>16384)
				FilesWithData[numpnts(FilesWithData)]={dirStr}
				break
			endif
			j+=1
		While(1)
		i+=1
	While(1)
End

// Returns the name of the odor associated with a given sweep number.  
Function /s SweepOdor(sweepNum[,numeric])
	variable sweepNum
	variable numeric // Odor number instead of odor name.  
	
#ifdef Acq
	wave /z history=GetChannelHistory("Odor")
	if(!waveexists(history))
		printf "Could not find root:Odor:%s.\r",chanHistoryName  
		return ""
	endif
	variable i,j
	string odors="1:A;2:B;3:E;4:F;5:IAA"
	string odorsUsed=""
	for(i=0;i<max(1,dimsize(history,2));i+=1)
		variable ampl=history[sweepNum][%ampl][i]
		variable divisor=history[sweepNum][%divisor][i]
		variable remainder=history[sweepNum][%remainder][i]
		for(j=0;j<itemsinlist(odors);j+=1)
			string odorInfo=stringfromlist(j,odors)
			variable channel=str2num(stringfromlist(0,odorInfo,":"))
			string odorNumber=stringfromlist(0,odorInfo,":")
			string odorName=stringfromlist(1,odorInfo,":")
			if((ampl & 2^channel) && (remainder & 2^mod(sweepNum,divisor)))
				if(numeric)
					odorsUsed+=odorNumber+";"
				else
					odorsUsed+=odorName+";"
				endif
			endif
		endfor
	endfor
	odorsUsed=removeending(odorsUsed,";")
	return odorsUsed
#endif
End

// Remap the phases in 'phase' so that the spike times in 'spikeT' have a uniform phase distribution.  
Function /wave PhaseRemap(phase,spikeT)
	wave phase // A wave of phases (e.g. lfp or respiration) for every sample in a continuous recording.  
	wave spikeT // A wave of spike times.  
	
	make /free/n=(numpnts(spikeT)) phases=phase(spikeT)
	wave cdf=ECDF(phases,points=1000)
	setscale x,-pi,pi,cdf
	wave invCDF=InverseCDF(phases,lo=-pi,hi=pi)
	duplicate /o phase $(getwavesdatafolder(phase,2)+"_remap") /wave=phaseRemap
	phaseRemap=2*pi*(invcdf(phase)-0.5)
End

Function SpikePhaseHistograms(spikesDF,signalDFs[,plot,phases,smooth_])
	dfref spikesDF // An electrode epoch containing unit folders.  
	wave /df signalDFs // a wave of data folders for each signal for which a histogram should be constructed.  
	variable plot,smooth_
	wave /wave phases // Optional wave of phase waves to use instead of recomputing the phase each time.  
	
	variable i,j,k
	if(plot)
		string wins=""
		for(i=0;i<numpnts(signalDFs);i+=1)
			string signal=getdatafolder(0,signalDFs[i])
			string win=getdatafolder(0,spikesDF)+"_"+signal
			dowindow /k $win
			display /k=1 /n=$win
			wins+=win+";"
		endfor
	endif
	
	variable numUnits=0//CountObjectsDFR(spikesDF,4)
	make /free/df/n=0 unitDFs
	for(i=0;i<CountObjectsDFR(spikesDF,4);i+=1)
		string unit=GetIndexedObjNameDFR(spikesDF,4,i)
		if(!stringmatch(unit,"U*"))
			continue
		endif
		dfref df=spikesDF:$unit
		wave /z/sdfr=df data
		
		if(waveexists(data))
			unitDFs[numUnits]={df}
			numUnits+=1
		endif
	endfor
		
	make /o/n=(numUnits) respPeak
	make /o/n=0 spikesDF:PhaseTuning /wave=TuningMatrix=nan
	make /free/n=(numUnits,numpnts(signalDFs)) indices=p,depth=nan
	for(i=0;i<numUnits;i+=1)
		Prog("Unit",i,numUnits,msg=getdatafolder(0,unitDFs[i]))
		for(j=0;j<numpnts(signalDFs);j+=1)
			if(paramisdefault(phases))
				string prefix=SpikePhase(unitDFs[i],signalDFs[j])
			else
				prefix=SpikePhase(unitDFs[i],signalDFs[j],phase=phases[j])
			endif
			wave Tuning=$(prefix+"PhaseTuning")
			if(!numpnts(TuningMatrix))
				Redimension /n=(dimsize(Tuning,0),numUnits) TuningMatrix 
			endif
			TuningMatrix[][i]=Tuning[p]
			duplicate /free tuning,smoothed
			smooth /e=1 1,smoothed
			wavestats /q/m=1 smoothed
			depth[i][j]=(v_max-v_min)/(v_max+v_min)
		endfor
	endfor
	sort depth,indices
	for(i=0;i<numUnits;i+=1)
		variable index=indices[i]
		Prog("Unit",i,numUnits,msg=getdatafolder(0,unitDFs[index]))
		for(j=0;j<numpnts(signalDFs);j+=1)
			wavestats /q tuning
			respPeak[index]=v_maxloc
			if(plot)
				string axisL="left_"+num2str(floor(i/8))
				string axisB="bottom_"+num2str(mod(i,8))
				variable red=0,green=0,blue=0
				unit=getdatafolder(0,unitDFs[index])
				if(0)
					variable unitNum=str2num(unit[1,strlen(unit)-1])
					getclustercolors(unitNum,red,green,blue)
				elseif(0)
					string source=SourceElectrode(spikesDF,index+1)
					string electrode=stringfromlist(0,source,":")
					getelectrodecolors(electrode,red,green,blue)
				else
					colortab2wave rainbow
					wave m_colors
					setscale x,0,1,m_colors
					red=m_colors(depth[index])(0); green=m_colors(depth[index])(1); blue=m_colors(depth[index])(2)
				endif
				appendtograph /w=$win /l=$axisL /b=$axisB /c=(red,green,blue) TuningMatrix[][index] /tn=$("Unit "+unit)
				make /o/n=3 spikesDF:phaseTicks /wave=phaseTicks={-pi,0,pi}
				make /o/n=3/t spikesDF:phaseTickLabels /wave=phaseTickLabels={"-\F'Symbol'p","0","\F'Symbol'p"}
				modifygraph userTicks($axisB)={phaseTicks,phaseTickLabels},nTicks($axisL)=2
				setaxis $axisL 0,3*mean(Tuning)
			endif	
		endfor
	endfor
	copyscales Tuning,TuningMatrix
	if(smooth_)
		smooth /dim=0/e=1 smooth_,TuningMatrix
	endif
	if(plot)
		for(i=0;i<itemsinlist(wins);i+=1)
			win=stringfromlist(i,wins)
			TileAxes(win=win,pad={0.2,0,0,0.15},grout={0.04,0.02})
			modifygraph /w=$win mode=5,hbfill=2
			textbox /a=mb/f=0/t=1 "Phase"
		endfor
	endif
End

function PhaseOddsRatio(df,unit,type,bin)
	dfref df
	string type // "'rsp' or 'lfp'"
	variable unit,bin
	
	dfref dfi=df:$("U"+num2str(unit))
	wave /sdfr=dfi tuning=$(type+"_PhaseTuning")
	return tuning[bin]/mean(tuning)
end

Function /wave Spikes2Raster(df,delta[,minn,maxx,binary])
	dfref df
	variable delta,minn,maxx,binary
	
	wave /sdfr=df clusters,times
	
	wavestats /q/m=1 times
	minn=paramisdefault(minn) ? v_min : minn
	maxx=paramisdefault(maxx) ? v_max : maxx
	variable bins=(maxx-minn)/delta	
	wavestats /q/m=1 clusters
	make /o/n=(bins,v_max+1) df:raster /wave=raster=0
	setscale /p x,minn,delta,raster
	variable i,numSpikes=numpnts(times)
	for(i=0;i<numSpikes;i+=1)
		raster[(times[i]-minn)/delta][clusters[i]]+=1
	endfor
	if(binary)
		matrixop /o raster=-equal(raster,0)+1
	endif
	return raster
End

Function /wave JointSurprise(waves[,expected,phases,cycloHistograms,minOrder,maxOrder,atLeast,sortt,shift])
	wave /wave waves // (1) A wave of references to single-column waves, each containing 1's and 0's.  One wave for each neuron.  
					    // (2) Or, a wave with a reference one multi-column wave.  One column for each neuron.    
					    // Also, if there is more than one layer, the layers will be assumed to be trials, which will be used instead of rows for the purposes of computing expected coincidences.  
	variable minOrder // Minimum order, e.g. 2 to limit to >= two-way coincidences.  
	variable maxOrder // Maximum order, e.g. 2 to limit to <= two-way coincidences.  
	variable atLeast // At least the set of k neurons, but with no restrictions on the other n-k.  By default, only the set of k neurons can fire.  
	variable sortt // Sort by surprise.  
	variable shift // Compute observed spike counts from the a random trial for each cell, rather than the same trial.  
	wave /wave expected // Wave of waves of expected values (probabilities of firing).  These should come from some sort of fit, like GLM.  If this is not provided, expected values will be computed from marginals of the data ('waves').  
	wave /wave phases // Wave of waves of phases.  Each wave of phases should have the same dimensions as the waves contained in 'waves'.  
	wave /wave cycloHistograms // Wave of waves of cycloHistograms, one for each wave of phases.  The cyclohistogram should have one column for each neuron, and the x-scaling should be from -pi to pi.  
							     // Cyclohistograms should be computed based on binary data, i.e. 0's and 1's in each source bin, so that histogram represents probability of at least one spike at that phase.  
	
	variable numUnits=numpnts(waves)
	variable bins=dimsize(waves[0],0)
	if(numUnits==1 && dimsize(waves[0],1)>1)
		numUnits=dimsize(waves[0],1)
	endif
	minOrder=paramisdefault(minOrder) ? 0 : minOrder
	maxOrder=paramisdefault(maxOrder) ? numUnits : maxOrder
	variable i,j,k,combos=0,comboOffset=0
	for(i=minOrder;i<=maxOrder;i+=1)
		combos+=binomial(numUnits,i)
	endfor
	
	make /free/n=(combos) surprise=nan,numExpected=0,numObserved=0
	wave w0=waves[0]
	variable trials=max(1,dimsize(w0,2))
	make /free/n=(bins,numUnits,trials) data,matches,probs
	make /free/n=(trials,numUnits) permutations=p
	if(shift)
		for(i=0;i<numUnits;i+=1)
			make /free/n=(trials) ordered=p,random=enoise(1)
			sort random,ordered
			permutations[][i]=ordered[p]
		endfor
	endif
	
	if(numpnts(waves)>1) // waves contains references to many one-dimensonal waves.  
		for(i=0;i<numUnits;i+=1)
			wave w=waves[i]
			data[][i][]=(w[p][0][permutations[r][i]]>0) // (1,0) for (a,no) spike.  
		endfor
	else // waves contains a reference to one multi-dimensional wave.   
		wave w=waves[0]
		data=(w[p][q][permutations[r][q]]>0)
	endif
	if(paramisdefault(expected))
		imagetransform /METH=2 xProjection data; wave m_xprojection
		imagetransform /METH=2 zProjection data; wave m_zprojection
		matrixop /free normalization=meancols(m_zprojection)
		probs=m_zprojection[p][q]*m_xprojection[q][r]/normalization[q] // Joint probability across bins and trials for each unit.  
		probs=numtype(probs)==2 ? 0 : probs[p][q][r] // Turn any 0/0 entries from the normalization into zeroes.  
	else
		if(numpnts(expected)>1) // waves contains references to many one-dimensonal waves.  
			for(i=0;i<numUnits;i+=1)
				wave w=expected[i]
				probs[][i][]=w[p][0][i]  // (1,0) for (a,no) spike.  
			endfor
		else // waves contains a reference to one multi-dimensional wave.   
			wave w=expected[0]
			probs=w[p][q][r]
		endif
	endif
	if(!paramisdefault(phases) && !paramisdefault(cycloHistograms))
		for(i=0;i<numpnts(phases);i+=1)
			wave phase=phases[i]
			wave cycloHistogram=cycloHistograms[i]
			if(dimsize(cycloHistogram,1)!=numUnits)
				printf "The cyclohistogram has %d columns but there are %d units.\r",dimsize(cycloHistogram,1),numUnits
			endif
			matrixop /free normalization=meancols(cycloHistogram)
			probs*=cycloHistogram(phase[p][r])(q)/normalization[q] // Adjust the probability according to the odds ratio for that cell for the phase in that bin of that trial.  
			probs=numtype(probs)==2 ? 0 : probs[p][q][r] // Turn any 0/0 entries from the normalization into zeroes.  
		endfor
	endif
	
	make /free/n=(numUnits) units=p
	variable index=0,zz
	for(i=minOrder;i<=maxOrder;i+=1)
		variable count=binomial(numUnits,i)
		for(j=0;j<count;j+=1)
			if(mod(j,10)==0)
				prog("Combo",j,count)
			endif
			wave comboIndex=NthCombination(units,i,j)
			string dimLabel="|"
			make /free/n=(numUnits) combo=0
			for(k=0;k<i;k+=1)
				combo[comboIndex[k]]=1
				dimLabel+=num2str(comboIndex[k])+"|"
			endfor
			if(atLeast)
				dimLabel+="*"
			endif
			setdimlabel 0,index,$dimLabel,surprise
			//tic()
			multithread matches=data*combo[q]
			//tac()
			for(k=0;k<trials;k+=1)
				matrixop /free trialHits=sumrows(matches[][][k])
				if(atLeast)
					trialHits=(trialHits>=i)
				else
					trialHits=(trialHits==i)
				endif
				numObserved[index]+=sum(trialHits)
			endfor
			//toc()
			if(trials<=1) // Compute probability by mean firing rate across the whole trial.  A scalar for each unit.  
				if(atLeast)
					make /free/n=(numUnits) comboProbs=combo[p] ? probs[p] : 1
				else
					make /free/n=(numUnits) comboProbs=combo[p] ? probs[p] : (1-probs[p])
				endif
				comboProbs=log(comboProbs)
				variable jointProb=10^sum(comboProbs)
				numExpected[index]=jointProb*bins
			else // Compute probability by mean firing rate across trials, for each bin (like PETH).  A vector for each unit.  
//				if(shift)
//					duplicate /free matches,matchesShifted
//					multithread matchesShifted[][comboIndex[1]][]=matches[p][q][mod(r+shift,trials)] // Shift unit 1 by 'shift' trials.  
//					wave matches=matchesShifted
//					for(k=0;k<trials;k+=1)
//						matrixop /free trialHits=sumrows(matches[][][k])
//						if(atLeast)
//							trialHits=(trialHits>=i)
//						else
//							trialHits=(trialHits==i)
//						endif
//						numExpected[index]+=sum(trialHits)
//					endfor
//				else
				for(k=0;k<trials;k+=1)
					if(atLeast)
						make /free/n=(bins,numUnits) comboProbs=combo[q] ? probs[p][q][k] : 1
					else
						make /free/n=(bins,numUnits) comboProbs=combo[q] ? probs[p][q][k] : (1-probs[p][q][k])
					endif
					comboProbs=log(comboProbs)
					matrixop /o jointProbs=powR(10,sumrows(comboProbs))
					numExpected[index]+=sum(jointProbs)//*trials
				endfor
//				endif
			endif
			
			if(numExpected[index]==0 && numObserved[index]>0)// && shift==0)
				printf "%f %f %f %f.\r",log2(comboIndex[0]),log2(comboIndex[1]),numExpected[index],numObserved[index]
			endif
			if(numObserved[index]>0)
				zz+=1
			endif
			
			// Must average x and x-1 to avoid bias.  This will give a uniform distribution of cdf values under the null hypothesis.  
			variable cdf=(statspoissoncdf(numObserved[index],numExpected[index])+statspoissoncdf(numObserved[index]-1,numExpected[index]))/2
			if(numtype(cdf)) // NaN or Inf, probably because the numbers were too large for statspoissoncdf.  
				cdf=statsnormalcdf(numObserved[index],numExpected[index],sqrt(numExpected[index]))
			endif
			if(numtype(cdf)==2)
				//printf comboIndex,numObserved[index],numExpected[index]
			endif
			variable pValue=1-cdf
			if(numExpected[index]==0 && numObserved[index]==0)
				pValue=0.5
			endif
			//if(1 || pValue==1 || pValue==0) // Too extreme even for statsnormalcdf.  
			//	pValue=1-(1+erf((numObserved-numExpected)/sqrt(2*numExpected)))/2
			//endif
			pValue=(pValue<0) ? 0 : pValue
			surprise[index]=log((1-pValue)/pValue)
			//printf numExpected[i],numObserved[i],pValue,surprise[i]
			//printf numExpected[i],numObserved[i],surprise[i]
			index+=1
		endfor
	endfor
	//printf zz

//	i=0
//	do
//		if(numtype(surprise[i])==2) // NaN.  
//			deletepoints i,1,surprise,numExpected,numObserved
//		else
//			i+=1		
//		endif
//	while(i<dimsize(surprise,0))
	if(sortt)
		make /free/n=(numpnts(surprise)) indices=p
		duplicate /free surprise,surpriseUnsorted
		sort /r surprise,surprise,numExpected,numObserved,indices
		for(i=0;i<combos;i+=1)
			setdimlabel 0,i,$getdimlabel(surpriseUnsorted,0,indices[i]),surprise
		endfor
	endif
	concatenate {numExpected,numObserved},surprise
	setdimlabel 1,0,S,surprise
	setdimlabel 1,1,expected,surprise
	setdimlabel 1,2,observed,surprise
	//wavetransform /o flip, surprise // Put all 1's first and all 0's last.  
	//wavetransform /o flip, num // Put all 1's first and all 0's last.  
	return surprise
End

// Computes joint surprise from a block of data.  
function /wave JointSurpriseTrials(data[,winSize,winOverlap,minOrder,maxOrder,atLeast,shift,phases,cycloHistograms])
	wave data // Data from 'keepTrials' in the MakePETH function, i.e. time x cells x odors x trials.  
	variable winSize,winOverlap // In seconds.  
	variable minOrder // Minimum order, e.g. 2 to limit to >= two-way coincidences.  
	variable maxOrder // Maximum order, e.g. 2 to limit to <= two-way coincidences.  
	variable atLeast // At least the set of k neurons, but with no restrictions on the other n-k.  By default, only the set of k neurons can fire.  
	variable shift // Compute observed spike counts from random trials for each neuron.  
	wave /wave phases // Data from 'keepTrials' in the MakePETH function, but for the phase, i.e. time x 1 x odors x trials.  
	wave /wave cycloHistograms // Cyclohistograms for the cells, an N x units matrix, with an x-scaling from -pi to pi.  
	
	minOrder=paramisdefault(minOrder) ? 2 : minOrder
	maxOrder=paramisdefault(maxOrder) ? 2 : maxOrder
	variable pMax=dimsize(data,0)
	variable units=dimsize(data,1)
	variable stims=dimsize(data,2)
	variable trials=dimsize(data,3)
	
	variable i,j,k,m,combos=0,comboOffset=0
	for(i=0;i<minOrder;i+=1)
		comboOffset+=binomial(units,i)
	endfor
	for(i=minOrder;i<=maxOrder;i+=1)
		combos+=binomial(units,i)
	endfor
	winSize=paramisdefault(winSize) ? pMax : winSize/dimdelta(data,0)
	winOverlap=paramisdefault(winOverlap) ? 0 : winSize*winOverlap

	variable bins=(pMax-winSize)/(winSize-winOverlap)+1
	make /o/n=(combos,3,bins) JointSurprise_=nan
	for(i=0;i<bins;i+=1)
		prog("Bin",i,bins)
		variable t=i*(winSize-winOverlap)
		//for(j=0;j<stims;j+=1)
			//prog("Stim",j,stims)
			//duplicate /free/r=[t,t+winSize-1][][][] data, w
			make /o/n=(winSize,units,stims*trials) w=data[t+mod(p,winSize)][q][mod(r,stims)][mod(floor(r/stims),trials)]
			//duplicate /o w,test; abort
			variable sortt=paramisdefault(winSize) // If there are multiple bins, don't sort because then each bin will have a different sort order.  
			if(!paramisdefault(phases) && !paramisdefault(cycloHistograms))
				if(!paramisdefault(phases))
					make /free/wave/n=(numpnts(phases)) phases_
					for(k=0;k<numpnts(phases);k+=1)
						wave phase=phases[k]
						make /o/n=(winSize,1,stims*trials) phase_=phase[t+mod(p,winSize)][0][mod(r,stims)][mod(floor(r/stims),trials)]
						phases_[k]=phase_
					endfor
				endif
				wave surprise=JointSurprise({w},minOrder=minOrder,maxOrder=maxOrder,atLeast=atLeast,sortt=sortt,shift=shift,phases=phases_,cycloHistograms=cycloHistograms)
			else
				wave surprise=JointSurprise({w},minOrder=minOrder,maxOrder=maxOrder,atLeast=atLeast,sortt=sortt,shift=shift)
			endif
			JointSurprise_[][][i]=surprise[p][q]
			waveclear w
		//endfor
	endfor
	//duplicate /o surprise,test
//	if(1) // Sort and Label
//		make /free/n=(combos) index=p
//		duplicate /o JointSurprise_, JointSurprise_Orig
//		matrixop /free JS=meancols(JointSurprise_^t)
//		sort /r JS,JS,index
//		for(i=0;i<combos;i+=1)
//			setdimlabel 0,i,$GetDimLabel(surprise,0,index[i]),JointSurprise_
//			JointSurprise_[i][]=JointSurprise_Orig[index[i]][q]
//		endfor
//	else
		for(i=0;i<combos;i+=1)
			setdimlabel 0,i,$GetDimLabel(surprise,0,i),JointSurprise_
		endfor
//	endif
	return JointSurprise_
end

function JointSurpriseBins(js)
	wave js // Joint Surprise.  
	variable combos=dimsize(js,0)
	variable bins=dimsize(js,2)
	
	make /o/n=(combos,bins) observed=js[p][2][q]
	make /o/n=(combos,bins) expected=js[p][1][q]
	duplicate /free expected,expectedBoot
	redimension /n=(-1,-1,1000) expectedBoot
	expectedBoot=poissonnoise(expected[p][q])
	imagetransform /METH=2 xProjection expectedBoot
	wave expectedSumDist=m_xprojection
	matrixop /o observedSum=meancols(observed)
	
	variable i,j,k
	make /o/n=(bins) SurpriseZ=nan
	for(i=0;i<bins;i+=1)
		wave ro=row(expectedSumDist,i)
		wavestats /q ro
		variable zz=(observedSum[i]-v_avg)/v_sdev
		SurpriseZ[i]=zz
	endfor
	killwaves /z m_xprojection
end

Function SpikeBayesROC(df[,features])
	dfref df // A unit data folder.  Assumes that the parent data folder contains the cluster assignments for the entire tetrode.  
	wave features // The coordinates of the data in a feature space, e.g. the PCA coefficients.  
	
	if(paramisdefault(features))
		wave /sdfr=df features=lambdas 
	endif
	string unitName=getdatafolder(0,df)
	variable clusterNum=str2num(unitName[1])
	wave invCovs=MahalInvCovMatrix(transpose(features)) // inverse of the covariance matrix.  
	matrixop /free means=meancols(features)
	//redimension /n=(numpnts(means)) means
	make /free/n=0 us,them // d^2 values for this cluster and for all others, based on the covariance matrix of this cluster.  
	make /o/n=1000 df:trueHits,df:trueMisses,df:falseHits,df:falseMisses,df:sensitivity,df:specificity,df:falseDiscovery
	wave /sdfr=df trueHits,trueMisses,falseHits,falseMisses,sensitivity,specificity,falseDiscovery 
	variable dof=dimsize(features,1)
	setscale x,0,statsinvchicdf(0.99,dof),trueHits,trueMisses,falseHits,falseMisses,sensitivity,specificity,falseDiscovery // Range from threshold of d^2=0 to the 95th percentile of the distribution of d^2 under the null hypothesis.  
	variable i,count=0

	for(i=0;i<dimsize(features,0);i+=1)
		matrixop /free spike=row(features,i)^t
		matrixop /free mahal=sqrt((spike-means)^t x invcovs x (spike-means))
		us[count]={mahal[0]^2}
		count+=1
	endfor
	
	dfref parentDF=$removeending(getdatafolder(1,df),unitName+":")
	wave /sdfr=parentDF clusters,parentFeatures=$(nameofwave(features))
	count=0
	for(i=0;i<dimsize(parentFeatures,0);i+=1)
		if(clusters[i]==0 || clusters[i]==clusterNum) // Exclude noise cluster and self.  
			continue
		endif
		matrixop /free spike=row(parentFeatures,i)^t
		matrixop /free mahal=sqrt((spike-means)^t x invcovs x (spike-means))
		them[count]={mahal[0]^2}
		count+=1
	endfor
	
	sort us,us
	sort them,them
	for(i=0;i<numpnts(sensitivity);i+=1)
		variable thresh=pnt2x(sensitivity,i)
		trueHits[i]=1+binarysearch(us,thresh)
		switch(trueHits[i])
			case -1:
				trueHits[i]=numpnts(us)
				break
			case -2:
				trueHits[i]=0 // No spikes at all.  
				break
		endswitch
		trueMisses[i]=numpnts(us)-trueHits[i]
		falseHits[i]=1+binarysearch(them,thresh)
		switch(falseHits[i])
			case -1:
				falseHits[i]=numpnts(them)
				break
			case -2:
				falseHits[i]=0 // No spikes at all.  
				break
		endswitch
		falseMisses[i]=numpnts(them)-falseHits[i]
		sensitivity[i]=trueHits[i]/numpnts(us)
		specificity[i]=1-falseHits[i]/numpnts(them)
		falseDiscovery[i]=falseHits[i]/(trueHits[i]+falseHits[i])
	endfor
	duplicate /o them test
End

function TotalCorrelationByBinSize(df,eventsDF,phaseDF,pethInstance,binSizes[,nonstationary])
	dfref df,eventsDF,phaseDF
	string pethInstance
	wave binSizes
	variable nonstationary
	
	variable i,numBinSizes = numpnts(binSizes)
	wave phaseData = phaseDF:data
	findlevels /q/edge=1 phaseData,0
	variable period = numpnts(phaseData)*deltax(phaseData)/v_levelsfound
	for(i=0;i<numBinSizes;i+=1)
		Prog("Bin Size",i,numBinSizes)
		Core#SetVarPackageSetting("Nlx","PETH",pethInstance,"binWidth",binSizes[i])
		if(0)
			NlxA#MakePETH(df,eventsDF,pethInstance,keepTrials=1)
			variable phaseBins = max(1,round(period / binSizes[i])) // 0.5 is the approximate period of one respiration cycle in seconds.  
			wave /sdfr=df clusters
			variable numUnits=1+wavemax(clusters)
		
			CycloHistograms(phaseDF:Data,df,phaseBins,normalize="Density")//,smooth_=25)
			wave /sdfr=df trials,cycloHistogram
			//variable smoothing_bins = min(dimsize(cycloHistogram,0)-2,ceil(binSizes[i]*100/0.5))
			//smooth /e=1/dim=0/b=1 smoothing_bins, cycloHistogram
			wave totalCorrs = TotalCorrelation(trials,cycloHistograms={cycloHistogram},nonstationary=nonstationary)
			duplicate /o totalCorrs df:$("totalCorrs_"+num2str(i))
		endif
		// Optional.  
		UpdateNoiseCorrs(df,i)
	endfor
end

function UpdateNoiseCorrs(df,i)
	dfref df
	variable i
	
	wave /sdfr=df totalCorrs = $("totalCorrs_"+num2str(i))
	variable noiseCorrs_plane = 0//dimsize(totalCorrs,2)-1
	extract /free totalCorrs,noiseCorrs,r==noiseCorrs_plane && p!=q && p>0 && q>0
	extract /free totalCorrs,noiseCorrs_same,r==noiseCorrs_plane && p!=q && SameElectrode(df,{p,q})==1
	extract /free totalCorrs,noiseCorrs_diff,r==noiseCorrs_plane && p!=q && SameElectrode(df,{p,q})==0
	ecdf(noiseCorrs)
	ecdf(noiseCorrs_same)
	ecdf(noiseCorrs_diff)
	wave /sdfr=df noiseCorrsForBinSizes,noiseCorrsForBinSizes_same,noiseCorrsForBinSizes_diff
	wave /sdfr=df noiseCorrsForBinSize_sem,noiseCorrsForBinSize_same_sem,noiseCorrsForBinSize_diff_sem
	redimension /n=(i+1) noiseCorrsForBinSizes,noiseCorrsForBinSizes_same,noiseCorrsForBinSizes_diff
	redimension /n=(i+1) noiseCorrsForBinSize_sem,noiseCorrsForBinSize_same_sem,noiseCorrsForBinSize_diff_sem
	variable quantile=i==7 ? 0.4 : 0.5//max(0.5,0.9-i*0.05)
	
	//statsquantiles /q/trim=25 noiseCorrs
	wavestats /q noiseCorrs
	//wave w_statsquantiles
	noiseCorrsForBinSizes[i]=noiseCorrs(quantile)//v_avg//max(0,v_q25)//(v_q25+v_median)/2//v_q25*2
	noiseCorrsForBinSize_sem[i]=v_sdev/sqrt(v_npnts)
	
	//statsquantiles /q/trim=25 noiseCorrs_same
	wavestats /q noiseCorrs_same
	noiseCorrsForBinSizes_same[i]=noiseCorrs_same(quantile)//v_avg//max(0,v_q25)//(v_q25+v_median)/2//v_q25*2
	noiseCorrsForBinSize_same_sem[i]=v_sdev/sqrt(v_npnts)
	
	wavestats /q noiseCorrs_diff
	noiseCorrsForBinSizes_diff[i]=noiseCorrs_diff(quantile)//v_avg//max(0,v_q25)//(v_q25+v_median)/2//v_q25*2
	noiseCorrsForBinSize_diff_sem[i]=v_sdev/sqrt(v_npnts)
	doupdate
end

function /wave TotalCorrelation(trials[,cycloHistograms,nonstationary,noCov])
	wave trials // A wave of spike counts with dimensions corresponding to {time,unit,stimulus,trial}.  
	wave /wave cycloHistograms // Optional wave of 2D waves of cycloHistograms for each neuron, which should correspond to firing rates in each phase bin.  
	// For example, the first 2D wave could be a cyclohistogram for the respiratory phase, the second could be for the LFP phase, etc.  
	variable nonstationary
	variable noCov // Set to 1 to compute correlations, and 0 to compute covariances.  
	
	noCov = paramisdefault(noCov) ? 1 : noCov
	variable pMax=dimsize(trials,0)
	variable numUnits=dimsize(trials,1)
	variable numStims=dimsize(trials,2)
	variable numTrials=dimsize(trials,3)
	variable numCycloHistograms=paramisdefault(cycloHistograms) ? 0 : numpnts(cycloHistograms)
	make /o/n=(numUnits,numUnits,14+3*numCycloHistograms) totalCorrs=nan // 7 layers are total correlation, time correlation, signal correlation, trial correlation, the three two-way combinations of those correlation, the three one-way, three two-way, and one three-way combinations of noise correlation.  
	make /o/n=(numUnits,numUnits,2) cov_var
	setscale /p x,1,1,totalCorrs
	setscale /p y,1,1,totalCorrs
	variable unit1,unit2
	variable Twopi=1//2*pi/10
	//wave ch = cycloHistogram[0]
	for(unit1=0;unit1<numUnits;unit1+=1)
		prog("Unit1",unit1,numUnits)
		make /free/n=(pMax,numStims,numTrials)/d w1=trials[p][unit1][q][r]
		if(nonstationary)
			redimension /e=1/n=(pMax*numStims*numTrials) w1
			differentiate /meth=1 w1
			redimension /e=1/n=(pMax,numStims,numTrials) w1
		endif
		//print unit1,mean(w1)
		//continue
		variable rows=dimsize(w1,0),cols=dimsize(w1,1),layers=dimsize(w1,2)
		
		// Projections, averaging across identical times, stimuli, or trials.  
		imagetransform /METH=2 xProjection w1; duplicate /free m_xprojection, w1_signalTrial;// duplicate /o w1,w1_nx; w1_nx-=w1_x[q][r]
		matrixop /free w1_signal=meancols(w1_signalTrial^t)
		matrixop /free w1_trial=meancols(w1_signalTrial)
		imagetransform /METH=2 yProjection w1; duplicate /free m_yprojection, w1_timeTrial//; ;duplicate /o w1,w1_ny; w1_nx-=w1_y[p][r]
		matrixop /free w1_time=meancols(w1_timeTrial^t)
		imagetransform /METH=2 zProjection w1; duplicate /free m_zprojection, w1_signalTime//; duplicate /o w1,w1_nz; w1_nx-=w1_z[p][q]
		
		// Dot products.  
		make /d/free/n=1 w_mean11=mean(w1)*mean(w1)
		make /d/free/n=(rows,cols,layers) w1squared=w1*w1
		make /d/free/n=1 w_corr11=mean(w1squared)
		matrixop /free w_time11=mean(magsqr(w1_time))
		matrixop /free w_signal11=mean(magsqr(w1_signal))
		matrixop /free w_trial11=mean(magsqr(w1_trial))
		matrixop /free w_signalTrial11=mean(magsqr(w1_signalTrial))
		matrixop /free w_timeTrial11=mean(magsqr(w1_timeTrial))
		matrixop /free w_signalTime11=mean(magsqr(w1_signalTime))
		
		make /free/n=(numCycloHistograms) w_phase11
		variable i
		for(i=0;i<numCycloHistograms;i+=1)
			wave ch=cycloHistograms[i]
			//duplicate /free ch,ch_
			//deletepoints /m=1 0,1,ch_ // Assume that first column of cyclohistogram corresponds to noise cluster (cluster zero).  
			//wave ch=ch_
			variable numBins=dimsize(ch,0)
			variable rate1=mean(w1) // Mean count per trials matrix bin.  
			matrixop /free w_phase11A=mean(magsqr(col(ch,unit1)*rate1*numBins)) // *rate1*2*pi makes cyclohistogram pdf equal to cyclohistogram firing rate.  
			w_phase11[i]=w_phase11A
		endfor
		
		for(unit2=0;unit2<unit1;unit2+=1)
			totalCorrs[unit1][unit2][]=totalCorrs[unit2][unit1][r] // The other side of the diagonal of the matrix, which has already been done.  
		endfor
		for(unit2=unit1;unit2<numUnits;unit2+=1)
			make /free/n=(pMax,numStims,numTrials)/d w2=trials[p][unit2][q][r]
			if(nonstationary)
				redimension /e=1/n=(pMax*numStims*numTrials) w2
				differentiate /meth=1 w2
				redimension /e=1/n=(pMax,numStims,numTrials) w2
			endif
			
			// Projections, averaging across identical times, stimuli, or trials.  
			imagetransform /METH=2 xProjection w2; wave w2_signalTrial=m_xprojection//; duplicate /o w2,w2_nx; w2_nx-=w2_x[q][r]
			matrixop /free w2_signal=meancols(w2_signalTrial^t)
			matrixop /free w2_trial=meancols(w2_signalTrial)
			imagetransform /METH=2 yProjection w2; wave w2_timeTrial=m_yprojection//; duplicate /o w2,w2_ny; w2_ny-=w2_y[p][r]
			imagetransform /METH=2 zProjection w2; wave w2_signalTime=m_zprojection//; duplicate /o w2,w2_nz; w2_nz-=w2_z[p][q]
			matrixop /free w2_time=meancols(w2_timeTrial^t)
			
			// Dot products.  
			make /d/free/n=1 w_mean22=mean(w2)*mean(w2)
			make /d/free/n=(dimsize(w1,0),dimsize(w1,1),dimsize(w1,2)) w2squared=w2*w2
			make /d/free/n=1 w_corr22=mean(w2squared)
			matrixop /free w_time22=mean(magsqr(w2_time))
			matrixop /free w_signal22=mean(magsqr(w2_signal))
			matrixop /free w_trial22=mean(magsqr(w2_trial))
			matrixop /free w_signalTrial22=mean(magsqr(w2_signalTrial))
			matrixop /free w_timeTrial22=mean(magsqr(w2_timeTrial))
			matrixop /free w_signalTime22=mean(magsqr(w2_signalTime))
			
			make /d/free/n=1 w_mean12=mean(w1)*mean(w2)
			make /d/free/n=(dimsize(w1,0),dimsize(w1,1),dimsize(w1,2)) w12=w1*w2
			make /d/free/n=1 w_corr12=mean(w12)
			matrixop /free w_time12=mean(w1_time*w2_time)
			matrixop /free w_signal12=mean(w1_signal*w2_signal)
			matrixop /free w_trial12=mean(w1_trial*w2_trial)
			matrixop /free w_signalTrial12=mean(w1_signalTrial*w2_signalTrial)
			matrixop /free w_timeTrial12=mean(w1_timeTrial*w2_timeTrial)
			matrixop /free w_signalTime12=mean(w1_signalTime*w2_signalTime)
			
			make /free/n=(numCycloHistograms) w_phase12,w_phase22
			for(i=0;i<numCycloHistograms;i+=1)
				wave ch=cycloHistograms[i]
				//duplicate /free ch,ch_
				//deletepoints /m=1 0,1,ch_ // Assume that first column of cyclohistogram corresponds to noise cluster (cluster zero).  
				//wave ch=ch_
				numBins=dimsize(ch,0)
				variable rate2=mean(w2)
				matrixop /free w_phase12A=mean(col(ch,unit1)*rate1*numBins*col(ch,unit2)*rate2*numBins)
				w_phase12[i]=w_phase12A[0]
				matrixop /free w_phase22A=mean(magsqr(col(ch,unit2)*rate2*numBins))
				w_phase22[i]=w_phase22A[0]
			endfor
			
			// Degrees of correlation.  Numerators are covariances, thus they can be added and subtracted.  
			matrixop /free totalCorr=(w_corr12 - w_mean12)/powR(sqrt((w_corr11-w_mean11)*(w_corr22-w_mean22)),noCov)
			if(unit1==unit2)
				//print w_corr12-w_mean12,w_corr11-w_mean11,w_corr22-w_mean22
			endif
			matrixop /free timeCorr=(w_time12 - w_mean12)/powR(sqrt((w_time11-w_mean11)*(w_time22-w_mean22)),noCov)
			matrixop /free signalCorr=(w_signal12 - w_mean12)/powR(sqrt((w_signal11-w_mean11)*(w_signal22-w_mean22)),noCov)
			matrixop /free trialCorr=(w_trial12 - w_mean12)/powR(sqrt((w_trial11-w_mean11)*(w_trial22-w_mean22)),noCov)
			matrixop /free signalTrialCorr=(w_signalTrial12 - w_mean12)/powR(sqrt((w_signalTrial11-w_mean11)*(w_signalTrial22-w_mean22)),noCov)
			matrixop /free timeTrialCorr=(w_timeTrial12 - w_mean12)/powR(sqrt((w_timeTrial11-w_mean11)*(w_timeTrial22-w_mean22)),noCov)
			matrixop /free signalTimeCorr=(w_signalTime12 - w_mean12)/powR(sqrt((w_signalTime11-w_mean11)*(w_signalTime22-w_mean22)),noCov)
			matrixop /free noiseCorrSig=(w_corr12 - w_signal12)/powR(sqrt((w_corr11-w_signal11)*(w_corr22-w_signal22)),noCov)
			matrixop /free noiseCorrTime=(w_corr12 - w_time12)/powR(sqrt((w_corr11-w_time11)*(w_corr22-w_time22)),noCov)
			matrixop /free noiseCorrTrial=(w_corr12 - w_trial12)/powR(sqrt((w_corr11-w_trial11)*(w_corr22-w_trial22)),noCov)
			matrixop /free noiseCorrSigTime=(w_corr12 - w_signal12 -w_time12 + w_mean12)/powR(sqrt((w_corr11-w_signal11-w_time11+w_mean11)*(w_corr22-w_signal22-w_time22+w_mean22)),noCov)
			matrixop /free noiseCorrTimeTrial=(w_corr12 - w_time12 - w_trial12 + w_mean12)/powR(sqrt((w_corr11 - w_time11 - w_trial11 + w_mean11)*(w_corr22 - w_time22 - w_trial22 + w_mean22)),noCov) // + w_mean comes in because there is a - w_mean inherent in both w_signal and w_trial, but only one should be subtracted.  
			matrixop /free noiseCorrSigTrial=(w_corr12 - w_signal12 - w_trial12 + w_mean12)/powR(sqrt((w_corr11 - w_signal11 - w_trial11 + w_mean11)*(w_corr22 - w_signal22 - w_trial22 + w_mean22)),noCov) // + w_mean comes in because there is a - w_mean inherent in both w_signal and w_trial, but only one should be subtracted.  	
			matrixop /free noiseCorrSigTimeTrial=(w_corr12 - w_signal12 - w_trial12 - w_time12 + 2*w_mean12)/powR(sqrt((w_corr11 - w_signal11 - w_trial11 - w_time11 + 2*w_mean11)*(w_corr22 - w_signal22 - w_trial22 - w_time22 + 2*w_mean22)),noCov) // + w_mean comes in because there is a - w_mean inherent in both w_signal and w_trial, but only one should be subtracted.  
			
			make /free/n=(numCycloHistograms) noiseCorrPhase,phaseCorr,noiseCorrAll
			for(i=0;i<numCycloHistograms;i+=1)
				wave ch=cycloHistograms[i]
				//duplicate /free ch,ch_
				//deletepoints /m=1 0,1,ch_ // Assume that first column of cyclohistogram corresponds to noise cluster (cluster zero).  
				//wave ch=ch_
				numBins=dimsize(ch,0)
				matrixop /free phaseCorrA=(w_phase12[i]-w_mean12[0])/powR(sqrt((w_phase11[i]-w_mean11[0])*(w_phase22[i]-w_mean22[0])),noCov)
				matrixop /free noiseCorrPhaseA=(w_corr12-w_phase12[i])/powR(sqrt((w_corr11-w_phase11[i])*(w_corr22-w_phase22[i])),noCov)
				matrixop /free noiseCorrAllA=(w_corr12 - w_signal12 - w_trial12 - w_time12 - w_phase12[i] + 3*w_mean12)/powR(sqrt((w_corr11-w_signal11-w_trial11-w_time11-w_phase11[i]+3*w_mean11)*(w_corr22-w_signal22 - w_trial22 - w_time22 - w_phase22[i] + 3*w_mean22)),noCov) // + w_mean comes in because there is a - w_mean inherent in both w_signal and w_trial, but only one should be subtracted.  
				matrixop /free noiseCorrAllA=(w_corr12 - w_signal12 - w_trial12 - w_time12 - w_phase12[i] + 3*w_mean12)/powR(sqrt((w_corr11-w_signal11-w_trial11-w_time11-w_phase11[i]+3*w_mean11)*(w_corr22 - w_signal22 - w_trial22 - w_time22 - w_phase22[i] + 3*w_mean22)),noCov) // + w_mean comes in because there is a - w_mean inherent in both w_signal and w_trial, but only one should be subtracted.  
				//noiseCorrAllA = NoiseCorr(w1,w2,{w1_signal,w1_time,w1_trial,col(ch,unit1)},{w2_signal,w2_time,w2_trial,col(ch,unit2)}) // New and improved.  
				if(numBins>=1)
					phaseCorr[i]=phaseCorrA[0]
					noiseCorrPhase[i]=noiseCorrPhaseA[0]
					noiseCorrAll[i]=noiseCorrAllA[0]
				else
					phaseCorr[i]=nan
					noiseCorrPhase[i]=totalCorr[0]
					noiseCorrAll[i]=noiseCorrSigTimeTrial[0]
				endif
			endfor
			
			totalCorrs[unit1][unit2][0]=totalCorr[0]
			totalCorrs[unit1][unit2][1]=timeCorr[0]
			totalCorrs[unit1][unit2][2]=signalCorr[0]
			totalCorrs[unit1][unit2][3]=trialCorr[0]
			totalCorrs[unit1][unit2][4]=signalTimeCorr[0]
			totalCorrs[unit1][unit2][5]=signalTrialCorr[0]
			totalCorrs[unit1][unit2][6]=timeTrialCorr[0]
			totalCorrs[unit1][unit2][7]=noiseCorrSig[0]
			totalCorrs[unit1][unit2][8]=noiseCorrTime[0]
			totalCorrs[unit1][unit2][9]=noiseCorrTrial[0]
			totalCorrs[unit1][unit2][10]=noiseCorrSigTime[0]
			totalCorrs[unit1][unit2][11]=noiseCorrTimeTrial[0]
			totalCorrs[unit1][unit2][12]=noiseCorrSigTrial[0]
			totalCorrs[unit1][unit2][13]=noiseCorrSigTimeTrial[0]
			for(i=0;i<numCycloHistograms;i+=1)
				totalCorrs[unit1][unit2][14+3*i]=phaseCorr[i]
				totalCorrs[unit1][unit2][15+3*i]=noiseCorrPhase[i]
				totalCorrs[unit1][unit2][16+3*i]=noiseCorrAll[i]
			endfor
		endfor
	endfor
	if(noCov==0)
		duplicate /free/r=[][][0] totalCorrs,totalCorrs0
		totalCorrs /= sqrt(totalCorrs0[p][p]*totalCorrs0[q][q])
	endif
	killwaves /z m_xprojection,m_yprojection,m_zprojection
	return totalCorrs
end

// Redundant with SpikePhaseHistograms(), except for the binary option which makes it distinct.  
function /wave CycloHistograms(phase,dataDF,numPhaseBins[,normalize,binary,smooth_])
	wave phase
	dfref dataDF
	variable numPhaseBins,smooth_
	string normalize
	variable binary // Result will reflect the probability of at least one spike at that value, each time it is encountered.  
	
	normalize=selectstring(!paramisdefault(normalize),"Density",normalize)
	wave /z/sdfr=dataDF times,clusters
	//wave clusterIndex=NlxA#ClustersWithSpikes(dataDF,exclude={0})
	variable numUnits=1+wavemax(clusters)//max(1,numpnts(clusterIndex))

	make /free/n=(numPhaseBins+1) phaseBins=-pi+2*pi*p/numPhaseBins
	make /free/n=(numUnits+1) unitBins=p
	
	duplicate /free times,phases
	phases=phase(times[p])
	make /o/n=(numPhaseBins,numUnits) dataDF:cycloHistogram /wave=cyclo=0
		
	if(binary)
		duplicate /free times,cycles
		findlevels /q phase,0.001; wave w_findlevels
		cycles=binarysearch(w_findlevels,times)
		cycles=cycles<0 ? nan : cycles
		make /free/n=(wavemax(cycles)+2) cycleBins=p
		variable i
		for(i=0;i<numUnits;i+=1)
			Prog("Unit",i,numUnits)
			extract /free cycles,cycles_i,clusters==i
			extract /free phases,phases_i,clusters==i
			if(numpnts(phases_i))
				duplicate /free JointHistogram4(phases,cycles,phaseBins,cycleBins) m_jointhistogram 
				m_jointhistogram=m_jointhistogram>0
				matrixop /free phaseBinResponse=sumrows(m_jointhistogram)
				cyclo[][i]=phaseBinResponse[p]
			endif
		endfor
	else
		if(numPhaseBins>1)
			duplicate /o JointHistogram4(phases,clusters,phaseBins,unitBins) cyclo
		else
			redimension /n=(numUnits,1) cyclo
			setscale /p x,0,1,cyclo
			histogram clusters,cyclo
			matrixtranspose cyclo
		endif
	endif
	strswitch(normalize)
		case "Density":
			matrixop /free sums=sumcols(cyclo)^t
			cyclo/=sums[q]
			break
		case "Rate":
			variable tt = numpnts(phase)*deltax(phase)
			cyclo /= (tt/numPhaseBins)
			break
		default: // Leave as counts.  
			break
	endswitch
	if(smooth_)
		smooth /e=1/dim=0 smooth_,cyclo
	endif
	setscale x,-pi,pi,cyclo
	return cyclo
end

#endif

function FixWaveBitDepth(df)
	dfref df
	
	variable i
	variable bitVolts=7.6e-9
	//nvar /sdfr=root: bitVolts
	//wave /z/sdfr=df data
	string type=Nlx#DataType(df)
	strswitch(type)
		case "ntt":
			string waves=core#dir2("waves",df=df)
			for(i=0;i<itemsinlist(waves);i+=1)
				string wave_name=stringfromlist(i,waves)
				wave w=df:$wave_name
				strswitch(wave_name)
					case "data":
						if((wavetype(data) & 2^1)>0) // If data is 32-bit float.  
							w/=bitVolts // Convert from voltage to A/D signal.  
							redimension /w w // Make 16-bit int.  
						endif
						break
					case "clusters":
						if((wavetype(w) & 2^5)>0) // If cluster assignments are 32-bit int.  
							redimension /w w // Make 16-bit int.  
						endif
						break
					case "features":
						if(stringmatch(getdatafolder(1,df),"*merged*"))
							redimension /n=0 w
						endif
						break
				endswitch
			endfor
			break
	endswitch
	for(i=0;i<countobjectsdfr(df,4);i+=1)
		string folder=getindexedobjnamedfr(df,4,i)
		dfref dfi=df:$folder
		FixWaveBitDepth(dfi)
	endfor
end
