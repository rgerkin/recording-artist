#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1		//November, 2007
constant K_BGmaxparams=3

Structure TFBackgroundParameters
	//Universal structure to be used for input parameters to any function producing a spectral estimate
	
	wave dw,xw				//input waves for XY-pair data
	wave dw_int				//input wave for waveform data
	wave magnitude,phase		//output waves
	variable getParams		//set to 1 when calling to retrieve info for creation of controls
	
	variable Fmin,Fmax		//minimum and maximum frequency of interest
	variable freqRes			//desired frequency resolution; if 0, default resolution (1/series length)
								//if <1/length, data will be padded to obtain desired resolution
	
	struct TFBGSetVar SV			//structures holding set-variable parameters specific to a spectral estimate method
	
	struct TFBGPopMenu PM		//structures holding popup menu parameters specific to a spectral estimate method
endStructure

Structure TFBGSetVar
	//parameters to create a set variable control
	string name[K_BGmaxparams]				//control name
	variable value	[K_BGmaxparams]			//value
	variable low[K_BGmaxparams],high[K_BGmaxparams]	//low and high limits and increment for creating set variable control
	variable inc[K_BGmaxparams]	
endStructure

Structure TFBGPopMenu
	//parameters to create a popup menu control
	string name[K_BGmaxparams]				//control name
	string value[K_BGmaxparams]				//semicolon-separated list for popup menu
	string popStr[K_BGmaxparams]				//value of selected item
	variable popNum[K_BGmaxparams]			//number of selected item
endStructure

Function TFBACKGROUND_prototype(BGPs)
	struct TFBackgroundParameters &BGPs
	
	if(BGPs.getParams)
		BGPS.SV.name[0]="";BGPS.SV.value[0]=nan;BGPS.SV.low[0]=nan;BGPS.SV.high[0]=nan;BGPS.SV.inc[0]=nan
		BGPS.SV.name[1]="";BGPS.SV.value[1]=nan;BGPS.SV.low[1]=nan;BGPS.SV.high[1]=nan;BGPS.SV.inc[1]=nan
		BGPS.SV.name[2]="";BGPS.SV.value[2]=nan;BGPS.SV.low[2]=nan;BGPS.SV.high[2]=nan;BGPS.SV.inc[2]=nan
		BGPS.PM.name[0]="";BGPS.PM.value[0]="";BGPS.PM.popStr[0]="";BGPS.PM.popNum[0]=nan
		BGPS.PM.name[1]="";BGPS.PM.value[1]="";BGPS.PM.popStr[1]="";BGPS.PM.popNum[1]=nan
		BGPS.PM.name[2]="";BGPS.PM.value[2]="";BGPS.PM.popStr[2]="";BGPS.PM.popNum[2]=nan
	else
	endif	
end

Function TFBACKGROUND_WhiteNoise(BGPs)			//calculates expected white noise spectrum
	struct TFBackgroundParameters &BGPs
	
	if(BGPs.getParams)
		BGPS.SV.name[0]="";BGPS.SV.value[0]=nan;BGPS.SV.low[0]=nan;BGPS.SV.high[0]=nan;BGPS.SV.inc[0]=nan
		BGPS.SV.name[1]="";BGPS.SV.value[1]=nan;BGPS.SV.low[1]=nan;BGPS.SV.high[1]=nan;BGPS.SV.inc[1]=nan
		BGPS.SV.name[2]="";BGPS.SV.value[2]=nan;BGPS.SV.low[2]=nan;BGPS.SV.high[2]=nan;BGPS.SV.inc[2]=nan
		BGPS.PM.name[0]="";BGPS.PM.value[0]="";BGPS.PM.popStr[0]="";BGPS.PM.popNum[0]=nan
		BGPS.PM.name[1]="";BGPS.PM.value[1]="";BGPS.PM.popStr[1]="";BGPS.PM.popNum[1]=nan
		BGPS.PM.name[2]="";BGPS.PM.value[2]="";BGPS.PM.popStr[2]="";BGPS.PM.popNum[2]=nan
	else
		variable N=numpnts(BGPs.dw_int)
		redimension/n=((BGPs.Fmax-BGPs.Fmin)/BGPs.FreqRes) BGPs.magnitude
		setscale/i x BGPs.Fmin,BGPs.Fmax,BGPs.magnitude
		wavestats/q BGPs.dw_int
		BGPs.magnitude=v_sdev/sqrt(N)
		BGPs.magnitude*=2*BGPs.magnitude
	endif	
end

Function TFBACKGROUND_RedNoise(BGPs)			//calculates expected AR1 red noise spectrum
	struct TFBackgroundParameters &BGPs
	
	if(BGPs.getParams)
		BGPS.SV.name[0]="";BGPS.SV.value[0]=nan;BGPS.SV.low[0]=nan;BGPS.SV.high[0]=nan;BGPS.SV.inc[0]=nan
		BGPS.SV.name[1]="";BGPS.SV.value[1]=nan;BGPS.SV.low[1]=nan;BGPS.SV.high[1]=nan;BGPS.SV.inc[1]=nan
		BGPS.SV.name[2]="";BGPS.SV.value[2]=nan;BGPS.SV.low[2]=nan;BGPS.SV.high[2]=nan;BGPS.SV.inc[2]=nan
		BGPS.PM.name[0]="";BGPS.PM.value[0]="";BGPS.PM.popStr[0]="";BGPS.PM.popNum[0]=nan
		BGPS.PM.name[1]="";BGPS.PM.value[1]="";BGPS.PM.popStr[1]="";BGPS.PM.popNum[1]=nan
		BGPS.PM.name[2]="";BGPS.PM.value[2]="";BGPS.PM.popStr[2]="";BGPS.PM.popNum[2]=nan
	else
		struct AR1_Params AR1p
		AR1_getParamsSimple(BGPs.dw_int,AR1p)
		
		variable N=numpnts(BGPs.dw_int)
		redimension/n=((BGPs.Fmax-BGPs.Fmin)/BGPs.FreqRes) BGPs.magnitude
		setscale/i x BGPs.Fmin,BGPs.Fmax,BGPs.magnitude
		BGPs.magnitude=AR1p.tau/deltax(BGPs.dw_int)*AR1p.alpha*sqrt(1/(1+(2*pi*x*AR1p.tau)^2)/N)*pi/2	//ref?
		BGPs.magnitude*=BGPs.magnitude/sqrt(2)
	//	BGPs.magnitude=sqrt((1-AR1p.gamm^2)/(1+AR1p.gamm^2-2*AR1p.gamm*cos(2*pi*p/N))/N)/2
	endif	
end

//This is a collection of functions that can estimate the AR(1) model parameters (contained in 
//the structure AR1_params) for a red noise data series and can use those parameters to 
//generate an artificial red noise series. The calculation follows that outlined by
//AS=Allen, M.R., and Smith, L.A., 1996, Monte Carlo SSA: detecting irregular 
//oscillations in the presence of coloured noise, Journal of Climate, 9:3373-3404

//written by Ben Cramer (bscramer@uoregon.edu)

Structure AR1_params
	variable u0				//mean of the AR(1) process
	variable c0				//variance of noise
	variable alpha			//standard deviation of the AR(1) process
	variable gamm			//lag-1 autocorrelation of the AR(1) process
	variable tau				//e-folding time of noise autocorrelation exponential decay
	variable mu2			//adjustment for statistical bias
endStructure

Function ARnoise(nw,m,s,tau)
	wave nw	//Wave to be filled with AR(1) (red) noise.
	variable m,s,tau
	
	struct AR1_params AR1p
	AR1p.u0=m
	AR1p.c0=s
	AR1p.tau=tau
	
	AR1p.gamm=e^(-1/AR1p.tau)
	AR1p.alpha=sqrt(AR1p.c0*(1-AR1p.gamm^2))
	nw[0][][]=sqrt(AR1p.c0)*gnoise(1)+AR1p.u0
	nw[1,dimsize(nw,0)-1][][]=AR1(nw[p-1][q][r],AR1p)
end

Function/d AR1(uprev,AR1p)
	variable uprev	//the previous value in the AR(1) noise series
	struct AR1_params &AR1p

//Returns values for filling out a wave with AR(1) (red) noise.  The first number
//of a series should be calculated as sqrt(alpha^2/(1-gamma^2))*gnoise(1)+u0

	return AR1p.gamm*(uprev-AR1p.u0)+AR1p.alpha*gnoise(1)+AR1p.u0
end

Function AR1_getParamsSimple(dw,AR1p)
	wave dw
	struct AR1_params &AR1p
	
	variable c1,crat,i,N,dbar
	wavestats/q/m=1 dw
	N=v_npnts
	dbar=v_avg
	
	newdatafolder/o root:Packages
	newdatafolder/o root:Packages:AR1
	make/d/o root:Packages:AR1:gamma_approx_coeffs
	wave gamma_approx_coeffs=root:Packages:AR1:gamma_approx_coeffs
	make/d/o/n=(N) root:Packages:AR1:getARparams_tempdw
	wave/d tw=root:Packages:AR1:getARparams_tempdw
	
	tw[]=(dw[p]-dbar)	^2				//remove mean
	AR1p.c0=sum(tw)/(N)					//estimate the lag-0 covariance of dw
	redimension/n=(N-1) tw
	tw[]=(dw[p]-dbar)*(dw[p+1]-dbar)
	c1=sum(tw,-inf,inf)/(N-1)		//estimate lag-1 covariance of dw
	crat=c1/AR1p.c0							//ratio of lag-1 and lag-0 covariance
	gamma_approx_coeffs={N,crat}
	if(crat>(N^2-3*N-1)/(N^2-1))
		AR1p.gamm=0.99999	//When C>(N^2-3*N-1)/(N^2-1), the equation cannot be solved uniquely.
					//Instead, we set gamma to a default value of 1; see footnote 4 in AS(4.3)
	else
			//The next line approximates gamma by using optimize to find the solution
			//to the equation c1/c0=1-mu^2) or tr(QCnQ,1)/tr(QCnQ,0)=tr(QCdQ,1)/tr(QCdQ,0)
		optimize/T=.0000001/L=0.0001/H=0.99999/Q gamma_approx,gamma_approx_coeffs
											//This may fail near endpoints
		if((v_min>0.000001) || (numtype(v_min)!=0))
//			print "gamma="+num2str(V_minloc)
//			abort "no solution found for gamma"	//abort if there is no solution to the equation
			doalert 0,"AR(1) parameters cannot be calculated!"
		endif
		AR1p.gamm=max(0.1,V_minloc)
	endif
	AR1p.mu2=mu_squared(N,AR1p.gamm)				//get mu2
	AR1p.c0/=1-AR1p.mu2							//solve for c0, simple AR(1) case
	AR1p.alpha=sqrt((1-AR1p.gamm^2)*AR1p.c0)			//solve for alpha
	AR1p.tau=-deltax(dw)/ln(AR1p.gamm)
	killdatafolder root:Packages:AR1
end
	
Function getARparams(dw,K,AR1p,Cw,Ew)
	wave/d dw,Cw,Ew;wave K
	struct AR1_params &AR1p
	
//Calculates the input parameters to generate AR(1) (red) noise
//having the same variance (alpha) and lag-1 autocorrelation
//(gamma) as the data series (dw).  It is assumed that the process
//mean is unknown; the statistical mean is removed from w and 
//a correction is used to approximate gamma and alpha.  See AS(4.3).
//If the simple AR(1) model is desired, use a null wave reference for K.
//If K is a valid wave reference, parameters for an AR(1) + signal model
//will be returned; K should then be of length M, with 0s in positions
//corresponding to EOFs which are considered signal and 1s in all other positions.

	variable crat,i,M=numpnts(K)
	variable N=numpnts(dw),dbar=mean(dw,-inf,inf);dw-=dbar	//remove mean
	make/d/o gamma_approx_coeffs
	variable simple=floor(sum(K,-inf,inf)/M)
	if(simple==0)	//use AR(1) + signal model
		make/d/o/n=(M,M) M_product
		IdentityMat(M_product);M_Product[][]*=K[p]	//M_product now contains K
		MatrixMultiply Ew,M_product,Ew/T
		duplicate/o M_product,getARparams_tempQ
		wave/d Qn=getARparams_tempQ
		MatrixMultiply M_product,Cw,M_product
		duplicate/o M_product,getARparams_tempQCQ
		wave/d QCQ=getARparams_tempQCQ
		gamma_approx_coeffs={N,tr(QCQ,1)/tr(QCQ,0),M}
		crat=0
	else		//use simple AR(1) model
		make/d/o/n=(N) getARparams_tempdw=0;wave/d tw=getARparams_tempdw
		tw[]=(dw[p])^2;AR1p.c0=sum(tw,-inf,inf)/N	//estimate the lag-0 covariance of dw
		redimension/n=(N) tw;tw[]=(dw[p])*(dw[p+1])
		crat=sum(tw,-inf,inf)/(N-1)/AR1p.c0		//estimate lag-1 and divide by lag-0 covariance of dw
		gamma_approx_coeffs={N,crat}
	endif
	if(crat>(N^2-3*N-1)/(N^2-1))
		AR1p.gamm=1	//When C>(N^2-3*N-1)/(N^2-1), the equation cannot be solved uniquely.
					//Instead, we set gamma to a default value of 1; see footnote 4 in AS(4.3)
	else
			//The next line approximates gamma by using optimize to find the solution
			//to the equation c1/c0=1-mu^2) or tr(QCnQ,1)/tr(QCnQ,0)=tr(QCdQ,1)/tr(QCdQ,0)
		optimize/T=.0000001/L=0.0001/H=0.99999/Q gamma_approx,gamma_approx_coeffs
											//This may fail near endpoints
		if((v_min>0.000001) | (numtype(v_min)!=0))
//			print "gamma="+num2str(V_minloc)
//			abort "no solution found for gamma"	//abort if there is no solution to the equation
			doalert 0,"AR(1) parameters cannot be calculated!"
		endif
		AR1p.gamm=V_minloc
	endif
	AR1p.mu2=mu_squared(N,AR1p.gamm)				//get mu2
	if(simple==0)
		make/d/o/n=(M,M) M_product
		M_product[][]=AR1p.gamm^(abs(p-q))-AR1p.mu2	//Get W
		MatrixMultiply Qn,M_product,Qn
		duplicate/o M_product,getARparams_tempQWQ
		wave/d QWQ=getARparams_tempQWQ			//get QWQ
		AR1p.c0=tr(QCQ,0)/tr(QWQ,0)					//solve for c0, AR(1) + signal case
	else
		AR1p.c0/=1-AR1p.mu2								//solve for c0, simple AR(1) case
	endif
	AR1p.alpha=sqrt((1-AR1p.gamm^2)*AR1p.c0)		//solve for alpha
	dw+=dbar
	killwaves/z tw,gamma_approx_coeffs,mu2_temp,Qn,M_product,QCQ,QWQ
end

Function/d gamma_approx(w,gamm)
	wave/d w;variable gamm
	
//Function for minimization in order to find gamma for input into AR(1).
//Based on the number of points in w, choosed either simple AR(1) model or AR(1) + signal model.

//For simple AR(1) model:
//w[0] should contain N - the number of points in the data series
//w[1] should contain c1/c0 - the ratio of the lag-1 covariance to the lag-0 covariance of the data.

	variable mu2=mu_squared(w[0],gamm)
	if(numpnts(w)==2)
		return abs(w[1]-(gamm-mu2)/(1-mu2))
		
//For AR(1) + signal model:
//w[0] should contain N - the number of points in the data series
//w[1] should contain tr(QCQ,1)/tr(QCQ,0)
//w[2] should contain M - the dimensionality of the lag-covariance matrix.
	else
		wave/d Qn=getARparams_tempQ	//Q, the "noise projection matrix", must be created in the calling procedure.
		make/d/o/n=(w[2],w[2]) M_product=0
		M_product[][]=gamm^(abs(p-q))-mu2
			//M_product contains the matrix W'; c0W'=Cnw, the expected lag-covariance matrix for the noise.
		MatrixMultiply Qn,M_product,Qn
		duplicate/o M_product, getARparams_tempQWQ;wave/d QWQ=getARparams_tempQWQ
		killwaves/z M_product
		variable trrat=tr(QWQ,1)/tr(QWQ,0)
		return abs(trrat-w[1])
	endif
end

Function/d tr(mat,j)
	wave/d mat;variable j
	
//Calculates a "generalised trace operator" used to find noise parameters in getARparams().
//mat should be of dimension M x M.
	
	variable M=dimsize(mat,0)-j,temp;make/d/o/n=(M) tr_tempmat
	tr_tempmat[]=mat[p][p+j];temp=mean(tr_tempmat,-inf,inf)
	killwaves tr_tempmat
	return temp
end
	
Function/d mu_squared(N,gamm)
	variable N,gamm
	
//Supplies mu^2, a parameter used to adjust for bias introduced by removing the statistical mean from the data series
	
	return (((N-gamm^N)/(1-gamm)-gamm*(1-gamm^(N-1))/(1-gamm)^2)*2/N^2)-1/N
end

static Function IdentityMat(mat)
	wave/d mat
	
	variable i
	
	mat=0
	do
		mat[i][i]=1;i+=1
	while(i<dimsize(mat,0))
end

