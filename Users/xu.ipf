#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

static strconstant module="Acq"

function FrozenPlusNegative_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	variable multiplier=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
	SetStimParam("dAmpl",chan,pulseSet,0,sweep_num = sweep_num) // Set dAmpl to be 0 because we are not using this parameter as intended in Default_stim.  
	Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num = sweep_num)
	SetStimParam("dAmpl",chan,pulseSet,multiplier,sweep_num = sweep_num) // Set it back to its original value.  
	string daq=Chan2DAQ(chan)
	variable IPI=GetStimParam("IPI",chan,pulseSet)
	variable numPulses=GetStimParam("pulses",chan,pulseSet)
	variable kHz=GetKHz(daq)
	wave /z frozen=Core#WavPackageSetting(module,"stimuli",GetChanName(chan),"frozen")
	if(waveexists(frozen))
		lastSample = min(lastSample,firstSample+numpnts(frozen)-1) // Only extend to the end of the pulse or the end of the frozen wave, whichever comes first.  
		Stimulus[firstSample,lastSample][sweepParity] += multiplier*frozen[p-firstSample][sweepParity]
		Stimulus[firstSample+numPulses*IPI*kHz,lastSample+numPulses*IPI*kHz][sweepParity] -= multiplier*frozen[p-firstSample-numPulses*IPI*kHz]
	endif
end

function DefaultPlusNegative4_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num = sweep_num)
	variable IPI=GetStimParam("IPI",chan,pulseSet,sweep_num = sweep_num)
	variable Ampl=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)
	variable numPulses=GetStimParam("Pulses",chan,pulseSet,sweep_num = sweep_num)
	string daq = MasterDAQ()
	variable kHz=GetKHz(daq)
	if(pulseSet==0 && pulseNum==(numPulses-1)) // Last pulse of first pulse set.  
		variable i
		for(i=0;i<NUM_LEAK_PULSES;i+=1)
			Stimulus[firstSample+(i+1)*kHz*IPI,lastSample+(i+1)*kHz*IPI][sweepParity][pulseSet]=-Ampl/NUM_LEAK_PULSES
		endfor
	endif
end