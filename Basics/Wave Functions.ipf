
// $Author: rick $
// $Rev: 618 $
// $Date: 2013-01-24 20:21:19 -0700 (Thu, 24 Jan 2013) $

#pragma rtGlobals=1		// Use modern global access method.

Function Npnts(w)
	wave w
	wavestats /q/m=1 w
	return v_npnts
End

Function IsFree(w)
	wave w
	
	return wavetype(w,2)==2
End

threadsafe Function /WAVE Col(w,n)
	Wave w
	Variable n // The column number.  
	
	if(numpnts(w)==0)
		make /free/n=0 w_
	else
		n=(n>dimsize(w,1)) ? 0 : n
		MatrixOp /free w_=col(w,n)
		setscale /p x,dimoffset(w,0),dimdelta(w,0),w_
	endif
	return w_
End

threadsafe Function /WAVE Row(w,n)
	Wave w
	Variable n // The row number.  

	n=(n>dimsize(w,0)) ? 0 : n
	MatrixOp /free w_=row(w,n)
	setscale /p x,dimoffset(w,1),dimdelta(w,1),w_
	return w_
End

Function /WAVE Layer(w,n)
	Wave w
	Variable n // The layer number.  
	
	if(n>=dimsize(w,2))
		n=0
	endif
	MatrixOp /O/FREE w_=layer(w,n)
	setscale /p x,dimoffset(w,0),dimdelta(w,0),w_
	setscale /p y,dimoffset(w,1),dimdelta(w,1),w_
	return w_
End

threadsafe function /wave Beam(w,row,col)
	wave w
	variable row,col // The row and column number.  
	
	row=(row>dimsize(w,0)) ? 0 : row
	col=(col>dimsize(w,1)) ? 0 : col
	imagetransform /beam={(row),(col)} getBeam w
	wave w_beam
	setscale /p x,dimoffset(w,2),dimdelta(w,2),w_beam
	return w_beam
End

threadsafe function /wave sub(w,indices)
	wave w
	wave indices
	
	variable i
	indices[1][]=numtype(indices[1][q]) ? (dimoffset(w,q)+dimsize(w,q)*dimdelta(w,q)) : indices[1][q]
	switch(dimsize(indices,1))
		case 0:
		case 1:
			duplicate /free/r=(indices[0],indices[1]) w,w_
			break
		case 2:
			duplicate /free/r=(indices[0][0],indices[1][0])(indices[0][1],indices[1][1]) w,w_
			break
		case 3:
			duplicate /free/r=(indices[0][0],indices[1][0])(indices[0][1],indices[1][1])(indices[0][2],indices[1][2]) w,w_
			break
		case 4:
			duplicate /free/r=(indices[0][0],indices[1][0])(indices[0][1],indices[1][1])(indices[0][2],indices[1][2])(indices[0][3],indices[1][3]) w,w_
			break
	endswitch
	return w_
end

threadsafe function setRow(w,source,row[,layer])
	wave w,source
	variable row,layer
	
	multithread w[row][][layer]=source[q]
end

threadsafe function setColumn(w,source,col[,layer])
	wave w,source
	variable col,layer
	
	if(paramisdefault(layer))
		imagetransform /D=source /G=(col) putCol w
	else
		imagetransform /D=source /G=(col) /P=(layer) putCol w
	endif
	//multithread w[][col][layer]=source[p]
end

threadsafe function setLayer(w,source,layer)
	wave w,source
	variable layer
	
	multithread w[][][layer]=source[p][q]
end

threadsafe function /wave GetChunk(w,dim,n)
	wave w
	variable dim,n
	
	switch(dim)
		case 0:
			duplicate /free/r=[n,n][][][] w,result
			break
		case 1:
			duplicate /free/r=[][n,n][][] w,result
			break
		case 2:
			duplicate /free/r=[][][n,n][] w,result
			break
		case 3:
			duplicate /free/r=[][][][n,n] w,result
			break
		default:
			make /free/n=0 result
			break
	endswitch
	return result
end

threadsafe function /wave GetBeam(w,dim,ind)
	wave w,ind
	variable dim
	
	switch(dim)
		case 0:
			duplicate /free/r=[][ind[0],ind[0]][ind[1],ind[1]][ind[2],ind[2]] w,result
			break
		case 1:
			duplicate /free/r=[ind[0],ind[0]][][ind[1],ind[1]][ind[2],ind[2]] w,result
			break
		case 2:
			duplicate /free/r=[ind[0],ind[0]][ind[1],ind[1]][][ind[2],ind[2]] w,result
			break
		case 3:
			duplicate /free/r=[ind[0],ind[0]][ind[1],ind[1]][ind[2],ind[2]][] w,result
			break
		default:
			make /free/n=0 result
			break
	endswitch
	return result
end

threadsafe function /wave OpBeams(w,dim,op[,mt])
	wave w
	variable dim
	string op
	variable mt // Multithreaded.  
	
	make /free/n=4 dims=p
	deletepoints dim,1,dims
	make /free/n=(dimsize(w,dims[0]),dimsize(w,dims[1]),dimsize(w,dims[2])) result
	strswitch(op)
		case "mean":
			if(mt)
				multithread result=mean(GetBeam(w,dim,{p,q,r}))
			else
				result=mean(GetBeam(w,dim,{p,q,r}))
			endif
			break
		case "stdev":
			if(mt)
				multithread result=sqrt(variance(GetBeam(w,dim,{p,q,r})))
			else
				result=sqrt(variance(GetBeam(w,dim,{p,q,r})))
			endif
			break
		case "sem":
			if(mt)
				multithread result=SEM(GetBeam(w,dim,{p,q,r}))
			else
				result=SEM(GetBeam(w,dim,{p,q,r}))
			endif
			break
		case "CV":
			if(mt)
				multithread result=ComputeCV(GetBeam(w,dim,{p,q,r}))
			else
				result=ComputeCV(GetBeam(w,dim,{p,q,r}))
			endif
			break
		case "Z":
			wave w1=OpBeams(w,dim,"mean",mt=mt)
			wave w2=OpBeams(w,dim,"stdev",mt=mt)
			result=w1/w2
			break
		case "T":
			wave w1=OpBeams(w,dim,"mean",mt=mt)
			wave w2=OpBeams(w,dim,"sem",mt=mt)
			result=w1/w2
			break
		default:
			printf "No such op: %s; .\r",op
	endswitch
	return result
end

threadsafe function /wave MeanBeams(w,dim[,mt])
	wave w
	variable dim,mt
	
	return OpBeams(w,dim,"Mean",mt=mt)
end

threadsafe function /wave StdevBeams(w,dim[,mt])
	wave w
	variable dim,mt
	
	return OpBeams(w,dim,"StDev",mt=mt)
end

threadsafe function /wave SEMBeams(w,dim[,mt])
	wave w
	variable dim,mt
	
	return OpBeams(w,dim,"SEM",mt=mt)
end

threadsafe function /wave CVBeams(w,dim[,mt])
	wave w
	variable dim,mt
	
	return OpBeams(w,dim,"CV",mt=mt)
end

threadsafe function /wave ZBeams(w,dim[,mt])
	wave w
	variable dim,mt
	
	return OpBeams(w,dim,"Z",mt=mt)
end

threadsafe function /wave TBeams(w,dim[,mt])
	wave w
	variable dim,mt
	
	return OpBeams(w,dim,"T",mt=mt)
end

function /wave Matrix2Waves(m)
	wave m
	
	variable i
	make /free/wave/n=(dimsize(m,1)) result
	for(i=0;i<dimsize(m,1);i+=1)
		matrixop /free w=col(m,i)
		result[i]=w
	endfor
	return result
end

function /wave Transpose(w)
	wave w
	
	matrixop /free wt=w^t
	return wt
end

function /wave SubtractMean(w)
	wave w
	wavestats /q/m=1 w
	duplicate /free w,w1
	w1-=v_avg
	return w1
end

Function Redim(w,dims)
	wave w
	wave dims
	
	switch(numpnts(dims))
		case 1:
			redimension /n=(dims[0]) w 
			break
		case 2:
			redimension /n=(dims[0],dims[1]) w 
			break
		case 3:
			redimension /n=(dims[0],dims[1],dims[2]) w 
			break
		case 4:
			redimension /n=(dims[0],dims[1],dims[2],dims[3]) w 
			break
		default:
			break
	endswitch
End

function Convolve2(kernel,w[,col])
	wave kernel,w
	variable col
	variable i,n_cols = max(1,dimsize(w,1))
	for(i=0;i<n_cols;i+=1)
		if(paramisdefault(col) || i==col)
			duplicate /free/r=[][i,i] w,w_col
			duplicate /free/r=[][i,i] kernel,kernel_col
			convolve kernel_col,w_col
			w[][i] = w_col[p]
		endif
	endfor
end

Function PrintWave(w)
	wave w
	
	print w
End

// Turns a wave of waves into a matrix.  
threadsafe Function /wave W2matrix(waves)
	wave /wave waves
	
	wave w=waves[0]
	variable i
	string name=""
	for(i=0;i<numpnts(waves);i+=1)
		wave w=waves[i]
		if(i==0)
			variable rows=dimsize(w,0)
			variable cols=max(1,dimsize(w,1))
			make /free/n=(rows,cols) matrix=w[p][q]
		else
			variable newCols=max(1,dimsize(w,1))
			redimension /n=(rows,cols+newCols) matrix
			matrix[][cols,]=w[p][q-cols]
			cols+=newCols
		endif
		name+=nameofwave(w)+"_"
	endfor
	copyscales w,matrix
	Note matrix,"NAME="+name
	return matrix
End

function InWav(w,xx[,int])
	wave w
	variable xx,int
	
	if(int)
		findvalue /i=(xx) w
	else
		findvalue /v=(xx) w
	endif
	return v_value>=0
end

function InWavT(w,xx)
	wave /t w
	string xx
	
	findvalue /text=(xx) /txop=4 w
	return v_value>=0
end

function /wave SortRanks(w)
	wave w
	duplicate /free w,leaderboard,ranks
	leaderboard=p; ranks=p
	sort w,leaderboard
	sort leaderboard,ranks
	return ranks
end

// Turns e.g. a wave of spike times into a wave of 1's and 0's, with 1's at the X-values corresponding to those spike times.  
Function Events2Binary(events,template[eventNums,before,after])
	wave events // wave of event times.  
	wave template // wave to overwrite with 1's and 0's. 
	wave eventNums // Optional wave of numbers to assign to each event.  Default is to use 1's.   
	variable before,after // Optional lengths of 1-ness before and after each time.  
	
	template=0
	variable i
	for(i=0;i<numpnts(events);i+=1)
		if(paramisdefault(eventNums))
			variable eventNum=1
		else
			eventNum=eventNums[i]
		endif
		template[x2pnt(template,events[i]-before),x2pnt(template,events[i]+after)]=eventNum
	endfor
End

threadsafe function /s dimsizes(w)
	wave w
	
	string sizes=""
	variable i
	do
		variable size=dimsize(w,i)
		if(i==0 || size)
			sizes+=num2str(size)+" "
		endif
		i+=1
	while(size && i<4)
	return sizes
end

function SortMatrix(w,dim,key[,reverse_])
	wave w
	variable dim // Dimension to sort.  0 sorts each row; 1 sorts each column.  
	variable key // Index of the key row/column.  -1 to sort each independently.  
	variable reverse_ // Reverse sort.  
	
	if(key>=0)
		switch(dim)
			case 0:
				wave w_key=Row(w,key)
				break
			case 1:
				wave w_key=Col(w,key)
				break
		endswitch
	endif
	variable i
	for(i=0;i<dimsize(w,dim);i+=1)
		switch(dim)
			case 0:
				wave w_=Row(w,i)
				if(key<0)
					wave w_key=w_
				endif
				if(reverse_)
					sort /r w_key,w_
				else
					sort w_key,w_
				endif
				w[i][]=w_[q]
				break
			case 1:
				wave w_=Col(w,i)
				if(key<0)
					wave w_key=w_
				endif
				if(reverse_)
					sort /r w_key,w_
				else
					sort w_key,w_
				endif
				w[][i]=w_[p]
				break
		endswitch
	endfor
end

Function WaveVarOrDefault(path,defaultVal)
	String path // Wave path plus indices, e.g. root:smith[3]
	Variable defaultVal
	
	String name
	Variable xx,yy,zz
	sscanf path,"%[A-Za-z0-9:][%f][%f][%f]",name,xx,yy,zz
	Wave /Z Wav=$name
	if(WaveExists(Wav))
		return Wav[xx][yy][zz]
	else
		return defaultVal
	endif
End

Function /S WaveTVarOrDefault(path,defaultStr)
	String path // Wave path plus indices, e.g. root:smith[3]
	String defaultStr
	
	String name
	Variable xx,yy,zz
	sscanf path,"%[A-Za-z0-9:][%f][%f][%f]",name,xx,yy,zz
	Wave /Z/T WavT=$name
	if(WaveExists(Wav))
		return WavT[xx][yy][zz]
	else
		return defaultStr
	endif
End

// Returns a semicolon-separated list of all the Igor windows that use 'w'.  
// Only searches graphs and tables, and only works on X and Y waves.  
Function /S WhereUsed(w)
	Wave w
	String where_used=""
	Variable i
	String win_list=WinList("*",";","WIN:3")
	for(i=0;i<ItemsInList(win_list);i+=1)
		String win_name=StringFromList(i,win_list)
		Variable j=0
		Do
			Wave /Z Candidate=WaveRefIndexed(win_name,j,3)
			if(!WaveExists(Candidate))
				break
			endif
			if(StringMatch(GetWavesDataFolder(Candidate,2),GetWavesDataFolder(w,2)))
				where_used+=win_name+";"
			endif
			j+=1
		While(1)
	endfor
	return where_used
End

// Returns index of the the numeric value 'value' or NaN if not found.  
// Warning: The FindValue operation sets V_Value to -1 if not found.  
Function FindValue2(Wav,value[,tolerance])
	Wave Wav
	Variable value,tolerance
	
	tolerance=paramisdefault(tolerance) ? 1.0E-7 : tolerance
	FindValue /V=(value) /T=(tolerance) Wav
	if(V_Value>=0)
		return V_Value
	else
		return NaN
	endif
End

// Returns index of the the numeric value 'value' or NaN if not found.  
// Warning: The FindValue operation sets V_Value to -1 if not found.  
Function FindValue2T(w,value[,start])
	wave /T w
	string value
	variable start
	
	findvalue /TEXT=(value)/S=(start)/TXOP=4 w
	if(v_value>=0)
		return v_value
	else
		return NaN
	endif
End

// Extracts all the points from all of the waves matching 'match' that meet the criteria specified.  
Function Extract2(Source,criteria[,match])
	Wave Source
	String criteria // e.g. "numtype(Source)==0"
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	String source_name=NameOfWave(Source)
	criteria=ReplaceString("Source",criteria,source_name)
	String wave_list=WaveList(match,";","")
	Variable i
	for(i=0;i<ItemsInList(wave_list);i+=1)
		String /G E2_wave_name=StringFromList(i,wave_list)
		if(!StringMatch(E2_wave_name,source_name))
			String command="Extract /O "+E2_wave_name+","+E2_wave_name+","+criteria
			Execute /Q command
		endif
	endfor
	command="Extract /O "+source_name+","+source_name+","+criteria
	Execute /Q command
	KillStrings /Z E2_wave_name
End

Function /wave Extract3(w,criteria)
	wave w
	string criteria
	
	string temp=UniqueName("temp",1,0)
	string cmd="Extract /o "+getwavesdatafolder(w,2)+","+temp+","+criteria
	execute /Q cmd
	duplicate /free $temp result
	killwaves /z $temp
	return result
End

// Sort a multidimensional wave according to one of the columns.  
// INCOMPLETE.  
Function SortMD(Matrix,index)
	Wave matrix // The multidimensional wave to be sorted.  
	Wave index // The column number to put in order.  
	Variable i
	for(i=0;i<dimsize(Matrix,1);i+=1)
		Duplicate /o/R=[][i,i] Matrix Column
		Redimension /n=(numpnts(Column),1) Column
		KillWaves Column
	endfor
End

// Returns the maximum value at the given index from the list of waves.  
Function MaxWaveList(index,wave_list)
	Variable index
	String wave_list
	Variable i,maxx=-Inf
	for(i=0;i<ItemsInList(wave_list);i+=1)
		Wave w=$StringFromList(i,wave_list)
		if(w[index]>maxx)
			maxx=w[index]
		endif
	endfor
	if(numtype(maxx)!=0)
		maxx=NaN
	endif
	return maxx
End

// Returns the minimum value at the given index from the list of waves.  
Function MinWaveList(index,wave_list)
	Variable index
	String wave_list
	Variable i,minn=Inf
	for(i=0;i<ItemsInList(wave_list);i+=1)
		Wave w=$StringFromList(i,wave_list)
		if(w[index]<minn)
			minn=w[index]
		endif
	endfor
	if(numtype(minn)!=0)
		minn=NaN
	endif
	return minn
End

// Make a 2D wave from a bunch of 1D waves.  
Function Make2DWave(stem,suffix_list[,parity])
	String stem // e.g. "sweep"
	String suffix_list // e.g. "1;2;3;4"
	Variable parity // 0 for even, 1 for odd, and omit for both.  
	
	suffix_list=ListExpand(suffix_list)
	Variable num_waves=ItemsInList(suffix_list)
	Make /o/n=(0,0) TwoDWave=0
	Variable i,index=0
	for(i=0;i<ItemsInList(suffix_list);i+=1)
		if(ParamIsDefault(parity) || mod(i,2)==parity)
			String wave_name=stem+StringFromList(i,suffix_list)
			Wave OneDwave=$wave_name
			Wave ODW_ds=$Downsample(OneDWave,10)
			Redimension /n=(max(dimsize(ODW_ds,0),dimsize(TwoDWave,0)),index+1) TwoDWave
			TwoDWave[][index]=ODW_DS[p]
			KillWaves ODW_ds
			index+=1
		endif
	endfor
End

// Takes a pair of X and Y values (event locations and amplitudes) and converts this to a pair of waves 
// that, when plotted against each other, will show blips at the X values with sizes determined by the Y values.  
Function XY2Graph(X_Wave0,Y_Wave0)
	Wave X_Wave0,Y_Wave0
	Duplicate /o X_Wave0 X_Wave
	Duplicate /o Y_Wave0 Y_Wave
	Variable i=0
	Do
		Variable x=X_Wave[i]
		InsertPoints i,1,X_Wave,Y_Wave
		X_Wave[i]=x
		Y_Wave[i]=0
		InsertPoints i+2,1,X_Wave,Y_Wave
		X_Wave[i+2]=x
		Y_Wave[i+2]=0
		i+=3
	While(i<numpnts(X_Wave))
End

// Creates two waves: one a text wave with a point for each unique entry in the text wave 
// 'InWave', and the other a numeric wave with the number of instance of each entry in 'InWave'.  
Function TextHistogram_old(InWave)
	Wave /T InWave
	Make /o/n=0 TH_Counts
	Make /o/T/n=0 TH_Entries
	Variable i
	for(i=0;i<numpnts(InWave);i+=1)
		String entry=InWave[i]
		FindValue /TEXT=entry /TXOP=4 TH_Entries
		if(V_Value>=0)
			TH_Counts[V_Value]+=1
		else
			InsertPoints 0,1,TH_Counts,TH_Entries
			TH_Counts[0]=1
			TH_Entries[0]=entry
		endif
	endfor
End

threadsafe Function /wave UniqueValues(w[,exclude])
	wave w,exclude
	
	make /free/n=0 result
	variable i,index=0
	for(i=0;i<numpnts(w);i+=1)
		if(numtype(w[i])==2)
			continue // Don't include NaN's.  
		endif
		if(numpnts(exclude))
			findvalue /v=(w[i]) exclude
			if(v_value>=0)
				continue
			endif
		endif
		findvalue /v=(w[i]) result
		if(v_value<0)
			result[numpnts(result)]={w[i]}
		endif
	endfor
	return result
end

// Creates a wave with a point for each unique value in 'w'.  The value of the point is the number of instances of that value, and the row label is the value itself.  
threadsafe Function /wave DenseHistogram(w[,exclude])
	wave w
	wave exclude
	
	make /free/n=0 denseHist
	variable i,index=0
	make /free/n=0 found
	for(i=0;i<numpnts(w);i+=1)
		if(numtype(w[i])==2)
			continue // Don't include NaN's.  
		endif
		if(numpnts(exclude))
			findvalue /v=(w[i]) exclude
			if(v_value>=0)
				continue
			endif
		endif
		findvalue /v=(w[i]) found
		if(v_value<0)
			found[index]={w[i]}
			denseHist[index]={1}
			index+=1
		else
			denseHist[v_value]+=1
		endif
	endfor
	for(i=0;i<numpnts(found);i+=1)
		setdimlabel 0,i,$num2str(found[i]),denseHist
	endfor
	return denseHist
End

// Make a synaptic current based upon a single decaying exponential function.  
Function /wave AlphaSynapso(amplitude,t_decay,offset,duration[,kHz,name])
	Variable amplitude,t_decay,offset,duration // In mV, ms, ms, and ms.    
	Variable kHz
	String name // The name of the output wave.  
	kHz=ParamIsDefault(kHz) ? 10 : kHz
	name=SelectString(ParamIsDefault(name),name,"Alpho")
	Make /free/n=(duration*kHz) Alpho
	duration/=1000; offset/=1000; t_decay/=1000 // Convert from ms to s.  
	SetScale x,-offset,duration-offset,Alpho
	Alpho=x>0 ? x*exp(-x/t_decay) : 0
	Alpho*=amplitude*(exp(1)/t_decay) // Normalize so that peak value is 'amplitude'.  
	return Alpho
End

// Bend a wave so that the area to the left of cursor A remains the same, the area to the right of cursor B increases by degree (additively),
// and the area between the cursors goes up by degree times the fractional position between the cursors.  
// Useful for fixing periods of linear drift in a recording.  
Function Bend(degree[,w,x1,x2])
	Variable degree
	Wave w
	Variable x1,x2
	if(ParamIsDefault(w))
		Wave w=CsrWaveRef(A)
	endif
	x1=ParamIsDefault(x1) ? xcsr(A) : x1
	x2=ParamIsDefault(x2) ? xcsr(B) : x2
	
	Variable p1=x2pnt(w,x1)
	Variable p2=x2pnt(w,x2)
	Variable denominator=p2-p1
	w[p1,p2]+=degree*(p-p1)/denominator
	w[p2+1,]+=degree
End

// Add to a wave between the cursors.    
// Useful for fixing periods of linear drift in a recording.  
Function Add(amount[,w,x1,x2])
	Variable amount
	Wave w
	Variable x1,x2
	if(ParamIsDefault(w))
		Wave w=CsrWaveRef(A)
	endif
	x1=ParamIsDefault(x1) ? xcsr(A) : x1
	x2=ParamIsDefault(x2) ? xcsr(B) : x2
	
	Variable p1=x2pnt(w,x1)
	Variable p2=x2pnt(w,x2)
	Variable denominator=p2-p1
	w[p1,p2]+=amount
End

// Clips (in points) a wave corresponding to a trace to the area visible in the window.  
Function Clip2Visible([trace,win])
	string trace,win
	
	win=selectstring(paramisdefault(win),win,winname(0,1))
	trace=selectstring(paramisdefault(trace),trace,TopTrace(win=win))
	
	wave w=tracenametowaveref(win,trace)
	doupdate
	string xAxis=tracexaxis(trace,win=win)
	getaxis /q $xAxis
	duplicate /free/r=(v_min,v_max) w,segment
	duplicate /o segment, $GetWavesDataFolder(w,2)
End

Function FindLevels2(w,exceed,reset)
	Wave w
	Variable exceed,reset
	FindLevels /Q w,exceed; Duplicate /o W_FindLevels ExceedLevels
	FindLevels /Q w,reset; Duplicate /o W_FindLevels ResetLevels
	// Variable i=w<exceed ? 0 : 1 // If the first point is less than exceed, the first level crossing will be up, so start there.  Otherwise, start at the second level crossing
	Make /o/n=(0,2) Regions
	Variable index=0,i=0,j=0
	Do
		Redimension /n=(index+1,2) Regions
		Do
			if(ExceedLevels[i] > ResetLevels[j])
				break
			endif
			i+=1
		While(i<numpnts(ExceedLevels))
		Regions[index][0]=ExceedLevels[i]
		Do
			if(ResetLevels[j] > ExceedLevels[i])
				break
			endif
			j+=1
		While(j<numpnts(ResetLevels))
		Regions[index][1]=ResetLevels[j]
		index+=1
	While(i<numpnts(ExceedLevels))
End

Function CorrelatedNoise(amplitude,tau,Template)
	Variable amplitude // The amplitude of the standard deviation of the noise.  
	Variable tau // Correlation time in x units.    
	Wave Template
	Variable delta=dimdelta(Template,0)
	tau/=delta
	Template=0
	Template=gnoise(1)+(Template[p-1]*exp(-1/tau))
	WaveStats /Q Template
	Variable scale=amplitude/V_sdev
	Template*=scale
End

Function FirstNonZero(w)
	Wave w
End

Function Cutoff(w,low,high)
	Wave w
	Variable low,high
	w=(w>=low && w <=high) ? w : NaN
End

// Deletes duplicate values from a text wave, and also from the corresponding indices of companion waves if they are provided.  
Function DeleteTextDuplicates(w[,companions])
	Wave /T w
	String companions
	Variable i,j,num_companions; String item
	if(!ParamIsDefault(companions))
		num_companions=ItemsInList(companions)
	else
		num_companions=0
	endif
	Do
		item=w[i]
		FindValue /S=(i+1) /TEXT=item /TXOP=4 w
		if(V_Value>=0)
			DeletePoints V_Value,1,w
			for(j=0;j<num_companions;j+=1)
				DeletePoints V_Value,1,$StringFromList(j,companions)
			endfor
		else
			i+=1
		endif
	While(i<numpnts(MiniNames))
End

// Deletes duplicate values from a text wave, and also from the corresponding indices of companion waves if they are provided.  
Function DeleteDuplicates(w[,companions])
	Wave w
	String companions
	Variable i,j,item,num_companions
	if(!ParamIsDefault(companions))
		num_companions=ItemsInList(companions)
	else
		num_companions=0
	endif
	Do
		item=w[i]
		FindValue /S=(i+1) /V=(item) w
		if(V_Value>=0)
			DeletePoints V_Value,1,w
			for(j=0;j<num_companions;j+=1)
				DeletePoints V_Value,1,$StringFromList(j,companions)
			endfor
		else
			i+=1
		endif
	While(i<numpnts(MiniNames))
End

// Like rightx(), except return the x value of the last point, not the x value of the point after the last point.  
Function Rightx2(w)
	Wave w
	return pnt2x(w,numpnts(w)-1)
End

// Sets all the 'areas' listed in regions to 'value'
Function SetRegions(w,regions,value)
	Wave w
	String regions
	Variable value
	Variable i,start,finish; String region
	for(i=0;i<ItemsInList(regions);i+=1)
		region=StringFromList(i,regions)
		start=NumFromList(0,region,sep=",")
		start=x2pnt(w,start)
		finish=NumFromList(1,region,sep=",")
		finish=x2pnt(w,finish)
		w[start,finish]=value
	endfor
End 

// Sets the scale of all the waves in a given folder.  
Function SetFolderScale(folder,offset,delta)
	String folder // Full folder path.  
	Variable offset,delta
	String curr_folder=GetDataFolder(1)
	SetDataFolder $folder
	String wave_list=WaveList("*",";","")
	Variable i
	for(i=0;i<ItemsInList(wave_list);i+=1)
		String wave_name=StringFromList(i,wave_list)
		SetScale /P x,offset,delta,$wave_name
	endfor
	SetDataFolder $curr_folder
End

// Multiplies all the waves in 'folder' by 'value'.  
Function MultiplyFolder(folder,value)
	String folder // Full folder path.  
	Variable value
	String curr_folder=GetDataFolder(1)
	SetDataFolder $folder
	String wave_list=WaveList("*",";","")
	Variable i
	for(i=0;i<ItemsInList(wave_list);i+=1)
		String wave_name=StringFromList(i,wave_list)
		Wave w=$wave_name
		w*=value
	endfor
	SetDataFolder $curr_folder
End

// Return the index of the value of it is in the wave, or -1 if it is not
Function WaveSearch(w,val)
	Wave w
	Variable val
	Extract /O/INDX w,tempWS,w==val
	Variable loc
	if(numpnts(tempWS)>0)
		loc=tempWS[0]
	else
		loc=-1
	endif
	KillWaves tempWS
	return loc
End

Function TextWaveSearch(w,str)
	Wave /T w
	String str
	Extract /O/INDX /T w,tempWS,StringMatch(w,str)
	Variable loc
	if(numpnts(tempWS)>0)
		loc=tempWS[0]
	else
		loc=-1
	endif
	KillWaves tempWS
	return loc
End

// Starting from the integer 'start', finds the first integer that is not a value in the wave 'w'.  
Function FirstOpen(w,start)
	Wave w
	Variable start
	Variable i=start
	Do
		FindValue /V=(i) w 
		i+=1
	While(V_Value>=0)
	return i-1
End

Function /S Sweeps2Matrix(prefix,sweeps)
	String prefix
	String sweeps
	String matrix_name=CleanupName(prefix+sweeps,0)
	sweeps=ListExpand(sweeps)
	Make /o/n=(0,ItemsInList(sweeps)) $matrix_name
	Wave WaveMatrix=$matrix_name
	Variable i
	for(i=0;i<ItemsInList(sweeps);i+=1)
		Wave Sweep=$(prefix+StringFromList(i,sweeps))
		if(numpnts(sweep)>dimsize(WaveMatrix,0))
			Redimension /n=(numpnts(sweep),-1) WaveMatrix
		endif
		WaveMatrix[][i]=Sweep[p]
	endfor	
	SetScale /P x,dimOffset(Sweep,0),dimdelta(Sweep,0), WaveMatrix
	for(i=0;i<ItemsInList(sweeps);i+=1)
		Wave Sweep=$(prefix+StringFromList(i,sweeps))
		if(numpnts(sweep)<dimsize(WaveMatrix,0))
			WaveMatrix[numpnts(sweep),][i]=NaN
		endif
	endfor	
	return matrix_name
End

// Turns a wave of times to a wave where points corresponding to those times are 1, and all other points are 0.  
Function Times2Bins(Times[,length,scale])
	Wave Times
	Variable length,scale // Length in seconds, scale in Hz
	if(ParamIsDefault(length))
		WaveStats /Q Times
		length=V_max
	endif
	scale=ParamIsDefault(scale) ? 1000 : scale // 1 kHz (frequency doesn't have to match the original data sampling frequency)
	Make /o/n=(length*scale) $(NameOfWave(Times)+"_Bins")=0
	Wave Bins=$(NameOfWave(Times)+"_Bins")
	SetScale /P x,0,1/scale,Bins
	Variable i
	for(i=0;i<numpnts(Times);i+=1)
		Bins[floor(Times[i]*scale)]=1
	endfor
End  

// Multiply the wave with cursor A on it by a factor of n
Function Multiply(n)
	Variable n
	Wave w=CsrWaveRef(A)
	w*=n
End

// Returns the number of entries of a ascending wave whose values are between x and y.  
Function NumBetweenXandY(w,x,y)
	Wave w
	Variable x,y
	Variable num=0
	Duplicate /o w tempBetween
	tempBetween=(tempBetween>x && tempBetween < y) ? 1 : 0
	num=sum(tempBetween)
	KillWaves tempBetween
	return num
End

// Makes an inversion of the wave (also interpolates, so number of data points will be different)
Function /wave Invert(w[,lo,hi,points])
	Wave w
	Variable lo,hi,points
#if exists("Interpolate2")
	WaveStats /Q w
	lo=ParamIsDefault(lo) ? V_min : lo
	hi=ParamIsDefault(hi) ? V_max : hi
	points=ParamIsDefault(points) ? 1000 : points
	String invert_name=CleanUpName(NameOfWave(w)+"_Inv",1)
	Make /o/n=(points) $invert_name /wave=Inverted=0
	SetScale /I x,lo,hi,Inverted
	Duplicate /free w Temp
	Temp=DimOffset(w,0)+p*DimDelta(w,0)
	Interpolate2 /T=1 /I=3 /Y=Inverted w,Temp
	return Inverted
#else
	printf "Need Interpolate XOP.\r"
#endif
End

Function Segment2Wave([name])
	String name
	if(ParamIsDefault(name))
		name="test"
	endif
	Duplicate /o /R=(xcsr(A),xcsr(B)) CsrWaveRef(A), test
End

// Turns positive values into the log of themselves, and negative values into the -log of their negative selves.  
// Values less than 1 will be left alone.  Values greater than 1 will have 1 added to themselves at the end.  
Function LogPosAndNeg(w)
	Wave w
	w=(w > 1) ? log(w) + 1 : w
	w=(w < -1) ? -log(-w) - 1 : w
End

// Add 'num' to the region between the cursors
Function RegionAdd(num)
	Variable num
	Wave w=CsrWaveRef(A)
	w[pcsr(A),pcsr(B)]+=num
End

// Find the number of values in a wave between x1 and x2, inclusive.  
Function NumBetween(w,x1,x2)
	Wave w
	Variable x1,x2
	Duplicate /o w tempNumBetween
	Redimension /n=(numpnts(tempNumBetween)) tempNumBetween
	DeleteNans(tempNumBetween)
	Variable i,j=0
	for(i=0;i<numpnts(tempNumBetween);i+=1)
		if(tempNumBetween[i]>=x1)
			break
		endif
	endfor
	for(j=i;j<numpnts(tempNumBetween);j+=1)
		if(tempNumBetween[j]>x2)
			break
		endif
	endfor
	KillWaves tempNumBetween
	return j-i
End

// Returns the x value that is 'fract' from the left-most index of the wave.
Function FractionOfWave(w,fract)
	Wave w
	Variable fract
	Variable length=rightx(w)-leftx(w)
	Variable start=leftx(w)
	return start+length*fract
End

// For a sorted, ascending wave, returns the point whose value comes AFTER 'num'.
// If no value comes after 'num', returns Inf.  
// Useful for using as an argument for InsertPoints, in order to insert a new value.  
Function BinarySearch2(w,num)
	Wave w
	Variable num
	Variable loc=BinarySearch(w,num)
	switch(loc)
		case -1: 
			return 0
			break
		case -2:
			return numpnts(w)
			break
		case -3:
			return 0
			break
		default:
			return loc+1
			break
	endswitch
End

// For a sorted, ascending wave, inserts 'num' where it would go to keep the wave in sorted order.  
Function InsertInOrder(w,num[,companions])
	Wave w
	Variable num
	String companions
	Variable loc=BinarySearch2(w,num)
	InsertPoints loc,1,w
	w[loc]=num
	Variable i
	if(!ParamIsDefault(companions))
		for(i=0;i<ItemsInList(companions);i+=1)
			Wave Companion=$StringFromList(i,companions)
			InsertPoints loc,1,Companion
			Companion[loc]=num
		endfor
	endif
End

Function SmoothRegion(num[,w,x1,x2])
	Variable num
	Wave w
	Variable x1,x2
	if(ParamIsDefault(w))
		Wave w=CsrWaveRef(A)
	endif
	x1=ParamIsDefault(x1) ? xcsr(A) : x1
	x2=ParamIsDefault(x2) ? xcsr(B) : x2
	Duplicate /o /R=(x1,x2) w tempSmoothRegion
	Smooth num,tempSmoothRegion
	w=(x>x1 && x<x2) ? tempSmoothRegion(x) : w 
End

Function SuppressRegions(w,regions,[factor,value,method])
	Wave w
	String regions
	Variable factor,value
	String method
	if(ParamIsDefault(method))
		method="Squash"
	endif
	if(ParamIsDefault(factor))
		factor=20
	endif
	Variable i,start_x,start_p,finish_x,finish_p
	String region
	for(i=0;i<ItemsInList(regions);i+=1)
		region=StringFromList(i,regions)
		start_x=NumFromList(0,region,sep=",")
		start_p=x2pnt(w,start_x)
		finish_x=NumFromList(1,region,sep=",")
		finish_p=x2pnt(w,finish_x)
		strswitch(method)
			case "Constant": 
				w[start_p,finish_p]=value
				break
			case "Squash":
				SuppressRegion(factor,w=w,x1=start_x,x2=finish_x)
				break
			case "Boxcar":
				Smooth2(w,factor,method="boxcar")
				break
			case "Binomial":
				Smooth2(w,factor,method="binomial")
				break
			case "Delete":
				// Not yet implemented.  
				break
		endswitch
	endfor
End

// Suppress a region to have 'factor' times less standard deviation than it had before.  
Function SuppressRegion(factor[,w,x1,x2])
	Variable factor
	Wave w
	Variable x1,x2
	if(ParamIsDefault(w))
		Wave w=CsrWaveRef(A)
	endif
	x1=ParamIsDefault(x1) ? xcsr(A) : x1
	x2=ParamIsDefault(x2) ? xcsr(B) : x2
	if(x2>=leftx(w) && x1<=rightx(w))
		Variable p1=x2pnt(w,x1)
		Variable p2=x2pnt(w,x2)
		Variable y1=w[p1], y2=w[p2]
		
		Variable slope=(y2-y1)/(p2-p1)
		w[p1,p2] = (y1+slope*(p-p1))+((w[p]-(y1+slope*(p-p1)))/factor)
	endif
End

// Smooths a segment of a wave.  
Function Smooth2(w,smooth_factor[,left,right,method])
	Wave w
	Variable smooth_factor,left,right
	String method
	if(ParamIsDefault(method))
		method="binomial"
	endif
	left=ParamIsDefault(left) ? leftx(w) : left
	right=ParamIsDefault(right) ? rightx(w) : right
	Duplicate /o/R=(left,right) w segment
	strswitch(method)
		case "binomial": 
			Smooth /E=3 smooth_factor, segment
			break
		case "boxcar":
			Smooth /B=1/E=3 smooth_factor, segment
			break
	endswitch
	Variable p1=x2pnt(w,left)
	Variable p2=x2pnt(w,right)
	w[p1,p2]=segment[p-p1]
	KillWaves /Z segment
End


Function GeoMean(w)
	Wave w
	Duplicate /o w tempGeoMean
	Extract /O tempGeoMean,tempGeoMean,tempGeoMean>0 && tempGeoMean<Inf
	tempGeoMean=log(tempGeoMean)
	WaveStats /Q tempGeoMean
	Variable summ=V_avg // Equal to the average of the log of the product of the original points in the wave
	KillWaves tempGeoMean
	return 10^(summ)
End

// Make the middle point of the wave be x=0, and otherwise preserves the scaling
Function CenterWave(w)
	Wave w
	Variable range=dimdelta(w,0)*numpnts(w)
	SetScale /I x,-range/2,range/2,w
End

Function WaveDuration(w)
	Wave w
	return dimsize(w,0)*dimdelta(w,0)
End

Function Squeeze(matrix)
	Wave matrix
	Variable i
	make /free/n=4 sizes=dimsize(matrix,p)
	extract /free sizes,new_sizes,sizes>1
	new_sizes[4]={0}
	redimension /n=(new_sizes[0],new_sizes[1],new_sizes[2],new_sizes[3])/e=1 matrix
End

Function Squish(matrix,dim)
	Wave matrix
	Variable dim
	Variable i
	switch(dim)
		case 0:
			Duplicate /O/R=[][0,0] matrix, Squished; Squished=0
			for(i=0;i<dimsize(matrix,dim);i+=1)
				Duplicate /O/R=[i,i][] matrix,row
				WaveStats /Q/M=1 row
				Squished[i]=V_avg
			endfor
			break
		case 1:
			Duplicate /O/R=[0,0][] matrix, Squished; Squished=0
			for(i=0;i<dimsize(matrix,dim);i+=1)
				Duplicate /O/R=[][i,i] matrix,column
				WaveStats /Q/M=1 column
				Squished[i]=V_avg
			endfor
			Redimension /n=(numpnts(Squished)) Squished
			break
	endswitch
	KillWaves /Z row,column
End

// Turns a point in the wave, e.g. a piece of spike noise, into a NaN so it doesn't affect averaging or fitting.  
Function NanifyButton()
	Cursors()
	NewPanel /K=1 /W=(100,100,200,200) /N=NanifyButton
	Button NanifyButton, pos={5,5}, size={90,90}, proc=Nanify, title="NaNify"
	Button Previous, title="\\W617",proc=NextInList
	Button Next, title="\\W623",proc=NextInList
End

Function NaNify(ctrlName) : ButtonControl
	String ctrlName
	Wave w=CsrWaveRef(A)
	w[pcsr(A)]=NaN
End

Function NaNRegion([parity])
	String parity
	Wave w=CsrWaveRef(A)
	if(ParamIsDefault(parity))
		w[pcsr(A),pcsr(B)]=NaN
	else
		Variable parity_var
		strswitch(parity)
			case "Even":
				parity_var=0
				break
			case "Odd":
				parity_var=1
				break
			default:
				return 0
				break
		endswitch
		w[pcsr(A),pcsr(B)]=mod(p-pcsr(A),2)==parity_var ? NaN : w[p]
	endif
End

Function ZeroRegion()
	Wave w=CsrWaveRef(A)
	w[pcsr(A),pcsr(B)]=0
End

// Pads a wave with the last point repeated n times
Function PadWithLast(w,n)
       Wave w
       Variable n
       Variable points=numpnts(w)
       InsertPoints points,1,w
       w[points]=w[points-1]
       return n
End

Function DisplayMatrixWaves(name,[versus,restrict]) // Display the columns of a matrix as waves
	String name // Name of the matrix wave
	Variable versus // Plot all of the columns against column number "versus"
	String restrict // Restrict the plotted columns to match a certain numerical recipe, e.g. only odd columns
	// There is also an optional mask below for selecting only the waves that match certain criteria
	Variable average // Display an average wave as well (1 or 0)
	Wave matrix=$name
	Variable i
	if(ParamIsDefault(versus))
		restrict=""
	endif
	
	Display /K=1 /N=$(name+restrict)
	//if(DataFolderExists(name))
	//	KillDataFolder $name
	//endif
	NewDataFolder /O $name
	//DoWindow /K $name
	
	String path=GetDataFolder(1)+name+":"
	if(ParamIsDefault(versus))
		versus=NaN
	else
	endif
	for(i=0;i<dimsize(matrix,1);i+=1)
		strswitch(restrict)
			case "":
				PlotMatrixColumn(path,name,i,versus=versus)
				break
			case "odd":
				if(mod(i,2)!=0)
					PlotMatrixColumn(path,name,i,versus=versus)
				endif
				break
			case "even":
				if(mod(i,2)==0)
					PlotMatrixColumn(path,name,i,versus=versus)
				endif
				break
		endswitch
	endfor
	
	//KillWaves/Z $(path+name+"_avg") WindowName
	Wave vers=$(path+name+"_"+"versus")
	Make /o/n=(dimsize(matrix,0)) $(path+WinName(0,1)+"_avg")
	Wave avg=$(path+WinName(0,1)+"_avg")
	avg=nan
	if(ParamIsDefault(versus))
		AppendToGraph /C=(0,0,65535) avg
	else
		AppendToGraph /C=(0,0,65535) avg vs vers
	endif
	Cursors()
	CalcAvg("avg")
End

Function PlotMatrixColumn(path,name,column,[versus])
	String path,name // Path of the matrix and its name
	Variable column // Column number to plot
	Variable versus
	Wave matrix=$name
	Variable i
	i=column
	
	if(versus>=0)
		Make /o/n=(dimsize(matrix,0)) $(path+name+"_"+"versus")
		Wave vers=$(path+name+"_"+"versus")
		vers=matrix[p][versus]
	endif
	
	Make /o/n=(dimsize(matrix,0)) $(path+name+"_"+num2str(i))
	Wave piece=$(path+name+"_"+num2str(i))
	piece=matrix[p][i]
	WaveStats/Q piece
	if(V_numNans==0)
		if(versus>=0)
			if(i!=versus)
				AppendToGraph piece vs vers
			endif
		else
			AppendToGraph piece
		endif
	else
		printf "Column %d has NaN entries so it was not plotted (would screw up averaging).\r",i
	endif
End

// Sets every value below 'thresh' equal to 'thresh', and every value above 100 equal to 100.  
Function Crop(thresh)
	Variable thresh
	Wave toCrop=CsrWaveRef(A)
	Variable i
	for(i=0;i<numpnts(toCrop);i+=1)
		if(toCrop[i]<thresh)
			toCrop[i]=thresh // Don't set to NaN, then many Igor function will not work on the data
		elseif(toCrop[i]>100)
			toCrop[i]=100 // Shortens the huge stimulus artifact in voltage clamp
		endif			
	endfor
End

// Dilate time in wave 'w' by an instantaneous factor given by the values in the wave 'dilate'.  
Function Dilate(w,t,dilate)
	wave w,dilate
	variable t // Reference to this time point.  
	
	t=x2pnt(w,t)
	Duplicate /FREE w,oldw
	w=oldw[t+(p-t)*dilate[p]]
End

// For a list of spike times, e.g. "100,200,450;800,950", will generate the wave listISIs={100,250,150}
// Assumes commas separate consecutive spikes, and semicolons separate groups of spikes, 
// where inter-group-intervals are not to be counted.  Also generates the wave listISIs_time_since_first={100,350,150}
Function ISIsfromList(list)
	String list
	Variable i,j
	Make /o/n=0 listISIs
	Make /o/n=0 listISIs_time_since_first
	String sublist
	for(i=ItemsInList(list)-1;i>=0;i-=1) // Go reverse order (easier)
		sublist=StringFromList(i,list)
		InsertPoints 0,ItemsInList(sublist,",")-1,listISIs,listISIs_time_since_first
		for(j=1;j<ItemsInList(sublist,",");j+=1)
			listISIs[j-1]=str2num(StringFromList(j,sublist,","))-str2num(StringFromList(j-1,sublist,","))
			listISIs_time_since_first[j-1]=str2num(StringFromList(j,sublist,","))-str2num(StringFromList(0,sublist,","))
		endfor
	endfor
End

// If the wave has an odd number of points, inserts a new point at the beginning equal to the first point
Function MakeEven(w)
	Wave w
	if(EvenPoints(w))
	else
		InsertPoints 0,1,w
		w[0]=w[1]
	endif
End

// Returns 1 if the wave has an even number of points, and 0 if it has an odd number of points
Function EvenPoints(w)
	Wave w
	Variable points=numpnts(w)
	if(mod(points,2)==0)
		return 1
	else
		return 0
	endif
End

// Returns peak and trough locations and values in the waves peaklocs,peakvals,troughlocs,troughvals
Function FindPeaks([w,first,last,smooth_val,refractory])
	Wave w
	Variable first,last,smooth_val,refractory
	if(ParamIsDefault(w))
		Wave w=CsrWaveRef(A)
	endif
	if(ParamIsDefault(first))
		first=leftX(w)
	endif
	if(ParamIsDefault(last))
		last=rightX(w)
	endif
	if(ParamIsDefault(smooth_val))
		smooth_val=100
	endif
	if(ParamIsDefault(refractory))
		refractory=0.005
	endif
	Duplicate /o w d0
	Smooth smooth_val, d0 
	Differentiate d0 /D=d1  // Find the first derivative
	Smooth smooth_val, d1
	Differentiate d1 /D=d2 // Find the second derivative
	Smooth smooth_val,d2
	FindLevels /Q/R=(first,last) d2,0 // Find zero crossings in the second derivative
	Differentiate d2 /D=d3 // Find the third derivative
	Wave levels=W_FindLevels
	InsertPoints 0,1,levels; levels[0]=first
	InsertPoints numpnts(levels),1,levels; levels[numpnts(levels)-1]=last
	Variable i
	//String /G peak_locs="", peak_vals="", trough_locs="", trough_vals=""
	//KillWaves peaklocs,peakvals,troughlocs,troughvals
	Make /o/n=1 peaklocs, peakvals, troughlocs, troughvals
	Duplicate /o w d0_smooth
	Smooth 5,d0_smooth
	Variable peakiness=0
	Variable j=0,k=0
	for(i=0;i<numpnts(levels)-1;i+=1)
		WaveStats /Q/R=(levels[i],levels[i+1]) d0_smooth
		//if(abs(d1(levels[i]))>10)
		if(d3(levels[i])<=0 )//&& d2(V_minloc)<peakiness) // A peak is upcoming
			Redimension /n=(j+1) peaklocs, peakvals
			peaklocs[j]=V_maxloc
			peakvals[j]=V_max
			j+=1
		else // A trough is upcoming
			Redimension /n=(k+1) troughlocs, troughvals
			troughlocs[k]=V_minloc
			troughvals[k]=V_min
			k+=1
		endif
		//endif
	endfor
	//CleanAppend("PeakWave")
	KillWaves /Z raw,d0,d0_smooth,d1,d2,d3
End

Function WaveFromLocsAndVals(locs,vals,remove_insig)
	String locs,vals
	Variable remove_insig
	Variable i
	Variable loc,val
	KillWaves /Z LocWave,ValWave
	Make /o/n=(ItemsInList(locs)) LocWave,ValWave
	for(i=0;i<ItemsInList(vals);i+=1)
		loc=str2num(StringFromList(i,locs))
		val=str2num(StringFromList(i,vals))
		LocWave[i]=loc
		ValWave[i]=val
	endfor
	Sort LocWave,LocWave,ValWave
	if(remove_insig)
		Wave w=CsrWaveRef(A)
		RemoveInsignificantPeaks(w,LocWave,ValWave)
	endif
	SVar all_locs=all_locs; SVar all_vals=all_vals
	all_locs=NumWave2String(LocWave)
	all_vals=NumWave2String(ValWave)
	CleanAppend("ValWave",versus="LocWave")
End

Function ResampleEvenly(w,max_spacing)
	Wave w
	Variable max_spacing
	Wave alllocs=alllocs; Wave allvals=allvals
	Variable i,spacing,new_samples
	Variable j=numpnts(alllocs)
	InsertPoints 0,1,alllocs,allvals
	InsertPoints j+1,1,alllocs,allvals
	alllocs[0]=leftX(w); allvals[0]=w(leftX(w))
	alllocs[j+1]=rightX(w); allvals[j+1]=w(rightX(w))
	i=1
	Do
		spacing=alllocs[i]-alllocs[i-1]
		new_samples=ceil(spacing/max_spacing)
		for(j=0;j<new_samples;j+=1)
			InsertPoints i+j,1,alllocs,allvals
			alllocs[i+j]=(alllocs[i-1]+(j+1)*spacing/(new_samples+1))
			allvals[i+j]=w(alllocs[i+j])
		endfor
		i+=1+j
	While(i<numpnts(alllocs))
End

// Gets rid of extrema that are too similar to adjacent extrema (less than insig_val different from both adjacent extrema)
Function RemoveInsignificantPeaks(w,LocWave,ValWave[,insig_val])
	Wave w,LocWave,ValWave
	Variable insig_val
	if(ParamIsDefault(insig_val))
		insig_val=10
	endif
	Variable i=1,xi,x1,x2,yi,y1,y2,diff,diff1,diff2,removed,cumul=0
	Do
		diff1=max(abs(ValWave(i)-ValWave(i+1)),abs(ValWave(i)-ValWave(i-1)))
		xi=LocWave(i); x1=LocWave(i-1); x2=LocWave(i+1); yi=ValWave(i); y1=ValWave(i-1); y2=ValWave(i+1)
		diff2=abs(yi-(y1+(y2-y1)*(xi-x1)/(x2-x1)))
		if((diff1<insig_val))
			DeletePoints i,1,LocWave,ValWave
			if(abs(interp(xi,LocWave,ValWave)-w(xi))>insig_val/2)
				InsertPoints i,1,LocWave,ValWave
				LocWave[i]=xi
				ValWave[i]=w(LocWave[i])
				i+=1
			endif
		else
			i+=1
		endif
	While(i<numpnts(ValWave)-1)
End

Function AddSignificantPeaks(w,LocWave,ValWave[,insig_val])
	Wave w,LocWave,ValWave
	Variable insig_val
	
#if exists("Interpolate2")
	if(ParamIsDefault(insig_val))
		insig_val=10
	endif
	Variable i=1,length
	Do
		Duplicate /O /R=(LocWave(i-1),LocWave(i)) w xData
		Interpolate2 /i=3 /T=1 /Y=xData LocWave,ValWave
		xData-=w(x)
		WaveTransform /O abs xData
		WaveStats /Q xData
		length=rightx(xData)-leftx(xData)
		if(V_max>insig_val || V_avg>insig_val/3 || V_avg*length>insig_val/10)
			InsertPoints i,1,LocWave,ValWave
			LocWave[i]=V_maxloc
			ValWave[i]=w(LocWave[i])
		else
			i+=1
		endif
	While(i<numpnts(LocWave))
#else
	printf "Need Interpolate XOP.\r"
#endif
End

Function AddSignificantPeaks2(w,LocWave,ValWave[,insig_val])
	Wave w,LocWave,ValWave
	Variable insig_val
#if exists("Interpolate2")
	if(ParamIsDefault(insig_val))
		insig_val=10
	endif
	Variable i=1,length,last_max
	Do
		Duplicate /O /R=(LocWave(i-1),LocWave(i)) w xData
		Interpolate2 /i=3 /T=1 /Y=xData LocWave,ValWave
		xData-=w(x)
		WaveTransform /O abs xData
		WaveStats /Q xData
		last_max=V_max
		length=rightx(xData)-leftx(xData)
		//if(V_max>insig_val/2 || V_avg*length>insig_val/15)// || (V_avg>insig_val/5)// && length>0.05))
		InsertPoints i,1,LocWave,ValWave
		LocWave[i]=V_maxloc
		ValWave[i]=w(LocWave[i])
		Duplicate /O /R=(LocWave(i-1),LocWave(i+1)) w xData
		Interpolate2 /i=3 /T=1 /Y=xData LocWave,ValWave
		xData-=w(x)
		WaveTransform /O abs xData
		WaveStats /Q xData
		if(V_max<last_max-1 || V_max>insig_val/2)
		else
			DeletePoints i,1,LocWave,ValWave
			i+=1
		endif
	While(i<numpnts(LocWave))
#else
	printf "Need Interpolate XOP.\r"
#endif
End


// Removes redundancies (consecutive identical points in the first wave of the list, and the corresponding points in all other waves in the list
Function RemoveRedundancies(wave_list)
	String wave_list
	String wave_name
	Variable num_waves=ItemsInList(wave_list)
	Wave FirstWave=$StringFromList(0,wave_list)
	Variable last_point=FirstWave[0]
	Variable i=1,j
	Do
		if(FirstWave[i]==last_point)
			for(j=0;j<num_waves;j+=1)
				wave_name=StringFromList(j,wave_list)
				DeletePoints i,1,$wave_name
			endfor
		else
			last_point=FirstWave[i]
			i+=1
		endif
	While(i<numpnts(FirstWave))
End

// Resamples areas at a rate proportional to the the magnitude of the local first derivative, based on a smoothing of that derivative by a degree smooth_val
Function ResampleKeyRegions(w,resample_factor[,order,smooth_val])
	Wave w
	Variable resample_factor
	Variable order,smooth_val
	if(ParamIsDefault(order))
		order=1
	endif
	if(ParamIsDefault(smooth_val))
		smooth_val=1000
	endif
	Variable i
	for(i=0;i<order;i+=1)
		Differentiate w /D=d1
	endfor
	Smooth smooth_val,d1
	WaveTransform /o abs d1
	Integrate d1
	Duplicate /o d1 sinewave
	sinewave=sin(resample_factor*d1)
	FindLevels /Q sinewave,0
	Wave levels=W_FindLevels
	Wave alllocs=alllocs; Wave allvals=allvals
	Variable j=numpnts(alllocs)
	for(i=0;i<numpnts(W_FindLevels);i+=1)
		Redimension /n=(j+1) alllocs,allvals
		alllocs[j]=levels[i]
		allvals[j]=w(levels[i])
		j+=1
	endfor
	Sort alllocs,alllocs,allvals
	KillWaves d1
End

// Finds values in w (smoothed by smooth_val), where the absolute value of the nth derivative exceeds thresh
Function FindDerivThreshes(w,n,thresh,smooth_val)
	Wave w
	Variable n,thresh,smooth_val
	Duplicate /o w DerivThreshes // Make a copy of the wave for smoothing at the end
	Smooth smooth_val,DerivThreshes
	Variable i
	for(i=0;i<n;i+=1)
		Differentiate DerivThreshes
	endfor
	WaveTransform /o abs DerivThreshes
	DerivThreshes-=thresh
	WaveTransform /o sgn DerivThreshes
	CleanAppend("DerivThreshes")
End

// Deletes a list of points all at once from the wave with name wave_name
Function DeleteListOfPoints(wave_name,list) // List must be in sequence from lowest to highest
	String wave_name,list
	Variable i, n, toDelete
	n=0
	for(i=0;i<ItemsInList(list);i+=1)
		toDelete=str2num(StringFromList(i,list))
		DeletePoints toDelete-n,1,$wave_name
		n+=1
	endfor
End

// Find a local maximum in w near x_val; scan_size determines the coarseness of the scan; flip=1 finds a local minimum.
Function AscendGradient(w,x_val [scan_size,flip])
	Wave w
	Variable x_val,scan_size,flip
	if(ParamIsDefault(scan_size))
		scan_size=0.008                 // Default scan_size
	endif
	Duplicate /o w toAscend
	if(flip==1)
		toAscend*=-1
	endif
	Variable left_mean,right_mean,inc
	WaveStats /Q/R=(x_val-scan_size,x_val+scan_size) w
	x_val=V_maxloc
//	Do
//		Do // Look leftwards to see if there is a gradient to ascend
//			left_mean=mean(toAscend,x_val-scan_size,x_val)
//			if(left_mean>toAscend(x_val))
//				x_val-=scan_size/2
//			else
//				break
//			endif
//		While (1)
//		Do // Look rightwards to see if there is a gradient to ascend
//			right_mean=mean(toAscend,x_val,x_val+scan_size)
//			if(right_mean>toAscend(x_val))
//				x_val+=scan_size/2
//			else
//				break
//			endif
//		While (1)
//	scan_size/=2 // Now that there are no more gradients at the current resolution, cut the resolution in half and continue
//	While(scan_size>=0.001) // Stop when the resolution is less than 1 ms
	KillWaves toAscend
	return x_val
End

Function Strings2Waves(w)
	Wave /T w // A text wave, each entry of which is a string to be converted into a numeric wave
	Variable i
	String wave_name=NameOfWave(w)
	for(i=0;i<numpnts(w);i+=1)
		String2Wave(w[i],name=wave_name+"_"+num2str(i))
	endfor
End

Function First2Last(w)
	Wave w
	return w[numpnts(w)-1]-w[0]
End

// Removes any values from w that are between low and high, and deletes the corresponding points
Function RemoveWaveVals(w[,low,high])
	Wave w
	Variable low,high
	if(ParamIsDefault(low))
		low=-inf
	endif
	if(ParamIsDefault(high))
		high=-inf
	endif
	Variable i
	Do
		if(w[i]>low && w[i]<high)
			DeletePoints i,1,w
		else
			i+=1
		endif
	While(i<numpnts(w))
End

// Fills bad ranges with the point immediately to the left of each bad range
Function FillBadRangesWithLeft(w,bad_ranges)
	Wave w
	String bad_ranges
	String bad_range
	Variable i,left,right
	for(i=0;i<ItemsInList(bad_ranges);i+=1)
		bad_range=StringFromList(i,bad_ranges)
		left=str2num(StringFromList(0,bad_range,","))
		right=str2num(StringFromList(1,bad_range,","))
		left=x2pnt(w,left)
		right=x2pnt(w,right)
		w[left,right]=w[left-1];
	endfor
End

// Interpolates a new wave at sampling rate 'kHz' samples/ms
Function /S InterpFromPairs(Ywave,Xwave,output,[,kHz])
	Wave Ywave,Xwave
	String output
	Variable kHz
#if exists("Interpolate2")
	if(ParamIsDefault(kHz))
		kHz=10
	endif
	WaveStats /Q Xwave
	Variable seconds=V_max // Number of seconds represented
	KillWaves /Z $output
	Make /o/n=(1000*kHz*seconds) $output
	SetScale /P x,0,1/(1000*kHz),$output
	if(numpnts(Xwave)!=numpnts(Ywave)) // If waves are of different lengths
		Redimension /n=(numpnts(Xwave)) Ywave // Shorten or lengten Ywave to have the same number of points as Xwave
	endif
	Interpolate2 /I=3/T=1/Y=$output Xwave,Ywave // Linear interpolation
	return output
#else 
	printf "Need Interpolate XOP.\r"
#endif
End

// Pads the specified columns of a matrix (so that stimuli in all columns have the same onset time)
Function PadColumns(Matrix,first,last,amount)
	Wave Matrix
	Variable first,last,amount
	Variable i
	for(i=first;i<=last;i+=1)
		Duplicate /o/R=[][i,i] Matrix Column
		InsertPoints 0,amount,Column
		Matrix[][i]=Column[p]
	endfor
	KillWaves Column
End

Function Reconstruct(list[,graph,kHz])
	String list // List of the waves to reconstruct
	Variable graph // Set to 0 for no graph, 1 for a new graph, and 2 to append to the top graph
	Variable kHz
	if(ParamIsDefault(kHz))
		kHz=10
	endif
	if(ParamIsDefault(graph))
		graph=1
	endif
	if(graph==1)
		Display /K=1 
	endif
	Variable i; String item
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		Wave vals=$("root:sweeps:vals_"+item)
		Wave locs=$("root:sweeps:locs_"+item)
		Wave toAppend=$InterpFromPairs(vals,locs,"reconstruction_"+item,kHz=kHz)
		if(graph)
			AppendToGraph toAppend
		endif
	endfor
End

// Reconstructs a wave from a DWT of that wave with values below a certain cutoff already deleted.  
Function ReconstructFromDWT(list[,graph,kHz])
	String list // List of the waves to reconstruct
	Variable graph // Set to 0 for no graph, 1 for a new graph, and 2 to append to the top graph
	Variable kHz
	if(ParamIsDefault(kHz))
		kHz=10
	endif
	if(ParamIsDefault(graph))
		graph=1
	endif
	if(graph==1)
		Display /K=1 
	endif
	Variable i; String item
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		Wave vals=$("root:sweeps:vals_"+item)
		Wave locs=$("root:sweeps:locs_"+item)
		Wave toAppend=$InterpFromPairs(vals,locs,"reconstruction_"+item,kHz=kHz)
		if(graph)
			AppendToGraph toAppend
		endif
	endfor
End

Function ReconstructDWT(Locs,Vals,average,scale,points,reconstruction_name)
	Wave Locs,Vals
	Variable average,scale,points
	String reconstruction_name
	Make /o/n=(points) tempDWT=0
	Variable i
	for(i=0;i<numpnts(Locs);i+=1)
		tempDWT[Locs[i]]=Vals[i]
	endfor
	DWT /P=2 /I tempDWT,$reconstruction_name
	Wave Reconstruction=$reconstruction_name
	SetScale /P x,0,scale,Reconstruction
	Reconstruction+=average
	KillWaves /Z tempDWT
End

// Like FindListItem, but for text waves.  Returns the index of the first match
Function FindWaveItem(w,item)
	Wave /T w
	String item
	Variable i
	for(i=0;i<numpnts(w);i+=1)
		if(StringMatch(w[i],item))
			return i
		endif
	endfor
End

// Gets spike times (threshold crossing times) for a threshold of 'thresh' and a refractory period of 'refract'
// Returns in a wave called 'SpikeTimes'
Function FindSpikeTimes(w [,threshold,refractory,left,right])
	Wave w
	Variable threshold // The action potential must reach this level
	Variable refractory // Two action potentials cannot occur within this number of seconds
	Variable left,right // The left and right end of the area to search
	threshold=ParamIsDefault(threshold) ? -10 : threshold
	refractory=ParamIsDefault(refractory) ? 0.01 : refractory
	left=ParamIsDefault(left) ? leftx(w) : left
	right=ParamIsDefault(right) ? rightx(w) : right
	Make /o/n=0 SpikeTimes
	FindLevels /R=(left,right) /D=SpikeTimes /Q/M=(refractory) w, threshold
	Variable i=0,previous_point,next_point
	Do // Keeps only crossings up through threshold (spike onset times)
		//previous_point=floor(x2pnt(w,SpikeTimes[i]))
		//next_point=floor(x2pnt(w,SpikeTimes[i]))+1 // The next point after the crossing
		if(w[NextPoint(w,SpikeTimes[i])]<threshold) // If it is a crossing down through the threshold
			DeletePoints i,1,SpikeTimes // Get rid of it
		else
			i+=1 // Otherwise, keep it and move to the next crossing
		endif
	While(i<numpnts(SpikeTimes))
End

// Like x2pnt, but returns the previous point
Function PrevPoint(w,x)
	Wave w
	Variable x
	return floor((x - DimOffset(w,0))/DimDelta(w,0))
End

// Like x2pnt, but returns the next point
Function NextPoint(w,x)
	Wave w
	Variable x
	return floor((x - DimOffset(w,0))/DimDelta(w,0))+1
End

// Removes all NaNs from 'w', and the corresponding indices of a list of companion waves.  
Function DeleteNaNs(w[,companions])
	Wave w
	String companions
	Variable i=0,j,k
	if(ParamIsDefault(companions))
		Extract /O w,w,numtype(w)!=2
	endif
	Do
		if(IsNan(w[i]))
			k=0
			Do
				k+=1
			While(IsNan(w[i+k]) && i+k < numpnts(w))
			DeletePoints i,k,w
			if(!ParamIsDefault(companions))
				for(j=0;j<ItemsInList(companions);j+=1)
					Wave companion=$StringFromList(j,companions)
					DeletePoints i,k,companion
				endfor
			endif
		else
			i+=1
		endif
	While(i<numpnts(w))
End

// If a wave is sorted from lowest to highest (default), NaNs will come after the highest value.  This deletes those NaN points.
Function DeleteNaNsAfterSort(SortedWave)
	Wave SortedWave
	if(numpnts(SortedWave)>0)
		WaveStats /Q SortedWave
		DeletePoints V_maxloc+1,numpnts(SortedWave)-V_maxloc-1,SortedWave
	endif
End

Function Zeros2Nans(w)
	Wave w
	Variable i,j
	for(i=0;i<dimsize(w,0);i+=1)
		for(j=0;j<dimsize(w,1);j+=1)
			if(w[i][j]==0)
				w[i][j]=NaN
			endif
		endfor
	endfor
End

// Build a matrix from a list of waves.  Each column will contain a wave.  Values beyond the length of the shortest wave (or 'min_duration') will contain NaNs.  
// Uses x units throughout.  All waves must have the same x-scaling.  
Function Waves2Matrix(list[,down_sample,dest_name,min_duration,max_duration,wrap])
	String list
	Variable down_sample // Downsample each wave by this factor (for computational speed)
	String dest_name // The name of the destination matrix
	Variable min_duration // The minimum duration of the rows (in x units).  Waves with less than this duration will be padded with NaNs.
	Variable max_duration // The maximum duration of the row (in x units).  Waves greater than this duration will be treated according to the value of 'wrap'.  
	Variable wrap // If waves exceed max_duration, they will be cutoff at the end if wrap=0, and wrapped to the next line (row) if wrap=1.  
	
	down_sample=ParamIsDefault(down_sample) ? 1 : down_sample
	if(ParamIsDefault(dest_name))
		dest_name="Matrix"
	endif
	max_duration=ParamIsDefault(max_duration) ? Inf : max_duration
	wrap=ParamIsDefault(wrap) ? 0 : wrap
	
	Wave ExampleWave=$StringFromList(0,list)
	Variable offset=dimoffset(ExampleWave,0)
	Variable delta=dimdelta(ExampleWave,0)
	Variable num_waves=ItemsInList(list)
	Variable i,duration=0; String wave_name
	for(i=0;i<num_waves;i+=1)
		wave_name=StringFromList(i,list)
		Wave w=$wave_name
		duration=max(duration,numpnts(w)*delta)
	endfor
	duration=max(duration,min_duration)
	duration=min(duration,max_duration)
	Make /o/n=(round(duration/delta),num_waves) $dest_name=NaN // Each column will be a wave from the list
	Wave Matrix=$dest_name
	for(i=0;i<num_waves;i+=1)
		wave_name=StringFromList(i,list)
		Wave w=$wave_name
		InsertDownsampled(Matrix,w,i,down_sample)
		if((numpnts(w)*delta > duration) && wrap) // If the wave is longer than the maximally allowed duration, and 'wrap' is on.  
			InsertPoints /M=1 i+1,1,Matrix
			InsertDownsampled(Matrix,w,i,down_sample,start=round(duration/delta))
		endif
	endfor
	SetScale /P x,offset,delta*down_sample,Matrix
End

Function InsertDownsampled(Matrix,w,column,down_sample[,start])
	Wave Matrix, w
	Variable column,down_sample,start // Start is the point at which to start in 'w'.  
	if(down_sample==1)
		Matrix[][column]=w[p+start]
	else
		Duplicate /o w tempWaveScaleless
		SetScale /P x,0,1,tempWaveScaleless
		Matrix[][column]=mean(tempWaveScaleless,start+p*down_sample,start+(p+1)*down_sample)
	endif
	Matrix[numpnts(w)/down_sample,][column]=NaN
	KillWaves /Z tempWaveScaleless
End

// Uses high-pass filtering to isolate spikes and then returns spike times
Function FindSpikeTimes2(w[,freq_cutoff,threshold])
	Wave w
	Variable freq_cutoff,threshold
	freq_cutoff=ParamIsDefault(freq_cutoff) ? 20 : freq_cutoff
	threshold=ParamIsDefault(threshold) ? 10 : threshold
	Duplicate /o w $(NameOfWave(w)+"_HPF")
	Wave HPF=$(NameOfWave(w)+"_HPF")
	FindLevels /Q HPF, 10
	Wave Levels=W_FindLevels
	if(mod(numpnts(Levels),2)!=0)
		printf "Odd number of level crossings found in filtered version of %s!  Should be even for spikes (2 per spike).\r",NameOfWave(w)  
	endif
	Make /o/n=(numpnts(Levels)/2) SpikeTimes=NaN
	Variable i
	for(i=0;i<numpnts(Levels);i+=2)
		SpikeTimes[i/2]=Levels[i]
	endfor
	KillWaves HPF
End

Function GetOneTau(sweep,testPulsestart)
	Wave sweep
	Variable testPulsestart
	Variable V_fitOptions=4
	Variable V_FitError=0
	Variable testPulselength=0.1 // Hardcoded for now since the channel number is not passed in so I can't determine the exact test pulse length.  
	Duplicate/o/R=(testPulsestart,testPulsestart+testPulselength) sweep waveToFitA
	Duplicate/o/R=(testPulsestart+testPulselength,testPulsestart+2*testPulselength) sweep waveToFitB
	//Duplicate/o waveToFit waveToFitA
	//Duplicate/o waveToFit waveToFitB
	//DeletePoints 0,x2pnt(WaveToFitA,pulseStart),waveToFitA
	//DeletePoints 0,x2pnt(WaveToFitB,pulseStart+testPulselength),waveToFitB
	waveToFitA=(waveToFitA-waveToFitB)/2 //Averages the two impulse responses together
	CurveFit /Q/N/W=0 exp, waveToFitA (testPulsestart+0.0005,testPulsestart+testPulselength/2)
	return 1/K2
End

Function NormalizeToUnity(w)
	Wave w
	Variable factor
	Integrate /p w /D=integrated
	factor=integrated[numpnts(integrated)-1]
	w/=factor
End

Function TotalCharge(sweep,pulses,pre,post) // Which channel, over how many pulses, is there staggering?
	Wave sweep
	Variable pulses
	String pre
	String post
	Variable charge
	Variable baseline
	Variable starttime
	NVar offset=root:stagger_offset
	starttime=0.298+(str2num(pre[1])-1)*offset
	Integrate sweep /D=integrated
	charge= integrated(starttime+0.050*(pulses^2))-integrated(starttime) // pulses^2 since this is the difference between a 50 ms window and a 200 ms window
	baseline = (pulses^2)*(integrated(starttime)-integrated(starttime-0.050))
	return baseline - charge // order reversed to get a positive value for the total charge
End

Function GetCharge()
	Variable baseline=vcsr(A)*(xcsr(B)-xcsr(A))
	Variable average=area(CsrWaveRef(A),xcsr(A),xcsr(B))
	return baseline-average
End

// Convert a text wave into a numeric wave, assuming the text wave contains numbers.  
Function TextWave2NumWave(textWave)
	Wave /T textWave
	String temp_name=UniqueName("tempWave",1,1)
	String wave_folder=GetWavesDataFolder(textWave,1)
	String wave_name=NameOfWave(textWave)
	Make /o/n=(numpnts(textWave)) $(wave_folder+temp_name)
	Wave tempWave=$(wave_folder+temp_name)
	Variable i
	for(i=0;i<numpnts(tempWave);i+=1)
		tempWave[i]=str2num(textWave[i])
	endfor
	KillWaves textWave
	Rename tempWave $wave_name
End

// Average a series of equally spaced chunk of a wave.  
Function AverageTrain(w,start,interval,num_stims)
	Wave w
	Variable start,interval,num_stims
	Duplicate /o /R=(start,start+interval) w AverageTrainWave
	AverageTrainWave=0
	Variable i
	for(i=0;i<num_stims;i+=1)
		AverageTrainWave+=w(start+interval*i+x)
	endfor
	AverageTrainWave/=num_stims
End

// Set the region between the cursors in the Amplitude Analysis window to zero.  
Function ZeroAmplRegion()
	SVar allChannels=root:parameters:allChannels
	Variable i,j
	String pre,post
	for(i=0;i<ItemsInList(allChannels);i+=1)
		post=StringFromList(i,allChannels)
		for(j=0;j<ItemsInList(allChannels);j+=1)
			pre=StringFromList(j,allChannels)
			Wave ampl=$("root:cell"+post+":ampl_"+pre+"_"+post)
			Wave ampl2=$("root:cell"+post+":ampl2_"+pre+"_"+post)
			ampl[xcsr(A),xcsr(B)]=0
			ampl2[xcsr(A),xcsr(B)]=0
		endfor
	endfor
End

// Suppresses region between the cursors to be a smooth line connecting the values at the cursors
Function Suppress()
	Wave w=CsrWaveRef(A)
	Variable x1=pcsr(A),x2=pcsr(B),y1=vcsr(A),y2=vcsr(B)
	Variable dx=x2-x1, dy=y2-y1
	w[x1,x1+dx]=y1+(p-x1)*dy/dx
End

// Suppresses region between the cursors towards the imaginary line connecting the cursors.  
// Additive, not multiplicative.  
Function Suppress2(degree)
	Variable degree // How fine should the suppress be (Higher degree maintains more of the noise).   
	Wave w=CsrWaveRef(A)
	Variable x1=xcsr(A),x2=xcsr(B),y1=vcsr(A),y2=vcsr(B)
	Variable dx=x2-x1, dy=y2-y1
	Duplicate /FREE /R=(xcsr(A),xcsr(B)) w Segment,SmoothSegment
	Smooth /B=1 /E=3 degree,SmoothSegment
	//Display /K=1 Segment,SmoothSegment; return 0
	Segment-=SmoothSegment // Just the noise
	w=(x>x1 && x<x2) ? y1+(x-x1)*dy/dx+Segment(x) : w
End

Function ConcatWC()
	root()
	SetDataFolder :wholecell
	String wave_list=WaveList("sweep*",";","")
	wave_list=SortList(wave_list,";",16)
	if(strlen(wave_list))
		Concatenate /O/NP wave_list,ConcatSweep
	else
		Make /o ConcatSweep
	endif
	//Display /K=1 ConcatSweep
End

// Cut out a region between the cursors.  
Function Cut()
	DeletePoints pcsr(A), pcsr(B)-pcsr(A)+1, CsrWaveRef(A)
End

// Cut out a region between the cursors.  
Function Restrict()
	Wave Wav=CsrWaveRef(A)
	DeletePoints pcsr(B)+1,numpnts(Wav)-pcsr(B),Wav
	DeletePoints 0,pcsr(A),Wav
End

Function Rid(threshold,cellString) // Don't include points where the EPSC is a failure, or below the noise.  
	Variable threshold
	String cellString
	Wave ampl = $("root:cell"+cellString+":ampl")
	Wave ampl2 = $("root:cell"+cellString+":ampl2")
	NVar total_sweeps = root:sweep_number1
	Variable n=total_sweeps
	for(n=total_sweeps;n>=1;n-=1)
		if(ampl[n]<threshold)
			ampl[n]=NaN
		endif
	endfor	
End
