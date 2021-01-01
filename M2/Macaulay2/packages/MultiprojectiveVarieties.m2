
-*
   Copyright 2020, Giovanni Staglianò.

   You may redistribute this file under the terms of the GNU General Public
   License as published by the Free Software Foundation, either version 2 of
   the License, or any later version.
*-

if version#"VERSION" < "1.17" then error "this package requires Macaulay2 version 1.17 or newer";

newPackage(
    "MultiprojectiveVarieties",
    Version => "0.1", 
    Date => "January 1, 2021",
    Authors => {{Name => "Giovanni Staglianò", Email => "giovannistagliano@gmail.com"}},
    Headline => "multi-projective varieties",
    Keywords => {"Projective Algebraic Geometry"},
    PackageImports => {"PrimaryDecomposition", "Cremona"},
    PackageExports => {"Cremona"},
    DebuggingMode => false,
    Reload => false
)

export{"MultiprojectiveVariety", "projectiveVariety", "Saturate", "projections", "fiberProduct", "Probabilistic"}

debug Cremona;

MultiprojectiveVariety = new Type of MutableHashTable;

globalAssignment MultiprojectiveVariety;

MultiprojectiveVariety.synonym = "projective variety";

projectiveVariety = method(TypicalValue => MultiprojectiveVariety, Options => {MinimalGenerators => true, Saturate => true});

projectiveVariety Ideal := o -> I -> (
    R := ring I;
    if not isPolynomialRing R then error "expected an ideal in a polynomial ring";
    if not isField coefficientRing R then error "the coefficient ring needs to be a field";
    m := multigens R;
    if flatten m != gens R then error "the given grading on the polynomial ring is not allowed: the degree of each variable must be a standard basis vector of ZZ^r in the commonly used order";
    if not isHomogeneous I then error "expected a (multi)-homogeneous ideal";
    if o.Saturate 
    then for x in m do I = saturate(I,ideal x,MinimalGenerators=>o.MinimalGenerators)
    else if o.MinimalGenerators then I = trim I;
    new MultiprojectiveVariety from {
        "idealVariety" => I,
        "ringVariety" => null,
        "dimVariety" => null,        
        "dimAmbientSpaces" => apply(m, n -> (#n)-1),
        "multigens" => m,
        "multidegree" => null,
        "ambient" => null,
        "top" => null,
        "singularLocus" => null,
        "segreMap" => null,
        "flattenMap" => null,
        "projections" => null,
        "euler" => null
    }
);

projectiveVariety Ring := o -> R -> (
    if not isPolynomialRing ambient R then error "expected the ambient ring to be polynomial";
    X := projectiveVariety(ideal R,MinimalGenerators=>false,Saturate=>false);
    I := X#"idealVariety";
    m := X#"multigens";
    if o.Saturate then (
        for x in m do I = saturate(I,ideal x,MinimalGenerators=>o.MinimalGenerators);
        if I != X#"idealVariety" then error "the ideal is not multisaturated";
    );
    X#"ringVariety" = R;
    X
);

expression MultiprojectiveVariety := X -> expression expressionVar(dim X,X#"dimAmbientSpaces");

hasAttribute = value Core#"private dictionary"#"hasAttribute"
getAttribute = value Core#"private dictionary"#"getAttribute"
ReverseDictionary = value Core#"private dictionary"#"ReverseDictionary"

net MultiprojectiveVariety := X -> (
   if hasAttribute(X,ReverseDictionary) then toString getAttribute(X,ReverseDictionary) else "ProjectiveVariety"
);

MultiprojectiveVariety#{Standard,AfterPrint} = MultiprojectiveVariety#{Standard,AfterNoPrint} = X -> (
  << endl << concatenate(interpreterDepth:"o") << lineNumber << " : " << "ProjectiveVariety, " << expression X << endl;
);

ideal MultiprojectiveVariety := X -> X#"idealVariety";

ring MultiprojectiveVariety := X -> (
    if X#"ringVariety" =!= null then return X#"ringVariety";
    X#"ringVariety" = (ring ideal X)/(ideal X)
);

coefficientRing MultiprojectiveVariety := X -> coefficientRing ring ideal X;

ambient MultiprojectiveVariety := X -> (
    if X#"ambient" =!= null then return X#"ambient";
    ambX := if ideal X == 0 then X else projectiveVariety ideal ring ideal X;
    X#"ambient" = ambX
);

dim MultiprojectiveVariety := X -> (
    if X#"dimVariety" =!= null then return X#"dimVariety";
    R := ring ideal X;
    I := ideal X;
    X#"dimVariety" = max(dim I - (# heft R),-1)
);

codim MultiprojectiveVariety := {} >> o -> X -> sum(X#"dimAmbientSpaces") - (dim X);

multidegree MultiprojectiveVariety := X -> (
    if X#"multidegree" =!= null then return X#"multidegree";
    X#"multidegree" = multidegree ideal X
);

degree MultiprojectiveVariety := X -> getMultidegree(multidegree X, X#"dimAmbientSpaces");

projections = method();
projections MultiprojectiveVariety := X -> (
    if X#"projections" =!= null then return X#"projections";
    X#"projections" = apply(X#"multigens",x -> rationalMap sub(matrix{x},ring X))
);

segre MultiprojectiveVariety := X -> (
    if X#"segreMap" =!= null then return X#"segreMap";
    X#"segreMap" = segre ring X
);

describe MultiprojectiveVariety := X -> (
    n := X#"dimAmbientSpaces";
    amb := "empty space";
    if # n >= 1 and min n >= 0 then (
        amb = "PP^"|toString(n_0);
        for i from 1 to #n-1 do amb = amb | " x PP^" | toString(n_i);
    );
    s := "ambient:.............. "|toString(amb)|newline;
    s = s|"dim:.................. "|toString(dim X);
    if dim X == -1 then return s;
    s = s|newline|"codim:................ "|toString(codim X)|newline;
    s = s|"degree:............... "|toString(degree X);
    if codim X == 0 then return s; 
    s = s|newline;
    if # n > 1 then s = s|"multidegree:.......... "|toString(multidegree X)|newline;        
    s = s|"generators:........... "|toString((concatenate for l in degrees X list (toString unsequence toSequence first l)|"^"|(toString(last l)|" ")))|newline;
    purity := X == top X;
    s = s|"purity:............... "|toString(purity); 
    if purity then (
        s = s|newline|"dim sing. l.:......... "|toString(dim singularLocus X); 
        if dim singularLocus X >= 0 then s = s|newline|"gens sing. l.:........ "|toString((concatenate for l in degrees singularLocus X list (toString unsequence toSequence first l)|"^"|(toString(last l)|" ")));
    );
    if # n > 1 then (
        s = s|newline|"Segre embedding:...... "|"map to PP^"|toString(numgens target segre X -1); 
        N := product apply(n, i -> i+1) -1;
        if numgens target segre X -1 < N then s = s|" ⊂ PP^"|toString(N);
    );
    return s;
);

degrees MultiprojectiveVariety := X -> pairs tally degrees ideal X;

singularLocus MultiprojectiveVariety := X -> ( -- assume equidimensionality: X == top X
    if X#"singularLocus" =!= null then return X#"singularLocus";
    if X#"top" =!= null then if X =!= top X then error "expected an equidimensional projective variety";
    I := ideal X;
    X#"singularLocus" = projectiveVariety(I + minors(codim X,jacobian I,Strategy=>Cofactor),MinimalGenerators=>true,Saturate=>true)
);

top MultiprojectiveVariety := X -> (
    if X#"top" =!= null then return X#"top";
    T := top ideal X;
    X#"top" = if T == ideal X then X else projectiveVariety(T,MinimalGenerators=>true,Saturate=>false)
);

MultiprojectiveVariety == MultiprojectiveVariety := (X,Y) -> (
    if ring ideal X =!= ring ideal Y then error "expected varieties in the same ambient";
    if X === Y or ideal X === ideal Y then return true;
    if dim X != dim Y then return false;
    ideal X == ideal Y
);

flattenMap = method(); 
flattenMap MultiprojectiveVariety := X -> (
    if X#"flattenMap" =!= null then return X#"flattenMap";
    ttt := local ttt;
    X#"flattenMap" = parametrizeProductOfProjectiveSpaces(ring ideal X,ttt)
);

point (MultiprojectiveVariety,Boolean) := (X,b) -> (
    if # X#"dimAmbientSpaces" == 1 then return projectiveVariety(point(ideal X,b),MinimalGenerators=>false,Saturate=>false);
    f := flattenMap X;
    j := (map parametrize point f ideal X) * f;
    p := projectiveVariety sum(projections ambient X,g -> g^* kernel(j * (map g)));
    if b then if not (dim p == 0 and degree p == 1 and isSubset(ideal X,ideal p)) then error("something went wrong in trying to pick a random "|toString(coefficientRing X)|"-rational point on the variety");
    return p;
);
point MultiprojectiveVariety := X -> point(X,true);

MultiprojectiveVariety ** MultiprojectiveVariety := (X,Y) -> (
    K := coefficientRing X;
    if K =!= coefficientRing Y then error "different coefficient rings encountered";
    d := matrix degrees ring ideal X;
    e := matrix degrees ring ideal Y;
    de := (d | matrix pack(numColumns e,apply(numRows d * numColumns e,i->0))) || (matrix pack(numColumns d,apply(numRows e * numColumns d,j->0)) | e);
    x := local x; y := local y;
    n := X#"dimAmbientSpaces"; m := Y#"dimAmbientSpaces";
    R := K[x_0..x_(#n + sum n - 1),y_0..y_(#m + sum m - 1),Degrees=>entries de]; 
    sX := map(R,ring ideal X,submatrix(vars R,0 .. #n + sum n - 1));
    sY := map(R,ring ideal Y,submatrix'(vars R,0 .. #n + sum n - 1));
    XxY := projectiveVariety((sX ideal X) + (sY ideal Y),MinimalGenerators=>true,Saturate=>false);
    XxY#"projections" = apply(projections XxY,apply((projections X)|(projections Y),target),(f,T) -> rationalMap((map f) * (map rationalMap(target f,T)),Dominant=>"notSimplify"));
    XxY
);

MultiprojectiveVariety + MultiprojectiveVariety := (X,Y) -> (
    if ring ideal X =!= ring ideal Y then error "expected varieties in the same ambient";
    projectiveVariety(intersect(ideal X,ideal Y),MinimalGenerators=>true,Saturate=>false)
);

MultiprojectiveVariety - MultiprojectiveVariety := (X,Y) -> (
    if ring ideal X =!= ring ideal Y then error "expected varieties in the same ambient";
    projectiveVariety(quotient(ideal X,ideal Y,MinimalGenerators=>true),MinimalGenerators=>false,Saturate=>false)
);

MultiprojectiveVariety * MultiprojectiveVariety := (X,Y) -> (
    if ring ideal X =!= ring ideal Y then error "expected varieties in the same ambient";
    projectiveVariety(ideal X + ideal Y,MinimalGenerators=>true,Saturate=>true)
);

isSubset (MultiprojectiveVariety,MultiprojectiveVariety) := (X,Y) -> (
    if ring ideal X =!= ring ideal Y then error "expected varieties in the same ambient";
    isSubset(ideal Y,ideal X)
);

fiberProductInt = method();
fiberProductInt (MutableHashTable,MutableHashTable) := (phi,psi) -> (
    if target phi =!= target psi then error "expected two morphisms with the same target";
    if not isMorphism phi then <<"--warning: the first map is not a morphism"<<endl;
    if not isMorphism psi then <<"--warning: the second map is not a morphism"<<endl;
    ambX := projectiveVariety ambient source phi;
    ambY := projectiveVariety ambient source psi;
    ambXxY := ambX ** ambY;
    R := ring ambXxY;
    n := numgens ring ambX -1;    
    sx := map(R,ring ambX,submatrix(vars R,{0..n}));
    sy := map(R,ring ambY,submatrix'(vars R,{0..n}));
    I := sx ideal source phi;
    J := sy ideal source psi;
    F := apply(maps phi,f -> sx lift(toMatrix f,ring ambX));
    G := apply(maps psi,g -> sy lift(toMatrix g,ring ambY));
    Z := projectiveVariety(I + J + intersect flatten for f in F list for g in G list saturate(saturate(minors(2,f||g),ideal f),ideal g),MinimalGenerators=>true,Saturate=>true); 
    Z#"projections" = apply(projections Z,projections ambXxY,(f,g) -> rationalMap((map f) * (map rationalMap(target f,target g)),Dominant=>"notSimplify"));
    Z
);

fiberProduct = method(TypicalValue => MultiprojectiveVariety);
fiberProduct (MultihomogeneousRationalMap,MultihomogeneousRationalMap) := (phi,psi) -> fiberProductInt(phi,psi);
fiberProduct (MultihomogeneousRationalMap,RationalMap) := (phi,psi) -> fiberProductInt(phi,psi);
fiberProduct (RationalMap,MultihomogeneousRationalMap) := (phi,psi) -> fiberProductInt(phi,psi);
fiberProduct (RationalMap,RationalMap) := (phi,psi) -> fiberProductInt(phi,psi);

euler (MultiprojectiveVariety,Option) := (X,opt) -> (
    o := toList opt;
    if not(#o == 2 and first o === Probabilistic) then error "Probabilistic is the only available option for euler(MultiprojectiveVariety)";
    if not instance(last o,Boolean) then error "option Probabilistic accepts true or false";
    if X#"euler" =!= null then return X#"euler";
    local e;
    if # X#"dimAmbientSpaces" == 1 then (
        if codim X == 0 then return X#"euler" = numgens ring X;
        e = EulerCharacteristic(ideal X,MathMode=>not last o,Verbose=>false);
     ) else (
        <<"--warning: code to be improved"<<endl;
        e = EulerCharacteristic(image segre X,MathMode=>not last o,Verbose=>false);
    );
    if not last o then X#"euler" = e;
    return e;
);

euler MultiprojectiveVariety := X -> euler(X,Probabilistic=>true);


beginDocumentation() 

document {Key => {MultiprojectiveVarieties}, 
Headline => "Multi-projective varieties",
PARA{"This is a work in progress package to handling multi-projective varieties, that is, closed subvarieties of products of projective spaces. The aim is to provide a better support for the package ",TO Cremona,", which treats ",TO2{RationalMap,"rational maps"}," from multi-projective varieties to projective varieties. In the future, for instance, the source of a rational map ",TEX///$\Phi:X\subseteq \mathbb{P}^{k_1}\times\mathbb{P}^{k_2}\times\cdots\times\mathbb{P}^{k_n}\dashrightarrow Y\subseteq\mathbb{P}^N$///," will be the ",TO2{MultiprojectiveVariety,"multi-projective variety"}," ",TEX///$X$///," and not, as it currently is, the coordinate ring of ",TEX///$X$///,"; see ",TO (source,RationalMap),". Also ",TO2{(symbol ^**,RationalMap,Ideal),"inverse images"}," and ",TO2{(symbol _*,RationalMap),"direct images"}," of subvarieties via rational maps will look more intuitive."}
}

document {Key => {MultiprojectiveVariety}, 
Headline => "the class of all multi-projective varieties", 
PARA {"A multi-projective variety is a closed subvariety of a product of projective spaces ",TEX///$\mathbb{P}^{k_1}\times\mathbb{P}^{k_2}\times\cdots\times\mathbb{P}^{k_n}$///,"."}}

document { 
Key => {projectiveVariety, (projectiveVariety,Ideal), (projectiveVariety,Ring), [projectiveVariety,Saturate], [projectiveVariety,MinimalGenerators]}, 
Headline => "the closed multi-projective subvariety defined by a multi-homogeneous ideal", 
Usage => "projectiveVariety I", 
Inputs => { "I" => Ideal => {"a homogeneous ideal in a polynomial ring ",TEX///$R$///," with the ",TEX///$\mathbb{Z}^n$///,"-grading where the degree of each variable is a standard basis vector, that is, ",TEX///$R$///," is the homogeneous coordinate ring of a product of ",TEX///$n$///," projective spaces ",TEX///$\mathbb{P}^{k_1}\times\mathbb{P}^{k_2}\times\cdots\times\mathbb{P}^{k_n}$///}},
Outputs => {MultiprojectiveVariety => {"the projective subvariety of ",TEX///$\mathbb{P}^{k_1}\times\mathbb{P}^{k_2}\times\cdots\times\mathbb{P}^{k_n}$///," defined by ",TEX///$I$///}},
PARA{"Equivalently, one can give as input the coordinate ring of the projective variety, that is, the quotient of ",TEX///$R$///," by (the multisaturation of) ",TEX///$I$///,"."}, 
PARA{"In the example, we take a complete intersection ",TEX///$X\subset\mathbb{P}^{2}\times\mathbb{P}^{3}\times\mathbb{P}^{1}$///," of two hypersurfaces of multidegrees ",TEX///$(2,1,0)$///," and ",TEX///$(1,0,1)$///,"."},
EXAMPLE {
"K = ZZ/333331;", 
"R = K[x_0..x_2,y_0..y_3,z_0,z_1,Degrees=>{3:{1,0,0},4:{0,1,0},2:{0,0,1}}];",
"I = ideal(random({2,1,0},R),random({1,0,1},R))",
"X = projectiveVariety I",
"describe X"
},
PARA{"Below, we calculate the image of ",TEX///$X$///," via the Segre embedding of ",TEX///$\mathbb{P}^{2}\times\mathbb{P}^{3}\times\mathbb{P}^{1}$///," in ",TEX///$\mathbb{P}^{23}$///,"; thus we get a projective variety isomorphic to ",TEX///$X$///," and embedded in a single projective space ",TEX///$\mathbb{P}^{19}=<X>\subset\mathbb{P}^{23}$///,"."},
EXAMPLE {
"s = segre X;",
"X' = projectiveVariety image s",
"(dim X', codim X', degree X')",
"degrees X'"
},
SeeAlso => {(segre,MultiprojectiveVariety),(dim,MultiprojectiveVariety),(codim,MultiprojectiveVariety),(degree,MultiprojectiveVariety),(singularLocus,MultiprojectiveVariety)}} 

undocumented {Saturate};

document {Key => {(dim,MultiprojectiveVariety)}, 
Headline => "the dimension of the variety", 
Usage => "dim X", 
Inputs => {"X" => MultiprojectiveVariety}, 
Outputs => {ZZ => {"the dimension of ", TEX///$X$///}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","dim X"}, 
SeeAlso => {(codim,MultiprojectiveVariety)}} 

document {Key => {(codim,MultiprojectiveVariety)}, 
Headline => "the codimension of the variety", 
Usage => "codim X", 
Inputs => {"X" => MultiprojectiveVariety}, 
Outputs => { ZZ => {"the codimension of ", TEX///$X$///}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","codim X"}, 
SeeAlso => {(dim,MultiprojectiveVariety)}} 

document {Key => {(ideal,MultiprojectiveVariety)}, 
Headline => "the defining ideal of the variety", 
Usage => "ideal X", 
Inputs => {"X" => MultiprojectiveVariety}, 
Outputs => {Ideal => {"the defining ideal of ", TEX///$X$///}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","ideal X"}, 
SeeAlso => {(ring,MultiprojectiveVariety)}} 

document {Key => {(ring,MultiprojectiveVariety)}, 
Headline => "the coordinate ring of the variety", 
Usage => "ring X", 
Inputs => {"X" => MultiprojectiveVariety}, 
Outputs => {Ring => {"the coordinate ring of ", TEX///$X$///}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","ring X"}, 
SeeAlso => {(ideal,MultiprojectiveVariety),(coefficientRing,MultiprojectiveVariety)}} 

document {Key => {(coefficientRing,MultiprojectiveVariety)}, 
Headline => "the coefficient ring of the variety", 
Usage => "coefficientRing X", 
Inputs => {"X" => MultiprojectiveVariety}, 
Outputs => {Ring => {"the coefficient ring of ", TEX///$X$///}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","coefficientRing X"}, 
SeeAlso => {(ring,MultiprojectiveVariety)}} 

document {Key => {(degree,MultiprojectiveVariety)}, 
Headline => "the degree of the variety", 
Usage => "degree X", 
Inputs => {"X" => MultiprojectiveVariety}, 
Outputs => { ZZ => {"the degree of the image of ", TEX///$X$///," via the Segre embedding of the ",TO2{(ambient,MultiprojectiveVariety),"ambient"}," of ",TEX///$X$///}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","degree X"}, 
SeeAlso => {(multidegree,MultiprojectiveVariety),(segre,MultiprojectiveVariety)}} 

document {Key => {projections,(projections,MultiprojectiveVariety)}, 
Headline => "projections of a multi-projective variety", 
Usage => "projections X", 
Inputs => {"X" => MultiprojectiveVariety => {"a subvariety of ",TEX///$\mathbb{P}^{k_1}\times\mathbb{P}^{k_2}\times\cdots\times\mathbb{P}^{k_n}$///}}, 
Outputs => {{"the list of the projections ", TEX///$X\to \mathbb{P}^{k_i}$///,", for ",TEX///$i=1,\ldots,n$///}}, 
EXAMPLE {"X = projectiveVariety(ZZ/101[x_0..x_3]) ** projectiveVariety(ZZ/101[y_0..y_2]);","projections X"}} 

document {Key => {(ambient,MultiprojectiveVariety)}, 
Headline => "the ambient of the variety", 
Usage => "ambient X", 
Inputs => {"X" => MultiprojectiveVariety}, 
Outputs => { MultiprojectiveVariety => {"the product of the projective spaces where ", TEX///$X$///," is embedded"}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","ambient X;"}} 

document {Key => {(multidegree,MultiprojectiveVariety)}, 
Headline => "the multidegree of the variety", 
Usage => "multidegree X", 
Inputs => {"X" => MultiprojectiveVariety}, 
Outputs => {{"the multi-degree of the defining ideal of ", TEX///$X$///}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","multidegree X"}, 
SeeAlso => {(degree,MultiprojectiveVariety),(multidegree,Ideal)}} 

document {Key => {(segre,MultiprojectiveVariety)}, 
Headline => "the Segre embedding of the variety", 
Usage => "segre X", 
Inputs => {"X" => MultiprojectiveVariety}, 
Outputs => {{"the map returned by ",TO segre," ",TO2{(ring,MultiprojectiveVariety),"ring"}," ", TEX///$X$///}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","segre X"}, 
SeeAlso => {segre}}

document {Key => {(point,MultiprojectiveVariety)}, 
Headline => "pick a random rational point on a projective variety", 
Usage => "ideal point X", 
Inputs => {"X" => MultiprojectiveVariety => {"defined over a finite field"}}, 
Outputs => {{ofClass MultiprojectiveVariety,", a random rational point on ", TEX///$X$///}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","ideal point X"},
SeeAlso => {point,randomKRationalPoint}} 

document {Key => {(singularLocus,MultiprojectiveVariety)}, 
Headline => "the singular locus of the variety", 
Usage => "singularLocus X", 
Inputs => {"X" => MultiprojectiveVariety => {"which is assumed to be equidimensional"}}, 
Outputs => { MultiprojectiveVariety => {"the singular locus of ", TEX///$X$///}}, 
EXAMPLE {"X = projectiveVariety ideal random({2,1},ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}]);","singularLocus X;","Y = projectiveVariety intersect(ideal X,ideal random({1,1},ring ambient X));","singularLocus Y;"}} 

document {Key => {(symbol ==,MultiprojectiveVariety,MultiprojectiveVariety)}, 
Headline => "equality of projective varieties", 
Usage => "X == Y", 
Inputs => { 
MultiprojectiveVariety => "X",
MultiprojectiveVariety => "Y"}, 
Outputs => { 
Boolean => {"whether ",TT"X"," and ",TT"Y", " are the same variety"}},
EXAMPLE {
"R = ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}];",
"(I,J) = (ideal(y_0-26*y_1,x_0*y_1+36*x_1*y_1-40*x_2*y_1),ideal(x_0*y_1+36*x_1*y_1-40*x_2*y_1,x_2*y_0-26*x_2*y_1,x_1*y_0-26*x_1*y_1,x_0*y_0+27*x_1*y_1-30*x_2*y_1));",
"I == J",
"X = projectiveVariety I",
"Y = projectiveVariety J",
"X == Y"}}

document {Key => {(isSubset,MultiprojectiveVariety,MultiprojectiveVariety)}, 
Headline => "whether one variety is a subvariety of another", 
Usage => "isSubset(X,Y)", 
Inputs => { 
MultiprojectiveVariety => "X",
MultiprojectiveVariety => "Y"}, 
Outputs => { 
Boolean => {"whether ",TT"X"," is contained in ",TT"Y"}}}

document {Key => {(symbol **,MultiprojectiveVariety,MultiprojectiveVariety)}, 
Headline => "product of projective varieties", 
Usage => "X ** Y", 
Inputs => { 
MultiprojectiveVariety => "X",
MultiprojectiveVariety => "Y"}, 
Outputs => { 
MultiprojectiveVariety => {"the product of ",TT"X"," and ",TT"Y"}},
EXAMPLE {"R = ZZ/101[x_0..x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}];",
"S = ZZ/101[x_0,x_1,y_0..y_2,z_0,z_1,Degrees=>{2:{1,0,0},3:{0,1,0},2:{0,0,1}}];",
"X = projectiveVariety ideal(random({2,1},R),random({1,1},R));", 
"Y = projectiveVariety ideal random({1,1,1},S);",
"XxY = X ** Y;",
"describe X",
"describe Y",
"describe XxY"},
SeeAlso => {fiberProduct}}

document {Key => {(symbol *,MultiprojectiveVariety,MultiprojectiveVariety)}, 
Headline => "intersection of projective varieties", 
Usage => "X * Y", 
Inputs => { 
MultiprojectiveVariety => "X",
MultiprojectiveVariety => "Y"}, 
Outputs => { 
MultiprojectiveVariety => {"the intersection of ",TT"X"," and ",TT"Y",", that is, the projective variety defined by the sum of the corresponding ideals"}},
EXAMPLE {"R = ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}];",
"X = projectiveVariety ideal random({2,1},R);",
"Y = projectiveVariety ideal random({1,1},R);", 
"Z = X * Y;"},
SeeAlso => {(symbol +,MultiprojectiveVariety,MultiprojectiveVariety),(symbol +,Ideal,Ideal)}}

document {Key => {(symbol +,MultiprojectiveVariety,MultiprojectiveVariety)}, 
Headline => "union of projective varieties", 
Usage => "X + Y", 
Inputs => { 
MultiprojectiveVariety => "X",
MultiprojectiveVariety => "Y"}, 
Outputs => { 
MultiprojectiveVariety => {"the union of ",TT"X"," and ",TT"Y",", that is, the projective variety defined by the intersection of the corresponding ideals"}},
EXAMPLE {"R = ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}];",
"X = projectiveVariety ideal random({2,1},R);",
"Y = projectiveVariety ideal random({1,1},R);", 
"Z = X + Y;",
"assert(Z - X == Y and Z - Y == X)"},
SeeAlso => {(symbol -,MultiprojectiveVariety,MultiprojectiveVariety),(symbol *,MultiprojectiveVariety,MultiprojectiveVariety),(intersect,List)}}

document {Key => {(symbol -,MultiprojectiveVariety,MultiprojectiveVariety)}, 
Headline => "difference of projective varieties", 
Usage => "X - Y", 
Inputs => { 
MultiprojectiveVariety => "X",
MultiprojectiveVariety => "Y"}, 
Outputs => { 
MultiprojectiveVariety => {"the difference of ",TT"X"," and ",TT"Y",", that is, the projective variety defined by the colon ideal ",TT"ideal X : ideal Y"}},
EXAMPLE {"R = ZZ/101[x_0,x_1,x_2,y_0,y_1,Degrees=>{3:{1,0},2:{0,1}}];",
"X = projectiveVariety ideal(x_0^3*y_0+2*x_0^2*x_1*y_0+2*x_0*x_1^2*y_0+x_1^3*y_0+2*x_0^2*x_2*y_0+3*x_0*x_1*x_2*y_0+2*x_1^2*x_2*y_0+2*x_0*x_2^2*y_0+2*x_1*x_2^2*y_0+x_2^3*y_0+x_0^3*y_1+2*x_0^2*x_1*y_1+2*x_0*x_1^2*y_1+x_1^3*y_1+2*x_0^2*x_2*y_1+3*x_0*x_1*x_2*y_1+2*x_1^2*x_2*y_1+2*x_0*x_2^2*y_1+2*x_1*x_2^2*y_1+x_2^3*y_1);",
"Y = projectiveVariety ideal(x_0*y_0+x_1*y_0+x_2*y_0+x_0*y_1+x_1*y_1+x_2*y_1);", 
"Z = X - Y;",
"assert(Z + Y == X and X - Z == Y)"},
SeeAlso => {(symbol +,MultiprojectiveVariety,MultiprojectiveVariety),(quotient,Ideal,Ideal)}}

undocumented {(expression,MultiprojectiveVariety), (net,MultiprojectiveVariety), (point,MultiprojectiveVariety,Boolean), (top,MultiprojectiveVariety), (describe,MultiprojectiveVariety),(degrees,MultiprojectiveVariety)}

document {Key => {fiberProduct,(fiberProduct,RationalMap,RationalMap)}, 
Headline => "fiber product of projective varieties", 
Usage => "fiberProduct(phi,psi)", 
Inputs => { 
"phi" => {"a ",TO2{RationalMap,"morphism"}," ",TEX///$X\to Z$///," (that is, ",ofClass RationalMap," that is everywhere defined)"},
"psi" => {"another ",TO2{RationalMap,"morphism"}," ",TEX///$Y\to Z$///,", with the same target ",TEX///$Z$///}}, 
Outputs => { 
MultiprojectiveVariety => {"the fiber product ",TEX///$X\times_{Z} Y$///}},
PARA {"The natural morphisms ",TEX///$X\times_{Z} Y\to X$///," and ",TEX///$X\times_{Z} Y\to Y$///," can be obtained using ",TO projections,"."},
PARA {"As an example, we calculate the fiber product of the blowing up ",TEX///$\phi:Bl_{C}(\mathbb{P}^3)\to\mathbb{P}^3$///," of ",TEX///$\mathbb{P}^3$///," along a twisted cubic curve ",TEX///$C\subset\mathbb{P}^3$///," and the inclusion ",TEX///$\psi:L\to \PP^3$///," of a secant line ",TEX///$L\subset\mathbb{P}^3$///," to ",TEX///$C$///,"."},
EXAMPLE {
"ringP3 = ZZ/33331[a..d]; C = ideal(c^2-b*d,b*c-a*d,b^2-a*c), L = ideal(b+c+d,a-d)", 
"phi = first graph rationalMap C;",
"psi = parametrize L;",
"F = fiberProduct(phi,psi);",
"describe F"},
SeeAlso => {(symbol **,MultiprojectiveVariety,MultiprojectiveVariety)}}

document { 
Key => {(euler,MultiprojectiveVariety)}, 
Headline => "topological Euler characteristic of a (smooth) projective variety", 
Usage => "euler X
euler(X,Probabilistic=>b)", 
Inputs => { 
MultiprojectiveVariety => "X" => {"which has to be smooth, and ",TT"b"," is a ",TO2{Boolean,"boolean value"},", that is, ",TT"true"," or ",TT"false"," (the default value is ",TT"true",")"}}, 
Outputs => { 
ZZ => {"the topological Euler characteristics of the variety ",TT"X",", calculated as ",TO EulerCharacteristic,TT"(ideal X,MathMode=>(not b))"}},
EXAMPLE {
"X = projectiveVariety minors(2,genericSymmetricMatrix(ZZ/33331[vars(0..5)],3));",
"euler X"},
SeeAlso => {EulerCharacteristic,(euler,ProjectiveVariety)}}

undocumented {(euler,MultiprojectiveVariety,Option),Probabilistic}

