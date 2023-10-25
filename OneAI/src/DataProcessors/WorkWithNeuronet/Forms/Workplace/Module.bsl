#Region FormHeaderItemsEventHandlers

&AtClient
Procedure NeuronetOnChange(Item)
	Object.InputNeurons.Clear();
	If ValueIsFilled(Object.Neuronet) Then
		FillInputNeurons();
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersResult

&AtClient
Async Procedure ResultSelection(Item, RowSelected, Field, StandardProcessing)
	QuestionText = NStr("en = 'Do you want to change existing experience of neuronet?'");
	Answer = Await DoQueryBoxAsync(QuestionText, QuestionDialogMode.YesNo);
	If Answer = DialogReturnCode.Yes Then
		ChangeExperienceAtServer(Object.Neuronet, Item.CurrentData.Neuron);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure GetResult(Command)
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	CountOfLayers = GetCountOfLayers(Object.Neuronet);
	If CountOfLayers < 3 Then
		MessageTemplate = NStr("en = 'Your neuronet has only %1 layers. It must be minimum 3. Add a new layer and try again.'");
		MessageText = StrTemplate(MessageTemplate, CountOfLayers);
		Message(MessageText);
		Return;
	EndIf;
	
	GetResultAtServer();
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function GetCountOfLayers(Neuronet)
	Count = 0;
	
	Layers = Catalogs.Layers.Select(, Neuronet);
	While Layers.Next() Do
		Count = Count + 1;
	EndDo;
	
	Return Count;
EndFunction

&AtServer
Function GetInputNeurons()
	Query = New Query;
	Query.Text =
		"SELECT
		|	NeuronsInputLinks.Ref
		|INTO NotInputNeurons
		|FROM
		|	Catalog.Neurons.InputLinks AS NeuronsInputLinks
		|WHERE
		|	NeuronsInputLinks.Layer.Owner = &Neuronet
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Neurons.Ref
		|INTO NeuronsByNet
		|FROM
		|	Catalog.Neurons AS Neurons
		|WHERE
		|	Neurons.Owner.Owner = &Neuronet
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	NeuronsByNet.Ref AS Neuron,
		|	CASE
		|		WHEN NotInputNeurons.Ref IS NULL
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS IsInputNeuron
		|INTO ResultTable
		|FROM
		|	NeuronsByNet AS NeuronsByNet
		|		LEFT JOIN NotInputNeurons AS NotInputNeurons
		|		ON NeuronsByNet.Ref = NotInputNeurons.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ResultTable.Neuron AS Neuron
		|FROM
		|	ResultTable AS ResultTable
		|WHERE
		|	ResultTable.IsInputNeuron
		|
		|ORDER BY
		|	Neuron
		|AUTOORDER
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP NotInputNeurons
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP NeuronsByNet
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP ResultTable";
	
	Query.SetParameter("Neuronet", Object.Neuronet);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Select();
EndFunction

&AtServer
Procedure FillInputNeurons()
	Neurons = GetInputNeurons();
	While Neurons.Next() Do
		NeuronRow = Object.InputNeurons.Add();
		NeuronRow.Neuron = Neurons.Neuron;
	EndDo;
EndProcedure

&AtServer
Function GetQueryText()
	QueryText = "
		|SELECT
		|	InputLayer.Neuron AS Neuron,
		|	InputLayer.Active AS Active
		|INTO InputLayerData
		|FROM
		|	&InputLayer AS InputLayer
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	NeuronsInputLinks.Ref AS Neuron,
		|	NeuronsInputLinks.Layer AS Layer,
		|	NeuronsInputLinks.Neuron AS InputNeuron,
		|	NeuronsInputLinks.Weight AS Weight
		|INTO Neurons
		|FROM
		|	Catalog.Neurons.InputLinks AS NeuronsInputLinks
		|WHERE
		|	NeuronsInputLinks.Ref.Owner.Owner = &Neuronet
		|;
		|
		|";
	CountOfLayers = GetCountOfLayers(Object.Neuronet);
	If CountOfLayers = 3 Then
		QueryText = QueryText + "
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT DISTINCT
			|	Neurons.Neuron AS Neuron,
			|	SUM(InputLayerData.Active * ISNULL(Neurons.Weight, 0)) AS Result
			|FROM
			|	InputLayerData AS InputLayerData
			|		LEFT JOIN Neurons AS Neurons
			|		ON InputLayerData.Neuron = Neurons.InputNeuron
			|
			|GROUP BY
			|	Neurons.Neuron
			|;"
	Else
		QueryText = QueryText + "
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT DISTINCT
			|	Neurons.Neuron AS Neuron,
			|	SUM(InputLayerData.Active * ISNULL(Neurons.Weight, 0)) AS Result
			|INTO InternalLayerData1
			|FROM
			|	InputLayerData AS InputLayerData
			|		LEFT JOIN Neurons AS Neurons
			|		ON InputLayerData.Neuron = Neurons.InputNeuron
			|
			|GROUP BY
			|	Neurons.Neuron
			|;
			|";
		CountOfInternalLayers = CountOfLayers - 2;
		For CurrentLayerNumber = 2 To CountOfInternalLayers Do
			QueryTextLayerTemplate = "
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT DISTINCT
				|	Neurons.Neuron AS Neuron,
				|	SUM(InternalLayerData%1.Result * ISNULL(Neurons.Weight, 0)) AS Result
				|INTO InternalLayerData%2
				|FROM
				|	InternalLayerData%1 AS InternalLayerData%1
				|		LEFT JOIN Neurons AS Neurons
				|		ON (InternalLayerData%1.Neuron = Neurons.InputNeuron)
				|
				|GROUP BY
				|	Neurons.Neuron
				|;
				|";
			QueryTextLayer = StrTemplate(QueryTextLayerTemplate, CurrentLayerNumber - 1, CurrentLayerNumber);
			QueryText = QueryText + QueryTextLayer;	
		EndDo;
		QueryTextLayerTemplate = "
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT DISTINCT
			|	Neurons.Neuron AS Neuron,
			|	SUM(InternalLayerData%1.Result * ISNULL(Neurons.Weight, 0)) AS Value
			|FROM
			|	InternalLayerData%1 AS InternalLayerData%1
			|		LEFT JOIN Neurons AS Neurons
			|		ON (InternalLayerData%1.Neuron = Neurons.InputNeuron)
			|
			|GROUP BY
			|	Neurons.Neuron
			|
			|ORDER BY
			|	Value DESC
			|AUTOORDER
			|;
			|";
		QueryTextLayer = StrTemplate(QueryTextLayerTemplate, CurrentLayerNumber - 1);
		QueryText = QueryText + QueryTextLayer;	
	EndIf;	
			
	QueryText = QueryText + "	
		|////////////////////////////////////////////////////////////////////////////////
		|DROP InputLayerData
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP Neurons
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP InternalLayerData1";


	Return QueryText;
EndFunction

&AtServer
Function GetResultData()
	Query = New Query;
	Query.Text = GetQueryText();
			
	Query.SetParameter("Neuronet", Object.Neuronet);
	Query.SetParameter("InputLayer", Object.InputNeurons.Unload());
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Select();
EndFunction

&AtServer
Procedure GetResultAtServer()
	Object.Result.Clear();
	
	ResultData = GetResultData();
	While ResultData.Next() Do
		ResultRow = Object.Result.Add();
		FillPropertyValues(ResultRow, ResultData);
	EndDo;
EndProcedure

&AtServerNoContext
Procedure ChangeExperienceAtServer(Neuronet, OutputNeuron)
	SynapticLinksForUpdate = New ValueTable;
	SynapticLinksForUpdate.Columns.Add("InputNeuron");
	SynapticLinksForUpdate.Columns.Add("Neuron");
	SynapticLinksForUpdate.Columns.Add("Weight");
	
	GetSynapticLinksForUpdate(SynapticLinksForUpdate, OutputNeuron);
	a = 1;
EndProcedure

&AtServerNoContext
Function GetInputLinks(Neuron)
	Query = New Query;
	Query.Text =
		"SELECT
		|	NeuronsInputLinks.Neuron AS InputNeuron,
		|	NeuronsInputLinks.Ref AS Neuron,
		|	NeuronsInputLinks.Weight,
		|	NeuronsInputLinks.IsConstant
		|FROM
		|	Catalog.Neurons.InputLinks AS NeuronsInputLinks
		|WHERE
		|	NeuronsInputLinks.Ref = &Neuron";
	
	Query.SetParameter("Neuron", Neuron);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Select();
EndFunction

&AtServerNoContext
Procedure GetSynapticLinksForUpdate(SynapticLinksForUpdate, Neuron)
	InputLinks = GetInputLinks(Neuron);
	While InputLinks.Next() Do
		If Not InputLinks.IsConstant Then
			SynapticLinkForUpdate = SynapticLinksForUpdate.Add();
			FillPropertyValues(SynapticLinkForUpdate, InputLinks);
		EndIf;
		GetSynapticLinksForUpdate(SynapticLinksForUpdate, InputLinks.InputNeuron);
	EndDo;
EndProcedure

#EndRegion