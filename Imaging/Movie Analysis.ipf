#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName = Movie

strconstant package_loc="root:Packages:MovieProcessPanel"

Menu "Imaging"
	//"Movie Processing",/Q,InitMovieProcessing()
End

function /df MovieHome([instance,create,go])
	string instance
	variable create,go
	
	instance = selectstring(!paramisdefault(instance),"default",instance)
	dfref df = InstanceHome("Acq","movie","default",create=create)
	if(go)
		setdatafolder df
	endif
	return df
end

Function InitMovieProcessing()
	//InitializeExperiment()
	dfref currDF = GetDataFolderDFR()
	dfref df = MovieHome(create=1,go=1)
	string /g movie_mask="*", curr_movie
	variable /g space_width=1,time_width=1,movie_history_index=0,frame_num=0,frame_time=0,frame_rate=10,zMin=0,zMax=0,contrast_param=1
	make /o/t/n=0 MovieHistory=""
	make /o/n=1000 contrast_lookup
	setscale /I x,0,1,contrast_lookup
	contrast_lookup = x
	make /o/n=(1,2) CellCoords = nan
	svar /sdfr=df movie_mask
	SetDataFolder currDF
	string movies = MovieList()
	curr_movie = stringfromlist(0,movies)
	DrawMovieWindow()
	DrawMoviePanel()
End

function DrawMovieWindow()
	dfref df = MovieHome()
	dowindow /k MovieWin
	make /o/n=(256,256) df:current_image=gnoise(1)
	NewImage /N=MovieWin/K=1 df:current_image
	dowindow /t MovieWin,"Frame Viewer"
	variable width=500,height=500
	MoveWindow /w=MovieWin 200,200,200+width,200+height 
	if(wintype("CameraPanel"))	
		AutoPositionWindow /m=0/r=CameraPanel
	endif
	//ModifyImage current_image ctab= {*,*,Grays,0}
	//ModifyImage current_image lookup=df:contrast_lookup
	ModifyGraph mirror=2
	SetAxis /A left
	SetAxis /A top
	SetWindow MovieWin hook(click)=MovieClickHook//, hook=MovieHook, hookCursor=0, hookEvents=1,markerHook={MovieMarkerHook,0,30}
	//UpdateImageParams()
	//SetDrawLayer UserFront
	//SetDrawEnv translate= 0.473529,-0.088586,rotate= -11.841,rsabout
	//SetDrawEnv save
end

function DrawMoviePanel()
	string panelName = "MoviePanel"
	DoWindow /K $panelName
	NewPanel /K=1/N=$panelName /EXT=0 /HOST=MovieWin /W=(0,0,500,500) as "Movie Processing"
	dfref df = MovieHome()
		
	// Movie selection.  
	CheckBox AllImages,pos={3,4},size={20,15},proc=IMP_Checkboxes,title="All Images",value=1,mode=1
	CheckBox RawImages,pos={3,23},size={20,15},proc=IMP_Checkboxes,title="Raw Only",value=0,mode=1
	CheckBox FilteredImages,pos={3,42},size={20,15},proc=IMP_Checkboxes,title="Filtered Only",value=0,mode=1
	SetVariable ScrollMovie size={80,20}, pos={21,5}, bodyWidth=15, value=df:movie_history_index, title=" ", proc=IMP_SetVars
	SetVariable CurrMovie size={315,20}, pos+={-12,0}, variable=df:curr_movie, title=" "
	PopupMenu MovieList value=#"MovieList()", mode=0, size={20,20}, pos+={-6,-3}, bodyWidth=20, title=" ", proc=IMP_Popups
	SetVariable MovieMask size={150,20}, pos={85,25}, variable=df:movie_mask, title="Mask:",proc=IMP_SetVars
	TabControl Tabs tabLabel(0)="Visualization", tabLabel(1)="Processing",value=0, pos+={-10,5}, size={205,25}, proc=IMP_Tabs
	
	DrawVisualizationControls()
	DrawProcessingControls()
	DrawTimeline()
	
	Struct WMTabControlAction tab
	tab.win="MovieWin#"+panelName
	tab.ctrlName="Tabs"
	tab.eventCode=2
	IMP_Tabs(tab)
	
	SetWindow MovieWin#MoviePanel hook(click) = MoviePanelHook
	SetMovie()
end

function DrawProcessingControls()
	dfref df = MovieHome()

	// Filter buttons and settings.  
	String space_funcs=GetCases("MovieFilterSpace")+"Gauss;Median"
	String time_funcs=GetCases("MovieFilterTime")
	SetDrawEnv textxjust=1,save
	//Titlebox Spatial_Filters pos={30,77}, title="Spatial Filters", userData(tab)="Processing"
	//Titlebox Temporal_Filters pos={170,77}, title="Temporal Filters", userData(tab)="Processing"
	
	Variable i
	for(i=0;i<ItemsInList(space_funcs);i+=1)
		String space_func=StringFromList(i,space_funcs)
		Button $("S_"+space_func), title=space_func, pos={10,94+i*25}, size={100,20}, proc=IMP_Buttons, userData(tab)="Processing"
	endfor 
	SetVariable Space_Width pos={10,102+i*25}, size={80,20}, variable=df:space_width, title="Width: ", userData(tab)="Processing"
	GroupBox space_group pos={2,72}, size={115,52+25*i}, userData(tab)="Processing", title="Spatial Filters"
	
	for(i=0;i<ItemsInList(time_funcs);i+=1)
		String time_func=StringFromList(i,time_funcs)
		Button $("T_"+time_func), title=time_func, pos={160,94+i*25}, size={100,20}, proc=IMP_Buttons, userData(tab)="Processing"
	endfor
	SetVariable Time_Width pos={160,102+25*i}, size={80,20}, variable=df:time_width, title="Width: ", userData(tab)="Processing"
	GroupBox time_group pos={152,72}, size={115,52+25*i}, userData(tab)="Processing", title="Temporal Filters"
end

function DrawVisualizationControls()
	dfref df = MovieHome()
	
	variable xPos = 0 
	variable yPos = 71
	
	// Cell selection controls.
	GroupBox ROIs,pos={3,yPos},size={92,118},userData(tab)="Visualization",title="ROIs"
	Checkbox MoveCells pos={8,yPos+18}, mode=1, value=1, title="Move",proc=IMP_Checkboxes,userData(tab)="Visualization"
	Checkbox AddCells pos={8,yPos+45}, mode=1, title="Add",proc=IMP_Checkboxes,userData(tab)="Visualization"
	Button ClearCells pos={8,yPos+83}, size={40,20}, title="Clear", proc=IMP_Buttons,userData(tab)="Visualization"
	Checkbox ClearOne pos={53,yPos+75}, mode=1, title="One",proc=IMP_Checkboxes,userData(tab)="Visualization"
	Checkbox ClearAll pos={53,yPos+95}, mode=1, value=1, title="All",proc=IMP_Checkboxes,userData(tab)="Visualization"
	
	// Appearance Controls. 
	xPos = 97
	GroupBox Appearance,pos={xPos+5,yPos},size={369,118},userData(tab)="Visualization",title="Appearance"
	PopupMenu ColorTable,pos={xPos+11,yPos+18},size={200,21},proc=IMP_Popups,mode=1,popvalue="",value= #"\"*COLORTABLEPOP*\"",userData(tab)="Visualization"
	Checkbox ColorReverse,pos+={-4,2},proc=IMP_Checkboxes,value=0,title="Invert", userData(tab)="Visualization"
	TitleBox MinBrightnessTitle, frame=0, pos={xPos+11,yPos+49}, title="Min", userData(tab)="Visualization"
	Slider MinBrightness,pos+={-30,0},size={225,16},fSize=9,limits={0,65535,0},variable=df:zmin,bodyWidth= 70,vert=0,ticks=0,proc=IMP_Sliders,userData(tab)="Visualization"
	TitleBox MaxBrightnessTitle, frame=0, pos={xPos+11,yPos+69}, title="Max", userData(tab)="Visualization"
	Slider MaxBrightness,pos+={-30,0},size={225,16},title="Max",fSize=9,limits={0,65535,0},variable=df:zmax,bodyWidth= 70,vert=0,ticks=0,proc=IMP_Sliders,userData(tab)="Visualization"
	//Button ContrastSet,pos={8,251},size={50,16},proc=IMP_Buttons,title="Set",labelBack=(52224,52224,52224),userData(tab)="Visualization"
	Button Darker,pos={xPos+11,yPos+95},size={28,15},proc=IMP_Buttons,title="\\W623",labelBack=(52224,52224,52224),fSize=10,proc=IMP_Buttons,userData(tab)="Visualization"
	Button Brighter,pos+={-5,0},size={28,15},proc=IMP_Buttons,title="\\W617",labelBack=(52224,52224,52224),fSize=10,proc=IMP_Buttons,userData(tab)="Visualization"
	SetVariable ContrastParam,pos+={0,0},size={42,16},proc=IMP_SetVars,title=" ",limits={0,inf,0.1},value=df:contrast_param,userData(tab)="Visualization"
	PopupMenu ContrastPicker,pos+={-5,-2},size={73,21},proc=IMP_Popups,fSize=8,mode=3,popvalue="Linear",value="Linear;Gamma",userData(tab)="Visualization"
	PopupMenu ContrastPresets,pos+={-7,0},proc=IMP_Popups,mode=1,value=" ;Full Range;3-97%;2 SDs;2 IQRs",userData(tab)="Visualization"
	wave /sdfr=df contrast_lookup
	Display /N=ImageHist /HOST=MovieWin#MoviePanel /W=(0.744,0.178,0.935,0.368)
	appendtograph /l=left1 /b=bottom1 contrast_lookup
	make /o/n=100 df:image_hist /wave=image_hist=0
	appendtograph /l=right1 /t=top1 image_hist
	modifygraph nticks=0, nolabel=2,freepos={0.1,kwFraction},axThick=0,rgb=(0,0,0),lstyle(contrast_lookup)=1
	SetDrawLayer UserBack
	SetDrawLayer UserBack
	SetDrawEnv fillfgc= (61166,61166,61166)
	DrawRect -1,-1,2,2
	
	// Navigation Controls.  
	xPos = 0
	yPos = 203
	GroupBox Navigation,pos={xPos+5,yPos},size={466,64},userData(tab)="Visualization",title="Navigation"
	Button Backward,pos={xPos+12,yPos+16},size={25,20},proc=IMP_Buttons,title="\\W647",fSize=16,fStyle=1,userData(tab)="Visualization"
	Slider FrameSlider,pos+={-5,4},size={390,20},limits={0,100,1},variable=df:frame_num,side= 0,vert= 0,ticks= 0,thumbColor= (0,15872,65280),proc=IMP_Sliders,userData(tab)="Visualization"
	Button Forward,pos+={-4,-5},size={25,20},proc=IMP_Buttons,title="\\W650",fSize=16,fStyle=1,userData(tab)="Visualization"
	SetVariable FrameNum,pos={xPos+11,yPos+44},size={65,20},proc=IMP_SetVar,title="Frame",format="%g",limits={0,inf,0},value=df:frame_num,userData(tab)="Visualization"
	SetVariable FrameTime,pos+={0,0},size={65,20},proc=IMP_SetVar,title="Time",format="%.3f",limits={0,inf,0},value=df:frame_time,userData(tab)="Visualization"
	Button Play,pos+={0,0},size={60,18},proc=IMP_Buttons,title="\\W649",labelBack=(52224,52224,52224),fSize=12,fColor=(65535,65535,65535),userData(tab)="Visualization"
	Slider SpeedSlider,pos+={0,1},size={87,21},limits={1,60,1},variable=df:frame_rate,side= 0,vert= 0,ticks= 0,thumbColor= (0,15872,65280),proc=IMP_Sliders, title="Speed",userData(tab)="Visualization"
	SetVariable Speed,pos+={-5,-2},size={50,20},proc=IMP_SetVar,title="Hz",format="%g",limits={1,60,0},value=df:frame_rate,userData(tab)="Visualization"
end

function DrawTimeLine()
	Display /N=MovieTimeline /HOST=MovieWin#MoviePanel /W=(0.01,0.56,0.99,0.98) as "Movie Processing"
	dfref df = MovieHome()
	//wave /z/sdfr=df timeline
	//if(!waveexists(timeline))
	//	make /o/n=100 df:timeline /wave=timeline=0
	//endif
	//AppendToGraph /l=left1 /b=bottom1 timeline
	//Label left1 "Intensity"
	NewFreeAxis /l left1
	NewFreeAxis /b bottom1
	Label bottom1 "Frame #"
	NewFreeAxis /t top1
	Label top1 "Time (ms)"
	ModifyGraph lblPos=100,btLen=1,btlen(left1)=3,freePos(left1)={0,bottom1},freePos(bottom1)={0.05,kwFraction},axisEnab(left1)={0.05,0.85},freePos(top1)={0.15,kwFraction}
	ModifyGraph axisEnab(top1)={0.02,0.92}, axisEnab(bottom1)={0.02,0.92}
	UpdateTimeline()
end

function MoviePanelHook(hook)
	struct wmwinhookstruct &hook
	
	switch(hook.eventCode)
		case 5: // Mouse up.  
			if(hook.eventMod & 8)
				PopupContextualMenu /N "TimelineContextualMenu"
			endif
			break
	endswitch
end

menu "TimelineContextualMenu", contextualmenu
	"Save",/Q, TimelineSave()
	"Table",/Q,TimelineTable()
end

function TimelineSave()
	SavePICT /E=-7 /WIN=MovieWin#MoviePanel#MovieTimeline as "Timeline.tif"
end

function TimelineTable()
	dfref df = MovieHome()
	wave movie = CurrentMovie()
	wave /sdfr=df CellCoords
	variable num_frames = dimsize(movie,2)
	variable num_cells = numtype(sum(CellCoords))==2 ? 0 : dimsize(CellCoords,0)
	if(num_cells)
		make /o/n=(num_frames,num_cells) df:Timeline /wave=Timeline = movie[CellCoords[q][0]][CellCoords[q][1]][p]
		edit /k=1 Timeline as "Timeline"
	endif
end

function IMP_Tabs(tab)
	Struct WMTabControlAction &tab
	if(tab.eventCode>0)
		strswitch(tab.ctrlName)
			case "Tabs":
				controlinfo /w=$tab.win $tab.ctrlName
				string title = s_value
				string controls = ControlNameList(tab.win,";")
				variable i
				for(i=0;i<itemsinlist(controls);i+=1)
					string control = stringfromlist(i,controls)
					string group = getuserdata(tab.win,control,"tab")
					if(strlen(group))
						modifycontrol $control disable=!stringmatch(group,title), win=$tab.win
					endif	
				endfor
				break
		endswitch
	endif
end

function IMP_Checkboxes(cb)
	struct wmcheckboxaction &cb
	if(cb.eventCode !=2)
		return -1
	endif
	dfref df = MovieHome()
	strswitch(cb.ctrlName)
		case "AllImages":
		case "RawImages":
		case "FilteredImages":
			string image_options = ControlNameList("MovieWin#MoviePanel", ";", "*Images")
			variable i
			for(i=0;i<itemsinlist(image_options);i+=1)
				Checkbox $stringfromlist(i,image_options) value=0, win=MovieWin#MoviePanel
			endfor
			Checkbox $cb.ctrlName value=1, win=MovieWin#MoviePanel
			break
		case "ColorReverse":
			UpdateImageParams()
			break
		case "MoveCells":
			Checkbox AddCells value=0, win=MovieWin#MoviePanel
			setwindow MovieWin userData(addCells)="0"
			break
		case "AddCells":
			Checkbox MoveCells value=0, win=MovieWin#MoviePanel
			setwindow MovieWin userData(addCells)="1"
			wave /z/sdfr=df CellCoords
			if(!waveexists(CellCoords))
				make /o/n=(1,2) df:CellCoords=nan
			endif
			break
		case "ClearOne":
			Checkbox ClearAll value=0, win=MovieWin#MoviePanel
			break
		case "ClearAll":
			Checkbox ClearOne value=0, win=MovieWin#MoviePanel
			break
	endswitch
end

Function IMP_Popups(pop)
	STRUCT WMPopupAction &pop
	if(pop.eventCode !=2)
		return 0
	endif
	dfref df = MovieHome()
	strswitch(pop.ctrlName)
		case "ColorTable":
			UpdateImageParams()
			break
		case "MovieList":
			svar /sdfr=df curr_movie
			curr_movie=pop.popStr
			SetMovie()
		case "ContrastPresets":
			UpdatePanel()
			break
	endswitch
End

Function IMP_SetVars(set)
	Struct WMSetVariableAction &set
	if(set.eventCode !=2 && set.eventCode !=1)
		return 0
	endif
	dfref df = MovieHome()
	strswitch(set.ctrlName)
		case "MovieMask":
			svar /sdfr=df movies
			movies=WaveList(set.sval,";","MINLAYERS:2")
			break
		case "ScrollMovie":
			wave /t/sdfr=df MovieHistory
			svar /sdfr=df curr_movie
			nvar /sdfr=df movie_history_index
			if(movie_history_index>=numpnts(MovieHistory))
				movie_history_index=numpnts(MovieHistory)-1
			endif
			if(movie_history_index<0)
				movie_history_index=0
			endif
			curr_movie=MovieHistory[set.dval]
			SetMovie()
			break
		case "ContrastParam":
			nvar /sdfr=df contrast_param
			if(abs(contrast_param)<1e-5) // Fix a floating point bug in SetVariable controls.  
				contrast_param = 0
			endif
			UpdateImageParams()
			break
	endswitch
End

Function IMP_Buttons(but)
	Struct WMButtonAction &but
	if(but.eventCode!=2)
		return 0
	endif
	dfref df=MovieHome()
	wave movie = CurrentMovie()
	variable num_frames = dimsize(movie,2)
	variable bright_dark_step = 0.05
	ControlInfo /W=MovieWin#MoviePanel Tabs
	switch(v_value) // Number of the current tab.  
		case 0: // Visualizaton.
			nvar /sdfr=df frame_num,zmin,zmax
			svar /sdfr=df curr_movie
			strswitch(but.ctrlName)
				case "Backward":
					frame_num=limit(frame_num-1,0,num_frames-1)
					UpdateFrame()
					break
				case "Forward":
					frame_num=limit(frame_num+1,0,num_frames-1)
					UpdateFrame()
					break	
				case "Play":
					Play_Movie()
					break
				case "Brighter":
					wavestats /q movie
					zmin = limit(zmin+bright_dark_step*(v_max-v_min),zmin,v_max)
					zmax = limit(zmax+bright_dark_step*(v_max-v_min),zmin,v_max)
					UpdateImageParams()
					break
				case "Darker":
					wavestats /q movie
					zmin = limit(zmin-bright_dark_step*(v_max-v_min),v_min,zmax)
					zmax = limit(zmax-bright_dark_step*(v_max-v_min),v_min,zmax)
					UpdateImageParams()
					break
				case "ClearCells":
					wave /z/sdfr=df CellCoords
					if(waveexists(CellCoords))
						variable numCells = numtype(sum(cellCoords))==2 ? 0 : dimsize(CellCoords,0)
						ControlInfo /W=MovieWin#MoviePanel ClearAll			
						if(numCells==1 || v_value) // If there is only 1 cell or if "All" is selected.  
							redimension /n=(1,2) CellCoords
							CellCoords=nan
							variable i
							for(i=0;i<10;i+=1)
								string csr_name = num2char(97+i) 
								if(strlen(CsrInfo($csr_name,"MovieWin")))
									Cursor /W=MovieWin /K $csr_name
								endif
								string trace_name
								sprintf trace_name,"%s",csr_name// (%d,%d)",csr_name,x,y
								removefromgraph /z/w=MovieWin#MoviePanel#MovieTimeLine $csr_name
							endfor
							Legend /K/N=cell_legend
						elseif(numCells>1)
							redimension /n=(numCells-1,2) cellCoords
							csr_name = num2char(97+numCells-1) 
							if(strlen(CsrInfo($csr_name,"MovieWin")))
								Cursor /W=MovieWin /K $csr_name
							endif
							sprintf trace_name,"%s",csr_name// (%d,%d)",csr_name,x,y
							removefromgraph /z/w=MovieWin#MoviePanel#MovieTimeLine $csr_name
						endif
					endif
				endswitch
			break
		case 1: // Processing.
			string dimension=num2char(but.ctrlName[0]) // "S" for space and "T" for time.  
			string filter=but.ctrlName
			filter=filter[2,strlen(filter)-1]
			strswitch(dimension)
				case "S":
					NVar /sdfr=df width=space_width
					String new_movie=MovieFilterSpace(movie,filter,width)
					break
				case "T":
					NVar /sdfr=df width=time_width
					new_movie=MovieFilterTime(movie,filter,width)
					break
			endswitch
			wave movie = $new_movie
			UpdateMovieHistory(movie)
			SetMovie()
			break
	endswitch
End

function IMP_Sliders(sl)
	struct wmslideraction &sl
	if(sl.eventCode > 0 && sl.eventCode & 1)
		dfref df = MovieHome()
		strswitch(sl.ctrlName)
			case "FrameSlider":
				UpdateFrame()
				break
			case "MovieSpeed":
				break
			case "MinBrightness":
			case "MaxBrightness":
				UpdateImageParams()
				PopupMenu ContrastPresets mode=1, win=$sl.win
				break
		endswitch
	endif
end

function MovieHook(hook)
	string hook
end

function MovieClickHook(hook)
	struct wmwinhookstruct &hook
	
	switch(hook.eventCode)
		case 5: // Mouse up.  
			variable canAddCells = str2num(GetUserData("MovieWin","","addCells"))
			if(canAddCells)
				dfref df = MovieHome()
				wave movie = CurrentMovie()
				wave /sdfr=df current_image
				variable x=round(AxisValFromPixel("","top",hook.mouseLoc.h))+0 // Avoids the negative zero problem.  
				variable y=round(AxisValFromPixel("","left",hook.mouseLoc.v))+0
				variable rows=dimsize(current_image,0)
				variable cols=dimsize(current_image,1)
				if(y>=0 && y<rows && x>=0 && x<cols)
					wave /sdfr=df CellCoords
					variable numCells = numtype(sum(cellCoords))==2 ? 0 : dimsize(CellCoords,0)
					if(numCells<10)
						CellCoords[numCells]={{x},{y}}
						string csr_name = num2char(65+numCells)
						Cursor /I/H=1/L=1/S=1 $csr_name,current_image,x,y
						ColorTab2Wave rainbow
						wave m_colors
						setscale x,0,10,m_colors
						variable red = m_colors(numCells)(0), green = m_colors(numCells)(1), blue = m_colors(numCells)(2)
						string trace_name
						sprintf trace_name,"%s",csr_name// (%d,%d)",csr_name,x,y
						AppendToGraph /w=MovieWin#MoviePanel#MovieTimeline /c=(red,green,blue) /l=left1 /t=top1 movie[x][y][] /tn=$trace_name
						Legend /W=MovieWin#MoviePanel#MovieTimeline /C/N=cell_legend/F=0/T=1/A=RC/X=-5.00/Y=0.00
					endif
				else
					SetWindow MovieWin userData(addCells)="0"
				endif
			else
				UpdateTimeline()
			endif
			break
	endswitch
end

function MovieMarkerHook(hook)
	struct wmmarkerhookstruct &hook
	
end

function /s MovieList()
	dfref df=MovieHome()
	svar /sdfr=df movie_mask
	controlinfo /w=MovieWin#MoviePanel AllImages; variable all=v_value
	controlinfo /w=MovieWin#MoviePanel RawImages; variable raw=v_value
	controlinfo /w=MovieWin#MoviePanel FilteredImages; variable filtered=v_value
	
	string movie_list = ""
	dfref df = CameraHome(create=0)
	if(datafolderrefstatus(df))
		movie_list += "Camera;-----;"
	endif
	dfref imageDF=ImageHome()
	string list = wavelist2(df=imageDF,match=movie_mask,minDims={0,0,1})
	if(strlen(list))
		movie_list += list+"----;"
	endif
	if(!datafolderrefsequal(imageDF,GetDataFolderDFR()))
		list = wavelist2(match=movie_mask,fullPath=1,minDims={0,0,1})
		if(strlen(list))
			movie_list += list+"----;"
		endif
	endif
	if(raw)
		movie_list = removefromlist2("*__*",movie_list)
	elseif(filtered)
		movie_list = listmatch("*__*",movie_list)
	endif
	
	return movie_list
end

function SetMovie()
	UpdateFrame()
	UpdatePanel()
	UpdateTimeline()
end

static function Show(movie_name)
	string movie_name
	
	dfref df=MovieHome()
	svar /sdfr=df curr_movie
	curr_movie=movie_name
	SetMovie()
end

function /wave CurrentMovie()
	dfref df=MovieHome()
	svar /sdfr=df curr_movie
	if(stringmatch(curr_movie,"Camera"))
		dfref camera = CameraHome()
		wave /z movie = camera:current_movie
	else
		dfref df = ImageHome()
		wave /z/sdfr=df movie = $curr_movie
		if(!waveexists(movie))
			wave /z movie = $curr_movie
		endif
	endif
	if(!waveexists(movie))
		string alert
		sprintf alert,"Couldn't find movie %s",curr_movie
		//DoAlert 0,alert
	endif
	return movie
end

static function UpdateFrame()
	dfref df=MovieHome()
	wave /z movie = CurrentMovie()
	if(waveexists(movie))
		nvar /sdfr=df frame_num,frame_time
		wave /sdfr=df current_image,image_hist
		matrixop /o current_image = layer(movie,frame_num)	
		frame_time = dimoffset(movie,2) + frame_num*dimdelta(movie,2)
		wavestats /q/m=1 movie
		setscale x,v_min,v_max,image_hist 
		histogram /b=2/p current_image,image_hist
		string traces = tracenamelist("MovieWin#MoviePanel#MovieTimeline",";",1)
		if(strlen(traces))
			string trace = stringfromlist(0,traces)
			Cursor /W=MovieWin#MoviePanel#MovieTimeline A,$trace,frame_time
		endif
		variable error = 0
	else
		error = 1
	endif
	return error
end

static function UpdatePanel()
	dfref df = MovieHome()
	wave /z movie = CurrentMovie()
	if(waveexists(movie))
		nvar /sdfr=df zmin,zmax
		variable num_frames = dimsize(movie,2)
		wavestats /q movie
		if(v_min==0 && v_max==0)
			v_max=65535
		endif
		string win = "MovieWin#MoviePanel"
		ControlInfo /w=$win ContrastPresets
		strswitch(s_value)
			case "Full Range":
				zmin=v_min
				zmax=v_max
				break
			case "3-97%":
				zmin=v_min+(v_max-v_min)*0.03
				zmax=v_min+(v_max-v_min)*0.97
				break
			case "2 SDs":
				zmin = limit(v_avg - 2*v_sdev,v_min,v_max)
				zmax = limit(v_avg + 2*v_sdev,v_min,v_max)
				break
			case "2 IQRs":
				wave /sdfr=df current_image // We are only going to compute quartiles on the current image to save time.  
				statsquantiles /q/box current_image
				zmin = limit(v_median - v_iqr,v_min,v_max)
				zmax = limit(v_median + v_iqr,v_min,v_max)
				break
			case " ":  
				if(zmin == zmax)
					zmin = v_min
					zmax = v_max
				endif
				break
		endswitch
		Slider FrameSlider limits={0,num_frames-1,1}, win=$win
		Slider MinBrightness limits={v_min,v_max,0}, win=$win
		Slider MaxBrightness limits={v_min,v_max,0}, win=$win
		UpdateImageParams()
	endif
end

function UpdateImageParams()
	dfref df = MovieHome()
	string win = "MovieWin"
	string panel = win+"#MoviePanel"
	controlinfo /w=$panel ColorTable; string color_table = s_value
	controlinfo /w=$panel ColorReverse; variable color_reverse = v_value
	nvar /sdfr=df zmin,zmax,contrast_param
	controlinfo /w=$panel ContrastPicker
	wave /sdfr=df contrast_lookup
	strswitch(s_value)
		case "Linear":
			contrast_lookup = x
			break
		case "Gamma":		
			contrast_lookup = x^(1/contrast_param)
			break
	endswitch
	wave /z movie = CurrentMovie()
	if(waveexists(movie))
		wavestats /q movie
		variable range = (v_max-v_min)/(zmax-zmin)
		if(range>1)
			setaxis /w=$(panel+"#ImageHist") bottom1 0-(range-1)*(zmin-v_min)/(zmin-v_min+v_max-zmax),1+(range-1)*(v_max-zmax)/(zmin-v_min+v_max-zmax)
		else
			setaxis /w=$(panel+"#ImageHist") bottom1 0,1
		endif
		ModifyImage /w=$win current_image ctab={zmin,zmax,$color_table,color_reverse},lookup=contrast_lookup
	endif
end

function UpdateTimeline()
	string win = "MovieWin#MoviePanel#MovieTimeline"
	wave /z movie = CurrentMovie()
	if(waveexists(movie))
		variable num_frames = dimsize(movie,2)
		wavestats /q movie
		setaxis /w=$win left1 v_min,v_max
		setaxis /w=$win /a bottom1 0,num_frames-1
		setaxis /w=$win /a top1 dimoffset(movie,2),dimoffset(movie,2)+num_frames*dimdelta(movie,2)
		dfref df = MovieHome()
		wave /sdfr=df CellCoords
		variable i
		for(i=0;i<dimsize(CellCoords,0);i+=1)
			if(numtype(CellCoords[i][0])==0)
				string csr_name = num2char(65+i)
				string csr_info = csrinfo($csr_name,"MovieWin")
				variable x = numberbykey("POINT",csr_info)
				variable y = numberbykey("YPOINT",csr_info)
				if(CellCoords[i][0] != x || CellCoords[i][1] != y)
					CellCoords[i][0] = x
					CellCoords[i][1] = y
					string trace_name
					sprintf trace_name,"%s",csr_name// (%d,%d)",csr_name,x,y
					replacewave /w=$win trace=$trace_name movie[x][y][]
				endif
			endif
		endfor
	else
		setaxis /w=$win /a bottom1 0,100
		setaxis /w=$win /a top1 0,1000
	endif
end

function Play_Movie()
	dfref df=MovieHome()
	nvar /sdfr=df frame_rate
	ctrlnamedbackground Play proc=PlayMovieBkg, period=60/frame_rate, start
end

function PlayMovieBkg(bkg)
	struct wmbackgroundstruct &bkg
	
	dfref df=MovieHome()
	nvar /sdfr=df frame_num
	wave movie = CurrentMovie()
	variable num_frames = dimsize(movie,2)
	if(frame_num<num_frames-1)
		frame_num+=1
		return UpdateFrame()
	else
		frame_num=0
		UpdateFrame()
		return -1
	endif
end

function UpdateMovieHistory(movie)
	wave movie
	dfref df=MovieHome()
	svar /sdfr=df curr_movie
	wave /t/sdfr=df MovieHistory
	if(!StringMatch(MovieHistory[0],curr_movie))
		InsertPoints 0,1,MovieHistory
		MovieHistory[0]=curr_movie
	endif
	InsertPoints 0,1,MovieHistory
	string new_movie = nameofwave(movie)
	MovieHistory[0]=new_movie
	curr_movie=new_movie
	nvar /sdfr=df movie_history_index
	movie_history_index=0
end

function /wave FloatMovie(m)
	wave m
	if(wavetype(m) & 2 || wavetype(m) & 4)
		return m
	else
		duplicate /free m,float_m
		redimension /s float_m
		note /nocr float_m nameofwave(m)
		return float_m
	endif
end

//Function StuffToDo()
//	String files=filez//"17April2008_slice2;march18_file2_RT;slice1;slice2;17April2008"//;file1_RT"
//	BatchPreprocess()
//	Variable i
//	NewPath /O/Q DataDir,spon_data_dir
//	String movies=AddPrefix(ListExpand("1,20"),"MV")
//	for(i=1;i<ItemsInList(files);i+=1)
//		String file=StringFromList(i,files)
//		LoadData /D/J=movies spon_data_dir+file
//		//if(i==1) // Get rid of this unless there are movies of different spatial sampling sizes in the same file.  
//		//	ResampleMovies(AddPrefix(ListExpand("8,12"),"MV"),4/3,4/3)
//		//endif
//		//StupidRename()
//		SVDMovies()
//		SVDFrames()
//		MinimumProjections()
//		Minimum2Projection()
//		KillWaves2(match="Ar1stim15s*")
//		SaveExperiment /P=DataDir as file+"_An.pxp"
//		SetDataFolder root:
//		//KillWaves /Z/A
//	endfor
//	KillPath /Z DataDir
//End

//Function BatchTimeCourses()
//	Variable i
//	String files=filez//"17April2008_slice2;march18_file2_RT;slice1;slice2;17April2008;file1_RT"
//	String prefixes=prefixez//"fura;fura(RT);fura;fura(RT);fura(RT);fura"
//	String ranges=movie_rangez//"1,5;1,5;1,5;1,5;1,5;,"
//	SetDataFolder root:
//	NewPath /O/Q ExperimentFolder, spon_data_dir
//	for(i=0;i<ItemsInList(files);i+=1)
//		String file=StringFromList(i,files)
//		String prefix=StringFromList(i,prefixes)
//		String range=StringFromList(i,ranges)
//		LoadRawMovieData(file,"",prefix,range,"",";")
//		TimeCourses(file)
//	endfor
//	//SaveExperiment
//End

Function TimeCourses(name)
	String name
	Variable j
	String movie_list=WaveList("Ar1stim15s*",";","")
	for(j=0;j<ItemsInList(movie_list);j+=1)
		String movie_name=StringFromList(j,movie_list)
		MovieOverTime($movie_name); Wave MOverTime
		Concatenate {MOverTime},$("TimeCourse_"+CleanupName(name,0))
		KillWaves $movie_name,MOverTime
	endfor
End

//// Preprocess experiment files (normalize and detrend) and save copies for later analysis.  
//// This takes a long time and should be run overnight.  
//Function BatchPreprocess()
//	Variable i
//	String files=filez//"17April2008_slice2;march18_file2_RT;slice1;slice2;17April2008"//;file1_RT"
//	String prefixes=prefixez//"fura;fura(RT);fura;fura(RT);fura(RT)"//;fura"
//	String movie_ranges=movie_rangez//"1,25;1,12;1,32;1,50;1,34"//;,"
//	String frame_ranges=frame_rangez//"2,174;1,174;1,174;1,174;2,174"
//	SetDataFolder root:
//	NewPath /O/Q ExperimentFolder, spon_data_dir
//	for(i=1;i<ItemsInList(files);i+=1) // Set back to i=0
//		String file=StringFromList(i,files)
//		String prefix=StringFromList(i,prefixes)
//		String movie_range=StringFromList(i,movie_ranges)
//		String frame_range=StringFromList(i,frame_ranges)
//		NormalizeDetrendAll(file,"",prefix,movie_range,"",";",suffix="",frame_range=frame_range)
//		SaveExperiment /P=ExperimentFolder as file+"DT.pxp"
//		KillWaves /Z/A
//	endfor
//End

Function StupidRename()
	String wave_list=WaveList("M*",";","")
	Variable i
	for(i=0;i<ItemsInList(wave_list);i+=1)
		Wave Movie=$StringFromList(i,wave_list)
		Rename $NameOfWave(Movie),$ReplaceString("M",NameOfWave(Movie),"MV")
		//Rename $NameOfWave(Movie),$ReplaceString("suffix",NameOfWave(Movie),"")
	endfor
End

// Loads the movies from the original experiment files, downsampling as needed to conserve memory.  
Function /S LoadRawMovieData(exp_name,sub_folder,session_prefix,sessions,movie_prefix,movies[,directory])
	String exp_name // Experiment name.  
	String sub_folder // Subfolder withing the experiment file to look for movies.  
	String session_prefix,sessions
	String movie_prefix,movies
	String directory
	if(ParamIsDefault(directory))
		directory=SpecialDirPath("Desktop",0,0,0)//spon_data_dir
	endif
	
	Variable i,j
	NewPath /O/Q ExperimentFolder, directory
	sessions=ListExpand(sessions)
	movies=ListExpand(movies)
	String wave_list=""
	for(i=0;i<ItemsInList(sessions);i+=1)
		for(j=0;j<ItemsInList(movies);j+=1)
			wave_list+=session_prefix+StringFromList(i,sessions)+movie_prefix+StringFromList(j,movies)+";"
		endfor
	endfor
	NewDataFolder /O/S root:TempLoad
	LoadData /O/Q/P=ExperimentFolder /S=sub_folder /J=wave_list exp_name+".pxp"
	String movies_loaded=""
	i=0
	Do
		Wave /Z Loaded=$GetIndexedObjName("",1,i)
		if(waveexists(Loaded) && WaveType(Loaded))
			Redimension /D Loaded
			// Set this scan information
			Variable session_num,movie_num
			if(strlen(movie_prefix))
				sscanf NameOfWave(Loaded),session_prefix+"%d"+movie_prefix+"%d",session_num,movie_num
				String new_movie_name="MV"+num2str(session_num)+num2str(movie_num)
			else
				sscanf NameOfWave(Loaded),session_prefix+"%d",session_num
				new_movie_name="MV"+num2str(session_num)
			endif
			Duplicate /o Loaded root:$new_movie_name
			movies_loaded+=new_movie_name+";"
			KillWaves /Z Loaded
		endif
	While(i<CountObjects("",1))
	KillDataFolder root:TempLoad
	return movies_loaded
End

Function NormalizeDetrendAll(file_name,folder_name,prefix1,range1,prefix2,range2[,suffix,frame_range])
	String file_name,folder_name,prefix1,range1,prefix2,range2,suffix,frame_range
	if(ParamIsDefault(suffix))
		suffix="ND"
	endif
	if(ParamIsDefault(frame_range))
		frame_range="0,200"
	endif
	Variable i,j
	range1=ListExpand(range1)
	range2=ListExpand(range2)
	//NewPath /O/C/Q filePath, spon_data_dir+file_name+":"
	for(i=0;i<ItemsInList(range1);i+=1)
		String r1=StringFromList(i,range1)
		LoadRawMovieData(file_name,folder_name,prefix1,r1,prefix2,range2)
		for(j=0;j<ItemsInList(range2);j+=1)
			String r2=StringFromList(j,range2)
			String name="MV"+r1+r2
			Wave /Z TempMov=$name
			if(waveexists(TempMov))
				Variable first=str2num(StringFromList(0,frame_range,","))
				Variable last=str2num(StringFromList(1,frame_range,","))
				Duplicate /o/R=[][][first,last] TempMov, $"Mov"; Wave Mov=$"Mov"
				KillWaves /Z TempMov
				Wave Mov2=$MovieFilterTime(Mov,"Normalize",0); KillWaves /Z Mov
				Wave Mov3=$MovieFilterTime(Mov2,"Detrend",0); KillWaves /Z Mov2
				String new_name=name+suffix
				Duplicate /o Mov3 $new_name
				//KillWaves /Z Mov2,Mov3,TempMov
				Save /O/P=filePath $new_name as new_name+".ibw"
				KillWaves /Z $new_name // Comment this out if you want to save a normalized, detrended .pxp file.  
			endif
		endfor
	endfor
	KillPath /Z filePath
End

// Uses MatrixFilter on each plane, with the specified 'type' of filtering.  
Function /S MovieFilterSpace(mov,type,width)
	wave mov
	string type
	variable width
	
	if(width==0)
		String new_movie_name=NameOfWave(Mov)+"__"+type[0,2]+"S"
	else
		new_movie_name=NameOfWave(Mov)+"__"+type[0,2]+"S"+num2str(width)
	endif
	Duplicate /o FloatMovie(mov) $new_movie_name
	Wave NewMov=$new_movie_name
	Variable i,j,frames=dimsize(Mov,2)
	Make /o/n=(frames) FrameRecord=NaN
	Try
		for(i=0;i<frames;i+=1)
			ImageTransform /P=(i) getPlane, Mov
			Wave M_ImagePlane
			strswitch(type)
				case "Average": // Subtract the mean of the entire frame.  
					WaveStats /Q M_ImagePlane
					M_ImagePlane-=V_avg
					FrameRecord[i]=V_avg
					break
				case "Peak": // Subtract the location of the peak of a Gaussian fit
					//WaveStats /Q M_ImagePlane
					//M_ImagePlane-=V_avg
					Histogram /B={0.9,0.0001,2000} M_ImagePlane Hist_Rick // Change histogram bins if needed.  
					Variable V_FitOptions=4
					CurveFit/Q/M=2/W=0 gauss, Hist_Rick[0,1999]/D
					M_ImagePlane-=K2
					FrameRecord[i]=K2
					break
				case "Mode": // Subtract the mode (peak of a smoothed histogram).  
					Histogram /B={0.9,0.0001,2000} M_ImagePlane Hist_Rick // Change histogram bins if needed.
					Smooth 100,Hist_Rick
					WaveStats /Q Hist_Rick
					M_ImagePlane-=V_maxloc
					FrameRecord[i]=V_maxloc
					break
				default:
					MatrixFilter /N=(width) $type M_ImagePlane
					break
			endswitch
			ImageTransform /P=(i) /D=M_ImagePlane setPlane, NewMov
			//ProgWin(i,frames,"MovieFilterSpace: "+type)
		endfor
	Catch
	EndTry
	KillWaves /Z M_ImagePlane
	return new_movie_name
End

Function /S MovieFilterTime(mov,type,width)
	wave mov
	string type
	variable width
	
	if(width==0)
		String new_movie_name=NameOfWave(Mov)+"__"+type[0,2]+"T"
	else
		new_movie_name=NameOfWave(Mov)+"__"+type[0,2]+"T"+num2str(width)
	endif
	Duplicate /o FloatMovie(mov) $new_movie_name
	Wave NewMov=$new_movie_name
	Variable i,j,rows=dimsize(Mov,0),cols=dimsize(Mov,1)
	Try
		for(i=0;i<rows;i+=1)
			for(j=0;j<cols;j+=1)
				ImageTransform /Beam={(i),(j)} getBeam, NewMov
				Wave W_Beam
				strswitch(type)
					case "Mode": // Subtract the mode (peak of a smoothed histogram).  
						Histogram /B={0.9,0.001,200} W_Beam Hist_Rick // Change histogram bins if needed.
						Smooth width,Hist_Rick
						WaveStats /Q Hist_Rick
						W_Beam-=V_maxloc
						break
					case "Median":
						Smooth /M=0 width,W_Beam
						break
					case "Detrend":
						DSPDetrend /F=line W_Beam; Wave W_Detrend
						W_Beam=W_Detrend						
						break
					case "Normalize":
						WaveStats /Q W_Beam
						W_Beam/=V_avg
					case "DFF":
						wavestats /q/r=[0,width-1] W_Beam
						w_beam = (w_beam-v_avg)/v_avg
						break
				endswitch
				ImageTransform /Beam={(i),(j)} /D=W_Beam setBeam, NewMov
			endfor
			//ProgWin(i,rows,"MovieFilterTime: "+type)
		endfor
	Catch
	EndTry
	strswitch(type)
		case "Delete":
			deletepoints /M=2 0,width,NewMov
			break
	endswitch
	KillWaves /Z W_Beam,W_Detrend,W_Sigma
	return new_movie_name
End

Function SerialRandomnessMovie(Movie)
	Wave Movie
	String curr_func=GetRTStackInfo(1)
	Variable i,j,rows=dimsize(Movie,0),cols=dimsize(Movie,1),frames=dimsize(Movie,2)
	Make /o/n=(rows,cols) SR_Frame=NaN
	Try
		for(i=0;i<rows;i+=1)
			for(j=0;j<cols;j+=1)
				ImageTransform /Beam={(i),(j)} getBeam, Movie
				StatsSRTest /Q/P W_Beam; Wave W_StatsSRTest
				if(frames>150) // StatsSRTest reports different values for different size input waves.   
					Variable critical=W_StatsSRTest[4]
					Variable p=1-StatsNormalCDF(critical,0,1)
				else
					p=W_StatsSRTest[5]
				endif
				SR_Frame[i][j]=log(p)
			endfor
			//ProgWin(i,rows,curr_func)
		endfor
	Catch
	EndTry
	KillWaves /Z W_Beam
End

Function TestSR()
	Make /o/n=50000 TestSRWave=NaN
	Variable i
	for(i=0;i<numpnts(TestSRWave);i+=1)
		Make /o/n=170 Crap=gnoise(1)
		StatsSRTest /Q/P Crap; Wave W_StatsSRTest
		TestSRWave[i]=W_StatsSRTest[3]
	endfor
	Sort TestSRWave,TestSRWave
	SetScale x,0,1,TestSRWave
End

Function PValImage(Mov)
	Wave Mov
	Variable xbar=0.00012535,stdev=0.0028242
	Duplicate /o Mov,NewMov
	NewMov=StatsNormalCDF(Mov,xbar,stdev)
End

Function MovieOverTime(Mov)
	Wave Mov
	Variable frames=dimsize(Mov,2)
	Make /o/n=(frames) MOverTime
	Variable i,rows=dimsize(Mov,0),cols=dimsize(Mov,1)
	for(i=0;i<dimsize(Mov,2);i+=1)
		ImageTransform /P=(i) sumPlane Mov
		MOverTime[i]=V_Value
	endfor
	MOverTime/=(rows*cols)
End

Function MoviesOverTime(stem,list)
	String stem,list
	list=ListExpand(list)
	Variable i,movies=ItemsInList(list)
	Variable frames=170
	Make /o/n=(frames) MsOverTime=0
	Make /o/n=(movies) MovieRecord=NaN
	Make /o/n=0 AvgOverTime
	Variable failures=0
	for(i=0;i<movies;i+=1)
		Wave Movie=$(stem+StringFromList(i,list))
		MovieOverTime(Movie)
		Wave MOverTime
		WaveStats /Q MOverTime; Variable baseline=V_avg
		MovieRecord[i]=baseline
		//MsOverTime+=MOverTime
		DSPDetrend /Q/F=dblexp MOverTime; Wave W_Detrend
		if(V_flag) // If exponential detrend failed.  
			DSPDetrend /F=line MOverTime; Wave W_Detrend
			failures+=1
		else
			MsOverTime+=W_Detrend
		endif
		W_Detrend/=baseline
		Concatenate /NP {MOverTime}, AvgOverTime
	endfor
	MsOverTime/=(movies-failures)
End

Function MovieFreqs(stem,list)
	String stem,list
	list=ListExpand(list)
	Variable i,movies=ItemsInList(list)
	Variable frames=170
	Make /o/n=(movies) MovieRecord=NaN
	Make /o/n=0 AvgOverTime
	Variable failures=0
	for(i=0;i<movies;i+=1)
		Wave Movie=$(stem+StringFromList(i,list))
		MovieOverTime(Movie)
		FFT /MAG /DEST=FFTD MOverTime
		if(i==0)
			Duplicate /o FFTD FFTDAvg
		else
			FFTDAvg+=FFTD
		endif
	endfor
	FFTDAvg/=movies
End

Function PixelOverTime(Movie[,x,y])
	Wave Movie; Variable x,y
	x=ParamIsDefault(x) ? xcsr(A) : x
	y=ParamIsDefault(y) ? vcsr(A) : y
	ImageTransform /Beam={(x),(y)} getBeam, Movie
	//Display /K=1 W_Beam
End

Function SVDFrames([frame])
	Variable frame
	frame=ParamIsDefault(frame) ? 0 : frame
	String wave_list=WaveList("M_U*",";","")
	Variable i,num
	for(i=0;i<ItemsInList(wave_list);i+=1)
		Wave M_U=$StringFromList(i,wave_list)
		sscanf NameOfWave(M_U),"M_U%d",num
		String best_frame="Frame"+num2str(num)
		MatrixOp /O $best_frame=col(M_U,frame)
		Redimension /n=(128,128) $best_frame
	endfor
End

Function MinimumProjections([stem])
	String stem
	if(ParamIsDefault(stem))
		stem="Ar1stim15s*"
	endif
	String wave_list=WaveList(stem,";","TEXT:0,MINLAYERS:2")
	Variable i,num
	//ProgWinOpen()
	for(i=0;i<ItemsInList(wave_list);i+=1)
		Wave Movie=$StringFromList(i,wave_list)
		sscanf NameOfWave(Movie),"Ar1stim15s%d",num
		ImageTransform /METH=3 zProjection Movie
		Duplicate /o M_zProjection $(NameOfWave(Movie)+"_Min")
		//ProgWin(i/ItemsInList(wave_list),0)
	endfor
	
	KillWaves /Z M_zProjection
End

// A minimum projection for the whole experiment.  
Function Minimum2Projection()
	String wave_list=WaveList("Minimum*",";","")
	Variable i
	for(i=0;i<ItemsInList(wave_list);i+=1)
		Wave Minimum=$StringFromList(i,wave_list)
		Duplicate /o Minimum, TempM2P
		MatrixFilter /N=3 median, Minimum
		if(i==0)
			Concatenate /O {Minimum}, MinProjMov
		else
			Concatenate {Minimum}, MinProjMov
		endif
		Minimum=TempM2P
		//Make /o/D/n=(128,128,0) MovieOfSVDs=0
		//ImageTransform /O/P=(new_frames) /INSW=Frame insertZPlane, MovieOfSVDs
	endfor
	ImageTransform /METH=3 zProjection MinProjMov
	Duplicate /o M_zProjection MinProj
	KillWaves /Z M_zProjection,MinProjMov,TempM2P
End

Function SVDMovie(Movie)
	Wave Movie
	Wave Matrix=$RedimMovie(Movie)	
	MatrixSVD /O/U=1/V=1 Matrix
	KillWaves /Z Matrix
End

Function ExtractSVDFrameAndTime(M_U,M_VT,num)
	Wave M_U,M_VT
	Variable num
	MatrixOp /O $("Frame"+num2str(num))=col(M_U,num)
	Redimension /n=(128,128) $("Frame"+num2str(num))
	MatrixOp /O $("TimeCourse"+num2str(num))=row(M_VT,num)
	Wave TimeCourse=$("TimeCourse"+num2str(num))
	Redimension /n=(numpnts(TimeCourse)) TimeCourse
End

Function UnSVDMovie(M_U,W_S,M_VT[,keep])
	Wave M_U,W_S,M_VT
	Variable keep // Number of eigenvalues to keep.  
	Duplicate /o W_S, W_S_Backup
	if(!ParamIsDefault(keep))
		W_S[keep,Inf]=0
	endif
	MatrixOp /O UnSVD=M_U x Diagonal(W_S) x M_VT
	Wave Unredim=$UnredimMovie(UnSVD,dimsize(M_VT,0),dimsize(M_VT,1)) // I know this will always give a square matrix.  
	KillWaves UnSVD
	Rename Unredim, UnSVD
	W_S=W_S_Backup
	KillWaves /Z W_S_Backup
End

Function AverageBestFrames()
	Variable i
	String frame_list=WaveList("BestFrame*",";","")
	Variable flip
	for(i=0;i<ItemsInList(frame_list);i+=1)
		String frame_name=StringFromList(i,frame_list)
		Wave Frame=$frame_name
		if(i==0)
			Duplicate /o Frame AvgFrame
			if(mean(Frame)<0)
				AvgFrame*=-1
			endif
			Concatenate /O {Frame}, Frames
		else
			if(mean(Frame)<0)
				AvgFrame-=Frame
			else
				AvgFrame+=Frame
			endif
			Concatenate {Frame}, Frames
		endif	
	endfor
	AvgFrame/=i
End

// Redimensions a movie (3D) into a 2D Matrix
Function /S RedimMovie(Movie)
	Wave Movie
	Variable rows=dimsize(Movie,0),cols=dimsize(Movie,1),frames=dimsize(Movie,2)
	String matrix_name=NameOfWave(Movie)+"_redim"
	Make /o/n=(rows*cols,frames) $matrix_name; Wave Matrix=$matrix_name
	Variable i
	for(i=0;i<frames;i+=1)
		ImageTransform /P=(i) getPlane Movie; Wave M_ImagePlane
		Redimension /n=(rows*cols) M_ImagePlane
		Matrix[][i]=M_ImagePlane[p]
	endfor
	KillWaves /Z M_ImagePlane
	return GetWavesDataFolder(Matrix,2)
End

// Undoes the redimensioning of RedimMovie, turning a matrix (2D) back into a movie (3D).  
Function /S UnredimMovie(Matrix,rows,cols)
	Wave Matrix
	Variable rows,cols
	Variable frames=dimsize(Matrix,1)
	String movie_name=NameOfWave(Matrix)+"_unredim"
	Make /o/n=(rows,cols,frames) $movie_name; Wave Movie=$movie_name
	Variable i
	for(i=0;i<frames;i+=1)
		MatrixOp /O OneFrame=col(Matrix,i)
		Redimension /n=(rows,cols) OneFrame
		ImageTransform /P=(i) /D=OneFrame setPlane Movie
	endfor
	KillWaves /Z OneFrame
	return GetWavesDataFolder(Movie,2)
End

// Remaps the pixel values of the top image on a graph so that the current low displayed value is 0, the high displayed values 
// is 65535, and values in between are linearly interpolated.  Used to prepare an image for RGB overlay.  
Function Graphs2RGB(graph_names,dest_name[,flip])
	String graph_names // Semi-colon separated list of names of three graphs.  Leave an entry blank to skip a color.  
	String dest_name // Name of the destination RGB 3-plane color image.  
	Variable flip // Flip white and black on any of the channels.  Bit 0 for red, 1 for green, and 2 for blue.  
	
	Make /o/n=(0,0,3) $dest_name=0; Wave RGBImage=$dest_name
	Variable i
	for(i=0;i<ItemsInList(graph_names);i+=1)
		String graph=StringFromList(i,graph_names)
		String top_image=StringFromList(0,ImageNameList(graph,";"))
		Wave /Z OneImage=ImageNameToWaveRef(graph,top_image)
		if(!strlen(WinList(graph,";","WIN:1")) || !WaveExists(OneImage))
			continue
		endif
		Variable rows=dimsize(OneImage,0),cols=dimsize(OneImage,1)
		Redimension /n=(rows,cols,3) RGBImage
		
		String ctab_info=StringByKey("RECREATION",ImageInfo(graph,top_image,0),":",";")
		ctab_info=StringByKey("ctab",ctab_info,"=",";")
		sscanf ctab_info," {%s}",ctab_info
		String low_str=StringFromList(0,ctab_info,",")
		String high_str=StringFromList(1,ctab_info,",")
		
		if(GrepString(low_str,"\*") || GrepString(high_str,"\*"))
			WaveStats /Q $top_image
			Variable low=V_min,high=V_max
		endif
		if(!GrepString(low_str,"\*"))
			low=str2num(low_str)
		endif
		if(!GrepString(high_str,"\*"))
			high=str2num(high_str)
		endif
		if(flip & 2^i)
			RGBImage[][][i]=65535*(high-OneImage[p][q])/(high-low)
		else
			RGBImage[][][i]=65535*(OneImage[p][q]-low)/(high-low)
		endif
		RGBImage=RGBImage < 0 ? 0 : RGBImage
		RGBImage=RGBImage > 65535 ? 65535 : RGBImage
	endfor
End

Function MinMaxMovie(num)
	Variable num
	Wave Movie=$("Rick"+num2str(num))
	ImageTransform /METH=1 zProjection Movie; Duplicate /o M_ZProjection MaxVal; 
	ImageTransform /METH=2 zProjection Movie; Duplicate /o M_ZProjection AvgVal; 
	ImageTransform /METH=3 zProjection Movie; Duplicate /o M_ZProjection MinVal
End

Function LayoutFrames(stem,range[,cols])
	String stem,range
	Variable cols
	cols=ParamIsDefault(cols) ? 4 : cols
	range=ListExpand(range)
	Preferences 1
	NewLayout /K=1/N=$(stem)
	String layout_name=WinName(0,4)
	Variable i,num_frames=0
	Variable frames=ItemsInList(range),row=0,col=0
	Variable frame_num=0
	for(i=0;i<frames;i+=1)
		String frame_name=stem+StringFromList(i,range)
		if(exists(frame_name))
			num_frames+=1
		endif
	endfor
	Variable rows=ceil(num_frames/cols)
	
	STRUCT frect margins; GetMargins(layout_name,margins)
	for(i=0;i<frames;i+=1)
		frame_name=stem+StringFromList(i,range)
		if(exists(frame_name))
			String sub_win=layout_name+"#G"+num2str(frame_num)
			NewImage /HOST=$layout_name /K=1 $frame_name
			Label top frame_name
			Variable top=row/rows,left=col/cols,bottom=(row+1)/rows,right=(col+1)/cols
			Adapt2Margins(margins,left,top,right,bottom)
			MoveSubWindow /W=$sub_win fnum=(left,top,right,bottom)
			if(mean($frame_name)<0)
				ModifyImage /W=$sub_win $frame_name ctab= {*,*,Grays,1}
			endif
			col+=1
			if(col>=cols)
				col=0
				row+=1
			endif
			frame_num+=1
		endif
	endfor
End

// Sets a structure with the locations of the margins as a fraction of the window size.  
Function GetMargins(win,margins)
	String win; STRUCT frect &margins
	GetWindow $win logicalprintablesize
	margins.top=V_top
	margins.left=V_left
	margins.right=V_right
	margins.bottom=V_bottom
	GetWindow $win logicalpapersize
	margins.top/=V_bottom
	margins.left/=V_right
	margins.right/=V_right
	margins.bottom/=V_bottom
End

Structure fRect
	float top
	float left
	float bottom
	float right
EndStructure

Structure fPoint
	float v
	float h
EndStructure

// Adapts a fractional coordinate to be relative to the printable area.  
Function Adapt2Margins(margins,left,top,right,bottom)
	STRUCT frect &margins
	Variable &left,&top,&right,&bottom
	left=margins.left+(margins.right-margins.left)*left
	right=margins.left+(margins.right-margins.left)*right
	top=margins.top+(margins.bottom-margins.top)*top
	bottom=margins.top+(margins.bottom-margins.top)*bottom
End

Function CompareDebleachRates()
	Variable i,j,k
	Make /o/n=(1,1,0) DebleachRates=0
	String movies="5"
	movies=ListExpand(movies)
	Variable num_movies=ItemsInList(movies)
	Try
		for(k=0;k<num_movies;k+=1)
			Variable movie_num=str2num(StringFromList(k,movies))
			Wave Movie=$("Rick"+num2str(movie_num))
			Variable rows=dimsize(Movie,0), cols=dimsize(Movie,1), frames=dimsize(Movie,2)
			Redimension /n=(rows,cols,num_movies) DebleachRates
			for(i=0;i<rows;i+=1)
				for(j=0;j<cols;j+=1)
					ImageTransform /Beam={(i),(j)} getBeam, Movie
					Wave W_Beam
					Variable V_fitOptions=4
					CurveFit /Q line, W_Beam
					DebleachRates[i][j][k]=K1
				endfor
				//ProgWin(i+k*rows,rows*num_movies,"CompareDebleachRates")
			endfor
		endfor
	Catch
		
	EndTry
	
End

Function ContrastProjection(Movie)
	Wave Movie
	ImageTransform /METH=1 zProjection Movie
	Duplicate /o M_ZProjection ContrastFrame
	ImageTransform /METH=3 zProjection Movie
	Wave M_ZProjection
	ContrastFrame-=M_ZProjection
End

Function ConcatDetrend(num)
	Variable num
	Variable i
	Make /O/n=0 MsOverTime
	for(i=0;i<10;i+=1)
		Wave Movie=$("MV"+num2str(num)+num2str(i))
		MovieOverTime(Movie)
		Wave MOverTime
		DSPDetrend /F=line MOverTime
		Concatenate /NP {W_Detrend}, MsOverTime
	endfor
End

Function Concats(num)
	Variable num
	Make /O/n=0 MsOverTime
	Variable i
	for(i=0;i<10;i+=1)
		Wave /Z Movie=$("MV"+num2str(num)+num2str(i))
		if(WaveExists(Movie))
			MovieOverTime(Movie)
			Wave MOverTime
			Concatenate /NP {MOverTime}, MsOverTime
		endif
	endfor
End

Function SVDMovies([sing_values])
	Variable sing_values // The number of eigenvectors to keep.  
	sing_values=ParamIsDefault(sing_values) ? 10 : sing_values
	Variable i,j
	String movies=WaveList("Ar1stim15s*",";","MINLAYERS:2")
	for(i=0;i<ItemsInList(movies);i+=1)
		Wave Movie=$StringFromList(i,movies)
		String movie_name
		sscanf NameOfWave(movie),"MV%[0-9]",movie_name
		//ProgWin(i,ItemsInList(movies),movie_name)
		Redimension /D Movie
		SVDMovie(Movie)
		Duplicate /o/R=[][0,sing_values-1] M_U $("M_U"+movie_name)
		Duplicate /o/R=[0,sing_values-1][] M_VT $("M_VT"+movie_name)
		Duplicate /o W_W $("W_W"+movie_name)
		KillWaves /Z M_U,M_VT,W_W//,Movie
	endfor
End

Function MakeMovieOfSVDs()
	String frame_sets=WaveList("M_U*",";","")
	frame_sets=RemoveFromList("M_U",frame_sets)
	Variable i,new_frames=0
	Make /o/D/n=(128,128,0) MovieOfSVDs=0
	for(i=0;i<ItemsInList(frame_sets);i+=1)
		String frame_set=StringFromList(i,frame_sets)
		String singular_name
		sscanf frame_set,"M_U%[0-9]",singular_name
		Wave W_W=$("W_W"+singular_name)
		MatrixOp /O W_WSquared=magsqr(W_W)
		Variable explained=W_WSquared[0]/sum(W_WSquared)
		KillWaves /Z W_WSquared
		if(explained>0.03) // More than 3% of the explained variance in the first eigenframe, i.e. not a movie of noise.  
			Wave FrameSet=$frame_set
			MatrixOp /o Frame=col(FrameSet,0)
			Redimension /D/n=(128,128) Frame
			if(mean(Frame)<0)
				Frame*=-1
			endif
			ImageTransform /O/P=(new_frames) /INSW=Frame insertZPlane, MovieOfSVDs
			new_frames+=1
		endif
	endfor
	SVDMovie(MovieOfSVDs)
End

Function CellTimeCourses([width,height])
	Variable width,height 
	// The size of the box around each pixel that will be used for averaging.  
	// [1,1] includes only the pixel in question. These values should be odd.  
	width=ParamIsDefault(width) ? 1 : width
	height=ParamIsDefault(height) ? 1 : height
	Wave CellLocs
	Variable i,j,h,v
	//NormalizeDetrendAll()
	//SaveExperiment
	String movie_list=WaveList("Ar1stim15s15_DFF*",";","MINLAYERS:2")
	movie_list=SortList(movie_list,";",16)
	printf "%d Movies; %d Cells",ItemsInList(movie_list),dimsize(CellLocs,0)
	for(i=0;i<ItemsInList(movie_list);i+=1)
		String movie_name=StringFromList(i,movie_list)
		Wave Movie=$movie_name
		for(j=0;j<dimsize(CellLocs,0);j+=1)
			Variable x=CellLocs[j][0]
			Variable y=CellLocs[j][1]
			String name=movie_name+"_"+num2str(x)+"_"+num2str(y)
			Make /o/n=0 $name=NaN
			Wave Cell=$name
			Make /o/D/n=(dimsize(Movie,2)) Beam_=0
			//Average of a 'width' x 'height' area.  
			//Faster than using ImageTransform for averaging because I only need a few areas.  
			for(h=(-width+1);h<width;h+=1)
				for(v=(-height+1);v<height;v+=1)
					ImageTransform /BEAM={(x+h),(y+v)} getBeam Movie
					Wave W_Beam
					Beam_+=W_Beam
				endfor
			endfor
			Beam_/=1
			Concatenate /NP {Beam_},Cell
		endfor
	endfor
End

Function CellCorrelation([prefix])
	String prefix
	if(ParamIsDefault(prefix))
		prefix="Cell_"
	endif
	String cell_list=WaveList(prefix+"*",";","")
	KillWaves /Z CellMatrix
	Make /o/n=(1,ItemsInList(cell_list)) CellMatrix
	Variable i
	for(i=0;i<ItemsInList(cell_list);i+=1)
		Wave Cell=$StringFromList(i,cell_list)
		Redimension /n=(numpnts(Cell),-1) CellMatrix
		CellMatrix[][i]=Cell[p]	
	endfor
	//Concatenate /O cell_list,CellMatrix
	MatrixOp /O Corr_Matrix=syncCorrelation(CellMatrix)
	MatrixOp /o Corr_Var=varcols(CellMatrix)
	Corr_Matrix/=(sqrt(Corr_Var[0][q]*Corr_Var[0][p]))
	KillWaves /Z Corr_Var
End

//Function CorrelationClustering(num_patterns,Corr_Matrix)
//	Variable num_patterns // Number of patterns that you expect to find.  
//	Wave Corr_Matrix // The correlation (or covariance) matrix.  
//	KMeans /INIT=1 /SEED=(ticks) /NCLS=(num_patterns) /OUT=2 Corr_Matrix // K-Means clustering.  
//	Duplicate /o Corr_Matrix Clustered_Matrix // Prepared the clustered correlation matrix.  
//	Duplicate /o W_KMMembers Sorting_Index; Sorting_Index=p
//	Sort W_KMMembers,Sorting_Index // Create a sorting index to use to swap out rows (and columns).  
//	Clustered_Matrix=Corr_Matrix[Sorting_Index[p]][Sorting_Index[q]] // Shuffle rows (and columns).  
//	Wave /Z Waterfall_Colors
//	if(WaveExists(Waterfall_Colors))
//		Wave W_KMMembers // The pattern number that each signal most represents (the K-Means clustering result).  
//		Waterfall_Colors=W_KMMembers[q] // Color the waterfall plot according to the clustering result.  
//	endif
//	KillWaves /Z M_KMClasses,W_KMMembers // Cleanup.  
//End

Function DisplayCells([prefix])
	String prefix
	if(ParamIsDefault(prefix))
		prefix="Cell_"
	endif
	String cell_list=WaveList(prefix+"*",";","")
	Display /K=1
	Variable i
	for(i=0;i<ItemsInList(cell_list);i+=1)
		String cell_name=StringFromList(i,cell_list)
		Wave Cell=$cell_name
		AppendToGraph Cell
		ModifyGraph offset($NameOfWave(Cell))={0,0.1*i}
	endfor
End

Function PhysicalDvsSVDD()
	String cell_list=WaveList("Cell_*",";","")
	Wave M_VT
	Variable i,j
	Make /o/n=(ItemsInList(cell_list),ItemsInList(cell_list)) PhysicalD=NaN,SVDD=NaN
	Make /o/n=(128,128,3) ColoredCells=NaN
	Make /o/n=(128,128,1) SignalCells=0
	for(i=0;i<ItemsInList(cell_list);i+=1)
		String cell_name=StringFromList(i,cell_list)
		Variable x,y
		sscanf cell_name, "Cell_%d_%d",x,y
		ColoredCells[x-1,x+1][y-1,y+1][]=M_VT[r][i]
		for(j=i;j<ItemsInList(cell_list);j+=1)
			String cell_name2=StringFromList(j,cell_list)
			Variable x2,y2
			sscanf cell_name2, "Cell_%d_%d",x2,y2
			PhysicalD[i][j]=sqrt((x2-x)^2 + (y2-y)^2)
			SVDD[i][j]=sqrt((M_VT[0][i]-M_VT[0][j])^2 + (M_VT[1][i]-M_VT[1][j])^2 +(M_VT[2][i]-M_VT[2][j])^2)
		endfor
		Wave FCell=$("FCell_"+num2str(x)+"_"+num2str(y))
		SignalCells[x-1,x+1][y-1,y+1]=sum(FCell)+(log(0.5)*numpnts(FCell))//StatsMedian(Cell)-mean(Cell)
	endfor
	for(i=0;i<3;i+=1)
		ImageStats /P=(i) ColoredCells
		ColoredCells[][][i]=65535*(V_max-ColoredCells[p][q][i])/(V_max-V_min)
	endfor
	Redimension /n=(numpnts(PhysicalD)) PhysicalD,SVDD
End

Function FilterTimeCourses([method])
	String method
	String cell_list=WaveList("Cell_*",";","")
	Variable i; 
	if(ParamIsDefault(method))
		method=""
	endif
	for(i=0;i<ItemsInList(cell_list);i+=1)
		String cell_name=StringFromList(i,cell_list)
		Wave Cell=$cell_name
		FilterTimeCourse(Cell,method)
	endfor
End

Function FilterTimeCourse(theWave,method)
	Wave theWave; String method
	String new_name="F"+NameOfWave(theWave)
	Duplicate /o theWave $new_name
	Wave Filtered=$new_name
	strswitch(method)
		case "ZScore":
			DSPDetrend /F=line /Q Filtered; Wave W_Detrend
			Filtered=W_Detrend
			WaveStats /Q Filtered
			Filtered=-log(StatsNormalCDF(Filtered,V_avg,V_sdev))
			break
		default:
			DSPDetrend /F=line /Q Filtered; Wave W_Detrend
			Filtered=W_Detrend
			break
	endswitch
	KillWaves /Z W_Detrend
End

Function BrowseMovie(Movie)
	Wave Movie
	ImageTransform /P=0 getPlane Movie
	Duplicate /O M_ImagePlane,MovieFrame
	KillWaves /Z M_ImagePlane
	NewImage MovieFrame
	ControlBar /T 35

	String wave_list=WaveList("*",";","MINLAYERS:2")
#if str2num(StringByKey("IGORVERS",IgorInfo(0)))>6.03
	SetVariable frame_num, value=_NUM:0, limits={0,dimsize(Movie,2)-1,1}, proc=ChangeMovieFrame
#endif
	Variable index=WhichListItem(NameOfWave(Movie),wave_list)
	PopupMenu movie_name, value=WaveList("*",";","MINLAYERS:2"), proc=ChangeMovie
	SetWindow kwTopWin userdata(MovieName)=GetWavesDataFolder(Movie,2)
	WaveStats /Q Movie
	ModifyImage MovieFrame ctab= {V_min,V_max,Grays,0}
End

Function ChangeMovieFrame(set) : SetVariableControl
	STRUCT WMSetVariableAction &set
	if(set.eventCode!=1)
		return 0
	endif
	Variable frame_num=set.dval
	String movie_name=GetUserData("","","MovieName")
	ImageTransform /P=(frame_num) getPlane $movie_name
	Duplicate /O M_ImagePlane,MovieFrame
	KillWaves /Z M_ImagePlane
End

Function ChangeMovie(pop) : PopupMenuControl
	STRUCT WMPopupAction &pop
	if(pop.eventCode!=2)
		return 0
	endif
	String movie_name=pop.popStr
	Wave /Z Movie=$movie_name
	if(waveexists(Movie))
		SetWindow kwTopWin userdata(MovieName)=GetWavesDataFolder(Movie,2)
		ControlInfo frame_num
		Variable frame_num=V_Value
		ImageTransform /P=(frame_num) getPlane Movie
		Duplicate /O M_ImagePlane,MovieFrame
		KillWaves /Z M_ImagePlane
		WaveStats /Q Movie
		ModifyImage MovieFrame ctab= {V_min,V_max,Grays,0}
	endif
End

Function ChangeJasonMovieNames(session_name,movie_name)
	String session_name,movie_name
	String movies=WaveList(session_name+"*",";","")
	movies=SortList(movies,";",16)
	Variable i,index=0
	for(i=0;i<ItemsInList(movies);i+=1)
		String movie=StringFromList(i,movies)
		if(StringMatch(movie,"*DFF"))
			continue
		endif
		Variable session,num
		sscanf movie,session_name+"%d"+movie_name+"%d",session,num
		Duplicate /o $movie root:$("fura2"+num2str(index))
		KillWaves /Z $movie
		index+=1
	endfor
End

// Change the size of each movie frame.   
Function /S ResampleMovie(Movie,x,y)
	Wave Movie
	Variable x,y // Resampling factors.  Greater than 1 is a bigger movie.  
	Variable i
	Make /o/n=(dimsize(Movie,0)*x,dimsize(Movie,1)*y,dimsize(Movie,2)) $(NameOfWave(Movie)+"_RS")
	Wave Resampled=$(NameOfWave(Movie)+"_RS")
	for(i=0;i<dimsize(Resampled,2);i+=1)
		ImageTransform /P=(i) getPlane Movie; Wave M_ImagePlane
		//WaveStats /Q M_ImagePlane; Variable minn=V_min
		//M_ImagePlane-=(minn) // Make all values >=0 so that ImageInterpolate works.  
		//ImageInterpolate /TRNS={scaleShift,0,x,0,y} Resample M_ImagePlane; Wave M_InterpolatedImage
		//M_InterpolatedImage+=(minn)
		Resampled[][][i]=Interp2D(M_ImagePlane,p/x,q/y)
		//ImageTransform /P=(i) /D=M_InterpolatedImage setPlane Resampled
	endfor
	//KillWaves /Z M_ImagePlane,M_InterpolatedImage
	return GetWavesDataFolder(Resampled,2)
End

Function ResampleMovies(movie_list,x,y)
	String movie_list
	Variable x,y
	Variable i
	for(i=0;i<ItemsInList(movie_list);i+=1)
		String movie_name=StringFromList(i,movie_list)
		Wave Movie=$movie_name
		Wave Resampled=$ResampleMovie(Movie,x,y)
		Duplicate /o Resampled $movie_name
		KillWaves /Z Resampled
	endfor
End

Function WaveNameChange(match,this,that)
	String match,this,that
	String waves=WaveList(match,";","")
	Variable i
	for(i=0;i<ItemsInList(waves);i+=1)
		String wave_name=StringFromList(i,waves)
		if(!StringMatch(wave_name,match))
			continue
		endif
		Rename $wave_name $ReplaceString(this,wave_name,that)
	endfor
End

// Make traces evenly spaced.  
Function OffsetStack(offset[,win])
	Variable offset; String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace=StringFromList(i,traces)
		ModifyGraph offset($trace)={0,i*offset}
	endfor
End


