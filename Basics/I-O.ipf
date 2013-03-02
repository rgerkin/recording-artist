
// $Author: rick $
// $Rev: 626 $
// $Date: 2013-02-07 09:36:23 -0700 (Thu, 07 Feb 2013) $

#pragma rtGlobals=1		// Use modern global access method.
#ifndef Acq
override strconstant DAQs=""
#endif

Function /S DesktopDir()
	return SpecialDirPath("Desktop",0,0,0)
End

Function FileExists(path,file)
	String path,file
	
	String files=IndexedFile($path,-1,"????")
	if(WhichListItem(file,files)>=0)
		return 1
	else
		return 0
	endif
End

Function DirExists(path,folder)
	String path,folder
	
	String folders=IndexedDir($path,-1,0)
	if(WhichListItem(folder,folders)>=0)
		return 1
	else
		return 0
	endif
End

Function SaveUnpacked([location])
	String location
	// Create a path
	if(ParamIsDefault(location))
		NewPath /Q/C/O save_path
	else
		NewPath /Q/C/O save_path, location
	endif
	if(!exists("root:last_save_time"))
		Variable /G root:last_save_time=0
	endif
	NVar last_save_time=root:last_save_time
	
	// Copy all the window macros to a text file
	String windows=WinList("*",";","WIN:87")
	Variable i,j,ref_num; String win,macro_text
	Open /P=save_path ref_num as "Windows.txt"
	for(i=0;i<ItemsInList(windows);i+=1)
		win=StringFromList(i,windows)
		macro_text=WinRecreation(win,0)
		fbinwrite ref_num,macro_text
	endfor
	Close ref_num
	
	// Save notebook
	SaveNotebook /P=save_path /O /S=2 LogPanel#ExperimentLog as "ExperimentLog"
	
	// Save data
	SetDataFolder root:
	SaveData/O/P=save_path /Q/D=1/L=7/M=(last_save_time)/R ":"
	last_save_time = datetime
End

Function LoadUnpacked([location])
	String location
	
	// Create a path
	if(ParamIsDefault(location))
		NewPath /Q/C/O load_path
	else
		NewPath /Q/C/O load_path, location
	endif
	
	// Load data
	LoadData /Q/O/R/D/P=load_path ":"
	
	// Reconstruct windows
	Variable ref_num; String line
	Open /Z/R/P=load_path ref_num as ":Windows.txt"
	Do
		FReadLine ref_num,line
		if(strlen(line)==0)
			break
		endif
		Execute /Q/Z line
	While(1)
	Close ref_num
	
	// Load notebook
	OpenNotebook /Z/N=ExperimentLog /P=load_path "ExperimentLog"
End

Function LoadIBWs([directory,mask])
	String directory,mask
	if(ParamIsDefault(mask))
		mask="*"
	endif
	mask=mask+".ibw"
	if(ParamIsDefault(directory))
		NewPath /Q/O LoadIBWsPath
	else
		NewPath /Q/O LoadIBWsPath,directory
	endif
	PathInfo LoadIBWsPath
	directory=S_path
	String files=LS(directory,mask=mask)
	Variable i
	for(i=0;i<ItemsInList(files);i+=1)
		String file_name=StringFromList(i,files)
		String wave_name=RemoveEnding(file_name,".ibw")
		LoadWave /Q/N=wave_name/P=LoadIBWsPath file_name
		String wave_loaded=StringFromList(0,S_waveNames)
		if(!StringMatch(wave_loaded,wave_name))
			Duplicate /O $wave_loaded, $wave_name
			KillWaves /Z $wave_loaded
		endif
	endfor
End

function NumLinesInFile(refNum)
	variable refNum
	
	FStatus refNum
	variable currPos=v_filepos
	FSetPos refNum,0
	string line
	variable numLines
	do
		FReadLine refNum,line
		if(!strlen(line))
			break
		endif
		numLines+=1
	while(1)
	FSetPos refNum,currPos
	return numLines
end

Function PrintAllLayouts()
	Variable i
	String layout_name,layouts=WinList("*",";","WIN:4")
	for(i=0;i<ItemsInList(layouts);i+=1)
		layout_name=StringFromList(i,layouts)
		PrintLayout $layout_name
	endfor
End

Function SaveDataInPackedFile([path_name,file_name])
	String path_name				// Name of symbolic path
	String file_name				// Name of packed file to be written
	String desktop_dir=SpecialDirPath("Desktop",0,0,0)
	if(ParamIsDefault(path_name))
		NewPath /O/Q Desktop,desktop_dir
		path_name="Desktop"
	endif
	if(ParamIsDefault(file_name))
		file_name=IgorInfo(1)+".pxp"
	endif
	SaveData/R/P=$path_name file_name
End

// For loading data from Pakming's experiments (.atf files).  
Function pClampLoad()
	Variable channels
	String channel_info,units
	KillWaves /Z Header0,wave0,thyme
	Do
		LoadWave /A=Header/J/K=2/L={0,0,10,0,1}/M/O/Q/V={"~","",0,0} // Load header information for a file (~ is a character that will never occur)
		if(!waveexists(Header0))
			break
		endif
		Wave /T Header0
		channel_info=Header0[7]
		channel_info=StringFromList(1,channel_info,"=")
		channels=ItemsInList(channel_info,",")
		units=Header0[9]
		if(StringMatch(units,"*pA*"))
			units="pA"
		elseif(StringMatch(units,"*nA*"))
			units="nA"
		else
			printf "Invalid Units.\r"; return 0
		endif
		LoadWave /A/J/L={9,10,0,0,0}/M/Q S_path+S_filename; Wave wave0
		printf "Loading %d channels from %s (%s -> pA).\r",channels,s_fileName,units
		Variable i,j,sweep
		if(!waveexists(wave0))
			break
		endif
		String name=CleanupName(StringFromList(0,S_filename,"."),0)
		Duplicate /O/R=()(0,0) wave0 $(name+"_time")  // Extract time column
		Wave thyme=$(name+"_time")
		DeletePoints /M=1 0,1,wave0 // Remove time column
		if(StringMatch(units,"nA"))
			wave0*=1000
		endif
		for(i=0;i<channels;i+=1)
			Duplicate /o wave0 $(name+"_chan"+num2str(i+1)) 
			Wave chanWave=$(name+"_chan"+num2str(i+1))
			j=channels-i-1
			// Delete every other row to leave only channel 1
			Do
				DeletePoints /M=1 j,channels-1,chanWave
				j+=1
			While(j<dimsize(chanWave,1))
			SetScale /P x,thyme[0],thyme[1],chanWave
		endfor
		KillWaves Header0,wave0,thyme
	While(1)
End

// Makes a new file name based on the current date and which letters have already been taken amongst
// files on the desktop; e.g. 2007.01.05.c.  
Function /S NewFileName([path])
	String path
	if(ParamIsDefault(path))
		String path_str=SpecialDirPath("Desktop",0,0,0)
	else
		PathInfo $path
		path_str=S_path
	endif
	String curr_files=LS(path_str)
	Variable i=0,unique=0; String match,letter,date_formatted,name
	date_formatted=FormatDate()
	Do
		letter=num2char(97+i)
		name=FormatDate()+"_"+letter
		match=ListMatch(curr_files,name+"*")
		if(IsEmptyString(match))
			unique=1
			break
		else
			i+=1
		endif
	While(i<=26)
	if(unique)
		return name
	else
		return ""
	endif
End

Function PrintoutManager()
	if(!DataFolderExists("root:PrintoutInfo"))
		NewDataFolder /O/S root:PrintoutInfo
		Make /T/o/n=0 PreBaselineSweeps,PostBaselineSweeps,InductionSweeps; 
		Variable /G induction_number=1
	endif
	SetDataFolder root:PrintoutInfo
	DoWindow /K PrintoutPanel
	DoWindow /K STDPSweepsTable
	Edit /K=1 /N=STDPSweepsTable
	AppendToTable PreBaselineSweeps
	AppendToTable InductionSweeps
	AppendToTable PostBaselineSweeps
	MoveWindow /W=STDPSweepsTable 0,0,325,150
	NewPanel /W=(450,100,890,225) /K=1 /N=PrintoutPanel as "Printout Manager"
	Button AddPreBaselineSweeps size={140,25},pos={0,0}, title="Add Pre Baseline Sweeps",proc=AddPrintoutSweeps
	Button AddInductionSweeps size={140,25},pos={150,0}, title="Add Induction Sweeps",proc=AddPrintoutSweeps
	Button AddPostBaselineSweeps size={140,25},pos={300,0}, title="Add Post Baseline Sweeps",proc=AddPrintoutSweeps
	SetVariable NextInduction size={140,25},pos={150,50}, title="Induction",value=root:PrintoutInfo:induction_number,limits={1,Inf,1}
	Button PrintBaselineValues size={80,25},pos={330,50}, title="Values",proc=PrintBaselineValues
	Button Finish size={140,25},pos={150,100}, title="Finish",proc=Printout
	root()
End

function /s GetDataDir([module])
	string module
	
	if(paramisdefault(module))
		string modules=Core#ListAvailableModules()
		variable i
		for(i=0;i<itemsinlist(modules);i+=1)
			module=stringfromlist(i,modules)
			string dataDir=Core#StrPackageSetting(module,"random","","dataDir")
			if(strlen(dataDir))
				break
			endif
		endfor
	else
		dataDir=Core#StrPackageSetting(module,"random","","dataDir")
	endif
	return dataDir 
end

Function DisplayIBW(name[,path,down_sample])
	String name,path
	Variable down_sample
	
	if(ParamIsDefault(path))
		path=GetDataDir(module="Acq")
	endif
	String wave_name,ibw
	path=Windows2IgorPath(path)
	NewPath /O/Q IBWPath path
	if(!StringMatch(name[strlen(name)-4,strlen(name)-1],".ibw"))
		ibw=name+".ibw"
	else
		ibw=name
	endif
	LoadWave /O/Q/P=IBWpath ibw
	wave_name=StringFromList(0,S_wavenames)
	if(IsEmptyString(wave_name))
		printf "%s not found.\r",ibw
		return 0
	endif
	if(down_sample)
		DownSample($wave_name,down_sample,in_place=1)
	endif
	if(!StringMatch(wave_name,name))
		Duplicate /o $wave_name $name
		KillWaves /Z $wave_name
	endif
	String graph_name=UniqueName(CleanUpName(name,0),6,0)
	Display /K=1 /N=$graph_name $name
	SetWindow $graph_name hook=WindowKillHook, userData="KillWave="+GetWavesDataFolder($name,2)
	Textbox name
	Cursors()
	//SetWindow hook=WindowKillHook
End

Function /S LoadIBW(name[,path,type])
	String name,path
	String type // e.g. "Field", "VC", "VC80", "CC" [default].
	
	type=SelectString(strlen(type),"CC",type)
	
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
	
	String ibw
	if(!StringMatch(name[strlen(name)-4,strlen(name)-1],".ibw"))
		ibw=name+".ibw" // Add ".ibw"
	else
		ibw=name
	endif
	LoadWave /O/Q/P=IBWPath ibw
	String wave_name=StringFromList(0,S_wavenames)
	if(IsEmptyString(wave_name))
		printf "%s not found.\r",ibw
		return ""
	endif
	Wave LoadedWave=$wave_name
	name=ibw[0,strlen(ibw)-5] // Remove ".ibw"
	NewDataFolder /o root:Cells
	String folder
	if(StringMatch(type,"CC") || !strlen(type))
		folder="root:Cells:"+name
	else
		folder="root:Cells:"+type+":"+name
	endif	 
	NewDataFolder /O/S $folder
	Duplicate /o LoadedWave $(folder+":"+name)
	KillWaves /Z LoadedWave
	return folder+":"+name
End

// For loading Pakmings spike times from calcium imaging data
Function LoadDelimitedFiles()
	NewPath /M="Choose the folder containing the files" /O/Q/Z DelimitedFilesLocation
	Variable i; String file=""
	Do
		file=IndexedFile(DelimitedFilesLocation, i, ".xls")
		if(!IsEmptyString(file))
			NewDataFolder /O/S root:$file
			LoadWave /Q/J/P=DelimitedFilesLocation file
			i+=1
		else
			break
		endif
	While(1)
End

Function /S Windows2IgorPath(path)
	String path
	path=ReplaceString(":\\",path,":")
	path=ReplaceString("\\",path,":")
	if(!StringMatch(path[strlen(path)-1],":"))
		path+=":"
	endif
	return path
End

Function LoadEEGData()
	NewPath /O/Q/Z/M="Choose the folder containg the EEG tab-delimited text files" EEG
	PathInfo EEG
	String directory=S_path
	String sub_directory=StringFromList(ItemsInList(directory,":")-1,directory,":")
	NewDataFolder /O/S $sub_directory
	String file_list=LS(S_path)
	file_list=ListMatch(file_list,"*.txt")
	Variable i; String file,wave_name,folder
	Variable num_files=ItemsInList(file_list)
	Display /K=1 /N=$("EEGData_"+sub_directory)
	for(i=0;i<num_files;i+=1)
		file=StringFromList(i,file_list)
		folder=GetDataFolder(1)
		LoadWave /O/J/N=EEG_File directory+":"+file
		wave_name=StringFromList(0,S_Wavenames)
		file=ReplaceString(".txt",file,"")
		Duplicate /o $wave_name $file
		KillWaves /Z $wave_name
		DeleteNans($file)
		SetScale /P x,0,0.01,"s",$file
	endfor
	SetDataFolder root:
End

// Loads a tab-delimited text file (default) or a comma separated values (CSV) files into a bunch of waves.
Function LoadText2Waves(location,exp_name [,new_name,format])
	String location,exp_name // The location of the file and it's name
	String new_name,format // An optional new_name to use as a prefix for the waves, and the format of the file
	if(ParamIsDefault(new_name))
		NewDataFolder /O/S $("root:"+exp_name) // Make a folder to temporarily hold the waves
	else
		NewDataFolder /O/S $("root:"+new_name)
	endif
	if(ParamIsDefault(format) || !cmpstr(format,"tab"))
		LoadWave /J/W/A location+":"+exp_name+".txt"
	elseif(!ParamIsDefault(format) && cmpstr(format,"csv"))
		LoadWave  /G/W/A location+":"+exp_name+".csv"
	endif
	//MoveWaves2Root(exp_name)
End

// Save waves from a folder (local name) to a table and a tab delimited text file
Function Folder2Text(folder[,match,except])
	String folder // The name of the folder to use, such as "status"
	String match // A semicolon separated list of possible matching names, including asterisks.  
	String except // A semicolon separated list of things to not include.  Has priority.  
	if(ParamIsDefault(match))
		match="*"
	endif
	if(ParamIsDefault(except))
		except=""
	endif
	
	Variable i,j,index
	String wave_name
	String new_list=WaveList2(folder=folder,match=match,except=except)
	Edit /K=1 /N=Reanalysis_Waves
	folder=FindFolder(folder)
	
	for(i=0;i<ItemsInList(new_list);i+=1)
		wave_name=folder+":"+StringFromList(i,new_list)
		if(waveexists($wave_name))
			AppendToTable $wave_name
		else // If it does not exist
			if(cmpstr(folder+":",wave_name)) // And if the wave name is not an empty string 
				printf "%s does not exist.\r",wave_name
			endif
		endif
	endfor
	new_list=AddPrefix(new_list,folder+":")
	Save /J/B new_list as "RG_"+IgorInfo(1)
	//SaveTableCopy /T=1 as "RG_"+IgorInfo(1)
End 

Function LoadMatrixWave(name)
	String name
	SVar path=root:Windows:path // A path in Windows OS
	SVar extension=root:Windows:extension // An filename extension in Windows OS
	if(!exists("root:Windows:path") || !exists("root:Windows:extension"))
		printf "There must be both a path string and an extension string in the root:Windows folder.\r"
		return 0
	endif
	SetDataFolder root:
	LoadWave /G/M /N=$name path+":"+name+"."+extension
End

// Saves all open layouts to the Igor home folder, e.g. E:\Program Files\Wavemetrics\Igor Pro Folder
Function SaveAll2JPG(to_save)
	String to_save
	String code
	strswitch(to_save)
		case "graphs":
			code="WIN:1"
			break
		case "layouts":
			code="WIN:4"
			break
		default:
	endswitch
	String list=WinList("*",";",code)
	Variable i
	String item
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		DoWindow /F $item
		SavePICT/P=Igor/E=-6/B=288
	endfor
End

Function SaveWavesAsDat(first,last)
	Variable first,last
	String list=""
	Variable i
	for(i=first;i<=last;i+=1)
		list+="wave"+num2str(i)+";"
	endfor
	Save/J/M="\r\n" /B list
End

// Use Neato to make a .dot file from a matrix of distances.  
function DistanceMatrix2GraphViz(type,len[,lenErr,lenScale,nodeLabels,nodeSize,groupSize,groupMembership,showEdges,nodeImages,imagePath,toPDF])
	string type // e.g. "Neato"
	wave len // Matrix of desired edge lengths.   N x N. 
	wave lenErr // Matrix of uncertainties for desired edge lengths.  N x N.  
	variable lenScale // Scale all edge lengths by this value. 
	variable showEdges 
	variable toPDF
	wave /t nodeLabels // Labels for nodes.  N.  
	wave nodeSize // Physical size of nodes.  N.  
	variable groupSize
	wave groupMembership // N.  
	wave /t nodeImages // N.  
	string imagePath
	
	if(!waveexists(lenErr))
		duplicate /free len,lenErr
		lenErr=1
	endif
	lenScale=paramisdefault(lenScale) ? 1 : lenScale
	groupSize=paramisdefault(groupSize) ? 1 : groupSize
	//matrixop /free logLenErr=log(lenErr)
	variable lenErrMed=statsmedian(lenErr)
	newpath /o/q desktop, specialdirpath("Desktop",0,0,0)
	pathinfo desktop
	imagePath=selectstring(!paramisdefault(imagePath),s_path,imagePath)
	imagePath=parsefilepath(5,imagePath,"*",0,0)
	string name=nameofwave(len)
	close /a
	variable refNum
	open /p=desktop refNum as name+"."+type
	colortab2wave rainbow
	wave m_colors
	setscale x,0,1,m_colors
	variable numGroups=paramisdefault(groupMembership) ? ceil(dimsize(len,0)/groupSize) : wavemax(groupMembership)
	strswitch(type)
		case "neato":
			string str="graph G {\r"
			fbinwrite refNum,str
			str="node ["//overlap=scale;\r"
			//sprintf str,"%sK = %.3f;\r",str,lenScale
			if(!paramisdefault(nodeImages))
				str+="shape= none, fixedsize=true, "
			else
				str+="style= filled, "
			endif
			str+="];\r"
			fbinwrite refNum,str
			variable i,j
			variable thin=1
			//string colors="red;blue;green;yellow;orange;brown;black;gray;purple"
			for(i=0;i<dimsize(len,0)/thin;i+=1)
				string color//=stringfromlist(mod(floor(i/groupSize),itemsinlist(colors)),colors)
				variable group=paramisdefault(groupMembership) ? floor(i/groupSize) : groupMembership[i]
				variable colorIndex=group/numGroups
				variable red=m_colors(colorIndex)(0)
				variable green=m_colors(colorIndex)(1)
				variable blue=m_colors(colorIndex)(2)
				sprintf color,"#%2x%2x%2x",red/256,green/256,blue/256
				color=replacestring(" ",color,"0")
				sprintf str,"%d [ ",i+1
				if(!paramisdefault(nodeImages))
					sprintf str,"%simage=\"%s%s\", imagescale=TRUE, ",str,imagePath,nodeImages[i]
				else
					sprintf str,"%sfillcolor = \"%s\", ",str,color
				endif
				if(!paramisdefault(nodeSize))
					sprintf str,"%swidth=%f, height=%f, ",str,nodeSize[i],nodeSize[i]
				endif
				if(!paramisdefault(nodeLabels))
					sprintf str,"%slabel=\"%s\", labelloc=\"b\", ",str,nodeLabels[i]
				endif
				str+="];\r"
				fbinwrite refNum,str
				for(j=i+1;j<dimsize(len,1)/thin;j+=1)
		//		for(j=0;j<dimsize(len,1)/thin;j+=1)
		//			if(i==j)
		//				continue
		//			endif
					if(len[i][j]>0) // Only consider positive edge lengths.  
						sprintf str,"%d -- %d [len=%.3f, w=%.3f, %s];\r",i+1,j+1,len[i][j]*lenScale,lenErrMed/lenErr[i][j],selectstring(showEdges,"style=invis","")
						fbinwrite refNum,str
					endif
				endfor
			endfor
			str="}\r"
			fbinwrite refNum,str
			break
	endswitch
	close refNum
	if(toPDF)
		string args=Igor2WindowsPath("Desktop")+name+";"
		args+=type+";"
		ExecuteUserFile("User Procedures:Recording Artist:Other:neato.bat",args)
	endif
end

function GraphViz2Coords(file)
	string file
	
	newpath /o/q desktop specialdirpath("Desktop",0,0,0)
	close /a 
	variable refNum
	open /P=desktop/R refNum as file
	string line,name
	variable num,left,top,width,height
	make /o/n=0 graphCoords
	freadline refNum, line // First line.  
	do
		freadline refNum, line
		if(stringmatch(line,"node*"))
			sscanf line,"node %d %f %f %f %f %[A-Za-z0-9_]",num,left,top,width,height,name
			redimension /n=(num,4) graphCoords
			graphCoords[num-1][]={{left},{top},{left+width},{top+height}}
			setdimlabel 0,num-1,$name,graphCoords
			setdimlabel 1,0,left,graphCoords
			setdimlabel 1,1,top,graphCoords
			setdimlabel 1,2,right,graphCoords
			setdimlabel 1,3,bottom,graphCoords
		else
			break
		endif	
	while(1)
end

function AppendGraphList(graphCoords)
	wave graphCoords
	
	variable i,factor=72
	for(i=0;i<dimsize(graphCoords,0);i+=1)
		string win=getdimlabel(graphCoords,0,i)
		appendlayoutobject /f=0 graph $win
		modifylayout units=1
		modifylayout left($win)=factor*graphCoords[i][%left],width($win)=factor*(graphCoords[i][%right]-graphCoords[i][%left])
		modifylayout top($win)=factor*graphCoords[i][%top],height($win)=factor*(graphCoords[i][%bottom]-graphCoords[i][%top])
	endfor
end

Function Region2IBW([theWave,x1,x2])
	Wave theWave
	Variable x1,x2
	if(ParamIsDefault(theWave))
		Wave theWave=CsrWaveRef(A)
	endif
	x1=ParamIsDefault(x1) ? xcsr(A) : x1
	x2=ParamIsDefault(x2) ? xcsr(B) : x2
	Duplicate /o /R=(x1,x2) theWave tempRegion2IBW
	Save tempRegion2IBW as "Lina_"+IgorInfo(1)
	KillWaves tempRegion2IBW
End

// Returns a string containing the names of files in a directory
// Use the Windows format for directory paths
Function /S LS(dir_str[,mask])
	String dir_str,mask
	if(ParamIsDefault(mask))
		mask="*"
	endif
	dir_str=ReplaceString(":\\",dir_str,":")
	dir_str=ReplaceString("\\",dir_str,":")
	
	NewPath /O/Q tempPath, dir_str
	Variable i
	String dir_contents=IndexedFile(tempPath,-1,"????")
	dir_contents=ListMatch(dir_contents,mask)
	KillPath /Z tempPath
	return dir_contents
End

// Returns a string containing the names of subdirectories in a directory.
// Use the Windows format for directory paths.
Function /S LS_Directory(dir_str[,mask])
	String dir_str,mask
	if(ParamIsDefault(mask))
		mask="*"
	endif
	dir_str=ReplaceString(":\\",dir_str,":")
	dir_str=ReplaceString("\\",dir_str,":")
	//return dir_str
	NewPath /O/Q tempPath, dir_str
	Variable i
	String dir_contents=IndexedDir(tempPath,-1,0)
	dir_contents=ListMatch(dir_contents,mask)
	KillPath /Z tempPath
	return dir_contents
End

// Each DAT file will contain the waves in suffixes, prepended by a stem
Function ExportDAT(stems,suffixes[,separator])
	String stems,suffixes
	String separator
	if(ParamIsDefault(separator))
		separator="_"
	endif
	Variable i,j
	String stem,suffix,save_list
	for(i=0;i<ItemsInList(stems);i+=1)
		stem=StringFromList(i,stems)
		save_list=""
		for(j=0;j<ItemsInList(suffixes);j+=1)
			suffix=StringFromList(j,suffixes)
			save_list+=stem+separator+suffix+";"
		endfor
		Save /G/B save_list as stem+".dat"
	endfor
End

function MergeFiles(match)
	string match
	
	newpath /o/q desktop,specialdirpath("desktop",0,0,0)
	pathinfo desktop
	variable i
	do
		string file=IndexedFile(desktop,i,".pxp")
		if(strlen(file))
			if(stringmatch(file,match))
				execute /p "MERGEEXPERIMENT "+s_path+file
			endif
			i+=1
		else
			break
		endif
	while(1)
end

// Does something to files matching 'match' in starting system directory 'directory'.  
// Recursively searches subdirectories.  
Function Do2Files(match,directory)
	String match,directory
	
	String paths=PathList("D2F*",";","")
	Variable i=0
	Do
		String path_name="D2F"+num2str(i)
		i+=1
	While(WhichListItem(path_name, paths)>=0)
	NewPath /O/Q $path_name, directory
	
	Variable dir_num=0
	Do
		String sub_directory=IndexedDir($path_name, dir_num, 0)
		if(!strlen(sub_directory))
			break
		endif
		Do2Files(match,directory+":"+sub_directory)
		dir_num+=1
	While(1)
	
	Variable file_num=0
	Do
		String file_name=IndexedFile($path_name, file_num, "????")
		if(!strlen(file_name))
			break
		endif
		if(StringMatch(file_name,match))
			// The thing to do to each file.  
			MoveFile/P=$path_name file_name as file_name+".ibw"
			//
		endif
		file_num+=1
	While(1)
	
	KillPath /Z $path_name
End

Function RenameFiles(directory)
	String directory
	NewPath /O/Q tempPath directory
	Variable i
	String win_dir=ReplaceString(":",directory,"\\")
	win_dir=ReplaceString("C\\",win_dir,"C:\\")
	Variable ref_num
	Open ref_num as "C:rename_igor_files3.bat"
	String files=LS(directory,mask="06*.pxp")
	for(i=0;i<ItemsInList(files);i+=1)
		String file=StringFromList(i,files)
		String new_name="2006_"+file[2,3]+"_"+file[4,5]+"_"+file[6]+".pxp"
		fprintf ref_num,"rename \""+win_dir+file+"\" "+new_name+"\n"
	endfor
	files=LS(directory,mask="2007.*.pxp")
	for(i=0;i<ItemsInList(files);i+=1)
		file=StringFromList(i,files)
		new_name="2007_"+file[5,6]+"_"+file[8,9]+"_"+file[11]+".pxp"
		fprintf ref_num,"rename \""+win_dir+file+"\" "+new_name+"\n"
	endfor
	files=LS(directory,mask="*simplified.pxp")
	for(i=0;i<ItemsInList(files);i+=1)
		file=StringFromList(i,files)
		new_name=RemoveEnding(file,"_simplified.pxp")+".pxp"
		fprintf ref_num,"rename \""+win_dir+file+"\" "+new_name+"\n"
	endfor
	Close ref_num
	String cmd="C:\\rename_igor_files2.bat"
	ExecuteScriptText /B cmd
	KillPath /Z tempPath
End

function ExportWins([types,match,except])
	variable types
	string match,except
	
	types=paramisdefault(types) ? 7 : types
	match=selectstring(!paramisdefault(match),"*",match)
	except=selectstring(!paramisdefault(except),"",except)
	
	newpath /o/q Desktop specialdirpath("Desktop",0,0,0)
	variable i
	string wins=WinList2(types=types,match=match,except=except)
	for(i=0;i<itemsinlist(wins);i+=1)
		string win=stringfromlist(i,wins)
		GetWindow $win,title
		string name=selectstring(strlen(s_value),win,s_value)
		MoveWindow /W=$win 0,0,300,300
		SavePict /O/P=Desktop/E=-5/WIN=$win as CleanupName(IgorInfo(1)[0,9]+"_"+name,0)+".png"
		dowindow /k $win
	endfor	
end


function ExportHDF5(path_name,file_name)
	string path_name,file_name
#if exists("HDF5CreateFile")	
	pathinfo $path_name
	if(!v_flag)
		string full_path = strvarordefault("root:Packages:HDF:path","")
		if(strlen(full_path))
			newpath /o hdf_path,full_path
			pathinfo hdf_path
		endif
		if(!v_flag)
			newpath /o hdf_path
		endif
		path_name = "hdf_path"
	endif
	variable fileID
	print file_name
	pathinfo $path_name
	print v_flag,s_path
	HDF5CreateFile /O/P=$path_name fileID as file_name+".h5"
	//variable groupID
	//HDF5CreateGroup fileID, "/root", groupID
	HDF5SaveGroup /O /R /T root:, fileID, "."
	HDF5CloseFile /Z fileID  
#else
	print "HDF5 XOP not loaded.  
#endif
end