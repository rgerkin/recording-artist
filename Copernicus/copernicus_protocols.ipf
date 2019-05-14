#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName=copernicus
static strconstant module=copernicus

static strconstant protocol_sequence_location = "root:parameters:copernicus:protocol_sequence"
static strconstant curr_protocol_location = "root:parameters:copernicus:curr_protocol"


function /wave get_protocol_sequence()
	wave /z/t sequence = $protocol_sequence_location
	if(!waveexists(sequence))
		wave /t sequence = make_protocol_sequence()
	endif
	return sequence
end

function /s get_curr_protocol()
	string curr_protocol = strvarordefault(curr_protocol_location, "")
	if(!strlen(curr_protocol))
		wave /t sequence = get_protocol_sequence()
		curr_protocol = sequence[0][0]
	endif
	return curr_protocol
end

function /wave make_protocol_sequence()
	make /o/t/n=(1,99) $protocol_sequence_location /wave=sequence=""
	setdimlabel 0,-1,Protocol,sequence
	setdimlabel 1,0,Name,sequence
	setdimlabel 1,1,Repeats,sequence
	
	// BEGIN SEQUENCE EDITING
	sequence[0][] = {{"AIBS_Ramp"}, {"1"}}
	sequence[1][] = {{"AIBS_Square_Suprathreshold"}, {"3"}}
	sequence[2][] = {{"AIBS_Square_Subthreshold"}, {"8"}}
	// END SEQUENCE EDITING
		
	variable i
	for(i=0; i<dimsize(sequence,0); i+=1)
		if(!strlen(sequence[i][0]))
			redimension /n=(i,2) sequence
			break
		endif
		string protocol = sequence[i][0]
		string stimuli_available = StimulusList()
		if(whichlistitem(protocol, stimuli_available) < 0)
			DoAlert 0, protocol+" is not an available stimulus protocol"
		endif
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
	if(dimsize(sequence,0)==0)
		doalert 0, "Protocol Sequencer has no listed protocols"
	endif 
	return sequence
end


function auto_configure_stimulus()
	// For now, just a blank stimulus with a test pulse
	//wave test_pulse = Core#WavPackageSetting("Acq","stimuli",GetChanName(0),"testPulseOn")
	//test_pulse = 1
	string curr_protocol = get_curr_protocol()
	SelectPackageInstance("stimuli",curr_protocol)
end