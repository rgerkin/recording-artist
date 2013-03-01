#pragma rtGlobals=1		// Use modern global access method.

// For all.  
#ifndef Null

#ifdef Basics
#ifdef Dev
#endif
#include "Basics"
#endif

#ifdef Acq
#ifdef Dev
#endif
#include "Acquisition"
#endif // End #ifdef Acq

#ifdef Img
#ifdef Dev
#endif
#include "Imaging"
#endif

#ifdef Nlx
#include "Load Neuralynx"
#include "Neuralynx Analysis"
#include "Neuralynx Analysis2"
#endif

#endif

#if exists("Core#SetProfile")
Function IgorStartOrNewHook(igorApplicationNameStr)
	string igorApplicationNameStr 
	// Other people might want their own IgorStartOrNewHook functions to execute when they select their names
	//// from the profile menu.  They can put their code under their name here.  
	//string profiles=Core#ListProfiles()
	//string lastProfile=StringFromList(0,profiles)
	//Core#SetProfile(lastProfile)
	printf "%s %s\r",Date(),time()
	Execute /Q/P "ExperimentModified 0"
End
#endif
//#endif // End #ifdef Null

Function AfterFileOpenHook(refNum,file,pathName,type,creator,kind)
    Variable refNum,kind
    String file,pathName,type,creator
    
    printf "%s %s\r",Date(),time()
    SetDataFolder root:
    Execute /Q/P "ExperimentModified 0"
End

//Menu "Misc", hideable
//	Submenu "Packages"
//		"Axon", /Q, Execute/P/Q/Z "INSERTINCLUDE \"LoadABF212\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "LoadAxonBinaryFile()" 
//			help = {"For loading data in Axon Binary Format."}
//		"Dependency Analyzer", /Q, Execute/P/Q/Z "INSERTINCLUDE \"Dependency_Analyzer\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "DependencyAnalyzer#InitDependencyAnalyzer()" 
//			help = {"For analyzing the dependencies of each procedure file on the others."} 
//		"Drag and Drop Traces", /Q, Execute/P/Q/Z "INSERTINCLUDE \"DragAndDropTraces\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "DoAlert 0,\"You can toggle dragging and dropping of traces from the Graph menu\"" 
//			help = {"For dragging traces from one graph and dropping them on to another.  Limited to simple graphs."}
//		"Graph Browser", /Q, Execute/P/Q/Z "INSERTINCLUDE \"GraphBrowser\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "WM_GrfBrowser#NewGraphBrowser()" 
//			help = {"For browsing the contents of all graphs."}
//		"Manuscript Writer", /Q, Execute/P/Q/Z "INSERTINCLUDE \"Manuscript Writer\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "IMW#DisplayFigureManager();IMW#DisplayManuscriptManager()" 
//			help = {"For organizing figures for a manuscript."}
//		"Minis", /Q, Execute/P/Q/Z "INSERTINCLUDE \"Minis\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "InitMiniAnalysis()" 
//			help = {"For analysis of miniature/spontaneous synaptic currents."}
//		"Movie Analysis", /Q, Execute/P/Q/Z "INSERTINCLUDE \"Movie Analysis\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "InitMovieProcessing()" 
//			help = {"For analysis of movies (stacks of images)."}
//		"Notebook Browser", /Q, Execute/P/Q/Z "INSERTINCLUDE \"Notebook Browser\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "NotebookBrowser#Init()" 
//			help = {"For browsing notebooks in packed experiment files."}
//		"Neuralynx", /Q, Execute/P/Q/Z "INSERTINCLUDE \"Load Neuralynx\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "NeuralynxPanel()" 
//			help = {"For loading and analyzing data collected using Neuralynx electrophysiological equipment."}
//		"Time-Frequency",/Q, Execute/P/Q/Z "INSERTINCLUDE \"Time-Frequency\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "TimeFrequencyInvestigation()" 
//			help = {"For time-frequency analysis of signals."}
//		"Upstates", /Q, Execute/P/Q/Z "INSERTINCLUDE \"Upstates\"; INSERTINCLUDE \"Manual Upstate Detection\"";Execute/P/Q/Z "COMPILEPROCEDURES " 
//			help = {"For both automated and manual analysis of Upstates and Downstates."}
//		"Waves Average", /Q, Execute/P/Q/Z "INSERTINCLUDE \"Waves Average\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "MakeWavesAveragePanel()" 
//			help = {"For more sophisticated averaging of waves."}
//	end
//end









