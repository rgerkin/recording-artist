// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/NotebookBrowser.ipf $
// $Author: rick $
// $Rev: 566 $
// $Date: 2011-07-14 09:16:22 -0400 (Thu, 14 Jul 2011) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=NotebookBrowser

constant fileLeft=5
constant notebookLeft=275
constant listTop=25

#include "ExtractPackedNotebooks"

Menu "Misc"
	"Notebook Browser",NotebookBrowser#Init()
End

static Function Init()
	NewDataFolder /O/S root:Packages
	NewDataFolder /O/S NotebookBrowser
	Make /o/n=0/T Files="",Text=""
	Make /o/n=0 SelectedFiles=0,SelectedText=0
	String /G root:Packages:NotebookBrowser:notebookStr=""
	String /G path=SpecialDirPath("Desktop",0,0,0)
	String /G loadedName=""
	Variable /G formatted=0
	NewPath /O/Q NotebookBrowserPath, path
	MakePanel()
End

static Function MakePanel()
	DoWindow /K NotebookBrowserPanel
	NewPanel /K=1/N=NotebookBrowserPanel/W=(100,100,650,350) as "Notebook Browser"
	SetWindow NotebookBrowserPanel hook(Hook)=NotebookBrowser#WinHook, hookEvents=2
	SetDataFolder root:Packages:NotebookBrowser
	Button SetPath, proc=NotebookBrowserButtons, title="Path:"
	SetVariable Path size={350,20}, value=path, title=" "
	Checkbox Formatted variable=root:Packages:NotebookBrowser:formatted, title="Formatted"
	Listbox Files mode=1, pos={fileLeft,listTop}, size={250,200}, listWave=Files,selWave=SelectedFiles,proc=NotebookBrowserListboxes
	ListFiles()
	ListBox NotebookText mode=0, pos={notebookLeft,listTop}, size={250,200}, listWave=Text,selWave=SelectedText
End

static Function WinHook(info)
	Struct WMWinHookStruct &info
	strswitch(info.eventName)
		case "resize":
			GetWindow NotebookBrowserPanel, wsizeDC
			Listbox Files size={250,V_bottom-V_top-listTop-15}, win=$info.winName
			ListBox NotebookText size={V_right-V_left-notebookLeft-10,V_bottom-V_top-listTop-10}, win=$info.winName
	endswitch
End

Function NotebookBrowserButtons(ctrlName)
	String ctrlName
	
	strswitch(ctrlName)
		case "SetPath":
			SVar path=root:Packages:NotebookBrowser:path
			NewPath /O/Q NotebookBrowserPath
			if(V_flag==0)
				PathInfo NotebookBrowserPath
				path=S_path
			endif
			ListFiles()
			break
	endswitch
End

Function NotebookBrowserListboxes(info)
	Struct WMListboxAction &info
	
	if(info.eventCode!=2)
		return -1
	endif
	strswitch(info.ctrlName)
		case "Files":
			Wave /T Files=root:Packages:NotebookBrowser:Files
			String file=Files[info.row]
			SVar loadedName=root:Packages:NotebookBrowser:loadedName
			NVar formatted=root:Packages:NotebookBrowser:formatted
			if(strlen(loadedName))
				DoWindow /K $loadedName // Kill most recently opened notebook.  
			endif
			String notebookFiles=ExtractPackedNotebooks("NotebookBrowserPath",file)
			String notebookFile=StringFromList(0,notebookFiles)
			if(!strlen(notebookFile))
				return -2
			endif
			loadedName=UniqueName("Notebook",10,0)
			OpenNotebook /P=NotebookBrowserPath /N=$(loadedName) /K=1 /V=0 notebookFile
			Notebook $loadedName selection={startOfFile,endOfFile}
			GetSelection notebook, $loadedName, 2
			SVar notebookStr=root:Packages:NotebookBrowser:notebookStr
			notebookStr=S_Selection
			if(!formatted)
				DoWindow /K $loadedName // Kill formatted notebook since plain text has already been extracted.  
			else
				Notebook $loadedName selection={startOfFile,startOfFile} // Deselect notebook text.  
				GetWindow NotebookBrowserPanel,wsize
				MoveWindow /W=$loadedName V_right,V_top,V_right+300,V_top+300
				DoWindow /T $loadedName file
				DoWindow /F $loadedName
			endif
			Wave /T Text=root:Packages:NotebookBrowser:Text
			Wave SelectedText=root:Packages:NotebookBrowser:SelectedText
			Variable lines=ItemsInList(notebookStr,"\r")
			Redimension /n=(lines) Text,SelectedText
			Text=StringFromList(p,notebookStr,"\r")
			SelectedText=0
			break
	endswitch
End

static Function ListFiles()
	String file
	Variable i=0
	Wave /T Files=root:Packages:NotebookBrowser:Files
	Wave SelectedFiles=root:Packages:NotebookBrowser:SelectedFiles
	Redimension /n=0 Files
	Do
		file=IndexedFile(NotebookBrowserPath,i,".pxp")
		if(!strlen(file))
			break
		endif
		Files[numpnts(Files)]={file}
		i+=1
	While(1)
	Redimension /n=(numpnts(Files)) SelectedFiles
	SelectedFiles=0
End