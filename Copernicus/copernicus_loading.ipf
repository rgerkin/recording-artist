#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma moduleName=copernicus
static strconstant module=copernicus

function /s get_copernicus_data_path()
	string path = SpecialDirPath("Igor Pro User Files", 0, 0, 0)
	path += "data"
	NewPath /c/o/q data, path
	return path
end

function load_frankensweeps(name[,path])
	string name, path
	
	if(paramisdefault(path))
		path = get_copernicus_data_path()
	endif
	
	path += ":frankensweeps:" + name
	
	NewPath /o/q franken_path, path
	NewDataFolder /o root:frankensweeps
	NewDataFolder /o root:frankensweeps:$name
	dfref df = root:frankensweeps:$name
	variable i=0
	Do
		string file_name = IndexedFile(franken_path, i, ".csv")
		if(strlen(file_name) == 0)
			break										// No more files
		endif
		LoadWave /N=franken_temp/G/O/P=franken_path /Q file_name
		wave franken_temp0, franken_temp1
		variable t_first = franken_temp0[0]
		variable t_last = franken_temp0[numpnts(franken_temp1)-1]
		SetScale /I x, t_first, t_last, franken_temp1
		Duplicate /o franken_temp1, df:$RemoveEnding(file_name, ".csv")
		killwaves /z franken_temp0, franken_temp1
		i += 1
	While(1)
end