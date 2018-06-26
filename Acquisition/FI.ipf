#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#ifdef Acq
#include "Spike Functions"


Menu "Analysis", dynamic
	SubMenu "Triangle Alpha"
		UsedChannels(), /Q, TriangleReport("Alpha")
	End
	SubMenu "Triangle Beta"
		UsedChannels(), /Q, TriangleReport("Beta")
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
	SubMenu "SagReport"
		UsedChannels(), /Q, SagReport()
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
		return -1
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

function TriangleReport(name[,channel])
	string name, channel
	
	if(paramisdefault(channel))
		GetLastUserMenuInfo
		channel = s_value
	endif
	dfref curr_df = getDataFolderDFR()
	dfref chanDF = GetChannelDF(channel)
	newdatafolder /o/s chanDF:Triangle
	dfref triangleDF = chanDF:Triangle
	variable chan = Label2Chan(channel)
	string spike_methods = MethodList("Spike_Rate")
	string spike_method = stringfromlist(0,spike_methods)
	string sweeps
	string match = "*triangular_pulse_"+name+"*"
	sweeps = GetStimuliWithName(chan, match)
	if(!strlen(sweeps))
		DoAlert 0,"No sweeps with a stimulus name matching '"+match+"'"
		return -1
	endif
	variable first_sweep = str2num(stringfromlist(0,sweeps))
	variable last_sweep = str2num(stringfromlist(itemsinlist(sweeps)-1,sweeps))
	variable begin = GetEffectiveStimParam("Begin",chan,sweepNum=first_sweep)/1000
	variable width = GetEffectiveStimParam("Width",chan,sweepNum=first_sweep)/1000
	variable ampl = GetEffectiveStimParam("Ampl",chan,sweepNum=first_sweep)
	make /o/n=(10000*(width/2)) current_up=0, current_down=0
	setscale /p x,0,0.0001,current_up,current_down
	current_up = ampl*(x/(width/2))
	current_down = ampl*(1-(x/(width/2)))
	duplicate /o current_up, triangleDF:rate_up /wave=rate_up
	duplicate /o current_down, triangleDF:rate_down /wave=rate_down
	rate_up = 0
	rate_down = 0
	variable i
	wave w = GetChanSweep(chan,first_sweep)
	
	Spikes(w=w,start=begin,finish=begin+width/2,folder=getdatafolder(1,triangleDF))
	wave /sdfr=triangleDF SpikeTimes=Peak_locs,ISI
	for(i=0;i<numpnts(SpikeTimes)-1;i+=1)
		variable p1 = (SpikeTimes[i]-begin)*10000
		//variable p2 = (SpikeTimes[i+1]-begin)*10000
		rate_up[p1,] = 1/(SpikeTimes[i+1]-SpikeTimes[i])
	endfor
	FindLevel /P/Q rate_up,0.0001
	variable up = current_up[v_levelx]
	
	Spikes(w=w,start=begin+width/2,finish=begin+width,folder=getdatafolder(1,triangleDF))
	wave /sdfr=triangleDF SpikeTimes=Peak_locs,ISI
	for(i=0;i<numpnts(SpikeTimes);i+=1)
		p1 = (SpikeTimes[i]-begin-width/2)*10000
		if(i==0)
			rate_down[0,p1-1] = rate_up[numpnts(rate_up)-1]
		endif
		//variable p2 = (SpikeTimes[i+1]-begin)*10000
		if(i==(numpnts(SpikeTimes)-1))
			rate_down[p1,] = 0
		else
			rate_down[p1,] = 1/(SpikeTimes[i+1]-SpikeTimes[i])
		endif
	endfor
	
	FindLevel /P/Q rate_down,0.0001
	variable down = current_down[v_levelx]
	
	string str
	sprintf str,"\K(65535,0,0)Current at recruitment is %d pA", up
	sprintf str,"%s\r\K(0,0,65535)Current at decruitment is %d pA", str, down
	dowindow /k TriangleWin
	display /k=1/n=TriangleWin/w=(0,0,700,400)
	appendtograph /c=(65535,0,0)/l=frequency /b=current_b rate_up vs current_up
	appendtograph /c=(0,0,65535)/l=frequency /b=current_b rate_down vs current_down
	ModifyGraph mode=4,marker=19,msize=2
	string acq_mode = GetAcqMode(chan)
	string output_units = GetModeOutputUnits(acq_mode)
	string input_units = GetModeInputUnits(acq_mode)
	Label current_b, "Current ("+output_units+")" 
	Label frequency, "Firing rate (Hz)"
	TextBox /A=RB/X=5.00/Y=0.00 str
	ModifyGraph mode=4,marker=19,msize=2
	legend /A=RB/X=12.50/Y=10.00
	//variable minn = 
	//string str
	//sprintf str, "R_in = %.4g MOhms; Tau = %.3g ms; C = %.3g pF", r_in/1e6, tau*1000, c*1e12 
	//TextBox str
	appendtograph /l=vm /b=time_ w
	duplicate /o w triangleDF:triangle /wave=tr
	tr = 0
	tr[x2pnt(tr,begin),x2pnt(tr,begin+width/2)] = 2*ampl*(x-begin)/width
	tr[x2pnt(tr,begin+width/2),x2pnt(tr,begin+width)] = 2*ampl*(begin+width-x)/width
	appendtograph /c=(0,0,0) /l=current_l /b=time_ tr
	ModifyGraph axisEnab(frequency)={0.5,1},axisEnab(current_b)={0.55,1}
	ModifyGraph axisEnab(vm)={0.5,1},axisEnab(time_)={0,0.45}
	ModifyGraph axisEnab(current_l)={0,0.45},freePos(frequency)={0.55,kwFraction}
	ModifyGraph freePos(current_b)={0.5,kwFraction},freePos(vm)={0,kwFraction}
	ModifyGraph freePos(time_)={0,kwFraction},freePos(current_l)={0,kwFraction}
	ModifyGraph lblPos(frequency)=50,lblPos(current_b)=50
	ModifyGraph lblPos(vm)=50,lblPos(current_l)=50,lblPos(time_)=50
	Label vm "Membrane Potential ("+input_units+")"
	Label current_l "Current ("+output_units+")"
	Label time_ "Time (s)"
	setdatafolder curr_df
end

function SagReport([channel])
	string channel
	
	if(paramisdefault(channel))
		GetLastUserMenuInfo
		channel = s_value
	endif
	
	variable chan = Label2Chan(channel)
	// Change to name used for test pulse sweeps
	string stim_name = "*put_*"
	string sweeps = GetStimuliWithName(chan,stim_name) 
	if(!itemsinlist(sweeps))
		string alert
		sprintf alert, "No sweeps found matching '%s'\r", stim_name
		DoAlert 0,alert
		return -1
	endif
	variable i
	dfref df = GetChanDF(chan)
	make /o/n=(itemsinlist(sweeps)) df:sag_i, df:sag_v_ss, df:sag_v_peak
	wave /sdfr=df sag_i, sag_v_ss, sag_v_peak
	for(i=0;i<itemsinlist(sweeps);i+=1)
		variable sweep_num = str2num(stringfromlist(i,sweeps))
		variable begin = GetEffectiveStimParam("Begin",chan,sweepNum=sweep_num)/1000
		variable width = GetEffectiveStimParam("Width",chan,sweepNum=sweep_num)/1000
		variable ampl = GetEffectiveStimParam("Ampl",chan,sweepNum=sweep_num)
		string mode = GetAcqMode(chan,sweep_num=sweep_num)
		string input_units = GetInputUnits(chan, sweep_num=sweep_num)
		string output_units = GetInputUnits(chan, sweep_num=sweep_num)
		wave w = GetChanSweep(chan, sweep_num)
		duplicate /free w, w_smooth
		smooth 5,w_smooth
		wavestats /q/r=(begin,begin+0.25) w_smooth
		sag_v_peak[i] = v_minloc
		wavestats /q/r=(begin+width-0.1,begin+width-0.001) w_smooth
		sag_v_ss[i] = v_avg
		sag_i[i] = ampl
	endfor
	dowindow /k SagWin
	display /k=1/n=SagWin
	appendtograph /c=(65535,0,0) sag_v_ss vs sag_i
	appendtograph /c=(0,0,65535) sag_v_peak vs sag_i
	ModifyGraph mode=4,marker=19,msize=2
	legend
	//variable minn = 
	//string str
	//sprintf str, "R_in = %.4g MOhms; Tau = %.3g ms; C = %.3g pF", r_in/1e6, tau*1000, c*1e12 
	//TextBox str
end

#endif