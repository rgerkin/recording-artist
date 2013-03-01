#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1		//November 12, 2007
#pragma IgorVersion=6

//This procedure file provides a structure and wrapper functions to add interpolation 
//controls to a separately programmed control panel.

//For an example of how to use the wrapper functions, see the Time-Frequency procedure file.

//The Igor built-in Loess and Interpolate2 (linear and cubic spline) operations are supported in this procedure file, and a routine to calculate
//gaussian smoothed, median value, and mean value interpolations are also provided.

//written by Ben Cramer (bscramer@uoregon.edu)


static constant K_Interpmaxparams=3

Structure InterpolationParameters
	//Universal structure to be used for input parameters to any interpolation function
	
	wave dw,xw				//input waves for XY-pair data
	wave/D dw_int				//output wave for interpolated data
	variable getParams		//set to 1 when calling to retrieve info for creation of controls
	
	variable Xmin,Xmax		//minimum and maximum x values to define a subrange of the data
	variable interpRes
	
	struct InterpolationSetVar SV			//structures holding set-variable parameters specific to an interpolation method
	
	struct InterpolationPopMenu PM		//structures holding popup menu parameters specific to an interpolation method
endStructure

Structure InterpolationSetVar
	//parameters to create a set variable control
	string name[K_Interpmaxparams]				//control name
	variable value	[K_Interpmaxparams]			//value
	variable low[K_Interpmaxparams],high[K_Interpmaxparams]	//low and high limits and increment for creating set variable control
	variable inc[K_Interpmaxparams]	
endStructure

Structure InterpolationPopMenu
	//parameters to create a popup menu control
	string name[K_Interpmaxparams]				//control name
	string value[K_Interpmaxparams]				//semicolon-separated list for popup menu
	string popStr[K_Interpmaxparams]				//value of selected item
	variable popNum[K_Interpmaxparams]			//number of selected item
endStructure

Function INTERPOLATION_prototype(IPs)
	struct InterpolationParameters &IPs
	
	if(IPs.getParams)
		IPs.SV.name[0]="";IPs.SV.value[0]=nan;IPs.SV.low[0]=nan;IPs.SV.high[0]=nan;IPs.SV.inc[0]=nan
		IPs.SV.name[1]="";IPs.SV.value[1]=nan;IPs.SV.low[1]=nan;IPs.SV.high[1]=nan;IPs.SV.inc[1]=nan
		IPs.SV.name[2]="";IPs.SV.value[2]=nan;IPs.SV.low[2]=nan;IPs.SV.high[2]=nan;IPs.SV.inc[2]=nan
		IPs.PM.name[0]="";IPs.PM.value[0]="";IPs.PM.popStr[0]="";IPs.PM.popNum[0]=nan
		IPs.PM.name[1]="";IPs.PM.value[1]="";IPs.PM.popStr[1]="";IPs.PM.popNum[1]=nan
		IPs.PM.name[2]="";IPs.PM.value[2]="";IPs.PM.popStr[2]="";IPs.PM.popNum[2]=nan
	else
//		IPs.dw_int=nan
	endif	
end

Function INTERPOLATION_Linear(IPs)
	struct InterpolationParameters &IPs

	if(IPs.getParams)
		IPs.SV.name[0]="";IPs.SV.value[0]=nan;IPs.SV.low[0]=nan;IPs.SV.high[0]=nan;IPs.SV.inc[0]=nan
		IPs.SV.name[1]="";IPs.SV.value[1]=nan;IPs.SV.low[1]=nan;IPs.SV.high[1]=nan;IPs.SV.inc[1]=nan
		IPs.SV.name[2]="";IPs.SV.value[2]=nan;IPs.SV.low[2]=nan;IPs.SV.high[2]=nan;IPs.SV.inc[2]=nan
		IPs.PM.name[0]="";IPs.PM.value[0]="";IPs.PM.popStr[0]="";IPs.PM.popNum[0]=nan
		IPs.PM.name[1]="";IPs.PM.value[1]="";IPs.PM.popStr[1]="";IPs.PM.popNum[1]=nan
		IPs.PM.name[2]="";IPs.PM.value[2]="";IPs.PM.popStr[2]="";IPs.PM.popNum[2]=nan
	else
		Interpolate2/I=3/T=1/Y=$(getwavesdatafolder(IPs.dw_int,2)) IPs.xw,IPs.dw
	endif	
end

Function INTERPOLATION_Spline(IPs)
	struct InterpolationParameters &IPs

	if(IPs.getParams)
		IPs.SV.name[0]="Smoothing Factor:";IPs.SV.value[0]=1;IPs.SV.low[0]=0;IPs.SV.high[0]=inf;IPs.SV.inc[0]=0.1
		IPs.SV.name[1]="";IPs.SV.value[1]=nan;IPs.SV.low[1]=nan;IPs.SV.high[1]=nan;IPs.SV.inc[1]=nan
		IPs.SV.name[2]="";IPs.SV.value[2]=nan;IPs.SV.low[2]=nan;IPs.SV.high[2]=nan;IPs.SV.inc[2]=nan
		IPs.PM.name[0]="";IPs.PM.value[0]="";IPs.PM.popStr[0]="";IPs.PM.popNum[0]=nan
		IPs.PM.name[1]="";IPs.PM.value[1]="";IPs.PM.popStr[1]="";IPs.PM.popNum[1]=nan
		IPs.PM.name[2]="";IPs.PM.value[2]="";IPs.PM.popStr[2]="";IPs.PM.popNum[2]=nan
	else
		Interpolate2/F=(IPs.SV.value[0])/S=(IPs.SV.value[1])/I=3/T=3/Y=$(getwavesdatafolder(IPs.dw_int,2)) IPs.xw,IPs.dw
	endif	
end

Function INTERPOLATION_Loess(IPs)
	struct InterpolationParameters &IPs

	if(IPs.getParams)
		IPs.SV.name[0]="Smoothing Factor:";IPs.SV.value[0]=0.1;IPs.SV.low[0]=0.005;IPs.SV.high[0]=1;IPs.SV.inc[0]=0.005
		IPs.SV.name[1]="";IPs.SV.value[1]=nan;IPs.SV.low[1]=nan;IPs.SV.high[1]=nan;IPs.SV.inc[1]=nan
		IPs.SV.name[2]="";IPs.SV.value[2]=nan;IPs.SV.low[2]=nan;IPs.SV.high[2]=nan;IPs.SV.inc[2]=nan
		IPs.PM.name[0]="Regression Order:"
		IPs.PM.value[0]="0 (Constant);1 (Line, Lowess);2 (Quadratic, Loess)"
		IPs.PM.popStr[0]="2 (Quadratic, Loess)";IPs.PM.popNum[0]=3
		IPs.PM.name[1]="Robust Fitting:";IPs.PM.value[1]="No;Yes";IPs.PM.popStr[1]="No";IPs.PM.popNum[1]=1
		IPs.PM.name[2]="";IPs.PM.value[2]="";IPs.PM.popStr[2]="";IPs.PM.popNum[2]=nan
	else
		Loess/DEST=$getwavesdatafolder(IPs.dw_int,2)/DFCT/SMTH=(IPs.SV.value[0])/ORD=(IPs.PM.popNum[0]-1)/R=(IPs.PM.popNum[1]-1)/V=0/Z srcWave=IPs.dw,factors={IPs.xw}
	endif	
end

Function INTERPOLATION_Gaussian(IPs)
	struct InterpolationParameters &IPs

	if(IPs.getParams)		
		IPs.SV.name[0]="Cutoff Period:"
		if(IPs.interpRes>0)
			IPs.SV.value[0]=10*IPs.interpRes
		else
			IPs.SV.value[0]=1
		endif
		IPs.SV.low[0]=0;IPs.SV.high[0]=inf;IPs.SV.inc[0]=0.1
		
		IPs.SV.name[1]="Response at Cutoff:";IPs.SV.value[1]=0.2;IPs.SV.low[1]=0.05;IPs.SV.high[1]=0.95;IPs.SV.inc[1]=0.05
		IPs.SV.name[2]="";IPs.SV.value[2]=nan;IPs.SV.low[2]=nan;IPs.SV.high[2]=nan;IPs.SV.inc[2]=nan
		IPs.PM.name[0]="";IPs.PM.value[0]="";IPs.PM.popStr[0]="";IPs.PM.popNum[0]=nan
		IPs.PM.name[1]="";IPs.PM.value[1]="";IPs.PM.popStr[1]="";IPs.PM.popNum[1]=nan
		IPs.PM.name[2]="";IPs.PM.value[2]="";IPs.PM.popStr[2]="";IPs.PM.popNum[2]=nan
	else
		GaussInterpolate(IPs.dw_int,IPs.dw,xw=IPs.xw,period=IPs.SV.value[0],response=IPs.SV.value[1])
	endif	
end

Function GaussInterpolate(dw_int,dw[,xw,period,response,extrapolate,minsum])
//Interpolates using Gaussian filter weights. Input can be either XY or waveform data. Output is waveform data. 
//The interpolated resolution and data limits are taken from the preset wave scaling of dw_int
	
	wave dw_int	//returns the result of the interpolation. Wave length and scaling should be set prior to calling the interpolation
	wave dw		//input data wave
	wave/Z xw		//input position waves. xw is optional to allow gaussian interpolation of waveform data
	variable period,response	//define the gaussian filter by giving desired response at a given periodicity. Values of response >=1 or <=0 will default to cutoff response of 0.1
	variable extrapolate	//non-zero to generate non-NaN values for all points in dw_int, even if they fall <min(xw) or >max(xw); default value is 0
	variable minsum		//define minimum sum of weights to produce a non-NaN value

	string dfSave=getdatafolder(1)
	NewDataFolder/o/s root:Packages
	NewDataFolder/o/s root:Packages:GaussInterpolate
	make/o/d tmp_dw,tmp_xw
	make/o/d GaussCoeffs
	setdatafolder $dfSave
	
	variable npts1,npts2,dx,i,j,xval,leftwt,rightwt,leftsum,rightsum,xpt
	npts1=numpnts(dw_int)
	dx=deltax(dw_int)
	if(waveexists(xw))
		duplicate/o/d dw,tmp_dw;duplicate/o/d xw,tmp_xw
	else
		duplicate/o/d dw,tmp_dw,tmp_xw;tmp_xw=x
	endif
	RemoveNaNs(tmp_dw,w2=tmp_xw)
	sort tmp_xw,tmp_xw,tmp_dw
	npts2=numpnts(tmp_dw)
	
	if(ParamIsDefault(minsum))
		minsum=1E-9
	endif
	if(ParamIsDefault(response) || (response>=1) || (response<=0))
		response=0.1
	endif
	if(ParamIsDefault(period))
		period=2*dx
	endif
	
	GaussKernel(GaussCoeffs,npts1,dx,period,response)
		
	//Loops through dw_int, calculating gaussian weighted means for data at each point
	for(i=0,npts1=numpnts(dw_int);i<npts1;i+=1)
		dw_int[i]=0;xval=pnt2x(dw_int,i)
		xpt=binarysearch(tmp_xw,xval)
		if(xpt==-2)
			xpt=npts2-1
		elseif(xpt==-3)
			xpt=-1
		endif
		for(j=xpt,leftsum=0;j>=0 && j<npts2;j-=1)	//loop through values
			leftwt=GaussCoeffs(tmp_xw[j]-xval)
			if(leftwt<minsum)
				break
			endif
			dw_int[i]+=tmp_dw[j]*leftwt
			leftsum+=leftwt
		endfor
		if((!extrapolate) && (leftsum<minsum/1E-3))
			dw_int[i]=nan
			continue
		endif
		for(j=xpt+1,rightsum=0;j>=0 && j<npts2;j+=1)
			rightwt=GaussCoeffs(tmp_xw[j]-xval)
			if(rightwt<minsum)
				break
			endif
			dw_int[i]+=tmp_dw[j]*rightwt
			rightsum+=rightwt
		endfor
		if(((!extrapolate) && ((rightsum<minsum) || (leftsum<minsum))) || (leftsum+rightsum<minsum))	//if not enough points close enough to x position, return NaN
			dw_int[i]=nan
		else																					//if enough points, or extrapolate is requested
			dw_int[i]/=leftsum+rightsum
		endif
	endfor
	
	killdatafolder root:Packages:GaussInterpolate
end

Function LocalFitInterpolate(polyDegree,kernel,dw_int,dw[,xw,plusConf,minusConf,confInt,period,response,extrapolate,minsum,singleThread])
	variable polyDegree
	string kernel
	wave dw_int	//returns the result of the interpolation. Wave length and scaling should be set prior to calling the interpolation
	wave dw		//input data wave
	wave/Z xw		//input position waves. xw is optional to allow gaussian interpolation of waveform data
	wave/Z plusConf,minusConf
	variable period,response	//define the gaussian filter by giving desired response at a given periodicity. Values of response >=1 or <=0 will default to cutoff response of 0.1
	variable extrapolate	//non-zero to generate non-NaN values for all points in dw_int, even if they fall <min(xw) or >max(xw); default value is 0
	variable minsum		//define minimum sum of weights to produce a non-NaN value
	variable confInt
	variable singleThread
	
	dw_int=nan
	variable npts1,npts2,dx,i,j,nThreads=ThreadProcessorCount
	npts1=numpnts(dw_int)
	dx=deltax(dw_int)
	if(ParamIsDefault(minsum))
		minsum=1E-9
	endif
	if(ParamIsDefault(response) || (response>=1) || (response<=0))
		response=0.1
	endif
	if(ParamIsDefault(period))
		period=2*dx
	endif
	if(ParamIsDefault(confInt))
		confInt=95
	endif
	if(paramisdefault(plusConf) && paramisdefault(minusConf))
		confInt=0
	endif
	if(paramIsDefault(singleThread))
		singleThread=0
	endif
	nThreads=singleThread ? 1 : ThreadProcessorCount
	string dfSave=getdatafolder(1)
	string junkFolder="root:Packages:LocalLinearInterpolate:",ThreadFolder
	newdatafolderpath(junkFolder,set=1)
	make/o/d KernelCoeffs
	make/o/d tmp_dw,tmp_xw
	setdatafolder $dfSave

	if(waveexists(xw))
		duplicate/o/d dw,tmp_dw;duplicate/o/d xw,tmp_xw
	else
		duplicate/o/d dw,tmp_dw,tmp_xw;tmp_xw=x
	endif
	sort tmp_dw,tmp_dw,tmp_xw
	wavestats/q/m=1 tmp_dw;redimension/n=(v_npnts) tmp_dw,tmp_xw
	sort tmp_xw,tmp_xw,tmp_dw
	wavestats/q/m=1 tmp_xw;redimension/n=(v_npnts) tmp_dw,tmp_xw
	npts2=v_npnts
	variable ThreadN
	if(paramisdefault(plusConf))
		make/o plusConf
	else
		plusConf=nan
	endif
	if(paramisdefault(minusConf))
		make/o minusConf
	else
		minusConf=nan
	endif
	for(ThreadN=0;ThreadN<nThreads;ThreadN+=1)
		ThreadFolder=junkFolder+"Thread"+num2istr(ThreadN)+":"
		NewDataFolderPath(ThreadFolder)
		make/d/o/n=(npts2) $(ThreadFolder+"tmp_wts")
		make/o/d/n=2 $(ThreadFolder+"w_coef"),$(ThreadFolder+"w_sigma"),$(ThreadFolder+"confInterval")
	endfor
	setdatafolder $dfSave
	
		
	strSwitch(kernel)
		case "Gauss":
			GaussKernel(KernelCoeffs,npts1,dx,period,response)
			break
		case "Loess":
			LoessKernel(KernelCoeffs,npts1,dx,period,response)
			break
	endSwitch
	
	if(!singleThread)
		variable mt=ThreadGroupCreate(nThreads)
	endif
	
	for(ThreadN=0;ThreadN<nThreads;ThreadN+=1)
		ThreadFolder=junkFolder+"Thread"+num2istr(ThreadN)+":"
		SetDataFolder $ThreadFolder
		wave tmp_wts,w_coef,w_sigma,confInterval
		SetDataFolder $dfSave
		if(nThreads==1)
			LocalFitThreads(polyDegree,dw_int,tmp_dw,tmp_xw,tmp_wts,KernelCoeffs,ThreadFolder,dfSave,confInterval,0,npts1,minsum,extrapolate,confint,plusConf,minusConf,0)
		else
			ThreadStart mt,ThreadN,LocalFitThreads(polyDegree,dw_int,tmp_dw,tmp_xw,tmp_wts,KernelCoeffs,ThreadFolder,dfSave,confInterval,floor(ThreadN*npts1/nThreads),floor((ThreadN+1)*npts1/nThreads),minsum,extrapolate,confint,plusConf,minusConf,1)
		endif
		i+=1
	endfor
	
	if(!singleThread)
		do
			variable stopper=ThreadGroupWait(mt,25)
		while(stopper!=0)
		variable dummy=ThreadGroupRelease(mt)
	endif
	
	killdatafolder root:Packages:LocalLinearInterpolate
end

Threadsafe Function LocalFitThreads(polyDegree,dw_int,tmp_dw,tmp_xw,tmp_wts,KernelCoeffs,CurveFitFolder,dfSave,confInterval,i,max_i,minsum,extrapolate,confint,plusConf,minusConf,multiThread)
	variable polyDegree
	wave dw_int,tmp_dw,tmp_xw,tmp_wts,confInterval,KernelCoeffs
	string CurveFitFolder,dfSave
	variable i,max_i,minsum,extrapolate,confint
	wave plusConf,minusConf
	variable multiThread
			
	variable xval,xpt
	variable leftwt,rightwt,leftpt,rightpt,leftsum,rightsum,count
	variable conf_min,conf_max
	variable v_fitError=0,v_fitOptions=6
	for(i=i;i<max_i;i+=1)
		xval=pnt2x(dw_int,i)
		tmp_wts=KernelCoeffs(tmp_xw[p]-xval)		//this does not adjust the weights for sample resolution (i.e., duplicate measurements each receive full weight)
		wavestats/q/m=1 tmp_wts
//		tmp_wts/=(v_avg)	//wrong - but needs scaling to get conf right
		
		xpt=binarysearchinterp(tmp_xw,xval)
		if(numtype(xpt) || xpt==0)
			continue
		endif
		
		tmp_wts=1/tmp_wts
		wavestats/q/m=1/r=[0,ceil(xpt-1)] tmp_wts
		leftpt=xpt-v_npnts
		wavestats/q/m=1/r=[ceil(xpt)] tmp_wts
		rightpt=xpt+v_npnts-1
		tmp_wts=1/tmp_wts
		for(leftpt=leftpt+1,count=1;leftpt<=rightpt;leftpt+=1)
			if(tmp_wts[leftpt]!=tmp_wts[leftpt-1])
				count+=1
			endif
		endfor
		if(count<polyDegree)
			if(extrapolate)
				wavestats/q/m=1 tmp_wts
				tmp_wts*=tmp_dw
				dw_int[i]=sum(tmp_wts)/(v_sum)
				continue
			endif
			continue
		endif

		wavestats/q/m=1/r=[0,ceil(xpt-1)] tmp_wts
		leftwt=v_sum
		wavestats/q/m=1/r=[ceil(xpt)] tmp_wts
		rightwt=v_sum
		if(min(leftwt,rightwt)<minsum)
			if(!extrapolate)
				continue
			else
				tmp_wts*=tmp_dw
				dw_int[i]=sum(tmp_wts)/(leftwt+rightwt)
				continue
			endif
		endif
		
		if(!multithread)
			setdatafolder $CurveFitFolder
		endif
		make/d/o/n=2 w_coef,w_sigma
		if(confInt)
			if(polyDegree<2)
				w_coef=nan
			elseif(polyDegree==2)
				CurveFit/NTHR=0/N/ODR=0/Q line,tmp_dw /X=tmp_xw/W=tmp_wts/I=0/F={confInt/100,4}
			else
				CurveFit/NTHR=0/N/ODR=0/Q poly polyDegree,tmp_dw /X=tmp_xw/W=tmp_wts/I=0/F={confInt/100,4}
			endif
		else
			if(polyDegree<2)
				w_coef=nan
			elseif(polyDegree==2)
				CurveFit/NTHR=0/N/ODR=0/Q line,tmp_dw /X=tmp_xw/W=tmp_wts/I=0
			else
				CurveFit/NTHR=0/N/ODR=0/Q poly polyDegree,tmp_dw /X=tmp_xw/W=tmp_wts/I=0
			endif
		endif
		if(!multithread)
			setdatafolder $dfSave
		endif
		if(v_fitError)
			continue
		else
			dw_int[i]=poly(w_coef,xval)
			if(confInt)
				w_sigma*=StudentT(confInt/100,v_npnts-numpnts(w_coef))
				confInterval=w_coef[p]+w_sigma[p]
				conf_min=poly(confInterval,xval)
				conf_max=poly(confInterval,xval)
				
				confInterval=w_coef[p]-w_sigma[p]
				conf_min=min(conf_min,poly(confInterval,xval))
				conf_max=max(conf_max,poly(confInterval,xval))
				
				confInterval=w_coef[p]+sign(p-1)*w_sigma[p]
				conf_min=min(conf_min,poly(confInterval,xval))
				conf_max=max(conf_max,poly(confInterval,xval))
				
				confInterval=w_coef[p]-sign(p-1)*w_sigma[p]
				conf_min=min(conf_min,poly(confInterval,xval))
				conf_max=max(conf_max,poly(confInterval,xval))
				
				plusConf[i]=conf_max
				minusConf[i]=conf_min
			endif
		endif
	endfor
	return 1
end

Function LoessKernel(LoessCoeffs,npts,dx,period,response)
	wave LoessCoeffs
	variable npts,dx,period,response
	
	redimension/n=(npts*2+1) LoessCoeffs
	setscale/p x (-npts*dx),dx,LoessCoeffs
	LoessCoeffs[]=(1-abs(x/(period/2))^3)^3
	LoessCoeffs[0,x2pnt(LoessCoeffs,-(period/2))]=0
	LoessCoeffs[x2pnt(LoessCoeffs,period/2),]=0
end

Function GaussKernel(GaussCoeffs,npts,dx,period,response)
	wave GaussCoeffs
	variable npts,dx,period,response
	
	//Generates weights for weighted mean of points by inverse fft of the gaussian response.
	variable gwidth=(1/period)/sqrt(-ln(response))
	
	make/n=(npts)/o/d/c $(getWavesDataFolder(GaussCoeffs,1)+":GaussResponse")
	wave/c GaussResponse=$(getWavesDataFolder(GaussCoeffs,1)+":GaussResponse")
	setscale/p x 0,1/(npts*dx),GaussResponse
	GaussResponse=exp(-(x/gwidth)^2)
	ifft/Z/R/DEST=$(getWavesDataFolder(GaussCoeffs,2)) GaussResponse
	rotate (npts),GaussCoeffs
	GaussCoeffs[0]=0
	GaussCoeffs[numpnts(GaussCoeffs)-1]=0
end

Function INTERPOLATION_Median(IPs)
	struct InterpolationParameters &IPs

	if(IPs.getParams)		
		IPs.SV.name[0]="Window Size:"
		if(IPs.interpRes>0)
			IPs.SV.value[0]=2*IPs.interpRes
		else
			IPs.SV.value[0]=1
		endif
		IPs.SV.low[0]=0;IPs.SV.high[0]=inf;IPs.SV.inc[0]=IPs.SV.value[0]
		
		IPs.SV.name[1]="";IPs.SV.value[1]=nan;IPs.SV.low[1]=nan;IPs.SV.high[1]=nan;IPs.SV.inc[1]=nan
		IPs.SV.name[2]="";IPs.SV.value[2]=nan;IPs.SV.low[2]=nan;IPs.SV.high[2]=nan;IPs.SV.inc[2]=nan
		IPs.PM.name[0]="";IPs.PM.value[0]="";IPs.PM.popStr[0]="";IPs.PM.popNum[0]=nan
		IPs.PM.name[1]="";IPs.PM.value[1]="";IPs.PM.popStr[1]="";IPs.PM.popNum[1]=nan
		IPs.PM.name[2]="";IPs.PM.value[2]="";IPs.PM.popStr[2]="";IPs.PM.popNum[2]=nan
	else
		MedianInterpolate(IPs.dw_int,IPs.dw,xw=IPs.xw,range=IPs.SV.value[0])
	endif	
end

Function MedianInterpolate(dw_int,dw[,xw,range,extrapolate,minvals,preMedian])
	wave dw,dw_int
	wave/Z xw
	variable range,extrapolate,minvals,preMedian
//Fills dw_int with the median of values of dw corresponding to the x scaling of dw_int.
//If xw is a valid wave reference, then it uses values from xw as x values for dw, 
//otherwise it uses the x scaling of dw.
		
	string dfSave=getdatafolder(1)
	NewDataFolder/o/s root:Packages
	NewDataFolder/o/s root:Packages:MedianInterpolate
	make/o/d vals,tmp_dw,tmp_xw
	setdatafolder $dfSave
	
	variable npts1,npts2,dx,i,j,k,minx,maxx
	dx=deltax(dw_int)
	if(paramisdefault(range))
		range=dx
	endif
	if(preMedian)
		range/=10
	endif
	if(waveexists(xw))
		duplicate/o/d dw,tmp_dw;duplicate/o/d xw,tmp_xw
	else
		duplicate/o/d dw,tmp_dw,tmp_xw;tmp_xw=x
	endif
	RemoveNaNs(tmp_dw,w2=tmp_xw)
	sort tmp_xw,tmp_xw,tmp_dw
	npts2=numpnts(tmp_dw)
	
	if(extrapolate)
		i=0;npts1=numpnts(dw_int)
	else
		i=x2pnt(dw_int,tmp_xw[0]+range/2);npts1=x2pnt(dw_int,tmp_xw[npts2-1]-range/2)
		dw_int[0,i-1]=nan;dw_int[npts1,]=nan
	endif
	minx=pnt2x(dw_int,i)-range/2;maxx=minx+range
	
	for(i=i,j=0,k=-1;i<npts1;i+=1,minx+=dx,maxx+=dx)
		for(j=j;j<npts2;j+=1)
			if(tmp_xw[j]>=minx)
				break
			endif
		endfor
		for(k=k+1;k<npts2;k+=1)
			if(tmp_xw[k]>maxx)
				break
			endif
		endfor
		k-=1
		dw_int[i]=MedianVal(tmp_dw,pt1=j,pt2=k,order=1,minn=(minvals && !preMedian))
	endfor
	
	killdatafolder root:Packages:MedianInterpolate
	if(preMedian)
		MedianInterpolate(dw_int,dw_int,range=range*10,extrapolate=extrapolate,minvals=minvals)
	endif
end

Function INTERPOLATION_Mean(IPs)
	struct InterpolationParameters &IPs

	if(IPs.getParams)		
		IPs.SV.name[0]="Window Size:"
		if(IPs.interpRes>0)
			IPs.SV.value[0]=2*IPs.interpRes
		else
			IPs.SV.value[0]=1
		endif
		IPs.SV.low[0]=0;IPs.SV.high[0]=inf;IPs.SV.inc[0]=IPs.SV.value[0]
		
		IPs.SV.name[1]="";IPs.SV.value[1]=nan;IPs.SV.low[1]=nan;IPs.SV.high[1]=nan;IPs.SV.inc[1]=nan
		IPs.SV.name[2]="";IPs.SV.value[2]=nan;IPs.SV.low[2]=nan;IPs.SV.high[2]=nan;IPs.SV.inc[2]=nan
		IPs.PM.name[0]="";IPs.PM.value[0]="";IPs.PM.popStr[0]="";IPs.PM.popNum[0]=nan
		IPs.PM.name[1]="";IPs.PM.value[1]="";IPs.PM.popStr[1]="";IPs.PM.popNum[1]=nan
		IPs.PM.name[2]="";IPs.PM.value[2]="";IPs.PM.popStr[2]="";IPs.PM.popNum[2]=nan
	else
		MeanInterpolate(IPs.dw_int,IPs.dw,xw=IPs.xw,range=IPs.SV.value[0])
	endif	
end

Function MeanInterpolate(dw_int,dw[,xw,range,extrapolate,minvals])
	wave dw,dw_int
	wave/Z xw
	variable range,extrapolate,minvals
//Fills dw_int with the mean of values of dw corresponding to the x scaling of dw_int.
//If xw is a valid wave reference, then it uses values from xw as x values for dw, 
//otherwise it uses the x scaling of dw.
		
	string dfSave=getdatafolder(1)
	NewDataFolder/o/s root:Packages
	NewDataFolder/o/s root:Packages:MeanInterpolate
	make/o/d vals,tmp_dw,tmp_xw
	setdatafolder $dfSave

	variable npts1,npts2,dx,i,j,k,minx,maxx
	dx=deltax(dw_int)
	if(paramisdefault(range))
		range=dx
	endif
	if(waveexists(xw))
		duplicate/o/d dw,tmp_dw;duplicate/o/d xw,tmp_xw
	else
		duplicate/o/d dw,tmp_dw,tmp_xw;tmp_xw=x
	endif
	RemoveNaNs(tmp_dw,w2=tmp_xw)
	sort tmp_xw,tmp_xw,tmp_dw
	npts2=numpnts(tmp_dw)
	
	if(extrapolate)
		i=0;npts1=numpnts(dw_int)
	else
		i=x2pnt(dw_int,tmp_xw[0]+range/2);npts1=x2pnt(dw_int,tmp_xw[npts2-1]-range/2)
		dw_int[0,i-1]=nan;dw_int[npts1,]=nan
	endif
	minx=pnt2x(dw_int,i)-range/2;maxx=minx+range
	
	for(i=i,j=0,k=-1;i<npts1;i+=1,minx+=dx,maxx+=dx)
		for(j=j;j<npts2;j+=1)
			if(tmp_xw[j]>=minx)
				break
			endif
		endfor
		for(k=k+1;k<npts2;k+=1)
			if(tmp_xw[k]>maxx)
				break
			endif
		endfor
		k-=1
		dw_int[i]=MeanVal(tmp_dw,pt1=j,pt2=k,order=1,minn=minvals)
	endfor
	
	killdatafolder root:Packages:MeanInterpolate
end

static Function RemoveNaNs(w1[,w2])
	//Removes points that are NaN in EITHER w1 or w2 from both w1 and w2.
	//CAUTION - does not preserve original order of data.
	wave w1,w2
	
	if(paramisdefault(w2))
		sort w1,w1
		wavestats/q/m=1 w1
		redimension/n=(v_npnts) w1
	else
		sort w2,w1,w2
		wavestats/q/m=1 w2
		redimension/n=(v_npnts) w2,w1
		sort w1,w1,w2
		wavestats/q/m=1 w1
		redimension/n=(v_npnts) w1,w2
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

static Function MedianVal(dw[,pt1,pt2,minn,order])
	wave dw;variable pt1,pt2,minn,order
	
	NewDataFolder/o root:Packages
	NewDataFolder/o root:Packages:MedianVal
	make/d/o root:Packages:MedianVal:vals
	wave vals=root:Packages:MedianVal:vals
	
	variable med,i
	if(paramisdefault(pt1) || (pt1<0))
		pt1=0
	endif
	if(paramisdefault(pt2) || (pt2>numpnts(dw)))
		pt2=numpnts(dw)
	endif
	if(numtype(pt1) || numtype(pt2) || (pt1<0) || (pt2<0))
		med=nan
	elseif(order && (pt1>pt2))
		med=nan
	else
		duplicate/o/r=[pt1,pt2]/d dw,vals
		sort vals,vals
		wavestats/q/m=1 vals
		if(v_npnts==0 || v_npnts<minn)
			med=nan
		else
			med=vals[(v_npnts-1)/2]
		endif
	endif
	killdatafolder root:Packages:MedianVal
	return med
end

static Function MeanVal(dw[,pt1,pt2,minn,order])
	wave dw;variable pt1,pt2,minn,order
	
	NewDataFolder/o root:Packages
	NewDataFolder/o root:Packages:MeanVal
	make/d/o root:Packages:MeanVal:vals
	wave vals=root:Packages:MeanVal:vals
	
	variable meen,i,npts=numpnts(dw)
	if(paramisdefault(pt1) || pt1<0)
		pt1=0
	endif
	if(paramisdefault(pt2) || pt2>npts)
		pt2=npts
	endif
	if(numtype(pt1) || numtype(pt2))
		meen=nan
	elseif(order && (pt1>pt2))
		meen=nan
	else
		duplicate/o/r=[pt1,pt2]/d dw,vals
		sort vals,vals
		wavestats/q/m=1 vals
		if(v_npnts==0 || v_npnts<minn)
			meen=nan
		else
			meen=v_avg
		endif
	endif
	killdatafolder root:Packages:MeanVal
	return meen
end