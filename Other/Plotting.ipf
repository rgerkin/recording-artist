// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Plotting.ipf $
// $Author: rick $
// $Rev: 585 $
// $Date: 2011-08-26 09:24:03 -0400 (Fri, 26 Aug 2011) $

#pragma rtGlobals=1		// Use modern global access method.

// A window that can show the columns of a matrix, and in which those columns can be browsed.  
Function BrowseMatrix(Matrix)
	Wave Matrix
	if(WinExist("MatrixBrowser"))
		DoWindow/f MatrixBrowser
	else
		Display /K=1 /N=MatrixBrowser /W=(0,0,400,300)
		ControlBar /T 35
		//Cursors()
		Variable /G root:matrix_sweep_num
		SetVariable sweep,pos={35,10},size={120,10},title="Sweep",value=root:matrix_sweep_num,proc=NewMatrixSweep,limits={1,inf,1}
		PopupMenu matrix_win,pos={235,10},size={120,10},title="Window",value=";"+WinList("*",";","WIN:1")
		Checkbox transpose,pos={435,10},size={120,10},title="Transpose"
		SetWindow MatrixBrowser, userData=GetWavesDataFolder(Matrix,2)
		NVar num=root:matrix_sweep_num; num=0
		NewMatrixSweep("",0,"","")
	endif
End

// Creates a color wave according to the text values of some wave for use in z-coloring some trace of equal length.  
Function ColorByTextWave(TextWave,mapping)
	Wave /T TextWave
	String mapping // e.g. "CTL:black;TTX:red"
	Make /o/n=(numpnts(TextWave),3) ColorWave
	Variable i,red,green,blue
	for(i=0;i<numpnts(TextWave);i+=1)
		String color=StringByKey(TextWave[i],mapping)
		Color2RGB(color,red,green,blue)
		ColorWave[i][]={{red},{green},{blue}}
	endfor
End

// Sets three variables to the rgb values for a named color.  
Function Color2RGB(color,red,green,blue)
	String color
	Variable &red,&green,&blue
	strswitch(color)
		case "red":
			red=65535; green=0; blue=0
			break
		case "green":
			red=65535; green=0; blue=0
			break
		case "blue":
			red=65535; green=0; blue=0
			break
		case "black":
			red=0; green=0; blue=0
			break
		default: 
			red=0; green=0; blue=0
			break
	endswitch
End

Function YvsX2Image(Xwave,Ywave)
	Wave Xwave
	Wave Ywave
	Duplicate /o Xwave Xwave2
	Duplicate /o Ywave Ywave2
	Xwave2=log(Xwave2)
	Ywave2=log(Ywave2)
	Make /o/n=(600,600) $CleanupName("Image_"+NameOfWave(Xwave)+"_"+NameOfWave(Ywave),1)=0
	Wave Image=$CleanupName("Image_"+NameOfWave(Xwave)+"_"+NameOfWave(Ywave),1)
	//Make /o/n=500 dummy
	SetScale /I x,-2.1,2.8,Image; SetScale /I y,-2.1,2.8,Image
	//SetScale /I x,-2,3,Dummy
	Variable i,x_val,y_val
	for(i=0;i<numpnts(Xwave2);i+=1)
		x_val=Xwave2[i]
		y_val=Ywave2[i]
		if(!IsNaN(x_val)>0 && !IsNaN(y_val)>0)
			Image[x2pnt(Image,x_val)][x2pnt(Image,y_val)]+=1
		endif
	endfor
	NewImage /K=1 Image
	ModifyGraph userTicks={log_Ticks,log_Tick_labels}
	ModifyImage $NameOfWave(Image) ctab= {*,*,Rainbow,0}
	// Smooth
	for(i=0;i<10;i+=1)
		MatrixFilter /n=3 gauss Image
	endfor
	KillWaves /Z Dummy,Xwave2,Ywave2
End

Function GraphFits([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	NewDataFolder /O root:GraphFits
	Display /K=1 /N=GraphFits
	String graph_fits=WinName(0,1)
	DoWindow /B $graph_fits
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace_name=StringFromList(i,traces)
		Wave theWave=TraceNameToWaveRef(win,trace_name)
		Make /o/D W_coef={0.001,0.003,0.004,0,-50} // Initial guesses for fitting coefficients for fit function 'Synapse'. 
		Make /o/T T_Constraints = {"K0<=0.002","K1<=0.02","K2>0.004","K2<0.006","K4<0"} // Fit constraints for fit function 'Synapse'.  
		Make /o/n=(numpnts(theWave)) tempFit=0
		// w[0] = t_rise; w[1] = t_decay1; w[2] = t_decay2; w[3]= t0; w[4] = y0; w[5] = A
		Variable V_fitoptions=6,V_FitError=0,V_FitQuitReason=0,V_FitMaxIters=500
		FuncFit /Q/N Synapse kwcWave=W_Coef theWave /C=T_Constraints /D=tempFit
		if(V_FitError)
			printf "Error: Trace #%d (%s).\r",i,trace_name
		endif
		String fit_name="root:GraphFits:Fit_"+trace_name
		Duplicate /o tempFit $fit_name
		AppendToGraph /W=$graph_fits $fit_name
	endfor
	KillWaves /Z tempFit
	DoWindow /F $graph_fits
End

// Makes a layout of the jpegs matching 'mask' in 'directory' to the printer, by first tiling them on a layout (one page)
Function DirLayout([directory,mask])
	String directory,mask
	if(ParamIsDefault(directory))
		directory=GetDirectory()
	endif
	if(ParamIsDefault(mask))
		mask="*"
	endif
	String file_list=LS(directory,mask=mask)
	file_list=ListMatch(file_list,"*.jpg")
	
	NewLayout /N=Graphs
	Variable i; String file,loaded_name
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:figures
	for(i=0;i<ItemsInList(file_list);i+=1)
		file=StringFromList(i,file_list)
		ImageLoad /T=jpeg directory+":"+file
		loaded_name=StringFromList(0,S_Wavenames)
		NewImage /S=0 /K=1 $loaded_name
		AppendLayoutObject graph $TopWindow()
	endfor
	Execute "Tile"
	SetDataFolder $curr_folder
End


// An auxiliary function for BrowseMatrix()
Function NewMatrixSweep(ctrlName,popNum,popStr,other) : SetVariableControl
	String ctrlName; Variable popNum; String popStr,other
	GetWindow MatrixBrowser, userData; String source=S_Value
	DoUpdate
	GetAxis /Q left
	Variable low=V_min,high=V_max
	RemoveTraces()
	ControlInfo /W=MatrixBrowser transpose; Variable transpose=V_Value
	if(transpose)
		Duplicate /o /R=[popNum-1,popNum-1][] $source root:MatrixSweep
		Redimension /n=(numpnts(root:MatrixSweep)) root:MatrixSweep
		SetScale /P x,dimoffset($source,1),dimdelta($source,1),root:MatrixSweep
	else
		Duplicate /o /R=[][popNum-1,popNum-1] $source root:MatrixSweep
		SetScale /P x,dimoffset($source,0),dimdelta($source,0),root:MatrixSweep
	endif
	AppendToGraph root:MatrixSweep
	ControlInfo /W=MatrixBrowser matrix_win; String win=S_Value
	if(WinExist(win))
		RemoveFromGraph /W=$win /Z line
		Make /o/n=2 line=0
		Variable scaled_val
		if(transpose)
			GetAxis /W=$win /Q left
			SetScale /I x,V_min,V_max,line
			scaled_val=pnt2x2($source,popNum,0)
			line=scaled_val
			AppendToGraph /VERT /W=$win line
			//lineX={-Inf,Inf};lineY={popNum,popNum}
		else
			//DoUpdate
			GetAxis /W=$win /Q bottom
			SetScale /I x,V_min,V_max,line
			scaled_val=pnt2x2($source,popNum,1)
			line=scaled_val
			AppendToGraph /W=$win line
		endif
		ModifyGraph /W=$win rgb(line)=(0,0,0)
		//AppendToGraph /W=$win lineY vs lineX
	endif
	SetAxis left low,high
End

// Do to all the sweeps between the cursors, or indicated by 'regions'.   
Function Do2RegionSweeps(func_name [,args,channel,regions])
	String func_name
	String args // Arguments other than the name of the sweep.  
	String channel
	String regions // Regions such as "10,34;83,118".  
	DoWindow /F AnalysisWin
	if(ParamIsDefault(regions))
		if(!strlen(CsrInfo(A)) || !strlen(CsrInfo(B)))
			printf "Put cursors on region in Amplitude Analysis window first.\r"  
			return 0
		endif
		regions=num2str(xcsr(A)+1)+","+num2str(xcsr(B)+1)
	endif
	if(ParamIsDefault(channel))
		channel=CsrWave(A)
		channel=ReplaceString("ampl_",channel,"") // Turn "ampl_R1_R1" into "R1_R1"
		channel=ReplaceString("ampl2_",channel,"") // Turn "ampl2_R1_R1" into "R1_R1"
		channel=StringFromList(1,channel,"_") // Turn "R1_R1" into "R1"
	endif
	if(ParamIsDefault(args))
		args=""
	else
		args=","+args
	endif
	Variable i,sweep_num
	String region,actual_args,command
	regions=ListExpand(regions)
	for(i=0;i<ItemsInList(regions);i+=1)
		sweep_num=NumFromList(i,regions)
		actual_args=ReplaceString("<SWEEPNUM>",args,num2str(sweep_num))
		String sweep="root:cell"+channel+":sweep"+num2str(sweep_num)
		if(exists(sweep))
			command=func_name+"("+sweep+actual_args+")"
			//Execute /Q command
		endif
	endfor
End

