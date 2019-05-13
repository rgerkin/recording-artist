#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

static strconstant module="Acq"

static function rheobase_val()
	return numvarordefault("root:parameters:copernicus:rheobase_val", 0)
end

static function rheobase_relative()
	return numvarordefault("root:parameters:copernicus:rheobase_rel", 0)
end

// Stimulus assembler prototype.  
Function Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	variable ampl=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)
	ampl += rheobase_relative()*rheobase_val()
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
	Stimulus[firstSample,lastSample][sweepParity] += ampl+dampl*pulseNum
End

// Convolves stimulus with an alpha function mimicking a synaptic current or potential
function Alpha_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	variable ampl=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)
	ampl += rheobase_relative()*rheobase_val()
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
	Stimulus[firstSample,lastSample][sweepParity] += ampl+dampl*pulseNum
	variable pulses=GetStimParam("Pulses",chan,pulseSet,sweep_num = sweep_num)
	if(pulseNum==pulses-1)
		wave template = AlphaSynapso(1,3,0,50)
		Convolve2(template,Stimulus,col=sweepParity)
	endif
end

// Convolves stimulus with a template
function Template_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	variable ampl=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)
	rheobase_relative()*rheobase_val()
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
	//variable begin = GetStimParam("Begin",chan,pulseSet,sweep_num = sweep_num)
	
	Stimulus[firstSample][sweepParity] += ampl+dampl*pulseNum // Pulse of only one sample, to be convolved below.  
	variable pulses=GetStimParam("Pulses",chan,pulseSet,sweep_num = sweep_num)
	if(pulseNum==pulses-1)
		wave /z template=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"template")
		if(waveexists(template))
			Convolve2(template,Stimulus,col=sweepParity)
		endif
	endif
end

// Distributes pulses according to Poisson statistics and then convolves with a template
function Poisson_Template_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	variable pulses=GetStimParam("Pulses",chan,pulseSet)
	if(pulseNum == pulses - 1)
		variable ampl=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)
		ampl += rheobase_relative()*rheobase_val()
		variable dAmpl=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
		variable begin = GetStimParam("Begin",chan,pulseSet,sweep_num = sweep_num)
		variable width = GetStimParam("Width",chan,pulseSet,sweep_num = sweep_num)
		variable delta_x = dimdelta(Stimulus,0)
		make /free/n=(pulses) locs=abs(enoise(0.001*width/delta_x))
		locs += 0.001*begin/delta_x
		variable i
		for(i=0;i<numpnts(locs);i+=1)
			Stimulus[floor(locs[i])][sweepParity] += ampl+dampl*i
		endfor
		wave /z template=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"template")
		if(waveexists(template))
			Convolve2(template,Stimulus,col=sweepParity)
		endif
	endif
end

// Adds gaussian noise to the stimulus
function Noisy_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num = sweep_num)
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
	Stimulus[firstSample,lastSample][sweepParity] += gnoise(dAmpl)
end

// Adds pink noise to the stimulus
function Pink_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num = sweep_num)
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
	if(rheobase_relative())
		variable ampl=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)
		dAmpl = dAmpl * (ampl+rheobase_val())/ ampl
	endif
	duplicate /o PinkNoise(lastSample-firstSample+1, 1, dAmpl) pink
	Stimulus[firstSample,lastSample][sweepParity] += pink[p-firstSample]
end


// Adds gaussian noise to the stimulus and then convolves with an alpha function
function Noisy_Alpha_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num = sweep_num)
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
	variable pulses=GetStimParam("Pulses",chan,pulseSet)
	Stimulus[firstSample,lastSample][sweepParity] += gnoise(dAmpl)
	if(pulseNum==pulses-1)
		wave template = AlphaSynapso(1,3,0,50)
		Convolve2(template,Stimulus,col=sweepParity)
	endif
end

// Applies a frozen stimulus
function Frozen_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	variable multiplier=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
	SetStimParam("dAmpl",chan,pulseSet,0,sweep_num = sweep_num) // Set dAmpl to be 0 because we are not using this parameter as intended in Default_stim.  
	Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num = sweep_num)
	SetStimParam("dAmpl",chan,pulseSet,multiplier,sweep_num = sweep_num) // Set it back to its original value.  
	wave /z frozen=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"frozen")
	if(waveexists(frozen))
		lastSample = min(lastSample,firstSample+numpnts(frozen)-1) // Only extend to the end of the pulse or the end of the frozen wave, whichever comes first.  
		Stimulus[firstSample,lastSample][sweepParity] += multiplier*frozen[p-firstSample][sweepParity]
	endif
end

// Distributes pulses according to Poisson statistics and then convolves with an alpha function
function Poisson_Alpha_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	variable ampl=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)
	variable dAmpl=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
	variable width=lastSample-firstSample
	variable start=abs(enoise(dimsize(Stimulus,0)))
	Stimulus[start,start+width][sweepParity] += ampl+dampl*pulseNum
	variable pulses=GetStimParam("Pulses",chan,pulseSet,sweep_num = sweep_num)
	if(pulseNum==pulses-1)
		wave template = AlphaSynapso(1,3,0,50)
		Convolve2(template,Stimulus,col=sweepParity)
	endif
end

// Uses stimulus parameters to construct a sine wave
function Sine_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	variable freq=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)		//Set frequency (Hz)
	variable ampl=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)		//Set amplitude
	variable kHz=GetKHz(MasterDAQ())
	variable start = firstSample/(1000*kHz)
	
	Stimulus[firstSample,lastSample][sweepParity] += ampl * sin(2*pi*(x-start)*freq)
end

// Uses stimulus parameters to construct a ramp
function Ramp_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	variable amplEnd=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)		//Set frequency (Hz)
	variable amplStart=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)		//Set amplitude
	variable kHz=GetKHz(MasterDAQ())
	variable start = firstSample/(1000*kHz)
	variable width = (lastSample-firstSample+1)/(1000*kHz)
	variable slope = (amplEnd-amplStart)/width
	
	Stimulus[firstSample,lastSample][sweepParity] += amplStart + slope*(x-start)
end

// Map assembler names to values in the menu
function /s AssemblerNames(name)
	string name
	
	strswitch(name)
		case "DefaultPlusNegative":
			return "Default + Negative/4"
			break
		case "FrozenPlusNegative":
			return "Frozen + Negative"
			break
		default:
			return name
	endswitch
end

