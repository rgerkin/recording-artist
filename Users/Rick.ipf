// $URL: svn://raptor.cnbc.cmu.edu/rick/recording-artist/Recording%20Artist/Users/Rick.ipf $
// $Author: rick $
// $Rev: 633 $
// $Date: 2013-03-28 15:53:22 -0700 (Thu, 28 Mar 2013) $

#pragma rtGlobals=3		// Use modern global access method.

#ifdef Rick

#ifdef Nlx
#include "Olfaction"
#endif

#ifdef Acq // Only load Rick's procedure files if the acquistion procedure files are loaded.  
#if exists("AxonTelegraphFindServers")
#include "Axon"
#endif
//#include "Batch Experiment Processing"
#include "Batch Plotting"
//#include "::Recording Artist:Acquisition (dev):Batch Wave Functions"
//#include "Data Browser"
//#include "Experiment Browser"
#include "GraphBrowser2"
#include "::Acquisition:Experiment Update"
//#include "Manual Upstate Detection"
//#include "Model Reverb"
//#include "Minis"
//#include "More Analysis"
//#include "Networking"
//#include "Reverberation"
//#include "ReverbPrintout"
//#include "Simulations"
#include "Spike Functions"
//#include "Spontaneous Analysis"
#if exists("VDT2")
#include "Sutter"
#endif
//#include "Temperature"
#ifdef Dev
//#include "Upstates"
#endif
#endif

#ifdef Basics
#include "ACL_WindowDesktops"
#include "Databases"
#include "Fit Functions"
#include "GLMFit"
#include "Manuscript Writer"
#include "Multithreading"
#include "NotebookBrowser"
#include "Plotting"
#include "Progress Window"
#if exists("SQLHighLevelOp")
#include "SQLUtils"
#endif
#include "Stats Plot"
#endif

Function ProfileHook()
	Execute /Q/Z "SetIgorOption colorize,UserFuncsColorized=1"
	Execute /Q/Z "SetIgorOption colorize,userFunctionColor=(40000,0,65000)"
	Execute /Q/Z "SetIgorOption independentModuleDev=1"
	Execute /Q/Z "SetIgorOption useFlushFileBuffers=0"
End

Function BeforeDebuggerOpensHook(pathToErrorFunction,isUserBreakpoint)
	String pathToErrorFunction
	Variable isUserBreakpoint
	
	svar /z password=root:password
	if(svar_exists(password))
		variable clearErrors=0
		string message="stackCrawl = "+GetRTStackInfo(0)
		Variable rtErr= GetRTError(clearErrors)	// get the error #
		Variable substitutionOption= exists(pathToErrorFunction)== 3 ? 3 : 2
		String errorMessage= GetErrMessage(rtErr,substitutionOption)
		message+="\rError = "+errorMessage
#if exists("email2")
		//email2(password,"4123773408@messaging.sprintpcs.com","[Igor Debugger Alert]",message) // Send me a text message.  
#endif
	endif
	return 0	// return 0 to show the debugger; an unexpected error occurred.
End
#endif // End of Rick's section.  

//#ifdef Bob
//#ifdef Acq // Only load Bob's procedure files if the acquistion procedure files are loaded.  
//#endif
//#endif


