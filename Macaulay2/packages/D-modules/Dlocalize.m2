--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Takes a cyclic holonomic module D_n/I and returns 
-- localization D_n/I [1/f] as D_n module
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Dlocalize = method( Options => {Strategy => OTW})
Dlocalize(Ideal, RingElement) := options -> (I, f) -> (Dlocalization(I,f,options))
Dlocalize(Module, RingElement) := options -> (M, f) -> (Dlocalization(M,f,options))
     
Dlocalization = method( Options => {Strategy => OTW})
Dlocalization(Ideal, RingElement) := options -> (I, f) -> (
     if (I.cache.?quotient === false) then I.cache.quotient = (ring I)^1/I;
     Dlocalize(I.cache.quotient, f, options) )
Dlocalization(Module, RingElement) := options -> (M, f) -> (
     outputRequest := {LocModule};
     outputTable := computeLocalization(M, f, outputRequest, options);
     outputTable#LocModule )

DlocalizeMap = method( Options => {Strategy => OTW})
DlocalizeMap(Ideal, RingElement) := options -> (I, f) -> (DlocalizationMap(I,f,options))
DlocalizeMap(Module, RingElement) := options -> (M, f) -> (DlocalizationMap(M,f,options))
     
DlocalizationMap = method( Options => {Strategy => OTW})
DlocalizationMap(Ideal, RingElement) := options -> (I, f) -> (
     if (I.cache.?quotient === false) then I.cache.quotient = (ring I)^1/I;
     DlocalizeMap(I.cache.quotient, f, options) )
DlocalizationMap(Module, RingElement) := options -> (M, f) -> (
     outputRequest := {LocMap};
     outputTable := computeLocalization(M, f, outputRequest, options);
     outputTable#LocMap )

DlocalizeAll = method( Options => {Strategy => OTW})
DlocalizeAll(Ideal, RingElement) := options -> (I, f) -> (DlocalizationAll(I,f,options))
DlocalizeAll(Module, RingElement) := options -> (M, f) -> (DlocalizationAll(M,f,options))
     
DlocalizationAll = method( Options => {Strategy => OTW})
DlocalizationAll(Ideal, RingElement) := options -> (I, f) -> (
     if (I.cache.?quotient === false) then I.cache.quotient = (ring I)^1/I;
     DlocalizeAll(I.cache.quotient, f, options) )
DlocalizationAll(Module, RingElement) := options -> (M, f) -> (
     outputRequest := {LocModule, LocMap, Bfunction, 
	  IntegrateBfunction, Boperator, GeneratorPower, annFS};
     computeLocalization(M, f, outputRequest, options) )

------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
--
-- computeLocalization (Module M, RingElement f, List output)
--
-- Computes the localization and returns a hash table of outputs according to the 
-- request given by "output"
--
--
-- Two different strategies are possible:
--
-- 1. "Saturated" -- appears in Walther's paper on local cohomology and 
--     based on Oaku's work
--
-- 2. "OTW" -- appears in paper of Oaku-Takayama-Walther on localization
--
--
-- Possible output formats: 
--
--     LocModule, LocMap, Bpolynomial, Boperator
--
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
computeLocalization = (M, f, output, options) -> (
   W := ring M;
   r := numgens target gens M; 
   -- case 1: M is a proper submodule of (D_n)^r/N
   if (gens M != map(W^r) ) 
   then error "expected input to be a cokernel";
   -- case 2: M is a cokernel
   if (r > 1) then error "non-cyclic modules not yet supported";

   outputList := {};
   pInfo(1, "localize: Computing localization with " | 
	toString options.Strategy | " strategy...");
   
   if (options.Strategy == Oaku) then (
	pInfo(1, "localize: Warning: Oaku's strategy requires 
	     module to be f-saturated");
	I := ideal relations M;
     	tInfo := toString first timing (AnnI := AnnIFs2 (I,f););
	pInfo(2, "\t\t\t time = " | tInfo | " seconds");
     	Ws := ring AnnI;
     	ns := numgens Ws;
	
	elimWs := (coefficientRing Ws)[(entries vars Ws)#0,
	     WeylAlgebra => Ws.monoid.Options.WeylAlgebra,
	     MonomialOrder => Eliminate (ns-1)];
     	ff := substitute(f,elimWs);
     	elimAnnI := substitute(AnnI, elimWs);
     	H := gens elimAnnI | matrix{{ff}};

	if member(Boperator, output) then (
	     pInfo(1, "localize: computing Bpoly and Bop...");
     	     tInfo = toString first timing (
	     	  gbH := gb(H, ChangeMatrix => true);
     	     	  bpolys := selectInSubring(1, gens gbH);
     	     	  if (bpolys == 0) then error "module not specializable";
     	     	  if (rank source bpolys > 1) then error "ideal principal but not
     	     	  realized as such.  Need better implementation";
     	     	  bpoly := bpolys_(0,0);
	     	  ind := position((entries gens gbH)#0, i -> (i == bpoly));
     	     	  C := getChangeMatrix gbH;
     	     	  tempBop := C_(numgens source H - 1, ind);     
	     	  Bop := tempBop;
		  );
	     pInfo(2, "\t\t\t time = " | tInfo | " seconds");	     
	     )
	else (
	     pInfo(1, "localize: computing Bpoly...");
     	     tInfo = toString first timing (
	     	  bpoly = (mingens ideal selectInSubring(1, gens gb H))_(0,0);
		  );
	     pInfo(2, "\t\t\t time = " | tInfo | " seconds");	     
	     if (bpoly == 0) then error "module not specializable";
	     );

     	bpoly = substitute(bpoly, (coefficientRing W)[Ws_(ns-1)]);
     	bestPower := min (getIntRoots (bpoly));
        if (bestPower == infinity) then bestPower = 0;
     	locIdeal := substitute(substitute(AnnI, {Ws_(ns-1) => bestPower}), W);
     	locModule := W^1/locIdeal;

     	if member (LocMap, output) then (
	     if (locModule == 0) then locMap = map(W^0, M, 
		  transpose compress matrix{{0_W}})
       	     else (
	     	  if (bestPower > 0) then (
	     	       pInfo(0, "Warning: Still need to add b-operator.  Adjusting
		       generator to make localization map simple");
		       bestPower = 0;
		       locIdeal = substitute(substitute(AnnI, 
			    	 {Ws_(ns-1) => bestPower}), W);
     		       locModule = W^1/locIdeal;
		       locMap = map(locModule, M, matrix{{f^(-bestPower)}})
		       )
	     	  else locMap = map(locModule, M, matrix{{f^(-bestPower)}});
		  );
	     );
	)
   
   else if (options.Strategy == OTW) then (
       	N := relations M;
       	nW := numgens W;
       	if (W.?dpairVars === false) then createDpairs(W);
       	n := #W.dpairVars#0;
       	-- create the auxilary ring D_n<a,Da> 
       	a := symbol a;
       	Da := symbol Da;
       	LW := (coefficientRing W)[(entries vars W)#0, a, Da,
	     WeylAlgebra => append(W.monoid.Options.WeylAlgebra, a=>Da)];
       	nLW := numgens LW;
       	WtoLW := map(LW, W, (vars LW)_{0..nW-1});
       	LWtoW := map(W, LW, (vars W) | matrix{{0_W,0_W}});
       	createFourier(LW);
       	-- weight vectors for integration to a = 0
       	w := append( toList(n:0), -1);
       	wt := join( toList(nW:0), {1,-1} );
       	-- twist generators of I into generators of twistI;
       	Lf := WtoLW f;
       	twistList := apply( toList(0..nLW-1), 
	     i -> LW_i - (LW_i*Lf - Lf*LW_i) * a^2 * Da );
       	twistMap := map(LW, LW, matrix{twistList});
       	LN := WtoLW N;
       	twistN = matrix{{1-Lf*a}} | twistMap LN;
	pInfo (1, "localize: computing Bpoly...");
       	tInfo = toString first timing (
	     bpoly = bFunction(ideal twistN, w);
	     );
	pInfo(2, "\t\t\t time = " | tInfo | " seconds");
       	if (bpoly == 0) then (
	     use W;
       	     error "Module not specializable. Localization cannot be computed.";
	     );
       	bpoly = substitute(bpoly, {(ring bpoly)_0 => (ring bpoly)_0 + 1});
       	intRoots := getIntRoots(bpoly);
       	if (#intRoots == 0) then maxRoot := -infinity
       	else maxRoot = max intRoots;
       	-- case 1: no non-negative integer roots
       	if (maxRoot < 0) then (
	     locModule = W^0;
	     locMap = map(W^0, M, transpose compress matrix{{0_W}});
	     maxRoot = 0;
	     bestPower = -2;
	     )
       	-- case 2: localization generated by (1/f)^(maxroot+2)
       	else (
	     bestPower = -maxRoot - 2;
	     pInfo(1, "localize: computing GB...");
	     tInfo = toString first timing (
		  G := gens gbW2 (ideal twistN, wt);
		  );
	     pInfo(2, "\t\t\t time = " | tInfo | " seconds");
	     i := 0;
	     relationsList := {};
	     while (i < numgens source G) do (
	       	  gi := G_(0,i);
	       	  weight := max apply(exponents gi, e -> sum(e, wt, (b,c)->b*c) );
	       	  j := 0;
	       	  while (j <= maxRoot - weight) do (
		       tmp := LW.Fourier (a^j * gi);
     	       	       relationsList = append(relationsList, 
			    LW.FourierInverse substitute(tmp, {a => 0}) );
		       j = j+1;
		       );
	       	  i = i+1;
	       	  );
	     relationsMat := transpose matrix{relationsList};
	     tempL := coefficients({nLW-2}, relationsMat);
	     presMat := transpose tempL#1;
	     srcSize := numgens source presMat;
	     targSize := numgens target presMat;
	     genIndex := position((entries tempL#0)#0, e->(e==a^maxRoot));
	     permList := apply( targSize, i ->
	       	  if (i == genIndex) then (targSize-1)
	       	  else if (i == targSize-1) then genIndex
	       	  else i );
	     presMat = map(LW^targSize, LW^srcSize, presMat^permList);
	     -- eliminate the first "maxRoot" components to get annihilating ideal
	     -- of "a^(maxRoot)"
	     HW := (coefficientRing W)[symbol homVar, (entries vars W)#0,
	       	  WeylAlgebra => W.monoid.Options.WeylAlgebra,
	       	  MonomialOrder => Eliminate 1];
	     HWtoW := map(W, HW, matrix{{1_W}} | (vars W) );
	     WtoHW := map(HW, W, (vars HW)_{1..numgens W});
	     I1 := LWtoW presMat;
	     I2 := WtoHW I1;
	     I3 := transpose ( HW_0 * (transpose I2)_{0..(targSize)-2} | 
	       	  (transpose I2)_{targSize - 1} );
	     pInfo(1, "localize: computing presentation...");
	     tInfo = toString first timing (
	     	  I4 := gens gb I3;
		  );
	     pInfo(2, "\t\t\t time = " | tInfo | " seconds");
	     I5 := map(HW^(numgens target I4), HW^(numgens source I4), I4); 
	     testMap := map(HW^targSize, HW^targSize,
	       	  matrix append( toList(targSize-1 : toList(targSize:0_HW)),
		       append(toList(targSize-1:0_HW), 1_HW) ) );
	     i = 0;
	     tempList = {};
	     while (i < numgens source I5) do (
	       	  if (testMap * I5_{i} == I5_{i}) then (
		       tempList = append(tempList, I5_(targSize-1,i)) );
	       	  i = i+1;
	       	  );
	     if (tempList === {}) then (
		  locModule = W^0;
		  locMap = map(W^0, M, transpose compress matrix{{0_W}});
		  )
	     else (
		  locModule = cokernel HWtoW matrix{tempList};
		  locMap = map(locModule, M, matrix{{f^(-bestPower)}});
		  );	     
	     );
	)
   else error "Only recognizes strategies Saturated and OTW (default)";

   use W;
   if member(LocModule, output) then outputList = append(outputList, 
	LocModule => locModule);
   if member(LocMap, output) then outputList = append(outputList,
	LocMap => locMap);
   if member(GeneratorPower, output) then outputList = append(outputList, 
	GeneratorPower => bestPower);
   if options.Strategy == OTW then (
   	if member(IntegrateBfunction, output) then outputList = append(outputList,
	     IntegrateBfunction => factorBFunction bpoly);
	);
   if options.Strategy == Oaku then (
   	if member(Bfunction, output) then outputList = append(outputList,
	     Bfunction => factorBFunction bpoly);
	if member(annFS, output) then outputList = append(outputList,
	     annFS => AnnI);  
   	if member(Boperator, output) then outputList = append(outputList,
	     Boperator => Bop);
   	);
   hashTable outputList
   )


AnnIFs2 = method()
AnnIFs2(Ideal, RingElement) := (I, f) -> (
     pInfo(1, "computing AnnIFs... ");
     W := ring I;
     n := numgens W;
     
     t := symbol t;
     dt := symbol dt;
     WAopts := W.monoid.Options.WeylAlgebra | {t => dt};
     WT := (coefficientRing W)[ t, dt, (entries vars W)#0, 
	  WeylAlgebra => WAopts,
	  MonomialOrder => Eliminate 2 ];
     u := symbol u;
     v := symbol v;
     WTUV := (coefficientRing W)[ u, v, t, dt, (entries vars W)#0,
	  WeylAlgebra => WAopts,
	  MonomialOrder => Eliminate 2 ];
     WtoWTUV := map(WTUV, W, (vars WTUV)_{4..n+3});
     -- twist generators of I into generators of KI
     f' := substitute(f,WTUV);
     twistList := join({u,v,t-f',dt}, apply( toList(4..n+3), 
	  i -> WTUV_i + (WTUV_i*f' - f'*WTUV_i)*dt));
     twistMap := map(WTUV, WTUV, matrix{twistList});
     tempKI = twistMap(ideal (t) + WtoWTUV I);
     wts := {1,-1,1,-1} | toList(n:0);
     KI = ideal homogenize(gens tempKI, u, wts);
     
     g := (entries gens KI)#0 | { u * v - 1 };
     preGens := flatten entries substitute(
	  selectInSubring(1, gens gb ideal g), WT);
     use WT;
     s := symbol s;
     WS := (coefficientRing W)[(entries vars W)#0, s,
	  WeylAlgebra => W.monoid.Options.WeylAlgebra];
     WTtoWS := g -> (
	  e := exponents leadMonomial g;
	  if e#0 > e#1 then g = dt^(e#0-e#1) * g
	  else g = t^(e#1-e#0) * g;
	  g' := 0_WS;
	  while (d := exponents leadMonomial g; d#0 * d#1 != 0) do(
	       c := leadCoefficient g;
	       g' = g' + c * (-s-1)^(d#1) * WS_(drop(d, 2) | {0}); -- >%-0	
	       g = g - c * (t*dt)^(d#1) * WT_({0,0} | drop(d, 2));
	       ); 
	  g' + substitute(g, WS)
	  );
     use W;
     ideal (preGens / WTtoWS) 
     )
