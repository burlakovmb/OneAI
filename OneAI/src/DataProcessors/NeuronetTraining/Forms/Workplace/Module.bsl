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

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Run(Command)
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	For Step = 1 To Object.StepsQty Do
		For Each DataSet In Object.DataSets Do
			InputNeurons = New Array;
			Filter = New Structure("Active", 1);
			Filter.Insert("Key", DataSet.Key);
			For Each InputNeuron In Object.InputNeurons.FindRows(Filter) Do
				InputNeurons.Add(InputNeuron.Neuron);
			EndDo;
		
			Filter = New Structure("Key", DataSet.Key);
			For Each ResultNeuron In Object.Result.FindRows(Filter) Do
				If ResultNeuron = 0 Then
					Continue;
				EndIf;
				
				ExperienceWeight = ResultNeuron.Value * Object.Speed;
				CommonFunctionalityAIServerCall.ChangeExperience(Object.Neuronet, ResultNeuron.Neuron, InputNeurons, ExperienceWeight);
			EndDo;
		EndDo;
	EndDo;
	
	MessageText = NStr("en = 'Training was completed!'");
	Message(MessageText);
EndProcedure

&AtClient
Async Procedure DeleteAnExistingExperience(Command)
	QuestionText = NStr("en = 'Do you want to delete an existing experience of neuronet?'");
	Answer = Await DoQueryBoxAsync(QuestionText, QuestionDialogMode.YesNo);
	If Answer = DialogReturnCode.Yes Then
		DeleteAnExistingExperienceAtServer();
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

&AtServer
Procedure DeleteAnExistingExperienceAtServer()
	Errors = False;
	Neurons = CommonFunctionalityAI.GetNeurons(Object.Neuronet);
	While Neurons.Next() Do
		NeuronObject = Neurons.Neuron.GetObject();
		For Each Link In NeuronObject.InputLinks Do
			If Link.IsConstant Then
				Continue;
			EndIf;
			
			Link.Weight = 0;
		EndDo;
		
		Try
			NeuronObject.Write();
		Except
			Errors = True;
			Message(ErrorDescription());
		EndTry;
	EndDo;
	
	If Errors Then
		MessageText = NStr("en = 'You have some errors. Try again later.'");
	Else
		MessageText = NStr("en = 'An existing experience was deleted successfully.'");
	EndIf;
	
	Message(MessageText);
EndProcedure

#EndRegion