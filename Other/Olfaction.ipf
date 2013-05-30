// $URL: svn://raptor.cnbc.cmu.edu/rick/recording-artist/Recording%20Artist/Other/Olfaction.ipf $
// $Author: rick $
// $Rev: 632 $
// $Date: 2013-03-15 17:17:39 -0700 (Fri, 15 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=Olfaction
static strconstant module=Nlx
constant MAX_MODELS = 20
#include "GLMFit"
//#include "Spike Functions"

function InfoRate(df,models[,mode])
	dfref df
	wave models
	string mode // Not quite supported yet.  Don't know how to deal with coincidences in the 'counts' case.  
	
	mode = selectstring(!paramisdefault(mode),"exists",mode)
	strswitch(mode)
		case "exists":
			wave /sdfr=df yy = spikeExists
			break
		case "counts":
			wave /sdfr=df yy = spikeCounts
			break
		default:
			printf "No such mode: %s\r",mode
			return -1
	endswitch
	
	variable numObservations=dimsize(yy,0)
	variable numUnits=dimsize(yy,1)
	variable observationsPerSecond=10
	variable maxModels=20
	
	make /o/n=(numUnits,numUnits,maxModels) $("logLikeMuRateDep_"+mode) /wave = logLikelihoodMuRateDep
	make /o/n=(numUnits,numUnits,maxModels) $("logLikeMeanRateDep_"+mode) /wave = logLikelihoodMeanRateDep
	make /o/n=(numUnits,numUnits,maxModels) $("logLikeMuRateInd_"+mode) /wave = logLikelihoodMuRateInd
	make /o/n=(numUnits,numUnits,maxModels) $("logLikeMeanRateInd_"+mode) /wave = logLikelihoodMeanRateInd 
	make /o/n=(numUnits,numUnits,maxModels) $("logLikeDiffRateDep_"+mode) /wave = logLikelihoodDiffRateDep
	make /o/n=(numUnits,numUnits,maxModels) $("logLikeDiffRateInd_"+mode) /wave = logLikelihoodDiffRateInd
	make /o/n=(numUnits,numUnits,maxModels) $("logLikeDiffRateDiff_"+mode) /wave = logLikelihoodDiffRateDiff
	make /free/n=(numUnits,numUnits,numObservations) spikeCoincidences
	multithread spikeCoincidences=yy[r][p]*yy[r][q]
	variable i
	for(i=0;i<numpnts(models);i+=1)
		variable model=models[i]
		variable delete=0
		
		wave /z/d/sdfr=df muExists1=$("muExists1_"+num2str(model))
		if(!waveexists(muExists1))
			loadwave /o/p=Correlation "muExists1_"+num2str(model)+".ibw"
			wave /sdfr=df muExists1=$("muExists1_"+num2str(model))
			delete=1
		endif
		make /free/n=(numUnits,numUnits,numObservations) muCoincidencesDep
		make /free/n=(numUnits,numUnits) meanCoincidencesDep
		
		wave /z/d/sdfr=df muExists2=$("muExists2_"+num2str(model))
		if(!waveexists(muExists2))
			loadwave /o/p=Correlation "muExists2_"+num2str(model)+".ibw"
			wave /sdfr=df muExists2=$("muExists2_"+num2str(model))
			delete=1
		endif
		printf "Calculating muCoincidencesDep... "
		multithread muCoincidencesDep=muExists1[r][q][p]*muExists2[r][p][0]
		if(delete)
			killwaves muExists1
		endif
		
		make /free/n=(numUnits,numUnits,numObservations) muCoincidencesInd
		make /free/n=(numUnits,numUnits) meanCoincidencesInd
		printf "Calculating muCoincidencesInd... "
		multithread muCoincidencesInd=muExists2[r][q][0]*muExists2[r][p][0]
		if(delete)
			killwaves muExists2
		endif
		
		printf "Calculating logLikelihoodDep... "
		make /free/n=(numUnits,numUnits,numObservations) logLikelihoodMuDep,logLikelihoodMeanDep
		imagetransform /meth=2 zProjection muCoincidencesDep; wave m_zProjection
		meanCoincidencesDep[][]=m_zProjection[p][q]
		multithread logLikelihoodMeanDep=log(1 - abs(spikeCoincidences[p][q][r] - meanCoincidencesDep[p][q]))/log(2)
		multithread logLikelihoodMuDep=log(1 - abs(spikeCoincidences[p][q][r] - muCoincidencesDep[p][q][r]))/log(2)
		killwaves meanCoincidencesDep,muCoincidencesDep
		
		printf "Calculating logLikelihoodInd... "
		make /free/n=(numUnits,numUnits,numObservations) logLikelihoodMuInd,logLikelihoodMeanInd
		imagetransform /meth=2 zProjection muCoincidencesInd; wave m_zProjection
		meanCoincidencesInd[][]=m_zProjection[p][q]
		multithread logLikelihoodMeanInd=log(1 - abs(spikeCoincidences[p][q][r] - meanCoincidencesInd[p][q]))/log(2)
		multithread logLikelihoodMuInd=log(1 - abs(spikeCoincidences[p][q][r] - muCoincidencesInd[p][q][r]))/log(2)
		killwaves meanCoincidencesInd,muCoincidencesInd
		
		imagetransform /meth=2 zProjection logLikelihoodMuDep
		wave sumLogLikelihoodMuDep=m_zProjection
		//sumLogLikelihoodMuDep*=numObservations
		logLikelihoodMuRateDep[][][model]=sumLogLikelihoodMuDep[p][q]*observationsPerSecond
		
		imagetransform /meth=2 zProjection logLikelihoodMuInd
		wave sumLogLikelihoodMuInd=m_zProjection
		//sumLogLikelihoodMuInd*=numObservations
		logLikelihoodMuRateInd[][][model]=sumLogLikelihoodMuInd[p][q]*observationsPerSecond
		
		imagetransform /meth=2 zProjection logLikelihoodMeanDep
		wave sumLogLikelihoodMeanDep=m_zProjection
		//sumLogLikelihoodMeanDep*=numObservations
		logLikelihoodMeanRateDep[][][model]=sumLogLikelihoodMeanDep[p][q]*observationsPerSecond
		
		imagetransform /meth=2 zProjection logLikelihoodMeanInd
		wave sumLogLikelihoodMeanInd=m_zProjection
		//sumLogLikelihoodMeanInd*=numObservations
		logLikelihoodMeanRateInd[][][model]=sumLogLikelihoodMeanInd[p][q]*observationsPerSecond
		
		logLikelihoodDiffRateDep[][][model]=logLikelihoodMuRateDep[p][q][model]-logLikelihoodMeanRateDep[p][q][model]
		logLikelihoodDiffRateInd[][][model]=logLikelihoodMuRateInd[p][q][model]-logLikelihoodMeanRateInd[p][q][model]
		logLikelihoodDiffRateDiff[][][model]=logLikelihoodDiffRateDep[p][q][model]-logLikelihoodDiffRateInd[p][q][model]
	endfor
end

// Calculate the deviance of each cell pair interaction, i.e. the difference in log likehood of cell i spiking for models with and without cell j.  Significant coupling is indicated by significant deviances.  
function InfoRate2(df,models[,mode,meanModel])
	dfref df
	wave models
	string mode
	variable meanModel // Use this model as the mean against which information gain is measured.  
	
	mode = selectstring(!paramisdefault(mode),"exists",mode)
	strswitch(mode)
		case "exists":
			wave /sdfr=df yy = spikeExists
			variable modeNum=0
			break
		case "counts":
			wave /sdfr=df yy = spikeCounts
			modeNum=1
			break
		default:
			printf "No such mode: %s\r",mode
			return -1
	endswitch
	mode = upperstr(mode[0])+mode[1,strlen(mode)]
	
	variable numObservations=dimsize(yy,0)
	variable numUnits=dimsize(yy,1)
	variable observationsPerSecond=10
	matrixop /free numSpikes = sumCols(yy)^t // Number of spikes in each cell.  
	
	variable i
	for(i=0;i<numpnts(models);i+=1)
		variable model=models[i]
		make /o/d/n=(numUnits,numUnits) df:$("infoRateInd"+mode+"_"+num2str(model)) /wave=infoRateInd
		make /o/d/n=(numUnits,numUnits) df:$("infoRateDep"+mode+"_"+num2str(model)) /wave=infoRateDep
		make /o/d/n=(numUnits,numUnits) df:$("infoRateDiff"+mode+"_"+num2str(model)) /wave=infoRateDiff
		make /o/d/n=(numUnits,numUnits) df:$("deviance"+mode+"_"+num2str(model)) /wave=deviance
		
		// Have some redundancy in code here to save memory, deleting as we go along.  
		// Replace each mu vector with its mean value.  
		wave mu2 = GetMu(df,mode,2,model)
		imagetransform /meth=2 xProjection mu2
		duplicate /free m_xProjection,mu2mean
		killwaves /z m_xProjection
		
		make /free/d/n=(numUnits,numUnits,numObservations) logLikelihood2
		multithread logLikelihood2=LnSomethingPDF(yy[r][p],mu2[r][q][p],modeNum)
		if(stringmatch(stringbykey("delete",note(mu2)),"1"))
			killwaves mu2
		endif
		matrixop /free sumLogLikelihood2 = sumbeams(logLikelihood2)
		waveclear logLikelihood2
		
		make /free/d/n=(numUnits,numUnits,numObservations) logLikelihoodMean
		if(paramisdefault(meanModel))
			multithread logLikelihoodMean=LnSomethingPDF(yy[r][p],mu2mean[q][p],modeNum)
			matrixop /free sumLogLikelihoodMean = sumbeams(logLikelihoodMean)
		else
			wave mu2mean = GetMu(df,mode,2,meanModel)
			multithread logLikelihoodMean=LnSomethingPDF(yy[r][p],mu2mean[r][q][p],modeNum)
			matrixop /free sumLogLikelihoodMean = sumbeams(logLikelihoodMean)
			killwaves mu2mean
		endif
		waveclear logLikelihoodMean
		
		wave mu1 = GetMu(df,mode,1,model)
		//imagetransform /meth=2 xProjection mu1
		//duplicate /free m_xProjection,mu1mean
		//killwaves /z m_xProjection
		
		make /free/d/n=(numUnits,numUnits,numObservations) logLikelihood1
		multithread logLikelihood1=LnSomethingPDF(yy[r][p],mu1[r][q][p],modeNum)
		if(stringmatch(stringbykey("delete",note(mu1)),"1"))
			killwaves mu1
		endif
		matrixop /free sumLogLikelihood1 = sumbeams(logLikelihood1)
		waveclear logLikelihood1
		
		//make /free/d/n=(numUnits,numUnits,numObservations) logLikelihood2mean
		//if(paramisdefault(meanModel))
		//	multithread logLikelihood2mean=LnSomethingPDF(yy[r][p],mu2mean[q][p],modeNum)
		//	matrixop /free sumLogLikelihood2mean = sumbeams(logLikelihood2mean)
		//else
		//	wave mu2mean = GetMu(df,mode,2,meanModel)
		//	multithread logLikelihood2mean=LnSomethingPDF(yy[r][p],mu2mean[r][q][p],modeNum)
		//	matrixop /free sumLogLikelihood2mean = sumbeams(logLikelihood2mean)
		//	killwaves mu2mean
		//endif
		//waveclear logLikelihood2mean
			
		strswitch(mode)
			case "exists":
				// Compute bits per second.  
				infoRateInd = (sumLogLikelihood2[p][q]-sumLogLikelihoodMean[p][q])*(observationsPerSecond/numObservations)/ln(2)
				infoRateDep = (sumLogLikelihood1[p][q]-sumLogLikelihoodMean[p][q])*(observationsPerSecond/numObservations)/ln(2)
				break
			case "counts":
				// Compute bits per spike.  
				infoRateInd = (sumLogLikelihood2[p][q]-sumLogLikelihoodMean[p][q])/numSpikes[p]//*(observationsPerSecond/numObservations)/ln(2)
				infoRateDep = (sumLogLikelihood1[p][q]-sumLogLikelihoodMean[p][q])/numSpikes[p]//*(observationsPerSecond/numObservations)/ln(2)
				break
		endswitch
		infoRateDiff = InfoRateDep[p][q] - InfoRateInd[p][q]
		deviance = 2*(sumLogLikelihood1[p][q] - sumLogLikelihood2[p][q])
	endfor
end

function FDRs(df,mode,model[,shuffle])
	dfref df
	string mode
	variable model,shuffle
	
	string suffix = mode+"_"+num2str(model)+selectstring(shuffle,"","_shuffle")
	wave deviance = df:$("deviance"+suffix)
	variable numUnits = dimsize(deviance,0)
	make /o/d/n=(numUnits,numUnits) df:$("fdr"+suffix) /wave=fdr = (1 - statschicdf(deviance[p][q],1))
	extract /o fdr,df:$("fdr"+suffix+"_same") /wave=fdr_same,SameElectrode(df,{p+1,q+1})==1
	ecdf(fdr_same); 
	fdr_same *= numpnts(fdr_same) / (p+1)
	ecdf(fdr_same)
	extract /o fdr,df:$("fdr"+suffix+"_diff") /wave=fdr_diff,SameElectrode(df,{p+1,q+1})==0
	ecdf(fdr_diff); 
	fdr_diff *= numpnts(fdr_diff) / (p+1)
	ecdf(fdr_diff)
	ecdf(fdr)
	fdr *= numpnts(fdr) / (p+1)
	ecdf(fdr)
end

function /wave GetMu(df,mode,num,model)
	dfref df
	variable model // 0-15 or so.  
	variable num // 1 or 2.  
	string mode // "exists" or "counts"
	
	dfref currDF = GetDataFolderDFR()
	mode = upperstr(mode[0])+mode[1,strlen(mode)]
	string name = "mu"+mode+num2str(num)+"_"+num2str(model)
	wave /z/d/sdfr=df mu=$name
	if(!waveexists(mu))
		pathinfo Correlation
		if(!v_flag)
			newpath /o Correlation
		endif
		setdatafolder df
		GetFileFolderInfo /P=Correlation/Q/Z=1 name+".ibw"
		if(!v_flag)
			loadwave /o/q/p=Correlation name+".ibw"
			wave mu = df:$name
			note /k/nocr mu replacestringbykey("delete",note(mu),"1")
		else
			make /o/d/n=(100,10,10) df:$name /wave=mu
			note /k/nocr mu replacestringbykey("delete",note(mu),"0")
		endif
	else
		note /k/nocr mu replacestringbykey("delete",note(mu),"0")
	endif
	setdatafolder currDF
	return mu
end

threadsafe function LnSomethingPDF(yy,mu,modeNum)
	variable yy,mu,modeNum
	
	if(modeNum==0)
		return LnStatsBinomialPDF(yy,mu)
	elseif(modeNum==1)
		return LnStatsPoissonPDF(yy,mu)
	endif
end

threadsafe function LnStatsBinomialPDF(yy,mu)
	variable yy,mu
	
	return ln(1 - abs(yy - mu))
end

threadsafe function LnStatsPoissonPDF(yy,mu)
	variable yy,mu
	
	if(yy<100)
		variable result = yy*ln(mu) - mu - ln(factorial(yy))
	else
		result = yy*ln(mu) - mu - stirling(yy)
	endif
	if(abs(result)>1e10)
		//print result,yy,mu
	endif
	return result
end

function InfoRate3(df,modelA,modelB)
	dfref df
	variable modelA,modelB
	wave /sdfr=df spikeExists
	variable numObservations=dimsize(spikeExists,0)
	variable numUnits=dimsize(spikeExists,1)
	variable observationsPerSecond=10
	
	variable deleteA=0,deleteB=0
	make /free/d/n=(numUnits,numUnits,numObservations) logLikelihoodA,logLikelihoodB
	make /o/d/n=(numUnits,numUnits) $("deviance_"+num2str(modelA)+"_"+num2str(modelB)) /wave=deviance
	wave /z/d/sdfr=df muExistsA=$("muExists1_"+num2str(modelA))
	wave /z/d/sdfr=df muExistsB=$("muExists1_"+num2str(modelB))
	if(!waveexists(muExistsA))
		loadwave /o/p=Correlation "muExists1_"+num2str(modelA)+".ibw"
		deleteA=1
	endif
	if(!waveexists(muExistsB))
		loadwave /o/p=Correlation "muExists1_"+num2str(modelB)+".ibw"
		deleteB=1
	endif
	wave /d/sdfr=df muExistsA=$("muExists1_"+num2str(modelA))
	wave /d/sdfr=df muExistsB=$("muExists1_"+num2str(modelB))
	multithread logLikelihoodA=ln(1 - abs(spikeExists[r][p] - muExistsA[r][q][p]))
	multithread logLikelihoodB=ln(1 - abs(spikeExists[r][p] - muExistsB[r][q][p]))
	matrixop /free sumLogLikelihoodA = sumbeams(logLikelihoodA)
	matrixop /free sumLogLikelihoodB = sumbeams(logLikelihoodB)
	deviance = 2*(sumLogLikelihoodB[p][q] - sumLogLikelihoodA[p][q])
	if(deleteA)
		killwaves /z $("muExists1_"+num2str(modelA))
	endif
	if(deleteB)
		killwaves /z $("muExists1_"+num2str(modelB))
	endif
end

function LogLTimeCourse(df,model)
	dfref df
	variable model
	wave /sdfr=df spikeExists
	variable numBins=dimsize(spikeExists,0)
	variable numUnits=dimsize(spikeExists,1)
	variable observationsPerSecond=10
	
	variable delete=0
	make /free/d/n=(numUnits,numBins) logLikelihood
	wave /z/d/sdfr=df muExists=$("muExists2_"+num2str(model))
	if(!waveexists(muExists))
		loadwave /o/p=Correlation "muExists2_"+num2str(model)+".ibw"
		delete=1
	endif
	wave /d/sdfr=df muExists=$("muExists2_"+num2str(model))
	logLikelihood=ln(1 - abs(spikeExists[q][p] - muExists[q][0][p]))
	variable binsPerTrial=observationsPerSecond*10 // 10 seconds in a trial.  
	variable numTrials=numBins/binsPerTrial
	make /free/n=(numUnits,binsPerTrial,numTrials) logLikelihoodTimeCourse_ = logLikelihood[p][binsPerTrial*r+q]
	matrixop /o logLikelihoodTimeCourse = sumbeams(logLikelihoodTimeCourse_)
	if(delete)
		killwaves /z $("muExists2_"+num2str(model))
	endif
end

function VarianceExplained(df,models)
	dfref df
	wave models
	
	wave /sdfr=df spikeExists
	variable numObservations=dimsize(spikeExists,0)
	variable numUnits=dimsize(spikeExists,1)
	variable observationsPerSecond=10
	make /o/n=(numUnits,MAX_MODELS) variance_explained_firing
	make /o/n=(numUnits,numUnits,MAX_MODELS) variance_explained_coincidence
	newpath /o/q Correlation, "E:NNU Projects:Reliability:Correlation"
	
	variable i
	for(i=0;i<numpnts(models);i+=1)
		variable model=models[i]
		if(numpnts(models)>1)
			Prog("Model",i,numpnts(models),msg="# "+num2str(model))
		endif
		wave /z/d/sdfr=df muExists1=$("muExists1_"+num2str(model))
		wave /z/d/sdfr=df muExists2=$("muExists2_"+num2str(model))
		if(!waveexists(muExists1) || !waveexists(muExists2))
			loadwave /o/p=Correlation "muExists1_"+num2str(model)+".ibw"
			loadwave /o/p=Correlation "muExists2_"+num2str(model)+".ibw"
			variable delete=1
		else
			delete=0
		endif
		
		// For single cell firing.  
		wave /d/sdfr=df muExists=$("muExists2_"+num2str(model)) // In this case, the numUnits models for each unit will themselves each be missing one unit.  Each of these models will be averaged to get a consensus model.  
		matrixop /o ss_tot = sumcols(powR(subtractmean(spikeExists,1),2))^t
		
		imagetransform /meth=2 yProjection muExists
		wave muExists_consensus = m_yProjection // Average across models, each using some other cell as a covariate.  New wave is observations x cells, like spikeExists.  
		matrixop /o ss_err = sumcols(powR(spikeExists - muExists_consensus,2))^t
		variance_explained_firing[][model] = 1 - ss_err[p]/ss_tot[p]
		
		// For coincidences.  
		wave /d/sdfr=df muExists1=$("muExists1_"+num2str(model))
		wave /d/sdfr=df muExists2=$("muExists2_"+num2str(model))
		make /free/n=(numObservations,numUnits,numUnits) muCoincidences,coincidenceExists
		multithread muCoincidences = muExists1[p][q][r]*muExists2[p][r][q]
		multithread coincidenceExists = spikeExists[p][q] * spikeExists[p][r]
		
		imagetransform /meth=2 xProjection coincidenceExists
		wave coincidenceExists_mean=m_xProjection
		make /free/n=(numObservations,numUnits,numUnits) s_tot
		multithread s_tot = (coincidenceExists[p][q][r] - coincidenceExists_mean[q][r])^2
		imagetransform /meth=2 xProjection s_tot
		duplicate /free m_xProjection ss_tot
		ss_tot *= numObservations
		
		make /free/n=(numObservations,numUnits,numUnits) s_err
		multithread s_err = (coincidenceExists[p][q][r] - muCoincidences[p][q][r])^2
		imagetransform /meth=2 xProjection s_err
		duplicate /free m_xProjection ss_err
		ss_err *= numObservations
		
		variance_explained_coincidence[][][model] = 1 - ss_err[p][q]/ss_tot[p][q]
		if(delete)
			killwaves $("muExists1_"+num2str(model)),$("muExists2_"+num2str(model))
		endif
	endfor
end

function ModelROC(df,models[,permute])
	dfref df
	wave models
	variable permute
	
	setdatafolder df
	wave /sdfr=df spikeExists
	variable numObservations=dimsize(spikeExists,0)
	variable numUnits=dimsize(spikeExists,1)
	variable observationsPerSecond=10
	variable resolution=1000
	//make /o/n=(resolution,MAX_MODELS) fpr_firing,tpr_firing
	//make /o/n=(resolution,MAX_MODELS) fpr_coincidence,tpr_coincidence
	make /o/n=(1001,numUnits,MAX_MODELS) df:rocs /wave=rocs
	//setscale x,0,1,fpr_firing,tpr_firing,fpr_coincidence,tpr_coincidence
	newpath /o/q Correlation, "C:Users:rgerkin:Desktop"//"E:NNU Projects:Reliability:Correlation"
	
	variable i
	for(i=0;i<numpnts(models);i+=1)
		if(numpnts(models)>1)
			Prog("Model",i,numpnts(models),msg="Model "+num2str(models[i]))
		endif
		variable model=models[i]
		wave /z/d/sdfr=df muExists1=$("muExists1_"+num2str(model))
		wave /z/d/sdfr=df muExists2=$("muExists2_"+num2str(model))
		if(!waveexists(muExists1) || !waveexists(muExists2))
			loadwave /o/p=Correlation "muExists1_"+num2str(model)+".ibw"
			loadwave /o/p=Correlation "muExists2_"+num2str(model)+".ibw"
			variable delete=1
		else
			delete=0
		endif
		
		//if(i==0)
		//	variable numObservations = dimsize(muExists2,0)
		//	variable numUnits = dimsize(muExists2,1)
		//	
		//endif
		// For single cell firing.  
		wave /d/sdfr=df muExists=$("muExists2_"+num2str(model)) // In this case, the numUnits models for each unit will themselves each be missing one unit.  Each of these models will be averaged to get a consensus model.  
		imagetransform /meth=2 yProjection muExists
		wave muExists_consensus = m_yProjection // Average across models, each using some other cell as a covariate.  New wave is observations x cells, like spikeExists.  
		variable j
		//setscale /I x,0,1,roc_mean
		for(j=0;j<numUnits;j+=1)
			Prog("Unit",j,numUnits)
			make /free/n=(numObservations) randos=gnoise(1),index=p
			if(permute)
				sort randos,index
			endif
			extract /o muExists_consensus,muExists_spikes,spikeExists[index[p]][q]==1 && q==j // Get all the mu's for bins with spikes.  Need to be global waves for subsequent use with Interpolate2 XOP (in Invert).  
			extract /o muExists_consensus,muExists_noSpikes,spikeExists[index[p]][q]==0 && q==j
			ecdf(muExists_spikes) // Sorted.  x-value is a quantile and y-value is a mu.  
			ecdf(muExists_noSpikes)
			wave inverted_spikes = Invert(muExists_spikes,lo=0,hi=1,points=1000) // Now x-value is a mu and y-value is a quantile.  
			wave inverted_noSpikes = Invert(muExists_noSpikes,lo=0,hi=1,points=1000)
			inverted_spikes = 1 - inverted_spikes // Now this is true positive rate.  
			inverted_noSpikes = 1 - inverted_noSpikes // Now this is false positive rate.  
			
			// Pad with 0 and 1 on the ends so the interpolation works correctly.  
			insertpoints 0,1,inverted_spikes,inverted_noSpikes
			inverted_spikes[0]=0
			inverted_noSpikes[0]=0
			inverted_spikes[numpnts(inverted_spikes)]={1}
			inverted_noSpikes[numpnts(inverted_noSpikes)]={1}
			
			// Interpolate to get a tpr which is a function of an evenly spaced (from 0 to 1) fpr.  This way averaging across cells will work.    
			make /free/n=1001 roc_
			setscale /I x,0,1,roc_	
			Interpolate2 /T=1 /I=3 /Y=roc_ inverted_noSpikes,inverted_spikes
			roc_=limit(roc_,0,1)
			rocs[][j][model]=roc_[p]
			waveclear muExists_spikes,muExists_noSpikes
		endfor
		
		killwaves inverted_spikes,inverted_noSpikes,muExists_spikes,muExists_noSpikes
		
		// For coincidences.  
		if(0) // Takes several minutes.  Be sure to uncomment the lines below that store the results.  
			wave /d/sdfr=df muExists1=$("muExists1_"+num2str(model))
			wave /d/sdfr=df muExists2=$("muExists2_"+num2str(model))
			make /free/n=(numObservations,numUnits,numUnits) muCoincidences,coincidenceExists
			multithread muCoincidences = muExists1[p][q][r] * muExists2[p][r][q]
			multithread coincidenceExists = spikeExists[p][q] * spikeExists[p][r]
			extract /o muCoincidences,muCoincidences_coincs,coincidenceExists==1 // Get all the mu's for bins with spikes.  Need to be global waves for subsequent use with Interpolate2 XOP (in Invert).  
			extract /o muCoincidences,muCoincidences_noCoincs,coincidenceExists==0
			ecdf(muCoincidences_coincs) // Sorted.  x-value is a quantile and y-value is a mu.  
			ecdf(muCoincidences_noCoincs)
			wave inverted_coincidences = Invert(muCoincidences_coincs,lo=0,hi=1,points=1000) // Now x-value is a mu and y-value is a quantile.  
			wave inverted_noCoincidences = Invert(muCoincidences_noCoincs,lo=0,hi=1,points=1000)
			//tpr_coincidence[][model] = 1-inverted_coincidences[p]	
			//fpr_coincidence[][model] = 1-inverted_noCoincidences[p]
			killwaves inverted_coincidences,inverted_noCoincidences,muCoincidences_coincs,muCoincidences_noCoincs
		endif
			
		if(delete)
			killwaves $("muExists1_"+num2str(model)),$("muExists2_"+num2str(model))
		endif
	endfor
	
	wave /sdfr=df roc_means
	imagetransform /meth=2 yProjection rocs
	if(!waveexists(roc_means))	
		duplicate /o m_yprojection df:roc_means /wave=roc_means
	else
		wave m_yprojection
		for(i=0;i<numpnts(models);i+=1)
			roc_means[][models[i]] = m_yprojection[p][q]
		endfor
	endif
	setscale x,0,1,roc_means
end

// Obsolete.  Use All GLMs2
function AllGLMs(df[,simul])
	dfref df
	variable simul // Do all fits simultaneously.  
	
	cd df	
	wave /sdfr=root: trialTime // Time elapsed since trial onset.  
	wave /sdfr=root: OdorsOn // Identity of the last odor turned on.  
	wave /sdfr=root:resp:e10:phase respPhaseBasis=basis // Basis vectors for the respiratory phase, consisting of sines and cosines of the integer multiples of the instantaneous phase.  
	wave /sdfr=root: trialNum,trialNum2,trialNum3 // Powers of the total time elapsed since recording onset.  
	wave trials // A PETH trials matrix created by triggering on trial onset for the first of the odors.  
			   // Each row will the contain numOdors trials concatenated.  Result should be numBinsPerTrial x numUnits x 1 x numTrialsPerOdor
	variable numBinsPerTrial=dimsize(trials,0) // If each trial is 10 seconds and bin size is 0.1, then this is equal to 100.  
	variable numUnits=dimsize(trials,1)
	variable numTrialsPerOdor=dimsize(trials,3) // Also equals numTrials in a normal numBinsPerTrial x numUnits x numOdors x numTrials matrix.  
	// Create a wave with one column for each cell which contains concatenated data for the whole experiment.  
	make /o/n=(numBinsPerTrial*numTrialsPerOdor,numUnits) df:spikeCounts /wave=spikeCounts=trials[mod(p,numBinsPerTrial)][q][0][floor(p/numBinsPerTrial)]
	duplicate /o spikeCounts, spikeExists
	spikeExists=spikeCounts>0
	make /o/n=(dimsize(spikeCounts,0),numUnits) muCounts=nan,muExists=nan
	make /free/n=9 splines
	splines[0]=3 // Cubic splines.  
	splines[1]=1 // First derivatives match.  
	splines[2]=0 // Apply to the first covariate (trialTime).  
	splines[3]=10 // Repeat every ten units (seconds, the length of a trial).  
	splines[4]=1 // Require continuity between the end of one trial and the beginning of the next.  
	splines[5,]={0,2,6,10} // Spline knots at 0, 2, 6, and 10 seconds into the trial.  0 and 10 are points of continuity between trials.  2 and 6 are odor onset and odor offset, respectively.  
	variable i,j
	for(j=1;j<2;j+=1)
		Prog("Type",j,2)
		if(!simul)
			variable first=1
			for(i=0;i<numUnits;i+=1)
				Prog("Unit",i,numUnits)
				if(j==0)
					wave spikeCount=col(spikeCounts,i)
					duplicate /free spikeCounts,otherSpikeCounts
					deletepoints /m=1 i,1,otherSpikeCounts
					//matrixop /free otherSpikeCounts=meancols(otherSpikeCounts^t)
					//glmfit(spikeCount,{otherSpikeCounts},"gaussian",noConstant=0,brief=1)
					glmfit(spikeCount,{trialTime,otherSpikeCounts,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},"poisson",splines=splines,noConstant=1,brief=1)
					wave mu
					muCounts[][i]=mu[p]
				else
					wave spikeExist=col(spikeExists,i)
					duplicate /free spikeExists,otherSpikeExists
					deletepoints /m=1 i,1,otherSpikeExists
					glmfit(spikeExist,{trialTime,otherSpikeExists,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},"binomial",splines=splines,noConstant=1,brief=2,condition=1)
					wave mu
					muExists[][i]=mu[p]
					wave betas,betaTs,betaPvals,betaDeviances 
					if(first)
						duplicate /o betas,allBetas
						duplicate /o betaTs,allBetaTs
						duplicate /o betaPvals,allBetaPvals
						duplicate /o betaDeviances,allBetaDeviances
					else
						concatenate {betas},allBetas
						concatenate {betaTs},allBetaTs
						concatenate {betaPvals},allBetaPvals
						concatenate {betaDeviances},allBetaDeviances
					endif
				endif
				first=0
				waveclear mu
			endfor
		else
			make /free/n=(numUnits,numUnits) pMu=0
			make /free/n=(numUnits,numUnits,numUnits) b=(p==q && p==r) ? 0.0001 : 10000
			splines[2]=numUnits // Apply splines to the covariate after spikeCounts/spikeExists, which has 'numUnits' columns.  
			if(j==0)
				glmfit(spikeCounts,{spikeCounts,trialTime,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},"poisson",splines=splines,prior=L1Norm,priorParams={pMu,b},noConstant=1,brief=1)
				wave mu
				muCounts=mu[p][q]
			else
				glmfit(spikeExists,{spikeExists,trialTime,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},"binomial",splines=splines,prior=L1Norm,priorParams={pMu,b},noConstant=1,brief=1)
				wave mu
				muExists=mu[p][q]
			endif
		endif
	endfor
end

function AllGLMs2(df,model[,mode,reset,pass_start,pass_end,i_start,i_end,j_start,j_end,betas_thresh,mus_thresh,recalculate_mus,save_,kill])
	dfref df
	variable model,reset,i_start,i_end,j_start,j_end,pass_start,pass_end
	variable betas_thresh // Fit only those models which have a beta value which exceeds 'beta_thresh'.  Requires reset=0.  
	variable mus_thresh // Fit only those models for whom the sum of the mu values (across bins) deviate from the actual spike counts by more than the fraction 'mus_thresh'.  
	variable recalculate_mus // Just recalculate mu's from existing betas.  
	variable save_ // Save the mu's when finished with the fits.  
	variable kill // Kill the mu's when finished with the fits (and after optionally saving).  
	string mode
	
	pass_start = paramisdefault(pass_start) ? 1 : pass_start
	pass_end = paramisdefault(pass_end) ? 2 : pass_end
	reset = paramisdefault(reset) ? 0 : reset
	mode = selectstring(!paramisdefault(mode),"exists",mode)
	save_ = paramisdefault(save_) ? 1 : save_
	kill = paramisdefault(kill) ? 1 : kill
	variable brief = recalculate_mus ? 6 : 1 
	cd df	
	
	pathinfo Correlation
	if(!v_flag)
		newpath /o Correlation
	endif
	wave /sdfr=root: OdorsOn // Identity of the last odor turned on.  
	wave /sdfr=root:resp:e10:phase respPhaseBasis=basis // Basis vectors for the respiratory phase, consisting of sines and cosines of the integer multiples of the instantaneous phase.  
	wave /sdfr=root: trialNum,trialNum2,trialNum3 // Powers of the total time elapsed since recording onset.  
	wave trials // A PETH trials matrix created by triggering on trial onset for the first of the odors.  
			   // Each row will the contain numOdors trials concatenated.  Result should be numBinsPerTrial x numUnits x 1 x numTrialsPerOdor
	variable numBinsPerTrial=dimsize(trials,0) // If each trial is 10 seconds and bin size is 0.1, then this is equal to 100.  
	variable numUnits=dimsize(trials,1)
	variable numTrialsPerOdor=dimsize(trials,3) // Also equals numTrials in a normal numBinsPerTrial x numUnits x numOdors x numTrials matrix.  
	// Create a wave with one column for each cell which contains concatenated data for the whole experiment.  
	make /o/n=(numBinsPerTrial*numTrialsPerOdor,numUnits) df:spikeCounts /wave=spikeCounts=trials[mod(p,numBinsPerTrial)][q][0][floor(p/numBinsPerTrial)]
	strswitch(mode)
		case "exists":
			string distr = "binomial"
			duplicate /o spikeCounts, spikeExists
			wave yy = spikeExists
			yy=spikeCounts>0
			break
		case "counts":
			distr = "poisson"
			wave yy = spikeCounts
			break
		default:
			printf "No such mode: %s\r",mode
			return -1
	endswitch
	variable numBins=dimsize(yy,0)
	wave /sdfr=root: trialTime // Time elapsed since trial onset.  
	wave /z/sdfr=root: training
	if(!waveexists(training))
		make /o/n=(numBins) root:training /wave=training=0
	endif
	string upperMode = upperstr(mode[0])+mode[1,strlen(mode)]
	
	wave /z/d betas1=df:$("betas"+upperMode+"1_"+num2str(model))
	wave /z/d betas2=df:$("betas"+upperMode+"2_"+num2str(model))
	if(!waveexists(betas1) || !waveexists(betas2))
		make /o/d/n=(200,numUnits,numUnits) df:$("betas"+upperMode+"1_"+num2str(model)) /wave=betas1 // Model for predicting spiking in unit i, which also uses unit j.  
		make /o/d/n=(200,numUnits,numUnits) df:$("betas"+upperMode+"2_"+num2str(model)) /wave=betas2 // Model for predicting spiking in unit i, which deliberately does not use unit j.  
	else
		redimension /n=(200,numUnits,numUnits) betas1,betas2
	endif
	make /free/n=8 splines
	splines[0]=3 // Cubic splines.  
	splines[1]=1 // First derivatives match.  
	splines[2]=0 // Apply to the first covariate (trialTime).  
	splines[3]=10 // Repeat every ten units (seconds, the length of a trial).  
	splines[4]=1 // Require continuity between the end of one trial and the beginning of the next.  
	splines[5,]={2,4,6} // Spline knots at 2, 4, and 6 seconds into the trial.  2 , 4, and 6 are odor (low) onset, (high) onset, and odor offset, respectively.  
	funcref L2norm prior=$"L2norm"
	
	make /free/d/n=1000 betas//=0 // Don't initialize so the values from the previous fit can be used as a starting point.  
	i_end = paramisdefault(i_end) ? numUnits-1 : i_end
	j_end = paramisdefault(j_end) ? numUnits-1 : j_end
	variable i,j,pass,fits=0
	for(pass=pass_start;pass<=pass_end;pass+=1) // Various possible involvements of unit j.  See muExists 1, 2, 3 above.  
		Prog("Pass",pass-1,2)
//		if(pass==2) // SKIPPING PASS 1.  
//			continue
//		endif
		if(pass==1)
			wave mu1 = GetMu(df,mode,1,model) // Model for predicting spiking in unit i, which also uses unit j.  
			redimension /e=1/n=(numBins,numUnits,numUnits) mu1
			if(reset)
				multithread mu1=nan
				multithread betas1=nan
			endif
		elseif(pass==2)
			wave mu2 = GetMu(df,mode,2,model) // Model for predicting spiking in unit i, which deliberately does not use unit j.  
			redimension /e=1/n=(numBins,numUnits,numUnits) mu2
			if(reset)
				multithread mu2=nan
				multithread betas2=nan
			endif
		endif
		//for(i=0;i<=0;i+=1)
		for(i=i_start;i<=i_end;i+=1)
			Prog("Unit I",i,numUnits)
			if(i>0)
				//break
			endif
			wave yy_i=col(yy,i) // A vector of binary observations about whether or not unit i has a spike in each bin.  
			//for(j=87;j<=87;j+=1)
			for(j=j_start;j<=j_end;j+=1) 
				Prog("Unit J",j,numUnits)
				switch(pass)
					case 1:
						if(i==j && model!=0)
							mu1[][j][i]=nan
							betas1[][j][i]=nan
							continue
						endif
						if(j>0 && model==0)
							mu1[][j][i]=mu1[p][0][i] // Just use the values from j=0.  
							continue
						endif
						duplicate /free/r=[1,][j,j][i,i] betas1, oldBetas // All betas except from the constant term.  
						//print dimsizes(betas1),dimsizes(oldBetas)
						//print oldBetas
						oldBetas = abs(oldBetas)
						if (wavemax(oldBetas) < betas_thresh)// || numtype(oldBetas[0])==2) // If old betas are small enough.  
							continue // Don't fit again.  
						elseif(betas_thresh)
							print pass,i,j,wavemax(oldBetas)
						endif
						duplicate /free/r=[][j,j][i,i] mu1, oldMus
						variable ratio = abs(sum(oldMus)/sum(yy_i)-1)
						if(ratio < mus_thresh)
							continue
						else
							printf "Mu Threshold reached for pass %d, iteration (%d,%d): Mu ratio was was %.3f\r", pass,i,j,ratio
						endif
						if(recalculate_mus)
							betas = betas1[p][j][i]
						endif
						break
					case 2:
						if(i==j && i>0)
							mu2[][j][i]=nan
							betas2[][j][i]=nan
							continue
						endif
						if(j>0 && model>=6)
							mu2[][j][i]=mu2[p][0][i] // Just use the values from j=0.  
							continue
						endif
						duplicate /free/r=[1,][j,j][i,i] betas2, oldBetas // All betas except from the constant term.  
						oldBetas = abs(oldBetas)
						if (wavemax(oldBetas) < betas_thresh)// || numtype(oldBetas[0])==2) // If old betas are small enough.  
							continue // Don't fit again.  
						elseif(betas_thresh)
							printf "Beta Threshold reached for pass %d, iteration (%d,%d): Maximum beta was %.3f\r", pass,i,j,wavemax(oldBetas)
						endif
						duplicate /free/r=[][j,j][i,i] mu2, oldMus
						ratio = abs(sum(oldMus)/sum(yy_i)-1)
						if(ratio < mus_thresh)
							continue
						else
							print pass,i,j,ratio
						endif
						if(recalculate_mus)
							betas = betas2[p][j][i]
						endif
						break
				endswitch
				make /free/d/n=1000 priorMeans=0; priorMeans[0]=ln(mean(yy_i)) // TO DO: priorMeans[0] should be related to the firing rate (mean value of yy across bins) through the link function.  Here I have hard-coded ln, but it should be made more general.  
				string priorName = stringbykey("NAME",funcrefinfo(prior))
				strswitch(priorName)
					case "L1norm":
						variable priorCovar = 0.1
						break
					case "L2norm":
						priorCovar = 2 // Reduce this if fits start failing GLMSanityCheck, e.g. the predicted number of spikes across the experiment deviates significantly from the actual number of spikes.  
						break
					default:
						priorCovar = 2
				endswitch
				make /free/d/n=(1000,1000) priorCovars=p==q ? priorCovar : 0; priorCovars[0][0]=100
				variable sameElec=SameElectrode(df,{i+1,j+1}) // 1 if unit i and unit j were recorded on the same tetrode, and 0 if they were not.  
				wave yy_j=col(yy,j)  // A vector of binary observations about whether or not unit j has a spike in each bin.   
				make /free/d/n=10000 mu=nan
				make /free/n=(numUnits) unitNums=p	
				switch(model)
					case 0: // Full Model.  
						switch(pass)
							case 1:
								extract /free unitNums,unitNums_,unitNums!=i
								break
							case 2:
								extract /free unitNums,unitNums_,unitNums!=i && unitNums!=j
								break
						endswitch
						make /free/n=(numBins,numpnts(unitNums_)) other_yy=yy[p][unitNums_[q]]
						//print priorMeans
						variable logL = glmfit(yy_i,{trialTime,other_yy,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
						//print logL
						//wavestats /q betas
						//print v_min,v_max
						//print betas
						//wave mu
						//print betas[0]
						//print sum(mu),sum(yy_i)
						break
					case 1: // Full model but only with neurons on i's tetrode.  
						if(sameElec) // We only care about this model when neuron i and j are on the same tetrode.  
							switch(pass)
								case 1:
									extract /free unitNums,unitNums_,unitNums!=i && (unitNums==j || SameElectrode(df,{i+1,p+1})==1)
									break
								case 2:
									extract /free unitNums,unitNums_,unitNums!=i && unitNums!=j && SameElectrode(df,{i+1,p+1})==1
									break
							endswitch
							make /free/n=(numBins,numpnts(unitNums_)) other_yy=yy[p][unitNums_[q]]
							glmfit(yy_i,{trialTime,other_yy,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
						else
							continue
						endif
						break
					case 2: // Full model but only with neurons *not* on i's tetrode.  
						if(sameElec)
							switch(pass)
								case 1:
									extract /free unitNums,unitNums_,unitNums!=i && (unitNums==j || SameElectrode(df,{i+1,p+1})==0)
									break
								case 2:
									extract /free unitNums,unitNums_,unitNums!=i && unitNums!=j && SameElectrode(df,{i+1,p+1})==0
									break
							endswitch
							make /free/n=(numBins,numpnts(unitNums_)) other_yys=yy[p][unitNums_[q]]
							glmfit(yy_i,{trialTime,other_yy,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
						else
							continue
						endif
						break
					case 3: // Full model but only with the mean firing rate (of all other neurons).  
						extract /free unitNums,unitNums_,unitNums!=i && unitNums!=j
						make /free/n=(numBins,numpnts(unitNums_)) other_yy=yy[p][unitNums_[q]]
						matrixop /free other_yyMean=meancols(other_yy^t)		
						switch(pass)
							case 1:
								glmfit(yy_i,{trialTime,yy_j,other_yyMean,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
								break
							case 2:
								glmfit(yy_i,{trialTime,other_yyMean,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
								break
						endswitch
						break
					case 4: // Full model but only with the mean firing rate of other neurons on i's tetrode.  
						if(1 || sameElec)
							extract /free unitNums,unitNums_,unitNums!=i && unitNums!=j && (SameElectrode(df,{i+1,p+1})==1 || SameElectrode(df,{j+1,p+1})==1)
							make /free/n=(numBins,numpnts(unitNums_)) other_yy=yy[p][unitNums_[q]]
							matrixop /free other_yyMean=meancols(other_yy^t)		
							switch(pass)
								case 1:									
									glmfit(yy_i,{trialTime,yy_j,other_yyMean,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
									break
								case 2:
									glmfit(yy_i,{trialTime,other_yyMean,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
									break
							endswitch
						else
							continue
						endif
						break
					case 5: // Full model but only with the mean firing rate of other neurons *not* on i's tetrode.  
						if(1 || sameElec)
							extract /free unitNums,unitNums_,unitNums!=i && unitNums!=j && (SameElectrode(df,{i+1,p+1})==0 && SameElectrode(df,{j+1,p+1})==0)
							make /free/n=(numBins,numpnts(unitNums_)) other_yy=yy[p][unitNums_[q]]
							matrixop /free other_yyMean=meancols(other_yy^t)
							switch(pass)
								case 1:
									glmfit(yy_i,{trialTime,yy_j,other_yyMean,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
									break
								case 2:
									glmfit(yy_i,{trialTime,other_yyMean,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
									break
							endswitch
						else
							continue
						endif
						break
					case 6: // Full model but with *no* other neurons. 
						switch(pass)
							case 1:
								glmfit(yy_i,{trialTime,yy_j,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
								break
							case 2:
								glmfit(yy_i,{trialTime,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
								break
						endswitch
						break
					case 7: // Model without odor identities.  
						switch(pass)
							case 1:
								glmfit(yy_i,{trialTime,yy_j,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,splines=splines,noConstant=1,brief=brief,condition=1)
								break
							case 2:
								glmfit(yy_i,{trialTime,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,splines=splines,noConstant=1,brief=brief,condition=1)
								break
						endswitch
						break
					case 8: // Model without odor timing.  
						switch(pass)
							case 1:
								glmfit(yy_i,{yy_j,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,noConstant=0,brief=brief,condition=1)
								break
							case 2:
								glmfit(yy_i,{OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,noConstant=0,brief=brief,condition=1)
								break
						endswitch
						break
					case 9: // Model without firing rate drift.  
						switch(pass)
							case 1:
								glmfit(yy_i,{trialTime,yy_j,OdorsOn,respPhaseBasis},distr,betas=betas,splines=splines,noConstant=1,brief=brief,condition=1)
								break
							case 2:
								glmfit(yy_i,{trialTime,OdorsOn,respPhaseBasis},distr,betas=betas,splines=splines,noConstant=1,brief=brief,condition=1)
								break
						endswitch
						break
					case 10: // Model without respiration.  
						switch(pass)
							case 1:
								glmfit(yy_i,{trialTime,yy_j,OdorsOn,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=0,brief=brief,condition=1)
								break
							case 2:
								glmfit(yy_i,{trialTime,OdorsOn,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=0,brief=brief,condition=1)
								break
						endswitch
						break
					case 11: // Model with only respiration (and firing rate drift).  
						switch(pass)
							case 1:
								glmfit(yy_i,{yy_j,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},noConstant=0,brief=brief,condition=1)
								break
							case 2:
								glmfit(yy_i,{respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},noConstant=0,brief=brief,condition=1)
								break
						endswitch
						break
					case 12: // Model with only firing rate drift.  
						switch(pass)
							case 1:
								glmfit(yy_i,{yy_j,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},noConstant=0,brief=brief,condition=1)
								break
							case 2:
								glmfit(yy_i,{trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},noConstant=0,brief=brief,condition=1)
								break
						endswitch
						break
					case 13: // Model with nothing (basically mean firing rate).  
						switch(pass)
							case 1:
								glmfit(yy_i,{yy_j},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},noConstant=0,brief=brief,condition=1)
								break
							case 2:
								make /free/n=(numBins) onez=1
								glmfit(yy_i,{onez},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},noConstant=1,brief=brief,condition=1)
								break
						endswitch
						break
					case 14: // Full model w/ no other neurons, and each odor gets it's own response time course.  NEEDS TO BE FIXED TO DO THIS.  
						switch(pass)
							case 1:
								glmfit(yy_i,{trialTime,yy_j,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
								break
							case 2:
								glmfit(yy_i,{trialTime,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
								break
						endswitch
					case 15: // Full model w/ no other neurons, plus an interaction term between odor and cell j.  
						switch(pass)
							case 1:
								wave deviance=deviance_6_15
								if(1)//deviance[i][j]>10)
									make /free/n=(numBins) index=p,randos=gnoise(1)
									sort randos,index
									make /free/n=(numBins,dimsize(OdorsOn,1)) OdorAndSpikeJ = yy_j[index[p]] * OdorsOn[index[p]][q] * (mod(trialTime[index[p]],10)>=4 && mod(trialTime[index[p]],10)<=6)
									OdorAndSpikeJ+=gnoise(0.001)
									glmfit(yy_i,{trialTime,yy_j,OdorsOn,OdorAndSpikeJ,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,betas=betas,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1)
								else
									mu=nan
								endif
								break
							case 2:
								mu=nan
								return 0
								//glmfit(yy_i,{trialTime,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},distr,prior=prior,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=brief,condition=1,train=training)
								break
						endswitch
						break
				endswitch
				wave /d mu//,betas // Referencing 'betas' here gets the global wave, which for some reason is giving a different value.  
				print sum(mu),sum(yy_i)
				switch(pass)
					case 1: 
						mu1[][j][i]=mu[p]
						betas1[][j][i]=betas[p]
						redimension /n=(dimsize(betas,0),-1,-1) betas1
						break
					case 2:
						mu2[][j][i]=mu[p]
						betas2[][j][i]=betas[p]
						redimension /n=(dimsize(betas,0),-1,-1) betas2
						break
				endswitch
				fits+=1
			endfor
			j_start=0
		endfor
		if(pass==1)
			if(save_)
				save /o/p=Correlation mu1 as nameofwave(mu1)+".ibw"
			endif
			if(kill)
				killwaves /z mu1
			endif
		elseif(pass==2)
			if(save_)
				save /o/p=Correlation mu2 as nameofwave(mu2)+".ibw"
			endif
			if(kill)
				killwaves /z mu2
			endif
		endif
	endfor
	printf "Ran %d fits.\r",fits
end

function GLMSanityCheck(df,model,mode[,betas_thresh,mus_thresh,pass_start,pass_end,kill])
	dfref df
	variable model,pass_start,pass_end,kill,betas_thresh,mus_thresh
	string mode
	
	betas_thresh = paramisdefault(betas_thresh) ? 6.5 : betas_thresh
	mus_thresh = paramisdefault(mus_thresh) ? 0.05 : mus_thresh
	pass_start = paramisdefault(pass_start) ? 1 : pass_start
	pass_end = paramisdefault(pass_end) ? 2 : pass_end
	kill = paramisdefault(kill) ? 1 : kill
	cd df	
	pathinfo Correlation
	if(!v_flag)
		newpath /o Correlation
	endif
	wave trials // A PETH trials matrix created by triggering on trial onset for the first of the odors.  
			   // Each row will the contain numOdors trials concatenated.  Result should be numBinsPerTrial x numUnits x 1 x numTrialsPerOdor
	variable numBinsPerTrial=dimsize(trials,0) // If each trial is 10 seconds and bin size is 0.1, then this is equal to 100.  
	variable numUnits=dimsize(trials,1)
	variable numTrialsPerOdor=dimsize(trials,3) // Also equals numTrials in a normal numBinsPerTrial x numUnits x numOdors x numTrials matrix.  
	// Create a wave with one column for each cell which contains concatenated data for the whole experiment.  
	make /o/n=(numBinsPerTrial*numTrialsPerOdor,numUnits) df:spikeCounts /wave=spikeCounts=trials[mod(p,numBinsPerTrial)][q][0][floor(p/numBinsPerTrial)]
	strswitch(mode)
		case "exists":
			string distr = "binomial"
			duplicate /o spikeCounts, spikeExists
			wave yy = spikeExists
			yy=spikeCounts>0
			break
		case "counts":
			distr = "poisson"
			wave yy = spikeCounts
			break
		default:
			printf "No such mode: %s\r",mode
			return -1
	endswitch
	variable i,j,pass
	for(pass=pass_start;pass<=pass_end;pass+=1) // Various possible involvements of unit j.  See muExists 1, 2, 3 above.  
		Prog("Pass",pass-1,2)
		wave betas = df:$("betas"+mode+num2str(pass)+"_"+num2str(model))
		if(pass==1)
			wave mu = GetMu(df,mode,1,model) // Model for predicting spiking in unit i, which also uses unit j.  
		elseif(pass==2)
			wave mu = GetMu(df,mode,2,model) // Model for predicting spiking in unit i, which deliberately does not use unit j.  
		endif
		for(i=0;i<numUnits;i+=1)
			Prog("Unit I",i,numUnits)
			wave yy_i=col(yy,i) // A vector of binary observations about whether or not unit i has a spike in each bin.  
			for(j=1;j<numUnits;j+=1) 
				duplicate /free/r=[][j,j][i,i] mu, mu_
				variable ratio = abs(sum(mu_)/sum(yy_i)-1)
				if(ratio>mus_thresh)
					print pass,i,j,ratio,sum(yy_i)
				endif
				duplicate /free/r=[1,][j,j][i,i] betas,betas_ // All betas except from the constant term.  
				betas_ = abs(betas_)
				if (wavemax(betas_) > betas_thresh)// || numtype(oldBetas[0])==2) // If old betas are small enough.  
					print pass,i,j,wavemax(oldBetas)
				endif
			endfor
		endfor
		if(kill)
			killwaves /z mu
		endif
	endfor
end

function TestGLMs(df,model)
	dfref df
	variable model
	
	cd df	
	wave /sdfr=root: OdorsOn // Identity of the last odor turned on.  
	wave /sdfr=root:resp:e10:phase respPhaseBasis=basis // Basis vectors for the respiratory phase, consisting of sines and cosines of the integer multiples of the instantaneous phase.  
	wave /sdfr=root: trialNum,trialNum2,trialNum3 // Powers of the total time elapsed since recording onset.  
	wave trials // A PETH trials matrix created by triggering on trial onset for the first of the odors.  
			   // Each row will the contain numOdors trials concatenated.  Result should be numBinsPerTrial x numUnits x 1 x numTrialsPerOdor
	variable numBinsPerTrial=dimsize(trials,0) // If each trial is 10 seconds and bin size is 0.1, then this is equal to 100.  
	variable numUnits=dimsize(trials,1)
	variable numTrialsPerOdor=dimsize(trials,3) // Also equals numTrials in a normal numBinsPerTrial x numUnits x numOdors x numTrials matrix.  
	// Create a wave with one column for each cell which contains concatenated data for the whole experiment.  
	make /o/n=(numBinsPerTrial*numTrialsPerOdor,numUnits) df:spikeCounts /wave=spikeCounts=trials[mod(p,numBinsPerTrial)][q][0][floor(p/numBinsPerTrial)]
	duplicate /o spikeCounts, spikeExists
	spikeExists=spikeCounts>0
	variable numBins=dimsize(spikeExists,0)
	wave /sdfr=root: trialTime // Time elapsed since trial onset.  
	wave /z/sdfr=root: training
	if(!waveexists(training))
		make /o/n=(numBins) root:training /wave=training=0
	endif
	//make /o/d/n=(numBins,numUnits,numUnits) df:$("muExists1_"+num2str(model)) /wave=muExists1=nan // Model for predicting spiking in unit i, which also uses unit j.  
	make /o/d/n=(numBins,numUnits,numUnits) df:$("muExists2_"+num2str(model)) /wave=muExists2=nan // Model for predicting spiking in unit i, which deliberately does not use unit j.  
	//make /o/d/n=(200,numUnits,numUnits) df:$("betas1_"+num2str(model)) /wave=betas1=nan // Model for predicting spiking in unit i, which also uses unit j.  
	//make /o/d/n=(200,numUnits,numUnits) df:$("betas2_"+num2str(model)) /wave=betas2=nan // Model for predicting spiking in unit i, which deliberately does not use unit j.  
	wave /sdfr=df betas2 = $("betas2_"+num2str(model))
	make /free/n=9 splines
	splines[0]=3 // Cubic splines.  
	splines[1]=1 // First derivatives match.  
	splines[2]=0 // Apply to the first covariate (trialTime).  
	splines[3]=10 // Repeat every ten units (seconds, the length of a trial).  
	splines[4]=1 // Require continuity between the end of one trial and the beginning of the next.  
	splines[5,]={0,2,6,10} // Spline knots at 0, 2, 6, and 10 seconds into the trial.  0 and 10 are points of continuity between trials.  2 and 6 are odor onset and odor offset, respectively.  
	variable i,j,pass
	
	for(i=0;i<numUnits;i+=1)
		Prog("Unit I",i,numUnits)
		wave spikeExist_i=col(spikeExists,i) // A vector of binary observations about whether or not unit i has a spike in each bin.  
		wave betas2_6
		make /free/d/n=1000 betas = betas2[p][0][i]
		make /free/d/n=1000 priorMeans=0
		make /free/d/n=(1000,1000) priorCovars=p==q ? 2 : 0
		glmfit(spikeExist_i,{trialTime,OdorsOn,respPhaseBasis,trialNum,trialNum2,trialNum3},"binomial",betas=betas,prior=L2norm,priorParams={priorMeans,priorCovars},splines=splines,noConstant=1,brief=5,condition=1,train=training)
		wave mu
		muExists2[][0][i]=mu[p]//mod(p,3)==2 ? mu[floor(p/3)] : nan
	endfor
end
	
static function /wave EventOdors(eventsDF)
	dfref eventsDF
	
	wave /sdfr=eventsDF times,TTL,IgorSweep
	
	newdatafolder /o eventsDF:Odor
	dfref df=eventsDF:Odor
	make /o/n=(numpnts(times)) df:data /wave=Odor=mod(floor(IgorSweep),5)
	extract /o Odor,Odor,TTL==32768
	extract /o times,df:times,TTL==32768
	svar /sdfr=eventsDF type
	string /g df:type=type
	return Odor
end

function /wave SpikeTrainDistances(data,events,pethInstance[,method])
	dfref data,events
	string pethInstance,method
	
	method=selectstring(!paramisdefault(method),"Victor",method)
	wave /wave pethIntervals=NlxA#PETHIntervals(events,pethInstance)
	string pethTriggers=NlxA#PETHtriggers(pethInstance)
	string primaryTrigger=stringfromlist(0,pethTriggers)
	wave intervals=pethIntervals[%$primaryTrigger] // Intervals for primary trigger. 
	make /free/n=(dimsize(intervals,1)) index=p, random=gnoise(1)
	sort random,index
	make /free/n=(2,50) intervals_=intervals[p][index[q]][0] // Use only 20 intervals.  
	wave /sdfr=data clusters
	variable atLeast=1000
	wave clusterIndices=NlxA#ClustersWithSpikes(data,exclude={0},atLeast=atLeast)
	wave counts=NlxA#ClusterCounts(data,atLeast=atLeast)
	duplicate /o counts,$"counts" /wave=poop2//; edit poop2.ld; abort
	
	variable numTrains=dimsize(intervals_,1) // 2 rows, numIntervals columns, numIntervalTypes layers.  
	variable numCells=numpnts(clusterIndices)
	//variable numIntervalTypes=1//dimsize(intervals,2)
	make /free/n=6 costs
	setscale /I x,1,2,costs
	costs=10^x
	variable numCosts=numpnts(costs)
	make /free/n=(numTrains*numCells,numTrains*numCells,numCosts) distances//Cells,numIntervalTypes) distances
	make /o/n=(numCells) distanceMeans=nan
	variable i,j,k
	for(j=0;j<numCosts;j+=1)
		Prog("Cost",j,numCosts)
		variable cost=costs[j]
		for(i=0;i<numCells;i+=1)
			Prog("Cell i",i,numCells)
			variable cluster1=clusterIndices[i]
			for(k=0;k<numCells;k+=1)
				Prog("Cell k",k,numCells)
				if(k==i)
					variable cluster2=clusterIndices[k]
					wave /wave trains=NlxA#Trains(data,{cluster1,cluster2},intervals_,relative=1) // Clusters by Intervals wave of train references.  
					string params
					sprintf params,"COST:%f;NORMALIZE:1;START:0;FINISH:0.5",cost
					wave matrix=SpikeTrainDistanceMatrix(trains,params=params,method=method)
					extract /free matrix,matrixOffDiag,p!=q && numtype(matrix[p][q])==0
					distanceMeans[i]=mean(matrixOffDiag)
				else
					make /free/n=(numTrains,numTrains) matrix=nan
				endif
				distances[i*numTrains,(i+1)*numTrains-1][k*numTrains,(k+1)*numTrains-1][j]=matrix[p-i*numTrains][q-k*numTrains]
			endfor
		endfor
		setdimlabel 2,j,$("COST = "+num2str(cost)),distances
	endfor
	return distances
end

function /wave SpikeTrainDistanceMatrix(w[,method,params])
	wave /wave w // Wave of spike train waves.  
	string method,params
	
	method=selectstring(!paramisdefault(method),"Victor",method)
	params=selectstring(!paramisdefault(params),"",params)
	if(dimsize(w,1)==0) // Only rows.  
		duplicate /free w,w_
		matrixtranspose w_
		wave w=w_
	endif
	variable i,j,numTrains=dimsize(w,1),numCells=dimsize(w,0)
	make /free/n=(numTrains,numTrains) result
	for(i=0;i<numTrains;i+=1)
		//Prog("Train i",i,numTrains)
		wave w1=w[0][i] // Train i from first cell.  
		for(j=0;j<i;j+=1)
			result[i][j]=result[j][i]
		endfor
		for(j=i;j<numTrains;j+=1)
			//Prog("Train J",j,numTrains)
			wave w2=w[min(1,numCells-1)][j] // Train j from second cell (or from first cell if numCells==1).  
			result[i][j]=SpikeTrainDistance(w1,w2,method=method,params=params)
		endfor
	endfor
	return result
end

function SpikeTrainDistance(w1,w2[,method,params])
	wave w1,w2 // Each of these contains the times of one set of spikes.  
	string method,params
	
	method=selectstring(!paramisdefault(method),"Victor",method)
	params=selectstring(!paramisdefault(params),"",params)
	variable tau=numberbykey("TAU",params)
	variable cost=numberbykey("COST",params)
	if(numtype(tau)==2)
		tau=1/cost
	endif
	if(numtype(cost)==2)
		cost=1/tau
	endif
	variable i,j,distance=nan
	strswitch(method)
		case "Van Rossum": // The Van Rossum distance.  
			tau=(numtype(tau)==2) ? 0.01 : tau // 10 ms default.  
			tau=max(tau,0)
			variable delta=numberbykey("DELTA",params) // Sampling frequency for evaluating spike coincidence.  
			// NEED TO CHOOSE A DELTA WHICH IS SUFFICIENTLY SMALLER THAN TAU.  
			delta=(numtype(delta)==2) ? tau/100 : delta   
			variable nTau=10 // Integrate 10 taus past the last spike.  
			if(numpnts(w1) && numpnts(w2))
				variable start=min(wavemin(w1),wavemin(w2))
				variable finish=max(wavemax(w1),wavemax(w2))+nTau*tau
			elseif(numpnts(w1))
				start=wavemin(w1)
				finish=wavemax(w1)+nTau*tau
			elseif(numpnts(w2))
				start=wavemin(w2)
				finish=wavemax(w2)+nTau*tau
			else
				distance=0
				break
			endif
			variable samples=(finish-start)/delta
			make /free/n=(samples) spikes1=0,spikes2=0
			setscale x,start,finish,spikes1,spikes2
			for(i=0;i<numpnts(w1);i+=1)
				variable pp=x2pnt(spikes1,w1[i])
				spikes1[pp]=1
			endfor
			for(i=0;i<numpnts(w2);i+=1)
				pp=x2pnt(spikes2,w2[i])
				spikes2[pp]=1
			endfor
			variable convSamples=nTau*tau/delta
			make /free/n=(convSamples) exponential
			setscale /p x,0,delta,exponential
			exponential=exp(-x/tau)
			convolve exponential,spikes1,spikes2
			//redimension /n=(samples) spikes1,spikes2
//			if(numpnts(w1)>5 && tau<0.1)
//				duplicate /o spikes1,spikes1_
//				duplicate /o spikes2,spikes2_
//				display /k=1 spikes1_,spikes2_
//				abort
//			endif
			matrixop /free result=(delta/tau)*sumsqr(spikes1-spikes2)
			distance=result[0]
			break
		case "Victor": // The victor D_spike metric: http://www-users.med.cornell.edu/~jdvicto/vipu97.html
			//http://www-users.med.cornell.edu/~jdvicto/spkdm.html
			cost=(numtype(cost)==2) ? 100 : cost // 100 per second i.e. 1 per 10 ms default.  
			cost=max(cost,0)
			variable n1=numpnts(w1)
			variable n2=numpnts(w2)
			if(cost==0)
				distance=abs(n1-n2)
			elseif(cost==Inf)
				distance=n1+n2
			else	
				make /free/n=(n1+1,n2+1) scr=0
				// INITIALIZE MARGINS WITH COST OF ADDING A SPIKE
				scr[][0]=p
				scr[0][]=q
				if(n1 && n2)
					for(i=1;i<=n1;i+=1)
      						for(j=1;j<=n2;j+=1)
         						make /free/n=(3) costs={scr[i-1][j]+1, scr[i][j-1]+1, scr[i-1][j-1]+cost*abs(w1[i-1]-w2[j-1])}
         						scr[i][j]=wavemin(costs)
         					endfor
         				endfor
         			endif
         			distance=scr[n1+1][n2+1]
 			endif
 			variable normalize=numberbykey("NORMALIZE",params)
 			if(normalize) // Normalize to be independent of spike counts.  
 				// Normalize between -1 and 1, independent of n1, n2, and n1 - n2.  
 				// As cost -> 0, the normalization will tend to -1, and as cost -> Inf, the normalization will tend to +1.  
 				// The normalized value will be ~ tanh(ln(f(cost))), where f is some polynomial.  
 				// The normalized value also has the interpretation cos(g(cost)), where g is some function and the normalization is the
 				// angle that appears in the law of cosines.  
 				distance=((distance^2-n1^2-n2^2)/(2*n1*n2))
 			endif
 			break
 		case "Victor Interval": // The Victor D_interval metric: http://www-users.med.cornell.edu/~jdvicto/metricdf.html#interval
			//http://www-users.med.cornell.edu/~jdvicto/spkdf.html
			cost=(numtype(cost)==2) ? 100 : cost // 100 per second i.e. 1 per 10 ms default.  
			cost=max(cost,0)
			n1=numpnts(w1)+1 // Number of intervals.  
			n2=numpnts(w2)+1 // Number of intervals. 
			start=numberbykey("START",params)
			finish=numberbykey("FINISH",params)
			if(numpnts(w1) && numpnts(w2))
				start=numtype(start) ? min(wavemin(w1),wavemin(w2)) : start
				finish=numtype(finish) ? max(wavemax(w1),wavemax(w2)) : finish
			elseif(numpnts(w1))
				start=numtype(start) ? wavemin(w1) : start
				finish=numtype(finish) ? wavemax(w1) : finish
			elseif(numpnts(w2))
				start=numtype(start) ? wavemin(w2) : start
				finish=numtype(finish) ? wavemax(w2) : finish
			else
				distance=0
				break
			endif
			variable interval=finish-start // From first to last spike, such that boundary intervals have length zero.  
			
			make /free/n=(n1+1,n2+1) scr=0
      			scr[][0]=p
      			scr[0][]=q
      			for(i=1;i<=n1;i+=1)
      				if(i==1 && i==n1)
      					variable di=interval
      				elseif(i==1 && i<n1)
      					di=w1[i-1]
      				elseif(i>1 && i==n1)
      					di=interval-w1[i-2]
      				elseif(i>1 && i<n1) 
      					di=w1[i-1]-w1[i-2]
   				endif
     				for(j=1;j<=n2;j+=1)
      					if(j==1 && j==n2)
      						variable dj=interval
      					elseif(j==1 && j<n2)
      						dj=w2[j-1]
      					elseif(j>1 && j==n2)
      						dj=interval-w2[j-2]
      					elseif(j>1 && j<n2) 
      						dj=w2[j-1]-w2[j-2]
      					endif
      					variable dist=abs(di-dj)
      					variable iend=0,jend=0
      					if(i== n1)//if(i==1 || i== n1)
      					// I changed this and the j line from the original FORTRAN code, which I think was mistaken.  
      					// In the original code, a train with one spike would have both of its intervals meeting this condition, and consequently
      					// dist would be forced to 0 when it shouldn't be.  Comparison of two trains with one spike each would give a distance of 0.  
      					// I think that condition should just give the normal Victor distance.  
      						iend=1
      					endif
      					if(j== n2)//if(j==1 || j==n2)
      						jend=1
      					endif
      					if(iend==0 && jend==0)
      					elseif(iend==1 && jend==1)
      						dist=0
      					elseif(iend==1)
      						dist=max(0,di-dj)
      					elseif(jend==1)
      						dist=max(0,dj-di)
      					endif
      					make /free/n=3 costs={scr[i-1][j]+1,scr[i][j-1]+1,scr[i-1][j-1]+cost*dist}
      					scr[i][j]=wavemin(costs)
      				endfor
     			endfor
     			distance=scr[n1][n2]
     			normalize=numberbykey("NORMALIZE",params)
     			if(normalize) // Normalize to be independent of spike counts.  
 				// See note for "Victor Distance".  
 				distance=((distance^2-n1^2-n2^2)/(2*n1*n2))
 			endif
 			break
 		case "Schreiber": // Smoothed cross-correlation.  
 			//http://www.dauwels.com/files/crp145.pdf
 			start=numberbykey("START",params)
			finish=numberbykey("FINISH",params)
 			if(numpnts(w1) && numpnts(w2))
				start=numtype(start) ? min(wavemin(w1),wavemin(w2)) : start
				finish=numtype(finish) ? max(wavemax(w1),wavemax(w2)) : finish
			elseif(numpnts(w1))
				start=numtype(start) ? wavemin(w1) : start
				finish=numtype(finish) ? wavemax(w1) : finish
			elseif(numpnts(w2))
				start=numtype(start) ? wavemin(w2) : start
				finish=numtype(finish) ? wavemax(w2) : finish
			else
				distance=0
				break
			endif
			tau=(numtype(tau)==2) ? 0.01 : tau // 10 ms default.  
			tau=max(tau,0)
			delta=numberbykey("DELTA",params) // Sampling frequency for evaluating spike coincidence.  
			delta=(numtype(delta)==2) ? tau/10 : delta   
			wave spikes1=SpikeTimes2Raster(w1,start,finish,delta=delta)
			wave spikes2=SpikeTimes2Raster(w2,start,finish,delta=delta)
			string kernel=stringbykey("KERNEL",params)
			kernel=selectstring(strlen(kernel),"Gaussian",kernel)
			variable smoothingSamples=tau/delta
			strswitch(kernel)
				case "Gaussian":
					smooth /e=2 smoothingSamples^2,spikes1,spikes2
					break
			endswitch
			distance=statscorrelation(spikes1,spikes2) // Similarity, actually.  
 			break
 	endswitch
 	return distance
end

function /wave SpikeTimes2Raster(w,start,finish[,delta])
	wave w
	variable start,finish,delta
	
	make /free/n=0 result
	if(numpnts(w))
		delta=paramisdefault(delta) ? 0.001 : delta // 1 ms default.  
		variable i,samples=(finish-start)/delta
		redimension /n=(samples) result
		result=0
		setscale x,start,finish,result
		for(i=0;i<numpnts(w);i+=1)
			variable pp=x2pnt(result,w[i])
			result[pp]+=1
		endfor
	endif
	return result
end

// Returns the timing of spikes 1 through N that follow a stimulus.  Organized so that each layer is a cell, each row is a trial/trigger, and each column is an integer spike number.  
function /wave NthSpikeTiming(df,triggerTimes[,nMax])
	dfref df
	wave triggerTimes // Trigger times for resetting the spike count.  
	variable nMax
	
	nMax=paramisdefault(nMax) ? 10 : nMax
	wave /sdfr=df times,clusters
	wave hist=densehistogram(clusters,exclude={0})
	
	make /free/n=(numpnts(triggerTimes),nMax,numpnts(hist)) Timings=nan
	variable i,j
	for(j=0;j<numpnts(hist);j+=1) // Iterate over cells.
		variable cell=str2num(getdimlabel(hist,0,j))  
		extract /free times,cellTimes,clusters==cell
		for(i=0;i<numpnts(triggerTimes);i+=1)
			extract /free cellTimes,cellTriggerTimes,cellTimes>triggerTimes[i]
			Timings[i][][j]=(q<numpnts(cellTriggerTimes)) ? cellTriggerTimes[q]-triggerTimes[i] : nan
		endfor
		setdimlabel 2,j,$num2str(cell),Timings
	endfor
	return Timings
end

function makeSqrtPoissonCI(ci)
	variable ci // Confidence interval, e.g. 0.95
	make /o/n=(100,2) sqrtPoissonCI=nan
	setscale x,0,12,sqrtPoissonCI
	ci=1-ci
	variable i
	for(i=0;i<dimsize(sqrtPoissonCI,0);i+=1)
		prog("mu",i,dimsize(sqrtPoissonCI,0))
		variable mu=dimoffset(sqrtPoissonCI,0)+i*dimdelta(sqrtPoissonCI,0)
		make /o/n=100000 sqrtPoissonNoise=sqrt(poissonnoise(mu))-sqrt(mu)+gnoise(0.001)
		ecdf(sqrtPoissonNoise)
		sqrtPoissonCI[i][0]=sqrtPoissonNoise(ci/2)
		sqrtPoissonCI[i][1]=sqrtPoissonNoise(1-ci/2)
	endfor
end

#if exists("JointHistogram")
function CorrelationByPhase(phase,dataDF[,diff,numPhaseBins])
	wave phase
	dfref dataDF
	variable diff // Differences in spikes from previous cycle.  
	variable numPhaseBins
	
	numPhaseBins=paramisdefault(numPhaseBins) ? 1: numPhaseBins
	
	wave /z/sdfr=dataDF times,clusters
	wave clusterIndex=NlxA#ClustersWithSpikes(dataDF)
	variable numUnits=numpnts(clusterIndex)
	numUnits=max(1,numUnits)
	
	
	variable i,phaseWidth=pi
	variable thresh=cos(phaseWidth/2)
	make /o/n=(numUnits,numUnits,numPhaseBins) totalCorrsByPhase
	wave crossings=NlxB#PhaseCrossings(phase,0,"up")
	variable numCycles=numpnts(crossings)-1 // Number of complete cycles.  
	make /o/n=(numCycles,numPhaseBins,numUnits) dataDF:spikesPerCycle /wave=SpikesPerCycle
	setscale /p y,-pi,2*pi/numPhaseBins,SpikesPerCycle
	
	// Compute spike counts in each phase bin in each respiratory cycle for each unit.  
	variable cycle,bin
	for(i=0;i<numUnits;i+=1)
		Prog("Unit",i,numUnits)
		extract /free Times,UnitTimes,Clusters==ClusterIndex[i]
		duplicate /free UnitTimes,Cycles,Phases
		Cycles=binarysearch(crossings,UnitTimes[p])
		Phases=phase(Phases[p])
		make /free/n=(numCycles) cycleBins=p
		make /free/n=(numPhaseBins) phaseBins=-pi+2*pi*p/numPhaseBins 
		jointhistogram /xbwv=cycleBins /ybwv=phaseBins cycles,phases
		wave m_jointHistogram
		SpikesPerCycle[][][i]+=m_jointHistogram[p][q]
	endfor	 
	
	return 0
	
	if(diff)
		differentiate /meth=1/dim=0 SpikesPerCycle
	endif
	
	duplicate /free SpikesPerCycle CycleSpiked
	CycleSpiked=SpikesPerCycle>0
	imagetransform /meth=2 xProjection CycleSpiked // Probability of at least one spike per cell per phase bin.    
	wave m_xprojection
	make /o/n=(numUnits,numUnits,numPhaseBins) expected=m_xprojection[p][r]*m_xprojection[q][r] // Expected fraction of cycles in which both cells spiked.  
	wavestat(w=expected)
	make /o/n=(numUnits,numUnits,numPhaseBins) observed=0
	for(i=0;i<cycles;i+=1)
		observed+=(SpikesPerCycle[i][p][r]>0 && SpikesPerCycle[i][q][r]>0)
	endfor
	make /o/n=(numUnits,numUnits,numPhaseBins) phaseSurprise=(statsbinomialcdf(observed,expected,cycles)+statsbinomialcdf(observed-1,expected,cycles))/2
	phaseSurprise=numtype(phaseSurprise) ? statsnormalcdf(observed,expected*cycles,sqrt(cycles*expected*(1-expected))) : phaseSurprise
	wavestat(w=observed)
	
	for(i=0;i<numpnts(phaseSurprise);i+=1)
		if(phaseSurprise[i]==0 || numtype(phaseSurprise[i]))
			printf "%f,%d,%f\r",phaseSurprise[i],observed[i],expected[i]*cycles
		endif
	endfor
	
	phaseSurprise=(observed<5 || expected<(5/cycles)) ? nan : phaseSurprise
	
	//int cycles
	for(bin=0;bin<numPhaseBins;bin+=1)
		duplicate /free phase,mask
		mask=sin(phase+2*pi*i/numPhaseBins) > thresh
		make /o/n=(cycles,numUnits) binSpikes=SpikesPerCycle[p][q][bin]
		matrixop /free binSpikesShift=rotaterows(binSpikes,1)
		matrixop /free corrMatrix=((binSpikes^t x binSpikes) - (binSpikes^t x binSpikesShift)) / (cycles*sqrt(varcols(binSpikes)^t x varcols(binSpikes)))
		totalCorrsByPhase[][][bin]=corrMatrix[p][q]
	endfor
	
	//totalCorrsByPhase[][][bin]=(observed<5 || expected<(5/cycles)) ? nan : totalCorrsByPhase
end

function /wave DownsamplePhase(phase,rate)
	wave phase
	variable rate
	
	duplicate /o phase $(getwavesdatafolder(phase,2)+"_ds") /wave=ds
	unwrap 2*pi,ds
	resample /rate=(rate) ds
	ds+=pi
	ds=mod(ds,2*pi)-pi
	return ds
end

function PhasePreferenceOdor(phase,dataDF,numPhaseBins)
	wave phase
	dfref dataDF
	variable numPhaseBins
	
	wave /z/sdfr=dataDF times,clusters
	wave clusterIndex=NlxA#ClustersWithSpikes(dataDF)
	variable numUnits=numpnts(clusterIndex)
	numUnits=max(1,numUnits)
	
	wave odorTimes=root:D2010_07_16:events:E12:times
	wave odorIdentities=root:D2010_07_16:events:E12:odors
	make /free/n=(numUnits) unitBins=clusterIndex[p]
	make /free/n=(numPhaseBins) phaseBins=-pi+2*pi*p/numPhaseBins 	
	
	variable numOdors=5
	make /o/n=(numUnits,numUnits,numOdors,5) phaseCorrs	
	variable odor,j,i
	for(odor=0;odor<numOdors;odor+=1)
		extract /o odorTimes,currOdorTimes,odorIdentities==odor
		for(j=0;j<5;j+=1)
			make /free/n=(numPhaseBins,numUnits) phaseTuning=0
			//for(i=0;i<numpnts(currOdorTimes);i+=1)
			for(i=0;i<numpnts(odorTimes);i+=1)
				//variable t=currOdorTimes[i]
				variable t=odorTimes[i]
				variable tMin=t-4+2*j
				variable tMax=t-2+2*j
				extract /free times,times_,times[p]>tMin && times[p]<tMax
				extract /free clusters,clusters_,times[p]>tMin && times[p]<tMax
				duplicate /free times_,phases
				phases=phase(times_[p])
				jointhistogram /xbwv=phaseBins /ybwv=unitBins phases,clusters_
				wave m_jointHistogram
				phaseTuning+=m_jointHistogram
			endfor
			wave phaseCorr=CorrelationMatrix({phaseTuning})
			phaseCorrs[][][odor][j]=phaseCorr[p][q]
		endfor
	endfor
end

function /wave PhaseCorrelation(phase,dataDF,numPhaseBins)
	wave phase
	dfref dataDF
	variable numPhaseBins
	
	wave /z/sdfr=dataDF times,clusters
	wave clusterIndex=NlxA#ClustersWithSpikes(dataDF)
	variable numUnits=numpnts(clusterIndex)
	numUnits=max(1,numUnits)
	
	make /free/n=(numUnits) unitBins=clusterIndex[p]
	make /free/n=(numPhaseBins) phaseBins=-pi+2*pi*p/numPhaseBins 	
	
	make /o/n=(numUnits,numUnits) phaseCorrs	
	duplicate /free times,phases
	phases=phase(times[p])
	jointhistogram /xbwv=phaseBins /ybwv=unitBins phases,clusters
	wave m_jointHistogram
	return CorrelationMatrix({m_jointhistogram})
end
#endif

function TotalCorrelationConsiderPhase()
	wave PETH=NlxA#MakePETHfromPanel(keepTrials=1)
	dfref dataDF=$getwavesdatafolder(PETH,1)
	wave /sdfr=dataDF trials,phaseTuning
	wave totalCorrs=TotalCorrelation(trials,cycloHistograms={phaseTuning})
end

// A vector with spike waveform isolation for each unit compared to all other units.  
function TotalIsolation(dataDF,numUnits)
	dfref dataDF
	variable numUnits
	
	dfref mergedDF=ParentFolder(dataDF)
	dfref experimentDF=ParentFolder(mergedDF)
	string epoch=getdatafolder(0,dataDF)
		
	variable i,j
	string electrodes=""
	make /o/n=(numUnits) totalIsolations=nan
	make /free/n=0/wave isolations
	for(i=0;i<numUnits;i+=1)
		string source1=SourceElectrode(dataDF,i)
		if(!strlen(source1))
			continue
		endif
		string electrode1=stringfromlist(0,source1,":")
		if(whichlistitem(electrode1,electrodes)<0)	
			dfref electrodeDF=experimentDF:$electrode1
			dfref df=electrodeDF:$epoch
			electrodes+=electrode1+";"
			isolations[numpnts(isolations)]={ClusterIsolation(df)}
		endif
		variable index=whichlistitem(electrode1,electrodes)
		wave isolation=isolations[index]
		variable unit1=str2num(stringfromlist(1,source1,":"))
		totalIsolations[i]=isolation[unit1][dimsize(isolation,1)-1]
	endfor
end

// A matrix of spike waveform isolation between each pair of units in a recording session.  0 if they are on different electrode, > 0 if they are on the same electrode.  Lower is better.  
function PairwiseIsolation(dataDF,numUnits)
	dfref dataDF
	variable numUnits
	
	dfref mergedDF=ParentFolder(dataDF)
	dfref experimentDF=ParentFolder(mergedDF)
	string epoch=getdatafolder(0,dataDF)
		
	variable i,j
	string electrodes=""
	make /o/n=(numUnits,numUnits) unitIsolations=nan
	make /free/n=0/wave isolations
	for(i=0;i<numUnits;i+=1)
		string source1=SourceElectrode(dataDF,i)
		if(!strlen(source1))
			continue
		endif
		string electrode1=stringfromlist(0,source1,":")
		if(whichlistitem(electrode1,electrodes)<0)	
			dfref electrodeDF=experimentDF:$electrode1
			dfref df=electrodeDF:$epoch
			electrodes+=electrode1+";"
			isolations[numpnts(isolations)]={ClusterIsolation(df)}
		endif
		variable index=whichlistitem(electrode1,electrodes)
		wave isolation=isolations[index]
		variable unit1=str2num(stringfromlist(1,source1,":"))
		for(j=0;j<numUnits;j+=1)
			string source2=SourceElectrode(dataDF,j)
			if(!strlen(source2))
				continue
			endif
			string electrode2=stringfromlist(0,source2,":")
			variable unit2=str2num(stringfromlist(1,source2,":"))
			if(stringmatch(electrode1,electrode2))
				unitIsolations[i][j]=isolation[unit1][unit2]
			else
				unitIsolations[i][j]=0
			endif
		endfor
	endfor
end

function /wave FilterResp(signalDF[,lo,smooth1,smooth2])
	dfref signalDF
	variable lo,smooth1,smooth2
	
	lo=paramisdefault(lo) ? 10 : lo
	smooth1=paramisdefault(smooth1) ? 10 : smooth1
	smooth2=paramisdefault(smooth2) ? 100 : smooth2
	wave /z/sdfr=signalDF raw
	if(!waveexists(raw))
		wave /z/sdfr=signalDF data
		duplicate /o data signalDF:raw /wave=raw
	endif
	duplicate /o raw, signalDF:data /wave=data 
	bandpassfilter(data,lo,0)
	duplicate /free data,data_med1; smooth /m=0 smooth1,data_med1; data-=data_med1; 
	duplicate /free data,data_med2; smooth /m=0 smooth2,data_med2; data-=data_med2
	return data
end

// The method from the Journal of Neuroscience Methods, 2006 paper.  
// Assumes that the respiration signal is already filtered.  
// Really spreads apart the phase region during inspiration, so that preferred phase will look broader, but will probably be more accurate.  
Function /WAVE RespiratoryPhase(RespWave[,IEoffset,maxRate,minAmpl,EIthresh1,EIthresh2])
	Wave RespWave
	Variable IEoffset // The signal amplitude at which inspiration gives way to expiration.  Usually zero.  
	Variable maxRate // Maximum respiration rate (Hz).  
	Variable minAmpl // Minimum respiratory amplitude during expiration.  
	Variable EIthresh1 // Fraction of inspiration extremum that must be crossed to signify E to I transition (the first threshold).  
	Variable EIthresh2 // Fraction of inspiration derivative extremum that must be crossed to signify E to I transition (the second threshold).  
	
	IEoffset=ParamIsDefault(IEOffset) ? StatsMedian(RespWave) : IEOffset
	maxRate=ParamIsDefault(maxRate) ? 15 : maxRate
	minAmpl=ParamIsDefault(minAmpl) ? (wavemax(RespWave)-IEoffset)/2 : minAmpl
	EIthresh1=ParamIsDefault(EIthresh1) ? 0.2 : EIthresh1
	EIthresh2=ParamIsDefault(EIthresh2) ? 0.2 : EIthresh2
	
	Variable minPeriod=1/maxRate // Minimum respiratory period (s).  
	Duplicate /o/FREE RespWave,Filtered
	Filtered*=-1 // Because the signals I record and the signals in the paper are of opposite sign.  
	Filtered-=IEOffset // Subtract off the IEOffset so that an amplitude of 0 represents the I to E transition and so the low-pass filter will behave nicely.  
	Variable samplingInterval=dimdelta(RespWave,0) // Sampling interval in seconds per sample.  
	Make /FREE EThresh
	
	// Find I to E crossings.  
	FindLevels /Q/EDGE=1/M=(minPeriod)/D=EThresh Filtered,minAmpl
	Duplicate /o EThresh,IEpoints
	Variable i
	for(i=0;i<numpnts(EThresh);i+=1)
		FindLevel /Q/R=(EThresh[i],EThresh[i]-minPeriod) Filtered,0 // Search backwards from each E threshold for an I to E crossing.  
		if(!V_flag) // If a crossing was found...  
			IEPoints[i]=V_LevelX // Mark it as an I to E crossing.  
		endif
	endfor
	if(numtype(IEPoints[0])) // If the first I to E crossing (which would precede the first EThresh crossing) is not found...  
		DeletePoints 0,1,IEPoints // Then delete this point which contains nothing.  
	endif
	
	// Find E to I crossings.  
	Differentiate /METH=1 Filtered /D=DiffWave
	Duplicate /o IEPoints,EIPoints 
	EIPoints=NaN
	for(i=0;i<numpnts(IEPoints)-1;i+=1)
		WaveStats /Q/M=1/R=(IEPoints[i],IEPoints[i+1]) Filtered
		Variable iPeak=V_min // Peak (negative) of inspiration for each cycle.  
		WaveStats /Q/M=1/R=(IEPoints[i],V_minloc) DiffWave
		Variable iDiffPeak=V_min // Peak (negative) of the derivative of inspiration for each cycle.  
		FindLevel /EDGE=2/Q/R=(IEPoints[i],IEPoints[i+1]) Filtered,iPeak*EIthresh1 // Search for a crossing of the first threshold.  
		if(DiffWave(V_LevelX)>iDiffPeak*EIthresh2) // If the second threshold has not already been crossed.  
			FindLevel /EDGE=2/Q/R=(V_LevelX,IEPoints[i+1]) DiffWave,iDiffPeak*EIthresh2 // Search for a crossing of the second threshold.  
			if(V_flag) // No level was found.  
				continue // Do not assign a time to EIPoints[i].  
			endif
		endif
		EIPoints[i]=V_LevelX // Mark this point at which both threshold have been crossed as an E to I crossing.  
	endfor

	// Compute phase from I to E and E to I crossings.  
	Wave Anchors=Filtered
	Anchors=NaN
	for(i=0;i<numpnts(IEPoints);i+=1)
		Anchors[x2pnt(Anchors,IEPoints[i])]=2*pi*i
		Anchors[x2pnt(Anchors,EIPoints[i])]=pi+2*pi*i
	endfor
	Duplicate /o Anchors,PhaseWave
	//PhaseWave=Anchors
	if(numpnts(Anchors)<2) // Not enough anchor points to do interpolation.  
		return PhaseWave
	endif
	Interpolate2 /Y=PhaseWave /T=1 Anchors
	Variable firstIEpoint=x2pnt(PhaseWave,IEPoints[0])
	Variable lastIEpoint=x2pnt(PhaseWave,IEPoints[numpnts(IEPoints)-1])
	PhaseWave[0,firstIEpoint-1]=NaN // Set phases before first I to E crossing to NaN.  
	PhaseWave[lastIEpoint+1,]=NaN // Set phases after last I to E crossing to NaN.  
	PhaseWave=mod(PhaseWave,2*pi)
	PhaseWave=numtype(RespWave) || RespWave==0 ? NaN : PhaseWave // Get rid of points that didn't make sense in the source.  
	KillWaves /Z IEPoints,EIPoints,DiffWave
	return PhaseWave
End

// Set the negative peaks to be phase 0 and interpolate in between.  
// Assumes that the respiration signal is already filtered.  
Function /WAVE RespiratoryPhaseSimple(signalDF[,lo,hi,minAmpl])
	dfref signalDF
	variable lo,hi // Bandpass filter cutoffs.  
	variable minAmpl // Minimum respiratory amplitude during expiration.  This will be a positive number, but used to search for a negative threshold crossing.  
	
	lo=paramisdefault(lo) ? Inf : lo
	hi=paramisdefault(hi) ? 0 : hi
	minAmpl=paramisdefault(minAmpl) ? 100 : minAmpl
	wave filtered=FilterResp(signalDF)
	duplicate /o filtered root:crap
	duplicate /free PeakFinder(filtered,minAmpl) peaks

	// Compute phase from level crossings.  
	Duplicate /free filtered,anchors
	anchors=NaN
	variable i
	anchors[0]=0
	anchors[numpnts(anchors)-1]=0
	for(i=0;i<numpnts(peaks);i+=1)
		anchors[x2pnt(anchors,peaks[i])]=2*pi*i
	endfor
	newdatafolder /o signalDF:phase
	dfref phaseDF=signalDF:phase
	duplicate /o anchors,phaseDF:data /wave=phases
	if(numpnts(anchors)<2) // Not enough anchor points to do interpolation.  
		return phases
	endif
	Interpolate2 /Y=phases /T=1 anchors
	Variable firstIEpoint=x2pnt(phases,peaks[0])
	Variable lastIEpoint=x2pnt(phases,peaks[numpnts(peaks)-1])
	phases[0,firstIEpoint-1]=NaN // Set phases before first I to E crossing to NaN.  
	phases[lastIEpoint+1,]=NaN // Set phases after last I to E crossing to NaN.  
	phases=mod(phases,2*pi)
	phases=numtype(filtered) || filtered==0 ? NaN : phases // Get rid of points that didn't make sense in the source.  
	phases-=pi
	return phases
End

// Set the negative peaks to be phase 0 and interpolate in between.  
// Assumes that the respiration signal is already filtered.  
Function /WAVE RespiratoryPhaseNew(RespWave[,thresh,dThresh,minFreq,maxFreq])
	Wave RespWave
	variable thresh // A fractional threshold for inspiration onset and expiration offset.  Relative to the positive peak of inspiration and negative peak of expiration.  
	variable dthresh // Same as thresh, but for slopes.  Both thresholds must be crossed to mark inspiration onset or expiration offset.  
	variable minFreq // Minimum respiration frequency.  
	variable maxFreq // Maximum respiration frequency.  
	
	thresh=paramisdefault(thresh) ? 0.1 : thresh
	dthresh=paramisdefault(dthresh) ? 0.1 : dthresh
	minFreq=paramisdefault(minFreq) ? 1 : minFreq
	maxFreq=paramisdefault(maxFreq) ? 5 : maxFreq
	
	// Find crossings of minAmpl and -minAmpl, which will become -pi/2 and pi/2.  
	variable /c simpleLevel=BestThreshold(RespWave)
	make /free up,down
	FindLevels /Q/EDGE=1/M=0.1/d=up RespWave,imag(simpleLevel)
	FindLevels /Q/EDGE=1/M=0.1/d=down RespWave,real(simpleLevel)
	
	// Keep only pairs of crossings that are sensical.  This will solve alignment problems between the waves 'up' and 'down'.  
	make /free/n=(numpnts(up),numpnts(down)) diffs=down[q]-up[p]
	extract /o/free/indx diffs,diffsIndex,(diffs>0 && diffs<0.5) // An inspiration/expiration event should be 0 to 0.5 seconds.  
	make /free/n=(numpnts(diffsIndex)) ups=mod(diffsIndex,numpnts(up))
	make /free/n=(numpnts(diffsIndex)) downs=floor(diffsIndex/numpnts(up))
	ups=up[ups]
	downs=down[downs]
	
	// Find the inspiration/expiration boundary, which will become 0.  
	duplicate /free RespWave,dRespWave
	smooth 25,dRespWave
	differentiate dRespWave
	duplicate /free ups,boundaries
	variable i
	for(i=0;i<numpnts(ups);i+=1)
		wavestats /q/r=(ups[i],downs[i]) dRespWave
		boundaries[i]=v_minloc
	endfor
	
	// Refine the above crossings to be a fraction of the maximum and maximum slope in the region between 'up' and 'down'.  
	variable med=statsmedian(RespWave)
	for(i=0;i<numpnts(ups);i+=1)
		WaveStats /Q/M=1/R=(ups[i],downs[i]) RespWave
		variable upLevel=med+thresh*(V_max-med)
		variable downLevel=med+thresh*(V_min-med)
		
		WaveStats /Q/M=1/R=(ups[i],downs[i]) dRespWave
		variable upLevelD=dThresh*V_max
		variable downLevelD=dThresh*V_min
		
		FindLevel /EDGE=1/Q/R=(boundaries[i]-1/maxFreq,boundaries[i]) RespWave,upLevel // Search for a crossing of the signal threshold.  
		variable upLevelX=V_levelX*(!v_flag)
		FindLevel /EDGE=1/Q/R=(boundaries[i]-1/maxFreq,boundaries[i]) dRespWave,upLevelD // Search for a crossing of the dSignal threshold.  
		variable upLevelDX=V_levelX*(!v_flag)
		
		FindLevel /EDGE=1/Q/R=(boundaries[i],boundaries[i]+1/maxFreq) RespWave,downLevel // Search for a crossing of the signal threshold.  
		variable downLevelX=V_levelX*(!v_flag)
		FindLevel /EDGE=1/Q/R=(boundaries[i],boundaries[i]+1/maxFreq) dRespWave,downLevelD // Search for a crossing of the dSignal threshold.  
		variable downLevelDX=V_levelX*(!v_flag)
		
		if(upLevelX && upLevelDX)
			ups[i]=max(upLevelX,upLevelDX) // Mark this point at which both thresholds have been crossed.  
		else
			ups[i]=NaN
		endif
		if(downLevelX && downLevelDX)
			downs[i]=max(downLevelX,downLevelDX) // Mark this point at which both thresholds have been crossed.  
		else
			downs[i]=NaN
		endif
	endfor
	
	// Interpolate the phase from the level crossings.  
	wave Anchors=dRespWave // reuse dRespWave to save memory.  
	Anchors=NaN
	Anchors[0]=0
	Anchors[numpnts(Anchors)-1]=0
	for(i=0;i<numpnts(ups);i+=1)
		Anchors[x2pnt(Anchors,ups[i])]=0+2*pi*i
		Anchors[x2pnt(Anchors,boundaries[i])]=pi/2+2*pi*i
		Anchors[x2pnt(Anchors,downs[i])]=pi+2*pi*i
	endfor
	Duplicate /o Anchors,PhaseWave
	if(numpnts(Anchors)<2) // Not enough anchor points to do interpolation.  
		return PhaseWave
	endif
	Interpolate2 /Y=PhaseWave /T=1 Anchors
	Variable firstBoundaryPoint=x2pnt(PhaseWave,boundaries[0])
	Variable lastBoundaryPoint=x2pnt(PhaseWave,boundaries[numpnts(boundaries)-1])
	PhaseWave[0,firstBoundaryPoint-1]=NaN // Set phases before first I to E crossing to NaN.  
	PhaseWave[lastBoundaryPoint+1,]=NaN // Set phases after last I to E crossing to NaN.  
	PhaseWave=mod(PhaseWave,2*pi) // Wrap.  
	PhaseWave-=pi // Convert to range -pi to pi
	
	// Get rid of points that don't make sense
	for(i=0;i<numpnts(ups);i+=1)
		if(boundaries[i]-ups[i]>1/minFreq)
			//PhaseWave[x2pnt(PhaseWave,ups[i]),x2pnt(PhaseWave,boundaries[i])]=NaN
		endif
		if(downs[i]-boundaries[i]>1/minFreq)
			//PhaseWave[x2pnt(PhaseWave,boundaries[i]),x2pnt(PhaseWave,downs[i])]=NaN
		endif
		if(ups[i]-downs[i-1]>1/minFreq)
			PhaseWave[x2pnt(PhaseWave,downs[i-1]),x2pnt(PhaseWave,ups[i])]=NaN
		endif	
	endfor
	PhaseWave=numtype(RespWave) || RespWave==0 ? NaN : PhaseWave  
	return PhaseWave
End

Function /wave OdorStimIdentity([epoch,message])
	variable epoch
	string message
	
	epoch=paramisdefault(epoch) ? -1 : epoch
	
	wave /sdfr=root: IgorT
	dfref stims=NlxA#ExtractEvents("stim",epoch=epoch)
	wave /sdfr=stims Times
	make /o/n=(numpnts(Times)) stims:odors /wave=OdorNum=str2num(SweepOdor(binarysearch(IgorT,Times[p]),numeric=1))
	return OdorNum
End

Function OdorState(template[,epoch,message])
	wave template // Wave to overwrite with odor identity (numeric).  
	variable epoch
	string message
	
	epoch=paramisdefault(epoch) ? -1 : epoch
	message=selectstring(paramisdefault(message),message,"Cheetah 160 Digital Input Port TTL (0xFFFF8000)")
	
	dfref stims=NlxA#ExtractEvents("stim",epoch=epoch)
	wave OdorNum=OdorStimIdentity(epoch=epoch)
	wave /sdfr=stims times
	Events2Binary(times,template,eventNums=OdorNum,after=2)
End

function TTLs2Odors(ttl)
	wave ttl
	
	duplicate /o ttl, $(getwavesdatafolder(ttl,1)+"Odors") /wave=odors
	odors=nan
	variable i=0,j=0
	for(i=0;i<numpnts(ttl);i+=1)
		if(ttl[i]>0)
			odors[i]=mod(j,5)
			j+=1
		endif
	endfor
end

function RosePlot(tuningMatrix[,rates,phase_shift,no_plot])
	wave tuningMatrix // Assumes this scaled to have phase (the unit circle) respresented in X.  
	wave rates // Wave of corresponding average spike rates for color-coding.  
	variable phase_shift // Rotate phase by this amount to match conventions in other figures.  
	variable no_plot
	
	dfref df = getwavesdatafolderdfr(tuningMatrix)
	variable n_phaseBins = dimsize(tuningMatrix,0)
	variable n_cells = dimsize(tuningMatrix,1)
	make /o/n=(n_phaseBins+1,n_cells) df:rosePlot_X /wave=XX,df:rosePlot_Y /wave=YY
	copyscales /p tuningMatrix,XX,YY
	setscale /p x,dimoffset(tuningMatrix,0)+phase_shift,dimdelta(tuningMatrix,0),XX,YY
	if(!no_plot)
		display as "Rose Plot"
	endif
	if(!paramisdefault(rates))
		duplicate /free rates log_rates
		log_rates = log(rates)+log(2)
		wavestats /q/m=1 log_rates
		variable min_rate = -2//v_min
		variable max_rate = 2//v_max
		colortab2wave yellowhot
		make /o/n=5 df:tick_values /wave=tick_values = p-2
		make /o/t/n=5 df:tick_labels /wave=tick_labels = num2str(10^(tick_values[p]))
		wave m_colors
		setscale x,min_rate,max_rate,m_colors
	endif
	variable cell
	for(cell=0;cell<=n_cells;cell+=1)
		XX[][cell] = tuningMatrix[mod(p,n_phaseBins)][cell]*cos(x)
		YY[][cell] = tuningMatrix[mod(p,n_phaseBins)][cell]*sin(x)
		if(!no_plot)
			if(!paramisdefault(rates))
				variable rate = log_rates[cell]
				variable red = m_colors(rate)[0]
				variable green = m_colors(rate)[1]
				variable blue = m_colors(rate)[2]
			endif
			if(log_rates[cell]>-1.5)
				appendtograph /c=(red,green,blue) YY[][cell] vs XX[][cell]
			endif
		endif
	endfor
	if(!no_plot)
		ModifyGraph mode=0,marker=8,zero=4,noLabel=2,axThick=0,zeroThick=5
		ColorScale /F=0 side=2, ctab={min_rate,max_rate,yellowhot,0} "Mean Firing Rate (Hz)"
		ColorScale/C/N=text0 userTicks={tick_values,tick_labels}
		SetDrawEnv fname="Symbol",fsize=18,save
		SetDrawEnv xcoord=bottom
		DrawText 0,0,"p/2"
		SetDrawEnv xcoord=bottom
		DrawText 0,1,"-p/2"
		SetDrawEnv ycoord=left
		DrawText 1,0,"0"
		SetDrawEnv ycoord=left
		DrawText 0,0,"+/- p"
	endif
end