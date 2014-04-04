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
	variable threshold = -240
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
	"AverageTrace!T/1", AverageTrace()
	"Graph firing rate!T/2", GraphRate()
	"AppendWholeGraph!T/3", AppendWholeGraph()
	"Cell attached FR!T/4", AttachedFR()
	"SpikeShapeAnalysis!T/5", SpikeShapeAnalysis()
	"IF Plot!T/6", IFPlot1()
	"Ih!T/7", IhAnalysis(0)
	"TestPulse!T/8", TestPulseAnalysis(0)
	"AverageSweepsWindow!T/9", AverageWavesOnGraph()
End

Function WilcoxStat()
    wave group1
    wave group2
    wave  W_WilcoxonTest
   
    statswilcoxonranktest/q/T=0/tail = 4 group1, group2
   
    print "p = ", W_wilcoxontest[5]
   
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

Function AverageWavesOnGraph([win_name])
	string win_name
	variable i,j
	string FinalAvgWaveName, basename
	prompt baseName, "baseName"
	doprompt "Select basename", baseName

//These lines magically get the waves you want off the SweepsWin window
	win_name=selectstring(paramisdefault(win_name),win_name,winname(0,1))
	string traces = TraceNameList(win_name, ";", 1)
	string firsttrace =  stringfromlist(0,traces)
	
	for(i=0; i<itemsinList(traces); i+=1)
		string trace = StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef(win_name,trace)
		
		if(i==0)
			duplicate/o tracewave NewAvgwave
			j+=1
			display tracewave
			else
			NewAvgWave+=TraceWave
			j+=1
			appendtograph tracewave
			endif
		
	endfor

duplicate/o NewAvgWave FinalAvgWave
FinalAvgWave/=j

sprintf FinalAvgWaveName, "%s%s", "AvgTrace_", baseName
		duplicate/o FinalAvgWave $FinalAvgWaveName

appendtograph $FinalAvgWaveName
ModifyGraph lsize($FinalAvgWaveName)=2,rgb($FinalAvgWaveName)=(0,0,0)
display $FinalAvgWaveName


End


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Function SynapticAnalysis([win_name])
	string win_name
	variable deltaOne, SampleRate
	variable fit, W_coef0, W_coef1, W_coef2, W_fitconstant,x
	variable i, v_flag
	variable baseline, ipsc, taudecay,  IPSC1Amp, IPSC1AmpTime
	variable IPSCAmpAverage, IPSCdecayAverage
	variable taudecayAvg
	string baseName
	string AvgDecay, AvgAmp
	string AvgDecayStr, AvgAmpStr
	string ipscAmpName, ipscDecayName
	string ipscStatsWaveName, ipscStatsName
	wave w_coef
	prompt baseName, "baseName"
	doprompt "", baseName
	
	//make sure function cancels
	if(V_flag)
		abort
	endif
	
	//waves for individual traces
	make/o/n=0 ipscAmp
	make/o/n=0 ipscdecay
		
	//These lines magically get the waves you want off the SweepsWin window
	win_name=selectstring(paramisdefault(win_name),win_name,winname(0,1))
	string traces = TraceNameList(win_name, ";", 1)
	string firsttrace =  stringfromlist(0,traces)
	
	for(i=0; i<itemsinList(traces); i+=1)
		string trace = StringFromList(i,traces)
		Wave TraceWave=TraceNameToWaveRef(win_name,trace)			
		//Amplitude
		Wavestats/q/r=(0.47, 0.49) TraceWave
			baseline = v_avg
		Wavestats/q/r=(0.5, 0.54) TraceWave
			IPSC1Amp = v_min; IPSC1Amp-=baseline	
			IPSC1AmpTime = v_minLoc
		redimension/n=(numpnts(ipscAmp)+1) ipscAmp
		ipscAmp[i] = ipsc1Amp 
		
		//tau decay
		CurveFit/q exp_XOffset  TraceWave(IPSC1AmpTime,0.54) /D 
		taudecay = W_coef[2]*1000
		redimension/n=(numpnts(ipscdecay)+1) ipscdecay
		ipscdecay[i] = taudecay

		endfor
	
	edit ipscamp, ipscdecay

	wave/t ipscstats
	if (waveexists(ipscstats)==0)
		make/t/o/n=4 IPSCstats; IPSCstats[0] = "IPSC amp"; IPSCstats[1] = "IPSC sdev"; IPSCstats[2] = "dev/avg"; IPSCstats[3] = "decay"; 
		edit ipscstats
		dowindow/c PSCStatsResults
	endif
	
	dowindow/f pscstatsresults
	if (v_flag==0)
		edit ipscstats
		dowindow/c pscstatsresults
	endif
	
	make/o/n=4 statsWave
		wavestats/q IPSCAmp
			statsWave[0] = (v_avg)*-1
			statsWave[1] = v_sdev
			statsWave[2] = (statsWave[1] / statsWave[0])
		wavestats/q ipscDecay	
			statsWave[3] = v_avg

	sprintf IPSCstatsName, "%s%s_", "IPSCstats", baseName
		duplicate/o statsWave $IPSCstatsName	
	
	dowindow/f PSCStatsResults
	appendtotable $ipscstatsName

	
	End




#endif




#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function SaveMiniWaves([win_name])	
	string win_name
	variable i
	string PathName = ""
	string Path1
	prompt PathName, "Path to folder"
	doprompt "", pathName
	
	if (strlen(pathName)==0)
		newPath/o Path1
		else
		newPath/o Path1, PathName
	endif
	
	
		//These lines magically get the waves you want off the SweepsWin window
		win_name=selectstring(paramisdefault(win_name),win_name,winname(0,1))
		string traces = TraceNameList(win_name, ";", 1)
		
		for(i=0; i<itemsinList(traces); i+=1)
			string trace = StringFromList(i,traces)
			Wave TraceWave=TraceNameToWaveRef(win_name,trace)
			save/i/p=Path1 TraceWave
		endfor


		

End

Function LoadMinis()
	string PathName
	string FileName
	variable FileIndex
	prompt pathName, "PathName"
	doprompt "", pathName
	 
	//If no path was specified, prompt for one
	if(strlen(pathName)==0)
		newPath/o tempPath
		pathName= "tempPath"
	endif
	
	do
		fileName = IndexedFile($PathName, fileIndex, ".ibw")
			//  break out of loop when there are no more fileNames
			if (strlen(fileName) == 0)
				//print fileName
				break
			endif	
			
		LoadWave/q/o/P=$pathName FileName
		
	FileIndex+=1
	While (1)
	
End
	
	
///Mini analysis program from Robyn 12-1-09
Function miniwavesAG(first,last)
    variable first, last
    variable j
    variable i=first
    string tempwave, newwave
    variable fillin
    variable baselineValue
    
    do
        tempWave = "sweep"+num2str(i)
      //make new wave so original isn't overwritten.  Will eventually be called "y"+i
        duplicate/o $tempWave wv1
     //replace stimulus artifact
     	fillin = wv1[79]
     	 wv1[79,1209] = fillin
     	 //get baseline for subtraction
   //  	 wavestats /q/r=(1,2) wv1//was this
   	wavestats/q/r=(1,5) wv1	//Aryn changed 7-31-10
     	baselineValue = v_avg

    //    j=500
   //     do   
            wv1-= baselineValue
            ///////Just for NOW//////////
  //          wv1*=-1
            /////////////////////////
            
//           print tempWave
//            print baselineValue
            j = j+1
    //    while(j<=50000)       
        sprintf newwave, "%s%g", "y",i
        duplicate/o wv1 $newwave
        i = i+1
    while(i<=last)
End
	
