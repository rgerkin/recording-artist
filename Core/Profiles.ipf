// Don't write anything above this line! //
#pragma rtGlobals=1		// Use modern global access method.
#pragma IndependentModule=Core

// Depends upon Symbols.ipf, but should not be explicitly included because in most installations a link
// to a directory (Core) containing Symbols.ipf already exists in the Igor Procedures folder.  

static strconstant editor="EditProfilesWin"
static strconstant moduleInfo_="root:Packages:Profiles"
strconstant FLAGS_LONG="Developer;Acquisition;Neuralynx"
constant DEV=0
constant ACQ=1
constant NLX=2
constant maxprofiles=25

function /s ModuleInfo()
	return moduleInfo_
end

// Get the current profile based on the directory immediately above the desktop.  
Function /S GetOSUser()
	string desktop=SpecialDirPath("Desktop",0,0,0)
	return StringFromList(ItemsInList(desktop,":")-2,desktop,":")
End

function /s GetProfilesPath()
	return SpecialDirPath("Packages", 0, 0, 0)+"Profiles:"
end

function /s GetProfilePath(profile)
	string profile
	
	return GetProfilesPath()+profile
end

Menu "Profiles"
	Core#ListProfiles(init=1,brackets=1), /Q, Core#ProfileMenu()
	"--------------"
	"Edit Profiles", /Q, Core#EditProfiles()
	SubMenu "Edit Modules"
		Core#ListProfileModules(Core#CurrProfileName()), /Q, GetLastUserMenuInfo; Core#EditModule(s_value)
	End
End

Function EditProfiles()
	InitProfiles()
	LoadModuleManifests()
	DoWindow /K $editor
	NewPanel /K=1 /N=$editor /W=(100,100,800,500) as "Profile Settings"
	string profiles=ListProfiles()+"_new_;"
	dfref df=ProfilesDF()
	svar /sdfr=df profileName
	SetVariable CurrProfile value=profileName, disable=2, bodywidth=100, title="Current Profile:"
	variable i,xx=100,xJump=75
	for(i=0;i<itemsinlist(profiles);i+=1)
		string profileName_=stringfromlist(i,profiles)
		ShowProfile(profileName_,xx+i*xJump)
	endfor
	BuildMenu "Profiles"
End

SetVariable ProfileName variable=root:Packages:Profiles:profile, disable=2, title="Profile:",pos={2,5},size={100,25}

function ShowProfile(profileName,xx)
	string profileName
	variable xx
	
	variable yy=30,yJump=30,xMargin=5
	struct profileInfo profile
	if(stringmatch(profileName,"_new_"))
		variable new=1
	else
		GetProfileInfo(profile,name=profileName,forceLoad=1)
	endif
	string userData="NAME:"+profileName
	variable width=fontsizestringwidth("Default",10,0,profileName)*72/ScreenResolution
	if(new)
		width=65
		SetVariable NewName, pos={xx+30-width/2,yy+2}, bodywidth=width, value=_STR:"", title=" ", userData=userData
	else
		TitleBox $("Title_"+profileName), pos={xx+7-width/2,yy}, title=profileName
	endif
	yy+=yJump
	TitleBox $("Title_Dev"), pos={xMargin,yy-5}, title="Developer"
	Checkbox $Hash32("isDev_"+profileName), pos={xx+5,yy}, value=IsDeveloper(profile), title=" ",proc=Core#EditProfilesCheckboxes, userData="INFO:isDev;"+userData
	yy+=yJump
	string modules=ListAvailableModules()
	variable i
	for(i=0;i<itemsinlist(modules);i+=1)
		string module=stringfromlist(i,modules)
		TitleBox $("Title_"+module), pos={xMargin,yy-5}, title=ModuleTitle(module)
		Checkbox $Hash32("has"+module+"_"+profileName), pos={xx+5,yy}, value=HasModule(profile,module), title=" ",proc=Core#EditProfilesCheckboxes, userData="INFO:has"+module+";"+userData
		yy+=yJump
	endfor
	variable xButtons=-12
	if(new)
		Button Add,pos={xx+xButtons,yy},proc=EditProfilesButtons,title="Add", userData="ACTION:add;"+userData
		yy+=yJump
		PopupMenu Clone,pos={xx+xButtons,yy},title="Clone",mode=1,value=#"\" ;\"+Core#ListProfiles()"
	else	
		Button $Hash32("Update_"+profileName),pos={xx+xButtons,yy},proc=EditProfilesButtons,title="Update", userData="ACTION:update;"+userData
		yy+=yJump
		Button $Hash32("Delete_"+profileName),pos={xx+xButtons,yy},proc=EditProfilesButtons,title="Delete", userData="ACTION:delete;"+userData
	endif
end

function /s Hash32(name[,length])
	string name
	variable length
	
	length=paramisdefault(length) ? 30 : length // Return only a 31 character string, since some controls will not take a 32 character name.  
	name=UpperStr(name)
	string result=hash(name,1)
	return "x"+result[0,length-1] 
end

function EditProfilesButtons(ctrlName)
	string ctrlName
	
	string userData=GetUserData(editor,ctrlName,"")
	string action=stringbykey("ACTION",userData)
	string profileName=stringbykey("NAME",userData)
	struct profileInfo profile
	string currProfile=CurrProfileName()
			
	strswitch(action)
		case "Update":
			GetProfileInfo(profile,name=profileName)
			UpdateProfile(profile)
			if(stringmatch(profileName,currProfile))
				SetProfile(profileName)
			endif
			break
		case "Delete":
			GetProfileInfo(profile,name=profileName)
			DeleteProfile(profile)
			InitProfiles()
			break
		case "Add":
			controlinfo NewName
			profile.name=s_value
			controlinfo Clone
			profile.style=selectstring(v_value>1,"_default_",s_value)
			if(!NewProfile(profile))
				EditProfiles()
			endif
			break
	endswitch
end

function UpdateProfile(profile[,new,quiet])
	struct profileInfo &profile
	variable new,quiet
	
	string profileName=selectstring(new,profile.name,"_new_")
	controlinfo $Hash32("isDev_"+profileName)
	profile.dev=v_value
	string modules=ListAvailableModules()
	variable i=0
	do
		string module=stringfromlist(i,modules)
		controlinfo $Hash32("has"+module+"_"+profileName)
		if(v_flag>0 && v_value)
			i+=1
		else
			modules=RemoveFromList(module,modules)
		endif
	while(i<itemsinlist(modules))
	if(stringmatch(profile.name,"_new_"))
		controlinfo NewName
		profile.name=s_value
	endif
	SetProfileModules(profile,modules)
	// Another kludge.    
	if(profile.dev==0)
		//LoadPackageDefinitionsOld()
	endif
	// End Kludge.  
		
	//DefUndef(selectstring(value,"Undef","Def"),flag,recompile=1)
	//StructPut /S profile, root:Packages:profiles:profile	
	//if(value)
	//	Execute /Q/P/Z "ProcGlobal#LoadPackageDefinitions(\""+flag+"\")" // Load package definitions for the new profile.  
	//endif
	//Execute /Q/P/Z "EditProfilePackages()"
	if(!new)
		SaveProfile(profile,quiet=quiet)
	endif
end

function SetProfileModules(profile,modules)
	struct profileInfo &profile
	string modules
	
	profile.modules=""
	string allModules=ListAvailableModules()
	variable i
	for(i=0;i<itemsinlist(allModules);i+=1)
		string module=stringfromlist(i,allModules)
		if(whichlistitem(module,modules)>=0)
			AddModule(profile,module)
		endif
		//else
		//	RemoveModule(profile,module)
		//endif
	endfor
end

function EditProfilesCheckboxes(ctrlName,value)
	string ctrlName
	variable value

	string userData=GetUserData(editor,ctrlName,"")
	string info=stringbykey("INFO",userData)
	string profileName=stringbykey("NAME",userData)
	string modules=ListAvailableModules()
	
	variable changes=0,tries=0
	do
		variable i,j
		for(i=0;i<itemsinlist(modules);i+=1)
			string module=stringfromlist(i,modules)
			string control=Hash32("has"+module+"_"+profileName)
			controlinfo $control
			if(v_flag>0 && v_value)
				dfref df=ModuleManifest(module)
				if(datafolderrefstatus(df))
					svar /z/sdfr=df requires
					if(svar_exists(requires))
						for(j=0;j<itemsinlist(requires);j+=1)
							string require=stringfromlist(j,requires)
							control=Hash32("has"+require+"_"+profileName)
							controlinfo $control
							if(v_flag<=0 || !v_value)
								printf "Module '%s' requires module '%s'.\r",module,require
								control=Hash32("has"+module+"_"+profileName)
								checkbox $control value=0
								changes+=1
							endif
						endfor
					endif
					nvar /z/sdfr=df dev
					if(nvar_exists(dev))
						control=Hash32("isDev_"+profileName)
						controlinfo $control
						if(v_flag>0)
							string onOff=""
							if(dev && !v_value)
								onOff="on"
							elseif(!dev && v_value)
								onOff="off"
							endif
							if(strlen(onOff))
								printf "Module '%s' requires the developer setting be turned %s.\r",module,onOff
								control=Hash32("has"+module+"_"+profileName)
								checkbox $control value=0
								changes+=1
							endif
						endif
					endif
				endif
			endif
		endfor
		tries+=1
	while(changes>0 && tries<10)
end

//function /df ModuleManifest(module)
//	string module
//	
//	dfref df=ProfilesDF()
//	string loc=getdatafolder(1,df)+module+":Manifest"
//	dfref df=$loc
//	return df
//end

Function /S ListProfiles([brackets,init]) 
	variable brackets,init
	
	ExperimentModified; variable modified=V_flag
	if(init)
		InitProfiles()
	endif
	InitProfilesPath()
	make /free/t/n=0 profileNames
	make /free/n=0 lastUse
	struct profileInfo profile
	
	string profiles=IndexedFile(Profiles,-1,".bin")
	profiles=replacestring(".bin",profiles,"")
	if(!strlen(profiles) && init)
		InitProfiles()
	endif
	variable i=0
	do
		string oneProfile=StringFromList(i,profiles)
		GetProfileInfo(profile,name=oneProfile,forceLoad=1)
		//if(!strlen(profile.name))
		//	printf "Null name for profile file '%s'.\r",oneprofile
		//endif	
		if(profile.selected)
			profileNames[i]={profile.name}
			lastUse[i]={profile.selected-2.837e08}
			i+=1
		else // This profile has been "deleted", so skip.  
			profiles=removefromlist(oneProfile,profiles)
		endif
	while(i<itemsinlist(profiles))
	if(numpnts(lastUse))
		Sort /R lastUse,profileNames // Sort the profiles so that the most recently selected profiles are first.  
	endif
	string lastProfile=profileNames[0]
	if(!strlen(CurrProfileName()) && numpnts(profileNames))
		SetProfile(lastProfile)
	endif
	if(numpnts(profileNames))
		profiles=lastProfile+";"+removefromlist(lastProfile,profiles,";",0) // Put the most recent profile first.  
	else
		profiles=""
	endif
	if(brackets)
		profiles=";"+profiles
		string profiles2 = ""
		string currProfile=CurrProfileName()
		for(i=0;i<itemsinlist(profiles);i+=1)
			oneProfile = stringfromlist(i,profiles)
			if(stringmatch(oneProfile,currProfile))
				profiles2 += "["+oneProfile+"];"
			else
				profiles2 += oneProfile+";"
			endif
		endfor
		profiles=profiles2[1,strlen(profiles2)-1]
	endif
	ExperimentModified modified
	return profiles 
end

function InitProfilesPath()
	// If applicable, copy Users folder to Profiles folder.  This would be necessary if updating across the version change from "Users" to "Profiles".
	string usersPath = SpecialDirPath("Packages", 0, 0, 0)+"Users:" 
	string profilesPath=GetProfilesPath()
	GetFileFolderInfo /q/z=1 profilesPath
	if(!v_flag) // If there is a folder called "Profiles".
		newpath /o/q Profiles profilesPath
		variable i=0
		string firstProfile=indexedfile(Profiles,i,".bin")
		if(strlen(firstProfile)==0) // But there are no profiles inside.  
			newpath /o/q/z Users usersPath // Check the old "Users" path.  
			if(!v_flag) // If there is a "Users" folder.  
				do // Copy all the profiles from "Users" into "Profiles".  
					string user=indexedfile(Users,i,".bin")
					if(strlen(user))
						copyfile /o/p=Users user as profilesPath+user
						user=removeending(user,".bin")
						copyfolder /o/p=Users user as profilesPath+user
					else
						break
					endif
					i+=1
				while(1)
			endif
		endif
	else // If there is no "Profiles" folder.
		GetFileFolderInfo /q/z=1 usersPath
		if(v_isfolder) // But there is a "Users" folder.
			copyfolder /o/p=Packages "users" as "profiles"
		endif
	endif
	NewPath/O/C/Q Profiles, profilesPath // Create a directory in the Packages directory for this package. 
end

Function ProfileMenu()
	GetLastUserMenuInfo
	string profileName=ReplaceString("[",S_Value,"") // Get rid of bracket in case first profile was selected.  
	profileName=ReplaceString("]",profileName,"")
	SetProfile(profileName)
End

function /s CreateDefaultProfile()
	struct profileInfo profile
	string profileName="Generic"
	profile.name=profileName
	CreateProfile(profile,quiet=1)
	return profileName
end

function NewProfile(profile)
	struct profileInfo &profile
	string style
	
	string profileName=profile.name
	variable err=0
	// Check for conflict with an existing profile name.  
	string profiles=ListProfiles()
	if(whichlistitem(profileName,profiles)>=0)
		variable i
		do
			string newProfileName=profileName+num2str(i)
		while(whichlistitem(newProfileName,profiles)>=0)
		string alert
		sprintf alert,"There is an existing profile with this name.  Consider the alternative name '%s'.",newProfileName
		DoAlert 0,alert
		SetVariable NewName value=_STR:newProfileName
		err=-1
	elseif(!stringmatch(CleanupName(profileName,0),profileName))
		profileName=CleanUpName(profileName,0)
		sprintf alert,"That is not a legal name.  Consider the alternative name '%s'.",profileName
		DoAlert 0,alert
		SetVariable NewName value=_STR:profileName
		err=-2
	else	
		UpdateProfile(profile,new=1,quiet=1)
		variable isOldProfile=ProfileExists(profileName)
		CreateProfile(profile)
		if(isOldProfile)
			sprintf alert,"Since a deleted profile with this name already existed, its packages have been kept intact.\r"
			DoAlert 0,alert
			sprintf alert "To get a fresh profile, pick a fresh name, or first delete the folder located at:\r%s.",GetProfilePath(profileName)
			DoAlert 0,alert
		endif
	endif
	return err
end

function /s ModuleTitle(module)
	string module
	
	string title=module
	strswitch(module)
		case "Acq":
			title="Acquisition"
			break
		case "Nlx":
			title="Neuralynx"
			break
	endswitch
	return title
end

function /s ListProfileModules(profileName)
	string profileName
	
	struct profileInfo profile
	GetProfileInfo(profile,name=profileName)
	string modules=profile.modules
	return modules
end

function /s ListAvailableModules()
	string result=""
	newpath /o/q/z modulePath ModuleManifestsDiskLocation()
	if(!v_flag)
		variable i=0
		do
			string name=indexeddir(modulePath,i,0)
			if(!strlen(name))
				break
			endif
			if(!stringmatch(name,".*") && !stringmatch(name,"dev"))
				result+=name+";"
			endif
			i+=1
		while(1)
	endif
	return result
end

function IsDeveloper(profile)
	struct profileInfo &profile
	
	return profile.dev
end

function HasModule(profile,module)
	struct profileInfo &profile
	string module

	string modules=profile.modules
	return whichlistitem(module,modules)>=0
end

//function /s ListProfileModules(profileName)
//	string profileName
//	
//	struct profileInfo profile
//	GetProfileInfo(profile,name=profileName,forceLoad=1)
//	string modules=profile.modules
//	return modules
//end

function ProfileExists(name)
	string name
	
	variable result=0
	if(strlen(name))
		string loc=GetProfilePath(name)
		GetFileFolderInfo /Q/Z=1 loc
		result=!v_flag
	endif
	return result
end

function CreateProfile(profile[,createDir,save_,quiet])
	struct profileInfo &profile
	//string clone
	variable createDir,save_,quiet
	
	//clone=selectstring(!paramisdefault(clone),"",clone)
	save_=paramisdefault(save_) ? 1 : save_
	if(!strlen(profile.name))
		profile.name="Default"+num2str(abs(round(enoise(100000))))
	endif
	string profileName=profile.name
	string profileStyle=profile.style
	//profile.style=selectstring(strlen(clone),"Default",clone)
	profile.selected=1
	//if(createDir)
		if(ProfileExists(profile.style))
			NewPath /O/Q tempPath GetProfilesPath()
			CopyFolder /O/P=tempPath profileStyle as profileName
		else
			NewPath /C/O/Q tempPath GetProfilesPath()+profileName
		endif
	//endif
	if(save_)
		SaveProfile(profile,quiet=quiet)
	endif
end

Function DeleteProfile(profile)
	struct profileInfo &profile
		
	variable err=0
	string profileName=profile.name
	DoAlert 1,"Are you sure you want to delete all settings for the profile "+profileName+"?"
	if(V_Flag==1) // Yes clicked.  
		//NewPath /O/C/Q 
		err+=LoadProfile(profile,quiet=1)
		profile.selected=0 // Set this variable to zero so this profile doesn't show up in the menu anymore, rather than deleting all of the profile files.  
		err+=SaveProfile(profile,quiet=1)
//		if(StringMatch(profileName,CurrProfileName()))
//			String profiles=Listprofiles()
//			String lastprofile=StringFromList(0,profiles)
//			SetProfile(lastprofile)
//		endif
		if(!err)
			printf "Deleted profile '%s'.\r",profileName
		endif
		if(stringmatch(winname(0,65),editor))
			EditProfiles()
		endif
	else
		err=-1
	endif
	return err
End

Function SetProfile(profileName[,recompile])
	string profileName
	variable recompile
	
	recompile=paramisdefault(recompile) ? 1 : recompile
	ExperimentModified; Variable modified=V_flag
	String currFolder=GetDataFolder(1)
	// Set current profile and update selection time.    
	Struct profileInfo profile
	GetProfileInfo(profile)
	String lastProfileName=profile.name
	LoadPackagePreferences "Profiles",profileName+".bin",0,profile
	if(V_bytesRead==0) // profile preferences file for 'profileName' does not exist.  
		string msg=SelectString(strlen(profileName),"No profiles were found.  Select \"Edit Profiles\" from the Profiles menu to begin.","The profile "+profileName+" was not found.")
		DoAlert 0,msg
		return -1
	endif
	profile.selected=DateTime-date2secs(2000,1,1)
	SaveProfile(profile,quiet=1)
	
	// Put serialized structure information for this profile into the current experiment file.  
	dfref df=ProfilesDF()
	svar /sdfr=df profileStr=profile,profileName_=profileName
	StructPut /S profile, profileStr
	profileName_=profileName
	
	// Update universal symbol definitions.  
	String defList=profileName+";"
	String undefList=lastprofileName+";"
	if(profile.dev)
		Execute /Q/Z "SetIgorOption IndependentModuleDev=1"
		defList=AddListItem("Dev",defList)
	else
		//LoadPackageDefinitionsOld() // Load package definitions for the new profile.  
		Execute /Q/Z "SetIgorOption IndependentModuleDev=0"
		undefList=AddListItem("Dev",undefList)
	endif
	if(strlen(profileName))
		defList=AddListItem("Core",defList) // Define Core for every profile. 
	endif
	variable i=0
	string modules=ListAvailableModules()
	do
		string module=stringfromlist(i,modules)
		if(HasModule(profile,module))
			defList=AddListItem(module,defList)
			i+=1
		else
			undefList=AddListItem(module,undefList)
			modules=RemoveFromList(module,modules)
		endif
	while(i<itemsinlist(modules))
	Undef(undefList,recompile=0)
	Def(defList,recompile=recompile)
	
	for(i=0;i<itemsinlist(modules);i+=1)
		module=stringfromlist(i,modules)
		LoadModuleManifest(module) // Load package definitions for the new profile.  
		Execute /P/Q/Z "ProcGlobal#ModuleDiskLocation(\""+module+"\",create=1)" // Create module home directories.  
		//Execute /P/Q/Z "ProcGlobal#LoadPackages(\""+module+"\")" // Load package definitions for the new profile.  
	endfor

	printf "Loading profile settings for '%s'...\r",profileName
	String cmd
	sprintf cmd,"Core#CheckProfileHook(%d)",modified // A function defined for each profile (in the constants file).  
	Execute /Q/P/Z cmd
	BuildMenu "Profiles"
	ExperimentModified modified
	//Execute /Q/P/Z "ExperimentModified 0"//+num2str(modified)
	//Execute /Q/P/Z "DoIgorMenu \"File\", \"New Experiment\""
End

function LoadModuleManifests([modules])
	string modules
	
	modules=selectstring(!paramisdefault(modules),ListAvailableModules(),modules)
	variable i
	for(i=0;i<itemsinlist(modules);i+=1)
		string module=stringfromlist(i,modules)
		LoadModuleManifest(module)
	endfor
end

//function LoadModuleManifest(module)
//	string module
//	
//	string cmd
//	sprintf cmd,"ProcGlobal#LoadModuleManifest(\"%s\")",module
//	Execute /Q/Z cmd // Load package definitions for the new profile. 
//end

// Returns a string version of the profile structure.  
Function /s GetProfile()
	svar /z/sdfr=ProfilesDF() profileStr=profile
	if(svar_exists(profileStr))
		return profileStr
	endif
	return ""
End

Function IsCurrprofile(name)
	String name
	
	return StringMatch(name,CurrProfileName())
End

function /s CurrProfileName()
	struct profileInfo profile
	
	GetProfileInfo(profile)
	return profile.name
end

Function /S GetProfileInfo(profile[,name,forceLoad])
	struct profileInfo &profile // Fill this by reference.  
	string name // Get info for the named profile rather than the current profile.  
	variable forceLoad
	
	if(forceLoad || (!ParamIsDefault(name) && !IsCurrProfile(name)))
		LoadPackagePreferences "Profiles",name+".bin",0,profile
	else // Get info for the current profile.  
		string profileStr = GetProfile()
		if(strlen(profileStr))
			StructGet /S profile, profileStr
		endif
	endif
	return profile.name
End

function /df ProfilesDF()
	string loc="root:Packages:profiles"
	if(!datafolderexists(loc))
		NewDataFolder /O root:Packages
		NewDataFolder /O root:Packages:profiles
	endif
	dfref df=$loc
	return df
end


function InitProfiles()
	dfref df=ProfilesDF()
	string /g df:profile, df:profileName
	svar /sdfr=df profileStr=profile,profileName
	string profiles=ListProfiles()
	if(itemsinlist(profiles)==0)
		profiles=CreateDefaultProfile()
	endif
	string firstProfile=stringfromlist(0,profiles)
	if(!strlen(profileStr) || whichlistitem(profileName,profiles)<0)
		SetProfile(firstProfile)
	endif
end

Function ModifyProfileInfo(profile,changes)
	struct profileInfo &profile
	string changes
	
	variable i
	for(i=0;i<itemsinlist(changes);i+=1)
		string change=stringfromlist(i,changes)
		string changeVar=stringfromlist(0,change,"=")
		string changeValue=stringfromlist(1,change,"=")
		strswitch(changeVar)
			case "Dev":
				profile.dev=str2num(changeValue)
				break
			default:
				variable val=str2num(changeValue)
				if(val)
					AddModule(profile,changeVar)
				elseif(!val)
					RemoveModule(profile,changeVar)
				endif
		endswitch
	endfor
End

function AddModule(profile,module)
	struct profileInfo &profile
	string module
	
	RemoveModule(profile,module)
	profile.modules=AddListItem(module,profile.modules)
end

function RemoveModule(profile,module)
	struct profileInfo &profile
	string module
	
	profile.modules=RemoveFromList(module,profile.modules)
end

//// Loads profile into the Packages directory, but does not set actually set up the profile for use.  
//Function LoadProfile(name)
//	string name
//	NewDataFolder /O root:Packages
//	NewDataFolder /O root:Packages:profiles
//	if(strlen(name)==0)
//		string profiles=Listprofiles()
//		string OSuser=GetOSUser()
//		if(WhichListItem(OSuser,profiles,";",0,0)) // Guess the current profile from login credentials.  
//			name=OSuser
//		else
//			name=StringFromList(0,profiles) // Pick the first profile.  
//		endif	
//	endif
//	Struct profileInfo profile
//	LoadPackagePreferences "Profiles",name+".bin",0,profile
//	String /G root:Packages:profiles:profile
//	StructPut /S profile, root:Packages:profiles:profile	
//	return profile.name
//End

Function PrintProfile(profileName)
	string profileName // Name of one profile, or leave out to get info for all profiles.  
	
	struct profileInfo profile
	variable i
	string profiles=ListProfiles()
	for(i=0;i<ItemsInList(profiles);i+=1)
		string oneProfile=StringFromList(i,profiles) // Already has '.bin' extension.  
		if(!strlen(profileName) || StringMatch(oneProfile,profileName))
			GetProfileInfo(profile,name=oneProfile,forceLoad=1)
			print profile
		endif
	endfor
End

function PrintFlag(flag)
	string flag
	
	struct profileInfo profile
	variable i
	string profiles=ListProfiles()
	for(i=0;i<ItemsInList(profiles);i+=1)
		string oneProfile=StringFromList(i,profiles) // Already has '.bin' extension.  
		GetProfileInfo(profile,name=oneProfile,forceLoad=1)
		printf "%s: ",oneProfile
		strswitch(flag)
			case "selected":
				variable var=profile.selected
				printf "%d",var
				break
		endswitch
		printf "\r"
	endfor
end

Function CheckProfileHook(modified)
	Variable modified
	
	if(exists("ProcGlobal#profileHook")==6)
		Execute /Q/Z "ProcGlobal#ProfileHook()"
	endif
	// Since this executed in the operation queue (using /P flag), it might follow other ExperimentModified
	// operations, so we set the ExperimentModified status to be whatever it was when the function
	// began executing.  
	ExperimentModified modified
End

Structure profileInfo
	char name[30] // The name of the profile.  
	char style[30] // A style of the profile, used to set defaults.  
	uint32 selected // Time (seconds from 1/1/2000) when this profile was last selected from the menu.  
	double dummy[62]
	uchar dev
	char modules[100]
	char dummy2[3]
	double reserved[75]
	double reserved0[100]
EndStructure

function SaveProfile(profile[,quiet])
	struct profileInfo &profile
	variable quiet
	
	string profileName=profile.name
	SavePackagePreferences /FLSH=1 "Profiles",profileName+".bin",0,profile
	if(v_flag)
		printf "Profile '%s' could not be saved [%d].\r",profileName,v_flag
	elseif(!quiet)
		printf "Profile '%s' saved succesfully.\r",profileName
	endif
	return v_flag
end

function LoadProfile(profile[,quiet])
	struct profileInfo &profile
	variable quiet
	
	string profileName=profile.name
	LoadPackagePreferences "Profiles",profileName+".bin",0,profile
	if(v_flag)
		printf "Profile '%s' could not be loaded [%d].\r",profileName,v_flag
	elseif(!quiet)
		//printf "Profile '%s' loaded succesfully.\r",profileName
	endif
	return v_flag
end

//// The old way of defining packages.  Scheduled for deletion.  
//Function LoadPackageDefinitionsOld()
//	NewDataFolder /O/S root:Packages
//	NewDataFolder /O/S profiles
//	NewDataFolder /O/S Acq
//	String /G acqModesSettings="VAR:inputGain=1000,outputGain=1000,testPulsestart,testPulselength,testPulseampl;CHECK:dynamic=0;STR:inputUnits,outputUnits;"
//	String /G analysisMethodsSettings="VAR:axisMin,axisMax=100,axisSize=1;CHECK:show=1,crossChannel,logScale;STR:units=#;WAVE:marker=19|8,mSize=3|3,active=channels,analysisWin|Minimum=channels,analysisWin|parameter,analysisWin|features=1|0"
//	String /G channelConfigsSettings="VAR:filters|notchFreq=60,filters|notchHarmonics=10,filters|wyldpointWidth=3,filters|wyldpointThresh=0,filters|lowFreq=200,filters|highFreq=1,red,green,blue;CHECK:filters|notch,filters|wyldpoint,filters|low,filters|high,filters|zero,filters|powerSpec;STR:inputMap=N,outputMap=N,acqMode,stimulusName;"
//	String /G stimuliSettings="VAR:pulseSets=1,duration=1,ISI=2,saveMode=2;CHECK:continuous;STR:acqmode;WAVE:divisor,remainder,width,ampl,dampl,pulses,IPI,begin,testPulseOn;"
//	String /G randomSettings="VAR:lblpos|Axis Label Position|0|100|1,fsize|Font Size|6|24|1,ITC_kHz|ITC kHz|0.1|100|1,NIDAQ_kHz|NIDAQ kHz|0.1|100|1;CHECK:lineFeedLabels|Axis Label Line Breaks|0|1|1;STR:defaultView|Default Sweeps View|Broad|Focused,dataDir:Default Data Directory;"
//	String /G sealtestSettings="VAR:left=10,top=10;right=800;bottom=600"
//	String /G selectorSettings="VAR:left=10,top=10;right=800;bottom=600"
//End