// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Sutter.ipf $
// $Author: rick $
// $Rev: 565 $
// $Date: 2011-07-05 21:30:25 -0400 (Tue, 05 Jul 2011) $

#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName=Sutter

strconstant sutter_loc="root:Packages:Sutter:"

static Function IsDebuggerOn()
	DebuggerOptions
	return V_enable
End

static Function Init([port])
	String port
#if exists("VDT2")==4
	if(ParamIsDefault(port))
		port="COM3"
	endif
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:Packages
	NewDataFolder /O/S Sutter
	Variable /G x1,y1,z1,xRem,yRem,zRem,update_coords=1
	String /G dummy
	Make /o/n=0 xWave,yWave,zWave
	
	VDTGetPortList2
	if(WhichListItem(port,S_VDT)<0)
		String msg="Port %s is not in the list of available ports.\r"
		msg+="Quit Igor and turn on the Sutter controller and see if %s appears in the list of available ports when you restart Igor.\r"
		printf msg,port,port
		update_coords=0
		SetDataFolder $curr_folder
		return -1
	endif
	VDTOperationsPort2 $port
	
	// Safely attempt to initialize the connection with the controller.  
	variable debugOn=IsDebuggerOn()
	DebuggerOptions enable=0
	VDT2 baud=128000, buffer=4096, databits=8, echo=0, in=0, killio, out=0, parity=0, stopbits=1
	variable err=GetRTError(1)
	if(err==-31999)
		printf "Windows is denying access to the COM port.  Turning off Sutter coordinate updating.\r"
		update_coords=0
	elseif(err)
		printf "Error: %s\r",GetErrMessage(err)
		update_coords=0
	else
		VDT2 killio // Empty the input/output buffer to start from scratch.  
	endif
	
	SetDataFolder $curr_folder
#else
	printf "The VDT2 XOP is not loaded.\r"
#endif
End

Function Update()
	String folder="root:Packages:Sutter:"
	NVar /Z x1=$(folder+"x1"),y1=$(folder+"y1"),z1=$(folder+"z1")
	SVar /Z dummy=$(folder+"dummy")
#if exists("VDT2")
	DebuggerOptions debugOnError=0
	NVar /Z update_coords=$(folder+"update_coords")
	if(NVar_Exists(x1) && update_coords)
		VDTWrite2 /O=1 "C"
		if(GetRTError(1)==-31999)
			printf "Windows is denying access to the COM port.  Turning off Sutter coordinate updating.\r"
			update_coords=0
		else	
			VDTReadBinary2  /B /O=1 /Q /T="\r"  /TYPE=(0x20) /Y={0,1/16} x1,y1,z1
			VDTRead2 /O=1 dummy
		endif
	endif
	DebuggerOptions debugOnError=1
#endif
End

Function Move(dx1,dy1,dz1[,absolute,maxMove,noUpdate])
	Variable dx1,dy1,dz1
	Variable absolute // Absolute position instead of relative to current position.  
	Variable maxMove // Maximum size of a move in any direction (in microns).  
	Variable noUpdate // Do not update the current position before making the delta move.  
	String folder="root:Packages:Sutter:"
	NVar /Z x1=$(folder+"x1"),y1=$(folder+"y1"),z1=$(folder+"z1")
	NVar /Z xRem=$(folder+"xRem"),yRem=$(folder+"yRem"),zRem=$(folder+"zRem")
	SVar /Z dummy=$(folder+"dummy")
	maxMove=ParamIsDefault(maxMove) ? Inf : maxMove
#if exists("VDT2")
	if(NVar_Exists(x1))
		if(absolute)
			Variable x2=dx1*16, y2=dy1*16, z2=dz1*16
		else
			if(!noUpdate)
				Update()
			endif
			Variable maxRequest=max(max(abs(dx1),abs(dy1)),abs(dz1))
			if(maxRequest>maxMove)
				dx1*=(maxMove/maxRequest)
				dy1*=(maxMove/maxRequest)
				dz1*=(maxMove/maxRequest)
			endif
			x2=(x1+dx1)*16; y2=(y1+dy1)*16; z2=(z1+dz1)*16
		endif
		
		// Handle fractional units of movement (not fractional microns, but fractional motor steps).  
		xRem+=mod(x2,1) // Add any fractional component of the target position to a remainder tracker.  
		yRem+=mod(y2,1)
		zRem+=mod(z2,1)
		x2+=floor(xRem) // If the remainder tracker is greater than 1, add its integer value to the target.  
		y2+=floor(yRem)
		z2+=floor(zRem)
		xRem-=floor(xRem) // Subtract off that integer value from the remainder tracker.  
		yRem-=floor(yRem)
		zRem-=floor(zRem)
		
		VDTWrite2 /O=1 "M"
		if(GetRTError(1)==-31999) // Failed!  
			printf "VDT Write Failed.\r"
			VDT2 killio // Empty the input/output buffer to start from scratch.  
		else	
			VDTWriteBinary2  /B /O=1 /Q /TYPE=(0x20) x2,y2,z2
			VDTRead2 /O=1 dummy
		endif
	endif
#endif
End

Function LiveUpdate(s)
	STRUCT WMBackgroundStruct &s
	Update()
#if exists("UpdateLogPanelCoords")
	Variable i
	for(i=0;i<ItemsInList(sutterLocations);i+=1)
		String location=StringFromList(i,sutterLocations)
		ControlInfo /W=LogPanel $("Live_"+location)
		if(V_Value)
			UpdateLogPanelCoords(location)
		endif
	endfor
#endif
	return 0
End

Function ToggleLive()
	Variable i
	Variable live=0
#if exists("UpdateLogPanelCoords")
	for(i=0;i<ItemsInList(sutterLocations);i+=1)
		String location=StringFromList(i,sutterLocations)
		ControlInfo /W=LogPanel $("Live_"+location); live+=V_Value
	endfor
#endif
	if(live)
		CtrlNamedBackground Sutter, period=30, proc=Sutter#LiveUpdate, start
	else
		CtrlNamedBackground Sutter, stop
	endif
End

Function SlowMove(dx,dy,dz,speed)
	Variable dx,dy,dz,speed
	String folder="root:Packages:Sutter:"
	String currFolder=GetDataFolder(1)
	if(!DataFolderExists(folder))
		printf "Must initialize Sutter first with InitSutter()\r"
		return -1
	endif
	SetDataFolder $folder
	Update()
	NVar /Z x1,y1,z1
	
	Variable /G targetX=x1+dx,targetY=y1+dy,targetZ=z1+dz
	Variable backgroundRate=2
	Variable distance=sqrt(dx^2+dy^2+dz^2)
	Variable duration=distance/speed
	Variable /G maxMove=max(max(abs(dx),abs(dy)),abs(dz))/(duration*backgroundRate)
	//Variable /G numMovesLeft=duration*10
	CtrlNamedBackground SutterTimedMove proc=SutterLiveMove, period=(60/backgroundRate), start // Run 'backgroundRate' times per second.  
	SetDataFolder $currFolder
End

Function LiveMove(s)
	STRUCT WMBackgroundStruct &s
	String folder="root:Packages:Sutter:"
	NVar targetX=$(folder+"targetX"), targetY=$(folder+"targetY"), targetZ=$(folder+"targetZ")
	if(!NVar_Exists(targetX))
		return -1
	else 
		NVar maxMove=$(folder+"maxMove")
		Update()
		NVar x1=$(folder+"x1"),y1=$(folder+"y1"),z1=$(folder+"z1")
		Variable tolerance=0.5
		Variable dx,dy,dz,dDiag
		dx=targetX-x1; dy=targetY-y1; dz=targetZ-z1
		dDiag=(dy^2 + dZ^2)^(1/2)
		SetVariable /Z dX,value= _NUM:dx, win=LogPanel 
		SetVariable /Z dY,value= _NUM:dy,win=LogPanel 
		SetVariable /Z dZ,value= _NUM:dz, win=LogPanel
		SetVariable /Z dDiag,value=_NUM:dDiag, win=LogPanel
		if(abs(dx)<tolerance && abs(dY)<tolerance && abs(dZ)<tolerance ) // Termination condition.  
			 Stop()
			return 1
		endif
		
		String moveStr
		sprintf moveStr,"Current Move: %f,%f,%f",dx,dy,dz
		Move(dx,dy,dz,noUpdate=1,maxMove=maxMove)
		return 0
	endif
End

Function Stop()
	CtrlNamedBackground SutterTimedMove stop
	Button /z Sutter_Move, title="Go", userData="Go", win=LogPanel
	ControlInfo /W=LogPanel Sutter_Speed
	if(v_flag)
		Variable newSpeed=min(V_Value,5) // Reduce the speed so that is not too fast on the next move.  
		SetVariable /z Sutter_Speed, value=_NUM:newSpeed, win=LogPanel
	endif
End

Function View()
	DoWindow /K SutterCoords
	NewPanel /K=1 /N=SutterCoords
	SetVariable x1,pos={1,2},size={75,16},value= root:Packages:Sutter:x1
	SetVariable y1,pos={1,26},size={75,16},value= root:Packages:Sutter:y1
	SetVariable z1,pos={1,50},size={75,16},value= root:Packages:Sutter:z1
End