#pragma rtGlobals=1		// Use modern global access method.

// Analyze recordings with a fixed threshold (mV above the median membrane potential).  
Function StateDetector(w,winSize,upThresh,downThresh,consolidate,freq[,plot])
	wave w // The input wave.  
	variable winSize // 0.25.  The size of the segments (in seconds) for which statistics are calculated.  Smaller values will identify state transitions with more precision, but will be more sensitive to random fluctuations.  
	wave upThresh // {3,1}.  
	wave downThresh // {3,1}.  
	variable consolidate // 2.  Twice the minimum width of a state, in seconds.  Upstates shorter than this which are near each other will be consolidated into one upstate.  
	variable freq // 100.  New sampling frequency in Hz.  Too high a sampling frequency will retain too much noise; too low will miss the sharpness of state transitions.  
	variable plot // Plot the results.  
	
	// If the input wave 'w' does not already have sampling frequency 'freq', then make a copy and downsample it.  
	variable sampleSize=dimdelta(w,0)
	if(sampleSize != 1/freq)
		duplicate /free w,w_
		resample /rate=(freq) w_
	else
		wave w_=w
	endif
	
	// Compute a running mean and standard deviation of the baseline of 'w' and its first derivative.  
	// The segements where the computation of these running statitics are paused, due to excursions too far beyond the baseline values, are noted in the wave 'Paused'.  
	RunningStatistics(w_,winSize=winSize,pauseOn={{upThresh[0],upThresh[1]},{downThresh[0],downThresh[1]}})
	wave Meann,StanDev
	wave Paused // A first draft of the upstate locations, before consolidation of nearby Upstates.  
	duplicate /o Paused States
	Consolidation(States,consolidate) // Consolidation of nearby Upstates into a single Upstate.  
	// Consolidation is the only part of the algorithm that could not in principle be done in real-time as data is being collected, because it requires looking at future provisional states.  
	// Triggering off of Upstates presumably would not require consolidation, but the ends of Upstates might be identified prematurely without it.  
	// At this point, 'States' now represents a time series where 0's correspond to times in the Down state, and 1's to times in the Up state, and can be overlaid onto a plot of the data.  
	
	// Extract the locations of transtions from down to up ('Ups') and up to down ('Downs').  
	Extract /O/INDX States,Ups,(States[p]-States[p-1])==1
	Extract /O/INDX States,Downs,(States[p]-States[p-1])==-1
	
	// Convert from indices to times.  
	Redimension /S Ups,Downs
	Ups=leftx(w)+Ups*deltax(States)
	Downs=leftx(w)+Downs*deltax(States)
	if(plot)
		display /k=1
		appendtograph /c=(0,0,0) w
		appendtograph /c=(65535,0,0) Meann
		appendtograph /c=(0,0,65535) StanDev
		appendtograph /c=(0,65535,0) States
		modifygraph lsize(States)=2
		legend
	endif
	KillWaves /Z Meann,StanDev,Paused // Cleanup.  
End

Threadsafe Function RunningStatistics(w[,winSize,pauseOn,winShape])
	wave w
	variable winSize // The size of the segments for which statistics are calculated.  Smaller values will identify state transitions with more precision, but will be more sensitive to random fluctuations.  
	wave pauseOn // Format {{on_thresh,on_duration},{off_thresh,off_duration}}; Stop updating if the Z-score exceeds 'on_thresh' for 'on_duration', and continue if it stops exceeding 'off_thresh' for 'off_duration'. 
	string winShape // Window shape for running statitics.  Rectangular ("Rect") or Exponential ("Exp").  Exponential windows weight more recent values in the window more heavily.  

	variable delta=dimdelta(w,0) // Duration of a sample, in seconds.  
	variable lag=1 // How many samples back to look.  Lag must be greater than zero and has always been set to 1.   
	variable maxOffTime=2000/delta // The largest number of samples for which updating may be off before it is reinitialized.  
								 // Guards against e.g. sudden, long-lasting increases in the baseline.  The numerator is time in milliseconds.  

	winSize=ParamIsDefault(winSize) ? 0.25 : winSize // Default value of 250 ms.  
	if(!ParamIsDefault(pauseOn)) // Set the values for stopping and restarting updating of the baseline statistics.  
		variable on_thresh=pauseOn[0][0]
		variable on_duration=pauseOn[1][0]
		variable off_thresh=pauseOn[0][1]
		variable off_duration=pauseOn[1][1]
	endif
	winShape=SelectString(ParamIsDefault(winShape),winShape,"Exp") // Default to an exponential window, weighting recent samples more heavily than distant samples.  
	
	variable n=winSize/delta // Number of points in the window.  
	variable num_bins=round(numpnts(w)-n) // Number of points remaining (last point of initial window to last point of 'w').  
	variable i=0
	
	Differentiate /METH=1 w /D=dw // Compute the derivative (first difference) of the input wave 'w'.  
	wave dw
	//duplicate /free w,MeansThresh,StDevsThresh
	
	WaveStats /Q/R=[0,n-1] w // Compute statistics over the first n points of 'w' (called the initial segment), to get initial values of the statistics.  
	variable eX=V_avg // Mean of 'w'.  
	variable eX2=V_rms^2 // Mean of w-squared.  Simplifies the calculation of running variance. 
	variable eS=sqrt(eX2-eX^2) // Standard deviation of 'w'.  More appropriate than v_sdev, because it does not use the (n-1) correction as it is not intended to be an unbiased estimator.  
	Make /o/n=(numpnts(w)) Meann=eX,StanDev=eS,Paused=0 // Fill the outputs with the initial values.  
	
	// Repeat for the derivative of 'w'.  
	WaveStats /Q/R=[0,n-1] dw  
	variable edX=V_avg
	variable edX2=V_rms^2 // Work with variance to simplify the calculation. 
	variable edS=sqrt(edX2-edX^2)
	Make /free/n=(numpnts(w)) DMeann=edX,DStanDev=edS
	
	// Set initial values to statistics for inital segment.  
	variable val_on=eX,dval_on=edX
	variable val_off=val_on,dval_off=dval_on
	variable pause=0 // Update segment statistics when the next sample is examined.  
	variable count=0 // Initialize the counter for suspension/resumption of updating.  
	
	// Loop over all samples, starting with the first sample after the initial segment.  
	for(i=n;i<n+num_bins;i+=1)
		val_on=w[i] // The next value to examine in 'w'.  
		dval_on=dw[i] // The next value to examine in 'dw', the derivative of 'w'.  
		
		variable zw=(val_on-eX)/eS // A Z-score for the new 'w' value.  
		variable zdw=((dval_on-edX)/edS)^2 // A Z-score for the new 'dw' value.  
		
		//MeansThresh[i]=zw // A wave to store the 'w' z-scores.  
		//StDevsThresh[i]=zdw // A wave to score the 'dw' z-scores.  
		if(!ParamIsDefault(pauseOn)) // Check to see if updating should be suspended or resumed based on these scores.  
			if(pause==0 && (zw>on_thresh && zdw>on_thresh) && zw>0) // If we are currently updating but both thresholds have been crossed...
				count+=1 // Note that it has been going on.  
				if(count>=on_duration) // If this situation has persisted for a while...
					pause=1 // Stop updating.  
					count=0 // Reinitialize the counter.  
				endif
			elseif(pause==1 && (zw<off_thresh && zdw<off_thresh)) // If we are not updating but are under both thresholds.  
				count+=1
				if(count>=off_duration)
					pause=0 // Start updating.  
					count=0
					variable offTime=0 // Reinitialize the amount of time that updating has been off (since it is no longer off).  
				endif
			else
				count=0
			endif
			if(pause==1) // If we are not updating.  
				offTime+=1 // Note that we are still not updating.  
				if(offTime>maxOffTime) // If updating has been off for too long, turn it on again.  
					pause=0
					offTime=0
					count=0
					
					// Reinitialize statistics according to a new initial segment, starting at the current location and extending back n samples.  
					WaveStats /Q/R=[i-n+1,i] w
					eX=V_avg
					eX2=V_rms^2
					eS=sqrt(eX2-eX^2)
					WaveStats /Q/R=[i-n+1,i] dw
					edX=V_avg
					edX2=V_rms^2
					edS=sqrt(edX2-edX^2)
				endif
			else
				offTime=0
			endif
		endif
		
		if(!pause) // If we are updating.  
			Paused[i]=0 // Note that this was a period of updating.  
			val_on=w[i-lag] // Take the next value of 'w'.  
			dval_on=dw[i-lag] // Take the next value of 'dw'.  
			strswitch(winShape) // Updating the segment statistics according to the window shape.  
				case "Rect": // Rectangular window.  
					eX+=(val_on-val_off)/n // Update the mean-tracking variable.  
					eX2+=(val_on^2-val_off^2)/n // Update the mean-squared-tracking variable.  
					edX+=(dval_on-dval_off)/n
					edX2+=(dval_on^2-dval_off^2)/n
					val_off=w[i-n]*!Paused[i-n] // Set the next value to fall off as the window completely passes it.  
					dval_off=dw[i-n]*!Paused[i-n]
					break
//				case "Gauss": // Gaussian window
//					// Put all of this outside of the loop.  
//					Meann=w
//					// I believe that (2*n)^2 passes of binomial smoothing is equivalent to a Gaussian with standard deviation n.  
//					Smooth /E=3 (2*n)^2, Meann
//					StanDev=(w-Meann)^2
//					Smooth /E=3 (2*n)^2,StanDev
//					StanDev=sqrt(StanDev)
//					break
				case "Exp": // Exponential window.  
				default: // Default is exponential window.  
					eX+=(val_on-eX)/n 
					eX2+=(val_on^2-eX2)/n
					edX+=(dval_on-edX)/n
					edX2+=(dval_on^2-edX2)/n
					// Note that there is no 'off' value because past values fall off exponentially, rather than suddenly as the past edge of the window is reached.  
					break
			endswitch
			// Update statistics.  
			Meann[i]=eX
			eS=sqrt(eX2-eX^2)
			StanDev[i]=eS
			DMeann[i]=edX
			edS=sqrt(edX2-edX^2)
			DStanDev[i]=edS
		else // If we are not updating.  
			// Keep all values the same.  
			Paused[i]=1
			Meann[i]=Meann[i-1]
			StanDev[i]=StanDev[i-1]
			dMeann[i]=dMeann[i-1]
			dStanDev[i]=dStanDev[i-1]
		endif
	endfor
	
	KillWaves /Z dw
	SetScale /P x,0,delta,Meann,StanDev,Paused // Scales the results to start at 0 seconds and have the same sampling frequency as the input.  
	CopyScales /P w,Meann,StanDev
End

// Use successive median smoothing to cause a region of UP and DOWN to unanimously reflect the majority state in that region.  
Function Consolidation(w,minWidth_[,quantile])
	wave w // The wave of states to be consolidated.  Should contain 0's and 1's.  
	variable minWidth_ // The width of the area over which consolidation will occur.  
	variable quantile // The quantile (between 0 and 1) to use for assessing state.  
					// 0.5 uses the median, i.e. an area that is majority 'UP' will become all 'UP', and likewise for 'DOWN'.  
					// Other values would weight the consolidation so that e.g. an area that is only 20% 'UP' could be consolidate as being 'UP'.  
	
	quantile=ParamIsDefault(quantile) ?  0.5 : quantile // Use the median, i.e. majority rules.  
	
	Do
		variable minWidth=minWidth_
		duplicate /free w ComparisonWave
		
		variable i
		minWidth=round(minWidth/deltax(w)) // Convert from units to points.  
		minWidth+=(mod(minWidth,2)==0) ? 1 : 0 // Make the number of points odd so there can be a clear winner.  .  
		if(quantile==0.5) // If using the median.  
			Smooth /M=0 minWidth,w // Median smooth with width minWidth.  
		else // If using some other quantile, do boxcar smoothing, which isn't quite the same.  
			Smooth /B=1 minWidth,w
			w=w>quantile
			Smooth /B=1 minWidth,w
			w=w>quantile
		endif
	While(!equalWaves(w,ComparisonWave,1)) // Continue this process until median smoothing no longer affects the wave, i.e. all states that can be consolidated are already consolidated.  
End

// Produce a wave called 'Test' that can be used for testing the State Detector.  
function MakeFakeStates()
	Make /o/n=100000 Test
	make /free/n=100000 Downstate,Upstate=0
	SetScale x,0,10,Test,Downstate,Upstate
	Downstate=-x+gnoise((15-x)/5) // Scaling dx=0.0001, points=100000
	variable i=poissonnoise(5)*400
	do
		variable duration=poissonnoise(5)*400
		Upstate[i,i+duration-1]=sin(2*pi*(p-i)/10000)*10+10*gnoise(sin(2*pi*(p-i)/10000))^2		
		i+=poissonnoise(5)*2000
	while(i<100000)
	Test=(Downstate+Upstate)/10
End