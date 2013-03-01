// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Data%20Browser.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=Browser

Function Create()
	NewDataFolder /O/S root:Packages
	NewDataFolder /O/S DataBrowser
	DoWindow /K DataBrowser
	Make /o/T/n=1 Name="root:",FullPath="root:"
	Make /o/T/n=3 Facts=""
	Make /o/n=3 FactsSel=(p==0) ? 2 : 0
	Make /o/n=1 DataSel=64,Type=4
	Variable /G lastSelection=0,mouseDownSelection=0
	NewPanel /K=1/N=DataBrowser /W=(100,100,500,500)
	ListBox Data, listWave=Name, selWave=DataSel, size={250,300}, mode=4, font="Courier", proc=DataBrowserListBoxes
	ListBox Facts, listWave=Facts, selWave=FactsSel, pos={0,310}, size={250,50}, mode=0, proc=DataBrowserListBoxes
	String /G OS=StringByKey("OS",IgorInfo(3))
	SetDataFolder root:
End

Function DataBrowserListBoxes(info)
	Struct WMListBoxAction &info
	
	DFRef f=root:Packages:DataBrowser
	Wave DataSel=f:DataSel, Type=f:Type 
	Wave /T Name=f:Name, FullPath=f:FullPath, Facts=f:Facts
	NVar lastSelection=f:lastSelection
	
	strswitch(info.ctrlName)
		case "Data":
			if(info.eventCode !=1 && info.eventCode !=2)
				return -1
			endif
			if(info.ctrlRect.right-info.mouseLoc.h<15) // The scroll bar was clicked.  
				return -2
			endif
			
			DFRef f=root:Packages:DataBrowser
			Wave DataSel=f:DataSel, Type=f:Type 
			Wave /T Name=f:Name, FullPath=f:FullPath, Facts=f:Facts
			Variable row=info.row
		
			String object=Name[row]
			String path=FullPath[row]
			switch(info.eventCode)
				case 1: // Mouse down.  
					if(info.eventMod & 16) // Right mouse button.  
						String menuStr=""
						switch(Type[row]) // Data Type
							case 1: // Wave
								menuStr+="Display;Edit;"
								if(dimsize($fullPath,1)>1)
									menuStr+="NewImage;"
								endif
								break
							case 2: // Variable
								break
							case 3: // String
								break
							case 4: // Folder
								menuStr+="SetDataFolder;"
								break
						endswitch
						menuStr+="Copy Full Path;Delete;"
						PopupContextualMenu menuStr
						strswitch(S_Selection)
							case "Display":
								Display /K=1 $path
								break
							case "Edit":
								Edit /K=1 $path
								break
							case "NewImage":
								NewImage /K=1 $path
								break
							case "SetDataFolder":
								SetDataFolder $path
								break
							case "Copy Full Path":
								PutScrapText path
								break
							case "Delete":
								DoAlert 1,"Are you sure you want to delete "+path+"?"
								if(V_flag==1)
									switch(Type[row])
										case 1:
											KillWaves /Z $path
											break
										case 2:
											KillVariables /Z $path
											break
										case 3:
											KillStrings /Z $path
											break
										case 4:
											KillDataFolder /Z $path
											break
									endswitch
								endif
								break
						endswitch
					endif
					if(info.eventMod & 1) // Left mouse button.  
						String factsStr=DataBrowserFacts(path,Type[row])
						Facts=StringFromList(p,factsStr)
						
						NVar mouseDownSelection=f:mouseDownSelection
						mouseDownSelection=row
					endif
					break
				case 2: // Mouse up.  
					SVar OS=f:OS
					if(!(info.eventMod & 1) && StringMatch("OS","Windows*")) // Left mouse button was not down.  
						//DataSel[row]=(DataSel[row] %^ 16) // Set disclosure box to its state before the mouse click.  
						break
					endif
					
					if(Type[row] == 4 && info.mouseLoc.h<15) // Folder disclosure box clicked.  
						String folder=object
						Variable depth=ItemsInList(path,":")-1
						folder=ReplaceString("\t",folder,"")
						Variable i,j
						if(!(DataSel[row] & 16)) // Currently open.  
							CloseFolder(row)
						else // Currently closed.  
							for(i=1;i<=4;i+=1) // Iterate over all object types.  
								//path=RemoveEnding(path,":")+":"
								for(j=0;j<CountObjects(path,i);j+=1)
									object=GetIndexedObjName(path,i,j)
									InsertPoints row+j+1,1,Name,FullPath,Type,DataSel
									Name[row+j+1]=DataBrowserDataTypes(i)+SelectString(i==4,"\t\t","")+RepeatString("\t\t",depth)+object
									FullPath[row+j+1]=RemoveEnding(path,":")+":"+object
									Type[row+j+1]=i
									DataSel[row+j+1]=64*(i==4) // Make it expandable if it is a folder.  
								endfor
							endfor
						endif
						break
					endif
					if(Type[row]==4) // Mouse up on a folder.  
						DataSel[row]=(DataSel[row] %^ 1)
						NVar mouseDownSelection=f:mouseDownSelection
						if(row!=mouseDownSelection) // Mouse down and mouse up not on the same object.  
							DFRef destFolder=$path
							String sourceLoc=FullPath[mouseDownSelection]
							String objName=ObjNameFromFullPath(sourceLoc)
							if(exists(path+":"+objName))
								DoAlert 1,"An object with the same name already exists at the destination.  Overwrite?"
								if(V_flag!=1)
									break
								endif
							endif
							switch(Type[mouseDownSelection])
								case 1: // Wave
									Wave /Z DestWave=destFolder:$objName
									if(WaveExists(DestWave))
										KillWaves /Z DestWave
									endif
									if(WaveExists(DestWave))
										Rename DestWave,$UniqueName(NameOfWave(DestWave),1,0)
									endif
									MoveWave $sourceLoc destFolder
									break
								case 2: // Variable
									NVar sourceVar=$sourceLoc
									Variable /G destFolder:$objName=sourceVar
									KillVariables /Z $sourceLoc
									break
								case 3: // String
									SVar sourceStr=$sourceLoc
									String /G destFolder:$objName=sourceStr
									KillStrings /Z $sourceLoc
									break
								case 4: // Folder  
									CloseFolder(mouseDownSelection)
									DFRef DestF=destFolder:$objName
									if(DataFolderRefStatus(DestF))
										KillDataFolder /Z DestF
									endif
									if(DataFolderRefStatus(DestF))
										RenameDataFolder DestF,$UniqueName(objName,11,0)
									endif
									MoveDataFolder $sourceLoc destFolder
									break
								default:
									break
							endswitch
							if(DataSel[row] & 16) // Destination folder is currently open (not expanded).  
								MoveObjectInfo(mouseDownSelection,row+1)
							else
								MoveObjectInfo(mouseDownSelection,NaN)
							endif
						endif
					elseif(DataSel[row] & 16) // Strange, but 16 works here. 
						DataSel[row]=DataSel[row] & ~1
					endif
					//if(info.eventMod & 2) // Shift held down.  
					//elseif(info.eventMod & 2) // Control held down.  
					//else
					//	Variable state=DataSel[row]
						//DataSel=DataSel & ~1
					//	print DataSel
					//endif
					//print state
					//DataSel[row]=(state %^ 1)
					DataSel[row]=(DataSel[row] %^ 16) // Set disclosure box to its state before the mouse click.  
					lastSelection=row
			endswitch
			break
		case "Facts":
			if(info.eventCode !=7) // 7 = Finish edit.  
				return -1
			endif
			path=FullPath[lastSelection]
			switch(Type[lastSelection])
				case 1:
					Wave Wav=$path
					Variable rows,cols,layers
					sscanf Facts[0],"%d x %d x %d",rows,cols,layers
					Redimension /n=(rows,cols,layers) Wav
					break
				case 2:
					NVar var=$path
					var=str2num(Facts[0])
					break
				case 3:
					SVar str=$path
					str=Facts[0]
					break
				default:
					break
			endswitch
			break
	endswitch
End

Function /S DataBrowserDataTypes(type)
	Variable type
	
	switch(type)
		case 1:
			return "\K(65535,0,0)"
		case 2:
			return "\K(0,65535,0)"
		case 3:
			return "\K(0,0,65535)"
		default:
			return ""
	endswitch
End

Function /S DataBrowserFacts(fullPath,type)
	String fullPath
	Variable type
	
	String facts=""
	switch(type)
		case 1:
			Wave Wav=$fullPath
			sprintf facts,"%d x %d x %d",dimsize(Wav,0),dimsize(Wav,1),dimsize(Wav,2)
			break
		case 2:
			NVar var=$fullPath
			sprintf facts,"%f",var
			break
		case 3:
			SVar str=$fullPath
			sprintf facts,"%s",str
			break
		default:
			break
	endswitch
	return facts
End

Function CloseFolder(row)
	Variable row
	
	DFRef f=root:Packages:DataBrowser
	Wave /T FullPath=f:FullPath,Name=f:Name
	Wave Type=f:Type,DataSel=f:DataSel
	if(row==0)
		Redimension /n=1 Name,FullPath,Type,DataSel
	else
		Variable depth=ItemsInList(FullPath[row],":")-1
		Variable j=row+1
		Do
			Variable subDepth=ItemsInList(FullPath[j],":")-1
			if(subDepth>depth)
				DeletePoints j,1,Name,FullPath,Type,DataSel
			else
				break
			endif
		While(j<dimsize(Name,0))
	endif
End

Function MoveObjectInfo(sourceRow,destRow)
	Variable sourceRow,destRow
	
	DFRef f=root:Packages:DataBrowser
	Wave /T FullPath=f:FullPath,Name=f:Name
	Wave Type=f:Type,DataSel=f:DataSel
	
	if(numtype(destRow))
		Variable offset=0
	else
		offset=(sourceRow>=destRow)
		String newContainingFolder=SelectString(destRow-1,"root:",RemoveEnding(FullPath[destRow-1],":")+":")
		InsertPoints destRow,1,Name,FullPath,Type,DataSel
		
		FullPath[destRow]=FullPath[sourceRow+offset]
		String object=StringFromList(ItemsInList(FullPath[destRow],":")-1,FullPath[destRow],":")
		FullPath[destRow]=newContainingFolder+object
		
		Type[destRow]=Type[sourceRow+offset]
		
		Variable newDepth=ItemsInList(FullPath[destRow],":")-2
		Name[destRow]=Name[sourceRow+offset]
		Name[destRow]=DataBrowserDataTypes(Type[destRow])+SelectString(Type[destRow]==4,"\t\t","")+RepeatString("\t\t",newDepth)+object
		
		DataSel[destRow]=DataSel[sourceRow+offset]
	endif
	
	DeletePoints sourceRow+offset,1,Name,FullPath,Type,DataSel // +1 to account for point inserted by InsertPoints
End

Function /S ObjNameFromFullPath(fullPath)
	String fullPath
	
	fullPath=RemoveEnding(fullPath,":")
	return StringFromList(ItemsInList(fullPath,":")-1,fullPath,":")
End

Function ClearInvalidLines()
	DFRef f=root:Packages:DataBrowser
	Wave /T FullPath=f:FullPath,Name=f:Name
	Wave Type=f:Type,DataSel=f:DataSel
	
	Variable i
	Do
		String path=FullPath[i]
		if(!exists(path) && !DataFolderExists(path))
			DeletePoints i,1,FullPath,Name,Type,DataSel
		else
			i+=1
		endif
	While(i<numpnts(FullPath))
End