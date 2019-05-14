#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName = copernicus
static strconstant module=copernicus

// Upper left corner of logging panel
static constant data_x = 0
static constant data_y = 365
static constant data_width = 650
static constant data_height = 205

static strconstant data_name="DataWin"
static strconstant data_title="Data"

function CreateAndHideWaveSelector()
	string DAQ = MasterDAQ()
	WaveSelector()
	String selector_win=DAQ+"_Selector"
	DoWindow /HIDE=1 $selector_win 
	doupdate
end


// The main data visualization window
function data_window([rebuild])
	variable rebuild
	build_window(rebuild,data_name,data_title,data_x,data_y,data_width,data_height)
	CreateAndHideWaveSelector()
	ControlBar /T 40
	string DAQ = MasterDAQ()
	dfref daqDF = GetDAQdf(DAQ)
	SetWindow $data_name userData(daq)=DAQ
	SetVariable message pos={315,10}, fsize=14, bodywidth=270, disable=2
	SetVariable message value=_STR:"Beginning data collection..."
	wave /sdfr=daqDF input_0
	appendtograph input_0
	string state = get_state()
	string stopped = stringbykey("Acquisition", state, ":")
	string title = selectstring(stringmatch(stopped,"Stop"), "Stop", "Start")
	Button StartStop, pos={10, 10}, title=title, proc=DataWinButtons
	Label bottom "Time (s)"
	Label left "Membrane Potential (mV)"
	ModifyGraph font="Arial Black"
	auto_configure_stimulus()
	String selector_win=DAQ+"_Selector"
	DoWindow /HIDE=1 $selector_win 
	//start_acquisition()
end


// Handle button presses in the Data window
function DataWinButtons(info)
	struct WMButtonAction &info
	
	switch(info.eventCode)
		case 2: // Mouse Up
			string daq = MasterDAQ()
			dfref df = GetDaqDF(daq)
			nvar /sdfr=df acquiring
			strswitch(info.ctrlName)
				case "StartStop":
					if(acquiring)
						stop_acquisition()
						SetAcquisitionMonitor(0)
						Button StartStop, title="Start", win=DataWin
					else
						start_acquisition()
					endif
					break
			endswitch
			break
	endswitch
end