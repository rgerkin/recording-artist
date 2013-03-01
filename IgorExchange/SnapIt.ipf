// ScreenSizer Module
// $Author: Jeffrey J Weimer$
// SVN History: $Revision: 424 $ on $Date: 2010-05-01 12:32:27 -0400 (Sat, 01 May 2010) $

#define English

#pragma rtGlobals=1
#pragma IgorVersion=6.10
#pragma version=1.0

#pragma IndependentModule=SnapIt
#pragma ModuleName=SnapIt

Static StrConstant thePackage="SnapIt"
Static StrConstant thePackageFolder="root:Packages:SnapIt"
Static StrConstant theProcedureFile = "SnapIt.ipf"
Static Constant thePackageVersion = 1.0
Static Constant hasHelp = 0

#ifdef English
Static StrConstant KillMeRequest="Do you really want to remove SnapIt?"
#endif
#ifdef Deutsch
Static StrConstant KillMeRequest="Moechten Sie verchlich SnapIt abloeschen?"
#endif

// panel width/height constants

Static Constant snitw=70
Static Constant snith=60

// Menu

Menu "Misc"
	Submenu "Panels"
		"SnapIt",/Q,ShowSnapItPanel()
	end
end

Function ShowSnapItPanel()

	if (WinType("SnapItPanel")!=0)
		DoWindow/F SnapItPanel
		return 0
	endif

	NewPanel/W=(25,25,25+snitw,25+snith)/FLT=1/N=SnapItPanel/K=1 as "SnapIt!"
	SetActiveSubwindow _endfloat_
	ModifyPanel/W=SnapItPanel noEdit=1
	
	Button camera,win=SnapItPanel, pos={5,5},title="",picture= SnapIt#SnapIt#SnapItButton, proc=SnapIt
	return 0
	
End

// Camera Button Control

Function SnapIt(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			CaptureFrontGraph()
			break
	endswitch

	return 0
End

Function CaptureFrontGraph()

	DFREF cdf= GetDataFolderDFR()
	string tstr=WinName(0,1,1), fldr
	variable ic, nl
	
	if (strlen(tstr)==0)
		DoAlert 0, "No front graph window"
		return 0
	endif

	if (!DataFolderExists(thePackageFolder))
		SetDataFolder root:
		NewDataFolder/O/S Packages
		NewDataFolder/O/S SnapIt
		string/g cgname="", cfldr=""
		SetDataFolder cdf
	endif

	SVAR cgname = root:Packages:SnapIt:cgname
	SVAR cfldr = root:Packages:SnapIt:cfldr

	cgname = tstr	
	
	fldr = cleanupname(tstr+DateTimeStamp(),0)
	
	TextBox/W=$cgname/A=RT/B=0/F=2/C/N=SnapShotXXX fldr
	DoUpdate
	sprintf tstr, "Capture the front graph %s as what name(.pxp)?", cgname
	prompt fldr, tstr
	DoPrompt "Choose Experiment Name",  fldr
	if (V_flag==1)
		TextBox/W=$cgname/K/N=SnapShotXXX
		return 0
	endif
	
	TextBox/W=$cgname/A=RT/B=0/F=2/C/N=SnapShotXXX fldr
	
	SaveGraphCopy/W=$cgname as fldr
	
	TextBox/W=$cgname/K/N=SnapShotXXX

	return 0

end

Function/S DateTimeStamp([sep])
	string sep
	
	string a, b, c, dstr, tstr
	string gExp
	
	if (ParamIsDefault(sep))
		sep = ""
	endif
	
	gExp = "([0-9]+):([0-9]+)"	
	SplitString/E=(gExp) secs2time(datetime,2), a, b
	tstr = a + b
	
	gExp = "([0-9]+)/([0-9]+)/([0-9]+)"	
	SplitString/E=(gExp) secs2date(datetime,-1), a, b, c

	dstr = c[2,3] + b + a
	
	return (dstr + sep +  tstr)

end

// Help Static Function

Static Function Help()

	if (!hasHelp)
		DoAlert 0, "NO HELP FOR THIS PACKAGE!"
		return 0
	endif

	if (strlen(thePackage)!=0)
		DisplayHelpTopic thePackage
	else
		DoAlert 0, "NO PACKAGE NAME FOR HELP!"
		return -1
	endif
	return 0
end

// Remove Me

Static Function RemoveMe([quiet])
	variable quiet
	
	if (ParamIsDefault(quiet) || (quiet == 0))
		DoAlert 1, KillMeRequest	
		if (V_flag == 2)
			return 0
		endif
	endif
	
	if (strlen(thePackageFolder)!=0)
		KillDataFolder/Z $thePackageFolder
	endif
	
	string theCmd
	if (strlen(thePackage)!=0)
		sprintf theCmd "DELETEINCLUDE \"%s\"" thePackage
		Execute/P/Z/Q theCmd
	endif
	if (strlen(theProcedureFile)!=0)
		sprintf theCmd "CloseProc/NAME=\"%s\"" theProcedureFile	
		Execute/P/Q theCmd
	endif
	
	return 0
end

// PNG: width= 174, height= 47
Static Picture SnapItButton
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!#%!!!!P#Qau+!;1qU_uKc;&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U+-oJd5u`*!m<i&q-.dG!p]'DUe\/H\m:CU3IGo."X!CUh78]j7"DGo_A49fK(pRHQ7M#gH;t=>W+
	V/RC4N'c3m"`ArUa/Q_":,VJQ:+A(-&Su[P2\A62jm$sZZ,W0l2>L"FjBg_4Ij!lD`>9u,W3"i5RqD
	;X/f"GrU)]'q=df5,1roP#S@OG,bipISfD'_B=BIbp:&lW5MDaDd<8J+75+kEWltl:<T@*B*&GX!pt
	6,EY^N1krldmmh)A?Af=7]X6_:<XF)H4DKCQA#)InL8n?ZjO=L=utNqe>n#03aZ3`/k!E.7cBlJ'6=
	2K[ifD7Ik105\:e#+Z&#%R0pngJS&K5abbSc_!;nif@EYGi<,'pPE"G6pr.0a_L).?$l"QpYGuW%fT
	/TnA.QJ?NbI)SUbH4nO-4(U??kRV(Y5JfVSF56mebMA6'XBTNcDE96,u]>\?<lHeNG1#U%Wp#:Hu"&
	LERtM>?oS07<^;IraMbKmLF@XV$]:d($MV<s!%ma1q6W*kCU>]<&D-Z2F$ZNi[rEVRQJKXXAK=d1Xj
	+VpJePep;J26D5k/TsKu-(JAa'QmEd;"%`(sc.QoL7u\B9mnc%RCn_&LFZ_to+oi4KJuCkmRid<`DF
	XjFo`.aZ3W024nG<4R]^sGIq[[4?2VL@s5C`\1/$HV@n%.ETh;@&#GAeIWpS9-kK0'e0WZ$jDAe#t0
	8TO2'Hn`r;.eKH7(n'D4(%RAh\_'i3c&>AbR+Bdj.N\@ib.`X?k"mjL,RUAjiP)kM.&FBs6mP(r:DC
	b\RWETG_/%^26qlIJDh%XghRa"6Gjp_TmL6pi#SRa0NY7J3cHXW%g9p6B^@mOV++<dD7imM>o)8hPY
	$GhF[5LTS<='he[<p.'IW3]SJ`!]_j(&PO=)nb=e87*U<TAA)q>`4"^lG`mW41hg0(l+Q(f_,h9.Gn
	CIpcY7N08\k"Z$aC%7N-CKV=4VOpVPH@EuOaf#a+o9i"RBG2$lZPu3hO'cMIn88qph\[gDJDSPS,+9
	(cJM:[_AU*(f2Xe'sc_2ZLTQn6EEnoGoKoVXl14[%hq1WE\[mMc81DP0GT.=E?^9#n$UJ1IqIZih'i
	0d[3<-X8j?\i$/Rq'KLB15<Aj#:q#0!sE4.)l>Js:GO_j6eFp5'b*tCJXN-YrqWbqQS/U4n%A804pV
	b$M?(IJX)\J<5qG*/,3&cC^$D!7Q$FmWKU+%lU9pRM:e4!`@.AtMlg(Vb>2&5Brnfs>hf$4$`ZpQB_
	ZL,R@#K<A6.!W^=4O!\!87g+qb"!l8],;!?RGIM'VqaZE[<)4@@JURMC'7$&-9a6!"BC[GT[!IGT6e
	HM@&gKM"]TKjYFBYSrKic@"VE$JeCJgebL`qrI94F>5O`6r8PG=qj9oRRCUaeU8.ij$8@(UA49fG\b
	3E.n%CA+TZ.ZP4HoG/4G7;3oenSd,P#!NF1#2Rh.]+QpuC93rY+19ipe]#`g;iFj`_!7)[Phe(dXSe
	p6Akt[IM1IAt9/o,ncJs7]R$Y;/7J[*>s.<O:[XA$4]nh!-Z:fLb`CX3"QLuC((>#SYa!CI=!D=C1A
	*&h2"$OhjjZ/V&ruK\GEb^rmJUb#CHf+@!iQK&L%D.5hH37,Vc<pG-.=eP<.3HdYVpN%3eP4IV\h.e
	G'mg.4,8+gZp1EH0CrW:7j`CietiAs%AuVS_a*:_/R;b<C#/1_X;Fn*bj(M2'ZPJOr.U0'F8^P5_(M
	P#Y(IQ@A!a'#QV>fWCVhs,)uYfJ5Afk@K\>P(n8\G]XV;;:50b@_H%eR.p&mL2OTu$&_/-u,Qo:u,-
	#B@Ph@e,?m-j,5r_NKrM&-93JAd-;?NsI;3Ea]lgYIer8mT9j7.s!NJ:R)+\@j=af2=BYI6O[\_19C
	WU^Q`g<oC&5bS_h`mE(IUFOmr$C*.Zc>5?1]i-8WHA7;\!-fomek%RjSB>;s*b.#G$*%f5<S7p>"g>
	bEHWYI0*X4m#DYoD,-SAc?<,9u:?G*MJZ7M`oUl$_Hp?^YlY`2C+b*iX4[/cG:P-HBQ*VEGp>"dg;Z
	O4Sf+XU8O)Mfje;@sJ>Lgo;hDq*#M'S%pX\^Gi&WkjJ`X#C_r$r"E,#4J@s>5D+s\6OD!QZe<'^h/=
	X6rY]\RKB3W&1%G^&N)CQ-^4Y35/!E[W&?QF$q&p.\.TN#ap\l\C_0-^LK)X@*dd8$8&(2:12H:+:I
	!+JdG7^N1eh3!k,7WsB]ef8Xso?&?)/d?2nra9M94n+AY,q5,Y!UsSq8_]-N^%*c-1pq3R<H?0Gl^B
	)j;mXKkT&NZ>CVq)[:.!n^Yh]I+:Z+\8I*Y;7R2=,$uG$[UBmn;AO4JEP`,o9F(o(Zn*,SWZ[H:*0h
	,:+<jidJcVMZ-UQo\&0V=8f-;,"2QTi.LejX,oDS,B0fqIDgMOD[mu=TPlC@>;Hi8DCF`k+JDL^iS5
	C`I[5!QSr0$X@eEc:IQcRcj1C,S4=GO4p2qfXWJZ:m8W7Nc[h-s4@o&<VsgJ(6AIS9Q4\mmHTqRaLU
	FPiL1.O__mbDBQ<d!3"d(MiK#+RrMtk$8e[aW)lh2O5?V7&Xb@@*juWhk^=UJYS4rLG+p[@&es=*dR
	jm\jWB;1LuOU!Ka4"qelqk_")e5C!2FC`<-\#Z^N&+[lpDl/qsM(KB^d(Yg=k9?daI^W;O1lDP$_L?
	jcu0mm='9]<1GqE5Buup2tn+MkNn*s^@[+:P!JL:K<h;mL=^b=G'g@?l/[+B60e-spr%EX2*TTm>AK
	+jXMut%\E_g7<LIMGr^5=GM7m9'J+`AphTlCCd;c0WlDE.<:l#>V?UuT`P?(rZ-rtbk`YOZDJ=b7j"
	XmE"I4Y!:TO7p;9GD?Zi']\,'FHU+1,:9t942EMVRY4%&!G(0e]e)&7u<c1F77o#K*T!DY-j)fAQb7
	/.3]pgU+B<,V!7gJe[<aAA"2%,=CNNkXEA\M[mZO@VT,%.G\-lp0>DmCrp%A[&dI$5@lR32M91VQqt
	D*oH?=%B/d-_<1L])L+<:p2DiFMl<+qK1;m_/e:k]$P5uM34dBA1[Wl0.78cSu*"K+Eha5nm-bQ(?[
	,,@UR`Y-e_Tigtc6G0JUN!@4.9;]^3dj0'73?t;Bn5+bN,N#^[Y/"#;eGtIR&cpQ1ETigYM3uC&6e5
	)&QAWdOqu,?[cbFppa0M91hGG1;:u.q*/$$u[pVZU#:9#hBG3lm)T"AWIVAkLa#hj!r/M&MZ\od34k
	F[7s[9%9,HKusHs$XP,'@e5A0ZPT8M#>1fn;W$CBK9sL%']/h:dp@d-WLjP_e<,p>einNN;udd@UDZ
	UYme/E?q\TYRi8UV.)]n?,!fK^pqGD)2eGr_U=V3\AZR,'LY3M)9glBmc%g9#baDM4jaF)Zlf7$c`n
	GYpVLSd5<-,ok>'aQ*Ro@?K`5h9P)7c<e*Uc[fSNV,\WFqi/>$]pmDt!Xspr(D^%Q,/a,Y_deN=D4c
	\\,:imbG@NT76(DM:\q;]lNJl6Sm3?CeTp?#.pjbBB.(i88(MMX,=219HjN^Y[N&]F^8W1aFHOU.[K
	Fc7=[.h:-h."MH-9%HO4G%<81jIXb7@"'.6q>847k<b)XeL^$f`L^8UKkOue4DC5ILu3r$@M[Xeca;
	cAErIf;)73To+ep0,)AF)DHiZUe*0F*"H(2/bh=XbeLH>Agb*;^t/&Aa/HC-_L=[-Um],%m><la6jg
	\[6i9UEclh[r^sZO!AH5l0f?@KkK]V[VET%]k*pkij:@7m5Q8S7hg=k/:[[&F7gE`l!:l>PE'p:P<!
	."h"-?Dg=bDSSOI1,8:n^]__hJ<Zi!#:L5f"!4)_0EdJ'e@s:"mV4e>B<5bFWp':p0jm8iAJ>_^*]6
	D'J4N/R2*J926jO3bC&SCkF4LFe^FeCkXj_dlXF`W$huQbU,mEFP7Dgj311!/T$bclJkH33>c22.RE
	?&?[YOiH"$6BB7;6I55"N>^?=Mu&'QCsSN?cJ1T+!>m.G^&Q4d&1XEF=#,9OP\hL5:qJ+g4@Ri%dmc
	K!f-m^Ztk*IDI?E[(9dN#BpM@5BC`r`7GGc'rYM`J`V6?X*kN:^.6)5eX,R5(3<VpY>L,ciO2K)Bh\
	sON2?Ae12($<Wh_sR)f@r!5(WM.6su;(]);rMT/?<gm'<cJ#1@*S^/ShPo+[TlYV:>dqPpq-hc-G=,
	LJ;(MfTN,rHaJ:/NII%8]!ZUSaoc)N@4Xk99WaRC$-L@kGhY/cZH6WS(sJ%jJ^n:(eL<(P9,1qWp#a
	Fo/jJ5Q($,+1p,bs288,q93p+"lHrjp=g,6FD-!@%"O%cKemAe]^Yjh='pC;dm*lsqsO@VrV,4,ch$
	USpH(%BGl3a9IZfQc80*5@k0>lll\tOQhg>!lp'[MgaG9cB`ugZh+&>0KFK+#Ame@aYI,Xm&^@Cc,m
	f(1t!\I*c6noQWnU^)=YG%o]3&ZFdohbblW@BXq(VL%&VepKf.\^_Ao4#rH8Eu^%NNFo@^(B04AQrC
	mG<:uMcE'$mWG9!+bI0?$64A`kb$iq<4"AbFoc6,;bg0WkdnCHc@q1^dP>'KnFt6^o=r8n%.bHb7?k
	?-[J[7USJ,Imn2pZm4UE@55j7``.mlpI?;h+VuSm?\lq:C,^[Td[N2sMlti(W](J+_@D^AcCWoB;t,
	'TlnGN]lmI!uEUqGl-j^k:^("Gi1ha'ZLug7QJ6FaBi5\s79IpCQZpBLO]<EKO#0P06jn?)h_F-`]j
	=r@s:%_llZ9)0E:R;00f:sdDh#%bY6lO,m&]*S8bk.L1F+Gm3!Rk:fUDt_C^&tX)1aU=/LZ$Z[')$3
	2Q-I[BUaO8Q_`e:kTtI`M.FakV"ss'74K=l"mbli7-kON>WHW#.?:.f;YDM_q](:cFeROn(tb&f!o-
	@SQf<(Pn:<c/1NMUZLjq$.NjI:-pnWkW?7aGea(89*A`O8rhCPuqu$%UDa*a5,JQ7PCY"9f?L:m2K*
	X22keeM=\QsRErpuKVkZ`Q1kB"7Yh/`.RO55$;flLf`3:Zk%4aSFW$poEt;;jR1rQ^Uf0CjgHo?VlF
	nYZls%4DH;ph%=N!g)BMs7JVPeURI]Dg_HWqa;BEN+<2?OrBNm!:&O$TVH:d!MF`G!=B:Q6EV!;B^X
	*#dCE/@X23;"qW;DDZmt?5@:$.3)k3h'@qPOY04/`kKBn_8D'J3rQG2h:)CoN\OM2CmL>).8-5.'QA
	Pnb)a[FF$!6/2>M=,;$^+M;QUq*6EE8PHO;;`rTb@d0elp&(*pYMIsG42CXT4s6Yr9A4uHIeNi>O/K
	#qk]X&YMV!=]3"WplP@3@TD@I_Ik,;.5PDe*lBUI^K*V,mfQZHBr6j"n&4AhjJV]7>0nMGQK'S8:D0
	>6f$W$cIDuUI1bDIq`GqdqT?P358n,2kqBFk.=p\s_HTcL`5bZ)-#U7afJO/V=Tdni@BW$m876_-Qc
	PnLa^3i+DASFj"21,NuLK2Zq^n>1r>0-pbo?G't@b1=#pe7#;f=9anhAPGMNiOr4,ks8!R1DPZ)/'p
	+I!:o!Mf3PC30f-e`3-leV&u>R;&k(#P]I8_CDngq+H1S/IQBkQ9I+Lk-Xmo/XpBt>SknUAjOum"Tl
	'K-50=j<UBCCC5DSPf&jiaPtT5HJ(#PT<\V-@&(+GTVSKWlbJY:nV-?M`WY5B>qsI7!JV(1EQg-fV`
	qI/OHIh02:@]N;I[bZ-r@pfIA.292BDCbQe17k_l_eE6n1FPMHs?h,\8:)K17#U1E]XAto;.]O+<GR
	7-oAn('q4j(2lQ>PG+&5!hED@<+"'Pj]UBWmc/+`"27ehD`t4,8CO*hDu0/=lN$Ub#/=p"oFh?";?_
	RH\$a]_V9#@-R1.UV5+M9Bhe:oTU0+TDO'\L"!n1^Bf*&qRJ\.oE\FQ5'*UQlV1/NK;d8dH5EUl63o
	k9<oIA/['*d6l]9o9>OZ90b(C-FNN[a%Y2*cFGE6p<8?*e'W$X_-Ma\%!hU-XV?m%@LOSl2D"=\WtK
	QJE#!:c-N&VsE,)P@*DTV<&UD&NDW(P8j'el_WGKcmWd2.9Fj;1bmW=.-VNlWq5H.F#.f]q/e<*;V&
	`]lRafAm%`Y.W5pdG.Z>$2T`Q/hSREEF1fI`eggea!7J^r1FSRW7I`bOid<pM3E<7oCFdS>Og?d%7^
	Ke:k(<mMI#,s^]<uffd'dM&HH0%&b-cL+gI1Wq&p[8dFlZ)G6p&e1J.`f16fKRc'W_R:)-007mfEc2
	-odKbA7G7@cp9.T;?\b00kR=A@j6^FXcao*;;JrofFH_Z,'(u<g[0<h^9k6a_Gq.A:/"DX:(hWTa^_
	WZ/;k&X!1;Gd*t-;\XY6M!MR"cujF[%$5s/0/g*B:P@9nl0JioRt.RArtTBE`m?3'GBn33ujAi=6g=
	j_@^)`XX<*GE2,.O979N#)A9M\];Q#ltrs?=XV[C8hcK+gUE*m6Om6dVrZ*nrQ-GNAcHKj=^]=Kn_;
	`Jqg:U70Z<r<Chp]A#L3<UV3',UIf4mqRtFEeRl.%N&?>^=0As_lLd2t1m*m_KrTIfLc?:rBpu'NmT
	RXV<6o;PX"-Wr=f?Qp7>NBJ+K0ml>`SZdO^b`37R1^*;<6"+&[KudW^mlOh&N]1hIs%D*n#$RJGY1&
	k[TLeiqktKOG'8-6kl]&KeroiVQ)e\mNWb;L$Aml)8JVPOC9o0$D@'6(c4E"%%]g/!?2KNWa?ZF\A[
	VR<)7@s[2V`uQC!s/4Km:M!($qkOsHl4n?,[)VUqjgGOI\N#fL93d910Vl!%XlET,?bq(`IL586l`1
	A"5]$cu&`MpT^s^XP#8mbEMSQ\-s3>:gFi>$MO]NNo`2_0Zt3N:5!a?=1&K)S:B.T;),pGlZdFb!C4
	KhTuc+,PX$m<oM#t*/t1Xd6UnriiX,QOt'ou$:Vj!8jHlc8ji#H.`Gcn$\Kpr:t^LOn3m<gdnuf<n@
	IF:(rFNgLF6bLEOg2QjQ)OrLr$^6\_/OW7eL,IiAanrW/*Fr7&;op/6su[l&m]WSNCFWTJNLloXhec
	?KAZ_Q(_96Ss.s'=+kHtXED+"?F7?#PG_1//=i/ukk2LpM[N?uN/dY]Q_g`<\C`(LXu"daA,Cat49r
	m`%2E2s^1[>bHU5:#@N?C*#*ap'+d5dqFD.n.+fb.mHETYq2U5m\TJg?mq7]6)T^j5"mf:;p-n\g5T
	a3>+$&_@D!e;le`mhmS=:59AN/cAQ2QJu_i:-0J]DDJTOsDqW<``@F@(.pJ1&(PCZ?.4P&=D,U)Jb<
	YFo1n.;`>fS5?VdiT:*B3mel>6PC!f]m?\_XlI<+2727!Q`5$_Qdq@N>>ZeLMpWc6FXP<,IRQmFqP$
	2$B>mT:#ESObbUF"dK)stl`qu?<,G<bom0CR#s6<Li(&*Dt\4n6Z6#PHGj5W]g#<JX^c,W3#u&[.;s
	^).Vu='!g4AY;UDPSBXfW(G(]&5)JHZh6^4AePH)edH"[<T3g]786Bj+[Isk0o-&j+)Q^o>"EJ`HX2
	p`&_H>kB$P-K@eS*dSOOG!e;1'\mu'_YS:'h_]<#$Ph_F!PGL*pM`d>1En,Ci-O'd8$jI:(LjBB""m
	$,1@T<Ci6Ja]UWT6fh,?iTXhN>g]%jH0,tgLnj@472RhGa`4V9F0V2S"6_j=q,LbqOp.MY:En+6+>`
	QhSX:2iKpaFb7dC+*.AuC#??Oe9<l((;YI-<.]f?PK@un0@82L/!iiCF!8,MWJaWfpF[V*(PObt6/e
	A04d!)2Q`(4>sTb(4cTlhgb(f5BcNV)]NAflCtQHTb;,%>&`9ka%5$5'8[]d5Z,@T#lf8ls7(fr^"c
	5'sH!kKVT1JUP/`'dm@<mGs+jMTuqU<bp3aTl'a#BBe492dSOfie8<FD`t`l9k\NdiS:tb`b)Pu4'h
	*@.u3/COh.#Vm<YJ^2mG=-bl$<>Af&X?TkM.2KBC(dr4W,pX]u3W9HS^JBWDJT+@Z_CIhJOI+DA!!L
	"7RD^j8h=RMm>1PH(.7XYI(Q&U`1R"<q8TL(^K\i$/a<[a&\4:4j?lQur+TOeJ%$EkEj(0KV?869'2
	Wm&o/ceYZUp.\8W*+U$uaChm'>64d`@;'m\gX^7LR3P07pnsaQggqWU1m[_gmPI"mT?T@`4_SoH]ej
	Pf^5go+Eb'qCChMqoKDti[fksg#BnatRSp\XdQgofdAe%%XU.EB6^YU!`ej7,1)]jo*"VjGa.]Dm-8
	_-?s(4niO"B?rL*H69V'=uc06F6*p=5LWdTs3UPWpORKI[5MS?GUGCZ6ieDTIA2=$E3*g+dBY.(,u.
	G\HkC10CrTus$;hmm2iskeCJYlM`e%-t$&Ouc@:W#IBWtKK8@K&g\Ub)XNum+;\+@"/?X$dJR\U7W#
	q4!F3EHn`YLi+'rDp6^2*"[5rWE4QW'Z+"Sm?\h/+(<P74981GLPV`A%ZqtC$"X1KnXpAEXlPF@X,P
	J9MOp00ft\'mWR@JcCJ0C?5[NRbj:]'_*Jcio"7L+910sJ]!^J0^1d6uGOP+/VdDO]lt^7)/_/WETs
	XgC=Pg\J\TMM&l[>NS5RFi!g0#mm&ULV6+/oSV3[f"O#]*p#duYk#*i#jB=&DD*_:FRMC_@@.''%fJ
	_qK:BA.jc(oRdq`aD;CoES8"R]%oW*aiVXXIdulVorDGj^N-/Xo[>(F@2WZX<Fa7kpr(tCS?Y!@kD5
	GM^hj1$#]f.e9rCdY]"E"83Oa5$r`6)-ZSjs.1[2P&9@&>+A!/Z+Q5k3$h:6RbTC;IDZ0(i<IJ\h^G
	IrSYc\!r!K]o"Eg\s+XhGV,aLd+k4[@CbSRJNo1&kJ-qVE'jKk6nC!X8o6:^l\k4^m8[_&dC.I6'[Y
	9E@=6ZTa[GH>;Cq-<&ta/Lq).N-*![0=^Y0gOsV(q6l6i$)a0!CMrD4Yn%NGl^AVF=k1<panbDbKFI
	K'uOq^@$bgtK)9pmueqf/];72=#L"fW%XM!j$4It%C>>%_F.`:E>%]-gc\[9AkB[P_)e71^n?\%LG*
	g:jqu\4C-W-DkFQB2hb#H\U3R1`,=IA'D_.e'/Vr2\at:LuqYgX4c&!h"<hbb$h5^T``gXBb8nc:kM
	$L:k?_ZS>mct![V;"6cKT<c;g[@P"c?C`6fQ%*<[)]40!"f0=J5&in)njBCDETqhqADo%p9YigboWa
	gj1QF(:/b<n_7!#)4UC:fX!\?u!*<1&Q68rmIX$=)1sY#"`9kf_H(Hqu+7lU/i56NAXn!nY.FYARUu
	MWn"^S4;"]tXcAAudko`15C!@(NCL]kP1)m0ZdSLOo.<<c;`F'@#,3)E-\PI.E'd_32\i&$WdV<13*
	hppN9E=.V;\_Zj?[m!'WT:pI0tmln!IK@!:IM[6XR;ohX>bl%bFW*>/b@s?<-P!BO4*D,rT<OL34PD
	<LjmX%*'\hZa$mW9^K.$\k5Xm\,kf\BIJ`^0Ci=b\TR)j:4[%'!,aKtUQcmYgY$?%8\\P3dlq4M<3o
	-]7V?jGSKGeE$"O:M%JWe+iHQ)FO:lf:3&#_njFaHF_cT\!AgkPTHdZo5*PUe-0Dr\"^AV\og1n"q7
	."4;;nMj"E7Kpe2!+4tGd@.!"U`c[eKPPS<fUq8(_e+P]]egOg@9m3pOt0A[YsO&nBo8:&64W#!,Bc
	SekGXp,LF6E*5Y.0X91AeA5g2u$5;8M0Jk2(+:Q-ldAs8]LdkY`XTYN`FCmF%KoO=o':kk)rfph.T,
	<(CW@-<Keqf,BNg)5e/KOd!iEg,UjZ7oL,9O1>T8rJle=;M\H"K6\jQPbjqmdq1h]`sC6?[F^+je7)
	XaFDS-;<iFX=a(&2(oZM6A0o@5o?CGJDoqKlGTpr.3dbDKiD`?iMg7[EbIcJ6PkPb#+:.640n^-1AW
	R]^S,K]Q;IoYQ55fgf2eF51bc_=>JCqfUYSS4%Q8Nc!lHU<,GR0DAm(GEbg)7!)a8Kj!gkq0;JlKA7
	!._Yp%LAa1^+>Y"CD<#"rf6d5&B<GD/jk0Lmt1]D)`AqAOmDF9'XFKlJ2r0*B<s>l1Qdr>L.0XBLML
	]U/e3df&'L3?p41ebrm.:[#k\qY7Yn_rJjl'gJuG3Nu*amo=_V.k>gLI+<5jgg/QGA1Dr13_sJl)-?
	6]kP+q>9Q8\d`e\9R<0S_*RGOn#3%jp"GA,\_N]uE.*2mncd[9WgL2P9L\YJbFF_(3.8TX=Wcn*A`f
	+[>eoh`[k(Y?W$KDF^df`#\D\]DgOs(YeW?Sq07j2"IC,M"^iL@p<V8SL&":z8OZBBY!QNJ
	ASCII85End
End
