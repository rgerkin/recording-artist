#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName=copernicus
static strconstant module=copernicus

// Upper left corner of status panel
static constant status_x=650
static constant status_y=0
static constant status_width=200
static constant status_height=305
static strconstant status_name=StatusPanel
static strconstant status_title="Status"

static strconstant seal_test_lineup_traces="Lineup the traces in the orange boxes"
static strconstant seal_test_resistance_low="Resistance too low; get a new electrode"
static strconstant seal_test_resistance_high="Resistance too high; get a new electrode"
static strconstant seal_test_find_cell="Target a cell; then provide negative pressure"
static strconstant seal_test_good_seal="Great seal; Now break in with suction"
static strconstant seal_test_good_breakin="Good break-in; now begin experiment"
static strconstant seal_test_bad_breakin="Bad break-in; get a new electrode"
static strconstant seal_test_noise_high="Too noisy; ground your rig"


function status_panel([rebuild])
	variable rebuild
	
	build_panel(rebuild,status_name,status_title,status_x,status_y,status_width,status_height)
	variable xx = 10
	variable yy = 10
	variable yJump = 45
	variable i
	for(i=0;i<3;i+=1)
		string str = stringfromlist(i,"Input;Access;Rest")
		string name = "Status_SealQuality_"+str
		Groupbox $"Groupbox_"+name, pos={xx-5,yy+yJump*i-5}, size={120,40}
		ValDisplay $name mode=1,limits={0,1,0.5},highColor=(2,39321,1),lowColor=(65535,0,0),zeroColor=(65535,65532,16385)
		ValDisplay $name pos={xx+55,yy+yJump*i}, size={50,25}, bodywidth=25, barmisc={0,0}, value=_NUM:0.3+0.3*i
		ValDisplay $name title="\Z20\F'Arial Black'"+str
	endfor
	Button Run, disable=1
end


// Check whether electrode parameters are in range during the seal test
function check_electrode_range()
	dfref df = SealTestInstanceDF()
	nvar /sdfr=df target_electrode_resistance, range_electrode_resistance, target_seal_resistance, max_noise
	dfref df = SealTestChanDF(0)
	nvar /sdfr=df inputRes, timeConstant, leak, noise
	variable target = 5000 / target_electrode_resistance
	variable delta = target*range_electrode_resistance
	string state = get_state()
	strswitch(state)
		case "SealTest:Start":
			variable lower = target_electrode_resistance - target_electrode_resistance*range_electrode_resistance
			variable upper = target_electrode_resistance + target_electrode_resistance*range_electrode_resistance
			if(noise > max_noise)
				update_seal_test_message(seal_test_noise_high)
			elseif(inputRes < lower)
				update_seal_test_message(seal_test_resistance_low)
			elseif(inputRes > upper)
				update_seal_test_message(seal_test_resistance_high)
			elseif(leak > delta || leak < -delta)
				update_seal_test_message(seal_test_lineup_traces)
			else
				update_seal_test_message(seal_test_find_cell)
			endif
			break
		case "SealTest:Seal":
			if(inputRes > target_seal_resistance)
				update_seal_test_message(seal_test_good_seal)
				set_state("SealTest:Breakin")
			else
				update_seal_test_message(seal_test_find_cell)
				set_state("SealTest:Seal")
			endif	
			break
		case "SealTest:Breakin":
			//if(inputRes > target_seal_resistance)
			//	update_seal_test_message(seal_test_good_breakin)
			//else
			//	update_seal_test_message(seal_test_bad_breakin)
			//endif	
			string tc = num2str(timeConstant)
			if(numtype(timeconstant))
				update_seal_test_message(seal_test_good_seal)
			else
				update_seal_test_message("Time constant is %d ms")
			endif
			break
		default:
			update_seal_test_message("State unhandled!")			
	endswitch
end


// Update the message in the Seal Test window
function update_seal_test_message(msg)
	string msg
	SetVariable message win=SealTestWin, value=_STR:msg
	strswitch(msg)
		case seal_test_find_cell:
			Button Baseline_0 disable=0, win=SealTestWin
			break
		default:
			Button Baseline_0 disable=2, win=SealTestWin
			break
	endswitch
end


// Update the message in the Data window
function update_data_message(msg)
	string msg
	SetVariable message win=DataWin, value=_STR:msg
end


function compute_input_resistance()
	wave w = root:parameters:Acq:DAQs:daq0:input_0
	variable tps = Core#VarPackageSetting("Acq","AcqModes","VC","testPulseStart")
	variable tpl = Core#VarPackageSetting("Acq","AcqModes","VC","testPulseLength")
	variable tpa = Core#VarPackageSetting("Acq","AcqModes","VC","testPulseAmpl")
	variable baseline = mean(w,0,tps-0.001)
	variable pulse_depth = mean(w,tps+tpl-0.25*tpl,tps+tpl-0.001)
	variable r_in = 1000*tpa / abs(baseline - pulse_depth)
	variable quality = 1/(1+exp((-r_in+50)/10))
	//print r_in, quality
	ValDisplay status_sealquality_input value=_NUM:quality, win=StatusPanel
	//print(r_in)
end