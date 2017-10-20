// $Author: rick $
// $Rev: 633 $
// $Date: 2013-03-28 15:53:22 -0700 (Thu, 28 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.

#ifdef Rick
// David Dana, 2011-3-16
// Creates a Folder menu for selecting among data folders, as an alternative to the Data Browser.
// Supports hierarchical folder structures, but somewhat kludgily since we can't make dynamic menus
// truly hierarchical.  See FolderMenuItems() description for complete description of menu behavior.
// Menu also includes a command for creating new folders (but not deleting).

Menu "Folder", dynamic
	FolderMenuItems(), FolderItemHandler()
	"-"
	"New Folder...", FolderPromptNewFolder()
End Menu
 
//--------------------------------------------------------------------------
//	Constructs a menu listing the current data folder, its parent, siblings, and children if any.
//	The first menu item is always the parent of the current folder, or root: if root: is current.
//	Then are listed all folders with the same parent as the current folder.
//	If the current folder has folders below it, these are also listed, indented below the current folder.
//
//	If the current folder has siblings with their own children (the current folder's nieces and nephews ;-) ),
//	those children are not shown, but their parents are marked with a '>'.   The user can view those children
//	by selecting the parent.
//
//	The currently active data folder is marked with a check, and disabled (since there is no point to
//	selecting it again).
//	
//	David Dana, HOBI Labs, Inc. 2011-3-16
Function/S FolderMenuItems()
 
	string itemStr
	string currentDF = GetDataFolder(1)	// Get complete folder path
	string parent = CurrentFolderParent(1)
 
	//	First menu item is the full path of the parent folder
	if (strlen(parent) == 0)	//  the current folder is root, there is no parent
		itemStr = DisablePrefix() + CheckMarkPrefix() + "root:;"
		parent = "root:"
	else
		itemStr = parent + ";"	
	endif
 
//	Find all children of parent (possibly including the current folder)
	variable i, itemCount = CountObjects(parent, 4)
	if (itemCount)
		itemStr = itemStr + "-;"
	//	Add each child to menu item list
		string child
		for (i = 0; i < itemCount; i += 1)
			child = getIndexedObjName(parent, 4, i)
			string childFullPath = parent + possiblyQuoteName(child) + ":"
			variable grandchildCount = CountObjects(childFullPath,4)
	// if this is the current folder, prefix checkmark and see if it has children
			if (stringmatch(currentDF, childFullPath))
				itemStr = itemStr + DisablePrefix() + CheckMarkPrefix() + child + ";"
				if (grandChildCount)
					variable j
					for (j = 0; j < grandChildCount; j+=1)
						string grandChild = getIndexedObjName(childFullPath,4,j)
						itemStr =  itemStr + "  " + grandChild + ";"  // prefix subfolders with 2 spaces for clarity
					endfor
				endif
			else
				if (grandChildCount)
					itemStr = itemStr + ParentPrefix() + child + ";"
				else
					itemStr = itemStr + child + ";"
				endif
			endif
		endfor
	endif
	return itemStr
End Function  //--------------------------------------------------------------
 
//--------------------------------------------------------------------------
//	Responds to a selection from the menu constructed by FolderMenuItems().
//	Extracts the path of a folder and sets that as the current data folder.
Function FolderItemHandler()
	GetLastUserMenuInfo
	String folderPath = S_Value
	Variable itemNumber = v_value
 
	variable isChild = StringMatch(folderPath, ChildPrefix() + "*")
	folderPath = StripPrefix(folderPath)
	string parentPath = StringFromList (0, FolderMenuItems(), ";")
	parentPath = StripPrefix(parentPath)
 
	if (itemNumber == 1)			// first item is the parent folder
		folderPath = "::"			// Go up one level
	else
		if (!isChild)	// if child, folderPath is already correct
			folderPath = parentPath + possiblyquotename(folderPath)
		endif
	endif
	SetDataFolder folderPath
End Function  //--------------------------------------------------------------
 
//--------------------------------------------------------------------------
// Append this to the front of a menu item to indicate the folder is child of a folder above it
Function/S ChildPrefix()
	Return "  "
End Function  //--------------------------------------------------------------
 
//--------------------------------------------------------------------------
// Append this to the front of a menu item to indicate the folder has children
Function/S ParentPrefix()
	Return "!>"
End Function  //--------------------------------------------------------------
 
//--------------------------------------------------------------------------
// Append this to the front of a menu item to disable it.  Can be added in front of other marks.
Function/S DisablePrefix()
	Return "("
End Function  //--------------------------------------------------------------
 
//--------------------------------------------------------------------------
// Append this to the front of a menu item to give it a check mark
Function/S CheckMarkPrefix()
	return "!" + num2Char(18)
End Function  //--------------------------------------------------------------
 
//--------------------------------------------------------------------------
// Removes special characters such as check marks, etc. from the front of a menu item name
Function/S StripPrefix(s)
string s
	if (stringmatch(s, "(*"))		// an open parenthesis makes the item inactive
		s = s[1,inf]
	endif
	if (stringmatch(s, "!!*") == 0)		// the initial ! is a logic inversion operator.
		s = s[2,inf]
	endif
	if (stringmatch(s, ChildPrefix() + "*"))
		s = s[strlen(ChildPrefix()), inf]
	endif
	return s
End Function  //--------------------------------------------------------------
 
//--------------------------------------------------------------------------
// Asks for the user for the name of a new folder.  Returns 0 if user cancelled or error.
Function FolderPromptNewFolder()
 
	string name
	prompt name, "Name for new folder in " + GetDataFolder (0)
	string promptStr = "New Data Folder"
	DoPrompt/HELP="" promptStr, name
	if (v_flag == 1)	// user cancelled
		return 0
	endif
	if (CheckName(name, 11))
		DoAlert 0, "\"" + name + "\" is not a legal folder name or is already in use."
		return 0
	endif
	NewDataFolder $name
	return 1
End Function  //--------------------------------------------------------------
 
//--------------------------------------------------------------------------
// Returns the name of the parent of the current folder, or empty string if the current folder is root:.
// If fullSpec is zero, returns only the base name of the parent, otherwise returns its full path
Function/S CurrentFolderParent(fullSpec)
variable fullSpec
 
	string folder = GetDataFolder(1) 
	if (stringmatch(folder, "root:"))
		return ""
	else
		variable items = ItemsInList (folder, ":")
		if (fullSpec)
			folder = RemoveListItem (items - 1, folder, ":")
			return folder
		else
			return StringFromList (items-2, folder, ":")
		endif
	endif
End Function  //--------------------------------------------------------------
#endif

Function Root()
	SetDataFolder root:
End

function /df NewFolder(folder_str[,go])
	string folder_str
	variable go
	
	return Core#NewFolder(folder_str,go=go)
end

function /s JoinPath(folders)
	wave /t folders
	
	return Core#JoinPath(folders)
end

Function IMD(num)
	Variable num
	Execute /Q "SetIgorOption IndependentModuleDev="+num2str(num)
End

function showhelp(str)
	string str
	displayhelptopic str
end

threadsafe Function Dbg(str)
	string str // A debugging message to print. 
#ifdef PrintDebug
	printf "%s\r",str
#endif
End

Function SetDbg(state)
	variable state
	
	if(state)
		Execute /Q/P "SetIgorOption poundDefine=PrintDebug"
	else
		Execute /Q/P "SetIgorOption poundUnDefine=PrintDebug"
	endif
	Execute /Q/P "Silent 101"
End

function FolderDiff(df1,df2)
	dfref df1,df2
	
	variable i,j
	string types="waves;variables;strings;folders;"
	string folder1=getdatafolder(1,df1)
	string folder2=getdatafolder(1,df2)
	for(i=1;i<=itemsinlist(types);i+=1)
		for(j=0;j<CountObjectsDFR(df1,i);j+=1)
			string name=GetIndexedObjNameDFR(df1,i,j)
			if(exists(folder1+name)!=exists(folder2+name))
				printf "No %s in %s.\r",name,folder2
			else
				strswitch(Core#ObjectType(folder1+name))
					case "WAV":
					case "WAVT":
						wave w1=df1:$name
						wave w2=df2:$name
						if(!equalwaves(w1,w2,-1))
							printf "%s is not equal between %s and %s.\r",name,folder1,folder2
						endif
						break
					case "VAR":
						nvar var1=df1:$name
						nvar var2=df2:$name
						if(var1!=var2)
							printf "%s is not equal between %s and %s.\r",name,folder1,folder2
						endif
						break
					case "STR":
						svar str1=df1:$name
						svar str2=df2:$name
						if(!stringmatch(str1,str2))
							printf "%s is not equal between %s and %s.\r",name,folder1,folder2
						endif
						break
					case "FLDR":
						dfref subDF1=df1:$name
						dfref subDF2=df2:$name
						if(datafolderrefstatus(subDF1) && datafolderrefstatus(subDF2))
							FolderDiff(subDF1,subDF2)
						endif
						break
				endswitch
			endif
		endfor
	endfor
End

Function IgorVers()
	String version=StringByKey("IGORFILEVERSION",IgorInfo(3))
	String majorVersion=version[0]
	String minorVersion=ReplaceString(".",version[1,strlen(version)-1],"")
	version=majorVersion+"."+minorVersion
	return str2num(version)
End

Function IsDebuggerOn()
	DebuggerOptions
	return V_enable
End

function /s Timestamp()
	return secs2date(datetime,-2)+"_"+replacestring(":",secs2time(datetime,3),"-")
end

function InitVars([df,vars,strs,overwrite])
	dfref df
	string vars,strs
	variable overwrite
	
	if(paramisdefault(df))
		df=getdatafolderdfr()
	endif
	vars=selectstring(!paramisdefault(vars),"",vars)
	strs=selectstring(!paramisdefault(strs),"",strs)
	
	variable i
	for(i=0;i<itemsinlist(vars);i+=1)
		string info=stringfromlist(i,vars)
		string name=stringfromlist(0,info,"=")
		nvar /z/sdfr=df var=$name
		if(!nvar_exists(var) || overwrite)
			variable varValue=str2num(stringfromlist(1,info,"="))
			variable /g df:$name=varValue
		endif
	endfor
	for(i=0;i<itemsinlist(strs);i+=1)
		info=stringfromlist(i,strs)
		name=stringfromlist(0,info,"=")
		svar /z/sdfr=df str=$name
		if(!svar_exists(str) || overwrite)
			string strValue=stringfromlist(1,info,"=")
			string /g df:$name=strValue
		endif
	endfor
end

Function CtrlNumValue(ctrlName[,win])
	string ctrlName,win
	
	win=selectstring(paramisdefault(win),win,winname(0,65))
	controlinfo /w=$win $ctrlName
	return v_flag>0 ? v_value : nan
End

Function /S CtrlStrValue(ctrlName[,win])
	string ctrlName,win
	
	win=selectstring(paramisdefault(win),win,winname(0,65))
	controlinfo /w=$win $ctrlName
	return selectstring(v_flag>0,"",s_value)
End

Function WaitForThreads(threadRef)
	Variable threadRef
	
	Do
		Variable tgs= ThreadGroupWait(threadRef,100)
	while( tgs != 0 )
End

Function /WAVE ErrWave(num)
	variable num
	make /free/n=1 error=num
	return error
End

Function ExecuteUserFile(file,args)
	string file // Relative to Igor Pro User Files directory, using colons as path separators.  
	string args
	
	if(stringmatch(file[0],":"))
		file=file[1,strlen(file)-1] // Remove leading colon.  
	endif
	string igorFilesPath=Igor2WindowsPath("Igor Pro User Files")
	string filePath=Igor2WindowsPath(file)
	string cmd="\""+igorFilesPath+filePath+"\""	
	variable i
	for(i=0;i<itemsinlist(args);i+=1)
		cmd+=" "+stringfromlist(i,args)
	endfor
	executescripttext /b cmd
End

function /s Igor2WindowsPath(path)
	string path // Can be a path name, an Igor special directory path name, or a raw colon-separated path.  
	PathInfo $path
	if(v_flag) // Is existing path.  
		path=s_path
	else
		debuggeroptions
		if(v_debugOnError)
			variable debugOnError=1
		endif
		debuggeroptions  debugOnError=0
		string possiblePath=specialdirpath(path,0,0,0)
		if(!getrterror(1)) // Is Igor special directory path.  
			path=possiblePath
		endif
		debuggeroptions debugOnError=debugOnError
	endif
	if(stringmatch(path[1],":"))
		path[1,1]="|||||" // Protect drive letter.  
	endif
	path=replacestring(":",path,"\\") // Replace path separators.  
	path=replacestring("|||||",path,":\\") // Restore drive letter.  
	return path	
end

// Execute 'command' for all instances of ## replaced by items in 'replaceStrs'.  
function Exx(command,replaceStrs[,parallel,times,noExpand])
	string command
	wave /t replaceStrs
	variable parallel
	variable times
	variable noExpand // Do not use ListExpand.  

	times=ParamIsDefault(times) ? 1 : times
	if(!noExpand)
		replaceStrs=listexpand(replaceStrs[p],no_sort=parallel)
	endif
	redimension /n=4 replaceStrs
	replaceStrs=selectstring(strlen(replaceStrs),";",replaceStrs[p])
	make /free/n=(numpnts(replaceStrs)) numItems=ItemsInList(replaceStrs[p])
	variable i,j,k,m,t
	for(t=0;t<times;t+=1)
		if(times>1)
			Prog2("Times",t,times)
		endif
		if(parallel)
			for(i=0;i<numItems[0];i+=1)
				Prog2("1",i,numItems[0])
				string cmd1=ReplaceString("%1",command,stringfromlist(i,replaceStrs[0]))
				cmd1=ReplaceString("%2",cmd1,stringfromlist(i,replaceStrs[1]))
				cmd1=ReplaceString("%3",cmd1,stringfromlist(i,replaceStrs[2]))
				cmd1=ReplaceString("%4",cmd1,stringfromlist(i,replaceStrs[3]))
				Execute "Preferences 1;"+cmd1
			endfor
		else
			for(i=0;i<numItems[0];i+=1)
				Prog2("1",i,numItems[0],atLeast=2)
				cmd1=ReplaceString("%1",command,stringfromlist(i,replaceStrs[0]))
				for(j=0;j<numItems[1];j+=1)
					Prog2("2",j,numItems[1],atLeast=2)
					string cmd2=ReplaceString("%2",cmd1,stringfromlist(j,replaceStrs[1]))
					for(k=0;k<numItems[2];k+=1)
						Prog2("3",k,numItems[2],atLeast=2)
						string cmd3=ReplaceString("%3",cmd2,stringfromlist(k,replaceStrs[2]))
						for(m=0;m<numItems[3];m+=1)
							Prog2("4",m,numItems[3],atLeast=2)
							string cmd4=ReplaceString("%4",cmd3,stringfromlist(m,replaceStrs[3]))
							Execute "Preferences 1;"+cmd4
						endfor
					endfor
				endfor
			endfor
		endif
	endfor
End

static function Prog2(name,num,denom[,atLeast])
	variable num,denom,atLeast
	string name
	
#if exists("Prog")
	if(denom>=atLeast)
		string cmd
		sprintf cmd,"Prog(\"%s\",%d,%d)",name,num,denom
		Execute /Q cmd
	endif
#endif
end

// Lambda functions.  The string 'str' will be executed, and the value of a global variable 'v_lambda' will be returned.  
// The user is responsible for create the variable v_lambda in their string.  
function Lambda(str)
	string str
	
	execute /q str
	variable v_lambda=numvarordefault("v_lambda",nan)
	return v_lambda
end

static function Prog(str,var1,var2[,atLeast])
	string str
	variable var1,var2,atLeast

end

// Evaluates the string and returns the value as a number.  
// Even works with constants, since it is routed through the command line.  
Function NumEval(str)
	String str
	Execute /Q/Z "Variable /G evalNumTemp=NaN"
	NVar evalNumTemp
	Execute /Q/Z "Variable /G evalNumTemp="+str
	Variable result=evalNumTemp
	KillVariables /Z evalNumTemp
	return result
End

Function /S StrEval(str)
	String str
	Execute /Q/Z "String /G evalStrTemp="+str
	SVar evalStrTemp
	String result=evalStrTemp
	KillStrings /Z evalStrTemp
	return result
End

Function Post_(str[,trace])
	String str
	variable trace // Prints a stack trace.  
	
	SVar /Z win_names=root:Packages:ProgWin:win_names
	String topPanel=WinName(0,64)
	if(!trace && SVar_Exists(win_names) && WhichListItem(topPanel,win_names)>=0) // There is a progress window to post a message to and no stack trace is desired.  .  
		Titlebox Status title=str, pos={5,5}, size={200,20}, win=$topPanel
	elseif(trace)
		sprintf str,"%s:\r%s\r",str,GetRTStackInfo(trace)
	else
		printf "%s\r",str
	endif
End

Function KillInFolder(folder,list)
	DFRef folder
	String list
	
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		KillWaves /Z folder:$item
		KillVariables /Z folder:$item
		KillStrings /Z folder:$item
	endfor
End

// Returns the number of times a function is called.  
Function FunctionCalls(funcName)
	String funcName
	
	String allFunctions=FunctionList("*",";","KIND:2")
	Variable i,callers=0
	for(i=0;i<ItemsInList(allFunctions);i+=1)
		String callingFunction=StringFromList(i,allFunctions)
		String function_text=ProcedureText(callingFunction,0)
		Make /o/T/n=(ItemsInList(function_text,"\r")) FunctionText=StringFromList(p,function_text,"\r")
		DeletePoints 0,1,FunctionText // Exclude function title.  
		Make /o/T/n=0 MatchingLines
		String grep_str=funcName
		Grep /E=(grep_str) FunctionText as $"MatchingLines"	
		// Restrict to lines where the function name is not immediately preceded by a letter or number, which couldn't correspond to a real function call.  
		// Or to window controls that call this procedure.  
		grep_str="^"+funcName+"\(|[^a-zA-Z0-9_]"+funcName+"\(|[Pp]roc="+funcName
		Grep /E=(grep_str) MatchingLines as $"MatchingLines"
		// Restrict to lines that do not start with a comment mark.  
		grep_str="^[^(////)]"
		Grep /E=(grep_str) MatchingLines as $"MatchingLines"
		callers+=(numpnts(MatchingLines)>0)
	endfor
	return callers
End

Function SVInput(eventCode)
	Variable eventCode
	
	switch(eventCode)
		case 1: // Mouse up.  
			return 1
			break
		case 2: // Enter key.    
			return 1
			break
		case 4: // Scroll up.  
			return 0
			break
		case 5: // Scroll down.  
			return 1
			break
		default:
			return 0
			break
	endswitch
End

Function PopupInput(eventCode)
	Variable eventCode
	
	switch(eventCode)
		case 2: // Mouse up.  
			return 1
			break
		default:
			return 0
			break
	endswitch
End

function /df ParentFolder(df)
	dfref df
	
	string folder=removeending(getdatafolder(1,df),":")+":"
	folder=removeending(getdatafolder(1,df),getdatafolder(0,df)+":")
	if(!strlen(folder))
		dfref parent=root:
	else
		dfref parent=$folder
	endif
	return parent
end

// Returns 1 if the specified Igor timestamp falls in a daylight savings time epoch.  
Function DST(timeStamp)
	Variable timeStamp
	
	Variable day,month,year,dayOfWeek,hours,minutes
	String date_=Secs2Date(timeStamp,-1)
	sscanf date_,"%d/%d/%d (%d)",day,month,year,dayOfWeek
	String time_=Secs2Time(timeStamp,2)
	sscanf time_,"%d:%d",hours,minutes
	switch(month)
		case 1:
		case 2:
			return 0
			break
		case 3: 
			Variable minDay=dayOfWeek+7*1 // Second sunday.  
			if(day>=minDay && (dayOfWeek!=1 || hours>=2))
				return 1
			else
				return 0
			endif
			break
		case 4:
		case 5:
		case 6:
		case 7:
		case 8:
		case 9: 
		case 10: 
			return 1
			break
		case 11:
			minDay=dayOfWeek+7*0 // First sunday.  
			if(day>=minDay && (dayOfWeek!=1 || hours>=2))
				return 0
			else
				return 1
			endif
			break
			break
		case 12:
			return 0
			break
		default:
			printf "No such month: %d.\r",month
	endswitch
End

Function Log2(var)
	variable var
	
	return log(var)/log(2)
End

// Moves the notebook selection to be the end of the notebook.  If this is not a blank line, it creates a blank line below this and moves the selection there.   
Function FirstBlankLine(notebookName)
	String notebookName
	Notebook $notebookName selection={endOfFile,endOfFile}
	GetSelection notebook, $notebookName,1
	if(V_endPos>0)
		Notebook $notebookName text="\r"
	endif
End

Function/S WordWrapTextBox(textBoxName,wrapWidth[,windowName])
	String textBoxName
	Variable wrapWidth
	String windowName
	
	if(ParamIsDefault(windowName))
		windowName=WinName(0,5)
	endif
	Variable layout_=(WinType(windowName)==3)
	if(!strlen(textBoxName))
		String annotations=AnnotationList(windowName)
		Variable i,textboxes
		for(i=0;i<ItemsInList(annotations);i+=1)
			String info=AnnotationInfo(windowName,textBoxName,1)
			String type=StringByKey("TYPE",info)
			if(StringMatch(type,"Textbox")) // Apply word wrapping to textboxes is graphs and layouts.  
				textboxName=StringFromList(i,annotations)
				if(layout_) // Layout
					String layout_info=LayoutInfo(windowName,textboxName)
					Variable selected=NumberByKey("SELECTED",layout_info)
					if(!selected)
						continue // Only apply word wrapping to selected textboxes in layouts.  
					endif
				endif
				String result=WordWrapTextBox(textboxName,wrapWidth,windowName=windowName)
				textboxes+=1
			endif
		endfor
		if(textboxes==0)
			return ""
		else
			return result
		endif
	endif
	
	Variable currentLineNum = 0
	// determine the dimensions of the control where this text will be placed
	
	info=AnnotationInfo(windowName,textBoxName,1)
	if(strlen(info))		
		variable strpos=StrSearch(info,"TEXT:",0)
		String textStr=info[strpos+5,strlen(info)-1]
		String rect=StringByKey("RECT",info)
		Variable left,top,right,bottom
		sscanf rect,"%f,%f,%f,%f",left,top,right,bottom
		Variable textHeight=bottom-top
	else						// Textbox doesn't exist.
		return ""				
	endif
	
	// Protect double carriage returns and carriage returns followed by tabs.  
	textStr=ReplaceString("\r\r",textStr,"<|r>")
	textStr=ReplaceString("\r\t",textStr,"<|t>")
	// Kill old carriage returns.  
	textStr=ReplaceString("\r",textStr,"")
	// Bring back protected characters.  
	textStr=ReplaceString("<|r>",textStr,"\r\r")
	textStr=ReplaceString("<|t>",textStr,"\r\t")

	Make /o/T/n=0 outputTextWave
	String returnTextStr=""
	Variable firstLineNum=0

	// get the font information for the default font used in this panel
	if(layout_)
		DefaultGuiFont all
	else
		DefaultGuiFont/W=$(windowName) all
	endif
	String defaultFontName = S_name
	Variable defaultTextFontSize = V_value
	Variable defaultTextFontStyle = V_flag

	// now read information from title control to see if
	// a non-default font size, style, or name is being used	
	Variable textFontSize=NaN, textFontStyle=NaN
	String fontName, escapedFontName
	sscanf textStr,"\Z%d",textfontSize
	if (numtype(textFontSize) != 0)		// default font size is used
		textFontSize = defaultTextFontSize
		if (numtype(textFontSize) != 0)
			textFontSize = 12
		endif
	endif
	sscanf textStr,"\f%d",textfontStyle
	if (numtype(textFontStyle) != 0)		// default font style is used
		textFontStyle = defaultTextFontStyle
		if (numtype(textFontStyle) != 0)
			textFontStyle = 0
		endif
	endif		
	sscanf textStr,"\S'%[A-Za-z]'",fontName
	if (cmpstr(fontName, "") == 0)	// no font name found
		fontName = defaultFontName
		if (cmpstr(fontName, "") == 0)		// will be true if S_name above is ""
			fontName = GetDefaultFont(windowName)
		endif
	endif
	
	// Determine the height, in pixels, of a line of text
	Variable lineHeight = FontSizeHeight(fontName, textFontSize, textFontStyle)
	Variable maxNumLines = Inf//floor(textHeight / lineHeight)

	// search for spaces, check length of string up to that point + length of new text, and decide whether 
	// to add the new word or add a line break
	Variable sourceStringPos = 0
	Variable nextSpacePos, nextCRPos, nextBreakPos
	Variable currentTextWidth, newTextWidth
	Variable breakIsCR = 0
	String nextWordString = ""
	String currentLineString = ""

	do
		nextSpacePos = strsearch(textStr, " ", sourceStringPos)
		nextSpacePos = nextSpacePos >= 0 ? nextSpacePos : inf		// set to inf if space is not found
		nextCRPos = strsearch(textStr, "\r", sourceStringPos)
		nextCRPos = nextCRPos >= 0 ? nextCRPos : inf		// set to inf if \r is not found
		if (nextCRPos >= 0 && nextCRPos < nextSpacePos)
			breakIsCR = 1
		else
			breakIsCR = 0
		endif
		nextBreakPos = min(nextSpacePos, nextCRPos)

		if (numtype(nextBreakPos) == 1)		// nextBreakPos == inf means there are no more spaces or \r
			if (strlen(textStr) == sourceStringPos)	// at the end of the string
				returnTextStr += currentLineString	
				break
			else
				nextWordString = textStr[sourceStringPos, inf]
				sourceStringPos = strlen(textStr)
			endif
		else
			nextWordString = textStr[sourceStringPos, nextBreakPos]
		endif
		currentTextWidth = FontSizeStringWidth(fontName, textFontSize, textFontStyle, currentLineString)
		newTextWidth = FontSizeStringWidth(fontName, textFontSize, textFontStyle, nextWordString)
		if ((currentTextWidth + newTextWidth + 5) <= wrapWidth)		// add this word		// leave 5px padding
			currentLineString += nextWordString
			if (numtype(nextBreakPos) == 1)
				break
			elseif (breakIsCR)
				sourceStringPos = nextBreakPos + 1
				returnTextStr += currentLineString
				Redimension/N=(currentLineNum + 1) outputTextWave
				outputTextWave[currentLineNum] = currentLineString
				currentLineString = ""
				currentLineNum += 1
			else
				sourceStringPos = nextBreakPos + 1
			endif
		else													// add a new line and then add this word
			returnTextStr += currentLineString
			returnTextStr += "\r"
			Redimension/N=(currentLineNum + 1) outputTextWave
			outputTextWave[currentLineNum] = currentLineString + "\r"
			currentLineNum += 1
			currentLineString = nextWordString
			if (numtype(nextBreakPos) == 1)
				break
			else
				sourceStringPos = nextBreakPos + 1
			endif
		endif
	while(sourceStringPos < strlen(textStr) - 1)
	returnTextStr += currentLineString		// add last part of string to return string
	Redimension/N=(currentLineNum + 1) outputTextWave
	outputTextWave[currentLineNum] = currentLineString + "\r"
	
	Variable n
	String finalOutputString = ""
	Variable numLinesToReturn = min(DimSize(outputTextWave, 0), maxNumLines + firstLineNum)
	For (n=firstLineNum; n<numLinesToReturn; n+=1)
		finalOutputString += outputTextWave[n]
	EndFor
	finalOutputString=RemoveEnding(finalOutputString,"\r")
	
	KillWaves /Z outputTextWave
	Textbox /W=$windowName /C/N=$textboxName finalOutputString
	return finalOutputString
End

constant PosixMinusIgor=2082844800
Function /S Time2()
	Variable offset=date2secs(-1,-1,-1) // Local time offset.  
	Variable millisecs=DateTime
	millisecs-=round(millisecs)
	String time_=time()
	Variable hours,minutes,seconds
	String pm
	sscanf time_,"%d:%d:%d %s",hours,minutes,seconds,pm
	sprintf time_,"%d:%d:%2.3f %s",hours,minutes,seconds+millisecs,pm
	return time_
End

// Returns a list of functions not called by any other function.  
Function /S FunctionsNotCalled(procName[,match])
	String procName // The name of the procedure file in which to look for called functions, or "" for all procedures.  All procedures will be searched for calling functions.  
	String match // Restrict the called list (not the calling list) to a subset, e.g. "C*")
	
	if(ParamIsDefault(match))
		match="*"
	endif
	String options="KIND:2"
	if(strlen(procName))
		options+=",WIN:"+procName+".ipf"
	endif
	
	String allFunctions=FunctionList(match,";",options)
	allFunctions=SortList(allFunctions)
	Variable i
	String notCalled=""
	
	for(i=0;i<ItemsInList(allFunctions);i+=1)
		String calledFunction=StringFromList(i,allFunctions)
		Variable callers=FunctionCalls(calledFunction)
		printf "%s: %d.\r",calledFunction,callers
		if(!callers)
			notCalled+=calledFunction+";"
		endif
	endfor
	
	return notCalled
End

Function SaveCDF()
	String /G root:currFolder=GetDataFolder(1)
End

Function RestoreCDF()
	SetDataFolder StrVarOrDefault("root:currFolder","root:")
End

// Parses a string and returns an Igor timestamp.  
Function String2Time(str)
	String str // Must be in the form yyyy/mm/dd hh:mm:ss.micro (hh should be military style).  
	
	Variable year,month,day,hours,minutes,seconds
	sscanf str,"%d/%d/%d %d:%d:%f",year,month,day,hours,minutes,seconds
	Variable time_=date2secs(year,month,day)+hours*3600+minutes*60+seconds
	return time_
End

// Returns 1 if the SetVariable is connected to a variable, and 2 if it is connected to a string.  Returns 0 if does not exist, and negative values for other errors.  
Function SetVarNumOrStr(setVarName[,win])
	String setVarName
	String win
	
	if(ParamIsDefault(win))
		win=WinName(0,65)
	endif
	ControlInfo /W=$win $setVarName
	if(V_flag<=0)
		return V_flag
	endif
	if(StringMatch(S_Value,num2str(V_Value))) // String representation of a number. 
		return 2
	elseif(numtype(V_Value)<2)
		return 1
	else
		return 2
	endif
End

// Returns the english name of a number.  The number can be between 0 and 100, inclusive.  
// Switch-Case automatically rounds numbers.  
Function /S Num2Name(num)
	Variable num
	switch(num)
		case 0: 
			return "zero"
		case 1: 
			return "one"
		case 2: 
			return "two"
		case 3: 
			return "three"
		case 4: 
			return "four"
		case 5: 
			return "five"
		case 6: 
			return "six"
		case 7: 
			return "seven"
		case 8: 
			return "eight"
		case 9: 
			return "nine"
		case 10: 
			return "ten"
		case 11: 
			return "eleven"
		case 12: 
			return "twelve"
		case 13: 
			return "thirteen"
		case 14: 
			return "fourteen"
		case 15: 
			return "fifteen"
		case 16: 
			return "sixteen"
		case 17: 
			return "seventeen"
		case 18: 
			return "eighteen"
		case 19: 
			return "nineteen"
		case 20: 
			return "twenty"
		case 30: 
			return "thirty"	
		case 40: 
			return "fourty"	
		case 50: 
			return "fifty"	
		case 60: 
			return "sixty"	
		case 70: 
			return "seventy"	
		case 80: 
			return "eighty"	
		case 90: 
			return "ninety"	
		case 100: 
			return "hundred"	
		default:
			if(num>100)
				return "MoreThanHundred"
			elseif(num<0)
				return "Negative"
			else
				Variable remainder=mod(num,10)
				Variable base=num-remainder
				return Num2Name(base)+"-"+Num2Name(remainder)
			endif
	endswitch
End

// Takes an english name for a number and returns that number.  Only integers between 0 and 100, inclusive.  
// Names like "twenty-two" must have hyphens.  
Function Name2Num(name)
	String name
	strswitch(name)
		case "zero": 
			return 0 
		case "one":
			return 1 
		case "two":
			return 2 
		case "three":
			return 3 
		case "four":
			return 4 
		case "five":
			return 5 
		case "six":
			return 6 
		case "seven":
			return 7 
		case "eight":
			return 8 
		case "nine":
			return 9 
		case "ten":
			return 10 
		case "eleven":
			return 11 
		case "twelve":
			return 12
		case "thirteen":
			return 13 
		case "fourteen":
			return 14
		case "fifteen":
			return 15 
		case "sixteen":
			return 16 
		case "seventeen":
			return 17
		case "eighteen":
			return 18 
		case "nineteen":
			return 19 
		case "twenty":
			return 20 
		case "thirty":
			return 30 
		case "fourty":
			return 40 
		case "fifty":
			return 50 
		case "sixty":
			return 60 
		case "seventy":
			return 70 	
		case "eighty"	:
			return 80 
		case "ninety"	:
			return 90 
		case "hundred":
			return 100 	
		default:
			if(!StringMatch(name,"*-*"))
				return NaN
			else
				String base=StringFromList(0,name,"-")
				String remainder=StringFromList(1,name,"-")
				return Name2Num(base)+Name2Num(remainder)
			endif
	endswitch
End

// Makes macros for all open windows (not procedure windows) and returns the text of those macros.  
Function Windows2Macros()
	String windows=WinList("*",";","WIN:87")
	Variable i; String win,macros=""
	for(i=0;i<ItemsInList(windows);i+=1)
		win=StringFromList(i,windows)
		Execute /P "DoWindow /R "+win
	endfor
End

// ---------------- Begin zip/unzip functions ----------------

#if exists("zipencode")

constant maxArraySize=100 // The maximum size of a uChar array.  

Structure Bytes
	uchar byte[maxArraySize]
EndStructure

Function Compress(theWave)
	Wave theWave
	
	// Determine the number of bytes per point for later redimensioning.  
	Variable waveTypeNum=WaveType(theWave)
	String header
	sprintf header,"TYPE:%d;NAME:%s;NOTE:%s",WaveType(theWave),NameOfWave(theWave),note(theWave)
	if(waveTypeNum<=1)
		printf "Compression of %s will not proceed because it is the wrong wave type.\r",NameOfWave(theWave)
		return -1
	endif

	String zipName=CleanupName(NameOfWave(theWave)+"_zip",1)
	String /G $zipName=""; SVar zipStr=$zipName
	
	SOCKITwavetostring theWave, zipStr
	zipStr=zipencode(zipStr)
	//String /G poop=zipStr
	zipStr=header+"\n"+zipStr
End

Function Decompress(zipStr)
	String zipStr
	
	// Extract meta-information and data from the string.  
	Variable headerLength=strsearch(zipStr,"\n",0)
	String header=zipStr[0,headerLength-1]
	Variable waveTypeNum; String waveNayme,waveNote
	sscanf header,"TYPE:%d;NAME:%[^;];NOTE:%s",waveTypeNum,waveNayme,waveNote
	String data=zipdecode(zipStr[headerLength+1,strlen(zipStr)-1])
	
	SOCKITstringtowave waveTypeNum,data
	Wave W_stringToWave
	Note W_stringToWave waveNote
	if(!exists(waveNayme))
		Rename W_stringToWave $waveNayme
	else
		Duplicate /o W_stringToWave $waveNayme
	endif
	KillWaves /Z W_stringToWave
End

// Returns the number of bits per point.  'waveTypeNum' is a number returned by WaveType.  
Function BitDepth(waveTypeNum)
	Variable waveTypeNum
	
	Variable bitDepth
	if(waveTypeNum & 8)
		bitDepth=8
	elseif(waveTypeNum & 16)
		bitDepth=16
	elseif(waveTypeNum & 2 || waveTypeNum & 32)
		bitDepth=32
	elseif(waveTypeNum & 4)
		bitDepth=64
	else
		return -1
	endif
	return bitDepth
End

#endif

// ---------------- End zip/unzip functions ----------------

Function LCM2(a,b)
	Variable a, b
	return((a*b)/gcd(a,b))
End

Function LCM(w)
	Wave w
	Variable i,result=w[0]
	for(i=1;i<numpnts(w);i+=1)
		if(w[i] > 0)
			result=LCM2(result,w[i])
		endif
	endfor
	return result
End

// Returns the greatest common factor in a wave.  
Function GCF(theWave)
	Wave theWave
	Variable i,result=theWave[i]
	for(i=1;i<numpnts(theWave);i+=1)
		result=gcd(result,theWave[i])
	endfor
	return result
End

// Converts a condition into a color
Function /S Condition2Color(condition[,no_print])
	String condition
	Variable no_print
	
	Variable /G red,green,blue
	strswitch(condition)
		case "Ctl":
			red=0;green=0;blue=0
			break
		case "Control":
			red=0;green=0;blue=0
			break
		case "Control,None":
			red=0;green=0;blue=0
			break
		case "[NULL]":
			red=0;green=0;blue=0
			break
		case "Control,Paxilline":
			red=10000;green=10000;blue=10000
			break
		case "Control,Iberiotoxin":
			red=20000;green=20000;blue=20000
			break
		case "TTX":
			red=65535;green=0;blue=0
			break
		case "Seizure":
			red=65535;green=0;blue=0
			break
		case "Seizure,None":
			red=65535;green=0;blue=0
			break
		case "Seizure,Paxilline":
			red=65535;green=10000;blue=10000
			break
		case "Seizure,Iberiotoxin":
			red=65535;green=20000;blue=20000
			break
		case "Q54":
			red=0;green=0;blue=65535
			break
		case "SJL":
			red=15000;green=15000;blue=15000
			break
		case "Warm":
			red=0; green=0; blue=65535
			break
		case "PTX":
			red=65535;green=0;blue=0
			break
		case "AM-251":
			red=0;green=65535;blue=0
			break
		default:
			if(!no_print)
				printf "Not a valid condition : %s\r",condition
			endif
			red=0;green=0;blue=0
			break
	endswitch
	return num2str(red)+","+num2str(green)+","+num2str(blue)
End

// Converts a condition into a color
Function /S Condition2Colour(condition,red,green,blue[,no_print])
	String condition
	Variable &red,&green,&blue,no_print
	
	strswitch(condition)
		case "Ctl":
			red=0;green=0;blue=0
			break
		case "Control":
			red=0;green=0;blue=0
			break
		case "[NULL]":
			red=0;green=0;blue=0
			break
		case "TTX":
			red=65535;green=0;blue=0
			break
		case "TTX_Patch":
			red=0;green=65535;blue=0
			break
		case "Seizure":
			red=65535;green=0;blue=0
			break
		case "Q54":
			red=0;green=0;blue=65535
			break
		case "SJL":
			red=15000;green=15000;blue=15000
			break
		case "Warm":
			red=0; green=0; blue=65535
			break
		case "PTX":
			red=65535;green=0;blue=0
			break
		case "AM-251":
			red=0;green=65535;blue=0
			break
		default:
			if(!no_print)
				printf "Not a valid condition : %s\r",condition
			endif
			red=0;green=0;blue=0
			break
	endswitch
	return num2str(red)+","+num2str(green)+","+num2str(blue)
End

Function Condition2Pattern(condition)
	String condition
	
	strswitch(condition)
		case "Control":
			return 2
			break
		case "Paxilline":
			return 7
			break
		case "Iberiotoxin":
			return 11
			break
		default:
			return 2
			break
	endswitch
End

// Extracts a channel name from a string containing the name of a channel, e.g. "cellL2"
Function /S ExtractChannel(str,channels)
	String str,channels
	Variable i; String channel
	for(i=0;i<ItemsInList(channels);i+=1)
		channel=StringFromList(i,channels)
		if(StringMatch(str,"*"+channel+"*"))
			return channel
		endif
	endfor
	return ""
End

Function /S DFRName(df)
	dfref df
	
	return GetDataFolder(1,df)
End

// Puts a copy of the window recreation macro for the top graph or layout on the clipboard.  
Function /S CopyWinRec([win,append])
	String win
	Variable append
	if(ParamIsDefault(win))
		win=WinName(0,69)
	endif
	String win_rec=WinRecreation(win,0)
	if(append)
		win_rec=GetScrapText()+win_rec
	endif
	PutScrapText win_rec
	return win_rec
End

// Puts single quotes around every part of a name, with a part defined as those words separated by colons.  
// For use when certain parts start with numbers or other folder unfriendly characters.  
Function /S Quote(str)
	String str
	Variable i
	String new_str=""
	for(i=0;i<ItemsInList(str,":");i+=1)
		new_str+="'"+StringFromList(i,str,":")+"':"
	endfor
	if(!StringMatch(str[strlen(str)-1],":"))
		new_str=RemoveEnding(new_str,":")
	endif
	return new_str
End

// Like UniqueName(), except it ensures that a name is unique for many kinds of objects simulatneously.  
// If the name is illegal for reasons other than lack of uniqueness, this function may hang.  
Function /S UniqueName2(name,objects)
	String name
	String objects // Like "6;11" corresponding to a graph window and data folder.  
	Variable illegal=0,i=0
	Do
		String new_name=name+num2str(i)
		illegal=CheckName2(new_name, objects)
		i+=1
	While(illegal)
	return new_name
End

// Like CheckName(), except it checks name for many kinds of objects simulatneously.
Function CheckName2(name,objects)
	String name
	String objects // Like "6;11" corresponding to a graph window and data folder.  
	Variable illegal=0,i
	for(i=0;i<ItemsInList(objects);i+=1)
		Variable object_num=str2num(StringFromList(i,objects))
		illegal+=CheckName(name, object_num)
	endfor
	return illegal
End

Function/S NameOfCallingRoutine()
	String stackList= GetRTStackInfo(0)
	Variable numRoutines=ItemsInList(stackList)
	return StringFromList(numRoutines-3,stackList)
End

Function /S OtherChannel(channel)
	String channel
	strswitch(channel)
		case "R1": 
			return "L2"
			break
		case "L2":
			return "R1"
			break
		default:
			return "R1"
			break
	endswitch
End

Function ProgressPanel()
	if(!WinExist("Progress_Panel"))
		String curr_folder=GetDataFolder(1)
		NewDataFolder /O/S root:ProgressPanel
		Variable /G progress_value=0
		String /G progress_text="No progress yet"
		NewPanel /K=1/N=Progress_Panel	/W=(100,100,455,200)
		ValDisplay Progress barmisc={0,50}, mode=3, limits={0,100,0}, fsize=24,bodyWidth=200,size={200,90},value=#"root:ProgressPanel:progress_value", title="% Complete: "
		TitleBox Progress_text pos={0,50}, fsize=24,variable=root:ProgressPanel:progress_text, frame=0
		SetDataFolder $curr_folder
	else
		DoWindow /F Progress_Panel
	endif
End

// Formats the current date in YYYY.MM.DD format
Function /S FormatDate()
	String date_formatted=Secs2Date(DateTime,-1)	// returns, e.g., 15/03/1993 (2)
	date_formatted=date_formatted[6,9]+"_"+date_formatted[3,4]+"_"+date_formatted[0,1]
	return date_formatted
End

Function Tic([msg]) // Starts the timer.  
	string msg
	newdatafolder /o root:packages
	newdatafolder /o root:packages:Timer
	dfref df=root:packages:Timer
	nvar /z refNum=df:refNum
	if(nvar_exists(refNum))
		variable dummy=StopMsTimer(refNum)
	endif
	killstrings /z df:msg
	if(paramisdefault(msg))
		string /g df:msg="t"
	else
		string /g df:msg=msg
	endif
	variable /G df:refNum=StartMsTimer
End

Function Toc() // Stops the timer and returns the time in milliseconds.  
	dfref df=root:packages:Timer
	NVar /Z refNum=df:refNum
	if(nvar_exists(refNum))
		variable duration=StopMsTimer(refNum)/1000
	else
		return -1
	endif
	svar /z msg=df:msg
	string str
	if(svar_exists(msg) && strlen(msg))
		sprintf str,"%s: %.1f ms",msg,duration
		Post_(str)
	endif
	killvariables /Z refNum,print_
	killstrings /z msg
	return duration
End

Function Tac() // Prints a "split" for the timer.  
	dfref df=root:packages:Timer
	NVar /Z refNum=df:refNum
	if(nvar_exists(refNum))
		variable duration=StopMsTimer(refNum)/1000
	else
		return -1
	endif
	refNum=StartMsTimer
	svar /z msg=df:msg
	string str
	if(svar_exists(msg) && strlen(msg))
		sprintf str,"%s: %.1f ms",msg,duration
		Post_(str)
	endif
	return duration
End

// Executes scrap text one line at a time.  
Function ExecuteScrap()
	String scrap=GetScrapText()
	Variable i; String line
	for(i=0;i<ItemsInList(scrap,"\r");i+=1)
		line=StringFromList(i,scrap,"\r")
		Execute /Q line
	endfor
End

Function OddEven(num)
	Variable num
	if(mod(num,2)==0)
		return 0
	elseif(mod(num,2)==1)
		return 1
	else
		return -1
	endif
End

Function RoundTo(var,places)
	Variable var,places
	var*=10^places
	var=round(var)
	var/=10^places
	return var
End

// Returns the name of any waves exceeding 'minSize' points wherever they are found in any directory.  
Function FindBigWaves(minSize[,df,depth,noShow])
	Variable minSize // A minimum number of points, e.g. 100000
	variable depth // Used by the function recursion.  Ignore.  
	variable noShow // Don't show the table at the end.  
	dfref df // A folder to use as the top level of the search.  Default is root:  
	
	if(paramisdefault(df))
		dfref df=root:
	endif
	if(depth==0)
		NewDataFolder /O root:Packages
		NewDataFolder /O root:Packages:FindBigWaves
		dfref packageDF=root:Packages:FindBigWaves
		Make /o/T/n=0 packageDF:names
		Make /o/n=0 packageDF:sizes
	else
		dfref packageDF=root:Packages:FindBigWaves
	endif
	variable i
	wave /T/sdfr=packageDF names
	wave /sdfr=packageDF sizes
	variable points=numpnts(names)
	for(i=0;i<CountObjectsDFR(df,1);i+=1)
		wave w=df:$getindexedobjnamedfr(df,1,i)
		if(numpnts(w)>minSize)
			names[points]={GetWavesDataFolder(w,2)}
			sizes[points]={numpnts(w)}
			points+=1
		endif
	endfor
	i=0
	Do
		string folder=GetIndexedObjNamedfr(df,4,i)
		if(strlen(folder))
			dfref subDF=df:$folder
			FindBigWaves(minSize,df=subDF,depth=depth+1)
		else
			break
		endif
		i+=1
	While(1)
	if(depth==0)
		sort /R sizes,sizes,names
		if(!noShow)
			if(wintype("BigWaves"))
				dowindow /f BigWaves
			else
				edit /K=1 /N=BigWaves names,sizes as "Big Waves"
			endif
		endif
	endif
End

// Finds a wave no matter which folder it is in.  
Function /S FindWave(name)
	String name
	if(!exists("root:go_root"))
		Variable /G root:go_root
		SetDataFolder root:
	endif
	// Insert arbitrary code to perform in every folder here:  
	String wave_name="",wave_list=WaveList(name,";","")
	if(ItemsInList(wave_list)>0)
		wave_name=StringFromList(0,wave_list)
		Wave theWave=$wave_name
		wave_name=GetWavesDataFolder(theWave,2)
	else
		Variable i=0; String folder=""
		Do
			folder=GetIndexedObjName("",4,i)
			if(!StringMatch(folder,""))
				SetDataFolder $folder
				wave_name=FindWave(name)
				if(strlen(wave_name))
					break
				endif
			else
				break
			endif
			i+=1
		While(1)
	endif
	if(StringMatch(GetDataFolder(1),"root:"))
		KillVariables /Z go_root
	else
		SetDataFolder ::
	endif
	return wave_name
End

Function /S Name2Condition(name)
	String name
	if(StringMatch(name,"*CTL*"))
		return "CTL"
	elseif(StringMatch(name,"*TTX*"))
		return "TTX"
	endif
	return ""
End

// Converts a condition into a color.  Uses pass by reference.  
Function /S Condition2Color2(condition,red,green,blue[,no_print])
	String condition
	Variable &red,&green,&blue
	Variable no_print
	
	strswitch(condition)
		case "Ctl":
			red=0;green=0;blue=0
			break
		case "Control":
			red=0;green=0;blue=0
			break
		case "[NULL]":
			red=0;green=0;blue=0
			break
		case "TTX":
			red=65535;green=0;blue=0
			break
		case "Seizure":
			red=65535;green=0;blue=0
			break
		case "Q54":
			red=0;green=0;blue=65535
			break
		case "SJL":
			red=15000;green=15000;blue=15000
			break
		case "Warm":
			red=0; green=0; blue=65535
			break
		case "PTX":
			red=65535;green=0;blue=0
			break
		case "AM-251":
			red=0;green=65535;blue=0
			break
		default:
			if(!no_print)
				printf "Not a valid condition : %s\r.",condition
			endif
			red=0;green=0;blue=0
			break
	endswitch
	return num2str(red)+","+num2str(green)+","+num2str(blue)
End

// Kill instances of r,g,b as global variables wherever they are found.  Doesn't require compilation first.  
Macro KillRGB()
	if(!exists("root:go_root"))
		Variable /G root:go_root
		SetDataFolder root:
	endif
	KillVariables /Z r,g,b
	Variable i=0; String folder=""
	Do
		folder=GetIndexedObjName("",4,i)
		if(!StringMatch(folder,""))
			SetDataFolder $folder
			KillRGB()
		else
			break
		endif
		i+=1
	While(1)
	if(StringMatch(GetDataFolder(1),"root:"))
		KillVariables /Z go_root
	else
		SetDataFolder ::
	endif
End

// Gets names of folders in the current directory
Function /S DirFolders([match])
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	String folders=DataFolderDir(1)
	folders=StringByKey("FOLDERS",folders)
	folders=ReplaceString(",",folders,";")
	folders=ListMatch(folders,match)
	return folders
End

// Returns a string containg the name of the first data folder with name "folder".  Starts from root: unless start_folder is specified
Function /S FindFolder(find [,start_folder])	
	String find
	String start_folder
	String curr_folder=GetDataFolder(1)
	if(ParamIsDefault(start_folder))
		start_folder="root:"
	endif
	if(StringMatch(find,"root:*")) // If there is a "root:" in the name, it is probably a full folder reference, 
							// so don't bother searching for it.  
		if(datafolderexists(find))
			//SetDataFolder $find
			return find
		endif
	endif
	SetDataFolder $start_folder
	return FindFolderR(find)
End

// The recursion for FindFolder.
Function /S FindFolderR(find)
	String find
	if(DataFolderExists(find))
		return GetDataFolder(1)+find
	else
		String subfolders=StringByKey("FOLDERS",DataFolderDir(1)) // Returns a list of all the folders in the current folder
		String subfolder
		String found=""
		Variable i
		for(i=0;i<ItemsInList(subfolders,",");i+=1)
			subfolder=GetDataFolder(1)+StringFromList(i,subfolders,",")
			SetDataFolder $subfolder
			found=FindFolderR(find)
			if(strlen(found))
				break
			endif
		endfor
		if(!StringMatch(GetDataFolder(1),"root:"))
			SetDataFolder ::
		endif
	endif
	return found
End

Function x2pntbefore(theWave,x)
	Wave theWave
	Variable x
	Variable point=x2pnt(theWave,x)
	Variable x2=pnt2x(theWave,point)
	if(x2>x)
		point-=1
	endif
	return point
End

Function x2pntafter(theWave,x)
	Wave theWave
	Variable x
	Variable point=x2pnt(theWave,x)
	Variable x2=pnt2x(theWave,point)
	if(x2<x)
		point+=1
	endif
	return point
End

// Takes a directory name from the clipboard and puts it into Igor form
Function /S GetDirectory()
	String dir_name=GetScrapText()
	dir_name=ReplaceString("\\",dir_name,":")
	dir_name=ReplaceString("::",dir_name,":")
	return dir_name
End

// Like pnt2x, but for n dimensions
Function pnt2x2(theWave,point,dim)
	Wave theWave
	Variable point,dim
	return dimoffset(theWave,dim)+point*dimdelta(theWave,dim)
End

// Like x2pnt, but for n dimensions
Function x2pnt2(theWave,x,dim)
	Wave theWave
	Variable x,dim
	return (x-dimoffset(theWave,dim))/dimdelta(theWave,dim)
End

// Turns an integer into a string with zeros in the front until there are n digits
Function /S num2ndigits(num,n)
	Variable num,n
	String num_str=num2str(num)
	Variable i
	for(i=strlen(num_str);i<n;i+=1)
		num_str="0"+num_str
	endfor
	return num_str
End


// Converts seconds into minutes:seconds
Function /S Secs2MinsAndSecs(secs)
	Variable secs
	String thyme=""
	Variable minutes=floor(secs/60)
	secs-=minutes*60
	String sec_string=num2str(secs)
	if(secs<10)
		sec_string="0"+sec_string
	endif
	return num2str(minutes)+":"+sec_string
End

Function Convert2ActualTime(wave_name)
	String wave_name
	Wave time_wave=$wave_name
	NVar expStartT=root:status:expStartT
	Variable i
	for(i=0;i<numpnts(time_wave);i+=1)
		time_wave[i]=(time_wave[i]*60)+expStartT
	endfor
End

Function StoreCurs()
	Variable /G root:cursA=xcsr(A)
	Variable /G root:cursB=xcsr(B)
End

Function RecallCurs()
	String traces=TraceNameList("",";", 1) // Get names of waves plotted on topmost graph
	NVar cursA=root:cursA
	NVar cursB=root:cursB
	Cursor A $(StringFromList(0, traces)) cursA
	Cursor B $(StringFromList(0, traces)) cursB
End


// Gets the colors from a list of colors generated using GetTraceColor(). 
Function ColorsFromList(color)
	String color
	Variable /G red=str2num(StringFromList(0,color))
	Variable /G green=str2num(StringFromList(1,color))
	Variable /G blue=str2num(StringFromList(2,color))
End

// Wraps the text 'text' so that the maximum length of a line is 'max_length'
Function /S WrapText(text,max_length)
	String text
	Variable max_length
	String new_text=text
	Variable i,j,iterations=0
	Do
		Make /o/n=0 ReturnLocations
		Do
			Variable location=strsearch(new_text, "\r", i)
			InsertPoints 0,1,ReturnLocations
			ReturnLocations[0]=location
			i=location+1
		While(location>=0)
		ReturnLocations[0]=strlen(text)-1
		WaveTransform /O flip, ReturnLocations
		InsertPoints 0,1,ReturnLocations
		Differentiate /METH=1 ReturnLocations /D=Diffs
		WaveStats /Q Diffs
		if(V_max<=max_length)
			break
		endif
		for(i=0;i<numpnts(ReturnLocations)-1;i+=1)
			location=ReturnLocations[i]
			Variable next_location=ReturnLocations[i+1]
			if(next_location>location+max_length)
				j=location+max_length
				Do
					if(StringMatch(new_text[j]," "))
						new_text[j]="\r"
						break
					endif
					j-=1
				While(j>location)
			endif
		endfor
		iterations+=1
	While(1)
	return new_text
	KillWaves /Z ReturnLocations
End

Function /S ListFolders(inFolder[,match,except])
	string inFolder,match,except
	
	match=selectstring(paramisdefault(match),match,"*")
	except=selectstring(paramisdefault(except),except,"")
	return Core#Dir2("folders",folder=inFolder,match=match,except=except)
End

Function /s DirDFR(df,type[,match,except])
	dfref df
	string type,match,except
	
	match=selectstring(paramisdefault(match),match,"*")
	except=selectstring(paramisdefault(except),except,"")
	return Core#Dir2(type,df=df,match=match,except=except)
End

// Given a number, returns the smallest power of 2 greater than that number.  Useful for padding waves.
Threadsafe Function NextPowerOf2(num)
	Variable num
	Variable i=0;
	Do
		i+=1
	While(2^i<num)
	return 2^i
End

threadsafe Function Pad2(w)
	wave w
	
	return NextPowerOf2(dimsize(w,0))
End

Function /S NumWave2String(theWave)
	Wave theWave
	Variable i
	String str=""
	for(i=0;i<numpnts(theWave);i+=1)
		str+=num2str(theWave[i])+";"
	endfor
	return str
End

Function Units2Num(units)
	String units
	strswitch(units)
		case "100 mM":
			return 100000
			break
		case "10 mM":
			return 10000
			break
		case "mM":
			return 1000
			break
		case "100 µM":
			return 100
			break
		case "10 µM":
			return 10
			break
		case "µM":
			return 1
			break	
		case "microM":
			return 1
			break	
		case "100 nM": 
			return 0.1
			break
		case "10 nM": 
			return 0.01
			break
		case "nM": 
			return 0.001
			break
		default:
			printf "Not valid units : \r",units
			return NaN
			break	 
	endswitch
End

Function DecimalPlaces(var,places)
	Variable var,places
	if(round(places)!=places)
		DoAlert 0,"Places must be an integer [DecimalPlaces]"
	endif
	var*=(10^places)
	var=round(var)
	var/=(10^places)
	return var
End

Function IsNaN(var)
	Variable var
	return !(var>=0 || var<=0)
End

Function SetVars2Nan(var_list)
	String var_list
	Variable i
	for(i=0;i<ItemsInList(var_list);i+=1)
		NVar var=$StringFromList(i,var_list)
		var=NaN
	endfor
End

Function SetStrings2Empty(string_list)
	String string_list
	Variable i
	for(i=0;i<ItemsInList(string_list);i+=1)
		SVar str=$StringFromList(i,string_list)
		str=""
	endfor
End

Function WinExist(name)
	String name
	return strlen(WinList(name,";",""))>0
End

Function /S WaveAxes(trace_name)
	String trace_name
	String info=TraceInfo("",trace_name,0)
	String axes=StringByKey("AXISFLAGS",info)
	return axes
	//String x_axis=StringByKey("XAXIS",info)
	//String y_axis=StringByKey("YAXIS",info)
	//return x_axis+";"+y_axis
End

// Returns the top image in an Image Graph
Function /S TopImage([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String list=ImageNameList(win,";")
	return StringFromList(ItemsInList(list)-1,list)
End

// Takes a comma separated list of numbers and produces the global variables red,green,blue
Function String2Colors(color)
	String color
	color=ReplaceString(",",color,";") // If it is a comma-separated list, turns it into a semicolon-separated list
	Variable /G red,green,blue
	red=str2num(StringFromList(0,color))
	green=str2num(StringFromList(1,color))
	blue=str2num(StringFromList(2,color))
End

Macro Put()
	myText=myText+num2str(xcsr(A))+";"
End

Macro Get()
	PutScrapText myText
End

// Makes the first letter uppercase
Function /S UpperFirst(str)
	String str
	return Upperstr(str[0])+str[1,strlen(str)-1]
End

// Creates a panel to allow function to be run with a GUI.  
Function FunctionPanel(proc_files,function_list[,match])
	String proc_files,function_list,match
	if(ParamIsDefault(match))
		match="*"
	endif
	
	NewDataFolder /O/S root:Packages
	NewDataFolder /O/S FunctionPanel
	String this_folder=GetDataFolder(1)
	DoWindow /K Function_Panel
	NewPanel /N=Function_Panel /K=1 as "Function Panel"
	Variable y_offset=25
	
	Variable i,j; 
	//if(StringMatch(function_list[strlen(function_list)-1],";")
	//function_list=RemoveEnding(function_list)+";"
	for(i=0;i<ItemsInList(proc_files);i+=1)
		String proc_file=StringFromList(i,proc_files)
		function_list+=FunctionList(match,";","WIN:"+proc_file)
	endfor
	for(i=0;i<ItemsInList(function_list);i+=1)
		String function_name=StringFromList(i,function_list)
		String info=FunctionInfo(function_name)
		Button $function_name,title=function_name,pos={85,5+i*y_offset},size={100,20}, proc=FunctionButton	
		Variable n_params=NumberByKey("N_PARAMS",info)
		for(j=0;j<n_params;j+=1)
			Variable param_type=NumberByKey("PARAM_"+num2str(j)+"_TYPE",info)
			String setvar_name=function_name+"_"+num2str(j)
			CreateParameterOrReturn(param_type,1,setvar_name,200+j*50,5+i*y_offset)
		endfor
		Variable return_type=NumberByKey("RETURNTYPE",info)
		setvar_name=function_name+"_r"
		CreateParameterOrReturn(return_type,0,setvar_name,5,5+i*y_offset)
		DrawText 65,i*y_offset-5,"="
	endfor
End

Function CreateParameterOrReturn(type,editable,setvar_name,x,y)
	Variable type,editable,x,y
	String setvar_name
	switch(type)
		case 4: 
			String help="variable"
			Variable /G $setvar_name=0
			if(editable)
				SetVariable $(setvar_name), pos={x,y}, value=$setvar_name, title=" ",help={help}
			else
				ValDisplay $(setvar_name), pos={x,y}, value=#(GetDataFolder(1)+setvar_name), title=" ",help={help}				
			endif
			break
		case 8192:
			help="string"
			String /G $setvar_name=""
			SetVariable $(setvar_name), pos={x,y}, value=$setvar_name, title=" ",help={help}
			break
		default:
			printf "%s is not a variable or a string\r",setvar_name
	endswitch
End

Function FunctionButton(ctrlName) : ButtonControl
	String ctrlName
	String function_name=ctrlName
	String folder="root:Packages:FunctionPanel:"
	String info=FunctionInfo(function_name)
	Variable num_params=NumberByKey("N_PARAMS",info)
	Variable num_opt_params=NumberByKey("N_OPT_PARAMS",info)
	String command
	String return_name=function_name+"_r"
	sprintf command,"%s=%s(",return_name,function_name
	Variable i
	for(i=0;i<num_params;i+=1)
		String param_name=function_name+"_"+num2str(i)
		if(i>num_params-num_opt_params)
			sprintf command,"%s%s,",command,param_name // Will need to change this to include parameter names.  
		else
			sprintf command,"%s%s,",command,param_name
		endif
	endfor
	command=RemoveEnding(command,",")
	command+=")"
	String curr_folder=GetDataFolder(1)
	SetDataFolder $folder
	Execute /Q command
	SetDataFolder $curr_folder
End

Structure PackedFileRecordHeader
	uint16 recordType; 	// Record type plus superceded flag. 
	int16 version;				// Version information depends on the type of record. 
	int32 numDataBytes;			// Number of data bytes in the record following this record header. 
EndStructure

// Extracts window recreation macros from a .pxp file.  
Function ExtractWinRec(file[,path])
	String file,path
	
	Variable refNum
	if(ParamIsDefault(path))
		Open /R refNum as file
	else
		Open /R/P=$path refNum as file
	endif
	
	Struct PackedFileRecordHeader RecordHeader
	String /G recStr=""
	Make /o/B ByteWave
	Make /T/o/n=0 recWave // The text wave that will contain all of the window recreation macros.  
	Variable pos
	Do
		FBinRead /F=0 refNum,RecordHeader
		if(RecordHeader.recordType==4) // Recreation record
			//
			
			//Redimension /B/n=(RecordHeader.numDataBytes) ByteWave
			//FBinRead /F=0 refNum,ByteWave
			Variable i=0,totalChars=0,on=0
			Do
				//Redimension /n=(numpnts(recWave)+1) recWave
				FReadLine /N=(RecordHeader.numDataBytes) /T=num2char(13) refNum,recStr
				totalChars+=strlen(recStr)
				if(StringMatch(recStr,"Window *"))
					on=1
				endif
				if(StringMatch(recStr,"EndMacro*"))
					on=0
					i+=1
				endif
				if(on)
					recWave[i]={recStr}
					i+=1
				endif
			While(totalChars<RecordHeader.numDataBytes)
			//break
			FSetPos refNum, pos+RecordHeader.numDataBytes+8
		else
			Redimension /B/n=(RecordHeader.numDataBytes) ByteWave
			FBinRead /F=0 refNum,ByteWave
		endif
		FStatus refNum
		pos=V_filePos
	While(V_filePos<V_logEOF)
	Close refNum
End

Function MoveObjects(objectList,sourceFolder,destFolder[,saveSource,createDest])
	String objectList // List of data objects.  An optional new name can be given following an : after an item name.  An optional new value can be specified after an equals sign.  
	DFRef sourceFolder,destFolder
	Variable saveSource // Do not kill the object at the source location, i.e. copy instead of moving.  
	Variable createDest // Create the destination object even if nothing was found at the source.  
	
	if(!DataFolderRefStatus(sourceFolder))
		return -1
	endif
	if(!DataFolderRefStatus(destFolder))
		return -1
	endif
	Variable i
	for(i=0;i<ItemsInList(objectList);i+=1)
		String objectInfo=StringFromList(i,objectList)
		String itemName,newItemName,value
		sscanf objectInfo,"%[^,=],%[^,=],=%s",itemName,newItemName,value
		String type=""
		if(ItemsInList(newItemName,":")>1) // If the item format is e.g. "VAR:smith", then the name should be 'smith' and it must be a variable, i.e. other types will be ignored.  
			type=StringFromList(0,itemName,":")
			itemName=StringFromList(1,itemName,":")
		endif
		if(!strlen(newItemName))
			newItemName=itemName
		endif
		if(ItemsInList(newItemName,":")>1) // If the new item format is e.g. "VAR:smith", then the name should be 'smith' and it should be recast as a variable.  
			String newType=StringFromList(0,newItemName,":") // Doesn't actually work yet.  Types will always be preserved.  
			newItemName=StringFromList(1,newItemName,":")
		endif
		SetDataFolder sourceFolder
		if(!strlen(type))
			type=Core#ObjectType(itemName)
		endif
		strswitch(type)
			case "WAV": // Numeric wave.  
				Wave /Z SourceWave=sourceFolder:$itemName
				NVar /Z DestVar=destFolder:$newItemName // See if there is a variable at the destination with the same name.  
				if(WaveExists(SourceWave) && !NVar_Exists(DestVar))
					Duplicate /o SourceWave, destFolder:$newItemName /WAVE=DestWave
					if(!saveSource)
						KillWaves /Z SourceWave
					endif
				elseif(createDest)
					Make /o/n=1 destFolder:$newItemName /WAVE=DestWave
				endif
				if(WaveExists(DestWave) && strlen(value))
					DestWave=str2num(StringFromList(p,value,","))
				endif
				WaveClear DestWave
				break
			case "WAVT": // Text wave.  
				Wave /Z/T SourceWaveT=sourceFolder:$itemName
				if(WaveExists(SourceWaveT))
					Duplicate /o/T SourceWaveT, destFolder:$newItemName /WAVE=DestWaveT
					if(!saveSource)
						KillWaves /Z SourceWaveT
					endif
				elseif(createDest)
					Make /o/T/n=1 destFolder:$newItemName /WAVE=DestWaveT
				endif
				if(WaveExists(DestWaveT) && strlen(value))
					DestWaveT=StringFromList(p,value,",")
				endif
				WaveClear DestWaveT
				break
			case "VAR": // Numeric variable.  
				NVar /Z sourceVar=$itemName
				SetDataFolder destFolder
				if(strlen(value))
					Variable /G $newItemName=str2num(value)
				elseif(NVar_Exists(sourceVar))
					Variable /G $newItemName=sourceVar
					if(!saveSource)
						KillVariables /Z sourceStr
					endif
				elseif(createDest)
					Variable /G $newItemName=NaN
				endif
				break
			case "STR": // String variable.  
				SVar /Z sourceStr=$itemName
				SetDataFolder destFolder
				if(strlen(value))
					String /G $newItemName=value
				elseif(SVar_Exists(sourceStr))
					String /G $newItemName=sourceStr
					if(!saveSource)
						KillStrings /Z sourceStr
					endif
				elseif(createDest)
					String /G $newItemName=""
				endif
				break
		endswitch
	endfor
End

Function MakeObjects(objectList,folder)
	String objectList // List of data objects.  An optional new name can be given following an : after an item name.  An optional new value can be specified after an equals sign.  
	DFRef folder
	
	if(!DataFolderRefStatus(folder))
		return -1
	endif
	Variable i
	for(i=0;i<ItemsInList(objectList);i+=1)
		String objectInfo=StringFromList(i,objectList)
		String type=StringFromList(0,objectInfo,":")
		String flags=StringFromList(1,objectInfo,":")
		String nameAndvalue=StringFromList(2,objectInfo,":")
		String name,value
		sscanf nameAndValue,"%[^=]=%s",name,value
		
		SetDataFolder folder
		strswitch(type)
			case "WAV": // Numeric wave.  
				if(exists(name)!=1) // Not already a numeric or text wave. 
					KillVariables /Z $name
					KillStrings /Z $name
					Execute /Q/Z "Make /o"+flags+" "+name+"="+value
				endif
				break
			case "WAVT": // Text wave.  
				if(exists(name)!=1) // Not already a numeric or text wave. 
					KillVariables /Z $name
					KillStrings /Z $name
					String cmd="Make /o/T"+flags+" "+name+"="+value // Try as is. 
					Execute /Q/Z cmd
					if(V_flag)
						value=RemoveEnding(value,"\"")
						if(StringMatch(value[0],"\""))
							value=value[1,strlen(value)-1]
						endif
						cmd="Make /o/T"+flags+" "+name+"=\""+value+"\"" // Try with quotes.  
						Execute /Q/Z cmd
					endif
				endif
				break
			case "VAR": // Numeric variable.  
				if(exists(name)!=2) // Not already a numeric or string variable. 
					KillWaves /Z $name
					Execute /Q/Z "Variable /G"+flags+" "+name+"="+value
				endif
				break
			case "STR": // String variable.  
				if(exists(name)!=2) // Not already a numeric or string variable.  
					KillWaves /Z $name
					Execute /Q/Z "String /G"+flags+" "+name+"="+value
				endif
				break
		endswitch
	endfor
End

// Duplicate the contents of folder 'source' into folder 'dest', overwriting what is already there in case of a name conflict.  
// Non-conflicting contents of the destination folder will be preserved.  
Function DuplicateFolderContents(source,dest[,except])
	string source,dest,except
	if(ParamIsDefault(except))
		except=""
	endif
	String curr_folder=GetDataFolder(1)
	SetDataFolder $source
	NewDataFolder /O $dest
	Variable i,j; String item,items,type,types="FOLDERS;WAVES;VARIABLES;STRINGS"
	String contents=ReplaceString("\r",DataFolderDir(-1),"")
	for(i=0;i<ItemsInList(types);i+=1)
		type=StringFromList(i,types)
		items=StringByKey(type,contents)
		for(j=0;j<ItemsInList(items,",");j+=1)
			item=StringFromList(j,items,",")
			if(WhichListItem(item,except)<0)
				strswitch(type)
					case "FOLDERS":
						DuplicateFolderContents(source+":"+item,dest+":"+item,except=except)
						break
					case "WAVES":
						Duplicate /o $(source+":"+item),$(dest+":"+item)
						break
					case "VARIABLES":
						Variable /G $(dest+":"+item); NVar num_dest=$(dest+":"+item)
						NVar num_source=$(source+":"+item)
						num_dest=num_source
						break
					case "STRINGS":
						String /G $(dest+":"+item); SVar str_dest=$(dest+":"+item)
						SVar str_source=$(source+":"+item)
						num_dest=num_source
						break
				endswitch
			endif
		endfor
	endfor
	SetDataFolder $curr_folder
End

Function /S StrDefault(condition,true,false)
	Variable condition
	String true,false
	
	if(condition)
		return true
	else
		return false
	endif
End

function TestDebugToggler()
	UnDebug()
	FuncWithRTE()
	PrintDebug()
	ReDebug()
end

function FuncWithRTE()
	make /o/n=101 test0
	fft test0
end

function UnDebug()
	DebuggerOptions
	newdatafolder /o root:Packages
	newdatafolder /o root:Packages:DebugToggler
	variable /g root:Packages:DebugToggler:debugOn=v_enable
	DebuggerOptions enable=0
end

function PrintDebug()
	variable err=GetRTError(1)
	if(err)
		printf GetErrMessage(err)+"\r"
	endif
end

function ReDebug()
	nvar /z debugOn=root:Packages:DebugToggler:debugOn
	if(nvar_exists(debugOn))
		DebuggerOptions enable=debugOn
	endif
end

Function PerformFunctionOnThese(function_name,list,args_before,args_after,to_append)
	String function_name
	String list // Semicolon separated list of things to perform the function on
	String args_before,args_after // Other arguments for the function you want to call, must include preceding and following commas
	String to_append // Something to append to each thing in the list
	Variable i=0
	String thing
	Do
		thing=StringFromList(i,list,";")+to_append
		Execute(function_name+"("+args_before+"\""+thing+"\""+args_after+")")
		i+=1
	While(cmpstr("",StringFromList(i,list,";")))
End

// Recursively kills all items in all folders (the current folder and below) that match 'match' (including the folders).  
Function KillRecurse(match[,except,curr_depth])
	String match
	String except // Will not delete items matching 'except' or recurse into folders matching 'except'.  'except' can be a list and accepts wildcards.  
	Variable curr_depth // Current recursion depth.  
	if(ParamIsDefault(except))
		except=""
	endif
	KillWaveList(match,except=except)
	KillVariableList(match,except=except)
	KillStringList(match,except=except)
	KillDataFolders(match,except=except)
	String folders=DataFolderDir(1)
	folders=StringByKey("FOLDERS",folders)
	Variable i; String folder
	String curr_folder=GetDataFolder(1)
	for(i=0;i<ItemsInList(folders,",");i+=1)
		folder=StringFromList(i,folders,",")
		if(!StringMatch2(folder,except))
			SetDataFolder $curr_folder
			SetDataFolder $folder
			KillRecurse(match,except=except,curr_depth=curr_depth+1)
		endif
	endfor
	if(curr_depth==0) // If this is the initial function for the recursion.  
		SetDataFolder $curr_folder
	endif
End

// Recursively finds the full paths of all folders underneath the current folder in the current experiment.  
Function /S AllFolders([top_folder])
	String top_folder
	if(ParamIsDefault(top_folder))
		top_folder=":"
	endif
	String original_folder=GetDataFolder(1)
	SetDataFolder $top_folder
	String folders=DataFolderDir(1)
	folders=StringByKey("FOLDERS",folders)
	folders=ReplaceString(",",folders,";")+";"
	//print folders
	if(strlen(folders)>1)
		String curr_folder=GetDataFolder(1)
		folders=AddPrefix(folders,curr_folder)
		Variable i; String folder,all_folders=folders
		
		for(i=0;i<ItemsInList(folders);i+=1)
			folder=StringFromList(i,folders)
			if(strlen(folder))
				SetDataFolder folder
				String sub_folders=AllFolders()
				all_folders+=sub_folders
			endif
		endfor
		SetDataFolder $curr_folder
		if(!ParamIsDefault(top_folder))
			SetDataFolder $original_folder
		endif
		return all_folders
	else
		if(!ParamIsDefault(top_folder))
			SetDataFolder $original_folder
		endif
		return ""
	endif
End

// Kills all waves matching match_str in folders listed in folder_list
Function KillWaves2([folders,match])
	String folders, match // folders should be "" to look only in root:; match can contain wildcards
	Variable i,j
	if(ParamIsDefault(folders))
		folders="root:"
	endif
	if(ParamIsDefault(match))
		match="*"
	endif
	String folder, wave_list, wave_name
	String curr_folder=GetDataFolder(1)
	for(i=0;i<ItemsInList(folders);i+=1)
		SetDataFolder curr_folder
		folder=StringFromList(i,folders)
		SetDataFolder folder
		wave_list=WaveList(match,";","")
		for(j=0;j<ItemsInList(wave_list);j+=1)
			wave_name=StringFromList(j,wave_list)
			KillWaves /Z $wave_name
		endfor
	endfor
	SetDataFolder curr_folder
End

// Kills all waves matching "match_str"
Function KillWaveList(match_str[,except])
	String match_str
	String except
	if(ParamIsDefault(except))
		except=""
	endif
	String list=WaveList(match_str,";","")
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		if(!StringMatch2(item,except))
			KillWaves /Z $item
		endif
	endfor
End

// Kills all waves matching "match_str"
Function KillStringList(match_str[,except])
	String match_str
	String except
	if(ParamIsDefault(except))
		except=""
	endif
	String list=StringList(match_str,";")
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		if(!StringMatch2(item,except))
			KillStrings /Z $item
		endif
	endfor
End

// Kills all waves matching "match_str"
Function KillVariableList(match_str[,except])
	String match_str
	String except
	String list=VariableList(match_str,";",4+2)
	if(ParamIsDefault(except))
		except=""
	endif
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		if(!StringMatch2(item,except))
			KillVariables /Z $item
		endif
	endfor
End

// Kills all waves matching "match_str"
Function KillDataFolders(match[,df,except])
	string match,except
	dfref df
	
	except=selectstring(ParamIsDefault(except),except,"")
	if(paramisdefault(df))
		df=:
	endif
	string list=Core#Dir2("folders",df=df,match=match,except=except)
	variable i
	for(i=0;i<ItemsInList(list);i+=1)
		string item=StringFromList(i,list)
		KillDataFolder /Z $item
	endfor
End

// Returns a list of all directories in root_folder (no subdirectories), which is root: if no argument is provided.
Function /S DataFolders([root_folder,no_include])
	String root_folder
	String no_include
	if(ParamIsDefault(root_folder))
		root_folder=GetDataFolder(1)
	endif
	String curr_folder=GetDataFolder(1)
	SetDataFolder root_folder
	String folders=StringByKey("FOLDERS",DataFolderDir(1))
	folders=ReplaceSeparator(folders,",",";") // Replace commas with semicolons for separators
	SetDataFolder curr_folder
	if(!ParamIsDefault(no_include))
		Variable i
		String no
		for(i=0;i<ItemsInList(no_include);i+=1)
			no=StringFromList(i,no_include)
			folders=RemoveFromList(no,folders)
		endfor
	endif
	return folders
End