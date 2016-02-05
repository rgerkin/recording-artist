
// $Author: rick $
// $Rev: 616 $
// $Date: 2012-12-05 14:46:20 -0700 (Wed, 05 Dec 2012) $

#pragma rtGlobals=1		// Use modern global access method.

function /wave ChungKennedy(w,mm,kk,pp[,pis])
	wave w // Data.  
	variable mm // Analysis window length.  
	variable kk // Number of filters.  
	variable pp // An exponent.  
	wave pis // The weights (pi_i) for the filters.  Has length kk.  
	
	if(paramisdefault(pis))
		make /free/n=(kk) pis = 1
	endif
	
	variable n = numpnts(w)
	make /free/n=(n,kk*2) estimates
	estimates[][0,kk] = mean(w,pnt2x(w,p-2^(q+1)),pnt2x(w,p-1)) // Forwards.  
	estimates[][kk,] = mean(w,pnt2x(w,p+1),pnt2x(w,p+2^(q+1-kk))) // Backwards.  
	
	make /free/n=(n,kk*2) weights
	make /free/n=(n,kk,mm) forwards = (w[p-r]-estimates[p-r][q])^2
	make /free/n=(n,kk,mm) backwards = (w[p+r]-estimates[p+r][q+kk])^2
	matrixop /free forwards = powR(sumbeams(forwards),-pp)
	matrixop /free backwards = powR(sumbeams(backwards),-pp)
	weights[][0,kk] = forwards[p][q]*pis[q]
	weights[][kk,] = backwards[p][q-kk]*pis[q-kk]
	
	// Normalize.  
	matrixop /free sums = sumrows(weights)
	weights /= sums[p]
	
	matrixop /free result = sumrows(estimates * weights)
	return result
end

function /wave RandomPhases(w[,width,trim])
	wave w
	variable width,trim
	
	width=paramisdefault(width) ? waveduration(w) : width
	//overlap = paramisdefault(overlap) ? 0 : overlap
	trim = paramisdefault(trim) ? 25 : trim
	width/=dimdelta(w,0)
	width = round(width)
	width -= mod(width,2) != 0 ? 1 : 0
	//overlap*=width
	variable i,numFFTs=floor(numpnts(w)/width)//1+floor((numpnts(w)-width)/(width-overlap))
	variable start=0
	for(i=0;i<numFFTs;i+=1)
		variable finish=start+width-1
		fft /rp=[start,finish]/mag/dest=tempMag w
		if(i==0)
			make /free/n=(numpnts(tempMag),numFFTs) amplitudes
		endif
		amplitudes[][i]=tempMag[p]
		start+=(width)//-overlap)
	endfor
	duplicate /o amplitudes,crap2
	killwaves /z tempMag
	make /free/n=(dimsize(amplitudes,0)) medians=RowTrimmedMean(amplitudes,p,trim=trim)//RowMedian(amplitudes,p)
	duplicate /free w,result
	result=0
	start=0
	do
		variable offset=0//result[start-1]
		variable points=numpnts(medians)
		make /free/n=(points) noise=enoise(pi)
		//make /free/n=(points) index=intnoise(numFFTs)
		//make /free/c/n=(points) sample=cmplx(cos(noise[p])*amplitudes[p][index[p]],sin(noise[p])*amplitudes[p][index[p]])
		make /free/c/n=(points) sample=cmplx(cos(noise[p])*medians[p],sin(noise[p])*medians[p])
		sample[0]=0
		ifft sample
		finish=min(start+width-1,numpnts(result)-1)
		result[start,finish]=offset+sample[p-start]
		start+=width
	while(start<numpnts(result))
	return result
end

function /wave AAFT(w[,width])
	wave w
	variable width
		
	width=paramisdefault(width) ? waveduration(w) : width
	width/=dimdelta(w,0)
	make /free/n=(numpnts(w)) surrogate=0
	variable i,offset=0,numFFTs=floor(numpnts(w)/width)
	for(i=0;i<numFFTs;i+=1)
		variable points=numpnts(w)/numFFTs
		variable start=i*points
		variable finish=start+points-1
		make /free/n=(points) wLeaderboard=p,wRanks=p,noises=enoise(pi)
		duplicate /free/r=[start,finish] w,w_
		sort w_,wLeaderboard
		sort wLeaderboard,wRanks
		make /free/n=(points) wNormal=statsinvnormalcdf((1+wRanks)/(1+points),0,1)
		variable pad=2^ceil(log2(points))
		//fft /pad=(pad)/dest=wFFT wNormal
		fft /dest=wFFT wNormal
		wFFT=cmplx(cos(noises[p])*cabs(wFFT[p]),sin(noises[p])*cabs(wFFT[p]))
		ifft /dest=wNormal wFFT
		//killwaves wFFT
		redimension /n=(points) wNormal
		make /free/n=(points) wNewLeaderboard=p,wNewRanks=p
		sort wNormal,wNewLeaderboard
		sort wNewLeaderboard,wNewRanks
		make /free/n=(points) surrogate_=w_[wLeaderboard[wNewRanks[p]]]
		//offset=surrogate_[0]-offset
		surrogate[start,finish]=surrogate_[p-start]//-offset
		//offset=surrogate[finish]
	endfor
	copyscales w,surrogate
	return surrogate
end

threadsafe function /wave ConvolveColumns(w,kernel) // Perform convolution using 'kernel' on each column of wave 'w'.  
	wave w,kernel
	
	variable rows=dimsize(w,0), columns=dimsize(w,1)
	make /free/wave/n=(columns) waves
	multithread waves=convolution(col(w,p),kernel) // This wave reference wave will store the free waves which contain the results of each column's convolution.  
	make /free/n=(rows,columns) w_
	make /free/n=(columns) dummy
	multithread dummy=setColumn(w_,waves[p],p) // Set each column of the final result to be equal to the column result pointed to by the wave reference wave.  
	return w_
end

threadsafe function /wave convolution(w,kernel)
	wave w,kernel
	
	variable rotate_=-numpnts(kernel)/2
	matrixop /free w_=rotaterows(convolve(w,kernel,0),rotate_)
	return w_
end

Function /wave RaisedCosineBasis(signal,freq,offset,num)
	wave signal // Signal of 0's and 1's, for example bins containing (or not) spikes.  
	variable freq,offset,num // e.g. freq=5, offset=1, num=7.  
	
	variable length=100 // TO DO: change this so it is computed from freq, offset, and num.  
	make /free/n=(length,num) raisedCosineBasis_
	setscale /p x,0,dimdelta(signal,0)*1000,raisedCosineBasis_ // Factor of 1000 needed to get spacing and stretching to work right.  
	raisedCosineBasis_= (abs(freq*log(x+offset) - q*pi/2) <= pi) ? (1+cos(freq*log(x+offset)-q*pi/2))/2 : 0
	duplicate /o raisedCosineBasis_ historyMu
	duplicate /o signal signal1
	rotate 1,signal1 // Rotate so that the spike time itself comes before the non-zero values of the convolution.  
	matrixop /o raisedCosines=convolve(raisedCosineBasis_,signal1,0)
	setscale /p x,0,dimdelta(signal,0),raisedCosines
	redimension /n=(-1,num) raisedCosines // For some reason convolution gives it an extra, useless column.  
	return raisedCosines
End

Function /wave TrackingBasis(signal,freq,offset,num)
	wave signal // Signal of 0's and 1's, for example bins containing (or not) spikes.  
	variable freq,offset,num // e.g. freq=5, offset=1, num=7.  
	
	variable length=100 // TO DO: change this so it is computed from freq, offset, and num.  
	make /free/n=(length,num) raisedCosineBasis_
	setscale /p x,0,dimdelta(signal,0)*1000,raisedCosineBasis_ // Factor of 1000 needed to get spacing and stretching to work right.  
	raisedCosineBasis_= exp(-x/2^q)
	duplicate /o raisedCosineBasis_ historyMu
	duplicate /o signal signal1
	rotate 1,signal1 // Rotate so that the spike time itself comes before the non-zero values of the convolution.  
	matrixop /o raisedCosines=convolve(raisedCosineBasis_,signal1,0)
	setscale /p x,0,dimdelta(signal,0),raisedCosines
	redimension /n=(-1,num) raisedCosines // For some reason convolution gives it an extra, useless column.  
	return raisedCosines
End

Function /wave PolynomialISIBasis(signal,freq,offset,num)
	wave signal // Signal of 0's and 1's, for example bins containing (or not) spikes.  
	variable freq,offset,num // e.g. freq=5, offset=1, num=7.  
	
	variable length=100 // TO DO: change this so it is computed from freq, offset, and num.  
	make /free/n=(length,num) raisedCosineBasis_
	setscale /p x,0,dimdelta(signal,0)*1000,raisedCosineBasis_ // Factor of 1000 needed to get spacing and stretching to work right.  
	raisedCosineBasis_= (x>0 ? ln(x)^(q+1) : 0)/10^3
	duplicate /o raisedCosineBasis_ historyMu
	duplicate /o signal signal1
	rotate 1,signal1 // Rotate so that the spike time itself comes before the non-zero values of the convolution.  
	matrixop /o raisedCosines=convolve(raisedCosineBasis_,signal1,0)
	setscale /p x,0,dimdelta(signal,0),raisedCosines
	redimension /n=(-1,num) raisedCosines // For some reason convolution gives it an extra, useless column.  
	//raisedCosines[length-1][]=raisedCosines[length-2][q] // Make up for the rotation by setting the last point equal to the next to last point.  
	return raisedCosines
End

Function /wave PhaseWavelets(signalDF,lowFreq,highFreq[,graph])
	dfref signalDF
	variable lowFreq,highFreq // Frequency band over which to do the calculation.  Choose this wisely.  NOT a fourier scale, but based on the scale of the wavelet.  Usually within a factor of 2 of the fourier scale.  
	variable graph // Graph the phase at each frequency over time, to confirm that we averaging over a band containing only one fundamental phase vs time relationship. 
	
	wave w=signalDF:data
	Duplicate /free w source
	wavestats /q/m=1/r=(0,0.02) source
	source-=v_avg // Subtract off baseline to avoid edge effects.  
	//Resample /DOWN=10 source
	variable start=1/highFreq
	variable numFreqs=100
	variable delta=log2(highFreq/lowFreq)/numFreqs
	variable length=numpnts(source)
	CWT /out=1 /WBI1=morletC /m=0 /r1={0,1,length} /r2={start,delta,numFreqs} /smp2=4 /endm=0 source
	wave /c m_cwt // A complex wave of wavelet coefficients.  
	//make /o/n=0 df:phase /wave=Phase
	//matrixop /o Phase=meancols(phase(m_cwt)^t) // Mean phase over the specificed frequency region, as a function of time.  
	// No!  Cannot average over angles since it is not that easy.  Must take cos and average over those, than invcos.  
	matrixop /free meanSin=meancols(sin(phase(m_cwt))^t) // Mean sin(phase) over the frequency region.  Note that phase here is the matrixop keyword, not the wave.  
	matrixop /free meanCos=meancols(cos(phase(m_cwt))^t) // Mean cos(phase) over the frequency region.  
	
	newdatafolder /o signalDF:Phase
	dfref df2=signalDF:Phase
	make /o/n=(numpnts(meanCos)) df2:data /wave=phase=atan(meanSin/meanCos) // Mean phase over the specificed frequency region, as a function of time.
	wave /z/sdfr=signalDF times
	if(waveexists(times))
		duplicate /o times df2:times
	endif
	string /g df2:type="ncs"
	
	Phase += (meanCos<0 ? pi : (meanSin<0 ? 2*pi : 0)) // Correction.  See StatsCircularMoments help for justification.  
	Phase -= pi // Convert from (0,2*pi) to (-pi,pi).   
	if(graph)
		matrixop /o phases=phase(m_cwt)
		copyscales m_cwt,phases
		//matrixop /free meann=meancols(mag(m_cwt))
		//wavestats /q meann
		wave w_cwtscaling
		//variable fourierScale=w_cwtscaling[v_maxloc]
		variable numTicks=10
		make /o/n=(numTicks) w_cwtscalingX=p*(numFreqs/numTicks)
		make /o/t/n=10 w_cwtscalingT=num2str(roundto(1/w_cwtscaling[p*10],1))
		if(graph!=2)
			display /k=1
			appendimage /l=left1 phases
			appendtograph /l=left2 /c=(0,0,65535) phase
			appendtograph /r=right /c=(65535,0,0) w
			ModifyGraph userticks(left1)={w_cwtscalingX,w_cwtscalingT}, tkLblRot=0, axisEnab(bottom)={0.05,1}, freePos(left1)={0.05,kwFraction}, freePos(left2)={0.05,kwFraction}, lblPos(left1)=50, lblPos(left2)=50
			ModifyGraph axisEnab(left1)={0,0.48},axisEnab(left2)={0.52,1},axisEnab(right)={0.52,1}
			setaxis left2 -pi,pi
			label left1 "Hz"
			label left2 "Radians"
			label bottom "s"
		endif
	endif
	killwaves /z m_cwt,phases
	copyscales source,Phase
	source+=v_avg
	Phase=numtype(source) ? NaN : Phase
	return Phase
End

Threadsafe Function /wave ts_DSPPeriodogram(w)
	wave w
	fft /mags /winf=Hanning /dest=$(nameofwave(w)+"_psd") /pad=(Pad2(w)) w
	wave psd=$(nameofwave(w)+"_psd")
	psd/=numpnts(w)
	//waveclear w_periodogram
	return psd 
End

// Generates a time-frequency matrix based on a windowed fourier transform.  Also see CWT and CWT2.  
threadsafe Function /WAVE ts_TimeFrequency(Source,winSize,winOverlap[,maxFreq,smoothing,fractional,logg])
	Wave Source
	Variable winSize // Size of the window for each transform, in the units of Source.  
	Variable winOverlap // Fractional overlap between windows.  
	variable maxFreq // The maximum frequency to keep.  
	Variable smoothing // Optional number of binomial smoothing passes for each windowed spectrum.  
	variable fractional // Express PSD as a fraction of the total power in the signal (across all frequencies) for each window.  
	variable logg // Take the logarithm (base 10) of the result.  
	
	if(winOverlap>0.99)
		//DoAlert 0,"Choose an overlap value less than 0.99"
		printf "Choose an overlap value less than 0.99.\r"
		return $""
	endif
	
	Variable i
	Variable numTransforms=numpnts(Source)*deltax(Source)/(winSize*(1-winOverlap))
	Variable winPoints=round(winSize/deltax(Source))
	String destName=NameOfWave(Source)+"_tf"
	variable yPoints=1+winPoints/2
	Make /o/n=(numTransforms,yPoints) $destName /WAVE=Dest
	Do
		Variable start=i*winPoints*(1-winOverlap)
		Variable finish=start+winPoints
		Duplicate /o/FREE/R=[start,finish-1] Source, TFWindow
		Wave TFSpectrum=ts_DSPPeriodogram(TFWindow)
		if(smoothing)
			Smooth smoothing,TFSpectrum
		endif
		ImageTransform /D=TFSpectrum /G=(i) putRow, Dest
		i+=1
	While(finish<numpnts(Source))
	killwaves /z TFWindow
	variable highest=wavemax(Dest)
	Redimension /n=(i,-1) Dest
	SetScale /P x,leftx(Source)+winSize/2,winSize*(1-winOverlap), Dest
	variable interval=1/(deltax(Source)*winPoints)
	SetScale /P y,-0.5*interval,interval, Dest
	if(fractional)
		matrixop /o Dest=powR(normalizecols(sqrt(Dest)),2)
	endif
	if(maxFreq)
		variable maxFreqPoint=(maxFreq-dimoffset(Dest,1))/dimdelta(Dest,1)
		redimension /n=(-1,ceil(maxFreqPoint)) Dest
	endif
	if(logg)
		Dest=log(Dest)
	endif
	KillWaves /Z TFSpectrum
	return Dest
End

// Follow a maximum ridge in a 2D image/matrix 'w'.  
Function /wave RidgeFollow(w)
	wave w  
	
	make /o/n=0 xRidge,yRidge
	duplicate /free w,north,east
	matrixfilter gradN north
	matrixfilter gradE east
	variable i=0,xx=0, yy=dimsize(w,1)/2 // Starts at the far left, halfway between the top and bottom.  
	do
		if(north[xx][yy]<east[xx][yy])
			xx+=1
		elseif(abs(enoise(1))<0.05) // Random perturbation to escape from local extrema.  
			xx+=1
		elseif(north[xx][yy]>=0)
			yy+=1
		else
			yy-=1
		endif
		xRidge[i]={xx}
		yRidge[i]={yy}
		i+=1
	while(xx<dimsize(w,0))
	xRidge=dimoffset(w,0)+dimdelta(w,0)*xRidge
	yRidge=dimoffset(w,1)+dimdelta(w,1)*yRidge
	string name=getwavesdatafolder(w,2)+"_ridge"
	make /o/n=(dimsize(w,0)) $name /wave=ridge
	copyscales w,ridge
#if exists("Interpolate2")==4
	Interpolate2 /T=2 /I=3 /Y=$name xRidge, yRidge // cannot put 'ridge' here in place of '$name'.   
#else
	DoAlert 0,"The Interpolate2 operation was not found.  Is the Interpolate XOP loaded?"
#endif
	killwaves /z xRidge,yRidge
	return ridge
End

Function /wave GaborTransform(w)
	wave w
	
	duplicate /free w,windowed
	wavestats /q/m=1 windowed
	windowed-=v_avg
	make /o/n=(4/deltax(w)) windowF
	setscale x,-2,2,windowF
	windowF=exp(-pi*(x)^2)
	variable summ=sum(windowF)
	windowF/=summ
	convolve /a windowF windowed
	wave gabor=TimeFrequency(windowed,4,0.9,destName=nameofwave(w)+"_gwt")
	return gabor
End

// Computes the Gaussian-Weighted Wigner Transform.  
Function /wave GWT(w,gwidth)
	wave w
	variable gwidth
	
	wavestats /q/m=1 w
	variable avg=v_avg
	w-=v_avg
	WignerTransform /DEST=$(getwavesdatafolder(w,2)+"_gwt") /GAUS=(gwidth) w
	w+=v_avg
	wave gwt=$(getwavesdatafolder(w,2)+"_gwt")
	copyscales w,gwt
	return gwt
End

ThreadSafe Function /wave SincFilters(w,bands[,points])
	wave w
	string bands // As many semicolon-separated lo and hi cutoffs as you want.  Each one should be a comma-separated pair.  Leave part of it blank
	// to do only a lo or only a hi, e.g. ",5;59,61"
	variable points
	
	if(paramisdefault(points))
		points=min(10000,2*round(numpnts(w)/4))
	endif
	make /free/n=(points) kernel=0
	variable i
	for(i=0;i<itemsinlist(bands);i+=1)
		string band=stringfromlist(i,bands)
		variable lo=str2num(stringfromlist(0,band,","))
		variable hi=str2num(stringfromlist(1,band,","))
		make /free/n=(points) one_kernel=0
		if(!numtype(lo))
			wave lo_kernel=SincFilterKernel(points,lo*dimdelta(w,0),0) // Low-pass.  
			one_kernel+=lo_kernel
		endif
		if(!numtype(hi))
			wave hi_kernel=SincFilterKernel(points,hi*dimdelta(w,0),1) // High-pass.  
			one_kernel+=hi_kernel
		endif
		if(lo>hi) // Band-pass.  
			// Spectral inversion.  
			one_kernel*=-1 
			one_kernel[points/2]+=1
		else // Band-reject.
			// Coefficients are already ready.  
		endif
		kernel+=one_kernel
	endfor
	duplicate /o kernel poop
	filterfir /coef=kernel /winf=none w // This is basically convolution of the filtering kernel with the data.  
	return w
End

ThreadSafe Function /wave SincFilter(w,[lo,hi,points,order])
	wave w
	variable lo,hi,points,order
	
	if(paramisdefault(points))
		points=min(10000,2*round(numpnts(w)/4))
	endif
	make /free/n=(points) kernel=0
	if(!paramisdefault(lo))
		wave lo_kernel=SincFilterKernel(points,lo*dimdelta(w,0),0) // Low-pass.  
		kernel+=lo_kernel
	endif
	if(!paramisdefault(hi))
		wave hi_kernel=SincFilterKernel(points,hi*dimdelta(w,0),1) // High-pass.  
		kernel+=hi_kernel
	endif
	if(!paramisdefault(lo) && !paramisdefault(hi))
		if(lo>hi) // Band-pass.  
			// Spectral inversion.  
			kernel*=-1 
			kernel[points/2]+=1
		else // Band-reject.
			// Coefficients are already ready.  
		endif  
	endif
	variable i
	duplicate /free kernel finalKernel
	for(i=1;i<order;i+=1)
		convolve kernel,finalKernel
	endfor
	filterfir /coef=finalKernel /winf=none w // This is basically convolution of the filtering kernel with the data.  
	return w
End

Threadsafe Function /wave SincFilterKernel(points,freq,invert)
	variable points // Number of points in the kernel.  
	variable freq // Frequency for cutoff (as a fraction of the sampling frequency).  
	variable invert // Invert the kernel (produce high-pass instead of low-pass).  
	
	make /d/free/n=(points+1) Coefs=(sin(2*pi*freq*(x-points/2))/(x-points/2)) // Make a sinc wave centered at points/2.  
	coefs[points/2]=2*pi*freq // Fill the center point since 0/0 is undefined.  
	variable summ=sum(coefs)
	coefs/=summ // Normalize so the gain is unity.  
	if(invert) // Spectral inversion.  
		coefs*=-1
		coefs[points/2]+=1
	endif
	WindowFunction blackman367, coefs // Window the sinc filter with a Blackman window.  
	return coefs
End

// Finds crossings of the value 'trig' in 'Wav' such that after each crossing, no additional crossings can be counted until 'retrig' has also been crossed.  
Function /S FindLevelsRetrig(Wav,trig,retrig)
	Wave Wav
	Variable trig,retrig
	Make /o TrigLevels,RetrigLevels
	FindLevels /Q /D=TrigLevels Wav,trig
	FindLevels /Q /D=RetrigLevels Test,retrig
	Variable i=1,j=0
	Do
		if(TrigLevels[i]<RetrigLevels[j])
			DeletePoints i,1,TrigLevels
		else
			Do
				j+=1
			While(RetrigLevels[j]<TrigLevels[i] && j<numpnts(RetrigLevels))
			i+=1
		endif
	While(i<numpnts(TrigLevels))
	KillWaves /Z RetrigLevels
	return GetWavesDataFolder(TrigLevels,2)
End

Function InterpolationKnots(SourceWave,threshold)
	Wave SourceWave
	Variable threshold

	Make /o/n=2 knotLocs,knotVals // A wave of knot locations and wave of values at those locations.  
	
	// Start with the endpoints.  
	knotLocs={leftx(SourceWave),rightx(SourceWave)}
	knotVals=SourceWave(knotLocs)
	
	// Add new knots recursively, by taking an adjacent pair of knots and seeing if knew knots should be added between those knots.  
#if exists("Interpolate2")
	Variable i=1
	Do
		Duplicate /O /R=(knotLocs(i-1),knotLocs(i)) SourceWave xData
		Interpolate2 /I=3 /T=1 /Y=xData knotLocs,knotVals // Creates an straight line between the knots.  
		xData-=SourceWave(x) // The difference betwene the straight line (the estimate) and the real data between the knots.  
		WaveTransform /O abs xData // The absolute value of this difference.  
		WaveStats /Q xData
		Variable length=rightx(xData)-leftx(xData)
		
		// If the maximum of this difference, or its average, or its integral exceeds a threshold, add a new knot.  
		if(V_max>threshold || V_avg>threshold/3 || V_avg*length>threshold/10)
			InsertPoints i,1,knotLocs,knotVals
			knotLocs[i]=V_maxloc
			knotVals[i]=SourceWave(knotLocs[i])
		else
			i+=1
		endif
	While(i<numpnts(knotLocs))
#else
	DoAlert 0,"Need Interpolate XOP."
	return -1
#endif
	
	// Remove from both waves any consecutive duplicate values that occur in the wave of locations.  
	Extract /O knotVals,knotVals,p==0 || knotLocs[p]!=knotLocs[p-1]
	Extract /O knotLocs,knotLocs,p==0 || knotLocs[p]!=knotLocs[p-1]
	
	// Display the knot-based version of the original data.  
	// AppendToGraph knotVals vs knotLocs
End

Function ReduceAll()
	Variable tick=ticks
	Variable i,j,sweep_num
	SVar channels=root:parameters:ActiveChannels
	String channel,periodic_stims=""
	Display /K=1 /N=Reductions
	NewDataFolder /O root:reanalysis
	NewDataFolder /O/S root:reanalysis:SweepReductions
	Variable insig_val,num_stims,start,interval,duration
	Variable old_points=0,new_points=0 
	NVar final_sweep=root:status:currentSweepNum
	Make /o/n=0 Empty
	String /G compress_method="Homebrew 2006"
	
	for(i=0;i<ItemsInList(channels);i+=1)
		channel=StringFromList(i,channels)
		NewDataFolder /O/S $("root:reanalysis:SweepReductions:"+channel)
		Wave SweepParams=$("root:status:sweep_parameters_"+channel)
		for(sweep_num=1;sweep_num<=final_sweep;sweep_num+=1)
		//for(sweep_num=42;sweep_num<=42;sweep_num+=1)
			RemoveTraces()
			periodic_stims=""
			if(exists("root:cell"+channel+":sweep"+num2str(sweep_num)))
				AppendToGraph $("root:cell"+channel+":sweep"+num2str(sweep_num))
				Wave toReduce=$("root:cell"+channel+":sweep"+num2str(sweep_num))
				if(SweepParams[sweep_num][5]==1) // Voltage Clamp
					insig_val=10
				elseif(SweepParams[sweep_num][5]==0) // Current Clamp
					insig_val=1
				else
					printf "Clamp for sweep %d is unknown.\r",sweep_num
					insig_val=max(insig_val,1)
				endif
				WaveStats /Q/R=(0,0.1) toReduce
				num_stims=SweepParams[sweep_num][2]
				for(j=0;j<num_stims;j+=1) // For each stimulus of this channel during the sweep
					start=SweepParams[sweep_num][4]
					interval=SweepParams[sweep_num][3]
					duration=SweepParams[sweep_num][0]
					periodic_stims+=num2str((start+j*interval)/1000-0.001)+","+num2str((start+j*interval+duration)/1000+0.005)+";"
				endfor
				if(V_max>-1000 && V_sdev<500)
					Reduce(toReduce=toReduce,insig_val=insig_val,line_remove=1,periodic_stims=periodic_stims,to_append=1)
					Wave alllocs=alllocs
					old_points+=numpnts(toReduce)
					new_points+=numpnts(alllocs)
					Duplicate /o alllocs $("locs_"+num2str(sweep_num))
					Duplicate /o allvals $("vals_"+num2str(sweep_num))
				else
					Duplicate /o Empty $("locs_"+num2str(sweep_num))
					Duplicate /o Empty $("vals_"+num2str(sweep_num))
				endif
				DoUpdate
				printf "%s: %d\r",channel,sweep_num
			endif
		endfor
	endfor
	tick=ticks-tick
	printf "Ratio = 2 * %d / %d = %.2f in %.2f seconds.\r",new_points,old_points,100*2*new_points/old_points,tick/60
	root()
End

Function ExpFilter(theWave,tau[,points])
	Wave theWave
	Variable tau,points
	Variable delta=dimdelta(theWave,0)
	points=ParamIsDefault(points) ? 200 : points
	Make /o/n=(points) Filter
	SetScale /P x,0,delta,Filter
	Filter=exp(-x/tau)
	WaveStats /Q Filter
	Filter/=(V_avg*V_npnts)
	Variable start_points=numpnts(theWave)
	Convolve Filter,theWave
	Redimension /n=(start_points) theWave
	KillWaves /Z Filter
End

// Applies a DWT filter.  Use whole numbers for low, high, type, and num.  
Function DWTFilter(theWave[low,high,thresh,type,num])
	Wave theWave
	Variable low, high, thresh, type, num
	Variable delta=dimdelta(theWave,0)
	Variable offset=dimoffset(theWave,0)
	Variable points=numpnts(theWave)
	type=ParamIsDefault(type) ? 1 : type
	num=ParamIsDefault(num) ? 4 : num
	DWT /P=1/T=(type)/N=(num) theWave,Dwtd
	if(!ParamIsDefault(low))
		//for(i=0;i<=low;i+=1)
			DWTd[0,2^low]=0
		//endfor
	endif
	if(!ParamIsDefault(high))
		DWTd[2^high,inf]=0
	endif
	if(!ParamIsDefault(thresh))
		DWTd=(abs(DWTd)>thresh)? DWTd : 0
	endif
	DWT /I/P=2/T=(type)/N=(num) DWTd,$GetWavesDataFolder(theWave,2)
	Redimension /n=(points) theWave
	SetScale /P x,offset,delta,theWave
End

// Do the DWT, set all values below a threshold to zero, save the locations and values of non-zero values.  
Function /S DWTDenoise(theWave,threshold[,type,coefs])
	Wave theWave
	Variable threshold
	Variable type // Type of wavelet
	Variable coefs // Number of wavelet coefficients
	type=ParamIsDefault(type) ? 1 : type
	coefs=ParamIsDefault(coefs) ? 4 : coefs
	
	Variable start=dimoffset(theWave,0)
	Variable delta=dimdelta(theWave,0)
	
	// Do the DWT and set values below a set threshold to zero.  
	DWT /P=2 /T=(type) /N=(coefs) theWave,Dwtd
	Dwtd=(abs(dwtd)>threshold) ? Dwtd : 0
	Extract /INDX /O Dwtd,AllLocs,Dwtd!=0//; Wave AllLocs
	Extract /O Dwtd,AllVals,Dwtd!=0//; Wave AllVals
		
	// Do the inverse DWT and plot it on top of the original sweep, so they can be compared.  
	String dest_name=GetWavesDataFolder(theWave,2)+"_denoised"
	DWT /P=2 /I /T=(type) /N=(coefs) Dwtd,$dest_name
	SetScale /P x,start,delta,$dest_name
	KillWaves /Z Dwtd
	return dest_name
End

Function PSD(w[,winSize,overlap])
	wave w
	variable winSize,overlap
	
	winSize=paramisdefault(winSize) ? 3000 : round(winSize/dimdelta(w,0))
	winSize=min(numpnts(w),winSize)
	overlap=paramisdefault(overlap) ? 0.9 : overlap
	overlap=round(overlap*winSize)
	
	string destName=NameOfWave(w)+"_psd"
	DSPPeriodogram /q/segn={(winSize),(overlap)} w
	duplicate /o w_periodogram $destName /wave=psd
	string win=CleanupName("win_"+destName,0)
	if(WinType(win))
		DoWindow /F $win
	else
		Display /N=$(win) psd as "Power Spectral Density of "+NameOfWave(w)
		ModifyGraph log=1
		string d_units=StringByKey("DUNITS",WaveInfo(w,0))
		string x_units=StringByKey("DUNITS",WaveInfo(psd,0))
		if(strlen(d_units) && strlen(x_units))
			Label left "PSD "+(d_units)+"\S2\M/"+x_units
		endif
		Label bottom "Hz"
	endif	
End

// 
//  simpleICA(inX,reqComponents,w_init)
//  Parameters:
// 	inX is a 2D wave where columns contain a finite mix of independent components.
// 	reqComponents is the number of independent components that you want to extract.
//		This number must be less than or equal to the number of columns of inX.
//	w_init is a 2D wave of dimensions (reqComponents x reqComponents) and contains 
//  		an estimate of the mixing matrix.  You can simply pass $"" for this parameter
//		so the algorithm will use an equivalent size matrix filled with enoise().
//
//	The results of the function are the waves ICARes and WunMixing.  ICARes is a 2D 
//	wave in which each column contains an independent component.  WunMixing is a 2D
// 	wave that can be used to multiply the (re)conditioned input in order to obtain the unmixed 
//	components.
//
//	The code below implements the "deflation" approach for fastICA.  It is based on the 
//	fastICA algorithm: Hyvärinen,A (1999). Fast and Robust Fixed-Point Algorithms 
//	for Independent Component Analysis. IEEE Transactions on Neural Networks, 10(3),626-634.
// 	
//	 See testing example below the main function.
Function simpleICA(inX,reqComponents,w_init[,verbose])
	wave inX
	wave /z w_init
	variable reqComponents,verbose
 
	// The following 3 variables can be converted into function arguments.
	Variable maxNumIterations=1000
	Variable tolerance=1e-5
	Variable alpha=1
 
	Variable i,ii
	Variable iteration 
	Variable nRows=DimSize(inX,0)
	Variable nCols=DimSize(inX,1)
 
	// check the number of requested components:
	if(reqComponents>min(dimSize(inX,0),dimSize(inX,1)))
		doAlert 0,"Bad requested number of components"
		return 0
	endif
 
	// Never mess up the original data
	Duplicate/O/Free inX,xx					
 
	// Initialize the w matrix if it is not provided.	
	if(WaveExists(w_init)==0)
		Make/O/N=(reqComponents,reqComponents) w_init=enoise(1)
	endif
 
	// condition and transpose the input:
	MatrixOP/O xx=(NormalizeCols(subtractMean(xx,1)))^t
 
	// Just like PCA:
	MatrixOP/O/Free V=(xx x (xx^t))/nRows
	MatrixSVD V
	// M_VT is not used here.
	Wave M_U,W_W,M_VT									
	W_W=1.0/sqrt(w_w)
	MatrixOP/O/Free D=diagonal(W_W)
	MatrixOP/O/FREE K=D x (M_U^t)			
	KillWaves/z W_W,M_U,M_VT			 
 
	Duplicate/Free/R=[0,reqComponents-1][] k,kk
	Duplicate/O/FREE kk,k									
 
	// X1 could be output as PCA result.	
	MatrixOP/O/FREE X1=K x xx								
	// create and initialize working W; this is not an output!
	Make/O/Free/N=(reqComponents,reqComponents) W=0						
 
	for(i=1;i<=reqComponents;i+=1)										
		MatrixOP/O/FREE lcw=row(w_init,i-1)
               // decorrelating 							
		if(i>1)													
			Duplicate/O/Free lcw,tt									
			tt=0												
			for(ii=0;ii<i;ii+=1)
				MatrixOP/O/Free r_ii=row(W,ii)				// row ii of matrix W		
				MatrixOP/O/FREE ru=sum(lcw*r_ii)			// dot product		
				Variable ks=ru[0]
				MatrixOP/O/Free tt=tt+ks*r_ii							
			endfor
			MatrixOP/O/FREE lcw=lcw-tt								
		endif
		MatrixOP/O/Free lcw=normalize(lcw)						
		// iterate till convergence:	
		for(iteration=1;iteration<maxNumIterations;iteration+=1)				
			MatrixOP/O/Free wxProduct=lcw x x1						
			// should be supported by matrixop :(
			Duplicate/O/Free wxProduct,gwx
			gwx=tanh(alpha*wxProduct)									
			Duplicate/Free/R=[reqComponents,nRows] gwx,gwxf				 
			Make/O/Free/N=(reqComponents,nRows) gwxf
			// repeat the values from the first row on.
			gwxf=gwx[q]										
			Duplicate/O/FREE gwxf,gwx
			MatrixOP/O/Free x1gwxProd=x1*gwx							 
			Duplicate/O/FREE wxProduct,gwx2									 
			gwx2=alpha*(1-(tanh(alpha*wxProduct))^2)
			Variable theMean=mean(gwx2)
			MatrixOP/O/Free    wPlus=(sumRows(x1gwxProd)/numCols(x1gwxProd))^t-theMean*lcw	
			// reduce components						 
			Redimension/N=(1,reqComponents) wPlus				
			// starting from the second component;
			if(i>1)												
				Duplicate/O/FREE wPlus,tt									 
				tt=0												 
				for(ii=0;ii<i;ii+=1)					                  
					MatrixOP/O/Free r_ii=row(W,ii)				 
					MatrixOP/O/FREE ru=wPlus.(r_ii^t)							 
					ks=ru[0]
					MatrixOP/O tt=tt+ks*r_ii							 
				endfor										            
				wPlus=wPlus-tt							       			 
			endif
			MatrixOP/O/FREE wPlus=normalize(wPlus)							 
			MatrixOP/O/Free limV=abs(mag(sum(wPlus*lcw))-1)		
			if(verbose)
				printf "Iteration %d, diff=%g\r",iteration,limV[0]
			endif
			lcw=wPlus
			if(limV[0]<tolerance)
				break
			endif
		endfor
		// store the computed row in final W.
        	W[i-1][]=lcw[q]													
	endfor			// loop over components
 
	//  Calculate the un-mixing matrix
	MatrixOP/O WunMixing=W x K					
	// 	Un-mix; 					
	MatrixOP/O ICARes=(WunMixing x xx)^t	
	// Save estimate of mixing matrix.  
	matrixop /o WMixing=inv(ICARes^t x ICARes) x ICARes^t x inX						
End

// Filters out line noise with a frequency that has a period of 'period' in points.  
Function FilterPeriodNoise(theWave,period)
	Wave theWave
	Variable period
	//WaveStats /Q/M=1 theWave//Extract /o theWave,FHNOdds,mod(p,2)==1
	//Variable meann=V_avg
	//WaveStats /Q/M=1 FHNOdds; Variable oddMean=V_avg
	//KillWaves /Z FHNOdds
	Variable delta_x=deltax(theWave),start_x=leftx(theWave)
	Redimension /n=(period,numpnts(theWave)/period) theWave
	MatrixOp /O theWave=subtractMean(theWave,2)
	Redimension /n=(numpnts(theWave)) theWave
	SetScale /P x,start_x,delta_x,theWave
	//theWave+=V_avg
	//Extract /o theWave,FHNEvens,mod(p,2)==0
	//WaveStats /Q/M=1 FHNEvens; Variable evenMean=V_avg
	//KillWaves /Z FHNEvens
	//theWave-=mod(p,2)==1 ? oddMean : evenMean
	//theWave+=(oddMean+evenMean)/2
End

// Finds the location of the strongest peak in the correlogram, constrained to fall within minn and maxx.  
Function StrongestCorrelationLag(theWave[,minn,maxx])
	Wave theWave
	Variable minn,maxx
	Duplicate /o theWave tempSCL
	WaveStats /Q tempSCL; tempSCL=V_avg
	Correlate tempSCL,tempSCL
	//WaveStats /Q /R=(minn,maxx)
End

Function RemoveArtifacts(theWave,interval,width,thresh,direction)
	Wave theWave
	Variable interval,width,thresh
	String direction
	//Variable down,up // Remove pulses going downwards; remove pulses going upwards.  
	//Variable preserve_spikes // For current clamp data, preserves regions with spikes.  
	//interval=ParamIsDefault(interval) ? 10 : interval
	//width=ParamIsDefault(width) ? 0.16 : width
	//down=ParamIsDefault(down) ? 1 : down
	//up=ParamIsDefault(up) ? 0 : up
	Variable i,min_loc,max_loc,duration=rightx(theWave)-leftx(theWave)
	if(StringMatch(direction,"down"))
		for(i=leftx(theWave);i<rightx(theWave);i+=0)
			WaveStats /Q/R=(i,i+interval*1.1) theWave; min_loc=V_minloc
			WaveStats /Q/R=(min_loc-width,min_loc+width) theWave
			i=min_loc+1
		endfor
	endif
	if(StringMatch(direction,"up"))
		for(i=leftx(theWave);i<rightx(theWave);i+=0)
			WaveStats /Q/R=(i,i+interval*1.5) theWave; max_loc=V_maxloc
			WaveStats /Q/R=(max_loc-width,max_loc+width) theWave
			theWave[x2pnt(theWave,max_loc-width),x2pnt(theWave,max_loc+width)]=NaN
			i=max_loc+1
		endfor
	endif
#if exists("Interpolate2")
	Interpolate2 /T=1/Y=TempTestPulses theWave; Wave TempTestPulses
	theWave=IsNaN(theWave) ? TempTestPulses : theWave 
#endif
	KillWaves /Z TempTestPulses
End

// Returns the percentage of points correspond to the slowest time-scale n DWTs out of a total of big_n DWTs.  
// A wave of size between 2^(big_n-1) and 2^big_n will have big_n DWTs.  
Function DWTTool(n,big_n)
	Variable n,big_n
	Variable i,result=0
	for(i=1;i<=n;i+=1)
		result+=(2^i)
	endfor
	return 100*(result/(2^big_n))
End

// A reduced representation of a wave (peaks,troughs, whose x-values are derived from smoothing factor 
// smooth_factor, but whose y-values come from the original wave.  It's a pretty awesome compression 
// algorithm that I made up.  
Function Reduce([toReduce,first,last,smooth_val,insig_val,line_remove,to_append,periodic_stims])
	Wave toReduce
	Variable first,last,smooth_val,insig_val,line_remove,to_append
	String periodic_stims
	// Set optional parameters to defaults
	if(ParamIsDefault(toReduce))
		Wave toReduce=CsrWaveRef(A)
	endif
	Duplicate /o toReduce $("W_"+NameOfWave(toReduce))
	Wave theWave=$("W_"+NameOfWave(toReduce))
	first=ParamIsDefault(first) ? leftX(theWave) : first
	last=ParamIsDefault(last) ? rightX(theWave) : last
	smooth_val=ParamIsDefault(smooth_val) ? 15 : smooth_val
	insig_val=ParamIsDefault(insig_val) ? 10 : insig_val
	if(line_remove)
		LineRemove(theWave,freqs="60",width=1,harmonics=10)
	endif
	Duplicate /o theWave smoothed
	Smooth smooth_val,smoothed
	Make /o/n=2 alllocs, allvals
	// Collect more samples in areas where the difference between reduced representation and actual data is great
	alllocs={leftx(smoothed),rightx(smoothed)}  // (1)
	allvals={smoothed(leftX(smoothed)),smoothed(rightx(smoothed))} // (2)
	AddSignificantPeaks(smoothed,alllocs,allvals,insig_val=insig_val)
	// Remove from both waves consecutive duplicate values that occur in the wave of locations
	RemoveRedundancies("alllocs;allvals")
	// Append the reduced representation to the graph
	to_append=ParamIsDefault(to_append) ? 0 : to_append
	if(to_append)
//		CleanAppend("smoothed",color="0,0,65535")
//		CleanAppend("allvals",color="0,0,0",versus="alllocs")
		RemoveFromGraph /Z smoothed,allvals
		AppendToGraph /c=(0,0,65535) smoothed
		AppendToGraph /c=(0,0,0) allvals vs alllocs
	endif
End

// Filter out steps
Function StepFilter(w[,threshold,width,level])
	Wave w
	Variable threshold // The maximum derivative (rise per second) that will be tolerated.  
	Variable width // The width of the filter in seconds. 
	Variable level // Set the two sides opposite the step to be approximately equal in level.  
	threshold=ParamIsDefault(threshold) ? 50000 : threshold
	width=ParamIsDefault(width) ? 1 : width
	level=ParamIsDefault(level) ? 0 : level
	
	// Set any big jumps to 0.  
	Differentiate /METH=2 w
	WildPoint2(w,width,threshold,f_flag=0) // Replace wild points in the derivative (locations of steps) with NaN.  
	extract /free/indx w,nans,numtype(w)
	w=numtype(w) ? 0 : w // Replace NaNs with zero.  
	Integrate w
	
	if(level)
		Variable i
		for(i=0;i<numpnts(nans);i+=1)
			variable point=nans[i]
			duplicate /o/free/r=[0,point-1] w before
			duplicate /o/free/r=[point+1,] w after
			variable diff=statsmedian(after)-statsmedian(before)
			w[point+1,numpnts(theWave)-1]-=diff
		endfor
	endif
End

// Filter out single points that wildly differ from the local median.  
Function WildPoint2(w,width,threshold[,f_flag])
	wave w
	Variable threshold // The amount a point must differ from the local median to be replaced with the median. 
	Variable width // The width of the filter in seconds.  
	Variable f_flag
	f_flag=ParamIsDefault(f_flag) ? 1 : f_flag
	Variable scale=dimdelta(w,0)
	Variable width_points=round(width/scale)
	width_points=(mod(width_points,2)==0) ? width_points - 1 : width_points
#if(exists("Wildpoint"))
	if(f_flag)
		WildPoint /F w,width_points,threshold
	else
		WildPoint w,width_points,threshold
	endif
#else
	if(f_flag)
		Smooth /M=(threshold) width, w
	else
		Smooth /M=(threshold) /R=(NaN) width, w
	endif
#endif
End

// Compute the CWT for all waves in a folder and show all the images.  
Function CWTFolder([folder])
	String folder
	String curr_folder=GetDataFolder(1)
	if(ParamIsDefault(folder))
		folder=""
	endif
	SetDataFolder $folder
	String waves=WaveList("*",";","")
	Variable i; String wave_name
	for(i=0;i<ItemsInList(waves);i+=1)
		wave_name=StringFromList(i,waves)
		Wave oneWave=$wave_name
		CWT2(oneWave,start=2,delta=2,num=400,downsample=10,image_downsample=10,noPlot=0)
		DoUpdate
		NVar image_minn,image_maxx
		//ModifyImage $TopImage() ctab={image_minn,V_max/2,Rainbow,0}
	endfor
	KillVariables /Z minn,maxx
	SetDataFolder $curr_folder
End

// Compute FFTs for all the waves in a folder, calculating magnitudes.
Function FFTFolder()
	String waves=WaveList("*",";","")
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O :FFTs
	Variable i; String wave_name
	for(i=0;i<ItemsInList(waves);i+=1)
		wave_name=StringFromList(i,waves)
		Wave oneWave=$wave_name
		if(mod(numpnts(oneWave),2)!=0)
			PadWithLast(oneWave,1)
		endif
		FFT /MAG /DEST=$(curr_folder+"FFTs:'"+wave_name+"_FFT'") oneWave
	endfor
	//SetDataFolder ::
End

// Does the Discrete Wavelet Transform and displays each scale on a separate row.
Function DWT2(signal)
	Wave signal
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:DWTs
	DWT /P=1 /T=64 /N=4 signal // Use splines (/T=64)
	Wave W_DWT
	Variable i,scale,max_scale=log(numpnts(W_DWT))/log(2)
	Display /K=1
	for(i=numpnts(W_DWT);i>1;i/=2)
		scale=log(i)/log(2)
		Duplicate /O/R=[i/2,i-1] W_DWT $("Scale_"+num2str(scale))
		Wave currScale=$("Scale_"+num2str(scale))
		SetScale /I x,leftx(signal),rightx(signal),currScale
		AppendToGraph /L=$("Scale_"+num2str(scale)) currScale
		ModifyGraph axisEnab($("Scale_"+num2str(scale)))={(scale-1)/max_scale+0.02,scale/max_scale}
		ModifyGraph freepos($("Scale_"+num2str(scale)))={0,bottom}
		ModifyGraph fsize($("Scale_"+num2str(scale)))=8, btLen($("Scale_"+num2str(scale)))=1
	endfor
	ModifyGraph margin(left)=30
	//ModifyGraph fsize=8
	SetDataFolder $curr_folder
End

// Downsamples a wave in the current directory (2 dimension maximum).  Factor must be an integer.  
Function /S DownSample(theWave,factor[,dim,in_place,new_name])
	Wave theWave
	Variable factor,dim,in_place // If you want to downsample in place of the source of wave, set this to 1
	String new_name // New name for the downsampled wave.  
	if(WaveType(theWave)==0)
		return GetWavesDataFolder(theWave,2)
	endif
	dim=ParamIsDefault(dim) ? 0 : dim // The first dimension unless another dimension is specified
	Variable i
	
	if(ParamIsDefault(new_name))
		String new_wave_name=NameOfWave(theWave)+"_ds"//GetWavesDataFtheer(theWave,2)+"_ds"
		new_wave_name=CleanupName(new_wave_name,1)
	else
		new_wave_name=new_name
	endif
	Make /o/n=0 $new_wave_name
	Wave new_wave=$new_wave_name
	Note /NOCR new_wave, "Downsample="+num2str(factor)+";Source="+GetWavesDataFolder(theWave,2)+";"
	Make /o/n=4 DSDims=dimsize(theWave,p)
	DSDims[dim]=floor(dimsize(theWave,dim)/factor)
	Redimension /n=(DSDims[0],DSDims[1],DSDims[2],DSDims[3]) new_wave
	//new_wave=theWave[p*factor0][q*factor1]//[r*factor2][s*factor3] // This requires some kind of smoothing.  
	Variable first=dimoffset(theWave,dim)
	Variable delta=dimdelta(theWave,dim)
	switch(dim)
		case 0:
			SetScale /P x,first+delta*factor/2,delta*factor,new_wave
			break
		case 1:
			SetScale /P y,first+delta*factor/2,delta*factor,new_wave
			break
		case 2:
			SetScale /P z,first+delta*factor/2,delta*factor,new_wave
			break
		case 3:
			SetScale /P t,first+delta*factor/2,delta*factor,new_wave
			break
	endswitch
	new_wave=mean(theWave,x-delta*factor/2,x+delta*factor/2) // Not multidimensional aware!  
	if(in_place)
		new_wave_name=GetWavesDataFolder(theWave,2) // The same as the name of the the wave
		Duplicate /o new_wave,$new_wave_name
		KillWaves /Z new_wave
	endif
	KillWaves /Z DSDims
	return new_wave_name
End

Function DownSample2(theWave,factor)
	Wave theWave
	Variable factor
	Make /o/n=(numpnts(theWave)) Temp1=theWave[p]
	Make /o/n=(numpnts(theWave)/factor) Temp2
	Temp2=mean(Temp1,x*factor,(x+1)*factor-1)
	SetScale /P x,dimOffset(theWave,0),factor*dimDelta(theWave,0),Temp2
	Duplicate /o Temp2,theWave
	KillWaves Temp1,Temp2
End

// Downsample all the waves in a folder.  
Function Downsample3(factor[,folders,in_place,except])
	Variable factor, in_place
	String folders,except
	if(ParamIsDefault(folders))
		folders=GetDataFolder(1)
	endif
	if(ParamIsDefault(except))
		except=""
	endif
	
	Variable i,j
	String curr_folder=GetDataFolder(1)
	for(j=0;j<ItemsInList(folders);j+=1)
		String folder=StringFromList(j,folders)
		SetDataFolder $folder
		String wave_list=WaveList("*",";","TEXT:0")
		for(i=0;i<ItemsInList(wave_list);i+=1)
			String wave_name=StringFromList(i,wave_list)
			if(StringMatch(wave_name,except))
				continue
			endif
			Wave theWave=$wave_name
			Downsample(theWave,factor,in_place=in_place)
		endfor
		SetDataFolder $curr_folder
	endfor
End

// Downsample every wave in the experiment by the smallest factor (power of 2) that will leave that wave with at most 'max_rows'.  
Function DownsampleExperiment2([max_rows,newFreq,except,curr_depth])
	Variable max_rows,newFreq,curr_depth; String except
	if(ParamIsDefault(except))
		except=""
	endif
	if(!curr_depth)
		SetDataFolder root:
	endif
	// Insert arbitrary code to perform in every folder here:  
	String wave_list=WaveList("*",";","MINROWS:"+num2istr(max_rows))
	Variable j
	for(j=0;j<ItemsInList(wave_list);j+=1)
		String wave_name=StringFromList(j,wave_list)
		if(!strlen(ListMatch2(wave_name,except)))
			Wave theWave=$wave_name
			Variable rows=dimsize(theWave,0)
			if(max_rows>0 && newFreq==0)
				Variable factor=2^(ceil(log(rows/max_rows)/log(2)))
				if(factor>1)
					//Downsample(theWave,factor,in_place=1)
					if(WaveType(theWave)) // Not a text wave.  
						Resample /DOWN=(factor) theWave
					endif
				endif
			elseif(max_rows==0 && newFreq>0)
				if(WaveType(theWave)) // Not a text wave.  
					if(deltax(theWave)<(1/newFreq)) // If the resampling will be a downsampling.  
						Resample /RATE=(newFreq) theWave
					endif
				endif
			else // Neither max_rows nor new_Freq was specified (or were not specified to non-zero values).  
			endif
		endif
	endfor
	Variable i=0; String folder=""
	Do
		folder=GetIndexedObjName("",4,i)
		if(!StringMatch(folder,""))
			SetDataFolder $folder
			DownsampleExperiment2(max_rows=max_rows,newFreq=newFreq,except=except,curr_depth=curr_depth+1)
		else
			break
		endif
		i+=1
	While(1)
	if(curr_depth==0)
		SetDataFolder root:
	else
		SetDataFolder ::
	endif
End

// Does the Continous Wavelet Transform and displays it with a good scale
Function CWT2(signal[,start,delta,num,endm,downsample,image_downsample,noPlot,mother,out])
	Wave signal
	Variable start,delta,num // The starting scale, the interval between scales, and the number of scales
	Variable endm // The method for dealing with endpoints
	Variable downsample // The amount to downsample the original wave for performing the CWT
	Variable image_downsample // The amount to downsample the time axis of the resulting CWT by, so it doesn't take up so much memory.  
	Variable noPlot // Do not create a new plot (but update old ones).  
	String mother // The name of the mother wavelet.  
	variable out // The output format.  
	String curr_folder=GetDataFolder(1)
	start=ParamIsDefault(start) ? 0 : start // Note: It is unclear what start of zero even means.  You should set this manually.  
	delta=ParamIsDefault(delta) ? 0.1 : delta
	num=ParamIsDefault(num) ? 100 : num
	endm=ParamIsDefault(endm) ? 0 : endm
	downsample=ParamIsDefault(downsample) ? 10 : downsample
	image_downsample=ParamIsDefault(image_downsample) ? 10 : image_downsample
	out=paramisdefault(out) ? 4 : out // Default to real output containing the magnitude.  If out=1 is selected (complex), further calculations will just use the phase.  
	if(ParamIsDefault(mother))
		mother="Morlet"
	endif
	
	duplicate /free signal toCWT
	resample /down=(downsample) toCWT
	Variable scale=dimdelta(toCWT,0)
	if(noPlot)
		string win_name=WinName(0,1)
	else
		win_name=uniquename(CleanUpName(NameOfWave(signal),0),6,0)//+"_"+GetWavesDataFolder(signal,0),0)
	endif
	//win_name=UniqueName(win_name,6,0)
	WaveStats /Q/R=(0,0.02) toCWT
	toCWT-=V_avg // Because the /ENDM flag doesn't actually work, I have to subtract off the baseline to avoid edge effects in the CWT
	CWT /Q /OUT=(out) /WBI1={$mother} /FSCL /M=0 /R1={0,1,numpnts(toCWT)} /R2={start,delta,num} /SMP2=4 /ENDM=(endm) toCWT
	//CWT /Q /OUT=4 /WBI1={$mother} /SMP2=4 /FSCL /M=0 /R1={0,1,numpnts(toCWT)} /R2={start,delta,num} /ENDM=(endm) toCWT
	//CWT /Q /OUT=4 /WBI1={Morlet} /FSCL /M=0 /R1={0,1,numpnts(toCWT)} /ENDM=(endm) toCWT
	toCWT+=V_avg
	string CWT_name=NameOfWave(signal)+"_cwt"
	if(exists(CWT_Name))
		Duplicate /o M_CWT $CWT_Name; KillWaves /Z M_CWT
	else
		Rename M_CWT $CWT_Name
	endif
	if(out==1) // If output was complex, keep only the phase as a real wave.  
		Wave /c M_CWTcmplx=$CWT_Name
		M_CWTcmplx=cmplx(atan2(imag(M_CWTcmplx),real(M_CWTcmplx)),0)
		redimension /r M_CWTcmplx
		Wave M_CWT=$CWT_Name
	else // Otherwise take the log.  
		Wave M_CWT=$CWT_Name
		M_CWT=log(M_CWT)
	endif
	
	if(!noPlot)
		Display /N=$win_name /K=1
		AppendImage M_CWT vs {*, W_CWTScaling}
		TextBox /N=SignalName /D={1,1,0} ReplaceString("_",win_name," ")
		NewFreeAxis /R freq_axis
		ModifyGraph margin(left)=40,margin(right)=40,margin(bottom)=30
		ModifyGraph freePos(freq_axis)={0,kwFraction},lblpos(freq_axis)=40
		ModifyGraph log(left)=1,log(freq_axis)=1
		//ModifyGraph height={perUnit,25,left}
		Label left "Wavelength (s)"
		Label freq_axis "Frequency (Hz)"
		Label bottom "Time (s)"
	endif
	
	if(out==1) // If using phase, color from 0-pi to pi.  
		ModifyImage /W=$win_name $CWT_Name ctab= {-pi,pi,Rainbow,0}
	else // Otherwise color from min to max.  
		wavestats /q/m=1 m_cwt
		ModifyImage /W=$win_name $CWT_Name ctab= {V_min,V_max,Rainbow,0}
	endif
	
	//Variable freq_low=0.1,freq_high=100
	SetAxis /W=$win_name /A/R left; DoUpdate; GetAxis /Q left
	Variable firstWavelength=V_max//dimoffset(M_CWT,1)
	Variable lastWavelength=V_min//firstWaveLength+dimsize(M_CWT,1)*dimdelta(M_CWT,1)
	SetAxis /W=$win_name freq_axis 1/lastWaveLength,1/firstWaveLength
	ModifyGraph /W=$win_name axisEnab(left)={0.20,1}, axisEnab(freq_axis)={0.20,1},log(freq_axis)=1
	RemoveTraces(win=win_name)
	AppendToGraph /W=$win_name /L=ampl_axis /c=(0,0,0) signal
	SetAxis /W=$win_name /A ampl_axis 
	ModifyGraph /W=$win_name axisEnab(ampl_axis)={0,0.18}, freepos(ampl_axis)={0,bottom}, fsize=10
	//MoveWindow /W=$win_name win_left,win_top,win_right/2,win_bottom/2
	SetDataFolder $curr_folder
	Variable /G image_minn=V_min,image_maxx=V_max/2
End

Function DWTDenoise2(theWave[,threshold])
	Wave theWave
	Variable threshold // The threshold (%) below which wavelet coefficients will be discarded
	threshold=ParamIsDefault(threshold) ? 0.5 : threshold
	DWT /P=2 /D /V=(threshold) theWave
End

// Generates a time-frequency matrix based on a windowed fourier transform.  Also see CWT and CWT2.  
Function /WAVE TimeFrequency(Source,winSize,winOverlap[,segmentSize,segmentOverlap,maxFreq,smoothing,fractional,logg,destName])
	Wave Source
	Variable winSize // Size of the window for each transform, in the units of Source.  
	Variable winOverlap // Fractional overlap between windows.  
	variable segmentSize // Size of segments (as a fraction of window size) to use for averaging the spectrum within each window.  
	variable segmentOverlap // Overlap of segments.  
	variable maxFreq // The maximum frequency to keep.  
	Variable smoothing // Optional number of binomial smoothing passes for each windowed spectrum.  
	variable fractional // Express PSD as a fraction of the total power in the signal (across all frequencies) for each window.  
	variable logg // Take the logarithm (base 10) of the result.  
	string destName // Name of the destination wave.  
	
	if(winOverlap>0.99)
		//DoAlert 0,"Choose an overlap value less than 0.99"
		Post_("Choose an overlap value less than 0.99")
		return $""
	endif
	
	Variable i
	Variable numTransforms=floor(numpnts(Source)*deltax(Source)/(winSize*(1-winOverlap)))
	Variable winPoints=round(winSize/deltax(Source))
	if(mod(winPoints,2)!=0)
		winPoints-=1
	endif
	variable segmentPoints=floor(winPoints*segmentSize)
	if(mod(segmentPoints,2)!=0)
		segmentPoints-=1
	endif
	if(paramisdefault(segmentOverlap))
		segmentOverlap=0.5
	endif
	segmentOverlap=round(segmentPoints*segmentOverlap)
	destName=selectstring(paramisdefault(destName),destName,NameOfWave(Source)+"_tf")
	variable yPoints=1+(segmentSize ? segmentPoints : winPoints)/2
	Make /o/n=(numTransforms,yPoints) $destName /WAVE=Dest
	Do
		Variable start=i*winPoints*(1-winOverlap)
		Variable finish=start+winPoints
		Duplicate /o/FREE/R=[start,finish-1] Source, TFWindow
		if(mod(numpnts(TFWindow),2)!=0)
			redimension /n=(numpnts(TFWindow)-1) TFWindow
		endif
		if(segmentSize && segmentPoints < numpnts(TFWindow))
			DSPPeriodogram /Q/NODC=1 /WIN=Hanning /SEGN={(segmentPoints),(segmentOverlap)} TFWindow
		else
			DSPPeriodogram /Q/NODC=1 /WIN=Hanning TFWindow
		endif
		Wave TFSpectrum=W_Periodogram
		//TFSpectrum=0
		//FFT /MAGS /DEST=TFSpectrum /WINF=Hanning TFWindow
		if(smoothing)
			Smooth smoothing,TFSpectrum
		endif
		//print dimsizes(TFSpectrum), dimsizes(Dest)
		ImageTransform /D=TFSpectrum /G=(i) putRow, Dest
		//print i,numTransforms
		i+=1
	While(i<numTransforms)
	variable highest=wavemax(Dest)
	//Dest=log(Dest/highest)*20 // Normalize to dB.  
	Redimension /n=(i,-1) Dest
	SetScale /P x,leftx(Source),winSize*(1-winOverlap), Dest
	variable interval=1/(deltax(Source)*(segmentSize ? segmentPoints : winPoints))
	SetScale /P y,-0.5*interval,interval, Dest
	if(maxFreq)
		variable maxFreqPoint=(maxFreq-dimoffset(Dest,1))/dimdelta(Dest,1)
		redimension /n=(-1,ceil(maxFreqPoint)) Dest
	endif
	if(fractional)
		//redimension /d dest
		matrixop /free sums=sumcols(Dest^t)
		//print sums
		Dest /= sums[p]//
		//Matrixop /o Dest = powR(normalizecols(sqrt(Dest)),2)
	endif
	if(logg)
		Dest=log(Dest)
	endif
	KillWaves /Z TFSpectrum
	return Dest
End

// Generates a sliding cross-correlogram.  
// If w1 leads w2, the peak will be at a negative value.  If w1 follows w2, the peak will be at a positive value.  
Function /WAVE SlidingCorrelation(w1,w2,winSize,winOverlap[,smoothing])
	wave w1,w2
	variable winSize // Size of the window for each transform, in the units of the input waves 'w1' and 'w2'.    
	variable winOverlap // Fractional overlap between windows.  
	variable smoothing // Optional number of binomial smoothing passes for each windowed correlogram.  
	
	if(winOverlap>0.99)
		//DoAlert 0,"Choose an overlap value less than 0.99"
		Post_("Choose an overlap value less than 0.99"); return $""
	endif
	if(dimsize(w1,0)!=dimsize(w2,0) || abs(log(dimdelta(w1,0)/dimdelta(w2,0)))>1e-8)
		Post_("Source waves must be equal in length and scaling"); return $""
	endif
	
	variable i
	variable numWindows=numpnts(w1)*deltax(w1)/(winSize*(1-winOverlap))
	Variable winPoints=round(winSize/deltax(w1))
	string destname
	sprintf destName,"%s_%s_scorr",NameOfWave(w1),NameOfWave(w2)
	destName=CleanupName(destName,0)
	Make /o/n=(numWindows,winPoints) $destName /WAVE=Dest
	do
		variable start=i*winPoints*(1-winOverlap)
		variable finish=start+winPoints
		duplicate /o/FREE/R=[start,finish-1] w1, w1_
		duplicate /o/FREE/R=[start,finish-1] w2, w2_
		MatrixOp /o piece=correlate(subtractMean(w1_,0),subtractMean(w2_,0),0) x inv(sqrt(varcols(w1_)*varcols(w2_)*numpoints(w1_)*numpoints(w2_)))
		rotate winPoints/2, piece
		if(smoothing)
			smooth smoothing,piece
		endif
		ImageTransform /D=piece /G=(i) putRow, Dest
		i+=1
	while(finish<numpnts(w1))
	Redimension /n=(i,-1) Dest
	SetScale /P x,leftx(w1)+winSize/2,winSize*(1-winOverlap),"s",Dest
	SetScale y,-winSize/2,winSize/2,"s",Dest // Lag.  
	//variable interval=1/(deltax(w1)*winPoints)
	return Dest
End

// Generates a sliding cross-coherence spectrum.  
// I think this is not the same as the power spectrum of the cross-correlation, because you lose some phase relationships in the signals when you compute
// the cross-correlation function.  I should look into this.  
Function /WAVE SlidingCoherence(w1,w2,winSize,winOverlap[,segSize,segOverlap,smoothing])
	wave w1,w2
	variable winSize // Size of the window for each transform, in the units of the input waves 'w1' and 'w2'.    
	variable winOverlap // Fractional overlap between windows.  
	variable segSize // Size of each segment, as a fraction of window size, for computing the coherence with a window.  
	variable segOverlap // Fractional overlap between segments.  
	variable smoothing // Optional number of binomial smoothing passes for each windowed correlogram.  
	
	segSize=paramisdefault(segSize) ? 0.1 : segSize
	segOverlap = paramisdefault(segOverlap) ? 0.95 : segOverlap
	if(winOverlap>0.99)
		//DoAlert 0,"Choose an overlap value less than 0.99"
		Post_("Choose an overlap value less than 0.99"); return $""
	endif
	if(dimsize(w1,0)!=dimsize(w2,0) || abs(log(dimdelta(w1,0)/dimdelta(w2,0)))>1e-8)
		Post_("Source waves must be equal in length and scaling"); return $""
	endif
	
	variable i
	variable numWindows=numpnts(w1)*deltax(w1)/(winSize*(1-winOverlap))
	Variable winPoints=round(winSize/deltax(w1))
	string destname
	sprintf destName,"%s_%s_scoh",NameOfWave(w1),NameOfWave(w2)
	destName=CleanupName(destName,0)
	segSize*=winPoints
	if(mod(segSize,2)!=0)
		segSize+=1
	endif
	segOverlap*=segSize
	Make /o/n=(numWindows,segSize/2) $destName /WAVE=Dest
	do
		variable start=i*winPoints*(1-winOverlap)
		variable finish=start+winPoints
		duplicate /o/FREE/R=[start,finish-1] w1, w1_
		duplicate /o/FREE/R=[start,finish-1] w2, w2_
		copyscales w1_,w2_ // The scales should already be the same, but sometimes there are small machine-precision differences.  
		dspperiodogram /q/cohr /nodc=1 /segn={(segSize),(segOverlap)} w1_,w2_
		wave /c w_periodogram
		matrixop /o/free piece=mag(w_periodogram)
		if(smoothing)
			smooth smoothing,piece
		endif
		ImageTransform /D=piece /G=(i) putRow, Dest
		i+=1
	while(finish<numpnts(w1))
	killwaves /z w_periodogram
	Redimension /n=(i,-1) Dest
	SetScale /P x,leftx(w1)+winSize/2,winSize*(1-winOverlap),"s",Dest
	SetScale /P y,0,1/(segSize*dimdelta(w1,0)),"Hz",Dest // Frequency.  
	//variable interval=1/(deltax(w1)*winPoints)
	return Dest
End

Function SCorrPhaseOffset(scorr)
	wave scorr // Result of SlidingCorrelation(), a 2D matrix containing a sliding correlation.  
	
	make /o/n=(dimsize(scorr,0)) $(getwavesdatafolder(scorr,2)+"_ph") /wave=phases
	variable i
	wave ridge=ridgefollow(scorr)
	for(i=0;i<dimsize(scorr,0);i+=1)
		wave corr=row(scorr,i)
		bandpassfilter(corr,3,1)
		fft /mags /dest=fcorr corr
		wavestats /q fcorr
		variable peakFreq=v_maxloc
		killwaves /z fcorr
		phases[i]=-2*pi*ridge[i]*peakFreq
		//if(phases[i]>phases[i+1]+3*pi/2)
		//hilberttransform /dest=hilb corr
		//duplicate /o corr,phase
		//phase = atan2(-hilb,corr)
		//phases[i]=phase(0)
	endfor
	//phases+=pi
	//unwrap 2*pi,phases  
	//phases-=pi
	copyscales scorr,phases
	smooth /m=0 3,phases
End

Function /C BestThreshold(w[,signe,tries])
	wave w
	variable signe // +1 to only search threshold above the median, -1 to only search thresholds below the median.  
	variable tries // granularity of the search.  
	
	tries=paramisdefault(tries) ? 100 : tries
	make /o/n=(tries+1) crossings
	variable med=statsmedian(w)
	wavestats /q/m=1 w
	variable i
	variable minn=(signe>0) ? med : v_min
	variable maxx=(signe<0) ? med : v_max
	for(i=0;i<tries+1;i+=1)
		variable level=minn+i*(maxx-minn)/tries
		findlevels /q/edge=(level>med ? 1 : 2) w,level
		crossings[i]=v_levelsfound
	endfor
	crossings-=1 // This makes threshold with one crossing have zero crossings, helping to eliminate them from consideration.  
	differentiate crossings /d=dcrossings
	differentiate dcrossings /d=d2crossings
	crossings/=(abs(dcrossings)+0.5) // Amplify areas with small derivative.  
	crossings/=(abs(d2crossings)+0.5) // Amplify areas with small second derivative.  
	killwaves /z dcrossings,d2crossings,v_levelsfound
	smooth (tries/20),crossings
	setscale /I x,minn,maxx,crossings
	wavestats /q/r=(minn,0) crossings
	variable real_=v_maxloc
	wavestats /q/r=(0,maxx) crossings
	variable imag_=v_maxloc
	
	return cmplx(real_,imag_)
End

Function /S HighPassFilter(ToFilter,cutoff,width)
	Wave ToFilter
	Variable cutoff,width
	FFT /DEST=fftd ToFilter
	Duplicate /o fftd divisor
	divisor=1/(1+exp(-(x-cutoff)/width))
	fftd*=divisor
	String dest=NameOfWave(tofilter)+"_hpf"
	IFFT /DEST=$dest fftd
	KillWaves fftd
	//Display ToFilter; AppendToGraph /c=(0,0,0) $dest
	return dest
End

Function /wave BandPassFilter(w,lo,hi)
	wave w
	variable lo,hi
	wavestats /q/m=1 w
	//w-=v_avg
	wavetransform flip,w
	wave /z w_flipped
	if(!waveexists(w_flipped))
		wave w_flipped = m_flipped
	endif
	variable delta=dimdelta(w,0),points=dimsize(w,0),half=points/2
	if(lo>0 && lo<inf && hi>0 && hi<inf)
		filteriir /lo=(lo*delta) /hi=(hi*delta) w
		filteriir /lo=(lo*delta) /hi=(hi*delta) w_flipped
	elseif(lo>0 && lo<inf )
		filteriir /lo=(lo*delta) w
		filteriir /lo=(lo*delta) w_flipped
	elseif(hi>0 && hi<inf)
		filteriir /hi=(hi*delta) w
		filteriir /hi=(hi*delta) w_flipped
	endif
	wavetransform flip,w_flipped
	//display w,w_flipped; abort
	//w=(p>half ? w : w_flipped)
	variable med=statsmedian(w)
	//w-=med
	killwaves /z w_flipped
	return w
End

function FilterPanel(w)
	wave w
	
	dowindow /k FilterPanelWin
	newpanel /n=FilterPanelWin /k=1 /w=(100,100,700,500) as "Filter Panel"
	display /host=FilterPanelWin w
	modifygraph mode=0,rgb=(0,0,0)
	newdatafolder /o root:packages
	newdatafolder /o root:packages:filterPanel
	dfref df=root:packages:filterPanel
	variable /g df:lo=0
	variable /g df:hi=inf
	setvariable low value=df:lo,proc=FilterPanelSetVariables
	setvariable high value=df:hi,proc=FilterPanelSetVariables
	duplicate /o w df:filtered
	make /o/n=0/wave df:waves={w}
	appendtograph /c=(65535,0,0) df:filtered
end

function FilterPanelSetVariables(info)
	struct wmsetvariableaction &info
	
	switch(info.eventCode)
		case 1:
		case 2:
			strswitch(info.ctrlName)
				case "low":
				case "high":
					dfref df=root:packages:filterPanel
					nvar /sdfr=df lo,hi
					wave /wave waves=df:waves
					wave w=waves[0]
					duplicate /o w df:filtered /wave=filtered
					BandPassFilter(filtered,lo,hi)
					break
			endswitch
			break
	endswitch
end

// Removes the noise that manifests itself as wiggles in the signal every second or so.  
// Doesn't remove stimulus artifacts if 'stim_regions' is specified.  
// Looks for places where the second derivative is high and cuts them out.  
Function RemoveWiggleNoise(theWave[,thresh,stim_regions])
	Wave theWave
	Variable thresh
	String stim_regions // Obtain from StimulusRegionList().  
	Variable range=0.003
	thresh=ParamIsDefault(thresh) ? 7.5 : thresh
	Differentiate /METH=1 theWave /D=DiffWave; //Wave DiffWave
	Differentiate /METH=1 DiffWave /D=DiffWave; Wave DiffWave
	DiffWave /= (10000^2)
	if(!ParamIsDefault(stim_regions))
		SetRegions(DiffWave,stim_regions,0)
	endif
	WaveTransform /O abs,DiffWave
	Smooth 25,DiffWave
	FindLevels /Q/EDGE=1 DiffWave,thresh
	Wave W_FindLevels
	Variable i,level,p1,p2
	//Display /K=1 DiffWave
	for(i=0;i<numpnts(W_FindLevels);i+=1)
		level=W_FindLevels[i]
		WaveStats /Q/R=(level,level+0.005) DiffWave // Find peak.  
		//WaveStats /Q /R=(level-0.002,level+0.002) DiffWave
		//p1=x2pnt(theWave,V_maxloc-range)
		//p2=x2pnt(theWave,V_maxloc+range)
		WaveStats /Q /R=(V_maxloc-range,V_maxloc+range) theWave // Measure variance to figure out degree of suppression.  
		Smooth2(theWave,40,left=V_maxloc-range,right=V_maxloc+range,method="boxcar")
	endfor
	KillWaves /Z DiffWave,W_FindLevels
	//Interpolate2 /T=1 /Y=tempRWN theWave; Wave tempRWN
	//theWave=tempRWN
	//KillWaves /Z tempRWN 
End

Function NewNotchFilter(w,freq,harmonics[,QF,IIR])
	Wave w
	Variable freq,harmonics
	Variable QF // Quality factor, inversely related to width of notch filter.  
	Variable IIR // Use an infinite impulse response filter instead of just supressing chunks of the spectrogram.  
	
	QF=ParamIsDefault(QF) ? 25 : QF
	Variable max_noise=1 // Must be greater than the amplitude of the noise.  
	
	Variable points=floor((1/freq)/dimdelta(w,0))
	if(mod(points,2)==0)
		points+=1
	endif
	Duplicate /o w,TempSpikes,TempNoSpikes,TempSteps
	Smooth /M=0 points, TempSteps
	TempNoSpikes-=TempSteps
	Smooth /M=(max_noise) points, TempNoSpikes
	TempSpikes = w-TempSteps-TempNoSpikes
	
	WaveStats /Q w; w -= V_avg
	w -= (TempSteps+TempSpikes)
	if(IIR)
		Variable i
		for(i=1;i<=harmonics;i+=1)
			Variable harmonic=freq*i
			FilterIIR /N={60*dimdelta(w,0),QF} w
		endfor
	else
		FFT w
		wave /c wc = w
		for(i=1;i<=harmonics;i+=1)
			harmonic=freq*i
			Variable width=harmonic/QF  
			wc[x2pnt(w,harmonic-width/2),x2pnt(w,harmonic+width/2)]=cmplx(0,0)
		endfor
		IFFT w
	endif
	w += (TempSteps+TempSpikes)
	w += V_avg
	KillWaves /Z TempSpikes,TempNoSpikes,TempSteps
End

Function NewNotchFilter2(theWave,freq,harmonics[,QF,IIR])
	Wave theWave
	Variable freq,harmonics
	Variable QF // Quality factor, inversely related to width of notch filter.  
	Variable IIR // Use an infinite impulse response filter instead of just supressing chunks of the spectrogram.  
	
	QF=ParamIsDefault(QF) ? 25 : QF
	
	Variable max_transient=1 // Maximum length of the tranisent in the first derivative (not in the signal itself).  
	Variable points=numpnts(theWave)
	Variable first_point=theWave[0]
	
	Differentiate /METH=1 theWave /D=TempDiff
	//WaveStats /Q/M=1 TempDiff; TempDiff-=V_avg // Probably unnecessary.  
	Duplicate /o TempDiff,TempDiffRaw
	Variable smooth_width=mod(max_transient,2)==0 ? max_transient+3 : max_transient+2
	Smooth /M=0 smooth_width, TempDiff
	TempDiffRaw-=TempDiff
	if(IIR)
		Variable i
		for(i=1;i<=harmonics;i+=1)
			Variable harmonic=freq*i
			FilterIIR /N={60*dimdelta(theWave,0),QF} TempDiff
		endfor
	else
		if(mod(points,2)!=0)
			Redimension /n=(points+1) TempDiff
			TempDiff[points]=TempDiff[points-1]
		endif
		FFT TempDiff
		for(i=1;i<=harmonics;i+=1)
			harmonic=freq*i
			Variable width=harmonic/QF  
			TempDiff[x2pnt(TempDiff,harmonic-width/2),x2pnt(TempDiff,harmonic+width/2)]=0
		endfor
		IFFT TempDiff
		redimension /n=(points) TempDiff
	endif
	TempDiff+=TempDiffRaw
	//TempDiff+=V_avg // Probably unnecessary.  
	CopyScales theWave, TempDiff
	Integrate /METH=2 TempDiff /D=$GetWavesDataFolder(theWave,2)
	Redimension /n=(points) theWave // Remove last point which is an integration artifact.  
	theWave+=first_point
	KillWaves /Z TempDiff,TempDiffRaw
End

// Use FilteIIR
Function NewNotchFilter3(theWave,freq,harmonics[,QF,IIR])
	Wave theWave
	Variable freq,harmonics // Harmonics is ignored here.  
	Variable QF // Quality factor, inversely related to width of notch filter.  
	Variable IIR // Use an infinite impulse response filter instead of just supressing chunks of the spectrogram.  
	
	QF=ParamIsDefault(QF) ? 25 : QF

	WaveStats /Q theWave
	Variable avg=V_avg
	theWave-=avg	
	Duplicate /FREE theWave Flipped
	Flipped=theWave[numpnts(theWave)-p-1]
	FilterIIR /N={freq*dimdelta(theWave,0),QF} theWave
	FilterIIR /N={freq*dimdelta(theWave,0),QF} Flipped
	theWave[0,numpnts(theWave)/2]=Flipped[numpnts(theWave)-p-1]
	theWave+=V_avg
End

// Use FilterIIR on rotated copies of 'theWave', such that the ringing at the onset of the wave can be avoided.  
Function NewNotchFilter4(theWave,freq,harmonics[,QF,IIR])
	Wave theWave
	Variable freq,harmonics // Harmonics is ignored here.  
	Variable QF // Quality factor, inversely related to width of notch filter.  
	Variable IIR // Use an infinite impulse response filter instead of just supressing chunks of the spectrogram.  
	
	QF=ParamIsDefault(QF) ? 25 : QF

	Duplicate /FREE theWave,Raw
	//WaveStats /Q Raw
	//Variable avg=V_avg
	//Raw-=avg
	Variable i,rotations=4,rotPoints=dimsize(Raw,0)/rotations
	for(i=0;i<rotations;i+=1)	
		Duplicate /FREE theWave Rotated
		Rotate i*rotPoints,Rotated
		FilterIIR /N={freq*dimdelta(Raw,0),QF} Rotated
		Raw[rotPoints*(rotations-i-1),rotPoints*(rotations-i)-1]=Rotated[p+rotPoints*i]
		WaveClear Rotated
	endfor
	//Raw+=V_avg
	theWave=Raw
End

Function LineRemove2(wave_list[,freqs,width,harmonics])
	String wave_list,freqs
	Variable width,harmonics
	if(ParamIsDefault(freqs))
		freqs="60"
	endif
	width=ParamIsDefault(width) ? 0.5 : width // The width in Hz to suppress around the peak frequency.  
	harmonics=ParamIsDefault(harmonics) ? 20 : harmonics
	Variable i
	for(i=0;i<ItemsInList(wave_list);i+=1)
		String wave_name=StringFromList(i,wave_list)
		Wave theWave=$wave_name
		LineRemove(theWave,freqs=freqs,width=width,harmonics=harmonics)
	endfor
End

Function LineRemoveB(theWave,freq,harmonics)
	Wave theWave
	Variable freq,harmonics
	WaveStats /Q/M=1 theWave
	Variable avg=V_avg
	//theWave-=V_avg
	Variable delta=dimdelta(theWave,0)
	Variable j,points=numpnts(theWave)
	//Concatenate /O/NP {theWave,theWave}, TempWave
	//Variable V_FitOptions=4
	//CurveFit /Q/N line,theWave
	//Variable diff=K1*points*dimdelta(theWave,0)//theWave[points-1]-theWave[0]
	//TempWave[0,points]-=diff
	Duplicate /o theWave, ReverseWave
	WaveTransform /O flip,ReverseWave
	Variable Q=20
	for(j=1;j<=harmonics;j+=1)
		FilterIIR /N={freq*j*delta,Q} theWave
		FilterIIR /N={freq*j*delta,Q} ReverseWave
		//FilterFIR /NMF={freq*j/10000,(freq*j/10000)/20} theWave
	endfor
	theWave[0,points/2-1]=ReverseWave[points-p-1]
	//KillWaves /Z TempWave
	//theWave+=V_avg
End

// The greatest tool ever for removing 60 Hz noise!  
Function LineRemove(theWave[,freqs,width,harmonics,show])
	Wave theWave
	String freqs
	Variable width,harmonics,show
	if(ParamIsDefault(freqs))
		freqs="60" // The frequencies (+ harmonics) to suppress.  
	endif
	width=ParamIsDefault(width) ? 0.5 : width // The width in Hz to suppress around the peak frequency.  
	harmonics=ParamIsDefault(harmonics) ? 20 : harmonics
	
	WaveStats /Q/M=1 theWave; 
	Variable wave_avg=V_avg
	theWave-=wave_avg
	
	Variable i,j,left,right
	Variable original_points=numpnts(theWave)
	Variable padded_points=NextPowerOf2(original_points) // Padding to make the FFT faster.  
	DWT /D/V=90 /P=2 theWave,theWave_denoised // V=1 may need to be changed to a smaller value if the line noise is strong compared to the signal.  
	theWave-=theWave_denoised // Get rid of the denoised part, leaving only small fluctuations like 60 Hz.  
	FFT /MAG /PAD=(padded_points) /DEST=f_test theWave
	Duplicate /o theWave noiseWave
	Duplicate /o f_test MagWaveOld,MagWaveNew // Make copies of the FFT for examining the spectrum (using show=1).  
	Make /o/n=(harmonics) FreqZScores=NaN // A wave of Z-scores for each harmonic.  
	Variable freq,Hz,power
	f_test*=x^1 // Whitens the spectrum so the slope is ~ 1 around each peak, ensuring that a line noise peak will stand out.  
	
	FFT /PAD=(padded_points) /DEST=fftd theWave; // Make an actual FFT for operations.  
	Duplicate /o fftd fftd_original
	for(j=0;j<ItemsInList(freqs);j+=1)
		freq=str2num(StringFromList(j,freqs))
		for(i=1;i<=harmonics;i+=1)
			Hz=i*freq
			WaveStats /Q /R=(Hz-width,Hz+width) f_test // Examine the range around the potential line.  
			power=V_max
			left=x2pnt(f_test,Hz-width)
			right=x2pnt(f_test,Hz+width)
			f_test[x2pnt(f_test,left),x2pnt(f_test,right)]=NaN // Eliminate the potential FFT peaks around the line artifact to subsquently evaluate the background power.  
			// Removes the peaks to calculate the baseline mean and standard deviation of the power spectrum
			WaveStats /Q/R=(Hz-20,Hz+20) f_test // Get the background power +/- 20 Hz of the frequency of interest
			FreqZScores[i]=(power-V_avg)/V_sdev // Compute a Z-Score for the line based on the statistics of the background power.  
			if(FreqZScores[i]>4) // If the frequency has power significantly above baseline
				MagWaveNew[left,right]=V_avg*(x^-1) // Set the values in the region equal to the background power (de-whitened).    
				fftd[left,right]=fftd_original*MagWaveNew/MagWaveOld // Set the actual FFT to be bigger by a factor of the new one divided by the old one.  
			endif
		endfor
	endfor
	KillWaves /Z FreqZScores,f_test,fftd_original
	
	if(show)
		Display /K=1 MagWaveOld
		AppendToGraph /c=(0,0,65535) MagWaveNew
		ModifyGraph log=1
	endif
	KillWaves /Z MagWaveOld,MagWaveNew
	
	IFFT /DEST=tempLineRemove fftd // Restore to the time domain.  
	theWave=tempLineRemove
	KillWaves /Z tempLineRemove,fftd
	
	theWave+=theWave_denoised // Add back on the denoise part.  
	DeletePoints original_points,padded_points-original_points,theWave
	theWave+=wave_avg
	
	//Display /K=1 noiseWave
	KillWaves /Z theWave_denoised,noiseWave
End

Function NoiseCopy(theWave[,freq,harmonics])
	Wave theWave
	Variable freq,harmonics
	freq=ParamIsDefault(freq) ? 60 : freq
	harmonics=ParamIsDefault(harmonics) ? 10 : harmonics
	Duplicate /o theWave noise
	Make /o/C/n=(numpnts(theWave)) complex_noise=0
	CopyScales theWave, complex_noise
	FFT theWave; Wave /C fftd=theWave
	Variable i,Hz
	for(i=1;i<=harmonics;i+=1)
		Hz=i*freq
		complex_noise+=fftd(Hz)*cmplx(cos(2*pi*Hz*x),-sin(2*pi*Hz*x))
		complex_noise+=conj(fftd(Hz))*cmplx(cos(2*pi*Hz*x),+sin(2*pi*Hz*x))
	endfor
	IFFT theWave
	noise=real(complex_noise)
	noise*=(2/numpnts(noise))
End

function /wave PeakFinder(w,minAmpl[,left,right,locs,ampls])
	wave w,locs,ampls
	variable minAmpl,left,right
	if(!paramisdefault(left))
		left=max(left,leftx(w))
		right=min(right,rightx(w))
		if(right<left)
			return NULL
		endif
	elseif(paramisdefault(left))
		left=leftx(w)
		right=rightx(w)
		make /free/n=0 locs,ampls
	endif
	wavestats /q/r=(left,right) w
	if(v_max>minAmpl)
		locs[numpnts(locs)]={v_maxloc}
		ampls[numpnts(ampls)]={v_max}
		PeakFinder(w,minAmpl,left=left,right=v_maxloc-0.2,locs=locs,ampls=ampls)
		PeakFinder(w,minAmpl,left=v_maxloc+0.2,right=right,locs=locs,ampls=ampls)
	endif
	if(paramisdefault(left))
		sort locs,locs,ampls
		do
			differentiate locs /d=intervals_
			variable interval=statsmedian(intervals_)
			variable n=numpnts(locs)
			duplicate /free ampls smoothed
			smooth /m=0 3,smoothed
			make /free/n=(numpnts(locs)) state=intervals_[p]>interval/1.5 || ampls[p]>=smoothed[p] // With forward/backward intervals similar to the median interval and at least as large as the median peak.  
			extract /free locs,locs,state
			extract /free ampls,ampls,state
			killwaves /z intervals_
		while(sum(state)<numpnts(state)) // Repeat as long as there are still peaks being deleted.  
		//duplicate /o ampls,$"ampls"
		return locs
	endif
end

// Subtracts a loosely compressed version of itself
Function /S Detrend(theWave [,kHz])
	Wave theWave
	Variable kHz
	kHz=ParamIsDefault(kHz) ? 10 : kHz
	//Duplicate /o theWave trend
	//trend=mean(test,floor(x*60)/60,(1+floor(x*60))/60)
	//theWave-=trend
	//KillWaves trend
	//return ""
	Reduce(toReduce=theWave)
	Wave alllocs,allvals
	String trend_name=InterpFromPairs(allvals,alllocs,"Trend_"+NameOfWave(theWave),kHz=10)
	Wave trend=$trend_name
	theWave-=trend
	return trend_name
End

// Pushes the maximum down to the average.  Does nothing to the minimum.  
Function SuppressExtrema(theWave,left,right[,degree,complex])
	Wave theWave
	Variable left,right
	Variable degree,complex
	
#if exists("Interpolate2")
	Variable i,avg,width=(right-left)/2
	if(ParamIsDefault(degree))
		degree=2
	endif
	if(complex==1)
		Wave /C complexWave=theWave
		WaveTransform magnitude complexWave
		Wave magWave=W_magnitude
		Duplicate /O magWave magWaveOld
		WaveStats /Q/R=(left,right) magWave
//		for(i=0;V_max>degree*V_avg;i=+1)
//			magWave[x2pnt(magWave,left),x2pnt(magWave,right)]=magWave[p]>degree*V_avg ? V_avg : magWave[p]
//			WaveStats /Q/R=(left,right) magWave
//		endfor
		V_maxloc=(left+right)/2
		magWave[x2pnt(magWave,V_maxloc)]=NaN
		Interpolate2 /Y=magWave2 magWave; Wave magWave2
		magWave=magWave2
		complexWave[x2pnt(magWave,V_maxloc)]=magWave
//		complexWave[x2pnt(magWave,left),x2pnt(magWave,right)]*=(magWave/magWaveOld)
		//KillWaves magWave,magWaveOld
		return V_maxloc
	endif
	WaveStats /Q/R=(left,right) theWave
	theWave[x2pnt(theWave,left),x2pnt(theWave,right)]=magWave[p]>V_avg ? V_avg : theWave[p]
	return V_maxloc
#endif
End

Threadsafe Function FilterF(w,[lo,hi,width,n])
       wave w
       variable lo,hi,width,n
     	width=paramisdefault(width) ? 0.2 : width // Default width (between stop and pass band) as a percentage of the freqeuency.  
     	n=paramisdefault(n) ? 1001 : n // Default number of filter coefficients.  
     	 
      Variable delta=dimdelta(w,0)
      WaveStats /Q w
      Variable meann=V_avg
      w-=meann
     
     	if(lo)
     		filterfir /lo={lo*(1-width/2)*delta,lo*(1-width/2)*delta,n} w
      	endif
      	if(hi)
      		filterfir /hi={hi*(1-width/2)*delta,hi*(1-width/2)*delta,n} w
      	endif
    	w+=meann
End

Function RotateColumn(Matrix,column,points)
	Wave Matrix
	Variable column // Column number to rotate.  
	Variable points // Number of points to rotate the column by.  
	
	MatrixOp /o ColumnWave=col(Matrix,column)
	Rotate points,ColumnWave
	Matrix[][column]=ColumnWave[p]
End

Function MatrixLags(Matrix)
	Wave Matrix
	MatrixOp /O Phase2=phase(cmplx(syncCorrelation(Matrix),asyncCorrelation(Matrix)))
	Variable i
	Variable freq=7000
	Variable pointsPerRadian=(freq^-1)/(2*pi*dimdelta(Matrix,0))
	Make /o/n=0 RotationMagnitude
	for(i=0;i<dimsize(Matrix,1);i+=1)
		RotationMagnitude[numpnts(RotationMagnitude)]={Phase2[0][i]*pointsPerRadian}
		RotateColumn(Matrix,i,Phase2[0][i]*pointsPerRadian)
	endfor
End

Function RemoveSinNoise(Wav,freq)
	Wave Wav
	Variable freq // Initial guess for the frequency of the noise.  
	
	Variable oldRate=1/dimdelta(Wav,0)
	Variable newRate=10^(floor(log(freq))+2)
	Resample /RATE=(newRate) Wav; // Upsample for curve fitting.  
	K0=0; K1=0.00001; K2=freq; K3=0; 
	Make /o/n=(numpnts(Wav)) TempFit
	CurveFit/G/NTHR=0/Q /N=1 /W=0 sin Wav /D=TempFit
	Wave TempFit
	Wav-=TempFit
	Resample /RATE=(oldRate) Wav
	KillWaves /Z TempFit
End

Function NormalizeTraces3(folder_list,bad_list,norm_point)
	String folder_list, bad_list // A list of folders that contain traces to normalize, and a list of traces not to normalize
	Variable norm_point // The point in the traces, e.g. 0.05 (s) whose y value will equal 1 in the normalized traces
	Variable i,j,norm_by,adjust
	String folder
	String curr_folder=GetDataFolder(1)
	String no_use_list
	String wave_list, wave_name
	for(i=0;i<ItemsInList(folder_list);i+=1)
		SetDataFolder root:
		no_use_list=bad_list
		SetDataFolder curr_folder
		folder=StringFromList(i,folder_list)
		FindFolder(folder)
		wave_list=WaveList("*",";","")
		no_use_list=ListMatch(no_use_list,"*"+folder+"*")
		for(j=0;j<ItemsInList(wave_list);j+=1)
			wave_name=StringFromList(j,wave_list)
			if(!cmpstr("",ListMatch(no_use_list,"*"+wave_name)))
				if(!SerialStringMatch("*norm*;*thyme*;*M_colors*",wave_name))
					Duplicate /o $wave_name $(wave_name+"_normed")
					Wave normed=$(wave_name+"_normed")
					WaveStats /Q/R=(-0.005,-0.001) normed
					adjust=V_avg
					normed-=adjust
					norm_by=abs(normed(norm_point))	
					normed/=norm_by
				endif
			endif
		endfor
	endfor
	SetDataFolder curr_folder
End

Function MakeNoiseCopy(raw,freq_list)
	Wave raw
	String freq_list
	KillWaves fftd,mag
	FFT /DEST=fftd raw
	FFT /MAG /DEST=mag raw
	mag=log(mag)
	Duplicate /o raw,realnoise, imagnoise, noisecopy
	noisecopy=0
	Variable i, freq
	for(i=0;i<ItemsInList(freq_list);i+=1)
		freq=str2num(StringFromList(i,freq_list))
		//WaveStats /Q/R=(freq-0.01*freq,freq+0.01*freq) mag
		//freq=V_maxloc
		realnoise=cos(2*pi*freq*x)
		imagnoise=sin(2*pi*freq*x)
	// All cross terms (2,3,6,7) should add to zero
	//term1=realnoise*real(fftd(60))
	//term2=realnoise*imag(fftd(60))
	//term3=imagnoise*real(fftd(60))
	//term4=-(imagnoise*imag(fftd(60)))
	//term5=realnoise*real(fftd(60))
	//term6=realnoise*(-imag(fftd(60)))
	//term7=(-imagnoise)*real(fftd(60))
	//term8=-(-imagnoise)*(-imag(fftd(60)))
		noisecopy-=2*realnoise*real(fftd(freq))-2*(imagnoise*imag(fftd(freq)))
	endfor
	noisecopy/=numpnts(noisecopy)
	Display /K=1
	String denoised_name=NameofWave(raw)+"_denoised"
	Duplicate /o raw $denoised_name
	Wave denoised=$denoised_name
	denoised=raw-noisecopy
	AppendToGraph /c=(65535,0,0) raw
	AppendToGraph /c=(0,0,65535) denoised
	// term9=term2+term3+term6+term7 // Should equal 0
	//noisecopy=term1+term4+term5+term8
	//appendTograph noisecopy//,term9
End

Function RemoveLines(raw,freq_list)
	Wave raw
	String freq_list
	KillWaves /Z fftd,mag
	FFT /DEST=fftd raw
	FFT /MAG /DEST=mag raw
	mag=log(mag)
	Duplicate /o raw,realnoise, imagnoise, noisecopy
	noisecopy=0
	Variable i, freq
	for(i=0;i<ItemsInList(freq_list);i+=1)
		freq=str2num(StringFromList(i,freq_list))
		//WaveStats /Q/R=(freq-0.01*freq,freq+0.01*freq) mag
		//freq=V_maxloc
		realnoise=cos(2*pi*freq*x)
		imagnoise=sin(2*pi*freq*x)
	// All cross terms (2,3,6,7) should add to zero
	//term1=realnoise*real(fftd(60))
	//term2=realnoise*imag(fftd(60))
	//term3=imagnoise*real(fftd(60))
	//term4=-(imagnoise*imag(fftd(60)))
	//term5=realnoise*real(fftd(60))
	//term6=realnoise*(-imag(fftd(60)))
	//term7=(-imagnoise)*real(fftd(60))
	//term8=-(-imagnoise)*(-imag(fftd(60)))
		noisecopy-=2*realnoise*real(fftd(freq))-2*(imagnoise*imag(fftd(freq)))
	endfor
	noisecopy/=numpnts(noisecopy)
	Display /K=1
	String denoised_name=NameofWave(raw)+"_denoised"
	Duplicate /o raw $denoised_name
	Wave denoised=$denoised_name
	denoised=raw-noisecopy
	AppendToGraph /c=(65535,0,0) raw
	AppendToGraph /c=(0,0,65535) denoised
	// term9=term2+term3+term6+term7 // Should equal 0
	//noisecopy=term1+term4+term5+term8
	//appendTograph noisecopy//,term9
End

Function Shift()
	Wave test=root:test
	Make /o/n=200 Shifts
	Variable i
	Duplicate /o test, test2
	Duplicate /o noisecopy, noisecopy2
	for(i=0;i<200;i+=1)
		WaveTransform /o/P={1} shift,noisecopy2
		test2=test-noisecopy2
		WaveStats/Q test2
		Shifts[i]=V_sdev
	endfor
	//Correlate /c noisecopy, test2
	Display /K=1 shifts
	WaveStats/Q shifts
	Duplicate /o noisecopy, noisecopy2
	WaveTransform /o/P={V_minloc} shift,noisecopy2
	test2=test-noisecopy2
	Display /K=1
	AppendToGraph /c=(65535,0,0) test
	AppendToGraph /c=(0,65535,0) noisecopy
	AppendToGraph /c=(0,0,65535) noisecopy2	
End

Function RsFilter(theWave,resistance,capacitance)
	Wave theWave
	Variable resistance,capacitance
	Differentiate /METH=2 theWave /D=Impulse
	Duplicate /O Impulse Response,Filtered
	Filtered=0
	Variable i,tau=resistance*capacitance
	for(i=0;i<numpnts(theWave);i+=1)
		Make /o/n=1000 ImpulseResponse=(x>=i) ? exp(-(x-i)/tau) : 0
		WaveTransform /O normalizeArea ImpulseResponse
		Response=Impulse[i]*ImpulseResponse
		Integrate Response
		Filtered+=Response
	endfor
	KillWaves Impulse,Response
End

Function RsTheory(theWave)
	Wave theWave
	Variable i
	Make /o/n=100 RsTheoryPoints=NaN,RsTheoryPointsX=x
	for(i=1;i<100;i+=1)
		Duplicate /o theWave Filtered,ImpulseResponse
		ImpulseResponse=exp(-x/(i/10))
		//WaveTransform /O normalizeArea ImpulseResponse
		Integrate /P ImpulseResponse /D=Integrated
		ImpulseResponse/=Integrated[numpnts(Integrated)-1]
		Convolve ImpulseResponse Filtered
		WaveStats /Q Filtered
		RsTheoryPoints[i]=V_max
	endfor
	WaveStats /Q theWave
	RsTheoryPoints[0]=V_max
	//RsTheoryPoints[1,5]=NaN
	Variable temp=RsTheoryPoints[0]
	RsTheoryPoints /=Temp
	Display /K=1 RsTheoryPoints vs RsTheoryPointsX
	ModifyGraph log(left)=1
End

Function ODEs()
	//Display /K=1
	Make /o/n=1000 y1,x1,z1,eta
	y1[0]=0.1; x1[0]=0; z1[0]=0.9;
	Variable i,a=0.01,b=0.00333,c=0.00333
	for(i=1;i<numpnts(y1);i+=1)
		y1[i]=y1[i-1] -a*y1[i-1] + b*x1[i-1]
		x1[i]=x1[i-1] +c*z1[i-1] - b*x1[i-1]
		z1[i]=z1[i-1] +a*y1[i-1] - c*z1[i-1]
		b-=b*0.001
	endfor
	//AppendToGraph /c=(65535,0,0) y1
	//AppendToGraph /c=(0,0,65535) x1
	//AppendToGraph /c=(0,65535,0) z1
End

// Removes those single sample lines (spike noise) from a sweep
Function RemoveSpikeNoise(theWave[,thresh,kHz])
	Wave theWave
	Variable kHz,thresh // kHz is the sampling rate.  Thresh is the largest absolute second derivative that will be allowed.  
	kHz=ParamIsDefault(kHz)?10:kHz // Not used
	thresh=ParamIsDefault(thresh)?10^9:thresh
	Do
		Duplicate /o theWave noisy
		Differentiate /METH=1 noisy
		Differentiate /METH=1 noisy
		noisy=(abs(noisy)>thresh)?1:0
		theWave=noisy[p-1]?(0.5*(theWave[p-1]+theWave[p+1])):theWave[p]
	While(sum(noisy)>0)
End

Function RsDiffMethod(rawSweep,tau)
	Wave rawSweep
	Variable tau
	SetDataFolder root:
	Duplicate /O rawSweep, smoothSweep
	Smooth 100, smoothSweep
	Duplicate /O smoothSweep, diffSweep, compSweep
	Differentiate diffSweep
	Smooth 100, diffSweep
	compSweep=smoothSweep+diffSweep*tau
End  

Function Deconvolve(sweep,impulse)
	Wave sweep
	Wave impulse
	if(mod(numpnts(sweep),2)!=0)
		InsertPoints numpnts(sweep),1,sweep
	endif
	if(numpnts(sweep)!=numpnts(impulse))
		printf "Sweep and Impulse must have same dimensions!\r"
		Redimension/n=(numpnts(sweep)) impulse
	endif
	FFT/DEST=fsweep sweep
	FFT/DEST=fImpulse impulse
	fsweep/=fimpulse
	IFFT/DEST=deconvoluted fsweep                               
End  

Function RsCompensateTau(sweep,tau,n)
	Wave sweep
	Variable tau
	Variable n
	//Wave fitCoefs=root:fitCoefs
	Duplicate/o sweep, impulse
	impulse=exp(-x/tau)
	//impulse=fitCoefs[n][1]*exp(-x/fitCoefs[n][2])+fitCoefs[n][3]*exp(-x/fitCoefs[n][4])
	NormalizeToUnity(impulse)
	Duplicate/o sweep smoothed
	Smooth 50,smoothed
	Deconvolve(smoothed,impulse)
End

Function RsCompensateImpulse(sweep,impulse)
	Wave sweep
	Wave impulse
	Duplicate/o sweep smoothed
	Smooth 50,smoothed
	Deconvolve(smoothed,impulse)
End

Function RemoveTestPulses(theWave[,interval,width,down,up,preserve_spikes])
	Wave theWave
	Variable interval,width
	Variable down,up // Remove pulses going downwards; remove pulses going upwards.  
	Variable preserve_spikes // For current clamp data, preserves regions with spikes.  
	interval=ParamIsDefault(interval) ? 10 : interval
	width=ParamIsDefault(width) ? 0.16 : width
	down=ParamIsDefault(down) ? 1 : down
	up=ParamIsDefault(up) ? 0 : up
	Variable i,min_loc,max_loc,duration=rightx(theWave)-leftx(theWave)
	if(down)
		for(i=leftx(theWave);i<rightx(theWave);i+=0)
			WaveStats /Q/R=(i,i+interval*1.1) theWave; min_loc=V_minloc
			WaveStats /Q/R=(min_loc-width,min_loc+width) theWave
			if(!preserve_spikes || V_max<-20) // If no spike in the region
				theWave[x2pnt(theWave,min_loc-width),x2pnt(theWave,min_loc+width)]=NaN
			endif
			i=min_loc+1
		endfor
	endif
	if(up)
		for(i=leftx(theWave);i<rightx(theWave);i+=0)
			WaveStats /Q/R=(i,i+interval*1.5) theWave; max_loc=V_maxloc
			WaveStats /Q/R=(max_loc-width,max_loc+width) theWave
			theWave[x2pnt(theWave,max_loc-width),x2pnt(theWave,max_loc+width)]=NaN
			i=max_loc+1
		endfor
	endif
#if exists("Interpolate2")
	Interpolate2 /T=1/Y=TempTestPulses theWave; Wave TempTestPulses
	theWave=IsNaN(theWave) ? TempTestPulses : theWave 
#endif	
	KillWaves /Z TempTestPulses
End

Function /S NewFilter(theWave)
	Wave theWave
	String name=UniqueName("temp",1,0)
	Duplicate /o theWave $name; Wave Temp=$name
	Variable first=Temp[0]; Temp-=first
	Integrate Temp; Duplicate /o Temp Smoothed; Smooth /B=1/E=3 2,Smoothed
	Temp-=Smoothed
	Differentiate Temp
	//Variable i,summ=0
	//for(i=0;i<numpnts(Temp);i+=1)
	//	Temp[i]=(theWave-theWave[0])/(1+summ)
	//	summ+=Temp[i]
	//endfor
	return name
End

// Smooths with a variable gaussian window that gets wider as you move across the x-axis
Function Smooth3(theWave,initial,degree[,segments])
	Wave theWave
	Variable initial // Initial is the size of the smallest smoothing window (one end) 
	Variable degree // Degree is rate at which it widens as you go across the wave
	Variable segments // Segment is the number of segments to smooth independently
	
	Duplicate /o theWave $(NameOfWave(theWave)+"_Smoothed")
	Wave Smoothed=$(NameOfWave(theWave)+"_Smoothed")
	Smoothed=0
	Variable i, x_point, width, left, right
	Variable num_std=3 // Number of standard deviations of the Gaussian to actually use for the width (smaller number is faster but less accurate)
	segments=ParamIsDefault(segments) ? 10 : segments
	Variable segment_length=ceil(numpnts(theWave)/segments)
	Variable smooth_val
	
	// Method 1: Smoothing in segments
//	for(i=0;i<segments;i+=1)
//		Duplicate /o theWave tempSmooth
//		smooth_val=initial+i*degree
//		if(smooth_val>0)
//			Smooth initial+i*degree,tempSmooth
//		endif
//		Smoothed[i*segment_length,(i+1)*segment_length-1]+=tempSmooth
//	endfor
//	KillWaves tempSmooth
	
	// Method 2: Smoothing point by point, using a gaussian smooth
//	for(i=0;i<numpnts(Smoothed);i+=1)
//		x_point=pnt2x(theWave,i)
//		width=initial+x_point*degree
//		left=x2pnt(Smoothed,x_point-num_std*width)
//		right=x2pnt(Smoothed,x_point+num_std*width)
//		Smoothed[left,right]+=gauss(x,x_point,width)*theWave(x_point)
//	endfor
//    Smoothed*=dimdelta(Smoothed,0)

	// Method 3: Smoothing point by point, using a boxcar smooth (faster)
	Smoothed=mean(theWave,x-initial-x*degree,x+initial+x*degree)
//	for(i=0;i<numpnts(Smoothed);i+=1)
//		x_point=pnt2x(theWave,i)
//		width=initial+x_point*degree
//		left=x2pnt(Smoothed,x_point-width)
//		right=x2pnt(Smoothed,x_point+width)
//		Smoothed[left,right]+=gauss(x,x_point,width)*theWave(x_point)
//	endfor
	//Smoothed*=dimdelta(Smoothed,0)
	theWave=Smoothed; KillWaves Smoothed
End

// Downsamples a function so that each bin is an equal number of log units.  
Function LogDownsample(theWave,bin_size)
	Wave theWave
	Variable bin_size // Number of log units per bin
	Variable minn=log(leftx(theWave)+dimdelta(theWave,0))
	Variable maxx=log(rightx(theWave))
	Make /o/n=(floor((maxx-minn)/bin_size)) $(NameOfWave(theWave)+"_lds")
	Wave LDS=$(NameOfWave(theWave)+"_lds")
	LDS=mean(theWave,10^(minn+p*bin_size),10^(minn+(p+1)*bin_size))
	SetScale /P x,minn+0.5*bin_size,bin_size,LDS
End

// Implements a Median Filter
Function MedianFilter(theWave[,range,in_place])
	Wave theWave
	Variable range,in_place
	range=ParamIsDefault(range) ? 1 : range
	if(!in_place)
		String name=CleanupName("Median_"+NameOfWave(theWave),1)
		Duplicate /o theWave $name
		Wave filtered=$name
	else
		Wave filtered=theWave
	endif
	Variable i
	for(i=0;i<numpnts(filtered);i+=1)
		Duplicate /o/R=[i-range,i+range] theWave, segment
		Sort segment,segment
		filtered[i]=segment[range]
	endfor
End

Function DWTFingerprints(theWave)
	Wave theWave
	String curr_folder=GetDataFolder(1)
	DWT2(theWave)
	SetDataFolder root:DWTs
	String scales=WaveList("Scale_*",";","")
	scales=SortList(scales,";",17)
	Variable size=numpnts($StringFromList(0,scales))
	Variable i,factor
	Make /o/n=(size,ItemsInList(scales)) Fingerprint // Make a giant matrix where each column is the DWT breakdown of one timepoint.  
	for(i=0;i<ItemsInList(scales);i+=1)
		Wave Scale=$StringFromList(i,scales)
		factor=size/numpnts(scale)
		Fingerprint[][i]=Scale[floor(p/factor)][i]
	endfor
	SetDataFolder $curr_folder
End

