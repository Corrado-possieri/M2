doc ///
   Key
      basis
     (basis, Ideal)
     (basis, InfiniteNumber, InfiniteNumber, Ideal)
     (basis, InfiniteNumber, InfiniteNumber, Matrix)
     (basis, InfiniteNumber, InfiniteNumber, Module)
     (basis, InfiniteNumber, InfiniteNumber, Ring)
     (basis, InfiniteNumber, List, Ideal)
     (basis, InfiniteNumber, List, Matrix)
     (basis, InfiniteNumber, List, Module)
     (basis, InfiniteNumber, List, Ring)
     (basis, InfiniteNumber, ZZ, Ideal)
     (basis, InfiniteNumber, ZZ, Matrix)
     (basis, InfiniteNumber, ZZ, Module)
     (basis, InfiniteNumber, ZZ, Ring)
     (basis, List, Ideal)
     (basis, List, InfiniteNumber, Ideal)
     (basis, List, InfiniteNumber, Matrix)
     (basis, List, InfiniteNumber, Module)
     (basis, List, InfiniteNumber, Ring)
     (basis, List, List, Ideal)
     (basis, List, List, Matrix)
     (basis, List, List, Module)
     (basis, List, List, Ring)
     (basis, List, Matrix)
     (basis, List, Module)
     (basis, List, Ring)
     (basis, List, RingMap)
     (basis, List, ZZ, Ideal)
     (basis, List, ZZ, Matrix)
     (basis, List, ZZ, Module)
     (basis, List, ZZ, Ring)
     (basis, Matrix)
     (basis, Module)
     (basis, Ring)
     (basis, RingMap)
     (basis, Sequence, RingMap)
     (basis, ZZ, Ideal)
     (basis, ZZ, InfiniteNumber, Ideal)
     (basis, ZZ, InfiniteNumber, Matrix)
     (basis, ZZ, InfiniteNumber, Module)
     (basis, ZZ, InfiniteNumber, Ring)
     (basis, ZZ, List, Ideal)
     (basis, ZZ, List, Matrix)
     (basis, ZZ, List, Module)
     (basis, ZZ, List, Ring)
     (basis, ZZ, Matrix)
     (basis, ZZ, Module)
     (basis, ZZ, Ring)
     (basis, ZZ, RingMap)
     (basis, ZZ, ZZ, Ideal)
     (basis, ZZ, ZZ, Matrix)
     (basis, ZZ, ZZ, Module)
     (basis, ZZ, ZZ, Ring)
     [basis, Degree]
     [basis, Limit]
     [basis, SourceRing]
     [basis, Strategy]
     [basis, Truncate]
     [basis, Variables]
   Headline
     basis or generating set of all or part of a ring, ideal or module
   Usage
     f = basis M
     f = basis(deg, M)
     f = basis(lo, hi, M)
   Inputs
     M:{Module,Ring,Ideal,Matrix}
     deg:{ZZ,List}
       a degree or degree vector
     lo:{ZZ,InfiniteNumber}
       or {\tt -infinity}, the low degree
     hi:{ZZ,InfiniteNumber}
       or @TO infinity@, the high degree
     Limit=>ZZ
       an upper bound on the number of basis elements to collect
     Variables=>List
       a list of variables, or variable indices (defaults to the generators of the ring of M)
     SourceRing=>Ring
       if not the ring (of) M, then returns a module map whose target and source have different rings
     Strategy=>Thing
       specifies the algorithm
     Degree=>{ZZ,List}
       sets the degree of the resulting matrix.  Default is 0.  Seldom Used
     Truncate=>Boolean
       internal use only.  Used to implement @TO "Truncations::truncate(ZZ,Module)"@
   Outputs
     f:Matrix
       a map from a free module over the ring of {\tt M} (or by the ring specified with the
       {\tt SourceRing} option, if given), to {\tt M} which sends the basis elements of the
       free module to a basis (over the coefficient field) of the specified part of {\tt M}
   Description
    Text
      The function {\tt basis} finds a basis or generating set of a module over a coefficient ring,
      either for the full module, or for a degree range, or for a specific (multi-)degree.
      A ring or ideal may also be provided instead of a module.  Partial multi-degrees may also be given, see below
      for the usage and meaning.
      
      If $M$ is a matrix, then the matrix between the corresponding 
      bases of the source and target of $M$ is returned.  This feature should be considered experimental.

      The following examples show the varied uses of this function.

      {\bf Basis of the whole ring}
      
      If no degree or degree range is given, then
      a full basis is given.  In the example below, the 12 entries generate $R$ over the base ring ${\mathbb Q}$.
      If the object is not finite, then an error is given.
    Example
      R = QQ[a,b,c]/(a^2, b^3, a*c, c^3);
      basis R
      sort basis R
    Text

      {\bf Basis in a degree or range of degrees}
      
      If a single degree or degree range is given, give a basis (or generating set) of
      that particular degree (or degree range) of $M$.
    Example
      R = QQ[x,y,z]
      basis(2,R)
      I = ideal"x2,y3"
      phi = basis(3,I)
      super phi
    Text
      Notice that {\tt phi} is a matrix whose source is a free module, and whose target is the ideal.  @TO super@ is
      used to get the actual elements of $I$.

      {\bf Basis in a specific multi-degree}
            
      If a multidegree is given, then a range cannot be given.
      In this example, the dimension over QQ of this multigraded piece of R is 2.
    Example
      R = QQ[a..c,Degrees=>{{1,0},{1,-1},{1,-2}}]
      basis({4,-5},R)
    Text
      {\bf Partially described multidegrees}
            
      A partial multidegree can be given.  The given columns generate (form a basis in this case)
      the degree \{2,*\} part of R, over the subring QQ[d] generated by the variables which have degree \{0,*\}.
    Example
      R = QQ[a..d,Degrees=>{{1,0},{1,-1},{1,-2},{0,1}}]
      basis(2,R)
    Text    
      The base ring does not need to be a field.  In these cases, the given image vectors might only
      generate over the base ring, not be a basis.
      For instance, in 
      the following example, $B$ is generated over $A$ by 4 elements, but $B$ is not a free module.
    Example
      A = ZZ/101[a..d];
      B = A[x,y]/(a*x, x^2, y^2);
      try basis B
      basis(B, Variables => B_*)
    Text
      If $M$ is an ideal or module, the resulting map looks somewhat strange, since maps between modules
      are given from generators, in terms of the generators of the target module.  Use @TO super@ or @TO cover@
      to recover the actual elements.
    Example
      R = QQ[a,b,c]/(a^2, b^3, a*c, c^3);
      I = ideal(a,b^2,c)
      F = basis I
      super F
    Example
      C = B[u,v]/(u^2,u*v,v^2)
      basis(C, Variables=>{u,v,x_C,y_C}, SourceRing => A)
    Text
      If {\tt Variables} is given as an optional argument, only monomial multiples of the generators 
      which involve these variables will be considered.  In this case, the resulting elements might not
      form a generating set over the coefficient ring.  They do generate over the subring generated by the other
      variables.
    Example
      D = QQ[a..d]/(a^2, b^2)
      basis(D, Variables => {a,b})
    Text
      If the base ring has a local term order, then the generating set or basis will be over this ring.
    Example
      E = QQ{a..d}
      I = ideal(a+d^3-d^4, b^2 + d^3, c^2 + d^4, d^5)
      f = basis (E^1/I)
      cover f
    Text

      {\bf Functoriality}
          
      {\tt basis} is functorial, meaning that if $M : A \rightarrow B$ is a matrix between two modules,
      then the result is the induced matrix on the images of the result of basis applied to A and B.
    Example
      R = ZZ/101[a..d]
      M = koszul(2,vars R)
      f1 = basis(2, source M)
      f2 = basis(2, target M)
      f = basis(2,M)
      source f == image f1
      target f == image f2
    Text
      Obtain the map of free modules using @TO matrix@:
    Example
      matrix f
   Caveat
     If the base ring is not a field, then the result is only a generating set.  If the optional argument
     Variables is provided, then even this might not be correct.
   SeeAlso
     "Truncations::truncate(ZZ,Module)"
     (sort, Matrix)
     comodule
     super
     cover
///

-*
doc ///
   Key
     basis
   Headline
     basis of all or part of a module, ring or ideal
   Description
    Text
      This function has several variants, so here we introduce the most common uses
      of {\tt basis}.  See the specific links below to see the documentation for each
      variant.
      
      The most basis use is to find all of the monomials in a polynomial ring of a given degree:
    Example
      R = QQ[x,y,z]
      basis(2,R)
    Text
      We can also find a generating set (over the base ring QQ) of an ideal of module.  The returned value is
      a matrix from a free module to the ideal or module.
    Example
      I = ideal"x2,y3"
      phi = basis(3,I)
    Text
      To get the actual elements of I, form the image of this map
    Example
      image phi
   Caveat
   SeeAlso
     truncate
     coefficients
     monomials
     
///

doc ///
   Key
     (basis, Ring)
     (basis, Ideal)
     (basis, Module)
     "entire basis"
   Headline
     full basis or generating set of a finite module
   Usage
     f = basis M
   Inputs
     M:Ring
       or @ofClass Module@ or @ofClass Ideal@
     Limit=>ZZ
       an upper bound on the number of basis elements to collect
     Variables=>List
       a list of variables (defaults to the generators of the ring of M)
     SourceRing=>Ring
       if not the ring (of) M, then returns a module map whose target and source have different rings
   Outputs
     f:Matrix
       a matrix from a free module F to M, the columns forming a generating set 
       of $M$ over the coefficient ring.
   Description
    Text
      For example, the ring below is finite over {\tt QQ}, and has a basis over {\tt QQ}
      the images of the 12 unit vectors (i.e. the entries, in this case) of the output matrix.
    Example
      R = QQ[a,b,c]/(a^2, b^3, a*c, c^3);
      basis R
      sort basis R
    Text
      The base ring does not need to be a field.  In these cases, the given image vectors might only
      generate over the base ring, not be a basis.
      For instance, in 
      the following example, $B$ is generated over $A$ by 4 elements, but $B$ is not a free module.
    Example
      A = ZZ/101[a..d];
      B = A[x,y]/(a*x, x^2, y^2);
      basis B
    Text
      If $M$ is an ideal or module, the resulting map looks somewhat strange, since maps between modules
      are given from generators, in terms of the generators of the target module.  Use @TO super@ or @TO cover@
      to recover the actual elements.
    Example
      use R
      I = ideal(a,b^2,c)
      F = basis I
      super F
    Example
      C = B[u,v]/(u^2,u*v,v^2)
      basis(C, Variables=>{u,v,x_C,y_C}, SourceRing => A)
    Text
      If {\tt Variables} is given as an optional argument, only monomial multiples of the generators 
      which involve these variables will be considered.  In this case, the resulting elements might not
      form a generating set over the coefficient ring.  They do generate over the subring generated by the other
      variables.
    Example
      D = QQ[a..d]/(a^2, b^2)
      basis(D, Variables => {a,b})
    Text
      If the base ring has a local term order, then the generating set or basis will be over this ring.
    Example
      E = QQ{a..d}
      I = ideal(a+d^3-d^4, b^2 + d^3, c^2 + d^4, d^5)
      f = basis (E^1/I)
      cover f
   Caveat
     The resulting elements do not necessarily form a basis, only a generating set.
   SeeAlso
     truncate
     (sort, Matrix)
     comodule
     super
     cover
///

document { Key => {
     	  "previous basis documentation",
	  (basis,List,List,Module), 
	  (basis,InfiniteNumber,ZZ,Module), 
	  (basis,ZZ,InfiniteNumber,Module),
	  (basis,List,InfiniteNumber,Ideal), 
	  (basis,InfiniteNumber,List,Ideal), 
	  (basis,InfiniteNumber,List,Ring), 
	  (basis,List,InfiniteNumber,Ring), 
	  (basis,List,List,Ideal),
	  (basis,InfiniteNumber,ZZ,Ideal), 
	  (basis,ZZ,InfiniteNumber,Ideal), 
	  (basis,List,List,Ring), 
	  (basis,ZZ,InfiniteNumber,Ring), 
	  (basis,InfiniteNumber,ZZ,Ring), 
	  (basis,ZZ,ZZ,Module),
	  (basis,List,ZZ,Ideal), 
	  (basis,ZZ,List,Ideal), 
	  (basis,ZZ,List,Ring), 
	  (basis,List,ZZ,Ring), 
	  (basis,ZZ,ZZ,Ideal), 
	  (basis,ZZ,ZZ,Ring), 
	  (basis,List,Module), 
	  (basis,ZZ,Module),
	  (basis,List,Ideal), 
	  (basis,List,Ring), 
	  (basis,ZZ,Ideal), 
	  (basis,ZZ,Ring), 
	  (basis,List,InfiniteNumber,Module),
	  (basis,InfiniteNumber,List,Module), 
	  Truncate, 
 	  },
     Headline => "basis of all or part of a module or ring",
     Usage => "basis(i,M)",
     Inputs => {
	  "i" => "a list of integers to serve as a degree or multidegree",
	  "M" => {ofClass{Module,Ring,Ideal}, ".  If ", TT "M", " is a ring, it is replaced by the free module of rank 1.
	       If ", TT "M", " is an ideal, it is replaced by its underlying module over the ring it is contained in."},
	  Limit => ZZ => {"the maximum number of basis elements to find"},
	  Truncate => Boolean => {"whether to add additional generators to the basis sufficient to generate the submodule of ", TT "M", " generated
	       by all elements of degree at least ", TT "i", ".  If true, the degree rank must be equal to 1.  This option is intended mainly for internal use by
	       ", TO "Truncations::truncate", "."
	       },
	  Variables => List => {"a list of variables; only basis elements involving only these variables will be reported"},
	  SourceRing => Ring => {"the ring to use as the ring of the source of the map produced; by default, this is the same
	       as the ring of ", TT "M", "."
	       }
	  },
     Outputs => {
	  {
	       "a map from a free module over the ring specified by the ", TO "SourceRing", " option, or over
	       the ring of ", TT "M", " if the option was not used, to ", TT "M", " which sends the
	       basis elements of the free module to a basis (over the coefficient field) of the degree ", TT "i", " part of ", TT "M"
	       }
	  },
     PARA {
	  "The degree ", TT "i", " is a multi-degree, represented as a list of integers.  If the degree rank is 1, then ", TT "i", " may
	  be provided as an integer."
	  },
     PARA {
	  "The algorithm uses the heft vector of the ring, and cannot proceed without one; see ", TO "heft vectors", "."
	  },
     EXAMPLE lines ///
	  R = ZZ/101[a..c];
	  basis(2, R)
	  M = ideal(a,b,c)/ideal(a^2,b^2,c^2)
	  f = basis(2,M)
     ///,
     PARA {
	  "Notice that the matrix of ", TT "f", " above is expressed in terms of the
	  generators of ", TT "M", ".  The reason is that the module ", TT "M", " is the target
	  of the map ", TT "f", ", and matrices of maps such as ", TT "f", " are always expressed 
	  in terms of the generators of the source and target."
	  },
     EXAMPLE lines ///
	  target f
     ///,
     PARA {
     	  "The command ", TO "super", " is useful for rewriting ", TT "f", " in terms of the generators of module of which ", TT "M", " is a submodule."
	  },
     EXAMPLE lines ///
	  super f
     ///,
     PARA { "When a ring is multi-graded, we specify the degree as a list of integers." },
     EXAMPLE lines ///
	  S = ZZ/101[x,y,z,Degrees=>{{1,3},{1,4},{1,-1}}];
	  basis({7,24}, S)
     ///,
     PARA {
	  "Here is an example showing the use of the ", TO "SourceRing", " option.  Using a ring
	  of different degree length as the source ring is currently not well supported, because the
	  graded free modules may not lift."
	  },
     EXAMPLE lines ///
     R = QQ[x]/x^6;
     f = basis(R,SourceRing => ambient R)
     coimage f
     kernel f
     g = basis(R,SourceRing => QQ)
     coimage g
     kernel g
     ///,
     PARA {
	  "In some situations it may be desirable to retain the degrees of the generators, so a ring such as
	  ", TT "QQ[]", ", which has degree length 1, can serve the purpose."
	  },
     EXAMPLE lines ///
     degrees source g
     A = QQ[];
     h = basis(R,SourceRing => A)
     degrees source h
     coimage h
     kernel h
     ///,
     SYNOPSIS (
	  Usage => "basis M",
	  Inputs => { "M" => {ofClass{Module,Ring}} },
	  Outputs => { 
	       { "a map from a free module to ", TT "M", " which sends the basis elements to a basis, over the coefficient field, of ", TT "M" }
	       },
	  EXAMPLE lines ///
	       R = QQ[x,y,z]/(x^2,y^3,z^5)
	       basis R
	  ///
	  ),
     SYNOPSIS (
	  Usage => "basis(lo,hi,M)",
	  Inputs => {
	       "M" => {ofClass{Module,Ring,Ideal}},
	       "lo" => {ofClass{ZZ,List,InfiniteNumber}},
	       "hi" => {ofClass{ZZ,List,InfiniteNumber}}
	       },
	  Outputs => {{
		    "a map from a free module to ", TT "M", " which sends the
		    basis elements to a basis, over the ground field, of the part of ", TT "M", " spanned
		    by elements of degrees between ", TT "lo", " and ", TT "hi", ".
		    The degree rank must be 1."
		    }},
	  EXAMPLE lines ///
	       R = QQ[x,y,z]/(x^3,y^2,z^5);
	       basis R
	       basis(-infinity,4,R)
	       basis(5,infinity,R)
	       basis(2,4,R)
	  ///
	  )
     }

*-
