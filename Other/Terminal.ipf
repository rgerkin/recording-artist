// $URL: svn://churro.cnbc.cmu.edu/igorcode/Recording%20Artist/Other/Terminal.ipf $
// $Author: rick $
// $Rev: 424 $
// $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#pragma rtGlobals=1		// Use modern global access method.

#if exists("sockitopenconnection")

static strconstant package_name="SockitTerminalClient"
static strconstant terminator="\r\n"
static constant lines=20

Function InitClient()
	String curr_folder=GetDataFolder(1)
	NewDataFolder /O root:Packages
	NewDataFolder /O/S root:Packages:$package_name
	Variable /G buff_size=128
	Variable /G sock_num
	Make /o/T/n=(buff_size) Buffer
	String /G command=""
	String /G host_name=""
	Variable /G port_num=21
	Variable /G connected=0
	SetDataFolder curr_folder
	MakeClientPanel()
End

Function MakeClientPanel()
	String curr_folder=GetDataFolder(1)
	SetDataFolder root:Packages:$package_name
	DoWindow /K SockitTerminalClient
	NewPanel /K=1/W=(100,100,700,500) /N=$package_name as "Sockit Terminal Client"
	Wave /T Buffer
	Buffer=""
	ListBox Terminal listWave=Buffer, mode=0, size={475,300}, pos={10,35}, widths={290,25}, row=dimsize(Buffer,0)-lines, proc=TerminalProc
	SetVariable CommandLine, pos={10,345},size={475,25}, variable=command, title=" ",proc=CommandLineProc
	SetVariable HostName, pos={10,10},size={200,25}, variable=host_name, title="Host Name:"
	SetVariable PortNum, pos={220,10},size={85,25}, variable=port_num, title="Port:"
	NVar connected
	Button Connect, pos={315,6},size={85,20},title=SelectString(connected,"Connect","Disconnect"),proc=ClientConnect
	SetDataFolder curr_folder
End


Function TestClient()
	String curr_folder=GetDataFolder(1)
	SetDataFolder root:Packages:$package_name
	NVar sock_num
	Wave /T Buffer
	sock_num=sockitopenconnection("ftp.wavemetrics.com",21,Buffer,"",terminator,0)
	sockitsendmsg(sock_num,"USER anonymous\r\n")
	sockitsendmsg(sock_num,"PASS rig4@pitt.edu\r\n")
	SetDataFolder curr_folder
End

Function TerminalProc(LB_Struct) : ListBoxControl
	STRUCT WMListBoxAction &LB_Struct
	
End

Function ClientConnect(ctrlName) : ButtonControl
	String ctrlName
	NVar sock_num=$("root:Packages:"+package_name+":sock_num")
	NVar port_num=$("root:Packages:"+package_name+":port_num")
	SVar host_name=$("root:Packages:"+package_name+":host_name")
	Wave /T Buffer=$("root:Packages:"+package_name+":Buffer")
	NVar connected=$("root:Packages:"+package_name+":connected")
	if(connected)
		sockitcloseconnection(sock_num)
		connected=0
	else
		sock_num=sockitopenconnection(host_name,port_num,Buffer,"",terminator,0)
		connected=1
	endif
	Button Connect, title=SelectString(connected,"Connect","Disconnect"), win=$package_name
End

Function CommandLineProc(SV_Struct) :  SetVariableControl
	STRUCT WMSetVariableAction &SV_Struct
	if(SV_Struct.eventCode!=2) // The enter key was not pressed.  
		return 0
	endif
	String command=SV_Struct.sval
	command+="\r\n" // Add carriage return and line feed for telnet/ftp formatting.  
	NVar sock_num=$("root:Packages:"+package_name+":sock_num")
	sockitsendmsg(sock_num,command)
	//NVar buff_size=$("root:Packages:"+package_name+":buff_size")
	ListBox Terminal row=dimsize(Buffer,0)-lines
End

#endif 