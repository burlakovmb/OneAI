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
		InputNeurons = New Array;
		Filter = New Structure("Active", 1);
		For Each InputNeuron In Object.InputNeurons.FindRows(Filter) Do
			InputNeurons.Add(InputNeuron.Neuron);
		EndDo;
		
		ChangeExperienceAtServer(Object.Neuronet, Item.CurrentData.Neuron, InputNeurons);
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
Function GetDataTreeByLayers(SynapticLinksForUpdate)
	Query = New Query;
	Query.Text =
		"SELECT
		|	SynapticLinks.InputNeuron,
		|	SynapticLinks.Neuron,
		|	SynapticLinks.Weight,
		|	SynapticLinks.IsConstant,
		|	SynapticLinks.Order
		|INTO SynapticLinksForUpdate
		|FROM
		|	&SynapticLinks AS SynapticLinks
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SynapticLinksForUpdate.InputNeuron,
		|	SynapticLinksForUpdate.Neuron,
		|	SynapticLinksForUpdate.Weight,
		|	SynapticLinksForUpdate.IsConstant,
		|	SynapticLinksForUpdate.Order AS Order
		|FROM
		|	SynapticLinksForUpdate AS SynapticLinksForUpdate
		|
		|ORDER BY
		|	Order
		|AUTOORDER
		|TOTALS
		|BY
		|	Order
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP SynapticLinksForUpdate";
	
	Query.SetParameter("SynapticLinks", SynapticLinksForUpdate);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Select(QueryResultIteration.ByGroups);
EndFunction

&AtServerNoContext
Function CheckSynapticLinkTable(SynapticLinkTable, InputNeurons)
	Query = New Query;
	Query.Text =
		"SELECT
		|	SynapticLinkTable.InputNeuron,
		|	SynapticLinkTable.Neuron,
		|	SynapticLinkTable.Weight,
		|	SynapticLinkTable.IsConstant
		|INTO SynapticLinksForUpdate
		|FROM
		|	&SynapticLinkTable AS SynapticLinkTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SynapticLinksForUpdate.InputNeuron,
		|	SynapticLinksForUpdate.Neuron,
		|	SynapticLinksForUpdate.Weight,
		|	SynapticLinksForUpdate.IsConstant
		|FROM
		|	SynapticLinksForUpdate AS SynapticLinksForUpdate
		|WHERE
		|	SynapticLinksForUpdate.InputNeuron IN (&InputNeurons)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP SynapticLinksForUpdate";
	
	Query.SetParameter("SynapticLinkTable", SynapticLinkTable);
	Query.SetParameter("InputNeurons", InputNeurons);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Return True;
	EndDo;
	
	Return False;
EndFunction

&AtServerNoContext
Procedure ChangeExperienceAtServer(Neuronet, OutputNeuron, InputNeurons)
	SynapticLinksForUpdate = New ValueTable;
	SynapticLinksForUpdate.Columns.Add("InputNeuron", New TypeDescription("CatalogRef.Neurons"));
	SynapticLinksForUpdate.Columns.Add("Neuron", New TypeDescription("CatalogRef.Neurons"));
	SynapticLinksForUpdate.Columns.Add("Weight", New TypeDescription("Number"));
	SynapticLinksForUpdate.Columns.Add("IsConstant", New TypeDescription("Boolean"));
	SynapticLinksForUpdate.Columns.Add("Order", New TypeDescription("Number"));
	
	SynapticLinksForUpdateByLayers = New Structure;
	
	GetSynapticLinksForUpdate(SynapticLinksForUpdate, OutputNeuron, 1);
	DataTreeByLayers = GetDataTreeByLayers(SynapticLinksForUpdate);
	While DataTreeByLayers.Next() Do
		SynapticLinksForUpdateByLayer = New ValueTable();
		SynapticLinksForUpdateByLayer.Columns.Add("InputNeuron", New TypeDescription("CatalogRef.Neurons"));
		SynapticLinksForUpdateByLayer.Columns.Add("Neuron", New TypeDescription("CatalogRef.Neurons"));
		SynapticLinksForUpdateByLayer.Columns.Add("Weight", New TypeDescription("Number"));
		SynapticLinksForUpdateByLayer.Columns.Add("IsConstant", New TypeDescription("Boolean"));
		
		NeuronsByLayer = DataTreeByLayers.Select();
		While NeuronsByLayer.Next() Do
			If SynapticLinksForUpdateByLayers.Property("LinkFor_" + Left(NeuronsByLayer.Neuron.UUID(), 8)) Then
				SynapticLinksForUpdateByLayer = SynapticLinksForUpdateByLayers["LinkFor_" + Left(NeuronsByLayer.Neuron.UUID(), 8)].Copy();
			EndIf;
			
			SynapticLinksForUpdateByLayerRow = SynapticLinksForUpdateByLayer.Add();
			FillPropertyValues(SynapticLinksForUpdateByLayerRow, NeuronsByLayer);
			SynapticLinksForUpdateByLayers.Insert("LinkFor_" + Left(NeuronsByLayer.InputNeuron.UUID(), 8), SynapticLinksForUpdateByLayer);
		EndDo;
	EndDo;
	
	CountOfLayers = GetCountOfLayers(Neuronet);
	For Each Link In SynapticLinksForUpdateByLayers Do
		If Link.Value.Count() <> CountOfLayers - 1 Then
			Continue;
		EndIf;
		
		If Not CheckSynapticLinkTable(Link.Value, InputNeurons) Then
			Continue;
		EndIf;
		
		For Each Link In Link.Value Do
			If Link.IsConstant Then
				Continue;
			EndIf;
			
			NeuronObject = Link.Neuron.GetObject();
			
			Filter = New Structure("Neuron", Link.InputNeuron);
			InputLinkRow = NeuronObject.InputLinks.FindRows(Filter)[0];
			InputLinkRow.Weight = InputLinkRow.Weight + 1;
			
			Try
				NeuronObject.Write();
			Except
				Message(ErrorDescription());
			EndTry;
		EndDo;
	EndDo;
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
Procedure GetSynapticLinksForUpdate(SynapticLinksForUpdate, Neuron, Order)
	InputLinks = GetInputLinks(Neuron);
	While InputLinks.Next() Do
		SynapticLinkForUpdate = SynapticLinksForUpdate.Add();
		FillPropertyValues(SynapticLinkForUpdate, InputLinks);
		SynapticLinkForUpdate.Order = Order;
		GetSynapticLinksForUpdate(SynapticLinksForUpdate, InputLinks.InputNeuron, Order + 1);
	EndDo;
EndProcedure

#EndRegion