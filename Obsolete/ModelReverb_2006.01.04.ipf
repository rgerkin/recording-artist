#pragma rtGlobals=1		// Use modern global access method.

Function ModelControlWindow()
	DoWindow /K ModelControlWin
	NewPanel /K=1 /W=(0,0,350,850) /N=ModelControlWin as "Model Control"
	NewDataFolder /O/S root:Parameters
	Variable i,inc
	String variable_name,variable_names=StringByKey("VARIABLES",DataFolderDir(4))
	variable_names=ReplaceString(",",variable_names,";")
	variable_names=SortList(variable_names,";",4)
	for(i=0;i<ItemsInList(variable_names);i+=1)
		variable_name=StringFromList(i,variable_names)
		NVar var=root:parameters:$variable_name
		inc=(var==0) ? 1 : var/10
		SetVariable /Z $variable_name,size={150,20},title=variable_name,limits={-inf,inf,inc},value=root:parameters:$variable_name,proc=ModelControlProc2
		SetVariable /Z $variable_name userData=num2str(var)
	endfor
	Button ResetParameters,size={150,20},proc=ModelControlProc,title="Reset to Parameter Defaults"
	Button RegenerateNetwork,size={150,20},proc=ModelControlProc,title="Regenerate Network"
	Button Start,size={150,20},proc=ModelControlProc,title="Start"
	Button ContinueZ,size={150,20},proc=ModelControlProc,title="Continue"
End

Function ModelControlProc2(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr,varName
	Variable /G root:new_value=varNum
	String /G root:curr_control=ctrlName
	ModelControlProc("RegenerateWaves")
End

Function ModelControlProc(ctrlName) : ButtonControl
	String ctrlName
	
	NewDataFolder /O/S root:Parameters
	//print ctrlName
	if(!StringMatch(ctrlName,"ResetParameters"))
		NVar neurons,duration,delta_t,tau_d_Glut, tau_d_GABA,tau_r_Glut,tau_r_GABA,tau_l_Glut,tau_l_GABA,tau_s_Glut,tau_s_GABA,mu_Glut,mu_GABA,Cm, gL,tau,R_input,a0
		NVar gAMPA2Glut,gNMDA2Glut,gGABA2Glut,gAMPA2GABA,gNMDA2GABA,gGABA2GABA,AMPAR_mult,VL,VK,VGlut,VGABA,Vreset,AlphaCa,tauCa,Mg,refractory,synDelay
		NVar connectGlut2Glut,connectGlut2GABA,connectGABA2Glut,connectGABA2GABA,VthreshGlut,VthreshGABA,threshold_stdev,threshIncGlut,threshTauGlut,threshIncGABA,threshTauGABA
		NVar adaptIncGlut,adaptTauGlut,adaptIncGABA,adaptTauGABA,propGABA,betaCa,nCa,k1Ca,i_Ca_passive,gammaCa,eta_max,sCa,k2Ca,CaO,gammaAsync2,tauAsync2,xiAsync2
	endif
	
	strswitch(ctrlName)
		case "ResetParameters":
			Variable /G neurons=64,duration=5000,delta_t=1
			// Synaptic decay constant and time constant of recovery of vesicles to the active pool.  
			Variable /G tau_d_Glut=10, tau_d_GABA=50
			Variable /G tau_r_Glut=300, tau_r_GABA=300
			Variable /G tau_l_Glut=5000, tau_l_GABA=5000
			Variable /G tau_s_Glut=10000, tau_s_GABA=10000
			Variable /G mu_Glut=0.2,mu_GABA=0.2
			// Membrane time constant, leak conductance, AHP conductance for each cell type
			Variable /G Cm=1, gL=0, tau=10, R_input=0.5, a0=0.1
			// Synaptic conductances for each cell type; basically just two time constants for a general synaptic conductance
			//Variable /G gNMDA2Glut=0.01,gAMPA2Glut=0.07,gGABA2Glut=0.07
			//Variable /G gNMDA2GABA=0.01,gAMPA2GABA=0.03, gGABA2GABA=0.05;
			Variable /G gAMPA2Glut=10, gNMDA2Glut=0, gGABA2Glut=0
			Variable /G gAMPA2GABA=0.5, gNMDA2GABA=0, gGABA2GABA=0;
			Variable /G AMPAR_mult=1 // A multiplier for the AMPAR current, e.g. 0.5 would correspond to 50% AMPAR_Mult.  
			// Reversal Vs, reset V, and thresholds
			Variable /G VL=-70, VK=-90, VGlut=0, VGABA=-65, Vreset=-70
			// The amount by which Calcium increases with each spike; sort of like the rate of firing rate adaptation, except it works by enhancing the AHP  
			// The rate at which Calcium (AHP adaptation) decays.  The extracellular magnesium concentration in mM.
			Variable /G AlphaCa=0.15, tauCa=80, Mg=2
			// The rates at which the synaptic currents decay
			//Variable /G tau_AMPA=10, tau_NMDA=75, tau_GABA=50;
			// An absolute refractory period and a synaptic delay
			Variable /G refractory=3, synDelay=2;
			// A connectivity ratio, e.g. only 30% of the cell pairs will even be connected (subject to the exponential distribution).  
			Variable /G connectGlut2Glut=0.1, connectGlut2GABA=0.1, connectGABA2Glut=0.1, connectGABA2GABA=0.1;
			// This is actual firing rate adaptation, the threshInc's are the increment by which the firing threshold is incremented.  
			// The taus are the rate at which this increase in the threshold decays. 
			Variable /G VthreshGlut=-40, VthreshGABA=-30, threshold_stdev=5;
			Variable /G threshIncGlut=10, threshTauGlut=200, threshIncGABA=10, threshTauGABA=200
			Variable /G adaptIncGlut=0, adaptTauGlut=50, adaptIncGABA=0, adaptTauGABA=50;
			// The proportion of cells that are GABAergic.  
			Variable /G propGABA=0.1;
			// Set all the phenotypes of the cells, excitatory or inhibitory. 
			Variable /G betaCa=0.005,nCa=2,k1Ca=0.4,i_Ca_passive=0//15
			Variable /G gammaCa=0.125,eta_max=0.5,sCa=1,k2Ca=0.5,CaO=2000,xi=0.02
			Variable /G gammaAsync2=1,tauAsync2=30000,xiAsync2=10
			
			// Old values
			// eta_max=0.3
			// sCa=4
			// k2Ca=0.1
			//
			ModelControlProc("RegenerateWaves")
			break
		case "RegenerateNetwork":
			Make /o/n=(neurons) phenotype=abs(enoise(1))<propGABA // 0 will be Glut, 1 will be GABA.  
			phenotype[1][1]=0 // Force cell 1 to be glutamatergic
			Make /o/n=(neurons) ThresholdVariability=gnoise(1); //The baseline value of the firing threshold, randomized for each cell around a mean value.   
			Make /o/n=(2,2) connectionProbs={{connectGlut2Glut,connectGABA2Glut},{connectGlut2GABA,connectGABA2GABA}} 
			Make /o/n=(neurons,neurons) connectionMatrix=(abs(enoise(1))<connectionProbs[phenotype[p]][phenotype[q]])*abs(enoise(1)); // Generate connection strengths (to be multiplied by conductances). 
			ModelControlProc("RegenerateWaves")
			break
		case "RegenerateWaves":
			Make /o/n=(neurons,neurons) synapseN,synapseA,synapseI,connectionMatrix
			Make /o/n=(neurons) phenotype,V,deltaV,Calcium,Async2Force,Hill,Hill,CaForce,eta,facilitation,spiking,lastspike,aEPSC,nEPSC,IPSC
			Make /o/n=(neurons) tau_r,tau_d,tau_l,tau_s,mu,injected,InitThreshold,ThresholdVariability,Threshold,ThresholdInc,ThresholdTau,gAdapt=0,AdaptInc,AdaptTau
			Make /o/n=(neurons) i_injected,i_leak,i_nmda,mNMDA,i_ampa,i_gaba,i_adapt,i_total,spike
			Make /o/n=(neurons,neurons) synapseN,synapseA,synapseI
			Make /o/n=(neurons) stateX,stateY,stateZ,stateS,Available,Unavailable,Released,Imprisoned,Paroled,Sync,Async,Async2 // The synaptic vesicle recycling states
			// Assign attributes based on phenotype
			ThresholdInc=(!phenotype) ? threshIncGlut : threshIncGABA; //The increment to the threshold set so I don't have to look up the cell phenotype.
			ThresholdTau=(!phenotype) ? threshTauGlut : threshTauGABA; //Ditto for the time constant
			AdaptInc=(!phenotype) ? adaptIncGlut : adaptIncGABA; //The increment to the threshold set so I don't have to look up the cell phenotype.
			AdaptTau=(!phenotype) ? adaptTauGlut : adaptTauGABA; //Ditto for the time constant
			tau_r=(!phenotype) ? tau_r_Glut : tau_r_GABA;
			tau_d=(!phenotype) ? tau_d_Glut : tau_d_GABA;
			tau_l=(!phenotype) ? tau_l_Glut : tau_l_GABA;
			tau_s=(!phenotype) ? tau_s_Glut : tau_s_GABA;
			mu=(!phenotype) ? mu_Glut : mu_GABA;
			
			InitThreshold=((!phenotype) ? VthreshGlut : VthreshGABA)+ThresholdVariability*threshold_stdev
			Make /o/n=(3,2) MaxSynapticStrengths={{gNMDA2Glut,gAMPA2Glut,gGABA2Glut},{gNMDA2GABA,gAMPA2GABA,gGABA2GABA}}
			synapseN=(!phenotype[p])*connectionMatrix[p][q]*maxSynapticStrengths[0][phenotype[q]]
			synapseA=(!phenotype[p])*connectionMatrix[p][q]*maxSynapticStrengths[1][phenotype[q]]
			synapseI=(phenotype[p])*connectionMatrix[p][q]*maxSynapticStrengths[2][phenotype[q]]
			MatrixTranspose synapseA // Transpose now to save time during the simulation.  
			MatrixTranspose synapseN
			MatrixTranspose synapseI
			break
		case "Start":
			SimulReverb(no_reset=0)
			break
		case "ContinueZ":
			SimulReverb(no_reset=1)
			break
	endswitch
	SetDataFolder root:
End

Function Test3525()
	Make /o/n=64 Async2Force=gnoise(1),root:Noise=(abs(enoise(1))<0.5) ? 1 : 0
	Async2Force=(gnoise(1)<0) ? Async2Force[p] : 0
End

Function SimulReverb([no_reset])
	Variable no_reset
	SetDataFolder root:Parameters
	NVar duration,delta_t,neurons,Cm,gL;
	NVar gAMPA2Glut,gNMDA2Glut,gAMPA2GABA,gNMDA2GABA,gGABA2Glut,gGABA2GABA,AMPAR_Mult
	NVar VL,VK,VGlut,VGABA,Vreset,VthreshGlut,VthreshGABA;
	NVar AlphaCa,tauCa,refractory,tau,R_input,a0,Mg;
	NVar connectGlut2Glut,connectGlut2GABA,connectGABA2Glut,connectGABA2GABA;
	NVar synDelay,propGABA;
	NVar betaCa,nCa,k1Ca,i_Ca_passive,gammaCa,CaO,eta_max,sCa,k2Ca,xi
	NVar gammaAsync2,tauAsync2,xiAsync2
	
	Wave V,deltaV,Calcium,Async2Force,Hill,CaForce,eta,facilitation,spiking,lastspike,aEPSC,nEPSC,IPSC,Noise=root:Noise
	Wave tau_r,tau_d,tau_l,tau_s,injected,Available,Unavailable,Released,Imprisoned,Paroled,Sync,Async,Async2
	Wave InitThreshold,Threshold,ThresholdInc,ThresholdTau,gAdapt,AdaptInc,AdaptTau
	Wave synapseN,synapseA,synapseI,phenotype,stateX,stateY,stateZ,stateS,mu
	Wave i_injected,i_leak,i_nmda,mNMDA,i_ampa,i_gaba,i_adapt,i_total,spike
	Variable t,numGlutSpiking,numGABAspiking,i,j,effect,time_step,start_time,end_time
	
	SetDataFolder root:
	if(!no_reset)
		V=VL;Calcium=0.05; 
		spiking=0;spike=0;lastspike=-5;effect=0;
		stateX=1;stateY=0;stateZ=0;stateS=0
		aEPSC=0;nEPSC=0;IPSC=0;
		Threshold=InitThreshold; gAdapt=0
		i_injected=0;i_leak=0;i_nmda=0;i_ampa=0;i_gaba=0;i_adapt=0;i_total=0;spike=0
		start_time=0
		// Initialize the storage of data
		Make /o/n=0 history,histSpikes,histCalcium
		Make /o/n=0 histTotal,oneCell,voltageClamp,currentClamp,histOther
	else
		NVar curr_time
		start_time=curr_time
	endif
	
	//Duplicate /o InitThreshold InitThresholdNew
	//Wave InitThreshold=InitThresholdNew
	//InitThreshold-=10
	
	// Adapt to the time step
	end_time=start_time+duration
	tau/=delta_t
	ThresholdTau/=delta_t
	AdaptTau/=delta_t
	tau_r/=delta_t
	tau_d/=delta_t
	tau_l/=delta_t
	tau_s/=delta_t
	betaCa*=delta_t
	i_Ca_passive*=delta_t
	xi*=delta_t
	tauAsync2/=delta_t
	xiAsync2*=delta_t
	
	Redimension /n=(end_time,neurons) history,histSpikes,histCalcium
	Redimension /n=(end_time) histTotal,oneCell,voltageClamp,currentClamp,histOther
	SetScale /P x,0,delta_t,history,histCalcium,histSpikes,histTotal,oneCell,voltageClamp,currentClamp,histOther
	
	// Time course of current injection into cells from patch pipette(s)
	Variable injection_current=2000,injection_start=10,injection_stop=12
	
	// The loop
	Tic()
	for(t=start_time;t<end_time;t+=delta_t)
   		// Reset
   		V=spiking ? Vreset : V; // Reset V
   		spiking=0; 
		
		// Currents
		i_injected=(p==2 && t>injection_start && t<injection_stop) ? injection_current : 0
		FastOp i_leak=(gL*VL)-(gL)*V
		FastOp i_adapt=(gAdapt*VK)-(gAdapt)*V
		mNMDA=(1+(Mg/3.57)*exp(-0.062*V)) // Taken from Jahr and Stevens.  
		i_nmda=(VGlut)*nEPSC/mNMDA-V*nEPSC/mNMDA
		FastOp i_ampa=(VGlut*AMPAR_Mult)*aEPSC-(AMPAR_Mult)*V*aEPSC
		FastOp i_gaba=(VGABA)*IPSC-V*IPSC
		i_total=i_leak+i_adapt+i_nmda+i_ampa+i_gaba+i_injected
		
		// Membrane Potential
		FastOp deltaV=(a0)*V*V-(a0)*V*Threshold-(a0*VL)*V
		FastOp deltaV=deltaV+(a0*VL)*Threshold+(R_input)*i_total
	   	deltaV[0]=0
		FastOp V=V+(1/tau)*deltaV
	   	
	   	// Spiking?
	   	V=(V>VGlut)?0:V
	      	spiking=(V>threshold);
	      	V=spiking ? 30 : V //Assign spikes and their consequences to all cells that have reached threshold
	    	lastspike=spiking ? t : lastspike; // Record time of last spike for purposes of refractory period
	 	
	 	// Adaptation
	    	Threshold=Threshold+spiking*ThresholdInc+InitThreshold/ThresholdTau-Threshold/ThresholdTau; 
	    	FastOp gAdapt=gAdapt+AdaptInc*spike-gAdapt/AdaptTau
	     
	      // Presynaptic Calcium
	      	spike=(lastspike==(t-synDelay)) // Initiate synaptic conductance after the synaptic delay time.
	      	Hill=(Calcium^nCa)/(Calcium^nCa + k1Ca^nCa)
	      	CaForce=log(CaO/Calcium)
	      	FastOp Calcium=Calcium+(i_Ca_passive)
	     	FastOp Calcium=Calcium-(betaCa)*Hill+(gammaCa)*spike*CaForce; // Increment the Calcium
	      FastOp Async2Force=Async2Force+(gammaAsync2)*spike-(1/tauAsync2)*Async2Force
	     	Noise=(abs(enoise(1))<0.001) ? 1 : 0
	     	Eta=eta_max*(Calcium^sCa)/(Calcium^sCa + k2Ca^sCa)
		
		// Synaptic resource states
	       FastOp Sync=spike*stateX; FastOp Sync=mu*Sync
	      	FastOp Async=(xi)*eta*StateX
	       FastOp Async2=Noise*Async2Force
	     	FastOp Async2=(xiAsync2)*Async2*StateX
	      	FastOp Released=Sync+Async+Async2
	      	FastOp Available=(1/tau_r)*StateZ
	      	FastOp Unavailable=(1/tau_d)*StateY
	      	FastOp Imprisoned=(1/tau_l)*StateZ
	      	FastOp Paroled=(1/tau_s)*StateS
	      FastOp StateX=StateX-Released+Available; FastOp StateX=StateX+Paroled
	      	FastOp StateY=StateY+Released-Unavailable
	      FastOp StateZ=StateZ+Unavailable-Available; FastOp StateZ=StateZ-Imprisoned
	      FastOp StateS=StateS+Imprisoned-Paroled   	
	      	
	      	// Synaptic efficacy
		MatrixOp /O aEPSC = synapseA x stateY
		MatrixOp /O nEPSC = synapseN x stateY
		MatrixOp /O IPSC = synapseI x stateY
	     
		// Store history
		time_step=round(t/delta_t)
		history[time_step][]=V[q]; 
		histCalcium[time_step][]=calcium[q];
		histSpikes[time_step][]=spike[q]
		histTotal[time_step]=1000*sum(spike)/neurons
		histOther[time_step]=Async2[7]
		voltageClamp[time_step]=-i_total[0]
	endfor
	print Toc()
	Variable /G curr_time=t
	
	// Reset time constants back to a time step of 1
	tau*=delta_t
	ThresholdTau*=delta_t
	AdaptTau*=delta_t
	tau_r*=delta_t
	tau_d*=delta_t
	betaCa/=delta_t
	i_Ca_passive/=delta_t
	xi/=delta_t
	
	// Add a baseline at the beginning
	Wave currentClamp
	currentClamp = history(x)[7]
	InsertPoints /M=0 0,round(100/delta_t),histOther,histTotal,voltageClamp,currentClamp
	//Make /o/n=(round(end_time/10),neurons) raster
	//SetScale /P x,0,delta_t*10,raster
	//raster=sum(histSpike,x-delta_t*5,x+delta_t+4)
	currentClamp[0,round(100/delta_t)-1]=VL
	
	// Display the results
	Smooth round(5/delta_t),histTotal
	
//	if(IsEmptyString(WinList("WaterfallPlot",";","")))
//		NewWaterfall /W=(1,1,300,200)/K=1/N=WaterfallPlot history
//		Label left "mV"
//		Label right "Neuron #"
//		ModifyGraph lblRot(right)=90
//		ModifyGraph zColor(history)={history,*,*,Rainbow}
//		ModifyWaterfall angle=45
//	endif
//	if(IsEmptyString(WinList("CalciumPlot",";","")))
//		NewWaterfall /W=(301,1,600,200)/K=1/N=CalciumPlot histCalcium
//		Label left "Calcium Concentration (µM)"
//		Label right "Neuron #"
//		ModifyGraph lblRot(right)=90
//		ModifyGraph zColor(histCalcium)={histCalcium,*,*,Grays}
//		ModifyWaterfall angle=45
//	endif
	if(IsEmptyString(WinList("RasterPlot",";","")))
		Wave raster=histSpikes
		Display /W=(0,0,400,250) /K=1/N=RasterPlot
		AppendImage raster
		Label left "Neuron #"
	endif
	if(strlen(WinList("ExamplePlots",";",""))==0)
		Display /W=(0,0,400,400)/K=1/N=ExamplePlots
		AppendToGraph /L=SpikeRate histTotal
		AppendToGraph /L=IClamp currentClamp
		AppendToGraph /L=VClamp voltageClamp
		Label VClamp "pA"
		Label IClamp "mV"
		Label SpikeRate "Spikes/s"
		Label bottom "s"
		ModifyGraph prescaleExp(bottom)=-3
		SetAxis VClamp,-1000,0
		ModifyGraph axisEnab(SpikeRate)={0,0.31}, axisEnab(IClamp)={0.33,0.64}, axisEnab(VClamp)={0.66,1}
		ModifyGraph freePos(SpikeRate)={0,bottom}, freePos(IClamp)={0,bottom}, freePos(VClamp)={0,bottom}
		ModifyGraph axisEnab(bottom)={0.1,1},btLen=2
		ModifyGraph lblPos(SpikeRate)=45,lblPos(IClamp)=45,lblPos(VClamp)=45
	endif
	SetDataFolder root:
End

Function SimulReverbOld2([no_reset,AMPAR_Mult])
	Variable no_reset,AMPAR_Mult // AMPAR_Mult will be the fraction of AMPAR current allowed to remain.  
	AMPAR_Mult=ParamIsDefault(AMPAR_Mult) ? 1 : AMPAR_Mult
	NVar duration,delta_t,neurons,Cm,gL;
	NVar gAMPA2Glut,gNMDA2Glut,gAMPA2GABA,gNMDA2GABA
	NVar gGABA2Glut,gGABA2GABA,VL,VK,VGlut,VGABA,Vreset,VthreshGlut,VthreshGABA;
	NVar AlphaCa,tauCa,refractory,tau,R_input,a0,Mg;
	NVar connectGlut2Glut,connectGlut2GABA,connectGABA2Glut,connectGABA2GABA;
	NVar synDelay,propGABA;
	NVar betaCa,nCa,k1Ca,i_Ca_passive,gammaCa,CaO,eta_max,sCa,k2Ca,xi
	Wave V,deltaV,Calcium,Hill,CaForce,eta,facilitation,spiking,lastspike,aEPSC,nEPSC,IPSC
	Wave tau_r,tau_d,injected,Available,Unavailable,InUse
	Wave InitThreshold,Threshold,ThresholdInc,ThresholdTau,gAdapt,AdaptInc,AdaptTau
	Wave synapseN,synapseA,synapseI,phenotype,stateX,stateY,stateZ,stateS,mu
	Wave i_injected,i_leak,i_nmda,mNMDA,i_ampa,i_gaba,i_adapt,i_total,spike
	Variable t,numGlutSpiking,numGABAspiking,i,j,effect
	if(!no_reset)
		V=VL;Calcium=0.05; 
		spiking=0;spike=0;lastspike=-5;effect=0;
		stateX=1;stateY=0;stateZ=0;stateS=0
		aEPSC=0;nEPSC=0;IPSC=0;
		Threshold=InitThreshold; gAdapt=0
		i_injected=0;i_leak=0;i_nmda=0;i_ampa=0;i_gaba=0;i_adapt=0;i_total=0;spike=0 
	endif
	
	// Set new values
	duration=5000
	delta_t=1
	tau_r=300
	ThresholdInc=10//5//10
	ThresholdTau=200
	betaCa=0.005
	adaptInc=0//2
	adaptTau=50
	AMPAR_Mult=1
	a0=0.1
	eta_max=0.5
	sCa=1
	k2Ca=0.5
	mu=0.2
	//Duplicate /o InitThreshold InitThresholdNew
	//Wave InitThreshold=InitThresholdNew
	//InitThreshold-=10
	
	Variable /G theEnd=round(duration/delta_t); 
	Make /o/n=(theEnd,neurons) history,histCalcium,raster
	Make /o/n=(theEnd) histTotal,oneCell,voltageClamp,currentClamp,histOther
	// Time course of current injection into cells from patch pipette(s)
	Variable injection_current=2000,injection_start=10,injection_stop=12
	
	// The loop
	for(t=0;t<theEnd;t+=delta_t)
   		// Reset
   		V=spiking ? Vreset : V; // Reset V
   		spiking=0; 
		
		// Currents
		i_injected=(p>=2&&p<=9&&t>injection_start&&t<injection_stop) ? injection_current : 0
		FastOp i_leak=(gL*VL)-(gL)*V
		FastOp i_adapt=(gAdapt*VK)-(gAdapt)*V
		mNMDA=(1+(Mg/3.57)*exp(-0.062*V))
		i_nmda=(VGlut)*nEPSC/mNMDA-V*nEPSC/mNMDA
		FastOp i_ampa=(VGlut*AMPAR_Mult)*aEPSC-(AMPAR_Mult)*V*aEPSC
		FastOp i_gaba=(VGABA)*IPSC-V*IPSC
		i_total=i_leak+i_adapt+i_nmda+i_ampa+i_gaba+i_injected
		
		// Membrane Potential
		FastOp deltaV=(a0/tau)*V*V-(a0/tau)*V*Threshold-(a0*VL/tau)*V
		FastOp deltaV=deltaV+(a0*VL/tau)*threshold+(R_input/tau)*i_total
	   	deltaV[0]=0
		FastOp V=V+deltaV
	   	
	   	// Spiking?
	   	V=(V>VGlut)?0:V
	      	spiking=(V>threshold);
	      	V=spiking ? 30 : V //Assign spikes and their consequences to all cells that have reached threshold
	    	lastspike=spiking ? t : lastspike; // Record time of last spike for purposes of refractory period
	 	
	 	// Adaptation
	    	Threshold=Threshold+spiking*ThresholdInc+InitThreshold/ThresholdTau-Threshold/ThresholdTau; 
	    	FastOp gAdapt=gAdapt+AdaptInc*spike-gAdapt/AdaptTau
	     
	      // Presynaptic Calcium
	      	spike=(lastspike==(t-synDelay)) // Initiate synaptic conductance after the synaptic delay time.
	      	Hill=(Calcium^nCa)/(Calcium^nCa + k1Ca^nCa)
	      	CaForce=log(CaO/Calcium)
	      	FastOp Calcium=Calcium+(i_Ca_passive)
	     	FastOp Calcium=Calcium-(betaCa)*Hill+(gammaCa)*spike*CaForce; // Increment the Calcium
	      	Eta=eta_max*(Calcium^sCa)/(Calcium^sCa + k2Ca^sCa)
		
		// Synaptic resource states
	      	FastOp InUse=(mu)*spike*stateX+(xi)*eta*StateX
	      	FastOp Available=(1/tau_r)*stateZ
	      	FastOp Unavailable=(1/tau_d)*StateY
	      	FastOp StateX=StateX-InUse+Available
	      	FastOp StateY=StateY+InUse-Unavailable
	      	FastOp StateZ=StateZ+Unavailable-Available
	      	
	      	// Synaptic efficacy
		MatrixOp /O aEPSC = synapseA x stateY
		MatrixOp /O nEPSC = synapseN x stateY
		MatrixOp /O IPSC = synapseI x stateY
	     
		// Store history
		history[t][]=V[q]; 
		histCalcium[t][]=calcium[q];
		histTotal[t]=1000*sum(spike)/neurons
		histOther[t]=Eta[7]///neurons // i_leak+i_adapt+i_nmda+i_ampa+i_gaba+i_injected
		voltageClamp[t]=-i_total[0]
	endfor
	
	// Add a baseline at the beginning
	Wave currentClamp
	currentClamp = history[p][7]
	Wave raster
	raster=(history==30)
	InsertPoints 0,round(100/delta_t),histOther,histTotal,voltageClamp,currentClamp
	currentClamp[0,round(100/delta_t)-1]=VL
	
	// Display the results
	Smooth 5,histTotal
	Wave raster
	
//	if(IsEmptyString(WinList("WaterfallPlot",";","")))
//		NewWaterfall /W=(1,1,300,200)/K=1/N=WaterfallPlot history
//		Label left "mV"
//		Label right "Neuron #"
//		ModifyGraph lblRot(right)=90
//		ModifyGraph zColor(history)={history,*,*,Rainbow}
//		ModifyWaterfall angle=45
//	endif
//	if(IsEmptyString(WinList("CalciumPlot",";","")))
//		NewWaterfall /W=(301,1,600,200)/K=1/N=CalciumPlot histCalcium
//		Label left "Calcium Concentration (µM)"
//		Label right "Neuron #"
//		ModifyGraph lblRot(right)=90
//		ModifyGraph zColor(histCalcium)={histCalcium,*,*,Grays}
//		ModifyWaterfall angle=45
//	endif
//	if(IsEmptyString(WinList("RasterPlot",";","")))
//		NewImage /K=1/N=RasterPlot raster
//		Label left "Neuron #"
//	endif
	if(strlen(WinList("ExamplePlots",";",""))==0)
		Display /W=(1,250,200,525)/K=1/N=ExamplePlots
		AppendToGraph /L=SpikeRate histTotal
		AppendToGraph /L=IClamp currentClamp
		AppendToGraph /L=VClamp voltageClamp
		Label VClamp "pA"
		Label IClamp "mV"
		Label SpikeRate "Spikes/s"
		Label bottom "ms"
		SetAxis VClamp,-1000,0
		ModifyGraph axisEnab(SpikeRate)={0,0.31}, axisEnab(IClamp)={0.33,0.64}, axisEnab(VClamp)={0.66,1}
		ModifyGraph freePos(SpikeRate)={0,bottom}, freePos(IClamp)={0,bottom}, freePos(VClamp)={0,bottom}
		ModifyGraph axisEnab(bottom)={0.05,1},btLen=2
	endif
End

Function SimulReverbOld([no_reset,AMPAR_Mult])
	Variable no_reset,AMPAR_Mult
	NVar duration,delta_t,neurons,Cm,gL;
	NVar gAMPA2Glut,gNMDA2Glut,gAMPA2GABA,gNMDA2GABA
	NVar gGABA2Glut,gGABA2GABA,VL,VK,VGlut,VGABA,Vreset,VthreshGlut,VthreshGABA;
	NVar AlphaCa,tauCa,refractory,tau,R_input,a0,Mg;
	NVar connectGlut2Glut,connectGlut2GABA,connectGABA2Glut,connectGABA2GABA;
	NVar synDelay,propGABA;
	NVar betaCa,nCa,k1Ca,i_Ca_passive,gammaCa,CaO,eta_max,sCa,k2Ca,xi
	Wave V,Calcium,eta,facilitation,spiking,lastspike,aEPSC,nEPSC,IPSC
	Wave tau_r,tau_d,injected
	Wave InitThreshold,Threshold,ThresholdInc,ThresholdTau,gAdapt,AdaptInc,AdaptTau
	Wave synapseN,synapseA,synapseI,phenotype,stateX,stateY,stateZ,stateS,mu
	Wave i_injected,i_leak,i_nmda,i_ampa,i_gaba,i_adapt,i_total,spike
	Variable t,numGlutSpiking,numGABAspiking,i,j,effect
	if(!no_reset)
		V=VL;Calcium=0.05; 
		spiking=0;spike=0;lastspike=-5;effect=0;
		stateX=1;stateY=0;stateZ=0
		aEPSC=0;nEPSC=0;IPSC=0;
		Threshold=InitThreshold; gAdapt=0
		i_injected=0;i_leak=0;i_nmda=0;i_ampa=0;i_gaba=0;i_adapt=0;i_total=0;spike=0 
	endif
	
	// Set new values
	duration=5000
	delta_t=1
	//tau_r=400
	ThresholdInc=10//5//10
	ThresholdTau=200
	betaCa=0.005
	adaptInc=0//2
	adaptTau=50
	AMPAR_Mult=-1.5
	//mu=0.3
	
	Variable /G theEnd=round(duration/delta_t); 
	Make /o/n=(theEnd,neurons) history,histCalcium,raster
	Make /o/n=(theEnd) histTotal,oneCell,voltageClamp,currentClamp
	// Time course of current injection into cells from patch pipette(s)
	Variable injection_current=2000,injection_start=10,injection_stop=12
	
	// The loop
	for(t=0;t<theEnd;t+=delta_t)
   		// Reset
   		V=spiking ? Vreset : V; // Reset V
   		spiking=0; 
		
		// Currents
		i_injected=(p>=2&&p<=9&&t>injection_start&&t<injection_stop) ? injection_current : 0
		i_leak=gL*(VL-V)
		i_adapt=gAdapt*(VK-V)
		i_nmda=(VGlut-V)*(1/(1+(Mg/3.57)*exp(-0.062*V)))*nEPSC
		i_ampa=(VGlut-V)*aEPSC*(1-AMPAR_Mult)
		i_gaba=(VGABA-V)*IPSC
		i_total=i_leak+i_adapt+i_nmda+i_ampa+i_gaba+i_injected
		
	      // Membrane Potential
	      V+=(p==0)?0:((a0*(V-VL)*(V-threshold)+R_input*i_total)/tau)  
	     
	      
	      	// Spiking? 
	      	V=(V>VGlut)?0:V
	      	spiking=(V>threshold);
	      	V=spiking ? 30 : V //Assign spikes and their consequences to all cells that have reached threshold
	    	lastspike=spiking ? t : lastspike; // Record time of last spike for purposes of refractory period

	    	// Adaptation
	    	Threshold+=spiking*ThresholdInc+(InitThreshold-Threshold)/ThresholdTau; 
	    	gAdapt+=(spike*AdaptInc)-(gAdapt/AdaptTau)
	     
	      // Presynaptic calcium
	      	spike=(lastspike==(t-synDelay)) // Initiate synaptic conductance after the synaptic delay time.
	      	Calcium+=-(betaCa*(Calcium^nCa))/(Calcium^nCa+k1Ca^nCa)+i_Ca_passive+spike*gammaCa*log(CaO/Calcium); // Increment the Calcium
	      	Eta=eta_max*(Calcium^sCa/(Calcium^sCa + k2Ca^sCa))
	      	
	      	// Synaptic resource states
	      	StateX+=(stateZ/tau_r)+(-spike*mu*stateX)+(-eta*xi*stateX)
	      	StateY+=(-stateY/tau_d)+(spike*mu*stateX)+(eta*xi*stateX)
	      	StateZ+=(stateY/tau_d)+(-stateZ/tau_r)
		
		// Synaptic efficacy
		MatrixOp /O aEPSC = synapseA x stateY
		MatrixOp /O nEPSC = synapseN x stateY
		MatrixOp /O IPSC = synapseI x stateY

		// Store history
		history[t][]=V[q]; 
		histCalcium[t][]=calcium[q];
		histTotal[t]=1000*sum(spike)/neurons
		voltageClamp[t]=-i_total[0]
	endfor
	
	// Add a baseline at the beginning
	Wave currentClamp
	currentClamp = history[p][7]
	Wave raster
	raster=(history==30)
	InsertPoints 0,round(100/delta_t),histTotal,voltageClamp,currentClamp
	currentClamp[0,round(100/delta_t)-1]=VL
	
	// Display the results
	Smooth 5,histTotal
	Wave raster
	
//	if(IsEmptyString(WinList("WaterfallPlot",";","")))
//		NewWaterfall /W=(1,1,300,200)/K=1/N=WaterfallPlot history
//		Label left "mV"
//		Label right "Neuron #"
//		ModifyGraph lblRot(right)=90
//		ModifyGraph zColor(history)={history,*,*,Rainbow}
//		ModifyWaterfall angle=45
//	endif
//	if(IsEmptyString(WinList("CalciumPlot",";","")))
//		NewWaterfall /W=(301,1,600,200)/K=1/N=CalciumPlot histCalcium
//		Label left "Calcium Concentration (µM)"
//		Label right "Neuron #"
//		ModifyGraph lblRot(right)=90
//		ModifyGraph zColor(histCalcium)={histCalcium,*,*,Grays}
//		ModifyWaterfall angle=45
//	endif
//	if(IsEmptyString(WinList("RasterPlot",";","")))
//		NewImage /K=1/N=RasterPlot raster
//		Label left "Neuron #"
//	endif
	if(strlen(WinList("ExamplePlots",";",""))==0)
		Display /W=(1,250,200,525)/K=1/N=ExamplePlots
		AppendToGraph /L=SpikeRate histTotal
		AppendToGraph /L=IClamp currentClamp
		AppendToGraph /L=VClamp voltageClamp
		Label VClamp "pA"
		Label IClamp "mV"
		Label SpikeRate "Spikes/s"
		Label bottom "ms"
		SetAxis VClamp,-1000,0
		ModifyGraph axisEnab(SpikeRate)={0,0.31}, axisEnab(IClamp)={0.33,0.64}, axisEnab(VClamp)={0.66,1}
		ModifyGraph freePos(SpikeRate)={0,bottom}, freePos(IClamp)={0,bottom}, freePos(VClamp)={0,bottom}
		ModifyGraph axisEnab(bottom)={0.05,1},btLen=2
	endif
End

Function Test4835()
	Wave synapseA
	Variable i,j,k,l,total=0
	for(i=0;i<10;i+=1)
	for(j=0;j<10;j+=1)
	for(k=0;k<10;k+=1)
	for(l=0;l<10;l+=1)
		if(SynapseA[i][j][k][l]!=0)
			total+=1
		endif
	endfor
	endfor
	endfor
	endfor
	print total
End

  