#pragma rtGlobals=1		// Use modern global access method.
#include "Basics"

static strconstant module=Acq
#include ":Camera Wrappers" // Basic Camera Control.  
#include ":Camera Settings" // Camera Settings.  
#include ":Movie Analysis" // Image Analysis.  

Menu "Imaging"
	"Initialize Imaging", /Q, InitializeImaging();
	"Movie Analysis", /Q, InitMovieProcessing();
End

Function InitializeImaging()
	CameraHome()
	MakeCameraGlobals()
	MakeCameraPanel()
	InitMovieProcessing();
End


