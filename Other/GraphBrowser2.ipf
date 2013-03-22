#pragma rtGlobals=2		// Use modern global access method.
#pragma IgorVersion=6.0	// Independent modules require Igor 6
#pragma version=6.0
#pragma IndependentModule= RCG_GrfBrowser

// GraphBrowser.ipf
// Version 6.0, LH051121
// Version 6.01, Fixed two minor bugs, search for LH090609

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
	Variable curWidth= V_right-V_left
	Variable curHeight= V_bottom-V_top
	if( curWidth < minwidth || curHeight < minheight )		// LH090609: avoid unnecessary move to fix problem on Windows when maximized.
		MoveWindow/W=$winName V_left, V_top, V_left+max(curWidth,minwidth), V_top+max(curHeight,minheight)
	endif
	
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

	ControlInfo/W=$pname ckExpand
	Variable isFull= V_Value!=0				// full mode includes controls, non-full is just list of graphs
	
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
	Button bShowHideSel_F,disable=dis | (!isFull)		// LH090609: maintain hidden if not full mode
	Button bBringF_F,disable=dis | (!isFull)
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
		case 1: // Mouse down.  
			if(lba.eventMod & 16) // Right-click.    
				string win=listWave[lba.row][lba.col]
				SetWindow kwTopWin userData(win)=win
				PopupContextualMenu /N "GraphBrowserMenu"
			endif
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

menu "GraphBrowserMenu", contextualMenu, dynamic
	"\""+RCG_GrfBrowser#GraphBrowserWinTitle()+"\"",/Q,GraphBrowserMenuHook("Retitle")
	submenu "Importance"
		GraphBrowserWinImportance(3),/Q,GraphBrowserMenuHook("Importance",options="Importance:3")
		GraphBrowserWinImportance(2),/Q,GraphBrowserMenuHook("Importance",options="Importance:2")
		GraphBrowserWinImportance(1),/Q,GraphBrowserMenuHook("Importance",options="Importance:1")
	end
	"Annotate",/Q,GraphBrowserMenuHook("Annotate")
	"Show Important",/Q,GraphBrowserMenuHook("Show Important")
	"Show Similar",/Q,GraphBrowserMenuHook("Show Similar")
	"Layouts",/Q,InitLayoutManager()
	"Close",/Q,GraphBrowserMenuHook("Close")
	"Network Graph",/Q,GraphBrowserMenuHook("Network Graph")
end

function /s GraphBrowserWinTitle([win])
	string win
	
	if(paramisdefault(win))
		string panel=winname(0,64)
		if(strlen(panel))
			win=getuserdata(panel,"","win")
		else
			win=""
		endif
	endif
	if(wintype(win))
		getwindow /z $win, wtitle
		string title=s_value
	else
		title=""
	endif
	return title
end

function GraphBrowserMenuHook(item[,options])
	string item,options
	
	options=selectstring(!paramisdefault(options),"",options)
	string win=GetUserData("","","win")
	dfref pf=root:Packages:WMGrfBrowser:
	strswitch(item)
		case "Retitle": // Retitle this graph.
			getwindow $win, wtitle  
			string title=s_value
			prompt title,"Title:"
			//prompt annotation,"Annotation:"
			doprompt win+" Info",title//,annotation
			if(!v_flag)
				dowindow /t $win title
				//setwindow $win userData(annotation)=annotation
			endif
			break
		case "Annotate": // Annotate this graph.    
			InitGraphAnnotator(win)
			break
		case "Importance":
			setwindow $win userData(Importance)=stringbykey("Importance",options)
			wave /z/sdfr=pf Importance
			if(waveexists(Importance) && FindDimLabel(Importance,0,win)>=0)
				Importance[%$win]=numberbykey("Importance",options)
			endif
			break
		case "Show Important":
			InitGraphImportance("")//win)
			break
		case "Show Similar":
			InitGraphSimilarity(win)
			break		
		case "Layouts":
			InitLayoutManager()
			break
		case "Close":
			dowindow /k $win
			break
		case "Network Graph":
			STRUCT grfBrowserGlobals g
			GetGrfBrowserGlobals(g,"GraphBrowserPanel")
			newpath /o/q desktop specialdirpath("Desktop",0,0,0)
			variable i
			for(i=0;i<numpnts(g.wGrafList);i+=1)
				savepict /e=-5/win=$(g.wGrafList[i])/o/p=Desktop
			endfor
			NetworkGraph()
			break
	endswitch
end

function InitLayoutManager()
	STRUCT grfBrowserGlobals g
	GetGrfBrowserGlobals(g,"GraphBrowserPanel")
	dfref pf=root:Packages:WMGrfBrowser:
	newdatafolder /o pf:layouts
	dfref sf=pf:layouts
	
	variable i,j,k
	extract /free/t g.wGrafList,graphs,strlen(g.wGrafList) && wintype(g.wGrafList[p])
	sort graphs,graphs
	variable numGraphs=numpnts(graphs)
	
	dowindow /k LayoutManagerWin
	nvar /z/sdfr=sf width
	svar /z/sdfr=sf mask
	if(!nvar_exists(width))
		variable /g sf:width=100
		nvar /sdfr=sf width
	endif
	if(!svar_exists(mask))
		string /g sf:mask="Fig[0-9]+"
		svar /sdfr=sf mask
	endif
	string all_layouts=winlist("*",";","WIN:4")
	string layouts=""
	for(i=0;i<itemsinlist(all_layouts);i+=1)
		string layout_=stringfromlist(i,all_layouts)
		if(grepstring(layout_,mask))
			layouts+=layout_+";"
		endif
	endfor
	//listmatch(layouts,mask)
	layouts=sortlist(layouts,";",16)
	//layouts=listmatch(layouts,"Fig*")+removefromlist(listmatch(layouts,"Fig*"),layouts)
	variable numLayouts=itemsinlist(layouts)
	
	newpanel /k=1/n=LayoutManagerWin /w=(0,0,max(500,width*(numLayouts+1)),740) as "Layouts"
	setwindow LayoutManagerWin userData(numLayouts)=num2str(numLayouts)
	if(wintype("GraphBrowserPanel"))
		AutoPositionWindow /R=GraphBrowserPanel LayoutManagerWin
	endif
	
	setwindow LayoutManagerWin userData(xOffsets)=""
	groupbox controls, pos={2,2}, size={470,26}, labelback=(50000,50000,50000)
	button Refresh, title="Refresh", pos={4,5}, size={50,20}, proc=GraphBrowserAuxButtons
	checkbox Titles, title="Titles", pos+={0,3}, value=0, proc=GraphBrowserAuxCB
	setvariable Size, title="Size", pos+={0,-1}, size={60,20}, limits={50,1000,50}, variable=width, proc=GraphBrowserAuxSV
	setvariable Mask, title="Mask", size={100,20}, variable=mask, proc=GraphBrowserAuxSV
	button NewLayout_, title="New Layout:", pos+={15,-2}, size={70,20}, proc=GraphBrowserAuxButtons
	popupmenu Template, title=" ", mode=1, value="Generic;---;"+winlist("*",";","WIN:4")+"---;"+MacroList("*",";","SUBTYPE:Layout")
	for(i=0;i<=numLayouts;i+=1)
		if(i>0)
			layout_=stringfromlist(i-1,layouts)
		else
			layout_="Unassigned"
		endif
		make /o/n=0/t sf:$("listWave_"+num2str(i)) /wave=listWave
		for(j=0;j<numGraphs;j+=1)
			string graph=graphs[j]
			if(i>0)
				string graphInfo=layoutinfo(layout_,graph)
				if(strlen(graphInfo)) // If this graph is on this layout.  
					listWave[numpnts(listWave)]={graph}
				endif
			else
				variable assigned=0
				for(k=0;k<numLayouts;k+=1)
					string layout2=stringfromlist(k,layouts)
					graphInfo=layoutinfo(layout2,graph)
					if(strlen(graphInfo)) // If this graph is on this layout.  
						assigned=1
					endif
				endfor
				if(!assigned)
					listWave[numpnts(listWave)]={graph}
				endif
			endif
		endfor
		redimension /n=(max(1,numpnts(listWave))) listWave
		make /o/n=(numpnts(listWave)) sf:$("selWave_"+num2str(i)) /wave=selWave
		
		checkbox $("show_"+num2str(i)), pos={i*width,30}, size={20,20}, title=" ", value=1, proc=GraphBrowserAuxCB
		titlebox $("layoutTitle_"+num2str(i)), pos+={-11,0}, size={width,20}, title=layout_, userData(win)=layout_
		listbox $("layout_"+num2str(i)) listWave=listWave, selWave=selWave, pos={i*width,50}, size={width,700}, special={1,0,0}, mode=4, title=layout_, userData(win)=layout_,proc=GraphBrowserAuxLB
		controlinfo $("layout_"+num2str(i))
		setwindow LayoutManagerWin userData(xOffsets)+=num2str(v_left+v_width)+";"
	endfor
end

function NetworkGraph()
	dfref pf=root:Packages:WMGrfBrowser:
	wave /z/sdfr=pf importance,similarity
	if(!waveexists(importance) || !waveexists(similarity))
		printf "Must compute both importance and similarity first.\r"
	endif
	newdatafolder /o pf:graph
	dfref df=pf:graph
	
	//tic(); similarity=RCG_GrfBrowser#WinSimilarity(GetDimLabel(similarity,0,p),GetDimLabel(similarity,1,q)); toc()
	duplicate /o similarity,df:distance /wave=distance
	distance=1/(similarity[p][q]+0.2)
	string distancePath=getdatafolder(1,df)+"distance"
	duplicate /o Importance,df:size /wave=size
	size*=2
	string sizePath=getdatafolder(1,df)+"size"
	make /o/n=(numpnts(Importance)) /t df:labels=GetDimLabel(Importance,0,p)
	duplicate /o/t df:labels,df:images /wave=nodeImages
	nodeImages+=".png"
	string labelsPath=getdatafolder(1,df)+"labels"
	string imagePath=getdatafolder(1,df)+"images"
	
	Execute /Q "ProcGlobal#DistanceMatrix2GraphViz(\"neato\","+distancePath+",lenScale=15,nodeLabels="+labelsPath+",nodeImages="+imagePath+",nodeSize="+sizePath+",showEdges=0,toPDF=1)"
end

function InitGraphAnnotator(win)
	string win
	dowindow /k GraphAnnotatorWin
	if(wintype(win))
		newpanel /k=1/n=GraphAnnotatorWin /w=(0,0,500,250) as "Annotation for "+win
		setwindow GraphAnnotatorWin userData(win)=win
		AutoPositionWindow /R=LayoutManagerWin GraphAnnotatorWin
		setvariable Name value=_STR:win, size={75,20}, title="Name", proc=GraphAnnotatorSV
		getwindow $win, title 
		setvariable Title value=_STR:s_value, size={125,20}, title="Title", proc=GraphAnnotatorSV
		variable Importance=str2num(getuserdata(win,"","Importance"))
		setvariable Importance value=_NUM:(numtype(Importance) ? 1 : Importance), limits={1,3,1}, size={75,20}, title="Importance",proc=GraphAnnotatorSV
		string annotation=getuserdata(win,"","annotation")
		newnotebook /HOST=GraphAnnotatorWin /f=1/n=Annotation/w=(0.01,0.10,0.99,0.99)
		notebook GraphAnnotatorWin#Annotation text=annotation//, proc=GraphAnnotatorSV
		button Update, title="Update", pos+={0,-2}, proc=GraphAnnotatorButtons
	endif
end

function GraphAnnotatorButtons(info)
	struct wmbuttonaction &info
	
	string win=getuserdata(info.win,"","win")
	if(info.eventCode==2)
		strswitch(info.ctrlName)
			case "Update":
				notebook GraphAnnotatorWin#Annotation getData=2
				setwindow $win userData(annotation)=s_value
				dowindow /k GraphAnnotatorWin
				break
		endswitch
	endif
end

function GraphAnnotatorSV(info)
	struct wmsetvariableaction &info
	
	string win=GetUserData(info.win,"","win")
	dfref pf=root:Packages:WMGrfBrowser
	if(info.eventCode>0)
		strswitch(info.ctrlName)
			case "Name":
				variable illegal=checkname(info.sval,6)
				string newName = info.sval
				if(!stringmatch(newname,win) && !illegal)
					dowindow /c/w=$win $newname
					dowindow /t $info.win "Annotation for "+newname
					setwindow GraphAnnotatorWin userData(win)=newname
					wave /t/sdfr=pf wGrafList
					findvalue /text=win /txop=4 wGrafList
					if(v_value>=0)
						wGrafList[v_value]=newName
					endif
					InitLayoutManager()
				endif
				break
			case "Title":
				dowindow /t $win info.sval
				break
			case "Importance":
				setwindow $win userData(Importance)=num2str(info.dval)
				wave /z/sdfr=pf Importance
				if(waveexists(Importance) && FindDimLabel(Importance,0,win)>=0)
					Importance[%$win]=info.dval
				endif
				break
			case "Annotation":
				setwindow $win userData(annotation)=info.sval
				break
		endswitch
	endif
end

function InitGraphImportance(win)
	string win
	
	STRUCT grfBrowserGlobals g
	GetGrfBrowserGlobals(g,"GraphBrowserPanel")
	dfref pf=root:Packages:WMGrfBrowser:
	wave /z/sdfr=pf Importance
	if(!waveexists(Importance))
		make /o/n=0 pf:Importance /wave=Importance
	endif
	variable i=0
	extract /free/t g.wGrafList,graphs,strlen(g.wGrafList)
	variable numGraphs=numpnts(graphs)
	
	// Delete Importance wave entries that correspond to graphs that no longer exist.  
	do
		string labell=GetDimLabel(Importance,0,i)
		findvalue /text=labell /txop=4 graphs
		if(v_value<0 || strlen(labell)==0)
			deletepoints i,1,Importance
		else
			i+=1
		endif
	while(i<dimsize(Importance,0))
	
	// Add points for graphs that were not previously in the Importance matrix.    
	for(i=0;i<numGraphs;i+=1)
		string win_=graphs[i]
		variable index=FindDimLabel(Importance,0,win_)
		if(index<0)
			variable size=dimsize(Importance,0)
			redimension /n=(size+1) Importance
			SetDimLabel 0,size,$win_,Importance
			Importance[size]=1
		else
			Importance[%$win_]=str2num(getuserdata(win_,"","Importance"))
		endif
	endfor
	Importance=numtype(Importance) ? 1 : Importance
	newdatafolder /o pf:Importance
	dfref sf=pf:Importance
	
	dowindow /k GraphImportanceWin
	variable numImportanceLevels=3
	newpanel /k=1/n=GraphImportanceWin /w=(0,0,200*numImportanceLevels+10,700) as "<-- More Important              Less Important -->"
	setwindow GraphImportanceWin userData(win)=win
	setwindow GraphImportanceWin userData(numCategories)=num2str(numImportanceLevels)
	AutoPositionWindow /R=GraphBrowserPanel GraphImportanceWin
	
	setwindow GraphImportanceWin userData(xOffsets)=""
	for(i=0;i<numImportanceLevels;i+=1)
		extract /free/indx Importance,thisImportant,Importance==(i+1) || Importance<=0 || numtype(Importance)
		make /o/n=(max(1,numpnts(thisImportant)))/t sf:$("listWave_"+num2str(i)) /wave=listWave=selectstring(numpnts(thisImportant),"",graphs[thisImportant[p]])
		make /o/n=(max(1,numpnts(thisImportant))) sf:$("selWave_"+num2str(i)) /wave=selWave=0
		listbox $("Importance_"+num2str(i)) listWave=listWave, selWave=selWave, pos={200*numImportanceLevels-(i+1)*200,0}, size={200,700}, special={1,0,0}, mode=4, proc=GraphBrowserAuxLB, win=GraphImportanceWin
		controlinfo $("Importance_"+num2str(i))
		setwindow GraphImportanceWin userData(xOffsets)+=num2str(v_left)+";"
	endfor
end

function InitGraphSimilarity(win)
	string win
	
	STRUCT grfBrowserGlobals g
	GetGrfBrowserGlobals(g,"GraphBrowserPanel")
	dfref pf=root:Packages:WMGrfBrowser:
	wave /z/sdfr=pf similarity
	if(!waveexists(similarity))
		make /o/n=0 pf:similarity /wave=similarity
	endif
	variable i=0
	extract /free/t g.wGrafList,graphs,strlen(g.wGrafList)
	variable numGraphs=numpnts(graphs)
	
	// Delete similarity matrix entries that correspond to graphs that no longer exist.  
	do
		string labell=GetDimLabel(similarity,0,i)
		findvalue /text=labell /txop=4 graphs
		if(v_value<0 || strlen(labell)==0)
			deletepoints /m=0 i,1,similarity
			deletepoints /m=1 i,1,similarity
		else
			i+=1
		endif
	while(i<dimsize(similarity,0))
	
	// Add rows and columns for graphs that were not previously in the similarity matrix.    
	for(i=0;i<numGraphs;i+=1)
		string win_=graphs[i]
		variable index=FindDimLabel(similarity,0,win_)
		if(index<0)
			variable size=dimsize(similarity,0)
			redimension /n=(size+1,size+1) similarity
			similarity[size][]=0
			similarity[][size]=0
			similarity[size][size]=1
			SetDimLabel 0,size,$win_,similarity
			SetDimLabel 1,size,$win_,similarity
		endif
	endfor
	newdatafolder /o pf:similarity
	dfref sf=pf:similarity
	
	findvalue /text=win /txop=4 graphs
	if(v_value<0)
		printf "Could not find current window %s in the graph list.\r",win
		return -1
	endif
	
	dowindow /k GraphSimilarityWin
	variable numCategories=3
	newpanel /k=1/n=GraphSimilarityWin /w=(0,0,200*numCategories+10,730) as "<-- More Similar              Less Similar -->"
	button ResetSimilarity, proc=GraphBrowserAuxButtons, size={100,20}, title="Reset Similarity"
	setwindow GraphSimilarityWin userData(win)=win
	setwindow GraphSimilarityWin userData(numCategories)=num2str(numCategories)
	AutoPositionWindow /R=GraphBrowserPanel GraphSimilarityWin
	// Similar = 1; Dissimilar = 0.  
	
	make /o/n=(numGraphs) sf:currSimilarity /wave=currSimilarity=similarity[p][%$win]
	variable currIndex=FindDimLabel(similarity,1,win)
	currSimilarity[currIndex]=nan // Delete comparison to self.  
	
	setwindow GraphSimilarityWin userData(xOffsets)=""
	for(i=0;i<numCategories;i+=1)
		extract /free/indx currSimilarity,thisSimilar,(currSimilarity<(i+1)/numCategories && currSimilarity>=i/numCategories) || (i==(numCategories-1) && currSimilarity==1)
		make /o/n=(max(1,numpnts(thisSimilar)))/t sf:$("listWave_"+num2str(i)) /wave=listWave=selectstring(numpnts(thisSimilar),"",graphs[thisSimilar[p]])
		make /o/n=(max(1,numpnts(thisSimilar))) sf:$("selWave_"+num2str(i)) /wave=selWave=0
		listbox $("similarity_"+num2str(i)) listWave=listWave, selWave=selWave, pos={200*numCategories-(i+1)*200,30}, size={200,700}, special={1,0,0}, mode=4, proc=GraphBrowserAuxLB, win=GraphSimilarityWin
		controlinfo $("similarity_"+num2str(i))
		setwindow GraphSimilarityWin userData(xOffsets)+=num2str(v_left)+";"
	endfor
end

function GraphBrowserAuxButtons(info)
	struct wmbuttonaction &info
	
	dfref pf=root:Packages:WMGrfBrowser:
	string name=stringfromlist(0,info.ctrlName,"_")
	variable num=str2num(stringfromlist(1,info.ctrlName,"_"))
	switch(info.eventCode)
		case 2: // Mouse up.  
			strswitch(info.win)
				case "LayoutManagerWin":
					strswitch(name)
						case "Refresh":
							UpdateGraphList("GraphBrowserPanel")
							InitLayoutManager()
							break
						case "NewLayout":
							ControlInfo Template
							strswitch(s_value)
								case "---":
									break
								case "Generic":
									CreateGenericLayout()
									doupdate
									string new=winname(0,4)
									InitLayoutManager()
									InitGraphAnnotator(new)
									break
								default:
									if(whichlistitem(s_value,winlist("*",";","WIN:4"))>=0)
										string macroStr=winrecreation(s_value,0)
										execute /q macroStr
									elseif(whichlistitem(s_value,macrolist("*",";","SUBTYPE:Layout"))>=0)
										execute /q s_value
									endif
									doupdate
									new=winname(0,4)
									InitLayoutManager()
									InitGraphAnnotator(new)
							endswitch
							break
					endswitch
					break
				case "GraphSimilarityWin":
					wave /z/sdfr=pf similarity
					string path=getwavesdatafolder(similarity,2)
					execute /q "duplicate /o ProcGlobal#WinSimilarityMatrix(ProcGlobal#DimLabel2String("+path+",0),3) temp"
					wave temp
					similarity=temp[p][q]
					killwaves /z temp
					string win=getuserdata(info.win,"","win")
					InitGraphSimilarity(win)
					break
			endswitch
			break
	endswitch
end

function GraphBrowserAuxSV(info)
	struct wmsetvariableaction &info
	
	switch(info.eventCode)
		case 1:
		case 2:
			dfref pf=root:Packages:WMGrfBrowser:
			dfref sf=pf:layouts
			strswitch(info.ctrlName)
				case "Width":
					nvar /sdfr=sf width
					width=info.dval
					break
				case "Mask":
					svar /sdfr=sf mask
					mask=info.sval
					break
			endswitch
			InitLayoutManager()
			break
	endswitch
end

function GraphBrowserAuxCB(info)
	struct wmcheckboxaction &info
	
	dfref pf=root:Packages:WMGrfBrowser:
	dfref df=pf:layouts
	nvar /z/sdfr=df width
	string name=stringfromlist(0,info.ctrlName,"_")
	variable num=str2num(stringfromlist(1,info.ctrlName,"_"))
	switch(info.eventCode)
		case 2: // Mouse up.  
			strswitch(name)
				case "Titles":
					variable i
					string titleBoxes=ControlNameList("",";","layoutTitle*")
					for(i=0;i<itemsinlist(titleBoxes);i+=1)
						string box=stringfromlist(i,titleBoxes)
						string win=getuserdata("",box,"win")
						if(!stringmatch(win,"Unassigned"))
							getwindow /z $win title
							Titlebox $box, title=selectstring(info.checked,win,selectstring(strlen(s_value),win,s_value))
						endif
					endfor
					break
				case "Show":
					//variable collapsed=str2num(getuserdata(info.win,info.ctrlName,"collapsed"))
					listbox $("layout_"+num2str(num)) disable=!info.checked
					titlebox $("layoutTitle_"+num2str(num)) disable=!info.checked
					variable move=(info.checked*2-1)*(width-20)
					ShiftXOffsets(num,move,info.win)
					num+=1
					string xOffsets=getuserdata(info.win,"","xOffsets")
					do
						controlinfo $("layout_"+num2str(num))
						if(v_flag>0)
							listbox $("layout_"+num2str(num)) pos+={move,0}
							checkbox $("show_"+num2str(num)) pos+={move,0}
							controlinfo $("show_"+num2str(num))
							titlebox $("layoutTitle_"+num2str(num)) pos={v_left+20,v_top}
							ShiftXOffsets(num,move,info.win)
						else
							break
						endif
						num+=1
					while(1)
					//listbox $("layout_"+num2str(num)) disable=!collapsed	
					break
			endswitch
	endswitch
end

function ShiftXOffsets(num,delta,win)
	variable num,delta
	string win
	
	string xOffsets=getuserdata(win,"","xOffsets")
	variable oldXOffset=str2num(stringfromlist(num,xOffsets))
	variable newXOffset=oldXOffset+delta
	xOffsets=replacestring(";"+num2str(oldXOffset)+";",";"+xOffsets,";"+num2str(newXOffset)+";")
	xOffsets=xOffsets[1,strlen(xOffsets)-1]
	setwindow $win userData(xOffsets)=xOffsets
end

function CreateGenericLayout()
	preferences 1
	NewLayout
	string fsize="24"
	textbox /f=0/t=1/a=lt/x=0/y=0/n=A "\Z"+fsize+"A"
	textbox /f=0/t=1/a=lt/x=50/y=0/n=B "\Z"+fsize+"B"
	textbox /f=0/t=1/a=lt/x=0/y=33/n=C "\Z"+fsize+"C"
	textbox /f=0/t=1/a=lt/x=50/y=33/n=D "\Z"+fsize+"D"
	textbox /f=0/t=1/a=lt/x=0/y=66/n=E "\Z"+fsize+"E"
	textbox /f=0/t=1/a=lt/x=50/y=66/n=F "\Z"+fsize+"F"
end

function GraphBrowserAuxLB(info)
	struct wmlistboxaction &info
	
	switch(info.eventCode)
		case 1:
			// Selected.  
			if(info.eventMod & 16) // Right-click
				string selected=getuserdata(info.win,"","selected")
				string win=stringfromlist(1,selected,":")
				if(!strlen(win))
					win=getuserdata("",info.ctrlName,"win")
				endif
				InitGraphAnnotator(win)
			else
				wave /t w=info.listWave
				selected=""
				if(info.row<numpnts(w))
					selected=info.ctrlName+":"+w[info.row]
				endif
				setwindow $info.win userData(selected)=selected
				if(info.eventMod & 2)
					setwindow $info.win userData(copy)="1"
				else
					setwindow $info.win userData(copy)="0"
				endif
			endif
			break
		case 2: 
			// Moved.  
			controlinfo /w=$info.win $info.ctrlName
			variable destRow=floor((info.mouseLoc.v+v_vertscroll-50)/v_rowheight)
			// Not quite the same as info.row in some cases.  
			if(destRow<0)
				return -3
			endif
			selected=getuserdata(info.win,"","selected")
			if(!strlen(selected))
				return -2
			endif
			variable columnMouseDown=str2num(stringfromlist(1,info.ctrlName,"_"))
			string xOffsets=getuserdata(info.win,"","xOffsets")
			make /free/n=(itemsinlist(xOffsets)) xOffsets_=str2num(stringfromlist(p,xOffsets))
			variable columnMouseUp=1+binarysearch(xOffsets_,info.mouseLoc.h)
			if(columnMouseUp>=0 && columnMouseDown>=0)
				dfref pf=root:Packages:WMGrfBrowser:
				strswitch(info.win)
					case "GraphImportanceWin":
						if(columnMouseUp==columnMouseDown)
							return -4
						endif
						string type="Importance"
						break
					case "GraphSimilarityWin":
						if(columnMouseUp==columnMouseDown)
							return -4
						endif
						type="similarity"
						break
					case "LayoutManagerWin":
						type="layouts"
						break
				endswitch
				dfref sf=pf:$type
				wave /sdfr=sf/t oldListWave=$("listWave_"+num2str(columnMouseDown))
				wave /sdfr=sf oldSelWave=$("selWave_"+num2str(columnMouseDown))
				wave /sdfr=sf/t newListWave=$("listWave_"+num2str(columnMouseUp))
				wave /sdfr=sf newSelWave=$("selWave_"+num2str(columnMouseUp))
				win=stringfromlist(1,selected,":")
				if(!strlen(win))
					return -6
				endif
				findvalue /text=win /txop=4 oldListWave
				variable sourceRow=v_value
				if(sourceRow<0)
					printf "Could not find window %s in list wave.\r",win
					return -1
				elseif(sourceRow==destRow && columnMouseUp==columnMouseDown) // Same place.  
					return -5
				endif
				destRow=min(destRow,dimsize(newListWave,0))
				variable copy=str2num(getuserdata(info.win,"","copy"))
				copy=numtype(copy) ? 0 : copy
				if(copy==0)
					deletepoints sourceRow,1,oldListWave,oldSelWave
					if(numpnts(oldListWave)==0)
						oldListWave[0]={""}
						oldSelWave[0]={0}
					endif
				endif
				if(strlen(newListWave[0]))
					insertpoints destRow,1,newListWave,newSelWave
				else
					destRow=0
				endif
				newListWave[destRow]=win
				newSelWave[destRow]=0
				string comparisonWin=getuserdata(info.win,"","win")
				variable numCategories=str2num(getuserdata(info.win,"","numCategories"))
				wave /z/sdfr=pf wValue=$type
				strswitch(type)
					case "importance":
						variable newValue=columnMouseUp+1
						wValue[%$win]=newValue
						setwindow $win userData(Importance)=num2str(newValue)
						break
					case "similarity":
						newValue=columnMouseUp/(numCategories-1)
						wValue[%$comparisonWin][%$win]=newValue
						wValue[%$win][%$comparisonWin]=newValue
						break
					case "layouts": // Move graph to its new layout.  
						string oldLayout_=getuserdata("LayoutManagerWin","layout_"+num2str(columnMouseDown),"win")
						string newLayout_=getuserdata("LayoutManagerWin","layout_"+num2str(columnMouseUp),"win")
						if(!stringmatch(oldLayout_,"Unassigned"))
							RemoveLayoutObjects /Z/W=$oldLayout_ $win
						endif
						if(!stringmatch(newLayout_,"Unassigned"))						
							AppendLayoutObject /F=0/T=1/W=$newLayout_ graph $win
						endif
						FixLayout(oldLayout_,oldListWave)
						FixLayout(newLayout_,newListWave)
						break
				endswitch
			endif
			break
		case 3:
			selected=getuserdata(info.win,"","selected")
			win=stringfromlist(1,selected,":")
			if(wintype(win)==1 || wintype(win)==2)
				dowindow /f $win
			else
				win=getuserdata(info.win,info.ctrlName,"win")
				dowindow /f $win
			endif
			break
		case 12:
			selected=getuserdata(info.win,"","selected")
			win=stringfromlist(1,selected,":")
			variable num=info.row // Keystroke char code.  
			if(num==127) // Delete.  
				findvalue /text=(win) /txop=4 info.listWave
				deletepoints v_value,1,info.listWave,info.selWave
				string layout_=getuserdata("",info.ctrlName,"win")
				RemoveLayoutObjects /Z/W=$layout_ $win
				FixLayout(layout_,info.listWave)
			endif
			break
	endswitch
end

function FixLayout(win,graphs)
	string win
	wave /t graphs

	variable i,j
	if(wintype(win)==3)
		string list=annotationlist(win)
		string page=stringbykey("PAGE",LayoutInfo(win,"layout"))
		for(i=0;i<numpnts(graphs);i+=1)
			string graph=graphs[i]
			if(!strlen(graph))
				continue
			endif
			string letter=num2char(97+i)
			if(whichlistitem(letter,list,";",0,0)>=0)
				string info=annotationinfo(win,letter)
				string rect=stringbykey("RECT",info)
				variable right=str2num(stringfromlist(2,rect,","))
				variable bottom=str2num(stringfromlist(3,rect,","))
				variable maxWidth=inf, maxHeight=inf
				for(j=-2;j<itemsinlist(list);j+=1)
					if(j>=0)
						string other=stringfromlist(j,list) // Another annotation (i.e. another letter).  
						string otherInfo=annotationinfo(win,other)
						string otherRect=stringbykey("RECT",otherInfo)
						variable otherLeft=str2num(stringfromlist(0,otherRect,","))
						variable otherTop=str2num(stringfromlist(1,otherRect,","))
						variable otherRight=str2num(stringfromlist(2,otherRect,","))
						variable otherBottom=str2num(stringfromlist(3,otherRect,","))
					elseif(j==-2) // Right edge.  
						otherBottom=bottom  // Always lined up (apply to all figures).  
						otherLeft=str2num(stringfromlist(2,page,",")) // Right edge of page.  
					elseif(j==-1) // Bottom edge.  
						otherRight=right // Always lined up (apply to all figures).  
						otherTop=str2num(stringfromlist(3,page,",")) // Bottom edge of page.  
					endif
					if(abs(right-otherRight)<25 && otherTop>bottom)
						maxHeight=min(maxHeight,0.95*(otherTop-bottom))
					endif
					if(abs(bottom-otherBottom)<25 && otherLeft>right)
						maxWidth=min(maxWidth,0.95*(otherLeft-right))
					endif
				endfor
				modifylayout /w=$win left($graph)=right, top($graph)=bottom
				info=layoutinfo(win,graph)
				variable width=numberbykey("WIDTH",info)
				variable height=numberbykey("HEIGHT",info)
				modifylayout /w=$win width($graph)=min(width,maxWidth), height($graph)=min(height,maxHeight)
			endif
		endfor
	endif
end

// Return the name of the annotation with annotation text 'str'
function /S GetAnnotation(str[,win])
	string str,win
	
	win=selectstring(!paramisdefault(win),winname(0,5),win)
	string list=AnnotationList(win)
	variable i
	for(i=0;i<itemsinlist(list);i+=1)
		string item=stringfromlist(i,list)
		string info=annotationinfo(win,item)
		string text=stringbykey("TEXT",info)
		if(stringmatch(str,text))
			return item
		endif
	endfor
	return ""
end

function /s GraphBrowserWinImportance(Importance)
	variable Importance
	
	string str=""
	if(wintype("GraphBrowserPanel"))
		string win=getuserdata("GraphBrowserPanel","","win")
		if(wintype(win))
			variable currImportance=str2num(getuserdata(win,"","Importance"))
			str=num2str(Importance) + selectstring(Importance==currImportance || (Importance==1 && numtype(currImportance)),"","!*")
		endif
	endif
	return str
end

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

	NewPanel/K=1/W=(x0,y0,x0+638,y0+550) as "Graph Browser"
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