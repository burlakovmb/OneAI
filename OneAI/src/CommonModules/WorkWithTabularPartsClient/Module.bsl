#Region Public

Procedure SetFilterByKey(TabularPartItem, Key) Export
	Filter = New Structure("Key", Key);
	TabularPartItem.RowFilter = New FixedStructure(Filter);
EndProcedure

Procedure DeleteRowsByKey(TabularPart, Key) Export
	Filter = New Structure("Key", Key);	
	RowsArray = TabularPart.FindRows(Filter);
	For Each Row In RowsArray Do
		TabularPart.Delete(Row);
	EndDo;
EndProcedure

#EndRegion