#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=NlxA

strconstant KLUSTAKWIK_PATH="C:\Program Files\Neuralynx\SpikeSort 3D\Klustakwik.exe"
//strconstant KLUSTAKWIK_PATH="/Users/rgerkin/Desktop/KlustaKwik"
strconstant STIMULUS_MESSAGE="Cheetah 160 Digital Input Port TTL (0xFFFF8000)"
strconstant START_MESSAGE="Starting Recording"
strconstant EVENT_WAVES="desc;times;ttl;odors"
constant PETH_MODE=5 // 0: lines; 5: bars
strconstant PETH_ERROR="SEM" // "SEM" or ""
strconstant PACKAGE_FOLDER="root:Packages:Nlx:"
static strconstant module="Nlx"
strconstant defaultFeatureMethod="PCA"

// ------------------------- STH and PETH -----------------------

// Makes a spike-time histogram from loaded Neuralynx spike data.  
static Function /wave MakeSTH(df,binWidth[,tStart,tStop,show])
	dfref df
	variable binWidth // Width of bins in seconds.  
	variable tStart,tStop // Optional start and end times to search for spikes, in seconds.  
	variable show // Display the STH.  
	
	wave /sdfr=df times,clusters
	
	tStart=ParamIsDefault(tStart) ? wavemin(Times) - 0.001 : max(tStart,0) // Start time in seconds.  
	tStop=ParamIsDefault(tStop) ? wavemax(Times) + 0.001 : min(tStop,wavemax(Times)+100) // Stop time in seconds.  
	Variable i,maxCluster=wavemax(Clusters)
	
	// Count number of distinct clusters in the cluster wave.  
	Make /free/n=(maxCluster+1) TempHist // Maximum of 100 clusters.  
	Histogram /B=2 Clusters,TempHist
	TempHist=1 // TempHist>0 && p==0 // 1's for all clusters with spikes except for the unassigned cluster.  
	Variable numClusters=sum(TempHist)
	Variable numBins=ceil(tstop-tstart)/(binWidth)
	
	Make /o/n=(numBins,numClusters) df:STH /WAVE=NlxSTH=0
	for(i=0;i<=maxCluster;i+=1) // Start from i=1 to exclude unclustered spikes.  
		Make /o/free/n=(numBins) TempHist=0
		SetScale x,tStart,tStart+numBins*binWidth,TempHist,NlxSTH
		Extract /o/free Times,UnitTimes,Clusters[p]==i
		if(numpnts(UnitTimes))
			Histogram /B=2 UnitTimes, TempHist
			NlxSTH[][i]=TempHist[p]
		endif
	endfor
	SetScale /P x,tStart,binWidth,NlxSTH
	NlxSTH/=binWidth
	KillWaves /Z TempHist
	if(show)
		DisplaySTH(df)
	endif
	return NlxSTH
End

static Function /wave MakePETHfromPanel([dataDF,keepTrials])
	variable keepTrials
	dfref dataDF
	
	string win="NeuralynxPanel"
	if(paramisdefault(dataDF))
		ControlInfo /W=$win Data; dfref dataDF=$("root:"+S_Value)
	endif
	ControlInfo /W=$win TrigSource; dfref trigSourceDF=$("root:"+s_value)
	if(!datafolderrefstatus(trigSourceDF))
		printf "No event data found in: %s\r","root:"+s_value
		return NULL
	endif
	controlinfo /w=$win PETH_settings; string instance=s_value
//	variable tPre=VarPackageSetting(module,"PETH",instance,"tPre")
//	variable tPost=VarPackageSetting(module,"PETH",instance,"tPost")
//	variable binWidth=VarPackageSetting(module,"PETH",instance,"binWidth")
//	string normalize=StrPackageSetting(module,"PETH",instance,"normalize")
//	string trigSourceType=StrPackageSetting(module,"PETH",instance,"trigSourceType",default_="Events")
//	string trigEventType=StrPackageSetting(module,"PETH",instance,"trigEventType")
//	wave /z/t trigTTLs=WavTPackageSetting(module,"PETH",instance,"trigTTLs")
	
//	strswitch(trigSourceType)
//		case "Events":
//			wave triggerTimes=trigSourceDF:times
//			strswitch(trigEventType)
//				case "All":
//					duplicate /free triggerTimes,triggerValues
//					triggerValues=0
//					break
//				case "TTL":
//					wave /z/sdfr=trigSourceDF TTL
//					if(!waveexists(TTL))
//						printf "No TTL wave found in %s.\r",getdatafolder(1,trigSourceDF)
//						return NULL
//					endif
//					make /free/n=(numpnts(triggerTimes)) triggerValues=TTL[p]
//					//triggerValues=triggerValues[p]==0 ? nan : triggerValues[p]
//					if(waveexists(trigTTLs))
//						triggerValues=NaN
//						variable i
//						for(i=0;i<numpnts(trigTTLs);i+=1)
//							string trigTTL=trigTTLs[i]
//							if(stringmatch(trigTTL," ") && numpnts(trigTTLs)<=1) // If there is only one entry and it is blank.  
//								triggerValues=TTL // Use all of the TTLs.  
//							else
//								variable trigVal=VarPackageSetting(module,"TTL",trigTTL,"value")
//								triggerValues=(TTL[p]==trigVal) ? TTL[p] : triggerValues[p]
//							endif
//						endfor
//					endif
//					break
//			endswitch
//			break
//		default:
//			printf "Using %s as a trigger source type is not yet supported.\r",trigSourceType
//			return NULL
//	endswitch
	if(paramisdefault(keepTrials))
		keepTrials=Core#VarPackageSetting(module,"PETH",instance,"keepTrials",default_=0)
	endif
	wave NlxPETH=NlxA#MakePETH(dataDF,trigSourceDF,instance,keepTrials=keepTrials)
	wave counts=denseHistogram(triggerValues)
	string colLabels=""
	variable i
	for(i=0;i<numpnts(counts);i+=1)
		colLabels+=getdimlabel(counts,0,i)+";"
	endfor
	note /nocr NlxPETH, "COLLABELS="+collabels
	return NlxPETH
end

// Makes a peri-event time histogram from either Data or from a regular spike-time histogram.  
// Events contains a list of the stimuli or events to use as the 0 time bins for the histogram.  
static Function /wave MakePETH(dataDF,eventsDF,pethInstance[,show,mask,keepTrials,phase,shuffle])
	dfref dataDF
	dfref eventsDF
	variable show // Display the PETH.  
	wave mask
	variable keepTrials // Keep the trial-organized data for future calculations (e.g. to compute correlations).  Only available for mode 0.  
	wave phase
	string shuffle,pethInstance
	
	shuffle=selectstring(!paramisdefault(shuffle),"",shuffle)
	wave /wave intervals=PETHIntervals(eventsDF,pethInstance)//WavTPackageSetting(module,"PETH",pethInstance,"Intervals")
	string normalize=Core#StrPackageSetting(module,"PETH",pethInstance,"Normalize",default_="rate")
	//wave /z/t triggers=WavTPackageSetting(module,"PETH",pethInstance,"triggers")
	variable binWidth=Core#VarPackageSetting(module,"PETH",pethInstance,"binWidth")
	variable tPre=Core#VarPackageSetting(module,"PETH",pethInstance,"tPre")
	variable tPost=Core#VarPackageSetting(module,"PETH",pethInstance,"tPost")
	variable angles=Core#VarPackageSetting(module,"PETH",pethInstance,"angles") // The data is angular, so average by taking cosines first.  
	keepTrials = paramisdefault(keepTrials) ? Core#VarPackageSetting(module,"PETH",pethInstance,"keepTrials") : keepTrials
	//wave eventTimes=eventsDF:times
	//duplicate /free eventTimes,triggerVals
	//triggerVals=0
	variable i,j,k
	string triggers=PETHTriggers(pethInstance)
	wave /wave triggerTimes=PETHTriggerTimes(eventsDF,pethInstance)
	make /free/t/n=(itemsinlist(triggers)) eventTypes=stringfromlist(p,triggers)
	variable numEvents=dimsize(eventTimes,0),numEventTypes=numpnts(eventTypes)
	wave /z/sdfr=dataDF data,times,STH
	svar /sdfr=dataDF type
	
	variable numBins=ceil((tPost+tPre)/binWidth)
	strswitch(type)
		case "ntt":
			wave /sdfr=dataDF Clusters
			variable numUnits=1+wavemax(Clusters)//NumClusters(dataDF)
			break
		case "nev":
			wave /sdfr=dataDF TTL
			wave TTLVals=DenseHistogram(TTL,exclude={0})
			numUnits=numpnts(TTLVals) // Number of distinct TTL Values.  
			break
	endswitch
	
	numUnits=max(1,numUnits)
	Make /o/n=(numBins,numUnits,numEventTypes) dataDF:PETH /wave=PETH=0, dataDF:PETH_sem /WAVE=PETH_SEM=0
	variable doZscore=stringmatch(normalize,"Z-score")
	if(keepTrials || doZScore)
		duplicate /o PETH dataDF:Trials /wave=Trials
		redimension /n=(-1,-1,-1,1) Trials
		SetScale x,-tPre,tPost,Trials
	endif
	SetScale x,-tPre,tPost,PETH,PETH_SEM
	Make /o/FREE/n=(numUnits,numEventTypes) TrialCounts=0
	//variable dummy=0
	
	strswitch(type)
		case "ntt":
		case "nse":
			wave /sdfr=dataDF Clusters
			make /free/n=(numUnits) clusterIndex=p//wave clusterIndex=ClustersWithSpikes(dataDF)
			variable unitNum,eventTypeNum
			make /free/wave/n=(numUnits) wTimes=newfreewave(4,0)
			strswitch(shuffle)
				case "isi": // Maintain ISI distribution for each cell, but shuffle ISIs.  Might not change the PETH much, but will change the trials matrix.  
					for(unitNum=0;unitNum<numUnits;unitNum+=1)
						if(unitNum==0)
							printf "Shuffling ISIs\r"
						endif
						extract /free Times,Times_,Clusters==ClusterIndex[unitNum]
						wave times__=shuffleISIs(Times_,start=wavemin(Times))
						wTimes[unitNum]=times__
					endfor
					break
				default:
					for(i=0;i<numpnts(times);i+=1)
						wave times_ = wTimes[clusters[i]]
						times_[numpnts(times_)] = {times[i]}
					endfor
//					for(unitNum=0;unitNum<numUnits;unitNum+=1)
//						extract /free Times,Times_,Clusters==ClusterIndex[unitNum]
//						wTimes[unitNum] = Times_
//					endfor
			endswitch
			for(unitNum=0;unitNum<numUnits;unitNum+=1) // Unit number; does not equal cluster number if some clusters have zero spikes.  
				svar /z/sdfr=dataDF merged
				if(svar_exists(merged))
					string sourceClusters=stringbykey("sourceClusters",merged)
					string dimlabel=stringbykey(num2str(clusterIndex[unitNum]),sourceClusters,"=",",")
					dimlabel=replacestring(":",dimlabel,"\rU")
				else
					dimlabel=("U"+num2str(clusterIndex[unitNum]))
				endif
				SetDimLabel 1,unitNum,$dimlabel,PETH
//				strswitch(shuffle)
//					case "isi": // Maintain ISI distribution for each cell, but shuffle ISIs.  Might not change the PETH much, but will change the trials matrix.  
//						if(unitNum==0)
//							printf "Shuffling ISIs\r"
//						endif
//						extract /free Times,Times_,Clusters==ClusterIndex[unitNum]
//						wave times__=shuffleISIs(Times_,start=wavemin(Times))
//						times_=times__
//						break
//					default:
//						extract /free Times,Times_,Clusters==ClusterIndex[unitNum]
//				endswitch
				wave times_ = wTimes[unitNum]
				for(eventTypeNum=0;eventTypeNum<numEventTypes;eventTypeNum+=1) // For each column in the events wave (each column might be times for a specific odor).  
					string eventType=eventTypes[eventTypeNum]
					wave eventTimes=triggerTimes[%$eventType]
					for(i=0;i<numpnts(eventTimes);i+=1)
						if(numtype(eventTimes[i])) // Event time is NaN or +/- Inf.  
							continue
						endif
						TrialCounts[unitNum][eventTypeNum]+=1 // A valid trial.  
						variable trialNum=TrialCounts[unitNum][eventTypeNum]-1
						if(numpnts(Times_)==0) // No spikes in this cluster.  
							continue
						endif
						Make /free/n=(numBins) Trial=0
						variable left=eventTimes[i][eventTypeNum]-tPre, right=eventTimes[i][eventTypeNum]+tPost
						SetScale x,left,right,Trial
						Histogram /B=2 Times_,Trial
						//dummy+=sum(Trial)
						if(keepTrials || doZScore)
							redimension /n=(-1,-1,-1,max(dimsize(Trials,3),trialNum+1)) Trials
							Trials[][unitNum][eventTypeNum][trialNum]=Trial[p]
						endif
						strswitch(normalize)
							case "Rate":
								Trial/=binWidth // No break, continue into 'Count'.  
								break
							case "Probability":
								Trial=Trial>0
								break
						endswitch
						PETH[][unitNum][eventTypeNum]+=Trial[p]
						PETH_sem[][unitNum][eventTypeNum]+=(Trial[p])^2
					endfor
					if(unitNum==0)
						setdimlabel 2,eventTypeNum,$eventType,PETH
					endif
				endfor
			endfor
			break
		case "ncs":
			for(eventTypeNum=0;eventTypeNum<numEventTypes;eventTypeNum+=1) // For each column in the events wave (each column might be times for a specific odor).  
				eventType=eventTypes[eventTypeNum]
				wave eventTimes=triggerTimes[%$eventType]
				for(i=0;i<numpnts(eventTimes);i+=1)
					if(numtype(eventTimes[i][j])) // Event time is NaN or +/- Inf.  
						continue
					endif
					left=eventTimes[i][eventTypeNum]-tPre
					right=eventTimes[i][eventTypeNum]+tPost
					left=binarysearch(Times,left)
					right=binarysearch(Times,right)
					if(left<0 || right<0)
						continue
					endif
					TrialCounts[0][eventTypeNum]+=1 // A valid trial.  
					trialNum=TrialCounts[0][eventTypeNum]-1
					duplicate /free/r=[left,right] Data,Trial
					if(angles)
						Trial+=pi
						unwrap 2*pi,Trial
					endif 
					Resample /RATE=(1/binWidth) Trial
					Trial=mod(Trial,2*pi)-pi
					if(keepTrials || doZScore)
						redimension /n=(-1,-1,-1,max(dimsize(Trials,3),trialNum+1)) Trials
						Trials[][0][eventTypeNum][trialNum]=Trial[p]
					endif
					if(angles)
						PETH[][0][eventTypeNum]+=cos(Trial[p])
						PETH_sem[][0][eventTypeNum]+=(cos(Trial[p]))^2
					else
						PETH[][0][eventTypeNum]+=Trial[p]
						PETH_sem[][0][eventTypeNum]+=(Trial[p])^2
					endif
				endfor
			endfor
			break
		case "nev":
			for(k=0;k<numUnits;k+=1)
				variable TTLVal=str2num(getdimlabel(TTLVals,0,k))
				extract /free Times,Times_,TTL==TTLVal
				SetDimLabel 1,k,$num2str(TTLVal),PETH 
				for(eventTypeNum=0;eventTypeNum<numEventTypes;eventTypeNum+=1) // For each column in the events wave (each column might be times for a specific odor).  
					eventType=eventTypes[eventTypeNum]
					wave eventTimes=triggerTimes[%$eventType]
					for(i=0;i<numpnts(eventTimes);i+=1)
						if(numtype(eventTimes[i])) // Event time is NaN or +/- Inf.  
							continue
						endif
						TrialCounts[k][eventTypeNum]+=1 // A valid trial.  
						Make /o/FREE/n=(numBins) Trial=0
						left=eventTimes[i]-tPre; right=eventTimes[i]+tPost
						SetScale x,left,right,Trial
						Histogram /B=2 Times_,Trial
						Trial/=binWidth
						PETH[][k][eventTypeNum]+=Trial[p]
						PETH_sem[][k][eventTypeNum]+=(Trial[p])^2
					endfor
				endfor
			endfor
			break
		default:
			printf "%s is an unsupported type for a PETH\r"
			return $"" 
	endswitch
	
	PETH/=TrialCounts[q][r]
	PETH_sem=sqrt(PETH_sem/TrialCounts[q][r]-PETH^2)/sqrt(TrialCounts[q][r])
	if(angles)
		PETH=acos(PETH)
		PETH_sem=acos(PETH_sem)
	else
	endif
	strswitch(normalize)
		case "Density":
			imagetransform /meth=2 xProjection PETH
			wave m_xprojection
			PETH/=(numBins*m_xprojection[q][r])
			break
		case "Z-score":
			PETH_sem=sqrt(PETH_sem/TrialCounts[q][r]-PETH^2)/sqrt(TrialCounts[q][r])
			duplicate /free PETH,PETH_cv
			PETH_cv=PETH_sem/PETH
			variable numTrials=dimsize(Trials,3)	
			make /free/n=(numEventTypes) baselineBins,baselineFirst,baselineLast
			if(numEventTypes != numpnts(intervals))
				printf "Number of event types (%d) does not equal number of intervals (%d).\r"
			endif
			for(i=0;i<numpnts(intervals);i+=1)
				wave interval=intervals[i]
				// First column is the baseline interval.  
				baselineFirst[i] = floor((interval[0][0]+tPre)/binWidth)
				baselineLast[i] = floor((interval[1][0]+tPre)/binWidth)
				baselineBins[i] = baselineLast[i]-baselineFirst[i]+1 // Number of bins in the baseline period.  
			endfor
#ifdef Rick
			variable zStrict=1
#else
			variable zStrict=0
#endif
			if(zStrict) // Compute variance over all trials, all baseline bins.  
				make /free/n=(numUnits,numEventTypes,baselineBins[0],numTrials) baseline=Trials[baselineFirst+r][p][q][s] // Order units,eventTypes,bins,trials.  
				redimension /e=1/n=(numUnits,numEventTypes,baselineBins[0]*numTrials) baseline
				make /free/n=(numUnits,numEventTypes) layers=baselineBins[q]*TrialCounts[p][q] // Number of total bins for this {unit,eventType} combination.  
			else // Compute variance over PETH baseline bins, i.e. averaged across trials first.  
				make /free/n=(numUnits,numEventTypes,baselineBins[0]) baseline=PETH[baselineFirst+r][p][q] // Order units,eventTypes,bins,trials.  
				make /free/n=(numUnits,numEventTypes) layers=baselineBins[q]
			endif
			duplicate /free baseline,baseline2
			baseline2=baseline^2
			matrixop /free baselineMean=sumBeams(baseline)/layers // Mean across the baseline period (numUnits x numEventTypes).  
			matrixop /free baseline2Mean=sumBeams(baseline2)/layers // Mean of squares across the baseline period (numUnits x numEventTypes).  
			duplicate /free baselineMean,baselineStd
			baselineStd=sqrt(baseline2Mean-baselineMean^2) // Standard deviation across the baseline period.  
			PETH=(PETH[p][q][r]-baselineMean[q][r])/baselineStd[q][r]
			//imagestats /q /g={0,1,0,92} /p=4 PETH
			//print v_min,v_max
			//imagestats /q /g={4,5,0,92} /p=4 PETH
			//print v_min,v_max
			PETH_sem=PETH*PETH_cv
			break
	endswitch
	Note PETH, replacestringbykey("PETH_INSTANCE",note(PETH),pethInstance,"=")
	Note PETH, replacestringbykey("NORMALIZE",note(PETH),normalize,"=")
	//Note PETH, replacestringbykey("INTERVALS",note(PETH),intervals,"=")
	if(!keepTrials)
		killwaves /z Trials
	endif
	return PETH
End

// Returns a list of triggers instances for this PETH instance.  
static function /s PETHTriggers(pethInstance)
	string pethInstance
	
	wave /t triggers=Core#WavTPackageSetting(module,"PETH",pethInstance,"Triggers")
	variable i
	string triggerList=""
	for(i=0;i<numpnts(triggers);i+=1)
		string trigger=triggers[i]
		if(!Core#IsBlank(trigger))
			triggerList+=trigger+";"
		endif
	endfor
	if(!strlen(triggerList))
		triggerList=Core#ListPackageInstances(module,"Trigger")
	endif
	return triggerList
end

// Returns the absolute times of triggers for this PETH instance applied to this events DF.  
static function /wave PETHTriggerTimes(events,pethInstance)
	dfref events
	string pethInstance
	
	string triggers=PETHTriggers(pethInstance)
	
	variable i,numTriggers=itemsinlist(triggers)
	make /free/n=(numTriggers)/wave result
	for(i=0;i<numTriggers;i+=1)
		string trigger=stringfromlist(i,triggers)
		wave trigTimes=TriggerTimes(events,trigger)
		result[i]=trigTimes
		setdimlabel 0,i,$trigger,result
	endfor
	return result
end

// Returns the absolute times of events matching the specifications of this trigger instance.  
static function /wave TriggerTimes(events,triggerInstance)
	dfref events
	string triggerInstance
	string type=Core#StrPackageSetting(module,"Trigger",triggerInstance,"type")
	variable value=Core#VarPackageSetting(module,"Trigger",triggerInstance,"value")	
	wave /z/sdfr=events times
	strswitch(type)
		case "TTL":
			wave /sdfr=events data=TTL
			break
		default:
			wave /z/sdfr=events data
			break
	endswitch	
	string condition=Core#StrPackageSetting(module,"Trigger",triggerInstance,"condition")
	strswitch(condition)
		case "All":
			extract /free times,result,1
			break
		case "Equals":
		case "=":
			extract /free times,result,data==value
			break
		case ">":
			extract /free times,result,data>value
			break
		case "<":
			extract /free times,result,data<value
			break
		case ">=":
			extract /free times,result,data>=value
			break
		case "<=":
			extract /free times,result,data<=value
			break
		case "Crosses":
		case "Crosses+":
		case "Crosses-":
			strswitch(condition)
				case "Crosses":
					string direction=""
					variable edge=0
					break
				case "Crosses+":
					direction="_up"
					edge=1
					break
				case "Crosses-":
					direction="_down"
					edge=2
					break
			endswitch
			string name
			sprintf name,"crossings_%f%s",value,direction
			newdatafolder /o events:$name
			dfref df=events:$name
			make /o/n=0 tempResult
			findlevels /q/d=tempResult/edge=(edge) data,value
			duplicate /free tempResult, result
			killwaves /z tempResult
			break
	endswitch
	return result
end

// Returns the absolute intervals for this PETH instance applied to the times in this events DF.  
static function /wave PETHIntervals(events,pethInstance[,absolute])
	dfref events
	string pethInstance
	variable absolute // 1: Absolute times; 0: Trial-relative times.  
	
	string triggers=PETHTriggers(pethInstance)
	variable i,numTriggers=itemsinlist(triggers)
	make /free/n=(numTriggers)/wave result
	variable tPre=Core#VarPackageSetting(module,"PETH",pethInstance,"tPre")
	variable tPost=Core#VarPackageSetting(module,"PETH",pethInstance,"tPost")
	for(i=0;i<numTriggers;i+=1)
		string trigger=stringfromlist(i,triggers)
		if(absolute)
			result[i]=AbsTriggerIntervals(events,trigger,defaultTpre=tPre,defaultTpost=tPost)
		else
			result[i]=TriggerIntervals(trigger)
		endif
		setdimlabel 0,i,$trigger,result // Label with the name of the trigger instance used to create these intervals.  
	endfor
	return result
end

static function /wave AbsTriggerIntervals(eventsDF,triggerInstance[,defaultTpre,defaultTpost])
	dfref eventsDF
	string triggerInstance
	variable defaultTpre,defaultTpost
	
	wave triggerTimes=TriggerTimes(eventsDF,triggerInstance)
	wave intervals=TriggerIntervals(triggerInstance)
	if(!numpnts(intervals))
		make /free/n=0 intervals
		intervals[][0]={-defaultTpre,0}
		intervals[][1]={0,defaultTpost}
	endif
	variable numIntervals=dimsize(intervals,1)
	make /free/n=(2,numpnts(triggerTimes),numIntervals) intervalTimes=nan
	intervalTimes=triggerTimes[q]+intervals[p][r]
	return intervalTimes
end

// Returns the relative intervals for this trigger instance.  
static function /wave TriggerIntervals(triggerInstance)
	string triggerInstance
	
	wave /t intervals=Core#WavTPackageSetting(module,"Trigger",triggerInstance,"Intervals")
	variable i
	make /o/n=0 result
	for(i=0;i<numpnts(intervals);i+=1)
		string interval=intervals[i]
		if(!Core#IsBlank(interval))
			variable start=Core#VarPackageSetting(module,"Intervals",interval,"start")
			variable finish=Core#VarPackageSetting(module,"Intervals",interval,"finish")	
			redimension /n=(2,dimsize(result,1)+1) result
			result[][dimsize(result,1)-1]={start,finish}
		endif
	endfor
	return result
end

static function /wave Trains(df,clusterz,intervals[,relative])
	dfref df // The data DF.  
	wave clusterz // One or more clusters, e.g. {3} or {3,5}.  
	wave intervals // Each interval is one column in the form: {start,stop}
	variable relative // Relative to interval start time.  
	
	variable i,j,numIntervals=dimsize(intervals,1)
	wave /sdfr=df times,clusters
	make /free/n=0/wave result
	for(j=0;j<numpnts(clusterz);j+=1)
		extract /free times,clusterTimes,clusters[p]==clusterz[j]
		for(i=0;i<numIntervals;i+=1)
			variable start=intervals[0][i]
			variable stop=intervals[1][i]
			extract /free clusterTimes,train,clusterTimes[p]>=start && clusterTimes[p]<stop
			if(relative)
				train-=start
			endif
			result[j][i]={train}
		endfor
	endfor
	return result
end

static function /s TriggerDescription(trigInstance)
	string trigInstance
	
	string result=trigInstance
	string desc=Core#StrPackageSetting(module,"trigger",trigInstance,"desc")
	if(strlen(desc))
		result=desc
	endif
	return result
end

// Displays an STH as an image plot.  
static Function DisplaySTH(df[,minn,maxx])
	dfref df
	variable minn,maxx
	
	minn=paramisdefault(minn) ? 0.01 : minn
	maxx=paramisdefault(maxx) ? 100 : maxx
	Wave STH=df:STH
	
	string name=Nlx#DF2FileName(df)//getdatafolder(0,df)
	minn=max(minn,0.01)
	Variable binWidth=dimdelta(STH,0)
	Redimension /n=(-1,max(1,dimsize(STH,1))) STH // Make 2D even if there is only one cluster.  
	DoWindow /K $(name+"_STH")
	Display /K=1 /N=$(name+"_STH") as name+" STH"
	AppendImage /T=top STH
	make /o/n=10000 df:$("STH_lookup") /WAVE=logLookup
	setscale x,minn,maxx,logLookup
	logLookup=log(x/minn)/log(maxx/minn)
	variable numTicks=log(maxx/minn)
	Make /o/n=5 df:$("STH_tks") /WAVE=Ticks_
	if(numTicks>1)
		variable firstTick=10^floor(log(minn))
		Ticks_=firstTick*10^p; 
	else
		firstTick=minn
		Ticks_=firstTick*2^p
	endif
	AppendToGraph /c=(0,0,0)/L=left1/T=top STH[][0] /tn=OneSTH
	Textbox /A=RB /N=UnitName "Unit 0"
	Make /o/T/n=(numpnts(Ticks_)) df:$("STH_tksl") /WAVE=TickLabels=num2str(Ticks_)
	ModifyImage STH ctab={minn,maxx,YellowHot256,0}, lookup=logLookup
	ColorScale /F=0/B=1/A=RC/X=0/Y=0/E=2 userTicks={Ticks_,TickLabels}, log=1,lblMargin=0,tickLen=2.00, widthPct=2, "Frequency (Hz)"
	Label left "Unit #"
	Label top "Time (s)"
	Label left1, "Firing Rate (Hz)"
	ModifyGraph minor(left)=0,manTick(left)={0,1,0,0},manMinor(left)={0,0}, margin(left)=25,margin(top)=25,axisEnab(top)={0,0.9},axisEnab(left)={0.52,1},axisEnab(left1)={0,0.48}
	ModifyGraph mirror(left)=0, fsize=9, btlen=2, freePos(left1)={0,kwFraction},lsize=2,lblPos(left1)=30
	doupdate
	getaxis /q left
	if(v_max-v_min>10)
		modifygraph manTick(left)=0
	endif
	MoveWindow 100,100,800,500
	SetWindow kwTopWin hook(update)=NlxA#STHHook, hookEvents=1,userData(df)=getdatafolder(1,df)
	DrawDashedLine(0)
End

Function STHHook(info)
	struct wmwinhookstruct &info
	
	strswitch(info.eventName)
		case "mousedown":
			variable unit=round(AxisValFromPixel("","left",info.mouseLoc.v))
			dfref df=$getuserdata("","","df")
			wave STH=df:STH
			string traces = TraceNameList(info.winname,";",3)
			if(unit>=0 && unit<dimsize(STH,1) && WhichListItem("OneSTH",traces)>=0)
				ReplaceWave trace=OneSTH STH[][unit]
				ColorTab2Wave Rainbow; wave M_Colors
				setscale x,0,1,M_Colors
				string clusterpanel=getdatafolder(0,df)+"_pnl"
				if(wintype(clusterpanel))
					controlinfo /w=$clusterpanel $("color_"+num2str(unit))
					variable red=V_Red,green=V_Green,blue=V_Blue
				else
					GetClusterColors(unit,red,green,blue)
				endif 
				modifygraph rgb(OneSTH)=(red,green,blue)
				textbox /c/n=unitname "Unit "+num2str(abs(unit))
				KillWaves /Z M_Colors
				DrawDashedLine(unit)
			endif
			break
	endswitch
End

static Function DrawDashedLine(unit)
	variable unit
	
	DrawAction getgroup=dashedLine, delete, begininsert
	SetDrawEnv gstart,gname=dashedLine
	SetDrawEnv linefgc=(65535,65535,65535),dash=3,linethick=3,ycoord=left
	DrawLine 0,unit,0.9,unit
	SetDrawEnv gstop
	DrawAction endinsert
End

static Function DisplayPETH(df[,colLabels,layer])
	dfref df
	string colLabels
	variable layer // Which layer to display.  Usually, each layer corresponds to a different type of event (e.g. a different odor).  UNUSED.  
	
#ifdef Rick
	printf "Suppressing PETH Graph.\r"
	return -1
#endif
	if(paramisdefault(layer))
		layer=-1
	endif
	Wave PETH=df:PETH
	Wave Error=df:PETH_sem
	svar /z/sdfr=df clusterNames,type
	string pethInstance=stringbykey("PETH_INSTANCE",note(PETH))
	
	string clusterpanel=getdatafolder(0,df)+"_pnl"
	string name=Nlx#DF2FileName(df)
	DoWindow /K $(name+"_PETH")
	Display /K=1/N=$(name+"_PETH") /W=(0,0,500,800) as name+" PETH"
	Variable i,j,k,traces,unit,numUnits=max(1,dimsize(PETH,1)),numEventTypes=max(1,dimsize(PETH,2))
	
	strswitch(type)
		case "ntt":
			wave unitIndex=ClustersWithSpikes(df)
			numUnits=max(1,numpnts(unitIndex))
			break
		case "nev":
			wave /sdfr=df TTL
			wave TTLVals=DenseHistogram(TTL,exclude={0})
			make /free/n=(numpnts(TTLVals)) unitIndex=str2num(getdimlabel(TTLVals,0,p))
			numUnits=dimsize(PETH,1)
			break
	endswitch
	
	//ColorTab2Wave Rainbow; wave M_Colors
	//setscale x,0,1,M_Colors
	for(i=0;i<numUnits;i+=1)
		unit=waveexists(unitIndex) ? unitIndex[i] : 0
		String unitAxis="unitAxis_"+num2str(unit)
		variable unitMaxRate=0,unitMinRate=0
		for(j=0;j<numEventTypes;j+=1)
			String eventAxis="eventAxis_"+num2str(j)
			string PETHName,errorName
			sprintf PETHName,"PETH_%d_%d",unit,j
			sprintf errorName,"Error_%d_%d",unit,j
			strswitch(type)
				case "ntt":
					if(wintype(clusterpanel))
						k=0
						do
							controlinfo /w=$clusterpanel $("color_"+num2str(unit-k*numUnits))
							k+=1
						while(v_flag<0)	
						variable red=V_Red,green=V_Green,blue=V_Blue
					else
						GetClusterColors(unit,red,green,blue)
					endif
					break
				default:
					red=0; green=0; blue=0
					break
			endswitch
			AppendToGraph /L=$unitAxis /B=$eventAxis /c=(red,green,blue) PETH[][i][j] /tn=$PETHName
			strswitch(type)
				case "ntt":
					modifygraph mode($PETHName)=PETH_MODE
					break
			endswitch
			variable delta=dimdelta(PETH,0)
			traces+=1
			if(strlen(PETH_ERROR))
				Appendtograph /L=$unitAxis /B=$eventAxis /c=(48000,48000,48000) PETH[][i][j] /tn=$errorName
				ErrorBars/L=2/Y=1 $errorName Y,wave=(Error[][i][j],Error[][i][j])
				ReorderTraces $PETHName, {$errorName, $PETHName} 
			endif
			modifygraph lsize=3
			if(numUnits<=1)
				wavestats /q PETH
			else
				ImageStats /Q/G={0,dimsize(PETH,0)-1,i,i} PETH
			endif
			unitMaxRate=max(unitMaxRate,V_max)
			unitMinRate=min(unitMinRate,V_min)
			if(j==0)
				if(wintype(clusterpanel))
					controlinfo /w=$clusterpanel $("color_"+num2str(unit))
					red=V_Red;green=V_Green;blue=V_Blue
				endif
				variable axisMin=0.07+0.93*(i/numUnits+min(0.01,0.1/numUnits))
				variable axisMax=0.07+0.93*((i+1)/numUnits-min(0.01,0.1/numUnits))
				ModifyGraph /Z axisEnab($unitAxis)={axisMin,axisMax}, freePos($unitAxis)={0.03+0.97*(min(0.02,1/numEventTypes)),kwFraction}
				string labell,description=num2str(unit)
				string normalize=stringbykey("NORMALIZE",note(PETH))
				strswitch(type)
					case "ntt":
					case "nse":
						if(svar_exists(clusterNames))
							description=stringbykey(description,clusterNames)
						else
							description=getdimlabel(PETH,1,i)
						endif
						strswitch(normalize)
							case "rate":
								string units="Hz" // Here, 'units' refers to the measurement units, whereas 'unit' refers to the number (i.e. cluster) of the entity being plotted.
								break
							case "count":
								units="Count"
								break
							case "probability":
								units="Probability"
								break
							case "Z-score":
								units="Z Score"
								break
							case "Density":
								units="Probability Density"
								break
							default:
								units=""
						endswitch
						break
					case "ncs":
						description=getdatafolder(0,df)
						units="V"
						break
					case "nev":
						sprintf description,"%#X",str2num(getdimlabel(PETH,1,i))
						units="Prob."
						break
				endswitch
				sprintf labell,"\K(%d,%d,%d)%s (%s)",red,green,blue,description,units
				Label $unitAxis, labell
				ModifyGraph lblPos($unitAxis)=20, lblPosMode($unitAxis)=1, nticks($unitAxis)=2
			endif
			if(i==0)
				axisMin=0.03+0.97*(j/numEventTypes+min(0.02,1/numEventTypes))
				axisMax=0.03+0.97*((j+1)/numEventTypes-min(0.02,1/numEventTypes))
				ModifyGraph axisEnab($eventAxis)={axisMin,axisMax}, lblMargin($eventAxis)=2, lblPosMode($eventAxis)=2, freePos($eventAxis)={0.07+0.93*(min(0.01,1/numUnits)),kwFraction}, zero($eventAxis)=2
				SetAxis /Z $eventAxis,dimoffset(PETH,0),dimoffset(PETH,0)+dimsize(PETH,0)*dimdelta(PETH,0)
				string eventType=num2str(j)
				if(!paramisdefault(colLabels))
					labell=stringfromlist(j,colLabels)
				else
					eventType=getdimlabel(PETH,2,j)
					if(Core#InstanceExists(module,"trigger",eventType))
						labell=TriggerDescription(eventType)
					endif
				endif
				labell=selectstring(strlen(labell),"Event "+num2str(j),labell)
				Label $eventAxis labell+"\rTime (s)"
				if(Core#InstanceExists(module,"trigger",eventType))
					wave /t intervals=Core#WavPackageSetting(module,"trigger",eventType,"intervals")
					if(waveexists(intervals))
						for(k=0;k<numpnts(intervals);k+=1)
							if(strlen(intervals[k])==0 || stringmatch(intervals[k]," "))
								continue
							endif
							variable start=Core#VarPackageSetting(module,"Intervals",intervals[k],"start")
							variable finish=Core#VarPackageSetting(module,"Intervals",intervals[k],"finish")
							if(numtype(start)==0 && numtype(finish)==0 && finish>start)
								doupdate
								getaxis /q $eventAxis
								setdrawenv xCoord=$eventAxis,linethick=2,arrow=1*(finish>v_max)+2*(start<v_min)
								start=max(v_min,start)
								finish=min(v_max,finish)
								drawline start,k*0.01,finish,k*0.01
							endif
						endfor
					endif
				endif
			endif	
		endfor
		strswitch(normalize)
			case "Z-Score":
				break
			default:
				SetAxis /Z $unitAxis, unitMinRate*1.5, unitMaxRate*1.5
		endswitch
	endfor
	ModifyGraph fsize=9, btlen=3,lowTrip=1e-4//,offset={0.5*delta,0}
	MoveWindow 100,100,100+300*j,500
	KillWaves /Z M_Colors
End

function /s TTLValue2Label(TTLvalue[,pethInstance])
	variable TTLvalue
	string pethInstance
	
	pethInstance=selectstring(!paramisdefault(pethInstance),"",pethInstance)
	string labell=""
	wave /t triggers=Core#WavTPackageSetting(module,"PETH",pethInstance,"triggers")
	if(waveexists(triggers) && (numpnts(triggers)>1 || !stringmatch(triggers[0]," ")))
	else
		string instances=Core#ListPackageInstances(module,"trigger")
		make /free/t/n=0 triggers=stringfromlist(p,instances)
	endif
	variable k
	for(k=0;k<numpnts(triggers);k+=1)
		string triggerInstance=triggers[k]
		string triggerType=Core#StrPackageSetting(module,"trigger",triggerInstance,"type")
		if(!stringmatch(triggerType,"TTL"))
			continue
		endif
		variable trigValue=Core#VarPackageSetting(module,"trigger",triggerInstance,"value")
		if(TTLvalue==trigValue)
			string desc=Core#StrPackageSetting(module,"trigger",triggerInstance,"desc")
			if(strlen(desc))
				labell=desc
			else
				labell=triggerInstance
			endif
			break
		endif
	endfor
	return labell
end

// Generate new spike times with same ISI distribution as provided spike times.  
threadsafe Function /wave ShuffleISIs(times[,start])
	wave times // Spike times
	variable start // Start time of recording.  
	
	duplicate /free times,times_
	differentiate /meth=1 times_ // ISIs.  
	 
	// Shuffle ISIs.
	make /free/n=(numpnts(times_)) randos=enoise(1)  
	sort randos,times_
	
	integrate /meth=2 times_ // New spike times.  
	times_+=start // Add back integration constant.  
	
	return times_
End

Function /WAVE EventsMD(df,divisor)
	dfref df // Data folder of Events.  
	Variable divisor
	
	wave Events=df:times
	Variable i
	Make /o/n=(ceil(dimsize(Events,0)/divisor),divisor) $(GetWavesDataFolder(Events,2)+"_md") /WAVE=Events_MD=NaN
	for(i=0;i<dimsize(Events,0);i+=1)
		Events_MD[floor(i/divisor)][mod(i,divisor)]=Events[i] // Not correct since point number is not the same as sweep number.  
	endfor
	return Events_MD
End

// ----------------- Clustering -----------------------

// Cluster an entire recording session.  Without optional variables, assumes that data is loaded and split, and that events are loaded and epochs are known.  
Function Cluster([df,method,match,except,dataLoad,dataChop,dataSave,noKlustakwik])
	dfref df
	string method // Feature selection method.  
	string match,except
	variable dataLoad,dataChop,dataSave
	variable noKlustakwik // (0) Write feature files, cluster, load cluster files; (1) write feature files only; (2) load cluster files only.  
	
	if(paramisdefault(df))
		dfref df=root:
	endif
	method=selectstring(!paramisdefault(method),defaultFeatureMethod,method)
	match=selectstring(paramisdefault(match),match,"*")
	except=selectstring(paramisdefault(except),except,"")
	ControlInfo /W=NeuralynxPanel dirName
	NewPath /O/Q NlxPath,S_Value
	PathInfo NlxPath
	string pathStr=S_path
	setdatafolder df
	if(dataLoad)
		dfref Events=$LoadBinaryFile("nev","Events",pathName="NlxPath")
		dfref epochs=NlxA#ExtractEvents("epochs",df=events)
	else
		dfref events=df:events
		dfref epochs=events:epochs
	endif
	variable i=0,j
	string files=""
	if(dataload)
		do
			string file=indexedfile(NlxPath,i,".ntt")
			if(strlen(file)==0)
				break
			endif
			string letter=""
			sscanf file,"TT%[A-Z_].ntt",letter
			if(strlen(letter)==1)
				file=RemoveEnding(file,".ntt")
				if(!stringmatch(file,match) || stringmatch(file,except))
					i+=1
					continue
				endif
				files=AddListItem(file,files)
			endif
			i+=1
		while(1)
	else
		files=core#dir2("folders",df=df,match=match,except=except)
		i=0
		do // Remove non-ntt folders from the list.  
			file = stringfromlist(i,files)
			dfref fileDF = df:$file
			if(stringmatch(Nlx#DataType(fileDF),"ntt"))
				i+=1
			else
					files = removefromlist(file,files)
			endif
		while(i<itemsinlist(files))
	endif
	variable numFiles=itemsinlist(files)
	
	for(i=0;i<numFiles;i+=1)
		Prog("File",i,numFiles)
		file=stringfromlist(i,files)
		if(dataLoad)
			dfref dataDF=$LoadBinaryFile("ntt",file,pathName="NlxPath")
		else
			dfref dataDF=df:$file
		endif
		string type = Nlx#DataType(dataDF)
		if(whichlistitem(type,"ntt;nse") >= 0) // If this is spiking data.  
			if(dataChop)
				Post_("Splitting "+file+" into epochs...")
				variable numEpochs=NlxA#ChopData(dataDF,epochsDF=epochs)
			endif
			ClusterEpochs(dataDF,write=dataSave,noKlustakwik=noKlustakwik,method=method)
		endif
	endfor
	
	SetDataFolder df
End

// Cluster and write all the epochs of one electrode.  
Function ClusterEpochs(df[,method,write,noKlustakwik])
	dfref df // The data folder of the electrode.  
	string method // Feature selection method.  
	variable write // Write data back to disk.  
	variable noKlustakwik // (0) Write feature files, cluster, load cluster files; (1) write feature files only; (2) load cluster files only.  
	
	method=selectstring(!paramisdefault(method),defaultFeatureMethod,method)
	variable i
	string folders=""
	for(i=0;i<countobjectsdfr(df,4);i+=1)
		string folder=getindexedobjnamedfr(df,4,i)
		if(grepstring(folder,"E[0-9]"))
			folders=AddListItem(folder,folders)
		endif
	endfor
	folders=sortlist(folders,";",16)
	variable numFolders=itemsinlist(folders)
	for(i=0;i<numFolders;i+=1)
		Prog("Folder",i,numFolders)
		folder=stringfromlist(i,folders)
		dfref epochDF=df:$folder
		ClusterEpoch(epochDF,method=method,write=write,noKlustakwik=noKlustakwik)
	endfor
End

// Cluster and write all the electrodes of one epoch.  
Function ClusterElectrodes(df,electrodes,epoch[,method,write,noKlustakwik])
	dfref df // The data folder containing all the electrodes, e.g. root:d2010_07_16.
	string electrodes,epoch
	string method // Feature selection method.  
	variable write // Write data back to disk.  
	variable noKlustakwik // (0) Write feature files, cluster, load cluster files; (1) write feature files only; (2) load cluster files only.  
	
	method=selectstring(!paramisdefault(method),defaultFeatureMethod,method)
	string folders=core#Dir2("FOLDERS",df=df)
	electrodes=ListMatch2(folders,electrodes)
	variable i
	for(i=0;i<itemsinlist(electrodes);i+=1)
		Prog("Electrode",i,itemsinlist(electrodes))
		string electrode=stringfromlist(i,electrodes)
		dfref electrodeDF=df:$electrode
		dfref epochDF=electrodeDF:$epoch
		if(datafolderrefstatus(epochDF))
			ClusterEpoch(epochDF,method=method,write=write,noKlustakwik=noKlustakwik)
		endif
	endfor
End

Function ClusterEpoch(df[,method,write,noKlustakwik])
	dfref df
	string method // Feature selection method.  
	variable write // Write data back to disk.  
	variable noKlustakwik // (0) Write feature files, cluster, load cluster files; (1) write feature files only; (2) load cluster files only.  
	
	method=selectstring(!paramisdefault(method),defaultFeatureMethod,method)
	string name=Nlx#DF2FileName(df)
	if(noKlustakwik!=2)
		strswitch(method)
			case "Rick":
				wave /z lambdas=ClusterFeatures(df,method="PCA",numFeatures=5)
				wave /z lambdas=ClusterFeatures(df,method="DWT",numFeatures=5,append_=1)
				wave /z lambdas=ClusterFeatures(df,method="Point:8",numFeatures=1,flatten=0,append_=1)
				break
			case "PCA":
				wave /z lambdas=ClusterFeatures(df,method="PCA",numFeatures=9,flatten=1)
				break
			default:
				wave /z lambdas=ClusterFeatures(df,method=method,numFeatures=0)
		endswitch
		if(!waveexists(lambdas))
			Post_("ClusterPCA on epoch "+getdatafolder(1,df)+" was unsuccessful, possibly because there is no data in that epoch.")
			variable /g df:numClusters=0
			return -1
		endif
		Post_("Writing Klustakwik feature files for "+name+"...")
		KlustakwikFeatureFile(df,"lambdas")
	endif
	if(!noKlustakwik)
		Post_("Running Klustakwik for "+name+"...")
		KlustakwikRun(df)
	endif
	if(noKlustakwik!=1)
		Post_("Loading Klustakwik clusters for "+name+"...")
		KlustakwikLoadClusters(df)
	endif
	if(write)
		Post_("Saving binary file for "+name+"...")
		Nlx#SaveBinaryFile(df,fileName=name,force=1)
	endif
	wave /sdfr=df clusters
	variable /g df:numClusters=wavemax(clusters)
End

// Make feature files out of the feature data in the list of waves specified in 'match', which can include wildcards.  
// An example of a wave containing feature data would be "TTG_14_lmd", which would contain the lambda values from PCA of the data in TTG_14.  
// In that case, the suffix would be "lmd".  
Function KlustakwikFeatureFiles(match,feature)
	string match // String of data folders to match.  Data folders should exists at the current folder level.  If we are in 'TTA', we would usually want to match all the epochs, so match="E*".  
	string feature
	
	match=core#Dir2("folders",match=match)
	variable i; string list=""
	for(i=0;i<itemsinlist(match);i+=1)
		string name=stringfromlist(i,match)
		dfref df=$name
		KlustakwikFeatureFile(df,feature)
	endfor
End

Function KlustakwikFeatureFile(df,feature)
	dfref df
	string feature
	
	string path=""
	Nlx#GetPath(path,writeable=1)
	close /a
	wave features=df:$feature
	variable numSpikes=dimsize(features,0)
	variable numDims=dimsize(features,1) // For example, number of PCA components.  
	//make /o/free/n=(dimsize(w,1),numElectrodes*numSamples) klustakwik=round(10000000*w[mod(q,numElectrodes)][p][floor(q/numElectrodes)])
	variable num
	string filename
	string epochName=getdatafolder(0,df) // Current data folder, usually the epoch name.  
	dfref parentDF=$(removeending(getdatafolder(1,df),getdatafolder(0,df)+":"))
	string electrodeName=getdatafolder(0,parentDF) // Parent data folder, usually the electrode name. 
	sscanf epochName,"E%d",num
	sprintf filename,"%s.fet.%d",electrodeName,num
	
	// Create feature file.  
	variable refnum
	open /p=$path refnum as filename
	fsetpos refnum,0
	string str=num2str(numDims)+"\n"
	fbinwrite refNum,str // Write feature file header.  
	close refnum
	save /a=2/g/m="\n"/p=$path features as filename // Append features.  
End

Function KlustakwikRun(df[,options])
	dfref df
	string options
	
	options=selectstring(paramisdefault(options),options,"")
	string path=""
	string pathStr=Nlx#GetPath(path)
	string epochName=getdatafolder(0,df) // Current data folder, usually the epoch name.  
	dfref parentDF=$(removeending(getdatafolder(1,df),getdatafolder(0,df)+":"))
	string electrodeName=getdatafolder(0,parentDF) // Parent data folder, usually the electrode name. 
	variable num
	sscanf epochName,"E%d",num
	string cmd,os=igorinfo(2)
	strswitch(os)
		case "Macintosh":
			pathStr="/Volumes/"+ReplaceString(":",pathStr,"/")
			sprintf cmd,"do shell script \"%s '%s%s' %d\"",KLUSTAKWIK_PATH,pathStr,electrodeName,num
			break
		default:
			pathStr=ReplaceString(":",pathStr,"\\")
			pathStr=RemoveEnding(pathStr,"\\")
			pathStr[1]=":"
			sprintf cmd,"\"%s\" \"%s\\%s\" %d",KLUSTAKWIK_PATH,pathStr,electrodeName,num
			break
	endswitch
	ExecuteScriptText cmd
End

Function KlustakwikLoadClusters(df)
	dfref df
	
	string path=""
	Nlx#GetPath(path)
	string epochName=getdatafolder(0,df) // Current data folder, usually the epoch name.  
	dfref parentDF=$(removeending(getdatafolder(1,df),getdatafolder(0,df)+":"))
	string electrodeName=getdatafolder(0,parentDF) // Parent data folder, usually the electrode name. 
	variable num
	sscanf epochName,"E%d",num
	string clustersFile
	sprintf clustersFile,"%s.clu.%d",electrodeName,num
	variable refNum
	Open /Z/R/P=$path refNum as clustersFile
	if(!v_flag)
		Close refNum
		LoadWave /A/B=("N=temp,T=96;")/G/O/P=$path/Q clustersfile
		wave temp
		temp-=1 // The noise cluster in Klustakwik is cluster 1, but in SpikeSort3D it is cluster 0.  
		variable numClusters=temp[0]
		deletepoints 0,1,temp // The first point is the number of clusters.  
		duplicate /o temp,df:clusters
		killwaves /z temp
		printf "Klustakwik found %d clusters.\r",numClusters
	else
		Post_("No Klustakwik clusters file found.")
	endif
End

// ------------------------------- Viewer --------------------------------

// ----------------- Neuralynx Viewer -----------------------

// Initialize the Neuralynx Viewer.  
Function InitViewer()
	NewDataFolder /O root:Packages
	NewDataFolder /O root:Packages:Nlx
	dfref df=root:Packages:Nlx
	Variable /G df:spikeNum=0, df:maxSpikes=100, df:YAxisRange=120, df:timeStamp=0, df:d2=0, df:logP=0, df:isoD=0, df:Lratio=0
End

// Views Neuralynx spike data.  
Function CreateViewer(df)
	dfref df
	
	InitViewer()
	DoWindow /K NlxViewer
	Display /N=NlxViewer /K=1 /W=(100,100,600,600) as "Neuralynx Viewer"
	ControlBar /L 155
	Button ControlToggle, pos={0,0}, size={25,20}, proc=ViewerButtons, title="-", userData="1"
	Variable y_pos=25, y_space=25
	String name=GetDataFolder(1,df)
	name=name[5,strlen(name)-1] // Cut out leading "root:"
	name=removeending(name,":")
	svar type=df:type // "ntt" or "ncs" (the latter is not yet supported for viewing).  
	dfref nlx=$PACKAGE_FOLDER
	nvar /sdfr=nlx timestamp,d2
	
	String available=Nlx#Recordings(type)
	PopupMenu DataName, value=#("Nlx#Recordings(\""+type+"\")"), mode=(1+WhichListItem(name,available)), pos={27,0}, proc=ViewerPopupMenus
	y_pos+=1.5*y_space
	
	Groupbox VisualizationGroup, pos={2,y_pos}, size={150,280}
	TitleBox VisualizationTitle, pos={45,y_pos-15}, fstyle=1, frame=0, title="Visualization"
	y_pos+=3
	SetVariable SpikeNum, title="Spike #", value=nlx:$"spikeNum", bodywidth=50, pos={64,y_pos}, disable=1, proc=ViewerSetVariables
	nvar maxSpikes=nlx:$"maxSpikes"
	SetVariable MaxSpikes, title="Max Spikes", value=nlx:$"maxSpikes", bodywidth=50, userData=num2str(maxSpikes), pos={64,y_pos}, disable=0, proc=ViewerSetVariables
	y_pos+=y_space
	Checkbox OneSpike, title="One", mode=1, pos={5,y_pos+2}, value=0, proc=ViewerCheckboxes
	Checkbox AllSpikes, title="All",mode=1, value=1, proc=ViewerCheckboxes
	y_pos+=y_space
	Button AllClusters, title="All", pos={5,y_pos+2}, size={30,20}, proc=ViewerButtons
	Button AssignedClusters, title="Assigned", pos={40,y_pos+2}, proc=ViewerButtons
	Button NoClusters, title="None", pos={95,y_pos+2}, proc=ViewerButtons
	
	y_pos+=y_space
	make /o/n=(1,3,3) nlx:selWave=q==1 ? 32 : 0
	setdimlabel 2,1,foreColors,nlx:selWave
	setdimlabel 2,2,backColors,nlx:selWave
	make /o/t/n=(1,3) nlx:listWave
	make /o/n=(50,3) nlx:colorWave /wave=colorWave
	variable i
	for(i=0;i<dimsize(colorWave,0);i+=1)
		variable red,green,blue
		GetClusterColors(i,red,green,blue)
		colorWave[i+1][0]=red
		colorWave[i+1][1]=green
		colorWave[i+1][2]=blue
	endfor
	variable y_size=150
	Listbox Cluster, title="Cluster", pos={2,y_pos+2}, size={150,y_size}, selwave=nlx:selWave, listWave=nlx:listWave, colorWave=nlx:colorWave
	Listbox Cluster, mode=2, clickEventModifiers=4, widths={20,20,100}, proc=ViewerListboxes
	y_pos+=y_size+5
	//Button Merge, title="Merge", pos={2,y_pos},disable=1,proc=ViewerButtons
	//y_pos+=y_space
	SetVariable YAxisRange, title="Range (\F'Symbol'm\F'Arial'V)", value=nlx:$"YAxisRange", limits={0,Inf,10}, bodywidth=40, pos={55,y_pos}, disable=0, proc=ViewerSetVariables
	Checkbox YAxisAuto, title="Auto", value=0, pos={107,y_pos+2}, proc=ViewerCheckboxes
	y_pos+=y_space
	ValDisplay TimeStamp, title="Timestamp (s)", disable=1, bodywidth=60, pos={88,y_pos}, value=#(PACKAGE_FOLDER+"timestamp")
	y_pos+=2.5*y_space
	
	Groupbox IsolationGroup,size={150,175}, pos={2,y_pos}
	TitleBox IsolationTitle,fstyle=1,pos={50,y_pos-15},frame=0,title="Isolation"
	y_pos+=7
	ValDisplay D2, title="D\B2", bodywidth=30, pos={10,y_pos}, disable=1, format="%.1f", value=#(PACKAGE_FOLDER+"d2")
	ValDisplay IsoD, title="Iso D", disable=0, bodywidth=32, pos={15,y_pos}, format="%.1f", value=#(PACKAGE_FOLDER+"IsoD")
	ValDisplay logP, title="-log(p)", bodywidth=30, pos={85,y_pos}, disable=1, format="%.1f", value=#(PACKAGE_FOLDER+"logP")
	ValDisplay Lratio, title="L ratio", disable=0, bodywidth=30, pos={85,y_pos}, format="%.2f", value=#(PACKAGE_FOLDER+"Lratio")
	y_pos+=y_space
	SetVariable mahalThreshold,title="Show D\B2\M >",disable=0,bodywidth=35,pos={65,y_pos},value=_NUM:0,proc=ViewerSetVariables
	y_pos+=y_space*1.5
	Titlebox MahalVisualize, pos={6,y_pos},title="Mahal:"
	Button MahalPlots,pos={55,y_pos},size={35,20},proc=ViewerButtons, title="Plots"
	Button MahalMatrix,size={35,20},proc=ViewerButtons, title="Matrix"
	y_pos+=y_space
	Button ISI,pos={45,y_pos},proc=ViewerButtons, title="ISI"
	y_pos+=y_space
	Button Stats,pos={45,y_pos},proc=ViewerButtons, title="Stats"
	y_pos+=y_space
	Titlebox ClusterVisualize, pos={6,y_pos},title="Clusters:"
	Button TwoD, title="2D",size={30,20},proc=ViewerButtons
	Button ThreeD, title="3D",size={30,20},proc=ViewerButtons
	ReplaceWaves(df,type)
	strswitch(type)
		case "ntt":
			break
		case "ncs": // ncs not supported for viewing using this function.  
			break
	endswitch
	setwindow nlxViewer hook(click)=NlxViewerHook
End

Function NlxViewerHook(info)
	struct wmwinhookstruct &info
	
	if(info.eventCode==3 && (info.eventMod &2^4)) // Right mouse button down.  
		dfref nlx=$PACKAGE_FOLDER
		variable /g nlx:mouseX=info.mouseLoc.h
		variable /g nlx:mouseY=info.mouseLoc.v
		variable i,electrode=nan
		string axes=GetAxesFromClick(info.mouseLoc.h,info.mouseLoc.v,"axisT_","axis_")
		string xAxis=stringfromlist(0,axes)
		string yAxis=stringfromlist(1,axes)
		if(strlen(yAxis))
			sscanf yAxis,"axis_%d",electrode
		endif
		string clusterList=SelectedClusters()
		string /g nlx:trace=stringbykey("TRACE",TraceFromPixel(info.mouseLoc.h,info.mouseLoc.v,""))
		svar /sdfr=nlx trace
		controlinfo dataName
		dfref df=$("root:"+s_value)
		getmarquee
		if(v_flag || (strlen(trace) && !stringmatch(trace,"*Mean*")))
			string /g nlx:menuOption=""
			popupcontextualmenu /n "ClusterMenu"
			svar /sdfr=nlx menuOption
			menuOption=selectstring(strlen(menuOption),s_selection,menuOption)
			if(itemsinlist(clusterList)!=1 || numtype(electrode))
				return -1
			endif
			if(stringmatch(menuOption,"Draw *"))
				string upperLower
				sscanf menuOption,"Draw %s Boundary",upperLower
				NlxA#DrawBoundary(df,electrode,clusterList,upperLower)
			elseif(stringmatch(menuOption,"Edit *"))
				sscanf menuOption,"Edit %s Boundary",upperLower
				NlxA#EditBoundary(df,electrode,clusterList,upperLower)
			elseif(stringmatch(menuOption,"Exclude Outliers"))
				ExcludeBoundaryOutliers(df,electrode,clusterList,"upper")
				ExcludeBoundaryOutliers(df,electrode,clusterList,"lower")
			elseif(stringmatch(menuOption,"Send Outliers To *"))
				variable destCluster
				sscanf menuOption,"Send Outliers To %d",destCluster
				ExcludeBoundaryOutliers(df,electrode,clusterList,"upper",destCluster=destCluster)
				ExcludeBoundaryOutliers(df,electrode,clusterList,"lower",destCluster=destCluster)
			endif
			return -1 // Prevent the normal right-click menu from opening up afterwards.  
		endif
	endif
End

Menu "ClusterMenu",contextualmenu, dynamic
	SubMenu "Send to Cluster"
		NlxA#SendToClusterList(),/Q,GetLastUserMenuInfo; ClusterMenuHook(s_value)
	End
	SubMenu "Upper Boundary"
		"Draw",SetMenuOption("Draw Upper Boundary")
		"Edit",SetMenuOption("Edit Upper Boundary")
	End
	SubMenu "Lower Boundary"
		"Draw",SetMenuOption("Draw Lower Boundary")
		"Edit",SetMenuOption("Edit Lower Boundary")
	End
	"Exclude Outliers",;
	SubMenu "Send Outliers To"
		NlxA#SendToClusterList(),/Q,GetLastUserMenuInfo; SetMenuOption("Send Outliers To "+s_value)
	End
End

function SetMenuOption(str)
	string str
	string /g $(PACKAGE_FOLDER+"menuOption")=str
end

static function DrawBoundary(df,electrode,clusterList,type)
	dfref df
	variable electrode
	string clusterList,type
	
	string cluster=stringfromlist(0,clusterList)
	dfref currDF=getdatafolderdfr()
	newdatafolder /o/s df:boundaries
	dfref boundaries=df:boundaries
	string yName="u"+cluster+"_elec"+num2str(electrode)+"_"+type+"_yy"
	string xName="u"+cluster+"_elec"+num2str(electrode)+"_"+type+"_xx"
	make /o/n=0 $yName
	make /o/n=0 $xName
	GraphWaveDraw /W=NlxViewer /B=$("axisT_"+num2str(electrode))/L=$("axis_"+num2str(electrode))/O $yName,$xName
	setdatafolder currDF
	Button DoneDrawing pos={10,650},size={100,20}, disable=0, fcolor=(65535,0,0), title="\K(65535,65535,65535)Done Drawing",proc=ViewerButtons,win=NlxViewer
end

static function EditBoundary(df,electrode,clusterList,type)
	dfref df
	variable electrode
	string clusterList,type
	
	string cluster=stringfromlist(0,clusterList)
	dfref boundaries=df:boundaries
	if(!datafolderrefstatus(boundaries))
		return DrawBoundary(df,electrode,clusterList,type)
	else
		wave /z yy=boundaries:$("u"+cluster+"_elec"+num2str(electrode)+"_"+type+"_yy")
		wave /z xx=boundaries:$("u"+cluster+"_elec"+num2str(electrode)+"_"+type+"_xx")
		if(!waveexists(yy) || !waveexists(xx) || numpnts(xx)*numpnts(yy)==0)
			return DrawBoundary(df,electrode,clusterList,type)
		endif
		RemoveFromGraph /Z/W=NlxViewer $nameofwave(yy)
		AppendToGraph /W=NlxViewer /B=$("axisT_"+num2str(electrode)) /L=$("axis_"+num2str(electrode)) yy vs xx
		GraphWaveEdit /W=NlxViewer $nameofwave(yy)
		Button DoneDrawing pos={10,650},size={100,20}, disable=0, fcolor=(65535,0,0), title="\K(65535,65535,65535)Done Drawing",proc=ViewerButtons,win=NlxViewer
	endif
end

function ExcludeBoundaryOutliers(df,electrode,clusterList,type[,destCluster])
	dfref df
	variable electrode,destCluster
	string clusterList,type
	
	string cluster=stringfromlist(0,clusterList)
	dfref boundaries=df:boundaries
	
	wave /z yy=boundaries:$("u"+cluster+"_elec"+num2str(electrode)+"_"+type+"_yy")
	wave /z xx=boundaries:$("u"+cluster+"_elec"+num2str(electrode)+"_"+type+"_xx")
	if(!waveexists(yy) || !waveexists(xx) || numpnts(xx)*numpnts(yy)==0)
		return -1
	endif
	dfref pf=$PACKAGE_FOLDER
	make /o/n=32 pf:interped /wave=boundary
#if exists("Interpolate2")
	interpolate2 /I=3 /T=1 /Y=boundary xx,yy
#else
	wave boundary = nan
#endif
	ExcludeSpikes(df,electrode,cluster,type,boundary,destCluster=destCluster)
end

function ExcludeSpikes(df,electrode,clusterList,boundaryType,boundary[,destCluster])
	dfref df
	variable electrode,destCluster
	string clusterList,boundaryType
	wave boundary
	
	wave /sdfr=df data,clusters
	svar /sdfr=df type
	nvar /z/sdfr=df analog
	variable numSpikes=numpnts(clusters)
	strswitch(type)
		case "ntt":
		case "nse":
			variable numSamples=dimsize(data,0)
			break
	endswitch
	variable bitVolts=(nvar_exists(analog) && analog) ? 1 : ChannelBitVolts(df)
	make /free/n=(numSpikes,numSamples) exclude
	variable clusterLogic=BitList2Num(clusterList)
	strswitch(boundaryType)
		case "upper": // Exclude spikes that are or cross above the boundary.  
			boundary/=bitVolts
			multithread exclude=(clusterLogic & 2^clusters[p])>0 && data[q][p][electrode]>boundary[q]
			break
		case "lower": // Exclude spikes that are or cross below the boundary
			boundary/=bitVolts
			multithread exclude=(clusterLogic & 2^clusters[p])>0 && data[q][p][electrode]<boundary[q]
			break
		case "marquee": // Exclude spikes that are or cross into the marquee.  
			variable left=(nvar_exists(analog) && analog) ? (boundary[0]-dimoffset(data,0))/dimdelta(data,0) : ceil(boundary[0])
			variable top=boundary[1]/bitVolts
			variable right=(nvar_exists(analog) && analog) ? (boundary[2]-dimoffset(data,0))/dimdelta(data,0) : floor(boundary[2])
			variable bottom=boundary[3]/bitVolts
			multithread exclude=(clusterLogic & 2^clusters[p])>0 && q>=left && q<=right && data[q][p][electrode]>bottom && data[q][p][electrode]<top
			break
	endswitch
	matrixop /free exclude=sumrows(exclude)
	extract /free/indx exclude,indices,exclude>0
	ReassignSpikes(df,indices,destCluster)
end

function ChannelBitVolts(df)
	dfref df
	
	wave /z/sdfr=df metadata
	dfref rootDF=root:
	if(waveexists(metadata))
		struct nlxMetaData meta
		structget meta metadata
		variable bitVolts=meta.bitVolts
	elseif(!datafolderrefsequal(df,rootDF))
		dfref dfUp=ParentFolder(df)
		bitVolts=ChannelBitVolts(dfUp)
	else
		bitVolts=7.6e-9
	endif
	return bitVolts
end

Function /s ShowNewCluster()
	controlinfo oneSpike
	string str=""
	if(!v_value)
		str="New Cluster"
	endif
	return str
End

Function ClusterMenuHook(item)
	string item
	
	strswitch(item)
		default:
			if(stringmatch(item,"New"))
				variable destCluster=-1 // New cluster.  
			else
				destCluster=str2num(item) // Old cluster.  
			endif
			if(numtype(destCluster)==0) // A cluster number, therefore this is cluster (re)assignment.  
				dfref nlx=$PACKAGE_FOLDER
				controlinfo dataName
				dfref df=$("root:"+s_value)
				getmarquee
				if(v_flag) // There was a marquee.  
					nvar /sdfr=nlx mouseX,mouseY
					string axes=GetAxesFromClick(mouseX,mouseY,"axisT_","axis_")
					string xAxis=stringfromlist(0,axes)
					string yAxis=stringfromlist(1,axes)
					string clusterList=SelectedClusters()
					if(strlen(yAxis) && strlen(clusterList))
						variable electrode
						sscanf yAxis,"axis_%d",electrode
						getmarquee $yAxis,$xAxis
						make /free/n=4 marquee={v_left,v_top,v_right,v_bottom}
						ExcludeSpikes(df,electrode,clusterList,"Marquee",marquee,destCluster=destCluster)
					endif
					//string traces=YAxisTraces(yAxis)
					//traces=TracesInsideMarquee(traces)
				else // There was no marquee.  
					svar /sdfr=nlx trace
					variable spikeIndex
					sscanf trace,"Spike_%d_u%*s'",spikeIndex
					make /free/n=1 spikeIndices=spikeIndex
					ReassignSpikes(df,spikeIndices,destCluster)
				endif
			endif
			break
	endswitch
End

// List of clusters to assign spike(s) to in the Viewer.  
static Function /s SendToClusterList()
	string str=""
	controlinfo dataName
	dfref nlx=$PACKAGE_FOLDER
	if(datafolderrefstatus(nlx))
		wave /z/sdfr=nlx /t listWave
		variable i
		
		if(waveexists(listWave))
			for(i=0;i<dimsize(listWave,0);i+=1)
				str+=listWave[i][0]+";"
			endfor
		endif
	endif
	str+="New"
	return str
End

static Function ReassignSpikes(df,indices,newCluster)
	dfref df
	wave indices
	variable newCluster
	
	if(numpnts(indices)==0)
		return -1
	endif
	dfref nlx=$PACKAGE_FOLDER
	wave /sdfr=nlx /t listWave
	wave /z/sdfr=nlx selWave,GizmoColors
	if(newCluster<0) // A brand new cluster.  
		wave counts=ClusterCounts(df)
		variable i,j
		for(i=0;i<numpnts(counts);i+=1)
			if(counts[i]<=0) // An empty cluster.  
				break // Use it for the new cluster.  
			endif
		endfor
		newCluster=i
		variable numClusters=dimsize(listWave,0)
		redimension /n=(max(numClusters,i+1),-1,-1) listWave,selWave
		selWave[][0][2]=p+1
	endif
	
	ControlInfo DataName
	dfref df=$("root:"+S_Value)
	String type=Nlx#DataType(df)
	ControlInfo oneSpikes; variable oneSpike=v_value
	wave /sdfr=df clusters
	variable red,green,blue
	GetClusterColors(newCluster,red,green,blue)
	for(i=0;i<numpnts(indices);i+=1)
		variable index=indices[i]
		variable oldCluster=clusters[index]
		clusters[index]=newCluster
		if(waveexists(GizmoColors))
			GizmoColors[index][0]=red
			GizmoColors[index][1]=green
			GizmoColors[index][2]=blue
		endif
		
		variable oldCount=str2num(listWave[oldCluster][1])
		listWave[oldCluster][1]=num2str(oldCount-1)
		variable newCount=str2num(listWave[newCluster][1])
		listWave[newCluster][1]=num2str(newCount+1)
		if(!oneSpike)
			for(j=0;j<4;j+=1)
				string trace
				sprintf trace,"Spike_%d_u%d_t%d",index,oldCluster,j
				removefromgraph /z $trace
			endfor
		endif
	endfor
	if(oneSpike)
		ReplaceWaves(df,type)
	endif
End

Function ViewerButtons(info)
	Struct WMButtonAction &info
	if(info.eventCode!=2)
		return 0
	endif
	controlinfo dataname
	dfref df=$("root:"+s_value)
	
	string clusters=SelectedClusters(brief=1)
	variable cluster=str2num(stringfromlist(0,clusters))
	dfref pf=$PACKAGE_FOLDER
	wave /z/sdfr=pf selWave
	svar /z/sdfr=df type
	
	strswitch(info.ctrlName)
		case "ControlToggle":
			variable on=str2num(GetUserData("","ControlToggle",""))
			if(on)
				string visible=VisibleControls()
				ModifyControlList ControlNameList("", ";","") disable=1
				Button ControlToggle title="+", userData="0", userData(visible)=visible,disable=0
				ControlBar /L 0
				//ModifyControlList ControlNameList("", ";", "*_tab0") disable=1
			else
				visible=getuserdata("","ControlToggle","visible")
				variable i
				for(i=0;i<itemsinlist(visible);i+=1)
					string visibleControl=stringfromlist(i,visible)
					ModifyControlList visibleControl disable=0
				endfor
				Button ControlToggle title="-", userData="1"
				ControlBar /L 155
			endif
			break
		case "allClusters":
			selWave[][1][0]=selWave[p][1][0] | 16
			ReplaceWaves(df,type)
			break
		case "assignedClusters":
			selWave[0][1][0]=selWave[0][1][0] & ~16
			selWave[1,][1][0]=selWave[p][1][0] | 16
			ReplaceWaves(df,type)
			break
		case "noClusters":
			selWave[][1][0]=selWave[p][1][0] & ~16
			ReplaceWaves(df,type)
			break
		case "MahalPlots":
			if(numtype(cluster)==0)
				PlotMahal(df,cluster,regenerate=1)
			endif
			break
		case "MahalMatrix":
			if(numtype(cluster)==0)
				make /free/n=(itemsinlist(clusters)) w_selectedClusters=str2num(stringfromlist(p,clusters))
				MahalDistanceMatrix(df,units=w_selectedClusters,plot=1)
			endif
			break
		case "ISI":
			DisplayClusterISI(df,clusters)
			break
		case "Stats":
			DisplayClusterStats(clusters=clusters,recalc=1)
			break
		case "TwoD":
			Cluster2DVisualize(df,feature="lambdas",showClusters=SelectedClusters(option="checked"),maxFeatures=10)
			break
		case "ThreeD":
			Clustering(df,"lambdas",0)
			break
		case "DoneDrawing":
			GraphNormal /W=$info.win
			Button DoneDrawing disable=1,win=$info.win
			string traces=traceNameList(info.win,";",1)
			traces=listmatch(traces,"*upper*")+listmatch(traces,"*lower*")
			for(i=0;i<itemsinlist(traces);i+=1)
				string trace=stringfromlist(i,traces)
				if(stringmatch(trace,"*#*'"))
					removefromgraph /w=$info.win/z $trace
				endif
				modifygraph /w=$info.win/z rgb($trace)=(0,0,0), lstyle($trace)=3, lsize($trace)=2
			endfor
			break
	endswitch
End

Function ViewerCheckboxes(ctrlName,checked)
	String ctrlName
	Variable checked
	
	ControlInfo DataName
	dfref df=$("root:"+S_Value)
	String type=Nlx#DataType(df)
	dfref nlx=$PACKAGE_FOLDER
	wave /sdfr=nlx selWave
	strswitch(ctrlName)
		case "oneSpike":
			Checkbox allSpikes, value=0
			SetVariable maxSpikes, disable=1
			SetVariable spikeNum, disable=0
			ViewerCheckboxes("DummyRadioButton",0)
			break
		case "allSpikes":
			Checkbox oneSpike, value=0
			SetVariable maxSpikes, disable=0
			SetVariable spikeNum, disable=1
			ViewerCheckboxes("DummyRadioButton",1)
			break
		case "dummyRadioButton":
			//SetVariable SpikeNum, disable=2*checked
			ValDisplay TimeStamp, disable=checked
			ValDisplay d2, disable=checked
			ValDisplay isoD, disable=!checked
			ValDisplay logP, disable=checked
			ValDisplay Lratio, disable=!checked
			SetVariable mahalThreshold, disable=!checked
			ReplaceWaves(df,type)
			break
		case "yAxisAuto":
			SetVariable yAxisRange, disable=2*checked
			ReplaceWaves(df,type)
			break
	endswitch
End

Function ViewerSetVariables(info)
	Struct WMSetVariableAction &info
	
	if(info.eventCode!=1 && info.eventCode!=2)
		return 0
	endif
	ControlInfo DataName
	dfref df=$("root:"+s_value)
	string type=Nlx#DataType(df)
	Wave /sdfr=df Data
	
	strswitch(info.ctrlName)
		case "SpikeNum":
			ReplaceWaves(df,type)
//			Variable spikeNum=info.dval
//			ControlInfo Cluster; String cluster=S_Value
//			Wave /sdfr=df Clusters
//			strswitch(cluster)
//				case "All":
//					Extract /free/INDX Clusters, TempClusters, numtype(Clusters)==0
//					// Do nothing.  
//					break
//				case "Assigned":
//					Extract /free/INDX Clusters, TempClusters, Clusters!=0 && numtype(Clusters)==0
//					spikeNum=TempClusters[spikeNum]
//					break
//				default:
//					Extract /free/INDX Clusters, TempClusters, Clusters==str2num(cluster)
//					spikeNum=TempClusters[spikeNum]
//					break
//			endswitch
//			Variable red,green,blue
//			variable index=TempClusters[info.dval]
//			variable clusterNum=Clusters[index]
//			GetClusterColors(clusterNum,red,green,blue)
//			Variable i
//			String traces=TraceNameList("",";",3)
//			for(i=0;i<ItemsInList(traces);i+=1)
//				String trace_name=StringFromList(i,traces)
//				Wave Data=TraceNameToWaveRef("", trace_name)
//				ReplaceWave trace=$trace_name Data[][spikeNum][i] // Don't need to use ReplaceNlxWaves because this is the same data as before.  
//			endfor
//			ModifyGraph /Z rgb=(red,green,blue)
//			ValDisplay TimeStamp, value=#(getdatafolder(1,df)+"Times["+num2str(spikeNum)+"]")
//			
//			KillWaves /Z M_Colors
			break
		case "MaxSpikes":
			if(info.eventCode==1 || info.eventCode==2)
				variable oldVal=str2num(info.userData)
				dfref Nlx=$NlxFolder
				nvar newVal=Nlx:maxSpikes
				if(info.eventCode==1)
					variable inc=1.5
					if(newVal>oldVal)
						newVal=round(oldVal*inc)
					elseif(oldVal>newVal)
						newVal=round(oldVal/inc)
					endif		
				endif
				setvariable maxSpikes userData=num2str(newVal)
				ReplaceWaves(df,type)
			endif
			break
		case "MahalThreshold":
			ReplaceWaves(df,type)
			break
		case "YAxisRange":
			Variable y_range=info.dval
			controlinfo yAxisAuto; variable yAxisAuto=v_value
			String axes=AxisList("")
			variable i
			for(i=0;i<ItemsInList(axes);i+=1)
				String axis_name=StringFromList(i,axes)
				String axis_info=AxisInfo("",axis_name)
				String axis_type=StringByKey("AXTYPE",axis_info)
				if(StringMatch(axis_type,"LEFT"))
					if(!yAxisAuto)
						SetAxis $axis_name -y_range/1000000,y_range/1000000
					endif
					String axisT_name=ReplaceString("axis",axis_name,"axisT")
					SetAxis /A $axisT_name
				endif
			endfor
			break
	endswitch
End

Function ViewerPopupMenus(info)
	Struct WMPopupAction &info
	if(info.eventCode!=2)
		return 0
	endif
	Variable i
	ControlInfo DataName
	dfref df=$("root:"+S_Value)
	String type=Nlx#DataType(df) // Works for now, but will need to be changed.  
	strswitch(info.ctrlName)
		case "DataName":
			ReplaceWaves(df,type)
			//PopupMenu Cluster, mode=1
			break
		case "Cluster":
			ControlInfo OneSpike
			if(!V_Value)
				ReplaceWaves(df,type)
			else
				Struct WMSetVariableAction info2; info2.eventCode=1; info2.ctrlName="SpikeNum"
				ViewerSetVariables(info2)
			endif
			break
	endswitch
End

Function ViewerListboxes(info)
	struct wmlistboxaction &info
	
	if(info.eventCode!=2 && info.eventMod!=16) // Not mouse up or right-click.  
		return -1
	endif
	if(!stringmatch(winname(0,1),"NlxViewer"))
		return -2
	endif
	dfref nlx=$PACKAGE_FOLDER
	ControlInfo DataName
	dfref df=$("root:"+S_Value)
	String type=Nlx#DataType(df) // Works for now, but will need to be changed.  
	strswitch(info.ctrlName)
		case "Cluster":
			wave /sdfr=nlx selWave
			
			//selWave[][0][0]=0
			//selWave[info.row][1][0]=1
			string clusterz=SelectedClusters()
			if(!strlen(clusterz))
				//break
			endif
			if(info.eventCode==1) // Mouse down.  
				if(info.eventMod & 16) // Right-click.    
					PopupContextualMenu "Merge;Delete"
					wave /sdfr=df Clusters
					variable i
					strswitch(S_Selection)
						case "Merge": // Merge these clusters into the lowest numbered cluster of the group.  
							clusterz=SortList(clusterz,";",16)
							variable targetCluster=str2num(stringfromlist(0,clusterz))
							for(i=1;i<itemsinlist(clusterz);i+=1)
								variable cluster=str2num(stringfromlist(i,clusterz))
								extract /free/indx Clusters,indices,Clusters==cluster
								ReassignSpikes(df,indices,targetCluster)
							endfor
							break
						case "Delete": // Send all spikes to cluster 0.  
							for(i=0;i<itemsinlist(clusterz);i+=1)
								cluster=str2num(stringfromlist(i,clusterz))
								extract /free/indx Clusters,indices,Clusters==cluster
								ReassignSpikes(df,indices,0)
							endfor
							break
					endswitch
				endif
				break
			elseif(info.eventCode==2)		
				nvar /sdfr=nlx spikeNum
				spikeNum=0
				ControlInfo OneSpike
				if(!V_Value && info.col==2)
					if(ReplaceWaves(df,type,computeIsolation=1)>=0 && wintype("MahalPlot"))
						cluster=str2num(stringfromlist(0,clusterz))
						ClusterStats(df,clusterz)
						DisplayClusterISI(df,clusterz)
						PlotMahal(df,cluster)
					endif
				else
					ReplaceWaves(df,type)//Struct WMSetVariableAction info2; info2.eventCode=1; info2.ctrlName="SpikeNum"
					//ViewerSetVariables(info2)
				endif
				//Button Merge disable=(itemsinlist(clusterz)<2), title="Merge"
			endif
			break
	endswitch
End

// Replaces the data in the Neuralynx viewer with a new data wave (usually a different electrode).  
Function ReplaceWaves(df,type[,computeIsolation])
	dfref df // The new data folder.  
	String type // Type of the new data wave.  
	variable computeIsolation
	
	ControlInfo /W=NlxViewer yAxisRange; Variable yAxisRange=V_Value
	// Remove old traces.  
	String traces=TraceNameList("NlxViewer",";",3)
	traces=SortList(traces,";",17)
	Variable i,j,k
	for(i=0;i<ItemsInList(traces);i+=1)
		RemoveFromGraph /w=NlxViewer $StringFromList(i,traces)
	endfor
	
	dfref nlx=$PACKAGE_FOLDER
	nvar /sdfr=nlx maxSpikes
	
	SetWindow NlxViewer userData(fullPath)=getdatafolder(1,df)
	wave /z/sdfr=df Data
	variable bitVolts=ChannelBitVolts(df)
	strswitch(type)
		case "ntt":	
		case "nse":
			Wave /Z/sdfr=df Clusters,Lambdas,Times
			wave counts=ClusterCounts(df)
			make /free/n=(dimsize(counts,0)) dummy=p*(counts>0)
			wavestats /q dummy
			variable count=v_maxloc+2 // +1 for cluster 0, and +1 for an empty cluster at the end.  
			wave /sdfr=nlx /t listWave
			wave /sdfr=nlx selWave
			redimension /n=(count,3,-1) listwave,selWave
			selWave[][1][0] = selWave[p][1][0] | 32
			listwave=selectstring(q==0,num2str(counts[p]),GetDimLabel(counts,0,p)) // Cluster # in column 0, cluster spike count in column 2.  
			selWave[][0,1][2]=p+1
			if(wavemax(selWave,count,2*count-1)==32) // Sum of second column of selWave is 0, i.e. no cluster(s) are selected.   
				selWave[0][1][0]=48 // Set cluster 0 to be selected.  
			endif
			make /free/n=0 spikeIndices
			string checkedClusters=SelectedClusters(option="checked")	
			variable visibleClusters=0
			ControlInfo /W=NlxViewer OneSpike; Variable oneSpike=V_Value
			ControlInfo /W=NlxViewer AllSpikes; Variable allSpikes=V_Value
			for(i=0;i<numpnts(counts);i+=1)
				if(counts[i]>0 && whichlistitem(num2str(i),checkedClusters)>=0)
					extract /free/INDX clusters, spikeIndices_, clusters==i
					if(!oneSpike && (counts[i]>maxSpikes))
						statssample /n=(maxSpikes) spikeIndices_
						wave spikeIndices_=w_sampled
					endif  	
					concatenate /np {spikeIndices_},spikeIndices
					visibleClusters+=1
				endif
			endfor
			if(numpnts(spikeIndices)>(maxSpikes*10)) // No more than maxSpikes*10 (across clusters) should ever be plotted.  
				statssample /n=(maxSpikes*10) spikeIndices
				wave spikeIndices=w_sampled
			endif
			variable visibleSpikes=numpnts(spikeIndices)
			i=0
			do
				string checkedCluster=stringfromlist(i,checkedClusters)
				if(counts[%$checkedCluster]==0)
					checkedClusters=RemoveFromList(checkedCluster,checkedClusters)
				else
					i+=1
				endif
			while(i<itemsinlist(checkedClusters))
			checkedClusters=removeending(checkedClusters,";")
			controlinfo /W=NlxViewer mahalThreshold; variable mahalThreshold=v_value
			if(mahalThreshold)
				checkedClusters = ListExpand(checkedClusters)
				make /free/n=(itemsinlist(checkedClusters)) doClusters = str2num(stringfromlist(p,checkedClusters))
				wave mahalDistances=MahalDistance(Lambdas,clusters,doClusters=doClusters)
			endif
	
			if(visibleSpikes==0)
				return -1
			endif
			
			// Set up average spike wave.  
			if(!oneSpike && visibleClusters==1)
				make /o/n=(dimsize(data,0),dimsize(data,2)) df:$("Mean_"+checkedClusters) /wave=meanSpike=0
				make /o/n=(dimsize(data,0),dimsize(data,2)) df:$("StDev_"+checkedClusters) /wave=stdevSpike=0
			endif
			if(oneSpike)
				nvar /sdfr=nlx spikeNum,timeStamp,d2,logP
				variable index=spikeIndices[spikeNum]
				timeStamp=Times[index]
				make /free/n=(dimsize(counts,0)) counts_=counts*((selWave[p][1][0] & 16) > 0)
				SetVariable SpikeNum limits={0,sum(counts_)-1,1},win=NlxViewer
				if(waveexists(lambdas))
					wave spikeLambdas=row(lambdas,index) // The lambdas for one spikes.  
					variable dof=numpnts(spikeLambdas) // Degrees of freedom is the dimensionality of spikeLambdas.  
					d2=Mahalanobis(lambdas,transpose(spikeLambdas))
					logP=-log(1-statschicdf(d2,dof))
				endif
			elseif(computeIsolation)
				string highlighted=SelectedClusters(option="highlighted")
				if(itemsinlist(highlighted)==1) // One cluster highlighted.  
					variable refCluster=str2num(stringfromlist(0,highlighted))
					string refName="U"+num2str(refCluster)
					if(refCluster>=0)
						nvar /sdfr=nlx isoD,Lratio
						wave clusterswithspikez=clusterswithspikes(df)
						wave /z isolation=ClusterIsolation(df,centeredClusters={refCluster},nuisanceClusters=clustersWithSpikez)
						if(waveexists(isolation))
							isoD=isolation[%$refName][%isoD]
							Lratio=isolation[%$refName][%Lratio]
							string str
							for(i=0;i<count;i+=1)
								if(counts[i] && itemsinlist(highlighted))
									string nuisanceName="U"+num2str(i)
									if(i==refCluster)
										sprintf str,"%d",counts[i]
									else
										sprintf str,"%d [%.2f]",counts[i],isolation[%$refName][%$nuisanceName]
									endif
									listWave[i][2]=str
								endif
							endfor
						endif
					endif
				endif
			endif
			make /free/n=100 appendedSpikes=0 // Index is cluster number.  
			variable electrodes=dimsize(data,2)
			for(i=0;i<electrodes;i+=1)
				make /free/n=100 encounteredSpikes=0
				String axis_name="axis_"+num2str(i)
				String axisT_name="axisT_"+num2str(i)
				for(j=0;j<visibleSpikes;j+=1) // Append all spikes on this channel or only the first one.  
					if(oneSpike)
						index=spikeIndices[spikeNum]
					else
						index=spikeIndices[j]
					endif
					variable clusterNum=Clusters[index]
					//variable clusterCount=counts[%$num2str(clusterNum)] // Number of spikes in the cluster that this spike belongs to.  
					//Variable sparse=(thinning>0) ? floor(clusterCount/100) : 0
					
					// Include in mean spike waveform.  
					if(!oneSpike && visibleClusters==1)
						meanSpike[][i]+=Data[p][index][i]
						stdevSpike[][i]+=Data[p][index][i]^2
						setscale /p x,0,dimdelta(Data,0),meanSpike,stDevSpike
					endif
					
					// Plot spike.  
					if(!mahalThreshold || mahalDistances[index]>mahalThreshold)
						variable red,green,blue
						GetClusterColors(clusterNum,red,green,blue)
						string traceName
						sprintf traceName, "Spike_%d_u%d_t%d", index, clusterNum, i
						AppendToGraph /W=NlxViewer /c=(red,green,blue) /L=$axis_name /B=$axisT_name Data[][index][i] /tn=$traceName
						appendedSpikes[clusterNum]+=(i==0)
					endif
					encounteredSpikes[clusterNum]+=1
					if(oneSpike)
						break
					endif
				endfor
				if(electrodes>1)
					ModifyGraph /z/W=NlxViewer  axisEnab($axis_name)={(i<2)*0.52,0.48+(i<2)*0.5}
					ModifyGraph /z/W=NlxViewer  axisEnab($axisT_name)={(mod(i,2)==1)*0.52,0.48+(mod(i,2)==1)*0.5}
				endif
				ModifyGraph /z/W=NlxViewer freePos($axis_name)={0,$axisT_name}
				ModifyGraph /z/W=NlxViewer freePos($axisT_name)={0,$axis_name}
				ModifyGraph /z/W=NlxViewer  tickUnit($axis_name)=1,prescaleExp($axis_name)=6,btlen=1,fsize=9
				controlinfo /W=NlxViewer yaxisauto
				if(v_value)
					SetAxis /A/Z/W=NlxViewer $axis_name
				else
					SetAxis /Z/W=NlxViewer $axis_name -yAxisRange/1000000,yAxisRange/1000000
				endif
				Label /Z/W=NlxViewer  $axis_name " "
				if(!oneSpike && visibleClusters==1 && appendedSpikes[clusterNum]) // At least one spike from at most one cluster.  
					// Append average waves.  
					sprintf traceName,"Mean[%d]_t%d", clusterNum, i
					AppendToGraph /W=NlxViewer /c=(0,0,0) /L=$axis_name /B=$axisT_name meanSpike[][i] /tn=$traceName
					modifygraph /W=NlxViewer lsize($traceName)=2
					errorbars /W=NlxViewer $traceName, Y wave=(stdevSpike[][i],stdevSpike[][i])
					
					// Append boundaries.  
					dfref boundaries=df:boundaries
					if(datafolderrefstatus(boundaries))
						string upperLower="upper;lower"
						for(k=0;k<2;k+=1)
							string boundary
							sprintf boundary,"u%d_elec%d_%s",clusterNum,i,stringfromlist(k,upperLower)
							wave /z yy=boundaries:$(boundary+"_yy")
							wave /z xx=boundaries:$(boundary+"_xx")
							if(waveexists(yy) && waveexists(xx) && numpnts(yy)*numpnts(xx))
								appendtograph /w=NlxViewer /L=$axis_name /B=$axisT_name /c=(0,0,0) yy vs xx
								traceName=nameofwave(yy)
								modifygraph /w=NlxViewer lsize($traceName)=2,lstyle($traceName)=3
							endif
						endfor
					endif
				endif
			endfor
			if(!oneSpike && visibleClusters==1)
				meanSpike/=j
				stdevSpike/=j
				stdevSpike=sqrt(stdevSpike-meanSpike^2)
				ValDisplay Timestamp value=#(getdatafolder(1,df)+"Times[0]"), win=NlxViewer 
			else
				ValDisplay Timestamp value=#(getdatafolder(1,df)+"Times["+num2str(spikeNum)+"]"), win=NlxViewer
			endif
			nvar /z/sdfr=df analog
			if(!nvar_exists(analog) || !analog)
				modifygraph /w=NlxViewer muloffset={0,bitVolts} // Apply voltage scaling factor to traces to convert from a 16-bit A/D output to a decimal voltage.  
			endif
			killwaves /z w_sampled
			// Update list wave and sel wave to reflect changes in numbers of clusters.  
			
			break
		case "nse":
			AppendToGraph /W=NlxViewer df:Data[][0]
			ModifyGraph /W=NlxViewer tickUnit(left)=1,prescaleExp(left)=6
			Label /W=NlxViewer left "\F'Symbol'm\F'Arial'V"
			break
		case "ncs":
			AppendToGraph /W=NlxViewer df:Data vs df:Times
			ModifyGraph /W=NlxViewer  tickUnit(left)=1,prescaleExp(left)=6
			Label /W=NlxViewer left "\F'Symbol'm\F'Arial'V"
			Label /W=NlxViewer bottom "Time (s)"
			break
	endswitch
	killwaves /z m_colors
	return 0
End

Function PlotIsolation(df[,doClusters,regenerate])
	dfref df
	wave doClusters
	variable regenerate 

	if(paramisdefault(doClusters))
		wave doClusters=ClustersWithSpikes(df)
	endif
	wave isolation=ClusterIsolation(df,centeredClusters=doClusters,nuisanceClusters=doClusters)
	if(wintype("IsolationPlot") && !regenerate)
		//dowindow /f MahalPlot
		removetraces(win="IsolationPlot")
	else
		dowindow /k IsolationPlot
		newimage /k=1/n=IsolationPlot isolation
		dowindow /t isolationplot, "Cluster Isolation Ratio"
	endif
	variable maxCluster=dimsize(isolation,0)
	setaxis /w=IsolationPlot left,maxCluster-0.5,-0.5
	setaxis /w=IsolationPlot top,-0.5,maxCluster-0.5
	ModifyImage /w=IsolationPlot isolation ctab= {0,1,Grays,1}
	ModifyGraph /w=IsolationPlot manTick={0,1,0,0},manMinor={0,0}
End

function /wave MahalDistanceMatrix(df[,units,plot])
	dfref df
	wave units // Only calculate distances from these units.  
	variable plot
	
	wave /sdfr=df clusters
	wavestats /q/m=1 clusters
	variable i,j,numClusters=v_max+1
	if(paramisdefault(units))
		make /free/n=(numClusters) units; units=p
	endif
	wave counts=ClusterCounts(df)
	i=0
	do
		if(counts[units[i]]==0)
			deletepoints i,1,units
		else
			i+=1
		endif
	while(i<numpnts(units))
	make /o/n=(numClusters,numClusters) df:ClusterDistances /wave=distances=nan
	make /free/wave/n=(numpnts(units)) mahalColumns
	mahalColumns=MakeMahals(df,units[p],normalize=1)
	for(i=0;i<numpnts(units);i+=1)
		variable ii=units[i]
		wave /z/wave d2s=mahalColumns[i]
		if(!waveexists(d2s))
			distances[ii][]=nan
			continue
		endif
		wave /z w1=d2s[ii]
		for(j=0;j<numClusters;j+=1)
			wave /z w2=d2s[j]
			if(waveexists(w1) && waveexists(w2))
				statskstest /q w1,w2
				wave w_ksresults
				distances[ii][j]=1-w_ksresults[%D]
			endif
		endfor
	endfor
	killwaves /z w_ksresults
	if(plot)
		dowindow /k MahalDistanceMatrixWin
		display /k=1/n=MahalDistanceMatrixWin as "Cluster Similarity"
		appendimage /l=left1 /t=top1 distances 
		movewindow /w=MahalDistanceMatrixWin 100,100,500,400
		newfreeaxis /r right1; newfreeaxis /b bottom1
		SetAxis/A/R left1
		ModifyGraph nticks(right1)=0,nticks(bottom1)=0,axisEnab={0.05,1},axisEnab={0.05,1},axisEnab(left1)={0,0.95},axisEnab(right1)={0,0.95},freepos={0.05,kwFraction},mirror=0
		ModifyGraph axisEnab(left1)={0,0.95},axisEnab(right1)={0,0.95},freePos(right1)={0,kwFraction},freePos(bottom1)={0,kwFraction}
		label left1 "Nuisance Cluster"
		label top1 "Centered Cluster"
		ModifyGraph btlen=2,lblPos=100
		ModifyImage ClusterDistances ctab= {-1,*,RedWhiteBlue,1}
		ColorScale /A=RC/E/F=0/X=0/Y=0 axisRange={0,},tickLen=0,nticks=10,width=10,heightPct=100
		modifygraph fsize=10
		ValDisplay Separation value=_NUM:0,title="S="
		setwindow MahalDistanceMatrixWin,hook(myHook)=MahalDistanceMatrixWinHook,userData(df)=getdatafolder(1,df)
		if(wintype("NlxViewer"))
			AutoPositionWindow /R=NlxViewer
		endif
	endif
	return distances
end

function MahalDistanceMatrixWinHook(info)
	struct WMWinHookStruct &info
	
	variable xx=round(AxisValFromPixel(info.winName,"top1",info.mouseLoc.h))
	variable yy=round(AxisValFromPixel(info.winName,"left1",info.mouseLoc.v))
	if(xx>=0 && yy>=0)
		string df_=getuserdata(info.winName,"","df")
		dfref df=$df_
		if(datafolderrefstatus(df))
			wave /z/sdfr=df ClusterDistances
			if(waveexists(ClusterDistances))
				valDisplay Separation value=_NUM:ClusterDistances[xx][yy],win=MahalDistanceMatrixWin 
			endif
			if(info.eventCode==5) // Mouse up.  
				dfref pf=$PACKAGE_FOLDER
				wave /z/sdfr=pf selWave
				if(waveexists(selWave))
					selWave[][1]=selWave[p][1] & ~16
					selWave[xx][1]=selWave[xx][1] | 16	
					selWave[yy][1]=selWave[yy][1] | 16	
					svar /sdfr=df type
					ReplaceWaves(df,type)
				endif
			endif
		endif
	endif
end

function /wave MakeMahals(df,cluster[,normalize])
	dfref df
	variable cluster
	variable normalize // (0) Cumulative spikes; (1) Cumulative probability.  
	
	wave /z/sdfr=df clusters,lambdas
	if(!waveexists(lambdas))
		printf "Features wave '%s' does not exist.  You must create it by the appropriate dimensional reduction.\r","lambdas"
		return $""
	elseif(sum(lambdas)==0)
		printf "Features wave '%s' is full of zeroes.\r","lambdas"
		return $""
	endif
	wave d2=MahalDistance(Lambdas,clusters,doClusters={cluster})
		
	variable i
	wavestats /q/m=1 clusters
	make /free/n=(v_max+1)/wave d2s=$""
	for(i=0;i<=v_max;i+=1)
		extract /free d2,w,clusters==i
		if(!numpnts(w))
			continue
		endif
		if(normalize)
			ecdf(w)
		else
			sort w,w
			setscale /p x,0,1,w
		endif
		d2s[i]=w//df:$("d2_"+num2str(i))
	endfor
	return d2s
end

Function PlotMahal(df,cluster[,normalize,regenerate])
	dfref df
	variable cluster
	variable normalize // (0) Cumulative spikes; (1) Cumulative probability.  
	variable regenerate 
	
	wave /wave d2s=MakeMahals(df,cluster,normalize=normalize)
	if(wintype("MahalPlot") && !regenerate)
		removetraces(win="MahalPlot")
	else
		dowindow /k MahalPlot
		display /k=1/n=MahalPlot as "Mahalanobis Distances (d^2)"
	endif
		
	variable i
	for(i=0;i<numpnts(d2s);i+=1)
		wave /z w=d2s[i]
		if(!waveexists(w))
			continue
		endif
		duplicate /o w,df:$("d2_"+num2str(i)) /wave=w_
		variable red,green,blue
		GetClusterColors(i,red,green,blue)
		appendtograph  /w=MahalPlot /c=(red,green,blue) w_
	endfor
	modifygraph /w=MahalPlot swapXY=1,log(bottom)=1,log(left)=!normalize,axisEnab(left)={0,0.95}
	label /w=MahalPlot bottom "D\S2\M"
	label /w=MahalPlot left selectstring(normalize,"Cumulative Spikes","Cumulative Probability")
	string userData="DF:"+getdatafolder(1,df)+";Cluster:"+num2str(cluster)+";"
	checkbox normalize, title="Normalize",userdata=userData,proc=MahalPlotCheckboxes,win=MahalPlot
	if(WinType("NlxViewer"))
		AutoPositionWindow /R=NlxViewer
	endif
End

function MahalPlotCheckboxes(info)
	struct wmcheckboxaction &info
	
	if(info.eventCode<0)
		return -1
	endif
	strswitch(info.ctrlName)
		case "Normalize":
			dfref df=$stringbykey("DF",info.userData)
			variable cluster=numberbykey("Cluster",info.userData)
			PlotMahal(df,cluster,normalize=info.checked)
			break
	endswitch
end

Function /s SelectedClusters([brief,option])
	variable brief // Summarize all clusters as "All", etc.  
	string option
	
	option=selectstring(!paramisdefault(option),"checked",option)
	dfref nlx=$PACKAGE_FOLDER
	wave /sdfr=nlx selWave
	wave /t/sdfr=nlx listWave
	string clusters=""
	variable i
	if(stringmatch(option,"checked"))
		for(i=0;i<dimsize(listWave,0);i+=1)
			if(selWave[i][1][0] & 16)
				clusters+=listWave[i][0]+";"
			endif
		endfor
	elseif(stringmatch(option,"highlighted"))
		controlinfo /w=nlxviewer cluster
		clusters+=listWave[v_value][0]+";"
	endif
	return clusters
End

// ---------------------------- Clustering -------------------------------------

// Determine salient features for clustering using principal components analysis (PCA).
Function /WAVE ClusterFeatures(df[,method,numFeatures,flatten,writeFeatures,append_])
	dfref df // A data folder containing e.g. a 32xNx4 Tetrode wave.  
	string method // "PCA" or "DWT"
	Variable numFeatures // Number of principal components to keep, e.g. 3.   A value of 0 or less will use a Malinowski F-test to determine how many principal components to keep.  Won't work unless data is flattened.  
	Variable flatten // For multiple electrodes, e.g. tetrodes, will flatten to produce a matrix so that the new number of samples is samples * numElectrodes.  
	Variable writeFeatures // Overwrite the feature data (e.g. replace peak values with lambdas).  
	variable append_ // Append to the existing features wave (more columns).  
	
	wave /sdfr=df data
	if(numpnts(data)==0)
		return NULL
	endif
	method=selectstring(!paramisdefault(method),defaultFeatureMethod,method)
	string methodDetails=stringfromlist(1,method,":")
	method=stringfromlist(0,method,":")
	flatten=paramisdefault(flatten) ? 1 : flatten
	writeFeatures=paramisdefault(writefeatures) ? 1 : writefeatures
	variable points=dimsize(data,0) // Number of samples per spike per electrode.  Usually 32.  
	variable replications=dimsize(data,1) // Number of spikes.  
	if(numFeatures<=0)
		strswitch(method)
			case "PCA":
				variable doMalinowski=1
				numFeatures=points
				flatten=1
				break
			case "DWT":
				numFeatures=10 // Default to 10 best features.  
				break
		endswitch
	endif
	numFeatures=(numFeatures==0) ? 3 : numFeatures
	variable numElectrodes=max(1,dimsize(data,2)) // e.g. 4 for a tetrode.  
	variable groups=flatten ? 1 : numElectrodes // Number of groups.  1 unless the data from each electrode is to be treated independently.  
	variable i,j,electrode
	
	wave /z/sdfr=df lambdas
	if(!append_ || !waveexists(lambdas))		
		make /o/n=(replications,numFeatures*groups) df:lambdas /wave=Lambdas=0
		variable column=0
	else
		column=dimsize(lambdas,1)
		redimension /n=(-1,column+numFeatures*groups) lambdas
		lambdas[][column,]=0
	endif
	strswitch(method)
		case "PCA":
			Make /o/n=(points*numElectrodes/groups,numFeatures*groups) df:princomps /WAVE=PCs
			for(i=0;i<groups;i+=1)
				Make /free/n=(points*numElectrodes/groups,replications) NormalizedData
				if(numElectrodes==1)
					NormalizedData=Data
				elseif(numElectrodes>1)
					if(flatten)
						NormalizedData=Data[mod(p,points)][q][floor(p/points)]
					else
						NormalizedData=Data[p][q][i]
					endif
				endif
				MatrixOp /o NormalizedData=subtractmean(subtractmean(NormalizedData,2),1)
				redimension /n=(-1,max(1,dimsize(NormalizedData,1))) NormalizedData // Make sure there is at least one column.  
				wavestats /q/m=1 NormalizedData
				if(v_max==0 && v_min==0)
				else
					PCA /LEIV /SCMT /SRMT /VAR NormalizedData
					wave M_R // Each column of this matrix is a principal component.  NormalizedData=M_R*M_C
					wave M_C // Each row of this matrix is the coefficients for one principal component.  
					PCs[][i*numFeatures,(i+1)*numFeatures-1]=M_R[p][q-i*numFeatures]
					Lambdas[][column+i*numFeatures,column+(i+1)*numFeatures-1]=M_C[q-i*numFeatures-column][p] // Lambdas for all tetrodes, with 'num_PCs' columns per tetrode.  
				endif
			endfor
			if(doMalinowski)
				Wave W_VAR
				variable sig=Malinowski(W_VAR,0.001)
				printf "%d signficant dimensions found\r",sig
				redimension /n=(-1,sig) Lambdas,PCs
			endif
			KillWaves /Z M_R,M_C,W_VAR
			break
		case "DWT": // Always flattens.  
			wave dwts=DWTSpikes(df)
			if(1)
				MatrixOp /o NormalizedData=subtractmean(subtractmean(dwts,2),1)
				PCA /LEIV /SCMT /SRMT /VAR NormalizedData
				Wave M_R // Each column of this matrix is a principal component.  NormalizedData=M_R*M_C
				Wave M_C // Each row of this matrix is the coefficients for one principal component.  
				wave lills=LillieforsFeatures(M_C)
				lambdas[][column,]=M_C[lills[q-column][0]][p]
			else
				wave lills=LillieforsFeatures(dwts)
				lambdas[][column,]=dwts[lills[q-column][0]][p]
			endif
			killwaves /z dwts
			break
		case "Point":
			variable pointNum=str2num(methodDetails)
			for(i=0;i<groups;i+=1)
				make /free/n=(points*numElectrodes/groups,replications) NormalizedData
				NormalizedData=Data[p][q][i]
				lambdas[][column+i,]=NormalizedData[pointNum][p]
			endfor
			break
		default:
			printf "No such cluster feature type: %s.\r",method
			return NULL
	endswitch
	
	// Normalize so that each feature has standard deviation = 1 across all spikes.  
	matrixop /free featureSDs=sqrt(varcols(lambdas))
	lambdas/=featureSDs[q]
	variable deleted=0
	i=0
	do
		if(featureSDs[i]==0 || numtype(featureSDs[i]))
			printf "Deleting feature %d because it is either has zero, infinite, or NaN variance.\r",i+deleted
			deletepoints /m=1 i,1,featureSDs,lambdas
			deleted+=1
		else
			i+=1
		endif
	while(i<dimsize(lambdas,1))
	// Delete any columns that are highly correlated with other columns.  
	if(dimsize(lambdas,1)>1)
		i=0
		do
			wave w1=col(lambdas,i)
			j=i+1
			do
				wave w2=col(lambdas,j)
				variable corr=statscorrelation(w1,w2)
				if(abs(corr)>1) // Shouldn't happen.  
					printf "Deleting feature %d because it is too correlated with feature %d (r=%.2f).\r",j+deleted,i+deleted,corr
					deletepoints /m=1 j,1,lambdas
					deleted+=1
				else
					j+=1
				endif
			while(j<dimsize(lambdas,1))
			i+=1
		while(i<(dimsize(lambdas,1)-1))
	endif
	
	if(writeFeatures)
		FeatureWrite(df,Lambdas)
	endif
	return Lambdas
End

function /wave DWTSpikes(df)
	dfref df
	wave /sdfr=df data
	variable spikes=dimsize(data,1)
	make /free/n=(128,spikes) data_=data[mod(p,32)][q][floor(p/32)]
	variable i
	for(i=0;i<spikes;i+=1)
		if(mod(i,100)==0)
			prog("Spike",i,spikes)
		endif
		wave oneSpike=col(data_,i)
		dwt /t=2 oneSpike
		wave w_dwt
		make /o/n=(numpnts(w_dwt),spikes) df:dwts /wave=dwts
		dwts[][i]=w_dwt[p]
	endfor
	prog("Spike",i,spikes)
	killwaves /z w_dwt
	return dwts
end

function /wave LillieforsFeatures(w)
	wave w // Matrix of features, one row per feature.  
	
	variable i,numFeatures=dimsize(w,0),numData=dimsize(w,1)
	make /free/n=(numFeatures) lills
	for(i=0;i<numFeatures;i+=1)
		prog("Feature",i,numFeatures)
		wave feature=row(w,i)
		redimension /n=(numData) feature
		lills[i]=LillieforsDmax(feature)
	endfor
	make /free/n=(numFeatures) index=p
	extract /free index,index_,numtype(lills)==0
	extract /free lills,lills_,numtype(lills)==0
	sort /r lills_,lills_,index_
	make /free/n=(numpnts(index_),2) results
	results[][0]=index_[p]
	results[][1]=lills_[p]
	return results
end

function Cluster2DVisualize(df[,feature,showClusters,maxFeatures])
	dfref df
	string feature
	string showClusters // Optional string of cluster numbers to show.  Default is all clusters.  
	variable maxFeatures
	
	feature=selectstring(!paramisdefault(feature),"lambdas",feature)
	wave /z features=df:$feature
	if(!waveexists(features))
		printf "Feature wave '%s' could not be found in %s\r",feature,getdatafolder(1,df)
	endif
	if(paramisdefault(maxFeatures))
		maxFeatures=dimsize(features,1)
	endif
	maxFeatures=min(maxFeatures,dimsize(features,1))
	
	dowindow /k Cluster2DWin
	display /k=1 /n=Cluster2DWin as "Cluster 2D Visualization"
	variable i,j
	for(i=0;i<maxFeatures;i+=1)
		string leftAxis="left"+num2str(i)
		for(j=0;j<i;j+=1)
			string bottomAxis="bottom"+num2str(j)	
			appendtograph /l=$leftAxis /b=$bottomAxis features[][i] vs features[][j]
			label $leftAxis "D"+num2str(i)
			label $bottomAxis "D"+num2str(j)
		endfor	
	endfor
	wave /z/sdfr=df clusters
	if(waveexists(clusters))
		dfref pf=$PACKAGE_FOLDER
		duplicate /o clusters,pf:clustersMask /wave=clustersMask
		if(!paramisdefault(showClusters))
			clustersMask=nan
			for(i=0;i<itemsinlist(showClusters);i+=1)
				variable cluster=str2num(stringfromlist(i,showClusters))
				clustersMask=(clusters[p]==cluster) ? clusters[p] : clustersMask[p]
			endfor
		endif
		variable numSpikes=numpnts(clusters)
		duplicate /o ClusterColorWave(100),pf:clusterColors /wave=colors
		variable red,green,blue
		modifygraph zColor={clustersMask,*,*,cindexRGB,0,colors},zColorMax=nan
		make /free featureMin,featureMax
		for(i=0;i<maxFeatures;i+=1)
			leftAxis="left"+num2str(i)
			bottomAxis="bottom"+num2str(i)	
			extract /free features,featuresClustered,clusters[p]>0 && q==i
			if(numpnts(featuresClustered)>=2)
				if(1)
					statsquantiles /q featuresClustered
					variable minn=v_median-v_iqr*5
					variable maxx=v_median+v_iqr*5
				else
					wavestats /q/m=1 featuresClustered
					minn=v_avg-v_sdev*5
					maxx=v_avg+v_sdev*5
				endif
				setaxis /z $leftAxis minn,maxx
				setaxis /z $bottomAxis minn,maxx
			endif
		endfor
		variable maxCluster=wavemax(clusters)
		string str=""
		for(i=0;i<=maxCluster;i+=1)
			GetClusterColors(i,red,green,blue)
			sprintf str,"%s\\K(%d,%d,%d) %d \r",str,red,green,blue,i
		endfor
		//TextBox/C/N=GizmoColors/f=0/B=(60928,60928,60928)/A=RB/X=0/Y=0 "\Z18"+removeending(str,"\r")
	endif
	modifygraph mode=2,nticks=0,axThick=0,lblposmode=1
	TileAxes()
	movewindow /w=Cluster2DWin 100,100,700,600
	ClusterPanel(df,checked=SelectedClusters(option="checked"))
	AutoPositionWindow /R=Cluster2DWin
end

function LeastGaussianProjection(df,cluster1,cluster2)
	dfref df
	variable cluster1,cluster2
	
	wave /z/sdfr=df clusters,dwts
	if(!waveexists(dwts))
		printf "Must create DWT wave first with DWTSpikes().\r"  
		return -1
	endif
	extract /indx/free clusters,clusters12,(clusters[p]==cluster1 || clusters[p]==cluster2)
	make /free/n=(numpnts(clusters12),128) dwts12=dwts[clusters12[p]][q]
  	matrixtranspose dwts12
	wave lills=LillieforsFeatures(dwts12)
	string name
	sprintf name,"dwts_%d_%d",cluster1,cluster2
	duplicate /o dwts,df:$name /wave=dwts12
	dwts12=dwts[p][lills[q][0]]
	Cluster2DVisualize(df,feature=name,maxFeatures=8)
end

Function FeatureWrite(df,NewFeatures[,offset])
	dfref df
	wave NewFeatures
	Variable offset
	
	Wave /I/U/Z Features=df:Features
	if(!WaveExists(NewFeatures) || !WaveExists(Features))
		Post_("Could not find Features wave.")
		return -1
	endif
	WaveStats /Q/M=1 NewFeatures
	Variable maxx=2^32-1, denom=V_max-V_min
	Features[][offset,min(offset+2,8)]=maxx*(NewFeatures[p][q-offset]-V_min)/denom // Rescale to be 32-bit unsigned.  
	
	Wave /z/sdfr=df MetaData
	if(waveexists(MetaData))
		Struct NlxMetaData NlxMetaData
		StructGet NlxMetaData MetaData
		Variable i
		for(i=offset;i<min(offset+3,8);i+=1)
			NlxMetaData.feature[i].name="PC"+num2str(i-offset+1)
			NlxMetaData.feature[i].chan=-1
		endfor
	endif
End

Function ClusterCollection(name,clusterDFs)
	string name
	wave /df clusterDFs
	
	variable i
	name=cleanupname(name,0)
	string destName="root:"+name
	newdatafolder /o $destName
	dfref newDF=$destName
	make /o/n=0 newDF:data /wave=data,newDF:times /wave=times
	make /o/n=0/i newDF:clusters /wave=clusters
	string /g newDF:clusterNames=""
	svar /sdfr=newDF clusterNames
	for(i=0;i<numpnts(clusterDFs);i+=1)
		dfref df=clusterDFs[i]
		wave clusterTimes=df:times, clusterClusters=df:clusters
		concatenate /np {clusterTimes},times
		duplicate /free clusterClusters,temp
		temp+=100*i
		concatenate /np {temp},clusters
		string sourceName=getdatafolder(1,df)
		string sourceNameClean=Nlx#df2filename(df)
	 	clusterNames+=num2str(temp[0])+":"+sourceNameClean+";"
		duplicatefoldercontents(sourceName,destName+":"+sourceNameClean)
		svar type=df:type
	endfor
	string /g newDF:type=type
	ReindexClusters(newDF)
End

Function ReindexClusters(df)
	dfref df
	
	wave /sdfr=df clusters
	svar /z/sdfr=df clusterNames
	make /free/n=1 used=0
	wavestats /q clusters
	variable oldIndex,newIndex=1
	for(oldIndex=1;oldIndex<=v_max;oldIndex+=1)
		clusters=(clusters==oldIndex) ? newIndex : clusters
		findvalue /i=(newIndex) clusters
		if(v_value>=0)
			if(svar_exists(clusterNames))
				string name=StringByKey(num2str(oldIndex),clusterNames)
				clusterNames=removebykey(num2str(oldIndex),clusterNames)
				clusterNames+=num2str(newIndex)+":"+name+";"
			endif
			newIndex+=1
		endif
	endfor
End

Function ExtractAllClusters(df)
	dfref df
	
	wave /w/sdfr=df Clusters
	variable i
	for(i=0;i<1000;i+=1)
		findvalue /i=(i) Clusters
		if(V_Value>=0) // If there is at least one unit assigned to cluster 'i'.
			ExtractClusters(df,num2str(i))
		endif
	endfor
End

// Extract only spikes from Data that belong to certain clusters.  
Function /s ExtractClusters(df,clusterz[,type,name])
	dfref df // The folder containing of spike data.  
	String type // ntt.  
	String clusterz // e.g. "8" or "8,12" (8 through 12) or "8,10;14,18" (8 through 10 and 14 through 18).  
	String name // Optional suffix for the extracted data.  
	
	if(paramisdefault(type))
		type=Nlx#DataType(df)
	endif
	clusterz=ListExpand(clusterz)
	wave /sdfr=df Data,Clusters,Times,Features
	
	if(!strlen(clusterz))
		Variable i
		for(i=0;i<numpnts(Clusters);i+=1)
			if(WhichListItem(num2str(Clusters[i]),clusterz)<0)
				clusterz+=num2str(Clusters[i])+";"
			endif
		endfor	
	endif
	
	if(ParamIsDefault(name))
		name=RemoveEnding(clusterz[0,7],";")
	endif
	string newDFname=CleanupName("U"+name,0)
	newdatafolder /o df:$newDFname
	dfref newDF=df:$newDFname
	if(ItemsInList(clusterz)==1) // If there is only one cluster to extract, use this faster method.  
		variable clusterNum=str2num(stringfromlist(0,clusterz))
		extract /o/free/indx Clusters,Indices,Clusters[p]==clusterNum
	else
		extract /o/free/indx Clusters,Indices,WhichListItem(num2str(Clusters[p]),clusterz)>=0
	endif
	variable count=numpnts(indices)
	make /o/n=(dimsize(data,0),count,dimsize(data,2)) newDF:data /WAVE=NewData=Data[p][Indices[q]][r]
	make /o/D/n=(count) newDF:times /WAVE=NewTimes=Times[Indices[p]]
	make /o/I/n=(count) newDF:clusters /WAVE=NewClusters=Clusters[Indices[p]]
	make /o/I/n=(count,dimsize(features,1)) newDF:features /WAVE=NewFeatures=Features[p][Indices[q]]
	wave /z/sdfr=df lambdas
	if(waveexists(lambdas))	
		make /o/n=(count,dimsize(lambdas,1)) newDF:lambdas=Lambdas[Indices[p]][q]
	endif
	if(waveexists(df:header))
		duplicate /o df:header newDF:header
		duplicate /o df:metadata newDF:metadata
	endif
	string /g newDF:type=type
	
	strswitch(type)
		case "ntt":
			if(numpnts(NewData))
				Redimension /n=(32,numpnts(NewData)/128,4) NewData
			endif
			break
		default:
			if(numpnts(NewData))
				Redimension /n=(count) NewData
			endif
	endswitch
	return getdatafolder(1,newDF)
End

// Extract only spikes from Data that occur close in time to certain events.  
Function /s ExtractSpontaneous(df,Events,range[,trim,name])
	dfref df // The folder containing the spike data.  
	wave Events // The wave of event times.  
	wave range // Two points indicating the start and end of the window to exclude, relative to the event times. 
	variable trim // Trim the exlcuded spaces so there are no gaps.  
	string name // Optional name for the extracted data.  
	
	name = selectstring(!paramisdefault(name),"Spont",name)
	return ExtractEvoked(df,Events,range,exclude=1,trim=trim,name=name)
End

// Extract only the Data that occur close in time to certain events.  
Function /s ExtractEvoked(df,Events,range[,exclude,trim,name])
	dfref df // The folder containing the data (spikes, lfp, etc.).  
	wave Events // The wave of event times.  
	wave range // Two points indicating the start and end of the window to extract, relative to the event times. 
	variable exclude // Exclude instead of including this range.  
	variable trim // Trim the exlcuded spaces so there are no gaps.  
	string name // Optional name for the extracted data.  
	
	if(ParamIsDefault(name))
		name = selectstring(exclude,"Evoked","Spont")
	endif
	string newDFname=CleanupName(name,0)
	newdatafolder /o df:$newDFname
	dfref newDF=df:$newDFname
	string type=Nlx#DataType(df)
	
	wave /z/sdfr=df Data,Clusters,Times,Features,Phase
	if(!waveexists(Times))
		wave Times=TimesFromData(df)
	endif
	
	make /free/n=(numpnts(times)) Recent = BinarySearch(Events,Times[p]-range[0])
	Recent = Recent[p]==-2 ? numpnts(Events)-1 : Recent[p]
	extract /o/free/indx Times,Indices,!exclude == ((Times[p]-Events[Recent[p]])<range[1] || (Times[p]-Events[Recent[p]+1])>range[0])
	variable count=numpnts(indices)
	make /o/D/n=(count) newDF:times /WAVE=NewTimes=Times[Indices[p]]
	if(trim)
		if(exclude)
			NewTimes -= (range[1]-range[0])*(Recent[Indices[p]]+1)
		else
			make /free/n=(numpnts(Events)) Gaps = 0
			Gaps[1,] = (Events[p]+range[0]) - (Events[p-1]+range[1])
			Integrate Gaps
			NewTimes -= Gaps[Recent[Indices[p]]]
		endif
	endif
	if(waveexists(df:header))
		duplicate /o df:header newDF:header
	endif
	if(waveexists(df:metadata))
		duplicate /o df:metadata newDF:metadata
	endif
	string /g newDF:type=type
	
	strswitch(type)
		case "ntt":
			if(waveexists(data))
				make /o/n=(dimsize(data,0),count,dimsize(data,2)) newDF:data /WAVE=NewData=Data[p][Indices[q]][r]
				if(numpnts(NewData))
					Redimension /n=(32,numpnts(NewData)/128,4) NewData
				endif
			endif
			make /o/I/n=(count) newDF:clusters /WAVE=NewClusters=Clusters[Indices[p]]
			if(waveexists(features))
				make /o/I/n=(count,dimsize(features,1)) newDF:features /WAVE=NewFeatures=Features[p][Indices[q]]
			endif
			break
		case "ncs":
		case "igor":
			make /o/n=(count) newDF:data /WAVE=NewData=Data[Indices[p]]
			if(waveexists(Phase))
				make /o/n=(count) newDF:phase=Phase[Indices[p]]
			endif
			if(numpnts(NewData))
				Redimension /n=(count) NewData
			endif
			break
		default:
			Post_("Not a supported data type: "+type)
			break
	endswitch
	return getdatafolder(1,newDF)
End

Function ClusterStats(df,clusterList)
	dfref df
	string clusterList // List of clusters.  Usually just one.  
	wave /sdfr=df data,clusters,times
	
	string clusterStr=removeending(replacestring(";",clusterList,"_"),"_")
	
	variable i,spikes=0,electrode
	wavestats /q/m=1 clusters
	variable maxCluster=v_max
	make /o/n=0 df:$("ISI_"+clusterStr) /wave=ISI=0
	make /o/n=(32,4,maxCluster+1) df:$("Mean_"+clusterStr) /wave=Meann=0
	make /o/n=(32,4,maxCluster+1) df:$("StDev_"+clusterStr) /wave=StDev=0
	make /o/n=(4,maxCluster+1) df:$("SNR_"+clusterStr) /wave=SNR=0
	make /o/n=(4,maxCluster+1) df:$("Ampl_"+clusterStr) /wave=Ampl=0
	make /o/n=(4,maxCluster+1) df:$("WidthPV_"+clusterStr) /wave=WidthPV=nan
	make /o/n=(4,maxCluster+1) df:$("WidthBrunoInit_"+clusterStr) /wave=WidthBrunoInit=nan
	make /o/n=(4,maxCluster+1) df:$("WidthBrunoAHP_"+clusterStr) /wave=WidthBrunoAHP=nan
	
	variable clusterLogic=BitList2Num(clusterList)
	for(i=0;i<dimsize(data,1);i+=1)
		if(!(clusterLogic & 2^Clusters[i])) // If spike i is not in the list of clusters.  
			continue
		endif
		meann+=data[p][i][q]
		stdev+=data[p][i][q]^2
		ISI[spikes]={times[i]}
		spikes+=1
	endfor
	differentiate /meth=2 ISI
	deletepoints 0,1,ISI // Delete first spike, where ISI is unknown.  
	sort ISI,ISI
	meann/=spikes
	stdev/=spikes
	stdev=sqrt(stdev-meann^2)
	for(electrode=0;electrode<4;electrode+=1)
		matrixop /free meann0=col(Meann,electrode)
		matrixop /free stdev0=col(StDev,electrode)	
		make /o/n=1000 meann1=nan
		setscale x,0,dimdelta(data,0), meann1
#if exists("Interpolate2")
		Interpolate2 /Y=meann1 meann0 
#endif
		wavestats /q/m=1 meann1
		variable maxx=v_max,minn=v_min
		Ampl[electrode]=maxx*10^6 // In microV.  
		variable baselineNoise=stdev0[0]*10^6 // In microV.  
		SNR[electrode]=Ampl[electrode]/baselineNoise
		if(v_minloc>v_maxloc)
			WidthPV[electrode]=v_minloc-v_maxloc
			
			findlevel /q/r=(v_maxloc,0) meann1,maxx/2
			if(!v_flag)
				variable left=v_levelX
				findlevel /q/r=(v_maxloc,inf) meann0,maxx/2
				if(!v_flag)
					variable right=v_levelX
					WidthBrunoInit[electrode]=(right-left)*dimdelta(data,0)
				endif
			endif
			
			findlevel /q/r=(v_minloc,0) meann1,minn/2
			if(!v_flag)
				left=v_levelX
				findlevel /q/r=(v_minloc,inf) meann0,minn/2
				if(!v_flag)
					right=v_levelX
					WidthBrunoAHP[electrode]=(right-left)*dimdelta(data,0)
				endif
			endif
		endif
		killwaves /z meann1
	endfor
End

Function DisplayClusterStats([df,clusters,recalc,periods])
	dfref df
	string clusters
	variable recalc // Recalculate stats.  
	wave periods
	
	if(paramisdefault(df))
		ControlInfo /W=NlxViewer DataName
		dfref df=$("root:"+S_Value)
	endif
	if(paramisdefault(clusters))
		wave clusters_=ClustersWithSpikes(df)
		variable i
		clusters=""
		for(i=0;i<numpnts(clusters_);i+=1)
			clusters+=num2str(clusters_[i])+";"
		endfor
	endif
	recalc=paramisdefault(recalc) ? 1 : recalc
	clusters=removeending(replacestring(";",clusters,"_"),"_")
	if(paramisdefault(periods))
		string pethInstance=Core#DefaultInstance(module,"PETH")
		wave periods=DefaultPrePostPeriods(pethInstance)
	endif
	
	if(recalc)
		ClusterStats(df,clusters)
		MannWhitney(periods=periods,df=df,aprx=1,freshTrials=1)
	endif
	
	string name=getdatafolder(1,df)+"_"+clusters+"_stats"
	name=name[5,strlen(name)-1] // Get rid of leading "root:"
	name=cleanupname(name,0)
	dowindow /k $name
	edit /k=1/n=$name as "Waveform Stats for "+getdatafolder(0,df)+"; Cluster(s): "+clusters
	string waves2Append="MannWhitneyP;Ampl;SNR;WidthPV;WidthBrunoInit;WidthBrunoAHP;ISI;Mean;StDev;"
	for(i=0;i<itemsinlist(waves2Append);i+=1)
		string wave2Append=stringfromlist(i,waves2Append)
		wave /sdfr=df w=$(wave2append+"_"+clusters)
		appendtotable w
	endfor
End

Function DisplayClusterISI(df,clusterList[,recompute,redraw])
	dfref df
	string clusterList
	variable recompute,redraw
	
	recompute=paramisdefault(recompute) ? 1 : recompute
	string clusterStr=removeending(replacestring(";",clusterList,"_"),"_")
	string name="Cluster_ISI"
	if(redraw || !wintype(name))
		dowindow /k $name
		display /k=1 /n=$name as "ISI Histogram"// for "+getdatafolder(0,df)+"; Cluster(s): "+clusters
	else
		dowindow /f $name
	endif
	variable i
	variable red,green,blue 
	variable clusterNum=(itemsinlist(clusterList)>1) ? -1 : str2num(stringfromlist(0,clusterList))
	GetClusterColors(clusterNum,red,green,blue)
	removetraces(win=name)
	string userData
	sprintf userData,"DF:%s;CLUSTERS:%s;RGB:%d,%d,%d;RECOMPUTE:%d",getdatafolder(1,df),replacestring(";",clusterList,","),red,green,blue,recompute
	setwindow kwTopWin userData=userData
	struct wmcheckboxaction info
	info.ctrlName="check_Consecutive"
	ISIHistogramCheckboxes(info)
	dfref nlx=$PACKAGE_FOLDER
	if(0)
		wave /sdfr=nlx logISIHist
		appendtograph /w=$name /c=(red,green,blue) logISIHist
		make /o/n=7 nlx:logISI_ticks /wave=ticks_=x-4
		make /o/t/n=7 nlx:logISI_tickLabels /wave=tickLabels={"0.1 ms","1 ms","10 ms","100 ms","1 s","10 s","100 s"}
		modifygraph /z/w=$name mode(logISIHist)=5,mode(logISIcumHist)=0,userTicks(bottom)={ticks_,tickLabels},log(left)=1
	else
		wave /sdfr=nlx ISIHist
		appendtograph /w=$name /c=(red,green,blue) ISIHist
		//make /o/n=7 nlx:ISI_ticks /wave=ticks_=x-4
		//make /o/t/n=7 nlx:logISI_tickLabels /wave=tickLabels={"0.1 ms","1 ms","10 ms","100 ms","1 s","10 s","100 s"}
		modifygraph /z/w=$name mode(ISIHist)=5,mode(ISIcumHist)=0
	endif
	modifygraph /z/w=$name axisEnab(left)={0,0.95},axisEnab(right)={0,0.95},log(left)=1,prescaleExp(bottom)=3
	label /w=$name bottom "ISI (ms)"
	label /w=$name left "Spike Count"
	label /z/w=$name right "Cumulative Spike Count"
	wave /sdfr=df ISI=$("ISI_"+clusterStr)
	variable med=statsmedian(ISI) // Median ISI in s.  
	variable rate=ln(2)/med // Because the median = mean*ln(2) for an exponential distribution.  
	string stats
	sprintf stats,"Median ISI = %.1f ms    Typical Firing Rate = %.2f Hz",med*1000,rate
	Textbox /w=$name/a=MT/X=8/Y=-7/t=1/f=0/n=stats/c stats
	checkbox check_Consecutive,mode=1,value=1,proc=ISIHistogramCheckboxes,title="Consecutive"
	checkbox check_All,pos={85,2},mode=1,value=0,proc=ISIHistogramCheckboxes,title="All"
	if(wintype("NlxViewer"))
		AutoPositionWindow /R=NlxViewer $name
	endif
End

function ISIHistogramCheckboxes(info)
	struct wmcheckboxaction &info
	
	if(info.eventCode<0)
		return -1
	endif
	string name="Cluster_ISI"
	string userData=getuserdata(info.win,"","")
	dfref df=$stringbykey("DF",userData)
	string clusterList=replacestring(",",stringbykey("CLUSTERS",userData),";")
	variable recompute=numberbykey("RECOMPUTE",userData)
	string clusterStr=removeending(replacestring(";",clusterList,"_"),"_")
	dfref nlx=$PACKAGE_FOLDER
	string checkboxes=controlnamelist(info.win,";","check_*")
	variable i
	for(i=0;i<itemsinlist(checkboxes);i+=1)
		checkbox $stringfromlist(i,checkboxes) value=0
	endfor
	checkbox $info.ctrlName value=1
	removefromgraph /z/w=$name logISIcumHist
	variable clusterLogic=BitList2Num(clusterList)
	strswitch(info.ctrlName)
		case "check_Consecutive": // Consecutive spikes, i.e. a conventional definition of ISI.  
			if(recompute)
				wave /sdfr=df times,clusters
				extract /o times,df:$("ISI_"+clusterStr) /wave=ISI,(clusterLogic & 2^clusters[p])>0
				differentiate /meth=2 ISI
				deletepoints 0,1,ISI // Delete first spike, where ISI is unknown.
				variable rescale=0
				if(rescale)
					duplicate /free ISI smoothISI
					smooth 10,smoothISI
					ISI/=smoothISI
				endif
				sort ISI,ISI
				if(0)
					duplicate /o ISI nlx:logISI /wave=logISI
					logISI=log(ISI)
					make /o/n=50 nlx:logISIHist /wave=logISIHist
					make /o/n=1000 nlx:logISIcumHist /wave=logISIcumHist
					setscale x,-4,3,logISIHist,logISIcumHist // 0.1 ms to 1000 seconds.  
					histogram /b=2 logISI,logISIHist
					histogram /b=2/cum logISI,logISIcumHist
					wave ISIcumHist=logISIcumHist
				else
					make /o/n=50 nlx:ISIHist /wave=ISIHist
					make /o/n=1000 nlx:ISIcumHist /wave=ISIcumHist
					setscale x,0,0.1,ISIHist,ISIcumHist // 0 to 100 ms  
					//print numpnts(ISI)
					histogram /b=2 ISI,ISIHist
					//print sum(ISIHist),wavemax(ISIHist)
					histogram /b=2/cum ISI,ISIcumHist
					//wave ISIcumHist=logISIcumHist
				endif
			endif
			appendtograph /w=$name /r/c=(0,0,0) ISIcumHist
			break
		case "check_All": // All spikes times vs. all other spike times, i.e. an auto-correlogram.  
			if(recompute)
				wave /sdfr=df times,clusters
				extract /free times,clusterTimes,(clusterLogic & 2^clusters[p])>0
				variable numSpikes=numpnts(clusterTimes)
				make /free/n=(numSpikes,numSpikes) diffs
				multithread diffs=p==q ? nan : log(abs(clusterTimes[p]-clusterTimes[q]))
				make /o/n=50 nlx:logISIHist /wave=logISIHist
				setscale x,-4,3,logISIHist
				histogram /b=2 diffs,logISIHist
				logISIHist/=10^x
			endif
			break		
	endswitch
end

function ComputeClusterDistances(df)
	dfref df
	
	string epoch=getdatafolder(0,df)
	wave /sdfr=df clusters
	variable i,j,numClusters=wavemax(clusters)
	make /o/n=(numClusters,numClusters) df:allClusterDistances /wave=allClusterDistances=nan
	for(i=0;i<numClusters;i+=1)
		string source_i=SourceElectrode(df,i)
		if(!strlen(source_i))
			continue
		endif
		string tetrode_i=stringfromlist(0,source_i,":")
		variable cluster_i=str2num(stringfromlist(1,source_i,":"))
		string str="root:"+tetrode_i+":"+epoch
		dfref tetrodeDF=$str
		for(j=0;j<numClusters;j+=1)
			string source_j=SourceElectrode(df,j)
			if(!strlen(source_j))
				continue
			endif
			string tetrode_j=stringfromlist(0,source_j,":")
			if(stringmatch(tetrode_i,tetrode_j))
				variable cluster_j=str2num(stringfromlist(1,source_j,":"))
				wave /sdfr=tetrodeDF clusterDistances
			 	allClusterDistances[i][j]=clusterDistances[cluster_i][cluster_j]
			endif
		endfor
	endfor
end

// ---------------------------------------------- Cluster Visualiztion ------------------------------------------------

// Used to cluster Neuralynx spike data using PCA, or simply visualize already clustered data.  
// Clustering not recommended if something more serious like Klustakwik or BubbleClust, plus manual cutting, is available.  
// Assumeses that the Feature data is already on a Gizmo plot.  
Function Clustering(df,feature,numClasses)
	dfref df
	string feature // The name of a wave with feature data, like "lambdas"
	variable numClasses // 0 to show the existing clusters\, >0 to recluster.  
	
	Wave Data=df:Data,Features=df:$feature
	variable numSpikes=dimsize(Features,0)
	variable useSpikeSortColors=1 // 1 to color according to SpikeSort3D, 0 to use a generic color map.  

	if(!useSpikeSortColors) // Color according to a generic color map.  
		ColorTab2Wave Rainbow; Wave M_Colors
		Variable numColorWavePoints=dimsize(M_Colors,0)
	endif
	dfref nlx=$PACKAGE_FOLDER
	Make /o/n=(numSpikes,4) nlx:GizmoColors /WAVE=GizmoColors
	if(numClasses>0) // TO DO: Replace with a call to Klustakwik.  
		MatrixOp /FREE FeaturesT=Features^t
		KMeans /OUT=2 /NCLS=(numClasses) /SEED=(gnoise(1)) /INIT=1 FeaturesT
		Wave Clusters=W_KMMembers
		killwaves /z FeaturesT
	else
		Wave /Z/sdfr=df Clusters
	endif
	
	wave Visualize=Cluster3DVisualize(df,feature=feature)
	variable i
	
	// Ceneter each column (feature).
	
	for(i=0;i<dimsize(Visualize,1);i+=1)
		matrixop /free column=col(Visualize,i)
		column=abs(column)
		variable med=statsmedian(column)
		column=column>10*med ? med*10 : column
		Visualize[][i]=sign(visualize[p][i])*column[p]
	endfor
	string name=cleanupname(getdatafolder(0,df),0)
	Execute /Q "NewGizmo /K=1/N="+name+"; AppendToGizmo /d scatter="+getwavesdatafolder(visualize,2)+",name=scatter0"
	Execute /Q "AppendToGizmo /d Axes=tripletAxes,name=axes0"
	Execute /Q "ModifyGizmo modifyObject=scatter0, property={shape,1}"
	AddBlendingToGizmo(gizmoName=name)
	if(waveexists(Clusters))
		// Remove empty clusters from consideration.  
		Make /FREE/n=100 TempHist
		Histogram /B=2 Clusters, TempHist
		Extract /FREE/INDX TempHist,TempIndex,TempHist>0
		variable numClusters=numpnts(TempIndex)
		if(!useSpikeSortColors)
			GizmoColors=(1/65535)*M_colors[FindValue2(TempIndex,Clusters[p])*numColorWavePoints/numClusters][q]
		else
			variable maxCluster=wavemax(Clusters) // Different from the number of clusters if there are empty clusters.  
			wave ClusterColorMap=ClusterColorWave(maxCluster+1)
			GizmoColors=(1/65535)*ClusterColorMap[Clusters[p]][q]
		endif
		GizmoColors[][3]=1 // Alpha setting.  
		Execute /Q "ModifyGizmo modifyObject=scatter0, property={colorWave,"+getwavesdatafolder(GizmoColors,2)+"},property={scatterColorType,1},property={size,2}"
		Execute /Q "ModifyGizmo operation=clearColor, data={0,0,0,0}"
		Execute /Q "ModifyGizmo modifyObject=axes0, property={-1,axisColor,1,1,1,1}"
		Execute /Q "ModifyGizmo hookEvents=8, hookFunction=ClusterKillHook"
	
		ClusterPanel(df)
	endif
	KillWaves /Z W_KMMembers,M_Colors
End

Function ClusterPanel(df[,checked])
	dfref df
	string checked // Optional list of clusters that are currently checked.  
	
	string name=cleanupname(getdatafolder(0,df),0)
	wave counts=ClusterCounts(df)
	variable numClusters=numpnts(counts)
	
	DoWindow /K $(name+"_Pnl")
	variable cluster,yy=60
	for(cluster=numClusters;cluster>=0;cluster-=1)
		if(counts[cluster]==0 && !wintype(name+"_Pnl"))
			continue
		endif
		if(!wintype(name+"_Pnl"))
			NewPanel /K=1 /N=$(name+"_Pnl") /W=(100,100,240,120+45*cluster)
		endif
		variable red,green,blue
		GetClusterColors(cluster,red,green,blue)
		string titleStr
		sprintf titleStr,"(%d) u%d",counts[cluster],cluster
		PopupMenu $("Color_"+num2str(cluster)) pos={3,yy+cluster*30}, size={105,25}, bodyWidth=50, popColor=(red,green,blue), value="*COLORPOP*"
		PopupMenu $("Color_"+num2str(cluster)) userData="DF:"+getdatafolder(1,df), title=titleStr, proc=ClusterPanelPopups
		if(paramisdefault(checked))
			variable checkd=1
		else
			checkd=whichlistitem(num2str(cluster),checked)>=0
		endif
		Checkbox $("Show_"+num2str(cluster)), pos={120,yy+cluster*30}, userData="DF:"+getdatafolder(1,df), size={25,25}, value=checkd, title="",proc=ClusterPanelCheckboxes
	endfor
	yy=2
	Checkbox Mahal, value=0,pos={2,yy},title="Mahal", userData="DF:"+getdatafolder(1,df), proc=ClusterPanelCheckboxes
	SetVariable MahalCenter, value=_NUM:0, disable=1, userData="DF:"+getdatafolder(1,df), limits={0,Inf,1}, proc=ClusterPanelSetVariables
	yy+=25
	Button ShowAll, title="All", pos={2,yy}, userData="DF:"+getdatafolder(1,df), proc=ClusterPanelButtons
	Button ShowNone, title="None", userData="DF:"+getdatafolder(1,df), proc=ClusterPanelButtons
	yy+=30
	dfref nlx=$PACKAGE_FOLDER
End

Function ClusterPanelButtons(info)
	struct wmbuttonaction &info
	
	if(info.eventCode!=2)
		return -1
	endif

	dfref nlx=$PACKAGE_FOLDER
	wave /z/sdfr=nlx GizmoColors,ClusterColors
	dfref df=$stringbykey("DF",info.userData)
	wave /sdfr=df Clusters
	struct wmcheckboxaction info2
	info2.ctrlName=info.ctrlName
	info2.userData=info.userData
	strswitch(info.ctrlName)
		case "ShowAll":
			info2.checked=1
			break
		case "ShowNone":
			info2.checked=0
			break
	endswitch
	if(stringmatch(info.ctrlName,"Show*"))
		string controls=ControlNameList(info.win,";","Show_*")
		variable i
		for(i=0;i<itemsinlist(controls);i+=1)
			string control=stringfromlist(i,controls)
			Checkbox $control value=info2.checked
			info2.eventCode=2
			info2.ctrlName=control
			ClusterPanelCheckboxes(info2)
		endfor
	endif
End

Function ClusterPanelCheckboxes(info)
	struct wmcheckboxaction &info
	
	if(info.eventCode!=2)
		return -1
	endif

	string type=stringfromlist(0,info.ctrlName,"_")
	variable num=str2num(stringfromlist(1,info.ctrlName,"_"))
	dfref df=$stringbykey("DF",info.userData)
	strswitch(type)
		case "Mahal":
			SetVariable MahalCenter, value=_NUM:0, disable=!info.checked
			if(info.checked)
				controlinfo MahalCenter
				Cluster3DVisualize(df,mahal=v_value)
				Execute /Q "ModifyGizmo modifyObject=axes0, setouterbox={-15,15,-15,15,-15,15}"
			else
				Cluster3DVisualize(df)
				Execute /Q "ModifyGizmo modifyObject=axes0, scalingMode=2"
			endif
			break
		case "Show":
			dfref nlx=$PACKAGE_FOLDER
			wave /sdfr=df Clusters
			wave /z/sdfr=nlx GizmoColors,ClusterColors,clustersMask
			if(waveexists(GizmoColors))
				GizmoColors[][3]=Clusters[p]==num ? info.checked : GizmoColors[p][3]
			endif
			if(waveexists(ClusterColors))	
				if(info.checked)
					clustersMask=clusters[p]==num ? clusters[p] : clustersMask[p]
				else
					clustersMask=clusters[p]==num ? 1000 : clustersMask[p]
				endif
			endif
			break
	endswitch
End

Function ClusterPanelSetVariables(info)
	struct wmsetvariableaction &info
	
	if(info.eventCode!=1 && info.eventCode!=2)
		return -1
	endif
	controlinfo /w=NlxViewer dataName
	dfref df=$("root:"+s_value)
	strswitch(info.ctrlName)
		case "MahalCenter":
			Cluster3DVisualize(df,mahal=info.dval)
			break
	endswitch
End

Function ClusterPanelPopups(info)
	struct wmpopupaction &info
	
	dfref pf=$PACKAGE_FOLDER
	switch(info.eventcode)
		case 2: // Mouse up. 
			string control=stringfromlist(0,info.ctrlName,"_")
			variable cluster=str2num(stringfromlist(1,info.ctrlName,"_"))
			strswitch(control)
				case "Color":
					variable red,green,blue
					sscanf info.popStr,"(%d,%d,%d)",red,green,blue
					make /free/n=3 SelectedColor={red,green,blue}
					dfref df=$stringbykey("DF",info.userData)
					wave /sdfr=df Clusters
					wave /z/sdfr=pf GizmoColors,ClusterColors
					if(waveexists(GizmoColors))
						GizmoColors=Clusters[p]==cluster ? (SelectedColor[q]/65535) : GizmoColors[p][q]
					endif
					if(waveexists(ClusterColors))
						ClusterColors[cluster][]=SelectedColor[q]
					endif
					break
			endswitch
			break
	endswitch
End

Function ClusterKillHook(infoStr)
	string infoStr
	
	string win=stringbykey("WINDOW",infoStr)
	string event=stringbykey("EVENT",infoStr)
	strswitch(event)
		case "kill":
			//dowindow /k $(win+"_pnl")
			break
	endswitch
End

// Colors for cluster number 'cluster' in the program SpikeSort3D by Neuralynx.  Colors provided by Robert van den Berg.  
Function /wave GetClusterColors(cluster,red,green,blue)
	variable cluster
	variable &red,&green,&blue
	
	string rgb=""
	cluster=cluster > 0 ? mod(cluster-1,15)+1 : cluster // Cycle through colors 1-15.  
	switch(cluster)
		case -1:
			rgb="(0,0,0)"
			break
		case 0:
			rgb="(128,128,128)"
			break
		case 1: 
			rgb="(255,0,0)"
			break
		case 2: 
			rgb="(255,222,153)"
			break
		case 3: 
			rgb="(161,255,0)"
			break
		case 4: 
			rgb="(153,255,158)"
			break
		case 5: 
			rgb="(0,255,187)"
			break
		case 6: 
			rgb="(153,212,255)"
			break
		case 7: 
			rgb="(25,0,255)"
			break
		case 8: 
			rgb="(232,153,255)"
			break
		case 9: 
			rgb="(255,0,135)"
			break
		case 10: 
			rgb="(255,168,153)"
			break
		case 11: 
			rgb="(255,212,0)"
			break
		case 12: 
			rgb="(202,255,153)"
			break
		case 13: 
			rgb="(0,255,51)"
			break
		case 14: 
			rgb="(153,255,243)"
			break
		case 15: 
			rgb="(0,110,255)"
			break
		default:
			break
	endswitch
	if(strlen(rgb))
		sscanf rgb,"(%d,%d,%d)",red,green,blue
		red*=256; green*=256; blue*=256
	else
		red=floor(abs(enoise(65535)))
		green=floor(abs(enoise(65535)))
		blue=floor(abs(enoise(65535)))
	endif
	make /free/n=3 w_rgb={red,green,blue}
	return w_rgb
End

// Colors for cluster number 'cluster' in the program SpikeSort3D by Neuralynx.  Colors provided by Robert van den Berg.  
Function /wave GetElectrodeColors(electrode,red,green,blue)
	string electrode
	variable &red,&green,&blue
	
	string electrodes="TTA;TTB;TTC;TTE;TTF;TTG;"
	variable num=whichlistitem(electrode,electrodes)
	if(num<0)
		red=0; green=0; blue=0
	else
		colortab2wave rainbow
		wave m_colors
		setscale x,0,itemsinlist(electrodes)-1,m_colors
		red=m_colors(num)(0)
		green=m_colors(num)(1)
		blue=m_colors(num)(2)
	endif
End

Function /wave ClusterColorWave(numClusters)
	variable numClusters
	
	Make /n=(numClusters,3) /FREE Colors
	variable i,red,green,blue
	for(i=0;i<numClusters;i+=1)
		GetClusterColors(i,red,green,blue)
		Colors[i][0]=red
		Colors[i][1]=green
		Colors[i][2]=blue
	endfor
	return Colors
End

Function /wave Cluster3DVisualize(df[,feature,mahal])
	dfref df
	string feature
	variable mahal // Cluster to center and normalize with a Mahalonobis transformation of the data.  
	
	feature=selectstring(!paramisdefault(feature),"lambdas",feature)
	wave /sdfr=df clusters,features=$feature
	
	dfref nlx=$PACKAGE_FOLDER
	if(paramisdefault(mahal))
		duplicate /o features nlx:visualize /wave=visualize	
	else
		duplicate /o MahalVectorsOneCluster(features,clusters,mahal) nlx:visualize /wave=visualize
	endif
	if(dimsize(visualize,1)>3)
		Redimension /n=(-1,3) visualize
	endif
	return visualize
End

// Delete spikes that fail to reach 'threshold' in the first n/2 samples on any channel.  
Function Rethreshold(df,threshold)
	dfref df
	variable threshold
	
	variable spike=0,electrode,numSpikes=dimsize(data,1),numElectrodes=max(1,dimsize(data,2)),numSamples=dimsize(data,0)
	variable maxx=0
	wave /sdfr=df data,times,clusters,features
	make /free/n=(numSpikes) aboveThreshold=0
	for(electrode=0;electrode<numElectrodes;electrode+=1)
		ImageTransform /P=(electrode) getPlane data
		Wave M_ImagePlane
		M_ImagePlane=p<(numSamples/2) && abs(M_ImagePlane)>threshold
		matrixop /o/free electrodeAboveThreshold=(sumcols(M_ImagePlane))^t
		aboveThreshold+=electrodeAboveThreshold
	endfor
	killwaves /z m_imageplane
	extract /o/free/indx aboveThreshold,goodSpikes,aboveThreshold>0
	extract /o/D Times,Times,aboveThreshold>0
	extract /o/I Clusters,Clusters,aboveThreshold>0
	extract /o/I Features,Features,aboveThreshold>0
	variable numGoodSpikes=numpnts(goodSpikes)
	Data=Data[p][goodSpikes[q]][r]
	Redimension /n=(-1,numGoodSpikes,-1) Data
End

// Returns a color by reference for a given spike cluster number.  
Function Cluster2Color(cluster,numClusters,red,green,blue[,keepColorTable])
	String cluster
	Variable numClusters,&red,&green,&blue,keepColorTable
	
	strswitch(cluster)
		case "All":
			red=0; green=0; blue=0
			break
		case "Assigned":
			red=10000; green=10000; blue=10000
			break
		default:
			ColorTab2Wave rainbow; Wave M_Colors
			Variable clusterChoice=str2num(cluster)
			Variable colorIndex=clusterChoice*dimsize(M_Colors,0)/numClusters
			red=M_Colors[colorIndex][0]; green=M_Colors[colorIndex][1]; blue=M_Colors[colorIndex][2]
			break
	endswitch
	if(!keepColorTable)
		KillWaves /Z M_Colors
	endif
End

// Used to build the popup menu for Neuralynx clusters.  
Function /S ClusterChoices()
	ControlInfo DataName
	dfref df=$("root:"+S_Value)
	Wave /sdfr=df Data,Clusters
	Variable maxx=wavemax(Clusters)
	Variable i
	String choices="All;Assigned;"
	for(i=0;i<=maxx;i+=1)
		choices+=num2str(i)+";"
	endfor
	return choices
End

// ----------- Neuralynx Chopper -------------------------------
// Chops data into subsets.  

Function Chop([df,epochsDF,match,except,killSource])
	dfref df
	dfref epochsDF
	string match,except
	variable killSource // To save memory, redimension to zero the data waves from the original folders after chopping.  
	
	if(paramisdefault(df))
		dfref df=root:
	endif
	if(paramisdefault(epochsDF))
		epochsDF = root:Events:epochs
	endif
	match=selectstring(paramisdefault(match),match,"*")
	except=selectstring(paramisdefault(except),except,"")
	setdatafolder df
	variable i
	printf "Chopping all data into epochs...\r"
	for(i=0;i<CountObjectsDFR(df,4);i+=1)
		string folder=getindexedobjnamedfr(df,4,i)
		dfref subDF=df:$folder
		wave /z w=subDF:data
		if(!waveexists(w) || !stringmatch(folder,match) || stringmatch(folder,except))
			continue
		endif
		NlxA#ChopData(subDF,epochsDF=epochsDF,killSource=killSource)
	endfor
End

Function ChopWindow()
	DoWindow /K NlxChopWin
	Display /K=1 /N=NlxChopWin as "Neuralynx Chopper"
	//Clusters vs Time_ 
	ControlBar /T 30	
	SetVariable NumSegments, value=_NUM:1, limits={1,11,1}, size={100,20}, title="Segments", proc=NlxA#ChopWinSetVariables
	Button Chop title="Chop", proc=NlxA#ChopWinButtons
	PopupMenu Type value="ntt;ncs",proc=NlxA#ChopWinPopupMenus
	PopupMenu Data value=#"Nlx#Recordings(\"\")",proc=NlxA#ChopWinPopupMenus
	PopupMenu Times pos={350,2}, value=#"Nlx#Recordings(\"nev\")",proc=NlxA#ChopWinPopupMenus
	ChopWinUpdate()
End

static Function ChopWinUpdate([df,type])
	dfref df
	string type
	
	if(!WinType("NlxChopWin"))
		ChopWindow()
	else
		DoWindow /F NlxChopWin
	endif
	RemoveTraces()
	if(ParamIsDefault(df) || ParamIsDefault(type))
		df=$Nlx#DFfromMenu()
		type=Nlx#DataType(df)
	endif
	PopupMenu Data	value=#("Nlx#Recordings(\"\")")
	if(!datafolderrefstatus(df))
		return -1
	endif
	wave /z/sdfr=df Data,Times
	if(!waveexists(Data))
		return -2
	endif
	
	strswitch(type)
		case "ntt":
			Wave /sdfr=df Clusters
			AppendToGraph Clusters vs Times
			ModifyGraph mode=2
			Label left "Cluster #"
			SetAxis left -0.5,wavemax(Clusters)+0.5
			ModifyGraph manTick(left)={0,1,0,0},manMinor(left)={0,0}
			break
		case "ncs":
			AppendToGraph Data vs Times
			ModifyGraph mode=0
			SetAxis /A left
			Label left "Amplitude (\F'Symbol'm\F'Default'V)"
			break
	endswitch
	ControlInfo NumSegments
	Variable numCursors=V_Value-1
	ChopPlaceCursors(numCursors)
	dfref Epochs=GetChopEpochs()
	ChopPlotEpochs(Epochs)
	Label bottom "Time (s)"
End

static Function ChopWinButtons(ctrlName)
	String ctrlName
	
	strswitch(ctrlName)
		case "Chop":
			dfref df=$Nlx#DFfromMenu()
			ChopData(df)
			Button Save_, title="Save", proc=NlxA#ChopWinButtons
			break
		case "Save_":
			dfref df=$Nlx#DFfromMenu()
			ControlInfo Type; String type=S_Value
			ControlInfo NumSegments; Variable numSegments=V_Value
			if(numSegments<2)
				ControlInfo Times
				Wave Times=$S_Value
				numSegments=numpnts(Times)
			endif
			ControlInfo /W=NeuralynxPanel fileName; String fileName=S_Value
			ControlInfo /W=NeuralynxPanel dirName
			NewPath /O/Q/C NeuralynxSavePath S_Value
			Variable i
			for(i=0;i<numSegments;i+=1)
				dfref Segment=df:$("E"+num2str(i))
				SaveBinaryFile(Segment,fileName=getdatafolder(0,df)+"_E"+num2str(i),pathName="NeuralynxSavePath")
			endfor
			break
	endswitch
End

static Function ChopWinSetVariables(info)
	Struct WMSetVariableAction &info
	
	if(info.eventCode!=1 && info.eventCode!=2)
		return -1
	endif
	strswitch(info.ctrlName)
		case "NumSegments":
			PopupMenu Times disable=(info.dval>1)
			ChopPlaceCursors(info.dval-1)
			break
	endswitch
End

static Function ChopWinPopupMenus(info)
	Struct WMPopupAction &info
	
	if(info.eventCode!=2)
		return -1
	endif
	strswitch(info.ctrlName)
		case "Data":
			ChopWinUpdate()
			break
		case "Type":
			ChopWinUpdate(type=info.popStr)
			break
		case "Times":
			dfref epochs=GetChopEpochs()
			ChopPlotEpochs(Epochs)
			break
	endswitch
End

static Function ChopPlotEpochs(epochs)
	dfref epochs
	
	wave /sdfr=epochs Times
	RemoveFromGraph /z Times
	AppendToGraph /vert /c=(0,0,65535) times /tn=Times
	modifygraph marker(Times)=10,mode(Times)=3,muloffset(Times)={0.0000001,0}
End

static Function ChopPlaceCursors(numCursors)
	variable numCursors
	if(!StringMatch(WinName(0,1),"NlxChopWin"))
		return -1
	endif
	Variable i
	for(i=0;i<10;i+=1)
		String cursorName=num2char(97+i)
		Variable cursorExists=strlen(CsrInfo($cursorName,""))
		if(i<numCursors)
			if(!cursorExists)
				Cursor /H=2 /S=1 /F $cursorName,$TopTrace(),0,0.5
			endif
		else
			if(cursorExists)
				Cursor /K $cursorName
			endif
		endif
	endfor
End

static Function /df GetChopEpochs()
	ControlInfo /W=NlxChopWin Times
	if(v_flag == 3)
		dfref ChopEpochs=$("root:"+s_value)
	else
		dfref ChopEpochs = root:Events:epochs
		if(!datafolderrefstatus(ChopEpochs))
			NlxA#ChopEvents()
			dfref ChopEpochs = root:Events:epochs
		endif
	endif
	return ChopEpochs
End

static Function ChopData(dataDF[,epochsDF,type,killSource,quiet])
	dfref dataDF,epochsDF
	string type
	variable killSource // To save memory, redimension to zero the data waves from the original folders after chopping.  
	variable quiet
	
	if(paramisdefault(type))
		type=Nlx#DataType(dataDF)
	endif
	if(!strlen(type))
		return -1
	endif
	wave /z/sdfr=dataDF Data,Times,Clusters,Features,Header,Metadata
	
	variable i
	if(ParamIsDefault(epochsDF) && stringmatch(WinName(0,1),"NlxChopWin*"))
		ControlInfo /w=NlxChopWin NumSegments
		if(V_Value>1) // Chop using cursor locations.  
			getaxis /q bottom; variable axisMin=v_min,axisMax=v_max
			Make /FREE/n=1 ChopTimes=0
			for(i=0;i<10;i+=1)
				String cursorName=num2char(97+i)
				Variable cursorExists=strlen(CsrInfo($cursorName,""))
				if(cursorExists)
					variable axisFract=str2num(stringbykey("POINT",CsrInfo($cursorName,"")))
					ChopTimes[i+1]={v_min+(v_max-v_min)*axisFract}
				endif
			endfor
			Sort ChopTimes,ChopTimes
		else
			dfref epochsDF=GetChopEpochs()
			wave epochTimes=epochsDF:times
		endif
	endif
	if(!waveexists(ChopTimes) || !paramisdefault(epochsDF))
		if(datafolderrefstatus(epochsDF)==0)
			dfref epochsDF=GetChopEpochs()
		endif
		wave /z epochTimes=epochsDF:times
		if(waveexists(epochTimes))
			Duplicate /FREE epochTimes ChopTimes
		else
			doalert 0,"Must use the graphical chopper, or provide an Epochs folder."
			return -1
		endif
	endif
	printf "Chopping data for %s...\r",getdatafolder(0,dataDF)
	variable numEpochs=numpnts(ChopTimes)
	ChopTimes[numEpochs]={Times[numpnts(Times)-1]+0.001}
	make /o/n=(numEpochs) dataDF:epochDuration /wave=epochDuration
	make /o/n=(numEpochs) dataDF:epochEventCount /wave=epochEventCount
	for(i=0;i<numEpochs;i+=1)
		cursorName=num2char(97+i)
		Variable start=BinarySearch(Times,ChopTimes[i]-0.001)
		Variable finish=BinarySearch(Times,ChopTimes[i+1]-0.001)
		if(start==finish || start==-2)
			variable count=0
		else
			start+=1
			if(finish==-2)
				finish=numpnts(Times)-1
			endif
			count=finish-start+1
		endif
		if(!quiet)
			printf "Epoch %d: Start (%d), Finish (%d), # Frames (%d)\r", i,start,finish,count
		endif
		epochDuration[i]=ChopTimes[i+1]-ChopTimes[i]
		epochEventCount[i]=count
		Variable rows=dimsize(Data,0)
		Variable layers=dimsize(Data,2)
		String newDFname="E"+num2str(i)
		newdatafolder /o dataDF:$newDFname
		dfref newDF=dataDF:$newDFname
		variable j
		for(j=0;j<countobjectsdfr(dataDF,1);j+=1)
			string name=getindexedobjnamedfr(dataDF,1,j)
			wave w=dataDF:$name
			strswitch(name)
				case "Times":
					make /o/d/n=(count) newDF:$name=w[p+start]
					break
				case "Clusters":
					make /o/w/u/n=(count) newDF:$name=w[p+start]
					break
				case "Features":
					make /o/I/n=(count,8) newDF:$name=w[p+start][q]
					break
				case "Data":
					strswitch(type)
						case "ntt":
							if(count)
								make /o/n=(rows,count,layers) newDF:$name /wave=w1 = w[p][q+start][r]
							else
								make /o/n=0 newDF:$name
							endif
							break
						case "ncs":
							make /o/n=(count) newDF:$name=w[p+start]
							variable delta=dimdelta(w,0)
							SetScale /p x,Times[start],delta,newDF:$name
							break
						case "nev":
							make /o/n=(count) newDF:$name=w[p+start]
							break
					endswitch
					break
				case "Header":
				case "Metadata":
					duplicate /o w,newDF:$name
					break
				case "Desc":
					wave /t wt=dataDF:$name
					make /o/t/n=(count) newDF:$name=wt[p+start]
					break
				case "EpochDuration":
				case "EpochEventCount":
					break
				default:
					make /o/n=(count) newDF:$name=w[p+start]
					break
			endswitch
		endfor
		string /g newDF:type=Type
	endfor
	if(killSource)
		redimension /n=0/w data
	endif
	return numEpochs
End

// ---------------------------------------- Data Merging Functions --------------------------------

// Merge several different recordings (that presumably occur during the same epoch) such as recordings from different tetrodes.  
static Function MergeData(rootDF,dataList,[epoch,name,mergeWaveforms,mergeFeatures])
	dfref rootDF
	wave /df dataList
	string name
	variable epoch // e.g. 10.  
	variable mergeWaveforms,mergeFeatures
	
	if(paramisdefault(name))
		name="Merged"
	endif
	newdatafolder /o rootDF:$name
	dfref df=rootDF:$name
	if(!paramisdefault(epoch))
		name="E"+num2str(epoch)
		newdatafolder /o df:$name
		dfref df_=df:$name
		dfref df=df_
	endif
	dfref dfi=dataList[0]
	string type=Nlx#DataType(dfi)
	string /g df:type=type
	
	variable i,j,k
	strswitch(type)
		case "ntt":
			Make /o/n=(32,1,4)/w df:Data /WAVE=MergedData=0 // Will be empty unless 'mergeWaveforms' is set to 1.  Has 1 column so that it retains 3 dimensions.  
			break
		default:
			DoAlert 0,"Only ntt data can be merged using this function."
			break
	endswitch
	for(i=0;i<itemsinlist(NTT_WAVES);i+=1)
		string wave_name=stringfromlist(i,NTT_WAVES)
		Make /o/n=0 df:$wave_name
		strswitch(wave_name)
			case "clusters":
			case "features":
				redimension /i/u df:$wave_name
				break
			case "times":
				redimension /d/u df:$wave_name
				break
		endswitch
	endfor
	variable currCluster=1
	string sourceElectrodes="",sourceClusters=""
	for(i=0;i<numpnts(dataList);i+=1)
		dfref dfi=datalist[i]
		if(!paramisdefault(epoch))
			dfref temp=dfi:$("E"+num2str(epoch))
			dfi=temp
		endif
		prog("Epoch",i,numpnts(dataList),msg=getdatafolder(1,dfi))
		wave /sdfr=dfi clusters	
		if(mergeWaveforms) // Make a new wave containing all the waveforms as well, instead of just merging the various Times and Clusters waves.  
			 // Not yet implemented.  
		endif
		string source=getdatafolder(0,dfi)
		if(stringmatch(source,"E*")) // If the source folder is an epoch.  
			source=getdatafolder(0,ParentFolder(dfi)) // Use the parent of that folder, which probably has the name of a tetrode.  
		endif
		for(j=0;j<itemsinlist(NTT_WAVES);j+=1)
			string ntt_wave=stringfromlist(j,NTT_WAVES)
			prog("Data",j,itemsinlist(NTT_WAVES),msg=ntt_wave)
			wave /sdfr=dfi w=$ntt_wave
			wave /sdfr=df wMerged=df:$ntt_wave
			extract /free/indx w,realClusters,clusters[p]>0 // Indices for assigned spikes.  This ensures the unassigned spikes will be excluded from the merge.  
			variable newPoints=numpnts(realClusters)
			strswitch(ntt_wave)
				case "clusters":
					duplicate /free w,w_
					wave clusterCountz=ClusterCounts(dfi)
					for(k=1;k<=wavemax(w);k+=1)
						if(ClusterCountz[k])
							w_=(w_==k) ? currCluster : w_[p] // Give each cluster a new number except the unassigned cluster, which will remain 0.  
							string sourceCluster
							sprintf sourceCluster,"%d=%s:%d,",currCluster,source,k
							sourceClusters+=sourceCluster
							currCluster+=1
						endif
					endfor
					variable oldPoints=numpnts(wMerged)
					redimension /n=(oldPoints+newPoints) wMerged
					wMerged[oldPoints,]=w_[realClusters[p-oldPoints]]
					break
				case "features":
					if(mergeFeatures)
						oldPoints=dimsize(wMerged,0)
						redimension /n=(oldPoints+newPoints,-1) wMerged
						wMerged[oldPoints,][]=w[realClusters[p-oldPoints]][q]
					endif
					break
				case "data":
					if(mergeWaveforms)
						strswitch(type)
							case "ntt":
								oldPoints=dimsize(wMerged,1)
								redimension /n=(32,oldPoints+newPoints,4)/w wMerged
								wMerged[][oldPoints,][]=w[p][realClusters[q-oldPoints]][r]
								break
						endswitch
					endif
					break
				default:
					oldPoints=numpnts(wMerged)
					redimension /n=(oldPoints+newPoints) wMerged
					wMerged[oldPoints,]=w[realClusters[p-oldPoints]]
					break
			endswitch
			waveclear w_
		endfor
		sprintf sourceElectrodes,"%s%s=%d,",sourceElectrodes,source,currCluster
	endfor
	if(dimsize(MergedData,1)>1)
		deletepoints /m=1 0,1,MergedData // Delete the point that was only there to maintain that dimension.  
	endif
	sourceElectrodes=removeending(sourceElectrodes,",")+";"
	sourceClusters=removeending(sourceClusters,",")+";"
	string /g df:merged="sourceElectrodes:"+sourceElectrodes+"sourceClusters:"+sourceClusters
End

static Function Merge([df,match,epoch,mergeWaveforms])
	dfref df // Root df.  
	string match // e.g. "TT*"
	variable epoch,mergeWaveforms
	
	if(paramisdefault(df))
		dfref df=root:
	endif
	match=selectstring(!paramisdefault(match),"*",match)
	string folders=Core#Dir2("folders",df=df,match=NTT_NAMES)
	make /free/df/n=0 dataList
	variable i
	for(i=0;i<itemsinlist(folders);i+=1)
		string folder=stringfromlist(i,folders)
		if(strlen(listmatch2(folder,match)))
			dfref subDF=df:$folder
			dataList[i]={subDF}
		endif
	endfor
	if(!paramisdefault(epoch))
		MergeData(df,dataList,epoch=epoch,mergeWaveforms=mergeWaveforms)
	else
		i=0
		do
			dfref subDFdf=dataList[i]
			dfref epochDF=subDF:$("E"+num2str(i))
			if(datafolderrefstatus(epochDF))
				MergeData(df,dataList,epoch=i,mergeWaveforms=mergeWaveforms)
			else
				break
			endif
			i+=1
		while(1)
	endif
End

static function EpochNumClusters(df)
	dfref df
	
	make /o/n=0 df:numClusters /wave=numClusters
	variable i
	for(i=0;i<CountObjectsDFR(df,4);i+=1)
		string epochName=getindexedobjnamedfr(df,4,i)
		if(grepstring(epochName,"E[0-9]+"))
			dfref dfi=df:$epochName
			//variable epochNum
			//sscanf epochName,"E%d",epochNum
			wave /sdfr=dfi clusters
			wave clusterIndices=ClustersWithSpikes(dfi)
			numClusters[numpnts(numClusters)]={numpnts(clusterIndices)}
			setdimlabel 0,numpnts(numClusters)-1,$epochName,numClusters
		endif
	endfor
end

// ---------------------------------------- Event Manager functions -------------------------------

Function /df ExtractEpochs([df])
	dfref df
	
	if(paramisdefault(df))
		df=root:Events
	endif
	return ExtractEvents("epochs",df=df)
End

// Subdivide the epochs further based on the locations of cursors on the top graph.  
Function /WAVE ExtractMoreEpochs([df])
	dfref df
	
	if(paramisdefault(df))
		df=root:Events
	endif
	wave /sdfr=df Epochs
	if(strlen(csrinfo(a)))
		Epochs[numpnts(Epochs)]={xcsr(a)}
	endif
	if(strlen(csrinfo(b)))
		Epochs[numpnts(Epochs)]={xcsr(b)}
	endif
	sort Epochs,Epochs
	return Epochs
End

// Extract events with a particular stimulation message.   
static Function /df ExtractEvents(eventType[,df,epoch,message,offset])
	string eventType
	dfref df
	variable epoch // - Leave unspecified for to operate on the Events folder
				  // - epoch>=0 to operate on that epoch.  
				  // - epoch=-1 to operate on each epoch.  
	string message // Value of the 'desc' wave indicating an event.  
	variable offset // Offset the index of the event occurence from the index of the message.  
	
	variable i,j
	if(paramisdefault(df))
		dfref df=root:Events
	endif
	strswitch(eventType) // Match the appropriate Cheetah event message to the desired even type.  
		case "stimulus":
			eventType="stims"
		case "stim":
			if(paramisdefault(message))
				message = STIMULUS_MESSAGE
			endif
			break
		case "epoch": // Extract events corresponding to the start of recording.  
		case "epochs":
			eventType="epochs"
			if(paramisdefault(message))
				message = START_MESSAGE
			endif
			break
		default:
			if(stringmatch(eventType,"TTL=*"))
				variable ttl_
				sscanf eventType,"TTL=%x",ttl_
				print ttl_
				wave /sdfr=df ttl
				findvalue /i=(ttl_) ttl
				if(v_value<0)
					DoAlert 0,"No TTL with that value in the Events data"
					return NULL
				else
					wave /sdfr=df /t desc
					if(paramisdefault(message))
						message = desc[v_value]
					endif
				endif
			else
				DoAlert 0,"Unknown event type: "+eventType
				return NULL
			endif
			break
	endswitch
	
	eventType=cleanupName(eventType,0)
	make /free/n=0/df dfs
	if(!paramisdefault(epoch))
		if(epoch>=0)
			dfref dfi=df:$("E"+num2str(epoch))
			if(datafolderrefstatus(dfi)==0)
				string msg
				sprintf msg, "Events have not been assigned to epoch %d.  Use ChopEvents().",epoch
				DoAlert 0,msg
				abort
			endif
			dfs[numpnts(dfs)]={dfi}
		elseif(epoch==-1)
			for(i=0;i<countobjectsdfr(df,4);i+=1)
				string folder=getindexedobjnamedfr(df,4,i)
				if(grepstring(folder,"E[0-9]"))
					dfref dfi=df:$folder
					dfs[numpnts(dfs)]={dfi}
				endif
			endfor
		else
			sprintf msg, "Invalid epoch number %d.",epoch
			doalert 0,msg
			abort
		endif
	else
		dfs[0]={df}
	endif
	
	for(j=0;j<numpnts(dfs);j+=1)
		df=dfs[j]
		svar /sdfr=df type
		wave /sdfr=df /t Desc
		newdatafolder /o df:$eventType
		dfref eventDF=df:$eventType
		
		string waves=EVENT_WAVES
		
		for(i=0;i<itemsinlist(waves);i+=1)
			string name=stringfromlist(i,waves)
			wave /z w=df:$name
			if(waveexists(w))
				extract /o w,eventDF:$name, stringmatch(Desc[p+offset],message)
				string /g eventDF:type=type
			endif
		endfor
		wave times=eventDF:times
	endfor
	return eventDF
End

static Function ExtractTTL(ttl_[,epoch])
	variable ttl_,epoch
	
	string eventType
	sprintf eventType,"TTL=%X",ttl_
	if(paramisdefault(epoch))
		ExtractEvents(eventType)
	else
		ExtractEvents(eventType,epoch=epoch)
	endif
end

// Create a subset of the events in eventsDF which also fall within the absolute intervals prescribed by 
// the trigger times and relative intervals given in triggerInstance.  
static Function EventsWithinInterval(eventsDF1,eventsDF2,triggerInstance)
	dfref eventsDF1 // Choose a subset of these events.  
	dfref eventsDF2 // Based on the times of these events... (note that eventsDF1 may equal eventsDF2).  
	string triggerInstance // ... and triggers from the latter events.  
	
	wave intervals=AbsTriggerIntervals(eventsDF1,triggerInstance)
	newdatafolder /o eventsDF2:$triggerInstance
	dfref df=eventsDF2:$triggerInstance
	wave /sdfr=eventsDF2 times
	extract /o times,df:times,InIntervals(times[p],intervals)
end

static function InIntervals(value,intervals)
	variable value
	wave intervals // 2 x N x M wave of intervals.  The two rows are {start,stop}.  
	
	variable i,j
	for(i=0;i<dimsize(intervals,1);i+=1)
		for(j=0;j<max(1,dimsize(intervals,2));j+=1)
			if(value>=intervals[0][i][j] && value<intervals[1][i][j])
				return 1
			endif
		endfor
	endfor
	return 0
end

// Chop the Events folder into epochs.  
static Function ChopEvents([events])
	dfref events
	if(paramisdefault(events))
		dfref events=root:Events
	endif
	svar /sdfr=events type
	dfref epochs=events:epochs
	if(!datafolderrefstatus(epochs))
		ExtractEvents("epoch",df=events)
		dfref epochs=events:epochs
	endif
	wave /z/sdfr=events Times
	wave /z epochTimes=epochs:Times
	string waves=EVENT_WAVES
	variable i,epoch
	for(epoch=0;epoch<numpnts(epochTimes);epoch+=1)
		newdatafolder /o events:$("E"+num2str(epoch))
		dfref epochDF=events:$("E"+num2str(epoch))
		for(i=0;i<itemsinlist(waves);i+=1)
			string name=stringfromlist(i,waves)
			wave /z w=events:$name
			if(waveexists(w))
				extract /o w,epochDF:$name, (Times>=epochTimes[epoch] && (Times<epochTimes[epoch+1] || (epoch+1)>=numpnts(epochTimes)))
				string /g epochDF:type=type
			endif
		endfor
	endfor
End

// ---------------------------------------- Utility Functions -------------------------------------------

 // Use the scaling of the 'Data' wave to make a 'Times' wave.  
static Function /wave TimesFromData(df)
	dfref df
	
	duplicate /free df:Data,Times
	redimension /d Times
	Times=dimoffset(df:Data,0)+p*dimdelta(df:Data,0)
	return Times
End

threadsafe static Function NumClusters(df)
	dfref df
	
	wave /z/sdfr=df clusters
	if(!waveexists(clusters))
		return 0
	endif
	make /free/n=100 counts=0
	setscale /p x,0,1,counts
	histogram /b=2 clusters,counts
	counts=counts>0
	return sum(counts)
End

threadsafe static Function /wave ClustersWithSpikes(df[,exclude,atLeast])
	dfref df
	wave exclude // Exclude cluster 0, typically the noise cluster.  
	variable atLeast // At least this many spikes.  
	
	wave /z/sdfr=df Clusters
	if(!waveexists(Clusters))
		return $""
	endif
	make /free/n=100 counts=0
	histogram /b=2 clusters,counts
	variable i
	if(!paramisdefault(exclude))
		for(i=0;i<numpnts(exclude);i+=1)
			counts[exclude[i]]=0	
		endfor
	endif
	atLeast=paramisdefault(atLeast) ? 1 : atLeast
	extract /free/indx counts,nonZero,counts>=atLeast
	return nonZero
End

static Function /wave ClusterCounts(df[,atLeast])
	dfref df
	variable atLeast
	
	wave /z/sdfr=df Clusters
	if(!waveexists(Clusters) || numpnts(Clusters)==0)
		return NULL
	endif
	make /free/n=100 counts=0
	histogram /b=2 clusters,counts
	variable i=0,j=0
	do
		if(counts[i]<atLeast)
			deletepoints i,1,counts
		else
			SetDimLabel 0,i,$num2str(j),counts
			i+=1
		endif
		j+=1
	while(i<dimsize(counts,0))
	return counts
End

//// Returns the contents of an Igor folder.  
//static Function /s Dir2(type[,df,folder,match,except])
//	dfref df
//	string folder,type,match,except
//	
//	if(paramisdefault(df))
//		if(paramisdefault(folder))
//			df=getdatafolderdfr()
//		else
//			df=$folder
//		endif
//	endif	
//	
//	match=selectstring(paramisdefault(match),match,"*")
//	except=selectstring(paramisdefault(except),except,"")
//	
//	strswitch(type)
//		case "":
//			string types="1;2;3;4"
//			break
//		case "waves":
//			types="1"
//			break
//		case "variables":
//			types="2"
//			break
//		case "strings":
//			types="3"
//			break	
//		case "folders":
//			types="4"
//			break
//		default:
//			types=""
//			break
//	endswitch
//	
//	variable i,j
//	string items=""
//	for(j=0;j<itemsinlist(types);j+=1)
//		variable type_=str2num(stringfromlist(j,types))	
//		for(i=0;i<CountObjectsDFR(df,type_);i+=1)
//			string item=getindexedobjnamedfr(df,type_,i)
//			if(strlen(listmatch2(item,match)) && !strlen(listmatch2(item,except)))
//				items+=item+";"
//			endif
//		endfor
//	endfor
//	
//	return items
//End
//
//// Perform a Malinowski F-test and return the number of significant eigenvalues.  
//static Function Malinowski(Eigenvalues,alpha[,saveFs])
//	Wave Eigenvalues // A wave of eigenvalues to test.  
//	variable alpha // The signficance level.  Not corrected for multiple comparisons.  
//	variable saveFs // Save the F-statistics for each eigenvalue.  Actually the ratio of the F-statistic and its critical value.  
//	
//	variable i,pp=numpnts(Eigenvalues),sig=NaN
//	make /free/n=(pp) Fs=NaN
//	for(i=1;i<=pp;i+=1)
//		make /o/free/n=(pp) denominator=Eigenvalues[p]/(pp-i)
//		deletepoints 0,i,denominator
//		variable F=Eigenvalues[i-1]/sum(denominator)
//		variable crit=StatsInvFCDF(1-alpha, 1, pp-i)
//		if(F<crit && numtype(sig))
//			sig=i-1
//			if(!saveFs)
//				break
//			endif
//		endif
//		if(saveFs)
//			Fs[i-1]=F/crit
//		endif
//	endfor
//	if(saveFs)
//		duplicate /o Fs $"MalinowskiFs"
//	endif
//	return sig
//End

// ---------------------------------------- Rick Functions ----------------------------------------------

Function BinnedSpikes(df,template)
	dfref df
	wave template
	
	duplicate /o template df:spiking /wave=spiking
	Events2Binary(df:times,spiking)
End

Function SplitEpoch([events,t])
	dfref events
	variable t // Time that defines where the epoch will be split.  
	
	if(paramisdefault(events))
		dfref events=root:Events
	endif
	t=paramisdefault(t) ? xcsr(a) : t
	dfref epochs=events:epochs
	wave epochTimes=epochs:times
	variable epoch=binarysearch(epochTimes,t)
	switch(epoch)
		case -1:
			doalert 0,"Split time is before the beginning of the first epoch."
			return -1
			break
		case -2:
			epoch=numpnts(epochTimes)
		default:
			insertpoints epoch+1,1,epochTimes
			epochTimes[epoch+1]=t
	endswitch
	SplitEpochRecurse(t,epoch,root:)
End

Function SplitEpochRecurse(t,epoch,df)
	variable t,epoch
	dfref df
	
	variable i=0
	string renameQueue=""
	do
		string subFolder=getindexedobjnamedfr(df,4,i)
		if(!strlen(subFolder))
			break
		endif
		i+=1	
		if(grepstring(subFolder,"^E[0-9]+$")) // Is an epoch folder.  
			variable folderEpoch
			sscanf subFolder,"E%d",folderEpoch
			if(folderEpoch>epoch)
				renameQueue=addlistitem(subFolder,renameQueue)
			elseif(folderEpoch==epoch)
				dfref epochDF=df:$subFolder
				duplicatedatafolder epochDF df:$(subFolder+"_XsplitX")
				SplitEpochDFRecurse(t,epoch,epochDF,-1)
				epochDF=df:$(subFolder+"_XsplitX")
				SplitEpochDFRecurse(t,epoch,epochDF,1)  
			endif
		else // Is some other kind of subfolder.  
			dfref subDF=df:$subFolder
			SplitEpochRecurse(t,epoch,subDF)
		endif
	while(1)
	renameQueue=sortlist(renameQueue,";",17)
	for(i=0;i<itemsinlist(renameQueue);i+=1)
		subFolder=stringfromlist(i,renameQueue)
		subDF=df:$subFolder
		sscanf subFolder,"E%d",folderEpoch
		renamedatafolder subDF $("E"+num2str(folderEpoch+1))
	endfor
	dfref splitDF=df:$("E"+num2str(epoch)+"_XsplitX")
	if(datafolderrefstatus(splitDF))
		renamedatafolder splitDF $("E"+num2str(epoch+1))
	endif
End

Function SplitEpochDFRecurse(t,epoch,df,mode)
	variable t,epoch,mode // mode: -1 to keep data before time t and 1 to keep data after time t.   
	dfref df
	
	wave /sdfr=df times
	variable index=binarysearch(times,t)
	variable points=numpnts(times)
	variable i=0
	do
		string wave_name=getindexedobjnamedfr(df,1,i)
		if(!strlen(wave_name))
			break
		endif
		i+=1
		wave /z w=df:$wave_name
		if(waveexists(w))
			if(stringmatch(wave_name,"data") && dimsize(w,0)==32) // Split along columns.  
				variable dim=1
			elseif(dimsize(w,0)==points) // Split along rows.  
				dim=0
			else // Not a wave to split.  
				continue
			endif
			if(mode==-1)
				deletepoints /m=(dim) index+1,points-index-1,w
			elseif(mode==1)
				variable offset=dimoffset(w,0)
				variable delta=dimdelta(w,0)
				deletepoints /m=(dim) 0,index+1,w
				if(dim==0 && (offset!=0 || delta!=1)) // If this wave has non-default scaling.  
					setscale /P x,offset+delta*(index+1),delta,w // Rescale wave so offset is correct.  
				endif
			endif
		endif
	while(1)
	
	i=0
	do
		string subFolder=getindexedobjnamedfr(df,4,i)
		if(!strlen(subFolder))
			break
		endif
		i+=1
		dfref subDF=df:$subFolder
		SplitEpochDFRecurse(t,epoch,subDF,mode)
	while(1)
End

Function /wave MannWhitney([df,periods,aprx,freshTrials])
	wave periods
	variable aprx,freshTrials
	dfref df
	
	if(paramisdefault(df))
		ControlInfo /W=NeuralynxPanel Data
		dfref df=$("root:"+S_Value)
	endif
	if(paramisdefault(periods) || dimsize(periods,0)<=1)
		string pethInstance=Core#DefaultInstance(module,"PETH")
		wave periods=DefaultPrePostPeriods(pethInstance)
	endif

	wave /z/sdfr=df Trials
	if(!waveexists(Trials) || freshTrials)
		printf "Trial matrix not found or new Trial matrix requested; constructing PETH trial matrix from panel settings.\r"
		MakePETHFromPanel(dataDF=df,keepTrials=1)
		wave /z/sdfr=df Trials
	endif
	variable numUnits=dimsize(Trials,1)
	//wave clustersWithSpikes_=ClustersWithSpikes(df) // Wave of clusters with spikes.
	variable numClusters=numUnits//numpnts(clustersWithSpikes_)
	wave /sdfr=df clusters
	variable numEventTypes=dimsize(Trials,2)
	variable numTrials=dimsize(Trials,3)
	variable i,j,k
	make /o/n=(numClusters,numEventTypes,2) df:MannWhitneyResults /wave=MannWhitneyResults=nan
	setdimlabel 2,0,$"P-Values",MannWhitneyResults
	setdimlabel 2,1,$"Z-Scores",MannWhitneyResults
	for(i=0;i<=numUnits;i+=1)
		prog("Unit",i,numUnits)
		
		for(j=0;j<numEventTypes;j+=1)
			make /free/n=(numTrials) period1rates,period2rates
			variable periodLayer=min(dimsize(periods,2),j)
			variable period1start=periods[0][0][periodLayer]
			variable period1finish=periods[0][1][periodLayer]
			variable period2start=periods[1][0][periodLayer]
			variable period2finish=periods[1][1][periodLayer]
			variable period1duration=period1finish-period1start
			variable period2duration=period2finish-period2start
			for(k=0;k<numTrials;k+=1)
				duplicate /free /r=(period1start,period1finish)(i,i)(j,j)(k,k) trials period1spikes	
				duplicate /free /r=(period2start,period2finish)(i,i)(j,j)(k,k) trials period2spikes	
				period1rates[k]=sum(period1spikes)/period1duration
				period2rates[k]=sum(period2spikes)/period2duration
				waveclear period1spikes,period2spikes
			endfor
			if(paramisdefault(aprx))
				make /free/n=2 points={numpnts(period1rates),numpnts(period2rates)}
				if(wavemax(points)>75 || wavemin(points)>50) // If there are more than 75 points in one of the waves or more than 50 in both of them.   
					aprx=1
				else
					aprx=0
				endif
			endif 
			statswilcoxonranktest /aprx=(aprx)/q/tail=4 period1rates,period2rates
			wave w_wilcoxontest
			MannWhitneyResults[i][j][0]=w_wilcoxontest[%P_TwoTail] // P-value.  
			variable U=w_wilcoxontest[%Up_statistic]//,w_wilcoxontest[%Up_statistic])
			variable n1=w_wilcoxontest[%m]
			variable n2=w_wilcoxontest[%n]
			variable mu=n1*n2/2
			variable sigma=sqrt(n1*n2*(n1+n2+1)/12)
			MannWhitneyResults[i][j][1]=(U-mu)/sigma // Z-score.  
		endfor
		MannWhitneyResults[][][0]=MannWhitneyResults[p][q][0]==1 ? statsnormalcdf(MannWhitneyResults[p][q][1],0,1)  : MannWhitneyResults[p][q][0]
		variable unitNum=i//clustersWithSpikes_[i]
		setdimlabel 0,i,$("Unit "+num2str(unitNum)),MannWhitneyResults
	endfor
	string noht
	sprintf noht,"PERIOD1:%f-%f;PERIOD2:%f-%f",periods[0][0],periods[1][0],periods[0][1],periods[1][1]
	note /nocr/k MannWhitneyResults,noht
	//edit MannWhitneyP
	return MannWhitneyResults
End

function /wave DefaultPrePostPeriods(pethInstance)
	string pethInstance
	variable tPre=Core#VarPackageSetting(module,"PETH",pethInstance,"tPre")
	variable tPost=Core#VarPackageSetting(module,"PETH",pethInstance,"tPost")
	make /free/n=(2,2) periods={{-tPre,0},{0,tPost}}
	return periods
end

function DoStats([df])
	dfref df
	
	string win="NeuralynxPanel"
	if(paramisdefault(df))
		ControlInfo /W=$win Data
		if(v_flag<=0)
			printf "Cannot figure out which data to do stats on.\r"
			return -1
		endif
		dfref dataDF=$("root:"+S_Value)
	endif
	wave /sdfr=dataDF PETH
	string pethInstance=stringbykey("PETH_INSTANCE",note(PETH))
	variable i,numEventTypes=dimsize(PETH,2)
	//wave /z/t triggers=WavTPackageSetting(module,"PETH",pethInstance,"triggers")
	make /free/t/n=(numEventTypes) eventTypes=GetDimLabel(PETH,2,p),eventLabels=num2str(p)
	make /free/n=(2,2,numEventTypes) periods // BaselineResponse x StartFinish x numEventTypes 
	for(i=0;i<numpnts(eventTypes);i+=1)
		string trigger=eventTypes[i]
		string trigType=Core#StrPackageSetting(module,"Trigger",trigger,"type")
		strswitch(trigType)
			case "TTL":
				eventLabels[i]=TriggerDescription(trigger)
				break
		endswitch
		wave /t intervals=Core#WavTPackageSetting(module,"Trigger",trigger,"Intervals")
		if(numpnts(intervals)>=2)
			string baselineInterval=intervals[0]
			string responseInterval=intervals[1]
			periods[0][0][i]=Core#VarPackageSetting(module,"Intervals",baselineInterval,"start")
			periods[0][1][i]=Core#VarPackageSetting(module,"Intervals",baselineInterval,"finish")
			periods[1][0][i]=Core#VarPackageSetting(module,"Intervals",responseInterval,"start")
			periods[1][1][i]=Core#VarPackageSetting(module,"Intervals",responseInterval,"finish")
		else // Use the full pre-trigger and the full post-trigger as the analysis periods.   
			wave periodsLayer=DefaultPrePostPeriods(pethInstance)
			periods[][][i]=periodsLayer[p][q]
		endif
	endfor
	wave mannWhitneyResults=MannWhitney(df=dataDF,periods=periods)
	for(i=0;i<dimsize(mannWhitneyResults,1);i+=1)
		SetDimLabel 1,i,$eventLabels[i],mannWhitneyResults 
	endfor
	DoWindow /K MannWhitneyTable 
	Edit /K=1/N=MannWhitneyTable mannWhitneyResults.ld as "Mann-Whitney p-values"
end