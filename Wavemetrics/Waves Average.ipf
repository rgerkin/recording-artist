#pragma rtGlobals=1		// Use modern global access method.
#pragma version 1.04

// Procedure file "Waves Average". Some may have the procedure file "AverageWaves"; this is much better.
// Best way to use it is to put "#include <Waves Average>" in your procedure window.

//*****************************************************
// Changes for version 1.01:
//	1)	altered fWaveAverage() function to handle waves with NaN's and waves having variable length.
// Changes for version 1.02:
//	1)	Fixed the change made in 1.01: made an average wave only as long as the first wave in the list.
// Changes for version 1.03:
//		X scaling if first wave in wave list provided to fWaveAverage() is 
//			copied to the output waves.
// Changes for version 1.04:
//		Append To Graph checkbox was not honored
//*****************************************************

Menu "Analysis"
	"Waves Average Panel", MakeWavesAveragePanel()
end

Proc MakeWavesAveragePanel()

	if (WinType("WaveAveragePanel") == 7)
		DoWindow/F WaveAveragePanel
	else
		InitWaveAverageGlobals()
		f_WaveAveragePanel()
	endif
end

Function InitWaveAverageGlobals()

	String SaveDF = GetDataFolder(1)
	SetDataFolder root:
	NewDataFolder/O/S Packages
	NewDataFolder/O/S WM_WavesAverage
	
	if (Exists("ErrorWaveName") != 2)
		String/G AveWaveName="W_WaveAverage"
	endif
	if (Exists("ErrorWaveName") != 2)
		String/G ErrorWaveName="W_WaveAveError"
	endif
	if (Exists("ListExpression") != 2)
		String/G ListExpression="sweep*"
	endif
	if (Exists("AveWaveRegion") != 2)
		if(strlen(CsrInfo(A,"AnalysisWin")))
			String/G AveWaveRegion
			sprintf AveWaveRegion,"%d,%d",xcsr(A,"AnalysisWin"),xcsr(B,"AnalysisWin")
		else
			String/G AveWaveRegion="1,1000"
		endif
	endif
	if (Exists("wave_list") != 2)
		String/G wave_list=""
	endif
	String/G WA_ListOfWaves
	Variable i
	Do
		String folder_name=GetIndexedObjName("root:",4,i)
		if(StringMatch(folder_name,"*cell*")) // If it is a folder that might have recorded sweeps.  
			break
		endif
		folder_name=""
	While(strlen(folder_name))
	String/G DataFolder="root:"+folder_name
	
	if (Exists("nSD") != 2)
		Variable/G nSD=2
	endif
	if (Exists("ConfInterval") != 2)
		Variable/G ConfInterval=95
	endif
	if (Exists("GenErrorWaveChecked") != 2)
		Variable/G GenErrorWaveChecked=1
	endif
	if (Exists("ErrorMenuSelection") != 2)
		Variable/G ErrorMenuSelection=2	// default to confidence interval
	endif
	if (Exists("WavesFromItem") != 2)
		Variable/G WavesFromItem=2
	endif
	if (Exists("AppendToGraphCheckValue") != 2)
		Variable/G AppendToGraphCheckValue=1
	endif
	
	SetDataFolder $SaveDF
end
	

Function fWaveAverage(ListOfWaves, ErrorType, ErrorInterval, AveName, ErrorName)
	String ListOfWaves
	Variable ErrorType		// 0 = none; 1 = S.D.; 2 = Conf Int; 3 = Standard Error
	Variable ErrorInterval	// if ErrorType == 1, # of S.D.'s; ErrorType == 2, Conf. Interval
	String AveName, ErrorName
	
	if ( ErrorType == 2)
		if ( (ErrorInterval>100) %| (ErrorInterval < 0) )
			Abort "Confidence interval must be between 0 and 100"
		endif
		ErrorInterval /= 100
	endif
	
	Variable i=0
	Variable numWaves = ItemsInList(ListOfWaves)
	Variable maxLength = 0
	
	for (i = 0; i < numWaves; i += 1)
		String theWaveName=StringFromList(i,ListOfWaves, ";")
		Wave/Z w=$theWaveName
		if (!WaveExists(w))
			DoAlert 0, "A wave in the list of waves ("+theWaveName+") cannot be found."
			return -1
		endif
		maxLength = max(maxLength, numpnts(w))
	endfor
	
	Make/N=(maxLength)/D/O $AveName
	Wave/Z AveW=$AveName
	Wave w=$StringFromList(0,ListOfWaves, ";")
	CopyScales/P w, AveW
	AveW = 0
	Duplicate/O AveW, TempNWave
	TempNWave = 0
	
	String wNm
	i = 0
	Variable j, npnts
	for (i = 0; i < numWaves; i += 1)
		wNm = StringFromList(i,ListOfWaves, ";")
		Wave/Z w=$wNm
		npnts = numpnts(w)
		for (j = 0; j < npnts; j += 1)
			if (numtype(w[j]) == 0)
				AveW[j] += w[j]
				TempNWave[j] += 1
			endif
		endfor
	endfor
	
	AveW /= TempNWave
	
	if (ErrorType)
		Duplicate/O AveW, $ErrorName
		Wave/Z SDW=$ErrorName
		SDW = 0
		i=0
		for (i = 0; i < numWaves; i += 1)
			wNm = StringFromList(i,ListOfWaves, ";")
			Wave/Z w = $wNm
			if (!WaveExists(w))
				DoAlert 0, "A wave in the list of waves ("+wNm+") cannot be found."
				return -1
			endif
			npnts = numpnts(w)
			for (j = 0; j < npnts; j += 1)
				if (numtype(w[j]) == 0)
					SDW[j] += (w[j]-AveW[j])^2
				endif
			endfor
		endfor
		SDW /= (TempNWave-1)
		SDW = sqrt(SDW)			// SDW now contains s.d. of the data for each point
		if (ErrorType > 1)
			SDW /= sqrt(TempNWave)	// SDW now contains standard error of mean for each point
			if (ErrorType == 2)
				SDW *= StudentT(ErrorInterval, TempNWave-1) // CLevel confidence interval width in each point
			endif
		endif
		if(ErrorType!=2)
			SDW *= ErrorInterval
		endif
	endif 
	
	KillWaves/Z TempNWave		
end

Function ErrorTypeMenuProc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

	Variable/G root:Packages:WM_WavesAverage:ErrorMenuSelection
	NVAR/Z ErrorMenuSelection=root:Packages:WM_WavesAverage:ErrorMenuSelection
	
	DoWaveAverageProgDrawLayer(1, popNum)
	ShowHideErrorControls(1, popNum)
	ErrorMenuSelection = popNum
End

Function GenErrorWaveCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	Variable/G root:Packages:WM_WavesAverage:GenErrorWaveChecked
	NVAR/Z GenErrorWaveChecked=root:Packages:WM_WavesAverage:GenErrorWaveChecked
	ControlInfo ErrorTypeMenu
	Variable ErrorMenuSelection=V_value

	DoWaveAverageProgDrawLayer(checked, ErrorMenuSelection)
	ShowHideErrorControls(checked, ErrorMenuSelection)
	GenErrorWaveChecked=checked
End

Function DoWaveAverageProgDrawLayer(checked, ErrorType)
	Variable checked
	Variable ErrorType	// 0 = no error; 1 = S.D.; 2 = Conf Int; 3 = Standard Error

	SetDrawLayer/K ProgBack

	if (checked)
		SetDrawEnv fsize= 10
		DrawText 28,226,"Error:"
		SetDrawEnv fsize= 10
		switch(ErrorType)
			case 1:	
				DrawText 58,142,"# of s.d.'s:"
				break
			case 2:	
				DrawText 67,142,"Interval:"
				DrawText 154,144,"%"
				break
			case 3:
				DrawText 49,142,"# of s.e.m.'s:"
				break
		endswitch
	endif
end

Function ShowHideErrorControls(ShowThem, ErrorType)
	Variable ShowThem
	Variable ErrorType

	PopupMenu ErrorTypeMenu,disable=!ShowThem
	SetVariable SetErrorWaveName,disable=!ShowThem
	SetVariable SetNSD,disable=!ShowThem || (ErrorType!=1 && ErrorType!=3)
	SetVariable SetConfInterval,disable=!ShowThem || ErrorType!=2
end

Function ShowHideWavesFromGraphControls(ShowThem)
	Variable ShowThem
	NVAR/Z AppendToGraphCheckValue=root:Packages:WM_WavesAverage:AppendToGraphCheckValue
	CheckBox AverageAppendToGraphCheck,disable=!ShowThem
end	

Function ShowHideWaveNameTmpltControls(ShowThem)
	Variable ShowThem
	SetVariable SetListExpression,disable=!ShowThem
End	

Function AppendToGraphCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	NVAR/Z AppendToGraphCheckValue=root:Packages:WM_WavesAverage:AppendToGraphCheckValue
	AppendToGraphCheckValue=checked
End


Function WaveFromMenuProc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

	NVAR WavesFromItem=root:Packages:WM_WavesAverage:WavesFromItem
	
	WavesFromItem=popNum
	ShowHideWavesFromGraphControls(popNum==2)
	ShowHideWaveNameTmpltControls( (popNum==1) %| (popNum==2) %| (popNum==3) )
End

Function f_WaveAveragePanel()

	NVAR/Z GenErrorWaveChecked=root:Packages:WM_WavesAverage:GenErrorWaveChecked
	if (!NVAR_Exists(GenErrorWaveChecked))
		DoAlert 0, "Some data required for building the Waves Average control panel cannot be found."
		return -1
	endif
	NVAR/Z WavesFromItem=root:Packages:WM_WavesAverage:WavesFromItem
	if (!NVAR_Exists(WavesFromItem))
		DoAlert 0, "Some data required for building the Waves Average control panel cannot be found."
		return -1
	endif
	NVAR/Z ErrorMenuSelection=root:Packages:WM_WavesAverage:ErrorMenuSelection
	if (!NVAR_Exists(ErrorMenuSelection))
		DoAlert 0, "Some data required for building the Waves Average control panel cannot be found."
		return -1
	endif
	
	SVAR/Z AveWaveName=root:Packages:WM_WavesAverage:AveWaveName
	if (!SVAR_Exists(AveWaveName))
		DoAlert 0, "Some data required for building the Waves Average control panel cannot be found."
		return -1
	endif
	
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(24,57,226,465) as "Average Waves"
	DoWindow/C WaveAveragePanel
	//ShowTools/A
	SetDrawLayer UserBack
	SetDrawEnv fillpat= 0
	DrawRect 7,301,194,404
	SetDrawEnv fstyle= 1
	DrawText 12,179,"Destination wave names:"
	SetDrawEnv fsize= 10
	DrawText 29,193,"Average:"
	SetDrawEnv fstyle= 1
	DrawText 13,319,"Graph the Results"
	SetDrawEnv fillpat= 0
	DrawRect 7,291,194,5
	SetDrawEnv fstyle= 1
	DrawText 13,23,"Select Waves"
	PopupMenu WaveSourceMenu,pos={15,27},size={55,21},proc=WaveFromMenuProc
	PopupMenu WaveSourceMenu,mode=1,popvalue="root",value= #"LastFolder(root:Packages:WM_WavesAverage:DataFolder)+\";from Top Graph;from Top Table\""
	Button BrowseFolder,pos={140,29},size={45,20},proc=ChooseDataFolderProc,title="Choose"
	SetVariable SetAveWaveName,pos={29,194},size={140,16},title=" ",fSize=10
	SetVariable SetAveWaveName,value= root:Packages:WM_WavesAverage:AveWaveName
	SetVariable SetAveWaveRegion,pos={13,77},size={122,16},title=" Region:",fSize=10
	SetVariable SetAveWaveRegion,value= root:Packages:WM_WavesAverage:AveWaveRegion
	Button Cursors,pos={140,75},size={50,20},title="Cursors",proc=GetCursorRegions
	CheckBox GenErrorCheck,pos={11,108},size={119,14},proc=GenErrorWaveCheckProc,title="Generate Error Wave"
	CheckBox GenErrorCheck,value= 1
	Button WavesAveDoItButton,pos={13,267},size={50,20},proc=WaveAverageDoItButtonProc,title="Do It"
	Button WavesAveHelpButton,pos={136,266},size={50,20},proc=WavesAverageHelpButtonProc,title="Help"
	PopupMenu WavesAverageGraphXWave,pos={26,325},size={140,21},title="X Data:"
	PopupMenu WavesAverageGraphXWave,mode=1,popvalue="_Calculated_",value= #"\"_Calculated_;\\M1-;\"+WaveListMatchWave(\"\", 4,$root:Packages:WM_WavesAverage:AveWaveName, 0, 6, root:Packages:WM_WavesAverage:WA_ListOfWaves, 1)"
	CheckBox AverageAppendToGraphCheck,pos={11,246},size={99,14},proc=AppendToGraphCheckProc,title="Append to Graph"
	CheckBox AverageAppendToGraphCheck,disable=1,value= 1
	SetVariable SetListExpression,pos={21,54},size={160,16},title="Name Template:"
	SetVariable SetListExpression,fSize=10
	SetVariable SetListExpression,value= root:Packages:WM_WavesAverage:ListExpression
	Button WaveAveMakeGraphDoIt,pos={13,355},size={50,20},proc=WaveAverageMakeGraphButtonProc,title="Do It"
	Checkbox IncludeOriginals,pos={91,358},title="Include originals"
	Checkbox Append_,pos={91,378},title="Append to last"
	PopupMenu ErrorTypeMenu,pos={28,104},size={129,21},proc=ErrorTypeMenuProc
	PopupMenu ErrorTypeMenu,mode=2,popvalue="Confidence Interval",value= #"\"Standard Deviations;Confidence Interval;Standard Errors\""
	SetVariable SetErrorWaveName,pos={29,227},size={140,16},title=" ",fSize=10
	SetVariable SetErrorWaveName,value= root:Packages:WM_WavesAverage:ErrorWaveName
	SetVariable SetNSD,pos={110,128},size={40,14},title=" ",fSize=10,disable=1
	SetVariable SetNSD,limits={0,Inf,1},value= root:Packages:WM_WavesAverage:nSD
	SetVariable SetConfInterval,pos={110,128},size={40,14},title=" ",fSize=10,disable=1
	SetVariable SetConfInterval,limits={0,100,1},value= root:Packages:WM_WavesAverage:ConfInterval
	SetWindow kwTopWin,hook=WavesAverageCloseHook
	PopupMenu WaveSourceMenu,mode=1
	PopupMenu ErrorTypeMenu,mode=2
	ShowHideErrorControls(1,1)
	DoWaveAverageProgDrawLayer(1,2)
EndMacro

Function /S LastFolder(folder_str)
	String folder_str
	return StringFromList(ItemsInList(folder_str,":")-1,folder_str,":")
End

Function GetCursorRegions(ctrlName) : ButtonControl
	String ctrlName
	SVar regions=root:Packages:WM_WavesAverage:AveWaveRegion
	String graphs=WinList("*",";","WIN:1")
	String top_graph=StringFromList(0,graphs)
	//print top_graph
	if(strlen(top_graph) && strlen(CsrInfo(A,top_graph)) && strlen(CsrInfo(B,top_graph))) // If cursors A and B are on the top graph.  
		regions=num2str(xcsr(A))+","+num2str(xcsr(B))
	endif
End

Function ChooseDataFolderProc(ctrlName) : ButtonControl
	String ctrlName
	Do
		String cdfBefore = GetDataFolder(1)	// Save current data folder before.
		Execute /Q "CreateBrowser prompt=\"Choose a data folder\",showVars=0,showStrs=0"
		SVar S_BrowserList
		SetDataFolder $cdfBefore
		String folder=StringFromList(0,S_BrowserList)+":"
		if(DataFolderExists(folder))
			break
		endif
	While(1)
	SVar DataFolder=root:Packages:WM_WavesAverage:DataFolder
	DataFolder=folder
	PopupMenu WaveSourceMenu,mode=1
	ShowHideWavesFromGraphControls(0)
End

Function WavesAverageCloseHook(infoStr)
	String infoStr
	
	String Event = StringByKey("EVENT",infoStr)
	if (CmpStr(Event, "kill")== 0)
		DoAlert 1, "Kill the WM_WavesAverage data folder? The Average Waves control panel settings will be lost, but your experiment will be less cluttered."
		if (V_flag == 1)
			KillDataFolder root:Packages:WM_WavesAverage
			return 1
		endif
	endif
	return 0
End

Function WavesAverageHelpButtonProc(ctrlName) : ButtonControl
	String ctrlName

	DisplayHelpTopic "RCG_ Waves Average Procedure File and Control Panel"
End

Function WaveAverageDoItButtonProc(ctrlName) : ButtonControl
	String ctrlName

	String theList
	String aWave
	String TopGraph=WinName(0,1)
	String TopTable=WinName(0,2)
	
	Variable DoConf
	Variable Interval
	Variable AppndGrph=0
	
	SVAR/Z ListExpression=root:Packages:WM_WavesAverage:ListExpression
	if (!SVAR_Exists(ListExpression))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	SVAR/Z ErrorWaveName=root:Packages:WM_WavesAverage:ErrorWaveName
	if (!SVAR_Exists(ErrorWaveName))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	SVAR/Z AveWaveName=root:Packages:WM_WavesAverage:AveWaveName
	if (!SVAR_Exists(AveWaveName))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	SVAR/Z WA_ListOfWaves=root:Packages:WM_WavesAverage:WA_ListOfWaves
	if (!SVAR_Exists(WA_ListOfWaves))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	
	NVAR/Z nSD=root:Packages:WM_WavesAverage:nSD
	if (!NVAR_Exists(nSD))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	NVAR/Z ConfInterval=root:Packages:WM_WavesAverage:ConfInterval
	if (!NVAR_Exists(ConfInterval))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	NVAR/Z ErrorMenuSelection=root:Packages:WM_WavesAverage:ErrorMenuSelection
	if (!NVAR_Exists(ErrorMenuSelection))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif

	ControlInfo WaveSourceMenu
	Variable ListSource=V_value
	switch(ListSource)
		case 1:
			String curr_folder=GetDataFolder(1)
			SVar DataFolder=root:Packages:WM_WavesAverage:DataFolder
			SVar regions=root:Packages:WM_WavesAverage:AveWaveRegion
			SetDataFolder DataFolder
			theList=WaveList(ListExpression,";","")
			//print theList
			String sweep_nums=ListExpand(regions)
			String prefix=RemoveEnding(ListExpression,"*")
			String DataFolderNoColon=RemoveEnding(DataFolder,":")
			theList=AddPrefix(sweep_nums,DataFolderNoColon+":"+prefix)
			Variable i=0
			Do
				String wave_name=StringFromList(i,theList)
				//print wave_name
				if(!exists(wave_name))
					theList=RemoveListItem(i,theList)
				else
					i+=1
				endif
			While(i<ItemsInList(theList))
			String /G root:Packages:WM_WavesAverage:wave_list=theList
			//print theList
			SetDataFolder $curr_folder
			//return 0
			break
	 	case 2:		// from Top Graph
			if (strlen(TopGraph) == 0)
				abort "There are no graphs"
			endif
			theList = WaveListfromGraph(ListExpression, ";", TopGraph)
			ControlInfo AverageAppendToGraphCheck
			AppndGrph = V_value
			break
		case 3:		// from Top Table
			if (strlen(TopTable) == 0)
				abort "There are no tables"
			endif
			theList = WA_TableWaveList("*", ";", TopTable)
		break
	endswitch
	
	Variable ErrorType = 0
	ControlInfo GenErrorCheck
	if (V_value)
		ErrorType = ErrorMenuSelection
		if (ErrorType == 1 || ErrorType==3)
			Interval = nSD
		endif
		if (ErrorType == 2)
			Interval = ConfInterval
		endif
	endif
	
	if(strlen(theList))
		fWaveAverage(theList, ErrorType, Interval, AveWaveName, ErrorWaveName)
	else
		DoAlert 0,"No waves match the given criteria."
		return -1
	endif
	
	if (AppndGrph)
		DoWindow/F $(WinName(0,1))
		aWave =  StringFromList(0, theList, ";")
		CheckDisplayed $AveWaveName
		if (V_flag == 0)
			String TInfo = traceinfo("", NameOfWave($(aWave)),0)
			String AFlags=StringByKey("AXISFLAGS",TInfo)
			if(!strlen(TInfo))
				string axis_bottom = stringfromlist(0,AxisList2("horizontal"))
				string axis_left = stringfromlist(0,AxisList2("vertical"))
				AFlags="/L="+axis_left+"/B="+axis_bottom
			endif
			String XWaveInfo = PossiblyQuoteName(StringByKey("XWAVE", TInfo))
			if (strlen(XWAveInfo) > 0)
				XWaveInfo = " vs "+StringByKey("XWAVEDF", TInfo)+XWaveInfo
			endif
			String AppCom = "AppendToGraph "+AFlags+" "+AveWaveName+XWaveInfo
			Execute AppCom
		endif
		if (ErrorType == 0)
			ErrorBars $AveWaveName, OFF
		else
			ErrorBars $AveWaveName, Y wave=($ErrorWaveName, $ErrorWaveName)
		endif
	endif
	
	WA_ListOfWaves = theList
End

Function WaveAverageMakeGraphButtonProc(ctrlName) : ButtonControl
	String ctrlName

	SVAR/Z ErrorWaveName=root:Packages:WM_WavesAverage:ErrorWaveName
	if (!SVAR_Exists(ErrorWaveName))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	SVAR/Z AveWaveName=root:Packages:WM_WavesAverage:AveWaveName
	if (!SVAR_Exists(AveWaveName))
		DoAlert 0, "Some data required for the operation cannot be found. Try closing the panel and re-opening it."
		return -1
	endif
	
	Wave/Z AW = $AveWaveName
	if (!WaveExists(AW))
		abort "The wave "+AveWaveName+" does not exist. Perhaps you need to click Do It in the upper part of the panel."
	endif
	
	ControlInfo WavesAverageGraphXWave
	String x_wave_name=S_Value
	Wave /Z XW=$x_wave_name
	if (!WaveExists(XW) && cmpstr(x_wave_name,"_Calculated_"))
		abort "The X wave, "+x_wave_name+" cannot be found."
	endif
	ControlInfo/W=WaveAveragePanel IncludeOriginals
	Variable include_originals=V_value
	SVAR wave_list=root:Packages:WM_WavesAverage:wave_list
	
	ControlInfo/W=WaveAveragePanel Append_
	Variable append_=V_value
	SVar /Z graphName=root:Packages:WM_WavesAverage:graphName
	if(!append_ || (!SVar_Exists(graphName) || !WinType(graphName)))
		Display /K=1 /N=WavesAverageGraph as "Wave Average"
		String /G root:Packages:WM_WavesAverage:graphName=WinName(0,1)
#if exists("AverageWavesButtons")==6
		ControlBar /T 30
		Button CopyCursors, size={120,25}, proc=AverageWavesButtons, title="Copy Cursors to Sweeps"
#endif
		string axis_left = "left"
		string axis_bottom = "bottom"
	else
		DoWindow /F $graphName
		axis_bottom = stringfromlist(0,AxisList2("horizontal"))
		axis_left = stringfromlist(0,AxisList2("vertical"))
	endif
	if(include_originals)
		Variable i
		for(i=0;i<ItemsInList(wave_list);i+=1)
			String wave_name=StringFromList(i,wave_list)
			//print wave_name
			if(WaveExists(XW))
				AppendToGraph /c=(0,0,0) $wave_name vs XW
			else
				AppendToGraph /c=(0,0,0) $wave_name
			endif
		endfor
	endif
	if (WaveExists(XW))
		//if(append_)
		//	AppendToGraph /l=axis_left/b=axis_bottom/c=(65535,0,0) AW vs XW
		//else
			AppendToGraph /c=(65535,0,0) AW vs XW
		//endif
	else
		//if(append_)
		//	AppendToGraph /l=axis_left/b=axis_bottom/c=(65535,0,0) AW
		//else
			AppendToGraph /c=(65535,0,0) AW
		//endif
	endif
		
	ControlInfo/W=WaveAveragePanel GenErrorCheck
	if (V_value)
		ErrorBars $AveWaveName, Y wave=($ErrorWaveName, $ErrorWaveName)
	endif
End

Function/S WaveListfromGraph(matchStr, sepStr, graphName)
	String matchStr, sepStr, graphName
	
	String theList=""
	if (strlen(graphName) == 0)
		graphName = WinName(0,1)
	endif
	
	Variable i = 0
	do
		Wave/Z w = WaveRefIndexed(graphName,i,1)
		if (!WaveExists(w))
			break
		endif
		if (stringmatch(NameOfWave(w), matchStr))
			theList += GetWavesDataFolder(w, 2)+sepStr
		endif
		i += 1
	while (1)
	return theList
end

Function/S WA_TableWaveList(matchStr, sepStr, tableName)
	String matchStr, sepStr, tableName
	
	if (strlen(tableName) == 0)
		TableName=WinName(0,2)
	endif
	
	String ListofWaves=""
	String thisColName
	Variable i, nameLen
	
	GetSelection table, $TableName, 7
	String SelectedColNames=S_selection
	String SelectedDataFolders=S_dataFolder
	
	if (V_startCol == V_endCol)		// There is no selection or the selection doesn't make sense; use the whole table
		i = 0
		do
			Wave/Z w=WaveRefIndexed(TableName,i,1)
			if (!waveExists(w))
				break
			endif
			ListofWaves += GetWavesDataFolder(w, 2)+";"
		
			i += 1
		while (1)
	else	
		i = 0
		do
			thisColName = StringFromList(i, SelectedColNames, ";")
			if (strlen(thisColName) == 0)
				break
			endif
			nameLen = strlen(thisColName)
			if (CmpStr(thisColName[nameLen-2,nameLen-1], ".i") != 0)
				if (CmpStr(thisColName[nameLen-3,nameLen-3], "]") != 0)
					thisColName = thisColName[0,nameLen-3]
					if (stringmatch(thisColName, matchStr))
						thisColName = StringFromList(i, SelectedDataFolders,";")+thisColName
						if (Exists(thisColName))
							ListofWaves += thisColName+";"
						endif
					endif
				endif
			endif
			i += 1
		while (1)
	endif

	return ListofWaves
end
