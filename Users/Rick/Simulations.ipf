#pragma rtGlobals=1		// Use modern global access method.

Function PowerLawDifferential()
	Make /o/D/n=1000000 PowerLawTest
	PowerLawTest[0]=1
	Variable i
	for(i=1;i<numpnts(PowerLawTest);i+=1)
		PowerLawTest[i]=PowerLawTest[i-1]+(0.02)*(100)*PowerLawTest[i-1]^(1-0.3)
	endfor
	//Display /K=1 PowerLawTest
	//ModifyGraph log=1
End

Function TestSurprise()
	Make /o/n=10 Iterations,MatchedIterations
	String events_name=UniqueName("Events",1,0),events_sem_name=UniqueName("Events_SEM",1,0),rates_name=UniqueName("Rates",1,0)
	String matched_events_name=UniqueName("MatchedEvents",1,0),matched_events_sem_name=UniqueName("MatchedEvents_SEM",1,0)
	Make /o/n=10 $rates_name=0.005*(x+0.5)
	Make /o/n=(numpnts($rates_name)) $events_name,$events_sem_name,$matched_events_name,$matched_events_sem_name
	Wave Events=$events_name; Wave Events_SEM=$events_sem_name; Wave Rates=$rates_name
	Wave MatchedEvents=$matched_events_name; Wave MatchedEvents_SEM=$matched_events_sem_name;
	
	Variable i,j,duration=20000
	for(j=0;j<numpnts(Rates);j+=1)
		print Rates[j]
		for(i=0;i<numpnts(Iterations);i+=1)
			MakePoissTrainUpDown(5,0.01,Rates[j],0.5,duration=duration)
			Wave PoissTrain
			Iterations[i]=PoissSurprise(PoissTrain,rate=0.1,thresh=1.5)
			MakePoissTrain(numpnts(PoissTrain)/duration,duration=duration)
			MatchedIterations[i]=PoissSurprise(PoissTrain,rate=0.1,thresh=1.5)
			Iterations[i]/=duration // Convert from events to events per second
			MatchedIterations[i]/=duration // Convert from events to events per second
		endfor
		WaveStats /Q Iterations
		Events[j]=V_avg
		Events_SEM[j]=V_sdev/sqrt(V_npnts)
		WaveStats /Q MatchedIterations
		MatchedEvents[j]=V_avg
		MatchedEvents_SEM[j]=V_sdev/sqrt(V_npnts)
	endfor
	
	//Events-=MatchedEvents
	
	Display /K=1 
	AppendtoGraph /c=(65535,0,0) Events vs Rates
	ErrorBars $NameOfWave(Events),Y wave=($NameOfWave(Events_SEM),$NameOfWave(Events_SEM))
	AppendtoGraph /c=(0,0,0) MatchedEvents vs Rates
	ErrorBars $NameOfWave(MatchedEvents),Y wave=($NameOfWave(MatchedEvents_SEM),$NameOfWave(MatchedEvents_SEM))
	Label left "Events per second"
	Label bottom "Poisson Rate (Hz)"
	ModifyGraph lowTrip(left)=0.001
	DoUpdate; GetAxis /Q left
	SetAxis left 0,V_max
End

// Returns a train of spike times in seconds
Function /S MakePoissTrain(rate[,duration]) // Rate in Hz
	Variable rate,duration
	duration=ParamIsDefault(duration) ? 10000 : duration
	Make /o/n=0 PoissTrain
	Variable thyme=0,ISI,i=0
	Do
		ISI=-ln(abs(enoise(1)))/rate
		thyme+=ISI
		if(thyme<duration)
			Redimension /n=(i+1) PoissTrain
			PoissTrain[i]=thyme
			i+=1
		else
			return NameOfWave(PoissTrain)
		endif
	While(1)
	
End

Function /S MakePoissTrainUpDown(rateUp,rateDown,rateTransUp,rateTransDown[,duration])
	Variable rateUp,rateDown,rateTransUp,rateTransDown,duration
	duration=ParamIsDefault(duration) ? 10000 : duration
	Make /o/n=0 PoissTrain
	Variable thyme=0,ISI,i=0,transTime
	Variable state=(abs(enoise(1)) < rateTransUp/(rateTransUp+rateTransDown)) // Initial state is randomly determined based on transition rates
	Do
		if(state==1) // Up-state
			transTime=thyme-ln(abs(enoise(1)))/rateTransDown
			Do
				ISI=-ln(abs(enoise(1)))/rateUp
				thyme+=ISI
				if(thyme < duration)
					if(thyme<TransTime)
						Redimension /n=(i+1) PoissTrain
						PoissTrain[i]=thyme
						i+=1
					else
						thyme=TransTime
						state=0
						break
					endif
				else
					return NameOfWave(PoissTrain)
				endif
				While(i<numpnts(PoissTrain))
		elseif(state==0) // Down-state
			transTime=thyme-ln(abs(enoise(1)))/rateTransUp
			Do
				ISI=-ln(abs(enoise(1)))/rateDown
				thyme+=ISI
				if(thyme < duration)
					if(thyme<TransTime)
						Redimension /n=(i+1) PoissTrain
						PoissTrain[i]=thyme
						i+=1
					else
						thyme=TransTime
						state=1
						break
					endif
				else
					return NameOfWave(PoissTrain)
				endif
			While(i<numpnts(PoissTrain))
		endif
	While(1)
End

Function TestMeanWaitingTime()
	Variable prob=0.001
	Variable i
	Make /o/n=25 Caca
	for(i=0;i<numpnts(Caca);i+=1)
		Make /o/n=100000 Test=expnoise(100)
		Caca[i]=1/MeanWaitingTime(Test,Inf)
	endfor
	WaveStat2(Caca)
End

Function FirstPassage()
	Make /o/n=10000 PDF,CDF,Values
	Make /o/n=100 RandomWalkLatencies,RandomWalkSigmas
	Variable barrier=20
	Variable barrier2=barrier^2
	Variable i
	for(i=0;i<numpnts(RandomWalkLatencies);i+=1)
		//print i
		Variable sigma=sqrt(0.1)*1.05^i
		SetScale x,0,10000,PDF,CDF,Values
		Variable lambda=barrier^2/sigma^2
		Variable last_guess=9,guess=10,next_guess,old_value,consec=0,tolerance=0.001
		Do
			Variable value=StatsWaldCDF(guess,1000000,lambda)
			if(value<0.5-tolerance)
				if(old_value<0.5-tolerance)
					consec+=1
					next_guess=guess*consec
				else
					consec=0
					next_guess=guess+abs(last_guess-guess)/2
				endif
			elseif(value>0.5+tolerance)
				if(old_value>0.5+tolerance)
					consec+=1
					next_guess=guess/consec
				else
					consec=0
					next_guess=guess-abs(last_guess-guess)/2
				endif
			elseif(value>=0.5-tolerance && value<=0.5+tolerance )
				break
			else
				guess=10; abort
			endif
			//print guess,next_guess,value,lambda
			last_guess=guess
			guess=next_guess
			old_value=value
		While(1)
		//PDF=StatsWaldPDF(x,1000000,lambda)
		//Values=PDF*x
		//Extract /O Values,ActualValues,numtype(Values)==0
		//Values[0]=0
		//Integrate Values
		//FindLevel /Q CDF,0.5
//		if(V_flag)
//			Averages[i]=NaN
//		else
//			Averages[i]=V_LevelX//Values[numpnts(Values)-1]
//		endif
		RandomWalkLatencies[i]=guess
		RandomWalkSigmas[i]=sigma
		//DoUpdate
	endfor
	//Averages=log(Averages)
	//Sigmas=log(Sigmas)
	//CurveFit/Q/M=2/W=0 line, Averages /X=Sigmas /D
	//print K0,K1
	//Display /K=1 Averages vs Drifts
End

// Function for running IntegrateODE for exponential decay.  
Function FirstOrder(pw, xx, yw, dydx)
	Wave pw	// pw[0] contains the value of the constant a
	Variable xx	// not actually used in this example
	Wave yw	// has just one element- there is just one equation	
	Wave dydx	// has just one element- there is just one equation	

	// There's only one equation, so only one expression here.
	//  The constant a in the equation is passed in pw[0]
	dydx[0] = -pw[0]*yw[0]
End

// Apparently, the standard deviation of the distribution of MatchTemplate scores is ~ the cube root of the correlation time of the noise used to generate the data.  
Function TemplateScoresVsCorrelationTime()
	Variable i
	Variable iterations=10
	Make /o/n=100000 Test
	SetScale /P x,0,0.0001,Test
	Make /o Hist
	Make /o/n=(iterations) Widths=NaN,Taus=NaN
	Display /K=1 Widths vs Taus
	Wave Alpho=$AlphaSynapso(1,3,5,40)
	Variable V_FitOptions=4
	Execute /Q "ProgressWindow open"
	for(i=0;i<iterations;i+=1)
		Variable ampl=1+i
		Variable tau=0.005//i/10000
		CorrelatedNoise(ampl,tau,test)
		Execute /Q "MatchTemplate Alpho,Test"
		Histogram /B=4 Test,Hist
		CurveFit/Q/M=2/W=0 gauss, Hist
		Widths[i]=K3
		Taus[i]=ampl//tau
		Execute /Q "ProgressWindow frac="+num2str(i/iterations)
		DoUpdate
	endfor
	Execute /Q "ProgressWindow close"
End

// Get the number of events using the excess number of positively valued MatchTemplate scores.  
Function NumberOfEvents(num_events)
	Variable num_events
	Variable i
	Make /o/n=100000 Test
	SetScale /P x,0,0.0001,Test
	CorrelatedNoise(1,0.005,Test)
	Make /o Hist
	Wave Alpho=$AlphaSynapso(1,3,5,40)
	Variable points=numpnts(Alpho)
	Variable V_FitOptions=4
	//Execute /Q "ProgressWindow open"
	for(i=0;i<num_events;i+=1)
		Variable loc=round(abs(enoise(numpnts(Test))))
		Test[loc,loc+points-1]+=10000*Alpho[p-loc]
	endfor
	Duplicate /o Test,Scores
	Execute /Q "MatchTemplate /C Alpho,Scores"
	Histogram /B=4 Scores,Hist
	Extract /O Scores,ScoresPos,Scores>0
	Extract /O Scores,ScoresNeg,Scores<0
	Variable excess=numpnts(ScoresPos)-numpnts(ScoresNeg)
	print excess
	//Execute /Q "ProgressWindow close"
End

Function DifferentTimeConstants(p0,i0,n0,decay_time,baseline_variance,num_events[,offset_noise,correlation_time,decay_time_noise])
	Variable p0,i0,n0,decay_time,baseline_variance,num_events
	Variable offset_noise // Adds a jitter to the start times, reproducing a failure to correctly align the events in time.  
	Variable correlation_time // The correlation time of the non-binomial noise.  
	Variable decay_time_noise // The standard deviation of the decay time.  
	NewDataFolder /O/S root:MeanVariance
	Display /K=1
	String graph_name=WinName(0,1)
	Make /o/n=(num_events) TraceAmplitudes
	Make /o/n=(num_events) TraceFits
	Make /o/n=200 tempFit
	Make /o/n=(num_events) Ns
	Variable V_FitOptions=6
	Variable i
	for(i=0;i<num_events;i+=1)
		String wave_name="MVE"+num2str(i)
		Make /o/n=200 $wave_name=0; Wave Event=$wave_name
		SetScale /P x,0,0.1,Event
		Do
			Variable size=2//expnoise(2)
		While(size<1 || size>20)
		//size=(size<0) ? 0 : size
		Variable offset=round(abs(enoise(offset_noise)))
		Variable new_n=n0*size
		Ns[i]=new_n
		Variable decay_rand=enoise(decay_time_noise)
		Variable t_decay=decay_time-decay_rand
		offset+=decay_rand
		//print t_decay
		//print new_n
		Event+=i0*new_n*p0*(e/t_decay)*(x-offset)*exp(-(x-offset)/t_decay) // The effective p here is an alpha function with peak value of p0.  
		Event[0,x2pnt(Event,offset)]=0
		//Event[0,x2pnt(Event,t_decay)]=0
		Make /o/n=200 Noise
		SetScale /P x,0,0.1,Noise
		CorrelatedNoise(sqrt(baseline_variance),correlation_time,Noise)
		Event+=Noise//gnoise(sqrt(baseline_variance))
		//Event+=i0*new_n*exp(-x/t_decay)
		AppendToGraph Event
		WaveStats /Q/M=1 Event
		TraceAmplitudes[i]=V_max//Event[0]
		Make /o W_Coef={t_decay,offset,0,new_n*p0*i0}
		//FuncFit /Q/N AlphaSynapse kwcWave=W_Coef Event /D=tempFit
		WaveStats /Q/M=1 tempFit
		TraceFits[i]=V_max-V_min
		Event/=TraceFits[i]//V_max//(new_n*i0)
		//print Event[0]
		//print i
	endfor
	WaveStats /Q Ns
	print i0,V_avg
	AverageTraces(variance=1); ModifyGraph rgb($TopTrace())=(0,0,0)
	//Display /K=1 $(graph_name+"_Matrix_SEM") vs $(graph_name+"_Matrix_Mean")
	//BigDots()
End

Function Squares(meann,noise)
	Variable meann,noise
	Make /o/n=1000000 Test=meann+gnoise(noise)
	Test=Test^2
	print sum(Test)
End

Function BinoVariance(i,N,p0,noiz)
	Variable i,N,p0,noiz
	Variable j
	Variable count=0
	Variable iterations=100000
	Make /o/n=1 Noise,VariableP
	Make /o/n=(iterations) Ps
	for(j=0;j<numpnts(Noise);j+=1)
		Ps=p0+gnoise(noiz)
		Make /o/n=(iterations) Test=binomialnoise(N,Ps)
		Test*=i
		WaveStats /Q Test
		VariableP[j]=V_sdev^2
		Variable variance=V_sdev^2
		Noise[j]=noiz
		//print p*N*i,V_avg
	endfor
	Make /o/n=(iterations) Ps2=Ps^2
	WaveStats /Q Ps; Variable PVar=V_sdev^2
	print i*i*N*p0-((i*N*p0)^2)/N,       p0*(1-p0)*i*i*N,          variance,              i*i*N*N*PVar+i*i*N*p0-i*i*N*mean(Ps2)
	//Display /K=1 VariableP vs Noise
End

Function Successes(p,noise)
	Variable p,noise
	Variable i
	Variable count=0
	Variable iterations=100000
	for(i=0;i<100000;i+=1)
		if((p+enoise(noise))>abs(enoise(1)))
			count+=1
		endif
	endfor
	return count/iterations
End

Function CorrelateNoiseStDevs()
	Variable i
	Make /o/n=100 Values
	for(i=0;i<numpnts(Values);i+=1)
		Make /o/n=200000 Noise=0
		CorrelatedNoise(3,5,Noise)
		Values[i]=Noise[199999]
	endfor
	WaveStats /Q Values
	print V_sdev
End

Function MeanVarianceEvents(p0,i0,n0,decay_time,baseline_variance,num_events[,offset_noise,correlation_time,decay_time_noise,i_noise])
	Variable p0,i0,n0,decay_time,baseline_variance,num_events
	Variable offset_noise // Adds a jitter to the start times, reproducing a failure to correctly align the events in time.  
	Variable correlation_time // The correlation time of the non-binomial noise.  
	Variable decay_time_noise // The standard deviation of the decay time.  
	Variable i_noise // The standard deviation of the single channel current.  
	NewDataFolder /O/S root:MeanVariance
	Display /K=1
	String graph_name=WinName(0,1)
	Make /o/n=(num_events) TraceAmplitudes
	Make /o/n=(num_events) TraceFits
	Make /o/n=250 tempFit
	Make /o/n=(num_events) Ns,Is
	Variable V_FitOptions=6
	Variable i
	for(i=0;i<num_events;i+=1)
		String wave_name="MVE"+num2str(i)
		Make /o/n=250 $wave_name=0; Wave Event=$wave_name
		SetScale /P x,0,0.1,Event
		Do
			Variable size=2//+enoise(0.5) // Will use expnoise once I figure out the very best estimator of the variance from an exponential distribution.  
		While(size<1 || size>20)
		//size=(size<0) ? 0 : size
		Variable offset=3+round(abs(enoise(offset_noise)))
		Variable new_n=n0*size
		Variable new_i=i0+gnoise(i_noise)
		Ns[i]=new_n
		Is[i]=new_i
		Variable decay_rand=enoise(decay_time_noise)
		Variable t_decay=decay_time-decay_rand
		offset+=decay_rand
		Event+=new_i*binomialnoise(new_n,p0*(e/t_decay)*(x-offset)*exp(-(x-offset)/t_decay)) // The effective p here is an alpha function with peak value of p0.  
		Event[0,x2pnt(Event,offset)]=0
		//Event[0,x2pnt(Event,t_decay)]=0
		Make /o/n=250 Noise
		SetScale /P x,0,0.1,Noise
		CorrelatedNoise(sqrt(baseline_variance),correlation_time,Noise)
		//Event+=Noise//gnoise(sqrt(baseline_variance))
		//Event+=i0*new_n*exp(-x/t_decay)
		//ExpFilter(Event,2)
		AppendToGraph Event
		WaveStats /Q/M=1 Event
		TraceAmplitudes[i]=V_max//Event[0]
		Make /o W_Coef={t_decay,offset,0,new_n*p0*i0}
		FuncFit /Q/N AlphaSynapse kwcWave=W_Coef Event /D=tempFit
		SetScale /P x,0,0.1,tempFit
		Duplicate /o tempFit root:MeanVariance:$("Fit_"+num2str(i))
		WaveStats /Q/M=1 tempFit
		TraceFits[i]=V_max-V_min
		//Event/=TraceFits[i]//V_max//(new_n*i0)
		//print Event[0]
		//print i
	endfor
	WaveStats /Q Ns
	Variable avg_N=V_avg
	print i0,avg_N
	
	AverageTraces(variance=1)
	ModifyGraph rgb($TopTrace())=(0,0,0)
	Wave Variance=$(graph_name+"_Matrix_SEM")
      Wave Meann=$(graph_name+"_Matrix_Mean")
      Display /K=1 Variance vs Meann
      
//	NocetiTraces(TraceAmplitudes=TraceFits)
//	Wave Meann=root:Noceti:NocetiMean
//	Wave Variance=root:Noceti:NocetiVariance

//	Display /K=1
//	//graph_name=WinName(0,1)
//	for(i=0;i<num_events;i+=1)
//		Wave Fit=root:MeanVariance:$("Fit_"+num2str(i))
//		WaveStats /Q/M=1 Fit
//		Fit/=V_max
//		AppendToGraph /c=(0,0,0) Fit
//	endfor

	BigDots()
//	CurveFit/Q/M=2/W=0 poly 3, SEM[70,230] /X=Meann[70,230]/D; print K1,-1/K2
	
	Make /o W_Coef={i0,avg_N}
	WaveStats /Q Is
	Variable CVi=i_noise/i0
	Make /o/n=(numpnts(Meann)) CViWave=CVi, CVpWave=0, Fit_Variance=0
      FuncFit/Q/N/NTHR=1/TBOX=0 MVFit2 W_coef  Variance /X={Meann,CViWave,CVpWave} /D=Fit_Variance; print W_Coef[0],W_Coef[1]
      AppendToGraph Fit_Variance vs Meann
//	Make /o/n=(numpnts(Graph0_Matrix_Mean)) CViWave=CVi, CVpWave=0
//	FuncFit/Q/N/NTHR=1/TBOX=0 MVFit2 W_coef  Graph0_Matrix_SEM[70,230] /X={Graph0_Matrix_Mean,CViWave,CVpWave} /D; print W_Coef[0],W_Coef[1]
//	AppendToGraph fit_Graph0_Matrix_SEM
//	Wave W_Coef
//	Redimension /D W_Coef
//	W_Coef={i0*0.8,avg_N*0.8,1}
//	FuncFit/Q/N/H="001"/NTHR=1/TBOX=0 MVFit W_coef  Graph0_Matrix_SEM[70,230] /X={Graph0_Matrix_Mean,Graph1_Matrix_SEM} /D; print W_Coef[0],W_Coef[1]
//	AppendToGraph fit_Graph0_Matrix_SEM
End

Function FilteredAlphas()
	Variable i
	Display /K=1
	Wave Alpho=$AlphaSynapso(100,2,5,20)
	Make /o/n=0 Filters,Fitz,Peaks
	for(i=1;i<10;i+=0.2)
		Duplicate /o Alpho $("Alpho"+num2str(i))
		Wave AlphoFiltered=$("Alpho"+num2str(i))
		Variable tau=i/2
		ExpFilter(AlphoFiltered,tau)
		AppendToGraph /c=(0,0,0) AlphoFiltered
		Make /o W_Coef={2,5,0,100}
		Variable V_FitOptions=4
		FuncFit /Q/N AlphaSynapse kwcWave=W_Coef AlphoFiltered /D
		InsertPoints 0,1,Filters,Fitz,Peaks
		//print tau,W_Coef[0]
		WaveStats /Q/M=1 AlphoFiltered
		Peaks[0]=V_max
		Filters[0]=tau
		Fitz[0]=W_Coef[3]*W_Coef[0]/e
	endfor
	Display /K=1 Fitz vs Filters
	Display /K=1 Peaks vs Fitz
End

Function SelfVariance(p0,i0,n0,decay_time,baseline_variance,num_events[,offset_noise,correlation_time,decay_time_noise])
	Variable p0,i0,n0,decay_time,baseline_variance,num_events
	Variable offset_noise // Adds a jitter to the start times, reproducing a failure to correctly align the events in time.  
	Variable correlation_time // The correlation time of the non-binomial noise.  
	Variable decay_time_noise // The standard deviation of the decay time.  
	NewDataFolder /O/S root:MeanVariance
	Display /K=1
	String graph_name=WinName(0,1)
	Make /o/n=(num_events) TraceAmplitudes
	Make /o/n=(num_events) TraceFits
	Make /o/n=250 tempFit
	Make /o/n=(num_events) Ns
	Variable V_FitOptions=6
	Variable i
	for(i=0;i<num_events;i+=1)
		String wave_name="MVE"+num2str(i)
		Make /o/n=250 $wave_name=0; Wave Event=$wave_name
		SetScale /P x,0,0.1,Event
		Do
			Variable size=2//expnoise(2)
		While(size<1 || size>20)
		//size=(size<0) ? 0 : size
		Variable offset=3+round(abs(enoise(offset_noise)))
		Variable new_n=n0*size
		Ns[i]=new_n
		Variable decay_rand=enoise(decay_time_noise)
		Variable t_decay=decay_time-decay_rand
		offset+=decay_rand
		Event+=i0*binomialnoise(new_n,p0*(e/t_decay)*(x-offset)*exp(-(x-offset)/t_decay)) // The effective p here is an alpha function with peak value of p0.  
		Event[0,x2pnt(Event,offset)]=0
		//Event[0,x2pnt(Event,t_decay)]=0
		Make /o/n=250 Noise
		SetScale /P x,0,0.1,Noise
		CorrelatedNoise(sqrt(baseline_variance),correlation_time,Noise)
		Event+=Noise//gnoise(sqrt(baseline_variance))
		//Event+=i0*new_n*exp(-x/t_decay)
		//WaveStats /Q/M=1 Event
		//TraceAmplitudes[i]=V_max//Event[0]
		Make /o W_Coef={t_decay,offset,0,new_n*p0*i0}
		FuncFit /Q/N AlphaSynapse kwcWave=W_Coef Event /D=tempFit
		Event-=tempFit
		//Differentiate /METH=1 Event; Redimension /n=(numpnts(Event)-1) Event
		AppendToGraph Event
		//SetScale /P x,0,0.1,tempFit
		//Duplicate /o tempFit root:MeanVariance:$("Fit_"+num2str(i))
		//WaveStats /Q/M=1 tempFit
		//TraceFits[i]=V_max-V_min
		//Event/=TraceFits[i]//V_max//(new_n*i0)
		//print Event[0]
		//print i
	endfor
End

// Models reverberation occurence as an inhomogeneous renewal process.  (The inhomogeneity exists at the time of stimulus, where the probabilty is raised substantially).  
// A second inhomogeneity could exist, in that the probability could decay slowly with time after a reverberation, but this is not yet implemented.  
Function /S MockReverb(amplitude,duration0,rate0,duration_tau,rate_tau)
	Variable amplitude,duration0,rate0,duration_tau,rate_tau
	Variable recording_time=100
	Variable time_scale=0.001
	Variable time_step=0.01
	Variable time_skip=time_step/time_scale
	Variable points=round(recording_time/time_scale)
	Make /o /n=(points) Reverb=0
	SetScale x,0,recording_time,Reverb
	Variable oscillation_freq=8
	Variable stim_time=3
	Variable stim_prob=1
	Variable rate=rate0
	Variable duration=duration0
	Variable relative_rate=1
	Variable rando,comparator
	Variable t
	for(t=time_step;t<recording_time;t+=time_step)
		rate=relative_rate*rate0
		rando = abs(enoise(1))
		if(x2pnt(Reverb,t)==x2pnt(Reverb,stim_time))
			comparator = stim_prob*relative_rate
		else
			comparator = rate*time_step
		endif
		if(rando<comparator)
			Variable ampl=amplitude*(1+gnoise(0.1))
			Reverb[x2pnt(Reverb,t),x2pnt(Reverb,t+duration)]+=-ampl*abs(sin(pi*oscillation_freq*x))*sqrt(exp(-(x-t)/duration))
			t=t+duration
			relative_rate=0
			duration=0
		else
			relative_rate+=time_step*(1-relative_rate)/rate_tau
			duration+=time_step*(duration0-duration)/duration_tau
		endif
	endfor
	return GetWavesDataFolder(Reverb,2)
End

Function MockReverbs()
	Make /o/n=0 MedianDuration,Levels
	Variable i // i is the inherent spontaneous reverberation rate.  
	String name
	//Display /K=1
	for(i=0;i<2;i=(i+0.001)*1.5)
		print i
		Wave Reverb=$MockReverb(500,5,i,15,3)
		//Display /K=1
		//name=UniqueName(CleanUpName(NameOfWave(Reverb)+num2str(i),0),1,0)
		//Duplicate /o Reverb $name; Wave Reverb=$name
		//AppendToGraph Reverb
		InsertPoints 0,1,MedianDuration,Levels
		Smooth /B=2 round((1/0.001)/8),Reverb
		Make /o/n=0 Onsets,Offsets
		FindLevels /EDGE=2/Q/D=Onsets Reverb,-50; Wave Onsets
		Levels[0]=numpnts(Onsets)
		FindLevels /EDGE=1/Q/D=Offsets Reverb,-50; Wave Offsets
		Duplicate /o Onsets,Durations
		Durations=-(Onsets-Offsets)
		//print numpnts(Durations),Durations
		MedianDuration[0]=StatsMedian(Durations)
	endfor
	
	Display /K=1 MedianDuration vs Levels
	BigDots(size=3)
	Execute /Q/Z "Tile"
End

Function CrashTest()
	//Make /o/n=0 MedianDuration,Levels
	//Variable i // i is the inherent spontaneous reverberation rate.  
	//for(i=0;i<3;i+=0.05)
	//	MockReverb(500,2,i,5,5)
	//	InsertPoints 0,1,MedianDuration,Levels
	//endfor
	//Make /o/n=100 Reverb=gnoise(25)
	//Display Reverb
	//Smooth /B=2 round((1/0.001)/8),Reverb
	//FindLevels /D=$("OnsetTimes") Reverb,-30; Wave OnsetTimes
	//Levels[0]=numpnts(W_FindLevels)
	//FindLevels /EDGE=1/Q/D=Offsets Reverb,-30; Wave Offsets
	//Duplicate /o Onsets,Durations
	//Durations=-(Onsets-Offsets)
	print StatsMedian(Durations)
End

Function ExponentialCascade(first,num,multiple)
	Variable first,num,multiple
	Make /o/n=1000000 Poop=0
	Variable i,factor
	for(i=0;i<num;i+=1)
		factor=first*(multiple^i)
		Poop+=exp(-x/factor)
	endfor
	Display /K=1 Poop
	ModifyGraph log=1
End

Function SumSquareWaves()
	Variable i
	Make /o/n=110000 test=0
	SetScale x,-1,10,test
	//Variable length
	Make /o/n=1000 Lengths=expnoise(4)
	for(i=0;i<1000;i+=1)
		test[10000,10000+Lengths[i]*10000]+=1
	endfor
	Display /K=1 test
	KillWaves Lengths
End

Function test562()
	Variable t1,t2,val
       Make/o/n=1000 ddd=gnoise(10)
       //ddd=(ddd>0) ? NaN : ddd
       t1=startmstimer
       val=statsmedian(ddd)
       t1=stopmstimer(t1)
       t2=startmstimer
       Median2(ddd)
       t2=stopmstimer(t2)
       print t2/t1
End

// Determine what the relationship is between the size of a wave and the time it takes to perform a certain operation on it.  
Function TimeTester()
	Variable i,j,points,points2,points3
	Variable /G no_print
	Variable num_examples=1,num_iterations=1,dummy,dummy2
	Make /o/n=(num_examples) Answers,Lengths
	Make /o/n=(num_iterations) TT_Temp
	Toc()
	Wave /Z StateX,Released,Available,Unavailable
	Variable temp1,temp2; String str
	for(i=0;i<num_examples;i+=1)
		points=760+100*i
		Lengths[i]=points
		// Set up the wave here.  
			
		//TT_Temp=(TT_Temp<0) ? NaN : TT_Temp
		//Make /o/n=(points) Stuff=1.345
		for(j=0;j<num_iterations;j+=1)
			Make /D/o/n=(128*128,points) TT_Temp2=gnoise(1)
			Tic()
			MatrixSVD /U=1 /V=1 TT_Temp2
			//MatrixOp /O TT_Temp2=5*TT_Temp2*TT_Temp2
			dummy=Toc()
			//Tic()
			//FastOp TT_Temp2=5*TT_Temp2*TT_Temp2
			//dummy2=Toc()
			TT_Temp[j]=dummy//2/dummy
		endfor
		WaveStats /Q/M=1 TT_Temp
		Answers[i]=V_avg
		//print i,Answers[i]
		//print Answers[i]
	endfor
	KillVariables /Z no_print
	KillWaves /Z TT_Temp,TT_Temp2
	//Display /K=1 Answers vs Lengths
	//Label left "Time (ms)"
	//Label bottom "Wave Size (points)"
End

Function RemoveNaNsBySorting(myWave)
	Wave myWave
	Make /o/n=(numpnts(myWave)) keyWave = x
  	Sort myWave, myWave, keyWave
	WaveStats/Q myWave
	//print numpnts(myWave),numpnts(keyWave)
	DeletePoints V_npnts,V_numNaNs,myWave,keyWave
  	Sort keyWave, keyWave, myWave
      KillWaves keyWave
End

// See what kind of p-values result from gaussian distributions with the following means and variances
Function PTest(mean1,sem1,n1,mean2,sem2,n2)
	Variable mean1,sem1,n1,mean2,sem2,n2
	Variable i,iterations=100
	Make /o/n=(iterations) PTest_Temp=NaN
	Make /o/n=(n1) wave1
	Make /o/n=(n1) wave2
	Make /o/n=3 PearsonVals
	for(i=0;i<iterations;i+=1)
		wave1=mean1+gnoise(sem1*sqrt(n1))
		wave2=mean2+gnoise(sem2*sqrt(n2))
		PTest_Temp[i]=imag(StatTTest(0,wave1,wave2))
	endfor
	print WaveStat2(PTest_Temp)
	//KillWaves PTest_Temp,PearsonVals
End

// See if CV Analysis is biased to give different results for synapses with different initial strength.  
Function CVTest()
	Variable i,begin,endd,iterations=10000
	Make /o/n=(iterations) LowResult=NaN,HighResult=NaN
	Make /o/n=(iterations) LowResult2=NaN,HighResult2=NaN
	for(i=0;i<iterations;i+=1)
		Make /o/n=20 LowBegin,HighBegin
		Make /o/n=20 LowEnd,HighEnd
		//LowBegin=50+gnoise(10)
		HighBegin=500+gnoise(10)
		//LowEnd=40+gnoise(8)
		HighEnd=500+gnoise(10)
		//begin=(stdev(LowBegin)/mean(LowBegin))^2
		//endd=(stdev(LowEnd)/mean(LowEnd))^2
		//LowResult[i]=begin/endd
		//begin=(StDevNoise(LowBegin)/mean(LowBegin))^2
		//endd=(StDevNoise(LowEnd)/mean(LowEnd))^2
		//LowResult2[i]=begin/endd
		begin=(stdev(HighBegin)/mean(HighBegin))^2
		endd=(stdev(HighEnd)/mean(HighEnd))^2
		//HighResult[i]=begin/endd
		HighResult[i]=(mean(HighEnd)/mean(HighBegin))/(begin/endd)
		//begin=(StDevNoise(HighBegin)/mean(HighBegin))^2
		//endd=(StDevNoise(HighEnd)/mean(HighEnd))^2
		//HighResult2[i]=begin/endd
//		if(mod(i,1000)==0)
//			print i
//		endif
	endfor
	//Duplicate /o HighResult Quotient
	//Quotient=HighResult2/HighResult
	//LowResult=log(LowResult)
	//HighResult=log(HighResult)
	//Sort LowResult,LowResult
	Sort HighResult,HighResult
	//Sort LowResult2,LowResult2
	//Sort HighResult2,HighResult2
	//Sort Quotient,Quotient
	Display /K=1 
	//AppendToGraph Quotient
	//AppendToGraph /c=(65535,0,0) LowResult
	AppendToGraph /c=(0,0,65535) HighResult
	ModifyGraph log(left)=1
	//AppendToGraph /c=(65535,0,0) LowResult2
	//AppendToGraph /c=(0,0,65535) HighResult2
	//ModifyGraph log=1
	//print WaveStat2(LowResult)
	print WaveStat2(HighResult)
End

// Slopes and correlation coefficients for a baseline, assuming that the values are just noise around a fixed mean.  
Function RunUpDown(st_dev,[meann,trials,num_iterations])
	Variable st_dev,meann,trials,num_iterations
	meann=ParamIsDefault(meann) ? 100 : meann
	trials=ParamIsDefault(trials) ? 20 : trials
	num_iterations=ParamIsDefault(num_iterations) ? 1000 : num_iterations
	
	Make /o/n=(trials) RunUpDownSamples
	Make /o/n=(num_iterations) Rs,Slopes
	Variable i,V_FitOptions=4
	for(i=0;i<num_iterations;i+=1)
		//print i
		RunUpDownSamples=meann+gnoise(st_dev)
		CurveFit /Q line RunUpDownSamples
		Rs[i]=V_Pr
		Slopes[i]=K1
	endfor
	Sort Rs,Rs
	Sort Slopes,Slopes
	SetScale x,0,1,Rs,Slopes
	Display /K=1
	AppendToGraph /L /c=(65535,0,0) Slopes
	AppendToGraph /R /c=(0,0,65535) Rs
	ModifyGraph axRGB(left)=(65535,0,0), axRGB(right)=(0,0,65535)
	Label left "Slope (pA/trial)"
	Label right "R (Correlation Coefficient)"
	Label bottom "Cumulative Fraction"
	Textbox "Standard Deviation = "+num2str(st_dev)+" pA; Trials = 20"
End

// Display the relationship between statistical moments in a signal and the frequency and amplitude of mEPSCs in that signal
Function MiniStats()
	Display /K=1 /N=MiniStatsGraph
	NewDataFolder /O/S root:MiniStats
	Variable kHz=10,duration=10,iterations=25
	Make /o/n=(kHz*1000*duration) Signal,Mini
	SetScale /P x,0,1/(10*kHz),Signal,Mini // Set to 10 kHz sampling rate.
	Make /o /n=(kHz*1000*duration) Expo=0
	SetScale /P x,0,1/(1000*kHz),Expo  
	Make /n=(iterations) Freq,Meann,SDev,Skew,Kurtosis,ADev,RMS
	Variable i,offset,rate,amplitude=-1,decay=0.01
	for(i=1;i<=iterations;i+=1)
		print i
		rate=i
		Signal=0//gnoise(0.1)
		offset=0
		Do
			offset+=-ln(abs(enoise(1)))/rate
			if(offset>duration)
				break
			else
				Wave Expo=$ExpSynapse(amplitude,decay,offset,duration,"Expo")
				Signal+=Expo
			endif
		While(1)
		WaveStats /Q Signal; Freq[i]=rate
		Meann[i]=V_avg
		SDev[i]=V_sdev
		Skew[i]=V_skew
		Kurtosis[i]=V_kurt
		ADev[i]=V_adev
		RMS[i]=V_rms
	endfor
	AppendToGraph Meann,SDev,Skew,Kurtosis,ADev,RMS vs Freq
	//KillWaves Signal
	//SetDataFolder ::
	//KillDataFolder root:MiniStats
End

// Make a synaptic current based upon a single decaying exponential function.  
Function /S ExpSynapse(amplitude,decay,offset,duration,template)
	Variable amplitude,decay,offset,duration // In mV, s, s, and s.    
	String template // The name of a wave to turn into an exponential synapse.  
	Wave Expo=$template
	Variable kHz=10
	Expo=x>offset ? amplitude*exp(-(x-offset)/decay) : 0
	return GetWavesDataFolder(Expo,2)
End

// Superimpose a bunch of alpha synapses.  
Function /S AlphoSynapsos(locations,amplitudes,t_decay,offset,duration[,kHz])
	String locations,amplitudes
	Variable t_decay,offset,duration // In mV, ms, ms, and ms.    
	Variable kHz
	kHz=ParamIsDefault(kHz) ? 10 : kHz
	Make /o/n=(duration*kHz) Alpho=0
	duration/=1000; offset/=1000; t_decay/=1000 // Convert from ms to s.  
	SetScale x,-offset,duration-offset,Alpho
	Variable i
	for(i=0;i<ItemsInList(locations);i+=1)
		Variable location=str2num(StringFromList(i,locations))
		Variable amplitude=str2num(StringFromList(i,amplitudes))
		print location
		Alpho+=x>location ? amplitude*(x-location)*exp(-(x-location)/t_decay) : 0
	endfor
	return GetWavesDataFolder(Alpho,2)
End

// Make a synaptic current based upon a single decaying exponential function.  
Function /S MakeSynapso(amplitude,t_rise,t_decay,offset,duration[,kHz])
	Variable amplitude,t_rise,t_decay,offset,duration // In mV, ms, ms, and ms.    
	Variable kHz
	kHz=ParamIsDefault(kHz) ? 10 : kHz
	Make /o/n=(duration*kHz) Synapso
	SetScale x,-offset,duration-offset,Synapso
	Synapso=x>0 ? amplitude*(1-exp(-x/t_rise))*exp(-x/t_decay) : 0
	return GetWavesDataFolder(Synapso,2)
End

// Compare the variance of a population to the average of the difference between neighbors in that population
Function VarianceVsAverageDifference()
	Make /o/n=100 Ratio=NaN
	Variable i,sdev1,sdev2
	for(i=0;i<numpnts(AverageDiff);i+=1)
		Make /o/n=100000 Noisy=binomialNoise(50,0.2) // Create a noisy signal.  
		WaveStats /Q Noisy
		sdev1=V_sdev // The standard deviation of that signal.  
		Noisy+=x^0.1 - ln(x) // Add some sort of trend to it.  
		Differentiate /METH=1 Noisy // Differentiate it.  
		WaveStats /Q Noisy
		sdev2=V_sdev/sqrt(2) // The standard deviation of the differentiated signal divided by sqrt(2).  
		//AverageDiff[i]=V_adev
		Ratio[i]=sdev1/sdev2 // Compares these two values.  
	endfor
	WaveStats /Q Ratio; print num2str(V_avg)+" +/- "+num2str(V_sdev/sqrt(V_npnts))
	//Display /K=1 AverageDiff
End

// Calculate the impact of series resistance on the measured amplitude of a synaptic current.  
Function ImpactRs()
	SetDataFolder root:
	Duplicate/o root:cellL2:sweep71, synapse
	Variable tau
	Variable n
	Make/o/n=100 impact
	Make/o/n=100 taus
	for(n=0;n<100;n+=1)
		tau=n*0.0001
		synapse=10*(-exp(-x/0.01)*(1-exp(-x/0.003)))
		InsertPoints 0,100,synapse
		Duplicate/o synapse, impulse
		impulse=exp(-x/tau)
		NormalizeToUnity(impulse)
		FFT /dest=fsynapse synapse
		FFT /dest=fimpulse impulse
		fsynapse=fsynapse*fimpulse
		IFFT /dest=filtered fsynapse
		IFFT impulse
		WaveStats/Q filtered
		impact[n]=V_min
		taus[n]=tau
		DeletePoints 0,100,synapse
	endfor
	WaveStats/Q synapse
	impact[0]=V_min
	impact/=-5
	Display/K=1 impact vs taus
End

Function FitsToSynapseNoise()
	Make /o/n=301 Template
	SetScale /I x,-0.1,0.2,Template
	Variable amplitude=1000
	Variable decay=0.02
	Variable i,j
	String coefs="t_rise;t_decay;t0;y0;A"
	Make /o/D W_coef={0.0015,0.004,0,0,-50}
	Make /o/n=(0,5) AllCoefs
	//Display /K=1
	for(i=0;i<1000;i+=1)
		amplitude=100+abs(enoise(1000))
		Wave Alpha=$AlphaSynapso(-amplitude,decay,0,100)
		Alpha+=gnoise(1)
		//AppendToGraph Alpha
		W_coef={0.01,0.02,0,0,-50}
		//Make /o/T T_Constraints = {""};//{"K0>0","K0<0.01","K1>0","K1<0.05","K2<5","K2>-5","K3<10","K3>-10","K4<0"}	
		Variable V_fitoptions=4,V_FitError=0,V_FitQuitReason,V_FitMaxIters=40
		Variable num_errors=0
		V_FitError=0
		FuncFit/L=(numpnts(Alpha))/N/Q/NTHR=1/TBOX=0 Synapse kwCWave=W_coef Alpha ///C=T_Constraints /D
		if(V_FitError!=0)
			print num2str(i)+": Fit Error = "+num2str(V_FitError)+"; "+num2str(V_FitQuitReason)
			num_errors+=1
		else
			print num2str(i)
			InsertPoints /M=0 0, 1, AllCoefs
			for(j=0;j<5;j+=1)
				AllCoefs[0][j]=W_coef[j]
			endfor
		endif	
	endfor
	String coef
	for(i=0;i<numpnts(W_coef);i+=1)
		coef=StringFromList(i,coefs)
		Duplicate /o/R=[][i,i] AllCoefs $("Coef_"+coef)
		Wave CoefWave=$("Coef_"+coef)
		Redimension /n=(numpnts(CoefWave)) CoefWave
	endfor
	V_FitOptions=4
	Display /K=1 Coef_A vs Coef_t_decay
	BigDots(size=2)
	Wave Coef_A
	Coef_A*=-1
	ModifyGraph log=1
End

Function PoissEnd(prob,duration,num_trials)
	Variable prob
	Variable duration
	Variable num_trials
	Make /o/n=(num_trials) results
	Make /o/n=(duration) sample
	results=0
	Variable trial
	Variable lastone
	Variable t
	for(trial=1;trial<=num_trials;trial+=1)
    		sample=0;
    		lastone=0;
    		for(t=1;t<=duration;t+=1)
	       	if(abs(enoise(1))>(1-prob))
            			sample[t]=1
            			lastone=t
            		endif
        	endfor
        	results[trial]=duration-lastone
    	endfor
	Histogram results,hist
	CurveFit /Q exp  hist[0,490] /D 
	print K2
	print mean(results)
End