#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName = copernicus
static strconstant module=copernicus

#include "copernicus_logging"
#include "copernicus_actions"
#include "copernicus_status"
#include "copernicus_protocols"
#include "copernicus_acquisition"
#include "copernicus_visualization"
#include "copernicus_utilities"


Menu "Copernicus"
	"Initialize", copernicus#init()
End

function init()
	Core#Def("ReallyNoDAQ")
	Silent 101
	Core#LoadModuleManifest(module)
	Core#LoadPackage(module, "Coordinates")
	Initialization(create_windows=0, prompt_experiment_name=0)
	dfref df = getstatusDF()
	variable /g df:copernicus = 1
	string /g df:copernicus_state = "Initialized"
	// Build the logging panel
	logging_panel(rebuild=1)
	// Build the actions panel
	action_panel(rebuild=1)
	// Build the status panel
	status_panel(rebuild=1)

	make_protocol_sequence()
	// Build the data window
	data_window(rebuild=1)
end
