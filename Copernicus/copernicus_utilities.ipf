#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName = copernicus
static strconstant module=copernicus


// Is copernicus active?
function copernicus()
	dfref df = getstatusDF()
	nvar /z/sdfr=df copernicus
	variable result = 0
	if(nvar_exists(copernicus) && copernicus)
		result = 1
	endif
	return result
end


function build_panel(rebuild, name, title, xx, yy, width, height)
	variable rebuild, xx, yy, width, height
	string name, title
	
	if(rebuild)
		DoWindow /K $name
	else
		if(WinType(name))
			DoWindow /F $name
			return 0
		endif
	endif
	NewPanel /K=1 /W=(xx,yy,xx+width,yy+height) /N=$name as title
end

function build_window(rebuild, name, title, xx, yy, width, height)
	variable rebuild, xx, yy, width, height
	string name, title
	
	if(rebuild)
		DoWindow /K $name
	else
		if(WinType(name))
			DoWindow /F $name
			return 0
		endif
	endif
	Display /K=1 /W=(xx,yy,xx+width,yy+height) /N=$name as title
end


// Get the current experiment state
function /s get_state()
	dfref df = getstatusDF()
	svar /sdfr=df copernicus_state
	return copernicus_state
end


// Set the current experiment state
function set_state(state)
	string state
	dfref df = getstatusDF()
	svar /sdfr=df copernicus_state
	copernicus_state = state
end


// Generate an alert dialog
static function alert(msg, actions)
	string msg // Display this message
	string actions // Semicolon-separated list of actions (Igor commands)
						// to execute for each possible button press
	// If there is one action, the button title will be "OK"
	// If there are two actions, the button titles will be "Yes" and "No"
	// If there are three actions, the button titles will be "Yes", "No", and "Cancel"
	
	variable i
	string buttons
	for(i=0;i<itemsinlist(actions);i+=1)
		
	endfor
	variable n_actions = max(0, itemsinlist(actions)-1)
	DoAlert n_actions, msg
	string action = stringfromlist(v_flag-1,actions)
	Execute /Q/P action
end


