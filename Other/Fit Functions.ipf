// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Fit%20Functions.ipf $
// $Author: rick $
// $Rev: 606 $
// $Date: 2012-04-24 22:40:38 -0400 (Tue, 24 Apr 2012) $

#pragma rtGlobals=1		// Use modern global access method.

// ----------------------------- Maximum Likelihood Estimation ------------------------------------ //

function /wave MaximumLikelihood(distFunc,data[,guess])
	funcref PoissonMLE distFunc
	wave data,guess
	
	if(!paramisdefault(guess))
		make /o/n=(numpnts(guess)) coefs=guess[p]
	else
		string name = stringbykey("NAME",funcrefinfo(distFunc))
		strswitch(name)
			case "GammaMLE":
				make /o/n=3 coefs = {0,1,1}
				break
			default:
				make /o/n=3 coefs=abs(enoise(10))
		endswitch
	endif
	Optimize /A=1/M={2,1}/Q/X=coefs distFunc,data
	return coefs
end

function PoissonMLE(data,coefs)
	wave data,coefs
	
	variable mu = coefs[0]
	make /free/n=(numpnts(data)) logLikelihood = data*ln(mu) - mu- ln(factorial(data))
	return sum(logLikelihood)
end

function GammaMLE(data,coefs)
	wave data,coefs
	
	variable offset = coefs[0]
	variable scale = coefs[1]
	variable shape = coefs[2]
	make /free/n=(numpnts(data)) logLikelihood = log(StatsGammaPDF(data[p], offset, scale, shape))
	variable logL = sum(logLikelihood)
	return logL
end

// ------------------------------ Maximum Likelihood Curve Fitting --------------------------------- //

function /wave MaximumLikelihoodFit(fitFunc,distFunc,data[,guess])
	string fitFunc
	funcref PoissonFit distFunc
	wave data,guess
	
	string /g fitFunc_=fitFunc
	make /o/n=3 coefs=paramisdefault(guess) ? abs(enoise(10)) : guess[p]
	Optimize /A=1/M={2,1}/Q/X=coefs distFunc,data
	return coefs
end

function PoissonFit(data,coefs)
	wave data,coefs
	
	svar fitFunc_
	funcref FitLog func=$fitFunc_
	duplicate /o data,prediction
	prediction = func(coefs,x)
	//make /free/n=(numpnts(data)) likelihood_ = (prediction^data)*exp(-prediction)/factorial(data)
	make /free/n=(numpnts(data)) logLikelihood = data*ln(prediction) - prediction - ln(factorial(data))
	return sum(logLikelihood)
end

function BinomialFit(data,coefs)
	wave data,coefs
	
	svar fitFunc_
	funcref FitLog func=$fitFunc_
	duplicate /o data,prediction
	prediction = func(coefs,x)
	make /free/n=(numpnts(data)) logLikelihood = ln(StatsBinomialPDF(data[p], prediction[p], 4))
	return sum(logLikelihood)
end

// ------------- Curve Fitting Functions ----------------- //

function Logistic(w,x) : FitFunc
	wave w; variable x
	
	return 1/(1+exp(-(x-w[0])/w[1]))
end

Function FitLog(w,x): FitFunc
	Wave w; Variable x
	return w[0]+w[1]*log(x)
End

Function FitCumulPowerLaw(w,x) : FitFunc
	Wave w; Variable x
	//return w[2]*((x+w[0])^w[1])
	return w[2]+((x+w[0])^w[1])
End

Function FitGammaPDF(w,x) : FitFunc
	wave w; variable x
	return w[2]*StatsGammaPDF(x,0,w[0],w[1])
End

function FitLogGammaPDF(w,x) : FitFunc
	wave w; variable x
	return w[2]+w[1]*ln(x)+w[0]*x
end

Function FitGammaLogPDF(w,x) : FitFunc
	wave w; variable x
	return w[2]*StatsGammaPDF(10^x,0,w[0],w[1])
End

Function FitGammaCDF(w,x) : FitFunc
	Wave w; Variable x
	return StatsGammaCDF(x,0,w[0],w[1])
End

// Count ratio is w[0].  Gamma Function 1 has scale w[1] and shape w[2].  Gamma Function 2 has scale w[3] and shape w[4]. 
// Assumes ratio is between normalized distributions.   
function FitLogGammaRatio(w,x) : FitFunc
	wave w; variable x
	
	return w[0]+w[1]*x+w[2]*ln(x)
	//return ln(w[0]*StatsGammaPDF(x,0,w[1],w[2])/StatsGammaPDF(x,0,w[3],w[4]))
end

// w[0] = Count ratio.  w[1] = Rate parameter ratio.  w[2] = Shape parameter 1.  w[3] = Shape parameter 2.  
function FitGammaRatio(w,x) : FitFunc
	wave w; variable x
	
	//return w[0] * (w[1]^w[2]) * ((1+w[1]*x)^(-w[2]-w[3])) * (x^(w[2]-1)) / beta(w[2],w[3])
	return (w[0]^w[1]) * ((1+w[0]*x)^(-w[1]-w[2])) * (x^(w[1]-1)) / beta(w[1],w[2])
end

Function Synapse3(w,t) : FitFunc 
	Wave w; Variable t
	// w[0] = t_rise; w[1] = t_decay1; w[2]= t0; w[3] = y0; w[4] = A; w[5] = rise_shape
	variable rise=StatsGammaCDF(t,w[2],w[0],w[5])
	variable decay=t>w[2] ? exp(-(t-w[2])/w[1]) : 1
	return w[3]+w[4]*rise*decay
End

Function Synapse2(w,t) : FitFunc 
	Wave w; Variable t
	// w[0] = t_rise; w[1] = t_decay1; w[2] = t_decay2; w[3]= t0; w[4] = y0; w[5] = A
	variable rise=1-exp(-(t-w[3])/w[0])
	variable decay1=exp(-(t-w[3])/w[1])
	variable decay2=exp(-(t-w[3])/w[2])
	return t>w[3] ? w[4]+w[5]*rise*decay1*decay2 : w[4]
End

Function Synapse(w,t) : FitFunc 
	Wave w; Variable t
	// w[0] = t_rise; w[1] = t_decay; w[2]= t0; w[3] = y0; w[4] = A
	variable rise=1-exp(-(t-w[2])/w[0])
	variable decay=exp(-(t-w[2])/w[1]) 
	return t>w[2] ? w[3]+w[4]*rise*decay : w[3]
End

Function Synapse3Reverse(w,t) : FitFunc 
	Wave w; Variable t
	return Synapse3(w,w[2]-(t-w[2]))
End

Function SynapseReverse(w,t) : FitFunc 
	Wave w; Variable t
	return Synapse(w,w[2]-(t-w[2]))
End

Function AlphaSynapse(w,t) : FitFunc 
	Wave w; Variable t
	// w[0] = t_decay and rise (one parameter); w[1] = t0; w[2] = y0; w[3] = A
	return t>w[1] ? w[2]+w[3]*(t-w[1])*exp(-(t-w[1])/w[0]) : w[2]
End

Function RickSynapse(w,t) : FitFunc 
	Wave w; Variable t
	// w[0] = t_decay and rise (one parameter); w[1] = t0; w[2] = y0; w[3] = A
	return t>w[1] ? w[2]+w[3]*(1-exp(-(t-w[1])/0.001))*exp(-(t-w[1])/w[0]) : w[2]
End

Function MVFit(w,mean_current,var_f) : FitFunc
	Wave w; Variable mean_current,var_f
	// w[0] = i; w[1]=N; w[2]=p_max
	return w[0]*mean_current - (mean_current^2)/w[1] + (w[0]^2)*(w[1]^2)*(w[2]^2)*(var_f)
End

Function MVFit2(w,mean_current,CVi,CVp) : FitFunc
	Wave w; Variable mean_current,CVi,CVp
	// w[0] = i; w[1]=N; w[2]=p_max
	return w[0]*mean_current*(1+CVi^2) - (mean_current^2)*(((1/w[1])-1)*(1+CVi^2)*(1+CVp^2)+1)
End

Function ManyGauss(w,t) : FitFunc
	Wave w; Variable t
	// w[0] = i; w[1]=N; w[2]=p_max
	Variable i,result
	result=w[2]*exp(-((t/w[0])^2))
	for(i=3;i<numpnts(w);i+=1)
		result+=w[i]*exp(-((t-(i-2)*w[1])/w[0])^2)
		result+=w[i]*exp(-((t+(i-2)*w[1])/w[0])^2)
	endfor
	return result
End

Function ManyGauss2(w,t) : FitFunc
	Wave w; Variable t
	// w[0] = i; w[1]=N; w[2]=p_max
	Variable i,result=0
	for(i=0;i<numpnts(w);i+=3)
		result+=w[2+i]*exp(-(((t-w[1+i])/w[0+i])^2))
	endfor
	return result
End

Function GuessManyGauss(w)
	Wave /D w
	Variable i
	w[0]=1; w[1]=3;w[2]=100
	for(i=3;i<numpnts(w);i+=1)
		w[i]=w[2]*(2/i)
	endfor
End

Function FitBinomial(w,t) : FitFunc
	Wave w; Variable t
	//StatsBinomialPDF(x, p, N )
End

Function FitWald(w,t) : FitFunc
	Wave w; Variable t
	Variable result=w[2]*StatsWaldPDF(t,w[0],w[1])
	return result
End

Function FitDVonMises(w,t) : FitFunc
	wave w; variable t
	return w[4]+w[2]*sin(2*pi*w[3]*t-w[0])*exp(w[1]*cos(2*pi*w[3]*t-w[0]))
End

Function FitDriftingVonMises(w,t) : FitFunc
	wave w; variable t
	return w[2]*exp(w[1]*cos(t-w[0]+w[3]*cos(t)))/Besseli(0,w[1])
End

Function FitVonMises(w,t) : FitFunc
	wave w; variable t
	
	variable result=w[2]*StatsVonMisesPDF(t, w[0], w[1])
	result=numtype(result)==2 ? 0 : result
	return result
End

Function FitNormalizedVonMises(w,t) : FitFunc
	wave w; variable t
	
	variable result=StatsVonMisesPDF(t, w[0], w[1])
	result=numtype(result)==2 ? 0 : result
	return result
End

// Fits a cross-correlation function (unnormalized, mean unsubtracted) of two non-negative periodic signals, 
// e.g. phase histograms, with a function that should fit that CCF if the two signals were themselves well-fit
// by von Mises distributions, but were not correlated above what one would expect from those distributions.  
// Example: neuron A and neuron B have preferred phases corresponding to von Mises distribution parameters
// {mu_A,kappa_A} and {mu_B,kappa_B}.  Their phase histograms are computed.  These histograms can be over
// any range, but should roughly repeat every 2*pi.  If they have no contingent dependence, the cross-correlation 
// function of their spike phases should be well fit by the function below.  
Function FitVonMisesCorr(w,t) : FitFunc
	wave w; variable t
	// w[0] // Phase offset (mu_A-mu_B}.   
	// w[1] // Phase dispersion for signal 1 (mu_A).  
	// w[2] // Phase dispersion for signal 2 (mu_B).  
	// w[3] // Scaling factor (arbitrary, artifact of number of points, etc.).  
	return Besseli(0,sqrt(w[1]^2+w[2]^2+2*w[1]*w[2]*cos(t-w[0])))/w[3]
End

Function FitWrappedNormal(w,t) : FitFunc
	wave w; variable t
	
	variable k,summation=0
	variable krange=10 // accuracy parameter.  
	for(k=-krange;k<=krange;k+=1)
		summation+=exp(-(t-w[0]-2*pi*k)^2/(2*w[1]^2))
	endfor
	return w[2]*summation
End

Function MultivariateLinearRegression(w,x1,x2) : FitFunc
	wave w
	variable x1,x2
	
	return w[0]+w[1]*x1+w[2]*x2
End

Function MLGaussianFit(data,params)
	wave params,data
	
	make /free/n=(numpnts(data)) loglikelihoods=ln(StatsNormalPDF(data, params[0], params[1]))
	return sum(loglikelihoods)
End

// ------------------------------------------------ Maximum Likelihood Fits ------------------------------------- //

function /wave CensoredGammaLikelihoodFit(data,cutoff)
	wave data
	variable cutoff
	
	extract /free data,data_,data>cutoff
	insertpoints 0,1,data_
	data_[0]=cutoff
	make /o/n=2 coefs=1 // Shape and scale.  
	optimize /a/m={2,1}/q/i=2000/x=coefs CensoredGamma, data_
	return coefs
end

function CensoredGamma(data,scale,shape)
	wave data
	variable scale,shape
	
	variable cutoff = data[0]
	make /free/d/n=(numpnts(data)-1) logL = ln(statsgammapdf(data[p+1],cutoff,scale,shape))
	return sum(logL)
end