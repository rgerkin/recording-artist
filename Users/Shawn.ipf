// $URL: svn://churro.cnbc.cmu.edu/igorcode/Users/Rick.ipf $
// $Author: rick $
// $Rev: 598 $
// $Date: 2011-11-18 16:16:45 -0500 (Fri, 18 Nov 2011) $

#pragma rtGlobals=1		// Use modern global access method.

#ifdef Shawn
#include "Minis"
//#include "Ken"
#include "Progress Window"

Macro Shawnify()
	ConvertShawn2Rick()
End

Function ConvertShawn2Rick()
	make /o/d/n=1 root:sweepT=0
	NewDataFolder /O/S root:status
	variable /G currSweep=0
	NewDataFolder /O/S root:parameters
	newdatafolder /o/s Acq
	NewDataFolder /o/s DAQs
	newdatafolder /o/s daq0
	make /o/t/n=0 channelConfigs
	SetDataFolder root:parameters:Acq
	newdatafolder /o/s ChannelConfigs
	
	//Make /o/T/n=0 Labels
	//Make /o/n=(0,3) Colors
	//cd ::
	//newdatafolder 
	//Variable /G numChannels=0
	SetDataFolder root:
	String waves=WaveList("wave*",";","")
	Variable i,j
	for(i=0;i<ItemsInList(waves);i+=1)
		String wave_name=StringFromList(i,waves)
		if(GrepString(wave_name,"wave%*[0-9]+"))
			Variable voltage
			Wave Wav=$wave_name
			Variable cols=dimsize(Wav,1)
			//if(cols<1)
			//	continue
			//endif
			cols = max(1,cols)
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
			if(j>currSweep)
				currSweep=j
			endif
			newdatafolder /o  root:parameters:Acq:channelConfigs:$("ch"+num2str(i))
			dfref chanDF = root:parameters:Acq:channelConfigs:$("ch"+num2str(i))
			string /g chanDF:label_=wave_name
			//Labels[numpnts(Labels)]={wave_name}
			//Colors[dimsize(Colors,0)]={0}
			channelConfigs[numpnts(channelConfigs)]={wave_name}
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
#endif