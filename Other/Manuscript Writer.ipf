// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Manuscript%20Writer.ipf $
// $Author: rick $
// $Rev: 616 $
// $Date: 2012-12-05 14:46:20 -0700 (Wed, 05 Dec 2012) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=IMW

strconstant IMW=IMW
strconstant IMW_folder="root:Packages:Manuscript_Writer"
strconstant IMWfigNums="1;2;3;4;5;6;7;8;9;10;S1;S2;S3;S4;S5;S6;S7;S8;S9;S10"
strconstant IMWfigLetters="A;B;C;D;E;F;G;H;I;J"
strconstant IMWfigSubNums=";1;2;3;4;5;6;7;8;9"

Structure MarkerPrefs
	char name[10] // Usually just one letter.  
	Struct point coords
	Struct point loc
	double reserved[100]
EndStructure

Menu "More"
	"Manuscript Writer",/Q,DisplayFigureManager();DisplayManuscriptManager()
End

Function Init_IMW()
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:Packages
	NewDataFolder /O/S $IMW_folder
	NewDataFolder /O MarkerPrefs
	String /G free_fig_numbers=IMWfigNums
	String /G free_fig_letters=IMWfigLetters
	DoWindow /K $(IMW+"FigureManager")
	DisplayFigureManager()
	//DisplayManuscriptManager()
	SetDataFolder $curr_folder
End

// -------------------- Begin Manuscript Manager --------------------

Function DisplayManuscriptManager()
	String win_name=IMW+"ManuscriptManager"
	DoWindow /K $win_name
	NewDataFolder /O root:Packages
	NewDataFolder /O $IMW_folder
	NewPanel /N=$win_name /K=1 as "Manuscript Manager"
	Button New_Manuscript size={125,25}, proc=ManuscriptManagerButtons, title="New Manuscript"
	Button Export_Manuscript size={125,25}, proc=ManuscriptManagerButtons, title="Export Manuscript"
	Button Add_Figure pos={0,35}, size={100,25}, proc=ManuscriptManagerButtons, title="Add Figure"
	PopupMenu Figure_List size={150,25}, value=WinList("*",";","WIN:7")
	Button Add_Value pos={0,70}, size={100,25}, proc=ManuscriptManagerButtons, title="Add Value"
	Button Add_Reference pos={0,105}, size={100,25}, proc=ManuscriptManagerButtons, title="Add Reference"
	Button Update_All pos={0,140}, size={125,25}, proc=ManuscriptManagerButtons, title="Update Objects"
End

Function ManuscriptManagerButtons(ctrlName) : ButtonControl
	String ctrlName
	strswitch(ctrlName)
		case "New_Manuscript":
			NewManuscript()
			break
		case "Export_Manuscript":
			ExportManuscript()
			break
		case "Add_Figure":
			CreateObject("Figure")
			break
		case "Add_Value":
			CreateObject("Value")
			break
		case "Add_Reference":
			AddReference()
			break
		case "Update_All":
			UpdateAll()
			break
	endswitch
End

Function NewManuscript([name,title])
	String name,title
	if(ParamIsDefault(name) || ParamIsDefault(title))
		Prompt name, "Give a short name to your manuscript..."
		Prompt title, "Give a title to your manuscript..."
		DoPrompt "New Igor Manuscript", name, title
		if (V_Flag)
			return -1								// User canceled
		endif
	endif
	String curr_folder=GetDataFolder(1)
	SetDataFolder IMW_folder
	if(DataFolderExists(name))
		DoAlert 0,"You already have a manuscript in progress with that name."
		return -2
	endif
	String /G active_manuscript=name
	NewDataFolder /O/S $(IMW_folder+":"+name)
	NewNotebook /N=$name /F=1 as title
	SetDataFolder $curr_folder
End

Function ExportManuscript([name])
	String name
	if(ParamIsDefault(name))
		name=TopManuscript()
	else
		name=TopManuscript(name=name)
	endif
	SaveNotebook /I/S=2 $name
End

Function /S TopManuscript([name])
	String name
	String manuscripts=ManuscriptNames()
	if(ParamIsDefault(name))
		String notebooks=WinList("*",";","WIN:16")
		Variable i
		name=""
		for(i=0;i<ItemsInList(notebooks);i+=1)
			String notebook0=StringFromList(i,notebooks)
			if(WhichListItem(notebook0,manuscripts)>=0)
				name=notebook0
			endif
		endfor
	elseif(WhichListItem(name,manuscripts)<0)
		name=""
	endif
	return name
End

Function /S ManuscriptNames()
	Variable i
	Variable num_manuscripts=CountObjects(IMW_folder,4)
	String manuscripts=""
	for(i=0;i<num_manuscripts;i+=1)
		String manuscript=GetIndexedObjName(IMW_folder,4,i)
		manuscripts+=manuscript+";"
	endfor
	return manuscripts
End

Function AddReference()
	DoAlert 0, "Not yet implemented."
End

Function Reference() : ButtonControl
	String ctrlName
	//Execute /Q "CreateBrowser prompt=\"Choose an object to insert...\""
End

Function CreateObject(object_type)
	String object_type
	
	String manuscript=TopManuscript()
	String curr_folder=GetDataFolder(1)
	SetDataFolder IMW_folder
	
	strswitch(object_type)
		case "Figure":
			ControlInfo Figure_List
			String source1=S_Value
			String object_name="Figure_"+source1
			String object_folder=IMW_folder+":"+manuscript+":'"+object_name+"'"
			NewDataFolder /O/S $object_folder
			String /G source=source1
			String /G type="Figure"
			String /G commands="DoWindow /F "+source
			break
		case "Value":
			Execute /Q "CreateBrowser prompt=\"Choose an object to insert...\""
			NVar flag=$(IMW_folder+":V_flag")
			if(!flag)
				SetDataFolder $curr_folder
				return 0
			endif
			SVar S_BrowserList
			String object_loc=StringFromList(0,S_BrowserList)
			Variable object_depth=ItemsInList(object_loc,":")-1
			object_name=StringFromList(object_depth,object_loc,":")
			object_folder=IMW_folder+":"+manuscript+":'"+object_name+"'"
			NewDataFolder /O/S $object_folder
						
			String /G source=object_loc
			String /G type="Value"
			String /G commands=""
			break
	endswitch
	InsertObject(object_name)
	SetDataFolder $curr_folder
End

Function InsertObject(object_name)
	String object_name
	
	String manuscript=TopManuscript()
	String object_folder=IMW_folder+":"+manuscript+":"+object_name+":"
	String curr_folder=GetDataFolder(1)
	SetDataFolder $object_folder
	SVar object_type=type
	SVar object_source=source
	Svar object_commands=commands
	
	strswitch(object_type)
		case "Figure":
			SavePICT /WIN=$object_source as "Clipboard"
			LoadPICT /O/Q "Clipboard",$object_name
			NotebookAction /W=$manuscript name=$object_name, linkstyle=0, picture=$object_name, title=object_source, commands=object_commands
			break
		case "Value":
			// Need better code for checking variable type.  
			NVar /Z num_value=$object_source
			SVar /Z str_value=$object_source
			String object_value=""
			if(NVar_Exists(num_value))
				object_value=num2str(num_value)
			endif
			if(SVar_Exists(str_value))
				object_value=str_value
			endif
			// 
			NotebookAction /W=$manuscript name=$object_name, linkstyle=1, title=object_value, commands=object_commands
			break
	endswitch
	SetDataFolder $curr_folder
End

Function UpdateObject(object_name)
	String object_name
	String manuscript=TopManuscript()
	Notebook $manuscript selection={startOfFile,startOfFile}
	Notebook $manuscript findSpecialCharacter={object_name,1}
	InsertObject(object_name)
End

Function UpdateAll()
	//String curr_folder=GetDataFolder(1)
	String manuscript=TopManuscript()
	String manuscript_folder=IMW_folder+":"+manuscript
	Variable i,num_objects=CountObjects(manuscript_folder,4)
	for(i=0;i<num_objects;i+=1)
		String object_name=GetIndexedObjName(manuscript_folder, 4, i)
		//SVar type=$(manuscript_folder+":"+object_name+":type")
		UpdateObject(object_name)
	endfor
	//SetDataFolder $curr_folder
End

Function Cleanup()
End

// -------------------- Begin Figure Manager --------------------

Function DisplayFigureManager()
	String win_name=IMW+"FigureManager"
	DoWindow /K $win_name
	NewPanel /N=$win_name /K=1 /W=(100,100,500,300) as "Figure Manager"
	Variable left=8
	Variable top=30
	Variable x=left
	Variable y=top
	TitleBox SourcesTitle, pos={x-3,y-27}, title="Sources"
	GroupBox SourcesGroup, pos={x-3,y-5}, size={200,150}
	
	// Rename a figure that is not yet a part of the manuscript.  
	Button Add_Figure pos={x,y}, size={100,25}, proc=FigureManagerButtons, title="Add Figure"
	PopupMenu Add_Figure_List size={75,20}, value="From file;Blank;"+WinList("*",";","WIN:7"),proc=FigureManagerPopups
	y+=50
	
	// Change the number of an existing figure.  
	Button Change_Figure pos={x,y}, size={100,25}, proc=FigureManagerButtons, title="Change Figure #"
	PopupMenu Change_Figure_List size={75,20}, value=FigList()
	y+=50
	
	// Change the name/place of an existing figure panel. 
	Button Change_Panel pos={x,y}, size={100,25}, proc=FigureManagerButtons, title="Change Fig. Panel"
	PopupMenu Change_Panel_List size={75,20}, value=PanelList()
	y+=50
	
	x=left+250; y=top
	TitleBox DestsTitle, pos={x-3,y-27}, title="Destinations"
	GroupBox Dests, pos={x-3,y-3}, size={130,150}
	
	PopupMenu Number_List pos={x,y}, size={50,20}, value=IMWfigNums,proc=FigureManagerPopups
	PopupMenu Letter_List pos={x+45,y}, size={50,20}, value=IMWfigLetters
	
	y+=35
	Checkbox Clone pos={x,y}, title="Clone",proc=FigureManagerCheckboxes
	Checkbox Wedge pos={x+50,y}, title="Wedge",proc=FigureManagerCheckboxes
	y+=25
	Checkbox Swap, pos={x,y}, title="Swap",proc=FigureManagerCheckboxes
	Checkbox Delete, pos={x+50,y}, title="Delete",proc=FigureManagerCheckboxes
	
	y+=35
	Button SaveMarkerPrefs, pos={x,y}, size={95,20}, proc=FigureManagerButtons, title="Save Marker Prefs"
	Button LoadMarkerPrefs, pos={x,y+25}, size={95,20}, proc=FigureManagerButtons, title="Load Marker Prefs"
End

Function /S FigList()
	String figs=ListMatch(WinList("*",";","WIN:4"),"Fig*") // Layout starting with "Fig".  
	figs=SortFigs(figs)
	figs="Top Figure;"+figs
	return figs
End

Function /S PanelList()
	String panels=ListMatch(WinList("*",";","WIN:3"),"Fig*") // Graphs and tables starting with "Fig".  
	panels=SortFigs(panels)
	panels="Top Panel;"+panels
	return panels
End

Function /S SortFigs(figs)
	String figs
	
	String supplemental=ListMatch(figs,"FigS*")
	supplemental=SortList(supplemental,";",16)
	figs=RemoveFromList(supplemental,figs)
	figs=SortList(figs,";",16)
	figs+=supplemental
	return figs
End

Function FigureManagerButtons(ctrlName) : ButtonControl
	String ctrlName
	
	ControlInfo $(ctrlName+"_List"); String oldName=S_value
	strswitch(s_value)
		case "Top Figure":
			oldName=winname(0,4)
			break
		case "Top Panel":
			oldName=winname(0,1)
			break
	endswitch
	String old,oldN,oldL
	sscanf oldName,"Fig%s",old
	sscanf oldName,"Fig%[S0-9]%[a-zA-Z]",oldN,oldL
	ControlInfo Number_List; String newN=S_value
	ControlInfo Letter_List; String newL=S_value
	ControlInfo Clone; Variable clone=V_value
	ControlInfo Wedge; Variable wedge=V_Value
	ControlInfo Delete; Variable delete=V_Value
	
	strswitch(ctrlName)
		case "Add_Figure":
			strswitch(oldName)
				case "From file": // From file.  
					Execute /P/Q "MERGEEXPERIMENT "
					break
				case "Blank":
					oldName=""
					// no break to allow next command to execute.    
				default:
					// Consider saving a graph copy and then merging back in and putting the folder in the right place.
					AddFigure(oldName,newN)
			endswitch
			PopupMenu Figure_List value="From file;Blank;"+WinList("*",";","WIN:7") // Force the popup menu to refresh.  
			break
		case "Change_Figure":
			if(delete)
				DropFigure(oldN)
			elseif(wedge)
				WedgeFigure(oldN,newN)
			else
				ChangeFigNumber(oldN,newN,clone=clone)
			endif
			break
		case "Change_Panel":
			if(delete)
				DropPanel(oldN,oldL,fillGap=wedge)
			elseif(wedge)
				WedgePanel(oldN,oldL,newN,newL)
			else
				ChangePanelLetter(oldN+oldL,newN+newL,clone=clone)
			endif
			break
		case "SaveMarkerPrefs":
			SavePanelMarkerPrefs()
			break
		case "LoadMarkerPrefs":
			LoadPanelMarkerPrefs()
			break
	endswitch
End

Function FigureManagerPopups(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum	// which item is currently selected (1-based)
	String popStr		// contents of current popup item as string
	
	UpdateFigureManager()
End

Function FigureManagerCheckboxes(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked			// 1 if selelcted, 0 if not
	
	strswitch(ctrlName)
		case "Clone":
			Checkbox Swap value=CheckboxState("Swap")*!checked
			break
		case "Wedge":
			Checkbox Swap value=CheckboxState("Swap")*!checked
			break
		case "Swap":
			Checkbox Clone value=CheckboxState("Clone")*!checked
			Checkbox Wedge value=CheckboxState("Wedge")*!checked
			break
		case "Delete":
			Checkbox Clone value=CheckboxState("Clone")*!checked
			Checkbox Wedge value=CheckboxState("Wedge")*!checked, title=SelectString(checked,"Wedge","Collapse")
			Checkbox Swap value=CheckboxState("Swap")*!checked
			break
	endswitch
	
	UpdateFigureManager()
End

Function CheckboxState(ctrlName[,win])
	String ctrlName,win
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	ControlInfo /W=$win $ctrlName
	return V_Value 
End

Function UpdateFigureManager()
End

Function AddFigure(old_name,number)
	String old_name,number
	String name=number
	if(strlen(old_name))
		DoWindow /C /W=$old_name $("Fig"+name)
	else
		NewLayout /N=$("Fig"+name)
	endif
	SetWindow $("Fig"+name),userdata(ACL_desktopNum)=number
	printf "Please put all the data associated with this figure into folder root:Fig%d\r",number
End

Function AddPanel(old_name,number,letter)
	String old_name,number,letter
	String name=number+letter
	if(strlen(old_name))
		DoWindow /C /W=$old_name $("Fig"+name)
	else
		Display /N=$("Fig"+name)
		// Add some code for appending it to the layout and shifting the other panels around.  
	endif
	SetWindow $("Fig"+name),userdata(ACL_desktopNum)=number
	printf "Please put all the data associated with this panel into folder root:Fig%d:%d\r",number,letter
End

// Deletes the figure window (layout) and all associate panels (graphs and tables).  
Function DropFigure(N)
	String N
	
	DFRef currFolder=GetDataFolderDFR()
	DoWindow /K $("Fig"+N)
	DoAlert 1,"Would you also like to close the figure panels associated with this figure?"
	Variable dropPanels=(V_flag==1)
	if(!dropPanels)
		return 0
	endif
	DoAlert 1,"Would you also like to delete the data associated with this figure?"
	Variable dropData=(V_flag==1)	
	Variable i
	for(i=0;i<ItemsInList(IMWfigLetters);i+=1)
		String L=StringFromList(i,IMWfigLetters)
		DropPanel(N,L,dropData=dropData)
	endfor
	SetDataFolder currFolder
End

// Delete the figure panel (a graph or table).  
Function DropPanel(N,L[,dropData,fillGap])
	String N,L
	Variable dropData // Delete the data associated with this panel.  
	Variable fillGap // Fill the gap caused by dropping this panel, e.g. if "B" is dropped, then "C" becomes "B", "D" becomes "C", and so on.  
	
	Variable freezePanels=0
	
	DFRef currFolder=GetDataFolderDFR()
	DoWindow /K $("Fig"+N+L)
	if(ParamIsDefault(dropData))
		DoAlert 1,"Would you also like to delete the data associated with this figure?"
		dropData=(V_flag==1)	
	endif
	if(dropData)
		DFRef panelData=root:$("Fig"+N):$L
		if(DataFolderRefStatus(panelData))
			printf "Deleting %s%s.\r",N,L
			KillDataFolder /Z panelData
//			SetDataFolder panelData
//			KillRecurse("*")
//			KillDataFolder /Z panelData
		endif
	endif
	if(fillGap)
		// Handle figure and panels.  
		String figRec=WinRecreation("Fig"+N,0) // Copy figure layout.  
		Variable i,index=WhichListItem(UpperStr(L),IMWfigLetters)
		String renameList=""
		for(i=index+1;i<ItemsInList(IMWfigLetters);i+=1)
			String oldL="Fig"+N+StringFromList(i,IMWFigLetters)
			String newL="Fig"+N+StringFromList(i-1,IMWFigLetters)
			if(WinType(oldL))
				DoWindow /W=$oldL /C $newL
				if(freezePanels) // Freeze the panels in their current positions instead of letting them get bumped around by the renaming process.  
					figRec=ReplaceString(oldL,figRec,newL)
				endif
			else
				break
			endif
		endfor
		DoWindow /K $("Fig"+N)
		Execute /Q figRec // Regenerate figure layout.  
	
		// Handle data folders.  
		DFRef oldFolder=root:$("Fig"+N):$L
		if(DataFolderRefStatus(oldFolder))
			return 0
		endif
		for(i=index+1;i<ItemsInList(IMWfigLetters);i+=1)
			oldL=StringFromList(i,IMWfigLetters)
			newL=StringFromList(i-1,IMWfigLetters)
			DFRef oldFolder=root:$("Fig"+N):$oldL
			if(DataFolderRefStatus(oldFolder))
				RenameDataFolder oldFolder $newL
			endif
		endfor
	endif
	SetDataFolder currFolder
End

static Function FigCount()
	Variable i,numFigs=0
	String taken_fig_numbers=""
	for(i=0;i<CountObjectsDFR(root:,4);i+=1)
		String folder=GetIndexedObjNameDFR(root:,4,i)
		if(StringMatch(folder,"Fig*"))
			numFigs+=1
		endif
	endfor
	return numFigs
End

Function /S FreeFigNumbers()
	String freeFigNums=""
	Variable i,numFigs=FigCount(),takenFigNums
	
	// Make a list of available, figure numbers.  
	Do
		String possibleFigNum=StringFromList(i,IMWfigNums)	
		if(!DataFolderExists("root:Fig"+possibleFigNum))
			 freeFigNums+=possibleFigNum+";"
			 if(takenFigNums>=numFigs)
			 	break
			 endif
		else
			takenFigNums+=1
		endif
		i+=1
	While(i<ItemsInList(IMWfigNums))
	
	return freeFigNums
End

Function /S FreeFigLetters(fig_number)
	String fig_number
	Variable i
	String free_fig_letters=IMWfigLetters
	for(i=0;i<CountObjects("root:Fig"+fig_number,4);i+=1)
		String folder=GetIndexedObjName("root:",4,i)
		if(WhichListItem(folder,IMWfigLetters)>=0)
			free_fig_letters=RemoveFromList(folder,free_fig_letters)
		endif
	endfor
	return free_fig_letters
End

Function WedgeFigure(old,new)
	String old,new
	ChangeFigNumber(old,"0") // Temporarily change to zero so that the old number is freed up for the shuffling of figures.  
	String free=FreeFigNumbers()
	String next=new
	Do // Find the first free number going up starting from 'number'
		next=Number2FigNumberStr(FigNumberStr2Number(next)+1)
	While(WhichListItem(next,free)<0)
	Do // Go back down from the free number and bump each figure up by one number.  
		String nextFree=next
		next=Number2FigNumberStr(FigNumberStr2Number(next)-1)
		ChangeFigNumber(next,nextFree)
	While(FigNumberStr2Number(next)>FigNumberStr2Number(new))
	ChangeFigNumber("0",next) // Finally assign the figure its new number.  
End

Function WedgePanel(oldN,oldL,newN,newL)
	String oldN,oldL,newN,newL
	ChangePanelLetter(oldN+oldL,newN+"0") // Temporarily change to zero so that the old letter is freed up for the shuffling of figures.  
	String free=FreeFigLetters(newN)
	String nextL=newL
	Variable index=WhichListItem(nextL,free)+1
	nextL=StringFromList(index,IMWfigLetters)  // Find the first free letter going up starting from 'letter'
	Do // Go back down from the free letter and bump each figure up by one letter.  
		String nextFree=nextL
		index=WhichListItem(nextL,free)-1
		nextL=StringFromList(index,IMWfigLetters)
		ChangePanelLetter(newN+nextL,newN+nextFree)
	While(index>WhichListItem(nextL,newL))
	ChangePanelLetter(newN+"0",newN+nextL) // Finally assign the figure its new letter.  
End

// Converts a figure number, which is actually a string and could have letters in it, to a numeric equivalent.  
// e.g. "S12" becomes 83012.  
Function FigNumberStr2Number(fig_number)
	String fig_number
	String prefix; Variable number
	number=str2num(fig_number)
	if(numtype(number)==0)
		return number
	else
		sscanf fig_number,"%[^0-9]%d",prefix,number
		return char2num(prefix)*1000+number
	endif
End

// Converts a numeric code produced by FigNumberStr2Number back into a figure number (which is actually a string).    
Function /S Number2FigNumberStr(number)
	Variable number
	if(number<100)
		return num2str(number)
	endif
	String fig_number=num2str(number)
	Variable prefix=str2num(fig_number[0,1])
	Variable suffix=str2num(fig_number[2,strlen(fig_number)-1])
	return num2char(prefix)+num2str(suffix)
End


// Updates layout/figure/folder names according to the new figure number.  
// If there is already a figure with the new number, it will be changed to the old number (swapped).  
// This is for changing whole figures.  To change figure panels only, use ChangePanelLetter()
Function ChangeFigNumber(old,new[,clone,wedge,swap])
	String old,new
	Variable clone // Clone the figure instead of just changing the number.  Two figures will then be identical.  
	Variable wedge // Wedge a figure in between two figures and renumber accordingly.  
	Variable swap // Swaps old and new figure numbers.   
	
	if(!WinType("Fig"+old))
		DoAlert 0,"No such window: Fig"+old
		return 1
	endif
	if(WinType("Fig"+new) && clone && !wedge && !swap)
		DoAlert 0,"There is already a Figure "+new
		return 2
	endif
	
	// Reassign the figure components that currently use the new number (if any) a temporary number.  
	String unique_name=""
	if(WinType("Fig"+new))
		unique_name=UniqueName("Fig"+old,8,1000)
		ChangeFigNumber(new,unique_name)
		if(wedge)
			WedgeFigure(old,new)
			return 0
		endif
	endif
	
	// Update names of folders containing figure data.  
	if(clone)
		DuplicateDataFolder root:$("Fig"+old) root:$("Fig"+new)
	else
		RenameDataFolder root:$("Fig"+old) $("Fig"+new)
	endif
	
	// Assign the the new number to the layout using the old number.  
	String win_rec=WinRecreation("Fig"+old,0)
	win_rec=ReplaceString("Fig"+old,win_rec,"Fig"+new)
	Execute /Q win_rec
	GetWindow $("Fig"+new), title; String title=S_Value
	title=ReplaceString("Figure "+old,title,"Figure "+new)
	DoWindow /T $("Fig"+new) title
	PrintSettings /W=$("Fig"+new) copySource=$("Fig"+old)
	if(!clone)
		DoWindow /K $("Fig"+old)
	endif
	String desktop=SelectString(StringMatch(new[0],"S"), new, num2str(10+str2num(new[1,Inf])))
	SetWindow $("Fig"+new),userdata(ACL_desktopNum)=desktop

	// Assign the the new number to the graphs using the old number.  
	Variable i,j
	for(i=0;i<ItemsInList(IMWfigLetters);i+=1)
		string letter=StringFromList(i,IMWfigLetters)
		for(j=0;j<itemsinlist(IMWfigSubNums);j+=1)
			string subNum=stringfromlist(j,IMWfigSubNums)
			string oldFigName="Fig"+old+letter+subNum
			string newFigName="Fig"+new+letter+subNum
			if(wintype(oldFigName))
				GetWindow $oldFigName, title; title=S_Value
				if(clone)
					CloneWindow(win=oldFigName,replace="Fig"+old,with="Fig"+new)
					//DoWindow /C $("Fig"+new+letter)
				else
					// Igor automatically updated trace locations in graphs when the folder names changed above.  
					DoWindow /C/W=$oldFigName $newFigName
				endif
				title=ReplaceString("Figure "+old+letter+subNum,title,"Figure "+new+letter+subNum)
				SetWindow $newFigName,userdata(ACL_desktopNum)=desktop
			endif
		endfor
	endfor
	
	// Reassign the figure components currently using the temporary number (if any) the old number.  
	if(strlen(unique_name))
		ChangeFigNumber(unique_name,old)
	endif
	return 0
End

// Kills the layout, graphs, and folder associated with a figure.  
Function KillFigure(num[,preserve_data])
	Variable num // The figure number.  
	Variable preserve_data // Don't kill the folder.  
	String numm=num2str(num)
	DoWindow /K $("Fig"+numm)
	Variable i
	for(i=0;i<ItemsInList(IMWfigLetters);i+=1)
		String letter=StringFromList(i,IMWfigLetters)
		DoWindow /K $("Fig"+numm+letter)
	endfor
	KillDataFolder /Z root:$("Fig"+numm)
End

// Inserts a figure panel into the appropriate spot based on an existing letter textbox or the user's preferences about the position of figure panels.  
Function InsertFigurePanel(figure_num,letter)
	String figure_num,letter
	Preferences 1
	String fig_panel_name="Fig"+figure_num+letter
	String type=WinTypeStr(fig_panel_name)
	AppendLayoutObject /W=$("Fig"+figure_num) $type $(fig_panel_name)
	Variable left,top
	Variable marker_exists=PanelMarker(figure_num,letter,left,top)
	if(!marker_exists)
		Textbox /W=$("Fig"+figure_num) /A=LT /X=(left) /Y=(top) /N=$letter letter	
	endif
	// Get coordinates for panel from the textbox.  
	String info=AnnotationInfo("Fig"+figure_num,letter)
	Variable x_offset=1,y_offset=1 // [TODO] Add a setting for the spacing (x and y) between the figure panel letter and the panel itself.  
	left=NumberByKey("ABSX",info)+x_offset
	top=NumberByKey("ABSY",info)+y_offset
	ModifyLayout left($fig_panel_name)=left, top($fig_panel_name)=top
	// Revise to handle pushing other figures panels up by one.  
End

// Adds markers (such as letters) to the graphs or tables in 'panels' or to the selected objects.  
Function AddPanelMarkers([figName,panels,markers])
	String figName,panels,markers
	if(ParamIsDefault(figName))
		figName=TopLayout()
	endif
	if(ParamIsDefault(panels))
		panels=SelectedPanels(figName)
	endif
	Variable i
	for(i=0;i<ItemsInList(panels);i+=1)
		String panelName=UpperStr(StringFromList(i,panels))
		if(ParamIsDefault(markers))
			String marker=panelName[strlen(panelName)-1,strlen(panelName)-1]
		else
			marker=StringFromList(i,markers)
		endif
		Struct rect coords
		PanelCoords(figName,panelName,coords)
		TextBox /C/N=$marker /A=LT/F=0 /B=1 /X=(coords.left) /Y=(coords.top) "\Z18\f01"+marker
		ModifyLayout left($marker)=coords.left, top($marker)=coords.top
	endfor
End

Function PanelCoords(figName,panelName,coords)
	String figName,panelName
	Struct rect &coords
	String panelInfo=LayoutInfo(figName,panelName)
	coords.left=NumberByKey("LEFT",panelInfo)
	coords.top=NumberByKey("TOP",panelInfo)
	print coords.left,coords.top
End

Function /S SelectedPanels(figName)
	String figName
	
	String panels=""
	String indexStr
	Variable index = 0
	Do
		sprintf indexStr, "%d", index
		String info = LayoutInfo(figName, indexStr)
		if (strlen(info) == 0)
			break			// No more objects
		endif

		Variable selected = NumberByKey("SELECTED", info)
		if (selected)
			String objectTypeStr = StringByKey("TYPE", info)
			if (CmpStr(objectTypeStr,"Graph") == 0 || CmpStr(objectTypeStr,"Table") == 0)		// This is a graph or table?
				String panelNameStr = StringByKey("NAME", info)
				panels+=panelNameStr+";"
			endif
		endif
		
		index += 1
	While(1)
	return panels
End

// Gets the position settings for a figure panel marker (panel letter) based on the existing marker or on user preferences.  
Function PanelMarker(fig,marker,left,top)
	String fig,marker // The marker is usually a letter describing a figure panel, like "A".  
	Variable &left,&top 
	fig="Fig"+fig
	String annotations=AnnotationList(fig)
	if(WhichListItem(marker,annotations)>=0)
		String info=AnnotationInfo(fig,marker)
	else
		info=""
	endif
	if(strlen(info))
		left=NumberByKey("ABSX",info)
		top=NumberByKey("ABSY",info)
		return 1
	else
		Struct MarkerPrefs MarkerPrefs
		SVar markerPrefStr=$(IMW_Folder+":MarkerPrefs:"+marker)
		StructGet /S/B=0 MarkerPrefs, markerPrefStr
		left=MarkerPrefs.coords.h
		top=MarkerPrefs.coords.v
		return 0
	endif
End

// Saves the locations of the markers (letters) for each panel of layout 'fig' in the preferences.  
Function SavePanelMarkerPrefs([fig])
	String fig
	if(ParamIsDefault(fig))
		fig=WinName(0,4) // Top layout.  
	endif
	String annotations=AnnotationList(fig)
	Variable i
	for(i=0;i<ItemsInList(annotations);i+=1)
		String annotation=StringFromList(i,annotations) // May or may not be a marker.  
		// Add checking to see that it is a marker, for example by adding user data to the layout with the addition of each marker.  
		String info=AnnotationInfo(fig,annotation)
		String type=StringByKey("TYPE",info)
		if(StringMatch(type,"TEXTBOX"))
			Struct MarkerPrefs MarkerPrefs
			MarkerPrefs.coords.h=NumberByKey("X",StringByKey("FLAGS",info),"=","/") // Get /X flag.  
			MarkerPrefs.coords.v=NumberByKey("Y",StringByKey("FLAGS",info),"=","/") // Get /Y flag.  
			String marker=StringByKey("TEXT",info)
			marker=CleanupName(marker,0)
			String /G $(IMW_Folder+":MarkerPrefs:"+marker)
			SVar markerPrefStr=$(IMW_Folder+":MarkerPrefs:"+marker)
			StructPut /S/B=0 MarkerPrefs,markerPrefStr
			//StructPut /S/B=0 pt, default_marker_loc
			Variable index=WhichListItem(marker,IMWfigLetters)
			if(index>=0)
				SavePackagePreferences /FLSH=1 "IgorManuscriptWriter", "markerPrefs.bin", index, MarkerPrefs 
			endif
		endif
	endfor
End

// Saves the locations of the markers (letters) for each panel of layout 'fig' in the preferences.  
Function LoadPanelMarkerPrefs([fig])
	String fig
	if(ParamIsDefault(fig))
		fig=WinName(0,4) // Top layout.  
	endif
	String annotations=AnnotationList(fig)
	Variable i
	for(i=0;i<ItemsInList(annotations);i+=1)
		String annotation=StringFromList(i,annotations) // May or may not be a marker.  
		// Add checking to see that it is a marker, for example by adding user data to the layout with the addition of each marker.  
		String info=AnnotationInfo(fig,annotation)
		String type=StringByKey("TYPE",info)
		if(StringMatch(type,"TEXTBOX"))
			Struct MarkerPrefs MarkerPrefs
			String marker=StringByKey("TEXT",info)
			marker=CleanupName(marker,0)
			String /G $(IMW_Folder+":MarkerPrefs:"+marker)
			SVar markerPrefStr=$(IMW_Folder+":MarkerPrefs:"+marker)
			Variable index=WhichListItem(marker,IMWfigLetters)
			if(index>=0)
				LoadPackagePreferences "IgorManuscriptWriter", "markerPrefs.bin", index, MarkerPrefs 
			endif
			StructPut /S/B=0 MarkerPrefs,markerPrefStr
		endif
	endfor
End

// Returns 1 if the panel is in the figure, or 0 if it is not.  
Function PanelInFigure(panel,figure)
	String panel,figure
	String info=LayoutInfo(figure,panel)
	return (strlen(info)>0)
End

// For changing the graph, folder, and layout associated with one figure panel.  
// For changing entire figures, use ChangeFigNumber().  
Function ChangePanelLetter(old,new[,clone,wedge,swap])
	String old,new // e.g. "6e" and "6g"
	Variable clone // Clone the figure instead of just changing the number.  
	Variable wedge,swap
	
	String oldN=old[0,strlen(old)-2]
	String newN=new[0,strlen(new)-2]
	String oldL=old[strlen(old)-1]
	String newL=new[strlen(new)-1]
	
	if(!WinType("Fig"+old))
		DoAlert 0,"No such window: Fig"+old
		return 1
	endif
	if(WinType("Fig"+new) && clone && !wedge && !swap)// && ItemsInList(GetRTStackInfo(0))<=1)
		DoAlert 0,"There is already a Figure "+new
		return 2
	endif
	
	// Reassign the figure components that currently use the new number (if any) a temporary number.  
	String unique_name=""
	if(WinType("Fig"+new))
		unique_name=newN+"_"
		ChangePanelLetter(new,unique_name)
		if(wedge)
			WedgePanel(oldN,oldL,newN,newL)
			return 0
		endif
	endif
	
	// Update names of folders containing figure data.  
	//sscanf old,"%d%s",oldN,oldL
	//sscanf new,"%d%s",newN,newL
	String old_folder_name="root:Fig"+oldN+":"+PossiblyQuoteName(oldL)
	String new_folder_name="root:Fig"+newN+":"+PossiblyQuoteName(newL)
	NewDataFolder /O $("root:Fig"+newN)
	if(clone)
		DuplicateDataFolder $old_folder_name,$new_folder_name
	else
		// Reroute through IMW_Folder to avoid name collision.  
		MoveDataFolder $old_folder_name,$(IMW_Folder+":")
		RenameDataFolder $(IMW_Folder+":"+PossiblyQuoteName(oldL)) $UpperStr(newL)
		MoveDataFolder $(IMW_Folder+":"+PossiblyQuoteName(newL)),$RemoveEnding(new_folder_name,PossiblyQuoteName(newL))
		// Only doing this because it is safer than DuplicateDataFolder followed by KillDataFolder.  
	endif
	
	// Assign the the new name to the graph/panel itself.  
	if(clone)
		String replace="Fig"+oldN+":"+oldL
		replace+=";Fig"+oldN+oldL
		String with="Fig"+newN+":"+newL
		with+=";Fig"+newN+newL
		CloneWindow(win="Fig"+old,replace=replace,with=with)
	else
		DoWindow /C/W=$("Fig"+old) $("Fig"+new)
	endif
	GetWindow $("Fig"+new), title; String title=S_Value
	title=ReplaceString("Figure "+old,title,"Figure "+new)
	SetWindow $("Fig"+new),userdata(ACL_desktopNum)=newN
	
	// Update the layout (figure) containing this figure panel (graph) so that it knows its new name.    
	// ---Currently does not support moving figure panels across different figures.  
	if(StringMatch(oldN,newN) && ItemsInList(GetRTStackInfo(0))<=10) // Same layout and not in the middle of recursion.  
		String win_rec=WinRecreation("Fig"+oldN,0)
		win_rec=ReplaceString("Fig"+old,win_rec,"Fig"+new)
		DoWindow /K $("Fig"+oldN)
		Execute /Q win_rec
		PrintSettings /W=$("Fig"+oldN) copySource=$("Fig"+oldN)
	endif
	
	// Reassign the figure components currently using the temporary number (if any) their old number.  
	if(strlen(unique_name))
		ChangePanelLetter(unique_name,oldN+oldL)
	endif
	
	Preferences 1
	if(!WinType("Fig"+newN))
		NewLayout /N=$("Fig"+newN)
	endif
	if(ItemsInList(GetRTStackInfo(0))<=2) // Not in the middle of recursion.  
		if(!PanelInFigure("Fig"+new,"Fig"+newN)) // The panel is not yet in the figure.  
			String type=WinTypeStr("Fig"+new)
			string oldInfo=LayoutInfo("Fig"+oldN,"Fig"+old) 
			variable width=NumberByKey("WIDTH",oldInfo)
			variable height=NumberByKey("HEIGHT",oldInfo)
			AppendLayoutObject /W=$("Fig"+newN) $type $("Fig"+new)
			ModifyLayout /W=$("Fig"+newN) frame($("Fig"+new))=0, trans($("Fig"+new))=1
			ModifyLayout /W=$("Fig"+newN) width($("Fig"+new))=width, height($("Fig"+new))=height
			RemoveLayoutObjects /W=$("Fig"+oldN) /Z $("Fig"+old)
			// *** Need to add letters when a new figure panel is added. ***  
		endif
	endif
	
	return 0
End

Function /S WinTypeStr(win)
	String win
	Variable type=WinType(win)
	switch(type)
		case 1:
			return "graph"
		case 2:
			return "table"
		case 3:
			return "layout"
		case 4:	
			return "notebook"
		case 7:	
			return "panel"
	endswitch
	return ""
End

// ***** Replace all instances of WinExist with WinType *****

Function ExportFigs([res,format,winPrefixes,oneFile,chapter,path,printt,labell])
	Variable res // Resolution in dpi.  
	variable printt // Prints in addition to saving.  
	string format // jpg, pdf, etc.  
	string winPrefixes
	variable oneFile // Export all figures in one file by placing them in a notebook.    
	String chapter // Which chapter (only relevant for theses, books, etc.)
	String path // Named path to which files will be saved.  
	variable labell // Add a label to each figure.  
	
	res=ParamIsDefault(res) ? 144 : res
	if(paramisdefault(format))
		format="pdf"
	endif
	winPrefixes=selectstring(!paramisdefault(winPrefixes),"Fig:Fig. ;FigS: Fig. S",winPrefixes)
	strswitch(format)
		case "eps":
			variable formatNum=-3
			break
		case "png":
			formatNum=-5
			break
		case "jpg":
			formatNum=-6
			break
		case "tif":
			formatNum=-7
			break
		case "pdf":
			formatNum=-8
			break
		default:
			formatNum=-6
			break
	endswitch
	if(ParamIsDefault(chapter))
		chapter=""
	else
		chapter+="."
	endif
	if(ParamIsDefault(path))
		NewPath /O/Q Desktop,SpecialDirPath("Desktop",0,0,0)
		path="Desktop"
	endif
	
	if(oneFile)
		NewNotebook /N=tempNotebook /F=1
	endif
	Variable i,j
	for(j=0;j<itemsinlist(winPrefixes);j+=1)
		string winPrefix=stringfromlist(j,winPrefixes)
		string winTitle=stringfromlist(1,winPrefix,":")
		winPrefix=stringfromlist(0,winPrefix,":")
		for(i=1;i<=10;i+=1)
			String win=winPrefix+num2str(i)
			if(WinType(win))
				if(labell)
					Textbox /W=$win /A=RB /C /T=1 /F=0 /X=0 /Y=0 /N=Title winTitle+num2str(i)
				endif
				if(oneFile)
					Notebook tempNotebook, picture={$win,0,1}
				else
					SavePICT /B=(res) /N=$win /O/P=$path /E=(formatNum) as winPrefix+chapter+num2str(i)+"."+format
				endif
				if(printt)
					PrintLayout $win
				endif
				if(labell)
					Textbox /W=$win /K/N=Title
				endif
			endif
		endfor
	endfor
	if(oneFile)
		SaveNotebook /P=$path tempNotebook 
		DoWindow /K tempNotebook
	endif
End

Function ExportThumbs()
	NewPath /O/C/Q ThumbsPath,SpecialDirPath("Desktop",0,0,0)+":Thumbs"
	ExportFigs(res=72,path="ThumbsPath")
End

// Used for appending figures panels to a layout.  
Function AppendFig(figNum)
	Variable figNum
	String panels=WinList("Fig"+num2str(figNum)+"*",";","WIN:1")
	Variable i
	for(i=0;i<ItemsInList(panels);i+=1)
		String panel=StringFromList(i,panels)
		AppendLayoutObject /T=1 /F=0 graph $panel
	endfor
End

// ----------------------- Begin Project Manager --------------------------


