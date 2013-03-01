#pragma rtGlobals=1		// Use modern global access method.

Function Data2Access(sweepstring,offsetNum)
	string sweepstring
	variable offsetNum
	print sweepstring
	if(!DataFolderExists("root:reanalysis"))
		newdatafolder /o/s root:reanalysis
	endif 
	Make/o/t/n=10 root:reanalysis:regionStrings
	Make/o/n=10 root:reanalysis:leftEnd
	Make/o/n=10 root:reanalysis:rightEnd
	Make/o/n=10 root:reanalysis:means
	Make/o/n=10 root:reanalysis:variances
	Make/o/n=10 root:reanalysis:slopes
	Make/o/n=10 root:reanalysis:durations
	Make/o/n=10 root:reanalysis:ratios
	Make/o/n=(10,10) root:reanalysis:accessFormatted
	Variable regions=Parse(sweepstring)
	Stats(StringFromList(0,sweepstring),regions)
	Format(offsetNum,regions)
End

Function Parse(sweepstring)
	string sweepstring
	Wave/T regionStrings = root:reanalysis:regionStrings
	Wave leftEnd = root:reanalysis:leftEnd
	Wave rightEnd = root:reanalysis:rightEnd
	Variable n=0
	Do
		regionStrings[n]=StringFromList(n+1,sweepstring,";")
		if(cmpstr("",regionstrings[n]))
			leftEnd[n]=str2num(StringFromList(0,regionstrings[n],","))
			rightEnd[n]=str2num(StringFromList(1,regionstrings[n],","))
		endif
		n+=1
	While(cmpstr(StringFromList(n,sweepstring,";"),""))
	return n-1
End

Function Stats(cellString,regions)
	String cellString
	Variable regions
	Wave firstPulse1=$("root:cell"+cellString+":ampl")
	Wave secondPulse1=$("root:cell"+cellString+":ampl2")
	Duplicate/o firstPulse1,ratioPulse
	ratioPulse=secondPulse1/firstPulse1
	Duplicate /o firstPulse1,firstPulse
	Duplicate /o secondPulse1,secondPulse 
	Wave leftEnd = root:reanalysis:leftEnd
	Wave rightEnd = root:reanalysis:rightEnd
	Wave means = root:reanalysis:means
	Wave variances = root:reanalysis:variances
	Wave slopes = root:reanalysis:slopes
	Wave durations = root:reanalysis:durations
	Wave ratios = root:reanalysis:ratios
	//firstPulse=-firstPulse
	//secondPulse=-secondPulse
	Variable n
	for(n=0;n<regions;n+=1)
		WaveStats/R=(leftEnd[n],rightEnd[n]) firstPulse
		means[n]=V_avg
		variances[n]=V_sdev^2
		CurveFit line, firstPulse (leftEnd[n],rightEnd[n]) 
		slopes[n]=K1
		durations[n]=V_npnts/3
		WaveStats/R=(leftEnd[n],rightEnd[n]) ratioPulse
		ratios[n]=Median1(ratioPulse,leftEnd[n],rightEnd[n])
	endfor
End

Function Format(offsetNum,regions)
	Variable offsetNum
	Variable regions
	Wave accessFormatted=root:reanalysis:accessFormatted
	Wave means = root:reanalysis:means
	Wave variances = root:reanalysis:variances
	Wave slopes = root:reanalysis:slopes
	Wave durations = root:reanalysis:durations
	Wave ratios = root:reanalysis:ratios
	Variable n=0
	Variable m=0
	for(n=0;n<regions-1;n+=1)
		if(offsetNum!=0 && offsetNum==n)
			m+=1
		endif
		accessFormatted[n][0]=ratios[m]
		accessFormatted[n][1]=ratios[m+1]
		accessFormatted[n][2]=means[m]
		accessFormatted[n][3]=means[m+1]
		accessFormatted[n][4]=variances[m]
		accessFormatted[n][5]=variances[m+1]
		accessFormatted[n][6]=durations[m]
		accessFormatted[n][7]=durations[m+1]
		accessFormatted[n][8]=slopes[m]
		accessFormatted[n][9]=slopes[m+1]
		m+=1
	endfor	
End

