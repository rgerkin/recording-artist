#pragma rtGlobals=1		// Use modern global access method.

Function UpstateLocationsZ()
	root()
	String win=WinName(0,1)
	Variable i
	if(!CursorExists("A") || !CursorExists("B"))
		DoAlert 0,"Put cursors on the graph to mark the region of interest first"
		return 0
	endif
	Variable x1=xcsr(A)
	Variable x2=xcsr(B)
	String traces=TraceNameList(win,";",3),trace
	String /G target_dir="root:PairedUpstates"
	NewDataFolder /O $target_dir
	// Get the upstate locations for each wave.  
	print "\r"
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		Wave theWave=TraceNameToWaveRef(win,trace)
		Cursor /W=$win A,$trace,x1
		Cursor /W=$win B,$trace,x2
		print trace+":"
		UpstateLocations()
		Sort UpstateOn,UpstateOn,UpstateOff
		Duplicate /o UpstateOn $(target_dir+":"+CleanupName("UpstateOn_"+trace,1))
		Duplicate /o UpstateOff $(target_dir+":"+CleanupName("UpstateOff_"+trace,1))
		KillWaves /Z UpstateOn,UpstateOff
		print "\r"
	endfor
	
	// Cleanup.  
	root()
	KillDataFolder /Z root:MeanStDevPlot_F
	KillWaves /Z ZMeans,ZStDevs,MahalDistances
	
	NewPanel /K=1 /N=UpstateManager /W=(0,0,350,100)
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		TraceColor(trace,win=win); NVar red,green,blue
		Wave UpstateOn=$(target_dir+":"+CleanupName("UpstateOn_"+trace,1))
		Wave UpstateOff=$(target_dir+":"+CleanupName("UpstateOff_"+trace,1))
		Variable /G $(target_dir+":upstate_number_"+trace)
		Variable num_upstates=numpnts(UpstateOn)
		SetVariable $("UpstateNumber_"+trace),limits={0,num_upstates-1,1}, size={100,20}, value=$(target_dir+":upstate_number_"+trace),proc=MoveUpstate,title=trace
		Button $("Add_"+trace), proc=AddUpstate,size={100,20},title="Add Upstate"
		Button $("Remove_"+trace), proc=RemoveUpstate,size={100,20},title="Remove Upstate"
		SetWindow UpstateManager userData+=trace+";"
	endfor
	KillVariables /Z red,green,blue
End

Function MoveUpstate(ctrlName,varNum,varStr,varName)
	String ctrlName
	Variable varNum	
	String varStr,varName	
	String trace=StringFromList(1,ctrlName,"_")
	SVar target_dir=root:target_dir
	Wave UpstateOn=$(target_dir+":"+CleanupName("UpstateOn_"+trace,1))
	Wave UpstateOff=$(target_dir+":"+CleanupName("UpstateOff_"+trace,1))
	Cursor A,$trace,UpstateOn(varNum)
	Cursor B,$trace,UpstateOff(varNum)
End

Function AddUpstate(ctrlName)
	String ctrlName
	String trace=StringFromList(1,ctrlName,"_")
	SVar target_dir=root:target_dir
	Wave UpstateOn=$(target_dir+":"+CleanupName("UpstateOn_"+trace,1))
	Wave UpstateOff=$(target_dir+":"+CleanupName("UpstateOff_"+trace,1))
	InsertPoints 0,1,UpstateOn,UpstateOff
	UpstateOn[0]=xcsr(A)
	UpstateOff[0]=xcsr(B)
	Sort UpstateOn,UpstateOn,UpstateOff
	Variable num_upstates=numpnts(UpstateOn)
	SetVariable $("UpstateNumber_"+trace),limits={0,num_upstates-1,1}
End

Function RemoveUpstate(ctrlName)
	String ctrlName
	String trace=StringFromList(1,ctrlName,"_")
	SVar target_dir=root:target_dir
	Wave UpstateOn=$(target_dir+":"+CleanupName("UpstateOn_"+trace,1))
	Wave UpstateOff=$(target_dir+":"+CleanupName("UpstateOff_"+trace,1))
	NVar upstate_number=$(target_dir+":upstate_number_"+trace)
	DeletePoints upstate_number,1,UpstateOn,UpstateOff
	Variable num_upstates=numpnts(UpstateOn)
	SetVariable $("UpstateNumber_"+trace),limits={0,num_upstates-1,1}
End