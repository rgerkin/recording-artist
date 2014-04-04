
// $Author: rick $
// $Rev: 630 $
// $Date: 2013-02-19 22:12:49 -0700 (Tue, 19 Feb 2013) $

#pragma rtGlobals=1		// Use modern global access method.

Function /wave ManyTests(waves[,tests])
	wave /wave waves
	string tests
	
	if(paramisdefault(tests))
		tests="bootmean;ks;t;wilcoxon"
	endif
	make /o/n=(itemsinlist(tests)) w_pvals
	variable i,pp
	for(i=0;i<itemsinlist(tests);i+=1)
		string test=stringfromlist(i,tests)
		strswitch(test)
			case "bootmean":
				pp=bootmean(waves[0],waves[1])
				break
			case "ks":
				statskstest /q waves[0],waves[1]
				wave w_ksresults
				pp=w_ksresults[%$"PValue(Ne)"]
				break
			case "t":
				statsttest /q/tail=4 waves[0],waves[1]
				wave w_statsttest
				pp=w_statsttest[%p]
				break
			case "wilcoxon":
				statswilcoxonranktest /q/tail=4 waves[0],waves[1]
				wave w_wilcoxontest
				pp=w_wilcoxontest[%P_TwoTail]
				break
			default:
				pp=nan
		endswitch
		w_pvals[i]=min(pp,1-pp)
	endfor
	return w_pvals
End

function ColMedian(m,col_)
	wave m
	variable col_
	
	matrixop /free w=col(m,col_)
	return statsmedian(w)
end

function RowMean(m,row_)
	wave m
	variable row_
	
	matrixop /free w=row(m,row_)
	return mean(w)
end

function RowMedian(m,row_)
	wave m
	variable row_
	
	matrixop /free w=row(m,row_)
	return statsmedian(w)
end

function RowTrimmedMean(m,row_[trim])
	wave m
	variable row_,trim
	
	trim=paramisdefault(trim) ? 25 : trim
	
	matrixop /free w=row(m,row_)
	redimension /n=(numpnts(w)) w
	return TrimmedMean(w,trim=trim)
end

function TrimmedMean(w[,trim])
	wave w
	variable trim
	
	trim=paramisdefault(trim) ? 25 : trim
	sort w,w
	setscale x,0,100,w
	return mean(w,trim,100-trim)
end

Function Det(m)
	wave /d m
	
	matrixop /free determinant=det(m)
	return determinant[0]
End

// http://en.wikipedia.org/wiki/Distance_correlation
// For vectors of length N, the calculation requires enough memory for construction of N x N matrices.  
Function DistanceCovariance(w1,w2[,permute])
	wave w1,w2
	variable permute // Permute for hypothesis testing.  
	
	variable length=(numpnts(w1))
	if(numpnts(w2) != length)
		Post_("Vectors must be the same length",trace=1)
		return -1
	endif
	if(permute)
		make /free/n=(length) randos=enoise(1)
		duplicate /free w2,w2_
		sort randos,w2_
	else
		wave w2_=w2
	endif
	make /free/n=(numpnts(w1),numpnts(w1)) A=abs(w1[p]-w1[q])
	make /free/n=(numpnts(w2),numpnts(w2)) B=abs(w2_[p]-w2_[q])
	matrixop /free A_=subtractmean(subtractmean(A,1),2)
	matrixop /free B_=subtractmean(subtractmean(B,1),2)
	matrixop /free result=sqrt(mean(A_*B_))
	
	return result[0]
End

// http://en.wikipedia.org/wiki/Distance_correlation
Function DistanceCorrelation(w1,w2[,permute])
	wave w1,w2
	
	variable permute // Permute for hypothesis testing.  
	variable result=DistanceCovariance(w1,w2,permute=permute)/sqrt(DistanceCovariance(w1,w1)*DistanceCovariance(w2,w2))
	return result
End

function DistanceS2(w1,w2)
	wave w1,w2
	
	wave w2_=w2
	make /free/n=(numpnts(w1),numpnts(w1)) A=abs(w1[p]-w1[q])
	make /free/n=(numpnts(w2),numpnts(w2)) B=abs(w2_[p]-w2_[q])
	return mean(A)*mean(B)
end

function DistancePValue(w1,w2)
	wave w1,w2
	variable t=sqrt(numpnts(w1)*(DistanceCovariance(w1,w2)^2)/DistanceS2(w1,w2))
	return t//2*(1-statsnormalcdf(t,0,1))
end

// Computes the Kullback-Leibler Divergence for two distributions.  
function KLDivergence(w1,w2)
	wave w1,w2 // pdfs or counts.  
	
	variable sumw1=sum(w1)
	variable sumw2=sum(w2)
	make /free/n=(numpnts(w1)) Dkl=(w1 > 0) ? (w1/sumw1)*log2((w1/sumw1)/(w2/sumw2)) : 0
	return sum(Dkl)
end

// Computes the Jensen-Shannon Divergence for two distributions.  
function JSDivergence(w1,w2)
	wave w1,w2 // pdfs or counts.   
	
	make /free/n=(numpnts(w1)) w12=(w1+w2)/2
	return (KLDivergence(w1,w12)+KLDivergence(w2,w12))/2
end

function BhattacharyaCoefficient(w1,w2)
	wave w1,w2 // pdfs or counts.  

	matrixop /free result=sqrt(w1*w2/(sum(w1)*sum(w2))) // Squared probabilites.  
	return sum(result)
end

function BhattacharyaDistance(w1,w2)
	wave w1,w2
	
	return -ln(BhattacharyaCoefficient(w1,w2))
end

function HellingerDistance(w1,w2)
	wave w1,w2
	
	return sqrt(1-BhattacharyaCoefficient(w1,w2))
end

function RenyiDivergence(w1,w2,alpha[,symmetric])
	wave w1,w2
	variable alpha,symmetric
	
	if(symmetric)
		matrixop /free w12=(w1+w2)/2
		duplicate /free w1,w1_
		duplicate /free w2,w2_
		variable i=0
		// Eliminate bins where both w1 and w2 have zero probabilty.  
		do
			if(w12[i]<=0)
				deletepoints i,1,w1_,w2_,w12
			else
				i+=1
			endif
		while(i<numpnts(w12))
		return (RenyiDivergence(w1_,w12,alpha)+RenyiDivergence(w2_,w12,alpha))/2
	else
		if(alpha==1) // Through L'Hopital's rule it can be shown that as alpha -> 1, the Renyi Divergence equals the Kullback-Leibler Divergence.  
			return KLDivergence(w1,w2)
		else
			variable sumw1=sum(w1), sumw2=sum(w2)
			make /free/n=(numpnts(w1)) result=(w1/sumw1)^alpha * (w2/sumw2)^(1-alpha)
			return log2(sum(result))/(alpha-1)
		endif
	endif
end

function TotalVariationDistance(w1,w2)
	wave w1,w2 // pdfs or counts.  
	
	matrixop /free result=0.5*sum(abs(w1/sum(w1) - w2/sum(w2)) // pdf differences.  
end

// Cover and Thomas, 1991.  
// http://arxiv.org/abs/q-bio/0311039, eq. 10.  
function VariationOfInformation(w[,finite])
	wave w // Joint pdf.  
	variable finite // Correct for finite data.  Assumes that pdf is actually a histogram of (integer) counts.  
	
	finite=paramisdefault(finite) ? 1 : finite
	return Entropy(w,finite=finite,rel=1)-MutualInformation(w,finite=finite)
end

// http://arxiv.org/abs/q-bio/0311039, eq. 12.  
function JaccardDistance(w[,finite,sharp])
	wave w // Joint pdf.  
	variable finite // Correct for finite data.  Assumes that pdf is actually a histogram of (integer) counts.  
	variable sharp // Use the "sharper" measure in eq. 16.  
	
	finite=paramisdefault(finite) ? 1 : finite
	if(sharp)
		matrixop /free w1=sumcols(w)
		matrixop /free w2=sumcols(w^t)
		return 1 - MutualInformation(w,finite=finite)/max(abs(Entropy(w1,finite=finite,rel=1)),abs(Entropy(w2,finite=finite,rel=1)))
	else
		matrixop /free w1=sumcols(w)
		matrixop /free w2=sumcols(w^t)
		return 1 - MutualInformation(w,finite=finite)/abs(Entropy(w))
	endif
end

function JaccardCoefficient(w[,finite,sharp])
	wave w
	variable finite,sharp
	
	return 1-JaccardDistance(w,finite=finite,sharp=sharp)
end

function LevenshteinDistance(str1,str2[,cost])
	string str1,str2
	variable cost // Cost of a substitution.  
	
	cost=paramisdefault(cost) ? 1 : cost
	variable i,j,m=strlen(str1), n=strlen(str2)
  	make /free/n=(m+1,n+1) d
  	d[][0]=p
  	d[0][]=q
  	for(j=1;j<=n;j+=1)
  		for(i=1;i<=m;i+=1)		
  			if(char2num(str1[i-1])==char2num(str2[j-1]))  
        			d[i][j] = d[i-1][j-1]
      			else
        			d[i][j] = min(d[i-1][j-1]+cost,min(d[i-1][j]+1,d[i][j-1]+1))
           		endif
  		endfor
  	endfor
  	return d[m][n]
end

function /wave DistanceMatrix(data,method[,bins,minBin,maxBin,alpha])
	wave data // Each row is an observation (e.g. trial), and each column is a distinct observed entity (e.g. cell).    
	string method
	variable bins // Number of histogram bins.  Joint histograms will have this number squared.    
	variable minBin
	variable maxBin
	variable alpha // Parameter for Renyi distance.  
	
	bins=paramisdefault(bins) ? 10 : bins
	wavestats /q/m=1 data
	minBin=paramisdefault(minBin) ? v_min : minBin
	maxBin=paramisdefault(maxBin) ? v_max : maxBin
	variable binWidth=(maxBin-minBin)/(bins-1)
	alpha=paramisdefault(alpha) ? 1 : alpha
	
	variable i,j,observations=dimsize(data,0),entities=dimsize(data,1)
	make /o/n=(entities,entities) $("distances"+method) /wave=distances=nan
	strswitch(method)
		case "R2":
		case "DistanceCorrelation":
			for(i=0;i<entities;i+=1)
				prog("i",i,entities)
				wave entity1=col(data,i)
				for(j=0;j<i;j+=1)
					distances[i][j]=distances[j][i]
				endfor
				distances[i][i]=0
				for(j=i+1;j<entities;j+=1)
					wave entity2=col(data,j)
					strswitch(method)
						case "R2":
							distances[i][j]=1-StatsCorrelation(entity1,entity2)^2
							break
						case "DistanceCorrelation":
							distances[i][j]=1-DistanceCorrelation(entity1,entity2)
							break
					endswitch
				endfor
			endfor
			break
		case "JSD": // Square root of Jensen-Shannon Divergence.  Each column of 'data' should be a probability distribution (or histogram).  
		case "Bhattacharya":
		case "Hellinger":
		case "Renyi":
			make /free/n=(bins) hist1=0,hist2=0
			for(i=0;i<entities;i+=1)
				prog("i",i,entities)
				wave entity1=col(data,i)
				histogram /b={minBin,binWidth,bins}/c entity1,hist1
				for(j=0;j<i;j+=1)
					distances[i][j]=distances[j][i]
				endfor
				distances[i][i]=0
				for(j=i+1;j<entities;j+=1)
					wave entity2=col(data,j)
					histogram /b={minBin,binWidth,bins}/c entity2,hist2
					strswitch(method)
						case "JSD": // Square root of Jensen-Shannon Divergence.  Each column of 'data' should be a probability distribution (or histogram).  
							distances[i][j]=sqrt(JSDivergence(hist1,hist2))
							break
						case "Bhattacharya":
							distances[i][j]=BhattacharyaDistance(hist1,hist2)
							break
						case "Hellinger":
							distances[i][j]=HellingerDistance(hist1,hist2)
							break
						case "Renyi":
							distances[i][j]=RenyiDivergence(hist1,hist2,alpha,symmetric=1)
							break
					endswitch
				endfor
			endfor
			break
		case "Jaccard": // Jacard distance.  'Data' should be a joint probability distribution.  
			make /free/n=(bins) bins1=minBin+p*binWidth
			duplicate /free bins1,bins2
			for(i=0;i<entities;i+=1)
				prog("i",i,entities)
				wave entity1=col(data,i)
				for(j=0;j<i;j+=1)
					distances[i][j]=distances[j][i]
				endfor
				distances[i][i]=0
				for(j=i+1;j<entities;j+=1)
					wave entity2=col(data,j)
#if exists("jointhistogram")==4
					jointhistogram /c /xbwv=bins1 /ybwv=bins2 entity1,entity2
#endif
					wave m_jointhistogram
					setscale /i x,minBin,maxBin,m_jointhistogram
					setscale /i y,minBin,maxBin,m_jointhistogram
					if(i==0 && j==1)
						//duplicate /o m_jointhistogram poop
						//abort
					endif
					distances[i][j]=JaccardDistance(m_jointhistogram,finite=1)
				endfor
			endfor
		default:
			printf "No such method: %s\r",method
			break
	endswitch
	return distances
end

Function /wave Correlation(waves,[kind,circ,noRotate])
	wave /wave waves
	string kind // 'degc', 'covar', or 'corr'.  
	variable circ // Pad the ends (0) or do it circularly (1).  
	variable noRotate // do not rotate so that 0 lag is in the center of the wave.  
	
	wave w1=waves[0]
	wave w2=waves[1]
	kind=selectstring(paramisdefault(kind),kind,"degc")
	if(stringmatch(getwavesdatafolder(w1,2),getwavesdatafolder(w2,2)))
		string name=nameofwave(w1)+"_"+kind
	else
		name=nameofwave(w1)+"_"+nameofwave(w2)+"_"+kind
	endif
	make /o $name /wave=result
	variable scale=dimdelta(w1,0)
	
	strswitch(kind)
		case "corr":
			if(!circ)
				duplicate /o w2,result
				Correlate w1,result
				result/=numpnts(w1)
      				// or
      				// MatrixOp /free matrix=w1 x w2^t
				// result = sum of each diagonal in matrix.  
			else
				// duplicate /o w2,result
				// Correlate /C w1,result
      				// or
      				MatrixOp /o result=correlate(w1,w2,0)/numpoints(w1)
			endif
			break
		case "covar":
			if(!circ)
				// duplicate /o w2,result
				// Correlate /NODC w1,result 
      				// or
      				MatrixOp /o result=crossCovar(w1,w2,0)/numpoints(w1)
			else
				// duplicate /o w2,result
				// Correlate /NODC /C w1,result
      				// or
      				MatrixOp /o result=correlate(subtractMean(w1,0),subtractMean(w2,0),0)/numpoints(w1)
			endif
			break
		case "degc":
			if(!circ)
				// variable norm=sqrt(variance(w1)*variance(w2)*numpnts(w1)*numpnts(w2))
				// duplicate /o w2,result
				// Correlate /NODC w1,result; result/=norm
      				// or
      				MatrixOp /o result=crossCovar(w1,w2,1)
			else
				// variable norm=sqrt(variance(w1)*variance(w2)*numpnts(w1)*numpnts(w2))
				// duplicate /o w2,result
				// Correlate /NODC /C w1,result; result/=norm     		
      				// or
      				MatrixOp /o result=correlate(subtractMean(w1,0),subtractMean(w2,0),0) x inv(sqrt(varcols(w1)*varcols(w2)*numpoints(w1)*numpoints(w2)))
      				// or 
      				// MatrixCorr /DEGC w1,w2 // Then sum the diagonals.  
      				// result = sum of each diagonal in M_degC.  
			endif
			break
		default:
			printf "Not a valid kind: %s [Correlation()].\r",kind
			return NULL
	endswitch
	if(circ && !noRotate)
		rotate (numpnts(result)-1)/2,result//variable newPoints=numpnts(result)-1
		//insertpoints 0,newPoints,result
		//result[0,newPoints-1]=result[p+newPoints+1]
	endif
	setscale /p x,0,scale,result
	if(!noRotate)
		setscale x,-rightx(result)/2,rightx(result)/2,result
	endif
	return result
End

// Computes the correlation function for waves in 'waves'.  
// Returns a numWave x numWaves x lag matrix.  
Function /wave CorrelationFunction(waves)
	wave /wave waves // A waves wave of 1D waves, or a single matrix of column waves.  Either way, in braces.  
	variable maxLag
	
	wave w=waves[0]
	if(wavetype(w,2)==2) // Free wave.  
		dfref df=getdatafolderdfr()
	else
		df=getwavesdatafolderdfr(w)
	endif
	wave wavesMatrix=W2Matrix(waves)
	string name=stringbykey("NAME",note(wavesMatrix))
	if(stringmatch(name,"*_free_*"))
		name="X"
	endif
	name=removeending(name,"_")
	variable points=dimsize(wavesMatrix,0)
	variable numWaves=dimsize(wavesMatrix,1)
	variable i,j
	for(i=0;i<numWaves;i+=1)
		matrixop /free col_i=col(wavesMatrix,i)
		for(j=0;j<numWaves;j+=1)
			matrixop /free col_j=col(wavesMatrix,j)
			wave oneCorr=Correlation({col_i,col_j},kind="degc",circ=1)
			if(i==0 && j==0)
				make /o/n=(numWaves,numWaves,numpnts(oneCorr)) df:$(name+"_corr") /wave=Correlation
			endif
			multithread Correlation[i][j][]=oneCorr[r]
		endfor
	endfor
	setscale /p z,0,dimdelta(w,0),Correlation
	return Correlation
End

threadsafe Function /wave CorrelationMatrix(waves[,shuffle])
	wave /wave waves // A waves wave of 1D waves, or a single matrix of column waves.  Either way, in braces.  
	variable shuffle
	
	wave w=waves[0]
	wave dataMatrix=W2Matrix(waves)
	
	return CorrMatrixFromDataMatrix(dataMatrix,shuffle=shuffle)
End

threadsafe Function /wave CorrMatrixFromDataMatrix(dataMatrix[,shuffle])
	wave dataMatrix
	variable shuffle
	
	if(shuffle)
		duplicate /free dataMatrix,shuffled
		variable i
		for(i=0;i<dimsize(shuffled,1);i+=1)
			//make /free/n=(dimsize(shuffled,0)) index=p,noise=gnoise(1)
			//sort noise,index
			//shuffled[][i]=dataMatrix[index[p]][q]
			make /free/n=(50) index=p,noise=gnoise(1)
			sort noise,index
			shuffled[][i]=dataMatrix[mod(p,200)+200*index[floor(p/200)]][q]
		endfor
		wave dataMatrix=shuffled
	endif
	matrixop /free w=syncCorrelation(dataMatrix)/sqrt(varcols(dataMatrix)^t x varcols(dataMatrix))
	return w
End

// Compute a correlation matrix stack out of correlation matrices from 'n' segments of the data matrix.  
threadsafe function /wave CorrelationMatrixStack(matrix,n)
	wave matrix
	variable n
	
	variable rows=dimsize(matrix,0)
	variable columns=dimsize(matrix,1)
	variable seg=round(rows/n)
	make /free/n=(columns,columns,n) w
	make /free/wave/n=(n) waves
	make /free/n=(n) dummy
	multithread waves=CorrMatrixFromDataMatrix(sub(matrix,{{p*seg,(p+1)*seg-1},{0,inf}}))
	dummy=setLayer(w,waves[p],p)
	return w
end

function /wave DeltaCorrelation(w1,w2[,interval,maxWidth])
	wave w1,w2
	variable interval // Interval between (Gaussian) smoothing widths, in x units.  
	variable maxWidth // Maximum (Gaussian) smoothing width, in x units.  
	
	interval=paramisdefault(interval) ? 1 : interval/dimdelta(w1,0) // One point.  
	maxWidth=paramisdefault(maxWidth) ? dimsize(w1,0)/2 : maxWidth/dimdelta(w1,0) // Half the width of the input. 
	variable maxPasses=maxWidth
	
	wave var1_=correlation({w1,w1},kind="covar",circ=0)
	wave var2_=correlation({w2,w2},kind="covar",circ=0)
	wave cov_=correlation({w1,w2},kind="covar",circ=0)
	variable mid=(numpnts(cov_)+1)/2
	make /o/n=0 deltaCorr
	make /o/n=0 widths
	duplicate /o/r=[mid-maxPasses,mid+maxPasses] var1_,var1
	duplicate /o/r=[mid-maxPasses,mid+maxPasses] var2_,var2
	duplicate /o/r=[mid-maxPasses,mid+maxPasses] cov_,cov
	mid=(numpnts(cov)-1)/2
	tic()
	smooth /f=0 1,var1,var2,cov
	variable i=0,cumPasses=1 
	do
		deltaCorr[i]={cov[mid]/sqrt(var1[mid]*var2[mid])}
		widths[i]={sqrt(cumPasses)}
		variable numPasses=interval
		cumPasses+=numPasses
		smooth /f=0 numPasses,var1,var2,cov
		i+=1
	while(cumPasses<maxPasses)
	toc()
	setscale /p x,0,1,deltaCorr,widths
	widths*=dimdelta(w1,0)
	differentiate deltaCorr /x=widths; deltaCorr*=-1
	return deltaCorr
end

function /wave DeltaCorrelation2(w1,w2[,interval,maxWidth])
	wave w1,w2
	variable interval // Interval between (Gaussian) smoothing widths, in x units.  
	variable maxWidth // Maximum (Gaussian) smoothing width, in x units.  
	
	interval=paramisdefault(interval) ? 1 : interval/dimdelta(w1,0) // One point.  
	maxWidth=paramisdefault(maxWidth) ? dimsize(w1,0)/2 : maxWidth/dimdelta(w1,0) // Half the width of the input. 
	variable maxPasses=maxWidth
	
	make /o/n=0 deltaCorr
	make /o/n=0 widths
	tic()
	duplicate /free w1,w1_
	duplicate /free w2,w2_
	variable i=0,cumPasses=1 
	do
		deltaCorr[i]={statscorrelation(w1_,w2_)}
		widths[i]={sqrt(cumPasses)}
		variable numPasses=interval
		cumPasses+=numPasses
		smooth /f=0 numPasses,w1_,w2_
		i+=1
	while(cumPasses<maxPasses)
	toc()
	setscale /p x,0,1,deltaCorr,widths
	widths*=dimdelta(w1,0)
	differentiate deltaCorr /x=widths; deltaCorr*=-1
	return deltaCorr
end

function /wave DeltaCorrelation3(w1,w2[,interval,maxWidth])
	wave w1,w2
	variable interval // Interval between (Gaussian) smoothing widths, in x units.  
	variable maxWidth // Maximum (Gaussian) smoothing width, in x units.  
	
	interval=paramisdefault(interval) ? 1 : interval/dimdelta(w1,0) // One point.  
	maxWidth=paramisdefault(maxWidth) ? dimsize(w1,0)/2 : maxWidth/dimdelta(w1,0) // Half the width of the input. 
	variable maxPasses=maxWidth
	
	make /o/n=0 deltaCorr
	make /o/n=0 widths
	tic()
	variable i=0,j,segments=1
	duplicate /free w1,w1_
	duplicate /free w2,w2_
	setscale /p x,0,1,w1_,w2_
	variable length,wLength=dimsize(w1,0)
	variable overlap=0.95
	deltaCorr[i]={statscorrelation(w1,w2)}
	for(length=2;length<=wLength;length*=1.2)
		prog("Length",length,wLength)
		variable length_=round(length)
		widths[i]={length_}
		variable corr=0
		segments=1+(wLength-length_)/(length_*(1-overlap))
		segments=round(segments)
		wave w=sub(w1_,{0,100})
		for(j=0;j<segments;j+=1)
			variable start=j*length_*(1-overlap)
			variable stop=start+length_-1
			stop=max(stop,start+10)
			wave a=sub(w1_,{start,stop})
			wave b=sub(w2_,{start,stop})
			corr+=statscorrelation(a,b)
		endfor
		corr/=segments
		deltaCorr[i]={corr}
		i+=1
	endfor
	toc()
	setscale /p x,0,1,deltaCorr,widths
	widths*=dimdelta(w1,0)
	differentiate deltaCorr /x=widths//; deltaCorr*=-1
	differentiate deltaCorr /x=widths//; deltaCorr*=-1
	return deltaCorr
end

// Generate a partial correlation matrix from a correlation matrix.  
// Adapted from http://www.tulane.edu/~PsycStat/dunlap/Psyc613/RI2.html.  
// or http://en.wikipedia.org/wiki/Partial_correlation#Using_matrix_inversion.  
Function /wave PartialCorrelationMatrix(corrMatrix)
	wave corrMatrix
	matrixinverse corrMatrix
	wave m_inverse
	if(wavetype(corrMatrix,2)==2) // Free wave.  
		string name="X"
	else
		name=getwavesdatafolder(corrMatrix,2)
		name=removeending(name,"corr")
		name=removeending(name,"corrMat")
		name=removeending(name,"_")	
	endif
	duplicate /o corrMatrix $(name+"_pCorrMat") /wave=pCorrMatrix
	pCorrMatrix=-m_inverse[p][q]/sqrt(m_inverse[p][p]*m_inverse[q][q])
	pCorrMatrix=(p==q) ? 1 : pCorrMatrix // Set diagonals to 1.  
	killwaves /z m_inverse
	return pCorrMatrix
End

// Generate a multiple correlation matrix from a correlation matrix.  
// Adapted from http://www.tulane.edu/~PsycStat/dunlap/Psyc613/RI2.html
Function /wave MultipleCorrelationMatrix(corrMatrix)
	wave corrMatrix
	matrixinverse corrMatrix
	wave m_inverse
	string name=getwavesdatafolder(corrMatrix,2)
	name=removeending(name,"corr")
	name=removeending(name,"corrMat")
	name=removeending(name,"_")	
	make /o/n=(dimsize(corrMatrix,0)) $(name+"_mulCorr") /wave=mulCorr
	mulCorr=sqrt(1-1/m_inverse[p][p])
	killwaves /z m_inverse
	return mulCorr
End

// Computes the partial correlation function up to lag 'maxLag' (in scaled units) for waves in 'waves'.  
// Uses a partial correlation matrix generated from the data waves and all lags of each data wave up to 'maxLag'.  
// Does not asymptotically agree with my implementation of PartialAutoCorrelationFunction (for autocorrelation).  
// This is probably because this controls for all lags from 0 to 'magLag', whereas PartialAutoCorrelationFunction 
//controls for all lags from 0 to T (with the returned function a function of T).  
Function /wave PartialCorrelationFunction(waves,maxLag[downSample])
	wave /wave waves // A waves wave of 1D waves, or a single matrix of column waves.  Either way, in braces.  
	variable maxLag
	variable downSample // Downsample the data for a faster correlation that can more easily fit into memory.  
	
	wave w=waves[0]
	if(wavetype(w,2)==2) // Free wave.  
		dfref df=getdatafolderdfr()
	else
		df=getwavesdatafolderdfr(w)
	endif
	wave wavesMatrix=W2Matrix(waves)
	string name=stringbykey("NAME",note(wavesMatrix))
	if(stringmatch(name,"*_free_*"))
		name="X"
	endif
	name=removeending(name,"_")
	
	setscale /p y,0,dimdelta(w,0),wavesMatrix
	if(!paramisdefault(downsample))
		resample /dim=0/down=(downsample) wavesMatrix
	endif
	variable points=dimsize(wavesMatrix,0)
	variable numWaves=dimsize(wavesMatrix,1)
	maxLag/=dimdelta(wavesMatrix,0) // Convert from x-scaling units to points.
	redimension /n=(-1,numWaves*maxLag) wavesMatrix
	wavesMatrix=wavesMatrix[mod(p-floor(q/numWaves)+points,points)][mod(q,numWaves)]
	//duplicate /o wavesMatrix poop
	deletepoints /m=0 0,maxLag,wavesMatrix // Delete the first 'lag' points because not enough of their history is known.  
	wave corrMat=CorrelationMatrix({wavesMatrix})
	wave pcorrMat=PartialCorrelationMatrix(corrMat)
	make /o/n=(numWaves,numWaves,maxLag) df:$(name+"_pcorr") /wave=PartialCorrelation=pcorrMat[p][q+numWaves*r]
	setscale /p z,0,dimdelta(wavesMatrix,0),PartialCorrelation
	return PartialCorrelation
End

// Computes the partial autocorrelation function up to lag 'maxLag' (in scaled units) for wave 'w'.  
// Adapted from http://dr-adorio-adventures.blogspot.com/2010/05/python-econometrics-levinson-durbin.html
// Does not asymptotically agree with my implementation of PartialCorrelationFunction (for autocorrelation).  
// This is probably because this controls for all lags from 0 to T (with the returned function a function of T), 
// whereas PartialCorrelationFunction controls for all lags from 0 to 'maxLag'.  
Function /wave PartialAutoCorrelationFunction(w,maxLag[,corr])
	wave w
	variable maxLag
	wave corr // Optionally specify an existing autocorrelation function.  
	
	maxLag/=dimdelta(w,0) // Convert from x-scaling units to points.  
	if(paramisdefault(corr))
		wave rr=Correlation({w},kind="degc",circ=1,noRotate=1)
	else
		wave rr=corr
	endif
	//duplicate /o rr,$"rr"
	make /free/n=(maxLag,maxLag) A=0
	make /free/n=(maxLag) V=0
    	A[0][0] = rr[0]
    	A[1][1] = rr[1]/rr[0]
    	V[1] = rr[0] - A[1][1] * rr[1]
	
	variable i,j
	for(i=2;i<=maxLag;i+=1)
		variable summ=0
		for(j=1;j<i;j+=1)
			summ+= A[j][i-1] * rr[i-j]
		endfor
		A[i][i]=(rr[i]-summ) / V[i-1]
		for(j=1;j<i;j+=1)
			A[j][i] = A[j][i-1] - A[i][i] * A[i-j][i-1]
		endfor
		V[i] = V[i-1] * (1 - A[i][i]^2)
	endfor
	string name=getwavesdatafolder(w,2)
	make /o/n=(maxLag) $(name+"_pautocorr") /wave=prr=A[p][p]
	copyscales /p rr,prr 
	return prr
End

// Signal and Noise Correlation.  
//make /o/n=(200,100) test1=gnoise(1),test2=gnoise(1)
//matrixop /o totalCov=mean(test1*test2)-mean(test1)*mean(test2); print totalCov[0]
//  -0.00995685
//matrixop /o signalCov=mean(meancols(test1)*meancols(test2))-mean(test1)*mean(test2); print signalCov[0]
//  -0.000776673
//matrixop /o noiseCov=mean(test1*test2) - mean(meancols(test1)*meancols(test2)); print noiseCov[0]
//  -0.00918018
//matrixop /o totalCov=(subtractmean(test1,0) . subtractmean(test2,0))/20000; print totalCov[0]
//  -0.00995685
//matrixop /o signalCov=(subtractmean(meancols(test1),0) . subtractmean(meancols(test2),0))/100; print signalCov[0]
//  -0.000776673
//matrixop /o noiseCov=(subtractmean(test1,1) . subtractmean(test2,1))/20000; print noiseCov[0]
//  -0.00918018

threadsafe Function FisherZ(rr)
	variable rr // Pearson's correlation coefficient r.  
	
	return ln((1+rr)/(1-rr))/2
End

Function FisherZsem(n)
	variable n
	
	return 1/(sqrt(n-3))
End

Function FisherP(rr,n)
	variable rr // Pearson's correlation coefficient r.  
	variable n // Number of sample points.  
	
	variable zz=FisherZ(rr)/FisherZsem(n)
	variable pp=statsnormalcdf(zz,0,1)
	return pp
End

// Harmonic Mean.  
Function HMean(w)
	wave w 
	duplicate /free w,w1
	w1=1/w
	return 1/sum(w1)
End

Function CircularCorrelation(w1,w2)
	wave w1,w2
	
	variable n2=numpnts(w1)^2
	matrixop /free num=4*(sum(cos(w1)*cos(w2))*sum(sin(w1)*sin(w2))-sum(cos(w1)*sin(w2))*sum(sin(w1)*cos(w2)))
	matrixop /free denom=sqrt((n2-powR(sum(cos(2*w1)),2)-powR(sum(sin(2*w1)),2))*(n2-powR(sum(cos(2*w2)),2)-powR(sum(sin(2*w2)),2)))
	return num[0]/denom[0]
End

Function StatsCircularCorrelationTest2(n[,iter])
	variable n,iter
	
	iter=paramisdefault(iter) ? 1000 : iter
	variable i
	make /o/n=(iter) test3=nan
	for(i=0;i<iter;i+=1)
		make /o/free/n=(n) test1=enoise(pi),test2=enoise(pi)
		StatsCircularCorrelationTest /q/paa/alph=0.01 test1,test2
		wave W_StatsCircularCorrelationTest
		variable rr=W_StatsCircularCorrelationTest[%raa]
		test3[i]=rr
	endfor
	ecdf(test3)
End

#if !exists("StatTTest")
       Function StatTTest(num,wave1,wave2)
               Variable num
               Wave wave1,wave2
               DoAlert 0,"The XOP containing StatTTest has not been loaded or is not compatible with this platform."
       End

       Function StatPearsonTest(wave0,wave1,wave2)
               Wave wave0,wave1,wave2
               DoAlert 0,"The XOP containing StatPearsonTest has not been loaded or is not compatible with this platform."
       End
#endif

// Lilliefors test for normality.  Less normal samples have smaller p-values.  
// This uses an analytic approximation (StatsLillieforsCDF) that is only accurate for small p-values, i.e. cases where you might reject the null hypothesis.  
function StatsLillieforsTest(w)
	wave w
	
	variable n=numpnts(w)
	variable Dmax=LillieforsDmax(w)
	return StatsLillieforsCDF(n,Dmax)
end

function LillieforsDmax(w)
	wave w
	
	wavestats /q w
	variable /g temp_avg=v_avg, temp_sdev=v_sdev
	if(v_sdev>0)
		statskstest /q/cdff=gaussianUserCDF w
		wave w_ksresults
		variable result=w_ksresults[%D]
	else
		result=nan
	endif
	return result
end

function gaussianUserCDF(inX)
	variable inX
	
	nvar temp_avg,temp_sdev
	return statsNormalCDF(inX,temp_avg,temp_sdev)
	killvariables /z temp_avg,temp_sdev
end

// Returns the upper tail p-value for the Lilliefors distribution.  
// http://www.jstor.org/stable/2684607
function StatsLillieforsCDF(n,Dmax)
	variable n // Sample size.  
	variable Dmax // Kolmogorov test statistic.  
	
	variable pp=nan
	if(n<5)
		printf "At least 5 samples are needed for the Lilliefors test.  You provided only %s.\r",n
	else
		if(n>100)
			Dmax=Dmax*(n/100)^0.49
			n=100
		endif
		pp=exp(-7.01256*Dmax^2*(n+2.78019) + 2.99587*Dmax*(n+2.78019)^0.5 - 0.122119 + 0.974598/n^0.5 + 1.67997/n)
	endif
	return pp
end

// Returns the number of significant p-values at threshold 'alpha' after applying the Simes procedure for False Discovery Rate.  
// http://en.wikipedia.org/wiki/False_discovery_rate
function /wave FalseDiscoveryTransform(pValues)
	wave pValues
	
	variable m=numpnts(pValues)
	make /free/n=(m) index=p
	redimension /n=(m)/e=1 pValues
	sort pValues,index,pValues
	make /free/n=(m) index2=p
	pValues*=(m/(p+2))
	sort index,pValues
	return pValues
end

// Returns the number of significant p-values at threshold 'alpha' after applying the Simes procedure for False Discovery Rate.  
// http://en.wikipedia.org/wiki/False_discovery_rate
function FalseDiscoveryRate(pValues,alpha)
	wave pValues
	variable alpha
	
	duplicate /free pValues,pValues_
	sort pValues_,pValues_
	variable m=numpnts(pValues_)
	pValues_*=(m/alpha)
	extract /free/indx pValues_,indices,pValues_<(p+1)
	if(numpnts(indices))
		return 1+wavemax(indices)
	else
		return 0
	endif
end

// Returns the fraction of significant p-values at each threshold alpha.  
function /wave FDRVsAlpha(pValues[,logStepSize])
	wave pValues
	variable logStepSize
	
	logStepSize=paramisdefault(logStepSize) ? 1/5 : logStepSize
	variable i,logUnits=4,points=1+ceil(logUnits/logStepSize)
	make /free/n=(points) FDR
	setscale /I x,-logUnits,0,FDR
	variable denom=numpnts(pValues)
	for(i=0;i<numpnts(FDR);i+=1)
		variable alpha=10^(dimoffset(FDR,0)+i*dimdelta(FDR,0))
		variable num=FalseDiscoveryRate(pValues,alpha)
		FDR[i]=num/denom
	endfor
	return FDR
end

Function StepFinder(data,threshold,winsize)
  wave data
  variable threshold // A threshold t-value for detecting a step. 
  variable winsize // Number of samples on each side of a putative step to compare.   
  make /free/n=(numpnts(data)) tValues=nan
  make /free/n=(winsize) wBefore,wAfter
  variable i=winsize // 'i' will be the location of the putative step.  
  do // Slide window until a step is found in the source wave 'w'.  
    wBefore = data[p+i-winsize]
    wAfter = data[p+i]
    statsttest/Q wBefore,wAfter
    wave w_statsttest
    tValues[i]=w_statsttest[8] // t-values for the null hypothesis that both sides have equal means.  
    i+=1
  while (i<(numpnts(data)-winsize)) //Stop after the population changed.  
  //display tValues
  make /o/n=0 stepsUp,stepsDown
  findlevels /q/d=stepsUp/edge=1 tValues,-threshold // Find crossings down through t=-threshold (steps up).  
  findlevels /q/d=stepsDown/edge=2 tValues,threshold // Find crossings up through t=threshold (steps down).  
  //edit stepsUp,stepsDown
End

#ifdef Rick
// Makes an autocorrelogram of a wave, and names gives the destination wave the suffix 'autocorr'.    
Function /WAVE AutoCorr(w)
	Wave w
	Duplicate /o w $(CleanupName(NameOfWave(w)+"_autocorr",0)) /WAVE=AutoCorr
	Correlate /AUTO /NODC AutoCorr,AutoCorr
	return AutoCorr
End
#endif

Function StatsContingencyTest2(observed)
	wave observed // Matrix of counts.  Must be integer counts, not probabilities.  
	matrixop /free expected=(sumcols(observed)^t x sumcols(observed^t) / sum(observed))^t
	matrixop /free colCounts=sumcols(observed)
	matrixop /free rowCounts=sumcols(observed^t)
	rowCounts=rowCounts>0 // Rows with non-zero count.  
	colCounts=colCounts>0 // Columns with non-zero count.  
	variable df=(sum(rowCounts)-1)*(sum(colCounts)-1)
	matrixop /o chiSquare =sum(replacenans(powR(observed - expected,2)/expected,0))
	return StatsChiCDF(chiSquare[0],df)
End

Function RelJointEntropy(matrix[,finite])//,w0,w1[,count,iter])
	wave matrix // The actual 2D joint histogram.  
	variable finite
	//wave w0,w1 // The actual 1D histograms.  
	//variable count // The number of data points (samples) in each 1D histogram.  Default is the sum of a 1D histogram.   
	//variable iter // Number of iterations of bootstrap 
	
//	count=paramisdefault(count) ? sum(w0) : count
//	iter=paramisdefault(iter) ? 100 : iter	
//	if(sum(w0) != sum(w1))
//		//printf "Each histogram needs to have the same total count, representing the same data set."
//		//return NaN
//	endif
//	variable i,j,length0=numpnts(w0),length1=numpnts(w1)
//	if(length0 != dimsize(matrix,0) || length1 != dimsize(matrix,1))
//		printf "The size of the1D histograms must be the same as the number of rows and columns, respectively, in the joint histogram."
//		return NaN
//	endif
//	
//	duplicate /free w0,w0cdf
//	duplicate /free w1,w1cdf
//	integrate /p w0cdf
//	integrate /p w1cdf
//	w0cdf/=w0cdf[inf]
//	w1cdf/=w1cdf[inf]
//	w0cdf=statsnormalcdf(x,40,5)
//	w1cdf=statsnormalcdf(x,60,7)
//	
//	make /free/n=(iter) Entropies=NaN
//	for(j=0;j<iter;j+=1)
//		make /free/n=(length0,length1) bootMatrix
//		for(i=0;i<count;i+=1)
//			variable xx=1+binarysearch(w0cdf,abs(enoise(1)))
//			variable yy=1+binarysearch(w1cdf,abs(enoise(1)))
//			bootMatrix[xx][yy]+=1
//		endfor
//		Entropies[j]=RelEntropy(bootMatrix)
//	endfor
//	wavestats /q Entropies

	matrixop /free w0=sumcols(matrix)
	matrixop /free w1=sumrows(matrix)
	variable actual=Entropy(matrix,finite=finite,rel=1)
	variable marginal=Entropy(w0,finite=finite,rel=1)+Entropy(w1,finite=finite,rel=1)
	printf "Actual joint entropy = %.2f.  Marginal joint entropy = %.2f.\r",actual,marginal//v_avg
	return actual-marginal
End

// Estimates entropy using the NSB method, which is very good when the data is undersampled.  
// Works correctly when N << K.  
// PHYSICAL REVIEW E 69, 056111 (2004)
Function EntropyNSB(w[,finite,rel])
	wave w // Counts.  
	variable finite // Corrects for finite bins.  When N > K is possible you need to correct for the fact that the number of bins with non-zero counts -> 0 as N -> inf.   
	variable rel // Makes it relative to the maximum entropy for this number of bins.  
	
	variable N=sum(w) // Observations.
	variable K=numpnts(w)  
	make /free/n=(numpnts(w)) nonzero=w>0
	variable K1=sum(nonzero) // Number of bins with non-zero counts.  
	variable nats=-digamma(1) - ln(2) + 2*ln(N) - digamma(N-K1)
	variable bits=nats/ln(2)
	if(finite)
		bits+=MaxEntropy(N,K,aprx=1)-log2(N)
	endif
	if(rel)
		bits-=log2(K)
	endif
	return bits
End

// Computes the entropy from the raw observation values (not the histogram) using the digamma function.  
// Great for large N; does not require binning.  Data must not be degenerate.  
Function DiGammaEntropy(w)
	wave w // One-dimensional data.     
	
	duplicate /free w,diffs
	sort diffs,diffs
	differentiate /meth=1 diffs
	variable N=numpnts(w)
	redimension /n=(N-1) diffs
	diffs=ln(diffs)
	variable nats=mean(diffs) + digamma(N) - digamma(1)
	return nats/ln(2)
End

// Computes entropy of a wave 'w' of counts, relative to a wave in which all values have probability 1/numpnts(w).  
// Result will range from 0 to log2(numpnts(w)).  'finite' corrects for finite data.  
Function Entropy(w,[finite,rel])
	wave w
	variable finite // do not use unless the wave w is a histogram of counts, i.e. all integers.  
	variable rel // Relative to the maximum entropy for this number of bins.  

	duplicate /free w,w1
	w1=limit(w1,0,Inf) // Set negatives to zero.  There shouldn't really be negatives, but there might be small ones due to spline interpolation.  
	variable summ=sum(w)
	w1/=summ // Force the sum to be 1 so that this is sensible as a probability distribution.  
	w1=(w1==0) ? 0 : w1*log2(w1) // Compute p*log2(p), except where p=0 in which case just set to 0.  
	variable h=-sum(w1)
	
	variable numBins=numpnts(w)
	if(finite)
		variable count=sum(w) // Number of data points.  
		h-=MaxEntropy(count,numBins)
		if(!rel)
			h+=log2(numBins)
		endif
	elseif(rel)
		h-=log2(numBins)
	endif
	return h
End

// Entropy of a uniform distribution, i.e. the most positive entropy, for 'n' samples taken from a uniform distribution and placed into 'b' histogram bins.   
// Arises because bins with counts of 0 and 1 will both lead to p*log2(p)=0, so a sparse histogram with tend to have entropy nearer to zero than the underlying distribution.  
// In the limit of n>>b, this is just log2(b), which corresponds to infinite measurements but finite sampling accuracy.   
// In the limit of b>>n, this is just log2(n), which corresponds to infinite sampling accuracy but finite measurements.  
//We use this to compute entropy relative to a uniform distribution.  
Function MaxEntropy(n,b[,aprx])
	variable n // number of samples.  
	variable b // number of bins.  
	variable aprx // Use a fast approximation.  Discovered by Eureqa.  
	
	if(aprx)
		variable nats=(ln(n)*ln(b))/ln(n+b) // Possibly ln(n+b-sqrt(n)) in the denominator.  
		return nats/ln(2)
	else
		//make /free/n=(n+1) summTerms=binomial(n,x)*(1/b)^x*(1-1/b)^(n-x)
		make /free/n=(n+1) summTerms=statsbinomialpdf(x,1/b,n)
		//summTerms=numtype(summTerms) ? gauss(x,n/b,sqrt(n/b)) : summTerms // Make a gaussian approximation when n is large and statsbinomialpdf fails.  
		summTerms*=x*log2(x)
		summTerms=numtype(summTerms) ? 0 : summTerms // Correct for any other bugs in statsbinomialpdf, and for the 0*log2(0) case.  
		return -b*sum(summterms)/(n+1)+log2(b)
	endif
End

// Computes entropy of a data (not counts) wave 'w', relative to the number of bins used to compute the probability distribution.  
Function /wave EntropyVsBinSize(w,minBinSize[,inc,minVal,maxVal])
	wave w
	variable minBinSize // Smallest histogram bin size to use. 
	variable inc // Power increment to increase the bin size by.  For example, inc=2 will double the bin size with each calculation.   
	variable minVal,maxVal // Low and high range for computing the histogram.  By default the min and max of 'w' will be used, however this is not ideal.  
	
	inc=(paramisdefault(inc) || inc<1) ? 1.1 : inc
	wavestats /q/m=1 w
	minVal=paramisdefault(minVal) ? v_min : minVal
	maxVal=paramisdefault(maxVal) ? v_max : maxVal
	make /o/n=0 $(getwavesdatafolder(w,2)+"_ent") /wave=ent=nan
	setscale /p x,log2(minBinSize),log2(inc),ent
	variable binSize
	variable maxBinSize=(maxVal-minVal)/2
	for(binSize=minBinSize;binSize<=maxBinSize;binSize*=inc)
		make /o/free hist
		variable numBins=ceil((maxVal-minVal)/binSize)
		histogram /b={minVal,binSize,numBins} w,hist
		ent[numpnts(ent)]={Entropy(hist,rel=1)}
	endfor
	return ent
End

// Estimate mutual information using the Kraskov et al. method:  
// http://arxiv.org/abs/cond-mat/0305641
function KraskovMutualInformation(w[,method,k])
	wave w // 'dims' columns of data.  Each row should correspond to 'dims' simultaneous observations.  
	variable method // 1 or 2.  
	variable k // Use the kth nearest neighbor.  

	//make /o/n=(100,100,2) test=gnoise(1); make /o/n=(100,100) test2=3
	//imagetransform /O/P=0/INSW=test2 insertZPlane,test
	//abort
	
	method=paramisdefault(method) ? 1 : method	
	k=paramisdefault(k) ? 1 : k
	variable N=dimsize(w,0)
	variable i,dims=dimsize(w,1)
	variable MI=nan
	
	make /o/n=(N,N,dims) $uniquename("distances",1,0) /wave=distances=abs(w[p][r]-w[q][r]) // Distances between points along each dimension.  Global wave used here because ImageTransform /O does not work with free waves.  
	imagetransform /meth=1 zProjection distances // Distance in 'dims'-dimensional space is the maximum of the distances in each dimension.  
	wave m_zProjection
	imagetransform /O/P=0/INSW=m_zprojection insertZPlane,distances // The maximum distances is now the zeroth layer (plane) of the distances matrix.  
	for(i=0;i<N;i+=1)
		imagetransform /PTYP=1/P=(i) getPlane distances
		wave m_imageplane
		sortmatrix(m_imageplane,1,0) // Sort so that the values of the distance (in the full space) are put in order, from nearest to farthest.  
		distances[][i][]=m_imageplane[p][r]
		//imagetransform /PTYP=1/P=(i)/D=m_imageplane setPlane distances
	endfor
		
	if(method==1)
		MI=digamma(k) + (dims-1)*digamma(N)
		make /free/n=(N,N,dims) neighbors=(p==q) ? 0 : (distances[p][q][r+1]<distances[k][q][0]) // 1 if it is nearer (in the subspace) than the kth nearest neighbor (in full space), 0 if it is not.  
	elseif(method==2)
		MI=digamma(k) + (dims-1)*digamma(N) - (dims-1)/k
		make /free/n=(N,N,dims) neighbors=(p==q) ? 0 : (distances[p][q][r+1]<=distances[k][q][r+1]) // 1 if it is nearer (in the subspace) than the projection (in the subspace) of the kth nearest neighbor (in full space), 0 if it is not.  
	endif
	
	for(i=0;i<dims;i+=1)
		matrixop /free numNeighbors=sumcols(layer(neighbors,i)) // The number of points nearer (in dimension i) than the projection (in the subspace) of the kth nearest neighbor (in the full space), for each point.  
		if(method==1)
			numNeighbors=digamma(1+numNeighbors)
		elseif(method==2)
			numNeighbors=digamma(numNeighbors)
		endif
		MI-=mean(numNeighbors) // Subtract off the mean of the digamma function of the number of such points.    
	endfor
	killwaves /z distances
	
	return MI///ln(2)
end

function /wave DarbellayMutualInformation(w[,rr,ss,d,show,depth,currX,currY])
	wave w
	variable rr // Number of partitions per iteration, usually 2.  
	variable ss // Number of partitions for testing whether further partitions should be made.  Must be >= rr.  
	variable d // KL-divergence criterion for further subpartioning.  
	variable show // Show the partioning graphically.  
	variable depth // Recursion depth.  
	variable currX,currY // Current bins (from calling function)
	
	rr=paramisdefault(rr) ? 2 : rr
	ss=paramisdefault(ss) ? rr : ss
	d=paramisdefault(d) ? 0 : d // 0 is a bad choice as the KL-divergence will always be > 0, so the subpartitoning will continue until the count is either 1 or 0 in every bin.  
	
	variable N=dimsize(w,0)
	variable dims=dimsize(w,1)
	variable iter=0,i,j,dim
	
	// Initialize boundaries.  
//	make /free/n=(rr,2,dims) boundaries // 2 is for a left and right boundary.  
//	for(dim=0;dim<dims;dim+=1)
//		wave col=col(w)
//		wavestats /q col
//		variable range=v_max-v_min
//		variable cushion=range/2
//		boundaries[][0][dim]=v_min-cushion+p*(range+2*cushion)/rr // Left boundary.  
//		boundaries[][1][dim]=v_min-cushion+(p+1)*(range+2*cushion)/rr // Right boundary.  
//	endfor
	
	wave xx_=col(w,0), yy_=col(w,1)
	wavestats /q xx_; wavestats /q yy_
	sort xx_,xx_; sort yy_,yy_
	setscale /I x,0,1,xx_,yy_
	variable cushion=0.1
	make /free/n=(rr+1) xBins=xx_(p/rr)-cushion*(xx_(1)-xx_(0)) // Would like to start with 2 bins (3 points in xBins), but JointHistogram is not allowing it.  
	make /free/n=(rr+1) yBins=yy_(p/rr)-cushion*(yy_(1)-yy_(0))
	make /free/n=(N) dummy=p
	
	// Adaptively modify boundaries.  
	wave xx=col(w,0), yy=col(w,1) // Note no underscore, i.e. not sorted.  
	duplicate /free xBins,xBinsNew
	duplicate /free yBins,yBinsNew
#if exists("jointhistogram")==4
	jointhistogram /xbwv=xBins /ybwv=yBins xx,yy
#endif
	wave m_jointhistogram
	redimension /n=(numpnts(xBins)-1,numpnts(yBins)-1) m_jointhistogram // Get rid of the last bins until A.G. fixes JointHistogram.  
	StatsContingencyTable /ALPH=0.05 /Q m_jointhistogram
	wave W_ContingencyTableResults
	variable pval=W_ContingencyTableResults[%P_Value]
	if(pval<0.05)
		for(i=0;i<numpnts(xBins)-1;i+=1)
			for(j=0;j<numpnts(yBins)-1;j+=1)
				extract /free xx,xx2,(xx_[p]>=xBins[i]) && (xx_[p]<xBins[i+1]) && (yy_[p]>=yBins[j]) && (yy_[p]<yBins[j+1])
				if(numpnts(xx2)<4)
					continue
				endif
				extract /free yy,yy2,(xx_[p]>=xBins[i]) && (xx_[p]<xBins[i+1]) && (yy_[p]>=yBins[j]) && (yy_[p]<yBins[j+1])
				make /free/n=(numpnts(xx2),2) w2=(q==0) ? xx2[p] : yy2[p]
				wave partitions=DarbellayMutualInformation(w2,rr=rr,ss=ss,d=d,depth=depth+1,currX=i,currY=j)
				wave xBins2=col(partitions,0)
				wave yBins2=col(partitions,1)
				concatenate /np {xBins2},xBinsNew
				concatenate /np {yBins2},yBinsNew
			endfor
		endfor
	else
		variable finish=1
		redimension /n=0 xBinsNew,yBinsNew
	endif 
//	if((show + finish) >= 2)
//		dowindow /k DarbellayPartition
//		display /k=1/n=DarbellayPartition w[][1] vs w[][0] as "Darbellay Partition"
//		setdrawenv xcoord=bottom,ycoord=prel,save
//		for(i=0;i<numpnts(xBins);i+=1)
//			drawline xBins[i],0,xBins[i],1
//		endfor
//		setdrawenv xcoord=prel,ycoord=left,save
//		for(i=0;i<numpnts(yBins);i+=1)
//			drawline 0,yBins[i],1,yBins[i]
//		endfor
//		ModifyGraph mode=2,lsize=2
//		doupdate
//		if(show>=2)
//			sleep /s 1
//		endif
//	endif
	
	make /free/n=(numpnts(xBinsNew),2) partitions=(q==0) ? xBinsNew[p] : yBinsNew[p]
	return partitions
end

function MutualInformation(w[,finite])
	wave w // Joint pdf.  
	variable finite // Correct for finite data.  
	
	duplicate /free w,w1
	w1=w1<0 ? 0 : w1 // Set negatives to zero.  There shouldn't really be negatives, but there might be small ones due to spline interpolation.  
	matrixop /free marginal1=sumcols(w1) // Marginal probability of column variable.  
	matrixop /free marginal2=sumcols(w1^t) // Marginal probability of row variable.  
	return Entropy(marginal1,finite=finite) + Entropy(marginal2,finite=finite) - Entropy(w,finite=finite)
end

function shorth(data,alpha)
	wave data
	variable alpha
	
	duplicate /free data,sorted
	sort data,sorted
	variable n=numpnts(data)
	alpha*=n
	make /o/n=(n/2) shorths=sorted[p+alpha]-sorted[p]
	wavestats /q/m=1 shorths
	variable meann=mean(sorted,v_minloc,v_minloc+n/2)
	return meann
end

Function IntNoise(num)
	Variable num
	
	return floor(abs(enoise(num)))
End

Function /WAVE Subset(Wav,num)
	Wave Wav
	Variable num
	
	Make /o/FREE/n=(numpnts(Wav)) Index=x, Randos=enoise(1000)
	Sort Randos,Index
	Extract /FREE Wav,SubsetWave,Index<num
	return SubsetWave
End

Function SortDims(Wav,dim)
	Wave Wav
	Variable dim
	
	Variable i
	switch(dim)
		case 0: // Sort each row independently.
		  	for(i=0;i<dimsize(Wav,dim);i+=1)
				MatrixOp /O myRow=row(Wav,i)
				Sort myRow,myRow
				Wav[i][]=myRow[q]
			endfor
			break
		case 1: // Sort each column independently.  
			for(i=0;i<dimsize(Wav,dim);i+=1)
				MatrixOp /O myCol=col(Wav,i)
				Sort myCol,myCol
				Wav[][i]=myCol[p]
			endfor
			break
		default:
			DoAlert 0,"No such dimension "+num2str(dim)+" in wave "+NameOfWave(Wav)
			break
	endswitch
End

Function Percentile(Wav,percentile)
	Wave Wav
	Variable percentile // 0 through 100.  
	
	StatsQuantiles /Q/QW Wav
	Wave W_QuantileValues
	Duplicate /o Wav,TempWav
	Sort W_QuantileValues,W_QuantileValues,TempWav
	Variable value=TempWav[BinarySearch(W_QuantileValues,percentile)]
	KillWaves /Z TempWav
	return value
End

// Converts a wave into an empirical cumulative distribution function with "bins" centered.  
threadsafe Function /wave ECDF(w[,points])
	Wave w
	Variable points // Use interpolation to achieve a fixed number of points.  
	
	Extract /O w,w,numtype(w)==0 // Get rid of NaN, Inf, and -Inf.  
	Sort w,w
//#if exists("Interpolate2")
//	if(points)
//		if(!numpnts(w))
//			return $""
//		endif
//		String dest=GetWavesDataFolder(w,2)+"_ECDF"
//		Interpolate2 /N=(points) /Y=$dest w
//		Wave w=$dest
//	endif
//#endif
	SetScale /P x,0.5/numpnts(w),1/numpnts(w),w
	return w
End

Function /wave InverseCDF(w[,lo,hi,points])
	wave w
	variable lo,hi // Lo and Hi bounds for the data.  
	variable points // Points used to compute the cdf and inverse cdf.  
	
	WaveStats /Q w
	lo=ParamIsDefault(lo) ? V_min : lo
	hi=ParamIsDefault(hi) ? V_max : hi
	points=ParamIsDefault(points) ? 1000 : points
	duplicate /free w,w1
	wave cdf=ECDF(w1,points=points)
	wave icdf=Invert(cdf,lo=lo,hi=hi,points=points)
	return icdf
End

// Creates a wave that is the sum of each diagonal in the matrix.  Wraps around to get diagonals of equal length.  
Function SumDiags(Matrix)
	Wave Matrix
	
	Make /o/n=(dimsize(Matrix,0)) DiagWave=0
	Variable i,j
	for(i=0;i<dimsize(Matrix,0);i+=1)
		Variable summ=0
		for(j=0;j<dimsize(Matrix,1);j+=1)
			Variable row=mod(i+j,dimsize(Matrix,0))
			summ+=Matrix[row][j]
		endfor
		DiagWave[i]=summ
	endfor
End

// Running correlation.  This is an example I posted to the Igor mailing list to compute a running correlation (correlation in each time chunk) for two waves with unequal sampling rates.  
Function CorrPieces(Fast,Sloww)
	Wave Fast,Sloww
	Variable i
	
	Duplicate /o Fast,NewFast
	Duplicate /o Sloww,NewSlow
	Resample /DOWN=(60) NewFast
	//Now cut up each wave into 30 minute blocks.  Since they are now both at 0.166 Hz, a 30 minute block is 300 points.  Suppose you have 24 hours of data (48 blocks).
	Redimension /n=(300,48) NewFast,NewSlow
	MatrixOp /o NewFast=NormalizeCols(subtractMean(NewFast,1))
	MatrixOp /o NewSlow=NormalizeCols(subtractMean(NewSlow,1))
	
	Make /o/n=(dimsize(NewFast,1)) RunningCorr=0
	for(i=0;i<dimsize(NewFast,1);i+=1)
		MatrixOp /o FastChunk=col(NewFast,i)
		MatrixOp /o SlowChunk=col(NewSlow,i)
		MatrixOp /o CorrChunk=Correlate(FastChunk,SlowChunk,0)
		RunningCorr[i]=CorrChunk(0)
	endfor
End

// Computes a running value of the mean and variance in a width of 'width' points.    
// Uses reflection to compute values near the endpoints.  
// Do not use for low values of width, since I have glossed over the n vs n-1 issues.  
Function RunningStats(w,width)
	Wave w; Variable width
	if(mod(width,2)!=0)  
		width-=1 // Make width even.  
	endif
	Variable i
	Duplicate /o/D w, RS_Proxy, RunningMean, RunningVariance, RunningMax, RunningMin
	Variable points=numpnts(w)
	Redimension /n=(points+width) RS_Proxy
	Rotate (width)/2, RS_Proxy
	RS_Proxy[0,(width)/2]=w[(width)/2 - p - 1] // Reflection across the start.  
	RS_Proxy[points+(width)/2,points+width-1]=w[points-(p-width/2+2-points)] //Reflection across the end.  
	Duplicate /O/R=[0,width-1] RS_Proxy Seed,SeedSquared//,SeedIndex
	//SeedIndex=p
	WaveStats /Q Seed
	SeedSquared=Seed^2
	RunningMean[0]=V_avg
	RunningVariance[0]=(sum(SeedSquared)-V_avg^2)/V_npnts//sqrt((V_sdev^2)*numpnts(Seed)/(numpnts(Seed)-1))
	RunningMax[0]=V_max; Variable max_loc=V_maxloc
	RunningMin[0]=V_min; Variable min_loc=V_minloc
	Sort /R Seed,Seed
	for(i=1;i<numpnts(w);i+=1)
		Variable last_off=RS_Proxy[i-1]
		Variable next_on=RS_Proxy[i+width-1]
		Variable old_mean=RunningMean[i-1]
		Variable old_var=RunningVariance[i-1]
		Variable meann=((old_mean*width)-last_off+next_on)/width
		RunningMean[i]=meann
		Variable var=((width*(old_var+old_mean^2)-last_off^2+next_on^2)/width)-meann^2
		RunningVariance[i]=var
		if(i-max_loc>width/2)
			WaveStats /Q/R=[i-width/2,i+width/2] w
			RunningMax[i]=V_max
			max_loc=V_maxloc
		else
			if(next_on >= RunningMax[i-1])
			 	RunningMax[i]=next_on
			 	max_loc=i+width/2-1
			 else
			 	RunningMax[i]=RunningMax[i-1]
			endif
		endif
		if(i-min_loc>width/2)
			WaveStats /Q/R=[i-width/2,i+width/2] w
			RunningMin[i]=V_min
			min_loc=V_minloc
		else
			if(next_on <= RunningMin[i-1])
			 	RunningMin[i]=next_on
			 	min_loc=i+width/2
			 else
			 	RunningMin[i]=RunningMin[i-1]
			endif
		endif
	endfor
	// Faster but more confusing.  
	//RunningMean[1,]=(RunningMean[p-1]*width-RS_Proxy[p-1]+RS_Proxy[p+width-1])/width
	//RunningVariance[1,]=((width*(RunningVariance[p]+RunningMean[p-1]^2)-RS_Proxy[p-1]^2+RS_Proxy[p+width-1]^2)/width)-RunningMean[p]^2
	Duplicate /o RunningVariance RunningStDev
	RunningStDev=sqrt(RunningVariance)
	Duplicate /o RunningMax RunningContrast
	RunningContrast=RunningMax-RunningMin
	KillWaves /Z Seed,SeedSquared,RS_Proxy,RunningVariance
	CopyScales w, RunningMean,RunningStDev,RunningMax,RunningMin,RunningContrast
End

// Makes waves containing the mean and SEM of waveY when the values waveX fall within each of the ranges
// provided by the entries of rangeWave.  
// Output: RangeMeans,RangeSEMs
Function RangeStats(waveY,waveX,rangeWave[,logg,minn,maxx,med,binary,no_plot,stem])
	Wave waveY,waveX
	Wave /T rangeWave
	Variable logg // Logg equals 1 to do compute geometric mean and standard deviation.  
	Variable minn,maxx,med // Compute a bin minimum, maximum, or median instead of a mean.  
	Variable binary // Converts all non-zero data points to 1's before computing statistics.  
	Variable no_plot
	String stem // A stem for the names of the waves to be created.  
	if(ParamIsDefault(stem))
		stem="Range"
	endif
	Variable i
	Make /o/n=(numpnts(rangeWave)) $(stem+"Means"),$(stem+"SEMs"),$(stem+"Ns")
	Wave Means=$(stem+"Means"),SEMs=$(stem+"SEMs"),Ns=$(stem+"Ns")
	for(i=0;i<numpnts(rangeWave);i+=1)
		String range=rangeWave[i]
		Variable low=str2num(StringFromList(0,range,","))
		Variable high=str2num(StringFromList(1,range,","))
		if(numtype(high)==0)
			Extract /O waveY,$"tempRangeStats",waveX>=low && waveX<=high
		else // There was no high value, only a single number.  
			Extract /O waveY,$"tempRangeStats",waveX==low
		endif
		Wave Temp=tempRangeStats
		Ns[i]=numpnts(Temp)
		if(numpnts(Temp)>=1)
			if(binary)
				Temp=Temp ? 1 : 0
			endif
			WaveStats /Q Temp
			if(logg)
				Means[i]=GeoMean(Temp)
				SEMs[i]=LogStDev(Temp)/sqrt(V_npnts)
			elseif(minn)
				Means[i]=V_min
			elseif(maxx)
				Means[i]=V_max
			elseif(med)
				if(numpnts(Temp)>2)
					StatsQuantiles /Q Temp
					Means[i]=V_Median
					SEMs[i]=(V_IQR/2)/sqrt(V_npnts)
				else
					Means[i]=V_avg
					SEMs[i]=V_sdev/sqrt(V_npnts)
				endif
			else
				Means[i]=V_avg
				SEMs[i]=V_sdev/sqrt(V_npnts)
			endif
		else
			Means[i]=NaN
			SEMs[i]=NaN
		endif
	endfor
	if(no_plot==0)
		Display /K=1 Means vs RangeWave
		ErrorBars $NameOfWave(Means),Y wave=(SEMs,SEMs)
	elseif(no_plot==2) // Append
		Wave CatWave=XWaveRefFromTrace("",TopTrace())
		AppendToGraph Means vs CatWave
		ErrorBars $NameOfWave(Means),Y wave=(SEMs,SEMs)
	endif
End

// Averages across columns.  
Function MatrixAverage(mat[,subtractMean])
	wave mat
	variable subtractMean // Normalize each column to a mean of zero first.  
	
	String name=getwavesdatafolder(mat,2)
	if(subtractMean)
		matrixop /O $(name+"_mean")=sumcols(subtractmean(mat,1)^t)/numcols(mat)
		matrixop /O $(name+"_sem")=sqrt(varcols(subtractmean(mat,1)^t)/numcols(mat))
	else
		matrixop /O $(name+"_mean")=sumcols(mat^t)/numcols(mat)
		matrixop /O $(name+"_sem")=sqrt(varcols(mat^t)/numcols(mat))
	endif
	wave meann=$(name+"_mean"); redimension /n=(numpnts(meann)) meann
	wave sem=$(name+"_sem"); redimension /n=(numpnts(sem)) sem
	copyscales mat,meann,sem
	display /K=1 meann
	errorbars $nameofwave(meann),Y wave=(sem,sem)
End

// Sums all the integers from m through n, inclusive.  
Function Summation(m,n)
	Variable m,n
	Variable i,summ=0
	for(i=m;i<=n;i+=1)
		summ+=i
	endfor
	return summ
End

// Better than StatsBinomialCDF, doesn't fail for certain extreme inputs
function StatsBinomialCDF2(xx,pp,N)
	variable xx,pp,N
	
	variable result = (StatsBinomialCDF(xx,pp,N) +  StatsBinomialCDF(xx-1,pp,N))/2
	if(numtype(result))
		result = StatsNormalCDF(xx,pp*N,sqrt(N*pp*(1-pp)))
	endif
	return result
end

// Computes binomial statistics.  
Function BinoStats(successes,trials)
	Variable successes,trials
	Variable meann=successes/trials
	Variable SEM=sqrt(meann*(1-meann)/trials)
	printf "%f  +/- %f\r",meann,SEM
End

// Overwrites a wave with an Ornstein-Uhlenbeck process.  
Function OrnUhl(w,tau,sigma)
	Wave w // Template to be overwritten.  Can be 2D to generate many columns of O-U processes.  
	Variable tau // In x units.  0
	Variable sigma
	tau/=dimdelta(w,0)
	w[0][]=gnoise(sigma)
	w[1,][]=w[p-1][q]-w[p-1][q]/tau+gnoise(sigma) // gnoise(sigma) = sigma*gnoise(1)
End

Function OrnUhlPS(tau,sigma)
	Variable tau,sigma
	Variable i
	Make /o/n=100000 Test
	SetScale x,0,10,Test
	for(i=0;i<100;i+=1)
		OrnUhl(Test,tau,sigma)
		//Test=gnoise(1)
		//Integrate Test
		//Redimension /n=100000 Test
		FFT /MAGS /DEST=ftest2 Test
		Wave /C ftest2
		Make /o/n=(numpnts(ftest2)) ftest
		CopyScales ftest,ftest
		ftest=ftest2
		if(i==0)
			Duplicate /o ftest mean_ftest
			Wave mean_ftest
		else
			mean_ftest+=ftest
		endif
	endfor
	Duplicate /o mean_ftest,ftest,ftestx
	ftestx=x
	ftest=log(ftest)
	ftestx=log(ftestx)
	DeletePoints 0,1, ftest,ftestx
	Loess /DEST=Loessed /N=100 srcWave=ftest, factors={ftestx}
	Make /o/n=1000 Loessed2; SetScale x,0,5,Loessed2
	Loessed2=Loessed[BinarySearchInterp(ftestx,x)]
	Differentiate Loessed2 /D=diffF
End

// Test OrnUhl time constant.  
Function OrnUhlTest(tau,sigma)
	Variable tau,sigma
	Make /o/n=100 Iterations
	Variable points=10000
	Make /o/n=(points) Test221=0
	Variable i
	for(i=0;i<numpnts(Iterations);i+=1)
		Make /o/n=(points) Test=0
		Test=Test[p-1]-Test[p-1]/tau+gnoise(sigma) // gnoise(sigma) = sigma*gnoise(1)
		WaveStats /Q Test; Test-=V_avg
		Correlate Test,Test
		DeletePoints 0,points-1,Test
		Test221+=Test
	endfor
	Test221/=i
	Variable peak=Test221[0]
	Test221/=peak
	SetScale /P x,0,1,Test,Test221
	Variable V_FitOptions=4
	Make /o/n=3 W_Coef={0,1,1/tau}
	//Variable K1=sum(Test2)
	CurveFit/Q/N/H="110" exp, Test221[0,tau*2]/D
	return 1/W_Coef[2]
End

// High-resolution Index (from Supplemental Materials of Mokeichev et al., Neuron, 2004)  
Function HRI(wave1,wave2[,segment_duration])
	Wave wave1,wave2
	Variable segment_duration
	segment_duration=ParamIsDefault(segment_duration) ? 100 : segment_duration
	Variable num_segments=numpnts(wave1)/segment_duration
	if(numpnts(wave1) != numpnts(wave2))
		printf "wave1 and wave2 must have equal numbers of points.\r"
		return 0
	elseif(num_segments != round(num_segments))
		printf "There must be an integer number of segments.\r"
		return 0
	endif
	Duplicate /o wave1,waveA
	Duplicate /o wave2,waveB
	WaveStats /Q waveA
	waveA-=V_avg
	WaveStats /Q waveB
	waveB-=V_avg
	Variable i,Corr
	Make /o/n=(num_segments) TWave
	for(i=0;i<num_segments;i+=1)
		Duplicate /o/R=[i*segment_duration,(i+1)*segment_duration-1] waveA,$"waveAsegment"; Wave waveAsegment
		Duplicate /o/R=[i*segment_duration,(i+1)*segment_duration-1] waveB,$"waveBsegment"; Wave waveBsegment
		Corr=StatsCorrelation(waveASegment,waveBSegment)
		MatrixOp /o Multiplicand=mag(waveASegment-waveBSegment)/(mag(waveASegment)+mag(waveBSegment))
		TWave[i]=Corr*(1-Multiplicand[0])
	endfor
	Variable HRI1=(sum(TWave)^2)/sqrt(num_segments)
	MatrixOp /o HRI2=sqrt(Frobenius(waveA)*Frobenius(waveB))/sum(mag(waveA-waveB))
	Variable HRI=HRI1*HRI2[0]
	KillWaves /Z waveA,waveB,TWave,Multiplicand,HRI2
	return HRI
End

// Get the Z scores for the mean and standard deviation.  Uses the contents of root:MeanStDevPlot_f
Function MeanStDevZs([folder])
	String folder
	if(ParamIsDefault(folder))
		folder="root:MeanStDevPlot_f"
	endif
	String curr_folder=GetDataFolder(1)
	SetDataFolder $folder
	Wave Meann,StanDev
	String mean_values, stdev_values
	mean_values=ValueFromSignalAndNoise(Meann)
	Variable mean_xbar=NumFromList(0,mean_values)
	Variable mean_sigma=NumFromList(1,mean_values)
	stdev_values=ValueFromSignalAndNoise(StanDev)
	Variable stdev_xbar=NumFromList(0,stdev_values)
	Variable stdev_sigma=NumFromList(1,stdev_values)
	Variable i
	Duplicate /o Meann,Z_Means,Z_StDevs
	Z_Means=(Meann-mean_xbar)/mean_sigma
	Z_StDevs=(StanDev-stdev_xbar)/stdev_sigma
	SetDataFolder $curr_folder
End

// Computes the expected mean waiting time given a series of waiting times 'Times' 
// and the maximum possible waiting time given the endpoint of the simulation.  
Function MeanWaitingTime(Times,max_time)
	Wave Times
	Variable max_time // The duration of each simulation.  
	Variable i,hits=0,wait=0
	for(i=0;i<numpnts(Times);i+=1)
		wait+=Times[i]
		if(Times[i]<max_time)
			hits+=1
		endif
	endfor
	Variable prob=hits/wait // Assume this is a poisson process with probability 'prob' in each unit of time.  
	return 1/prob // This would be the mean of an exponential distribution of waiting times for a Poisson process of probabilty 'prob'.  
End

// Returns the value of the First Passage Time PDF at a given value of x, x0, barrier, mu, and sigma.  
Function FirstPassageTimePDF(T,x0,barrier,drift,sigma)
	Variable T // A given time for first passage.  
	Variable x0 // The starting point.  
	Variable barrier // The location of the barrier.  
	Variable drift // The drift rate.  
	Variable sigma // The standard deviation of the random walk.  
	return StatsWaldPDF(T, barrier/drift,barrier^2/sigma^2)
	//((barrier-x0)/((2*pi*sigma^2*T^3)^(1/2)))*exp(-((barrier-x0-drift*T)^2)/(2*sigma^2*T))
End

Function FirstPassageTimePDF2(T,x0,barrier,drift,sigma)
	Variable T // A given time for first passage.  
	Variable x0 // The starting point.  
	Variable barrier // The location of the barrier.  
	Variable drift // The drift rate.  
	Variable sigma // The standard deviation of the random walk.  
	return ((barrier-x0)/((2*pi*sigma^2*T^3)^(1/2)))*exp(-((barrier-x0-drift*T)^2)/(2*sigma^2*T))
End

// Returns the Durbin-Watson statistic.
Function DurbinWatson(Data,Fit)
	Wave Data,Fit
	Make /o/n=(numpnts(Fit)) Residuals=Fit-Data
	Differentiate /METH=2 Residuals /D=DiffResiduals
	DeletePoints 0,1,DiffResiduals
	MatrixOp /O DurbinWatsonStatistic=sumsqr(DiffResiduals)/sumsqr(Residuals)
	Variable stat=DurbinWatsonStatistic[0]
	KillWaves /Z Residuals,DiffResiduals,DurbinWatsonStatistic
	return stat
End

// Uses the median of the absolute value to compute a standard deviation that is robust against outliers.  
Function SafeStDev(w)
	wave w
	duplicate /free w,absW
	absW=abs(w)
	variable med=statsmedian(absW)
	return med/statsinvnormalcdf(0.75,0,1)
End

// Computes the median after discarding NaNs and Infs.  
Function MedianReal(w)
	Wave w
	Extract /O w,MRTempWave,numtype(w)==0
	Variable med=StatsMedian(MRTempWave)
	KillWaves /Z MRTempWave
	return med
End

// Computes the median after discarding NaNs and Infs.  
Function MedianNonZero(w)
	Wave w
	Extract /O w,MRTempWave,numtype(w)==0 && w!=0
	Variable med=StatsMedian(MRTempWave)
	KillWaves /Z MRTempWave
	return med
End

Function MedianMinusMean(w[,x1,x2])
	Wave w
	Variable x1,x2
	x1=ParamIsDefault(x1) ? dimoffset(w,0) : x1
	x2=ParamIsDefault(x2) ? dimoffset(w,0)+numpnts(w)*dimdelta(w,0) : x2
	Variable median,meann
	Duplicate /o/R=(x1,x2) w tempMMMWave
	WaveStats /Q/M=1 tempMMMWave
	meann=V_avg
	median=StatsMedian(tempMMMWave)
	return median-meann
End

// Computes the degree of correlation for each pair of vectors (columns) in a 2D matrix.  
Function CorrelationDegreeMatrix(Matrix)
	Wave Matrix
	Variable i,j,correlation
	Variable size=dimsize(Matrix,1)
	Make /o/n=(size,size) CDMatrix=NaN
	for(i=0;i<size;i+=1)
		Duplicate /o/R=[][i,i] Matrix,$"Column1"; Wave Column1
		for(j=0;j<size;j+=1)
			if(i==j)
				CDMatrix[i][j]=1
			elseif(i<j)
				Duplicate /o/R=[][j,j] Matrix,$"Column2"; Wave Column2
				CDMatrix[i][j]=StatsCorrelation(Column1,Column2)
			elseif(i>j)
				CDMatrix[i][j]=CDMatrix[j][i]
			endif
		endfor
	endfor
	KillWaves /Z Column1,Column2
	Edit /K=1 CDMatrix
End

// Computes the average deviation from the mode of the distribution
Function MeanMinusMode(w[,smooth_val])
	Wave w
	Variable smooth_val
	smooth_val=ParamIsDefault(smooth_val) ? 5 : smooth_val
	Variable theMode=Mode(w,smooth_val=smooth_val)
	Variable theMean=mean(w)
	return theMean-theMode
End

// Computes the average deviation from the mode of the distribution
Function DeviationFromMode(w[,smooth_val])
	Wave w
	Variable smooth_val
	smooth_val=ParamIsDefault(smooth_val) ? 5 : smooth_val
	Variable theMode=Mode(w,smooth_val=smooth_val)
	Duplicate /o w DFMtempWave
	DFMtempWave -= theMode
	DFMtempWave=DFMtempWave^2
	Variable variance=mean(DFMtempWave)
	KillWaves /Z DFMtempWave
	return sqrt(variance)
End

// Makes a graph showing the similarity between all waves in the current directory.  
// Assumes waves are something like spike times of cells
// i.e. each index of the wave is the spike time of one cell, and each wave is a different trial
Function MakeSimilarityMatrix([method,p_values1,p_values2])
	String method
	Variable p_values1,p_values2 // p_values1 for p-values in the histogram; p_values2 for p-values for individual squares
	
	// Defaults
	if(ParamIsDefault(method))
		method="Degree of Correlation"
	endif
	p_values1=ParamIsDefault(p_values1) ? 1 : p_values1
	p_values2=ParamIsDefault(p_values2) ? 0 : p_values2
	String curr_folder=GetDataFolder(1)
	
	// Assumes each trial is its own folder, with waves corresponding to the neurons' spike times in each PSC group.  Compute similarity for every pair of groups.
	String waves=WaveList("sw*",";",""), this_sweep,last_sweep="",sweep_breaks=""
	waves=SortList(waves,";",16)
	NewDataFolder /O/S $method
	Variable i,j,k,sweep_break,num_waves=ItemsInList(waves)
	Make /o/n=(num_waves,num_waves) SimilarityMatrix=NaN 
	Duplicate /o SimilarityMatrix ShuffledSimilarityMatrix
	for(i=0;i<num_waves;i+=1)
		Wave wave1=$("::"+StringFromList(i,waves))
		this_sweep=StringFromList(0,NameOfWave(wave1),"_") // The sweep (trial) that this set of spikes came from.
		if(!StringMatch(this_sweep,last_sweep))
			sweep_breaks+=num2str(i)+";" // Add to a list that indicates where the next sweep in the matrix begins.
		endif
		last_sweep=this_sweep
		if(p_values1)
			Duplicate /o wave1,temp1; ShuffleSpikes(temp1) // Make a version of wave1 in which the spikes are shuffled across cells.
		endif
		for(j=i;j<num_waves;j+=1)
			Wave wave2=$("::"+StringFromList(j,waves))
			SimilarityMatrix[i][j]=CompareVectors(wave1,wave2,method=method,p_value=p_values2) // Compute the similarity according to method.
			if(p_values1)
				Duplicate /o wave2,temp2; ShuffleSpikes(temp2)  // Make a version of wave2 in which the spikes are shuffled across cells.
				ShuffledSimilarityMatrix[i][j]=CompareVectors(temp1,temp2,method=method,p_value=p_values2) // Compute the similarity of the shuffled data according to method.
			endif
		endfor
		for(j=0;j<i;j+=1)
			SimilarityMatrix[i][j]=SimilarityMatrix[j][i] // Fill in the entries across the diagonal.
			ShuffledSimilarityMatrix[i][j]=ShuffledSimilarityMatrix[j][i]
		endfor
	endfor
	Display /K=1
	AppendImage /L=left2 /T=top2 SimilarityMatrix
	SetAxis /A/R left2 // Reverse the left axis so that (0,0) will be in the upper left-hand corner.
	
	// Add lines indicating the boundary between sweeps.
	SetDrawEnv linefgc=(65535,0,0), xcoord=top2, ycoord=left2, save
	for(i=1;i<ItemsInList(sweep_breaks);i+=1)
		sweep_break=str2num(StringFromList(i,sweep_breaks))
		DrawLine sweep_break-0.5,-0.5,sweep_break-0.5,num_waves-0.5 // Vertical line
		DrawLine -0.5,sweep_break-0.5,num_waves-0.5,sweep_break-0.5 // Horizontal line
	endfor
	
	// Compute p-values and ticks corresponding to those p-values.
	//if(p_values1)
		Duplicate /o SimilarityMatrix SimilarityMatrixUnwrapped
		Redimension /n=(numpnts(ShuffledSimilarityMatrix)) ShuffledSimilarityMatrix,SimilarityMatrixUnwrapped
		Sort ShuffledSimilarityMatrix,ShuffledSimilarityMatrix; Sort SimilarityMatrixUnwrapped,SimilarityMatrixUnwrapped
		SetScale x,0,1,ShuffledSimilarityMatrix,SimilarityMatrixUnwrapped
		Make /o SimilarityMatrixHist
		Variable x_offset=0,zero_line=0,bottom2_max=1
		
		// Method-specific changes
		strswitch(method)
			case "Degree of Correlation":
				ModifyImage SimilarityMatrix ctab= {-1,1,RedWhiteBlue,0}
				Histogram /B={-0.99,0.05,40} SimilarityMatrix,SimilarityMatrixHist
				x_offset=-0.01; zero_line=3
				break
			case "Covariance":
				ModifyImage SimilarityMatrix ctab= {*,SimilarityMatrixUnwrapped(0.95),RedWhiteBlue,0}
				WaveStats /M=1 /Q SimilarityMatrixUnwrapped
				Histogram /B={V_min,(V_max-V_min)/40,40} SimilarityMatrix,SimilarityMatrixHist
				bottom2_max=V_max
				//x_offset=-0.01 
				zero_line=3
				break
			case "Correlation of Sequence":
				ModifyImage SimilarityMatrix ctab= {-1,1,RedWhiteBlue,0}
				Histogram /B={-0.99,0.05,40} SimilarityMatrix,SimilarityMatrixHist
				x_offset=-0.01; zero_line=3
				break
			case "Least Squares":
				ModifyImage SimilarityMatrix ctab= {0,*,Grays,1}
				Reverse /P ShuffledSimilarityMatrix,SimilarityMatrixUnwrapped
				WaveStats /M=1 /Q SimilarityMatrixUnwrapped
				Histogram /B={-0.01,0.05,ceil(V_max/0.05)} SimilarityMatrix,SimilarityMatrixHist
				bottom2_max=V_max
				x_offset=0.01
				break
			case "Average Distance":
				ModifyImage SimilarityMatrix ctab= {0,*,Grays,1}
				Reverse /P ShuffledSimilarityMatrix,SimilarityMatrixUnwrapped
				WaveStats /M=1 /Q SimilarityMatrixUnwrapped
				Histogram /B={-0.01,0.05,ceil(V_max/0.05)} SimilarityMatrix,SimilarityMatrixHist
				bottom2_max=V_max
				x_offset=0.01
				break
			case "Euclidean Distance":
				Reverse /P ShuffledSimilarityMatrix,SimilarityMatrixUnwrapped
				SimilarityMatrix=log(SimilarityMatrix); ShuffledSimilarityMatrix=log(ShuffledSimilarityMatrix); SimilarityMatrixUnwrapped=log(SimilarityMatrixUnwrapped); 
				WaveStats /M=1 /Q SimilarityMatrixUnwrapped
				Histogram /B={V_min,0.05,ceil((V_max-V_min)/0.05)} SimilarityMatrix,SimilarityMatrixHist
				bottom2_max=V_max
				x_offset=0.01
				method+=" (log)"
				ModifyImage SimilarityMatrix ctab= {SimilarityMatrixUnwrapped(0.95),*,Grays,1}
				break
			default:
				printf "Not a known correlation method: %s [MakeSimilarityMatrix]\r",method
				break
		endswitch
		
		Make /o PValuesOfChoice={0.05,0.01,0.001}
		Make /o /N=(numpnts(PValuesOfChoice)) PValueTickWave=NaN
		Make /o /T /N=(numpnts(PValuesOfChoice)) PValueTickLabelWave
		Variable p_value
		for(i=0;i<numpnts(PValuesOfChoice);i+=1)
			p_value=PValuesOfChoice[i]
			PValueTickWave[i]=ShuffledSimilarityMatrix(1-p_value)
			PValueTickLabelWave[i]=num2str(p_value)
		endfor
		
		// Make a histogram of similarity values.
		
		Wave SimilarityMatrixHist
		SimilarityMatrixHist /= ((num_waves^2)-num_waves)
		AppendToGraph /c=(0,65535,0) /R=right2 /B=bottom2 SimilarityMatrixHist
		Label left2 "PSC Group #"; Label top2 "PSC Group #"
		Label bottom2 method; Label right2 "Occurence (PDF)"; 
		ModifyGraph axisEnab(left2)={0,0.96},axisEnab(top2)={0.02,0.6}, axisEnab(bottom2)={0.62,0.97}, axisEnab(right2)={0.04,0.96} 
		ModifyGraph freePos(left2)={-0.5,top2}, freepos(top2)={-0.5,left2}, freepos(bottom2)={0,right2}, freepos(right2)={bottom2_max,bottom2}
		DoUpdate; GetAxis /Q right2; SetAxis right2 0,V_max*1.1
		ModifyGraph zero(bottom2)=zero_line, mode=5,offset={x_offset,0}
		
		NewFreeAxis /T top3; GetAxis /Q bottom2; SetAxis top3 V_min,V_max; Label top3 "p value"
		ModifyGraph userticks(top3)={PValueTickWave,PValueTickLabelWave}, axisEnab(top3)={0.62,0.97}, freepos(top3)={0.04,kwFraction}, tkLblRot(top3)=90
		KillWaves temp1,temp2,PValuesOfChoice
	//endif
	
	// Cleanup
	ModifyGraph fSize=9,lblPosMode=2,btlen=3
	//KillWaves ShuffledSimilarityMatrix
	SetDataFolder $curr_folder
End

// Shuffles spike times between cells (one cell gets another cell's spike times).  Uses resampling.  
Function ShuffleSpikes(spikes)
	Wave spikes
	Variable i; String spike_locs=""
	for(i=0;i<numpnts(spikes);i+=1)
		if(!IsNaN(spikes[i]))
			spike_locs+=num2str(i)+";"
		endif
	endfor
	Variable num_spikes=ItemsInList(spike_locs)
	Make /o randos=floor(abs(enoise(num_spikes)))
	// If there was a spike in that cell, draw a new spike time from among the other spike times.  
	for(i=0;i<numpnts(spikes);i+=1)
		if(!IsNaN(spikes[i]))
			spikes[i]=spikes[str2num(StringFromList(randos[i],spike_locs))]
		endif
	endfor
	KillWaves randos
End

// Returns the location of the first (non-central) auto-correlation peak.  Good for determining reverberation frequency
Function AutoCorrPeak(sweep[,start,finish])
	Wave sweep
	Variable start,finish
	start=ParamIsDefault(start) ? leftx(sweep) : start
	finish=ParamIsDefault(finish) ? rightx(sweep) : finish
	Duplicate /o/R=(start,finish) sweep,smoothed
	smoothed=(smoothed>50) ? 0 : smoothed // Suppress artifacts
	smoothed=(smoothed<-1000) ? -1000 : smoothed // Suppress artifacts
	Smooth 1000,smoothed
	Differentiate smoothed
	FindLevels /Q smoothed,2000; Wave W_FindLevels // Find places where the slope crosses a 2000 pA/s threshold
	if(V_LevelsFound>0) // If reverberation is greater than 1 second
		Correlate smoothed,smoothed
		smoothed = (smoothed < 0) ? 0 : smoothed
		FindPeak /Q/R=(0.01+start,) smoothed // Search from 10 ms to the end for a peak
		//WaveStats /Q/R=(V_PeakLoc,) smoothed // Search from the location of that peak onward for a maximum
		// Result will be the location of the largest peak (may be the peak found by FindPeak)
		return 1/(V_peakloc-start)
	else
		return NaN
	endif
End

Function AutoCorrPeakAll(experiment[,start,finish])
	Wave experiment
	Variable start,finish
	String freq_name=NameOfWave(experiment)+"_Freqs"
	Make /o/n=(dimsize(experiment,1)) $freq_name,vals=NaN
	Wave Freqs=$freq_name
	Variable i
	for(i=0;i<dimsize(experiment,1);i+=1)
		Duplicate /o/R=()(i,i) experiment sweep
		start=ParamIsDefault(start) ? leftx(sweep) : start
		finish=ParamIsDefault(finish) ? rightx(sweep) : finish
		Freqs[i]=AutoCorrPeak(sweep,start=start,finish=finish)
		//NVar V_PeakVal
		//vals[i]=V_PeakVal
	endfor
	Display /K=1 Freqs
	ModifyGraph mode=2,lsize=3
	KillWaves sweep
End

// Ignore the first point of each wave
Function Pearson(wave1[,wave2,logg,start])
	Wave wave1,wave2
	Variable logg,start // Test if the r value when the log of each wave is used; Start from a point other than the zeroth point
	Duplicate /o/R=[start,] wave1, waveA
	if(ParamIsDefault(wave2))
		Duplicate /o waveA,waveB
		waveB=x
	else
		Duplicate /o/R=[start,] wave2,waveB
	endif
	Make /o/n=3 OutputWave
	if(logg)
		waveA=log(waveA)
		waveB=log(waveB)
	endif
	StatPearsonTest(waveA,waveB,OutputWave)
	printf "R = %.3f"+"; p = %.4f; Z = %1.2f\r",OutputWave[0],OutputWave[1],OutputWave[2]
	KillWaves waveA,waveB,OutputWave
End

// Converts a scatter plot into a line graph, where each point on the line is the average of the points witihin bin_width/2 of each side of the point.  
Function XY2RunningAverage(bin_start,bin_width,bin_shift,[only_trace,win,no_append])
	Variable bin_start // The left edge of the first bin.  
	Variable bin_width // The width of each bin (the range of X-values to be included in each bin).  
	Variable bin_shift // The shift from the left edge of one bin to the left edge of the next (bins can overlap).  
	String only_trace,win
	Variable no_append
	if(ParamIsDefault(win))
		win=WinName(0,1) // Use the top window.  
	endif
	String trace,traces=TraceNameList(win,";",3)
	Variable i,j,k,left,right,temp_left,temp_right,index_left,index_right,num_bins
	//Display /K=1 /N=G_RunningAvg
	for(i=0;i<ItemsInList(traces);i+=1)
		trace=StringFromList(i,traces)
		if(!ParamIsDefault(only_trace) && !StringMatch(only_trace,trace))
			continue
		endif
		Duplicate /o TraceNameToWaveRef(win,trace) tempYWave // Copy of the Y Wave.  
		Duplicate /o XWaveRefFromTrace(win,trace) tempXWave // Copy of the X Wave.  
		Sort tempXWave,tempXWave,tempYWave // Sort each so that the values of the X-wave are ascending.  
		Make /o/n=0 $CleanUpName("RunningAvg_"+trace,0); Wave RunningAvg=$CleanUpName("RunningAvg_"+trace,0) // The output wave.  
		Make /o/n=0 $CleanUpName("RunningSEM_"+trace,0); Wave RunningSEM=$CleanUpName("RunningSEM_"+trace,0) // The error bars for the output wave.  
		left=bin_start // The left edge with be at the lowest X wave point.  
		right=tempXWave[numpnts(tempXWave)-1] // The right edge will be at the highest X wave point.  
		num_bins=1+ceil((right-left)/bin_shift) // Set the number of bins to span the range of points in the X wave.  
		Redimension /n=(num_bins) RunningAvg,RunningSEM // Set the output waves to have the right number of points.  
		SetScale /P x,left,bin_shift,RunningAvg,RunningSEM // Set the scale of the output to match the binning.  
		index_left=0 // Initialize the index of the left-most point of the bin to 0.  
		for(j=0;j<num_bins;j+=1) // Loop through the bins.  
			k=index_left // Start at the left-most point of the most recent bin.  
			temp_left=left+j*bin_shift-bin_width/2 // Set the left-most point of this bin.  
			temp_right=left+j*bin_shift+bin_width/2 // Set the right-most point of this bin.  
			// Find the X wave indices whose values are just inside the bin edges.  
			index_left=BinarySearch(tempXWave,temp_left)
			index_right=BinarySearch(tempXWave,temp_right)
			// Adjust indices and deal with bins whose edges extend past the range of the X values.  
			index_left=(index_left==-2) ? numpnts(tempXWave)-1 : index_left+1
			index_right=(index_right==-2) ? (numpnts(tempXWave)-1) : index_right
			// If there is less than 1 point in the bin, leave it undefined.  You could revise this to leave 1 point undefined as well, since there is no error measurement.  
			if(index_right<index_left) 
				RunningAvg[j]=NaN
				RunningSEM[j]=NaN
			else
				Duplicate /O/R=[index_left,index_right] TempYWave,TempValues // Copy a chunk of the Y wave corresponding to the points in the X wave whose values where inside the bin.  
				Extract/O TempValues,TempValues,numtype(TempValues) == 0 // Get rid of NaNs and Infs.  
				if(numpnts(TempValues)>0) // If there are any values left.  
					WaveStats /Q tempValues
					RunningAvg[j]=V_avg // Here I use the mean... use whatever statistic you want
					RunningSEM[j]=V_sdev/sqrt(V_npnts) // Standard error of the mean...
				else // If the bin has no points, leave it undefined.  
					RunningAvg[j]=NaN
					RunningSEM[j]=NaN
				endif
			endif
		endfor
		if(!no_append)
			AppendToGraph RunningAvg // Append this trace to the new graph.  
			ErrorBars $NameOfWave(RunningAvg), Y wave=(RunningSEM,RunningSEM) // Append the error bars.  
			ModifyGraph mode($TopTrace())=0 // Make it a line graph.  
		endif
	endfor
	KillWaves /Z TempXWave,TempYWave,TempValues // Cleanup.  
End

// Returns the most likely value (actually the location of the peak of the smoothed histogram).
Function Mode(w[,x1,x2,p1,p2,smooth_val])
	Wave w
	Variable x1,x2,p1,p2,smooth_val
	smooth_val=ParamIsDefault(smooth_val) ? 5 : smooth_val
	//WaveStats /M=1/Q w
	Make /o ModeHist 
	if(!ParamIsDefault(x1))
		Histogram /B=4 /R=(x1,x2) w,modeHist
	elseif(!ParamIsDefault(p1))
		Histogram /B=4 /R=[p1,p2] w,modeHist
	else
		Histogram /B=4 w,modeHist
	endif
	//Display /K=1 modeHist
	if(smooth_val>0)
		Smooth smooth_val,modeHist
	endif
	WaveStats /M=1/Q modeHist
	KillWaves modeHist
	return V_maxloc
End

// Compute confidence intervals for CV analysis.  
Function CVAnalysis3(range,before_mean,after_mean,Before_Wave,After_Wave[,iterations,mode])
	Variable range // The confidence interval, e.g. 0.9 for 90%.  
	Variable before_mean,after_mean // The actual means before and after induction (instead of computing them from Before_Wave and After_Wave).  
	Wave Before_Wave,After_Wave // The samples before and after induction.  
	Variable iterations // More iterations is slower, but more accurate.  
	Variable mode // 0 for non-stationary CV, 1 for detrended CV.  
	
	mode=ParamIsDefault(mode) ? 0 : mode
	iterations=ParamIsDefault(iterations) ? 1000 : iterations
	Variable i,before,after
	
	Duplicate /o Before_Wave Before_Wave_Temp
	Duplicate /o After_Wave After_Wave_Temp
	Variable before_stdev=StDevNoise(Before_Wave,mode=mode)
	Variable after_stdev=StDevNoise(After_Wave,mode=mode)
	Make /o/n=(iterations) Result=NaN
	
	for(i=0;i<iterations;i+=1)
		Before_Wave_Temp=before_mean+gnoise(before_stdev)
		After_Wave_Temp=after_mean+gnoise(after_stdev)
		before=(StDevNoise(Before_Wave_Temp,mode=mode)/before_mean)^2
		after=(StDevNoise(After_Wave_Temp,mode=mode)/after_mean)^2
		Result[i]=before/after
	endfor
	before=(StDevNoise(Before_Wave,mode=mode)/before_mean)^2
	after=(StDevNoise(After_Wave,mode=mode)/after_mean)^2
	ECDF(Result)
	Make /o/n=1 CV_Low,CV_Actual,CV_High
	CV_Actual=before/after
	Variable cutoff=(1-range)/2
	CV_Low=Result(cutoff)
	CV_High=Result(1-cutoff)
End

function BinomialTest(k1,n1,k2,n2)
	variable k1,n1,k2,n2
	
	variable p1=k1/n1, p2=k2/n2, p0 = (k1+k2)/(n1+n2)
	variable Z = (p1-p2)/sqrt(p0*(1-p0)*(1/n1 + 1/n2))
	variable pp = statsnormalcdf(Z,0,1)
	pp = pp > 0.5 ? (1-pp) : pp
	return pp
end

Function BootBino(successes1,trials1,successes2,trials2[,num_iterations])
	Variable successes1,trials1,successes2,trials2,num_iterations
	Variable successes,trials,prob,prob1,prob2,prob_diff
	num_iterations=ParamIsDefault(num_iterations) ? 100000 : num_iterations
	successes=successes1+successes2
	trials=trials1+trials2
	prob=successes/trials
	prob1=successes1/trials1
	prob2=successes2/trials2
	prob_diff=prob2-prob1
	Variable i
	Make /o/n=(num_iterations) BBTest1=BinomialNoise(trials1,prob)/trials1
	Make /o/n=(num_iterations) BBTest2=BinomialNoise(trials2,prob)/trials2
	Make /o/n=(num_iterations) BBDifferences=BBTest1-BBTest2
	Sort BBDifferences,BBDifferences
	SetScale x,0,1,BBDifferences
	FindLevel /Q BBDifferences,prob_diff
	Variable level=V_flag ? 0 : V_LevelX
	if(level>0.5)
		level=1-level
	endif
	KillWaves /Z BBDifferences,BBTest1,BBTest2
	return level
End

// Returns the Mahalanobis distance of two data points.  OBSOLETE.  
//Function MahalDistance(values1,values2,stdevs)
//	String values1,values2,stdevs // values are vectors (in string form) describing the two data points; stdevs are the standard deviations of the dataset in each dimension.  
//	Variable i,distance_squared=0,dims=ItemsInList(values1)
//	Variable val1,val2,stdev
//	for(i=0;i<dims;i+=1)
//		val1=NumFromList(i,values1)
//		val2=NumFromList(i,values2)
//		stdev=NumFromList(i,stdevs)
//		distance_squared+=((val1-val2)/stdev)^2
//	endfor
//	return sqrt(distance_squared)
//End


// If a data consists of gaussian noise plus a signal on on end, this function will figure out the p-value
// corresponding to the probabability that a given value from that data could be from the noise component, 
// or just the mean and standard deviation of the noise.   
// Assumes that the signal is usually more positive than the noise.  
Function /S ValueFromSignalandNoise(data[,p])
	Wave data
	Variable p // Either return the location of a p-value,
	Duplicate /o data,Sorted_Data
	Sort Sorted_Data,Sorted_Data
	Make /o/n=1000 Hist; SetScale x,0,Median2(Sorted_Data)*2,Hist
	Histogram /B=2 Sorted_Data,Hist
	Duplicate /o Hist Hist2
	Smooth 1000,Hist2
	WaveStats /Q Hist2
	KillWaves /Z Hist2
	Variable mean_noise=V_maxloc
	Variable difference
	String value
	FindLevel /Q Sorted_Data,mean_noise
	if(V_flag)
		printf "No level found [ValueFromSignalandNoise], data=%s\r",NameOfWave(data)
		abort
	else
		// Set the scale so that 0.5 will fall right at the mean value the noise, and everything
		// beneath it will be noise, and the noise is symmetrical, so we will be able to find a p-value.  
		SetScale x,0,0.5*rightx(Sorted_Data)/V_LevelX,Sorted_Data
		if(!ParamIsDefault(p))
			difference=mean_noise-Sorted_Data(p)
			value=num2str(mean_noise+difference)
		else
			Duplicate /o /R=(0,0.5) Sorted_Data temp1,temp2
			temp2-=mean_noise
			temp2*=-1
			temp2+=mean_noise
			Concatenate /O {temp1,temp2}, Sorted_Data
			WaveStats /Q Sorted_Data
			value=num2str(mean_noise)+";"+num2str(V_sdev)
		endif
	endif
	//Histogram /B=2 Sorted_Data,Hist
	//Display /K=1 Hist
	KillWaves /Z Hist,Sorted_Data,temp1,temp2
	return value
End

// Finds the chunks in which a majority of the data is non-zero, based on successive median smoothing.  
Function FindChunks(w[,minWidth])
	Wave w 
	Variable minWidth // Minimum width of a zero or non-zero chunk, in the units of the wave.  Sets the width of the largest smoothing window.
	
	Variable i
	minWidth=round(2*minWidth/deltax(w)) // Convert from units to points.  
	minWidth=ParamIsDefault(minWidth) ? 101 :minWidth // Default of 101 points.  
	Duplicate /o w Answer
	Variable start=mod(numpnts(w),2)==0 ? numpnts(w)-1 : numpnts(w)-2
	start=min(start,minWidth) 
	for(i=3;i<=start;i+=2)
		Smooth /M=0 i,Answer
	endfor
End

// Dynamically computes the running mean and standard deviation.  
// Test material for upstates:  
//Make /o/n=100000 Test,Downstate,Upstate
//SetScale x,0,10,Test,Downstate,Upstate
//Downstate=-x/2+gnoise((15-x)/5) // Scaling dx=0.0001, points=100000
//Upstate=sin(2*pi*x)>0.5 && x>1 ? sin(2*pi*x)*10+10*gnoise(sin(2*pi*x))^2 : 0
//Test=Downstate+Upstate
//RunningMeanStDev(Test,no_plot=1,bin_size=0.001,pause_update="1,1;2,5") // 1 ms resolution!  
//Display
//AppendToGraph /c=(0,0,0) Test
//AppendToGraph /c=(65535,0,0) Meann
//AppendToGraph /c=(0,0,65535) StanDev
Threadsafe Function RunningMeanStDev(w[,winSize,pauseOn,winShape])
	wave w
	variable winSize // The size of the segments for which statistics are calculated.  Smaller values will identify state transitions with more precision, but will be more sensitive to random fluctuations.  
	wave pauseOn // Format {{on_thresh,on_duration},{off_thresh,off_duration}}; Stop updating if the Z-score exceeds 'on_thresh' for 'on_duration', and continue if it stops exceeding 'off_thresh' for 'off_duration'. 
	string winShape // Window shape for running statitics.  Rectangular ("Rect") or Exponential ("Exp").  Exponential windows weight more recent values in the window more heavily.  

	variable delta=dimdelta(w,0) // Duration of a sample, in seconds.  
	variable lag=1 // How many samples back to look.  Lag must be greater than zero and has always been set to 1.   
	variable maxOffTime=2000/delta // The largest number of samples for which updating may be off before it is reinitialized.  
								 // Guards against e.g. sudden, long-lasting increases in the baseline.  The numerator is time in milliseconds.  

	winSize=ParamIsDefault(winSize) ? 0.25 : winSize // Default value of 250 ms.  
	if(!ParamIsDefault(pauseOn)) // Set the values for stopping and restarting updating of the baseline statistics.  
		variable on_thresh=pauseOn[0][0]
		variable on_duration=pauseOn[1][0]
		variable off_thresh=pauseOn[0][1]
		variable off_duration=pauseOn[1][1]
	endif
	winShape=SelectString(ParamIsDefault(winShape),winShape,"Exp") // Default to an exponential window, weighting recent samples more heavily than distant samples.  
	
	variable n=winSize/delta // Number of points in the window.  
	variable num_bins=round(numpnts(w)-n) // Number of points remaining (last point of initial window to last point of 'w').  
	variable i=0
	
	Differentiate /METH=1 w /D=dw // Compute the derivative (first difference) of the input wave 'w'.  
	wave dw
	//duplicate /free w,MeansThresh,StDevsThresh
	
	WaveStats /Q/R=[0,n-1] w // Compute statistics over the first n points of 'w' (called the initial segment), to get initial values of the statistics.  
	variable eX=V_avg // Mean of 'w'.  
	variable eX2=V_rms^2 // Mean of w-squared.  Simplifies the calculation of running variance. 
	variable eS=sqrt(eX2-eX^2) // Standard deviation of 'w'.  More appropriate than v_sdev, because it does not use the (n-1) correction as it is not intended to be an unbiased estimator.  
	Make /o/n=(numpnts(w)) Meann=eX,StanDev=eS,Paused=0 // Fill the outputs with the initial values.  
	
	// Repeat for the derivative of 'w'.  
	WaveStats /Q/R=[0,n-1] dw  
	variable edX=V_avg
	variable edX2=V_rms^2 // Work with variance to simplify the calculation. 
	variable edS=sqrt(edX2-edX^2)
	Make /free/n=(numpnts(w)) DMeann=edX,DStanDev=edS
	
	// Set initial values to statistics for inital segment.  
	variable val_on=eX,dval_on=edX
	variable val_off=val_on,dval_off=dval_on
	variable pause=0 // Update segment statistics when the next sample is examined.  
	variable count=0 // Initialize the counter for suspension/resumption of updating.  
	
	// Loop over all samples, starting with the first sample after the initial segment.  
	for(i=n;i<n+num_bins;i+=1)
		val_on=w[i] // The next value to examine in 'w'.  
		dval_on=dw[i] // The next value to examine in 'dw', the derivative of 'w'.  
		
		variable zw=(val_on-eX)/eS // A Z-score for the new 'w' value.  
		variable zdw=((dval_on-edX)/edS)^2 // A Z-score for the new 'dw' value.  
		
		//MeansThresh[i]=zw // A wave to store the 'w' z-scores.  
		//StDevsThresh[i]=zdw // A wave to score the 'dw' z-scores.  
		if(!ParamIsDefault(pauseOn)) // Check to see if updating should be suspended or resumed based on these scores.  
			if(pause==0 && (zw>on_thresh && zdw>on_thresh) && zw>0) // If we are currently updating but both thresholds have been crossed...
				count+=1 // Note that it has been going on.  
				if(count>=on_duration) // If this situation has persisted for a while...
					pause=1 // Stop updating.  
					count=0 // Reinitialize the counter.  
				endif
			elseif(pause==1 && (zw<off_thresh && zdw<off_thresh)) // If we are not updating but are under both thresholds.  
				count+=1
				if(count>=off_duration)
					pause=0 // Start updating.  
					count=0
					variable offTime=0 // Reinitialize the amount of time that updating has been off (since it is no longer off).  
				endif
			else
				count=0
			endif
			if(pause==1) // If we are not updating.  
				offTime+=1 // Note that we are still not updating.  
				if(offTime>maxOffTime) // If updating has been off for too long, turn it on again.  
					pause=0
					offTime=0
					count=0
					
					// Reinitialize statistics according to a new initial segment, starting at the current location and extending back n samples.  
					WaveStats /Q/R=[i-n+1,i] w
					eX=V_avg
					eX2=V_rms^2
					eS=sqrt(eX2-eX^2)
					WaveStats /Q/R=[i-n+1,i] dw
					edX=V_avg
					edX2=V_rms^2
					edS=sqrt(edX2-edX^2)
				endif
			else
				offTime=0
			endif
		endif
		
		if(!pause) // If we are updating.  
			Paused[i]=0 // Note that this was a period of updating.  
			val_on=w[i-lag] // Take the next value of 'w'.  
			dval_on=dw[i-lag] // Take the next value of 'dw'.  
			strswitch(winShape) // Updating the segment statistics according to the window shape.  
				case "Rect": // Rectangular window.  
					eX+=(val_on-val_off)/n
					eX2+=(val_on^2-val_off^2)/n
					edX+=(dval_on-dval_off)/n
					edX2+=(dval_on^2-dval_off^2)/n
					val_off=w[i-n]*!Paused[i-n] // Set the next value to fall off as the window completely passes it.  
					dval_off=dw[i-n]*!Paused[i-n]
					break
//				case "Gauss": // Gaussian window
//					// Put all of this outside of the loop.  
//					Meann=w
//					// I believe that (2*n)^2 passes of binomial smoothing is equivalent to a Gaussian with standard deviation n.  
//					Smooth /E=3 (2*n)^2, Meann
//					StanDev=(w-Meann)^2
//					Smooth /E=3 (2*n)^2,StanDev
//					StanDev=sqrt(StanDev)
//					break
				case "Exp": // Exponential window.  
				default: // Default is exponential window.  
					eX+=(val_on-eX)/n 
					eX2+=(val_on^2-eX2)/n
					edX+=(dval_on-edX)/n
					edX2+=(dval_on^2-edX2)/n
					// Note that there is no 'off' value because past values fall off exponentially, rather than suddenly as the past edge of the window is reached.  
					break
			endswitch
			// Update statistics.  
			Meann[i]=eX
			eS=sqrt(eX2-eX^2)
			StanDev[i]=eS
			DMeann[i]=edX
			edS=sqrt(edX2-edX^2)
			DStanDev[i]=edS
		else // If we are not updating.  
			// Keep all values the same.  
			Paused[i]=1
			Meann[i]=Meann[i-1]
			StanDev[i]=StanDev[i-1]
			dMeann[i]=dMeann[i-1]
			dStanDev[i]=dStanDev[i-1]
		endif
	endfor
	
	KillWaves /Z dw
	SetScale /P x,0,delta,Meann,StanDev,Paused
	CopyScales /P w,Meann,StanDev
End

// Computes a running value of the peak of the histogram and the standard deviation for the left-hand distribution (left of the peak) mirrored over to the right.  
// Similar to a running mean and standard deviation, except it tries to isolate values the come from the noise, which is assumed to have smaller mean and be
// more common (higher probability to be the determinant of the distribution at any given time, thus higher peak in the histogram) than the signal.  The second
// of these assumptions could be invalid with a sufficiently small bin_size ~ duration of the non-noise elements.   
// Rather than a window of strict size 'bin_size', bin_size is like a time constant for the updating.  This appeared to have better accuracy in tests with mock waves.  
// This function isn't really that great.  Use RunningMeanStDev with pause_update for something much better.  
Function RunningModeAndZ(w,bin_size)
	Wave w
	Variable bin_size
	
	//String curr_folder=GetDataFolder(1)
	//NewDataFolder /O/S root:MeanStDevPlot_F
	Variable delta=dimdelta(w,0)
	Variable bin_points=bin_size/delta
	Variable num_bins=round(numpnts(w)-bin_points)
	Make /o/n=(num_bins) ModeWave,WidthWave // WidthWave is the standard deviation of the left-hand distribution.  
	Variable i=0
	
	WaveStats /Q w
	Variable minn=trunc(V_min),maxx=ceil(V_max),resolution=0.02
	Make /o/n=((maxx-minn)/resolution) Hist
	SetScale x,minn,maxx,Hist
	
	Histogram /C/B=2/R=[0,bin_points-1] w,Hist; Wave Hist
	Variable smooth_width=3 // Needs to be 5 or less because Smooth uses a different algorithm when the first argument is > 50.  
	Make /o/n=(6*smooth_width+1) GaussAdd=gauss(x,smooth_width*3,smooth_width)
	Smooth 2*(smooth_width^2),Hist
	WaveStats /Q/M=1 Hist
	Variable mean_noise=V_maxloc
	Variable mean_loc=trunc((mean_noise-minn)/resolution)
	Variable max_count=V_max

	Extract /O w,wLeft,p<bin_points && w<mean_noise
	Variable mean_noise2=mean_noise^2
	wLeft-=mean_noise
	wLeft=wLeft^2
	Variable var_noise=mean(wLeft)//sum(wLeft)/(bin_points-1) // Use variance to make updating with each new sample easier.  
	Variable old_mean_noise=mean_noise
	Variable old_val=w[0]
	Variable j=numpnts(wLeft)
	
	for(i=0;i<num_bins;i+=1)
		Variable old_loc=trunc((w[i]-minn)/resolution)
		Variable new_loc=trunc((w[i+bin_points]-minn)/resolution)
		Variable multiplier=(1-1/bin_points)^(-mod(i,100)) // Must reset the multiplier periodically or numerical errors will result.  
		Hist[new_loc-3*smooth_width,new_loc+3*smooth_width]+=multiplier*GaussAdd[3*smooth_width+p-new_loc]
		WaveStats /Q/M=1/R=[new_loc-3*smooth_width,new_loc+3*smooth_width] Hist
		if(V_max>max_count)
			WaveStats /Q/M=1 Hist
			max_count=V_max
			mean_noise=V_maxloc
		endif
		Variable new_val=w[i+bin_points]
		old_val=w[i]
		if(new_val<=mean_noise)
			old_val=wLeft[j-bin_points]
			var_noise+=((new_val-mean_noise)^2 - var_noise)/(bin_points-1)//((new_val-mean_noise)^2 - (old_val-old_mean_noise)^2)/(bin_points-1)
			old_mean_noise=mean_noise
			wLeft[j]={new_val}
			j+=1
		endif
		ModeWave[i]=mean_noise
		WidthWave[i]=sqrt(var_noise) // Convert back to standard deviation.  
		if(mod(i,100)==99) // Must reset the multipler periodically or numerical errors will result.  
			max_count/=multiplier
			Hist/=multiplier
		endif
		//Hist[old_loc-3*smooth_width,old_loc+3*smooth_width]-=multiplier*GaussAdd[3*smooth_width+p-old_loc]
	endfor
	KillWaves /Z Hist
	Variable left=dimoffset(w,0)+bin_size/2
	SetScale /P x,left,dimdelta(w,0),ModeWave,WidthWave
	
	//SetDataFolder $curr_folder
End

// Plot points corresponding to the mean vs. the standard deviation of the signal in bins of size 'bin_size', shifting by 'shift' with each step.  
Function MeanStDevPlot(w[,bin_size,shift,non_stationary,no_plot])
	Wave w
	Variable bin_size,shift,non_stationary,no_plot
	bin_size=ParamIsDefault(bin_size) ? 0.25 : bin_size
	shift=ParamIsDefault(shift) ? 0.1 : shift
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:MeanStDevPlot_F
	Make /o/n=0 Meann,StanDev,BinCenters
	Variable left=leftx(w)
	Variable right=rightx(w)
	Variable duration=right-left
	Variable i=0
	Variable start=left
	Do
		if(start>right-bin_size)
			break
		else
			InsertPoints 0,1,Meann,StanDev,BinCenters
			WaveStats /Q/R=(start,start+bin_size) w
			Meann[0]=V_avg
			if(non_stationary)
				Duplicate /O/R=(start,start+bin_size) w Segment
				//Smooth /B 10,Segment
				Differentiate Segment
				WaveStats /Q Segment
				StanDev[0]=V_sdev/sqrt(2)
			else
				StanDev[0]=V_sdev
			endif
			BinCenters[0]=start+bin_size/2
			start+=shift
		endif
	While(1)
	WaveTransform /O flip,Meann
	WaveTransform /O flip,StanDev
	WaveTransform /O flip,BinCenters
	SetScale /P x,BinCenters[0],shift, Meann,StanDev
	KillWaves /Z Segment
	if(!no_plot)
		Display /K=1 /N=MeanVsStDev Meann vs StanDev
		BigDots(size=2)
	endif
	SetDataFolder $curr_folder
End

// Converts the values in a matrix to the z-score in the given dimension.  
Function Matrix2Zs(Matrix,dim)
	Wave Matrix
	Variable dim // dim=0 would convert each row to a row of p-values given the data in that row.  
	
	if(!WaveExists(Matrix))
		printf "No such wave: [Matrix2Zs]\r"
	endif
	Variable i,dimSize1=dimsize(Matrix,dim),dimSize2=dimsize(Matrix,1-dim)
	for(i=0;i<dimSize1;i+=1)
		if(dim==0)
			Duplicate /O/R=[i][] Matrix Section
		elseif(dim==1)
			Duplicate /O/R=[][i] Matrix Section
		endif
		//Redimension /n=(numpnts(Section)) Section
		//Sort Section,Section
		//Variable edge=numpnts(Section)/4
		//DeletePoints 0,edge,Section // Delete first 1/4.  
		//DeletePoints edge*2,edge,Section // Delete last 1/4.  
		WaveStats /Q Section
		if(dim==0)
			Matrix[i][]=(Matrix[i][q]-V_avg)/V_sdev
		elseif(dim==1)
			Matrix[][i]=(Matrix[p][i]-V_avg)/V_sdev
		endif
	endfor
	KillWaves /Z Trimmed,Trimmed2
End

// Generates a random integer in the range [0,n)
Function Rand(n)
	Variable n
	return floor(abs(enoise(n)))
End

// Perform K-Means clustering of EPSCs, by finding peaks in a signal (many of which will be EPSCs), taking a wavelet decomposition
// of those peaks and clustering those decomposition vectors (one vector for each peak in the original signal).  
Function KMeans2(originalWave,CWT_Wave)
	Wave originalWave,CWT_Wave // CWT_Wave must be transposed from the original CWT of the signal.  
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O/S root:KMeanss
	FindPeaks(w=originalWave,smooth_val=1000)
	Wave PeakLocs=root:TroughLocs
	Make /o/n=(dimsize(CWT_Wave,0),numpnts(PeakLocs)) SelectiveCWT
	SelectiveCWT[][]=CWT_Wave[p][x2pnt(originalWave,PeakLocs[q])] // Select only those time points where there is a maximum.  
	Display /K=1 /N=KMeansDistances
	Variable i
	Duplicate /o SelectiveCWT DummySelectiveCWT,GaussianBall
	DummySelectiveCWT=SelectiveCWT[Rand(dimsize(SelectiveCWT,0))][Rand(dimsize(SelectiveCWT,1))]
	GaussianBall=gnoise(1)
	for(i=2;i<numpnts(PeakLocs);i=floor(i*1.5))
		KMeans /OUT=2 /NCLS=(i) /CAN SelectiveCWT
		Wave Distances=M_KMCDistances
		Redimension /n=(numpnts(M_KMCDistances)) M_KMCDistances
		Wave Distances=M_KMCDistances
		DeleteNans(Distances)
		Duplicate /o Distances $("Distances_"+num2str(i))
		Wave Distances=$("Distances_"+num2str(i))
		Sort Distances,Distances
		AppendToGraph /c=(65535,0,0) Distances
	endfor
	for(i=2;i<10;i+=1)
		KMeans /OUT=2 /NCLS=(i) /CAN DummySelectiveCWT
		Wave Distances=M_KMCDistances
		Redimension /n=(numpnts(M_KMCDistances)) M_KMCDistances
		Wave Distances=M_KMCDistances
		DeleteNans(Distances)
		Duplicate /o Distances $("DummyDistances_"+num2str(i))
		Wave Distances=$("DummyDistances_"+num2str(i))
		Sort Distances,Distances
		AppendToGraph /c=(0,0,65535) Distances
	endfor
	for(i=2;i<10;i+=1)
		KMeans /OUT=2 /NCLS=(i) /CAN GaussianBall
		Wave Distances=M_KMCDistances
		Redimension /n=(numpnts(M_KMCDistances)) M_KMCDistances
		Wave Distances=M_KMCDistances
		DeleteNans(Distances)
		Duplicate /o Distances $("DummyDistances2_"+num2str(i))
		Wave Distances=$("DummyDistances2_"+num2str(i))
		Sort Distances,Distances
		AppendToGraph /c=(0,65535,0) Distances
	endfor
	ModifyGraph mode=4
	SetDataFolder $curr_folder
End

// Cluster a correlation matrix by swapping rows (and columns).  
function /wave CorrelationClustering(numPatterns,corrMatrix[,method,maxDispersion])
	variable numPatterns // Number of patterns that you expect to find.  
	wave corrMatrix // The correlation (or covariance) matrix.  
	string method // KMeans or FP.  
	variable maxDispersion
	
	method=selectstring(!paramisdefault(method),"KMeans",method)
	maxDispersion=paramisdefault(maxDispersion) ? inf : maxDispersion
	duplicate /free corrMatrix clusteredMatrix // Prepared the clustered correlation matrix.  
	make /free/n=(dimsize(corrMatrix,0)) index=p		
	
	strswitch(method)
		case "KMeans":
			do
				KMeans /CAN /INIT=1 /NCLS=(numPatterns) /DEAD=1 /OUT=2 /SEED=(ticks) corrMatrix // K-Means clustering.  
			while(sum(w_kmdispersion)>maxDispersion)
			wave w_KMMembers
			Sort W_KMMembers,index // Create a sorting index to use to swap out rows (and columns).  
			break
		case "FP":
			FPClustering /MAXC=(numPatterns) corrMatrix // K-Means clustering.  
			Sort W_FPClusterIndex,index // Create a sorting index to use to swap out rows (and columns).  
			break
	endswitch
	
	clusteredMatrix=corrMatrix[index[p]][index[q]] // Shuffle rows (and columns).  
	wave /Z waterfallColors
	if(waveexists(waterfallColors))
		wave W_KMMembers // The pattern number that each signal most represents (the K-Means clustering result).  
		waterfallColors=W_KMMembers[q] // Color the waterfall plot according to the clustering result.  
	endif
	killwaves /z M_KMClasses,W_KMMembers,W_FPCenterIndex,W_FPClusterIndex // Cleanup.  
	return clusteredMatrix
End

function /wave BestCorrelationClustering(corrMatrix[,iter])
	wave corrMatrix
	variable iter
	
	iter=paramisdefault(iter) ? 100 : iter
	variable i,j
	make /o/n=25 ClusterDispersions
	setscale /p x,1,1,ClusterDispersions
	for(i=0;i<25;i+=1)
		variable minn=inf
		for(j=0;j<10;j+=1)
			CorrelationClustering(i+1,corrMatrix)
			wave W_KMDispersion
			minn=min(minn,sum(W_KMDispersion))
		endfor
		ClusterDispersions[i]=minn
	endfor
	return ClusterDispersions
end

threadsafe Function ComputeCV(w)//[,correction,x1,x2])
	wave w
	//Variable correction // Correct for slow variations in the signal that artificially increase the standard deviation.  
	//Variable x1,x2
	//x1=ParamIsDefault(x1) ? leftx(w) : x1
	//x2=ParamIsDefault(x2) ? rightx(w) : x2
	//Variable avg,sdev
	//WaveStats /Q /R=(x1,x2) w; avg=V_avg
	//if(correction)
	//	sdev=StDevNoise(w,x1=x1,x2=x2)
	//else
	//	sdev=V_sdev
	//endif
	//return sdev/V_avg
	wavestats /q w
	return v_sdev/v_avg
End

// Computes the standard deviation of the noise, independent of any slowly varying component.  
// This is also called the (square root of the) non-stationary variance
Function StDevNoise(w[,x1,x2,mode])
	Wave w
	Variable x1,x2,mode // Mode 0 is non-stationary standard deviation; mode 1 detrends and returns conventional standard deviation.  
	mode=ParamIsDefault(mode) ? 0 : mode
	x1=ParamIsDefault(x1) ? leftx(w) : x1
	x2=ParamIsDefault(x2) ? rightx(w) : x2
	Duplicate /O/R=(x1,x2) w Temp_StDevNoise_Wave
	DeleteNans(Temp_StDevNoise_Wave)
	if(mode==0)
		Differentiate /METH=1 Temp_StDevNoise_Wave
		if(numpnts(Temp_StDevNoise_Wave)>0)
			WaveStats /Q Temp_StDevNoise_Wave
			KillWaves Temp_StDevNoise_Wave
			return V_sdev*dimdelta(w,0)/sqrt(2)
		else
			return NaN
		endif
	elseif(mode==1)
		if(numpnts(Temp_StDevNoise_Wave)>0)
			Execute /Q "DSPDetrend /F=line "+GetWavesDataFolder(Temp_StDevNoise_Wave,2)
			Wave W_Detrend
			WaveStats /Q W_Detrend
			KillWaves W_Detrend
			return V_sdev
		else
			return NaN
		endif
	endif
End

Function DSPDetrendTest(w)
	Wave w
	DSPDetrend /F=line w
End

// Compares two vectors of spike times.
Function CompareVectors(wave1,wave2[,method,p_value])
	Wave wave1,wave2
	String method
	Variable p_value // Returns a p-value instead of the actual output of the method.  Uses resampling.  
	if(ParamIsDefault(method))
		method="Degree of Correlation"
	endif
	
	// Remove NaNs
	Duplicate /o wave1 waveA
	Duplicate /o wave2 waveB
	Variable i=0,j,value
	Do
		if(IsNaN(waveA[i]) || IsNaN(waveB[i]))
			DeletePoints i,1,waveA,waveB
		else
			i+=1
		endif
	While(i<numpnts(waveA))
	
	Variable V_FitOptions=4 // Suppresses curve-fitting window
	Duplicate /o waveA waveAbackup
	Duplicate /o waveB waveBbackup
	
	Make /o /n=(1+p_value*1000) Values=NaN
	for(i=0;i<numpnts(Values);i+=1) // Once (default), or many times (if p-values are required)
		if(i>0)
			waveA=waveAbackup
			waveB=waveBbackup
			ShuffleSpikes(waveA)
			ShuffleSpikes(waveB)
		endif
		strswitch(method)
			case "Degree of Correlation": // Maximum degree of correlation
				MatrixCorr /DEGC waveA,waveB
				Values[i]=MatrixTrace(M_degCorr)
				break
			case "Covariance":
				MatrixCorr /COV waveA,waveB
				Values[i]=MatrixTrace(M_Covar)
				break
			//case "Coherence":
			//	MatrixCorr /COV waveA,waveB
			//	Values[i]=MatrixTrace(M_Covar)
			//	break
			case "Correlation of Sequence": // Maximum degree of correlation for the sequence (e.g. cell 5 is first, cell 3 is second, etc.)
				Make /o/n=(numpnts(waveA)) waveAIndex=p, waveBIndex=p
				Sort waveA,waveAIndex; Sort waveB,waveBIndex
				for(j=0;j<numpnts(waveAIndex);j+=1)
					waveA[waveAIndex[j]]=j
					waveB[waveBIndex[j]]=j
				endfor
				MatrixCorr /DEGC waveA,waveB
				Values[i]=MatrixTrace(M_degCorr)
				break
			case "Average Distance": // The (minimum) sum of the temporal lags for each spike
				Duplicate /o waveA waveDiff
				waveDiff=waveA-waveB
				K1=0
				V_FitOptions+=2 // Switch to minimizing absolute differences rather than the squares of differences
				CurveFit /G/Q/H="01" line waveDiff
				waveDiff-=K0
				WaveStats /Q waveDiff
				KillWaves waveA,waveB
				V_FitOptions-=2
				Values[i]=V_adev
				break
			case "Euclidean Distance": // The shortest path in n-dimensional spikes between the spike vectors
				Duplicate /o waveA waveDiff,unitVector,projection
				waveDiff=waveA-waveB; unitVector=1
				// Remove the projection, to obtain a difference vector representing the closest the original vectors could be after an equal shift of all of their elements.
				projection=MatrixDot(waveDiff,unitVector)
				waveDiff-=projection 
				Values[i]=sqrt(MatrixDot(waveDiff,waveDiff))
				break
			case "Least Squares": // Minumum least squares difference
				Duplicate /o waveA waveDiff
				waveDiff=waveA-waveB
				K1=0
				CurveFit /G/Q/H="01" line waveDiff
				waveDiff-=K0
				WaveStats /Q waveDiff
				Values[i]=V_sdev^2
				break
			default: 
				printf "Not a recognized method [CompareVectors]; method=%s\r",method
				return 0
		endswitch
		KillWaves /Z M_degCorr,M_Covar
	endfor
	value=Values[0]
	if(p_value)
		DeletePoints 0,1,Values
		if(WhichListItem(method,"Degree of Correlation;Covariance")>=0)
			Sort /R Values,Values
		else
			Sort Values,Values
		endif
		SetScale x,0,1,Values
		FindLevel /Q Values,value
		if(V_flag)
			value=NaN
		else
			value=V_LevelX
		endif
	endif
	KillWaves /Z waveA,waveB,waveAbackup,waveBbackup,waveDiff,unitVector,projection,M_degCorr,M_Covar,Values
	return value
End

// Plot the mean and standard deviation of each bin as a point in a 2D plot.    
Function MeanStDevClusters(w[,bin_size,shift])
	Wave w
	Variable bin_size
	Variable shift
	bin_size=ParamIsDefault(bin_size) ? 0.1 : bin_size
	shift=ParamIsDefault(shift) ? bin_size/2 : shift
	Variable i,left,right
	Variable length=rightx(w)-leftx(w)
	Variable num_segments=floor(length/shift)
	Make /o/n=0 SegmentMeans,SegmentStDevs
	for(i=0;i<num_segments;i+=1)
		left=leftx(w)+i*shift
		right=leftx(w)+i*shift+bin_size
		Duplicate /O/R=(left,right) w Segment
		WaveStats /Q Segment
		if(rightx(Segment)-leftx(Segment) >= bin_size)
			InsertPoints 0,1,SegmentMeans,SegmentStDevs
			SegmentMeans[0]=V_avg
			SegmentStDevs[0]=V_sdev
		endif
	endfor
	KillWaves Segment
	Display /K=1 SegmentStDevs vs SegmentMeans
	BigDots(size=2)
End

// Computes the standard deviation by doing a log transform first, and then untransforming.  
Function LogStDev(w)
	Wave w
	Duplicate /o w tempLogWave
	Variable LogMean=GeoMean(w)
	tempLogWave=log(tempLogWave)
	WaveStats /Q tempLogWave
	Variable value=sqrt(5)*V_sdev*LogMean // Sqrt(5) is a fudge factor.  I need to figure this out.  
	KillWaves /Z tempLogWave,LogVariances
	return value
End

Function UnifRnd(low,high)
	Variable low,high
	return low+abs(enoise(high-low))
End

Function /S ListTTest2(list,name)
	String list,name
	Variable i,size
	size=ItemsInList(list)
	//String list2=list
	String curr_folder=GetDataFolder(1)
	NewDataFolder /o/s root:t_test
	Make /o/n=(size) $(name+"_1"),$(name+"_2")
	Make /o/T/n=(size) $(name+"_keys")
	Wave wave1=$(name+"_1")
	Wave wave2=$(name+"_2")
	Wave /T keys=$(name+"_keys")
	String entry,numbers,number1,number2,key
	for(i=0;i<size;i+=1)
		entry=StringFromList(i,list)
		key=StringFromList(0,entry,":")
		numbers=StringFromList(1,entry,":")
		number1=StringFromList(0,numbers,",")
		number2=StringFromList(1,numbers,",")
		keys[i]=key
		wave1[i]=str2num(number1)
		wave2[i]=str2num(number2)
	endfor
	Edit /K=1
	AppendToTable keys,wave1,wave2
	ModifyTable width=46
	ModifyTable size=8
 	printf "p=.3f\r",Statttest(2,wave1,wave2)
	SetDataFolder curr_folder
	return ""
End


// Returns median value of wave w from x=x1 to x=x2.
// Pass -INF and +INF for x1 and x2 to get median of the entire wave.
Function Median1(w,x1,x2)
	Wave w
	Variable x1, x2
	Variable result
	Duplicate/R=(x1, x2) w, tempMedianWave			// Make a clone of wave
	Sort tempMedianWave, tempMedianWave			// Sort clone
	SetScale/P x 0,1,tempMedianWave
	result = tempMedianWave((numpnts(tempMedianWave)-1)/2)
	KillWaves tempMedianWave
	return result
End

// Construct a wave whose values are the median of the contents of each bin.  Returns the name of the wave.
Function /S MedianWave(w,bin_size)
	Wave w
	Variable bin_size
	Make /o/n=(ceil(numpnts(w)*dimdelta(w,0)/bin_size)) $("Median_"+NameOfWave(w))
	Wave Med=$("Median_"+NameOfWave(w))
	SetScale /P x,dimoffset(w,0),bin_size,Med
#if exists("Median")!=3
	Med=Median(w=w,x1=x-bin_size/2,x2=x+bin_size/2)
#else
	Med=Median(w,x-bin_size/2,x+bin_size/2)
#endif
	return GetWavesDataFolder(Med,2)
End

#if exists("Median")!=3
Function Median([w,x1,x2])
	Wave w
	Variable x1,x2
	if(ParamIsDefault(w))
		Wave w=CsrWaveRef(A)
	endif
	x1=ParamIsDefault(x1) ? xcsr(A) : x1
	x2=ParamIsDefault(x2) ? xcsr(B) : x2
	Duplicate /o/R=(x1,x2) w tempMedianWave
	//Sort tempMedianWave,tempMedianWave
	//WaveStats /M=1/Q tempMedianWave
	//DeletePoints V_npnts,V_numNaNs,tempMedianWave
	Extract /O tempMedianWave,tempMedianWave,numtype(tempMedianWave)==0
	Variable result=StatsMedian(tempMedianWave)//tempMedianWave[(numpnts(tempMedianWave)-1)/2]
	KillWaves tempMedianWave
	return result
End
#endif

Function Median2(w)
	Wave w
	Extract /O w,tempMedianWave,numtype(w)==0
	Variable result=StatsMedian(tempMedianWave)
	KillWaves tempMedianWave
	return result
End

Function Median3(w,p1,p2)
	Wave w
	Variable p1,p2
	Duplicate /o/R=[p1,p2] w tempMedianWave
	Sort tempMedianWave,tempMedianWave
	WaveStats /M=1/Q tempMedianWave
	DeletePoints V_npnts,V_numNaNs,tempMedianWave
	Variable result=tempMedianWave[(numpnts(tempMedianWave)-1)/2]
	KillWaves tempMedianWave
	return result
End

Function GetExpFit(name,start,nd,cursors)
	String name
	Variable start,nd,cursors
	if(cursors==1)
		start=xcsr(A)
		nd=xcsr(B)
	endif
	if(WaveExists(root:$name))
		Duplicate/o /R=(start,nd) root:$name waveToFit	
	elseif(WaveExists(root:reanalysis:$name))
		//Variable V_fitOptions=4
		//Variable V_FitError=0
		Duplicate/o /R=(start,nd) root:reanalysis:$name waveToFit		
	else
		printf "No such wave\r"
		return 0
	endif
	DeletePoints 0,x2pnt(waveToFit,start),waveToFit
	DoWindow/K Fit
	Display /N=Fit /K=1 waveToFit
	CurveFit /Q/N/W=0 exp, waveToFit (start+0.001,nd-0.001) /D
	Variable tau=(1000/K2)
	WaveStats/Q fit_waveToFit
	printf "Tau = %f\rError = %f\rSize = %f\r",tau,V_chisq/((nd-start)*(mean(waveToFit)^2)),V_max-V_min
	return tau
End

Function MeanBetweenCursors()
	Variable start=xcsr(A)
	Variable nd=xcsr(B)
	WaveStats /Q/R=(start,nd) CsrWaveRef(A)
	return V_avg
End

Function /S WaveStat([w,x1,x2,clipp,no_print,digits])
	Wave w
	Variable x1,x2,no_print,clipp
	Variable digits // Number of digits after the decimal point.  
	digits=ParamIsDefault(digits) ? 5 : digits
	if(paramisdefault(w))
		wave /z w=csrwaveref(A)
		if(!waveexists(w))
			string traces=tracenamelist("",";",1)
			variable i
			for(i=0;i<itemsinlist(traces);i+=1)
				string trace=stringfromlist(i,traces)
				wave w=tracenametowaveref("",trace)
				wavestat(w=w,x1=x1,x2=x2,clipp=clipp,no_print=no_print,digits=digits)
			endfor
			return ""
		endif
	endif
	String wave_name=NameOfWave(w)
	if((!paramisdefault(x1) || !paramisdefault(x2)) && (x1!=0 || x2!=0))
		duplicate /free/r=(paramisdefault(x1) ? leftx(w) : x1,paramisdefault(x2) ? rightx(w) : x2) w,w1
		wave w=w1
	endif
	if(numpnts(w)==0)
		if(!no_print)
			printf "%s has zero points\r",NameOfWave(w)
		endif
	else
		if(!ParamIsDefault(clipp) && clipp!=0)
			matrixop /free w=clip(w,-clipp,clipp)
		endif
		WaveStats /Q w
		String meann=num2str(RoundTo(V_avg,digits))
		String SEM=num2str(RoundTo(V_sdev/sqrt(V_npnts),digits))
		String nn=num2str(RoundTo(V_npnts,digits))
		String minn=num2str(RoundTo(V_min,digits))
		String maxx=num2str(RoundTo(V_max,digits))
		String CV=num2str(RoundTo(V_sdev/V_avg,digits))
		StatsQuantiles /Q w
		String med=num2str(RoundTo(V_median,digits))
		String lower=num2str(RoundTo(V_Q25,digits))
		String upper=num2str(RoundTo(V_Q75,digits))
		if(!no_print)
			string text=wave_name+": Mean = "+meann+" +/- "+SEM+"; Median = "+med+" ["+lower+","+upper+"]; n = "+nn+"; Min = "+minn+"; Max = "+maxx+"; CV = "+CV
			printf text
		endif
		text=meann+" +/- "+SEM+"   ("+nn+" ["+minn+","+med+","+maxx+"])"
	endif
	KillWaves /Z $"WS2temp"
	return text
End

// Reliable and extremely fast kernel density estimator for one-dimensional data;
//        Gaussian kernel is assumed and the bandwidth is chosen automatically;
//        Unlike many other implementations, this one is immune to problems
//        caused by multimodal densities with widely separated modes (see example). The
//        estimation does not deteriorate for multimodal densities, because we never assume
//        a parametric model for the data.
// INPUTS:
//     data    - a vector of data from which the density estimate is constructed;
//          n  - the number of mesh points used in the uniform discretization of the
//               interval [MIN, MAX]; n has to be a power of two; if n is not a power of two, then
//               n is rounded up to the next power of two, i.e., n is set to n=2^ceil(log2(n));
//               the default value of n is n=2^12;
//   MIN, MAX  - defines the interval [MIN,MAX] on which the density estimate is constructed;
//               the default values of MIN and MAX are:
//               MIN=min(data)-Range/10 and MAX=max(data)+Range/10, where Range=max(data)-min(data);
// OUTPUTS:
//   bandwidth - the optimal bandwidth (Gaussian kernel assumed);
//     density - column vector of length 'n' with the values of the density
//               estimate at the grid points;
//     xmesh   - the grid over which the density estimate is computed;
//             - If no output is requested, then the code automatically plots a graph of
//               the density estimate.
//        cdf  - column vector of length 'n' with the values of the cdf
//  Reference: 
// Kernel density estimation via diffusion
// Z. I. Botev, J. F. Grotowski, and D. P. Kroese (2010)
// Annals of Statistics, Volume 38, Number 5, pages 2916-2957. 

//
//  Example:
//           data=[randn(100,1);randn(100,1)*2+35 ;randn(100,1)+55];
//              kde(data,2^14,min(data)-5,max(data)+5);


//  Notes:   If you have a more reliable and accurate one-dimensional kernel density
//           estimation software, please email me at botev@maths.uq.edu.au



// Translated into Igor; J.G.G. Borst, 21 Jan 2011.
// usage: make/O/N=300 data = selectnumber(mod(p,3)-1,gnoise(1), gnoise(1)*2+35,gnoise(1)+55) 
// Make/N=400/O data_Hist
// Histogram/P/C/B={-10,.2,400} data,data_Hist
// kde(data,2^14,Wavemin(data)-5,Wavemax(data)+5)
Function kde(data,n,min_range,max_range)			// Reliable and extremely fast kernel density estimator for one-dimensional data
	Wave data
	Variable n,min_range,max_range
	
	Variable Range, R, dx, xmesh, Npnts, Sum_data, t_star, bandwidth

	//data=data(:); //make data a column vector
	if (n<0) // if n is not supplied switch to the default
	    n=2^14
	endif
	n=2^ceil(log(n)/log(2))			// round up n to the next power of 2; log
	WaveStats/Q/M=1 data
	Npnts = V_npnts						//N=length(unique(data))
	if (max_range<min_range)	 //define the default  interval [MIN,MAX]
	    Range=V_max-V_min
	    min_range=V_min-Range/10
	    max_range=V_max+Range/10
	endif
	
	// set up the grid over which the density estimate is computed
	R=max_range-min_range
	dx=R/(n-1)
	
	//bin the data uniformly using the grid defined above;
	Make/D/O/N=(n) initial_data, density, a2
	Histogram/B={min_range, dx, n} data, initial_data		//xmesh=min_range+[0:dx:R]
	Sum_data = sum(initial_data)
	initial_data/=Sum_data
	
	dct1d(initial_data) 		// discrete cosine transform of initial data
	
	// now compute the optimal bandwidth^2 using the referenced method
	// use  fzero to solve the equation t=zeta*gamma^[5](t)
	a2=(initial_data/2)^2			//a2=(a(2:end)/2).^2
	DeletePoints 0, 1, a2
	Make/O/D/N=(n-1) I_1
	I_1=(p+1)^2				//I[1:n-1]'.^2

	Make/O/N=1 pars = Npnts			//FindRoots needs a single parameter wave, so waves I_1 and a2 cannot be passed
	FindRoots/Q/L=0/H=0.1 fixed_point, pars				//t_star=fzero(@(t)fixed_point(t,Npnts,I,a2),[0,.1])
	t_star=V_root
	if (V_flag > 0)
		t_star=.28*Npnts^(-2/5)
	endif

	// smooth the discrete cosine transform of initial data using t_star
	Duplicate/O initial_data, a_t
	a_t=initial_data*exp(-p^2*pi^2*t_star/2)

	// now apply the inverse discrete cosine transform
	idct1d(density, a_t)
	density/=R

	// take the rescaling of the data into account
	bandwidth=sqrt(t_star)*R
	SetScale/P x min_range, dx,"", density

	//next lines are untranslated Matlab code	
	//if nargout==0
	//    figure(1), plot(xmesh,density)
	//end
	//% for cdf estimation
	//if nargout>3
	//    f=2*pi^2*sum(I.*a2.*exp(-I*pi^2*t_star));
	//    t_cdf=(sqrt(pi)*f*N)^(-2/3);
	//    % now get values of cdf on grid points using IDCT and cumsum function
	//    a_cdf=a.*exp(-[0:n-1]'.^2*pi^2*t_cdf/2);
	//    cdf=cumsum(idct1d(a_cdf))*(dx/R);
	//    % take the rescaling into account if the bandwidth value is required
	//    bandwidth_cdf=sqrt(t_cdf)*R;
	//end

	KillWaves/Z  initial_data, a_t, a2, pars, I_1
	
	return bandwidth
end

//################################################################
Function fixed_point(pars, t)		// this implements the function t-zeta*gamma^[l](t)
	Wave pars
	Variable t
			
	Variable out, s, K0, const, time1, f
	Variable l=7
	Variable Npnts = pars[0]
	Wave a2				//would be better to pass it
	Wave I_1
	
	Duplicate/O I_1, Itemp
	Itemp = I_1^l*a2*exp(-I_1*pi^2*t)
	f=2*pi^(2*l)*sum(Itemp)				//f=2*pi^(2*l)*sum(I.^l.*a2.*exp(-I*pi^2*t))
	for (s=l-1;s>1;s-=1)				//s=l-1:-1:2
	    K0=calc_K0product(s)/sqrt(2*pi)						//K0=prod([1:2:2*s-1])/sqrt(2*pi)
	    const=(1+(1/2)^(s+1/2))/3
	    time1=(2*const*K0/Npnts/f)^(2/(3+2*s))
	    Itemp = I_1^s*a2*exp(-I_1*pi^2*time1)
	    f=2*pi^(2*s)*sum(Itemp)
	endfor

	KillWaves/Z Itemp

	out=t-(2*Npnts*sqrt(pi)*f)^(-2/5)
	
	return out
End

//################################################################
Static Function calc_K0product(s)
	Variable s
	
	Variable K0=1, icnt=1
	Do 
		icnt +=2
		K0*=icnt
	While (icnt<2*s-1)
	
	return K0

End
	
//##############################################################
Function idct1d(outwave, data)			// computes the inverse discrete cosine transform
	Wave outwave, data			//outwave is output, data is unchanged
	
	Variable icnt, jcnt
	Variable/C unit = cmplx(0,1) 
	Variable npnts = numpnts(data)
	Duplicate/O data, tempdata			//weights 
	Make/C/O/N=(npnts) weights
	
	//Compute weights
	weights = npnts*exp(unit*p*pi/(2*npnts))				//weights = nrows*exp(i*(0:nrows-1)*pi/(2*nrows)).';
	
	//Compute x tilde using equation (5.93) in Jain
	weights*=data			//data = real(ifft(weights.*data))
	IFFT/C/Z weights
	tempdata=real(weights)
	
	//Re-order elements of each column according to equations (5.93) and (5.94) in Jain
	for (icnt=0; icnt<npnts; icnt+=2)
		outwave[icnt]=tempdata[icnt/2]			//out(1:2:npnts) = data(1:npnts/2)
	endfor
	for (icnt=1; icnt<npnts; icnt+=2)
		jcnt=npnts-(icnt-1)/2-1
		outwave[icnt]=tempdata[jcnt]			//out(2:2:npnts) = data(npnts:-1:npnts/2+1)
	endfor
	
	KillWaves/Z weights, tempdata

	//Reference:
	//A. K. Jain, "Fundamentals of Digital Image
	//Processing", pp. 150-153.
end

//##############################################################	
Function dct1d(data)		// computes the discrete cosine transform of the column vector data
	Wave data			//will be modified
	
	Variable icnt, jcnt
	Variable/C unit = cmplx(0,1) 
	Variable npnts = numpnts(data)			//[nrows,ncols]=size(data);
	Duplicate/O data, tempdata
	// Compute weights to multiply DFT coefficients
	Make/O/C/N=(npnts) weight, fftresult
	weight = 2*(exp(-unit*p*pi/(2*npnts))	)			//weight = [1;2*(exp(-unit*(1:npnts-1)*pi/(2*npnts))).'];
	weight[0] = 1
	// Re-order the elements of the columns of x; data = [ data(1:2:end,:); data(end:-2:2,:) ];
	for (icnt=0; icnt<npnts; icnt+=2)
		data[icnt/2]=tempdata[icnt]
	endfor
	for (icnt=0; icnt<npnts; icnt+=2)
		jcnt=npnts-icnt-1
		data[npnts/2+icnt/2]=tempdata[jcnt]
	endfor
	// Multiply FFT by weights;  data= real(weight.* fft(data));
	FFT/DEST=fftresult data
	
	fftresult*=weight
	data= real(fftresult)
	
	KillWaves/Z weight, tempdata, fftresult
end

// Returns stats for only those points whose partners in criteria_wave match certain criteria
Function /S WaveStats2(wave1,criteria_wave,criteria) // For now only does "greater than" as criteria
	Wave wave1
	Wave criteria_wave
	Variable criteria // The number that values of criteria_wave need to be greater than
	Duplicate wave1 temp_wave
	Variable i
	for(i=0;i<numpnts(wave1);i+=1)
		if(criteria_wave[i]<criteria)
			temp_wave[i]=nan
		endif
	endfor
	WaveStats /Q temp_wave
	String print_string=""
	print_string+="Mean = "+num2str(V_avg)+"; "
	print_string+="Num Points = "+num2str(V_npnts)+"; "
	print_string+="Max = "+num2str(V_max)+"; "
	print_string+="Min = "+num2str(V_min)+" ;"
	KillWaves temp_wave
	return "MEAN:"+num2str(V_avg)+";"+"SEM:"+num2str(V_sdev/sqrt(V_npnts))
End

Function BasicStats(w)
	Wave w
	WaveStats /Q w
	string str=num2str(V_avg)+" +/- "+num2str(V_sdev/sqrt(V_npnts))+"; n = "+num2str(V_npnts)
	printf "%s.\r",str
End

Proc GetStats(ctrlName) : ButtonControl // Get statistics for the wave segment indicated by the cursors.  
	string ctrlName
	WaveStats /M=1/R=[xcsr(A),xcsr(B)] CsrWaveRef(A)
End

Function Mean_Value()
	String traces=TraceNameList("",";", 1) // Get names of waves plotted on topmost graph
	Variable mean_value=mean($(StringFromList(0, traces)), xcsr(A), xcsr(A)+0.045) // Get mean value of current over 45 ms
	return mean_value-vcsr(B) // Subtract leak current
End	

Function DeltaY()
	return vcsr(A)-vcsr(B)
End

Function MovingAvg(half_width,cell)
	Variable half_width
	String cell
	Variable first_sweep=xcsr(A,"AnalysisWin")+1
	Variable last_sweep=xcsr(B,"AnalysisWin")+1
	Variable i,j
	Variable left,right
	if(!datafolderexists("root:reanalysis"))
		NewDataFolder /S root:reanalysis
	else
		if(!datafolderexists("root:reanalysis:movingAvg"))
			NewDataFolder /S root:reanalysis:movingAvg
		endif
	endif
	Duplicate /O $("root:cell"+cell+":sweep"+num2str(first_sweep)) root:reanalysis:movingAvg:temp_avg
	Wave temp_avg=root:reanalysis:movingAvg:temp_avg
	for(i=first_sweep;i<=last_sweep;i+=1)
		left=min(half_width,i-first_sweep)
		right=min(half_width,last_sweep-i)
		temp_avg=0
		for(j=i-left;j<=i+right;j+=1)
			Duplicate /O $("root:cell"+cell+":sweep"+num2str(j)) root:reanalysis:movingAvg:to_be_added
			Wave to_be_added=root:reanalysis:movingAvg:to_be_added
			temp_avg+=to_be_added
			to_be_added=0
		endfor
		temp_avg/=(left+right+1)
		Duplicate /O temp_avg $("root:reanalysis:movingAvg:"+cell+"_"+num2str(i))
	endfor
End

threadsafe function SEM(w)
	wave w
	if(numpnts(w)<2)
		return NaN
	endif
	wavestats /q w	
	return v_sdev/sqrt(V_npnts)
End

Function Stat()
	WaveStats /Q/R=(xcsr(A),xcsr(B)) CsrWaveRef(A)
	string str=num2str(V_avg)+" +/- "+num2str(V_sdev/sqrt(V_npnts))
	printf "%s.\r",str
End

Function ModelSynapse(xx,rise,decay1,decay2,ampl[,x_offset,y_offset])
	Variable xx,rise,decay1,decay2,ampl
	Variable x_offset,y_offset
	x_offset=ParamIsDefault(x_offset) ? 0 : x_offset
	y_offset=ParamIsDefault(y_offset) ? 0 : y_offset
	if(xx<=x_offset)
		return y_offset
	else
		return y_offset+ampl*(1-exp(-(xx-x_offset)/rise))*exp(-(xx-x_offset)/decay1)*exp(-(xx-x_offset)/decay2)
	endif
End

// Takes a wave, and produces a wave of the same length and scaling, gnoiseWave
Function MakeGNoise(wave_template,avg,std)
	Wave wave_template
	Variable avg,std // Mean and standard deviation
	Duplicate /o wave_template gnoiseWave
	Variable i
	for(i=0;i<numpnts(gnoiseWave);i+=1)
		gnoiseWave[i]=avg+gnoise(std)
	endfor
End

// A test to compare two samples data sets; Uses the bootstrap method
Function BootTest(data1,data2[,trials])
	Wave Data1
	Wave Data2
	Variable trials
	if(ParamIsDefault(trials))
		trials=10000
	endif
	String curr_folder=GetDataFolder(1)
	NewDataFolder /o/s root:StatTests
	Make /o/n=(numpnts(Data1)+numpnts(Data2)) Pooled
	Variable i,j
	for(i=0;i<numpnts(Data1);i+=1)
		Pooled[i]=Data1[i]
	endfor
	for(i=0;i<numpnts(Data2);i+=1)
		Pooled[i+numpnts(Data1)]=Data2[i]
	endfor
	Make /o/n=(trials) TrialDiffs
	Duplicate /o Data1 SampleData1
	Duplicate /o Data2 SampleData2
	Variable mean1,mean2
	for(i=0;i<trials;i+=1)
		for(j=0;j<numpnts(Data1);j+=1)
			SampleData1[j]=Pooled[floor(abs(enoise(numpnts(Pooled))))]
		endfor
		for(j=0;j<numpnts(Data2);j+=1)
			SampleData2[j]=Pooled[floor(abs(enoise(numpnts(Pooled))))]
		endfor
		WaveStats /Q SampleData1; mean1=V_avg
		WaveStats /Q SampleData2; mean2=V_avg
		TrialDiffs[i]=mean2-mean1
	endfor
	WaveStats /Q Data1; mean1=V_avg; 
	printf "%s : %f +/- %f.\r",NameOfWave(Data1),V_avg,V_sdev/sqrt(V_npnts)
	WaveStats /Q Data2; mean2=V_avg
	printf "%s : %f +/- %f.\r",NameOfWave(Data2),V_avg,V_sdev/sqrt(V_npnts)
	Variable actual_diff=mean2-mean1
	Sort TrialDiffs,TrialDiffs
	FindLevel /Q TrialDiffs,actual_diff
	printf "p = %f.\r",min(V_LevelX/trials,1-V_LevelX/trials)
	SetDataFolder curr_folder
End

// Returns the mean and sem across columns from a matrix.  
// The mean and sem will be waves, with one point for every row in the matrix
Function MatrixStats(Matrix[,nonstationary])
	Wave Matrix
	Variable nonstationary // The SEM is calculated in the nonstationary way.  
	Variable plot // Set to 1 if you want to append the mean and sem waves to the top graph
	Variable i
	Make /o/n=(dimsize(Matrix,0)) $(NameOfWave(Matrix)+"_Mean"), $(NameOfWave(Matrix)+"_SEM")
	Wave Meen=$(NameOfWave(Matrix)+"_Mean") // Purposely misspelled to avoid confusing Igor
	Wave SEM=$(NameOfWave(Matrix)+"_SEM")
	Meen=NaN;SEM=NaN
	for(i=0;i<dimsize(Matrix,0);i+=1)
		Duplicate /o/R=[i,i][] Matrix Row // Grab a row
		Redimension /n=(dimsize(Matrix,1)) Row // Fixes a problem where Igor still thinks w is 2D
		WaveStats /Q Row; Variable points=V_npnts
		Meen[i]=V_avg
		if(V_npnts==0) // Calculate the SEM normally if there are is at least one non-NaN values.  Otherwise, return NaN
			SEM[i]=NaN
		else
			if(nonstationary)
				SetScale /P x,0,1,Row
				Sort Row,Row
				Differentiate /METH=1 Row
				Redimension /n=(numpnts(Row)-1) Row
				WaveStats /Q Row
				SEM[i]=(V_sdev/sqrt(points))/sqrt(2)
			else
				SEM[i]=V_sdev/sqrt(points)
			endif
		endif
	endfor
	KillWaves Row
End

// Computes the correlation coefficient within a window of 'win_size' every 'interval' units for two signals.  
Function Correlate2(signal1,signal2[,big_win,small_win,interval])
	Wave signal1,signal2
	Variable big_win,small_win,interval
	big_win=ParamIsDefault(big_win) ? 0.5 : big_win // The width of the window from which mean and variance are computed.
	small_win=ParamIsDefault(small_win) ? 0.5 : small_win // The width of the window within which the samples are compared, given the mean and variance in big_win.
	interval=ParamIsDefault(interval) ? 0.05 : interval
	Variable duration=min(WaveDuration(signal1),WaveDuration(signal2))
	Variable start=min(leftx(signal1),leftx(signal2))
	Variable finish=max(rightx(signal1),rightx(signal2))
	Variable i,index=0,points1,points2,mean1,mean2,sdev1,sdev2,normalization,big_left,big_right,small_left,small_right,length,correlation
	Make /o/n=3 PearsonOutput=NaN
	
	String name=CleanUpName("CorrWin_"+NameOfWave(signal1)+"_"+NameOfWave(signal2),1)
	NewDataFolder /O root:reanalysis
	Make /o/n=((finish-start)/interval) root:reanalysis:$name=NaN // Make a result wave.
	Wave result=root:reanalysis:$name
	SetScale /P x,start,interval,result
	Make /o WindowTemplate
	//CopyScales /P signal1,WindowTemplate
	for(i=start;i<=finish;i+=interval)
		small_left=max(start,i-small_win/2)
		small_right=min(finish,i+small_win/2)
		WaveStats /Q /M=1 /R=(small_left,small_right) signal1; points1=V_npnts
		WaveStats /Q /M=1 /R=(small_left,small_right) signal2; points2=V_npnts
		if(points1!=points2)
			printf "Unequal number of valued points between %f and %f.\r",small_left,small_right
		else
			Duplicate /O/R=[x2pnt(signal1,small_left),x2pnt(signal1,small_right)] signal1 piece1; 
			Duplicate /O/R=[x2pnt(signal2,small_left),x2pnt(signal2,small_right)] signal2 piece2;
			//Make /C/o/n=(numpnts(piece1)) tempCorr,tempCorr2
			if(big_win==small_win)
				// Using statPearsonTest (equal weight to all points in the window)
				statPearsonTest(piece1,piece2,PearsonOutput)
				correlation=PearsonOutput[0]
			else // By hand, using different window sizes.  Also allows for a non-rectangular window (which doesn't work yet).  
				big_left=max(start,i-big_win/2)
				big_right=min(finish,i+big_win/2)
				WaveStats /Q /R=(big_left,big_right) signal1; mean1=V_avg; sdev1=V_sdev
				WaveStats /Q /R=(big_left,big_right) signal2; mean2=V_avg; sdev2=V_sdev
				Wave CorrelationDiagonal=$CorrelationDiag(piece1,piece2,mean1=0,mean2=0,sdev1=sdev1,sdev2=sdev2)
				length=numpnts(piece1)
				Redimension /n=(length) WindowTemplate
				WindowTemplate=1//(length/2)-abs(x-length/2+1/2) // A triangular window. (Doesn't work)
				CorrelationDiagonal*=WindowTemplate
				CorrelationDiagonal/=(mean1*mean2)
				correlation=sum(CorrelationDiagonal)/(mean(WindowTemplate)) // Normalize according to the area of the window.  
			endif
			result[index]=correlation // The correlation coefficient
			index+=1
		endif
	endfor
	KillWaves /Z PearsonOutput,CorrelationDiagonal,WindowTemplate//,tempCorr,tempCorr2
End

// Produces the diagonal of the correlation matrix (without computing the whole matrix).  This diagonal should sum to the correlation coefficient r.  
Function /S CorrelationDiag(signal1,signal2[,mean1,mean2,sdev1,sdev2])
	Wave signal1,signal2
	Variable mean1,mean2,sdev1,sdev2
	Variable length=numpnts(signal1)
	WaveStats /Q signal1; mean1=ParamIsDefault(mean1) ? V_avg : mean1; sdev1=ParamIsDefault(sdev1) ? V_sdev : sdev1
	WaveStats /Q signal2; mean2=ParamIsDefault(mean2) ? V_avg : mean2; sdev2=ParamIsDefault(sdev2) ? V_sdev : sdev2
	Variable normalization=sdev1*sdev2*(length-1)
	Make /o/n=(length) CorrelationDiagonal=(signal1[p]-mean1)*(signal2[p]-mean2)/normalization
	return GetWavesDataFolder(CorrelationDiagonal,2)
End

// Find the correlation between wave1 and wave2 by first subtracting off the means (avoids the triangular correlation shape).  
Function Correlate3(wave1,wave2)
	Wave wave1,wave2
	Duplicate /o wave1, WavesCorrelated
	Duplicate /o wave2, WavesCorrelated2
	WaveStats /Q/M=1 WavesCorrelated
	WavesCorrelated-=V_avg
	WaveStats /Q/M=1 WavesCorrelated2
	WavesCorrelated2-=V_avg
	Correlate WavesCorrelated2,WavesCorrelated
	Display /K=1 WavesCorrelated
	KillWaves /Z WavesCorrelated2
End

// Correlates two spike trains (where wave1 and wave2 are spike times).  
Function CorrelateSpikeTrains(wave1,wave2[,max_lag,bin_width])
	Wave wave1,wave2
	Variable max_lag,bin_width // The range of lags (above and below 0) and the width of bins for the correlogram.  
	max_lag=ParamIsDefault(max_lag) ? 10 : max_lag
	bin_width=ParamIsDefault(bin_width) ? 0.01 : bin_width
	Make /FREE/n=(numpnts(wave1),numpnts(wave2)) TrainDiffs
	TrainDiffs=wave1[p]-wave2[q]
	Redimension /n=(numpnts(wave1)*numpnts(wave2)) TrainDiffs
	String name=CleanUpName("c_"+NameOfWave(wave1)+NameOfWave(wave2),0)
	Make /o/n=0 $(name) /WAVE=SpikeTrainCorrelation
	Histogram /B={-max_lag+bin_width/2,bin_width,(2*max_lag/bin_width)-1} TrainDiffs, SpikeTrainCorrelation
	// Normalize by number of spikes.  Assumes middle bin will contain only zero lag spikes.  Middle bin will now have a value of 1 for auto-correlation.  
	SpikeTrainCorrelation /= (sqrt(numpnts(wave1)*numpnts(wave2))) 
	Display /K=1 SpikeTrainCorrelation
	Label bottom "Lag (seconds)"
End

// Returns the standard deviation of a wave
Function StDev(w[,x1,x2])
	Wave w
	Variable x1,x2
	x1=ParamIsDefault(x1) ? leftx(w) : x1
	x2=ParamIsDefault(x2) ? rightx(w) : x2
	WaveStats /Q /R=(x1,x2) w
	return V_sdev
End

// Generates a cross-correlogram, normalized so that the values are between -1 and 1.  
Function /S Correlogram(wave1,wave2[,left,right])
	Wave wave1,wave2
	Variable left,right
	left=ParamIsDefault(left) ? min(leftx(wave1),leftx(wave2)) : left 
	right=ParamIsDefault(right) ? max(rightx(wave1),rightx(wave2)) : right 
	Duplicate /o /R=(left,right) wave1,waveA; WaveStats /Q waveA
	waveA-=V_avg; Variable sdev_1=V_sdev,points1=V_npnts
	Duplicate /o /R=(left,right) wave2,waveB; WaveStats /Q waveB
	waveB-=V_avg;Variable sdev_2=V_sdev,points2=V_npnts
	String name=CleanupName("Correlogram_"+NameOfWave(wave1)+"_"+NameOfWave(wave2),1)
	NewDataFolder /o root:reanalysis
	Duplicate /o waveB root:reanalysis:$name
	Wave Correlogram=root:reanalysis:$name
	Correlate waveA,Correlogram
	Correlogram/=((min(points1,points2)-1)*sdev_1*sdev_2)
	CenterWave(Correlogram)
	KillWaves /Z waveA,waveB
	return GetWavesDataFolder(Correlogram,2)
End

Function RegressYvsX(y,x)
	String y,x
	SVar file_names=file_names
	Variable i,j
	String name
	KillWaves Coeffs,Sigmas
	Make /o/n=(1,3) Coeffs,Sigmas
	for(i=0;i<ItemsInList(file_names);i+=1)
		name=StringFromList(i,file_names)
		Duplicate /o $(name+"_"+x) X_Wave
		Duplicate /o $(name+"_"+y) Y_Wave
		j=0
		Do  
			if(IsNaN(X_Wave[j]) || IsNaN(Y_Wave[j])) // Get rid of NaNs which screw up curve fitting. 
				DeletePoints j,1,X_Wave,Y_Wave 
			elseif(X_Wave[j]>1) // Get rid of values greater than 1 second
				DeletePoints j,1,X_Wave,Y_Wave 
			else
				j+=1
			endif
		While(j<numpnts(X_Wave))
		if(numpnts(X_Wave)>2)
			Display /K=1 /N=$("W_"+name)
			AppendToGraph Y_Wave vs X_Wave
			ModifyGraph log(bottom)=1, log(left)=1,mode=2, lsize=3
			K0=3;K1=1;K2=-1
			CurveFit /G/Q Power Y_Wave /X=X_Wave /D 
			Redimension /n=(i+1,3) Coeffs,Sigmas
			Wave W_coef=W_coef; Wave W_sigma=W_sigma
			Coeffs[i][]=W_coef[q]
			Sigmas[i][]=W_sigma[p]
		endif
	endfor
	//KillWaves X_Wave,Y_Wave
End

// Computes mean of each of a list of features for each cell.  Puts in waves called Mean_X and SEM_X where X is the name of the feature
Function FeatureStats(features)
	String features
	Wave /T File_Name
	Variable i,j; String feature,cell
	for(i=0;i<numpnts(File_Name);i+=1)
		feature=StringFromList(i,features)
		Make /o/n=(numpnts(File_Name)) $("Mean_"+feature)=NaN, $("SEM_"+feature)=NaN
		Wave MeanWave=$("Mean_"+feature)
		Wave SEMWave=$("SEM_"+feature)
		for(j=0;j<numpnts(MeanWave);j+=1)
			cell=File_Name[j]
			WaveStats /Q root:$(cell+"_"+feature)
			MeanWave[j]=V_avg
			SEMWave[j]=V_sdev/sqrt(V_npnts)
		endfor
	endfor
End

// Puts p-values up for all traces compared to the provided control trace
Function GraphTTest(control_name[,type,no_textbox])
	String control_name
	Variable type // The type of test (0=normal, 1=unequal variances, 2=paired)
	Variable no_textbox
	String all_traces=TraceNameList("",";",3)
	String control_trace=StringFromList(0,ListMatch(all_traces,control_name))
	//String other_traces=RemoveFromList(control_trace,all_traces)
	Variable i,p_val,red,green,blue
	String trace, textbox_name
	Wave ControlWave=TraceNameToWaveRef("",control_trace)
	Make /o/n=(ItemsInList(all_traces)) PVals=NaN
	for(i=0;i<ItemsInList(all_traces);i+=1)
		trace=StringFromList(i,all_traces)
		printf "Computing p-value for %s.\r",trace
		if(!StringMatch(trace,control_trace))
			GetTraceColor(trace,red,green,blue)
			Wave OtherWave=TraceNameToWaveRef("",trace)
			p_val=RoundTo(BootMean(ControlWave,OtherWave),3)
			if(!no_textbox)
				textbox_name="p_"+num2str(WhichListItem(trace,all_traces))
				TextBox /G=(red,green,blue) /N=$textbox_name "p = "+num2str(p_val)
			endif
			PVals[i]=p_val
		endif
	endfor
End

Function ListTTest(wave_list,control_name)
	String wave_list,control_name
	String control=StringFromList(0,ListMatch(wave_list,control_name))
	Variable i,p_val; String name
	Make /o/n=(ItemsInList(wave_list)) PVals=NaN
	for(i=0;i<ItemsInList(wave_list);i+=1)
		name=StringFromList(i,wave_list)
		if(!StringMatch(name,control))
			Wave OtherWave=$name
			p_val=RoundTo(BootMean($control,OtherWave),3)
			PVals[i]=p_val
		endif
	endfor
End

// Uses the bootstrap technique to see if means are significantly different.  Returns a p-value.  
// If you use 'median', make sure that 'Wave1' and 'Wave2' have no NaNs, because they will be counted in the sorting to find the median.  
Function BootMean(Wave1,Wave2[,num_iterations,median])
	Wave Wave1,Wave2
	Variable num_iterations
	Variable median // Use the median instead of the mean.  
	if(ParamIsDefault(num_iterations))
		num_iterations=10000
	endif
	Concatenate /o/np {Wave1,Wave2}, GrandWave
	Duplicate /o Wave1 Wave1_samp
	Duplicate /o Wave2 Wave2_samp
	Variable size1=numpnts(Wave1)
	Variable size2=numpnts(Wave2)
	Variable grand_size=size1+size2
	Variable iteration,i,index
	Make /o/n=(num_iterations) BootStrapMeanDiffs
	// Method 1
//	Make /o/n=(grand_size*num_iterations) MassiveWave
//	MassiveWave=grandwave[floor(abs(enoise(grand_size)))]
//	for(iteration=0;iteration<num_iterations;iteration+=1)
//		WaveStats /Q /R=[iteration*grand_size,iteration*grand_size+size1-1] MassiveWave; Variable mean1=V_avg
//		WaveStats /Q /R=[iteration*grand_size+size1,iteration*grand_size+grand_size-1] MassiveWave; Variable mean2=V_avg
//		BootStrapMeanDiffs[iteration]=mean1-mean2
//	endfor

	for(i=0;i<num_iterations;i+=1) // Use this loop only until the memory leak for StatsResample with /WS and /SQ is fixed.  
		if(median)
			//StatsResample /Q/N=(size1) /SQ=0 /ITER=(num_iterations) GrandWave; Duplicate /o M_StatsQuantilesSamples, BootSamples1
			StatsResample /Q/N=(size1) GrandWave; WaveStats /Q/M=1 W_Resampled; Variable mean1=V_avg
			//StatsResample /Q/N=(size1) /SQ=0 /ITER=(num_iterations) GrandWave; Duplicate /o M_StatsQuantilesSamples, BootSamples2
			StatsResample /Q/N=(size1) GrandWave; WaveStats /Q/M=1 W_Resampled; Variable mean2=V_avg
			//BootStrapMeanDiffs=BootSamples1[2][p]-BootSamples2[2][p]
			BootStrapMeanDiffs[i]=mean1-mean2
		else
			//StatsResample /Q/N=(size1) /WS=1 /ITER=(num_iterations) GrandWave; Duplicate /o M_WaveStatsSamples, BootSamples1
			StatsResample /Q/N=(size1) GrandWave; Variable med1=StatsMedian(W_Resampled)
			//StatsResample /Q/N=(size2) /WS=1 /ITER=(num_iterations) GrandWave; Duplicate /o M_WaveStatsSamples, BootSamples2
			StatsResample /Q/N=(size1) GrandWave; Variable med2=StatsMedian(W_Resampled)
			//BootStrapMeanDiffs=BootSamples1[3][p]-BootSamples2[3][p]
			BootStrapMeanDiffs[i]=med1-med2
		endif
	endfor
	KillWaves /Z BootSamples1,BootSamples2,M_WaveStatsSamples,M_StatsQuantilesSamples,W_Resampled
	
	// Method 2
//	for(iteration=0;iteration<num_iterations;iteration+=1)
//		Wave1_samp=grandwave[floor(abs(enoise(grand_size)))] // Sample with replacement
//		Wave2_samp=grandwave[floor(abs(enoise(grand_size)))]
//		WaveStats /Q Wave1_samp; mean1=V_avg
//		WaveStats /Q Wave2_samp; mean2=V_avg
//		BootStrapMeanDiffs[iteration]=mean1-mean2
//	endfor
	
	Sort BootStrapMeanDiffs,BootStrapMeanDiffs
	if(median)
		mean1=StatsMedian(Wave1)
		mean2=StatsMedian(Wave2)
	else
		WaveStats /Q Wave1; mean1=V_avg
		WaveStats /Q Wave2; mean2=V_avg
	endif
	Variable actual_mean=mean1-mean2
	FindLevel /Q BootStrapMeanDiffs, actual_mean
	if(!V_flag)
		Variable p=min(V_LevelX,num_iterations-V_LevelX)/num_iterations
	else
		WaveStats /Q/M=1 BootStrapMeanDiffs
		if(actual_mean > V_max || actual_mean < V_min)
			p=0
		endif
	endif
	KillWaves /Z GrandWave,Wave1_samp,Wave2_samp,BootStrapMeanDiffs
	return p
End

// Uses the bootstrap technique to generate a p-value for a ratio of means 'ratio' of 'n1' random samples and 'n2' random samples of wave 'w'.  
Function BootMeanRatio(w1,n1,n2,ratio[,w2,iter])
	Wave w1,w2
	Variable n1,n2,ratio,iter
	if(ParamIsDefault(iter))
		iter=10000
	endif

	StatsResample /Q/N=(n1)/ITER=(iter)/WS=1 w1
	Duplicate /FREE M_WaveStatsSamples,SampleStats1

	if(ParamIsDefault(w2))
		StatsResample /Q/N=(n2)/ITER=(iter)/WS=1 w1
	else
		StatsResample /Q/N=(n2)/ITER=(iter)/WS=1 w2
	endif
	Duplicate /FREE M_WaveStatsSamples,SampleStats2
	
	MatrixOp /FREE Ratios=(row(SampleStats2,3)/row(SampleStats1,3))^t
	KillWaves /Z M_WaveStatsSamples,W_Resampled
	
	Sort Ratios,Ratios
	SetScale x,0,1,Ratios
	FindLevel /Q Ratios,ratio
	Duplicate /o Ratios,$"Ratios2"
	if(!V_flag)
		Variable p=min(V_LevelX,1-V_LevelX)
	else
		WaveStats /Q/M=1 Ratios
		if(ratio > V_max || ratio < V_min)
			p=0
		endif
	endif
	
	return p
End

Function Histogram3(num_bins,w[,log10,graph])
	Variable num_bins
	Wave w
	Variable log10,graph // Graph=0 is for no graphing, 1 is for a new graph, 2 is for appending
	if(ParamIsDefault(graph))
		graph=1
	endif
	Make /o/n=(num_bins) $(NameOfWave(w)+"_hist")
	if(!ParamIsDefault(log10) && log10==1)
		w=log(w)
	endif
	Histogram /B=1 w, $(NameOfWave(w)+"_hist")
	if(!ParamIsDefault(log10) && log10==1)
		w=10^w
	endif
	if(graph)
		if(graph==1)
			Display /K=1 $(NameOfWave(w)+"_hist")
		elseif(graph==2)
			AppendToGraph $(NameOfWave(w)+"_hist")
		endif
		ModifyGraph mode($(NameOfWave(w)+"_hist"))=5 // Bars
	endif
End

Function /S MeanSEM(w)
	Wave w
	WaveStats /Q w
	return num2str(V_avg)+" +/- "+num2str(V_sdev/sqrt(V_npnts))
End

Function /S PoissSurpriseBatch(SpikeTrain)
	Wave SpikeTrain
	String numbursts_name=CleanUpName("NumBursts_"+NameOfWave(SpikeTrain),0)
	Make /o/n=20 $numbursts_name=NaN
	Wave NumBursts=$numbursts_name
	Variable i
	for(i=0;i<20;i+=1)
		NumBursts[i]=PoissSurprise(SpikeTrain,rate=0.1,thresh=i+1)
	endfor
	SetScale x,1,20,NumBursts
	return numbursts_name
End

// Take a spike train and returns a string containing the indices of the start and end points of each burst
// Uses the Poisson Surprise method
Function PoissSurprise(SpikeTrain[,rate,min_spikes,thresh,total_time,raw_wave])
	Wave SpikeTrain
	Variable rate,min_spikes,thresh,total_time
	Wave raw_wave
	Duplicate /o SpikeTrain Train
	DeleteNans(Train)
	min_spikes=ParamIsDefault(min_spikes) ? 2 : min_spikes
	thresh=ParamIsDefault(thresh) ? 1.5 : thresh
	total_time=ParamIsDefault(total_time) ? Train[numpnts(Train)-1] : total_time
	Variable i,j,index,start,duration,count,high_count,prob,S
	rate=ParamIsDefault(rate) ? numpnts(Train)/total_time : rate
	String burstsizes_name=CleanupName("burstsizes_"+NameOfWave(SpikeTrain),1)
	String bursttimes_name=CleanupName("bursttimes_"+NameOfWave(SpikeTrain),1)
	String burstduration_name=CleanupName("burstduration_"+NameOfWave(SpikeTrain),1)
	String burstinterval_name=CleanupName("burstinterval_"+NameOfWave(SpikeTrain),1)
	String burstrate_name=CleanupName("burstrate_"+NameOfWave(SpikeTrain),1)
	Make /o/n=0 $burstsizes_name,$bursttimes_name,$burstduration_name,$burstinterval_name,$burstrate_name
	Wave BurstSize=$burstsizes_name
	Wave BurstTimes=$bursttimes_name
	Wave BurstDuration=$burstduration_name
	Wave BurstInterval=$burstinterval_name
	Wave BurstRate=$burstrate_name
	if(!ParamIsDefault(raw_wave))
		Duplicate /o raw_wave Surprise; Surprise=-50
	else
		Make /o/n=0 Surprise
	endif
	i=0;j=i+min_spikes-1
	Do
		S=1
		for(j=j;j<numpnts(Train);j+=1)
			prob=PoissCumulProb(j-i,Train[j]-Train[i],rate)
			if(prob>=S)
				j-=1
				break
			endif
			S=prob
		endfor
		j=min(j,numpnts(Train)-1) // If j has been augments beyond the last spike, set it to the last spike
		for(i=i;j-i>=min_spikes-1;i+=0)
			i+=1
			prob=PoissCumulProb(j-i,Train[j]-Train[i],rate)
			if(prob>=S)
				i-=1
				break 
			endif
			S=prob
		endfor
		count=j-i+1
		if(log(S)<-thresh)
			Redimension /n=(numpnts(BurstSize)+1) BurstSize,BurstDuration,BurstInterval
			Redimension /n=(dimsize(BurstTimes,0)+1,2) BurstTimes
			BurstSize[numpnts(BurstSize)-1]=count
			BurstTimes[dimsize(BurstTimes,0)-1][]={{Train[i]},{Train[j]}}
			//Surprise[x2pnt(Surprise,Train[i]),x2pnt(Surprise,Train[j])]=50
		endif
		i=j+1
		j=i+min_spikes-1
	While(i<numpnts(Train))
	//Sort BurstSize,BurstSize
	SetScale /I x,0,1,BurstSize
	BurstDuration=BurstTimes[p][1]-BurstTimes[p][0]
	BurstInterval=BurstTimes[p][0]-BurstTimes[p-1][1]; BurstInterval[0]=NaN
	BurstRate=BurstSize/BurstDuration
	return numpnts(BurstSize)
End

Function KS(data1,data2)
	Wave data1,data2
	Extract/O data1,dataA,numtype(data1) == 0
	Extract/O data2,dataB,numtype(data2) == 0
	Sort dataA,dataA; Sort dataB,dataB
	Variable low=min(dataA[0],dataB[0])
	Variable high=max(dataA[numpnts(dataA)-1],dataB[numpnts(dataB)-1])	
	Wave InvertA=Invert(dataA,lo=low,hi=high)
	Wave InvertB=Invert(dataB,lo=low,hi=high)
	//Display /K=1 InvertA,InvertB
	WaveStats /Q InvertA; InvertA/=V_max
	WaveStats /Q InvertB; InvertB/=V_max
	InvertA-=InvertB
	WaveTransform /O abs InvertA
	WaveStats /Q InvertA
	KillWaves /Z dataA,dataB,InvertA,InvertB
	return V_max
End

// StatsResample has a memory leak as of Igor 6.10b080303, so don't use this function.  
Function BootKS(wave1,wave2[,num_iterations])
	Wave wave1,wave2
	Variable num_iterations
	num_iterations=ParamIsDefault(num_iterations) ? 1000 : num_iterations
	Concatenate /O/NP {wave1,wave2}, GrandWave
	Duplicate /o wave1 BootSamples1
	Duplicate /o wave2 BootSamples2
	Variable i
	Variable size1=numpnts(wave1),size2=numpnts(wave2)
	Variable points=size1+size2
	Make /o/n=(num_iterations) KSVals=NaN
	//Display /K=1 BootSamples1,BootSamples2
	for(i=0;i<num_iterations;i+=1)
		StatsResample /Q/N=(size1) GrandWave; Duplicate /o W_Resampled, BootSamples1
		StatsResample /Q/N=(size2) GrandWave; Duplicate /o W_Resampled, BootSamples2
		//BootSamples1=GrandWave[floor(abs(enoise(points)))]
		//BootSamples2=GrandWave[floor(abs(enoise(points)))]
		SetScale x,0,1,BootSamples1,BootSamples2
		KSVals[i]=KS(BootSamples1,BootSamples2)
		//Sort BootSamples1,BootSamples1
		//Sort BootSamples2,BootSamples2
		//DoUpdate
	endfor
	Sort KSVals,KSVals
	SetScale x,1,0,KSVals
	Duplicate /o wave1 waveA
	Duplicate /o wave2 waveB
	SetScale x,0,1,waveA,waveB
	Variable actual_KS=KS(waveA,waveB)
	KillWaves /Z waveA,waveB
	//Display /K=1 KSVals
	FindLevel /Q KSVals,actual_KS
	Variable p_value=V_LevelX < 0.5 ? V_LevelX : 1-V_LevelX
	printf "KS Statistic is:%f; p = %f.\r",actual_KS,V_LevelX
	//Display /K=1 KSVals
	KillWaves /Z BootSamples1,BootSamples2,W_Resampled,KSVals
	return V_LevelX
End

// Probability of n events in time T given rate r
Function PoissProb(n,T,r)
	Variable n,T,r
	return ((r*t)^n)*exp(-r*T)/factorial(n)
End

// Probability of at least n events in time T given rate r
Function PoissCumulProb(n,T,r)
	Variable n,T,r
	Variable i,summ=0
	Make /o/D/n=(n) PoissVals
	for(i=0;i<n;i+=1)
		PoissVals[i]=((r*t)^i)*exp(-r*T)/factorial(i)
	endfor
	//return max(PoissProb(n,T,r),1-sum(PoissVals)) // This max function is needed to due to rounding errors in Igor
	if(1-sum(PoissVals)>10^-15)
		return 1-sum(PoissVals)
	else
		return PoissProb(n,T,r)
	endif
End

Function /WAVE MakeCorrelatedNoises(numPoints,cov)
	Variable numPoints // The number of signals/repetitions/trials.  
	Wave cov // Covariance matrix. 
	
	variable numNoises=dimsize(cov,0)
	make /free/n=(numNoises,numPoints) gaussNoise=gnoise(1)
	matrixop /free CorrelatedNoises = (chol(cov)^t x gaussNoise)^t
	return CorrelatedNoises
End

// Makes a joint histogram.  Assumes that the destination wave // has already been scaled appropriately.  
Threadsafe Function JointHistogram_(Source1,Source2,Dest)
	Wave Source1,Source2,Dest
	
	Dest=0
	Variable i
	for(i=0;i<numpnts(Source1);i+=1)
  		Variable xx=(Source1[i]-dimoffset(Dest,0))/dimdelta(Dest,0)
  		Variable yy=(Source2[i]-dimoffset(Dest,1))/dimdelta(Dest,1)
  		Dest[xx][yy]+=1
	endfor
End

// Makes a joint histogram.  Assumes that the destination wave has already been scaled appropriately.  
Threadsafe Function JointHistogram2_(w1,w2,hist,j,nthreads)
	WAVE w1,w2,hist
	variable j,nthreads	
	
	variable i,points=numpnts(w1)
	for(i=j*points/nthreads;i<(j+1)*points/nthreads;i+=1)
  		Variable xx=(w1[i]-dimoffset(hist,0))/dimdelta(hist,0)
  		Variable yy=(w2[i]-dimoffset(hist,1))/dimdelta(hist,1)
  		hist[xx][yy]+=1
	endfor
End

Function JointHistogram2(w1,w2,hist)
	WAVE w1,w2,hist	
	
	Variable i,nthreads= ThreadProcessorCount
	variable mt= ThreadGroupCreate(nthreads)
	
	for(i=0;i<nthreads;i+=1)
		ThreadStart mt,i,JointHistogram2_(w1,w2,hist,i,nthreads)
	endfor
	do
		variable tgs= ThreadGroupWait(mt,100)
	while( tgs != 0 )
	variable dummy= ThreadGroupRelease(mt)
End

// Makes a joint histogram.  Assumes that the destination wave has already been scaled appropriately.  
// This is about 4x faster than JointHistogram.  
Function JointHistogram3(w0,w1,hist[,normalize])
	WAVE w0,w1,hist
	variable normalize
	
	variable bins0=dimsize(hist,0)
	variable bins1=dimsize(hist,1)
	variable n=numpnts(w0)
	variable left0=dimoffset(hist,0)
	variable left1=dimoffset(hist,1)
	variable right0=left0+bins0*dimdelta(hist,0)
	variable right1=left1+bins1*dimdelta(hist,1)
	
	// Scale between 0 and the number of bins to create an index wave.  
	if(ThreadProcessorCount<4) // For older machines, matrixop is faster. 
		matrixop /free idx1=floor(bins0*(w0-left0)/(right0-left0))
		matrixop /free idx2=floor(bins1*(w1-left1)/(right1-left1))
		idx1=idx1<0 || idx1>=bins0 ? nan : idx1
		idx2=idx2<0 || idx2>=bins1 ? nan : idx2
		make /free/n=(n) idx=idx1+bins0*idx2
	else // For newer machines with many cores, multithreading with make is faster.  
		make /free/n=(n) idx,idx1,idx2
		multithread idx1=floor(bins0*(w0-left0)/(right0-left0))
		multithread idx2=floor(bins1*(w1-left1)/(right1-left1))
		multithread idx1=idx1<0 || idx1>=bins0 ? nan : idx1
		multithread idx2=idx2<0 || idx2>=bins1 ? nan : idx2
		multithread idx=idx1+bins0*idx2
	endif
	
	// Compute the histogram and redimension it.  
	histogram /b={0,1,bins0*bins1} idx,hist
	redimension /n=(bins0,bins1) hist // Redimension to 2D.  
	setscale x,left0,right0,hist // Fix the histogram scaling in the x-dimension.  
	setscale y,left1,right1,hist // Fix the histogram scaling in the y-dimension.  
	//variable summ=sum(hist)
	if(normalize)
		hist/=n // Normalize.  
	endif
End

function /wave JointHistogram4(xx,yy,xBins,yBins)
	wave xx,yy,xBins,yBins
	
	make /free/n=(numpnts(xBins)-1,numpnts(yBins)-1) result
	variable delta_x = xBins[1]-xBins[0]
	variable delta_y = yBins[1]-yBins[0]
#if exists("JointHistogram")
	JointHistogram /dest=result /xbwv=xBins /ybwv=yBins /e xx,yy
	setscale /p x,xBins[0],delta_x,result
	setscale /p y,yBins[0],delta_y,result
#else
	setscale /p x,xBins[0],delta_x,result
	setscale /p y,yBins[0],delta_y,result
	JointHistogram3(xx,yy,result)
#endif
	
	return result
end

// Degree of correlation matrix for a matrix of column vectors.  
Function /wave SyncDegC(m)
	wave m
	
	matrixop /free degC=synccorrelation(m) / sqrt(varcols(m)^t x varcols(m))
	return degC
End

// Perform a Malinowski F-test and return the number of significant eigenvalues.  
Function Malinowski(Eigenvalues,alpha[,saveFs])
	Wave Eigenvalues // A wave of eigenvalues to test.  
	variable alpha // The signficance level.  Not corrected for multiple comparisons.  
	variable saveFs // Save the F-statistics for each eigenvalue.  Actually the ratio of the F-statistic and its critical value.  
	
	variable i,pp=numpnts(Eigenvalues),sig=NaN
	make /free/n=(pp) Fs=NaN
	for(i=1;i<=pp;i+=1)
		make /o/free/n=(pp) denominator=Eigenvalues[p]/(pp-i)
		deletepoints 0,i,denominator
		variable F=Eigenvalues[i-1]/sum(denominator)
		variable crit=StatsInvFCDF(1-alpha, 1, pp-i)
		crit=numtype(crit) ? inf : crit
		if(F<crit && numtype(sig))
			sig=i-1
			if(!saveFs)
				break
			endif
		endif
		if(saveFs)
			Fs[i-1]=F/crit
		endif
	endfor
	if(saveFs)
		duplicate /o Fs $"MalinowskiFs"
	endif
	return (sig>1) ? sig : 1
End

// Returns the Mahalanobis distance of two data points.  OBSOLETE.  
//Function MahalDistance(values1,values2,stdevs)
//	String values1,values2,stdevs // values are vectors (in string form) describing the two data points; stdevs are the standard deviations of the dataset in each dimension.  
//	Variable i,distance_squared=0,dims=ItemsInList(values1)
//	Variable val1,val2,stdev
//	for(i=0;i<dims;i+=1)
//		val1=NumFromList(i,values1)
//		val2=NumFromList(i,values2)
//		stdev=NumFromList(i,stdevs)
//		distance_squared+=((val1-val2)/stdev)^2
//	endfor
//	return sqrt(distance_squared)
//End

// Compute L-ratio.  
function GetLratio(dist,size,sizeRatio,dof)
	variable dist,size,sizeRatio,dof
	make /free/n=(size,dof) d2self=gnoise(1)^2
	matrixop /free d2self=sumcols(d2self^t)^t
	make /free/n=(size*sizeRatio,dof) d2nuisance=(dist+gnoise(1))^2
	matrixop /free d2nuisance=sumcols(d2nuisance^t)^t
	make /free/n=(numpnts(d2nuisance)) Lc=1-statschicdf(d2nuisance,dof) // Nuisance weights.  
	variable spikesInCluster=numpnts(d2self)
	variable Lratio=sum(Lc)/spikesinCluster
	return Lratio
end

// Returns the L index (the numerator of the L-ratio from Schmitzer-Torbert et al, 2005) between a 'point' and the mean of the 'data'
function Lindex(data,point)
	wave data // each observation (e.g. spike) in the 'data' should be one row.  
	wave point // one row to compare to the mean of the data.  
	
	variable mahal=mahalanobis(data,point)
	variable dof=numpnts(point) // There number of degrees of freedom is equal to the dimensionality of the measurement.  
	variable val=1-statschicdf(mahal,dof)
	return val
end

// Returns the Mahalonobis distance d^2 between a 'point' and the mean of the 'data', or between two points in the 'data'.  
Function Mahalanobis(data,point)
	wave data // each observation (e.g. spike) in the 'data' should be one row.  
	wave point // one row to compare to the mean of the data, two row to compare between two points.  
	
	variable dims=dimsize(data,1)
	wave invCovs=MahalInvCovMatrix(data) // inverse of the covariance matrix.  dims x dims.  
	switch(dimsize(point,0)) // number of rows.  
		case 0: // effectively one row.  
		case 1: 
			matrixop /free means=meancols(data)^t // dims x 1 wave.  
			matrixop /free mahal=(point-means) x invcovs x (point-means)^t // (1 x dims) x (dims x dims) x (dims x 1)
			break
		case 2: 
			matrixop /free mahal=(row(point,0)-row(point,1)) x invcovs x (row(point,0)-row(point,1))^t // (1 x dims) x (dims x dims) x (dims x 1)
			break
		default:
			return NaN
	endswitch
	return mahal[0]
End

Function /wave MahalInvCovMatrix(data)
	wave data // each observation (e.g. spike) in the 'data' should be one row.   
	
	//duplicate /o CorrelationMatrix({data}) crap
	//matrixop /o crap=synccorrelation(data)///numrows(data)) // inverse of the covariance matrix.  
	//duplicate /o crap,crap2
	//crap/=(sqrt(abs(crap2[p][p]*crap2[q][q])))
	//edit crap
	//abort
	//extract /o crap,crap2,abs(crap[p][q])>0.99 && p!=q
	matrixop /free invcovs=inv((numrows(data)-0)*synccorrelation(data)/numrows(data)) // inverse of the covariance matrix.  
	//abort
	//duplicate /o invCov,crap
	return invcovs
End

#ifdef Nlx
// Returns two columns:
// 1) The isolation distance, which is the maximum Mahalanobis distance from the center of the 'cluster' at which points in 'data' inside that distance are more likely 
// to be members of 'cluster' than not.  K.D. Harris et al., 2001.  Equivalent to the value of D^2 for which the false discovery rate at threshold D^2 is equal to 0.5, where 
// the existing cluster assignments are taken to be the ground truth.  
// 2) The L-ratio, which is equal to sum(1-cdf(D^2)) for all spikes outside the cluster divided by the number of spikes in the cluster.  Similar to the ratio of false positives
// to (true positives + true negatives).    
Function /wave ClusterIsolation(df[,features,centeredClusters,nuisanceClusters])
	dfref df
	string features // e.g. "lambdas" to use the PCA coefficients.  
	wave centeredClusters
	wave nuisanceClusters // only do these clusters, e.g. "3-5".  
	
	features=selectstring(!paramisdefault(features),"lambdas",features)
	wave clustersWithSpikez=NlxA#ClustersWithSpikes(df)
	if(paramisdefault(centeredClusters))
		centeredClusters=clustersWithSpikez
	endif
	if(paramisdefault(nuisanceClusters))
		nuisanceClusters=clustersWithSpikez
	endif
	wave /z/sdfr=df clusters,values=$features
	if(!waveexists(values))
		printf "Features wave '%s' does not exist.\r",features
		return NULL
	endif
	if(sum(values)==0)
		printf "Features wave '%s' is full of zeroes.\r",features
		return NULL
	endif
	wave d2s=MahalDistance(values,clusters,doClusters=centeredClusters)
	make /o/n=(numpnts(centeredClusters),numpnts(nuisanceClusters)+2) df:isolation /wave=Isolation=nan//isolationDistances=nan, df:Lratios /wave=Lratios=nan
	variable i=0
	for(i=0;i<numpnts(centeredClusters);i+=1)
		variable centeredCluster=centeredClusters[i]
		string clusterName="U"+num2str(centeredCluster)
		variable column=FindDimLabel(d2s,1,clusterName)
		if(column<0)
			continue
		endif
		SetDimLabel 0,i,$clusterName,Isolation
		matrixop /free d2=col(d2s,column)
	
		dfref clusterDF=df:$clusterName
		
		duplicate /free clusters sortedclusters,sortedSelf
		redimension /s sortedSelf // convert from unsigned int to single precision so values can be negative.  
		sort d2,d2,sortedClusters,sortedSelf // sort so that cluster assignments are put in order of mahalanobis distance to cluster center.  
		
		// Compute isolation distance.  
		sortedSelf=(sortedSelf==centeredCluster) ? 1 : -1 // 1 if a spike belongs to the cluster and -1 if it doesn't.  
		integrate /p sortedSelf
		findlevel /q/edge=2 sortedSelf,0 // find the farthest spike from the cluster center where only half of the spikes that are nearer belong to the cluster.  
		if(!v_flag)
			variable isolationDistance=d2[V_LevelX] // mahalanobis distance of this spike.  
		elseif(sortedSelf[numpnts(sortedSelf)-1]<0)
			isolationDistance=0
		else
			isolationDistance=Inf
		endif
		Isolation[centeredCluster][numpnts(nuisanceClusters)]=isolationDistance
		variable /g clusterDF:isolationDistance=isolationDistance
		
		// Compute L-ratio.  
		extract /free d2,d2nuisance,sortedclusters!=centeredCluster
		variable dof=dimsize(values,1)
		make /free/n=(numpnts(d2nuisance)) Lc=1-statschicdf(d2nuisance,dof) // Nuisance weights.  
		variable spikesInCluster=numpnts(d2)-numpnts(d2nuisance)
		variable Lratio=sum(Lc)/spikesinCluster
		Isolation[%$clusterName][numpnts(nuisanceClusters)+1]=Lratio
		variable /g clusterDF:Lratio=Lratio
		
		// Compute pairwise L-average.  
		variable j
		for(j=0;j<numpnts(nuisanceClusters);j+=1)
			variable nuisanceCluster=nuisanceClusters[j]
			string nuisanceClusterName="U"+num2str(nuisanceCluster)
			SetDimLabel 1,j,$nuisanceClusterName,Isolation
			extract /free d2,d2nuisance,sortedClusters==nuisanceCluster
			make /free/n=(numpnts(d2nuisance)) Lc=1-statschicdf(d2nuisance,dof) // Nuisance weights.  
			variable Lratio_pair=sum(Lc)/spikesinCluster
			Isolation[%$clusterName][%$nuisanceClusterName]=Lratio_pair
		endfor
		
		waveclear d2nuisance,sortedClusters,sortedSelf
		//i+=1
	endfor
	toc()
	isolation=numtype(isolation) ? nan : isolation
	SetDimLabel 1,numpnts(nuisanceClusters),isoD,Isolation
	SetDimLabel 1,numpnts(nuisanceClusters)+1,Lratio,Isolation
	return Isolation
End
#endif

// Computes the distance of each point in 'data' to the center of each cluster in 'clusters'.  
// Each column will be the Mahalanobis distance of all spikes to the center of one cluster.  Each column will be the distances to the center of a different cluster.  
Function /WAVE MahalDistance(data,clusters,[doClusters])
	wave data // each point in the 'data' should be one column.  m dimensions, n columns (data points).  
	wave clusters // cluster membership.  
	wave doClusters // only do these clusters, e.g. "{3,4,5}".  
	
	if(paramisdefault(doClusters))
		make /free/n=100 counts=0
		histogram /b=2 clusters,counts
		extract /free/indx counts,doClusters,counts>0
	endif
	
	variable points=dimsize(data,0)
	variable dims=dimsize(data,1)
	wavestats /q/m=1 clusters
	variable i
	make /free/n=(points,1) mahaldists=0
	for(i=0;i<numpnts(doClusters);i+=1)
		variable cluster=doClusters[i]
		wave mahalVectors=MahalVectorsOneCluster(data,clusters,cluster) // Each row is a normalized distance in one dimension.  
		if(numpnts(mahalVectors)==0) // Probably because the cluster is empty.  
			make /free/n=1 mahalDist=nan
		else
			matrixop /free mahalDist=sumrows(mahalVectors * mahalVectors) // Mahalanobis distances d^2.  
			redimension /n=(points,i+1) mahalDists
			mahalDists[][i]=mahalDist[p] // Make this one column in a matrix of mahalanobis distances with respect to all cluster centers.  
		endif
		SetDimLabel 1,i,$("U"+num2str(cluster)),mahaldists
		//i+=1
	endfor
	return mahaldists
End

// Returns a set of distance vectors for all data with respect to the center of cluster 'cluster'.  
Function /wave MahalVectorsOneCluster(data,clusters,cluster)
	wave data // each observation/point in the 'data' should be a row.  M observations (e.g. spikes) x N dimensions (e.g. features).    
	wave clusters // cluster membership.  
	variable cluster // The cluster to be centered and normalized.    
	
	extract /indx/free clusters,clusterIndices,clusters[p]==cluster
	variable clusterSize=numpnts(clusterIndices)
	variable numFeatures=dimsize(data,1) // Number of features.  
	numFeatures=min(numFeatures,clusterSize-1) // Normally the dimensionality of the feature space, but this is not allowed to meet or exceed the number of spikes in the cluster.  
	if(clusterSize==0)
		make /free/n=0 mahalVectors
	else
		make /free/n=(clusterSize,numFeatures) onecluster=data[clusterIndices[p]][q]
		duplicate /free/r=[][0,numFeatures-1] data,datacentered // [0,numFeatues-1] will usually be all the features.  
		matrixop /free oneclustermean=meancols(onecluster)^t // A row vector.  
		datacentered-=oneclustermean[q]
		wave invCov=MahalInvCovMatrix(oneCluster)
		//variable factor=0.001 // Avoids matrix math errors by shifting the calculation into a numerically stable area.  
		matrixop /free mahalVectors=(datacentered x chol(invCov)^t) // Normalized distance vectors for all spikes with respect to one cluster center.  The sum of the squares of these values is d^2.  
	endif
	return mahalVectors
End

// Computes the square root of a matrix w by Denman–Beavers square root iteration.  
Function SqrtMatrix(w)
	wave w
	
	duplicate /o w,yy,zz
	zz=(p==q) // Identity matrix.  
	
	make /o/n=1000 errors
	variable i
	do
		matrixop /free yy_=(yy+inv(zz))/2
		matrixop /free zz_=(zz+inv(yy))/2
		yy=yy_
		zz=zz_
		i+=1
		matrixop /o test2=yy x yy
		matrixop /o error=Frobenius(w - (yy x yy))
		errors[i]=error[0]
	while(i<numpnts(errors))
End

// -------- Bayesian regularization -------- //

// Return an estimate for the parameter which maximizes the MAP given a prior Laplace distribution with mean 'mu' and scaling parameter 'sigma'.  
function Shrinkage(data,func,params[,limits])
	wave data // The observation(s).  
	funcref likelihoodProtoFunc func
	wave params
	wave limits
	
	string funcInfo=funcrefinfo(func)
	string funcName=stringbykey("NAME",funcInfo)
	if(numberbykey("ISPROTO",funcInfo) || !strlen(funcName))
		DoAlert 0,"Invalid function reference [Shrinkage]"
		return -1
	endif
	wavestats /q data
	if(numpnts(data)<=1)
		v_sdev=(v_avg==0) ? inf : sqrt(v_avg)
	endif
	if(paramisdefault(limits))
		make /free/n=(2,2) limits={{v_avg-2*v_sdev},{v_avg+2*v_sdev}} // {{muMin},{muMax}}
	endif
	make /free posterior={v_avg}
	variable /g shrinkageStDev=v_sdev
	variable /g shrinkageNumParams=numpnts(params) // The last one is the posterior stdev, which I am holding constant and equal to the sample stdev.  
	string /g shrinkageFuncName=funcName
	make /free/n=(shrinkageNumParams+numpnts(data)) priorAndData
	priorAndData[0,shrinkageNumParams-1]=params[p]
	priorAndData[shrinkageNumParams,]=data[p-shrinkageNumParams]
	Optimize /a=1/q /x=posterior /xsa=limits /m={3,1} BayesLikelihood,priorAndData
	killvariables shrinkageNumParams,shrinkageStDev
	killstrings shrinkageFuncName
	return posterior[0] 
end

function BayesLikelihood(priorAndData,posterior)
	wave priorAndData // Parameters for the prior distribution and the data.    
	wave posterior // posterior[0]=posterior mu; posterior[1]=posterior sigma.    
	
	nvar shrinkageNumParams,shrinkageStDev
	svar shrinkageFuncName
	funcref likelihoodProtoFunc priorFunc=$shrinkageFuncName
	funcref likelihoodProtoFunc posteriorFunc=GaussLikelihood
	make /free/n=(shrinkageNumParams) prior=priorAndData[p]
	make /free/n=(numpnts(priorAndData)-shrinkageNumParams) data=priorAndData[p+shrinkageNumParams]
	variable lnLdataGivenParams=numtype(sum(posterior))==2 ? -inf : Likelihood(data,posteriorFunc,{posterior[0],shrinkageStDev})
	variable lnLparams=Likelihood(posterior,priorFunc,prior)
	return lnLdataGivenParams+lnLparams
end

function Likelihood(data,func,params)
	wave data
	funcref likelihoodProtoFunc func
	wave params
	
	wave likelihood=func(data,params)
	if(numtype(sum(likelihood))==2)
		Post_("Data likely contains NaN's")
		extract /free likelihood,likelihood_,numtype(likelihood)!=2
		wave likelihood=likelihood_
	endif
	return sum(likelihood)
end

function /wave LikelihoodProtoFunc(data,params)
	wave data,params
end

function /wave LaplaceLikelihood(data,pp)
	wave data
	wave pp // mu and b.  
	
	duplicate /free data,likelihood
	if(pp[1]<0)
		likelihood=-inf
	else
		likelihood=ln(exp(-abs(data-pp[0])/pp[1])/(2*pp[1]))
	endif
	return likelihood
end

function /wave GaussLikelihood(data,pp)
	wave data
	wave pp // mu and sigma.  
	
	duplicate /free data,likelihood
	if(pp[1]<0)
		likelihood=-inf
	else
		likelihood=ln(gauss(data,pp[0],pp[1]))
	endif
	return likelihood
end

// ----------------------------- //

// Return the Nth combination of size 'k' from 'w'.  
function /wave NthCombination(w,k,n)
	wave w
	variable k,n
	
	make /free/n=(k) combos=nan
	duplicate /o w,w_
	variable i
	for(i=0;i<k;i+=1)
		variable num=0,index=0,size=numpnts(w_)
		do
			variable dec=binomial(size-index-1,k-i-1) // Decrement 'n' by this amount.  
			if(n<dec)
				break
			else
				n-=dec
				index+=1 // Choose a value at this index in 'w_'.  
			endif
		while(1)
		combos[i]=w_[index]
		deletepoints 0,index+1,w_ // Now only consider values with a higher index than 'index'.  
	endfor
	return combos
end

// Returns a Kohonen map (self-organizing map) based on the training data.  
function Kohonen(data,units[,lambda,mapSize,alpha0,range0,spaceConstant,timeConstant,init2PCs,xRange,yRange,show])
	wave data // The training data.  A matrix of column vectors with dimension 'dims'.  Each column is one datum.  
	wave units // M x N units spanning the first two principal components of the data.  
	variable lambda,alpha0,range0,spaceConstant,timeConstant,mapSize,init2PCs,show
	wave xRange,yRange
	
	alpha0=paramisdefault(alpha0) ? 0.5 : alpha0 // Initial learning rate.  
	lambda=paramisdefault(lambda) ? 10 : lambda // Number of cycles of learning.  
	mapSize=paramisdefault(mapSize) ? 5 : mapSize // Initial map grid should span this many standard deviations along each principal component.  
	variable dims=dimsize(data,0),numData=dimsize(data,1)
	variable iters=lambda*numData
	variable i,xx,yy,t,numXUnits=units[0],numYUnits=units[1]
	range0=paramisdefault(range0) ? max(numXUnits,numYUnits)/2 : range0
	spaceConstant=paramisdefault(spaceConstant) ? iters/3 : spaceConstant // Neighborhood of learning shrinks with this time constant (units of number of data encountered). 
	timeConstant=paramisdefault(timeConstant) ? iters/3 : timeConstant // Learning rate shrinks at with this time constant (units of number of data encountered).  
	
	make /o/n=(numXUnits,numYUnits,dims) map
	if(init2PCs) // Use principal components.  
		matrixop /free center=meancols(data^t)^t
		PCA /SRMT/SCMT/SEVC/LEIV data
		wave M_R // Each column is a principal component.  
		wave W_Eigen // Component variances.  
		matrixop /free PCs=normalizecols(M_R) // Normalized principal components.  
		multithread map=(mapSize*w_eigen[0]/sqrt(numData^1))*PCs[r][0]*(p-(numXunits-1)/2)/numXunits+(mapSize*w_eigen[1]/sqrt(numData^1))*PCs[r][1]*(q-(numYunits-1)/2)/numYunits+center[r]
	else
		wavestats /q/m=1 data
		variable span=v_max-v_min
		make /free/n=(numXunits,numYunits) randos=intnoise(numData)
		map=data[r][randos[p][q]]
		map=v_min+(abs(enoise(span)))
		map=gnoise(1)
	endif
	for(t=0;t<lambda;t+=1)
		prog("Pass",t,lambda)
		if(1) // Other things to do:  
			KohonenAux(data,map)
			doupdate
		endif
		make /free/n=(numData) indices=p, randos=gnoise(1)
		sort randos,indices
		for(i=0;i<numData;i+=1)
			variable iter=t*numData+i
			if(mod(i,20)==0)
				prog("Datum",i,numData)
			endif
			variable index=intnoise(numData)//indices[i]
			make /free/n=(numXunits,numYunits,dims) vectors,vectors2
			multithread vectors=data[r][index]-map[p][q][r]
			multithread vectors2=vectors^2
			matrixop /free distancesA=sqrt(sumbeams(vectors2)) // Here distances represents the vector distance between nodes and data.  
			imagestats /q/m=1 distancesA
			variable bmuX=v_minRowLoc, bmuY=v_minColLoc
			make /free/n=(numXunits,numYunits) distancesB=max(abs(p-bmuX),abs(q-bmuY))//sqrt((p-bmuX)^2+(q-bmuY)^2) // Here distances represents the map distance between nodes and the BMU.  
			variable alpha=alpha0*(1-iter/iters)
			variable range=1+(range0-1)*(1-iter/iters)
			multithread map+=distancesB[p][q]<=range ? alpha*exp(-(distancesB[p][q]/(2*range))^2)*vectors[p][q][r] : 0
			//KohonenAux(data,map)
			//doupdate
		endfor
	endfor
	
	KohonenAux(data,map)
	make /o/n=(numXunits,numYunits) occupancy=0
	make /o/n=(numData,2) BMUs=nan
	make /o/n=(numData,3) dataColors=nan
	wave mapProjection
	make /o/n=(numXunits*numYunits,3) map1DColors=mapProjection[mod(p,numXunits)][floor(p/numXunits)][q]
	if(1)//lambda)
		for(i=0;i<numData;i+=1)
			if(mod(i,20)==0)
				prog("Datum",i,numData)
			endif
			make /free/n=(numXunits,numYunits,dims) vectors
			multithread vectors=data[r][i]-map[p][q][r]
			matrixop /free vectors2=vectors * vectors
			matrixop /free distances=sqrt(sumbeams(vectors2)) // Done in two steps because of MatrixOp bug.  
			imagestats /q distances
			bmuX=v_minRowLoc; bmuY=v_minColLoc
			occupancy[bmuX][bmuY]+=1
			BMUs[i][0]=bmuX
			BMUs[i][1]=bmuY
			dataColors[i][]=mapProjection[BMUs[p][0]][BMUs[p][1]][q]
		endfor
	endif
	occupancy=log2(1+occupancy)
	if(show)
		if(0)
			newimage map1DProjection; doupdate; dowindow /t kwTopWin "PC Coefficients for Map"
			label left "Map Units"
			label top "PC #"
			modifyImage map1DProjection ctab= {*,*,RedWhiteBlue,1}
			
			newimage dataProjection; doupdate; dowindow /t kwTopWin "PC Coefficients for Data"
			label left "Data Observations"
			label top "PC #"
			ModifyImage dataProjection ctab= {*,*,RedWhiteBlue,1}
		endif
			
		display dataProjection[1][] vs dataProjection[0][] as "PC Coefficients for Map and Data"
		appendtograph map1DProjection[1][] vs map1DProjection[0][]
		ModifyGraph marker(map1DProjection)=17,mode(map1DProjection)=3,mode(dataProjection)=2
		ModifyGraph zColor(dataProjection)={dataColors,*,*,directRGB,0},zColor(map1DProjection)={map1DColors,*,*,directRGB,0}
		label left "PC 2"
		label bottom "PC 1"
		
		newimage occupancy; doupdate; dowindow /t kwTopWin "Occupancy"
		newimage mapProjection; doupdate; dowindow /t kwTopWin "RGB Map"
		newimage Umatrix doupdate; dowindow /t kwTopWin "U-Matrix"
		ModifyImage Umatrix ctab= {*,*,Grays,1}
		
		display as "Map"; TileAppend({map},5,5,colors=mapProjection)
	endif
end

function KohonenAux(data,map)
	wave data,map
	
	PCA /SCMT/SRMT/LEIV data // Compute principal components of the data.  
	wave m_r // Principal components are columns.  
	wave m_c // PC coefficients are rows.  
	// Convert map into a vector.  Each map point becomes a column, and each dimension in the data a row.   
	duplicate /o map,map1D
	variable numXUnits=dimsize(map,0), numYUnits=dimsize(map,1), dims=dimsize(data,0)
	make /o/n=(numXunits*numYunits,dims) map1D=map[mod(p,numXunits)][floor(p/numXunits)][q]
	//redimension /e=1/n=(numXunits*numYunits,dims) map1D
	matrixtranspose map1D
	//matrixop /o map1DProjection=(inv(m_r^t x m_r) x m_r^t x subtractmean(map1D,2)) // A projection of the map vectors into the PC space for easy visualization.   
	//matrixop /o dataProjection=(inv(m_r^t x m_r) x m_r^t x subtractmean(data,2)) // A projection of the map vectors into the PC space for easy visualization.   		
	matrixop /o map1Dprojection=(inv(m_r^t x m_r) x m_r^t x map1D) // A projection of the map vectors into the PC space for easy visualization.   
	matrixop /o dataProjection=m_c//(inv(m_r^t x m_r) x m_r^t x data) // A projection of the map vectors into the PC space for easy visualization.   		

	make /o/n=(numXunits,numYunits,3) mapProjection=map1Dprojection[r][p+q*numXunits] // Turn back into a map, with map values corresponding to the PC space.  
	redimension /n=(numXunits,numYunits,3) mapProjection // Only keep the first 3 PC coeffients.  
	make /free/n=(numXunits*numYunits,3) stuff1=mapProjection[mod(p,numXunits)][floor(p/numXunits)][q]
	variable i
	for(i=0;i<3;i+=1) // Color by rank in each PC projection.  
		matrixop /free pc=row(map1Dprojection,i)^t
		make /free/n=(numXunits*numYunits) color=65535*p/(numXunits*numYunits)
		make /free/n=(numpnts(pc)) index=p,index2=p
		sort pc,index
		sort index,index2
		mapProjection[][][i]=color[index2[p+q*numXunits]]
	endfor 
	//matrixop /free mapProjection_=round(scale(mapProjection,0,65535)) // Scale for RGB (bad matrixOp token if dest=source).  
	//mapProjection=mapProjection_
	//redimension /u/w mapProjection
	make /free/n=(numXunits,numYunits,4) Umatrix_
	make /free/n=(numXunits,numYunits) neighbors=4-(p==0 || p==(numXunits-1))-(q==0 || q==(numYunits-1)
	multithread Umatrix_[][][0]=UmatrixAux(map,p,q,1,0,numXunits,numYunits)
	multithread Umatrix_[][][1]=UmatrixAux(map,p,q,-1,0,numXunits,numYunits)
	multithread Umatrix_[][][2]=UmatrixAux(map,p,q,0,1,numXunits,numYunits)
	multithread Umatrix_[][][3]=UmatrixAux(map,p,q,0,-1,numXunits,numYunits)
	matrixop /o Umatrix=sumbeams(Umatrix_)/neighbors
end

threadsafe function UmatrixAux(map,xx,yy,dx,dy,lenX,lenY)
	wave map
	variable xx,yy,dx,dy,lenX,lenY
	
	if((xx+dx)>=lenX || (xx+dx)<0 || (yy+dy)>=lenY || (yy+dy)<0)
		variable result=0
	else
		make /free/n=(dimsize(map,2)) dist=(map[xx][yy][p]-map[xx+dx][yy+dy][p])^2
		result=sqrt(sum(dist))
	endif
	return result
end

function covariance(w1,w2)
	wave w1,w2
	matrixop /free result = mean(w1*w2) - mean(w1)*mean(w2)
	return result[0]
end

function FleshlerHoffman(i,N,p)
	variable i,N,p
	
	variable ti = ((-ln(1-p))^-1) * (1+ln(N)+(N-i)*ln(N-i)-(N-i+1)*ln(N-i+1))
	return ti
end