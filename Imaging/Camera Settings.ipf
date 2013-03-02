#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName = Imaging

Function MakeCameraPanel()
	dfref df = CameraHome()
	nvar /sdfr=df X_pixels
	if(!nvar_exists(X_pixels))
		MakeCameraGlobals()
	endif
	DoWindow/K CameraPanel
	NewPanel /N=CameraPanel/W=(48,107,241,243) as "Camera"
	Button InitCamera,pos={2,2},size={87,24},disable=0,proc=CameraPanelButtons,title="Intialize Camera"
	Button CloseCamera,pos+={0,0},size={87,24},disable=0,proc=CameraPanelButtons,title="Close Camera"
	SetVariable BinX,pos={2,32},size={59,16},disable=0,title="Bin X",limits={0,256,1},value=df:X_pixels,bodyWidth= 30
	SetVariable Exposure,pos+={0,0},size={110,16},disable=0,title="Exposure (ms)",format="%d",limits={10,inf,10},value=df:exposure_time
	SetVariable BinY,pos={2,57},size={59,16},disable=0,title="Bin Y",limits={0,256,1},value=df:Y_pixels,bodyWidth= 30
	SetVariable Frames,pos+={0,0},size={89,16},disable=0,title="# Frames",limits={1,inf,1},value=df:num_frames
	Checkbox Save_,pos={2,82},title="Save",variable=df:save_
	CheckBox Trigger,pos+={0,0},size={108,14},title="Triggered",variable=df:trigger
	Button Start,pos={2,107},size={87,24},disable=0,proc=CameraPanelButtons,title="Start"
	Button Focus,pos+={0,0},size={87,24},disable=0,proc=CameraPanelButtons,title="Focus",help={"CTRL To Auto Focus, CTRL-SHIFT For 1 SD"}
End

function /df CameraHome([instance,create])
	string instance
	variable create
	
	instance = selectstring(!paramisdefault(instance),"default",instance)
	create = paramisdefault(create) ? 1 : create
	dfref df = Core#InstanceHome("Acq","camera","default",create=create)
	return df
end

function /df ImageHome([set,instance])
	string set,instance
	
	dfref camera_df = CameraHome()
	if(!paramisdefault(set))
		string /g camera_df:working_folder = set
	endif
	svar /z/sdfr=camera_df working_folder
	if(!svar_exists(working_folder))
		newdatafolder /o root:Camera	
		dfref df = root:Camera
	else
		newdatafolder /o $working_folder
		df = $working_folder
	endif
	if(!paramisdefault(instance))
		df = df:$instance
	endif
	return df
end

static function IsTriggered()
	dfref df=CameraHome()
	nvar /z/sdfr=df trigger
	return nvar_exists(trigger) && trigger
end

//////////////////////////////////////
// Makes globals so that:
// 1) camera handle can be accessed by other functions and
// 2) there is control of basic aspects of image aquisition (binning, exposure, frames, etc.)
//////////////////////////////////////
Function MakeCameraGlobals()
	dfref currDF = getdatafolderdfr()
	dfref df = CameraHome()
	setdatafolder df
	variable/g xop_handle,camera_handle,totalROIs
	variable /g X_pixels=2,Y_pixels=2
	variable /g exposure_time=50 // ms.  
	variable /g num_frames=10
	variable /g trigger=0
	variable /g save_=1
	make /o/W/U/n=(512,512,1) current_movie=0
	SetDataFolder currDF
End

//////////////////////////////////////
// Sets up a handle for the camera and stores it in a global. Also creates flags
// to indicate whether handles exist, are corrupted, etc..
//////////////////////////////////////

Function InitializeCamera()
	MakeCameraGlobals()
	dfref df = CameraHome()
	nvar /sdfr=df camera_handle,xop_handle
	variable cancelled
	string message
	
	if(xop_handle>0)
		DoAlert 0, "The camera is already initialized"
		return 0
	endif
	
	variable xop_handle_
	variable status = Camera#Open_(xop_handle_)
	xop_handle = xop_handle_ // Needed because globals cannot be passed by reference.  	
	If(status!=0)
		Camera#GetStatusText(xop_handle,message)
		printf "%s:%s\r","Camera#Open",message
		return -1
	EndIf		
	
	variable camera_handle_
	status = Camera#DialogSelector(xop_handle,camera_handle_,cancelled)
	camera_handle = camera_handle_ // Needed because globals cannot be passed by reference.  	
	If(status!=0)
		Camera#GetStatusText(xop_handle,message)
		Camera#Deallocate()
		printf "%s: %s\r", "Camera#DialogSelector", message
		return -2
	Endif
	
	if(cancelled!=0)
		Camera#Deallocate()
		printf "Camera dialog canceled.\r"
		return -3
	EndIf

	status = Camera#Dialog(camera_handle,cancelled)
	If(status!=0)
		Camera#GetStatusText(camera_handle,message)
		Camera#Deallocate()
		printf "%s: %s\r", "Camera#Dialog", message
		return -4
	EndIf
End

//////////////////////////////////////
// Updates camera settings(Binning, exposure). More advanced settings (shutter mode,
// etc.) are camera specific and should be taken care of by other fxns.
//////////////////////////////////////
Function CameraParameters()
	dfref df = CameraHome()

	nvar /sdfr=df xop_handle,camera_handle,X_pixels,Y_pixels,exposure_time
	
	variable exposure_get,status
	
	If(camera_handle<=0 || !datafolderrefstatus(df))
		DoAlert 0, "Camera needs to be initialized before calling CameraParameters()"
		return -1
	EndIf
	
	Camera#ExposureTimeSet(camera_handle,exposure_time)
	Camera#BinningSet(camera_handle,X_pixels,Y_pixels)		
End

Function FastFocus([stop])
	variable stop
	
	if(stop)
		TerminateAcquisition()
	else
		dfref df = CameraHome()
		nvar /sdfr=df camera_handle,xop_handle
		
		if(!DataFolderRefStatus(df) || camera_handle<=0)
			DoAlert 0, "Camera needs to be initialized first"
			return -1
		endIf
		
		variable status
		CameraParameters()
		Camera#TriggerSet(camera_handle,0)	
		Camera#AcquisitionBeginFocus(camera_handle) // Prepare the camera for focus mode
		Camera#AcquisitionStart(camera_handle) // Start the actual acquisition. 
		Movie#Show("Camera")
		CtrlNamedBackground FastFocus proc=FastFocusBkg, period=1, burst=1, start
	endif
End

function FastFocusBkg(s)
	struct WMBackgroundStruct &s
	
	dfref df = CameraHome()
	wave /sdfr=df current_movie
	nvar /sdfr=df camera_handle,xop_handle
	variable available_frames,status,utc_time,roi_index=0
	
	variable pressed = GetKeyState(0)	// detect user presses inside the main Do-loop
	string win = "MovieWin#MoviePanel"
	switch(pressed)
		case 32:	// Did the user hit escape?
			TerminateAcquisition()
			return 1
			break
		case 1: // Control.  
			PopupMenu /Z ContrastPresets mode=2, win=$win
			break
		case 4: // Shift
			PopupMenu /Z ContrastPresets mode=3, win=$win
			break
		case 5: // Control+Shift
			PopupMenu /Z ContrastPresets mode=4, win=$win
			break
	endswitch
	if(pressed && pressed<32)
		Movie#UpdatePanel()
	endif
	Camera#AcquisitionFramesAvailable(camera_handle, available_frames) 
	if(available_frames > 0)	// Is a frame ready?
		Camera#AcquisitionGetFrames(camera_handle, available_frames, roi_index, current_movie, utc_time) // ...Write input to a single IGOR wave	
		Movie#UpdateFrame()
		//Duplicate/O $wave_image df:currentFrame /wave=currentFrame	// TO DO: See above, write image directly to df instead of to current directory and then duplicating.  				
	endif		
	return 0
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Similar motivation to "deallocate camera" Just used to make the command folder+global
// saavy.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function TerminateAcquisition() // TO DO: Is this in all ways superior to DeallocateCamera()?  
	dfref df = CameraHome()
	nvar /sdfr=df camera_handle
	
	variable status,bytes,x_pixels,y_pixels,temperature,locked,hardware_provided,roi_index=0
	
	printf "Terminating Image Acquisition.\r"
	CtrlNamedBackground FastFocus stop
	if(!datafolderrefstatus(df) || camera_handle==0)
		return -1
	endif
	Camera#AcquisitionStop(camera_handle)	
	Camera#AcquisitionGetSize(camera_handle, 0, bytes, x_pixels, y_pixels)
	printf "ROI: %d, Bytes: %d, X pixels: %d, Y pixels: %d\r", roi_index, bytes, x_pixels, y_pixels
	Camera#TemperatureGet(camera_handle, temperature, locked, hardware_provided)
	printf "CCD temperature measured: %d, Temperature locked (1 means true): %d, Temperature locked info provided by hardware (1 means true): %d\r", temperature, locked, hardware_provided
	Camera#AcquisitionEnd(camera_handle)
End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Acquires a single sweep, user specifies total frames and image name.
// This is imaging specific.... not to be confused w/ AcquireOneSweep which collects 
// both phys and imaging... Also need some escape code in appropriate places?? (So camera doesn't 
// end up locked..)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function AcquireMovie([now])
	variable now
	
	dfref df = CameraHome()
	nvar /z/sdfr=df camera_handle,xop_handle,num_frames,X_pixels,Y_pixels,exposure_time,totalROIs
	if(!nvar_exists(camera_handle) || camera_handle<=0)
		if(numtype(InitializeCamera()))
			return -2
		endif
	endif
	CameraParameters()	// update camera parameters (frames,bin,etc..)
	string message
	variable roi_index,utc_time
	
	variable trig = now ? 1 : 3 // A trigger variable used by the XOP.  
	Camera#TriggerSet(camera_handle,trig)	// no trigger necessary for collecting one sweep.  3 for trigger.
	variable status = Camera#AcquisitionBeginSequence(camera_handle,num_frames) // prep the camera for acquisition
	if(status!=0)
		Camera#GetStatusText(camera_handle,message)
		Camera#Deallocate()
		printf "%s:%s\r","Camera#AcquisitionBeginSequence",message
		return -1
	endif

	status = Camera#AcquisitionStart(camera_handle) // let er' rip.
	dfref cameraDF = ImageHome()
	dfref currDF = getdatafolderdfr()
	setdatafolder cameraDF
	string image_name = UniqueName("image",1,0)
	setdatafolder currDF
	wave /sdfr=df current_movie
	WriteAvailableImages(current_movie)	// try this instead of the below for ROIs
	duplicate /o current_movie cameraDF:$image_name
	wave /t/z cameraHistory = cameraDF:history
	if(!waveexists(cameraHistory))
		make /o/n=0/t cameraDF:history /wave=cameraHistory
	endif
	cameraHistory[dimsize(cameraHistory,0)] = {"Name:"+image_name+";Frames:"+ num2str(num_frames) + ";BinX:"+num2str(X_pixels)+";BinY:"+num2str(Y_pixels)+";exposure time:"+num2str(exposure_time)+";Collected at:"+time()}
	TerminateAcquisition()
End

/////////////// Clears all available ROIS
Function ClearROIs()
	dfref df = CameraHome()
	nvar /sdfr=df camera_handle
	if(!datafolderrefstatus(df) || !camera_handle<=0)
		return -1
	endif
	string message
	variable status = Camera#ROIClear(camera_handle)
	if(status!=0)
		Camera#GetStatusText(camera_handle,message)
		printf "%s:%s","Camera#ROIClear\r",message
		return -2
	endif
End

/////// If frames are in the buffer, then write them to to an IGOR wave ////
Function WriteAvailableImages(w)
	wave w
	
	dfref df = CameraHome()
	nvar /sdfr=df camera_handle,totalROIs,num_frames

	variable done_count,roi_index,utc_time
	string message
	do
		variable status = Camera#AcquisitionFramesAvailable(camera_handle,done_count)	// wait until the frames are ready to be read into a wave..	
		if(status!=0)
			TerminateAcquisition()
			return -1
		endIf
	while(!done_count)
	Camera#AcquisitionStop(camera_handle)	// kill the acquisition	
	Camera#AcquisitionGetFrames(camera_handle,num_frames,roi_index,w,utc_time)	//.. and write to an IGOR wave
	
	if(status!=0)
		Camera#GetStatusText(camera_handle,message)
		TerminateAcquisition()
		printf "%s:%s","Camera#AcquisitionGetFrames\r",message
		return -2
	endif	
End

////////////////////////// WINDOWS AND BUTTONS: /////////////////////////////////////////

function CameraPanelButtons(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			strswitch(ba.ctrlName)
				case "CloseCamera":
					Camera#Deallocate()
					break
				case "InitCamera":
					InitializeCamera()
					break
				case "Start":
					AcquireMovie(now=!IsTriggered())
					break
				case "Focus":
					CtrlNamedBackground FastFocus status
					variable focusing = numberbykey("RUN",s_info)
					if(focusing)
						Button Focus fcolor=(0,0,0)
						FastFocus(stop=1) // Stop
					else
						Button Focus fcolor=(65535,0,0)
						FastFocus(stop=0) // Start
					endif
					break
			endswitch
			break
	endswitch
end

