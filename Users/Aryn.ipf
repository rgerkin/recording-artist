#pragma rtGlobals=1		// Use modern global access method.

#ifdef Acq
#include "Spike Functions"
#include "Waves Average"
#include "Minis"

override function MakeLogPanel()
        if(WinType("LogPanel"))
                DoWindow /F LogPanel
                return 0
        else
                NewNotebook/W=(600,570,940,710) /F=0/N=LogPanel
        endif
end
        
function StimulusTable()
	dowindow /k StimTable
	edit /k=1/n=StimTable as "Stimulus Table"
	variable num_channels = GetNumChannels() // Number of channels.  
	variable curr_sweep = GetCurrSweep() // Current sweep number.  
	make /o/n=(curr_sweep,num_channels) StimulusAmplitudes
	variable i,j,k
	// This part could be done in one line except for the labeling of the table.  
	for(i=0;i<curr_sweep;i+=1)
		setdimlabel 0,i,$("Sweep "+num2str(i)) StimulusAmplitudes
		for(j=0;j<num_channels;j+=1)
			setdimlabel 1,j,$GetChanLabel(j) StimulusAmplitudes
			wave ampl = GetAmpl(j,sweepNum=i)
			wave livePulseSets = GetLivePulseSets(j,sweepNum=i)
			variable result = 0
			for(k=0;k<numpnts(livePulseSets);k+=1)
				result += ampl[livePulseSets[k]]
			endfor
			StimulusAmplitudes[i][j] = result
		endfor
	endfor
	make /o/n=(curr_sweep) StimulusAmpls_0 = StimulusAmplitudes[p][0]
	make /o/n=(curr_sweep) StimulusAmpls_1 = StimulusAmplitudes[p][1]
	appendtotable StimulusAmpls_0//,StimulusAmpls_1
end

function DoIhStuff(chan)
	variable chan
	
	variable i,sweepNum
	variable first = GetCursorSweepNum("A")
	variable last = GetCursorSweepNum("B")
	string list = ""
	dfref df=Core#InstanceHome("Acq","sweepsWin","win0")
	wave /sdfr=df SelWave
	for(sweepNum=first;sweepNum<=last;sweepNum+=1)
		if(SelWave[sweepNum][chan] & 16)
			variable ampl = GetEffectiveAmpl(chan,sweepNum=sweepNum)
			wave w = GetChanSweep(chan,sweepNum)
			string name = "Ih_average_"+num2str(ampl)
			wave /z avg = $CleanupName(name,0)
			if(!waveexists(avg))
				make /o/n=(numpnts(w)) $CleanupName(name,0) /wave=avg=0
			endif
			if(whichlistitem(name,list)<0)
				avg=0
				note /k avg, ""
				list += name+";"
			endif
			avg += w[p]
			note /nocr avg, "X"
		endif
	endfor
	display /k=1
	for(i=0;i<itemsinlist(list);i+=1)
		name = stringfromlist(i,list)
		wave avg = $CleanupName(name,0)
		string the_note = note(avg)
		avg /= strlen(the_note)
		colortab2wave rainbow
		wave m_colors
		setscale x,0,1,m_colors
		variable red = m_colors(i/itemsinlist(list))[0]
		variable green = m_colors(i/itemsinlist(list))[1]
		variable blue = m_colors(i/itemsinlist(list))[2]
		appendtograph /c=(red,green,blue) avg
	endfor
end

//This procedure file keeps track of all custom preferences.  In general, these preferences are 
//user entered parameters in dialog boxes.  Managing preferences this way causes dialog box
//values to be preserved, even when Igor is turned off.  See the Igor manual for more information
//on LoadPackagePreferences, SavePackagePreferences etc.

	static StrConstant kPackageName = "Salk SNL-D Igor Package"
	static StrConstant kPreferencesFileName = "Salk SNL-D Custom Igor Prefs"
	static constant MAX_STRING =100  //This should be 128 to match the data file.  Igor 5.05A does not allow structures with arrays of length > 100.  BAD IGOR.  BAAAAD IGOR.
	static constant MAX_SEGMENTS = 4
	
	//Amplifier settings
	constant NONE = 0;
	constant AXOCLAMP2B = 1;
 	constant AXOPATCH200B = 2;
	constant MULTICLAMP = 3;

	
	//Acquisition Tags
	static constant AMPLIFIER_TAG = 0
//	static constant SPONTANEOUS_TAG = 1
//	static constant INPUTRESISTANCE_TAG = 3
//	static constant TESTPULSE_TAG = 4
	//	static constant SINERUN_TAG = 5 //Number changed to 10
//	static constant VCSTEPRUN_TAG=6
	//	static constant VCMULTIPULSE_TAG=7 //Numbers changed to 40-49
	static constant SPIKESTIM_TAG = 8
//	static constant SETTINGSNUMBER_TAG = 9
	static constant SINERUN_TAG = 10
	//	static constant NA_INACTIVATION_TAG = 11 //Numbers changed to 50-59
	//	static constant NA_Slow_INACT_TAG = 12 //Numbers changed to 60-69
	
	//	static constant STIM_TAG =13  //Deprecated 
	//	static constant STIMALTERNATE_TAG = 14 //Deprecated
	//	static constant RAMANSTIM_TAG = 15 //Deprecated

	//static constant RAMP_TAG = 16
//	static constant NA_SPIKE_INACT_TAG = 17  //Deprecated
	static constant NA_SPIKE_INACT_TAG = 18
	static constant SETTINGSNUMBER_TAG = 19


	
//	static constant FIRST_ISOLATOR_STIM_TAG = 20//  20-29 RESERVED  Numbers changed to 80-89
	
	static constant FIRST_STEPRUN_TAG = 30  //30-39 RESERVED
	
	static constant VCMULTIPULSE_TAG=40 //40-49 RESERVED
	
	static constant NA_INACTIVATION_TAG = 50 //50-59 RESERVED
	static constant NA_Slow_INACT_TAG = 60 //60-69 RESERVED
	static constant NA_INACT_VOLTAGE_TAG = 70 //70-79 RESERVED
	
//	static constant ISOLATOR_STIM_TAG = 80//  80-99 RESERVED, 10 for acquisition, 10 for analysis
	
	static constant PULSE_TRAIN_TAG = 100 //100-109 RESERVED
	
//	static constant ISOLATOR_STIM_TAG = 110//  110-129 RESERVED, 10 for acquisition, 10 for analysis
	
	static constant TESTPULSE_TAG = 130
	static constant VCSTEPRUN_TAG= 131
	static constant INPUTRESISTANCE_TAG = 132
	//static constant OPTICAL_STIM_TAG = 133
	static constant OPTICAL_STIM_TAG = 134
	static constant MULTICLAMP_TAG = 135
	
	static constant ISOLATOR_STIM_TAG = 140//  140-159 RESERVED, 10 for acquisition, 10 for analysis
	static constant ISO_SIN_STIM_TAG = 160 //160 - 169 RESERVED
	
	static constant RAMPVC_TAG = 171
	static constant RAMPCC_TAG = 172
	static constant SPONTANEOUS_TAG = 173
	static constant WHITENOISE_TAG = 174
	
		
	static constant MULTICHAN_TAG = 180  //180-189
	
	static constant MCLEVELS_TAG = 190 //190-209
	
	static constant MCISOSTIM_TAG = 210 //210-219
	
	static constant MCWAVEFORM_TAG = 220 //220-239
	
		static constant MCISOSTIM_FILE_TAG = 240 //240-240

	

	//Analysis Tags
	//static constant IFPLOT_TAG = 1001 changed to 1009
	static constant RIN_TAG = 1002
	//	static constant SPIKEPARAMS_TAG = 1003  changed to 1007
	static constant MEANRATE_TAG = 1004
	//static constant STEPRESPONSES_TAG = 1005
	//	static constant VC_STEP_RUN_PLOT_TAG = 1006 changed to 1008
//	static constant SPIKE_PARAMS_TAG = 1007
	static constant VC_STEP_RUN_PLOT_TAG = 1008
	//static constant IFPLOT_TAG = 1009
	//static constant IFPLOT_TAG = 1010
	//static constant SINE_FIT_TAG = 1011
	static constant SPIKE_CODE_TAG = 1012
	//static constant SINE_FIT_TAG = 1013
	static constant APPEND_GRAPH_TAG = 1014
	static constant SPIKE_PARAMS_TAG = 1015
	static constant RIN_FIT_TAG = 1016
	static constant SPONT_PARAMS_TAG = 1017
	//static constant IFPLOT_TAG = 1018
	//static constant IFPLOT_TAG = 1019
	static constant AUTOSAVE_TAG = 1020
	static constant MUTLI_TABLES_TAG = 1021
	static constant VIEWER_TAG = 1030 //1030-1039 reserved
	static constant PARAMS_BY_SPIKE_TAG = 1040
	static constant IFPLOT_TAG = 1042
	//static constant WHITE_ANALY_TAG = 1043
	static constant WHITE_MODEL_TAG = 1044
	static constant SINE_FIT_TAG = 1045
	static constant WHITE_ANALY_TAG = 1046
	
	
	
	Structure AutoSavePreferences	
		uint32 autosave
	EndStructure

Function LoadAutoSavePreferences(prefs)
	STRUCT AutoSavePreferences &prefs
	Variable kPreferencesRecordID = AUTOSAVE_TAG  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 )

		prefs.autosave = 1;

	endif
End


Function SetAutoSavePreferences(prefs)
	STRUCT AutoSavePreferences &prefs
	Variable kPreferencesRecordID = AUTOSAVE_TAG 
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End


	Structure AmplifierPreferences
	uint32 version  //Currently 100, increment each time the structure is changed.
	uint32 amplifier
	uint16 reserved[100] //Reserved for future options.
	EndStructure

Function LoadAmplifierPreferences(prefs)
	STRUCT AmplifierPreferences &prefs
	Variable kPreferencesRecordID = AMPLIFIER_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
	
		prefs.version = currentPrefsVersion
		
		prefs.amplifier = MULTICLAMP;

		Variable i
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

//Use when setting programmatically
Function SetAmplifierPreferences(prefs)
	STRUCT AmplifierPreferences &prefs
	Variable kPreferencesRecordID = AMPLIFIER_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//Use when setting with the user interface.
Function SetAmplifierPrompt()
	STRUCT AmplifierPreferences prefs
	LoadAmplifierPreferences(prefs)
	Variable amplifier = prefs.amplifier
	
	//String amplifier = ""

	prompt  amplifier "Amplifier (0: None, 1: Axoclamp2B, 2:Axopatch200B, 3:Multiclamp)"//popup "None;Axoclamp2B;Axopatch200B;Multiclamp"

	DoPrompt "Choose Amplifier", amplifier
	If(V_flag)
		abort
	endif
	
	prefs.amplifier = amplifier

	SetAmplifierPreferences(prefs)
	
	KillWaves/A/Z
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure MulticlampPreferences
double vcFeedback[4]
double vcCommand[4]
double ccFeedback[4]
double ccCommand[4]

EndStructure

Function LoadMultiClampPreferences(prefs)
	STRUCT MultiClampPreferences &prefs
	Variable kPreferencesRecordID = MULTICLAMP_TAG  //Increment for each new record type
	
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		Variable i
		for(i=0; i<4; i+=1)	
			prefs.vcFeedback[i] = 500 //MOhms
			prefs.vcCommand[i] = 20 //mV/V
			prefs.ccFeedback[i] = 500 //MOhms
			prefs.ccCommand[i] = 400 //pA/V
		endfor
		
	endif
End

Function SetMulticlampPreferences(prefs)
	STRUCT MulticlampPreferences &prefs
	Variable kPreferencesRecordID = MULTICLAMP_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//If using the multiclamp amplifier, match these settings to those of the amplifier.
//This will assure that input and output have the correct scaling.
Function SetMulticlampPrompt()
	STRUCT MulticlampPreferences prefs
	LoadMulticlampPreferences(prefs)
	Variable vcFeedback0 = prefs.vcFeedback[0]
	Variable vcCommand0 = prefs.vcCommand[0]
	Variable ccFeedback0 = prefs.ccFeedback[0]
	Variable ccCommand0 = prefs.ccCommand[0]
	
	Variable vcFeedback1 = prefs.vcFeedback[1]
	Variable vcCommand1 = prefs.vcCommand[1]
	Variable ccFeedback1 = prefs.ccFeedback[1]
	Variable ccCommand1 = prefs.ccCommand[1]

	Prompt vcFeedback0, "VC Feedback Resistor (M½):"
	Prompt vcCommand0, "VC Command Sensitivity (mV/V):"
	Prompt ccFeedback0, "CC Feedback Resistor (M½):"
	Prompt ccCommand0, "CC Command Sensitivity (pA/V):"
	
	Prompt vcFeedback1, "VC Feedback Resistor (M½):"
	Prompt vcCommand1, "VC Command Sensitivity (mV/V):"
	Prompt ccFeedback1, "CC Feedback Resistor (M½):"
	Prompt ccCommand1, "CC Command Sensitivity (pA/V):"
	
	DoPrompt "Multiclamp 700B Settings:", vcFeedback0, vcCommand0, ccFeedback0, ccCommand0, vcFeedback1, vcCommand1, ccFeedback1, ccCommand1
	
	prefs.vcFeedback[0] = vcFeedback0
	prefs.vcCommand[0] = vcCommand0
	prefs.ccFeedback[0] = ccFeedback0
	prefs.ccCommand[0] = ccCommand0
	
		
	prefs.vcFeedback[1] = vcFeedback1
	prefs.vcCommand[1] = vcCommand1
	prefs.ccFeedback[1] = ccFeedback1
	prefs.ccCommand[1] = ccCommand1
	
	SetMulticlampPreferences(prefs)
	
	KillWaves/A/Z

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure SpontaneousPreferences

uchar  comment[MAX_STRING]

double duration  
uint16 durationUnits
double sampleRate  //in kHz  //No longer queried.  Forced to be 40 kHz
uchar adcChansString[20]
EndStructure

Function LoadSpontaneousPreferences(prefs)
	STRUCT SpontaneousPreferences &prefs
	Variable kPreferencesRecordID = SPONTANEOUS_TAG  //Increment for each new record type

	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)

		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.durationUnits = 0
				
		prefs.duration = 5000
		prefs.sampleRate = 40		

		prefs.adcChansString = "0"

	endif
End

Function SetSpontaneousPreferences(prefs)
	STRUCT SpontaneousPreferences &prefs
	Variable kPreferencesRecordID = SPONTANEOUS_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure InputResistancePreferences
int32 amplitude  //in pA
uchar comment[MAX_STRING]
uint32 nTracesToAverage
uint16 reserved[100] 
EndStructure

Function LoadInputResistancePreferences(prefs)
	STRUCT InputResistancePreferences &prefs
	Variable kPreferencesRecordID = INPUTRESISTANCE_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		
		prefs.amplitude = -10
		
		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.nTracesToAverage = 2
				
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetInputResistancePreferences(prefs)
	STRUCT InputResistancePreferences &prefs
	Variable kPreferencesRecordID = INPUTRESISTANCE_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure TestPulsePreferences
uchar comment[MAX_STRING]
double pulseAmp //relative pulse amp
double holdingPotential
int32 rsWaveRange
EndStructure

Function LoadTestPulsePreferences(prefs)
	STRUCT TestPulsePreferences &prefs
	Variable kPreferencesRecordID = TESTPULSE_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)	
		
		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.pulseAmp = -30
		prefs.holdingPotential = -50
		prefs.rsWaveRange = 250

	endif
End

Function SetTestPulsePreferences(prefs)
	STRUCT TestPulsePreferences &prefs
	Variable kPreferencesRecordID = TESTPULSE_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure SineRunPreferences
uint32 version  //Currently 100, increment each time the structure is changed.
uchar comment[MAX_STRING]
int32 amplitude
uchar periods[MAX_STRING]
uchar nPeriods[MAX_STRING]
uint16 reserved[100] 
EndStructure

Function LoadSineRunPreferences(prefs)
	STRUCT SineRunPreferences &prefs
	Variable kPreferencesRecordID = SINERUN_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion	
		
		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.amplitude = 100
		
		prefs.periods = "500, 2000, 250, 1000, 4000"
		prefs.nPeriods = "10, 6, 16, 6, 5"
				
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetSineRunPreferences(prefs)
	STRUCT SineRunPreferences &prefs
	Variable kPreferencesRecordID = SINERUN_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure VCStepRunPreferences
uint32 version  //Currently 100, increment each time the structure is changed.
int32 startVoltage  //in mV
int32 stopVoltage   //in mV
int32 stepSize  //in mV
double interTrialInterval  //in s No longer used
uchar  comment[MAX_STRING]
double prePulse  //ms
double durPulse  //ms
double postPulse //ms
double holding //in mV
int32 rsWaveRange //pA //No longer used
uint16 reserved[96] 

EndStructure

Function LoadVCStepRunPreferences(prefs)
	STRUCT VCStepRunPreferences &prefs
	Variable kPreferencesRecordID = VCSTEPRUN_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100 
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion
		
		prefs.startVoltage = -90
		prefs.stopVoltage = -20
		prefs.stepSize = 10
		prefs.interTrialInterval = 2 //no longer used

		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.prePulse = 100
		prefs.durPulse = 50
		prefs.postPulse = 100
		prefs.holding = -50
		
		prefs.rsWaveRange = 250 //No longer used
				
		for(i=0; i<96; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetVCStepRunPreferences(prefs)
	STRUCT VCStepRunPreferences &prefs
	Variable kPreferencesRecordID = VCSTEPRUN_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure VCMultipulsePreferences
uint32 version  //Currently 100, increment each time the structure is changed.
uchar  comment[MAX_STRING]
double rsWaveRange //in mV  //No longer used
double firstStepDur //in ms
double firstStepAmp //in mV
double secondStepDur //in ms
double secondStepAmpInit //in mV
double secondStepAmpLimit //in mV
double secondStepAmpInterval//in mV
double holdPotential //in mV
double interTrialInterval //in s.  No longer used.
uint16 reserved[100] 
EndStructure

Function LoadVCMultipulsePreferences(prefs, settingsNumber)
	STRUCT VCMultipulsePreferences &prefs
	Variable settingsNumber
	Variable kPreferencesRecordID = VCMULTIPULSE_TAG+settingsNumber  //Increment for each new record type
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion
		
		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.rsWaveRange = 250  //No longer used
		prefs.firstStepDur = 500
		prefs.firstStepAmp = -90
		prefs.secondStepDur = 50
		prefs.secondStepAmpInit  = -40
		prefs.secondStepAmpLimit = 30
		prefs.secondStepAmpInterval = 10
		prefs.holdPotential = -50
		prefs.interTrialInterval = 2 //No longer used
		
				
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetVCMultipulsePreferences(prefs, settingsNumber)
	STRUCT VCMultipulsePreferences &prefs
	Variable settingsNumber
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	Variable kPreferencesRecordID = VCMULTIPULSE_TAG + settingsNumber //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure SpikeStimPreferences
uint32 version  //Currently 100, increment each time the structure is changed.
uchar  comment[MAX_STRING]
uchar  stimNames[MAX_STRING]
double holdPotential //in mV
uint16 reserved[100] 
EndStructure

Function LoadSpikeStimPreferences(prefs)
	STRUCT SpikeStimPreferences &prefs
	Variable kPreferencesRecordID = SPIKESTIM_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion
		
		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		for(i=0; i<MAX_STRING; i+=1)
			prefs.stimNames[i] = 0
		endfor	
		
		prefs.holdPotential = -50
				
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetSpikeStimPreferences(prefs)
	STRUCT SpikeStimPreferences &prefs
	Variable kPreferencesRecordID = SPIKESTIM_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure IsolatorStimPreferences

//Global Characterstics
uchar  comment[MAX_STRING]
double duration //ms
double interTrialInterval//s
uint32 nTrials

//CC vs VC
double ccDur //ms
double vcDur//ms
uint32 pulseMode  //CC=0 or VC=1

double prePulse //ms
double durPulseA //ms
double ampPulseA //(pA for CC, mV for VC)
double durPulseB //ms
double ampPulseB //(pA for CC, mV for VC)


//Output to Stimulus Isolator
double stim1Delay //ms
uchar pulseWidths[MAX_STRING]
uchar interPulseIntervals[MAX_STRING]
uchar nPulses[MAX_STRING]

uint32 stim2Active
double stim2Delay //ms
uint32 fitFirstEpsc //0: No, 1: Yes
double relativeRestingTime  //ms
double relativeStartFitTime  //ms
double relativeEndFitTime //ms

EndStructure

Function LoadIsolatorStimPreferences(prefs, settingsNumber, type)
	STRUCT IsolatorStimPreferences &prefs
	Variable settingsNumber
	Variable type //0 for acquisition, 1 for analysis
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	if(type ==1)
		settingsNumber +=10
	endif
	
	Variable kPreferencesRecordID = ISOLATOR_STIM_TAG +  settingsNumber //Increment for each new record type
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		
		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.duration = 5000
		prefs.interTrialInterval = 1
		prefs.nTrials = 1
		
		prefs.ccDur = 5000
		prefs.vcDur = 0
		prefs.pulseMode = 0
		prefs.prePulse = 1000
		prefs.durPulseA = 500
		prefs.ampPulseA = -100
		prefs.durPulseB = 500
		prefs.ampPulseB = 100
		
		prefs.stim1Delay = 1000
		prefs.pulseWidths = "2"
		prefs.interPulseIntervals = "6"
		prefs.nPulses = "50"
		prefs.stim2Active = 0
		prefs.stim2delay = 1002
		
		prefs.fitFirstEpsc = 1
		prefs.relativeRestingTime = -3
		prefs.relativeStartFitTime = 1
		prefs.relativeEndFitTime = 5

	endif
End

Function SetIsolatorStimPreferences(prefs, settingsNumber, type)
	STRUCT IsolatorStimPreferences &prefs
	Variable settingsNumber
	Variable type //0 for acquisition, 1 for analysis
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	if(type ==1)
		settingsNumber +=10
	endif
	
	Variable kPreferencesRecordID =ISOLATOR_STIM_TAG +  settingsNumber//Increment for each new record type

	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure IsoSinStimPreferences

//Global Characterstics
uchar  comment[MAX_STRING]
double duration //ms
double interTrialInterval//s
uint32 nTrials

//CC vs VC
double ccDur //ms
double vcDur//ms
uint32 pulseMode  //CC=0 or VC=1

//Output to Stimulus Isolator
double stim1Delay //ms
double preSteadyStim //ms
double modulationPeriod //ms
double nPeriods 
double postSteadyStim //ms

double modulationOffset //Hz
double modulationAmplitude //Hz
double pulseWidth //ms


uint32 stim2Active
double stim2Delay //ms


EndStructure

Function LoadIsoSinStimPreferences(prefs, settingsNumber)
	STRUCT IsoSinStimPreferences &prefs
	Variable settingsNumber
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	
	Variable kPreferencesRecordID = ISO_SIN_STIM_TAG +  settingsNumber //Increment for each new record type
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		
		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.duration = 5000
		prefs.interTrialInterval = 1
		prefs.nTrials = 1
		
		prefs.ccDur = 5000
		prefs.vcDur = 0
		prefs.pulseMode = 0

		
		prefs.stim1Delay = 1000
		prefs.preSteadyStim = 1000
		prefs.modulationPeriod = 350
		prefs.nPeriods = 5
		prefs.postSteadyStim = 1000
		prefs.modulationOffset = 50
		prefs.modulationAmplitude = 10
		prefs.pulseWidth = .05
		prefs.stim2Active = 0
		prefs.stim2delay = 1002
		


	endif
End

Function SetIsoSinStimPreferences(prefs, settingsNumber)
	STRUCT IsoSinStimPreferences &prefs
	Variable settingsNumber
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	
	Variable kPreferencesRecordID =ISO_SIN_STIM_TAG +  settingsNumber//Increment for each new record type

	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure OpticalStimPreferences
uchar  comment[MAX_STRING]
uint32 mode
double delay
double interPulseInterval
uint32 nPulses
double gap
uint32 nGroups
double tail
uint32 nTrials
double interTrialInterval
EndStructure

Function LoadOpticalStimPreferences(prefs)
	STRUCT OpticalStimPreferences &prefs
	Variable kPreferencesRecordID = OPTICAL_STIM_TAG  //Increment for each new record type
	
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		
		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.mode=0
		prefs.delay = 500
		prefs.interpulseInterval = 1000
		prefs.nPulses = 2
		prefs.gap = 2000
		prefs.nGroups = 2
		prefs.tail = 500
		prefs.nTrials = 1
		prefs.interTrialInterval = 1
		
	endif
End

Function SetOpticalStimPreferences(prefs)
	STRUCT OpticalStimPreferences &prefs
	Variable kPreferencesRecordID = OPTICAL_STIM_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure StepRunPreferences
uint32 version  //Currently 100, increment each time the structure is changed.
int32 startCurrent  //in pA
int32 stopCurrent   //in pA
int32 stepSize  //in pA
uint32 numTrials
double interTrialInterval  //in s
uchar  comment[MAX_STRING]
uint32 prePulse  //ms
uint32 durPulse  //ms
uint32 postPulse //ms
uint32 samplingInterval //in us  No longer used.  Fixed at 25.
uint16 reserved[96] 
EndStructure

Function LoadStepRunPreferences(prefs, settingsNumber)
	STRUCT StepRunPreferences &prefs
	Variable settingsNumber
	Variable kPreferencesRecordID = FIRST_STEPRUN_TAG+ settingsNumber //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion
		
		prefs.startCurrent = 0
		prefs.stopCurrent = 200
		prefs.stepSize = 100
		prefs.numTrials = 1
		prefs.interTrialInterval = 4

		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.prePulse = 1000
		prefs.durPulse = 1000
		prefs.postPulse = 2000
		prefs.samplingInterval = 25  //ignored.  fixed in code at 25.
		for(i=0; i<96; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetStepRunPreferences(prefs, settingsNumber)
	STRUCT StepRunPreferences &prefs
	Variable settingsNumber
	Variable kPreferencesRecordID = FIRST_STEPRUN_TAG + settingsNumber //Increment for each new record type
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure NaInactivationPreferences
uint32 version  //Currently 100, increment each time the structure is changed.

uchar  comment[MAX_STRING]
double holding  //mV
double baseline //mV
double pulseAmpA //mV
double pulseAmpB //mV
double pulseWidthA //ms
double pulseWidthB //ms
uchar deltaTs[MAX_STRING] //ms
uint16 reserved[100] 
EndStructure

Function LoadNaInactivationPreferences(prefs, settingsNumber)
	STRUCT NaInactivationPreferences &prefs
	Variable settingsNumber
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif

	Variable kPreferencesRecordID = NA_INACTIVATION_TAG + settingsNumber//Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion

		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
				
		prefs.holding = -50
		prefs.baseline = -50
		prefs.pulseAmpA = 30
		prefs.pulseAmpB = 30
		prefs.pulseWidthA = 5
		prefs.pulseWidthB = 5
		prefs.deltaTs = "1, 2, 3, 4, 5, 6, 7, 8, 9, 10"

		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetNaInactivationPreferences(prefs, settingsNumber)
	STRUCT NaInactivationPreferences &prefs
	Variable settingsNumber
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif

	Variable kPreferencesRecordID = NA_INACTIVATION_TAG + settingsNumber  //Increment for each new record type

	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure NaSlowInactPreferences
uint32 version  //Currently 100, increment each time the structure is changed.

uchar  comment[MAX_STRING]
double holding  //mV
double baseline //mV
double longPulseAmp //mV
uchar deltaTs[MAX_STRING] //ms
double shortPulseAmp //mV
double shortPulseWidth //ms

uint16 reserved[100] 
EndStructure

Function LoadNaSlowInactPreferences(prefs, settingsNumber)
	STRUCT NaSlowInactPreferences &prefs
	Variable settingsNumber
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif

	Variable kPreferencesRecordID = NA_Slow_INACT_TAG + settingsNumber//Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion

		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
				
		prefs.holding = -50
		prefs.baseline = -50
		prefs.longPulseAmp = 30
		prefs.deltaTs = "1,2,3,4,5,6,7,8,9,10"
		prefs.shortPulseAmp = 30
		prefs.shortPulseWidth = 5

		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetNaSlowInactPreferences(prefs, settingsNumber)
	STRUCT NaSlowInactPreferences &prefs
	Variable settingsNumber
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif

	Variable kPreferencesRecordID = NA_Slow_INACT_TAG + settingsNumber  //Increment for each new record type

	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure NaInactVoltagePreferences
uint32 version  //Currently 100, increment each time the structure is changed.
uchar  comment[MAX_STRING]
double firstStepDur //in ms
double firstStepAmpInit //in mV
double firstStepAmpLimit //in mV
double firstStepAmpInterval//in mV
double secondStepDur //in ms
double secondStepAmp //in mV
double holdPotential //in mV
double interTrialInterval //in s  No longer used.
uint16 reserved[100] 
EndStructure

Function LoadNaInactVoltagePreferences(prefs, settingsNumber)
	STRUCT NaInactVoltagePreferences &prefs
	Variable settingsNumber
	Variable kPreferencesRecordID = NA_INACT_VOLTAGE_TAG+settingsNumber  //Increment for each new record type
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion
		
		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.firstStepDur = 10
		prefs.firstStepAmpInit  = -60
		prefs.firstStepAmpLimit = 30
		prefs.firstStepAmpInterval = 5
		prefs.secondStepDur = 5
		prefs.secondStepAmp = 15

		prefs.holdPotential = -50
		prefs.interTrialInterval = 2 //No longer used
		
				
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetNaInactVoltagePreferences(prefs, settingsNumber)
	STRUCT NaInactVoltagePreferences &prefs
	Variable settingsNumber
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	Variable kPreferencesRecordID = NA_INACT_VOLTAGE_TAG + settingsNumber //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure RampVCPreferences

uchar  comment[MAX_STRING]
double holding  //mV
double baseline //mV

double  startAmp //mV
double finalAmp//mV
double rampDuration //ms

EndStructure

Function LoadRampVCPreferences(prefs)
	STRUCT RampVCPreferences &prefs

	Variable kPreferencesRecordID = RAMPVC_TAG//Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)

		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
				
		prefs.holding = -50
		prefs.baseline = -50
		prefs.startAmp = -50
		prefs.finalAmp = 20
		prefs.rampDuration = 100

	endif
End

Function SetRampVCPreferences(prefs)
	STRUCT RampVCPreferences &prefs

	Variable kPreferencesRecordID = RAMPVC_TAG  //Increment for each new record type

	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure RampCCPreferences

uchar  comment[MAX_STRING]


double  startAmp //pA
double finalAmp//pA
double rampSlope //pA/s

EndStructure

Function LoadRampCCPreferences(prefs)
	STRUCT RampCCPreferences &prefs

	Variable kPreferencesRecordID = RAMPCC_TAG//Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)


		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.startAmp = -50
		prefs.finalAmp = 50
		prefs.rampSlope = 100

	endif
End

Function SetRampCCPreferences(prefs)
	STRUCT RampCCPreferences &prefs

	Variable kPreferencesRecordID = RAMPCC_TAG  //Increment for each new record type

	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure NaSpikeInactPreferences
uint32 version  //Currently 100, increment each time the structure is changed.

uchar  precom[MAX_STRING]
double stepVoltage //mV
uchar  stimName[MAX_STRING]
uchar deltaTs[MAX_STRING] //ms list
double holding  //mV

uint16 reserved[100] 
EndStructure

Function LoadNaSpikeInactPreferences(prefs)
	STRUCT NaSpikeInactPreferences &prefs

	Variable kPreferencesRecordID = NA_SPIKE_INACT_TAG//Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion

		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.precom[i] = 0
		endfor
				
		prefs.stepVoltage = 15
		prefs.stimName = "stimName"
		prefs.deltaTs = "1,2,3,4,5,7,10,50,100,500,1000"
		prefs.holding = -50
		
	endif
End

Function SetNaSpikeInactPreferences(prefs)
	STRUCT NaSpikeInactPreferences &prefs

	Variable kPreferencesRecordID = NA_SPIKE_INACT_TAG  //Increment for each new record type

	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure PulseTrainPreferences
uint32 version  //Currently 100, increment each time the structure is changed.

uchar  comment[MAX_STRING]
uint32 nPulses
double pulseAmp //pA
double pulseWidth //ms
uchar deltaTs[MAX_STRING] //ms
uint16 reserved[100] 
EndStructure

Function LoadPulseTrainPreferences(prefs, settingsNumber)
	STRUCT PulseTrainPreferences &prefs
	Variable settingsNumber
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif

	Variable kPreferencesRecordID = PULSE_TRAIN_TAG + settingsNumber//Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion

		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.nPulses = 10
		prefs.pulseAmp = 20
		prefs.pulseWidth = 5
		prefs.deltaTs = "10, 20, 30, 40, 50"

		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetPulseTrainPreferences(prefs, settingsNumber)
	STRUCT PulseTrainPreferences &prefs
	Variable settingsNumber
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif

	Variable kPreferencesRecordID = PULSE_TRAIN_TAG + settingsNumber  //Increment for each new record type

	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure SettingsNumberPreferences
int32 isolatorStim
int32 stepRun
int32 viewer
EndStructure

Function LoadSettingsNumberPreferences(prefs)
	STRUCT SettingsNumberPreferences &prefs
	Variable kPreferencesRecordID = SETTINGSNUMBER_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)

		prefs.isolatorStim = 0
		prefs.stepRun = 0
		prefs.viewer = 0
		

	endif
End

Function SetSettingsNumberPreferences(prefs)
	STRUCT SettingsNumberPreferences &prefs
	Variable kPreferencesRecordID = SETTINGSNUMBER_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

Function GetSettingsNumber(TitleString, FieldString)
	String TitleString, FieldString
	
	Struct SettingsNumberPreferences prefsA
	LoadSettingsNumberPreferences(prefsA)
	Variable settingsNumber = prefsA.stepRun
	
	prompt settingsNumber, FieldString
	DoPrompt TitleString, settingsNumber
	if(V_Flag)
		abort
	endif
	prefsA.stepRun = settingsNumber
	SetSettingsNumberPreferences(prefsA)
	return settingsNumber
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure WhiteNoisePreferences

uchar  comment[MAX_STRING]

int32 seed
double offset //pA
double standardD //pA
double interval //ms
double duration
uint16 durationUnits
EndStructure

Function LoadWhiteNoisePreferences(prefs)
	STRUCT WhiteNoisePreferences &prefs
	Variable kPreferencesRecordID = WHITENOISE_TAG  //Increment for each new record type

	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)

		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.comment[i] = 0
		endfor
		
		prefs.seed = 4357
		prefs.offset = 0
		prefs.standardD = 10
		prefs.interval = 10
		prefs.duration = 5
		prefs.durationUnits = 2


	endif
End

Function SetWhiteNoisePreferences(prefs)
	STRUCT WhiteNoisePreferences &prefs
	Variable kPreferencesRecordID = WHITENOISE_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure MultiChanPreferences


//Global Characterstics
uchar  comment[MAX_STRING]
double duration //ms
double interTrialInterval//s
uint32 nTrials
uint32 channel0
uint32 channel1
uint32 isolator


EndStructure

Function LoadMultiChanPreferences(prefs, settingsNumber)
	STRUCT MultiChanPreferences &prefs
	Variable settingsNumber
	Variable channel //0 or 1
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	

	
	Variable kPreferencesRecordID = MULTICHAN_TAG +  settingsNumber //Increment for each new record type
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)	
	
		prefs.comment = "comment"	
		prefs.duration = 5000
		prefs.interTrialInterval = 1
		prefs.nTrials = 1
		prefs.channel0 = 1
		prefs.channel1 = 0
		prefs.isolator = 1

	endif
End

Function SetMultiChanPreferences(prefs, settingsNumber)
	STRUCT MultiChanPreferences &prefs
	Variable settingsNumber
	Variable channel //0 or 1
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	
	Variable kPreferencesRecordID =MULTICHAN_TAG +  settingsNumber//Increment for each new record type

	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End





//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure MCLevelsPreferences


//CC vs VC
double ccDur //ms
double vcDur//ms
uint32 pulseMode  //CC=0 or VC=1

double prePulse //ms
double durPulseA //ms
double ampPulseA //(pA for CC, mV for VC)
double durPulseB //ms
double ampPulseB //(pA for CC, mV for VC)


EndStructure

Function LoadMCLevelsPreferences(prefs, settingsNumber, channel)
	STRUCT MCLevelsPreferences &prefs
	Variable settingsNumber
	Variable channel //0 or 1
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	if(channel ==1)
		settingsNumber +=10
	endif
	
	Variable kPreferencesRecordID = MCLEVELS_TAG +  settingsNumber //Increment for each new record type
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		
		prefs.ccDur = 5000
		prefs.vcDur = 0
		prefs.pulseMode = 0
		prefs.prePulse = 1000
		prefs.durPulseA = 500
		prefs.ampPulseA = -100
		prefs.durPulseB = 500
		prefs.ampPulseB = 100

	endif
End

Function SetMCLevelsPreferences(prefs, settingsNumber, channel)
	STRUCT MCLevelsPreferences &prefs
	Variable settingsNumber
	Variable channel //0 or 1
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	if(channel ==1)
		settingsNumber +=10
	endif
	
	Variable kPreferencesRecordID =MCLEVELS_TAG +  settingsNumber//Increment for each new record type

	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure MCIsoStimPreferences


//Output to Stimulus Isolator
double stim1Delay //ms
uchar pulseWidths[MAX_STRING]
uchar interPulseIntervals[MAX_STRING]
uchar nPulses[MAX_STRING]

uint32 stim2Active
double stim2Delay //ms
uint32 fitFirstEpsc //0: No, 1: Yes
double relativeRestingTime  //ms
double relativeStartFitTime  //ms
double relativeEndFitTime //ms


EndStructure

Function LoadMCIsoStimPreferences(prefs, settingsNumber)
	STRUCT MCIsoStimPreferences &prefs
	Variable settingsNumber

	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	

	
	Variable kPreferencesRecordID = MCISOSTIM_TAG +  settingsNumber //Increment for each new record type
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		
		prefs.stim1Delay = 1000
		prefs.pulseWidths = "2"
		prefs.interPulseIntervals = "6"
		prefs.nPulses = "50"
		prefs.stim2Active = 0
		prefs.stim2delay = 1002
		
		prefs.fitFirstEpsc = 1
		prefs.relativeRestingTime = -3
		prefs.relativeStartFitTime = 1
		prefs.relativeEndFitTime = 5

	endif
End

Function SetMCIsoStimPreferences(prefs, settingsNumber)
	STRUCT MCIsoStimPreferences &prefs
	Variable settingsNumber

	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif

	
	Variable kPreferencesRecordID =MCISOSTIM_TAG +  settingsNumber//Increment for each new record type

	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure MCIsoStimFilePreferences


//Output to Stimulus Isolator
double stim1Delay //ms
double pulseWidth
uchar pulseTimesFile[MAX_STRING]

uint32 stim2Active
double stim2Delay //ms
uint32 fitFirstEpsc //0: No, 1: Yes
double relativeRestingTime  //ms
double relativeStartFitTime  //ms
double relativeEndFitTime //ms


EndStructure

Function LoadMCIsoStimFilePreferences(prefs, settingsNumber)
	STRUCT MCIsoStimFilePreferences &prefs
	Variable settingsNumber

	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	

	
	Variable kPreferencesRecordID = MCISOSTIM_FILE_TAG +  settingsNumber //Increment for each new record type
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		
		prefs.stim1Delay = 1000
		prefs.pulseWidth = 2
		prefs.pulseTimesFile = ""
		prefs.stim2Active = 0
		prefs.stim2delay = 1002
		
		prefs.fitFirstEpsc = 1
		prefs.relativeRestingTime = -3
		prefs.relativeStartFitTime = 1
		prefs.relativeEndFitTime = 5

	endif
End

Function SetMCIsoStimFilePreferences(prefs, settingsNumber)
	STRUCT MCIsoStimFilePreferences &prefs
	Variable settingsNumber

	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif

	
	Variable kPreferencesRecordID =MCISOSTIM_FILE_TAG +  settingsNumber//Increment for each new record type

	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure MCWaveformPreferences


//CC vs VC
double ccDur //ms
double vcDur//ms
//Add holding?

uchar stimName[MAX_STRING]


EndStructure

Function LoadMCWaveformPreferences(prefs, settingsNumber, channel)
	STRUCT MCWaveformPreferences &prefs
	Variable settingsNumber
	Variable channel //0 or 1
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	if(channel ==1)
		settingsNumber +=10
	endif
	
	Variable kPreferencesRecordID = MCWAVEFORM_TAG +  settingsNumber //Increment for each new record type
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		
		prefs.ccDur = 0
		prefs.vcDur = 5000
		prefs.stimName = "WaveName"

	endif
End

Function SetMCWaveformPreferences(prefs, settingsNumber, channel)
	STRUCT MCWaveformPreferences &prefs
	Variable settingsNumber
	Variable channel //0 or 1
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	if(channel ==1)
		settingsNumber +=10
	endif
	
	Variable kPreferencesRecordID =MCWAVEFORM_TAG +  settingsNumber//Increment for each new record type

	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End






//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure IFPlotPreferences
uchar baseName[MAX_STRING]
double relativeStart
double analysisDuration
double freqCutoff
uint32 stepAdaptation
uchar epochsToIgnore[MAX_STRING]
EndStructure

Function LoadIFPlotPreferences(prefs)
	STRUCT IFPlotPreferences &prefs
	Variable kPreferencesRecordID = IFPLOT_TAG  //Increment for each new record type
	
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)	
		
		Variable i
		prefs.baseName = ""

		prefs.relativeStart = 0
		prefs.analysisDuration = 1000
		prefs.freqCutoff = 80.0
		prefs.stepAdaptation = 1
		prefs.epochsToIgnore = ""

	endif
End

Function SetIFPlotPreferences(prefs)
	STRUCT IFPlotPreferences &prefs
	Variable kPreferencesRecordID = IFPLOT_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure RinPreferences
uint32 version  //Currently 100, increment each time the structure is changed.
uint32 peak
uint32 mempotential

uint16 reserved[100] 
EndStructure

Function LoadRinPreferences(prefs)
	STRUCT RinPreferences &prefs
	Variable kPreferencesRecordID = RIN_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion	
		
		Variable i
			
		prefs.peak = 1
		prefs.mempotential = 0
			
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetRinPreferences(prefs)
	STRUCT RinPreferences &prefs
	Variable kPreferencesRecordID = RIN_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure RinFitPreferences
uchar epochsToIgnore[100]

uint16 reserved[100] 
EndStructure

Function LoadRinFitPreferences(prefs)
	STRUCT RinFitPreferences &prefs
	Variable kPreferencesRecordID = RIN_FIT_TAG  //Increment for each new record type
	
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 )
			
		Variable i
			
		prefs.epochsToIgnore = ""
			
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetRinFitPreferences(prefs)
	STRUCT RinFitPreferences &prefs
	Variable kPreferencesRecordID = RIN_FIT_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure SpontParamsPreferences
double startTime
double endTime

EndStructure

Function LoadSpontParamsPreferences(prefs)
	STRUCT SpontParamsPreferences &prefs
	Variable kPreferencesRecordID = SPONT_PARAMS_TAG  //Increment for each new record type
	
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)	
		
		Variable i
		
		prefs.startTime = -1
		prefs.endTime = -1


	endif
End

Function SetSpontParamsPreferences(prefs)
	STRUCT SpontParamsPreferences &prefs
	Variable kPreferencesRecordID = SPONT_PARAMS_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure SpikeParamsPreferences
uchar startAvString[100]
uchar endAvString[100]
uint32 branch

uint16 reserved[100] 
EndStructure

Function LoadSpikeParamsPreferences(prefs)
	STRUCT SpikeParamsPreferences &prefs
	Variable kPreferencesRecordID = SPIKE_PARAMS_TAG  //Increment for each new record type
	
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)	
		
		Variable i
		
		
		prefs.startAvString = "<entire trace>"
		prefs.endAvString = "<entire trace>"

		prefs.branch = 0
			
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetSpikeParamsPreferences(prefs)
	STRUCT SpikeParamsPreferences &prefs
	Variable kPreferencesRecordID = SPIKE_PARAMS_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure ParamsBySpikePreferences
uchar paramNames[100]
uint32 branch

EndStructure

Function LoadParamsBySpikePreferences(prefs)
	STRUCT ParamsBySpikePreferences &prefs
	Variable kPreferencesRecordID = PARAMS_BY_SPIKE_TAG  //Increment for each new record type
	
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)	
		
		prefs.paramNames = "AP_hw_ms, AP_thresh_mV"

		prefs.branch = 0
	endif
End

Function SetParamsBySpikePreferences(prefs)
	STRUCT ParamsBySpikePreferences &prefs
	Variable kPreferencesRecordID = PARAMS_BY_SPIKE_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure MeanRatePreferences
uint32 version  //Currently 100, increment each time the structure is changed.
uint32 depolarized
uint16 reserved[100] 
EndStructure

Function LoadMeanRatePreferences(prefs)
	STRUCT MeanRatePreferences &prefs
	Variable kPreferencesRecordID = MEANRATE_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion	
		
		Variable i	
		
		prefs.depolarized = 0
		
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetMeanRatePreferences(prefs)
	STRUCT MeanRatePreferences &prefs
	Variable kPreferencesRecordID = MEANRATE_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


//Structure StepResponsesPreferences
//uint32 version  //Currently 100, increment each time the structure is changed.
//double threshold
//uint32 timeUnit  //0=min, 1=s, 2=ms
//uint16 reserved[100] 
//EndStructure
//
//Function LoadStepResponsesPreferences(prefs)
//	STRUCT StepResponsesPreferences &prefs
//	Variable kPreferencesRecordID = STEPRESPONSES_TAG  //Increment for each new record type
//	
//	Variable currentPrefsVersion = 100  
//	
//	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
//
//	//If unable to load prefences, load from defaults.
//	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
//		prefs.version = currentPrefsVersion	
//		
//		Variable i	
//		
//		prefs.threshold = -10
//		prefs.timeUnit = 2
//		
//		for(i=0; i<100; i+=1)
//			prefs.reserved[i] = 0
//		endfor
//	endif
//End
//
//Function SetStepResponsesPreferences(prefs)
//	STRUCT StepResponsesPreferences &prefs
//	Variable kPreferencesRecordID = STEPRESPONSES_TAG //Increment for each new record type
//	
//	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
//End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure VCStepRunPlotPreferences
uint32 version  //Currently 100, increment each time the structure is changed.
uchar  basename[MAX_STRING]
double startAmplitude
double amplitudeIncrement
uint32 cutRange  //menu, values held in function
uint16 reserved[100] 
EndStructure

Function LoadVCStepRunPlotPreferences(prefs)
	STRUCT VCStepRunPlotPreferences &prefs
	Variable kPreferencesRecordID =VC_STEP_RUN_PLOT_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion
		
		Variable i
		for(i=0; i<MAX_STRING; i+=1)
			prefs.basename[i] = 0
		endfor	
			
		prefs.startAmplitude = -55
		prefs.amplitudeIncrement = 10
		prefs.cutRange = 1
		
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetStepRunPlotPreferences(prefs)
	STRUCT VCStepRunPlotPreferences &prefs
	Variable kPreferencesRecordID = VC_STEP_RUN_PLOT_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure SineFitPreferences
uint32 version  //Currently 100, increment each time the structure is changed.
uint32 mode  
uint32 createLayout
uint32 createTable // no longer an option
uchar epochsToIgnore[100]

uint16 reserved[100] 
EndStructure

Function LoadSineFitPreferences(prefs)
	STRUCT SineFitPreferences &prefs
	Variable kPreferencesRecordID =SINE_FIT_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion
		
		prefs.mode = 0
		prefs.createLayout = 1
		prefs.createTable = 1 //no longer an option
		
		prefs.epochsToIgnore = ""
		
		Variable i
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetSineFitPreferences(prefs)
	STRUCT SineFitPreferences &prefs
	Variable kPreferencesRecordID = SINE_FIT_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure SpikeCodePreferences ///Now only used for upgrading.
uint32 version  //Currently 100, increment each time the structure is changed.
uchar basename[MAX_STRING]
uchar pathName[MAX_STRING]
double duration //ms
double threshold //V/s
uint32 branch //(0: Standard, 1:Aryn)

uint16 reserved[100] 
EndStructure

Function LoadSpikeCodePreferences(prefs)
	STRUCT SpikeCodePreferences &prefs
	Variable kPreferencesRecordID =SPIKE_CODE_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 || prefs.version!=currentPrefsVersion)
		prefs.version = currentPrefsVersion
		
		prefs.baseName = ""
		prefs.pathName = ""
		prefs.duration = 110
		prefs.threshold = 10
		prefs.branch = 0
		
		Variable i
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetSpikeCodePreferences(prefs)
	STRUCT SpikeCodePreferences &prefs
	Variable kPreferencesRecordID = SPIKE_CODE_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Structure AppendGraphPreferences

uint32 closeWindow
uint32 useAxis

uint16 reserved[100] 
EndStructure

Function LoadAppendGraphPreferences(prefs)
	STRUCT AppendGraphPreferences &prefs
	Variable kPreferencesRecordID =APPEND_GRAPH_TAG  //Increment for each new record type
	
	Variable currentPrefsVersion = 100  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		
		prefs.closeWindow = 0
		prefs.useAxis = 1
		
		Variable i
		for(i=0; i<100; i+=1)
			prefs.reserved[i] = 0
		endfor
	endif
End

Function SetAppendGraphPreferences(prefs)
	STRUCT AppendGraphPreferences &prefs
	Variable kPreferencesRecordID = APPEND_GRAPH_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////



Structure MutlipleTablesPreferences	
uchar basename[MAX_STRING]
uint32 showManual
uint32 showGain
uint32 showSpont
uint32 showSpike
uint32 showAdaptation
uint32 showPassive
uint32 showRebound
EndStructure

Function LoadMultipleTablesPreferences(prefs)
	STRUCT MutlipleTablesPreferences &prefs
	Variable kPreferencesRecordID = MUTLI_TABLES_TAG  
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0 )
		prefs.baseName = "base"
		prefs.showManual = 1
		prefs.showGain = 1
		prefs.showSpont = 1
		prefs.showSpike = 1
		prefs.showAdaptation = 1
		prefs.showPassive = 1
		prefs.showRebound = 1

	endif
End


Function SetMultipleTablesPreferences(prefs)
	STRUCT MutlipleTablesPreferences &prefs
	Variable kPreferencesRecordID = AUTOSAVE_TAG 
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Structure ViewerPreferences

double stepSize
double leftLimit
double rightLimit
uint32 segmentToShow
double histMin
double histMax
double binSize
uint32 nChans
double stopTime
double minPeakWidth
double minPeakAmp
double thresholdStep
uint32 inverted
uint32 liveUpdate

EndStructure

Function LoadViewerPreferences(prefs, settingsNumber)
	STRUCT ViewerPreferences &prefs
	Variable settingsNumber
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif
	
	
	Variable kPreferencesRecordID = VIEWER_TAG +  settingsNumber //Increment for each new record type
	
	Variable currentPrefsVersion = 100
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)
		
		prefs.stepSize = 2
		prefs.leftLimit = 0
		prefs.rightLimit = 2
		prefs.segmentToShow = 0
		prefs.histMin = 0
		prefs.histMax = 100
		prefs.binSize =.5
		prefs.nChans = 1
		prefs.stopTime = inf
		prefs.minPeakWidth = 2
		prefs.minPeakAmp  = 100
		prefs.thresholdStep = 20
		prefs.inverted = 0
		prefs.liveUpdate = 1	

	endif
End

Function SetViewerPreferences(prefs, settingsNumber)
	STRUCT ViewerPreferences &prefs
	Variable settingsNumber
	
	if(settingsNumber > 9)
		DoAlert 0, "Requested settingsNumber is too high."
		abort
	endif

	Variable kPreferencesRecordID =VIEWER_TAG +  settingsNumber//Increment for each new record type

	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////



Structure WhiteAnalysisPreferences
double timeCourseLength //ms
uint32 subtractUncorrelated
double uncorrelatedStart //ms
double uncorrelatedStop //ms

EndStructure

Function LoadWhiteAnalysisPreferences(prefs)
	STRUCT WhiteAnalysisPreferences &prefs
	Variable kPreferencesRecordID = WHITE_ANALY_TAG  //Increment for each new record type
	
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)	
		
		prefs.timeCourseLength = 2000
		prefs.subtractUncorrelated = 1
		prefs.uncorrelatedStart = -2000
		prefs.uncorrelatedStop = -1000
	


	endif
End

Function SetWhiteAnalysisPreferences(prefs)
	STRUCT WhiteAnalysisPreferences &prefs
	Variable kPreferencesRecordID = WHITE_ANALY_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////



Structure WhiteModelPreferences
uchar  timecourseName[MAX_STRING]

EndStructure

Function LoadWhiteModelPreferences(prefs)
	STRUCT WhiteModelPreferences &prefs
	Variable kPreferencesRecordID = WHITE_MODEL_TAG  //Increment for each new record type
	
	
	LoadPackagePreferences/MIS=1 kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs

	//If unable to load prefences, load from defaults.
	if(V_flag!=0 || V_bytesRead==0)	
		
		prefs.timeCourseName = "timecourse_0"



	endif
End

Function SetWhiteModelPreferences(prefs)
	STRUCT WhiteModelPreferences &prefs
	Variable kPreferencesRecordID = WHITE_MODEL_TAG //Increment for each new record type
	
	SavePackagePreferences kPackageName, kPreferencesfileName, kPreferencesRecordID, prefs
End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//
////Colorize traces on a graph
//Function colors()
//
//	String graphName = WinName(0,1)
//	if(strlen(graphName) == 0)
//		return -1
//	endif
//	
//	String tnl = TraceNameList( graphName, ";", 1 )
//	Variable numTraces = ItemsInList(tnl)
//	if (numTraces <= 0)
//		return -1
//	endif
//	
//	//	ColorTab2Wave Rainbow16
//	//	Wave M_colors
//	Make/O/N=(3,4) color
//	color[][0]={0,0,0}
//	color[][1]={1,4,52428}
//	color[][2]={39321,13101,1}
//	color[][3]={2,39321,1}
//	color[][4]={0,0,65535}
//	color[][5]={26205,52428,1}
//	color[][6]={65535,0,0}
//	color[][7]={65535,0,52428}
//	color[][8]={65535,43690,0}
//	color[][9]={65535,65532,16385}
//
//	Variable i
//
//	for(i=0; i<numtraces; i+=1)
//		ModifyGraph rgb[i] = (color[0][mod(i, dimsize(color, 1))], color[1][mod(i, dimsize(color, 1))], color[2][mod(i, dimsize(color, 1))])
//
//	endfor	
//	
//	KillWaves color
//	
//	
//End


///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////

Function AppendWholeGraph()
	String targetwindow=WinName(0,1), sourcewindow=WinName(1,1)
	
	STRUCT AppendGraphPreferences prefs
	LoadAppendGraphPreferences(prefs)
	
	
	Variable closewindow=prefs.closeWindow
	Variable useAxis=prefs.useAxis
	
	
	
	Prompt targetwindow,"Target window name"
	Prompt sourcewindow,"Source window name"
	Prompt closewindow,"Close source window (0: No, 1: Yes)?"
	Prompt useAxis, "Axis (0: Left, 1: Right)"
	
	DoPrompt "Append whole graph", targetwindow, sourcewindow, closeWindow, useAxis
	
	if(V_flag)
		abort
	endif
	
	cd root:Chan_0		//fix added 4/1/13
	
	prefs.closeWindow = closeWindow
	prefs.useAxis = useAxis
	
	SetAppendGraphPreferences(prefs)
      
	Variable n,startpos,stoppos
	String ywavename
   
	
	Make/o/n=0/t ywaves,xwaves,errorwaves, colorsStrings
	Make/o/n=0 modes,markersymbols,markersizes

	
	// store all trace names in waves called "xwaves" and "ywaves", loop runs from first to last trace in source window	
	do			
		if ( cmpstr(Wavename(sourcewindow,n,1)	,"") == 0 )			// end loop if last trace found 		
			break		
		endif
		ywavename=Wavename(sourcewindow,n,1)
		Redimension/n=(numpnts(ywaves)+1) ywaves,xwaves,modes,markersymbols,markersizes,errorwaves, colorsStrings
		ywaves[numpnts(ywaves)-1]=ywavename
		xwaves[numpnts(xwaves)-1]=Wavename(sourcewindow,n,2)
		
		// search for possible error-bar waves attached to IF-plots (Igor can't extract the error bar wave from a trace in a graph!!!!!)	
		if ( strsearch(ywavename,"Means",0) != -1 )
			if ( exists(ywavename[0,strsearch(ywavename,"Means",0)-1]+"StDevs") == 1 )
				errorwaves[numpnts(errorwaves)-1]=ywavename[0,strsearch(ywavename,"Means",0)-1]+"StDevs"
			else
				errorwaves[numpnts(errorwaves)-1]=""
			endif
		else
			errorwaves[numpnts(errorwaves)-1]=""	
		endif	
		

		String infoString = traceinfo(sourcewindow, ywaveName, 0)
		modes[numpnts(ywaves)-1] = NumberByKey("mode(x)", infoString, "=", ";")
		colorsStrings[numpnts(ywaves)-1] = StringByKey("rgb(x)", infoString, "=", ";")
		
		markerSymbols[numpnts(ywaves)-1] = NumberByKey("marker(x)", infoString, "=", ";")
		markerSizes[numpnts(ywaves)-1] = NumberByKey("msize(x)", infoString, "=", ";")

			
		n+=1	
	while(1)

	DoWindow/F $targetwindow					// bring target window to front
	n=0
	
	// append traces to target window, one by one
	do			
		if ( cmpstr(xwaves(n),"") == 0 )		// if source trace has only a y-wave (implicit x-wave)
			if(useAxis==0)
				AppendToGraph $ywaves(n)
			else
				AppendToGraph/R $ywaves(n)
			endif
		else
			if(useAxis==0)
				AppendToGraph $ywaves(n) vs $xwaves(n)
			else
				AppendToGraph/R $ywaves(n) vs $xwaves(n)
			endif
		endif
			
		String cmd
		sprintf cmd "ModifyGraph mode('%s')=%d, rgb('%s')=%s, marker('%s')=%d, msize('%s')=%d", ywaves(n), modes(n), ywaves(n), colorsStrings(n), ywaves(n), markerSymbols(n), ywaves(n), markerSizes(n)
	//	print cmd
		Execute cmd
		
		if (cmpstr(errorwaves(n),"") != 0 )
			ErrorBars $ywaves(n) Y,wave=($errorwaves(n),$errorwaves(n))
		endif	
		n+=1
	while ( n < numpnts(ywaves) )

	// close source window if option is set
	if ( closewindow==1 )
		DoWindow/k $sourcewindow
	endif			

	Killwaves/z ywaves, xwaves, errorWaves, colorsStrings, modes, markerSymbols, markerSizes		// clean up
	Print "Copied source window",sourcewindow,"into target window",targetwindow, "."
End




///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////

Function RinCC()
	string RinWaveName
	variable baseline, peakMin, avgMinPoint, avgMin, VmChange, RinValue
	
	//Refer to the wave measuring Rin with -100 pA injection
	RinWaveName = WaveName("", 0,1)
	Wave RinWave = $RinWaveName
	
	wavestats/q/r=[0,469] RinWave
	baseline = v_avg
	
	wavestats/q/r=[470, 1626] RinWave
	peakMin = v_min
	avgMinPoint = x2pnt(RinWave,v_minloc)
	avgMin = ((RinWave[avgMinPoint-1]+RinWave[avgMinPoint+1]+RinWave[avgMinPoint])/3)
	
	VmChange = baseline-avgMin
	VmChange*=1e-3
	
	RinValue = (VmChange)/0.1e-9
	RinValue/=1e6

	print RinValue,"MOhms"

End


///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////


Function TestPulseAnalysis()
	string RinWaveName, RinString, RsSTring, CapString, AvgWaveName, TempName
	variable voltageStep=-5
	variable holding
	variable integral, ichange, MinLocation, baseline, avgLate, MinLocPoint
	variable numerator, denominator, CapforRS
	variable RsPoint, Rs, RinValue, CapValue, tau, RsNew
	variable i, V_flag, indexNum
	string TPtextName, TPOutputName
	string baseName
	prompt BaseName, "BaseName"
	doprompt "", baseName

	make/o/t/n=5 TPtext
	make/o/n=5 TPOutput
	
	TPtext[0] = "Rin"; TPtext[1] = "Capacitance"; TPtext[2] = "Rs"; TPtext[3] = "transient"; TPtext[4] = "holding"
	
	//make sure cancel button works
	if(V_flag)
		abort
	endif
	
	AverageTrace()
	
	make/o/t/n=0 AvgName
	//Get avg wave off the graph
	do	
		redimension/n=(numpnts(AvgName)+1) AvgName
		AvgWaveName = WaveName("", i, 1)
		AvgName[i]=AvgWaveName
		if (strlen(AvgWaveName) == 0)
			break
		endif
	
	i += 1
	indexNum = i
	while(1)
	
	indexNum-=1

		tempName = WaveName("", indexNum, 1)
		wave RinWave =  $tempName 		
		display RinWave; ModifyGraph rgb=(0,0,0)
		
	//Calculate Rin
		wavestats/q/r=(0.006,0.0097) RinWave
			baseline = v_avg
			holding = v_avg
	//	wavestats/q/r=(0.017, 0.0194) RinWave
		wavestats/q/r=(0.027, 0.029) RinWave
			avgLate = v_avg
		iChange = baseline-avgLate
			iChange*=1e3	//convert current from pA to nA
			//R = V/I
			RinValue = (voltagestep)/(iChange)
				RinValue*=-1e6	//convert to MOhms
		TPOutput[0] = RinValue
	
//	//Calculate Rs (simple way)
//		WaveStats/q/r=[98, 107] RinWave
//			MinLocation=V_minloc	
//			Rspoint=V_min
//		//Rs=(V/I)
//			iChange=(RsPoint-baseline)*1e-9	//calculates change in current and converts to nA
//			Rs=voltageStep/iChange
//			Rs/=1e6	//conveerts Rs to MOhms
	

	//Calculate Capacitance
		duplicate/o/r=(0.0099, 0.014) RinWave IntWave			//0.014 for MSNs; 0.0117 for FS or LTS
			IntWave-=baseline
		Integrate IntWave; integral = IntWave[numpnts(intWave)]
			// C=q/V  	
			VoltageStep/=-1000	//convert from mV to V
			capValue=(Integral/voltagestep)
			CapValue*=-1
		TPOutput[1] = CapValue
		
	//Caclulate Rs, independently of transient with tau = RC
			WaveStats/q/r=(0.01, 0.0114) RinWave
			MinLocation=V_minloc	
			MinLocPoint = x2pnt(RinWave, minLocation)
			duplicate/o/r=[MinLocPoint, 125] RinWave TauWave
			CurveFit/q/NTHR=0 exp_XOffset  TauWave /D 
			wave W_coef
			tau = W_coef[2]
				CapforRs= CapValue
				CapforRs*=1e-12
			RsNew = tau/CapforRs
				RsNew*=1e-6
				TPOutput[2] = RsNew
				TPOutput[3] = tau
				TPOutput[4] = holding
				
		
//	//Calculate Rs- resistant to filtering: Rs = (Tau * voltage step) / [(integral)+(Tau * final current)]
//From Matthew
//			MinLocPoint = x2pnt(RinWave, minLocation)
//			duplicate/o/r=[MinLocPoint, 125] RinWave TauWave
//			CurveFit/q/NTHR=0 exp_XOffset  TauWave /D 
//			wave W_coef
//			tau = W_coef[2]
//			numerator = tau * VoltageStep
//				iChange*=1e-9		//Current in units of A
//				integral *=1e-12	//Charge in units of Q/s
//			denominator = integral + (tau * iChange)
//			RsNew = numerator/denominator
//				RsNew*=1e-6 		//Rs in units of MOhms
//			print "Rs New = ", RsNew, "MOhms"
			
		
			RinString=  num2str (RinValue)
			RsString = num2str (RsNew)
			CapString = num2str (CapValue)

			RinString = "Rin =  "+ RinString + " MOhms"
			RsString = "Rs =  " + RsString + " MOhms"
			CapString = "Cap = " + CapString + " pF"

		TextBox/C/N=text2/F=0/S=3/M/A=RB/Y=20/X=10 CapString
		TextBox/C/N=text1/F=0/S=3/M/A=RB/Y=30/X=4 RsString
		TextBox/C/N=text0/F=0/S=3/M/A=RB/Y=40/x=2 RinString
		
		sprintf TPtextName, "%s%s", "TPtext_", baseName
			duplicate/o TPtext $TPTextName
		sprintf TPOutputName, "%s%s", "TPOutput_", baseName
			duplicate/o TPOutput $TPOutputName
		
		edit $TPtextName, $TPOutputName
	
End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function DSIANalysis()
	string tempString, MatchString
	variable i, istart, iend
	variable baseline, minPeaKPoint
	variable v_flag
	variable pre1, pre2, pre3, pre4, pre5, post1, post2, post3, post4, post5
	variable pre1Avg, pre2Avg, pre3Avg, pre4Avg, pre5Avg, post1Avg, post2Avg, post3Avg, post4Avg, post5Avg
	variable Count, Run
	variable baselineAvg
	string startEpoch, EndEpoch
	string baseName
	string cmdstr
	string DSINormpre, DSINormPost
	string preWave1Name, preWave2Name, preWave3Name, preWave4Name, preWave5Name, postWave1Name, postWave2Name, postWave3Name, postWave4Name, postWave5Name
	string DSIAvgpreName, DSIAvgpostName, DSISDpreName, DSISDpostName
	prompt startEpoch, "First Epoch"
	prompt EndEpoch, "Last Epoch"
	prompt baseName, "baseName"
	doprompt "Select wave range for DSI", startEpoch, EndEpoch, baseName
	
	wave/t DSIWaves_w
	wave/t DSIWaves_c
	
	//make sure function cancels
	if(V_flag)
		abort
	endif
	
	make/o/n=0 preWave1
	make/o/n=0 preWave2
	make/o/n=0 preWave3
	make/o/n=0 preWave4
	make/o/n=0 preWave5
	make/o/n=0 postWAve1
	make/o/n=0 postWave2
	make/o/n=0 postWave3
	make/o/n=0 postWave4
	make/o/n=0 postWave5
	
	make/o/n=0 preAvg
	make/o/n=0 preSD
	make/o/n=0 postAvg
	make/o/n=0 postSD
	
	//Analyze appropriate part of wave
	do
	if (strlen(DSIWaves_w[i]) ==0)
		break
	endif
	tempString = DSIWaves_w[i]
	matchString = tempString[1, strlen(tempString)]
	
	if (stringmatch (matchString, startEpoch)==1)
		istart = i
	endif
	if (stringmatch (matchString, EndEpoch)==1)
		iend = i
	endif
	
	i+=1
	while (1)
				
		//Analyze pre1
			i = istart
			do
				wave cv1 = $DSIWaves_c[i]
					wavestats/q/r = (0 ,0.05) cv1
					baseline = v_avg
					wavestats/q/r=(0.054, 0.07) cv1
					minPeakPoint = x2pnt(cv1, v_minloc)
					pre1= ((cv1[minPeakPoint-1]+cv1[minPeakPoint+1]+ cv1[minPeakPoint])/3)-baseline
					redimension/n = (numpnts(preWave1)+1) preWave1; preWave1[Count] = pre1
				Count+=1
			i+=1
			while (i<= iend)	
			
				wavestats/q preWave1
				redimension/n = (numpnts(preAvg)+1) preAvg	
				redimension/n = (numpnts(preSD)+1) preSD						
				preAvg[0] = v_avg
				preSD[0]= v_sdev	
							
		//Analyze pre2
		i = istart	
			do
				wave cv1 = $DSIWaves_c[i]
					wavestats/q/r = (10 ,10.05) cv1
					baseline = v_avg
					wavestats/q/r=(10.054, 10.07) cv1
					minPeakPoint = x2pnt(cv1, v_minloc)
					pre2= ((cv1[minPeakPoint-1]+cv1[minPeakPoint+1]+ cv1[minPeakPoint])/3)-baseline
					redimension/n = (numpnts(preWave2)+1) preWave2; preWave2[Count] = pre2

				Count+=1
			i+=1
			while (i<= iend)	
				wavestats/q preWave2
				redimension/n = (numpnts(preAvg)+1) preAvg	
				redimension/n = (numpnts(preSD)+1) preSD						
				preAvg[1] = v_avg
				preSD[1]= v_sdev	

	//Analyze pre3
		i = istart	
			do
				wave cv1 = $DSIWaves_c[i]
					wavestats/q/r = (20 ,20.05) cv1
					baseline = v_avg
					wavestats/q/r=(20.054, 20.07) cv1
					minPeakPoint = x2pnt(cv1, v_minloc)
					pre3= ((cv1[minPeakPoint-1]+cv1[minPeakPoint+1]+ cv1[minPeakPoint])/3)-baseline
					redimension/n = (numpnts(preWave3)+1) preWave3; preWave3[Count] = pre3

				Count+=1
			i+=1
			while (i<= iend)	
				wavestats/q preWave3
				redimension/n = (numpnts(preAvg)+1) preAvg	
				redimension/n = (numpnts(preSD)+1) preSD						
				preAvg[2] = v_avg
				preSD[2]= v_sdev	
				
	//Analyze pre4
		i = istart	
			do
				wave cv1 = $DSIWaves_c[i]
					wavestats/q/r = (30 ,30.05) cv1
					baseline = v_avg
					wavestats/q/r=(30.054, 30.07) cv1
					minPeakPoint = x2pnt(cv1, v_minloc)
					pre4= ((cv1[minPeakPoint-1]+cv1[minPeakPoint+1]+ cv1[minPeakPoint])/3)-baseline
					redimension/n = (numpnts(preWave4)+1) preWave4; preWave4[Count] = pre4

				Count+=1
			i+=1
			while (i<= iend)	
				wavestats/q preWave4
				redimension/n = (numpnts(preAvg)+1) preAvg	
				redimension/n = (numpnts(preSD)+1) preSD						
				preAvg[3] = v_avg
				preSD[3]= v_sdev	
			
	//Analyze pre5
		i = istart	
			do
				wave cv1 = $DSIWaves_c[i]
					wavestats/q/r = (40 ,40.05) cv1
					baseline = v_avg
					wavestats/q/r=(40.054, 40.07) cv1
					minPeakPoint = x2pnt(cv1, v_minloc)
					pre5= ((cv1[minPeakPoint-1]+cv1[minPeakPoint+1]+ cv1[minPeakPoint])/3)-baseline
					redimension/n = (numpnts(preWave5)+1) preWave5; preWave5[Count] = pre5
				Count+=1
			i+=1
			while (i<= iend)	
				wavestats/q preWave5
				redimension/n = (numpnts(preAvg)+1) preAvg	
				redimension/n = (numpnts(preSD)+1) preSD						
				preAvg[4] = v_avg
				preSD[4]= v_sdev	
				
		//Analyze post1
			i = istart
			do
				wave cv1 = $DSIWaves_c[i]
					wavestats/q/r = (55.339 ,55.593) cv1
					baseline = v_avg
					wavestats/q/r=(55.645 ,55.663) cv1
					minPeakPoint = x2pnt(cv1, v_minloc)
					post1= ((cv1[minPeakPoint-1]+cv1[minPeakPoint+1]+ cv1[minPeakPoint])/3)-baseline
					redimension/n = (numpnts(postWave1)+1) postWave1; postWave1[Count] = post1
				Count+=1
			i+=1
			while (i<= iend)	
			
				wavestats/q postWave1
				redimension/n = (numpnts(postAvg)+1) postAvg	
				redimension/n = (numpnts(postSD)+1) postSD						
				postAvg[0] = v_avg
				postSD[0]= v_sdev	
							
		//Analyze post2
		i = istart	
			do
				wave cv1 = $DSIWaves_c[i]
					wavestats/q/r = (65.339 ,65.593) cv1
					baseline = v_avg
					wavestats/q/r=(65.645 ,65.663) cv1
					minPeakPoint = x2pnt(cv1, v_minloc)
					post2= ((cv1[minPeakPoint-1]+cv1[minPeakPoint+1]+ cv1[minPeakPoint])/3)-baseline
					redimension/n = (numpnts(postWave2)+1) postWave2; postWave2[Count] = post2
				Count+=1
			i+=1
			while (i<= iend)	
				wavestats/q postWave2
				redimension/n = (numpnts(postAvg)+1) postAvg	
				redimension/n = (numpnts(postSD)+1) postSD						
				postAvg[1] = v_avg
				postSD[1]= v_sdev	

	//Analyze post3
		i = istart	
			do
				wave cv1 = $DSIWaves_c[i]
					wavestats/q/r = (75.339 ,75.593) cv1
					baseline = v_avg
					wavestats/q/r=(75.645 ,75.663) cv1
					minPeakPoint = x2pnt(cv1, v_minloc)
					post3= ((cv1[minPeakPoint-1]+cv1[minPeakPoint+1]+ cv1[minPeakPoint])/3)-baseline
					redimension/n = (numpnts(postWave3)+1) postWave3; postWave3[Count] = post3
				Count+=1
			i+=1
			while (i<= iend)	
				wavestats/q postWave3
				redimension/n = (numpnts(postAvg)+1) postAvg	
				redimension/n = (numpnts(postSD)+1) postSD						
				postAvg[2] = v_avg
				postSD[2]= v_sdev	
				
	//Analyze post4
		i = istart	
			do
				wave cv1 = $DSIWaves_c[i]
					wavestats/q/r = (85.339 ,85.593) cv1
					baseline = v_avg
					wavestats/q/r=(85.645 ,85.663) cv1
					minPeakPoint = x2pnt(cv1, v_minloc)
					post4= ((cv1[minPeakPoint-1]+cv1[minPeakPoint+1]+ cv1[minPeakPoint])/3)-baseline
					redimension/n = (numpnts(postWave4)+1) postWave4; postWave4[Count] = post4
				Count+=1
			i+=1
			while (i<= iend)	
				wavestats/q postWave4
				redimension/n = (numpnts(postAvg)+1) postAvg	
				redimension/n = (numpnts(postSD)+1) postSD						
				postAvg[3] = v_avg
				postSD[3]= v_sdev	
			
	//Analyze post5
		i = istart	
			do
				wave cv1 = $DSIWaves_c[i]
					wavestats/q/r = (95.339 ,95.593) cv1
					baseline = v_avg
					wavestats/q/r=(95.645 ,95.663) cv1
					minPeakPoint = x2pnt(cv1, v_minloc)
					post5= ((cv1[minPeakPoint-1]+cv1[minPeakPoint+1]+ cv1[minPeakPoint])/3)-baseline
					redimension/n = (numpnts(postWave5)+1) postWave5; postWave5[Count] = post5
				Count+=1
			i+=1
			while (i<= iend)	
				wavestats/q postWave5
				redimension/n = (numpnts(postAvg)+1) postAvg	
				redimension/n = (numpnts(postSD)+1) postSD						
				postAvg[4] = v_avg
				postSD[4]= v_sdev	
				
			preAvg*=-1; postAvg*=-1
		
			sprintf preWave1Name, "%s%s", baseName, "_preWave1"
				duplicate/o preWave1 $preWave1Name	
			sprintf preWave2Name, "%s%s", baseName, "_preWave2"
				duplicate/o preWave2 $preWave2Name
			sprintf preWave3Name, "%s%s", baseName, "_preWave3"
				duplicate/o preWave3 $preWave3Name
			sprintf preWave4Name, "%s%s", baseName, "_preWave4"
				duplicate/o preWave4 $preWave4Name
			sprintf preWave5Name, "%s%s", baseName, "_preWave5"
				duplicate/o preWave5 $preWave5Name
			sprintf postWave1Name, "%s%s", baseName, "_postWAve1"
				duplicate/o postWAve1 $postWave1Name
			sprintf postWave2Name, "%s%s", baseName, "_postWAve2"
				duplicate/o postWAve2 $postWave2Name
			sprintf postWave3Name, "%s%s", baseName, "_postWAve3"
				duplicate/o postWAve3 $postWave3Name
			sprintf postWave4Name, "%s%s", baseName, "_postWAve4"
				duplicate/o postWAve4 $postWave4Name
			sprintf postWave5Name, "%s%s", baseName, "_postWAve5"
				duplicate/o postWAve5 $postWave5Name
				
			sprintf DSIAvgpreName, "%s%s", baseName, "_DSIpreAvg"
				duplicate/o preAvg $DSIAvgpreName
			sprintf DSIsdpreName, "%s%s", baseName, "_DSIpreSD"
				duplicate/o preSD $DSIsdpreName
			sprintf DSIAvgpostName, "%s%s", baseName, "_DSIpostAvg"
				duplicate/o postAvg $DSIAvgpostName
			sprintf DSIsdpostName, "%s%s", baseName, "_DSIpostSD"
				duplicate/o postSD $DSIsdpostName	
			
						
			//Normalized waves by baseline
			wavestats/q preAvg; BaselineAvg = v_avg
			duplicate/o preAvg preNorm
			duplicate/o postAvg postNorm
			preNorm/=baselineAvg
			postNorm/= baselineAvg
	
			sprintf DSINormpre, "%s%s", baseName, "_DSINormPre"
				duplicate/o preNorm $DSINormpre	
			sprintf DSINormpost, "%s%s", baseName, "_DSINormPost"
				duplicate/o postNorm $DSINormpost	
			
			edit $preWave1Name, $preWave2Name, $preWave3Name, $preWave4Name, $preWave5Name, $postWave1Name, $postWave2Name, $postWave3Name, $postWave4Name, $postWave5Name
			edit $DSIAvgpreName, $DSIsdpreName, $DSIAvgpostName, $DSIsdpostName, $DSINormpre, $DSINormPost
			make/o/n=5 DSIpreTimes
			make/o/n=5 DSIpostTimes
			DSIpreTimes[0]=0; DSIpreTimes[1]=10; DSIpreTimes[2]=20; DSIpreTimes[3]=30; DSIpreTimes[4]=40
			DSIpostTimes[0]=55; DSIPostTimes[1]=65; DSIPostTimes[2]=75; DSIPostTimes[3]=85; DSIPostTimes[4]=95
			
			display $DSIAvgpreName vs DSIpreTimes; appendtograph $DSIAvgpostName vs DSIpostTimes
			ModifyGraph mode=3,marker=16,msize=4
			ModifyGraph rgb[0]=(34952,34952,34952); ModifyGraph rgb[1]=(0,0,0)
			ErrorBars  $DSIAvgpreName Y,wave=($DSIsdpreName,$DSIsdpreName)
			ErrorBars $DSIAvgpostName Y,wave=($DSISDpostName,$DSISDpostName)

			
			cmdstr = "dotline(0,100, " + num2str(baselineAvg) + " )"
			execute cmdstr

			


End


//Created 5-5-2009 by AG.  Puts repeated trials of PPR curve at a given interval onto the same graph.  Allows screening to make sure
//only appropriate trials are averaged using PPRAnalysisAG
Function PPRPreviewAG()
	wave/t PPRWaveList
	variable Count 		//Number of times PPR was repeated
	variable Trials =3 		//trials = 4 if ppr was repeated 5 times
	variable i 
	
	//Gets repeated traces at each interval onto same graph
	display
	dowindow/c PPR25
	
	display
	dowindow/c PPR50
	
	display
	dowindow/c PPR75
	
	display
	dowindow/c PPR100
	
	display
	dowindow/c PPR250
	
	display
	dowindow/c PPR500
	
	do
		dowindow/F PPR25
			appendtograph $PPRWaveList[i]  
		
		dowindow/F PPR50
			appendtograph $PPRWaveList[i+1]  
			
		dowindow/F PPR75
			appendtograph $PPRWaveList[i+2]  
		
		dowindow/F PPR100
			appendtograph $PPRWaveList[i+3]  
			
		dowindow/F PPR250
			appendtograph $PPRWaveList[i+4]  
			
		dowindow/F PPR500
			appendtograph $PPRWaveList[i+5]  
			
		i +=6
		Count +=1
		
		while (count<=(Trials))
				

End


//Created 5-5-2009 by AG.  Analyzes PPR at each interval.  Data should be pre-screened using PPRPreviewAG
Function PPRAnalysisAG()
	string tempWave
	variable v_flag
	variable baseline
	variable peak1, peak2
	variable PPR25, PPR50, PPR75, PPR100, PPR250, PPR500, PPR1000
	variable i
	
	//make sure function cancels
	if(V_flag)
		abort
	endif
	
	make/o/n=0 PPR25Wave
	make/o/n=0 PPR50Wave
	make/o/n=0 PPR75Wave
	make/o/n=0 PPR100Wave
	make/o/n=0 PPR250Wave
	make/o/n=0 PPR500Wave
	make/o/n=0 PPR1000Wave
		
	//Analyze waves with 25 ms interval
	dowindow/F PPR25
	do
		tempWave = WaveName("", i, 1)
		if(strlen(tempWave)==0)
			break
		endif
		duplicate/o $tempWave wv1
		
		//Find baseline
		wavestats/q/r= (0.036, 0.09) wv1
			baseline = v_avg
		//Find peak of first IPSC
		wavestats/q/r=(0.101, 0.12) wv1
			peak1 = baseline - (v_min)
		//Find peak of second IPSC
		wavestats/q/r=(0.1266, 0.14) wv1
			peak2 = baseline - (V_min)
		//Calculate PPR
		PPR25 = peak2 / peak1
	
		
		redimension/n=(numpnts(PPR25Wave)+1) PPR25Wave
		PPR25Wave [i] = PPR25
		
		i+=1
		while (1)

		
	//Analyze waves with 50 ms interval
	i=0
	dowindow/F PPR50
	do
		tempWave = WaveName("", i, 1)
		if(strlen(tempWave)==0)
			break
		endif
		duplicate/o $tempWave wv1
		
		//Find baseline
		wavestats/q/r= (0.036, 0.09) wv1
			baseline = v_avg
		//Find peak of first IPSC
		wavestats/q/r=(0.101, 0.12) wv1
			peak1 = baseline - (v_min)
		//Find peak of second IPSC
		wavestats/q/r=(0.1512, 0.1574) wv1
			peak2 = baseline - (V_min)
		//Calculate PPR
		PPR50 = peak2 / peak1
		
		redimension/n=(numpnts(PPR50Wave)+1) PPR50Wave
		PPR50Wave [i] = PPR50
		
		i+=1
		while (1)
		
	//Analyze waves with 75 ms interval
	i=0
	dowindow/F PPR75
	do
		tempWave = WaveName("", i, 1)
		if(strlen(tempWave)==0)
			break
		endif
		duplicate/o $tempWave wv1
		
		//Find baseline
		wavestats/q/r= (0.036, 0.09) wv1
			baseline = v_avg
		//Find peak of first IPSC
		wavestats/q/r=(0.101, 0.12) wv1
			peak1 = baseline - (v_min)
		//Find peak of second IPSC
		wavestats/q/r=(0.1763, 0.19) wv1
			peak2 = baseline - (V_min)
		//Calculate PPR
		PPR75 = peak2 / peak1
		
		redimension/n=(numpnts(PPR75Wave)+1) PPR75Wave
		PPR75Wave [i] = PPR75
		
		i+=1
		while (1)
		
	//Analyze waves with 100 ms interval
	i=0
	dowindow/F PPR100
	do
		tempWave = WaveName("", i, 1)
		if(strlen(tempWave)==0)
			break
		endif
		duplicate/o $tempWave wv1
		
		//Find baseline
		wavestats/q/r= (0.036, 0.09) wv1
			baseline = v_avg
		//Find peak of first IPSC
		wavestats/q/r=(0.101, 0.12) wv1
			peak1 = baseline - (v_min)
		//Find peak of second IPSC
		wavestats/q/r=(0.201, 0.22) wv1
			peak2 = baseline - (V_min)
		//Calculate PPR
		PPR100 = peak2 / peak1
		
		redimension/n=(numpnts(PPR100Wave)+1) PPR100Wave
		PPR100Wave [i] = PPR100
		
		i+=1
		while (1)
		
	//Analyze waves with 250 ms interval
	i=0
	dowindow/F PPR250
	do
		tempWave = WaveName("", i, 1)
		if(strlen(tempWave)==0)
			break
		endif
		duplicate/o $tempWave wv1
		
		//Find baseline
		wavestats/q/r= (0.036, 0.09) wv1
			baseline = v_avg
		//Find peak of first IPSC
		wavestats/q/r=(0.101, 0.12) wv1
			peak1 = baseline - (v_min)
		//Find peak of second IPSC
		wavestats/q/r=(0.351, 0.371) wv1
			peak2 = baseline - (V_min)
		//Calculate PPR
		PPR250 = peak2 / peak1
		
		redimension/n=(numpnts(PPR250Wave)+1) PPR250Wave
		PPR250Wave [i] = PPR250
		
		i+=1
		while (1)
		
	//Analyze waves with 500 ms interval
	i=0
	dowindow/F PPR500
	do
		tempWave = WaveName("", i, 1)
		if(strlen(tempWave)==0)
			break
		endif
		duplicate/o $tempWave wv1
		
		//Find baseline
		wavestats/q/r= (0.036, 0.09) wv1
			baseline = v_avg
		//Find peak of first IPSC
		wavestats/q/r=(0.101, 0.12) wv1
			peak1 = baseline - (v_min)
		//Find peak of second IPSC
		wavestats/q/r=(0.602, 0.6127) wv1
			peak2 = baseline - (V_min)
		//Calculate PPR
		PPR500 = peak2 / peak1
		
		redimension/n=(numpnts(PPR500Wave)+1) PPR500Wave
		PPR500Wave [i] = PPR500
		
		i+=1
		while (1)		


	//Analyze waves with 1000 ms interval
	i=0
	dowindow/F PPR1000
	do
		tempWave = WaveName("", i, 1)
		if(strlen(tempWave)==0)
			break
		endif
		duplicate/o $tempWave wv1
		
		//Find baseline
		wavestats/q/r= (0.036, 0.09) wv1
			baseline = v_avg
		//Find peak of first IPSC
		wavestats/q/r=(0.101, 0.12) wv1
			peak1 = baseline - (v_min)
		//Find peak of second IPSC
		wavestats/q/r=(1.101, 1.12) wv1
			peak2 = baseline - (V_min)
		//Calculate PPR
		PPR1000 = peak2 / peak1
		
		redimension/n=(numpnts(PPR1000Wave)+1) PPR1000Wave
		PPR1000Wave [i] = PPR1000
		
		i+=1
		while (1)	
		edit PPR25Wave, PPR50Wave, PPR75Wave, PPR100Wave, PPR250Wave, PPR500Wave, PPR1000Wave
		dowindow/c PPRResults
		
		//Calculate avg for each time interval and make PPR graph
		make/o/n=7 PPRInterval
		PPRInterval[0]=25; PPRInterval[1] = 50; PPRInterval[2] = 75; PPRInterval[3] = 100; PPRInterval[4] = 250; PPRInterval[5] = 500; PPRInterval[6] = 1000
		
		make/o/n=7 PPRavg
		make/o/n=7 PPRsd
			wavestats/q PPR25Wave
			PPRavg[0] = v_avg
			PPRSD[0] =v_sdev
			
			wavestats/q PPR50Wave
			PPRavg[1] = v_avg
			PPRSD[1] =v_sdev
			
			wavestats/q PPR75Wave
			PPRavg[2] = v_avg
			PPRSD[2] =v_sdev
			
			wavestats/q PPR100Wave
			PPRavg[3] = v_avg
			PPRSD[3] =v_sdev
			
			wavestats/q PPR250Wave
			PPRavg[4] = v_avg
			PPRSD[4] =v_sdev
			
			wavestats/q PPR500Wave
			PPRavg[5] = v_avg
			PPRSD[5] =v_sdev
			
			wavestats/q PPR1000Wave
			PPRavg[6] = v_avg
			PPRSD[6] =v_sdev
			
			edit PPRInterval, PPRavg, PPRsd
			
			display PPRAvg vs PPRInterval
			ModifyGraph mode=4,marker=19,msize=4,rgb=(0,0,0)
			SetAxis left 0,2
			Execute "dotline(25,1000,1)"
			SetAxis bottom 0,1000; ModifyGraph manTick(bottom)={0,100,0,0},manMinor(bottom)={1,0}
			ErrorBars PPRavg Y,wave=(PPRsd,PPRsd)
			


End




/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////



//Created 10-17-08
//Note, sampling rate for fast spikes is a bit of an issue- spike times aren't exactly at the peak of each spike.
Function GraphRate([win_name])
	string win_name
	variable threshold = -20
	string RateDisplayName, TimeDisplayName
	string Name
	
	
	//These lines magically get the waves you want off the SweepsWin window
	win_name=selectstring(paramisdefault(win_name),win_name,winname(0,1))
	string traces = TraceNameList(win_name, ";", 1)
	string trace = StringFromList(0,traces)
	Wave TraceWave=TraceNameToWaveRef(win_name,trace)

	FindSpikeTimesAG(TraceWave, 0, 30, Threshold)
	
	sprintf RateDisplayName "%s%s", "Rates_", trace 
		duplicate/o SpikeRates $RateDisplayName
	sprintf  TimeDisplayName "%s%s", "Times_", trace 
		duplicate/o SpikeTimes $TimeDisplayName
		
	display $RateDisplayName vs $TimeDisplayName	
	ModifyGraph mode=3,marker=19,msize=2;ModifyGraph rgb=(0,0,0)
	
	cd :

End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function SpikeShapeAnalysis([win_name])
	string win_name
	variable i, j, k, m
	variable startTime, endTime
	variable threshold = -35
	variable trainTime, binLength
	variable startAnalysis = 1.1
	variable EndAnalysis = 2
	variable APPeak, halfMaxPoint1, halfMaxPoint2, halfMax, halfheight, Apht
	variable deltaOne, SampleRate
	variable pnt1, pnt2, numSpikes, AvgRate
	variable ThreshPnt, APThresh
	variable APwidth, FirstCrossing, SecondCrossing, NumberOfSpikes
	string SpkName, RateString, CVString, SpikeParametersName, SpikeParamOutputName, avgSpkWvName
	string SpkTotalName, SpikeTimesName, SpikeRatesName, avgNameWave, nSpikesString
	variable AHPVm, AHP, CVvar, FRvar
	string baseName
	wave/t spkWaveNames
	prompt startAnalysis, "Time to start Analysis"
	prompt baseName, "BaseName"
	doprompt "", startAnalysis, baseName
	
	
//These lines magically get the waves you want off the SweepsWin window
	win_name=selectstring(paramisdefault(win_name),win_name,winname(0,1))
	string traces = TraceNameList(win_name, ";", 1)
	string firsttrace =  stringfromlist(0,traces)
//	wave wv1 = tracenametowaveref(win_name, firsttrace)
	make/o/n=0 CVwave
	make/o/n=0 FRwave
	make/o/n=0 nSpikesWave
//for loop goes through each wave on graph until there aren't anymore
	for(j=0;j<ItemsInList(traces);j+=1)
		string trace = StringFromList(j,traces)
		Wave TraceWave=TraceNameToWaveRef(win_name,trace)
		print Trace
		startTime = startanalysis  //resets start and end time to prompted values
		endTime = endAnalysis  //resets start and end time to prompted values
			i=0
			do 
				startTime = startanalysis  //resets start and end time to prompted values
				endTime = endAnalysis  //resets start and end time to prompted values
				FindSpikeTimesAG(TraceWave,startTime,endTime,Threshold)
				wave spikeIntervals, spikeTimes, spikePeakVoltages, spikeRates
			 	startTime = SpikeTimes[0]
			 	EndTime = SpikeTimes[numpnts(spikeRates)]
				//save out each spike as individual wave; use constant interval before and after spike
				pnt1=spikeTimes[i]-0.02	//time interval before spike: 20 ms before peak
				pnt2=spikeTimes[i] + 0.04	//time interval after spike: 40 ms after peak
				duplicate/o/r = (pnt1, pnt2) TraceWave pieceWave	
				//offset peak of each spike to zero
				deltaOne = (spikeTimes[i] - pnt1) 
				SampleRate = deltax(pieceWave)
				SetScale/P x -deltaOne,SampleRate,"",pieceWave		
				//give waves unique names and put them on a graph
				sprintf spkName, "%s%g%s%s", "Spk_",k, "_", baseName		
				duplicate/o pieceWave $spkName
					if (k==0)
						display $spkName
					else
						appendtograph $spkName
					endif 	//*
				i+=1
				k+=1
			while (i<numpnts(spikeTimes))
			//edit spikeintervals, spikerates
			
			//Calculate CV and firing rate
			wavestats/q spikeintervals
				CVvar = (v_sdev / v_avg)
				redimension/n=(j+1) CVwave
				CVwave[j] = CVvar
			wavestats/q SpikeRates
				FRvar = v_avg
				redimension/n=(j+1) FRwave
				FRwave[j] = v_avg
			NumberOfSpikes = numpnts(SpikeRates)+1
				redimension/n=(j+1) nSpikesWave
				nSpikesWave[j] = NumberOfSpikes
		endfor
		 
		 edit CVwave, FRwave, nSpikesWave
		//calculate avg FR and CV across all traces
		wavestats/q CVwave
			variable CVfinal = v_avg
			CVString = Num2Str(CVfinal)
					
		wavestats/q FRwave
			variable FRfinal = v_avg
			RateString = Num2Str(FRfinal)
			
		wavestats/q nSpikesWave
			variable nSpikesFinal = v_sum
			nSpikesString = Num2Str(nSpikesFinal)
			print "Spikes analyzed = ", nSpikesFinal
	
		//Average spikes together
		displaymeantrace()
			wave Mean_65535_0_0_mean
			ModifyGraph rgb(Mean_65535_0_0_mean)=(0,0,0)
			sprintf avgNameWave, "%s%s", "Avg_", baseName		
			duplicate/o Mean_65535_0_0_mean $avgNameWave
			
		//put avg firing rate and CV on graph
		display $avgNameWave
		TextBox/C/N=text0/F=0/A=RT/X=8  "CV = " + CVString 
		TextBox/C/N=text1/F=0/A=RT/Y=-2 "FR = " + RateString + " Hz"
		ModifyGraph rgb=(0,0,0)
		
		//Analyze Spike Parameters//////////////////////////////////////////////////////////////////////////////
		wave AvgSpike =$avgNameWave
		make/o/t/n=10 SpikeParameters 
		SpikeParameters[0] = "AP Thresh"; SpikeParameters[1] = "Spike Width"; SpikeParameters[2] = "Half width"; 
		SpikeParameters[3] = "AHP Vm"; SpikeParameters[4] = "AHP"; SpikeParameters[5] = "PeakVm"; 
		SpikeParameters[6] = "Spk Ht"; SpikeParameters[7] = "Rate"; SpikeParameters[8] = "CV"; SpikeParameters[9] = "n spikes"
		make/o/n=10 SpikeParamOutput
		SpikeParamOutput=nan
		
		//Find APThreshold by looking at 2nd derivative (when 2nd deriv exceeds 3e8)
			duplicate/o avgSpike derivAvgSpike
				differentiate derivAvgSpike
			duplicate/o derivAvgSpike deriv2AvgSpike
				differentiate deriv2AvgSpike
			findlevel/q/P/Edge=1 deriv2AvgSpike, 3e+08
			if (v_flag==1)
				print "No thresh found, use 3e7"
				findlevel/q/P/Edge=1 deriv2AvgSpike, 3e+07
			endif
				Threshpnt = v_levelX
			APThresh = avgSpike[ThreshPnt]
			SpikeParamOutput[0]=APThresh
			
		//Find Spike Width (from threshold to threshold)
			//width
			findlevel/q/r=(-0.0076, -0.0001)/Edge=1 avgSpike, APThresh
				FirstCrossing= v_LevelX
			findlevel/q/r=(0.00026, 0.01)/Edge=2 avgSpike, APThresh
				SecondCrossing= v_LevelX
			APwidth = SecondCrossing-FirstCrossing
				APwidth*=1000 //convert to ms
			SpikeParamOutput[1]=APwidth
				
			//width at half height
			wavestats/q/r=(FirstCrossing, SecondCrossing) avgSpike
			APpeak = v_max
				SpikeParamOutput[5] = APpeak	//assign spike peak
					APht = APpeak - APThresh	//calculate spike height from threshold
					SpikeParamOutput[6] = APht
			halfheight =  (APThresh  - APPeak)/2
			findlevel/q/r=(FirstCrossing, 0) avgSpike, halfheight
				halfMaxPoint1 = v_levelX
			findlevel/q/r=(0, SecondCrossing) avgSpike, halfheight
				halfMaxPoint2 = v_levelX
			halfMax = halfMaxPoint2- halfMaxPoint1
				halfMAx*=1000 //convert to ms
			SpikeParamOutput[2]=halfMax
				
				
			//Find AHP (2nd threshold crossing to min after spike)
			findlevel/q/r=(0.00026, 0.01)/Edge=2 avgSpike, APThresh
				SecondCrossing= v_LevelX
			wavestats/q/r=(SecondCrossing, 0.006) avgSpike
			AHPVm = v_min
			AHP = APThresh-  AHPVm
			SpikeParamOutput[3]=AHPVm
			SpikeParamOutput[4]=AHP
			SpikeParamOutput[5]= APpeak
			SpikeParamOutput[6]= APht
			SpikeParamOutput[7]= FRfinal
			SpikeParamOutput[8] = CVfinal
			SpikeParamOutput[9] = k
			
			//give output waves unique names
			sprintf SpikeParametersName, "%s%s", "SpkParams_", baseName
				duplicate/o SpikeParameters $SpikeParametersName
			sprintf SpikeParamOutputName, "%s%s", "SpkParamOutput_", baseName
				duplicate/o SpikeParamOutput $SpikeParamOutputName
			
		
		edit $SpikeParametersName, $SpikeParamOutputName
			
	
		

	
	

End



	//inset at * to create text wave with ref names for pieces
	//					if (waveexists(spkWaveNames)==0)
			//						make/o/t/n=0 spkWaveNames
			//					endif
			//				Redimension/n=(k+1) SpkWaveNames
			//				SpkWaveNames[k]=spkName	
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function IFplot([win_name])
	string win_name
	variable i,j,m,k,h
	variable istart, iend ///to delete
	variable startTime =1
	variable endTime = 2
	variable VmRest, CurrentStart, CurrentEnd, FRinitial, FRend, ARratio
	string cmdString, RateDisplayName, TimeDisplayName
	wave/t istepsWaves_w
	string baseName, IFPlotOutputName, IFPlotDataName
	variable threshold = -20
	variable hypNum, RateNum
	variable FRvar, InputCurrent
	variable count
	variable curr_sweep = GetCurrSweep() // Current sweep number. 
	variable num_channels = GetNumChannels() // Number of channels. 
	string FRWaveName, InputCurrentWaveName , InputValue, ARratioName
	wave StimulusAmpls_0
	prompt baseName, "baseName"
	doprompt "Select wave range istepsanalysis", baseName

	if (waveExists(StimulusAmpls_0)==0)
		StimulusTable()
	Endif
	
	//make sure function cancels
	if(V_flag)
		abort
	endif
		
	//waves to hold info 
	make/o/n=0 FRwave
	make/o/n=0 InputCurrentWave
	make/o/n=0 FirstHundred
	make/o/n=0 LastHundred
	make/o/n=0 ARratioWave
	
	//output waves
	make/o/t/n=11 IFplotOutput
	IFplotOutput[0] = "maxFR"
	IFplotOutput[1] = "Rheobase"
	IFplotOutput[2] = "Input Range"
	IFplotOutput[3] = "Cell attached rate"
	IFPlotOutput[4] = "Cell attached CV"
	IFplotOutput[5] = "tau_fast"
	IFplotOutput[6] = "tau_slow"
	IFplotOutput[7] = "Linear slope"
	IFplotOutput[8] = "Adaptation 50 Hz"
	IFplotOutput[9] = "Adaptation 150 Hz"
	IFplotOutput[10] = "Adaptation 250 Hz"
	
	make/o/n=11 IFPlotData
	IFPlotData = nan
	
	//These lines magically get the waves you want off the SweepsWin window
	win_name=selectstring(paramisdefault(win_name),win_name,winname(0,1))
	string traces = TraceNameList(win_name, ";", 1)
	
	//for loop goes through each wave on graph until there aren't anymore
	for(i=0;i<ItemsInList(traces);i+=1)
		string Trace =  stringfromlist(i,traces)
		Wave TraceWave=TraceNameToWaveRef(win_name,trace)
		string labell = getwavesdatafolder(TraceWave,0)
		variable chan = GetLabelChan(labell)
		variable sweepNum
		sscanf nameofwave(traceWave),"sweep%d",sweepNum
		InputCurrent = GetEffectiveAmpl(chan,sweepNum=sweepNum)
		variable strLength = strlen(Trace)
			if (strLength >=12)	
				 InputValue = Trace[12,strLength]
			else
				 InputValue = Trace[5, strLength]
			endif
		variable SweepPoint = str2num(inputValue); //print SweepPoint
			if (SweepPoint == nan)	//Catch times when sweep number is not read correctly...but doesn't actually work
				print "Couldn't find number of sweep"
				abort
			endif	
		InputCurrent =  StimulusAmpls_0[SweepPoint]
			redimension/n=(i+1) InputCurrentWave
			InputCurrentWave[i] = InputCurrent
		FindSpikeTimesAG(TraceWave, startTime, endTime, Threshold)
		wave spikeRates, spikeTimes;// edit spikeRates, SpikeTimes
		//Finds the average firing rate across the whole second
			wavestats/q spikeRates
			FRvar = v_avg
			redimension/n=(i+1) FRwave
			FRwave[i] =FRvar
		//Finds the adaptation ratio
		for (j=0; j<(numpnts(spikeTimes)); j+=1)
			if (SpikeTimes[j] > 1 && SpikeTimes[j]  < 1.1)
				redimension/n=(k+1) FirstHundred
				FirstHundred[k] = SpikeRates[j]
				k+=1
			endif
			if (SpikeTimes[j] > 1.9 && SpikeTimes[j] <2)
				redimension/n=(m+1) LastHundred
				LastHundred[m] = SpikeRates[j-1]
				m+=1
			endif
		endfor				
				if (numpnts(FirstHundred)>0)
					wavestats/q FirstHundred
					FRinitial = v_avg
					else
					FRinitial = nan
					print "for ", Trace, " trace, not enough spikes for adaptation"
				endif
				if (numpnts(LastHundred)>0)
					wavestats/q LastHundred
					FRend = v_avg
					else
					FRend = nan
					print "for ", j, " trace, not enough spikes for adaptation"
				endif
			//Calculate adaptation ratio
				//	print "FR end = ", FRend
				//	print "FRinitial = ", FRinitial
					ARratio = FRend / FRinitial
					redimension/n=(i+1) ARratioWave
					ARratioWave[i] = ARratio
		endfor
	
	//Create IF plot
	sprintf FRWaveName, "%s%s", "FR_", baseName
		duplicate/o FRWave $FRWaveName
	sprintf InputCurrentWaveName, "%s%s", "Current_", baseName
		duplicate/o InputCurrentWave $InputCurrentWaveName
	display $FRwaveName vs $InputCurrentWaveName
		ModifyGraph mode=4,marker=19
		
	//Create adatpation ratio graph
	sprintf ARratioName, "%s%s", "Adapt_", baseName
		duplicate/o ARratioWave $ARratioName
	display $ARratioName vs $FRWaveName
		ModifyGraph mode=4,marker=19
		SetAxis left 0.5,1
		
	//Get max FR
	variable pntsFRWave = numpnts(FRWave)
	IFPlotdata[0]= FRWave[pntsFRWave]
	
	//Get Rheobase
	if (FRWave[0] ==0)
		if (FRWave[1]==0)
			if (FRWave[2]==0)
				IFPlotdata[1] = InputCurrentWave[3]
			endif
			IFPlotdata[1] = InputCurrentWave[2]
		endif
		IFPlotdata[1]=  InputCurrentWave[1]
	else
		IFPlotdata[1] = InputCurrentWave[0]
	endif
	
	//Get dynamic input range
	IFPlotdata [2] = InputCurrentWave[pntsFRWave] - InputCurrentWave[0]
	
	//Get fits to I-F plot
	CurveFit/q/M=2/W=0 dblexp_XOffset,FRWave/X=InputCurrentWave/D
		wave W_Coef
		variable FastTau = W_coef[4]
		variable SlowTau = W_Coef[2]
		IFPlotdata[5] = FastTau
		IFplotData[6] = SlowTau
		
	//Adaptation at different firing rates
	for(h=0;h<numpnts(FRWave);h+=1)
		if (FRWave[h]>30&&FRWave[h] <70)	//AR for ~50 Hz
			IFPlotData[8] = ARRatioWave[h]
		endif
		if (FRWave[h]>120&&FRWave[h] <180)	//AR for ~150 Hz
			IFPlotData[9] = ARRatioWave[h]
		endif
		if (FRWave[h]>200&&FRWave[h] <260)	//AR for ~250 Hz
			IFPlotData[10] = ARRatioWave[h]
		endif
	endfor
		
	sprintf IFPlotOutputName, "%s%s", "IFOutput_", baseName
		duplicate/o IFPlotOutput $IFPlotOutputName
	sprintf IFPlotDataName, "%s%s", "IFData_", baseName
		duplicate/o IFPlotData $IFPlotDataName
	
	edit $IFPlotOutputName, $IFPlotDataName
//	edit  IFPlotOutput, IFPlotData
		


		

		
		

	
	
	abort
	

		
	
			


	do
		wave wv1 = $istepsWaves_w[i]
			FindSpikeTimesAG(wv1, 0.05, 0.5, Threshold)
			wave SpikeTimes
			wave SpikeRates
			
			if (numpnts(SpikeTimes)>=1)
				wavestats/q spikeRates		//this is where the error is
				redimension/n=(numpnts(RateResponse)+1) RateResponse
				redimension/n=(numpnts(istepsDisplay2)+1) istepsDisplay2
			//	RateResponse[RateNum] = v_avg
				RateNum+=1
				wavestats/q/r=(0.05, 0.5) wv1
				redimension/n=(numpnts(hypResponse)+1) hypResponse
				redimension/n=(numpnts(istepsDisplay1)+1) istepsDisplay1
			//	hypResponse[hypNum] = v_avg
				hypNum+=1
			//	istepsDisplay2[RateNum] = istepsValues[i]
			//	istepsDisplay1[hypNum] = istepsValues[i]
			endif
				//make adaptation graph
				dowindow/F AdaptationGraph
					sprintf RateDisplayName "%s%g", "Rates_", i 
						duplicate/o SpikeRates $RateDisplayName
					sprintf  TimeDisplayName "%s%g", "Times_", i 
						duplicate/o SpikeTimes $TimeDisplayName
				appendtograph $RateDisplayName vs $TimeDisplayName
				ModifyGraph mode=3,marker=19,msize=2,rgb=(0,0,0)
				SetAxis bottom 0,0.6
	

		count+=1
		i+=1
		while (i<=iend)

	//display the FR vs input graph and do linear fit to measure gain				
		display RateResponse vs istepsDisplay2
			ModifyGraph mode=4,marker=19,msize=3
			ModifyGraph msize=4,rgb=(0,0,0)
			label left "Firing Rate (Hz)"; label bottom "Input (pA)"
			CurveFit/q/NTHR=0 line  rateresponse /X=istepsdisplay2 /D 
			variable gain
		//	gain = w_coef[1]*1000
			
	//Find the slope of positive current injections
	CurveFit/q/NTHR=0 line  hypResponse[3,(i)] /X=istepsDisplay1 /D 
	variable PosSlope
	//PosSlope =W_coef[1]
	
	//Calculate rectification (NegSlope / PosSlope)
		variable rectification
	//	rectification = (NegSlope / PosSlope)
		
	//Find maxFR 
	variable maxFR
	variable numRateResponse
	numRateResponse = numpnts(RateResponse)
//	maxFR = RateResponse[numRateResponse]
	
	//Find rheobase
	variable instFR
	variable rheobase
	variable p
		do
//		instFR = RateResponse[p]
			if (instFR>0)
//			print rateresponse[p]
//				rheobase = istepsDisplay2[p]
				break
			endif
		while (i<numpnts(rateresponse))
		

//Create wave to store output
	wave istepsValues
	make/o/n=0 hypResponse
	make/o/n=0 RateResponse
	make/o/n=0 istepsDisplay1
	make/o/n=0 istepsDisplay2
	make/o/n=100 VmWave; VmWave=nan
	
	make/o/n=7 OutputWave
	make/o/t/n=7 OutputWaveTitle
	
	OutputWaveTitle[0] = "Vm rest"
	OutputWaveTitle[1] = "HypSlope"
	OutputWaveTitle[2] = "PosSlope"
	OutputWaveTitle [3] = "rectification"
	OutputWaveTitle[4 ] = "Gain"
	OutputWaveTitle[5] = "maxFR"
	OutputwaveTitle[6] = "rheobase"
			
	//Creat table withoutput values
	edit OutputWaveTitle, Outputwave
	
	OutputWave[0] = VmRest
//	OutputWave[1] = NegSlope
	OutputWave[2] = PosSlope
	OutputWave[3] = rectification
	OutputWave[4] = Gain
	OutputWave[5] = maxFR
	OutputWave[6] = rheobase
			

End


Function Plateau()
	variable v_flag
	string tempWave
	variable i
	string wv1
	variable baseline, post, plateau
	
	//make sure function cancels
	if(V_flag)
		abort
	endif
	
	//get  wave off graph
	wv1 = WaveName("", i, 1)
	
	 wavestats/q/r=(0,0.05) $wv1
	 	baseline = v_avg
	wavestats/q/r=(0.55,0.6) $wv1
		post = v_avg
		
	plateau = post - baseline
	print plateau
End



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function AltDynamics()
	variable v_flag
	variable istart, iend, i
	variable baseline
	variable xPoint1, xPoint2, minPeakPoint
	variable SpikeNum
	variable nextIPSC, nextIPSCPoint
	variable minPeakx
	variable ipsc
	variable W_coef0, w_coef1, w_coef2, w_fitConstant, x, fit
	variable nextMinPeakPoint
	variable scaling,  NormValue
	variable Range1, Range2
	variable nextIPSCmin, FreqNum, frequency, count, OverLimit
	string startEpoch, EndEpoch
	string baseName
	string tempString, MatchString
	string ipscAmpName, ipscNormName
	prompt startEpoch, "First Epoch"
	prompt EndEpoch, "Last Epoch"
	prompt baseName, "baseName"
	doprompt "Select wave range for DSI", startEpoch, EndEpoch, baseName
	
	
	
	wave w_coef, w_fitConstants

	//make sure function cancels
	if(V_flag)
		abort
	endif
	
	//Declare waves (creqted during acquisition)
	wave/t DynamicsWaves_w
	wave/t DynamicsWaves_c
	
	make/o/n=10 SpikeNumDisplay 
				SpikeNumDisplay[0]=1; SpikeNumDisplay[1]=2; SpikeNumDisplay[2]=3; SpikeNumDisplay[3]=4; SpikeNumDisplay[4]=5;
				SpikeNumDisplay[5]=6;SpikeNumDisplay[6]=7; SpikeNumDisplay[7]=8; SpikeNumDisplay[8]=9; SpikeNumDisplay[9]=10
		
	do
		if (strlen(DynamicsWaves_w[i]) ==0)
			break
		endif
		tempString = DynamicsWaves_w[i]
		matchString = tempString[1, strlen(tempString)]
		
		if (stringmatch (matchString, startEpoch)==1)
			istart = i
		endif
		if (stringmatch (matchString, EndEpoch)==1)
			iend = i
		endif
	i+=1
	while (1)

	//make average for 10 Hz traces
	i = istart
	do
		wave cv1 = $DynamicsWaves_c[i]
		if (count==0)
			duplicate/o cv1 Avg10
		else
			Avg10+=cv1
				OverLimit = i+4
				if (OverLimit> iend)
					Avg10/=(Count+1)
					display Avg10
				endif
		endif
		i+=4
		Count+=1
		while (i<=iend)
		
	//make average for 20 Hz traces
	i = istart+1; Count=0
	do
		wave cv1 = $DynamicsWaves_c[i]
		if (count==0)
			duplicate/o cv1 Avg20
		else
			Avg20+=cv1
			OverLimit = i+4
				if (OverLimit> iend)
					Avg20/=(Count+1)
					display Avg20
				endif
		endif
		i+=4
		Count+=1
		while (i<=iend)
		
	//make average for 50 Hz traces
	i = istart+2; Count=0
	do
		wave cv1 = $DynamicsWaves_c[i]
		if (count==0)
			duplicate/o cv1 Avg50
		else
			Avg50+=cv1
			OverLimit = i+4
				if (OverLimit> iend)
					Avg50/=(Count+1)
					display Avg50
				endif
		endif
		i+=4
		Count+=1
		while (i<=iend)
		
	//make average for 100 Hz traces
	i = istart+3; Count=0
	do
		wave cv1 = $DynamicsWaves_c[i]
		if (count==0)
			duplicate/o cv1 Avg100
		else
			Avg100+=cv1
			OverLimit = i+4
				if (OverLimit> iend)
					Avg100/=(Count+1)
					display Avg100
				endif
		endif
		i+=4
		Count+=1
		while (i<=iend)

//Do the analysis
do
		SpikeNum=0
		if (FreqNum==0)
			duplicate/o Avg10 AVgTemp
			make/o/n=10 WaveTimes; WaveTimes[0] = 0.1; WaveTimes[1] = 0.2; WaveTimes[2] = 0.3; WaveTimes[3] = 0.4; WaveTimes[4] = 0.5;
			WaveTimes[5] = 0.6; WaveTimes[6] = 0.7; WaveTimes[7] = 0.8; WaveTimes[8] = 0.9; WaveTimes[9] = 1
			frequency = 10
		endif
		if (FreqNum==1)
			duplicate/o Avg20 AvgTemp
			make/o/n=10 WaveTimes; WaveTimes[0] = 0.1; WaveTimes[1] = 0.15; WaveTimes[2] = 0.2; WaveTimes[3] = 0.25; WaveTimes[4] = 0.3;
			WaveTimes[5] = 0.35; WaveTimes[6] = 0.4; WaveTimes[7] = 0.45; WaveTimes[8] = 0.5; WaveTimes[9] = 0.55
			frequency = 20
		endif
		if (FreqNum==2)
			duplicate/o Avg50 AvgTemp
			make/o/n=10 WaveTimes; WaveTimes[0] = 0.1; WaveTimes[1] = 0.12; WaveTimes[2] = 0.14; WaveTimes[3] = 0.16; WaveTimes[4] = 0.18;
			WaveTimes[5] = 0.2; WaveTimes[6] = 0.22; WaveTimes[7] = 0.24; WaveTimes[8] = 0.26; WaveTimes[9] = 0.28
			frequency = 50
		endif
		if (FreqNum==3)
			duplicate/o Avg100 AvgTemp
			make/o/n=10 WaveTimes; WaveTimes[0] = 0.1; WaveTimes[1] = 0.11; WaveTimes[2] = 0.12; WaveTimes[3] = 0.13; WaveTimes[4] = 0.14;
			WaveTimes[5] = 0.15; WaveTimes[6] = 0.16; WaveTimes[7] = 0.17; WaveTimes[8] = 0.18; WaveTimes[9] = 0.19
			frequency = 100
		endif
		
		duplicate/o AvgTemp ResponseWAve
		
		make/o/n=0 ipscAmpWave
	
			Wavestats/q/r=[362, 940] ResponseWave
				baseline = v_avg	
			do	
				xPoint1 = WaveTimes[SpikeNum]
				xPoint2 = xPoint1+0.01
				nextIPSC = WaveTimes[SpikeNum+1]
				//IPSC analysis
				Wavestats/q/r=(xPoint1, xPoint2) ResponseWave	
					minPeakPoint = x2pnt(ResponseWave, v_minloc)
					if(SpikeNum!=9)
						Scaling = deltax(ResponseWave);nextIPSCpoint = nextIPSC/scaling
						CurveFit/q exp_XOffset  ResponseWave[minPeakPoint, nextIPSCpoint] /D 
					endif
					ipsc = ((ResponseWave[minPeakPoint-1]+ResponseWave[minPeakPoint+1]+ ResponseWave[minPeakPoint])/3)-baseline	//Finds amplitude of first IPSC
				redimension/n=(numpnts(ipscAmpWave)+1) ipscAmpWave
				ipscAmpWave[spikeNum] = ipsc
				//Extrapolate where voltage would be at end of IPSC to get a baseline for the next IPSC in train; if there is a failure (amp < 20 pA), avg to get baseline
				if (SpikeNum!=9)
						Range1 = WaveTimes[SpikeNum+1]
						Range2 = Range1+0.01
						Wavestats/q/r=(Range1, Range2) ResponseWave		//detect min peak of next IPSC
								NextIPSCmin =  v_minloc	
						if (abs(ipscAmpWave[spikeNum])>20)
							W_coef0 = W_coef[0]	
							W_coef1 = W_coef[1]
							W_coef2 = W_coef[2]
							W_fitConstant = W_fitConstants[0]
							x = NextIPSCmin
							fit= W_coef0+W_coef1*exp(-(x-W_fitConstants)/W_coef2)
							baseline = fit
						else
							Wavestats/q/r=((Range1-0.001), Range1) ResponseWave
							baseline = v_avg
							print "Failure to First Spike"; print SpikeNum
						endif
					endif
		
				SpikeNum+=1
				while (SpikeNum<=9)
				
			//Do the normalization
			duplicate/o ipscAmpWave ipscNormWave
			NormValue = ipscNormWave[0]
			ipscNormWave/=NormValue
			
			sprintf ipscAmpName, "%s%s%g", baseName, "_ipscAMP_", frequency
			duplicate/o ipscAmpWave $ipscAmpName
			sprintf ipscNormName, "%s%s%g", baseName, "_Norm", frequency
			duplicate/o ipscNormWave $ipscNormName
			
			if (FreqNum==0)
				edit $ipscAmpName, $ipscNormName
				display $ipscNormName vs SpikeNumDisplay
			else
				Appendtotable $ipscAmpName, $ipscNormName
				appendtograph $ipscNormName vs SpikeNumDisplay
					if (FreqNum==3)
						ModifyGraph mode=4,marker=19, msize = 4
						Execute "AgColors()"
						ModifyGraph manTick(bottom)={1,1,0,0},manMinor(bottom)={0,0}
					endif
			endif
			
				
		FreqNum+=1
		//print FreqNum
		while (FreqNum<=3)
		
		
							

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function EPSCtrain()
	string tempWave
	variable V_flag
	variable baseline
	variable Time1, Time2
	variable freq, int
	variable Amp
	variable tauTime1, tauTime2
	variable w_coef0, w_coef1, w_coef2, W_fitConstant, x, fit
	variable nextTime1, nextTime2, nextEPSC
	variable i
	variable/g RunAlready
	string NewWaveName
	prompt Freq, "Frequency"
	doprompt "", Freq
	wave w_coef, W_fitConstants

//make sure function cancels
	if(V_flag)
		abort
	endif
		
		//get  wave off graph
		tempWave = WaveName("", 0, 1)
		duplicate/o $tempWave wv1
		
		//Calculate baseline
	//	wavestats/q/r=(0.0234, 0.06) wv1
		wavestats/q/r=(0.035, 0.0892) wv1
		baseline = v_avg
		wv1-=baseline
		
		make/o/n=0 AmpsWave
			
		if (RunAlready==0)
			edit
			dowindow/c TopGraph
			RunAlready=1
		endif
				
		if (freq == 1)
			int = 1
		endif
		if (freq == 10)
			int = 0.1
		//int = 0.0982
		endif
		if (freq == 20)
			int = 0.05
		//int = 0.0482
		endif
		if (freq == 50)
			int = 0.02
		//int = 0.0182
		endif
		if (freq == 100)
			int = 0.01
		endif
		
	//	Time1 = 0.0668
	//	Time2 = 0.0673
	//	Time1= 0.1026
	//	Time2 = 0.1043
	Time1= 0.103
	Time2 = 0.12

	//Calculate EPSC amplitude
		wavestats/q/r=(Time1, Time2) wv1
		redimension/n=(numpnts(AmpsWave)+1) AmpsWave
		Amp = V_min
		AmpsWave[0]= v_min
		i=1
		//print time1, time2, amp
wave fit_wv1
	do
		//Extrapolate where voltage would be at end of IPSC to get a baseline for the next EPSC in train
				tauTime1 = v_minLoc
				tauTime2 = v_minLoc + int-0.004//-0.008
				CurveFit/q exp_XOffset  wv1(tauTime1,tauTime2) /D 
					NextTime1 = Time1+int
					NextTime2 = Time2+int
					wavestats/q/r=(Nexttime1, NextTime2) wv1
					x = v_minLoc
				//Extrapolate to determine baseline for second spike
							W_coef0 = W_coef[0]	
							W_coef1 = W_coef[1]
							W_coef2 = W_coef[2]
							W_fitConstant = W_fitConstants[0]
							baseline= W_coef0+W_coef1*exp(-(x-W_fitConstants)/W_coef2)		
//							if (i==6)
//								display wv1; appendtograph fit_wv1
//							//	print tauTime1, TauTime2
//							//	abort
//							endif
//							
		
			Time1+=int
			Time2+=int
			//Calculate EPSC amplitude
			wavestats/q/r=(Time1, Time2) wv1
			redimension/n=(numpnts(AmpsWave)+1) AmpsWave
		AmpsWAve[i] = V_min-baseline		
//			if (i==8)
////				print baseline
//				print Time1, Time2
////			abort
//			endif
//		
	i+=1
	while (i<=9)


		sprintf NewWaveName, "%s%g", "EPSCAmps_", freq
		duplicate/o AmpsWave $NewWaveName
		
		dowindow/F TopGraph
		appendtotable $NewWaveName
	
End

Function MakeNormEPSC()
	wave EPSCAmps_1
	wave EPSCAmps_20
	wave EPSCAmps_50
	wave EPSCAmps_10
	wave EPSCAmps_100

	
	make/o/n=10 SpikeNumWave
		SpikeNumWave[0] = 1
		SpikeNumWave[1] = 2
		SpikeNumWave[2] = 3
		SpikeNumWave[3] = 4
		SpikeNumWave[4] = 5
		SpikeNumWave[5] = 6
		SpikeNumWave[6] = 7
		SpikeNumWave[7] = 8
		SpikeNumWave[8] = 9
		SpikeNumWave[9] = 10
	
//	
////	duplicate/o EPSCAmps_1 EPSCNorm1
////		EPSCNorm1/=EPSCAmps_1[0]
	duplicate/o EPSCAmps_10 EPSCNorm10
		EPSCNorm10/=EPSCAmps_10[0]
	duplicate/o EPSCAmps_20 EPSCNorm20
		EPSCNorm20/=EPSCAmps_20[0]
	duplicate/o EPSCAmps_50 EPSCNorm50
		EPSCNorm50/=EPSCAmps_50[0]
	duplicate/o EPSCAmps_100 EPSCNorm100
		EPSCNorm100/=EPSCAmps_100[0]
		
	display  EPSCNOrm1, EPSCNorm10, EPSCNorm20, EPSCNorm50, EPSCNorm100  vs SpikeNumWave
	display  EPSCNorm10, EPSCNorm20, EPSCNorm50, EPSCnorm100 vs SpikeNumWave
	ModifyGraph mode=4,marker=19,msize=4
	Execute "AGcolors()"
	Legend/C/N=text0/J/F=0/A=RT "\\s(EPSCNorm1) 1 Hz\r\\s(EPSCNorm10) 10 Hz\r\\s(EPSCNorm20) 20 Hz\r\\s(EPSCNorm50) 50 Hz\r\\s(EPSCNorm100) 100Hz"
	//Legend/C/N=text0/J/F=0/A=RT "\\s(EPSCNorm10) 10 Hz\r\\s(EPSCNorm20) 20 Hz\r\\s(EPSCNorm50) 50 Hz\r\\s(EPSCNorm100) 100Hz"
	
//	edit EPSCNorm10, EPSCNorm20, EPSCNorm50, EPSCNorm100
	edit EPSCNorm1, EPSCNorm10, EPSCNorm20, EPSCNorm50, EPSCNorm100
	



End
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Function NaturalTrainAnalysis()
	variable v_flag, i
	variable baseline, minpeakPoint
	wave w_coef
	wave W_fitconstants
	variable ipsc, secondSpikeTime
	variable fit, ResponsePoint
	variable w_coef0, w_coef1, w_coef2, W_fitConstant, x
	variable LoopCount
	string NaturalTrainName, SpikeTrainName, ResponseTrainName
	string tempString, matchString
	string startEpoch, endEpoch
	variable istart, iend
	variable NextSpikePoint, scaling, nextSpikeTime, SpikeNum
	wave NaturalSpikeTimes
	string baseName, AvgName, SDName
	prompt startEpoch, "First Epoch"
	prompt EndEpoch, "Last Epoch"
	prompt baseName, "baseName"
	doprompt "Select wave range for Natural Spikes", startEpoch, EndEpoch, baseName
	//make sure function cancels
	if(V_flag)
		abort
	endif

	wave/t NaturalWaves1_w
	wave/t NaturalWaves1_c
	
	wave NautralSpikeTimes
		//Analyze appropriate part of wave
	do
	if (strlen(NaturalWaves1_c[i]) ==0)
		break
	endif
	tempString = NaturalWaves1_c[i]
	matchString = tempString[1, strlen(tempString)]
	
	if (stringmatch (matchString, startEpoch)==1)
		istart = i
	endif
	if (stringmatch (matchString, EndEpoch)==1)
		iend = i
	endif
	
	i+=1
	while (1)
	
	i = istart
	do
		ResponseTrainName = NaturalWaves1_c[i]
		Wave SpikeTrain = NaturalSpikeTimes
		wave ResponseTrain = $ResponseTrainName

				SpikeNum=0
				make/o/n=0 ipscAmp
					do
						if (SpikeNum== numpnts(SpikeTrain))
							break
						endif
							if (SpikeNum==0)
								wavestats/q/r=[0,36] ResponseTrain
								baseline = v_avg
							else
								baseline = fit
							endif
							Wavestats/q/r=(SpikeTrain[SpikeNum], (SpikeTrain[SpikeNum]+.0023)) ResponseTrain; //duplicate/o/r=(SpikeTimes[i], (SpikeTimes[i]+.0023)) ResponseTrain DisplayTest; display DIsplayTest
							minPeakPoint = x2pnt(ResponseTrain, v_minloc)	
							//Fit IPSC decay with exponential
							NextSpikeTime = SpikeTrain[SpikeNum+1]
							Scaling = deltax(ResponseTrain);NextSpikePoint = NextSpikeTime/scaling
							CurveFit/q exp_XOffset  ResponseTrain[MinPeakPoint,NextSpikePoint] /D 
							//Find IPSC amplitude
							ipsc = ((ResponseTrain[minPeakPoint-1]+ResponseTrain[minPeakPoint+1]+ ResponseTrain[minPeakPoint])/3)-baseline
							//Put results in table	
							redimension/n=(numpnts(ipscAmp)+1) ipscAmp
							ipscAMP[SpikeNum] = ipsc
							//Extrapolate to determine baseline for second spike
							W_coef0 = W_coef[0]	
							W_coef1 = W_coef[1]
							W_coef2 = W_coef[2]
							W_fitConstant = W_fitConstants[0]
							x = NextSpikeTime
							fit= W_coef0+W_coef1*exp(-(x-W_fitConstants)/W_coef2)		
							
					SpikeNum+=1
					while(istart<=iend)	
					sprintf NaturalTrainName, "%s%g%s%s", "AmpTrain", LoopCount, "_", baseName
					duplicate/o ipscAmp $NaturalTrainName
					killwaves ipscAmp
			
			if (LoopCount==0)
				edit $NaturalTrainName
				make/o/t/n=0 TextWave
				redimension/n=(numpnts(TextWave)+1) TextWave
				TextWave[LoopCount] = NaturalTrainName
			else
				appendtotable $NaturalTrainName
				redimension/n=(numpnts(TextWave)+1) TextWave
				TextWave[LoopCount] = NaturalTrainName
			endif
			
		i+=1
		LoopCount+=1
		while (i<=iend)
		
		//Transform Waves for averaging
		variable Count
		Count = numpnts(textWave)
		Wavestats/q $TextWave[0]
		variable length = v_npnts
		variable i1=0
		variable i2
		string cmdstr
		do
			i2 = 0
			cmdstr = "make/o/n=" + num2str(count) + " tempWave" + num2str(i1)
			execute cmdstr
			do
				cmdstr = "tempWave" + num2str(i1) + "[" + num2str(i2) + "] = " + textWave[i2] + "[" + num2str(i1) + "]"
					execute cmdstr
				i2 +=1
				while (i2 < count)
			i1 += 1
		while (i1 < length)
			
			cmdstr = "make/o/n=" + num2str(length) + " Wave_avg"
				execute cmdstr
			cmdstr = "make/o/n=" + num2str(length) + " Wave_SD"
				execute cmdstr
			i1 = 0
			
		do
			cmdstr = "WaveStats/q tempWave" + num2str(i1)
				execute cmdstr
			cmdstr = "Wave_avg[" + num2str(i1) + "] = v_avg"
				execute cmdstr
			cmdstr = "Wave_SD[" + num2str(i1) + "] = v_sdev"
				execute cmdstr
			cmdstr = "Killwaves tempWave" + num2str(i1)
				execute cmdstr
			i1 += 1
		while (i1 < length)
		
		sprintf AvgName, "%s%s", "NaturalAvg_", baseName
		duplicate/o Wave_avg $AvgName
		sprintf SDName, "%s%s", "NaturalSD_", baseName
		duplicate/o Wave_SD $SDName
		
		edit $AvgName, $SDName
		display $AvgName vs NaturalSpikeTimes
		ModifyGraph mode=3,marker=8,msize=4,opaque=1,rgb=(0,0,0)
		ErrorBars $AvgName Y,wave=($SDName,$SDName)
		appendtograph/r $SDName vs NaturalSpikeTimes
		modifygraph rgb[1] = (43690,43690,43690)
		

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Created 10-17-08

Function BaselineAnalysis()
	string CCWaveName, VCWaveName
	variable deltaOne, SampleRate
	variable fit, W_coef0, W_coef1, W_coef2, W_fitconstant,x
	variable i, v_flag
	variable method
	variable tenpercent, ninetypercent, rise
	variable baseline, minPeakPoint, ipsc, taudecay
	variable IPSCAmpAverage, IPSCdelayAverage, IPSCdecayAverage, RiseTimeAverage, Amp2, baselineAvg
	variable taudecayAvg
	variable ipsc2
	string baseName
	string tempWave
	string AvgDecay, AvgAmp, AvgDelay, AvgRise
	string AvgDecayStr, AvgAmpStr, AvgDelayStr, AvgRiseStr
	string totalSpikeWaveName, TotalResponseWaveName, ipscAmpName, ipscDelayName, ipscDecayName, RiseTimeName, ipscAMp2Name, PPRName, delayName
	string startEpoch, EndEpoch, tempstring, matchString
	string ipscStatsWaveName, ipscStatsName
	variable istart, iend, Count
	variable peakTime
	wave SpikeTimes
	
	variable IPSC1Amp, IPSC1AmpTime, IPSC2Amp, IPSC2AmpTime
	variable Threshold = -45
	variable TimeofSpike
	variable VarDelay
	
	prompt startEpoch, "First Epoch"
	prompt EndEpoch, "Last Epoch"
	prompt baseName, "baseName"
	prompt method, "From list (0); From graph (1)"
	doprompt "Select wave range for Baseline", startEpoch, EndEpoch, baseName, method
	

	//make sure function cancels
	if(V_flag)
		abort
	endif

	//User created waves- a list of all the wavs containing presynaptic response and those containing matching
		//postsynaptic response
	Wave/t BaselineWaves_w
	Wave/t BaselineWaves_C

	//waves for individual traces
	make/o/n=0 ipscAmp
	make/o/n=0 ipscdecay
	make/o/n= 0 riseTime
	make/o/n= 0 ipscAmp2
	make/o/n=0 PPRWave1
	make/o/n=0 DelayTime
	
	//Analyze appropriate part of wave
	do
	if (strlen(BaselineWaves_C[i]) ==0)
		break
	endif
	tempString = BaselineWaves_C[i]
	matchString = tempString[1, strlen(tempString)]

	
	if (stringmatch (matchString, startEpoch)==1)
		istart = i
	endif
	if (stringmatch (matchString, EndEpoch)==1)
		iend = i
	endif
	
	i+=1
	while (1)
	print istart
	print iend

	if (method==0)
		i = istart
	else
		i = 0
	endif	
	
	do
		if (method==0)
		//assign names to waves
		Wave CCWave = $BaselineWaves_w[i]
		wave VCWave = $BaselineWaves_C[i]
		Wave W_Coef
		endif
		
		if (method==1)
		//get consecutive waves off graph
			tempWave = WaveName("", i, 1)
			if(strlen(tempWave)==0)
				break
			endif
			Wave VCWave = $tempWave
			
		endif
	
						
		//Get time of AP peak for latency
			FindSpikeTimesAG(CCWave, 0.095, 0.11, Threshold)
			TimeofSpike = spikeTimes[0]
		//	print BaselineWaves_w[i]
		//	print "Time of spike = ", TimeofSpike
		//Analyze IPSC1			
			Wavestats/q/r=(0.05, 0.08) VCWave
				baseline = v_avg
			Wavestats/q/r=(0.104, 0.13) VCWave
				IPSC1Amp = v_min	
				IPSC1AmpTime = v_minLoc
			//Find tau of decay
				CurveFit/q exp_XOffset  VCWave(IPSC1AmpTime,0.14) /D 
				taudecay = W_coef[2]
			//Find amplitude
				minPeakPoint = x2pnt(VCWave, v_minLoc)
				ipsc = ((VCWave[minPeakPoint-1]+VCWave[minPeakPoint+1]+ VCWave[minPeakPoint])/3)-baseline
			//Find riseTime
				tenpercent =baseline+ 0.1*(V_min - baseline)		// tenpercent is the amplitude that is 10% of the max amplitude of the epsc
				//	print "ten percent", tenpercent
				ninetypercent =baseline+ 0.9*(V_min - baseline)	// ditto, for ninety percent
					//print ninetypercent; print i
				Make/O/N=7 DataWave=0							// Wave to hold the results in, and check for glaring error
					DataWave[0] = V_min - baseline					// the epsc amplitude
					DataWave[1] = V_minloc 			// and location of maximum amplitude
						FindLevel/Q/R=(0.103, 0.108) VCWave, tenpercent
							//if stimulus artifact obscures initial 10% of IPSC, rise time will not be calculated
							if (v_flag==0)
							DataWave[2] = tenpercent - baseline				// tenpercent of amplitude
								//	print dataWave[2]	
							DataWave[3] = V_LevelX 				// location of tenpercent amplitude
									//print dataWave[3]
							else
								dataWave[2] = nan
								dataWAve[3] = nan
							endif
							
							if (v_flag ==0)
								varDelay = DataWave[3]-TimeofSpike	//changed this.  Was -0.1
								//print varDelay
							else
								varDelay = nan
							endif
						FindLevel/Q/R=(0.101, 0.14) VCWave, ninetypercent
							DataWave[4] = ninetypercent - baseline				// ditto at ninetypercent
								//print dataWave[4]
							DataWave[5] = V_LevelX 
							//	print dataWave[5]; print i
							if (v_flag==0)
								rise = DataWave[5] - DataWave[3]
							else 
								rise = nan
							endif
							
			
	
			redimension/n=(numpnts(ipscAmp)+1) ipscAmp
			redimension/n=(numpnts(ipscdecay)+1) ipscdecay
			redimension/n=(numpnts(RiseTime)+1) riseTime
			redimension/n=(numpnts(ipscAmp2)+1) ipscAmp2
			redimension/n=(numpnts(PPRWave1)+1) PPRWave1
			redimension/n=(numpnts(delayTime)+1) delayTime
			ipscAmp[Count] = ipsc
			ipscdecay[Count] = taudecay
			RiseTime[Count] = rise	
			delayTime[Count] = varDelay	
			
			wave W_fitconstants
			if (ipsc < -10)
				//Extrapolate to determine baseline for second spike
				W_coef0 = W_coef[0]	
				W_coef1 = W_coef[1]
				W_coef2 = W_coef[2]
				W_fitConstant = W_fitConstants[0]
				x = 0.151
				fit= W_coef0+W_coef1*exp(-(x-W_fitConstants)/W_coef2)
				baseline = fit
			else
				Wavestats/q/r=(0.151, 0.15105) VCWave
					baseline = v_avg
				endif
				
			//Move on to second spike
			Wavestats/q/r=(0.151, 0.2) VCWave
				IPSC2Amp = v_min
				IPSC2AmpTime = v_minLoc
				minPeakPoint = x2pnt(VCWave, v_minloc)	
			ipsc2 = ((VCWave[minPeakPoint-1]+VCWave[minPeakPoint+1]+ VCWave[minPeakPoint])/3)-baseline	//Finds amplitude of first IPSC
			ipscAmp2[Count] = ipsc2
				
			
					
		//For display
			duplicate/o/r=(0.08, 0.2) VCWave BaselineDisplay
				deltaOne =  -0.08
				SampleRate = deltax(VCWave)
				SetScale/P x -deltaOne,SampleRate,"",BaselineDisplay
			//do the averaging
				if (Count==0)
					duplicate/o BaselineDisplay TotalBaselineDisplay
				else
					TotalBaselineDisplay+=BaselineDisplay
				endif
			if (i==iend)
				TotalBaselineDisplay/=(Count+1)
			endif

	Count+=1
	i+=1
	
	//Calculate PPR
	duplicate/o ipscAmp2 PPRWave1
	PPRWave1/=ipscAmp
	
	//	iend=3
		while (i<=iend)


	wavestats/q/r=(0.08, 0.1) TotalBaselineDisplay
		BaselineAvg = v_avg
		TotalBaselineDisplay-=baselineAvg

	//Give waves unique names
	sprintf totalResponseWaveName, "%s%s", "DisplayWave_", baseName
		duplicate/o TotalBaselineDisplay $totalResponseWaveName	
	sprintf ipscAmpName, "%s%s", "ipscAmp_", baseName
		duplicate/o ipscAmp $ipscAmpName	
	sprintf ipscdecayName, "%s%s", "ipscDecay_", baseName
		duplicate/o ipscDecay $ipscDecayName
	sprintf RiseTimeName, "%s%s", "RiseTime_", baseName
		duplicate/o RiseTime $RiseTimeName
	sprintf ipscAmp2Name, "%s%s", "ipscAmp2_", baseName
		duplicate/o ipscAmp2 $ipscAmp2Name	
	sprintf PPRName, "%s%s", "PPR_", baseName
		duplicate/o PPRWave1 $PPRName	
	sprintf delayName, "%s%s", "delay_", baseName
		duplicate/o delayTime $delayName

	display $TotalResponseWaveName

	
	make/t/o/n=9 IPSCstats; IPSCstats[0] = "IPSC amp"; IPSCstats[1] = "IPSC sdev"; IPSCstats[2] = "dev/avg"; IPSCstats[3] = "tau"; 
	IPSCstats[4] = "RiseTime"; IPSCstats[5] = "PPR"; IPSCstats[6] = "PPRSD"; IPSCstats[7] = "delay time"; IPSCstats[8] = "delay Sdev"
	make/o/n=9 statsWave
	
	wavestats/q IPSCAmp
		statsWave[0] = (v_avg)*-1
		statsWave[1] = v_sdev
		statsWave[2] = (statsWave[1] / statsWave[0])
	wavestats/q ipscDecay	
		statsWave[3] = v_avg
	wavestats/q RiseTime
		statsWave[4] = v_avg
	wavestats/q PPRWave1
		statsWave[5] = v_avg
		statsWave[6] = v_sdev
	wavestats/q delayTime
		statsWave[7] = v_avg
		statsWave[8] = v_sdev
	sprintf IPSCstatsWaveName, "%s%s", "Title", baseName
		duplicate/o ipscStats $IPSCstatsWaveName	
	sprintf IPSCstatsName, "%s%s", "IPSCstats", baseName
		duplicate/o statsWave $IPSCstatsName	
	
	Edit $ipscAmpName, $ipscDecayName, $RiseTimeName, $ipscAmp2Name, $PPRName, $delayName
	edit $IPSCstatsWaveName, $IPSCStatsName
		

	killwaves ipscAmp, ipscdecay, riseTime, ipscAmp2
		
		

End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function IPSCAnalysis()
	variable deltaOne, SampleRate
	variable fit, W_coef0, W_coef1, W_coef2, W_fitconstant,x
	variable i, v_flag
	variable method
	variable tenpercent, ninetypercent, rise
	variable baseline, minPeakPoint, ipsc, taudecay
	variable IPSCAmpAverage, IPSCdelayAverage, IPSCdecayAverage, RiseTimeAverage, Amp2, baselineAvg
	variable taudecayAvg
	variable ipsc2
	string baseName
	string tempWave
	string AvgDecay, AvgAmp, AvgDelay, AvgRise
	string AvgDecayStr, AvgAmpStr, AvgDelayStr, AvgRiseStr
	string totalSpikeWaveName, TotalResponseWaveName, ipscAmpName, ipscDelayName, ipscDecayName, RiseTimeName, ipscAMp2Name, PPRName, delayName
	string startEpoch, EndEpoch, tempstring, matchString
	string ipscStatsWaveName, ipscStatsName
	variable istart, iend, Count
	variable peakTime
	
	variable IPSC1Amp, IPSC1AmpTime, IPSC2Amp, IPSC2AmpTime
	
	prompt baseName, "baseName"
	doprompt "", baseName
	

	//make sure function cancels
	if(V_flag)
		abort
	endif

	//waves for individual traces
	make/o/n=0 ipscAmp
	make/o/n=0 ipscdecay
	make/o/n= 0 riseTime
	make/o/n= 0 ipscAmp2
	make/o/n=0 PPRWave1
	make/o/n=0 DelayTime
	
		
	do
		//get consecutive waves off graph
			tempWave = WaveName("", i, 1)
			if(strlen(tempWave)==0)
				break
			endif
			print tempWave
			iend = i
	i+=1
	while (1)

	i=0
	do
		//get consecutive waves off graph
			tempWave = WaveName("", i, 1)
			Wave VCWave = $tempWave
			Wave W_coef
	
						
		//Analyze IPSC1			
			Wavestats/q/r=(0.05, 0.08) VCWave
				baseline = v_avg
			Wavestats/q/r=(0.101, 0.14) VCWave
				IPSC1Amp = v_min	
				IPSC1AmpTime = v_minLoc
			//Find tau of decay
				CurveFit/q exp_XOffset  VCWave(IPSC1AmpTime,0.14) /D 
				taudecay = W_coef[2]
				
			//Find amplitude
				minPeakPoint = x2pnt(VCWave, v_minLoc)
				ipsc = ((VCWave[minPeakPoint-1]+VCWave[minPeakPoint+1]+ VCWave[minPeakPoint])/3)-baseline
			//Find riseTime
				tenpercent =baseline+ 0.1*(V_min - baseline)		// tenpercent is the amplitude that is 10% of the max amplitude of the epsc
				//	print tenpercent
				ninetypercent =baseline+ 0.9*(V_min - baseline)	// ditto, for ninety percent
					//print ninetypercent; print i
				Make/O/N=7 DataWave=0							// Wave to hold the results in, and check for glaring error
					DataWave[0] = V_min - baseline					// the epsc amplitude
					DataWave[1] = V_minloc 			// and location of maximum amplitude
						FindLevel/Q/R=(0.101, 0.108) VCWave, tenpercent
							//if stimulus artifact obscures initial 10% of IPSC, rise time will not be calculated
							if (v_flag==0)
							DataWave[2] = tenpercent - baseline				// tenpercent of amplitude
								//	print dataWave[2]	
							DataWave[3] = V_LevelX 				// location of tenpercent amplitude
								//	print dataWave[3]
							else
								dataWave[2] = nan
								dataWAve[3] = nan
							endif
							
							if (v_flag ==0)
								delayTime = DataWave[3]-0.1
							else
								delayTime = nan
							endif
						FindLevel/Q/R=(0.101, 0.14) VCWave, ninetypercent
							DataWave[4] = ninetypercent - baseline				// ditto at ninetypercent
								//print dataWave[4]
							DataWave[5] = V_LevelX 
							//	print dataWave[5]; print i
							if (v_flag==0)
								rise = DataWave[5] - DataWave[3]
							else 
								rise = nan
							endif
							
			
	
			redimension/n=(numpnts(ipscAmp)+1) ipscAmp
			redimension/n=(numpnts(ipscdecay)+1) ipscdecay
			redimension/n=(numpnts(RiseTime)+1) riseTime
			redimension/n=(numpnts(ipscAmp2)+1) ipscAmp2
			redimension/n=(numpnts(PPRWave1)+1) PPRWave1
			redimension/n=(numpnts(delayTime)+1) delayTime
			ipscAmp[i] = ipsc
			ipscdecay[i] = taudecay
			RiseTime[i] = rise	
			delayTime[i] = peakTime	
			
			wave W_fitconstants
			if (ipsc < -10)
				//Extrapolate to determine baseline for second spike
				W_coef0 = W_coef[0]	
				W_coef1 = W_coef[1]
				W_coef2 = W_coef[2]
				W_fitConstant = W_fitConstants[0]
				x = 0.151
				fit= W_coef0+W_coef1*exp(-(x-W_fitConstants)/W_coef2)
				baseline = fit
			else
				Wavestats/q/r=(0.151, 0.15105) VCWave
					baseline = v_avg
				endif
				
			//Move on to second spike
			Wavestats/q/r=(0.151, 0.2) VCWave
				IPSC2Amp = v_min
				IPSC2AmpTime = v_minLoc
				minPeakPoint = x2pnt(VCWave, v_minloc)	
			ipsc2 = ((VCWave[minPeakPoint-1]+VCWave[minPeakPoint+1]+ VCWave[minPeakPoint])/3)-baseline	//Finds amplitude of first IPSC
			ipscAmp2[i] = ipsc2
				
			
					
		//For display
			duplicate/o/r=(0.08, 0.2) VCWave BaselineDisplay
				deltaOne =  -0.08
				SampleRate = deltax(VCWave)
				SetScale/P x -deltaOne,SampleRate,"",BaselineDisplay
			//do the averaging
				if (i==0)
					duplicate/o BaselineDisplay TotalBaselineDisplay
				else
					TotalBaselineDisplay+=BaselineDisplay
				endif
			if (i==iend)
				TotalBaselineDisplay/=(i+1)
			endif



	
	//Calculate PPR
	duplicate/o ipscAmp2 PPRWave1
	PPRWave1/=ipscAmp
	
		i+=1
		while (i<=iend)


	wavestats/q/r=(0.08, 0.1) TotalBaselineDisplay
		BaselineAvg = v_avg
		TotalBaselineDisplay-=baselineAvg

	//Give waves unique names
	sprintf totalResponseWaveName, "%s%s", "DisplayWave_", baseName
		duplicate/o TotalBaselineDisplay $totalResponseWaveName
	
	sprintf ipscAmpName, "%s%s", "ipscAmp_", baseName
		duplicate/o ipscAmp $ipscAmpName	
	sprintf ipscdecayName, "%s%s", "ipscDecay_", baseName
		duplicate/o ipscDecay $ipscDecayName
	sprintf RiseTimeName, "%s%s", "RiseTime_", baseName
		duplicate/o RiseTime $RiseTimeName
	sprintf ipscAmp2Name, "%s%s", "ipscAmp2_", baseName
		duplicate/o ipscAmp2 $ipscAmp2Name	
	sprintf PPRName, "%s%s", "PPR_", baseName
		duplicate/o PPRWave1 $PPRName	
	sprintf delayName, "%s%s", "delay_", baseName
		duplicate/o delayTime $delayName

	display $TotalResponseWaveName

	
	make/t/o/n=9 IPSCstats; IPSCstats[0] = "IPSC amp"; IPSCstats[1] = "IPSC sdev"; IPSCstats[2] = "dev/avg"; IPSCstats[3] = "tau"; 
	IPSCstats[4] = "RiseTime"; IPSCstats[5] = "PPR"; IPSCstats[6] = "PPRSD"; IPSCstats[7] = "delay time"; IPSCstats[8] = "delay Sdev"
	make/o/n=9 statsWave
	
	wavestats/q IPSCAmp
		statsWave[0] = (v_avg)*-1
		statsWave[1] = v_sdev
		statsWave[2] = (statsWave[1] / statsWave[0])
	wavestats/q ipscDecay	
		statsWave[3] = v_avg
	wavestats/q RiseTime
		statsWave[4] = v_avg
	wavestats/q PPRWave1
		statsWave[5] = v_avg
		statsWave[6] = v_sdev
	wavestats/q delayTime
		statsWave[7] = v_avg
		statsWave[8] = v_sdev
	sprintf IPSCstatsWaveName, "%s%s", "Title", baseName
		duplicate/o ipscStats $IPSCstatsWaveName	
	sprintf IPSCstatsName, "%s%s", "IPSCstats", baseName
		duplicate/o statsWave $IPSCstatsName	
	
	Edit $ipscAmpName, $ipscDecayName, $RiseTimeName, $ipscAmp2Name, $PPRName, $delayName
	edit $IPSCstatsWaveName, $IPSCStatsName
		

	killwaves ipscAmp, ipscdecay, riseTime, ipscAmp2
	
	End
		
		

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////



Function PreStimChargeAnalysis()
	string tempWave
	variable, i
	variable baseline, length
	
	make/o/n=0 Charge
	
	do
		//get consecutive waves off graph
		tempWave = WaveName("", i, 1)
		if(strlen(tempWave)==0)
			break
		endif
		duplicate/o $tempWave wv1
	
	wavestats/q/r=(0.18, 0.199)  wv1
	baseline = v_avg
	
	wv1 -=baseline
	wv1*=-1
	
	//duplicate/o/r=(0.2, 0.3) wv1 integral		//default
	duplicate/o/r=(0.2, 0.3) wv1 integral
	Integrate integral
	length = numpnts(integral)
	redimension/n=(numpnts(Charge)+1) Charge
	Charge[i] = integral[length]
	
	i+=1
	while (1)
	


End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function IVCurve()
	wave/t SpikeWaves
	wave/t ResponseWaves
	wave postholding, W_Coef
	string tempWave, ResponseName
	variable i, holding, peakX
	variable baseline, minPeakPoint, taudecay, ipsc, IPSCAmp, ipscDecay
	variable threshold = -40
	
	//duplicate/o postholding holdingpotential
	make/o/n=0 holdingpotential
	holding = -80
	
	make/o/n = 0 AmpIV
	make/o/n = 0 DecayIV
	make/o/t/n=0  List

	do

//get consecutive waves off graph
		tempWave = WaveName("", i, 1)
		if(strlen(tempWave)==0)
			break
		endif
		duplicate/o $tempWave Response
			
			//Analyze response
			//For display
				Wavestats/q/r=(0.5, 0.54) Response//Wavestats/q/r=(0.35, 0.39) Response
				baseline = v_avg	//for display
				duplicate/o/r=(0.53, 0.6) Response IPSCWave//duplicate/o/r=(0.4, 0.46) Response IPSCWave
				IPSCWave-=baseline
				redimension/n=(numpnts(holdingpotential)+1) holdingpotential
				holdingpotential[i]=holding
						
		Wavestats/q/r=(0.551, 0.6) Response
			if (i<4)
			//if (holdingpotential[i]<=0) 
				minPeakPoint = x2pnt(Response, v_minloc)	//if negative holding potential, current is inward and need to look for min
			//endif
			//if (holdingpotential[i]>=0)
			else
				minPeakPoint = x2pnt(Response, v_maxloc)	//if negative positive potential, current is outward and need to look for max
			endif
						
		ipsc = ((Response[minPeakPoint-1]+Response[minPeakPoint+1]+ Response[minPeakPoint])/3)-baseline	//Finds amplitude of first IPSC
		redimension/n=(numpnts(AmpIV)+1) AmpIV
		redimension/n=(numpnts(DecayIV)+1) DecayIV
		AmpIV[i] = ipsc
		sprintf ResponseName, "%s%g", "IPSC_", holding
		duplicate/o IPSCWave $ResponseName	
		redimension/n = (numpnts(List)+1) List
		List[i] = ResponseName
	
	i+=1
	holding+=20
	while (i<8)
	//while (i<numpnts(holdingpotential))
	
	edit holdingpotential, AmpIV
	display AmpIV vs holdingpotential
	ModifyGraph mode=4,marker=19,msize=3,rgb=(0,0,0)
	
	i=0
	do
		wave ToGraph = $List[i]
		if (i==0)
			display ToGraph
		else
			appendtograph ToGraph
		endif
		Execute "colors()"
		
		i+=1
		while (i<8)
		//while (i<numpnts(holdingpotential))	

End



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//created 6/17/05 by AG
//Takes all the traces on a graph and averages them into 1 trace; average is displayed in thick black line on graph

Function AverageTrace()
	String baseName 							// for naming the resulting waves
	variable i
	string tempWave, avgName
	Prompt baseName, "Base name"
	Doprompt "", baseName
	
	//make sure function cancels
	if(V_flag)
		abort
	endif
	
		do
		//get consecutive waves off graph
		tempWave = WaveName("", i, 1)
		if(strlen(tempWave)==0)
			break
		endif
		duplicate/o $tempWave wv1

		if (i==0)
			duplicate/o wv1 placeholder
		else
			placeholder +=wv1
		endif
		
	i+=1
	while (1)
	
	placeholder/=i
	sprintf AvgName "%s%s", baseName, "_avg"
	duplicate/o placeholder $AvgName
	
	appendtograph $avgName
	ModifyGraph lsize($avgName)=2,rgb($avgName)=(0,0,0)
	
	End
	

		

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////





Function FindSpikeTimesAG(w, startTime, endTime, thresh)
	Wave w
	Variable startTime, endTime, thresh
	FindSpikeTimesSmoothed(w, startTime, endTime, thresh, 0, 5, 1)
//cd :chan_0
End

Function FindSpikeTimesSmoothed(w, startTime, endTime, thresh, minSpikeWidth, minAmplitude, showNoSpikesWarning)
	Wave w  //Input wave
	Variable startTime, endTime //s
	Variable thresh //mV (spikes are not possible in voltage clamp)
	Variable minSpikeWidth  //s  To prevent false positives
	Variable minAmplitude  //amplitude-thresh must be greater than this, to prevent false positives
	Variable showNoSpikesWarning
	minSpikeWidth = minSpikeWidth/deltax(w)  //samples

	Variable inSpike = 0
	Variable nSpikes = 0
	Variable i, maxTime, maxAmp, previousSpikeTime
	Make/O/N =10000 spikeTimes = 0, spikePeakVoltages = 0
	Make/O/N =10000 spikeIntervals = 0, intervalTimes = 0
	
	//Force startTime and endTime into range.  Convert to points.
	//If startTime or endTime are negative, the endpoint is used for that time.
	Variable startPoint = x2pnt(w, startTime)
	Variable endPoint = x2pnt(w, endTime)
	startPoint = max(0, startPoint)
	startPoint = min(startPoint, numpnts(w))
	
	if(endPoint<0)
		endPoint = numpnts(w)
	endif
	
	endPoint = min(endPoint, numpnts(w))

	if(startPoint >= endPoint)
		DoAlert 0, "Given range for FindSpikes has zero or negative size"
	endif
	
	Variable primed = 0 // assures that no partial spikes will be picked up at the beginning of the detection window.
	Variable spikeStartTime = startPoint
	for(i=startPoint; i<endPoint; i+=1)
		//If in a spike
		if(w[i] > thresh && primed == 1) 
			//if entering new spike
			if(inSpike ==0)
				maxTime = i
				maxAmp = w[i]
				inSpike = 1
				spikeStartTime = i
				//if continuing in spike
			else
				if(w[i] > maxAmp)
					maxTime = i
					maxAmp = w[i]
				endif
			endif
			//if not in a spike
		else 

			//if was just in a spike and it was wide enough to be real, save it
			if(inSpike == 1 && ((i-spikeStartTime)>minSpikeWidth) && minAmplitude <= maxAmp -thresh)

				nSpikes+=1
				if(nSpikes == numpnts(spikeTimes))
					Redimension/N=(numpnts(spikeTimes)*2) spikeTimes, spikePeakVoltages, spikeIntervals, intervalTimes
				endif
				spikeTimes[nSpikes-1] = maxTime
				spikePeakVoltages[nSpikes-1] = maxAmp
				if(nSpikes>1)
				
					spikeIntervals[nSpikes -2] = maxTime-previousSpikeTime  //Executive decision by Sascha
					intervalTimes[nSpikes-2] = maxTime  
				endif
				previousSpikeTime = maxTime
			endif
			inSpike=0
			primed = 1
		endif
		//		if(i==startPoint + 2)
		//			abort
		//		endif
	endfor
	
	variable/G meanRate_ag		// making global for use in other procedures
	variable/G CV_ag					// coefficient of variation (of interspike intervals)= std dev/mean
	
	if(nSpikes == 0)
		Make/O/N=0 spikeTimes, spikePeakVoltages, spikeIntervals, intervalTimes, spikeRates
		meanRate_ag = 0
		CV_ag = NaN
		
		if(showNoSpikesWarning == 1)
			Print "*No spikes*"
		endif
	else
	
		Redimension/N=(nSpikes) spikeTimes, spikePeakVoltages
		Redimension/N=(nSpikes-1) spikeIntervals, intervalTimes
	
		spikeTimes=spikeTimes*deltax(w) +leftx(w)
		spikeIntervals = spikeIntervals*deltax(w)
		intervalTimes = intervalTimes*deltax(w) + leftx(w)
	
		Duplicate/O spikeIntervals, spikeRates
		spikeRates = 1/spikeRates
	//	edit spikerates
	//	edit spikeintervals

	
		SetScale/P x 0, 1 ,"Spike Number", spikeTimes
		SetScale d 0,0,"Time (s)", spikeTimes
	
		SetScale/P x 0, 1 ,"Spike Number", spikePeakVoltages
		SetScale d 0,0,"Spike Peak Voltages (mV)", spikePeakVoltages

		SetScale/P x 0, 1 ,"Interval Number", spikeIntervals
		SetScale d 0,0,"Time Interval (s)", spikeIntervals
	
		SetScale/P x 0, 1 ,"Interval Number", intervalTimes
		SetScale d 0,0,"Time (s)", intervalTimes
	
		SetScale/P x 0, 1 ,"Interval Number", spikeRates
		SetScale d 0,0,"spikes/s", spikeRates
	
	
		// Calculate mean firing rate (in spikes/sec): 1/mean interval
		// If only one interval, wavestats barfs
		
		if (dimSize (spikeIntervals, 0) == 1)
			meanRate_ag = 1/spikeIntervals(0)		
			CV_ag = NaN
		endif
	

		if (dimSize (spikeIntervals, 0) > 1)
			WaveStats/Q spikeIntervals

			meanRate_ag = 1/V_avg  //in Hz
			CV_ag = V_sdev/V_avg  //Coefficient of Variance = Sdev/mean of both intervals and 1/intervals.
		//	print "smooth spike times code = ", CV_ag
		//	print "firing rate = ", meanrate_ag
		endif
	
	endif
	
End



// draws a dotted diagonal line between startXY and endXY

Macro DiagLine()
	
	variable startXY, endXY
	variable bottom_min, left_min
	variable bottom_max, left_max
	
	getaxis/q bottom; bottom_min=v_min; bottom_max=v_max
	getaxis/q left; left_min=v_min; left_max=v_max
	
	startXY=min(left_min, bottom_min)
	endXY=max(left_max, bottom_max)
	
	setaxis bottom startXY, endXY
	setaxis left startXY, endXY

	SetDrawEnv xcoord= bottom,ycoord= left,dash= 2;DelayUpdate
	DrawLine startXY, startXY, endXY, endXY
	
 End	
 
 ///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
 
 

// Draws a straight dashed line at 'flatY' between startX and endX
Macro DotLine(startX, endX, flatY)
	variable startX, endX, flatY
	
	SetDrawEnv xcoord= bottom,ycoord= left,dash= 2, linethick=0.5;DelayUpdate
	DrawLine startX, flatY, endX, flatY
	
 End	
 
 ///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
Proc dots() : GraphStyle
	PauseUpdate; Silent 1		// modifying window...
	ModifyGraph/Z mode=3
	ModifyGraph/Z marker=19, msize=3
	ModifyGraph/Z rgb[0]=(65535,0,0),rgb[1]=(1,4,52428), rgb[2]=(51664,44236,58982), rgb[3]=(52428,34958,1)
EndMacro

///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
Proc AGcolors() : GraphStyle
	PauseUpdate; Silent 1
	ModifyGraph/Z rgb[0]=(0,0,65535), rgb[1]=(65535,0,0), rgb[2]=(3,52428,1), rgb[3]=(36873,14755,58982)
	ModifyGraph/Z rgb[4]=(65535,43690,0), rgb[5]=(39321,39321,39321), rgb[6]=(52428,1,20971), rgb[7]=(32768,32770,65535)
	ModifyGraph/z rgb[8]= (65535,32768,32768)
EndMacro


//  Makes both axes disappear
Proc AxesOff()
	
	ModifyGraph noLabel(left)=2,axThick(left)=0
	ModifyGraph noLabel(bottom)=2,axThick(bottom)=0
End




//  Makes both axes reappear
Proc AxesOn()
	
	ModifyGraph noLabel(left)=0,axThick(left)=1
	ModifyGraph noLabel(bottom)=0,axThick(bottom)=1
End




Function TauCalculator()
	variable W_coef0 =  832.4
	variable W_coef1 =   3488.72
	variable W_coef2=    1007.92
	variable W_fitConstant =  20.7
	variable x = 10
	
	
	
	variable fit
	
		fit= W_coef0+W_coef1*exp(-(x-W_fitConstant)/W_coef2)
		print fit
		
		

End



//
////Created 4/1/13
//Function test(name)
//	string Name
//	dfref  dfr = root:$name
//	wave wv1 = dfr:sweep29
//	
//	display dfr:sweep29
//	
//End


Menu "AG_Analysis"
	"Graph firing rate!T/2", GraphRate()
	"AverageTrace!T/1", AverageTrace()
	"AppendWholeGraph!T/3", AppendWholeGraph()
	"SpikeShapeAnalysis!T/4", SpikeShapeAnalysis()
	"Cell attached FR!T/5", AttachedFR()
	
	
End


//Function Names([win_name])
//	string win_name
//	variable i
//	
////These lines magically get the waves you want off the SweepsWin window
//	win_name=selectstring(paramisdefault(win_name),win_name,winname(0,1))
//	string traces = TraceNameList(win_name, ";", 1)
//	string firsttrace =  stringfromlist(0,traces)
//	wave w = tracenametowaveref(win_name, firsttrace)
////for loop goes through each wave on graph until there aren't anymore
//	for(i=0;i<ItemsInList(traces);i+=1)
//		string trace = StringFromList(i,traces)
//		Wave TraceWave=TraceNameToWaveRef(win_name,trace)
//		if (i==0)
//			display TraceWave
//		else
//			appendtograph TraceWave
//		endif
//	endfor
//	
//	//display w
//	//print getwavesdatafolder(w,2)	//prints full name of wave, including data folder
//	
//	
//
//End
//


Function AttachedFR([win_name])
	string win_name
	variable threshold = 20
	variable i
	variable startTime = 0.5
	variable endTime = 5
	variable attFR, attCV
	prompt threshold, "threshold"
	prompt startTime, "start time"
	prompt endTime, "end time"
	
	doprompt "", threshold, startTime, EndTime
	
	make/o/n=0 attFRWave
	make/o/n=0 attCVwave
	
//These lines magically get the waves you want off the SweepsWin window
	win_name=selectstring(paramisdefault(win_name),win_name,winname(0,1))
	string traces = TraceNameList(win_name, ";", 1)
	
	//for loop goes through each wave on graph until there aren't anymore
	for(i=0;i<ItemsInList(traces);i+=1)
		string Trace =  stringfromlist(i,traces)
		Wave TraceWave=TraceNameToWaveRef(win_name,trace)
		
		duplicate/o TraceWave TempWave
			TempWave*=-1
		
		FindSpikeTimesAG(TempWave, startTime, endTime, Threshold)
		wave spikeRates, spikeIntervals;// edit spikeRates, SpikeTimes
		//Finds the average firing rate across the whole second
			wavestats/q spikeRates
			attFR = v_avg
			redimension/n=(i+1) attFRwave
			attFRwave[i] =attFR
		//Finds the CV
			wavestats/q SpikeIntervals
			attCV = (v_sdev / v_avg)
			redimension/n=(i+1) attCVwave
			attCVwave[i] = attCV
		endfor
		
		wavestats/q attFRwave
			variable extraCellRate = v_avg
			print "cell attached FR = ", extraCellRate
		wavestats/q attCVwave
			variable extraCellCV = v_avg
			print "cell attached CV = ", extraCellCV
	
End

//// $URL: svn://raptor.cnbc.cmu.edu/rick/recording-artist/Recording%20Artist/Other/Minis.ipf $
//// $Author: rick $
//// $Rev: 632 $
//// $Date: 2013-03-15 17:17:39 -0700 (Fri, 15 Mar 2013) $
//
//#pragma moduleName=Minis
//#pragma rtGlobals=1		// Use modern global access method.
//#include "Batch Wave Functions"
//#include "Fit Functions"
////#include "Utilities"
////#include "List Functions"
//#include "Progress Window"
//
//strconstant minisFolder="root:Minis:"
//strconstant miniFitCoefs="Rise Time;Decay Time;Offset Time;Baseline;Amplitude;" // Rise_Time will be fixed to 1 ms.  
//strconstant miniRankStats="Chi-Squared;Event Size;Event Time;R2;Log(1-R2);Cumul Error;Mean Error;MSE;Score;Rise 10%-90%;Interval;Plausability;pFalse;"
//strconstant miniOtherStats="Fit Time Before;Fit_Time_After;"
////strconstant miniFitCoefs="Decay_Time;Offset_Time;y0;Amplitude"
//constant miniFitBefore=6 // In ms.  
//constant miniFitAfter=9 // In ms.  
//
//#ifdef SQL
//	override constant SQL_=1
//#endif
//constant SQL_=0
//constant fitOffset=25
//
//#if exists("SQLHighLevelOp") && strlen(functionlist("SQLConnekt",";",""))
//#define SQL
//#endif
//
//// Static functions that replace those found in the Acq package, if it is not present.  
//#ifndef Acq
//// Returns a list of used channels.   
//#if !exists("UsedChannels")
//static Function /S UsedChannels()
//	String currFolder=GetDataFolder(1)
//	Variable i,j
//	String str1,str2,channelsUsed=""
//	for(i=0;i<CountObjects("root:",4);i+=1)
//		String folder=GetIndexedObjName("root:",4,i)
//		for(j=0;j<CountObjects("root:"+folder,1);j+=1)
//			String wave_name=GetIndexedObjName("root:"+folder,1,j)
//			sscanf wave_name,"%[sweep]%s",str1,str2
//			if(StringMatch(str1,"sweep") && numtype(str2num(str2))==0)
//				channelsUsed+=folder+";"
//				break
//			endif
//		endfor
//	endfor
//	return channelsUsed
//End
//#endif
//
//// Returns a list of methods using the code in case 'method'.  Usually this will be a list with one element, the same as the input.  
//static Function /S MethodList(method)
//	String method
//	
//	Variable i
//	String methods=ListPackageInstances(module,"analysisMethods")
//	String matchingMethods=""
//	for(i=0;i<ItemsInList(methods);i+=1)
//		String oneMethod=StringFromList(i,methods)
//		string sourceMethod=StrPackageSetting(module,"analysisMethods",oneMethod,"method")
//		if(stringMatch(sourceMethod,method))
//			matchingMethods+=oneMethod+";"
//		endif
//	endfor
//	return matchingMethods
//End
//
//// Returns the name of the top-most trace on a graph.  
//// Simplified version of function in 'Experiment Facts.ipf', reproduced here for simplicity.  
//static Function /S TopTrace()
//	String traces=TraceNameList("",";",1)
//	String topTrace=StringFromList(ItemsInList(traces)-1,traces)
//	return topTrace
//End
//
//static Function RemoveTraces()
//	String traces=TraceNameList("",";",1)
//	traces=SortList(traces,";",16)
//	Variable i=ItemsInList(traces)-1
//	Do
//		String trace=StringFromList(i,traces)
//		RemoveFromGraph /Z $trace
//		i-=1
//	While(i>=0)
//End
//#endif
//
//Menu "Analysis"
//	"Minis",/Q,InitMiniAnalysis() 
//End
//
//Function InitMiniAnalysis()
//	variable err=0
//	variable lastSweep=GetCurrSweep()
//	if(!lastSweep)
//		DoAlert 0,"No experiment data to use."
//		err=-1
//	else
//		dfref df=NewFolder(minisFolder)
//		string /g df:sweeps="0-"+num2str(lastSweep-1)
//		variable /g df:threshold=-5
//		MiniAnalysisPanel()
//	endif
//	return err
//End
//
//function /s GetUsedMiniChannels()
//	string channels=UsedChannels()
//	variable i
//	do
//		string channel=stringfromlist(i,channels)
//		dfref df=GetMinisChannelDF(channel,proxy=0)
//		if(!datafolderrefstatus(df))
//			channels=removefromlist(channel,channels)
//		else
//			i+=1
//		endif
//	while(i<itemsinlist(channels))
//	return channels
//end
//
//function /df GetMinisDF()
//	dfref df=newfolder(minisFolder)
//	string variables
//	sprintf variables,"currMini=0;fit_before=%f;fit_after=%f",miniFitBefore,miniFitAfter
//	string strings
//	sprintf strings,"channels=%s;",""//GetUsedMiniChannels()
//	InitVars(df=df,vars=variables,strs=strings)
//	return df
//end
//
//function /df GetMinisChannelDF(channel[,create,proxy])
//	string channel
//	variable create,proxy
//	
//	if(paramisdefault(proxy))
//		proxy=GetMinisProxyState()
//	endif
//	string suffix=""
//	if(proxy)
//		suffix="_"+cleanupname(stringfromlist(proxy,proxies),0)
//	endif
//	dfref df=GetMinisDF()
//	if(create)
//		newdatafolder /o df:$(channel+suffix)
//	endif
//	dfref df_=df:$(channel+suffix)
//	return df_
//end
//
//function /df GetMinisSweepDF(channel,sweep[,create,proxy])
//	string channel
//	variable sweep,create,proxy
//	
//	proxy = paramisdefault(proxy) ? GetMinisProxyState() : proxy
//	
//	dfref df=GetMinisChannelDF(channel,proxy=proxy)
//	string name="sweep"+num2str(sweep)
//	if(create)
//		newdatafolder /o df:$name
//	endif
//	dfref df_=df:$name
//	return df_
//end
//
//function /df GetMinisOptionsDF([create])
//	variable create
//	
//	dfref df=GetMinisDF()
//	if(create)
//		newdatafolder /o df:options
//	endif
//	dfref df_=df:options
//	return df_
//end
//
//Function MiniAnalysisPanel()
//	DoWindow /K MiniAnalysisWin
//	NewPanel /K=1 /N=MiniAnalysisWin as "Mini Analysis"
//	Variable xStart=0,yStart=0,xx=xStart,yy=yStart,xJump=65,yJump=25
//	PopupMenu Channels, pos={xx,yy}, value=#("ListCombos(\""+UsedChannels()+"\")"),title="Channels",mode=ItemsInList(ListCombos(UsedChannels())),proc=MiniAnalysisWinPopupMenus
//	yy+=yJump
//	
//	dfref df=GetMinisDF()
//	svar /sdfr=df sweeps
//	nvar /sdfr=df threshold
//	
//	SetVariable Sweeps, pos={xx,yy}, size={200,20}, title="Sweeps", value=_STR:sweeps,proc=MiniAnalysisWinSetVariables
//	yy+=yJump
//	Checkbox Clean, pos={xx,yy}, value=0,title="Clean",proc=MiniAnalysisWinCheckboxes
//	xx+=xJump
//	Checkbox Search, pos={xx,yy}, value=1,title="Search",proc=MiniAnalysisWinCheckboxes
//	xx+=xJump
//	Checkbox UseCursors, pos={xx,yy}, value=0,title="Cursors",proc=MiniAnalysisWinCheckboxes
//#ifdef SQL
//	xx+=xJump
//	Checkbox DB, pos={xx,yy}, value=0,title="Database",proc=MiniAnalysisWinCheckboxes
//#endif
//	xx+=xJump
//	PopupMenu proxy, pos={xx,yy-3}, mode=1,value=proxies,title="Proxy",proc=MiniAnalysisWinPopupMenus
//	xx=xStart; yy+=yJump
//	SetVariable Threshold, pos={xx,yy}, size={95,20}, title="Threshold", limits={-Inf,Inf,0.5}, value=threshold,proc=MiniAnalysisWinSetVariables
//	xx=xStart; yy+=yJump
//	Button Start, pos={xx,yy}, title="Start", proc=MiniAnalysisWinButtons
//End
//
//Function MiniAnalysisWinButtons(ctrlName)
//	String ctrlName
//	
//	string type=StringFromList(0,ctrlName,"_")
//	string channel=ctrlName[strlen(type)+1,strlen(ctrlName)-1]
//	strswitch(type)
//		case "Start":
//			Controlinfo Clean; Variable clean=V_Value
//			Controlinfo Search; Variable miniSearch=V_Value
//			ControlInfo Channels; String channels=ReplaceString(",",S_Value,";")
//			Controlinfo DB; Variable DB=V_Value
//			Controlinfo proxy; Variable proxy=V_Value-1
//			Controlinfo Threshold; Variable threshold=V_Value
//			Controlinfo Sweeps; String sweeps=S_Value
//			ControlInfo UseCursors; Variable useCursors=V_Value
//			Variable tStart=(useCursors && strlen(csrinfo(A,"SweepsWin")) ? xcsr(A,"SweepsWin") : 0
//			Variable tStop=(useCursors && strlen(csrinfo(B,"SweepsWin")) ? xcsr(B,"SweepsWin") : Inf
//			CompleteMiniAnalysis(clean=clean,miniSearch=miniSearch,channels=channels,threshold=threshold,noDB=!DB,sweeps=sweeps,tStart=tStart,tStop=tStop,proxy=proxy)
//			break
//		case "ShowMinis":
//			dfref df=GetMinisDF()
//			svar /sdfr=df channelsUsed
//			//Wave /T Baseline_Sweeps,Post_Activity_Sweeps
//			//String regions=Baseline_Sweeps[0]+Post_Activity_Sweeps[0]
//			Variable i
//			for(i=0;i<ItemsInList(channelsUsed);i+=1)
//				channel=StringFromList(i,channelsUsed)
//				dfref chanDF=GetMinisChannelDF(channel)
//				wave /t/sdfr=chanDF MiniCounts,MiniNames
//				wave /sdfr=chanDF MC_SelWave
//				MiniCounts[][2]=SelectString(MC_SelWave[p][2] & 16,"Ignore","Use") // Update MiniCounts to reflect the value of the Checkbox.  May not be necessary.  
//				if(!waveexists(miniNames))
//					InitMiniStats(channel)
//				endif
//			endfor
//			ShowMinis(channels=channelsUsed)//,regions=regions)
//			break
//		case "Ignore":
//			dfref chanDF=GetMinisChannelDF(channel)
//			wave /t/sdfr=chanDF MiniCounts
//			wave /sdfr=chanDF MC_SelWave
//			variable sweepNum
//			for(i=0;i<numpnts(MC_SelWave);i+=1)
//				if(MC_SelWave[i][0]>0)
//					MC_SelWave[i][2] = 32
//					MiniCounts[i][2]="Ignore"  
//				endif
//			endfor
//			break
//	endswitch
//End
//
//Function MiniAnalysisWinCheckboxes(ctrlName,value)
//	String ctrlName
//	Variable value
//	
//	dfref df=GetMinisDF()
//	strswitch(ctrlName)
//		case "DB":
//			SetVariable Sweeps, disable=value
//			break
//	endswitch
//End
//
//Function MiniAnalysisWinSetVariables(info)
//	Struct WMSetVariableAction &info
//	
//	if(info.eventCode<0)
//		return 0
//	endif
//	dfref df=GetMinisDF()
//	strswitch(info.ctrlName)
//		case "Sweeps":
//			string /g df:sweeps=ListExpand(info.sval)
//			break
//	endswitch
//End
//
//Function MiniAnalysisWinPopupMenus(info)
//	Struct WMPopupAction &info
//	
//	if(!PopupInput(info.eventCode))
//		return 0
//	endif
//	dfref df=GetMinisDF()
//	strswitch(info.ctrlName)
//		case "Channels":
//			//Wave Channels=root:Minis:Channels
//			//String used=UsedChannels()
//			//Channels=WhichListItem(StringFromList(p,used),info.popStr)>=0
//			break
//		case "Proxy":
//			variable /g df:proxy=whichlistitem(info.popStr,proxies)
//			nvar /sdfr=df proxy
//			string suffix=""
//			if(proxy)
//				suffix="_"+cleanupname(info.popStr,0)
//			endif
//			string channels=UsedChannels()
//			variable i
//			for(i=0;i<itemsinlist(channels);i+=1)
//				string channel=stringfromlist(i,channels)
//				string ctrlName="MiniCounts_"+channel
//				controlinfo $ctrlName
//				if(v_flag>0)
//					variable create=0
//					df=GetMinisChannelDF(channel)
//					if(datafolderrefstatus(df))
//						wave /z/sdfr=df MC_SelWave
//						if(!waveexists(MC_SelWave))
//							create=1
//						endif
//					else
//						create=1
//					endif
//					if(create)
//						InitMiniCounts(channel)
//						df=GetMinisChannelDF(channel)
//						if(!datafolderrefstatus(df))
//							break
//						endif
//					endif
//					wave /sdfr=df MC_SelWave
//					wave /t/sdfr=df MiniCounts
//					Listbox $ctrlName,listWave=MiniCounts,selWave=MC_SelWave
//				endif
//			endfor
//			break
//	endswitch
//End
//
//// Keeps the listboxes in sync 
//Function MiniAnalysisWinListboxes(info) : ListBoxControl
//	STRUCT WMListboxAction &info
//	
//	variable numChannels=GetNumChannels()
//	Wave /T Labels=GetChanLabels()
//	
//	String type=StringFromList(0,info.ctrlName,"_")
//	String channel=info.ctrlName
//	channel=channel[strlen(type)+1,strlen(channel)-1]
//	String listboxName="MiniCounts_"+channel
//	dfref df=GetMinisChannelDF(channel)
//	if(!DataFolderRefStatus(df))
//		return -1
//	endif
//	
//	switch(info.eventCode)
//		case 2: // Clicking the mouse.  
//			// Pass through to case 4.  
//		case 4: // Picking a new sweep.  			
//			Wave /T/sdfr=df MiniCounts
//			Wave /sdfr=df MC_SelWave
//			variable i,sweepNum=str2num(MiniCounts[info.row][0])	
//			variable numMinis=str2num(MiniCounts[info.row][1])
//			variable numSweeps=dimsize(MiniCounts,0)
//			if(numtype(numMinis))
//				MC_SelWave[info.row][2]=MC_SelWave[info.row][2] & ~16
//			endif
//			if(info.col==2)
//				MiniCounts[info.row][2]=SelectString(MC_SelWave[info.row][2] & 16,"Ignore","Use") // Update MiniCounts to reflect the value of the Checkbox.  
//				wave /z/sdfr=df Use,Index
//				if(waveexists(Use) && info.eventCode==2)
//					make /free/n=(numSweeps) counts=str2num(MiniCounts[p][1])
//					insertpoints 0,1,counts
//					counts[0]=0
//					integrate counts
//					variable start=counts[info.row]
//					variable finish=counts[info.row+1]-1
//					if(finish>=start)
//						variable yes=stringmatch(MiniCounts[info.row][2],"Use")
//						Use[start,finish]=yes
//						for(i=start;i<=finish;i+=1)
//							FindValue /V=(i) Index
//							if(yes && v_value<0)
//								insertpoints 0,1,Index
//								Index[0]=i
//							elseif(!yes && v_value>=0)
//								deletepoints i,1,index
//							endif
//						endfor
//					endif
//				endif
//			endif
//			if(info.eventCode==2)
//				break
//			endif
//			Variable chan=Label2Chan(channel)
//			if(WinType("SweepsWin"))
//				Checkbox $("Show_"+num2str(chan)) value=1, win=SweepsWin
//			endif
//			//sweepNum=str2num(MiniCounts[info.row][0])
//#if exists("MoveCursor")==6
//			MoveCursor("A",sweepNum)
//#endif
//			break
//		case 8: // Vertical scrolling.  Used to keep listboxes in sync (always scrolled vertically to the same degree).  
//			for(i=0;i<numChannels;i+=1)
//				String otherChannel=Labels[i]
//				if(!StringMatch(channel,otherChannel))
//					String otherListboxName="MiniCounts_"+otherChannel
//					ControlInfo $otherListboxName
//					if(V_flag !=0 && V_startRow != info.row) // If the listbox exists and is not at the same row as the selected listbox.  
//						Listbox $otherListboxName,row=info.row
//						ControlUpdate $listboxName
//					endif
//				endif
//			endfor
//			break
//	endswitch
//End
//
//// ----------------------------- Other mini analysis functions.  ---------------------------------
//
//Function CompleteMiniAnalysis([clean,miniSearch,channels,threshold,skip,noDB,sweeps,tStart,tStop,proxy])
//	Variable clean // Clean the sweeps first (remove noise).
//	Variable miniSearch // Proceed with the search for minis, (after cleaning if clean=1).    
//	String channels // Channels to analyze.  
//	Variable threshold // Threshold for minis (in pA).  
//	String skip // Regions to skip in the format "channel: region".  Not yet implemented.  
//	Variable noDB // Don't look for a list of sweeps in the database.  Just use the cursors in Ampl_Analysis.  
//	String sweeps // A manual sweeps.  
//	variable tStart,tStop // Start and stop time values within each sweep to search.  
//	variable proxy // Search time-reversed sweeps, to serve as a control.  
//	
//	if(!paramisdefault(proxy))
//		SetMinisProxyState(proxy)
//	else
//		proxy=GetMinisProxyState()
//	endif
//	clean=ParamIsDefault(clean) ? 0 : clean
//	miniSearch=ParamIsDefault(miniSearch) ? 1 : miniSearch
//	if(ParamIsDefault(channels))
//		channels=UsedChannels()
//	endif
//	threshold=ParamIsDefault(threshold) ? 7.5 : threshold
//	if(ParamIsDefault(sweeps))
//		sweeps=""
//	endif
//	
//	variable i,j,currSweep=GetCurrSweep()
//	dfref df=NewFolder(minisFolder)
//	variable /g df:miniThresh=threshold
//	string fileName=IgorInfo(1)
//	
//	if(noDB || !ParamIsDefault(sweeps))
//		if(!ParamIsDefault(sweeps))
//		elseif(WinType("AnalysisWin") && strlen(CsrInfo(A,"AnalysisWin")))
//			sweeps=num2str(xcsr(A,"Ampl_Analysis"))+","+num2str(xcsr(B,"Ampl_Analysis"))
//		else
//			printf"You must provide a database entry, or an Ampl_Analysis window with cursors, or a sweep list.\r"  
//			return 0
//		endif
//		sweeps=ListExpand(sweeps)
//	else
//#ifdef SQL
//		// Connect to the database and get the information about which sweeps should be searched for minis.  
//		SQLConnekt("Reverb")
//		SQLc("SELECT * FROM Mini_Sweeps WHERE Experimenter='RCG' AND File_Name='"+fileName+"'")
//		SQLDisconnekt()
//		Wave /T Baseline_Sweeps,Post_Activity_Sweeps
//		
//		// Add all of the sweeps from the lists contained in the database to 'sweeps', a list of sweeps that will be processed.  
//		for(i=0;i<ItemsInList(Baseline_Sweeps[0]);i+=1)
//			string temp_list=StringFromList(i,Baseline_Sweeps[0])
//			sweeps+=ListExpand(temp_list)
//		endfor
//		for(i=0;i<ItemsInList(Post_Activity_Sweeps[0]);i+=1)
//			temp_list=StringFromList(i,Post_Activity_Sweeps[0])
//			sweeps+=ListExpand(temp_list)
//		endfor
//#endif
//	endif
//	
//	// Prepare to measure the progress of the subsequent operations.  
//	variable numChannels=itemsinlist(channels)
//	make /free/n=(numChannels) channelSweeps
//	for(i=0;i<numChannels;i+=1)
//		string channel=StringFromList(i,channels)
//		for(j=0;j<ItemsInList(sweeps);j+=1)
//			variable sweepNum=NumFromList(j,sweeps)
//			wave /Z sweep=GetChannelSweep(channel,sweepNum)
//			if(WaveExists(Sweep))
//				channelSweeps[i]+=1
//			endif
//		endfor
//	endfor
//	
//	// Cleaning up the sweeps.  
//	if(clean)
//#ifdef Acq
//		for(i=0;i<numChannels;i+=1)
//			channel=StringFromList(i,channels)
//			if(numChannels>1)
//				Prog("Channel",i,numChannels,msg=channel)
//			endif
//			variable sweepsCompleted=0
//			for(j=0;j<ItemsInList(sweeps);j+=1)
//				sweepNum=NumFromList(j,sweeps)
//				wave /Z sweep=GetChannelSweep(channel,sweepNum)
//				if(WaveExists(Sweep))
//					Prog("Removing noise...",sweepsCompleted,channelSweeps[i],msg="Sweep "+num2str(sweepNum))
//					CleanWaves(channel,num2str(sweepNum))
//					sweepsCompleted+=1
//				endif
//			endfor
//		endfor
//#endif
//	endif
//	
//	// Searching for minis.  
//	if(miniSearch)
//		//sweepsCompleted=0
//		string /G df:sweeps=sweeps
//		for(i=0;i<numChannels;i+=1)
//			channel=StringFromList(i,channels)
//			if(numChannels>1)
//				Prog("Channel",i,itemsinlist(channels),msg=channel)
//			endif
//			InitMiniCounts(channel)
//			SetMinisChannel(channel)
//			dfref df=GetMinisChannelDF(channel)
//			wave /t/sdfr=df MiniCounts
//			sweepsCompleted=0
//			string formattedChannel=selectstring(proxy,channel,channel+" ("+stringfromlist(proxy,proxies)+")")
//			for(j=0;j<ItemsInList(sweeps);j+=1)
//				sweepNum=str2num(StringFromList(j,sweeps))
//				MiniCounts[j][0]=num2str(sweepNum)
//				wave /z sweep=GetChannelSweep(channel,sweepNum)
//				if(WaveExists(Sweep))
//					string msg
//					sprintf msg,"%s sweep %d",formattedChannel,sweepNum
//					Prog("Searching for minis...",sweepsCompleted,channelSweeps[i],msg=msg,parent="Channel")
//					tStart=paramisdefault(tStart) ? leftx(Sweep) : tStart
//					tStop=paramisdefault(tStop) ? rightx(Sweep) : tStop
//					variable count=MiniAnalysis(sweepNum,channel,thresh=threshold,clean=0,tStart=tStart,tStop=tStop,proxy=proxy)
//					MiniCounts[j][1]=num2str(count)
//					MiniCounts[j][2]="Use"
//					sweepsCompleted+=1
//				endif
//			endfor
//			//WaveStats /Q/M=1 MiniCounts
//			//Variable /G root:Minis:$(channel):raw_mini_count=round(V_avg*V_npnts)
//		endfor
//		MiniCountReview(channels)
//	endif
//End
//
//Function MiniCountReview(channels)
//	String channels
//	if(!WinType("MiniAnalysisWin"))
//		return -1
//	endif
//	
//	Struct rect coords
//	Core#GetWinCoords("MiniAnalysisWin",coords,forcePixels=1)
//	MoveWindow /W=MiniAnalysisWin coords.left,coords.top,coords.left+125*(max(2,ItemsInList(channels))),coords.top+350
//	DoWindow /F MiniAnalysisWin
//	Variable xStart=0,yStart=150,xx=xStart,yy=yStart,xJump=165
//	Variable i;String channel
//	Variable num_channels=ItemsInList(channels)
//	dfref df=GetMinisDF()
//	for(i=0;i<num_channels;i+=1)
//		yy=yStart
//		channel=StringFromList(i,channels)
//		dfref chanDF=GetMinisChannelDF(channel,create=1)
//		InitMiniStats(channel)
//		svar /sdfr=df sweeps
//		wave /t/sdfr=chanDF MiniCounts
//		make /o/n=(dimsize(MiniCounts,0),dimsize(MiniCounts,1)) chanDF:MC_SelWave /wave=MC_SelWave
//		MC_SelWave=0
//		MC_SelWave[][2]=32+16*StringMatch(MiniCounts[p][2],"Use")//*(WhichListItem(num2str(p),sweeps)>=0)
//		DrawText xx,yy,"Sweep"; xx+=47
//		DrawText xx,yy,"Minis"; xx+=57
//		DrawText xx,yy,"Use"; xx=xStart+i*xJump
//		yy+=5
//		ListBox $("MiniCounts_"+channel),widths={35,40,60},size={160,100},pos={xx,yy},listWave=MiniCounts,selWave=MC_SelWave,frame=2,mode=4,proc=MiniAnalysisWinListboxes
//		//String /G ignore_sweeps=""
//		yy+=100
//		Button $("Ignore_"+channel),pos={xx,yy},size={160,20},title=channel+" ignore",proc=MiniAnalysisWinButtons
//		xx+=xJump
//	endfor
//	string /g df:channelsUsed=channels
//	xx=xStart; yy+=35
//	Button ShowMinis,pos={xx,yy},size={100,20},proc=MiniAnalysisWinButtons,title="Show Minis"
//	xx+=120; yy+=3
//	Checkbox IgnoreStimulusSweeps,pos={xx,yy},size={100,20},title="Ignore Sweeps with Stimuli",value=0
//End
//
//Function MiniTimeCoursePlot(channel)
//	String channel
//	dfref df=GetMinisChannelDF(channel)
//	make /o/n=0 df:AllLocs /wave=AllLocs,df:AllVals /wave=AllVals
//	Variable i
//	wave Sweep_t=GetSweepT()
//	for(i=0;i<numpnts(Sweep_t);i+=1)
//		Variable sweep_time=Sweep_t[i]
//		Variable sweepNum=i+1
//		String mini_folder="Sweep"+num2str(sweepNum)
//		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
//		if(DataFolderRefStatus(sweepDF))
//			wave /z/sdfr=sweepDF Locs,Vals
//			Variable index=numpnts(AllLocs)
//			if(waveexists(Locs) && numtype(sweep_time)==0)
//				Locs+=sweep_time*60
//				Concatenate /NP {Locs},AllLocs
//				Locs-=sweep_time*60
//				Concatenate /NP {Vals},AllVals
//			endif
//		endif
//	endfor
//	AllLocs/=60
//	Display /K=1 AllVals vs AllLocs
//	ModifyGraph mode=2
//	ModifyGraph lsize=3
//	Duplicate /o AllVals AvgVals
//	AvgVals=mean(AllVals,p-35,p+35)
//	AppendToGraph /c=(65535,0,0) AvgVals vs AllLocs
//End
//
//// Average the minis currently available in the Mini Browser and display the average waveform.  
//Function AverageMinis([peak_align,peak_scale])
//	variable peak_align // Aligns to fitted peak.  Otherwise, aligns to fitted offset.  
//	variable peak_scale // Scales all minis so that fitted event size equals 1.  
//	
//	removefromgraph /z AverageMini
//	controlinfo Channel; string channel=s_value
//	//Display /K=1 /N=$("AllMinis_"+channel)
//	dfref df=GetMinisChannelDF(channel)
//	wave /sdfr=df /T MiniNames
//	wave /z/sdfr=df Event_Size,Offset_Time,Baseline
//	variable i,miniNum,sweepNum
//	variable red,green,blue; GetChannelColor(channel,red,green,blue)
//	string traces=TraceNameList("",";",1)
//	variable minis=0
//	for(i=0;i<itemsinlist(traces);i+=1)
//		string trace=stringfromlist(i,traces)
//		FindValue /TEXT=trace /TXOP=4 MiniNames
//		if(v_value<0)
//			printf "Couldn't find index for mini in trace %s.\r",trace
//			continue
//		else
//			variable index=v_value
//		endif
//		sscanf trace, "Sweep%d_Mini%d", sweepNum, miniNum
//		wave sweep=GetChannelSweep(channel,sweepNum)
//		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
//		wave /z/sdfr=sweepDF Locs
//		wave /z MiniIndex=sweepDF:Index
//		if(numtype(Locs[index]*Offset_Time[index]*Event_Size[index]*Baseline[index]))
//			printf "No fit available for %s.\r",trace
//			continue
//		endif
//		if(!peak_align)
//			variable loc=Offset_Time[index]/1000//Locs[miniNum]
//		elseif(peak_align)
//			wave /sdfr=sweepDF Fit=$("Fit_"+num2str(miniNum))
//			wavestats /Q/M=1 Fit
//			FindValue /V=(miniNum) MiniIndex
//			loc=Locs[V_Value]+V_minloc
//		endif
//		variable scale=peak_scale ? 1/Event_Size[index] : 1
//		if(minis==0)
//			duplicate /o/r=(loc-0.015,loc+0.03) sweep, df:AverageMini /wave=AverageMini
//			setscale x,-0.015,0.03,AverageMini
//			AverageMini=(AverageMini-Baseline[index])*scale
//		else
//			AverageMini+=(sweep(loc+x)-Baseline[index])*scale
//		endif
//		minis+=1
//	endfor
//	if(minis)
//		AverageMini/=minis
//		red=min(60000,65535-red); green=min(60000,65535-green); blue=min(60000,65535-blue)
//		appendtograph /c=(65535-red,65535-green,65535-blue) AverageMini
//		ModifyGraph lsize($TopTrace())=2
//	else
//		printf "No traces with minis were found.\r"
//	endif
//End
//
//
//// Score a wave for minis according to the Bekkers and Clements method.  
//Function MiniScore(Data,Template)
//	Wave Data,Template
//	Variable length=numpnts(Template)
//	Make /o/n=(numpnts(Data)-length+1) MiniScores=NaN
//	Duplicate/o Template Fitted_Template
//	Variable i
//	//Duplicate/o/R=[0,0+length-1] Data, $"Piece"; Wave Piece
//	for(i=0;i<numpnts(MiniScores);i+=1)
//		Duplicate/o/R=[i,i+length-1] Data, $"Piece"; Wave Piece
//		MatrixOp /o ScaleWave=(Template.Piece-sum(Template)*sum(Piece)/length)/(Template.Template-sum(Template)*sum(Template)/length)
//		Variable Offset=(sum(Piece)-ScaleWave[0]*sum(Template))/length;
//		//MatrixOp /o Fitted_Template=Template*Scale[0]+Offset;
//    		MatrixOp /o SSE=sumsqr(Piece-Fitted_Template)
//		Variable Standard_Error=sqrt(SSE[0]/(length-1)) // Should this be -1 or not?  
//		MiniScores[i]=ScaleWave/Standard_Error
//    	endfor
//    	CopyScales /P Data,MiniScores
//End
//
//Function PlotAllMiniFits(channel)
//	String channel
//	Variable i,j
//	Variable red,green,blue; GetChannelColor(channel,red,green,blue)
//	dfref df=GetMinisChannelDF(channel)
//	wave /t/sdfr=df MiniNames
//	wave /sdfr=df Index
//	Display /K=1
//	for(i=0;i<numpnts(Index);i+=1)
//		String mini_name=MiniNames[Index[i]]
//		Variable sweepNum,miniNum
//		sscanf mini_name, "Sweep%d_Mini%d", sweepNum,miniNum
//		String fit
//		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
//		wave /sdfr=sweepDF FitWave=$("Fit_"+num2str(miniNum))
//		wave /sdfr=df Baseline,Offset_Time,Event_Size
//		variable x1=Offset_Time[Index[i]]
//		variable y1=Baseline[Index[i]]
//		variable ampl=Event_Size[Index[i]]
//		wave /sdfr=sweepDF Locs,Index
//		FindValue /V=(miniNum) Index
//		variable mini_loc=Locs[V_Value]*1000
//		variable fit0=FitWave[0]
//		FitWave-=fit0
//		AppendToGraph /c=(red,green,blue) FitWave
//		String top_trace=TopTrace()
//	endfor
//End
//
//// Analyzes a sweep for minis.  
//Function MiniAnalysis(sweepNum,channel[,thresh,clean,tStart,tStop,proxy])
//	Variable sweepNum
//	String channel
//	Variable thresh
//	Variable clean // Remove line noise(s)
//	Variable tStart,tStop // Start and stop times within the sweep to search
//	variable proxy
//	
//	if(!paramisdefault(proxy))
//		SetMinisProxyState(proxy)
//	else
//		proxy=GetMinisProxyState()
//	endif
//	thresh=ParamIsDefault(thresh) ? 5 : thresh
//	wave /z Sweep=GetChannelSweep(channel,sweepNum,proxy=proxy)
//	if(!WaveExists(Sweep))
//		return -1
//	endif
//	string sweepName=getwavesdatafolder(sweep,2)
//	tStart=ParamIsDefault(tStart) ? leftx(Sweep) : tStart
//	tStop=(ParamIsDefault(tStop) || numtype(tStop)) ? rightx(Sweep) : tStop
//	dfref df=GetMinisDF()
//	dfref df=GetMinisSweepDF(channel,sweepNum,create=1)
//#ifdef Acq  
//	duplicate /free Sweep w
//	string stim_regions=StimulusRegionList(channel,sweepNum,includeGaps=1)
//	SuppressRegions(w,stim_regions,factor=10000,method="Squash")
//	if(clean)
//		NewNotchFilter(w,60,10)
//		//RemoveWiggleNoise(SweepCopy)
//	endif
//	Wave Sweep=w
//#endif
//	// Flip time if the reverse proxy is being used.  
//	variable start=(proxy==1) ? rightx(Sweep)-tStop : tStart
//	variable stop=(proxy==1) ? rightx(Sweep)-tStart : tStop
//	FindMinis(Sweep,df=df,thresh=thresh,within_median=10,tStart=start,tStop=stop,sweepName=sweepName)
//	WaveStats /Q/M=1 Sweep
//	wave /sdfr=df Locs,Vals
//	nvar /sdfr=df net_duration
//	Note /K Locs num2str(net_duration)
//	variable count=numpnts(Locs)
//	return count
//End
//
//// Finds minis in a sweep.  
//Function /wave FindMinis(w0[,df,thresh,tStart,tStop,within_median,print_stats,sweepName])
//	wave w0
//	variable thresh,tStart,tStop
//	variable within_median // Mini onset must occur at no less than 'within_median' + the median current of the sweep in order to be counted.  This excludes most events that occur during PSC groups.  
//	variable print_stats
//	dfref df
//	string sweepName
//	
//	if(paramisdefault(df))
//		df=GetDataFolderDFR()
//	endif
//	thresh=ParamIsDefault(thresh) ? 5 : thresh
//	tStart=ParamIsDefault(tStart) ? leftx(w0) : tStart
//	tStop=ParamIsDefault(tStop) ? rightx(w0) : tStop
//	within_median=ParamIsDefault(within_median) ? Inf : within_median
//	
//	if(tStop-tStart<=0)
//		return NULL
//	endif
//	duplicate /free/r=(tStart,tStop) w0 w,w_smooth
//	variable /g df:net_duration=tStop-tStart
//	nvar /sdfr=df net_duration
//	variable kHz=0.001/dimdelta(w,0)
//	// High-pass
//		//smooth /m=0 100*kHz+1,w_smooth // 100 ms median smoothing (for removal of low frequency components).  
//		resample /rate=10 w_smooth
//		//smooth /b=1 100*kHz+1,w_smooth // 100 ms boxcar smoothing (for removal of low frequency components).  
//		w-=w_smooth(x)
//	// Low-pass
//		resample /rate=1000 w
//		//tac()
//		//resample /rate=(kHz*1000) w
//		//smooth /b=1 2*kHz+1,w // 2 ms box-car smoothing.  
//	make /free/n=(dimsize(w,0)) Peak=0
//	SetScale/P x 0,dimdelta(w,0), Peak
//	Make /o/n=0 df:Locs,df:Vals,df:Index
//	wave /sdfr=df Locs,Vals,Index
//	variable i,rise_time=0.0015 // seconds
//	variable refract=0.01 // 10 ms minimum interval between minis. 
//	duplicate /free w,Jumps
//	Jumps-=w(x-rise_time)
//	FindLevels /Q/M=(refract)/EDGE=(thresh > 0 ? 1 : 2) Jumps,thresh; Wave W_FindLevels
//	for(i=0;i<numpnts(W_FindLevels);i+=1)
//		variable loc=W_FindLevels[i]	
//		if(w(loc-rise_time)<-within_median)
//			continue // Ignore events that start at a value < 'within_median' from the median current.  
//		endif
//	      WaveStats /Q/M=1/R=(loc-rise_time,loc+rise_time*3) w
//		variable magnitude=(thresh>0) ? (V_max-V_min) : (V_min-V_max)
//		Peak[x2pnt(theWave,loc)]=magnitude
//		InsertPoints 0,1,Locs,Vals,Index
//		Locs[0]=(thresh>0 ? V_maxloc : V_minloc)
//		Vals[0]=magnitude
//	endfor
//	Index=x
//	
//	WaveTransform /O flip, Locs
//	WaveTransform /O flip, Vals
//	KillWaves /Z W_FindLevels
//	if(print_stats)
//		printf "%d minis in %.2f seconds = %.2f Hz.",numpnts(Locs),net_duration,numpnts(Locs)/net_duration
//		printf "Median amplitude = %.2f pA.\r",StatsMedian(Vals)
//	endif
//	return Locs
//End
//
//// Assumes Minis have already been identified and locations and amplitudes are stored in root:Minis.  
//Function ShowMinis([channels])
//	string channels
//	
//	if(!WinType("ShowMinisWin"))
//		variable init=1 // If the Mini Browser window doesn't exist, we will initialize all the statistics.  Otherwise, we will just update them with changes made in the Mini Count Reviewer window.  
//	endif
//	variable i,numChannels=GetNumChannels()
//	
//	 // Set as the default channels those that are checked in the Sweeps window.  
//	if(ParamIsDefault(channels))
//		channels=""
//		if(wintype("SweepsWin"))
//			for(i=0;i<numChannels;i+=1)
//				string channel=Chan2Label(i)
//				ControlInfo /W=Sweeps $channel
//				if(V_Value)
//					channels+=channel+";"
//				endif
//			endfor
//			if(strlen(channels)==0)
//				DoAlert 0,"No channels selected in the window 'Sweeps'"
//				return -1
//			endif
//		endif
//		if(!strlen(channels))
//			channels=UsedChannels()
//		endif
//	endif
//	if(!strlen(channels))
//		DoAlert 0,"No channels available for use."
//		return -2
//	endif
//	if(!DataFolderExists(minisFolder))
//		printf "Must calculate Minis first using Recalculate() or CompleteMiniAnalysis().\r"
//		return -3
//	endif	
//		
//	// The main loop
//	for(i=0;i<itemsinlist(channels);i+=1)
//		channel=stringfromlist(i,channels)//Chan2Label(i)
//		dfref df=GetMinisChannelDF(channel)
//		wave /z/T/sdfr=df MiniNames
//		if(!waveexists(MiniNames))
//			init=1
//			InitMiniStats(channel) // Initialize all mini statistics.  
//			wave /T/sdfr=df MiniNames	
//		endif
//	endfor
//
//	// Display the minis that were found.  
//	if(init)
//		Display /K=1 /N=ShowMinisWin /W=(150,150,850,400) as "Mini Browser"
//		TextBox /MT/N=info/X=0/Y=0/F=0 "" 
//		SetWindow ShowMinisWin hook(select)=ShowMinisHook
//		dfref df=GetMinisDF()
//		Variable /G df:currMini=0
//		Variable /G df:fit_before=miniFitBefore
//		Variable /G df:fit_after=miniFitAfter
//	else
//		DoWindow /F ShowMinisWin
//	endif
//	SwitchMiniView("Browse")
//End
//
//function InitMiniCounts(channel)
//	string channel 
//	
//	dfref df=GetMinisChannelDF(channel,create=1)
//	svar /z/sdfr=GetMinisDF() sweeps
//	string sweeps_=ListExpand(sweeps)
//	variable numSweeps=itemsinlist(sweeps_)
//	make /o/t/n=(numSweeps,3) df:MiniCounts /wave=MiniCounts
//	MiniCounts[][0]=stringfromlist(p,sweeps)
//	MiniCounts[][1]="0"
//	MiniCounts[][2]="Use"
//	make /o/n=(numSweeps,3) df:MC_SelWave=(q==2) ? 48 : 0 
//end
//
//function InitMiniStats(channel)
//	string channel
//
//	dfref df=GetMinisChannelDF(channel)
//	wave /z/t/sdfr=df MiniCounts
//	if(!waveexists(MiniCounts))
//		printf "No such wave %sMiniCounts.\r",getdatafolder(1,df)
//	endif
//	ControlInfo /W=MiniAnalysisWin IgnoreStimulusSweeps
//	variable ignore_stimulus_sweeps=v_flag>0 ? v_value : 0
//	wave /sdfr=df MC_SelWave // The wave indicating the status of the entries in MiniCountReviewer.  
//	variable i,j,numMinis=0,numSweeps=dimsize(MiniCounts,0)
//	for(i=0;i<dimsize(MiniCounts,0);i+=1)
//		numMinis+=str2num(MiniCounts[i][1])
//	endfor
//	make /o/n=(numMinis) df:Use /wave=Use, df:Index /wave=Index=p
//	make /o/t/n=(numMinis) df:MiniNames /wave=MiniNames
//	string stats=miniFitCoefs+miniRankStats+miniOtherStats
//	for(i=0;i<ItemsInList(stats);i+=1)
//		string name=stringfromlist(i,stats)
//		make /o/n=(numMinis) df:$cleanupname(name,0) /wave=stat=nan
//	endfor
//	numMinis=0
//	for(i=0;i<dimsize(MiniCounts,0);i+=1)
//		variable hasStim=0
//		variable sweepNum=str2num(MiniCounts[i][0])
//#if exists("HasStimulus")==6
//		
//		hasStim=HasStimulus(sweepNum)
//#endif
//		variable start=numMinis
//		numMinis+=str2num(MiniCounts[i][1])
//		variable finish=numMinis-1
//		if(finish>=start)
//			if(!(MC_SelWave[i][2] & 16) || (ignore_stimulus_sweeps && hasStim)) // If the box for that stimulus is unchecked or that sweep has a stimulus and is to be ignored.  
//				variable include=0
//			else
//				include=1
//			endif
//			Use[start,finish]=include // Remove that sweep from the sweep list.  
//			MiniNames[start,finish]=GetMiniName(sweepNum,p-start)
//		endif
//	endfor
//	string /g df:direction="Down"
//end
//
//function /s GetMiniName(sweep,sweepMini)
//	variable sweep,sweepMini
//	
//	string name
//	sprintf name,"Sweep%d_Mini%d",sweep,sweepMini
//	return name
//end
//
//Function ShowMinisHook(info)
//	struct WMWinHookStruct &info
//	
//	dfref df=GetMinisDF()
//	nvar /sdfr=df currMini
//	switch(info.eventCode)
//		case 3: // Mouse down.  
//			string str
//			structput /s info.mouseLoc str
//			SetWindow ShowMinisWin userData(mouseDown)=str
//			if(!(info.eventMod & 1)) // If not the left mouse button.  
//				return 0
//			endif 
//			string mode=getuserdata("","","mode")
//			if(!stringmatch(mode,"All"))
//				return 0
//			endif
//			variable h=info.mouseLoc.h
//			variable v=info.mouseLoc.v
//			string trace=stringbykey("TRACE",TraceFromPixel(h,v,"WINDOW:ShowMinisWin"))
//			controlinfo Channel; string channel=s_value
//			variable red,green,blue
//			GetChannelColor(channel,red,green,blue)
//		
//			if(strlen(trace))
//				modifygraph rgb=((65535+red)/2,(65535+green)/2,(65535+blue)/2)
//				modifygraph rgb($trace)=(red,green,blue),lsize($trace)=3
//				ReorderTraces $TopTrace(), {$trace} 
//				dfref chanDF=GetMinisChannelDF(channel)
//				wave /t/sdfr=chanDF miniNames
//				findvalue /text=trace /txop=4 MiniNames
//				currMini=v_value
//				setwindow ShowMinisWin userData(selected)=trace
//			else
//				modifygraph rgb=(red,green,blue),lsize=0.5
//				setwindow ShowMinisWin userData(selected)=""
//				currMini=nan
//			endif
//			break
//		case 11: // Key down.  
//			switch(info.keyCode)
//				case 8: // Delete.  
//					RejectMini()
//				case 28: // Left arrow.  
//					GotoMini(currMini-1)
//					break
//				case 29: // Right arrow.  
//					GotoMini(currMini+1)
//					break	
//			endswitch
//			break
//		case 22: // Mouse wheel:
//			controlinfo Channel; channel=s_value
//			variable mini=currMini+info.wheelDy
//			if(mini>=0 && mini<NumMinis(channel))
//				GoToMini(mini)
//			endif
//			break
//	endswitch
//End
//
//Function NumMinis(channel)
//	string channel
//	
//	dfref df=GetMinisChannelDF(channel)
//	wave /sdfr=df Index
//	return numpnts(Index)
//End
//
//Function SwitchMiniView(mode)
//	String mode
//	
//	Variable all=StringMatch(mode,"All")
//	Variable browse=StringMatch(mode,"Browse")
//	if(!all && !browse)
//		return -1
//	endif
//	SetWindow ShowMinisWin userData(mode)=mode
//	dfref df=GetMinisDF()
//	nvar /sdfr=df currMini
//	svar /sdfr=df sweeps,channel=currChannel
//	variable i,j,sweepNum,miniNum
//	
//	// Remove old traces.  
//	string traces=TraceNameList("",";",1)
//	traces=SortList(traces,";",16)
//	
//	do
//		string trace=StringFromList(i,traces)
//		if(!strlen(trace))
//			RemoveFromGraph /Z $trace	
//		endif
//		i-=1
//	while(i>0)
//	
//	dfref chanDF=GetMinisChannelDF(channel)
//	if(!datafolderrefstatus(chanDF))
//		return -1
//	endif
//	string mini_name
//	wave /t/sdfr=chanDF MiniNames
//	wave /sdfr=chanDF Index
//	sscanf MiniNames[Index[currMini]],"sweep%d_mini%d",sweepNum,miniNum
//	string /G chanDF:direction="Down"
//	svar /sdfr=chanDF direction
//	wave /t Labels=GetChanLabels()
//	variable xx=3,yy=9
//	PopupMenu Channel pos={xx,yy}, mode=1+WhichListItem(channel,UsedChannels()), size={75,20}, proc=ShowMinisPopupMenus,value=#"UsedChannels()"
//	xx+=67
//	GroupBox FitBox pos={xx,yy-6}, size={343,31}
//	Button FitOneMini disable=!browse, pos={xx+6,yy-1}, size={30,20}, proc=ShowMinisButtons, title="Fit"
//	xx+=41
//	nvar /sdfr=df fit_before,fit_after
//	SetVariable Left disable=!browse, pos={xx,yy+1}, size={50,20}, value=fit_before, title="L:"
//	xx+=53
//	SetVariable Right disable=!browse, pos={xx,yy+1}, size={50,20}, value=fit_after, title="R:"
//	xx+=58
//	Button FitLesser disable=!browse, pos={xx,yy-1}, size={30,20}, proc=ShowMinisButtons, title="<="
//	Button FitGreater disable=!browse, size={30,20}, proc=ShowMinisButtons, title=">="
//	Button FitAll disable=!browse, size={40,20}, proc=ShowMinisButtons, title="Fit All" // Apply curve fits to all minis.  
//	Button Template disable=!browse, proc=ShowMinisButtons, title="Template", help={"Use the current curve fit as a template for Bekkers-Clements scoring."} 
//	
//	xx+=200
//	GroupBox RankBox pos={xx,yy-6}, size={210,31}
//	xx+=6
//	ValDisplay RankValue, disable=!browse, pos={xx,yy+1}, value=_NUM:0
//	xx+=55
//	Button RankMinis disable=!browse, pos={xx,yy-1}, size={52,20}, proc=ShowMinisButtons, title="Rank by: "
//	controlinfo RankChoices
//	variable popMode=v_flag>0 ? v_value : 1
//	xx+=60
//	PopupMenu RankChoices disable=!browse, pos={xx,yy-1}, fsize=8, mode=popMode,value=miniRankStats+miniFitCoefs,proc=ShowMinisPopupMenus
//	Variable num_minis=NumMinis(channel)
//	xx+=100
//	controlinfo sweepNum
//	if(GetMinisProxyState())//channel,sweepNum))
//		//Button StoreTimeReversed disable=!browse, pos={xx,yy-1}, size={100,20}, proc=ShowMinisButtons,title="Reversed"	
//	else
//		Button UseTimeReversed disable=!browse, pos={xx,yy-1},size={100,20},proc=ShowMinisButtons,title="Reject Reversed"
//		nvar /z/sdfr=chanDF timeRevThresh
//		if(!nvar_exists(timeRevThresh))
//			variable /g chanDF:timeRevThresh
//			nvar /z/sdfr=chanDF timeRevThresh
//		endif
//		xx+=110
//		SetVariable UseTimeRevThresh disable=!browse, pos={xx,yy+1},size={100,20},value=_NUM:0.01,limits={0,1,0.01},title="Threshold"
//	endif
//
//	xx=3; yy+=27
//	GroupBox SummaryBox, pos={xx,yy}, size={303,30}
//	xx+=5; yy+=5
//	Button Store disable=2*(!SQL_ || !browse),pos={xx,yy},proc=ShowMinisButtons, title="Review"
//	Button UpdateAnalysis disable=!browse,proc=ShowMinisButtons, title="Update"
//	Button SwitchView disable=0, proc=ShowMinisButtons, title=SelectString(StringMatch(mode,"All"),"All","Browse")
//	//Checkbox Scale disable=!all, proc=ShowMinisCheckboxes, title="Scale" // Scaling looks shitty.  Not advisable.  
//	Button Summary disable=!browse, proc=ShowMinisButtons,title="Summary"
//	controlinfo Summary
//	Button Average pos={v_left,v_top},disable=browse, proc=ShowMinisButtons,title="Average"
//	Button Options, proc=ShowMinisButtons, title="Options"
//	
//	xx+=310
//	GroupBox BrowseBox, pos={xx,yy-5}, size={273,30}
//	xx+=7
//	Button FirstMini disable=!browse,pos={xx,yy}, size={20,20},proc=ShowMinisButtons,title="<<"//,pos={375,27}
//	xx+=27
//	SetVariable CurrMini disable=!browse,pos={xx,yy+2}, size={80,20}, limits={0,num_minis-1,1}, proc=ShowMinisSetVariables, variable=currMini,title="Mini #"//,pos={405,30}
//	xx+=84
//	Button LastMini disable=!browse,pos={xx,yy},size={20,20},proc=ShowMinisButtons,title=">>"//,pos={495,27}
//	xx+=35
//	SetVariable SweepNum, pos={xx,yy+2}, size={80,20}, proc=ShowMinisSetVariables, title="Sweep"
//	xx+=70
//	SetVariable SweepMiniNum, pos={xx,yy+2}, size={40,20}, proc=ShowMinisSetVariables, title=""
//	
//	xx+=55
//	GroupBox RejectBox pos={xx,yy-5}, size={122,31}
//	xx+=6
//	Button Reject disable=0, pos={xx,yy}, proc=ShowMinisButtons, title="Reject:"
//	Button RejectBelow disable=!browse, size={20,20}, proc=ShowMinisButtons, title="<="
//	Button RejectAbove disable=!browse, size={20,20}, proc=ShowMinisButtons, title=">="
//	
//	ControlBar /T 69
//	strswitch(mode)
//		case "All":
//			Variable count=dimsize(MiniNames,0)
//			if(count>500)
//				DoAlert 1,"There are more than 500 minis to plot.  Are you sure you want to do this?"
//				if(V_flag==2)
//					SwitchMiniView("Browse")
//					return -1
//				endif
//			endif
//			all=1
//			RemoveTraces()
//			variable traceIndex=ItemsInList(TraceNameList("ShowMinisWin",";",1))
//			
//			dfref df=GetMinisOptionsDF(create=1)
//			variable scale=numvarordefault(joinpath({getdatafolder(1,df),"scale"}),0)
//			for(i=0;i<num_minis;i+=1)
//				AppendMini(MiniNames[Index[i]],channel,noFit=1,traceIndex=traceIndex,zero=1,scale=scale)
//				traceIndex+=1
//			endfor
//			SetVariable SweepNum, disable=1
//			SetVariable SweepMiniNum, disable=1
//			break
//		case "Browse":
//			browse=1
//			if(numtype(currMini))
//				currMini=0
//			endif
//			//RankMinis("RankByQuality") // Rank the minis by quality first. 
//			GoToMini(currMini) // Start with mini 0.
//			//Wave /T Mini_Names=$("root:Minis:"+channel+":Mini_Names") 
//			//mini_name=Mini_Names[currMini]
//			
//			string miniName=MiniNames[Index[currMini]]
//			
//			SetVariable SweepNum, disable=0
//			SetVariable SweepMiniNum, disable=0
//			break
//	endswitch
//	String text=SelectString(numpnts(MiniNames),"No minis on channel "+channel,"")
//	TextBox /W=ShowMinisWin/C/N=info text
//
//	Button SwitchView userData=mode
//	Label /Z/W=ShowMinisWin left, "pA"
//End
//
//Function ShowMinisButtons(ctrlName)
//	String ctrlName
//	
//	dfref df=GetMinisDF()
//	nvar /z/sdfr=df currMini
//	strswitch(ctrlName)
//		case "FitOneMini":
//			FitMinis(first=currMini,last=currMini)
//			break
//		case "FitLesser":
//			FitMinis(last=currMini)
//			break
//		case "FitGreater":
//			FitMinis(first=currMini)
//			break
//		case "FitAll":
//			//currMini=0
//			FitMinis()
//			break
//		case "UpdateAnalysis":
//			UpdateMiniAnalysis()
//			break
//		case "Template":
//			PickTemplate()
//			break
//		case "RankMinis":
//			ControlInfo RankChoices
//			RankMinis(S_Value)
//			break
//		case "Average":
//			AverageMinis()
//			break
//		case "Reject":
//			RejectMini()
//			break
//		case "RejectBelow":
//			RejectMinis("Below")
//			break
//		case "RejectAbove":
//			RejectMinis("Above")
//			break
//		case "Summary":
//			MiniSummary()
//			break
//		case "Store":
//			SQLStoreMinis()
//			break
////		case "StoreTimeReversed":
////			svar /sdfr=df channel=currChannel
////			dfref chanDF=GetMinisChannelDF(channel)
////			string reversedName=removeending(getdatafolder(1,chanDF),":")+"_reversed"
////			dfref reversedChanDF=$reversedName
////			if(datafolderrefstatus(reversedChanDF))
////				killdatafolder /z reversedChanDF
////			endif
////			duplicatedatafolder chanDF $reversedName 
////			break
//		case "FirstMini":
//			GoToMini(0)
//			break
//		case "LastMini":
//			svar /sdfr=df channel=currChannel
//			dfref chanDF=GetMinisChannelDF(channel)
//			GoToMini(NumMinis(channel)-1)
//			break
//		case "SwitchView":
//			String currView=GetUserData("","SwitchView","")
//			String mode=SelectString(StringMatch(currView,"Browse"),"Browse","All")
//			SwitchMiniView(mode)
//			break
//		case "Options":
//			DoWindow /K MiniOptions
//			NewPanel /K=1 /N=MiniOptions /W=(100,100,150,180)
//			AutoPositionWindow /M=1/R=ShowMinisWin
//			dfref df=GetMinisDF()
//			NewDataFolder /O df:Options
//			dfref optionsDF=df:Options
//			string options="Scale;Offset Fits;Zero"
//			variable i
//			for(i=0;i<ItemsInList(options);i+=1)
//				String option=StringFromList(i,options)
//				String option_=CleanupName(option,0)
//				Variable /G optionsDF:$option_
//				Checkbox $option_, pos={5,i*25+2}, variable=optionsDF:$option_, title=option, proc=ShowMinisCheckboxes
//			endfor
//	endswitch
//End
//
//Function ShowMinisCheckboxes(ctrlName,val)
//	String ctrlName
//	Variable val
//	
//	strswitch(ctrlName)
//		case "Scale":
//			DoWindow /F ShowMinisWin
//			SwitchMiniView("All")
//			break
//		case "Offset_Fits":
//			DoWindow /F ShowMinisWin
//			SwitchMiniView("Browse")
//			break
//		case "Zero":
//			DoWindow /F ShowMinisWin
//			SwitchMiniView("Browse")
//			break
//	endswitch
//End
//
//Function ShowMinisSetVariables(info)
//	Struct WMSetVariableAction &info
//	
//	if(!SVInput(info.eventCode))
//		return 0
//	endif
//	dfref df=GetMinisDF()
//	nvar /sdfr=df currMini
//	svar /sdfr=df channel=currChannel
//	dfref chanDF=GetMinisChannelDF(channel)
//	wave /t/sdfr=chanDF MiniNames
//	wave /sdfr=chanDF Use
//	strswitch(info.ctrlName)
//		case "CurrMini":
//			GoToMini(currMini)
//			break
//		case "SweepNum":
//		case "SweepMiniNum":
//			ControlInfo SweepNum; variable sweepNum=V_Value
//			ControlInfo SweepMiniNum; Variable sweepMiniNum=V_Value
//			variable lastSweepNum=str2num(GetUserData("","SweepNum",""))
//			variable lastSweepMiniNum=str2num(GetUserData("","SweepMiniNum",""))
//			strswitch(info.ctrlName)
//				case "SweepNum":
//					variable direction=sign(sweepNum-lastSweepNum)
//					break
//				case "SweepMiniNum":
//					direction=sign(sweepMiniNum-lastSweepMiniNum)
//					break
//			endswitch
//			svar /sdfr=df sweeps
//			if(sweepNum<MinList(sweeps) || sweepNum>MaxList(sweeps))
//				SetVariable SweepNum value=_NUM:lastSweepNum
//			endif
//			FindValue /TEXT="Sweep"+num2str(sweepNum)+"_Mini"+num2str(sweepMiniNum) /TXOP=4 MiniNames
//			variable num_minis=NumMinis(channel)
//			do	
//				if(!Use[V_Value] && currMini>=0 && currMini<num_minis)
//					v_value+=direction
//				else
//					break
//				endif
//			while(1)
//			currMini=limit(currMini,0,num_minis-1)
//			GoToMini(currMini)
//			break
//	endswitch
//End
//
//Function ShowMinisPopupMenus(info)
//	Struct WMPopupAction &info
//	
//	if(!SVInput(info.eventCode))
//		return 0
//	endif
//	dfref df=GetMinisDF()
//	nvar /sdfr=df currMini
//	svar /sdfr=df channel=currChannel
//	dfref chanDF=GetMinisChannelDF(channel)
//	strswitch(info.ctrlName)
//		case "Channel":
//			channel=info.popStr
//			string mode=GetUserData("ShowMinisWin","","mode")
//			SwitchMiniView(mode)
//			break
//		case "RankChoices":
//			RankMinis(info.popStr)
//			break
//		case "Direction":
//			string /g chanDF:direction=info.popStr
//			break
//	endswitch
//End
//
//Function PickTemplate()
//	String traces=TraceNameList("", ";", 3)
//	traces=ListMatch(traces,"Fit*")
//	if(ItemsInList(traces))
//		String trace=StringFromList(0,traces)
//		wave /z Template=TraceNameToWaveRef("",trace)
//		ControlInfo /W=ShowMinisWin Channel
//		String channel=S_Value
//		if(waveexists(Template))
//			dfref df=GetMinisChannelDF(channel)
//			Duplicate /o Template df:BC_Template
//		endif
//	endif
//End
//
//// Updates the values for mini amplitude and frequency in the Amplitude Analysis window to reflect Minis that have been removed in the Mini Browser.  
//Function UpdateMiniAnalysis()
//	ControlInfo /W=ShowMinisWin Channel
//	String channel=S_Value
//	if(!WinType("AnalysisWin"))
//		DisplayMiniRateAndAmpl(channel) // A simpler version of the same thing.  
//		return -1
//	endif
//	String methodStr="Minis"
//	//Variable num=1+WhichListItem(method_str,analysis_methods)
//	//PopupMenu Method mode=nu32m, win=Ampl_Analysis
//	//AnalysisMethodProc("Method",num,method_str)
//	
//	Variable i,j,k
//	String miniMethods=MethodList(methodStr) // Methods that are based on the Minis code.  
//	
//	dfref df=GetMinisDF()
//	svar /sdfr=df sweeps	
//	dfref df=GetMinisChannelDF(channel)
//	wave /t/sdfr=df MiniCounts
//	wave /sdfr=df Use
//	make /free/n=(dimsize(MiniCounts,0)) MiniSweepIndeks=str2num(MiniCounts[p][0])
//	for(j=0;j<=ItemsInList(sweeps);j+=1)
//		string sweep=StringFromList(j,sweeps)
//		variable sweepNum=str2num(sweep)
//		wave /z/sdfr=GetMinisSweepDF(channel,sweepNum) Locs,Vals,Index,Event_Size
//		if(waveexists(Locs))
//			variable net_duration=str2num(note(Locs))
//			for(i=0;i<numpnts(Vals);i+=1)
//				string mini_name=GetMiniName(sweepNum,i)
//				wave /t/sdfr=df MiniNames
//				FindValue /TEXT=mini_name /TXOP=4 MiniNames
//				if(V_Value>=0 && Use[v_value])
//					Vals[i]=Event_Size[V_Value]
//				else
//					Vals[i]=nan
//				endif
//			endfor
//			for(k=0;k<ItemsInList(miniMethods);k+=1)
//				string miniMethod=StringFromList(k,miniMethods)
//				MiniLocsAndValsToAnalysis(sweepNum,channel,Locs,Vals,duration=net_duration,miniMethod=miniMethod) // Creates its own MiniSweepIndex and kills it.  
//			endfor
//		endif
//	endfor
//End
//
//Function MiniSummary([channel])
//	string channel
//	
//	channel = selectstring(!paramisdefault(channel),GetMinisChannel(),channel)
//	dfref df=GetMinisChannelDF(channel)
//	wave /sdfr=df index
//	variable numMinis = numpnts(index)
//	make /o/n=(numMinis) Summary=nan
//	MoreMiniStats(channel)
//	variable i
//	string stats=miniRankStats+miniOtherStats
//	for(i=0;i<itemsinlist(stats);i+=1)
//		string name=stringfromlist(i,stats)
//		wave /z w=df:$cleanupname(name,0)
//		if(waveexists(w))
//			redimension /n=(-1,dimsize(Summary,1)+1) Summary
//			Summary[][i] = w[index[p]]
//			SetDimLabel 1,dimsize(Summary,1)-1,$name,Summary 
//			//appendtotable w
//		endif
//	endfor
//	DoWindow /K MiniSummaryWin
//	Edit /K=1 /N=MiniSummaryWin Summary.ld as "Mini Summary for channel "+channel
//End
//
//// Builds event times and inter-event intervals.  
//Function MoreMiniStats(channel[,proxy])
//	string channel
//	variable proxy
//	
//	proxy = paramisdefault(proxy) ? GetMinisProxyState() : proxy	
//	dfref df=GetMinisChannelDF(channel,proxy=proxy)
//	wave /t/sdfr=df MiniNames
//	wave /sdfr=df Use,Index
//	make /free/n=(numpnts(df:Event_Size)) TempIndex
//	wave /z sweepT=GetSweepT()
//	wave /sdfr=df baseline,event_size,amplitude,Event_Time,Interval,Rise_10_90=$cleanupname("Rise 10%-90%",0)
//	Event_Time=nan; Rise_10_90=nan
//	variable i,mini_num
//	
//	// Compute absolute event times, and 10%-90% rise times.  
//	for(i=0;i<numpnts(MiniNames);i+=1)
//		String name=MiniNames[i]
//		if(!Use[i])
//			continue
//		endif
//		variable sweepNum,miniNum
//		sscanf name,"Sweep%d_Mini%d",sweepNum,miniNum
//		dfref sweepDF=GetMinisSweepDF(channel,sweepNum,proxy=proxy)
//		
//		// Event Time.  
//		Wave /sdfr=sweepDF Locs,Vals,Index
//		FindValue /V=(miniNum) Index
//		Variable j=V_Value
//		if(WaveExists(sweepT))
//			Variable time_=sweepT[sweepNum]*60+Locs[j] // Time since experiments start.  
//			Event_Time[i]=time_
//		endif
//		
//		// Rise 10%-90%.  
//		wave /z/sdfr=sweepDF Fit=$("Fit_"+num2str(miniNum))
//		variable tenThresh=Baseline[i]+0.1*(Event_Size[i]*sign(Amplitude[i])
//		variable ninetyThresh=Baseline[i]+0.9*(Event_Size[i]*sign(Amplitude[i])
//		if(WaveExists(Fit))
//			FindLevel /Q Fit,tenThresh // Search from 5 ms before the peak until the peak. 
//			Variable ten=V_LevelX
//			FindLevel /Q/R=(ten,) Fit,ninetyThresh
//			Variable ninety=V_LevelX
//		else
//			wave sweep=GetChannelSweep(channel,sweepNum,proxy=proxy)
//			FindLevel /B=3/Q/R=(Locs[j]-0.005,Locs[j]+0.001) Sweep,tenThresh // Search from 5 ms before the peak until the peak. 
//			ten=V_LevelX
//			FindLevel /B=3/Q/R=(ten,Locs[j]+0.001) Sweep,ninetyThresh
//			ninety=V_LevelX
//		endif
//		Rise_10_90[i]=(ninety-ten)*1000 // Report in ms. 
//		//Rise_10_90[i]=numtype(Rise_10_90[i]) ? Inf : Rise_10_90[i]
//	endfor
//	
//	// Compute intervals.  
//if(0)
//	TempIndex=x
//	Sort Event_Time,Event_Time,TempIndex
//	Interval=Event_Time[p]-Event_Time[p-1]
//	Sort TempIndex,Event_Time,Interval
//	for(i=0;i<numpnts(MiniNames);i+=1)
//		name=MiniNames[i]
//		sscanf name,"Sweep%d_Mini%d",sweepNum,miniNum
//		Wave Index=root:Minis:$(channel):$("Sweep"+num2str(sweepNum)):Index
//		FindValue /V=(miniNum) Index
//		j=V_Value
//		if(j==0) // First mini of the sweep.  
//			Wave Sweep=root:$(channel):$("Sweep"+num2str(sweepNum))
//			variable lastSweepDuration=rightx(Sweep)
//			variable unrecordedDuration=60*(sweepT[sweepNum]-sweepT[sweepNum-1])-lastSweepDuration
//			Interval[i]+=unrecordedDuration
//		endif
//	endfor	
//	
//	KillWaves /Z TempIndex
//	//SetDataFolder $curr_folder
//else
//	duplicate /o Event_Time,Interval
//	//make /free/n=(numpnts(Interval)) TempInterval,TempIndex=p
//	extract /free/indx Interval,TempIndex,Use[p]==1
//	extract /free Interval,TempInterval,Use[p]==1
//	differentiate /meth=2 TempInterval
//	TempInterval[0]=nan
//	Interval=nan
//	for(i=0;i<numpnts(TempIndex);i+=1)
//		Interval[TempIndex[i]]=TempInterval[i]
//	endfor
//endif
//End
//
//function /s GetMinisChannel()
//	dfref df=GetMinisDF()
//	svar /sdfr=df currChannel
//	return currChannel
//end
//
//function SetMinisChannel(channel)
//	string channel
//	
//	dfref df=GetMinisDF()
//	string /g df:currChannel=channel
//end
//
//function GetCurrMini()
//	dfref df=GetMinisDF()
//	nvar /z/sdfr=df currMini
//	if(nvar_exists(currMini))
//		return currMini
//	else
//		variable /g df:currMini=0
//		return 0
//	endif
//end
//
//Function FitMinis([channel,first,last,proxy])
//	string channel
//	variable first,last // First and last mini to fit, by index.  
//	variable proxy
//	
//	DoWindow /F ShowMinisWin
//	variable i,error,num_errors=0
//	string mode=""
//	if(stringmatch(TopGraph(),"ShowMinisWin"))
//		mode=GetUserData("ShowMinisWin","SwitchView","")
//	endif
//	String trace,traces
//	if(paramisdefault(channel))
//		channel=GetMinisChannel()
//	endif
//	if(!paramisdefault(proxy))
//		SetMinisProxyState(proxy)
//	else
//		proxy=GetMinisProxyState()
//	endif
//	dfref df=GetMinisChannelDF(channel)
//	wave /t/sdfr=df MiniNames
//	wave /sdfr=df Index
//	first=paramisdefault(first) ? 0 : first
//	last=paramisdefault(last) ? NumMinis(channel)-1 : last
//	
//	//strswitch(mode)
//	//	case "All":
//	//		traces=TraceNameList("ShowMinisWin",";",3)
//	//		traces=RemoveFromList2("fit_*",traces) // Remove fits from the list of traces to fit.  
//	//		//make /free/n=(itemsinlist(traces)) MinisToFit=stringfromlist(p,traces)
//	//		break
//	//	case "Browse":
//			//duplicate /free/t/r= MiniNames MinisToFit
//			
//	//		break
//	//endswitch
//	
//	variable red,green,blue; GetChannelColor(channel,red,green,blue)
//	variable sweepNum,miniNum
//	dfref df=GetMinisDF()
//	variable /g df:paused=0
//	variable minisToFit=last-first+1
//	//nvar /sdfr=df currMini
//	string formattedChannel=selectstring(proxy,channel,channel+" ("+stringfromlist(proxy,proxies)+")")
//	for(i=first;i<=last;i+=1)
//		//string miniName=MiniNames[i]
//		//trace=StringFromList(i,traces)
//		if(StringMatch(mode,"Browse"))
//			GoToMini(i)
//		endif
//	
//		error=FitMini(i,channel=channel)//trace)
//		num_errors+=error
//		string msg
//		sprintf msg,"%s mini %s",formattedChannel,MiniNames[Index[i]]
//		Prog("Fitting Minis...",i-first,minisToFit,msg=msg)
//	endfor
//	if(first==last)
//		if(error)
//			printf "Fit error for this trace.\r"
//		endif
//	else
//		printf "%d errors out of %d traces.\r",num_errors,minisToFit//num_traces
//	endif
//End
//
//Function FitMinisPause(buttonNum, buttonName)
//	Variable buttonNum
//	String buttonName
//	dfref df=GetMinisDF()
//	nvar /sdfr=df paused
//	paused=!paused
//	if(!paused)
//		FitMinis()
//	endif
//End
//
//// Try adding /G so that the guesses from W_Coef are actually used.  
//Function FitMini(num[,channel])//trace)
//	variable num
//	string channel
//	
//	variable winIsTop=stringmatch(TopGraph(),"ShowMinisWin")
//	if(paramisdefault(channel))
//		if(winIsTop)
//			ControlInfo /W=ShowMinisWin Channel
//			channel=S_Value
//		else
//			channel=GetMinisChannel()
//		endif
//	endif
//	if(winIsTop)
//		GoToMini(num)
//	endif
//	variable sweepNum,miniNum
//	dfref df=GetMinisDF()
//	dfref chanDF=GetMinisChannelDF(channel)
//	variable currMini=GetCurrMini()
//	wave /t/sdfr=chanDF MiniNames
//	wave /sdfr=chanDF Index
//	variable index_=Index[num]
//	string mini_name=MiniNames[Index[num]]//currMini]
//	sscanf mini_name,"Sweep%d_Mini%d",sweepNum,miniNum
//	dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
//	variable proxy=GetMinisProxyState()//channel,sweepNum)
//	variable V_FitMaxIters=500,error,i
//	wave sweep=GetChannelSweep(channel,sweepNum,proxy=proxy)//TraceWave=TraceNameToWaveRef("",trace)
//	variable delta=dimdelta(sweep,0)
//	variable kHz=0.001/delta
//	//KillWaves $FitLocation(trace,win="ShowMinisWin")
//	wave /sdfr=sweepDF Locs,Vals
//	wave SweepIndex=sweepDF:Index
//	FindValue /V=(miniNum) SweepIndex
//	variable peak_loc=Locs[V_Value]
//	variable peak_val=Vals[V_Value]
//	nvar /sdfr=df fit_before,fit_after
//	variable offset_fits=NumVarOrDefault(joinpath({getdatafolder(1,df),"Options","offset_fits"}),0)
//	variable peak_point=x2pnt(Sweep,peak_loc)
//	variable first_point=peak_point-fit_before*kHz // This corresonds to, e.g., 5 ms before the peak.  
//	variable last_point=peak_point+fit_after*kHz // This corresponds to, e.g., 10 ms after the peak.  
//	variable bump=0
//	if(fit_before<=0)
//		bump=(fit_before/1000 - 0.005)
//		peak_loc-=bump
//	endif
//	svar /sdfr=chanDF direction
//	variable amplGuess=peak_val>0 ? 50 : -50
//	string amplInequality=SelectString(peak_val>0,"<0",">0")
//	make /o/t df:T_Constraints /wave=Constraints
//	string fit_name="Fit_"+num2str(miniNum)
//	if(winIsTop)
//		removeFromGraph /Z $fit_name
//	endif
//	make /o/n=(last_point-first_point+1) sweepDF:$fit_name /wave=Fit=0
//	setScale /I x,-fit_before/1000,fit_after/1000,Fit
//	peak_loc+=bump
//	DebuggerOptions
//	variable debugOn=v_debugOnError
//	DebuggerOptions debugOnError=0
//	if(last_point>=numpnts(Sweep))
//		variable V_FitError=7, V_FitQuitReason=4
//	else  
//		variable tries=0
//		do
//			v_fiterror=0; V_FitQuitReason=0
//			switch(tries)
//				case 0: // On the first try.  
//					string fitType="Synapse3"
//					variable v_fitoptions=4 // Minimize the squared error.  
//					break
//				case 1: // On the second try, if the first try fails.  
//					v_fitoptions=6 // Minimize the absolute error.  
//					break
//				case 2: 
//					fitType="Synapse"
//					break
//			endswitch
//			//if(proxy)
//			//	fitType+="_Reversed"
//			//endif
//			Make /o/D chanDF:W_coef /wave=Coefs
//			strswitch(fitType)
//				case "Synapse":
//				//case "Synapse_Reversed":
//					redimension /n=5 Coefs,Constraints
//					Constraints={"K0<=0.003","K1<=0.05","K2<"+num2str(peak_loc),"K4"+amplInequality} // Fit constraints for fit function 'Synapse'.  
//					Coefs={0.001,0.003,peak_loc-0.0025,Sweep[first_point],amplGuess} // Initial guesses for fitting coefficients for fit function 'Synapse'.  
//					break
//				case "Synapse3":
//					redimension /n=6 Coefs,Constraints
//					Constraints={"K0<=0.003","K1<=0.05","K2<"+num2str(peak_loc),"K4"+amplInequality,"K5>1"} // Fit constraints for fit function 'Synapse3.  
//					Coefs={0.002,0.003,peak_loc-0.0015,Sweep[first_point],amplGuess,2}
//					//Coefs= {0.0002,0.003,peak_loc,-29.126,-27.1913,2.06805}
//					break
//			endswitch
//			FuncFit /H="00000"/N/Q $fitType kwcWave=Coefs Sweep[first_point,last_point] /C=Constraints /D=Fit[0,last_point-first_point]
//			Variable err = GetRTError(0)
//			if (err != 0)
//				string errMessage=GetErrMessage(err)
//				printf "Error in Curvefit: %s\r", errMessage
//				err = GetRTError(1)						// Clear error state
//			endif
//			tries+=1
//		while(v_fiterror && tries<2)
//		if(winIsTop)
//			AppendToGraph /c=(0,0,0) Fit
//			ModifyGraph offset($fit_name)={,0+offset_fits*fitOffset}
//		endif
//	endif
//	DebuggerOptions debugOnError=debugOn
//	if(winIsTop)
//		ModifyGraph /W=ShowMinisWin rgb($TopTrace())=(0,0,0)
//	endif
//	// Fitting error:
//	duplicate /free Fit,Residual
//	Residual=Sweep[first_point+p]-Fit[p]
//	
//	if(V_FitError!=0)
//		printf "%s: Fit Error = %d; %d.\r",MiniNames[Index[num]],V_FitError,V_FitQuitReason
//		error=1
//	endif
//	string stats=miniFitCoefs+miniRankStats+miniOtherStats
//	if(index_<0)
//		for(i=0;i<itemsinlist(stats);i+=1)
//			string name=stringfromlist(i,stats)
//			wave w=chanDF:$cleanupname(name,0)
//			InsertPoints 0,1,w
//			index_=0
//		endfor
//	endif
//	for(i=0;i<ItemsInList(miniFitCoefs);i+=1)
//		name=stringFromList(i,miniFitCoefs)
//		wave w=chanDF:$cleanupname(name,0)
//		w[index_]=error ? nan : Coefs[i]
//		if(StringMatch(name,"*Time*"))
//			w[index_]*=1000 // Convert from seconds to milliseconds.  
//		endif
//	endfor
//	for(i=0;i<itemsinlist(stats);i+=1)
//		name=stringfromlist(i,stats)
//		wave w=chanDF:$cleanupname(name,0)
//		wave /z/sdfr=chanDF Event_Size=$cleanupname("Event Size",0)
//		strswitch(name)
//			case "Chi-Squared":
//				w[index_]=(v_fiterror || numtype(v_chisq)) ? Inf : V_chisq/numpnts(Fit)
//				break
//			case "Fit Time Before":
//				w[index_]=fit_before
//				break
//			case "Fit Time After":
//				w[index_]=fit_after
//				break
//			case "Score":
//				// Bekkers-Clements scoring
//				string BC_Template=joinpath({getdatafolder(1,chanDF),"BC_Template"})
//				variable BC_score=NaN
//				if(waveexists($BC_Template))
//					duplicate /o/R=[peak_point-100,peak_point+150] Sweep BC_Match
//					if(abs(1-(BC_Match[inf]/BC_Match[0]))<0.0001)
//						BC_Match[0]*=1.0001 // This is necessary to keep MatchTemplate /C from crashing.  
//					endif
//					execute /Q/Z "MatchTemplate /C "+BC_Template+", BC_Match"
//					wavestats /Q/M=1 BC_Match
//					killwaves /Z BC_Match
//					BC_score=V_max
//				endif
//				w[index_]=BC_score
//				break
//			case "Cumul Error":
//				duplicate /free Residual,CumulResidual
//				CumulResidual=Residual
//				Integrate /P CumulResidual
//				wavestats /q/m=1 CumulResidual
//				w[index_]=abs(V_max-V_min)/sqrt(last_point-first_point+1)
//				w[index_]=(numtype(w[index_])==2) ? Inf : w[index_]
//				break
//			case "Mean Error":
//				duplicate /free Residual,absResidual
//				absResidual=abs(Residual)
//				w[index_]=mean(absResidual)
//				//printf "Mean "+num2str(w[index_])
//				break
//			case "MSE":
//				w[index_]=norm(Residual)^2
//				//printf "Mean "+num2str(w[index_])
//				break
//			case "R2":
//				variable ssTot=variance(Sweep,peak_loc-fit_before/1000,peak_loc+fit_after/1000)
//				variable ssRed=variance(Residual)
//				w[index_]=max(0,1-ssRed/ssTot)
//				break
//			case "Log(1-R2)":
//				wave /sdfr=chanDF R2=$cleanupname("R2",0)
//				w[index_]=log(1-R2[index_])
//				break
//			case "Event Size":
//				wavestats /q/m=1 Fit
//				w[index_]=abs(V_max-V_min)
//				break
//			case "Plausability":
//				wave /sdfr=chanDF Cumul_Error=$cleanupname("Cumul Error",0),Mean_Error=$cleanupname("Mean Error",0),MSE=$cleanupname("MSE",0)
//				w[index_]=sqrt(Event_Size[index_])/MSE[index_]
//				w[index_]=(numtype(w[index_])==2) ? -Inf : w[index_]
//				break
//		endswitch
//	endfor
//	//endif
//	V_fitoptions=4
//	return error
//End
//
//// Remove the current mini from the graph and delete it, so it doesn't get included in the final analysis.  
//Function RejectMini()
//	dfref df=GetMinisDF()
//	nvar /z/sdfr=df currMini,traversal_direction
//	if(numtype(currMini))
//		return -1
//	endif
//	RemoveCurrMiniFromGraph()
//	KillMini(currMini)
//	svar /sdfr=df currChannel
//	variable proxy=GetMinisProxyState()
//	dfref df=GetMinisChannelDF(currChannel)
//	variable num_minis=NumMinis(currChannel)
//	if(NVar_exists(traversal_direction) && traversal_direction<0)
//		currMini=limit(currMini-1,0,num_minis-1)
//	else
//		currMini=limit(currMini,0,num_minis-1)
//	endif
//	string mode=getuserdata("","","mode")
//	if(stringmatch(mode,"browse"))	
//		GoToMini(currMini)
//	endif
//End
//
//// Remove the current mini from the graph
//Function RemoveCurrMiniFromGraph()
//	String ctrlName
//	String traces=TraceNameList("",";",3)
//	traces=RemoveFromList2("fit_*",traces)
//	string mode=getuserdata("","","mode")
//	dfref df=GetMinisDF()
//	strswitch(mode)
//		case "Browse":
//			string trace=StringFromList(0,traces)
//			break
//		case "All":
//			nvar /sdfr=df currMini
//			controlinfo /w=ShowMinisWin Channel; string channel=s_value
//			dfref chanDF=GetMinisChannelDF(channel)
//			wave /t/sdfr=chanDF miniNames
//			wave /sdfr=chanDF Index
//			trace=miniNames[Index[currMini]]
//			break
//	endswitch
//	RemoveFromGraph /Z $trace
//	RemoveFromGraph /Z $("fit_"+trace)
//End
//
//// Same as RejectMini, but for all minis less than the current index (Mini #).  
//Function RejectMinis(direction)
//	String direction
//	RemoveCurrMiniFromGraph()
//	dfref df=GetMinisDF()
//	nvar /sdfr=df currMini
//	Variable i
//	String trace,mini_name,fit_name
//	String curr_folder=GetDataFolder(1)
//	ControlInfo /W=ShowMinisWin Channel
//	String channel=S_Value
//	dfref df=GetMinisChannelDF(channel)
//	wave /t/sdfr=df MiniNames
//	strswitch(direction)
//		case "Below": 
//			for(i=currMini;i>=0;i-=1)
//				GoToMini(i)
//				KillMini(i)
//			endfor
//			currMini=0
//			break
//		case "Above":
//			for(i=currMini;i<numpnts(MiniNames);i+=0)
//				GoToMini(i)
//				if(KillMini(i))
//					break
//				endif
//			endfor
//			currMini=limit(currMini,0,NumMinis(channel)-1)
//			break
//	endswitch
//	
//	GoToMini(currMini)
//End
//
//Function KillMini(miniNum[,channel,proxy,preserve_loc])
//	variable miniNum,proxy
//	string channel
//	variable preserve_loc // Preserve a knowledge of its location (and amplitude) in the corresponding Sweep folder.  
//	
//	if(numtype(miniNum))
//		return -1
//	endif
//	if(ParamIsDefault(channel))
//		ControlInfo /W=ShowMinisWin Channel
//		channel=S_Value
//	endif
//	proxy = paramisdefault(proxy) ? GetMinisProxyState() : proxy
//	dfref df=GetMinisChannelDF(channel,proxy=proxy)
//	if(!datafolderrefstatus(df))
//		return -2
//	endif
//	wave /t/sdfr=df MiniNames
//	wave /sdfr=df Use,Index
//	if(miniNum<0 || miniNum>=numpnts(Index))
//		printf "miniNum = %d out of range; KillMini().\r",miniNum
//		return -3
//	endif
//	Use[Index[miniNum]]=0
//	deletepoints miniNum,1,Index
//	variable i
//	string stats=miniFitCoefs+miniRankStats+miniOtherStats
////	for(i=0;i<itemsinlist(stats);i+=1)
////		string name=stringfromlist(i,stats)
////		wave /z w=df:$cleanupname(name,0)
////		if(waveexists(w))
////			DeletePoints miniNum,1,w
////		endif
////	endfor
////	deletepoints miniNum,1,MiniNames
//	
//	// Fix the mini locations and value for the sweep in which this mini occurred.  
//	Variable sweepNum,sweepMiniNum // miniNum2 is the number of the mini for that sweep, as opposed to miniNum, which is the number of the mini overall.  
//	sscanf MiniNames[Index[miniNum]], "Sweep%d_Mini%d", sweepNum,sweepMiniNum
//	dfref sweepDF=GetMinisSweepDF(channel,sweepNum,proxy=proxy)
////	wave /sdfr=sweepDF Locs,Vals,Index
////	FindValue /V=(miniNum2) Index
////	if(v_value==-1)
////		printf "Could not find the value %d in %s; KillMini().\r",miniNum2,getwavesdatafolder(Index,2)
////	elseif(!preserve_loc)
////		DeletePoints v_value,1,Locs,Vals,Index
////	endif
//	string fit_name="Fit_"+num2str(sweepMiniNum)
//	KillWaves /Z sweepDF:$fit_name
//	
//	// Cleanup.  
//	Variable num_minis=numpnts(Index)
//	if(wintype("ShowMinisWin"))
//		SetVariable CurrMini limits={0,num_minis-1,1}, win=ShowMinisWin
//	endif
//End
//
//Function /S GoToMini(miniNum)
//	variable miniNum
//	
//	string traces=TraceNameList("ShowMinisWin",";",1)
//	traces=SortList(traces,";",16)
//	ControlInfo /W=ShowMinisWin Channel
//	string channel=S_Value
//	dfref chanDF=GetMinisChannelDF(channel)
//	if(!DataFolderRefStatus(chanDF))
//		return ""
//	endif
//	wave /t/sdfr=chanDF MiniNames
//	wave /sdfr=chanDF Index
//	String miniName=""
//	variable num_minis=NumMinis(channel)
//	miniNum=limit(miniNum,0,num_minis)
//	SetVariable currMini limits={0,num_minis,1}, win=ShowMinisWin
//	dfref optionsDF=GetMinisOptionsDF(create=1)
//	variable zero=NumVarOrDefault(joinpath({getdatafolder(1,optionsDF),"zero"}),0)
//	if(numpnts(Index)>0)
//		variable sweepNum,sweepMiniNum
//		miniName=MiniNames[Index[miniNum]]
//		sscanf miniName,"Sweep%d_Mini%d",sweepNum,sweepMiniNum
//		if(strlen(miniName))
//			AppendMini(miniName,channel,zero=zero) // Appends the mini and the fit, if it exists.  
//		endif
//	endif
//	dfref df=GetMinisDF()
//	nvar /z/sdfr=df currMini,last_mini
//	currMini=miniNum
//	if(nvar_exists(last_mini))
//		variable /g df:traversal_direction=currMini-last_mini
//	endif
//	variable /g df:last_mini=currMini
//	svar /sdfr=df sweeps
//	SetVariable SweepNum,value=_NUM:sweepNum, userData=num2str(sweepNum), limits={MinList(sweeps),MaxList(sweeps),1}, win=ShowMinisWin
//	wave /sdfr=GetMinisSweepDF(channel,sweepNum) Locs
//	SetVariable SweepMiniNum,value=_NUM:sweepMiniNum, userData=num2str(sweepMiniNum), limits={0,numpnts(Locs)-1,1}, win=ShowMinisWin
//	controlinfo /w=ShowMinisWin RankChoices
//	if(v_flag>0)
//		wave /z/sdfr=chanDF w=$cleanupname(s_value,0)
//		if(waveexists(w))
//			//string val=joinpath({getdatafolder(1,chanDF),nameofwave(w)})+"["+num2str(miniNum)+"]"
//			ValDisplay RankValue, value=_NUM:w[Index[miniNum]], format="%3.3f"
//			//SetVariable RankValue,value=_NUM:w[miniNum]
//		endif
//	endif
//	variable i=ItemsInList(traces)-1
//	do
//		string trace=StringFromList(i,traces)
//		if(strlen(trace))
//			RemoveFromGraph $trace
//		endif
//		i-=1
//	while(i>=0)
//	return miniName
//End
//
//Function AppendMini(mini_name,channel[,noFit,traceIndex,zero,scale])
//	String mini_name,channel
//	Variable noFit // Do not append the fit.  
//	Variable traceIndex // Index of the trace being appended.  
//	Variable zero // Zero the baseline.  
//	Variable scale // Scale so that the baseline to the peak spans 1 unit.  Also zeroes the baseline.  
//	
//	zero = scale ? 1 : zero // If we are scaling, zero regardless of whether the user has selected the 'zero' option.  
//	
//	Variable sweepNum,miniNum
//	sscanf mini_name, "Sweep%d_Mini%d", sweepNum,miniNum
//	dfref df=GetMinisSweepDF(channel,sweepNum)
//	wave /z/sdfr=df Fit=$("Fit_"+num2str(miniNum))
//	wave /sdfr=df Locs,Index
//	FindValue /V=(miniNum) Index
//	if(V_Value<0)
//		printf "Could not find the value %d in %s; AppendMini().\r",miniNum,getdatafolder(1,df)+"Index"
//	endif
//	Variable loc=Locs[V_Value]
//	//Variable loc=Locs[miniNum]
//	variable proxy=GetMinisProxyState()//channel,sweepNum)
//	Wave Sweep=GetChannelSweep(channel,sweepNum,proxy=proxy)
//	dfref df=GetMinisDF()
//	variable before=-0.015
//	variable after=0.030
//	Variable start=x2pnt(Sweep,loc+before)
//	Variable finish=x2pnt(Sweep,loc+after)
//	Variable red,green,blue; GetChannelColor(channel,red,green,blue)
//	if(zero)
//		WaveStats /M=1/Q/R=[start,start+100] Sweep
//		Variable baseline=V_avg
//	endif
//	if(scale)
//		WaveStats /M=1/Q/R=(loc-0.0005,loc+0.0005) Sweep // 1 second area centered at the peak.  
//		Variable peak=abs(V_avg-baseline)
//	else
//		peak=1
//	endif
//	AppendToGraph /c=(red,green,blue) Sweep[start,finish] /tn=$mini_name
//	setaxis bottom before,after
//	if(ParamIsDefault(traceIndex))
//		String top_trace=TopTrace()
//		ModifyGraph offset($top_trace)={-loc,-zero*baseline/peak}
//	else	
//		ModifyGraph offset[traceIndex]={-loc,-zero*baseline/peak}
//	endif
//	if(!noFit && waveexists(Fit))
//		AppendToGraph /c=(0,0,0) Fit /tn=$("Fit_"+mini_name)
//		top_trace=TopTrace()
//		Variable offset_fits=NumVarOrDefault(joinpath({getdatafolder(1,df),"Options","offset_fits"}),0)
//		ModifyGraph offset($top_trace)={,-zero*baseline/peak+offset_fits*fitOffset} // Why does the fit have an index of 3?  There are only two traces on the graph, the data and the fit.  
//	endif
//End
//
//function GetMinisProxyState()//channel,sweepNum)
//	//string channel
//	//variable sweepNum
//	variable result=0
//	dfref df=GetMinisDF()//SweepDF(channel,sweepNum)
//	nvar /z/sdfr=df proxy
//	if(nvar_exists(proxy) && proxy)
//		result=proxy
//	endif
//	return result
//end
//
//function SetMinisProxyState(state)
//	variable state
//	
//	dfref df=GetMinisDF()//SweepDF(channel,sweepNum)
//	variable /g df:proxy=state
//end
//
//Function RankMinis(rankKey[,channel,reversed])
//	string rankKey,channel
//	variable reversed
//	
//	channel=selectstring(!paramisdefault(channel),GetMinisChannel(),channel)
//	dfref df=GetMinisChannelDF(channel)
//	if(!DataFolderRefStatus(df))
//		return -1
//	endif
//	dfref minisDF=GetMinisDF()
//	nvar /z/sdfr=minisDF reverseSort
//	if(!nvar_exists(reverseSort))
//		variable /g minisDF:reverseSort=1
//		nvar /z/sdfr=minisDF reverseSort
//	endif
//	reverseSort=paramisdefault(reversed) ? !reverseSort : reversed
//	
//	wave rawKey=df:$cleanupname(rankKey,0)
//	wave /sdfr=df Index
//	make /free/n=(numpnts(Index)) key=rawKey[Index[p]]
//	if(reverseSort)
//		Sort /R key,Index
//	else
//		Sort key,Index
//	endif
//	if(wintype("ShowMinisWin"))
//		SetWindow ShowMinisWin userData(rank)=rankKey
//	endif
//	variable currMini=GetCurrMini()
//	if(stringmatch(TopGraph(),"ShowMinisWin"))
//		GoToMini(currMini) // Start with mini 0.
//	endif
//End
//
////// Returns a sorted, scaled distribution of values for fitting coefficient 'coef_num' across all fitted minis.  
////Function /S MiniCoefDistribution(coef_num)
////	Variable coef_num
////	// Make waves for each coefficient, so that the distribution of values for each coefficient can be analyzed.  
////	String coef
////	Duplicate /o/R=[][coef_num,coef_num] AllCoefs $(StringFromList(coef_num,miniFitCoefs))
////	Wave CoefWave=$(StringFromList(coef_num,miniFitCoefs))
////	Redimension /n=(numpnts(CoefWave)) CoefWave
////	Sort CoefWave,CoefWave
////	SetScale x,0,1,CoefWave
////	return GetWavesDataFolder(CoefWave,2)
////End
//
//// Assumed Minis have already been calculated and are stored in root:Minis.  
//Function RegionMinis([to_append])
//	Variable to_append
//	String top_graph=TopGraph()
//	DoWindow /F Ampl_Analysis
//	if(!strlen(CsrInfo(A)) || !strlen(CsrInfo(B)))
//		printf "Put cursors on region in Amplitude Analysis window first.\r"  
//		return 0
//	endif
//	String channel=GetWavesDataFolder(CsrWaveRef(A),0)
//	Variable sweepNum
//	dfref df=GetMinisDF()
//	if(!DataFolderExists(minisFolder))
//		printf "Must calculate Minis first using Recalculate() or CompleteMiniAnalysis().\r"
//		return -1
//	endif
//	dfref chanDF=GetMinisChannelDF(channel)
//	Variable first=xcsr(A)+1,last=xcsr(B)+1
//	String locs_name="Locs_"+num2str(first)+"_"+num2str(last)
//	String vals_name="Vals_"+num2str(first)+"_"+num2str(last)
//	String intervals_name="Intervals_"+num2str(first)+"_"+num2str(last)
//	String hist_vals_name="Hist_Vals_"+num2str(first)+"_"+num2str(last)
//	Make /o /n=0 chanDF:$locs_name /wave=All_Locs
//	Make /o /n=0 chanDF:$vals_name /wave=All_Vals
//	Variable cumul_time=0,duration
//	//Make /o /n=0 OtherTemp2
//	for(sweepNum=first;sweepNum<=last;sweepNum+=1)
//		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
//		wave /sdfr=sweepDF Locs,Vals
//		Duplicate /free Locs Mini_Locs_temp
//		Mini_Locs_temp+=cumul_time
//		//WaveTransform /O flip,Mini_Locs_temp
//		//OtherTemp=cumul_time
//		Concatenate /NP {Mini_Locs_temp}, All_Locs
//		Concatenate /NP {Vals}, All_Vals
//		//Concatenate /NP {OtherTemp}, OtherTemp2
//		wave Sweep=GetChannelSweep(channel,sweepNum)
//		duration=numpnts(Sweep)*deltax(Sweep)
//		cumul_time+=duration
//	endfor
//	
//	DoWindow /F $top_graph
//	if(!to_append || !WinExist("Mini_Ampls"))
//		Display /K=1 /N=Mini_Ampls
//	endif
//	if(!to_append || !WinExist("Mini_Intervals"))
//		Display /K=1 /N=Mini_Intervals
//	endif
//	
//	String mode="Time"
//	strswitch(mode)
//		case "Time":
//			Differentiate /METH=1 All_Locs /D=chanDF:$intervals_name; Wave All_Intervals=chanDF:$intervals_name
//			AppendToGraph /W=Mini_Intervals All_Intervals vs All_Locs
//			AppendToGraph /W=Mini_Ampls All_Vals vs All_Locs
//			ModifyGraph mode=3//,marker($locs_name)=8,marker($vals_name)=17
//			break
//		case "Cumul":	
//			Differentiate /METH=1 All_Locs /D=chanDF:$intervals_name; Wave All_Intervals=chanDF:$intervals_name
//			DeletePoints 0,1,All_Intervals
//			Sort All_Intervals,All_Intervals
//			Sort All_Vals,All_Vals
//			SetScale x,0,1, All_Intervals,All_Vals
//			AppendToGraph /W=Mini_Ampls /c=(65535,0,0) All_Vals
//			AppendToGraph /W=Mini_Intervals /c=(0,0,65535) All_Intervals
//			ModifyGraph /W=Mini_Ampls swapXY=1
//			ModifyGraph /W=Mini_Intervals swapXY=1
//			break
//		case "Hist":
//			Make /o/n=0 chanDF:$hist_vals_name; Wave Hist_Vals=chanDF:$hist_vals_name
//			Histogram /B={0,2.5,100} All_Vals,Hist_Vals
//			AppendToGraph /c=(65535,0,0) Hist_Vals
//			ModifyGraph mode=5
//			break
//	endswitch
//End
//
//Function ScaleMinis()
//	Variable i,x_scale,y_scale
//	String trace,traces=TraceNameList("",";",3)
//	String the_note,muloffset,intended_muloffset,trace_info
//	Variable scaleFlag=str2num(GetUserData("","Scale","scaled"))
//	if(!scaleFlag) // Not currently scaled.  Time to scale.  
//		for(i=0;i<ItemsInList(traces);i+=1)
//			trace=StringFromList(i,traces)
//			Wave TraceWave=TraceNameToWaveRef("",trace)
//			the_note=note(TraceWave)
//			trace_info=TraceInfo("",trace,0)
//			muloffset=StringByKey("muloffset(x)",trace_info,"=")
//			intended_muloffset=StringByKey("muloffset(x)",the_note,"=")
//			sscanf muloffset, "{%f,%f}", x_scale,y_scale
//			if(y_scale!=0) // Currently scaled.  Time to unscale. 
//				WaveStats /Q/R=(-0.015,0.005) TraceWave
//				ModifyGraph muloffset($trace)={0,0}
//			else
//				sscanf intended_muloffset, "{%f,%f}", x_scale,y_scale
//				ModifyGraph muloffset($trace)={0,y_scale}
//			endif
//		endfor		
//	endif
//End
//
//// Used for adding the locations and values of minis to mean/median values in the analysis window.  
//// Also for updating the variables used by the Mini Reviewer for rejecting bogus minis.  
//Function MiniLocsAndValsToAnalysis(sweepNum,channel,Locs,Vals[,duration,miniMethod])
//	Variable sweepNum
//	String channel
//	Wave /Z Locs,Vals
//	Variable duration
//	String miniMethod
//	
//	if(ParamIsDefault(duration))
//		Wave /Z SweepWave=GetChannelSweep(channel,sweepNum)
//		if(WaveExists(SweepWave))
//			duration=numpnts(SweepWave)*deltax(SweepWave)
//		endif
//	endif
//	if(ParamIsDefault(miniMethod))
//		miniMethod="Minis"
//	endif
//	
//	dfref df=GetMinisChannelDF(channel,create=1)
//	dfref dataDF=GetChannelDF(channel)
//	wave /z/sdfr=dataDF MinisAnalysisWave=$miniMethod
//	if(!WaveExists(MinisAnalysisWave))
//		wave /t/sdfr=df MiniCounts
//		variable maxSweep=str2num(MiniCounts[dimsize(MiniCounts,0)-1][0])
//		make /o/n=(maxSweep-1,2) dataDF:$miniMethod /WAVE=MinisAnalysisWave
//	endif
//	if(!WaveExists(Locs) || !WaveExists(Vals))
//		MinisAnalysisWave[sweepNum][]=NaN
//		return -1
//	endif
//	
//	Variable count=numpnts(Locs)
//	
//	if(numpnts(Vals))
//		WaveStats /Q/M=1 Vals
//		MinisAnalysisWave[sweepNum][0] = abs(V_avg) // Mean mini amplitude.  
//	else
//		MinisAnalysisWave[sweepNum][0] = NaN
//	endif
//	//ampl[sweep-1] = StatsMedian(Vals) // Median mini amplitude.  
//	MinisAnalysisWave[sweepNum][1] = count/duration // Mini frequency.  
//	Note /K Locs num2str(duration)
//	
//	//String /G root:Minis:sweeps=sweeps
//	variable currSweep=GetCurrSweep()
//	string sweeps=StrVarOrDefault(joinpath({minisFolder,"sweeps"}),"0,"+num2str(currSweep-1))
//	sweeps=ListExpand(sweeps)
//	wave /z/t/sdfr=df MiniCounts
//	if(!waveexists(MiniCounts))
//		Make /o/T/n=(ItemsInList(sweeps),3) df:MiniCounts=""
//		MiniCounts[][0]=StringFromList(p,sweeps)
//		MiniCounts[][1]=""
//		MiniCounts[][2]="Use"
//	endif
//	wave /t/sdfr=df MiniCounts
//	Make /free/n=(dimsize(MiniCounts,0)) MiniSweepIndex=str2num(MiniCounts[p][0])
//	FindValue /V=(sweepNum) MiniSweepIndex
//	if(V_Value>=0)
//		MiniCounts[V_Value][1]=num2str(count)
//	endif
//End
//
//Function DisplayMiniRateAndAmpl(channel)
//	String channel
//	
//	dfref df=GetMinisDF()
//	svar /sdfr=df sweeps
//	sweeps=ListExpand(sweeps)
//	df=GetMinisChannelDF(channel)
//	wave /t/sdfr=df MiniCounts
//	Variable i, numSweeps=dimsize(MiniCounts,0),totalDuration=0
//	make /free/n=0 AmplConcat
//	for(i=0;i<numSweeps;i+=1)
//		String sweepStr=MiniCounts[i][0]
//		Variable sweepNum=str2num(sweepStr)
//		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
//		if(DataFolderRefStatus(sweepDF) && StringMatch(MiniCounts[i][2],"Use"))
//			nvar /sdfr=sweepDF net_duration
//			wave /sdfr=sweepDF Locs,Vals
//			MiniLocsAndValsToAnalysis(sweepNum,channel,Locs,Vals,duration=net_duration)
//			Concatenate /NP {Vals},AmplConcat
//			totalDuration+=net_duration
//		else
//			MiniLocsAndValsToAnalysis(sweepNum,channel,$"",$"")
//		endif
//	endfor
//	WaveStats /Q AmplConcat
//	Display /K=1
//	AppendToGraph root:$(channel):Minis[][0]
//	ModifyGraph marker($TopTrace())=19
//	AppendToGraph root:$(channel):Minis[][1]
//	ModifyGraph marker($TopTrace())=8, mode=3
//	Label left "Mini Ampl / Rate"
//	Label bottom "Sweep Number"
//	printf "%d Minis at a rate of %f Hz with a mean amplitude of %f +/- %f pA.", V_npnts,V_npnts/totalDuration,V_avg,V_sdev/sqrt(V_npnts)
//End
//
//// Stores approved minis in the SQL database (uses the SQLBulkCommand method... faster but the code is more unreadable).   
//Function SQLStoreMinis()
//#ifdef SQL
//	String curr_folder=GetDataFolder(1)
//	SVar chan=root:Minis:currChannel
//	SetDataFolder root:Minis:$chan
//	Wave /T MiniNames
//
//	Make /o/n=(numpnts(MiniNames)) Segment,Sweep,Event_Num,Event_Time
//	
//	// Figure out the next available SegmentID.  
//	SQLConnekt("Reverb")
//	SQLc("SELECT SegmentID FROM Mini_Segments"); Wave SegmentID
//	Execute /Q "SQLDisconnect"
//	Variable id=FirstOpen(SegmentID,0)
//	
//	// Fill in the metadata for the minis.  
//	Segment=id
//	Variable i; Variable sweepNum,miniNum
//	for(i=0;i<numpnts(MiniNames);i+=1)
//		sscanf MiniNames[i],"Sweep%d_Mini%d",sweepNum,miniNum
//		Sweep[i]=sweepNum
//		Event_Num[i]=miniNum
//		Wave MiniLocs=$(":Sweep"+num2str(sweepNum)+":Locs")
//		Wave MiniIndex=$(":Sweep"+num2str(sweepNum)+":Index")
//		FindValue /V=(miniNum) MiniIndex
//		Event_Time[i]=MiniLocs[V_Value]
//	endfor
//	
//	// Create a table showing all the data for the minis.  
//	String column_names="Segment,Sweep,Event_Num,"
//	column_names+=replacestring(";",miniRankStats+miniOtherStats,",")
//	Variable num_columns=ItemsInList(column_names,",")
//	if(!WinExist("Mini_Review_Table"))
//		NewPanel /K=1 /N=Mini_Review /W=(100,100,1000,630)
//		Edit /HOST=Mini_Review /N=Mini_Table /W=(0.01,0.1,0.99,0.99)
//		for(i=0;i<ItemsInList(column_names,",");i+=1)
//			Wave Column=$StringFromList(i,column_names,",")
//			AppendToTable Column
//		endfor
//		Button Accept pos={0,0}, size={100,25}, proc=SQLInsertMinis,title="Add to Database"
//		ModifyTable /W=Mini_Review#Mini_Table width=50, sigDigits=3
//	endif
//	
//	// Prepare the entry for the SQL table Mini_Analysis.  
//	String /G root:Minis:sql_str,root:Minis:xop_str; SVar sql_str=::sql_str; SVar xop_str=::xop_str
//	sql_str="INSERT INTO Mini_Analysis ("+column_names+") "
//	sql_str+="VALUES ("+RepeatList(num_columns,"?",sep=",")+")"
//	xop_str=num2str(num_columns)+","+num2str(numpnts(MiniNames))+","+column_names
//	
//	// Prepare the entry for the SQL table Mini_Segments.  
//	String /G root:Minis:sql_str2; SVar sql_str2=::sql_str2
//	Variable first_sweep=xcsr(A,"Ampl_Analysis")+1
//	Variable last_sweep=xcsr(B,"Ampl_Analysis")+1
//	String used_sweeps=ListExpand(num2str(first_sweep)+","+num2str(last_sweep))
//	Variable rs=0,leak=0,duration=0
//	Wave RsWave=$("root:cell"+chan+":series_res")
//	Wave LeakWave=$("root:cell"+chan+":holding_i")
//	for(i=0;i<ItemsInList(used_sweeps);i+=1)
//		rs+=RsWave[str2num(StringFromList(i,used_sweeps))-1]
//		leak+=LeakWave[str2num(StringFromList(i,used_sweeps))-1]
//		Wave SweepWave=$("root:cell"+chan+":sweep"+StringFromList(i,used_sweeps))
//		duration+=(numpnts(SweepWave)*dimdelta(SweepWave,0))
//	endfor
//	Rs/=i; Leak/=i
//	String experimenter="RCG"
//	String file_name=IgorInfo(1)
//	NVar threshold=root:Minis:mini_thresh
//	sql_str2="INSERT INTO Mini_Segments (SegmentID,Experimenter,File_Name,Channel,First_Sweep,Last_Sweep,Duration,sweepNumbers,Threshold,Rs,Leak) VALUES "
//	sql_str2+="('"+num2str(id)+"','"+experimenter+"','"+file_name+"','"+chan+"','"+num2str(first_sweep)+"','"+num2str(last_sweep)+"','"
//	sql_str2+=num2str(duration)+"','"+used_sweeps+"','"+num2str(threshold)+"','"+num2str(Rs)+"','"+num2str(Leak)+"')"
//	
//	SetDataFolder $curr_folder
//#endif
//End
//
//Function SQLInsertMinis()
//#ifdef SQL
//	String ctrlName
//	SVar sql_str=root:Minis:sql_str; SVar xop_str=root:Minis:xop_str; SVar sql_str2=root:Minis:sql_str2
//	ControlInfo /W=ShowMinisWin Channel
//	String channel=S_Value
//	SetDataFolder root:Minis:$channel
//	Execute /Q "SQLConnect \"Reverb\",\"\",\"\""
//	SQLc(sql_str2)
//	SQLbc(sql_str,xop_str)
//	Execute /Q "SQLDisconnect"
//	DoWindow /K Mini_Review_Table
//	SetDataFolder ::
//#endif
//End
//
//// ----------------------- Totally optional functions that may or may not be useful. ---------------------------------------
//
//#ifdef Rick
//function CompareMinisToReversed(channel[,graph])
//	string channel
//	variable graph
//	
//	dfref forDF=GetMinisChannelDF(channel,proxy=0)
//	dfref revDF=$(removeending(getdatafolder(1,forDF),":")+"_reversed")
//	newdatafolder /o forDF:thresholds
//	dfref df=forDF:thresholds
//	
//	variable red,green,blue
//	GetChannelColor(channel,red,green,blue)
//	variable i,j
//	string miniRankStats_=miniRankStats+miniFitCoefs+miniOtherStats+"ultimate;"
//	for(i=0;i<itemsinlist(miniRankStats_);i+=1)
//		string stat=stringfromlist(i,miniRankStats_)
//		duplicate /o forDF:$cleanupname(stat,0) df:$("for_"+cleanupname(stat,0)) /wave=forward
//		duplicate /o revDF:$cleanupname(stat,0) df:$("rev_"+cleanupname(stat,0)) /wave=reversed
//		sort forward,forward
//		sort reversed,reversed
//		setscale x,0,1,forward,reversed
//		duplicate /free reversed,reversedNoNans
//		ecdf(reversedNoNans)
//		//if(numpnts(reversed)<alpha*numpnts(forward)) // Already less than alpha.  
//		variable points=1000
//		make /o/n=(points) df:$("thresh_"+cleanupname(stat,0)) /wave=threshold
//		setscale x,0,1,threshold
//		strswitch(stat)
//			case "Plausability":
//			case "MSE1":
//				variable increasing=1 // Increasing value is better.  
//				break
//			default:
//				increasing=0
//		endswitch
//		threshold=reversedNoNans(x)
//		threshold[0]=-Inf
//		threshold[numpnts(threshold)]={Inf}
//		points+=2
//		make /o/n=(points) df:$("sensitivity_"+cleanupname(stat,0)) /wave=sensitivity
//		make /o/n=(points) df:$("specificity_"+cleanupname(stat,0)) /wave=specificity
//		make /o/n=(points) df:$("fdr_"+cleanupname(stat,0)) /wave=fdr
//		for(j=0;j<points;j+=1)
//			if(increasing)
//				extract /free forward,forwardHits,forward>=threshold[j]
//				extract /free reversed,reversedHits,reversed>=threshold[j]
//			else
//				extract /free forward,forwardHits,forward<=threshold[j]
//				extract /free reversed,reversedHits,reversed<=threshold[j]
//			endif
//			specificity[j]=1-numpnts(reversedHits)/(numpnts(reversedHits)+numpnts(forward)-numpnts(forwardHits))
//			sensitivity[j]=numpnts(forwardHits)/(numpnts(forward))
//			fdr[j]=numpnts(reversedHits)/(numpnts(forwardHits)+numpnts(reversedHits))
//		endfor
//		printf "%s: %4.4f\r",stat,-log(1-areaXY(Specificity,Sensitivity))
//		string topWin=WinName(0,1)
//		if(graph)
//			display /k=1 as stat
//			//appendtograph /c=(0,0,0) reversed
//			appendtograph /c=(red,green,blue) sensitivity vs specificity
//			setaxis /R bottom 1,0.9; setaxis left 0.5,1
//			SetDrawEnv xcoord= bottom, dash=3;DelayUpdate
//			DrawLine 0.99,1,0.99,0
//			autopositionwindow /R=$topWin $winname(0,1)
//			doupdate
//		endif
//		//setaxis /R bottom 0,1
//		//appendtograph /c=(red,green,blue) specificity vs threshold
//		//appendtograph /c=(red,green,blue) sensitivity vs threshold 
//	endfor
//end
//
//function AllMiniStats(channel[,proxy,stats])
//	string channel
//	variable proxy
//	string stats
//	
//	stats = selectstring(!paramisdefault(stats),miniRankStats+miniFitCoefs,stats)
//	stats=removefromlist2("Score;pFalse;Event Time;Interval",stats)
//	dfref df=GetMinisChannelDF(channel,proxy=0)
//	dfref proxy_df=GetMinisChannelDF(channel,proxy=proxy)
//	wave /sdfr=df index
//	wave index_proxy=proxy_df:index
//	variable i
//	for(i=0;i<itemsinlist(stats);i+=1)
//		string stat=stringfromlist(i,stats)
//		wave /sdfr=df w=$cleanupname(stat,0)
//		wavestats /q w
//	 	if(v_npnts==0)
//	 		continue
//	 	endif
//	 	make /free/n=(numpnts(index)) score=w[index[p]]
//	 	
//		wave /sdfr=proxy_df w_proxy=$cleanupname(stat,0)
//	 	make /free/n=(numpnts(index_proxy)) score_proxy=w_proxy[index_proxy[p]]
//	 		
//	 	make /free/n=0 is_non_positive
//	 	concatenate {score,score_proxy},is_non_positive
//	 	is_non_positive = is_non_positive<=0
//	 	//if(sum(is_non_positive)==0) // If there are non-positives, then log-transform.  
//	 	//	score=ln(score)
//	 	//	score_proxy=ln(score_proxy)
//	 	//else
//	 		score=sign(score)*abs(score)^(1/3)
//	 		score_proxy=sign(score_proxy)*abs(score_proxy)^(1/3)
//	 	//endif
//	 	
//	 	// Center the data around the candidate median.  
//	 	wavestats /q score
//	 	statsquantiles /q score
//	 	variable center = v_median, normalize = v_iqr
//	 	
//	 	//if(i==0)
//	 	//	duplicate /o score,caca
//	 	//endif
//	 	score = (score[p]-center)/normalize
//	 	score_proxy = (score_proxy[p]-center)/normalize
//	 	
//	 	if(i==0)
//			make /o/n=(numpnts(index_proxy),itemsinlist(stats)) proxy_df:ultimate=nan
//		endif
//	 	wave /sdfr=proxy_df ultimate
//	 	ultimate[][i]=score_proxy[p]
//	 	SetDimLabel 1,i,$stat,ultimate 
//	endfor
//end
//
//function /wave LogIfPositive(w)
//	wave w
//	
//	duplicate /free w,non_positive,transformed
//	non_positive = w<=0
//	if(sum(non_positive)==0)
//		transformed = ln(w)
//	endif
//	return transformed
//end
//
//function MiniProbFalse(channel,proxy[,method,stats])
//	string channel
//	variable proxy
//	string method,stats
//	
//	if(proxy==0)
//		return 0
//	endif
//	method = selectstring(!paramisdefault(method),"PCA",method)
//	
//	//stats = selectstring(!paramisdefault(stats),"Log(1-R2);Rise 10%-90%;",stats)
//	stats = selectstring(!paramisdefault(stats),miniRankStats+miniFitCoefs,stats)
//	stats=removefromlist2("Score;pFalse;Event Time;Interval",stats)
//	variable num_stats=min(50,itemsinlist(stats))
//	
//	AllMiniStats(channel,proxy=0,stats=stats)
//	dfref df=GetMinisChannelDF(channel,proxy=0)
//	wave /sdfr=df ultimate,use,index
//	variable i,j,num_minis=dimsize(ultimate,0)
//	variable num_minis_original = dimsize(use,0)
//	
//	AllMiniStats(channel,proxy=proxy,stats=stats)
//	dfref df=GetMinisChannelDF(channel,proxy=proxy)
//	wave ultimate_proxy=df:ultimate
//	variable num_minis_proxy=dimsize(ultimate_proxy,0)
//	
//	make /o/n=(num_minis_original) df:pFalse /wave=pFalse=(Use[p] ? 0 : nan)
//	if(num_minis_proxy)
//		make /free/n=(0,num_stats) ultimate_combined
//		concatenate /np=0 {ultimate,ultimate_proxy},ultimate_combined
//		
//		//variable cols_=dimsize(ultimate_forward,1)
//		duplicate /o ultimate,df:lambdas /wave=lambdas
//		duplicate /o ultimate_proxy,df:lambdas_proxy /wave=lambdas_proxy
//		
//		strswitch(method)
//			case "ICA":
//				MatrixOp /free ultimate_combined_=subtractmean(subtractmean(ultimate_combined,2),1)
//				simpleICA(ultimate_combined_,num_stats,$"")
//				wave ICARes
//				lambdas=ICARes[p][q]
//				lambdas_proxy=ICARes[p+num_minis][q]
//				break
//			case "PCA":
//				matrixtranspose ultimate_combined
//				MatrixOp /free ultimate_combined_=subtractmean(ultimate_combined,2)
//				//MatrixOp /free ultimate_combined_=subtractmean(subtractmean(ultimate_combined,2),1)
//				PCA /LEIV /SCMT /SRMT /VAR ultimate_combined_
//				//wave M_R // Each column of this matrix is a principal component.  NormalizedData=M_R*M_C
//				wave M_C // Each row of this matrix is the coefficients for one principal component.
//				lambdas=M_C[q][p] // Lambdas for all tetrodes, with 'num_PCs' columns per tetrode.  
//				lambdas_proxy=M_C[q][p+num_minis] // Lambdas for all tetrodes, with 'num_PCs' columns per tetrode.  	
//				break
//			case "Raw":
//			default:
//				if(!stringmatch(method,"Raw"))
//					printf "Unknown method.  Using 'Raw'.\r"
//				endif
//				lambdas=ultimate_combined[p][q]
//				lambdas_proxy=ultimate_combined[p+num_minis][q]
//		endswitch
//		make /o/n=(0,num_stats) all_lambdas
//		concatenate /np=0 {lambdas,lambdas_proxy}, all_lambdas
//		variable max_rank=min(dimsize(all_lambdas,0)-1,dimsize(all_lambdas,1))
//		redimension /n=(-1,max_rank) all_lambdas // Ensure that there are more minis than stats.  
//		
//		variable prior=max(0.001,num_minis_proxy/num_minis)
//		make /free/n=(num_stats,2) maxes,mins,means,stdevs
//		make /free/n=(num_stats,2)/wave histograms
//		for(i=0;i<max_rank;i+=1) // Iterate over all principal components.  
//			for(j=0;j<2;j+=1)
//				if(j==0)
//					wave w=col(lambdas_proxy,i)
//					//duplicate /o w,lambdas_proxy_
//				else
//					wave w=col(lambdas,i)
//					//duplicate /o w,lambdas_
//				endif
//				wavestats /q w
//				maxes[i][j]=v_max
//				mins[i][j]=v_min
//				//statsquantiles /q w
//				//means[i][j]=v_median
//				//stdevs[i][j]=v_iqr/(2*statsinvnormalcdf(0.75,0,1))
//				variable bins = 100
//				make /free/d/n=(bins) hist
//				wave all=col(all_lambdas,i)
//				wavestats /q all
//				variable delta = (v_max-v_min)/bins
//				setscale x,v_min-delta,v_max+delta,hist
//				histogram /b=2/p w,hist
//				smooth /e=2 200,hist
//				duplicate /o hist $("hist_"+num2str(i)+selectstring(j,"_proxy",""))
//				histograms[i][j]=hist
//			endfor
//		endfor
//		
//		for(j=0;j<num_minis;j+=1) // Iterate over candidate minis.  
//			Prog("pFalse",j,num_minis)
//			variable prob=prior
//			for(i=0;i<max_rank;i+=1) // Iterate over all principal components.  
//				variable yy=lambdas[j][i]
//				
//				// Likelihood.  
//				wave hist_f=histograms[i][0]
//				
//				// Marginal.  
//				wave hist=histograms[i][1]
//				
//				prob*=hist_f(yy)/hist(yy)
//				if(numtype(prob))
//					duplicate /o hist_f,$"hist_f"
//					duplicate /o hist,$"hist"
//					print i,yy
//					abort
//				endif
//				prob=min(prob,1)
//			endfor
//			pFalse[index[j]]=min(prob,1)
//			//wave /sdfr=GetMinisChannelDF(channel,proxy=0) Log_1_R2_,Rise_10__90_
//		endfor
//		make /o/d/n=(100,100) df:pFalse2D /wave=pFalse2D=prior
//		setscale /i x,mins[0][1],maxes[0][1],pFalse2D
//		setscale /i y,mins[1][1],maxes[1][1],pFalse2D
//		for(i=0;i<max_rank;i+=1) // Iterate over all principal components.  
//			wave hist_f=histograms[i][0]
//			wave hist=histograms[i][1]
//			if(i==0)
//				pFalse2D *= hist_f(x)/hist(x)
//			elseif(i==1)
//				pFalse2D *= hist_f(y)/hist(y)
//			endif
//		endfor
//		//pFalse2D *= statsnormalpdf(x,means[0][0],stdevs[0][0])/statsnormalpdf(x,means[0][1],stdevs[0][1])
//		//pFalse2D *= statsnormalpdf(y,means[1][0],stdevs[1][0])/statsnormalpdf(y,means[1][1],stdevs[1][1])
//		pFalse2D = min(1,pFalse2D)
//	endif
//end
//
//function /wave MiniStatsGivenProxy(channel,proxy,fpr[,stats])
//	string channel,stats
//	variable proxy
//	variable fpr // False positive rate.  
//	
//	if(paramisdefault(stats))
//		stats="Event Size;Interval"
//	endif
//	dfref df=GetMinisChannelDF(channel,proxy=0)
//	wave /sdfr=df use
//	variable num_minis_raw=dimsize(use,0)
//	dfref proxyDF=GetMinisChannelDF(channel,proxy=proxy)
//	wave /sdfr=proxyDF use
//	variable num_minis_proxy_raw=dimsize(use,0)
//	if(num_minis_raw<3)
//		make /o/n=(num_minis_raw) proxyDF:pFalse=0
//	elseif(num_minis_proxy_raw<3)
//		make /o/n=(num_minis_raw) proxyDF:pFalse=0	
//	else
//		MiniProbFalse(channel,proxy)
//	endif
//	make /free/n=(itemsinlist(stats)) statsWave
//	wave /sdfr=df use
//	wave /sdfr=proxyDF pFalse
//	extract /free pFalse,pFalse_,use==1
//	if(numpnts(pFalse_))
//		sort pFalse_,pFalse_
//		setscale x,0,1,pFalse_
//		duplicate /free pFalse_ pFalse_cumul
//		integrate pFalse_cumul
//		findlevel /q pFalse_cumul,fpr
//		if(v_flag)
//			variable fractUse=1
//		else
//			fractUse=v_levelx
//		endif
//		variable pFalse_thresh = pFalse_(fractUse)
//		variable numUse=fractUse*numpnts(pFalse_)
//		//RankMinis("pFalse",channel=channel,reversed=0)
//		newdatafolder /o df:Stats
//		dfref statsDF=df:Stats
//		wave /sdfr=df Event_Size
//		variable i
//		string results=""
//		printf "%d/%d Minis Used.\r",numUse,numpnts(pFalse_)		
//		for(i=0;i<itemsinlist(stats);i+=1)
//			string stat=stringfromlist(i,stats)
//			setdimlabel 0,i,$stat,statsWave
//			wave w=df:$CleanupName(stat,0)
//			extract /free w,w_Used,use==1 && pFalse_<=pFalse_thresh && numtype(w)==0
//			printf "%s: %f\r",stat,statsmedian(w_Used)
//			statsWave[%$stat]=statsmedian(w_Used)
//		endfor
//	else
//		statsWave=nan
//	endif
//	return statsWave
//end
//
//function FormatMiniStats(proxy)
//	variable proxy // Set to 0 to use the median of all the proxies.  
//	
//	cd root:
//	string conditions="ctl;ttx"
//	wave /t/sdfr=root:db file_name,drug_incubated,channel,experimenter
//	wave /sdfr=root:db div,div_drug_added
//	make /o/n=0 Size,Interval,DIV_Added,DIV_Recorded,Days_In_Drug
//	make /o/t/n=0 Condition,File,Person
//	variable i,j,count=0
//	for(i=0;i<itemsinlist(conditions);i+=1)
//		string condition_=stringfromlist(i,conditions)
//		wave Stats=$("Stats_"+condition_)
//		for(j=0;j<dimsize(Stats,2);j+=1)
//			string file_channel=GetDimLabel(Stats,2,j)
//			string file_=removeending(file_channel,"_cellR1")
//			file_=removeending(file_,"_cellL2")
//			file_=removeending(file_,"_cellL2-1")
//			file_=removeending(file_,"_cellL2-2")
//			findvalue /text=file_ /txop=4 file_name
//			if(v_value<0)
//				printf "Could not find file %s in xf_filename.\r",file_
//				continue
//			endif
//			variable index=v_value
//			if(div_drug_added[index]>11)
//				continue
//			endif
//			File[count]={file_name[index]}
//			Person[count]={experimenter[index]}
//			if(!stringmatch(drug_incubated[index],condition_))
//				printf "Drug incubated doesn't match condition!\r"
//			endif
//			Condition[count]={drug_incubated[index]}
//			if(proxy)
//				Size[count]={Stats[0][proxy-1][j]}
//				Interval[count]={Stats[1][proxy-1][j]}
//			else
//				duplicate /free/r=[0,0][][j,j] Stats, temp
//				Size[count]={statsmedian(temp)}
//				duplicate /free/r=[1,1][][j,j] Stats, temp
//				Interval[count]={statsmedian(temp)}
//			endif
//			DIV_Recorded[count]={div[index]}
//			DIV_Added[count]={div_drug_added[index]}
//			Days_In_Drug[count]={div[index]-div_drug_added[index]}
//			count+=1
//		endfor
//	endfor
//end
//
//function MinisBatch(proxy,[fdr,stats,files,clean,search,analyze,messiness_thresh,save_,use_copy])
//	wave proxy
//	variable fdr,messiness_thresh,clean,search,analyze
//	variable save_ // Save a copy after processing.  
//	variable use_copy // Start with the processed copy, rather than the raw experiment file.  
//	string stats,files
//	
//	files=selectstring(!paramisdefault(files),"*",files)
//	messiness_thresh = paramisdefault(messiness_thresh) ? 20 : fdr
//	stats=selectstring(!paramisdefault(stats),"Event Size;Interval;",stats)
//	fdr = paramisdefault(fdr) ? 0.01 : fdr
//	//clean = paramisdefault(clean) ? 0 : clean
//	string suffix = selectstring(!paramisdefault(use_copy) && use_copy,"","_analyzed")
//	
//	ProgReset()
//	string db="reverb2"
//	newpath /o/q Desktop,SpecialDirPath("Desktop",0,0,0)
//	newpath /o/q XFMinisPath "E:GQB Projects:Xu Fang mEPSC Data"
//	newpath /o/q RCGMinisPath "E:GQB Projects:Reverberation:Data:2007"
//	
//	close /a 
//	variable i,j,k,ref_num
//	KillAll("windows")
//	newdatafolder /o/s root:DB
//	SQLc("SELECT A1.File_Name,A1.Experimenter,A1.Drug_Incubated,A1.DIV,A1.DIV_Drug_Added,A2.Channel,A2.Sweep_Numbers,A3.Baseline_Sweeps FROM ((Island_Record A1 INNER JOIN Mini_Segments A2 ON A1.File_Name=A2.File_Name) INNER JOIN Mini_Sweeps A3 ON A1.File_Name=A3.File_Name) WHERE A1.Experimenter",db=db)
//	wave /t File_Name,Drug_Incubated,Channel,Sweep_Numbers,Baseline_Sweeps,Experimenter
//	wave DIV,DIV_Drug_Added
//	setdatafolder root:
//	string curr_file=""
//	string curr_experimenter=""
//	variable sweepInfo,miniResults
//	Open /P=Desktop sweepInfo as "sweepInfo.txt"
//	Open /P=Desktop miniResults as "MinisResults.txt"
//	variable processed=0
//	for(i=0;i<numpnts(File_Name);i+=1)
//		string file=File_Name[i]
//		if(!stringmatch2(file,files))
//			continue
//		endif
//		prog("Cell",i,numpnts(File_Name),msg=file)
//		string channel_="cell"+stringfromlist(0,Channel[i],"-")
//		if(stringmatch(Experimenter[i],"RCG")) // If Rick did the experiment, check to see that the sweeps in question are baseline sweeps.  
//			string baseline_sweeps_=listexpand(Baseline_Sweeps[i])
//			string first_sweep=stringfromlist(0,Sweep_Numbers[i])
//			if(whichlistitem(first_sweep,baseline_sweeps_)>=0) // The sweeps to analyze are baseline sweeps.  
//				string sweeps = baseline_sweeps_
//				k=0
//				do // Start analysis with sweep10.  
//					sweeps = removefromlist(num2str(k),sweeps)
//					k+=1
//				while(minlist(sweeps)<=10)
//				if(itemsinlist(sweeps)<5)
//					printf "Only %d sweeps to analyze for channel %s of file %s.\r", itemsinlist(sweeps),channel_,file
//				endif	
//			else // They are not baseline sweeps.  
//				continue
//			endif
//		else
//			sweeps=Sweep_Numbers[i]
//		endif
//		if(!stringmatch(file,curr_file))
//			if(processed>0 && save_)
//				saveexperiment /c/p=$(curr_experimenter+"MinisPath") as curr_file+"_analyzed.pxp"
//			endif
//			cd root:
//			KillAll("windows",except="MiniStatsTable*")//;Messiness*")
//			KillRecurse("*",except="Packages;DB")
//			GetFileFolderInfo /Q/P=$(Experimenter[i]+"MinisPath")/Z=1 file+suffix+".pxp"
//			if(v_flag || !v_isfile)
//				printf "No such file: %s.\r",file
//				continue
//			endif
//			cd root:
//			printf "Loading data for %s.\r",file
//			fprintf sweepInfo, "%s\r", file
//			svar /z/sdfr=root: textProgStatus
//			LoadData /O/Q/R/P=$(Experimenter[i]+"MinisPath") file+suffix+".pxp"
//			ProgReset()
//			prog("Cell",i,numpnts(File_Name),msg=file)
//			if(clean)
//				BackwardsCompatibility(quiet=1,dontMove="XuFangStats*;DB",recompile=(i==0))
//				SuppressTestPulses()
//			endif
//		endif
//		dfref channelDF=GetChannelDF(channel_)
//		if(!datafolderrefstatus(channelDF))
//			printf "Channel %s not found.\r",channel_
//			continue
//		endif
//		sweeps=ListExpand(sweeps)
//		sweeps=AddConstantToList(sweeps,-1)
//		printf "Channel %s.\r",channel_
//		fprintf sweepInfo, "\tChannel %s\r", channel_
//		string good_sweeps=""
//		wave /z Messiness_=root:$(channel_):Messiness
//		if(!waveexists(Messiness_))
//			make /o/n=0 root:$(channel_):Messiness /wave=Messiness_
//		else
//		endif
//		for(j=0;j<itemsinlist(sweeps);j+=1)
//			variable sweep_num=str2num(stringfromlist(j,sweeps))
//			if(clean)
//				Prog("Messy?",j,itemsinlist(sweeps))
//				wave /z Sweep=GetChannelSweep(channel_,sweep_num)
//				if(waveexists(sweep))
//					variable messiness=SweepMessiness(Sweep)
//					Messiness_[sweep_num]={messiness}
//					fprintf sweepInfo, "\t\tSweep %d: Messiness = %.1f\r",sweep_num,messiness
//				endif
//			else
//				messiness=Messiness_[sweep_num]
//			endif
//			if(messiness<messiness_thresh)
//				good_sweeps+=num2str(sweep_num)+";"
//			else
//				printf "Sweep %d is too messy: %.1f\r",sweep_num,messiness
//			endif
//		endfor
//		if(clean)
//			Prog("Messy?",0,0)
//		endif
//		fprintf miniResults,"%s (%s)\r",file,channel_
//		if(search)		
//			MiniSearch(proxy,channel_,good_sweeps,miniResults)
//		endif
//		if(analyze)
//			wave statsMatrix=MiniStats(proxy,fdr,channel_,miniResults,stats=stats)
//			wave /z w=root:$("Stats_"+Drug_Incubated[i])
//			if(!waveexists(w))
//				duplicate /o statsMatrix root:$("Stats_"+Drug_Incubated[i]) /wave=w
//				dowindow /k $("MiniStatsTable_"+Drug_Incubated[i])
//				edit /n=$("MiniStatsTable_"+Drug_Incubated[i]) w.ld
//				variable index=0
//			else
//				index=dimsize(w,2)
//			endif
//			redimension /n=(-1,-1,index+1) w
//			w[][][index]=statsMatrix[p][q]
//			setdimlabel 2,index,$(file+"_"+channel_),w
//			save /o/p=Desktop w as "MiniResults_"+Drug_Incubated[i]+".ibw"
//		endif
//		curr_file=file
//		curr_experimenter=Experimenter[i]
//		processed+=1
//		//abort
//	endfor
//	if(save_)
//		saveexperiment /c/p=$(Experimenter[i]+"MinisPath") as curr_file+"_analyzed.pxp"
//	endif
//	close sweepInfo
//	close miniResults
//end
//
//function MiniSearch(proxy,channel,sweeps,miniResults)
//	wave proxy
//	string channel,sweeps
//	variable miniResults // A file reference.  
//	
//	SetMinisChannel(channel)
//	duplicate /free proxy,proxies
//	findvalue /V=0 proxy
//	if(v_value<0)
//		insertpoints 0,1,proxies
//		proxies[0]=0
//	endif
//	
//	variable i,j
//	for(i=0;i<numpnts(proxies);i+=1)
//		variable currProxy=proxies[i]
//		SetMinisProxyState(currProxy)
//		if(miniResults>=0)
//			fprintf miniResults, "\t[Proxy = %d]\r",currProxy
//		endif
//		CompleteMiniAnalysis(miniSearch=1,channels=channel,threshold=-5,sweeps=sweeps)
//		dfref df=GetMinisChannelDF(channel)
//		wave /t/sdfr=df MiniCounts
//		if(miniResults>=0)
//			for(j=0;j<dimsize(MiniCounts,0);j+=1)
//				fprintf miniResults, "\t\tSweep %d: %d minis\r",str2num(MiniCounts[j][0]),str2num(MiniCounts[j][1])
//			endfor
//		endif
//		InitMiniStats(channel)
//		FitMinis()
//		MoreMiniStats(channel)
//		KillFailedMinis(channel)
//	endfor
//	SetMinisProxyState(0)
//end
//
//function /wave MiniStats(proxy,fdr,channel,miniResults[,stats])
//	wave proxy
//	variable fdr
//	string channel,stats
//	variable miniResults // A file reference.  
//	
//	if(paramisdefault(stats))
//		stats="Event Size;Interval"
//	endif
//	
//	SetMinisChannel(channel)
//	
//	// Stats by which to automatically exclude certain minis from consideration.  
//	string kill_stats = miniRankStats+miniFitCoefs
//	kill_stats=removefromlist2("Score;pFalse;Event Time;Interval",kill_stats)
//	
//	variable i,j
//	for(i=0;i<numpnts(proxy);i+=1)
//		Prog("Proxy",i,numpnts(proxy),msg=num2str(proxy[i]))
//		wave proxyResults=MiniStatsGivenProxy(channel,proxy[i],fdr,stats=stats)
//		if(i==0)
//			duplicate /free proxyResults statsMatrix
//		endif
//		redimension /n=(-1,i+1) statsMatrix
//		setdimlabel 1,i,$num2str(proxy[i]),statsMatrix
//		statsMatrix[][i]=proxyResults[p] 
//		fprintf miniResults,"\t[Proxy %d]\r",proxy[i]
//		for(j=0;j<itemsinlist(stats);j+=1)
//			fprintf miniResults,"\t\t%s:%d\r",stringfromlist(j,stats),proxyResults[j]
//		endfor
//	endfor
//	fprintf miniResults,"\r"
//	return statsMatrix
//end
//
//function KillFailedMinis(channel[,proxy,stats])
//	string channel,stats
//	variable proxy
//
//	proxy = paramisdefault(proxy) ? GetMinisProxyState() : proxy
//	stats = selectstring(!paramisdefault(stats),miniRankStats+miniFitCoefs,stats)
//	stats=removefromlist2("Score;pFalse;Event Time;Interval",stats)
//	
//	dfref df=GetMinisChannelDF(channel,proxy=proxy)
//	wave /sdfr=df Index
//	variable j=0,k
//	if(numpnts(Index))
//		do
//			variable safe=1
//			for(k=0;k<itemsinlist(stats);k+=1)
//				string stat = stringfromlist(k,stats)
//				wave /sdfr=df w=$cleanupname(stat,0)
//				variable kill=0
//				strswitch(stat)
//					case "Event Size":
//						if(w[Index[j]]<5) // Kill any mini less than 5 pA in size.  
//							kill=1
//						endif
//						break
//				endswitch
//				if(numtype(w[Index[j]]))
//					kill=1
//				endif
//				if(kill)
//					KillMini(j,channel=channel,proxy=proxy)
//					safe = 0
//					break
//				endif
//			endfor
//			if(safe)
//				j+=1
//			endif
//		while(j<numpnts(Index))
//	endif
//end
//
//function SweepMessiness(w)
//	wave w
//	
//	duplicate /free/r=(0.3,) w,w_
//	resample /rate=100 w_
//	smooth /m=0 15,w_
//	wavestats /q w_
//	return v_sdev^2
//end
//
//function SuppressTestPulses()
//	variable i,j,currSweep=GetCurrSweep()
//	string channels=UsedChannels()
//	for(i=0;i<currSweep;i+=1)
//		Prog("Supressing test pulses...",i,currSweep,msg="Sweep "+num2str(i))
//		for(j=0;j<itemsinlist(channels);j+=1)
//			string channel=stringfromlist(j,channels)
//			SuppressTestPulse(channel,i)
//		endfor
//	endfor
//	Prog("Supressing test pulses...",0,0) // Hide this progress bar.  
//end
//
//function test124(channel)
//	string channel
//	
//	dfref fdf=GetMinisChannelDF(channel,proxy=0)
//	dfref rdf=GetMinisChannelDF(channel,proxy=1)
//	wave /sdfr=fdf fTime=Offset_Time
//	wave /sdfr=rdf rTime=Offset_Time
//	wave /t/sdfr=fdf fName=MiniNames
//	wave /t/sdfr=rdf rName=MiniNames
//	variable i,sweepNum,miniNum
//	
//	make /free/n=(numpnts(fTime)) fSweep
//	for(i=0;i<numpnts(fSweep);i+=1)
//		sscanf fName[i],"Sweep%d_Mini%d",sweepNum,miniNum
//		fSweep[i]=sweepNum
//	endfor
//	make /free/n=(numpnts(rTime)) rSweep
//	for(i=0;i<numpnts(rSweep);i+=1)
//		sscanf rName[i],"Sweep%d_Mini%d",sweepNum,miniNum
//		rSweep[i]=sweepNum
//	endfor
//	
//	make /free/n=(numpnts(fTime),numpnts(rTime)) test=fTime[p] - (30000-rTime[q])
//	test=(fSweep[p] == rSweep[q]) ? abs(test[p][q]) : Inf
//	make /o/n=(numpnts(rTime)) relTime_
//	for(i=0;i<numpnts(rTime);i+=1)
//		wave w=col(test,i)
//		relTime_[i]=wavemin(w)
//	endfor
//end
//
//function MiniPCA(channel)
//	string channel
//	
//	dfref df=GetMinisChannelDF(channel)
//	wave w=MakeMiniMatrix(channel)
//	matrixop /o w=subtractmean(subtractmean(w,1),2)
//	//matrixop /o w=normalizecols(w)
//	//matrixop /o w=normalizerows(w)
//	//matrixop /o w=normalizerows(subtractmean(w,1))
//	//matrixop /o w=normalizerows(subtractmean(subtractmean(w,1),2))
//	PCA /LEIV /SCMT /SRMT /VAR w
//	Wave M_R // Each column of this matrix is a principal component.  NormalizedData=M_R*M_C
//	Wave M_C // Each row of this matrix is the coefficients for one principal component.  
//	variable numMinis=dimsize(w,1)
//	variable numPoints=dimsize(w,0)
//	make /o/n=(numPoints,3) df:PCs=M_R[p][q]  
//	make /o/n=(numMinis,3) df:Lambdas=M_C[q][p]  
//	killwaves /z M_R,M_C
//end
//
//function /wave MakeMiniMatrix(channel)
//	string channel
//	
//	dfref df=GetMinisChannelDF(channel)
//	wave /t/sdfr=df MiniNames
//	wave /sdfr=df Index,Offset_Time
//	variable numMinis=numpnts(Index)
//	variable kHz=10
//	variable start=-7,finish=15 // In ms.  
//	make /o/n=(1,numMinis) MiniMatrix
//	variable i,sweepNum,miniNum
//	for(i=0;i<numMinis;i+=1)
//		sscanf MiniNames[Index[i]],"Sweep%d_Mini%d",sweepNum,miniNum
//		wave sweep=GetChannelSweep(channel,sweepNum)
//		dfref sweepDF=GetMinisSweepDF(channel,sweepNum)
//		wave /sdfr=sweepDF Locs
//		if(i==0)
//			variable numPoints=0.001*(finish-start)/dimdelta(sweep,0)
//			make /o/n=(numPoints,numMinis) df:MiniMatrix /wave=MiniMatrix
//			setscale /p x,0,dimdelta(sweep,0),MiniMatrix
//		endif
//		variable start_=(Locs[miniNum]+start/1000-dimoffset(sweep,0))/dimdelta(sweep,0)
//		MiniMatrix[][i]=sweep[start_+p]
//	endfor
//	return MiniMatrix
//end
//
//// Create inter-mini distributions for each of several size cutoffs.  
//Function MiniDistributions()
//	root()
//	Variable i,j;String folder
//	Wave /T FileName
//	String mins="6;8;10;15;20"; Variable minn
//	for(i=0;i<numpnts(FileName);i+=1)
//		folder="root:Cells:VC:"+FileName[i]+"_VC"
//		root()
//		if(DataFolderExists(folder))
//			SetDataFolder $folder
//			Wave /Z MiniLocs
//			if(waveexists(MiniLocs))
//				for(j=0;j<ItemsInList(mins);j+=1)
//					minn=NumFromList(j,mins)
//					Wave Ampls=:MiniAmpls	
//					Duplicate /o MiniLocs :MiniLocsTemp
//					Wave Locs=:MiniLocsTemp
//					Locs=(Ampls>minn) ? Ampls : NaN
//					Extract/O Locs,Locs,numtype(Locs) == 0
//					Duplicate/ o Locs :$("MiniIntervals_"+num2str(minn))
//					Wave Intervals=:$("MiniIntervals_"+num2str(minn))
//					Intervals=Locs[p]-Locs[p-1]
//					DeletePoints 0,1,Intervals
//					KillWaves /Z Locs
//				endfor
//			endif
//			//Wave U_Intervals,UpstateOn,UpstateOff
//			//U_Intervals=UpstateOn-UpstateOff[p-1]
//			//U_Intervals[0]=NaN
//		endif
//	endfor
//End
//
//#ifdef SQL
//// Collect mini statistics for each of the regions specified in the table Mini_Sweeps in the Reverberation database.  
//// Creates a folder hierarchy of cell:channel, and each wave has a point for each epoch, where epoch 0 is the baseline, 
//// epoch 1 is early in the post-activity baseline, epoch 2 is late in the post-activity baseline, and subsequent epochs are in
//// subsequent baseline periods.  
//Function CollectMiniStats()
//	root()
//	SQLConnekt("Reverb")
//	SQLc("SELECT A1.DIV,A1.Drug_Incubated,A2.* FROM Island_Record A1, Mini_Sweeps A2 WHERE A1.File_Name=A2.File_Name") 
//	// Get all the data from Mini_Sweeps and info about whether it was a TTX incubated or a control experiment.  
//	Wave /T File_Name,Baseline_Sweeps,Post_Activity_Sweeps,Intervening_Drugs,Drug_Incubated
//	Variable i,j,k
//	String channels="R1;L2"
//	
//	for(i=0;i<numpnts(File_Name);i+=1)
//		String file=File_Name[i]
//		String before=Baseline_Sweeps[i]
//		String after=StringFromList(0,Post_Activity_Sweeps[i]) // The sweep range of the baseline after the first region of activity.  
//		String after2=StringFromList(1,Post_Activity_Sweeps[i])  // The sweep range of the baseline after the second region of activity.  
//		if(strlen(after2)==0)
//			after2="9999999"
//		endif
//		NewDataFolder /O/S root:$file
//		for(j=0;j<ItemsInList(channels);j+=1)
//			String channel=StringFromList(j,channels)
//			NewDataFolder /O/S root:$(file):$channel
//			SQLc("SELECT * FROM Mini_Segments WHERE Channel='"+channel+"' AND File_Name='"+file+"'")
//			Make /o/n=5 MeanSize=NaN,MedianSize=NaN,Frequency=NaN
//			Wave MeanSize,MedianSize,Frequency
//			Wave First_Sweep,Last_Sweep,SegmentID,Duration,Rs
//			for(k=0;k<numpnts(SegmentID);k+=1)
//				variable id=SegmentID[k]
//				SQLc("SELECT * FROM Mini_Analysis WHERE Segment="+num2str(id)) // What about a maximum value for the decay time constant?  
//				wave Event_Size,Duration, Decay_Time
//				
//				Variable med_sweep=round((First_Sweep[k]+Last_Sweep[k])/2) // The median sweep of this segment.    
//				Variable before_after_cutoff=20 // Number of sweeps separating "early" (epoch 1) from "late" (epoch 2).  Won't matter much if segments in the database are far from this value.  
//				Variable first_sweep_after=NumFromList(0,ListExpand(after)) // The first sweep after the first region of activity.  
//				Variable first_sweep_after2=NumFromList(0,ListExpand(after2)) // The first sweep after the second region of activity.  
//				
//				if(InRegion(med_sweep,before))
//					Variable epoch=0 // Before activity.  
//				elseif(InRegion(med_sweep,after))
//					if(med_sweep<first_sweep_after+before_after_cutoff)
//						epoch=1 // 5-10 minutes after activity.  
//					else
//						epoch=2 // 25-30 minutes after activity.  
//					endif
//				elseif(InRegion(med_sweep,after2)) // In the region after the second baseline, i.e. after a second round of activity.  
//					if(med_sweep<first_sweep_after2+before_after_cutoff)
//						epoch=3 // 5-10 minutes after activity.  
//					else
//						epoch=4 // 25-30 minutes after activity.  
//					endif
//				else
//					epoch=-1
//					printf "Epoch could not be identified for id %d.\r",k
//				endif
//				if(epoch>=0)
//					Event_Size*=exp(0.005*Rs[k])/exp(0.005*25) // Normalize for access resistance.  
//					//Extract /O Event_Size,Event_Size,Decay_Time<10
//					//Extract /O Event_Size,Event_Size,Event_Size>5
//					WaveStats /Q Event_Size
//					MeanSize[epoch]=V_avg
//					MedianSize[epoch]=StatsMedian(Event_Size)
//					Frequency[epoch]=numpnts(Event_Size)/Duration
//				endif
//			endfor
//		endfor
//	endfor
//	root()
//	SQLDisconnekt()
//End
//
//// One data point for each experiment for each stat.  
//Function BaselineSummaryStats()
//	setdatafolder root:
//	newdatafolder /o/s sql
//	SQLConnekt("Reverb")
//	SQLc("SELECT A1.DIV,A1.DIV_Drug_Added,A1.Drug_Incubated,A2.* FROM Island_Record A1, Mini_Sweeps A2 WHERE A1.File_Name=A2.File_Name") 
//	// Get all the data from Mini_Sweeps and info about whether it was a TTX incubated or a control experiment.  
//	wave /t/sdfr=root:sql Experimenter,File_Name,Baseline_Sweeps,Post_Activity_Sweeps,Intervening_Drugs,Drug_Incubated
//	wave /sdfr=root:sql DIV,DIV_Drug_Added
//	setdatafolder root:
//	variable i,j,k,m
//	string channels="R1;L2"
//	string conditions="CTL;TTX"
//	
//	make /o/n=0 Amplitude,Amplitudes,Frequency,Count,Duration,Interval,Intervals,Threshold,DIV_Recorded,DIV_Added,Days_In_Drug
//	make /o/t/n=0 File,Person,Condition,Analysis
//	
//	make /free/n=(itemsinlist(conditions)) count=0
//	variable countt=0
//	for(i=0;i<numpnts(File_Name);i+=1)
//		prog("File",i,numpnts(File_Name))
//		string file_=File_Name[i]
//		string condition_=Drug_Incubated[i]
//		variable conditionNum=whichlistitem(condition_,conditions)
//		if(conditionNum<-1)
//			printf "Invalid condition: %s.\r",condition_
//		endif
//		string Sweeps=Baseline_Sweeps[i]
//		string FirstSweep=StringFromList(0,Baseline_Sweeps[i],",")
//		string LastSweep=StringFromList(1,Baseline_Sweeps[i],",")
//		if(!strlen(FirstSweep))
//			printf "No first sweep for file %s.\r",file_
//			continue
//		endif
//		//String after=StringFromList(0,Post_Activity_Sweeps[i]) // The sweep range of the  after the first region of activity.  
//		//String after2=StringFromList(1,Post_Activity_Sweeps[i])  // The sweep range of the  after the second region of activity.  
//		//if(strlen(after2)==0)
//		//	after2="9999999"
//		//endif
//		SQLc("SELECT Sweep as File_Sweep,Sweep_Dur FROM sweep_record WHERE File_Name='"+file_+"' AND Sweep>="+FirstSweep+" AND Sweep<="+LastSweep)
//		wave File_Sweep,Sweep_Dur
//		wavestats /Q/M=1 File_Sweep
//		make/o/n=(V_max+1) SweepDurations=NaN
//		for(j=0;j<numpnts(File_Sweep);j+=1)
//			SweepDurations[File_Sweep[j]]=Sweep_Dur[j]
//		endfor
//		newdatafolder /O/S root:$file_
//		variable CNQX=StringMatch(File_Name[i],"2008*")
//		for(j=0;j<ItemsInList(channels);j+=1)
//			Prog("Channel",j,itemsinlist(channels))
//			String channel=StringFromList(j,channels)
//			NewDataFolder /O/S root:$(file_):$channel
//			
//			// Pairwise Evoked Connectivity.  
//			SQLc("SELECT ConnectivityID FROM Connectivity WHERE File_Name='"+file_+"' AND Channel='"+channel+"'")
//			wave /z ConnectivityID
//			if(waveexists(ConnectivityID) && numpnts(ConnectivityID))
//				variable /g connID=ConnectivityID[0]
//				SQLc("SELECT Autapse_Value,Partner_1,Synapse_1,Partner_2,Synapse_2,Partner_3,Synapse_3 FROM Connectivity WHERE Phenotype<>'GABA' AND ConnectivityID="+num2str(connID)) 
//				make /o/n=0 Incoming,Outgoing
//				wave /z Autapse_Value
//				if(waveexists(Autapse_Value))
//					Incoming[0]={Autapse_Value[0]*(CNQX+1)}
//					Outgoing[0]={Autapse_Value[0]*(CNQX+1)}
//					for(k=1;k<=3;k+=1)
//						wave Partner=$("Partner_"+num2str(k))
//						wave Synapse=$("Synapse_"+num2str(k))
//						if(Partner[0]>0)
//							Outgoing[numpnts(Outgoing)]={Synapse[0]*(CNQX+1)}
//						endif
//					endfor
//				endif
//				for(k=1;k<=3;k+=1)
//					SQLc("SELECT Synapse_1,Synapse_2,Synapse_3 FROM Connectivity WHERE Phenotype<>'GABA' AND Partner_"+num2str(k)+"="+num2str(connID))
//					wave Synapse=$("Synapse_"+num2str(k))
//					for(m=0;m<numpnts(Synapse);m+=1)
//						Incoming[numpnts(Incoming)]={Synapse[m]*(CNQX+1)}
//					endfor
//				endfor 
//			endif	
//			
//			SQLc("SELECT * FROM Mini_Segments WHERE Channel='"+channel+"' AND File_Name='"+file_+"' AND First_Sweep>="+FirstSweep+" AND Last_Sweep<="+LastSweep)
//			wave /Z First_Sweep,Last_Sweep,SegmentID,Duration,Rs,Threshold
//			if(!waveexists(First_Sweep))
//				printf "No first sweep for file %s, channel %s.\r",file_,channel
//				continue
//			else
//				printf "OK: File %s, Channel %s.\r",file_,channel
//			endif
//			//wave /sdfr=df Amplitude,Amplitudes,Frequency,Count,Duration,Interval,Intervals,Threshold,DIV_Recorded,DIV_Added,Days_In_Drug
//			variable /g totalMinis=0, totalDuration=0, totalFreq=NaN
//			make /o/n=0 Sizes
//			for(k=0;k<numpnts(SegmentID);k+=1)
//				SQLc("SELECT * FROM Mini_Analysis WHERE Segment="+num2str(SegmentID[k]))
//				wave Event_Size,Event_Time,Sweep
//				Sweep*=30
//				Event_Time+=Sweep
//				sort Event_Time,Event_Time,Event_Size
//				differentiate /METH=1 Event_Time /D=$"Event_Interval"
//				wave Event_Interval=$"Event_Interval"
//				redimension /n=(numpnts(Event_Interval)-1) Event_Interval
//				//Extract /O Event_Time,Event_Time,Event_Time>0
//				concatenate /NP {Event_Interval}, Intervals // For the entire condition.  
//				concatenate /NP {Event_Size}, Amplitudes // For the entire condition.  
//				concatenate /NP {Event_Size}, Sizes // Just for this channel.  
//				totalMinis+=numpnts(Event_Size)
//				totalDuration+=Duration[k]
//			endfor
//			if(totalDuration>0)
//				totalFreq=totalMinis/totalDuration
//				wavestats /q/m=1 Event_Size
//				if(v_npnts != totalMinis)
//					printf "Number of minis not equal to number of points in Event_Size!\r"
//				endif
//				Amplitude[countt]={statsmedian(Event_Size)}
//				Count[countt]={totalMinis}
//				Duration[countt]={totalDuration}
//				Interval[countt]={statsmedian(Event_Interval)}
//				Frequency[countt]={totalMinis/totalDuration}
//				Threshold[countt]={Threshold[0]} // Assume only one segment.  
//				DIV_Recorded[countt]={DIV[i]}
//				DIV_Added[countt]={DIV_Drug_Added[i]}
//				Days_In_Drug[countt]={DIV[i]-DIV_Drug_Added[i]}
//				File[countt]={File_Name[i]}
//				Condition[countt]={condition_}
//				Person[countt]={Experimenter[i]}
//				Analysis[countt]={"0"} // Manual
//				count[conditionNum]+=1
//				countt+=1
//			endif
//			ECDF(Intervals)
//		endfor
//	endfor
//	root()
//	SQLDisconnekt()
//End
//
//Function ConnectivityStats()
//	SQLConnekt("Reverb")
//	root();
//	SQLc("SELECT File_Name,Channel,ConnectivityID,Autapse_Value,Partner_1,Synapse_1,Partner_2,Synapse_2,Partner_3,Synapse_3 From Connectivity")
//	//abort
//	wave ConnectivityID
//	wave /T File_Name,Channel,Phenotype
//	variable i,k,m
//	wavestats /q ConnectivityID
//	make /o/n=(v_max+1) meanIncoming=nan,meanOutgoing=nan
//	for(i=0;i<numpnts(ConnectivityID);i+=1)
//		if(mod(i,10)==0)
//			Prog("Connection",i,numpnts(ConnectivityID))
//		endif
//		if(stringmatch(Phenotype[i],"*GABA*"))
//			continue
//		endif
//		variable /g connID=ConnectivityID[i]
//		newdatafolder /o/s root:$File_Name[i]
//		newdatafolder /o/s $Channel[i]
//		make /o/n=0 Incoming,Outgoing
//		variable CNQX=StringMatch(File_Name[i],"*2008*")
//		wave /sdfr=root: Autapse_Value
//		Incoming[0]={Autapse_Value[i]*(CNQX+1)}
//		Outgoing[0]={Autapse_Value[i]*(CNQX+1)}
//		for(k=1;k<=3;k+=1)
//			wave Partner=root:$("Partner_"+num2str(k))
//			wave Synapse=root:$("Synapse_"+num2str(k))
//			if(Partner[i]>0)
//				Outgoing[numpnts(Outgoing)]={Synapse[i]*(CNQX+1)}
//			endif
//		endfor					
//		for(k=1;k<=3;k+=1)
//			SQLc("SELECT Synapse_1,Synapse_2,Synapse_3 FROM Connectivity WHERE Phenotype<>'GABA' AND Partner_"+num2str(k)+"="+num2str(connID))
//			wave Synapse=$("Synapse_"+num2str(k))
//			for(m=0;m<numpnts(Synapse);m+=1)
//				Incoming[numpnts(Incoming)]={Synapse[m]*(CNQX+1)}
//			endfor
//		endfor
//		extract /o Incoming,$"Incoming",Incoming>0
//		extract /o Outgoing,$"Outgoing",Outgoing>0
//		if(numpnts(Incoming)>1)
//			meanIncoming[connID]={mean(Incoming,1,numpnts(meanIncoming)-1)}
//		endif
//		if(numpnts(Outgoing)>1)
//			meanOutgoing[connID]={mean(Outgoing,1,numpnts(meanOutgoing)-1)}
//		endif
//	endfor
//	root()
//	meanIncoming=log(meanIncoming)//meanIncoming,numtype(meanIncoming)==0
//	meanOutgoing=log(meanOutgoing)//extract /o meanOutgoing,meanOutgoing,numtype(meanOutgoing)==0
//	SQLDisconnekt()
//End
//
//Function EvokedVsMinis()
//	root()
//	variable i,j,count=0
//	make /o EvokedVsMinisData
//	for(i=0;i<CountObjectsDFR(root:,4);i+=1)
//		string file_name=GetIndexedObjNameDFR(root:,4,i)
//		if(!stringmatch(file_name,"*200*"))
//			continue
//		endif
//		dfref df=root:$file_name
//		string channels="R1;L2"
//		for(j=0;j<itemsinlist(channels);j+=1)
//			string channel=stringfromlist(j,channels)
//			dfref df1=df:$channel
//			if(!datafolderrefstatus(df1))
//				continue
//			endif
//			wave /z/sdfr=df1 Sizes,Incoming,Outgoing
//			nvar /z/sdfr=df1 totalMinis,totalDuration,totalFreq
//			if(waveexists(Sizes) && (waveexists(Incoming) || waveexists(Outgoing)))
//				redimension /n=(count+1,4) EvokedVsMinisData
//				EvokedVsMinisData[count][0]=mean(Sizes)
//				EvokedVsMinisData[count][1]=totalFreq
//				EvokedVsMinisData[count][2]=mean(Incoming)
//				EvokedVsMinisData[count][3]=mean(Outgoing) 	
//				count+=1
//			endif
//		endfor
//	endfor
//End
//
//Function PlasticityVsReverberation(time_point,parameter)
//	String time_point,parameter
//	root()
//	SQLConnekt("Reverb")
//	String sql_cmd="SELECT A1.DIV,A3.Transition,A3.Reverberation,A1.Drug_Incubated,A2.* FROM Island_Record A1, Mini_Sweeps A2, Transitions A3 "
//	sql_cmd+="WHERE A1.File_Name=A2.File_Name AND A2.File_Name=A3.File_Name AND A1.File_Name=A3.File_Name"
//	SQLc(sql_cmd)
//	// Get all the data from Mini_Sweeps and info about whether it was a TTX incubated or a control experiment.  
//	Wave /T File_Name,Baseline_Sweeps,Post_Activity_Sweeps,Intervening_Drugs,Drug_Incubated
//	Wave Reverberation,Transition
//	Variable i,j,k
//	String channels="R1;L2"
//	String time_points="early;late"
//	String conditions="ctl;ttx"
//	if(StringMatch(time_point,"early"))
//		Variable tp=1
//	elseif(StringMatch(time_point,"late"))
//		tp=2
//	endif
//	SQLDisconnekt()
//	NewDataFolder /O/S root:$(time_point+"_"+parameter+"2")
//	Make /o/n=0 Reverb=NaN,Trans=NaN,Plasticity=NaN
//	Make /o/T/n=0 Source 
//	root()
//	Display /K=1 /N=$(time_point+"_"+parameter)
//	for(i=0;i<numpnts(File_Name);i+=1)
//		String file=File_Name[i]  
//		String condition=Drug_Incubated[i]
//		for(j=0;j<ItemsInList(channels);j+=1)
//			String channel=StringFromList(j,channels)
//			SetDataFolder root:$(file):$channel
//			Condition2Color(condition); NVar red,green,blue
//			InsertPoints 0,1,Reverb,Trans,Plasticity,Source
//			Source[0]=file+"_"+channel
//			Reverb[0]=Reverberation[i]
//			Trans[0]=Transition[i]
//			Wave Stat=$parameter
//			Duplicate /o Stat :Normed; Wave Normed
//			Normed/=Stat[0]
//			Plasticity[0]=Normed[tp]
//			KillVariables /Z red,green,blue
//		endfor
//	endfor
//	AppendToGraph /c=(65535,0,0) Plasticity vs Reverb
//	AppendToGraph /T=top_axis /c=(0,0,65535) Plasticity vs Trans
//	BigDots()
//	root()
//End
//
//Function PlotAllMiniPlasticity(time_point,parameter)
//	String time_point,parameter
//	root()
//	SQLConnekt("Reverb")
//	String sql_cmd="SELECT A1.DIV,A1.Drug_Incubated,A2.* FROM Island_Record A1, Mini_Sweeps A2, Transitions A3 WHERE A1.File_Name=A2.File_Name"
//	SQLc(sql_cmd)
//	// Get all the data from Mini_Sweeps and info about whether it was a TTX incubated or a control experiment.  
//	Wave /T File_Name,Baseline_Sweeps,Post_Activity_Sweeps,Intervening_Drugs,Drug_Incubated
//	Variable i,j,k
//	String channels="R1;L2"
//	String used_drugs=";None;AP5;MPEP,LY367385;Wortmannin;TNP-ATP;MPEP"
//	String time_points="early;late"
//	String conditions="ctl;ttx"
//	if(StringMatch(time_point,"early"))
//		Variable tp=1
//	elseif(StringMatch(time_point,"late"))
//		tp=2
//	endif
//	SQLDisconnekt()
//	NewDataFolder /O/S root:$(time_point+"_"+parameter)
//	Make /o/n=0 XAxis=NaN,YAxis=NaN
//	Make /o/T/n=0 Source 
//	Make /o/T/n=(ItemsInList(used_drugs)) XAxisLabels=StringFromList(p,used_drugs)
//	Make /o/n=(ItemsInList(used_drugs)) XAxisValues=p
//	Wave XAxis,YAxis,XAxisValues; Wave /T Source,XAxisLabels
//	root()
////	for(i=0;i<ItemsInList(used_drugs);i+=1)
////		String drug=CleanupName(StringFromList(i,used_drugs),0)
////		//Display /K=1/N=$("Sizes_"+drug)
////		//Display /K=1/N=$("Frequencies_"+drug)
////	endfor
////	
////	for(i=0;i<ItemsInList(time_points);i+=1)
////		String time_point=StringFromList(i,time_points)
////		for(j=0;j<ItemsInList(conditions);j+=1)
////			String condition=StringFromList(j,conditions)
////			Make /o/n=0 $(time_point+"_"+condition)
////			Make /o/T/n=0 $(time_point+"_"+condition+"_Labels")
////		endfor
////	endfor
//	
//	Display /K=1 /N=$(time_point+"_"+parameter)
//	for(i=0;i<numpnts(File_Name);i+=1)
//		String file=File_Name[i]
//		String drugs=Intervening_Drugs[i]
//		String drug1=StringFromList(0,drugs); // Drug list during the first period of activity.  
//		drug1=SelectString(StringMatch(drug1,"[Null]"),drug1,"None")
//		String drug2=StringFromList(1,drugs); // Drug list during the second period of activity (if there was one).
//		drug2=SelectString(StringMatch(drug1,"[Null]"),drug2,"None")  
//		String condition=Drug_Incubated[i]
//		// Identify which graph this case should be on (which of 'used_drugs' was present during the activity period.  
////		for(j=0;j<ItemsInList(used_drugs);j+=1)
////			drug=StringFromList(j,used_drugs)
////			if(WhichListItem(drug, drug1, ",")>=0)
////				break
////			else
////				drug=""
////			endif
////		endfor
//		
//		//if(StringMatch(drug,"AP5"))
//			//drug=CleanupName("",0) // Regardless of the drug, just append it to the graph corresponding to no drug.  
//			for(j=0;j<ItemsInList(channels);j+=1)
//				String channel=StringFromList(j,channels)
//				SetDataFolder root:$(file):$channel
//				//Wave MeanSize,MedianSize,Frequency
//				Condition2Color(condition); NVar red,green,blue
//				//AppendToGraph /c=(red,green,blue) MeanSize_norm
//				//Tag /F=0 $TopTrace(),1,"\Z07"+drug1
//				//Tag /F=0 $TopTrace(),3,"\Z07"+drug2
//				InsertPoints 0,1,XAxis,YAxis,Source
//				Variable item=WhichListItem(drug1,used_drugs)
//				if(item==6)
//					item=3
//				endif
//				if(StringMatch(condition,"CTL"))
//					item=0
//				endif
//				Source[0]=file+"_"+channel
//				XAxis[0]=item
//				Wave Stat=$parameter
//				Duplicate /o Stat :Normed; Wave Normed
//				Normed/=Stat[0]
//				YAxis[0]=Normed[tp]
//				if(item==1 && YAxis[0]>0.8)
//					//printf file,channel,Normed[2],"\r"
//				endif
//				//AppendToGraph /W=$("Sizes_"+drug) /c=(red,green,blue) MedianSize
//				//AppendToGraph /W=$("Frequencies_"+drug) /c=(red,green,blue) Frequency
//				KillVariables /Z red,green,blue
////				for(k=0;k<ItemsInList(time_points);k+=1)
////					time_point=StringFromList(k,time_points)
////					Wave TimePoint=root:$(time_point+"_"+condition)
////					Wave /T Labels=root:$(time_point+"_"+condition+"_Labels")
////					InsertPoints 0,1,TimePoint,Labels
////					TimePoint[0]=MedianSize[1+k]/MedianSize[0]//Frequency[1+k]/Frequency[0]
////					Labels[0]=file+"_"+channel
////				endfor
//				//if(numtype(Frequency[0])==0 && numtype(Frequency[1])==0)
//				//	z+=1
//				//endif
//			endfor
//		//endif
//	endfor
//	AppendToGraph YAxis vs XAxis
//	ModifyGraph userticks(bottom)={XAxisValues,XAxisLabels}
//	BigDots()
//	root()
//End
//
//// Computes the non-stationary mean and variance using the method in the Noceti paper on the traces in the top graph.  
//// Looks up info about the traces in MiniNames.  
//Function Noceti(channel)
//	String channel
//	//AverageMinis(channel,peak_scale=0)
//	String traces=TraceNameList("",";",3)
//	traces=RemoveFromList2("*_Matrix_Mean",traces)
//	String top_trace=StringFromList(0,traces)
//	Wave TopMini=TraceNameToWaveRef("",top_trace)
//	Variable points=numpnts(TopMini)
//	Wave /T MiniNames=$("root:Minis:"+channel+":MiniNames")
//	Wave Event_Size=$("root:Minis:"+channel+":Event_Size")
//	String curr_folder=GetDataFolder(1)
//	NewDataFolder /O/S $("root:Minis:"+channel+":Noceti")
//	Make /o/n=(ItemsInList(traces),points) NocetiMatrix
//	Make /o/n=(ItemsInList(traces)) TraceAmplitudes
//	Variable i
//	for(i=0;i<ItemsInList(traces);i+=1)
//		String mini_name=StringFromList(i,traces)
//		FindValue /TEXT=mini_name MiniNames; Variable index=V_Value
//		if(index>=0) // This should always be the case unless there are extra traces plotted on the graph.  
//			Wave Mini=$("root:Minis:"+channel+":Minis:"+mini_name)
//			TraceAmplitudes[i]=Event_Size[index]
//			NocetiMatrix[i][]=Mini[q]
//		endif
//	endfor
//	Make /o/n=(points) NocetiMean,NocetiVariance
//	for(i=0;i<points;i+=1)
//		Duplicate /o/R=[][i] NocetiMatrix $"NocetiColumn"; Wave NocetiColumn
//		Sort TraceAmplitudes,NocetiColumn
//		Differentiate /METH=1 NocetiColumn /D=NocetiDiff
//		NocetiDiff/=2
//		Redimension /n=(numpnts(NocetiDiff)-1) NocetiDiff
//		WaveStats /Q NocetiColumn
//		Variable meann=V_avg
//		NocetiMean[i]=meann
//		//NocetiDiff/=meann
//		WaveStats /Q NocetiDiff
//		NocetiVariance[i]=V_sdev^2
//	endfor
//	SetScale /P x,dimoffset(TopMini,0),dimdelta(TopMini,0),NocetiMean,NocetiVariance
//	Display /K=1 NocetiVariance[66,198] vs NocetiMean[66,198]
//	//Display /K=1 NocetiVariance vs NocetiMean
//	ModifyGraph mode=2, lsize=3
//	//Edit /K=1 NocetiMean,NocetiVariance
//	Wave NocetiMean,NocetiVariance
//	ModifyGraph rgb($TopTrace())=(0,0,0)
//	SetDataFolder $curr_folder
//	//Edit /K=1 NocetiMatrix
//End
//
//// Doesn't assume anything about where the traces came from.  
//Function NocetiTraces([TraceAmplitudes,left,right])
//	Wave TraceAmplitudes // A wave of amplitudes of the traces.  
//	Variable left // The left-most point to plot.  
//	Variable right // The right-most point to plot.  
//	String traces=TraceNameList("",";",3)
//	traces=RemoveFromList2("*_Matrix_Mean",traces)
//	String top_trace=StringFromList(0,traces)
//	Wave TopMini=TraceNameToWaveRef("",top_trace)
//	left=ParamIsDefault(left) ? leftx(TopMini) : left
//	right=ParamIsDefault(right) ? rightx(TopMini): right
//	Variable points=numpnts(TopMini)
//	String curr_folder=GetDataFolder(1)
//	NewDataFolder /O/S root:Noceti
//	Make /o/n=(ItemsInList(traces),points) NocetiMatrix
//	Variable i
//	if(ParamIsDefault(TraceAmplitudes))
//		Make /o/n=(ItemsInList(traces)) TraceAmplitudes
//		for(i=0;i<ItemsInList(traces);i+=1)
//			String trace_name=StringFromList(i,traces)
//			Wave TraceWave=TraceNameToWaveRef("",trace_name)
//			WaveStats /Q/M=1 TraceWave
//			TraceAmplitudes[i]=V_max//-V_min
//		endfor
//	endif
//	for(i=0;i<ItemsInList(traces);i+=1)
//		trace_name=StringFromList(i,traces)
//		Wave TraceWave=TraceNameToWaveRef("",trace_name)
//		NocetiMatrix[i][]=TraceWave[q]
//	endfor
//	Make /o/n=(points) NocetiMean,NocetiVariance
//	Duplicate /o/R=[][0] NocetiMatrix NocetiMasterColumn
//	for(i=0;i<points;i+=1)
//		Duplicate /o/R=[][i] NocetiMatrix $"NocetiColumn"; Wave NocetiColumn
//		Sort TraceAmplitudes,NocetiColumn
//		//Sort NocetiMasterColumn,NocetiColumn
//		//Sort NocetiColumn,NocetiColumn
//		Differentiate /METH=1 NocetiColumn /D=NocetiDiff
//		Redimension /n=(numpnts(NocetiDiff)-1) NocetiDiff
//		WaveStats /Q NocetiColumn
//		Variable meann=V_avg
//		NocetiMean[i]=meann
//		//NocetiDiff/=meann
//		WaveStats /Q NocetiDiff
//		NocetiVariance[i]=(V_sdev^2)/2
//	endfor
//	SetScale /P x,dimoffset(TopMini,0),dimdelta(TopMini,0),NocetiMean,NocetiVariance
//	Variable x1=x2pnt(TopMini,left)
//	Variable x2=x2pnt(TopMini,right)
//	Display /K=1 NocetiVariance[x1,x2] vs NocetiMean[x1,x2]
//	ModifyGraph mode=2, lsize=3
//	ModifyGraph rgb($TopTrace())=(0,0,0)
//	SetDataFolder $curr_folder
//	//Edit /K=1 NocetiMatrix
//End
//#endif




#endif
