#pragma rtGlobals=1		// Use modern global access method.

#pragma rtGlobals=1		// Use modern global access method.
#include "Dependency_Analyzer"

// Estimation of Parameters and Eigenmodes of Multivariate Autoregressive Models
// Arnold Neumaier and Tapio Schneider
// arfit.pdf
function MAR(w,maxLag)
	wave w
	variable maxLag
	variable i,points=dimsize(w,0), n=dimsize(w,1)
	wave test1=w
	make /o/n=(points,n*maxLag) test1All=test1[p-floor(q/n)-1][mod(q,n)]
	//matrixop /o test1All=rotateCols(test1All,-n)
	insertpoints /m=1 0,1,test1All
	test1All[][0]=1
	matrixop /o UU=test1All^t x test1All
	matrixop /o VV=test1^t x test1
	matrixop /o WW=test1^t x test1All
	matrixop /o BB=(WW x inv(UU))^t
	variable np=n*maxLag-1
	matrixop /o CC=(VV - WW x inv(UU) x WW^t)/(n-np)
	make /o/n=(n,n,maxLag) pcorr_lls=BB[q+r*2+1][p]
end

function pCorrLLS(w,maxLag)
	wave w
	variable maxLag
	
	//w=p+10000*q
	variable points=dimsize(w,0)-maxLag+1 // Points to use.  
	variable numWaves=dimsize(w,1)
	maxLag/=dimdelta(w,0) // Convert from x-scaling units to points.
	make /o/n=(numWaves,numWaves,maxLag) pCorr_lls=nan
	variable i,j,lag,v_fitoptions=4
	make /o/n=(points,numWaves*maxLag) all=w[p+maxLag-floor(q/numWaves)][mod(q,numWaves)] // For all lags between 0 and maxLag...
	for(i=0;i<numWaves;i+=1)
		make /o/n=(points) yy=all[p][i]
		for(j=0;j<numWaves;j+=1)
			for(lag=0;lag<maxLag;lag+=1)
				make /o/n=(points) xx=all[p][j+lag*numWaves]
				duplicate /free all,zz
				variable col1=i
				variable col2=j+lag*numWaves
				if(col1<col2)
					deletepoints /m=1 col2,1,zz
					deletepoints /m=1 col1,1,zz//zz[][col1]=1
				elseif(col2<col1)
					deletepoints /m=1 col1,1,zz
					deletepoints /m=1 col2,1,zz//zz[][col2]=1
				else
					continue // Partial correlation with itself.  
				endif
			
				matrixlls yy zz
				wave m_b
				redimension /n=(1,-1) m_b
				matrixop /o resid_yyzz=yy - zz x m_b^t
				
				matrixlls xx zz
				redimension /n=(1,-1) m_b
				matrixop /o resid_xxzz=xx - zz x m_b^t
					
				variable rr=statscorrelation(resid_yyzz,resid_xxzz)
				pCorr_lls[i][j][lag]=rr
			endfor
		endfor
	endfor
end

Structure myStructure
	wave coefW
	variable x[24]
EndStructure

Function myFitFunc(s) : FitFunc
	Struct myStructure &s
	
	wave betas=s.coefW
	make /free/n=24 xx=s.x[p]
	matrixop /free result=xx . betas
	return result[0]
End

Function MultivariateLinear(xx,betas)
	wave xx // The covariates.  First column should contain ones.  
	wave betas // The coefficients.
	
	matrixop /free result=xx x betas
	return sum(xxBeta)
End

function CorrLLS(w,maxLag)
	wave w
	variable maxLag
	
	variable points=dimsize(w,0)
	variable numWaves=dimsize(w,1)
	maxLag/=dimdelta(w,0) // Convert from x-scaling units to points.
	duplicate /free w,yy
	make /free/n=(points,numWaves*maxLag) xx
	xx=yy[p+mod(q,maxLag)][floor(q/maxLag)]
	duplicate /o xx,poop
	redimension /n=(points-maxLag,-1) yy,xx
	matrixLLS yy,xx
	redimension /n=(2,-1) m_b
end

function DeterminantPDF(dim)
	variable dim
	
	variable i
	make /o/n=(100000) test2
	for(i=0;i<numpnts(test2);i+=1)
		make /o/n=(dim,dim) test=cos(enoise(pi))
		matrixop /o test=normalizerows(test)
		matrixop /o determinant=det(test)
		test2[i]=log(abs(determinant[0]))
	endfor
	ecdf(test2)
End

function AllSweeps2(experiment)
	variable experiment
	wave Times1,Times2,Index1,Index2,Spikes_
	make /o/n=40 Peaks
	variable i
	ProgWinOpen()
	for(i=1;i<=40;i+=1)
		ProgWin((i-1)/40,0)
		extract /o $("Times"+num2str(experiment)),$"Times_",Index1==i
		wave Times_=$"Times_"
		Events2Binary(Times_,Spikes_)
		make /o/n=(numpnts(spikes_),4) history=0
		history=(spikes_[p-1] ? 1 : history[p-1][q]+1)
		history=ln(history)^(q+1)
		matrixop /o history=subtractmean(history,1)
		glmfit(:spikes_,{history},"poisson",quiet=1)
		wave betas
		make /o/n=(numpnts(betas)-1) historyBetas=betas[p+1]
		history=ln(p+1)^(q+1)
		matrixop /o history=subtractmean(history,1)
		matrixop /o historyMu=exp(history x historyBetas)
		insertpoints 0,1,historyMu
		wavestats /q/r=[1,] historyMu
		if(historyBetas[1]>0)
			Peaks[i]=v_minloc
		else
			Peaks[i]=v_maxloc
		endif
		print Peaks[i]
		doupdate
	endfor
	ProgWinClose()
end

Function TestDet4()
	variable i
	make /o/n=(5,5) test=5+gnoise(5)
	make /o/n=5 test2=norm(row(test,p))
	make /o/n=100000 results
	for(i=0;i<numpnts(results);i+=1)
		make /free/n=(5,5) m_=test+gnoise(test2(p))
		results[i]=abs(det(m_))
	endfor
	ecdf(results)
	//results/=abs(det(test))
End

Function TestDet3()
	variable i
	make /o/n=100000 results,results2
	for(i=0;i<numpnts(results);i+=1)
		make /o/n=(4,4) m_=gnoise(1)
		results[i]=abs(det(m_))
	endfor
	ecdf(results)
	for(i=0;i<numpnts(results2);i+=1)
		make /o/n=(4,4) m_=5+gnoise(1)
		results2[i]=abs(det(m_))
	endfor
	ecdf(results2)
	make /o/n=(numpnts(results)) results3=results2/results
End

Function TestDet2()
	variable i
	make /o/n=100000 results
	for(i=0;i<numpnts(results);i+=1)
		variable a=enoise(pi),b=enoise(pi),c=enoise(pi)
		results[i]=sqrt(1+2*cos(a)*cos(b)*cos(c)-cos(a)^2-cos(b)^2-cos(c)^2)
	endfor
	ecdf(results)
End

// Returns a cumulative distribution function for the size of a determinant relative to the size of the determinant of a matrix with orthogonal rows.  
Function /wave DeterminantCDF(m[,iter])
	wave m // A sample matrix.  	
	variable iter // Iterations (size of the cumulative histogram).  
	
	iter=paramisdefault(iter) ? 1000 : iter
	variable i
	make /free/n=(iter) cdf
	variable meann=mean(m)
	for(i=0;i<numpnts(results);i+=1)
		make /free/n=(dimsize(m,0),dimsize(m,1)) m_=meann+gnoise(1)
		matrixop /o relDeterminant=abs(det(m_))/exp(sum(ln(sqrt(sumrows(m_*m_)))))
		cdf[i]=relDeterminant
	endfor
	ecdf(cdf)
	return cdf
End

Function CentralLimit()
	make /o/n=(1000,1000) test=statsvonmisesnoise(1,10)
	matrixop /o test=sumcols(test)^t
	test=mod(test,2*pi)
End

Function VonMisesVsCC()
	variable i,j
	make /o/n=200 test4
	setscale x,0,10,test4
	progwinopen()
	for(j=0;j<numpnts(test4);j+=1)
		progwin(j/numpnts(test4),0)
		make /o/n=(100) test3
		for(i=0;i<numpnts(test3);i+=1)
			make /o/n=1000 test1=enoise(pi),testDiff=StatsVonMisesNoise(0,pnt2x(test4,j)),test2=test1+testDiff
			matrixop /o r2=powR(mean(cos(testDiff)),2)+powR(mean(sin(testDiff)),2)
			test3[i]=r2[0]
			//test3[i]=CircularCorrelation(test,test2)
		endfor
		sort test3,test3
		test4[j]=mean(test3)
	endfor
	progwinclose()
End

Function VonMisesVsCC2()
	variable i,j
	make /o/n=200 test4
	setscale x,0,10,test4
	progwinopen()
	for(j=0;j<numpnts(test4);j+=1)
		progwin(j/numpnts(test4),0)
		make /o/n=(100) test3
		for(i=0;i<numpnts(test3);i+=1)
			make /o/n=1000 test=StatsVonMisesNoise(0,10),test2
			test2=test+StatsVonMisesNoise(0,pnt2x(test4,j))
			test3[i]=CircularCorrelation(test,test2)
			//print test3[i]
		endfor
		sort test3,test3
		test4[j]=mean(test3)
	endfor
	progwinclose()
End