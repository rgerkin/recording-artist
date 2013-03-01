// $URL: svn://churro.cnbc.cmu.edu/igorcode/IgorExchange/Dependency_Analyzer.ipf $
// $Author: rick $
// $Rev: 607 $
// $Date: 2012-04-24 22:56:02 -0400 (Tue, 24 Apr 2012) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1.02
#pragma IndependentModule=DependencyAnalyzer

// Changes since 1.01:
// Made into an IndependentModule.  Only scans functions in the ProcGlobal module, i.e. not in a named module.  

static constant min_listbox_size=50

Menu "Analysis"
	"Analyze Procedure Dependencies",/Q,InitDependencyAnalyzer()
End

Function InitDependencyAnalyzer()
	DoWindow /K DependencyAnalyzerPanel
	NewDataFolder /O root:Packages
	NewDataFolder /O/S root:Packages:DependencyAnalyzer
	String /G all_procedures=WinList("*",";","WIN:128")
	NewPanel /K=1/N=DependencyAnalyzerPanel/W=(100,100,550,505) as "Dependency Analyzer"
	SelectProcFiles()
End

Function SelectProcFiles()
	SetDataFolder root:Packages:DependencyAnalyzer
	SVar all_procedures
	Make /o/T/n=(ItemsInList(all_procedures)) AllProcs=StringFromList(p,all_procedures)
	Make /o/n=(numpnts(AllProcs)) ProcSelections1,ProcSelections2
	SetDrawEnv textxjust=1,save
	DrawText 225,20,"Check to see if functions from..."
	SetDrawEnv fstyle=4
	DrawText 100,50,"These procedure files"
	DrawText 225,50,"call functions from"
	SetDrawEnv fstyle=4
	DrawText 350,50,"These procedure files"
	
	ListBox Callers pos={25,55},size={150,320},listWave=AllProcs,selWave=ProcSelections1,mode=4
	ListBox Callees pos={275,55},size={150,320},listWave=AllProcs,selWave=ProcSelections2,mode=4
	ProcSelections1=1 // Select All
	ProcSelections2=1 
	Button SelectAll1 pos={55,380},size={80,20},title="Select All",proc=SelectProcFilesButtons
	Button SelectAll2 pos={305,380},size={80,20},title="Select All",proc=SelectProcFilesButtons
	Button Compute pos={185,200},size={80,20},title="Compute",proc=SelectProcFilesButtons
	Button HelpMain pos={210,350},size={30,20},title="?",proc=HelpFilesButtons
	Checkbox SortCounts pos={188,225}, value=1, title="Sort Results"
End

Function ComputeDependencies([dependsOn,dependedOn,sort_results])
	String dependsOn,dependedOn
	Variable sort_results
	SetDataFolder root:Packages:DependencyAnalyzer
	SVar all_procedures
	if(ParamIsDefault(dependsOn))
		dependsOn=all_procedures
	endif
	if(ParamIsDefault(dependedOn))
		dependedOn=all_procedures
	endif
	
	String selected_procedures=""
	AddUniqueItems2List(dependsOn,selected_procedures)
	AddUniqueItems2List(dependedOn,selected_procedures)	
	Make /o/T/n=(ItemsInList(selected_procedures)) SelectedProcs=StringFromList(p,selected_procedures)
	Make /o/T/n=0 AllFunctions=""
	Variable num_proc_files=ItemsInList(selected_procedures)
	
	// Get a list of functions defined in each of the selected procedure files.  
	Variable i,j
	for(i=0;i<num_proc_files;i+=1)
		String proc_file=StringFromList(i,selected_procedures)
		//String cmd="print num2str(3)+FunctionList(\"*\",\";\",\"WIN:"+proc_file+"\")"
		//Execute cmd
		//print cmd
		String defined_functions=FunctionList("*",";","WIN:"+proc_file+" [ProcGlobal]")
		proc_file=CleanupName("PF_"+RemoveEnding(proc_file,".ipf"),1)
		Make /o/T/n=(ItemsInList(defined_functions)) $proc_file=StringFromList(p,defined_functions)
		Concatenate /NP/T {$proc_file}, AllFunctions
	endfor
	
	// Get a list of functions used in each procedure file.  
	Variable num_depends=ItemsInList(dependsOn)
	Variable num_depended=ItemsInList(dependedOn)
	Make /o/n=(num_depends,num_depended) DependencyCounts=NaN
	Make /o/T/n=(num_depends,num_depended) DependencyDetails=""
	string /g DotLanguage=""
	SetDrawLayer /W=DependencyAnalyzerPanel /K ProgBack
	DrawText /W=DependencyAnalyzerPanel 215,255,"0%"
	DoUpdate
	ColorTab2Wave Rainbow; wave M_Colors
	variable red,green,blue
	for(i=0;i<num_depends;i+=1)
		String proc_file1=StringFromList(i,dependsOn)
		proc_file1=CleanupName(RemoveEnding(proc_file1,".ipf"),1)
		red=floor(M_Colors[100*i/num_depends][0]/256)
		green=floor(M_Colors[100*i/num_depends][1]/256)
		blue=floor(M_Colors[100*i/num_depends][2]/256)
		string line=""
		sprintf line,"edge[color=\"#%.2X%.2X%.2X\"];",red,green,blue
		DotLanguage+=line
		for(j=0;j<num_depended;j+=1)
			String proc_file2=StringFromList(j,dependedOn)
			proc_file2=CleanupName(RemoveEnding(proc_file2,".ipf"),1)
			Variable count=0
			String details=""
			DependencyCount(proc_file1,proc_file2,count,details)
			DependencyCounts[i][j]=count
			DependencyDetails[i][j]=details
			if(count>0 && cmpstr(proc_file1,proc_file2))
				sprintf line,"edge[penwidth=%.2f];",1+ln(count)
				DotLanguage+=line
				line=proc_file1+">"+proc_file2+";"
				line=replacestring("-",line,"_")
				line=replacestring(" ",line,"_")
				line=replacestring(">",line," -> ")
				DotLanguage+=line
			endif
		endfor
		SetDrawLayer /W=DependencyAnalyzerPanel /K ProgBack
		DrawText /W=DependencyAnalyzerPanel 215,255,num2str(round((i+1)*100/num_depends))+"%"
		DoUpdate
	endfor
	
	SortDependencies(dependsOn,dependedOn,sort_results)
	DisplayDependencies()
End

Function AddUniqueItems2List(items,list)
	String items, &list
	Variable i
	for(i=0;i<ItemsInList(items);i+=1)
		String item=StringFromList(i,items)
		if(WhichListItem(item,list)<0)
			list+=item+";"
		endif
	endfor
End

Function DependencyCount(proc_file1,proc_file2,dependency_count,dependency_list)
	String proc_file1,proc_file2
	Variable &dependency_count
	String &dependency_list
	
	dfref df=root:Packages:DependencyAnalyzer
	Wave /T DefinedFunctions1=df:$("PF_"+proc_file1)
	Wave /T DefinedFunctions2=df:$("PF_"+proc_file2)
	Variable i,j
	for(i=0;i<numpnts(DefinedFunctions1);i+=1) // For each function defined by the first procedure file.  
		String defined_function1=DefinedFunctions1[i]
		String function_text=ProcedureText("ProcGlobal#"+defined_function1,0)
		Make /free/T/n=(ItemsInList(function_text,"\r")) FunctionText=StringFromList(p,function_text,"\r")
		DeletePoints 0,1,FunctionText // Exclude function title.  
		// Exclude comments.  
		for(j=0;j<numpnts(FunctionText);j+=1)
			variable commentStart=strsearch(FunctionText[j],"//",0)
			if(commentStart>=0)
				FunctionText[j]=(FunctionText[j])[0,commentStart]
			endif
		endfor
		// Find number of calls to functions defined by the second procedure file.   
		for(j=0;j<numpnts(DefinedFunctions2);j+=1)
			String defined_function2=DefinedFunctions2[j]
			Make /o/T/n=0 MatchingLines
		// Find lines in function1 containing the name of function2.  This narrows down the search considerably.   
			Grep /E=(defined_Function2) FunctionText as $"MatchingLines"
			MatchingLines=replacestring("\t",MatchingLines,"")
		// Find lines in function1 containing actual calls of function2.  This is a computationally expensive search, per line.  
			string grep_str="^"+defined_function2+"\(|[=,\$\[\{\(]"+defined_function2+"\("
			Grep /E=(grep_str) MatchingLines as $"MatchingLines"	
			Variable called=numpnts(MatchingLines)>0
			dependency_count+=called
			if(called)
				dependency_list+=defined_function1+" calls "+defined_function2+";"
			endif
		endfor
	endfor
	KillWaves /Z FunctionText//,MatchingLines
	return 1
End

Function /s QuickDependencyList(proc_file1,proc_file2)
	string proc_file1,proc_file2
	string dependency_list=""
	variable dependency_count=0
	DependencyCount(proc_file1,proc_file2,dependency_count,dependency_list)
	print dependency_count
	return  dependency_list
End

Function SortDependencies(depends_On,depended_On,do_sort)
	String depends_On,depended_On
	Variable do_sort
	Wave DependencyCounts
	Wave /T DependencyDetails
	Variable i,num_depends=ItemsInList(depends_On),num_depended=ItemsInList(depended_On)
	
	// Depended on.  
	Make /o/n=(num_depended) NumDependencies=NaN,DependencyIndex=p
	WaveStats /Q/M=1 DependencyCounts
	Variable total_depend=V_avg*V_npnts
	for(i=0;i<num_depended;i+=1)
		Duplicate /o/R=[][i,i] DependencyCounts $"DependedOn"; Wave DependedOn
		Redimension /n=(numpnts(DependedOn)) DependedOn
		Variable tiebreak=sum(DependedOn)/(total_depend-DependedOn[i])
		DependedOn=DependedOn>0
		DeletePoints i,1,DependedOn // Don't count self.  
		NumDependencies[i]=sum(DependedOn)+tiebreak
	endfor
	if(do_sort)
		Sort /R NumDependencies,DependencyIndex
	endif
	String sorted_procedures=""
	for(i=0;i<ItemsInList(depended_on);i+=1)
		sorted_procedures+=StringFromList(DependencyIndex[i],depended_on)+";"
	endfor
	MatrixSort(DependencyCounts,1,DependencyIndex)
	LabelDependencies(DependencyCounts,sorted_procedures,1)
	TextMatrixSort(DependencyDetails,1,DependencyIndex)
	LabelDependencies(DependencyDetails,sorted_procedures,1)
	
	// Depends on.  
	Make /o/n=(num_depends) NumDependencies=NaN,DependencyIndex=p
	for(i=0;i<num_depends;i+=1)
		Duplicate /o/R=[i,i][] DependencyCounts $"DependOn"; Wave DependOn
		Redimension /n=(numpnts(DependOn)) DependOn
		tiebreak=sum(DependOn)/(total_depend-DependOn[i])
		DependOn=DependOn>0
		DeletePoints i,1,DependOn // Don't count self.  
		NumDependencies[i]=sum(DependOn)+tiebreak
	endfor
	if(do_sort)
		Sort /R NumDependencies,DependencyIndex
	endif
	sorted_procedures=""
	for(i=0;i<ItemsInList(depends_on);i+=1)
		sorted_procedures+=StringFromList(DependencyIndex[i],depends_on)+";"
	endfor
	MatrixSort(DependencyCounts,0,DependencyIndex)
	LabelDependencies(DependencyCounts,sorted_procedures,0)
	TextMatrixSort(DependencyDetails,0,DependencyIndex)
	LabelDependencies(DependencyDetails,sorted_procedures,0)
	KillWaves /Z NumDependencies,DependencyIndex,DependedOn,DependOn
End

Function LabelDependencies(DependencyCounts,proc_names,dim)
	Wave DependencyCounts
	String proc_names
	Variable dim
	Variable i,num_proc_files=ItemsInList(proc_names)
	for(i=0;i<num_proc_files;i+=1)
		String proc_file1=StringFromList(i,proc_names)
		proc_file1=RemoveEnding(proc_file1,".ipf")
		SetDimLabel dim,i,$proc_file1,DependencyCounts
	endfor
End

Function MatrixSort(MatrixToSort,dim,SortIndex)
	Wave MatrixToSort
	Variable dim
	Wave SortIndex
	Variable i
	Duplicate /o MatrixToSort SortedMatrix
	for(i=0;i<numpnts(SortIndex);i+=1)
		Variable index=SortIndex[i]
		if(dim==0) // Rows.  
			SortedMatrix[i][]=MatrixToSort[index][q]
		elseif(dim==1) // Columns.  
			SortedMatrix[][i]=MatrixToSort[p][index]
		endif
	endfor
	MatrixToSort=SortedMatrix
	KillWaves /Z SortedMatrix
End

Function TextMatrixSort(MatrixToSort,dim,SortIndex)
	Wave /T MatrixToSort
	Variable dim
	Wave SortIndex
	Variable i
	Duplicate /o/T MatrixToSort SortedMatrix
	for(i=0;i<numpnts(SortIndex);i+=1)
		Variable index=SortIndex[i]
		if(dim==0) // Rows.  
			SortedMatrix[i][]=MatrixToSort[index][q]
		elseif(dim==1) // Columns.  
			SortedMatrix[][i]=MatrixToSort[p][index]
		endif
	endfor
	MatrixToSort=SortedMatrix
	KillWaves /Z SortedMatrix
End

Function DisplayDependencies()
	SetDataFolder root:Packages:DependencyAnalyzer
	Wave DependencyCounts
	Wave /T DependencyDetails
	//print "---"
	Variable i,j
	Variable rows=dimsize(DependencyCounts,0)
	Variable columns=dimsize(DependencyCounts,1)
	DoWindow /K DependencyAnalyzerResults
	Variable unit_height=FontSizeHeight("Arial",12,1)
	Variable unit_width=25
	NewPanel /K=1 /N=DependencyAnalyzerResults /W=(100,100,200+columns*unit_height,200+rows*unit_width) as "Dependency Results"
	Button HelpResults size={20,20}, pos={5,5}, proc=HelpFilesButtons, title="?"
	SetDrawEnv textxjust=1,textyjust=1,save
	SetDrawEnv textrot=90,fstyle=2
	DrawText 10,25+rows*20/2,"Calls"
	SetDrawEnv textrot=0,fstyle=2
	DrawText 40+columns*25/2,12,"Called"
	Duplicate /o DependencyCounts DependencyCountListSelections
	Make /o/T/n=(rows,columns+1) DependencyCountsText="\JC"+num2str(DependencyCounts[p][q])
	DependencyCountsText[][columns]="\f01"+GetDimLabel(DependencyCounts,0,p)
	DependencyCountListSelections=0
	ListBox DependencyCountList, pos={unit_width,unit_width}, fsize=12,font="Arial"//,widths={0}
	ListBox DependencyCountList selWave=DependencyCountListSelections,listWave=DependencyCountsText, mode=0,proc=PAR_Click
	Variable max_width=0
	Variable total_height=max(unit_height*rows,min_listbox_size)
	for(i=0;i<rows;i+=1)
		String depends_on=GetDimLabel(DependencyCounts,0,i)
		max_width=max(max_width,FontSizeStringWidth("Arial",12,1,depends_on))
		Variable height=i*unit_height
		for(j=0;j<columns;j+=1)
			String depended_on=GetDimLabel(DependencyCounts,1,j)
			Variable width=j*unit_width
			if(i==0)
				SetDrawEnv textrot=90,fname="Arial",fsize=12,fstyle=1,textxjust=1,textyjust=2
				DrawText unit_width*1.5+width,unit_width+40+total_height+2,depended_on
				ListBox DependencyCountList,widths+={unit_width}
			endif
			Variable cyclic=0
			if(FindDimLabel(DependencyCounts,0,depended_on)!=-2 && FindDimLabel(DependencyCounts,1,depends_on)!=-2) // If both procedure files were analyzed as callers and callees.  
				cyclic=DependencyCounts[%$depends_on][%$depended_on] && DependencyCounts[%$depended_on][%$depends_on] && !StringMatch(depends_on,depended_on)
				DependencyCountsText[i][j]=SelectString(cyclic,"","\K(65535,0,0)")+DependencyCountsText[i][j] // Bold and color red cyclic dependencies.  
			endif
			if(StringMatch(depends_on,depended_on))
				DependencyCountsText[i][j]=SelectString(DependencyCounts[i][j],"","\f02")+DependencyCountsText // Italicize remaining dependencies.  
			else
				DependencyCountsText[i][j]=SelectString(DependencyCounts[i][j],"","\f01")+DependencyCountsText // Bold remaining dependencies.  
			endif
		endfor
	endfor
	//print unit_height,max_width
	//max_width+=30 // Fudge factor since FontSizeStringWidth does not work correctly.  
	Variable total_width=max(unit_width*columns+max_width,min_listbox_size)
	MoveWindow /W=DependencyAnalyzerResults 100,100,160+unit_width+total_width,190+unit_width+total_height+max_width
	ListBox DependencyCountList,fsize=12,size={total_width+40,total_height+40},widths+={max_width},mode=5,special={0,unit_height,1}
	Checkbox Zeroes, value=1, title="Zeroes",proc=DisplayDependenciesCheckboxes
	Checkbox Self, value=1, title="Self-Dependencies",proc=DisplayDependenciesCheckboxes
	SetDataFolder root:
End

function DisplayDependenciesCheckboxes(ctrlName,value)
	string ctrlName
	variable value
	
	dfref df=root:Packages:DependencyAnalyzer
	wave /T/sdfr=df DependencyCountsText
	wave /sdfr=df DependencyCounts
	strswitch(ctrlName)
		case "Zeroes":
			DependencyCountsText=selectstring(DependencyCounts[p][q] || q>=dimsize(DependencyCounts,1),selectstring(value,"","\JC"+num2str(DependencyCounts[p][q])),DependencyCountsText[p][q])
			break
		case "Self":
			DependencyCountsText=selectstring(!stringmatch(GetDimLabel(DependencyCounts,0,p),GetDimLabel(DependencyCounts,1,q)),selectstring(value,"","\f02\JC"+num2str(DependencyCounts[p][q])),DependencyCountsText[p][q])
			break
	endswitch
end
End

Function PAR_Click(lb) : ListBoxControl
	STRUCT WMListboxAction &lb
	if(lb.eventCode!=2)
		return 0
	endif
	Wave DependencyCounts=root:Packages:DependencyAnalyzer:DependencyCounts
	if(lb.col==dimsize(DependencyCounts,1)) // If the user clicked on the name of the procedure.  
		String proc_name=GetDimLabel(DependencyCounts,0,lb.row)
		DependencyStack(proc_name)
	//elseif(!DependencyCounts[lb.row][lb.col]) // If there is no dependency between these two files (in that direction)
	else
		ShowFunctionDependencies(lb.row,lb.col)
	endif
End

Function ShowFunctionDependencies(row,col)
	Variable row,col
	String details=GetDependencyDetails(row,col)
	DoWindow /K DependencyAnalyzerDetails
	Variable height=max(100,min(ItemsInList(details)*25,400))
	NewPanel /N=DependencyAnalyzerDetails /K=1/W=(100,100,400,100+height) as "Function Dependencies"
	Button HelpDetails pos={5,5}, size={30,20}, proc=HelpFilesButtons, title="?"
	Make /o/T/n=(ItemsInList(details)) root:Packages:DependencyAnalyzer:FunctionDependencies=StringFromList(p,details)
	ListBox DependencyCountList, pos={10,30}, size={280,height-45}, listWave=root:Packages:DependencyAnalyzer:FunctionDependencies, mode=0,proc=GoToFunction
End

Function GoToFunction(lb) : ListBoxControl
	STRUCT WMListboxAction &lb
	if(lb.eventCode!=2)
		return 0
	endif
	Wave DependencyCounts=root:Packages:DependencyAnalyzer:DependencyCounts
	Variable caller_index=lb.row-1
	if(caller_index<0) // User clicked on the procedure file names.  
		STRUCT WMListboxAction fake_lb
		fake_lb.eventCode=2
		String caller_proc,called_proc
		// Should use SplitString instead of the below.  
		String str=ReplaceString(" -> ",lb.ListWave[0],"->")
		str=ReplaceString(" ",str,"*")
		str=ReplaceString("->",str," -> ")
		sscanf str,"\f01%s -> %s",caller_proc,called_proc
		caller_proc=ReplaceString("*",caller_proc," ")
		called_proc=ReplaceString("*",called_proc," ")
		//print caller_proc,called_proc
		fake_lb.row=FindDimLabel(DependencyCounts,0,called_proc)
		fake_lb.col=FindDimLabel(DependencyCounts,1,caller_proc)
		//print "---"
		//print fake_lb.row,fake_lb.col
		if(fake_lb.row>-2 && fake_lb.col>-2)
			PAR_Click(fake_lb) // Show dependencies for the reverse case.  
		endif
	else // User clicked on the function names.  
		//String caller_proc=GetDimLabel(DependencyCounts,0,caller_index)
		//print caller_proc
		String caller_function=StringFromList(0,lb.ListWave[lb.row]," ")
		//SVar all_procedures=root:Packages:DependencyAnalyzer:all_procedures
		//String candidate_caller_procs=ListMatch(all_procedures,caller_proc+".ipf")+ListMatch(all_procedures,caller_proc)
		//caller_proc=StringFromList(0,candidate_caller_procs) 
		//print caller_function
		//String FunctionInfo
		string cmd="DisplayProcedure \""+caller_function+"\""
		Execute /P/Q cmd
	endif
End

Function /S GetDependencyDetails(i,j)
	Variable i,j
	Wave DependencyCounts=root:Packages:DependencyAnalyzer:DependencyCounts
	Wave /T DependencyDetails=root:Packages:DependencyAnalyzer:DependencyDetails
	String details="\f01"+GetDimLabel(DependencyCounts,0,i)+" -> "+GetDimLabel(DependencyCounts,1,j)
	details+=";"+DependencyDetails[i][j]
	return details
End

Function SelectProcFilesButtons(ctrlName) : ButtonControl
	String ctrlName
	Wave ProcSelections1=root:Packages:DependencyAnalyzer:ProcSelections1
	Wave ProcSelections2=root:Packages:DependencyAnalyzer:ProcSelections2
	strswitch(ctrlName)
		case "Compute":
			Variable i
			String callers="",callees=""
			Wave /T AllProcs=root:Packages:DependencyAnalyzer:AllProcs
			for(i=0;i<numpnts(ProcSelections1);i+=1)
				if(ProcSelections1[i] & 1)
					callers+=AllProcs[i]+";"
				endif
				if(ProcSelections2[i] & 1)
					callees+=AllProcs[i]+";"
				endif
			endfor
			ControlInfo SortCounts
			ComputeDependencies(dependsOn=callers,dependedOn=callees,sort_results=V_Value)
			break
		case "SelectAll1":
			ProcSelections1=1
			break
		case "SelectAll2":
			ProcSelections2=1
			break
	endswitch
End

Function HelpFilesButtons(ctrlName) : ButtonControl
	String ctrlName
	strswitch(ctrlName)
		case "HelpMain":
			DisplayHelpTopic "Dependency Analyzer[Main Panel]"
			break
		case "HelpResults":
			DisplayHelpTopic "Dependency Analyzer[Results Panel]"
			break
		case "HelpDetails":
			DisplayHelpTopic "Dependency Analyzer[Details Panel]"
			break
		case "HelpDependencyStack":
			DisplayHelpTopic "Dependency Analyzer[Dependency Stack Panel]"
			break
	endswitch
End

// Makes a list of procedure files required by a given procedure file.  
Function DependencyStack(proc_file)
	String proc_file
	SetDataFolder root:Packages:DependencyAnalyzer
	Wave DependencyCounts
	Make /o/T/n=0 ProcedureStack
	Make /o/n=0 StackDepth
	DependencyStackRecurse(proc_file,1)
	FindValue /TEXT=proc_file /TXOP=4 ProcedureStack
	DeletePoints V_Value,1,ProcedureStack,StackDepth
	Sort StackDepth,StackDepth,ProcedureStack
	ProcedureStack="\f01"+num2str(StackDepth)+": \f00"+ProcedureStack
	InsertPoints 0,1,ProcedureStack
	ProcedureStack[0]="\f01"+proc_file
	DoWindow /K DependencyStackPanel
	Variable height=max(95,min(numpnts(ProcedureStack)*25,400))
	NewPanel /N=DependencyStackPanel /K=1/W=(100,100,400,120+height) as "Dependency Stack"
	ListBox DependencyStackList, pos={10,30}, size={280,height-15}, listWave=ProcedureStack, mode=0, proc=DependencyStackRegen
	Button HelpDependencyStack pos={5,5}, size={30,20}, proc=HelpFilesButtons, title="?"
	KillWaves /Z StackDepth
End

Function DependencyStackRegen(lb) : ListBoxControl
	STRUCT WMListboxAction &lb
	if(lb.eventCode!=2)
		return 0
	endif
	if(lb.row==0 || lb.row>=numpnts(lb.ListWave))
		return 0
	endif
	//print lb.row
	Variable offset=strsearch(lb.ListWave[lb.row], "f00", 0)
	String proc_file=lb.ListWave[lb.row]
	//print offset+2,proc_file
	proc_file=proc_file[offset+3,strlen(proc_file)-1]
	//print proc_file[0],proc_file[strlen(proc_file)-1],proc_file
	DependencyStack(proc_file)
End	
	
Function DependencyStackRecurse(proc_file,depth)
	String proc_file
	Variable depth
	Wave /T SelectedProcs,ProcedureStack
	Wave StackDepth
	Wave DependencyCounts
	Variable i
	for(i=0;i<numpnts(SelectedProcs);i+=1)
		String one_proc=RemoveEnding(SelectedProcs[i],".ipf")
		if(StringMatch(proc_file,one_proc))
			continue
		endif
		if(DependencyCounts[%$proc_file][%$one_proc])
			FindValue /TEXT=one_proc /TXOP=4 ProcedureStack
			if(StringMatch(proc_file,"Acquisition_Windows") && StringMatch(one_proc,"Experiment Facts"))
				print depth
			endif
			if(V_Value>=0) // Added to the stack already.  
				Variable old_depth=StackDepth[V_Value]
				//print StackDepth,depth,new_depth,proc_file,V_Value
				if(depth<old_depth) // If it should be shallower on the stack that it is currently listed.  
					StackDepth[V_Value]=depth
					DependencyStackRecurse(one_proc,depth+1)
				endif
			elseif(V_Value<0) // Not added to the stack yet.  
				//print proc_file,one_proc,DependencyCounts[%$proc_file][%$one_proc]
				InsertPoints 0,1,ProcedureStack,StackDepth
				ProcedureStack[0]=one_proc
				StackDepth[0]=depth
				DependencyStackRecurse(one_proc,depth+1)
			endif
		endif
	endfor	
End

Function GraphVizDot()
	svar dotLanguage=root:Packages:DependencyAnalyzer:dotLanguage
	variable i,refNum
	newpath /o/q desktop specialdirpath("desktop",0,0,0)
	Open /p=desktop refNum "dependencies.dot"
	string line="digraph G {\r\n"
	fbinwrite refNum,line
	for(i=0;i<itemsinlist(dotLanguage);i+=1)
		string item = stringfromlist(i,dotLanguage)
		item = replacestring("(",item,"")
		item = replacestring(")",item,"")
		line="\t"+item+";\r\n"
		fbinwrite refNum,line
	endfor
	line="\t}\r\n"
	fbinwrite refNum,line
	Close refNum
End
