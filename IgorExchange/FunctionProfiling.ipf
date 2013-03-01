#pragma rtGlobals=3	// Use modern global access method.
#pragma IgorVersion=6.23
#pragma ModuleName= FuncProfilingModule

// To find where your code is spending the most time, create a function that takes no
// paremeters and exercises your code for at least a second. Then call it via
// RunFuncWithProfiling(yourFuncHere)
// Or, if your test will take longer than 100 seconds, use
//		RunFuncWithProfiling(yourFuncHere,testTime=yourTimeEstimate)
//
//	The top functions will be printed into a notebook named "ProfilingResults"
// The left hand side will be annotated with percentages and a bar.
//	The results will look best in a monospaced font.
//	By default, the bar length will be relative to the total hit count. You can make it relative
//	to the line with the maximum hit count by including the optional variable normMode=1 like so:
//		RunFuncWithProfiling(yourFuncHere,normMode=1)
//	By default, results are printed until the total exceeds 80%. You can change that by providing
//	the optional variable maxPct like so:
//		RunFuncWithProfiling(yourFuncHere,maxPct=90)
//
// Your test function may call functions that are ThreadSafe and those that reside in an independent module
//	but only functions in the main thread are profiled. 
//
// If you have code that is inconvenient or difficult to wrap into a function that can
//	be passed to RunFuncWithProfiling, you can use the function pair:
//		BeginFunctionProfiling([testTime])
//		EndFunctionProfiling([normMode,maxPct])
//	You can create a simple panel with a button that calls these functions by executing:
//		FunctionProfilingPanel()
//	Don't forget to stop profiling.
//
//	The profiling code relies on two built-in functions that were added in Igor PRo 6.23. They are:
//
// A numeric function:
//	GetRTLocation(sleepMs)
// sleepMs is the number of milliseconds to sleep the current thread after fetching a value.
// Gets a code that defines the current location in the source that was executing at the time this was called.
// Use in a preemptive thread to sample a running routine for performance profiling.
// The result (stored in a double) can be passed to GetRTLocInfo to determine the location in the procedures.
// Note that this samples the main thread only and the locations will become meaningless after any procedure editing.
//
// And a string fucnction:
// GetRTLocInfo(code)
// code is the result from a (very recent) GetRTLocation
// Returns Key-value string: "PROCNAME:name;LINE:line;FUNCNAME:name;" or, a zero length string if the location could not be found.
// line number is padded with zeros to enable sorting
//
//	Created LH111202



Function MyExerciseRoutineProto()
End

Function RunFuncWithProfiling(f[,testTime,normMode,maxPct])
	FUNCREF MyExerciseRoutineProto f		// pass your function here
	Variable testTime						// estimate of total execution time (needed only if greater than 100 sec)
	Variable normMode						// needed only to pass 1 to indicate normalize bars to max found
	Variable maxPct							// needed only if print limit of 80% is not appropriate
	
	STRUCT MyProfilingStuff s
	StartProfiling(s,testTime)			// put the estimated time your code will run in the second parameter

	try
		f()
	catch
		StopProfiling(s)
		Print "User abort or other error"
		return 0
	endtry

	variable hitTot= StopProfiling(s)

	Print "Total time= ",s.testTime

	if( hitTot==0 )
		return 0						// something went wrong
	endif

	ProfilingCalcTopFuncs(s)
	ProfilingPrintTopFuncs(s,normMode,maxPct)
End



Static Structure MyProfilingStuff
	// Sampling step
	WAVE/D w							// used for samping the program location
	Variable tid						// thread id
	
	Variable testTime				// time between start and stop
	
	// Results processing step
	WAVE/T profilingLineInfo		// raw results
	WAVE profilingLineHitCount		// hit count for each
	
	Variable invalidSamps, validSamps

	WAVE/T profilingFuncNames		// each function
	WAVE profilingFuncPercent		// and its total percent
EndStructure



ThreadSafe Static Function DoProfiling(w,st)
	WAVE w
	Variable st
	
	Variable np= numpnts(w), i
	for(i=0; i<np; i+=1)
		w[i]= GetRTLocation(st)
		DFREF df= ThreadGroupGetDFR(0,0)
		if( DataFolderRefStatus(df) )
			break
		endif
	endfor
	return i		// how far we got
End

Static Function StartProfiling(s, tmax)
	STRUCT MyProfilingStuff &s
	Variable tmax	// time in seconds the test is expected to take (needed if > 100)
	
	Variable desiredSamps= 100000						// big enough for 100 sec at 1ms sampling rate
	
	Variable tms= round(1000*tmax/desiredSamps)		// milliseconds to sleep between samples
	if( tms<1 )
		tms= 1
	elseif( tms>100 )
		tms= 100
		desiredSamps= round(tmax*1000/tms)
	endif
	Make/O/D/FREE/N=(desiredSamps) s.w
	s.tid= ThreadGroupCreate(1)
	ThreadStart s.tid, 0, DoProfiling(s.w, tms)
	s.testTime= StopMSTimer(-2)
End

// returns total hit count; free waves ps.profilingLineInfo (text) and ps.profilingLineHitCount
// contain the semi-processed data
Static Function StopProfiling(ps)
	STRUCT MyProfilingStuff &ps

	NewDataFolder/O junkToStopProfiling
	Variable/G :junkToStopProfiling:junkvar=1
	ThreadGroupPutDF ps.tid,junkToStopProfiling			// message to stop
	Variable tstatus= ThreadGroupWait(ps.tid,1000)		// wait up to 1 sec for proper quit
	if( tstatus != 0 )
		print "Trouble stopting profiling thread, status= ",tstatus
	endif
	ps.testTime= (StopMSTimer(-2) - ps.testTime)*1E-6

	Variable tsamps= ThreadReturnValue(ps.tid,0)
	if( tsamps == numpnts(ps.w) )
		Print "Warning: time estimate too short."
	endif

	tstatus= ThreadGroupRelease(ps.tid)
	if( tstatus != 0 )
		print "Trouble releasing profiling thread, status= ",tstatus
	endif
	if( NumType(tsamps) != 0 ||  tsamps==0 )
		if( tsamps<10 )
			print "Too few samples taken - probably run time was too short."
		else
			print "Trouble stopping thread gave invalid results. Quitting."
		endif
		return 0
	endif
	
	Make/O/T/N=(tsamps)/FREE profilingLineInfo
	Make/O/N=(tsamps)/FREE profilingLineHitCount
	WAVE/T ps.profilingLineInfo= profilingLineInfo
	WAVE ps.profilingLineHitCount= profilingLineHitCount
	
	Make/O/T/N=(tsamps)/FREE rawSampLocInfo= GetRTLocInfo(ps.w[p])
	Sort rawSampLocInfo, rawSampLocInfo
	Variable i, j, indexOut=0
	for(i=0;i<tsamps;i+=1)
		if(strlen(rawSampLocInfo[i]) != 0 )
			break
		endif
	endfor
	String s,stmp
	if( i!=0 )
		profilingLineInfo[indexOut]= "INVALID"		// This can happen occasionally due to the nature of preemptive sampling or because no function was executing at the time a sample was taken.
		profilingLineHitCount[indexOut]= i
		indexOut+=1
	endif
	if( i>= tsamps )
		Print "No valid samples were taken."
		return 0
	endif
	ps.invalidSamps= i
	do
		s= rawSampLocInfo[i]
		for(j=i+1;j<tsamps;j+=1)
			if( CmpStr(s,rawSampLocInfo[j]) != 0 )
				break
			endif
		endfor
		profilingLineInfo[indexOut]= s
		profilingLineHitCount[indexOut]= j-i
		indexOut+=1
		i= j
	while(i<tsamps)
	Redimension/N=(indexOut) profilingLineInfo,profilingLineHitCount
	ps.validSamps= sum(profilingLineHitCount) - ps.invalidSamps
	return ps.validSamps
End


Static Function ProfilingCalcTopFuncs(ps)
	STRUCT MyProfilingStuff &ps

	Variable np= numpnts(ps.profilingLineInfo)
	Make/O/T/N=(np)/FREE profilingFuncNames
	Make/O/D/N=(np)/FREE profilingFuncPercent

	WAVE/T ps.profilingFuncNames= profilingFuncNames
	WAVE ps.profilingFuncPercent= profilingFuncPercent
	
	Variable i=0, outIndex=0
	
	// Skip any invalid lines (sorting puts them at the begining)
	for(i=0;i<np;i+=1)
		if( strlen(StringByKey("FUNCNAME",ps.profilingLineInfo[i])) )
			break
		endif
	endfor
	
	// Collect all counts for each function 
	do
		String pn= StringByKey("PROCNAME",ps.profilingLineInfo[i])
		String fn= StringByKey("FUNCNAME",ps.profilingLineInfo[i])
		
		profilingFuncNames[outIndex]= "PROCNAME:"+pn+";FUNCNAME:"+fn+";"
		profilingFuncPercent[outIndex]= ps.profilingLineHitCount[i]
		
		for(i+=1; i<np; i+=1 )
			String pn2= StringByKey("PROCNAME",ps.profilingLineInfo[i])
			String fn2= StringByKey("FUNCNAME",ps.profilingLineInfo[i])
			if( CmpStr(pn,pn2)==0 && CmpStr(fn,fn2)==0 )
				profilingFuncPercent[outIndex] += ps.profilingLineHitCount[i]
			else
				break
			endif
		endfor
		outIndex += 1
	while(i<np)
	
	Redimension/N=(outIndex) profilingFuncNames,profilingFuncPercent
		
	profilingFuncPercent= round(profilingFuncPercent*100/ps.validSamps)
	Sort/R profilingFuncPercent,profilingFuncPercent,profilingFuncNames
End			
	

Static Function ProfilingPrintTopFuncs(ps, normMode,maxPct)
	STRUCT MyProfilingStuff &ps
	Variable normMode	// how to normalize the bars. 0 vs total hit count, 1 vs max
	Variable maxPct		// neede only if 80 is not appropriate
	
	if( maxPct==0 )
		maxPct= 80
	endif

	Variable np= numpnts(ps.profilingFuncPercent)
	Variable i
	
	DoWindow/F ProfilingResults
	if( V_Flag == 0 )
		NewNotebook/F=0/N=ProfilingResults
	endif
	NoteBook ProfilingResults, selection={startOfFile,endOfFile}

	// First, a summary
	
	String stmp
	Variable fractValid= ps.validSamps/(ps.validSamps+ps.invalidSamps)
	sprintf stmp,"Total time: %g, Time in Function code: %g (%.3g%%)\r",ps.testTime, (ps.testTime*fractValid), 100*fractValid
	
	NoteBook ProfilingResults, text= stmp
	NoteBook ProfilingResults, text= "Top function percentages:\r"
	Variable pctTot= 0
	for(i=0;i<np;i+=1)
		String pn= StringByKey("PROCNAME",ps.profilingFuncNames[i])
		String fn= StringByKey("FUNCNAME",ps.profilingFuncNames[i])
		
		Variable vtmp= ps.profilingFuncPercent[i]
		sprintf stmp, "Function %s: %d\r", pn+"#"+fn,  vtmp
		NoteBook ProfilingResults, text=stmp
	
		pctTot += ps.profilingFuncPercent[i]
		if( pctTot>maxPct )
			break
		endif
	endfor
	
	NoteBook ProfilingResults, text= "\rAnnotated Top Functions:\r"
	if( normMode )
		NoteBook ProfilingResults, text= "(Bars normalized to largest hit count)\r"
	endif

	// Again for the full func print
	pctTot= 0
	for(i=0;i<np;i+=1)
		pn= StringByKey("PROCNAME",ps.profilingFuncNames[i])
		fn= StringByKey("FUNCNAME",ps.profilingFuncNames[i])
	
		String func= ProfilingAnnotateFunc(pn, fn, ps.profilingFuncPercent[i], ps.profilingLineInfo, ps.profilingLineHitCount, normMode, ps.validSamps)
		NoteBook ProfilingResults, text=func
		pctTot += ps.profilingFuncPercent[i]
		if( pctTot>maxPct )
			break
		endif
	endfor
End


Static Function/T ProfilingAnnotateFunc(pn, fn, pct, wInfo, wCnt, normMode, validSamps)
	String pn, fn			// procedure and function names
	Variable pct			// percent of hits in this function
	WAVE/T wInfo			// line info
	WAVE wCnt				// and cooresponding hit count
	Variable normMode	// how to normalize the bars. 0 vs total hit count, 1 vs max
	Variable validSamps	// total valid samples
	
	String func= ProcedureText(fn,0,pn)
	if( strlen(func)==0 )
		return "Error getting procedure text"
	endif
	String finfo= FunctionInfo(fn,pn+" [_AnyIM_]")		// Had to modify FunctionInfo to allow the AnyIM part just for its use here. 
	Variable lineNo= NumberByKey("PROCLINE",finfo)
	if( NumType(lineNo) != 0 )
		return "Error getting procedure line number"
	endif
	
	// now search for group of line info data for this function
	Variable ninfo= numpnts(wCnt)
	Variable i
	for(i=0;i<ninfo;i+=1)
		if( CmpStr(pn,StringByKey("PROCNAME",wInfo[i])) == 0 && CmpStr(fn,StringByKey("FUNCNAME",wInfo[i])) == 0 )
			break
		endif
	endfor
	
	if( i>=ninfo )
		return "Error getting finding info set"
	endif
	
	String anTerm= "\t|"		// replace with your preferred termination of the annotation part
	
	String noHit= "[00]          "+anTerm
	String hitSplats="**********"
	String hitSpaces="          "
	
	Variable j, nLines= ItemsInList(func,"\r")
	Variable nextHitLine= NumberByKey("LINE",wInfo[i]) - lineNo
	Variable barTot= normMode ? WaveMax(wCnt) : validSamps
	
	String splats= "*******************************************************************************************"
	
	String outStr="\r"+splats+"\r"
	String stmp
	sprintf stmp, "Function: %s; Percent total %.2d\r",pn+"#"+fn,pct
	outStr += stmp+splats+"\r"
	
	for(j=0;j<nLines;j+=1)
		String sLine= StringFromList(j, func, "\r") + "\r"
		if( j<nextHitLine )
			outStr += noHit + sLine
		else
			String sPre
			Variable linepct= round(100*wCnt[i]/validSamps)		// true percentage of total hit count
			sprintf  sPre,"[%0.2d]",linepct
			linepct= round(100*wCnt[i]/barTot)							// percentage normalized to either total or max individual line
			Variable nSplats= max(1,round(linepct/10))
			sPre += hitSplats[0,nSplats-1]
			if( nSplats != 10 )
				sPre += hitSpaces[0,10-nSplats-1]
			endif
			outStr += sPre + anTerm + sLine
			i+=1
			if( i<ninfo && CmpStr(pn,StringByKey("PROCNAME",wInfo[i])) == 0 && CmpStr(fn,StringByKey("FUNCNAME",wInfo[i])) == 0 )
				nextHitLine= NumberByKey("LINE",wInfo[i]) - lineNo
			else
				nextHitLine= inf
			endif
		endif
	endfor
	return outStr
End


// *********** background versions ***********

//		
//		
//	You can create a simple panel with a button that calls these functions by executing:
//		FunctionProfilingPanel()


Function BeginFunctionProfiling([testTime])
	Variable testTime		// default value of zero is fine (will act like 100)
	
	DFREF saveDFR= GetDataFolderDFR()
	NewDataFolder/O/S root:tmpBackgroundFldr
	STRUCT MyProfilingStuff s
	StartProfiling(s,testTime)	
	Variable/G tid= s.tid
	KillWaves/Z $"profilingLineInfo"		// just in case this got left around
	MoveWave s.w, profilingLineInfo
	Variable/G gTestTime= s.testTime
	SetDataFolder saveDFR
End

Function EndFunctionProfiling([normMode, maxPct])
	Variable normMode			// default value of zero is fine
	Variable maxPct				// needed only if print limit of 80% is not appropriate
	
	DFREF saveDFR= GetDataFolderDFR()
	SetDataFolder root:tmpBackgroundFldr
	NVAR tid
	NVAR gTestTime
	WAVE profilingLineInfo
	STRUCT MyProfilingStuff s
	s.tid= tid
	s.testTime= gTestTime
	WAVE s.w= profilingLineInfo
	
	variable hitTot= StopProfiling(s)

	if( hitTot==0 )
		return 0						// something went wrong
	endif

	ProfilingCalcTopFuncs(s)
	ProfilingPrintTopFuncs(s,normMode,maxPct)
	SetDataFolder saveDFR
	KillDataFolder root:tmpBackgroundFldr
End

Static Function FuncProfStartStopProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	if( ba.eventCode == 2 )		// mouse up
		if( CmpStr(ba.ctrlName, "bStart") == 0 )
			BeginFunctionProfiling()
			Button bStart, win=$ba.win, rename= bStop,title= "Stop Profiling"
		else
			EndFunctionProfiling()
			Button bStop, win=$ba.win, rename= bStart,title= "Start Profiling"
		endif
	endif
	return 0
End

Window FunctionProfilingPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel/K=1/FLT=1 /W=(52,65,292,193)
	Button bStart,pos={61,50},size={112,28},proc=FuncProfilingModule#FuncProfStartStopProc,title="Start Profiling"
	SetActiveSubwindow _endfloat_
EndMacro
