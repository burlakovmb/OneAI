#Region Public

Procedure SetFilterByKey(TabularPartItem, Key)
	If Not ValueIsFilled(TabularPartItem) Then
		Return;
	EndIf;
	
	Filter = New Structure("Key", Key);
	TabularPartItem.RowFilter = Filter;
EndProcedure

#EndRegion