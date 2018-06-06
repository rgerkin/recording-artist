#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#ifdef Acq
#include "Spike Functions"


Menu "Analysis", dynamic
	SubMenu "Triangle Alpha"
		UsedChannels(), /Q, CursorsTriangle("Alpha")
	End
	SubMenu "Triangle Beta"
		UsedChannels(), /Q, CursorsTriangle("Beta")
	End
	SubMenu "Rheobase"
		UsedChannels(), /Q, FIReport("Rheobase*")
	End
	SubMenu "FI"
		UsedChannels(), /Q, FIReport("FI_Plot")
	End
	SubMenu "Supra"
		UsedChannels(), /Q, SupraReport()
	End
	SubMenu "ThreeX"
		UsedChannels(), /Q, ThreeXReport()
	End
	SubMenu "TestPulse"
		UsedChannels(), /Q, TestPulseReport()
	End
End

Function FIReport(name[,channel])
	string channel,name
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
	sweeps = GetStimuliWithName(chan, name)
	if(!strlen(sweeps))
		DoAlert 0,"No sweeps with a stimulus name matching '"+name+"'"
	endif
	first_sweep = str2num(stringfromlist(0,sweeps))
	last_sweep = str2num(stringfromlist(itemsinlist(sweeps)-1,sweeps))
	variable begin = GetEffectiveStimParam("Begin",chan,sweepNum=first_sweep)/1000
	variable width = GetEffectiveStimParam("Width",chan,sweepNum=first_sweep)/1000
	if(stringmatch(name,"*alpha*") || stringmatch(name,"*beta*"))
		width = width/2
	endif
	Analyze(chan,chan,sweeps,analysisMethod=spike_method,x_left=begin,x_right=(begin+width))
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
		wave w = GetChanSweep(chan,rheobase_sweep)
		begin = GetEffectiveStimParam("Begin",chan,sweepNum=rheobase_sweep)
		width = GetEffectiveStimParam("Width",chan,sweepNum=rheobase_sweep)
		string folder = "root:"+possiblyquotename(channel)+":rheobase_spikes"
		Spikes(w=w,start=begin/1000,finish=(begin+width)/1000,folder=folder)
		dfref rheobaseDF = chanDF:rheobase_spikes
		CellSpikes(channel,first=rheobase_sweep,last=rheobase_sweep,folder=folder,rheobase=1,start=begin/1000,finish=(begin+width)/1000) 
		duplicate /free/r=[][0,0] Spike, Rate
		wavestats /q/r=[first_sweep,last_sweep] Rate
		variable ampl_with_max_spikes = Amplitude[v_maxloc]
		print v_max, ampl_with_max_spikes, max_ampl_no_spike
		variable slope = v_max/(ampl_with_max_spikes - max_ampl_no_spike)
		string str = ""
		if(stringmatch(name,"Rheo*"))
			sprintf str, "The rheobase current is %d %s (%d %s)", min_ampl_spike, units, max_ampl_no_spike, units
		elseif(stringmatch(name, "FI*"))
			sprintf str, "FI Curve Slope is %.3g", slope
		endif
		TextBox /A=LT str
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
	string sweeps = GetStimuliWithName(chan, "Supra*")
	first_sweep = str2num(stringfromlist(0,sweeps))
	last_sweep = str2num(stringfromlist(itemsinlist(sweeps)-1,sweeps))
	variable begin = GetEffectiveStimParam("Begin",chan,sweepNum=first_sweep)/1000
	variable width = GetEffectiveStimParam("Width",chan,sweepNum=first_sweep)/1000
	for(i=first_sweep;i<=last_sweep;i+=1)
		variable ampl = GetEffectiveAmpl(chan,sweepNum=i)
		if(ampl>supra_ampl_threshold)
			supra_sweeps += num2str(i)+";"
		endif
	endfor
	CellSpikes(channel,list=supra_sweeps,supra=1,start=begin,finish=begin+0.5) 
end

function ThreeXReport([channel])
	string channel
	
	if(paramisdefault(channel))
		GetLastUserMenuInfo
		channel = s_value
	endif
	
	string burst_sweeps = ""
	variable chan = Label2Chan(channel)
	variable first_sweep = GetCursorSweepNum("A")
	variable last_sweep = GetCursorSweepNum("B")
	string sweeps = GetStimuliWithName(chan, "X3X*")
	first_sweep = str2num(stringfromlist(0,sweeps))
	last_sweep = str2num(stringfromlist(itemsinlist(sweeps)-1,sweeps))
	variable begin = GetEffectiveStimParam("Begin",chan,sweepNum=first_sweep)/1000
	variable width = GetEffectiveStimParam("Width",chan,sweepNum=first_sweep)/1000
	variable i
	newdatafolder /o root:$(channel):ThreeXReportData
	dfref df = root:$(channel):ThreeXReportData
	dowindow /k ThreeXReportWin
	display /k=1/n=ThreeXReportWin
	variable num_sweeps = last_sweep - first_sweep + 1
	make /o/n=(100,num_sweeps) df:rate_mean /wave=rate_mean=nan
	variable max_points = 0
	for(i=first_sweep;i<=last_sweep;i+=1)
		wave w = GetChanSweep(chan,i)
		Spikes(w=w,folder=getdatafolder(1,df),start=begin,finish=begin+width)
		wave /sdfr=df ISI
		
		duplicate /o ISI df:$("rate_"+num2str(i)) /wave=rate_i
		if(numpnts(rate_i))
			rate_i = 1/rate_i
			appendtograph /c=(0,0,0) rate_i
			rate_mean[0,numpnts(rate_i)-1][i-first_sweep] = rate_i[p]
			max_points = max(max_points,numpnts(rate_i))
		endif
	endfor
	matrixop /o rate_mean = meancols(rate_mean^t)
	redimension /n=(max_points) rate_mean
	appendtograph /c=(65535,0,0) rate_mean
	ModifyGraph mode=4,marker=19
	Label bottom "ISI #"
	Label left "Instantaneous Firing Rate"
	Legend
end

function TestPulseReport([channel])
	string channel
	
	if(paramisdefault(channel))
		GetLastUserMenuInfo
		channel = s_value
	endif
	
	variable chan = Label2Chan(channel)
	// Change to name used for test pulse sweeps
	string test_pulse_stim_name = "*put_*"
	string sweeps = GetStimuliWithName(chan,test_pulse_stim_name) 
	if(itemsinlist(sweeps))
		wave w = AverageSweeps(chan,sweeps,show=1)
		variable sweep_num = str2num(stringfromlist(0,sweeps))
		variable begin = GetEffectiveStimParam("Begin",chan,sweepNum=sweep_num)/1000
		variable width = GetEffectiveStimParam("Width",chan,sweepNum=sweep_num)/1000
		variable ampl = GetEffectiveStimParam("Ampl",chan,sweepNum=sweep_num)
		string mode = GetAcqMode(chan,sweep_num=sweep_num)
		variable r_in = ComputeInputResistance(w,mode,ampl=ampl,baseline_left=begin-0.1,baseline_right=begin-0.01,input_left=begin+width-0.1,input_right=begin+width-0.01)
		variable tau = GetOneTau(w,begin,testPulseLength=width)
		variable c = tau/r_in
		string str
		sprintf str, "R_in = %.4g MOhms; Tau = %.3g ms; C = %.3g pF", r_in/1e6, tau*1000, c*1e12 
		TextBox str
	else
		printf "No sweeps found matching '%s'\r", test_pulse_stim_name
	endif
end

function /wave TriangleRange(chan,sweep_num)
	variable chan, sweep_num
	
	string stim_name = GetStimulusName(chan,sweep_num=sweep_num)
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
		case "Alpha":
			CursorPlace(w[0],(w[0]+w[1])/2)
			TriangleReport(chan,"alpha")
			CursorPlace((w[0]+w[1])/2,w[1])
			FIReport("triangular_pulse_alpha")
			break
		case "Beta":
			CursorPlace(w[0],(w[0]+w[1])/2)
			TriangleReport(chan, "beta")
			CursorPlace((w[0]+w[1])/2,w[1])
			break
	endswitch
end

function TriangleReport(chan, name[,channel])
	variable chan
	string name, channel
	
	if(paramisdefault(channel))
		GetLastUserMenuInfo
		channel = s_value
	endif
	dfref curr_df = getDataFolderDFR()
	dfref chanDF = GetChannelDF(channel)
	newdatafolder /o/s chanDF:Triangle
	//variable chan = Label2Chan(channel)
	string spike_methods = MethodList("Spike_Rate")
	string spike_method = stringfromlist(0,spike_methods)
	string sweeps
	sweeps = GetStimuliWithName(chan, name)
	if(!strlen(sweeps))
		DoAlert 0,"No sweeps with a stimulus name matching '"+name+"'"
	endif
	variable first_sweep = str2num(stringfromlist(0,sweeps))
	variable last_sweep = str2num(stringfromlist(itemsinlist(sweeps)-1,sweeps))
	variable begin = GetEffectiveStimParam("Begin",chan,sweepNum=first_sweep)/1000
	variable width = GetEffectiveStimParam("Width",chan,sweepNum=first_sweep)/1000
	if(stringmatch(name,"*alpha*") || stringmatch(name,"*beta*"))
		width = width/2
	endif
	Analyze(chan,chan,sweeps,analysisMethod=spike_method,x_left=begin,x_right=(begin+width))
	wave Spike = chanDF:$spike_method
	variable ampl = GetEffectiveAmpl(chan,sweepNum=first_sweep)
	dfref triangleDF = chanDF:Triangle
	wave /sdfr=triangleDF Peak,ISI
	display /k=1/n=FIWin ISI vs Peak
	ModifyGraph mode=4,marker=19,msize=5
	string acq_mode = GetAcqMode(chan)
	string units = GetModeOutputUnits(acq_mode)
	Label bottom, "Amplitude ("+units+")" 
	Label left, "Firing rate (Hz)"
	string str = ""
	TextBox /A=LT str
	setdatafolder curr_df
end

#endif