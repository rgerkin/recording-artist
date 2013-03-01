// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Raster.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

constant defaultRasterBinSize=0.01

Function RasterPlot(channel[,name])
	String channel
	String name
	
	String currFolder=GetDataFolder(1)
	SetDataFolder root:$channel
	if(ParamIsDefault(name))
		name="Events"
	endif
	
	NVar duration=root:parameters:duration
	NVar currSweepNum=root:status:currentSweepNum
	
	String title=name
	name=CleanupName(name,0)
	DoWindow /K $name
	Display /K=1/N=$name/W=(100,100,600,400) as title
	ControlBar /T 35
	SetWindow $name userData(channel)=channel
	SetVariable BinSize value=_NUM:defaultRasterBinSize, size={100,20}, title="Bin Size (s)"
	SetVariable Threshold value=_NUM:0, size={90,20}, title="Thresh (mV)"
	SetVariable Refractoriness value=_NUM:0.01, size={95,20}, limits={0,Inf,0.01}, title="Refract (s)"
	SetVariable Smoothing value=_NUM:0, size={80,20}, limits={0,Inf,1}, proc=RasterPlotSetVariables, title="Smooth"
	SetVariable Sweeps value=_STR:"1-"+num2str(currSweepNum), size={90,20}, title="Sweeps"
	Button Update, proc=RasterPlotButtons, title="Update"
	
	Variable rasterPoints=round(duration/defaultRasterBinSize)
	Make /o/n=(rasterPoints,1) $("Raster_"+name) /WAVE=Raster=0
	SetScale x,0,duration,Raster
	SetScale /P y,currSweepNum,1,Raster
	AppendImage Raster
	ModifyImage Raster_Events ctab= {0,1,Grays,1}
	ModifyGraph manTick(left)={0,1,0,0},manMinor(left)={0,0},axisEnab(left)={0,0.7}
	Label left "Sweep #"
	RasterPlotHistogram(name,channel)
	Wave Hist=$("Hist_"+name)
	AppendToGraph /L=left2 Hist
	ModifyGraph axisEnab(left2)={0.75,1},freePos(left2)={0,kwFraction}
	Label left2 "Rate (Hz)"
	Label bottom "Time (s)"
	ModifyGraph lblPos(left)=45,lblpos(left2)=45
	SetDataFolder $currFolder
End

Function RasterRow(name,chan,sweepNum)
	String name
	String chan
	Variable sweepNum
	
	Wave Raster=root:$(chan):$("Raster_"+name)
	Wave Sweep=root:$(chan):$("sweep"+num2str(sweepNum))
	
	ControlInfo /W=RasterWin Threshold; Variable thresh=V_Value
	ControlInfo /W=RasterWin Refractoriness; Variable refract=V_Value
	NVar duration=root:parameters:duration
	Variable sweepDuration=numpnts(Sweep)*deltax(Sweep)
	FindLevels /Q/EDGE=1/M=(refract)/R=(0,min(duration,sweepDuration)) Sweep,thresh
	Wave W_FindLevels
	Variable i,col=sweepNum-dimoffset(Raster,1)
	
	for(i=0;i<numpnts(W_FindLevels);i+=1)
		Variable loc=W_FindLevels[i]
		Variable row=loc/dimdelta(Raster,0)
		Raster[row][col]=1
	endfor
End

Function RasterPlotSetVariables(info)
	Struct WMSetVariableAction &info
	
	if(!SVInput(info.eventCode))
		return 0
	endif
	
	String name=info.win
	String channel=GetUserData(name,"","channel")
	strswitch(info.ctrlName)
		case "Smoothing":
			RasterPlotHistogram(name,channel)
			break
	endswitch
End

Function RasterPlotButtons(ctrlName)
	String ctrlName
	
	String name=WinName(0,1)
	String channel=GetUserData(name,"","channel")
	strswitch(ctrlName)
		case "Update":
			ControlInfo Sweeps; String sweeps=ListExpand(S_Value)
			Variable firstSweep=MinList(sweeps)
			Variable lastSweep=MaxList(sweeps)
			Wave Raster=root:$(channel):$("Raster_"+name)
			Raster=0
			NVar duration=root:parameters:duration
			ControlInfo BinSize; Variable binSize=V_Value
			Variable rasterPoints=round(duration/binSize)
			Redimension /n=(rasterPoints,lastSweep-firstSweep+1) Raster
			SetScale x,0,duration,Raster
			SetScale /I y,firstSweep,lastSweep,Raster
			Variable i
			for(i=0;i<ItemsInList(sweeps);i+=1)
				Variable sweepNum=str2num(StringFromList(i,sweeps))
				RasterRow(name,channel,sweepNum)
			endfor
			RasterPlotHistogram(name,channel)
			break
	endswitch
End

Function RasterPlotHistogram(name,channel)
	String name,channel
	
	print name
	Wave Raster=root:$(channel):$("Raster_"+name)
	Make /o/n=(dimsize(Raster,0)) root:$(channel):$("Hist_"+name) /WAVE=Hist
	MatrixOp /o Hist=sumCols(Raster^t)^t
	Hist/=dimsize(Raster,1)
	CopyScales /P Raster,Hist
	ControlInfo /W=$name Smoothing; Variable smoothing=V_Value
	print smoothing
	if(smoothing>0)
		Smooth smoothing,Hist
	endif
End		