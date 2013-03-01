#pragma rtGlobals=1		// Use modern global access method.

////////////////////////////////////////////////////////////////////////////////////////////
// 14NOV02
//  Added the varimax procedure derived from the Henry Kaiser paper: "Computer Program for Varimax Rotation in 
// factor analysis", Educational and Psychological Measurement, Vol XIX, No. 3. 1959 PP. 413-420.
//
// 24OCT02
// The following procedures are based on the tests and text in E.R. Malinowski, "Factor Analysis in Chemistry" (third ed.),
// ISBN 0-471-13479-1.  The book also contains in an appendix some Matlab code that is full of errors, is unoptimal and 
// difficult to read.  This was distilled below to the following IGOR routines.

// The following function evaluates the significant factors for the input data matrix.
// matD: a rectangular matrix containing the input data.  It should not contain any 
// NaNs.  
// mode: a variable that describes how the function is used.
// 0 -- complete with GUI
// 1 -- no GUI; just return the significant number but keep the remaining data stored in root:Packages:PCA
// 2 -- no GUI; just return the significant number and clean up all leftovers.
// Note that the %SL correspond to the F-test values where the null hypothesis is that the eigenvalue belongs to the 
// error eigenvalues.  Therefore high %SL makes it likely that the null hypothesis is correct and therefore the eigenvalue
// should not be included (see comments in the book on page 105).
// Depending on mode, the results of the analysis are stored in the wave significanceTest which can be found in 
// root:Packages:PCA.
////////////////////////////////////////////////////////////////////////////////////////////

Function WMSignifiantFactorAnalysis(matD,mode)
	Wave matD
	Variable mode
	
	String oldDF=GetDataFolder(1)
	SetDataFolder root:
	NewDataFolder/O/S Packages
	NewDataFolder/O/S PCA
	
	Variable rows,cols
	rows=DimSize(matD,0)
	cols=DimSize(matD,1)
	
	if(rows<cols)
		MatrixTranspose matD
		rows=DimSize(matD,0)
		cols=DimSize(matD,1)
	endif
	
	MatrixSVD   matD
	if(V_Flag)
		Abort "Error in SVD; could not determine the number of significant factors."
		SetDataFolder oldDF
		return NaN
	endif
	
	Wave M_U,M_V,W_W
	Make/O/N=(cols) eigenValue,df,rev,sev,sdf,re,ind
	
	Variable i
	for(i=0;i<cols;i+=1)
		eigenValue[i]=W_W[i]*W_W[i]
		df[i]=(rows-i)*(cols-i)				// shifted index
		rev[i]=eigenValue[i]/df[i]
	endfor
	
	Variable k
	
	sev=NaN
	sdf=NaN
	
	for(k=0;k<cols-1;k+=1)
		sev[k]=sum(eigenValue,k+1,INF)  	 
		sdf[k]=sum(df,k+1,INF)			 
	endfor
	
	re=NaN
	ind=NaN
	for(i=0;i<cols-1;i+=1)
		re[i]=sqrt(sev[i]/(rows*(cols-i)))
		ind[i]=re[i]/(cols-i)^2
	endfor
	
	Variable n
	WaveStats/Q ind
	n=V_minloc+1		// add 1 because we are zero based
	if(mode==0)
		Print "ind function indicates there are ",n," significant factors"
	endif
	if(n<=0)
		SetDataFolder oldDF
		return 0
	endif
	
	if(mode==2)
		KillWaves/Z  M_U,M_VT,W_W, eigenValue,df,rev,sev,sdf,re,ind
		SetDataFolder oldDF
		return n
	endif
		
	Make/O/N=(cols,5) significanceTest
	
	SetDimLabel 1,0,eignevalue,significanceTest
	SetDimLabel 1,1,RE,significanceTest
	SetDimLabel 1,2,IND,significanceTest
	SetDimLabel 1,3,REV,significanceTest
	SetDimLabel 1,4,SL,significanceTest
	
	for(i=0;i<cols;i+=1)
		significanceTest[i][0]=eigenValue[i]
		significanceTest[i][1]=re[i]
		significanceTest[i][2]=ind[i]
		significanceTest[i][3]=rev[i]
	endfor
	
	Variable f,a,b,tt,degF,im,jm,ss,cc,ks,fk,cl,sl
	
	for(i=0;i<cols-1;i+=1)
		f=(sdf[i]*eigenValue[i])/((rows+i)*(cols+i)*sev[i])
		tt=sqrt(f)
		degF=cols-i-1
		a=tt/sqrt(degF)
		b=degF/(degF+tt*tt)
		im=degF-2
		jm=degF-2*floor(degF/2)
		ss=1
		cc=1
		ks=2+jm
		fk=ks
		if((im-2)>=0)
			for(k=ks;k<=im;k+=2)
				cc=cc*b*(fk-1)/fk
				ss=ss+cc
				fk=fk+2
			endfor
			
			if((degF-1)>0)
				cl=0.5+(a*b*ss+atan(a))*0.31831
			else
				cl=0.5+atan(a)*0.31831
			endif
			
			if(jm<0)
				cl=0.5+0.5*a*sqrt(b)*ss
			endif
		endif
		
		significanceTest[i][4]=100*(1-cl)
	endfor
	
	if(mode==0)
		Edit/K=1	significanceTest.ld
	endif
	
	KillWaves/Z  M_U,M_VT,W_W,eigenValue,df,rev,sev,sdf,re,ind
	SetDataFolder oldDF
	return n
End

////////////////////////////////////////////////////////////////////////////////////////////
// 23OCT02
// A program designed to target test suspected vectors. 
// matD is the data matrix that should not contain any NaNs.
// numFactors is the number of significant factors assumed. numFactors must be smaller
// than the smallest dimension of matD.
// testMatrix is a test matrix containing the same number of rows as matD and as many columns
// as you would want to test.
// The function returns 0 if successful or -1 otherwise.
// The results of the analysis are stored in the wave targetResults which can be found in 
// root:Packages:PCA.
////////////////////////////////////////////////////////////////////////////////////////////

Function WMTargetTestFactorAnalysis(matD,numFactors,testMatrix)
	Wave matD
	Variable numFactors
	Wave testMatrix
	
	String oldDF=GetDataFolder(1)
	SetDataFolder root:
	NewDataFolder/O/S Packages
	NewDataFolder/O/S PCA

	Variable rx,nx
	Variable rows,cols
	
	rx=DimSize(testMatrix,0)
	nx=DimSize(testMatrix,1)
	
	rows=DimSize(matD,0)
	cols=DimSize(matD,1)
	
	if(rx !=rows)
		Abort  "Target vectors must have the same number of rows as data matrix"
		return -1
	endif
	
	Variable large,small
	large=rows
	small=cols
	if(rows<cols)
		large=cols
		small=rows
		MatrixTranspose matD
		MatrixSVD   matD
		if(V_Flag)
			Abort "Error in SVD"
			SetDataFolder oldDF
			return -1
		endif
		Wave matU=M_VT					// qqq may not need to be the transposed
		MatrixTranspose matU
	else
		MatrixSVD   matD
		Wave matU=M_U
	endif
	
	Variable j
	Make/O/N=(small) eigenValue,df,rev
	Wave W_W
	
	for(j=0;j<small;j+=1)
		eigenValue[j]=W_W[j]*W_W[j]
		df[j]=(rows-j)*(cols-j)
		rev[j]=eigenValue[j]/df[j]
		matU[][j]=matU[p][j]*W_W[j]
	endfor
	
	Make/O/N=(DimSize(matU,0),numFactors) uBar
	Variable sev,sdf,re
	
	uBar=matU[p][q]
	sev=sum(eigenValue,numFactors,inf)			// assuming small is the last index
	sdf=sum(df,numFactors,inf)					// starting the count from numFactors because we are zero based
	
	if(small<=numFactors)
		Abort "numFactors must be smaller than the smallest dimension of the matrix."
		return -1
	endif
	
	re=sqrt(sev/(large*(small-numFactors)))
	
	MatrixInverse/P uBar						// Pseudo inverse; This will require IGOR 5.0
	Wave M_Inverse
	
	// create temporary vectors to hold data for matrix multiplications:
	Make/O/N=(rows) tmpX,dX,XP,aet,rep,ret,spoil,ftest
	
	for(j=0;j<nx;j+=1)
		tmpX=testMatrix[p][j]
		MatrixMultiply M_Inverse,tmpX
		Wave M_Product
		Duplicate/O M_Product, tmpT
		MatrixMultiply uBar,tmpT
		Duplicate/O M_Product, XP
		dX=XP-tmpX
		aet[j]=sqrt(MatrixDot(dX,dX)/(rx-numFactors))
		rep[j]=re*norm(tmpT)
		if(rep[j]>aet[j])
			ret[j]=0
		else
			ret[j]=sqrt(aet[j]^2-rep[j]^2)
		endif
		spoil[j]=ret[j]/rep[j]
		ftest[j]=(sdf*rows*aet[j]^2)/((rows-numFactors)*(cols-numFactors)*sev*MatrixDot(tmpT,tmpT))
	endfor
	
	Make/O/N=(nx,5) targetResults
	SetDimLabel 1,0,AET,targetResults
	SetDimLabel 1,1,REP,targetResults
	SetDimLabel 1,2,RET,targetResults
	SetDimLabel 1,3,SPOIL,targetResults
	SetDimLabel 1,4,FTest,targetResults
	
	for(j=0;j<nx;j+=1)
		targetResults[j][0]=aet[j]
		targetResults[j][1]=rep[j]
		targetResults[j][2]=ret[j]
		targetResults[j][3]=spoil[j]
		targetResults[j][4]=ftest[j]
	endfor
	
	KillWaves/Z 	tmpX,dX,XP,aet,rep,ret,spoil,ftest

	SetDataFolder oldDF	
	return 0
End


////////////////////////////////////////////////////////////////////////////////////////////
// 24OCT02
// matD is the data matrix.
// testMatrix must have the same number of rows as matD.  The number of columns in testMatrix
// must be equal to the number of factors in matD.
// Returns -1 if it fails, 0 if it succeeds.
// The results are in the waves loadings and loadingError in root:Packages:PCA
// 
////////////////////////////////////////////////////////////////////////////////////////////
Function WMCalcFactorLoading(matD,testMatrix)
	Wave matD,testMatrix
	
	
	Variable rows,cols,small,k
	Variable numFactors
	Variable j
	
	rows=DimSize(matD,0)
	cols=DimSize(matD,1)
	if(rows!=DimSize(testMatrix,0))
		Abort "The number of rows in the test matrix must match the number of rows in the data matrix."
		return -1
	endif

	String oldDF=GetDataFolder(1)
	SetDataFolder root:
	NewDataFolder/O/S Packages
	NewDataFolder/O/S PCA
	
	numFactors=DimSize(testMatrix,1)
	if(numFactors>=rows)
		Abort "The number of columns in the test matrix must be less than the number of rows."
		return -2
	endif
	
	small=cols
	if(rows<cols)
		small=rows
		MatrixTranspose matD
		MatrixSVD matD
		Wave M_U, M_VT,W_W		
		MatrixTranspose M_VT			// this will hold the matrix U
		Wave V=M_U
		Wave U=M_VT
	else
		MatrixSVD matD
		Wave M_U, M_VT,W_W	
		MatrixTranspose M_VT			// this will hold the matrix V
		Wave V=M_VT
		Wave U=M_U
	endif
	
	for(j=0;j<small;j+=1)
		U[][j]*=W_W[j]
	endfor
	
	Make/O/N=(DimSize(U,0),numFactors) ubar
	Make/O/N=(DimSize(V,0),numFactors) vbar
	ubar=U[p][q]
	vbar=V[p][q]
	
	MatrixInverse/P uBar						// This will require IGOR 5.0
	Wave M_Inverse
	Duplicate/O M_Inverse, pinv
	Make/O/N=(rows) waveX,waveDx
	Make/O/N=(rows,numFactors) fullT

	for(j=0;j<numFactors;j+=1)			// Needs work from here down.
		waveX=testMatrix[p][j]
		MatrixMultiply pinv,waveX
		Wave M_Product
		Duplicate/O M_Product,waveT
		MatrixMultiply ubar,waveT
		Wave M_Product
		waveDx=M_Product-waveX
		fullT[][j]=waveT[p]
	endfor
	
	MatrixInverse fullT					// result in M_Inverse
	MatrixTranspose vbar				// result overwrites
	Wave M_Inverse
	MatrixMultiply M_Inverse,vbar	// result in M_Product
	Wave M_Product
	Duplicate/O M_Product,loadings		// loadings=inv(t)*vbar'
	
	// estimated error in the loadings using Clifford method
	
	Duplicate/O matD, matError
	MatrixMultiply testMatrix,loadings
	Wave M_product
	matError-=M_product
	
	Duplicate/O testMatrix, testMatrixT
	MatrixTranspose testMatrixT
	MatrixMultiply testMatrixT,testMatrix
	Wave M_product
	MatrixInverse M_product
	Wave M_inverse
	Duplicate/O M_inverse xx
	
	Make/O/N=(rows) ej
	Duplicate/O loadings,loadingError
	for(j=0;j<cols;j+=1)
		ej=matError[p][j]
		Duplicate/O ej,ejt
		MatrixTranspose ejt
		MatrixMultiply xx,ejt,ej
		Wave M_product
		M_product/=(rows-numFactors)
		for(k=0;k<numFactors;k+=1)
			loadingError[k][j]=sqrt(M_product[k][k])
		endfor
	endfor
	
	KillWaves/Z M_product,ej,ejt,M_inverse,vbar,M_U,M_VT,waveX,waveDx,fullT,waveT,testMatrixT
	
	SetDataFolder oldDF
	
	return 0
End

////////////////////////////////////////////////////////////////////////////////////////////
// 14NOV02
// The following function performs a Varimax rotation of inWave subject to the specified epsilon.  
// The algorithm follows the paper by Henry F Kaiser 1959 and involves normalization followed by
// rotation of two vectors at a time.
// The value of epsilon determines convergence.  The algorithm computes the tangent of 4*rotation 
// angle and the value is compared to epsilon.  If it is less than epsilon it is assumed to be essentially
// zero and hence no rotation.  A smaller value of epsilon leads to a larger number of rotations.
// The function returns the number of rotations peformed (each rotation is on two vectors).  The function
// creates the wave M_Varimax that contains the rotated matrix.
////////////////////////////////////////////////////////////////////////////////////////////

Function WM_VarimaxRotation(inWave,epsilon)
	Wave inWave
	Variable epsilon
	
	Variable rows=DimSize(inWave,0)
	Variable  cols= DimSize(inWave,1)
	
	// start by computing the "communalities"
	 Make/O/N=(cols) communalities
	 Variable i,j,theSum
	 for(i=0;i<cols;i+=1)
	 	theSum=0
	 	for(j=0;j<rows;j+=1)
	 		theSum+=inWave[j][i]*inWave[j][i]
	 	endfor
	 	communalities[i]=sqrt(theSum)
	 endfor
	 
	 Make/O/N=(2,2) rotationMatrix
	 Make/O/N=(rows,2) twoColMatrix
	 Duplicate/O inWave, M_Varimax		// the calculation is done in place so M_Varimax will be the wave holding the rotated vectors.
	 // normalize the wave
	 for(i=0;i<cols;i+=1)
	 	for(j=0;j<rows;j+=1)
	 		M_Varimax[j][i]/=communalities[i]
	 	endfor
	 endfor
	 
	 // now start rotating vectors:
	 Variable convergenceLevel=cols*(cols-1)/2
	 Variable rotation,col1,col2
	 Variable rotationCount=0
	 do
	 	for(col1=0;col1<cols-1;col1+=1)
	 		for(col2=col1+1;col2<cols;col2+=1)
				rotation=doOneVarimaxRotation(M_Varimax,rotationMatrix,twoColMatrix,col1,col2,rows,epsilon)
				rotationCount+=1
				if(rotation)
					convergenceLevel=cols*(cols-1)/2
				else
					convergenceLevel-=1
					if(convergenceLevel<=0)
						 for(i=0;i<cols;i+=1)
						 	for(j=0;j<rows;j+=1)
						 		M_Varimax[j][i]*=communalities[i]
						 	endfor
						 endfor
						KillWaves/Z rotationMatrix,twoColMatrix,communalities,M_Product
						return rotationCount
					endif
				endif
			endfor
		endfor
	while(convergenceLevel>0)

	KillWaves/Z rotationMatrix,twoColMatrix,communalities,M_Product
	return rotationCount
End

////////////////////////////////////////////////////////////////////////////////////////////
// this function is being called by WM_VarimaxRotation(); it has no use on its own.  The function
// rotates a couple of vectors at a time.  We keep rotationMatrix,twoColMatrix in the calling routine
// so that they are allocated only once and not each time this function is called.
// To optimize things further consider the xx and yy assignments. 
////////////////////////////////////////////////////////////////////////////////////////////
Function  doOneVarimaxRotation(norWave,rotationMatrix,twoColMatrix,col1,col2,rows,epsilon)
	wave norWave,rotationMatrix,twoColMatrix
	Variable col1,col2,rows,epsilon
	
	Variable A,B,C,D
	Variable i,xx,yy
	Variable sqrt2=sqrt(2)/2
	
	A=0
	B=0
	C=0
	D=0
	
	for(i=0;i<rows;i+=1)
		xx=norWave[i][col1]
		yy=norWave[i][col2]
		twoColMatrix[i][0]=xx
		twoColMatrix[i][1]=yy
		A+=(xx-yy)*(xx+yy)
		B+=2*xx*yy
		C+=xx^4-6.*xx^2*yy^2+yy^4
		D+=4*xx^3*yy-4*yy^3*xx
	endfor
	
	Variable numerator,denominator,absNumerator,absDenominator
	numerator=D-2*A*B/rows
	denominator=C-(A*A-B*B)/rows
	absNumerator=abs(numerator)
	absDenominator=abs(denominator)
	
	Variable cs4t,sn4t,cs2t,sn2t,tan4t,ctn4t
	
	// handle here all the cases :
	if(absNumerator<absDenominator)
		tan4t=absNumerator/absDenominator
		if(tan4t<epsilon)
			return 0								// no rotation
		endif
		cs4t=1/sqrt(1+tan4t*tan4t)
		sn4t=tan4t*cs4t
		
	elseif(absNumerator>absDenominator)
		ctn4t=absDenominator/absNumerator
		if(ctn4t<epsilon)							// paper sec 9
			sn4t=1
			cs4t=0
		else
			sn4t=1/sqrt(1+ctn4t*ctn4t)
			cs4t=ctn4t*sn4t
		endif
	elseif(absNumerator==absDenominator)
		if(absNumerator==0)
			return 0;								// undefined so we do not rotate.
		else
			sn4t=sqrt2
			cs4t=sqrt2
		endif
	endif
	
	// at this point we should have sn4t and cs4t
	cs2t=sqrt((1+cs4t)/2)
	sn2t=sn4t/(2*cs2t)
	
	Variable cst=sqrt((1+cs2t)/2)
	Variable snt=sn2t/(2*cst)
	
	// now converting from t to the rotation angle phi based on the signs of the numerator and denominator
	Variable csphi,snphi
	
	if(denominator<0)
		csphi=sqrt2*(cst+snt)
		snphi=sqrt2*(cst-snt)
	else
		csphi=cst
		snphi=snt
	endif
	
	if(numerator<0)
		snphi=-snt
	endif
	
	// perform the rotation using matrix multiplication
	rotationMatrix={{csphi,snphi},{-snphi,csphi}}
	MatrixMultiply twoColMatrix,rotationMatrix
	// now write the rotation back into the wave
	Wave M_Product
	for(i=0;i<rows;i+=1)
		norWave[i][col1]=M_Product[i][0]
		norWave[i][col2]=M_Product[i][1]
	endfor
	return 1
End