// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/GLMFit.ipf $
// $Author: rick $
// $Rev: 617 $
// $Date: 2013-01-01 23:01:38 -0700 (Tue, 01 Jan 2013) $

#pragma rtGlobals=1		// Use modern global access method.

// GLMFit: Generalized linear model.  
// Example: GLMFit(observation,{covariate1,covariate2,covariate3},"log")
Function GLMFit(yy,wxx,distr[,distrParams,link,betas,prior,priorParams,func,splines,nonlinear,basis,bin,method,stepMethod,maxStepSize,maxIters,tolerance,brief,quiet,noConstant,train,condition,noGroup,depth])
	wave yy // Y values = Dependent variable = To be predicted = Measurements
	wave /wave wxx // X values = numCovariates = Regressors = Inputs; note that this is a wave of wave references, so that many waves can be passed.  
	string distr // Distribution, e.g. gaussian, poisson, vonmises.  
	wave distrParams
	string link // Link function, e.g. identity, log, tan.  By default, uses the canonical link function for the distribution.  
	
	wave /d betas // Initial guesses for the coefficients.  If the likelihood function is totally convex, this is unnecessary.  Otherwise, you may need to specify these to avoid getting trapped in a local maximum.  
	funcref L2Norm prior
	wave /wave priorParams
	
	// If an part of the model is non-linear, i.e. the covariate will be passed through a non-linearity, these next two parameters must be set.  
	string func // If func is "smith", will use functions with names like "log_poisson_smith" instead of "log_poisson".  This way arbitrary nonlinearities can be specified in the model.  
	string nonlinear // apply non-linear function func to covariate i with initial guesses a,b,c,... for function parameters using the syntax "i,func,a,b,c,...".  Mutliple numCovariates can have non-linearities, separated by semi-colons.      
	wave splines // The first entry contains the order of the polynomial to be used, i.e. {3} for a cubic.  
				// The second entry contains the maximum order of derivative to make continuous at the knots, i.e. {2} for all derivatives up to and including second derivatives.  
				// The third entry contains the index of the covariate which contains the linear variable, e.g. 't'.  
				// The fourth entry contains the modulus for repetition of the same splines, in units of the linear covariate.  Repeating splines will use the same coefficients as the original splines.  
				// The fifth entry is a boolean indicating whether the splines exist on a circular domain, i.e. does the end of the last spline meet the beginning of the first spline.  
				// The remaining entries contain the locations of the knots, in units of the linear covariate.  
				// To apply splines to multiple numCovariates, use one column for each, with each column containing the entries above.  
	
	string basis // replace covariate i (indexed from 1, with 0 as the constant term) in wxx with the basis expansion returned (as columns) by func using the syntax "i:func".  Mutliple numCovariates can have non-linearities, separated by semi-colons.      
	wave bin // divide covariate i (indexed from 1, with 0 as the constant term) in wxx into n bins in the range a,b and optionally enforce a mean of 0 using the syntax: {i,n,a,b,mean0}.  Multiple waves can be in additional columns.    
	
	variable method
		// method = 0 : Use IRLS function (by far the fastest way).  
		// method = 1 : Use Optimize to find the maximum of the log likelihood function.  
		// method = 2 : Use FindRoots to find the roots of the score function (gradient of the log likelihood function).  Faster than method 1, but perhaps more error prone (programmer error?)
	variable stepMethod // Method for stepping from one candidate solution to the next, for method = 1.  Has no effect for other methods.    
		// stepMethod=0:	Line Search			
		// stepMethod=1: Dogleg
		// stepMethod=2: More-Hebdon
		// stepMethod=3:	Simulated Annealing
	variable maxStepSize // Maximum step size in searching for solutions.  
	variable maxIters // Maximum iterations in searching for solutions.  
	variable tolerance // Tolerance (deviance above which fitting will terminate).  
	variable brief // 0 to calculate everything including submodel deviances.  
				// (1) to calculate only the main model solution, not the errors, t-values, deviances, or p-values.  
				// (2) to calculate only the main model solution and the the errors, t-values, and deviances.  
				// (3) same as (2) but echo the betas, their errors, and t-values.  
				// (4) don't even fit, just return the likelihood with the provided betas, and generated the data matrix.  
				// (>=5) don't train on the training set, just return the likelhood of the test data with the provided betas.  
				// (-1) to calculate everything and also echo submodel betas.  
	variable quiet // Do not echo results.  
	variable noConstant // Do not add a constant term (column of ones) to the list of numCovariates.  
	wave train // Training/Testing mask.  Set values to 1 to use for training (fitting), and to -1 to use for testing (cross-validation), or 0 for both.  Likelihood returned will be for testing set.  
	variable condition // Condition resultant X matrices by equalizing the L1 norm of each column.  Values > 0 restore the original data matrix and fix the betas to match the original matrix.  Values < 0 keep the conditioned values.  
	variable noGroup // Do not group coefficients according to their origin.  Test every submodel that does not contain one of them.  
	variable depth // Recursion depth.  
	
	variable i,j,k
	variable vars=1 // Number of variables needed to specify the mean in this distribution.  
	variable numCovariates=0
	variable numCoefficients=0
	variable observations=dimsize(yy,0)
	
	brief = paramisdefault(brief) ? (depth>0 ? 1 : 0) : brief
	stepMethod=paramisdefault(stepMethod) ? 2 : stepMethod // stepMethod=2 (More-Hebdon) appears to be about 35% faster than the other step methods.  
	maxStepSize=paramisdefault(maxStepSize) ? 10 : maxStepSize
	maxIters=paramisdefault(maxIters) ? 1000 : maxIters
	tolerance=paramisdefault(tolerance) ? 0.0001 : tolerance
	
	if(paramisdefault(train))
		make /free/n=(dimsize(yy,0)) train=0
	endif
		
	if(paramisdefault(link)) // Use canonical link functions.  
		strswitch(distr)
			case "gaussian":
				link="identity"
				break
			case "poisson":
				link="log"
				break
			case "binomial":
				link="logit"
				break
			case "multinomial":
				link="logit"
				vars=paramisdefault(distrParams) ? wavemax(yy) : distrParams[0]-1
				break
			case "exponential":
				link="inverse"
				break
			case "vonmises":
				link="tan"
				break
			default:
				printf "Unknown distribution: %s.  Exiting.\r",distr
				return nan
		endswitch
	endif
	
	if(paramisdefault(prior))
		funcref L2norm prior=$""
		make /free/wave/n=0 priorParams
	endif
	if(paramisdefault(priorParams) && !paramisdefault(prior))
		string priorName = stringbykey("NAME",FuncRefInfo(prior))
		strswitch(priorName)
			case "L1norm":	
			case "L2norm":
				make /free/d/n=1 param1=0 // Mean parameter.  
				make /free/d/n=1 param2=1 // Variance parameter.  
				make /free/wave/n=2 priorParams = {param1,param2}
				break
			default:
				printf "Could not generate default prior parameters for prior '%s'.\r", priorName
				return nan  
				break
		endswitch
	endif
	
	noConstant=!(noConstant==0) // Force to be 0 or 1.  
	
	make /o/d/n=0 xx // Create a matrix with that is observations x numCovariates.   
	make /free/n=0 coefficientIndex // An index to group related coefficients together (used later).  
	make /free/t/n=0 covariate_names
	if(!noConstant)
		redimension /n=(observations,1) xx
		xx=1
		coefficientIndex[0]={0}
		covariate_names[0]={"Constant"}
		numCovariates+=1
		numCoefficients+=1
	endif
	for(i=0;i<numpnts(wxx);i+=1) // Fill the matrix xx with the user-supplied waves wxx.  
		wave w=wxx[i] // One covariate.  
		if(wavetype(w)==0) // Text wave.  
			wave /t w_text=wxx[i]
			string unique_entries=""
			for(j=0;j<numpnts(w_text);j+=1)
				string entry = w_text[j]
				if(whichlistitem(entry,unique_entries)<0)
					unique_entries+=entry+";"
				endif
			endfor
			if(!quiet)
				printf "Converted '%s' to numeric.\r",unique_entries
			endif
		endif
		if(!noGroup)
			covariate_names[numCovariates]={nameofwave(w)}
		endif
		for(j=0;j<max(1,dimsize(w,1));j+=1)
			redimension /n=(observations,numCoefficients+1) xx
			coefficientIndex[numCoefficients]={numCovariates}
			if(wavetype(w)==0) // Text wave.  
				xx[][numCoefficients]=whichlistitem(w_text[p][j],unique_entries) // One column for each covariate.  
			else
				xx[][numCoefficients]=w[p][j]
			endif
			numCoefficients+=1
			if(noGroup)
				string label_=GetDimLabel(w,1,j)
				covariate_names[numCovariates]={nameofwave(w)+"; "+selectstring(strlen(label_),"Col "+num2str(j),label_)}
			endif
			numCovariates+=noGroup
		endfor
		numCovariates+=(1-noGroup)
	endfor
	if(numCoefficients<2)
		condition=0
	endif
	
	variable sumXX=sum(xx)
	if(numtype(sumXX))
		if(!quiet)
			printf "There are infs or NaNs in the data set.\r"
		endif
		return nan
	endif
	
	// Optionally break up a covariate into several numCovariates valued at 0 or 1, corresponding to the whether the covariate was in a particular range of values at that observation.  
	if(!paramisdefault(bin))
		if(dimsize(bin,0)!=5)
			printf "Number of rows in the 'bin' parameter wave must be 5.  Exiting.\r"
			return nan
		endif
		for(i=0;i<dimsize(bin,1);i+=1)
			variable wn=bin[0][i]
			if(wn>=numCovariates)
				continue
			endif
			variable bins=bin[1][i]
			variable low=bin[2][i]
			variable high=bin[3][i]
			variable mean0=bin[4][i] ? 1 : 0
			variable width=(high-low)/bins
			wave w=wxx[wn-1] // One covariate that should be binned.  -1 is because covariate 1 is the 0th entry in wxx (the constant term is covariate 0).  
			variable column=wn+numCoefficients-numCovariates // wn if it is the only covariate being binned; otherwise account for others numCovariates binned before it.  
			
			insertpoints /m=1 column,bins-1,xx
			insertpoints column,bins-1,coefficientIndex
			for(j=0;j<bins;j+=1)
				duplicate /free w,wBin
				wBin=(w>=(low+j*width) && w<(low+(j+1)*width)) // 0 or 1.  
				xx[][column+j]=wBin[p]-mean0/bins // Subtract 1/bins so that the mean across bins is 0 instead of 1/bins.  
				coefficientIndex[column+j]={wn}
				waveclear wBin
			endfor
			//covariateIndex[column+j]=gnoise(1) // Testing this out to see if ensuring that the columns are linearly independent helps.  
			numCoefficients+=bins-1
		endfor
	endif
	
	if(!paramisdefault(basis))
		for(wn=0;wn<numCovariates;wn+=1)
			string basisFuncName=stringbykey(num2str(wn),basis)
			if(!strlen(basisFuncName))
				continue
			endif
			funcref basisFuncProto basisFunc=$basisFuncName
			if(!strlen(stringbykey("NAME",funcrefinfo(basisFunc)))) // If the function doest not match the prototype.  
				printf "%s does not match the fitting function prototype; ignoring basis functions.\r",basisFuncName
				continue
			endif
			wave w=wxx[wn-1] // One covariate that should be transformed with basis functions.  -1 is because covariate 1 is the 0th entry in wxx (the constant term is covariate 0).  
			wave basisColumns=basisFunc(w)
			variable numBasisColumns=max(1,dimsize(basisColumns,1))
			column=wn+numCoefficients-numCovariates // wn if it is the only covariate being basised; otherwise account for others numCovariates binned/basised before it.  
			insertpoints /m=1 column,numBasisColumns-1,xx
			insertpoints column,numBasisColumns-1,coefficientIndex
			xx[][column,column+numBasisColumns-1]=basisColumns[p][q-column] // Replace original value with basis expansion.  
			coefficientIndex[column,column+numBasisColumns-1]=wn
			numCoefficients+=numBasisColumns-1
		endfor
	endif
	
	// Optionally apply a non-linear function to some covariate, increasing the number of parameters.  
	if(!paramisdefault(nonlinear))
		make /free/n=(numCovariates)/t funcRefs=""
		make /free/n=(numCovariates)/wave funcGuesses
		for(i=0;i<itemsinlist(nonlinear);i+=1)
			string nonlinear_=stringfromlist(i,nonlinear)
			wn=str2num(stringfromlist(0,nonlinear_,","))
			if(wn>=numCovariates)
				printf "%d is larger than the highest-numbered covariate.\r",wn
				continue
			endif
			string funcName=stringfromlist(1,nonlinear_,",")
			funcref fitFuncProto fitFunc=$funcName
			if(!strlen(stringbykey("NAME",funcrefinfo(fitFunc)))) // If the function doest not match the prototype.  
				printf "%s does not match the fitting function prototype; treating as linear instead.\r",funcName
				continue
			endif
			funcRefs[wn]=funcName
			make /o/n=0 $("guess_"+num2str(wn)) /wave=guesses
			for(j=2;j<itemsinlist(nonlinear_,",");j+=1)
				variable guess=str2num(stringfromlist(j,nonlinear_,","))
				guesses[j-2]={guess}
			endfor
			funcGuesses[wn]=guesses
		endfor
	endif
	
	if(!paramisdefault(splines) && dimsize(splines,0)>=6) // At least 4 metaparameters plus 2 knots. 
		duplicate /free splines,splines_ // Make a copy to operate on.   
		for(k=0;k<max(1,dimsize(splines_,1));k+=1) // Iterate over each covariate to be splined.  
			variable splineOrder=splines_[0][k]
			variable splineDiff=splines_[1][k]
			variable splineRootCol=splines_[2][k]+!noConstant
			matrixop /free tt=col(xx,splineRootCol) // The splined column, which we will call "t" as if it contains time.  
			variable splineModulus=splines_[3][k]
			if(splineModulus)
				tt=mod(tt,splineModulus) // The value of t will be reset every 'splineModulus' units.  
			endif
			variable splineCircular=splines_[4][k] != 0 // Are the first and last splines continuous with each other, i.e. is the first knot the same as the last knot?  
			make /free/n=(dimsize(splines,0)-5) knots=splines[5+p][k]
			variable numKnots=numpnts(knots)
			if(wavemax(knots)>splineModulus)
				printf "Spline modulus must be at least as large as the position of the largest knot.\r"
				return nan
			endif
			if(splineCircular)
				//variable numNewCoefficients=(splineOrder-splineDiff)*numKnots - 1
				variable numNewCoefficients=splineOrder+1+(splineOrder-splineDiff)*(numKnots-1) - (splineDiff+1) - 1
			else
				numNewCoefficients=splineOrder+1+(splineOrder-splineDiff)*(numKnots-2) - 1 // Add splineOrder+1 coefficients for each spline, but take away those coefficients which are determined by coeffcients in previous splines.     
			endif
			insertpoints /m=1 splineRootCol,numNewCoefficients,xx // Be careful because the index in the xx wave corresponding to the term to be fitted with splines may have changed as a result of the use of other optional arguments.  
			splines_[2][]+=splines_[2][q]>splineRootCol ? numNewCoefficients : 0 // Change the root column for subsequent numCovariates to reflect changes in the size of the xx wave.  
			insertpoints splineRootCol,numNewCoefficients,coefficientIndex
			coefficientIndex[splineRootCol,splineRootCol+numNewCoefficients-1]=splineRootCol
			numCoefficients+=numNewCoefficients
			make /free/n=(numpnts(tt)) knotIndices=binarysearch(knots,tt[p]) // Which spline does each observation belong to?  
			variable offset=0
			if(splineCircular)
				knotIndices = knotIndices<0 ? numKnots-1 : knotIndices[p]
				//tt += tt[p]<knots[0] ? splineModulus : 0
			endif
			xx[][splineRootCol,splineRootCol+numNewCoefficients]=0
			for(i=0;i<numKnots;i+=1)
				if(splineCircular) // Circular domain.  
					for(j=0;j<(numNewCoefficients+1);j+=1)
						switch(splineOrder)
							case 2:
								switch(splineDiff)
									case 0: // a[0,0],a[0,1],a[0,2],a[1,1],a[1,2],a[2,2]   I eliminated the first order coefficient for the last spline.   
										variable spline = j<=2 ? 0 : (1+floor((j-3)/2))
										variable power = spline == 0 ? j : (1 + mod(j-3,2))
										power += spline==(numKnots-1) ? 1 : 0
										break
									case 1: // a[0,0],a[1,2],a[2,2],a[3,2],a[4,2],a[5,2],..    I eliminated the last two (first, second order) coefficients for the first spline.   
										spline = j
										power = spline == 0 ? 0 : 2
										break
								endswitch
								break
							case 3:
								switch(splineDiff)
									case 0:  // a[0,0],a[0,1],a[0,2],a[0,3],a[1,1],a[1,2],a[1,3],a[2,2],a[2,3]   I eliminated the first order coefficient for the last spline.   
										spline = j<=3 ? 0 : (1+floor((j-4)/3))
										power = spline == 0 ? j : (1 + mod(j-4,3))
										power += spline==(numKnots-1) ? 1 : 0
										break
									case 1: // a[0,0],a[0,1],a[0,2],a[0,3],a[1,2],a[1,3],a[2,2],a[2,3],...   I eliminated both (second and third order) coefficients for the last spline.   
										spline = j<=3 ? 0 : (1+floor((j-4)/2))
										power = spline == 0 ? j : (2 + mod(j-4,2))
										break
									case 2: // a[0,0],a[1,3],a[2,3],a[3,3],a[4,3],a[5,3],..    .I eliminated the last three (first, second, and third order) coefficients for the first spline.   
										spline = j
										power = spline == 0 ? 0 : 3
										break
								endswitch
								break
						endswitch
						column = splineRootCol + j
						xx[][column] = knotIndices[p] == i ? SplineCoefs2(splineOrder,splineDiff,tt[p],splineModulus,knots,spline,power,i) : xx[p][q]
					endfor
				else // Not a circular domain.   
					if(i==0) // First full spline.  
						for(j=0;j<=splineOrder;j+=1)
							power=j
							column = splineRootCol + j
							xx[][column]=(tt[p]-knots[i])^power // Set each observation to the jth polynomial term for the ith knot if it is in the ith spline, and otherwise set it to zero.  
						endfor
						offset+=splineOrder+1 
					else
						for(j=0;j<splineOrder-splineDiff;j+=1)
							power=j+splineDiff+1
							column = splineRootCol + offset + j
							xx[][column]=knotIndices[p]>=i ? (tt[p]-knots[i])^power : 0 // Set each observation to the jth polynomial term for the ith knot if it is in the ith spline, and otherwise set it to zero.  
						endfor
						offset+=(splineOrder-splineDiff)
					endif
				endif
			endfor
		endfor
		xx=numtype(xx[p][q])==2 ? 0 : xx[p][q]
	endif
	
	variable yColumns=max(1,dimsize(yy,1)) // Number of columns of the data to be predicted.  Usually 1.  
	if(paramisdefault(betas))
		make /o/d/n=(numCoefficients,vars,yColumns) betas=gnoise(0.01) // Initial guess at solution.    
	else
		redimension /d/n=(numCoefficients,vars,yColumns) betas
	endif
	if(!paramisdefault(prior))
		for(i=0;i<numpnts(priorParams);i+=1)
			wave w=priorParams[i]
			variable numPriorRows=dimsize(w,0)
			variable numPriorColumns=dimsize(w,1)			
			variable numPriorLayers=dimsize(w,2)			
			priorName=stringbykey("NAME",funcrefinfo(prior))
			strswitch(priorName)
				case "L1Norm":
				case "L2Norm":
					if(i==0) // Mean.  
						redimension /d/n=(numCoefficients,vars,yColumns) w
						w[numPriorRows,][0][numPriorLayers,]=0
					elseif(i==1) // Variance.  
						redimension /d/n=(numCoefficients*vars,numCoefficients*vars,yColumns) w
						for(j=numPriorRows;j<dimsize(w,0);j+=1)
							w[j][][]=p==q ? w[numPriorRows-1][numPriorColumns-1][0] : 0
						endfor
					endif
					break
			endswitch
		endfor
	endif
	
	string likelihoodName=distr+"_"+link
	if(exists(likelihoodName)!=6)
		printf "No such function: %s.  Exiting.\r",likelihoodName
		return nan
	endif	
	funcref gaussian_identity likelihood=$likelihoodName
	
	if(condition) // Condition the matrix.    
		matrixop /free square=xx^t x xx
		matrixeigenv square
		wave w_eigenvalues
		if(!quiet)
			//printf "Old condition number is %d.\r",sqrt(w_eigenvalues[0]/w_eigenvalues[numpnts(w_eigenvalues)-1])
		endif
		make /free/n=(dimsize(xx,1)) scaling = colmax(xx,p)//matrixop /free scaling=meancols(abs(xx))
		duplicate /free xx,xxScaled
		xxScaled/=scaling[q]
		matrixop /free square=xxScaled^t x xxScaled
		matrixeigenv square
		if(!quiet)
			//printf "New condition number is %d.\r",sqrt(w_eigenvalues[0]/w_eigenvalues[numpnts(w_eigenvalues)-1])
		endif
	endif
	
	if(!paramisdefault(train))
		extract /free/indx train,trainIndices,train>=0
		extract /free/indx train,testIndices,train<=0
		make /free/n=(numpnts(trainIndices),dimsize(yy,1)) yyTrain=yy[trainIndices[p]][q]
		make /free/n=(numpnts(trainIndices),dimsize(xx,1)) xxTrain=xx[trainIndices[p]][q]
		make /free/n=(numpnts(testIndices),dimsize(yy,1)) yyTest=yy[testIndices[p]][q]
		make /free/n=(numpnts(testIndices),dimsize(xx,1)) xxTest=xx[testIndices[p]][q]
	else
		duplicate /free yy,yyTrain,yyTest
		duplicate /free xx,xxTrain,xxTest
	endif
	strswitch(distr)
		case "gaussian": // Must put this in normal form so the variance is independent of the mean.  
			wavestats /q yyTrain
			yyTrain/=v_sdev
			wavestats /q yyTest
			yyTest/=v_sdev
			variable y_stdev=v_sdev
			break
	endswitch
	if(brief==4)
		return likelihood(xxTrain,betas)
	endif
	
	if(condition)
		xxTrain/=scaling[q]
		if(!paramisdefault(priorParams))
			for(i=0;i<numpnts(priorParams);i+=1)
				wave w=priorParams[i]
				priorName=stringbykey("NAME",funcrefinfo(prior))
				strswitch(priorName)
					case "L1Norm":
					case "L2Norm":
						if(i==0) // Mean.  
							w*=scaling[p]
						elseif(i==1) // Variance.  
							w*=scaling[p]*scaling[q]  
						endif
						break
				endswitch
			endfor
		endif
	endif
	if(brief<5)
		switch(method)
			case 0: // IRLS.  
				maxStepSize=paramisdefault(maxStepSize) ? Inf : maxStepSize
				IRLS(yyTrain,xxTrain,betas,link,distr,maxIters=maxIters,maxStepSize=maxStepSize,tolerance=tolerance,prior=prior,priorParams=priorParams,quiet=quiet)
				break
			case 1: // Maximize the likelihood function directly.  
				maxStepSize=paramisdefault(maxStepSize) ? 10 : maxStepSize
				optimize /q/a=1/i=(maxIters)/m={stepMethod,1} /s=(maxStepSize) /x=betas likelihood,xxTrain
				killwaves /z w_optgradient
				break
			case 2: // Find roots of the score function (gradient of the likelihood function) to get coefficients.   
				string scoreName="d_"+distr+"_"+link
				if(exists(scoreName)!=6)
					printf "No such function: %s.  Exiting.\r",scoreName
					return nan
				endif	
				funcref d_gaussian_identity score=$scoreName
				FindRoots /q/i=(maxIters) /f=(maxStepSize) /x=betas score,xxTrain
				break
			default:
				printf "No such fitting method: %d.\r",method
				return nan
		endswitch
	endif
	if(condition>0)
		xxTrain*=scaling[q]
		betas/=scaling[p]
		if(!paramisdefault(priorParams))
			for(i=0;i<numpnts(priorParams);i+=1)
				wave w=priorParams[i]
				priorName=stringbykey("NAME",funcrefinfo(prior))
				strswitch(priorName)
					case "L1Norm":
					case "L2Norm":
						if(i==0) // Mean.  
							w/=scaling[p]
						elseif(i==1) // Variance.  
							w/=scaling[p]*scaling[q]  
						endif
						break
				endswitch
			endfor
		endif
	endif
	
	matrixop /free eta=xxTest x betas
		
	strswitch(link)
		case "identity":
			matrixop /o mu=eta
			break
		case "log":
			matrixop /o mu=exp(eta)
			break
		case "logit":
			//redimension /e=1/n=(numCovariates,vars) eta
			if(vars>1)
				matrixop /o mu=exp(eta)/colrepeat(sumrows(exp(eta))+1,vars)
			else
				matrixop /o mu=exp(eta)/(sumrows(exp(eta))+1)
			endif
			break
		case "inverse":
			matrixop /o mu=powR(eta,-1)
			break
		case "tan":
			matrixop /o mu=2*atan(eta)
			break
		default:
			printf "No such link function %s.  Exiting.\r",link
			return nan
	endswitch
	
	strswitch(distr)
		case "gaussian": // Must put this in normal form so the variance is independent of the mean.  
			mu *= y_stdev
			//betas *= y_stdev
			break
	endswitch
	
	variable modelLikelihood=likelihood(xxTest,betas) // maximized log likelihood of the model (ignores prior).  
	
	if(depth==0)
		variable r2=statscorrelation(yyTest,mu)^2
		duplicate /free mu,mu_
		duplicate /free xx,xx_full // Backup covariate matrix from full_model, since xx may be overwritten during recursion.  
	endif
	if(abs(brief)==1 || brief==5 || depth>0)
		strswitch(distr)
			case "gaussian": // Must put this in normal form so the variance is independent of the mean.  
				betas *= y_stdev
				break
		endswitch
		if(brief==-1)
			printf "{ "
			for(i=0;i<numpnts(betas);i+=1)
				printf "%.2f ",betas[i]
			endfor
			printf " }\r"
		endif
	else
		string fisherName="d2_"+distr+"_"+link // Name of function that evaluates the Hessian matrix.  
		if(exists(fisherName)!=6)
			printf "No such function: %s.\r",fisherName
		else
			funcref d2_gaussian_identity fish=$fisherName
			wave fisher=fish(xxTest,betas) // Hessian matrix of the log likelihood evaluated at the solution 'betas'.  
			duplicate /o fisher $"fisher"
			duplicate /free fisher fisherNorm
			wavestats /q fisher
			variable fisherAvg=v_avg
			fisherNorm/=fisherAvg
			matrixeigenv fisherNorm
			wave w_eigenvalues
			variable conditionNumber=sqrt(cabs(w_eigenvalues[0])/cabs(w_eigenvalues[numpnts(w_eigenvalues)-1]))
			// Try inverting the covariance matrix.  
			variable err=getrterror(1)
			DebuggerOptions
			variable doe=v_DebugOnError
			DebuggerOptions debugOnError=0		
			matrixop /free betaErrorMatrix=chol(inv(fisher))///sqrt(observations)//temp[p][p]//sqrt(betaCovars[p][p])/sqrt(observations)
			err=getrterror(1)
			if(err)
				if(!quiet)
					printf "Fisher information matrix is probably close to singular.\r"
					printf "Condition Number = %g\r",conditionNumber
				endif
				make /o/n=(numCoefficients,vars) betaErrors=sqrt((1/fisher[p+q*numCoefficients][p+q*numCoefficients]))///sqrt(observations) // This is not really correct, but with a singular matrix, what else can be done?  
			else
				duplicate /o betaErrorMatrix $"betaErrorMatrix"
				make /o/n=(numCoefficients,vars) betaErrors=betaErrorMatrix[p+q*numCoefficients][p+q*numCoefficients]
			endif
			strswitch(distr)
				case "gaussian": // Must put this in normal form so the variance is independent of the mean.  
					betas *= y_stdev
					betaErrors *= y_stdev
					break
			endswitch
			DebuggerOptions debugOnError=doe
		endif
			
		make /o/n=(numCoefficients,vars) betaTs=betas/betaErrors // t-statistic.  
		variable dof=numCovariates-1 // Degrees of freedom.
		make /o/n=(numCoefficients,vars) betaPartials=sqrt(1/(1+(dof/betaTs^2)))*sign(betaTs) // Partial correlations.  
		make /o/n=(numCoefficients,vars) betaPvals=nan // p-values.  
		make /o/n=(numCoefficients,vars) betaDeviances=nan // Deviances vs. model with the given covariate excluded.  
		if(brief!=2) // If we are printing stats or testing the sub-models.  
			if(numCovariates>1)
				variable covariate,coefficient=0
				for(covariate=0;covariate<numCovariates;covariate+=1)
					extract /free coefficientIndex,coefficienti,coefficientIndex==covariate
					variable familySize=numpnts(coefficienti) // If this was a binned covariate or from a multidimensional basis, this number will be > 1.  Otherwise, it will be 1.  
					if(brief==3) // Report stats but do not test sub-models.  
					else // Test sub-models.  
						Prog("Sub",covariate,numCovariates)
						duplicate /free/wave wxx,wxx_sub
						if(covariate>0 || noConstant)
							if(!noGroup)
								deletepoints covariate-!noConstant,1,wxx_sub
							else
								variable which_wxx=0
								variable covariates_so_far=0
								do
									covariates_so_far+=dimsize(wxx[which_wxx],1)
									if(covariates_so_far>=covariate)
										break
									else
										which_wxx+=1
									endif
								while(1)
								variable wxx_index = covariate-(covariates_so_far-dimsize(wxx[which_wxx],1))-!noConstant
								wave w = wxx[which_wxx]
								duplicate /free w,w_sub
								deletepoints /m=1 wxx_index,1,w_sub
								wxx_sub[which_wxx]=w_sub
							endif
						endif
						
						duplicate /free betas,betas_sub
						deletepoints /m=0 covariate,familySize,betas_sub
						betas_sub+=gnoise(0.00001) // Tweak the betas just a little bit to avoid some singular hessian matrix issues when testing the sub-models.  
						
						if(!paramisdefault(splines))	
							duplicate /free splines,splines_sub
							if(i<splines_sub[2])
								splines_sub[2]-=1 // Possibly change index of variable to be subject to splines.  
							elseif(i==splines_sub[2])
								redimension /n=0 splines_sub // If we are testing the significance of the splined variable, test the model without the variable without splines.  
							endif
						else
							make /free/n=0 splines_sub
						endif
						
						duplicate /free/wave priorParams,priorParams_sub
						for(j=0;j<numpnts(priorParams);j+=1)
							wave priorParam=priorParams[j]
							duplicate /free priorParam,priorParam_sub
							k=0
							do
								if(dimsize(priorParam,k)>1)
									deletepoints /m=(k) coefficient,familySize*(j==1 ? vars : 1),priorParam_sub
								else
									break
								endif
								k+=1
							while(1)
							priorParams_sub[j]=priorParam_sub
						endfor
						variable subModelLikelihood=GLMFit(yy,wxx_sub,distr,link=link,splines=splines_sub,method=method,stepMethod=stepMethod,maxStepSize=maxStepSize,maxIters=maxIters,betas=betas_sub,prior=prior,priorParams=priorParams_sub,brief=1,quiet=1,noConstant=(covariate==0 || noConstant ? 1 : 0),train=train,depth=depth+1)
						betaDeviances[coefficient]=2*(modelLikelihood-subModelLikelihood) // deviance between this model and the full model.  
					endif
					dof=(familySize>1) ? familySize : 1  
					for(j=0;j<dimsize(bin,1);j+=1)
						if(bin[0][j]==covariate) // If it was binned, there are actually familySize-1 degrees of freedom because the sum of the bins equals a constant.   
							dof-=1
							break
						endif
					endfor
					betaPvals[coefficient][]=1-statschicdf(betaDeviances[coefficient][q],dof) // significance of this value of deviance.  
					if(!quiet)
						variable digits=5
						string covariate_name=covariate_names[covariate]
						if(stringmatch(covariate_name,"_free_"))
							sprintf covariate_name,"Column %d",coefficient
						endif
						if(familySize<=1) // Regular.  
							for(k=0;k<vars;k+=1)	
								string format="(%d: %s%s) %.[[digits]]f +/- %.[[digits]]f; t=%.2f; rho=%.2f; dev=%.2f; p=%.3f\r"
								format = replacestring("[[digits]]",format,num2str(digits))	
								printf format,covariate,covariate_name,selectstring(vars>1,"","["+num2str(k)+"]"),betas[coefficient][k],betaErrors[coefficient][k],betaTs[coefficient][k],betaPartials[coefficient][k],betaDeviances[coefficient][k],betaPvals[coefficient][k] // Summary of this covariate.  	
							endfor
						else // Binned or Basised.  
							for(j=0;j<familySize;j+=1)
								for(k=0;k<vars;k+=1)
									if(j==0)
										format = "(%s: %s%s) %.[[digits]]f +/- %.[[digits]]f; t=%.[[digits]]f; rho=%.[[digits]]f; dev=%.[[digits]]f; p=%.[[digits]]f\r"
										format = replacestring("[[digits]]",format,num2str(digits))	
										printf format,num2str(covariate)+num2char(97+j),covariate_name,selectstring(vars>1,"","["+num2str(k)+"]"),betas[coefficient][k],betaErrors[coefficient][k],betaTs[coefficient][k],betaPartials[coefficient][k],betaDeviances[coefficient][k],betaPvals[coefficient][k] // Summary of this covariate.  
									else
										format = "(%s%s) %.[[digits]]f +/- %.[[digits]]f; t=%.[[digits]]f\r"
										format = replacestring("[[digits]]",format,num2str(digits))
										printf format,num2str(covariate)+num2char(97+j),selectstring(vars>1,"","["+num2str(k)+"]"),betas[coefficient+j][k],betaErrors[coefficient+j][k],betaTs[coefficient+j][k] // Summary of this covariate.  Don't show deviance and p-value for subsequent bins since this is redundant.  
									endif
								endfor
							endfor
						endif
					endif
					//if(!paramisdefault(splines))
					//	duplicate /o splines_,splines // Restore knots from full model.  
					//endif
					coefficient+=familySize
				endfor
			endif
		endif
		if(!quiet)
			printf "Log-Likelihood = %f\r",modelLikelihood // The log-likelihood.  
			printf "R2 = %.3f\r",r2
			printf "AIC = %.2f\r",AIC(modelLikelihood,xxTest,betas) // Here 'modelLikelihood' is already the log-likelihood, so we don't need the ln.  
			printf "BIC = %.2f\r",BIC(modelLikelihood,xxTest,betas)
		endif
	endif
	if(depth==0)
		duplicate /o mu_,mu // Restore full model mu.
		duplicate /o xx_full,xx // Restore full model xx, which may have been overwritten during recursion or broken up during testing/training.  
		if(norm(train) != 0) // There was a training and testing phase.  
			duplicate /o xxTrain $"xxTrain"
			duplicate /o xxTest $"xxTest"
		endif
	endif
	return modelLikelihood
End

// ---------------- Gaussian distribution; Identity link function. -----------

// The following functions will either maximize the log likelihood, or find roots of the gradient of the log likelihood, according to the following set of equations:  
L({yi}|mu) = prod{ exp(-(yi-mu)^2/sigma^2) } // The likelihood function for a gaussian distribution.  
ln(L) =sum{ -(yi-mu)^2/sigma^2 } // Log likelihood.  
ln(L) =sum{ -(yi-b0-b1*x1i-b2*x2i-...)^2/sigma^2 } // Plug in the glm equation mu = b0 + b1*x1 + b2*x2 + ..., where mu=E(y).  We can drop the sigma^2 when maximizing.  
grad(ln(L))=sum{ (yi-b0-b1*x1i-b2*x2i-...) } // The gradient of the log likelihood, with constants taken outside of the summation and dropped since we will be setting equal to zero.  
                sum{ x1i*(yi-b0-b1*x1i-b2*x2i-...) }
                sum{ x2i*(yi-b0-b1*x1i-b2*x2i-...) }
                ...
hessian(ln(L))=sum( -1        -x1i        -x2i       .... )
                            ( -x1i     -x1i^2     -x1i*x2i  .... )
                            ( -x2i     -x1i*x2i   -x2i^2    .... )
                            ( ....                                     )       

// L
Function gaussian_identity(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the maximum.  
	
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	matrixop /free eta=xx x betas
	make /free/n=(numpnts(eta)) likelihoods = -(yy[p]-eta[p])^2 // Just minimizing the sum of squares in this simple case.  
	variable logL = sum(likelihoods)
	return logL
End

// L'
Function /wave d_gaussian_identity(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the roots of the gradient function.  
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	variable observations=dimsize(xx,0)
	variable numCovariates=dimsize(xx,1)
	variable yColumns=max(1,dimsize(betas,1))
	variable i,j
	matrixop /free eta=xx x betas
	matrixop /free grad=2*(xx^t x (yy - eta))
	return grad
End

// -L''
Function /wave d2_gaussian_identity(xx,betas)
	wave xx,betas  
	
	variable xColumns=dimsize(xx,1)
	variable yColumns=max(1,dimsize(betas,1))
	matrixop /free fisher_=2*(xx^t x xx)///numrows(xx) // Positive because the negative sign on the Hessian cancels with the negative 1 that we multiply to get a Fisher information matrix.  
	make /free/d/n=(xColumns,xColumns,yColumns) fisher=fisher_[p][q]
	return fisher
End

// ---------------- Gaussian distribution; Log link function. Not canonical. -----------

// The following functions will either maximize the log likelihood, or find roots of the gradient of the log likelihood, according to the following set of equations:  
L({yi}|mu) = prod{ exp(-(yi-mu)^2/sigma^2) } // The likelihood function for a gaussian distribution.  
ln(L) =sum{ -(yi-mu)^2/sigma^2 } // Log likelihood.  
ln(L) =sum{ -(yi-exp(b0-b1*x1i-b2*x2i-...))^2/sigma^2 } // Plug in the glm equation ln(mu) = b0 + b1*x1 + b2*x2 + ..., where mu=E(y).  We can drop the sigma^2 when maximizing.  
grad(ln(L))=sum{ exp(b0-b1*x1i-b2*x2i-...) - (yi - exp(b0-b1*x1i-b2*x2i-...)) } // The gradient of the log likelihood, with constants taken outside of the summation and dropped since we will be setting equal to zero.  
                sum{ exp(b0-b1*x1i-b2*x2i-...) - x1i*(yi - exp(b0-b1*x1i-b2*x2i-...)) }
                sum{ exp(b0-b1*x1i-b2*x2i-...) - x2i*(yi - exp(b0-b1*x1i-b2*x2i-...)) }
                ...
hessian(ln(L))=exp(b0-b1*x1i-b2*x2i-...) + (yi - 2*exp(b0-b1*x1i-b2*x2i-...)) * sum( -1        -x1i        -x2i       .... )
                                                                   								( -x1i     -x1i^2     -x1i*x2i  .... )
                                                                   								( -x2i     -x1i*x2i   -x2i^2    .... )
                                                                    								( ....                                     )       

// L
Function gaussian_log(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the maximum.  
	
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	matrixop /free eta=xx x betas
	make /free/n=(numpnts(eta)) likelihoods = -(yy[p]-exp(eta[p]))^2  
	return sum(likelihoods)
End

// L' 
Function /wave d_gaussian_log(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the roots of the gradient function.  
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	matrixop /free eta=xx x betas
	matrixop /free grad= - (xx^t x (yy - exp(eta))) + rowrepeat(sumcols(exp(eta))^t,4)
	return grad
End

// -L''
// TO DO: Check for correctness.  
Function /wave d2_gaussian_log(xx,betas)
	wave xx,betas  
	
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	variable observations=dimsize(xx,0)
	variable xColumns=dimsize(xx,1)
	variable yColumns=max(1,dimsize(betas,1))
	matrixop /free eta=xx x betas
	make /free/d/n=(observations,yColumns) multiplier=sqrt(abs(yy - 2*exp(eta)))
	make /free/d/n=(observations,xColumns,yColumns) matrix=exp(eta) + xx[p][q] * multiplier[p][r]
	matrixop /free fisher=matrix^t x matrix
	return fisher
End

// ---------------- Poisson distribution; Logarithmic link function. -----------

// The following functions will either maximize the log likelihood, or find roots of the gradient of the log likelihood, according to the following set of equations:  
L({y}|mu) = prod{ exp(-mu)*mu^yi/yi! } // The likelihood function for a poisson distribution.  
ln(L) =sum{ -mu + yi*ln(mu) - ln(yi!) } // Log likelihood.  
ln(L) =sum{ -exp(b0+b1*x1i+b2*x2i+...) + yi*(b0+b1*x1i+b2*x2i+...) - ln(yi!) } // Plug in the glm equation ln(mu) = b0 + b1*x1 + b2*x2 + ..., where mu=E(y).  
grad(ln(L))=sum{ -exp(b0+b1*x1i+b2*x2i+...) + yi} // The gradient of the log likelihood.  
                sum{ -x1i*exp(b0+b1*x1i+b2*x2i+...) + yi*x1i}
                sum{ -x2i*exp(b0+b1*x1i+b2*x2i+...) + yi*x2i}
                ...
hessian(ln(L))=sum{ -exp(b0+b1*x1i+b2*x2i+...) * ( 1         x1i         x2i            .... )
                            						            ( x1i      x1i^2      x1i*x2i     .... )
                            						            ( x2i      x1i*x2i    x2i^2       .... )
                                                                                         ( ....                                            ) }      

//Function poisson_log(xx,betas[,knots])
//	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
//	wave betas // The coefficients that will be adjusted to find the maximum.  
//	wave knots // The first entry contains the order of the polynomial to be used, i.e. {3} for a cubic.  The second entry contains the indices of the numCovariates which contains the linear variable, e.g. 't'.  
//				// Subsequent powers of that variable are assumed to be contained in immediately subsequent columns, up to the polynomial order specified.  So if covariate 3 might contains 't', 
//				// the second entry would be {3}.  The third entry contains the index of the coefficient (column of the beta wave) which contains the constant coefficient for the first spline.  Subsequent coefficients for
//				// that spline and coefficients for subsequent splines are assumed to be contained in immediately subsequent columns.  The remaining entries contain the locations of the knots, in units of the linear covariate.  
//	
//	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
//	
//	matrixop /free xxBeta=xx x betas
//	xxBeta = -exp(xxBeta[p]) + yy[p]*xxBeta[p] - ln(factorial(yy[p]))
//	return sum(xxBeta)
//End

Function poisson_log(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the maximum.  
	
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	matrixop /free eta=xx x betas
	if(wavemax(eta)>100)
		printf "Max eta=%.2f, Min eta=%.2f\r",wavemax(eta),wavemin(eta)
		duplicate /o xx,test_xx
		duplicate /o betas,test_betas
		duplicate /o eta,test_eta
		//abort
	endif
	//make /free/d/n=(dimsize(eta,0),dimsize(eta,1)) likelihoods1 = -exp(eta[p])
	//make /free/d/n=(dimsize(eta,0),dimsize(eta,1)) likelihoods2 = yy[p]*eta[p] 
	//make /free/d/n=(dimsize(eta,0),dimsize(eta,1)) likelihoods3 = -ln(factorial(yy[p]))
	//print sum(likelihoods1),sum(likelihoods2),sum(likelihoods3)
	//make /free/d/n=(dimsize(eta,0),dimsize(eta,1)) likelihoods = likelihoods1 + likelihoods2 + likelihoods3
	make /free/d/n=(dimsize(eta,0),dimsize(eta,1)) likelihoods = -exp(eta[p]) + yy[p]*eta[p] - ln(factorial(yy[p]))
	likelihoods = numtype(likelihoods[p][q])==1 ? (-exp(eta[p]) + yy[p]*eta[p] - Stirling(yy[p])) : likelihoods[p][q] // Use Stirling's approximation if there are any Inf's or -Inf's.  
	variable result = sum(likelihoods)
	return result
End

Function /wave d_poisson_log(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the roots of the gradient function.  
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	matrixop /free eta=xx x betas
	matrixop /free grad=xx^t x (yy - exp(eta))
	return grad
End

// L''
Function /wave d2_poisson_log(xx,betas)
	wave xx,betas  
	
	variable observations=dimsize(xx,0)
	variable xColumns=dimsize(xx,1)
	variable yColumns=max(1,dimsize(betas,1))
	matrixop /free multiplier=sqrt(exp(xx x betas))
	make /free/d/n=(observations,xColumns,yColumns) matrix=xx[p][q] * multiplier[p][r]
	make /free/d/n=(xColumns,xColumns,yColumns) fisher
	variable i
	for(i=0;i<yColumns;i+=1)
		matrixop /free matrix_=layer(matrix,i)
		matrixop /free fisher_=(matrix_^t x matrix_)///numrows(xx) // Positive because the negative sign on the Hessian cancels with the negative 1 that we multiply to get a Fisher information matrix.  
		fisher[][][i]=fisher_[p][q]
	endfor
	return fisher
End

// ---------------- Binomial distribution; Logistic link function. -----------

// The following functions will either maximize the log likelihood, or find roots of the gradient of the log likelihood, according to the following set of equations:  
L({y}|mu) = prod{ (mu^yi)(1-mu)^(1-yi) } // The likelihood function for a binomial distribution.  
ln(L) =sum{ yi*ln(mu) + (1-yi)*ln(1-mu) } // Log likelihood.  
ln(L) =sum{ yi*ln(mu/(1-mu)) + ln(1-mu) } 
ln(L) =sum{ yi*(b0+b1*x1i+b2*x2i+...) + ln(1-(1/(1+exp(-b0-b1*x1-b2*x2-...)))) } // Plug in the glm equation with logit link ln(mu/(1-mu)) = b0 + b1*x1 + b2*x2 + ..., where mu=E(y).    
etai=b0+b1*x1i+b2*x2i+...
grad(ln(L))=sum{ yi - 1 + 1/(1+exp(etai)) } // The gradient of the log likelihood.  
                sum{ x1i*(yi - 1 + 1/(1+exp(etai)) }
                sum{ x2i*(yi - 1 + 1/(1+exp(etai)) }
                ...
hessian(ln(L))=sum{ -1/(2*(1+cosh(etai))) * ( 1         x1i         x2i            .... )
                            					   ( x1i      x1i^2      x1i*x2i       .... )
                            					   ( x2i      x1i*x2i    x2i^2          .... )
                                                              ( ....                                          ) }   

Function binomial_logit(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the maximum.  
	
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	matrixop /free eta=xx x betas
	make /free/n=(dimsize(eta,0)) likelihoods = yy[p]*eta[p] + ln(1-(1/(1+exp(-eta[p]))))
	variable result=sum(likelihoods)
	if(numtype(result)==1) // Infinity or -Infinity.  Probably results from exponentiating a very negative number.  
		likelihoods=numtype(likelihoods[p])==1 ? yy[p]*eta[p]-eta[p] : likelihoods[p] // Use an approximate expression.  
		result=sum(likelihoods)
	endif
	return result
End

Function /wave d_binomial_logit(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the roots of the gradient function.  
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	variable observations=dimsize(xx,0)
	variable numCovariates=dimsize(xx,1)
	variable vars=max(1,dimsize(betas,1))
	variable yColumns=max(1,dimsize(betas,2))
	matrixop /free eta=xx x betas
	matrixop /free grad=xx^t x (yy + powR(1+exp(eta),-1) - 1)
	return grad
End

// L''
Function /wave d2_binomial_logit(xx,betas)
	wave xx,betas  
	
	variable observations=dimsize(xx,0)
	variable xColumns=dimsize(xx,1)
	variable yColumns=max(1,dimsize(betas,1))
	matrixop /free eta=xx x betas
	make /free/d/n=(observations,yColumns) multiplier=sqrt(1/(2*(1+cosh(eta))))
	make /free/d/n=(observations,xColumns,yColumns) matrix=xx[p][q] * multiplier[p][r]
	matrixop /free fisher=matrix^t x matrix
//	make /free/d/n=(xColumns,xColumns,yColumns) fisher
//	variable i
//	for(i=0;i<yColumns;i+=1)
//		matrixop /free matrix_=layer(matrix,i)
//		matrixop /free fisher_=(matrix_^t x matrix_)///numrows(xx) // Positive because the negative sign on the Hessian cancels with the negative 1 that we multiply to get a Fisher information matrix.  
//		fisher[][][i]=fisher_[p][q]
//	endfor
	return fisher
End

// ---------------- Multinomial distribution; Logistic (Gibbs) link function. -----------

// The following functions will either maximize the log likelihood, or find roots of the gradient of the log likelihood, according to the following set of equations:  
// Here mu is vector valued, with k probabilities for each of the k+1 possible values of y from 0 through k.  The probability for y=0 is the balance (i.e. 1 minus the rest).    
// So etai[0]=0, and etai[k]=bk0+bk1*x1i+..., where b00=0, b01=0, ...
L({y=k}|mu) = prodi{ (exp(etai[k])/sumk(exp(etai[k]))) } // The likelihood function for a multinomial distribution.  The sum here is over k different values of yi at a single i.  
ln(L) = sumi{ ln((exp(etai[k])/sumk(exp(etai[k])))) } // Log likelihood.  
       =  sumi{ etai[k] - ln(sumk(exp(etai[k]))) }
etaki = bk0+bk1*x1i+bk2*x2i+...
ln(L) = sumi{ (bk0+bk1*x1i+...) -ln(sumk(exp(bk0+bk1*x1i+...))) } // Plug in the glm equation with logit link ln(muk/(sum(muk)-muk)) = b0 + b1*x1 + b2*x2 + ..., where mu=E(y).    

grad(ln(L))=sumi{ yi==k - exp(etai[k])/sumk(exp(etai[k])) } // The gradient of the log likelihood.  The gradient will have a column with this form for each k.  
                 sumi{ x1i*(yi==k - exp(etai[k])/sumk(exp(etai[k]))) }
                 sumi{ x2i*(yi==k - exp(etai[k])/sumk(exp(etai[k]))) }
                ...
                
hessian(ln(L))[Ak1][Bk2] = -(k1==k2) ? sumi{ xAi*(sumk(exp(etai[k]))*xBi*exp(etai[k1]) - exp(etai[k1])*xBi*exp(etai[k2]))/(sumk(exp(etai[k]))^2) } : sumi{ xAi*(0 - exp(etai[k1])*xBi*exp(etai[k2]))/sumk(exp(etai[k]))^2
                			 = -(k1==k2) ? sumi{ xAi*xBi*exp(etai[k1])*(sumk(exp(etai[k])-exp(etai[k1]))/sumk(exp(etai[k]))^2 } : sumi{ -xAi*xBi*(exp(etai[k1])*exp(etai[k2])/sumk(exp(etai[k])))^2 }
							 = -sumi{ xAi*xBi*(k1==k2 ? c1/d - (c1/d)^2 : -c1c2/d^2) } where cN=exp(etai[kN]) and d=sumk(exp(etai[k]))

Function multinomial_logit(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the maximum.  
	
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	variable observations=dimsize(xx,0)
	variable vars=dimsize(betas,1)
	variable yColumns=max(1,dimsize(yy,1))
	// If the possible values for y are {0,1,2,...,k}, then betas will have k columns.  No column is required for y=0, because this will always give eta=0, exp(eta)=1.  
	matrixop /free eta=xx x betas
	insertpoints /m=1 0,1,eta
	eta[][0]=0
	duplicate /o eta,eta_
#if 0 // Gives more Infs.  
	make /free/d/n=(observations,vars+1,vars+1) etaMatrix=exp(eta[p][r]-eta[p][q])
	matrixop /free zz=powR(sumbeams(etaMatrix),-1) // Linear likelihoods, with one column for each possible yy value.  
	make /free/d/n=(observations,yColumns) likelihoods=ln(zz[p][yy[p][q]][q]) // Log likelihoods for each points.  
#else
	matrixop /free expEta=sumrows(exp(eta))
	make /free/d/n=(observations,yColumns) likelihoods = eta[p][yy[p][q]][q] - ln(expEta[p][0][q])
#endif
	duplicate /o likelihoods,likelihoods_
	variable result=sum(likelihoods)
	//duplicate /o likelihoods,likelihoods_
	//duplicate /o eta,eta_
	//duplicate /o expEta,expEta_
	//if(numtype(result)==1) // Infinity or -Infinity.  Probably results from exponentiating a very negative number.  
	//	likelihoods=numtype(likelihoods[p])==1 ? yy[p]*eta[p]-eta[p] : likelihoods[p] // Use an approximate expression.  
	//	result=sum(likelihoods)
	//endif
	return result
End

Function /wave d_multinomial_logit(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the roots of the gradient function.  
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	variable observations=dimsize(xx,0)
	variable numCovariates=dimsize(xx,1)
	variable yColumns=max(1,dimsize(yy,1))
	variable vars=max(1,dimsize(betas,1))
	variable i,j
	matrixop /free eta=xx x betas
	if(vars>1)
		matrixop /free expEta=colrepeat(sumrows(exp(eta))+1,vars)
	else
		matrixop /free expEta=sumrows(exp(eta))+1
	endif
	make /free/n=(observations,vars,yColumns) state=(yy[p][r]==(q+1))
	//duplicate /o state,state_
	//duplicate /o eta,eta_
	//duplicate /o expEta,expEta_
	//expEta=exp(eta-ln(expEta))
	//duplicate /o expEta,expEta_
	matrixop /free grad=xx^t x (-exp(eta-ln(expEta))+state) // The use of exp(ln(a)-ln(b)) in here instead of just a/b is to avoid NaNs from dividing large numbers.  
	return grad
End

// L''
// TODO: Set up to work correctly with multiple dependent variables (yColumns>1).  
Function /wave d2_multinomial_logit(xx,betas)
	wave xx,betas  
	
	wave yy=yy_
	variable observations=dimsize(xx,0)
	variable numCovariates=dimsize(xx,1)
	variable vars=max(1,dimsize(betas,1))
	variable yColumns=1//max(1,dimsize(yy,1))
	matrixop /free eta=xx x betas
	if(vars>1)
		matrixop /free expEta=colrepeat(sumrows(exp(eta))+1,vars)
	else
		matrixop /free expEta=sumrows(exp(eta))+1
	endif
	make /free/d/n=(observations,vars,yColumns) zz=exp(eta[p][q][r]-ln(expEta[p][0][r]))//exp(eta[p][q][r])/expEta[p][0][r]
#if 0 // Slow.  
	make /free/d/n=(numCovariates*vars,numCovariates*vars,observations) matrix=xx[r][mod(p,numCovariates)] * xx[r][mod(q,numCovariates)] * (((floor(p/numCovariates)==floor(q/numCovariates)) ? zz[r][floor(p/numCovariates)] : 0) - zz[r][floor(p/numCovariates)]*zz[r][floor(q/numCovariates)])
	matrixop /free fisher=sumbeams(matrix)
#else // Faster.  
	make /free/d/n=(numCovariates*vars,numCovariates*vars) fisher
	variable i,j
	for(i=0;i<vars;i+=1)
		for(j=0;j<vars;j+=1)
			if(i==j)
				make /free/c/d/n=(observations,numCovariates,yColumns) matrix=xx[p][q] * sqrt(zz[p][i][r] - zz[p][i][r]*zz[p][j][r])
			else
				make /free/c/d/n=(observations,numCovariates,yColumns) matrix=xx[p][q] * sqrt(-zz[p][i][r]*zz[p][j][r])
			endif
			matrixop /free fisher_=real(matrix^t x matrix)
			fisher[i*numCovariates,(i+1)*numCovariates-1][j*numCovariates,(j+1)*numCovariates-1]=fisher_[p-i*numCovariates][q-j*numCovariates]
		endfor
	endfor
#endif
	return fisher
End

// ---------------- Exponential distribution; Inverse link function. -----------

// The following functions will either maximize the log likelihood, or find roots of the gradient of the log likelihood, according to the following set of equations:  
L({y}|mu) = prod{ exp(-yi/mu)/mu } // The likelihood function for an exponential distribution.  
ln(L) =sum{ -yi/mu) - ln(mu) } // Log likelihood.  
ln(L) =sum{ -yi*(b0+b1*x1i+b2*x2i+...) + ln(b0+b1*x1+b2*x2+...))) } // Plug in the glm equation with inverse link 1/mu = b0 + b1*x1 + b2*x2 + ..., where mu=E(y).    
etai = 1/mu = b0+b1*x1i+b2*x2i+...
grad(ln(L))=sum{ -yi + etai) } // The gradient of the log likelihood.  
                sum{ x1i*(-yi + etai) }
                sum{ x2i*(-yi + etai) }
                ...
hessian(ln(L))=sum{ (-yi + etai) * ( 1         x1i         x2i            .... )
                            			  ( x1i      x1i^2      x1i*x2i       .... )
                            			  ( x2i      x1i*x2i    x2i^2          .... )
                                               ( ....                                          ) }   

Function exponential_inverse(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the maximum.  
	
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	//matrixop /free eta=xx x betas
	matrixop /free eta=clip(xx x betas,1e-10,inf) // Avoid negative domain.  
	make /free/n=(dimsize(eta,0)) likelihoods = -yy[p]*eta[p] + ln(eta[p])
	variable result=sum(likelihoods)
	return result
End

Function /wave d_exponential_inverse(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the roots of the gradient function.  
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	//variable observations=dimsize(xx,0)
	//variable numCovariates=dimsize(xx,1)
	//variable vars=max(1,dimsize(betas,1))
	//variable yColumns=max(1,dimsize(betas,2))
	//matrixop /free eta=xx x betas
	matrixop /free eta=clip(xx x betas,1e-10,inf) // Avoid negative domain.  
	matrixop /free grad=xx^t x (-yy + powR(eta,-1))
	return grad
End

// L''
Function /wave d2_exponential_inverse(xx,betas)
	wave xx,betas  
	
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	variable observations=dimsize(xx,0)
	variable xColumns=dimsize(xx,1)
	variable yColumns=max(1,dimsize(betas,1))
	//matrixop /free eta=xx x betas
	matrixop /free eta=clip(xx x betas,1e-10,inf) // Avoid negative domain.  
	make /free/d/n=(observations,yColumns) multiplier=1/eta//sqrt(eta^-2)
	make /free/d/n=(observations,xColumns,yColumns) matrix=xx[p][q] * multiplier[p][r]
	matrixop /free fisher=matrix^t x matrix
	return fisher
End

// ---------------- Von Mises distribution; Tangent link function. -----------

// The following functions will either maximize the log likelihood, or find roots of the gradient of the log likelihood, according to the following set of equations:  
L({yi}|mu) = prod{ exp(k*cos(yi-mu))/(2*pi*besseli(k) } // The likelihood function for a von Mises distribution.  
ln(L) =sum{ k*cos(yi-mu) - ln(2*pi)  - ln(besseli(k)) } // Log likelihood.  
ln(L) =sum{ k*cos(yi-2*atan(b0+b1*x1i+b2*x2i-...) -ln(2*pi) - ln(besseli(k)) } // Plug in the glm equation tan(mu/2) = b0 + b1*x1 + b2*x2 + ..., where mu=E(y).  We can drop k, ln(2*pi), and ln(besseli(k)) when maximizing.  
grad(ln(L))=sum{ -sin(yi-2*atan*(b0+b1*x1i+b2*x2i+...))/(1+(b0+b1*x1i+b2*x2i+...)^2) } // The gradient of the log likelihood, with constants taken outside of the summation and dropped since we will be setting equal to zero.  
                sum{ -x1i*sin(yi-2*atan*(b0+b1*x1i+b2*x2i+...))/(1+(b0+b1*x1i+b2*x2i+...)^2) }
                sum{ -x2i*sin(yi-2*atan*(b0+b1*x1i+b2*x2i+...))/(1+(b0+b1*x1i+b2*x2i+...)^2) }
                ...
hessian(ln(L)=...

Function vonmises_tangent(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the maximum.  
	
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	matrixop /free eta=xx x betas
	make /free/n=(numpnts(eta)) likelihoods = cos(yy[p]-2*atan(eta[p]))  
	return sum(likelihoods)
End

Function /wave d_vonmises_tangent(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the roots of the gradient function.  
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	variable observations=dimsize(xx,0)
	variable numCovariates=dimsize(xx,1)
	variable j
	matrixop /free eta=xx x betas
	make /free/n=(numCovariates) grad
	for(j=0;j<numCovariates;j+=1) // Over gradient dimensions.   
		make /free/n=(observations) result = -xx[p][j]*sin(yy[p] - 2*atan(eta[p]))/(1+eta[p]^2)
		grad[j]=sum(result)	
	endfor
	return grad
End

// L''
Function /wave d2_vonmises_tangent(xx,betas)
	wave xx,betas  
	
	matrixop /free fisher=0//exp(xx x betas)*synccorrelation(xx)*(varcols(xx) * varcols(xx)^t)
	return fisher
End

// ---------------- Poisson distribution; Logarithmic link function; one covariate is fit with a von Mises distribution. -----------

// The following functions will either maximize the log likelihood, or find roots of the gradient of the log likelihood, according to the following set of equations:  
L({yi}|mu) = prod{ exp(-mu)*mu^yi/yi! } // The likelihood function for a poisson distribution.  
ln(L) =sum{ -mu + yi*ln(mu) - ln(yi!) } // Log likelihood.  
ln(mu) = eta = xx x beta
eta = sum{ etai }
etai = b0 + b1*x1i + b2*x2i + ... + b10*vm(x10i,b11,b12)
ln(L) =sum{ -exp(eta) + yi*eta - ln(yi!) } // Plug in the glm equation ln(mu) = eta = sum(etai) = b0 + b1*x1 + b2*x2 + ..., where mu=E(y).  
grad(ln(L))=sum{ (-exp(eta) + yi) } // The gradient of the log likelihood.  
                sum{ x1i*(-exp(eta) + yi) }
                sum{ x2i*(-exp(eta) + yi) }
                ...
                sum{ vm(x10i,b11,b12)*(-exp(eta) + yi) } // d/db10 (von Mises amplitude)
                sum{ b10*sin(x10i-b11)*vm(x10i,b11,b12)*(-exp(eta) + yi) } // d/db11 (von Mises mean)
                sum{ b10*(cos(x10i-b11)-besseli(1,b12)/besseli(0,b12))*vm(x10i,b11,b12)*(-exp(eta) + yi) } // d/db12 (von Mises concentration)
hessian(ln(L))=...//sum{ -exp(eta) * ( 1         x1i         x2i            .... )
                            						            ( x1i      x1i^2      x1i*x2i     .... )
                            						            ( x2i      x1i*x2i    x2i^2       .... )
                                                                                         ( ....                                            ) }      

Function poisson_log_vm(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the maximum.  
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	matrixop /free xxBeta=xx x betas
	xxBeta = -exp(xxBeta[p]) + yy[p]*xxBeta[p] - ln(factorial(yy[p]))
	return sum(xxBeta)
End

Function /wave d_poisson_log_vm(xx,betas)
	wave xx // The numCovariates.  The first column [0] is ones, the rest [1,] are x values.  
	wave betas // The coefficients that will be adjusted to find the roots of the gradient function.  
	wave yy=yy_ // A global corresponding to observations.  I could have stuck this as a column in the xx wave, but then the indexing becomes non-intuitive.  
	
	variable observations=dimsize(xx,0)
	variable numCovariates=dimsize(xx,1)
	variable j
	matrixop /free xxBeta=xx x betas
	make /free/n=(numCovariates) grad
	for(j=0;j<numCovariates;j+=1) // Over gradient dimensions.   
		make /free/n=(observations) result = -xx[p][j]*exp(xxBeta[p]) + yy[p]*xx[p][j]  
		grad[j]=sum(result)	
	endfor
	return grad
End

// L''
Function /wave d2_poisson_log_vm(xx,betas)
	wave xx,betas  
	
	duplicate /free xx,matrix
	matrixop /free scalar=sqrt(exp(xx x betas))
	matrix*=scalar[p]
	matrixop /free fisher=(matrix^t x matrix)///numrows(xx) // Positive because the negative sign on the Hessian cancels with the negative 1 that we multiply to get a Fisher information matrix.  
	return fisher
End

// ----------------- Priors / Penalties ----------------

L1 normalization
Laplacian prior distribution
x = Fit parameters (betas)
mu = Location parameter
b = Scale parameter
L({x}|mu,b) = (1/2b)*exp(-abs(x-mu)/b)
ln(L) = -ln(2b)-abs(x-mu)/b
dln(L)/dx = x-mu ==0 ? 0 : -sign(x-mu)/b
d2ln(x)/dx2 = 0 (Set to 1 to avoid having to invert a matrix of zeroes).  

// Compute log likelihood for model parameters 'betas' given prior Laplacian distribution with parameters 'param'.  
function L1norm(betas,params)
	wave betas
	wave /wave params // Parameters for the prior distribution.  
	
	wave mu=params[0]
	wave b=params[1]
	
	variable numCovariates=dimsize(betas,0)
	variable vars=max(1,dimsize(betas,1))
	variable yColumns=max(1,dimsize(betas,2))
	redimension /e=1/n=(numCovariates*vars,1,yColumns) betas,mu
	matrixop /free likelihood=-(inv(b) x abs(betas-mu)))
	redimension /e=1/n=(numCovariates,vars,yColumns) betas,mu
	matrixop /free meann=mean(abs(b)) // Condition the b matrix to avoid very small or very large determinants.  
	//matrixop /free normalization=ln(2*abs(det(b))) // Second term corrects for the division by meann[0] in the first term.  All of this is for numerical stability.  
	matrixop /free normalization=ln(2*abs(det(b/meann[0])))+numcols(b)*ln(meann[0]) // Second term corrects for the division by meann[0] in the first term.  All of this is for numerical stability.  
	likelihood-=normalization[q]
	return sum(likelihood)
end

function /wave d_L1norm(betas,params)
	wave betas
	wave /wave params // Parameters for the prior distribution.  
	
	wave mu=params[0]
	wave b=params[1]
	variable numCovariates=dimsize(betas,0)
	variable vars=max(1,dimsize(betas,1))
	variable yColumns=max(1,dimsize(betas,2))
	redimension /e=1/n=(numCovariates*vars,1,yColumns) betas,mu
	matrixop /free grad=inv(b) x sgn(mu-betas)
	redimension /e=1/n=(numCovariates,vars,yColumns) betas,mu,grad
	return grad
end

function /wave d2_L1norm(betas,params)
	wave betas
	wave /wave params // Parameters for the prior distribution.  
	
	wave mu=params[0]
	wave b=params[1]
	variable numCovariates=dimsize(betas,0)
	variable vars=max(1,dimsize(betas,1))
	variable yColumns=max(1,dimsize(betas,2))
	make /free/n=(numCovariates*vars,numCovariates*vars,yColumns) fish=0
	//matrixop /free fish=0//identity(numpnts(b)) // Really it is zero, but I don't want to deal with inverting a zero matrix.  
	return fish
end

L2 normalization
Gaussian prior distribution
B = Fit parameters (betas)
mu = Prior mean_ of betas
sigma2 = Prior uncertainty (variance_) of betas
L({B}|mu,sigma2) = prod(1/sqrt(2*pi*sigma2))*prod{ exp(-(B-mu)^2/sigma2) } // The prior likelihood of the betas given prior mean mu and prior covariance sigma2.    
ln(L) = sum(ln(1/sqrt(2*pi*sigma2))-(B-mu)^2/sigma2 = sum(-ln(2*pi*sigma2)/2 - (B-mu)^2/sigma2)
grad(ln(L)) = [ 2*(B1-mu)/sigma2
                     2*(B2-mu)/sigma2
                     ... ]
hessian(ln(L)) = [ 2/sigma2   2/sigma2   .... 
                         2/sigma2   2/sigma2   ....
                         2/sigma2   2/sigma2   .... ]

function L2Norm(betas,params)
	wave betas
	wave /wave params
	
	wave mu=params[0] // Prior means.  
	wave sigma2=params[1] // Prior covariance.  
	
	variable numCovariates=dimsize(betas,0)
	variable vars=max(1,dimsize(betas,1))
	variable yColumns=max(1,dimsize(betas,2))
	redimension /e=1/n=(numCovariates*vars,1,yColumns) betas,mu
	matrixop /free prior=-powR(chol(inv(sigma2)) x (betas-mu),2)  // Log-Likelihood function for a normal distribution with mean mu and covariance sigma2.  
	
	redimension /e=1/n=(numCovariates,vars,yColumns) betas,mu
	matrixop /free normalization=ln(2*pi*abs(det(sigma2)))/2
	prior-=normalization[q]
	return sum(prior)
end

function /wave d_L2Norm(betas,params)
	wave betas
	wave /wave params
	
	wave mu=params[0] // Prior means.  
	wave sigma2=params[1] // Prior covariance.  
	variable numCovariates=dimsize(betas,0)
	variable vars=max(1,dimsize(betas,1))
	variable yColumns=max(1,dimsize(betas,2))
	redimension /e=1/n=(numCovariates*vars,1,yColumns) betas,mu
	matrixop /free grad=-2*inv(sigma2) x (betas-mu)
	redimension /e=1/n=(numCovariates,vars,yColumns) betas,mu,grad
	return grad
end

function /wave d2_L2Norm(betas,params)
	wave betas
	wave /wave params
	
	wave mu=params[0] // Prior means.  
	wave sigma2=params[1] // Prior covariance.  

	matrixop /free fisher=2*inv(sigma2) // Positive because the negative sign on the Hessian cancels with the negative 1 that we multiply to get a Fisher information matrix.  
	return fisher
end

// ----------------- Fit Quality --------------------------

function AIC(logLikelihood,xx,betas)
	variable logLikelihood
	wave xx,betas
	
	variable k=numpnts(betas)
	return 2*k - 2*logLikelihood
end

function BIC(logLikelihood,xx,betas)
	variable logLikelihood
	wave xx,betas
	
	variable k=numpnts(betas)
	variable n=dimsize(xx,0)
	return -2*logLikelihood + k*ln(n)
end

// ----------------- IRLS functions --------------------

function /wave IRLS(yy,xx,betas,link,distribution[,prior,priorParams,tolerance,maxIters,maxStepSize,quiet])
	wave yy // Outcomes vector; size = numObservations.  
	wave xx // Covariate matrix; size = numObservations x numnumCovariates
	wave betas // Initial guesses for coefficients; size = numnumCovariates.  
	string link // Link function.  
	string distribution // Distribution determining the likeihood function.  
	variable maxIters,maxStepSize,tolerance,quiet
	funcref L2Norm prior
	wave /wave priorParams
	
	maxIters=paramisdefault(maxIters) ? 1000 : maxIters
	tolerance=paramisdefault(tolerance) ? 0.0001 : tolerance
	variable numObservations=dimsize(yy,0)
	variable numnumCovariates=dimsize(xx,1)
	variable yColumns=max(1,dimsize(yy,1))
	variable vars=dimsize(betas,1)
	duplicate /o yy,yy_ // Temporarily needed for checking likelihood.  
	
	string likelihoodName=distribution+"_"+link
	string scoreName="d_"+likelihoodName
	string fisherName="d2_"+likelihoodName
	funcref gaussian_identity likelihood=$likelihoodName
	funcref d_gaussian_identity score=$scoreName
	funcref d2_gaussian_identity fisher=$fisherName
	if(!paramisdefault(prior))
		string priorFunc=StringByKey("NAME",FuncRefInfo(prior))
		if(strlen(priorFunc))
			variable usePrior=1
			funcref d_L2norm priorScore=$("d_"+priorFunc)
			funcref d2_L2norm priorFisher=$("d2_"+priorFunc)
		endif	
	endif
	
	variable iteration=0,deviance=Inf,startMaxStepSize=maxStepSize,newLikelihood=-Inf,entry=0,netDeviance=0,flag=0
	do
		Prog("Iteration",iteration,Inf)
		//printf "Iteration: %d\r",iteration
		variable oldDeviance=deviance
		duplicate /free/d betas oldBetas
		variable oldLikelihood=likelihood(xx,oldBetas)
		if(abs(oldLikelihood) > 1e20)
			//duplicate /o oldBetas,test_betas
			//duplicate /o xx,test_xx
			//abort
		endif
		wave fish=fisher(xx,betas)
		wave grad=score(xx,betas)
		if(usePrior)
			variable priorLike=prior(betas,priorParams)
			wave priorGrad=priorScore(betas,priorParams)
			wave priorFish=priorFisher(betas,priorParams)
			oldLikelihood+=priorLike
			grad+=priorGrad
			fish+=priorFish
			//fish+=(p==q) ? 0.1 : 0
		endif
		redimension /e=1/n=(numnumCovariates*vars) grad
		if(flag) // Use method of 1-dimensional gradients, trying a different dimension each time.  
			//abort
			matrixop /free diffBetas=grad
//			make /free/n=(numpnts(betas)) manhattanDeviances=0
//			for(entry=0;entry<numpnts(betas);entry+=1)
//				matrixop /free newBetas=oldBetas
//				newBetas[entry]+=diffBetas[entry]/10
//				variable provisionalLikelihood=likelihood(xx,newBetas) // True likelihood after a move of 'diffBetas'.  
//				if(usePrior)
//					provisionalLikelihood+=prior(newBetas,priorParams)
//				endif
//				manhattanDeviances[entry]=provisionalLikelihood-oldLikelihood
//			endfor
//			wavestats /q/m=1 manhattanDeviances
			diffBetas=0
//			diffBetas[v_maxloc]=grad[v_maxloc]
			diffBetas[entry]=grad[entry]
			//wavestats /q/m=1 diffBetas
		else // Use Newton's method.  
			matrixop /free diffBetas=inv(fish) x grad
		endif
		redimension /e=1/n=(numnumCovariates,vars) grad,diffBetas
		if(0)
			wavestats /q/m=1 diffBetas
			variable extremum=max(v_max,-v_min)
			if(extremum>maxStepSize)
				diffBetas*=(maxStepSize/extremum)
			endif
		elseif(numtype(maxStepSize)==0)
			diffBetas=limit(diffBetas[p][q][r],-maxStepSize,maxStepSize)
		endif
		
		if(numtype(sum(diffBetas)))
			variable fishDet=matrixdet(fish)
			if(fishDet==0)
				printf "Encountered a singular Hessian matrix during an update to the coefficients.\r"
				duplicate /o fish,fish_
				matrixop /free xxSums=sumcols(xx)^t // Compute the column sums of the data matrix. 
				extract /free/indx xxSums,xxSumsZero,xxSums==0 // Find the indices corresponding to columns whose sums are zero.   
				variable i
				printf "Setting data columns "
				for(i=0;i<numpnts(xxSumsZero);i+=1)
					xx[][xxSumsZero[i]]=gnoise(0.01) // Set this data column to random values.   
					printf "%s%d",selectstring(i==0,",",""),xxSumsZero[i]
				endfor
				printf " to random (instead of zero).\r"
				matrixop /free fishSums=sumcols(fish)^t // Compute the column sums of the Fisher matrix.  
				extract /free/indx fishSums,fishSumsZero,fishSums==0 // Find the indices corresponding to columns whose sums are zero.  
				printf "Setting beta indices "
				for(i=0;i<numpnts(fishSumsZero);i+=1)
					betas[fishSumsZero[i]]=0 // Set the beta corresponding to each zero-sum Fisher column to zero.  
					printf "%s%d",selectstring(i==0,",",""),fishSumsZero[i]
				endfor
				printf " to zero.\r"
				continue // Try again with these new betas.  
			elseif(numtype(sum(xx))==2) // Don't know why, but sometimes xx values get randomly replaced with NaNs.  
				xx=numtype(xx[p][q])==2 ? 0 : xx[p][q]
				continue // Try again with xx fixed.  
			else
				wavestats /q/m=1 diffBetas
				if(v_npnts) // Not all NaNs.  
					printf "%d out of %d of the points in the vector to update the betas contained NaNs.  Zeroing these.\r",v_numnans,numpnts(diffBetas)
					diffBetas=numtype(diffBetas)==2 ? 0 : diffBetas[p][q][r]
				else
					printf "Encountered a vector of NaNs in the update to the coefficients.\r"
					duplicate /o diffBetas diffBetas_
					duplicate /o fish fish_
					duplicate /o grad grad_
					duplicate /o betas betas_
					abort
					break
				endif
			endif
		endif
		iteration+=1
		
		// Back-tracking line search (Convex Optimization, Boyd and Vandenberghe, p. 465).  
		variable alpha=0.25, beta_=0.5, backTracks=0
		do
			matrixop /free newBetas=oldBetas+diffBetas
			variable provisionalLikelihood=likelihood(xx,newBetas) // True likelihood after a move of 'diffBetas'.  
			if(usePrior)
				provisionalLikelihood+=prior(newBetas,priorParams)
			endif
			matrixop /free lineSearchLikelihood=oldLikelihood+alpha*sum(grad * diffBetas)//(grad^t x diffBetas) // Linearly extrapolated likelihood after a move of 'diffBetas'.  The delta from the old likelihood is modulated by a fraction 'alpha'.  
			if((provisionalLikelihood>=sum(lineSearchLikelihood)) || 0*(provisionalLikelihood>newLikelihood))
				break
			else
				//Prog("Backtracks",backTracks,Inf)
				diffBetas*=beta_
				backTracks+=1
				if(backTracks==1000) // If we have to backtrack this many times, the Fisher matrix is probably close to singular and is no longer a useful guide.  
					break
				endif
				//printf "\tBacktracks: %d\r",backTracks
			endif
		while(1)
		if(backTracks<1000) // If we had to backtrack more than 1000 times, the update probably isn't a very good one.  
			betas=oldBetas+diffBetas
			//continue
		endif
		newLikelihood=likelihood(xx,betas)
		if(usePrior)
			newLikelihood+=prior(betas,priorParams)
		endif
		deviance=2*(newLikelihood-oldLikelihood)
		if(deviance<0) // We jumped too far.  
			maxStepSize/=10
		else
			maxStepSize+=(startMaxStepSize-maxStepSize)/10
		endif
		if(0 && !flag && deviance<tolerance) // If Newton's method is no longer useful (very near the solution).  
			flag=1 // Switch to Manhattan gradient descent.  
			netDeviance=0 // Set the deviance for descent over all successive dimensions to zero.  
			entry=0 // Start with dimension zero to step along.  
			continue
		elseif(flag) // If using Manhattan gradient descient.  
			netDeviance+=deviance // Note any change in the deviance since 
			if(deviance<tolerance)
				entry+=1 // Move on to the next dimension.  
			endif
			entry=mod(entry,numpnts(diffBetas)) // If all the dimension's have been used, start at dimension zero again.  
			if(entry==0) // If we are on dimension zero.  
				if(netDeviance<tolerance) // And the net deviance over all dimensions is too small.  
					break // Then we are done.  
				else
					netDeviance=0 // Otherwise, set the net deviance to zero and start through the dimensions again.  
				endif
			endif
		endif
	while((iteration<maxIters && deviance>tolerance) || flag) // Break on maximum iterations reached or small deviance.  
	
	if(!quiet)
		printf "After %d iterations, reached log-likelihood of %.3f.\r",iteration,newLikelihood
	endif
	//killwaves /z yy_
	return betas
end

// Weighted least squares.  
function /wave WLS(yy,xx,weights)
	wave yy,xx,weights
	
	variable numObservations=dimsize(yy,0)
	variable numnumCovariates=dimsize(xx,1)
	make /free/n=(numObservations,numnumCovariates) wxx=weights[p]*xx[p][q]
	matrixop /free result=inv(xx^t x wxx) x xx^t x (weights * yy)
	//matrixop /free result=inv(xx^t x diagonal(weights) x xx) x xx^t x diagonal(weights) x yy
	return result
end

// -------------- Spline functions ---------------------

//function /wave SplineCoefs(order,tKnots,xx,xxCol,betas,betasCol)
//	variable order // Order of the polynomial used to fit each spline.  
//	wave tKnots // Wave of knot times.  
//	wave xx // Wave of independent variables.  Each column contains one variable, and each row is an observation.  
//	variable xxCol // Column number in wave 'xx' which contains the linear variable.  
//	wave betas // Complete list of coeficients.  This function returns a subset of this list applicable to each observation, depending on the spline it belongs to.  
//	variable betasCol // Column number in wave 'betas' which contains the constant coefficient for the first spline.  
//	
//	make /free/wave/n=(dimsize(xx,0)) betaSelector // An wave of references to beta waves.  The ith reference will indicate the appropriate betas to use for the ith observation.  
//	variable i,knots=numpnts(tKnots)
//	make /free/wave/n=(knots-1) betaSelections
//	duplicate /free/r=[betasCol,betasCol+2*knots-1] betas,knotBetas
//	switch(order)
//		case 3: // Cubic polynomial.  
//			variable b0=knotBetas[0]
//			variable b1=knotBetas[1]
//			variable b2=knotBetas[2]
//			variable b3=knotBetas[3]
//			i=0
//			do
//				make /free/n=(order+1) newBetas={b0,b1,b2,b3}
//				betaSelections[i]=knotBetas
//				i+=1
//				if(i>=knots-1)
//					break
//				else
//					variable dt=tKnots[i]-tKnots[i-1]
//					b0=b0+b1*(dt)+b2*(dt)^2+b3*(dt)^3
//					b1=b1+2*b2*(dt)+3*b3*(dt)^2
//					b2=knotBetas[order+1+2*(i-1)]
//					b3=knotBetas[order+2+2*(i-1)]
//				endif
//			while(1)
//			break
//	endswitch
//	matrixop /free parameter=col(betas,betasCol)
//	make /free/n=(dimsize(xx,0)) knotIndex=binarysearch(tKnots,parameter[p])
//	betaSelector = betaSelections[knotIndex[p]] // There is no checking here to see if we the knotIndex is < 0 (i.e. before the first or after the last knot), because Igor doesn't support conditional assignment with 
//											// wave reference waves.  So checking will have to be done in the calling function to be sure that likelihoods for values outside the knot boundaries evaluate to
//											// 0 or 1 or whatever.  
//	return betaSelector
//end

function SplineCoefs2(order,diff,tt,Tx,k,n,power,i)
	variable order,diff
	variable tt // Current value of the splined variable, e.g. trial time.  
	variable Tx // Max value, i.e. modulus of the periodic domain.  
	wave k // Knot locations.    
	variable n // Spline index for this coefficient.  
	variable power // To which power in a spline n to apply this result.   
	variable i // The value tt belongs to spline i.  
	
	variable last = numpnts(k)-1
	make /free/n=(numpnts(k)) t_ = tt - k[p]
	switch(order)
		case 2:
			switch(diff)
				case 0:
					if(i == last)
						t_ += tt<k[0] ? Tx : 0
						switch(power)
							case 0:
								variable value = 1
								break
							case 1:
								value = (Tx-t_[0])*(t_[n]-t_[i])/(Tx-t_[0]+t_[i])
								break
							case 2:
								value = (Tx-t_[0])*(t_[n]^2-(Tx-t_[0]+2*t_[n])*t_[i])/(Tx-t_[0]+t_[i])
								break
						endswitch
					else
						value = n<=i ? (t_[n])^power : 0
					endif
					break
				case 1:
					switch(i)
						default:
							t_ += tt<k[0] ? Tx : 0
							switch(power)
								case 0: 
									value = 1
									break
								case 2:
									value = -Tx*t_[0]*t_[n] + t_[0]^2*t_[n] - t_[0]*t_[n]^2
									if(n<=i)
										value += Tx*t_[n]^2
									endif
									value /= 	Tx
									break
								default:
									value = NaN // This is an error condition.  
							endswitch
					endswitch
					break
			endswitch
			break
		case 3:
			switch(diff)
				case 0:
					if(i == last)
						t_ += tt<k[0] ? Tx : 0
						switch(power)
							case 0:
								value = 1
								break
							case 1:
								value = (Tx-t_[0])*(t_[n]-t_[i])/(Tx-t_[0]+t_[i])
								break
							case 2:
								value = (Tx-t_[0])*(t_[n]^2-(Tx-t_[0]+2*t_[n])*t_[i])/(Tx-t_[0]+t_[i])
								break
							case 3:
								value = (Tx-t_[0])*(t_[n]^3-(Tx-t_[0])^2*t_[i]-3*t_[n]*(Tx-t_[0]+t_[n])*t_[i])/(Tx-t_[0]+t_[i])
								break
						endswitch
					else
						value = n<=i ? (t_[n])^power : 0
					endif
					break
				case 1:
					if(i == last)
						t_ += tt<k[0] ? Tx : 0
						switch(power)
							case 0:
								value = 1
								break
							case 1:
								value = t_[0] - Tx*t_[i]^2*(3*Tx-3*t_[0]+t_[i])/(Tx-t_[0]+t_[i])^3
								break
							case 2:
								value = ((Tx-t_[0])^2*(t_[n]-t_[i])*((3*t_[n]-t_[i])*t_[i]+Tx*(t_[n]+t_[i])-t_[0]*(t_[n]+t_[i])))/(Tx-t_[0]+t_[i])^3
								break
							case 3:
								value = ((Tx-t_[0])^2*(t_[n]-t_[i])^2*(3*t_[n]*t_[i] + Tx*(t_[n]+2*t_[i]) - t_[0]*(t_[n]+2*t_[i])))/(Tx-t_[0]+t_[i])^3
								break
						endswitch
					else
						value = n<=i ? (t_[n])^power : 0
					endif
					break
				case 2:
					switch(i)
						default:
							t_ += tt<k[0] ? Tx : 0
							switch(power)
								case 0: 
									value = 1
									break
								case 3:
									value = Tx^2*t_[0]^2 - 2*Tx*t_[0]^3 + t_[0]^4 - Tx^2*t_[0]*t_[n] + 3*Tx*t_[0]^2*t_[n] - 2*t_[0]^3*t_[n] - 3*Tx*t_[0]*t_[n]^2 + 3*t_[0]^2*t_[n]^2 - 2*t_[0]*t_[n]^3
									if(n<=i)
										value += 2*Tx*t_[n]^3
									endif
									value /= 2*Tx
									break
								default:
									value = NaN // This is an error condition.  
							endswitch
					endswitch
					break
			endswitch
			break
	endswitch
	return value
end

function /wave SplineCoefs(splines,betas)
	wave splines // See documentation in GLMFit().  
	wave betas // Complete list of independent coeficients.  This function returns a larger list which contains coefficients which are linear combinations of others, for the purpose of achieving the dimensionality of the data.    
	
	variable order=splines[0]
	variable diff=splines[1]
	variable col=splines[2]
	//variable modulus=splines[3]
	variable circular=splines[4] // First spline knot and last spline knot represent the same point in time.  
	make /free/n=(numpnts(splines)-5) knots=splines[5+p]
	variable i,j,numKnots=numpnts(knots)
	duplicate /free betas,newBetas
	insertpoints col,(diff+1)*(numKnots-2+circular),newBetas
	make /free/d/n=(order+1) b
	for(j=0;j<=order;j+=1)
		b[j]=betas[col+j]
	endfor	
	i=0
//	if(1)
		do
			variable index=col+(order+1)*i // Index of the first newBeta of the ith spline.  
			newBetas[index,index+order]=b[p-index] // Set the newBetas to the b's either initialized above (for i=0) or computed below.  
			i+=1
			if(i>=numKnots-1) // If we have gone through all the splines, break out.  
				break	
			else // Compute the coefficients for the next spline, based on the betas.  
				make /free/d/n=(order+1) dtp=p==0 ? 1 : (knots[i]-knots[i-1])^p // Powers of the time between this knot and the previous one.  
				if(diff>=0)
					b[0]=matrixdot(b,dtp) // Set the constant term for this spline to be equal to the value of the polynomial for the last spline evaluated at this knot.  
				endif
				if(diff>=1)
					make /free/d/n=(order) slope=b[p+1]*dtp[p]*(p+1) // Set up the RHS of the equation for setting slopes to be equal at the knot.  This is the first derivative of the polynomial.  
					b[1]=sum(slope) // Set the linear term for this spline to be equal to the value of that first derivative.  
				endif
				if(diff>=2)
					make /free/d/n=(order-1) curvature=b[p+2]*dtp[p]*(p+1)*(p+2) // Set up the RHS of the equation for setting curvatures to be equal at the knot.  This is the second derivative of the polynomial.  
					b[2]=sum(curvature)
				endif
				if(circular && i==numKnots-2) // Last spline, must make continuous on its right edge with the first spline's left edge (i.e. they share a knot).  So redo some of the b's.  
					b[diff+1,order]=betas[col+order+1+p-(diff+1)-1+(i-1)*(order-diff)] // Set the remaining terms to be equal to the corresponding betas, which are independent of the previous splines.   // Provisionally set the remaining terms to be equal to the corresponding betas, which are independent of the previous splines.  
					make /free/d/n=(order+1) dtp=p==0 ? 1 : (knots[i+1]-knots[i])^p // Powers of the time between this knot and the final one. 
					switch(order)
						case 0:
							b[0]=betas[col]
							break
						case 1:
							switch(diff)
								case 0:
									b[1]=(betas[col]-b[0])/dtp[1]
									break
							endswitch
							break
						case 2:
							switch(diff)
								case 0:
									b[1]=(betas[col]-b[0]-b[2]*dtp[2])/dtp[1]
									break
								case 1:
									b[2]=(betas[col+1]*dtp[1]-betas[col]+b[0])/dtp[2]
									break
							endswitch
							break
						case 3:
							switch(diff)
								case 0:
									b[1]=(betas[col]-b[0]-b[2]*dtp[2]-b[3]*dtp[3])/dtp[1]
									break
								case 1:
									b[2]=(3*betas[col]-betas[col+1]*dtp[1]-3*b[0]-2*b[1]*dtp[1])/dtp[2]
									b[3]=(2*b[0]+b[1]*dtp[1]-2*betas[col]+betas[col+1]*dtp[1])/dtp[3]
									break
							endswitch
							break
					endswitch
				else
					b[diff+1,order]=betas[col+order+1+p-(diff+1)+(i-1)*(order-diff)] // Set the remaining terms to be equal to the corresponding betas, which are independent of the previous splines.  
				endif
			endif
		while(1)
//	else
//		switch(order)
//			case 2: // Quadratic polynomial.  
//				b[0]=betas[col]
//				b[1]=betas[col+1]
//				b[2]=betas[col+2]
//				i=0
//				do
//					newBetas[3*i]=b[0]
//					newBetas[3*i+1]=b[1]
//					newBetas[3*i+2]=b[2]
//					i+=1
//					if(i>=numKnots-1)
//						break
//					else
//						variable dt=knots[i]-knots[i-1]
//						b[0]=b[0]+b[1]*(dt)+b[2]*(dt)^2
//						b[1]=b[1]+2*b[2]*(dt)
//						b[2]=betas[col+order+1+2*(i-1)]
//					endif
//				while(1)
//				break
//			case 3: // Cubic polynomial.  
//				b[0]=betas[col]
//				b[1]=betas[col+1]
//				b[2]=betas[col+2]
//				b[3]=betas[col+3]
//				i=0
//				do
//					newBetas[4*i]=b[0]
//					newBetas[4*i+1]=b[1]
//					newBetas[4*i+2]=b[2]
//					newBetas[4*i+3]=b[3]
//					i+=1
//					if(i>=numKnots-1)
//						break
//					else
//						dt=knots[i]-knots[i-1]
//						b[0]=b[0]+b[1]*(dt)+b[2]*(dt)^2+b[3]*(dt)^3
//						b[1]=b[1]+2*b[2]*(dt)+3*b[3]*(dt)^2
//						b[2]=betas[col+order+1+2*(i-1)]
//						b[3]=betas[col+order+2+2*(i-1)]
//					endif
//				while(1)
//				break
//		endswitch
//	endif
	return newBetas
end

// -------------- Basis functions ---------------------

Function /wave basisFuncProto(w)
	wave w
End

Function /wave circularBasis(w)
	wave w
	
	make /free/n=(dimsize(w,0),2) w_basis
	w_basis[][0]=cos(w[p])
	w_basis[][1]=sin(w[p])
	return w_basis
End

// --------------- Fit functions -------------------------

Function fitFuncProto(w,x)
	wave w
	variable x
End

// -------------- Auxiliary functions -----------------

static Function /wave Col(w,i)
	wave w
	variable i
	
	matrixop /free col_=col(w,i)
	return col_
End

static Function ColMax(w,i)
	wave w
	variable i
	
	duplicate /free/r=[][i,i] w,col_i
	wavestats /q/m=1 col_i
	return v_max
end

static function product(w)
	wave w
	
	matrixop /free result=exp(sum(ln(w))
	return result[0]
end

function DecimalHash(str,digits)
	string str
	variable digits
	
	string hex=hash(str,1)[0,digits-1]
	variable dec
	sscanf hex,"%x",dec
	return dec
end

// Stirling's approximation of ln(n!) for large n.  
threadsafe function Stirling(n)
	variable n
	
	return 0.5*ln(2*pi*n) + n*ln(n) - n
end

//// The non mean-subtracted, non normalized correlation matrix of the columns of xx.  
//static function /wave correlationMatrix(xx)
//	wave xx // A 2D wave with m rows and n columns.  
//	
//	matrixop /free result=numrows(xx) * synccorrelation(xx) * (varcols(xx)^t x varcols(xx)) // A 2D wave that is n x n.  
//	return result
//end

// Return the mean and standard deviation of the fit evaluated at one point (for 1D betas waves).  
function /c fitMeanSEM(betas,fisher,link,data)
	wave betas,fisher
	wave data // A single observation of the covariates.  
	string link
	
	variable i,iters=10000,numCovariates=dimsize(betas,0)
	matrixop /free cov = inv(fisher)
	wave noises = MakeCorrelatedNoises(iters,cov)
	make /free/n=(iters) mus
	for(i=0;i<iters;i+=1)
		make /free/n=(numCovariates) noisyBetas = betas[p]+noises[i][p]
		matrixop /free eta = noisyBetas[p] . data
		strswitch(link)
			case "identity":
				mus[i] = eta[0]
				break
			case "log":
				mus[i] = exp(eta[0])
				break
			case "logit":
				mus[i] = 1/(1+exp(-eta[0]))
				break
			case "inverse":
				mus[i]=1/eta[0]
				break
			case "tan":
				mus[i]=2*atan(eta[0])
				break
			default:
				printf "No such link function %s.  Exiting.\r",link
				return -1
		endswitch
	endfor
	//mus = 10^mus // Remove this.  
	wavestats /q mus
	print statsmedian(mus)
	return cmplx(v_avg,v_sdev)
end

// -------------- Testing ----------------

// Should print something close to {0.1,0.2,-0.3}
Function TestGLMFit(num)
	variable num
	variable i
	make /o/n=(100,3) test
	for(i=0;i<numpnts(test);i+=1)
		prog("Test",i,numpnts(test))
		make /o/n=(num) xx1=gnoise(1),xx2=gnoise(1),yy=poissonnoise(exp(0.1+0.2*xx1[p]-0.3*xx2[p]+gnoise(0.1)))
		glmfit(yy,{xx1,xx2},"poisson",quiet=1)
		wave betas
		test[i][]=betas[q]
		//test[i]=GLMFit(0,stepMethod=num)
	endfor
	matrixop /free result = meancols(test)
	print result
End

//#if !exists("prog")
//// Download 'Progress Window.ipf' to get the real progress window function.  
//override function prog(name,num,denom[,msg,parent])
//	string name,msg,parent
//	variable num,denom
//end
//#endif
//
//#if !exists("MakeCorrelatedNoises")
//// This also exists in 'Statistics.ipf".  
//override function /WAVE MakeCorrelatedNoises(numPoints,cov)
//	variable numPoints // The number of signals/repetitions/trials.  
//	wave cov // Covariance matrix. 
//	
//	variable numNoises=dimsize(cov,0)
//	make /free/n=(numNoises,numPoints) gaussNoise=gnoise(1)
//	matrixop /free CorrelatedNoises = (chol(cov)^t x gaussNoise)^t
//	return CorrelatedNoises
//end
//#endif