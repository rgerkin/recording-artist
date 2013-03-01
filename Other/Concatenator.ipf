// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Concatenator.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

strconstant loc="root:Packages:Concatenator:"
constant seam_threshold=10 // Number of units (pA or mV) to use as a threshold for identifying unacceptable seams.  
constant seam_sample=0.01 // Number of seconds to average when scanning around the seams.  

Function InitConcat()
	NewDataFolder /O root:Packages
	NewDataFolder /O/S $RemoveEnding(loc,":")
	String /G concat_list
	String /G prefix="sweep"
	String /G folder
	Variable /G seamless
	ConcatenatorPanel()
End

Function ConcatenatorPanel()
	DoWindow /K ConcatPanel
	NewPanel /W=(100,100,400,220) /K=1/N=ConcatPanel as "Concatenator"
	SetVariable folder fsize=12, pos={5,5}, size={150,25}, value=$(loc+"folder"),title=" "
	Button ChooseFolder size={100,20}, title="Choose Folder",proc=PanelButtons
	SetVariable prefix, fsize=12, pos={5,35}, size={100,20}, value=$(loc+"prefix"), title="Prefix:"
	SetVariable ConcatList, fsize=12, size={175,20}, value=$(loc+"concat_list"), title="Sweep List:"
	Button Cursors pos={200,60}, size={85,20},  title="Cursors", proc=PanelButtons
	//GroupBox GroupBox1, pos={0,0}, size={400,75} 
	DrawLine 0,88,400,88
	Button Concat, size={100,20}, pos={5,95},  title="Concatenate", proc=PanelButtons
	Checkbox Seamless, fsize=12, pos={115,95}, variable=$(loc+"seamless"), title="Seamless"
	Checkbox DisplayIt, fsize=12, pos={210,95}, title="Display"
	SetDataFolder root:
End

Function PanelButtons(ctrlName) : ButtonControl
	String ctrlName
	strswitch(ctrlName)
		case "ChooseFolder":
			Execute /Q "CreateBrowser prompt=\"Choose a data folder\", showVars=0, showStrs=0"
			SVAR S_BrowserList
			String one_folder=StringFromList(0,S_BrowserList)
			if(StringMatch(one_folder,"root"))
				one_folder="root:"
			endif
			if(DataFolderExists(one_folder))
				SVar folder=$(loc+"folder")
				folder=RemoveEnding(one_folder,":")
			else
				PanelButtons("ChooseFolder")
			endif
			break
		case "Cursors":
			if(strlen(WinList("*",";","WIN:1")) && strlen(CsrInfo(A)) && strlen(CsrInfo(B)))
				SVar concat_list=$(loc+"concat_list")
				concat_list=num2str(xcsr(A)+1)+","+num2str(xcsr(B)+1)
			endif
			break
		case "Concat":
			ConcatenateWaves()
			break
	endswitch
End

Function ConcatenateWaves()
	String curr_folder=GetDataFolder(1)
	SetDataFolder $loc
	SVar concat_list=$(loc+"concat_list")
	String list=ListExpand(concat_list)
	SVar prefix=$(loc+"prefix")
	SVar folder=$(loc+"folder")
	list=AddPrefix(list,folder+":"+prefix)
	String concat_name=CleanupName(prefix+concat_list,1)
	
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		String wave_name=StringFromList(i,list)
		if(!exists(wave_name))
			DoAlert 0,"There is no wave named "+wave_name
			SetDataFolder curr_folder
			return 0
		endif
	endfor
	
	Concatenate /O/NP list, $concat_name
	Wave Concatenated=$concat_name
	NVar seamless=$(loc+"seamless")
	if(seamless)
		FixSeams(Concatenated,list)
	endif
	ControlInfo /W=ConcatPanel DisplayIt
	if(V_Value)
		Display Concatenated
	endif
	SetDataFolder curr_folder
End

Function FixSeams(Concatenated,list)
	Wave Concatenated
	String list
	Variable i,first,last,cum_points=0
	for(i=0;i<ItemsInList(list);i+=1)
		Wave theWave=$StringFromList(i,list)
		Variable duration=dimsize(theWave,0)*numpnts(theWave)
		first=mean(theWave,duration-0.01,duration)
		Variable gap=first-last
		if(i>0 && abs(gap)>seam_threshold)
			Concatenated[cum_points,]-=gap
		endif
		last=mean(theWave,0,0.01)
		cum_points+=numpnts(theWave)
	endfor
End

