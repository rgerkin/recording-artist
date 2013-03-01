#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName = Camera

#if exists("SIDXOpen")==4 // If the SIDX XOP is installed.    
#define SIDX6
#include "SIDX6 Wrappers"
#endif

static function /s GetCameras()
	return "default"
end

static function /s CameraType(camera)
	string camera
	return "SIDX6"
end

function Open_(xop_handle)
	variable &xop_handle

	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref Open_ f = $funcName
			variable status=f(xop_handle)
		endif 
	endfor
	return status
end

function GetStatusText(xop_handle,message)
	variable xop_handle
	string &message
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref GetStatusText f = $funcName
			variable status=f(xop_handle,message)
		endif 
	endfor
	return status
end

function DialogSelector(xop_handle,camera_handle,cancelled)
	variable xop_handle,&camera_handle,&cancelled

	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref DialogSelector f = $funcName
			variable status=f(xop_handle,camera_handle,cancelled)
		endif 
	endfor
	return status
end

function Dialog(camera_handle,cancelled)
	variable camera_handle,&cancelled
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref Dialog f = $funcName
			variable status=f(camera_handle,cancelled)
		endif 
	endfor
	return status
end

function GetCameraStatusText(camera_handle,message)
	variable camera_handle,&message
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref GetCameraStatusText f = $funcName
			variable status=f(camera_handle,message)
		endif 
	endfor
	return status
end

//////////////////////////////////////
// This basically just closes the camera and xop, but also kills the data folder w/ the handles.
// This is useful for keeping track of whether a global for the camera handle exists.
//////////////////////////////////////
Function Deallocate([cameras])
	string cameras
	
	cameras=selectstring(!paramisdefault(cameras),GetCameras(),cameras) 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)
		string type=CameraType(camera)
		if(strlen(type))
			dfref df = CameraHome(instance=camera)
			if(datafolderrefstatus(df))
				nvar /sdfr=df camera_handle, xop_handle
				CameraClose(camera_handle)
				Close_(xop_handle)
				camera_handle=0
				xop_handle=0
			endif
		endif
	endfor	
End

function CameraClose(camera_handle)
	variable camera_handle
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref CameraClose f = $funcName
			variable status=f(camera_handle)
		endif 
	endfor
	return status
End

function Close_(xop_handle)
	variable xop_handle
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref Close_ f = $funcName
			variable status=f(xop_handle)
		endif 
	endfor
	return status
end

function ExposureTimeSet(camera_handle,exposure_time)
	variable camera_handle,exposure_time
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref ExposureTimeSet f = $funcName
			variable status=f(camera_handle,exposure_time)
		endif 
	endfor
	return status
end

function BinningSet(camera_handle,X_pixels,Y_pixels)
	variable camera_handle,X_pixels,Y_pixels
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref BinningSet f = $funcName
			variable status=f(camera_handle,X_pixels,Y_pixels)
		endif 
	endfor
	return status
end

function TriggerSet(camera_handle,trigger)
	variable camera_handle,trigger
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref TriggerSet f = $funcName
			variable status=f(camera_handle,trigger)
		endif 
	endfor
	return status
end

function AcquisitionBeginFocus(camera_handle)
	variable camera_handle
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref AcquisitionBeginFocus f = $funcName
			variable status=f(camera_handle)
		endif 
	endfor
	return status
end

function AcquisitionBeginSequence(camera_handle,num_frames)
	variable camera_handle, num_frames
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref AcquisitionBeginSequence f = $funcName
			variable status=f(camera_handle,num_frames)
		endif 
	endfor
	return status
end


function AcquisitionStart(camera_handle)
	variable camera_handle

	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref AcquisitionStart f = $funcName
			variable status=f(camera_handle)
		endif 
	endfor
	return status
end

function AcquisitionFramesAvailable(camera_handle,available_frames)
	variable camera_handle,&available_frames
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref AcquisitionFramesAvailable f = $funcName
			variable status=f(camera_handle,available_frames)
		endif 
	endfor
	return status
end

function AcquisitionGetFrames(camera_handle,num_frames,roi_index,w,utc_time)
	variable camera_handle,num_frames,roi_index,&utc_time
	wave w
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref AcquisitionGetFrames f = $funcName
			variable status=f(camera_handle,num_frames,roi_index,w,utc_time)
		endif 
	endfor
	return status
end

function AcquisitionStop(camera_handle)
	variable camera_handle
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref AcquisitionStop f = $funcName
			variable status=f(camera_handle)
		endif 
	endfor
	return status
end

function AcquisitionGetSize(camera_handle,var,bytes,x_pixels,y_pixels)
	variable camera_handle,var,&bytes,&x_pixels,&y_pixels
	
	//var = 0
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref AcquisitionGetSize f = $funcName
			variable status=f(camera_handle,var,bytes,x_pixels,y_pixels)
		endif 
	endfor
	return status
end

function TemperatureGet(camera_handle,temperature,locked,hardware_provided)
	variable camera_handle, &temperature, &locked, &hardware_provided
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref TemperatureGet f = $funcName
			variable status=f(camera_handle,temperature,locked,hardware_provided)
		endif 
	endfor
	return status
end

function AcquisitionEnd(camera_handle)
	variable camera_handle
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref AcquisitionEnd f = $funcName
			variable status=f(camera_handle)
		endif 
	endfor
	return status
end

function ROIClear(camera_handle)
	variable camera_handle
	
	string cameras=GetCameras() 
	variable i
	for(i=0;i<ItemsInList(cameras);i+=1)
		string camera=stringfromlist(i,cameras)	
		string type=CameraType(camera)
		string funcName=type+"#"+GetRTStackInfo(1)
		if(exists(funcName)==6 && strlen(type))
			funcref ROIClear f = $funcName
			variable status=f(camera_handle)
		endif 
	endfor
	return status
end