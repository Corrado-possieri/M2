newPackage(
    "FGLM",
    Version => "1.0.0",
    Date => "May 20, 2019",
    Authors => {
        { Name => "Dylan Peifer",   Email => "djp282@cornell.edu", HomePage => "https://math.cornell.edu/~djp282" },
        { Name => "Mahrud Sayrafi", Email => "mahrud@umn.edu",     HomePage => "https://math.umn.edu/~mahrud" }
        },
    Headline => "Groebner bases via the FGLM algorithm"
    )

-*
Copyright (C) 2019 Dylan Peifer and Mahrud Sayrafi

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*-

export {"fglm"}

-------------------------------------------------------------------------------
--- top level functions
-------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- See Section 2.4.4, Algorithm 2.5 of Thibaut Verron's thesis for details:
-- https://thibautverron.github.io/doc/2016-these.pdf
---------------------------------------------------------------------------
fglm = method()
fglm(Ideal,         Ring) := GroebnerBasis => (I1, R2) -> fglm(gb I1, R2)
fglm(GroebnerBasis, Ring) := GroebnerBasis => (G1, R2) -> (
    -- G1 = a Groebner basis for I1 in R1
    -- R2 = a polynomial ring
    -- returns Groebner basis G2 of the ideal generated by G1 in the ring R2

    R1 := ring G1;
    kk := coefficientRing R1;
    I1 := ideal gens G1; -- TODO: make a github issue add gb to cache
    if R1 == I1 then return forceGB(sub(gens G1, R2));
    if dim I1 > 0 then error "expected zero-dimensional ideal";
    if #gens R1 != #gens R2 then error "expected the same number of generators";

    M := multiplicationMatrices G1;
    m := numcols M#0;
    n := #gens R2;

    -- elements in the groebner basis
    G2 := new MutableHashTable from {}; -- leading term => gb element
    -- elements in the staircase
    B2 := new MutableHashTable from {1_R2 => true};
    B2' := {1_R2};

    -- initiating LU-decomposition matrices
    P := new MutableList from toList(0..m-1);
    v := transpose matrix {{1_kk} | toList ((m-1):0)};
    LU := mutableMatrix map(kk^m, kk^(m+1), 0);
    lambda := transpose mutableMatrix {toList (m:0_kk)};
    incrLU(P, LU, v, 0);

    -- normal form translation table
    -- Note: we want dense mutable matrices
    -- TODO: get rid of this and use LU
    V := new MutableHashTable from {1_R2 => v};

    -- list of elements between the staircase and groebner basis generators
    -- Note: use a heap in the engine for this
    S := new MutableHashTable from for i to n - 1 list R2_i * 1_R2 => (i, 1_R2);

    s := 1;
    while #S > 0 do (
	-- TODO: use O(1) min for fun and profit
	(elt, vals) := min pairs S;
	remove(S, elt);
	if any(keys G2, lt -> elt % lt == 0) then continue;
	(i, mu) := vals;
	v = M#i * V#mu;

	-- FIXME: About 70% of time is spent on these three lines:
	r := incrLU(P, LU, v, s);
	if r == 0 then (
	    backSub(
		submatrix(LU, toList(0..s-1), toList(0..s-1)),
		submatrix(LU, toList(0..s-1), {s}), lambda
		);
	    -- TODO: don't remake a matrix every time
	    g := elt - matrix {B2'} * matrix submatrix(lambda, toList(0..s-1), {0});
	    G2#elt = g;
	    ) else (
	    s = s + 1;
	    -- TODO: add elt to VS and row reduce here
	    V#elt = v;
	    B2#elt = true;
	    B2' = B2' | {elt};
	    -- Add the product of elt and generators of R2 to S
	    for j to n - 1 do if not B2#?(R2_j * elt) then S#(R2_j * elt) = (j, elt);
	    );
	);
    forceGB(matrix {values G2})
    )

incrLU = (P, LU, v, n) -> (
    v = mutableMatrix v^(new List from P); -- FIXME
    m := numrows LU;
    -- copy v to LU_{n}
    for j to m - 1 do LU_(j, n) = v_(j, 0);
    -- reduce LU_{n}
    for i to n - 1 do (
	v_(i, 0) = LU_(i, n);
	columnAdd(LU, n, -LU_(i, n), i);
	);
    -- replace top of v in U
    for i to n - 1 do LU_(i, n) = v_(i, 0);
    -- update P
    n' := position(n..m-1, j -> LU_(j, n) != 0);
    if ZZ === class n' then n' = n' + n else return 0;
    if n != n' then (
	rowSwap(LU, n, n');
	P#n = P#n + P#n';
	P#n' = P#n - P#n';
	P#n = P#n - P#n';
    );
    -- set 1 to diagonal of L
    for j from n + 1 to m - 1 do LU_(j, n) = LU_(j, n) / LU_(n, n);
    -- return new v
    transpose matrix { toList(n:0) | for j from n to m - 1 list LU_(j, n) }
    )

-- U is upper triangular
-- fills x such that Ux=v
backSub = (U, v, x) -> (
    n := numrows U;
    x_(n-1, 0) = v_(n-1, 0) / U_(n-1, n-1);
    for i from 2 to n do x_(n-i,0) = (v_(n-i, 0) - sum(n-i+1..n-1, j -> U_(n-i, j) * x_(j,0))) / U_(n-i,n-i);
    )

-------------------------------------------------------------------------------
-- See Section 2.4.4, Algorithm 2.4 of Thibaut Verron's thesis for details:
-- https://thibautverron.github.io/doc/2016-these.pdf
-- Applies more "tricks"
-------------------------------------------------------------------------------
-- TODO: Move to engine
-- TODO: return MutableMatrix
multiplicationMatrices' = method()
multiplicationMatrices'(GroebnerBasis) := List => (G) -> (
    -- G = a GroebnerBasis
    -- returns the matrices giving multiplication by variables in R/I

    R := ring G;
    I := ideal gens G;
    B := first entries sub(basis (R/I), R); -- TODO: find a way to avoid recomputing GB
    N := new MutableHashTable from for b in B list b => b;
    F := flatten for x in gens R list flatten apply(B, b -> if not N#?(x * b) then x * b else {});
    F = sort F;

    for mu in F do (
	i := position(first entries leadTerm G, g -> mu == leadMonomial g);
	if i =!= null then (
	    g := (gens G)_i_0;
	    N#mu = mu - g // leadCoefficient g; -- Verron has typo in line 9
	    ) else (
	    j := position(F, mu' -> mu % mu' == 0 and any(gens R, x -> mu == x * mu'));
	    mu' := F#j;
	    (gs, cs) := coefficients N#mu';
	    N#mu = sum apply(first entries gs, first entries transpose cs, (g, c) -> N#(g * mu // mu') * c);
	    );
	);

    for x in gens R list lift(last coefficients(matrix{apply(x * B, elt -> N#elt)}, Monomials => B), coefficientRing R)
    )

-- TODO: Make this into a more general function that gets
-- (f: ring elt, S: quotient ring, B: basis) -> (M: multiplication matrix of f)
multiplicationMatrices = method()
multiplicationMatrices(GroebnerBasis) := List => (G) -> (
    -- G = a GroebnerBasis
    -- returns the matrices giving multiplication by variables in R/I

    R := ring G;
    I := ideal gens G;
    B := basis (R/I); -- TODO: find a way to avoid recomputing GB

    for x in gens R list lift(last coefficients(x * B, Monomials => B), coefficientRing R)
    )

-*
-- Input invertible upper triangular U and b and return x such that Ux=b
backsub(Matrix, Matrix) := Matrix => opts -> (U, b) -> (
    )

-- Input invertible upper triangular U and b and return x such that Ux=b
forwardsub(Matrix, Matrix) := Matrix => (L, b) -> (
    backsub(L, b, Forward => true)
    )

-- Input A, x, b and returns true if Ax=b
isEqual(Matrix, Matrix, Matrix) := Boolean -> (
    )

-- permute rows or columns
permuteMatrix(Matrix, List) := Matrix -> opts -> (
    )

-- return x such that LUx=b or null
solveLU(List, Matrix, Matrix, Matrix) := Matrix -> opts -> (P, L, U, b) -> (
    )

updateLU(List, Matrix, Matrix, Matrix) := (List, Matrix, Matrix) -> opts -> (P, L, U, b) -> (
    opts->U'
    call permute
    call backsub
    return LU factorization
    )
*-

-------------------------------------------------------------------------------
--- Helper functions for tests
-------------------------------------------------------------------------------

cyclic = method(Options => {CoefficientRing => ZZ/32003, MonomialOrder => GRevLex})
cyclic(ZZ) := Ideal => opts -> (n) -> (
    R := (opts.CoefficientRing)[vars(0..n-1), MonomialOrder => opts.MonomialOrder];
    F := toList apply(1..n-1, d -> sum(0..n-1, i -> product(d, k -> R_((i+k)%n))))
         | {product gens R - 1};
    ideal F
    )

katsura = method(Options => {CoefficientRing => ZZ/32003, MonomialOrder => GRevLex})
katsura(ZZ) := Ideal => opts -> (n) -> (
    n = n-1;
    R := (opts.CoefficientRing)[vars(0..n), MonomialOrder => opts.MonomialOrder];
    L := gens R;
    u := i -> (
	 if i < 0 then i = -i;
	 if i <= n then L_i else 0_R
	 );
    f1 := -1 + sum for i from -n to n list u i;
    F := toList prepend(f1, apply(0..n-1, i -> - u i + sum(-n..n, j -> (u j) * (u (i-j)))));
    ideal F
    )

test = (I1, MO2) -> (
    R1 := ring I1;
    R2 := (coefficientRing R1)(monoid ([gens R1], MonomialOrder => MO2));
    G2 := gb(sub(I1, R2));
    elapsedTime G2' := fglm(I1, R2);
    assert(gens G2 == gens G2')
    )

-------------------------------------------------------------------------------
--- documentation
-------------------------------------------------------------------------------
beginDocumentation()

doc ///
Key
  FGLM
Headline
  Compute Groebner bases via the FGLM algorithm
Description
  Text
    FGLM is a Groebner basis conversion algorithm. This means it takes a
    Groebner basis of an ideal with respect to one monomial order and changes it
    into a Groebner basis of the same ideal over a different monomial
    order. Conversion algorithms can be useful since sometimes when a Groebner
    basis over a difficult monomial order (such as lexicographic or an
    elimination order) is desired, it can be faster to compute a Groebner basis
    directly over an easier order (such as graded reverse lexicographic) and
    then convert rather than computing directly in the original order. Other
    examples of conversion algorithms include the Groebner walk and
    Hilbert-driven Buchberger.

    FGLM performs conversion by doing linear algebra in the quotient ring R/I,
    where I is the ideal generated by the original Groebner basis in the
    polynomial ring R. This requires that I is zero-dimensional.

    In Macaulay2, monomial orders must be given as options to rings. For
    example, the following ideal has monomial order given by graded reverse
    lexicographic (which is also the default order in Macaulay2).

  Example
    R1 = QQ[x,y,z, MonomialOrder => GRevLex]
    I1 = ideal(x*y + z - x*z, x^2 - z, 2*x^3 - x^2*y*z - 1)
  Text
    If we want a Groebner basis of I1 with respect to lexicographic order
    we could substitute the ideal into
    a new ring with that order and compute directly,
  Example
    R2 = QQ[x,y,z, MonomialOrder => Lex];
    I2 = sub(I1, R2);
    gens gb I2  -- performs computation in R2
  Text
    but it may be faster to compute directly in the first order and then use
    FGLM.
  Example
    G1 = gb I1;  -- performs computation in R1
    gens fglm(G1, R2)

  Text
    Further background and details can be found in the following resources:
  Text
    @UL {
        "Cox, Little, O'Shea - Using Algebraic Geometry (2005)",
        "Faugere, Gianni, Lazard, Mora - Efficient Computation of Zero-dimensional
         Groebner Bases by Change of Ordering (1993)",
        "Gerdt, Yanovich - Implementation of the FGLM Algorithm and Finding Roots
         of Polynomial Involutive Systems (2003)"
     }@
Caveat
  The ideal generated by the Groebner basis must be zero-dimensional.
SeeAlso
  groebnerBasis
///

doc ///
Key
  fglm
  (fglm, GroebnerBasis, Ring)
  (fglm, Ideal, Ring)
Headline
  convert a Groebner basis
Usage
  H = fglm(G, R)
  H = fglm(I, R)
Inputs
  G: GroebnerBasis
     the starting Groebner basis
  I: Ideal
     the starting ideal
  R: Ring
     a ring with the target monomial order
Outputs
  H: GroebnerBasis
     the new Groebner basis in the target monomial order
Description
  Text
    FGLM takes a Groebner basis of an ideal with respect to one monomial order
    and changes it into a Groebner basis of the same ideal over a different
    monomial order. The initial order is given by the ring of G and the target
    order is the order in R. When given an ideal I as input a Groebner basis of
    I in the ring of I is initially computed directly, and then this Groebner
    basis is converted into a Groebner basis in the ring R.
  Example
    R1 = QQ[x,y,z];
    I1 = ideal(x^2 + 2*y^2 - y - 2*z, x^2 - 8*y^2 + 10*z - 1, x^2 - 7*y*z);
    R2 = QQ[x,y,z, MonomialOrder => Lex];
    fglm(I1, R2)
Caveat
  The ideal I generated by G must be zero-dimensional. The target ring R must be
  the same ring as the ring of G or I, except with different monomial order. R
  must be a polynomial ring over a field.
SeeAlso
  FGLM
  groebnerBasis
///

-------------------------------------------------------------------------------
--- tests
-------------------------------------------------------------------------------

TEST ///
  debug needsPackage "FGLM"
  R1 = ZZ/101[x,y,z]
  I1 = ideal(x*y + z - x*z, x^2 - z, 2*x^3 - x^2*y*z - 1)
  test(I1, Lex)
///

TEST ///
  debug needsPackage "FGLM"
  R1 = QQ[x,y,z]
  I1 = ideal(x^2 + 2*y^2 - y - 2*z, x^2 - 8*y^2 + 10*z - 1, x^2 - 7*y*z)
  test(I1, Lex)
///

TEST ///
  debug needsPackage "FGLM"
  R1 = QQ[x,y,z]
  I1 = ideal(x^2 + y^2 + z^2 - 2*x, x^3 - y*z - x, x - y + 2*z)
  test(I1, Lex)
///

TEST ///
  debug needsPackage "FGLM"
  R1 = QQ[x,y,z]
  I1 = ideal(x*y + z - x*z, x^2 - z, 2*x^3 - x^2*y*z - 1)
  test(I1, Lex)
///

TEST ///
  -- katsura6
  -- gb: 0.123865
  -- fglm: 0.115399
  debug needsPackage "FGLM"
  I = katsura(6, MonomialOrder=>Lex)
  G1 = elapsedTime gb I
  I = katsura(6)
  R = newRing(ring I, MonomialOrder=>Lex)
  G2 = elapsedTime fglm(I, R)
  assert(sub(gens G2, ring G1) == gens G1)
///

TEST ///
  -- cyclic6
  -- gb: 0.280165
  -- fglm: 0.885988
  debug needsPackage "FGLM"
  I = cyclic(6, MonomialOrder=>Lex)
  G1 = elapsedTime gb I
  I = cyclic(6)
  R = newRing(ring I, MonomialOrder=>Lex)
  G2 = elapsedTime fglm(I, R)
  assert(sub(gens G2, ring G1) == gens G1)
///

end--

-------------------------------------------------------------------------------
--- Development sections
-------------------------------------------------------------------------------

restart
uninstallPackage "FGLM"
restart
installPackage "FGLM"

restart
needsPackage "FGLM"
elapsedTime check FGLM -- ~3.2 seconds

viewHelp "FGLM"

-------------------------------------------------------------------------------
--- Longer tests
-------------------------------------------------------------------------------

-- cyclic7
-- gb: 1354.44
-- fglm: 353.367
restart
debug needsPackage "FGLM"
I = cyclic(7, MonomialOrder=>Lex)
G1 = elapsedTime gb I
I = cyclic(7)
R = newRing(ring I, MonomialOrder=>Lex)
G2 = elapsedTime fglm(I, R)


-- katsura7
-- gb: 6.78653
-- fglm: 0.779608
restart
debug needsPackage "FGLM"
I = katsura(7, MonomialOrder=>Lex)
G1 = elapsedTime gb I
I = katsura(7)
R = newRing(ring I, MonomialOrder=>Lex)
G2 = elapsedTime fglm(I, R)


-- katsura8
-- gb: 2305.46
-- fglm: 8.23514
restart
debug needsPackage "FGLM"
I = katsura(8, MonomialOrder=>Lex)
G1 = elapsedTime gb I
I = katsura(8)
R = newRing(ring I, MonomialOrder=>Lex)
G2 = elapsedTime fglm(I, R)


-- reimer5
-- gb: 8.3658
-- fglm: 3.79775
restart
needsPackage "FGLM"
kk = ZZ/32003
R1 = kk[x,y,z,t,u, MonomialOrder=>Lex]
I1 = ideal(2*x^2 - 2*y^2 + 2*z^2 - 2*t^2 + 2*u^2 - 1,
           2*x^3 - 2*y^3 + 2*z^3 - 2*t^3 + 2*u^3 - 1,
           2*x^4 - 2*y^4 + 2*z^4 - 2*t^4 + 2*u^4 - 1,
           2*x^5 - 2*y^5 + 2*z^5 - 2*t^5 + 2*u^5 - 1,
           2*x^6 - 2*y^6 + 2*z^6 - 2*t^6 + 2*u^6 - 1)
G1 = elapsedTime gb I1
R2 = kk[x,y,z,t,u]
I2 = sub(I1, R2)
G2 = elapsedTime fglm(I2, R1)

-- virasoro
-- gb: 8.91079
-- fglm: 52.1752
restart
needsPackage "FGLM"
kk = ZZ/32003
R1 = kk[x1,x2,x3,x4,x5,x6,x7,x8, MonomialOrder=>Lex]
I1 = ideal(8*x1^2 + 8*x1*x2 + 8*x1*x3 + 2*x1*x4 + 2*x1*x5 + 2*x1*x6 + 2*x1*x7 - x1 - 8* x2*x3 - 2*x4*x7 - 2*x5*x6,
           8*x1*x2 - 8*x1*x3 + 8*x2^2 + 8*x2*x3 + 2*x2*x4 + 2*x2*x5 + 2*x2*x6 + 2*x2* x7 - x2 - 2*x4*x6 - 2*x5*x7,
	   -8*x1*x2 + 8*x1*x3 + 8*x2*x3 + 8*x3^2 + 2*x3*x4 + 2*x3*x5 + 2*x3*x6 + 2* x3*x7 - x3 - 2*x4*x5 - 2*x6*x7,
	   2*x1*x4 - 2*x1*x7 + 2*x2*x4 - 2*x2*x6 + 2*x3*x4 - 2*x3*x5 + 8*x4^2 + 8*x4* x5 + 2*x4*x6 + 2*x4*x7 + 6*x4*x8 - x4 - 6*x5*x8,
	   2*x1*x5 - 2*x1*x6 + 2*x2*x5 - 2*x2*x7 - 2*x3*x4 + 2*x3*x5 + 8*x4*x5 - 6*x4* x8 + 8*x5^2 + 2*x5*x6 + 2*x5*x7 + 6*x5*x8 - x5,
	   -2*x1*x5 + 2*x1*x6 - 2*x2*x4 + 2*x2*x6 + 2*x3*x6 - 2*x3*x7 + 2*x4*x6 + 2* x5*x6 + 8*x6^2 + 8*x6*x7 + 6*x6*x8 - x6 - 6*x7*x8,
	   -2*x1*x4 + 2*x1*x7 - 2*x2*x5 + 2*x2*x7 - 2*x3*x6 + 2*x3*x7 + 2*x4*x7 + 2* x5*x7 + 8*x6*x7 - 6*x6*x8 + 8*x7^2 + 6*x7*x8 - x7,
	   -6*x4*x5 + 6*x4*x8 + 6*x5*x8 - 6*x6*x7 + 6*x6*x8 + 6*x7*x8 + 8*x8^2 - x8)
G1 = elapsedTime gb I1;
R2 = kk[x1,x2,x3,x4,x5,x6,x7,x8];
I2 = sub(I1, R2);
G2 = elapsedTime fglm(I2, R1);

-- chemkin
-- gb: 5916.76
-- fglm: 4.46076
restart
needsPackage "FGLM"
kk = ZZ/32003
R1 = kk[w,x3,x4,y2,y3,y4,y5,z2,z3,z4,z5, MonomialOrder=>Lex]
I1 = ideal(-4*w*y2 + 9*y2^2 + z2,
           x3^2 + y3^2 + z3^2 - 1,
           x4^2 + y4^2 + z4^2 - 1,
           9*y5^2 + 9*z5^2 - 8,
           -6*w*x3*y2 + 3*x3 + 3*y2*y3 + 3*z2*z3 - 1,
           3*x3*x4 + 3*y3*y4 + 3*z3*z4 - 1,
           x4 + 3*y4*y5 + 3*z4*z5 - 1,
           -6*w + 3*x3 + 3*x4 + 8,
           9*y2 + 9*y3 + 9*y4 + 9*y5 + 8,
           z2 + z3 + z4 + z5,
           w^2 - 2)
G1 = elapsedTime gb I1
R2 = kk[w,x3,x4,y2,y3,y4,y5,z2,z3,z4,z5]
I2 = sub(I1, R2)
G2 = elapsedTime fglm(I2, R1)

-- MES test
restart
needsPackage "FGLM"
kk = ZZ/32003
A = random(kk^3, kk^10)
(P,L,U) = LUdecomposition A
  Q = id_(target A) _ P
  Q*L*U == A

A = random(kk^10, kk^3)
(P,L,U) = LUdecomposition A
  Q = id_(target A) _ P
  Q*L*U == A

A = matrix"0,0,0,1;0,1,0,1;0,0,1,1" **kk
(P,L,U) = LUdecomposition A
  Q = id_(target A) _ P
  Q*L*U == A

A = transpose matrix"0,0,0,1;0,1,0,1;0,0,1,1" **kk
(P,L,U) = LUdecomposition A
  Q = id_(target A) _ P
  Q*L*U == A

A = transpose matrix"0,0,0,1;0,1,0,1;0,0,1,1" ** QQ
(P,L,U) = LUdecomposition A
  Q = id_(target A) _ P
  Q*L*U == A

A = transpose matrix"0,0,0,1;0,1,0,1;0,0,1,1" ** RR
(P,L,U) = LUdecomposition A
  Q = id_(target A) _ P
  Q*L*U == A
