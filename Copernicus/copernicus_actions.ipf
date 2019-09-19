#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName=copernicus
static strconstant module=copernicus

// Upper left corner of action panel
static constant action_panel_x = 0
static constant action_panel_y = 400

static strconstant action_panel_name = ActionsPanel
static strconstant action_panel_title = "Actions"


// The action panel
function action_panel([rebuild])
	variable rebuild
	variable xx = 5
	variable yy = 5
	variable button_width = 75
	variable button_height = 40
	string actions = "Log;Seal;Run;Edit_"
	variable panel_width = button_width+10
	variable panel_height = (button_height+5)*itemsinlist(actions)+5
	build_panel(rebuild, action_panel_name, action_panel_title, action_panel_x, action_panel_y, panel_width, panel_height, float=0)
	make /free/n=(3,3) colors = {{1,9611,39321}, {65535,0,0}, {0,40000,0}}
	variable i
	for(i=0; i<itemsinlist(actions);i+=1)
		variable j = mod(i, 3)
		string action = stringfromlist(i, actions)
		Button $action, fsize=24, pos={xx,yy+i*(button_height+5)}, size={button_width, button_height}, disable=0, proc=action_panel_buttons
		Button $action, fColor=(colors[0][j], colors[1][j], colors[2][j]), valueColor=(65535,65535,65535)
		Button $action, title="\F'Arial Black'" + replacestring("_", action, "")
	endfor
end


// Handle all button presses
Function action_panel_buttons(ctrlName) : ButtonControl
	String ctrlName
	
	string daq = MasterDAQ()
	string daq_type = DAQType(daq)
	strswitch(ctrlName)
		case "Seal":
			set_state("SealTest:Start")
			SetAcqMode("VC", 0)
			if(stringmatch(daq_type, "NoDAQ"))
				nvar /sdfr=$NoDAQ#GetDAQPath() t_init,t_update,tau,r_in,r_a,noise,offset
				offset = 0
				noise = 1
				r_in = 10
			endif
			SealTest(1)
			break
		case "Run":
			SetAcqMode("CC", 0)
			if(stringmatch(daq_type, "NoDAQ"))
				nvar /sdfr=$NoDAQ#GetDAQPath() t_init,t_update,tau,r_in,r_a,noise,offset
				offset = 0
				noise = 0.1
				r_in = 100
			endif
			data_window()
			break
		case "Edit_":
			view_protocol_sequence()
			break
	endswitch
End