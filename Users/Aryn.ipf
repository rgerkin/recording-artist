#pragma rtGlobals=1		// Use modern global access method.

function StimulusTable()
	dowindow /k StimTable
	edit /k=1/n=StimTable.ld as "Stimulus Table"
	variable num_channels = GetNumChannels() // Number of channels.  
	variable curr_sweep = GetCurrSweep() // Current sweep number.  
	make /o/n=(curr_sweep,num_channels) StimulusAmplitudes
	variable i
	// This part could be done in one line except for the labeling of the table.  
	for(i=0;i<curr_sweep;i+=1)
		setdimlabel 0,i,$("Sweep "+num2str(i)) StimulusAmplitudes
		for(j=0;j<num_channels;j+=1)
			setdimlabel 1,j,$GetChanLabel(j) StimulusAmplitudes
			wave ampl = GetAmpl(j,sweepNum=i)
			wave livePulseSets = GetLivePulseSets(j,i)
			variable result = 0
			for(k=0;k<numpnts(livePulseSets);k+=1)
				result += ampl[livePulseSets[k]]
			endfor
			StimulusAmplitudes[i][j] = result
		endfor
	endfor
	append StimulusAmplitudes
end