#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName=copernicus
static strconstant module=copernicus

// Upper left corner of action panel
static constant action_x = 650
static constant action_y = 365
static constant action_width = 200
static constant action_height = 100

static strconstant action_name = ActionsPanel
static strconstant action_title = "Actions"


// The action panel
function action_panel([rebuild])
	variable rebuild
	build_panel(rebuild,action_name,action_title,action_x,action_y,action_width,action_height)
	variable xx = 10
	variable yy = 15
	Button Seal, fsize=24, pos={xx,yy}, size={75,40}, disable=0, proc=action_panel_buttons, title="\F'Arial Black'Seal"
	Button Seal, fColor=(1,9611,39321), valueColor=(65535,65535,65535)
	Button Run, fsize=24,  pos={xx+80,yy}, size={75,40}, disable=0, proc=action_panel_buttons, title="\F'Arial Black'Run"
	Button Run, fColor=(65535,0,0), valueColor=(65535,65535,65535)
end


// Handle all button presses
Function action_panel_buttons(ctrlName) : ButtonControl
	String ctrlName
	
	strswitch(ctrlName)
		case "Seal":
			set_state("SealTest:Start")
			SealTest(1)
			break
		case "Run":
			data_window()
			break
	endswitch
End