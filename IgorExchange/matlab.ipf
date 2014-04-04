#pragma rtGlobals=1		// Use modern global access method.
#pragma modulename=matlab

// Dimension number.  

// e.g. any({0,3,0,0}) returns 1.  
static function /wave any(w[,dim])
	wave w
	variable dim // dimension number.  
	
	if(paramisdefault(dim))
		matrixop /free w1=sum(equal(w,0)-1)
	elseif(dim==0)
		matrixop /free w1=sumcols(equal(w,0)-1)
	elseif(dim==1)
		matrixop /free w1=sumcols(equal(w^t,0)-1)^t
	endif
	return w1
end

// creates new free axes.  Appended traces come with their own axes, so these are for embellishment.  
static function axes(name)
	string name
	newfreeaxis /L $(name+"X")
	newfreeaxis /B $(name+"Y")
end

// e.g axis({0,10,1,100}) sets the x-axis from 0 to 10 and the y-axis from 0 to 100.  
static function axis(w)
	wave w // axis limits
	setaxis bottom w[0],w[1]
	setaxis lrft w[2],w[3]
end

// kills a free axis.  Note that axis associated with traces cannot be killed without removing the trace (see RemoveFromGraph).  
static function cla(name)
	string name
	killfreeaxis $name
end

// return a string containing the type of data structure which whose name was passed as a string.  Note that these types (e.g. WAV) are simply my own abbreviations, and never actually used by Igor.  
static function /s class(name)
	string name
	
	Variable exist=exists(name)
	if(exist==1)
		Wave /Z myWave=$name
		if(WaveExists(myWave))
			if(WaveType(myWave))
				return "WAV" // Numeric wave.  
			else
				return "WAVT" // Text wave.  
			endif
		endif
	elseif(exist==2)
		NVar /Z myVar=$name
		if(NVar_Exists(myVar))
			return "VAR" // Numeric variable.  
		endif
		SVar /Z myStr=$name
		if(SVar_Exists(myStr))
			return "STR" // String variable.  
		endif
	else
		if(datafolderexists(name))
			return "FLDR"
		endif
	endif
	return ""
end

// deletes a piece of data (variable, string, wave, or folder) from memory.  Note that it will not be deleted if it is currently in use (displayed on a graph or in a table).  
static function clear(name)
	string name
	string type=class(name)
	strswitch(type)
		case "WAV":
		case "WAVT":
			killwaves /z $name
			break
		case "VAR":
			killvariables /z $name
			break
		case "STR":
			killstrings /z $name
			break
		case "FLDR":
			killdatafolder /z $name
			break
	endswitch
end

// Removes all the traces from the top-most graph.  
static function clf()
	variable i
	string traces=tracenamelist("",";",3)
	traces=sortlist(traces,";",17)
	for(i=0;i<itemsinlist(traces);i+=1)
		string trace=stringfromlist(i,traces)
		removefromgraph $trace
	endfor
end

// Deletes a file from disk.  A full path to the file is expected.  Note that Igor works best with colons as path separators, e.g. "C:Documents and Settings:Bob:Desktop:test.txt"
static function delete(name)
	string name
	DeleteFile name
end

// Computes the first difference.  Note that backward and central differences can be computed by changing the /meth flag.  
static function /wave diff(w)
	wave w
	duplicate /free w,w1
	differentiate /meth=1 w1
	return w1
end

// Prints the values of a wave in a nice format.  
static function disp(w)
	wave w
	print /f w
end

// Computes a dot product.  
static function /wave dot(w1,w2[,dim])
	wave w1,w2
	variable dim
	if(paramisdefault(dim))
		matrixop /free w3=w1 . w2
	elseif(dim==1)
		matrixop /free w3=sumcols(w1 * w2)
	elseif(dim==2)
		matrixop /free w3=sumcols(w1^t * w2^t)^t
	endif
	return w3
end

// Updates all graphs.  Note that this happens automatically unless a function is currently executing.  
static function drawnow()
	doupdate
end

// Creates an identity matrix, e.g. eye({3,3}) returns a 3 x 3 identity matrix.  
static function /wave eye(w)
	wave w
	if(numpnts(w)==1)
		matrixop /free w=identity(w[0])
	elseif(numpnts(w)==2)
		matrixop /free w=identity(w[0],w[1])
	endif
	return w
end

// Creates a 0 matrix, e.g. false({3,2}) return a 3 x 2 matrix of zeroes.  0 and FALSE are identical in Igor.  
static function /wave false(w)
	wave w
	switch(numpnts(w))
		case 1:
			make /free/n=(w[0]) w1=0
			break
		case 2:
			make /free/n=(w[0],w[1]) w1=0
			break
		case 3:
			make /free/n=(w[0],w[1],w[2]) w1=0
			break
		case 4:
			make /free/n=(w[0],w[1],w[2],w[3]) w1=0
			break
	endswitch
	return w1
end

// Makes a new, blank graph window.  
static function figure()
	display
end

// Returns the indices of all non-zero values in a wave, e.g. find({0,0,3,0,2,5,0}) returns {2,4,5}.  
static function /wave find(w)
	wave w
	extract /free/indx w,w1,w!=0
	return w1
end

// Rounds towards zero.  
static function /wave fix(w)
	wave w
	duplicate /free w,w1
	w1=floor(abs(w))*sign(w)
	return w1
end

// fprintf: see 'fprintf' operation.  

// fopen: Opens/creates a file for reading/writing.  Based on 'Open' operation.  
static function fopen(filename,permission)
	string filename
	string permission
	
	variable fileID
	strswitch(permission)
		case "w":
			Open fileID as fileName
			break
		case "a":
			Open /A fileID as fileName
			break
		default:
			Open /R fileID as fileName
	endswitch
	return fileID
end

// fseek: Sets a file pointer to a particular location in a file.  
static function fseek(fileID,offset,origin)
	variable fileID,offset
	string origin
	
	fstatus fileID
	strswitch(origin)
		case "cof":
			fsetpos fileID,v_filepos+offset
			break
		case "eof":
			fsetpos fileID,offset
			break
		default: // "bof"
			fsetpos fileID,v_logeof+offset
			break
	endswitch
end

// fclose: Closes an open file.  
static function fclose(fileID)
	variable fileID
	
	if(fileID>=0)
		Close fileID
	else
		Close /A
	endif
end

// gca: Return the names of the top 2 axes in the top-most graph.  No direct equivalent.  
static function /s gca()
	string axes=axislist("")
	string firstAxis=stringfromlist(0,axes)
	string secondAxis=stringfromlist(1,axes)
	return firstAxis+";"+secondAxis
end

// gcf: Returns the name of the topmost graph.  
static function /s gcf()
	return winname(0,1)
end

// get: No direct equivalent; but see 'AxisList', 'TraceNameList', and 'GetWindow'.  

// grid: Adds a grid to the top-most graph.  
static function grid()
	modifygraph grid=1
end

// help: Display the Igor help file for a particular Igor topic or function.  
static function help(str)
	string str
	
	displayhelptopic str
end

// help2: Displays the MATLAB help (on the web) for a particular MATLAB function.  
static function help2(str)
	string str
	
	BrowseURL /Z "http://www.mathworks.com/access/helpdesk/help/techdoc/ref/"+str+".html"
end

// hist: Returns a histogram of the data, with bin centers specified.  
static function /wave hist(data,binCenters)
	wave data,binCenters
	
	make /o/n=(numpnts(binCenters)) $(getwavesdatafolder(data,2)+"_hist") /wave=myHist=0
	variable spacing=binCenters[1]-binCenters[0]
	histogram /b={binCenters[0]-spacing/2,spacing,numpnts(binCenters)} data,myHist
	return myHist
end 

// histc: Returns a histogram of the data, with bin left edges specified.  
static function /wave histc(data,binEdges)
	wave data,binEdges
	
	make /o/n=(numpnts(binEdges)) $(getwavesdatafolder(data,2)+"_hist") /wave=myHist=0
	variable spacing=binEdges[1]-binEdges[0]
	histogram /b={binEdges[0],spacing,numpnts(binEdges)} data,myHist
	return myHist
end 

// hold: No direct equivalent; all graph properties and traces are retained by default.  See 'RemoveFromGraph' to remove traces.  

// isempty: Returns the truth about whether a wave contains any points.  For testing string length, see 'strlen'.  
static function isempty(w)
	wave w
	
	return numpnts(w)==0
end

// load: Loads Igor data from disk.  
static function load(fileName)
	string fileName
	
	LoadData fileName
end

// log10: Computes the log base 10.  For log base 'e', see 'ln'.  
static function /wave log10(w)
	wave w
	
	duplicate /free w,w_
	w_ = log(w)
	return w_
end 

// loglog: Creates a log-log plot of the data.  To apply to an existing graph, use only 'ModifyGraph'.  
static function loglog(xData,yData)
	wave xData,yData
	
	display yData vs xData
	modifygraph log=1
end 

// max_: Returns the maximum value of a wave.  Also see 'WaveStats'.   To get the maximum of two numbers, use 'max'.  
static function max_(w)
	wave w
	
	return wavemax(w)
end

// mean_: Returns the mean value of a wave.  Also see 'mean', which does not ignore NaNs.     
static function mean_(w)
	wave w
	
	wavestats /m=1 w
	return v_avg
end

#if igorversion() < 7
// median: Returns the median value of a wave.    
static function median(w)
	wave w
	
	return statsmedian(w)
end 
#endif

// min_: Returns the minimum value of a wave.  Also see 'WaveStats'.   To get the minimum of two numbers, use 'min'.  
static function min_(w)
	wave w
	
	return wavemin(w)
end

// mod: see 'mod' function.  

// ones: Returns a matrix ones, e.g. ones({4,2,3}) returns a 4 x 2 x 3 matrix of ones.    
static function /wave ones(w)
	wave w
	
	wave w
	switch(numpnts(w))
		case 1:
			make /free/n=(w[0]) w1=1
			break
		case 2:
			make /free/n=(w[0],w[1]) w1=1
			break
		case 3:
			make /free/n=(w[0],w[1],w[2]) w1=1
			break
		case 4:
			make /free/n=(w[0],w[1],w[2],w[3]) w1=1
			break
	endswitch
	return w1
end 

// pause: Pauses execution for the specified number of seconds.  To pause indefinitely until the mouse is clicked, use pause(0).   
static function pause(n)
	variable n
	
	if(n>0)
		sleep /s n
	else
		sleep /b/s 999999
	endif
end 

// pi: see 'pi'. 
 
// plot: Plots one wave vs another.  To plot only one wave, use 'Display wavename'.  For a blank graph, use only 'Display'.  Use the /k=1 flag to avoid pesky graph saving warnings.  
static function plot(xWave,yWave)
	wave xWave,yWave
	
	display yWave vs xWave 
end 

// rand: Returns a matrix of uniformly random values between 0 and 1.    
static function /wave rand(w)
	wave w
	
	switch(numpnts(w))
		case 1:
			make /free/n=(w[0]) w1
			break
		case 2:
			make /free/n=(w[0],w[1]) w1
			break
		case 3:
			make /free/n=(w[0],w[1],w[2]) w1
			break
		case 4:
			make /free/n=(w[0],w[1],w[2],w[3]) w1
			break
	endswitch
	w1=abs(enoise(1))
	return w1 
end 

// rand: Returns a matrix of gaussian random values with zero mean and unit variance.    
static function /wave randn(w)
	wave w
	
	switch(numpnts(w))
		case 1:
			make /free/n=(w[0]) w1
			break
		case 2:
			make /free/n=(w[0],w[1]) w1
			break
		case 3:
			make /free/n=(w[0],w[1],w[2]) w1
			break
		case 4:
			make /free/n=(w[0],w[1],w[2],w[3]) w1
			break
	endswitch
	w1=gnoise(1)
	return w1 
end 

// rectangle: based on 'DrawRect' operation.  
static function rectangle(propertyName,propertyValue)
	string propertyName
	wave propertyValue
	
	strswitch(propertyName)
		case "Position":
			DrawRect propertyValue[0],propertyValue[1],propertyValue[0]+propertyValue[2],propertyValue[1]+propertyValue[3]
			break
	endswitch
end 

// rem: based on 'floor' function.  
static function rem(num,denom)
	variable num,denom
	
	variable fix=floor(abs(num/denom))*sign(num/denom)
	return num - fix*denom
end 

// repmat: based on the 'MatrixOp' operation.  
static function /wave repmat(w,m,n)
	wave w
	variable m,n
	
	matrixop /free w1=rowrepeat(colrepeat(w,n),m)
	return w1
end 

// reshape: based on the 'Redimension' operation.  
static function /wave reshape(w,m,n)
	wave w
	variable m,n
	
	Redimension /n=(m,n) w
	return w 
end 

// round: see 'round' function.  

// save: see 'SaveExperiment'.  To save only certain waves, see 'Save'.  

// semilogx: based on 'Display' and 'ModifyGraph' operations.  To apply to an existing graph, use only 'ModifyGraph'.  
static function semilogx(xData,yData)
	wave xData,yData
	
	display yData vs xData
	modifygraph log(bottom)=1
end 

// semilogy: based on 'Display' and 'ModifyGraph' operations.  To apply to an existing graph, use only 'ModifyGraph'.  
static function semilogy(xData,yData)
	wave xData,yData
	
	display yData vs xData
	modifygraph log(left)=1
end 

// set: no equivalent.  See 'SetAxis', 'ModifyGraph', 'SetWindow', 'MoveWindow'.  

// sign: see 'sign' function.  

// sin: see 'sin' function.  

// size: based on 'dimsize' function.   Note that in Igor the first dimension is dimension 0.  
static function size(w,dim)
	wave w
	variable dim
	
	return dimsize(w,dim-1) 
end 

// sort_ (sort): based on 'Sort' operation.  
static function /wave sort_(w[,mode])
	wave w
	string mode
	
	mode=selectstring(paramisdefault(mode),mode,"ascending")
	strswitch(mode)
		case "descending":
			sort /r w,w
			break
		default:
			sort w,w
			break
	endswitch
	return w	
end 

// sprintf: see 'sprintf' function.  

// std: based on 'WaveStats' operation.  
static function std(w)
	wave w
	
	wavestats /q w
	return v_sdev 
end 

// strcmp: based on 'cmpstr' function.  
static function strcmp(str1,str2)
	string str1,str2
	
	return cmpstr(str1,str2) 
end 

// subplot: no equivalent.  I will implement this later.  
static function subplot()
end

// svd: based on 'MatrixSVD' operation.  
static function svd(w)
	wave w
	
	MatrixSVD /U=1/V=1 w // Creates M_U, W_W, M_VT, analogous to [U,S,V'].  The /U and /V flags specifiy the "economy size" decomposition.  
end

// tan: see 'tan' function.  

// tic: based on 'StartMsTimer' operation.  
static function tic()
	variable /g root:timerRef=StartMsTimer
end 

// title: based on 'TextBox' operation.  
static function title(str)
	string str
	
	TextBox /A=MT str
end 

// toc: based on 'StopMsTimer' and 'Print' operations.  
static function toc()
	nvar /z timerRef=root:timerRef
	if(nvar_exists(timerRef))
		variable elapsed=StopMsTimer(timerRef)
		print elapsed
		killvariables /z timerRef
		return elapsed
	endif
end 

// true: based on 'Make' operation.  
static function /wave true(w)
	wave w
	switch(numpnts(w))
		case 1:
			make /free/n=(w[0]) w1=1
			break
		case 2:
			make /free/n=(w[0],w[1]) w1=1
			break
		case 3:
			make /free/n=(w[0],w[1],w[2]) w1=1
			break
		case 4:
			make /free/n=(w[0],w[1],w[2],w[3]) w1=1
			break
	endswitch
	return w1
end

// uicontrol: based on a number of operations for creating user controls.  
static function /s uicontrol([style,string_,position,callback])
	string style,string_,callback
	wave position
	
	variable left=position[0], top=position[1], width=position[2]-position[0], height=position[3]-position[1]
	string name=UniqueName(style,15,0)
	strswitch(style)
		case "checkbox":
			checkbox $name pos={left,top}, size={width,height}, title=string_, mode=0, proc=$callback
			break
		case "edit":
			setvariable $name pos={left,top}, size={width,height}, title=string_, proc=$callback
			break
		case "frame":
			groupbox $name pos={left,top}, size={width,height}, title=string_, proc=$callback
		case "listbox":
			listbox $name pos={left,top}, size={width,height}, title=string_, proc=$callback
		case "popupmenu":
			popupmenu $name pos={left,top}, size={width,height}, title=string_, proc=$callback
		case "pushbutton":
			button $name pos={left,top}, size={width,height}, title=string_, proc=$callback
			break
		case "radiobutton":
			checkbox $name pos={left,top}, size={width,height}, title=string_, mode=1, proc=$callback
			break
		case "slider":
			slider $name pos={left,top}, size={width,height}, title=string_, proc=$callback
			break
		case "text":
			titlebox $name pos={left,top}, size={width,height}, title=string_, proc=$callback
			break
		case "togglebutton":
			checkbox $name pos={left,top}, size={width,height}, title=string_, mode=2, proc=$callback // This is not exactly a toggle button.  
			break
		default:
			return ""
	endswitch
	return name
end

// uipanel: based on 'NewPanel' operation.  
static function uipanel([position])
	wave position
	
	if(paramisdefault(position))
		newpanel
	else
		newpanel /w=(position[0],position[1],position[2],position[3])
	endif
end

// xlabel: based on "Label" operation.  
static function xlabel(str)
	string str
	
	label bottom str 
end 

// ylabel: based on "Label" operation.  
static function ylabel(str)
	string str
	
	label left str  
end 

// zeroes: based on 'make' operation.  
static function /wave zeroes(m,n)
	variable m,n
	
	make /free/n=(m,n) w=0
	return w 
end 

//----------------- Auxiliary functions to support the above MATLAB functions ------------------------

// extract column 'n' from wave 'w'.  
static function /wave col(w,n)
	wave w
	variable n
	
	matrixop /free col_=col(w,n)
	return col_
end

// extract row 'n' from wave 'w'.  
static function /wave row(w,n)
	wave w
	variable n
	
	matrixop /free row_=row(w,n)
	return row_
end