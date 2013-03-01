#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1		//November 12, 2007
#pragma IgorVersion=6

//This procedure file provides a structure and wrapper functions to add spectral estimate 
//controls to a separately programmed control panel.

//For an example of how to use the wrapper functions, see the Time-Frequency procedure file.

//This procedure file provides a windowed periodogram, Blackman-Tukey, and Welch spectral estimates.

//written by Ben Cramer (bscramer@uoregon.edu)


strconstant K_FFTWindowList="Bartlett;Blackman;cos2;Hamming;Hanning;KaiserBessel;Poisson2;Riemann"
constant K_specmaxparams=3

Structure SpectrumParameters
	//Universal structure to be used for input parameters to any function producing a spectral estimate
	
	wave dw,xw				//input waves for XY-pair data
	wave dw_int				//input wave for waveform data
	wave magnitude,phase		//output waves
	variable getParams		//set to 1 when calling to retrieve info for creation of controls
	
	variable Xmin,Xmax		//minimum and maximum x values to define a subrange of the data
	variable Fmin,Fmax		//minimum and maximum frequency of interest
	variable freqRes			//desired frequency resolution; if 0, default resolution (1/series length)
								//if <1/length, data will be padded to obtain desired resolution
	
	struct SpecSetVar SV			//structures holding set-variable parameters specific to a spectral estimate method
	
	struct SpecPopMenu PM		//structures holding popup menu parameters specific to a spectral estimate method
endStructure

Structure SpecSetVar
	//parameters to create a set variable control
	string name[K_specmaxparams]				//control name
	variable value	[K_specmaxparams]			//value
	variable low[K_specmaxparams],high[K_specmaxparams]	//low and high limits and increment for creating set variable control
	variable inc[K_specmaxparams]	
endStructure

Structure SpecPopMenu
	//parameters to create a popup menu control
	string name[K_specmaxparams]				//control name
	string value[K_specmaxparams]				//semicolon-separated list for popup menu
	string popStr[K_specmaxparams]				//value of selected item
	variable popNum[K_specmaxparams]			//number of selected item
endStructure

Function SPECTRUM_prototype(SPs)
	struct SpectrumParameters &SPs
	
	if(SPs.getParams)
		SPS.SV.name[0]="";SPS.SV.value[0]=nan;SPS.SV.low[0]=nan;SPS.SV.high[0]=nan;SPS.SV.inc[0]=nan
		SPS.SV.name[1]="";SPS.SV.value[1]=nan;SPS.SV.low[1]=nan;SPS.SV.high[1]=nan;SPS.SV.inc[1]=nan
		SPS.SV.name[2]="";SPS.SV.value[2]=nan;SPS.SV.low[2]=nan;SPS.SV.high[2]=nan;SPS.SV.inc[2]=nan
		SPS.PM.name[0]="";SPS.PM.value[0]="";SPS.PM.popStr[0]="";SPS.PM.popNum[0]=nan
		SPS.PM.name[1]="";SPS.PM.value[1]="";SPS.PM.popStr[1]="";SPS.PM.popNum[1]=nan
		SPS.PM.name[2]="";SPS.PM.value[2]="";SPS.PM.popStr[2]="";SPS.PM.popNum[2]=nan
	else
//		SPs.magnitude=nan;SPs.phase=nan
	endif	
end

Function SPECTRUM_Periodogram(SPs)
	struct SpectrumParameters &SPs

	if(SPs.getParams)
		SPS.SV.name[0]="";SPS.SV.value[0]=nan;SPS.SV.low[0]=nan;SPS.SV.high[0]=nan;SPS.SV.inc[0]=nan
		SPS.SV.name[1]="";SPS.SV.value[1]=nan;SPS.SV.low[1]=nan;SPS.SV.high[1]=nan;SPS.SV.inc[1]=nan
		SPS.SV.name[2]="";SPS.SV.value[2]=nan;SPS.SV.low[2]=nan;SPS.SV.high[2]=nan;SPS.SV.inc[2]=nan
		SPS.PM.name[0]="Taper Function"
		SPS.PM.value[0]="None;"+K_FFTWindowList
		SPS.PM.popStr[0]="Hamming"
		SPS.PM.popNum[0]=whichlistitem(SPS.PM.popStr[0],SPS.PM.value[0])+1
		SPS.PM.name[1]="";SPS.PM.value[1]="";SPS.PM.popStr[1]="";SPS.PM.popNum[1]=nan
		SPS.PM.name[2]="";SPS.PM.value[2]="";SPS.PM.popStr[2]="";SPS.PM.popNum[2]=nan
	else
		Pgram(SPs.dw_int,PgramMagS=SPs.magnitude,win=SPs.PM.popStr[0],pad=1/SPs.freqRes/deltax(SPS.dw_int))
	endif
end

Function SPECTRUM_Welch(SPs)
	struct SpectrumParameters &SPs

	if(SPs.getParams)
		SPS.SV.name[0]="Number of Segments";SPS.SV.value[0]=5;SPS.SV.low[0]=1;SPS.SV.high[0]=inf;SPS.SV.inc[0]=1
		SPS.SV.name[1]="Percent Overlap";SPS.SV.value[1]=50;SPS.SV.low[1]=0;SPS.SV.high[1]=100;SPS.SV.inc[1]=5
		SPS.SV.name[2]="";SPS.SV.value[2]=nan;SPS.SV.low[2]=nan;SPS.SV.high[2]=nan;SPS.SV.inc[2]=nan
		SPS.PM.name[0]="Taper Function"
		SPS.PM.value[0]="None;"+K_FFTWindowList
		SPS.PM.popStr[0]="Hamming"
		SPS.PM.popNum[0]=whichlistitem(SPS.PM.popStr[0],SPS.PM.value[0])+1
		SPS.PM.name[1]="";SPS.PM.value[1]="";SPS.PM.popStr[1]="";SPS.PM.popNum[1]=nan
		SPS.PM.name[2]="";SPS.PM.value[2]="";SPS.PM.popStr[2]="";SPS.PM.popNum[2]=nan
	else
		newdatafolder/o root:Packages
		newdatafolder/o root:Packages:WelchSpectrum
		make/o/d root:Packages:WelchSpectrum:tmp_dw,root:Packages:WelchSpectrum:tmp_magS
		wave tmp_dw=root:Packages:WelchSpectrum:tmp_dw,tmp_magS=root:Packages:WelchSpectrum:tmp_magS
		variable i,npnts,nsegs,seglen,segoffset,segolf
		npnts=numpnts(SPs.dw_int)
		nsegs=SPs.SV.value[0]
		segolf=SPs.SV.value[1]/100
		seglen=floor(npnts/(nsegs-nsegs*segolf+segolf))
		segoffset=floor(seglen*(1-segolf))
		for(i=0;i<nsegs;i+=1)
			duplicate/r=[i*segoffset,i*segoffset+seglen-1]/o SPs.dw_int,tmp_dw
			Pgram(tmp_dw,PgramMagS=tmp_magS,win=SPs.PM.popStr[0],pad=1/SPs.freqRes/deltax(tmp_dw))
			if(i==0)
				duplicate/o tmp_magS,SPs.Magnitude
			else
				SPs.magnitude+=tmp_magS
			endif
		endfor
		SPs.magnitude=SPs.magnitude/nsegs*seglen/npnts
		copyscales/p tmp_magS,sps.magnitude
		killdatafolder/z "root:Packages:WelchSpectrum"
	endif
end

Function Pgram(dw[,PgramMagS,win,pad])
	wave dw,PgramMagS
	string win
	variable pad
		
	string PgramName
	variable np,np2,magfac
	if(paramisdefault(PgramMagS))
		PgramName=GetWavesDataFolder(dw,2)
	else
		PgramName=GetWavesDataFolder(PgramMagS,2)
	endif
	make/o/d $PgramName
	wave PgramMagS=$PgramName
	duplicate/o dw,dwTemp
	wavestats/M=1/q dwTemp
	np=v_npnts
	dwTemp-=v_avg
	if(ParamIsDefault(pad) || (pad==0) || numtype(pad) || np>pad)
		np2=np+mod(np,2)
	else
		pad=round(pad)
		np2=pad+mod(pad,2)
//		np2=2^(ceil(log(np2)/log(2))+1)
	endif
	if(ParamIsDefault(win) || whichlistitem(win,K_FFTWindowList)<0)
		fft/PAD={np2}/DEST=$PgramName/MAGS dwTemp
	else
		fft/PAD={np2}/DEST=$PgramName/MAGS/WINF=$win dwTemp
		magfac=winNorm(np,win)
		PgramMagS/=magfac
	endif
	PgramMagS*=2/np^2			//normalizes to magnitude^2/np
	KillWaves /Z dwTemp
end

function winNorm(n,windowF)
	variable n
	string windowF
	
	newdatafolder/o root:Packages
	newdatafolder/o root:Packages:winNorm
	make/o/n=(n) root:Packages:winNorm:tmpWin
	wave tmpWin=root:Packages:winNorm:tmpWin
	tmpWin=1
	windowFunction/FFT=1 $windowF,tmpWin
	wavestats/q tmpWin
	killdatafolder/Z root:Packages:winNorm
	return v_rms^2
end

Function SPECTRUM_BlackmanTukey(SPs)
	struct SpectrumParameters &SPs
	
	if(SPs.getParams)
		SPS.SV.name[0]="Lag Fraction"
		SPS.SV.value[0]=0.25
		SPS.SV.low[0]=0.05
		SPS.SV.high[0]=1
		SPS.SV.inc[0]=0.05
		SPS.SV.name[1]="";SPS.SV.value[1]=nan;SPS.SV.low[1]=nan;SPS.SV.high[1]=nan;SPS.SV.inc[1]=nan
		SPS.SV.name[2]="";SPS.SV.value[2]=nan;SPS.SV.low[2]=nan;SPS.SV.high[2]=nan;SPS.SV.inc[2]=nan
		SPS.PM.name[0]="Taper Function"
		SPS.PM.value[0]="None;"+K_FFTWindowList
		SPS.PM.popStr[0]="Hamming"
		SPS.PM.popNum[0]=whichlistitem(SPS.PM.popStr[0],SPS.PM.value[0])+1
		SPS.PM.name[1]="";SPS.PM.value[1]="";SPS.PM.popStr[1]="";SPS.PM.popNum[1]=nan
		SPS.PM.name[2]="";SPS.PM.value[2]="";SPS.PM.popStr[2]="";SPS.PM.popNum[2]=nan
	else
		BTspec(SPs.dw_int,dwMag2Name=getWavesDataFolder(SPs.magnitude,2),lagfrac=SPS.SV.value[0],winF=SPs.PM.popStr[0],pad=1/SPs.freqRes/deltax(SPs.dw_int))
	endif	
end

Function BTspec(dw,[dw2,lagfrac,pad,winF,dwMag2Name,dwPhName,dw2Mag2name,dw2PhName,XMag2Name,XPhName,XCohName])
	wave dw,dw2;variable lagfrac,pad
	string dwMag2Name,dwPhName,dw2Mag2name,dw2PhName
	string winF,XMag2Name,XPhName,XCohName
	
	string dwFolder="",dwName="",dw2Name="",dw2Folder=""
	variable dw_avg,dw2_avg,x1,x2,dx,var,var2,cov,np,npad,lag
	
	dwFolder=GetWavesDatafolder(dw,1);dwName=nameofwave(dw)
	if(paramisdefault(dwMag2Name))
		dwMag2Name=dwFolder+dwName+"_BTMag2"
	endif
	if(paramisdefault(dwPhName))
		dwPhName=dwFolder+dwName+"_BTphase"
	endif
	if(ParamIsDefault(dw2))
		wave dw2=$getwavesdatafolder(dw,2)
	else
		dw2name=nameofwave(dw2)
		dw2Folder=getwavesdatafolder(dw2,1)
		if(ParamIsDefault(dw2Mag2Name))
			dw2Mag2Name=dw2Folder+dw2Name+"_BTMag2"
		endif
		if(ParamIsDefault(dw2PhName))
			dw2PhName=dw2Folder+dw2Name+"_BTphase"
		endif
		if(ParamIsDefault(XMag2Name))
			XMag2Name=dwFolder+dwName+"_"+dw2Name+"_XBTMag2"
		endif
		if(ParamIsDefault(XPhName))
			XPhName=dwFolder+dwName+"_"+dw2Name+"_XBTphase"
		endif
		if(ParamIsDefault(XCohName))
			XCohName=dwFolder+dwName+"_"+dw2Name+"_XBTcoh"
		endif
	endif
	NewDataFolder/o/s TMP_BTspec
	dx=max(abs(deltax(dw)),abs(deltax(dw2)))
	x1=max(pnt2x(dw,0),pnt2x(dw2,0))
	x2=min(pnt2x(dw,numpnts(dw)-1),pnt2x(dw2,numpnts(dw2)-1))
	if(x1>x2)
		doalert 0,"Waves don't overlap."
		return 0
	endif
	np=round(abs(x2-x1)/dx+1)
	if(ParamIsDefault(lagfrac))
		lag=round(np*2)
	else
		lag=ceil(lagfrac*(np*2-1))
		lag=lag-mod(lag,2)
	endif
	wavestats/q/r=(x1,x2) dw;dw_avg=v_avg;var=v_sdev^2
	wavestats/q/r=(x1,x2) dw2;dw2_avg=v_avg;var2=v_sdev^2
	cov=covariance(dw,dw2)
	make/d/o/n=(np) dwCorr,dw2Corr,XCorr
	setscale/p x x1,dx,dwCorr,dw2Corr,XCorr
	dwCorr=dw(x)-dw_avg;dw2Corr=dw2(x)-dw2_avg;XCorr=dw2(x)-dw2_avg

//calculate spectrum for dw:
	correlate dwCorr,XCorr;XCorr/=np
	correlate dw2Corr,dw2Corr;dw2Corr/=np
	correlate dwCorr,dwCorr;dwCorr/=np
	
	BTspec_calc(dwCorr,lag,npad=pad,win=winF);wave W_magsqr,W_phase
	duplicate/o W_magsqr,$dwMag2Name
	duplicate/o W_phase,$dwPhName
	wave dwMag2=$dwMag2Name,dwPh=$dwPhName
	//dwPh[0]=dwPh[1]//;unwrap 2*pi,dwPh
	if(strlen(dw2name))
//calculate spectrum for dw2:
		BTspec_calc(dw2Corr,lag,npad=pad,win=winF)
		duplicate/o W_magsqr,$dw2Mag2Name
		duplicate/o W_phase,$dw2PhName
		wave dw2Mag2=$dw2Mag2Name,dw2Ph=$dw2PhName
		//dw2Ph[0]=dw2Ph[1]//;unwrap 2*pi,dw2Ph
//calculate cross spectrum:
		BTspec_calc(XCorr,lag,npad=pad,win=winF)
		duplicate/o W_magsqr,$XMag2Name,$XCohName
		duplicate/o W_phase,$XPhName
		wave XMag2=$XMag2Name,XPh=$XPhName,XCoh=$XCohName
		//XPh[0]=XPh[1]//;unwrap 2*pi,XPh
		XCoh=min((XMag2)/(sqrt(dwMag2)*sqrt(dw2Mag2)),1)
		wavestats/q XMag2;v_max=(sqrt(v_max)*0.1)^2
		XPh=((XMag2>v_max)*(XCoh>0.5)) ? XPh : nan
		XCoh=((XMag2>v_max)*(XCoh>0.5)) ? XCoh : nan
	endif
	
	
	SetDataFolder ::
	killdatafolder TMP_BTspec
end

function BTspec_calc(w,lag[,npad,win])
	wave w;variable lag,npad;string win
	
	variable np,fftsign,magfac
	np=numpnts(w)
	if(ParamIsDefault(npad) || (npad==0) || numtype(npad))
		npad=np+mod(np,2)
	else
		npad=2*round(npad)
//		npad=2^(ceil(ln(lag)/ln(2))+1)
	endif
	rotate -floor((np-lag)/2),w;redimension/n=(lag) w
	if(ParamIsDefault(win) || whichlistitem(win,K_FFTWindowList)<0)
		fft/PAD={npad}/DEST=fftw w
	else
		fft/PAD={npad}/DEST=fftw/WINF=$win w
	endif
	wavetransform magsqr,fftw
	wavetransform phase,fftw
	wave W_magsqr
	W_magsqr=sqrt(W_magsqr)
	W_magsqr*=4/np	//normalizes to 2*magnitude^2/np, since np is twice the original number of points
end

Function Covariance(dw1,dw2)
	wave dw1,dw2
	
	variable avg1,avg2,i,np,summ=0
	np=numpnts(dw1)
	if(numpnts(dw2)!=np)
		return nan
	endif
	wavestats/q dw1;avg1=v_avg
	wavestats/q dw2;avg2=v_avg
	for(i=0;i<np;i+=1)
		summ+=(dw1[i]-avg1)*(dw2[i]-avg2)
	endfor
	return summ/(np-1)
end

Function SPECTRUM_MultiTaper(SPs)
	struct SpectrumParameters &SPs
	
	if(SPs.getParams)
		SPS.SV.name[0]="Number of Tapers:"
		SPS.SV.value[0]=3
		SPS.SV.low[0]=1
		SPS.SV.high[0]=inf	//should be bandwidth*2-1
		SPS.SV.inc[0]=1
		SPS.SV.name[1]="Time-Bandwidth Product:"
		SPS.SV.value[1]=2
		SPS.SV.low[1]=1
		SPS.SV.high[1]=inf	//should be npnts/2
		SPS.SV.inc[1]=1
		SPS.SV.name[2]="";SPS.SV.value[2]=nan;SPS.SV.low[2]=nan;SPS.SV.high[2]=nan;SPS.SV.inc[2]=nan
		SPS.PM.name[0]="";SPS.PM.value[0]="";SPS.PM.popStr[0]="";SPS.PM.popNum[0]=nan
		SPS.PM.name[1]="";SPS.PM.value[1]="";SPS.PM.popStr[1]="";SPS.PM.popNum[1]=nan
		SPS.PM.name[2]="";SPS.PM.value[2]="";SPS.PM.popStr[2]="";SPS.PM.popNum[2]=nan
	else
		duplicate/o SPs.magnitude,dummy
		MTM(SPs.dw_int,mtmMagS=SPs.magnitude,mtmFtest=dummy,nTapers=SPS.SV.value[0],bandwidth=SPS.SV.value[1],pad=1/SPs.freqRes)
	endif	
end

Function MTM(dw[,mtmMagS,mtmFtest,nTapers,bandwidth,pad])
	wave dw,mtmMagS,mtmFtest
	variable nTapers,bandwidth,pad
		
	string junkFolder="root:Packages:TFToolkit:MTMspec"
	NewDataFolderPath(junkFolder)
	
	string MagSName,FtestName
	variable np,np2,avg
	if(paramisdefault(mtmMagS))
		MagSName=GetWavesDataFolder(dw,2)+"_mtm"
	else
		MagSName=GetWavesDataFolder(mtmMagS,2)
	endif
	make/o/d $MagSName				//ensures double precision
	wave mtmMagS=$MagSName
	if(paramisdefault(mtmFtest))
		FtestName=GetWavesDataFolder(dw,2)+"_mtm"
	else
		FtestName=GetWavesDataFolder(mtmFtest,2)
	endif
	make/o/d $FtestName				//ensures double precision
	wave mtmFtest=$FtestName
	
	duplicate/o dw,$(junkFolder+":tempdw"),$(junkFolder+":tempMagS")
	wave tempdw=$(junkFolder+":tempdw"),tempMagS=$(junkFolder+":tempMagS")
	wavestats/M=1/q dw
	np=v_npnts
	avg=v_avg
	if(ParamIsDefault(pad) || (pad==0) || numtype(pad) || np>pad)
		np2=np+mod(np,2)
	else
		pad=round(pad)
		np2=pad+mod(pad,2)
//		np2=2^(ceil(log(np2)/log(2))+1)
	endif

	if(ParamIsDefault(bandwidth))
		bandwidth=2
	endif
	bandwidth=min(bandwidth,np/2)		//ensure bandwidth is small enough
	if(ParamIsDefault(nTapers))
		nTapers=3
	endif
	nTapers=min(nTapers,bandwidth*2-1)		//ensure number of tapers is small enough
	
	make/o/d $(junkFolder+":SlepTaps"),$(junkFolder+":SlepVals")
	wave SlepTaps=$(junkFolder+":SlepTaps"),SlepVals=$(junkFolder+":SlepVals")
	Slepian_Tapers(np,nTapers,bandwidth,SlepTaps,SlepVals)
	
	variable i
	for(i=0;i<nTapers;i+=1)
		tempdw=(dw-avg)*SlepTaps[p][i]
		fft/PAD={np2}/DEST=$getWavesDataFolder(tempMagS,2)/MAGS tempdw
		tempMagS/=SlepVals[i]
		if(i==0)
			duplicate/o tempMagS,mtmMagS
		else
			mtmMagS+=tempMagS
		endif
	endfor
	mtmMagS*=2/np^2/nTapers			//normalizes to magnitude^2/np
//	killDataFolder $junkFolder
end

Function Multi_Taper_Method(dw,rw,ft,nt,bw,hf,fr,el,es)
	wave dw,rw,ft;variable nt,bw,hf,fr,el,es
	
	variable npts,dstep,i,j,k,l,m
	
	npts=dimsize(dw,0);dstep=dimdelta(dw,0);rw=0;ft=0
	el=npts;es=npts
	make/o/n=(hf*max(el*dstep,1/fr),1) temprw=0,tempft=0;
	make/o/n=(hf*max(el*dstep,1/fr))/c tempfftsum;redimension/n=(hf/fr,1) rw,ft
	make/c/o/n=(hf*max(el*dstep,1/fr),nt) tempspec
	setscale/P x,0,fr,"cycles/"+waveunits(dw,0),rw,ft
	setscale/P x,0,min(1/(el*dstep),fr),"",temprw,tempft,tempfftsum
	make/o/d/n=(el,nt) SlepTaps=0;make/o/d/n=(nt) SlepVals=0
	Slepian_Tapers(el,nt,bw,SlepTaps,SlepVals)
	wave tapsum=tapsum;i=0;make/o tempfft;wave/c tempfftc=tempfft
	do
		duplicate/o/r=[i*es,i*es+el-1][][][] dw,tempdw
//		detrend(tempdw);j=0
		do
			m=0;tempfftsum=cmplx(0,0)
			do
				l=0
				do
					k=0
					do
						redimension/r/n=(el) tempfft;tempfft[]=tempdw[p][k][l][m]*sleptaps[p][j]
						redimension/n=(2*trunc(max(1/(2*dstep*fr),el/2))) tempfft;fft tempfft
						tempfftsum[]+=tempfft[p];k+=1
					while(k<dimsize(dw,1))
					l+=1
				while(l<dimsize(dw,2))
				m+=1
			while(m<dimsize(dw,3))
			duplicate/o tempfftsum,tempfft;tempfftc/=(k*l*m)
			tempspec[][j]=tempfftc[p]*dstep;tempfftc*=2*dstep/(SlepVals[j]*el*nt);tempfftc[0]/=2
			temprw[]+=sqrt(magsqr(tempfftc[p]))
			j+=1
		while(j<nt)
		regre2(tempspec,1+el/2,nt,tempft,tapsum,tempfft)
		redimension/n=(-1,i+1) rw,ft
		rw[][i]=sqrt(temprw[(pnt2x(rw,p)-dimoffset(temprw,0))/dimdelta(temprw,0)])
		ft[][i]=tempft[(pnt2x(rw,p)-dimoffset(tempft,0))/dimdelta(tempft,0)]
		i+=1
	while(i*es+el-1<npts)
	if(dimsize(rw,1)==1)
		redimension/n=(-1,0) rw,ft
	else
		setscale/P y,(pnt2x(dw,el/2-1)),(es*dstep),waveunits(dw,0),rw,ft
	endif
	killwaves/z tempdw,tempfft,temprw,tapsum,sleptaps,slepvals,tempspec,tempft
end

Function regre2(eigspec,nf,nt,ftest,tapsum,scratch)
	wave eigspec,ftest,tapsum;wave/c scratch;variable nf,nt

	variable sumvar,i,j,sum2
	variable/c sums

	do
		sumvar+=tapsum[i]*tapsum[i];i+=1
	while(i<nt)
	i=0
	do
		scratch[i]=cmplx(0,0);j=0
		do
			scratch[i]+=eigspec[i][j]*tapsum[j];j+=1
		while(j<nt)
		scratch[i]/=sumvar
		sum2=0;j=0
		do
			sums=eigspec[i][j]-scratch[i]*tapsum[j]
			sum2+=magsqr(sums);j+=1
		while(j<nt)
		ftest[i]=(nt-1)*magsqr(scratch[i])*sumvar/sum2
		i+=1
	while(i<nf)
end

Function Slepian_Tapers(np,nt,bw,eigvec,eigval)
	variable np,nt,bw;wave/d eigvec,eigval

//This procedure follows the algorithm described in 
//		J.M. Lees and J.ÊPark, Multi-taper spectral analysis: A stand-alone C-subroutine, 
//		Computers and Geology 21 (1995), no.Ê2, 199Ð236.

	
	string dfSave=getDataFolder(1),junkFolder="root:Packages:TFToolkit:MTMspec"
	NewDataFolderPath(junkFolder,set=1)
	
	make/d/o/n=(np) diag
	make/d/o/n=(np-1) subdiag
	make/d/o/n=(nt) tapsum
	variable dfac,drat,k,gamm,tapsq,i
	
	diag[]=-((np-1-2*p)/2)^2*(cos(2*pi*bw/np))	//eqn. 1 in Lees & Park, 1995
	subdiag[]=-(p+1)*(np-(p+1))/2					//eqn. 2 in Lees & Park, 1995
	
	MatrixOp/O EigVec=TriDiag(subdiag,diag,subdiag)
	MatrixEigenV/SYM/EVEC/RNG={2,1,(max(2,nt))} EigVec
	wave W_eigenvalues,m_eigenvectors
	duplicate/o/R=[0,nt-1] W_eigenvalues,EigVal			//Do we need to sort the eigenvalues first?
	duplicate/o/R=[][0,nt-1] M_eigenvectors,EigVec
	setdatafolder $dfSave

	dfac=pi*bw
	drat=8*dfac
	dfac=4*sqrt(pi*dfac)*exp(-2*dfac)
	for(k=0;k<nt;k+=1)
		eigval[k]=1-dfac
		dfac=dfac*drat/(k+1)  				//! is this correct formula? yes,but fails as k -> 2n
	endfor

	gamm=ln(8*np*sin(2*pi*bw/np))+0.5772156649

	eigval[]=max(1/(1+exp(pi*-2*pi*(bw-p/2-0.25)/gamm)),eigval[p])

	for(k=0;k<nt;k+=1)
		tapsum[k]=0;tapsq=0
		for(i=0;i<np;i+=1)
			tapsum[k]+=eigvec[i][k]
			tapsq+=eigvec[i][k]*eigvec[i][k]
		endfor
		tapsum[k]/=sqrt(tapsq/np)
		eigvec[]/=sqrt(tapsq/np)
	endfor
end

static Function NewDataFolderPath(path[,set])
	string path
	variable set
	
	variable depth=itemsinlist(path,":"),i
	string partial=stringfromlist(0,path,":")
	if(strlen(partial)==0)	//path is relative, beginning with a :
		partial="";i=1
	elseif(cmpstr("root",partial)==0) //path is full from root
		partial="root";i=1
	else						//path is relative, with no initial :
		partial="";i=0
	endif
	for(i=i;i<depth;i+=1)
		partial+=":"+possiblyquotename(cleanupname(StringFromList(i,path,":"),1))
		newdatafolder/o $partial
	endfor
	if(set)
		SetDataFolder $partial
	endif
end