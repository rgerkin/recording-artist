// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Coherence.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.


///// Initalizes random X and Y coordinates on the interval [0,1]
Function MakeRandomVectors(numpts)
Variable numpts
SetDataFolder root:CoherenceGlobals
Make/O/N=(numpts) x_wave,y_wave

x_wave[0,*]=enoise(.5)+.5
y_wave[0,*]=enoise(.5)+.5

Duplicate/O x_wave NewXwave,newYWave

End

///// Determines which subset of the X,Y coordinates will
///// be travel in the same direction (all others will be 
///// randomly oriented. "NewCorr" specifies
///// whether this set is maintained as is, or a new set is 
///// chosen - this fxn is called by a hook controlled by
///// the "Coherence" slider bar.  
Function SelectCorrelatedPoints(coherence,NewCorr)
Variable coherence
Variable NewCorr
Wave x_wave = root:CoherenceGlobals:x_wave
Wave CorrPtsWave = root:CoherenceGlobals:CorrPtsWave

If(NewCorr>0)	
	Duplicate/O x_wave CorrPtsWave;CorrPtsWave=0
	CorrPtsWave =(coherence>=(enoise(.5)+.5))
EndIf
	
End


///// Update the X,Y pairs
Function UpdateVector(theta,displacement)
Variable theta,displacement
	displacement=displacement>1? 1:displacement
	displacement=displacement<0? 0:displacement

Wave/Z x_wave = root:CoherenceGlobals:x_wave
Wave/Z y_wave=root:CoherenceGlobals:y_wave
Wave/Z CorrPtsWave=root:CoherenceGlobals:CorrPtsWave

Wave/Z CoherentX = root:CoherenceGlobals:CoherentX
Wave/Z CoherentY = root:CoherenceGlobals:CoherentY

	Duplicate/O x_wave newXwave,newYwave
	Duplicate/O x_wave thetaWave_noise,thetaWave_corr,thetaWave
		 thetaWave_noise=0;thetaWave_corr=0;thetaWave=0
Variable X_coord,Y_coord,X_displacement,Y_displacement
Variable NewX_coord,NewY_coord
Variable n,ThetaUpdate

	thetaWave_noise[0,*] = ((Enoise(180)+180))*(PI/180)	///
	thetaWave_noise[0,*] = thetaWave_noise[p]*!(CorrPtsWave[p]) // pick random thetas for the non-correlated points
	
	thetaWave_corr = (theta*CorrPtsWave[p])*(PI/180) // the other guys all have the same theta specified by the argument
	thetaWave[0,*]=thetaWave_Corr[p]+thetaWave_noise[p] // combine the "changing" and "non-changing" guys.
	
	
	newXwave[0,*] = x_wave[p]+(displacement*cos(thetaWave[p]))
	newYwave[0,*] = y_wave[p]+(displacement*sin(thetaWave[p]))

	newXwave[0,*] = newXwave[p]>1 ? newXwave[p]-1 : newXwave[p] // Did we leave the interval [0,1]? If so, just
	newXwave[0,*] = newXwave[p]<0 ? newXwave[p]+1 : newXwave[p] // wrap around to the beginning/end of the interval
	newYwave[0,*] = newYwave[p]>1 ? newYwave[p]-1 : newYwave[p] // as appropriate
	newYwave[0,*] = newYwave[p]<0 ? newYwave[p]+1 : newYwave[p]
	
	
	Duplicate/O newXwave x_wave
	Duplicate/O newYwave y_wave
	
	ZapZerosFromWave(x_wave,CorrPtsWave,CoherentX)
	ZapZerosFromWave(y_wave,CorrPtsWave,CoherentY)	 // Duplicate out the Coherent points so they can be visualized
		
End

///// The Master background function
Function MyBG()
NVAR theta = root:CoherenceGlobals:theta
NVAR coherence = root:CoherenceGlobals:coherence
NVAR NewCorrValues = root:CoherenceGlobals:NewCorrValues
	SelectCorrelatedPoints(coherence,NewCorrValues)	// the only trick is to check "NewCorrValues"
	UpdateVector(theta,.05)							// with each call of MyBG(), as this can vary w/	
	return 0											// the slider control
End

///// Set up a data folder and initialize some globals	
Function MakeCoherenceGlobals()
String dfSav = GetDataFolder(1)
NewDataFolder/O/S root:CoherenceGlobals
If(Exists("numpts"))
	SetDataFolder dfSav
Else

	Variable/G numpts = 100
	Variable/G coherence  = .1
	Variable/G theta = 45
	Variable/G NewCorrValues=1
	Make/O/N=100 x_wave,y_wave,CorrPtsWave
	Make/O/N=0 CoherentX,CoherentY
	Make/T/O/N=9 Theta_ticks = {"0","45","90","135","180","225","270","315","360"}
	Make/O/N=9 ThetaTickVals = {0,45,90,135,180,225,270,315,360}
EndIf

SetDataFolder dfSav

End


Function StartDots()
MakeCoherenceGlobals()
NVAR numpts = root:CoherenceGlobals:numpts
NVAR coherence = root:CoherenceGlobals:coherence
NVAR newCorrValues = root:CoherenceGlobals:NewCorrValues
Wave/Z x_wave = root:CoherenceGlobals:x_wave
Wave/Z y_wave = root:CoherenceGlobals:y_wave
	
	NewCorrValues=1
	MakeRandomVectors(numpts)
	
If(WinType("CoherentDots")==0)
	Display/N=CoherentDots x_wave vs y_wave AS "Coherent Dots"
	ModifyGraph mode=3,marker=19,msize(x_wave)=3,rgb(x_wave)=(0,0,0)
	ModifyGraph axRGB=(65535,65535,65535),tlblRGB=(65535,65535,65535);DelayUpdate
	ModifyGraph alblRGB=(65535,65535,65535);DelayUpdate
	SetAxis left 0,1.1 ;DelayUpdate
	SetAxis bottom 0,1.1 
EndIf

SetBackground MyBG()
CtrlBackground period=3,start

End

Function StopDots()
KillBackground
End

Function StartStopButton(CtrlName) : ButtonControl
	String ctrlName
	
	If(cmpstr(ctrlName,"bStart") == 0 )
		Button $ctrlName,title="Stop",rename=bStop
		StartDots() 
	Else
		Button $ctrlName,title="Start",rename=bStart
		StopDots() 
	Endif

End

Window CoherencePanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel/K=1 /W=(789,76,1171,427)
	SetDrawLayer UserBack
	SetDrawEnv linethick= 2,arrow= 1
	DrawLine 43,241,43,219
	SetDrawEnv linethick= 2,arrow= 2
	DrawLine 184,241,184,219
	SetDrawEnv linethick= 2,arrow= 1
	DrawLine 101,231,125,231
	SetDrawEnv linethick= 2,arrow= 2
	DrawLine 245,231,269,231
	SetDrawEnv linethick= 2,arrow= 1
	DrawLine 327,241,327,219
	SetDrawEnv linethick= 2,arrow= 1
	DrawLine 72,241,90,223
	SetDrawEnv linethick= 2,arrow= 1
	DrawLine 299,241,281,223
	SetDrawEnv linethick= 2,arrow= 2
	DrawLine 156,241,138,223
	SetDrawEnv linethick= 2,arrow= 2
	DrawLine 217,241,235,223
	SetDrawEnv fsize= 18
	DrawText 143,339,"flow direction"
	SetDrawEnv fsize= 18
	DrawText 150,182,"coherence"
	SetVariable TotalDots,pos={18,14},size={175,25},title="Total Dots",fSize=18
	SetVariable TotalDots,limits={1,200,1},value= root:CoherenceGlobals:numpts
	Button bStart,pos={230,9},size={103,49},proc=StartStopButton,title="Start"
	Button bStart,fSize=20
	Slider slider0,pos={36,109},size={309,49},proc=SliderMoved
	Slider slider0,limits={0,1,0.05},variable= root:CoherenceGlobals:coherence,vert= 0,ticks= 10
	Slider slider1,pos={37,261},size={309,51}
	Slider slider1,limits={0,360,1},variable= root:CoherenceGlobals:theta,vert= 0,ticks= 10
	Slider slider1,userTicks={root:CoherenceGlobals:ThetaTickVals,root:CoherenceGlobals:Theta_ticks}
	CheckBox ShowCoherentSet,pos={20,54},size={157,20},proc=ShowCoherentSet,title="Show Coherent Set"
	CheckBox ShowCoherentSet,fSize=16,value= 0
EndMacro

Macro StartCoherencePlot()
	MakeCoherenceGlobals()
	CoherencePanel()
End

///// During the process of sliding, new coherence values are chosen, so CorrPtsWave needs to 
///// change on the fly. 
Function SliderMoved(S_Struct) :SliderControl
Struct WMSliderAction &S_Struct
NVAR NewCorrValues = root:CoherenceGlobals:NewCorrValues

	If(S_Struct.eventCode==2)
		NewCorrValues = 1 // Mouse down? Update the set of Correlated dots
	EndIf
	If(S_Struct.eventCode==4)
		NewCorrValues = 0 // Mouse up? Maintain the set of Correlated dots
	EndIf
		
End

///// Does what it says.
Function ZapZerosFromWave(inwave,indexWave,outwave)
Wave inwave
Wave indexWave
Wave outwave

Variable totalPoints = dimsize(indexWave,0)
Variable totalNonZeroPoints = sum(indexWave)
	
	Duplicate/O inwave outwave; Duplicate/O indexWave indexWaveDup
	Sort/R indexWaveDup,indexWaveDup,outwave
	DeletePoints TotalNonzeroPoints-1,totalPoints, outwave
			
End

Function ShowCoherentSet(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	Wave CoherentX = root:CoherenceGlobals:CoherentX
	Wave CoherentY = root:CoherenceGlobals:CoherentY
	
	If(checked==1)
		AppendToGraph/W=CoherentDots CoherentX vs CoherentY
		ModifyGraph mode=3,marker=19,msize(CoherentX)=5,rgb(CoherentX)=(65280,0,0)
	EndIf
	
	If(checked==0)
		RemoveFromGraph/W=CoherentDots/Z CoherentX
	EndIf
	
End
