// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Stats%20Plot.ipf $
// $Author: rick $
// $Rev: 615 $
// $Date: 2012-09-05 13:14:03 -0700 (Wed, 05 Sep 2012) $

#pragma rtGlobals=1		// Use modern global access method.

// Makes a scatter plot for 2 waves, and shows histograms for each on orthogonal axes.  
function HistogramXY(wX,wY[,bins,binsX,binsY,min_,minX,minY,max_,maxX,maxY,normalize])
	wave wX,wY
	variable bins,binsX,binsY,min_,minX,minY,max_,maxX,maxY
	variable normalize // Normalize so that histograms show a rate.  
	
	bins=paramisdefault(bins) ? 25 : bins
	//min_=paramisdefault(min_) ? min(wavemin(wX),wavemin(wY)) : min_
	//max_=paramisdefault(max_) ? max(wavemax(wX),wavemax(wY)) : max_
	
	binsX=paramisdefault(binsX) ? bins : binsX
	minX=paramisdefault(minX) ? (paramisdefault(min_) ? wavemin(wx) : min_) : minX
	maxX=paramisdefault(maxX) ? (paramisdefault(max_) ? wavemax(wx) : max_)  : maxX
	
	binsY=paramisdefault(binsY) ? bins : binsY
	minY=paramisdefault(minY) ? (paramisdefault(min_) ? wavemin(wy) : min_)  : minY
	maxY=paramisdefault(maxY) ? (paramisdefault(max_) ? wavemax(wy) : max_)  : maxY
	
	print binsX,binsY
	
	display /k=1 wY vs wX
	modifygraph mode=2,lsize=2,axisenab(left)={0,0.8},axisenab(bottom)={0,0.8}
	make /o/n=(binsX) $(getwavesdatafolder(wX,2)+"_hist") /wave=histX
	make /o/n=(binsY) $(getwavesdatafolder(wY,2)+"_hist") /wave=histY 
	setscale x,minX,maxX,histX
	setscale x,minY,maxY,histY
	histogram /b=2 wX,histX
	histogram /b=2 wY,histY
	if(normalize)
		histX /= dimdelta(histX,0)
		//histY /=
	endif 
	appendtograph /l=left1 histX
	appendtograph /vert/b=bottom1 histY
	modifygraph mode=2,lsize=2,axisenab(left1)={0.85,1},axisenab(bottom1)={0.85,1}
	modifyGraph freePos(left1)={0,kwFraction},freePos(bottom1)={0,kwFraction}
	modifygraph mode($nameofwave(histX))=5,mode($nameofwave(histY))=5
	if((minX == minY) && (maxX == maxY))
		make /o/n=(2) $(getwavesdatafolder(wY,1)+"unity") /wave=unity={minX,maxX}
		appendtograph /c=(0,0,0) unity vs unity
		modifygraph mode(unity)=0,lstyle(unity)=3 
	endif
end

// Puts a symbol (like an asterisk) to indicate a significant difference between two groups on a category plot.
Function SignificanceSymbol(cat1,bar1,cat2,bar2,catGap,barGap,symbol,height[,offset])
	Variable cat1,bar1,cat2,bar2
	variable catGap,barGap // As specified in a ModifyGraph command.  
	variable height // Vertical position of the sumbol, as a fraction of the distance from the top of the vertical axis to the bottom.  
	String symbol // Symbol to use, e.g. "*"
	variable offset // Place the symbol over the second bar, instead of over the midpoint between the first and second bar.  
	
	SetDrawEnv xcoord=$AxisName("bottom"), textxjust=1, textyjust=1, fstyle=1, fsize=18, dash=1, save
	//GetAxis /Q bottom; Variable minn=V_min,maxx=V_max
	string traces=TraceNameList("",";",1)
	Variable numBars=ItemsInList(traces)
	variable x1=BarCenter(cat1,bar1,catGap,barGap,numBars)
	variable x2=BarCenter(cat2,bar2,catGap,barGap,numBars)
	variable xmid=offset ? x2 : (x1+x2)/2
	string trace1=stringfromlist(bar1,traces)
	string trace2=stringfromlist(bar2,traces)
	wave w1=tracenametowaveref("",trace1)
	wave w2=tracenametowaveref("",trace2)
	if(dimsize(w1,1)>0)
		variable y1=w1[cat1][bar1]
		variable y2=w2[cat2][bar2]
	else
		y1=w1[cat1]
		y2=w2[cat2]
	endif
	string yAxis=TraceYAxis(trace1)
	
	getaxis /q $yAxis
	if(height>0)
		height=v_max-height*(v_max-v_min)
	else
		height=v_min-height*(v_max-v_min)
	endif
	SetDrawEnv ycoord=$yAxis, textyjust=1, save
	DrawLine x1,y1,x1,height // Vertical line going to cat1,bar1.    
	DrawLine x2,y2,x2,height // Vertical line going to cat2,bar2.  
	DrawLine x1,height,xmid-0.05,height // Horizontal line going from cat1,bar1 to symbol.  
	if(!offset)
		DrawLine x2,height,xmid+0.05,height // Horizontal line going from cat2,bar2 to symbol.  
	endif
	variable pp=str2num(symbol)
	if(numtype(pp)==0) // If a number was provided as the symbol.  
		// Convert it to a number of *'s.  
		if(pp<0.001)
			symbol="***"
		elseif(pp<0.01)
			symbol="**"
		elseif(pp<0.1)
			symbol="*"
		else
			symbol="n.s."
		endif
		SetDrawEnv fsize=18 // Big font for *'s.  
	elseif(!cmpstr(symbol,"*") || !cmpstr(symbol,"**") || !cmpstr(symbol,"***"))
		SetDrawEnv fsize=18 // Big font for *'s.  
	else
		SetDrawEnv fsize=9 // Small font for numbers.  
	endif
	DrawText xmid,height,symbol // Symbol.  
End

// Make a cumulative histogram out of each trace in the graph.  
Function Graph2Cumul([win])
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace_name=StringFromList(i,traces)
		Wave theWave=TraceNameToWaveRef(win,trace_name)
		SetScale x,0,1,theWave
		Sort theWave,theWave
	endfor
End	
	
Function ExpFilterTraces(tau,[win])
	Variable tau
	String win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String traces=TraceNameList(win,";",3)
	Variable i
	for(i=0;i<ItemsInList(traces);i+=1)
		String trace_name=StringFromList(i,traces)
		Wave theWave=TraceNameToWaveRef(win,trace_name)
		ExpFilter(theWave,tau)
	endfor
End

Function PlotParam1vsParam2(conditions,param1,param2)
	String conditions
	String param1,param2
	Variable i,j,k,m
	SVar file_names=file_names
	Make /o/n=5 ISI_list={0,0.25,1}
	String name,condition
	Variable min_isi
	for(m=0;m<ItemsInList(conditions);m+=1)
		condition=StringFromList(m,conditions)
		for(j=0;j<numpnts(ISI_list);j+=1)
			min_isi=ISI_list[j]
			Make /o/n=1 $("Avg"+param1+"_"+num2str(min_ISI)+"_"+condition)
			Wave avg1=$("Avg"+param1+"_"+num2str(min_ISI)+"_"+condition)
			Make /o/n=1 $("SEM"+param1+"_"+num2str(min_ISI)+"_"+condition)
			Wave sem1=$("SEM"+param1+"_"+num2str(min_ISI)+"_"+condition)
			Make /o/n=1 $("Avg"+param2+"_"+num2str(min_ISI)+"_"+condition)
			Wave avg2=$("Avg"+param2+"_"+num2str(min_ISI)+"_"+condition)
			Make /o/n=1 $("SEM"+param2+"_"+num2str(min_ISI)+"_"+condition)
			Wave sem2=$("SEM"+param2+"_"+num2str(min_ISI)+"_"+condition)
			k=0
			for(i=0;i<ItemsInList(file_names);i+=1)
				name=StringFromList(i,file_names)
				if(StringMatch(name,"*"+condition+"*"))
					Redimension /n=(k+1) avg1,sem1,avg2,sem2
					Wave ISI = $(name+"_isis")
					Wave Params1= $(name+"_"+param1)
					Wave Params2= $(name+"_"+param2)
					Duplicate /o Params1 Params1B
					Duplicate /o Params2 Params2B
					//WaveStats /Q widths2; printf V_npnts
					Params1B=ISI[p]>min_isi ? Params1[p] : NaN
					Params2B=ISI[p]>min_isi ? Params2[p] : NaN
					//WaveStats /Q widths2; printf V_npnts
					WaveStats /Q Params1B
					DeleteNaNs(Params1B)
					avg1[k]=V_npnts>0 ? Median1(Params1B,-Inf,Inf) : NaN // Use median instead of mean
					//avgW[k]=V_avg
					sem1[k]=V_sdev/sqrt(V_npnts)
					WaveStats /Q Params2B
					DeleteNaNs(Params2B)
					avg2[k]=V_npnts>0 ? Median1(Params2B,-Inf,Inf) : NaN // Use median instead of mean
					//avgH[k]=V_avg
					sem2[k]=V_sdev/sqrt(V_npnts)
					KillWaves Params1B,Params2B
					k+=1
				endif
			endfor
			//Sort avgW,avgW,semW
			//Sort avgH,avgH,semH
		endfor
	endfor
	for(j=0;j<numpnts(ISI_list);j+=1)
		min_isi=ISI_list[j]
		Display /K=1 /N=$("Min_ISI_"+num2str(min_isi*1000))
		for(m=0;m<ItemsInList(conditions);m+=1)
			condition=StringFromList(m,conditions)
			Wave avg1=$("Avg"+param1+"_"+num2str(min_ISI)+"_"+condition)
			Wave sem1=$("SEM"+param1+"_"+num2str(min_ISI)+"_"+condition)
			Wave avg2=$("Avg"+param2+"_"+num2str(min_ISI)+"_"+condition)
			Wave sem2=$("SEM"+param2+"_"+num2str(min_ISI)+"_"+condition)
			AppendToGraph avg1 vs avg2
			ErrorBars $NameOfwave(avg1),Y wave=($NameOfWave(sem1),$NameOfWave(sem1))
			//ErrorBars $NameOfwave(avg2),X wave=($NameOfWave(sem2),$NameOfWave(sem2))
		endfor
		TextBox "ISI > "+num2str(min_isi*1000)+" ms"
		Label left "ms"
		ModifyGraph mode=2,lsize=5
		ModifyGraph /Z rgb($("Avg"+param1+"_"+num2str(min_ISI)+"_Control"))=(0,0,0)
		ModifyGraph /Z rgb($("Avg"+param1+"_"+num2str(min_ISI)+"_PTX"))=(65535,0,0)
		ModifyGraph /Z rgb($("Avg"+param1+"_"+num2str(min_ISI)+"_PTZ"))=(65535,0,50000)
	endfor
End

// Converts a scatter plot into a line graph, where each point on the line is the average of the points in a given range on the scatter plot.  
Function /S Scatter2Line(bin_start,bin_width,num_bins[,win,overlap,logg,minn,maxx,med,binary,show,thick])
	Variable bin_start,bin_width,num_bins
	String win
	variable overlap // Fractional overlap of bins.  
	Variable logg // Logg equals 1 to do compute geometric mean and standard deviation.  
	Variable minn,maxx,med // Compute a bin minimum, maximum, or median instead of a mean.  
	Variable binary // Converts all non-zero data points to 1's before computing statistics.  
	Variable show // 0 to not plot, 1 to append, and 2 to plot in a new window.   
	variable thick // Error bar thickness.  
	Variable left,right
	
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	show=paramisdefault(show) ? 1 : show
	thick=paramisdefault(thick) ? 1 : thick
	String traces=TraceNameList(win,";",3)
	Variable i,j,k;String trace
	String new_win=UniqueName("Scatter2Line",6,0)
	if(show==2)
		Display /K=1 /N=$new_win// G_Hist
	endif
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		if(StringMatch(trace,"fit_*") || StringMatch(trace,"Hist_*"))
			continue // Skip fit lines.  
		endif
		wave yy=TraceNameToWaveRef(win,trace)
		wave xx=XWaveRefFromTrace(win,trace)
		if(numpnts(yy)==0 || numpnts(xx)==0)
			continue
		endif
		Duplicate /free yy yy_
		Duplicate /free xx xx_
		Sort xx_,xx_,yy_
		dfref df=getwavesdatafolderdfr(yy)
		Make /o/n=0 df:$CleanUpName("Hist_"+trace,0) /wave=Hist
		Make /o/n=0 df:$CleanUpName("HistSEM_"+trace,0) /wave=HistSEM
		Redimension /n=(num_bins) Hist,HistSEM
		if(bin_width==0)
			bin_start=0
			variable flag=1
			wavestats /q/m=1 xx
			bin_width=v_max/num_bins
		endif
		SetScale /P x,bin_start+bin_width/2,bin_width*(1-overlap),Hist,HistSEM
		k=0
		for(k=0;k<Inf;k+=1)
			if(xx_[k]>=bin_start)
				break
			endif
		endfor
		for(j=0;j<num_bins;j+=1)
			left=bin_start+j*bin_width*(1-overlap)
			right=left+bin_width
			Make /free/n=0 values
			Do
				if(xx_[k]>=left && xx_[k]<right && k<numpnts(xx_))
					InsertPoints 0,1,values
					values[0]=yy_[k]
					k+=1
				else
					break
				endif
			While(1)
			Extract /free values,values_,numtype(values) == 0
			if(numpnts(values_)>0)
				if(binary)
					values_=values_ ? 1 : 0
				endif
				WaveStats /Q values_
				if(logg)
					Hist[j]=GeoMean(values_)
					HistSEM[j]=LogStDev(values_)/sqrt(V_npnts)
				elseif(minn)
					Hist[j]=V_min
				elseif(maxx)
					Hist[j]=V_max
				elseif(med)
					if(numpnts(values_)>2)
						StatsQuantiles /Q/QM=1 values_
						Hist[j]=V_Median
						HistSEM[j]=(V_IQR/2)/sqrt(V_npnts)
					else
						Hist[j]=V_avg
						HistSEM[j]=V_sdev/sqrt(V_npnts)
					endif
				else
					Hist[j]=V_avg
					HistSEM[j]=V_sdev/sqrt(V_npnts)
				endif
			else
				Hist[j]=NaN
				HistSEM[j]=NaN
			endif
		endfor
		if(show)
			string plotWin=selectstring(show==1,new_win,win)
			Variable red,green,blue
			GetTraceColor(trace,red,green,blue,win=win)
			string histName=CleanUpName("Hist_"+trace,0)
			AppendToGraph /w=$plotWin /c=(red,green,blue) Hist /tn=$histName
			ErrorBars/T=(thick)/L=(thick) /w=$plotWin $histName, Y wave=(HistSEM,HistSEM)
			ModifyGraph /w=$plotWin mode($histName)=0
		endif
		if(flag)
			bin_width=0
		endif
	endfor
	DoWindow /F $win // Keep the target window in front in case I want to run the function again right away.  
	return new_win
End

function Scatter2Loess(bins[,win,smith,plot,ci])
	variable bins
	string win
	variable plot
	variable smith
	variable ci
	
	smith=paramisdefault(smith) ? 0.1 : smith
	ci=paramisdefault(ci) ? 0.95 : ci
	win=selectstring(!paramisdefault(win),winname(0,1),win)
	
	variable i
	string traces=TraceNameList(win,";",3)
	for(i=0;i<ItemsInList(traces);i+=1)
		string trace=StringFromList(i,traces)
		if(StringMatch(trace,"*loess*") || StringMatch(trace,"*loC*"))
			continue
		endif
		wave yy=TraceNameToWaveRef(win,trace)
		string name=getwavesdatafolder(yy,2)
		if(dimsize(yy,1)>0)
			variable column=TraceColumn(trace,win=win)
			wave yy_=col(yy,column)
			wave yy=yy_
			name+="_"+num2str(column)
		endif
		wave xx=XWaveRefFromTrace(win,trace)
		make/O/D/N=(bins) $(name+"_loess") /wave=fit
		wavestats/Q xx
		//setscale/I x, -60,60, "", fit
		setscale/I x, v_min, v_max, "", fit
		make /o/n=(bins) $(name+"_loCP") /wave=cp, $(name+"_loCM") /wave=cm
		if(ci)
			loess /CONF={ci, $(name+"_loCP"), $(name+"_loCM")} /DEST=fit /DFCT /SMTH=(smith) /ORD=2 srcWave=yy, factors={xx}
		else
			loess /DEST=fit /DFCT /SMTH=(smith) srcWave=yy, factors={xx}
		endif
		if(plot)
			variable red,green,blue
			GetTraceColor(trace,red,green,blue,win=win)
			appendtograph /w=$win/c=(red,green,blue) fit
			name=nameofwave(fit)
			modifyGraph /w=$win mode($name)=0,lsize($name)=2,lstyle($name)=0
			if(ci)
				appendtograph /w=$win/c=(red,green,blue) cp, cm
				string nameCP=nameofwave(cp), nameCM=nameofwave(cm)
				modifyGraph /w=$win mode($nameCP)=0,mode($nameCM)=0,lstyle($nameCP)=3,lstyle($nameCM)=3	
			endif
		endif
	endfor
End

Function MeanTrace([name,graph,geometric,interpol,median])
	String name // "Mean_" and "SEM_" will be append in front of this
	String graph // Default is top graph
	Variable geometric // Use geometric mean (exp of mean of logs) rather than arithmetic mean.  
	Variable interpol // If X values are different for each traces, interpolation will be needed
	Variable median // Use the median instead of the mean  
	if(ParamIsDefault(graph))
		graph=WinName(0,1)
	endif
	Variable max_time=15, interp_step=0.05
	String traces=TraceNameList(graph,";",3),trace,mean_name,sem_name
	if(ParamIsDefault(name))
		name=StringFromList(0,traces)
	endif
	mean_name=CleanupName("Mean_"+name,1)
	sem_name=CleanupName("SEM_"+name,1)
	Variable i,last_point,longest=0
	Make /o/n=(0,ItemsInList(traces)) WaveMatrix
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef(graph,trace)
		if(interpol)
			Wave XWave=XWaveRefFromTrace(graph,trace)
			last_point=XWave[numpnts(XWave)-1]
			longest=(last_point>longest) ? last_point : longest
			Make /o/n=(max_time/interp_step) Interped
			SetScale /P x,0,interp_step,Interped
			if(numpnts(TraceWave)>=2)
#if exists("Interpolate2")
				Interpolate2 /I=3/T=1/Y=Interped XWave, TraceWave
				Interped=(x>last_point) ? NaN : Interped
				Wave TraceWave=Interped
#else
				printf "Interpolate XOP needed.\r"
				return -1
#endif
			endif
		endif
		if(numpnts(TraceWave) > dimsize(WaveMatrix,0))
			Redimension /n=(numpnts(TraceWave),-1) WaveMatrix
		endif
		if(numpnts(TraceWave)>2)
			WaveMatrix[][i]=TraceWave[p]
		else
			WaveMatrix[][i]=NaN
		endif
	endfor	
	if(!interpol) // The matrix has as many rows as the longest wave.  Entries beyond the end of the shorter wave are replaced with NaNs.
		for(i=0;i<ItemsInList(traces);i+=1)
			trace=StringFromList(i,traces)
			Wave TraceWave=TraceNameToWaveRef(graph,trace)
			if(numpnts(TraceWave) < dimsize(WaveMatrix,0))
				WaveMatrix[numpnts(TraceWave),][i]=NaN
			endif
		endfor
	else // Excess rows in the matrix of interpolated sweeps are removed.  
		Redimension /n=(ceil(longest/interp_step),-1) WaveMatrix
	endif
	Wave TraceWave=TraceNameToWaveRef(graph,StringFromList(0,traces))
	Duplicate /o TraceWave $mean_name,$sem_name
	Redimension /n=(dimsize(WaveMatrix,0)) $mean_name,$sem_name
	if(interpol)
		SetScale /P x,0,interp_step,$mean_name,$sem_name
	endif
	Wave Meann=$mean_name, SEM=$sem_name
	Meann=0;SEM=0;//Variable points
	for(i=0;i<dimsize(WaveMatrix,0);i+=1)
		Duplicate /O/R=[i,i][] WaveMatrix Row
		if(geometric)
			Row=ln(Row)
			WaveStats /Q Row
			if(median)
				Redimension /n=(numpnts(Row)) Row
				DeleteNans(Row)
				Meann[i]=exp(Median1(Row,-Inf,Inf))
			else
				Meann[i]=exp(V_avg)
			endif
			SEM[i]=exp(V_avg+V_sdev/sqrt(V_npnts))-exp(V_avg)
		else
			WaveStats /Q Row
			if(median)
				Redimension /n=(numpnts(Row)) Row
				DeleteNans(Row)
				Meann[i]=Median1(row,-Inf,Inf)
			else
				Meann[i]=V_avg
			endif
			SEM[i]=V_sdev/sqrt(V_npnts)
		endif
	endfor
	AppendToGraph /c=(0,0,0) Meann
	ModifyGraph lsize($NameOfWave(Meann)) =1
	ErrorBars $NameOfWave(Meann), Y wave=(SEM,SEM)
	KillWaves Row,WaveMatrix
End

// Plots the mean and SEM of the traces on a graph.  
Function AverageTraces([match,variance,nonstationary])
	String match
	Variable variance // Error bars are variance instead of SEM.  
	Variable nonstationary // The SEM or variance is calculated in the nonstationary way.  
	if(ParamIsDefault(match))
		match="*"
	endif
	String traces=TraceNameList("",";",3)
	traces=ListMatch(traces,match)
	Variable i; String trace,list=""
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef("",trace)
		list+=GetWavesDataFolder(TraceWave,2)+";"
	endfor	
	Wave LastTrace=TraceNameToWaveRef("",trace)
	Variable red,green,blue
	String color=GetTraceColor(trace,red,green,blue)
	Waves2Matrix(list)
	Duplicate /o Matrix $(WinName(0,1)+"_Matrix")
	KillWaves Matrix; Wave Matrix=$(WinName(0,1)+"_Matrix")
	MatrixStats(Matrix,nonstationary=nonstationary)
	Wave Meen=$(NameOfWave(Matrix)+"_Mean") // Purposely misspelled to avoid confusing Igor
	Wave SEM=$(NameOfWave(Matrix)+"_SEM")
	if(variance)
		SEM=SEM^2
		SEM*=ItemsInList(list) // Assumes that each trace in the list has a computable value at each point.    
	endif
	AppendToGraph /c=(red,green,blue) Meen
	ErrorBars $NameOfWave(Meen),Y wave=(SEM,SEM)
	CopyScales /P LastTrace Meen,SEM
End

// Averages waves in a graph, with each average wave in the new graph being equal to the average of all waves
// of the same color in the target graph (the graph that was on top when the function was called).  
Function AverageByColor([graph_name,error_bars,align_left,align_right,median,sparse_error_bars])
	String graph_name
	Variable error_bars // Compute and show error bars
	Variable align_left,align_right // Subtract off the mean of this region before computing mean and SEM.  
	Variable median // Use median instead of mean.   
	Variable sparse_error_bars // A value other than zero specifies an interval for error bars.  
	if(ParamIsDefault(graph_name))
		graph_name=WinName(0,1) // Top window.  
	endif
	error_bars=ParamIsDefault(error_bars) ? 1 : error_bars
	String curr_folder=GetDataFolder(1)
	String folder_name=UniqueName("AverageByColor",11,0)
	NewDataFolder /O/S root:$folder_name
	
	String traces=TraceNameList(graph_name,";",3)
	Variable i,j,index; String trace,color,trace_xwave
	String colors=ListGraphColors()
	//Make /o/n=(ItemsInList(colors)) divisors=0
	Variable red,green,blue,meann,xwave_count=0
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		color=GetTraceColor(trace,red,green,blue,win=graph_name)
		color=color[0,strlen(color)-2] // Eliminate the trailing comma
		color=ReplaceString(";",color,",")
		index=WhichListItem(color,colors)
		Wave traceWave=TraceNameToWaveRef(graph_name,trace)
		Wave /Z ColorMatrix=$("ColorMatrix_"+num2str(index))
		if(!waveexists(ColorMatrix))
			Make /o/n=(numpnts(traceWave),0) $("ColorMatrix_"+num2str(index))
			Wave ColorMatrix=$("ColorMatrix_"+num2str(index))
			CopyScales traceWave ColorMatrix
		else
			Wave ColorMatrix=$("ColorMatrix_"+num2str(index))
			InsertPoints /M=1 0,1,ColorMatrix
			if(!ParamIsDefault(align_left) && !ParamIsDefault(align_right))
				meann=mean(traceWave,align_left,align_right)
			else
				meann=0
			endif
			ColorMatrix[][0]=traceWave-meann
		endif
		Wave /Z TraceXWave=XWaveRefFromTrace(graph_name,trace)
		if(waveexists(TraceXWave)) // If there is an XWave
			xwave_count+=1
		endif
		//divisors[index]+=1
	endfor
	String xwave_name="" // Actually the name of the y wave to which the x wave is connected.  
	if(xwave_count>ItemsInList(traces)/2)
		xwave_name=TopTrace(win=graph_name)
	endif
	//Display /K=1 /N=AverageWaves4Colors
	
	String avg_name,sem_name; Variable error_bar_point
	for(i=0;i<ItemsInList(colors);i+=1)
		Wave ColorMatrix=$("ColorMatrix_"+num2str(i))
		avg_name=CleanupName("Avg4Color_"+num2str(i)+"_"+graph_name,1)
		sem_name=CleanupName("SEM4Color_"+num2str(i)+"_"+graph_name,1)
		Duplicate /o/R=[][0,0] ColorMatrix $avg_name,$sem_name
		Redimension /n=(numpnts($avg_name)) $avg_name,$sem_name
		Wave AvgWave4Color=$avg_name
		Wave SEMWave4Color=$sem_name
		for(j=0;j<dimsize(ColorMatrix,0);j+=1)
			Duplicate /o/R=[j,j][] ColorMatrix $"Row"; Wave Row
			Redimension /n=(numpnts(Row)) Row
			// Remove outliers
				Sort Row,Row
				DeletePoints 0,1,Row
				WaveTransform /O flip,Row
				DeletePoints 0,1,Row
			//
			WaveStats /Q Row
			if(median)
				AvgWave4Color[j]=StatsMedian(Row)
			else
				AvgWave4Color[j]=V_avg
			endif
			SEMWave4Color[j]=V_sdev/sqrt(V_npnts)
			//SEMWave4Color[j]=LogStDev(Row)
		endfor
		//AvgWave4Color=divisors[i]
		color=StringFromList(i,colors)
		red=str2num(StringFromList(0,color,","))
		green=str2num(StringFromList(1,color,","))
		blue=str2num(StringFromList(2,color,","))
		if(strlen(xwave_name)>0)
			AppendToGraph /c=(red,green,blue) AvgWave4Color vs XWaveRefFromTrace(graph_name,xwave_name)
		else
			AppendToGraph /c=(red,green,blue) AvgWave4Color
		endif
		if(error_bars)
			ErrorBars $NameOfWave(AvgWave4Color),Y wave=(SEMWave4Color,SEMWave4Color)
			if(sparse_error_bars)
				error_bar_point=0
				for(j=0;j<numpnts(SEMWave4Color);j+=1)
					if(pnt2x(SEMWave4Color,j)>=sparse_error_bars*error_bar_point)
						error_bar_point+=1
					else
						SEMWave4Color[j]=NaN
					endif
				endfor
			endif
		endif
		CopyScales ColorMatrix AvgWave4Color
		KillWaves /Z Row,ColorMatrix
	endfor
	SetWindow $graph_name, hook=WindowKillHook,userData+="KillFolder=root:"+folder_name+";"
	KillVariables /Z red,green,blue
	SetDataFolder $curr_folder
End

// Don't average across cells first.  
Function ParameterPlot(param[,features,conditions,ISI_range,spike_history,spike_future,min_peak,plots,folder,clamp,pool])
	String param // Param is a parameter that you would like to analyze, such as "Width".  It should be the name of a wave already in the folder for each cell.  
	String features // features are the names of columns from the database (and the names of a waves in Igor), such as "Condition;BathDrug".
	String conditions // Conditions are the possible values of those columns that you would like to be plotted, such as "Control,None;Control,Paxilline;Seizure,None;Seizure,Paxilline".
	String ISI_range,spike_history,spike_future
	Variable min_peak // The minimum height that a spike must achieve to be counted (not relative to threshold).
	String plots // "bar;cumul;scatter" (Separate Graphs)  
	String folder // Which folder contains all the data, e.g. "root:Cells"
	String clamp
	variable pool // (0) Average across cells, weighting according to the standard error in each cell.  
				  // (1) Average across cells, weighting all cells equally.  
				  // (2) Pool all events, with no regard to which cell they came from.    
	
	// Defaults.  
	root()
	if(ParamIsDefault(features))
		features="Condition"
	endif
	if(ParamIsDefault(conditions))
		conditions="Control;Seizure"
	endif
	if(ParamIsDefault(ISI_range))
		ISI_range="0;Inf"
	endif
	if(ParamIsDefault(spike_history))
		spike_history="0;Inf;1" // At least zero spikes, at most infinity spikes, in the last one second
	endif
	if(ParamIsDefault(spike_future))
		spike_future="0;Inf;1" // At least zero spikes, at most infinity spikes, in the next one second
	endif
	min_peak=ParamIsDefault(min_peak) ? -Inf : min_peak
	Variable minn_history=NumFromList(0,spike_history),maxx_history=NumFromList(1,spike_history),duration_history=NumFromList(2,spike_history)
	Variable minn_future=NumFromList(0,spike_future),maxx_future=NumFromList(1,spike_future),duration_future=NumFromList(2,spike_future)
	if(ParamIsDefault(plots))
		plots="Bar"
	endif
	if(ParamIsDefault(clamp) || StringMatch(clamp,"CC"))
		clamp=""
	endif
	if(ParamIsDefault(folder))
		folder="root:Cells"
	endif
	if(!IsEmptyString(clamp))
		folder+=":"+clamp
		clamp="_"+clamp
	endif
	
	// Make a temporary condition wave.  
	Variable i,j,k,m,temp
	Duplicate /FREE/T Condition Feature
	Feature=""
	for(i=0;i<dimsize(Feature,0);i+=1)
		for(j=0;j<ItemsInList(features);j+=1)
			String oneFeatureStr=StringFromList(j,features)
			Wave /T OneFeature=$onefeatureStr
			Feature[i]+=OneFeature[i]+","
		endfor
		Feature[i]=RemoveEnding(Feature[i],",")
	endfor
	
	String categories=""
	for(i=0;i<ItemsInList(conditions);i+=1)
		String condition=StringFromList(i,conditions)
		String feature1=StringFromList(0,condition,",")
		if(WhichListItem(feature1,categories)<0)
			categories+=feature1+";"
		endif
	endfor
	Variable numCategories=ItemsInList(categories)
	Make /FREE/n=(numCategories) BarsInCategory=0
	
	String curr_folder=GetDataFolder(1)
	Wave /T FileName
	String name,traces,trace,avg_name,sem_name,caption,units,plot,wave_list=""
	Variable min_isi=NumFromList(0,ISI_range), max_isi=NumFromList(1,ISI_range)
	strswitch(param)
		case "Width": 
			units=" (ms)"
			break
		default:
			units=" (mV)"
			break
	endswitch
	
	// Make the window and display the caption
	String /G bar_name="",cumul_name="",scatter_name=""
	for(i=0;i<ItemsInList(plots);i+=1)
		plot=StringFromList(i,plots)
		Display /W=(1+150*i,1,151+150*i,151) /K=1 /N=$(plot+"_"+param+clamp)
		SVar graph_name=$(plot+"_name")
		graph_name=TopWindow()
		SetWindow $graph_name, hook=WindowKillHook,userData="KillFolder="+RemoveFromList(plot,graph_name,"_")
	endfor
	String graph_folder=RemoveFromList(plot,graph_name,"_")
	NewDataFolder /O/S root:$graph_folder
	caption=UpperFirst(param)
	if(!ParamIsDefault(ISI_range))
		caption+=" : "+num2str(min_isi*1000)+"< ISI < "+num2str(max_isi*1000)+" ms"
	endif
	//TextBox /A=LT /F=0 /N=ISI_Cutoff /C /X=1.72/Y=0.41 caption
	
	// Make waves of condition names and tick markers
	String ConditionList=UniqueName("ConditionList",1,0)
	Make /o/T /n=(ItemsInList(categories)) $ConditionList /wave=ConditionLabels
	Make /o /n=(ItemsInList(categories)) $(ConditionList+"_tick") /wave=ConditionTickNums
	ConditionLabels=StringFromList(p,categories)+"\r"
	
	// Setup waves for the bar graph
	if(WhichListItem("Bar",plots)>=0)
		// Something with the name stem "ConditionList" will contain the text of the x-axis of the bar graph
		avg_name=UniqueName("Avgs"+param,1,0)
		sem_name=UniqueName("SEMs"+param,1,0)
		Variable numBarsPerCategory=ItemsInList(conditions)/ItemsInList(categories) 
		Make /o/n=(numCategories,numBarsPerCategory) $avg_name=NaN,$sem_name=NaN
		Make /FREE/n=(numCategories,numBarsPerCategory) SampleSizes
		Wave Avgs=$avg_name; Wave SEMs=$sem_name
		Make /o/n=(numCategories,3) $UniqueName("ColorTable",1,0) /WAVE=ColorTable=0
		Make /o/n=(numBarsPerCategory) $UniqueName("PatternTable",1,0) /WAVE=PatternTable=0
	endif
	Variable start,finish
	for(i=0;i<ItemsInList(conditions);i+=1)
		// Setup the waves to analyze the data
		condition=StringFromList(i,conditions)
		feature1=StringFromList(0,condition,",")
		String feature2=StringFromList(1,condition,",")
		Variable catNum=WhichListItem(feature1,categories)
		Variable barNum=BarsInCategory[catNum]
		BarsInCategory[catNum]+=1
		Condition2Color(feature1); NVar red,green,blue
		Variable patternNum=Condition2Pattern(feature2)
		avg_name=CleanupName(param+"_"+condition,1)
		sem_name=CleanupName("SEM_"+param+"_"+condition,1)
		if(barNum==0 && strlen(wave_list))
			wave_list=RemoveEnding(wave_list,",")+";"
		endif
		wave_list+=avg_name+"|"
		Make /o/n=0 $avg_name /wave=avg
		Make /o/n=0 $sem_name /wave=sem
		Make /o/T/n=0 $condition /wave=Experiment
		// Go through all the files and add data to the appropriate wave
		for(j=0;j<numpnts(FileName);j+=1)
			name=folder+":"+FileName[j]+clamp
			if(StringMatch(Feature[j],condition) && DataFolderExists(name))
				SetDataFolder $name
				
				// Check for non-existent parameter waves or weird values.  
				Wave /Z ParamWave=$param
				if(!waveexists(ParamWave))
					printf "%s does not exist in %s.\r",param,GetDataFolder(1)
					abort
				endif
				if(wavemin(ParamWave)<0)
					printf "%s has values < 0.\r",name
				endif
				if(wavemax(ParamWave)>50)
					//printf name+" has values > 50"
				endif
				
				// Filter out the data that doesn't match the constraints.  
				Duplicate /free ParamWave ParamWave2
				Wave /Z SpikeTimes = Peak_locs
				Wave /Z ISI = ISI
				Wave /Z Peak=Peak
				if(!ParamIsDefault(ISI_range))
					ParamWave2=ISI<min_ISI ? NaN :ParamWave2
					ParamWave2=ISI>max_ISI ? NaN : ParamWave2
					ParamWave2=IsNaN(ISI)? NaN : ParamWave2
				endif
				if(!ParamIsDefault(min_peak))
					ParamWave2=Peak<min_peak ? NaN : ParamWave2
					ParamWave2=IsNaN(Peak) ? NaN : ParamWave2
				endif
				if(!ParamIsDefault(spike_history) || !ParamIsDefault(spike_future))
					for(k=0;k<numpnts(ParamWave2);k+=1)
						start=1+BinarySearch(SpikeTimes,SpikeTimes[k]-duration_history)
						if(k-start<minn_history || k-start > maxx_history)
							ParamWave2[k]=NaN
						endif
						finish=BinarySearch(SpikeTimes,SpikeTimes[k]+duration_future)
						if(finish-k<minn_future || finish-k > maxx_future)
							ParamWave2[k]=NaN
						endif
					endfor
				endif
				extract /free paramwave2,paramwave3,numtype(paramwave2)==0
				
				// Add data to the summary statistics waves.  
				if(numpnts(ParamWave3))
					variable index=numpnts(avg)
					switch(pool)
						case 0: // Average across cells, weighting according to the standard error in each cell.  
						case 1: // Average across cells, weighting all cells equally.  
							WaveStats /Q ParamWave3
							experiment[index]={FileName[j]}
							avg[index]={statsmedian(ParamWave3)}// Use median instead of mean
							sem[index]={V_sdev/sqrt(V_npnts)}
							break
						case 2: // Pool all events, with no regard to which cell they came from.    
							redimension /n=(index+numpnts(paramwave3)) avg,sem,experiment
							experiment[index,]=FileName[j]
							avg[index,]=ParamWave3[p-index]
							sem[index,]=ParamWave3[p-index] 
							// SEM would only apply if the param wave had multiple entries for each event (like mutliple spike widths corresponding to multiple spikes in each up state.  \
							// I would need to change the code to make this accurate.  
							break
					endswitch
				endif	
				SetDataFolder root:$graph_folder
			endif
		endfor
		
		// Get rid of NaNs.  
		extract /o/t experiment,experiment,numtype(avg)==0
		extract /o sem,sem,numtype(avg)==0
		extract /o avg,avg,numtype(avg)==0
		
		Sort avg,avg,sem,experiment
		switch(pool)
			case 0: // Average across cells, weighting according to the standard error in each cell.  
				// Weight the statistics according to the standard error in each cell.  
				duplicate /free avg,weightedavg
				duplicate /free sem,weights
				weights=1/sem
				weights=numtype(weights) ? wavemin(weights) : weights // Replace NaNs (which probably came from cells with one event and therefore undefined SEM) with the smallest weight.  
				weights=numtype(weights) ? 1 : weights // If the last replacement failed, every cell probably has one event, in which case just give them all equal weight.  
				weightedavg=avg*weights
				wavestats /q weightedavg
				v_avg/=mean(weights)
				v_sdev/=mean(weights)
				break
			case 1:
				wavestats /Q avg
				break
			case 2:
				wavestats /Q avg
				killwaves /z sem
				break
		endswitch
		SampleSizes[catNum][barNum]=V_npnts
		
		// Store data for the bar graph
		if(WhichListItem("Bar",plots)>=0)
			ColorTable[catNum][]={{red},{green},{blue}}
			PatternTable[barNum]=patternNum
			avgs[catNum][barNum]=V_avg
			sems[catNum][barNum]=V_sdev/sqrt(V_npnts)
		endif
		
		// Make the cumulative histogram
		SetScale /I x,0,1,avg
		
		if(WhichListItem("Cumul",plots)>=0)
			DoWindow /F $cumul_name
			AppendToGraph /c=(red,green,blue) /L=cumul_left /B=cumul_bottom avg
			Label cumul_left "\Z10\f01"+caption+units; Label cumul_bottom "\Z10\f01"+"Cumulative Probability"
			//ErrorBars $NameOfwave(Avg),Y wave=($NameOfWave(sem),$NameOfWave(sem))
			ModifyGraph axisEnab(cumul_bottom)={0.10,0.99}, axisEnab(cumul_left)={0.10,1}, freePos(cumul_bottom)={0.10,kwFraction}
			ModifyGraph freePos(cumul_left)={0,cumul_bottom}, lblPos(cumul_left)=35, btLen=2,lblpos(cumul_bottom)=30
			SetAxis cumul_bottom 0,1
		endif
		if(WhichListItem("Scatter",plots)>=0)
			DoWindow /F $scatter_name
			index=(i+1)/(ItemsInList(conditions)+1)
			SetScale /I x,index,index+0.00000001,avg
			AppendToGraph /c=(red,green,blue) /L=scatter_left /B=scatter_bottom avg
			//Label scatter_left caption+units; 
			ModifyGraph mode=3,marker=19
			ModifyGraph axisEnab(scatter_bottom)={0.05,0.99}, axisEnab(scatter_left)={0.10,1}, freePos(scatter_bottom)={0.10,kwFraction}
			ModifyGraph freePos(scatter_left)={0,scatter_bottom}, lblPos(scatter_left)=35, btLen=2 ,fsize(scatter_left)=9,fsize(scatter_bottom)=8
			SetAxis scatter_bottom 0,1
			DoUpdate; GetAxis /Q scatter_left; temp=V_max-V_min
			SetAxis scatter_left V_min-temp/10,V_max+temp/10; 
			ConditionTickNums[i]=index
			ModifyGraph userticks(scatter_bottom)={ConditionTickNums,ConditionLabels}
		endif
	endfor
	
	if(WhichListItem("Bar",plots)>=0)
		// Append the bar graph
		DoWindow /F $bar_name
		for(i=0;i<numBarsPerCategory;i+=1)
			String avgName
			sprintf avgName,NameOfWave(avgs)+"#%d",i
			AppendToGraph /L=summary_left /B=summary_bottom avgs[][i] vs $ConditionList
			string semName
			sprintf semName,NameOfWave(sems)
			ErrorBars $(avgName),Y wave=($(semName)[*][i],$(semName)[*][i])
			ModifyGraph zColor($avgName)={ColorTable,*,*,directRGB}
			ModifyGraph hbFill($avgName)=PatternTable[i]
		endfor
		ModifyGraph axisEnab(summary_bottom)={0.15,0.99}, axisEnab(summary_left)={0.10,1}, freePos(summary_bottom)={0.10,kwFraction}
		ModifyGraph freePos(summary_left)={0,summary_bottom}//={numpnts($ConditionList),summary_bottom}
		ModifyGraph fsize=10, fstyle=1
		Label summary_left caption+units
		WaveStats /Q avgs
		if(V_min>0)
			SetAxis summary_left 0,V_max*1.5
		elseif(V_max<0)
			SetAxis summary_left V_min*1.5,0
		else
			SetAxis summary_left V_min*1.5,V_max*1.5
		endif
		
		if(StringMatch(plots,"*scatter*"))
			GetAxis /Q /W=$("scatter_"+param) scatter_left; 
			SetAxis summary_left V_min,V_max; 
		endif
		
		// Append sample sizes and p-values.  
		DoUpdate
		GetAxis /Q summary_left
		variable yRange=V_max-V_min
		variable catGap=0.3, barGap=0.1
		for(i=0;i<dimsize(avgs,0);i+=1) // Iterate over categories.  
			variable numBars=dimsize(avgs,1)
			for(j=0;j<numBars;j+=1) // Iterate over bars in each category.  
				if(numtype(avgs[i][j])==0)
					SetDrawEnv xcoord=summary_bottom, ycoord=rel,textxjust=1,textyjust=1,fsize=8
					variable xPos=BarCenter(i,j,catGap,barGap,numBars) // The middle of the bar.  
					DrawText xPos,0.95,"("+num2str(SampleSizes[i][j])+")" // The x coordinates here will depend on the values of catgap and bargap.  
					string experimental=stringfromlist(j,stringfromlist(i,wave_list),"|") // This experimental group.  
					if(i==0 && j==0) // Probably the main control.  
						continue
					elseif(j==0) // Probably the "control" for a subsequent category.  
						string control=stringfromlist(0,stringfromlist(0,wave_list),"|") // The main control group.  
						variable cat1=0, bar1=0
					else
						control=stringfromlist(0,stringfromlist(i,wave_list),"|") // The control group for this category.  
						cat1=i; bar1=0
					endif
					
					wave w1=$control,w2=$experimental
					if(numpnts(w1)*numpnts(w2)>2500)
						variable approx=1
					endif
					statswilcoxonranktest /aprx=(approx) /tail=4 /q $control,$experimental
					wave w_wilcoxontest
					variable pval=w_wilcoxontest[%P_TwoTail]
					//variable pVal=BootMean($control,$experimental)
					pVal=min(1,pVal*max(1,numBars-1)) // A simplified Bonferroni Correction
					SignificanceSymbol(cat1,bar1,i,j,catGap,barGap,num2str(RoundTo(pVal,4)),0.1)
					//SetDrawEnv xcoord=summary_bottom, ycoord=summary_left,textxjust=1,textyjust=1,fsize=8
					//DrawText xPos, avgs[i][j]+(avgs[i][j]>0 ? 1 : -1)*(sems[i][j]+yRange/15),"p="+num2str(RoundTo(pVal,4))
				endif
			endfor
		endfor
		ModifyGraph btLen(summary_bottom)=0.1,btlen(summary_left)=2,bargap(summary_bottom)=barGap,catGap(summary_bottom)=catGap,lblPos(summary_left)=35
	endif
	if(StringMatch(plots,"*cumul*"))
		DoWindow /F $cumul_name
		ModifyGraph swapXY=1
	endif
	KillVariables /Z red,green,blue
	KillStrings bar_name,cumul_name,scatter_name
	//KillWaves2(folder_list="root:"+graph_folder)
	SetDataFolder $curr_folder
End

// Plots a parameter for a minimum ISI indicated in ISI_list.
// The parameter should be the name of a wave that is found in the folder for each cell.  
// Assumes that the data contained in Condition, Experimenter, and FileName are up to date.  
// Uses the minimum value for each cell instead of the average value.    
Function ParameterPlotMin(Feature,conditions,param[,ISI_range,spike_history,spike_future,min_peak,plots])
	Wave /T Feature // Feature is a column from the database (and the name of a wave in Igor), such as "Injected".
	String conditions // Conditions are the possible values of that column that you would like to be plotted, such as "Control;PTX".
	String param // Param is a parameter that you would like to analyze, such as "Width".  It should be the name of a wave already in the folder for each cell.  
	String ISI_range,spike_history,spike_future
	Variable min_peak // The minimum height that a spike must achieve to be counted (not relative to threshold).
	String plots // "bar;cumul;scatter" (Separate Graphs)  
	min_peak=ParamIsDefault(min_peak) ? -Inf : min_peak
	if(ParamIsDefault(ISI_range))
		ISI_range="0;Inf"
	endif
	if(ParamIsDefault(spike_history))
		spike_history="0;Inf;1" // At least zero spikes, at most infinity spikes, in the last one second
	endif
	if(ParamIsDefault(spike_future))
		spike_future="0;Inf;1" // At least zero spikes, at most infinity spikes, in the next one second
	endif
	Variable minn_history=NumFromList(0,spike_history),maxx_history=NumFromList(1,spike_history),duration_history=NumFromList(2,spike_history)
	Variable minn_future=NumFromList(0,spike_future),maxx_future=NumFromList(1,spike_future),duration_future=NumFromList(2,spike_future)
	if(ParamIsDefault(plots))
		plots="Bar"
	endif
	Variable i,j,k,index,m,temp
	String curr_folder=GetDataFolder(1)
	Wave /T FileName
	String name,condition,traces,trace,avg_name,sem_name,caption,units,plot,wave_list=""
	Variable min_isi=NumFromList(0,ISI_range), max_isi=NumFromList(1,ISI_range)
	strswitch(param)
		case "Width": 
			units=" (ms)"
			break
		default:
			units=" (mV)"
			break
	endswitch
	
	// Make the window and display the caption
	String /G bar_name="",cumul_name="",scatter_name=""
	for(i=0;i<ItemsInList(plots);i+=1)
		plot=StringFromList(i,plots)
		Display /W=(1+150*i,1,151+150*i,151) /K=1 /N=$(plot+"_"+param)
		SVar graph_name=$(plot+"_name")
		graph_name=TopWindow()
		SetWindow $graph_name, hook=WindowKillHook,userData="KillFolder="+RemoveFromList(plot,graph_name,"_")
	endfor
	String graph_folder=RemoveFromList(plot,graph_name,"_")
	NewDataFolder /O/S root:$graph_folder
	caption=UpperFirst(param)
	if(!ParamIsDefault(ISI_range))
		caption+=" : "+num2str(min_isi*1000)+"< ISI < "+num2str(max_isi*1000)+" ms"
	endif
	//TextBox /A=LT /F=0 /N=ISI_Cutoff /C /X=1.72/Y=0.41 caption
	
	// Make waves of condition names and tick markers
	String ConditionList=UniqueName("ConditionList",1,0)
	Make /o/T /n=(ItemsInList(conditions)) $ConditionList
	Make /o /n=(ItemsInList(conditions)) $(ConditionList+"_tick")
	List2WavT(conditions,name=ConditionList) 
	Wave /T ConditionLabels=$ConditionList
	Wave ConditionTickNums=$(ConditionList+"_tick")
	
	// Setup waves for the bar graph
	if(WhichListItem("Bar",plots)>=0)
		// Something with the name stem "ConditionList" will contain the text of the x-axis of the bar graph
		avg_name=UniqueName("Avgs"+param,1,0)
		sem_name=UniqueName("SEMs"+param,1,0)
		Make /o/n=(ItemsInList(conditions)) $avg_name,$sem_name
		Wave Avgs=$avg_name; Wave SEMs=$sem_name
		String ColorTable=UniqueName("ColorTable",1,0)
		Make /o/n=(ItemsInList(conditions),3) $ColorTable=0
	endif
	Variable start,finish
	for(i=0;i<ItemsInList(conditions);i+=1)
		// Setup the waves to analyze the data
		condition=StringFromList(i,conditions)
		Condition2Color(condition); NVar red,green,blue
		avg_name=CleanupName("Avg"+param+"_"+condition,1)
		wave_list+=avg_name+";"
		sem_name=CleanupName("SEM"+param+"_"+condition,1)
		Make /o/n=0 $avg_name,$sem_name; Wave avg=$avg_name; Wave sem=$sem_name; 
		Make /o/T/n=0 $condition; Wave /T Experiment=$condition
		index=0
		// Go through all the files and add data to the appropriate wave
		for(j=0;j<numpnts(FileName);j+=1)
			name=FileName[j]
			if(StringMatch(Feature[j],condition) && DataFolderExists("root:"+name))
				Redimension /n=(index+1) avg,sem,Experiment
				Experiment[index]=FileName[j]
				SetDataFolder root:Cells:$name
				Wave SpikeTimes = Peak_locs
				Wave ISI = ISI
				Wave Peak=Peak
				Wave ParamWave=$param
				Duplicate /o ParamWave ParamWave2
				if(!ParamIsDefault(ISI_range))
					ParamWave2=ISI<min_ISI ? NaN :ParamWave2
					ParamWave2=ISI>max_ISI ? NaN : ParamWave2
					ParamWave2=IsNaN(ISI)? NaN : ParamWave2
				endif
				if(!ParamIsDefault(min_peak))
					ParamWave2=Peak<min_peak ? NaN : ParamWave2
					ParamWave2=IsNaN(Peak) ? NaN : ParamWave2
				endif
				if(!ParamIsDefault(spike_history) || !ParamIsDefault(spike_future))
					for(k=0;k<numpnts(ParamWave2);k+=1)
						start=1+BinarySearch(SpikeTimes,SpikeTimes[k]-duration_history)
						if(k-start<minn_history || k-start > maxx_history)
							ParamWave2[k]=NaN
						endif
						finish=BinarySearch(SpikeTimes,SpikeTimes[k]+duration_future)
						if(finish-k<minn_future || finish-k > maxx_future)
							ParamWave2[k]=NaN
						endif
					endfor
				endif
				if(numpnts(ParamWave2)>0)
					WaveStats /Q ParamWave2
					avg[index]=V_min// Use median instead of mean
					sem[index]=V_sdev/sqrt(V_npnts)
				else
					avg[index]=NaN
					sem[index]=NaN
				endif
				KillWaves ParamWave2
				index+=1
				SetDataFolder root:$graph_folder
			endif
		endfor
		
		Sort avg,avg,sem,Experiment
		WaveStats /Q avg
		DeleteNans(avg); DeleteNans(sem) // Get rid of the NaNs
		ConditionLabels[i]+="\r"+"n = "+num2str(V_npnts)	
		
		// Store data for the bar graph
		if(WhichListItem("Bar",plots)>=0)
			Wave WColorTable=$ColorTable
			WColorTable[i][]={{red},{green},{blue}}
			avgs[i]=V_avg; sems[i]=V_sdev/sqrt(V_npnts)
		endif
		
		// Make the cumulative histogram
		SetScale /I x,0,1,avg
		
		if(WhichListItem("Cumul",plots)>=0)
			DoWindow /F $cumul_name
			AppendToGraph /c=(red,green,blue) /L=cumul_left /B=cumul_bottom avg
			Label cumul_left "\Z10\f01"+caption+units; Label cumul_bottom "\Z10\f01"+"Cumulative Probability"
			ErrorBars $NameOfwave(Avg),Y wave=($NameOfWave(sem),$NameOfWave(sem))
			ModifyGraph axisEnab(cumul_bottom)={0.10,0.99}, axisEnab(cumul_left)={0.10,1}, freePos(cumul_bottom)={0.10,kwFraction}
			ModifyGraph freePos(cumul_left)={0,cumul_bottom}, lblPos(cumul_left)=35, btLen=2,lblpos(cumul_bottom)=30
			SetAxis cumul_bottom 0,1
		endif
		if(WhichListItem("Scatter",plots)>=0)
			DoWindow /F $scatter_name
			index=(i+1)/(ItemsInList(conditions)+1)
			SetScale /I x,index,index+0.00000001,avg
			AppendToGraph /c=(red,green,blue) /L=scatter_left /B=scatter_bottom avg
			//Label scatter_left caption+units; 
			ModifyGraph mode=3,marker=19
			ModifyGraph axisEnab(scatter_bottom)={0.05,0.99}, axisEnab(scatter_left)={0.10,1}, freePos(scatter_bottom)={0.10,kwFraction}
			ModifyGraph freePos(scatter_left)={0,scatter_bottom}, lblPos(scatter_left)=35, btLen=2 ,fsize(scatter_left)=9,fsize(scatter_bottom)=8
			SetAxis scatter_bottom 0,1
			DoUpdate; GetAxis /Q scatter_left; temp=V_max-V_min
			SetAxis scatter_left V_min-temp/10,V_max+temp/10; 
			ConditionTickNums[i]=index
			ModifyGraph userticks(scatter_bottom)={ConditionTickNums,ConditionLabels}
		endif
	endfor
	
	if(WhichListItem("Bar",plots)>=0)
		// Append the bar graph
		DoWindow /F $bar_name
		AppendToGraph /L=summary_left /B=summary_bottom avgs vs $ConditionList
		ErrorBars $NameOfWave(avgs),Y wave=($NameOfWave(sems),$NameOfWave(sems))
		ModifyGraph axisEnab(summary_bottom)={0.15,0.99}, axisEnab(summary_left)={0.10,1}, freePos(summary_bottom)={0.10,kwFraction}
		ModifyGraph freePos(summary_left)={0,summary_bottom}//={numpnts($ConditionList),summary_bottom}
		ModifyGraph fsize(summary_left)=9,fsize(summary_bottom)=8
		Label summary_left "\\Z10\\f01"+caption+units
		
		// Colorize the bars
		ModifyGraph zColor($NameOfWave(avgs))={$ColorTable,*,*,directRGB}
		
		if(StringMatch(plots,"*scatter*"))
			GetAxis /Q /W=$("scatter_"+param) scatter_left; 
			SetAxis summary_left V_min,V_max; 
		endif
		
		// Append p-values
		ListTTest(wave_list,"*control*")
		Wave PVals=PVals
		Variable control_found=0
		for(i=0;i<ItemsInList(conditions);i+=1)
			condition=StringFromList(i,conditions)
			Condition2Color(condition); NVar red,green,blue
			if(!StringMatch(condition,"*control*") || control_found==1) // If it is not the control, display the p-value
				SetDrawEnv xcoord=summary_bottom, ycoord=summary_left,textxjust=1,textyjust=avgs[i]>0?0:2,fsize=8//,textrgb=(red,green,blue),
				DrawText i+0.5, avgs[i]+(avgs[i]>0?1:-1)*sems[i],"p="+num2str(PVals[i])
			else
				control_found=1
			endif
		endfor
		ModifyGraph hbFill=2, btLen(summary_bottom)=0.1,btlen(summary_left)=2,catGap(summary_bottom)=0.3,lblPos(summary_left)=35
	endif
	if(StringMatch(plots,"*cumul*"))
		DoWindow /F $cumul_name
		ModifyGraph swapXY=1
	endif
	KillVariables /Z red,green,blue
	KillStrings bar_name,cumul_name,scatter_name
	//KillWaves2(folder_list="root:"+graph_folder)
	SetDataFolder $curr_folder
End