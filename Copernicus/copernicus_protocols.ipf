#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName=copernicus
static strconstant module=copernicus

static strconstant protocol_sequence_location = "root:parameters:copernicus:protocol_sequence"
static strconstant curr_protocol_location = "root:parameters:copernicus:curr_protocol"


function /wave get_protocol_sequence()
	dfref df = get_protocols_df()
	wave /z/t sequence = df:sequence_list
	if(!waveexists(sequence))
		wave /t sequence = make_protocol_sequence()
	endif
	return sequence
end

function /s get_protocol_order()
	wave /t sequence = get_protocol_sequence()
	string order = ""
	variable i
	for(i=0; i<dimsize(sequence, 0); i+=1)
		order += sequence[i][0] + ";"
	endfor
	return order
end

function /s get_curr_protocol()
	string curr_protocol = strvarordefault(curr_protocol_location, "")
	if(!strlen(curr_protocol))
		wave /t sequence = get_protocol_sequence()
		curr_protocol = sequence[0][0]
	endif
	return curr_protocol
end

function set_curr_protocol(protocol)
	string protocol
	if(whichlistitem(protocol, get_protocol_order()) < 0)
		string alert
		sprintf alert, "Protocol %s not in sequence", protocol
		DoAlert 0, alert
		return -1
	endif
	svar /z curr_protocol = $curr_protocol_location
	if(!svar_exists(curr_protocol))
		string /g $curr_protocol_location
		svar /z curr_protocol = $curr_protocol_location
	endif
	curr_protocol = protocol
	make_protocol_sequence_sw()
end

function /wave make_protocol_sequence()
	dfref df = get_protocols_df()
	make /o/t/n=(19,3) df:sequence_list /wave=sequence=""
	setdimlabel 0,-1,Protocol,sequence
	setdimlabel 1,0,Name,sequence
	setdimlabel 1,1,Repeats,sequence
	setdimlabel 1,2,Remaining,sequence
	
	// BEGIN SEQUENCE EDITING
	sequence[0][] = {{"AIBS_Ramp"}, {"1"}, {"1"}}
	sequence[1][] = {{"AIBS_Square_Suprathreshold"}, {"3"}, {"3"}}
	sequence[2][] = {{"AIBS_Square_Subthreshold"}, {"8"}, {"8"}}
	// END SEQUENCE EDITING
		
	variable i
	for(i=0; i<dimsize(sequence,0); i+=1)
		if(!strlen(sequence[i][0]))
			redimension /n=(i,3) sequence
			break
		endif
		string protocol = sequence[i][0]
		string stimuli_available = StimulusList()
		if(whichlistitem(protocol, stimuli_available) < 0)
			DoAlert 0, protocol+" is not an available stimulus protocol"
		endif
	endfor
	if(dimsize(sequence,0)==0)
		doalert 0, "Protocol Sequencer has no listed protocols"
	endif 
	set_protocol_order_labels()
	return sequence
end

function set_protocol_order_labels()
	wave /t sequence = get_protocol_sequence()
	variable i
	for(i=0; i<dimsize(sequence,0); i+=1)
		switch(i)
			case 0:
				setdimlabel 0,i,p1st,sequence
				break
			case 1:
				setdimlabel 0,i,p2nd,sequence
				break
			case 2:
				setdimlabel 0,2,p3rd,sequence
				break
			default:
				setdimlabel 0,i,$("p"+num2str(i)+"st"),sequence
		endswitch
	endfor
end

function /df get_protocols_df()
	return Core#PackageHome(module, "Protocols", create=1)
end

function view_protocol_sequence()
	wave sequence = get_protocol_sequence()
	dowindow /k protocol_sequence_viewer
	newpanel /k=1 /n=protocol_sequence_viewer as "Sequence Viewer"
	dfref df = get_protocols_df()
	make /o df:sequence_colors /wave=cw= {{65535, 65535, 65535}, {65535, 0, 0}}
	matrixtranspose cw
	wave sw = make_protocol_sequence_sw()
	ListBox protocol_sequence, listWave=sequence, selWave=sw, colorWave=cw
	ListBox protocol_sequence, proc=sequence_hook, fsize=18, font="Bahnschrift SemiBold Condensed"	
	resize_protocol_sequence(resize_window=1)
	//SetWindow protocol_sequence_viewer hook(events)=sequence_hook
end

function resize_protocol_sequence([resize_window])
	variable resize_window
	
	variable x, y
	protocol_sequence_sizer(x, y)
	ListBox protocol_sequence size={x+185, y}, widths={x, 78, 95}
	if(resize_window)
		GetWindow protocol_sequence_viewer wsize
		MoveWindow /w=protocol_sequence_viewer v_left, v_top, v_left+x+185, v_top+y
	endif
end

function protocol_sequence_sizer(x, y)
	variable &x, &y
	
	wave /t sequence = get_protocol_sequence()
	y = (dimsize(sequence, 0)+1) * 30
	variable i, longest = 0
	for(i=0;i<dimsize(sequence, 0);i+=1)
		longest = max(longest, strlen(sequence[i][0]))
	endfor
	x = longest*4 + 160
end

function /wave make_protocol_sequence_sw()
	dfref df = get_protocols_df()
	wave sequence = get_protocol_sequence()
	make /o/B/U/n=(dimsize(sequence,0), 3, 2) df:sequence_selector /wave=sw=0
	sw[][][0] = 2
	setdimlabel 2,1,foreColors,sw
	string curr_protocol = get_curr_protocol()
	findvalue /text=curr_protocol sequence
	if(v_value>=0)
		sw[v_value][][%foreColors] = 1
	endif	
	return sw
end

menu "sequence_edit_menu", contextualmenu, dynamic
	"Set as current", /Q, sequence_edit_handler()
	"Delete", /Q, sequence_edit_handler()
	"Move Up", /Q, sequence_edit_handler()
	"Move Down", /Q, sequence_edit_handler()
	Submenu "Replace"
		StimulusList(), /Q, sequence_edit_handler(operation="Replace")
	End
	Submenu "Insert above"
		StimulusList(), /Q, sequence_edit_handler(operation="Insert above")
	End
	Submenu "Insert below"
		StimulusList(), /Q, sequence_edit_handler(operation="Insert below")
	End
end

function sequence_edit_handler([operation])
	string operation
	variable row = str2num(GetUserData("protocol_sequence_viewer","","row"))
	
	wave /t sequence = get_protocol_sequence()
	wave /sdfr=getwavesdatafolderdfr(sequence) sw=sequence_selector
	
	GetLastUserMenuInfo
	if(paramisdefault(operation))
		operation = s_value
		string choice = sequence[row][0]
	else
		choice = s_value
	endif
	
	strswitch(operation)
		case "Set as current":
			string /g $curr_protocol_location=choice
			break
		case "Delete":
			DeletePoints /M=0 row, 1, sequence
			break
		case "Move up":
			if(row>0)
				string count = sequence[row][1]
				sequence[row][] = sequence[row-1][q]
				sequence[row-1][0] = choice
				sequence[row-1][1] = count
			endif
			break
		case "Move down":
			if(row<dimsize(sequence,0)-1)
				count = sequence[row][1]
				sequence[row][] = sequence[row+1][q]
				sequence[row+1][0] = choice
				sequence[row+1][1] = count
			endif
			break
		case "Replace":
			sequence[row][0] = choice
			break
		case "Insert above":
			InsertPoints /M=0 row, 1, sequence
			sequence[row][0] = choice
			sequence[row][1] = "1"
			sequence[row][2] = "1"
			break
		case "Insert below":
			InsertPoints /M=0 row+1, 1, sequence
			sequence[row+1][0] = choice
			sequence[row+1][1] = "1"
			sequence[row+1][2] = "1"
			break
	endswitch
	
	set_protocol_order_labels()
	make_protocol_sequence_sw()
	resize_protocol_sequence(resize_window=1)
end

function sequence_hook(info)
	struct WMListBoxAction &info
	switch(info.eventCode)
		case 4: // Selection
			if(info.eventMod & 16) // Right-click
				wave sequence = get_protocol_sequence()
				//menu_items = ""
				if(info.row >=0 && info.row < dimsize(sequence,0))
					SetWindow protocol_sequence_viewer, userData(row)=num2str(info.row)
					PopupContextualMenu /N "sequence_edit_menu"
				endif
			endif
			break
		case 7: // End edit
			validate_sequence()
			break
	endswitch
	
end

function validate_sequence()
	wave /t sequence = get_protocol_sequence()
	variable row
	for(row=0;row<dimsize(sequence,0);row+=1)
		string protocol = sequence[row][0]
		string num = sequence[row][1]
		if(whichlistitem(protocol, stimuluslist()) < 0)
			DoAlert 0, protocol+" is not an available stimulus protocol"
		endif
		if(str2num(num)<0 || numtype(str2num(num)))
			DoAlert 0, num+" is not a valid number of stimulus protocol repeats"
		endif
	endfor
end

function edit_protocol_sequence()
	wave sequence = get_protocol_sequence()
	dowindow /k protocol_sequence_editor
	edit /k=1 /n=protocol_sequence_editor sequence.ld as "Sequence Editor"
end

function auto_configure_stimulus()
	// For now, just a blank stimulus with a test pulse
	//wave test_pulse = Core#WavPackageSetting("Acq","stimuli",GetChanName(0),"testPulseOn")
	//test_pulse = 1
	do
		string curr_protocol = get_curr_protocol()
		variable remaining = get_remaining(curr_protocol)
		if(remaining==0)
			string next_protocol = get_next_protocol()
			if(strlen(next_protocol))
				set_curr_protocol(next_protocol)
			else
				// Out of protocols. Experiment is finshed.
				return 1
			endif
		else
			curr_protocol = get_curr_protocol()
			break
		endif
	while(1)
	SelectPackageInstance("stimuli", curr_protocol)
	SetAcqSetting("DAQs", "daq0", "sweepsLeft", num2str(remaining))
	return 0
end

function get_remaining(protocol)
	string protocol
	wave /t sequence = get_protocol_sequence()
	variable index = get_protocol_index(protocol)
	if(index >= 0)
		variable remaining = str2num(sequence[index][2])
	else
		alert_no_such_protocol(protocol)
	endif
	return remaining
end

function set_remaining(remaining [,protocol])
	variable remaining
	string protocol
	if(paramisdefault(protocol))
		protocol = get_curr_protocol()
	endif
	wave /t sequence = get_protocol_sequence()
	variable index = get_protocol_index(protocol)
	if(index >= 0)
		sequence[index][2] = num2str(remaining)
	else
		alert_no_such_protocol(protocol)
	endif
end

function alert_no_such_protocol(protocol)
	string protocol
	string str
	sprintf str, "No such protocol '%s'", protocol
	DoAlert 0, str
end

function get_protocol_index(protocol)
	string protocol
	wave /t sequence = get_protocol_sequence()
	variable i
	for(i=0; i<dimsize(sequence, 0); i+=1)
		if(stringmatch(sequence[i][0], protocol))
			return i
		endif
	endfor
	return -1
end

function /s get_next_protocol()
	wave /t sequence = get_protocol_sequence()
	variable i
	string next=""
	string curr_protocol = get_curr_protocol()
	for(i=0; i<dimsize(sequence, 0)-1; i+=1)
		if(stringmatch(sequence[i][0], curr_protocol))
			next = sequence[i+1][0]
			break
		endif
	endfor
	return next
end