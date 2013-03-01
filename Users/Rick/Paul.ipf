#pragma rtGlobals=1		// Use modern global access method.

// Formats data into a matrix. Requires odor_name and odor_code, which defines how e.g. "o1" maps onto an odor name.    
function TrialOdors(df[,epoch])
	dfref df
	variable epoch
	
	dfref currDF = getdatafolderdfr()
	setdatafolder df
	wave /t odor_name,odor_code
	dfref eventsDF = df:Events
	dfref eagDF = df:EAG
	if(!paramisdefault(epoch))
		dfref eagDF2 = eagDF:$("E"+num2str(epoch))
		eagDF = eagDF2
		dfref eventsDF2 = eventsDF:$("E"+num2str(epoch))
		eventsDF = eventsDF2
	endif
	wave /t/sdfr=eventsDF desc
	wave /sdfr=eventsDF times
	
	extract /o times,starts,stringmatch(desc[p],"*ms*") || stringmatch(desc[p],"*cont*")
	extract /o/t desc,durations,stringmatch(desc[p],"*ms*") || stringmatch(desc[p],"*cont*")
	extract /free/t desc,code1,stringmatch(desc[p+1],"*ms*") || stringmatch(desc[p+1],"*cont*")
	extract /free/t desc,code2,stringmatch(desc[p+2],"*ms*") || stringmatch(desc[p+2],"*cont*")
	duplicate /o/t code1,trial_odor_codes,trial_odor_names
	trial_odor_codes = selectstring(stringmatch(code2[p],"o*"),code1[p],code2[p]+";"+code1[p]) 
	variable i
	for(i=0;i<numpnts(trial_odor_names);i+=1)
		findvalue /text=trial_odor_codes[i] /txop=4 odor_code
		if(v_value==-1)
			print "Couldn't find "+trial_odor_codes[i]
		endif
		//print trial_odor_codes[i],v_value
		trial_odor_names[i] = odor_name[v_value]
	endfor
	
	wave /sdfr=eagDF times,data
	variable x_scale = dimdelta(data,0)
	variable n_pnts = ceil(1/x_scale)
	variable n_freqs = 10
	variable n_odors = ceil(numpnts(starts)/n_freqs)
	make /free/n=(n_pnts,n_freqs,n_odors) matrix
	setscale /p x,0,x_scale,matrix
	for(i=0;i<numpnts(starts);i+=1)
		variable index = binarysearch(times,starts[i])
		matrix[][mod(i,10)][floor(i/10)] = data[index+p]
	endfor
	if(paramisdefault(epoch))
		duplicate /o matrix $"matrix"
	else
		duplicate /o matrix $("matrix_"+num2str(epoch))
	endif
	setdatafolder currDF
end

function MakePeriodograms(df[,epoch,air_subtracted])
	dfref df
	variable epoch,air_subtracted
	
	dfref currDF = getdatafolderdfr()
	setdatafolder df
	if(air_subtracted)
		wave matrix = matrix_airsubtracted
	else
		if(paramisdefault(epoch))
			wave matrix
		else
			wave matrix = $("matrix_"+num2str(epoch))
		endif
	endif
	variable n_pnts = dimsize(matrix,0)
	variable n_freqs = dimsize(matrix,1)
	variable n_odors = dimsize(matrix,2)
	variable seg_length = round(n_pnts/5)
	seg_length -= mod(seg_length,2)==0 ? 0 : 1
	variable seg_overlap = round(seg_length*0.99)
	variable start = n_pnts/10
	variable i,j
	make /free/n=(1,n_freqs,n_odors) periodograms
	for(i=0;i<n_freqs;i+=1)
		prog("Freq",i,n_freqs)
		for(j=0;j<n_odors;j+=1)
			duplicate /free/r=[][i,i][j,j] matrix trial
			copyscales /p matrix,trial
			DSPPeriodogram /NODC=1 /Q /SEGN={(seg_length),(seg_overlap)} /R=[(start),(n_pnts)] /WIN=Hanning trial 
			wave w_periodogram
			redimension /n=(numpnts(w_periodogram),-1,-1) periodograms
			copyscales /p w_periodogram,periodograms
			periodograms[][i][j] = log(w_periodogram[p])
			//timefrequency(test,0.2,0.99,maxfreq=100)
		endfor
	endfor
	redimension /n=(200/dimdelta(periodograms,0),-1,-1) periodograms
	if(paramisdefault(epoch))
		duplicate /o periodograms $"periodograms"
	else
		duplicate /o periodograms $("periodograms_"+num2str(epoch))
	endif
	setdatafolder currDF
end

function RandomStim(duration)
	variable duration
	
	variable kHz = 1
	make /o/n=(1,2) stim2
	make /o/n=(1000*kHz*duration) stim
	setscale x,0,duration,stim
	variable state = 0
	variable t = 0
	variable count = 0
	do
		if(state == 0)
			variable off_duration = round(2+expnoise(8))
			stim[t*kHz,(t+off_duration)*kHz-1] = 0
			t += off_duration
			state = 1
		else
			variable on_duration = round(3+expnoise(7))
			stim[t*kHz,(t+on_duration)*kHz-1] = 1
			stim2[count][0] = {t}
			t += on_duration
			stim2[count][1] = on_duration
			count += 1
			state = 0
		endif
		//print t,state
	while(t<numpnts(stim))
end

function /wave MSequence(bits)
	variable bits
	
	variable n_words = 2^bits
	make /free/n=(n_words) words=p,randos=gnoise(1)
	sort randos,words
	make /o/n=(n_words,bits) m_sequence = (words[p] & 2^q)>0
	redimension /e=1/n=(n_words*bits) m_sequence
	return m_sequence
end

function MSequence2StartsDurations(m_sequence)
	wave m_sequence
	
	if(m_sequence[0])
		insertpoints 0,1,m_sequence
		m_sequence[0]=0
	endif
	findlevels /edge=1/q m_sequence,0.5
	duplicate /free w_findlevels ups
	if(m_sequence[numpnts(m_sequence)-1]==1)
		m_sequence[numpnts(m_sequence)]={0}
	endif
	findlevels /edge=2/q m_sequence,0.5
	duplicate /free w_findlevels downs
	killwaves w_findlevels
	make /o/n=(numpnts(ups),2) starts_durations
	starts_durations[][0] = ups[p]+0.5
	starts_durations[][1] = downs[p]-ups[p]
end

function DisplayMSequence(starts_durations)
	wave starts_durations
	
	make /o/n=(starts_durations[Inf][0]) broadband_stim = 0
	setscale /p x,0,1,broadband_stim
	variable i
	for(i=0;i<dimsize(starts_durations,0);i+=1)
		variable start = starts_durations[i][0]
		variable finish = starts_durations[i][0] + starts_durations[i][1] - 1
		broadband_stim[start,finish] = 1
	endfor
end

// Use if data and events have been chopped into epochs.  
function DisplayData(df)
	dfref df
	
	dfref eagDF = df:EAG
	dfref eventsDF = df:events
	variable epoch=0
	do
		dfref eagEpochDF = eagDF:$("E"+num2str(epoch))
		dfref eventsEpochDF = eventsDF:$("E"+num2str(epoch))
		if(datafolderrefstatus(eagEpochDF))
			wave /sdfr=eagEpochDF data,times
			wave event_times = eventsEpochDF:times
			variable start_index = binarysearch(times,event_times[0]) // Time of first epoch event (usually the beginning of the stimulus).    
			variable x_scale = dimdelta(data,0)
			display /k=1 data[start_index,start_index+10/x_scale] as "Signal for Epoch "+num2str(epoch) // Display 10 seconds of data.  
			dspperiodogram /db/nodc=1/segn={1000,900}/r=[(start_index+0.1/x_scale),(start_index+10/x_scale)]/win=Hanning data
			duplicate /o w_periodogram eagEpochDF:periodogram /wave=periodogram
			variable f_scale = dimdelta(periodogram,0)
			redimension /n=(200/f_scale) periodogram
			display /k=1 periodogram as "Power Spectrum for Epoch "+num2str(epoch) // Display 10 seconds of data.  
		else
			break
		endif
		epoch+=1
	while(epoch<100)
end

function Chop(df)
	dfref df
	
	dfref eagDF = df:EAG
	dfref eventsDF = df:Events
	NlxA#ExtractEvents("epochs",df=eventsDF)
	dfref epochsDF = eventsDF:epochs
	NlxA#ChopData(df:EAG,epochsDF=epochsDF)
	NlxA#ChopEvents(events=eventsDF) // Uses the epochs folder automatically.  
end

function MakeVTA(df[,epoch,t_min,t_max,e_min,e_max,condition,nth,resampled,invert]) // Valve-triggered average. 
	dfref df
	variable epoch,resampled,invert,nth,t_min,t_max,e_min,e_max
	string condition
	
	dfref currDF = getdatafolderdfr()
	dfref eagDF = df:EAG
	dfref eventsDF = df:Events
	
	// Set defaults.  
	if(!paramisdefault(epoch))
		dfref eagDF2 = eagDF:$("E"+num2str(epoch))
		eagDF = eagDF2
		dfref eventsDF2 = eventsDF:$("E"+num2str(epoch))
		eventsDF = eventsDF2
	endif
	if(!paramisdefault(e_min))
		dfref e_minDF = eagDF:$("E"+num2str(e_min))
		wave /sdfr=e_minDF times
		t_min = times[0]-1
	else
		t_min = paramisdefault(e_min) ? -Inf : e_min
	endif
	if(!paramisdefault(e_max))
		dfref e_maxDF = eagDF:$("E"+num2str(e_max))
		wave /sdfr=e_maxDF times
		t_max = times[numpnts(times)-1]+1
	else
		t_max = paramisdefault(t_max) ? Inf : t_max
	endif
	
	// Find valve-opening times.  
	wave /t/sdfr=eventsDF desc
	wave /sdfr=eventsDF times
	make /free/n=0 valve_open_times
	if(!paramisdefault(condition))
		variable i = 0, set = 0
		do
			variable rank = 0
			i = FindValue2T(desc,condition,start=i)
			do
				if(stringmatch(desc[i],"o*") || stringmatch(desc[i],"*ms*") || stringmatch(desc[i],"*cont*"))
					redimension /n=(max(dimsize(valve_open_times,0),rank+1),set+1) valve_open_times
					valve_open_times[rank][set] = times[i]
					rank += 1
				endif
				i += 1
			while(!stringmatch(desc[i+1],"*ms*") && !stringmatch(desc[i+1],"*cont*") && i<numpnts(desc))
			set += 1
		while(i<numpnts(desc))
	else
		rank = 0
		do
			if(stringmatch(desc[i],"o*"))
				redimension /n=(max(dimsize(valve_open_times,0),rank+1),1) valve_open_times
				valve_open_times[rank][0] = times[i]
				rank += 1
			endif
			i+=1
		while(i<numpnts(desc))
	endif
	variable n_opens = dimsize(valve_open_times,0)
	variable n_sets = max(1,dimsize(valve_open_times,1))
	printf "%d candidates... ", n_opens*n_sets
	
	// Filtering.  
	wave /sdfr=eagDF data,times
	variable x_scale = dimdelta(data,0)
	duplicate /free data,copy
	variable median_width = round(0.001/x_scale)
	median_width += mod(median_width,2) == 0 ? 1 : 0
	smooth /m=0/dim=0 median_width,copy
	filteriir/dim=0 /lo=(500*x_scale) copy
	
	// Make the VT matrix.  
	variable n_pnts = 2000
	make /free/n=(n_pnts) matrix
	i = 0
	for(set=0;set<n_sets;set+=1)
		for(rank=0;rank<n_opens;rank+=1)
			if(!paramisdefault(nth) && nth>=0 && rank!=nth)
				continue
			endif
			variable t = valve_open_times[rank][set]
			if(t < t_min || t > t_max)
				continue
			endif
			variable index =binarysearch(times,t)
			redimension /n=(-1,i+1) matrix
			matrix[][i] = copy[index+p-n_pnts/2]
			i += 1
		endfor
	endfor
	printf "%d selected.\r", i
	setdatafolder eagDF
	
	// Upsample.  
	if(resampled)
		resample /up=(resampled)/dim=0 matrix
		x_scale /= resampled
		n_pnts *= resampled
	endif
	
	// Invert sign.  
	if(invert)
		matrix *= -1
	endif
	
	// Make VTA and errors from VT matrix.  
	matrixop /free vta = meancols(matrix^t)
	matrixop /free vta_sd = sqrt(varcols(subtractmean(matrix,1)^t))^t
	matrixop /free vta_sem = sqrt(varcols(subtractmean(matrix,1)^t)/numcols(matrix))^t
	setscale /p x,-n_pnts*x_scale/2,x_scale,matrix,vta,vta_sem,vta_sd
	variable avg = mean(vta)
	vta -= avg
	
	// Make final output waves.  
	string suffix1 = "", suffix2 = ""
	if(!paramisdefault(condition))
		suffix1 = "_"+condition
	endif
	if(!paramisdefault(nth) && nth>=0)
		suffix2 = "_"+num2str(nth)+"th"
	endif
	string suffix = suffix1 + suffix2
	duplicate /o vta,$cleanupname("vta"+suffix,0)
	duplicate /o vta_sd,$cleanupname("vta"+suffix+"_sd",0)
	duplicate /o vta_sem,$cleanupname("vta"+suffix+"_sem",0)
	
	setdatafolder currDF
end

function MergeVTAs(dfs[,condition,nth,pool_errors,merge_num])
	string dfs
	string condition
	variable nth
	variable pool_errors // Compute sd and sem as mean across sd/sem's rather than sd/sem across means.   
	variable merge_num
	
	dfref currDF = getdatafolderdfr()
	string suffix1 = "", suffix2 = ""
	if(!paramisdefault(condition))
		suffix1 = "_"+condition
	endif
	if(!paramisdefault(nth) && nth>=0)
		suffix2 = "_"+num2str(nth)+"th"
	endif
	string suffix = suffix1 + suffix2
	variable i
	newdatafolder /o root:merged
	merge_num = paramisdefault(merge_num) ? floor(abs(enoise(10000))) : merge_num
	newdatafolder /o/s root:merged:$("N"+num2str(merge_num))
	string /g sources = dfs
	make /o/n=0 vta,vta_sd,vta_sem
	for(i=0;i<itemsinlist(dfs);i+=1)
		string df_name = stringfromlist(i,dfs)
		if(stringmatch(df_name[0],":"))
			df_name = getdatafolder(1,currDF)+df_name[1,strlen(df_name)-1]
		endif
		dfref df = $df_name
		wave /sdfr=df vtai = $("vta"+suffix)
		wave /sdfr=df vtai_sd = $("vta"+suffix+"_sd")
		wave /sdfr=df vtai_sem = $("vta"+suffix+"_sem")
		concatenate {vtai},vta
		concatenate {vtai_sd},vta_sd
		concatenate {vtai_sem},vta_sem
	endfor	
	if(pool_errors)
		matrixop /o vta_sd = meancols(vta_sd^t)
		matrixop /o vta_sem = meancols(vta_sem^t)/sqrt(i)
	else
		matrixop /o vta_sd = sqrt(varcols(vta^t)^t)
		matrixop /o vta_sem = vta_sd/sqrt(i)
	endif
	matrixop /o vta = meancols(vta^t)
	copyscales vtai,vta,vta_sd,vta_sem
	printf "Merged into number %d\r" merge_num
	setdatafolder currDF
end

function /df String2DFRef(str)
	string str
	
	variable i
	for(i=0;i<itemsinlist(str,":");i+=1)
		string name = stringfromlist(i,str,":")
		if(i==0)
			dfref df = $(name+":")
		else
			dfref df2 = df:$name
			df = df2
		endif
	endfor
	return df
end

function /wave MakePeriodogram(df[,epoch,subtractEpoch,condition,no_save])
	dfref df
	variable epoch,subtractEpoch,no_save
	string condition
	
	dfref eagDF = df:EAG
	dfref eventsDF = df:Events
	if(!paramisdefault(epoch))
		dfref eagDF2 = eagDF:$("E"+num2str(epoch))
		eagDF = eagDF2
		dfref eventsDF2 = eventsDF:$("E"+num2str(epoch))
		eventsDF = eventsDF2
	endif
	if(!datafolderrefstatus(eagDF))
		printf "No folder found.\r"
		return null
	endif
	wave eag_times = eagDF:times
	wave event_times = eventsDF:times
	if(paramisdefault(condition))
		variable first = 0
		variable last = numpnts(event_times)-2
		condition = ""
	else
		wave /t/sdfr=eventsDF desc
		findvalue /txop=4/text=condition desc
		if(v_value<0)
			print "Couldn't find "+condition
		endif
		first = v_value
		extract /free/indx desc,index,stringmatch(desc[p],"*ms*") || stringmatch(desc[p],"*cont*") && p>first
		last = index[0]-2
	endif
	//print first,last,numpnts(event_times)
	variable start = binarysearch(eag_times,event_times[first])
	variable stop = binarysearch(eag_times,event_times[last])
	wave /sdfr=eagDF data
	if((stop-start)<1)
			printf "Periodogram failed for %s.\r",getdatafolder(1,eagDF)
			return null
	endif
	dspperiodogram /nodc=1/segn={1000,900}/r=[(start),(stop)]/win=Hanning data
	wave w_periodogram
	if(!no_save)
		string name = "periodogram"+selectstring(strlen(condition),"","_"+condition)
		print name
		duplicate /o w_periodogram,eagDF:$name /wave=periodogram
	else
		wave periodogram = w_periodogram
	endif
	if(!paramisdefault(subtractEpoch))
		wave background = MakePeriodogram(df,epoch=subtractEpoch,condition=condition,no_save=1)
		periodogram /= background
	endif
	return periodogram
end

function MergePeriodograms(dfs[,condition,merge_num])
	string dfs
	variable merge_num
	string condition
	
	dfref currDF = getdatafolderdfr()
	variable i
	newdatafolder /o root:merged
	merge_num = paramisdefault(merge_num) ? floor(abs(enoise(10000))) : merge_num
	newdatafolder /o/s root:merged:$("N"+num2str(merge_num))
	string /g sources = dfs
	make /o/n=0 periodogram
	for(i=0;i<itemsinlist(dfs);i+=1)
		string df_name = stringfromlist(i,dfs)
		if(stringmatch(df_name[0],":"))
			df_name = getdatafolder(1,currDF)+df_name[1,strlen(df_name)-1]
		endif
		dfref df = $df_name
		if(!datafolderrefstatus(df))
			df = $("root:"+df_name)
		endif
		wave /sdfr=df periodogrami = $("periodogram"+selectstring(paramisdefault(condition),"_"+condition,""))
		concatenate {periodogrami},periodogram
	endfor	
	matrixop /o periodogram_sd = sqrt(varcols(periodogram^t)^t)
	matrixop /o periodogram_sem = periodogram_sd/sqrt(i)
	matrixop /o periodogram = meancols(periodogram^t)
	copyscales periodogrami,periodogram,periodogram_sd,periodogram_sem
	printf "Merged into number %d\r" merge_num
	setdatafolder currDF
end

function DisplayVTA(df[,epoch,condition,nth,error,lines])
	dfref df
	string condition,error
	variable epoch,nth,lines
	
	if(!paramisdefault(epoch))
		dfref df2 = df:$("E"+num2str(epoch))
		df = df2
	endif
	error = selectstring(!paramisdefault(error),"sem",error)
	string suffix1 = "", suffix2 = ""
	if(!paramisdefault(condition))
		suffix1 = "_"+condition
	endif
	if(!paramisdefault(nth) && nth>=0)
		suffix2 = "_"+num2str(nth)+"th"
	endif
	string suffix = suffix1 + suffix2
	wave /sdfr=df vta = $cleanupname("vta"+suffix,0)
	
	if(!lines)
		ShadedErrorBars(vta,kind=error)
	else
		DrawAction delete
	endif
	SetAxis bottom -0.002,0.050
	ModifyGraph prescaleExp(bottom)=3
	Label bottom "Time since valve trigger (ms)"
	Label left "Signal strength (\F'Symbol'm\F'Default'V)"
	modifygraph offset={0,-vta(0)}
	modifygraph fsize=14,fstyle=1
	ModifyGraph manTick(bottom)={0,10,0,0}
	ModifyGraph zero(bottom)=1
	wavestats /q/r=(0,0.025) vta
	variable peak = v_max, peak_x = v_maxloc
	setdrawenv xcoord=bottom,dash=3,save
	//tag /p=1/x=10/y=0 $nameofwave(vta),peak_x,"\Z14Peak"
	drawline peak_x,0,peak_x,1
	differentiate /meth=1 vta /d=d_vta
	wavestats /q/r=(0,peak_x) d_vta
	findlevel /q/r=(0,peak_x) d_vta,v_max/10
	variable onset = vta(v_levelx), onset_x = v_levelx
	//tag /p=1/x=-10/y=10 $nameofwave(vta),v_levelx,"\Z14Onset"
	drawline onset_x,0,onset_x,1
	findlevel /q/r=(onset_x,peak_x) vta,onset+0.1*(peak-onset)
	variable x_10 = v_levelx
	//tag /p=1/x=-10/y=20 $nameofwave(vta),v_levelx,"\Z1410%"
	setdrawenv xcoord=bottom,dash=2,save
	drawline x_10,0,x_10,1
	findlevel /q/r=(onset_x,peak_x) vta,onset+0.9*(peak-onset)
	variable x_90 = v_levelx
	//tag /p=1/x=-10/y=5 $nameofwave(vta),v_levelx,"\Z1490%"
	drawline x_90,0,x_90,1
	string /g df:info
	svar /sdfr=df info
	sprintf info,"Onset:%f;10:%f;90:%f;Peak:%f;",onset_x,x_10,x_90,peak_x
	string name = getdatafolder(1,df)
	name = removeending(removefromlist("merged:root",name,":"),":")
	dowindow /t kwtopwin name
	print onset_x,x_10,x_90,peak_x
end

function DisplayPeriodograms(dfs)
	wave /df dfs
	
	display //as getdatafolder(0,df)
	string legend_str = ""
	variable i
	for(i=0;i<numpnts(dfs);i+=1)
		dfref dfi = dfs[i]
		wave /sdfr=dfi periodogram
		ShadedErrorBars(periodogram,append_=1)
		//legend_str += "\\s(odor"+epoch+") Odor "+epoch+"\r"
	endfor
	legend /j/n=legend0 legend_str
	modifygraph log=1,lsize=3,fsize=14,fstyle=1,zero(left)=4//,axisEnab(right)={0,0.4}
	string traces = tracenamelist("",";",1)
	for(i=0;i<=itemsinlist(traces);i+=1)
		string trace = stringfromlist(i,traces)
		if(stringmatch(trace,"*_high*") || stringmatch(trace,"*_low*"))
			modifygraph lsize($trace)=0
		endif
	endfor
	//setaxis right 0.5,100
	label left "Power (\F'Symbol'm\F'Default'V\S2\M/Hz)"
	//label right "Ratio"
	label bottom "Frequency (Hz)"
end

//function DisplayPeriodograms(df,odorEpochs,airEpochs)
//	dfref df
//	wave odorEpochs,airEpochs
//	
//	dfref eagDF = df:EAG
//	display as getdatafolder(0,df)
//	string legend_str = ""
//	variable i
//	for(i=0;i<numpnts(odorEpochs);i+=1)
//		string epoch = num2str(odorEpochs[i])
//		dfref dfi = eagDF:$("E"+epoch)
//		wave /sdfr=dfi periodogram
//		variable red = 65535*(mod(i,3)==0)
//		variable green = 65535*(mod(i,3)==1)
//		variable blue = 65535*(mod(i,3)==2)
//		appendtograph /c=(red,green,blue) periodogram /tn=$("odor"+epoch)
//		if(i==0)
//			duplicate /o periodogram df:periodogram /wave=diff
//		else
//			diff += periodogram
//		endif
//		legend_str += "\\s(odor"+epoch+") Odor "+epoch+"\r"
//	endfor
//	diff /= i
//	for(i=0;i<numpnts(airEpochs);i+=1)
//		epoch = num2str(airEpochs[i])
//		dfref dfi = eagDF:$("E"+num2str(airEpochs[i]))
//		wave /sdfr=dfi periodogram
//		appendtograph /c=(0,0,0) periodogram /tn=$("air"+epoch)
//		if(i==0)
//			duplicate /free periodogram control
//		else
//			control += periodogram
//		endif
//		legend_str += "\\s(air"+epoch+") Air "+epoch+"\r"
//	endfor
//	control /= i
//	diff /= control
//	//modifygraph muloffset={0,0.001}
//	appendtograph /r/c=(20000,20000,20000) diff /tn=diff
//	legend_str += "\\s(diff) Ratio"
//	legend /j/n=legend0 legend_str
//	modifygraph log=1,lsize(diff)=3,fsize=14,fstyle=1,zero(left)=4,axisEnab(right)={0,0.4}
//	setaxis right 0.5,100
//	label left "Power (\F'Symbol'm\F'Default'V\S2\M/Hz)"
//	label right "Ratio"
//	label bottom "Frequency (Hz)"
//end

function /s ClearData([depth])
	variable depth
	
	string wave_list = ""
	dfref	df = getdatafolderdfr()
	variable n_folders = countobjectsdfr(df,4)
	variable i
	for(i=0;i<n_folders;i+=1)
		dfref dfi = df:$getindexedobjnamedfr(df,4,i)
		setdatafolder dfi
		wave_list += ClearData(depth = depth+1)
	endfor
	setdatafolder df
	variable n_waves = countobjectsdfr(df,1)
	string list = wavelist("data",";","")
	list += wavelist("times",";","")
	list += wavelist("epoch*",";","")
	for(i=0;i<itemsinlist(list);i+=1)
		string wave_name = stringfromlist(i,list)
		if(!stringmatch(wave_name,"*outwave*"))
			wave_list += getdatafolder(1,df)+wave_name+";"
		endif
	endfor
	if(depth == 0)
		for(i=0;i<itemsinlist(wave_list);i+=1)
			wave_name = stringfromlist(i,wave_list)
			wave w = $wave_name
			killwaves /z w
		endfor
	endif
	return wave_list
end

function StartsDurations2ValveStates(starts,durations)
	wave starts,durations
	
	make /o/n=(starts[Inf]+durations[Inf]) valve_states = 0
	variable i
	for(i=0;i<numpnts(starts);i+=1)
		valve_states[starts[i],starts[i]+durations[i]-1] = 1
	endfor
	return valve_states
end

function EventTimes2ValveStates(df,epoch)
	dfref df
	variable epoch
	
	dfref eventsDF_ = df:Events
	dfref eventsDF = eventsDF_:$("E"+num2str(epoch))
	dfref eagDF_ = df:EAG
	dfref eagDF = eagDF_:$("E"+num2str(epoch))
	wave /sdfr=eventsDF times
	wave /t/sdfr=eventsDF desc
	extract /free times,start_times,stringmatch(desc[p],"o*")
	extract /free times,end_times,stringmatch(desc[p],"TTL*")
	wave /sdfr=eagDF data
	variable x_scale = deltax(data)
	make /o/n=((end_times[Inf]-start_times[0])/x_scale) valve_states = 0
	setscale /p x,start_times[0],x_scale,valve_states
	variable i
	for(i=0;i<numpnts(start_times);i+=1)
		variable start = x2pnt(valve_states,start_times[i])
		variable end_ = x2pnt(valve_states,end_times[i])
		valve_states[start,end_-1] = 1
	endfor
end

function EventTimes2EAGSegment(df,epoch)
	dfref df
	variable epoch
	
	dfref eventsDF_ = df:Events
	dfref eventsDF = eventsDF_:$("E"+num2str(epoch))
	dfref eagDF_ = df:EAG
	dfref eagDF = eagDF_:$("E"+num2str(epoch))
	wave /sdfr=eventsDF times
	wave /t/sdfr=eventsDF desc
	extract /free times,start_times,stringmatch(desc[p],"o*")
	extract /free times,end_times,stringmatch(desc[p],"TTL*")
	wave /sdfr=eagDF data,times
	variable start = binarysearch(times,start_times[0])
	variable end_ = binarysearch(times,end_times[Inf])
	duplicate /o/r=[start,end_] data,segment
	setscale /p x,times(start),deltax(data),segment
end