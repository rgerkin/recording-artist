// $URL: svn://churro.cnbc.cmu.edu/igorcode/IgorExchange/Load%20Neuralynx.ipf $
// $Author: rick $
// $Rev: 618 $
// $Date: 2013-01-24 20:21:19 -0700 (Thu, 24 Jan 2013) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName= Nlx
static strconstant module=Nlx
constant useSettings=1
static strconstant panelName="NeuralynxPanel"

//#include "Neuralynx Analysis"

//	NOTE: This requires version 1.25 or later Neuralynx files which start with a 16,384 byte header.
//	Earlier files lack this header.
// 
//	See http://www.neuralynx.com/download/NeuralynxDataFileFormats.pdf for file format specifications.  
//	 
//	This supports .ntt and .ncs files.  A "Neuralynx" menu item is provided in the Analysis menu which provides panel access to the individual file loading and saving functions.  All of the loading functions 
//	are also accessible from the Data/Load Waves menu.  The types variable throughout these function refer to "ntt" or "ncs" (must not contain a leading period) files.  For .ntt files, the data will be loaded
//	as a data wave, a wave with a "_t" suffix (spike times) and a wave with a "_c" suffix (cluster assignments if SpikeSort3D has been used), a wave with a "_h" suffix (the file header), and a wave with a 
//     "_m" suffix (metadata from the file header).  The .ntt data 
//	wave will have 3 dimensions; each spike gives one row.  There are 'NTTSamples' columns because each spike contains 'NTTSamples' samples per channel, and there are 4 layers, one for each channel.  The panel provides
// 	access to a viewer which allows for review of the loaded spike data.  There are also some rudimentary analysis functions such as spike-time-histograms and PETHs if stimulus times are known.  
//	Primitive clustering is available via PCA but is not recommended since better tools like SpikeSort3D or MClust are available.  Many of the functions provided here do not apply to .ncs (continous) data, 
//	except for the loaders, since there isn't much more to do with these that one can't do on one's own.  

strconstant NlxFolder="root:Packages:Nlx:"

// ----------------------------- Neuralynx Data Structures ----------------------------------

// Information that proceeds each chunk of data in .ncs files.   
constant NCSInfoLength=20 // Total bytes per record (8 timestamp, 4 channel number, 4 sampling frequency, 4 num valid samples).  
constant NCSDataSize=2 // Bytes per point (int16).  
constant NCSSamples=512 // Samples per record.  
constant NCSDataLength=1024 //  Bytes per record. (int16 size * NCSSamples).  

Structure NlxNCSInfo
	uint32 TimeStamp_low
	uint32 TimeStamp_high
	uint32 ChannelNumber
	uint32 SampleFreq
	uint32 NumValidSamples
EndStructure

// Information that proceeds each chunk of data in .ntt files.   
constant NTTInfoLength=48 // Total bytes per record (8 timestamp, 4 acquisition entity, 4 for classified cell number, 4x8 for spike feature)	.
constant NTTDataSize=2 // Bytes per point (int16).  
constant NTTSamples=32 // Samples per record per electrode.  (Tetrode = 4 electrodes).  
constant NTTDataLength=256 // Bytes per record. (int16 size x 'NTTSamples' x 4 electrodes/tetrode).  
Structure NlxNTTInfo
	uint32 TimeStamp_low
	uint32 TimeStamp_high
	uint32 SpikeAcqNumber
	uint32 ClassCellNumber
	uint32 FeatureParams[8]
EndStructure

// Information that proceeds each chunk of data in .nev files.   
constant NEVInfoLength=184 // Total bytes per record (8 timestamp, 4 acquisition entity, 4 for classified cell number, 4x8 for spike feature)	.
//constant NTTDataSize=2 // Bytes per point (int16).  
//constant NTTDataLength=256 // Bytes per record. (int16 x 32 x 4).  
Structure NlxNEVInfo
	int16 nstx
	int16 npkt_id
	int16 npkt_data_size
	uint32 TimeStamp_low
	uint32 TimeStamp_high
	int16 nevent_id
	uint16 nttl // The TTL state (16 bits).  
	int16 ncrc
	int16 ndummy1
	int16 ndummy2
	int32 dnExtra[8]
	uchar EventString_low[64]
	uchar EventString_high[64]
EndStructure

Structure NlxFeature
	char name[20]
	uchar num
	char chan
EndStructure

// Things we want to read out of each file's text header.  
static constant NlxHeaderSize = 16384			// Size of header in version 1.25 and later files
Structure NlxMetaData // Metadata in the header.  
	double SampleFreq 
	double bitVolts
	double fileOpenT[2]
	double fileCloseT[2]
	Struct NlxFeature feature[8]
	double reserved[100]
EndStructure

constant NlxTimestampScale=1000000 // The timestamp units are in microseconds.  

// --------------------------- Neuralynx Menus -------------------------------------

// Add an item to Igor's Load Waves submenu (Data menu)
Menu "Load Waves"
	SubMenu "Load Neuralynx"
		"Load Neuralynx Binary Continuous File...", LoadBinaryFile("ncs","")
		"Load Neuralynx Binary Tetrode File...", LoadBinaryFile("ntt","")
		"Load Neuralynx Event File...", LoadBinaryFile("nev","")
		"Load All Neuralynx Binary Continuous Files In Folder...", LoadAllBinaryFiles("ncs","")
		"Load All Neuralynx Binary Tetrode Files In Folder...", LoadAllBinaryFiles("ntt","")
		//"Edit Neuralynx Loader Settings", EditNlxDefaultSettings()
	End
End

// ----------------------------------- Neuralynx Loading/Saving -------------------------------------

// Loads the header of a neuralynx file.  Fills the NlxMetaData structure for use by other functions, creates a Name_h wave containing the binary header.  
Function /WAVE LoadHeader(refNum, type, NlxMetaData)
	Variable refNum
	String type
	Struct NlxMetaData &NlxMetaData		// Outputs
	
	String line,featureName
	Variable bitVolts,sampleFreq,month,day,year,hours,minutes,secs,featureNum,chan
	FSetPos refNum, 0
	
	FSkipLines(refNum,2)
	FReadLine refNum,line // Currently unused.  
	sscanf line,"## Time Opened (m/d/y): %d/%d/%d  At Time: %d:%d:%f ",month,day,year,hours,minutes,secs
	NlxMetaData.fileOpenT[0]=date2secs(year,month,day)
	NlxMetaData.fileOpenT[1]=3600*hours+60*minutes+secs

	FReadLine refNum,line // Currently unused.  
	sscanf line,"## Time Closed (m/d/y): %d/%d/%d  At Time: %d:%d:%f ",month,day,year,hours,minutes,secs
	NlxMetaData.fileCloseT[0]=date2secs(year,month,day)
	NlxMetaData.fileCloseT[1]=3600*hours+60*minutes+secs
	
	Variable i=0, feature=0
	Do
		FReadLine refNum, line
		do // Get rid of leading tabs.  
			if(stringmatch(line[0],"\t"))
				line=line[1,strlen(line)-1]
			else
				break
			endif
		while(1)
		string key
		sscanf line,"-%s",key
		strswitch(key)
			case "SamplingFrequency":
				sscanf line,"-SamplingFrequency %f",sampleFreq
				NlxMetaData.sampleFreq=sampleFreq
				break
			case "ADBitVolts":
				strswitch(type)
					case "ncs":
						sscanf line,"-ADBitVolts %f",bitVolts
						break
					case "ntt":
						sscanf line,"-ADBitVolts %f",bitVolts // Even though tetrodes could have 4 settings, they are likely to be the same.  
						break
				endswitch
				NlxMetaData.bitVolts=bitVolts
				break
			case "Feature":
				sscanf line,"-Feature %s %d %d",featureName,featureNum,chan
				NlxMetaData.feature[feature].name=featureName
				NlxMetaData.feature[feature].num=featureNum
				NlxMetaData.feature[feature].chan=chan
				feature+=1
				break
		endswitch
		i+=1
	While(i<50)
	
	FSetPos refNum,0
	Make /free/n=(NlxHeaderSize) /B TempHeader
	FBinRead /B=3 refNum, TempHeader
	return TempHeader
End

// Creates the Name_h string containing key-value pairs with all header information for a file.  
static Function /S KeyValueHeader(refNum,type)
	Variable refNum
	String type
	
	FSetPos refNum, 0
	String info="",line,key,value
	Variable i=0
	Do
		FReadLine refNum, line
		if(strsearch(line,"-",0)==0) // Line starts with a hyphen.  
			sscanf line,"-%[A-Za-z:]%s",key,value
			key=ReplaceString(":",key,"") // Remove any colons in the key.  
			info+=key+":"+value+";"
		endif
		FStatus refNum
	While(V_filePos<NlxHeaderSize)
	FSetPos refNum, 0
	return info
End

// Loads the data (everything after the header) from a Neuralynx file.  
static Function /wave LoadNlxData(refNum, type, baseName, NlxMetaData)
	Variable refNum
	String type,baseName
	Struct NlxMetaData &NlxMetaData
		
	FSetPos refNum, NlxHeaderSize													// Go to the end of the header (start of the data).  
	FStatus refNum
	Variable i,j,bytes=V_logEOF-V_filePos
	strswitch(type)
		case "ncs":
			Variable numRecords=bytes/(NCSInfoLength+NCSDataLength) // Number of 'NCSSamples' point frames of continuous data plus associated meta-information.  
			Struct NlxNCSInfo NCSInfo
			FBinRead/B=3 refNum, NCSInfo						// Read the info for the first frame of this continuous event.  
			Variable firstFrameT=(NCSInfo.timestamp_low+(2^32)*NCSInfo.timestamp_high)/NlxTimestampScale // Only useful if there are no interruptions in acquisition.  
			Variable chan=NCSInfo.ChannelNumber
			FSetPos refNum, NlxHeaderSize+NCSInfoLength+NCSDataLength
			FBinRead/B=3 refNum, NCSInfo						// Read the info for the second frame of this continuous event.  
			variable secondFrameT=(NCSInfo.timestamp_low+(2^32)*NCSInfo.timestamp_high)/NlxTimestampScale
			variable startT=firstFrameT
			variable deltaT=(secondFrameT-firstFrameT)/NCSSamples
			break
		case "ntt":
			numRecords = bytes/(NTTInfoLength+NTTDataLength) // Number of distinct tetrode records.  
			Struct NlxNTTInfo NTTInfo
			FBinRead/B=3 refNum, NTTInfo						// Read the info for the first frame of this tetrode event.  
			startT=0 										// Each event has its own timestamp.  
			chan=NTTInfo.SpikeAcqNumber
			deltaT=1/NlxMetaData.SampleFreq // Sampling frequency given in the header but not in the frame info for tetrode data.  
			break
		case "nev":
			numRecords = bytes/(NEVInfoLength) // Number of distinct event records.  
			Struct NlxNEVInfo NEVInfo
			FBinRead/B=3 refNum, NEVInfo						// Read the info for the first frame of this tetrode event.  
			startT=0
			break
	endswitch

	if(!strlen(baseName))
		baseName=type
	endif
	String wave_name= CleanupName(baseName,0)
	Make/o/n=(bytes/numRecords,numRecords) /B/U data // uint8 wave (byte wave).  
	FSetPos refNum,NlxHeaderSize 								// Go back to the beginning of the data.  
	FBinRead/B=3 refNum, Data								// Read the rest of the file.  	
	
	// Now sort the wheat from the chaff (clean up the data wave to remove bytes containing metainformation, and resize/redimension it.)  
	IgorizeData(:,type,numRecords)
	
	Note Data, "TYPE:"+type+";"
	strswitch(type)
		case "ncs":
			SetScale/P x, startT, deltaT, "s", Data
			break
		case "ntt":
			SetScale/P x, 0, deltaT, "s", Data
			break
	endswitch
	
	return Data
End

// Takes Igor waves of data and times, created by LoadNlxData, and saves it back into a Neuralynx file.  Assumes there will be already be an intact header in the file that will be overwritten.  
// Use this if you have done some processing on the data in Igor, like removing bogus spikes or extracting a subset of the data, and now want to re-export it for analysis with Neuralynx tools.  
static Function /S SaveNlxData(refNum,df)
	Variable refNum
	dfref df
	
	string type=Nlx#DataType(df)
	wave /sdfr=df Times,Header
	
	strswitch(type)
		case "ncs":
			break
		case "ntt":
			Variable numRecords = numpnts(Times) // Number of distinct tetrode records.  
	endswitch
	
	wave NlxFormatted=DeIgorizeData(df)
	FSetPos refNum,0
	FBinWrite /B=3 refNum, Header
	FSetPos refNum,NlxHeaderSize 								// Go back to the beginning of the data.  
	FBinWrite/B=3 refNum, NlxFormatted						// Write the new data.  
End

// All the Neuralynx data after the header consists of a series of frames.  Each frame contains data and metadata.  This converts the old metadata+data (Raw) into just the data (Raw) as well 
// as a wave of cluster numbers (_c suffix) and a wave of times (_t suffix).  
Function IgorizeData(df,type,numRecords)
	dfref df
	String type
	Variable numRecords
		
	Variable i
	//Make /o/n=(numRecords)/I NumValidSamples // Always 512 according to Brian at Nlx.  
	strswitch(type)
		case "ncs":
			Make /o/D/U/n=(numRecords) df:times /wave=Times
			break
		case "ntt":
			Make /o/D/U/n=(numRecords) df:times /wave=Times
			Make /o/W/U/n=(numRecords) df:clusters /wave=Clusters
			Make /o/I/U/n=(numRecords,8) df:features /wave=Features 
			break
		case "nev":
			Make /o/T/n=(numRecords) df:desc /wave=Events
			Make /o/W/U/n=(numRecords) df:TTL /wave=TTL
			Make /o/D/U/n=(numRecords) df:times /wave=Times
			break
	endswitch
	
	wave Raw=df:Data
	for(i=0;i<numRecords;i+=1)
		Variable timestamp=0
		strswitch(type)
			case "ncs":
				Struct NlxNCSInfo NCSInfo
				StructGet /B=3 NCSInfo, Raw[i]
				timestamp=NCSInfo.timestamp_low+(2^32)*NCSInfo.timestamp_high
				Times[i]=timestamp/NlxTimestampScale
				//NumValidSamples[i]=NCSInfo.NumValidSamples
				break
			case "ntt":
				Struct NlxNTTInfo NTTInfo
				StructGet /B=3 NTTInfo, Raw[i]
				timestamp=NTTInfo.timestamp_low+(2^32)*NTTInfo.timestamp_high
				Times[i]=timestamp/NlxTimestampScale
				Clusters[i]=NTTInfo.ClassCellNumber
				Features[i][]=NTTInfo.FeatureParams[q]
				break
			case "nev":
				Struct NlxNEVInfo NEVInfo
				StructGet /B=3 NEVInfo, Raw[i]
				String eventStr=NEVInfo.EventString_low+NEVInfo.EventString_high
				timestamp=1*NEVInfo.timestamp_low+(2^32)*NEVInfo.timestamp_high
				Events[i]=eventStr
				TTL[i]=NEVInfo.nttl
				Times[i]=timestamp/NlxTimestampScale
				break
		endswitch
	endfor
	
	strswitch(type)
			case "ncs":
				DeletePoints /M=0 0,NCSInfoLength,Raw // Delete the metainformation.  
				Redimension /n=(numpnts(Raw)/NCSDataSize)/E=1/W Raw // Convert into one long wave with the appropriate point size.  
				break
			case "ntt":
				DeletePoints /M=0 0,NTTInfoLength,Raw // Delete the metainformation.  
				Redimension /n=(numpnts(Raw)/NTTDataSize)/E=1/W Raw // Convert into one long wave with the appropriate point size.    
				Duplicate /FREE Raw, NTTTemp
				Redimension /n=(NTTSamples,numRecords,4) Raw // Tetrode number (not sample number) is the first index, so redimensioning in one step doesn't work.  
				Raw[][][]=NTTTemp[(p*4)+(128*q)+r] // Maybe use MatrixOp with WaveMap to improve speed?  No, it only supports 2 dimensional waves.  
				break
			case "nev":
				// Nothing left to do since TTL values and times are already extracted.  If you want to do more with the data you should do it in the previous .nev case.  
				break
	endswitch
	// Raw is now clean!  
End

// The opposite of IgorizeData.  This puts the Data and the Times (but not the clusters) back into a Neuralynx frame format for use with re-exporting Neuralynx data with SaveNlxData.  
Function /wave DeIgorizeData(df)
	dfref df
	
	Make/FREE/n=0 /B/U NlxFormatted // uint8 wave (byte wave).  
	string type=DataType(df)	
	Wave /sdfr=df Data,Times,MetaData
	Variable i,j,k,numRecords=numpnts(Times)
	Struct NlxMetaData NlxMetaData
	
	Wave /I/U /sdfr=df Features
	Wave /W/U /sdfr=df Clusters
	StructGet NlxMetaData MetaData
	//Make/O/n=(bytes/numRecords,numRecords) /B/U $(wave_name) /WAVE=NxFormatted // uint8 wave (byte wave).
	//Make /o/n=(numRecords)/I NumValidSamples // Always 512 according to Brian at Nlx.  
	for(i=0;i<numRecords;i+=1)
		Variable timestamp=0
		strswitch(type)
			case "ncs":
				break
			case "ntt":
				Struct NlxNTTInfo NTTInfo
				NTTInfo.timestamp_low=mod(Times[i]*NlxTimestampScale,2^32)
				NTTInfo.timestamp_high=floor(Times[i]*NlxTimestampScale/(2^32))
//				NTTInfo.SpikeAcqNumber=0 // Ignore this since it doesn't matter.  
				NTTInfo.ClassCellNumber=Clusters[i]  
				for(j=0;j<8;j+=1)
					if(WaveExists(Features))
						NTTInfo.FeatureParams[j]=Features[i][j]
					else
						NTTInfo.FeatureParams[j]=MetaData
					endif
				endfor
				StructPut /B=3 NTTInfo, NlxFormatted[i]
				break
			case "nev":
				break
		endswitch
	endfor
	strswitch(type)
			case "ncs":
				break
			case "ntt":  
				Duplicate /FREE Data,NTTTemp
				Redimension /n=(numpnts(Data))/W NTTTemp
				NTTTemp=Data[floor(mod(p,128)/4)][floor(p/128)][mod(p,4)]/NlxMetaData.bitVolts
				Redimension /n=(NTTDataSize*NTTSamples*4,numRecords)/E=1/B/U NTTTemp
				Redimension /n=(NTTInfoLength+NTTSamples*4*NTTDataSize,numRecords) NlxFormatted
				NlxFormatted[NTTInfoLength,][]=NTTTemp[p-NTTInfoLength][q] // Maybe use MatrixOp with WaveMap to improve speed?    
				break
			case "nev":
				break
	endswitch
	return NlxFormatted // Clean is now raw!  
End

// Load a Neuralynx file.  
Function /s LoadBinaryFile(type,fileName[,pathName,baseName,downSamp])
	String type					// File type: continuous "ncs" or tetrode "ntt".   
	String fileName				// file name, partial path and file name, or full path or "" for dialog.
	String pathName				// Igor symbolic path name or "" for dialog.
	String baseName				// Base name for the wave for this channel .  
	Variable downSamp
	
	dfref currFolder=GetDataFolderDFR()
	downSamp = downsamp>1 ? downsamp : 1
	
	strswitch(type)
		case "ncs":
			break
		case "ntt":
			break
		case "nev":
			break
		default:
			DoAlert 0, "Unknown format: "+type
			return "-100" // Exit now so we don't have to deal with the default case again.  
			break
	endswitch
	
	if(ParamIsDefault(pathName))
		PathInfo NlxPath
		if(V_flag)
			pathName="NlxPath"
		else
			pathName="home"
		endif
	endif

	if(ParamIsDefault(baseName))
		baseName=StrVarOrDefault(NlxFolder+"baseNameDefault",fileName)
	endif
	
	String message = "Select a Nlx binary ."+type+" file"
	Variable refNum
	//print fileName+"."+type
	Open/R/Z=2/P=$pathName/M=message/T=("."+type) refNum as fileName+"."+type
	// Save outputs from Open in a safe place.
	if (V_flag != 0)
		return num2str(V_flag)			// -1 means user canceled.
	endif
	String fullPath = S_fileName
	String path=RemoveListItem(ItemsInList(fullPath,":")-1,fullPath,":")
	fileName=StringFromList(ItemsInList(fullPath,":")-1,fullPath,":")
	fileName=StringFromList(0,fileName,".")
	if(!strlen(baseName))
		baseName=fileName
	endif
	
	// Loaded files with names like "TTA_E8.ntt" into data folders like "TTA:E8" relative to the current folder (usually root).  
	variable i
	for(i=0;i<itemsinlist(baseName,"_");i+=1)
		string folder=stringfromlist(i,baseName,"_")
		NewDataFolder /O/S $folder
	endfor
	dfref df=GetDataFolderDFR()
	
	NewPath /O/Q/Z NlxPath path
	
	Struct NlxMetaData NlxMetaData
	Duplicate /o LoadHeader(refNum,type,NlxMetaData) header
	
	FStatus refNum
	if(V_logEOF<=16384) // Has only the header or even less.  
		printf "%s has no data\r",fullPath
		Close refNum
		SetDataFolder currFolder
		return "-200"
	else
		wave Data=LoadNlxData(refNum, type, baseName, NlxMetaData)	// Load the sample data
	endif
	
	string /g $"type"=type
	string /g headerValues=KeyValueHeader(refNum,type)
	Make /o metadata // Metadata from the header.  
	StructPut NlxMetaData MetaData // Save the header file in case we need to export a modified Nlx file.  
	
	if(StringMatch(type,"ncs"))
		Variable loadedPoints=numpnts(Data)
		Variable delta=deltax(Data)
		if(downSamp>1)
			delta*=downSamp
			if(loadedPoints>100000000) // Do it this way if the wave is large so we don't run out of memory.  
				Variable offset=leftx(Data)
				Data[0,dimsize(Data,0)/downSamp]=mean(Data,offset+p*delta,offset+(p+1)*delta)
				Redimension /n=(loadedPoints/downSamp,-1) Data
				SetScale /P x,leftx(Data),delta,Data
			else // Otherwise, do it the normal way.  
				Resample /DOWN=(downSamp) Data
			endif
		endif
	
		// Fix time wave for continous data so it is a monotonic representation of the time records.  
		if(StringMatch(type,"ncs"))
			Wave Times // Currently just the times for each block of 512 samples.  
			Duplicate /FREE/D Times,temp
			Redimension /D/n=(loadedPoints/downSamp) Times
			Variable factor=NCSSamples/downsamp
			Times=temp[floor(p/factor)]+(temp[floor(p/factor)+1]-temp[floor(p/factor)])*(mod(p,factor)/factor)
		endif
	endif
	
	strswitch(type)
		case "nev":
			variable numSamples = numpnts(Data)
			break
		default: 
			//Redimension/S Data												// Change to floating point so we can represent data in volts.
			//Data*=NlxMetaData.bitVolts
			SetScale d, 0, 0, "V", Data										// Note that the data units are volts
			strswitch(type)
				case "ncs":
					numSamples = numpnts(Data)
					break
				case "ntt":
					numSamples=dimsize(Data,1)
					break
			endswitch
			break
	endswitch
	printf "Loaded data for %s (%d samples).\r", GetDataFolder(0), numSamples
	
	Close refNum
	SetDataFolder currFolder

	return getdatafolder(1)
End

// Using Igor components, overwrite the data component of a Neuralynx file.  
Function SaveBinaryFile(df[,path,fileName,force])
	dfref df						// The folder which contains the data to be written to a file.  
	String path					// Igor symbolic path name or "" for dialog.
	String fileName				// file name, partial path and file name, or full path or "" for dialog.
	variable force				// Force overwrite without prompting.  
	
	string type=Nlx#DataType(df)
	
	Close /A
	strswitch(type)
		case "ncs":
			break
		case "ntt":
			break
		default:
			DoAlert 0, "Unknown format: "+type
			return -2 // Exit now so we don't have to deal with the default case again.  
			break
	endswitch
	
	Variable err
	
	if(ParamIsDefault(path))
		path="NlxPath"
		pathinfo $path
		if(!strlen(s_path))
			Do
				NewPath /O/M="Choose a default folder for Nlx files."/Q $path
			While(V_flag)
		endif
	endif
	
	// This puts up a dialog if the pathName and fileName do not specify a file.
	String message = "Choose a Nlx binary "+type+" file to overwrite or specify a new name."
	Variable refNum
	if(ParamIsDefault(fileName))
		fileName=DF2FileName(df)
	endif
	Open /R/Z=1/P=$path/M=message/T=("."+type) refNum as fileName+"."+type
	variable fileExists=!V_flag
	if(fileExists && !force) // File with this name already exists.  
		DoAlert 1,"Overwrite existing file "+fileName+"?"
		if(V_flag>1)
			Close refNum
			return -3
		endif
	endif
	Open /P=$path/M=message/T=("."+type) refNum as fileName+"."+type
	
	// Save outputs from Open in a safe place.
	err = V_Flag
	String fullPath = S_fileName
	
	if (err==-1) // User cancelled.  
		Close /a
		return -4
	endif
	
	Printf "Writing Nlx binary "+type+" data in \"%s\"\r", fullPath
	
	SaveNlxData(refNum,df)	// Load the sample data
	
	Close refNum
	return 0			// Zero signifies no error.	
End

// Loads all the neuralynx files of a given type in a directory.  
Function /s LoadAllBinaryFiles(type,baseName[,pathName,downSamp])
	String type				// File type.  
	String pathName			// Name of an Igor symbolic folder created by Misc->NewPath. "" for dialog.
	String baseName	// Base name for the wave for this channel or "" for dialog.
	Variable downSamp
	
	if(ParamIsDefault(pathName) || strlen(pathName) == 0)
		String message = "Select a directory containing Nlx "+type+" files"
		NewPath/O/Q/M=message NlxDataPath		// This displays a dialog in which you can select a folder
		if (V_flag != 0)
			return num2str(V_flag)									// -1 means user canceled
		endif
		pathName = "NlxDataPath"
	endif

	downSamp=ParamIsDefault(downSamp) ? NumVarOrDefault(NlxFolder+"downsampleNCS",0) : downSamp
	
	String filesLoaded = ""
	String fileName
	Variable i = 0
	Do
		fileName = IndexedFile($pathName, i, "."+type)
		fileName=RemoveEnding(fileName,"."+type)
		if (strlen(fileName) == 0)
			break										// No more files
		endif
		
		string dfName=LoadBinaryFile(type,fileName,pathName=pathName,baseName=baseName,downSamp=downSamp)
		variable err=str2num(dfName) // Try converting the return value into a number.  
		if(numtype(err)==0) // If it is a number... 
			return num2str(err) // ... then it is an error code.  
		endif
		if(strlen(dfName))
			filesLoaded+=dfName+";"
		endif
		i += 1
	While(1)
	
	return filesLoaded
End

Function HeaderCheck()
	ControlInfo /W=NeuralynxPanel dirName
	NewPath /O/Q temppath,S_Value
	Variable i=0
		Do
			Variable j=0
			String dirName=IndexedDir(temppath,i,1)
			Do
				NewPath /O/Q temppath2,dirName
				String fileName=IndexedFile(temppath2,j,".ncs")
				if(strlen(fileName))
					String path=dirName+":"+fileName
					Variable refNum
					Open /R refNum as path
					String header=KeyValueHeader(refNum,"ncs")
					// ----- Put code to check headers here.  -----
					FStatus refNum
					if(NumberByKey("AmpLowCut",header)<1 && V_logEOF>16384)
						printf "%s,%d",path,V_logEOF
					endif
					// -------------------------------------------------------------
					Close refNum
				endif
				j+=1
			While(strlen(fileName))
			i+=1
		While(strlen(dirName))
	//KeyValueNlxHeader(refNum,type)
End

// ---------------------------------- Viewing Loaded Data ---------------------------------------

Function Viewer(df)
	dfref df
#if exists("NlxA#CreateViewer")
	NlxA#CreateViewer(df) // Fancy viewer included in the Neuralynx Analysis procedure file.   
#else
	SimpleViewer(df,sparse=10) // Crappy viewer to use if the Neuralynx Analysis file is not present.  
#endif	
End

Function SimpleViewer(df[,sparse,yAxisRange])
	dfref df
	variable sparse // Plotting all spikes can take a long time, so set this value to "n" to plot only every "nth" spike.  
	variable yAxisRange // A value for the + and - range of the y axis, in volts.  
	
	svar type=df:type
	wave Data=df:Data
	variable i,j,red,green,blue
	Display /K=1 /N=SimpleViewer as CleanupName(GetDataFolder(0,df),0)
	strswitch(type)
		case "ntt":
			wave Clusters=df:Clusters
			variable clusterMax=wavemax(Clusters)
			ColorTab2Wave Rainbow; wave M_Colors
			for(i=0;i<4;i+=1)
				String axis_name="axis_"+num2str(i)
				String axisT_name="axisT_"+num2str(i)
				Variable numSpikes=dimsize(Data,1)
				for(j=0;j<numSpikes;j+=1)  
					Variable cluster=Clusters[j]
					Variable colorIndex=dimsize(M_Colors,0)*(cluster-1)/clusterMax
					red=M_Colors[colorIndex][0]; green=M_Colors[colorIndex][1]; blue=M_Colors[colorIndex][2]
					if(!sparse || mod(j,sparse)==0)				
						AppendToGraph /c=(red,green,blue) /L=$axis_name /B=$axisT_name Data[][j][i]
					endif
				endfor
				ModifyGraph /Z axisEnab($axis_name)={(i<2)*0.52,0.48+(i<2)*0.5}, freePos($axis_name)={0,$axisT_name}
				ModifyGraph /Z axisEnab($axisT_name)={(mod(i,2)==1)*0.52,0.48+(mod(i,2)==1)*0.5}, freePos($axisT_name)={0,$axis_name}
				ModifyGraph /Z tickUnit($axis_name)=1,prescaleExp($axis_name)=6,btlen=1,fsize=9
			endfor
			break
		case "ncs":
			wave Times=df:Times
			AppendToGraph Data vs Times
			break
	endswitch
	
	// Scale axes.  
	string axes=AxisList("")
	for(i=0;i<itemsinlist(axes);i+=1)
		string axis=stringfromlist(i,axes)
		string info=AxisInfo("",axis)
		string axisType=stringbykey("AXTYPE",info)
		strswitch(axisType)
			case "left":
			case "right":
				if(yAxisRange)
					SetAxis /Z $axis -yAxisRange/1000000,yAxisRange/1000000
				else
					SetAxis /A/Z $axis
				endif
				Label /Z $axis " "
				break
		endswitch
	endfor
End

// ---------------- Neuralynx Master Panel ---------------------

Menu "Analysis"
	"Neuralynx",/Q,InitPanel()
End

static function VarSetting(package,object,instance[,setting])
	string package,object,instance,setting
	
	setting=selectstring(!paramisdefault(setting),"value",setting)
	variable result=Core#VarPackageSetting(module,package,instance,object,setting=setting)
	return result
end

static function /s StrSetting(package,object,instance[,setting,module_])
	string package,object,instance,setting,module_
	
	setting=selectstring(!paramisdefault(setting),"value",setting)
	module_=selectstring(!paramisdefault(module_),module,module_)
	
	string result=""
	if(useSettings)
		result=Core#StrPackageSetting(module,package,instance,object,setting=setting)
	endif
	if(strlen(result)==0)
		strswitch(package)
			case "Sources":
				strswitch(setting)
					case "dataDir":
						result=specialdirpath("Desktop",0,0,0)
						break
				endswitch
				break
		endswitch
	endif
	return result
end

Function InitPanel([reload]) : Panel
	variable reload
	
	if(wintype("NeuralynxPanel") && !reload)
		DoWindow /F NeuralynxPanel
		return 0
	endif
	Core#LoadPackages(module)
	NewPath /O/Q/Z NlxPath, StrSetting("Sources","dataDir","")
	DoWindow /K NeuralynxPanel
	NewPanel /K=1 /W=(577,90,1075,199) /N=NeuralynxPanel as "Neuralynx Analysis"
	string path=""
	GetPath(path,message="Choose a data directory")
	
	GroupBox SaveLoad,pos={1,0},size={485,47}
	SetVariable dirName,pos={3,2},size={288,16},proc=Nlx#PanelSetVariables,title="Directory"
	PathInfo NlxPath
	SetVariable dirName,value= _STR:SelectString(V_flag,"",S_path)
	SetVariable fileName,pos={93,25},size={197,16},title="File",value= _STR:""
	PopupMenu Type,pos={3,23},size={83,21},title="Type"
	PopupMenu Type,mode=1,popvalue="ntt",value= #"\"ntt;nse;ncs;nev;all\"", proc=Nlx#PanelPopupMenus
	Button ChooseDir,pos={292,1},size={19,20},proc=Nlx#PanelButtons,title="..."
	PopupMenu Sources_settings,value=#"Nlx#ListPackageInstances(\"Sources\")",title="Sources",userData="MODE:1;",proc=Nlx#PanelPopupMenus
	Button ChooseFile,pos={292,24},size={19,19},proc=Nlx#PanelButtons,title="..."
	Button Load,pos={321,24},size={50,20},proc=Nlx#PanelButtons,title="Load"
	Button Save,pos={376,24},size={50,20},proc=Nlx#PanelButtons,title="Save"
	
	GroupBox SaveLoad1,pos={1,51},size={485,53}
	PopupMenu Data,pos={3,53},size={83,21},proc=Nlx#PanelPopupMenus,title="Data"
	PopupMenu Data,mode=1,value= #"Nlx#Recordings(\"\")"
	Button View,pos={200,53}, proc=Nlx#PanelButtons, title="View"
#if exists("NlxA#ChopWindow")
	Button Chop,size={50,20},proc=Nlx#PanelButtons,title="Chop"
#endif
	SetVariable tStart,size={71,16},title="Start",value= _NUM:0
	SetVariable tStop,size={75,16},title="Stop",value= _NUM:inf
	string trigSource=StrSetting("Sources","trigSource","")
	PopupMenu TrigSource,pos={3,79},size={87,21},proc=Nlx#PanelPopupMenus,mode=max(1,1+whichlistitem(trigSource,EventList())),value=#"Nlx#EventList()",title="Trig"
	//string trigType=StrSetting("Sources","trigType","")
	//PopupMenu TrigType,pos={90,79},mode=max(1,1+whichlistitem(trigType,TriggerList())),value=#"Nlx#TriggerList()",proc=Nlx#PanelPopupMenus, title=" "
#if exists("NlxA#MakeSTH")	
	//ControlInfo DisplaySTH
	//CheckBox DisplayPETH,pos={v_left,v_top+26}, size={45,14},title="Show",value= 0
	Button MakeSTH,pos={200,79},size={45,20},proc=Nlx#PanelButtons,title="STH"
	Button MakePETH,size={45,20},proc=Nlx#PanelButtons,title="PETH"
	Button Stats,size={45,20},proc=Nlx#PanelButtons,title="Stats"
	PopupMenu PETH_settings,value=#"Nlx#ListPackageInstances(\"PETH\")",title="Settings",userData="MODE:1;",proc=Nlx#PanelPopupMenus
#endif	
End

static function /s ListPackageInstances(package[,editor,saver])
	string package
	variable editor,saver
	
	editor=paramisdefault(editor) ? 1 : editor
	return Core#ListPackageInstances(module,package,editor=editor,saver=saver)
end

static Function /s EventList()
	//string events=Nlx#Recordings("nev")
	string events=WaveList2(match="data",recurse=1,fullPath=1)
	events+=WaveList2(match="times",recurse=1,fullPath=1)
	variable i
	events=replacestring("root:",events,"")
	events=replacestring(":data;",events,";")
	events=replacestring(":times;",events,";")
	events=UniqueList(events)
	if(!strlen(events))
		events="None"
	endif
	return events
End

static Function /S TriggerList()
	controlinfo /w=NeuralynxPanel TrigSource
	string triggers="All;"
	if(v_flag>0)
		dfref df=$("root:"+s_value)
		variable i
		triggers+=wavelist2(df=df,type=1)
	endif
	return triggers
End

//  Uses to build the popup menu for Neuralynx data loaded.  
static Function /S Recordings(type[,df,name,depth])
	String type
	dfref df
	string name // Specify if you want to return the full path to a recording with a given name.  
	variable depth
	
	if(!strlen(type))
		variable i=0
		do
			ControlInfo /W=$(WinName(i,65)) type
			i+=1
		while(v_flag<0 && i<100)
		type=s_value
	endif
	if(paramisdefault(df))
		df=root:
	endif
	
	string list=""
	svar /z type_=df:type
	if(svar_exists(type_) && stringmatch(type_,type))
		list=getdatafolder(1,df)+";"
	endif
	string folders=stringbykey("folders",datafolderdir(1,df))
	for(i=0;i<itemsinlist(folders,",");i+=1)
		string folder=stringfromlist(i,folders,",")
		string sublist=Recordings(type,df=df:$folder,depth=depth+1)
		if(strlen(sublist))
			list+=sublist
		endif
	endfor
	if(paramisdefault(df)) // If we are at the top level of the recursion.  
		string list2=""
		for(i=0;i<itemsinlist(list);i+=1) // Make all the folder names relative to the current folder.  
			string item=stringfromlist(i,list)
			item=replacestring("root:",item,"")
			item=removeending(item,":")
			if(strlen(item))
				list2+=item+";"
			endif
		endfor
		list=list2
	endif
	if(!strlen(list) && depth==0)
		list="None"
	endif
	return list
End

// Returns the start time (in seconds since midnight) for the Neuralynx data.  
// This is the t=0 for the times stored in the _t waves.  
Function StartEndTime(tStart,tEnd)
	Variable &tStart,&tEnd
	
	variable refNum
	Open /M="Where is the CheetahLogFile for this experiment?"/P=NlxPath/R/T=".txt"/Z=2 refNum as "CheetahLogFile.txt"
	if(v_flag)
		printf "No CheetahLogFile found.\r"
	endif
	NewPath /O/Q NlxPath removeending(s_filename,"CheetahLogFile.txt")
	string line
	variable hours,minutes,seconds
	do
		freadline refnum,line
		if(stringmatch(line,"*RealTimeClock*"))
			sscanf line,"-* NOTICE  *-  %d:%d:%f",hours,minutes,seconds
			tStart=3600*hours+60*minutes+seconds
		elseif(stringmatch(line,"*DataFile::Shutdown()*"))
			sscanf line,"-* NOTICE  *-  %d:%d:%f",hours,minutes,seconds
			tEnd=3600*hours+60*minutes+seconds
		endif
	while(strlen(line))
	
	if(tEnd<tStart)
		tEnd=Inf
	endif
End

static Function /s StartTime()
	variable tStart,tEnd
	StartEndTime(tStart,tEnd)
	return secs2time(tStart,3)
End

static Function PanelSetVariables(info)
	Struct WMSetVariableAction &info
	if(info.eventCode != 1 && info.eventCode != 2)
		return -1
	endif
	strswitch(info.ctrlName)
		case "binWidth":
			variable oldBinWidth=str2num(getuserdata("","binWidth",""))
			if(!numtype(oldBinWidth))
				//SetVariable binWidth value=_NUM:(oldBinWidth>info.dval) ? oldBinWidth/2 : oldBinWidth*2
			endif
			SetVariable binWidth userData=num2str(info.dval)
	endswitch
End

static Function PanelButtons(ctrlName)
	String ctrlName
	strswitch(ctrlName)
		case "ChooseDir":
			NewPath /M="Choose a directory of Neuralynx files..."/O/Q/Z NlxPath
			if(!V_flag)
				PathInfo NlxPath
				SetVariable dirName, value=_STR:S_path
			else
				return -2
			endif
			break
		case "ChooseFile":
			Variable refNum
			//PathInfo NeuralynxPath
			ControlInfo Type; String type=S_Value
			Open /D/R/T=("."+selectstring(stringmatch(type,"all"),type,"n**"))/Z=2/P=NlxPath/M="Choose a Neuralynx file..." refNum
			if(strlen(S_fileName))
				String fileName=StringFromList(ItemsInList(S_fileName,":")-1,S_fileName,":")
				SetVariable fileName, value=_STR:RemoveEnding(fileName,"."+type)
			endif
			break
		case "Load":
			ControlInfo Type; string types=S_Value
			if(stringmatch(types,"All"))
				types="ntt;ncs;nev;"
			endif
			controlinfo Sources_settings; string instance=s_value
			ControlInfo fileName; string fileNameList=S_Value
			//ControlInfo DownSample; Variable downSamp=V_Value
			ControlInfo dirName; String dirName=S_Value
			NewPath /O/Q/C NeuralynxLoadPath dirName
			variable i,j
			for(j=0;j<itemsinlist(types);j+=1)
				type=stringfromlist(j,types)
				variable downSamp=VarSetting("Sources",type+"Downsample",instance)
				downSamp=numtype(downSamp) ? 0 : downSamp
				string pathFileNames=PathFiles("NeuralynxLoadPath",extension="."+type)
				string matches=""
				for(i=0;i<itemsinlist(fileNameList);i+=1) // fileNameList might be a semicolon-separated list, or a single file name.  
					fileName=stringfromlist(i,fileNameList)
					fileName=removeending(fileName,"."+type)+"."+type
					matches+=ListMatch(pathFileNames,fileName)
				endfor
				matches=uniquelist(matches)
				for(i=0;i<itemsinlist(matches);i+=1)
					fileName=stringfromlist(i,matches)
					fileName=removeending(fileName,"."+type)
					if(strlen(fileName))
						LoadBinaryFile(type,fileName,downSamp=downSamp,pathName="NeuralynxLoadPath")
					endif
				endfor
			endfor
			break
		case "Save":
			ControlInfo fileName; fileName=S_Value
			ControlInfo dirName; dirName=S_Value
			dfref df=$DFFromMenu()
			NewPath /O/Q/C NeuralynxSavePath dirName
			if(strlen(fileName))
				SaveBinaryFile(df,fileName=fileName,path="NeuralynxSavePath")
			endif
			break
		case "View":
			ControlInfo Data; dfref df=$("root:"+S_Value)
			Viewer(df)
			break
#if exists("NlxA#MakeSTH")
		case "MakeSTH":
			ControlInfo tStart; Variable tStart=V_Value
			ControlInfo tStop; Variable tStop=V_Value
			ControlInfo Data; dfref dataDF=$("root:"+S_Value)
			if(!datafolderrefstatus(dataDF))
				break
			endif
			controlinfo PETH_settings; instance=s_value
			variable binWidth=Core#VarPackageSetting(module,"PETH",instance,"binWidth")
			wave NlxSTH=NlxA#MakeSTH(dataDF,binWidth,tStart=tStart,tStop=tStop)
			//ControlInfo DisplaySTH
			//if(V_Value)
				NlxA#DisplaySTH(dataDF)
			//endif
			break
		case "MakePETH":
			ControlInfo Data; dfref dataDF=$("root:"+S_Value)
			if(!datafolderrefstatus(dataDF))
				break
			endif
			wave /z NlxPETH=NlxA#MakePETHFromPanel()
			//string colLabels=stringbykey("COLLABELS",note(NlxPETH))
			if(waveexists(NlxPETH))
				NlxA#DisplayPETH(dataDF)//,colLabels=colLabels)
			endif
			break
		case "Stats":
			DoStats()
			break
#endif
#if exists("NlxA#ChopWindow")
		case "Chop":
			NlxA#ChopWindow()
			break
#endif
	endswitch
End

static Function PanelPopupMenus(info)
	Struct WMPopupAction &info
	if(info.eventCode!=2)
		return -1
	endif
	
	info.userData=ReplaceStringByKey("MODULE",info.userData,module)
	if(Core#PossiblyEditSettingsPM(info))
		return 0
	endif
	strswitch(info.ctrlName)
		case "Data":
			dfref df=$("root:"+info.popStr)
			wave /z/sdfr=df times
			if(waveexists(times))
				setvariable tStart, value=_NUM:wavemin(Times)
			endif
			break
		case "Type":
			//SetVariable Downsample, disable=!StringMatch(info.popStr,"ncs")
			break
		case "Triggers":
			break
		case "Sources_settings":
			SetVariable dirName,value=_STR:StrSetting(stringfromlist(0,info.ctrlName,"_"),"dataDir",info.popStr),win=$info.win
			string sourcesInstance=info.popStr
			string dataDir=Core#strpackagesetting(module,"Sources",sourcesInstance,"dataDir")
			NewPath /Q/O NlxPath,dataDir
			break
	endswitch
End

// ------------------------------ Helper functions. -----------------------------

// Returns the neuralynx data type "ntt", "ncs", etc. for a given data wave.  Only "ntt" supported and only by virtue of its 4 layer (tetrode) nature.  
static Function /S DataType(df)
	dfref df
	
	if(datafolderrefstatus(df))
		svar /z/sdfr=df type
		wave /z/sdfr=df chanHistory=channelHistoryName
	endif
	if(svar_exists(type))
		return type
	elseif(waveexists(chanHistory))
		return "igor"
	else
		return ""
	endif
End

static Function /s DF2FileName(df)
	dfref df
	
	string name=getdatafolder(1,df)
	name=name[5,strlen(name)-1]
	name=replacestring(":",name,"_")
	name=removeending(name,"_")
	return name
End

// Skips num_lines lines worth of data from a file.  
static Function FSkipLines(refNum,num_lines)
	Variable refNum,num_lines
	String dummy
	Variable i
	for(i=0;i<num_lines;i+=1)
		FReadLine refNum,dummy
	endfor
	return num_lines
End

static Function /s PathFiles(path[,extension])
	string path,extension
	
	if(paramisdefault(extension))
		extension="????"
	endif
	string files=""
	variable i=0
	do
		string name=IndexedFile($path,i,extension)
		files+=name+";"
		i+=1
	while(strlen(name))
	return removeending(files,";")
End

static Function /S GetPath(path[,message,writeable])
	string &path
	string message
	variable writeable
	
	if(!strlen(path))
		path="NlxPath"
	endif
	pathinfo $path
	if(!strlen(S_path))
		if(paramisdefault(message))
			message="Choose a directory of Neuralynx files..."
		endif
		newpath /o/q/m=message $path
		pathinfo $path
	endif
	string pathStr=S_path
	return pathstr
End

static Function /S MatchingFolder()
	String fileName=IgorInfo(1)
	string path=""
	GetPath(path,message="Choose a data directory")
	Variable i
	Do
		String dirName=IndexedDir(NlxPath,i,0)
		if(!strlen(dirName) || StringMatch(fileName[0,9],ReplaceString("-",dirName[0,9],"_")))
			break
		endif
		i+=1
	While(1)
	return dirName
End

static Function /s DFfromMenu()
	ControlInfo Data
	if(!V_Value)
		return ""
	endif
	string folder=S_Value
	variable i
	do // Find the correct data folder, starting from children of the current data folder, and working all the way up to root.  
		folder=":"+folder
		dfref df=$folder
		i+=1
	while(!datafolderrefstatus(df) && i<10) // If this is not a valid data folder.
	return folder
End

static function /df PanelDF(type)
	string type
	
	ControlInfo /W=$panelName $type
	if(v_flag<=0)
		printf "Could not find '%s' menu in %s.\r",type,panelName
		return NULL
	endif
	dfref df=$(joinpath({getdatafolder(1),s_value}))
	if(!datafolderrefstatus(df))
		dfref df=$("root:"+s_value)
	endif
	if(!datafolderrefstatus(df))
		printf "Could not find data folder for panel %s source %s.\r",type,s_value
	endif
	return df	
end

static function /df PanelData()
	return PanelDF("Data")
end

static function /df PanelTriggers()
	return PanelDF("TrigSource")
end

static function /s PanelInstance(package)
	string package
	
	string result="_default_"
	ControlInfo /W=$panelName $(package+"_settings")
	if(v_flag<=0)
		printf "Could not find popup meny for package %s in the panel %s.  Using default instance of %s.\r",package,panelName,package
	else
		result=s_value
	endif
	return result
end

// -------------------- Profile Packages ----------------------- //

static Function EditPackagesTabs(info)
	struct WMTabControlAction &info
	
	ControlInfo /W=ProfilePackagesWin Tab; string package=s_value
	string module=Core#PackageModule(package)
	string packagedescription=strvarordefault(Core#moduleInfo()+":"+module+":"+package+":desc","")
	variable x=5,y=115,yjump=32 // Positions for controls to appear.  
	variable titleX=2,titleY=y-60
	TitleBox Text title=packageDescription, pos={titleX,titleY}, disable=0
	Core#EditPackageInstances(module,package)
	//Struct rect coords
	//GetWinCoords(WinName(0,64),coords,forcePixels=1)
	//Variable factor=ScreenResolution/72
	//MoveWindow coords.left,coords.top,coords.left+max(700,x+xjump)/factor,coords.top+(y)/factor
End

//static Function /S ListDefaultPackageInstances(module,package)
//	string module,package
//	
//	string instances=""
//	strswitch(package)
//		case "TTL":
//			instances="CSon;USon;CSoff;USoff"
//			break
//	endswitch
//	return instances
//End

//static Function LoadPackageDefinitions(module)
//	string module
//	
//	string /g SourcesSettings="GENERIC:1"
//		sourcesSettings+=";STR:dataDir|Default Data Directory="+replacestring(":",specialdirpath("Desktop",0,0,0),"/")+","
//		sourcesSettings+="animal|Animal|Mouse|Rat|Rabbit=Mouse,"
//		sourcesSettings+="trigSource|Trigger Source|Events|Data=Events,"
//		sourcesSettings+="trigType|Trigger Type|All|TTL=All,"
//		sourcesSettings+=";VAR:ncsDownsample|Downsample NCS|0|1000|1=32,"
//	string /g PETHSettings="GENERIC:1"
//		pethSettings+=";VAR:binWidth|Bin Width=0.1,pre|Pre T=3,post|Post T=7,"
//		pethSettings+=";STR:normalize|Normalization|Rate|Count|Z-Score=Rate,"
//	string /g TTLSettings="GENERIC:0;VAR:value|TTL Value=1;STR:desc|Description"
//	string /g MiscSettings="GENERIC:1;STR:mood|Mood|Happy|Sad|Awesome=Happy"
//End
