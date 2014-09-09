#pragma rtGlobals=1		// Use modern global access method.

#include "Symbols"
#include "Settings"
#include "Profiles"
#include "Utilities"
#include "List Functions"
#include "Signal Processing"
#include "Statistics"
#include "Progress Window"
#include "Wave Functions"
#include "Load Neuralynx"
#include "Neuralynx Analysis"
#include "Neuralynx Analysis2"
#include "Graphing"

strconstant pathName = "PaulPath"
strconstant animalPathName = "AnimalPath"
constant epoch_offset = 3 // Column number of epoch 0 in all_experiments_list. 
constant n_shuffles = 125

function All([i,j,k,no_delete])
	variable i,j,k,no_delete
	
	tic()
	string animals = "ticl;"//locust;ant;bee;cockroach;moth;orangeroach;laser;"
	string odors = ";"//hpn;hpn0.1;hpn0.01;hpn0.001;hx;hx0.1;nol;iso;lem;lio;bom;6me;"
	string stimuli = "bb;ff"
	
	wave /t/sdfr=root: active_list = active_experiments_list
	variable m
	for(i=i;i<itemsinlist(animals);i+=1)
		Prog("Animal",i,itemsinlist(animals))
		string animal = stringfromlist(i,animals)
		for(j=j;j<itemsinlist(odors);j+=1)
			Prog("Odor",j,itemsinlist(odors))
			string odor = stringfromlist(j,odors)
			for(k=0;k<itemsinlist(stimuli);k+=1)
				Prog("Stimulus",k,itemsinlist(animals))
				string stimulus = stringfromlist(k,stimuli)
				variable refNum
				string current
				
				sprintf current,"%s_%s_%s.txt", animal, stimulus, odor
				Close /A
				pathinfo $pathName
				if(!strlen(s_path))
					newpath /o/q/m="Choose the data path" $pathName
				endif
				DeleteFile /P=$pathName /Z current
				open /p=$pathName refNum as current
				if(Init(animal,stimulus,odor))
					printf "Could not initialize.\r"
					return -1
				endif
				string files_missing = CheckFileList() 
				if(strlen(files_missing))
					string msg
					sprintf msg,"WARNING: Missing these files %s",files_missing
					print msg
					// Remove missing experiments from active_list so they are not analyzed.  
					for(m=0;m<itemsinlist(files_missing);m+=1)
						string file = stringfromlist(m,files_missing)
						file = removeending(file,"_EAGds.ncs")
						file = removeending(file,"_Events.nev")
						findvalue /text=(file)/txop=4 active_list
						if(v_value>=0)
							deletepoints /m=0 v_value,1,active_list
						endif
					endfor
					//DoAlert 0,msg
					//return -2
				endif
				//printf "%s,%s,%s,%d",animal,stimulus,odor,dimsize(active_list,0)
				LoadAllEpochs(no_sparse=stringmatch(animal,"TiCl"))
				Go()
				Close refNum
				DeleteFile /P=$pathName current
			endfor
			k=0
		endfor
		j=0
		cd root:
		if(!no_delete)
			KillRecurse("ps*")
		endif
	endfor
	toc()
	print "Done"
	DoAlert 0,"Done!"
end

function Go()
	string dfs = GetDFs()
	if(!strlen(dfs))
		print "No data folders found.\r"
		return -1
	endif
	svar /sdfr=root: stimulus,animal
	wave /t/sdfr=root: active_experiments_list
	CleanData()
	MakeAllVTAs()
	return 0
//	FormatData()
//	MakeAllPeriodograms()
//	MakeAllSpectrograms()
	if(stringmatch(stimulus,"BB"))
		wave eag_bb = MergeBBs(subtract=0) // Odor epochs.  
		if(!stringmatch(animal,"TiCl"))
			make /free ranges = {{1,9.9}}//{0.01,1},{5,10}}
			wave ticl_bb = root:bb:ticl_bb_:x:bb
			variable i,j
//			for(i=0;i<dimsize(ranges,1);i+=1)
//				EAG_TiCl_Coherence(EAG_bb,TiCl_bb,startT=ranges[0][i],endT=ranges[1][i])
//			endfor
//			EAG_TiCl_Coherogram(EAG_bb,TiCl_bb)
//			
//			wave eag_bb = MergeBBs(subtract=-1) // Air epochs.  
//			for(i=0;i<dimsize(ranges,1);i+=1)
//				EAG_TiCl_Coherence(EAG_bb,TiCl_bb,startT=ranges[0][i],endT=ranges[1][i],subtracted=-1)
//			endfor
//			EAG_TiCl_Coherogram(EAG_bb,TiCl_bb,subtracted=-1)
			
			wave eag_bb = MergeBBs(subtract=1) // Air-subtracted odor epochs.  
			for(i=0;i<dimsize(ranges,1);i+=1)
				for(j=0;j<dimsize(active_experiments_list,0);j+=1)
					string name = active_experiments_list[j][0]
					dfref df = root:$(name):EAG
					string odor_epoch_ = active_experiments_list[j][1]
					string air_epoch_ = active_experiments_list[j][2]
					dfref odor_epoch = df:$odor_epoch_
					dfref air_epoch = df:$air_epoch_
					wave /sdfr=odor_epoch odor = data
					wave /sdfr=air_epoch air = data
					duplicate /free odor, bb
					bb -= air
					wave antenna_coherence = EAG_TiCl_Coherence(bb,TiCl_bb,startT=ranges[0][i],endT=ranges[1][i],subtracted=1,no_shuffles=1)
					duplicate /o antenna_coherence df:$"coherence_sub"
				endfor
				EAG_TiCl_Coherence(EAG_bb,TiCl_bb,startT=ranges[0][i],endT=ranges[1][i],subtracted=1)
			endfor
//			EAG_TiCl_Coherogram(EAG_bb,TiCl_bb,subtracted=1)
		endif
	endif
//	if(stringmatch(stimulus,"FF"))
//		wave eag_ff = MergeFFs(subtract=0) // Odor epochs.  
//		if(!stringmatch(animal,"TiCl"))
//			wave eag_ff = MergeFFs(subtract=-1) // Air epochs.  
//			wave eag_ff = MergeFFs(subtract=1) // Air-subtracted odor epochs.  
//		endif
//	endif
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
	
	string species_list = "bee:MS_Apis mellifera;ant:MS_Camponotus;cockroach:MS_Cockroach;moth:MS_Manduca sexta;locust:MS_Locust;orangeroach:MS_orange spotted roach;TiCl:MS_photodetector + TiCl;laser:valve+laser"
	string stimulus_list = "FF:;BB:BB"
	variable i,j,k,n=0
	for(i=0;i<dimsize(w,0);i+=1)
		string species = stringbykey(animal,species_list)
		if(stringmatch(w[i][1],species)) // If this experiment corresponds to this species.  
			if(stringmatch(species,"*TiCl*"))
				duplicate /free/t/r=[i,i][] w, row_
				redimension /n=(numpnts(row_)) row_
				extract /free/indx row_,matching_epochs,stringmatch(row_[p],stimulus)
				matching_epochs -= 3 // Epochs start in the third column.  
				variable new_epochs = numpnts(matching_epochs)
				if(new_epochs)
					n += new_epochs
					redimension /n=(n,3) active_experiments_list // File name, odor epochs, nearest blank epochs.  
					active_experiments_list[n-new_epochs,n-1][0] = w[i][0] // File name.  
					active_experiments_list[n-new_epochs,n-1][1] = "E"+num2str(matching_epochs[p-(n-new_epochs)])  
					active_experiments_list[n-new_epochs,n-1][2] = ""
				endif
				continue  
			else
				n += 1
				redimension /n=(n,3) active_experiments_list // File name, odor epochs, nearest blank epochs.  
				active_experiments_list[n-1][0] = w[i][0] // File name.  
				active_experiments_list[n-1][1] = "" // Epoch list.  
			endif
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

function /df LoadEpochs(experiment[,sparse])
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
		ChopAll(df,quiet=1)
		
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
										sprintf msg,"WARNING: Epoch %d in experiment %s found to be unusable but not marked as such.\r",epochNum,experiment
										print msg
										//doalert 0,msg
									endif
								endif
							endif 
							if(stringmatch(epoch,active_list[active_index][1]) || stringmatch(epoch,active_list[active_index][2])) // Match the odor epoch or the corresponding blank epoch.  
								k+=1
							else
								killdatafolder /z dfi // Otherwise delete since we don't need it right now.  
								if(v_flag) // Couldn't kill, probably because data is in use (graph or table).  
									k+=1
								endif
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
	wave /t/sdfr=root: all_list = all_experiments_list
	wave /t/sdfr=root: active_list = active_experiments_list
	for(i=0;i<dimsize(active_list,0);i+=1)
		Prog("Clean",i,dimsize(active_list,0))
		string name = active_list[i][0]
		dfref df = root:$name
		string odorEpoch = active_list[i][1]
		string airEpoch = active_list[i][2]
		dfref eagDF_ = df:EAG
		dfref eventsDF_ = df:Events
		findvalue /text=name/txop=4 all_experiments_list
		string notes = all_list[v_value][2]
		string epochs = odorEpoch+";"+airEpoch
		for(j=0;j<itemsinlist(epochs);j+=1)
			string epoch = stringfromlist(j,epochs)
			dfref eagDF = eagDF_:$epoch
			dfref eventsDF = eventsDF_:$epoch
			wave /t/sdfr=eventsDF desc
			wave /t/sdfr=eventsDF times,TTL
			if(stringmatch(desc[numpnts(desc)-1],"50ms"))
				redimension /n=(numpnts(desc)-1) desc,times,TTL
			endif
			if(stringmatch(desc[numpnts(desc)-2],"50ms"))
				redimension /n=(numpnts(desc)-2) desc,times,TTL
			endif
			string ff_strs = "cont;50ms;6ms";
			for(k=0;k<itemsinlist(ff_strs);k+=1)
				string ff_str = stringfromlist(k,ff_strs)
				findvalue /text=(ff_str) /txop=4 desc
				if(v_value>=0 && v_value<15)
					deletepoints 0,v_value+2,desc,times,TTL
				endif
			endfor
			wave /sdfr=eagDF data
			if(stringmatch(notes,"inverted!"))
				data *= -1
				printf "Inverted epoch %s in experiment %s.\r",epoch,name
			endif
			wavestats /q/r=[0,5] data
			data -= v_avg // Subtract mean of the first 6 points.  
		endfor
	endfor
	Prog("Clean",0,0)
end

function MakeAllVTAs([no_merge])
	variable no_merge
	
	variable i,j,k
	wave /t/sdfr=root: list = active_experiments_list
	svar /sdfr=root: stimulus, animal
	strswitch(stimulus)
		case "ff":
			string conditions = "100ms;50ms;30ms;20ms;15ms;12ms;10ms;8ms;6ms;cont"
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
	
	if(!no_merge)
		string dfs = GetDFs()
		for(k=0;k<itemsinlist(nths);k+=1)
			nth = str2num(stringfromlist(k,nths))
			if(!stringmatch(animal,"TiCl"))
				wave vta = MergeVTAs(dfs,conditions=conditions,nth=nth,subtracted=1,pool_errors=1)
				VTAStats(vta)
				wave vta = MergeVTAs(dfs,conditions=conditions,nth=nth,subtracted=-1,pool_errors=1)
				VTAStats(vta)
			endif
			wave vta = MergeVTAs(dfs,conditions=conditions,nth=nth,subtracted=0,pool_errors=1)
			VTAStats(vta)
		endfor
	endif
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
		sprintf msg,"WARNING: Number of starts (%d) not equal to number of frequencies (%d) for %s, epoch %d",numpnts(starts),n_freqs,getdatafolder(1,df),epoch
		print msg
		//DoAlert 0,msg
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
	return eagDF:data
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
	variable n_freqs = max(1,dimsize(data,1))
	variable seg_length = round(n_pnts/5)
	seg_length -= mod(seg_length,2)==0 ? 0 : 1
	variable seg_overlap = round(seg_length*0.99)
	variable start = round(n_pnts/10)
	variable i,j
	string suffix = ""
	if(!paramisdefault(subtractEpoch))
		if(subtractEpoch >= 0)
			suffix = "_sub"
		else
			suffix = "_air"
		endif
	endif
	make /o/n=(1,n_freqs) eagDF:$("periodograms"+suffix) /wave=periodograms
	
	for(i=0;i<n_freqs;i+=1)
		prog("Freq",i,n_freqs)
		duplicate /free/r=[][i,i] data trial
		copyscales /p data,trial
		redimension /d trial
		DSPPeriodogram /NODC=1 /Q /SEGN={(seg_length),(seg_overlap)} /R=[(start),(n_pnts-1)] /WIN=Hanning trial 
		wave w_periodogram
		if(numtype(w_periodogram[0]))
			duplicate /o trial,root:trial_
			duplicate /o data,root:data_
			print start,n_pnts,i,seg_length,seg_overlap
			DoAlert 1,"Periodogram had a bad value in it. Stop?"
			if(v_flag==1)
				abort
			endif
		endif
		redimension /n=(numpnts(w_periodogram),-1) periodograms
		copyscales /p w_periodogram,periodograms
		periodograms[][i] = log(w_periodogram[p])
	endfor
	prog("Freq",0,0)
	killwaves /z w_periodogram
	redimension /n=(round(200/dimdelta(periodograms,0)),-1,-1) periodograms
	
	if(!paramisdefault(subtractEpoch) && subtractEpoch>=0)
		wave air_periodograms = MakePeriodograms(df,subtractEpoch,subtractEpoch=-1)
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
		if(subtractEpoch >= 0)
			suffix = "_sub"
		else
			suffix = "_air"
		endif
	endif
	
	duplicate /free data data1D
	redimension /n=(numpnts(data)) data1D
	setscale /p x,0,dimdelta(data,0),data1D
	duplicate /o timefrequency(data1D,0.2,0.95,maxfreq=200,logg=1) eagDF:$("spectrogram"+suffix) /wave=spectrogram
	
	if(!paramisdefault(subtractEpoch) && subtractEpoch>=0)
		wave air_spectrogram = MakeSpectrogram(df,subtractEpoch,subtractEpoch=-1)
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
		if(subtractEpoch >= 0)
			suffix = "_sub"
		else
			suffix = "_air"
		endif
	endif
	
	DSPPeriodogram /NODC=1 /Q /SEGN={(seg_length),(seg_overlap)} /R=[(start),(n_pnts)] /WIN=Hanning trial 
	wave w_periodogram
	redimension /n=(round(200/dimdelta(w_periodogram,0)),1) w_periodogram
	w_periodogram = log(w_periodogram[p])
	duplicate /o w_periodogram eagDF:$("periodogram"+suffix) /wave=periodogram
	killwaves /z w_periodogram
	
	if(!paramisdefault(subtractEpoch) && subtractEpoch>=0)
		wave air_periodogram = MakeBBPeriodogram(df,subtractEpoch,subtractEpoch=-1)
		periodogram -= air_periodogram // Periodograms are already log-transformed so subtraction is correct here.  	
	endif
	
	return w_periodogram
end

function MakeAllPeriodograms()
	wave /t/sdfr=root: list = active_experiments_list
	svar /sdfr=root: stimulus, animal
	strswitch(stimulus)
		case "ff":
			//string conditions = "100ms;50ms;30ms;20ms;15ms;12ms;10ms;8ms;6ms;cont"
			break
		case "bb":
			//conditions = ";"
			break
		default:
			//conditions = ""
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
		wave periodogram = MergePeriodograms(dfs,subtracted=-1)
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
		wave spectrogram = MergeSpectrograms(dfs,subtracted=-1)
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
			dspperiodogram /db/nodc=1/segn={1000,900}/q/r=[(start_index+0.1/x_scale),(start_index+10/x_scale)]/win=Hanning data
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

function ChopAll(df[,quiet])
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
		wave /sdfr=e_minDF min_times = times
		t_min = min_times[0]-1
	else
		t_min = paramisdefault(e_min) ? -Inf : e_min
	endif
	if(!paramisdefault(e_max))
		dfref e_maxDF = eagDF:$("E"+num2str(e_max))
		wave /sdfr=e_maxDF max_times = times
		t_max = max_times[numpnts(max_times)-1]+1
	else
		t_max = paramisdefault(t_max) ? Inf : t_max
	endif
	nth = paramisdefault(nth) ? -1 : nth
	
	// Find valve-opening times. 
	wave /t/sdfr=eventsDF desc
	wave /sdfr=eventsDF event_times = times
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
		if(subtractEpoch >= 0)
			wave background = MakeVTA(df,subtractEpoch,subtractEpoch=-1,condition=condition,nth=nth,resampled=resampled,invert=invert)
			vta -= background
			suffix += "_sub"
		else
			suffix += "_air"
		endif
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
											// -1 if they are just air.  0 otherwise.   
	variable pool_errors // Compute sd and sem as mean across sd/sem's rather than sd/sem across means.   
	variable merge_num
	
	dfref currDF = getdatafolderdfr()
	string suffix1 = "", suffix2 = "", suffix3 = ""
	if(!paramisdefault(nth) && nth>=0)
		suffix2 = "_"+num2str(nth)+"th"
	endif
	if(subtracted > 0)
		suffix3 = "_sub"
	elseif(subtracted < 0)
		suffix3 = "_air"
	endif
	string suffix = suffix2 + suffix3
	variable i,j
	variable num_individuals = itemsinlist(dfs)
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
	make /o/n=0 vta,vta_sd,vta_sem,vta_jack
	
	conditions = selectstring(!paramisdefault(conditions),";",conditions)
	for(j=0;j<itemsinlist(conditions);j+=1)
		string condition = stringfromlist(j,conditions)
		if(strlen(condition))
			suffix1 = "_"+condition
		endif
		suffix = suffix1 + suffix2 + suffix3
		make /free/n=0 vta_,vta_sd_,vta_sem_	
		for(i=0;i<num_individuals;i+=1)
			string df_names = stringfromlist(i,dfs)
			string odor_df_name = stringfromlist(0,df_names,",")
			string air_df_name = stringfromlist(1,df_names,",")
			if(subtracted >= 0)
				dfref df = $odor_df_name
			else
				dfref df = $air_df_name
			endif
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
		make /free/n=(dimsize(vta_,0),dimsize(vta_,1)) vta_jack__ = vta__[p] * num_individuals // Sum instead of overage.  
		vta_jack__ -= vta_[p][q]
		vta_jack__ /= (num_individuals - 1)
		wavestats /q/r=[0,dimsize(vta__,0)/2] vta__
		vta__ -= v_avg
		vta_jack__ -= v_avg
		concatenate {vta__},vta
		concatenate {vta_sd__},vta_sd
		concatenate {vta_sem__},vta_sem
		redimension /n=(dimsize(vta_,0),dimsize(vta_jack,1)+1,dimsize(vta_,1)) vta_jack
		vta_jack[][j][] = vta_jack__[p][r]
	endfor
	copyscales /p vtai,vta,vta_sd,vta_sem,vta_jack
	if(paramisdefault(merge_num))
		printf "Merged into vta%s\r",suffix
	else
		printf "Merged into number %d\r" merge_num
	endif
	setdatafolder currDF
	
	return vta
end

function /wave FormatBB(df,epoch)
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
	setscale /p x,0,dimdelta(data,0),data_
	
	duplicate /o data_ eagDF:data // Overwrite data with formatted data.  
	duplicate /o times_ eagDF:times // Overwrite data with formatted data.  
	
	return data_
end

function /wave MergeBBs([subtract,merge_num])
	variable subtract // Subtract air epochs.  
	variable merge_num
	
	string dfs = GetDFs()
	dfref currDF = getdatafolderdfr()
	string suffix1 = "", suffix2 = "", suffix3 = ""
	if(subtract > 0)
		suffix1 = "_sub"
	elseif(subtract < 0)
		suffix1 = "_air"
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
		if(stringmatch(air_df_name[0],":"))
			air_df_name = getdatafolder(1,currDF)+air_df_name[1,strlen(air_df_name)-1]
		endif
		dfref odorDF = $odor_df_name
		dfref airDF = $air_df_name
		wave /z/sdfr=odorDF odor_data = data
		wave /z/sdfr=airDF air_data = data
		if(subtract >= 0)
			duplicate /free odor_data,bbi
			if(subtract > 0)
				bbi -= air_data
			endif
		endif
		if(subtract < 0)
			duplicate /free air_data,bbi		
		endif
		variable baseline = bbi[0]
		bbi -= baseline
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

function /wave MergeFFs([subtract,merge_num])
	variable subtract // Subtract air epochs.  
	variable merge_num
	
	string dfs = GetDFs()
	dfref currDF = getdatafolderdfr()
	string suffix1 = "", suffix2 = "", suffix3 = ""
	if(subtract > 0)
		suffix1 = "_sub"
	elseif(subtract < 0)
		suffix1 = "_air"
	endif
	string suffix = suffix1 + suffix2 + suffix3
	newdatafolder /o/s root:FF
	newdatafolder /o/s $Environment()
	if(paramisdefault(merge_num))
		newdatafolder /o/s $("x"+suffix)
	else
		newdatafolder /o/s $("N"+num2str(merge_num))
	endif
	
	string /g sources = dfs
	make /o/n=0 ff_all
	variable i
	for(i=0;i<itemsinlist(dfs);i+=1)
		string df_names = stringfromlist(i,dfs)
		string odor_df_name = stringfromlist(0,df_names,",")
		string air_df_name = stringfromlist(1,df_names,",")
		if(stringmatch(odor_df_name[0],":"))
			odor_df_name = getdatafolder(1,currDF)+odor_df_name[1,strlen(odor_df_name)-1]
		endif
		if(stringmatch(air_df_name[0],":"))
			air_df_name = getdatafolder(1,currDF)+air_df_name[1,strlen(air_df_name)-1]
		endif
		dfref odorDF = $odor_df_name
		dfref airDF = $air_df_name
		wave /z/sdfr=odorDF odor_data = data
		wave /z/sdfr=airDF air_data = data
		if(subtract >= 0)
			duplicate /free odor_data,ffi
			if(subtract > 0)
				ffi -= air_data
			endif
		endif
		if(subtract < 0)
			duplicate /free air_data,ffi		
		endif
		make /free/n=(dimsize(ffi,1)) baselines = ffi[0][p]
		ffi -= baselines[q]
		redimension /n=(numpnts(ffi)) ffi
		if(i>0)
			if(dimsize(ffi,0)<dimsize(ff_all,0))
				redimension /n=(dimsize(ffi,0),dimsize(ff_all,1),-1) ff_all
			elseif(dimsize(ffi,0)>dimsize(ff_all,0))
				redimension /n=(dimsize(ff_all,0),-1) ffi
			endif
		endif
		variable baseline = ffi[0]
		concatenate {ffi}, ff_all
	endfor
	matrixop /o ff_sd = sqrt(varcols(ff_all^t)^t)
	matrixop /o ff_sem = ff_sd/sqrt(i)
	matrixop /o ff = meancols(ff_all^t)
	redimension /n=(numpnts(ff)/10,10) ff,ff_sd,ff_sem
	copyscales /p ffi,ff,ff_sd,ff_sem
	if(paramisdefault(merge_num))
		printf "Merged into ff%s\r",suffix
	else
		printf "Merged into number %d\r" merge_num
	endif
	setdatafolder currDF
	
	return ff
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
	if(subtracted > 0)
		suffix2 = "_sub"
	elseif(subtracted < 0)
		suffix2 = "_air"
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
		string air_df_name = stringfromlist(1,df_names,",")
		if(subtracted >= 0)
			dfref df = $odor_df_name
		else
			dfref df = $air_df_name
		endif
		wave /sdfr=df periodogrami = $("periodograms"+suffix)
		if(i==0)
			duplicate /free periodogrami,periodogram_
		else
			if(dimsize(periodogrami,0)<dimsize(periodogram_,0))
				redimension /n=(dimsize(periodogrami,0),-1,-1) periodogram_
			elseif(dimsize(periodogrami,0)>dimsize(periodogram_,0))
				redimension /n=(dimsize(periodogram_,0),-1,-1) periodogrami
			endif
			concatenate {periodogrami},periodogram_
		endif
	endfor	
	
	string environment_ = Environment()
	string stimulus = stringfromlist(1,environment_,"_")
	
	matrixop /free periodogram2_ = periodogram_ * periodogram_
	// periodogram should be M x N x trials at this point. 
	if(1)//stringmatch(stimulus,"FF")) // For FF trials = 10.  
		matrixop /o periodogram_sd = sqrt(sumbeams(periodogram2_)/i - powR(sumbeams(periodogram_)/i,2))
		matrixop /o periodogram_sem = periodogram_sd/sqrt(i)
		matrixop /o periodogram = sumbeams(periodogram_)/i
		variable rows = dimsize(periodogram_,0)
		variable cols = dimsize(periodogram_,1)
		variable layers = dimsize(periodogram_,2)
		make /o/n=(rows,cols,layers) periodogram_jack = periodogram[p][q]*i
		periodogram_jack -= periodogram_[p][q][r]
		periodogram_jack /= i
	else // For BB trials = 1 (or 0, i.e. just M x N).  
		matrixop /o periodogram_sd = sqrt(meancols(periodogram2_^t) - powR(meancols(periodogram_^t),2))
		matrixop /o periodogram_sem = periodogram_sd/sqrt(i)
		matrixop /o periodogram = meancols(periodogram_^t)
	endif
	copyscales /p periodogrami,periodogram,periodogram_jack,periodogram_sd,periodogram_sem
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
	if(subtracted > 0)
		suffix2 = "_sub"
	elseif(subtracted < 0)
		suffix2 = "_air"
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
		string air_df_name = stringfromlist(1,df_names,",")
		if(subtracted >= 0)
			dfref df = $odor_df_name
		else
			dfref df = $air_df_name
		endif
		wave /sdfr=df spectrogrami = $("spectrogram"+suffix)
		if(i==0)
			duplicate /free spectrogrami,spectrogram_
		else
			if(dimsize(spectrogrami,0)<dimsize(spectrogram_,0))
				redimension /n=(dimsize(spectrogrami,0),-1,-1) spectrogram_
			elseif(dimsize(spectrogrami,0)>dimsize(spectrogram_,0))
				redimension /n=(dimsize(spectrogram_,0),-1,-1) spectrogrami
			endif
			concatenate {spectrogrami},spectrogram_
		endif	
	endfor	
	
	// spectrogram should be (time x valve intervals) x frequencies for FF and BB. 
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

function /wave StartsDurations2ValveStates(starts,durations)
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

function /wave EAG_TiCl_Coherence(EAG_bb,TiCl_bb[,startT,endT,subtracted,no_shuffles])
	wave EAG_bb,TiCl_bb
	variable startT,endT,subtracted,no_shuffles
	
	startT = paramisdefault(startT) ? 0 : startT
	endT = paramisdefault(endT) ? Inf : endT
	
	variable seg_length = 1000
	variable seg_overlap = 500
	
	string suffix = ""
	if(subtracted > 0)
		suffix += "_sub"
	elseif(subtracted < 0)
		suffix += "_air"
	endif
	
	dfref currDF = getdatafolderdfr()
	newdatafolder /o/s root:coherence
	newdatafolder /o/s $cleanupname(num2str(startT)+"_"+num2str(endT),0)
	newdatafolder /o/s $Environment()
	newdatafolder /o/s $("x"+suffix)
	
	duplicate /free EAG_bb,eag
	duplicate /free TiCl_bb,ticl
	
	variable points = min(numpnts(eag),numpnts(ticl))
	redimension /d/n=(points) eag,ticl
	variable scale = dimdelta(eag,0)/dimdelta(ticl,0)
	if(scale != 1)
		if(abs(scale-1)<1e-10)
			printf "Small differences in wave scaling observed. Setting scales to be equal.\r"
		else
			printf "WARNING: Scales appear to be unequal for %s and %s.\r",getwavesdatafolder(eag,2),getwavesdatafolder(ticl,2)
		endif
	endif
	copyscales /p eag,ticl
	
	variable delta_x = dimdelta(eag,0)
	variable startP = round(startT/delta_X)
	variable endP = min(points,round(endT/delta_X))
	
	dspperiodogram /cohr /q /r=[(startP),(endP)] /segn={(seg_length),(seg_overlap)} eag,ticl
	wave w_periodogram
	matrixop /o coherence_mag = abs(w_periodogram)
	smooth 101,coherence_mag
	copyscales /p w_periodogram,coherence_mag
	if(!no_shuffles)
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
		copyscales /p w_periodogram,coherence_mag_shuffled,coherence_mag_shuffled_sd
	endif
	copyscales /p w_periodogram,coherence_mag
	killwaves /z w_periodogram
	setdatafolder currDF
	
	return coherence_mag
end

function /wave EAG_TiCl_Coherogram(EAG_bb,TiCl_bb[,subtracted])
	wave EAG_bb,TiCl_bb
	variable subtracted
	
	variable seg_length = 1000
	variable seg_overlap = 500
	
	string suffix = ""
	if(subtracted > 0)
		suffix += "_sub"
	elseif(subtracted < 0)
		suffix += "_air"
	endif
	
	dfref currDF = getdatafolderdfr()
	newdatafolder /o/s root:coherogram
	newdatafolder /o/s $Environment()
	newdatafolder /o/s $("x"+suffix)
	
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
		wave coherogram = SlidingCoherence(eag_shuffled,ticl_shuffled,0.2,0.95)
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

// Merge VTAs within an animal, across pulse trains.  
function MergeVTAs2([nth,subtracted])
	variable nth
	variable subtracted // 1 if they are air subtracted (they should have "_subtracted" in the name). 
											// -1 if they are just air.  0 otherwise.   
	
	string species = "locust;ant;bee;cockroach;moth;orangeroach;"
	string odors = ";hpn;hpn0.1;hpn0.01;hpn0.001;hx;hx0.1;nol;iso;lem;lio;bom;6me;"
	string conditions = "100ms;50ms;30ms;20ms;15ms;12ms;10ms;8ms;6ms;cont"
	newdatafolder /o root:vta_individual
	variable i,j,k,m
	string loaded = ""
	string suffix1 = "", suffix2 = "", suffix3 = ""
	if(!paramisdefault(nth) && nth>=0)
		suffix2 = "_"+num2str(nth)+"th"
	endif
	if(subtracted > 0)
		suffix3 = "_sub"
	elseif(subtracted < 0)
		suffix3 = "_air"
	endif
	string suffix = suffix2 + suffix3
	variable n_species = itemsinlist(species)
	for(i=0;i<n_species;i+=1)
		Prog("Species",i,n_species)
		string specie = stringfromlist(i,species)
		variable n_odors = itemsinlist(odors)
		for(j=0;j<n_odors;j+=1)
			Prog("Odors",j,n_odors)
			string odor = stringfromlist(j,odors)
			Init(specie,"FF",odor)
			LoadAllEpochs(no_sparse=1)
			CleanData()
			//FormatData()
			//loaded += name+";"
			MakeAllVTAs(no_merge=1)	
			wave /t/sdfr=root: list = active_experiments_list
			variable n_individuals = dimsize(list,0)
			string folder_name = "root:vta_individual:"+cleanupname(Environment(),0)
			newdatafolder /o $folder_name
			dfref individual_df = $folder_name
			make /o/n=(1,n_individuals) individual_df:$("vta"+suffix) /wave=vta_matrix
			for(k=0;k<n_individuals;k+=1) // k is the individual.  
				string name = list[k][0]
				dfref animal_df = $("root:"+name+":EAG")
				string odorEpoch = list[k][1]
				variable odorEpoch_ = str2num(odorEpoch[1,strlen(odorEpoch)-1])
				string airEpoch = list[k][2]
				variable airEpoch_ = str2num(airEpoch[1,strlen(airEpoch)-1])
				if(subtracted > 0)
					dfref df = animal_df:$odorEpoch
				elseif(subtracted < 0)
					dfref df = animal_df:$airEpoch
				else
					dfref df = animal_df:$odorEpoch
				endif
				for(m=0;m<itemsinlist(conditions);m+=1)
					string condition = stringfromlist(m,conditions)
					wave vta_condition = df:$("vta_"+condition+suffix)
					if(m==0)
						duplicate /o vta_condition df:$("vta_ff"+suffix) /wave=vta_ff
						redimension /n=(-1,itemsinlist(conditions)) vta_ff
					else
						vta_ff[][m] = vta_condition[p]
					endif
				endfor
				matrixop /free vta_ff_ = meancols(vta_ff^t)
				copyscales vta_ff,vta_ff_
				wavestats /q/r=[0,x2pnt(vta_ff_,0)-1] vta_ff_
				variable baseline = v_avg
				vta_ff_ -= baseline
				duplicate /o vta_ff_ df:$("vta_ff"+suffix)
				redimension /n=(dimsize(vta_ff_,0),-1) vta_matrix
				vta_matrix[][k] = vta_ff_[p]
				copyscales vta_ff_,vta_matrix
			endfor
			KillRecurse("ps*")
		endfor
	endfor
end

function ExportVTAs()
	newpath /o/q desktop SpecialDirPath("Desktop",0,0,0)
	wave /df dfs = GetVTAdfs()
	variable i
	for(i=0;i<numpnts(dfs);i+=1)
		dfref df = dfs[i]
		wave /sdfr=df vta_jack
		if(numpnts(vta_jack) > 1)
			matrixop /free flat = meancols(vta_jack^t) // Average across conditions (inter-pulse intervals).  
			copyscales /p vta_jack,flat
			string name = VTA2Name(df)
			save /j/o/p=desktop flat as name+".dat"
		endif
	endfor
end

function /wave GetVTAdfs()
	dfref df = root:vta
	variable i
	make /free/df/n=0 dfs
	for(i=0;i<CountObjectsDFR(df,4);i+=1)
		string name = GetIndexedObjNameDFR(df,4,i)
		if(stringmatch(name,"*_ff_*"))
			dfref dfi = df:$name
			if(stringmatch(name,"ticl*"))
				dfref dfii = dfi:x_0th
			else
				dfii = dfi:x_0th_sub
			endif
			if(datafolderrefstatus(dfii))
				dfs[numpnts(dfs)] = {dfii}
			endif
		endif
	endfor
	return dfs
end

function /s VTA2Name(df)
	dfref df
	
	string name = getdatafolder(1,df)
	name = replacestring("root:vta:",name,"")
	name = replacestring("'",name,"")
	name = cleanupname(name,0)

	return name
end

function VTAonsets([mode,threshold])
	variable mode // 0 for jackknife, 1 for individual antennae.  
	variable threshold // Default is 5 S.D.'s.  Always use 5 for mean antenna.  
	
	threshold = paramisdefault(threshold) ? 5 : threshold
	wave /df dfs = GetVTAdfs()
	variable i,j
	make /o/n=(numpnts(dfs)) mean_onsets,avg_onsets
	for(i=0;i<numpnts(dfs);i+=1)
		dfref df = dfs[i]
		string name = VTA2name(df)
		wave /sdfr=df vta,vta_jack
		variable mean_onset = VTAonset(vta,threshold=5)
		variable n_individuals = dimsize(vta_jack,2)
		variable avg_onset = NaN, stdev_onset = NaN
		if(n_individuals>1)
			make /free/n=(n_individuals) sample_onsets
			for(j=0;j<n_individuals;j+=1)
				wave vta_jack_i = layer(vta_jack,j)
				if(mode == 1)
					duplicate /free vta, vta_i
					vta_i = (vta * n_individuals) - (vta_jack_i * (n_individuals-1))
					sample_onsets[j] = VTAonset(vta_i,threshold=threshold)
				else
					sample_onsets[j] = VTAonset(vta_jack_i,threshold=threshold)
				endif
			endfor
			wavestats /q sample_onsets
			avg_onset = v_avg
			stdev_onset = v_sdev
			if(mode==0)
				stdev_onset *= (n_individuals-1) // jackknife correction.  
			endif
			variable minn = v_min
			variable maxx = v_max
			variable n_bad = v_numnans
			if(numpnts(sample_onsets)>=3)
				statsquantiles /q sample_onsets
				variable med = v_median
				if(numpnts(sample_onsets)>=5)
					variable v25 = v_q25
					variable v75 = v_q75
				else
					v25 = nan
					v75 = nan
				endif
			endif
		endif
		mean_onset -= 3.96
		avg_onset -= 3.96
		mean_onsets[i] = mean_onset
		avg_onsets[i] = avg_onset
		printf "%s = %.1f (%.1f +/- %.1f) [%.0f - %.0f - %.0f - %.0f - %.0f], (%d, %d)\r",name,mean_onset,avg_onset,stdev_onset,minn,v25,med,v75,maxx,n_individuals,n_bad
	endfor
end

function VTAonset(vta[,threshold])
	wave vta
	variable threshold
	
	threshold = paramisdefault(threshold) ? 5 : threshold
	matrixop /free vta_ = meancols(vta^t)
	copyscales /p vta,vta_
	wavestats /q/r=(0,0.003) vta_
	variable thresh = v_avg + threshold*v_sdev
	findlevels /q/r=(0,) vta_,thresh
	wave w_findlevels
	variable i = 0
	do
		if(i >= numpnts(w_findlevels) - 1) // If last level crossing.  
			break
		endif
		if(w_findlevels[i+1] - w_findlevels[i] > 0.001) // If level crossing lasts at least 10 ms.  
			break
		endif
		i+=2
	while(1)
	variable xx = w_findlevels[i]
	
	variable onset = xx * 1000 // Convert to ms.  
	return onset
end

function LowestResolvablePeaks([mode,method])
	variable mode // 0 to use the jackknife groups of antennas, 1 to use the individual antennas.  
	variable method // 0 for a comparison using SEM, any other value for a comparison just using the mean, with the value as log-threshold.  
	
	string species = "ticl;locust;ant;bee;cockroach;moth;orangeroach;laser;"
	string odors = "hpn;hpn0.1;hpn0.01;hpn0.001;hx;hx0.1;nol;iso;lem;lio;bom;6me;"
	variable i,j,k
	make /o/n=0 means,avgs
	for(i=0;i<itemsinlist(species);i+=1)
		string specie = stringfromlist(i,species)
		for(j=0;j<itemsinlist(odors);j+=1)
			string odor = stringfromlist(j,odors)
			dfref df = root:periodograms:$(specie+"_ff_"+odor):x_sub
			if(datafolderrefstatus(df))
				wave /sdfr=df periodogram_jack
				variable n_individuals = max(1,dimsize(periodogram_jack,2))
				make /free/n=(n_individuals) values
				for(k=0;k<n_individuals;k+=1)
					if(mode == 0)
						values[k] = LowestResolvablePeak(df,jack_sample=k,method=method)
					elseif(mode == 1)
						values[k] = LowestResolvablePeak(df,antenna=k,method=method)
					endif
				endfor
				variable m = Nan, s = NaN, minn = NaN, maxx = NaN, v25 = nan, v75 = nan
				variable value = LowestResolvablePeak(df,method=method) // Mean antenna.  
				if(n_individuals>1)
					wavestats /q values
					m = v_avg
					s = v_sdev
					if(mode == 0)
						 s *= (n_individuals-1) // jackknife correction.  
					endif
					minn = v_min
					maxx = v_max
					variable nans = v_numnans
					variable med = statsmedian(values)
					if(n_individuals>=5)
						statsquantiles /q values
						v25 = v_q25
						v75 = v_q75
					endif
				endif
				means[numpnts(means)] = {value}
				avgs[numpnts(avgs)] = {m}
				printf "%s, %s: %.0f, %.1f +/- %.1f, [%.0f - %.0f - %.0f - %.0f - %.0f], (%d,%d)\r",specie,odor,value,m,s,minn,v25,med,v75,maxx,n_individuals,nans
			endif
		endfor
	endfor
end

function LowestResolvablePeak(df[,antenna,jack_sample,method])
	dfref df
	variable antenna // Calculate for the antenna with this index.  
	variable jack_sample // Calculate for the jacknife sample with this index (i.e. excluding the antenna with this index).  
	variable method // 0 for a comparison using SEM, any other value for a comparison just using the mean, with the value as log-threshold.  
	
	variable result = nan
	wave /sdfr=df periodogram,periodogram_sem
	if(!paramisdefault(jack_sample))
		wave /sdfr=df periodogram_jack
		copyscales /p periodogram,periodogram_jack // This may not have been done in MergePeriodograms()
		wave periodogram = layer(periodogram_jack,jack_sample)
	endif
	if(!paramisdefault(antenna))
		wave /sdfr=df periodogram_jack
		copyscales /p periodogram,periodogram_jack // This may not have been done in MergePeriodograms()
		wave periodogram_jack_i = layer(periodogram_jack,antenna)
		variable n_antennae = max(1,dimsize(periodogram_jack,2))
		duplicate /free periodogram, periodogram_i
		periodogram_i = (periodogram * n_antennae) - (periodogram_jack_i * (n_antennae-1))
		wave periodogram = periodogram_i
	endif
	make /free/n=9 ms_values = {6,8,10,12,15,20,30,50,100}
	variable i
	//print getdatafolder(1,df)
	for(i=0;i<numpnts(ms_values);i+=1)
		variable ms = ms_values[i]
		if(CanResolvePeak(ms,periodogram,periodogram_sem,method=method))
			result = ms
			//if(ms>=50)
			//	print "Yes:"+num2str(ms)
			//endif
			break
		endif
		if(ms==100)
			//print "No:"+num2str(ms)
		endif
	endfor
	return result
end

function CanResolvePeak(ms,periodogram,periodogram_sem[,method])
	variable ms, method
	wave periodogram, periodogram_sem
	
	variable peak_range = 0
	variable trough_range = 0.5
	variable result = nan
	string conditions = "100ms;50ms;30ms;20ms;15ms;12ms;10ms;8ms;6ms;cont"
	variable col_ = whichlistitem(num2str(ms)+"ms",conditions)
	if(col_ >= 0)
		variable hz = 1000/ms
		wave periodogram_ = col(periodogram,col_)
		if(method==0)
			wave periodogram_sem_ = col(periodogram_sem,col_)
			duplicate /free periodogram_,periodogram_lower,periodogram_higher
			periodogram_lower -= periodogram_sem_
			periodogram_higher += periodogram_sem_
			
			//wavestats /q/r=(hz*(1-peak_range),hz*(1+peak_range)) periodogram_
			//variable meann = periodogram_(v_maxloc)
			//variable maxx = periodogram_lower(v_maxloc) // highest mean - sem.  
			variable meann = periodogram_(hz)
			variable maxx = periodogram_lower(hz) // highest mean - sem.  
			wavestats /q/r=(hz*(1-trough_range),hz) periodogram_higher
			variable minn_left = v_min
			wavestats /q/r=(hz,hz*(1+trough_range)) periodogram_higher
			variable minn_right = v_min // lowest mean + sem.  
			if(maxx > minn_left && maxx > minn_right && meann > 0)
				result = 1
			else
				result = 0
			endif
		else
			maxx = periodogram_(hz) // highest mean - sem.  
			//wavestats /q/r=(hz*(1-trough_range),hz*(1+trough_range)) periodogram_
			//meann = v_avg
			variable trough_range_ = trough_range
			do
				duplicate /free/r=(hz*(1-trough_range_),hz*(1+trough_range_)) periodogram_,w
				if(numpnts(w)<3)
					trough_range_ *= 1.1
				else
					break
				endif
			while(1)
			//dspdetrend /f=line w
			//wave w = w_detrend
			maxx = w(hz)
			wavestats /q w
			meann = (v_avg*v_npnts - maxx)/(v_npnts-1) // Mean not counting peak.  
			if(maxx > (meann + method) && maxx > 0)
				result = 1
			else
				result = 0
			endif
		endif
	endif
	return result
end

function MaxCoherences()
	string species = "ticl;locust;ant;bee;cockroach;moth;orangeroach;laser;"
	string odors = "hpn;hpn0.1;hpn0.01;hpn0.001;hx;hx0.1;nol;iso;lem;lio;bom;6me;"
	variable i,j,k
	make /o/n=0 avgs,means
	for(i=0;i<itemsinlist(species);i+=1)
		string specie = stringfromlist(i,species)
		for(j=0;j<itemsinlist(odors);j+=1)
			string odor = stringfromlist(j,odors)
			dfref df = root:coherence:X1_9_9:$((specie+"_bb_"+odor)):x_sub
			if(datafolderrefstatus(df))
				wave /sdfr=df coherence_mag,coherence_mag_shuffled,coherence_mag_shuffled_sd
				Init(specie,"bb",odor)
				wave /t active_experiments_list
				variable n_individuals = max(1,dimsize(active_experiments_list,0))
				make /free/n=(n_individuals) values
				for(k=0;k<n_individuals;k+=1)
					string name = active_experiments_list[k][0]
					dfref antenna_df = $("root:"+name+":EAG")
					wave /sdfr=antenna_df coherence_mag_k = coherence_sub
					values[k] = MaxCoherence(coherence_mag_k,coherence_mag_shuffled,coherence_mag_shuffled_sd)
				endfor
				variable m = Nan, s = NaN, minn=NaN, maxx=NaN, v25=NaN, v75=Nan, bad=0
				variable value = MaxCoherence(coherence_mag,coherence_mag_shuffled,coherence_mag_shuffled_sd) // Mean antenna.  
				if(n_individuals>1)
					wavestats /q values
					m = v_avg
					s = v_sdev
					minn = v_min
					maxx = v_max
					bad = v_numnans
					extract /free values, good_values, numtype(values)==0
					variable med = statsmedian(good_values)
					if(numpnts(good_values)>=5)
						statsquantiles /q good_values
						v25 = v_q25
						v75 = v_q75
					endif
				endif
				//print values
				//sort values,values
				printf "%s, %s: %.0f, %.0f +/- %.0f, [%.0f - %.0f - %.0f - %.0f - %.0f], (%d,%d)\r",specie,odor,value,m,s,minn,v25,med,v75,maxx,n_individuals,bad
				if(v_min > value || v_max < value)
					//print value,values
				endif
				avgs[numpnts(avgs)] = {m}
				means[numpnts(means)] = {value}
			endif
		endfor
	endfor
end

function MaxCoherence(meann,shuffle,shuffle_sd[,threshold])
	wave meann,shuffle,shuffle_sd
	variable threshold
	
	threshold = paramisdefault(threshold) ? 5 : threshold
	
	duplicate /free meann, diff
	diff -= (shuffle + threshold*shuffle_sd)
	smooth 101,diff
	findlevel /q/edge=2 diff, 0
	if(numtype(v_levelx) || diff[0] < 0 && diff[1] < 0 && diff[2] < 0) // If no downward level crossing found.  
		v_levelx = NaN // Then it must be below the threshold throughout, so set to 0 (no coherence).  
	endif
	return v_levelx
end