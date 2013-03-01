// $URL: svn://churro.cnbc.cmu.edu/igorcode/IgorExchange/Multithreading.ipf $
// $Author: rick $
// $Rev: 607 $
// $Date: 2012-04-24 22:56:02 -0400 (Tue, 24 Apr 2012) $

// Easy Multithreading Package
// by Richard C. Gerkin
// Requires Igor 6.2.  

//   This procedure file provides an easy way to achieve multithreading in Igor with your existing library of functions, and without having to deal with any lower level implementation of thread management.  
// This provides an interface to two of the three approaches to multithreading in Igor:  
//
//    -- The first, accomplished by placing "Multithead" in front of a wave assignment statement, requires no simplification.  
//
//    -- The second involves parallel assignment to waves using a function that generates the assignment contents.  For example, this function could be used to fill the columns of a matrix, in parallel.  
//	To test this implementation, call Multi#DirectTest() on the command line.  By following the example functions DirectTest() and DirectTask(), you will be able to write your own functions to use with the
//       high level implementation Multi#ParallelD().  
//       This method requires putting your existing Igor functions that you want to execute in parallel into the form:  
//
//       Function myFunction(w,options)
//          wave w; string options
//       End
//
//    -- The third involves parallel operation on data folders placed in queue.   For example, this could be used to perform an analysis on the contents of every subfolder in some data folder, such as root:.  
//       To test this implementation, call Multi#QueueTest() on the command line.  By following the example functions QueueTest() and QueueTask(), you will be able to write your own functions to use with the
//       high level implementation Multi#ParallelQ().  It is very important that you create/modify the worker functions you intend to use (the functional argument to ParallelD()) to include WaveClear commands as
//       necessary to avoid leaving any references in use when a preemptive thread exits.  Failure to do so will usually lead to Igor hanging and often loss of data.  Proceed with caution and save often.  
//       This method requires putting your existing Igor functions that you want to execute in parallel into the form:  
// 
//       Function myFunction(df,options)
//          dfref df; string options
//       End
//
//   In both cases, the functional form required for using ParallelD or ParallelQ is easily achieved by modifying your existing function's arguments or simply wrapping in a wrapper function with the correct form.  
// The 'options' string should be able to hold many/all of the arguments that your function already has, through the use of conversion of numbers with num2str, wave references with GetWavesDataFolder(), and so on.  
// These can all be combined into one string with semi-colon separated keys and values (with each key-value pair separated by a colon), which can then be extracted with StringByKey(), NumberByKey(), etc.  
//   Multithreading can be expected to speed up processing by a factor of up to the return value of ThreadProcessorCount on your machine.  Due to the overhead of multithreading, this limit is approached most
// closely with computationally intensive operations.  On a Mac Pro using OS X 10.6, ThreadProcessorCount returns 16, and I typically get a 10-12x speedup depending on the task.  
//   The programmer should also be aware that multithreaded tasks must still share the same pool of memory, so a function that requires 1/2 of the available memory in Igor (at most 2 gigabytes since Igor is 32-bit) 
// cannot be parallelized across more than 2 threads.  So ideally your tasks will require less than 4 gigabytes/ThreadProcessorCount to allow each thread to run in parallel without running out of memory.  
//   Be sure that all of your functions can be made Threadsafe.  This is easy enough to test; just put Threadsafe in front of the function name.  Graphing operations are not and probably never will be threadsafe.  
// However, some other operations are not currently Threadsafe but probably can be made Threadsafe with a little prodding of the Wavemetrics developers.  
//   Lastly, using the debugger in a multithreaded task is not possible.  Therefore, you will need to debug with print statements.  To make this easier, I have included a function Dbg(), which prints to the history window
// only when the compiler definition 'PrintDebug" is on.  Mutli#SetDbg() can be used to turn 'PrintDebug' on and off.  When it is off, Dbg() statements will do nothing, as if they were commented out.  
//   Enjoy your multithreading adventures!  

#pragma rtGlobals=3		// Use super-modern global access method.
#pragma moduleName=Multi

// ----------- Examples to paste into one of your other procedure files (be sure to give them new names). ---------------

// An example function that you could run serially or in parallel to fill the columns of the wave 'w'.  
ThreadSafe Function DirectTask(w,options)
	WAVE w
	string options
	
	variable col=NumberByKey("COL",options)
	make /free/n=(dimsize(w,0)) myColumn=gnoise(1)
	FFT myColumn
	IFFT myColumn
	w[][col]=myColumn[p]
End

// Test serial vs. parallel performance for the 'DirectTask' function.  
Function DirectTest()
	variable rows=10000
	variable cols=1000
	make/o/n=(rows,cols) jack
	
	variable i
	for(i=0;i<10;i+=1)		// get any pending pause events out of the way
	endfor
	
	variable refNum
	refNum=StartMsTimer; Multi#SerialD(jack,DirectTask,""); variable serialT=StopMsTimer(refNum)
	refNum=StartMsTimer; Multi#ParallelD(jack,DirectTask,""); variable parallelT=StopMsTimer(refNum)
	printf "Serial took %.1f ms; Parallel took %.1f ms; Parallel was %.2f times faster.\r",serialT/1000,parallelT/1000,serialT/parallelT
end

// An example function that you could run serially or in parallel across the subfolders of data folder df.  
threadsafe static Function QueueTask(df,options)
	dfref df
	string options
	
	setdatafolder df
	wave smith
	fft smith
	ifft smith
	waveclear smith
End

// Test serial vs. parallel performance for the 'QueueTask' function.  
static Function QueueTest()
	NewDataFolder/O/S root:myGroup
	variable i
	for(i=0;i<100;i+=1)
		NewDataFolder/O/S $("df"+num2str(i))
		Make/o/n=100000 smith=gnoise(1)
		SetDataFolder ::
	endfor
	SetDataFolder root:
	waveclear smith
	
	variable refNum
	refNum=StartMsTimer; Multi#SerialQ(root:myGroup,QueueTask,""); variable serialT=StopMsTimer(refNum)
	refNum=StartMsTimer; Multi#ParallelQ(root:myGroup,QueueTask,""); variable parallelT=StopMsTimer(refNum)
	printf "Serial took %.1f ms; Parallel took %.1f ms; Parallel was %.2f times faster.\r",serialT/1000,parallelT/1000,serialT/parallelT
end

// -------------- Functions to facilitate multithreading with direct wave assignment.  For use with ParallelD. ------------------------------

// To execute non-threadsafe functions serially.  
static Function SerialD_(w,f,options[,prog])
	WAVE w
	funcref MTD_FuncPrototype_ f
	string options
	variable prog
	
	Variable cols=dimsize(w,1)
	Variable i,col
	
	for(col= 0;col<cols;col+=1)
		options="COL:"+num2str(col)
		f(w,options)
	endfor
End

// To execute threadsafe functions serially.  
static Function SerialD(w,f,options[,prog])
	WAVE w
	funcref MTD_FuncPrototype f
	string options
	variable prog
	
	Variable cols=dimsize(w,1)
	Variable i,col
	
	for(col= 0;col<cols;col+=1)
		options="COL:"+num2str(col)
		f(w,options)
	endfor
End

// To execute threadsafe functions in parallel. 
static Function ParallelD(w,f,options[,prog])
	WAVE w
	funcref MTD_FuncPrototype f
	string options
	variable prog
	
	Variable cols=dimsize(w,1)
	Variable i,col,numThreads=ThreadProcessorCount
	variable tgID=ThreadGroupCreate(numThreads)
	
	for(col=0;col<cols;)
		options=addlistitem("COL:"+num2str(col),options)
		for(i=0;i<numThreads;i+=1)
			ThreadStart tgID,i,f(w,options)
			col+=1
			if( col>=cols)
				break
			endif
		endfor		
		do
		while(ThreadGroupWait(tgID,100))
	endfor
	variable dummy= ThreadGroupRelease(tgID)
End

// Function prototype for a threadsafe function you can use with the direct method.  
threadsafe function MTD_FuncPrototype(w,options)
	wave w
	string options
end

// Function prototype for a non-threadsafe function you can use with the direct method (only for testing the speed of serial execution).  
function MTD_FuncPrototype_(w,options)
	wave w
	string options
end

// -------------- Functions to facilitate multithreading with an input/output queue.  For use with ParallelQ. ------------------------------

// To execute non-threadsafe functions serially.  
static function SerialQ_(df,f,options[,match])
	dfref df
	funcref MTQ_FuncPrototype_ f
	string options,match
	
	setdatafolder df
	string folders=stringbykey("FOLDERS",DataFolderDir(1))
	if(!paramisdefault(match))
		folders=ListMatch(folders,match,",")
	endif
	variable i
	Variable nfldrs= itemsinlist(folders,",")
	for(i=0;i<nfldrs;i+=1)
		string folder=stringfromlist(i,folders,",")
		f(df:$folder,options)
	endfor
end

// To execute threadsafe functions serially. 
static function SerialQ(df,f,options[,match])
	dfref df
	funcref MTQ_FuncPrototype f
	string options,match
	
	setdatafolder df
	string folders=stringbykey("FOLDERS",DataFolderDir(1))
	if(!paramisdefault(match))
		folders=ListMatch(folders,match,",")
	endif
	variable i
	Variable nfldrs=itemsinlist(folders,",")
	for(i=0;i<nfldrs;i+=1)
		string folder=stringfromlist(i,folders,",")
		f(df:$folder,options)
	endfor
end

// To execute threadsafe functions in parallel. 
static function ParallelQ(df,f,options[,match,prog])
	dfref df
	funcref MTQ_FuncPrototype f
	string options
	string match // Only operate on folders within df that match 'match'.  
	variable prog // Display a progress window.  
 
	variable tgID=TGInit(f,options)
	setdatafolder df
	string folders=stringbykey("FOLDERS",DataFolderDir(1))
	if(!paramisdefault(match))
		folders=ListMatch(folders,match,",")
	endif
	TGExecute(tgID,folders,prog)
	variable dummy=ThreadGroupRelease(tgID)
	dbg("Parallel Execution Finished")
end

// Executes the multithreaded input/output folder queue operation and manages the main thread group  You do not need to call this directly.  
static function TGExecute(tgID,folders,prog) 
	variable tgID
	string folders
	variable prog
 
	variable i
	Variable nfldrs=itemsinlist(folders,",")
	for(i=0;i<nfldrs;i+=1)
		string folder=stringfromlist(i,folders,",")
		dfref df=$folder
		dbg("Status of "+folder+" is "+num2str(DataFolderRefStatus(df)))
		ThreadGroupPutDF tgID,df
		dbg("Put "+folder)
	endfor
	if(prog)
		ProgWinOpen()
	endif
	for(i=0;i<nfldrs;i+=1)
		if(prog)
			ProgWin(i/nfldrs,0)
		endif
		dbg("Waiting for folder number "+num2str(i))
		do
			folder=ThreadGroupGetDF(tgID,2000)
			if(strlen(folder)==0)
				dbg("main still waiting for worker thread results")
			else
				break
			endif
		while(1)
		dbg("Got "+folder)
	endfor
	if(prog)
		ProgWinClose()
	endif
end

// Initializes the multithreaded input/output folder queue operation.  You do not need to call this directly.  
static function TGInit(f,options)
	funcref MTQ_FuncPrototype f
	string options
	
	variable numThreads=ThreadProcessorCount
	variable tgID=ThreadGroupCreate(numThreads)
	dbg("Thread group "+num2str(tgID)+" was created.")
	variable i
	for(i=0;i<numThreads;i+=1)
		ThreadStart tgID,i,TGWrap(f,options)
		dbg("Thread "+num2str(i)+" was started.")
	endfor
	return tgID
end

// Wraps the 'worker' function (e.g. QueueTask) in the preemptive thread group and manages its release of data back into the main thread group.  You do not need to call this directly.  
threadsafe static function TGWrap(f,options)
	funcref MTQ_FuncPrototype f
	string options
	
	dbg("A thread is waiting to get a folder.")
	do
		do
			string folder=ThreadGroupGetDF(0,2000)
			if(strlen(folder)==0)
				//printz "worker thread still waiting for input queue"
			else
				break
			endif
		while(1)
		dbg("A thread got folder "+folder)
		dfref df=$folder
		dbg("Status of thread's folder "+folder+" is "+num2str(DataFolderRefStatus(df)))
		f(df,options)
		dbg("Execute a function on "+folder)
		ThreadGroupPutDF 0,df
		dbg("Folder "+folder+" has been put released back to the queue.")
	while(1)
end

// Function prototype for a threadsafe function you can use with the input/output folder queue method.  
threadsafe function MTQ_FuncPrototype(df,options)
	dfref df
	string options
end

// Function prototype for a non-threadsafe function you can use with the input/output folder queue method (only for testing the speed of serial execution).  
function MTQ_FuncPrototype_(df,options)
	dfref df
	string options
end

// ------------------------------ Auxiliary Functions -----------------------------------

// Prints a debug message (just a print statement) only if the PrintDebug definition is set.  
threadsafe static Function Dbg(str)
	string str // A debugging message to print. 
#ifdef PrintDebug
	print str
#endif
End

// Defines or undefines the PrintDebug compiler definition, thus effectively enabling or disabling print Dbg().  
static Function SetDbg(state)
	variable state
	
	if(state)
		Execute /Q/P "SetIgorOption poundDefine=PrintDebug"
	else
		Execute /Q/P "SetIgorOption poundUnDefine=PrintDebug"
	endif
	Execute /Q/P "Silent 101"
End

// Progress window functions for the programmer to implement.  Can be superceded with the Progress Window package, which implements a graphical progress window.  
#if !exists("ProgWinOpen")
static Function ProgWinOpen()
End

static Function ProgWin(progress,level)
	variable progress,level
End

static Function ProgWinClose()
End
#endif