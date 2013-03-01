// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Databases.ipf $
// $Author: rick $
// $Rev: 599 $
// $Date: 2011-12-16 09:25:15 -0500 (Fri, 16 Dec 2011) $

#pragma rtGlobals=1		// Use modern global access method.

Function SQLConnekt(dbase[username,password])
	String dbase,username,password
	
	String currFolder=GetDataFolder(1)
	if(ParamIsDefault(username))
		username=""
	endif
	if(ParamIsDefault(password))
		password=""
	endif
#if exists("SQLCommand")
	Execute /Q "SQLConnect \""+database+"\",\""+username+"\",\""+password+"\""
#endif
	NewDataFolder /O/S root:Packages
	NewDataFolder /O/S SQL
	String /G database=dbase
	SetDataFolder $currFolder
End

Function SQLDisconnekt()
#if exists("SQLCommand")
	Execute /Q "SQLDisconnect"
#endif
End

Function /S SQL_StringClean(str)
	String str
	str=ReplaceString("'",str,"''")
	return str
End

Function /S SQL_DrugStr([drug,no_drug])
	String drug,no_drug
	String drug_str=""
	Variable i
	if(!ParamIsDefault(drug) && !StringMatch(drug,"NULL"))
		if(strlen(drug)>0)
			for(i=0;i<ItemsInList(drug);i+=1)
				String one_drug=StringFromList(i,drug)
				drug_str+=" AND Drug LIKE '%"+one_drug+"%'"
			endfor
		else
			drug_str+=" AND Drug IS NULL"
		endif
	endif
	if(!ParamIsDefault(no_drug) && !StringMatch(no_drug,"NULL"))
		if(strlen(no_drug)>0)
			drug_str+=" AND (Drug IS NULL OR ("
			for(i=0;i<ItemsInList(no_drug);i+=1)
				one_drug=StringFromList(i,no_drug)
				drug_str+="Drug NOT LIKE '%"+one_drug+"%' AND "
			endfor
			drug_str=RemoveEnding(drug_str," AND ")
			drug_str+="))"
		else
			drug_str+=" AND Drug IS NOT NULL"
		endif
	endif
	return drug_str
End

Function /S SQL_GetColumnNames(table_name)
	String table_name
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:SQLgcn
	String sql_str="SELECT * FROM "+table_name+" WHERE 1=2" // ensures zero-length waves.  
	SQLc(sql_str)
	String column_names=WaveList("*",";","")
	KillDataFolder root:SQLgcn
	if(DataFolderExists(curr_folder))
		SetDataFolder $curr_folder
	else
		SetDataFolder root:
	endif
	return column_names
End

Function SQLc(sql_str[,show,db])
	String sql_str,db
	Variable show
	String command
	sql_str=ReplaceString("<<<",sql_str,"\"+")
	sql_str=ReplaceString(">>>",sql_str,"+\"")
	sql_str=ReplaceString("NaN",sql_str,"NULL")
	sql_str=ReplaceString("''",sql_str,"NULL")
	sql_str=ReplaceString("' '",sql_str,"NULL")
	sql_str=lowerstr(sql_str) // Make all letters lowercase since table names are probably lowercase.  
//	if(exists(sql_str)) // If the string passed is the name of a global string variable.  
//		SVar actual_sql_str=$sql_str
//		actual_sql_str=ReplaceString("\"",actual_sql_str,"\\\"")
//		command="SQLCommand $sql_str"
//	else // Otherwise, interpret the string as the text of the command itself.  
//		command="SQLCommand \""+sql_str+"\""
//	endif
	if(show)
		printf "%s\r",sql_str
	endif
#if exists("SQLCommand") // If we are using the Bruxton SQL XOP.  
	command="SQLCommand \""+sql_str+"\""
	if(strlen(command)>400)
		DoAlert 0,"Cannot execute a string of greater than 400 characters on the command line."
		return -1
	else
		Execute /Q command
	endif
#elif exists("SQLHighLevelOp") // If we are using the Wavemetrics SQL XOP.  
	dfref df = root:Packages:SQL
	if(!datafolderrefstatus(df))
		newdatafolder /o root:Packages:SQL
		dfref df = root:Packages:SQL
		string /g df:database="reverb"
	endif
	svar /sdfr=df database	
	if(paramisdefault(db))
		db=database
	else
		database=db
	endif
	Variable debuggerOn
	DebuggerOptions debugOnError=0
	
	// On Windows or Mac
	SQLHighLevelOp /CSTR={"DSN="+db,SQL_DRIVER_COMPLETE} /O /E=0 sql_str
	
	// In Wine (on Linux)
	//SQLHighLevelOp /CSTR={"DSN="+db+";UID=rick;PWD=toto",SQL_DRIVER_NOPROMPT} /O /E=0 sql_str
	
	if (GetRTError(0))
		printf "%s\r",sql_str
		printf "%s\r",GetRTErrMessage()
		DebuggerOptions debugOnError=1
		return GetRTError(1)
	endif
	DebuggerOptions debugOnError=1
#else
	DoAlert 0,"There is no SQL XOP (Bruxton or Wavemetrics) installed."  
#endif
End

// Does not support individual text fields of greater than 254 characters.  Limitation of the XOP.  
Function SQLbc(sql_str,xop_str)
	String sql_str,xop_str
	String command
	//if(exists(sql_str)) // If the string passed is the name of a global string variable.  
	//	command="SQLBulkCommand "+sql_str
	//else // Otherwise, interpret the string as the text of the command itself.  
	//	command="SQLBulkCommand \""+sql_str+"\""
	//endif
	command="SQLBulkCommand \""+sql_str+"\","+xop_str
	if(strlen(command)>400)
		DoAlert 0,"Cannot execute a string of greater than 400 characters on the command line."
		abort
	else
		Execute /Q command
	endif
	
End

Function /S SQLValueString(values)
	String values
	Variable i
	String sql_value_str=""
	for(i=0;i<ItemsInList(values);i+=1)
		sql_value_str+="'"+StringFromList(i,values)+"',"
	endfor
	sql_value_str=sql_value_str[0,strlen(sql_value_str)-2] // Remove final comma
	return sql_value_str
End

// For a new (empty) field to a table in Access, and then I want to fill that field with the values
// they should have based on the corresponding field in another table.  
Function FillNewField()
	// Not yet implemented.  
End

// Selects fields from all the tables in the Spikes Database such that 'where' is satisfied, and an
// inner join is met (in this case the primary keys must match).  
Function SQLSelect(fields,where,depth)
	String fields // Fields must start with A1., etc. to disambiguate between fields with the same name in different tables.  
	String where // e.g. "A1.File_Name='060917B' AND A1.Exp='RCG'"
	Variable depth // If you are only searching parameters in the first 2 tables, the depth should be 2.  Depth must be a number from 1 to 3.  
	
	String tables
	
	String /G fieldsG,whereG,tablesG // Doing it this way overcomes the 400 character limit for command line operations.  
	fieldsG=fields
	if(depth>=1)
		tablesG="Pair_Record A1"
		whereG=" WHERE "+where
	endif
	if(depth>=2)
		tablesG+=",Inductions A2"
		whereG+=" AND A1.ExperimentID = A2.ExperimentID"
	endif
	if(depth>=3)
		tablesG+=",Trials A3"
		whereG+=" AND A2.InductionID = A3.InductionID" 
	endif
	if(StringMatch(whereG," WHERE "))
		whereG=""
	endif
	
	String sql_command="SQLCommand \"SELECT \"+fieldsG+\" FROM \"+tablesG+whereG"
	//String command_str="SQLCommand \""+sql_command+"\""
	Execute /Q sql_command
	KillStrings fieldsG,whereG,tablesG
End

// Update file names to the current "YYYY_MM_DD_L" format.  
Function UpdateFileNames2()
	SQLConnekt("Reverb")
	String tables="Activity_Summary;ChargeBeforeAfter;CNQX;Connectivity;Event_Analysis;F_I;Mini_Segments;Mini_Sweeps;"
	tables+="Reverb_Properties;Sweep_Record;Sweep_Analysis;Transitions"
	String command
	Variable i
	for(i=0;i<ItemsInList(tables);i+=1)
		String table=StringFromList(i,tables)
		String columns=SQL_GetColumnNames(table)
		if(WhichListItem("Experimenter",columns)>=0)
			command="SELECT Experimenter FROM "+table+" WHERE Experimenter='PML'"
			SQLc(command)
			Wave /T Experimenter
			if(numpnts(Experimenter))
				UpdateFileNames(table," AND Experimenter='RCG'")
				continue
			endif
		endif
		UpdateFileNames(table,"")
	endfor
	SQLDisconnekt()
End
	
// Auxiliary function for UpdateFileNames2().  Works on each table.  	
Function UpdateFileNames(table,experimenter)
	String table // Name of the table.  
	String experimenter // Not the literal name, but "AND Experimenter = 'RCG'" if applicable.  Leave as "" for no experimenter qualification.  
	
	Variable i
	String command="SELECT File_Name FROM "+table+" WHERE File_Name LIKE '06%'"+experimenter
	SQLc(command)
	Wave /T File_Name
	for(i=0;i<numpnts(File_Name);i+=1)
		String name=File_Name[i]
		String new_name="2006_"+name[2,3]+"_"+name[4,5]+"_"+name[6]
		command="UPDATE "+table+" SET File_Name='"+new_name+"' WHERE File_Name='"+name+"'"
		SQLc(command)
	endfor
	
	command="SELECT File_Name FROM "+table+" WHERE File_Name LIKE '2007.%'"+experimenter
	SQLc(command)
	Wave /T File_Name
	for(i=0;i<numpnts(File_Name);i+=1)
		name=File_Name[i]
		new_name="2007_"+name[5,6]+"_"+name[8,9]+"_"+name[11]
		command="UPDATE "+table+" SET File_Name='"+new_name+"' WHERE File_Name='"+name+"'"
		SQLc(command)
	endfor
	//command+="SELECT * FROM 
	//SQLDisconnekt()
End

// Insert file names from 'Island_Record' into some other table.  
// Programmed specifically for a certain task, but the code can be made general.  
Function InsertFileNames()
	SQLConnekt("Reverb")
	SQLc("SELECT File_Name FROM Island_Record WHERE TTX_Patch=1 OR TTX_Patch IS NULL ORDER BY File_Name")
	Duplicate /o/T File_Name,Files
	Variable i
	for(i=0;i<numpnts(Files);i+=1)
		String file=Files[i]
		String command="SELECT File_Name FROM Connectivity WHERE File_Name='"+file+"'"
		SQLc(command)
		Wave /T File_Name
		if(numpnts(File_Name))
			continue
		endif
		command="INSERT INTO Connectivity (File_Name,Channel) VALUES ('"+file+"','R1')"
		SQLc(command)
		command="INSERT INTO Connectivity (File_Name,Channel) VALUES ('"+file+"','L2')"
		SQLc(command)
	endfor
	SQLDisconnekt()
End

#pragma rtGlobals=1		// Use modern global access method.

Function SQL()
	String currFolder=GetDataFolder(1)
	NewDataFolder /O/S root:Packages
	NewDataFolder /O/S SQL
	if(!exists("CommandHistory"))
		Make /o/n=1/T CommandHistory=""
	endif
	Make /o/n=5/T Command="",CurrCommand=""
	Make /o/n=5 SQLSelWave=2
	DoWindow /K SQLPanel
	NewPanel /K=1/W=(100,100,800,188) /N=SQLPanel as "SQL Panel"
	Button Enter, pos={10,5}, size={675,20}, title="Query", proc=SQLPanelButtons
	Listbox CommandLine, pos={10,25},size={675,49}, ListWave=Command, SelWave=SQLSelWave, title=" ",proc=SQLPanelListboxes
	SetVariable CommandHistory,pos={685,25},size={10,25}, value=_NUM:0, userData=num2str(-1), title=" ",proc=SQLPanelSetVariables
	SetDataFolder $currFolder
End

Function SQLPanelButtons(ctrlName)
	String ctrlName
	
	strswitch(ctrlName)
		case "Enter":
			Wave /T Command=root:Packages:SQL:Command
			Variable i=0
			String commandStr=""
			Do
				if(strlen(Command[i]))
					commandStr+=Command[i]+" "
				endif
				i+=1
			While(i<numpnts(Command))
			if(strlen(commandStr))
				SQLc(commandStr)
				Wave /T CommandHistory=root:Packages:SQL:CommandHistory
				InsertPoints 0,1,CommandHistory
				CommandHistory[0]=commandStr
				Wave /T CurrCommand=root:Packages:SQL:CurrCommand
				CurrCommand=Command
			endif
	endswitch
End

Function SQLPanelSetVariables(info) :  SetVariableControl
	STRUCT WMSetVariableAction &info
	Variable code=info.eventCode
	if(code!=1 && code!=2)
		return -1
	endif
	strswitch(info.ctrlName)
		case "CommandHistory": 
			if(code==1) // Mouse up.  
				Wave /T Command=root:Packages:SQL:Command
				Wave /T CommandHistory=root:Packages:SQL:CommandHistory
				Variable entries=numpnts(CommandHistory)
				Variable num=info.dval
				Variable oldNum=str2num(GetUserData("","CommandHistory",""))
				if(num>=0 && oldNum==-1)
					Duplicate /o/T Command root:Packages:SQL:CurrCommand
				endif
				num=limit(info.dval,-1,entries-1)
				SetVariable CommandHistory,value=_NUM:num, userData=num2str(num)
				if(num==-1)
					Wave /T CurrCommand=root:Packages:SQL:CurrCommand
					Command=CurrCommand
				else
					Variable i=0
					Command=""
					Do
						Command[i]=(CommandHistory[num])[i*255,(i+1)*255]
						i+=1
					While(i<strlen(CommandHistory[num])/255)
				endif
			endif  
			break
	endswitch
End

Function SQLPanelListboxes(info)
	Struct WMListBoxAction &info
	strswitch(info.ctrlName)
		case "CommandLine":
			break
	endswitch
End

