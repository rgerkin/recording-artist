#pragma rtGlobals=1		// Use modern global access method.
#pragma IndependentModule=TFToolkit

Menu "Analysis",hideable
	Submenu "Packages"
		"Time-Frequency Decomposition",/Q,Execute/P/Q/Z "INSERTINCLUDE \"Time-Frequency\"";Execute/P/Q/Z "COMPILEPROCEDURES ";Execute/P/Q/Z "TimeFrequencyInvestigation()"
	end
end
