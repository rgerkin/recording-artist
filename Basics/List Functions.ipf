
// $Author: rick $
// $Rev: 632 $
// $Date: 2013-03-15 17:17:39 -0700 (Fri, 15 Mar 2013) $

#pragma rtGlobals=1		// Use modern global access method.

Function CharCount(str,char)
	String str,char
	
	Variable i,count=0
	for(i=0;i<strlen(str);i+=1)
		if(char2num(str[i])==char2num(char))
			count+=1
		endif
	endfor
	return count
End

Function /S RelPath(path)
	String path
	
	path=RemoveEnding(path,":")
	String rel=StringFromList(ItemsInList(path,":")-1,path,":")
	return rel
End

Function /s ClearBrackets(str)
	string str
	
	str=replacestring("[",str,"")
	str=replacestring("]",str,"")
	return str
End

function /s ListIntersection(lists)
	wave /t lists
	
	variable i,j
	string newList="",counts=""
	for(i=0;i<numpnts(lists);i+=1)
		string list=lists[i]
		string currItems=""
		for(j=0;j<itemsinlist(list);j+=1)
			string item=stringfromlist(j,list)
			if(whichlistitem(item,currItems)<0)
				variable count=NumberByKey(item,counts)
				count=numtype(count) ? 0 : count
				counts=ReplaceNumberByKey(item,counts,count+1)
				currItems+=item+";"
			endif
		endfor
	endfor
	for(i=0;i<itemsinlist(counts);i+=1)
		string entry=stringfromlist(i,counts)
		item=stringfromlist(0,entry,":")
		count=NumberByKey(item,counts)
		if(count==numpnts(lists))
			newList+=item+";"
		endif
	endfor
	return newList
end

Function /S ListCombos(list[,compare])
	String list,compare
	
	Variable i,j
	Variable numItems=ItemsInList(list)
	String combos=""
	for(i=0;i<2^numItems;i+=1)
		Variable true=1
		String combo=""
		for(j=0;j<numItems;j+=1)
			String item=StringFromList(j,list)
			combo+=SelectString(i & 2^j,"",item+",")
			if(WaveExists(Comparison))
				Variable comparison=str2num(StringFromList(j,compare))
				true*=((i & 2^j)>0)==comparison
			else
				true=0
			endif
		endfor
		combo=RemoveEnding(combo,",")
		combo=SelectString(strlen(combo)," ",combo)
		if(true)
			combo="["+combo+"]"
		endif	
		combos+=RemoveEnding(combo,",")+";"
	endfor
	return combos
End

function /s MatchExcept(list,match,except)
	string list,match,except
	
	variable i,j; string newList=""
	for(i=0;i<itemsinlist(list);i+=1)
		string item=stringfromlist(i,list)
		variable skip=0
		for(j=0;j<itemsinlist(except);j+=1)
			if(stringmatch(item,stringfromlist(j,except)))
				skip=1
				break
			endif
		endfor
		if(!skip)
			for(j=0;j<itemsinlist(match);j+=1)
				if(stringmatch(item,stringfromlist(j,match)))
					newList+=item+";"
				endif
			endfor
		endif
	endfor
	return newList
end

// Returns a list of all the cases in a switch function.  
Function /S GetCases(func_name[,switch_name])
	String func_name,switch_name
	if(ParamIsDefault(switch_name))
		switch_name="*switch*"
	else
		switch_name="*switch "+switch_name+"*"
	endif
	String cases=""
	String function_text=ProcedureText(func_name)
	Variable i,j
	for(i=0;i<ItemsInList(function_text,"\r");i+=1)
		String line=StringFromList(i,function_text,"\r")
		if(StringMatch(line,switch_name))
			j=i+1
			Do
				line=StringFromList(j,function_text,"\r")
				if(StringMatch(line,"*case*"))
					String one_case
					sscanf line," case \"%[a-zA-Z\-0-9_ ]",one_case
					cases+=one_case+";"
				endif
				j+=1
			While(!StringMatch(line,"*endswitch*"))
			i=j+1
		endif
	endfor
	return cases
End

// Returns the width in screen tof the widest string in a given list.  
Function WidestString(list,font,size,style)
	String list,font
	Variable size,style
	
	Variable i, longest=0
	for(i=0;i<ItemsInList(list);i+=1)
		String str=StringFromList(i,list)
		longest=max(longest,FontSizeStringWidth(font,size,style,str))
	endfor
	return longest
End

// Returns the given line number of a notebook into a string.  The first line is number 0.  
Function /S NotebookLine2String(notebook_name,line)
	String notebook_name
	Variable line
	Notebook $notebook_name, selection={(line,0),(line+1,0)}
	Getselection notebook, $notebook_name, 2
	return S_selection
End

Function LongestRegion(regions)
	String regions
	Variable i
	Variable longest_region=0
	for(i=0;i<ItemsInList(regions);i+=1)
		String region=StringFromList(i,regions)
		Variable start=str2num(StringFromList(0,region,","))
		Variable finish=str2num(StringFromList(1,region,","))
		Variable length=finish-start
		longest_region=max(longest_region,length)
	endfor
	return longest_region
End

// Converts the values from a list of global variables to a semi-colon separated list of values.  The list of globals
// can contain numeric or string variables or even waves.  For waves, the value at 'index' is put into the list.  
Function /S GlobalList2Values(source_list,index)
	String source_list
	Variable index
	Variable i; String value_list=""
	for(i=0;i<ItemsInList(source_list);i+=1)
		String name=StringFromList(i,source_list)
		strswitch(Core#ObjectType(name))
			case "WAV": 
				Wave myWave=$name
				value_list+=num2str(myWave[index])+";"
				break
			case "WAVT": 
				Wave /T myTextWave=$name
				value_list+=myTextWave[index]+";"
				break
			case "VAR": 
				NVar myVar=$name
				value_list+=num2str(myVar)+";"
				break
			case "STR": 
				SVar myStr=$name
				value_list+=myStr+";"
				break
			default:
				DoAlert 0,name+" could not be found or does not contain a known data type."
				break	
		endswitch
	endfor
	return value_list
End

// Adds single quotes to each item in the list.  
Function /S SingleQuoteList(list)
	String list
	Variable i; String new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		new_list+="'"+item+"';"
	endfor
	return new_list
End

// Fills the gaps between regions if those gaps are less than max_gap.  
Function /S FillGaps(regions,max_gap)
	String regions
	Variable max_gap
	Variable i; String new_regions
	regions=SortRegions(regions)
	for(i=0;i<ItemsInList(regions);i+=1)
		String region=StringFromList(i,regions)
		Variable start=str2num(StringFromList(0,region,","))
		Variable finish=str2num(StringFromList(1,region,","))
		Variable last_start,last_finish
		if(i>0)
			if(start-last_finish<=max_gap)
				String new_region=num2str(last_start)+","+num2str(finish)
				regions=ReplaceListItem(new_region,regions,i-1)
				regions=RemoveListItem(i,regions)
				i-=1
				start=last_start
			endif
		endif
		last_start=start
		last_finish=finish
	endfor
	return regions
End

// Sorts regions from earliest start to latest start.  
Function /S SortRegions(regions)
	String regions
	Variable i
	String new_regions=""
	Make /o/n=(ItemsInList(regions)) SortRegions_Starts,SortRegions_Index=p
	for(i=0;i<ItemsInList(regions);i+=1)
		String region=StringFromList(i,regions)
		Variable start=str2num(StringFromList(0,region,","))
		SortRegions_Starts[i]=start
	endfor
	Sort SortRegions_Starts,SortRegions_Index
	for(i=0;i<ItemsInList(regions);i+=1)
		region=StringFromList(SortRegions_Index[i],regions)
		new_regions+=region+";"
	endfor
	KillWaves /Z SortRegions_Starts,SortRegions_Index
	return new_regions
End

// Removes all spaces from a string.  
Function /S ShedSpaces(str)
	String str
	Variable i
	String new_str=""
	for(i=0;i<strlen(str);i+=1)
		if(!StringMatch(str[i]," "))
			new_str+=str[i]
		endif
	endfor
	return new_str
End

// Accepts lists in the match parameter.  
Function StringMatch2(str,match_list)
	String str
	String match_list
	Variable i
	for(i=0;i<ItemsInList(match_list);i+=1)
		String match_item=StringFromList(i,match_list)
		if(StringMatch(str,match_item))
			return 1
		endif
	endfor
	return 0
End

// Returns only those list values with the right remainder after modular arithmetic.  
Function /S ModList(list,remainder[,modulus])
	String list
	Variable remainder,modulus
	modulus=ParamIsDefault(modulus) ? 2 : modulus
	list=ListExpand(list)
	
	Variable i; String new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		String entry=StringFromList(i,list)
		Variable num=str2num(entry)
		if(mod(num,modulus)==remainder)
			new_list+=num2str(num)+";"
		endif
	endfor
	return new_list
End

Function /S RepString(pattern,start,finish,step)
	String pattern // Something like "sweep%d"
	Variable start,finish,step // The variables to fill with.  
	
	String str=""
	Variable i
	for(i=start;i<=finish;i+=step)
		sprintf str,str+pattern,i
	endfor
	return str
End

Function /S RepeatString(str,num)
	String str
	Variable num
	
	Variable i
	String newStr=""
	for(i=0;i<=num;i+=1)
		newStr+=str
	endfor
	return newStr
End

// Adds a constant value to all the numbers in list.  
Function /S AddConstantToList(list,num)
	string list
	variable num
	
	variable i; string new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		variable entry=str2num(StringFromList(i,list))
		entry+=num
		new_list+=num2str(entry)+";"
	endfor
	return new_list
End

// Removes character 'char' from string 'str'.  
Function /S RemoveChar(str,char)
	String str,char
	Variable i
	String new_str=""
	for(i=0;i<strlen(str);i+=1)
		if(cmpstr(str[i],char))
			new_str+=str[i]
		endif
	endfor
	return new_str
End

// Returns whether 'value' is in the list of regions formatted like "10,15;27,48"
Function InRegion(value,regions)
	Variable value
	String regions
	regions=ListExpand(regions)
	if(WhichListItem(num2str(value),regions)>=0)
		return 1
	endif
	return 0
End

// Make a list in which the string 'str' is repeated 'num' times, separated by 'sep'.  
Function /S RepeatList(num,str[,sep])
	Variable num
	String str,sep
	if(ParamIsDefault(sep))
		sep=";"
	endif
	String list=""
	Variable i
	for(i=0;i<num;i+=1)
		list+=str+sep
	endfor
	list=RemoveLastNChars(list,1)
	return list
End

Function /S RemoveLastNChars(str,n)
	String str
	Variable n
	return str[0,strlen(str)-(1+n)]
End

Function MedianList(list[,keep_NaNs])
	String list
	Variable keep_NaNs
	list=SortList(list,";",2)
	if(!keep_NaNs)
		list=RemoveFromList("NaN",list)
	endif
	Variable num_items=ItemsInList(list)
	if(mod(num_items,0)==1)
		return str2num(StringFromList((num_items-1)/2,list))
	else
		return (str2num(StringFromList(num_items/2,list))+str2num(StringFromList((num_items/2)-1,list)))/2
	endif
End

// Returns the truth as to whether any item in list1 matches any item in list2.  
Function AnyMatch(list1,list2)
	String list1,list2
	Variable i; String item
	for(i=0;i<ItemsInList(list1);i+=1)
		item=StringFromList(i,list1)
		if(WhichListItem(item,list2)>=0)
			return 1
		endif
	endfor
	return 0
End

// Sorts a list so as to put the entries of the list key_list in sorted order
Function /S SortList2(list,key_list)
	String list,key_list
	if(ItemsInList(list)!=ItemsInList(key_list))
		printf "List (%d) and key_list (%d) do not have the same number of items.\r",itemsInList(list),itemsInList(key_list)
		return ""
	endif
	Wave /T Sort_Wave=$List2WavT(list,name="sort_wave")
	Wave /T SortKey_Wave=$List2WavT(key_list,name="sort_key_wave")
	Sort /A SortKey_Wave,Sort_Wave
	list=WavT2List(Sort_Wave)
	KillWaves Sort_Wave,SortKey_Wave
	return list
End

Function /S TextWave2String(TextWave[,noSep])
	Wave /T TextWave
	Variable noSep
	
	Variable i; String str=""
	for(i=0;i<numpnts(TextWave);i+=1)
		str+=TextWave[i]+SelectString(noSep,";","")
	endfor
	return str
End

function /s DimLabel2String(w,dim)
	wave w
	variable dim
	
	variable i
	string str=""
	for(i=0;i<dimsize(w,dim);i+=1)
		str+=getdimlabel(w,dim,i)+";"
	endfor
	return str
end

// Takes a list like "a,b;c,d;e,f" and converts it into "a;c;e" for n=0 or "b;d;f" for n=1
Function /S NthEntries2List(list,n)
	String list
	Variable n
	String new_list="",item
	Variable i
	if(strlen(list)>0)
		for(i=0;i<ItemsInList(list);i+=1)
			item=StringFromList(i,list)
			new_list+=StringFromList(n,item,",")+";"
		endfor
	endif
	return new_list
End

// Returns the negative of every value in a list
Function /S NegList(list)
	String list
	Variable i,item
	String new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		item=str2num(StringFromList(i,list))
		new_list=new_list+num2str(-item)+";"
	endfor
	return new_list
End

// Takes a template wave (for scaling), a list of times, and a list of amplitudes and creates a wave with 
// instantaneous impulses with those amplitudes at those times.  Returns in a wave called destName
Function ImpulseFromList(templateWave,locs[,vals,destName,baseline])
	Wave templateWave
	String locs
	String vals
	String destName
	Variable baseline
	if(ParamIsDefault(destName))
		destName="ImpulseWave"
	endif
	Duplicate /o templateWave $destName
	Wave dest=$destName
	dest=baseline
	Variable i
	Variable loc,val
	for(i=0;i<ItemsInList(locs);i+=1)
		loc=str2num(StringFromList(i,locs))
		if(ParamIsDefault(vals))
			val=templateWave(loc)
		else
			val=str2num(StringFromList(i,vals))
		endif
		dest[x2pnt(dest,loc)]=val
	endfor
End

// Excludes any peaks that come within refractory ms of a larger peak.  
Function SpacePeaks(refractory[,flip])
	Variable refractory
	Variable flip
	SVar locs=peak_locs
	SVar vals=peak_vals
	Variable i=1
	Variable loc,val
	Variable last_loc=str2num(StringFromList(0,locs))
	Variable last_val=str2num(StringFromList(0,vals))
	Do
		loc=str2num(StringFromList(i,locs))
		val=str2num(StringFromList(i,vals))
		if(flip)
			val*=-1
		endif
		if(abs(loc-last_loc)<refractory)
			if(val>last_val)
				locs=RemoveListItem(i-1,locs)
				vals=RemoveListItem(i-1,vals)
				last_loc=loc
				last_val=val
			else
				locs=RemoveListItem(i,locs)
				vals=RemoveListItem(i,vals)
			endif
		else
			last_loc=loc
			last_val=val
			i+=1
		endif
	While(i<ItemsInList(locs))
End

Function String2Wave(str[,name,versus,plot])
	String str
	String name // The name of the output wave
	String versus
	Variable plot
	if(ParamIsDefault(name))
		name="StringWave"
	endif
	Make /o/n=(ItemsInList(str)) $name
	Wave StringWave=$name
	Variable i
	for(i=0;i<ItemsInList(str);i+=1)
		StringWave[i]=str2num(StringFromList(i,str))	
	endfor
	String plot_versus=""
	if(!ParamIsDefault(versus))
		Make /o/n=(ItemsInList(str)) $(name+"X")
		Wave StringWaveX=$(name+"X")
		for(i=0;i<ItemsInList(str);i+=1)
			StringWaveX[i]=str2num(StringFromList(i,versus))
		endfor
		plot_versus=" vs "+name+"X"
	endif
	if(!ParamIsDefault(plot))
		Display /K=1
		Execute "AppendToGraph StringWave"+plot_versus
	endif
End


// Use in case some list doesn't have a trailing semicolon
Function /S JoinLists(list_of_lists)
	String list_of_lists // A list of lists, e.g. "list_a;list_b;list_c"
	String item
	Variable i,j
	String new_list=""
	for(i=0;i<ItemsInList(list_of_lists);i+=1)
		SVar one_list=$StringFromList(i,list_of_lists)
		new_list=new_list+RegenList(one_list)
	endfor
	return new_list
End

Function /S ConcatLists(list1,list2)
	String list1,list2
	String new_list=RegenList(list1)+RegenList(list2)
	return new_list
End

// Better than list match, match_list can contain many items.  
Function /S ListMatch2(list,match_list)
	String list,match_list
	Variable i,j
	String entry
	String new_list=""
	String matches
	for(i=0;i<ItemsInList(match_list);i+=1)
		entry=StringFromList(i,match_list)
		matches=ListMatch(list,entry)
		if(strlen(matches))
			new_list=new_list+RemoveEnding(matches,";")+";"
		endif
	endfor
	new_list=UniqueList(new_list)
	return new_list
End

Function /S RegenList(list)
	String list
	Variable i
	String entry
	String new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		entry=StringFromList(i,list)
		new_list=new_list+entry+";"
	endfor
	return new_list
End

Function IsEmptyString(str)
	String str
	return !cmpstr(str,"")
End

Function /S Append2List(entry,list)
	String entry,list
	return entry+";"+list
End

Function MeanList(list[,keep_NaNs])
	String list
	Variable keep_NaNs
	Variable i,total,item,num_items
	if(!keep_NaNs)
		list=RemoveFromList("NaN",list)
	endif
	total=0
	num_items=ItemsInList(list)
	for(i=0;i<num_items;i+=1)
		item=str2num(StringFromList(i,list))
		total+=item
	endfor
	return total/num_items
End

Function SEMlist(list)
	String list
	Variable i,item,num_items
	Make /n=0 temp
	num_items=ItemsInList(list)
	for(i=0;i<num_items;i+=1)
		InsertPoints 0,1,temp
		item=NumFromList(i,list)
		temp[0]=item
	endfor
	WaveStats /Q temp
	KillWaves temp
	return V_sdev/sqrt(V_npnts)
End

// Gets the minimum value from a list
Function MinList(list)
	String list
	Variable i,minn,candidate
	minn=str2num(StringFromList(0,list))
	for(i=1;i<ItemsInList(list);i+=1)
		candidate=str2num(StringFromList(i,list))
		minn=min(minn,candidate)
	endfor
	return minn
End

// Gets the maximum value from a list
Function MaxList(list)
	String list
	Variable i,maxx,candidate
	maxx=str2num(StringFromList(0,list))
	for(i=1;i<ItemsInList(list);i+=1)
		candidate=str2num(StringFromList(i,list))
		maxx=max(maxx,candidate)
	endfor
	return maxx
End

Function /S GraphList()
	return WinList("*",";","WIN:1") // List of all open graphs
End

Function /S StringFromIndex(index,wave_list[,sep])
	Variable index
	String wave_list,sep // The separator is for the output list.  The input list is assumed to be semicolon separated.  
	if(ParamIsDefault(sep))
		sep=";"
	endif
	Variable i; String wave_name
	String list=""
	for(i=0;i<ItemsInList(wave_list);i+=1)
		wave_name=StringFromList(i,wave_list)
		if(!waveexists($wave_name))
			printf "[StringFromIndex] No such wave in the current folder: %s.\r",wave_name
			abort
		endif
		if(WaveType($wave_name))
			Wave numWave=$wave_name
			list+=num2str(numWave[index])+sep
		else
			Wave /T textWave=$wave_name
			list+=textWave[index]+sep
		endif
	endfor
	return list
End

Function /S AddFlanking(list,flank[,sep])
	String list,flank,sep
	Variable i
	String new_list=""
	String list_item
	if(ParamIsDefault(sep))
		sep=";"
	endif
	for(i=0;i<ItemsInList(list,sep);i+=1)
		list_item=StringFromList(i,list,sep)
		new_list+=flank+list_item+flank+sep
	endfor
	if(!StringMatch(list[strlen(list)-1],sep)) // If there was not a trailing separator in the original.  
		new_list=new_list[0,strlen(new_list)-2] // Keep it out of the new one as well.  
	endif
	return new_list
End

function /S ZipLists(lists[,sep])
	wave /t lists
	string sep
	
	sep = selectstring(!paramisdefault(sep),"",sep)
	string new_list = ""
	variable i,j
	for(i=0;i<itemsinlist(lists[0]);i+=1)
		for(j=0;j<numpnts(lists);j+=1)
			string list = lists[j]
			string item = stringfromlist(min(i,itemsinlist(lists[j])-1),list)
			new_list += item+sep
		endfor
		new_list+=";"
	endfor
	return new_list
end

Function /S AddSuffix(list,suffix[,sep])
	String list,suffix,sep
	Variable i
	String new_list=""
	String list_item
	if(ParamIsDefault(sep))
		sep=";"
	endif
	for(i=0;i<ItemsInList(list,sep);i+=1)
		list_item=StringFromList(i,list,sep)
		new_list+=list_item+suffix+sep
	endfor
	if(!StringMatch(list[strlen(list)-1],sep)) // If there was not a trailing separator in the original.  
		new_list=new_list[0,strlen(new_list)-2] // Keep it out of the new one as well.  
	endif
	return new_list
End

Function /S AddPrefix(list,prefix)
	String list,prefix
	Variable i
	String new_list=""
	String list_item
	for(i=0;i<ItemsInList(list);i+=1)
		list_item=StringFromList(i,list)
		new_list+=prefix+list_item+";"
	endfor
	if(StringMatch(list[strlen(list)-1],";"))
		return new_list
	else
		return new_list[0,strlen(new_list)-2] // Omit last semi-colon
	endif
End

// Adds a semicolon at the end of a string if there isn't one; otherwise, does nothing.  
Function /S AddSemiColon(str)
	String str
	if(!cmpstr(str[strlen(str)-1],";"))
		return str
	else
		return str+";"
	endif
End

Function SerialStringMatch(list,str)
	String list,str
	Variable i
	String match_str
	for(i=0;i<ItemsInList(list);i+=1)
		match_str=StringFromList(i,list)
		if(StringMatch(str,match_str) == 1)
			return 1
		endif
	endfor
	return 0
End

Function /S KeyValues(list,to_what)
	String list
	String to_what
	Variable num
	strswitch(to_what)
		case "keys":
			num=0
			break
		case "values":
			num=1
			break
		default:
			printf "Unrecognized parameter: %s.\r",to_what
	endswitch
	Variable i
	String new_list=""
	String item,entry
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		entry=StringFromList(num,item,":")
		new_list=Append2List(entry,new_list)
	endfor
	return new_list
End

function BitList2Num(list)
	string list
	
	variable i,bits=0
	for(i=0;i<itemsinlist(list);i+=1)
		variable num=str2num(stringfromlist(i,list))
		bits=bits | 2^num
	endfor
	return bits
end

function /s Num2BitList(bits)
	variable bits
	
	string list=""
	variable i,maxBit=floor(log(bits)/log(2))
	for(i=1;i<=maxBit;i+=1)
		if(bits & 2^i)
			list+=num2str(i)+";"
		endif
	endfor
	return list
end

Function PlotList(list [,folder,append])
	String list
	String folder,append
	String curr_folder=GetDataFolder(1)
	if(ParamIsDefault(folder))
	else
		FindFolder(folder)
	endif
	Variable i
	String wave_name
	if(ParamIsDefault(append))
		Display /K=1
	endif
	for(i=0;i<ItemsInList(list);i+=1)
		wave_name=StringFromList(i,list)
		AppendToGraph $wave_name
	endfor
	SetDataFolder curr_folder
End

Function /S WildList(list [,left,right])
	String list
	Variable left,right
	String left_str=""
	String right_str=""
	if(ParamIsDefault(left) || left!=0)
		left_str="*"
	endif
	if(ParamIsDefault(right) || right!=0)
		right_str="*"
	endif
	Variable i
	String item
	String new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		item=left_str+item+right_str
		new_list=Append2List(item,new_list)
	endfor
	return new_list
End

// Better than RemoveFromList, it takes wildcards)
Function /S RemoveFromList2(match_str,list)
	String match_str,list // match_str can itself be a list
	String matches=ListMatch2(list,match_str)
	return RemoveFromList(matches,list)
End

Function /S RemoveEnding2(list,ending)
	String list,ending
	Variable i
	String new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		String item=StringFromList(i,list)
		new_list+=RemoveEnding(item,ending)+";"
	endfor
	return new_list
End

// Extends a list to include anything waves in a given folder that contains a bad lists entry plus the suffix in its name
Function ExtendBadList1(bad_lists,suffix,folder)
	String bad_lists,suffix,folder
	String curr_folder=GetDataFolder(1)
	Variable i
	String candidates,bad_list_entry,new_entries
	for(i=0;i<ItemsInList(bad_lists);i+=1)
		SetDataFolder root: // Assumes that the bad lists are in root
		SVar bad_list=$StringFromList(i,bad_lists)
		Variable j
		folder=FindFolder(folder)
		candidates=WaveList("*",";","")
		for(j=0;j<itemsInList(bad_list);j+=1)
			bad_list_entry=StringFromList(j,bad_list)
			new_entries=ListMatch(candidates,"*"+bad_list_entry+suffix+"*")
			new_entries=RemoveFromList(bad_list_entry,new_entries) // Make sure it is not a duplicate (things already on the bad list)
			if(cmpstr("",new_entries)) // If it resembles something on the bad list
				bad_list=new_entries+bad_list // Put it on the bad list
				j+=ItemsInList(new_entries)
			endif
		endfor
	endfor
	SetDataFolder curr_folder
End

// Takes the first 3 parts of every item on the bad list (synapse specific), and anything with that and contains is added to the bad list
Function ExtendBadList2(bad_lists,contains,folder)
	String bad_lists,contains,folder
	String curr_folder=GetDataFolder(1)
	Variable i
	String candidates,bad_list_entry,bad_list_entry2,new_entries
	for(i=0;i<ItemsInList(bad_lists);i+=1)
		SetDataFolder root: // Assumes that the bad lists are in root
		SVar bad_list=$StringFromList(i,bad_lists)
		Variable j
		folder=FindFolder(folder)
		candidates=WaveList("*",";","")
		for(j=0;j<itemsInList(bad_list);j+=1)
			bad_list_entry=StringFromList(j,bad_list)
			if(!cmpstr("NMDA",StringFromList(3,bad_list_entry,"_")))
				bad_list_entry2=RemoveListItem(3,bad_list_entry,"_") // Totally specific to the NR2 project
			else
				bad_list_entry2=bad_list_entry
			endif
			new_entries=ListMatch(candidates,"*"+bad_list_entry2+"*")
			new_entries=ListMatch(new_entries,"*"+contains+"*")
			new_entries=RemoveFromList(bad_list_entry,new_entries) // Make sure it is not a duplicate (things already on the bad list)
			if(cmpstr("",new_entries)) // If it resembles something on the bad list
				bad_list=new_entries+bad_list // Put it on the bad list
				j+=ItemsInList(new_entries)
			endif
		endfor
	endfor
	SetDataFolder curr_folder
End

// Prints a list out, item by item
Function PrintList(list)
	String list
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		printf "%s\r",StringFromList(i,list)
	endfor
End

// Gets mean values from a list with keys
Function WaveFromKeyList(keys,list_string[,bad_list_name,name,start])
	String keys,list_string // Pass the name of the list in as a string
	String bad_list_name,name // Optional new name for the wave
	Variable start // Start at this position in the list
	SVar list=$list_string
	if(ParamIsDefault(name))
		name=list_string
	endif
	String bad_list
	if(ParamIsDefault(bad_list_name))
		bad_list=""
	else
		SVar bad_list2=$bad_list_name
		bad_list=bad_list2
	endif
	KillWaves /Z $("W_"+name)
	Make /o /n=0 $("W_"+name); Wave theWave=$("W_"+name)
	Variable i
	for(i=0;i<start;i+=1)
		list=RemoveListItem(0,list)
	endfor
	list=ListMatch2(list,keys) // Select the subset of the list with keys contained in the string "keys"
	String item,key
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		key=StringFromList(0,item,":")
		if(FindListItem(key,bad_list)==-1)
			Redimension /n=(numpnts(theWave)+1) theWave
			theWave[numpnts(theWave)-1]=str2num(StringFromList(1,item,":"))
		endif
	endfor
End

// Replaces one list separator with another.
Function /S ReplaceSeparator(list,old_sep,new_sep)
	String list,old_sep,new_sep
	String new_list=""
	Variable i
	for(i=0;i<ItemsInList(list,old_sep);i+=1)
		new_list=new_list+StringFromList(i,list,old_sep)+new_sep
	endfor
	return new_list
End

// Removes all items in list that do not match match_list
Function /S RemoveNonMatches(list,match_list)
	String list,match_list
	Variable i
	String entry
	String new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		entry=StringFromList(i,list)
		if(FindListItem(entry,match_list)!=-1)
			new_list=new_list+entry+";"
		endif
	endfor
	return new_list
End

// Removes empty entries in a list
Function /T RemoveEmpties(list)
	String list
	Variable i=0
	String entry
	Do
		entry=StringFromList(i,list)
		if(!cmpstr(entry,""))
			list=RemoveListItem(i,list)
		else
			i+=1
		endif
	While(i<ItemsInList(list))
	return list
End


Function /S ListGraphs([match])
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	return WinList(match,";","WIN:1") // Gets a list of all graphs
End

Function /S ListLayouts([match])
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	return WinList(match,";","WIN:4") // Gets a list of all layouts
End

Function /S ListTables([match])
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	return WinList(match,";","WIN:2") // Gets a list of all tables
End

Function /S ListNotebooks([match])
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	return WinList(match,";","WIN:16") // Gets a list of all tables
End

Function /S ListPanels([match])
	String match
	if(ParamIsDefault(match))
		match="*"
	endif
	return WinList(match,";","WIN:64") // Gets a list of all tables
End

// Returns a string containing the name of the topmost window (graph, table, layout,or panel).  
Function /S TopWindow()
	return StringFromList(0,WinList("*",";","WIN:71"))
End

// Returns a string containing the name of the topmost graph.
Function /S TopGraph()
	return StringFromList(0,WinList("*",";","WIN:1"))
End

// Returns a string containing the name of the topmost panel.  
Function /S TopPanel()
	return StringFromList(0,WinList("*",";","WIN:64"))
End

// Returns a string containing the name of the topmost layout.  
Function /S TopLayout()
	return StringFromList(0,WinList("*",";","WIN:4"))
End

// Returns a string containing the name of the topmost window (graph, table, layout,or panel).  
Function /S TopNotebook()
	return StringFromList(0,WinList("*",";","WIN:16"))
End


Function /S Wild(str)
	String str
	return "*"+str+"*"
End

Function ReplaceInAllStrings(find,replace)
	String find,replace
	String list=StringList("*",";")
	Variable i
	String item
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		SVar str=$item
		str=ReplaceString(find,str,replace)
	endfor
End

// Expands a list of the form "3,6;12,14" to "3;4;5;6;12;13;14"
threadsafe Function /S ListExpand(list[,no_sort])
	String list
	variable no_sort
	
	list=ReplaceString("-",list,",")
	list=ReplaceString("!",list,"~")
	String new_list="",exclude=""
	Variable i,j
	String sub_list,first,last,item
	
	// Include.  
	for(i=0;i<ItemsInList(list);i+=1)
		sub_list=StringFromList(i,list)
		if(!StringMatch(sub_list,"~*"))
			first=StringFromList(0,sub_list,",")
			last=StringFromList(1,sub_list,",")
			if(!cmpstr("",last))
				new_list=AddListItem(first,new_list,";",Inf)
			else
				variable first_=str2num(first)
				variable last_=str2num(last)
				first_=numtype(first_) ? 0 : first_
				last_=numtype(last_) ? 0 : last_
				for(j=first_;j<=last_;j+=1)
					item=num2str(j)
					new_list=AddListItem(item,new_list,";",Inf)
				endfor
			endif
		endif
	endfor
	
	// Exclude.  
	for(i=0;i<ItemsInList(list);i+=1)
		sub_list=StringFromList(i,list)
		if(StringMatch(sub_list,"~*"))
			sub_list=sub_list[1,strlen(sub_list)-1]
			first=StringFromList(0,sub_list,",")
			last=StringFromList(1,sub_list,",")
			if(!cmpstr("",last))
				exclude=AddListItem(first,exclude)
			else
				first_=str2num(first)
				last_=str2num(last)
				first_=numtype(first_) ? 0 : first_
				last_=numtype(last_) ? 0 : last_
				for(j=first_;j<=last_;j+=1)
					item=num2str(j)
					exclude=AddListItem(item,exclude)
				endfor
			endif
		endif
	endfor
	if(stringmatch(exclude,""))
		exclude = " "
	endif
	new_list=RemoveFromList(exclude,new_list)
	
	if(!no_sort)
		if(grepstring(new_list,"[A-Za-z_]"))
			new_list = sortlist(new_list) // Alphanumeric sort ascending.  
		else
			new_list = SortList(new_list,";",2) // Numeric sort ascending.  
		endif
	endif
	
	return new_list
End

// Contracts a list of the form "3;4;5;6;12;13;14" to "3,6;12,14"
Function /S ListContract(list)
	String list
	String new_list=""
	Variable i,j,curr_num,last_num,length
	String sub_list,first,last,item
	new_list=StringFromList(0,list)
	curr_num=str2num(new_list)
	length=1
	for(i=1;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		if(str2num(item)==curr_num+1) // The next number is one higher than the previous number
			curr_num+=1
			length+=1
		elseif(str2num(item)>curr_num+1) // The next number is more than one higher
			if(length>1)
				new_list+="-"+StringFromList(i-1,list)+";"+item
			else
				new_list+=";"+item
			endif
			last_num=str2num(item)
			curr_num=last_num
			length=1
		endif
	endfor
	if(curr_num>last_num)
		new_list+="-"+num2str(curr_num)
	endif
	return new_list
End

Function /S ReverseListOrder(list)
	String list
	String new_list=""
	Variable i
	String item
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		new_list=AddListItem(item,new_list)
	endfor
	return new_list
End

// Better than wavelist, it searches an arbitrary folder and return waves that both match any entry in match (which can be a list with wildcards), 
// and do not match any entry in no_match (which can also be a list with wildcards).  
Function /s WaveList2([folder,df,match,win,except,type,recurse,fullPath,minDims])
	String folder // The name of the folder to use, such as "status"; Enter "" if you want to use the current folder.
	DFRef df // A data folder reference instead of a folder name.  
	String win // A window name instead of a data folder.  
	String match // A semicolon separated list of possible matching names, including asterisks.  
	String except // A semicolon separated list of things to not include.  Has priority.  
	variable type // Wave type: Text (0) or Numeric (1)
	variable recurse // Recursively search subfolders.  
	variable fullPath // Return full path names of waves.  
	wave minDims

	folder=selectstring(ParamIsDefault(folder),folder,":")
	match=selectstring(ParamIsDefault(match),match,"*")
	except=selectstring(ParamIsDefault(except),except,"")
	type=paramisdefault(type) ? 1 : type
	if(ParamIsDefault(df))
		df=$folder
	endif
	variable i,j
	string waves=""
	
	if(!paramisdefault(win))
		if(!strlen(win))
			win=WinName(0,1)
		endif
		string traces=TraceNameList(win,";",3)
		for(i=0;i<ItemsInList(traces);i+=1)
			string trace=StringFromList(i,traces)
			if(strlen(listmatch2(trace,match)) && !strlen(listmatch2(trace,except)))
				wave w=TraceNameToWaveRef(win,trace)
				if(fullPath)
					waves+=getwavesdatafolder(w,2)+";"
				else
					waves+=nameofwave(w)+";"
				endif
			endif
		endfor
	else
		for(i=0;i<CountObjectsDFR(df,1);i+=1)
			string wave_name=getindexedobjnamedfr(df,1,i)
			if(strlen(listmatch2(wave_name,match)) && !strlen(listmatch2(wave_name,except)))
				wave /z w=df:$wave_name
				if(paramisdefault(type) || (wavetype(w)>0) == type)
					variable tooSmall=0
					if(!paramisdefault(minDims))
						for(j=0;j<numpnts(minDims);j+=1)
							if(dimsize(w,j)<minDims[j])
								tooSmall = 1
							endif
						endfor
						if(tooSmall)
							continue
						endif
					endif
					if(fullPath)
						waves+=getwavesdatafolder(w,2)+";"
					else
						waves+=wave_name+";"
					endif
				endif
			endif
		endfor
	endif
	if(recurse)
		for(i=0;i<CountObjectsDFR(df,4);i+=1)
			string subfolderName=getindexedobjnamedfr(df,4,i)
			dfref subdf=df:$subfolderName
			waves+=wavelist2(df=subdf,match=match,except=except,recurse=1,fullPath=fullPath)
		endfor	
	endif
	return waves
End

// Sorts all the waves in the wave reference wave 'sortWaves' such that the items in 'keyWave' are in order.  
// Can sort arbitrarily long lists of waves.    
Function Sort2(keyWave,sortWaves[,reverseSort])
	wave keyWave
	wave /wave sortWaves
	variable reverseSort
	
	duplicate /o keyWave,tempWave
	variable i=0
	do
		string cmd="Sort /A "
		if(reverseSort)
			cmd+="/R "
		endif
		cmd+=getwavesdatafolder(tempWave,2)
		variable proceed=0
		do 
			wave /z w=sortWaves[i]
			if(waveexists(w))
				cmd+=","+getwavesdatafolder(w,2)
				proceed+=1
			endif
			i+=1
		while(strlen(cmd)<255 && i<numpnts(sortWaves))
		if(proceed)
			execute /Q cmd
		endif
	while(i<numpnts(sortWaves))
	killwaves /z tempWave
End

// Strips characters from the end of a string
Function /S StripChars(str,num)
	String str
	Variable num
	Variable length=strlen(str)
	return str[0,strlen(str)-1-num]
End

Function Chan2Num(channel)
	String channel
	strswitch(channel)
		case "R1":
			return 0
			break
		case "L2":
			return 1
			break
		case "B3":
			return 2
			break
		default:
			break
	endswitch
End

// Takes something like "10,11;20,21;30,31" and returns "10,20,30"
Function /S ListSubSet(list,index)
	String list
	Variable index
	Variable i
	String new_list=""
	String entry
	for(i=0;i<ItemsInList(list);i+=1)
		entry=StringFromList(i,list)
		new_list=new_list+StringFromList(index,entry,",")+";"
	endfor
	return new_list
End

// Extracts items first through last from list and returns a new list.  
Function /S ListExtract(list,first,last)
	String list
	Variable first,last
	Variable i
	String new_list=""
	for(i=max(first,0);i<=min(last,ItemsInList(list));i+=1)
		String entry=StringFromList(i,list)
		new_list=new_list+entry+";"
	endfor
	return new_list
End

Function NumFromList(num,list[,sep])
	Variable num
	String list,sep
	if(ParamIsDefault(sep))
		sep=";"
	endif
	return str2num(StringFromList(num,list,sep))
End

// Takes a list of pairs, e.g "1,2;10,15;20,23" and removes any pair that is entirely flanked by a member of bad_ranges
// For example, if bad_ranges was "0,5;18,24", then "1,2" and "20,23" would be removed from the list of pairspairs
Function /S RemovePairsInBadRange(pairs,bad_ranges)
	String pairs
	String bad_ranges
	String pair,range
	Variable i,j,left,right,range_left,range_right,removed
	i=0
	Do
		pair=StringFromList(i,pairs)
		left=str2num(StringFromList(0,pair,","))
		right=str2num(StringFromList(1,pair,","))
		for(j=0;j<ItemsInList(bad_ranges);j+=1)
			range=StringFromList(j,bad_ranges)
			range_left=str2num(StringFromList(0,range,","))
			range_right=str2num(StringFromList(1,range,","))
			if(left>range_left && right<range_right)
				pairs=RemoveListItem(i,pairs)
				removed=1
				break
			endif
		endfor
		if(removed==1)
			removed=0
		else
			i+=1
		endif
	While(i<ItemsInList(pairs))
	return pairs
End

// Takes entries of a text wave and converts them to a list
Function /S WavT2List(theWave)
	Wave /T theWave
	Variable i
	String list=""
	for(i=0;i<numpnts(theWave);i+=1)
		list+=theWave[i]+";"
	endfor
	return list
End

// Takes entries of a numeric wave and converts them to a list
Function /S NumWave2List(theWave)
	Wave theWave
	Variable i
	String list=""
	for(i=0;i<numpnts(theWave);i+=1)
		list+=num2str(theWave[i])+";"
	endfor
	return list
End

// Adds an item to the end of a list
Function /S Add2List(item,list)
	String item,list
	return AddListItem(item,list,";",Inf)
End

// Takes a list and generates a new list with only one entry for every unique value in the original list
Function /S UniqueList(list)
	String list
	String new_list=""
	Variable i
	String item,match
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		match=ListMatch(new_list,item)
		if(IsEmptyString(match))
			new_list+=item+";"
		endif
	endfor
	return new_list
End

// Find the experiments that have both a valid measurement from list1 and a valid measurement from list2
Function /S GetDifs(list1,list2,bad_list)
	String list1,list2
	String bad_list // Makes sure nothing on the bad list (e.g. current too small) is on the returned list
	Variable i
	String item,full_key,key,items,match,entry1,entry2
	items=""
	String answer=""
	for(i=0;i<ItemsInList(list1);i+=1)
		item=StringFromList(i,list1)
		full_key=StringFromList(0,item,":")
		key=RemoveListItem(3,item,"_")
		match=ListMatch(list2,key+"*")
		match=StringFromList(0,match)
		if(!IsEmptyString(match) && !StringMatch(bad_list,"*"+full_key+"*"))
			entry1=StringFromList(1,item,":")
			entry2=StringFromList(1,match,":")
			items+=key+":"+entry1+","+entry2+";"
		endif
	endfor
	answer=items
	return answer
End

// Returns the number of comma-separated pairs (in the semicolon-separated list) whose second value
// is 'size' more than its first value
Function NumPairsOfSize(list,size)
	String list
	Variable size
	Variable i,first,second,num
	String pair
	for(i=0;i<ItemsInList(list);i+=1)
		pair=StringFromList(i,list)
		first=Str2Num(StringFromList(0,pair,","))
		second=Str2Num(StringFromList(1,pair,","))
		if(second>first+size)
			num+=1
		endif
	endfor
	return num
End

// Returns the difference between two values in a comma separated pair.  
Function PairDiff(pair)
	String pair
	Variable first=str2num(StringFromList(0,pair,","))
	Variable second=str2num(StringFromList(1,pair,","))
	return second-first
End

Function /S List2WavT(list[,name])
	String list
	String name
	if(ParamIsDefault(name))
		name="W_List"
	endif
	Make /o/T/n=(ItemsInList(list)) $name
	Wave /T textWave=$name
	Variable i
	for(i=0;i<ItemsInList(list);i+=1)
		textWave[i]=StringFromList(i,list)
	endfor
	return GetWavesDataFolder(textWave,2)
End  

function /s AddValues2Keys(keys,values[,modular,sep])
	string keys,values,sep
	variable modular // Start at the first value when the end is reached.  
	
	modular=paramisdefault(modular) ? 1 : modular
	sep=selectstring(!paramisdefault(sep),":",sep)
	
	variable i
	string str=""
	for(i=0;i<itemsinlist(keys);i+=1)
		string key=stringfromlist(i,keys)
		if(modular)
			string value=stringfromlist(mod(i,itemsinlist(values)),values)
		else
			value=stringfromlist(i,values)
		endif
		sprintf str,"%s%s%s%s;",str,key,sep,value
	endfor
	return str
end

// Replaces the item at index with the new item.  Adds a final semicolon, if there is one.  
Function /S ReplaceListItem(new_item,list,index)
	String new_item,list
	Variable index
	Variable i; String new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		if(i!=index)
			new_list+=StringFromList(i,list)+";"
		else
			new_list+=new_item+";"
		endif
	endfor
	return new_list
End

// Multiples every value in a list by a constant
Function /S MultiplyList(list,multiple)
	String list
	Variable multiple
	Variable i; String old_val,new_val,new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		old_val=StringFromList(i,list)
		new_val=num2str(multiple*str2num(old_val))
		new_list+=new_val+";"
	endfor
	return new_list
End

Function /S RemovePrefix(list,prefix)
	String list,prefix
	Variable i; String item,new_list=""
	for(i=0;i<ItemsInList(list);i+=1)
		item=StringFromList(i,list)
		if(StringMatch(item,prefix+"*"))
			item=item[strlen(prefix),strlen(item)-1]
		endif
		new_list+=item+";"
	endfor
	return new_list
End

// Returns the index of the region that 'num' is in, for 'regions' of the form "5,12;17,24"
// Returns -1 if it is not in any of the regions.  
Function InRegionList(num,regions)
	Variable num
	String regions
	Variable i
	for(i=0;i<ItemsInList(regions);i+=1)
		String region=StringFromList(i,regions)
		Variable lower=str2num(StringFromList(0,region,","))
		Variable upper=str2num(StringFromList(1,region,","))
		if(num>=lower && num<=upper)
			return i
		endif
	endfor
	return -1	
End

// Returns the degree of overlap between test region and all of the regions in 'regions', for 'regions' of the form "5,12;17,24" and for test_region of the form "8,19".  
Function IntersectRegionList(test_region,regions)
	String test_region
	String regions
	
	Variable test_lower=str2num(StringFromList(0,test_region,","))
	Variable test_upper=str2num(StringFromList(1,test_region,","))
	if(test_upper<test_lower)
		Variable temp=test_lower
		test_lower=test_upper
		test_upper=temp
	endif
	Variable i,total_overlap=0
	for(i=0;i<ItemsInList(regions);i+=1)
		String region=StringFromList(i,regions)
		Variable lower=str2num(StringFromList(0,region,","))
		Variable upper=str2num(StringFromList(1,region,","))
		if(upper<lower)
			temp=lower
			lower=upper
			upper=temp
		endif
		Variable overlap=0
		if(test_upper<=upper && test_upper>=lower)
			if(test_lower>=lower)
				overlap=test_upper-test_lower
			elseif(test_lower<lower)
				overlap=test_upper-lower
			endif
		elseif(test_lower>=lower && test_lower<=upper)
			if(test_upper<=upper) // Should not be true if we are here.  
				overlap=test_upper-test_lower
			elseif(test_upper > upper) // Should be true if we are here.  
				overlap=upper-test_lower
			endif
		elseif(test_lower<lower && test_upper>upper)
			overlap=upper-lower
		endif
		total_overlap+=overlap
	endfor
	return total_overlap
End

