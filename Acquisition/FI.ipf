#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "Spike Functions"

Menu "Analysis", dynamic
	SubMenu "FI"
		UsedChannels(), /Q, FIReport()
	End
	SubMenu "Supra"
		UsedChannels(), /Q, SupraReport()
	End
End

Function FIReport([channel])
	string channel
	if(paramisdefault(channel))
		GetLastUserMenuInfo
		channel = s_value
	endif
	dfref curr_df = getDataFolderDFR()
	dfref chanDF = GetChannelDF(channel)
	newdatafolder /o/s chanDF:FI
	variable chan = Label2Chan(channel)
	variable first_sweep = GetCursorSweepNum("A")
	variable last_sweep = GetCursorSweepNum("B")
	variable total_sweeps = GetCurrSweep()
	string spike_methods = MethodList("Spike_Rate")
	string spike_method = stringfromlist(0,spike_methods)
	wave Spike = chanDF:$spike_method
	make /o/n=(total_sweeps) Amplitude=nan//,SpikeCount=nan,Frequency=nan
	variable i, rheobase = Inf, rheobase_sweep=NaN
	for(i=first_sweep;i<=last_sweep;i+=1)
		Amplitude[i] = GetEffectiveAmpl(chan,sweepNum=i)
		if(Spike[i][1]>0 && Amplitude[i]<rheobase)
			rheobase = Amplitude[i]
			rheobase_sweep = i
		endif
		//variable duration = GetEffectiveStimParam("Width",chan,sweepNum=i)
		//SpikeCount[i] = 
		//Frequency[i] = SpikeCount[i]/duration
	endfor
	
	display /k=1 Spike[][0] vs Amplitude
	string acq_mode = GetAcqMode(chan)
	string units = GetModeInputUnits(acq_mode)
	//stim_units = Get 
	Label bottom, "Amplitude ("+units+")" 
	Label left, "Firing rate (Hz)"
	if(rheobase_sweep>-1)
		printf "The rheobase current is %d %s.\r", rheobase, units
		wave w = GetChanSweep(chan,rheobase_sweep)
		variable begin = GetEffectiveStimParam("Begin",chan,sweepNum=rheobase_sweep)
		variable width = GetEffectiveStimParam("Width",chan,sweepNum=rheobase_sweep)
		Spikes(w=w,start=begin,finish=begin+width,folder="root:"+channel+":rheobase_spikes")
		dfref rheobaseDF = chanDF:rheobase_spikes
		CellSpikes(channel,first=rheobase_sweep,last=rheobase_sweep) 
	else
		printf "No rheobase was found.\r"
	endif
	setdatafolder curr_df
End

function SupraReport([channel])
	string channel
	
	if(paramisdefault(channel))
		GetLastUserMenuInfo
		channel = s_value
	endif
	
	variable supra_ampl_threshold = 100
	string supra_sweeps = ""
	variable chan = Label2Chan(channel)
	variable first_sweep = GetCursorSweepNum("A")
	variable last_sweep = GetCursorSweepNum("B")
	variable i
	for(i=first_sweep;i<=last_sweep;i+=1)
		variable ampl = GetEffectiveAmpl(chan,sweepNum=i)
		if(ampl>supra_ampl_threshold)
			supra_sweeps += num2str(i)+";"
		endif
	endfor
	CellSpikes(channel,list=supra_sweeps) 
end
