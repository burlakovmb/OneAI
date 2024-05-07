#Region FormHeaderItemsEventHandlers

&AtClient
Async Procedure NeuronetStartChoice(Item, ChoiceData, StandardProcessing)
	OnStartChoice(StandardProcessing);
EndProcedure

&AtClient
Procedure NeuronetOnChange(Item)
	If ValueIsFilled(Object.Neuronet) Then
		CountOfLayers = CommonFunctionalityAIServerCall.GetCountOfLayers(Object.Neuronet);
		If CountOfLayers < 3 Then
			MessageTemplate = NStr("en = 'Your neuronet has only %1 layers. It must be minimum 3. Add a new layer and try again.'");
			MessageText = StrTemplate(MessageTemplate, CountOfLayers);
			Message(MessageText);
			Object.Neuronet = Undefined;
			ClearTabularParts();
		EndIf;
	Else
		ClearTabularParts();
	EndIf;
EndProcedure

&AtClient
Procedure NeuronetClearing(Item, StandardProcessing)
	OnClearing(StandardProcessing);
EndProcedure

&AtClient
Procedure DataSetOnChange(Item)
	ClearTabularParts();
	
	If ValueIsFilled(Object.DataSet) Then
		LoadTabularPartsFromDataSet();
	EndIf;
EndProcedure

&AtClient
Procedure DataSetClearing(Item, StandardProcessing)
	OnClearing(StandardProcessing);
EndProcedure

&AtClient
Procedure DataSetStartChoice(Item, ChoiceData, StandardProcessing)
	OnStartChoice(StandardProcessing);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ClearTabularParts()
	Object.DataSets.Clear();
	Object.InputNeurons.Clear();
	Object.Result.Clear();
EndProcedure

&AtServer
Procedure LoadTabularPartsFromDataSet()
	Object.DataSets.Load(Object.DataSet.DataSets.Unload());
	Object.InputNeurons.Load(Object.DataSet.InputNeurons.Unload());
	Object.Result.Load(Object.DataSet.Result.Unload());
EndProcedure

&AtClient
Procedure OnClearing(StandardProcessing)
	If Object.DataSets.Count() > 1 Then
		Answer = DoQueryBoxAsync(NStr("en = 'Tabular parts will be cleared. Continue?'"), QuestionDialogMode.YesNo);
		If Answer = DialogReturnCode.No Then
			StandardProcessing = False;
		Else
			ClearTabularParts();
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure OnStartChoice(StandardProcessing)
	If Object.DataSets.Count() > 0 Then
		Answer = DoQueryBoxAsync(NStr("en = 'Tabular parts will be cleared. Continue?'"), QuestionDialogMode.YesNo);
		If Answer = DialogReturnCode.No Then
			StandardProcessing = False;
		Else
			ClearTabularParts();
		EndIf;
	EndIf;
EndProcedure

#EndRegion