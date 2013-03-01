#pragma rtGlobals=1		// Use modern global access method.

//Lomb periodogram functions for performing spectral analysis on unequally sampled
//data sets.  Function Lomb is much too slow to be used for anything with n>1000.
//Function fastLomb is a faster version that only sacrifices some of the precision.
//Translated from Numerical Recipes in FORTRAN.

//modified from Numerical Recipes by Ben Cramer (bscramer@uoregon.edu)

Function SPECTRUM_XY_Lomb(SPs)
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
		newdatafolderpath("root:Packages:Spectra:Lomb")
		if(!waveexists(SPs.xw))
			doalert 0,"Lomb periodogram is inappropriate for waveform data. Proceding with a dummy X wave."
			duplicate/o SPs.dw_int,root:Packages:Spectra:Lomb:dummyX
			wave SPs.xw=root:Packages:Spectra:Lomb:dummyX
			SPs.xw=x
		endif
		fastLomb(SPs.xw,SPs.dw,pr=SPs.magnitude,ofac=4,hifac=2,win=SPs.PM.popStr[0])			//calculate periodogram		
		WaveStats/Q SPs.dw
		SPs.magnitude=sqrt(SPs.magnitude)				//change amplitude from mag2 to mag
		killdatafolder/z "root:Packages:Spectra:Lomb"
	endif
end

Function SPECTRUM_XY_LombWelch(SPs)
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
		string JunkFolder="root:Packages:Spectra:LombWelch"
		newdatafolderpath(JunkFolder)
		make/o/d $(JunkFolder+":tmp_dw"),$(JunkFolder+":tmp_xw"),$(JunkFolder+":tmp_magS")
		wave tmp_dw=$(JunkFolder+":tmp_dw"),tmp_xw=$(JunkFolder+":tmp_xw"),tmp_magS=$(JunkFolder+":tmp_magS")
		variable i,npnts,nsegs,seglen,segoffset,segolf,p1,p2
		if(!waveexists(SPs.xw))
			doalert 0,"Lomb periodogram is inappropriate for waveform data. Proceding with a dummy X wave."
			duplicate/o SPs.dw_int,$(JunkFolder+":dummyX")
			wave SPs.xw=$(JunkFolder+":dummyX")
			SPs.xw=x
		endif
		npnts=numpnts(SPs.dw_int)
		nsegs=SPs.SV.value[0]
		segolf=SPs.SV.value[1]/100
		seglen=(SPs.Xmax-SPs.Xmin)/(nsegs-nsegs*segolf+segolf)
		segoffset=seglen*(1-segolf)
		for(i=0;i<nsegs;i+=1)
			p1=max(0,binarysearch(SPS.xw,SPs.Xmin+i*segoffset)+1)
			p2=binarysearch(SPs.xw,SPs.Xmin+i*segoffset+seglen)
			if(p2<0)
				p2=npnts-1
			endif
			duplicate/r=[p1,p2]/o SPs.dw,tmp_dw
			duplicate/r=[p1,p2]/o SPs.xw,tmp_xw
			fastLomb(tmp_xw,tmp_dw,pr=tmp_magS,ofac=4,hifac=2,win=SPs.PM.popStr[0])		//calculate periodogram	
			if(i==0)
				duplicate/o tmp_magS,SPs.Magnitude
			else
				SPs.magnitude+=tmp_magS
			endif
		endfor
		SPs.magnitude=sqrt(SPs.magnitude/nsegs^2)
		copyscales/p tmp_magS,sps.magnitude
		killdatafolder/z junkFolder
	endif
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

Function/S Lomb(xw,yw[,ofac,hifac,pr])
	wave xw,yw,pr;variable ofac,hifac

//Given data with abscissas xw (which need not be equally spaced or sorted) and ordinates
//yw, and given a desired oversampling factor ofac (a typical value being 4 or larger),
//this routine fills array pr with an increasing sequence of frequencies (not angular frequencies)
//up to hifac times the "average" Nyquist frequency.  pr is waveform, with scaling set as cycles/unit
//of yw. The arrays xw and yw are not altered.
//pr is redimensioned to be large enough to contain the output. The routine also returns jmax
//such that pr(jmax) is the maximum element in pr, and prob, an estimate of the significance of
//that maximum against the hypothesis of random noise. A small value of prob indicates that a
//significant periodic signal is present.  The values are returned as a string value:
//num2str(jmax)+";"+num2str(prob)

	variable nout,np,jmax,prob
	
	variable i,j,ave,c,cc,cwtau,effm,expy,pymax,s,ss,sumc,sumcy,sums,sumsh,sumsy,swtau
	variable var,wtau,xave,xdif,xmax,xmin,yy,arg,wtemp
	make/n=(2000)/d/o wi,wpi,wpr,wr
	
	if(paramIsDefault(ofac))
		ofac=4
	endif
	if(paramIsDefault(hifac))
		hifac=1
	endif
	if(paramisdefault(pr))
		return ""
	endif
	np=dimsize(xw,0);nout=0.5*ofac*hifac*np
	redimension/n=(nout) pr
	wavestats/q yw;ave=v_avg;var=v_sdev^2		//Get mean and variance of the input data.
	wavestats/q xw;xmax=v_max;xmin=v_min		//Get the range of abscissas.
	xdif=xmax-xmin;xave=(xmax+xmin)/2
	pymax=0
	setscale/P x,1/(xdif*ofac),1/(xdif*ofac),"cycles/"+waveunits(xw,-1),pr
	
//Initialize values for the trigonometric recurrences at each data point.
//The recurrences are done in double precision.
	wpr[]=-2*sin(pi*((xw[p]-xave)/(xdif*ofac)))^2
	wpi[]=sin(2*pi*((xw[p]-xave)/(xdif*ofac)))
	wr[]=cos(2*pi*((xw[p]-xave)/(xdif*ofac)))
	wi[]=wpi[p]

//Main loop over the frequencies to be evaluated.	
	i=0
	do

//First, loop over the data to get tau and related quantities.
		sumsh=0;sumc=0;j=0
		do
			c=wr[j];s=wi[j];sumsh=sumsh+s*c;sumc=sumc+(c-s)*(c+s);j+=1
		while(j<np)
		wtau=0.5*atan2(2*sumsh,sumc)
		swtau=sin(wtau);cwtau=cos(wtau)

//Then, loop over the data again to get the periodogramvalue.
		sums=0;sumc=0;sumsy=0;sumcy=0;j=0
		do
			s=wi[j];c=wr[j]
			ss=s*cwtau-c*swtau;cc=c*cwtau+s*swtau
			sums=sums+ss^2;sumc=sumc+cc^2
			yy=yw[j]-ave;sumsy=sumsy+yy*ss;sumcy=sumcy+yy*cc
			wtemp=wr[j]									//Update the trigonometric recurrences.
			wr[j]=(wr[j]*wpr[j]-wi[j]*wpi[j])+wr[j]
			wi[j]=(wi[j]*wpr[j]+wtemp*wpi[j])+wi[j]
			j+=1
		while(j<np)
		pr[i]=0.5*(sumcy^2/sumc+sumsy^2/sums)/var
		if (pr[i]>=pymax)
			pymax=pr[i]
			jmax=i
		endif
		i+=1
	while(i<nout)
	expy=exp(-pymax)		//Evaluate statistical significance of the maximum.
	effm=2*nout/ofac
	prob=effm*expy
	if(prob>0.01)
		prob=1-(1-expy)^effm
	endif
	killwaves/z wr,wpr,wpi,wi
	return num2str(jmax)+";"+num2str(prob)
END

Function/S fastLomb(xw,yw[,ofac,hifac,pr,sig,win])
	wave xw,yw,pr,sig;variable ofac,hifac;string win

//Given data with abscissas xw (which need not be equally spaced or sorted) and ordinates
//yw, and given a desired oversampling factor ofac (a typical value being 4 or larger),
//this routine fills array pr with an increasing sequence of frequencies (not angular frequencies)
//up to hifac times the "average" Nyquist frequency.  pr is waveform, with scaling set as cycles/unit
//of yw. The arrays xw and yw are not altered.
//pr is redimensioned to be large enough to contain the output. The routine also returns jmax
//such that pr(jmax) is the maximum element in pr, and prob, an estimate of the significance of
//that maximum against the hypothesis of random noise. A small value of prob indicates that a
//significant periodic signal is present.  The values are returned as a string value:
//num2str(jmax)+";"+num2str(prob)
//optionally fills a significance wave; enter $"" for sig if you don't want the significance wave.
//To suppress leakage, a window function (win) can be specified from the choices for Igors WindowFunction operation.

	variable np,nout,jmax,prob
	variable MACC=4		//Number of interpolation points per 1/4 cycle of highest frequency.
	variable j,ndim,nfreq,nfreqt
	variable ave,ck,ckk,cterm,cwt,den,df,effm,expy,fac,fndim,hc2wt,hs2wt,hypo,pmax,sterm,swt,var
	variable xdif,xmax,xmin
	
	if(paramIsDefault(ofac))
		ofac=4
	endif
	if(paramIsDefault(hifac))
		hifac=1
	endif
	if(paramisdefault(pr))
		return ""
	endif
	np=dimsize(xw,0);nout=0.5*ofac*hifac*np;nfreqt=ofac*hifac*np*MACC;nfreq=32
	do		//Size the FFT as next power of 2 above nfreqt.
		nfreq*=2
	while(nfreq<nfreqt)
	ndim=2*nfreq
	redimension/n=(ndim) pr
	wavestats/q yw;ave=v_avg;var=v_sdev^2		//Compute the mean, variance, and range of the data.
	wavestats/q xw;xmin=v_min;xmax=v_max
	xdif=xmax-xmin
	pr=0;duplicate/o pr,wk		//Zero the workspaces.
	fac=ndim/(xdif*ofac);fndim=ndim
	
//taper, if specified
	if(ParamIsDefault(win) || whichlistitem(win,K_FFTWindowList)<0)
	else
		make/n=(nout*2) tmpWin=1
		setscale/I x,xmin,xmax,tmpWin
		windowFunction $win,tmpWin
		duplicate/o yw,ywWin
		wave yw=ywWin
		yw*=tmpWin(xw[p])
	endif
	
//Extirpolate the data into the workspaces.
	for(j=0;j<np;j+=1)
		if(numtype(xw[j])+numtype(yw[j])==0)
			ck=1+mod((xw[j]-xmin)*fac,fndim);ckk=1+mod(2*(ck-1),fndim)
			spread(yw[j]-ave,pr,ndim,ck,MACC);spread(1,wk,ndim,ckk,MACC)
		endif
	endfor
	duplicate/o pr,temppr;duplicate/o wk,tempwk
	fft temppr;fft tempwk		//Take the Fast Fourier Transforms.
	setscale/P x,1/(xdif*ofac),1/(xdif*ofac),"cycles/"+waveunits(xw,-1),pr
	pmax=-1
	
//Compute the Lomb value for each frequency.
	for(j=0;j<nout;j+=1)
		hypo=magsqr(tempwk[j+1])
		hc2wt=0.5*real(tempwk[j+1])/hypo
		hs2wt=0.5*imag(tempwk[j+1])/hypo
		cwt=sqrt(0.5+hc2wt)
		if(sign(hs2wt)==1)
			swt=abs(sqrt(0.5-hc2wt))
		else
			swt=-abs(sqrt(0.5-hc2wt))
		endif
		den=0.5*np+hc2wt*real(tempwk[j+1])+hs2wt*imag(tempwk[j+1])
		cterm=(cwt*real(temppr[j+1])+swt*imag(temppr[j+1]))^2/den
		sterm=(cwt*imag(temppr[j+1])-swt*real(temppr[j+1]))^2/(np-den)
		pr[j]=(cterm+sterm)/(2*var)
		if (pr[j]>pmax)
			pmax=pr[j];jmax=j
		endif
	endfor
	redimension/n=(j) pr
//correct for taper, if specified
	if(ParamIsDefault(win) || whichlistitem(win,K_FFTWindowList)<0)
	else
		pr/=winNorm(nout*2,win)
	endif
	pr*=var/nfreq*2000	//fudge factor
	
//Estimate significance of largest peak value.
	expy=exp(-pmax);effm=2*nout/ofac;prob=effm*expy
	if(prob>0.01)
		prob=1-(1-expy)^effm
	endif
	if(waveexists(sig))
		duplicate/o pr,sig
		sig=exp(-pr)
		for(j=0;j<nout;j+=1)
			if(sig*effm>0.01)
				sig=1-(1-sig)^effm
			else
				sig=sig*effm
			endif
		endfor
	endif
	killwaves/z wk,temppr,tempwk,ywWin,tmpWin
	return num2str(jmax)+";"+num2str(prob)
end

Function spread(yy,yw,np,xx,mm)
	wave yw;variable yy,np,xx,mm
	
//Given an array yw of length np, extirpolate (spread) a value yy into mm actual array elements
//that best approximate the "fictional" (i.e., possibly noninteger) array element number xx.
//The weights used are coefficients of the Lagrange interpolating polynomial.
	
	variable ihi,ilo,ix,j,nden,fac
	
	ix=trunc(xx)
	if(xx==ix)
		yw[ix]=yw[ix]+yy
	else
		ilo=min(max(trunc(xx-0.5*mm+1),1),np-mm+1)
		ihi=ilo+mm-1
		nden=factorial(mm)
		fac=xx-ilo
		for(j=ilo+1;j<=ihi;j+=1)
			fac=fac*(xx-j)
		endfor
		yw[ihi]=yw[ihi]+yy*fac/(nden*(xx-ihi))
		for(j=ihi-1;j>=ilo;j-=1)
			nden=(nden/(j+1-ilo))*(j-ihi)
			yw[j]=yw[j]+yy*fac/(nden*(xx-j))
		endfor
	endif
end