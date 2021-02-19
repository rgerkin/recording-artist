#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName = copernicus
static strconstant module=copernicus
static strconstant font="Arial Black"
static constant font_size=10

#include "copernicus_loading"
#include "copernicus_logging"
#include "copernicus_actions"
#include "copernicus_status"
#include "copernicus_protocols"
#include "copernicus_acquisition"
#include "copernicus_visualization"
#include "copernicus_utilities"


Menu "Copernicus"
	"Initialize", copernicus#init()
	"Edit Protocols", copernicus#view_protocol_sequence()
	"Virtual Cell Parameters", NoDAQPanel()
End

function init()
	//Core#Def("ReallyNoDAQ")
	Silent 101
	Core#LoadModuleManifest(module)
	Core#LoadPackage(module, "Coordinates")
	Initialization(create_windows=0, prompt_experiment_name=0)
	dfref df = getstatusDF()
	variable /g df:copernicus = 1
	string /g df:copernicus_state = "Initialized"
	DefaultGUIFont all={font, font_size, 0} 
	// Build the logging panel
	logging_panel(rebuild=1)
	// Build the actions panel
	action_panel(rebuild=1)
	// Build the status panel
	status_panel(rebuild=1)

	make_protocol_sequence()
	// Build the data window
	//data_window(rebuild=1)
	
	// Set other defaults
	//SetAcqSetting("DAQs", "daq0", "Duration", "2")
	//SetAcqSetting("DAQs", "daq0", "ISI", "3")
end

function zeromq_init()
	zeromq_stop() // Stop any existing ZeroMQ operations
	zeromq_server_bind("tcp://127.0.0.1:5555") // Create a ZeroMQ server and begin listening
	zeromq_handler_start() // Prepare to handle incoming messages	
end

Function zeromq_receive_test_results( TestResults)
	string TestResults
	print TestResults
End