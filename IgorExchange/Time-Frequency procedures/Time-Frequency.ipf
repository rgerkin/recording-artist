#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1.05		//February 22, 2008
//#pragma IndependentModule=TFToolkit
#pragma IgorVersion=6
#include <WaveSelectorWidget>
#include ":Time-Freq Decompositions"
#include ":Spectral Estimates"
#include ":Interpolations"
#include ":Time-Freq Backgrounds"
#include ":DynamiTabs"

//#include ":Lomb Periodogram"

//This procedure file provides functions to create a control panel-driven plot of the time-frequency content of a signal.
//The features are described in a separate help file.

//The procedure file relies on the AR(1), Interpolations, Spectral Estimates, and Time-Freq Decompositions procedure files.

//FOR PROGRAMMERS WANTING TO EXTEND THE FUNCTIONALITY:
//To add a module in a separate tab, see the TFPlotTabsAddTab_prototype function.
//To add interpolation, spectral estimate, or time-frequency decomposition methods, see the separate procedure files.

//written by Ben Cramer (bscramer@uoregon.edu)

static constant kMaxNameLength=33		//Igor names are restricted to 31 characters; add 2 for enclosing single-quotes in liberal names
static constant kTFVersion=1.05		//current Time-Frequency procedure version

static strconstant ksWorkFolder="root:Packages:TFToolkit:TFPlot"
static strconstant ksWorkFolderPrefix="TFAnalysis"

Function/s PopupVals(kw)
	string kw
	
	strswitch(kw)
		case "VertAxis":
			return "Linear frequency;Linear period;Log(10);Log(2)"
		case "AmpAxis":
			return "Linear;Log(10);Log(2)"
		case "Norms":
			return "Magnitude Squared;Magnitude;Sin Peak Amplitude;Background Normalized"
		case "SwapXY":
			return "vertical spectrum plot;vertical data plot"
	endSwitch
end

Menu "Analysis"
	"Time-Frequency Investigation",TimeFrequencyInvestigation()
end

Structure TF_GlobalRefs							//structure containing references to all globals, so they don't have to be redefined constantly
	
//Folders
	string TFfolder
	string SettingsFolder
	string PlotFolder
	string BackgroundFolder
	string SpectrumFolder
	string TFDecompFolder

//waves
//data
	wave dw,xw,dw_int								//wave references for user selected data and x-value waves and for interpolated data
//decomposition
	wave TFmag,TFfrequency,TFcoi,TFGlobalSpec
//spectrum
	wave SpectrumMag,SpectrumFrequency			//wave references for spectrum
//background
	wave BackgroundMag,BackgroundFrequency				//wave references for expected background spectrum
//appearance
	wave CTabMod										//wave reference for color table to display time-frequency decomposition
	wave/t vertP,vertF
	wave vertPy,vertFy								//manual tick waves
//for display
	wave PlotTFdecomp,PlotTFGlobalSpec,PlotTFdecompX
	wave PlotSpectrum,PlotSpectrumX
	wave PlotBackground,PlotBackgroundX

//window names
	SVAR Win											//name of window
	string ctrlWin,dataWin							//tabbed control window, and data selection control window
	SVAR dwPath,xwPath
	NVAR ProtectPlot,dataWinHide
//preprocessing tab
//	SVAR DetrendType									//current setting of detrend choice
//	NVAR RemoveOutliers,RemoveFliers
//	NVAR RemoveSD,RemoveRG						//standard deviation and data window to define fliers/outliers
//interpolation tab
	SVAR InterpType									//current setting of TF interpolation popup selector
	NVAR LiveUpdate									//auto-interpolate setting
	NVAR InterpRes,Xmin,Xmax						//interpolation parameters
	NVAR InterpSV0,InterpSV1,InterpSV2			//current setting of interpolation setvariable parameters
	SVAR InterpPM0,InterpPM1,InterpPM2		//current setting of interpolation popupmenu parameters
//decomposition tab
	SVAR DecompType									//current setting of TF decomposition popup selector
	NVAR PeriodMin,PeriodMax						//decomposition parameters
	NVAR freqRes
	NVAR TFDecompSV0,TFDecompSV1,TFDecompSV2	//current setting of decomposition setvariable parameters
	SVAR TFDecompPM0,TFDecompPM1,TFDecompPM2	//current setting of decomposition popupmenu parameters
//spectrum tab
	SVAR SpectrumType								//current setting of TF spectrum popup selector
	NVAR SpectrumSV0,SpectrumSV1,SpectrumSV2	//current setting of spectrum setvariable parameters
	SVAR SpectrumPM0,SpectrumPM1,SpectrumPM2	//current setting of spectrum popupmenu parameters
//background tab
	SVAR BackgroundType								//current setting of TF spectrum popup selector
	NVAR BackgroundSV0,BackgroundSV1,BackgroundSV2	//current setting of spectrum setvariable parameters
	SVAR BackgroundPM0,BackgroundPM1,BackgroundPM2	//current setting of spectrum popupmenu parameters
	NVAR SigLevel
//appearance tab
	SVAR AmpAxis
	SVAR Norms										//current setting of normalization popup selector
	SVAR VertAxis										//current setting of vertical axis popup selector
	SVAR CTabMode									//color table
	NVAR CTabMax,CTabMin,CTabTau				//color table parameters
	NVAR NTicks										//axis tick parameters
	SVAR SwapXY										//plot rotation mode
endStructure

function TF_MakeRefs(TFgr,win)			//instead of defining lists of references in each function, a single call to this takes care of all
	struct TF_GlobalRefs &TFgr
	string win
		
	NewDataFolderPath(ksWorkFolder)
	
	win=stringfromlist(0,win,"#")				//to avoid referencing panels
	string AnalysisFolder=getuserdata(win,"","TFfolder")
	if(strlen(AnalysisFolder))
		TFgr.TFfolder=ksWorkFolder+":"+AnalysisFolder
	else
		TFgr.TFfolder=" "		//datafolderexists chokes on 0-length string
	endif
	if(datafolderexists(TFgr.TFfolder))
	//Folders
		TFgr.SettingsFolder=TFgr.TFfolder+":Settings"
		NewDataFolderPath(TFgr.SettingsFolder)
		TFgr.PlotFolder=TFgr.TFfolder+":Plot"
		NewDataFolderPath(TFgr.PlotFolder)
	
		string/g $(TFgr.SettingsFolder+":win")
		SVAR TFgr.win=$(TFgr.SettingsFolder+":win")
		TFgr.win=win								//this attaches the analysis folder to this window
		TFgr.ctrlWin=TFgr.win+"#TFCtrlPanel",TFgr.dataWin=TFgr.win+"#TFWaveSelPanel"
		
		variable/g $(TFgr.SettingsFolder+":ProtectPlot"),$(TFgr.SettingsFolder+":LiveUpdate"),$(TFgr.SettingsFolder+":dataWinHide")
		NVAR TFgr.ProtectPlot=$(TFgr.SettingsFolder+":ProtectPlot"),TFgr.LiveUpdate=$(TFgr.SettingsFolder+":LiveUpdate"),TFgr.dataWinHide=$(TFgr.SettingsFolder+":dataWinHide")

	//data selection
		string/g $(TFgr.SettingsFolder+":dwPath"),$(TFgr.SettingsFolder+":xwPath")
		SVAR TFgr.dwPath=$(TFgr.SettingsFolder+":dwPath"),TFgr.xwPath=$(TFgr.SettingsFolder+":xwPath")
	//preprocessing tab
//		string/g $(TFgr.SettingsFolder+":DetrendType")
//		SVAR TFgr.DetrendType=$(TFgr.SettingsFolder+":DetrendType")	
//		variable/g $(TFgr.SettingsFolder+":RemoveOutliers"),$(TFgr.SettingsFolder+":RemoveFliers")
//		NVAR TFgr.RemoveOutliers=$(TFgr.SettingsFolder+":RemoveOutliers"),TFgr.RemoveFliers=$(TFgr.SettingsFolder+":RemoveFliers")
//		variable/g $(TFgr.SettingsFolder+":RemoveSD"),$(TFgr.SettingsFolder+":RemoveRG")
//		NVAR TFgr.RemoveSD=$(TFgr.SettingsFolder+":RemoveSD"),TFgr.RemoveRG=$(TFgr.SettingsFolder+":RemoveRG")
	//interpolation tab
		string/g $(TFgr.SettingsFolder+":InterpType")
		SVAR TFgr.InterpType=$(TFgr.SettingsFolder+":InterpType")
		variable/g $(TFgr.SettingsFolder+":InterpRes")
		NVAR TFgr.InterpRes=$(TFgr.SettingsFolder+":InterpRes")
		variable/g $(TFgr.SettingsFolder+":Xmin"),$(TFgr.SettingsFolder+":Xmax")
		NVAR TFgr.Xmin=$(TFgr.SettingsFolder+":Xmin"),TFgr.Xmax=$(TFgr.SettingsFolder+":Xmax")
		NVAR/Z TFgr.InterpSV0=$(TFgr.SettingsFolder+":Interpolation:"+TFgr.InterpType+":SV0")
		NVAR/Z TFgr.InterpSV1=$(TFgr.SettingsFolder+":Interpolation:"+TFgr.InterpType+":SV1")
		NVAR/Z TFgr.InterpSV2=$(TFgr.SettingsFolder+":Interpolation:"+TFgr.InterpType+":SV2")
		SVAR/Z TFgr.InterpPM0=$(TFgr.SettingsFolder+":Interpolation:"+TFgr.InterpType+":PM0")
		SVAR/Z TFgr.InterpPM1=$(TFgr.SettingsFolder+":Interpolation:"+TFgr.InterpType+":PM1")
		SVAR/Z TFgr.InterpPM2=$(TFgr.SettingsFolder+":Interpolation:"+TFgr.InterpType+":PM2")
	//decomposition tab
		string/g $(TFgr.SettingsFolder+":DecompType")
		SVAR TFgr.DecompType=$(TFgr.SettingsFolder+":DecompType")
		variable/g $(TFgr.SettingsFolder+":PeriodMin"),$(TFgr.SettingsFolder+":PeriodMax")
		NVAR TFgr.PeriodMin=$(TFgr.SettingsFolder+":PeriodMin"),TFgr.PeriodMax=$(TFgr.SettingsFolder+":PeriodMax")
		variable/g $(TFgr.SettingsFolder+":freqRes")
		NVAR TFgr.freqRes=$(TFgr.SettingsFolder+":freqRes")
		NVAR/Z TFgr.TFDecompSV0=$(TFgr.SettingsFolder+":TFDecomposition:"+TFgr.DecompType+":SV0")
		NVAR/Z TFgr.TFDecompSV1=$(TFgr.SettingsFolder+":TFDecomposition:"+TFgr.DecompType+":SV1")
		NVAR/Z TFgr.TFDecompSV2=$(TFgr.SettingsFolder+":TFDecomposition:"+TFgr.DecompType+":SV2")
		SVAR/Z TFgr.TFDecompPM0=$(TFgr.SettingsFolder+":TFDecomposition:"+TFgr.DecompType+":PM0")
		SVAR/Z TFgr.TFDecompPM1=$(TFgr.SettingsFolder+":TFDecomposition:"+TFgr.DecompType+":PM1")
		SVAR/Z TFgr.TFDecompPM2=$(TFgr.SettingsFolder+":TFDecomposition:"+TFgr.DecompType+":PM2")
	//spectrum tab
		string/g $(TFgr.SettingsFolder+":SpectrumType")
		SVAR TFgr.SpectrumType=$(TFgr.SettingsFolder+":SpectrumType")
		NVAR/Z TFgr.SpectrumSV0=$(TFgr.SettingsFolder+":Spectrum:"+TFgr.SpectrumType+":SV0")
		NVAR/Z TFgr.SpectrumSV1=$(TFgr.SettingsFolder+":Spectrum:"+TFgr.SpectrumType+":SV1")
		NVAR/Z TFgr.SpectrumSV2=$(TFgr.SettingsFolder+":Spectrum:"+TFgr.SpectrumType+":SV2")
		SVAR/Z TFgr.SpectrumPM0=$(TFgr.SettingsFolder+":Spectrum:"+TFgr.SpectrumType+":PM0")
		SVAR/Z TFgr.SpectrumPM1=$(TFgr.SettingsFolder+":Spectrum:"+TFgr.SpectrumType+":PM1")
		SVAR/Z TFgr.SpectrumPM2=$(TFgr.SettingsFolder+":Spectrum:"+TFgr.SpectrumType+":PM2")
	//background tab
		string/g $(TFgr.SettingsFolder+":BackgroundType")
		SVAR TFgr.BackgroundType=$(TFgr.SettingsFolder+":BackgroundType")
		variable/g $(TFgr.SettingsFolder+":SigLevel")
		NVAR TFgr.SigLevel=$(TFgr.SettingsFolder+":SigLevel")
	//appearance tab
		string/g $(TFgr.SettingsFolder+":AmpAxis"),$(TFgr.SettingsFolder+":VertAxis")
		SVAR TFgr.AmpAxis=$(TFgr.SettingsFolder+":AmpAxis"),TFgr.VertAxis=$(TFgr.SettingsFolder+":VertAxis")
		string/g $(TFgr.SettingsFolder+":Norms")
		SVAR TFgr.Norms=$(TFgr.SettingsFolder+":Norms")
		string/g $(TFgr.SettingsFolder+":CTabMode")
		SVAR TFgr.CTabMode=$(TFgr.SettingsFolder+":CTabMode")
		if(strlen(TFgr.CTabMode)==0)
			TFgr.CTabMode="Terrain"
		endif
		variable/g $(TFgr.SettingsFolder+":CTabMax"),$(TFgr.SettingsFolder+":CTabMin")
		NVAR TFgr.CTabMax=$(TFgr.SettingsFolder+":CTabMax"),TFgr.CTabMin=$(TFgr.SettingsFolder+":CTabMin")
		variable/g $(TFgr.SettingsFolder+":CTabTau")
		NVAR TFgr.CTabTau=$(TFgr.SettingsFolder+":CTabTau")
		variable/g $(TFgr.SettingsFolder+":NTicks")
		NVAR TFgr.NTicks=$(TFgr.SettingsFolder+":NTicks")
		string/g $(TFgr.SettingsFolder+":SwapXY")
		SVAR TFgr.SwapXY=$(TFgr.SettingsFolder+":SwapXY")

//Folders
		TFgr.BackgroundFolder=TFgr.TFfolder+":Background";NewDataFolderPath(TFgr.BackgroundFolder)
		TFgr.SpectrumFolder=TFgr.TFfolder+":Spectrum:"+TFgr.SpectrumType;NewDataFolderPath(TFgr.SpectrumFolder)
		TFgr.TFDecompFolder=TFgr.TFfolder+":TFDecomposition:"+TFgr.DecompType
		if(!StringMatch(TFgr.DecompType,"-none-"))
			NewDataFolderPath(TFgr.TFDecompFolder)
		endif
		if(!StringMatch(TFgr.SpectrumType,"-none-"))
			NewDataFolderPath(TFgr.SpectrumFolder)
		endif
	
	//waves
	//data
		wave/Z TFgr.dw=$(TFgr.dwPath),TFgr.xw=$(TFgr.xwPath)
		wave/Z TFgr.dw_int=$(TFgr.TFfolder+":IntData")
	//decomposition
		wave/Z TFgr.TFmag=$(TFgr.TFDecompFolder+":magnitude"),TFgr.TFGlobalSpec=$(TFgr.TFDecompFolder+":GlobalSpec")
		wave/Z TFgr.TFfrequency=$(TFgr.TFDecompFolder+":frequency")
		wave/Z TFgr.TFcoi=$(TFgr.TFDecompFolder+":COI")
	//spectrum
		wave/Z TFgr.BackgroundMag=$(TFgr.Backgroundfolder+":Amplitude"),TFgr.Backgroundfrequency=$(TFgr.Backgroundfolder+":frequency")
		wave/Z TFgr.SpectrumMag=$(TFgr.SpectrumFolder+":Amplitude"),TFgr.SpectrumFrequency=$(TFgr.SpectrumFolder+":Frequency")
	//appearance
		wave/Z TFgr.CTabMod=$(TFgr.TFfolder+":CTabMod")
		wave/Z/t TFgr.vertP=$(TFgr.TFfolder+":vertP"),TFgr.vertF=$(TFgr.TFfolder+":vertF")
		wave/Z TFgr.vertPy=$(TFgr.TFfolder+":vertPy"),TFgr.vertFy=$(TFgr.TFfolder+":vertFy")			//manual tick waves for periods
	
	//for display
		wave/Z TFgr.PlotTFdecomp=$(TFgr.PlotFolder+":TFdecomp"),TFgr.PlotTFdecompX=$(TFgr.PlotFolder+":TFdecompX")
		wave/Z TFgr.PlotTFGlobalSpec=$(TFgr.PlotFolder+":TFGlobalSpec")
		wave/Z TFgr.PlotBackground=$(TFgr.PlotFolder+":Background"),TFgr.PlotBackgroundX=$(TFgr.PlotFolder+":BackgroundX")
		wave/Z TFgr.PlotSpectrum=$(TFgr.PlotFolder+":Spectrum"),TFgr.PlotSpectrumX=$(TFgr.PlotFolder+":SpectrumX")
	endif
end

function/s TF_FindWaveAnalysis(dwPath)
	string dwPath
	
	string returnList="",folderName
	variable i
	for(i=0;;i+=1)
		folderName=GetIndexedObjName(ksWorkFolder,4,i)
		if(strlen(folderName)==0)
			break
		endif
		SVAR/Z thisdwPath=$(ksWorkFolder+":"+folderName+":Settings:dwPath")
		if(SVAR_exists(thisdwPath))
			if(cmpstr(dwPath,thisdwPath)==0)
				returnList=AddListItem(folderName,returnList)
			endif
		endif
	endfor
	return returnList
end	

function/s TF_FindUnplottedAnalysis()
	
	string returnList="",folderName
	variable i
	for(i=0;;i+=1)
		folderName=GetIndexedObjName(ksWorkFolder,4,i)
		if(strlen(folderName)==0)
			break
		endif
		SVAR/Z thisWin=$(ksWorkFolder+":"+folderName+":Settings:win")
		if(SVAR_exists(thisWin))
			if(strlen(thisWin))
				dowindow $thisWin
				if(v_flag)
					if(cmpstr(folderName,GetUserData(thisWin,"","TFfolder")))
						thisWin=""
					endif
				else
					thisWin=""
				endif
			endif
		endif
		if(!SVAR_exists(thisWin) || !strlen(thisWin))
			returnList=AddListItem(folderName,returnList)
		endif
	endfor
	return returnList
end	

function TF_LoadSettings(TFgr,dwPath,pan)
	struct TF_GlobalRefs &TFgr
	string dwPath,pan
	
	
	wave dw=$dwPath
	string dwPath0=""
	if(SVAR_exists(TFgr.dwPath))
		dwPath0=TFgr.dwPath
	endif
	string win=stringfromlist(0,pan,"#")
	string oldAnalyses=TF_FindWaveAnalysis(dwPath)
	string loadFolder
	variable i,nOld=itemsinlist(oldAnalyses),loadFlag=0
	string dfSave=getdatafolder(1)
	
	if(waveexists(dw))					//Check whether data wave is being changed
		if(nOld)		//has wave been analyzed?
			for(i=0;i<nOld;i+=1)
				loadFolder=stringfromlist(i,oldAnalyses)
				SVAR TFgr.win=$(ksWorkFolder+":"+loadFolder+":Settings:win")
				variable v_flag=0
				if(strlen(TFgr.win))				//dowindow chokes on 0-length names
					dowindow $TFgr.win
				endif
				if(v_flag)
					if(cmpstr(loadFolder,GetUserData(TFgr.win,"","TFfolder")))
						TimeFrequencyInvestigation()
						TF_AnalysisAttach(winname(0,1),loadFolder)
					else
						dowindow/f $TFgr.win
					endif					
				elseif(!loadFlag)					//On first unplotted analysis, change the current plot
					loadflag=1
					dowindow/f $win
					TF_AnalysisDetach(win)
					TF_AnalysisAttach(winname(0,1),loadFolder)
				else
					TimeFrequencyInvestigation()
					TF_AnalysisAttach(winname(0,1),loadFolder)
				endif
				if(nOld>1)
					getwindow $winName(0,1) gsize
					string ScreenCoords=stringfromlist(2,stringbykey("SCREEN1",IgorInfo(0),":",";"),"=")
					variable offsetHeight=(2*str2num(stringfromlist(3,ScreenCoords,",")))/(3*nOld)
					variable offsetWidth=(2*str2num(stringfromlist(2,ScreenCoords,",")))/(3*nOld)
					MoveWindow/W=$winName(0,1) i*offsetWidth,i*offsetHeight,i*offsetWidth+V_right-V_left,i*offsetHeight+V_bottom-V_top
				endif
			endfor
			if(!loadFlag)
				WS_ClearSelection(pan,"DataWaveSelect")
				WS_SelectAnObject(pan,"DataWaveSelect",dwPath0,openFoldersAsNeeded=1)	//reset data wave selector to previous selection
			endif
			return 0											//proper window has already been brought to front, so should exit
		else								//need to change the settings for this window
			TF_AnalysisDetach(win)

			SetDataFolder $ksWorkFolder
			loadFolder=UniqueName(ksWorkFolderPrefix,11,0)
			newdatafolderpath (loadFolder+":Settings")
			SetDataFolder $dfSave
			string/g $(ksWorkFolder+":"+loadFolder+":Settings:dwPath")=dwPath
			
			TF_AnalysisAttach(win,loadFolder,reset=1)
		endif
	endif
end

Function TF_AnalysisDetach(win)
	string win
	
	struct TF_GlobalRefs TFgr
	TF_MakeRefs(TFgr,win)
	TFgr.win=""					//dowindow chokes on 0-length string
	SetWindow $win userdata(TFfolder)=""
end

Function TF_AnalysisAttach(win,AnalysisFolder[,reset])
	string win,AnalysisFolder
	variable reset
	
	struct TF_GlobalRefs TFgr
	SetWindow $win userdata(TFfolder)=AnalysisFolder
	TF_MakeRefs(TFgr,win)
	if(reset)
		TF_SetParameterDefaults(TFgr,new=1)
	endif
	TabControl TFPlotTabs value=0,win=$TFgr.ctrlWin
	TF_BuildControlPanel(TFgr)

	WS_ClearSelection(TFgr.dataWin,"DataWaveSelect")
	if(waveexists(TFgr.dw))
		WS_SelectAnObject(TFgr.dataWin,"DataWaveSelect",getwavesdatafolder(TFgr.dw,2),openFoldersAsNeeded=1)
	endif
	WS_ClearSelection(TFgr.dataWin,"TimeWaveSelect")
	if(waveexists(TFgr.xw))
		WS_SelectAnObject(TFgr.dataWin,"TimeWaveSelect",getwavesdatafolder(TFgr.xw,2),openFoldersAsNeeded=1)
	else
		WS_OpenAFolderFully(TFgr.dataWin,"TimeWaveSelect",getwavesdatafolder(TFgr.dw,1))
	endif
	TF_LiveUpdate(TFgr)
end

Function/s TFListFunctions(prefix,none)
	string prefix
	variable none
	
	variable XY
	
	string FuncList,FuncListXY
	FuncList=(FunctionList(prefix+"_*",";","NPARAMS:1,VALTYPE:1,KIND:6"))
	FuncList=RemoveFromList(prefix+"_prototype",FuncList)
	FuncList=ReplaceString(prefix+"_",FuncList,"")
	
	
	if(XY)
		FuncListXY=(FunctionList(prefix+"XY_*",";","NPARAMS:1,VALTYPE:1,KIND:6"))
		FuncListXY=RemoveFromList(prefix+"XY_prototype",FuncListXY)
		FuncListXY=ReplaceString(prefix+"XY_",FuncListXY,"")	
		if(itemsinlist(FuncListXY))
			FuncList="\\M1(XY methods:;\\M0"+FuncListXY+"\\M1(waveform methods:;\\M0"+FuncList
		endif
	endif
	
	if(none)
		FuncList="none;\\M1-\\M0;"+FuncList
	endif	
	return FuncList
end

Function TF_SetParameterDefaults(TFgr[,new])
	struct TF_GlobalRefs &TFgr
	variable new
	
	TF_MakeRefs(TFgr,TFgr.win)
	
	if(new)
	//global variables
		TFgr.LiveUpdate=1;TFgr.ProtectPlot=0
	//data selection tab
//		TFgr.RemoveSD=3;TFgr.RemoveRG=1							//statistically "bad" parameters
	//interpolation tab
		TFgr.InterpType=stringfromlist(0,TFListFunctions("INTERPOLATION",0))
		TFgr.InterpRes=nan;TFgr.Xmin=nan;TFgr.Xmax=nan			//interpolation parameters
	//decomposition tab
		TFgr.DecompType=stringfromlist(0,TFListFunctions("TFDECOMPOSITION",1))
		TFgr.PeriodMin=nan;TFgr.PeriodMax=nan						//decomposition parameters
		TFgr.freqRes=1
	//spectrum tab
		TFgr.SpectrumType=stringfromlist(0,TFListFunctions("SPECTRUM",1))
	//background tab
		TFgr.BackgroundType=stringfromlist(0,TFListFunctions("TFBACKGROUND",1))
		TFgr.sigLevel=95													//significance level for spectrum display
	//appearance tab
		TFgr.VertAxis=stringfromlist(2,PopupVals("VertAxis"))
		TFgr.AmpAxis=stringfromlist(0,PopupVals("AmpAxis"))
		TFgr.Norms=stringfromlist(0,PopupVals("Norms"))
		TFgr.CTabMax=nan;TFgr.CTabMin=nan;TFgr.CTabTau=10		//color table parameters
		TFgr.CTabMode="Terrain"			
		TFgr.NTicks=5													//axis parameters
		TFgr.SwapXY=stringfromlist(0,PopupVals("SwapXY"))
	endif
	
	variable np=numpnts(TFgr.dw)
	if(waveexists(TFgr.xw))
		differentiate/P/EP=1/METH=1 TFgr.xw /D=$(TFgr.SettingsFolder+":tmp_dxw")
		wave tmp_dxw=$(TFgr.SettingsFolder+":tmp_dxw")
		sort tmp_dxw,tmp_dxw
		wavestats/M=1/q TFgr.xw
		TFgr.InterpRes=tmp_dxw[(v_npnts-2)/2]		//calculate median delta
		TFgr.Xmin=v_min;TFgr.Xmax=v_max
		killwaves tmp_dxw
	elseif(waveexists(TFgr.dw))
		TFgr.InterpRes=deltax(TFgr.dw)			//use data deltax
		if(TFgr.InterpRes>0)
			TFgr.Xmin=leftx(TFgr.dw);TFgr.Xmax=rightx(TFgr.dw)-TFgr.InterpRes
		else
			TFgr.Xmax=leftx(TFgr.dw);TFgr.Xmin=rightx(TFgr.dw)-TFgr.InterpRes
		endif
	endif
	TFgr.InterpRes=abs(TFgr.InterpRes)
	TFgr.PeriodMin=2*TFgr.InterpRes;TFgr.PeriodMax=(TFgr.Xmax-TFgr.Xmin)/4

	TF_BuildControlPanel(TFgr)
	WS_ClearSelection(TFgr.dataWin,"DataWaveSelect")
	WS_SelectAnObject(TFgr.dataWin,"DataWaveSelect",getwavesdatafolder(TFgr.dw,2),openFoldersAsNeeded=1)
	WS_ClearSelection(TFgr.dataWin,"TimeWaveSelect")
	if(waveexists(TFgr.xw))
		WS_SelectAnObject(TFgr.dataWin,"TimeWaveSelect",getwavesdatafolder(TFgr.xw,2),openFoldersAsNeeded=1)
	else
		WS_OpenAFolderFully(TFgr.dataWin,"TimeWaveSelect",getwavesdatafolder(TFgr.dw,1))
	endif
end

Function TF_WBLNameFilter(aName,contents)
	string aName;variable contents
	
	if(stringMatch(lowerstr(aName),"root:packages*"))
		return 0
	else
		return 1
	endif
end

Function TimeFrequencyInvestigation()		//builds initial controls
	
	
	string win,TFCtrlPanelName,TFWaveSelPanelName
	variable winTop,winBottom,winLeft,winRight
	string ScreenCoords
	win=uniquename("TFPlot",6,0)
	TFCtrlPanelName=win+"#TFCtrlPanel"
	TFWaveSelPanelName=win+"#TFWaveSelPanel"
//Build window
//	strSwitch(IgorInfo(2))
//		case "Macintosh":
//			ScreenCoords=stringfromlist(2,stringbykey("SCREEN1",IgorInfo(0),":",";"),"=")
//			winBottom=str2num(stringfromlist(3,ScreenCoords,","));winRight=str2num(stringfromlist(2,ScreenCoords,","))
//			break
//		case "Windows":
//			GetWindow kwFrameInner wsize
//			winBottom=V_bottom;winRight=V_right
//			break
//	endSwitch
//	winTop=0;winLeft=0
//	winBottom=(winBottom)/2
//	winRight=(winRight)/3
	winLeft=0;winTop=0;winRight=(700-255)*72/ScreenResolution;winBottom=425*72/ScreenResolution
	Display/K=1/W=(winLeft,winTop,winRight,winBottom)/N=$(win) as "Time Frequency Plot"
	NewPanel/k=2/EXT=2/HOST=$win/n=TFCtrlPanel/W=(700,0,700,150)/HIDE=1 as "Time Frequency controls"
	NewPanel/k=2/EXT=0/HOST=$win/n=TFWaveSelPanel/W=(5,425,250,425) as "Select waves:"

	SetWindow $win userdata(TFversion)=num2str(kTFVersion)
	SetWindow $win userdata(TFfolder)=("")
	SetWindow $win hook(TFPlotHook)=$"TF_WindowHook"
	
//Build controls for data selection - other controls will appear only when data wave has been selected
	WaveBrowserListbox("DataWaveSelect",TFWaveSelPanelName,promptText="Select Data Wave:",Xpos=5,Ypos=5,Xsize=240,Ysize=185,WaveOpts="CMPLX:0,TEXT:0,INTEGER:0,DIMS:1,UNSIGNED:0,WORD:0",procName="TFWBListbox",nameFilterProc="TF_WBLNameFilter")
	PopupMenu sortKind pos={5,400},title="Sort by",win=$TFWaveSelPanelName
	MakePopupIntoWaveSelectorSort(TFWaveSelPanelName,"DataWaveSelect","sortKind")
	
//help and wave selection button
	ControlBar 25
	Button DisplayHelp pos={5,2},size={60,20},proc=TFButton,title="Help",win=$win
end	



Function TF_SaveHook(rN,fileName,path,type,creator,kind)
	Variable rN,kind
	String fileName,path,type,creator
	
	string folderList=TF_FindUnplottedAnalysis()
	variable nFolders=itemsInList(folderList),i
	if(nFolders)
		DoAlert 1,"Preserve unplotted Time-Frequency analysis folders?"
		if(v_flag==2)
			for(i=0;i<nFolders;i+=1)
				killdatafolder/z $(ksWorkFolder+":"+stringfromlist(i,folderList))
			endfor
		endif
	endif
end	

function TF_WindowHook(WHS)
	struct WMWinHookStruct &WHS
	
	if(itemsinlist(GetRTStackInfo(3))>1)
		return -1
	endif
	
	struct TF_GlobalRefs TFgr
	TF_MakeRefs(TFgr,WHS.winName)
	
	string dataWin=(WHS.winName+"#TFWaveSelPanel")
	string ctrlWin=(WHS.winName+"#TFCtrlPanel")

	StrSwitch(WHS.eventName)
		case "activate":
			execute/Q/Z "SetIgorHook BeforeExperimentSaveHook="+GetIndependentModuleName()+"#TF_SaveHook"
			if(strlen(GetUserData(WHS.winName,"","TFfolder")))
			
				TF_VersionCheck(WHS.winName)
				if(TFgr.ProtectPlot)
					setwindow $TFgr.dataWin,hide=1
				else
					setwindow $TFgr.dataWin,hide=TFgr.DataWinHide
				endif
				setwindow $TFgr.ctrlWin,hide=0
			else
				setwindow $dataWin,hide=0
				setwindow $ctrlWin,hide=1
			endif
			break
		case "deactivate":
			setwindow $dataWin,hide=1
//			setwindow $ctrlWin,hide=1
			break
		case "kill":
			TF_AnalysisDetach(WHS.winName)
			break
		case "killVote":
			if(TFgr.ProtectPlot)
				setwindow $WHS.winName,hide=1
				return 2
			else
				return 0
			endif
			break
	endSwitch
end

Function TF_VersionCheck(win)
	string win
	
//version check
	variable TFversion=str2num(getuserdata(win,"","TFversion"))
	string AnalysisFolder=GetUserData(win,"","TFfolder")
	if(TFversion!=kTFVersion || numtype(TFversion))
		dowindow/k $win
		TimeFrequencyInvestigation()
		if(strlen(AnalysisFolder))
			SetWindow kwTopWin userdata(TFfolder)=AnalysisFolder
			TF_AnalysisAttach(winname(0,1),AnalysisFolder)
		endif
	endif
end

Function TF_BuildControlPanel(TFgr)
	struct TF_GlobalRefs &TFgr
	
	variable np=numpnts(TFgr.dw)
	string WaveOpts
	
//***Data selection controls
	sprintf WaveOpts,"CMPLX:0,TEXT:0,INTEGER:0,DIMS:1,UNSIGNED:0,WORD:0,MAXROWS:%u,MINROWS:%u",np,np
	WaveBrowserListbox("TimeWaveSelect",TFgr.dataWin,promptText="For XY Data, Select X Wave:",Xpos=5,Ypos=205,Xsize=240,Ysize=185,WaveOpts=WaveOpts,procName="TFWBListbox",add_calculated=1,nameFilterProc="TF_WBLNameFilter")
	MakePopupIntoWaveSelectorSort(TFgr.dataWin,"TimeWaveSelect","sortKind")
	PopupMenu MiscControls pos={75,2},size={150,20},proc=TFPopup,title="Misc",help={"Miscellaneous preference settings."},mode=0,win=$TFgr.win
	PopupMenu MiscControls value=TF_MiscPopupList(winName(0,1)),win=$TFgr.win
//	Button DisplayWaveSelectors pos={360,2},size={145,20},proc=TFButton,title="Hide Wave Selection",help={"Displays or hides the wave selection panel."},win=$TFgr.win	
//	Button DuplicateTFplot pos={235,2},size={120,20},proc=TFButton,title="Duplicate TF Plot",help={"Makes a new window with identical settings and display as the current window.\r\rChange the settings in the new plot to compare different manipulations of the same data."},win=$TFgr.win
//	Checkbox ProtectTFplot pos={75,2},size={150,20},proc=TFCheckbox,title="Protect Plot",variable=TFgr.ProtectPlot,help={"When checked, the current plot is protected from accidental deletion.\r\rThe wave selection panel is permanently hidden, \"closing\" the window will instead hide it, and the analysis folder will not be deleted."},win=$TFgr.win
//	CheckBox LiveUpdate pos={150,2},size={150,20},proc=TFCheckBox,title="Auto Calculate",variable=TFgr.LiveUpdate,help={"When checked, the display will be updated whenever control values are altered.\r\rFor large data series, the resulting time delay may be irritating."},win=$TFgr.win
	
	//***unhide tabbed control panel
	SetWindow $TFgr.ctrlWin,hide=0
	TabControl TFPlotTabs,pos={0,0},size={700,150},win=$TFgr.ctrlWin
	MakeTabDynamic(TFgr.ctrlWin,"TFPlotTabs")		//build tabbed control panel
end

Function/t TF_MiscPopupList(win)
	string win
	
	struct TF_GlobalRefs TFgr
	TF_MakeRefs(TFgr,win)
	
	string valStr=""

	if(TFgr.protectPlot)
		valStr=addListItem("\\M1(Show Wave Selection",valStr,";",inf)
	elseif(TFgr.dataWinHide)
		valStr=addListItem("\\M1Show Wave Selection",valStr,";",inf)
	else
		valStr=addListItem("\\M1Hide Wave Selection",valStr,";",inf)
	endif
	valStr=addListItem("\\M1Protect Plot"+selectString(TFgr.ProtectPlot,"","!"+num2char(18)),valStr,";",inf)
	valStr=addListItem("\\M1Auto Calculate"+selectString(TFgr.LiveUpdate,"","!"+num2char(18)),valStr,";",inf)
	valStr=addListItem("\\M1Duplicate TF Plot",valStr,";",inf)
	
	return valStr
end

//Function TFPlotTabsAddTab_Preprocessing(windowName)
	string windowName
	
	struct TF_GlobalRefs &TFgr
	TF_MakeRefs(TFgr,windowName)
	
//	string cmd
////***Preprocessing controls
//	cmd=GetIndependentModuleName()+"#TFListFunctions(\"DETREND\",0)"
//	PopupMenu DetrendType pos={5,25},proc=TFPopup,title="Detrend:",value=#cmd,mode=(max(0,WhichListItem(TFgr.DetrendType,TFListFunctions("DETREND",1)))+1),win=$TFgr.ctrlWin
//	CheckBox RemoveFliers pos={5,50},size={100,20},proc=TFCheckBox,title="Remove fliers",variable=TFgr.RemoveFliers,win=$TFgr.ctrlWin
//	CheckBox RemoveOutliers pos={5,75},size={100,20},proc=TFCheckBox,title="Remove outliers",variable=TFgr.RemoveOutliers,win=$TFgr.ctrlWin
//end
//
Function TFPlotTabsAddTab_Interpolation(windowName)
	string windowName
	
	struct TF_GlobalRefs TFgr
	TF_MakeRefs(TFgr,windowName)
	
	string cmd
//***Interpolation controls
	cmd=GetIndependentModuleName()+"#TFListFunctions(\"INTERPOLATION\","+num2str(!waveexists(TFgr.xw))+")"
	PopupMenu InterpType pos={5,25},proc=TFPopup,title="Interpolation:",value=#cmd,mode=(max(0,WhichListItem(TFgr.InterpType,TFListFunctions("INTERPOLATION",!waveexists(TFgr.xw))))+1),help={"Select the method of interpolation. Interpolation may be used to smooth waveform data."},win=$TFgr.ctrlWin
	SetVariable InterpRes pos={5,50},size={150,20},limits={sigdigits(TFgr.InterpRes,1)/10,inf,sigdigits(TFgr.InterpRes,1)/10},proc=TFSetVariable,title="Interp. Resolution:",value=$(TFgr.SettingsFolder+":InterpRes"),disable=(StringMatch(TFgr.InterpType,"none")*2),win=$TFgr.ctrlWin
	SetVariable InterpRes help={"Set the resolution desired for the interpolated data. This value determines the maximum frequency that can be displayed. Default value is the wave scaling (for waveform data) or the median sampling interval (for XY data)."},win=$TFgr.ctrlWin
	SetVariable XMin pos={5,75},size={150,20},limits={-inf,inf,sigdigits(abs(TFgr.XMax-TFgr.XMin)/10,1)},proc=TFSetVariable,title="Minimum X Value:",value=$(TFgr.SettingsFolder+":XMin"),help={"Minimum and maximum X values can be altered to analyze a subset of the data. Default values are the data extremes."},win=$TFgr.ctrlWin
	SetVariable XMax pos={5,100},size={150,20},limits={-inf,inf,sigdigits(abs(TFgr.XMax-TFgr.XMin)/10,1)},proc=TFSetVariable,title="Maximum X Value:",value=$(TFgr.SettingsFolder+":XMax"),help={"Minimum and maximum X values can be altered to analyze a subset of the data. Default values are the data extremes."},win=$TFgr.ctrlWin
	Button ResetValues pos={595,50},size={100,20},proc=TFButton,title="Reset Values",help={"Click to reset default interpolation resolution and minimum and maximum X values."},win=$TFgr.ctrlWin
	if(!TFgr.LiveUpdate)
		Button DoInterpolate pos={595,75},size={100,20},proc=TFButton,title="Calculate",help={"Click to recalculate. Only visible if \"Auto Calculate\" is not selected."},win=$TFgr.ctrlWin
	endif
	TF_OptionsInterpolate(TFgr)
end

Function TFPlotTabsAddTab_Decomposition(windowName)
	string windowName
	
	struct TF_GlobalRefs TFgr
	TF_MakeRefs(TFgr,windowName)
	
	string cmd
//***TF decomposition controls
	cmd=GetIndependentModuleName()+"#TFListFunctions(\"TFDECOMPOSITION\",1)"
	PopupMenu DecompType pos={5,25},proc=TFPopup,title="Decomposition:",value=#cmd,mode=(max(0,WhichListItem(TFgr.DecompType,TFListFunctions("TFDECOMPOSITION",1)))+1),help={"Select the method of time-frequency decomposition, displayed as a false-color image."},win=$TFgr.ctrlWin
	SetVariable PeriodMin pos={5,50},size={150,20},limits={TFgr.interpRes*2,(TFgr.XMax-TFgr.XMin),sigdigits(TFgr.PeriodMin,1)/10},proc=TFSetVariable,title="Minimum Period:",value=$(TFgr.SettingsFolder+":PeriodMin"),win=$TFgr.ctrlWin
	SetVariable PeriodMin help={"Minimum period can be set to analyze a subset of the spectrum. Minimum period determines maximum frequency. Default (and minimum) value is 2*interpolation resolution."},win=$TFgr.ctrlWin
	SetVariable PeriodMax pos={5,75},size={150,20},limits={TFgr.interpRes*2,(TFgr.XMax-TFgr.XMin),sigdigits(TFgr.PeriodMax,1)/10},proc=TFSetVariable,title="Maximum Period:",value=$(TFgr.SettingsFolder+":PeriodMax"),win=$TFgr.ctrlWin
	SetVariable PeriodMax help={"Maximum period can be set to analyze a subset of the spectrum. Maximum period determines minimum frequency. Default value is (Xmax-Xmin)/4. Maximum value is (Xmax-Xmin)."},win=$TFgr.ctrlWin
//	SetVariable freqRes pos={5,100},size={150,20},limits={1,inf,0.5},proc=TFSetVariable,title="spectral resolution multiple:",value=$(TFgr.SettingsFolder+":freqRes"),win=$TFgr.ctrlWin
	if(!TFgr.LiveUpdate)
		Button DoDecompose pos={595,75},size={100,20},proc=TFButton,title="Calculate",help={"Click to recalculate. Only visible if \"Auto Calculate\" is not selected."},win=$TFgr.ctrlWin
	endif
	TF_OptionsDecomp(TFgr)
end

Function TFPlotTabsAddTab_Spectrum(windowName)
	string windowName
	
	struct TF_GlobalRefs TFgr
	TF_MakeRefs(TFgr,windowName)
	
	string cmd
//***Spectrum controls
	cmd=GetIndependentModuleName()+"#TFListFunctions(\"SPECTRUM\",1)"
	PopupMenu SpectrumType pos={5,25},proc=TFPopup,title="Spectrum",value=#cmd,mode=(max(0,WhichListItem(TFgr.SpectrumType,TFListFunctions("SPECTRUM",1)))+1),help={"Select the method of spectral estimation."},win=$TFgr.ctrlWin
	SetVariable PeriodMin pos={5,50},size={150,20},limits={TFgr.interpRes*2,(TFgr.XMax-TFgr.XMin),sigdigits(TFgr.PeriodMin,1)/10},proc=TFSetVariable,title="Minimum Period:",value=$(TFgr.SettingsFolder+":PeriodMin"),win=$TFgr.ctrlWin
	SetVariable PeriodMin help={"Minimum period can be set to analyze a subset of the spectrum. Minimum period determines maximum frequency. Default (and minimum) value is 2*interpolation resolution."},win=$TFgr.ctrlWin
	SetVariable PeriodMax pos={5,75},size={150,20},limits={TFgr.interpRes*2,(TFgr.XMax-TFgr.XMin),sigdigits(TFgr.PeriodMax,1)/10},proc=TFSetVariable,title="Maximum Period:",value=$(TFgr.SettingsFolder+":PeriodMax"),win=$TFgr.ctrlWin
	SetVariable PeriodMax help={"Maximum period can be set to analyze a subset of the spectrum. Maximum period determines minimum frequency. Default value is (Xmax-Xmin)/4. Maximum value is (Xmax-Xmin)."},win=$TFgr.ctrlWin
	SetVariable freqRes pos={5,100},size={150,20},limits={1,inf,0.5},proc=TFSetVariable,title="0 pad (Multiple of N):",value=$(TFgr.SettingsFolder+":freqRes"),help={"The data series can be padded to a longer length, which can result in a smoother appearance. The apparent smoothness is deceptive."},win=$TFgr.ctrlWin
	if(!TFgr.LiveUpdate)
		Button DoSpectrum pos={595,75},size={100,20},proc=TFButton,title="Calculate",help={"Click to recalculate. Only visible if \"Auto Calculate\" is not selected."},win=$TFgr.ctrlWin
	endif
	TF_OptionsSpectrum(TFgr)
end

Function TFPlotTabsAddTab_NoiseModel(windowName)
	string windowName
	
	struct TF_GlobalRefs TFgr
	TF_MakeRefs(TFgr,windowName)
	
	string cmd
//***Background
	cmd=GetIndependentModuleName()+"#TFListFunctions(\"TFBACKGROUND\",1)"
	PopupMenu BackgroundType pos={5,25},proc=TFPopup,title="Noise Model",value=#cmd,mode=(max(0,WhichListItem(TFgr.BackgroundType,TFListFunctions("TFBACKGROUND",1)))+1),help={"Select the background noise model."},win=$TFgr.ctrlWin
	SetVariable PeriodMin pos={5,50},size={150,20},limits={TFgr.interpRes*2,(TFgr.XMax-TFgr.XMin),sigdigits(TFgr.PeriodMin,1)/10},proc=TFSetVariable,title="Minimum Period:",value=$(TFgr.SettingsFolder+":PeriodMin"),win=$TFgr.ctrlWin
	SetVariable PeriodMin help={"Minimum period can be set to analyze a subset of the spectrum. Minimum period determines maximum frequency. Default (and minimum) value is 2*interpolation resolution."},win=$TFgr.ctrlWin
	SetVariable PeriodMax pos={5,75},size={150,20},limits={TFgr.interpRes*2,(TFgr.XMax-TFgr.XMin),sigdigits(TFgr.PeriodMax,1)/10},proc=TFSetVariable,title="Maximum Period:",value=$(TFgr.SettingsFolder+":PeriodMax"),win=$TFgr.ctrlWin
	SetVariable PeriodMax help={"Maximum period can be set to analyze a subset of the spectrum. Maximum period determines minimum frequency. Default value is (Xmax-Xmin)/4. Maximum value is (Xmax-Xmin)."},win=$TFgr.ctrlWin
	SetVariable SigLevel pos={5,100},size={150,20},limits={0,100,5},proc=TFSetVariable,title="Significance Level:",value=$(TFgr.SettingsFolder+":SigLevel"),help={"Choose the significance level for the background noise spectrum expectation."},win=$TFgr.ctrlWin
	if(!TFgr.LiveUpdate)
		Button DoSpectrum pos={595,75},size={100,20},proc=TFButton,title="Calculate",help={"Click to recalculate. Only visible if \"Auto Calculate\" is not selected."},win=$TFgr.ctrlWin
	endif
	TF_OptionsBackground(TFgr)
end

Function TFPlotTabsAddTab_Appearance(windowName)
	string windowName
	
	struct TF_GlobalRefs TFgr
	TF_MakeRefs(TFgr,windowName)
	
	string cmd,helpStr
//***Appearance controls
	cmd=GetIndependentModuleName()+"#PopupVals(\"Norms\")"
	helpStr="Select the amplitude normalization for color scaling of the time-frequency decomposition and scaling of the spectral estimate./r/rMagnitude is analogous to standard deviation; Magnitude squared is analogous to variance; Sinusoidal peak amplitude is equivalent to maximum value in a sine wave; Background normalized normalizes the spectrum to the noise model spectrum expectation."
	PopupMenu Norms pos={5,25},size={200,20},proc=TFPopup,title="Amplitude Normalization:",value=#cmd,mode=(max(0,WhichListItem(TFgr.Norms,PopupVals("Norms")))+1),help={helpStr},win=$TFgr.ctrlWin
	cmd=GetIndependentModuleName()+"#PopupVals(\"AmpAxis\")"
	helpStr="Changes the scaling of the amplitude axis for the spectral estimate plot."
	PopupMenu AmpAxis pos={5,50},size={200,20},proc=TFPopup,title="Spectrum Amplitude Axis:",value=#cmd,mode=(max(0,WhichListItem(TFgr.AmpAxis,PopupVals("AmpAxis")))+1),help={helpStr},win=$TFgr.ctrlWin
	cmd=GetIndependentModuleName()+"#PopupVals(\"VertAxis\")"
	helpStr="Changes the scaling of the wavelength/frequency axes. Selecting linear period or linear frequency will result in a reciprocal scaling of the opposite axis; Log scaling applies to both axes."
	PopupMenu VertAxis pos={5,75},size={200,20},proc=TFPopup,title="Period/Frequency Axes:",value=#cmd,mode=(max(0,WhichListItem(TFgr.VertAxis,PopupVals("VertAxis")))+1),help={helpStr},win=$TFgr.ctrlWin
	SetVariable ReciprocalTicks pos={5,100},size={180,20},limits={1,inf,1},proc=TFSetVariable,title="Approximate Number of Ticks:",value=$(TFgr.SettingsFolder+":NTicks"),win=$TFgr.ctrlWin
	helpStr="Choose the color scale for false-color display of the time-frequency decomposition."
	PopupMenu CTabMode pos={275,25},size={200,20},proc=TFPopup,title="Color Table",value="*COLORTABLEPOP*",mode=(whichlistitem(TFgr.CTabMode,CTabList())+1),help={helpStr},win=$TFgr.ctrlWin
	helpStr="The color scale can be skewed to better display subtle differences at high or low amplitudes. A value of 0 produces a linear color scale. Positive (negative) values skew to better show differences at high (low) amplitudes."
	SetVariable CTabTau pos={275,50},size={150,20},limits={-inf,inf,1},proc=TFSetVariable,title="Color Table Nonlinearity:",value=$(TFgr.SettingsFolder+":CTabTau"),help={helpStr},win=$TFgr.ctrlWin
	helpStr="Change the minimum value of the color scale to better display variations at higher amplitudes. Entering \"NaN\" will reset to the minimum value of the spectral estimate amplitude axis."
	SetVariable CTabMin pos={275,75},size={150,20},limits={0,inf,sigdigits(abs(TFgr.CTabMax-TFgr.CTabMin),1)/10},proc=TFSetVariable,title="Minimum Color:",format="%3.3G",value=$(TFgr.SettingsFolder+":CTabMin"),help={helpStr},win=$TFgr.ctrlWin
	helpStr="Change the maximum value of the color scale to better display variations at higher amplitudes. Entering \"NaN\" will reset to the maximum value of the spectral estimate amplitude axis."
	SetVariable CTabMax pos={275,100},size={150,20},limits={0,inf,sigdigits(abs(TFgr.CTabMax-TFgr.CTabMin),1)/10},proc=TFSetVariable,title="Maximum Color:",format="%3.3G",value=$(TFgr.SettingsFolder+":CTabMax"),help={helpStr},win=$TFgr.ctrlWin
	cmd=GetIndependentModuleName()+"#PopupVals(\"SwapXY\")"
	helpStr="Exchanges the vertical and horizontal axes. The plot can be oriented with the data series plotted horizontally at the top and the spectral estimate plotted vertically to the right, or with the spectral estimate plotted horizontally at the top and the data series plotted vertically to the right."
	PopupMenu SwapXY pos={540,75},proc=TFPopup,title="",value=#cmd,mode=(max(0,WhichListItem(TFgr.SwapXY,PopupVals("SwapXY")))+1),help={helpStr},win=$TFgr.ctrlWin	
//	helpStr="Duplicates the plot into a new graph window that is detached from the control panel. The duplicated plot can be altered for presentation, and the displayed waves are copied into a separate folder."
//	Button CopyPlot pos={550,125},size={120,20},proc=TFButton,title="Make Plot Copy",help={helpStr},win=$TFgr.ctrlWin
end

Function TFCheckBox(CBS) : CheckBoxControl
	struct WMCheckboxAction &CBS
	
	if(itemsinlist(GetRTStackInfo(3))>1)
		return -1
	endif
	
	if(CBS.eventCode==2)		
		struct TF_GlobalRefs TFgr
		TF_MakeRefs(TFgr,CBS.win)
		
		StrSwitch(CBs.CtrlName)
//			case "RemoveFliers":
//			case "RemoveOutliers":
//				if(TFgr.RemoveFliers || TFgr.RemoveOutliers)
//					SetVariable RemoveSD bodywidth=60,size={150,20},pos={420,50},limits={0,10,0.1},proc=TFSetVariable,title="cutoff (sigma):",value=$(TFgr.SettingsFolder+":RemoveSD"),win=$CBS.win
//					SetVariable RemoveRG bodywidth=60,size={150,20},pos={420,75},limits={0,inf,0.1},proc=TFSetVariable,title="range:",value=$(TFgr.SettingsFolder+":RemoveRG"),win=$CBS.win
//				else
//					KillControl/w=$CBS.win RemoveSD
//					KillControl/w=$CBS.win RemoveRG
//				endif
//				break
		endSwitch

		TF_LiveUpdate(TFgr)
		RedrawDynamicTab(TFgr.ctrlWin,"TFPlotTabs")
	endif
end

Function TFSetVariable(SVs) : SetVariableControl
	STRUCT WMSetVariableAction &SVs
	
	if(itemsinlist(GetRTStackInfo(3))>1)
		return -1
	endif
	
	if(SVS.eventcode==2 || SVS.eventcode==1)		
		struct TF_GlobalRefs TFgr
		TF_MakeRefs(TFgr,SVS.win)
		
		variable UpdateAll
		
		StrSwitch(SVs.CtrlName)
			case "InterpRes":
				TFgr.PeriodMin=SVS.dval*2					//adjust sampling interval in interpolated data
				SetVariable InterpRes limits={sigdigits(TFgr.InterpRes,1)/10,inf,sigdigits(TFgr.InterpRes,1)/10},win=$SVS.win
				break
			case "PeriodMin":
			case "PeriodMax":
				SetVariable PeriodMin limits={TFgr.interpRes*2,(TFgr.XMax-TFgr.Xmin),sigdigits(TFgr.PeriodMin,1)/10},win=$SVS.win
				SetVariable PeriodMax limits={TFgr.interpRes*2,(TFgr.XMax-TFgr.Xmin),sigdigits(TFgr.PeriodMax,1)/10},win=$SVS.win
				UpdateAll=1
				break
			case "freqRes":
			case "Xmin":
			case "Xmax":
				SetVariable XMin limits={-inf,inf,sigdigits(abs(TFgr.XMax-TFgr.XMin)/10,1)},win=$TFgr.ctrlWin
				SetVariable XMax limits={-inf,inf,sigdigits(abs(TFgr.XMax-TFgr.XMin)/10,1)},win=$TFgr.ctrlWin
				break
			case "InterpSV1":
			case "InterpSV2":
			case "InterpSV3":
				break
			case "TFDecompSV1":
			case "TFDecompSV2":
			case "TFDecompSV3":
				break
			case "SpectrumSV1":
			case "SpectrumSV2":
			case "SpectrumSV3":
				break
			case "SigLevel":
				break
			case "CTabTau":
				TF_LogColorTable(TFgr)			//adjusts nonlinearity of color table
				break
			case "CTabMax":
			case "CTabMin":
				TF_PlotColorScale(TFgr.win,TFgr)
				break
			case "ReciprocalTicks":
				Modifygraph/W=$TFgr.win nticks(Amplitude)=2,nticks(data)=2,nticks(position)=TFgr.nTicks
				TF_PlotReciprocalAxes(TFgr.win,TFgr)
				break
		EndSwitch
		TF_LiveUpdate(TFgr,all=UpdateAll)
		RedrawDynamicTab(TFgr.ctrlWin,"TFPlotTabs")
	endif
End

Function TF_LogColorTable(TFgr)
	struct TF_GlobalRefs &TFgr
	
	variable n=100
	make/o/n=(n) $(TFgr.TFfolder+":CTabMod")
	wave TFgr.CTabMod=$(TFgr.TFfolder+":CTabMod")
	
	TFgr.CTabMod[]=(abs(TFgr.CTabTau)+1.00001)^(p/n)-1
	TFgr.CTabMod[]/=TFgr.CTabMod[n-1]
	if(TFgr.CTabTau<0)
		TFgr.CTabMod=-(TFgr.CTabMod)+1
		reverse/P TFgr.CTabMod
	endif
end

Function TFWBListbox(SelectedItem,EventCode,win,ControlName)
	string SelectedItem,win,ControlName
	variable EventCode
	
	if(itemsinlist(GetRTStackInfo(3))>3)
		return -1
	endif
	
	variable i
	for(i=0;i<1000000;i+=1)		//This helps with the wierd auto-scrolling of the listbox
	endfor
	
	if(EventCode==WMWS_SelectionChanged)

		struct TF_GlobalRefs TFgr
		TF_MakeRefs(TFgr,win)
		
		strSwitch(ControlName)
			case "DataWaveSelect":
				if(SVAR_exists(TFgr.dwPath))
					if(stringmatch(selectedItem,TFgr.dwPath))
						break
					endif
				endif
				TF_LoadSettings(TFgr,selectedItem,win)
				break
			case "TimeWaveSelect":
				if(!waveexists($selectedItem))
					selectedItem=""
				endif
				if(SVAR_exists(TFgr.xwPath))
					if(stringmatch(selectedItem,TFgr.xwPath))
						break
					endif
				endif
				wave/z TFgr.xw=$selectedItem
				if(waveexists(TFgr.xw))
					TFgr.xwPath=getWavesDataFolder(TFgr.xw,2)
				else
					TFgr.xwPath=""
				endif
				TF_MakeRefs(TFgr,TFgr.win)
				TF_SetParameterDefaults(TFgr,new=1)
				TF_LiveUpdate(TFgr)
				TF_PlotUpdate(TFgr.win)
				break
		endSwitch
	endif
end

Function TFPopup(PUs)
	struct WMPopupAction &PUs
	
	if(itemsinlist(GetRTStackInfo(3))>1)
		return -1
	endif
	
	if(PUs.eventCode==2)
		struct TF_GlobalRefs TFgr
		TF_MakeRefs(TFgr,PUs.win)
	
		StrSwitch(PUs.ctrlName)
			case "MiscControls":
				StrSwitch(PUs.popStr)
					case "Hide Wave Selection":
					case "Show Wave Selection":
						TFgr.dataWinHide=stringMatch(PUs.popStr,"Hide Wave Selection")
						setwindow $TFgr.dataWin,hide=TFgr.dataWinHide				
						break
					case "Duplicate TF plot":
						string dfSave=getDataFolder(1)
						SetDataFolder $ksWorkFolder
						string dupFolder=UniqueName(ksWorkFolderPrefix,11,0)
						duplicateDataFolder $TFgr.TFfolder,$dupFolder
						SetDataFolder $dfSave
						TimeFrequencyInvestigation()
						SetWindow kwTopWin userdata(TFfolder)=dupFolder
						TF_AnalysisAttach(winname(0,1),dupFolder)
						break
					case "Protect Plot":
						TFgr.ProtectPlot=!TFgr.ProtectPlot
						if(TFgr.ProtectPlot)
							setwindow $TFgr.dataWin,hide=1
							TFgr.DataWinHide=1		
						endif
						break
					case "Auto Calculate":
						TFgr.LiveUpdate=!TFgr.LiveUpdate
						RedrawDynamicTab(TFgr.ctrlWin,"TFPlotTabs")
						break
				endSwitch
				
				break
			case "InterpType":								//change in interpolation method
				TFgr.InterpType=PUs.popStr
				SetVariable InterpRes win=$TFgr.ctrlWin,disable=(StringMatch(TFgr.InterpType,"none")*2)
				TF_OptionsInterpolate(TFgr)
				break
			case "InterpPM1":
				TFgr.InterpPM0=PUs.popStr
				break
			case "InterpPM2":
				TFgr.InterpPM1=PUs.popStr
				break
			case "InterpPM3":
				TFgr.InterpPM2=PUs.popStr
				break
			case "DecompType":									//change in time-frequency decomposition
				TFgr.DecompType=PUs.popStr
				TF_MakeRefs(TFgr,TFgr.win)
	//			TFgr.CTabMax=nan;TFgr.CTabMin=nan											//this forces a recalculation of the color table
				TF_OptionsDecomp(TFgr)
				break
			case "TFDecompPM1":
				TFgr.TFDecompPM0=PUs.popStr
				break
			case "TFDecompPM2":
				TFgr.TFDecompPM1=PUs.popStr
				break
			case "TFDecompPM3":
				TFgr.TFDecompPM2=PUs.popStr
				break
			case "SpectrumType":				//change in spectrum  - automatically recalculates spectrum
				TFgr.SpectrumType=PUs.popStr
				TF_MakeRefs(TFgr,TFgr.win)
				TF_OptionsSpectrum(TFgr)
				break
			case "SpectrumPM1":
				TFgr.SpectrumPM0=PUs.popStr
				break
			case "SpectrumPM2":
				TFgr.SpectrumPM1=PUs.popStr
				break
			case "SpectrumPM3":
				TFgr.SpectrumPM2=PUs.popStr
				break
			case "BackgroundType":				//change in spectrum  - automatically recalculates spectrum
				TFgr.BackgroundType=PUs.popStr
				TF_MakeRefs(TFgr,TFgr.win)
				TF_OptionsBackground(TFgr)
				break
			case "BackgroundPM1":
				TFgr.BackgroundPM0=PUs.popStr
				break
			case "BackgroundPM2":
				TFgr.BackgroundPM1=PUs.popStr
				break
			case "BackgroundPM3":
				TFgr.BackgroundPM2=PUs.popStr
				break
			case "VertAxis":				//change in (non)linearity of period and frequency axes
				TFgr.VertAxis=PUs.popStr
				TF_PlotReciprocalAxes(TFgr.win,TFgr)
				break
			case "AmpAxis":			//change from/to log scale for spectrum amplitude
				TFgr.AmpAxis=PUs.popStr
				ModifyGraph log(Amplitude)=whichlistitem(TFgr.AmpAxis,PopupVals("AmpAxis"))
				break
			case "CTabMode":
				TFgr.CTabMode=PUs.popStr
				TF_PlotUpdate(TFgr.win)
				break
			case "Norms":				//change in normalization of time-frequency amplitudes
				TFgr.Norms=PUs.popStr
				TFgr.CTabMax=nan;TFgr.CTabMin=nan		//force change in color table limits
				TF_PlotUpdate(TFgr.win)
				break
			case "SwapXY":
				TFgr.SwapXY=PUs.popStr
				TF_PlotRotate(TFgr.win,TFgr)
				break
		EndSwitch
		TF_LiveUpdate(TFgr)
		RedrawDynamicTab(TFgr.ctrlWin,"TFPlotTabs")
	endif
End

Function TFButton(BS) : ButtonControl
	STRUCT WMButtonAction &BS
		
	if(itemsinlist(GetRTStackInfo(3))>1)
		return -1
	endif
	
	if(BS.eventcode==2)
		struct TF_GlobalRefs TFgr
		TF_MakeRefs(TFgr,BS.win)
		
		strswitch(BS.ctrlName)
			case "DisplayHelp":		//displays help file at subtopic for current tab
				TFgr.dataWin=(BS.win+"#TFWaveSelPanel")
				TFgr.ctrlWin=(BS.win+"#TFCtrlPanel")
				string helpTopic="Using the Time Frequency plot"
				getwindow $TFgr.ctrlWin hide
				if(!v_value)
					controlInfo/W=$TFgr.ctrlWin TFPlotTabs
					helpTopic+="["+S_Value+"]"
				endif
				DisplayHelpTopic/k=1 helpTopic
				break
			case "CopyPlot":			//duplicates the current plot area of the window, so that it can be edited, compared, etc.
				TF_PlotUpdate(TFgr.win,dup=1)
				break
			case "ResetValues":		//reset parameters to defaults based on data
				TF_SetParameterDefaults(TFgr)
				TF_LiveUpdate(TFgr)
				break
			case "DoInterpolate":	//interpolate
				TF_InitiateInterpolation(TFgr)
				TF_PlotUpdate(TFgr.win)
				break
			case "DoDecompose":		//do time-frequency decomposition
				TF_InitiateDecomposition(TFgr)
				TF_PlotUpdate(TFgr.win)
				break
			case "DoSpectrum":		//do time-frequency decomposition
				TF_InitiateSpectrum(TFgr)
				TF_PlotUpdate(TFgr.win)
				break
		endSwitch
		RedrawDynamicTab(TFgr.ctrlWin,"TFPlotTabs")
	endif
End

Function TF_OptionsInterpolate(TFgr)	//adds controls specfic to spectral estimate methods
	struct TF_GlobalRefs &TFgr
	
	struct InterpolationParameters IPs
	IPs.getParams=1		//makes spectrum function return information needed to build parameter controls
	IPs.Xmin=TFgr.Xmin;IPs.Xmax=TFgr.Xmax
	IPs.interpRes=TFgr.interpRes
	
	FuncRef INTERPOLATION_prototype InterpFunc=$("INTERPOLATION_"+TFgr.InterpType)
	InterpFunc(IPs)
	string InterpSettingsFolder=TFgr.SettingsFolder+":Interpolation:"+TFgr.InterpType
	NewDataFolderPath(InterpSettingsFolder)
	variable i
	string SVpath,PMpath,ctrlName

	for(i=0;i<3;i+=1)					//loop to build setvariable controls for spectrum parameters
		SVpath=InterpSettingsFolder+":SV"+num2istr(i)
		NVAR/Z gSV=$SVpath
		ctrlName="InterpSV"+num2istr(i+1)
		if(strlen(IPs.SV.name[i]))
			if(NVAR_exists(gSV))
				IPs.SV.value[i]=gSV
			else
				variable/g $SVpath=IPs.SV.value[i]
			endif
			SetVariable $ctrlName pos={190,25+i*25},size={150,20},proc=TFSetVariable,win=$TFgr.ctrlWin
			setvariable $ctrlName limits={IPs.SV.low[i],IPs.SV.high[i],IPs.SV.inc[i]},title=IPs.SV.name[i],value=$SVpath,win=$TFgr.ctrlWin
		else
			killvariables/z gSV
			killcontrol/W=$TFgr.ctrlWin $ctrlName
		endif
	endfor
	for(i=0;i<3;i+=1)				//loop to build popup menu controls for spectrum parameters
		PMpath=InterpSettingsFolder+":PM"+num2istr(i)
		SVAR/Z gPM=$PMpath
		string/g $(PMpath+"list")
		SVAR gPMvalue=$(PMpath+"list")
		ctrlName="InterpPM"+num2istr(i+1)
		if(strlen(IPs.PM.name[i]))
			if(SVAR_exists(gPM))
				IPs.PM.popStr[i]=gPM
			else
				string/g $PMpath=IPs.PM.popStr[i]
			endif
			gPMvalue=IPs.PM.value[i]
			PopupMenu $ctrlName,pos={350,25+i*25},proc=TFPopup,title=IPs.PM.name[i],win=$TFgr.ctrlWin
			PopupMenu $ctrlName value=#(PMpath+"list"),popvalue=IPs.PM.popStr[i],mode=1,win=$TFgr.ctrlWin
		else
			killstrings/z gPM,gPMvalue
			killcontrol/W=$TFgr.ctrlWin $ctrlName
		endif
	endfor
end

Function TF_InitiateInterpolation(TFgr)		//interpolate data using user-selected method
	struct TF_GlobalRefs &TFgr
		
	struct InterpolationParameters IPs
	IPs.getParams=0					//setting to calculate spectrum
	FuncRef INTERPOLATION_prototype InterpFunc=$("INTERPOLATION_"+TFgr.InterpType)
	string InterpSettingsFolder=TFgr.SettingsFolder+":Interpolation:"+TFgr.InterpType
	NewDataFolderPath(InterpSettingsFolder)
	variable i
	string SVpath,PMpath,ctrlName

	for(i=0;i<3;i+=1)		//loop to get values of setvariable parameters
		SVpath=InterpSettingsFolder+":SV"+num2istr(i)
		NVAR/Z gSV=$SVpath
		if(NVAR_exists(gSV))
			IPs.SV.value[i]=gSV
		else
			IPs.SV.value[i]=nan
		endif
	endfor
	for(i=0;i<3;i+=1)		//loop to get values of popup menu parameters
		PMpath=InterpSettingsFolder+":PM"+num2istr(i)
		SVAR/Z gPM=$PMpath
		SVAR/Z gPMvalue=$(PMpath+"list")
		if(SVAR_exists(gPM))
			IPs.PM.popStr[i]=gPM
			IPs.PM.popNum[i]=whichlistitem(gPM,gPMvalue)+1
		else
			IPs.PM.popStr[i]=""
			IPs.PM.popNum[i]=nan
		endif
	endfor
	
//(re)create interpolated data wave
	string IntName=TFgr.TFfolder+":IntData"
	make/o/d $IntName;wave TFgr.dw_int=$IntName

//the following code duplicates the original data and x waves to avoid altering them during pre-processing and interpolation
	string ProcName=TFgr.SettingsFolder+":ProcData"
	string ProcXName=TFgr.SettingsFolder+":ProcX"
	variable np,maxpt,minpt
	duplicate/o TFgr.dw,$ProcName
	wave dw=$ProcName
	if(waveexists(TFgr.xw))			//if there is an x-value wave; references the plotted xw in case the data is being tuned
		duplicate/o TFgr.xw,$ProcXName
		wave xw=$ProcXName
	else
		duplicate/o TFgr.dw,$ProcXName	//creates dummy x-value wave with values set to x-scaling of dw
		wave xw=$ProcXName
		xw=x
	endif
//removes nan in both xw and dw
	sort dw,xw,dw
	wavestats/q/m=0 dw
	redimension/n=(v_npnts) xw,dw
	sort xw,xw,dw					//put in x-value order
	wavestats/q/m=0 xw
	redimension/n=(v_npnts) xw,dw

//guard against insane values
	if(TFgr.Xmax<=TFgr.Xmin)
		TFgr.Xmin=xw[0]
		TFgr.Xmax=xw[numpnts(xw)-1]
	endif
	
//truncate data to user-selected range
	minpt=max(0,binarysearch(xw,TFgr.Xmin));maxpt=min(numpnts(dw)-1,binarysearch(xw,TFgr.Xmax))		//locate user-selected end-points
	if(maxpt<=0)
		maxpt=numpnts(dw)-1
	endif
	redimension/n=(maxpt+1) xw,dw
	deletepoints 0,minpt,xw,dw
	
//set xmin and xmax to values closest to user selected values	
	TFgr.Xmin=xw[0]
	TFgr.Xmax=xw[numpnts(xw)-1]
	
//set scaling for interpolated data wave
	np=trunc(abs((TFgr.Xmax-TFgr.Xmin)/(TFgr.InterpRes))+1)		//calculate number of points in interpolated wave
	np-=mod(np,2)													//make sure it's a multiple of 2, otherwise FFT fails
	redimension/n=(np) TFgr.dw_int
	setscale/p x TFgr.Xmin,TFgr.InterpRes,TFgr.dw_int
	
	IPs.Xmin=TFgr.Xmin;IPs.Xmax=TFgr.Xmax
	IPs.interpRes=TFgr.interpRes
	
	wave IPs.dw_int=$getwavesdatafolder(TFgr.dw_int,2)
	wave IPs.dw=$getwavesdatafolder(dw,2)
	wave IPs.xw=$getwavesdatafolder(xw,2)
	
	if(cmpstr(TFgr.InterpType,"none"))
		InterpFunc(IPs)		//calls spectrum calculation wrapper function
	else
		duplicate/o/r=(TFgr.xmin,TFgr.xmax) TFgr.dw,TFgr.dw_int
	endif
	
	ReplaceNaN(TFgr.dw_int,0,1)	//interpolated waves may have NaNs where there are not enough data points - this inserts flat intervals (spectrally relatively neutral) for NaNs
	killwaves/z xw,dw
end

Function TF_OptionsDecomp(TFgr)	//adds controls specfic to spectral estimate methods
	struct TF_GlobalRefs &TFgr
	
	struct TFDecompParameters TFPs
	TFPs.getParams=1		//makes spectrum function return information needed to build parameter controls
	FuncRef TFDECOMPOSITION_prototype DecompFunc=$("TFDECOMPOSITION_"+TFgr.DecompType)
	DecompFunc(TFPs)
	string DecompSettingsFolder=TFgr.SettingsFolder+":TFDecomposition:"+TFgr.DecompType
	NewDataFolderPath(DecompSettingsFolder)
	variable i
	string SVpath,PMpath,ctrlName

	for(i=0;i<3;i+=1)					//loop to build setvariable controls for spectrum parameters
		SVpath=DecompSettingsFolder+":SV"+num2istr(i)
		NVAR/Z gSV=$SVpath
		ctrlName="TFDecompSV"+num2istr(i+1)
		if(strlen(TFPs.SV.name[i]))
			if(NVAR_exists(gSV))
				TFPs.SV.value[i]=gSV
			else
				variable/g $SVpath=TFPs.SV.value[i]
			endif
			SetVariable $ctrlName pos={190,25+i*25},size={150,20},proc=TFSetVariable,win=$TFgr.ctrlWin
			setvariable $ctrlName limits={TFPs.SV.low[i],TFPs.SV.high[i],TFPs.SV.inc[i]},title=TFPs.SV.name[i],value=$SVpath,win=$TFgr.ctrlWin
		else
			killvariables/z gSV
			killcontrol/W=$TFgr.ctrlWin $ctrlName
		endif
	endfor
	for(i=0;i<3;i+=1)				//loop to build popup menu controls for spectrum parameters
		PMpath=DecompSettingsFolder+":PM"+num2istr(i)
		SVAR/Z gPM=$PMpath
		string/g $(PMpath+"list")
		SVAR gPMvalue=$(PMpath+"list")
		ctrlName="TFDecompPM"+num2istr(i+1)
		if(strlen(TFPs.PM.name[i]))
			if(SVAR_exists(gPM))
				TFPs.PM.popStr[i]=gPM
			else
				string/g $PMpath=TFPs.PM.popStr[i]
			endif
			gPMvalue=TFPs.PM.value[i]
			PopupMenu $ctrlName,pos={350,25+i*25},proc=TFPopup,title=TFPs.PM.name[i],win=$TFgr.ctrlWin
			PopupMenu $ctrlName value=#(PMpath+"list"),popvalue=TFPs.PM.popStr[i],mode=1,win=$TFgr.ctrlWin
		else
			killstrings/z gPM,gPMvalue
			killcontrol/W=$TFgr.ctrlWin $ctrlName
		endif
	endfor
end

Function TF_InitiateDecomposition(TFgr)	//calculate time-frequency spectrum
	struct TF_GlobalRefs &TFgr
	
	if(cmpstr(TFgr.DecompType,"none"))
		variable MemSize
	
	//	TFgr.CTabMax=nan;TFgr.CTabMin=nan	//forces recalculation of color table

		struct TFDecompParameters TFPs
		TFPs.getParams=0		//makes decomposition function do the calculation
		FuncRef TFDECOMPOSITION_prototype DecompFunc=$("TFDECOMPOSITION_"+TFgr.DecompType)
	
		string DecompSettingsFolder=TFgr.SettingsFolder+":TFDecomposition:"+TFgr.DecompType
		NewDataFolderPath(DecompSettingsFolder)
		variable i
		string SVpath,PMpath,ctrlName
	
		for(i=0;i<3;i+=1)					//loop to build setvariable controls for spectrum parameters
			SVpath=DecompSettingsFolder+":SV"+num2istr(i)
			NVAR/Z gSV=$SVpath
			if(NVAR_exists(gSV))
				TFPs.SV.value[i]=gSV
			else
				TFPs.SV.value[i]=nan
			endif
		endfor
		for(i=0;i<3;i+=1)				//loop to build popup menu controls for spectrum parameters
			PMpath=DecompSettingsFolder+":PM"+num2istr(i)
			SVAR/Z gPM=$PMpath
			SVAR/Z gPMvalue=$(PMpath+"list")
			if(SVAR_exists(gPM))
				TFPs.PM.popStr[i]=gPM
				TFPs.PM.popNum[i]=whichlistitem(gPM,gPMvalue)+1
			else
				TFPs.PM.popStr[i]=""
				TFPs.PM.popNum[i]=nan
			endif
		endfor
	
		TFPs.Xmin=TFgr.Xmin;TFPs.Xmax=TFgr.Xmax
		TFPs.Fmin=1/TFgr.PeriodMax;TFPs.Fmax=1/TFgr.PeriodMin
		TFPs.freqRes=1/TFgr.freqRes/(TFgr.Xmax-TFgr.Xmin)
		if(waveexists(TFgr.xw))
			wave TFPs.dw=$getwavesdatafolder(TFgr.dw,2);wave TFPs.xw=$getwavesdatafolder(TFgr.xw,2)
		endif
		wave TFPs.dw_int=$getwavesdatafolder(TFgr.dw_int,2)
	
	//make result waves
		NewDataFolderPath(TFgr.TFDecompFolder)
		make/o $(TFgr.TFDecompFolder+":magnitude"),$(TFgr.TFDecompFolder+":COI")
		make/o $(TFgr.TFDecompFolder+":Frequency"),$(TFgr.TFDecompFolder+":scale")
		TF_MakeRefs(TFgr,TFgr.win)
		wave/z TFPs.magnitude=$(TFgr.TFDecompFolder+":magnitude"),TFPs.coi=$(TFgr.TFDecompFolder+":COI")
		wave/z TFPs.frequency=$(TFgr.TFDecompFolder+":Frequency")
		wave/z TFPs.scale=$(TFgr.TFDecompFolder+":scale")
		
		DecompFunc(TFPs)	//decomposition
	
		TF_Sum(TFgr)		//calculate global spectrum
	endif
end

Function TF_OptionsSpectrum(TFgr)	//adds controls specfic to spectral estimate methods
	struct TF_GlobalRefs &TFgr
	
	struct SpectrumParameters SPs
	SPs.getParams=1		//makes spectrum function return information needed to build parameter controls
	FuncRef SPECTRUM_prototype SpectrumFunc=$("SPECTRUM_"+TFgr.SpectrumType)
	SpectrumFunc(SPs)
	string SpecSettingsFolder=TFgr.SettingsFolder+":Spectrum:"+TFgr.SpectrumType
	NewDataFolderPath(SpecSettingsFolder)
	variable i
	string SVpath,PMpath,ctrlName

	for(i=0;i<3;i+=1)					//loop to build setvariable controls for spectrum parameters
		SVpath=SpecSettingsFolder+":SV"+num2istr(i)
		NVAR/Z gSV=$SVpath
		ctrlName="SpectrumSV"+num2istr(i+1)
		if(strlen(SPs.SV.name[i]))
			if(NVAR_exists(gSV))
				SPs.SV.value[i]=gSV
			else
				variable/g $SVpath=SPs.SV.value[i]
			endif
			SetVariable $ctrlName pos={190,25+i*25},size={150,20},proc=TFSetVariable,win=$TFgr.ctrlWin
			setvariable $ctrlName limits={SPs.SV.low[i],SPs.SV.high[i],SPs.SV.inc[i]},title=SPs.SV.name[i],value=$SVpath,win=$TFgr.ctrlWin
		else
			killvariables/z gSV
			killcontrol/W=$TFgr.ctrlWin $ctrlName
		endif
	endfor
	for(i=0;i<3;i+=1)				//loop to build popup menu controls for spectrum parameters
		PMpath=SpecSettingsFolder+":PM"+num2istr(i)
		SVAR/Z gPM=$PMpath
		string/g $(PMpath+"list")
		SVAR gPMvalue=$(PMpath+"list")
		ctrlName="SpectrumPM"+num2istr(i+1)
		if(strlen(SPs.PM.name[i]))
			if(SVAR_exists(gPM))
				SPs.PM.popStr[i]=gPM
			else
				string/g $PMpath=SPs.PM.popStr[i]
			endif
			gPMvalue=SPs.PM.value[i]
			PopupMenu $ctrlName,pos={350,25+i*25},proc=TFPopup,title=SPs.PM.name[i],win=$TFgr.ctrlWin
			PopupMenu $ctrlName value=#(PMpath+"list"),popvalue=SPs.PM.popStr[i],mode=1,win=$TFgr.ctrlWin
		else
			killstrings/z gPM,gPMvalue
			killcontrol/W=$TFgr.ctrlWin $ctrlName
		endif
	endfor
end

Function TF_InitiateSpectrum(TFgr)		//calculates spectrum
	struct TF_GlobalRefs &TFgr
	
	if(cmpstr(TFgr.SpectrumType,"none"))
		struct SpectrumParameters SPs
		SPs.getParams=0					//setting to calculate spectrum
		FuncRef SPECTRUM_prototype SpectrumFunc=$("SPECTRUM_"+TFgr.SpectrumType)
		string SpecSettingsFolder=TFgr.SettingsFolder+":Spectrum:"+TFgr.SpectrumType
		NewDataFolderPath(SpecSettingsFolder)
		variable i
		string SVpath,PMpath,ctrlName
	
		for(i=0;i<3;i+=1)		//loop to get values of setvariable parameters
			SVpath=SpecSettingsFolder+":SV"+num2istr(i)
			NVAR/Z gSV=$SVpath
			if(NVAR_exists(gSV))
				SPs.SV.value[i]=gSV
			else
				SPs.SV.value[i]=nan
			endif
		endfor
		for(i=0;i<3;i+=1)		//loop to get values of popup menu parameters
			PMpath=SpecSettingsFolder+":PM"+num2istr(i)
			SVAR/Z gPM=$PMpath
			SVAR/Z gPMvalue=$(PMpath+"list")
			if(SVAR_exists(gPM))
				SPs.PM.popStr[i]=gPM
				SPs.PM.popNum[i]=whichlistitem(gPM,gPMvalue)+1
			else
				SPs.PM.popStr[i]=""
				SPs.PM.popNum[i]=nan
			endif
		endfor
		
		SPs.Xmin=TFgr.Xmin;SPs.Xmax=TFgr.Xmax
		SPs.Fmin=1/TFgr.PeriodMax;SPs.Fmax=1/TFgr.PeriodMin
		SPS.freqRes=1/TFgr.freqRes/(TFgr.Xmax-TFgr.Xmin)
		if(waveexists(TFgr.xw))
			wave SPs.xw=$getwavesdatafolder(TFgr.xw,2)
		endif
		wave SPs.dw=$getwavesdatafolder(TFgr.dw,2)
		wave SPs.dw_int=$getwavesdatafolder(TFgr.dw_int,2)
		NewDataFolderPath(TFgr.SpectrumFolder)											//Create spectrum subfolder, if it doesn't exist
		make/o $(TFgr.SpectrumFolder+":Amplitude")
		wave SPs.magnitude=$(TFgr.SpectrumFolder+":Amplitude")
		
		SpectrumFunc(SPs)		//calls spectrum calculation wrapper function
		
		duplicate/o SPs.magnitude,$(TFgr.SpectrumFolder+":Frequency")
		wave TFgr.SpectrumFrequency=$(TFgr.SpectrumFolder+":Frequency")
		TFgr.SpectrumFrequency=x
	endif
end

Function TF_OptionsBackground(TFgr)	//adds controls specfic to background noise estimates
	struct TF_GlobalRefs &TFgr
	
	struct TFBackgroundParameters BGPs
	BGPs.getParams=1		//makes background function return information needed to build parameter controls
	FuncRef TFBACKGROUND_prototype BackgroundFunc=$("TFBACKGROUND_"+TFgr.BackgroundType)
	BackgroundFunc(BGPs)
	string BGSettingsFolder=TFgr.SettingsFolder+":Background:"+TFgr.BackgroundType
	NewDataFolderPath(BGSettingsFolder)
	variable i
	string SVpath,PMpath,ctrlName

	for(i=0;i<3;i+=1)					//loop to build setvariable controls for background parameters
		SVpath=BGSettingsFolder+":SV"+num2istr(i)
		NVAR/Z gSV=$SVpath
		ctrlName="BackgroundSV"+num2istr(i+1)
		if(strlen(BGPs.SV.name[i]))
			if(NVAR_exists(gSV))
				BGPs.SV.value[i]=gSV
			else
				variable/g $SVpath=BGPs.SV.value[i]
			endif
			SetVariable $ctrlName pos={190,25+i*25},size={150,20},proc=TFSetVariable,win=$TFgr.ctrlWin
			setvariable $ctrlName limits={BGPs.SV.low[i],BGPs.SV.high[i],BGPs.SV.inc[i]},title=BGPs.SV.name[i],value=$SVpath,win=$TFgr.ctrlWin
		else
			killvariables/z gSV
			killcontrol/W=$TFgr.ctrlWin $ctrlName
		endif
	endfor
	for(i=0;i<3;i+=1)				//loop to build popup menu controls for backgroun parameters
		PMpath=BGSettingsFolder+":PM"+num2istr(i)
		SVAR/Z gPM=$PMpath
		string/g $(PMpath+"list")
		SVAR gPMvalue=$(PMpath+"list")
		ctrlName="BackgroundPM"+num2istr(i+1)
		if(strlen(BGPs.PM.name[i]))
			if(SVAR_exists(gPM))
				BGPs.PM.popStr[i]=gPM
			else
				string/g $PMpath=BGPs.PM.popStr[i]
			endif
			gPMvalue=BGPs.PM.value[i]
			PopupMenu $ctrlName,pos={350,25+i*25},proc=TFPopup,title=BGPs.PM.name[i],win=$TFgr.ctrlWin
			PopupMenu $ctrlName value=#(PMpath+"list"),popvalue=BGPs.PM.popStr[i],mode=1,win=$TFgr.ctrlWin
		else
			killstrings/z gPM,gPMvalue
			killcontrol/W=$TFgr.ctrlWin $ctrlName
		endif
	endfor
end

Function TF_InitiateBackground(TFgr)		//calculates background noise estimate
	struct TF_GlobalRefs &TFgr
	
	if(cmpstr(TFgr.BackgroundType,"none"))
		struct TFBackgroundParameters BGPs
		BGPs.getParams=0					//setting to calculate background spectrum
		FuncRef TFBACKGROUND_prototype BackgroundFunc=$("TFBACKGROUND_"+TFgr.BackgroundType)
		string BGSettingsFolder=TFgr.SettingsFolder+":Background:"+TFgr.BackgroundType
		NewDataFolderPath(BGSettingsFolder)
		variable i
		string SVpath,PMpath,ctrlName
	
		for(i=0;i<3;i+=1)		//loop to get values of setvariable parameters
			SVpath=BGSettingsFolder+":SV"+num2istr(i)
			NVAR/Z gSV=$SVpath
			if(NVAR_exists(gSV))
				BGPs.SV.value[i]=gSV
			else
				BGPs.SV.value[i]=nan
			endif
		endfor
		for(i=0;i<3;i+=1)		//loop to get values of popup menu parameters
			PMpath=BGSettingsFolder+":PM"+num2istr(i)
			SVAR/Z gPM=$PMpath
			SVAR/Z gPMvalue=$(PMpath+"list")
			if(SVAR_exists(gPM))
				BGPs.PM.popStr[i]=gPM
				BGPs.PM.popNum[i]=whichlistitem(gPM,gPMvalue)+1
			else
				BGPs.PM.popStr[i]=""
				BGPs.PM.popNum[i]=nan
			endif
		endfor
		
		BGPs.Fmin=1/TFgr.PeriodMax;BGPs.Fmax=1/TFgr.PeriodMin
		BGPs.freqRes=1/TFgr.freqRes/(TFgr.Xmax-TFgr.Xmin)
		if(waveexists(TFgr.xw))
			wave BGPs.xw=$getwavesdatafolder(TFgr.xw,2)
		endif
		wave BGPs.dw=$getwavesdatafolder(TFgr.dw,2)
		wave BGPs.dw_int=$getwavesdatafolder(TFgr.dw_int,2)
		NewDataFolderPath(TFgr.BackgroundFolder)											//Create Background subfolder, if it doesn't exist
		make/o $(TFgr.BackgroundFolder+":Amplitude")
		wave BGPs.magnitude=$(TFgr.BackgroundFolder+":Amplitude")
		
		BackgroundFunc(BGPs)		//calls background calculation wrapper function
		BGPs.magnitude*=sqrt(statsInvChiCDF(TFgr.sigLevel/100,2))												//spectrum should be chi2 distributed
		
		duplicate/o BGPs.magnitude,$(TFgr.BackgroundFolder+":Frequency")
		wave TFgr.BackgroundFrequency=$(TFgr.BackgroundFolder+":Frequency")
		TFgr.BackgroundFrequency=x
	endif
end

Function TF_Sum(TFgr)					//calculates spectrum by taking mean of time-frequency decomposition
	struct TF_GlobalRefs &TFgr
	variable dup		//if >0, this creates a duplicate of the current plot rather than updating
	
	variable i,npts=dimsize(TFgr.TFMag,0),ncols=dimsize(TFgr.TFMag,1)
	string name=GetWavesDataFolder(TFgr.TFMag,1)+"GlobalSpec"
	make/o/n=(ncols) $(name)
	wave TFgr.TFGlobalSpec=$(name)
	setscale/p x DimOffset(TFgr.TFMag,1),DimDelta(TFgr.TFMag,1),TFgr.TFGlobalSpec
	TFgr.TFGlobalSpec=0
	for(i=0;i<ncols;i+=1)
		ImageStats/G={0,npts-1,i,i} TFgr.TFMag
		TFgr.TFGlobalSpec[i]=V_avg
	endfor
//	TFgr.TFGlobalSpec[]=TFgr.TFMag[round(npts/2)][p]
end

Function TF_LiveUpdate(TFgr[,all])
	struct TF_GlobalRefs &TFgr
	variable all
	
	string S_value
	if(TFgr.LiveUpdate)
		if(all)
			S_value="OverrideAll"
		else
			controlInfo/W=$TFgr.ctrlWin TFPlotTabs
		endif
		strSwitch(S_value)
			case "OverrideAll":
			case "Interpolation":
				TF_InitiateInterpolation(TFgr)
				TF_InitiateDecomposition(TFgr)
				TF_InitiateSpectrum(TFgr)
				TF_InitiateBackground(TFgr)
				break
			case "Decomposition":
				TF_InitiateDecomposition(TFgr)
				break
			case "Spectrum":
				TF_InitiateSpectrum(TFgr)
				break
			case "NoiseModel":
				TF_InitiateBackground(TFgr)
				break
			default:
				return 0
		endSwitch
		TF_PlotUpdate(TFgr.win)
	endif	
end

function TF_PlotUpdate(win[,dup])
	string win
	variable dup		//if >0, this creates a duplicate of the current plot rather than updating
		
	struct TF_GlobalRefs TFgr
	TF_MakeRefs(TFgr,win)
	
	string plotN
	
	if(dup)				//if duplicating rather than updating
		plotN=uniquename(nameofwave(TFgr.dw)+"_TFplot",6,0)
		display/W=(5,164,705,764)/N=$plotN
	else
		plotN=TFgr.win
//Remove old plots:
		ClearGraph(win=plotN)
		ColorScale/N=AmpScale/K/W=$plotN
	endif
		
	Modifygraph/W=$plotN swapXY=0			//undo swap to build plot
	if(waveexists(TFgr.dw))											//if data wave has been selected, then update the plot
		if(WaveExists(TFgr.xw))	//plot dw vs xw, if one has been selected
			appendToGraph/W=$plotN/c=(0,0,0)/l=Data/b=Position TFgr.dw vs TFgr.xw
		else
			appendToGraph/W=$plotN/c=(0,0,0)/l=Data/b=Position TFgr.dw
		endif
		if(WaveExists(TFgr.dw_int) && (numpnts(TFgr.dw_int)>0))	//plot interpolated data, if it exists
			AppendToGraph/W=$plotN/l=Data/b=Position TFgr.dw_int
		endif
		setaxis/W=$plotN/A=2 Data
		setaxis/W=$plotN Position TFgr.Xmin,TFgr.Xmax

//plot spectrum
		if(!waveexists(TFgr.PlotSpectrum))
			make/o/n=1 $(TFgr.PlotFolder+":Spectrum"),$(TFgr.PlotFolder+":SpectrumX")=nan
			wave TFgr.PlotSpectrum=$(TFgr.PlotFolder+":Spectrum"),TFgr.PlotSpectrumX=$(TFgr.PlotFolder+":SpectrumX")
		endif
		AppendToGraph/W=$plotN/c=(0,0,0)/B=Amplitude/L=Period/VERT TFgr.PlotSpectrum vs TFgr.PlotSpectrumX
//plot TFdecomp
		if(!waveexists(TFgr.PlotTFdecomp))
			make/o/n=(1,1) $(TFgr.PlotFolder+":TFdecomp")=nan
			make/o/n=2 $(TFgr.PlotFolder+":TFdecompX")={1,2}
			make/o/n=1 $(TFgr.PlotFolder+":TFGlobalSpec")=nan
			wave TFgr.PlotTFdecomp=$(TFgr.PlotFolder+":TFdecomp"),TFgr.PlotTFdecompX=$(TFgr.PlotFolder+":TFdecompX")
			wave TFgr.PlotTFGlobalSpec=$(TFgr.PlotFolder+":TFGlobalSpec")
		endif
		AppendImage/W=$plotN/l=Period/b=Position TFgr.PlotTFdecomp vs {*,TFgr.PlotTFdecompX}
		AppendToGraph/W=$plotN/C=(0,0,65535)/B=Amplitude/L=Period/VERT TFgr.PlotTFGlobalSpec vs TFgr.PlotTFdecompX
//plot background
		if(!waveexists(TFgr.PlotBackground))
			make/o/n=1 $(TFgr.PlotFolder+":Background"),$(TFgr.PlotFolder+":BackgroundX")=nan
			wave TFgr.PlotBackground=$(TFgr.PlotFolder+":Background"),TFgr.PlotBackgroundX=$(TFgr.PlotFolder+":BackgroundX")
		endif
		AppendToGraph/W=$plotN/C=(65535,0,0)/B=Amplitude/L=Period/VERT TFgr.PlotBackground vs TFgr.PlotBackgroundX
//spectrum amplitude axis scaling
		if(whichListItem("Amplitude",AxisList(TFgr.win))>0)
			ModifyGraph/W=$plotN/Z log(Amplitude)=whichlistitem(TFgr.AmpAxis,PopupVals("AmpAxis"))
			Modifygraph/W=$plotN axisenab(Amplitude)={0.85,1}
			wavestats/q/m=(1)/z/R=(1/TFgr.PeriodMax,1/TFgr.PeriodMin) TFgr.SpectrumMag
			setaxis/W=$plotN/a=2 Amplitude
		endif

//Copy manipulations to plotted waves
		if(waveexists(TFgr.SpectrumMag))
			duplicate/o TFgr.SpectrumMag,TFgr.PlotSpectrum
			duplicate/o TFgr.SpectrumFrequency,TFgr.PlotSpectrumX
		else
			TFgr.PlotSpectrum=nan
		endif
		if(waveexists(TFgr.Backgroundmag))
			duplicate/o TFgr.Backgroundmag,TFgr.PlotBackground
			duplicate/o TFgr.Backgroundfrequency,TFgr.PlotBackgroundX
		else
			TFgr.PlotBackground=nan
		endif
		if(waveexists(TFgr.TFmag))
			duplicate/o TFgr.TFGlobalSpec,TFgr.PlotTFGlobalSpec
			duplicate/o TFgr.TFfrequency TFgr.PlotTFdecompX
			duplicate/o TFgr.TFmag,TFgr.PlotTFdecomp
		else
			TFgr.PlotTFdecomp=nan;TFgr.PlotTFGlobalSpec=nan
		endif
		strSwitch(TFgr.Norms)
			case "Magnitude":
				MatrixOp/O $(getWavesDataFolder(TFgr.PlotTFdecomp,2))=sqrt(TFgr.PlotTFdecomp)
				MatrixOp/O $(getWavesDataFolder(TFgr.PlotTFGlobalSpec,2))=sqrt(TFgr.PlotTFGlobalSpec)
				MatrixOp/O $(getWavesDataFolder(TFgr.PlotSpectrum,2))=sqrt(TFgr.PlotSpectrum)
				MatrixOp/O $(getWavesDataFolder(TFgr.PlotBackground,2))=sqrt(TFgr.PlotBackground)
				break
			case "Magnitude Squared":
				break
			case "Sin Peak Amplitude":
				MatrixOp/O $(getWavesDataFolder(TFgr.PlotTFdecomp,2))=2*sqrt(TFgr.PlotTFdecomp/2)
				MatrixOp/O $(getWavesDataFolder(TFgr.PlotTFGlobalSpec,2))=2*sqrt(TFgr.PlotTFGlobalSpec/2)
				MatrixOp/O $(getWavesDataFolder(TFgr.PlotSpectrum,2))=2*sqrt(TFgr.PlotSpectrum/2)
				MatrixOp/O $(getWavesDataFolder(TFgr.PlotBackground,2))=2*sqrt(TFgr.PlotBackground/2)
				break
			case "Background Normalized":
				TFgr.PlotTFdecomp[][]=TFgr.PlotTFdecomp[p][q]/TFgr.PlotBackground(TFgr.PlotTFdecompX[q])
				TFgr.PlotTFGlobalSpec[]=TFgr.PlotTFGlobalSpec[p]/TFgr.PlotBackground(TFgr.PlotTFdecompX[p])
				TFgr.PlotSpectrum=TFgr.PlotSpectrum/TFgr.PlotBackground(TFgr.PlotSpectrumX[p])
				TFgr.PlotBackground=TFgr.PlotBackground/TFgr.PlotBackground
				break
		endSwitch

//Axis ticks and labels
		NewFreeAxis/W=$plotN/o/r Frequency
		ModifyGraph/W=$plotN lblPos=60,lblPosMode=4
		Modifygraph/W=$plotN minor=1
		ModifyGraph/W=$plotN gfSize=0
		Modifygraph/W=$plotN nticks(Amplitude)=2,nticks(data)=2,nticks(position)=TFgr.nTicks
		ModifyGraph/W=$plotN highTrip(Amplitude)=100,lowTrip(Amplitude)=0.3
		ModifyGraph/W=$plotN highTrip(data)=100,lowTrip(data)=0.3
		string ordUnits,datUnits=Waveunits(TFgr.dw,-1)
		if(waveexists(TFgr.xw))
			ordUnits=Waveunits(TFgr.xw,-1)
		else
			ordUnits=Waveunits(TFgr.dw,0)
		endif
		Label/Z/W=$plotN  Position,ordUnits+"(\E)"
		Label/Z/W=$plotN  Period,"wavelength ("+ordUnits+"/cycle\E)"
		Label/Z/W=$plotN  Frequency,"frequency (cycles/"+OrdUnits+"\E)"
		Label/Z/W=$plotN  Amplitude,TFgr.Norms+" ("+DatUnits+"\E)"
		ModifyGraph TickUnit=1
		Label/Z/W=$plotN  Data,DatUnits+"(\E)"
//geometry
		Modifygraph/W=$plotN/Z freepos=0,axisenab(Data)={0.8,1},axisenab(Position)={0,0.8},mirror(Position)=1,expand=1
		Modifygraph/W=$plotN/Z axisenab(Period)={0,0.75},axisenab(Frequency)={0,0.75}
		Modifygraph/W=$plotN margin(left)=75,margin(bottom)=0,margin(right)=0,margin(top)=0

		TF_PlotRotate(plotN,TFgr)
		TF_PlotColorScale(plotN,TFgr,reset=1)
	endif
end

function TF_PlotColorScale(plotN,TFgr[,reset])
	string plotN
	struct TF_GlobalRefs &TFgr
	variable reset

//nonlinear color scale
	ColorScale/W=$plotN/C/N=AmpScale/F=0/A=LB/E=1/X=0/Y=0/B=1 log=0,minor=1,fsize=0
	ColorScale/W=$plotN/C/N=AmpScale image=$nameofwave(TFgr.PlotTFdecomp),""+TFgr.Norms+" ("+WaveUnits(TFgr.dw,-1)+"\E)"
	if(reset || numtype(TFgr.CTabMin) || numtype(TFgr.CTabMax))
		DoUpdate						//update plot for scaling of color scale
		GetAxis/Q/W=$plotN Amplitude
		TFgr.CTabMin=v_min;TFgr.CTabMax=v_max
	endif
	ControlInfo/W=$TFgr.ctrlWin CTabMin
	if(v_flag)		//if setvariable controls are drawn, update increment
		SetVariable CTabMin limits={0,inf,sigdigits(abs(TFgr.CTabMax-TFgr.CTabMin)/10,1)},win=$TFgr.ctrlWin
		SetVariable CTabMax limits={0,inf,sigdigits(abs(TFgr.CTabMax-TFgr.CTabMin)/10,1)},win=$TFgr.ctrlWin
	endif
	TF_LogColorTable(TFgr)
	ModifyImage/W=$plotN $nameofwave(TFgr.PlotTFdecomp) ctab= {TFgr.CTabMin,TFgr.CTabMax,$TFgr.CTabMode,0}
	ModifyImage/W=$plotN $nameofwave(TFgr.PlotTFdecomp) lookup=TFgr.CTabMod
end

function TF_PlotRotate(plotN,TFgr)
	string plotN
	struct TF_GlobalRefs &TFgr

	variable SwapXY=cmpstr(TFgr.SwapXY,"vertical data plot")==0
	
	TF_PlotReciprocalAxes(plotN,TFgr)
	if(SwapXY)		//Rotate
		Modifygraph/W=$plotN lblRot(Frequency)=0
		Modifygraph/W=$plotN swapXY=1
		ColorScale/W=$plotN/C/N=AmpScale vert=1,width=10,heightPct=40,side=2
		ReverseAxisRange("Period",plotN)
		ReverseAxisRange("Frequency",plotN)
		if(NumberByKey("IGORVERS", IgorInfo(0))<6.1)
			Modifygraph/W=$plotN margin(left)=140,margin(bottom)=60,margin(right)=0,margin(top)=60
		endif
	else				//unrotate
		Modifygraph/W=$plotN lblRot(Frequency)=180
		Modifygraph/W=$plotN swapXY=0
		ColorScale/W=$plotN/C/N=AmpScale vert=0,widthPct=40,height=10,side=1
		if(NumberByKey("IGORVERS", IgorInfo(0))<6.1)
			Modifygraph/W=$plotN margin(left)=60,margin(bottom)=110,margin(right)=60,margin(top)=0
		endif
	endif
end

function TF_PlotReciprocalAxes(plotN,TFgr)
	string plotN
	struct TF_GlobalRefs &TFgr
	
	variable tickInterval

	if(waveexists(TFgr.TFfrequency))
		duplicate/o TFgr.TFfrequency TFgr.PlotTFdecompX
	endif
	if(waveexists(TFgr.SpectrumFrequency))
		duplicate/o TFgr.SpectrumFrequency,TFgr.PlotSpectrumX
	endif
	if(waveexists(TFgr.Backgroundfrequency))
		duplicate/o TFgr.Backgroundfrequency,TFgr.PlotBackgroundX
	endif
	strswitch(TFgr.VertAxis)
		case "Linear frequency":
			break
		case "Linear period":
		case "Log(2)":
		case "Log(10)":
			TFgr.PlotTFdecompX=1/TFgr.PlotTFdecompX
			TFgr.PlotBackgroundX=1/TFgr.PlotBackgroundX
			TFgr.PlotSpectrumX=1/TFgr.PlotSpectrumX
			break
	endSwitch
//period & frequency axis ranges and ticks
	if(!waveexists(TFgr.vertP))
		make/o/t $(TFgr.TFfolder+":vertP"),$(TFgr.TFfolder+":vertF")
		make/o $(TFgr.TFfolder+":vertPy"),$(TFgr.TFfolder+":vertFy")
		wave/t TFgr.vertP=$(TFgr.TFfolder+":vertP"),TFgr.vertF=$(TFgr.TFfolder+":vertF")
		wave TFgr.vertPy=$(TFgr.TFfolder+":vertPy"),TFgr.vertFy=$(TFgr.TFfolder+":vertFy")
	endif
	ModifyGraph/W=$plotN userticks=0
	if(whichListItem("Period",AxisList(TFgr.win))>0)
		strswitch(TFgr.VertAxis)						//differentiate between linear and log axes
			case "Linear frequency":
				setaxis/W=$plotN/R Period 1/TFgr.PeriodMin,1/TFgr.PeriodMax
				setaxis/W=$plotN/R Frequency 1/TFgr.PeriodMin,1/TFgr.PeriodMax
				ModifyGraph/W=$plotN log(Period)=0,log(Frequency)=0
				tickInterval=SigDigits((1/TFgr.PeriodMin-1/TFgr.PeriodMax)/(TFgr.NTicks),1)
				redimension/n=(2*(1/TFgr.PeriodMin-1/TFgr.PeriodMax)/tickInterval) TFgr.vertF,TFgr.vertFy,TFgr.vertP,TFgr.vertPy
				TFgr.VertFy=(p+ceil((1/TFgr.PeriodMax)/TickInterval))*tickInterval
				TFgr.VertF=num2str(TFgr.VertFy)
				TFgr.VertPy=1/SigDigits(1/TFgr.vertFy,1);TFgr.VertP=num2str(1/TFgr.VertPy)
				ModifyGraph/W=$plotN userticks(Period)={TFgr.vertPy,TFgr.vertP}
				break
			case "Linear Period":
				setaxis/W=$plotN Period TFgr.PeriodMin,TFgr.PeriodMax
				setaxis/W=$plotN Frequency TFgr.PeriodMin,TFgr.PeriodMax
				ModifyGraph/W=$plotN log(Period)=0,log(Frequency)=0
				tickInterval=SigDigits((TFgr.PeriodMax-TFgr.PeriodMin)/(TFgr.NTicks),1)
				redimension/n=(2*(TFgr.PeriodMax-TFgr.PeriodMin)/tickInterval) TFgr.vertP,TFgr.vertPy,TFgr.vertF,TFgr.vertFy
				TFgr.VertPy=(p+ceil(TFgr.PeriodMin/TickInterval))*TickInterval
				TFgr.VertP=num2str(TFgr.VertPy)
				TFgr.VertFy=1/SigDigits(1/TFgr.VertPy,1);TFgr.VertF=num2str(1/Tfgr.VertFy)
				ModifyGraph/W=$plotN userticks(Frequency)={TFgr.vertFy,TFgr.vertF}
				break
			case "Log(10)":
				setaxis/W=$plotN Period TFgr.PeriodMin,TFgr.PeriodMax
				setaxis/W=$plotN Frequency 1/TFgr.PeriodMin,1/TFgr.PeriodMax
				ModifyGraph/W=$plotN log(Period)=1,log(Frequency)=1
				break
			case "Log(2)":
				setaxis/W=$plotN Period TFgr.PeriodMin,TFgr.PeriodMax
				setaxis/W=$plotN Frequency 1/TFgr.PeriodMin,1/TFgr.PeriodMax
				ModifyGraph/W=$plotN log(Period)=2,log(Frequency)=2
				break
		endSwitch
	endif
end

function ReverseAxisRange(axisName,plotName)
	string axisName,plotName
	
	getaxis/W=$plotName/Q $axisName
	setaxis/Z/W=$plotName $axisName,v_max,v_min
end

function SigDigits(val,dig)			//utility that returns a value truncated to dig number of digits
	variable val,dig
	
	variable i=1,ret
	do
		ret=trunc(val*10^i)
		if(ret==0)
			i+=1
		elseif(ret>=10)
			i-=1
		elseif(numtype(ret))
			return nan
		else
			i=10^i*10^(dig-1)
			return round(val*i)/i
		endif
	while(1)
end

static Function NewDataFolderPath(path[,set])
	string path
	variable set
	
	variable depth=itemsinlist(path,":"),i
	string partial=stringfromlist(0,path,":")
	if(strlen(partial)==0)	//path is relative, beginning with a :
		partial="";i=1
	elseif(cmpstr("root",partial)==0) //path is full from root
		partial="root";i=1
	else						//path is relative, with no initial :
		partial="";i=0
	endif
	for(i=i;i<depth;i+=1)
		partial+=":"+possiblyquotename(cleanupname(StringFromList(i,path,":"),1))
		newdatafolder/o $partial
	endfor
	if(set)
		SetDataFolder $partial
	endif
end

static Function ClearGraph([win])
	string win
	
	if(paramisdefault(win))
		win=winname(0,1)
	endif
	dowindow $win
	if(v_flag==0)
		win=winname(0,1)
	endif
	
	string PlotList
	variable i,nwaves
	PlotList=TraceNameList(win,";",1);nwaves=ItemsInList(PlotList)
	for(i=nwaves-1;i>=0;i-=1)
		RemoveFromGraph/W=$win/Z $stringfromlist(i,PlotList)
	endfor
	PlotList=ImageNameList(win,";");nwaves=ItemsInList(PlotList)
	for(i=nwaves-1;i>=0;i-=1)
		RemoveImage/W=$win/Z $stringfromlist(i,PlotList)
	endfor
	PlotList=AxisList(win);nwaves=itemsinList(PlotList)
	for(i=nwaves-1;i>=0;i-=1)
		KillFreeAxis/W=$win $stringfromlist(i,PlotList)
	endfor
end

static Function RemoveFliers(rg,sd,lw[,xw])
	wave lw,xw;variable rg,sd
	
	variable np,i,nr=0,no=0,pmin,pmax
	
	np=numpnts(lw)
	duplicate/o lw,tempderiv
	rg/=2
	if(waveexists(xw))
		differentiate tempderiv /X=xw
	else
		differentiate tempderiv
		rg/=deltax(lw)
	endif
//	do
		for(i=0,nr=no;i<np;i+=1)
			if(waveexists(xw))
				pmin=binarysearch(xw,xw[i]-rg)+1;pmax=binarysearch(xw,xw[i]+rg)
				if(pmax==-2)
					pmax=np-1
				endif
				wavestats/q/r=[pmin,pmax] tempderiv
			else
				wavestats/q/r=[max(i-rg,0),min(i+rg,np-1)] tempderiv
			endif
			if((abs(tempderiv[i])>(sd*V_sdev))*(numtype(tempderiv[i])<2))
				lw[i-1,i+1]=NaN;tempderiv[i]=NaN;no+=1
			endif
		endfor
//	while(nr!=no)
	killwaves/z tempderiv
	return nr
end

static Function RemoveOutliers(rg,sd,lw[,xw])
	wave lw,xw;variable rg,sd
	
	variable np,i,no=0,nr=0,pmin,pmax
	
	np=numpnts(lw)
	if(waveexists(xw))
	else
		rg/=deltax(lw)
	endif
//	do
		for(i=0,nr=no;i<np;i+=1)
			if(waveexists(xw))
				pmin=binarysearch(xw,xw[i]-rg)+1;pmax=binarysearch(xw,xw[i]+rg)
				if(pmax==-2)
					pmax=np-1
				endif
				wavestats/q/r=[pmin,pmax] lw
			else
				wavestats/q/r=[max(i-rg,0),min(i+rg,np-1)] lw
			endif
			if((lw[i]>(V_avg+sd*V_sdev)) + (lw[i]<(V_avg-sd*V_sdev)))
				lw[i]=NaN;no+=1
			endif
		endfor
//	while(nr!=no)
	return nr
end


static Function ReplaceNaN(w,at,rg)
	wave w
	variable at	//method of filling: 
				//		0 to fill with the average of the closest values
				//		1 to linearly interpolate between closest values
	variable rg	//number of points to use in defining closest values
	
	Variable i,j,avg,np=numpnts(w)
	
	i=0
	do
		wavestats/q/r=[i,min(i+99,np-1)] w
		if(V_numNaNs>0)
			i-=1
			do
				i+=1
			while((numtype(w[i])==0) & (i<np))
			j=0
			do
				j+=1
			while((numtype(w[i+j])!=0) & (i+j<np))
			if(i==0)
				w[i,i+j-1]=w[i+j]
			elseif(i+j==np)
				w[i,i+j-1]=w[i-1]
			elseif(at)
				wavestats/q/r=[max(i-rg,0),max(i-1,0)] w;avg=V_avg
				wavestats/q/r=[min(i+j,np-1),min(i+j+rg-1,np-1)] w
				w[i,i+j-1]=avg-((avg-V_avg)/j)*(p-i+1)
			else
				wavestats/q/r=[max(i-rg,0),min(i+j+rg-1,np-1)] w
				w[i,i+j-1]=v_avg
			endif
			i+=j
		else
			i+=100
		endif
	while(i<np)
end


static function WaveBrowserListbox(controlName,windowName[,promptText,Xpos,Ypos,Xsize,Ysize,WaveOpts,procName,add_calculated,nameFilterProc])
	string controlName,windowName
	variable Xpos,Ypos,Xsize,Ysize
	string WaveOpts,promptText,procName
	variable add_calculated
	string nameFilterProc
	
	string listBoxFolder
	
	if(paramisdefault(Xpos) || paramisdefault(Ypos))
		Xpos=5;Ypos=5
	endif
	if(paramisdefault(Xsize) || paramisdefault(Ysize))
		Xsize=100;Ysize=100
	endif
	if(paramisdefault(WaveOpts))
		waveOpts=""
	endif
	if(paramisdefault(nameFilterProc))
		nameFilterProc=""
	endif
	if(paramisdefault(PromptText))
		PromptText=""
	else
		TitleBox $(stringfromlist(0,controlName,"_")+"Title_"+stringfromlist(1,controlName,"_")),pos={Xpos,Ypos},size={Xsize,Ysize},title=promptText,fstyle=2^0,win=$windowName
		Ypos+=18;Ysize-=18
	endif
	ListBox $controlName,pos={Xpos,Ypos},size={Xsize,Ysize},win=$windowName

	MakeListIntoWaveSelector(windowName,controlName,content=WMWS_Waves,selectionMode=WMWS_SelectionSingle,listoptions=WaveOpts,nameFilterProc=nameFilterProc)
	if(!paramisdefault(procName))
		WS_SetNotificationProc(windowName, controlName, procname,isExtendedProc=1)
	endif
	if(add_calculated)
		WS_AddSelectableString(windowName,controlName,"_calculated_")
	endif
end
