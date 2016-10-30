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

%Macro SAS_RecQry;
	Proc SQL NoPrint Feedback;
	    /* Anchor Table */
		Create Table SQL_L1 As
		Select b.Parent 
		     , b.Child
		     , 'L_1' As Level Length=5
		From Source a
		Inner Join Source b
		On a.Child=B.Parent
		;
		
		/* SAS Recursive SQL Join - Rolls out hierarchy */
		%Let L=1;
		%Do %Until(&SQLOBS=0);
		    %Let M=&L.;
			%Let L=%Eval(&L.+1);
			Create Table SQL_L&L. As
			Select b.Parent
			     , b.Child
			     , "L_&L." As Level
			From SQL_L&M. a
			Inner Join Source b
			On a.Child=B.Parent
			;
		%End;
		%Let P=%Eval(&L-1);
		
		/* Creates table with Balanced Hierarchy */
		Create Table SQL_Hierarchy As
		Select 1 As Anchor
		     %Do N=1 %To &P.;
			     , L&N..Parent As L&N.a
			     , L&N..Child As L&N.b
			 %End;
		From SQL_L1 L1
		%Do N=2 %To &P.;
		%Let O=%Eval(&N.-1);
			Left Join SQL_L&N. L&N.
			On L&O..Child=L&N..Parent
		%End;
		Where 1
		%Do N=1 %To &P.;
		  And L&N.a ne .
		  And L&N.b ne .
		%End;
		;
		
		/* Reads what was rolled out and inserts into a Macro List */
		Select Node Into :SQL_List Separated By ' '  
		From (
		%Do N=1 %To &P.;
			%If &N. > 1 %Then Union;
			Select L&N.a As Node
			From SQL_Hierarchy 
			Union
			Select L&N.b As Node
			From SQL_Hierarchy
		%End;
		)
		;
				
	Quit;

	Proc Datasets Lib=Work Nolist Nodetails;
		Delete SQL_L1-SQL_L&n SQL_Hierarchy ;
	Quit;
	%Put NOTE: SQL_List = &SQL_List.;
%Mend;
%SAS_RecQry;

** SAS Documentation: http://support.sas.com/kb/25/437.html ;
