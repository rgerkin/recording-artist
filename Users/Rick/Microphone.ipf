#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function set_time()
	variable refNum
	open /p=NlxPath/r refNum as "CheetahLogFile.txt"
	string line
	do
		freadline refNum, line
		if(stringmatch(line,"*Time Opened*"))
			string date_str = stringfromlist(4,line," ")
		endif
		if(stringmatch(line,"*NOTICE*"))
			string time_str = stringfromlist(2,line,"-")
			time_str = replacestring(" ",time_str,"")
			break
		endif
	while(1)
	variable month,day,year
	sscanf date_str,"%d/%d/%d",month,day,year
	variable secs = date2secs(year,month,day) // At midnight for this date.  
	variable hours,minutes,seconds
	sscanf time_str,"%d:%d:%f",hours,minutes,seconds
	secs += 3600*hours + 60*minutes + seconds
	wave data = root:Mic1:data
	variable delta = dimdelta(data,0)
	setscale /p x,secs,delta,root:Mic1:data
	setscale /p x,secs,delta,root:Mic2:data
end

function session_start()
	dfref df = root:events
	wave /sdfr=df desc,times
	findvalue /txop=4 /text="SessionStart" desc
	variable t = NaN
	if(v_value>=0)
		t = times[v_value]
	endif
	return t
end

function load_running(tz)
	variable tz // How many hours relative to GMT?  e.g. Phoenix in the summer is -7.  
	loadwave /d/j/n=run_times/o/p=NlxPath/q "run_time.txt"
	loadwave /d/j/n=run_velocity/o/p=NlxPath/q "run_velocity.txt"
	wave run_times0
	run_times0 += date2secs(1970,1,1) + tz*60*60
end

function valve_triggered_response()
	wave /t new_session
	variable i,valve=nan,hours,minutes,seconds
	wave data = root:Mic1:data
	make /o/n=(2,0) x1_1,x1_2,x1_3,x2_1,x2_2,x2_3,x3_1,x3_2,x3_3
	setscale x,-5,5,x1_1,x1_2,x1_3,x2_1,x2_2,x2_3,x3_1,x3_2,x3_3
	make /o/n=(3,3) count=0
	make /o/n=(3,3,99) before_sniffs=nan
	make /o/n=(3,3,99) after_sniffs=nan	
	make /o/n=(3,3,99) interval=nan
	make /o/n=(3,3,99) amplitude=nan
	make /o/n=(3,3,99) interval=nan
	for(i=0;i<numpnts(new_session);i+=1)
		string time_,line = new_session[i]
		if(stringmatch(line,"TRIAL_PARAM:cur_valve*"))
			variable last_valve = valve
			sscanf line,"TRIAL_PARAM:cur_valve:%d|%d:%d:%f",valve,hours,minutes,seconds
			variable secs = date2secs(2014,7,23)+3600*hours+60*minutes+seconds
			//duplicate /free/r=(secs-5,secs+5) data,section
			duplicate /free/r=(secs-3,secs) data, before
			duplicate /free/r=(secs,secs+3) data, after
			if(numtype(last_valve)==0)
				setscale /p x,0,dimdelta(before,0),before,after
				//correlate /nodc/auto before,before
				//correlate /nodc/auto after,after
				variable count_ = count[last_valve-1][valve-1]
				wavestats /q before
				variable minn = v_min
				wavestats /q after
				minn = min(minn,v_min)
				variable threshold = minn/2
				findlevels /q/edge=2/m=0.01 before,threshold
				wave w_findlevels
				before_sniffs[last_valve-1][valve-1][count_] = numpnts(w_findlevels)
				findlevels /q/edge=2/m=0.01 after,threshold
				after_sniffs[last_valve-1][valve-1][count_] = numpnts(w_findlevels)
				count[last_valve-1][valve-1] += 1
				//wave matrix = $("x"+num2str(last_valve)+"_"+num2str(valve))
				//redimension /n=(-1,dimsize(matrix,1)+1) matrix
				//matrix[][dimsize(matrix,1)-1] = section[p]
			endif
		endif
	endfor
	before_sniffs /= 5
	after_sniffs /= 5
	wave before_sniffs,after_sniffs
	wavestats /q before_sniffs
	variable maxx = v_max
	wavestats /q after_sniffs
	maxx = max(maxx,v_max)
	make /o/n=2 unity = {0,maxx*1.2}
end

function plot_before_vs_after()
	display /k=1
	wave before_sniffs,after_sniffs,trials
	wavestats /q before_sniffs
	variable maxx = v_max
	wavestats /q after_sniffs
	maxx = max(maxx,v_max)
	make /o/n=2 unity = {0,maxx*1.2}
	variable i,j
	for(i=1;i<=3;i+=1)
		for(j=1;j<=3;j+=1)
			appendtograph /l=$("left"+num2str(i)) /b=$("bottom"+num2str(j)) after_sniffs[i-1][j-1][0,9] vs before_sniffs[i-1][j-1][0,9]
			appendtograph /l=$("left"+num2str(i)) /b=$("bottom"+num2str(j)) unity vs unity
			label $("left"+num2str(i)),"To "+num2str(i)
			label $("bottom"+num2str(j)),"From "+num2str(j)
		endfor
	endfor
	TileAxes()//grout={0.05})
	string traces = tracenamelist("",";",1)
	for(i=0;i<itemsinlist(traces);i+=1)
		string trace_name = stringfromlist(i,traces)
		if(stringmatch(trace_name,"after_sniffs*"))
			ModifyGraph mode($trace_name)=3,marker($trace_name)=19
			ModifyGraph zmrkSize($trace_name)={trials,*,*,1,10}
		endif
	endfor
end
