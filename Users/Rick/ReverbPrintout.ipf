#pragma rtGlobals=1		// Use modern global access method.

#include "Minis"

//******* Appending the values from the analysis window will not work in this version.  You will have to go back to the 2007 version *******//

// Sets up the manager to created a reverberation printout.  
Function ReverbPrintoutManager([base_name])
	String base_name
	if(ParamIsDefault(base_name))
		base_name=CleanupName(IgorInfo(1),0)
	endif
	// Initialize
	if(winexist("ReverbPrintoutManagerWin"))
		DoWindow /F ReverbPrintoutManagerWin
		return 0
	endif
	NewPanel /K=1/FLT=0/N=ReverbPrintoutManagerWin /W=(100,100,475,335) as "Reverberation Printout Manager"
	NewDataFolder /O root:Packages
	NewDataFolder /O/S root:Packages:ReverbPrintout
	String /G sweep_list=""; SVar master_sweep_list=sweep_list
	
	// Some miscellaneous settings for the printout.  
	Variable i,j
	String /G base_printout_name=base_name
	String some_variables="Min_Duration,1;Max_Duration,30;Rows_per_Page,200;Downsample,1"
	String entry, var_name; Variable var_value
	for(i=0;i<ItemsInList(some_variables);i+=1)
		entry=StringFromList(i,some_variables)
		var_name=StringFromList(0,entry,",")
		var_value=str2num(StringFromList(1,entry,","))
		Variable /G $var_name=var_value
		SetVariable $var_name, pos={125*mod(i,2),floor(i/2)*25}, size={115,20}, title=ReplaceString("_",var_name," "), value=$var_name
	endfor
	
	// Lets the user choose which channels to display
	String channel, axis_extremum
	String /G axis_extrema="VC_Axis_Low,-700;VC_Axis_High,50;VC_Colorscale_Low,-600;VC_Colorscale_High,25;"
	axis_extrema+="CC_Axis_Low,-80;CC_Axis_High,30;CC_Colorscale_Mid,-65;CC_Colorscale_High,0"
	for(i=0;i<ItemsInList(all_channels);i+=1)
		channel=StringFromList(i,all_channels)
		if(!DataFolderExists("root:cell"+channel))
			continue
		endif
		NewDataFolder /O/S root:Packages:ReverbPrintout:$channel
		String /G sweep_list=WaveList2(folder="root:cell"+channel,match="sweep*")
		sweep_list=RemoveFromList2("*mean*",sweep_list)
		Checkbox $channel, pos={25+i*75,50}, title=channel, value=strlen(sweep_list)>0
		Variable red,green,blue; GetChannelColor(channel,red,green,blue)
		TabControl $(channel+"_tab"), appearance={os9,all}, pos={i*80,75}, size={85,20}, labelBack=(red,green,blue), value=0
		TabControl $(channel+"_tab"), appearance={os9,all}, fsize=8, fstyle=1, tabLabel(0)="VC", tabLabel(1)="CC", proc=RPM_Tabs
		KillVariables /Z red,green,blue
		sweep_list=RemovePrefix(sweep_list,"sweep")
		sweep_list=SortList(sweep_list,";",16)
		master_sweep_list+=sweep_list
		sweep_list=ListContract(sweep_list)
		SetVariable $(channel+"_sweep_list"), size={100,100}, pos={0,100}, value=root:Packages:ReverbPrintout:$(channel):sweep_list, title="Sweeps"
		Button $(channel+"_CopySweepList"), pos={120,97}, size={100,20}, proc=RPM_CopySweepList, title="Copy "+channel+" to All"
		for(j=0;j<ItemsInList(axis_extrema);j+=1)
			entry=StringFromList(j,axis_extrema) // First entry before the comma.  
			axis_extremum=StringFromList(0,entry,",") // The name of the extremum.  
			SetVariable $(channel+"_"+axis_extremum) title=ReplaceString("_",axis_extremum[2,strlen(axis_extremum)-1]," "), pos={0,125+25*mod(j,4)}, size={135,20}, proc=RPM_SetVariables
			String loc
			if(StringMatch(axis_extremum,"*colorscale*"))
				Variable /G $axis_extremum=str2num(StringFromList(1,entry,",")) // The value of the extremum.  
				loc="root:Packages:ReverbPrintout:"+channel+":"+axis_extremum
			else
				Variable /G ::$axis_extremum=str2num(StringFromList(1,entry,",")) // The value of the extremum.  
				loc="root:Packages:ReverbPrintout:"+axis_extremum // All channels printed in each example, so this value shouldn't be in a channel subfolder.  
			endif
			SetVariable $(channel+"_"+axis_extremum) variable=$loc
		endfor
	endfor
	master_sweep_list=RemoveDuplicates(master_sweep_list)
	master_sweep_list=SortList(master_sweep_list,";",16)
	master_sweep_list=ListContract(master_sweep_list)
	print master_sweep_list
	SetDataFolder root:Packages:ReverbPrintout
	NVar /Z last_sweep=root:current_sweep_number
	if(!NVar_exists(last_sweep))
		Variable /G root:current_sweep_number=1
		NVar last_sweep=root:current_sweep_number
	endif
	Make /o/T/n=(last_sweep) RPE_ListWave=num2str(x+1)
	Make /o/n=(last_sweep) RPE_SelWave=0
	ListBox ExampleSweeps,widths={35,55,20},size={100,175},pos={250,50}, listWave=RPE_ListWave,selWave=RPE_SelWave,frame=2,mode=4,proc=RPE_ListBox,title="Example Sweeps"
	PopUpMenu ColorMaps, pos={270,0}, size={100,20}, proc=RPM_ColorMap, value="Ultimo;"+ctablist()
	Checkbox ReverseCMap, pos={250,3}, title=" ", proc=RPM_ReverseColorMap, help={"Reverse ColorMap"}
	Checkbox AppendAnalysis, pos={155,130}, size={100,20}, title="Analysis"
	Button ReverbPrintout, proc=ReverbPrintout, pos={250,25}, size={100,20}, title="Printout"
	RPM_Tabs(StringFromList(0,all_channels)+"_tab",0)
	SetDataFolder root:
End

// Returns a list after removing duplicate items.  
static Function /S RemoveDuplicates(list)
	String list
	String new_list=""
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		if(WhichListItem(item,new_list)<0)
			new_list+=item+";"
		endif
	endfor
	return new_list
End

Function ReverbPrintout(ctrlName)
	String ctrlName
	String curr_folder=GetDataFolder(1)
	SetDataFolder root:Packages:ReverbPrintout
	SVar base_printout_name
	String /G printout_names=""
	
	// Make the channel printout (Pakming style) for all checked channels.  
	Variable i; String channel,channels=""
	SVar sweep_list
	Variable num_sweeps=ItemsInList(ListExpand(sweep_list))
	NVar rows_per_page
	Variable /G num_pages=ceil(num_sweeps/rows_per_page)
	Preferences 1
	for(i=0;i<num_pages;i+=1)
		String printout_name=(base_printout_name+"_"+num2str(i))
		NewLayout /K=1 /N=$printout_name
		DoWindow /T $printout_name base_printout_name+" Summary"
		MoveWindow /I/W=$printout_name 1,1,11,8.5
		printout_names+=printout_name+";"
	endfor
	
	for(i=0;i<ItemsInList(all_channels);i+=1)
		channel=StringFromList(i,all_channels)
		ControlInfo /W=ReverbPrintoutManagerWin $channel
		if(V_Value) // If the checkbox is checked.    
			ReverbChannelPrintout(channel,base_printout_name)
			channels+=channel+";"
		endif
	endfor
	
	// Make an example sweeps printout if any example sweeps are selected.  
	SetDataFolder root:Packages:ReverbPrintout
	Wave RPE_SelWave
	Extract /O/T RPE_ListWave,ExampleSweeps,(RPE_SelWave>0)
	if(numpnts(ExampleSweeps))
		printout_names+=ReverbExamplesPrintout(ExampleSweeps,base_printout_name,channels)
	endif
	
	SetDataFolder root:
	Button SaveAll pos={155,155}, size={75,20}, proc=RPM_Save, title="Save JPGs", win=ReverbPrintoutManagerWin
	DoWindow /F ReverbPrintoutManagerWin
End

Function RPM_Save(ctrlName)
	String ctrlName
	SetDataFolder root:Packages:ReverbPrintout
	SVar printout_names
	Variable i
	NewPath /O/Q ReverbPrintouts,SpecialDirPath("Desktop",0,0,0)+":Reverb Printouts"
	for(i=0;i<ItemsInList(printout_names);i+=1)
		String printout=StringFromList(i,printout_names)
		if(winexist(printout))
			DoWindow /F $printout
			String name=IgorInfo(1)
			if(StringMatch(name,"*_simplified"))
				name=RemoveEnding(name,"_simplified")
				if(i>0)
					name+="_"+num2str(i+1)
				endif
			else
				name=printout
			endif
			SavePICT/O/P=ReverbPrintouts/E=-6/B=288/WIN=$printout as name+".jpg"
		else
			print "Printout "+printout+" could not be found and was not saved."  
		endif
	endfor
	DoWindow /F ReverbPrintoutManagerWin
End

// Printout for Example Sweeps.  
Function /S ReverbExamplesPrintout(ExampleSweeps,base_printout_name,channels)
	Wave /T ExampleSweeps
	String base_printout_name,channels
	SetDataFolder root:Packages:ReverbPrintout

	// Create the layout.  
	String printout_name=base_printout_name+"_examples"
	if(winexist(printout_name))
		DoWindow /K $printout_name
	endif
	Preferences 1
	NewLayout /K=1 /N=$printout_name /P=Portrait
	PrintSettings /I margins={0.5,0.5,0.5,0.5}
	String layout_info=LayoutInfo("","Layout")
	DoUpdate
	
	Variable j,k
	Variable sections=max(numpnts(ExampleSweeps),4)
	for(j=0;j<numpnts(ExampleSweeps);j+=1)
		Variable example_sweep=str2num(ExampleSweeps[j])
		String display_name="Sweep"+num2str(example_sweep)
		Variable left=AccommodateMargins(0.03,layout_info,"x")
		Variable top=0.1+0.88*j/sections; top=AccommodateMargins(top,layout_info,"y")
		Variable right=AccommodateMargins(0.97,layout_info,"x")
		Variable bottom=0.1+0.88*(j+1)/sections; bottom=AccommodateMargins(bottom,layout_info,"y")
		Display /HOST=$printout_name /N=$display_name /W=(left,top,right,bottom)
		for(k=0;k<ItemsInList(channels);k+=1)
			String channel=StringFromList(k,channels)
			String sweep_name="root:cell"+channel+":sweep"+num2str(example_sweep)
			if(exists(sweep_name))
				Variable red,green,blue; GetChannelColor(channel,red,green,blue)
				Wave SweepParams=root:$("sweep_parameters_"+channel)
				Variable clamp=SweepParams[example_sweep][5]
				String clamp_str=SelectString(clamp,"CC","VC")
				strswitch(clamp_str)
					case "CC":
						AppendToGraph /R=CC_axis /c=(red,green,blue) $sweep_name
						break
					default: // Usually VC.  
						AppendToGraph /L=VC_axis /c=(red,green,blue) $sweep_name
						break
				endswitch
			endif
		endfor
		for(k=0;k<2;k+=1)
			clamp_str=StringFromList(k,"VC;CC")
			NVar lower=$(clamp_str+"_axis_low")
			NVar upper=$(clamp_str+"_axis_high")
			SetAxis /Z/W=$(printout_name+"#"+display_name) $(clamp_str+"_axis"),lower,upper
		endfor
		ModifyGraph /Z freePos(VC_axis)={0,kwFraction}, freePos(CC_axis)={0,kwFraction},btlen=3
		Label /W=$(printout_name+"#"+display_name) bottom "Sweep "+num2str(example_sweep)
		Label /W=$(printout_name+"#"+display_name) /Z VC_Axis "pA"
		Label /W=$(printout_name+"#"+display_name) /Z CC_Axis "mV"
	endfor
	KillVariables /Z red,green,blue
	
	TextBox /W=$printout_name /N=When /A=MB/X=0/Y=0 /F=0 /O=0 "\\Z12"+base_printout_name+"\Z09 (Printed "+date()+")"
	
	// Append notebook text
	//if(!exists("simplified_notebook_text"))
		Notebook Experiment_Log selection={startOfFile, endOfFile}
		GetSelection notebook, Experiment_Log, 2
		String /G simplified_notebook_text=S_selection
	//endif
	SVar text=simplified_notebook_text
	text=ReplaceString("\r",text,".  ")
	String spaces=""
	for(j=0;j<5;j+=1)	
		text=ReplaceString("."+spaces+".",text,".")
		spaces+=" "
	endfor
	text=WrapText(text,150)
	TextBox /N=Logg/F=0/A=LT/X=0/Y=0/B=1/W=$printout_name "\Z08"+text
	SetDataFolder root:
	return printout_name+";"
End

// Pakming style printout for a single channel.  
Function /S ReverbChannelPrintout(channel,base_printout_name)
	String channel,base_printout_name
	Variable i,j,k
	Variable channel_num=Chan2Num(channel)
	Preferences 1
	 
	SetDataFolder root:Packages:ReverbPrintout
	NVar min_duration,max_duration,downsample,rows_per_page,num_pages
	SVar master_sweep_list=sweep_list; String sweep_list=ListExpand(master_sweep_list)
	if(DataFolderExists(channel))
		SetDataFolder $channel
		Svar chan_sweep_list=sweep_list; String channel_sweep_list=ListExpand(chan_sweep_list) 
	else
		return ""
	endif
	if(strlen(sweep_list)==0)
		return ""
	endif
	NewDataFolder /O DownSampledSweeps
	NewDataFolder /O AxisLabels
	Wave SweepParams=$("root:Sweep_Parameters_"+channel)
	Wave sweep_t=root:sweep_t
	Variable red,green,blue; 
	GetChannelColor(channel,red,green,blue)
	
	// For each sweep, make the image and append it to the layout.  
	Variable page; String printout_names=""
	for(page=0;page<num_pages;page+=1)
		// Initialize the graph.   
		String printout_name=base_printout_name+"_"+num2str(page)
		DoWindow /F $printout_name
		Execute /Q "SetIgorOption UseOldLayoutCoords=1"
		Execute /Q "SetIgorOption UseOldGraphics=1"
		Display /HOST=$printout_name /W=(0.5*channel_num,0,0.5+0.5*channel_num,1) /N=$channel
		String win=printout_name+"#"+channel
		Variable /G vc_sweeps=0,cc_sweeps=0
		Variable last_sweep_time=0
		Make /o/n=(1,0) $("Medians"+num2str(page))=NaN; Wave Medians=$("Medians"+num2str(page))
		Make /o/n=0 $("Analysis1"+num2str(page))=NaN; Wave Analysis1=$("Analysis1"+num2str(page))
		Make /o/n=0 $("Analysis2"+num2str(page))=NaN; Wave Analysis2=$("Analysis2"+num2str(page))
		SetScale /P y,MinList(sweep_list),1,Medians // Assume one sweep at a time.  
		Variable first_sweep_index=k
		Variable cumul_rows=0
		//print GetDataFolder(1)
		//print sweeps
		Variable num_sweeps=ItemsInList(sweep_list)
		for(k=k;k<num_sweeps;k+=1)
			Variable sweep_num=NumFromList(k,sweep_list)
			String sweep_name="sweep"+StringFromList(k,sweep_list)
			String display_name=sweep_name
			String clamp_str=SelectString(SweepParams[sweep_num][5],"CC","VC")
			NVar /Z clamp_sweeps=$(clamp_str+"_sweeps")
			if(NVar_Exists(clamp_sweeps))
				clamp_sweeps+=1
			endif
			Wave /Z Sweep=$("root:cell"+channel+":"+sweep_name)
			Variable no_wave_on_this_channel=0
			if(!waveexists(Sweep))
				Wave /Z Sweep=$("root:cell"+OtherChannel(channel)+":"+sweep_name)
				no_wave_on_this_channel=1
			endif
			if(waveexists(Sweep))
				// Downsample and append.  
				NVar down_sample=root:Packages:ReverbPrintout:Downsample
				SetDataFolder :DownsampledSweeps
				Wave Downsampled=$Downsample(Sweep,down_sample)
				SetDataFolder ::
				if(StringMatch(clamp_str,"CC"))
					Variable median_value=0
				else
					median_value=no_wave_on_this_channel ? NaN : StatsMedian(Downsampled)
				endif
				Note /NOCR Downsampled, "Clamp="+clamp_str+";"
				Redimension /n=(-1,1) DownSampled
				String sweep_axis_name=sweep_name+"_axis"
				String time_axis_name="time_axis"
				InsertPoints /M=1 0,1,Medians
				InsertPoints 0,1,Analysis1,Analysis2
				Medians[0][0]=median_value
				Wave ampl=$("root:cell"+channel+":ampl_"+channel+"_"+channel)
				Wave ampl2=$("root:cell"+channel+":ampl2_"+channel+"_"+channel)
				Analysis1[0,0]=NaN
				Analysis2[0,0]=NaN
				Analysis1[0]=ampl[sweep_num-1]
				Analysis2[0]=ampl2[sweep_num-1]
				if(no_wave_on_this_channel)
					Downsampled=NaN
				endif
				
				// If a sweep spans multiple rows, set all values past index 0 to NaN to avoid redundant points.   
				
				Downsampled-=median_value // Subtract off the median in voltage clamp (which should be approximately equal to the mode for this data).  
				AppendImage /L=$sweep_axis_name /T=$time_axis_name Downsampled
				SetAxis /A/R $sweep_axis_name
				SetAxis $time_axis_name 0,max_duration
				
				// Fix the axes, etc. 
				ModifyGraph nticks($sweep_axis_name)=0
				Variable vertical_offset=1-(cumul_rows/rows_per_page)
				Variable vertical_delta=1/rows_per_page
				Variable axis_low=abs(vertical_offset-vertical_delta) // abs is because sometimes I get very small negative numbers instead of zero.  
				Variable axis_high=vertical_offset
				ModifyGraph axisEnab($sweep_axis_name)={axis_low,axis_high}, axisEnab($time_axis_name)={0.05,0.98}
				ModifyGraph freePos($sweep_axis_name)={0,$time_axis_name}
				if(k==first_sweep_index)
					ModifyGraph freePos($time_axis_name)={-Inf,$sweep_axis_name}
				endif
				ModifyGraph fsize=8, btlen=1,mirror=0,standoff($time_axis_name)=0
				SetDrawEnv xcoord=prel,ycoord=$sweep_axis_name,textrot=90,textyjust=1,fsize=9,save
				if(mod(sweep_num,5)==0)
					Make /o :AxisLabels:$(sweep_name+"_Ticks")={0}
					Make /o/T :AxisLabels:$(sweep_name+"_TickLabels")={num2str(sweep_num)}
					ModifyGraph userticks($sweep_axis_name)={:AxisLabels:$(sweep_name+"_Ticks"),:AxisLabels:$(sweep_name+"_TickLabels")}
					ModifyGraph nticks($sweep_axis_name)=1
				endif
				
				// Draw a line to demarcate the end of the recording for that sweep.  
				Variable duration=WaveDuration(Downsampled)
				SetDrawEnv xcoord=$time_axis_name,ycoord=$sweep_axis_name
				DrawLine duration,-0.5,duration,0.5
				
				// Add tick marks every 5th minute for time since that start of the experiment .  
				Variable sweep_time=sweep_t[sweep_num-1]
				if(sweep_time>=last_sweep_time+1 && mod(round(sweep_time),5)==0)
					last_sweep_time=round(sweep_time)
					String exp_time_axis_name=sweep_name+"_exp_time_axis"
					NewFreeAxis /R $exp_time_axis_name
					SetAxis $exp_time_axis_name last_sweep_time-1,last_sweep_time+1
					ModifyGraph nticks($exp_time_axis_name)=1, axisEnab($exp_time_axis_name)={axis_low,axis_high}, btlen($exp_time_axis_name)=1
					ModifyGraph manTick($exp_time_axis_name)={0,5,0,0},freepos($exp_time_axis_name)={max_duration,time_axis}
				endif
			endif
			cumul_rows+=1
			Variable last_sweep_index=k
			if(cumul_rows==200)
				break
			endif
		endfor
		
		ReverbPrintoutDrugTags() // Add tags corresponding to the times when drugs were washed in and washed out. 
		
		// Append colorscale for each clamp type.  
		for(i=0;i<2;i+=1)
			clamp_str=StringFromList(i,"VC;CC")
			NVar clamp_sweeps=$(clamp_str+"_sweeps")
			print clamp_sweeps
			if(clamp_sweeps)
				ColorScale /W=$win /N=$("ColorScale"+clamp_str)
			endif
		endfor
		
		// Show the median leak values.  
		WaveTransform /O flip, Medians
		DeletePoints /M=1 0,1,Medians
		AppendImage /L=median_sweep_axis /T=median_dummy_axis Medians
		ModifyGraph axisEnab(median_sweep_axis)={1-(cumul_rows/rows_per_page),1}, freePos(median_sweep_axis)={-0.5,median_dummy_axis}
		ModifyGraph axisEnab(median_dummy_axis)={0.98,1}, freepos(median_dummy_axis)={-0.5,median_sweep_axis}
		SetAxis/A/R median_sweep_axis
		ModifyGraph nticks(median_sweep_axis)=0, nticks(median_dummy_axis)=0
		
		// Show the values from the analysis window.  
		ControlInfo /W=ReverbPrintoutManagerWin AppendAnalysis
		if(V_Value)
			WaveTransform /O flip, Analysis1
			WaveTransform /O flip, Analysis2
			AppendToGraph /VERT /R=analysis_sweep_axis /B=analysis_ampl1_axis Analysis1
			AppendToGraph /VERT /R=analysis_sweep_axis /B=analysis_ampl2_axis Analysis2
			SetAxis /A/R analysis_sweep_axis
			//ModifyGraph offset($NameOfWave(Analysis1))={-0.5,0}, offset($NameOfWave(Analysis2))={-0.5,0}
			ModifyGraph rgb($NameOfWave(Analysis1))=(0,65535,0),rgb($NameOfWave(Analysis2))=(0,0,0)
			ModifyGraph mode=3,msize=2
			ModifyGraph marker($NameOfWave(Analysis1))=19,marker($NameOfWave(Analysis2))=19
			ModifyGraph axisEnab(analysis_sweep_axis)={1-((cumul_rows-1)/rows_per_page),1}, freePos(analysis_sweep_axis)={0.5,median_dummy_axis}
			ModifyGraph axisEnab(analysis_ampl1_axis)={0,0.5}, axisEnab(analysis_ampl2_axis)={0,0.5}
			ModifyGraph freepos(analysis_ampl1_axis)={0,kwFraction}, freepos(analysis_ampl2_axis)={1,kwFraction}
			SetAxis/A/R median_sweep_axis
			SetAxis analysis_sweep_axis cumul_rows-0.5,-0.5
			Extract /O Analysis1, Analysis1Clean, numtype(Analysis1)==0
			Extract /O Analysis2, Analysis2Clean, numtype(Analysis2)==0
			SetAxis/A analysis_ampl1_axis 5,MedianNonZero(Analysis1Clean)*3; Label analysis_ampl1_axis "\K(0,65535,0)Amplitude (pA)"
			SetAxis/A analysis_ampl2_axis 0,MedianNonZero(Analysis2Clean)*3; Label analysis_ampl2_axis "Frequency (Hz)"
			KillWaves /Z Analysis1Clean,Analysis2Clean
			ModifyGraph nticks(analysis_sweep_axis)=0,btlen(analysis_ampl1_axis)=1,btlen(analysis_ampl2_axis)=1
			ControlInfo /W=Ampl_Analysis Method
			// Append individual mini amplitudes.  
			if(StringMatch(S_Value,"Minis"))
				String sweep_axes=ListMatch(AxisList(""),"Sweep*")
				Variable m
				for(m=0;m<ItemsInList(sweep_axes);m+=1)
					String sweep_axis=StringFromList(m,sweep_axes)
					sweep_name=StringFromList(0,sweep_axis,"_")
					String curr_folder=GetDataFolder(1)
					String mini_folder="root:Minis:"+channel+":"+sweep_name
					if(DataFolderExists(mini_folder))
						SetDataFolder $mini_folder
						Wave Peak_Vals,Peak_Locs
						SetDataFolder $curr_folder
						String new_sweep_axis=sweep_axis+"_minis"
						CloneAxis(sweep_axis,new_sweep_axis)
						AppendToGraph /VERT /T=individual_mini_axis /R=$new_sweep_axis Peak_Vals vs Peak_Locs
						ModifyGraph mode($TopTrace())=2
						SetAxis $new_sweep_axis 0,3 // First 3 seconds of the sweep is assumed to be the location of the minis.   
						ModifyGraph nticks($new_sweep_axis)=0,btLen($new_sweep_axis)=0,userticks($new_sweep_axis)=0
					endif
				endfor
				ModifyGraph /Z axisEnab(individual_mini_axis)={0,0.5},log(individual_mini_axis)=1,btlen(individual_mini_axis)=0,nticks(individual_mini_axis)=0
				SetAxis /Z individual_mini_axis 5,200 // First 3 seconds of the sweep is assumed to be the location of the minis.   
				ModifyGraph /Z freePos(individual_mini_axis)={0.95,kwFraction};DelayUpdate
				Label /Z individual_mini_axis "\\K(65535,0,0)Amplitude (pA)"
			endif
		endif
		
		// Determine the regions of constant clamp type and add text to indicate them, as well as lines to demarcate them.  
		String page_sweeps=ListExtract(sweep_list,first_sweep_index,last_sweep_index)
		page_sweeps=RemoveFromList("",page_sweeps)
		//print first_sweep_index,last_sweep_index
		//print page
		ReverbPrintoutClampText(channel,page_sweeps,printout_name+"#"+channel) 
		
		ModifyGraph fSize=8
		//print printout_name,display_name
		//TextBox /W=$printout_name /N=SweepNum /A=LC/X=0/Y=0/E=2/F=0/O=90 "\\Z09Sweep Number"  
		//TextBox /W=$printout_name /N=TimeAxisLabel /A=MB/X=0/Y=0/E=2/F=0 "Time (s)"
		Variable print_more_info=1
		if(print_more_info)
			String more_info_text=""
			SQLConnekt("Reverb")
			String stackList=GetRTStackInfo(0)
			String name
			if(WhichListItem("ReverbAndMiniPrintouts",stackList)>=0)
				SVar curr_name=root:name
				name=curr_name
			else
				name=IgorInfo(1)
			endif
			name=RemoveEnding(name,"_simplified")
			SQLc("SELECT DIV,Drug_Incubated,DIV_Drug_Added FROM Island_Record WHERE Experimenter='RCG' AND File_Name='"+name+"'")
			Wave /Z DIV,DIV_Drug_Added; Wave /Z/T Drug_Incubated
			//print DIV[0]
			if(waveexists(DIV) && numtype(DIV[0])==0)
				more_info_text+="\Z09"+Drug_Incubated[0]+";   DIV: "+num2str(DIV[0])+";   DIV Drug Added: "+num2str(DIV_Drug_Added[0])+";   Days in Drug: "+num2str(DIV[0]-DIV_Drug_Added[0])
				TextBox /C /N=AgeDetails /W=$printout_name /A=MB/F=0/X=0/Y=0 more_info_text
			endif
		endif
		TextBox /C /N=ExperimentName /W=$printout_name  /A=MT/X=0/Y=0/E=2/F=0 "\K(0,0,0)"+name
		TextBox /C /N=$("Channel_"+channel) /W=$printout_name /A=MT/X=(25*(2*channel_num-1))/Y=0/E=2/F=0 "\K("+num2str(red)+","+num2str(green)+","+num2str(blue)+")"+channel
		KillVariables /Z red,green,blue
		RPM_Update()
	endfor
	return printout_name
End

Function ReverbPrintoutClampText(channel,sweeps,printout_name)
	String channel,sweeps,printout_name
	ClampRegions(channel,sweeps)
	Wave /T Clamps,ClampSweepLists
	Variable i,j
	//print sweeps; //abort
	DoUpdate
	for(i=0;i<numpnts(Clamps);i+=1)
		String clamp_sweep_list=ClampSweepLists(i)
		//print ClampSweepLists
		//print clamp_sweep_list
		// Draw a line at the top of the clamp region.  
		Variable min_sweep=MinList(clamp_sweep_list)
		String min_axis="sweep"+num2str(min_sweep)+"_axis"
		GetAxis /Q $min_axis
		SetDrawEnv xcoord=prel,ycoord=$min_axis,textrot=90,textyjust=1,fsize=8
		DrawLine 0.05,V_max,1,V_max
		
		// Draw a line at the bottom of the clamp region.  
		Variable max_sweep=MaxList(clamp_sweep_list)
		String max_axis="sweep"+num2str(max_sweep)+"_axis"
		GetAxis /Q $max_axis
		SetDrawEnv xcoord=prel,ycoord=$max_axis,textrot=90,textyjust=1,fsize=8
		DrawLine 0.05,V_min,1,V_min
		
		// Draw the text "VC" or "CC" for on the right side of the clamp region.  
		Variable mid_sweep=round((min_sweep+max_sweep)/2)
		j=0
		Do
			String mid_axis="sweep"+num2str(mid_sweep+j)+"_axis"
			j+=sign(j)
			j*=-1
		While(!AxisExists(mid_axis,win=printout_name))
		SetDrawEnv xcoord=median_dummy_axis,ycoord=$mid_axis,textrot=0,textyjust=1,fsize=8
		DrawText 1.75,0,Clamps[i]
	endfor
End

// Add tags for drugs to the reveberation printout
Function ReverbPrintoutDrugTags()
	Wave /T info=root:drugs:info
	Variable i,k
	for(i=0;i<numpnts(info);i+=1)
		String entry=info[i]
		String tag_text=""
		for(k=0;k<ItemsInList(entry);k+=1)
			String subentry=StringFromList(k,entry)
			String units=StringFromList(3,subentry,",")
			if(strlen(units)>2)
				Variable multiplier=str2num(units[0,strlen(units)-4])
				units=units[strlen(units)-2,strlen(units)-1]
			else
				multiplier=1
			endif
			Variable conc=str2num(StringFromList(2,subentry,","))
			String name=StringFromList(1,subentry,",")
			Variable thyme=str2num(StringFromList(0,subentry,","))
			tag_text+=num2str(conc*multiplier)+" "+units+"\r"+name+"\r"
		endfor
		tag_text=tag_text[0,strlen(tag_text)-2]
		if(StringMatch(tag_text,"*Washout*"))
			tag_text="Wash"
		endif
		Wave sweep_t=root:sweep_t
		Variable drug_sweep=2+BinarySearch(sweep_t,thyme)
		if(drug_sweep>0)
			String sweep_axis_name="sweep"+num2str(drug_sweep)+"_axis"
			if(WhichListItem(sweep_axis_name,AxisList(""))>=0)
				Tag /A=MT/F=0/B=1/X=-5/Y=-1.8 $sweep_axis_name,0.5,"\Z"+num2ndigits(10-1,2)+tag_text
			endif
		endif
	endfor
End

Function RPM_Update()
	String curr_folder=GetDataFolder(1)
	SetDataFolder root:Packages:ReverbPrintout
	NVar /Z num_pages
	Wave /Z/T ExampleSweeps
	SVar base_printout_name
	Variable i,j,k
	
	// Fix the example sweep axes. 
	NVar VC_axis_high,VC_axis_low,CC_axis_low,CC_axis_high
	String window_name=base_printout_name+"_examples" 
	if(winexist(window_name))
		for(i=0;i<numpnts(ExampleSweeps);i+=1)
			String example_sweep=ExampleSweeps[i]
			String sweep_display_name=window_name+"#Sweep"+example_sweep
			SetAxis /W=$sweep_display_name /Z VC_axis,VC_axis_low,VC_axis_high
			SetAxis /W=$sweep_display_name /Z CC_axis,CC_axis_low,CC_axis_high
		endfor
	endif
	
	// Fix the images for each channel.  
	ControlInfo /W=ReverbPrintoutManagerWin ColorMaps
	String color_scale=S_Value
	ControlInfo /W=ReverbPrintoutManagerWin ReverseCMap
	Variable reverse_map=V_Value
	
	for(i=0;i<ItemsInList(all_channels);i+=1)
		String channel=StringFromList(i,all_channels)
		String folder="root:Packages:ReverbPrintout:"+channel
		if(DataFolderExists(folder))
			SetDataFolder folder
		else
			continue
		endif
		ColorTab2Wave Red; Duplicate /o M_Colors :RedMap; Wave RedMap
		ColorTab2Wave Blue; Duplicate /o M_Colors :BlueMap; Wave BlueMap
		Make /o/n=(512,3) $("UltimoVC_"+channel),$("UltimoCC_"+channel)		
		Wave UltimoVC=$("UltimoVC_"+channel)
		Wave UltimoCC=$("UltimoCC_"+channel)
		strswitch(channel)
			case "R1":
				UltimoVC[0,255][]=RedMap[p][q]; UltimoVC[256,511][]=BlueMap[511-p][q]
				UltimoCC[0,255][]=BlueMap[p][q]; UltimoCC[256,511][]=RedMap[511-p][q]
				break
			case "L2":
				UltimoVC[0,255][]=BlueMap[p][q]; UltimoVC[256,511][]=RedMap[511-p][q]
				UltimoCC[0,255][]=RedMap[p][q]; UltimoCC[256,511][]=BlueMap[511-p][q]
				break
			default: 
				UltimoVC[0,255][]=RedMap[p][q]; UltimoVC[256,511][]=BlueMap[511-p][q]
				UltimoCC[0,255][]=BlueMap[p][q]; UltimoCC[256,511][]=RedMap[511-p][q]
				break
		endswitch
		
		Variable page
		for(page=0;page<num_pages;page+=1)
			String win_name=base_printout_name+"_"+num2str(page)+"#"+channel
			String image_list=ImageNameList(win_name,";")
			if(strlen(image_list)==0)
				continue
			endif
			for(j=0;j<ItemsInList(image_list);j+=1)
				// Adjust image colorscale.   
				String image_name=StringFromList(j,image_list)
				if(StringMatch(image_name,"*Medians*"))
					String clamp_str="VC" // Just assume voltage clamp for now.  
				else
					Wave ImageWave=ImageNameToWaveRef(win_name,image_name)
					clamp_str=StringByKey("Clamp",note(ImageWave),"=")
				endif
				if(StringMatch(clamp_str,"CC"))
					NVar mid=$("CC_colorscale_mid")
					NVar upper=$("CC_colorscale_high")
				else // e.g. VC
					NVar lower=$("VC_colorscale_low")
					NVar upper=$("VC_colorscale_high")
					//ColorScale /W=$win_name/C/N=ColorScaleVC axisRange={lower,50}
				endif
				
				if(StringMatch(color_scale,"Ultimo"))
					if(StringMatch(clamp_str,"CC"))
						SetScale x,mid-(upper-mid),upper,UltimoCC
					else // e.g. VC
						SetScale x,lower,-lower,UltimoVC
					endif
					ModifyImage /W=$win_name $image_name cindex=$("Ultimo"+clamp_str+"_"+channel)
				else
					ModifyImage /W=$win_name $image_name ctab={lower,upper,$color_scale,reverse_map}
				endif
			endfor
			
			// Adjust colorscale limits.  
			RPM_AdjustColorScale("CC",-85,0,win_name)
			NVar lower=$("VC_colorscale_low")
			RPM_AdjustColorScale("VC",lower,50,win_name)
		endfor
	endfor
	
	SetDataFolder $curr_folder
End

Function RPM_AdjustColorScale(clamp,low,high,win_name)
	String clamp
	Variable low,high
	String win_name
	String colorscale_name="ColorScale"+clamp
	if(AnnotationExists(colorscale_name,win=win_name))
		Variable offset=StringMatch(clamp,"VC") ? 3 : 11
		ColorScale /W=$win_name/C/N=$colorscale_name axisRange={low,high}
		ColorScale /W=$win_name/C/N=$colorscale_name/G=(0,0,0) widthPct=2,height=100,frameRGB=0
		ColorScale /W=$win_name/C/N=$colorscale_name/F=0/B=1/A=RT/X=(offset)/Y=0 fsize=6,tickLen=2.00
	endif
End

Function RPM_ReverseColorMap(ctrlName,value)
	String ctrlName; Variable value
	RPM_Update()
End

Function RPM_ColorMap(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName; Variable popNum; String popStr
	RPM_Update()
End

Function RPM_Tabs(tab,value)
	String tab
	Variable value
	String key_channel=StringFromList(0,tab,"_")
	Variable i,j
	SVar axis_extrema=root:Packages:ReverbPrintout:axis_extrema
	String window_name="ReverbPrintoutManagerWin"
	for(i=0;i<ItemsInList(all_channels);i+=1)
		String channel=StringFromList(i,all_channels)
		if(!DataFolderExists("root:cell"+channel))
			continue
		endif
		Variable disable=!StringMatch(channel,key_channel)
		SetVariable $(channel+"_sweep_list"), disable=disable, win=$window_name
		Button $(channel+"_CopySweepList"), disable=disable, win=$window_name
		if(disable)
			TabControl $(channel+"_tab"), labelback=(32768,32768,32768), win=$window_name
		else
			Variable red,green,blue; GetChannelColor(channel,red,green,blue)
			TabControl $(channel+"_tab"), labelback=(red,green,blue), win=$window_name
		endif
		for(j=0;j<ItemsInList(axis_extrema);j+=1)
			String entry=StringFromList(j,axis_extrema) // First entry before the comma.  
			String axis_extremum=StringFromList(0,entry,",") // The name of the extremum.
			//print value,j,j&2  
			disable=!(StringMatch(channel,key_channel) && (value==(j>=4)))
			SetVariable $(channel+"_"+axis_extremum) disable=disable, win=$window_name
		endfor
	endfor
End

Function RPM_ExamplesListBox(ctrlName,row,col,event) : ListboxControl
	String ctrlName     // name of this control
	Variable row,col,event
	Variable sweep_num
	switch(event)
		case 1:
			String channel=StringFromList(0,ctrlName,"_")
			SetDataFolder root:Packages:ReverbPrintout
			
			// Activate channels in the 'Sweeps' window so that their sweeps will show up.  
			Variable i; 
			for(i=0;i<ItemsInList(all_channels);i+=1)
				channel=StringFromList(i,all_channels)
				ControlInfo /W=ReverbPrintoutManager $channel
				if(V_Value)
					Checkbox $channel value=1, win=Sweeps
				endif
			endfor
			
			MoveCursor("A",row+1)
			break
	endswitch
End

Function RPM_CopySweepList(ctrlName)
	String ctrlName
	String key_channel=StringFromList(0,ctrlName,"_")
	SVar key_sweep_list=root:Packages:ReverbPrintout:$(key_channel):sweep_list
	Variable i; String channel
	for(i=0;i<ItemsInList(all_channels);i+=1)
		channel=StringFromList(i,all_channels)
		SVar sweep_list=root:Packages:ReverbPrintout:$(channel):sweep_list
		sweep_list=key_sweep_list
	endfor
End

Function RPM_SetVariables(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName; Variable varNum; String varStr, varName
	RPM_Update()
End

// Returns the top image in an Image Graph
Function /S TopClampImage(clamp,[win])
	String clamp,win
	if(ParamIsDefault(win))
		win=WinName(0,1)
	endif
	String list=ImageNameList(win,";")
	Variable i
	for(i=ItemsInList(list)-1;i>0;i-=1)
		String image_name=StringFromList(i,list)
		Wave ImageWave=ImageNameToWaveRef(win,image_name)
		String this_clamp=StringByKey("Clamp",note(ImageWave),"=")
		if(StringMatch(clamp,this_clamp))
			return image_name
		endif
	endfor
	return "" 
End

Function SummaryPlusMiniAnalysis(channel)
	String channel
	NewDataFolder /O/S root:SPMA
	NewDataFolder /O/S $channel
	Variable first_sweep=1+xcsr(A,"Ampl_Analysis")
	Variable last_sweep=1+xcsr(B,"Ampl_Analysis")
	Variable sweep,split=0
	sweep=first_sweep
	Make /o/n=0 MiniAmpls
	Make /o/n=0 MiniFreqs
	Make /o/n=(0,30000) Summary
	Do
		Wave SweepWave=$("root:cell"+channel+":sweep"+num2str(sweep))
		Duplicate /o/R=(0.15+split*30,0.299+split*30) SweepWave, MiniRegion
		Duplicate /o/R=(0+split*30,30+split*30) SweepWave, SummaryRegion; Wave SummaryRegion
		FindMinis(MiniRegion,thresh=7.5)
		Wave Peak_Locs,Peak_Vals
		Variable count=numpnts(Peak_Locs)
		InsertPoints /M=0 0,1,MiniAmpls,MiniFreqs,Summary
		MiniAmpls[0]=StatsMedian(Peak_Vals)
		MiniFreqs[0]=StatsMedian(Peak_Locs)
		Downsample(SummaryRegion,10,in_place=1)
		Summary[0][]=SummaryRegion[q]
		KillWaves /Z MiniRegion,SummaryRegion
		if(WaveDuration(SweepWave)>30 && split==0)
			split=1
		else
			sweep+=1
			split=0
		endif
	While(sweep<=last_sweep)
	Display /K=1
	AppendImage /L=sweep_axis /T=time_axis Summary
	AppendToGraph /L=sweep_axis MiniAmpls,MiniFreqs
	SetDataFolder root:
End

Function PrintBaselineValues(ctrlName)
	String ctrlName
	Wave /T PreBaselineSweeps=root:PrintoutInfo:PreBaselineSweeps
	Wave /T PostBaselineSweeps=root:PrintoutInfo:PostBaselineSweeps
	Variable i,left,right
	for(i=0;i<numpnts(PreBaselineSweeps);i+=1)
		print "Induction "+num2str(i)+":"
		left=NumFromList(0,PreBaselineSweeps[i],sep=",")-1; right=NumFromList(1,PreBaselineSweeps[i],sep=",")-1;
		print "Pre: "+WaveStat(x1=left,x2=right,no_print=1)
		left=NumFromList(0,PostBaselineSweeps[i],sep=",")-1; right=NumFromList(1,PostBaselineSweeps[i],sep=",")-1
		print "Post: "+WaveStat(x1=left,x2=right,no_print=1)
	endfor
End

Function AddPrintoutSweeps(ctrlName)
	String ctrlName
	NVar induction_number=root:PrintoutInfo:induction_number
	String wave_name
	sscanf ctrlName,"Add%s",wave_name
	Wave /T theSweeps=root:PrintoutInfo:$wave_name
	if(induction_number>numpnts(theSweeps))
		Redimension /n=(induction_number) theSweeps
	endif
	Variable sweep_left=1+xcsr(A,"AnalysisWin")
	Variable sweep_right=1+xcsr(B,"AnalysisWin")
	theSweeps[induction_number-1]=num2str(sweep_left)+","+num2str(sweep_right)
	
	// Add a regression line.  
	if(StringMatch(wave_name,"*baseline*"))
		String pre_or_post,channel,name
		sscanf wave_name, "%sBaselineSweeps", pre_or_post
		Wave theWave=CsrWaveRef(A,"AnalysisWin")
		CurveFit /N/Q line, theWave[sweep_left-1,sweep_right-1] /X=sweepT[sweep_left-1,sweep_right-1] /D
		name=pre_or_post+"_"+num2str(induction_number)
		RemoveFromGraph /Z $name
		KillWaves /Z $("root:PrintoutInfo:"+name)
		Rename $TopTrace(win="AnalysisWin") $name
		MoveWave $name,root:PrintoutInfo:
		sscanf GetWavesDataFolder(theWave,0),"cell%s",channel
		Variable red,green,blue; GetChannelColor(channel,red,green,blue); 
		ModifyGraph /W=AnalysisWin lsize($name)=1.5,rgb($name)=(0,0,0)//(red,green,blue)
	endif
End