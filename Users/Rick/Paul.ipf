#pragma rtGlobals=1		// Use modern global access method.

strconstant pathName = "PaulPath"
strconstant animalPathName = "AnimalPath"
constant epoch_offset = 3 // Column number of epoch 0 in all_experiments_list. 
constant n_shuffles = 10

function All([i,j,k])
	variable i,j,k
	
	string animals = "ticl;bee;"
	string odors = ";hpn;hpn0.1;hpn0.01;hpn0.001;hx;hx0.1;nol;iso;lem;lio;bom;6me;"
	string stimuli = "ff;bb"
	
	for(i=i;i<itemsinlist(animals);i+=1)
		Prog("Animal",i,itemsinlist(animals))
		string animal = stringfromlist(i,animals)
		for(j=j;j<itemsinlist(odors);j+=1)
			Prog("Odor",j,itemsinlist(odors))
			string odor = stringfromlist(j,odors)
			for(k=0;k<itemsinlist(stimuli);k+=1)
				Prog("Stimulus",k,itemsinlist(animals))
				string stimulus = stringfromlist(k,stimuli)
				if(Init(animal,stimulus,odor))
					printf "Could not initialize.\r"
					return -1
				endif
				LoadAllEpochs()
				string files_missing = CheckFileList() 
				if(strlen(files_missing))
					printf "Missing these files %s",files_missing
					return -2
				endif
				//Go()
			endfor
			k=0
		endfor
		j=0
	endfor
end

function Go()
	string dfs = GetDFs()
	if(!strlen(dfs))
		print "No data folders found.\r"
		return -1
	endif
	CleanData()
	FormatData()
	MakeAllVTAs()
	svar /sdfr=root: stimulus,animal
	MakeAllPeriodograms()
	MakeAllSpectrograms()
	if(stringmatch(stimulus,"BB"))
		wave eag_bb = MergeBBs(subtract=0)
		if(!stringmatch(animal,"TiCl"))
			wave eag_bb = MergeBBs(subtract=1)
		endif
		wave ticl_bb = root:bb:ticl_bb_:x:bb
		EAG_TiCl_Coherence(EAG_bb,TiCl_bb,startT=0.01,endT=1)
		EAG_TiCl_Coherence(EAG_bb,TiCl_bb,startT=5,endT=10)
		EAG_TiCl_Coherogram(EAG_bb,TiCl_bb)
	endif
end

function Init(animal,stimulus,odor[,set_path])
	string animal // e.g. "bee"
	string stimulus // e.g. "FF" or "BB"
	string odor // e.g. "hpn" or "hpn0.1"
	variable set_path
	
	cd root:
	pathinfo $pathName
	if(!strlen(s_path) || set_path)
		newpath /o/q/m="Choose the data path" $pathName
	endif
	newpath /o/q/z $animalPathName s_path+animal
	if(v_flag)
		if(!set_path)
			Init(animal,stimulus,odor,set_path=1)
		else
			printf "Could not find path %s%s\r",s_path,animal
			return -1
		endif
	endif
	
	wave /t/sdfr=root: w=all_experiments_list
	make /o/t/n=0 active_experiments_list
	string /g root:$"animal" = animal
	string /g root:$"stimulus" = stimulus
	string /g root:$"odor" = odor
	
	string species_list = "bee:MS_Apis mellifera;TiCl:MS_photodetector + TiCl;"
	string stimulus_list = "FF:;BB:BB"
	variable i,j,k,n=0
	for(i=0;i<dimsize(w,0);i+=1)
		string species = stringbykey(animal,species_list)
		if(stringmatch(w[i][1],species)) // If this experiment corresponds to this species.  
			n+=1
			redimension /n=(n,3) active_experiments_list // File name, odor epochs, nearest blank epochs.  
			active_experiments_list[n-1][0] = w[i][0] // File name.  
			active_experiments_list[n-1][1] = "" // Epoch list.  
		else
			continue
		endif
		string stim = stringbykey(stimulus,stimulus_list)
		if(!strlen(odor) && stringmatch(stim,""))
			stim = "FF"
		endif
		for(j=0;j<dimsize(w,1);j+=1)
			if(stringmatch(w[i][j],stim+odor) || stringmatch(w[i][j],stim+" "+odor))
				active_experiments_list[n-1][1] += "E"+num2str(j-epoch_offset)//+";"
				for(k=0;k<=3;k+=1)
					if(stringmatch(w[i][j+k],stim+"Blank") || stringmatch(w[i][j+k],stim+" Blank")) // If there is a blank k epochs after it.  
						active_experiments_list[n-1][2] += "E"+num2str(j+k-epoch_offset)//+";"
						break
					endif
					if(stringmatch(w[i][j-k],stim+"Blank") || stringmatch(w[i][j-k],stim+" Blank")) // If there is a blank k epochs before it.  
						active_experiments_list[n-1][2] += "E"+num2str(j-k-epoch_offset)//+";"
						break
					endif
				endfor
				break // Ignore other matching epochs.  
			endif
		endfor
		variable odorFound = strlen(active_experiments_list[i][1])
		variable airFound = strlen(active_experiments_list[i][2])
		if(!odorFound || (!stringmatch(animal,"TiCl") && !airFound)) // If there were no epochs matching these conditions.  
			n-=1
			redimension /n=(n,3) active_experiments_list // Remove this experiment from the list.  
		endif
	endfor
end	

function /s Environment()
	svar /sdfr=root: animal,stimulus,odor
	
	return animal+"_"+stimulus+"_"+odor	
end

function DownsampleAllNCS(downSamp[,force])
	variable downSamp
	variable force // Make a downsampled version even when one already exists.  
	
	variable i
	do
		string fileName = IndexedFile($animalPathName,i,".ncs")
		fileName = removeending(fileName,".ncs")
		if(!strlen(fileName))
			break
		elseif(!stringmatch(fileName,"*ds"))
			string ds_name = fileName + "ds.ncs"
			GetFileFolderInfo /P=$animalPathName /Q /Z=1 ds_name
			if(v_flag || force) // No downsampled version.  
				dfref df = DownsampleNCS(fileName,downSamp)
				KillDataFolder /z df
			endif
		endif
		i+=1
	while(1)
end

function /df DownsampleNCS(fileName,downSamp)
	string fileName
	variable downSamp
	
	string folder = LoadBinaryFile("ncs",fileName,pathName=animalPathName,downSamp=downSamp)
	dfref df = $folder
	SaveBinaryFile(df,pathName=animalPathName,fileName=fileName + "ds",force=1)
	return df
end

function /s CheckFileList()
	variable i,j,k
	wave /t/sdfr=root: list = active_experiments_list
	string kinds = "_EAGds,ncs;_Events,nev"
	string files = ""
	for(i=0;i<dimsize(list,0);i+=1)
		for(j=0;j<itemsinlist(kinds);j+=1)
			string kind = stringfromlist(j,kinds)
			string suffix = stringfromlist(0,kind,",")
			string type = stringfromlist(1,kind,",")
			string fileName = list[i][0]+suffix+"."+type
			GetFileFolderInfo /P=$animalPathName /Q /Z fileName
			if(v_flag)
				files += fileName+";"
			endif
		endfor
	endfor
	return files
end

function /df LoadEpochs(experiment[sparse])
		string experiment
		variable sparse // Delete unneeded epochs.  
		
		wave /t/sdfr=root: all_list = all_experiments_list
		wave /t/sdfr=root: active_list = active_experiments_list
		duplicate /free/r=[][0,0] all_list,all_experiment_names
		duplicate /free/r=[][0,0] active_list,active_experiment_names
		findvalue /text=(experiment)/txop=4 all_experiment_names
		variable all_index = v_value
		findvalue /text=(experiment)/txop=4 active_experiment_names
		variable active_index = v_value
								
		string kinds = "_EAGds,ncs;_Events,nev"
		variable j
		for(j=0;j<itemsinlist(kinds);j+=1)
			string kind = stringfromlist(j,kinds)
			string suffix = stringfromlist(0,kind,",")
			string type = stringfromlist(1,kind,",")
			string fileName = experiment+suffix
			printf "Loading %s\r",fileName
			string folder = LoadBinaryFile(type,fileName,baseName=removeending(fileName,"ds"),pathName=animalPathName,downSamp=1,quiet=1)
		endfor
		dfref df = $experiment
		printf "Chopping %s\r",experiment
		Chop(df,quiet=1)
		
		if(sparse)	
			for(j=0;j<itemsinlist(kinds);j+=1)
				kind = stringfromlist(j,kinds)
				suffix = stringfromlist(0,kind,",")
				printf "Sparsening %s\r",experiment+suffix
				dfref df_ = df:$removeending(suffix[1,strlen(suffix)-1],"ds")
				killwaves /z df_:data,df_:times,df_:TTL // Delete the whole experiment data since we have already extracted the data by epoch.  
				variable k=0
					do
						string epoch = getindexedobjnamedfr(df_,4,k)
						if(!strlen(epoch))
							break
						elseif(stringmatch(epoch,"epochs"))
							k+=1
						else
							dfref dfi = df_:$epoch
							if(stringmatch(type,"nev"))
								wave /sdfr=dfi times
								if(numpnts(times)<100)
									string df_name = getdatafolder(1,dfi)
									printf "%s probably has no usable data.\r", df_name
									variable epochNum = str2num(epoch[1,strlen(epoch)-1])//+epoch_offset
									if(!stringmatch("x"+all_list[all_index][epochNum+epoch_offset],"x!!*"))
										string msg
										print all_index,epochNum,epoch_offset,"x"+all_list[all_index][epochNum+epoch_offset],"x!!*"
										sprintf msg,"WARNING: Epoch %d in experiment %s found to be unusable but not marked as such.\r",epochNum,experiment
										print msg
										doalert 0,msg
									endif
								endif
							endif 
							findvalue /text=(experiment)/txop=4 experiment_names
							if(stringmatch(epoch,active_list[active_index][1]) || stringmatch(epoch,active_list[active_index][2])) // Match the odor epoch or the corresponding blank epoch.  
								k+=1
							else
								killdatafolder /z dfi // Otherwise delete since we don't need it right now.  
							endif
						endif
					while(1)
			endfor
		endif
		
		return df
end

function LoadAllEpochs([no_sparse])
	variable no_sparse // Don't delete unneeded epochs.  
	
	cd root:
	variable i,j,k
	wave /t/sdfr=root: list = active_experiments_list
	//string kinds = "_EAGds,ncs;_Events,nev"
	for(i=0;i<dimsize(list,0);i+=1)
		Prog("Load",i,dimsize(list,0))
		string experiment = list[i][0]
		dfref df = LoadEpochs(experiment,sparse=!no_sparse)
	endfor
	Prog("Load",0,0)
end

// Some data have errors that need to be removed.  
function CleanData()
	variable i,j,k
	wave /t/sdfr=root: list = active_experiments_list
	for(i=0;i<dimsize(list,0);i+=1)
		Prog("Clean",i,dimsize(list,0))
		dfref df = root:$list[i][0]
		string odorEpoch = list[i][1]
		string airEpoch = list[i][2]
		dfref eventsDF_ = df:Events
		
		string epochs = odorEpoch+";"+airEpoch
		for(j=0;j<itemsinlist(epochs);j+=1)
			string epoch = stringfromlist(j,epochs)
			dfref eventsDF = eventsDF_:$epoch
			wave /t/sdfr=eventsDF desc
			wave /t/sdfr=eventsDF times,TTL
			if(stringmatch(desc[12],"6ms"))
				deletepoints 0,15,desc,times,TTL
			endif
			if(stringmatch(desc[numpnts(desc)-1],"50ms"))
				redimension /n=(numpnts(desc)-1) desc,times,TTL
			endif
			if(stringmatch(desc[0],"cont"))
				deletepoints 0,2,desc,times,TTL
			endif
		endfor
	endfor
	Prog("Clean",0,0)
end

function MakeAllVTAs()
	variable i,j,k
	wave /t/sdfr=root: list = active_experiments_list
	svar /sdfr=root: stimulus, animal
	strswitch(stimulus)
		case "ff":
			string conditions = "100ms;30ms;15ms;6ms"
			break
		case "bb":
			conditions = ";"
			break
		default:
			conditions = ""
	endswitch
	string nths = "-1;0;1"
	for(i=0;i<dimsize(list,0);i+=1)
		Prog("VTA",i,dimsize(list,0))
		dfref df = root:$list[i][0]
		string odorEpoch = list[i][1]
		variable odorEpoch_ = str2num(odorEpoch[1,strlen(odorEpoch)-1])
		string airEpoch = list[i][2]
		variable airEpoch_ = str2num(airEpoch[1,strlen(airEpoch)-1])
		printf "Making VTA for %s\r",list[i][0]
		for(j=0;j<itemsinlist(conditions);j+=1)
			string condition = stringfromlist(j,conditions)
			for(k=0;k<itemsinlist(nths);k+=1)
				variable nth = str2num(stringfromlist(k,nths))
				if(!stringmatch(animal,"TiCl"))
					wave vta = MakeVTA(df,odorEpoch_,subtractEpoch=airEpoch_,condition=condition,nth=nth,invert=0)
				endif
				wave vta = MakeVTA(df,odorEpoch_,condition=condition,nth=nth,invert=0)
			endfor
		endfor
	endfor
	Prog("VTA",0,0)
	string dfs = GetDFs()
	for(j=0;j<itemsinlist(conditions);j+=1)
			condition = stringfromlist(j,conditions)
			for(k=0;k<itemsinlist(nths);k+=1)
				nth = str2num(stringfromlist(k,nths))
				if(!stringmatch(animal,"TiCl"))
					wave vta = MergeVTAs(dfs,conditions=conditions,nth=nth,subtracted=1,pool_errors=1)
					VTAStats(vta)
				endif
				wave vta = MergeVTAs(dfs,conditions=conditions,nth=nth,subtracted=0,pool_errors=1)
				VTAStats(vta)
			endfor
	endfor
end

// Formats data into a matrix. Requires odor_name and odor_code, which defines how e.g. "o1" maps onto an odor name.    
function /wave FormatFF(df,epoch)
	dfref df
	variable epoch
	
	//wave /t odor_name,odor_code
	dfref eventsDF = df:Events
	dfref eagDF = df:EAG
	dfref eagDF2 = eagDF:$("E"+num2str(epoch))
	eagDF = eagDF2
	dfref eventsDF2 = eventsDF:$("E"+num2str(epoch))
	eventsDF = eventsDF2
	wave /t/sdfr=eventsDF desc
	wave /sdfr=eventsDF event_times = times, ttl
	
	extract /free event_times,starts,stringmatch(desc[p],"*ms*") || stringmatch(desc[p],"*cont*")
	
	wave /sdfr=eagDF data_times = times, data
	variable x_scale = dimdelta(data,0)
	variable n_pnts = ceil(1/x_scale)
	if(stringmatch(desc[1],"cont")) // For TiCl there is a continuous trial at the beginning and another at the end.  
		variable n_freqs = 11
	else
		n_freqs = 10
	endif
	if(numpnts(starts)!=n_freqs)
		string msg
		sprintf msg,"Number of starts (%d) not equal to number of frequencies (%d) for %s, epoch %d",numpnts(starts),n_freqs,getdatafolder(1,df),epoch
		DoAlert 0,msg
	endif
	make /free/n=(n_pnts,n_freqs) indices,data_,times_
	setscale /p x,0,x_scale,data_,times_
	variable i
	for(i=0;i<numpnts(starts);i+=1)
		variable index = binarysearch(data_times,starts[i])
		indices[][mod(i,10)] = index+p
	endfor
	data_ = data[indices[p][q]]
	times_ = data_times[indices[p][q]]
	
	duplicate /o data_ eagDF:data // Overwrite 1D data wave with 2D data wave (time x condition).  
	duplicate /o times_ eagDF:times // Overwrite 1D data wave with 2D data wave (time x condition).  
	return matrix
end

function FormatData()
	svar /sdfr=root: stimulus,animal
	variable i,n = GetNumExperiments()
	for(i=0;i<n;i+=1)
		Prog("Format",i,dimsize(list,0))
		dfref df = GetDF(i)
		variable odorEpoch = GetOdorEpoch(i)
		variable airEpoch = GetAirEpoch(i)
		printf "Formatting data for %s\r",getdatafolder(1,df)
		strswitch(stimulus)
			case "FF":
				FormatFF(df,odorEpoch)
				if(!stringmatch(animal,"TiCl"))
					FormatFF(df,airEpoch)
				endif
				break
			case "BB":
				FormatBB(df,odorEpoch)
				if(!stringmatch(animal,"TiCl"))
					FormatBB(df,airEpoch)
				endif
				break
		endswitch
	endfor
	Prog("Format",0,0)
end

// FormatData() must be run first.  
function /wave MakePeriodograms(df,epoch[,subtractEpoch])
	dfref df
	variable epoch
	variable subtractEpoch
	
	dfref eagDF_ = df:EAG
	dfref eagDF = eagDF_:$("E"+num2str(epoch))
	
	wave /sdfr=eagDF data
	variable n_pnts = dimsize(data,0)
	variable n_freqs = dimsize(data,1)
	variable seg_length = round(n_pnts/5)
	seg_length -= mod(seg_length,2)==0 ? 0 : 1
	variable seg_overlap = round(seg_length*0.99)
	variable start = n_pnts/10
	variable i,j
	string suffix = ""
	if(!paramisdefault(subtractEpoch))
		suffix = "_sub"
	endif
	make /o/n=(1,n_freqs) eagDF:$("periodograms"+suffix) /wave=periodograms
	
	for(i=0;i<n_freqs;i+=1)
		prog("Freq",i,n_freqs)
		duplicate /free/r=[][i,i] data trial
		copyscales /p data,trial
		DSPPeriodogram /NODC=1 /Q /SEGN={(seg_length),(seg_overlap)} /R=[(start),(n_pnts)] /WIN=Hanning trial 
		wave w_periodogram
		redimension /n=(numpnts(w_periodogram),-1) periodograms
		copyscales /p w_periodogram,periodograms
		periodograms[][i] = log(w_periodogram[p])
	endfor
	prog("Freq",0,0)
	killwaves /z w_periodogram
	redimension /n=(200/dimdelta(periodograms,0),-1,-1) periodograms
	
	if(!paramisdefault(subtractEpoch))
		wave air_periodograms = MakePeriodograms(df,subtractEpoch)
		periodograms -= air_periodograms // Periodograms are already log-transformed so subtraction is correct here.  	
	endif
	
	return periodograms
end

// FormatData() must be run first.  
function /wave MakeSpectrogram(df,epoch[,subtractEpoch])
	dfref df
	variable epoch
	variable subtractEpoch
	
	dfref eagDF_ = df:EAG
	dfref eagDF = eagDF_:$("E"+num2str(epoch))
	
	wave /sdfr=eagDF data
	variable n_pnts = dimsize(data,0)
	variable n_freqs = dimsize(data,1)
	variable seg_length = round(n_pnts/5)
	seg_length -= mod(seg_length,2)==0 ? 0 : 1
	variable seg_overlap = round(seg_length*0.99)
	variable start = n_pnts/10
	variable i,j
	string suffix = ""
	if(!paramisdefault(subtractEpoch))
		suffix = "_sub"
	endif
	
	duplicate /free data data1D
	redimension /n=(numpnts(data)) data1D
	setscale /p x,0,dimdelta(data,0),data1D
	duplicate /o timefrequency(data1D,0.2,0.95,maxfreq=200,logg=1) eagDF:$("spectrogram"+suffix) /wave=spectrogram
	
	if(!paramisdefault(subtractEpoch))
		wave air_spectrogram = MakeSpectrogram(df,subtractEpoch)
		spectrogram -= air_spectrogram // Periodograms are already log-transformed so subtraction is correct here.  	
	endif
	
	return spectrogram
end

function /wave MakeBBPeriodogram(df,epoch[,subtractEpoch])
	dfref df
	variable epoch
	variable subtractEpoch
	
	dfref eagDF_ = df:EAG
	dfref eagDF = eagDF_:$("E"+num2str(epoch))
	wave /sdfr=eagDF data
	variable n_pnts = dimsize(data,0)
	variable seg_length = round(n_pnts/5)
	seg_length -= mod(seg_length,2)==0 ? 0 : 1
	variable seg_overlap = round(seg_length*0.99)
	variable start = n_pnts/10
	variable i,j
	string suffix = ""
	if(!paramisdefault(subtractEpoch))
		suffix = "_sub"
	endif
	
	DSPPeriodogram /NODC=1 /Q /SEGN={(seg_length),(seg_overlap)} /R=[(start),(n_pnts)] /WIN=Hanning trial 
	wave w_periodogram
	redimension /n=(200/dimdelta(w_periodogram,0),1) w_periodogram
	w_periodogram = log(w_periodogram[p])
	duplicate /o w_periodogram eagDF:$("periodogram"+suffix) /wave=periodogram
	killwaves /z w_periodogram
	
	if(!paramisdefault(subtractEpoch))
		wave air_periodogram = MakeBBPeriodogram(df,subtractEpoch)
		periodogram -= air_periodogram // Periodograms are already log-transformed so subtraction is correct here.  	
	endif
	
	return w_periodogram
end

function MakeAllPeriodograms()
	wave /t/sdfr=root: list = active_experiments_list
	svar /sdfr=root: stimulus, animal
	strswitch(stimulus)
		case "ff":
			string conditions = "100ms;30ms;15ms;6ms"
			break
		case "bb":
			conditions = ";"
			break
		default:
			conditions = ""
	endswitch
	variable i
	for(i=0;i<dimsize(list,0);i+=1)
		Prog("Periodograms",i,dimsize(list,0))
		dfref df = root:$list[i][0]
		string odorEpoch = list[i][1]
		variable odorEpoch_ = str2num(odorEpoch[1,strlen(odorEpoch)-1])
		string airEpoch = list[i][2]
		variable airEpoch_ = str2num(airEpoch[1,strlen(airEpoch)-1])
		printf "Making periodogram for %s\r",list[i][0]
		if(!stringmatch(animal,"TiCl"))
			MakePeriodograms(df,odorEpoch_,subtractEpoch=airEpoch_)
		endif
		MakePeriodograms(df,odorEpoch_)
	endfor
	Prog("Periodograms",0,0)
	string dfs = GetDFs()
	if(!stringmatch(animal,"TiCl"))
		wave periodogram = MergePeriodograms(dfs,subtracted=1)
		PeriodogramStats(periodogram)
	endif
	wave periodogram = MergePeriodograms(dfs,subtracted=0)
	PeriodogramStats(periodogram)
end

function MakeAllSpectrograms()
	wave /t/sdfr=root: list = active_experiments_list
	svar /sdfr=root: stimulus, animal
	strswitch(stimulus)
		case "ff":
			string conditions = "100ms;30ms;15ms;6ms"
			break
		case "bb":
			conditions = ";"
			break
		default:
			conditions = ""
	endswitch
	variable i
	for(i=0;i<dimsize(list,0);i+=1)
		Prog("Spectrograms",i,dimsize(list,0))
		dfref df = root:$list[i][0]
		string odorEpoch = list[i][1]
		variable odorEpoch_ = str2num(odorEpoch[1,strlen(odorEpoch)-1])
		string airEpoch = list[i][2]
		variable airEpoch_ = str2num(airEpoch[1,strlen(airEpoch)-1])
		printf "Making spectrogram for %s\r",list[i][0]
		if(!stringmatch(animal,"TiCl"))
			MakeSpectrogram(df,odorEpoch_,subtractEpoch=airEpoch_)
		endif
		MakeSpectrogram(df,odorEpoch_)
	endfor
	Prog("Spectrograms",0,0)
	string dfs = GetDFs()
	if(!stringmatch(animal,"TiCl"))
		wave spectrogram = MergeSpectrograms(dfs,subtracted=1)
	endif
	wave spectrogram = MergeSpectrograms(dfs,subtracted=0)
end

function PeriodogramStats(periodogram)
	wave periodogram
	
	dfref df = getwavesdatafolderdfr(periodogram)
	
	string /g df:$(nameofwave(periodogram)+"_stats")
	svar /sdfr=df stats = $(nameofwave(periodogram)+"_stats")
	wave periodogram_sem = df:$(nameofwave(periodogram)+"_sem")
	duplicate /o periodogram df:periodogram_z /wave=periodogram_z
	periodogram_z = periodogram/periodogram_sem
end

function RandomStim(duration)
	variable duration
	
	variable kHz = 1
	make /o/n=(1,2) stim2
	make /o/n=(1000*kHz*duration) stim
	setscale x,0,duration,stim
	variable state = 0
	variable t = 0
	variable count = 0
	do
		if(state == 0)
			variable off_duration = round(2+expnoise(8))
			stim[t*kHz,(t+off_duration)*kHz-1] = 0
			t += off_duration
			state = 1
		else
			variable on_duration = round(3+expnoise(7))
			stim[t*kHz,(t+on_duration)*kHz-1] = 1
			stim2[count][0] = {t}
			t += on_duration
			stim2[count][1] = on_duration
			count += 1
			state = 0
		endif
	while(t<numpnts(stim))
end

function /wave MSequence(bits)
	variable bits
	
	variable n_words = 2^bits
	make /free/n=(n_words) words=p,randos=gnoise(1)
	sort randos,words
	make /o/n=(n_words,bits) m_sequence = (words[p] & 2^q)>0
	redimension /e=1/n=(n_words*bits) m_sequence
	return m_sequence
end

function MSequence2StartsDurations(m_sequence)
	wave m_sequence
	
	if(m_sequence[0])
		insertpoints 0,1,m_sequence
		m_sequence[0]=0
	endif
	findlevels /edge=1/q m_sequence,0.5
	duplicate /free w_findlevels ups
	if(m_sequence[numpnts(m_sequence)-1]==1)
		m_sequence[numpnts(m_sequence)]={0}
	endif
	findlevels /edge=2/q m_sequence,0.5
	duplicate /free w_findlevels downs
	killwaves w_findlevels
	make /o/n=(numpnts(ups),2) starts_durations
	starts_durations[][0] = ups[p]+0.5
	starts_durations[][1] = downs[p]-ups[p]
end

function DisplayMSequence(starts_durations)
	wave starts_durations
	
	make /o/n=(starts_durations[Inf][0]) broadband_stim = 0
	setscale /p x,0,1,broadband_stim
	variable i
	for(i=0;i<dimsize(starts_durations,0);i+=1)
		variable start = starts_durations[i][0]
		variable finish = starts_durations[i][0] + starts_durations[i][1] - 1
		broadband_stim[start,finish] = 1
	endfor
end

// Use if data and events have been chopped into epochs.  
function DisplayData(df)
	dfref df
	
	dfref eagDF = df:EAG
	dfref eventsDF = df:events
	variable epoch=0
	do
		dfref eagEpochDF = eagDF:$("E"+num2str(epoch))
		dfref eventsEpochDF = eventsDF:$("E"+num2str(epoch))
		if(datafolderrefstatus(eagEpochDF))
			wave /sdfr=eagEpochDF data,times
			wave event_times = eventsEpochDF:times
			variable start_index = binarysearch(times,event_times[0]) // Time of first epoch event (usually the beginning of the stimulus).    
			variable x_scale = dimdelta(data,0)
			display /k=1 data[start_index,start_index+10/x_scale] as "Signal for Epoch "+num2str(epoch) // Display 10 seconds of data.  
			dspperiodogram /db/nodc=1/segn={1000,900}/r=[(start_index+0.1/x_scale),(start_index+10/x_scale)]/win=Hanning data
			duplicate /o w_periodogram eagEpochDF:periodogram /wave=periodogram
			variable f_scale = dimdelta(periodogram,0)
			redimension /n=(200/f_scale) periodogram
			display /k=1 periodogram as "Power Spectrum for Epoch "+num2str(epoch) // Display 10 seconds of data.  
		else
			break
		endif
		epoch+=1
	while(epoch<100)
end

function Chop(df[,quiet])
	dfref df
	variable quiet
	
	dfref eagDF = df:EAG
	dfref eventsDF = df:Events
	NlxA#ExtractEvents("epochs",df=eventsDF)
	dfref epochsDF = eventsDF:epochs
	wave /sdfr=epochsDF times
	if(numpnts(times)<=1) // Epoch extraction failed, recording was probably continuous.  
		NlxA#ExtractEvents("epochs",message="100ms",offset=0,df=eventsDF)
	endif
	NlxA#ChopData(df:EAG,epochsDF=epochsDF,quiet=quiet)
	NlxA#ChopEvents(events=eventsDF) // Uses the epochs folder automatically.  
end

function /wave MakeVTA(df,epoch[,subtractEpoch,t_min,t_max,e_min,e_max,condition,nth,resampled,invert,no_save]) // Valve-triggered average. 
	dfref df
	variable epoch,subtractEpoch,resampled,invert,nth,t_min,t_max,e_min,e_max,no_save
	string condition
	
	dfref eagDF_ = df:EAG
	dfref eventsDF_ = df:Events
	dfref eagDF = eagDF_:$("E"+num2str(epoch))
	dfref eventsDF = eventsDF_:$("E"+num2str(epoch))
	
	// Set defaults.  
	if(!paramisdefault(e_min))
		dfref e_minDF = eagDF:$("E"+num2str(e_min))
		wave /sdfr=e_minDF times
		t_min = times[0]-1
	else
		t_min = paramisdefault(e_min) ? -Inf : e_min
	endif
	if(!paramisdefault(e_max))
		dfref e_maxDF = eagDF:$("E"+num2str(e_max))
		wave /sdfr=e_maxDF times
		t_max = times[numpnts(times)-1]+1
	else
		t_max = paramisdefault(t_max) ? Inf : t_max
	endif
	nth = paramisdefault(nth) ? -1 : nth
	
	// Find valve-opening times. 
	wave /t/sdfr=eventsDF desc
	wave /sdfr=eventsDF times
	wave event_times = times
	make /free/n=0 valve_open_times
	if(!paramisdefault(condition))
		variable i = 0, trial = 0
		do
			variable rank = 0
			i = FindValue2T(desc,condition,start=i)
			do
				if(i<numpnts(desc))			
					if(stringmatch(desc[i],"o*") || stringmatch(desc[i],"*ms*") || stringmatch(desc[i],"*cont*"))
						redimension /n=(max(dimsize(valve_open_times,0),rank+1),trial+1) valve_open_times
						valve_open_times[rank][trial] = event_times[i]
						rank += 1
					endif
					i += 1
				else
					break
				endif
			while(!stringmatch(desc[i+1],"*ms*") && !stringmatch(desc[i+1],"*cont*"))
			trial += 1
		while(i<numpnts(desc))
	else
		rank = 0
		do
			if(stringmatch(desc[i],"o*"))
				redimension /n=(max(dimsize(valve_open_times,0),rank+1),1) valve_open_times
				valve_open_times[rank][0] = event_times[i]
				rank += 1
			endif
			i+=1
		while(i<numpnts(desc))
	endif
	variable n_opens = dimsize(valve_open_times,0)
	variable n_trials = max(1,dimsize(valve_open_times,1))
	if(n_trials !=1 && n_trials != 10)
		string msg
		sprintf msg,"Found %d trials in epoch %d of %s.\r",n_trials,epoch,getdatafolder(1,df)
		doalert 0,msg
	endif
	printf "%d candidates... ", n_opens*n_trials
	
	// Filtering.  
	wave /sdfr=eagDF data_times = times, data
	variable x_scale = dimdelta(data,0)
	duplicate /free data,copy
	variable median_width = round(0.001/x_scale)
	median_width += mod(median_width,2) == 0 ? 1 : 0
	smooth /m=0/dim=0 median_width,copy
	filteriir/dim=0 /lo=(500*x_scale) copy
	
	// Make the VT matrix.  
	variable n_pnts = 2000
	make /free/n=(n_pnts,1) matrix
	i = 0
	for(trial=0;trial<n_trials;trial+=1)
		for(rank=0;rank<n_opens;rank+=1)
			if(!paramisdefault(nth) && nth>=0 && rank!=nth)
				continue
			endif
			variable t = valve_open_times[rank][trial]
			if(t < t_min || t > t_max)
				continue
			endif
			wave trial_times = col(data_times,trial)
			variable index = binarysearch(trial_times,t)
			redimension /n=(-1,i+1) matrix
			matrix[][i] = copy[index+p-n_pnts/2][trial]
			i += 1
		endfor
	endfor
	printf "%d selected.\r", i
	
	// Upsample.  
	if(resampled)
		resample /up=(resampled)/dim=0 matrix
		x_scale /= resampled
		n_pnts *= resampled
	endif
	
	// Invert sign.  
	if(invert)
		matrix *= -1
	endif
	
	// Make VTA and errors from VT matrix.  
	matrixop /free vta = meancols(matrix^t)
	matrixop /free vta_sd = sqrt(varcols(subtractmean(matrix,1)^t))^t
	matrixop /free vta_sem = sqrt(varcols(subtractmean(matrix,1)^t)/numcols(matrix))^t
	setscale /p x,-n_pnts*x_scale/2,x_scale,matrix,vta,vta_sem,vta_sd
	variable avg = mean(vta)
	vta -= avg
	
	// Make final output waves.  
	string suffix1 = "", suffix2 = ""
	if(!paramisdefault(condition) && strlen(condition))
		suffix1 = "_"+condition
	endif
	if(!paramisdefault(nth) && nth>=0)
		suffix2 = "_"+num2str(nth)+"th"
	endif
	string suffix = suffix1 + suffix2
	if(!paramisdefault(subtractEpoch))
		wave background = MakeVTA(df,subtractEpoch,condition=condition,nth=nth,resampled=resampled,invert=invert,no_save=1)
		vta -= background
		suffix += "_sub"
	endif
	if(!no_save)
		duplicate /o vta,eagDF:$cleanupname("vta"+suffix,0)
		duplicate /o vta_sd,eagDF:$cleanupname("vta"+suffix+"_sd",0)
		duplicate /o vta_sem,eagDF:$cleanupname("vta"+suffix+"_sem",0)
	endif
	return vta
end

function /wave MergeVTAs(dfs[,conditions,nth,subtracted,pool_errors,merge_num])
	string dfs
	string conditions
	variable nth
	variable subtracted // 1 if they are air subtracted (they should have "_subtracted" in the name).  
	variable pool_errors // Compute sd and sem as mean across sd/sem's rather than sd/sem across means.   
	variable merge_num
	
	dfref currDF = getdatafolderdfr()
	string suffix1 = "", suffix2 = "", suffix3 = ""
	if(!paramisdefault(nth) && nth>=0)
		suffix2 = "_"+num2str(nth)+"th"
	endif
	if(subtracted)
		suffix3 = "_sub"
	endif
	string suffix = suffix2 + suffix3
	variable i,j
	newdatafolder /o/s root:vta
	newdatafolder /o/s $Environment()
	if(paramisdefault(merge_num))
		newdatafolder /o/s $("x"+suffix)
	else
		newdatafolder /o/s $("N"+num2str(merge_num))
	endif
	string /g sources = dfs
	string /g $"conditions" = conditions
	variable /g $"nth" = nth
	variable /g $"subtracted" = subtracted
	variable /g $"pool_errors" = pool_errors
	make /o/n=0 vta,vta_sd,vta_sem
	
	conditions = selectstring(!paramisdefault(conditions),";",conditions)
	for(j=0;j<itemsinlist(conditions);j+=1)
		string condition = stringfromlist(j,conditions)
		if(strlen(condition))
			suffix1 = "_"+condition
		endif
		suffix = suffix1 + suffix2 + suffix3
		make /free/n=0 vta_,vta_sd_,vta_sem_	
		for(i=0;i<itemsinlist(dfs);i+=1)
			string df_names = stringfromlist(i,dfs)
			string odor_df_name = stringfromlist(0,df_names,",")
			dfref df = $odor_df_name
			wave /sdfr=df vtai = $("vta"+suffix)
			wave /sdfr=df vtai_sd = $("vta"+suffix+"_sd")
			wave /sdfr=df vtai_sem = $("vta"+suffix+"_sem")
			concatenate {vtai},vta_
			concatenate {vtai_sd},vta_sd_
			concatenate {vtai_sem},vta_sem_
		endfor	
		if(pool_errors)
			matrixop /free vta_sd__ = meancols(vta_sd_^t)
			matrixop /free vta_sem__ = meancols(vta_sem_^t)/sqrt(i)
		else
			matrixop /free vta_sd__ = sqrt(varcols(vta_^t)^t)
			matrixop /free vta_sem__ = vta_sd_/sqrt(i)
		endif
		matrixop /free vta__ = meancols(vta_^t)
		wavestats /q/r=[0,dimsize(vta__,0)/2] vta__
		vta__ -= v_avg
		concatenate {vta__},vta
		concatenate {vta_sd__},vta_sd
		concatenate {vta_sem__},vta_sem
	endfor
	copyscales /p vtai,vta,vta_sd,vta_sem
	if(paramisdefault(merge_num))
		printf "Merged into vta%s\r",suffix
	else
		printf "Merged into number %d\r" merge_num
	endif
	setdatafolder currDF
	
	return vta
end

function FormatBB(df,epoch)
	dfref df 
	variable epoch
	
	dfref eagDF_ = df:EAG
	dfref eagDF = eagDF_:$("E"+num2str(epoch))
	dfref eventsDF_ = df:Events
	dfref eventsDF = eventsDF_:$("E"+num2str(epoch))
	
	wave /sdfr=eagDF data,data_times=times
	wave /t/sdfr=eventsDF desc
	wave /sdfr=eventsDF TTL,events_times=times
	extract /free events_times,stim_times,(TTL & 32768)>0 && (stringmatch(desc[p],"o*") || stringmatch(desc[p-1],"o*"))
	variable start = stim_times[0]
	variable finish = stim_times[numpnts(stim_times)-1]
	variable first_sample = 1+binarysearch(data_times,start)
	variable last_sample = binarysearch(data_times,finish)
	duplicate /free/r=[first_sample,last_sample] data,data_
	duplicate /free/r=[first_sample,last_sample] data_times,times_
	
	duplicate /o data_ eagDF:data_ // Overwrite data with formatted data.  
	duplicate /o times_ eagDF:times_ // Overwrite data with formatted data.  
	
	return data
end

function /wave MergeBBs([subtract,merge_num])
	variable subtract // Subtract air epochs.  
	variable merge_num
	
	string dfs = GetDFs()
	dfref currDF = getdatafolderdfr()
	string suffix1 = "", suffix2 = "", suffix3 = ""
	if(paramisdefault(subtract))
		suffix1 = "_sub"
	endif
	string suffix = suffix1 + suffix2 + suffix3
	newdatafolder /o/s root:BB
	newdatafolder /o/s $Environment()
	if(paramisdefault(merge_num))
		newdatafolder /o/s $("x"+suffix)
	else
		newdatafolder /o/s $("N"+num2str(merge_num))
	endif
	
	string /g sources = dfs
	make /o/n=0 bb,bb_sd,bb_sem
	variable i
	for(i=0;i<itemsinlist(dfs);i+=1)
		string df_names = stringfromlist(i,dfs)
		string odor_df_name = stringfromlist(0,df_names,",")
		string air_df_name = stringfromlist(1,df_names,",")
		if(stringmatch(odor_df_name[0],":"))
			odor_df_name = getdatafolder(1,currDF)+odor_df_name[1,strlen(odor_df_name)-1]
		endif
		dfref odorDF = $odor_df_name
		wave /sdfr=odorDF data
		duplicate /free data,bbi
		if(subtract)
			dfref airDF = $air_df_name		
			wave /sdfr=airDF data
			bbi -= data
		endif
		if(i>0)
			if(numpnts(bbi)<dimsize(bb,0))
				redimension /n=(numpnts(bbi),dimsize(bb,1)) bb
			elseif(numpnts(bbi)>dimsize(bb,0))
				redimension /n=(dimsize(bb,0)) bbi
			endif
		endif
		concatenate {bbi},bb
	endfor
	matrixop /o bb_sd = sqrt(varcols(bb^t)^t)
	matrixop /o bb_sem = bb_sd/sqrt(i)
	matrixop /o bb = meancols(bb^t)
	copyscales /p bbi,bb,bb_sd,bb_sem
	if(paramisdefault(merge_num))
		printf "Merged into bb%s\r",suffix
	else
		printf "Merged into number %d\r" merge_num
	endif
	setdatafolder currDF
	
	return bb
end

// Get list of data folders for the current animal, stimulus, and odor.  
// Format is "odorDF1,airDF1;odorDF2,airDF2;..."  
function /s GetDFs()
	wave /t/sdfr=root: list = active_experiments_list
	string dfs = ""
	variable i
	for(i=0;i<dimsize(list,0);i+=1)
		dfref df = root:$list[i][0]
		string odorEpoch = list[i][1]
		variable odorEpoch_ = str2num(odorEpoch[1,strlen(odorEpoch)-1])
		string airEpoch = list[i][2]
		variable airEpoch_ = str2num(airEpoch[1,strlen(airEpoch)-1])
		dfs += getdatafolder(1,df)+"EAG:"+odorEpoch+","+getdatafolder(1,df)+"EAG:"+airEpoch+";"
	endfor
	
	return dfs
end

function GetNumExperiments()
	wave /t/sdfr=root: list = active_experiments_list
	
	return dimsize(list,0)
end

function /df GetDF(i)
	variable i
	
	wave /t/sdfr=root: list = active_experiments_list
	string df_name = list[i][0]
	dfref df = root:$df_name
	
	return df
end

function GetOdorEpoch(i)
	variable i
	
	wave /t/sdfr=root: list = active_experiments_list
	string odorEpoch = list[i][1]
	
	return str2num(odorEpoch[1,strlen(odorEpoch)-1])
end

function GetAirEpoch(i)
	variable i
	
	wave /t/sdfr=root: list = active_experiments_list
	string airEpoch = list[i][2]
	
	return str2num(airEpoch[1,strlen(airEpoch)-1])
end

function /df String2DFRef(str)
	string str
	
	variable i
	for(i=0;i<itemsinlist(str,":");i+=1)
		string name = stringfromlist(i,str,":")
		if(i==0)
			dfref df = $(name+":")
		else
			dfref df2 = df:$name
			df = df2
		endif
	endfor
	
	return df
end

function /wave MergePeriodograms(dfs[,condition,subtracted,merge_num])
	string dfs
	variable subtracted,merge_num
	string condition
	
	dfref currDF = getdatafolderdfr()
	string suffix1 = "", suffix2 = "", suffix3 = ""
	if(!paramisdefault(condition))
		suffix1 = "_"+condition
	endif
	if(subtracted)
		suffix2 = "_sub"
	endif
	string suffix = suffix1 + suffix2 + suffix3
	newdatafolder /o/s root:periodograms
	newdatafolder /o/s $Environment()
	if(paramisdefault(merge_num))
		newdatafolder /o/s $("x"+suffix)
	else
		newdatafolder /o/s $("N"+num2str(merge_num))
	endif
	
	string /g sources = dfs
	variable i
	for(i=0;i<itemsinlist(dfs);i+=1)
		string df_names = stringfromlist(i,dfs)
		string odor_df_name = stringfromlist(0,df_names,",")
		dfref df = $odor_df_name
		wave /sdfr=df periodogrami = $("periodograms"+suffix)
		if(i==0)
			duplicate /free periodogrami,periodogram_
		else
			concatenate {periodogrami},periodogram_
		endif
	endfor	
	// periodogram should be M x N x trials at this point. 
	duplicate /free periodogram_ periodogram2_
	periodogram2_ = periodogram_ * periodogram_
	matrixop /o periodogram_sd = sqrt(sumbeams(periodogram2_)/i - powR(sumbeams(periodogram_)/i,2))
	matrixop /o periodogram_sem = periodogram_sd/sqrt(i)
	matrixop /o periodogram = sumbeams(periodogram_)/i
	copyscales /p periodogrami,periodogram,periodogram_sd,periodogram_sem
	if(paramisdefault(merge_num))
		printf "Merged into x%s\r",suffix
	else
		printf "Merged into N%d\r" merge_num
	endif
	setdatafolder currDF
	return periodogram
end

function /wave MergeSpectrograms(dfs[,condition,subtracted,merge_num])
	string dfs
	variable subtracted,merge_num
	string condition
	
	dfref currDF = getdatafolderdfr()
	string suffix1 = "", suffix2 = "", suffix3 = ""
	if(!paramisdefault(condition))
		suffix1 = "_"+condition
	endif
	if(subtracted)
		suffix2 = "_sub"
	endif
	string suffix = suffix1 + suffix2 + suffix3
	newdatafolder /o/s root:spectrograms
	newdatafolder /o/s $Environment()
	if(paramisdefault(merge_num))
		newdatafolder /o/s $("x"+suffix)
	else
		newdatafolder /o/s $("N"+num2str(merge_num))
	endif
	
	string /g sources = dfs
	variable i
	for(i=0;i<itemsinlist(dfs);i+=1)
		string df_names = stringfromlist(i,dfs)
		string odor_df_name = stringfromlist(0,df_names,",")
		dfref df = $odor_df_name
		wave /sdfr=df spectrogrami = $("spectrogram"+suffix)
		if(i==0)
			duplicate /free spectrogrami,spectrogram_
		else
			concatenate {spectrogrami},spectrogram_
		endif	
	endfor	
	// periodogram should be M x N x trials at this point. 
	duplicate /free spectrogram_ spectrogram2_
	spectrogram2_ = spectrogram_ * spectrogram_
	matrixop /o spectrogram_sd = sqrt(sumbeams(spectrogram2_)/i - powR(sumbeams(spectrogram_)/i,2))
	matrixop /o spectrogram_sem = spectrogram_sd/sqrt(i)
	matrixop /o spectrogram = sumbeams(spectrogram_)/i
	copyscales /p spectrogrami,spectrogram,spectrogram_sd,spectrogram_sem
	if(paramisdefault(merge_num))
		printf "Merged into x%s\r",suffix
	else
		printf "Merged into N%d\r" merge_num
	endif
	setdatafolder currDF
	return spectrogram
end

function DisplayVTA(df[,epoch,condition,nth,error,lines])
	dfref df
	string condition,error
	variable epoch,nth,lines
	
	if(!paramisdefault(epoch))
		dfref df2 = df:$("E"+num2str(epoch))
		df = df2
	endif
	error = selectstring(!paramisdefault(error),"sem",error)
	string suffix1 = "", suffix2 = ""
	if(!paramisdefault(condition))
		suffix1 = "_"+condition
	endif
	if(!paramisdefault(nth) && nth>=0)
		suffix2 = "_"+num2str(nth)+"th"
	endif
	string suffix = suffix1 + suffix2
	wave /sdfr=df vta = $cleanupname("vta"+suffix,0)
	
	if(!lines)
		ShadedErrorBars(vta,kind=error)
	else
		DrawAction delete
	endif
	SetAxis bottom -0.002,0.050
	ModifyGraph prescaleExp(bottom)=3
	Label bottom "Time since valve trigger (ms)"
	Label left "Signal strength (\F'Symbol'm\F'Default'V)"
	modifygraph offset={0,-vta(0)}
	modifygraph fsize=14,fstyle=1
	ModifyGraph manTick(bottom)={0,10,0,0}
	ModifyGraph zero(bottom)=1
	VTAStats(vta)
	svar /sdfr=df stats = $(nameofwave(vta)+"_stats")
	variable peak_x = numberbykey("Peak",stats)
	variable onset_x = numberbykey("Onset",stats)
	variable x_10 = numberbykey("10",stats)
	variable x_90 = numberbykey("90",stats)
	setdrawenv xcoord=bottom,dash=3,save
	drawline peak_x,0,peak_x,1
	drawline onset_x,0,onset_x,1
	setdrawenv xcoord=bottom,dash=2,save
	drawline x_10,0,x_10,1
	drawline x_90,0,x_90,1
	string name = getdatafolder(1,df)
	name = removeending(removefromlist("merged:root",name,":"),":")
	dowindow /t kwtopwin name
end

function VTAStats(vta)
	wave vta
	
	dfref df = getwavesdatafolderdfr(vta)
	killstrings /z df:$(nameofwave(vta)+"_stats")
	make /o/t/n=0 df:$(nameofwave(vta)+"_stats") /wave=stats
	variable i
	for(i=0;i<max(1,dimsize(vta,1));i+=1)
		duplicate /free/r=[][i,i] vta,vta_smooth
		//resample /rate=2000 vta_smooth
		wave vta_ = vta_smooth
		copyscales /p vta,vta_
		wavestats /q/r=(0,0.025) vta_
		variable peak = v_max, peak_x = v_maxloc
		differentiate /meth=1 vta_ /d=d_vta
		wavestats /q/r=(0,peak_x) d_vta
		findlevel /q/r=(v_maxloc,0) d_vta,v_max/5
		variable onset = vta_(v_levelx), onset_x = v_levelx
		findlevel /q/r=(onset_x,peak_x) vta_,onset+0.1*(peak-onset)
		variable x_10 = v_levelx
		findlevel /q/r=(onset_x,peak_x) vta_,onset+0.9*(peak-onset)
		variable x_90 = v_levelx
		string stats_
		sprintf stats_,"Onset:%f;10:%f;90:%f;Peak:%f;",onset_x,x_10,x_90,peak_x
		printf "%s\r",stats_
		stats[i] = {stats_}
	endfor
end

function DisplayPeriodograms(dfs)
	wave /df dfs
	
	display //as getdatafolder(0,df)
	string legend_str = ""
	variable i
	for(i=0;i<numpnts(dfs);i+=1)
		dfref dfi = dfs[i]
		wave /sdfr=dfi periodogram
		ShadedErrorBars(periodogram,append_=1)
		//legend_str += "\\s(odor"+epoch+") Odor "+epoch+"\r"
	endfor
	legend /j/n=legend0 legend_str
	modifygraph log=1,lsize=3,fsize=14,fstyle=1,zero(left)=4//,axisEnab(right)={0,0.4}
	string traces = tracenamelist("",";",1)
	for(i=0;i<=itemsinlist(traces);i+=1)
		string trace = stringfromlist(i,traces)
		if(stringmatch(trace,"*_high*") || stringmatch(trace,"*_low*"))
			modifygraph lsize($trace)=0
		endif
	endfor
	//setaxis right 0.5,100
	label left "Power (\F'Symbol'm\F'Default'V\S2\M/Hz)"
	//label right "Ratio"
	label bottom "Frequency (Hz)"
end

//function DisplayPeriodograms(df,odorEpochs,airEpochs)
//	dfref df
//	wave odorEpochs,airEpochs
//	
//	dfref eagDF = df:EAG
//	display as getdatafolder(0,df)
//	string legend_str = ""
//	variable i
//	for(i=0;i<numpnts(odorEpochs);i+=1)
//		string epoch = num2str(odorEpochs[i])
//		dfref dfi = eagDF:$("E"+epoch)
//		wave /sdfr=dfi periodogram
//		variable red = 65535*(mod(i,3)==0)
//		variable green = 65535*(mod(i,3)==1)
//		variable blue = 65535*(mod(i,3)==2)
//		appendtograph /c=(red,green,blue) periodogram /tn=$("odor"+epoch)
//		if(i==0)
//			duplicate /o periodogram df:periodogram /wave=diff
//		else
//			diff += periodogram
//		endif
//		legend_str += "\\s(odor"+epoch+") Odor "+epoch+"\r"
//	endfor
//	diff /= i
//	for(i=0;i<numpnts(airEpochs);i+=1)
//		epoch = num2str(airEpochs[i])
//		dfref dfi = eagDF:$("E"+num2str(airEpochs[i]))
//		wave /sdfr=dfi periodogram
//		appendtograph /c=(0,0,0) periodogram /tn=$("air"+epoch)
//		if(i==0)
//			duplicate /free periodogram control
//		else
//			control += periodogram
//		endif
//		legend_str += "\\s(air"+epoch+") Air "+epoch+"\r"
//	endfor
//	control /= i
//	diff /= control
//	//modifygraph muloffset={0,0.001}
//	appendtograph /r/c=(20000,20000,20000) diff /tn=diff
//	legend_str += "\\s(diff) Ratio"
//	legend /j/n=legend0 legend_str
//	modifygraph log=1,lsize(diff)=3,fsize=14,fstyle=1,zero(left)=4,axisEnab(right)={0,0.4}
//	setaxis right 0.5,100
//	label left "Power (\F'Symbol'm\F'Default'V\S2\M/Hz)"
//	label right "Ratio"
//	label bottom "Frequency (Hz)"
//end

function /s ClearData([depth])
	variable depth
	
	string wave_list = ""
	dfref	df = getdatafolderdfr()
	variable n_folders = countobjectsdfr(df,4)
	variable i
	for(i=0;i<n_folders;i+=1)
		dfref dfi = df:$getindexedobjnamedfr(df,4,i)
		setdatafolder dfi
		wave_list += ClearData(depth = depth+1)
	endfor
	setdatafolder df
	variable n_waves = countobjectsdfr(df,1)
	string list = wavelist("data",";","")
	list += wavelist("times",";","")
	list += wavelist("epoch*",";","")
	for(i=0;i<itemsinlist(list);i+=1)
		string wave_name = stringfromlist(i,list)
		if(!stringmatch(wave_name,"*outwave*"))
			wave_list += getdatafolder(1,df)+wave_name+";"
		endif
	endfor
	if(depth == 0)
		for(i=0;i<itemsinlist(wave_list);i+=1)
			wave_name = stringfromlist(i,wave_list)
			wave w = $wave_name
			killwaves /z w
		endfor
	endif
	return wave_list
end

function StartsDurations2ValveStates(starts,durations)
	wave starts,durations
	
	make /o/n=(starts[Inf]+durations[Inf]) valve_states = 0
	variable i
	for(i=0;i<numpnts(starts);i+=1)
		valve_states[starts[i],starts[i]+durations[i]-1] = 1
	endfor
	return valve_states
end

function EventTimes2ValveStates(df,epoch)
	dfref df
	variable epoch
	
	dfref eventsDF_ = df:Events
	dfref eventsDF = eventsDF_:$("E"+num2str(epoch))
	dfref eagDF_ = df:EAG
	dfref eagDF = eagDF_:$("E"+num2str(epoch))
	wave /sdfr=eventsDF times
	wave /t/sdfr=eventsDF desc
	extract /free times,start_times,stringmatch(desc[p],"o*")
	extract /free times,end_times,stringmatch(desc[p],"TTL*")
	wave /sdfr=eagDF data
	variable x_scale = deltax(data)
	make /o/n=((end_times[Inf]-start_times[0])/x_scale) valve_states = 0
	setscale /p x,start_times[0],x_scale,valve_states
	variable i
	for(i=0;i<numpnts(start_times);i+=1)
		variable start = x2pnt(valve_states,start_times[i])
		variable end_ = x2pnt(valve_states,end_times[i])
		valve_states[start,end_-1] = 1
	endfor
end

function EventTimes2EAGSegment(df,epoch)
	dfref df
	variable epoch
	
	dfref eventsDF_ = df:Events
	dfref eventsDF = eventsDF_:$("E"+num2str(epoch))
	dfref eagDF_ = df:EAG
	dfref eagDF = eagDF_:$("E"+num2str(epoch))
	wave /sdfr=eventsDF times
	wave /t/sdfr=eventsDF desc
	extract /free times,start_times,stringmatch(desc[p],"o*")
	extract /free times,end_times,stringmatch(desc[p],"TTL*")
	wave /sdfr=eagDF data,times
	variable start = binarysearch(times,start_times[0])
	variable end_ = binarysearch(times,end_times[Inf])
	duplicate /o/r=[start,end_] data,segment
	setscale /p x,times(start),deltax(data),segment
end

function /wave EAG_TiCl_Coherence(EAG_bb,TiCl_bb[,startT,endT])
	wave EAG_bb,TiCl_bb
	variable startT,endT
	
	startT = paramisdefault(startT) ? 0 : startT
	endT = paramisdefault(endT) ? Inf : endT
	
	variable seg_length = 1000
	variable seg_overlap = 500
	
	dfref currDF = getdatafolderdfr()
	newdatafolder /o/s root:coherence
	newdatafolder /o/s $cleanupname(num2str(startT)+"_"+num2str(endT),0)
	newdatafolder /o/s $Environment()
	
	duplicate /free EAG_bb,eag
	duplicate /free TiCl_bb,ticl
	
	variable points = min(numpnts(eag),numpnts(ticl))
	redimension /n=(points) eag,ticl
	variable scale = dimdelta(eag,0)/dimdelta(ticl,0)
	if(scale != 1 && (scale-1)<1e-12)
		printf "Small differences in wave scaling observed. Setting scales to be equal.\r"
		copyscales /p eag,ticl
	endif
	
	variable delta_x = dimdelta(eag,0)
	variable startP = round(startT/delta_X)
	variable endP = min(points,round(endT/delta_X))
	
	dspperiodogram /cohr /r=[(startP),(endP)] /segn={(seg_length),(seg_overlap)} eag,ticl
	wave w_periodogram
	matrixop /o coherence_mag = abs(w_periodogram)
	smooth 101,coherence_mag
	copyscales /p w_periodogram,coherence_mag
	variable i
	make /free/n=(numpnts(coherence_mag),n_shuffles) shuffles
	for(i=0;i<n_shuffles;i+=1)
		prog("Shuffle",i,n_shuffles)
		wave eag_shuffled = eag
		wave ticl_shuffled = RandomPhases(ticl)
		dspperiodogram /q/cohr /r=[(startP),(endP)] /segn={(seg_length),(seg_overlap)} eag_shuffled,ticl_shuffled
		matrixop /free coherence_mag_shuffle = abs(w_periodogram)
		smooth 101,coherence_mag_shuffle
		shuffles[][i] = coherence_mag_shuffle[p]
	endfor
	prog("Shuffle",0,0)
	matrixop /o coherence_mag_shuffled = meancols(shuffles^t)
	matrixop /o coherence_mag_shuffled_sd = sqrt(varcols(shuffles^t)^t)
	copyscales /p w_periodogram,coherence_mag,coherence_mag_shuffled,coherence_mag_shuffled_sd
	killwaves /z w_periodogram
	setdatafolder currDF
	
	return coherence_mag
end

function EAG_TiCl_Coherogram(EAG_bb,TiCl_bb)
	wave EAG_bb,TiCl_bb
	
	variable seg_length = 1000
	variable seg_overlap = 500
	
	dfref currDF = getdatafolderdfr()
	newdatafolder /o/s root:coherogram
	newdatafolder /o/s $Environment()
	
	duplicate /free EAG_bb,eag
	duplicate /free TiCl_bb,ticl
	
	variable points = min(numpnts(eag),numpnts(ticl))
	redimension /n=(points) eag,ticl
	wave coherogram = SlidingCoherence(eag,ticl,0.2,0.95)
	matrixop /o coherogram_mag = abs(coherogram)
	smooth /dim=0 101,coherogram_mag
	copyscales /p coherogram,coherogram_mag
	variable i
	make /free/n=(dimsize(coherogram_mag,0),dimsize(coherogram_mag,1),n_shuffles) shuffles
	for(i=0;i<n_shuffles;i+=1)
		prog("Shuffle",i,n_shuffles)
		wave eag_shuffled = eag
		wave ticl_shuffled = RandomPhases(ticl)
		wave coherogram = SlidingCoherence(eag,ticl,0.2,0.95)
		matrixop /free coherogram_mag_shuffle = abs(coherogram)
		smooth /dim=0 101,coherogram_mag_shuffle
		shuffles[][][i] = coherogram_mag_shuffle[p][q]
	endfor
	prog("Shuffle",0,0)
	matrixop /o coherogram_mag_shuffled = sumbeams(shuffles)/n_shuffles
	//duplicate /o shuffles $"shuffles"
	matrixop /free temp = shuffles*shuffles
	matrixop /o coherogram_mag_shuffled_sd = sqrt(sumbeams(temp)/n_shuffles - powR(sumbeams(shuffles)/n_shuffles,2))
	copyscales /p coherogram,coherogram_mag,coherogram_mag_shuffled,coherogram_mag_shuffled_sd
	killwaves /z coherogram
	setdatafolder currDF
	
	return coherogram_mag
end