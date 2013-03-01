#pragma rtGlobals=1		// Use modern global access method.

function GetSpikes([threshold,refresh])
	variable refresh,threshold
	
	if(paramisdefault(threshold))
		controlinfo /w=AnalysisWin Parameter
		threshold=v_value
	endif
	
	variable start=GetCursorSweepNum("A")
	variable stop=GetCursorSweepNum("B")
	variable sweep
	wave sweepT=GetSweepT()
	dfref df=GetChannelDF("Patch")
	string /g df:type="nse"
	make /o/d/n=0 df:times /wave=times
	make /o/n=0 df:sweeps /wave=sweeps
	for(sweep=start;sweep<=stop;sweep+=1)
		Prog("Sweep",sweep-start,stop-start+1)
		wave w=GetChannelSweep("Patch",sweep)
		wave /z filtered=df:$("sweep"+num2str(sweep)+"_filtered")
		if(!waveexists(filtered) || refresh)
			duplicate /o w,df:$("sweep"+num2str(sweep)+"_filtered") /wave=filtered
			smooth /m=0 5,filtered
			variable kHz=0.001/dimdelta(w,0)
			StepFilter(filtered,threshold=1000*kHz,width=5) // Suppress and steps with instantaneous derivative greater than 10000*kHz over 5 samples.   
			BandPassFilter(filtered,Inf,500)//FilterIIR /HI=(500*dimdelta(filtered,0)) filtered
		endif
		duplicate /o filtered absFiltered
		absFiltered=abs(filtered)
		//if(sweep==1048)
		//	display /k=1 absfiltered
		//	abort
		//endif
		FindLevels /Q/EDGE=1/M=0.0025/R=[5,numpnts(w)-1] absFiltered,threshold
		wave w_findlevels
		extract /free w_findlevels,sweepSpikeTimes,abs(w_findlevels[p]-4)>0.01 && abs(w_findlevels[p]-6)>0.01
		
		variable startT=60*sweepT[sweep]
		sweepSpikeTimes+=startT
		concatenate /np {sweepSpikeTimes},times
		make /free/n=(numpnts(sweepSpikeTimes)) sweep_=sweep
		concatenate /np {sweep_},sweeps
		waveclear absFiltered
	endfor
	newdatafolder /o root:Events
	df=root:Events
	duplicate /o sweepT,df:times /wave=times
	times*=60
	times+=4
end

function SpikeShapes([df])
	dfref df
	
	if(paramisdefault(df))
		df=root:Patch
	endif
	wave /sdfr=df times,sweeps
	wave sweepT=GetSweepT()
	variable numSpikes=numpnts(times)
	variable spikeWindow=0.002 // Spike window (snippet) size in s.  
	variable kHz=50
	make /o/n=(spikeWindow*1000*kHz,numSpikes) df:spikeMatrix /wave=spikeMatrix  
	setscale x,-spikeWindow/2,spikeWindow/2,spikeMatrix
	make /o/n=(numSpikes,4) df:features /wave=features
	variable i,j
	for(i=0;i<numSpikes;i+=1)
		wave sweep=df:$("sweep"+num2str(sweeps[i])+"_filtered")
		variable startT=60*sweepT[sweeps[i]]
		variable t=times[i]-startT
		spikeMatrix[][i]=sweep(t+x)
		variable start=t-spikeWindow/2
		variable stop=t+spikeWindow/2-0.001/kHz
		wavestats /q/r=(start,stop) sweep
		features[i][0]=v_max
		features[i][1]=v_min
		features[i][2]=v_maxloc-v_minloc
		features[i][3]=v_rms^2
	endfor
	dowindow /k SpikeMatrixWin
	newimage /n=SpikeMatrixWin/k=1 root:patch:spikeMatrix
	ModifyImage spikeMatrix ctab= {-1,1,RedWhiteBlue,1}
	string featureList="Max;Min;Width;Energy"
	dowindow /k SpikeFeatureWin
	display /k=1/n=SpikeFeatureWin
	for(i=0;i<dimsize(features,1);i+=1)
		for(j=0;j<i;j+=1)
			appendtograph /l=$("left"+num2str(i)) /b=$("bottom"+num2str(j)) features[][i] vs features[][j]
			label $("left"+num2str(i)) stringfromlist(i,featureList)
			label $("bottom"+num2str(j)) stringfromlist(j,featureList)
		endfor
	endfor
	ModifyGraph mode=2,lsize=2
	ModifyGraph lblPos=90
	TileAxes(pad={0.1,0,0,0.1},box=1)
	AutoPositionWindow /R=SpikeMatrixWin
end
