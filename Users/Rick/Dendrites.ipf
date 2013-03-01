#pragma rtGlobals=1		// Use modern global access method.
#include <Waves Average>

strconstant PLOT_LIST="Den Dcum;Spi Dcum;Den Dhist;Spi Dhist;Spi Dens;Den Ocum;Spi Ocum;Den Ohist;Spi Ohist;Den DvO;Spi DvO;Den OvD;Spi OvD;Mod Sholl;Bif;Term"

Function GetData([path])
	String path
	
	Variable refNum
	if(ParamIsDefault(path))
		PathInfo home
		NewPath /O/Q Data,S_Path+"Neurogenesis Project Tracings"
		Open /P=Data/R/T=".asc" refNum
	else
		Open /R/T=".asc" refNum as path
	endif
	String line,branch,mode=""
	Variable x1,y1,z1,diameter,point
	Make /o/n=(0,3) Dendrites,Apicals,Mitral,EPL,Dendrite_Spines
	Do
		FReadLine refNum, line
		if(strsearch(line,"End",0)>=0 && !(strsearch(line,"End of split",0)>=0)) // If the end of the mode has been reached.  
			mode="" // Reset mode.  
		endif
		strswitch(mode)
			case "Mitral":
				sscanf line,"%*[<( ]%f  %f  %f   %f%*[)>]",x1,y1,z1,diameter
				Mitral[dimsize(Mitral,0)]={{x1},{y1},{z1}}
				break
			case "EPL":
				sscanf line,"%*[<( ]%f  %f  %f   %f%*[)>]",x1,y1,z1,diameter
				EPL[dimsize(EPL,0)]={{x1},{y1},{z1}}
				break
			case "Apical": 
				break
			case "Dendrite":
				Wave Dendrites=$(mode+"s")
				if(strsearch(line,"Spine",0)>=0) // A spine line.  
					Wave Spines=$(mode+"_Spines")
					sscanf line,"%*[<( ]%f  %f  %f   %f%*[)>]",x1,y1,z1,diameter
					//print x1,y1,z1,diameter
					Spines[dimsize(Spines,0)]={{x1},{y1},{z1}}
					SetDimLabel 0,dimsize(Spines,0)-1,$branch,Spines
				else
					if(strsearch(line,"Root",0)>=0) // The root of the dendrite. 
						sscanf line," ( %f  %f  %f   %f)",x1,y1,z1,diameter
						branch="Root"
					else
						Variable order=strsearch(line,"(",0)/2
						sscanf line," ( %f  %f  %f   %f)  ; %d, %s",x1,y1,z1,diameter,point,branch
					endif
					if(x1^2 + y1^2 + z1^2==0) // No useful information.  
						break
					endif
					Dendrites[dimsize(Dendrites,0)]={{x1},{y1},{z1}}
					if(!strlen(branch))
						branch=GetDimLabel(Dendrites, 0, dimsize(Dendrites,0)-2)
					endif
					SetDimLabel 0,dimsize(Dendrites,0)-1,$branch,Dendrites 
				endif
				break
			default: // No mode, so we must see if it is time to begin one.  
				if(strsearch(line,"(Dendrite)",0)>=0)
					mode="Dendrite"
				elseif(strsearch(line,"(Apical)",0)>=0)
					mode="Apical"
				elseif(strsearch(line,"Set \"Mitral Cell Layer\"",0)>=0)
					mode="Mitral"
				elseif(strsearch(line,"Set \"External Plexiform Layer\"",0)>=0)
					mode="EPL"
				endif
				break
		endswitch
	While(strlen(line))
	Close refNum
End

Function FindSpinesDistances2Layer(Layer,method)
	Wave Layer; Variable method
	
	Wave Spines
	Variable i,j,k
	Make /o/n=(dimsize(Spines,0)) $(NameOfWave(Layer)+"BestDistances")=NaN//,$(NameOfWave(Layer)+"DistancesUp")=NaN,$(NameOfWave(Layer)+"DistancesDown")=NaN
	Wave BestDistances=$(NameOfWave(Layer)+"BestDistances")//, DistancesUp=$(NameOfWave(Layer)+"DistancesUp"), DistancesDown=$(NameOfWave(Layer)+"DistancesDown")
	for(i=0;i<dimsize(Spines,0);i+=1)
		Variable min_distance_up=Inf,min_distance_down=Inf
		Variable x3=Spines[i][0],y3=Spines[i][1],z3=Spines[i][2]
		
		for(j=0;j<dimsize(Layer,0);j+=1)
			Variable distance=sqrt((Spines[i][0]-Layer[j][0])^2 + (Spines[i][1]-Layer[j][1])^2 + (Spines[i][2]-Layer[j][2])^2)
			if(Spines[i][2]-Layer[j][2]<0 && distance<min_distance_up)
				min_distance_up=distance
				//print 1
				Variable min_index_up=j
			endif
			if(Spines[i][2]-Layer[j][2]>=0 && distance<min_distance_down)
				//print 1
				min_distance_down=distance
				Variable min_index_down=j
			endif
		endfor
		Variable x1=Layer[min_index_up][0],y1=Layer[min_index_up][1],z1=Layer[min_index_up][2]
		Variable x2=Layer[min_index_down][0],y2=Layer[min_index_down][1],z2=Layer[min_index_down][2]
		
		// Now find the distance between the spine and the line connecting the closest point in the layer above and the layer below.  
		// The below was derived from http://local.wasp.uwa.edu.au/~pbourke/geometry/pointline
		if(method==0)
			Variable u=((x3-x1)*(x2-x1) + (y3-y1)*(y2-y1) + (z3-z1)*(z2-z1))/((x2-x1)^2 + (y2-y1)^2 + (z2-z1)^2)
			Variable x_closest=x1+u*(x2-x1)
			Variable y_closest=y1+u*(y2-y1)
			Variable z_closest=z1+u*(z2-z1)
			//print x_closest
			Variable best_distance=sqrt((x3-x_closest)^2 + (y3-y_closest)^2 + (z3-z_closest)^2)
		elseif(method==1)
			// Ignore z in this method and just assume that layers extended perfectly along the z-axis.  
			min_distance_up=sqrt((x1-x3)^2 + (y1-y3)^2)
			min_distance_down=sqrt((x2-x3)^2 + (y2-y3)^2)
			best_distance=min(min_distance_up,min_distance_down)
		endif
		BestDistances[i]=best_distance
	endfor
End

Function /wave FindSpineDistances2Root(dendrite)
	String dendrite
	Wave Spines=$(dendrite+"_Spines"),Dendrites
	Variable i,j,k
	Variable numSpines=dimsize(Spines,0)
	
	Make /o/n=(numSpines) SpineDistances2Root=NaN, SpineBranchOrder=NaN
	
	for(i=0;i<numSpines;i+=1)
		Variable x1=Spines[i][0],y1=Spines[i][1],z1=Spines[i][2],minDistance=Inf
		for(j=0;j<dimsize(Dendrites,0);j+=1)
			Variable distance=sqrt((x1-Dendrites[j][0])^2 + (y1-Dendrites[j][1])^2 + (z1-Dendrites[j][2])^2)
			if(distance<minDistance)
				minDistance=distance
				//print 1
				Variable minIndex=j
			endif
		endfor
		x1=Dendrites[minIndex][0];y1=Dendrites[minIndex][1];z1=Dendrites[minIndex][2]
		String branch=GetDimLabel(Dendrites, 0, minIndex)
		SpineBranchOrder[i]=BranchOrder(branch)
		String parentBranch=ParentBranchFromBranch(branch)
		Variable totalDistance=0
		for(j=minIndex-1;j>=0;j-=1)
			String anotherBranch=GetDimLabel(Dendrites, 0, j)
			if(StringMatch(branch,anotherBranch) || StringMatch(parentBranch,anotherBranch))
				Variable x2=x1,y2=y1,z2=z1
				x1=Dendrites[j][0];y1=Dendrites[j][1];z1=Dendrites[j][2]
				totalDistance+=sqrt( (x1-x2)^2 + (y1-y2)^2 + (z1-z2)^2 )
				branch=GetDimLabel(Dendrites, 0, j)
				//print branch
				parentBranch=ParentBranchFromBranch(branch)
			endif
		endfor
		if(!StringMatch(branch,"Root"))
			printf "Spine %d did not map back to root.\r",i
		endif
		SpineDistances2Root[i]=totalDistance
	endfor
	return SpineDistances2Root
End

Function /wave FindDendriteDistances2Root()
	Wave Dendrites
	Variable i,j,k
	Variable numDendrites=dimsize(Dendrites,0)
	
	Make /o/n=(numDendrites) DendriteDistances2Root=NaN, DendriteBranchOrder=NaN,DendriteSegmentLengths=(p==0) ? 0 : NaN
	Make /o/T/n=(numDendrites) DendriteBranch=""
	Make /o/T/n=0 BranchPoints
	Make /o/n=0 BranchPointDistances2Root
	String branchPointsInfo=""
	
	for(i=0;i<numDendrites;i+=1)
		Variable x1=Dendrites[i][0],y1=Dendrites[i][1],z1=Dendrites[i][2]
		String branch=GetDimLabel(Dendrites, 0, i)
		DendriteBranch[i]=branch
		DendriteBranchOrder[i]=BranchOrder(branch)
		String parentBranch=ParentBranchFromBranch(branch)
		Variable totalDistance=0
		for(j=i-1;j>=0;j-=1)
			String anotherBranch=GetDimLabel(Dendrites, 0, j)
			if(StringMatch(anotherBranch,parentBranch)) // We have found the parent branch.  
				String branchPointName=parentBranch+"_"+branch
				branchPointsInfo=ReplaceStringByKey(branchPointName,branchPointsInfo,num2str(i)+"_"+num2str(totalDistance)) // The distance from dendritic point i to the branch point,  in the direction of the root point.  
			endif
			if(StringMatch(branch,anotherBranch) || StringMatch(parentBranch,anotherBranch))
				Variable x2=x1,y2=y1,z2=z1
				x1=Dendrites[j][0];y1=Dendrites[j][1];z1=Dendrites[j][2]
				variable segmentLength=sqrt( (x1-x2)^2 + (y1-y2)^2 + (z1-z2)^2 )
				totalDistance+=segmentLength
				if(numtype(DendriteSegmentLengths[i]))
					DendriteSegmentLengths[i]=segmentLength
				endif
				branch=GetDimLabel(Dendrites, 0, j)
				//print branch
				parentBranch=ParentBranchFromBranch(branch)
			endif
		endfor
		if(!StringMatch(branch,"Root"))
			printf "Dendritic point %d did not map back to root.\r",i
		endif
		DendriteDistances2Root[i]=totalDistance
	endfor
	for(i=0;i<ItemsInList(branchPointsInfo);i+=1)
		String branchPointInfo=StringFromList(i,branchPointsInfo)
		//print branchPointInfo
		Variable index,dendriteDistance2BranchPoint
		sscanf branchPointInfo,"%[^:]:%d_%d",branchPointName,index,dendriteDistance2BranchPoint // Distance of dendritic point 'index' from the branch point.  
		Variable dendriteDistance2Root=DendriteDistances2Root[index]
		Variable branchPointDistance2Root=dendriteDistance2Root-dendriteDistance2BranchPoint
		BranchPoints[i]={branchPointName}
		BranchPointDistances2Root[i]={branchPointDistance2Root}
	endfor
	return DendriteDistances2Root
End

Function BranchOrder(branch)
	String branch
	
	String parentBranch
	if(StringMatch(branch,"Root"))
		return 0 // Root.  
	elseif(strsearch(branch,"-",0)>=0) // e.g. R1-2-1-1
		return ItemsInList(branch,"-")-1
	elseif(strlen(branch)==1) // e.g. R
		return 0 // Root.  
	else // e.g. R1.  
		return NaN
	endif
End

Function /S ParentBranchFromBranch(branch)
	String branch
	
	String parentBranch
	if(StringMatch(branch,"Root"))
		parentBranch="Root"
	elseif(strsearch(branch,"-",0)>=0) // e.g. R1-2-1-1
		parentBranch=branch[0,strlen(branch)-3] // e.g. R1-2-1
	elseif(strlen(branch)==1) // e.g. R
		parentBranch="Root"
	else // e.g. R1
		parentBranch=branch[0,0]
	endif
	return parentBranch
End

// The number of possible branches that one could be on at a certain distance from root (following the paths of dendrites).  
Function /wave ComputeModifiedSholl([normalize])
	variable normalize
	
	Wave Dendrites,DendriteDistances2Root
	Variable numDendrites=dimsize(Dendrites,0)
	if(numDendrites==0)
		return NULL
	endif
	Make /FREE/T/n=(numDendrites) BranchNames=GetDimLabel(Dendrites,0,p)
	Make /FREE/T/n=0 UniqueBranchNames
	Make /FREE/n=0 BranchMins,BranchMaxes
	Variable i,j
	if(normalize)
		wavestats /q/m=1 dendriteDistances2Root
		variable last=v_max
	else
		last=400
	endif
	Variable numSteps=20
	Make /o/n=(numSteps) ModifiedSholl=0
	SetScale x,1,last,ModifiedSholl

	String branches=""
	for(i=0;i<numDendrites;i+=1)
		String branch=BranchNames[i]
		if(WhichListItem(branch,branches)<0)
			branches+=branch+";"
			UniqueBranchNames[numpnts(UniqueBranchNames)]={branch}
		endif
	endfor
	
	for(i=0;i<numpnts(UniqueBranchNames);i+=1)
		Extract /FREE DendriteDistances2Root,Segment,StringMatch(BranchNames[p],UniqueBranchNames[i])
		WaveStats /Q Segment
		BranchMins[i]={V_min}
		BranchMaxes[i]={V_max}
	endfor
	
	for(i=0;i<numSteps;i+=1)
		Variable distance=pnt2x(ModifiedSholl,i)
		for(j=0;j<numpnts(UniqueBranchNames);j+=1)
			if(distance>BranchMins[j] && distance<=BranchMaxes[j])
				ModifiedSholl[i]+=1
			endif
		endfor
	endfor
	if(normalize)
		setscale x,0,1,ModifiedSholl
	endif
	return ModifiedSholl
End

Function Descendants([normalize])
	variable normalize
	
	wave /t DendriteBranch
	wave DendriteBranchOrder,DendriteDistances2Root
	if(numpnts(DendriteDistances2Root)==0)
		return nan
	endif
	make /o/n=50 ProbB=0,ProbT=0
	make /free/n=50 Bifurcations=0,Terminations=0,Propagations=0,Total=0
	if(normalize)
		wavestats /q DendriteDistances2Root
		variable last=v_max
	else
		last=500
	endif
	setscale x,0,last,ProbB,ProbT,Bifurcations,Terminations,Propagations,Total
	duplicate /o DendriteBranchOrder DendriteOutcome,DendriteTermini
	variable i,j
	DendriteOutcome[0]=1 // Propagation from Root.  
	for(i=1;i<numpnts(DendriteBranch);i+=1)
		if(stringmatch(DendriteBranch[i],DendriteBranch[i+1]))
			DendriteOutcome[i]=1 // Propagation.  
		else
			DendriteOutcome[i]=0 // Termination.  
			for(j=0;j<numpnts(DendriteBranch);j+=1)
				if(stringmatch(DendriteBranch[j],DendriteBranch[i]+"-*"))
					DendriteOutcome[i]=2 // Bifurcation.  
					break
				endif
			endfor
		endif
	endfor
	
	extract /free/indx DendriteOutcome,Termini,DendriteOutcome==0
	DendriteTermini=0
	DendriteTermini[0]=numpnts(Termini) // Termini from Root.  
	for(i=1;i<numpnts(DendriteBranch);i+=1)
		for(j=0;j<numpnts(Termini);j+=1)
			if(stringmatch(DendriteBranch[Termini[j]],DendriteBranch[i]+"-*"))
				DendriteTermini[i]+=1 // Terminus downstream of this segment.    
			endif
		endfor
	endfor
	DendriteTermini=DendriteTermini==0 ? 1 : DendriteTermini // Terminal branches do not have zero termini, they have one.  
	
	for(i=0;i<numpnts(DendriteBranch);i+=1)
		variable distance=DendriteDistances2Root[i]
		variable bin=x2pnt(Bifurcations,distance)
		switch(DendriteOutcome[i])
			case 0:
				Terminations[bin]+=1
				break
			case 1:
				Propagations[bin]+=1
				break
			case 2:
				Bifurcations[bin]+=1
				break
		endswitch
		Total[bin]+=1
	endfor
	ProbB=Bifurcations/(deltax(Bifurcations)*Total)
	ProbT=Terminations/(deltax(Terminations)*Total)
	if(normalize)
		setscale x,0,1,ProbB,ProbT
	endif
End

Function /wave DendriteGLMs()
	variable i,j
	make /o/n=0 allBetas
	string folders=Dir2("folders",df=root:,match="A*")
	for(i=0;i<itemsinlist(folders);i+=1)
		Prog("Folders",i,itemsinlist(folders))
		string folder=stringfromlist(i,folders)
		dfref df=root:$folder
		string cells=Dir2("folders",df=df,match="Cell*")
		for(j=0;j<itemsinlist(cells);j+=1)
			Prog("Cells",j,itemsinlist(cells))
			string cell=stringfromlist(j,cells)
			dfref df2=df:$cell
			wave betas=DendriteGLM(df2)
			concatenate {betas},root:allBetas
		endfor
	endfor
End

Function /wave DendriteGLM(df)
	dfref df
	
	wave /sdfr=df DendriteOutcome,DendriteDistances2Root,DendriteBranchOrder,DendriteTermini,DendriteSegmentLengths
	print "Interpolating..."
	wave Outcome=InterpFromValueAndLength(DendriteOutcome,DendriteSegmentLengths)
	wave Order=InterpFromValueAndLength(DendriteBranchOrder,DendriteSegmentLengths)
	wave Termini=InterpFromValueAndLength(DendriteTermini,DendriteSegmentLengths)
	wave Distance=InterpFromValueAndLength(DendriteDistances2Root,DendriteSegmentLengths,mode=1)
	duplicate /free Outcome Terminate
	Terminate=Outcome==0
	print numpnts(Outcome),numpnts(Order),numpnts(Termini),numpnts(Distance)
	print "Fitting..."
	GLMFit(Terminate,{Termini,Order,Distance},"binomial",brief=1)	
	return betas
End

Function /s AllFiles([group,plots,suffix,normalize])
	Variable group // Each condition gets one graph.  
	string plots // Plot types.  
	string suffix // File name suffix, e.g. "Sholl"
	variable normalize // Normalize each trace so that its maximum value is 1.  
	
	group=paramisdefault(group) ? 1 : group
	setdatafolder root:
	//string location="2 Photon Tracings"
	//string location="ASC Files - Rick"
	string location="Neurogenesis Project Tracings"
	PathInfo home
	String path=S_Path+location
	NewPath /O/Q Data,path
	wave /t animal,condition
	wave cellsPerAnimal
	
	Variable i,j,k,m,l,red,green,blue
	if(paramisdefault(plots))
		plots=PLOT_LIST
	endif
	if(paramisdefault(suffix) || strlen(suffix)==0)
		suffix=""
	else
		suffix=" ("+suffix+")"
	endif
	
	for(i=0;i<itemsinlist(plots);i+=1)
		string plot=stringfromlist(i,plots)
		if(whichlistitem(plot,PLOT_LIST)<0 && !stringmatch(plot,"analyses"))
			print "No such plot "+plot+"."
			return ""
		endif
	endfor
	
	make /o/t/n=0 conditions
	make /o/n=0 conditionNumAnimals,conditionNumCells
	for(i=0;i<numpnts(condition);i+=1)
		variable conditionIndex=findvalue2t(conditions,condition[i])
		if(numtype(conditionIndex))
			variable point=numpnts(conditions)
			conditions[point]={condition[i]}
			conditionNumAnimals[point]={1}
			conditionNumCells[point]={cellsPerAnimal[i]}
		else
			conditionNumAnimals[conditionIndex]+=1
			conditionNumCells[conditionIndex]+=cellsPerAnimal[i]
		endif
	endfor
	
	// Make similar waves to store the number of animals/cells actually analyzed, to make sure we got them all at the end.  
	duplicate /free conditionNumAnimals numAnimalsAnalyzed
	numAnimalsAnalyzed=0
	duplicate /free conditionNumCells numCellsAnalyzed
	numCellsAnalyzed=0
	
	string wins=""
	i=0
	Do
		String folder=IndexedDir(Data, i, 1)
		string animalName=IndexedDir(Data, i, 0)
		Prog("Animal",i,numpnts(animal),msg=animalName)
		if(stringmatch(folder,"*.svn"))
			i+=1
			continue
		endif
		if(!strlen(folder))
			break
		endif
		
		variable animalIndex=FindValue2T(animal,animalName)
		if(numtype(animalIndex))
			print folder+" could not be found in the wave of animal folders"
		endif
		Condition2Color(condition[animalIndex],red,green,blue)
		
		NewDataFolder /O/S root:$(animalName)
		NewPath /O/Q Data2,folder
		conditionIndex=FindValue2T(conditions,condition[animalIndex])
		j=0
		Do
			string subFolder=IndexedDir(Data2, j, 1)
			string cellName=IndexedDir(Data2,j,0)
			Prog("Cell",j,cellsPerAnimal[animalIndex],msg=cellName)
			if(!strlen(subFolder))
				break
			endif
			if(!StringMatch(subFolder,"*Cell*"))
				j+=1
				continue
			endif
			string file=IndexedDir(Data2, j, 0) // File has the same name as its parent folder.  
			String name=CleanupName(file,0)
			NewDataFolder /O/S root:$(animalName):$name
			string str=subFolder+":"+file+suffix+".asc"
			GetData(path=str)
			string computations="" // Store a list of computations that have been done on this file so we don't do them over and over for each plot.  
			
			for(k=0;k<itemsinlist(plots);k+=1)
				plot=stringfromlist(k,plots)
				Prog("Plot",k,itemsinlist(plots),msg=plot)
				if(stringmatch(plot,"Analyses"))
					FindDendriteDistances2Root()
					FindSpineDistances2Root("Dendrite")
					ComputeModifiedSholl()
					Descendants()
					continue
				endif
				if(group)
					string win=cleanupname(condition[animalIndex]+"_"+plot,0)
				else
					win=cleanupname(name+"_"+plot,0)
				endif
				if(!group || numCellsAnalyzed[conditionIndex]==0)
					DoWindow /K $win
					Display /K=1 /N=$win as selectstring(group,name,condition[animalIndex])+" "+plot
					wins+=win+";"
					SetWindow $win userdata(ACL_desktopNum)=num2str(k+1)
					SetWindow $win userData(plot)=plot
					if(group)
						movewindow /w=$win conditionIndex*100,0,conditionIndex*100+400,300
					endif
				endif
				string yTraceName=cleanupname(animalName+"_"+name+"_"+plot,0)
				strswitch(plot)
					case "Den Dcum":
						if(whichlistitem(computations,"FindDendriteDistances2Root()")<0)
							FindDendriteDistances2Root()
							computations=AddListItem("FindDendriteDistances2Root()",computations)
						endif
						wave /z dist=DendriteDistances2Root
						wave /z length=DendriteSegmentLengths
						wave /z yy=InterpFromValueAndLength(dist,length)
						
						if(waveexists(yy) && numpnts(yy))
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif
							wave yy2=ECDF(yy,points=1000)
							AppendToGraph /w=$win /c=(red,green,blue) yy2 /tn=$yTraceName
							ModifyGraph /w=$win swapXY=1
							Label /w=$win bottom "Dendrite Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
							Label /w=$win left "Cumulative Probability"
						endif
						break
					case "Den Dhist":
						if(whichlistitem(computations,"FindDendriteDistances2Root()")<0)
							FindDendriteDistances2Root()
							computations=AddListItem("FindDendriteDistances2Root()",computations)
						endif
						wave /z dist=DendriteDistances2Root
						wave /z length=DendriteSegmentLengths
						wave /z yy=InterpFromValueAndLength(dist,length)
						if(waveexists(yy) && numpnts(yy))
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif
							make /o/n=10 $(getwavesdatafolder(yy,2)+"_hist") /wave=yy2
							setscale x,0,normalize ? 1 : 400,yy2
							histogram /b=2 yy,yy2
							AppendToGraph /w=$win /c=(red,green,blue) yy2 /tn=$yTraceName
							Label /w=$win bottom "Dendrite Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
							Label /w=$win left "Count"
						endif
						break
					case "Den Ocum":
						if(whichlistitem(computations,"FindDendriteDistances2Root()")<0)
							FindDendriteDistances2Root()
							computations=AddListItem("FindDendriteDistances2Root()",computations)
						endif
						wave /z order=DendriteBranchOrder
						wave /z length=DendriteSegmentLengths
						wave /z yy=InterpFromValueAndLength(dist,length)
						
						if(waveexists(yy) && numpnts(yy))
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif
							wave yy2=ECDF(yy,points=1000)
							AppendToGraph /w=$win /c=(red,green,blue) yy2 /tn=$yTraceName
							ModifyGraph /w=$win swapXY=1
							Label /w=$win bottom "Dendrite Branch Order"+selectstring(normalize,""," (norm)")
							Label /w=$win left "Cumulative Probability"
						endif
						break
					case "Den Ohist":
						if(whichlistitem(computations,"FindDendriteDistances2Root()")<0)
							FindDendriteDistances2Root()
							computations=AddListItem("FindDendriteDistances2Root()",computations)
						endif
						wave /Z order=DendriteBranchOrder
						wave /z length=DendriteSegmentLengths
						wave /z yy=InterpFromValueAndLength(dist,length)
						
						if(waveexists(yy) && numpnts(yy))
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif
							make /o/n=20 $(getwavesdatafolder(yy,2)+"_hist") /wave=yy2
							setscale x,0,normalize ? 1 : 20,yy2
							histogram /b=2 yy,yy2
							AppendToGraph /w=$win /c=(red,green,blue) yy2 /tn=$yTraceName
							Label /w=$win bottom "Dendrite Branch Order"+selectstring(normalize,""," (norm)")
							Label /w=$win left "Count"
						endif
						break
					case "Den DvO":
						if(whichlistitem(computations,"FindDendriteDistances2Root()")<0)
							FindDendriteDistances2Root()
							computations=AddListItem("FindDendriteDistances2Root()",computations)
						endif
						wave /z dist=DendriteDistances2Root
						wave /z order=DendriteBranchOrder
						wave /z length=DendriteSegmentLengths
						wave /z yy=InterpFromValueAndLength(dist,length)
						wave /Z xx=InterpFromValueAndLength(order,length)
						if(waveexists(yy) && waveexists(xx) && numpnts(yy) && numpnts(xx))	
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif
							AppendToGraph /w=$win /c=(red,green,blue) yy /tn=$yTraceName vs xx
							SetAxis/W=$win/A
							ModifyGraph /w=$win lsize=1, mode=2
							Label /w=$win left "Dendrite Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
							Label /w=$win bottom "Dendritic Branch Order"
							break
						endif
						break
					case "Den OvD":
						if(whichlistitem(computations,"FindDendriteDistances2Root()")<0)
							FindDendriteDistances2Root()
							computations=AddListItem("FindDendriteDistances2Root()",computations)
						endif
						wave /z dist=DendriteDistances2Root
						wave /z order=DendriteBranchOrder
						wave /z length=DendriteSegmentLengths
						wave /z yy=InterpFromValueAndLength(order,length)
						wave /Z xx=InterpFromValueAndLength(dist,length)
						
						if(waveexists(yy) && waveexists(xx) && numpnts(yy) && numpnts(xx))	
							if(normalize)
								wavestats /q/m=1 xx
								xx/=v_max
							endif
							AppendToGraph /w=$win /c=(red,green,blue) yy /tn=$yTraceName vs xx
							SetAxis/W=$win/A
							ModifyGraph /w=$win lsize=1, mode=2
							Label /w=$win left "Dendritic Branch Order"
							Label /w=$win bottom "Dendrite Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
							break
						endif
						break
					case "Spi Dcum":
						if(whichlistitem(computations,"FindSpineDistances2Root(Dendrite)")<0)
							FindSpineDistances2Root("Dendrite")
							computations=AddListItem("FindSpineDistances2Root(Dendrite)",computations)
						endif
						wave /z yy=SpineDistances2Root // Only looks at spines along the dendrite labeled "Dendrite" in the file.  
						if(waveexists(yy) && numpnts(yy))
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif
							wave yy2=ECDF(yy,points=1000)
							AppendToGraph /w=$win /c=(red,green,blue) yy2 /tn=$yTraceName
							ModifyGraph /w=$win swapXY=1
							Label bottom "Spine Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
							Label left "Cumulative Probability"
						endif
						break
					case "Spi Dhist":
						if(whichlistitem(computations,"FindSpineDistances2Root(Dendrite)")<0)
							FindSpineDistances2Root("Dendrite")
							computations=AddListItem("FindSpineDistances2Root(Dendrite)",computations)
						endif
						wave /z yy=SpineDistances2Root // Only looks at spines along the dendrite labeled "Dendrite" in the file.  
						if(waveexists(yy) && numpnts(yy))
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif
							make /o/n=10 $(getwavesdatafolder(yy,2)+"_hist") /wave=yy2
							setscale x,0,normalize ? 1 : 400,yy2
							histogram /b=2 yy,yy2
							AppendToGraph /w=$win /c=(red,green,blue) yy2 /tn=$yTraceName
							Label bottom "Spine Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
							Label left "Count"
						endif
						break
					case "Spi Dens":
						if(whichlistitem(computations,"ComputeModifiedSholl()")<0)
							ComputeModifiedSholl(normalize=normalize)
							computations=AddListItem("ComputeModifiedSholl()",computations)
						endif
						if(whichlistitem(computations,"FindSpineDistances2Root(Dendrite)")<0)
							FindSpineDistances2Root("Dendrite")
							computations=AddListItem("FindSpineDistances2Root(Dendrite)",computations)
						endif
						wave /z yy=SpineDistances2Root // Only looks at spines along the dendrite labeled "Dendrite" in the file.  
						wave /z xx=ModifiedSholl
						if(waveexists(yy) && numpnts(yy))
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif
							make /o/n=10 $(getwavesdatafolder(yy,2)+"_dens") /wave=yy2
							setscale x,0,normalize ? 1 : 400,yy2
							histogram /b=2 yy,yy2
							yy2/=numtype(xx(x)) ? 1 : (max(1,xx(x)))
							AppendToGraph /w=$win /c=(red,green,blue) yy2 /tn=$yTraceName
							Label /w=$win bottom "Spine Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
							Label /w=$win left "Spines per "+num2str(rightx(yy2)/numpnts(yy2))+" microns of Dendrite"
						endif
						break
					case "Spi Ocum":
						if(whichlistitem(computations,"FindSpineDistances2Root(Dendrite)")<0)
							FindSpineDistances2Root("Dendrite")
							computations=AddListItem("FindSpineDistances2Root(Dendrite)",computations)
						endif
						wave /z yy=SpineBranchOrder
						if(waveexists(yy) && numpnts(yy))
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif
							wave yy2=ECDF(yy,points=1000)
							AppendToGraph /w=$win /c=(red,green,blue) yy2 /tn=$yTraceName
							ModifyGraph /w=$win swapXY=1
							Label /w=$win bottom "Spine Branch Order"+selectstring(normalize,""," (norm)")
							Label /w=$win left "Cumulative Probability"
						endif
						break
					case "Spi Ohist":
						if(whichlistitem(computations,"FindSpineDistances2Root(Dendrite)")<0)
							FindSpineDistances2Root("Dendrite")
							computations=AddListItem("FindSpineDistances2Root(Dendrite)",computations)
						endif
						wave /z yy=SpineBranchOrder
						if(waveexists(yy) && numpnts(yy))
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif
							make /o/n=20 $(getwavesdatafolder(yy,2)+"_hist") /wave=yy2
							setscale x,0,normalize ? 1 : 20,yy2
							histogram /b=2 yy,yy2
							AppendToGraph /w=$win /c=(red,green,blue) yy2 /tn=$yTraceName
							Label /w=$win bottom "Spine Branch Order"+selectstring(normalize,""," (norm)")
							Label /w=$win left "Count"
						endif
						break
					case "Spi DvO":
						if(whichlistitem(computations,"FindSpineDistances2Root(Dendrite)")<0)
							FindSpineDistances2Root("Dendrite")
							computations=AddListItem("FindSpineDistances2Root(Dendrite)",computations)
						endif
						wave /z yy=SpineDistances2Root
						wave /z xx=SpineBranchOrder
						if(waveexists(yy) && waveexists(xx) && numpnts(yy) && numpnts(xx))
							if(normalize)
								wavestats /q/m=1 yy
								yy/=v_max
							endif	
							AppendToGraph /w=$win /c=(red,green,blue) yy /tn=$yTraceName vs xx 
							SetAxis/W=$win/A
							ModifyGraph /w=$win lsize=1, mode=2
							Label /w=$win left "Spine Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
							Label /w=$win bottom "Spine Branch Order"
							break
						endif
						break
					case "Spi OvD":
						if(whichlistitem(computations,"FindSpineDistances2Root(Dendrite)")<0)
							FindSpineDistances2Root("Dendrite")
							computations=AddListItem("FindSpineDistances2Root(Dendrite)",computations)
						endif
						wave /Z xx=SpineDistances2Root
						wave /z yy=SpineBranchOrder
						if(waveexists(yy) && waveexists(xx) && numpnts(yy) && numpnts(xx))
							if(normalize)
								wavestats /q/m=1 xx
								xx/=v_max
							endif	
							AppendToGraph /w=$win /c=(red,green,blue) yy /tn=$yTraceName vs xx 
							SetAxis/W=$win/A
							ModifyGraph /w=$win lsize=1, mode=2
							Label /w=$win left "Spine Branch Order" 
							Label /w=$win bottom "Spine Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
							break
						endif
						break
					case "Mod Sholl":
						if(whichlistitem(computations,"ComputeModifiedSholl()")<0)
							ComputeModifiedSholl(normalize=normalize)
							computations=AddListItem("ComputeModifiedSholl()",computations)
						endif
						wave /z yy=ModifiedSholl
						if(waveexists(yy) && numpnts(yy))	
							AppendToGraph /w=$win /c=(red,green,blue) yy /tn=$yTraceName 
							SetAxis/W=$win/A
							ModifyGraph /w=$win lsize=1, mode=4
							Label /w=$win left "# of Branches"
							Label /w=$win bottom "Dendrite Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
							break
						endif
						break
					case "Bif":
						Descendants(normalize=normalize)
						wave yy=ProbB
						if(waveexists(yy))
							AppendToGraph /w=$win /c=(red,green,blue) yy /tn=$yTraceName 
							SetAxis/W=$win left 0,0.03
							ModifyGraph /w=$win lsize=1, mode=4
							Label /w=$win left "Bifurcation Probability"
							Label /w=$win bottom "Dendrite Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
						endif
						break
					case "Term":
						Descendants(normalize=normalize)
						wave yy=ProbT
						if(waveexists(yy) && numpnts(yy))
							AppendToGraph /w=$win /c=(red,green,blue) yy /tn=$yTraceName 
							SetAxis/W=$win left 0,0.03
							ModifyGraph /w=$win lsize=1, mode=4
							Label /w=$win left "Termination Probability"
							Label /w=$win bottom "Dendrite Distance from Root ("+selectstring(normalize,"microns","fraction")+")"
						endif
						break
				endswitch
				waveclear yy,xx,yy2
			endfor
			j+=1
			numCellsAnalyzed[conditionIndex]+=1
		While(1)
		i+=1
		numAnimalsAnalyzed[conditionIndex]+=1
	While(1)
	
	SetDataFolder root:
	return wins
End

// Return a wave that has a value for every 0.05 microns of length in the dendrite.  Corrects for the uneven spacing of clicks in the reconstruction of the dendritic tree.  
function /wave InterpFromValueAndLength(value,length,[mode])
	wave value,length
	variable mode
	
	make /o/n=0 $(getwavesdatafolder(value,2)+"_int") /wave=yy
	variable m,l
	for(m=0;m<numpnts(value);m+=1)
		for(l=0;l<length[m];l+=0.1)
			yy[numpnts(yy)]={value[m]-mode*l}
		endfor
	endfor
	return yy
end

function /s FixGraphs(wins[,normalize])
	string wins
	variable normalize
	
	variable i,j
	for(i=0;i<itemsinlist(wins);i+=1)
		Prog("Fix Graph",i,itemsinlist(wins))
		string win=stringfromlist(i,wins)
		if(!wintype(win))
			i+=1
			continue
		endif
		string traces=tracenamelist(win,";",1)
		string plot=getuserdata(win,"","plot")
		//print i,win,plot
		strswitch(plot)
			case "Den Dcum":
			case "Spi Dcum":
				setaxis /w=$win left 0,1
				setaxis /w=$win bottom 0,normalize ? 1 : 500
				break
			case "Den Dhist":
			case "Spi Dhist":
				setaxis /w=$win/a left
				setaxis /w=$win bottom 0,normalize ? 1 : 500
				break
			case "Den Ocum":
			case "Spi Ocum":
				setaxis /w=$win left 0,1
				setaxis /w=$win bottom 0,normalize ? 1 : 15
				break
			case "Den Ohist":
			case "Spi Ohist":
				setaxis /w=$win/a left
				setaxis /w=$win bottom 0,normalize ? 1 : 500
				break
			case "Spi Dens":
				setaxis /w=$win left 0,10
				setaxis /w=$win bottom 0,normalize ? 1 : 500
				break
			case "Den DvO":
			case "Spi DvO":
				scatter2line(0,1,15,win=win)
				removetraces(match=traces,win=win) // Remove original scatter.  
				setaxis /w=$win left 0,normalize ? 1 : 500
				setaxis /w=$win bottom 0,15
				break
			case "Den OvD":
			case "Spi OvD":
				scatter2line(0,normalize ? 1/20 : 20,20,win=win)
				removetraces(match=traces,win=win) // Remove original scatter.  
				setaxis /w=$win left 0,15
				setaxis /w=$win bottom 0,normalize ? 1 : 500
				break
			case "Mod Sholl":
				setaxis /w=$win left 0,10
				setaxis /w=$win bottom 0,normalize ? 1 : 500
				break
			case "Bif":
			case "Term":
				setaxis /w=$win left 0,0.05
				setaxis /w=$win bottom 0,normalize ? 1 : 500
				break
			default:
				setaxis /w=$win/a left
				setaxis /w=$win bottom 0,normalize ? 1 : 500
				break
		endswitch
	endfor
	
	return wins
end

function MeanTraces(wins)
	string wins
	
	variable i
	for(i=0;i<itemsinlist(wins);i+=1)
		string win=stringfromlist(i,wins)
		if(!wintype(win))
			continue
		endif
		prog("Mean Traces",i,itemsinlist(wins),msg=win)
		if(stringmatch(win,"*Mean"))
			continue
		endif
		displaymeantrace(win=win,error="SEM",name=win+"_Mean",type="Med")
	endfor
end

function /s MeanGraphs(wins)
	string wins
	
	variable i,j
	make/free/n=0 meanPlots=0
	for(i=0;i<itemsinlist(wins);i+=1)
		string win=stringfromlist(i,wins)
		if(!wintype(win))
			continue
		endif
		prog("Mean Graphs",i,itemsinlist(wins),msg=win)
		if(stringmatch(win,"*Mean"))
			continue
		endif
		displaymeantrace(win=win,error="SEM",name=win+"_Mean",type="Mean")
		string plot=getuserdata(win,"","plot")
		variable desktopNum=str2num(getuserdata(win,"","ACL_DesktopNum"))
		string class=stringfromlist(0,win,"_")
		variable conditionIndex=str2num(class[1])-1
		string combinedWin=cleanupname(class+"_"+plot+"_Mean",0)
		variable index=FindDimLabel(meanPlots,0,combinedWin)
		if(index<0)
			insertpoints 0,1,meanPlots
			meanPlots[0]=0
			SetDimLabel 0,0,$combinedWin,meanPlots
			index=0
		endif
		
		if(meanPlots[index]==0)
			DoWindow /K $combinedWin
			Display /K=1 /N=$combinedWin as combinedWin
			wins+=combinedWin+";"
			SetWindow $combinedWin userdata(ACL_desktopNum)=num2str(desktopNum)
			SetWindow $combinedWin userData(plot)=plot
			movewindow /w=$combinedWin conditionIndex*300,600,conditionIndex*300+285,840
		endif
		string meanTraces=tracenamelist(win,";",1)
		meanTraces=listmatch(meanTraces,"*mean")
		
		for(j=0;j<itemsinlist(meanTraces);j+=1)
			string meanTrace=stringfromlist(j,meanTraces)
			variable red,green,blue
			tracecolour(win,meanTrace,red,green,blue)
			wave w=tracenametowaveref(win,meanTrace)
			appendtograph /w=$combinedWin /c=(red,green,blue) w
			if(j==0 && meanPlots[index]==0)
				string leftStr=GetAxisLabel("left",win=win)
				label/w=$combinedWin left leftStr
				string bottomStr=GetAxisLabel("bottom",win=win)
				label /w=$combinedWin bottom bottomStr
				if(stringmatch(leftStr,"*Cumul*") || stringmatch(bottomStr,"*Cumul*"))
					modifygraph /w=$combinedWin swapXY=1
				endif
			endif
		endfor
		meanPlots[index]+=1
		if(meanPlots[index]==2)
			armenerrorbars(win=combinedWin)
		endif
	endfor
	return wins
end

function AlignGraphs(wins)
	string wins
	
	variable j
	for(j=0;j<itemsinlist(wins);j+=1)
		string win=stringfromlist(j,wins)
		variable num=str2num(win[1])
		string type=stringfromlist(1,win,"_")
		variable yy=0
		switch(num)
			case 1:
				yy+=stringmatch(type,"siRNA")
				break
			case 2:
				yy+=stringmatch(type,"nares")
				break
			case 3:
				yy+=stringmatch(stringfromlist(2,win,"_"),"nares")
				break
		endswitch
		if(num>0)
			movewindow /w=$win (num-1)*300,yy*300,(num-1)*300+285,yy*300+240
		endif
	endfor
end

function removeMeans(wins)
	string wins

	variable i,j
	for(i=0;i<itemsinlist(wins);i+=1)
		string win=stringfromlist(i,wins)
		string traces=tracenamelist(win,";",1)
		traces=listmatch(traces,"*mean*")
		for(j=0;j<itemsinlist(traces);j+=1)
			string trace=stringfromlist(j,traces)
			removefromgraph /z/w=$win $trace
		endfor
	endfor
end

function exportGraphs(wins,name)
	string wins,name
	
	variable i
	newpath /o/c/q saveDir specialdirpath("desktop",0,0,0)+name
	for(i=0;i<itemsinlist(wins);i+=1)
		string win=stringfromlist(i,wins)
		Prog("Export",i,itemsinlist(wins),msg=win)
		savepict /o /e=-8 /p=saveDir /win=$win as win+".pdf" 
	endfor
end

function NormalizeAllGraphs()
	variable i,j
	string wins=winlist("*",";","WIN:1")
	for(j=0;j<itemsinlist(wins);j+=1)
		string win=stringfromlist(j,wins)
		RemoveTraces(match="*arm*",win=win)
		NormalizeTraces(win=win)
		//DisplayMeanTrace(win=win,error="SEM",name=win+"_Mean")
		setaxis /w=$win bottom 0,1
	endfor
end

static Function Condition2Color(condition,red,green,blue)
	string condition
	variable &red,&green,&blue
	
	strswitch(condition)
		case "g1 ctl":
			red=0; green=0; blue=0
			break
		case "g1 siRNA":
			red=65535;green=0;blue=0
			break
		case "g2 ctl":
			red=0; green=0; blue=0
			break
		case "g2 nares":
			red=65535;green=0;blue=0
			break
		case "g3 siRNA":
			red=65535; green=0; blue=0
			break
		case "g3 siRNA nares":
			red=0;green=40000;blue=0
			break
		default:
			red=32768; green=32768; blue=32768
			print "No such condition: "+condition
			break
	endswitch
End

static Function ConditionNameChange()
	setdatafolder root:
	wave /t Condition
	Condition=replacestring("Group 1",Condition,"g1")
	Condition=replacestring("Group 2",Condition,"g2")
	Condition=replacestring("Group 3",Condition,"g3")
	Condition=replacestring("Control",Condition,"ctl")
	Condition=replacestring("Nares Occlusion",Condition,"nares")
	Condition=replacestring("& ",Condition,"")
End

Function GraphMerge()
	SetDataFolder root:A341R:Cell_1:
	AppendToGraph g1_siRNA_Terminate_Mean/TN=g1_siRNA_Terminate_Mean_armen
	AppendToGraph g1_siRNA_Terminate_Mean
	ModifyGraph lSize(g1_siRNA_Terminate_Mean)=3
	ModifyGraph rgb(g1_siRNA_Terminate_Mean_armen)=(65535,32767,32767),rgb(g1_siRNA_Terminate_Mean)=(65535,0,0)
	Label left "Termination Probability"
	Label bottom "Dendrite Distance from Root (microns)"
	SetAxis left 0,0.01
	SetAxis bottom 0,500
	ErrorBars/L=2/Y=1 g1_siRNA_Terminate_Mean_armen Y,wave=(g1_siRNA_Terminate_SEM,g1_siRNA_Terminate_SEM)
EndMacro

Function AllBatch()
	make /free/t/n=4 suffix={"","Sholl","","Sholl"}
	make /free/n=4 normalize={0,0,1,1}
	variable i
	for(i=3;i<numpnts(suffix);i+=1)
		string name="X_"+suffix[i]+"_"+num2str(normalize[i])
		Prog("Batch",i,numpnts(suffix),msg=name)
		killall("graphs")
		string wins=allfiles(normalize=normalize[i],suffix=suffix[i])
		fixgraphs(wins,normalize=normalize[i])
		aligngraphs(wins)
		meantraces(wins)
		wins+=meangraphs(wins)
		exportgraphs(wins,name)
	endfor
End