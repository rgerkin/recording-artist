// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Batch%20Experiment%20Processing.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

Function DoOnExperiments()
	root()
	Variable i,j;String folder
	Wave /T FileName
	for(i=0;i<numpnts(FileName);i+=1)
		folder="root:Cells:VC:"+FileName[i]+"_VC"
		root()
		//print folder
		if(DataFolderExists(folder))
			SetDataFolder $folder
			if(waveexists(U_Averages) && waveexists(U_NoiseNS))
				print folder
				Wave U_Averages,U_NoiseNS
				Make /o/n=(numpnts(U_Averages)) U_CV
				U_CV=U_NoiseNS/U_Averages
			else
				Make /o/n=0 U_Noise
			endif
			//Wave U_Intervals,UpstateOn,UpstateOff
			//U_Intervals=UpstateOn-UpstateOff[p-1]
			//U_Intervals[0]=NaN
		endif
	endfor
End

// Does stuff to all the .pxp files in a directory.  Supports recursive directory searching, but doesn't save the .pxp file.  
Function Do2PXPs2(path[,list])
	String path,list
	String desktop_dir=SpecialDirPath("Desktop",0,0,0)
	if(!StringMatch(path[strlen(path)-1],":"))
		path+=":"
	endif
	if(ParamIsDefault(list))
		list=LS(path,mask="*.pxp")
	endif
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		String file=StringFromList(i,list)
		String full_path=path+file
		// Do this to each pxp.  
			print full_path
			root(); KillRecurse("*")
			LoadData /Q/O=2/R full_path
			ConcatWC()
			NewPath /O/Q Desktop,desktop_dir
			Save /P=Desktop ConcatSweep as RemoveEnding(file,".pxp")+".ibw"
		//
	endfor
	String directories=LS_Directory(path)
	for(i=0;i<ItemsInList(directories);i+=1)
		String directory=StringFromList(i,directories)
		Do2PXPs2(path+directory)
	endfor
End

// Does stuff to all the .pxp files in a directory.  If it isn't working, be sure to check that your path is correct.  
Function Do2PXPs(path[,list,match,i])
	String path // A full directory path (not a symbolic path) with escaped slashes.  Should end with a path separator (colon or slash).  
	String match // A mask for the file name to match.  
	String list // A list of files to operate on.
	Variable i // Start from this index of the list.  
	i=ParamIsDefault(i) ? 0 : i
	if(!StringMatch(path[strlen(path)-1],":"))
		path+=":"
	endif
	if(ParamIsDefault(match))
		match="*"
	endif
	if(ParamIsDefault(list))
		list=LS(path,mask="*.pxp")
	endif  
	if(i==0)
		//SetIgorHook AfterFileOpenHook=$"" // Don't use file open hooks during this loop.  
	endif
	
	String file=StringFromList(i,list)
	if(StringMatch(file,match))
		if(i>0)
			Execute /P/Q "NEWEXPERIMENT "
			//Execute /P/Q "SaveExperiment /P=Igor as \"garbage.pxp\"" 
			// Due to some problem with the operation queue, I have to save the new experiment 
			// before opening a new one to avoid getting a save dialog.  
		endif
	
		String full_path=path+file
		String command="LOADFILE "+full_path
		//print command
		Execute /P/Q command
		//Execute /P/Q "COMPILEPROCEDURES "
		// ---- Insert code to do to each .pxp file here. It should be in Execute /P form otherwise it will executed before the file is loaded.----  
		
	//	Execute /P/Q "BackwardsCompatibility()"
	//	Execute /P/Q "SplitSweeps(max_duration=30)"
	//	Execute /P/Q "SimplifyExperiment()"
	//	Execute /P/Q "NewPath /Q Simp, reverb_data_dir+\"Simplified\""
	//	Execute /P/Q "SaveExperiment /P=Simp as RemoveEnding(\""+file+"\",\".pxp\")+\"_simplified.pxp\""
		
		Execute /P/Q "ReverbPrintoutManager()"
		Execute /P/Q "root:Packages:ReverbPrintout:Downsample=10"
		Execute /P/Q "ReverbPrintout(\"ReverbPrintout\")"
		Execute /P/Q "RPM_Save(\"\")"
		
		// -------------------------------------------------------------------
	endif
	i+=1
	if(i<ItemsInList(list))
		path=ReplaceString("\\",path,"\\\\")
		//String recursion_cmd="Do2PXPs(\""+path+"\",list=\""+list+"\",i="+num2str(i)+")"
		//command="Do2PXPs(\""+path+"\",list=root:g_list,i="+num2str(i)+")"
		//print strlen(command)
		command="Do2PXPs(\""+path+"\",match=\""+match+"\",i="+num2str(i)+")"
		//print "wehgjarwgbwr"
		print command
		Execute /P/Q command
	else
		//SetIgorHook AfterFileOpenHook=AfterFileOpenHook // Restore the file open hook after the loop has completed.  
	endif
End

Function Do2IBWs([path])
	String path
	root()
	if(ParamIsDefault(path))
		path=data_dir
	endif
	path=Windows2IgorPath(path)
	NewPath /O IBWPath path
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+".ibw"
		if(WhichListItem(ibw,ibw_list)>=0)
			LoadWave /O/P=IBWpath ibw
			wave_name=StringFromList(0,S_wavenames)
			Display /K=1 $wave_name
			Textbox Condition[i]+"-----"+FileName[i]
			SavePICT/O/P=IBWPath/E=-6/B=288 as Condition[i]+"_"+FileName[i]+".jpg"
			DoWindow /K $TopWindow()
			KillWaves $wave_name 
		endif
	endfor
	//KillPath IBWPath
End

// Replaces the traces in the 'Sweeps' window with ones that are fully sampled from the original data.  
Function ReplaceWithFullSampling()
	DoWindow /F Sweeps
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O root:Packages
	NewDataFolder /O root:Packages:RWFP
	Variable i
	String file_name=IgorInfo(1)
	if(!StringMatch(file_name,"*simplified*"))
		return 0
	endif
	file_name=RemoveEnding(file_name,"_simplified")
	NewPath /O/Q RWFP_Path,data_dir+"All:"
	String traces=TraceNameList("Sweeps",";",3)
	SVar all_channels=root:parameters:all_channels
	for(i=0;i<ItemsInList(all_channels);i+=1)
		String channel=StringFromList(i,all_channels)
		String /G root:Packages:RWFP:$(channel)=""
	endfor
	String objects=""
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace=StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef("Sweeps",trace)
		channel=GetWavesDataFolder(TraceWave,0)
		channel=channel[4,5]
		trace=StringFromList(0,trace,"#")
		SVar channel_list=root:Packages:RWFP:$(channel)
		channel_list+=trace+";"
	endfor
	for(i=0;i<ItemsInList(all_channels);i+=1)
		channel=StringFromList(i,all_channels)
		SVar channel_list=root:Packages:RWFP:$(channel)
		if(strlen(channel_list)==0)
			continue
		endif
		SetDataFolder root:$("cell"+channel)
		LoadData /J=channel_list/O/P=RWFP_Path /Q/S="cell"+channel file_name+".pxp"
	endfor
	KillPath /Z RWFP_Path
	KillDataFolder root:Packages:RWFP
	SetDataFolder $curr_folder
End

// Update the reverberation database by loading all experiment files in 'sub_dir' that aren't already described in the database, and storing relevant information from those files in the database.  
Function UpdateReverbDatabase(sub_dir[,first_skip_to_sql])
	String sub_dir // A directory where files are stored, e.g. "2007.01"
	Variable first_skip_to_sql // If the data and compression for the first file that will be encountered is already in memory, skip directly to the SQL steps.  This is useful
	// because the data for a given experiment may already be loaded in the case that it was some SQL step that failed, and a bug is subsequently fixed.   
	
	// Searching for files.  
	String reverb_data_location="C:Reverberation Project:Data:"+sub_dir
	NewPath /O/Q ReverbDataFolder,reverb_data_location
	String files=LS(reverb_data_location,mask="*.pxp")
	
	root()
	SetWaveLock 0,allInCDF // Unlock previously locked waves.  
	
	// Connect to the database and find out which experiments are already there.  
	Execute /Q "SQLConnect \"Reverb\",\"\",\"\""
	SQLc("SELECT Experimenter,File_Name FROM Island_Record")
	Wave /T Experimenter,File_Name
	SetWaveLock 1,Experimenter,File_Name // Lock down these waves so they don't get deleted.  
	
	// Initialize variables and get the names of the columns from the database tables.  
	Variable i,j,k,index,rows,num_completed=0; String file,used_channels,channel,notebook_names,notebook_name
	String sr_w_list=SQL_GetColumnNames("Sweep_Record")
	String sa_w_list=SQL_GetColumnNames("Sweep_Analysis")
	
	for(i=0;i<ItemsInList(files);i+=1)
		root()
		file=StringFromList(i,files)
		String /G name=ReplaceString(".pxp",file,"")
		index=TextWaveSearch(File_Name,name)
		if(index < 0) // Assumes there is not already an experiment with the same file name but a different experimenter in the database.  
			print "Adding "+name+" to the database"
			if(!first_skip_to_sql || num_completed) // If this is not the first one or the data is not already in memory
				LoadData /Q/O=2/R/P=ReverbDataFolder file
				// Now that the data is loaded, process it for storage.  
					BackwardsCompatibility()
					DoWindow /F/H
					ReduceAllDWT() // Perform the sweep compression.  
					used_channels=Reductions2Access(file_name_str=name,sweep_offset=0) // Format the information so that it can be easily put into the database.  
				//
			else
				SVar g_used_channels=root:g_used_channels
				used_channels=g_used_channels
			endif
			// The SQL Updating.  
					// Get the experiment notebook and insert the experiment into Island_Record.  
					Close /A
					notebook_name=CleanupName(name+"_notebook",0)
					ExtractPackedNotebooks("ReverbDataFolder",file,notebook_names=notebook_name)
					OpenNotebook /N=$notebook_name /P=ReverbDataFolder notebook_name
					String /G notebook_text=Log2Clip(notebook_name=notebook_name)
					notebook_text=SQL_StringClean(notebook_text)
					String /G sql_str="INSERT INTO Island_Record (Experimenter,File_Name,Filled,Comments) VALUES ('RCG','<<<name>>>',0,'<<<notebook_text>>>')"
					SQLc(sql_str)
					DoWindow /K $(notebook_name)
					
					// Add the sweep information to Sweep_Record
					SetDataFolder root:reanalysis:SweepReductions
					Wave /T File_Name; File_Name=name
					String /G sr_wave_list=ReplaceString(";",sr_w_list,",") // Make a global, and replace semi-colons with commas.  
					sr_wave_list=RemoveEnding(sr_wave_list)  // Get rid of the final comma.  
					String /G wave_list_indexed
					for(j=0;j<numpnts(Sweep);j+=1)
						wave_list_indexed=StringFromIndex(j,sr_w_list,sep=",") // Get a string of values, comma separated.  
						wave_list_indexed=AddFlanking(wave_list_indexed,"'",sep=",") // Add the single quotes.  
						wave_list_indexed=RemoveEnding(wave_list_indexed) // Remove the final comma.  
						wave_list_indexed=ReplaceString("'NaN'",wave_list_indexed,"NULL") // Replace NaN with NULL.  
						String /G sql_str="INSERT INTO Sweep_Record (<<<sr_wave_list>>>) VALUES (<<<wave_list_indexed>>>)"
						SQLc(sql_str)
						wave_list_indexed=ReplaceString("["+num2str(j)+"]",wave_list_indexed,"[curr_index]")
					endfor
					
					// Add the channel information to Sweep_Analysis
					for(k=0;k<ItemsInList(used_channels);k+=1)
						channel=StringFromList(k,used_channels)
						SetDataFolder root:reanalysis:SweepReductions:$channel
						Wave /T File_Name; File_Name=name
						String /G sa_wave_list=ReplaceString(";",sa_w_list,",") // Make a global, and replace semi-colons with commas.  
						sa_wave_list=RemoveEnding(sa_wave_list)  // Get rid of the final comma.  
						String /G wave_list_indexed
						for(j=0;j<numpnts(Sweep);j+=1)
							wave_list_indexed=StringFromIndex(j,sa_w_list,sep=",") // Get a string of values, comma separated.  
							wave_list_indexed=AddFlanking(wave_list_indexed,"'",sep=",") // Add the single quotes.  
							wave_list_indexed=RemoveEnding(wave_list_indexed) // Remove the final comma.  
							wave_list_indexed=ReplaceString("'NaN'",wave_list_indexed,"NULL") // Replace NaN with NULL.  
							String /G sql_str="INSERT INTO Sweep_Analysis (<<<sa_wave_list>>>) VALUES (<<<wave_list_indexed>>>)"
							SQLc(sql_str)
							wave_list_indexed=ReplaceString("["+num2str(j)+"]",wave_list_indexed,"[curr_index]")
						endfor
					endfor
					
				// Cleanup
				KillAll("graphs")
				KillAll("tables")
				KillAll("notebooks")
				root()
				KillRecurse("*") // Kill all the data to prepare for the next file. 
				num_completed+=1 
			//
			//break // Only do this for one file.  
		endif
	endfor
	
	root()
	Wave /T Experimenter,File_Name
	SetWaveLock 0,Experimenter,File_Name // Unlock the waves.  
	Execute /Q "SQLDisconnect" // Disconnect.  
End

// Update the reverberation database by loading all experiment files in 'sub_dir', and storing relevant information from those files in the database, overwriting existing data in the database.  
Function UpdateReverbDatabase2(sub_dir,[greater_than])
	String sub_dir // A directory where files are stored, e.g. "2007.01"
	String greater_than // With file name greater than (by strcmp) 'greater_than'. 
	
	// Searching for files.  
	String reverb_data_location="C:Reverberation Project:Data:"+sub_dir
	NewPath /O/Q ReverbDataFolder,reverb_data_location
	String files=LS(reverb_data_location,mask="*.pxp")
	
	root()
	SetWaveLock 0,allInCDF // Unlock previously locked waves.  
	
	// Connect to the database and find out which experiments are already there.  
	Execute /Q "SQLConnect \"Reverb\",\"\",\"\""
	//SQLc("SELECT Experimenter,File_Name FROM Island_Record")
	//Wave /T Experimenter,File_Name
	//SetWaveLock 1,Experimenter,File_Name // Lock down these waves so they don't get deleted.  
	
	// Initialize variables and get the names of the columns from the database tables.  
	Variable i,j,k,num_completed=0; 
	String sr_w_list=SQL_GetColumnNames("Sweep_Record")
	String sa_w_list=SQL_GetColumnNames("Sweep_Analysis")
	
	for(i=0;i<ItemsInList(files);i+=1)
		String file=StringFromList(i,files)
		String name=ReplaceString(".pxp",file,"")
		if(!ParamIsDefault(greater_than) && cmpstr(name,greater_than)<=0)
			continue
		endif
		print "Adding "+name+" to the database"
		SetDataFolder root:
		KillRecurse("*")
		SetDataFolder root:
		LoadData /Q/O=2/R/P=ReverbDataFolder file
		String used_channels=Info2Access(file_name_str=name) // Format the information so that it can be easily put into the database.  
		
		// The SQL Updating.  
				// Get the experiment notebook and insert the experiment into Island_Record.  
				Close /A
				String notebook_names=ExtractPackedNotebooks("ReverbDataFolder",file,notebook_names=name)
				String notebook_name=StringFromList(0,notebook_names)
				OpenNotebook /N=LogPanel#ExperimentLog /P=ReverbDataFolder notebook_name
				String /G notebook_text=Log2Clip()
				notebook_text=SQL_StringClean(notebook_text)
				String /G sql_str="UPDATE Island_Record SET Comments='<<<notebook_text>>>' WHERE File_Name='"+name+"'"
				SQLc(sql_str,show=0)
				DoWindow /K LogPanel#ExperimentLog
	
				// Add the sweep information to Sweep_Record
				String /G sql_str="DELETE FROM Sweep_Record WHERE File_Name='"+name+"'"
				SQLc(sql_str,show=0)
				SetDataFolder root:reanalysis:SweepReductions
				Wave /T File_Name; File_Name=name
				String /G sr_wave_list=ReplaceString(";",sr_w_list,",") // Make a global, and replace semi-colons with commas.  
				sr_wave_list=RemoveEnding(sr_wave_list)  // Get rid of the final comma.  
				String /G wave_list_indexed
				for(j=0;j<numpnts(Sweep);j+=1)
					wave_list_indexed=StringFromIndex(j,sr_w_list,sep=",") // Get a string of values, comma separated.  
					wave_list_indexed=AddFlanking(wave_list_indexed,"'",sep=",") // Add the single quotes.  
					wave_list_indexed=RemoveEnding(wave_list_indexed) // Remove the final comma.  
					wave_list_indexed=ReplaceString("'NaN'",wave_list_indexed,"NULL") // Replace NaN with NULL.  
					String /G sql_str="INSERT INTO Sweep_Record (<<<sr_wave_list>>>) VALUES (<<<wave_list_indexed>>>)"
					SQLc(sql_str,show=0)
					wave_list_indexed=ReplaceString("["+num2str(j)+"]",wave_list_indexed,"[curr_index]")
				endfor

				// Add the channel information to Sweep_Analysis
				String /G sql_str="DELETE FROM Sweep_Analysis WHERE File_Name='"+name+"'"
				SQLc(sql_str,show=0)
				for(k=0;k<ItemsInList(used_channels);k+=1)
					String channel=StringFromList(k,used_channels)
					SetDataFolder root:reanalysis:SweepReductions:$channel
					Wave /T File_Name; File_Name=name
					String /G sa_wave_list=ReplaceString(";",sa_w_list,",") // Make a global, and replace semi-colons with commas.  
					sa_wave_list=RemoveEnding(sa_wave_list)  // Get rid of the final comma.  
					String /G wave_list_indexed
					
					for(j=0;j<numpnts(Sweep);j+=1)
						wave_list_indexed=StringFromIndex(j,sa_w_list,sep=",") // Get a string of values, comma separated.  
						wave_list_indexed=AddFlanking(wave_list_indexed,"'",sep=",") // Add the single quotes.  
						wave_list_indexed=RemoveEnding(wave_list_indexed) // Remove the final comma.  
						wave_list_indexed=ReplaceString("'NaN'",wave_list_indexed,"NULL") // Replace NaN with NULL.  
						String /G sql_str="INSERT INTO Sweep_Analysis (<<<sa_wave_list>>>) VALUES (<<<wave_list_indexed>>>)"
						SQLc(sql_str,show=0)
						wave_list_indexed=ReplaceString("["+num2str(j)+"]",wave_list_indexed,"[curr_index]")
					endfor
				endfor

		// Cleanup
		KillAll("graphs")
		KillAll("tables")
		KillAll("notebooks")
		root()
		//KillRecurse("*") // Kill all the data to prepare for the next file. 
		num_completed+=1 
		//
		//break // Only do this for one file.  
	endfor
	
	root()
	Execute /Q "SQLDisconnect" // Disconnect.  
End

// Do FFTs on the signals for each cell, and average together ones from the same condition.  
Function FFT2([path])
	String path
	root()
	if(ParamIsDefault(path))
		path=spontaneous_ibw_dir
	endif
	path=Windows2IgorPath(path)
	NewPath /O IBWPath path
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i,j; String ibw,name,folder,condition_str
	String conditions="Control;Seizure"
	Make /o/n=(ItemsInList(conditions)) root:ConditionCounts=0; Wave ConditionCounts
	for(i=0;i<numpnts(FileName);i+=1)
		root()
		folder=FileName[i]
		ibw=FileName[i]+".ibw"
		if(DataFolderExists("root:"+folder))
			name=LoadIBW(ibw)
			print name
			Wave theWave=$name
			FFT /PAD=(NextPowerOf2(numpnts(theWave))) /OUT=4 /DEST=MagSquared theWave
			if(i==0)
				for(j=0;j<ItemsInList(conditions);j+=1)
					condition_str=StringFromList(j,conditions)
					Duplicate /o MagSquared root:$(condition_str+"_Spectrum")
					Wave Spectrum=root:$(condition_str+"_Spectrum")
					Spectrum=0
				endfor
			endif
			condition_str=Condition[i]
			Wave Spectrum=root:$(condition_str+"_Spectrum")
			Spectrum+=MagSquared
			ConditionCounts[WhichListItem(condition_str,conditions)]+=1
			KillWaves /Z theWave,MagSquared
		endif
	endfor
	root()
	Display /K=1
	for(j=0;j<ItemsInList(conditions);j+=1)
		condition_str=StringFromList(j,conditions)
		Wave Spectrum=root:$(condition_str+"_Spectrum")
		Spectrum/=ConditionCounts[WhichListItem(condition_str,conditions)]
		Condition2Color(condition_str); NVar red,green,blue
		AppendToGraph /c=(red,green,blue) Spectrum
	endfor
	ModifyGraph log=1
	KillVariables /Z red,green,blue
	root()
	//KillPath IBWPath
End

// Removes noise from all the Igor binary files in a given location, and then saves them again.  
Function DenoiseAllIBWs([path])
	String path
	root()
	if(ParamIsDefault(path))
		path=spontaneous_ibw_dir
	endif
	path=Windows2IgorPath(path)
	NewPath /O/Q IBWPath path
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name
	Display /K=1 /N=ToDenoise
	for(i=0;i<ItemsInlist(ibw_list);i+=1)
		print i
		ibw=StringFromList(i,ibw_list)
		print ibw
		LoadWave /O/Q/P=IBWPath ibw
		String loaded_name=StringFromList(0,S_Wavenames)
		Wave theWave=$loaded_name
		//AppendToGraph theWave
		DoUpdate
		Sleep /S 2
		LineRemove(theWave)
		print "Denoised..."
		DoUpdate
		Sleep /S 2
		Save /O/P=IBWPath theWave as ibw
		//RemoveFromGraph $NameOfWave(theWave)
		DoUpdate
		KillWaves theWave
	endfor
	DoWindow /K ToDenoise
	root()
	//KillPath IBWPath
End

// Calculates input resistance based on the test pulses that occur pseudo-randomly throughout the data.  
Function InputRContinuousDataVC2([path])
	String path
	root()
	if(ParamIsDefault(path))
		path=spontaneous_ibw_VC_dir
	endif
	path=Windows2IgorPath(path)
	NewPath /O/Q IBWPath path
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+"_VC"+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0)
			InputRContinuousDataVC(ibw=ibw,path=path)
		endif
	endfor
	root()
	//KillPath IBWPath
End

Function InputRContinuousDataVC([ibw,path])
	String ibw,path
	
	root()
	if(ParamIsDefault(path))
		path=spontaneous_ibw_VC_dir
	endif
	// Get the signal.  
	if(ParamIsDefault(ibw))
		Wave theWave=CsrWaveRef(A)
	else
		Wave theWave=$LoadIBW(ibw,path=path,type="VC") // Load the IBW and change the data folder.  
		print GetDataFolder(1)
	endif
	string curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:IR_Segments
	WaveStats /Q theWave
	Variable thresh=V_avg+(V_max-V_avg)*0.67
	Variable i=0,before,after,input_r
	if(thresh>50)
		Extract /O/INDX theWave, indexWaveIR, (theWave[p]>thresh && theWave[p-1]<=thresh)
		//FindLevels /Q /D=indexWaveIR theWave,thresh
		//indexWave*=dimdelta(theWave,0)
		//indexWave+=dimoffset(theWave,0)
		//Display /K=1
		Make /o/n=(numpnts(indexWaveIR)) IR_Befores=NaN,IR_Afters=NaN
		Variable diff,scale=dimdelta(theWave,0),range=0.08,range_points=range/scale
		for(i=0;i<numpnts(indexWaveIR);i+=1)
			Duplicate /o /R=[indexWaveIR[i]-range_points,indexWaveIR[i]+range_points] theWave $("IR_Segment_"+num2str(i))
			Wave Segment=$("IR_Segment_"+num2str(i))
			SetScale /P x,0,scale,Segment
			WaveStats /Q Segment
			diff=round((V_maxloc-range)/scale)
			//print diff
			Rotate -diff,Segment
			if(diff<0)
				Segment[numpnts(Segment)-diff,numpnts(Segment)-1]=NaN
			elseif(diff>0)
				Segment[0,diff-1]=NaN
			endif
			SetScale /P x,0,scale,Segment
			WaveStats /Q /R=(range-0.02,range-0.01) Segment; before=V_avg
			WaveStats /Q /R=(range+0.05,) Segment; after=V_avg
			IR_Befores[i]=before
			IR_Afters[i]=after
			//AppendToGraph Segment
			KillWaves /Z Segment
		endfor
	endif
	if(i>0)
		before=Median2(IR_Befores)
		after=Median2(IR_Afters)
		input_r=5000/abs(after-before)
		print num2str(input_r)+" MOhms"
	else
		before=NaN; after=NaN
		input_r=NaN
		print "No test pulse regions found."
	endif
	print ibw
	if(StringMatch(ibw,"Rick_05_11_22_B_VC.ibw"))
		input_r=714 // Measured manually (one test pulse).  
	endif
	if(StringMatch(ibw,"Rick_2006_07_21_b_D_VC.ibw"))
		input_r=NaN // Not really broken in.    
	endif
//	//AlignTraces(0,0.3)
//	if(i>0)
//		Duplicate /O Segment IR_Segment_Mean; IR_Segment_Mean=0
//		for(i=0;i<numpnts(indexWaveIR);i+=1)
//			Wave Segment=$("IR_Segment_"+num2str(i))
//			IR_Segment_Mean+=Segment
//		endfor
//		IR_Segment_Mean/=i
//		AppendToGraph IR_Segment_Mean
//		ModifyGraph lsize($TopTrace())=3
//	endif
	SetDataFolder $curr_folder
//	Differentiate /METH=2 theWave /D=IRdiffWave
//	WaveStats /Q IRdiffWave
//	Variable before=mean(theWave,V_maxloc-0.01,V_maxloc-0.001)
//	Variable after=mean(theWave,V_maxloc+0.5,V_maxloc+0.7)
//	Variable input_R=5/abs(after-before)
//	print input_R
	Make /o/n=1 InputR=input_r
//	print before,after,V_maxloc
	KillWaves /Z theWave IRdiffWave
	root()
	//KillPath IBWPath
End

// ReduceAll using a DWT instead of the custom algorithm.  
Function ReduceAllDWT()
	Variable tick=ticks
	Variable i,j,sweep_num
	SVar channels=root:parameters:active_channels
	String channel
	Display /K=1 /N=Reductions
	String /G curr_info=""
	Textbox /N=CurrInfo curr_info
	NewDataFolder /O/S root:reanalysis:SweepReductions
	String /G compress_method="DWT"
	Variable insig_val,start,interval,duration
	Variable old_points=0,new_points=0 
	NVar final_sweep=root:currentSweepNum
	Make /o/n=0 Empty
	for(i=0;i<ItemsInList(channels);i+=1)
		channel=StringFromList(i,channels)
		SetDataFolder root:reanalysis:SweepReductions
		Make /O/n=(final_sweep) $("SweepAverages"+channel)=0 // Average values of each sweep before they are subtracted off.  
		Make /O/n=(final_sweep) $("SweepScales"+channel)=0 // Scales of each sweep, destroyed in the DWT process.  
		Make /O/n=(final_sweep) $("SweepPoints"+channel)=0 // Number of points in each sweep, to be used for reconstruction.    
		Wave SweepAverages=$("SweepAverages"+channel)
		Wave SweepScales=$("SweepScales"+channel)
		Wave SweepPoints=$("SweepPoints"+channel)
		NewDataFolder /O/S $("root:reanalysis:SweepReductions:"+channel)
		Wave SweepParams=$("root:sweep_parameters_"+channel)
		for(sweep_num=1;sweep_num<=final_sweep;sweep_num+=1)
		//for(sweep_num=42;sweep_num<=42;sweep_num+=1)
			RemoveTraces()
			Wave /Z theWave=$("root:cell"+channel+":sweep"+num2str(sweep_num))
			if(waveexists(theWave))
				Duplicate /o theWave $"toReduce"
				Wave toReduce
				AppendToGraph toReduce
				if(SweepParams[sweep_num][5]==1) // Voltage Clamp
					insig_val=50
				elseif(SweepParams[sweep_num][5]==0) // Current Clamp
					insig_val=5
				else
					Print "Clamp for sweep "+num2str(sweep_num)+" is unknown"
					insig_val=max(insig_val,5)
				endif
				//print insig_val
				
				// Subtract off the average and store it.  Also store the point scaling of the sweep.  
				WaveStats /Q toReduce
				toReduce-=V_avg
				SweepAverages[sweep_num-1]=V_avg
				SweepScales[sweep_num-1]=dimdelta(toReduce,0)
				SweepPoints[sweep_num-1]=numpnts(toReduce)
				
				// Remove 60 Hz.  
				LineRemove(toReduce,freqs="60",width=1,harmonics=10)
				
				// Do the DWT, set all values below a threshold to zero, save the locations and values of non-zero values.  
				Wave dwtd=$DWTDenoise(toReduce,insig_val); Wave alllocs, allvals
				//DWT /P=2 toReduce,Dwtd
				//Dwtd=(abs(dwtd)>insig_val) ? Dwtd : 0
				//Extract /INDX /O Dwtd,$"alllocs",Dwtd!=0; Wave alllocs
				//Extract /O Dwtd,$"allvals",Dwtd!=0; Wave allvals
				
				// Do the inverse DWT and plot it on top of the original sweep, so they can be compred.  
				DWT /P=2 /I Dwtd,Dwtd
				CopyScales toReduce,Dwtd
				CleanAppend("Dwtd",color="0,0,0")
				
				// Store the compressed (non-zero DWT values) version and update the window to reflect that it has been compressed.  Also show the amount of compression.  
				Wave alllocs=alllocs
				old_points+=numpnts(toReduce)
				new_points+=numpnts(alllocs)
				curr_info=channel+": "+num2str(sweep_num)+"; "+num2str(100*new_points/old_points)+"%"
				TextBox /C /N=CurrInfo curr_info
				Duplicate /o alllocs $("locs_"+num2str(sweep_num))
				Duplicate /o allvals $("vals_"+num2str(sweep_num))
				DoUpdate
				KillWaves /Z toReduce
				//print channel+":"+num2str(sweep_num)
			endif
		endfor
	endfor
	KillWaves /Z Dwtd,alllocs,allvals
	tick=ticks-tick
	print "Ratio = 2 * "+num2str(new_points)+" / "+num2str(old_points)+" = "+num2str(100*2*new_points/old_points)+" % in "+num2str(tick/60)+" seconds"
	root()
End

// Look for Igor binary files in a given directory that have a NaN value somewhere.  
Function IBWNans([path])
	String path
	root()
	if(ParamIsDefault(path))
		path=spontaneous_ibw_VC_dir
	endif
	path=Windows2IgorPath(path)
	NewPath /O IBWPath path
	Wave /T FileName,Condition,Experimenter
	String ibw_list=ListMatch(LS(path),"*.ibw")
	Variable i; String ibw,name,loaded_name,folder,wave_name
	for(i=0;i<numpnts(FileName);i+=1)
		ibw=FileName[i]+"_VC"+".ibw"
		root()
		if(WhichListItem(ibw,ibw_list)>=0)
		print ibw
			if(!DataFolderExists("root:Cells:VC:"+FileName[i]+"_VC"))
				Wave theWave=$LoadIBW(ibw,path=path,type="VC") // Load the IBW and change the data folder.
				WaveStats /Q theWave
				if(V_numNaNs > 0) // Display the first IBW with a NaN value and halt.  
					Display /K=1 theWave
					abort 
				endif
				KillWaves theWave
			endif
		endif
	endfor
	root()
	//KillPath IBWPath
End

Macro Next()
	myText="";index+=1;DoWindow /K Gaga;KillWaves /Z $wave_name
	LoadWave /O/P=IBWpath root:FileName[index]+".ibw";wave_name=StringFromList(0,S_wavenames);Display /K=1 /N=Gaga $wave_name;Textbox Condition[index]+"-----"+FileName[index]
	MoveWindow 0,0,1000,520
	Cursors()
End

Function LoadAndConcatIBW(list,ds_factor)
	String list // List of ibw stems
	Variable ds_factor // Degree to which each one should be downsampled before concatenating
	Variable i,j; String file,item
	Make /o/n=0 LongSweep
	NewPath /O/Q FilePath, "C:Documents and Settings:Rick:Desktop:Spontaneous Firing (Roger):"
	i=0
	Do
		file=IndexedFile(FilePath,i,".ibw")
		print file
		if(strlen(file)==0)
			break
		else
			for(j=0;j<ItemsInList(list);j+=1)
				item=StringFromList(j,list)
				item=ReplaceString("f",item,"")
				item=StringFromList(1,item,"_")+StringFromList(2,item,"_")+StringFromList(0,item,"_")+StringFromList(3,item,"_")+"-RCSpikes.ibw"
				//print item
				if(StringMatch(file,item))
					LoadWave /P=FilePath /Q file
					Wave sweep=$StringFromList(0,S_WaveNames)
					DownSample(sweep,10)
					Concatenate /NP {sweep}, LongSweep
					CopyScales sweep,LongSweep
					KillWaves sweep
				endif
			endfor
			i+=1
		endif
	While(1)
End

// Loads the .ibw's named in file_list (do not actually append ".ibw")
Function LoadWaves(file_list[,stem])
	String file_list,stem
	stem=SelectString(ParamIsDefault(stem),stem,"")
	Variable i; String file
	for(i=0;i<ItemsInList(file_list);i+=1)
		file=StringFromList(i,file_list)
		LoadWave /H file+stem+".ibw"
	endfor
End

// Perform some operation on a bunch of IBWs
Function IBWBatch(directory,[func,mask])
	String directory
	Funcref PlotUpStates func
	String mask
	if(ParamIsDefault(mask))
		mask="*"
	endif
	String ibw_list=LS(directory,mask=mask)
	ibw_list=ListMatch(ibw_list,"*.ibw")
	Variable i; String ibw,wave_name,folder
	for(i=0;i<ItemsInList(ibw_list);i+=1)
		ibw=StringFromList(i,ibw_list)
		folder=GetDataFolder(1)
		LoadWave directory+":"+ibw
		wave_name=StringFromList(0,S_Wavenames)
		ibw=ReplaceString(".ibw",ibw,"")
		Rename $wave_name $ibw
		Display /K=1/N=CurrIBW $ibw
		Cursors();Spikes()
		//PlotSpikes(min_colorval=0.05,max_colorval=10,order="ISI")
		//TextBox /C/N=Caption ibw
		//SavePICT/E=-6/B=288 as ibw+".jpg"
		DoWindow /K CurrIBW
		//DoWindow /K $TopWin()
		SetDataFolder $folder
		if(!datafolderexists("root:'"+ibw+"_Folder'"))
			RenameDataFolder root:reanalysis, $(ibw+"_Folder")
		else
			RenameDataFolder root:reanalysis, $(ibw+"_Folder0")
		endif
		KillDataFolder /Z root:reanalysis
		KillWaves /Z $ibw
	endfor
End

Function FindMissingValues(sub_dir)
	String sub_dir
	String full_path="C:Reverberation Project:Data:"+sub_dir
	NewPath /O/Q SearchPath full_path
	String files=LS(full_path,mask="*.pxp")
	Variable i
	for(i=0;i<ItemsInList(files);i+=1)
		String file=StringFromList(i,files)
		LoadData /O/J="currentSweepNum" /P=SearchPath /Q file
		NVar currentSweepNum
		if(currentSweepNum>0)
		else
			print file+": "+num2str(currentSweepNum)
		endif
	endfor
End