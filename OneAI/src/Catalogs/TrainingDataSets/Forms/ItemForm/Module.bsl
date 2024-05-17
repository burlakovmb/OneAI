#Region FormHeaderItemsEventHandlers

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
Async Procedure NeuronetClearing(Item, StandardProcessing)
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
Async Procedure NeuronetStartChoice(Item, ChoiceData, StandardProcessing)
	If ValueIsFilled(Object.Neuronet) Then
		Answer = DoQueryBoxAsync(NStr("en = 'Tabular parts will be cleared. Continue?'"), QuestionDialogMode.YesNo);
		If Answer = DialogReturnCode.No Then
			StandardProcessing = False;
		Else
			ClearTabularParts();
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersDataSets

&AtClient
Procedure DataSetsOnActivateRow(Item)
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	WorkWithTabularPartsClient.SetFilterByKey(Items.InputNeurons, CurrentData.Key);
	WorkWithTabularPartsClient.SetFilterByKey(Items.Result, CurrentData.Key);
EndProcedure

&AtClient
Async Procedure DataSetsBeforeDeleteRow(Item, Cancel)
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure("Key", CurrentData.Key);	
	RowsArray = Object.InputNeurons.FindRows(Filter);
	If RowsArray.Count() > 0 Then
		Answer = DoQueryBoxAsync(NStr("en = 'Data of this data set will be deleted. Continue?'"), QuestionDialogMode.YesNo);
		If Answer = DialogReturnCode.No Then
			Cancel = True;
		Else
			WorkWithTabularPartsClient.DeleteRowsByKey(Object.InputNeurons, CurrentData.Key);
			WorkWithTabularPartsClient.DeleteRowsByKey(Object.Result, CurrentData.Key);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure DataSetsOnEditEnd(Item, NewRow, CancelEdit)
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If NewRow Then
		CurrentData.Key = New UUID();
		FillNeuronsAtServer(CurrentData.Key);
	EndIf;
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
Procedure FillInputNeuronsAtServer(Key)
	Neurons = CommonFunctionalityAI.GetInputNeurons(Object.Neuronet);
	While Neurons.Next() Do
		NeuronRow = Object.InputNeurons.Add();
		NeuronRow.Neuron = Neurons.Neuron;
		NeuronRow.Key = Key;
	EndDo;
EndProcedure

&AtServer
Procedure FillNeuronsAtServer(Key)
	FillInputNeuronsAtServer(Key);
	FillOutputNeuronsAtServer(Key)
EndProcedure

&AtServer
Procedure FillOutputNeuronsAtServer(Key)
	Neurons = CommonFunctionalityAI.GetOutputNeurons(Object.Neuronet);
	While Neurons.Next() Do
		NeuronRow = Object.Result.Add();
		NeuronRow.Neuron = Neurons.Neuron;
		NeuronRow.Key = Key;
	EndDo;
EndProcedure

#EndRegion