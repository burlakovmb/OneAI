#Region Public

Function GetCountOfLayers(Neuronet) Export
	Return CommonFunctionalityAI.GetCountOfLayers(Neuronet);
EndFunction

Procedure ChangeExperience(Neuronet, OutputNeuron, InputNeurons) Export
	CommonFunctionalityAI.ChangeExperience(Neuronet, OutputNeuron, InputNeurons);
EndProcedure

#EndRegion