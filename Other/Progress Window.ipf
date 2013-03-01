#pragma rtGlobals=1		// Use modern global access method.

constant PROGWIN_BAR_HEIGHT=20
constant PROGWIN_BAR_WIDTH=250
constant PROGWIN_MAX_DEPTH=10
constant AUTO_CLOSE=1

Function ProgWinOpen([coords])
	wave coords
	
	dowindow ProgWin
	if(v_flag)
		dowindow /k/w=ProgWin ProgWin
	endif
	if(paramisdefault(coords))
		make /free/n=4 coords={100,100,200+PROGWIN_BAR_WIDTH,110+PROGWIN_BAR_HEIGHT}
	endif
	NewPanel /K=1 /N=ProgWin /W=(coords[0],coords[1],coords[2],coords[3]) /FLT=1 as "Progress"
	SetActiveSubwindow _endfloat_
	MoveWindow /W=ProgWin coords[0],coords[1],coords[2],coords[3]
	DoUpdate /W=ProgWin /E=1
	SetWindow ProgWin userData=""
	SetWindow ProgWin userData(abortName)=""
	if(AUTO_CLOSE)
		Execute /P/Q "dowindow /k/w=ProgWin ProgWin" // Automatic cleanup of progress window at the end of function execution.  
	endif
End

Function Prog(name,num,denom[,msg,parent])
	string name,msg,parent
	variable num,denom
	
	string progStr=num2str(num)+"/"+num2str(denom)
	if(paramisdefault(msg))
		msg=progStr
	else
		msg="["+progStr+"] "+msg
	endif
	//selectstring(!paramisdefault(msg),progStr,"["+progStr+"] "+msg)
	execute /q "setigoroption pounddefine=noprog?"
	nvar noprog=v_flag
	if(noprog)
		return 1
	endif
	execute /q "setigoroption pounddefine=textprog?"
	nvar textprog=v_flag
	if(!textprog)
		if(!wintype("ProgWin"))
			ProgWinOpen()
		endif
		string data=GetUserData("ProgWin","","")
		string title=name
		name=cleanupname(name,0)
		variable currDepth=itemsinlist(data)
		variable depth=whichlistitem(name,data)
		if(denom==0 && depth>0)
			SetWindow ProgWin userData=removelistitem(depth,data)
			KillControl /W=ProgWin $("Abort_"+name)
			KillControl /W=ProgWin $("Prog_"+name)
			KillControl /W=ProgWin $("Status_"+name)
			return 0
		endif
		depth=(depth<0) ? currDepth : depth
		ControlInfo /W=ProgWin $("Prog_"+name)
		if(!v_flag) // No button yet.  
			variable yy=10+(10+PROGWIN_BAR_HEIGHT)*depth
			variable buttonWidth=FontSizeStringWidth("Default",12,0,title)
			Button $("Abort_"+name), pos={4,yy}, size={buttonWidth,20}, title=title, proc=ProgWinButtons, win=ProgWin
			ValDisplay $("Prog_"+name),pos={buttonWidth+7,yy},size={PROGWIN_BAR_WIDTH,PROGWIN_BAR_HEIGHT},limits={0,1,0},barmisc={0,0}, mode=3, win=ProgWin
			TitleBox $("Status_"+name), pos={buttonWidth+PROGWIN_BAR_WIDTH+9,yy},size={60,PROGWIN_BAR_HEIGHT}, win=ProgWin
		endif
		variable frac=num/denom
		ValDisplay $("Prog_"+name),value=_NUM:frac, win=ProgWin, userData(num)=num2str(num), userData(denom)=num2str(denom)
		TitleBox $("Status_"+name), title=msg, win=ProgWin
		if(!paramisdefault(parent))
			parent=cleanupname(parent,0)
			ControlInfo /W=ProgWin $("Prog_"+parent)
			if(v_flag>0)
				variable parentNum=str2num(getuserdata("ProgWin","Prog_"+parent,"num"))
				variable parentDenom=str2num(getuserdata("ProgWin","Prog_"+parent,"denom"))
				variable parentFrac=(parentNum+frac)/parentDenom
				ValDisplay $("Prog_"+parent),value=_NUM:parentFrac, win=ProgWin
			endif
		endif
		
		if(depth==currDepth)
			struct rect coords
			GetWinCoords("ProgWin",coords,forcePixels=1)
			variable msgWidth=FontSizeStringWidth("Default",9,0,msg)
			variable right=max(coords.right,coords.left+buttonWidth+PROGWIN_BAR_WIDTH+msgWidth)
			MoveWindow /W=ProgWin coords.left,coords.top,right,coords.bottom+(10+PROGWIN_BAR_HEIGHT)*72/ScreenResolution
			SetWindow ProgWin userData=addlistitem(name,data,";",inf)
		endif
		DoUpdate /W=ProgWin /E=1
		string abortName=GetUserData("ProgWin","","abortName")
		if(stringmatch(name,abortName))
			SetWindow ProgWin userData(abortName)=""
			debuggeroptions
			if(v_enable)
				debugger
			else
				return -1
			endif
		endif
	else
		svar /z status=root:textProgStatus
		if(!svar_exists(status))
			string /g root:textProgStatus
			svar /z status=root:textProgStatus
		endif
		status=ReplaceStringByKey(name,status,num2str(num)+"/"+num2str(denom),":",";",0)
		printf "%s\r",replacestring(";",replacestring(":",status,": "),"\t")
	endif
	return 0
End

function ProgReset()
	svar /z status=root:textProgStatus
	if(svar_exists(status))
		status=""
	endif
end

Function ProgWinButtons(ctrlName)
	String ctrlName
	
	Variable button_num
	String action=StringFromList(0,ctrlName,"_")
	string name=ctrlName[strlen(action)+1,strlen(ctrlName)-1]	
	strswitch(action)
		case "Abort":
			SetWindow ProgWin userData(abortName)=name
	endswitch
End

static Function GetWinCoords(win,coords[,forcePixels])
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
		printf "No such window: %s.\r"+win
	endif
End

function TextProg(on)
	variable on

	Core#DefUndef(selectstring(on,"undef","def"),"textprog")
end

function NoProg(on)
	variable on

	Core#DefUndef(selectstring(on,"undef","def"),"noprog")
end


