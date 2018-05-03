#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "Spike Functions"

Menu "Analysis", dynamic
	SubMenu "Triangle Up"
		UsedChannels(), /Q, CursorsTriangle("Up")
	End
	SubMenu "Triangle Down"
		UsedChannels(), /Q, CursorsTriangle("Down")
	End
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
	string sweeps
	sprintf sweeps,"%d,%d",first_sweep,last_sweep
	sweeps = ListExpand(sweeps)
	Analyze(chan,chan,sweeps,analysisMethod=spike_method)
	wave Spike = chanDF:$spike_method
	make /o/n=(total_sweeps) Amplitude=nan//,SpikeCount=nan,Frequency=nan
	variable i, rheobase_sweep=NaN, max_ampl_no_spike = -Inf, min_ampl_spike = Inf
	for(i=first_sweep;i<=last_sweep;i+=1)
		Amplitude[i] = GetEffectiveAmpl(chan,sweepNum=i)
		variable n_spikes = Spike[i][1]
		if(n_spikes>0 && Amplitude[i]<min_ampl_spike)
			min_ampl_spike = Amplitude[i]
			rheobase_sweep = i
		endif
		if(n_spikes==0 && Amplitude[i]>max_ampl_no_spike)
			max_ampl_no_spike = Amplitude[i]
		endif
	endfor
	for(i=first_sweep;i<=last_sweep;i+=1)
		Amplitude[i] = GetEffectiveAmpl(chan,sweepNum=i)
		if(Spike[i][1]>0 && Amplitude[i]<min_ampl_spike)
			min_ampl_spike = Amplitude[i]
		endif
		if(Spike[i][1]==0 && Amplitude[i]<min_ampl_spike)
			max_ampl_no_spike = Amplitude[i]
		endif
	endfor
	
	dowindow /k FIWin
	display /k=1/n=FIWin Spike[][0] vs Amplitude
	ModifyGraph mode=4,marker=19,msize=5
	string acq_mode = GetAcqMode(chan)
	string units = GetModeOutputUnits(acq_mode)
	Label bottom, "Amplitude ("+units+")" 
	Label left, "Firing rate (Hz)"
	//duplicate /free/r=[][0,0] Spike, rates
	//wavestats/q rates
	//variable max_rate = v_max
	//SetAxis left 0,max_rate*1.2
	//NewFreeAxis /R right1
	//ModifyFreeAxis right1, master=left
	//variable count = Spike[rheobase_sweep][1]
	//variable rate = Spike[rheobase_sweep][0]
	//variable duration = count/rate
	//SetAxis right1 0,max_rate*1.2*duration
	//Label right1, "Spike count"
	if(rheobase_sweep>-1)
		printf "The rheobase current is %d %s (%d %s).\r", min_ampl_spike, units, max_ampl_no_spike, units
		wave w = GetChanSweep(chan,rheobase_sweep)
		variable begin = GetEffectiveStimParam("Begin",chan,sweepNum=rheobase_sweep)
		variable width = GetEffectiveStimParam("Width",chan,sweepNum=rheobase_sweep)
		string folder = "root:"+possiblyquotename(channel)+":rheobase_spikes"
		Spikes(w=w,start=begin/1000,finish=(begin+width)/1000,folder=folder)
		dfref rheobaseDF = chanDF:rheobase_spikes
		CellSpikes(channel,first=rheobase_sweep,last=rheobase_sweep,folder=folder,rheobase=1) 
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
	CellSpikes(channel,list=supra_sweeps,supra=1) 
end

function /wave TriangleRange(chan,sweep_num)
	variable chan, sweep_num
	
	string stim_name = GetStimName(chan,sweep_num=sweep_num)
	if(!stringmatch(stim_name,"*tri*"))
		printf "Stimulus name '%s' for sweep %d may not be a triangle stimulus.", stim_name, sweep_num
	endif
	variable begin = GetEffectiveStimParam("Begin",chan,sweepNum=sweep_num)
	variable width = GetEffectiveStimParam("Width",chan,sweepNum=sweep_num)
	make /free/n=2 w = {begin/1000,(begin+width)/1000}
	return w
end

function CursorsTriangle(kind[,channel])
	string kind
	string channel
	
	if(paramisdefault(channel))
		GetLastUserMenuInfo
		channel = s_value
	endif
	variable chan = Label2Chan(channel)
	
	variable first_sweep = GetCursorSweepNum("A")
	wave w = TriangleRange(chan,first_sweep)
	strswitch(kind)
		case "Up":
			CursorPlace(w[0],(w[0]+w[1])/2)
			break
		case "Down":
			CursorPlace((w[0]+w[1])/2,w[1])
			break
	endswitch
end