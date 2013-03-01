#pragma rtGlobals=1

// Methods for plotting each patch experiment

Function HistoryGraph(inpu,method) 
	String inpu
	Variable method
	Variable i
	Variable j
	NVar numExperiments=root:numExperiments
	ColorTab2Wave rainbow
	Wave rainbow=root:M_colors
	Wave input=$inpu
	
	switch(method)
		case 1:	// Plots all values of synaptic strength, with first value first	
			input[][][2]=input[p][q-1][3]
			for(i=0; i<dimSize(input,0); i+=1)
				input[i][0][2]=0
				input[i][1][2]=15
				for(j=2; j<dimSize(input,1); j+=1)
					input[i][j][2]+=input[i][j-1][2]
				endfor
			endfor
			Display /K=1
			for(i=0; i<dimSize(input,0); i+=1)
				AppendToGraph input[i][][0] vs input[i][][2]
			endfor
			ModifyGraph mode=2,lsize=4,rgb=(0,0,0),log(left)=1
			SetDrawEnv xcoord=bottom, ycoord=left, save
			
			for(i=0; i<dimSize(input,0); i+=1)
				for(j=1; j<dimSize(input,1); j+=1)
					if(input[i][j][1]>10 && input[i][j][1]<30 && input[i][j][0]!=0)
						SetDrawEnv linefgc=(0,0,65535)
						DrawLine input[i][j-1][2],input[i][j-1][0],input[i][j][2],input[i][j][0]
					elseif(input[i][j][1]>35 && input[i][j][1]<90 && input[i][j][0]!=0)
						SetDrawEnv linefgc=(65535,0,0)
						DrawLine input[i][j-1][2],input[i][j-1][0],input[i][j][2],input[i][j][0]
					elseif(input[i][j][0]!=0)
						SetDrawEnv linefgc=(0,65535,0)
						DrawLine input[i][j-1][2],input[i][j-1][0],input[i][j][2],input[i][j][0]
					endif
					SetDrawEnv fillfgc=(rainbow[floor(100*i/numExperiments)][0],rainbow[floor(100*i/numExperiments)][1],rainbow[floor(100*i/numExperiments)][2])
					DrawOval input[i][j-1][2]-1,input[i][j-1][0]*1.05,input[i][j-1][2]+1,input[i][j-1][0]*.95
				endfor
			endfor
		break						
		
		case 2:		// Plots relative potentiation, with first episode first	
			input[][][2]=input[p][q+1][3]
			for(i=0; i<dimSize(input,0); i+=1)
				input[i][0][2]=0
				for(j=1; j<dimSize(input,1); j+=1)
					input[i][j][2]+=input[i][j-1][2]
				endfor
			endfor
//			for(i=0; i<dimSize(input,0); i+=1)
//				for(j=0; j<dimSize(input,1)-1; j+=1)
//				input[i][j][4]=input[i][j+1][0]/input[i][j][0]
//				endfor
//			endfor
			Display
			for(i=0; i<dimSize(input,0); i+=1)
				AppendToGraph /B=bot input[i][][4] vs input[i][][2]
				//ModifyGraph lsize($("poop#"+num2str(i)))=log(input[i][0][0])*2.5
				ModifyGraph rgb($(inpu+"#"+num2str(i)))=(rainbow[floor(100*i/numExperiments)][0],rainbow[floor(100*i/numExperiments)][1],rainbow[floor(100*i/numExperiments)][2])
			endfor
			ModifyGraph mode=2
			ModifyGraph freePos(bot)={1,left}
	
			for(i=0; i<dimSize(input,0); i+=1)
				for(j=1; j<dimSize(input,1); j+=1)
					SetDrawEnv xcoord=bot, ycoord=left, fillfgc=(0,65535,0), linefgc=(rainbow[floor(100*i/numExperiments)][0],rainbow[floor(100*i/numExperiments)][1],rainbow[floor(100*i/numExperiments)][2]), save	
					if(input[i][j][4]!=0 && input[i][j+1][4]!=0)
						DrawLine input[i][j][2],input[i][j][4],input[i][j+1][2],input[i][j+1][4]
					endif
					if(input[i][j][1]>35 && input[i][j][1]<90)
						SetDrawEnv fillfgc=(65535,0,0)
					elseif(input[i][j][1]>10 && input[i][j][1]<30)
						SetDrawEnv fillfgc=(0,0,65535)
					endif
					if(input[i][j][4]!=0)
						DrawOval input[i][j][2]-input[i][0][0]/1000,input[i][j][4]+input[i][0][0]/15000,input[i][j][2]+input[i][0][0]/1000,input[i][j][4]-input[i][0][0]/15000
					endif
				endfor
			endfor
		break
		
		case 3:			// Plots cumulative potentiation, with first episode first		
			input[][][2]=input[p][q][3]
			
			for(i=0; i<dimSize(input,0); i+=1) // Get cumulative time elapsed
				input[i][0][2]=0
				for(j=1; j<dimSize(input,1); j+=1)
					input[i][j][2]+=input[i][j-1][2]
				endfor
			endfor
			
			Variable cumul
			for(i=0; i<dimSize(input,0); i+=1) // Get cumulative potentiation
				cumul=1
				for(j=0; j<dimSize(input,1); j+=1)
					if(input[i][j][4]!=0)
						cumul*=input[i][j][4]
						input[i][j][5]=cumul
					endif
				endfor
			endfor
			
			for(i=0; i<numExperiments; i+=1) // Fill bad inductions with previous cumulative change
				for(j=1; j<dimSize(input,1); j+=1)
					if(input[i][j][5]==0)
						input[i][j][5]=input[i][j-1][5]
					endif
				endfor
			endfor
			
			Variable lastGood
			for(i=0; i<dimSize(input,0); i+=1) // Cut out non-existent pairings after the last one
				lastGood=input[i][dimSize(input,1)-1][5]
				for(j=dimSize(input,1)-2; j>=0; j-=1)
					if(input[i][j][5]==lastGood)
						input[i][j+1][5]=0
						print j+1
					endif
				endfor
			endfor
			
			Display
			for(i=0; i<dimSize(input,0); i+=1)
					AppendToGraph /B=bot input[i][][5] vs input[i][][2]
					//ModifyGraph lsize($("poop#"+num2str(i)))=log(input[i][0][0])*2.5
					ModifyGraph rgb($(inpu+"#"+num2str(i)))=(rainbow[floor(100*i/numExperiments)][0],rainbow[floor(100*i/numExperiments)][1],rainbow[floor(100*i/numExperiments)][2])
			endfor
			ModifyGraph mode=2
			ModifyGraph freePos(bot)={1,left}
	
			for(i=0; i<dimSize(input,0); i+=1)
				for(j=0; j<dimSize(input,1); j+=1)
					SetDrawEnv xcoord=bot, ycoord=left, fillfgc=(0,0,0), linefgc=(rainbow[floor(100*i/numExperiments)][0],rainbow[floor(100*i/numExperiments)][1],rainbow[floor(100*i/numExperiments)][2]), save	
					if(input[i][j][5]!=0 && input[i][j+1][5]!=0)
						DrawLine input[i][j][2],input[i][j][5],input[i][j+1][2],input[i][j+1][5]
					endif
					if(input[i][j][1]>35 && input[i][j][1]<90 && input[i][j][6] > 0)
						SetDrawEnv fillfgc=(65535,0,0)
					endif
					if(input[i][j][1]>10 && input[i][j][1]<30 && input[i][j][6] > 0)
						SetDrawEnv fillfgc=(0,0,65535)
					endif
					if(input[i][j][1]>10 && input[i][j][1]<90 && input[i][j][6] < 0)
						SetDrawEnv fillfgc=(0,65535,0)
					endif
					if(input[i][j][5]!=0)
						DrawOval input[i][j][2]-OvalSize(input[i][0][0]),input[i][j][5]+OvalSize(input[i][0][0])/20,input[i][j][2]+OvalSize(input[i][0][0]),input[i][j][5]-OvalSize(input[i][0][0])/20
					endif
				endfor
			endfor			
		break
		default:
		Print "Not A Valid Method"
	endswitch
	SetAxis left 0.6,2.0
End

Function RemoveGraphsAndTables()
	Variable i
	for(i=0;i<100;i+=1)
	DoWindow/K $("Graph"+num2str(i))
	DoWindow/K $("Table"+num2str(i))
	endfor
End

Function OvalSize(size)
	Variable size
	return log(size)/5
End

Function Access2Igor()
	Variable i
	Variable/G numExperiments=1
	Variable pairingNumber
	RemoveGraphsAndTables()
	KillWaves poop
	Make /O/n=(100,10,7) root:Analysis:poop
	if(!WaveExists(root:AccessData))
		Make/O/T/n=(200,25) root:AccessData
	endif
	Wave/T AccessData=root:AccessData
	string currName=AccessData[0][0]
	Wave poop=root:Analysis:poop
	poop[0][0][0]=str2num(AccessData[0][4])
	for(i=0;i<=dimSize(AccessData,0);i+=1)
		if(cmpstr(AccessData[i][0],currName)!=0)
			numExperiments+=1
			//Redimension /n=(numExperiments,10,7) poop
			poop[numExperiments-1][0][0]=str2num(AccessData[i][4])
			currName=AccessData[i][0]
		endif
			pairingNumber=str2num(AccessData[i][1])
			print pairingNumber
			//print numExperiments
			poop[numExperiments-1][pairingNumber-1][1]=str2num(AccessData[i][2]) //Number of spikes
			poop[numExperiments-1][pairingNumber-1][3]=str2num(AccessData[i][3]) //Minutes since last
			poop[numExperiments-1][pairingNumber-1][4]=str2num(AccessData[i][5]) //Potentiation
			poop[numExperiments-1][pairingNumber-1][6]=str2num(AccessData[i][6]) //Timing
	endfor
End

Function SelectN(firstInduction,lastInduction,lowerTiming,upperTiming,inputOrig)
	Variable firstInduction
	Variable lastInduction
	Variable lowerTiming
	Variable upperTiming
	Wave inputOrig
	Variable i,j
	if(!WaveExists(inputOrig))
		print("This input wave does not exist!")
	endif
	Duplicate/O inputOrig poop2
	Wave input=poop2
	for(i=0; i<dimSize(input,0); i+=1)
		for(j=firstInduction; j<=lastInduction; j+=1)
			if(input[i][j-1][1]==0 || input[i][j-1][6]<lowerTiming || input[i][j-1][6]>upperTiming)
				input[i][][]=0
			endif
		endfor
		for(j=lastInduction; j<dimSize(input,1); j+=1)
			input[i][j][]=0
			print j
		endfor
	endfor
End

Function SelectOrder(order,firstInduction,lastInduction,inputOrig)
	String order
	Variable firstInduction
	Variable lastInduction
	Wave inputOrig
	Variable i,j
	if(!WaveExists(inputOrig))
		print("This input wave does not exist!")
	endif
	Duplicate/O inputOrig poop3
	Wave input=poop3
	Make/O/n=1 orderWave
	i=0
	Do
		Redimension/n=(i+1) orderWave
		orderWave[i]=str2num(StringFromList(i,order))
		i+=1
	While(cmpstr(StringFromList(i,order),"")!=0)
	for(i=0; i<dimSize(input,0); i+=1)
		for(j=firstInduction-1; j<=lastInduction-1; j+=1)
			if(input[i][j][1] != orderWave[j] && (orderWave[j]>0 || orderWave[j]<0))
				input[i][][]=0
			endif
		endfor
	endfor
End
