#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#pragma moduleName = UL
 
static constant USE_RECORDING_ARTIST_PROFILES = 1
static strconstant orcid = "0000-0002-2940-3378" // For use only when USE_RECORDING_ARTIST_PROFILES is 0.  
static strconstant data_server = "localhost:8000"
static strconstant metadata_server = "http://researchdata.elsevier.com"
static strconstant scope_server = "http://researchdata.elsevier.com"
static strconstant get_data_id_url = "/projects/ephysmdb1/getEntityID"
static strconstant get_investigators_url = "/projects/ephysmdb1/getInvestigators"
static strconstant post_entity_url = "/projects/ephysmdb1/postEntity"
static strconstant app_key = "UrbanLegend"
static strconstant secret_sender_key = "9cdea69dfb441c32" // Should be lab specific.  Do not share. 
static strconstant ftp_server = "ftp://researchdata.elsevier.com"
static strconstant ftp_url = "/"
static strconstant ftp_user = "igorupload"
static strconstant ftp_pass = "Bethoo2l"   
static strconstant module = "UL"

static function TestModule()
	string investigators = GetInvestigators()
	printf "All Investigators:\r"
	variable i
	for(i=0;i<itemsinlist(investigators);i+=1)
		string investigator = stringfromlist(i,investigators)
		printf "\t%s\r",investigator
	endfor
	printf "Current Investigator ORCID id:\r\t%s\r", GetInvestigator()
	string entity_id
	string scope = GetEntityID(entity_id)
	printf "Current Entity ID and Scope:\r\t%s\t%s\r",entity_id,scope
	printf "Set Attributes:\r\t%s\r",SetAttributes("key1:value1;key2:value2","run")
	printf "Writing experiment to HDF5:\r\t%s\r",selectstring(ExportHDF5(),"Success","Failed")
end

// =======================================================//
// Urban Legend Menu. //
// =======================================================//

menu "UL"
	"Export as HDF5",/Q, UL#ExportHDF5()
	"Upload HDF5",/Q, UL#UploadHDF5()
	"Manually update scope",/Q,UL#AcqStart()
	"-------"
	UL#LastScope(disable=1)
	"-------"
	UL#ScopeHistory(disable=1)
end

// =======================================================//
// Initialization, start, and stop hooks for acquisition. //
// =======================================================//

// Call this whereever your code initializes an experiment (or before the first sweep).  
static function AcqInit()
	dfref df = Home()
	string /g df:investigator = GetInvestigator()
	variable /g df:init = 1
	make /o/d/n=0 df:times
	make /o/t/n=0 df:scopes
	Core#LoadPackage(module,"Recording")
end

static function IsAcqInited()
	dfref df = Home()
	variable inited = 0
	if(datafolderrefstatus(df))
		nvar /z/sdfr=df init
		if(nvar_exists(init) && init)
			inited = 1
		endif
	endif
	
	return inited
end

// Call this immediately after the "Start" or "Go" button is pressed.  
static function AcqStart()
	variable alert
	
	dfref df = Home()
	
	if(IsAcqInited())
		wave /sdfr=df times
		wave /t/sdfr=df scopes
		string entity_id
		string scope = GetEntityID(entity_id)
		alert = Core#VarPackageSetting(module,"Recording","Generic","ScopeAlert")
		variable num_scopes = numpnts(scopes)
		if(alert && num_scopes && stringmatch(scope,scopes[num_scopes-1]))
			DoAlert 1,"Scope not updated since last start. Continue anyway?"
			switch(v_flag)
				case 1: // Yes clicked.  
					break
				case 2: // No clicked.  
					abort
					break
			endswitch
		endif
		times[numpnts(times)] = {stopmstimer(-2)}
		scopes[numpnts(scopes)] = {scope}
	else
		printf "Must run UL#AcqInit() first.\r"
	endif
end

// Update a wave note with an attribute (e.g. scope).  
// Call this with 'scope' as the key as soon as a sweep is saved to memory.  
static function AcqBind(w,key[,value])
	wave w
	string key,value
	
	dfref df = Home()
	if(IsAcqInited())
		string curr_note = note(w)
		strswitch(key)
			case "scope":
				wave /t/sdfr=df scopes
				string scope = scopes[numpnts(scopes)-1]
				note /k w,replacestringbykey("scope",curr_note,scope,"=","\r")
				break
			default:
				if(!paramisdefault(value))
					note /k w,replacestringbykey(key,curr_note,value,"=","\r")
				endif
		endswitch
	else
		printf "Must run UL#AcqInit() first.\r"
	endif
end

// Call this immediately after the "Stop" or "End" button is pressed, 
// or whenever acquistion terminates normally.  
static function AcqStop([run_attributes])
	string run_attributes
	
	dfref df = Home()
	if(IsAcqInited())
		string default_run_attributes = "" // Put something here. What?  
		run_attributes = selectstring(!paramisdefault(run_attributes),default_run_attributes,run_attributes) 
		SetAttributes(run_attributes,"run")
	else
		printf "Must run UL#AcqInit() first.\r"
	endif
end


// ====================================================//
// ------------------ Main Workflow -------------------//
// ====================================================//

// Returns by value the expected scope for the id.  
// Example: print UL#GetEntityID(0)
static function /s GetEntityID(entity_id[,IDtype])
	string &entity_id
	string IDtype
	
	string url = scope_server + get_data_id_url
	string investigator = GetInvestigator()
	string stamp
	sprintf stamp,"%f",PosixTime()
	string attribute = "run_name"  
	IDtype = selectstring(!paramisdefault(IDtype),"run",IDtype)
	string sender = hash(Hex2Char(secret_sender_key)+app_key,1)
	string key = Hex2Char(secret_sender_key)
	string valid = hash(key+stamp,1)
	string format = ""//token"
	
	string keys = "investigator;stamp;attribute;IDtype;sender;valid;format"
	string encoded = EncodeList(keys,{investigator,stamp,attribute,IDtype,sender,valid,format})
	string scope = ""
	easyHttp /TIME=5 /POST=encoded url
	if(!v_flag)
		if(stringmatch(format,"token"))
			string token = "=#>"
			string sep = "|@|"
		else
			token = "="
			sep = ";"
			s_getHttp = replacestring("{",s_getHttp,"")
			s_getHttp = replacestring("}",s_getHttp,"")		
			s_getHttp = replacestring("\"",s_getHttp,"")		
			s_getHttp = replacestring(": ",s_getHttp,"=")	
			s_getHttp = replacestring(", ",s_getHttp,";")		
		endif
		string status = stringbykey("status",s_getHttp,token,sep,0)
		string error = stringbykey("error",s_getHttp,token,sep,0)
		investigator = stringbykey("investigator",s_getHttp,token,sep,0)
		entity_id = stringbykey("entity_id",s_getHttp,token,sep,0)
		scope = stringbykey("scope",s_getHttp,token,sep,0)
		//print s_gethttp
		//print entity_id,scope
		if(strlen(scope))
			dfref df = Home()
			variable i
			for(i=0;i<itemsinlist(s_getHttp);i+=1)
				string item = stringfromlist(i,s_getHttp)
				key = stringfromlist(0,item,"=")
				string value = stringfromlist(1,item,"=")
				string /g df:$key = value
			endfor
		endif
	endif
	return scope
end

// Get the last scope returned by the server by GetEntityID()
static function /s LastScope([disable])
	variable disable
	
	string result = ""
	dfref df=Home()
	if(datafolderrefstatus(df))
		svar /z/sdfr=df scope
		if(svar_exists(scope))
			result = selectstring(disable,"","(")+scope
		endif
	endif
	return result
end

static function /s ScopeHistory([disable])
	variable disable
	
	string result = ""
	dfref df=Home()
	if(datafolderrefstatus(df))
		wave /z/t/sdfr=df scopes
		if(waveexists(scopes))
			variable i
			for(i=(numpnts(scopes)-1);i>=0;i-=1)
				result += selectstring(disable,"","(")+scopes[i]+";"
			endfor
		endif
	endif
	return result
end

// Get list of investigators from the server.  
// List has format "name1,orcid1;name2,orcid2;..."
static function /s GetInvestigators()
	string url = metadata_server + get_investigators_url
	string stamp
	sprintf stamp,"%f",PosixTime()
	string key = Hex2Char(secret_sender_key)
	string sender = hash(key+app_key,1)
	string valid = hash(key+stamp,1)
	string format = "" // "token"
	
	string keys = "stamp;sender;valid;format"
	string encoded = EncodeList(keys,{stamp,sender,valid,format})
	easyHttp /TIME=5 /POST=encoded url
	string investigators = ""
	if(!v_flag)
		s_gethttp = replacestring(", \"investigators",s_gethttp,";\"investigators")
		s_gethttp = replacestring(", \"error",s_gethttp,";\"error")
		string status = stringbykey("\"status\"",s_getHttp)
		string error = stringbykey("\"error\"",s_getHttp)
		investigators = stringbykey("\"investigators\"",s_getHttp)
		investigators = replacestring("], ",investigators,";")
		investigators = replacestring("[",investigators,"")
		investigators = replacestring("]",investigators,"")
		investigators = replacestring("\"",investigators,"")
		investigators = replacestring(", ",investigators,",")
	endif
	return investigators
end

// Looks up Igor profile currently in use and returns profile name.  
// This will eventually be converted to return an ORCID instead.  
static function /s GetInvestigator()
	string investigator = orcid
#if exists("Core#GetProfileInfo")
	if(USE_RECORDING_ARTIST_PROFILES)
		struct Core#ProfileInfo profile
		Core#GetProfileInfo(profile)
		investigator = profile.orcid 
	endif
#endif
	return "http://orcid.org/"+investigator
end

// Post attribute metadata to the server.  
// Attributes should be of the form "key1:value1;key2:value2;..."
static function /s SetAttributes(attributes,entity_type)
	string attributes
	string entity_type
	
	string url = metadata_server + post_entity_url
	string query = ""
	string stamp
	sprintf stamp,"%f",PosixTime()
	string key = Hex2Char(secret_sender_key)
	string sender = hash(key+app_key,1)
	string valid = hash(key+stamp,1)
	string investigator = GetInvestigator()
	string entity_id
	string scope = GetEntityID(entity_id)
	attributes = jsonify(attributes)
	
	string keys = "query;entity_id;scope;investigator;attributes;entity_type;stamp;sender;valid"
	string encoded = EncodeList(keys,{query,entity_id,scope,investigator,attributes,entity_type,stamp,sender,valid})
	string action = ""
	easyHttp /TIME=5 /POST=encoded url
	if(!v_flag)
		string status = stringbykey("status",s_getHttp)
		string error = stringbykey("error",s_getHttp)
		action = stringbykey("action",s_getHttp)
	endif
	return action
end

// Export the entire experiment as HDF5.  
static function ExportHDF5([path_name,file_name])
	string path_name,file_name
	
#if exists("HDF5CreateFile")	
	if(paramisdefault(path_name) || !strlen(path_name))
		path_name = "hdf_path"
	endif
	string entity_id
	GetEntityID(entity_id) // Pass by reference.  
	file_name = selectstring(!paramisdefault(file_name),entity_id,file_name)
	file_name = selectstring(strlen(file_name),IgorInfo(1),file_name)
	path_name = SetHDF5Path(path_name)
	variable fileID
	pathinfo $path_name
	HDF5CreateFile /O/P=$path_name fileID as file_name+".h5"
	//variable groupID
	//HDF5CreateGroup fileID, "/root", groupID
	HDF5SaveGroup /O /R /T root:, fileID, "."
	HDF5CloseFile /Z fileID  
	printf "Exported as HDF5 to %s:%s.h5\r",s_path,file_name
	return 0
#else
	printf "HDF5 XOP not loaded.\r"  
	return -1
#endif
end

static function UploadHDF5([path_name,file_name])
	string path_name,file_name
	
	if(paramisdefault(path_name) || !strlen(path_name))
		path_name = "hdf_path"
	endif
	string entity_id
	GetEntityID(entity_id) // Pass by reference.  
	file_name = selectstring(!paramisdefault(file_name),entity_id,file_name)
	file_name = selectstring(strlen(file_name),IgorInfo(1),file_name)
	path_name = SetHDF5Path(path_name)
	GetFileFolderInfo /Q/P=$path_name file_name+".h5"
	if(v_flag) // File does not exist.  
		ExportHDF5(path_name=path_name,file_name=file_name)
	endif
	string url = removeending(ftp_server+ftp_url,"/")+"/"+file_name+".h5"
	FTPUpload /P=$path_name /V=7 /U=ftp_user /W=ftp_pass url, file_name+".h5"
end

// ====================================================//
// -------------- Auxiliary Utilities -----------------//
// ====================================================//

static function /df Home()
#if exists("Core#JoinPath")
	string folder = Core#JoinPath({Core#ModuleInfo(),"UL"})
	dfref df = $folder
	return df
#else
	newdatafolder /o root:UL
	return root:UL
#endif
end

// Return the number of seconds since the beginning of the Posix epoch.  
static function PosixTime()
	variable offset = date2secs(-1,-1,-1) // Seconds relative to UTC.  
	return datetime-date2secs(1970,1,1)-offset
end

// URL encode a list of keys and values.  
static function /s EncodeList(keys,values)
	string keys
	wave /t values
	
	string result = ""
	variable i
	for(i=0;i<itemsinlist(keys);i+=1)
		string key = stringfromlist(i,keys)
		string value = values[i]
		result += urlencode(key)+"="+urlencode(value)+"&"
	endfor
	return result
end

// Convert a hexadecimal string into a char string.  
static function /s Hex2Char(hex)
	string hex // A string like "0f8a047d0148c"
	
	string result = ""
	variable i
	for(i=0;i<strlen(hex);i+=2)
		variable num
		sscanf hex[i,i+1],"%x",num
		result += num2char(num)
	endfor
	return result
end

// Takes a key-value pair list and formats it as a JSON string.  
static function /s JSONify(list)
	string list
	
	string json = "{"
	variable i
	for(i=0;i<itemsinlist(list);i+=1)
		string pair = stringfromlist(i,list)
		string key = stringfromlist(0,pair,":")
		string value = stringfromlist(1,pair,":")
		json += "\""+key+"\":\""+value+"\","
	endfor
	json = removeending(json,",")+"}"
	
	return json
end

static function /s GetEntityID_()
	string entity_id = ""
	return GetEntityID(entity_id)
end

static function /s SetHDF5Path(path_name)
	string path_name
	
	pathinfo $path_name
	if(!v_flag)
		string full_path = strvarordefault("root:Packages:HDF:path","")
		if(strlen(full_path))
			newpath /o/q hdf_path,full_path
			pathinfo hdf_path
		endif
		if(!v_flag)
			newpath /o hdf_path
		endif
		path_name = "hdf_path"
	endif
	
	return path_name
end

// ====================================================//
// ------------------ Deprecated ----------------------//
// ====================================================//

// Encode a key-value pair for POSTing  
// The key is provided, and could just be the name of the object in Igor.  
// The value will be computed in this function from the provided path to the object .  

function /s Encode(key,path)
	string key // The desired key name of the object or property.  
	string path // Its path in Igor, e.g. root:cell0:sweep23
	
	// Is it a wave?  
	wave /z w = $path
	if(waveexists(w))
		string toEncode,msg_str=""
#if exists("SOCKITList")
		SOCKITWaveToString w,msg_str // Do I need the /E flag to preserve endian-ness?  
#else
		variable i
		for(i=0;i<numpnts(w);i+=1)
			msg_str+=num2str(w[i]) // Wrong but will fix later.  
		endfor
#endif
		print w,msg_str
		print "//"
		sprintf toEncode,"WAV:%s;%s",waveinfo(w,0),msg_str
	endif
	
	// Is it a variable?  
	nvar /z var = $path
	if(nvar_exists(var))
		sprintf toEncode,"NUM:%f",var
	endif
	
	// Is it a string?  
	svar /z str = $path
	if(svar_exists(str))
		sprintf toEncode,"STR:%s",str
	endif
	
	string result
	sprintf result,"%s=%s",URLEncode(key),URLEncode(toEncode)
	return result
end

// Post encoded data (one or more key-value pairs) to the server.  
static function Post(post_str[,server,path])
	string post_str,server,path
	
	if(paramisdefault(server))
		server = metadata_server
	endif
	if(paramisdefault(path))
		path = "/urban-legend/igor-post"
	endif
	easyHttp /POST=post_str /TIME=5 server+path
	if(!v_flag && stringmatch(s_getHttp,"success"))
		return 0
	else
		printf "Error Code:%d; Response:%s\r",v_flag,s_getHttp
		return -1
	endif
end

// Recursively post the entire contents of the experiment file.  
static function PostExperiment([df[,server])
	dfref df
	string server
	
	if(paramisdefault(df))
		dfref df = root:
	endif
	if(paramisdefault(server))
		server = metadata_server
	endif
	
	variable i,j
	// All data folders.  
	for(i=0;i<CountObjectsDFR(df,4);i+=1)
		dfref dfi = df:$GetIndexedObjNameDFR(df,4,i)
		PostExperiment(df=dfi)
	endfor
	// All waves (1), variables (2), and strings (3).  
	for(j=1;j<=3;j+=1)
		for(i=0;i<CountObjectsDFR(df,j);i+=1)
			string name = GetIndexedObjNameDFR(df,j,i)
			string path = removeending(getdatafolder(1,df),":")+":"+name
			string encoded = Encode(path,path) // Name the object after its location.  
			if(Post(encoded))
				return -1
			endif
		endfor
	endfor
end