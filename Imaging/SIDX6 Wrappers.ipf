#pragma rtGlobals=1		// Use modern global access method.
#pragma ModuleName = SIDX6

static function Open_(xop_handle)
	variable &xop_handle

	variable status
	SIDXOpen xop_handle,status
	return status
end

static function GetStatusText(xop_handle,message)
	variable xop_handle
	string &message
	
	variable status
	SIDXGetStatusText xop_handle,status,message
	return status
end

static function DialogSelector(xop_handle,camera_handle,cancelled)
	variable xop_handle,&camera_handle,&cancelled

	variable status
	SIDXDialogCameraSelector xop_handle,cancelled,camera_handle,status
	return status
end

static function Dialog(camera_handle,cancelled)
	variable camera_handle,&cancelled
	
	variable status
	SIDXDialogCamera camera_handle,cancelled,status
	return status
end

static function GetCameraStatusText(camera_handle,message)
	variable camera_handle,&message
	
	variable status
	SIDXCameraGetStatusText camera_handle,status,message
	return status
end

static function CameraClose(camera_handle)
	variable camera_handle
	
	SIDXCameraClose camera_handle
End

static function Close_(xop_handle)
	variable xop_handle
	
	SIDXClose xop_handle
end

static function ExposureTimeSet(camera_handle,exposure_time)
	variable camera_handle,exposure_time
	
	variable status
	exposure_time/=1000 // Convert from ms to s.  
	SIDXExposureTimeSet camera_handle,exposure_time,status
	return status
end

static function BinningSet(camera_handle,X_pixels,Y_pixels)
	variable camera_handle,X_pixels,Y_pixels
	
	variable status
	SIDXBinningSet camera_handle,X_pixels,Y_pixels,status		
	return status
end

static function TriggerSet(camera_handle,trigger)
	variable camera_handle,trigger
	
	// Trigger = 1 for no trigger.  Trigger = 3 for triggering.  
	variable available,status
	SIDXTriggerModeAvailable camera_handle, trigger, available, status
	if(available == 0)
		trigger = 1 - trigger // Switch from trigger mode 0 to 1 or 1 to 0 if the provided settings is unavailable.  
		printf "Switching to trigger mode %d.\r",trigger
	endif
	SIDXTriggerSet camera_handle,trigger,status
	return status
end

static function AcquisitionBeginFocus(camera_handle)
	variable camera_handle
	
	variable status
	SIDXAcquisitionBeginFocus camera_handle, status // Prepare the camera for focus mode
	return status
end

static function AcquisitionBeginSequence(camera_handle,num_frames)
	variable camera_handle,num_frames
	
	variable status
	SIDXAcquisitionBeginSequence camera_handle, num_frames, status // Prepare the camera for focus mode
	return status
end

static function AcquisitionStart(camera_handle)
	variable camera_handle

	variable status
	SIDXAcquisitionStart camera_handle, status // Start the actual acquisition. 
	return status
end

static function AcquisitionFramesAvailable(camera_handle,available_frames)
	variable camera_handle,&available_frames
	
	variable status
	SIDXAcquisitionFramesAvailable camera_handle, available_frames, status 
	return status
end

static function AcquisitionGetFrames(camera_handle,num_frames,roi_index,w,utc_time)
	variable camera_handle,num_frames,roi_index,&utc_time
	wave w
	
	variable status
	string dest=getwavesdatafolder(w,2) // This seems stupid but is required to make the operation work.  
	SIDXAcquisitionGetFrames camera_handle, num_frames, roi_index, $dest, utc_time, status // ...Write input to a single IGOR wave	
	redimension /n=(-1,-1,max(1,dimsize(w,2))) w // Force to have at least 1 layer (frame).  
	return status
end

static function AcquisitionStop(camera_handle)
	variable camera_handle
	
	variable status
	SIDXAcquisitionStop camera_handle	
	return status
end

static function AcquisitionGetSize(camera_handle,var,bytes,x_pixels,y_pixels)
	variable camera_handle,var,&bytes,&x_pixels,&y_pixels
	
	//var = 0
	variable status
	SIDXAcquisitionGetSize camera_handle, var, bytes, x_pixels, y_pixels, status
	return status
end

static function TemperatureGet(camera_handle,temperature,locked,hardware_provided)
	variable camera_handle, &temperature, &locked, &hardware_provided
	
	variable status
	SIDXTemperatureGet camera_handle, temperature, locked, hardware_provided, status
	return status
end

static function AcquisitionEnd(camera_handle)
	variable camera_handle
	
	SIDXAcquisitionEnd camera_handle
end

static function ROIClear(camera_handle)
	variable camera_handle
	
	variable status
	SIDXROIClear camera_handle,status
	return status
end