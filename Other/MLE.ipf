// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/MLE.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

Function MLE(Data,Func,num_params)
	Wave Data
	FuncRef GenericFit Func
	Variable num_params
	Make /o/n=10 TempData=NaN
	Variable i
//	Variable num_params=0
//	for(i=0;i<numpnts(TempData);i+=1)
//		TempData[i]=0
//		Variable result=Func(TempData,0)
//		if(numtype(result)!=2)
//			num_params=i+1
//			break
//		endif
//	endfor
	//Make /o/n=(num_params,num_params) MLE_PDF=Func
End

Function GenericFit(w,t)
	Wave w; Variable t
End

Function Gausso(w,x1,x2)
	Wave w
	Variable x1,x2
	return x1*exp(-x1/w[0])
End