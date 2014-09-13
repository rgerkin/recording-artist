// $Author: rick $
// $Rev: 594 $
// $Date: 2011-11-05 21:43:12 -0400 (Sat, 05 Nov 2011) $

#pragma rtGlobals=1		// Use modern global access method.

Function PDGAll(channel)
	dfref channel
	
	string epochs=DirDFR(channel,"folders")
	variable i,numEpochs=itemsinlist(epochs)
	display /k=1/n=Periodograms
	//ProgWinOpen(name="Computing Periodograms")
	for(i=0;i<numEpochs;i+=1)
		//ProgWin(i/numEpochs,0)
		string epoch=stringfromlist(i,epochs)
		SetDataFolder channel:$epoch
		dspperiodogram /segn={3000,2700} $epoch
		duplicate /o w_periodogram $(epoch+"_pdg") /wave=pdg
		appendtograph pdg 
	endfor
	//ProgWinClose()
End

// Kills all data folders in folder 'curr_folder' matching 'match'
Function KillDataFolder2([in_folder,match])
	String in_folder,match
	String curr_folder=GetDataFolder(1)
	if(!ParamIsDefault(in_folder))
		SetDataFolder $in_folder
	endif
	if(ParamIsDefault(match))
		match="*"
	endif
	String folders=StringByKey("FOLDERS",DataFolderDir(1))
	Variable i
	for(i=0;i<ItemsInList(folders,",");i+=1)
		String folder=StringFromList(i,folders,",")
		KillDataFolder /Z $folder
	endfor
	SetDataFolder $curr_folder
End

// Executes CleanWaves() on all the sweeps of the experiment.  
Function CleanAllWaves()
	Variable i
	string sweeps=AllSweeps()
	variable numChannels=GetNumChannels()
	for(i=0;i<numChannels;i+=1)
		string channel=Chan2Label(i)
		CleanWaves(channel,sweeps)
	endfor
End

// Remove 60 Hz noise.  
Function CleanWaves(channel,sweep_list)
	string channel,sweep_list
	sweep_list=ListExpand(sweep_list)
	
	variable i
	for(i=0;i<ItemsInList(sweep_list);i+=1)
		variable sweepNum=str2num(StringFromList(i,sweep_list))
		Wave /Z Sweep=GetChannelSweep(channel,sweepNum,quiet=1)
		if(waveexists(Sweep))
			Post_("Cleaning "+channel+" sweep "+num2str(sweepNum))
			NewNotchFilter(Sweep,60,10)
//			String stim_regions=StimulusRegionList(channel,sweep_num)
//			Duplicate /o Sweep SweepCopy,SweepDiff
//			/SuppressRegions(SweepCopy,stim_regions,factor=10000,method="Squash")
//			SweepDiff=Sweep-SweepCopy // Take out stimulus artifacts so they aren't detected by RemoveWiggleNoise
//			RemoveWiggleNoise(SweepCopy)
//			Sweep=SweepCopy+SweepDiff // Put those artifacts back.  
		endif
	endfor
	KillWaves /Z SweepCopy,SweepDiff
End

// Recursively finds all waves in all folders below folder 'folder' that match 'match, and does something to them.  
Function Do2Waves(match[,folder])
	String match,folder
	if(ParamIsDefault(folder))
		folder="root"
	endif
	SetDataFolder $(folder+":")
	String sub_folders=DirFolders()
	Variable i
	for(i=0;i<ItemsInList(sub_folders);i+=1)
		String sub_folder=StringFromList(i,sub_folders)
		Do2Waves(match,folder=folder+":'"+sub_folder+"'")
	endfor
	i=0
	Do
		String name=GetIndexedObjName("",1,i )
		if(!strlen(name))
			break
		endif
		if(StringMatch(name,match))
			Wave theWave=$name
			// Do the following to each wave.  
			String folder_name=GetDataFolder(0)
			String sweep=StringFromList(2,name,"_")
			print sweep,RemoveChar(folder_name,"'")
			RenameDataFolder $("::"+folder_name), $("X_"+sweep+"_"+folder_name)
			break
			//
		endif
		i+=1
	While(1)
	if(!StringMatch(GetDataFolder(1),"root:"))
		SetDataFolder ::
	endif
End

// Convert to Nan the point p for all waves in the given folder
Function ConvertPointRangeInFolder(p1,p2,new_value[,folder])
	Variable p1,p2,new_value
	String folder
	String curr_folder=GetDataFolder(1)
	if(ParamIsDefault(folder))
		folder=""
	endif
	SetDataFolder $folder
	String waves=WaveList("*",";","")
	waves=SortList(waves,";",16)
	Variable i; String wave_name
	for(i=0;i<ItemsInList(waves);i+=1)
		wave_name=StringFromList(i,waves)
		Wave oneWave=$wave_name
		oneWave[p1,p2]=new_value
	endfor
	SetDataFolder $curr_folder
End

// Shifts the x-values of all waves in the given data folder by shift
Function ShiftScales(shift[,folder,match])
	Variable shift
	String folder,match
	if(ParamIsDefault(folder))
		folder=""
	endif
	if(ParamIsDefault(match))
		match="*"
	endif
	String curr_folder=GetDataFolder(1)
	SetDataFolder $folder
	String waves=WaveList(match,";","")
	Variable i,offset,delta; String wave_name
	for(i=0;i<ItemsInList(waves);i+=1)
		wave_name=StringFromList(i,waves)
		Wave theWave=$wave_name
		offset=DimOffset(theWave,0)
		delta=DimDelta(theWave,0)
		SetScale /P x,offset-shift,delta,theWave
	endfor
	SetDataFolder $curr_folder
End

// Deletes the specified points from all the waves in a folder
Function DeletePoints2(start,num[,folder,mask,except])
	Variable start,num
	String folder,mask,except
	if(ParamIsDefault(mask))
		mask="*"
	endif
	if(ParamIsDefault(except))
		except=""
	endif
	String curr_folder=GetDataFolder(1)
	if(!ParamIsDefault(folder))
		SetDataFolder $folder
	endif
	String waves=WaveList(mask,";","")
	waves=RemoveFromList2(except,waves)
	Variable i
	for(i=0;i<ItemsInList(waves);i+=1)
		DeletePoints start,num,$StringFromList(i,waves)
	endfor
	SetDataFolder $curr_folder	
End

// Does some function to all the waves in the current folder, including waves in subfolders.  
Function DoOnAllWaves()
	//String contents=DataFolderDir(3)
	String folders=StringByKey("FOLDERS",DataFolderDir(1)), folder
	String waves=StringByKey("WAVES",DataFolderDir(2))
	Variable i
	for(i=0;i<ItemsInList(waves,",");i+=1)
		Wave theWave=$StringFromList(i,waves,",")
		// ----- Your code starts here -----
		theWave=theWave == 0 ? NaN : theWave
		//Rename theWave $("group"+num2str(i))
		// ----- Your code ends here -----
	endfor
	for(i=0;i<ItemsInList(folders,",");i+=1)
		folder=StringFromList(i,folders,",")
		SetDataFolder $folder
		DoOnAllWaves()
	endfor
	if(!StringMatch(GetDataFolder(1),"root:"))
		SetDataFolder ::
	endif
End

// Renames all the waves in a given folder
Function RenameFolderWaves(folder,old_name,new_name)
	String folder // Full folder path.  
	String old_name,new_name // Prefixes to use for renaming.  
	String curr_folder=GetDataFolder(1)
	SetDataFolder $folder
	String wave_list=WaveList("*",";","")
	Variable i
	for(i=0;i<ItemsInList(wave_list);i+=1)
		String wave_name=StringFromList(i,wave_list)
		Rename $wave_name,$(ReplaceString(old_name,wave_name,new_name))
	endfor
	SetDataFolder $curr_folder
End

// Copies waves to one directory and gives names to indicate their sources
Function UnifyWaves(source_folders,dest_folder) 
	String source_folders,dest_folder
	Variable i,j
	String source_folder, new_name
	String curr_folder=GetDataFolder(1)
	NewDataFolder /o $("root:"+dest_folder)
	source_folders=RemoveFromList(dest_folder,source_folders)
	for(i=0;i<ItemsInList(source_folders);i+=1)
		source_folder=StringFromList(i,source_folders) // Finds absolute location of the folder and goes to it.
		FindFolder(source_folder)
		String waves=StringByKey("WAVES",DataFolderDir(2))
		String wave_name
		for(j=0;j<ItemsInList(waves,",");j+=1) // All this is to move all the waves to root with new names
			wave_name=StringFromList(j,waves,",")
			//print wave_name
			new_name=source_folder+"_"+wave_name
			if(strlen(new_name)>31)
				new_name=new_name[0,30]
			endif
			Duplicate /o $wave_name $("root:"+dest_folder+":"+new_name)
			//print "poop"
		endfor
		//KillDataFolder $("root:"+folder_name)
	endfor
	SetDataFolder curr_folder
End

// Rescales all the wave in folders matching "folder_match_str" to a new scale
Function RescaleWaves(folder_match_str,scale,start [,multiply,match_str,no_match_str])
	String folder_match_str
	Variable scale,start // Supply a -1 for either of these to leave that value alone
	Variable multiply
	String match_str,no_match_str // Waves in those folders should match or not match these values
	if(ParamIsDefault(match_str))
		match_str="*"
	endif
	if(ParamIsDefault(no_match_str))
		no_match_str=""
	endif
	if(ParamIsDefault(multiply))
		multiply=1;
	endif
	String folders=DataFolders();
	folders=ListMatch(folders,folder_match_str);
	print folders;
	Variable i,j
	String folder
	String curr_folder=GetDataFolder(1)
	Display /K=1
	for(i=0;i<ItemsInList(folders);i+=1)
		folder=StringFromList(i,folders);
		String list=WaveList2(folder=folder,match=match_str,except=no_match_str)
		folder=FindFolder(folder)
		String /G scales
		scales="MATCH:"+match_str+";NO_MATCH:"+no_match_str+";START:"+num2str(start)+";SCALE:"+num2str(scale)+";MULT:"+num2str(multiply)
		for(j=0;j<ItemsInList(list);j+=1)
			Wave toScale=$StringFromList(j,list)
			if(start==-1)
				start=pnt2x(toScale,0)
				//print start
			endif
			if(scale==-1)
				scale=(pnt2x(toScale,numpnts(toScale))-pnt2x(toScale,0))/numpnts(toScale)
				//print scale
			endif
			SetScale /P x,start,scale,toScale
			toScale*=multiply
			AppendToGraph toScale
		endfor
	endfor
	SetDataFolder curr_folder
End

// Computes the difference waves for a given wave combination
Function DiffWaves(folder_match_str,wave_name1,wave_name2)
	String folder_match_str,wave_name1,wave_name2
	String folders=DataFolders();
	folders=ListMatch(folders,folder_match_str);
	//print folders;
	Variable i,j
	String folder
	String curr_folder=GetDataFolder(1)
	Display /K=1
	for(i=0;i<ItemsInList(folders);i+=1)
		SetDataFolder curr_folder
		folder=StringFromList(i,folders)
		SetDataFolder folder
		if(waveexists($wave_name1) && waveexists($wave_name2))
			Duplicate /o $wave_name1 $(wave_name2+"Dif")
			Wave diff= $(wave_name2+"Dif")
			Wave wave1=$wave_name1
			Wave wave2=$wave_name2
			diff=wave1-wave2
			AppendToGraph diff
		else
			Print "One of the waves does not exist in folder "+folder
		endif
	endfor
	SetDataFolder curr_folder
End

// Do something to the current folder
Function DoOnFolderWaves(to_do_first_part,to_do_last_part)
	String to_do_first_part
	String to_do_last_part
	String waves=WaveList("*",";","")
	Variable i
	String wave_name
	for(i=0;i<ItemsInList(waves);i+=1)
		wave_name=StringFromList(i,waves)
		Execute /Q to_do_first_part+wave_name+to_do_last_part
	endfor
End

Function LengthenTraces(cell,thresh,first,amount1,last,amount2,first_trace,last_trace)
	String cell
	Variable thresh,first,amount1,last,amount2,first_trace,last_trace
	Variable i,num_points
	for(i=first_trace;i<=last_trace;i+=1)
		Wave theSweep=$("root:cell"+cell+":sweep"+num2str(i))
		num_points=numpnts(theSweep)
		if(num_points<=thresh)
			InsertPoints last,amount2,theSweep
			InsertPoints first,amount1,theSweep
		endif
	endfor
End

Function KillMatch(match) // Kills all waves that match the wild card in the current directory
	String match
	String list=WaveList(match,";","")
	Variable i
	String curr_folder=GetDataFolder(1)
	//print list
	for(i=0;i<ItemsInList(list);i+=1)
		Wave toKill=$(curr_folder+StringFromList(i,list))
		KillWaves /Z toKill
	endfor
End

// For all waves that share the same folder as Sweep_Nums, gets rid of points where Sweep_Nums is 0 or NaN.  
Function CleanTables()
	SetDataFolder root:reanalysis:sweepsummaries:R1
	String channels="R1;L2;B3"
	Variable i,j; String list,channel,folder,clean_list
	for(i=0;i<ItemsInList(channels);i+=1)
		channel=StringFromList(i,channels)
		folder="root:reanalysis:sweepsummaries:"+channel
		if(DataFolderExists(folder))
			clean_list=""
			SetDataFolder "root:reanalysis:sweepsummaries:"+channel
			list=WaveList("*",";","")
			Wave Sweep_Nums=Sweep_Nums
			for(j=0;j<numpnts(Sweep_Nums);j+=1)
				if(Sweep_Nums[j]==0 || IsNan(Sweep_Nums[j]))
					clean_list+=num2str(j)+";"
				endif
			endfor
			for(j=0;j<ItemsInList(list);j+=1)
				DeleteListOfPoints(StringFromList(j,list),clean_list)
			endfor
		endif
	endfor
End

Function EditFolder(folder_str [,sorter])
	String folder_str
	String sorter
	Variable folder_depth=ItemsInList(folder_str,":")
	String subfolder=StringFromList(folder_depth-1,folder_str,":")
	String win_name=subfolder+"_Table"
	if(WinExist(win_name))
		DoWindow /F $win_name
	else
		Edit /K=1 /N=$win_name
		String curr_folder=GetDataFolder(1)
		SetDataFolder folder_str
		String wave_list=WaveList("*",";","")
		if(!ParamIsDefault(sorter))
			wave_list=sorter
		endif
		Variable i
		String wave_name
		for(i=0;i<ItemsInList(wave_list);i+=1)
			wave_name=StringFromList(i,wave_list)
			AppendToTable $(folder_str+wave_name)
		endfor
		SetDataFolder curr_folder
	endif
	ModifyTable width=41, size=8
End

// Sets an index value of a list of waves equal to NaN
Function SetWaves2Nan(index,wave_list)
	Variable index // If index=-1, will set all values in each wave to NaN
	String wave_list
	Variable i
	for(i=0;i<ItemsInList(wave_list);i+=1)
		Wave numWave=$StringFromList(i,wave_list)
		Wave /T textWave=$StringFromList(i,wave_list)
		if(index==-1)
			numWave=NaN
			textWave=""
		else
			numWave[index]=NaN
			textWave[index]=""
		endif
	endfor
End

// Removes quotes from all text waves in the current directory
// Fix this to only search the first and last character for quotes (otherwise takes about 10 seconds)
Function ClearQuotes()
	String list=WaveList("*",";","TEXT:1")
	Variable i,j
	for(i=0;i<ItemsInList(list);i+=1)
		Wave /T theWave=$StringFromList(i,list)
		//print NameOfWave(theWave)
		for(j=0;j<numpnts(theWave);j+=1)
			theWave[j]=ReplaceString("\"",theWave[j],"")
		endfor
	endfor
End

// Move Waves
Function MoveWaves(to,[from,match])
	String to,from,match
	String curr_folder=GetDataFolder(1)
	if(ParamIsDefault(from))
		from=""
	endif
	if(ParamIsDefault(match))
		match="*"
	endif
	SetDataFolder $from
	String waves=WaveList(match,";","")
	Variable i
	for(i=0;i<ItemsInList(waves);i+=1)
		Wave theWave=$StringFromList(i,waves)
		MoveWave theWave,$to
	endfor
	SetDataFolder $curr_folder
End

// Modifies all waves in the folder (optionally matching 'match') by taking log10,log2,reciprocal
Function ModFolder(mode [,folder,match])
	String mode
	String folder
	String match
	if(ParamIsDefault(folder))
		folder=":"
	endif
	if(ParamIsDefault(match))
		match="*"
	endif
	String curr_folder=GetDataFolder(1)
	SetDataFolder folder
	String waves=StringByKey("WAVES",DataFolderDir(2)) // Gets all waves in the current directory
	waves=ReplaceString(",",waves,";")
	Variable i
	for(i=0;i<ItemsInList(waves);i+=1)
		Wave theWave=$StringFromList(i,waves)
		strswitch(mode)
			case "log10":
				theWave=log(theWave)
				break
			case "exp10":
				theWave=10^theWave
				break
			case "log2":
				theWave=log(theWave)/log(2)
				break
			case "exp2":
				theWave=2^theWave
				break
			case "reciprocal":
				theWave=1/theWave
				break
			default:
				Print "Invalid mode : "+mode
				break
		endswitch
	endfor	
	SetDataFolder curr_folder
End

// Construct a median wave whose values are the medians of the median waves of the list of waves at each bin.
Function MedianMedianWave(wave_list,bin_size)
	String wave_list
	Variable bin_size
	Variable i,j,num_waves=ItemsInList(wave_list)
	Wave theWave=$StringFromList(0,wave_list)
	Make /o/n=(ceil(numpnts(theWave)*dimdelta(theWave,0)/bin_size)) MedMedWave=0,SEMMedWave=0
	SetScale /P x,dimoffset(theWave,0),bin_size,MedMedWave
	String median_waves=""
	for(i=0;i<num_waves;i+=1)
		Wave theWave=$StringFromList(i,wave_list)
		median_waves+=MedianWave(theWave,bin_size)+";"
	endfor
	String value_list
	for(i=0;i<numpnts(MedMedWave);i+=1)
		value_list=""
		for(j=0;j<num_waves;j+=1)
			Wave MedWave=$StringFromList(j,median_waves)
			value_list+=num2str(MedWave(dimoffset(MedMedWave,0)+i*dimdelta(MedMedWave,0)))+";"
		endfor
		MedMedWave[i]=MedianList(value_list)
		SEMMedWave[i]=SEMList(value_list)
	endfor
	Display /K=1 MedMedWave
	ErrorBars MedMedWave,Y wave=(SEMMedWave,SEMMedWave)
End

// Construct a mean wave whose values are the means of the median waves of the list of waves at each bin.
Function MeanMedianWave(wave_list,bin_size)
	String wave_list
	Variable bin_size
	Variable i,j,num_waves=ItemsInList(wave_list)
	Wave theWave=$StringFromList(0,wave_list)
	Make /o/n=(ceil(numpnts(theWave)*dimdelta(theWave,0)/bin_size)) MeanMedWave=0,SEMMedWave=0
	SetScale /P x,dimoffset(theWave,0),bin_size,MeanMedWave
	String mean_waves=""
	for(i=0;i<num_waves;i+=1)
		Wave theWave=$StringFromList(i,wave_list)
		mean_waves+=MedianWave(theWave,bin_size)+";"
	endfor
	String value_list
	for(i=0;i<numpnts(MedMedWave);i+=1)
		value_list=""
		for(j=0;j<num_waves;j+=1)
			Wave MedWave=$StringFromList(j,mean_waves)
			value_list+=num2str(MedWave(dimoffset(MeanMedWave,0)+i*dimdelta(MeanMedWave,0)))+";"
		endfor
		MeanMedWave[i]=MeanList(value_list)
		SEMMedWave[i]=SEMList(value_list)
	endfor
	Display /K=1 MeanMedWave
	ErrorBars MeanMedWave,Y wave=(SEMMedWave,SEMMedWave)
End

Function KillPeakWaves()
	Variable i,j
	SVar allChannels=root:parameters:allChannels
	for(i=0;i<ItemsInList(allChannels);i+=1)
		String channel=StringFromList(i,allChannels)
		if(DataFolderExists("root:Minis:"+channel))
			SetDataFolder root:Minis:$channel
			String dir_str=DataFolderDir(-1)
			String folders=StringByKey("FOLDERS",dir_str)
			for(j=0;j<ItemsInList(folders,",");j+=1)
				String folder=StringFromList(j,folders,",")
				SetDataFolder root:Minis:$(channel):$folder
				KillWaves /Z Peak_wave
			endfor
		endif
	endfor
	SetDataFolder root:
End

// Compute the latency between one event and another (for example, UpstateBegins and UpstateFirstSpikes) for each condition
Function EventLatency(event_1,event_2)
	String event_1,event_2
	root()
	Variable i; String folder
	Wave /T FileName
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:"+FileName[i]
		root()
		if(DataFolderExists(folder))
			SetDataFolder $folder
			Wave Event1=$event_1
			Wave Event2=$event_2
			Duplicate /o Event1 Latencies
			Latencies=Event2-Event1
		endif
	endfor
	root()
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

// Cut out a region between the cursors (a region according to the scale of the wave) for all waves on the specified graph.  
Function Cut3([win,mask])
	String win,mask
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	if(ParamIsDefault(mask))
		mask="*"
	endif
	String traces=TraceNameList(win,";",1)
	traces=ListMatch(traces,mask)
	Variable i,start,finish
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace=StringFromList(i,traces)
		Wave theWave=TraceNameToWaveRef(win,trace)
		start=x2pnt(theWave,xcsr(A))
		finish=x2pnt(theWave,xcsr(B))
		DeletePoints start, finish-start, theWave
	endfor
End

