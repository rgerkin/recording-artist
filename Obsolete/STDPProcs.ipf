#pragma rtGlobals=1		// Use modern global access method.

Function PPRVsSTDP2()
	String PPR_waves=WaveList("PPR_0*",";","")
	Variable i,j,size=ItemsInList(PPR_waves)
	for(i=0;i<30;i+=5)
		Make /o/n=(size) $("PPR_Change_"+num2str(i)+"_"+num2str(i+5))
		Wave PPRChange=$("PPR_Change_"+num2str(i)+"_"+num2str(i+5))
		for(j=0;j<size;j+=1)
			Wave PPRExp=$StringFromList(j,PPR_waves)
			SetScale /P x,-10,0.5,PPRExp
			PPRChange[j]=Median(theWave=PPRExp,x1=i+0.5,x2=i+5)/Median(theWave=PPRExp,x1=-5.5,x2=-0.5)
		
		endfor
		Display /K=1 root:STDPRatio vs PPRChange
		BigDots()
	endfor
	Label left "STDP Ratio"
	Label bottom "Change in Paired Pulse Ratio"
End

Function PPRvsSTDP([after1,after2])
	Variable after1,after2
	after1=ParamIsDefault(after1) ? 20 : after1
	after2=ParamIsDefault(after2) ? 20 : after2
	SetDataFolder root:PPR
	String wave_list=WaveList("PPR_0*",";","")
	Variable num_waves=ItemsInList(wave_list)
	Make /o/n=(num_waves) PPR_Before=NaN,PPR_Ratio=NaN
	Wave STDPRatio=root:STDPRatio
	Variable i
	for(i=0;i<num_waves;i+=1)
		Wave PPR=$StringFromList(i,wave_list)
		WaveStats /Q /R=(-6,-1) PPR
		PPR_Before[i]=V_avg 
		WaveStats /Q /R=(20,30) PPR
		PPR_Ratio[i]=V_avg/PPR_Before[i] 
		Print NameOfWave(PPR)+"; STDP Ratio: "+num2str(STDPRatio[i])+"; PPR Before: "+num2str(PPR_Before[i])+"; PPR Change: "+num2str(PPR_Ratio[i])
	endfor
	Display /K=1 PPR_Ratio vs PPR_Before
	Label left "Ratio [PPR After]/[PPR Before]"
	Label bottom "PPR Before Induction"
	BigDots()
	
	Display /K=1 STDPRatio vs PPR_Ratio
	Label left "STDP Ratio"
	Label bottom "Ratio [PPR After]/[PPR Before]"
	BigDots()
	ModifyGraph rgb=(0,65535,0)
	
	Display /K=1 STDPRatio vs PPR_Before
	Label left "STDP Ratio"
	Label bottom "PPR Before Induction"
	BigDots()
	ModifyGraph rgb=(0,0,65535)
	SetDataFolder root:
End

Function PlotRatiovsBefore(after1,after2)
	Variable after1,after2
	String wave_list=WaveList("PPR_0*",";","")
	Variable num_waves=ItemsInList(wave_list)
	Make /o/n=(num_waves) Before=NaN,Ratio=NaN
	Variable i
	for(i=0;i<num_waves;i+=1)
		Wave PPR=$StringFromList(i,wave_list)
		WaveStats /Q /R=(-6,-1) PPR
		Before[i]=V_avg 
		WaveStats /Q /R=(20,30) PPR
		Ratio[i]=V_avg/Before[i] 
	endfor
	Display /K=1 Ratio vs Before
	Label left "Ratio [PPR After]/[PPR Before]"
	Label bottom "PPR Before Induction"
	BigDots()
	
	Display /K=1 STDPRatio vs Ratio
	Label left "STDP Ratio"
	Label bottom "Ratio [PPR After]/[PPR Before]"
	BigDots()
	ModifyGraph rgb=(0,65535,0)
	
	Display /K=1 STDPRatio vs Before
	Label left "STDP Ratio"
	Label bottom "PPR Before Induction"
	BigDots()
	ModifyGraph rgb=(0,0,65535)
End
