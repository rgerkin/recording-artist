#pragma rtGlobals=1		// Use modern global access method.
//--------------------------------------------------------------Layouts--------------------------------------------------------------------------------

// Makes a layout for the windows whose name begins with "sweep"
Function SweepLayout()
	NewLayout /K=1 /N=$CleanupName(IgorInfo(1),0)
	String win,win_list=WinList("sweep*",";","WIN:1")
	win_list=RemoveFromList("Sweeps",win_list)
	Variable i
	win_list=SortList(win_list,";",16)
	for(i=0;i<ItemsInList(win_list);i+=1)
		win=StringFromList(i,win_list)
		//print win
		AppendLayoutObject graph $win
	endfor
	DoUpdate;HarmonizeAxes(win_list,"bottom")
	Variable num_graphs=str2num(StringByKey("NUMOBJECTS",LayoutInfo("","Layout")))
	Execute /Q "Tile/A=("+num2str(num_graphs)+",1)/O=1"
	Textbox /A=LT/N=Title /X=0 /Y=0 IgorInfo(1)
	//SavePICT/E=-6/B=72 as "CWT_"+IgorInfo(1)
End

Macro ZZ()
	SavePICT/E=-6/B=72 as "CWT_"+IgorInfo(1)
End

Function Printout([info_str])
	String info_str
	if(ParamIsDefault(info_str))
		Prompt info_str,"(Be sure the information is in quotes)"
		DoPrompt "Enter information about the protocol",info_str
	endif
	// Quick formatting fixes for compatibility
	ModifyGraph /W=Ampl_Analysis zero=0,axisEnab(Time_axis)={0.03,1},freePos(Ampl_axis)={0.03,kwFraction} 
	ModifyGraph /W=Sweeps freePos(VC_Axis)={0.05,kwFraction},freePos(CC_Axis)={0.05,kwFraction},axisEnab(time_axis)={0.05,0.95}
	ModifyGraph /W=Sweeps lblPos(VC_Axis)=25,lblPos(CC_Axis)=25
	
	Preferences 1 // Turn preferences on so that Page Setup can be preserved across layouts
	NewLayout /N=$(CleanupName(IgorInfo(1),0))
	AppendLayoutObject graph Membrane_Constants
	AppendLayoutObject graph Ampl_Analysis
	String pathway=TopVisibleTrace(win="Ampl_Analysis")
	pathway=ReplaceString("ampl_",pathway,"");pathway=ReplaceString("ampl2_",pathway,"") // Extract the synaptic pathway, e.g. "L2_R1"
	AppendLayoutObject graph $pathway
	AppendLayoutObject graph Sweeps
	//DoWindow/K Overlays
	//Display/K=1/N=Overlays as "Overlays"
	Execute("Tile")
	
	Textbox/N=Experiment/F=0/A=RT/X=10/Y=1.3 "\\JC\\Z16"+IgorInfo(1)+" "+pathway+" "+info_str+"\r\\Z10\JCPrinted: "+date()
	Notebook Experiment_Log selection={startOfFile, endOfFile}
	GetSelection notebook, Experiment_Log, 2
	TextBox/C/N=text2/F=0/A=LB/X=1/Y=35 S_selection
	DoWindow /C $CleanupName(IgorInfo(1)+" "+pathway+" "+info_str,0)
	//FindPairings(timingString,numRegions)
End

Function Add(numPairings,timing)
	Variable numPairings
	Variable timing
	if(!WaveExists(pairingTimes))
		Make/n=(1,3) pairingTimes
	endif
	pairingTimes[DimSize(pairingTimes,0),0]=hcsr(A)
	pairingTimes[DimSize(pairingTimes,0),1]=numPairings
	pairingTimes[DimSize(pairingTimes,0),2]=timing
	Redimension/n=((DimSize(pairingTimes,0)+1),3) pairingTimes
End

Function FindPairings(timingString,numRegions)
	string timingString
	variable numRegions
	Make /o/n=(10,4) pairingTimes
	pairingTimes=0
	Wave sweep_t=root:sweep_t
	Make/o/T/n=(numRegions) timings
	Variable i=0
	i=0
	Variable pairings=0;
	Variable n=0
	for(i=1;i<DimSize(sweep_t,0);i+=1)
		if(sweep_t[i]-sweep_t[i-1]<0.05)
			pairingTimes[n][0]=sweep_t[i]
			Do
				pairings+=1;
				i+=1;
			While(numpnts($("root:cellR1:sweep"+num2str(i)))<4500)
		pairingTimes[n][1]=pairings+1
		pairingTimes[n][3]=10000
		pairings=0
		GetAxis /W=ShortData left
		SetDrawEnv/W=ShortData xcoord= bottom,ycoord= left;DelayUpdate
		print n
		print timings[n]
		DrawText/W=ShortData (pairingTimes[n][0]+1),(V_max*0.8),num2str(pairingTimes[n][1])+StringFromList(n,timingString,";")	
		n+=1;
		endif
	endfor
	Make/o/n=10 times
	times=pairingTimes[p][0]
	Make/o/n=10 height
	height=pairingTimes[p][3]
	AppendToGraph/W=ShortData/L=left height vs times
	ModifyGraph/W=ShortData mode(height)=1
	ModifyGraph/W=ShortData rgb(height)=(0,65000,0)
End	

Function DisplayPairingTraces(pre,post,first,last,number)
	String pre,post
	Variable first,last,number
	first-=1
	last-=1
	Display /N=$("Pairing_"+num2str(number))
	Variable n=0
	for(n=first;n<=last;n+=1)
		AppendToGraph/L=pre_axis /C=(65535*R1(pre),65535*B3(pre),65535*L2(pre)) $("root:cell"+pre+":sweep"+num2str(n))
		AppendToGraph/R=post_axis  /C=(65535*R1(post),65535*B3(post),65535*L2(post)) $("root:cell"+post+":sweep"+num2str(n))
	endfor
	SetAxis bottom 0.09,0.15
	ModifyGraph tick(pre_axis)=2,tick(post_axis)=2,fSize(pre_axis)=6,fSize(bottom)=8;
	ModifyGraph fSize(post_axis)=6,axisEnab(bottom)={0.05,1};
	ModifyGraph freePos(pre_axis)={0.09,bottom},freePos(post_axis)=0
	AppendLayoutObject /F=0 /T=1 /R=(200,500,300,600) graph $("Pairing_"+num2str(number))
End

Function R1(channel)
	string channel
	if(!cmpstr("R1",channel))
		return 1
	else 
		return 0
	endif
End

Function L2(channel)
	string channel
	if(!cmpstr("L2",channel))
		return 1
	else 
		return 0
	endif
End

Function B3(channel)
	string channel
	if(!cmpstr("B3",channel))
		return 1
	else 
		return 0
	endif
End
Function Means(pre,post)
	String pre,post
	WaveStats /R=(xcsr(A),xcsr(B)) $("root:cell"+post+":ampl_"+pre+"_"+post)
	Print V_avg
End