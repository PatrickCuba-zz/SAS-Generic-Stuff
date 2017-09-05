* Build Reference Dataset and Custom Format ;
Data Ref_ProductLookup;
	 Length Sep1 Sep2 $1.;
     Infile Cards DSD DLM=',' Truncover;
     Input Rank        : 8.
           product     : $5.
           criteria_1  : $10.
           criteria_2  : $10.
           Description : $40.
             ;

     Retain Max_Array ;
     
     sep1=ifc(criteria_1 ne '', '~', '');
     sep2=ifc(criteria_2 ne '', '~', '');
     CodeCombined=Cat(Strip(product)
              , sep1, Strip(criteria_1)
              , sep2, Strip(criteria_2));

     NumOfSep=Sum(CountC(CodeCombined,'~'), 1)*2-1;
     Max_Array=Max(Max_Array, NumOfSep);
     Max_Length=10*Max_Array;
     Call Symputx('Max_Array', Max_Array);
     Call Symputx('Max_Length', Max_Length);
     
     Drop Sep1 Sep2 Max_Array Max_Length NumOfSep;

     Cards;
1, RESL, FXLO, CRD, Residential Fixed Home Loan Low with Credit Card
2, RESL, FXLO, REB, Residential Fixed Home Loan Low Rebate
3, RESL, FXHI, CRD, Residential Fixed Home Loan High with Credit Card
4, RESL, FXHI, REB, Residential Fixed Home Loan High Rebate
5, RESL, LMI, CRD, Residential Fixed Home Loan with LMI w Credit Card
6, RESL, LMI, , Residential Fixed Home Loan with LMI
7, RESL, , , Residential Home Loan Basic
8, RESL, DENY, , Deny Residential Home Loan
;
Run;
Data Fmt;
     Keep Start Label Fmtname HLO;
     Set Ref_ProductLookup End=End;

     Fmtname='$Ranking';
     Start=CodeCombined;
     Label=Rank;
     Output;

     If End Then Do;
           Start='';
           Label=Rank+1;
           HLO='O';
           Output;
     End;
Run;
Proc Format Cntlin=Fmt;
Quit;
Proc Delete Data=Fmt;
Quit;

Data _Null_;
     Length TestVal RankT $&Max_Length.. Rank 8.;
     Array CheckCode [&Max_Array.] $&Max_Length..;

     If _N_=1 Then Do;
           Declare Hash CH(Ordered: 'Yes');
           CH.DefineKey('Rank', 'RankT');
           CH.DefineData('Rank', 'RankT');
           CH.DefineDone();

           Declare HIter CHIter('CH');

           Call Missing(of _ALL_);
     End;

     /* Testing */
     TestVal=''; Expect=9; * Blanks ;
     Link Calc;

     TestVal='XXXX'; Expect=9; * Invalid Value ;
     Link Calc;

     TestVal='RESL'; Expect=7; * Just the product ;
     Link Calc;

     TestVal='RESL~LMI'; Expect=6; * LMI HL ;
     Link Calc;

     TestVal='RESL~LMI~CRD'; Expect=5; * HL w Cred & LMI ;
     Link Calc;

     TestVal='RESL~FXLO~CRD'; Expect=1; * Bestest ;
     Link Calc;

     TestVal='~'; Expect=9; * Invalid Value ;
     Link Calc;

     TestVal='FXHI~RESL~CRD'; Expect=3; * Mix it up ;
     Link Calc;

     Return;

Calc:
     Put '-------------';
     NumOfSep=Sum(CountC(TestVal,'~'), 1)*2-1;

     * Only loaded one value therefore no ~ in array, just apply the format directly on the value and hope for the best ;
     If NumOfSep=1 Then Do;
           Rank=Put(TestVal, $Ranking.);
           AppliedRank=Rank;
     End;
     Else Do;
         * If code is seperated by ~ then load into array to test permutations ;
           *** Load Codes into Array *** ;
         Cnt=0;
           /* Load each value separated by ~ into even array numbers, load a ~ into the array item between */
           Do i=1 To NumOfSep by 2;
                Cnt+1;
                CheckCode{i}=Scan(TestVal, Cnt, '~');
                If i > 1 and CheckCode{i} ne '' Then Do;
                    CheckCode{i-1}='~';
                    nFact=Fact(i);
                End;
           End;
           /* Use this number to try and find all permutations, use the factorial number in the function AllPerm - thats how many permutations we want to try */
           Do i=1 To nFact;
                rc=LexPerm(i, of CheckCode[*]);
               /* We need a variable to store our permutations, reset at each try (start of loop) */
                RankT='';
                Do j=1 to NumOfSep;
                     * Build code from permutation ;
                    RankT=Compress(RankT||CheckCode[j]); 
                    *RankT=CheckCode;
                End;
                * Apply format - if code is not found then it will be given the lowest rank ;
                Rank=Put(RankT, $Ranking.); 
                Put i= TestVal= Rank= RankT= NumOfSep= rc=;
                * Load each instance to a Hash table sorted by Rank, output the highest rank ;
                rc=CH.Add();
           End;

           * Because the Hash table is sorted by Rank the first item in the Hash is the highest rank we must use ;
           rc=CHIter.First();
           AppliedRank=Rank;
           rc=CHIter.Last();
           rc=CHIter.Next();

           rc=CH.Clear();
     End;

     Put TestVal= AppliedRank= Expect=;
     Return;
Run;

