Data Source;
	Infile Cards Truncover Dlm='09'x;
	Input child	 : 8.
	      parent : 8.
	      ;
	Cards;
1	.
2	1
3	1
4	2
5	4
6	4
7	4
;
Run;

Data _Null_;
	Length Layer 8. __Child 8.;
	If _N_=1 Then Do; 
		If 0 Then Set Work.Source;
		* Declare Has to Read in Source Data ;
		Declare Hash ReadData(Dataset: 'Work.Source', Ordered:'Yes', Multidata: 'Yes'); 
		ReadData.DefineKey('Child'); 
		ReadData.DefineData('Parent', 'Child');	  
		ReadData.DefineDone();		 
		* Declare Has to Read in Source Data ;
		Declare Hash ReadData2(Dataset: 'Work.Source', Ordered:'Yes', Multidata: 'Yes'); 
		ReadData2.DefineKey('Parent'); 
		ReadData2.DefineData('Parent', 'Child');	  
		ReadData2.DefineDone();		 
						
		* Declare Iterator to Move through data until every report is assigned a layer ;
		Declare Hiter AssignLayer('ReadData');
		
		* Declare Hash to Write out Updates to Layers ;
		Declare Hash WriteData(Ordered: 'Yes'); 
		WriteData.Definekey('Parent', 'Child'); 
		WriteData.DefineData('Parent', 'Child', 'Layer'); 
		WriteData.DefineDone();	 
		
		Declare Hiter PanLayers('WriteData');
		
		Call Missing(of _all_);
	End;
	MaxLoops=ReadData.Num_Items; ** Max Levels Possible ;
	
	* Task 1, Find Grandad - The top of the hierarchy  ;
	L1Rc=AssignLayer.First();
	Do Until(L1Rc ne 0);
        CheckChild=Parent;
        
        RcFind=ReadData.Find(Key: CheckChild);
        If RcFind ne 0 Then Do;
        	Layer=1;
        	Rc=WriteData.Add();
        End;
		L1Rc=AssignLayer.Next();
	End;
	
	* Load the Rest ;
	Rc=AssignLayer.First();
	Do Until(Rc ne 0);
		Lookup=Child;
		Layer+1;
		RcL=ReadData2.Find(Key: Lookup); * Get it from Source ;
		Do Until(RcL ne 0);
			RcC=WriteData.Find(); * Is it in the Target yet? ;
			If RcC ne 0 Then RcA=WriteData.Add();
			RcL=ReadData2.Find_Next(Key: Lookup);
		End;	
		Rc=PanLayers.Next();
	End;
	
	** Now that the data is loaded we go backwards 
	  - the lowest leaf is not a variable length hierarchy ;	
	
	Rc=WriteData.Output(Dataset: 'Work.Layered');	
 Run;
 
 Data _Null_;
 	Length Leaf 8.;
 	If _N_=1 Then Do;
 		If _N_=0 Then Set Layered;
 		Declare Hash ReadData(Dataset: 'Work.Layered', Ordered:'Descending'); 
		ReadData.DefineKey('Layer', 'Parent', 'Child'); 
		ReadData.DefineData('Layer', 'Parent', 'Child');	  
		ReadData.DefineDone();
		
		Declare Hiter AssignLayer('ReadData');
		
		Declare Hash CheckData(Dataset: 'Work.Layered'); 
		CheckData.DefineKey('Parent'); 
		CheckData.DefineData('Parent');	  
		CheckData.DefineDone();
		
		* Declare Hash to Write out Updates to Layers ;
		Declare Hash WriteData(Ordered: 'Yes'); 
		WriteData.Definekey('Leaf'); 
		WriteData.DefineData('Leaf'); 
		WriteData.DefineDone();	
		
		Call Missing(Leaf);
 	End;
 	
 	Rc=AssignLayer.First();
 	LastLeaf=Layer;
 	Do Until(Rc ne 0);
 	    * Check Parent in Child... ;
 	    CheckChild=Child;
 	    CheckParent=Parent;
 	    RcC=CheckData.Find(Key: CheckChild);
 	    
 	    If Layer=LastLeaf or RCC = 0 Then Do;
 	    	RcAdd=WriteData.Add(Key: Child, Data: Child);
 	    End;
 	    
 		Rc=AssignLayer.Next();
 	End;
 	Rc=WriteData.Output(Dataset: 'FinalDS');
 Run;
 
 Data _Null_;
 	Length Mac $255.;
 	Set FinalDS End=End;
 	Retain Mac;
 	Mac=Compbl(Mac||' '||Put(Leaf, 8. -L));
 	
 	If End Then Call Symput('Hash_List', Mac);
 Run;
 %Put Hash_List=&Hash_List.;
 
 * http://support.sas.com/documentation/cdl/en/lrcon/68089/HTML/default/viewer.htm#n1b4cbtmb049xtn1vh9x4waiioz4.htm#p10iopjiei4cx4n16g0uvlvzzqds;