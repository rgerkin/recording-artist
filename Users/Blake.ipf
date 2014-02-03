#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <Global Fit 2>

function ContourPlot(holdX,holdY,enzyme[,low,high,lowX,lowY,highX,highY,num,log10,upsample,purpleChi2,reset_fits])
	variable holdX // Index of first parameter to be held (x-axis)
	variable holdY // Index of second parameter to be held (y-axis).  
	variable enzyme // Index of the enzyme parameter (always held). 
	variable low // Smallest parameter value relative to optimum.  If optimum is 7 and you want to plot down to 5, this shoudl be -2.  
	variable high // Largest parameter value relative to optimum.  
	variable num // Number of fits per dimension.  
	variable log10 // Whether to plot on a logarithmic scale.  
	variable upsample // Upsample the final contour plot by the indicated factor.  Only applies if 'num' is >= 21.  
	variable purpleChi2 // The relative value of chi-squared (as a multiple of the best chi-squared) at which the plot becomes fully purple.  
	variable reset_fits // Reset fit coefficients to the overall best fit before doing each new fit.  
	
	// Independent control for x-axis and y-axis sizing.  
	variable lowX // Smallest parameter value for x-axis relative to optimum.  If optimum is 7 and you want to plot down to 5, this should be -2.  
	variable highX // Largest parameter value for x-axis relative to optimum.  
	variable lowY // Smallest parameter value relative to optimum.  If optimum is 7 and you want to plot down to 5, this shoudl be -2.  
	variable highY // Largest parameter value relative to optimum.  
	
	num = paramisdefault(num) ? 25 : num // Default number of fits per dimension.   
	purpleChi2 = paramisdefault(purpleChi2) ? 10 : purpleChi2
	
	// Perform the initial, unconstrained fit.  
	cd root:Packages:NewGlobalFit
	wave NewGF_CoefWave
	NewGF_CoefWave[][1] = 0 // Don't hold any coefficients.  
	NewGF_CoefWave[enzyme][1] = 1 // Hold enzyme concentration.
	variable guessX = NewGF_CoefWave[holdX][0] // Initial guess for X.  
	variable guessY = NewGF_CoefWave[holdY][0] // Initial guess for Y.  
	if(log10 & 1)
		guessX = log(guessX)
	endif
	if(log10 & 2)
		guessY = log(guessY)
	endif
	variable best_chisq = Fit(guessX,guessY,NewGF_CoefWave,holdX,holdY,1,log10=log10) // Chi-squared for the best fit (nothing held except enzyme concentration).  
	duplicate /o NewGF_CoefWave,bestCoefs  
	variable bestX = bestCoefs[holdX][0] // Best fit for X.  
	variable bestY = bestCoefs[holdY][0] // Best fit for Y.  
	if(log10 & 1)
		bestX = log(bestX)
		lowX = paramisdefault(lowX) ? (paramisdefault(low) ? -0.5 : low) : lowX 
		highX = paramisdefault(highX) ? (paramisdefault(high) ? +0.5 : low) : highX
	else
		lowX = paramisdefault(lowX) ? (paramisdefault(low) ? -bestX/2 : low) : lowX 
		highX = paramisdefault(highX) ?  (paramisdefault(high) ? bestX/2 : high) : highX
	endif
	if(log10 & 2)
		bestY = log(bestY)
		lowY = paramisdefault(lowY) ? (paramisdefault(low) ? -0.5 : low) : lowY
		highY = paramisdefault(highY) ? (paramisdefault(high) ? +0.5 : high) : highY
	else
		lowY = paramisdefault(lowY) ? (paramisdefault(low) ? -bestY/2 : low) : lowY
		highY = paramisdefault(highY) ? (paramisdefault(high) ? bestY/2 : high) : highY
	endif
	
	// Create the contour template.  
	if(!(log10 & 1) && bestX + lowX < 0) // If X parameter would be set below zero for subsequent fits.  
		lowX = -0.75*bestX // Make sure it gets set no lower than 0.25 * bestX.  
	endif
	if(!(log10 & 2) && bestY + lowY < 0) // If Y parameter would be set below zero for subsequent fits.  
		lowY = -0.75*bestY // Make sure it gets set no lower than 0.25 * bestY.  
	endif
	cd root:
	make /o/n=(num,num) contour
	setscale /I x,bestX+lowX,bestX+highX,contour
	setscale /I y,bestY+lowY,bestY+highY,contour
	if(log10 & 1)
		MakeTicksAndLabels("x",bestX,lowX,highX)
		wave x_ticks
		wave /t x_tick_labels
	endif
	if(log10 & 2)
		MakeTicksAndLabels("y",bestY,lowY,highY)
		wave y_ticks
		wave /t y_tick_labels
	endif
	
	// Do the fits.  
	cd root:Packages:NewGlobalFit
	bestCoefs[holdX][1] = 1 // Hold coefficient on X-axis.  
	bestCoefs[holdY][1] = 1 // Hold coefficient on Y-axis.  
	contour = Fit(x,y,bestCoefs,holdX,holdY,best_chisq,log10=log10,reset_fits=reset_fits) // Fill the contour matrix with data.  
	
	// Display the fits.  
	string win
	sprintf win,"ContourPlot_%d_%d",holdX,holdY
	dowindow /k $win
	display /n=$win
	appendimage contour
	if(log10 & 1)
		//modifyGraph axThick(bottom)=0,nticks(bottom)=0
		//newfreeaxis /b log_bottom
		//modifygraph log(log_bottom)=1
		//setaxis log_bottom,10^dimoffset(contour,0),10^(dimoffset(contour,0)+dimdelta(contour,0)*num)
		//ModifyGraph freePos(log_bottom)={0,kwFraction}
		ModifyGraph userticks(bottom)={x_ticks,x_tick_labels}
	endif
	if(log10 & 2)
		//modifyGraph axThick(left)=0,nticks(left)=0
		//newfreeaxis /l log_left
		//modifygraph log(log_left)=1
		//setaxis log_left,10^dimoffset(contour,1),10^(dimoffset(contour,1)+dimdelta(contour,1)*num)
		//ModifyGraph freePos(log_left)={0,kwFraction}
		ModifyGraph userticks(left)={y_ticks,y_tick_labels}
	endif
	ModifyImage contour ctab= {1,purpleChi2,Rainbow,0}
	if(upsample && num >= 21)
		Resample /dim=0 /up=(upsample) contour
		Resample /dim=1 /up=(upsample) contour
	endif
	string parameter_names = FitFunctionParameterNames()
	string x_name = stringfromlist(holdX,parameter_names)
	string y_name = stringfromlist(holdY,parameter_names)
	label bottom x_name
	label left y_name
	cd root:
	printf "Best fit found for %s=%.4g and %s=%.4g\r",x_name,log10 & 1 ? 10^bestX : bestX,y_name,log10 & 2 ? 10^bestY : bestY
end

// Fit with one pair of parameters held and return a relative chi-squared value.  
static function Fit(xx,yy,coefs,hold1,hold2,best_chisq[,log10,reset_fits])
	variable xx // Value (or log10 of value) of first parameter to be held.  
	variable yy // Value (or log10 of value) of second parameter to be held.  
	variable hold1 // Index of first parameter to be held.  
	variable hold2 // Index of second parameter to be held.  
	variable best_chisq // Value of best chi-squared value, to which result will be normalized.  
	variable log10 // Whether or not we are using logarithmic spacing.  
	variable reset_fits // Reset fit coefficients to the overall best fit first.  
	wave coefs // Current values of the fit coefficients.  
	
	variable maxIters = 1000 // Maximum number of iterations per fit.  
	variable fitLength = 200 // Number of points per fitted wave.  
	variable fitOptions = 16 // 16 = Silent fit with no delays.  
	wave /t NewGF_FitFuncNames, NewGF_DataSetsList, NewGF_CoefficientNames
	wave NewGF_LinkageMatrix
	coefs[hold1][0] = log10 & 1 ? 10^xx : xx
	coefs[hold2][0] = log10 & 2 ? 10^yy : yy
	if(reset_fits)
		duplicate /free coefs,coefs_
	else
		wave coefs_ = coefs
	endif
	DoNewGlobalFit(NewGF_FitFuncNames, NewGF_DataSetsList, NewGF_LinkageMatrix, coefs_, NewGF_CoefficientNames, $"", fitOptions, fitLength, 1, maxIters=maxIters, resultWavePrefix="", resultDF="")
	wave FitY,YCumData
	make /free/n=(numpnts(YCumData)) w_chisq = YCumData[p]>0 ? (YCumData[p]-FitY[p])^2 / FitY[p] : 0 // Compute the chi-squared components.  
	variable chisq = sum(w_chisq) // Sum to obtain chi-squared.  
	variable result = chisq/best_chisq // Normalize to the best chi-squared value.  
	return chisq/best_chisq // Return the result.  
end

static function /s FitFunctionParameterNames()
	wave /t funcNames = root:Packages:NewGlobalFit:NewGF_FitFuncNames
	string text = ProcedureText(funcNames[0])
	variable i
	string index,name, names = ""
	for(i=0;i<itemsinlist(text,"\r");i+=1)
		string line = stringfromlist(i,text,"\r")
		SplitString /E="CurveFitDialog/ w\[([0-9])\] = (\w+)" line, index, name
		if(strlen(index) && strlen(name))
			names += name+";"
		endif
	endfor
	return names
end

static function MakeTicksAndLabels(var,best,low,high)
	string var // 'x' or 'y'
	variable best,low,high
	
	make /o/n=0 $(var+"_ticks") /wave=tiks
	
	variable i,tick,pass=0,lo=10^floor(best+low),hi=10^ceil(best+high)
	do
		for(i=1;i<10;i+=1)
			tick = i*lo*10^pass
			tiks[numpnts(tiks)] = {log(tick)}
		endfor
		pass+=1
	while(tick<hi)
	make /o/t/n=(numpnts(tiks)) $(var+"_tick_labels") /wave=labels = selectstring(tiks[p]==round(tiks[p]),"",num2str(10^tiks[p]))
end