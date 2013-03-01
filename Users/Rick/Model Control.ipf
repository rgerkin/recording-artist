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
		SetVariable /Z $variable_name,size={150,20},title=variable_name,limits={-inf,inf,inc},value=root:parameters:$variable_name,proc=ModelControlSetVariables
		SetVariable /Z $variable_name userData=num2str(var),userData(parameter)="1"
	endfor
	if(mod(i,2)==1)
		Button Dummy, disable=3, size={150,20}, title=" "
	endif
	Button ResetParameters,size={150,20},proc=ModelControlProc,title="Reset to Parameter Defaults"
	Button RegenerateNetwork,size={150,20},proc=ModelControlProc,title="Regenerate Network"
	Button Start,size={150,20},proc=ModelControlProc,title="Start"
	Button ContinueZ,size={150,20},proc=ModelControlProc,title="Continue"
End

Function ModelControlSetVariables(info) : SetVariableControl
	Struct WMSetVariableAction &info
	strswitch(info.ctrlName) // The name of the variable:  
//		case "var1": // The name of one variable.  
//			break
		default:
			break
	endswitch
	ModelControlButtons("RegenerateWaves")
End

Function ModelControlButtons(ctrlName) : ButtonControl
	String ctrlName
	
	NewDataFolder /O/S root:Parameters
	//print ctrlName
	if(!StringMatch(ctrlName,"ResetParameters"))
		NVar neurons,duration,delta_t,tau_d, tau_r,tau_l,tau_s,mu,Cm,gL,tau,R_input,a0
		NVar gAMPA,AMPAR_mult,v_L,v_glut,v_reset,refractory,syn_delay
		NVar connect_prob,v_thresh,threshold_stdev,thresh_inc,thresh_tau
		NVar beta_Ca,nCa,k1Ca,i_Ca_passive,ca_rest,gamma_Ca,eta_max,sCa,k2Ca,CaO,xi
		NVar stimuli,interval1,interval2
	endif
	
	strswitch(ctrlName)
		case "ResetParameters":
			Variable /G neurons=64,duration=5000,delta_t=1
			// Synaptic decay constant and time constant of recovery of vesicles to the active pool.  
			Variable /G tau_d=10, tau_r=300
			Variable /G tau_l=5000, tau_s=10000
			Variable /G mu=0.35
			// Membrane time constant, leak conductance, AHP conductance for each cell type
			Variable /G tau=10, R_input=0.5, a0=0.1
			// Synaptic conductances for each cell type; basically just two time constants for a general synaptic conductance
			Variable /G gAMPA=10
			Variable /G AMPAR_mult=1 // A multiplier for the AMPAR current, e.g. 0.5 would correspond to 50% AMPAR_Mult.  
			// Reversal Vs, reset V, and thresholds
			Variable /G v_L=-70, v_glut=0, v_reset=-70
			// An absolute refractory period and a synaptic delay
			Variable /G refractory=0, syn_delay=2;
			// A connectivity ratio, e.g. only 30% of the cell pairs will even be connected (subject to the exponential distribution).  
			Variable /G connect_prob=0.2
			// This is actual firing rate adaptation, the threshInc's are the increment by which the firing threshold is incremented.  
			// The taus are the rate at which this increase in the threshold decays. 
			Variable /G v_thresh=-40, threshold_stdev=0;
			Variable /G thresh_inc=10, thresh_tau=200
			// Set all the phenotypes of the cells, excitatory or inhibitory. 
			Variable /G ca_rest=0.05,beta_Ca=0.005,nCa=2,k1Ca=0.4,i_Ca_passive=0//15
			Variable /G gamma_Ca=0.125,eta_max=0.3,sCa=4,k2Ca=0.4,caO=2000,xi=0.02
			Variable /G buffer_cap=100,buffer_off=0.000025,buffer_clear=0.00005
			// Set the stimulation protocol
			Variable /G stimuli=1,interval1=100,interval2=30000 // #, ms, ms
			ModelControlButtons("RegenerateWaves")
			break
		case "RegenerateNetwork":
			Make /o/n=(neurons) ThresholdVariability=gnoise(1); //The baseline value of the firing threshold, randomized for each cell around a mean value.   
			Make /o/n=(neurons,neurons) ConnectionMatrix=(abs(enoise(1))<connect_prob); // Generate connection strengths (to be multiplied by conductances). 
			ConnectionMatrix*=ExpNoise(1) // Added 2007.12.12.2347
			ModelControlButtons("RegenerateWaves")
			break
		case "RegenerateWaves":
			Make /o/n=(neurons,neurons) SynapseQ,ConnectionMatrix
			Make /o/n=(neurons) V,deltaV,Calcium,Hill,CaForce,Eta,Spiking,Lastspike,EPSC,Buffered,Buffer
			Make /o/n=(neurons) InitThreshold,Threshold
			Make /o/n=(neurons) I_injected,I_ampa,I_total,Spike
			Make /o/n=(neurons) StateX,StateY,StateZ,StateS,Available,Unavailable,Released,Imprisoned,Paroled,Sync,Async // The synaptic vesicle recycling states
			
			InitThreshold=v_thresh + gnoise(threshold_stdev)
			SynapseQ=gAMPA*ConnectionMatrix[p][q]
			MatrixTranspose SynapseQ // Transpose now to save time during the simulation.  
			break
		case "Start":
			Simulate(reset=1)
			break
		case "ContinueZ":
			Simulate(reset=0)
			break
	endswitch
	SetDataFolder root:
End

Function Simulate([reset])
	variable reset
	
	SetDataFolder root:Parameters
	NVar neurons,duration,delta_t,tau_d, tau_r,tau_l,tau_s,mu,Cm,tau,R_input,a0
	NVar gAMPA,AMPAR_mult,v_L,v_glut,v_reset,refractory,syn_delay
	NVar connect_prob,v_thresh,threshold_stdev,thresh_inc,thresh_tau
	NVar beta_Ca,nCa,k1Ca,i_Ca_passive,ca_rest,gamma_Ca,eta_max,sCa,k2Ca,CaO,xi
	NVar buffer_cap,buffer_off,buffer_clear
	NVar stimuli,interval1,interval2
	
	Wave V,deltaV,Calcium,Hill,CaForce,Eta,Spiking,lastspike,EPSC,Buffered,Buffer
	Wave Available,Unavailable,Released,Imprisoned,Paroled,Sync,Async
	Wave InitThreshold,Threshold
	Wave SynapseQ,StateX,StateY,StateZ,StateS
	Wave I_injected,I_ampa,I_total,Spike
	
	Variable t=0,num_spiking,i,j,time_step,start_time,end_time
	
	SetDataFolder root:
	if(reset)
		V=v_L; Calcium=Ca_rest; Buffered=0
		Spiking=0; Spike=0; Lastspike=-5; Threshold=InitThreshold
		StateX=1; stateY=0; stateZ=0; stateS=0; EPSC=0; Eta=0; Sync=0; Async=0
		I_injected=0;I_ampa=0;I_total=0
		start_time=0
		
		// Initialize the storage of data
		Make /o/n=0 history,histSpikes,histCalcium,histBuffered
		Make /o/n=0 histTotal,oneCell,voltageClamp,currentClamp,histOther,histOther2
	else
		NVar curr_time
		start_time=curr_time
	endif
	
	end_time=start_time+duration
	
	// Adapt to the time step
	tau/=delta_t
	thresh_tau/=delta_t
	tau_r/=delta_t
	tau_d/=delta_t
	tau_l/=delta_t
	tau_s/=delta_t
	beta_Ca*=delta_t
	i_Ca_passive*=delta_t
	xi*=delta_t
	
	//Redimension /n=(end_time,neurons) history,histSpikes,histCalcium
	Redimension /n=(end_time) histTotal,oneCell,voltageClamp,currentClamp,histOther,histOther2,histBuffered
	SetScale /P x,0,delta_t/1000,history,histCalcium,histSpikes,histTotal,oneCell,voltageClamp,currentClamp,histOther,histOther2,histBuffered
	
	// Time course of current injection into cells from patch pipette(s)
	Variable stim_time,injection_current=2000,injection_start=300,injection_width=1
	Make /o/n=(end_time/delta_t) CurrentInjection=0
	SetScale x,0,end_time,CurrentInjection
	
	Do
		for(i=0;i<stimuli;i+=1)
			stim_time=t+injection_start+i*interval1
			if(stim_time>=end_time)
				break
			endif
			CurrentInjection[x2pnt(CurrentInjection,stim_time),x2pnt(CurrentInjection,stim_time+injection_width)-1]=injection_current
		endfor
		t+=interval2
	While(t<end_time)
	
	// The loop
	for(t=start_time;t<end_time;t+=delta_t)
		//UpdateProgressWin(frac=t/end_time)
   		// Reset
   		V=Spiking ? v_reset : V; // Reset V
   		Spiking=0; 
		
		// Currents
		i_injected=(p==2) ? CurrentInjection(t) : 0
		FastOp i_ampa=(v_glut*AMPAR_Mult)*EPSC-(AMPAR_Mult)*V*EPSC
		FastOp i_total=i_ampa+i_injected
		
		// Membrane Potential; Quadratic Integrate and Fire dynamics
		FastOp deltaV=(a0)*V*V-(a0)*V*Threshold-(a0*v_L)*V
		FastOp deltaV=deltaV+(a0*v_L)*Threshold+(R_input)*I_total 
	   	deltaV[0]=0
		FastOp V=V+(1/tau)*deltaV
	   	
	   	// Spiking?
	   	V=(V>v_glut) ? 0 : V
	      	Spiking=(V>Threshold)
	      	V=Spiking ? 30 : V //Assign spikes and their consequences to all cells that have reached threshold
	    	lastspike=Spiking ? t : lastspike; // Record time of last spike for purposes of refractory period
	 	
	 	// Adaptation
	    	FastOp Threshold=Threshold + (1/thresh_tau)*InitThreshold - (1/thresh_tau)*Threshold 
	     	FastOp Threshold=Threshold + (thresh_inc)*spiking 
	     
	      // Presynaptic Calcium
	      	spike=(lastspike==(t-syn_delay)) // Initiate synaptic conductance after the synaptic delay time.
	      	Hill=((Calcium-Ca_rest)^nCa)/((Calcium-Ca_rest)^nCa + k1Ca^nCa)
	      	CaForce=log(CaO/Calcium)
	      	FastOp Calcium=Calcium+(i_Ca_passive)
	      	FastOp Buffer=(beta_Ca)*Hill - (beta_Ca/buffer_cap)*Hill*Buffered - (buffer_off)*Buffered// = beta*Hill*(1-buffered/buffer_cap)
	     	FastOp Calcium=Calcium-Buffer+(gamma_Ca)*spike*CaForce; // Increment the Calcium
	     	FastOp Buffered=Buffered+Buffer-(buffer_clear)*Buffered
	     	Eta=eta_max*(Calcium^sCa)/(Calcium^sCa + k2Ca^sCa)
		
		// Synaptic resource states
	       FastOp Sync=(mu)*Spike*StateX
	      	FastOp Async=(xi)*Eta*StateX
	     
	      	FastOp Released=Sync+Async
	      Released=BinomialNoise(100,Released)/100 // Used to make stochastic values in 1/100ths of the total resources.  
	      Released=Released>StateX ? StateX : Released
	      
	      	FastOp Available=(1/tau_r)*StateZ
	      	FastOp Unavailable=(1/tau_d)*StateY
	      	FastOp Imprisoned=(1/tau_l)*StateZ
	      	FastOp Paroled=(1/tau_s)*StateS
	      
	      FastOp StateX=StateX-Released+Available; FastOp StateX=StateX+Paroled
	      	FastOp StateY=StateY+Released-Unavailable
	      FastOp StateZ=StateZ+Unavailable-Available; FastOp StateZ=StateZ-Imprisoned
	      FastOp StateS=StateS+Imprisoned-Paroled   	
	      
	      	// Synaptic efficacy
		MatrixOp /O EPSC = SynapseQ x StateY
	     
		// Store history
		time_step=round(t/delta_t)
		history[time_step][]=V[q]; 
		histCalcium[time_step][]=calcium[q];
		histSpikes[time_step][]=Spike[q]
		histTotal[time_step]=1000*sum(spike)/neurons
		histOther[time_step]=mean(Eta)
		histOther2[time_step]=mean(StateX)
		histBuffered[time_step]=Buffered[2]
		VoltageClamp[time_step]=-I_total[0]
		CurrentClamp[time_step]=V[2]
		//if(V_Progress)
		//	break
		//endif
	endfor
	//Toc()
	Variable /G curr_time=t
	
	// Reset time constants back to a time step of 1
	tau*=delta_t
	thresh_tau*=delta_t
	tau_r*=delta_t
	tau_d*=delta_t
	tau_r*=delta_t
	tau_s*=delta_t
	beta_Ca/=delta_t
	i_Ca_passive/=delta_t
	xi/=delta_t
	
	// Adapt to the time step
	tau/=delta_t
	thresh_tau/=delta_t
	tau_r/=delta_t
	tau_d/=delta_t
	
	Wave CurrentClamp
	//CurrentClamp = history(x)[7]
	// Add a baseline at the beginning
//	if(start_time==0)
//		InsertPoints /M=0 0,round(100/delta_t),histOther,histTotal,voltageClamp,currentClamp
//		//Make /o/n=(round(end_time/10),neurons) raster
//		//SetScale /P x,0,delta_t*10,raster
//		//raster=sum(histSpike,x-delta_t*5,x+delta_t+4)
//		currentClamp[0,round(100/delta_t)-1]=v_L	
//	endif
	
	// Display the results
	Duplicate /o histTotal histTotal2
	Smooth round(5/delta_t),histTotal2
	
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
//		Wave raster=histSpikes
//		Display /W=(0,0,400,250) /K=1/N=RasterPlot
//		AppendImage raster
//		Label left "Neuron #"
//	endif
	if(strlen(WinList("ExamplePlots",";",""))==0)
		Display /W=(0,0,400,400)/K=1/N=ExamplePlots
		AppendToGraph /L=SpikeRate histTotal2
		AppendToGraph /L=IClamp currentClamp
		AppendToGraph /L=VClamp voltageClamp
		Label VClamp "pA"
		Label IClamp "mV"
		Label SpikeRate "Spikes/s"
		Label bottom "s"
		//ModifyGraph prescaleExp(bottom)=-3
		SetAxis VClamp,-1000,0
		ModifyGraph axisEnab(SpikeRate)={0,0.31}, axisEnab(IClamp)={0.33,0.64}, axisEnab(VClamp)={0.66,1}
		ModifyGraph freePos(SpikeRate)={0,bottom}, freePos(IClamp)={0,bottom}, freePos(VClamp)={0,bottom}
		ModifyGraph axisEnab(bottom)={0.1,1},btLen=2
		ModifyGraph lblPos(SpikeRate)=45,lblPos(IClamp)=45,lblPos(VClamp)=45
	endif
	SetDataFolder root:
End