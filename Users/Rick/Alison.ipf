#pragma rtGlobals=1		// Use modern global access method.

Macro Alison()
•Label summary_left "\\Z14Width (ms)"
•ModifyGraph axisEnab(summary_bottom)={0.08,0.99}
•ModifyGraph axisEnab(summary_bottom)={0.12,0.99}
•ModifyGraph lblPos(summary_left)=45
•Label summary_left "\\Z14width (ms)"
•ShowTools/A
•SetDrawEnv textrgb= (0,0,0)
•HideTools/A
•ModifyGraph fSize(summary_bottom)=10
•ModifyGraph fSize(summary_bottom)=14
•ModifyGraph axisEnab(summary_left)={0.1,1}
•ModifyGraph freePos(summary_bottom)={0.1,kwFraction}
•ModifyGraph fSize(summary_left)=12
•ModifyGraph nticks(summary_left)=3
•ModifyGraph fSize(summary_bottom)=0
•SetAxis summary_left 2.0744,4.95 
•ModifyGraph nticks(summary_left)=4
•Layout/T bar_Width,scatter_Width
•ModifyLayout frame(bar_Width)=0
•ModifyLayout frame=0
•Label scatter_left ""
•ModifyGraph axisEnab(summary_bottom)={0.2,0.99}
•SetAxis scatter_left 2.0744,4.7 
•SetAxis summary_left 2.0744,4.7 
•ModifyGraph fSize(scatter_left)=12
•Edit  root:ConditionList95
•ShowTools/A
•HideTools/A
•ModifyGraph freePos(scatter_bottom)={0.1,kwFraction}
•ModifyGraph axisEnab(scatter_left)={0.1,1}
•ModifyGraph fSize(summary_left)=10
•ModifyGraph fSize(scatter_left)=10
•Edit  root:ConditionList94
•ShowTools/A
•SetDrawEnv linefgc= (65535,65535,65535)
•HideTools/A
•ShowTools/A
•Label summary_left "\\Z12width (ms)"
•Label summary_left "\\Z12\\f01width (ms)"
•ModifyGraph fSize(summary_bottom)=8
•HideTools/A
•ShowTools/A
•HideTools/A
•ModifyGraph fSize(scatter_bottom)=8
•ShowTools/A
•SetDrawEnv fsize= 8
•HideTools/A
•ModifyGraph fStyle(summary_bottom)=1
•ModifyGraph fStyle=0
•ShowTools/A
•SetDrawEnv linefgc= (65535,65535,65535)
•HideTools/A
•ModifyGraph fSize(summary_left)=9;DelayUpdate
•Label summary_left "\\Z11\\f01width (ms)"
•ModifyGraph fSize(scatter_left)=9
•TextBox/C/N=text0/F=0/A=LB/X=26.04/Y=80.90 "A"
•TextBox/C/N=text0 "\\Z16A"
•TextBox/C/N=text0 "\\Z16A\\B1"
•TextBox/C/N=text1 "\\Z16A\\B2"
End