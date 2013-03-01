// $URL: svn://churro.cnbc.cmu.edu/igorcode/IgorExchange/DragAndDropTraces.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

Menu "Graph"
	DragAndDropMenuName(),/Q,DragAndDropToggle() 
End

Function /s DragAndDropMenuName()
	dfref df=root:Packages:DragAndDropTraces
 	if(!datafolderrefstatus(df))
 		return "Activate Drag-and-Drop Traces"
 	else
 		return "Deactivate Drag-and-Drop Traces"
 	endif
End

Function DragAndDropToggle()
	variable i
	string wins=winlist("*",";","WIN:1")
	dfref df=root:Packages:DragAndDropTraces
 	
 	if(!datafolderrefstatus(df))
 		newdatafolder /o root:Packages
		newdatafolder /o root:Packages:DragAndDropTraces
		dfref df=root:Packages:DragAndDropTraces
		string /g df:source,df:dest,df:trace
		variable /g df:lsize	
		for(i=0;i<itemsinlist(wins);i+=1)
			string win=stringfromlist(i,wins)
			setwindow $win hook(DragAndDrop)=DragAndDropHook
		endfor
	else
		killdatafolder df
 		for(i=0;i<itemsinlist(wins);i+=1)
			win=stringfromlist(i,wins)
			setwindow $win hook(DragAndDrop)=$""
		endfor
 	endif
End

Function DragAndDropHook(info)
	struct WMWinHookStruct &info
	
 	dfref df=root:Packages:DragAndDropTraces
 	if(!datafolderrefstatus(df))
		return -1
	endif
	
	string trace_info1=TraceFromPixel(info.mouseLoc.h,info.mouseLoc.v,"")
	getwindow $info.winName psizeDC
	variable mouseH=info.mouseLoc.h, mouseV=info.mouseLoc.v // Convert to variables.  
	if(mouseH>v_right || mouseH<v_left || mouseV<v_top || mouseV>v_bottom)
		nvar /sdfr=df lsize
		svar /sdfr=df trace
		if(strlen(trace) && lsize)
			modifygraph /z lsize($trace)=lsize
		endif
	endif
	switch(info.eventCode)
		case 3: // Mouse down.  
			if(strlen(trace_info1))
				info.cursorCode=1
				info.doSetCursor=1
				string /g df:trace=stringbykey("TRACE",trace_info1), df:source=info.winName
				svar /sdfr=df trace
				string trace_info2=traceinfo(info.winName,trace,0)
				variable /g df:lsize=numberbykey("lsize(x)",trace_info2,"=")
				nvar /sdfr=df lsize
				if(numtype(lsize))
					return -2
				endif
				modifygraph lsize($trace)=min(10,lsize*3)
			endif
			break
		case 5: // Mouse up.  
			nvar /sdfr=df lsize
			svar /sdfr=df trace,source
			if(strlen(trace) && strlen(source) && lsize)
				modifygraph /z/w=$source lsize($trace)=lsize
			endif
			if(!stringmatch(source,info.winName)) // Dragged from another window.  
				wave w=tracenametowaveref(source,trace)
				removefromgraph /z/w=$source $trace
				appendtograph /w=$info.winName w
			endif
			trace=""
			break
	endswitch
End