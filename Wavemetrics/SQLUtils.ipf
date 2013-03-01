#pragma rtGlobals=1		// Use modern global access method.

#include ":SQLConstants"

//== 
//Diagnostics (Added by Rick from the help file)
Function FetchUsingSQLGetData()
	Variable environmentRefNum=0,connectionRefNum=0,statementRefNum=0
	Variable result
	try
		// Create an environment handle. This returns an environment refNum in environmentRefNum.
		result = SQLAllocHandle(SQL_HANDLE_ENV,0,environmentRefNum)
		if (result)
			Print "Unable to allocate ODBC environment handle."
		endif
		AbortOnValue result!=0, 1

		// Set ODBC version attribute.
		result = SQLSetEnvAttrNum(environmentRefNum, SQL_ATTR_ODBC_VERSION, 3)
		if (result)
			PrintSQLDiagnostics(SQL_HANDLE_ENV,environmentRefNum,1) 
		endif
		AbortOnValue result!=0, 2

		// Get a connection refNum in connectionRefNum.
		result = SQLAllocHandle(SQL_HANDLE_DBC,environmentRefNum,connectionRefNum)
		if (result)
			PrintSQLDiagnostics(SQL_HANDLE_ENV,environmentRefNum,1) 
		endif
		AbortOnValue result!=0, 3

		// Connect to the database.
		result=SQLConnect(connectionRefNum,"IgorDemo1","DemoUser","Demo")
		if (result)
			PrintSQLDiagnostics(SQL_HANDLE_DBC,connectionRefNum,1) 
		endif
		AbortOnValue result!=0, 4
	
		// Create a statement refNum in statementRefNum.
		result=SQLAllocHandle(SQL_HANDLE_STMT,connectionRefNum,statementRefNum)
		if (result)
			PrintSQLDiagnostics(SQL_HANDLE_DBC,connectionRefNum,1) 
		endif
		AbortOnValue result!=0, 5

		// Execute it and parse the results. This returns a statement refNum in statementRefNum.
		result=SQLExecDirect(statementRefNum, "Select * from sampleTable;")
		if (result)
			PrintSQLDiagnostics(SQL_HANDLE_STMT,statementRefNum,1) 
		else
			ParseSQLResults(statementRefNum)		// This routine is provided by SQLUtils.ipf
		endif
		AbortOnValue result!=0, 6

	catch
		Print "Execution aborted with code ",V_AbortCode
	endtry
	
	if (statementRefNum != 0)
		SQLFreeHandle(SQL_HANDLE_STMT,statementRefNum)
	endif
	if (connectionRefNum != 0)
		SQLDisconnect(connectionRefNum)
		SQLFreeHandle(SQL_HANDLE_DBC,connectionRefNum)
	endif
	if (environmentRefNum != 0)
		SQLFreeHandle(SQL_HANDLE_ENV,environmentRefNum)
	endif

	return result
End
//===

//===========================================================================================
// The following function can be used for error diagnosis:
Function PrintSQLDiagnostics(handleType,handleRefNum,recordNum) 
	Variable handleType,handleRefNum,recordNum
	
	String SQLState,messageText
	Variable nativeError,result
	
	result=SQLGetDiagRec(handleRefNum,handleType,recordNum,SQLState,nativeError,messageText,512)
	if(result==0)
		printf "SQLState=%s\t NativeError=%g\t Error=%s\r",SQLState,nativeError,messageText
	else
		Switch(result)
			case SQL_SUCCESS_WITH_INFO:
				print "SQL_SUCCESS_WITH_INFO"
			break
			case  SQL_STILL_EXECUTING:
				print "SQL_STILL_EXECUTING"
			break
			case  SQL_ERROR:
				print "SQL_ERROR"
			break
			case  SQL_INVALID_HANDLE:
				print "SQL_INVALID_HANDLE"
			break
			case  SQL_NEED_DATA:
				print "SQL_NEED_DATA"
			break
			case  SQL_NO_DATA:
				print "SQL_NO_DATA"
			break
		endswitch
	endif
End

//===========================================================================================
//	SQLToWaveType(SQLDataType)
//	For a given SQL data type code, returns an Igor type code suitable for use with Make/Y=(<type>).
Function SQLToWaveType(SQLDataType)
	Variable SQLDataType
	
	switch(SQLDataType)
		case SQL_UNKNOWN_TYPE:
			return NaN						// Unknown type
			break
		
		case  SQL_CHAR:
			return 0							// Text
			break
		
		case SQL_NUMERIC:
		case SQL_FLOAT:
		case SQL_REAL:
		case SQL_DECIMAL:
			return 0x02						// Single-precision floating point
			break
		
		case SQL_INTEGER:
		case SQL_BIGINT:
			return 0x20						// Signed 32-bit integer
			break
		
		case SQL_SMALLINT:
			return 0x40						// Signed 16-bit integer
			break
		
		case SQL_DOUBLE:
			return 0x04						// Double-precision floating point
			break
			
		case SQL_DATETIME:
		case SQL_VARCHAR:
		case SQL_TYPE_DATE:
		case SQL_TYPE_TIME:
		case SQL_TYPE_TIMESTAMP:
			return 0							// Text
			break
	endswitch
End

//===========================================================================================
Function/S SQLToWaveTypeStr(SQLDataType)
	Variable SQLDataType
	
	switch(SQLDataType)
		case SQL_UNKNOWN_TYPE:
			return ""
		break
		case  SQL_CHAR:
			return "/T "
		break
		
		case SQL_NUMERIC:
		case SQL_FLOAT:
		case SQL_REAL:
		case SQL_DECIMAL:
			return "/S "
		break
		
		case SQL_INTEGER:
		case SQL_BIGINT:
			return "/i "
		break
		
		case SQL_SMALLINT:
			return "/W "
		break
		
		case SQL_DOUBLE:
			return "/D "
		break
			
		case SQL_DATETIME:
		case SQL_VARCHAR:
		case SQL_TYPE_DATE:
		case SQL_TYPE_TIME:
		case SQL_TYPE_TIMESTAMP:
			return "/T "
		break
	endswitch
End

//===========================================================================================
// The following function reads an SQL result set corresponding to the referenced statement.
// Text and numerical columns are read into text and numeric waves.  There are no test for 
// null data.
Function ParseSQLResults(statementRefNum)
	Variable statementRefNum

	Variable result,columnCount,rowCount,i,j,numVal,indicator
	String dataStr
	
	result=SQLNumResultCols(statementRefNum,columnCount)
	if(result==0)
		Make/O/T/N=(columnCount) outWaveName=""
		Make/O/N=(columnCount) outWaveType=0
		String colName
		Variable dataType,columnSize,decDigits,isNullable
		// Figure out the structure and contents of the SQL result set. 
		for(i=0;i<columnCount;i+=1)
			result=SQLDescribeCol(statementRefNum,i+1,colName,256,dataType,columnSize,decDigits,isNullable)
			if(result)
				PrintSQLDiagnostics(SQL_HANDLE_STMT,statementRefNum,1) 
			else
				outWaveName[i]=UniqueName(CleanupName(colName, 0 ),1,0)
				outWaveType[i]=SQLToWaveType(dataType)
			endif
		endfor

		result=SQLRowCount(statementRefNum,rowCount)
		if(result==0)
			if(rowCount<=0)
				Print "Empty SQL result set."
				return 0
			endif
			
			String cmd
			for(i=0;i<columnCount;i+=1)
				dataType = outWaveType[i]
				if (numtype(dataType) == 0)				// Is this a known output type?
					Make /Y=(dataType) /N=(rowCount) $(outWaveName[i])
				endif
			endfor
			
			// load all rows:
			for(i=0;i<rowCount;i+=1)
				result=SQLFetch(statementRefNum)	
				if(result)
					PrintSQLDiagnostics(SQL_HANDLE_STMT,statementRefNum,1) 
				endif
				
				// read all columns corresponding to the current row:	
				for(j=0;j<columnCount;j+=1)	
					if (NumType(outWaveType[j]) != 0)		// Unknown output type?
						continue								// Skip it.
					endif
					if (outWaveType[j] == 0)					// Text output?
						result=SQLGetDataStr(statementRefNum,j+1,dataStr,512,indicator)
						if(result)
							break
						endif
						Wave/T wt=$outWaveName[j]
						wt[i]=dataStr
					else										// Numeric output.
						result=SQLGetDataNum(statementRefNum,j+1,numVal,indicator)
						if(result)
							break
						endif
						Wave wd=$outWaveName[j]
						wd[i]=numVal
					endif
				endfor
			endfor
				
			if(result==0)
				// Display the table:
				Edit/K=1
				for(i=0;i<columnCount;i+=1)
					AppendToTable $outWaveName[i]
				endfor
			else
				PrintSQLDiagnostics(SQL_HANDLE_STMT,statementRefNum,1)
			endif
		else
			PrintSQLDiagnostics(SQL_HANDLE_STMT,statementRefNum,1) 
		endif
	endif
	
	SQLCloseCursor(statementRefNum);
	
	KillWaves/Z outWaveName,outWaveType
	
	return result
End	

// ShowSQLTypeInfo()
// Creates a table of data type information returned from the server.
// The main use for this is to see the list of data types supported by the DBMS.
// This list is in the first column of the table created by this function.
// Example:
//		ShowSQLTypeInfo("DSN=IgorDemo1;UID=DemoUser;PWD=Demo")
Function ShowSQLTypeInfo(connectionStr)
	String connectionStr			// A connection string identifying the server, database, user ID, and password.
	
	Variable result = 0
	Variable rc
	
	Variable environmentRefNum=-1, connectionRefNum=-1, statementRefNum=-1
	
	try
		rc = SQLAllocHandle(SQL_HANDLE_ENV, 0, environmentRefNum)
		if (rc != SQL_SUCCESS)
			AbortOnValue 1, 1
		endif

		rc = SQLSetEnvAttrNum (environmentRefNum, SQL_ATTR_ODBC_VERSION, 3)
		if (rc != SQL_SUCCESS)
			AbortOnValue 1, 2
		endif

		rc = SQLAllocHandle(SQL_HANDLE_DBC, environmentRefNum, connectionRefNum)
		if (rc != SQL_SUCCESS)
			AbortOnValue 1, 3
		endif
		
		String outConnectionStr
		Variable outConnectionStrRequiredLength
		rc = SQLDriverConnect(connectionRefNum, connectionStr, outConnectionStr, outConnectionStrRequiredLength, SQL_DRIVER_COMPLETE)
		switch(rc)
			case SQL_SUCCESS:
				rc = SQLAllocHandle(SQL_HANDLE_STMT, environmentRefNum, statementRefNum)
				if (rc != SQL_SUCCESS)
					AbortOnValue 1, 4
				endif
				
				rc = SQLGetTypeInfo(statementRefNum, SQL_ALL_TYPES)	// Generates a result set.
				if (rc != SQL_SUCCESS)
					AbortOnValue 1, 5
				endif
				
				SQLHighLevelOp /CONN=(connectionRefNum) /STMT=(statementRefNum) /E=1 ""	// Empty statement - just fetch result set into waves.
				ModifyTable width(TYPE_NAME)=142,format(COLUMN_SIZE)=2,width(COLUMN_SIZE)=122, width(LOCAL_TYPE_NAME)=244
				break
	
			case SQL_SUCCESS_WITH_INFO:
				PrintSQLDiagnostics(SQL_HANDLE_DBC,connectionRefNum,1)
				Print outConnectionStr
				AbortOnValue 1, 6
				break
			
			case SQL_NO_DATA:
				// The driver is supposed to return SQL_NO_DATA if the user cancels.
				// However, the MyODBC 3.51.19 driver returns SQL_ERROR, not SQL_NO_DATA in this event.
				Print "User cancelled."
				AbortOnValue 1, 7
				break
			
			default:			// Error
				PrintSQLDiagnostics(SQL_HANDLE_DBC,connectionRefNum,1)
				AbortOnValue 1, 8
				break
		endswitch
	catch
		Print "ShowSQLTypeInfo aborted with code ",V_AbortCode
		result = V_AbortCode
	endtry
	
	if (statementRefNum >= 0)
		SQLFreeHandle(SQL_HANDLE_STMT, statementRefNum)
	endif
	
	if (connectionRefNum >= 0)
		SQLDisconnect(connectionRefNum)
		SQLFreeHandle(SQL_HANDLE_DBC, connectionRefNum)
	endif
	
	if (environmentRefNum >= 0)
		SQLFreeHandle(SQL_HANDLE_ENV, environmentRefNum)
	endif
	
	return result
End
