#pragma rtGlobals=1		// Use modern global access method.
//#pragma moduleName=Settings
#pragma IndependentModule=Core

//#ifdef Dev
strconstant moduleEditor="EditModuleWin"
strconstant moduleInfo="root:Packages:Profiles"
strconstant moduleHome_="root:parameters"
strconstant defaultInstanceName="Generic"

Function EditModule(module[,package])
	string module,package
	
	dowindow /k $moduleEditor
	newpanel /k=1/n=$moduleEditor as "Edit Module "+module
	setwindow $moduleEditor hook(slide)=slideHook
	string packages=ListPackages(modules=module)
	package=selectstring(!paramisdefault(package),stringfromlist(0,packages),package)
	variable tab=max(0,WhichListItem(package,packages,";",0,0))
	variable i,j,k,m,num=0,x=0,y=95,xjump=55,yjump=25
	variable numPackages=itemsinlist(packages)
	if(numPackages)
		for(i=0;i<itemsInList(packages);i+=1)
			package=StringFromList(i,packages)
			string packageTitle=GetPackageTitle(module,package)
			TabControl tab, tabLabel(i)=packageTitle,userData($("MODULE"+num2str(i)))=module
			TabControl tab, userData($("PACKAGE"+num2str(i)))=package
			dfref df=PackageHome(module,package,quiet=1)
			if(!datafolderrefstatus(df))
				LoadPackage(module,package)
			endif
		endfor
		TabControl Tab, pos={0,5}, proc=EditPackagesTabs, size={100+65*numPackages,25}, value=tab
		struct wmtabcontrolaction info
		info.tab=tab
		EditPackagesTabs(info)
		TitleBox NoPackages, disable=1
	else
		TitleBox NoPackages, pos={5,80}, title="No packages have been loaded.", disable=0
	endif
End

function ErrLog()
	return Core#IsDef("errLog")
end

function SetErrLog(state)
	variable state
	
	if(state)
		Core#Def("errLog",recompile=0)
	else
		Core#Undef("errLog",recompile=0)
	endif
end

function /s GetPackageTitle(module,package)
	string module,package
	
	dfref manifestDF=PackageManifest(module,package)
	svar /z/sdfr=manifestDF title
	if(svar_exists(title))
		string packageTitle=title
	else
		packageTitle=VarNameToTitle(package)
	endif
	return packageTitle
end

function /s VarNameToTitle(varName)
	string varName
	
	string title=varName
	variable j
	for(j=0;j<strlen(title);j+=1)
		if(j==0) // If first character.  
			if(char2num(UpperStr(title[j]))!=char2num(title[j])) // If not capitalized.  
				title[0,0]=UpperStr(title[j]) // Capitalize.  
			endif
		elseif(char2num(UpperStr(title[j]))==char2num(title[j]) && !stringmatch(title[j]," ") && !stringmatch(title[j-1]," ") && char2num(UpperStr(title[j-1]))!=char2num(title[j-1])) // If uppercase letter following a lowercase letter.  
			title[j]=" " // Insert a space.  
			j+=1
		endif
	endfor
	title=removeending(title,"_")
	return title
end

function IsRootPackage(module,package)
	string module,package
	
	return stringmatch(module,package)		
end

function PossiblyEditSettingsPM(info)
	Struct WMPopupAction &info
	
	if(stringmatch(info.ctrlName,"*_Settings") && stringmatch(info.popStr,"_Edit_"))
		variable editing=1
	endif
	variable mode=NumberByKey("MODE",info.userData)
	if(numtype(mode))
		// Use either mode 1 or 0.  
		controlinfo /w=$(info.win) $(info.ctrlName)
		mode=NumberByKey("mode",s_recreation,"=",",")
		mode=numtype(mode) ? 1 : min(1,mode)
	endif
	if(editing)
		popupmenu $(info.ctrlName) mode=mode, win=$(info.win) // Update mode.  
		string module=stringbykey("MODULE",info.userData)
		string package=stringfromlist(0,info.ctrlName,"_")
		EditModule(module,package=package)
	else
		string cmd="popupmenu /z "+info.ctrlName+" userData=ReplaceStringByKey(\"MODE\",\""+info.userData+"\",\""+num2str(info.popNum)+"\"), win="+info.win // Update user data. 
		Execute /Q/P cmd // Must go into operation queue because control will because this function returns control to the normal control handler, which will block updates of user data.   
	endif
	return editing
end

Function EditPackageInstances(module,package[,sub,special,hideVars,freezeNew])
	string module,package,special
	variable hideVars // Hide the controls to change the package.  Just allow the deletion of packages.  
	string sub
	variable freezeNew // Don't initialize the new instance, just show it as it is.  
	
	string win=moduleEditor
	if(wintype(win))
		dowindow /f $win
	else
		EditModule(module)
	endif
	sub=selectstring(!paramisdefault(sub),"",sub)
	variable k,xstart=max(65,LongestPackageObjectTitle(module,package)+25)
	variable yStart=100
	variable xx=xStart,yy=yStart,yMax=yy
	string userData=""
	
	dfref manifestDF=PackageManifest(module,package)
	string packagedescription=strvarordefault(getdatafolder(1,manifestDF)+"desc","Settings for Package '"+package+"'") 
	variable length=strlen(packageDescription)
	killcontrol /W=$win Text
	TitleBox Text title=packageDescription, fixedSize=0, pos={5,yStart-65}, disable=0
	if(length>100) // Get around the limit of 100 characters for TitleBox titles.  
		string packageDescription2=packageDescription[100,length-1]
		doupdate
		controlinfo Text
		variable width1=v_width, left1=v_left
		TitleBox Text2 title=packageDescription2, fixedSize=0, frame=0, size={FontSizeStringWidth("Default",9,0,packageDescription2),11}, pos={left1+width1,yStart-61}, disable=0
		controlinfo Text2
		variable width2=v_width
		TitleBox Text fixedSize=1, size={width1+width2,20}
		KillControl /W=$win Text2
		TitleBox Text2 title=packageDescription2, fixedSize=0, frame=0, size={FontSizeStringWidth("Default",9,0,packageDescription2),11}, pos={left1+width1-4,yStart-61}, disable=0
	endif
	string instances=ListPackageInstances(module,package)
	variable numInstances=itemsinlist(instances)
	variable generic=IsGenericPackage(module,package)
	
	yy=yStart
	for(k=0;k<=numInstances;k+=1)
		if(k==numInstances && !generic)
			string instance="_New_"
			if(!freezeNew)
				InitNewInstance(module,package)
			endif
		elseif(k==numInstances && generic)
			break
		else
			instance=StringFromList(k,instances) // For generic package or new instance, this will be "".  
		endif
		if(strlen(instance))
			string title=selectstring(stringmatch(instance,"_New_"),instance,"")
			//title=selectstring(stringmatch(title,"Default_"),title,"Default")
			TitleBox $("Name_"+num2str(k)),pos={xx,yy-35},size={100,20},title=title, disable=0
			sprintf userData,"MODULE:%s;PACKAGE:%s;INSTANCE:%s;",module,package,instance
			//SetControlsUserData("SavePackage",userData)
		endif
		ShowPackageInstance(module,package,instance,xx,yy,generic=generic,sub=sub,hideVars=hideVars,firstInstance=(k==0))
		yMax=max(yy,yMax)
		yy=yStart
	endfor
	Button SavePackage, pos={3,yStart-35}, proc=EditPackagesButtons, title="Save", disable=!strlen(package),userData(generic)="0"
	struct rect coords
	GetWinCoords(win,coords,forcePixels=1)
	variable factor=ScreenResolution/72
	string packages=ListPackages(modules=module)
	variable numPackages=itemsinlist(packages)
	variable width=max(500,max(xx+10,100+65*numPackages))
	movewindow /w=$win coords.left,coords.top,coords.left+width/factor,coords.top+(yMax+30)/factor
	sprintf userData,"MODULE:%s;PACKAGE:%s;ACTION:%s;",module,package,"Save Package"
	SetControlsUserData("SavePackage",userData)
	return yy
End

function InitNewInstance(module,package)
	string module,package
	
	variable err=0
	dfref newDF=NewInstanceHome(module,package)
	dfref parentDF=$(RemoveEnding(getdatafolder(1,newDF),"New:"))
	dfref defaultDF=DefaultInstanceHome(module,package)
	if(datafolderrefstatus(newDF) && datafolderrefstatus(parentDF))
		killdatafolder /z newDF
		if(!v_flag)
			DuplicateDataFolder defaultDF parentDF:New
		else
			err=-1
		endif
	else
		err=-2
	endif
	if(err)
		printf "Could not initialize new instance of package %s.\r",package 
	endif
	return err
end

function ShowPackageInstance(module,package,instance,x,y[,generic,sub,hideVars,firstInstance])
	string module,package,instance,sub
	variable generic,hideVars,&x,&y,firstInstance
		
	sub=selectstring(!paramisdefault(sub),"",sub)
	variable new=stringmatch(instance,"_New_")
	dfref instanceDF=InstanceHome(module,package,instance,sub=sub,create=1)
	dfref manifestDF=PackageManifest(module,package,sub=sub)
	if(!datafolderrefstatus(manifestDF))
		return -1
	endif
	variable xjump=85,yjump=30,yStart=y
	variable i,j//,isSubPackage_=0
	nvar /z/sdfr=manifestDF noNew
	if(nvar_exists(noNew) && noNew && new)
		return 0
	endif
	for(i=0;i<CountObjectsDFR(manifestDF,4);i+=1)
		string object=GetIndexedObjNameDFR(manifestDF,4,i)
		dfref objectDF=ObjectManifest(module,package,object,sub=sub)
		string objectLoc=getdatafolder(1,objectDF)
		string valueLoc=joinpath({getdatafolder(1,instanceDF),object}) // Location of the object containing the actual data value(s).  
		string info=module+"_"+package+"_"+object+"_"+instance
		string control=strvarordefault(joinpath({objectLoc,"control"}),"")
		string type=ObjectType(joinpath({objectLoc,"value"}))
		string controlsToModify=""
		strswitch(type)
			case "WAV":
			case "WAVT":
				string addRow=Core#Hash32("Add Row "+info)
				string subtractRow=Core#Hash32("Subtract Row "+info)
				//string objectLoc=getdatafolder(1,manifestDF) // Location of the folder containing the manifest data for this object.  .  
				wave /z WAVvalDefault=objectDF:value
				wave /z WAVval=$valueLoc
				if(!waveexists(WAVval))
					killvariables /z $valueLoc
					killstrings /z $valueLoc
					duplicate /o WAVvalDefault,$valueLoc /wave=WAVval
				endif
				nvar /z/sdfr=objectDF minRows
				if(nvar_exists(minRows) && numpnts(WAVval)<minRows)
					redimension /n=(minRows) WAVval
				elseif(!nvar_exists(minRows) && numpnts(WAVval)==0)
					redimension /n=(1,-1,-1,-1) WAVval
				endif
				variable rows=dimsize(WAVval,0)		
				strswitch(control)
					case "ColorPopupMenu":
						rows=1
						break
					default:
						button $addRow, pos={x,y},size={20,20},title="+",disable=0,userData(ACTION)="Add Row",proc=EditPackagesButtons
						button $subtractRow, pos={x+20,y},size={20,20},title="-",disable=0,userData(ACTION)="Subtract Row",proc=EditPackagesButtons
						controlsToModify+=addRow+";"+subtractRow+";"
						y+=yJump
						break
				endswitch
				for(j=0;j<rows;j+=1)
					ShowPackageInstanceObject(module,package,instance,object,info+"_"+num2str(j),x,y,yJump,row=j,generic=generic,sub=sub,hideVars=hideVars,firstInstance=firstInstance)
				endfor
				break
			case "VAR":
			case "STR":
				killwaves /z $valueLoc
				strswitch(type)
					case "VAR":
						//nvar defaultVar=$joinpath({objectLoc,"value"})
						variable /g $valueLoc//=defaultVar
						break
					case "STR":
						//svar defaultStr=$joinpath({objectLoc,"value"})
						string /g $valueLoc//=defaultStr
						break
				endswitch
				ShowPackageInstanceObject(module,package,instance,object,info+"_0",x,y,yJump,generic=generic,sub=sub,hideVars=hideVars,firstInstance=firstInstance)
				break
			case "FLDR": // Subpackage.  
				ShowPackageInstance(module,package,instance,x,y,generic=generic,sub=joinpath({sub,object}),hideVars=hideVars,firstInstance=firstInstance)
				//isSubPackage_=1
				continue
				break
		endswitch
		//if(isSubPackage_)
		//	continue
		//endif
		if(i==0 && new && !strlen(sub)) // First object and new instance.  
			SetVariable $("NewInstance_Name"),title="",value=_STR:"New", pos={x,ystart-35}, disable=0
		endif
		string userData
		sprintf userData,"MODULE:%s;PACKAGE:%s;INSTANCE:%s;OBJECT:%s;SUB:%s;"module,package,instance,object,sub
		SetControlsUserData(controlsToModify,userData)
	endfor
	if(!generic && CountObjectsDFR(manifestDF,4) && (paramisdefault(sub) || !strlen(sub)))
		if(new)
			string action="Add Instance"
		else
			action="Delete Instance"
		endif
		string controlName=Core#Hash32(action+info)
		Button $controlName, pos={x-2,y}, disable=hideVars, proc=EditPackagesButtons, title=stringfromlist(0,action," ")
		sprintf userData,"MODULE:%s;PACKAGE:%s;INSTANCE:%s;ACTION:%s;"module,package,instance,action
		SetControlsUserData(controlName,userData)
	endif
//	// Module specific functions.  
//	funcref ShowPackageInstance f=$(module+"#ShowPackageInstance")
//	if(strlen(stringbykey("NAME",funcrefinfo(f))))
//		variable funcRefExists=1
//	endif
//	if(funcRefExists)				
//		sprintf special,"INSTANCE:%s;OBJECT:%s;K:%d:M:%d;YJUMP:%d:CTRLNAME:%s;DEFAULTLOC:%s",instance,object,k,m,yjump,controlName,strvarordefault(objectLoc+":value","")
//		f(module,package,x,y,special=special)
//	endif
	if(paramisdefault(sub) || !strlen(sub))
		x+=xjump
	endif
end

function ShowPackageInstanceObject(module,package,instance,object,info,x,y,yJump[,row,generic,sub,hideVars,firstInstance])
	string module,package,instance,object,info,sub
	variable generic,hideVars,&x,&y,yJump,row,firstInstance
	
	dfref instanceDF=InstanceHome(module,package,instance,sub=sub,create=1)
	dfref manifestDF=ObjectManifest(module,package,object,sub=sub)
	string objectLoc=getdatafolder(1,manifestDF) // Location of the folder containing the manifest data for this object.  
	string valueLoc=joinpath({getdatafolder(1,instanceDF),object}) // Location of the object containing the actual data value(s).  
	if(!exists(valueLoc))
		CopyDefaultInstanceObject(module,package,instance,object)
	endif
	string options
	sprintf options,"Core#StrPackageSetting(\"%s\",\"%s\",\"%s\",\"%s\",setting=\"%s\")",module,package,instance,object,"options"
	variable expandable=VarPackageSetting(module,package,instance,object,setting="expandable",default_=0)
	string controlName=Core#Hash32(info)
	string type=ObjectType(joinpath({objectLoc,"value"}))
	svar /z title_=$(objectLoc+"title")
	if(svar_exists(title_))
		string title=title_
	else
		title=VarNameToTitle(object)
	endif
	string control=strvarordefault(objectLoc+"control","")
	variable low=numvarordefault(objectLoc+"low",-inf)
	variable high=numvarordefault(objectLoc+"high",inf)
	variable inc=numvarordefault(objectLoc+"inc",1)
	variable dx=0,dy=0
	if(row==0)
		// Show object title.  
		if(firstInstance)
			variable top=y
		else
			controlinfo $(object+"_title")
			if(v_flag>0)
				top=max(y,v_top)
			else
				top=y
			endif
		endif
		TitleBox /z $(object+"_title") pos={5+itemsinlist(sub,":")*5,top},title=title,disable=0
	endif
	string controlsToModify=controlName+";"
	strswitch(type)
		case "WAV":
			wave WAV=$valueLoc
			strswitch(control)
				case "ColorPopupMenu":
					popupmenu $controlName,pos={x,y},popColor=(WAV[0],WAV[1],WAV[2]),disable=0,value="*COLORPOP*"
					break
				case "MarkerPopupMenu":
					popupmenu $controlName,mode=(1+WAV[row]),value="*MARKERPOP*"
					break
				case "Checkbox":
					checkbox $controlName,value=WAV[row]
					break
				default:
					control="SetVariable"
					setvariable $controlName,value=WAV[row],limits={low,high,inc}
			endswitch
			break
		case "WAVT":
			wave /t WAVT=$valueLoc
			strswitch(control)
				case "SetVariable":
					setvariable $controlName,value=WAVT[row]
					break
				case "PopupMenu":
					wave /t popValue=WavTPackageSetting(module,package,instance,object,sub=sub)
					popupmenu $controlName,popvalue=popValue[row],value=#options,mode=1
					dx=-5
				break
			endswitch
			break
		case "VAR":
			nvar VAR=$valueLoc
			strswitch(control)
				case "Checkbox":
					checkbox $controlName,variable=VAR
					break
				default:
					control="SetVariable"
					setvariable $controlName,value=VAR,limits={low,high,inc}
			endswitch
			break
		case "STR":
			svar STR=$valueLoc
			if(!strlen(control))
				control=selectstring(itemsinlist(STR)>1,"SetVariable","PopupMenu")
			endif
			strswitch(control)
				case "SetVariable":
					setvariable $controlName,size={45,20}, value=STR
					break
				case "PopupMenu":
				 // Check to make sure the selected item will be available in the popup menu (i.e. is loaded and allowed).   
					Execute /Q/Z "String /G evalStrTemp="+options
					svar evalStrTemp; string options_=evalStrTemp; killstrings /Z evalStrTemp
					if(whichlistitem(STR,options_)<0)
						STR = stringfromlist(0,options_)
					endif
				 // Set the poupup menu.  	
					popupmenu $controlName,popvalue=STR,value=#options,mode=1
					break
				case "Notebook":
					string notebookName=controlName[0,9]
					if(wintype(moduleEditor+"#"+notebookName))
						KillWindow $(moduleEditor+"#"+notebookName)
					endif
					newnotebook /N=$(notebookName) /F=1/HOST=$moduleEditor /W=(x,y,x+500,y+100)
					STR=WinRecreation(package,0)
					SetStrPackageSetting(module,package,instance,object,STR)
					notebook $(moduleEditor+"#"+notebookName) visible=1, text=STR,selection={startOfFile,startOfFile},findText={"", 1}
					y+=50
					break
			endswitch
			if(stringmatch(object,"dataDir"))
				string auxCtrl=Core#Hash32("New Path "+info)
				button $auxCtrl size={20,20},pos={x+expandable*15,y-2},title="...", userData(TARGET)=object, proc=EditPackagesButtons,disable=0
				button $auxCtrl userData(ACTION)="New Path"
				controlsToModify+=auxCtrl+";"
				variable auxButton=1
			endif
			if(expandable)
				auxCtrl=Core#Hash32("Expand "+info)
				button $auxCtrl pos={x,y}, size={15,15}, disable=0, title="+", userData(EXPANDED)="0", proc=EditPackagesButtons
				button $auxCtrl userData(ACTION)="Expand"
				button $auxCtrl userData(TARGET)=controlName
				controlsToModify+=auxCtrl+";"
			endif
			break
	endswitch
	
	// Change x locations of various types of controls.  
	strswitch(control)
		case "ColorPopupMenu":
		case "MarkerPopupMenu":
		case "PopupMenu":
			control="PopupMenu"
			dx=-5
			break
		case "SetVariable":
			break
		case "Checkbox":	
			dx=15
			dy=4
			control+="e"
			break
		default:
			break
	endswitch
	dx+=(expandable)*15
	dx+=(auxButton)*20
	string hook="EditPackages"+control+"s"
	modifycontrol /z $controlName pos={x+dx,y+dy}, title=" ", disable=0, help={PackageObjectHelp(module,package,object,sub=sub)},proc=$hook
	string userData
	sprintf userData,"MODULE:%s;PACKAGE:%s;INSTANCE:%s;OBJECT:%s;ROW:%d;"module,package,instance,object,row
	SetControlsUserData(controlsToModify,userData)
	y+=yJump
end

function /s GetSelectedInstance(module,package,[noDefault,quiet])
	string module,package
	variable noDefault // Do not return the default instance if none is selected.  
	variable quiet
	
	string result=""
	dfref df=PackageHome(module,package,quiet=quiet)
	if(datafolderrefstatus(df))
		svar /z/sdfr=df selected
		if(svar_exists(selected) && strlen(selected))
			result=InstanceOrDefault(module,package,selected,quiet=quiet)
		elseif(!noDefault)
			result=DefaultInstance(module,package,quiet=quiet)
		endif
	endif
	return result
end

function SetSelectedInstance(module,package,instance[,quiet])
	string module,package,instance
	variable quiet
	
	variable result=0
	dfref df=PackageHome(module,package,quiet=quiet)
	if(datafolderrefstatus(df))
		string /g df:selected=instance
		result=1
	elseif(!quiet)
		printf "Could not set selected instance for package %s.\r",package
	endif
	return result
end

function /s InstanceOrDefault(module,package,instance[,quiet])
	string module,package,instance
	variable quiet
	
	if(InstanceExists(module,package,instance,quiet=quiet))
		string result=instance
	else
		result=DefaultInstance(module,package,quiet=quiet)
	endif
	return result
end

function InheritInstancesOrDefault(module,parentPackage,childPackage,childInstances[,parentInstance,context,quiet])
	string module,parentPackage,parentInstance,childPackage,context
	wave /t childInstances
	variable quiet
	
	context=selectstring(!paramisdefault(context),"",context)
	parentInstance=selectstring(!paramisdefault(parentInstance),GetSelectedInstance(module,parentPackage,quiet=quiet),parentInstance)
	string parentObjects=ParentPackageObjects(module,childPackage,parentPackage,quiet=quiet)
	string parentObject=stringfromlist(0,parentObjects)
	dfref df=InstanceHome(module,parentPackage,parentInstance,quiet=quiet)
	variable err=0
	if(!strlen(parentObject))
		err=-1
	elseif(!datafolderrefstatus(df))
		err=-2
	else	
		strswitch(PackageObjectType(module,parentPackage,parentObject))
			case "STR":
				svar /sdfr=df str=$parentObject
				CopyInstance(module,childPackage,str,childInstances[0],context=context,quiet=quiet)
				break
			case "WAVT":
				wave /t/sdfr=df w=$parentObject
				variable i
				for(i=0;i<numpnts(childInstances);i+=1)
					CopyInstance(module,childPackage,w[i],childInstances[i],context=context,quiet=quiet)
				endfor
				break
			default:
				err=-3
		endswitch
	endif
	if(err)
		for(i=0;i<numpnts(childInstances);i+=1)
			CopyDefaultInstance(module,childPackage,childInstances[i],context=context,quiet=quiet)
		endfor
	endif	
	return err
end

function /s ParentPackageObjects(module,childPackage,parentPackage[,quiet])
	string module,childPackage,parentPackage
	variable quiet
	
	string objects=""
	dfref df=PackageManifest(module,parentPackage,quiet=quiet)
	if(datafolderrefstatus(df))
		variable i
		for(i=0;i<CountObjectsDFR(df,4);i+=1)
			string name=GetIndexedObjNameDFR(df,4,i)
			dfref dfi=df:$name
			svar /z/sdfr=dfi options
			if(svar_exists(options) && stringmatch(options,"Module:*"))
				string optionsModule,optionsPackage
				sscanf options,"Module:%[^:]:%[^:]",optionsModule,optionsPackage
				optionsPackage = removeending(optionsPackage,"+Blank")
				if(stringmatch(optionsPackage,childPackage))
					objects+=name+";"
				endif
			endif
		endfor
	endif
	return objects
end

function /s ChildPackage(module,parentPackage,object[,sub,quiet])
	string module,parentPackage,object,sub
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	string optionsModule,optionsPackage=""
	dfref df=ObjectManifest(module,parentPackage,object,sub=sub,quiet=quiet)
	if(datafolderrefstatus(df))
		svar /z/sdfr=df options
		if(svar_exists(options) && stringmatch(options,"Module:*"))
			sscanf options,"Module:%[^:]:%[^:]",optionsModule,optionsPackage
			optionsPackage=removeending(optionsPackage,"+Blank")
		endif
	endif
	return optionsPackage
end

function /s PackageObjectType(module,package,object[,sub,quiet])
	string module,package,object,sub
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	string type=""
	dfref df=ObjectManifest(module,package,object,sub=sub,quiet=quiet)
	if(datafolderrefstatus(df))
		string loc=joinpath({getdatafolder(1,df),"value"})
		type=ObjectType(loc)
		if(stringmatch(type,"STR"))
			svar str=$loc
			if(stringmatch(str,"_folder_"))
				type="FLDR"
			endif
		endif
	endif
	return type
end

function /s ListPackageObjects(module,package[,depth,rel,sub])
	string module,package,sub
	variable depth
	variable rel // If objects are at non-zero depth from the package root, give their path relative to the package root.  
	
	rel=paramisdefault(rel) ? 1 : rel
	sub=selectstring(!paramisdefault(sub),"",sub)
	depth=paramisdefault(depth) ? inf : depth
	string list=""
	dfref packageDF=PackageManifest(module,package,sub=sub)
	if(!datafolderrefstatus(packageDF))
		printf "Could not list package objects in %s because the package manifest could not be found.\r",package
	else
		variable i
		for(i=0;i<CountObjectsDFR(packageDF,4);i+=1)
			string object=GetIndexedObjNameDFR(packageDF,4,i)
			list+=selectstring(strlen(sub) && rel,"",sub+":")+object+";"
			if(depth && datafolderexists(getdatafolder(1,packageDF)+object+":value"))
				list+=ListPackageObjects(module,package,depth=depth-1,sub=object)
			endif
		endfor
	endif
	return list		
end

function /df PackageObjectHome(module,package,object)
	string module,package,object
	
	dfref packageDF=PackageHome(module,package)
	if(datafolderrefstatus(packageDF))
		dfref objectDF=packageDF:$object
	endif
	return objectDF
end

function LongestPackageObjectTitle(module,package)
	string module,package
	
	string objects=ListPackageObjects(module,package)
	variable longest=0
	variable i
	for(i=0;i<itemsinlist(objects);i+=1)
		string object=stringfromlist(i,objects)
		string title=PackageObjectTitle(module,package,object)
		if(!strlen(title))
			printf "Could not determine longest object title in package %s\r",package
			return max(longest,50) // Reasonable guess at the longest title.  	
		endif
		longest=max(longest,FontSizeStringWidth("Default",10,0,title))	
	endfor	
	return longest
end

function /s PackageObjectTitle(module,package,object)
	string module,package,object
	
	string title=""
	dfref packageDF=PackageManifest(module,package)
	if(!datafolderrefstatus(packageDF))
		printf "Could not find the title of object %s in package %s because the package manifest could not be found.\r",object,package  
	else
		title=strvarordefault(getdatafolder(1,packageDF)+object+":title",object)
	endif
	return title
end

function /df ObjectManifest(module,package,object[,sub,quiet])
	string module,package,object,sub
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	dfref df=PackageManifest(module,package,sub=sub,quiet=quiet)
	dfref manifest=df:$object
	if(!datafolderrefstatus(manifest) && !quiet)
		printf "Could not find manifest for object %s of package %s.\r",object,package
	endif
	return manifest
end

function /df PackageManifest(module,package[,sub,quiet,load])
	string module,package,sub
	variable quiet,load
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	string loc=moduleInfo+":"+module+":Manifest:"+package
	loc=JoinPath({loc,sub})
	dfref manifest=$loc
	if(!datafolderrefstatus(manifest))
		if(load)
			LoadModuleManifest(module)
			manifest=PackageManifest(module,package,sub=sub,quiet=quiet,load=0)
		elseif(!quiet)
			printf "Could not find manifest for package %s at location %s.\r",package,loc
		endif
	endif
	return manifest
end

function /s ListPackageInstances(module,package[,editor,saver,match,except,all,quiet,load,onDisk])
	string module,package,match,except
	variable editor,saver,all,quiet,load,onDisk
	
	match=selectstring(!paramisdefault(match),"*",match)
	except=selectstring(!paramisdefault(except),"",except)
	
	// List all the package instances.  
	variable i
	string instances=""
	dfref manifestDF=PackageManifest(module,package,quiet=quiet,load=load)
	if(onDisk)
		string loc=PackageDiskLocation(module,package,quiet=1)
		newpath /o/q/z packagePath,loc
		if(!v_flag)
			instances=indexedfile(packagePath,-1,".pxp")
			instances=replacestring(".pxp;",instances,";")
		endif
	else
		dfref packageDF=PackageHome(module,package,quiet=quiet,load=load)
		for(i=0;i<CountObjectsDFR(packageDF,4);i+=1)
			string possibleInstance=GetIndexedObjNameDFR(packageDF,4,i)
			if(stringmatch(possibleInstance,match) && !stringmatch(possibleInstance,except))
				svar /z/sdfr=manifestDF ignore
				if(!all && svar_exists(ignore) && grepstring(possibleInstance,ignore))
					continue
				endif
				if(IsSubPackage(module,package,possibleInstance))
					continue
				endif
				instances+=possibleInstance+";"
			endif
		endfor
	endif
	instances=SortList(instances)
	if(editor)
		instances+="_Edit_"
	endif
	if(saver)
		instances+="_Save_"
	endif
	return instances
end

function /s PackageObjectHelp(module,package,object[,sub])
	string module,package,object,sub
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	string result=""
	dfref df=ObjectManifest(module,package,object,sub=sub)
	if(datafolderrefstatus(df))
		svar /z/sdfr=df help_,help
		if(svar_exists(help_))
			result=help_
		elseif(svar_exists(help))
			result=help
		endif
	endif
	return result
end

// Returns the location of the package settings.  It is up to the calling function to know if this is a wave, variable, or string
function /s PackageSettingLoc(module,package,instance,object[,setting,sub,quiet,create])
	string module,package,instance,object,setting,sub
	variable quiet,create
	
	setting=selectstring(!paramisdefault(setting),"value",setting)
	sub=selectstring(!paramisdefault(sub),"",sub)
	if(stringmatch(setting,"value"))
		if(stringmatch(instance,"_new_"))
			string loc=getdatafolder(1,NewInstanceHome(module,package,sub=sub,quiet=quiet))
		else
			loc=getdatafolder(1,InstanceHome(module,package,instance,sub=sub,quiet=quiet,create=create))
		endif
		loc+=object
	else
		loc=getdatafolder(1,PackageManifest(module,package,sub=sub,quiet=quiet))
		loc+=object+":"+setting
	endif
	return loc
end

function VarPackageSetting(module,package,instance,object[,setting,default_,sub,quiet])
	string module,package,instance,object,setting,sub
	variable default_,quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	setting=selectstring(!paramisdefault(setting),"value",setting)
	string loc=PackageSettingLoc(module,package,instance,object,setting=setting,sub=sub,quiet=quiet)
	variable var=nan
	nvar /z var_=$loc
	if(nvar_exists(var_) && !numtype(var_))
		var=var_
	else
		var=paramisdefault(default_) ? nan : default_
	endif
	return var
end

function /s StrPackageSetting(module,package,instance,object[,setting,default_,sub,quiet])
	string module,package,instance,object,setting,sub
	string default_
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	setting=selectstring(!paramisdefault(setting),"value",setting)
	string loc=PackageSettingLoc(module,package,instance,object,setting=setting,sub=sub,quiet=quiet)
	string str=""
	svar /z str_=$loc 
	if(svar_exists(str_) && strlen(str_))
		str=str_
		if(stringmatch(setting,"options"))
			if(stringmatch(str,"Module:*"))
				str = replacestring("+",str,";")
				string optionsModule,optionsPackage,optionsPackage_
				sscanf str,"Module:%[^:]:%[^:]",optionsModule,optionsPackage_
				optionsPackage = stringfromlist(0,optionsPackage_)
				string extraOptions = removefromlist(optionsPackage,optionsPackage_)
				extraOptions = selectstring(strlen(extraOptions),"",removeending(extraOptions,";")+";")
				extraOptions = replacestring("Blank",extraOptions," ")
				str=extraOptions+ListPackageInstances(optionsModule,optionsPackage,quiet=quiet)
				//str=replacestring("Default_",str,"Default")
			elseif(stringmatch(str,"Return:*"))
				string func=str[7,strlen(str)-1]
				string cmd="string /g temp=ProcGlobal#"+func
				Execute /Q/Z cmd
				svar /z temp
				if(svar_exists(temp))
					str=temp
					killstrings /z temp
				endif
			endif
		elseif(stringmatch(str,"_default_"))
			string child=ChildPackage(module,package,object,sub=sub)
			if(strlen(child))
				str=DefaultInstance(module,child) // Default instance of child package.  
			endif
		endif
	endif
	if(!strlen(str))
		str=selectstring(!paramisdefault(default_),"",default_)
	endif
	return str
end

function /wave WavPackageSetting(module,package,instance,object[,setting,sub,quiet])
	string module,package,instance,object,setting,sub
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	setting=selectstring(!paramisdefault(setting),"value",setting)
	string loc=PackageSettingLoc(module,package,instance,object,setting=setting,sub=sub,quiet=quiet)
	wave /z w=$loc
	if(waveexists(w))
		return w
	else
		if(!quiet)
			printf "Could not find setting '%s' for object '%s' of instance '%s' of package '%s'\r",setting,object,instance,package
		endif
		return NULL
	endif
end

function /wave WavTPackageSetting(module,package,instance,object[,setting,sub,quiet])
	string module,package,instance,object,setting,sub
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	setting=selectstring(!paramisdefault(setting),"value",setting)
	string loc=PackageSettingLoc(module,package,instance,object,setting=setting,sub=sub,quiet=quiet)
	wave /z/t w=$loc
	if(waveexists(w))
		variable i
		for(i=0;i<numpnts(w);i+=1)
			if(stringmatch(w[i],"_default_"))
				string child=ChildPackage(module,package,object,sub=sub,quiet=quiet)
				if(strlen(child))
					w[i]=DefaultInstance(module,child,quiet=quiet) // Default instance of child package.  
				endif
			endif
		endfor
		return w
	endif
	return NULL
end

function SetPackageSetting(module,package,instance,object,value[,sub,indices,setting,quiet])
	string module,package,instance,object,value,setting,sub
	wave indices
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	setting=selectstring(!paramisdefault(setting),"value",setting)
	if(paramisdefault(indices))
		make /free/n=0 indices
	endif
	string loc=PackageSettingLoc(module,package,instance,object,sub=sub,setting=setting,quiet=quiet)
	SetObject(loc,value,indices=indices,quiet=quiet)
end

function SetVarPackageSetting(module,package,instance,object,value[,setting,quiet,create])
	string module,package,instance,object,setting
	variable value,quiet,create
	
	setting=selectstring(!paramisdefault(setting),"value",setting)
	string loc=PackageSettingLoc(module,package,instance,object,setting=setting,quiet=quiet)
	nvar /z var=$loc
	if(!nvar_exists(var))
		if(create)
			variable /g $loc
			nvar /z var=$loc
			var=value
		elseif(!quiet)
			printf "No such numeric variable object: %s.\r",loc
		endif
	else
		var=value
	endif
end

function SetStrPackageSetting(module,package,instance,object,value[,setting,quiet])
	string module,package,instance,object,value,setting
	variable quiet
	
	setting=selectstring(!paramisdefault(setting),"value",setting)
	string loc=PackageSettingLoc(module,package,instance,object,setting=setting,quiet=quiet)
	svar /z str=$loc
	if(!svar_exists(str))
		if(!quiet)
			printf "No such string object: %s.\r",loc
		endif
	else
		str=value
	endif
end

function SetWavPackageSetting(module,package,instance,object,value[,setting,indices,sub])
	string module,package,instance,object,setting,sub
	wave value,indices
	
	setting=selectstring(!paramisdefault(setting),"value",setting)
	sub=selectstring(!paramisdefault(sub),"",sub)
	string loc=PackageSettingLoc(module,package,instance,object,sub=sub,setting=setting)
	wave /z w=$loc
	if(paramisdefault(indices))
		redimension /n=(dimsize(value,0),dimsize(value,1),dimsize(value,2)) w
		w=value[p][q]
	else
		variable i
		for(i=0;i<numpnts(indices);i+=1)
			w[indices[i]][]={value[i][q]}
		endfor
	endif
end

function SetWavTPackageSetting(module,package,instance,object,value[,setting,indices,sub])
	string module,package,instance,object,setting,sub
	wave /t value
	wave indices
	
	setting=selectstring(!paramisdefault(setting),"value",setting)
	sub=selectstring(!paramisdefault(sub),"",sub)
	string loc=PackageSettingLoc(module,package,instance,object,setting=setting)
	wave /z/t w=$loc
	if(paramisdefault(indices))
		redimension /n=(dimsize(value,0),dimsize(value,1),dimsize(value,2)) w
		w=value[p][q]
	else
		variable i
		for(i=0;i<numpnts(indices);i+=1)
			w[indices[i]][]={value[i][q]}
		endfor
	endif
end

function /s PopupMenuOptions(module,package,instance,object[,sub,index,brackets,quiet])
	string module,package,instance,object,sub
	variable brackets,index,quiet
	
	brackets=paramisdefault(brackets) ? 1 : brackets
	sub=selectstring(!paramisdefault(sub),"",sub)
	//svar options=$PackageSettingLoc(module,package,instance,object,setting="options")
	string options=StrPackageSetting(module,package,instance,object,setting="options",sub=sub,quiet=quiet)
	string valueLoc=PackageSettingLoc(module,package,instance,object,sub=sub,quiet=quiet,create=0)
	strswitch(ObjectType(valueLoc))
		case "VAR":
			nvar var=$valueLoc
			string value=num2str(var)
			break
		case "STR":
			svar str=$valueLoc
			value=str
			break
		case "WAV":
			wave wav=$valueLoc
			value=num2str(wav[index])
			break
		case "WAVT":
			wave /t wavt=$valueLoc
			value=wavt[index]
			break
	endswitch	
	if(strlen(options) && exists(valueLoc) && brackets)
		options=replacestring(value,options,"["+value+"]")
	endif
	return options
end

function /s PackageModule(package)
	string package
	
	string module=""
	string win=moduleEditor
	controlinfo /w=$win Tab
	if(v_flag>0)
		module=getuserdata(win,"Tab","MODULE:"+num2str(v_value))
	endif
	if(!strlen(module))
		string packages=ListPackages(sources=1)
		module=stringbykey(package,packages)
	endif
	return module
end

function /s ListPackages([modules,sources,quiet])
	string modules
	variable sources,quiet
	
	if(paramisdefault(modules) || !strlen(modules))
		modules=Core#FLAGS_()	
	endif
	string packages=""
	variable i,j
	for(i=0;i<itemsinlist(modules);i+=1)
		string module=stringfromlist(i,modules)
		dfref df=ModuleManifest(module,quiet=quiet)
		if(datafolderrefstatus(df))
			for(j=0;j<CountObjectsDFR(df,4);j+=1)
				string package=GetIndexedObjNameDFR(df,4,j)
				packages+=package+selectstring(sources,"",":"+module)+";"
			endfor
		endif
	endfor
	return packages
end

function /df ModuleManifest(module[,load,quiet])
	string module
	variable load // Load from disk if not in current experiment file.  
	variable quiet
	
	load=paramisdefault(load) ? 1 : load
	string loc=joinpath({moduleInfo,module,"Manifest"})
	dfref df=$loc
	if(!datafolderrefstatus(df))
		string str=""
		if(load)
			LoadModuleManifest(module)
			if(!quiet)
				printf "Loading manifest for %s...\r",module
			endif
			str=" or on disk"
		endif
		df=$loc
		if(!datafolderrefstatus(df) && !quiet)
			printf "Manifest for %s could not be found in memory%s.\r",module,str
		endif
	endif
	return df
end

function /s GetControlUserData(ctrlName,property[,win])
	string ctrlName,property,win
	
	win=selectstring(!paramisdefault(win),winname(0,65),win)
	return getuserdata(win,ctrlName,upperstr(property))
end

function /s SetControlUserData(ctrlName,property,value[,win])
	string ctrlName,property,value,win
	
	win=selectstring(!paramisdefault(win),winname(0,65),win)
	modifycontrol /z $ctrlName userdata($upperstr(property))=value, win=$win
	return value
end

function SetControlsUserData(controls,userDataKeyPairs)
	string controls,userDataKeyPairs
	
	variable i,j
	for(i=0;i<itemsinlist(controls);i+=1)
		string controlName=stringfromlist(i,controls)
		for(j=0;j<itemsinlist(userDataKeyPairs);j+=1)
			string userDataKeyPair=stringfromlist(j,userDataKeyPairs)
			string userDataName=stringfromlist(0,userDataKeyPair,":")
			string value=stringbykey(userDataName,userDataKeyPair)
			SetControlUserData(controlName,userDataName,value)
		endfor
	endfor
end

function /s ToggleControlUserData(ctrlName,property[,win])
	string ctrlName,property,win
	
	win=selectstring(!paramisdefault(win),winname(0,65),win)
	string value=GetControlUserData(ctrlName,property,win=win)
	variable val=str2num(value)
	val=(numtype(val) || val) ? 0 : 1
	return SetControlUserData(ctrlName,property,num2str(val),win=win)
end

function EditPackagesTabs(info)
	struct WMTabControlAction &info
	if(info.eventCode==-1)
		return -1
	endif
	string win=moduleEditor
	dowindow /f $win
	TabControl Tab, value=info.tab
	ModifyControlList RemoveFromList("tab",ControlNameList("", ";", "*"),";",0) disable=1
	string childWindows=ChildWindowList(win)
	variable i
	for(i=0;i<itemsinlist(childWindows);i+=1)
		string childWindow=stringfromlist(i,childWindows)
		switch(WinType(win+"#"+childWindow))
			case 5: // Notebook.  
				killwindow $(win+"#"+childWindow)
				break
		endswitch
	endfor
	string package=getuserdata(win,"Tab","PACKAGE"+num2str(info.tab))
	string module=getuserdata(win,"Tab","MODULE"+num2str(info.tab))
	dfref df=DefaultInstanceHome(module,package,quiet=1)
	if(!datafolderrefstatus(df))
		LoadPackage(module,package)
	endif
	dfref df=NewInstanceHome(module,package)
	if(datafolderrefstatus(df))
		KillDataFolder df
	endif
	EditPackageInstances(module,package)
end

Function EditPackagesButtons(info) : ButtonControl
	struct wmbuttonaction &info
	
	if(info.eventCode!=2)
		return -1
	endif
	ControlInfo tab; Variable tabNum=V_Value
	string module=GetControlUserData(info.ctrlName,"MODULE")
	string package=GetControlUserData(info.ctrlName,"PACKAGE")//StringFromList(tabNum,ListPackages())
	string sub=GetControlUserData(info.ctrlName,"SUB")//StringFromList(tabNum,ListPackages())
	string instance=GetControlUserData(info.ctrlName,"INSTANCE")
	string object=GetControlUserData(info.ctrlName,"OBJECT")
	string action=GetControlUserData(info.ctrlName,"ACTION")
	string target=GetControlUserData(info.ctrlName,"TARGET")
	string currFolder=GetDataFolder(1)
	
	strswitch(action)
		case "Save Package":
			String profileName=GetUserData("","","PROFILENAME")
			Struct Core#ProfileInfo profile
			Core#GetProfileInfo(profile,name=profileName)
			SavePackage(module,package)
			break
		case "Add Instance":
			ControlInfo NewInstance_Name
			instance=S_Value
			string existingInstances=ListPackageInstances(module,package)
			if(!strlen(instance))
				DoAlert 0, "You must provide a name to the new instance."
				return -1
			elseif(stringmatch(instance,"New"))
				DoAlert 0, "Try giving it a more creative name than 'New'"
				return -2  
			elseif(CheckName(instance,4) || whichlistitem(instance,existingInstances)>=0)
				string str="The name '"+instance+"' will be changed to the legal name "
				string suffix=""
				do
					instance=CleanupName(instance+suffix,0)
					suffix+="_"
				while(whichlistitem(instance,existingInstances)>=0)
				str+="'"+instance+"'"
				DoAlert 0,str
				SetVariable NewInstance_Name value=_STR:instance
				return -3
			else
				 AddPackageInstance(module,package,instance)
			endif
			break
		case "Delete Instance":
			DeletePackageInstance(module,package,instance)
			break
		case "Add Row": // Increase wave size by 1.  
		case "Subtract Row": // Decrease wave size by 1.  
			wave w=WavPackageSetting(module,package,instance,object,sub=sub)
			variable oldSize=dimsize(w,0)
			variable delta=2*stringmatch(action,"Add Row")-1
			redimension /n=(max(1,oldSize+delta),-1) w
			if(oldSize>1 && delta<0)
				string ctrlInfo=module+"_"+package+"_"+object+"_"+instance+"_"+num2str(oldSize-1)
				string oldControl=Core#Hash32(ctrlInfo)
				killcontrol $oldControl
			endif
			//variable freezeNew=stringmatch(instance,"_New_")
			EditPackageInstances(module,package,freezeNew=1)//freezeNew)
			break
		case "Expand": // Expand/unexpand control.  
			variable wasExpanded=str2num(GetControlUserData(info.ctrlName,"EXPANDED"))
			button $info.ctrlName, title=selectstring(wasExpanded,"-","+"), win=$info.win
			ToggleControlUserData(info.ctrlName,"EXPANDED")
			controlinfo /w=$info.win $target
			string row=GetControlUserData(target,"ROW")
			setvariable $target size={250-v_width,20}, win=$info.win
			string instances=ListPackageInstances(module,package)+"_New_"
			instances=removefromlist(instance,instances)
			variable i
			string controlsToHide=""
			string objectControls=ControlNameList(info.win,";","*"+object+"*")
			for(i=0;i<itemsinlist(instances);i+=1)
				string otherInstance=stringfromlist(i,instances)	
				//string otherInstanceControls=ControlNameList(info.win,";","*"+otherInstance+"*")
				string otherCtrlInfo=module+"_"+package+"_"+object+"_"+otherInstance+"_"+row
				string otherControl=Core#Hash32(otherCtrlInfo)+";"
				otherControl+=Core#Hash32("Expand "+otherCtrlinfo)+";"
				otherControl+=Core#Hash32("New Path "+otherCtrlinfo)+";"
				controlsToHide+=otherControl
				//ListIntersection({objectControls,otherInstanceControls})
			endfor
			
			modifycontrollist /z controlsToHide disable=!wasExpanded
			break
		case "New Path":
			NewPath /O/Q currPath
			if(!v_flag)
				PathInfo currPath
				SetStrPackageSetting(module,package,instance,target,s_path)
			endif
			break
	endswitch
	
	funcref EditPackagesButtons f=$(module+"#EditPackagesButtons")
	if(strlen(stringbykey("NAME",funcrefinfo(f))))
		string special
		sprintf special,"PACKAGE:%s;ACTION:%s;INSTANCE:%s;",package,action,instance
		info.userData=special
		f(info)
	endif
	
	dfref df=GetDataFolderDFR()
	SetDataFolder root:
	strswitch(action)
		case "Add Instance":
		case "Delete Instance":
			//DoWindow /K $moduleEditor
			EditPackageInstances(module,package)
			break
	endswitch
	SetDataFolder df
End

function EditPackagesPopupMenus(info)
	struct wmpopupaction &info
	
	if(info.eventCode!=2)
		return -1
	endif
	string module=GetControlUserData(info.ctrlName,"module")
	string package=GetControlUserData(info.ctrlName,"package")//StringFromList(tabNum,ListPackages())
	string instance=GetControlUserData(info.ctrlName,"instance")
	string object=GetControlUserData(info.ctrlName,"object")
	string action=GetControlUserData(info.ctrlName,"action")
	variable generic=IsGenericPackage(module,package)
	variable row=str2num(GetControlUserData(info.ctrlName,"row")) 
	string controlType=StrPackageSetting(module,package,instance,object,setting="control",default_="")
	if(generic)
		instance=""
	elseif(!strlen(instance))
		instance="_new_"
	endif
	dfref df=InstanceHome(module,package,instance) // TO DO: Add support for subpackages.  
	//string type=ObjectType(getdatafolder(1,df)+objectName)
	strswitch(info.popStr)
		//case "Default":
		//	info.popStr="Default_"
		//	break
	endswitch
	variable red,green,blue
	sscanf info.popStr,"(%d,%d,%d)",red,green,blue
	string color
	sprintf color,"(%d,%d,%d)",red,green,blue
	if(stringmatch(info.popStr,color)) // Is color PopupMenu.  
		controlType="ColorPopupMenu"
	endif
	string dest=joinpath({getdatafolder(1,df),object})
	strswitch(controlType)
		case "ColorPopupMenu":
			sprintf color,"%d;%d;%d;",red,green,blue
			variable result=SetObject(dest,color,indices={0,1,2})
			break
		case "MarkerPopupMenu":
			result=SetObject(dest,num2str(info.popNum-1),indices={row})
			break
		default:
			result=SetObject(dest,info.popStr,indices={row})
	endswitch
	string special
	sprintf special,"NAME:%s;INSTANCE:%s;NUM:%d;PACKAGE:%s;",object,instance,row,package
	info.userData=special
	
	funcref EditPackagesPopupMenus f=$(module+"#EditPackagesPopupMenus")
	if(strlen(stringbykey("NAME",funcrefinfo(f))))
		f(info)
	endif
	return result
end

Function EditPackagesSetVariables(info) : SetVariableControl
	Struct WMSetVariableAction &info
	
	if(info.eventCode<1 || info.eventCode>3)
		return -1
	endif
	ControlInfo tab; Variable tabNum=V_Value
	string module=GetControlUserData(info.ctrlName,"module")
	string package=GetControlUserData(info.ctrlName,"package")//StringFromList(tabNum,ListPackages())
	string instance=GetControlUserData(info.ctrlName,"instance")
	string object=GetControlUserData(info.ctrlName,"object")
	string action=GetControlUserData(info.ctrlName,"action")
	variable num=str2num(GetControlUserData(info.ctrlName,"num")) 
	variable generic=IsGenericPackage(module,package)
	
	if(generic)
		string objectName=StringFromList(1,info.ctrlName,"_")
		instance=""
	else
		objectName=StringFromList(0,info.ctrlName,"_")
		if(!strlen(instance))
			instance="_new_"
		endif
	endif
	
	string special
	sprintf special,"PACKAGE:%s;INSTANCE:%s;OBJECT:%s;",package,instance,object
	info.userData=special
	
	
	funcref EditPackagesSetVariables f=$(module+"#EditPackagesSetVariables")
	if(strlen(stringbykey("NAME",funcrefinfo(f))))
		f(info)
	endif
End

function EditPackagesCheckboxes(info)
	struct wmcheckboxaction &info
	
	if(info.eventCode!=2)
		return -1
	endif
	
	string module=GetControlUserData(info.ctrlName,"module")
	string package=GetControlUserData(info.ctrlName,"package")//StringFromList(tabNum,ListPackages())
	string instance=GetControlUserData(info.ctrlName,"instance")
	string object=GetControlUserData(info.ctrlName,"object")
	string action=GetControlUserData(info.ctrlName,"action")
	variable num=str2num(GetControlUserData(info.ctrlName,"num"))
	dfref instanceDF=InstanceHome(module,package,instance)
	wave /z w=instanceDF:$object
	if(waveexists(w))
		w[num]=info.checked
	endif
	funcref EditPackagesCheckboxes f=$(module+"#EditPackagesCheckboxes")
	if(strlen(stringbykey("NAME",funcrefinfo(f))))
		f(info)
	endif
End

// Add a new package instance from the packaged editor.  
function AddPackageInstance(module,package,name)
	string module,package
	string name // Name of the new package.  
	
	dfref source=NewInstanceHome(module,package)
	dfref dest=PackageHome(module,package)
	dfref existing=InstanceHome(module,package,name,quiet=1)
	if(datafolderrefstatus(existing) && strlen(name))
		if(DeletePackageInstance(module,package,name))
			return -1
		endif
	endif
	if(datafolderrefstatus(source))
		duplicatedatafolder source dest:$name // Copy it into its new home in memory.  
		
		// If it was scheduled to be deleted in the next save, remove it from the deletion queue.  
		dfref deleted=$joinpath({moduleInfo,module,"Deleted"})
		if(datafolderrefstatus(deleted))
			svar /z/sdfr=deleted deletedInstances=$package
			if(svar_exists(deletedInstances))
				deletedInstances=removefromlist(name,deletedInstances)
			endif
		endif
	else
		printf "Could not add package instance.\r"
	endif
	//dfref new=dest:$name
	//if(datafolderrefstatus(new))	
	//endif
end

//function FolderLists2Items(df,items[,recurse])
//	dfref df
//	string items
//	variable recurse
//	
//	variable i
//	if(recurse)
//		for(i=0;i<countObjectsdfr(df,4);i+=1)
//			dfref sub=df:$GetIndexedObjNamedfr(df,4,i)
//			FolderLists2Items(sub,items,recurse=recurse)
//		endfor
//	endif
//	for(i=0;i<countObjectsdfr(df,3);i+=1)
//		svar str=df:$GetIndexedObjNamedfr(df,3,i)
//		str=stringfromlist(0,str)
//	endfor
//	for(i=0;i<countObjectsdfr(df,1);i+=1)
//		wave /t w=df:$GetIndexedObjNamedfr(df,3,i)
//		if(waveexists(w) && wavetype(w,1)==2)
//			w=stringfromlist(0,w)
//		endif
//		str=stringfromlist(0,str)
//	endfor
//end

function DeletePackageInstance(module,package,instance[,ignoreMissing])
	string module,package,instance
	variable ignoreMissing
	
	String instances=ListPackageInstances(module,package)
	if(ItemsInList(instances)>1) // Only if there is at least one other instance.  
		dfref packageHome=PackageHome(module,package)
		dfref packageInstance=packageHome:$instance
		if(!DataFolderRefStatus(packageInstance) && !ignoreMissing)
			printf "Could not find instance %s of package %s to delete it.\r",instance,package
			return -1
		endif
		killdatafolder /z packageInstance
		if(v_flag)
			printf "Could not kill existing package instance %s of the same name.  Make sure it is not in use.\r",instance
			return -2
		endif	
		dfref deleted=NewFolder(joinpath({moduleInfo,module,"Deleted"}))
		svar /z/sdfr=deleted deletedInstances=$package
		if(!svar_exists(deletedInstances))
			string /g deleted:$package=""
			svar /sdfr=deleted deletedInstances=$package
		endif
		deletedInstances+=instance+";"
	else
		DoAlert 0,"You must leave at least one instance of this package." 
		return -3
	endif		
end

function IsGenericPackage(module,package[,quiet,retries])
	string module,package
	variable quiet,retries
	
	variable isGeneric=1
	do
		dfref packageDF=PackageManifest(module,package,quiet=1)
		if(datafolderrefstatus(packageDF))
			nvar /z/sdfr=packageDF generic
			isGeneric=nvar_exists(generic) && generic
		elseif(retries)
			LoadModuleManifest(module,quiet=quiet)
		endif
		retries-=1
	while(retries>0)
	return isGeneric
end

function /s CurrTabModule()
	controlinfo Tab
	string module=getuserdata("","Tab","MODULE"+num2str(v_value))
	return module
end

function /s CurrTabPackage()
	ControlInfo Tab
	String package=StringFromList(V_Value,ListPackages())
	return package
end

Function SavePackage(module,package[,deleteOld,quiet])
	string module
	string package // e.g. "acqMode", "stimulus", "channelConfig", "analysisMethod".   
	variable deleteOld // Delete instances from disk that are not present in memory.  
	variable quiet
	
	Struct Core#ProfileInfo profile
	string profileName=Core#GetProfileInfo(profile)
	variable generic=IsGenericPackage(module,package)
	variable i,j,err=0
	if(!generic)
		string instances=ListPackageInstances(module,package)
		for(i=0;i<ItemsInList(instances);i+=1)
			string instance=StringFromList(i,instances)
			err+=SavePackageInstance(module,package,instance)
		endfor
		dfref deleted=$joinpath({moduleInfo,module,"Deleted"})
		if(datafolderrefstatus(deleted))
			svar /z/sdfr=deleted deletedInstances=$package
			if(svar_exists(deletedInstances))
				string str=replacestring(";",deletedInstances,", ")
				str=removeending(str,", ")
				sprintf str,"%s instance(s) (%s) will now be deleted from disk.  OK?",VarNameToTitle(package),str
				doalert 1,str
				if(v_flag==1)
					NewPath /O/Q/Z PackagePath PackageDiskLocation(module,package)
					if(!v_flag)
						for(j=0;j<itemsinlist(deletedInstances);j+=1)
							instance=stringfromlist(j,deletedInstances)
							DeleteFile /P=PackagePath/Z=1 instance+".pxp"
						endfor
					endif
				endif
				deletedInstances=""
				killstrings /z deletedInstances
			endif
		endif
	else
		err+=SavePackageInstance(module,package,"")
	endif
	if(!err && !quiet)
		printf "All instances of package '%s' successfully saved to disk.\r",GetPackageTitle(module,package)
	elseif(err)
		printf "Save was unsuccessful.  Error code = %d\r",err
	endif
	
	if(deleteOld && !generic)
		string path
		sprintf path,"%sProfiles:%s:%s:%s",SpecialDirPath("Packages",0,0,0),"Profiles",profile.name,module,package
		NewPath /C/O/Q currPath,path 
		string types="pxp;ibw"
		for(j=0;j<itemsinlist(types);j+=1)
			string type=stringfromlist(j,types)
			string fileInstances=IndexedFile(currPath, -1, "."+type)
			for(i=0;i<itemsinlist(fileInstances);i+=1)
				string fileInstance=stringfromlist(i,fileInstances)
				if(WhichListItem(removeending(fileInstance,"."+type),instances)<0)
					DeleteFile /P=tempPath fileInstance
				endif
			endfor
		endfor
	endif
	return err
End

Function LoadDefaultPackages(module[,packages,quiet])
	string module,packages
	variable quiet
	
	packages=selectstring(!paramisdefault(packages),ListPackages(modules=module,quiet=quiet),packages)
	packages = PackageLoadOrder(module,packages)
	variable i
	for(i=0;i<itemsinlist(packages);i+=1)
		string package=StringFromList(i,packages)
		PackageHome(module,package,create=1)
		LoadDefaultPackageInstances(module,package,quiet=quiet)
	endfor
End

function /s LoadDefaultPackageInstances(module,package[,quiet])
	string module,package
	variable quiet
	
	return LoadPackageInstance(module,package,"_default_",quiet=quiet)
end

function /s PackageLoadOrder(module,packages)
	string module,packages
	
	string manifest_home = getdatafolder(1,ModuleManifestHome(module))
	string load_first = strvarordefault(joinpath({manifest_home,"load_first"}),"")
	string load_last = strvarordefault(joinpath({manifest_home,"load_last"}),"")
	string load_ends = joinlists({load_first,load_last})
	string load_middle = RemoveFromList(load_ends,packages,";",0)
	string ordered_packages = joinlists({load_first,load_middle,load_last})
	return ordered_packages
end

Function /S LoadPackages(module[,packages,quiet])
	string module,packages
	variable quiet
	
	packages=selectstring(!paramisdefault(packages),ListPackages(modules=module,quiet=quiet),packages)
	packages = PackageLoadOrder(module,packages)
	string packageInstancesLoaded=""
	variable i
	for(i=0;i<ItemsInList(packages);i+=1)
		string package=stringFromList(i,packages)
		string loaded=LoadPackage(module,package,quiet=quiet)
		if(!strlen(loaded))
			loaded=LoadDefaultPackageInstances(module,package,quiet=quiet)
		endif
		if(strlen(loaded))
			packageInstancesLoaded+=package+":"+RemoveEnding(ReplaceString(";",loaded,","),",")+";"
		endif
	endfor
	FixPackageInstances(module,quiet=quiet)
	return packageInstancesLoaded
End

function FixPackageInstances(module[,packages,quiet])
	string module,packages
	variable quiet
	
	packages=selectstring(!paramisdefault(packages),ListPackages(modules=module,quiet=quiet),packages)
	variable i,j,err=0
	for(i=0;i<ItemsInList(packages);i+=1)
		string package=stringfromlist(i,packages)
		string instances=ListPackageInstances(module,package)
		for(j=0;j<itemsinlist(instances);j+=1)
			string instance=stringfromlist(j,instances)
			err+=FixPackageInstance(module,package,instance,quiet=quiet)
		endfor
	endfor
	return err
end

function FixPackageInstance(module,package,instance[,sub,quiet])
	string module,package,instance,sub
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	dfref df=InstanceHome(module,package,instance,sub=sub)
	dfref manifestDF=PackageManifest(module,package,sub=sub)
	variable i
	for(i=0;i<CountObjectsDFR(manifestDF,4);i+=1)
		string object=GetIndexedObjNameDFR(manifestDF,4,i)
		string options=PopupMenuOptions(module,package,instance,object,brackets=0)
		variable hasEmptyOption=whichlistitem(" ",options)>=0
		string type=PackageObjectType(module,package,object,sub=sub)
		strswitch(type)
			case "WAV":
				wave /z wav=df:$object
				if(!waveexists(wav))
					make /n=0 df:$object
				endif
				break
			case "WAVT":
				wave /z/t wavt=df:$object
				if(!waveexists(wavt))
					make /n=0/t df:$object
				endif
				break
			case "VAR":
				nvar /z var=df:$object
				if(!nvar_exists(var))
					variable /g df:$object
				endif
				break
			case "STR":
				svar /z str=df:$object
				if(!svar_exists(str))
					string /g df:$object
				endif
				break
			case "FLDR":
				dfref subDF=df:$object
				if(!datafolderrefstatus(var))
					newdatafolder /o df:$object
				endif
				break
		endswitch
		if(IsSubPackage(module,package,object,sub=sub,quiet=quiet))
			FixPackageInstance(module,package,instance,sub=joinpath({sub,object}),quiet=quiet)
		elseif(!hasEmptyOption && IsEmptyChoice(module,package,instance,object,sub=sub,quiet=quiet)) // If this object requires a value, but does not have one.  
			RunObjectGenerator(module,package,instance,object,sub=sub,quiet=quiet)
			if(IsEmptyChoice(module,package,instance,object,sub=sub,quiet=quiet))
				SetPackageSetting(module,package,instance,object,stringfromlist(0,options),indices={0},sub=sub,quiet=quiet)
			endif
		endif
	endfor
end

function IsSubPackage(module,package,object[,sub,quiet])
	string module,package,object,sub
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	variable result=nan
	dfref df=PackageManifest(module,package,sub=sub,quiet=quiet)
	if(datafolderrefstatus(df))
		dfref objectDF=df:$object
		if(datafolderrefstatus(objectDF))
			svar /z/sdfr=objectDF value
			if(svar_exists(value) && stringmatch(value,"_folder_"))
				result=1
			else
				result=0
			endif
		endif
	endif
	return result
end

function IsEmptyChoice(module,package,instance,object[,sub,quiet])
	string module,package,instance,object,sub
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	dfref manifestDF=ObjectManifest(module,package,object,sub=sub,quiet=quiet)
	dfref instanceDF=InstanceHome(module,package,instance,sub=sub,quiet=quiet)
	string valueLoc=joinpath({getdatafolder(1,manifestDF),"value"})
	variable result=nan
	strswitch(ObjectType(valueLoc))
		case "VAR":
			result=0
			break
		case "STR":
			svar /z/sdfr=manifestDF options
			svar /sdfr=instanceDF str=$object
			result=(!strlen(str) && svar_exists(options))
			break
		case "WAV":
			result=0
			break
		case "WAVT":
			wave /t/sdfr=instanceDF wavt=$object
			svar /z/sdfr=manifestDF options
			result=(!strlen(wavt[0]) && svar_exists(options))
			break
	endswitch
	return result
end

function PackageHasWaves(module,package)
	string module,package
	
	funcref PackageHasWaves f=$(module+"#PackageHasWaves")
	variable hasWaves=0
	if(strlen(stringbykey("NAME",funcrefinfo(f))))
		hasWaves=f(module,package)
	endif	
	return hasWaves
end

Function /S ListDefaultPackageInstances(module,package)
	string module,package
	
	string instances=""
	funcref ListDefaultPackageInstances f=$(module+"#ListDefaultPackageInstances")
	if(strlen(stringbykey("NAME",funcrefinfo(f))))
		instances=f(module,package)
	endif
	return instances
End

//Function LoadModuleManifests([modules])
//	string modules
//	
//	modules=selectstring(!paramisdefault(modules),ListModules(),modules)
//	variable i
//	for(i=0;i<itemsinlist(modules);i+=1)
//		string module=stringfromlist(i,modules)
//		LoadModuleManifest(module)
//	endfor
//End

function /df ModuleManifestHome(module[,create,go])
	string module
	variable create,go
	
	string path = joinpath({moduleinfo,module,"Manifest"})
	if(create)
		NewFolder(path,go=go)
	endif
	dfref df = $path
	if(go)
		cd df
	endif
	return df
end

Function /df LoadModuleManifest(module[,quiet])
	string module
	variable quiet
	
	dfref currDF=GetDataFolderDFR()
	ModuleManifestHome(module,create=1,go=1)
	cd ::
	string path=ModuleDiskLocation("",default_=1,quiet=quiet)
	newpath /o/c/q currPath,path
	path=joinpath({path,module})
	newpath /o/c/q currPath,path
	variable refNum
	open /r/z=1/p=currPath refNum "Manifest.pxp"
	if(v_flag)
		if(!quiet)
			printf "Manifest for module %s could not be found on disk.\r",module
		endif
	else
		close refNum
		LoadData /O/T/P=currPath /Q/R "Manifest.pxp"
	endif
	dfref df=getdatafolderdfr()
	setdatafolder currDF
	return df
End

//function /s ListModules()
//	string modules=Core#ListAllModules()
//	return modules
//end

Function SaveModuleManifests([modules])
	string modules
	
	modules=selectstring(!paramisdefault(modules),ListAvailableModules(),modules)
	variable i
	for(i=0;i<itemsinlist(modules);i+=1)
		string module=stringfromlist(i,modules)
		SaveModuleManifest(module)
	endfor
End

Function SaveModuleManifest(module)
	string module
	
	dfref currDF=GetDataFolderDFR()
	dfref df=ModuleManifest(module,load=0)
	if(!datafolderrefstatus(df))
		printf "There is no manifest for module %s\r",module
		return -1
	else
		SetDataFolder df
	endif
	string path=ModuleDiskLocation("",default_=1)
	newpath /o/c/q currPath,path
	path=removeending(path,":")+":"+module
	newpath /o/c/q currPath,path
	SaveData /O/P=currPath/Q/R "Manifest.pxp"
	setdatafolder currDF
End

Function /S ListPackageMembers(module,package[,availableOnly])
	string module
	string package // "AcqModes", "AnalysisMethods", etc.  
	variable availableOnly // 1 to list those marked as not available, 0 otherwise.  
	
	Struct Core#profileInfo profile
	Core#GetprofileInfo(profile)
	String basePath=SpecialDirPath("Packages",0,0,0)+"profiles:"+profile.name+":"+module
	Variable i
	String list=""
	NewPath /O/Q tempPath basePath+":"+package
	Do
		String fileName=IndexedFile(tempPath,i,".bin")		
		if(strlen(fileName))
			list+=RemoveEnding(fileName,".bin")+";"
		else
			break
		endif
	While(1)		
	return list
End		

// --------- Macro Saving and Loading.  

Function SaveProfileMacro(win)
	String win
	String macroStr=WinRecreation(win,0)
	NewPath /O/C/Q userPath SpecialDirPath("Packages",0,0,0)+"Profiles:"+Core#CurrProfileName()
	Variable refNum
	Open /P=userPath refNum as win+".txt"
	FBinWrite refNum, macroStr
	Close /A
End

Function /S LoadProfileMacro(macroName)
	String macroName
	NewPath /O/C/Q userPath SpecialDirPath("Packages",0,0,0)+"Profiles:"+Core#CurrProfileName()
	Variable refNum
	Open /P=userPath /R/Z refNum as macroName+".txt"
	if(V_flag)
		return "V_flag="+num2str(V_flag)
	endif
	String currFolder=GetDataFolder(1)
	NewDataFolder /O/S root:Packages
	NewDataFolder /O/S Profiles
	NewDataFolder /O/S Macros
	String /G $macroName=""
	SVar macroStr=$macroName
	FSetPos refNum,0
	FStatus refNum
	macroStr=PadString(macroStr,V_logEOF,0x20)
	FBinRead refNum, macroStr
	Close refNum
	SetDataFolder $currFolder
	return macroStr
End

Function ExecuteProfileMacro(module,package,instance,safe[,object,sub,onDisk,name,quiet])
	string module,package,instance,object,sub,name
	variable safe // Safe, line-by-line execution of the macro with error suppression.  
	variable onDisk,quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	if(paramisdefault(object) || strlen(object)==0)
		object="recMacro"
	endif
	if(!strlen(instance))
		instance=DefaultInstance(module,package)
	endif
	if(onDisk)
		LoadPackageInstance(module,package,instance,quiet=quiet)
	endif
	string macroStr=StrPackageSetting(module,package,instance,object,sub=sub,quiet=quiet)
	if(!paramisdefault(name))
		strswitch(name)
			case "_package_":
				string macroName=package
				break
			case "_instance_":
				macroName=instance
				break
			default:
				macroName=name
		endswitch
	else
		macroName=package
	endif
	dfref df=InstanceHome
	dfref profilesDF=Core#ProfilesDF()
	if(strlen(macroStr))
		variable error=ExecuteMacro(macroStr,macroName,safe)
	else
		error=-1
	endif
	return error
End

function ExecuteMacro(macroStr,macroName,safe)
	string macroStr,macroName
	variable safe
	
	variable error=0
	dfref currDF=GetDataFolderDFR()
	setdatafolder root:
	if(safe)
		display /K=1 /N=DummyWin // Protect exisiting windows that might be modified if one of the lines fails to execute properly.    
		string dummyWinName=WinName(0,1)
		variable numErrors=0
		variable i=1 // Skip "Window..." or "Macro..." line.  
		do
			string line=StringFromList(i,macroStr,"\r")
			if(strsearch(line,"fldrSav0",0)>=0)
				// Storing and setting the current data folder can be problematic because the fldrSav0 variable may already exist.  
				// So I've just handled this outside the loops that executes the macro lines, and I also set the current data folder to root
				// since all recreation macros execute from root.  
				i+=1
				continue
			endif
			if(strlen(line))
				Execute /Q/Z line
				if(V_flag && V_flag!=93) // Ignore errors from "PauseUpdate; Silent 1" lines.  
					dfref df=Core#ProfilesDF()
					newdatafolder /o df:Macros
					dfref macrosDF=df:Macros
					make /o/t/n=(numErrors) macrosDF:$("error_"+macroName) /WAVE=ErrorWave
					string errorStr
					sprintf errorStr,"Line #%d: Error #%d: %s",i,V_flag,line
					ErrorWave[numErrors]={errorStr}
					numErrors+=1
				endif
				i+=1
			else
				break
			endif
		while(i<ItemsInList(macroStr,"\r")-1) // Go all the way through the line before the "End" line.  
		if(numErrors)
			printf "There were errors recreating the macro %s.  They can be found in %s.\r",macroName,GetWavesDataFolder(ErrorWave,2)
		endif
		if(!stringmatch(winname(0,1),dummyWinName)) // If a window has been created in front of the dummy window.  
			DoWindow /C $macroName // Rename it to the name of the macro.  
		else
			DoAlert 0,"The waves plotted in the macro you saved were not found, therefore the macro was not executed successfully."  
			error=-1
		endif
		DoWindow /K $dummyWinName
	else
		i=0
		Do
			line=StringFromList(i,macroStr,"\r")
			if(strlen(line))
				Execute /Q/Z line
				i+=1
			else
				break
			endif
		While(1)
	endif
	setdatafolder currDF
	return error
end

//Function LoadAndExecuteProfileMacro(macroName[,kill,safe])
//	String macroName
//	Variable kill // Kill any existing window with the name 'macroName'.
//	Variable safe // Safe, line-by-line execution of the macro with error suppression.  
//	
//	LoadProfileMacro(macroName)
//	if(kill)
//		DoWindow /K $macroName
//	endif
//	
//	return ExecuteProfileMacro(macroName,safe=safe)
//End

// ------ Loading from the acquisition menu ------

Function LoadPackageInstanceFromMenu(module,package)
	String module,package
	
	GetLastUserMenuInfo
	String instance=S_Value
	LoadPackageInstance(module,package,instance)
End

//Function /S UnloadedPackageInstances(package)
//	String package
//	
//	ExperimentModified; variable modified=v_flag
//	Variable num
//	String profileName=Core#CurrProfileName()
//	String dirStr=SpecialDirPath("Packages", 0, 0, 0)+"profiles:"+profileName+":"+package
//	NewPath /O/Q/Z tempPath, dirStr
//	if(V_flag) // Couldn't find the directory
//		return ""
//	endif
//	String list=LS(dirStr)
//	list=RemoveEnding2(list,".bin")
//	list=RemoveEnding2(list,".ibw")
//	list=RemoveEnding2(list,".pxp")
//	KillWaves /Z tempPath
//	ExperimentModified modified
//	return list
//End

Function /S LoadPackage(module,package[,instances,noOverwrite,loadLive,quiet])
	string module
	string package // e.g. "acqMode", "stimulus", "channelConfig", "analysisMethod"
	string instances // e.g. "VC;CC".  Use "" for all instances of a non-generic package, or for the single instance of a generic package. Use "_default_" to load default instances of the package.  
	variable noOverwrite // Don't overwrite existing instances of a named package if it is already in the current experiment.  
	variable loadLive // Load live settings, if they exist.  
	variable quiet
	
	instances=selectstring(!paramisdefault(instances),ListPackageInstances(module,package,onDisk=1,quiet=1),instances)
	variable default_=stringmatch(instances,"_default_")
	variable i,generic=IsGenericPackage(module,package)
	if(!generic && !strlen(instances)) // Non-generic package; all instances requested.  
		string name=Core#CurrProfileName()
		string path=PackageDiskLocation(module,package,quiet=quiet)
		NewPath /C/O/Q currPath,path
		instances=IndexedFile(currPath, -1, ".pxp")
		instances=replacestring(".pxp;",instances,";")
	endif
	string loaded=""
	dfref packageDF=PackageHome(module,package,create=1,quiet=quiet)
	if(!generic)
		if(!strlen(instances) && !default_)
			if(!quiet)
#ifdef Dev
				printf "No instances found on disk for package '%s'. Loading from defaults...\r",package
#endif
			endif
			loaded=LoadPackageInstance(module,package,"_default_",quiet=quiet)
		else
		endif
		for(i=0;i<ItemsInList(instances);i+=1)
			string instance=StringFromList(i,instances)
			dfref instanceDF=InstanceHome(module,package,instance,quiet=1)
			if(!noOverwrite || datafolderrefstatus(instanceDF))
				loaded+=LoadPackageInstance(module,package,instance,quiet=quiet)+";"
			endif
		endfor
	elseif(default_)
		loaded=LoadPackageInstance(module,package,"_default_",quiet=quiet)
	elseif(!noOverwrite || !datafolderrefstatus(instanceDF))
		loaded=LoadPackageInstance(module,package,"",quiet=quiet)
	endif
	return loaded
End

Function /s LoadPackageInstance(module,package,instance[,quiet,special])
	string module
	String package // "acqModes, "stimuli", "channelConfigs", "analysisMethods"
	String instance // e.g. "VC;CC".  Leave blank for all.  	 
	variable quiet
	string special
	
	dfref currDF=getdatafolderdfr()
	string name=Core#CurrProfileName()
	variable error=0
	variable default_=stringmatch(instance,"_default_")
	instance=selectstring(default_,instance,DefaultInstance(module,package,forceManifest=1,quiet=quiet))
	dfref instanceDF=InstanceHome(module,package,instance,create=1,quiet=quiet)
	variable i,generic=IsGenericPackage(module,package,quiet=quiet)
	if(!generic) // Non-generic package.  
		string path=PackageDiskLocation(module,package,default_=default_,create=!default_,quiet=quiet)
		string search=instance
	else // Generic package.  
		path=ModuleDiskLocation(module,default_=default_,create=!default_,quiet=quiet)
		search=package
	endif
	newpath /o/c/q currPath,path
	
	if(default_)
		dfref manifest=PackageManifest(module,package,quiet=quiet)
		if(!datafolderrefstatus(manifest))
			error=-4
		endif
		variable loadedFromManifest=!LoadPackageFromManifest(module,package,quiet=quiet)
		if(!loadedFromManifest && !quiet)
			printf "Could not load default instance from manifest for package %s\r",package
		endif
		string defaultInstance=strvarordefault(getdatafolder(1,manifest)+"defaultInstance","")
		if(!strlen(defaultInstance))
			defaultInstance=defaultInstanceName
		endif
		newpath /o/q currPath path
		if(v_flag)
			if(!quiet)
				printf "Could not find path for package %s on disk.\r",package
			endif
			error=-5
		else
			for(i=0;i<itemsinlist(defaultInstance);i+=1)
				instance=stringfromlist(i,defaultInstance)
				variable refNum
				open /r/z/p=currPath refNum as instance+".pxp"
				if(!v_flag)
					search=instance
					variable foundDefault=1
				elseif(!stringmatch(defaultInstance,defaultInstanceName)) // Don't report or try to load
					if(!quiet)
						printf "Instance %s for package %s could not be found on disk.\r",instance,package
					endif
				endif
			endfor
		endif
	else
		pathinfo currPath
		string list=IndexedFile(currPath,-1,".pxp")
		variable foundOnDisk=WhichListItem(search+".pxp",list,";",0,0)>=0
	endif
	if(foundDefault || foundOnDisk)
		setdatafolder instanceDF
		LoadData /O/P=currPath /Q/R search+".pxp"
		if(v_flag>0 && generic)
			instance=defaultInstanceName
		endif
	elseif(!loadedFromManifest)
		if(!quiet)
#ifdef Dev
			if(generic)
				printf "Package '%s' was not found on disk. ",package
			else
				printf "Instance '%s' of package '%s' was not found on disk. ",selectstring(strlen(instance),"(Blank)",instance),package
			endif
#endif
		endif
		if(!default_) // If it was not generic, there would be no reason to load a default instance.  
#ifdef Dev
			if(!quiet)
				printf "Loading from defaults...\r"
			endif
#endif
			string loaded=LoadDefaultPackageInstances(module,package,quiet=quiet)
		else
			if(!quiet)
				printf "\r"
			endif
			error=-2
		endif
	endif
	
	// Module specific functions.  
	funcref LoadPackageInstance f=$(module+"#LoadPackageInstance")	
	if(strlen(stringbykey("NAME",funcrefinfo(f))) && !error)
		sprintf special,"PATH:%s",path
		f(module,package,instance,quiet=quiet,special=special)
	endif
	setdatafolder currDF
	return selectstring(!error,"",instance)
End

function /s DefaultInstance(module,package[,forceManifest,quiet])
	string module,package
	variable forceManifest,quiet
	
	string instance=""
	if(strlen(package))
		dfref df=PackageManifest(module,package,quiet=quiet)
		if(datafolderrefstatus(df))
			svar /z/sdfr=df default_
			if(svar_exists(default_) && (forceManifest || InstanceExists(module,package,default_,quiet=quiet)))
				instance=default_
			elseif(InstanceExists(module,package,defaultInstanceName,quiet=quiet) || forceManifest)
				instance=defaultInstanceName
			else
				instance=stringfromlist(0,ListPackageInstances(module,package,quiet=quiet))
			endif
		endif
	endif
	return instance
end

function MigrateModules()
	string modules=ListAvailableModules()
	variable i
	string loc=ProfileDiskLocation()
	NewPath /O/Q profilePath loc
	string packages=ListPackages(modules=modules,sources=1)
	for(i=0;i<itemsinlist(packages);i+=1)
		string packageInfo=stringfromlist(i,packages)
		string package=stringfromlist(0,packageInfo,":")
		string module=stringfromlist(1,packageInfo,":")
		GetFileFolderInfo /Q/Z=1/P=profilePath package
		if(!v_flag)
			NewPath /O/Q/C modulePath ModuleDiskLocation(module)
			if(v_isfolder && !stringmatch(package,module))
				string dest=PackageDiskLocation(module,package)
				MoveFolder /O/P=profilePath package as dest
			endif
		endif
	endfor
end

function /s RecordingArtistDiskLocation()
	string path=joinpath({specialdirpath("Igor Pro User Files",0,0,0),"User Procedures","Recording Artist"})
	return path
end

function /s ModuleManifestsDiskLocation()
	string path = joinpath({RecordingArtistDiskLocation(),"Modules"})
	return path
end

// Return the full path of a module's location on disk.
function /s ProfileDiskLocation([profileName,default_,create,quiet])
	string profileName
	variable default_ // The location of the default, with the manifest.   
	variable create,quiet
	
	if(default_)
		string path=ModuleManifestsDiskLocation()
	else
		profileName=selectstring(!paramisdefault(profileName),Core#CurrProfileName(),profileName)
		path=joinpath({SpecialDirPath("Packages",0,0,0),"Profiles",profileName})
	endif
	if(create)
		CreatePathLocation(path)	
	endif
	return path
end

// Return the full path of a module's location on disk.
function /s ModuleDiskLocation(module[,default_,create,quiet])
	string module
	variable default_ // The location of the default, with the manifest.   
	variable create,quiet
	
	string path=ProfileDiskLocation(default_=default_,quiet=quiet)
	path=joinpath({path,module})
	if(create)
		CreatePathLocation(path)	
	endif
	return path
end

function CreatePathLocation(diskPath)
	string diskPath
	
	string pathPart=""
	variable i
	for(i=0;i<itemsinlist(diskPath,":");i+=1)
		pathPart+=stringfromlist(i,diskPath,":")+":"
		newpath /o/c/q/z currPath pathPart
	endfor
end

function /s PackageDiskLocation(module,package[,default_,create,quiet])
	string module,package
	variable default_ // The location of the default, with the manifest.   
	variable create,quiet
	
	string path=ModuleDiskLocation(module,default_=default_,create=create,quiet=quiet)
	variable generic=IsGenericPackage(module,package)
	string extension=selectstring(generic,"",".pxp")
	path=joinpath({path,package})+extension
	string err="Could not find disk location for package '%s' at %s.\r"
	if(!generic)
		if(create)
			newpath /o/c/q/z currPath path
		else
			newpath /o/q/z currPath path
			if(v_flag && !quiet)
				printf err,package,path
			endif
		endif
	else
		getfilefolderinfo /q/z path
		if(v_flag && !quiet)
			printf err,package,path
		endif
	endif
	return path
end

function /s InstanceDiskLocation(module,package,instance[,quiet])
	string module,package,instance
	variable quiet
	
	string path=PackageDiskLocation(module,package,quiet=quiet)
	newpath /o/q/z currPath path
	string loc=""
	if(!v_flag)
		string file=instance+".pxp"
		GetFileFolderInfo /P=currPath /Q/Z=1 file
		if(v_flag)
			if(!quiet)
				printf "Could not find disk location for instance %s of package %s at location %s\r.",instance,package,path
			endif
		else
			loc=joinpath({path,file})
		endif
	endif
	return path
end

Function /s ProfilePath([module,package])
	string module,package
	
#ifdef Core
	if(paramisdefault(package) && !paramisdefault(module))
		string path=ModuleDiskLocation(module)
	elseif(paramisdefault(module))
		path=SpecialDirPath("Desktop",0,0,0)
	else
		path=PackageDiskLocation(module,package)
	endif	
#else
	string path=SpecialDirPath("Desktop",0,0,0)
#endif
	return path
End

function /df ModuleHome(module[,create,quiet])
	string module
	variable create,quiet
	
	variable err
	string loc=joinpath({moduleHome_,module})
	dfref df=$loc
	if(!datafolderrefstatus(df))
		if(create)
			NewFolder(loc)
			df=ModuleHome(module,quiet=quiet)
		elseif(!quiet)
			printf "Could not find module home for module %s at location %s.\r",module,loc
		endif
	endif
	return df
end

function /df PackageHome(module,package[,sub,create,quiet,load])
	string module,package,sub
	variable create // Create a folder for the package.  
	variable quiet,load
	
	// Only generic packages will have subpackages immediately beneath them.  
	// Non-generic packages will have subpackages beneath the *instance* folder.  
	sub=selectstring(!paramisdefault(sub) && IsGenericPackage(module,package),"",sub)
	dfref moduleDF = ModuleHome(module,create=create,quiet=quiet)
	string loc=joinpath({getdatafolder(1,moduleDF),package,sub})
	dfref df=$loc
	if(!datafolderrefstatus(df))
		if(load)
			LoadPackage(module,package,quiet=quiet)
			df=PackageHome(module,package,sub=sub,quiet=quiet,load=0)
		elseif(create)
			NewFolder(loc)
			df=PackageHome(module,package,sub=sub,quiet=quiet)
		elseif(!quiet)
			printf "Could not find data for %spackage '%s' at location '%s'.\r",selectstring(strlen(sub),"","sub"),joinpath({package,sub}),loc
		endif
	endif
	return df
end

function /df NewInstanceHome(module,package[,sub,scratch,quiet])
	string module,package,sub
	variable scratch,quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	string loc=joinpath({moduleInfo,module,"New",sub})
	if(scratch)
		killdatafolder /z $loc
	endif
	NewFolder(loc)
	dfref df=$loc
	if(!datafolderrefstatus(df) && !quiet)
		printf "Could not find temporary home for new instance of package %s at location %s.\r",package,loc
	endif
	return df
end
	
function /df InstanceHome(module,package,instance[,sub,create,quiet])
	string module,package,instance,sub
	variable create // Create the folder for the instance (but don't fill it with content).  
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	if(stringmatch(instance,"_new_"))
		return NewInstanceHome(module,package,sub=sub,quiet=quiet)
	endif
	string origInstance=instance
	variable generic=IsGenericPackage(module,package,quiet=quiet)
	strswitch(instance)
		case "":
		case "_default_":
			if(generic)
				instance=""
			else
				instance=DefaultInstance(module,package,quiet=quiet)//defaultInstanceName
			endif
			break
	endswitch
	
	variable package_create = paramisdefault(create) ? 1 : create
	dfref df_=PackageHome(module,package,create=package_create,quiet=quiet)
	string loc=JoinPath({getdatafolder(1,df_),instance,sub})
	dfref df = $loc
	if(!datafolderrefstatus(df))
		if(create)
			NewFolder(loc)
			df=InstanceHome(module,package,instance,sub=sub,quiet=1)
		elseif(!quiet && !generic)
			printf "Could not find data for instance '%s' of package '%s' at location '%s'.\r",instance,package,loc
		endif
	endif
	return df
end

function InstanceExists(module,package,instance[,quiet])
	string module,package,instance
	variable quiet

	dfref df=PackageHome(module,package,quiet=quiet)
	dfref instanceDF=df:$instance
	return strlen(instance) && datafolderrefstatus(instanceDF)>0
end

function IsBlank(str)
	string str
	
	variable i,result=1
	for(i=0;i<strlen(str);i+=1)
		strswitch(str[i])
			case " ":
			case "\r":
			case "\n":
			case "\t":
				break
			default:
				result=0
		endswitch
	endfor
	return result
end

function /df DefaultInstanceHome(module,package[,sub,quiet])
	string module,package,sub
	variable quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	string instance=DefaultInstance(module,package)
	return InstanceHome(module,package,instance,sub=sub,quiet=quiet)
end

function CopyDefaultInstanceObject(module,package,destInstance,object[,context,sub])
	string module,package,destInstance,object,context,sub
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	context=selectstring(!paramisdefault(context),"",context)
	variable err=0
	dfref manifestDF=ObjectManifest(module,package,object,sub=sub)
	string loc=joinpath({getdatafolder(1,manifestDF),"value"})
	string type=ObjectType(loc)
	dfref df=InstanceHome(module,package,destInstance)
	strswitch(type)
		case "WAV":
		case "WAVT":
			duplicate /o $loc,df:$object
			duplicate /o $loc,df:$object
			break
		case "VAR":
			nvar var=$loc
			variable /g df:$object=var
			break
		case "STR":
			svar str=$loc
			string /g df:$object=str
			break
		default:
			printf "Could not find any object in the manifest at %s.\r",loc
			err=-1
	endswitch
	if(!err)
		RunObjectGenerator(module,package,destInstance,object,context=context,sub=sub)
	endif
	return err
end

function /df CopyDefaultInstance(module,package,newInstance[,context,quiet])
	string module,package,newInstance,context
	variable quiet
	
	context=selectstring(!paramisdefault(context),"",context)
	return CopyInstance(module,package,DefaultInstance(module,package,quiet=quiet),newInstance,useGenerators=1,context=context,quiet=quiet)
end

function /df CopyInstance(module,package,instance,newInstance[,sub,useGenerators,context,quiet])
	string module,package,instance,newInstance,sub,context
	variable useGenerators,quiet
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	context=selectstring(!paramisdefault(context),"",context)
	
	string defaultInstance_=DefaultInstance(module,package,forceManifest=1,quiet=quiet)
	dfref instanceDF = InstanceHome(module,package,instance,sub=sub)
	if(!datafolderrefstatus(instanceDF))
		if(!quiet)
			printf "Copying from default instance '%s' instead of lost instance '%s'.\r",defaultInstance_,instance 
		endif
		instance = "_default_"
	endif
	if(stringmatch(instance,"_default_") || stringmatch(instance,"")) // If copying from default instance.  
		if(!InstanceExists(module,package,defaultInstance_,quiet=quiet))
			LoadPackageInstance(module,package,defaultInstance_,quiet=quiet)
		endif
		instance = defaultInstance_
		instanceDF = InstanceHome(module,package,defaultInstance_,sub=sub)
		useGenerators=1
	endif
		
	dfref packageDF=PackageHome(module,package,quiet=quiet)
	dfref newInstanceDF=packageDF:$newInstance
	if(datafolderrefstatus(newInstanceDF))
		killdatafolder /z newInstanceDF
		if(v_flag)
			printf "Could not kill '%s'.\r",getdatafolder(1,newInstanceDF)
		endif
	endif
	if(!datafolderrefstatus(newInstanceDF))
		if(datafolderrefstatus(instanceDF) && datafolderrefstatus(packageDF))
			duplicatedatafolder instanceDF packageDF:$newInstance
			if(useGenerators)
				RunInstanceGenerators(module,package,newInstance,context=context,quiet=quiet)
			endif
		else
			printf "Either package '%s' or instance '%s' could not be found.\r",package,instance
		endif
		instanceDF=packageDF:$newInstance
	endif
	return instanceDF
end

// For loading generic packages from the manifest instead of from a custom instance on disk.  
// Could also load an instance of a non-generic package, built from manifest defaults.  
function LoadPackageFromManifest(module,package[,sub,quiet])
	string module,package
	string sub // A subfolder of the generic package to load.  
	variable quiet
	
	variable err=0
	variable generic=IsGenericPackage(module,package,quiet=quiet)
	sub=selectstring(!paramisdefault(sub),"",sub)
	dfref source=PackageManifest(module,package,sub=sub,quiet=quiet)
	dfref dest=PackageHome(module,package,create=1,sub=sub,quiet=quiet)
	string destLoc=getdatafolder(1,dest)
	string instance=selectstring(generic,DefaultInstance(module,package,quiet=quiet),"")
	destLoc=joinpath({destLoc,instance,sub})
	NewFolder(destLoc)
	dest=$destLoc
	if(!datafolderrefstatus(source))
		if(!quiet)
			printf "Could not load package %s from manifest; unable to create %s\r",package,getdatafolder(1,source)
		endif
		err=-1
	else
		variable i,j
		for(i=0;i<CountObjectsDFR(source,4);i+=1)
			string object=GetIndexedObjNameDFR(source,4,i)
			dfref sourceObject=source:$object
			string objectLoc=getdatafolder(1,sourceObject)
			string type=ObjectType(objectLoc+"value")
			strswitch(type)
				case "WAV":
					wave /z WAVvalue=sourceObject:value
					duplicate /o WAVvalue dest:$object
					if(numpnts(WAVValue)==0)
						redimension /n=1 dest:$object
					endif
					break
				case "WAVT":
					wave /z/t WAVTvalue=sourceObject:value
					duplicate /o/t WAVTvalue dest:$object /wave=WAVT
					if(numpnts(WAVTValue)==0)
						redimension /n=1 dest:$object
					endif
					WAVT=stringfromlist(0,WAVT)
					break
				case "VAR":
					nvar /z VARvalue=sourceObject:value
					variable /g dest:$object=VARvalue
					break
				case "STR":
					svar /z STRvalue=sourceObject:value
					if(IsSubPackage(module,package,object,quiet=quiet))
						LoadPackageFromManifest(module,package,sub=joinpath({sub,object}),quiet=quiet) // Recursively go through subfolders to load package components.  
					else
						string /g dest:$object=stringfromlist(0,STRvalue)
					endif
					break
			endswitch
			RunObjectGenerator(module,package,instance,object,sub=sub,quiet=quiet)
		endfor
	endif
	return err
end

// Hooks to run when a new instance is created, to fill it with appropriate values, usually taken from the context.  
function RunInstanceGenerators(module,package,instance[,context,sub,quiet])
	string module,package,instance,context,sub
	variable quiet
	
	context=selectstring(!paramisdefault(context),"",context)
	sub=selectstring(!paramisdefault(sub),"",sub)
	dfref manifestDF=PackageManifest(module,package,quiet=quiet)
	variable i,err=0
	for(i=0;i<CountObjectsDFR(manifestDF,4);i+=1)
		string object=GetIndexedObjNameDFR(manifestDF,4,i)
		if(IsSubPackage(module,package,object))
			err+=RunInstanceGenerators(module,package,instance,context=context,sub=joinpath({sub,object}),quiet=quiet)
		else
			err+=RunObjectGenerator(module,package,instance,object,context=context,sub=sub,quiet=quiet)
		endif	
	endfor
	return err
end

function RunObjectGenerator(module,package,instance,object[,context,sub,quiet])
	string module,package,instance,object,context,sub
	variable quiet
	
	context=selectstring(!paramisdefault(context),"",context)
	sub=selectstring(!paramisdefault(sub),"",sub)
	variable i,err=0
	dfref instanceDF=InstanceHome(module,package,instance,sub=sub,quiet=quiet)
	strswitch(PackageObjectType(module,package,object,sub=sub,quiet=quiet))
		case "STR":
			svar /z/sdfr=instanceDF str=$object
			if(!svar_exists(str))
				make /free/t/n=1 w="_default"
			else	
				make /free/t/n=1 w=str
			endif
			break
		case "WAVT":
			wave /z/t/sdfr=instanceDF w=$object
			if(!waveexists(w))
				make /free/t/n=1 w="_default"
			endif
			break
	endswitch
	if(waveexists(w)) // If a free wave was just created in the preceding switch statement.  
		for(i=0;i<numpnts(w);i+=1)
			strswitch(w[i])
				case "_default_": // If an element of the value setting is set to the default.  
					string child=ChildPackage(module,package,object,sub=sub,quiet=quiet)
					string childInstance=DefaultInstance(module,child,quiet=quiet)
					SetPackageSetting(module,package,instance,object,childInstance,sub=sub,indices={i},quiet=quiet) // Set it to the default instance for the child package.  
					break
				case "_chan_":
					string chan=stringbykey("_chan_",context)
					if(strlen(chan))
						SetPackageSetting(module,package,instance,object,chan,sub=sub,indices={i},quiet=quiet)
					endif
					break
			endswitch
		endfor
	endif
	string cmd=GeneratorCommand(module,package,instance,object,sub=sub,context=context,quiet=quiet)
	if(strlen(cmd))
		dfref df=InstanceHome(module,package,instance,sub=sub,quiet=quiet)
		dfref currDF=GetDataFolderDFR()
		setdatafolder df
		execute /q/z cmd
		err=v_flag
		setdatafolder currDF
	endif
	return err
end

function /s GeneratorCommand(module,package,instance,object[,sub,context,quiet])
	string module,package,instance,object,sub,context
	variable quiet
	
	context=selectstring(!paramisdefault(context),"",context)
	sub=selectstring(!paramisdefault(sub),"",sub)
	dfref manifestDF=ObjectManifest(module,package,object,sub=sub)
	svar /z/sdfr=manifestDF generator
	string cmd=""
	if(svar_exists(generator))
		cmd=generator
	else
		dfref instanceDF=InstanceHome(module,package,instance,sub=sub)
		string loc=joinpath({getdatafolder(1,instanceDF),object})
		string value=ObjectContents(loc)
		strswitch(ObjectType(loc))
			case "STR":
				cmd="value="+value
				break
			case "WAVT":
				wave /t w=$loc
				if(dimsize(w,0)==numpnts(w))
					cmd="value="+value	
				elseif(!quiet)
					printf "Cannot run intrinsic object generator on a multidimensional wave.\r"
				endif
				break
		endswitch
	endif
	if(strlen(cmd))
		variable i
		for(i=0;i<itemsinlist(context);i+=1)
			string oneContext=stringfromlist(i,context)
			string replace=stringfromlist(0,oneContext,":")
			string with=stringfromlist(1,oneContext,":")
			cmd=replacestring(replace,cmd,with)
		endfor
		cmd=replacestring("_module_",cmd,module)
		cmd=replacestring("_package_",cmd,package)
		cmd=replacestring("_instance_",cmd,instance)
		cmd=replacestring("_object_",cmd,object)
		cmd=replacestring("_quiet_",cmd,num2str(quiet))
		cmd=replacestring("value",cmd,getdatafolder(0,manifestDF)) // Replace "value" with name of the manifest's object folder, which is the name of the object in the instance folder.  
	endif
	return cmd
end

function /s ObjectContents(loc)
	string loc
	
	string result=""
	string type=ObjectType(loc)
	strswitch(type)
		case "WAV":
			wave wav=$loc
			variable i
			result="{"
			for(i=0;i<numpnts(wav);i+=1)
				result+=num2str(wav[i])+","
			endfor
			result=removeending(result,",")+"}"
			break
		case "WAVT":
			wave /t wavt=$loc
			result="{"
			for(i=0;i<numpnts(wavt);i+=1)
				result+="\""+replacestring("\"",wavt[i],"\\\"")+"\","
			endfor
			result=removeending(result,",")+"}"
			break
		case "VAR":
			nvar var=$loc
			result=num2str(var)
			break
		case "STR":
			svar str=$loc
			result="\""+replacestring("\"",str,"\\\"")+"\""
			break
		case "FLDR":
			result=type
			break
	endswitch
	return result
end

Function SavePackageInstance(module,package,instance[,special])
	string module,package,instance,special
	
	variable err=0
	dfref currDF=getdatafolderdfr()
	// Module specific functions.  
	funcref SavePackageInstance f=$(module+"SavePackageInstance")
	if(strlen(stringbykey("NAME",funcrefinfo(f))))
		f(module,package,instance)
	endif
	
	string path
	sprintf path,"%sprofiles:%s:%s",SpecialDirPath("Packages",0,0,0),CurrProfileName(),module
	variable generic=IsGenericPackage(module,package)
	dfref instanceDF=InstanceHome(module,package,instance)
	if(!generic)
		path+=":"+package
		string toSave=instance
	else
		toSave=package
	endif
	NewPath /O/Q/C currPath,path
	if(v_flag)
		printf "Path %s could not be created.\r",path
		err=-1
	elseif(!datafolderrefstatus(instanceDF))
		err=-2
	else
		string objectList=PackageObjectList(module,package)
		objectList=SaveDataJOrderList(objectList) // Kludge until SaveData /J is fixed.  
		dfref currDF=getdatafolderdfr()
		setdatafolder instanceDF
		string /g saved_=""
		sprintf saved_,"TIMESTAMP:%d",datetime
		SaveData /J=(objectList)/O/P=currPath /R/Q toSave+".pxp"
		if(v_flag)
			err=-2
		endif
		setdatafolder currDF
	endif
	return err
End

function /s PackageObjectList(module,package[,sub])
	string module,package,sub
	
	sub=selectstring(!paramisdefault(sub),"",sub)
	dfref manifestDF=PackageManifest(module,package,sub=sub)
	
	variable i
	string list=""
	for(i=0;i<CountObjectsDFR(manifestDF,4);i+=1)
		string object=GetIndexedObjNameDFR(manifestDF,4,i)
		if(IsSubPackage(module,package,object))
			list+=PackageObjectList(module,package,sub=joinpath({sub,object}))
		else
			list+=object+";"
		endif
	endfor
	return list
end

// Re-ordering of list to work around bug in SaveData /J.  
function /s SaveDataJOrderList(list)
	string list
	
	string newList1="",newList2=""
	variable i,j
	for(i=0;i<itemsinlist(list);i+=1)
		string itemi=stringfromlist(i,list)
		for(j=0;j<itemsinlist(list);j+=1)
			string itemj=stringfromlist(j,list)
			if(i!=j && stringmatch(itemi,itemj+"*"))
				newList2+=itemi+";"
				break
			endif
		endfor
		if(j==itemsinlist(list))
			newList1+=itemi+";"
		endif
	endfor
	return newList1+newList2
end

// Applies a loaded package instance to the given channel.  
Function SelectPackageInstance(module,package,instance[,special])
	String package,instance,special,module
	Variable chan
	
	special=selectstring(!paramisdefault(special),"",special)
	funcref SelectPackageInstance f=$(module+"#SelectPackageInstance")
	if(strlen(stringbykey("NAME",funcrefinfo(f))))
		f(module,package,instance,special=special)
	endif
End

// ------------------------ Utility Functions -------------------------- //

function /s JoinPath(folders)
	wave /t folders
	
	string path=""
	variable i
	for(i=0;i<numpnts(folders);i+=1)
		string folder=folders[i]
		if(i>0 && stringmatch(folder[0],":"))
			folder=folder[1,strlen(folder)-1]
		endif
		folder=removeending(folder,":")
		if(strlen(folder))
			path+=folder+":"
		endif
	endfor
	path=removeending(path,":")
	return path
end

function /s JoinLists(lists)
	wave /t lists
	
	string joined=""
	variable i
	for(i=0;i<numpnts(lists);i+=1)
		string list=lists[i]
		list = removeending(list,";")
		if(strlen(list))
			joined += removeending(list,";")+";"
		endif
	endfor
	return joined
end

// Returns the data type found at the path passed in 'data_loc'.  Returns an empty string if no data object is found there.  
Function /S ObjectType(data_loc)
	string data_loc
	string result=""
	if(datafolderexists(data_loc))
		result="FLDR"
	else
		variable exist=exists(data_loc)
		if(exist==1)
			wave /Z myWave=$data_loc
			if(WaveExists(myWave))
				if(WaveType(myWave))
					result="WAV" // Numeric wave.  
				else
					result="WAVT" // Text wave.  
				endif
			endif
		elseif(exist==2)
			nvar /Z myVar=$data_loc
			if(NVar_Exists(myVar))
				result="VAR" // Numeric variable.  
			endif
			svar /Z myStr=$data_loc
			if(SVar_Exists(myStr))
				if(stringmatch(myStr,"_folder_"))
					result="FLDR"
				else
					result="STR" // String variable.  
				endif
			endif
		endif
	endif
	return result
End

function SetObject(objLoc,val[,indices,quiet])
	string objLoc,val
	wave indices
	variable quiet
	
	if(paramisdefault(indices))
		make /free/n=1 indices=0
	endif
	string type=ObjectType(objLoc)
	strswitch(type)
		case "VAR":
			nvar /z var=$objLoc
			if(nvar_exists(var))
				var=str2num(val)
			else
				return -1
			endif
			break
			break
		case "STR":
			svar /z str=$objLoc
			if(svar_exists(str))
				str=val
			else
				return -1
			endif
			break
		case "WAV":
			wave /z wav=$objLoc
			if(waveexists(wav))
				variable i
				for(i=0;i<numpnts(indices);i+=1)
					wav[indices[i]]=str2num(stringfromlist(i,val))
				endfor
			else
				return -1
			endif
			break
		case "WAVT":
			wave /z/t wavt=$objLoc
			if(waveexists(wavt))
				for(i=0;i<numpnts(indices);i+=1)
					wavt[indices[i]]=stringfromlist(i,val)
				endfor
			else
				return -1
			endif
			break
	endswitch
end

// Recursively create a deep subfolder by creating all of its parent folders, if necessary.  
Function /df NewFolder(folderStr[,go])
	String folderStr
	Variable go // Go to the newly created folder.  
	
	String currFolder=GetDataFolder(1)
	Variable i=1
	Do
		if(StringMatch(folderStr[i],":"))
			SetDataFolder ::
			i+=1
		else
			break
		endif
	While(1)
	
	for(i=0;i<ItemsInList(folderStr,":");i+=1)
		String subFolder=StringFromList(i,folderStr,":")
		if(StringMatch(subFolder,"root"))
			SetDataFolder root:
		elseif(!strlen(subFolder))
		else
			NewDataFolder /O/S $subFolder
		endif
	endfor

	if(!go)
		SetDataFolder $currFolder
	endif
	dfref df=$folderStr
	return df
End

Function GetWinCoords(win,coords[,forcePixels])
	String win
	STRUCT rect &coords
	Variable forcePixels // Force values to be returned in pixels in cases where they would be returned in points.  
	Variable type=WinType(win)
	Variable factor=1
	if(type)
		GetWindow $win wsize;
		if(type==7 && forcePixels==0)
			factor=ScreenResolution/72
		endif
		coords.left=V_left*factor
		coords.top=V_top*factor
		coords.right=V_right*factor
		coords.bottom=V_bottom*factor
	else
		printf "No such window '%s'\r",win
	endif
End
//#endif