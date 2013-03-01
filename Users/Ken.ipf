// $URL: svn://churro.cnbc.cmu.edu/igorcode/Users/Ken.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.
#include "Minis"
#include "Symbols"

Function ConvertKen2Rick()
	NewDataFolder /O/S root:status
	Variable /G currentSweepNum=0
	NewDataFolder /O/S root:parameters
	Make /o/T/n=0 Labels
	Make /o/n=(0,3) Colors
	Variable /G numChannels=0
	SetDataFolder root:
	String waves=WaveList("MC_*",";","")
	Variable i,j
	for(i=0;i<ItemsInList(waves);i+=1)
		String wave_name=StringFromList(i,waves)
		if(GrepString(wave_name,"MC_%*[0-9]"))
			Variable voltage
			Wave Wav=$wave_name
			Variable cols=dimsize(Wav,1)
			if(cols<1)
				continue
			endif
			NewDataFolder /O root:$wave_name
			for(j=0;j<cols;j+=1)
				//print wave_name,j
				Duplicate /o/R=[][j,j] Wav, $("root:"+wave_name+":sweep"+num2str(j)) /WAVE=Sweep
				Redimension /n=(numpnts(Sweep)) Sweep
				CopyScales /P Wav,Sweep
				SetScale /P x,0,0.0001,Sweep
				Sweep*=1000
				Variable left=x2pnt(Sweep,0.05), right=x2pnt(Sweep,0.06)
				//Sweep[left,right]=Sweep[left-1]+(Sweep[right+1]-Sweep[left-1])*(p-left)/(right-left)
				//left=x2pnt(Sweep,0.15); right=x2pnt(Sweep,0.16)
				//Sweep[left,right]=Sweep[left-1]+(Sweep[right+1]-Sweep[left-1])*(p-left)/(right-left)
				right=x2pnt(Sweep,0.2)
				DeletePoints 0,right,Sweep
				WaveClear Sweep
			endfor
			if(j>currentSweepNum)
				currentSweepNum=j
			endif
			Labels[numpnts(Labels)]={wave_name}
			Colors[dimsize(Colors,0)]={0}
			numChannels+=1
		endif
	endfor
End

Function GetMiniTime()
	ControlInfo /W=ShowMinisWin SweepNum
	Variable sweepNum=V_Value
	ControlInfo /W=ShowMinisWin SweepMiniNum
	Variable sweepMiniNum=V_Value
	ControlInfo /W=ShowMinisWin Channel
	String channel=S_Value
	Wave Locs=root:Minis:$(channel):$("sweep"+num2str(sweepNum)):Locs
	return Locs[sweepMiniNum]
End

Function MiniTimeShow()
	Textbox /C/N=MiniTimeShow0 "\{GetMiniTime()}"
End

