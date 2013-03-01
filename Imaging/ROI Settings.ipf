#pragma rtGlobals=1		// Use modern global access method.

//////////////////////////////////////
// Makes Globals for setting ROI
//////////////////////////////////////
Function MakeROIGlobals()
	dfref currDF= GetDataFolderDFR()
	dfref df = CameraHome()
	newdatafolder /o/s df:ROI
	variable/G left,right,top,bottom,V_Marquee,MouseDown,radioVal,active
	string/G refImage,message 
	SetDataFolder currDF
End

//////////////////////////////////////
// Updates ROI values based on user-input from a marquee
//////////////////////////////////////
Function UpdateMarqueeValues()
	MakeROIGlobals()
	
	GetMarquee left,bottom
	dfref df = CameraHome()
	dfref roiDF = df:ROI
	nvar /sdfr=roiDF left,right,top,bottom,active
	active = 1
	left = floor(v_left); right = ceil(v_right)
	top = ceil(v_top); bottom = floor(v_bottom)
	svar /sdfr=roiDF refImage,message
	svar /sdfr=df MovieOnDisplay
	refImage = MovieOnDisplay // So we can append this to a wave note to tell where the focus image came from 
	sprintf message,"coords: (%d,%d) , (%d,%d)",left,bottom,right,top				
	print message
End

//////////////////////////////////////
// Draws a box showing the active ROI
//////////////////////////////////////
Function DrawUsingMarq_coords()

	HideROIDisplay()
	dfref df = CameraHome()
	dfref roiDF = df:ROI
	nvar /sdfr=roiDF left,right,top,bottom,active
	if(!active)
		return -1
	endif
	
	DoWindow/F FrameViewer_subWin
	SetDrawLayer ProgFront
	SetDrawEnv xcoord= bottom,ycoord= left
	SetDrawEnv linefgc = (65280,65535,65535), fillpat=0,linethick=1.50
	DrawRect left,top,right,bottom
	SetDrawEnv xcoord= bottom,ycoord= left,textrgb=(65280,65535,65535),fsize= 18
	DrawText left,top+1, "ROI" 
End

//////////////////////////////////////
// Kills the ROI window w/o asking to Save/Replace
//////////////////////////////////////
Function KillWin_LockROI(infostr)
	String infoStr
	String Event = ""
	Event = StringByKey("EVENT",infostr)
	if(stringmatch(Event,"Killvote")) 	
		KillROI()
		DoWindow/K ROITab
	EndIf
End

//////////////////////////////////////
// Hides the shown ROI display (if any available)
//////////////////////////////////////
Function HideROIDisplay()
	SetDrawLayer/K/W=FrameViewer_subWin progFront
End

//////////////////////////////////////
// Kills the active ROI
//////////////////////////////////////
Function KillROI()
	HideROIDisplay()
	dfref df = CameraHome()
	dfref roiDF = df:ROI
	nvar /sdfr=roiDF active
	active = 0
	svar /sdfr=roiDF message
	message = "no active ROI"
End

//////////////////////////////////////
// Hook to indicate user-driven events w/ marquee
//////////////////////////////////////
Function myROIHook(H_Struct)
	STRUCT WMWinHookStruct &H_Struct
	
	dfref df = CameraHome()
	dfref roiDF = df:ROI
	nvar /sdfr=roiDF mouseDown
	if((mouseDown==1) && (StringMatch("Mousemoved",H_Struct.eventName))) // Cursor moved with button down.  
		UpdateMarqueeValues()
		DrawUsingMarq_coords()	
		mouseDown=0
	endif
	if(Stringmatch("Mousedown",H_Struct.eventName)) // Mouse button down without movement of the cursor.  
		mouseDown=1
	endif
End

//////////////////////////////////////
// Sets ROI update mode (locked or able to be updated)
//////////////////////////////////////
Function ROICheckboxes(cb) : CheckBoxControl
	struct WMCheckboxAction &cb
		
	dfref df = CameraHome()
	dfref roiDF = df:ROI
	nvar /sdfr=roiDF radioVal
	strswitch(cb.ctrlName)
		case "EnterROIs":
			radioVal=1
			SetWindow FrameViewer_subwin,hook(ROI_hk)=myROIHook				
			break
		case "LockROI":
			radioVal=2
			SetWindow FrameViewer_subwin,hook(ROI_hk)=$""
			break
	endswitch
	CheckBox EnterROIs,Win=ROITab,value=radioVal==1
	CheckBox LockROI,Win=ROITab,value=radioVal==2
End

function ROIButtons(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			strswitch(ba.ctrlName)
				case "KillROI":
					KillROI()
					break
				case "HideROI":
					HideROIDisplay()
					break
				case "ShowROI":
					DrawUsingMarq_coords()
					break
				case "ROIQuickTab":
					string ROI_wins = WinList("ROITab*",";","WIN:64")
					if(strlen(ROI_wins))
						KillWindows("ROITab*")
					else	
						ROITab()
					endIf
					break	
			endswitch
			break
	endswitch
end

//////////////////////////////////////
// 
//////////////////////////////////////
Function ForceLockROI()
	struct WMCheckboxAction cb
	cb.ctrlName = "LockROI"
	cb.checked = 1
	ROICheckboxes(cb)
End

//////////////////////////////////////
// Builds the ROI Panel
//////////////////////////////////////
Function ROITab()
	dfref df = CameraHome()
	MakeROIGlobals()
	dfref roiDF = df:ROI
	NewPanel /W=(505,136,697,265) as "ROI"
	ModifyPanel cbRGB=(32768,40704,65280)
	SetDrawLayer UserBack
	SetDrawEnv linefgc= (34816,34816,34816),fillpat= 4,fillfgc= (39168,39168,39168),fillbgc= (39168,39168,39168)
	DrawRect 75,10,156,48
	SetDrawEnv linefgc= (34816,34816,34816),fillpat= 0
	DrawRect 18,95,179,118
	DrawText 19,91,"status:"
	CheckBox EnterROIs,pos={79,11},size={75,14},proc=ROICheckboxes,title="Update ROI"
	CheckBox EnterROIs,value= 0,mode=1
	CheckBox LockROI,pos={80,32},size={64,14},proc=ROICheckboxes,title="Lock ROI"
	CheckBox LockROI,value= 1,mode=1
	Button KillROI,pos={17,50},size={45,19},proc=ROIButtons,title="Kill"
	Button ShowROI,pos={17,10},size={45,19},proc=ROIButtons,title="Show"
	Button HideROI,pos={17,30},size={45,19},proc=ROIButtons,title="Hide"
	TitleBox title0,pos={29,99},size={119,13},frame=0
	TitleBox title0,variable=roiDF:message
	ForceLockROI()
	SetWindow ROITab hook = KillWin_LockROI
End
