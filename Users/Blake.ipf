#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <Global Fit 2>

static constant e_NADH = 6220 // Extinction coefficient for NADH in (M*cm)^-1
static constant path_length = 0.401 // Path length for the experiment in cm.  

function ContourPlot(holdX,holdY,enzyme[,low,high,lowX,lowY,highX,highY,num,log10,upsample,purpleChi2,reset_fits,epsilon,passes,quiet])
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
	variable epsilon // Step size relative to parameter values.  
	variable passes // Maximum number of times to try each fit.
	variable quiet // Don't print messages after every failed fit.  
	
	// Independent control for x-axis and y-axis sizing.  
	variable lowX // Smallest parameter value for x-axis relative to optimum.  If optimum is 7 and you want to plot down to 5, this should be -2.  
	variable highX // Largest parameter value for x-axis relative to optimum.  
	variable lowY // Smallest parameter value relative to optimum.  If optimum is 7 and you want to plot down to 5, this shoudl be -2.  
	variable highY // Largest parameter value relative to optimum.  
	
	num = paramisdefault(num) ? 25 : num // Default number of fits per dimension.   
	purpleChi2 = paramisdefault(purpleChi2) ? 10 : purpleChi2
	epsilon = paramisdefault(epsilon) ? 1e-4 : epsilon
	passes = paramisdefault(passes) ? 10 : passes
	
	// Perform the initial, unconstrained fit.  
	cd root:Packages:NewGlobalFit
	wave NewGF_CoefWave
	//NewGF_CoefWave[][1] = 0 // Don't hold any coefficients.  
	NewGF_CoefWave[enzyme][1] = 1 // Hold enzyme concentration.
	variable guessX = NewGF_CoefWave[holdX][0] // Initial guess for X.  
	variable guessY = NewGF_CoefWave[holdY][0] // Initial guess for Y.  
	if(log10 & 1)
		guessX = log(guessX)
	endif
	if(log10 & 2)
		guessY = log(guessY)
	endif
	ControlInfo/W=NewGlobalFitPanel#NewGF_GlobalControlArea NewGF_ConstraintsCheckBox
	variable constrain = v_value
	variable best_chisq = Fit(guessX,guessY,NewGF_CoefWave,holdX,holdY,1,log10=log10,constrain=constrain,quiet=quiet) // Chi-squared for the best fit (nothing held except enzyme concentration).  
	duplicate /o NewGF_CoefWave,bestCoefs  
	variable bestX = bestCoefs[holdX][0] // Best fit for X.  
	variable bestY = bestCoefs[holdY][0] // Best fit for Y.  
	bestCoefs[][2] = bestCoefs[p][0]*epsilon // Set epsilon values to 1e-4 of the best fit parameter estimates.  
	if(constrain) // If there are constraints on the fit.  
		wave/t/z ConstraintWave = $"GFUI_GlobalFitConstraintWave"
		variable i
		do // Remove them for parameters that are being held.  
			variable held = stringmatch(ConstraintWave[i],"K"+num2str(holdX)+" *")
			held = held || stringmatch(ConstraintWave[i],"K"+num2str(holdY)+" *")
			held = held || stringmatch(ConstraintWave[i],"K"+num2str(enzyme)+" *")
			if(held)
				deletepoints i,1,ConstraintWave
			else
				i+=1
			endif
		while(i<dimsize(ConstraintWave,0))
	endif
	duplicate /free/r=[][1,1] bestCoefs,parameters_held
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
	variable pass = 1
	do
		contour = numtype(contour[p][q])==2 || pass==1 ? Fit(x,y,bestCoefs,holdX,holdY,best_chisq,log10=log10,reset_fits=reset_fits,constrain=constrain,quiet=quiet) : contour[p][q] // Fill the contour matrix with data.  
		wavestats /q contour
		if(v_numnans && pass<passes)
			printf "%d out of %d fits were unsuccessful.  Retrying these.\r",v_numnans,numpnts(contour)
			variable new_epsilon = epsilon * 1.5^pass
			if(new_epsilon < 1e-1)
				printf "Increasing epislon to %g.\r", new_epsilon
				bestCoefs[][2] = bestCoefs[p][0] * new_epsilon
			else
				printf "Perturbing initial parameters.\r"
				bestCoefs[p][0] = bestCoefs[p][1] ? 1 : (1+abs(enoise(0.1))) 
			endif
		else
			printf "%d out of %d fits were unsuccessful.\r",v_numnans,numpnts(contour)
			break
		endif
		pass += 1
	while(1)
	
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
	variable errorCode = GetRTError(1)	
end

// Fit with one pair of parameters held and return a relative chi-squared value.  
static function Fit(xx,yy,coefs,hold1,hold2,best_chisq[,log10,reset_fits,constrain,quiet])
	variable xx // Value (or log10 of value) of first parameter to be held.  
	variable yy // Value (or log10 of value) of second parameter to be held.  
	variable hold1 // Index of first parameter to be held.  
	variable hold2 // Index of second parameter to be held.  
	variable best_chisq // Value of best chi-squared value, to which result will be normalized.  
	variable log10 // Whether or not we are using logarithmic spacing.  
	variable reset_fits // Reset fit coefficients to the overall best fit first.  
	variable constrain // Use the constraint wave.  
	wave coefs // Current values of the fit coefficients.  
	variable quiet // Don't print an error message after a failed fit.  
	
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
	if(constrain)
		wave/t/z ConstraintWave = $"GFUI_GlobalFitConstraintWave"
	else
		wave /t/z ConstraintWave = $""
	endif
	try
		variable err = DoNewGlobalFit(NewGF_FitFuncNames, NewGF_DataSetsList, NewGF_LinkageMatrix, coefs_, NewGF_CoefficientNames, ConstraintWave, fitOptions, fitLength, 1, maxIters=maxIters, resultWavePrefix="", resultDF="")
	catch
		string fitErrorMessage = GetRTErrMessage()
		variable errorCode = GetRTError(1)	
	endtry
	nvar v_fitquitreason
	if(err && !quiet)
		printf "Fit error %d at x=%.4g,y=%.4g\r",err,coefs[hold1][0],coefs[hold2][0]
	endif
	if(v_fitquitreason && !quiet)
		printf "Fit quit due to reason %d at x=%.4g,y=%.4g\r",v_fitquitreason,coefs[hold1][0],coefs[hold2][0]
	endif
	wave FitY,YCumData
	make /free/n=(numpnts(YCumData)) w_chisq = YCumData[p]>0 ? (YCumData[p]-FitY[p])^2 / FitY[p] : 0 // Compute the chi-squared components.  
	variable chisq = sum(w_chisq) // Sum to obtain chi-squared.  
	if(chisq<0 && !quiet)
		printf "Negative value of chi-squared obtained at x=%.4g,y=%.4g\r",coefs[hold1][0],coefs[hold2][0]
	endif	
	variable result = chisq/best_chisq // Normalize to the best chi-squared value.  
	if(err || v_fitquitreason || chisq<0)
		result = nan
	endif
	return result // Return the result.  
end

function JackknifeEstimates(enzyme[,epsilon,passes,quiet,mode,number,holdout])
	variable enzyme // Index of the enzyme parameter (always held). 
	variable epsilon // Step size relative to parameter values.  
	variable passes // Maximum number of times to try each fit.
	variable quiet // Don't print messages after every failed fit.  
	variable mode // Mode for determining which data to holdout for each jackknife sample.  
	variable number // Number of jackknife estimates to use.     
	variable holdout // Number to holdout in each estimate, given the mode.  
	
	epsilon = paramisdefault(epsilon) ? 1e-4 : epsilon
	passes = paramisdefault(passes) ? 10 : passes
	holdout = paramisdefault(holdout) ? 1 : holdout
	
	// Perform the initial, unconstrained fit.  
	cd root:Packages:NewGlobalFit
	wave NewGF_CoefWave
	wave /t NewGF_DataSetsList
	NewGF_CoefWave[enzyme][1] = 1 // Hold enzyme concentration.
	variable guessX = NewGF_CoefWave[0][0] // Initial guess for X.  
	variable guessY = NewGF_CoefWave[1][0] // Initial guess for Y.  
	ControlInfo/W=NewGlobalFitPanel#NewGF_GlobalControlArea NewGF_ConstraintsCheckBox
	variable constrain = v_value
	variable mask_col = finddimlabel(NewGF_DataSetsList,1,"Masks")
	if(mask_col<0)
		variable no_old_masks = 1
		redimension /n=(-1,dimsize(NewGF_DataSetsList,1)+1) NewGF_DataSetsList
		mask_col = dimsize(NewGF_DataSetsList,1)-1
		setdimlabel 1,mask_col,Masks,NewGF_DataSetsList
	else
		duplicate /free/t/r=[][mask_col,mask_col] NewGF_DataSetsList, old_masks
	endif
	variable i,j,n
	for(i=0;i<dimsize(NewGF_DataSetsList,0);i+=1)
		string mask_name = "mask_"+num2str(i)
		wave data = $NewGF_DataSetsList[i][0]
		make /o/n=(numpnts(data)) root:$mask_name = 1
		NewGF_DataSetsList[i][mask_col] = "root:"+mask_name
	endfor
	make /o/n=(dimsize(NewGF_CoefWave,0),0) root:jackknife_estimates /wave=estimates
	
	variable num_data = 0, num_data_y=0
	for(i=0;i<dimsize(NewGF_DataSetsList,0);i+=1)
		wave mask = $NewGF_DataSetsList[i][mask_col]
		variable num_data_x = numpnts(mask)
		num_data_y += 1
		num_data += numpnts(mask)
	endfor		
	if(holdout > 0.5*num_data)
		printf "You tried to hold out %d, which is more than half of the data %d.\r",holdout,num_data
		return -1
	endif
	
	switch(mode)
		case 0: // Holdout random data.  
			number = paramisdefault(number) ? 50 : number
			break
		case 1: // Holdout ordered data.  
			number = paramisdefault(number) ? num_data : number
			break
		case 2: // Holdout whole X-values.    
			number = paramisdefault(number) ? num_data_x : number
			break
		case 3: // Holdout whole Y-values.  
			wave mask = $NewGF_DataSetsList[0][mask_col]			
			number = paramisdefault(number) ? num_data_y : number
			break
		case 4 : // Holdout X-values and then Y-values.  
			wave mask = $NewGF_DataSetsList[0][mask_col]		
			number = paramisdefault(number) ? num_data_x+num_data_y : number	
			break
	endswitch
	
	redimension /n=(-1,number) estimates
	wave /t list = NewGF_DataSetsList
	for(n=0;n<number;n+=1)
		switch(mode)
			case 0: // Holdout random data.  
				make /free/n=(num_data) super_mask,index=p,randos = gnoise(1)
				sort randos,index
				super_mask = index[p] < holdout ? 0 : 1
				variable counter = 0
				for(i=0;i<dimsize(list,0);i+=1)
					wave mask = $list[i][mask_col]			
					mask = super_mask[p+counter]
					counter += numpnts(mask)
				endfor	
				break
			case 1: // Holdout ordered data.  
				make /free/n=(num_data) super_mask = mod(n,num_data)-p < holdout && mod(n,num_data)-p >= 0 ? 0 : 1
				counter = 0
				for(i=0;i<dimsize(list,0);i+=1)
					wave mask = $list[i][mask_col]			
					mask = super_mask[p+counter]
					counter += numpnts(mask)
				endfor	
				break
			case 2: // Holdout whole X-values.    
				for(i=0;i<dimsize(list,0);i+=1)
					wave mask = $list[i][mask_col]			
					mask = mod(n,num_data_x)-p < holdout && mod(n,num_data_x)-p >= 0 ? 0 : 1
					print n,i,mask
				endfor	
				break
			case 3: // Holdout whole Y-values.  DOESN"T WORK.  
				for(i=0;i<dimsize(list,0);i+=1)
					wave mask = $list[i][mask_col]			
					mask = mod(n,num_data_y)-i < holdout && mod(n,num_data_y)-i >= 0 ? 0 : 1
					print n,i,mask
				endfor	
				break
			case 4 : // Holdout X-values and then Y-values.  Holdout always equals 1.  DOESN'T WORK.  
				for(i=0;i<dimsize(list,0);i+=1)
					wave mask = $list[i][mask_col]			
					if(mod(n,num_data_x+num_data_y)<num_data_x)
						mask = i==n ? 0 : 1
					else
						mask = p==n ? 0 : 1
					endif
				endfor
				break
			default:
				printf "%d not a jacknife mode.\r",mode
				return -2
				break
		endswitch
		variable best_chisq = Fit(guessX,guessY,NewGF_CoefWave,0,1,1,constrain=constrain,quiet=quiet) // Chi-squared for the best fit (nothing held except enzyme concentration).  )		
		estimates[][n] = NewGF_CoefWave[p][0]
		matrixop /o root:jackknife_mean = meancols(estimates^t)
		matrixop /o root:jackknife_std = sqrt(varcols(estimates^t))^t
	endfor	

	// Restore masking.  
	if(no_old_masks)
		for(i=0;i<dimsize(NewGF_DataSetsList,0);i+=1)
			wave mask = $NewGF_DataSetsList[i][mask_col]			
			mask = 1
		endfor			
		deletepoints /m=1 mask_col,1,NewGF_DataSetsList	
	else
		// TODO: Restore mask values if there were old masks being used.  
		NewGF_DataSetsList[][mask_col] = old_masks
	endif
	setdatafolder root:
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

function LoadDataFile()
	variable refNum
	open /m="Choose a data file"/r refNum
	if(!strlen(s_filename))
		return -1
	endif
	setdatafolder root:
	make /free/t/n=0 file_well_indices
	variable i,read = 0,block=0
	string line
	do
		FReadLine refNum, line
		if(read)
			if(itemsinlist(line,"\t")>1)
				if(stringmatch(line,"0:00*"))
					block+=1
					variable sample = 0
					newdatafolder /o/s root:$("Block"+num2str(block))
					make /o/n=0 times,temps
					make /o/n=(0,numpnts(file_well_indices)) values
					for(i=0;i<numpnts(file_well_indices);i+=1)
						setdimlabel 1,i,$file_well_indices[i],values
					endfor
				endif
				variable minutes,seconds
				sscanf stringfromlist(0,line,"\t"), "%d:%d", minutes, seconds
				times[sample] = {minutes*60+seconds}
				temps[sample] = {str2num(stringfromlist(1,line,"\t"))}
				for(i=0;i<numpnts(file_well_indices);i+=1)
					values[sample][i] = {str2num(stringfromlist(i+2,line,"\t"))}
				endfor
				sample += 1
			endif
		else
			if(stringmatch(line,"Time(hh:mm:ss)*"))
				redimension /n=(itemsinlist(line,"\t ")-2) file_well_indices 
				for(i=2;i<itemsinlist(line,"\t");i+=1)
					string item=stringfromlist(i,line,"\t")
					file_well_indices[i-2] = item
				endfor			
				read = 1
			endif
		endif
	while(strlen(line))
	close refNum
	variable blocks = block
	for(block=1;block<=blocks;block+=1)
		setdatafolder root:$("Block"+num2str(block))
		wave values
		i=0
		duplicate /o file_well_indices $"well_indices"
		wave well_indices
		do
			if(numtype(values[0][i])==2)
				deletepoints /m=1 i,1,values
				deletepoints /m=0 i,1,well_indices
			else
				i+=1
			endif
		while(i<dimsize(values,1))
	endfor
	setdatafolder root:
end

function FindLinearRegions([duration,min_r2,only_block])
	variable duration,min_r2,only_block
	
	duration = paramisdefault(duration) ? 60*7.5 : duration
	min_r2 = paramisdefault(min_r2) ? 0.97 :min_r2
	
	setdatafolder root:
	variable block = 1
	do
		if(!paramisdefault(only_block))
			if(block<only_block)
				block+=1
				continue
			elseif(block>only_block)
				break
			endif
		endif
		dfref blockDF = root:$("Block"+num2str(block))
		if(datafolderrefstatus(blockDF))
			cd blockDF
			printf "Block %d:\r",block
			wave times,values
			wave /t well_indices
			variable start = 0, finish = 0
			do
				finish += 1
			while(times[finish]-times[start]<duration)
			variable samples = finish - start
			make /o/n=(dimsize(values,1)) starts = nan, finishes = nan
			variable i
			for(i=0;i<dimsize(values,1);i+=1)
				start = 0
				finish = start + samples
				do
					duplicate /free/r=[start,finish] times, times_
					duplicate /free/r=[start,finish][i,i] values values_
					variable r2 = statscorrelation(times_,values_)^2
					//print i,start,finish,r2
					if(r2 >= min_r2)
						printf "\tWell %s exhibited r^2 = %.3f from t=%d seconds to t=%d seconds.\r",well_indices[i],r2,times[start],times[finish]
						starts[i] = times[start]
						finishes[i] = times[finish]
						break
					endif
					start += 1
					finish += 1
					if(finish >= dimsize(values,0))
						printf "\tWell %s never exhibited a region of length %d seconds with r^2 >= %.3f.\r",well_indices[i],duration,min_r2
						break
					endif
				while(1)
			endfor
		else
			break
		endif
		block += 1
	while(1)
	setdatafolder root:
end

function InitialHydrolysisRate(block,well)
	variable block
	string well
	
	dfref blockDF = root:$("Block"+num2str(block))
	if(!datafolderrefstatus(blockDF))
		printf "No data for block %d.\r",block
		return nan
	endif
	wave /z/sdfr=blockDF values,starts,finishes,times
	wave /z/t/sdfr=blockDF well_indices
	findvalue /text=well/txop=4 well_indices
	variable column = v_value
	variable startT = starts[column]
	variable finishT = finishes[column]
	findvalue /v=(startT) times
	variable start = v_value // Start index.  
	findvalue /v=(finishT) times
	variable finish = v_value // Start index.  
	duplicate /free/r=[][column,column] values, well_values
	curvefit /Q line, well_values[start,finish] /X=times
	variable slope = K1 // Slope in M/min^-1
	variable result = - slope / (e_NADH*path_length)
	return result
end

function InitialHydrolysisRates(block)
	variable block
	
	dfref blockDF = root:$("Block"+num2str(block))
	if(!datafolderrefstatus(blockDF))
		printf "No data for block %d.\r",block
		return -1
	endif
	wave /z/sdfr=blockDF values
	wave /z/t/sdfr=blockDF well_indices
	make /o/n=(dimsize(values,1)) blockDF:initial_hydrolysis_rates /wave=rates=nan
	variable i
	for(i=0;i<dimsize(values,1);i+=1)
		string well = well_indices[i]
		rates[i] = InitialHydrolysisRate(block,well)
	endfor	
end