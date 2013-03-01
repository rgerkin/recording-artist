#pragma rtGlobals=2		// Use modern global access method.
#pragma IgorVersion=6.0	// Independent modules require Igor 6
#pragma version=6.0
#pragma IndependentModule= WM_GrfBrowser

// GraphBrowser.ipf
// Version 6.0, LH051121

Menu "Misc", hideable
	"Graph Browser", /Q, NewGraphBrowser()
end

Structure grfBrowserGlobals
	SVAR curSelGName
	SVAR gCurWinNote
	SVAR sStartWith
	SVAR sContainsWave
	WAVE/T wGrafList
	WAVE wGrafSelList
	WAVE/T wWaveNameList
	
	NVAR prevHidden
EndStructure

Function GetGrfBrowserGlobals(g,pname)		// has side effect of creating globals if they do not yet exist
	STRUCT grfBrowserGlobals &g
	String pname		// panel name
	
	String dfsav= GetDataFolder(1)
	NewDataFolder/O/S root:Packages
	NewDataFolder/O/S root:Packages:WMGrfBrowser
	
	if( CmpStr(pname,"GraphBrowserPanel") != 0 )		// working on an additional panel beyond the base?
		NewDataFolder/O/S $pname
	endif
		
	
	SVAR/Z g.sContainsWave
	if( !SVAR_Exists(g.sContainsWave) )
		String/G sContainsWave
		String/G sStartWith
		String/G curSelGName,gCurWinNote
		Make/T/N=0 wGrafList
		Make/N=0 wGrafSelList
		Make/T/N=(0,2) wWaveNameList
		SetDimLabel 1,0,'wave name',wWaveNameList
		SetDimLabel 1,1,'data folder',wWaveNameList
		Variable/G prevHidden
	endif

	SVAR g.sContainsWave
	SVAR g.sStartWith
	SVAR g.curSelGName
	SVAR g.gCurWinNote
	WAVE/T g.wGrafList
	WAVE/T g.wWaveNameList
	NVAR g.prevHidden
	WAVE g.wGrafSelList
		
	
	SetDataFolder dfsav
End

Function GetWindowWaveList(name,wNames)
	String name			// window name
	WAVE/T wNames	// list of wave names goes here. Column 0 is wave name, column 1 is data folder
	
	Redimension/N=(1,2) wNames	// needed to avoid loosing col label if input rows=0
	Variable next= AppendWindowWaveList(name,wNames,0)
	Redimension/N=(next,2) wNames
	
	return next
end


Function AppendWindowWaveList(name,wNames,next)
	String name			// window name
	WAVE/T wNames	// list of wave names goes here. Column 0 is wave name, column 1 is data folder
	Variable next		// index of next slot in wNames
	
	Variable i
	for(i=0;;i+=1)
		WAVE/Z w= WaveRefIndexed(name,i,3)
		if( !WaveExists(w) )
			break
		endif
		String df= GetWavesDataFolder(w,1)
		if( strlen(df) != 0 )						// don't include contour waves
			wNames[next]= {{NameOfWave(w)},{df}}
			next += 1
		endif
	endfor
	String iml= ImageNameList(name,";")
	for(i=0;;i+=1)
		String iname= StringFromList(i,iml)
		if( strlen(iname) == 0 )
			break
		endif
		WAVE/Z w= ImageNameToWaveRef(name,iname)
		if( WaveExists(w) )
			wNames[next]= {{NameOfWave(w)},{GetWavesDataFolder(w,1)}}
			next += 1
		endif
	endfor

	String cwl= ChildWindowList(name)
	for(i=0;;i+=1)
		String swname= StringFromList(i,cwl)
		if( strlen(swname) == 0 )
			break
		endif
		String swpath= name+"#"+swname
		if( WinType(swpath) == 1 )
			next= AppendWindowWaveList(swpath,wNames,next)		// recursion
		endif
	endfor
	
	return next
end

Function ckExpandProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable expanded = cba.checked!=0
			ModifyControlList ControlNameList("", ";", "*_F") disable= expanded==0
			if(expanded )
				UpdateSelectedGraphInfo(cba.win,"",1)
			endif

			Variable leftWidth=  310*72/ScreenResolution
		
			GetWindow $cba.win wsize
			Variable width= V_right-V_left
			if( expanded==0 )
				width -= leftWidth
			else
				width += leftWidth
			endif
			Variable height= V_bottom-V_top
			MoveWindow/W=$cba.win V_left, V_top, V_left+width, V_top+height

			break
	endswitch

	return 0
End



Function HandleResizeEvent(winName,winRect,isFull)
	String winName
	STRUCT Rect &winRect
	Variable isFull
	
	if( isFull )
		Variable defH= 552,defW= 635		// default height and width of panel
		Variable newH= winRect.bottom - winRect.top, newW= winRect.right-winRect.left
		Variable deltaH= (newH-defH),deltaW=(newW-defW)
		 
		ListBox list0,win=$winName,pos={320,80},size={296+deltaW,421+deltaH}
	
		Slider slider0_F,win=$winName,size={268+deltaW,45}
		
		Variable lbcent= 320+(296+deltaW)/2		//listbox center
		Variable bhsep= 10			// buttons are this far from the center (right edge of left, left edeg of right)
		Variable bvsep= 30			// and are this far from bottom of widow (top of button)
		Variable bwidth= 101		// buttons are this wide
		
		
		Button bMakeVis_F,pos={lbcent-bhsep-bwidth,winRect.bottom-bvsep},win=$winName
		Button bMakeInvis_F,pos={lbcent+bhsep,winRect.bottom-bvsep},win=$winName
	
		GroupBox gbSel_F,win=$winName,size={290,374+deltaH}
		Button bEdit_F,pos={54,509+deltaH},win=$winName
		Button bSetDF_F,pos={170,509+deltaH},win=$winName
		ListBox wnlist_F,size={268,196+deltaH},win=$winName
		
		Button bNewBr_F,pos={winRect.right-110,5}
	else
		ListBox list0,win=$winName,pos={5,20},size={winRect.right-winRect.left-10,winRect.bottom-winRect.top-30}
	endif

End

Function MinPanelSize(winName,minwidth,minheight,r)
	String winName
	Variable minwidth,minheight
	STRUCT Rect &r					// resulting window dims in device units is put here
	
	minwidth *= 72/ScreenResolution
	minheight *= 72/ScreenResolution

	GetWindow $winName wsize
	Variable width= max(V_right-V_left,minwidth)
	Variable height= max(V_bottom-V_top,minheight)
	MoveWindow/W=$winName V_left, V_top, V_left+width, V_top+height
	
	GetWindow $winName wsizeDC
	r.left= V_left		// will be zero
	r.top= V_top		// ditto
	r.right= V_right
	r.bottom= V_bottom
End

Function GrfBrowserPanelWinProc(s)
	STRUCT WMWinHookStruct &s
	
	Variable rval= 0
	
	if( s.eventCode == 0 )		// activate
		UpdateGraphList(s.winName)
	elseif(  s.eventCode == 6 )	// resize
		STRUCT Rect r
		ControlInfo/W=$s.winName ckExpand
		Variable isFull= V_Value!=0
		MinPanelSize(s.winName,isFull ? 550 : 200,450,r)
		HandleResizeEvent(s.winName,r,isFull)
	endif
	
	return rval
end

Function FillWListncol(pname,ncols,getVisible,getInvisible,doStartsWith,startstr,doContains,containWave)
	String pname		// panel name
	Variable ncols,getVisible,getInvisible,doStartsWith,doContains
	String startstr,containWave

	STRUCT grfBrowserGlobals g
	GetGrfBrowserGlobals(g,pname)
	
	String cdf= GetDataFolder(1)
	NewDataFolder/O/S WMgbTmp
	
	Make/T/O/N=0 grfListNew
	
	String npat= "*"
	if( doStartsWith )
		npat= startstr+"*"
	endif
	
	if( doContains )
		if( CmpStr(containWave[0,4],"root:") != 0 )
			containWave= cdf+containWave
		endif
		WAVE/Z w=$containWave
		if( !WaveExists(w) )
			doContains= -1
		endif
	endif
	
	String wl= WinList(npat,";","WIN:1;")
	Variable i,j
	for(i=0,j=0;;i+=1)
		String name= StringFromList(i,wl)
		if( strlen(name)==0 )
			break
		endif
		DoWindow/HIDE=? $name
		Variable hidden= V_Flag==2

		if( !((getVisible && hidden==0) || ( getInvisible && hidden )) )
			continue
		endif
		
		if( doContains )
			if( doContains == -1 )
				continue				// skip all if bad wave name
			endif
			CheckDisplayed/W=$name w
			if( V_Flag==0 )
				continue
			endif
		endif
			
		grfListNew[j]={name}
		j += 1
	endfor

	Variable row,nrows= j,col,colmax= -1
	
	Sort/A grfListNew,grfListNew
	if( ncols>1 )
		nrows= ceil(nrows/ncols)
		Redimension/N=(nrows,ncols)/E=1 grfListNew
	endif

	if( !EqualWaves(grfListNew,g.wGrafList,1) )
		Duplicate/O/T grfListNew,g.wGrafList
		Redimension/N=(nrows,ncols)/E=1 g.wGrafSelList
		g.wGrafSelList= 0
		
		Variable foundit=0
		for(row=0;row<nrows;row+=1)
			for(col=0;col<ncols;col+=1)
				if( CmpStr(g.wGrafList[row][col],g.curSelGName) == 0 )
					g.wGrafSelList[row][col]= 1
					foundit= 1
					break
				endif
			endfor
		endfor
		
		if( !foundit )
			UpdateSelectedGraphInfo(pname,"",0)
		endif
	endif

	KillDataFolder :
End

Function UpdateGraphList(pname)
	String pname		// panel name
	
	ControlInfo/W=$pname slider0_F
	Variable ncol= V_Value
	
	ControlInfo/W=$pname ckVis_F
	Variable showvis= V_Value
	
	ControlInfo/W=$pname ckInVis_F
	Variable showinvis= V_Value

	ControlInfo/W=$pname ckStartWith_F
	Variable doStartsWith= V_Value 

	ControlInfo/W=$pname ckContains_F
	Variable doContains= V_Value 

	STRUCT grfBrowserGlobals g
	GetGrfBrowserGlobals(g,pname)
	
	FillWListncol(pname,ncol,showvis,showinvis,doStartsWith,g.sStartWith,doContains,g.sContainsWave)
	
	return 0
End

Function UpdateSelectedGraphInfo(pname,name,forceIt)
	String pname		// panel name
	String name
	Variable forceIt		// true to update using current selection

	STRUCT grfBrowserGlobals g
	GetGrfBrowserGlobals(g,pname)
	
	if( forceIt )
		name= g.curSelGName
	else
		if( CmpStr(g.curSelGName,name) == 0 )
			return 0			// do selection work only once
		endif
	endif
	
	ControlInfo/W=$pname ckAutoShow_F
	Variable doAutoShow= V_Value
	
	if( doAutoShow && strlen(g.curSelGName) != 0 )
		DoWindow/HIDE=(g.prevHidden) $g.curSelGName
	endif
	
	g.curSelGName= name
	
	if( strlen(name) == 0 )		// empty slot
		V_Flag= 0
	else
		DoWindow/HIDE=? $name
	endif
	g.prevHidden= V_Flag == 2
	
	variable dis= (V_Flag == 0) ? 2 : 0			// not found
	Button bShowHideSel_F,disable=dis
	Button bBringF_F,disable=dis
	if( dis == 2 )
		Redimension/N=(0,2) g.wWaveNameList		// zap contents but maintain column headers
		ListBox wnlist_F,selRow= -1
		return 0
	endif
	if( V_Flag==2 )
		Button bShowHideSel_F,userdata="show",title="Show",win=$pname
	else
		Button bShowHideSel_F,userdata="hide",title="Hide",win=$pname
	endif

	GetWindow $g.curSelGName,note
	g.gCurWinNote= S_Value

	GetWindowWaveList(g.curSelGName,g.wWaveNameList)

	if( doAutoShow )
		DoWindow/HIDE=0/B=kwTopWin $g.curSelGName
	endif

End


Function bUpdtProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			UpdateGraphList(ba.win)
			break
	endswitch

	return 0
End

Function list0Proc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 3: // double click
			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,lba.win)
			
			if( strlen(g.curSelGName) != 0 )
				Button bShowHideSel_F,userdata="hide",title="Hide"
				DoWindow/F $g.curSelGName
			endif
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			UpdateSelectedGraphInfo(lba.win,lba.listWave[row][col],0)
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
	endswitch

	return 0
End


Function bBringFProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,ba.win)
			
			Button bShowHideSel_F,userdata="hide",title="Hide"
			DoWindow/F $g.curSelGName
			break
	endswitch

	return 0
End

Function ckSelVisProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,cba.win)
			
			DoWindow/HIDE=(cba.checked==0) $g.curSelGName
			break
	endswitch

	return 0
End

Function ShowHideAll(pname,hidem)
	String pname
	Variable hidem
	
	STRUCT grfBrowserGlobals g
	GetGrfBrowserGlobals(g,pname)

	Variable row,nrows=DimSize(g.wGrafList,0),col,ncols= max(1,DimSize(g.wGrafList,1))
	for(row=0;row<nrows;row+=1)
		for(col=0;col<ncols;col+=1)
			String name= g.wGrafList[row][col]
			if( strlen(name) != 0 )
				DoWindow/HIDE=(hidem) $name
			endif
		endfor
	endfor
	
	g.prevHidden= hidem
End


Function bShowHideProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			ShowHideAll(ba.win,CmpStr(ba.ctrlName,"bMakeInvis_F")==0)
			break
	endswitch

	return 0
End



Function bShowHideSelProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable isHide= CmpStr(ba.userdata,"hide")==0
			if( isHide )
				Button $ba.ctrlName,userdata="show",title="Show"
			else
				Button $ba.ctrlName,userdata="hide",title="Hide"
			endif
			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,ba.win)
			
			DoWindow/HIDE=(isHide) $g.curSelGName
			
			g.prevHidden= isHide
			
			// click code here
			break
	endswitch

	return 0
End

Function svNoteProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 2: // Enter key
			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,sva.win)
			
			if( strlen(g.curSelGName) > 0 )
				SetWindow $g.curSelGName,note=  sva.sval
			endif
			break
	endswitch

	return 0
End


Function ColSliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa

	if( sa.eventCode  %& 0x1)	// bit 0, value set
		UpdateGraphList(sa.win)
	endif

	return 0
End


Function ckVisCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			UpdateGraphList(cba.win)
			break
	endswitch

	return 0
End

Function ckAutoShowProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	if(  cba.eventCode == 2 )		// mouse up
		STRUCT grfBrowserGlobals g
		GetGrfBrowserGlobals(g,cba.win)
		if( strlen(g.curSelGName) != 0 )
			if( cba.checked )		// after the click
				DoWindow/HIDE=0/B=kwTopWin $g.curSelGName
			else
				DoWindow/HIDE=(G.prevHidden) $g.curSelGName
			endif	
		endif
	endif
End

Function svStartWithProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			String sval = sva.sval

			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,sva.win)
			ControlInfo ckStartWith_F
			if( V_Value )
				UpdateGraphList(sva.win)
			endif

			break
	endswitch

	return 0
End

Function bEditProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,ba.win)
			ControlInfo wnlist_F
			if( V_Value >= 0 )
				String wpath= g.wWaveNameList[V_Value][1]
				if( strlen(wpath) != 0 )
					Edit $(wpath+PossiblyQuoteName(g.wWaveNameList[V_Value][0]))
				endif
			endif
			break
	endswitch

	return 0
End



Function bSetDFProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,ba.win)
			ControlInfo wnlist_F
			if( V_Value >= 0 )
				String wpath= g.wWaveNameList[V_Value][1]
				if( strlen(wpath) != 0 )
					SetDataFolder  $wpath
				endif
			endif
			break
	endswitch

	return 0
End



Function svContainsProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			String sval = sva.sval

			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,sva.win)
			ControlInfo ckContains_F
			if( V_Value )
				UpdateGraphList(sva.win)
			endif

			break
	endswitch

	return 0
End

Function bNewBrProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable i
			for(i=0;i<10;i+=1)		// no one could ever need more than 10 graph browsers! Never.
				String pname= "GraphBrowserPanel_"+num2istr(i)
				DoWindow $pname
				if( V_Flag==0 )
					GetWindow $ba.win,wsize
					NewGraphBrowserPanel(pname,V_left+10,V_top+20)
					UpdateGraphList(pname)
					break
				endif
			endfor
			break
	endswitch

	return 0
End


Function NewGraphBrowser()
	DoWindow/F GraphBrowserPanel
	if( V_Flag )
		return 0
	endif
	
	NewGraphBrowserPanel("GraphBrowserPanel",0,0)
	UpdateGraphList("GraphBrowserPanel")
End


Function popWaveListProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,pa.win)

			g.sContainsWave = PossiblyQuoteName(pa.popStr)
			CheckBox ckContains_F,value= 1
			UpdateGraphList(pa.win)
			break
	endswitch

	return 0
End

Function bWaveBrowseProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			if( !BrowserExists(1) )
				ModifyControl bWaveBrowse_F, disable=2
				break
			endif
			NVAR/Z V_Flag
			SVAR/Z S_BrowserList
			variable oldV_Flag= NVAR_Exists(V_Flag)
			variable oldS_BrowserList= SVAR_Exists(S_BrowserList)
		
			String SaveDF=GetDataFolder(1)
			String SavedBrowserState = GetBrowserSelectionViaExecute(-1)	// was GetBrowserSelection(-1)
			String thePrompt="Select a wave."
			Execute "CreateBrowser prompt=\""+thePrompt+"\", showwaves=1,showVars=0,showStrs=0"
			if (strlen(SavedBrowserState) > 0)
				Execute "ModifyBrowser "+SavedBrowserState		// ??? is this really needed ??? if so, why?
			endif
			SetDataFolder $SaveDF
			NVAR V_flag
			if (V_flag)
				SVAR S_BrowserList
				STRUCT grfBrowserGlobals g
				GetGrfBrowserGlobals(g,ba.win)
		
				g.sContainsWave = StringFromList(0,S_BrowserList)
				CheckBox ckContains_F,value= 1
				UpdateGraphList(ba.win)
				
				if( !oldS_BrowserList )
					KillStrings S_BrowserList		// clean up
				endif
			endif
			if( !oldV_Flag )
				KillVariables V_Flag		// clean up
			endif
			break
	endswitch

	return 0
End

// JP060918 - now GraphBrowser.ipf will compile if the user has started Igor with Extensions Off.
Function/S GetBrowserSelectionViaExecute(num)
	Variable num

	String/G root:Packages:WMGrfBrowser:selection
	SVAR selection= root:Packages:WMGrfBrowser:selection
	if (exists("GetBrowserSelection") == 3 )
		Execute "root:Packages:WMGrfBrowser:selection = GetBrowserSelection("+num2str(num)+")"
	else
		selection= ""
	endif
	return selection
End

// JP060918 - explain missing functionality if the user has started Igor with Extensions Off.
Function BrowserExists(tellUser)
	Variable tellUser
	
	Variable xopExists=exists("GetBrowserSelection") == 3 
	if( !xopExists && tellUser )
		DoAlert 0, "Data Browser missing or disabled by starting with Igor Extensions off (shift key held down)."
	endif
	return xopExists
End


// To update or change this, edit the recreation macro like so:
// Edit the first lines to match
// serch for "root:Packages:WMGrfBrowser:" and replace with "g."


Function NewGraphBrowserPanel(pname,x0,y0)
	String pname
	Variable x0,y0		// if non-zero, this is taken to be the origin
	
	if( x0==0 && y0==0 )
		x0= 450
		y0= 60
	endif

	NewPanel/K=1/W=(x0,y0,x0+638,y0+550)
	ModifyPanel noEdit=1
	DoWindow/C $pname
	
	STRUCT grfBrowserGlobals g
	GetGrfBrowserGlobals(g,pname)
	
	CheckBox ckExpand,pos={4,5},size={16,14},proc=ckExpandProc,title=""
	CheckBox ckExpand,value= 1,mode=2
	ListBox list0,pos={320,80},size={299,419},proc=list0Proc
	ListBox list0,listWave=g.wGrafList
	ListBox list0,selWave=g.wGrafSelList,mode= 6
	ListBox list0,special= {1,0,1}
	TitleBox title_F,pos={320,10},size={37,12},title="Columns",frame=0,anchor= LB
	CheckBox ckVis_F,pos={46,31},size={68,14},proc=ckVisCheckProc,title="Are visible"
	CheckBox ckVis_F,value= 1
	CheckBox ckInVis_F,pos={128,33},size={76,14},proc=ckVisCheckProc,title="Are invisible"
	CheckBox ckInVis_F,value= 1
	Slider slider0_F,pos={334,27},size={268,45},proc=ColSliderProc
	Slider slider0_F,limits={1,4,1},value= 1,vert= 0
	SetVariable svCurSelName_F,pos={20,182},size={262,15},title="Graph:"
	SetVariable svCurSelName_F,value= g.curSelGName,noedit= 1
	Button bBringF_F,pos={167,205},size={107,22},proc=bBringFProc,title="Bring to front"
	Button bMakeVis_F,pos={358,520},size={101,22},proc=bShowHideProc,title="Show All"
	Button bMakeInvis_F,pos={479,520},size={101,22},proc=bShowHideProc,title="Hide All"
	Button bShowHideSel_F,pos={50,205},size={105,22},proc=bShowHideSelProc,title="Show"
	Button bShowHideSel_F,userdata=  "show"
	SetVariable svNote_F,pos={24,271},size={254,15},proc=svNoteProc,title="win note"
	SetVariable svNote_F,value= g.gCurWinNote
	GroupBox gbSel_F,pos={13,162},size={290,374},title="Selection"
	ListBox wnlist_F,pos={26,301},size={268,196},frame=2
	ListBox wnlist_F,listWave=g.wWaveNameList,mode= 1
	ListBox wnlist_F,selRow= 5,special= {0,0,1}
	CheckBox ckAutoShow_F,pos={51,237},size={66,14},proc=ckAutoShowProc,title="Auto Show"
	CheckBox ckAutoShow_F,help={"Automatically show and hide graphs as selected in list."}
	CheckBox ckAutoShow_F,value= 0
	CheckBox ckStartWith_F,pos={46,56},size={16,14},proc=ckVisCheckProc,title=""
	CheckBox ckStartWith_F,value= 0
	SetVariable svStartWith_F,pos={64,56},size={164,15},proc=svStartWithProc,title="Start with:"
	SetVariable svStartWith_F,value= g.sStartWith
	GroupBox showGB_F,pos={15,9},size={287,148},title="Show windows that:"
	SetVariable svStartWith1_F,pos={64,78},size={164,15},proc=svContainsProc,title="Contain wave:"
	SetVariable svStartWith1_F,value= g.sContainsWave
	CheckBox ckContains_F,pos={46,78},size={16,14},proc=ckVisCheckProc,title=""
	CheckBox ckContains_F,value= 0
	Button bNewBr_F,pos={532,5},size={101,18},proc=bNewBrProc,title="New Browser"
	PopupMenu popWaveList_F,pos={230,76},size={20,20},proc=popWaveListProc
	PopupMenu popWaveList_F,help={"Select a wave in the current DataFolder."}
	PopupMenu popWaveList_F,mode=0,value= WaveList("*",";","")
	Button bWaveBrowse_F,pos={254,76},size={19,21},proc=bWaveBrowseProc,title="B"
	Button bWaveBrowse_F,help={"Use DataBrowser to select wave."}
	Button bEdit_F,pos={54,509},size={50,20},proc=bEditProc,title="Edit"
	Button bEdit_F,help={"View or edit wave in a new table."}
	Button bSetDF_F,pos={170,509},size={50,20},proc=bSetDFProc,title="Set DF"
	Button bSetDF_F,help={"Set Current DataFolder to same as selected wave."}
	SetWindow kwTopWin,hook(base)=GrfBrowserPanelWinProc
EndMacro
