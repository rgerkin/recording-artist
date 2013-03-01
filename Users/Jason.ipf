// $URL: svn://churro.cnbc.cmu.edu/igorcode/Users/Ken.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.
#include "Minis"
#include "Symbols"
static strconstant module = "Acq"

Function ConvertJason2Rick()
	// Setting shit up.  
	InitializeVariables()
	KillDataFolder /Z root:Chan_0
	nvar /sdfr=GetStatusDF() currSweep,waveformSweeps
	variable numChannels=0
	make /free/t/n=0 labels
	
	// Find the physiology_data folder.  
	dfref df = root:physiology_data
	if(!datafolderrefstatus(df))
		string cmd,message = "Where is the physiology_data folder"
		sprintf cmd,"CreateBrowser prompt=\"%s\",showWaves=0, showVars=0, showStrs=0",message
		execute /q cmd
		svar s_browserlist
		string folder = stringfromlist(0,s_browserlist)
		dfref df = $folder
	endif
	
	string DAQ = MasterDAQ()
	dfref DAQdf = GetDAQdf(DAQ)
	string waves = wavelist2(df=df,match="*_0") // Input waves in physiology_data
	variable i,j
	for(i=0;i<ItemsInList(waves);i+=1)
		string wave_name=StringFromList(i,waves)
		string label_ = removeending(wave_name,"_0")
		wave /sdfr=df w=$wave_name
		variable cols=dimsize(w,1)
		if(cols<1) // If it is 1-dimensional it isn't what we're looking for.  
			continue
		endif
		labels[numChannels] = {label_}
		SetWavTPackageSetting(module,"DAQs",DAQ,"channelConfigs",labels)
		InitChan(numChannels,label_=label_)	
		dfref chanDF = GetChanDF(numChannels)
		
		variable ms_per_sample = dimdelta(w,0)
		for(j=0;j<cols;j+=1)
			duplicate /o/R=[][j,j] w, chanDF:$("sweep"+num2str(currSweep)) /wave=sweep
			redimension /n=(numpnts(sweep)) sweep // Make 1-dimensional.  
			copyscales /P w,sweep
			setscale /P x,0,ms_per_sample/1000,"s",sweep // Convert from milliseconds to seconds.  
			currSweep += 1  
		endfor
		duplicate /o sweep,DAQdf:$("input_"+num2str(numChannels)) // Pretend that the last column was the last acquired sweep.  
		numChannels+=1
		waveformSweeps = j
	endfor
	
	for(i=0;i<numChannels;i+=1)
		wave history = GetChanHistory(i)
		redimension /n=(currSweep,-1,-1) history
		for(j=0;j<currSweep;j+=1)
			string acqMode
			strswitch(GetChanLabel(i))
				case "spont": // Voltage clamp.
					acqMode = "VC"
					break
				default: // Current clamp.
					acqMode = "CC"
					break
			endswitch
			setdimlabel 0,j,$acqMode,history
		endfor
		SetPackageSetting(module,"channelConfigs",GetChanName(i),"acqMode",acqMode)
	endfor
	make /o/d/n=(currSweep) sweepT = p/3 // Assume all sweeps are 20 seconds apart.  
	LoadPackageInstance(module,"acqModes","VC")
	LoadPackageInstance(module,"acqModes","CC")
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

