#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function Optimus1_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	if(!exists("root:sharedE"))
		variable activeWidth=GetStimParam("Width",chan,0,sweep_num = sweep_num)
#if exists("MakeSharedInputs1")
		MakeSharedInputs1()
#else
		DoAlert 0,"You need to get the function MakeSharedInputs() first!  Ask Rick."
		abort
#endif
	endif
	string DAQ=MasterDAQ()
	dfref df=GetDAQdf(DAQ)
	variable /g df:reassemble=1 // Reassemble the stimulus each sweep.  
	variable sampling=50000 // In dynamic clamp, must sample at 50000 Hz due to hardware.  
	variable kHz=sampling/1000
	wave w_num_pulses = GetNumPulses(chan,sweepNum = sweep_num)
	variable numPulses = w_num_pulses[pulseSet]
	if(mod(pulseSet,3)!=0) // If not pulse set 0, i.e. not the bias, i.e. E or I.  
		//wave sharedE=root:sharedE, sharedI=root:sharedI
		variable ampl=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)
		variable dAmpl=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
		variable begin=GetStimParam("Begin",chan,pulseSet,sweep_num = sweep_num)
		activeWidth=GetStimParam("Width",chan,pulseSet,sweep_num = sweep_num)
		variable width=lastSample-firstSample
		variable start=begin*kHz+abs(enoise(activeWidth*kHz))
		Stimulus[start,start][sweepParity]+=1
		variable pulses=GetStimParam("Pulses",chan,pulseSet,sweep_num = sweep_num)
		variable length=dimsize(Stimulus,0)
		if(pulseNum==numPulses-1)
			wave alpha=AlphaSynapso(ampl+dampl*pulseNum,width/kHz,0,width*10/kHz)
			start=begin*kHz
			variable finish=(begin+activeWidth)*kHz-1
			strswitch(nameofwave(Stimulus))
				case "eWave":
					wave /z sharedE=root:sharedE
					Stimulus[start,finish]+=sharedE[p-start]
					break
				case "iWave":
					wave /z sharedI=root:sharedI
					Stimulus[start,finish]+=sharedI[p-start]
					break
			endswitch
			Convolve2(alpha,Stimulus,col=sweepParity)
		endif
		Redimension /n=(length,-1) Stimulus
	else // For the bias, do the normal stuff.  
		Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num = sweep_num)
	endif
end

// Auxiliary function for Optimus1_stim
static Function MakeSharedInputs1()
	variable ePulses=GetStimParam("Pulses",0,1)
	variable iPulses=GetStimParam("Pulses",0,2)
	variable activeWidth=GetStimParam("Width",0,0)/1000 // In seconds.  
	variable eRate=ePulses/activeWidth
	variable iRate=iPulses/activeWidth
	setdatafolder root:
	make /o/n=(activeWidth*50000) sharedE,sharedI
	SetScale x,0,activeWidth,sharedE,sharedI
	sharedE=poissonnoise(eRate/50000)
	sharedI=poissonnoise(iRate/50000)
End

function Optimus2_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity[,sweep_num])
	wave Stimulus
	variable chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num
	
	sweep_num = paramisdefault(sweep_num) ? GetCurrSweep() : sweep_num
	
	string stimName=GetStimulusName(chan)
	if(!exists("root:"+stimName+"_sharedE") || !exists("root:"+stimName+"_sharedE"))
		MakeSharedInputs2(stimName)
	endif
	string DAQ=MasterDAQ()
	dfref df=daqDF
	variable /g df:reassemble=1 // Reassemble the stimulus each sweep.  
	variable sampling=50000 // In dynamic clamp, must sample at 50000 Hz due to hardware.  
	variable kHz=sampling/1000
	nvar /sdfr=daqDF numPulses
	if(mod(pulseSet,3)!=0) // If not pulse set 0, i.e. not the bias, i.e. E or I.  
		//wave sharedE=root:sharedE, sharedI=root:sharedI
		variable ampl=GetStimParam("Ampl",chan,pulseSet,sweep_num = sweep_num)
		variable dAmpl=GetStimParam("dAmpl",chan,pulseSet,sweep_num = sweep_num)
		variable begin=GetStimParam("Begin",chan,0,sweep_num = sweep_num)
		variable activeWidth=GetStimParam("Width",chan,0,sweep_num = sweep_num)
		variable width=lastSample-firstSample
		variable start=begin*kHz+abs(enoise(activeWidth*kHz))
		Stimulus[start,start][sweepParity]+=1
		variable pulses=GetStimParam("Pulses",chan,pulseSet,sweep_num = sweep_num)
		variable length=dimsize(Stimulus,0)
		if(pulseNum==numPulses-1)
			nvar /z/sdfr=root: useShared,poissonOnly
			if(!nvar_exists(useShared) || useShared)
				start=begin*kHz
				variable finish=(begin+activeWidth)*kHz-1
				variable sweepIndex=CtrlNumValue("sweepIndex",win="SweepIndexWin")
				wave /z/sdfr=root: sharedE=$(stimName+"_sharedE"), sharedI=$(stimName+"_sharedI")
				strswitch(nameofwave(Stimulus))
					case "eWave":
						Stimulus[start,finish]+=sharedE[p-start][sweepIndex]
						break
					case "iWave":
						Stimulus[start,finish]+=sharedI[p-start][sweepIndex]
						break
				endswitch
			endif
			if(!nvar_exists(poissonOnly) || !poissonOnly)
				wave alpha=AlphaSynapso(ampl+dampl*pulseNum,width/kHz,0,width*10/kHz)
				Convolve2(alpha,Stimulus,col=sweepParity)
			endif
		endif
		Redimension /n=(length,-1) Stimulus
	else // For the bias, do the normal stuff.  
		Default_stim(Stimulus,chan,firstSample,lastSample,pulseNum,pulseSet,sweepParity,sweep_num = sweep_num)
	endif
end

// Auxiliary function for Optimus2_stim
function MakeSharedInputs2(stimName)
	string stimName
	
	variable chan=DAC2Chan("0")
	dfref df=root:ITC
	wave /sdfr=df eWave,iWave
	variable i
	variable begin=GetStimParam("Begin",chan,0)
	variable kHz=50
	variable activeWidth=GetStimParam("Width",chan,0)
	make /o/n=(kHz*activeWidth,100) root:$(stimName+"_sharedE") /wave=sharedE,root:$(stimName+"_sharedI") /wave=sharedI
	variable /g root:useShared=0, root:poissonOnly=1
	for(i=0;i<dimsize(sharedE,1);i+=1)
		prog("Shared",i,dimsize(sharedE,1))
		Assemble(chan,eWave,triparity=1)
		Assemble(chan,iWave,triparity=2)
		sharedE[][i]=eWave[p+begin*kHz]
		sharedI[][i]=iWave[p+begin*kHz]
	endfor
	variable /g root:useShared=1,root:poissonOnly=0
	newpath /o/q desktop specialdirpath("Desktop",0,0,0)
	save /p=desktop sharedE as stimName+"_sharedE_"+Timestamp()+".ibw"
	save /p=desktop sharedI as stimName+"_sharedI_"+Timestamp()+".ibw"
end