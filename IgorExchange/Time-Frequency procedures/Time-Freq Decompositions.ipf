#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1		//November 12, 2007
#pragma IgorVersion=6

//This procedure file provides a structure and wrapper functions to add time-frequency decomposition 
//controls to a separately programmed control panel.

//For an example of how to use the wrapper functions, see the Time-Frequency procedure file.

//The Igor built-in Wigner and CWT operations are supported in this procedure file, and a routine to calculate
//the evolutive FFT is also provided.

//written by Ben Cramer (bscramer@uoregon.edu)

constant K_TFmaxparams=3
strconstant K_CWTMotherWavelets="Morlet;Paul;DOG"


Structure TFDecompParameters
	//Universal structure to be used for input parameters to any function producing a spectral estimate
	
	wave dw,xw				//input waves for XY-pair data
	wave dw_int				//input wave for waveform data
	wave magnitude,phase		//output waves
	wave scale,frequency					//output scale coordinates
	wave coi					//cone of influence
	variable getParams		//set to 1 when calling to retrieve info for creation of controls
	
	variable Xmin,Xmax		//minimum and maximum x values to define a subrange of the data
	variable Fmin,Fmax		//minimum and maximum frequency of interest
	variable freqRes			//desired frequency resolution; if 0, default resolution (1/series length)
								//if <1/length, data will be padded to obtain desired resolution
	
	struct TFDecompSetVar SV			//structures holding set-variable parameters specific to a spectral estimate method
	
	struct TFDecompPopMenu PM		//structures holding popup menu parameters specific to a spectral estimate method
endStructure

Structure TFDecompSetVar
	//parameters to create a set variable control
	string name[K_TFmaxparams]				//control name
	variable value	[K_TFmaxparams]			//value
	variable low[K_TFmaxparams],high[K_TFmaxparams]	//low and high limits and increment for creating set variable control
	variable inc[K_TFmaxparams]	
endStructure

Structure TFDecompPopMenu
	//parameters to create a popup menu control
	string name[K_TFmaxparams]				//control name
	string value[K_TFmaxparams]				//semicolon-separated list for popup menu
	string popStr[K_TFmaxparams]				//value of selected item
	variable popNum[K_TFmaxparams]			//number of selected item
endStructure

Function TFDECOMPOSITION_prototype(TFPs)
	struct TFDecompParameters &TFPs
	
	if(TFPs.getParams)
		TFPs.SV.name[0]="";TFPs.SV.value[0]=nan;TFPs.SV.low[0]=nan;TFPs.SV.high[0]=nan;TFPs.SV.inc[0]=nan
		TFPs.SV.name[1]="";TFPs.SV.value[1]=nan;TFPs.SV.low[1]=nan;TFPs.SV.high[1]=nan;TFPs.SV.inc[1]=nan
		TFPs.SV.name[2]="";TFPs.SV.value[2]=nan;TFPs.SV.low[2]=nan;TFPs.SV.high[2]=nan;TFPs.SV.inc[2]=nan
		TFPs.PM.name[0]="";TFPs.PM.value[0]="";TFPs.PM.popStr[0]="";TFPs.PM.popNum[0]=nan
		TFPs.PM.name[1]="";TFPs.PM.value[1]="";TFPs.PM.popStr[1]="";TFPs.PM.popNum[1]=nan
		TFPs.PM.name[2]="";TFPs.PM.value[2]="";TFPs.PM.popStr[2]="";TFPs.PM.popNum[2]=nan
	else
//		TFPs.magnitude=nan;TFPs.phase=nan
	endif	
end

Function TFDECOMPOSITION_Wigner(TFPs)		//calculates Wigner transform
	struct TFDecompParameters &TFPs
	
	if(TFPs.getParams)
		TFPs.SV.name[0]="Gauss Width Fraction";TFPs.SV.value[0]=0.25;TFPs.SV.low[0]=0.05;TFPs.SV.high[0]=inf;TFPs.SV.inc[0]=0.05
		TFPs.SV.name[1]="";TFPs.SV.value[1]=nan;TFPs.SV.low[1]=nan;TFPs.SV.high[1]=nan;TFPs.SV.inc[1]=nan
		TFPs.SV.name[2]="";TFPs.SV.value[2]=nan;TFPs.SV.low[2]=nan;TFPs.SV.high[2]=nan;TFPs.SV.inc[2]=nan
		TFPs.PM.name[0]="";TFPs.PM.value[0]="";TFPs.PM.popStr[0]="";TFPs.PM.popNum[0]=nan
		TFPs.PM.name[1]="";TFPs.PM.value[1]="";TFPs.PM.popStr[1]="";TFPs.PM.popNum[1]=nan
		TFPs.PM.name[2]="";TFPs.PM.value[2]="";TFPs.PM.popStr[2]="";TFPs.PM.popNum[2]=nan
	else
		variable PtMax,dFreq,dx,gWidth,npts,newn,dwmean,fac
		wavestats/q/m=1 TFPs.dw_int
		dwmean=v_avg;npts=v_npnts
		dx=deltax(TFPs.dw_int)
		gWidth=TFPs.SV.value[0]*npts*dx
		
		TFPs.dw_int-=dwmean		//remove mean
		WignerTransform/DEST=$getwavesdatafolder(TFPs.magnitude,2)/GAUS=(gWidth) TFPs.dw_int
		TFPs.dw_int+=dwmean		//add mean back in
		
		dFreq=DimDelta(TFPs.magnitude,1)
		PtMax=floor(TFPs.Fmin/dFreq)
		DeletePoints/M=1 0,PtMax,TFPs.magnitude		//remove low frequency components to save memory
		
		if(gWidth/dx>npts*2)							//kludge
			fac=4/npts^2*npts/(gWidth/dx)/2^(1-log((gWidth/dx)/npts)/log(2))
		else
			fac=4/npts^2*npts/(gWidth/dx)
		endif
		MatrixOP/O $getwavesdatafolder(TFPs.magnitude,2)=(TFPs.magnitude*fac)		//adjust amplitudes
		
		copyscales TFPs.dw_int,TFPs.magnitude
		redimension/n=(dimsize(TFPs.magnitude,1)+1) TFPs.frequency
		setscale/p y dFreq*PtMax,dFreq,TFPs.magnitude
		setscale/p x dFreq*PtMax,dFreq,TFPs.frequency
		TFPs.frequency=x
	endif
end

function TFDECOMPOSITION_Wavelet(TFPs)				//calculates continuous wavelet transform
	struct TFDecompParameters &TFPs
	
	if(TFPs.getParams)
		TFPs.SV.name[0]="Wavelet Parameter"
		TFPs.SV.value[0]=8;TFPs.SV.low[0]=1;TFPs.SV.high[0]=inf;TFPs.SV.inc[0]=1
		TFPs.SV.name[1]="Scale Resolution"
		TFPs.SV.value[1]=0.05;TFPs.SV.low[1]=0;TFPs.SV.high[1]=1;TFPs.SV.inc[1]=0.02
		TFPs.SV.name[2]="";TFPs.SV.value[2]=nan;TFPs.SV.low[2]=nan;TFPs.SV.high[2]=nan;TFPs.SV.inc[2]=nan
		TFPs.PM.name[0]="Mother Wavelet"
		TFPs.PM.value[0]=K_CWTMotherWavelets
		TFPs.PM.popStr[0]="Morlet"
		TFPs.PM.popNum[0]=whichlistitem(TFPs.PM.popStr[0],TFPs.PM.value[0])
		TFPs.PM.name[1]="";TFPs.PM.value[1]="";TFPs.PM.popStr[1]="";TFPs.PM.popNum[1]=nan
		TFPs.PM.name[2]="";TFPs.PM.value[2]="";TFPs.PM.popStr[2]="";TFPs.PM.popNum[2]=nan
	else
		variable dmean,dvar,dx,npts,npad,jlast,s0,pfac,magfac
		wavestats/q TFPs.dw_int
		dmean=v_avg;dvar=v_sdev^2;npts=v_npnts		//get stats
		dx=deltax(TFPs.dw_int)
		npad=2^(ceil(log(npts)/log(2))+1)
		
		StrSwitch(TFPs.PM.popStr[0])				//find wavelet mother-dependent factors to adjust scale to equivalent period
			case "Paul":
				pfac=4*pi/(2*TFPs.SV.value[0]+1)
				break
			case "DOG":
				pfac=2*pi/sqrt(TFPs.SV.value[0]+0.5)
				break
			case "Morlet":
	//		case kMotherMorletC:		complex Morlet decomposition not yet implemented
				pfac=4*pi/(TFPs.SV.value[0]+sqrt(2+TFPs.SV.value[0]^2))
				break
		endSwitch
		s0=(1/TFPs.Fmax)/dx/pfac
		jlast=floor((ln(npts)/ln(2))/TFPs.SV.value[1])	//find number of scales
		jlast=min(jlast,ceil((ln((1/TFPs.Fmin)/dx)/ln(2))/TFPs.SV.value[1]))
			
		redimension/n=(npad) TFPs.dw_int;TFPs.dw_int[npts,]=dmean		//pad data to avoid wrap-around
		setscale/p x 0,1,TFPs.dw_int											//dependence of CWT on input data x scaling is weird
		magfac=1
		StrSwitch(TFPs.PM.popStr[0])				//parameters are different for different wavelet mothers, so we can't use a single generic call
			case "Morlet":
	//		case kMotherMorletC:		complex Morlet decomposition not yet implemented
				CWT/ENDM=2/OUT=4/Q/R2={s0,TFPs.SV.value[1],jlast}/SMP2=4/WBI1={Morlet}/WPR1={TFPs.SV.value[0]} TFPs.dw_int
				magfac=sqrt(12)
				break
			case "Paul":
			case "DOG":
				CWT/ENDM=2/OUT=4/Q/R2={s0,TFPs.SV.value[1],jlast}/SMP2=4/WBI1={$TFPs.PM.popStr[0],TFPs.SV.value[0]} TFPs.dw_int
				magfac=sqrt(2)
				break
		endSwitch
		redimension/n=(npts) TFPs.dw_int
		redimension/n=(npts) TFPs.dw_int
		setscale/p x TFPs.Xmin,dx,TFPs.dw_int
		
	//put waves in CWT folder	
		wave M_CWT,W_CWTScaling
		duplicate/o/R=[0,npts] M_CWT,TFPs.magnitude		//remove padding from wavelet transform
		duplicate/o W_CWTScaling,TFPs.scale,TFPs.frequency
		killwaves/Z M_CWT,W_CWTScaling
		redimension/n=(npts) TFPs.coi
		copyscales/p TFPs.dw_int,TFPs.magnitude,TFPs.coi
		
		magfac*=(1/2^ceil(ln(npad)/ln(2)))/sqrt(npts)
				
		StrSwitch(TFPs.PM.popStr[0])				//parameters are different for different wavelet mothers, so we can't use a single generic call
			case "Morlet":
				TFPs.magnitude[][]*=(magfac/sqrt(TFPs.scale[q]))	//adjust amplitude scaling
				break
			case "Paul":
			case "DOG":
				TFPs.magnitude[][]*=(magfac)							//adjust amplitude scaling
				break
		endSwitch
		TFPs.magnitude*=TFPs.magnitude
		TFPs.scale*=dx
		TFPs.frequency=1/(TFPs.scale*pfac	)		//correct for original delta x and calculate Fourier equivalent frequency
	
		TFPs.coi[0,npts/2-1]=dx*pfac*(sqrt(2))^((!StringMatch(TFPs.PM.popStr[0],"Paul")) ? 1 : -1)*1*p		//get cone of influence
		TFPs.coi[npts/2,npts-1]=TFPs.coi[npts-1-p]
		TFPs.coi[]=binarysearchinterp(scale,TFPs.coi[p])	//convert COI values from scales to points
	endif
end

Function TFDECOMPOSITION_EvolutiveFFT(TFPs)
	struct TFDecompParameters &TFPs

	if(TFPs.getParams)
		TFPs.SV.name[0]="Width Fraction";TFPs.SV.value[0]=0.2;TFPs.SV.low[0]=0.05;TFPs.SV.high[0]=1;TFPs.SV.inc[0]=0.05
		TFPs.SV.name[1]="";TFPs.SV.value[1]=nan;TFPs.SV.low[1]=nan;TFPs.SV.high[1]=nan;TFPs.SV.inc[1]=nan
		TFPs.SV.name[2]="";TFPs.SV.value[2]=nan;TFPs.SV.low[2]=nan;TFPs.SV.high[2]=nan;TFPs.SV.inc[2]=nan
		TFPs.PM.name[0]="Taper Function"
		TFPs.PM.value[0]="None;"+K_FFTWindowList
		TFPs.PM.popStr[0]="Hamming"
		TFPs.PM.popNum[0]=whichlistitem(TFPs.PM.popStr[0],TFPs.PM.value[0])+1
		TFPs.PM.name[1]="";TFPs.PM.value[1]="";TFPs.PM.popStr[1]="";TFPs.PM.popNum[1]=nan
		TFPs.PM.name[2]="";TFPs.PM.value[2]="";TFPs.PM.popStr[2]="";TFPs.PM.popNum[2]=nan
	else
		newdatafolder/o root:Packages
		newdatafolder/o root:Packages:EvolutiveFFT
		make/o/d root:Packages:EvolutiveFFT:tmp_dw,root:Packages:EvolutiveFFT:tmp_magS
		wave tmp_dw=root:Packages:EvolutiveFFT:tmp_dw,tmp_magS=root:Packages:EvolutiveFFT:tmp_magS
		variable i,npnts,seglen
		npnts=numpnts(TFPs.dw_int)
		seglen=round(TFPs.SV.value[0]*npnts)
		seglen=seglen-mod(seglen,2)
		redimension/n=(npnts,(TFPs.Fmax-TFPs.Fmin)/TFPs.freqRes) TFPs.magnitude
		redimension/n=(dimsize(TFPs.magnitude,1)+1) TFPs.frequency
		setscale/p x leftx(TFPs.dw_int),deltax(TFPs.dw_int),TFPs.magnitude
		setscale/p y TFPs.Fmin,TFPs.freqRes,TFPs.magnitude
		setscale/p x TFPs.Fmin,TFPs.freqRes,TFPs.frequency
		TFPs.frequency=x
		for(i=0;i<npnts;i+=1)
			duplicate/r=[max(0,i-seglen/2),min(npnts,i+seglen/2)]/o TFPs.dw_int,tmp_dw
			pgram(tmp_dw,pgramMagS=tmp_magS,win=TFPs.PM.popStr[0],pad=1/TFPs.freqRes/deltax(tmp_dw))
			TFPs.magnitude[i][]=tmp_magS(y)
		endfor
		TFPs.magnitude=(TFPs.magnitude*seglen/npnts)
		killdatafolder/z "root:Packages:EvolutiveFFT"
	endif
end

