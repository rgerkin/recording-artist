#pragma rtGlobals=1		// Use modern global access method.

Function Brett(name)
	String name
	LoadWave /B="F=-2;"/N=$name/J "c:"+name 
	Duplicate /o $(name+"0") $StringFromList(0,name,".")
	KillWaves /Z $(name+"0")
	name=StringFromList(0,name,".")
	BrettStimsAndSpikes(name)
	Wave SpikeTimes=$(name+"_SpikeTimes")
	Wave StimTimes=$(name+"_StimTimes")
	BrettSpikeMatrix(name,StimTimes,SpikeTimes)
	Wave SpikeMatrix=$(name+"_Matrix")
	BrettRowStats(name,SpikeMatrix)
	BrettPSTH(name,SpikeMatrix,bin_width=10)
End

// Get the stimuli and spikes from the wave derived from the text file
Function BrettStimsAndSpikes(wave_name)
	String wave_name
	Wave /T data=$wave_name
	Variable i
	for(i=0;i<numpnts(data);i+=1)
		if(StringMatch(data[i],"\"spikes\""))
			Make /o/n=0 $(wave_name+"_SpikeTimes")
			Wave SpikeTimes=$(wave_name+"_SpikeTimes")
			for(i=i+2;i<numpnts(data);i+=1)
				if(!IsEmptyString(data[i]))
					Redimension /n=(numpnts(SpikeTimes)+1) SpikeTimes
					SpikeTimes[numpnts(SpikeTimes)-1]=str2num(data[i])
				else
					break
				endif
			endfor
			Make /o/n=0 $(wave_name+"_StimTimes")
			Wave StimTimes=$(wave_name+"_StimTimes")
			for(i=i+6;i<numpnts(data);i+=1)
				if(!IsEmptyString(data[i]))
					Redimension /n=(numpnts(StimTimes)+1) StimTimes
					StimTimes[numpnts(StimTimes)-1]=str2num(data[i])
				else
					break
				endif
			endfor
		endif
	endfor
End

// Build a matrix of spike times relative to the stimulus
// First row is the first spike; First column is the first stimulus
Function BrettSpikeMatrix(name,StimTimes,SpikeTimes)
	String name
	Wave StimTimes,SpikeTimes
	Make /o/n=(0,numpnts(StimTimes)) $(name+"_Matrix")
	Wave SpikeMatrix=$(name+"_Matrix")
	Variable i,j,spike_time,stim_num,num_spikes=0,last_stim_num=0
	for(i=0;i<numpnts(SpikeTimes);i+=1)
		spike_time=SpikeTimes[i] // Get the spike
		stim_num=BinarySearch(StimTimes,spike_time) // Get the stimulus number for that spike
		if(stim_num==-2) // If the value is beyond the final stimulus
			stim_num=numpnts(StimTimes)-1 // Make it the final stimulus
		endif
		if(stim_num==last_stim_num) // If the previous stimulus is the same as this stimulus
			num_spikes+=1 // Add one to the number of spikes for this stimulus
			if(num_spikes>dimsize(SpikeMatrix,0)) // If there are more spikes than rows in the matrix
				Redimension /n=(num_spikes,numpnts(StimTimes)) SpikeMatrix // Add a row to the matrix
			endif
		else // If it is a new stimulus
			num_spikes=1 // Set the number of spikes so far for the new stimulus to 1
		endif
		SpikeMatrix[num_spikes-1][stim_num]=spike_time-StimTimes[stim_num] // Add this spike to the spike matrix
		last_stim_num=stim_num // Set the last stimulus number equal to this stimulus number
	endfor
	for(i=0;i<dimsize(SpikeMatrix,0);i+=1)
		for(j=0;j<dimsize(SpikeMatrix,1);j+=1)
			if(SpikeMatrix[i][j]==0)
				SpikeMatrix[i][j]=NaN // Set all 0 values to NaN
			endif
		endfor
	endfor
End

// Statistics for 1st Spike, 2nd Spike, etc.
Function BrettRowStats(name,SpikeMatrix)
	String name
	Wave SpikeMatrix
	Make /o/n=(dimsize(SpikeMatrix,0),4) $(name+"_Stats")
	Wave Stats=$(name+"_Stats")
	Variable i
	for(i=0;i<dimsize(SpikeMatrix,0);i+=1)
		Duplicate /o/R=[i,i][] SpikeMatrix Row
		WaveStats /Q Row
		Stats[i][0]=V_avg
		Stats[i][1]=V_sdev/sqrt(V_npnts)
		Redimension /n=(dimsize(Row,1)) Row
		BrettKillNans(Row)
		Sort Row,Row
		Stats[i][2]=Row((V_npnts-1)/2)
		Stats[i][3]=V_npnts
	endfor
	KillWaves /Z Row
End

// Gets ride of "Not a number" values
Function BrettKillNaNs(theWave)
	Wave theWave
	Variable i
	//MatrixTranspose theWave
	for(i=0;i<numpnts(theWave);i=i)
		if(theWave[i]>0 || theWave[i]<=0)
			i+=1
		else // If it is not greater than 0 or less than 0, it must be a NaN
			//print theWave
			//print i
			DeletePoints i,1,theWave
		endif
	endfor
End

Function BrettPSTH(name,SpikeMatrix[,bin_width])
	String name
	Wave SpikeMatrix
	Variable bin_width
	if(ParamIsDefault(bin_width))
		bin_width=10
	endif
	Variable i
	Make /o/n=0 $(name+"_RelSpikeTimes")
	Wave RelSpikeTimes=$(name+"_RelSpikeTimes")
	for(i=0;i<dimsize(SpikeMatrix,1);i+=1)
		Duplicate /o/R=[][i,i] SpikeMatrix Column
		Redimension /n=(dimsize(Column,0)) Column
		Concatenate /NP {Column},RelSpikeTimes // Build on the current histogram
	endfor
	Redimension /n=(dimsize(RelSpikeTimes,0)) RelSpikeTimes
	BrettKillNaNs(RelSpikeTimes)
	Make /o/n=(ceil(1000/bin_width)) $(name+"_Histogram")
	Wave Hist=$(name+"_Histogram")
	SetScale /I x,0,1,Hist
	Histogram /B=2 RelSpikeTimes,Hist
	Hist/=dimsize(SpikeMatrix,1)
	KillWaves /Z Column
	Display /N=$("HistWin_"+name) /K=1 Hist
	ModifyGraph mode=5
End