// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/QImaging.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

Function GrabALot()
	Variable i,j
	i=0
	j=StartMsTimer
	Do
		Execute/Q "Grabber grabFrame"
		DoUpdate
		i+=1
	While (i<=50)
	print StopMsTimer(j)/(1000000*50)
End