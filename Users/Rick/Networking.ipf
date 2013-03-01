#pragma rtGlobals=1		// Use modern global access method.

#if exists("sockitopenconnection")
function email(selfServer,smtpServer,username,password,from,to,subject,message)
	string selfServer,smtpServer,username,password,from,to,subject,message
	 
	variable sock		//holds the SOCKIT reference
	make/o/t buf		//holds the output from the SOCKIT connection
	 
	sockitopenconnection /time=1 sock,smtpServer,25,buf	//open a SOCKIT connection to the mail server
	 
	sockitsendmsg sock,"HELO "+selfServer+"\n"		//say HELO to the server
	sockitsendmsg sock,"AUTH LOGIN\n"		//SMTP LOGIN, NOT VERY SECURE
	sockitsendmsg sock,base64encode(username)+"\r\n"
	sockitsendmsg sock,base64encode(password)+"\r\n"
	 
	sockitsendmsg sock,"MAIL FROM:"+from+"\n"		//say who you are
	sockitsendmsg sock,"RCPT TO:"+to+"\n"		//say who the recipient is
	 
	sockitsendmsg sock,"DATA\n"		//start the message
	sockitsendmsg sock,"Subject:"+subject+"\r\n"		//subject line, note double newline is required
	sockitsendmsg sock,message+"\r\n"		//the message
	 
	sockitsendmsg sock,"\r\n.\r\n"		//finish the message and send
	
	sockitcloseconnection(sock)	//close the SOCKIT connection
	killwaves /z buf
end

function email2(password,to,subject,message)
	string password,to,subject,message
	
	string selfServer = "igormailer.rickgerkin.com"
	string smtpServer = "smtp.mail.yahoo.com"
	string username = "rgerkin"
	string from = "rgerkin@yahoo.com"
	email(selfServer,smtpServer,username,password,from,to,subject,message)
end

// Stunnel must be running on port 5000 for this to work.  
Function gmailMessage(username, password, recipients, subject, message)
	string username, password, recipients, subject, message
	 
	variable sockID,ii
	make/t/o buf
	Wave/t buf
	try
		sockitopenconnection/q sockID, "localhost",5000,buf
		if(sockID<1)
			abort
		endif
		sockitsendnrecv/SMAL/TIME=2 sockID, "EHLO gmail.com\n"
		if(V_Flag || !stringmatch(S_tcp[0,2],"220"))
			abort
		endif
		sockitsendnrecv/SMAL/TIME=2 sockID, "AUTH LOGIN\n"
		if(V_Flag  || !stringmatch(S_tcp[0,2],"334"))
			abort
		endif
		sockitsendnrecv/SMAL/TIME=2 sockid, base64encode(username)+"\n"
		if(V_Flag  || !stringmatch(S_tcp[0,2],"334"))
			abort
		endif
		sockitsendnrecv/SMAL/TIME=2 sockid, base64encode(password)+"\n"
		if(V_Flag  || !stringmatch(S_tcp[0,2],"235"))
			abort
		endif
		sockitsendnrecv/SMAL/TIME=2 sockID, "MAIL FROM:<"+username+"@gmail.com>\n"
		if(V_Flag  || !stringmatch(S_tcp[0,2],"250"))
			abort
		endif
		for(ii=0 ; ii<itemsinlist(recipients) ; ii+=1)
			sockitsendnrecv/SMAL/TIME=2 sockID, "RCPT TO:<"+stringfromlist(ii, recipients)+">\n"
		endfor
		sockitsendnrecv/SMAL/TIME=2 sockID, "DATA\n"
		if(V_Flag  || !stringmatch(S_tcp[0,2],"354"))
			abort
		endif
		sockitsendnrecv sockID, "From:"+username+"\n"
		for(ii=0; ii<itemsinlist(recipients) ; ii+=1)
			sockitsendnrecv sockID, "To:"+stringfromlist(ii, recipients)+"\n"
		endfor
		sockitsendnrecv sockID, "Subject:"+subject+"\n\n"
		sockitsendnrecv sockID, message+"\r\n"
		sockitsendnrecv sockID, "."+"\r\n"
		if(V_Flag  || !stringmatch(S_tcp[0,2],"250"))
			abort
		endif
	catch
		print "Failed to send email"
	endtry
	sockitsendnrecv sockID, "QUIT\n"
	 
	sockitcloseconnection(sockID)
	killwaves/z buf
End
#endif