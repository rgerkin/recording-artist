// $URL: svn://churro.cnbc.cmu.edu/igorcode/Users/Rick.ipf $
// $Author: rick $
// $Rev: 607 $
// $Date: 2012-04-24 22:56:02 -0400 (Tue, 24 Apr 2012) $

#pragma rtGlobals=1		// Use modern global access method.

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
#include "::Recording Artist:Acquisition:Experiment Update"
//#include "Manual Upstate Detection"
//#include "Model Reverb"
#include "Minis"
//#include "More Analysis"
//#include "Networking"
#include "Reverberation"
//#include "ReverbPrintout"
//#include "Simulations"
#include "Spike Functions"
//#include "Spontaneous Analysis"
#if exists("VDT2")
#include "Sutter"
#endif
//#include "Temperature"
#ifdef Dev
#include "Upstates"
#endif
#endif

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

#ifdef Bob
#ifdef Acq // Only load Bob's procedure files if the acquistion procedure files are loaded.  
#endif
#endif

#ifdef Craig
#ifdef Dev
#ifdef Basics
#include "Load Neuralynx"
#include "Neuralynx Analysis"
#include "Neuralynx Analysis2"
#include "Progress Window"
#endif
#endif
#endif

