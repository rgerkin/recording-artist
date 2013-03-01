#pragma rtGlobals=1		// Use modern global access method.
#pragma IndependentModule=Core

Menu "Procedure", dynamic
       "Commentize/8",/Q, Execute/P/Q/Z "DoIgorMenu \"Edit\", \"Commentize\""
       "Decommentize/9",/Q, Execute/P/Q/Z "DoIgorMenu \"Edit\", \"Decommentize\""
End

function /s FLAGS_()
	return "Dev;Acq;Nlx"
end

Function Def(list[,recompile])
	String list
	Variable recompile
	
	recompile=ParamIsDefault(recompile) ? 1 : recompile
	DefUndef("def",list,recompile=recompile)
End 

Function Undef(list[,recompile])
	String list
	Variable recompile
	
	recompile=ParamIsDefault(recompile) ? 1 : recompile
	DefUndef("undef",list,recompile=recompile)
End

Function DefUndef(type,list[,recompile])
	String type,list // 'type' is "def" or "undef", and 'list' is the list of symbols.  
	Variable recompile // 1 to recompile, 0 to not.  
	
	recompile=ParamIsDefault(recompile) ? 1 : recompile
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		String symbol=StringFromList(i,list)
		if(strlen(symbol))
			Execute /Q "SetIgorOption pound"+type+"ine="+symbol
		endif
	endfor
	String OS=IgorInfo(2); OS=OS[0,2]
	if(StringMatch(type,"def"))
		Execute /Q "SetIgorOption poundDefine="+OS
	endif
	
	if(recompile)
		Compile()
	endif
End

Function IsDef(symbol)
	string symbol
	
	ExperimentModified; variable modified=v_flag
	Execute /Q "SetIgorOption poundDefine="+symbol+"?"
	nvar v_flag_=v_flag
	ExperimentModified modified
	return v_flag_
End

function AllDefs()
	variable i
	for(i=0;i<itemsinlist(FLAGS_());i+=1)
		string flag=stringfromlist(i,FLAGS_())
		variable on=IsDef(flag)
		printf "%s = %d\r",flag,on
	endfor
end

Function Compile()
	//ExperimentModified; Variable modified=V_flag
	printf "Recompiling...\r"
	Execute /Q/P "Silent 101"
	//Execute /Q/P "ExperimentModified "+num2str(modified)
	// Next four lines are just to get to recompile with new symbol definition.  
//	Execute /Q/P "INSERTINCLUDE \"Dummy\"" // Marks procedure files as needing compilation.  
//	Execute /Q/P "COMPILEPROCEDURES " // Will update the previous global definition only after this function is finished executing. 
//	Execute /Q/P "DELETEINCLUDE " // Marks procedure files as needing compilation.  
//	Execute /Q/P "COMPILEPROCEDURES " // Will update the previous global definition only after this function is finished executing. 
End

Menu "Misc"
	Submenu "Procedure Files"
		Core#DevString(),/Q,Core#Dev(!Core#IsDev())
		//"SVN Update [Dev]",/Q,SVNUpdate()
		SelectString(Core#IsDef("errLog"),"Turn Error Logging On","Turn Error Logging Off"),/Q,GetLastUserMenuInfo;Core#DefUnDef(selectstring(stringmatch(s_value,"*On"),"Undef","Def"),"errLog")
 		SubMenu "Load..."
			"Core",Core(1)
			"Basics",Def("Basics")
			"Acquisition",Def("Acq")
		End
		SubMenu "Unload..."
			"Core",Core(0)
			"Basics",Undef("Basics")
			"Acquisition",Undef("Acq")
			"Profiles",Undef(Core#ProfileList())
		End
		"Force Compile",/Q,Silent 101
	End
End

Function Dev(on)
	variable on
	if(on)
		printf "Switching to development version...\r"
		Def("Dev")
	else
		printf "Switching to stable version...\r"
		Undef("Dev")
	endif
End

Function IsDev()
	ExperimentModified; variable modified=v_flag
	Execute /Q/Z "SetIgorOption poundDefine=Dev?"
	Execute /Q/Z "variable /g root:v_dev=v_flag"
	nvar /z v_dev=root:v_dev
	ExperimentModified modified
	if(nvar_exists(v_dev) && v_dev)
		return 1
	else
		return 0
	endif
End

Function /S DevString()
	string str
	
	ExperimentModified; variable modified=v_flag
	if(IsDev())
		str="Switch to stable version"
	else
		str="Switch to development version"
	endif
	ExperimentModified modified
	
	return str
End

Function /S ProfileList()
	String fullPath = SpecialDirPath("Packages", 0, 0, 0)+"Profiles:" // Get path to Packages preferences directory on disk.
	NewPath/O/C/Q/Z profilesPath, fullPath // Create a directory in the Packages directory for this package
	String allprofiles=IndexedFile(profilesPath,-1,".bin")
	String list=""
	Variable i
	for(i=0;i<ItemsInList(allprofiles);i+=1)
		String profile=StringFromList(i,allprofiles)
		list+=RemoveEnding(profile,".bin")+";"
	endfor
	if(!strlen(list))
		printf "No profiles found [profileList()].\r"
	endif
	return list
End

Function /S Core(load)
	Variable load // 1 to load, 0 to unload.  
	
	Execute /Q "SetIgorOption independentModuleDev=1"
	string userProcs=SpecialDirPath("Igor Pro User Files",0,0,0)+"User Procedures"
	NewPath /O/Z/Q CodeCorePath, userProcs+":Code:Core:"
	if(v_flag)
		NewPath /O/Z/Q CodeCorePath, userProcs+":Core:"
	endif
	String coreList=""
	String currProcs=WinList("*",";","WIN:128,INDEPENDENTMODULE:1")
	Variable i=0
	Do
		String file=IndexedFile(CodeCorePath,i,".ipf")
		if(StringMatch(file,"Symbols*"))
			if(!load)
				i+=1
				continue // Never unload symbols because then you lose this function.  
			endif
		endif
		if(strlen(file))
			string procName=file
			variable loaded=WhichListItem(procName,currProcs)>=0
			if(!loaded)
				procName=file+" [Core]"
				loaded=WhichListItem(procName,currProcs)>=0
			endif
			if(load*!loaded)
				Execute /Q/P "OpenProc /P=CodeCorePath /R /V=0 \""+file+"\""
			elseif(!load*loaded)
				Execute /Q/P "CloseProc /NAME=\""+procName+"\""
			endif
			coreList+=RemoveEnding(file,".ipf")+";"
			i+=1
		else
			break
		endif
	While(strlen(file))
	Execute /Q "SetIgorOption independentModuleDev=0"
	if(load)
		Execute /Q "SetIgorOption poundDefine=Core"
	else
		Execute /Q "SetIgorOption poundUnDefine=Core"
	endif
	return coreList
End

Function SVNUpdate()
	DoAlert 1,"Close all procedure files, update, and reload them?  Unsaved changes to procedure files will be lost."
	Variable i
	if(V_flag==1)
		String cmdList=CloseAllProcs(exec=0); // Generate a list of procedure closing commands.  For some reason directly executing CloseAllProcs(exec=1) in the execute queue doesn't work correctly.  
		for(i=0;i<ItemsInList(cmdList);i+=1)
			String cmd=StringFromList(i,cmdList)
			Execute /Q/P cmd // Execute each procedure closing.  This does 
		endfor
		cmd="TortoiseProc /command:update /path:"
		String codePath=specialdirpath("Igor Pro User Files",0,0,0);
		codePath=removeending(codePath,":")+":User Procedures"
		NewPath /O/Q CodePath, codePath
		Execute /Q/P "ExecuteScriptText /B/Z \""+cmd+"\\\""+codePath+"\\\"\"" // Extra slashes needed to escape the quotes in the command.  
		//Execute /Q/P "Silent 101" // Recompile so Igor knows that every procedure has been closed.  
		Execute /Q/P "OpenProc /P=CodePath /V=1 \":Core:Symbols.ipf\""//; printf \"Open Symbols\""
		Execute /Q/P "Silent 101"//; printf \"Recompile\"" // Recompile to get access to functions in 'Symbols'.  
		Execute /Q/P "Core#Core(1)"//; printf \"Load Core\"" // Load core procedure files.  
		//Execute /Q/P "Symbols#Def(\"Acq\")" // Set acquisition files to be loaded.  
		Execute /Q/P "Silent 101" // Recompile.  
	endif
End

Function SVNVersion()
	variable version=0
	NewPath /o/q/z CodeSVN removeending(SpecialDirPath("Igor Pro User Files",0,0,0),":")+":User Procedures:.svn"
	if(!v_flag)
		variable refNum
		open /z/r/p=CodeSVN refNum as "entries"
		string line
		do
			freadline refNum,line
			if(stringmatch(line,"dir*"))
				freadline refNum,line
				version=str2num(line)
				break
			endif
		while(strlen(line))
		close refnum
	endif
	return version
End

Function /S CloseAllProcs([except,exec])
	String except
	Variable exec
	
	if(ParamIsDefault(except))
		except=""
	endif
	exec=ParamIsDefault(exec) ? 1 : exec
	Execute /Q "SetIgorOption IndependentModuleDev=1"
	String currProcs=WinList("*",";","WIN:128,INDEPENDENTMODULE:1")
	Variable i=0
	String cmdList=""
	for(i=0;i<ItemsInList(currProcs);i+=1)
		String procName=StringFromList(i,currProcs)
		Variable pos=strsearch(procName,"[",0)
		if(pos>=0) // If this has an independent module name. 
			//procName=procName[0,pos-2]// Truncate it to be compatible with CloseProc.  
		endif
		if(WhichListItem(except,procName)>=0)
			continue // Do not close procedures on the except list.  
		endif
		if(StringMatch(procName,"Procedure"))
			continue // Do not close experiment procedure file.  
		endif
		
		String cmd
		sprintf cmd, "CloseProc /NAME=\"%s\"",procName
		if(exec)
			Execute /Q/P cmd
		endif
		cmdList+=cmd+";"
	endfor
	Execute /Q "SetIgorOption independentModuleDev=0"
	if(exec)
		Execute /Q/P "Silent 101"
	endif
	return cmdList
End
