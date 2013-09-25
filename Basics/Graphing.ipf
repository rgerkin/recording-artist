
// $Author: rick $
// $Rev: 633 $
// $Date: 2013-03-28 15:53:22 -0700 (Thu, 28 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.

Menu "Graph"
	"Save Graph Settings",/Q,SaveProfileMacro(WinName(0,1))
	"Load Graph Settings",/Q,LoadProfileMacro(WinName(0,1))
	SubMenu "Rebuild Graph..."
		"Sweeps Window",SweepsWindow()
		"Analysis Window",AnalysisWindow()
	End
End

Menu "TracePopup"
	SubMenu "Copy"
		"Trace Location" ,/Q,TraceLoc(0)
		"Trace X-Wave Location",/Q,TraceLoc(2)
		"All Trace Locations",/Q,TraceLoc(1)
	End
	SubMenu "Trace Stats"
		//selectstring(GraphStatsOn(),"Activate Graph Stats",""),/Q,ActivateGraphStats()
		"This Trace",/Q,GetLastUserMenuInfo;WaveStat2(TraceNameToWaveRef("",S_tracename))
		"Group Mean",/Q,GetLastUserMenuInfo;DisplayMeanTrace(keyTrace=s_tracename)
		"Group Mean+-SEM",/Q,GetLastUserMenuInfo;DisplayMeanTrace(keyTrace=s_tracename,error="SEM")
		"Group Median",/Q,GetLastUserMenuInfo;DisplayMeanTrace(keyTrace=s_tracename,type="med")
		"Group Median+-SEM*",/Q,GetLastUserMenuInfo;DisplayMeanTrace(keyTrace=s_tracename,type="med",error="SEM")
		"T-test",/Q,StatsTTest /T=1 $TraceNum(0,reversi=1), $TraceNum(1,reversi=1)
		"Mann-Whitney U-test",/Q,StatsWilcoxonRankTest /T=1/APRX=1 $TraceNum(0,reversi=1), $TraceNum(1,reversi=1)
		"KS-test",/Q,StatsKSTest /T=1 $TraceNum(0,reversi=1), $TraceNum(1,reversi=1)
	End
	SubMenu "Decoration"
		"Scale Bar",/Q,ScaleBarPrompt()
		"Toggle Axis Visibility",/Q,HideAxes(hide=-1)
	End
	"Snap",/Q,Snap()
	//"Region Stats",/Q,GetLastUserMenuInfo;WaveStat(theWave=TraceNameToWaveRef("",S_tracename))
	//"Copy Region",/Q,GetLastUserMenuInfo;Duplicate /o /R=(xcsr(A),xcsr(B)) TraceNameToWaveRef("",S_tracename), WaveRegion
	//"Mean Wave",/Q,DisplayMeanTrace()
End

function Snap()
	string win = WinName(0,1)
	string new_win = CloneWindow(win=win,replace="/K=2",with="/K=1")
	variable i
	
	string controls = ControlNameList(new_win) 
	for(i=0;i<itemsinlist(controls);i+=1)
		string control = stringfromlist(i,controls)
		KillControl $control
	endfor
	
	string annotations = AnnotationList(new_win)
	for(i=0;i<itemsinlist(annotations);i+=1)
		string annotation = stringfromlist(i,annotations)
		Textbox /K/N=$annotation
	endfor
	
	ControlBar /L 0
	ControlBar /R 0
	ControlBar /T 0
	ControlBar /B 0
	
	string title
	prompt title,""
	doprompt "Enter Window Title",title
	if(v_flag)
		title = "Window "+num2str(floor(abs(enoise(10000))))
	endif
	DoWindow /T $new_win title
end

function /s FindFig(match)
	string match
	
	match=replacestring("*",match,"")
	string wins=winlist("*",";",""),list=""
	variable i
	for(i=0;i<itemsinlist(wins);i+=1)
		string win=stringfromlist(i,wins)
		string rec=winrecreation(win,0)
		if(stringmatch(rec,"*"+match+"*"))
			list+=win+";"
		endif
	endfor
	return list
end

function GraphStatsOn()
	variable result=0
	string win=winname(0,1)
	GetWindow $win hook(mouseDown)
	if(strlen(s_value))
		result=1
	endif
	return result
end

function ActivateGraphStats()
	string win=winname(0,1)
	SetWindow $win hook(mouseDown)=MouseDownHook
end

function MouseDownHook(info)
	struct WMWinHookStruct &info
	
	strswitch(info.eventName)
		case "mousedown":
			string str
			structput /s info.mouseLoc str
			SetWindow $info.winName userData(mouseDown)=str
			break
	endswitch
end

function ScaleBarPrompt()
	variable xx,yy,xMult=1,yMult=1,fSize=9
	string xUnits,yUnits,xAxis,yAxis
	prompt xx,"X range"
	prompt yy,"Y range"
	prompt xUnits,"X units"
	prompt yUnits,"Y units"
	prompt xMult,"X unit multiplier"
	prompt yMult,"Y unit multiplier"
	prompt xAxis,"X axis",popup,AxisList2("horizontal")
	prompt yAxis,"X axis",popup,AxisList2("vertical")
	prompt fSize,"Font size"
	doprompt "Scale Bar Parameters",xx,yy,xUnits,yUnits,xMult,yMult,xAxis,yAxis,fSize
	if(!v_flag)
		ScaleBar(xx,yy,xunits,yunits,xMult=xMult,yMult=yMult,x_axis=xAxis,y_axis=yAxis,font_size=fSize)
		HideAxes()
	endif
end

Menu "AllTracesPopup"
End

Menu "Layout"
	"Clone Layout" ,/Q,CloneWindowWithReplacement()
	"Copy Window Recreation Macro",/Q,CopyWinRecreation()
	"Send Graphs to Back",/Q,SendGraphs2Back()
	"Letter Figure Panels",/Q,LetterFigurePanels()
End

function NiceLayout(rows,cols[,win])
	variable rows,cols
	string win
	
	win=selectstring(!paramisdefault(win),winname(0,4),win)
	variable i=0,j,k,d
	//string info=LayoutInfo("","Layout")
	//string page=stringbykey("PAGE",info)
	//variable left,right,top,bottom
	//sscanf page,"%f,%f,%f,%f",left,top,right,bottom
	//variable xsize=right-left, ysize=bottom-top
	string types="Graph;Textbox"
	make /free/t/n=(itemsinlist(types)) items=""
	
	// Make lists of the various items in the layout.  
	do
		string info=LayoutInfo(win,num2str(i))
		string type=stringbykey("TYPE",info)
		string name=stringbykey("NAME",info)
		variable typeNum=whichlistitem(type,types)
		if(typeNum>=0)
			items[typeNum]+=name+";"
		endif
		i+=1
	while(strlen(info))
	
	// Go through these lists.  
	for(i=0;i<itemsinlist(types);i+=1)
		type=stringfromlist(i,types)
		if(itemsinlist(items[i])<2)
			continue
		endif
		make /free/n=(1,itemsinlist(items[i]),1) yy=numberbykey("TOP",layoutinfo(win,stringfromlist(q,items[i])))
		string dimensions="xx;yy"
		for(d=0;d<itemsinlist(dimensions);d+=1)
			string dimension=stringfromlist(d,dimensions)
			strswitch(dimension)
				case "xx":
					string lefttop="LEFT"
					string widthheight="WIDTH"
					variable classes=cols+1
					break
				case "yy":
					lefttop="TOP"
					widthheight="HEIGHT"
					classes=rows+1
					break
			endswitch
			make /free/n=(1,itemsinlist(items[i]),1) locs=numberbykey(lefttop,layoutinfo(win,stringfromlist(q,items[i])))	
			variable minDispersion=Inf
			make /free/I/n=(itemsinlist(items[i])) membership=0
			for(j=0;j<100;j+=1)
				KMeans /CAN /NCLS=(classes) /OUT=2 /SEED=(abs(enoise(1000))) locs
				wave w_kmmembers,W_KMDispersion
				if(sum(w_kmdispersion)<minDispersion)
					membership=w_kmmembers
					minDispersion=sum(w_kmdispersion)
				endif
			endfor
			for(j=0;j<=wavemax(w_kmmembers);j+=1)
				extract /free/indx membership,members,membership==j
				variable leftTopNum=0, widthHeightNum=0
				for(k=0;k<numpnts(members);k+=1)
					leftTopNum+=numberbykey(leftTop,layoutinfo(win,stringfromlist(members[k],items[i])))
					widthHeightNum+=numberbykey(widthHeight,layoutinfo(win,stringfromlist(members[k],items[i])))
				endfor
				leftTopNum/=numpnts(members)
				widthHeightNum/=numpnts(members)
				for(k=0;k<numpnts(members);k+=1)
					name=stringfromlist(members[k],items[i])
					strswitch(dimension)
						case "xx":
							modifylayout /w=$win left($name)=leftTopNum, width($name)=widthHeightNum
							break
						case "yy":
							modifylayout /w=$win top($name)=leftTopNum, height($name)=widthHeightNum
							break
					endswitch
				endfor
			endfor
		endfor
	endfor
	killwaves /z w_kmmembers,W_KMDispersion
end

function TitleWin(title[,win])
	string title,win
	
	win=selectstring(!paramisdefault(win),winname(0,4167),win)
	dowindow /t $win,title
end

// Like MoveWindow, but takes coordinates in pixels (which matched NewPanel behavior) instead of in points (which is used for Display, etc.).  
Function MovePanel(panel,coords)
	String panel
	STRUCT rect &coords
	Variable factor=ScreenResolution/72
	if(WinType(panel)==7)
		MoveWindow /W=$panel coords.left/factor,coords.top/factor,coords.right/factor,coords.bottom/factor
	endif
End

Function SaveGraph([win])
	string win
	
	win=selectstring(!paramisdefault(win),winname(0,1),win)
	string name=win
	prompt name,"Name: "
	doprompt "Save Graph",name
	if (V_Flag)
		return -1								// User canceled
	endif
	newpath /o/q desktop specialdirpath("desktop",0,0,0)
	SaveGraphCopy /O /P=desktop /W=$win as name+".pxp"
	string ext=".png"
	SavePICT /E=-5 /O /P=desktop /Q=1 /WIN=$win as name+ext
End

Function Retitle(title,[win])
	string title,win 
	
	win=selectstring(paramisdefault(win),win,winname(0,127))
	dowindow /t $win title
End

function /s VisibleControls([win,match])
	string win,match
	
	match=selectstring(!paramisdefault(match),"*",match)
	win=selectstring(!paramisdefault(win),winname(0,65),win)
	string controls=ControlNameList(win,";",match)
	variable i
	string list=""
	for(i=0;i<itemsinlist(controls);i+=1)
		string control=stringfromlist(i,controls)
		controlinfo /w=$win $control
		if(v_disable==0)
			list=AddListItem(control,list)
		endif
	endfor
	return list
end

//#if IgorVersion()>=6.2
Function ArmenErrorBars([win,suffix,match])
	string win,suffix,match
	
	win=selectstring(paramisdefault(win),win,winname(0,1))
	suffix=selectstring(paramisdefault(suffix),suffix,"sem")
	match=selectstring(paramisdefault(match),match,"*")
	
	string traces=tracenamelist(win,";",3)
	variable i,j,k,flag
	for(i=0;i<itemsinlist(traces);i+=1)
		flag=0
		string trace=stringfromlist(i,traces)
		if(stringmatch(trace,"*_armen"))
			continue
		endif
		if(!stringmatch(trace,match))
			continue
		endif
		wave w=tracenametowaveref(win,trace)
		dfref df=getwavesdatafolderdfr(w)
		string folder=getwavesdatafolder(w,1)
		string name=nameofwave(w)
		j=strlen(name)
		do
			make /free/t/n=0 names
			names[0]={folder+name+suffix}
			names[1]={folder+name+"_"+suffix}
			names[2]={folder+removeending("mean",name)+suffix}
			names[3]={folder+removeending("med",name)+suffix}
			for(k=0;k<numpnts(names);k+=1)
				//do
					string shorterName=names[k]
					wave /z error=$shorterName
				//	names[k]=shorterName[0,strlen(shorterName)-2]
				//while(strlen(names[k])>31)
				if(waveexists(error))
					flag=1
					break
				endif
			endfor
			if(flag)
				break
			endif
			name=name[0,strlen(name)-2]
			j-=1
		while(j>0)
		if(flag)
			variable length=strlen(trace)
			do
				string armen=trace[0,length-1]+"_armen"
				if(strlen(armen)>31)
					length-=1
				else
					break
				endif
			while(1)
			removefromgraph /w=$win/z $armen
			variable red,green,blue
			TraceColour(win,trace,red,green,blue)
			appendtograph /w=$win /c=(red,green,blue) w /tn=$armen
			AppendUserData(win,"metaTraces",armen)
			ErrorBars/L=2/Y=1 /w=$win $armen Y,wave=(error,error)
			modifygraph /w=$win rgb($armen)=((65535+red)/2,(65535+green)/2,(65535+blue)/2)
			modifygraph /w=$win lsize($armen)=1,lsize($trace)=3
			ReorderTraces /W=$win $trace, {$armen, $trace} 
		endif
	endfor
End
//#endif

// Makes shaded error bars, given a data wave and a wave containing e.g. standard errors.  
Function ShadedErrorBars(Data[,Error,kind,append_])
	wave Data,Error
	string kind
	variable append_
	
 	kind = selectstring(!paramisdefault(kind),"sem",kind)
	string dataName=GetWavesDataFolder(Data,2)
	string add_quote = ""
	if(stringmatch(dataName,"*'"))
		dataName = removeending(dataName,"'")
		add_quote = "'" 
	endif
	string dataLow=dataName+"_"+kind+"_low"+add_quote
  string dataHigh=dataName+"_"+kind+"_high"+add_quote
 	if(paramisdefault(error))
 		wave error = $(dataName+"_"+kind)+add_quote
 	endif
 	duplicate /o Error,$dataLow /WAVE=Low
  duplicate /o Error,$dataHigh /WAVE=High
  Low=Data-Error
  High=Data+Error
	if(!append_)
		display
  endif
  string traces = tracenamelist("",";",1)
  variable n = itemsinlist(traces)
  appendToGraph Low
	modifyGraph mode[0+n]=7, toMode[0+n]=1, hbFill[0+n]=4
	appendToGraph Data
	modifyGraph mode[1+n]=7, toMode[1+n]=1, hbFill[1+n]=4, lsize[1+n]=2
	appendToGraph High
End

function /s GetAxisLabel(axis[,win])
	string axis,win
	
	win=selectstring(paramisdefault(win),win,winname(0,1))
	string str=winrecreation(win,0)
	variable i
	for(i=0;i<itemsinlist(str,"\r");i+=1)
		string line=stringfromlist(i,str,"\r")
		//line=replacestring("\t",line,"")
		string labell=""
		string match="\tLabel "+axis+" *"
		if(stringmatch(line,match))
			line=line[strlen(match),strlen(line)-1]
			labell=replacestring("\"",line,"")
			break
		endif
	endfor
	
	return labell
end

// Return a waves wave corresponds to the waves plotted in the graph.  
function /wave GraphWaves([win,match,except])
	string win,match,except
	
	win=selectstring(!paramisdefault(win),winname(0,1),win)
	match=selectstring(!paramisdefault(match),"*",match)
	except=selectstring(!paramisdefault(except),"",except)
	
	string traces=MatchExcept(tracenamelist(win,";",1),match,except)
	make /free/wave/n=(itemsinlist(traces)) w=tracenametowaveref(win,stringfromlist(p,traces))
	return w
end	
	
Function /S PopupOptions(win,name,options[,selected])
	string win,name,options,selected
	
	if(!strlen(win))
		win=winname(0,65)
	endif
	if(paramisdefault(selected))
		if(stringmatch(getrtstackinfo(0),"*ExecuteMacro*"))
			selected=""
		else
			selected=getuserdata(win,name,"selected")
		endif
	endif
	selected=replacestring(";",selected,",")
	selected=removeending(selected,",")
	selected=ClearBrackets(selected)
	string displayedOptions=""
	variable i
	for(i=0;i<itemsinlist(options);i+=1)
		string option=stringfromlist(i,options)
		displayedOptions+=selectstring(stringmatch(option,selected),option,"["+option+"]")+";"
	endfor
	return displayedOptions
End

Function ColorTab(fract,colorTabName,red,green,blue)
	variable fract // Fraction of the way through the color table (0-1).  
	string colorTabName
	variable &red,&green,&blue
	
	ColorTab2Wave $colorTabName
	wave M_Colors
	setscale x,0,1,M_Colors
	red=M_Colors(fract)(0)
	green=M_Colors(fract)(1)
	blue=M_Colors(fract)(2)
	killwaves /z M_Colors
End

// Tiles graphs in a window so that each axis gets its own row/column.  
Function TileAxes([win,grout,pad,box])
	string win
	wave grout // 1 or 2 points.  
	wave pad // 1, 2, or 4 points.  
	variable box
	
	win=selectstring(paramisdefault(win),win,winname(0,1))
	if(paramisdefault(grout))
		make /free/n=4 grout=0.02
	endif
	if(paramisdefault(pad))
		make /free/n=4 pad=0.02
	endif
	
	variable groutH=grout[0],groutV=grout[numpnts(grout)-1]
	variable padL=pad[0],padT=numpnts(pad)>1 ? pad[1] : padL, padR=numpnts(pad)>2 ? pad[2] : padL, padB=numpnts(pad)>3 ? pad[3] : padT
	
	string axes=AxisList(win)
	variable i,j,k,totH=0,totV=0,lowH=1,lowV=1
	for(j=0;j<3;j+=1) // Axis inventory (j=0), then axis sizing and parallel shifting (j=1), then axis perpendicular shifting (intersection) (j=2).  
		if(j==1)
			if(1-groutV*(totV-1)<0)
				printf "Vertical grout too large to accomodate this many horizontal axes; decreasing vertical grout size...\r"
				groutV = 0.5/totV
			endif
			if(1-groutH*(totH-1)<0)
				printf "Horizontal grout too large to accomodate this many vertical axes; decreasing horizontal grout size...\r"
				groutH = 0.5/totH
			endif
		endif
		variable h=0,v=0
		for(i=0;i<itemsinlist(axes);i+=1)
			string axis=stringfromlist(i,axes)
			string info=AxisInfo(win,axis)
			string type=stringbykey("AXTYPE",info)
			strswitch(type)
				case "left":
				case "right":
					switch(j)
						case 0:
							totV+=1
							break
						case 1: 
							variable low = v*(1+groutV)/totV
							variable high = low + (1-groutV*(totV-1))/totV
							low = padB+(1-padB-padT)*low
							high = padB+(1-padB-padT)*high
							modifygraph /w=$win axisEnab($axis)={low,high}
							if(box)
								for(k=0;k<totH;k+=1)
									newfreeaxis /w=$win /l $("mirror"+num2str(k)+"_"+axis)
									modifygraph /w=$win axisEnab($("mirror"+num2str(k)+"_"+axis))={low,high}
								endfor	
							endif
							lowV=min(low,lowV)
							v+=1
							break
						case 2:
							modifygraph /w=$win freePos($axis)={lowH,kwFraction}
							if(box)
								//killfreeaxis /w=$win $("mirror_"+axis)
								//newfreeaxis /w=$win $("mirror_"+axis)
								for(k=0;k<totH;k+=1)
									high=((k+1)/totV)-((k+1)<totV ? groutH/2 : padR)
									modifygraph /w=$win freePos($("mirror"+num2str(k)+"_"+axis))={high,kwFraction},noLabel($("mirror"+num2str(k)+"_"+axis))=2,nticks($("mirror"+num2str(k)+"_"+axis))=0
								endfor
							endif
							break
					endswitch
					break
				case "top":
				case "bottom":
					switch(j)
						case 0:
							totH+=1
							break
						case 1:
							low = h*(1+groutH)/totH
							high = low + (1-groutH*(totH-1))/totH
							low = padL+(1-padL-padR)*low
							high = padL+(1-padL-padR)*high
							modifygraph /w=$win axisEnab($axis)={low,high}
							if(box)
								for(k=0;k<totH;k+=1)
									newfreeaxis /w=$win /b $("mirror"+num2str(k)+"_"+axis)
									modifygraph /w=$win axisEnab($("mirror"+num2str(k)+"_"+axis))={low,high}
								endfor
							endif
							lowH=min(low,lowH)
							h+=1
							break
						case 2:
							modifygraph /w=$win freePos($axis)={lowV,kwFraction}
							if(box)
								//killfreeaxis /w=$win $("mirror_"+axis)
								//newfreeaxis /w=$win $("mirror_"+axis)
								for(k=0;k<totH;k+=1)
									high=((k+1)/totH)-((k+1)<totH ? groutH/2 : padR)
									modifygraph /w=$win freePos($("mirror"+num2str(k)+"_"+axis))={high,kwFraction},noLabel($("mirror"+num2str(k)+"_"+axis))=2,nticks($("mirror"+num2str(k)+"_"+axis))=0
								endfor
							endif
							break
					endswitch	
					break
			endswitch
		endfor
	endfor
End

// May be easier to append manually and then use TileAxes.  
Function TileAppend(waves,rows,cols[,xIndices,yIndices,win,left,right,low,high,xLog,yLog,colors,box,labels,xLabel,yLabel,xMargin,yMargin,grout])
	wave /wave waves // Can be a bunch of 1D waves, a matrix (will plot columns), or a stack (will plot beams, and use the dimension sizes of the stack instead of provided rows and cols values).  
	variable rows,cols
	wave xIndices,yIndices // Indices of the columns or wave references to be plotted.  To plot waves against each other, provide xIndices.  
	variable left,right // Left and right values for x-axes. 
	variable low,high // Low and high values for y-axes. 
	variable xLog,yLog // Set x and/or y axes to log scale.  
	wave colors // A wave of colors in the same format as 'waves', except with one of the dimensions have 3 points.  
	variable box // 0 for no mirror axes, 1 for only mirror x-axes, 2 for only mirror y-axes, and 3 for mirror axes both ways.  
	string labels // Labels for axes.  
	string xLabel,yLabel // Master labels for the axes.  
	variable xMargin,yMargin // Margins (as a fraction of graph size) for the axes closests to the edge of the graph window.  
	wave grout // Grout as a fraction of the graph window size.  
	string win
	
	win=selectstring(!paramisdefault(win),winname(0,1),win)
	xMargin=paramisdefault(xMargin) ? 0.02 : xMargin
	yMargin=paramisdefault(yMargin) ? 0.02 : yMargin
	grout=paramisdefault(grout) ? 0.02 : grout
	
	wave w=waves[0]
	if(dimsize(w,1)<=1) // One of a bunch of 1D waves.  
		variable numWaves=numpnts(waves) 
		string mode="waves"
	elseif(dimsize(w,2)<=1) // A matrix.  
		numWaves=dimsize(w,1)
		make /free/n=(numWaves) yIndices=p
		mode="matrix"
	else // A stack.  
		numWaves=dimsize(w,0)*dimsize(w,1)
		rows=dimsize(w,0)
		cols=dimsize(w,1)
		mode="stack"
	endif
//	if(paramisdefault(yIndices))
//		make /free/n=(numWaves) yIndices=p
//	else
//		numWaves=numpnts(yIndices)
//	endif
	
	variable numXTicks=ceil(10/cols)
	variable numYTicks=ceil(10/rows)
	
	variable i
	for(i=0;i<numwaves;i+=1)
		wave w=waves[i]
		if(!waveexists(w))
			continue
		endif		
		variable row=mod(i,rows)
		variable col=floor(i/rows)
		string yAxis,xAxis
		sprintf xAxis,"x_%d",col
		sprintf yAxis,"y_%d",row
		variable red,green,blue
		if(!paramisdefault(colors))
			strswitch(mode)
				case "stack":
					red=colors[row][col][0]
					green=colors[row][col][1]
					blue=colors[row][col][2]
					break
			endswitch
		endif
		strswitch(mode)
			case "matrix":
				appendtograph /w=$win/L=$yaxis /B=$xAxis /c=(red,green,blue) w[][yIndices[i]]
				break
			case "stack":
				appendtograph /w=$win/L=$yaxis /B=$xAxis /c=(red,green,blue) w[row][col][]
				break
			default:
				appendtograph /w=$win/L=$yaxis /B=$xAxis /c=(red,green,blue) w
				break
		endswitch
		
		if(!paramisdefault(left) && !paramisdefault(right))
			setAxis /w=$win $xAxis left,right
		endif
		if(!paramisdefault(low) && !paramisdefault(high))
			setAxis /w=$win $yAxis low,high
		endif
		ModifyGraph /w=$win axOffset($yAxis)=-4,axOffset($xAxis)=-1,btLen=1
		modifygraph /w=$win lblpos($xAxis)=100,nticks($xAxis)=numXTicks,log($xAxis)=xLog
		modifygraph /w=$win lblpos($yAxis)=100,nticks($yAxis)=numYTicks,log($yAxis)=yLog
		if(!paramisdefault(labels))
			strswitch(labels)
				case "waveNames":
					label /w=$win $xAxis nameofwave(waves[col])
					label /w=$win $yAxis nameofwave(waves[row])
					break
				case "dfNames":
					label /w=$win $xAxis getwavesdatafolder(waves[col],0)
					label /w=$win $yAxis getwavesdatafolder(waves[row],0)
					break
				default:
					label /w=$win $xAxis stringfromlist(col,labels)
					label /w=$win $yAxis stringfromlist(row,labels)
					break
			endswitch
		endif
		if(box & 1)
			if(row>0)
				sprintf xAxis,"xLow_%d_%d",row,col
				newfreeaxis /w=$win /b $xAxis
				ModifyGraph /w=$win nticks($xAxis)=0
			endif
			sprintf xAxis,"xHigh_%d_%d",row,col
			newfreeaxis /w=$win /b $xAxis
			ModifyGraph /w=$win nticks($xAxis)=0
		endif
		if(box & 2)
			if(col>0)
				sprintf yAxis,"yLow_%d_%d",row,col
				newfreeaxis /w=$win /l $yAxis
				ModifyGraph /w=$win nticks($yAxis)=0
			endif
			sprintf yAxis,"yHigh_%d_%d",row,col
			newfreeaxis /w=$win /l $yAxis
			ModifyGraph /w=$win nticks($yAxis)=0
		endif
	endfor
	if(!paramisdefault(xLabel))
		textbox /w=$win/o=0/f=0/t=1/a=mt/x=0/y=0 xLabel
	endif
	if(!paramisdefault(yLabel))
		textbox /w=$win/o=90/f=0/t=1/a=rc/x=0/y=0 yLabel
	endif
	TileAxes(win=win,grout=grout,pad={xMargin,yMargin})
End

// May be easier to append manually and then use TileAxes.  
Function ScatterPlotMatrix(m[,left,right,low,high,xLog,yLog,labels,xMargin,yMargin,grout])
	wave m // Matrix to plot.  
	variable left,right // Left and right values for x-axes. 
	variable low,high // Low and high values for y-axes. 
	variable xLog,yLog // Set x and/or y axes to log scale.  
	string labels // Labels for axes.  
	variable xMargin,yMargin // Margins (as a fraction of graph size) for the axes closests to the edge of the graph window.  Between 0 and 1.  
	variable grout // Grout as a fraction of the graph window size.  
	
	xMargin=paramisdefault(xMargin) ? 0.02 : xMargin
	yMargin=paramisdefault(yMargin) ? 0.02 : yMargin
	grout=paramisdefault(grout) ? 0.02 : grout
	
	display /k=1
	doupdate
	string win=winname(0,1)
	variable i,j,numwaves=dimsize(m,1)
	for(i=0;i<numwaves;i+=1)
		string xAxis
		sprintf xAxis,"x_%d",i
		for(j=0;j<numwaves;j+=1)
			string yAxis
			sprintf yAxis,"y_%d",j
			appendtograph /L=$yaxis /B=$xAxis m[][j] vs m[][i]
			if(!paramisdefault(low) && !paramisdefault(high))
				setAxis /w=$win $yAxis low,high
			endif
			modifygraph /w=$win log($yAxis)=yLog
			if(paramisdefault(labels))
				string y_label=getdimlabel(m,1,j)
			else
				y_label=stringfromlist(j,labels)
			endif
			label /w=$win $yAxis y_label
		endfor
		if(!paramisdefault(left) && !paramisdefault(right))
			setAxis /w=$win $xAxis left,right
		endif
		modifygraph /w=$win log($xAxis)=xLog		
		if(paramisdefault(labels))
			string x_label=getdimlabel(m,1,i)
		else
			x_label=stringfromlist(i,labels)
		endif
		label /w=$win $xAxis x_label
	endfor
	modifygraph /w=$win axOffset=-4,axOffset=-1,btLen=1,lblpos=100
	TileAxes(win=win,grout={grout},pad={xMargin,yMargin})
End

Function AddBlendingToGizmo([gizmoName])
	String gizmoName
	
	if( ParamIsDefault(gizmoName) || (strlen(gizmoName) == 0) )
		gizmoName=winname(0,4096)
	endif
	if(!strlen(gizmoName))
		return -1
	endif
	string cmd
	sprintf cmd, "ModifyGizmo/N=%s startRecMacro", gizmoName
	execute/Q/Z cmd
	sprintf cmd,  "ModifyGizmo/N=%s insertDisplayList=0, opName=enableBlend, operation=enable, data=3042", gizmoName
	execute/Q/Z cmd
	sprintf cmd, "AppendToGizmo/N=%s attribute blendFunc={770,771},name=blendingFunction", gizmoName
	execute/Q/Z cmd
	sprintf cmd, "ModifyGizmo/N=%s insertDisplayList=0, attribute=blendingFunction", gizmoName
	execute/Q/Z cmd
	sprintf cmd, "ModifyGizmo/N=%s compile", gizmoName
	execute/Q/Z cmd
	sprintf cmd, "ModifyGizmo/N=%s endRecMacro", gizmoName
	execute/Q/Z cmd
End

Function /wave RegionAB()
	duplicate /free/r=(xcsr(a),xcsr(b)) csrwaveref(a), region
	return region
End

function SwapXY([win])
	string win
	
	win=selectstring(!paramisdefault(win),winname(0,1),win)
	string winrec=winrecreation(win,0)
	variable swap=!stringmatch(winrec,"*swapXY=1*") // Swap or swap back?  
	modifygraph /w=$win swapXY=swap
end

Function ColorizeWaterfall()
	wave /z w=TopWave()
	if(!waveexists(w))
		return -1
	endif
	string name=getwavesdatafolder(w,2)
	variable rows=dimsize(w,0)
	variable cols=dimsize(w,1)
	make /o/n=(rows*cols,3) $(name+"_clr") /wave=colors
	ColorTab2Wave rainbow
	wave m_colors
	colors=m_colors[100*floor(p/cols)/rows][q]
	killwaves /z m_colors
	name=TopTrace()
	modifygraph zColor($name)={colors,*,*,directRGB,0}
End

// Append a wave such that the values become a series of hashes (vertical lines) spaced along the x-axis.  
// You may need to play with the margin setting to get this to look right.  
Function AppendHashes(w[,axis])
	wave w
	string axis
#if IgorVersion() >= 6.2
	appendtograph /vert/r w /tn=hashTicks
	ModifyGraph mode(hashTicks)=3,marker(hashTicks)=10,msize(hashTicks)=25,margin=50,standoff=0,muloffset(hashTicks)={1e-100,1}
	SetAxis right -1,1
	HideAxes(axes="right")
#endif
End

Function IgorWinCoords(coords)
	Struct rect &coords
	if(StringMatch(IgorInfo(2),"Macintosh"))
		String coordStr=StringByKey("SCREEN1",IgorInfo(0))
		Variable left,top,right,bottom
		sscanf coordStr,"DEPTH=%*d,RECT=%d,%d,%d,%d",left,top,right,bottom
		coords.left=left
		coords.top=top+20
		coords.right=right
		coords.bottom=bottom
	else
		GetWindow kWFrameInner, wsize
		//String coordStr=StringByKey("SCREEN1",IgorInfo(0))
		//Variable left,top,right,bottom
		//sscanf coordStr,"DEPTH=%*d,RECT=%d,%d,%d,%d",left,top,right,bottom
		coords.left=V_left//*72/ScreenResolution
		coords.top=V_top//*72/ScreenResolution
		coords.right=V_right//*72/ScreenResolution
		coords.bottom=V_bottom//*72/ScreenResolution
	endif
End

function /s IgorWinCoords2()
	Struct rect coords
	IgorWinCoords(coords)
	string result = num2str(coords.left)+";"+num2str(coords.top)+";"
	result += num2str(coords.right)+";"+num2str(coords.bottom)+";"
	return result
end

Function RegenLayout([replace,with,win])
	String replace,with,win
	
	if(ParamIsDefault(win))
		win=WinName(0,4)
	endif
	
	String rec=WinRecreation(win,0)
	if(!ParamIsDefault(replace) && !ParamIsDefault(with))
		rec=ReplaceString(replace,rec,with)	
	endif
	DoWindow /K $win
	Preferences 1
	Variable i
	for(i=2;i<ItemsInList(rec,"\r")-1;i+=1) // All lines of the recreation macro except the first two and the last.  
		String line=StringFromList(i,rec,"\r")
		Execute /Q line
	endfor
	DoWindow /C $win
End

Function /S LayoutObjects([layoutName])
	String layoutName
	
	if(ParamIsDefault(layoutName))
		layoutName=WinName(0,4)
	endif
	Variable i=0
	String list=""
	Do
		String info=LayoutInfo(layoutName,num2str(i))
		String objName=StringByKey("NAME",info)
		if(strlen(objName))
			list+=objName+";"
			i+=1
		else
			break
		endif
	While(1)
	return list
End

// Returns a list of axis information for all the axes in the graph.  
Function /S GetAxes([graph])
	String graph
	
	if(ParamIsDefault(graph))
		graph=WinName(0,1)
	endif
	String axes=AxisList(graph)
	Variable i
	String axisCommands=""
	for(i=0;i<ItemsInList(axes);i+=1)
		String axis=StringFromList(i,axes)
		String axis_info=AxisInfo(graph,axis)
		String axisCommand=StringByKey("SETAXISCMD",axis_info)
		axisCommands+=axisCommand+";"
	endfor
	return axisCommands
End

Function SetAxes(axisCommands[,graph])
	String axisCommands,graph
	
	if(ParamIsDefault(graph))
		graph=WinName(0,1)
	endif
	Variable i
	for(i=0;i<ItemsInList(axisCommands);i+=1)
		String axisCommand=StringFromList(i,axisCommands)
		axisCommand=ReplaceString("SetAxis",axisCommand,"SetAxis /W="+graph)
		Execute /Q/Z axisCommand
	endfor
End

Function AddLetters(num)
	Variable num // Number of letters (starting with 'A').  
	Variable i
	for(i=0;i<num;i+=1)
		String letter=num2char(97+i)
		Textbox /F=0 "\Z18\f01"+UpperStr(letter)
	endfor
End

Function WindowCoordsFromMacro(macroStr,coords)
	String macroStr
	Struct rect &coords
	
	Variable i=0,left,top,right,bottom
	Do
		String line=StringFromList(i,macroStr,"\r")
		if(strlen(line))
			sscanf line,"\tDisplay /W=(%f,%f,%f,%f)%*s",left,top,right,bottom
			if(left)
				break
			endif
			i+=1
		else
			break
		endif
	While(1)
	coords.left=left
	coords.top=top
	coords.right=right
	coords.bottom=bottom
End

Function /S AxisName(type[,win])
	String type,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	
	String axis_list=AxisList(win)
	Variable i
	for(i=0;i<ItemsInList(axis_list);i+=1)
		String axisName=StringFromList(i,axis_list)
		String axis_info=AxisInfo(win,axisName)
		String axisType=StringByKey("AXTYPE",axis_info)
		if(StringMatch(type,axisType))
			return axisName
		endif
	endfor
	return ""
End

Function /S AxisList2(type[,win])
	String type,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	
	String axis_list=AxisList(win)
	String newAxisList=""
	Variable i
	for(i=0;i<ItemsInList(axis_list);i+=1)
		String axisName=StringFromList(i,axis_list)
		String axis_info=AxisInfo(win,axisName)
		String axisType=StringByKey("AXTYPE",axis_info)
		strswitch(type)
			case "vertical":
				if(StringMatch(axisType,"left") || StringMatch(axisType,"right"))
					newAxisList+=axisName+";"		
				endif
				break
			case "horizontal":
				if(StringMatch(axisType,"top") || StringMatch(axisType,"bottom"))
					newAxisList+=axisName+";"		
				endif
				break
			default:
				if(StringMatch(axisType,type) || StringMatch(axisType,"bottom"))
					newAxisList+=axisName+";"		
				endif
				break
		endswitch
	endfor
	return newAxisList
End

#if 1 // Use new TraceFromPixel functionality.  
Function /s TracesInsideMarquee(traces[,offset,remoov,win])
	string traces,win
	string offset // Optional offset for searching traces.  Use this if something if the trace plotted does not start at wave index 0.  
	variable remoov // Remove from graph.  

	win=selectstring(!paramisdefault(win),winname(0,1),win)
	if(!strlen(traces))
		traces=tracenamelist(win,";",1)
	endif
	getmarquee /w=$win
	variable factor=ScreenResolution/72
	variable xMid=factor*(v_right+v_left)/2
	variable yMid=factor*(v_bottom+v_top)/2
	variable dx=factor*(v_right-v_left)/2
	variable dy=factor*(v_bottom-v_top)/2
	variable i,xx,yy
	string newTraces=""
	for(i=0;i<itemsinlist(traces);i+=1)
		string trace=stringfromlist(i,traces)
		string hit=""
		string options
		sprintf options,"WINDOW:%s;ONLY:%s;DELTAX:%d;DELTAY:%d",win,trace,dx,dy
		hit=tracefrompixel(xMid,yMid,options)
		if(strlen(hit))
			newTraces+=stringbykey("TRACE",hit)+";"
		endif
	endfor
	if(remoov)
		newTraces=sortlist(newTraces,";",17)
		for(i=0;i<itemsinlist(newTraces);i+=1)
			trace=stringfromlist(i,newTraces)
			removefromgraph /z/w=$win $trace
		endfor
	endif
	return newTraces
End

#elif 0

Function /s TracesInsideMarquee(traces[,offset,win])
	string traces,win
	string offset // Optional offset for searching traces.  Use this if something if the trace plotted does not start at wave index 0.  

	win=selectstring(!paramisdefault(win),winname(0,1),win)
	getmarquee /w=$win
	variable xxInc=(v_right-v_left)/10
	variable yyInc=(v_bottom-v_top)/10
	variable i,xx,yy
	string newTraces=""
	for(i=0;i<itemsinlist(traces);i+=1)
		string trace=stringfromlist(i,traces)
		string hit=""
		for(xx=v_left;xx<=v_right;xx+=xxInc)
			for(yy=v_top;yy<=v_bottom;yy+=yyInc)
				hit=tracefrompixel(xx,yy,"WINDOW:"+win+";ONLY:"+trace)
				if(strlen(hit))
					break
				endif
			endfor
			if(strlen(hit))
				newTraces+=stringbykey("TRACE",hit)+";"
				break
			endif
		endfor
	endfor
	return newTraces
End
#endif

// Gets the pair of axes containing the point that was clicked.  Axes must have a certain name template.  
Function /S GetAxesFromClick(xx,yy,xName,yName[,win])
	variable xx,yy
	string xName,yName // e.g. "axisT_" and "axis_"
	string win
	
	win=selectstring(!paramisdefault(win),winname(0,1),win)
	variable i
	do
		string axis=yName+num2str(i)
		string axisT=xName+num2str(i)
		if(!strlen(axisinfo(win,axis)) || !strlen(axisinfo(win,axisT)))
			break
		endif
		variable xVal=axisvalfrompixel("",axisT,xx)
		getaxis /q $axisT
		if(xVal<v_min || xVal>v_max)
			i+=1
			continue
		endif
		variable yVal=axisvalfrompixel("",axis,yy)
		getaxis /q $axis
		if(yVal<v_min || yVal>v_max)
			i+=1
			continue
		endif
		return axisT+";"+axis
	while(1)
	return ""
End

Function /S GetYAxisFromClick(ypixel[,win])
	Variable ypixel
	String win
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	GetWindow $win psizeDC
	Variable yFrac=(V_bottom-ypixel)/(V_bottom-V_top)
	String axes=AxisList(win)
	Variable i
	for(i=0;i<ItemsInList(axes);i+=1)
		String axisName=StringFromList(i,axes)
		String axis_info=AxisInfo(win,axisName)
		String axisType=StringByKey("AXTYPE",axis_info)
		if(StringMatch(axisType,"LEFT") || StringMatch(axisType,"RIGHT"))
			String axisEnab=StringByKey("axisEnab(x)",axis_info,"=")
			Variable low,high
			sscanf axisEnab,"{%f,%f}",low,high
			if(yFrac>low && yFrac<high)
				return axisName
			endif
		endif
	endfor
	return ""
End

Function TraceName2SubRange(traceName)
    String traceName
    String info=TraceInfo("",traceName,0) // Assume top graph. 
    String range=StringByKey("YRANGE",Info)
    String range1,range2
    sscanf range,"[%[0-9,\*]][%[0-9,\*]]",range1,range2
 
End

Function RemoveFolderFromGraph(df[,win])
	dfref df
	string win
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	traces=SortList(traces,";",16)
	Variable i
	for(i=ItemsInList(traces)-1;i>=0;i-=1)
		string trace=StringFromList(i,traces)
		wave w=TraceNameToWaveRef(win,trace)
		dfref wavDF=GetWavesDataFolderDFR(w)
		if(datafolderrefsequal(wavDF,df))
			RemoveFromGraph /Z/W=$win $trace
		endif
	endfor
End

Function ReplaceFolderOnGraph(oldFolder,newFolder[,win])
	String oldFolder,newFolder,win
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace=StringFromList(i,traces)
		// CODE NEEDED HERE.  
	endfor
End

Function DisplayMeanTrace([win,error,name,type,keyTrace,x1,x2])
	string win
	string error // Also add standard deviation error bars.  
	string name // Optional name for mean wave.  
	string type // e.g. "med" for median.  Default is mean
	string keyTrace
	variable x1,x2 // Extent of mean wave.  
	
	win=selectstring(paramisdefault(win),win,winname(0,1))
	type=selectstring(paramisdefault(type),type,"mean")
	error=selectstring(paramisdefault(error),error,"")
	string traces=TraceNameList(win,";",1)
	keyTrace=selectstring(!paramisdefault(keyTrace),stringfromlist(0,traces),keyTrace)
	
	string metaTraces=getuserdata(win,"","metaTraces")
	traces=removefromlist(metaTraces,traces)
	Variable i,minSweep=Inf,maxSweep=0,red,green,blue
	
	string str=GetUserData(win,"","mouseDown")
	struct point mouseDown
	structget /s mouseDown str
	variable mouseX=mouseDown.h
	variable mouseY=mouseDown.v
	if(numtype(mouseX) || numtype(mouseY))
		return -1
	endif
	
	Variable keyRed,keyGreen,keyBlue
	GetTraceColor(keyTrace,keyRed,keyGreen,keyBlue,win=win)
	String keyYAxis=TraceYAxis(keyTrace,win=win)
	String keyXAxis=TraceXAxis(keyTrace,win=win)
	Wave KeyWave=TraceNameToWaveRef(win,keyTrace)
	String keyChannel=GetWavesDataFolder(KeyWave,0)
	String keyFolder=GetWavesDataFolder(KeyWave,1)
	Variable keyXoffset_=XOffset(keyTrace,win=win)
	variable left,right
	TraceRange(keyTrace,left,right,win=win)
	left=paramisdefault(x1) ? left : x1
	right=paramisdefault(x2) ? right : x2
	
	Duplicate /FREE/R=[left,right] KeyWave MeanWave,Count
	MeanWave=0
	Count=0
	if(strlen(error))
		Duplicate /FREE/R=[left,right] KeyWave ErrorWave
		ErrorWave=0
	endif
	strswitch(type)
		case "med":
			duplicate /free keyWave data
			redimension /n=(-1,itemsinlist(traces)) data 
			break
	endswitch
	
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace=StringFromList(i,traces)
		String yAxis=TraceYAxis(trace,win=win)
		String xAxis=TraceXAxis(trace,win=win)
		if(StringMatch(xAxis,keyXAxis) && StringMatch(yAxis,keyYAxis))
			GetTraceColor(trace,red,green,blue,win=win)
			if(red==keyRed && green==keyGreen && blue==keyBlue) // Trace of the same color as the key trace.  
				Wave TraceWave=TraceNameToWaveRef(win,trace)
				if(!waveexists(TraceWave)) // Not sure how this could happen, but Gilberto had this problem when one channel was not active.  
					continue
				endif
				Wave /z TraceXWave=XWaveRefFromTrace(win,trace)
				Variable xOffset_=XOffset(trace,win=win)
				Variable xMulOffset_=XmulOffset(trace,win=win)
				xMulOffset_=xMulOffset_ ? xMulOffset_ : 1
				Variable relXOffset=XOffset_-keyXOffset_
				Variable yOffset_=YOffset(trace,win=win)
				wavestats /q/m=1 TraceWave
				if(v_npnts==0)
					continue
				endif
				strswitch(type)
					case "mean":
						MeanWave+=numtype(TraceWave(x-relXOffset)) ? 0 : TraceWave(x-relXOffset)+yOffset_
						break
					case "med":
						data[][i]=numtype(TraceWave(x-relXOffset)) ? nan : TraceWave(x-relXOffset)+yOffset_
						break
				endswitch
				strswitch(error)
					case "SEM":
					case "StDev":
						ErrorWave+=numtype(TraceWave(x-relXOffset)) ? 0 : (TraceWave(x-relXOffset)+yOffset_)^2
						break
				endswitch
				String wavName=NameOfWave(TraceWave)
				Variable sweepNum
				sscanf wavName,"sweep%d",sweepNum
				minSweep=min(minSweep,sweepNum)
				maxSweep=max(maxSweep,sweepNum)
				Count+=numtype(TraceWave(x-relXOffset)) ? 0 : 1
			endif
		endif
	endfor
	
	if(!sum(count))
		return -2
	endif
	strswitch(type)
		case "mean":
			MeanWave/=Count
			strswitch(error)
				case "StDev":
					ErrorWave=sqrt(ErrorWave/Count-MeanWave^2)
					break
				case "SEM":
					ErrorWave=sqrt(ErrorWave/Count-MeanWave^2)/sqrt(Count)
					break
			endswitch
			break
		case "med":
			for(i=0;i<dimsize(data,0);i+=1)
				matrixop /free row_=row(data,i)
				extract /free row_,row2_,numtype(row_)==0
				switch(numpnts(row2_))
					case 0:
						MeanWave[i]=nan
						ErrorWave[i]=nan
						break
					case 1:
						MeanWave[i]=row2_[0]
						ErrorWave[i]=0
						break
					case 2:
						MeanWave[i]=statsmedian(row2_)
						break
					default:
						statsquantiles /q row2_
						MeanWave[i]=v_median
						break
				endswitch
						
				if(numpnts(row2_)>=2)
					// Error calculations.  
					row2_-=v_median
					row2_=abs(row2_)
					wavestats /q row2_
					strswitch(error)
						case "StDev":
							ErrorWave[i]=(v_avg/0.6745)
							break
						case "SEM":
							ErrorWave[i]=(v_avg/0.6745)/sqrt(Count[i])
							break
					endswitch
				endif
			endfor
			break
	endswitch
	
	string meanName=""
	if(paramisdefault(name))
		if(stringmatch(keyTrace,"sweep*"))
			if(minSweep==maxSweep)
				str=cleanupname(win,0)
				do
					if(strlen(str)+max(strlen(type),strlen(error))+1>31)
						str=str[0,strlen(str)-2]
					else
						break
					endif
				while(1)
				sprintf meanName,"%s_%s"str,type
			else
				sprintf meanName,"%s_%d_%d_%s",keyChannel,minSweep,maxSweep,type
			endif
		else
			sprintf meanName,"Mean_%d_%d_%d_%s",keyRed,keyGreen,keyBlue,type
		endif
	else
		meanName=name
	endif
	
	dfref df=keyFolder
	Duplicate /o MeanWave df:$CleanupName(meanName,0) /WAVE=MeanWave2 // Must use MeanWave2 to prevent a crash.  
	
	string errorName=""
	if(strlen(error))
		if(paramisdefault(name))
			if(minSweep==maxSweep)
				sprintf errorName,"%s_%s"str,error
			else
				sprintf errorName,"%s_%d_%d_%s",keyChannel,minSweep,maxSweep,error
			endif
		else
			errorName=removeending(meanName,type)+error
		endif
		
		Duplicate /o ErrorWave df:$CleanupName(errorName,0) /WAVE=ErrorWave2
	endif
	
	if(StringMatch(keyYAxis,"bottom") || StringMatch(keyXAxis,"left"))
		String temp=keyYAxis
		keyYAxis=keyXAxis
		keyXAxis=temp
	endif
	
	RemoveFromGraph /z/w=$win $meanName
	AppendToGraph /w=$win /c=(keyRed,keyGreen,keyBlue) /L=$keyYAxis /B=$keyXAxis MeanWave2[0,right-left+1] /tn=$meanName
	AppendUserData(win,"metaTraces",meanName)
	String meanTrace=TopTrace(win=win)
	ModifyGraph /W=$win/Z offset($meanTrace)={keyXoffset_,0}, lsize($meanTrace)=2

	if(strlen(error))
#if IgorVersion()>=6.3
		ArmenErrorBars(suffix=error,match="*"+meanName+"*",win=win)
#else
		ErrorBars /W=$win $meanTrace,Y wave=(ErrorWave2,ErrorWave2)
#endif
	endif
End

Function AppendUserData(win,name,data[,control])
	string win,name,data,control
	
	control=selectstring(paramisdefault(control),control,"")
	string oldData=getuserdata(win,control,name)
	setwindow $win userData($name)=removeending(oldData,";")+";"+data+";"
End

// Takes a graph of cumulative histograms from several experiments and makes a map that in which color is the cumulative histogram of the cumulative
// histogram values of experiments being at least a certain value.  Each cumulative histogram must have the same number of points.  
Function CumulativeHistogramMap([win,minn,maxx])
	string win
	variable minn,maxx
	
	win=selectstring(ParamIsDefault(win),win,WinName(0,1))
	String traces=TraceNameList(win,";",1)
	variable i,numTraces=itemsinlist(traces)
	for(i=0;i<numTraces;i+=1)
		String trace=StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef(win,trace)
		variable points=dimsize(traceWave,0)
		if(i==0)
			dfref df=getwavesdatafolderdfr(traceWave)
			variable delta=dimdelta(traceWave,0)
			variable offset=dimoffset(traceWave,0)
			make /free/n=(points,numTraces) data=0
		endif
		data[][i]=traceWave[p]
	endfor
	
	string name=win+"_CumulMap"
	make /o/n=(points,100) df:$name /wave=map=0
	setscale /p x,offset,delta,map
	minn=paramisdefault(minn) ? 0 : minn
	maxx=paramisdefault(maxx) ? wavemax(data) : maxx
	setscale y,minn,maxx,map // Scale the map so that its maximum y value is the largest value in the most right-shifted cumulative histogram.  
	for(i=0;i<dimsize(data,0);i+=1)
		matrixop /free values=row(data,i)^t
		sort values,values
		map[i][]=binarysearchinterp(values,dimoffset(map,1)+q*dimdelta(map,1))/numpnts(values)
		map[i][]=numtype(map[i][q]) ? (dimoffset(map,1)+q*dimdelta(map,1)>wavemax(values) ? 1 : 0) : map[i][q]
	endfor
	display /k=1/n=$cleanupname(name,0) as name
	appendimage map
	ModifyImage $name ctab= {0,1,RedWhiteBlue,0}
	setaxis /a left
	modifygraph swapXY=1
End

Function NormalizeTraces([win,horiz])
	String win
	variable horiz // Normalize the horizontal axis.  
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	
	Variable i
	String traces=TraceNameList(win,";",1)
	for(i=0;i<ItemsInList(traces);i+=1)
		string trace=StringFromList(i,traces)
		wave w=TraceNameToWaveRef(win,trace)
		if(!numpnts(w))
			continue
		endif
			
		if(horiz)
			wave /z w=XWaveRefFromTrace(win,trace)
			if(waveexists(w))
				wavestats /q/m=1 w
				variable maxx=v_max
			else
				wave w=TraceNameToWaveRef(win,trace)
				maxx=rightx(w)
			endif
			ModifyGraph /W=$win offset($trace)={0,0}, mulOffset($trace)={1/maxx,0}	
		else
			wave w=TraceNameToWaveRef(win,trace)
			wavestats /q/m=1 w
			ModifyGraph /W=$win offset($trace)={0,0}, mulOffset($trace)={0,1/v_max}	
		endif
	endfor
End

Function TraceRange(trace,left,right[,win])
	String trace,win
	Variable &left,&right
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String trace_info=TraceInfo(win,trace,0)
	String yRange=StringByKey("YRANGE",trace_info)
	sscanf yRange,"[%d,%d]",left,right
	if(left==0 && right==0)
		right=Inf
	endif
End

Function TraceColumn(trace[,win])
	String trace,win
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String trace_info=TraceInfo(win,trace,0)
	String yRange=StringByKey("YRANGE",trace_info)
	variable column=NaN
	sscanf yRange,"[*][%d]",column
	return column
End

// Returns the coordinates for a bezier flipped across the x-axis or y-axis assuming that 'x_origin' and 'y_origin' are the origin.  
// Also put them on the clipboard.  
Function /S FlipBezier(x_origin,y_origin,x_scale,y_scale,coords,axis)
	Variable x_origin,y_origin,x_scale,y_scale
	String coords // All of the bezier points.  
	String axis // 'x' or 'y', with x flipping up or down (across the x-axis).  
	String new_bezier
	sprintf new_bezier,"%f,%f,%f,%f,{",x_origin,y_origin,x_scale,y_scale
	Variable i
	for(i=0;i<ItemsInList(coords,",");i+=2)
		Variable x=str2num(StringFromList(i,coords,","))
		Variable y=str2num(StringFromList(i+1,coords,","))
		strswitch(axis)
			case "x":
				y=y_origin-(y-y_origin)
				break
			case "y":
				x=x_origin-(x-x_origin)
				break
		endswitch
		sprintf new_bezier,"%s%f,%f,",new_bezier,x,y
	endfor
	new_bezier=RemoveEnding(new_bezier,",")+"}"
	PutScrapText new_bezier
	Execute /Q "DrawBezier "+new_bezier
	return new_bezier
End

// Sends all selected graphs in the top layout to the back, one by one.  
Function SendGraphs2Back()
	Variable index=0
	Do
		String indexStr
		sprintf indexStr, "%d", index
		String info = LayoutInfo("", indexStr)
		if (strlen(info) == 0)
			break			// No more objects
		endif
		Variable selected = NumberByKey("SELECTED", info)
		if (selected)
			String objectTypeStr = StringByKey("TYPE", info)
			if (CmpStr(objectTypeStr,"Text") == 0)		// This is a graph?
				DoIgorMenu "Layout","Send to Back"
			endif
		endif
		
		index+=1
	While(1)
End

// Add letters to selected figure panels (graphs) in layouts.  
// Letters are derived from the last letter of the graph name.  
Function LetterFigurePanels()
	// Make a list of selected graphs.  
	Variable i=0
	String graph_names=""
	Do
		String info = LayoutInfo("",num2str(i))
		if (strlen(info) == 0)
			break			// No more objects
		endif
		Variable selected = NumberByKey("SELECTED", info)
		String objectTypeStr = StringByKey("TYPE", info)
		if (selected && StringMatch(objectTypeStr,"Graph"))			
			String graph_name=StringByKey("NAME", info)
			graph_names+=graph_name+";"
		endif
		i+=1
	While(1)	

	// Get rid of old letters.  
	String text_format="\\f01\\Z18"
	String annotations=AnnotationList("")
	for(i=0;i<ItemsInList(annotations);i+=1)
		String annotation=StringFromList(i,annotations)
		info=AnnotationInfo("",annotation)
		String text=StringByKey("TEXT",info)
		text=text[0,strlen(text)-2] // Remove last letter.  
		String text_format2=ReplaceString("\\",text_format,"\\\\")
		if(StringMatch(text,text_format2)) // If formatted like a figure panel letter.  
			Textbox /K /N=$annotation
		endif
	endfor
	
	// Get layout dimensions.  
	info=LayoutInfo("","Layout")
	String paper=StringByKey("PAPER",info)
	Variable paper_x=str2num(StringFromList(2,paper,","))
	Variable paper_y=str2num(StringFromList(3,paper,","))
	String page=StringByKey("PAGE",info)
	Variable margin_x=str2num(StringFromList(0,page,","))
	Variable margin_y=str2num(StringFromList(1,page,","))
	Variable page_x=str2num(StringFromList(2,page,","))-margin_x
	Variable page_y=str2num(StringFromList(3,page,","))-margin_y
	
	for(i=0;i<ItemsInList(graph_names);i+=1)
		graph_name=StringFromList(i,graph_names)
		info = LayoutInfo("",graph_name)
		Variable length=strlen(graph_name)
		String letter=graph_name[length-1,length-1]
		Variable left=NumberByKey("LEFT",info)-margin_x
		Variable top=NumberByKey("TOP",info)-margin_y
		Variable x=100*left/page_x
		Variable y=100*top/page_y
		TextBox /F=0/B=1/A=LT/X=(x)/Y=(y) text_format+letter
	endfor	
End

Function SliderCenterWrap(info) : SliderControl
	STRUCT WMSliderAction &info
	if(info.eventcode & 4)
		SliderCenter(info.ctrlName,win=info.win,quick=1)
	endif
End

// Sets the slider range so that the thumb is back in the center.  
// Useful for an "infinite" slider.  
Function SliderCenter(slider_name[,win,quick])
	String slider_name,win
	Variable quick
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	ControlInfo /W=$win $slider_name
	Variable val=V_Value
	String win_rec=WinRecreation(win,0)
	Variable i,low,high,inc,new_val
	if(quick!=1 && quick!=2 && quick!=3)
		quick=1
	endif
	if(quick==1)
		low=min(val*2,0); high=max(val*2,0); inc=0; new_val=val
	elseif(quick==2)
		low=val-1; high=val+1; inc=0; new_val=val
	elseif(quick==3)
		low=-1; high=1; inc=0; new_val=0
	else // The slow, accurate way.  NOT YET IMPLEMENTED.  
		for(i=0;i<ItemsInList(win_rec,"\r");i+=1)
			String line=StringFromList(i,win_rec,"\r")
		endfor
	endif
	Slider $slider_name limits={low,high,inc}, win=$win, value=new_val // Forces increment of zero.    
End

// Creates a color wave 'Colors' based on the mappings of the values in 'numbers' as strings in 'conditions'.  
Function ColorByNumber(conditions,numbers)
	String conditions // e.g. "CTL;TTX"
	String numbers // e.g. "010101"
	Variable i,red,green,blue
	Make /o/n=(ItemsInList(numbers),2) Colors
	for(i=0;i<ItemsInList(numbers);i+=1)
		Variable number=str2num(StringFromList(i,numbers))
		String condition=StringFromList(number,conditions)
		Condition2Colour(condition,red,green,blue)
		Colors[i][]={{red},{green},{blue}}
	endfor
End

Function StripWinRecHeader(win_rec)
	String &win_rec
	win_rec=RemoveListItem(0,win_rec,"\r")
	win_rec=RemoveListItem(ItemsInList(win_rec,"\r"),win_rec,"\r")
End

Function CumulPlot2(wave1,wave2)
	Wave wave1,wave2
	Display /K=1 wave1,wave2
	ModifyGraph mode=4,marker=8,msize=3,swapXY=1
	Variable i
	String wave_list=GetWavesDataFolder(wave1,2)+";"+GetWavesDataFolder(wave2,2)
	for(i=0;i<ItemsInList(wave_list);i+=1)
		String wave_name=StringFromList(i,wave_list)
		SetScale x,0,1,$wave_name
		wave_name=NameOfWave($wave_name)
		String condition=Name2Condition(wave_name)
		Condition2Color(condition); NVar red,green,blue
		ModifyGraph rgb($wave_name)=(red,green,blue)
	endfor
	KillVariables /Z red,green,blue
End

Function CumulPlot(wave_list[,graph_name])
	String wave_list
	String graph_name
	if(ParamIsDefault(graph_name))
		graph_name=UniqueName("CumulPlot_",6,0)
	endif
	Display /K=1 /N=$graph_name
	Variable i
	for(i=0;i<ItemsInList(wave_list);i+=1)
		String wave_name=StringFromList(i,wave_list)
		String condition=Name2Condition(wave_name)
		Condition2Color(condition); NVar red,green,blue
		SetScale x,0,1,$wave_name
		Sort $wave_name,$wave_name
		AppendToGraph /c=(red,green,blue) $wave_name
	endfor
	ModifyGraph mode=4,marker=8,msize=3,swapXY=1
	KillVariables /Z red,green,blue
End

Function CloneWindowWithReplacement()
	String win_rec=WinRecreation(WinName(0,5),0)
	Variable replace,with
	Prompt replace, "Replace: "		
	Prompt with, "With: "
	DoPrompt "Replacements", replace,with
	win_rec=ReplaceString("Fig"+num2str(replace), win_rec, "Fig"+num2str(with))
	win_rec=ReplaceString("Figure "+num2str(replace), win_rec, "Figure "+num2str(with))
	win_rec=ReplaceString("(ACL_desktopNum)=  \""+num2str(replace)+"\"", win_rec, "(ACL_desktopNum)=  \""+num2str(with)+"\"")
	Execute /Q win_rec
End

Function CopyWinRecreation()
	PutScrapText WinRecreation(WinName(0,5),0)
End

// Moves all the tags from being based on time to being based on sweep number.  
Function Tags2SweepNumber([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	Wave sweepT=root:sweepT
	String annotations=AnnotationList(win)
	Variable i
	for(i=0;i<ItemsInList(annotations);i+=1)
		String name=StringFromList(i,annotations)
		String info=AnnotationInfo(win,name,1)
		String type=StringByKey("TYPE",info)
		if(StringMatch(type,"Tag"))
			Variable time_val=str2num(StringByKey("ATTACHX",info))
			if(time_val==0)
				Variable sweep_num=0
			else
				sweep_num=BinarySearchInterp(sweepT,time_val)
			endif
			Tag /C/N=$name time_axis,sweep_num
		endif
	endfor
End

Function Quasilog([axis])
	String axis
	if(ParamIsDefault(axis))
		axis="left"
	endif
	Execute /Q "DoSplitAxis(\""+axis+"\",0.5,0)"
	Execute /Q "DoSplitAxis(\""+axis+"\",0.7,0)"
	Execute /Q "DoSplitAxis(\""+axis+"_P2\",0.3,0)"
	SetAxis $axis *,-1
	SetAxis $(axis+"_P2") 1,*
	SetAxis $(axis+"_P3") -1,0
	SetAxis $(axis+"_P2_P2") 0,1
End

Function Cursors([num,win])
	Variable num
	String win
	num=ParamIsDefault(num) ? 2 : num
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	if(!WinExist(win))
		printf "No such window: %s.\r",win
		return 0
	endif
	String trace=LongestVisibleTrace(win=win)
	if(!IsEmptyString(trace))
		Wave TraceWave=TraceNameToWaveRef(win,trace)
		Cursor /W=$win /H=2 A $trace leftx(TraceWave)
		Cursor /W=$win /H=2 B $trace rightx(TraceWave)
		variable i,pos
		variable length=rightx(theWave)-leftx(theWave)
		variable start=leftx(theWave)
		for(i=2;i<min(10,num);i+=1)
			if(mod(i,2)==0)
				pos=start+length*(i/2)/9
			else
				pos=start+length*(9-(i-1)/2)/9
			endif
			Cursor /W=$win /H=0 /S=1 $StringFromList(i-2,"C;D;E;F;G;H;I;J") $trace pos
		endfor
	endif
	//CursorStats()
End

Function CursorStats()
	GetWindow kwTopWin, wsizeOuterDC
	String win=WinName(0,1)
	if(CursorExists("A") && CursorExists("B"))
		String val="xcsr(B,\""+win+"\")-xcsr(A,\""+win+"\")"
	else
		val="0"
	endif
	ValDisplay CursorStat pos={V_right-50,V_bottom-18}, size={50,18}, value=#val
	SetWindow kwTopWin hook(CursorUpdateHook)=CursorUpdateHook
End

Function CursorUpdateHook(H_Struct)
	STRUCT WMWinHookStruct &H_Struct
	if(H_Struct.eventCode==7 || H_Struct.eventCode==8)
		CursorStats()
	else
		return 0
	endif
End

Function CursorPlace(a,b,[trace_name])
	Variable a,b
	String trace_name
	if(ParamIsDefault(trace_name)) // If not trace name is specified
		String traces=TraceNameList("",";", 1) // Get names of waves plotted on topmost graph
		trace_name=StringFromList(0, traces) // Pick the first wave
	endif
	Cursor A $(trace_name) a
	Cursor B $(trace_name) b
End

Function SaveCursors(name,[win])
	String name,win // Name of a cursor set.  
	
	win=selectstring(!ParamIsDefault(win),winname(0,1),win)
	name=selectstring(strlen(name),"Broad",name)
	dfref df=Core#InstanceHome("Acq",win,"win0",create=1,sub=name)
	String cursors="A;B",stem="xcsr_"
	Variable i
	for(i=0;i<ItemsInList(cursors);i+=1)
		String csr=StringFromList(i,cursors)
		if(strlen(csrwave($csr,win)) && datafolderrefstatus(df))
			newdatafolder /o df:$csr
			dfref cursorDF=df:$csr
			variable /G cursorDF:csr_x=xcsr2(csr,win=win)
			variable /G cursorDF:csr_y=vcsr2(csr,win=win)
			string /G cursorDF:trace=CsrWave($csr,win)
			string info=CsrInfo($csr)
			variable /G cursorDF:csr_free=str2num(StringByKey("ISFREE",info))
			variable /G cursorDF:x_point=str2num(StringByKey("POINT",info))
			variable /G cursorDF:y_point=str2num(StringByKey("YPOINT",info))
		endif
	endfor
End

Function RestoreCursors(name[,trace,win,offset])
	String name,trace,win
	Variable offset // An constant offset for the cursors with respect to the saved positions.
	win=selectstring(!ParamIsDefault(win),winname(0,1),win)
	name=selectstring(strlen(name),"Broad",name)
	dfref df=Core#InstanceHome("Acq",win,"win0",sub=name,quiet=1)
	if(!datafolderrefstatus(df))
		//printf "Could not find data '%s' to restore cursors for window '%s'.\r",name,win
		return -1
	endif
	trace=selectstring(!ParamIsDefault(trace) && strlen(trace),TopTrace(win=win),trace)
	if(strlen(trace)==0)
		return -2 // No trace on which to place the cursors.  
	endif
	String cursor_list="A;B"
	Variable i,err=0
	if(wintype("SweepsWin"))
		SetWindow SweepsWin hook=$""
	endif
	for(i=0;i<ItemsInList(cursor_list);i+=1)
		String csr=StringFromList(i,cursor_list)
		dfref cursorDF=df:$csr
		if(datafolderrefstatus(cursorDF))
			nvar /z/sdfr=cursorDF csr_x,csr_y,csr_free
			if(nvar_exists(csr_free) && csr_free)
				nvar /sdfr=cursorDF x_point
				nvar /sdfr=df y_point
				Cursor /F/P/W=$win $csr,$trace,x_point,y_point//csr_y // Don't feel like implementing this fully yet.  
			else
				variable trace_offset=XOffset(trace,win=win)
				Cursor /W=$win $csr,$trace,csr_x-trace_offset+offset
			endif
		else
			//printf "Could not find data for cursor '%s' in folder %s.\r",csr,getdatafolder(1,df)
			err=-1
		endif
	endfor
	if(err)
		Cursors(win=win)
	endif
	return err
End

// Returns the x position of the cursor relative to zero on the x-axis.  Considers sweep offsets to be "real".  
Function xcsr2(csr_name[,win])
	String csr_name,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	if(CursorExists(csr_name,win=win))
		Variable x1=xcsr($csr_name,win)
		x1+=XOffset(CsrWave($csr_name,win,1),win=win)
		return x1
	endif
End

Function ReanalyzeMatrix(Matrix)
	Wave Matrix
	Display /K=1
	ControlBar /T 30
	Variable /G root:curr_column
	SetVariable ColumnSet size={120,20},limits={0,dimsize(Matrix,1)-1,1},proc=RM_ChangeColumn,variable=root:curr_column,title="Column"
	SetVariable ColumnSet userData+=GetWavesDataFolder(Matrix,2)
	Duplicate /O/R=()(0,0) Matrix root:MatrixColumn
	AppendtoGraph MatrixColumn
End

// Auxiliary Function for ReanalyzeMatrix()
Function RM_ChangeColumn(ctrlName,popNum,popStr,other) : SetVariableControl
	String ctrlName; Variable popNum; String popStr,other
	Wave Matrix=$GetUserData("","ColumnSet","")
	Duplicate /O/R=()(popNum,popNum) Matrix root:MatrixColumn
End

Function ZeroToRegion()
	Wave theWave=CsrWaveRef(A)
	WaveStats /Q/R=(xcsr(A),xcsr(B)) theWave
	theWave-=V_avg
End

// Puts on a power law fit computed by taking the logs of the X and Y traces first, then re-exponentiating.  
Function PowerLawFit([graph,trace])
	String graph,trace
	if(ParamIsDefault(graph))
		graph=WinName(0,1)
	endif
	if(ParamIsDefault(trace))
		String traces=TraceNameList(graph,";",3)
		traces=RemoveFromList2("Fit*",traces)
		trace=StringFromList(0,traces)
	endif
	Wave YWave=TraceNameToWaveRef(graph,trace)
	Wave /Z XWave=XWaveRefFromTrace(graph,trace)
	DoUpdate
	GetAxis /Q bottom
	Variable left=V_min,right=V_max
	SetAxis bottom log(left),log(right)
	YWave=log(YWave)
	Variable XWave_exists=waveexists(XWave)
	if(!XWave_exists)
		Duplicate /o YWave,PLF_XWave; Wave XWave=PLF_XWave
		XWave=log(x)
	endif
	CurveFit/Q/M=2/W=0/X line, YWave/X=XWave/D
	Wave Fit=$("fit_"+NameOfWave(YWave))
	Wave /Z FitX=$("fitX_"+NameOfWave(YWave))
	Fit=10^Fit
	if(waveexists(FitX))
		FitX=10^FitX
	else
		Duplicate /o Fit $("fitX_"+NameOfWave(YWave))
		Wave FitX=$("fitX_"+NameOfWave(YWave))
		FitX=10^x
	endif
	YWave=10^YWave
	XWave=10^XWave
	RemoveFromGraph $NameOfWave(Fit)
	AppendToGraph Fit vs FitX
	SetAxis bottom left,right
	KillWaves /Z PLF_XWave
End

// Clears traces from one window; can be a list and can use wildcards.  
Function RemoveTraces([match,except,win,kill])
	String match,except,win
	Variable kill
	if(ParamIsDefault(match))
		match="*"
	endif
	if(ParamIsDefault(except))
		except=""
	endif
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces,trace
	Variable j
	
	Do
		traces=TraceNameList(win,";",3)
		traces=ListMatch2(traces,match)
		traces=RemoveFromList2(except,traces)
		trace=StringFromList(0,traces)
		if(!!strlen(trace))
			Wave w=TraceNameToWaveRef(win,trace)
			RemoveFromGraph /W=$win $trace
			if(kill)
				KillWaves /z w
			endif
		endif
	While (ItemsInList(traces)>1)
End

// Hides (or unhides) traces from one window; can use wildcards
Function HideTraces(hide[,trace_names,except,win,top])
	Variable hide // 1 for hide, 0 for show
	String trace_names,except,win 
	Variable top // If top is 1, only hide/show the top trace
	String traces,trace
	if(ParamIsDefault(trace_names))
		trace_names="*"
	endif
	if(ParamIsDefault(except))
		except=""
	endif
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	if(!ParamIsDefault(top))
		trace=TopTrace(win=win)
		ModifyGraph /W=$win hideTrace($trace)=hide
		return 0
	endif
	traces=TraceNameList(win,";",3)
	traces=ListMatch2(traces,trace_names)
	traces=RemoveFromList2(except,traces)
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		ModifyGraph /W=$win hideTrace($trace)=hide
	endfor
End

// Saves axis values in the graph 'win' with an arbitrary name 'name'.  
Function SaveAxes(name,[win])
	String name,win
	
	win=selectstring(!ParamIsDefault(win),winname(0,1),win)
	string package=win//RemoveEnding(win,"win")
	dfref df=Core#InstanceHome("Acq",package,"win0:"+name,create=1)
	
	string axis_list=AxisList(win)
	variable i
	for(i=0;i<ItemsInList(axis_list);i+=1)
		string axis_name=StringFromList(i,axis_list)
		newdatafolder /o df:$axis_name
		dfref axisDF=df:$axis_name
		if(datafolderrefstatus(axisDF))
			GetAxis /W=$win /Q $axis_name
			variable /G axisDF:min_=V_min
			variable /G axisDF:max_=V_max
			variable /G axisDF:autoscale=AxisAutoscale(axis_name,win=win)
		endif
	endfor
End

// Restores axes from axis set named 'name' in window 'win' to saved values.  
Function RestoreAxes(name,[win])
	String name,win
	
	win=selectstring(!ParamIsDefault(win),winname(0,1),win)
	name=selectstring(strlen(name),"Broad",name)
	string package=win//RemoveEnding(win,"win")
	dfref df=Core#InstanceHome("Acq",package,"win0:"+name)
	
	variable err=0
	if(!datafolderrefstatus(df))
		//printf "Could not find data '%s' to restore axes for window '%s'.\r",name,win
		err=-100
	endif
	string axis_list=AxisList(win)
	variable i
	for(i=0;i<ItemsInList(axis_list);i+=1)
		string axis_name=StringFromList(i,axis_list)
		dfref axisDF=df:$axis_name
		if(datafolderrefstatus(axisDF))
			nvar /z/sdfr=axisDF autoscale,min_,max_
			if(min_==max_ || (nvar_exists(autoscale) && autoscale))
				SetAxis /W=$win /A $axis_name
			else
				SetAxis /W=$win $axis_name min_,max_
			endif
		else
			err-=1
		endif
	endfor
	return err
End

// Returns 1 if the axis is autoscaled and 0 if it is not.  
Function AxisAutoscale(axis[,win])
	String axis,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	return StringMatch(StringByKey("SETAXISFLAGS",AxisInfo(win,axis)),"*/A*")
End

// Returns a string with rgb values for each color used in a graph
Function /S ListGraphColors([graph_name])
	String graph_name
	if(ParamIsDefault(graph_name))
		graph_name=""
	endif
	String traces=TraceNameList(graph_name,";",3)
	Variable i,index; String trace,color,color_list=""
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Variable red,green,blue
		color=GetTraceColor(trace,red,green,blue)
		color=color[0,strlen(color)-2] // Eliminate the trailing semicolon
		color=ReplaceString(";",color,",") // Turn semicolons into commas
		index=WhichListItem(color,color_list)
		if(index==-1) // If a trace of that color has not been seen yet
			color_list+=color+";" // Add it to the list
		endif
	endfor
	return color_list
End

Function CloneAxis(old_name,new_name[,win])
	String old_name,new_name,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String axis_info=AxisInfo(win,old_name)
	Variable recreation_pos=11+strsearch(axis_info,"RECREATION:",0)			
	String command=axis_info[recreation_pos,inf]
	command=ReplaceString("(x)",command,"("+new_name+")")
	command=RemoveEnding(command)
	String axis_flag=StringByKey("AXFLAG",axis_info,":")
	axis_flag=axis_flag[0,1]
	Execute "NewFreeAxis /W="+win+axis_flag+" "+new_name
	Variable i
	for(i=0;i<ItemsInList(command);i+=1)
		String sub_command=StringFromList(i,command)
		Execute "ModifyGraph /W="+win+" "+sub_command
	endfor
End

// Returns the name of the channel that the cursor 'cursor_name' is on.  
Function /S Cursor2Channel([win,cursor_name])
	String win,cursor_name
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	if(ParamIsDefault(cursor_name))
		cursor_name="A"
	endif
	String cursor_info=CsrInfo($cursor_name,win)
	String trace_name=StringByKey("TName",cursor_info)
	String trace_info=TraceInfo(win,trace_name,0)
	String colors=StringByKey("rgb(x)",trace_info,"=")
	colors=colors[1,strlen(colors)-2]
	Variable red=NumFromList(0,colors,sep=",")
	Variable green=NumFromList(1,colors,sep=",")
	Variable blue=NumFromList(2,colors,sep=",")
	String channel=Colors2Channel(red,green,blue)
	return channel
End

Function /S Colors2Channel(red,green,blue)
	Variable red,green,blue
	String channel
	if(red==65535 && green==0 && blue==0)
		channel="R1"
	elseif(red==0 && green==0 && blue==65535)
		channel="L2"
	elseif(red==0 && green==65535 && blue==0)
		channel="B3"
	else
		channel="Unknown"
	endif
	return channel
End

// Applies a multiplicate offset to all the traces of a graph such that their values at x='loc' are normalized to 1.  
Function NormalizeTraces2(loc[,graph])
	Variable loc
	String graph
	if(ParamIsDefault(graph))
		graph=WinName(0,1)
	endif
	String traces=TraceNameList(graph,";",3)
	Variable i,norm_value; String trace
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef(graph,trace)
		norm_value=1/TraceWave(loc)
		ModifyGraph /W=$graph muloffset($trace)={0,norm_value}
	endfor
End

// Removes traces where the value at x=loc is NaN.  
Function RemoveTracesWhereLocIsNaN(loc[,graph])
	Variable loc
	String graph
	if(ParamIsDefault(graph))
		graph=WinName(0,1)
	endif
	Variable i=0,norm_value; String trace
	Do
		String traces=TraceNameList(graph,";",3)
		if(i>=ItemsInList(traces))
			break
		endif
		trace=StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef(graph,trace)
		if(numtype(TraceWave[loc])==2) // If the value at 'loc' is NaN.  
			RemoveFromGraph /W=$graph $trace
		else
			i+=1
		endif
	While(1)
End

Function AxisExists(axis[,win])
	String axis,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String axes=AxisList(win)
	Variable item=WhichListItem(axis,axes)
	return item>=0
End

// Lists the full paths for each trace on the graph
Function ListTraceLocations()
	Variable i
	String trace,traces=TraceNameList("",";",3)
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef("",trace)
		printf "%s,%s.\r",trace,GetWavesDataFolder(TraceWave,2)
	endfor
End

// For a given trace name on a graph, returns the location of the wave that contains the fit (if there is one).  
Function /S FitLocation(trace[,win])
	String trace
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	Wave TraceWave=TraceNameToWaveRef(win,trace)
	String folder=GetWavesDataFolder(TraceWave,1)
	return folder+"fit_"+trace
End

Function RemoveFirstNTraces(n[,win])
	Variable n
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	Variable i
	for(i=0;i<n;i+=1)
		RemoveFromGraph /W=$win $BottomTrace()
	endfor
End

Function RemoveLastNTraces(n[,win])
	Variable n
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	Variable i
	for(i=0;i<n;i+=1)
		RemoveFromGraph /W=$win $TopTrace()
	endfor
End

// Draws vertical lines at the x-values corresponding to the points in a wave
Function DrawWaveLines(lines)
	Wave lines
	Variable i,x
	SetDrawEnv xcoord=bottom, ycoord=prel, save
	for(i=0;i<numpnts(lines);i+=1)
		x=lines[i]
		DrawLine x,0,x,1
	endfor
End

Function XOffset(trace[,win])
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String trace_info=TraceInfo(win,trace,0)
	String offset_str=StringByKey("offset(x)",trace_info,"=")
	offset_str=offset_str[1,strlen(offset_str)-2]
	return str2num(StringFromList(0,offset_str,","))
End

Function YOffset(trace[,win])
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String trace_info=TraceInfo(win,trace,0)
	String offset_str=StringByKey("offset(x)",trace_info,"=")
	offset_str=offset_str[1,strlen(offset_str)-2]
	return str2num(StringFromList(1,offset_str,","))
End

Function XmulOffset(trace[,win])
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String trace_info=TraceInfo(win,trace,0)
	String offset_str=StringByKey("muloffset(x)",trace_info,"=")
	offset_str=offset_str[1,strlen(offset_str)-2]
	return str2num(StringFromList(0,offset_str,","))
End

Function YmulOffset(trace[,win])
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String trace_info=TraceInfo(win,trace,0)
	String offset_str=StringByKey("muloffset(x)",trace_info,"=")
	offset_str=offset_str[1,strlen(offset_str)-2]
	return str2num(StringFromList(1,offset_str,","))
End

// Shifts existing offsets by x and y.  
Function OffsetShift(x,y,[traces,win])
	Variable x,y
	String traces,win
	if(ParamIsDefault(traces))
		traces="*"
	endif
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String trace,trace_list=TraceNameList("",";",3)
	trace_list=ListMatch2(trace_list,traces)
	Variable i,curr_x,curr_y
	for(i=0;i<ItemsInList(trace_list);i+=1)
		trace=StringFromList(i,trace_list)
		curr_x=XOffset(trace,win=win)
		curr_y=YOffset(trace,win=win)
		ModifyGraph /W=$win offset($trace)={curr_x+x,curr_y+y}
	endfor
End

// Sets existing multipliers to x and y (does not consider originals multipliers).  
Function OffsetMultiply(x,y,[traces,win])
	Variable x,y
	String traces,win
	if(ParamIsDefault(traces))
		traces="*"
	endif
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String trace,trace_list=TraceNameList("",";",3)
	trace_list=ListMatch2(trace_list,traces)
	Variable i,curr_x,curr_y
	for(i=0;i<ItemsInList(trace_list);i+=1)
		trace=StringFromList(i,trace_list)
		ModifyGraph /W=$win muloffset($trace)={x,y}
	endfor
End

// Turns axes into log
Function LogOn()
	DoUpdate
	GetAxis /Q left
	ModifyGraph log(left)=1
	SetAxis left, 1,V_max
	//GetAxis /Q bottom
	//SetAxis bottom, 0.1,V_max
	//ModifyGraph log(bottom)=1
End

// Turns axes into linear
Function LogOff()
	ModifyGraph log=0
End

Function ScaleBar(xx,yy,xunits,yunits[,xMult,yMult,x_axis,y_axis,font_size])
	variable xx,yy,xMult,yMult,font_size
	string xunits,yunits,x_axis,y_axis
	
	font_size=ParamIsDefault(font_size) ? 9 : font_size
	xMult=paramisdefault(xMult) ? 1 : xMult
	yMult=paramisdefault(yMult) ? 1 : yMult
	if(ParamIsDefault(x_axis))
		string x_axes=AxisList2("horizontal")
		x_axis=stringfromlist(0,x_axes)
	endif
	if(ParamIsDefault(y_axis))
		string y_axes=AxisList2("vertical")
		y_axis=stringfromlist(0,y_axes)
	endif
	Variable x_min,y_min,x_max,y_max,x_range,y_range
	SetDrawEnv xcoord=$x_axis, ycoord=$y_axis,fstyle=1,save
	DoUpdate
	GetAxis /Q $y_axis; y_min=V_min; y_max=V_max; y_range=V_max-V_min
	GetAxis /Q $x_axis; x_min=V_min; x_max=V_max; x_range=V_max-V_min
	DrawLine x_max,y_max,x_max,y_max-yy
	DrawLine x_max-xx,y_max-yy,x_max,y_max-yy
	//DrawLine 1,y/y_range,1-x/x_range,y/y_range
	//DrawLine 1-x/x_range,y/y_range,1-x/x_range,0
	SetDrawEnv textxjust=1, textyjust=2, fsize=font_size
	DrawText x_max-xx/2,y_max-yy,num2str(xx*xMult)+" "+xunits
	SetDrawEnv textxjust=0, textyjust=1, fsize=font_size
	DrawText x_max,y_max-yy/2," "+num2str(yy*yMult)+" "+yunits
End

Function HideAxes([hide,axes,win])
	variable hide // Hide=1, Show=0, Toggle=-1
	string axes,win
	
	win=selectstring(!paramisdefault(win),winname(0,1),win)
	hide=ParamIsDefault(hide) ? 1 : hide
	if(hide==-1)
		if(paramisdefault(axes))
			axes=AxisList(win)
		endif
		string axis=stringfromlist(0,axes)
		string info=AxisInfo(win,axis)
		variable noLabel=numberbykey("nolabel(x)",info,"=",";")
		if(noLabel)
			HideAxes(hide=0,axes=axes,win=win)
		else
			HideAxes(hide=1,axes=axes,win=win)
		endif
		return 0
	endif
	if(ParamIsDefault(axes))
		if(hide)
			ModifyGraph /Z/W=$win noLabel=2,axThick=0
		else
			ModifyGraph /Z/W=$win noLabel=0,axThick=1
		endif
	else
		variable i
		for(i=0;i<ItemsInList(axes);i+=1)
			axis=StringFromList(i,axes)
			if(hide==1)
				ModifyGraph /Z/W=$win noLabel($axis)=2,axThick($axis)=0
			else
				ModifyGraph /W=$win noLabel($axis)=0,axThick($axis)=1
			endif
		endfor
	endif
End

// Turns the axes white, and also hides the tick marks and the labels.  
Macro DisguiseAxes()
	ModifyGraph nticks=0,noLabel=2,axRGB=(65535,65535,65535);DelayUpdate
	ModifyGraph tlblRGB=(65535,65535,65535),alblRGB=(65535,65535,65535);DelayUpdate
End

Function KillWin()
	String win_name=WinName(0,1)
	DoWindow /K $win_name
End

Function RenameWindowAfterTopTrace()
	String title=TopTrace()
	if(strlen(TopTrace())==0)
		title=TopImage()
	endif
	Title=CleanUpName("W"+Title,0)
	DoWindow /C $Title	
End

Function AddTitle()
	String title=TopTrace()
	if(strlen(TopTrace())==0)
		title=TopImage()
		TextBox /A=LB/E=2/N=Title/X=0/Y=0 title
	else
		TextBox /A=LT/E=2/N=Title/X=0/Y=0 title
	endif
End

Function /S GetTrace(num)
	Variable num
	String traces=TraceNameList("",";",3)
	return StringFromList(num,traces)
End

// Returns the name of the trace on the top graph with "mean" in the name
Function /S GetMeanTrace()
	String traces=TraceNameList("",";",3)
	Variable i=0
	String trace
	Do
		trace=StringFromList(i,traces)
		if(StringMatch(trace,"*mean*"))
			break
		endif
		i+=1
	While(i<ItemsInList(traces))
	return trace
End

Function AccommodateMargins(value,layout_info,direction)
	Variable value
	String layout_info,direction
	String paper_info=StringByKey("PAPER",layout_info)
	String page_info=StringByKey("PAGE",layout_info)
	Variable paper,page,margin
	strswitch(direction)
		case "x":
			paper=str2num(StringFromList(2,paper_info,","))-str2num(StringFromList(0,paper_info,","))
			page=str2num(StringFromList(2,page_info,","))-str2num(StringFromList(0,page_info,","))
			margin=str2num(StringFromList(0,page_info,","))-str2num(StringFromList(0,paper_info,","))
			break
		case "y":
			paper=str2num(StringFromList(3,paper_info,","))-str2num(StringFromList(1,paper_info,","))
			page=str2num(StringFromList(3,page_info,","))-str2num(StringFromList(1,page_info,","))
			margin=str2num(StringFromList(1,page_info,","))-str2num(StringFromList(1,paper_info,","))
			break
			break
		default: 
			printf "Not a direction [AccomodateMargins].\r"  
			break
	endswitch	
	value=(margin+value*page)/paper
	return value
End

Function CursorExists(csr[,win])
	string csr,win
	
	win=selectstring(!paramisdefault(win),WinName(0,1),win)
	variable result=0
	if(wintype(win))
		string info=CsrInfo($csr,win)
		result=strlen(info)>0
	endif
	return result
End

Function AnnotationExists(name[,win])
	String name,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String annotations=AnnotationList(win)
	return WhichListItem(name,annotations)>=0
End

Function KillTags([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String annotations=AnnotationList(win)
	Variable i; String annotation,info,type
	for(i=0;i<ItemsInList(annotations);i+=1)
		annotation=StringFromList(i,annotations)
		info=AnnotationInfo(win,annotation)
		type=StringByKey("TYPE",info)
		if(StringMatch(type,"Tag"))
			TextBox /K /N=$annotation
		endif
	endfor
End
	
Function AlignTraces(x1,x2[win,match,except])
	Variable x1,x2 // Align the region between x1 and x2 to have value 0.  
	String win,match,except
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	if(ParamIsDefault(match))
		match="*"
	endif
	if(ParamIsDefault(except))
		except=""
	endif
	String traces=TraceNameList(win,";",3)
	traces=ListMatch(traces,match)
	traces=RemoveFromList(except,traces)
	Variable i; String trace
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave traceWave=TraceNameToWaveRef(win,trace)
		WaveStats /Q /R=(x1,x2) traceWave
		ModifyGraph offset($trace)={XOffset(trace,win=win),-V_avg}
	endfor
End

Function RemoveTracesByColor(red2,green2,blue2[,win])
	Variable red2,green2,blue2
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String color,trace,traces=TraceNameList(win,";",3)
	Variable i=0
	Do
		trace=StringFromList(i,traces)
		Variable red,green,blue
		color=GetTraceColor(trace,red,green,blue,win=win)
		if(red2==red && blue2==blue && green2==green)
			RemoveFromGraph /W=$win $trace
		else
			i+=1
		endif
		traces=TraceNameList(win,";",3)
	While(i<ItemsInList(traces))
	RemoveFromGraph
End

// Will apply the formatting code 'code' to all selected layout objects (use Control-A).  
// Not implemented yet.  
Function FormatLayoutAxisLabels(code)
	String code
	String info=LayoutInfo("","Layout")
	String object,objects=StringByKey("SELECTED",info)
	Variable i
	for(i=0;i<ItemsInList(objects);i+=1)
		object=StringFromList(i,objects)
	endfor
End

Function TraceLoc(flag[,sep])
	Variable flag // 0 for one trace, 1 for all traces, 2 for the X-wave of the selected trace.  
	String sep // The list separator.  
	if(ParamIsDefault(sep))
		sep=";"
	endif
	switch(flag)
		case 0:
			GetLastUserMenuInfo
			PutScrapText GetWavesDataFolder(TraceNameToWaveRef("",S_tracename),2)
			break
		case 1:
			String traces=TraceNameList("",";",3)
			Variable i;String trace,scrap_text=""
			for(i=0;i<ItemsInList(traces);i+=1)
				trace=StringFromList(i,traces)
				scrap_text+=GetWavesDataFolder(TraceNameToWaveRef("",trace),2)+sep
			endfor
			PutScrapText scrap_text[0,strlen(scrap_text)-2] // Remove final separator.  
			break
		case 2: 
			GetLastUserMenuInfo
			PutScrapText GetWavesDataFolder(XWaveRefFromTrace("",S_tracename),2)
			break
	endswitch
End

// Draw a unity line
Function UnityLine()
	DoUpdate
	GetAxis /Q left; Variable left1=V_min,left2=V_max
	GetAxis /Q bottom; Variable bottom1=V_min,bottom2=V_max
	Variable minn=max(left1,bottom1), maxx=min(left2,bottom2)
	DrawLine2(minn,minn,maxx,maxx)
End

// Draws a line using the principal axes as basis for coordinates.  
Function DrawLine2(x1,y1,x2,y2)
	Variable x1,y1,x2,y2
	SetDrawEnv xcoord=bottom, ycoord=left
	DrawLine x1,y1,x2,y2
End

Macro FixLayout()
	ModifyLayout frame=0,trans=1
End

// Returns the x position (between 0 and 1) of the center of a bar given the category and bar details.  
Function BarCenter(catNum,barNum,catGap,barGap,numBars)
	variable catNum,barNum,catGap,barGap,numBars
	
	if(numBars>1)
		variable xx=catNum+catGap/2+(barNum+0.5)*(1-barGap)*(1-catGap)/numBars+barNum*barGap*(1-catGap)/(numBars-1) // The middle of the bar.  
	else
		xx=catNum+catGap/2+(barNum+0.5)*(1-barGap)*(1-catGap)
	endif
	return xx
End

Function /S CloneWindow([win,replace,with,freeze,name])
	String win
	String replace,with // Replace some string in the windows recreation macro with another string.  
	Variable freeze // Make a frozen clone (basically just a picture).  
	string name // Name for new window.  
	
	if(ParamIsDefault(replace) || ParamIsDefault(with))
		replace=""; with=""
	endif
	if(ParamIsDefault(win))
		win=WinName(0,5)
	endif
	String win_rec=WinRecreation(win,0)
	Variable i
	for(i=0;i<ItemsInList(replace);i+=1)
		String one_replace=StringFromList(i,replace)
		String one_with=StringFromList(i,with)
		win_rec=ReplaceString(one_replace,win_rec,one_with)
	endfor
	if(freeze)
		Struct rect coords
		Core#GetWinCoords(win,coords)
		SavePICT /WIN=$win as "Clipboard"
		String newName=UniqueName(win,6,0)
		LoadPICT /O/Q "Clipboard",$newName
		Display /N=$newName /W=(coords.left,coords.top,coords.right,coords.bottom)
		DrawPICT /W=$newName 0,0,1,1,$newName
	else	
		Execute /Q win_rec
	endif
	if(!paramisdefault(name))
		name=cleanupname(name,0)
		if(wintype(name))
			name=uniquename(name,6,0)
		endif
		DoWindow /C $name
	else
		name = winname(0,5)
	endif
	return name
End

// Like CloneWindow, but replaces all the traces with copies and puts those copies in one data folder.  
Function CloneWindow2([win,name,times])
	String win
	String name // The new name for the window and data folder. 
	Variable times // The number of clones to make.  Clones beyond the first will have _2, _3, etc. appended to their names.   
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	if(ParamIsDefault(name))
		name=UniqueName2(win,"6;11")
	else
		name=CleanupName(name,0)
	endif
	times=ParamIsDefault(times) ? 1 : times
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:$name
	String traces=TraceNameList(win,";",3)
	Variable i,j
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace=StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef(win,trace)
		Wave /Z TraceXWave=XWaveRefFromTrace(win,trace)
		Duplicate /o TraceWave $NameOfWave(TraceWave)
		if(waveexists(TraceXWave))
			Duplicate /o TraceXWave $NameOfWave(TraceXWave)
		endif
	endfor
	String win_rec=WinRecreation(win,0)
	
	// Copy error bars if they exist.  Won't work with subrange display syntax.  
	for(i=0;i<ItemsInList(win_rec,"\r");i+=1)
		String line=StringFromList(i,win_rec,"\r")
		if(StringMatch(line,"*ErrorBars*"))
			String errorbar_names
			sscanf line,"%*[^=]=(%[^)])",errorbar_names
			for(j=0;j<2;j+=1)
				String errorbar_path=StringFromList(j,errorbar_names,",")
				sscanf errorbar_path,"%[^[])",errorbar_path
				String errorbar_name=StringFromList(ItemsInList(errorbar_path,":")-1,errorbar_path,":")
				Duplicate /o $("root"+errorbar_path) $errorbar_name
			endfor
		endif
	endfor
	
	for(i=1;i<=times;i+=1)
		Execute /Q win_rec
		if(i==1)
			DoWindow /C $name
		else
			DoWindow /C $(name+"_"+num2str(i))
		endif
		ReplaceWave allInCDF
	endfor
	SetDataFolder $curr_folder
End

Function /S FindGraph(graph_name)
	String graph_name
	String matching_graphs=WinList("*"+graph_name+"*",";","WIN:1")
	graph_name=StringFromList(0,matching_graphs)
	return graph_name
End

// Puts labels on the x-axis that are 10 to the value currently shown
Function LogXAxisLabels()
	DoUpdate
	GetAxis /Q bottom
	Variable range=floor(V_max)-ceil(V_min)+1
	Make /o/n=(range) LogTicks
	Make /T/o/n=(range) LogTicksLabels
	Variable i,minn=ceil(V_min)
	for(i=0;i<range;i+=1)
		LogTicks[i]=minn+i
		LogTicksLabels[i]=num2str(10^(minn+i))
	endfor
	ModifyGraph userticks(bottom)={LogTicks,LogTicksLabels}
End

// Renames the window so it has the same name as the folder containing the topmost trace.
Function RenameWindowLikeFolder()
	DoWindow /C $GetWavesDataFolder(TopWave(),0)
End

// Makes a table containing all the traces of the graph (top-most trace on the right)
Function Graph2Table([graph,match])
	String graph,match
	if(ParamIsDefault(graph))
		graph=WinName(0,1)
	endif
	if(ParamIsDefault(match))
		match="*"
	endif
	String traces=TraceNameList(graph,";",3)
	traces=ListMatch(traces,match)
	Edit /K=1 /N=$(graph+"_Table")
	Variable i; String trace
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave theWave=TraceNameToWaveRef(graph,trace)
		AppendToTable theWave
	endfor
End

// Titles the graph and adds a text box according to the folder of topmost trace.  
Function GraphTitleByFolder()
	String graphs=WinList("*",";","WIN:1")
	Variable i; String graph,trace,folder
	for(i=0;i<ItemsInList(graphs);i+=1)
		graph=StringFromList(i,graphs)
		trace=TopTrace(win=graph)
		Wave TraceWave=TraceNameToWaveRef(graph,trace)
		folder=GetWavesDataFolder(TraceWave,0)
		DoWindow /F $graph
		DoWindow /C $folder
		Textbox folder
	endfor
End

// Returns a string containing the name of the topmost graph that contains the given trace
Function /S FindTrace(trace_to_find)
	String trace_to_find
	String wins=WinList("*",";","WIN:1")
	Variable i,j; String win,traces,trace
	for(i=0;i<ItemsInList(wins);i+=1)
		win=StringFromList(i,wins)
		traces=TraceNameList(win,";",3)
		for(j=0;j<ItemsInList(wins);j+=1)
			trace=StringFromList(j,traces)
			if(StringMatch(trace,trace_to_find))
				return win
			endif
		endfor	
	endfor
	return ""
End

// Returns the vertical position of the cursor relative the axis, rather than the actual value of the wave at that point.  
Function vcsr2(cursor_name[,win])
	string cursor_name,win
	
	win=selectstring(!paramisdefault(win),winname(0,1),win)
	Variable free=str2num(StringByKey("ISFREE",CsrInfo($cursor_name,win)))
	if(free)
		return vcsr($cursor_name,win)
	else
		return vcsr($cursor_name,win)+YOffset(CsrWave($cursor_name,win),win=win)
	endif
End

Function CloneGraph([graph_name])
	String graph_name
	if(ParamIsDefault(graph_name))
		graph_name=WinName(0,1)
	endif
	String win_rec=WinRecreation(graph_name,0)
	Execute /Q win_rec
End

Function CloneLayout([layout_name])
	String layout_name
	if(ParamIsDefault(layout_name))
		layout_name=WinName(0,4)
	endif
	Preferences 1
	String win_rec=WinRecreation(layout_name,0)
	Execute /Q win_rec
End

// Graphs the quotient of the top two waves
Function GraphQuotient([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	String trace1=StringFromList(ItemsInList(traces)-1,traces)
	String trace2=StringFromList(ItemsInList(traces)-2,traces)
	Wave TraceWave1=TraceNameToWaveRef(win,trace1)
	Wave TraceWave2=TraceNameToWaveRef(win,trace2)
	WaveStats /Q TraceWave1; Variable maxx1=V_max
	WaveStats /Q TraceWave2; Variable maxx2=V_max
	String quotient_name=UniqueName("QuotientWave",1,0)
	Duplicate /o TraceWave1 $quotient_name
	Wave QuotientWave=$quotient_name
	if(maxx1>=maxx2)
		QuotientWave=TraceWave1/TraceWave2
	else
		QuotientWave=TraceWave2/TraceWave1
	endif
	QuotientWave=log(QuotientWave)
	Display /K=1 /N=$(win+"_q") QuotientWave
	//ModifyGraph log(left)=1
End

// Graphs the difference of the top two waves
Function GraphDifference([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	String trace1=StringFromList(ItemsInList(traces)-1,traces)
	String trace2=StringFromList(ItemsInList(traces)-2,traces)
	Wave TraceWave1=TraceNameToWaveRef(win,trace1)
	Wave TraceWave2=TraceNameToWaveRef(win,trace2)
	WaveStats /Q TraceWave1; Variable maxx1=V_max
	WaveStats /Q TraceWave2; Variable maxx2=V_max
	String Difference_name=UniqueName("DifferenceWave",1,0)
	Duplicate /o TraceWave1 $Difference_name
	Wave DifferenceWave=$Difference_name
	if(maxx1>=maxx2)
		DifferenceWave=TraceWave1-TraceWave2
	else
		DifferenceWave=TraceWave2-TraceWave1
	endif
	Display /K=1 /N=$(win+"_d") DifferenceWave
End

Function WindowKillHook(info)
	String info
	String win_name,events,user_data,instruction,type,data,folder
	Variable i
	events=StringByKey("EVENT",info)
	if(StringMatch(events,"kill"))
		win_name=StringByKey("WINDOW",info)
		user_data=GetUserData(win_name,"","")
		for(i=0;i<ItemsInList(user_data);i+=1)
			instruction=StringFromList(i,user_data)
			type=StringFromList(0,instruction,"=")
			data=StringFromList(1,instruction,"=")
			strswitch(type)
				case "KillFolder":
					folder=FindFolder(data)
					if(!IsEmptyString(folder))
						Execute /P/Q "KillDataFolder /Z "+folder
					endif
					break
				case "KillWave":
					Execute /P/Q "KillWaves /Z "+data
					break
			endswitch
		endfor
	endif
End

// Like ReorderTraces, but takes a string of all the traces as input
Function ReorderTraces2(traces[,win])
	String traces,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	traces=ReplaceSeparator(traces,";",",")
	Execute /Q "ReorderTraces "+StringFromList(0,traces)+", {"+traces+"}"
End

Function /S GetAxisEnab(axis[,win])
	String axis,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String axis_info=AxisInfo(win,axis)
	String enab_info=StringByKey("axisEnab(x)",axis_info,"=")
	enab_info=ReplaceString(",",enab_info,";")
	return enab_info[1,strlen(enab_info)-2]
End

// Makes the axes in axis_list have the same value in each window in win_list 
Function HarmonizeAxes(win_list,axis_list)
	String win_list,axis_list
	Variable i,j,axis_min=Inf,axis_max=-Inf
	String win,axis
	for(i=0;i<ItemsInList(axis_list);i+=1)
		axis=StringFromList(i,axis_list)
		for(j=0;j<ItemsInList(win_list);j+=1)
			win=StringFromList(j,win_list)
			GetAxis /Q /W=$win $axis
			axis_min=min(axis_min,V_min)
			axis_max=max(axis_max,V_max)
		endfor
		for(j=0;j<ItemsInList(win_list);j+=1)
			win=StringFromList(j,win_list)
			SetAxis /W=$win $axis axis_min,axis_max
		endfor
	endfor
End

Function /S List2Legend(list,traces[,sep])
	String list,traces,sep
	if(ParamIsDefault(sep))
		sep=";"
	endif
	Variable i; String item,trace,legend_str=""
	for(i=0;i<ItemsInList(list,sep);i+=1)
		item=StringFromList(i,list,sep)
		trace=StringFromList(i,traces,sep)
		legend_str+="\\s("+trace+") "+item+"\r"
	endfor
	legend_str=RemoveEnding(legend_str,"\r")
	return legend_str
End

// Returns the channel name, based on which folder the wave is in.  
Function /S Wave2Channel(theWave)
	Wave theWave
	String folder=GetWavesDataFolder(theWave,0)
	return folder
End

// Puts graphs onto layouts
Function Graphs2Layouts(num_per_layout) 
	Variable num_per_layout // Number of graphs per layout
	String list=WinList("*",";","WIN:1") // List of all open graphs
	Variable i
	String win_name,textbox_name
	Variable graph_number, position
	for(i=0;i<ItemsInList(list);i+=1)
		graph_number=mod(i,num_per_layout)
		if(graph_number==0)
			NewLayout /K=1
		endif
		win_name=StringFromList(i,list)
		AppendLayoutObject graph $win_name
		textbox_name=win_name+"_text"
		TextBox /A=RT /N=$textbox_name win_name // Make a text box that says what window is displayed
		position=100+graph_number*200
		ModifyLayout top($win_name)=position, top($textbox_name)=position
	endfor
End

function HideWindows(match)
	string match
	
	Variable i,j
	for(i=0;i<ItemsInList(match);i+=1)
		String oneMatch=StringFromList(i,match)
		String list=WinList(oneMatch,";","")
		for(j=0;j<ItemsInList(list);j+=1)
			String win=StringFromList(j,list)
			if(stringmatch(win,"*.ipf") || stringmatch(win,"*.ihf"))
			else
				DoWindow /HIDE=1 $win
			endif
		endfor
	endfor
end

Function KillWindows(match)
	String match
	
	Variable i,j
	for(i=0;i<ItemsInList(match);i+=1)
		String oneMatch=StringFromList(i,match)
		String list=WinList(oneMatch,";","")
		for(j=0;j<ItemsInList(list);j+=1)
			String win=StringFromList(j,list)
			DoWindow /K $win
		endfor
	endfor
End

Function KillAll(to_kill[,match,except])
	String to_kill,match,except
	
	if(ParamIsDefault(match))
		match="*"
	endif
	if(ParamIsDefault(except))
		except=""
	endif
	String list
	Variable i
	for(i=0;i<ItemsInList(match);i+=1)
		String matchItem=StringFromList(i,match)
		strswitch(to_kill)
			case "windows":
				list=ListGraphs(match=matchItem)+ListLayouts(match=matchItem)+ListTables(match=matchItem)+ListPanels(match=matchItem)
				break
			case "graphs":
				list=ListGraphs(match=matchItem)
				break
			case "layouts":
				list=ListLayouts(match=matchItem)
				break
			case "tables":
				list=ListTables(match=matchItem)
				break
			case "notebooks":
				list=ListNotebooks(match=matchItem)
				break
			case "panels":
				list=ListPanels(match=matchItem)
				break
			default:
				printf "Parameter not recognized.\r"
				return 0
		endswitch
	endfor
	list=UniqueList(list)
	for(i=0;i<ItemsInList(except);i+=1)
		String exceptItem=StringFromList(i,except)
		Variable j=0
		Do
			String listItem=StringFromList(j,list)
			if(StringMatch(listItem,exceptItem))
				list=RemoveFromList(listItem,list)
			else
				j+=1
			endif
		While(j<ItemsInList(list))
	endfor
	for(i=0;i<ItemsInList(list);i+=1)
		listItem=StringFromList(i,list)
		if(StringMatch(listItem,"Sweeps"))
			Textbox /C/N=TimeStamp/V=1
			DoUpdate
		endif
		DoWindow /K $listItem
	endfor
	DoWindow /K ReverbPrintoutManagerWin
End

Function /WAVE TopWave([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	String top_trace=StringFromList(ItemsInList(traces)-1,traces)
	if(strlen(top_trace))
		//return GetWavesDataFolder(TraceNameToWaveRef(win,top_trace),2)
		return TraceNameToWaveRef(win,top_trace)
	else
		return $""
	endif
End

Function /wave TopImageWave([win])
	string win
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	string imagename=TopImage(win=win)
	wave w=imagenametowaveref(win,imagename)
	return w
End

Function /WAVE TopXWave([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	String top_trace=StringFromList(ItemsInList(traces)-1,traces)
	if(strlen(top_trace))
		//return GetWavesDataFolder(TraceNameToWaveRef(win,top_trace),2)
		return XWaveRefFromTrace(win,top_trace)
	else
		return $""
	endif
End

Function /S TopTrace([win,xaxis,yaxis,visible,number])
	String win,xaxis,yaxis
	Variable visible,number
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	Variable i
	for(i=ItemsInList(traces)-1;i>=0;i-=1)
		String trace=StringFromList(i,traces)
		Variable match=1
		String trace_info=TraceInfo(win,trace,0)
		if(!ParamIsDefault(xaxis))
			String traceXAxis=StringByKey("XAXIS",trace_info)
			match*=StringMatch(xaxis,traceXAxis)
		endif
		if(!ParamIsDefault(yaxis))
			String traceYAxis=StringByKey("YAXIS",trace_info)
			match*=StringMatch(yaxis,traceYAxis)
		endif
		if(!ParamIsDefault(visible))
			Variable hidden=str2num(StringByKey("hideTrace(x)",trace_info,"="))
			match*=(visible!=hidden)
		endif
		if(match)
			if(number<=0)
				return trace
			else
				number-=1
			endif
		endif
	endfor
	return ""
End

Function /S BottomTrace([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	return StringFromList(0,traces)
End

// Returns the top trace which has axis as one of its axes.  
Function /S TopAxisTrace(axis[,win])
	String axis,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	Variable i; String trace,info,axes
	for(i=ItemsInList(traces)-1;i>=0;i-=1)
		trace=StringFromList(i,traces)
		info=TraceInfo(win,trace,0)
		axes=StringByKey("XAXIS",info)+";"+StringByKey("YAXIS",info)
		if(WhichListItem(axis,axes)>=0)
			return trace
		endif
	endfor
	return ""
End

//Sets axes of plots
Function SetAxesRange(x_min,x_max)
	Variable x_min,x_max
	Variable cushion=0.1 // Set the axes to be this factor more than high and low values of the traces
	String list=GraphList()
	String graph,traces,trace
	Variable i,j,y_min,y_max,temp_min,temp_max
	String y_min_list,y_max_list
	for(i=0;i<ItemsInList(list);i+=1)
		graph=StringFromList(i,list)
		y_min_list=""
		y_max_list=""
		DoWindow /F $graph
		traces=TraceNameList("",";",3)
		if(!IsEmptyString(traces))
			SetAxis bottom, x_min, x_max
			for(j=0;j<ItemsInList(traces);j+=1)
				trace=StringFromList(j,traces)
				Wave trace_wave=TraceNameToWaveRef("",trace)
				//WaveStats /Q/R=(x_min,x_max) trace_wave // Get stats on that trace
				//temp_min=V_min; temp_max=V_max
				// For synapses, to exclude the artifact from this calculation.  Use above lines otherwise
					WaveStats /Q/R=(0.02,x_max) trace_wave
					temp_min=V_min; temp_max=V_max
					WaveStats /Q/R=(-0.005,-0.001) trace_wave
					temp_min=min(temp_min,V_avg); temp_max=max(temp_max,V_avg)
				y_min_list=Append2List(num2str(temp_min),y_min_list)
				y_max_list=Append2List(num2str(temp_max),y_max_list)
			endfor
			y_min=MinList(y_min_list)
			y_max=MaxList(y_max_list)
			y_min-=cushion*(y_max-y_min); 
			y_max+=cushion*(y_max-y_min)
			SetAxis left, y_min, y_max
		endif
	endfor
End

Function LastInstance([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String instance,trace=TopTrace(win=win)
	instance=StringFromList(1,trace,"#")
	if(IsEmptyString(instance))
		return 0
	else
		return str2num(instance)
	endif
End



Function /S GetTraceDataFolder(trace_name[,win])
	String trace_name,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	Wave theWave=TraceNameToWaveRef(win,trace_name)
	return GetWavesDataFolder(theWave,0)
End

// Returns the name of the first trace in the top window corresponding to a wave name with full path
Function /S TraceFromWave(full_path_name)
	String full_path_name
	String traces=TraceNameList("",";",3)
	Variable i
	String trace,one_path
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		one_path=GetWavesDataFolder(TraceNameToWaveRef("",trace),2) // Prints the full path including the wave name
		if(!cmpstr(full_path_name,one_path)) // If they match
			return trace
		endif
	endfor
	return ""
End

Function BigDots([size])
	Variable size
	size=ParamIsDefault(size) ? 5 : size
	ModifyGraph mode=2;DelayUpdate
	ModifyGraph lsize=size
End

// Hightlight the trace with cursor A on it
Function HighlightTrace([whiten])
	String whiten // To make all other traces white (invisible on a white background)
	String trace
	LightenTraces(2)
	trace=CsrWave(A)
	Wave trace_wave=CsrWaveRef(A)
	//RemoveFromGraph $trace
	//AppendToGraph /C=(65535,0,0) trace_wave
	Cursor A, $trace,0.2
End

Function LightenTraces(factor[,traces,except,win])
	Variable factor
	String traces,except,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	if(factor<=1)
		printf "Factor must be >= 0.\r"
		return 0
	endif
	if(ParamIsDefault(traces))
		traces=TraceNameList(win,";",1)
	endif
	if(ParamIsDefault(except))
		except=""
	endif
	traces=RemoveFromList2(except,traces)
	Variable i, red, green, blue
	String trace,color
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		color=GetTraceColor(trace,red,green,blue,win=win)
		ModifyGraph /W=$win rgb($trace)=(65535-(65535-red)/factor,65535-(65535-green)/factor,65535-(65535-blue)/factor) // Doesn't change any of the colors.  Fix this however you want.  
	endfor
End

Function ExtractCoordsFromWinRec(winRec,rect)
	String winRec
	Struct rect &rect
	
	Variable i=0
	Do
		String line=StringFromList(i,winRec,"\r")
		if(!strlen(line))
			break
		endif
		if(strsearch(line,"Display",0)>=0)
			Variable left,top,right,bottom
			sscanf line,"\tDisplay /W=(%f,%f,%f,%f)",left,top,right,bottom
			rect.left=left
			rect.top=top
			rect.right=right
			rect.bottom=bottom
			break
		endif
		i+=1
	While(1)
	if(right>left && bottom>top)
		return 0
	else
		return -1
	endif
End

Function CalcAvg(identifier) // For calculating or recalculating an average wave from waves on a graph
	String identifier // A unique identifying piece of the name of the trace that has the average
	Variable num_traces=ItemsInList(TraceNameList("",";", 1)) // How many traces in the plot?
	Variable i
	String trace_name
	String traces
	Variable cursorA=xcsr(A); variable cursorB=xcsr(B) // Store the current locations of the cursors
	traces=TraceNameList("",";", 1) // A list of the names of traces on the graph
	for(i=0;i<num_traces;i+=1)
		trace_name=StringFromList(i,traces) // The name of the ith trace
		if(strsearch(trace_name,identifier,0)!=-1) // Did that trace contain the identifier string?
			break // Then move on
		endif
	endfor
	Variable avg_trace_location=i // The location of the average trace (if it was found)
	if(avg_trace_location==num_traces) // In case it was never found (i reached it's maximum value)
		printf "No trace with that identifier in the plot; making new average trace using that identifier.\r"
		Wave first_wave=WaveRefIndexed("",0,1) // The first wave on the plot
		String folder=GetWavesDataFolder(first_wave,1) // The folder that the first wave is in
		Duplicate /o first_wave $(folder+WinName(0,1)+"_"+identifier) // Make an average wave resembling the first wave
		Wave avg=$(folder+WinName(0,1)+"_"+identifier)
	else
		Wave avg=WaveRefIndexed("",avg_trace_location,1); // A reference to the average trace
	endif
	String avg_wavename=StringFromList(avg_trace_location,traces)
	
	Wave XWave=CsrXWaveRef(A)
	if(!waveexists(XWave))
		Cursors()
		Wave XWave=CsrXWaveRef(A)
	endif
	RemoveFromGraph /Z $avg_wavename // Get rid of the average trace
	num_traces=ItemsInList(TraceNameList("",";", 1))
	avg=0 // Set it to zero
	for(i=0;i<num_traces;i+=1) // Recompute the average trace
		if(i!=avg_trace_location) // Include all y-valued traces except the average trace in the average
			Wave toBeAdded=WaveRefIndexed("",i,1)
			avg+=toBeAdded
		endif
	endfor
	avg/=(num_traces) // Divide by the total number of traces that weren't the average trace
	
	if(waveexists(XWave))
		AppendToGraph /C=(0,0,65535) avg vs XWave // Bring it back to the forefront
	else
		AppendToGraph /C=(0,0,65535) avg // Bring it back to the forefront
	endif
	trace_name=WinName(0,1)+"_"+identifier
	CursorPlace(cursorA,cursorB,trace_name=trace_name) // Put the cursors back where they were
End

// Returns a string containing the color of the trace in semi-colon separated rgb format.  
Function /S GetTraceColor(trace_name,red,green,blue[,win])
	String trace_name,win
	Variable &red,&green,&blue
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	string color=StringByKey("rgb(x)",TraceInfo(win,trace_name,0),"=")
	color=color[1,strlen(color)-2] // Eliminates the parentheses around the color name.   
	color=ReplaceSeparator(color,",",";")
	red=NumFromList(0,color)
	green=NumFromList(1,color)
	blue=NumFromList(2,color)
	return color
End

Function /S TraceColour(graph,trace,red,green,blue)
    String graph, trace
    Variable &red,&green,&blue
   
    String color=StringByKey("rgb(x)",TraceInfo(graph,trace,0),"=")
    sscanf color,"(%d,%d,%d)",red,green,blue
End

// Hightlight the trace with cursor A on it to a list
Function AddTrace2List(list_name [,remoove])
	String list_name
	Variable remoove
	SVar list=$list_name
	list+=CsrWave(A)+";"
	if(!ParamIsDefault(remoove))
		RemoveFromGraph $CsrWave(A)
	endif
End

Function PlotPairsWithLines(wave1,wave2)
	Wave wave1,wave2
	Variable i
	Display /K=1
	String curr_folder=GetDataFolder(1)
	NewDataFolder /o/s root:PairsWithLines
	Make /o/n=2 x_wave
	x_wave[0]=0
	x_wave[1]=1
	String name
	for(i=0;i<numpnts(wave1);i+=1)
		name=StripChars(NameofWave(wave1),2)
		Make /o/n=2 $(name+"_"+num2str(i))
		Wave theWave=$(name+"_"+num2str(i))
		theWave[0]=wave1[i]
		theWave[1]=wave2[i]
		AppendToGraph theWave vs x_wave
	endfor
	ModifyGraph mode=4,marker=19
	SetAxis bottom -0.2,1.2 
	Label left "ms"
	Label bottom "Control ... Drug"
	SetDataFolder curr_folder
End

// A better histogram command, it doesn't make you prepare a destination wave first.  
// Makes a histogram with 'numbins' bins out of the wave with the cursors on it, or 'theWave' if provided.  
Function Histogram2(numbins[,theWave,cursors])
	Variable numbins
	Wave theWave
	Variable cursors // Whether or not to use the cursors as boundaries for values to include.
	if(ParamIsDefault(theWave))
		Wave theWave=CsrWaveRef(A)
	endif
	Make /o/n=(numbins) $(NameOfWave(theWave)+"_hist")
	Wave hist=$(NameOfWave(theWave)+"_hist")
	Variable left,right
	if(cursors)
		left=xcsr(A)
		right=xcsr(B)
	else
		left=leftx(theWave)
		right=rightx(theWave)
	endif
	Histogram /B=1 /R=(left,right) theWave,hist
	Display /K=1 hist
	ModifyGraph mode=5
End

// Returns the name of the top trace for which the given index exists and is not a NaN
Function /S TopValuedTrace(index,[win])
	Variable index
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3),trace
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		if(IsTraceValued(index,trace,win=win))
			return trace
		endif
	endfor
	return ""
End

// Returns the truth as to whether the trace both has more than index points and is not a NaN at point index.  
Function IsTraceValued(index,trace,[win])
	Variable index
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	Wave TraceWave=TraceNameToWaveRef(win,trace)
	if(numpnts(TraceWave)>index && !IsNaN(TraceWave[index]))
		return 1
	else
		return 0
	endif
End

// Returns the top-most trace that is not hidden
Function /S TopVisibleTrace([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3),trace
	Variable i
	for(i=ItemsInList(traces)-1;i>=0;i-=1)
		trace=StringFromList(i,traces)
		if(IsTraceVisible(trace,win=win))
			return trace
		endif
	endfor
	return ""
End

// Returns the truth as to whether the trace is visible (not hidden)
Function IsTraceVisible(trace,[win])
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String info=TraceInfo(win,trace,0)
	Variable hidden=str2num(StringByKey("hideTrace(x)",info,"="))
	return !hidden
End

// Returns the name of the longest visible trace
Function /S LongestVisibleTrace([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3),trace,longest_trace=""
	Variable i,max_length=0
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		if(IsTraceVisible(trace,win=win))
			Wave TraceWave=TraceNameToWaveRef(win,trace)
			Variable numPoints=TracePoints(trace,win=win)
			if(numPoints>max_length)
				max_length=numPoints
				longest_trace=trace
			endif
		endif
	endfor
	return longest_trace
End

Function TracePoints(trace,[win])
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String info=TraceInfo(win,trace,0)
	String pointsInfo=StringByKey("YRANGE",info)
	if(GrepString(pointsInfo,"[\*]"))
		Wave TraceWave=TraceNameToWaveRef(win,trace)
		return dimsize(TraceWave,0)
	else
		Variable first,last
		sscanf pointsInfo,"[%d,%d]",first,last
		return last-first+1
	endif
End

// Brings a trace to the front of the window.  Actually removes it and reappends it, with all of its features intact.  
Function BringToFront(trace,[win])
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	Wave traceWave=TraceNameToWaveRef(win,trace)
	String info=TraceInfo(win,trace,0),command
	Variable offset=strsearch(info,"RECREATION:",0)
	offset+=11
	info=info[offset,strlen(info)-1]
	RemoveFromGraph /W=$win $trace
	AppendToGraph /W=$win traceWave
	trace=TopTrace(win=win)
	info=ReplaceString("(x)",info,"("+trace+")")
	Variable i
	for(i=0;i<ItemsInList(info);i+=1)
		command=StringFromList(i,info)
		if(!IsEmptyString(command))
			Execute /Q "ModifyGraph /W="+win+" "+command
		endif
	endfor
End

// Sets an axis according to cursor locations
Function SetXAxis([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String trace=StringByKey("TNAME",CsrInfo(A))
	String axis=TraceXAxis(trace,win=win)
	SetAxis /W=$win $axis,hcsr(A),hcsr(B)
End

function /s CursorTrace(csr,[win])
	string csr,win
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	string info = csrinfo($csr)
	string trace = stringbykey("TNAME",info)
	return trace
end

Function /S TraceXAxis(trace,[win])
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String info=TraceInfo(win,trace,0)
	return StringByKey("XAXIS",info)
End

Function /S TraceYAxis(trace,[win])
	String trace,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String info=TraceInfo(win,trace,0)
	return StringByKey("YAxis",info)
End

Function PlotLevels(data,levels)
	Wave data,levels
	Variable i
	Duplicate /o data levelWave
	levelWave=NaN
	for(i=0;i<numpnts(levels);i+=1)
		levelWave[x2pnt(levelWave,levels[i])]=data[x2pnt(data,levels[i])]
	endfor
	Display data
	AppendToGraph /c=(0,0,0) levelWave
	ModifyGraph mode(levelWave)=2,lsize(levelWave)=5
End

Function CleanAppend(trace_name[,folder,color,versus])
	String trace_name
	String color,folder,versus
	String axes=WaveAxes(CsrWave(A))+" "
	RemoveFromGraph /Z $trace_name
	if(ParamIsDefault(color))
		color=""
	else
		color="/C=("+color+") "
	endif
	if(ParamIsDefault(versus))
		versus=""
	else
		versus=" vs "+versus
	endif
	String cmd_string="AppendToGraph "+color+axes+trace_name+versus
	Execute /Q/Z cmd_string
	//ModifyGraph rgb($trace_name)=(0,0,0)
End

// Because the Igor bar graph function is stupid, I made my own
Function BarGraph(data[,xvals,errors,colors,labels])
	Wave Data
	Wave Xvals
	Wave Errors
	String colors,labels
	Display /K=1 /N=Bars as "Bar Graph"
	Variable i
	String color
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:Bars
	if(ParamIsDefault(labels))
		labels=""
	endif
	for(i=0;i<numpnts(data);i+=1)
		Make /o/n=(numpnts(data)*3) $("Bar_"+num2str(i))
		Wave Bar=$("Bar_"+num2str(i))
		Bar=Nan
		Bar[3*i+1,3*i+2]=data[i]
		if(!ParamIsDefault(colors))
			color="/c=("+StringFromList(i,colors)+")"
		else
			color="/c=(0,0,0)"
		endif
		Execute "AppendToGraph "+color+" Bar_"+num2str(i)
		if(!ParamIsDefault(errors))
			Make /o/n=(numpnts(data)*3) $("ErrorBar_"+num2str(i))
			Wave ErrorBar=$("ErrorBar_"+num2str(i))
			ErrorBar=NaN
			ErrorBar[3*i+2]=Errors[i]
			ErrorBars $("Bar_"+num2str(i)),Y wave=(ErrorBar,ErrorBar)
		endif
		SetDrawEnv ycoord=left, xcoord=bottom,textxjust=1
		DrawText 3*i+2,-10,StringFromList(i,labels)
	endfor
	ModifyGraph mode=5,hbFill=2,tick(bottom)=3,nticks(bottom)=0
	WaveStats /Q Data
	SetAxis left 0.01,V_max*1.5
	SetAxis bottom 0,3*i+1
	SetDataFolder curr_folder
End

// Kills all annotations matching 'match' in graph or layout 'win'.  Won't work with non textbox annotations.  
Function KillAnnotations([match,win])
	String match,win
	if(ParamIsDefault(match))
		match="*"
	endif
	if(ParamIsDefault(win))
		win=WinName(0,5) // Top graph or layout.  
	endif
	String annotations=AnnotationList(win)
	Variable i
	for(i=0;i<ItemsInList(annotations);i+=1)
		String annotation=StringFromList(i,annotations)
		Textbox /K/W=$win /N=$annotation
	endfor
End

Function DrugWaves() // Make lines on the analysis graph that show when drugs were washed in and washed out.
	Wave/T info=root:status:drugs:info
	Variable i,j,k;
	String drugstring
	String druglist=""
	for(i=0;i<numpnts(info);i+=1)
		for(j=0;j<ItemsInList(info(i));j+=1)
			drugstring=StringFromList(j,info(i))
			druglist=druglist+RemoveListItem(0,drugstring,",")+";"
		endfor
	endfor
	String drugsused=""
	for(i=0;i<ItemsInList(druglist);i+=1)
		if(FindListItem(StringFromList(i,druglist),drugsused)>=0)
		else
			drugsused=drugsused+StringFromList(i,druglist)+";"
		endif
	endfor
	Wavestats /Q root:sweepT
	Variable max_time=V_max
	Variable time_base=10 // 10 timepoints in one minute
	String drugname
	Make /o/n=(numpnts(info)+1) root:status:drugs:drugtimes; Wave drugtimes=root:status:drugs:drugtimes 
	for(i=0;i<numpnts(info);i+=1)
		drugtimes[i]=str2num(StringFromList(0,info(i),","))
	endfor
	drugtimes[numpnts(info)+1]=max_time
	String text_legend="" 
	ColorTab2Wave BlueRedGreen
	Variable color_entry
	for(i=0;i<ItemsInList(drugsused);i+=1)
		drugname=StringFromList(i,drugsused)
		Make /o/n=(max_time*time_base) root:status:drugs:$drugname
		SetScale /p x, 0, 1/time_base, "min", root:status:drugs:$drugname
		Wave drugwave=root:status:drugs:$drugname
		drugwave=NaN
		for(j=0;j<numpnts(info);j+=1)
			for(k=0;k<ItemsInList(info(j));k+=1)
				if(FindListItem(drugname,StringFromList(k,info(j)),",")>=0)
					drugwave[drugtimes[j]*time_base,drugtimes[j+1]*time_base]=i+1
				endif
			endfor
		endfor
		DoWindow /F AnalysisWin
		color_entry=floor(abs(enoise(dimsize(M_colors,0))))
		Wave M_colors=$(GetDataFolder(1)+"M_colors")
		AppendToGraph /W=AnalysisWin /B=Time_axis /R=drug_axis /C=(M_colors(color_entry)(0),M_colors(color_entry)(1),M_colors(color_entry)(2)) drugwave
		
		text_legend=text_legend+num2str(i+1)+": "+StringFromList(i,drugsused)
		if(i<ItemsInList(drugsused)-1)
			text_legend=text_legend+"\r"
		endif
	endfor
	SetAxis /W=AnalysisWin drug_axis 0,(i+1)
	Label /W=AnalysisWin drug_axis "\\Z06 Drugs"
	ModifyGraph /W=AnalysisWin lblPos(drug_axis)=25, freePos(drug_axis)={max_time+1,Time_axis}, axisenab(time_axis)={0.02,0.97}
	TextBox /C /N=text0 /W=AnalysisWin "\Z06"+text_legend
	KillWaves M_Colors
End

Function TextMods(clamp,freq,conc,x1,x2)
	String clamp,freq,conc
	Variable x1,x2
	GetAxis left
	Variable y=V_max
	Variable y_inc=y/10
	Variable x=(x2+x1)/2
	DrawLine x1,-inf,x1,inf;
	DrawText x,y,clamp
	DrawText x,y-y_inc,freq
	DrawText x,y-2*y_inc,conc
End

// Put all the traces from other graphs onto a target graph (preserving styles for each trace)
Function MergeGraphs(target_graph,source_graphs)
	String target_graph,source_graphs
	Variable i; String source_graph,win_rec
	for(i=0;i<ItemsInList(source_graphs);i+=1)
		source_graph=StringFromList(i,source_graphs)
		win_rec=WinRecreation(source_graph,0)
	endfor
End

Function /S VisibleTraces([graph])
	String graph
	if(ParamIsDefault(graph))
		graph=""
	endif
	String traces=TraceNameList(graph,";",3)
	Variable i; String trace,visible_traces=""
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		if(!str2num(StringByKey("hideTrace(x)",TraceInfo(graph,trace,0),"="))) // If the trace is visible
			visible_traces+=trace+";"
		endif
	endfor
	return visible_traces
End

// Returns the location of the nth trace on the graph
Function /S TraceNum(n[,reversi,win])
	Variable n,reversi
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	if(reversi)
		n=ItemsInList(traces)-n-1
	endif
	Wave trace_wave=TraceNameToWaveRef(win,StringFromList(n,traces))
	return GetWavesDataFolder(trace_wave,2)
End

Function CycleColorsInGraph(colorscheme,[graphName])
	Variable colorscheme
	String graphName
	String TracesOnGraph
	String TableToUse
	
	Variable numTraces
	Variable n
	
	colorscheme = (colorscheme>8) ? 8 : colorscheme
	colorscheme = (colorscheme<1) ? 1 : colorscheme
	
	if (paramIsDefault(graphName))
		TracesOnGraph = TraceNameList("",";",1)
	else
	      TracesOnGraph = TraceNameList(graphName,";",1)
	endIf
	
	numTraces = ItemsInList(TracesOnGraph,";")
	TableToUse = StringFromList(colorscheme-1,CtabList())
	
	ColorTab2Wave $TableToUse
	Wave/Z M_Colors
	Make/FREE/N=(numTraces,3) ColorWave; ColorWave[0,*][0,*] = M_Colors[(100/numTraces)*p][q]
	Make /FREE/n=(numtraces) Randos=gnoise(1),Index=x
	Sort Randos,Index
	Duplicate /FREE ColorWave,ColorWave2
	ColorWave=ColorWave2[Index[p]][q]
	
	Do
      		string ThisTrace=StringFromList(n,TracesOnGraph)
             if(Strlen(ThisTrace)==0)
                    break
            	endIf
             ModifyGraph rgb($ThisTrace) = (ColorWave[mod(n,numTraces)][0],ColorWave[mod(n,numTraces)][1],ColorWave[mod(n,numTraces)][2])
             n+=1
	 While(1)
End

Function PlotCoefsandSigmas(str)
	String str
	Variable i,j,k
	Wave Coeffs=Coeffs
	Wave Sigmas=Sigmas
	SVar file_names=file_names
	String name
	for(i=0;i<dimsize(Coeffs,1);i+=1)
		Make /o/n=1 $"Coeffs_"+num2str(i)+"_"+str; Wave CoeffsToPlot=$"Coeffs_"+num2str(i)+"_"+str
		Make /o/n=1 $"Sigmas_"+num2str(i)+"_"+str; Wave SigmasToPlot=$"Sigmas_"+num2str(i)+"_"+str
		k=0
		for(j=0;j<dimsize(Coeffs,0);j+=1)
			name=StringFromList(j,file_names)
			if(stringmatch(name,"*"+str+"*")) // If the file name has str in it
				Redimension /n=(k+1) CoeffsToPlot,SigmasToPlot
				CoeffsToPlot[k]=Coeffs[j][i]
				SigmasToPlot[k]=Sigmas[j][i]
				k+=1
			endif
		endfor
		Sort CoeffsToPlot,CoeffsToPlot,SigmasToPlot
		Display /K=1 /N=$("W_"+num2str(i))
		AppendToGraph CoeffsToPlot
		ModifyGraph mode=2, lsize=3
		ErrorBars $NameOfWave(CoeffsToPlot),Y wave=($NameOFwave(SigmasToPlot),$NameofWave(SigmasToPlot))
	endfor
End

Function ConditionColorZ()
	String /G file_names=""
	Variable i,index=0
	Wave /T File_Name=File_Name
	Wave /T Condition=Condition
	Make /o/n=(0,3) ZColor=NaN
	String name
	for(i=0;i<numpnts(File_Name);i+=1)
		name=File_Name[i]
		if(WhichListItem(name,file_names)==-1)
			file_names+=name+";"
			Redimension /n=(index+1,3) ZColor
			Condition2Color(Condition[i]); NVar red,green,blue
			ZColor[index][0]=red
			ZColor[index][1]=green
			ZColor[index][2]=blue
			index+=1
		endif
	endfor
End

Function ScaleLayoutObjects(scale)
	Variable scale
	
	Variable i=0
	Do
		String objInfo=LayoutInfo("",num2str(i))
		if(!strlen(objInfo))
			break
		endif
		String name=StringByKey("NAME",objInfo)
		Variable left=NumberByKey("LEFT",objInfo)
		Variable top=NumberByKey("TOP",objInfo)
		Variable width=NumberByKey("WIDTH",objInfo)
		Variable height=NumberByKey("HEIGHT",objInfo)
		ModifyLayout left($name)=left*scale, top($name)=top*scale, width($name)=width*scale, height($name)=height*scale
		i+=1
	While(1)
End

Function ScaleLayoutTextBoxes(scale,origSize)
	Variable scale,origSize
	
	Variable i=0
	Do
		String objInfo=LayoutInfo("",num2str(i))
		if(!strlen(objInfo))
			break
		endif
		if(!StringMatch(StringByKey("TYPE",objInfo),"TEXTBOX"))
			i+=1
			continue
		endif
		String name=StringByKey("NAME",objInfo)
		String text=StringByKey("TEXT",AnnotationInfo("",name,1))
		if(StrSearch(text,"Z"+num2str(origSize),0)<0)
			i+=1
			continue
		endif
		//text=ReplaceString("\\Z24",text,"\\Z48")
		text=ReplaceString("Z"+num2str(origSize),text,"Z"+num2str(origSize*scale))
		Textbox /C/N=$name text
		Variable left=NumberByKey("LEFT",objInfo)
		Variable top=NumberByKey("TOP",objInfo)
		Variable width=NumberByKey("WIDTH",objInfo)
		Variable height=NumberByKey("HEIGHT",objInfo)
		ModifyLayout left($name)=left, top($name)=top // Restore original width and height
		ModifyLayout width($name)=width, height($name)=height // Restore original width and height
		i+=1
	While(1)
End

// Scales fonts for all axis labels and ticks for graph objects in a layout
Function ChangeLayoutObjectAxisFonts(newSize)
	Variable newSize
	
	Variable i=0
	Do
		String objInfo=LayoutInfo("",num2str(i))
		if(!strlen(objInfo))
			break
		endif
		if(!StringMatch(StringByKey("TYPE",objInfo),"GRAPH"))
			i+=1
			continue
		endif
		String name=StringByKey("NAME",objInfo)
		ModifyGraph /W=$name fsize=newSize
		i+=1
	While(1)
End

// Concatenates traces to show the whole experiment on one graph
Macro TraceSummary()
	Concat("1,"+num2str(root:status:currSweep),directory="root:cellR1:",split=1,downscale=10)
	Concat("1,"+num2str(root:status:currSweep),directory="root:cellL2:",split=1,to_append=1,downscale=10)
End

Function GraphRatio(numerator,denominator[,x1,x2,win])
	String numerator,denominator
	Variable x1,x2
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	x1=ParamIsDefault(x1) ? xcsr(A) : x1
	x2=ParamIsDefault(x2) ? xcsr(B) : x2
	Wave NumeratorWave=TraceNameToWaveRef(win,numerator)
	Wave DenominatorWave=TraceNameToWaveRef(win,denominator)
	Variable num,den
	num=mean(NumeratorWave,x1,x2)-mean(NumeratorWave,-0.005,-0.001)
	den=mean(DenominatorWave,x1,x2)-mean(DenominatorWave,-0.005,-0.001)
	printf "%d/%d=%f.\r",num,den,num/den
End

// Put the cursors on the ends of the x-axis
Function CursorsAxis()
	DoUpdate
	GetAxis /Q bottom
	Cursor A,$TopTrace(),V_min
	Cursor B,$TopTrace(),V_max
End

Function GraphMatrix(mat[,dim,subtractMean])
	Wave mat
	Variable dim,subtractMean
	
	dim=ParamIsDefault(dim) ? 1 : dim
	Variable i
	Display /K=1
	for(i=0;i<dimsize(mat,dim);i+=1)
		switch(dim)
			case 0: 
				AppendToGraph mat[i][]
				if(subtractMean)
					MatrixOp /O meann=mean(row(mat,i))
					ModifyGraph offset[i]={0,-meann}
				endif
				break
			case 1:
				AppendToGraph mat[][i]
				if(subtractMean)
					MatrixOp /O meann=mean(col(mat,i))
					ModifyGraph offset[i]={0,-meann}
				endif
				break
		endswitch
	endfor
End

function Waves2Bars(ws[,colors,inset])
	wave /wave ws // Wave of waves.  
	wave colors // A row for each wave.  
	string inset // Make an inset on the graph 'inset' or use "top" for the top graph.  Otherwise, make a new graph.  
	
	inset=selectstring(!paramisdefault(inset),"",inset)
	inset=selectstring(stringmatch(inset,"top"),inset,winname(0,1))
	string name=uniquename("New",11,0)
	cd root:
	newdatafolder /o root:$name
	dfref df=root:$name
	make /o/n=(numpnts(ws)) df:means /wave=means, df:sems /wave=sems
	make /o/n=(numpnts(ws),3) df:colors /wave=colors_=0
	
	if(!paramisdefault(colors))
		colors_=colors
	endif
	make /o/n=(numpnts(ws))/t df:labels /wave=labels
	variable i
	for(i=0;i<numpnts(ws);i+=1)
		wave w=ws[i]
		wavestats /q w
		means[i]=v_avg
		sems[i]=v_sdev/sqrt(v_npnts)
		labels[i]=nameofwave(w)
	endfor
	if(strlen(inset))	
		display /n=$(name+"_win")/HOST=$inset means vs labels	
	else
		display /n=$(name+"_win") means vs labels
	endif
	errorbars means, Y wave=(sems,sems)
	ModifyGraph zColor(means)={colors_,*,*,directRGB,0},hbFill=2
end

// Converts a a graph of two traces to a bar graph containing the mean and sem of those traces.  
// Works with a cumulative histogram, but the data doesn't have to be sorted or scaled.  
function Traces2Bars([win,inset])
	string win // Take traces from this graph.   
	string inset // Make an inset on to graph 'inset', or use "top" for an inset on graph 'win'.    
	
	win=selectstring(!paramisdefault(win),winname(0,1),win)
	inset=selectstring(!paramisdefault(inset),"",inset)
	inset=selectstring(stringmatch(inset,"top"),inset,winname(0,1))
	inset=selectstring(stringmatch(inset,"win"),inset,win)
	
	string traces=tracenamelist(win,";",1)
	variable i
	make /free/n=0/wave ws
	make /free/n=0 colors
	for(i=0;i<itemsinlist(traces);i+=1)
		string trace=stringfromlist(i,traces)
		wave w=tracenametowaveref(win,trace)
		ws[i]={w}
		variable red,green,blue
		GetTraceColor(trace,red,green,blue,win=win)
		colors[][i]={red,green,blue}
	endfor
	matrixtranspose colors
	Waves2Bars(ws,colors=colors,inset=inset)
end

// Converts a wave of indices (0,1,0,2,2,0,1) vs values (24.2,3.7,6,8,90.3,12.2,1.8,72.3) to a bar graph, with one bar for each unique index.  
Function NumValues2Bars(Xwave,Ywave[,XLabels])
	Wave Xwave // The indices.  
	Wave Ywave // The values.  
	Wave XLabels // Optional x-axis labels for the bars.  
	Make /o/n=(numpnts(XWave)) NV2B_Index=p
	Sort XWave,XWave,YWave,NV2B_Index
	Variable i; String wave_list=""
	Make /o/n=0 Means,SEMs
	Make /o/T/n=0 Labels
	for(i=0;i<numpnts(Xwave);i+=1)
		Variable index=XWave[i]
		String values_name="NV2B_"+num2str(index)
		if(!waveexists($values_name))
			Make /o/n=0 $values_name
			wave_list+=values_name+";"
		endif
		Wave /Z TheseValues=$(values_name)
		InsertPoints 0,1,TheseValues
		TheseValues[0]=YWave[i]
	endfor
	for(i=0;i<ItemsInList(wave_list);i+=1)
		values_name=StringFromList(i,wave_list)
		Wave TheseValues=$values_name
		InsertPoints 0,1,Means,SEMs,Labels
		WaveStats /Q TheseValues
		Means[0]=V_Avg
		SEMs[0]=V_sdev/sqrt(V_npnts)
		String index_name=values_name[5,strlen(values_name)-1]
		Labels[0]=index_name
		KillWaves /Z TheseValues
	endfor
	String curr_folder=GetDataFolder(0)
	WaveTransform /O flip, Means
	WaveTransform /O flip, SEMs
	WaveTransform /O flip, Labels
	Display /N=$curr_folder Means vs Labels
	ErrorBars Means,Y wave=(SEMs,SEMs) 
	Sort NV2B_Index,XWave,YWave
	KillWaves /Z NV2B_Index
End

Function /S YAxisTraces(axisName[,win])
	String axisName,win
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String axisTraces=""
	String traces=TraceNameList(win,";",3)
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace=StringFromList(i,traces)
		String trace_info=TraceInfo(win,trace,0)
		String traceAxisName=StringByKey("YAXIS",trace_info)
		if(!cmpstr(axisName,traceAxisName) || !cmpstr(axisName,"*"))
			axisTraces+=trace+";"
		endif
	endfor
	return axisTraces
End

function /s WinList2([types,match,except])
	variable types
	string match,except
	
	types=paramisdefault(types) ? 7 : types
	match=selectstring(!paramisdefault(match),"*",match)
	except=selectstring(!paramisdefault(except),"",except)
	variable i
	string wins=""
	for(i=0;i<itemsinlist(match);i+=1)
		string match_=stringfromlist(i,match)
		wins+=WinList(match_,";","WIN:"+num2str(types))
		wins=RemoveEnding(wins,";")+";"
	endfor
	for(i=0;i<itemsinlist(except);i+=1)
		string except_=stringfromlist(i,except)
		wins=removefromlist(except_,wins,";")
	endfor
	wins=UniqueList(wins)
	return wins
end

function ResizeWins(wins,width,height)
	string wins
	variable width,height
	
	variable i
	for(i=0;i<itemsinlist(wins);i+=1)
		string win=stringfromlist(i,wins)
		getwindow $win wsize
		movewindow /w=$win v_left,v_top,v_left+width,v_top+height
	endfor
end

function /wave WinSimilarityMatrix(wins,method)
	string wins
	variable method
	
	variable numWins=itemsinlist(wins)
	make /free/n=(numWins,numWins) similarity
	if(method==1) // Compare window recreation macros (using Levenshtein distance).  
		similarity=WinRecSimilarity(stringfromlist(p,wins),stringfromlist(q,wins))
	elseif(method==2) // Compare waves plotted.  
		wave wavesDisplayed=WinWaveMatrix(wins=wins)
		duplicate /free CorrelationMatrix({wavesDisplayed}) similarity
	elseif(method==3) // Compare folders of waves plotted.  
		wave pathsDisplayed=WinPathMatrix(wins=wins)
		duplicate /free CorrelationMatrix({pathsDisplayed}) similarity
	endif
	return similarity
end

function /wave WinWaveMatrix([wins])
	string wins
	
	wins=selectstring(!paramisdefault(wins),winlist("*",";","WIN:3"),wins)
	string waves=wavelist2(df=root:,recurse=1,fullPath=1)
	make /o/n=(itemsinlist(waves),itemsinlist(wins)) wavesDisplayed=IsDisplayed(stringfromlist(p,waves),stringfromlist(q,wins))
	variable i
	for(i=0;i<itemsinlist(waves);i+=1)
		SetDimLabel 0,i,$stringfromlist(i,waves),wavesDisplayed
	endfor
	return wavesDisplayed
end

function /wave WinPathMatrix([wins])
	string wins
	wins=selectstring(!paramisdefault(wins),winlist("*",";","WIN:3"),wins)
	string waves=wavelist2(df=root:,recurse=1,fullPath=1)
	make /free/n=(itemsinlist(waves),itemsinlist(wins)) wavesDisplayed=IsDisplayed(stringfromlist(p,waves),stringfromlist(q,wins))
	make /o/n=0 pathsDisplayed=0
	make /o/n=0/t paths
	variable i,k
	for(i=0;i<dimsize(wavesDisplayed,0);i+=1)
		string wave_name=stringfromlist(i,waves)
		wave w=$wave_name
		for(k=0;k<itemsinlist(wins);k+=1)
			if(wavesDisplayed[i][k])
				string fullPath=getwavesdatafolder(w,2)
				variable depth=itemsinlist(fullPath,":")-1
				do
					findvalue /text=fullPath /txop=4 paths
					if(v_value<0)
						paths[numpnts(paths)]={fullPath}
						redimension /n=(dimsize(pathsDisplayed,0)+1,itemsinlist(wins)) pathsDisplayed
						v_value=numpnts(paths)-1
					endif
					pathsDisplayed[v_value][k]+=1
					fullPath=removeending(fullPath,":"+stringfromlist(depth,fullPath,":"))
					depth-=1
				while(depth>0) // Deeper than root.    
			endif
		endfor	
	endfor
	return pathsDisplayed
end	

function WinRecSimilarity(g1,g2)
	string g1,g2 // Two window names.  
	
	string rec1=winrecreation(g1,0)
	string rec2=winrecreation(g2,0)
	return 1-LevenshteinDistance(rec1,rec2,cost=2)/(strlen(rec1)+strlen(rec2))
end

function IsDisplayed(wave_name,win)
	string wave_name // Full path. 
	string win
	
	wave w=$wave_name
	CheckDisplayed /W=$win w
	return v_flag
end

// Alison's graph style
Function AlisonGraphStyle()
	Label summary_left "\\Z14Width (ms)"
	ModifyGraph axisEnab(summary_bottom)={0.08,0.99}
	ModifyGraph axisEnab(summary_bottom)={0.12,0.99}
	ModifyGraph lblPos(summary_left)=45
	Label summary_left "\\Z14width (ms)"
	ShowTools/A
	SetDrawEnv textrgb= (0,0,0)
	HideTools/A
	ModifyGraph fSize(summary_bottom)=10
	ModifyGraph fSize(summary_bottom)=14
	ModifyGraph axisEnab(summary_left)={0.1,1}
	ModifyGraph freePos(summary_bottom)={0.1,kwFraction}
	ModifyGraph fSize(summary_left)=12
	ModifyGraph nticks(summary_left)=3
	ModifyGraph fSize(summary_bottom)=0
	SetAxis summary_left 2.0744,4.95 
	ModifyGraph nticks(summary_left)=4
	NewLayout 
	AppendLayoutObject graph bar_Width
	AppendLayoutObject graph scatter_Width
	ModifyLayout frame(bar_Width)=0
	ModifyLayout frame=0
	Label scatter_left ""
	ModifyGraph axisEnab(summary_bottom)={0.2,0.99}
	SetAxis scatter_left 2.0744,4.7 
	SetAxis summary_left 2.0744,4.7 
	ModifyGraph fSize(scatter_left)=12
	Edit  root:ConditionList95
	ShowTools/A
	HideTools/A
	ModifyGraph freePos(scatter_bottom)={0.1,kwFraction}
	ModifyGraph axisEnab(scatter_left)={0.1,1}
	ModifyGraph fSize(summary_left)=10
	ModifyGraph fSize(scatter_left)=10
	Edit  root:ConditionList94
	ShowTools/A
	SetDrawEnv linefgc= (65535,65535,65535)
	HideTools/A
	ShowTools/A
	Label summary_left "\\Z12width (ms)"
	Label summary_left "\\Z12\\f01width (ms)"
	ModifyGraph fSize(summary_bottom)=8
	HideTools/A
	ShowTools/A
	HideTools/A
	ModifyGraph fSize(scatter_bottom)=8
	ShowTools/A
	SetDrawEnv fsize= 8
	HideTools/A
	ModifyGraph fStyle(summary_bottom)=1
	ModifyGraph fStyle=0
	ShowTools/A
	SetDrawEnv linefgc= (65535,65535,65535)
	HideTools/A
	ModifyGraph fSize(summary_left)=9;DelayUpdate
	Label summary_left "\\Z11\\f01width (ms)"
	ModifyGraph fSize(scatter_left)=9
	TextBox/C/N=text0/F=0/A=LB/X=26.04/Y=80.90 "A"
	TextBox/C/N=text0 "\\Z16A"
	TextBox/C/N=text0 "\\Z16A\\B1"
	TextBox/C/N=text1 "\\Z16A\\B2"
End

// Code from Francis Dalaudier off the Igor mailing list.  

#pragma rtGlobals=1        // Use modern global access method.

// center, expand & shrink using graph marquee on a single-axis basis
//
// This procedure file provides some equivalent of built-in expand/shrink
// on an axis-by-axis (A-b-A) basis. A single level A-b-A Undo is provided.
// CenterŠ is intended to provide an equivalent for the option-drag.
// The center of the marquee is moved at the center of the axis.
// Other (more or less) related utilities are provided "as-is".
// See the comments in functions. G0000() build a test-graph.
//
// TO_DO : work for sub-windows (??)
// TO_DO : automatic update of axis info (???) -> just call caption()
// TO_DO : add help strings (?)
//
// === NO global variables ===
// === info is stored in named UserData, Tags and TextBox ===
// named UserData written to the window :
//        one per axis with the same name as the axis (used for undo)
//        one named "ax_tag" indicating presence of axis info
// named Tags attached to the axis :
//        one per axis with the same name as the axis
// named TextBox (similar to a legend) :
//        one named "ax_cap" containing the info about traces
// Pink background is used as a visual "signature" of the package


Menu "GraphMarquee"
   "-"
   "Toggle axis info",/Q
   SubMenu "Single Axis"
       "Expand",/Q, ax_single("Expand")
       "Shrink",/Q, ax_single("Shrink")
       "Center",/Q, ax_single("Center")
       "Undo",/Q, ax_single("Undo")
   End
End

Function ax_single(action)
   string action
   PopupContextualMenu AxisList("")
   if ( v_flag >=1 )
       strswitch(action)
           case "Expand":
               Do_expand(S_selection)
               break
           case "Shrink":
               Do_Shrink(S_selection)
               break
           case "Center":
               Do_Center(S_selection)
               break
           case "Undo":
               Un_Do(S_selection)
               break
       endswitch
   else
       GetMarquee/K
   endif
End

//=================================================

Function Un_Do(ax_name)
   String ax_name
   GetMarquee/K $(ax_name)
   GetAxis/Q  $(ax_name) //  V_min, V_max
   Execute(GetUserData("","",ax_name))
   string mem="SetAxis "+ax_name+","+num2str(V_min)+","+num2str(V_max)
   SetWindow kwTopWin UserData($(ax_name))=mem
End

Function Do_expand(ax_name)
   String ax_name
   GetMarquee/K $(ax_name)
   GetAxis/Q  $(ax_name) //  V_min, V_max
   string mem="SetAxis "+ax_name+","+num2str(V_min)+","+num2str(V_max)
   SetWindow kwTopWin UserData($(ax_name))=mem
   if (Vertical(ax_name))
       SetAxis $(ax_name), V_bottom, V_top // vertical axis
   else
       SetAxis $(ax_name), V_left, V_right // horizontal axis
   endif
End

Function Do_shrink(ax_name)
   String ax_name
   Variable N_min, N_max, rap2
   Variable gol=NumberByKey("log(x)", AxisInfo("",ax_name),"=")
   GetMarquee/K $(ax_name)
   GetAxis/Q  $(ax_name) //  V_min, V_max
   string mem="SetAxis "+ax_name+","+num2str(V_min)+","+num2str(V_max)
   SetWindow kwTopWin UserData($(ax_name))=mem
   if (Vertical(ax_name)) // vertical axis
       if (gol)
           V_bottom=log(V_bottom); V_top=log(V_top)
           V_max=log(V_max); V_min=log(V_min)
       endif
       rap2 = ((V_max - V_min)/(V_top - V_bottom))^2
       N_min = (V_bottom + V_top)/2 - rap2*(V_top - V_bottom)/2
       N_max = (V_bottom + V_top)/2 + rap2*(V_top - V_bottom)/2
   else                     // horizontal axis
       if (gol)
           V_left=log(V_left); V_right=log(V_right)
           V_max=log(V_max); V_min=log(V_min)
       endif
       rap2 = ((V_max - V_min)/(V_right - V_left))^2
       N_min = (V_left + V_right)/2 - rap2*(V_right - V_left)/2
       N_max = (V_left + V_right)/2 + rap2*(V_right - V_left)/2
   endif
   if (gol)
       N_min=alog(N_min); N_max=alog(N_max)
   endif
   SetAxis $(ax_name), N_min, N_max
End

Function Do_center(ax_name)
   String ax_name
   Variable N_min, N_max
   Variable gol=NumberByKey("log(x)", AxisInfo("",ax_name),"=")
   GetMarquee/K $(ax_name)
   GetAxis/Q  $(ax_name) //  V_min, V_max
   string mem="SetAxis "+ax_name+","+num2str(V_min)+","+num2str(V_max)
   SetWindow kwTopWin UserData($(ax_name))=mem
   if (Vertical(ax_name)) // vertical axis
       if (gol)
           V_bottom=log(V_bottom); V_top=log(V_top)
           V_max=log(V_max); V_min=log(V_min)
       endif
       N_min = (V_bottom + V_top)/2 - (V_max - V_min)/2
       N_max = (V_bottom + V_top)/2 + (V_max - V_min)/2
   else                         // horizontal axis
       if (gol)
           V_left=log(V_left); V_right=log(V_right)
           V_max=log(V_max); V_min=log(V_min)
       endif
       N_min = (V_left + V_right)/2 - (V_max - V_min)/2
       N_max = (V_left + V_right)/2 + (V_max - V_min)/2
   endif
   if (gol)
       N_min=alog(N_min); N_max=alog(N_max)
   endif
   SetAxis $(ax_name), N_min, N_max
End

Function Vertical(ax_name) // is the axis vertical ?
   String ax_name // 0 = horizontal, 1 =  vertical, -1 = not present
   String side=AxisInfo("",ax_name), car="top;left;bottom;right"
   Return mod(WhichListItem(StringByKey("AXTYPE",side),car),2)
End // return -1 when axis is not present on top graph

Function toggleaxisinfo() // for each axis -> show name as tag
   string al=AxisList(""), an, ai // axis list, axis name, axis info
   variable k,n=ItemsInList(al),gol,mid,vh
   variable ta=strlen(GetUserData("","","ax_tag")) // tag on axis
   GetMarquee/K
   for(k=0;k<n;k+=1)
       an=StringFromList(k,al)
       if (ta) // remove tags
           Tag/N=$(an)/K
           TextBox/K/N=ax_cap
           SetWindow kwTopWin UserData($"ax_tag")=""
       else // append tags
           ai=AxisInfo("",an)
           gol=NumberByKey("log(x)", AxisInfo("",an),"=")
           GetAxis/Q  $(an) //  V_min, V_max
           if (gol)
               mid=alog((log(V_min)+log(V_max))/2)
           else
               mid=(V_min+V_max)/2
           endif
           vh=Vertical(an)?90:0 // label orientation
           Tag/N=$(an)/C/F=0/O=(vh)/B=(65535,49151,49151)/X=0/Y=0/L=0 $(an), mid, an
           caption()
           SetWindow kwTopWin UserData($"ax_tag")="tag"
       endif
   endfor
end

Function caption() // "trace -> X, Y axis"
   string al=TraceNameList("",";",1), an, ti,tx
   variable k,n=ItemsInList(al)
   tx="trace -> \tX, Y axis"
   for(k=0;k<n;k+=1)
       an=StringFromList(k,al)
       ti=TraceInfo("",an,0)
       tx+="\r\s("+an+") "+an+" \t"
       tx+=StringByKey("XAXIS", ti)+", "
       tx+=StringByKey("YAXIS", ti)
   endfor
   TextBox/C/N=ax_cap/B=(65535,54611,49151)/A=MC/X=0/Y=0 tx
end

//==========================================================
// axis coloring
//     Label             alblRGB (axis_label)
//  0   1   2   3     tlblRGB (tick_label)
//  |       |         tickRGB
// _|___|___|___|__       axRGB
//  :   :   :   :     gridRGB

Function colorax(ca) // color axis according to control wave
   variable ca // 0 -> all black ; 1 -> color Y ; 2 -> color X & Y
   string ct="ModifyGraph tickRGB=(0,0,0),axRGB=(0,0,0),tlblRGB=(0,0,0),alblRGB=(0,0,0)"
   execute ct // all axis black
   if (ca)
       string al=TraceNameList("",";",1), an, ti, ax, cc, ce
       variable k,n=ItemsInList(al)
       for(k=0;k<n;k+=1) // for each trace, color axis with control wave
           an=StringFromList(k,al)
           ti=TraceInfo("",an,0)
           cc=StringByKey("rgb(x)", ti,"=") // curve color
           ce=ReplaceString("(0,0,0)", ct, cc)
           if (ca==2)
               ax="("+StringByKey("XAXIS", ti)+")=" // X_axis name
               execute ReplaceString("=", ce, ax)
           endif
           ax="("+StringByKey("YAXIS", ti)+")=" // Y_axis name
           execute ReplaceString("=", ce, ax)
       endfor
   endif
end

//==========================================================
Function ax_byaxis() // for each axis -> CWAVE (control wave) kind=name (range)
   string al=AxisList(""), an, ai // axis list, axis name, axis info
   string cw, at, ud // control wave, axis type, user data (for un_do)
   variable k,n=ItemsInList(al)
   for(k=0;k<n;k+=1)
       an=StringFromList(k,al)
       ai=AxisInfo("",an)
       cw=StringByKey("CWAVE",ai)
       at=UpperStr(StringByKey("AXTYPE",ai))
       ud=StringFromList(strlen(GetUserData("","",an))>0," ;°") // userData exist
       GetAxis/Q  $(an) //  V_min, V_max
       printf "A%d: %s /%1.1s=%s%s (%g,%g)\r",k,cw,at,an,ud,V_min,V_max
   endfor
end

Function ax_bytrace() // for each trace -> Ywave (YAXIS) vs [Xwave] YAXIS = rgb
   string al=TraceNameList("",";",1), an, ti
   variable k,n=ItemsInList(al)
   for(k=0;k<n;k+=1)
       an=StringFromList(k,al)
       ti=TraceInfo("",an,0)
       printf "T%d: %s ", k,an
       printf "(%s) vs ", StringByKey("YAXIS", ti)
       printf "%s (%s) = ", StringByKey("XWAVE", ti), StringByKey("XAXIS", ti)
       printf "%s\r",StringByKey("rgb(x)", ti,"=")
   endfor
end

Window G0000() : Graph
   PauseUpdate; Silent 1        // building window...
   make/O/N=999 yy=alog(enoise(1))
   Display /W=(208,158,621,646)/VERT/T/R=droite yy
   AppendToGraph yy
   ModifyGraph rgb(yy)=(1,4,52428)
   ModifyGraph log(left)=1
   ModifyGraph freePos(droite)=-50
   SetAxis left 0.0789705007683456,11.7496130556521
   SetAxis bottom -60.3808349556565,1652.60423967121
   SetAxis top -11.2236491279127,20.3213792362677
   SetAxis droite -95.0873682824026,1656.21070864067
EndMacro
//=================================================
//        obsolete (?)
Function old_bytrace() // for each trace -> XAXIS, YAXIS, rgb
   string al=TraceNameList("",";",1), an, ti
   variable k,n=ItemsInList(al)
   for(k=0;k<n;k+=1)
       an=StringFromList(k,al)
       ti=TraceInfo("",an,0)
       printf "T%d: %s, ", k,an
       printf "%s, ", StringByKey("XAXIS", ti)
       printf "%s, ", StringByKey("YAXIS", ti)
       printf "%s\r",StringByKey("rgb(x)", ti,"=")
   endfor
end

// End code from Francis Dalaudier.  