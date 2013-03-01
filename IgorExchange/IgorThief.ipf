#pragma rtGlobals=1		// Use modern global access method.

#pragma rtGlobals=1		// Use modern global access method.
#pragma version=1.0

//Constants
static Constant kLinearAxis=0
static Constant kLogAxis=1

//Action constants
static Constant kNoAction=0
static Constant kXminAction=1
static Constant kXmaxAction=2
static Constant kYminAction=3
static Constant kYmaxAction=4
static Constant kDigitizeAction=5

//Button and variable title string constants
static StrConstant ksLoadImage="Load Image"
static StrConstant ksStartDigitizing="Start Digitizing"
static StrConstant ksStopDigitizing="Stop Digitizing"
static StrConstant ksSetXminPoint="Set Xmin Point"
static StrConstant ksSetXmaxPoint="Set Xmax Point"
static StrConstant ksXmin="Xmin"
static StrConstant ksXmax="Xmax"
static StrConstant ksLogXAxis="Log X Axis"
static StrConstant ksXData="X Data"
static StrConstant ksSetYminPoint="Set Ymin Point"
static StrConstant ksSetYmaxPoint="Set Ymax Point"
static StrConstant ksYmin="Ymin"
static StrConstant ksYmax="Ymax"
static StrConstant ksLogYAxis="Log YAxis"
static StrConstant ksYData="Y Data"
static StrConstant ksNewWave="New Wave"
static StrConstant ksNewWaveDialog="Name of New Wave"

//This function adds IgorThief to the Data menu under the submenu Packages
Menu "Data"
	Submenu "Packages"
		"IgorThief",Execute/P "IgorThief()"
	End
End

//Prompts for an image file, then loads it, displays it, and appends 
//markers for the locations of xmin,xmax,ymin,ymax.
//Called when button pressed.
Function LoadProc(ctrlName) : ButtonControl
	String ctrlName
	
	//Save location of current data folder
	String oldDF= GetDataFolder(1)
	//Create data folder "root:Packages:IgorThief" and switch to it
	NewDataFolder/O/S root:Packages
	NewDataFolder/O/S root:Packages:IgorThief
	
	//Load image from file, giving name image, overwriting existing file if necessary
	ImageLoad/O/N=image
	if(V_flag==0)
		return 1
	endif
	String imagename = StringFromList(0,S_waveNames)
	//Append image to topmost window, after removing image to make sure only one copy on graph
	RemoveImage/Z $imagename
	AppendImage $imagename
	//Make the graph look nice
	SetAxis/A/R left
	ModifyGraph margin=1
	ModifyGraph tick=3,mirror=0,noLabel=2,axThick=0,standoff=0
	
	//Reference global variable gActionFlag, creating it if it doesn't exist
	NVAR gActionFlag
	if(NVAR_Exists(gActionFlag)==0)
		variable/g gActionFlag=kNoAction
		NVAR gActionFlag
	endif
	
	//Set gActionFlag to zero (no action), and set digitize button to show string ksStartTitle
	gActionFlag=kNoAction
	Button digitize,title=ksStartDigitizing
	
	//Reference gXminx,gXminy,gXmaxx,gXmaxy, creating if they don't exist.
	Wave gXminx,gXminy,gXmaxx,gXmaxy
	if((WaveExists(gXminx)==0)||(WaveExists(gXminy)==0)||(WaveExists(gXmaxx)==0)||(WaveExists(gXmaxy)==0))
		make/o/n=1 gXminx,gXminy,gXmaxx,gXmaxy
		gXminx=NAN
		gXminy=NAN
		gXmaxx=NAN
		gXmaxy=NAN
	endif
	
	//Reference gYminx,gYminy,gYmaxx,gYmaxy, creating if they don't exist.
	Wave gYminx,gYminy,gYmaxx,gYmaxy
	if((WaveExists(gYminx)==0)||(WaveExists(gYminy)==0)||(WaveExists(gYmaxx)==0)||(WaveExists(gYmaxy)==0))
		make/o/n=1 gYminx,gYminy,gYmaxx,gYmaxy
		gYminx=NAN
		gYminy=NAN
		gYmaxx=NAN
		gYmaxy=NAN
	endif
	
	//Append xmin,xmax,ymin,ymax markers to topmost window
	//after removing to make sure only one copy on graph
	RemoveFromGraph/Z gXminy
	RemoveFromGraph/Z gXmaxy
	RemoveFromGraph/Z gYminy
	RemoveFromGraph/Z gYmaxy
	AppendToGraph gXminy vs gXminx
	AppendToGraph gXmaxy vs gXmaxx
	AppendToGraph gYminy vs gYminx
	AppendToGraph gYmaxy vs gYmaxx
	//Make markers look nice
	ModifyGraph mode=3
	ModifyGraph marker(gXminy)=43,rgb(gXminy)=(65535,0,0)
	ModifyGraph marker(gXmaxy)=12,rgb(gXmaxy)=(65535,0,0)
	ModifyGraph marker(gYminy)=43,rgb(gYminy)=(0,0,65535)
	ModifyGraph marker(gYmaxy)=12,rgb(gYmaxy)=(0,0,65535)
	
	//Switch back to saved data folder
	SetDataFolder oldDF
End

//Sets the current action depending on the button pressed, which determines the effect of clicking on the graph
Function ActionProc(ctrlName) : ButtonControl
	String ctrlName
	
	//Save location of current data folder
	String oldDF= GetDataFolder(1)
	//Create data folder "root:Packages:IgorThief" and switch to it
	NewDataFolder/O/S root:Packages
	NewDataFolder/O/S root:Packages:IgorThief
	
	NVAR gActionFlag
	if(NVAR_Exists(gActionFlag)==0)
		variable/g gActionFlag=kNoAction
		NVAR gActionFlag
	endif
	
	//Determine which button was clicked
	strswitch(ctrlName)
		//Next click on graph sets xmin
		case "xmin":
			gActionFlag=kXminAction
			Button digitize,title=ksStartDigitizing
			break
		//Next click on graph sets xmax
		case "xmax":
			gActionFlag=kXmaxAction
			Button digitize,title=ksStartDigitizing
			break
		//Next click on graph sets ymin
		case "ymin":
			gActionFlag=kYminAction
			Button digitize,title=ksStartDigitizing
			break
		//Next click on graph sets ymax
		case "ymax":
			gActionFlag=kYmaxAction
			Button digitize,title=ksStartDigitizing
			break
		//Start or stop digitizing
		case "digitize":
			//If currently digitizing, stop, and change digitize button
			if(gActionFlag==kDigitizeAction)
				gActionFlag=kNoAction
				Button digitize,title=ksStartDigitizing
			//If NOT currently digitizing, start, and change digitize button
			else
				gActionFlag=kDigitizeAction
				Button digitize,title=ksStopDigitizing
			endif
			break
		default:
			break
	endswitch
	
	//Switch back to saved data folder
	SetDataFolder oldDF
End

//Handles mouse clicks in window appropriately, depending on current action
Function ActionWindowHook(infoStr)
	String infoStr

	//Save location of current data folder
	String oldDF= GetDataFolder(1)
	//Create data folder "root:Packages:IgorThief" and switch to it
	NewDataFolder/O/S root:Packages
	NewDataFolder/O/S root:Packages:IgorThief
	
	variable statusCode=0
	variable/d Xval=0,Yval=0
	variable/d Xmin,Xmax,Ymin,Ymax

	String event= StringByKey("EVENT",infoStr)
	
	//Reference global variables
	NVAR /z gActionFlag
	if(NVAR_Exists(gActionFlag)==0)
		variable/g gActionFlag=kNoAction
		NVAR gActionFlag
	endif
	
	NVAR /z gXmin, gXmax,gYmin,gYmax
	if((NVAR_Exists(gXmin)==0)||(NVAR_Exists(gXmax)==0)||(NVAR_Exists(gYmin)==0)||(NVAR_Exists(gYmax)==0))
		Variable/g gXmin, gXmax,gYmin,gYmax
		NVAR gXmin, gXmax,gYmin,gYmax
	endif
	
	NVAR /z gLogx,gLogy
	if((NVAR_Exists(gLogx)==0)||(NVAR_Exists(gLogy)==0))
		Variable/g gLogx=kLinearAxis,gLogy=kLinearAxis
		NVAR gLogx,gLogy
	endif
	
	Wave /z gXminx,gXminy,gXmaxx,gXmaxy
	if((WaveExists(gXminx)==0)||(WaveExists(gXminy)==0)||(WaveExists(gXmaxx)==0)||(WaveExists(gXmaxy)==0))
		make/o/n=1 gXminx,gXminy,gXmaxx,gXmaxy
		gXminx=NAN
		gXminy=NAN
		gXmaxx=NAN
		gXmaxy=NAN
	endif
	
	Wave /z gYminx,gYminy,gYmaxx,gYmaxy
	if((WaveExists(gYminx)==0)||(WaveExists(gYminy)==0)||(WaveExists(gYmaxx)==0)||(WaveExists(gYmaxy)==0))
		make/o/n=1 gYminx,gYminy,gYmaxx,gYmaxy
		gYminx=NAN
		gYminy=NAN
		gYmaxx=NAN
		gYmaxy=NAN
	endif
	
	SVAR /z gXwave, gYwave
	if((SVAR_Exists(gXwave)==0)||(SVAR_Exists(gYwave)==0))
		string/g gXwave=""
		string/g gYwave=""
		SVAR gXwave, gYwave
	endif

	//Check if event is mouseup
	if(cmpstr(event,"mouseup")==0)
	
		//Get mouse location
		variable/d mousex = str2num(StringByKey("MOUSEX",infoStr))
		variable/d mousey = str2num(StringByKey("MOUSEY",infoStr))
		
		//If mouse location in control bar, ignore.
		if((mousex<0)||(mousey<0))
			SetDataFolder oldDF

			return statusCode
		endif
		
		//Convert pixels to x and y values.
		mousex=AxisValFromPixel("", "bottom", mousex )
		mousey=AxisValFromPixel("", "left", mousey )
		
		//Perform task, depending on action chosen
		switch(gActionFlag)
			//No action selected
			case kNoAction:
				gActionFlag=kNoAction
				break
			//Set xmin to mouse location, and set action to zero (no action selected)
			case kXminAction:
				gXminx=mousex
				gXminy=mousey
				gActionFlag=kNoAction
				break
			//Set xmax to mouse location, and set action to zero (no action selected)
			case kXmaxAction:
				gXmaxx=mousex
				gXmaxy=mousey
				gActionFlag=kNoAction
				break
			//Set ymin to mouse location, and set action to zero (no action selected)
			case kYminAction:
				gYminx=mousex
				gYminy=mousey
				gActionFlag=kNoAction
				break
			//Set ymax to mouse location, and set action to zero (no action selected)
			case kYmaxAction:
				gYmaxx=mousex
				gYmaxy=mousey
				gActionFlag=kNoAction
				break
			//Digitize point
			case 5:
				//If X axis is log, take log of min and max values
				if(gLogx==kLogAxis)
					Xmin=log(gXmin)
					Xmax=log(gXmax)
				//If X axis is NOT log, leave alone
				else
					Xmin=gXmin
					Xmax=gXmax
				endif
				//If Y axis is log, take log of min and max values
				if(gLogy==kLogAxis)
					Ymin=log(gYmin)
					Ymax=log(gYmax)
				//If Y axis is NOT log, leave alone
				else
					Ymin=gYmin
					Ymax=gYmax
				endif
				//Project mousex and mousey values onto x and y axes, and scale appropriately
				Xval = ((mousex-gXminx)*(gXmaxx-gXminx)+(mousey-gXminy)*(gXmaxy-gXminy))/((gXmaxx-gXminx)^2+(gXmaxy-gXminy)^2)*(Xmax-Xmin) + Xmin
				Yval = ((mousex-gYminx)*(gYmaxx-gYminx)+(mousey-gYminy)*(gYmaxy-gYminy))/((gYmaxx-gYminx)^2+(gYmaxy-gYminy)^2)*(Ymax-Ymin) + Ymin
				//If X axis is log, convert back
				if(gLogx==kLogAxis)
					Xval=10^Xval
				endif
				//If Y axis is log, convert back
				if(gLogy==kLogAxis)
					Yval=10^Yval
				endif
				
				//Reference x and y data waves, and append digitized point.
				wave xwave=$gXwave
				wave ywave=$gYwave
				variable xwavelen=DimSize(xwave,0)
				variable ywavelen=DimSize(ywave,0)
				redimension/n=(xwavelen+1) xwave
				redimension/n=(ywavelen+1) ywave
				xwave[xwavelen]=Xval
				ywave[ywavelen]=Yval
				break
			default:
				gActionFlag=kNoAction
				break
		endswitch
		
	endif
	
	//Switch back to saved data folder
	SetDataFolder oldDF

	return statusCode // 0 if nothing done, else 1
End

//Selects waves for x and y data, allowing the creation of a new wave.
Function WaveSelectPopup(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum	// which item is currently selected (1-based)
	String popStr		// contents of current popup item as string
	
	//Save location of current data folder
	String oldDF= GetDataFolder(1)
	//Create data folder "root:Packages:IgorThief" and switch to it
	NewDataFolder/O/S root:Packages
	NewDataFolder/O/S root:Packages:IgorThief
	
	//Reference global variables, creating them if necessary
	SVAR gXwave, gYwave
	if((SVAR_Exists(gXwave)==0)||(SVAR_Exists(gYwave)==0))
		string/g gXwave=""
		string/g gYwave=""
		SVAR gXwave,gYwave
	endif

	//Switch back to saved data folder
	SetDataFolder oldDF

	//If ksNewWave is selected from popup menu, create new wave and set
	//currentwave to the newly created wave
	//Otherwise, set currentwave to one selected in popup menu
	if(cmpstr(popStr,ksNewWave)==0)
		String newwavename
		Prompt newwavename, ksNewWaveDialog
		DoPrompt ksNewWaveDialog, newwavename
		make/d/n=0 $newwavename
		wave currentwave=$newwavename
		//Set popNum to item number corresponding to new wave
		popNum=WhichListItem(NameOfWave(currentwave),GetNewWaveList())+1
	else
		wave currentwave=$popStr
	endif

	//Set the global wave variable to selected wave, depending on which control
	//was selected.
	strswitch(ctrlName)
		case "xwave":
			gXwave=GetWavesDataFolder(currentwave, 2)
			break
		case "ywave":
			gYwave=GetWavesDataFolder(currentwave, 2)
			break
		default:
			break
	endswitch

	//Set item selected in popup menu to popNum, and update control
	PopupMenu $ctrlName, mode=popNum
	ControlUpdate $ctrlName
	
	return(popNum)
	
End

//Returns a string with the wave list of the current directory,
//along with ksNewWave at the top of the list.
Function/S GetNewWaveList()
	return(ksNewWave+";"+WaveList("*",";",""))
End

//Creates IgorThief window with appropriate controls.
Function IgorThief()
	PauseUpdate; Silent 1		// building window...
	Display /W=(5,44,606,589) as "IgorThief"
	ControlBar 100
	
	//Save location of current data folder
	String oldDF= GetDataFolder(1)
	//Create data folder "root:Packages:IgorThief" and switch to it
	NewDataFolder/O/S root:Packages
	NewDataFolder/O/S root:Packages:IgorThief
	
	//Reference global variables, creating them if necessary
	NVAR /z gXmin, gXmax,gYmin,gYmax
	if((NVAR_Exists(gXmin)==0)||(NVAR_Exists(gXmax)==0)||(NVAR_Exists(gYmin)==0)||(NVAR_Exists(gYmax)==0))
		Variable/g gXmin, gXmax,gYmin,gYmax
		NVAR gXmin, gXmax,gYmin,gYmax
	endif
	
	NVAR gLogx, gLogy
	if((NVAR_Exists(gLogx)==0)||(NVAR_Exists(gLogy)==0))
		Variable/g gLogx=kLinearAxis, gLogy=kLinearAxis
		NVAR gLogx, gLogy
	endif
	
	//Switch back to saved data folder
	SetDataFolder oldDF

	//Build the user interface
	Button load,pos={0,1},size={100,25},proc=LoadProc,title=ksLoadImage
	Button digitize,pos={0,50},size={100,25},proc=ActionProc,title=ksStartDigitizing
	
	Button xmin,pos={140,0},size={100,25},proc=ActionProc,title=ksSetXminPoint
	Button xmax,pos={260,0},size={100,25},proc=ActionProc,title=ksSetXmaxPoint
	
	SetVariable xminval,pos={140,30},size={100,25},title=ksXmin
	SetVariable xminval,limits={-Inf,Inf,0},value= root:Packages:IgorThief:gXmin
	SetVariable xmaxval,pos={260,30},size={100,25},title=ksXmax
	SetVariable xmaxval,limits={-Inf,Inf,0},value= root:Packages:IgorThief:gXmax
	
	CheckBox logxaxis, pos={380,0},size={50,25},title=ksLogXaxis,variable=root:Packages:IgorThief:gLogx
	
	PopupMenu xwave, mode=1, pos={450,0},title=ksXData, proc=WaveSelectPopup,value=#"GetNewWaveList()"

	Button ymin,pos={140,50},size={100,25},proc=ActionProc,title=ksSetYminPoint
	Button ymax,pos={260,50},size={100,25},proc=ActionProc,title=ksSetYmaxPoint
	
	SetVariable yminval,pos={140,80},size={100,25},title=ksYmin
	SetVariable yminval,limits={-Inf,Inf,0},value= root:Packages:IgorThief:gYmin
	SetVariable ymaxval,pos={260,80},size={100,25},title=ksYmax
	SetVariable ymaxval,limits={-Inf,Inf,0},value= root:Packages:IgorThief:gYmax

	CheckBox logyaxis, pos={380,50},size={50,25},title=ksLogYaxis,variable=root:Packages:IgorThief:gLogy
	
	PopupMenu ywave, mode=1, pos={450,50},title=ksYData, proc=WaveSelectPopup,value=#"GetNewWaveList()"
	
	//Install window hook for top window, asking for mouse up/down events
	SetWindow kwTopWin, hook=ActionWindowHook, hookevents=1 //hookevents=1 tells igor to report mouse up/down events

End