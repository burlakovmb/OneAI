#Region Public

Function GetCountOfLayers(Neuronet) Export
	Count = 0;
	
	Layers = Catalogs.Layers.Select(, Neuronet);
	While Layers.Next() Do
		Count = Count + 1;
	EndDo;
	
	Return Count;
EndFunction

Function GetInputNeurons(Neuronet) Export
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
	
	Query.SetParameter("Neuronet", Neuronet);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Select();
EndFunction

Function GetDataTreeByLayers(SynapticLinksForUpdate) Export
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

Function GetInputLinks(Neuron) Export
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

Function CheckSynapticLinkTable(SynapticLinkTable, InputNeurons) Export
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

Procedure GetSynapticLinksForUpdate(SynapticLinksForUpdate, Neuron, Order) Export
	InputLinks = GetInputLinks(Neuron);
	While InputLinks.Next() Do
		SynapticLinkForUpdate = SynapticLinksForUpdate.Add();
		FillPropertyValues(SynapticLinkForUpdate, InputLinks);
		SynapticLinkForUpdate.Order = Order;
		GetSynapticLinksForUpdate(SynapticLinksForUpdate, InputLinks.InputNeuron, Order + 1);
	EndDo;
EndProcedure

Procedure ChangeExperience(Neuronet, OutputNeuron, InputNeurons) Export
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

#EndRegion