// Copyright 2014-2016 Michael E. Stillman

#include "res-f4.hpp"
#include "res-gausser.hpp"
#include "res-schreyer-frame.hpp"
#include "monoid.hpp"
#include "ntuple.hpp"
#include "memtailor.h"
#include "text-io.hpp"

#include <iostream>
#include <ctime>
#include <algorithm>
#include "../timing.hpp"

F4Res::F4Res(SchreyerFrame& res)
    : mFrame(res),
      mRing(res.ring()),
      mSchreyerRes(new ResMonomialsWithComponent(res.ring().monoid())),
      mHashTable(mSchreyerRes.get(), 10)
{
}

F4Res::~F4Res()
{
  // Nothing to free here.
}

void F4Res::resetMatrix(int lev, int degree)
{
  mThisLevel = lev;
  mThisDegree = degree;
  mNextReducerToProcess = 0;

  // mNextMonom[-1] is the reducer corresponding to this monomial
  mNextMonom = mMonomSpace.reserve(1 + monoid().max_monomial_size());
  mNextMonom++;
}

void F4Res::clearMatrix()
{
  mThisLevel = -1;
  mThisDegree = -1;
  mNextReducerToProcess = 0;
  mNextMonom = nullptr;

  auto timeA = timer();
  mHashTable.reset();
  auto timeB = timer();
  mFrame.timeResetHashTable += seconds(timeB - timeA);

  for (auto& f : mReducers)
    {
      mRing.resGausser().deallocate(f.mCoeffs);
    }

  for (auto& f : mSPairs)
    {
      mRing.resGausser().deallocate(f.mCoeffs);
    }

  mReducers.clear();
  mSPairs.clear();
  mSPairComponents.clear();
  mColumns.clear();

  mMonomSpace.reset();
}

/// findDivisor
//    m: monomial at level mThisLevel-1
//    result: monomial at level mThisLevel, IF true is returned
//  returns true if 'm' == inG(result), for some (unique) 'result'.
bool F4Res::findDivisor(res_const_packed_monomial m, res_packed_monomial result)
{
  // get component of m
  // find the range of monomials to check
  // for each of these, check divisibility in turn
  //   if one works, then return true, and set result.
  long comp =
      monoid().get_component(m);  // component is an index into level mLevel-2
  auto& elem = mFrame.level(mThisLevel - 2)[comp];
  auto& lev = mFrame.level(mThisLevel - 1);
  for (auto j = elem.mBegin; j < elem.mEnd; ++j)
    {
      // Check divisibility of m by this element
      res_packed_monomial pj = lev[j].mMonom;
      if (monoid().divide(m, pj, result))  // this sets the component to be 0
        {
          monoid().set_component(j, result);  // this sets component correctly
          return true;
        }
    }
  return false;
}

// A monomial at level lev has the following form:
// m[-1] index of a divisor for this monomial, -1 if no divisor exists
//    this is only used for monomials being placed into the hash table...
// m[0] is a hash value
// m[1] is the component, an index into the lev-1 part of the frame.
// m[2] is the degree,
// m[3..3+#vars-1] is the monomial.
//   Is m[-1] always present

// processMonomialProduct
//     m is a monomial, component is ignored (it determined the possible n's
//     being used here)
//     n is a monomial at level 'mThisLevel-1'
//     compute their product, and return the column index of this product
//       or -1, if the monomial is not needed.
//     additionally: the product monomial is inserted into the hash table
//     and column array (if it is not already there).
// caveats: this function is only to be used during construction
//     of the coeff matrices.  It uses mThisLevel.
//
// If the ring has skew commuting variables, then result_sign_if_skew is set to
// 0, 1, or -1.
ComponentIndex F4Res::processMonomialProduct(res_const_packed_monomial m,
                                             res_const_packed_monomial n,
                                             int& result_sign_if_skew)
{
  result_sign_if_skew = 1;
  auto x = monoid().get_component(n);
  auto& p = mFrame.level(mThisLevel - 2)[x];
  if (p.mBegin == p.mEnd) return -1;

  monoid().unchecked_mult(m, n, mNextMonom);
  // the component is wrong, after this operation, as it adds components
  // So fix that:
  monoid().set_component(x, mNextMonom);

  if (ring().isSkewCommutative())
    {
      result_sign_if_skew = monoid().skew_mult_sign(ring().skewInfo(), m, n);
      if (result_sign_if_skew == 0) return -1;
    }
  return processCurrentMonomial();
}

// new_m is a monomial that we have just created.  There are several
// things that can happen:
//  (1) new_m is already in the hash table (as is).
//       i.e. we have already processed this monomial.
//       in this case new_m[-1] is the index of the divisor for this monomial
//       (possibly -1).
//  (2) new_m is a newly seen monomial in this degree.
//       insert it into the hash table as a seen monomial
//       we set the divisor for new_m: either -1 or some index
//       If there is no divisor, return -1.
//       If there is: create a row, and push onto the mReducers list.
//    (2A)
ComponentIndex F4Res::processCurrentMonomial()
{
  res_packed_monomial new_m;  // a pointer to a monomial we are visiting
  if (mHashTable.find_or_insert(mNextMonom, new_m))
    return static_cast<ComponentIndex>(
        new_m[-1]);  // monom exists, don't save monomial space

  // intern the monomial just inserted into the hash table
  mMonomSpace.intern(1 + monoid().monomial_size(mNextMonom));

  // leave room for the next monomial.  This might be set below.
  mNextMonom = mMonomSpace.reserve(1 + monoid().max_monomial_size());
  mNextMonom++;

  bool has_divisor = findDivisor(new_m, mNextMonom);
  if (!has_divisor)
    {
      new_m[-1] = -1;  // no divisor exists
      return -1;
    }

  mMonomSpace.intern(1 + monoid().monomial_size(mNextMonom));

  ComponentIndex thiscol = static_cast<ComponentIndex>(mColumns.size());
  new_m[-1] = thiscol;  // this is a HACK: where we keep the divisor
  mColumns.push_back(new_m);

  Row row;
  row.mLeadTerm = mNextMonom;
  mReducers.push_back(row);

  // Now we increment mNextMonom, for the next time
  mNextMonom = mMonomSpace.reserve(1 + monoid().max_monomial_size());
  mNextMonom++;

  return thiscol;
}
void F4Res::loadRow(Row& r)
{
  //  std::cout << "loadRow: " << std::endl;

  r.mCoeffs = resGausser().allocateCoefficientVector();

  //  monoid().showAlpha(r.mLeadTerm);
  //  std::cout << std::endl;
  int skew_sign;  // will be set to 1, unless ring().isSkewCommutative() is
                  // true, then it can be -1,0,1.
  // however, if it is 0, then "val" below will also be -1.
  long comp = monoid().get_component(r.mLeadTerm);
  auto& thiselement = mFrame.level(mThisLevel - 1)[comp];
  // std::cout << "  comp=" << comp << " mDegree=" << thiselement.mDegree << "
  // mThisDegree=" << mThisDegree << std::endl;
  if (thiselement.mDegree == mThisDegree)
    {
      // We only need to add in the current monomial
      // fprintf(stdout, "USING degree 0 monomial\n");
      ComponentIndex val =
          processMonomialProduct(r.mLeadTerm, thiselement.mMonom, skew_sign);
      if (val < 0) fprintf(stderr, "ERROR: expected monomial to live\n");
      r.mComponents.push_back(val);
      if (skew_sign > 0)
        mRing.resGausser().pushBackOne(r.mCoeffs);
      else
        {
          // Only happens if we are in a skew commuting ring.
          ring().resGausser().pushBackMinusOne(r.mCoeffs);
        }
      return;
    }
  auto& p = thiselement.mSyzygy;
  auto end = poly_iter(mRing, p, 1);
  auto i = poly_iter(mRing, p);
  for (; i != end; ++i)
    {
      ComponentIndex val =
          processMonomialProduct(r.mLeadTerm, i.monomial(), skew_sign);
      // std::cout << "  monom: " << val << " skewsign=" << skew_sign << "
      // mColumns.size=" << mColumns.size() << std::endl;
      if (val < 0) continue;
      r.mComponents.push_back(val);
      if (skew_sign > 0)
        mRing.resGausser().pushBackElement(
            r.mCoeffs, p.coeffs, i.coefficient_index());
      else
        {
          // Only happens if we are in a skew commuting ring.
          mRing.resGausser().pushBackNegatedElement(
              r.mCoeffs, p.coeffs, i.coefficient_index());
        }
    }
}

class ResColumnsSorter
{
 public:
  typedef ResMonoid::value monomial;
  typedef ComponentIndex value;

 private:
  const ResMonoid& M;
  const F4Res& mComputation;
  const std::vector<res_packed_monomial>& cols;
  int lev;
  const ResSchreyerOrder& myorder;
  //  const std::vector<SchreyerFrame::FrameElement>& myframe;

  static long ncmps;
  static long ncmps0;

 public:
#if 0
  int compare(value a, value b)
  {
    ncmps ++;
    fprintf(stdout, "ERROR: should not get here\n");
    //return M.compare_grevlex(cols[a],cols[b]);
    return 0;
  }
#endif

  bool operator()(value a, value b)
  {
    ncmps0++;
    long comp1 = M.get_component(cols[a]);
    long comp2 = M.get_component(cols[b]);
#if 0
    fprintf(stdout, "comp1 = %ld comp2 = %ld\n", comp1, comp2);

    printf("compare_schreyer: ");
    printf("  m=");
    M.showAlpha(cols[a]);
    printf("\n  n=");    
    M.showAlpha(cols[b]);
    printf("\n  m0=");    
    M.showAlpha(myorder.mTotalMonom[comp1]);
    printf("\n  n0=");    
    M.showAlpha(myorder.mTotalMonom[comp2]);
    printf("\n  tiebreakers: %ld %ld\n",  myorder.mTieBreaker[comp1], myorder.mTieBreaker[comp2]);
#endif

    bool result = (M.compare_schreyer(cols[a],
                                      cols[b],
                                      myorder.mTotalMonom[comp1],
                                      myorder.mTotalMonom[comp2],
                                      myorder.mTieBreaker[comp1],
                                      myorder.mTieBreaker[comp2]) == LT);
#if 0
    printf("result = %d\n", result);
#endif
    return result;
  }

  ResColumnsSorter(const ResMonoid& M0, const F4Res& comp, int lev0)
      : M(M0),
        mComputation(comp),
        cols(comp.mColumns),
        lev(lev0),
        myorder(comp.frame().schreyerOrder(lev0 - 1))
  {
    // printf("Creating a ResColumnsSorter with level = %ld, length = %ld\n",
    // lev, myframe.size());
  }

  long ncomparisons() const { return ncmps; }
  long ncomparisons0() const { return ncmps0; }
  void reset_ncomparisons()
  {
    ncmps0 = 0;
    ncmps = 0;
  }

  ~ResColumnsSorter() {}
};

static void applyPermutation(ComponentIndex* permutation,
                             std::vector<ComponentIndex>& entries)
{
  // TODO: permutation should be a std::vector too,
  // and we should check the values of the permutation.
  for (ComponentIndex i = 0; i < entries.size(); i++)
    entries[i] = permutation[entries[i]];

  // The next is just a consistency check, that maybe can be removed later.
  for (ComponentIndex i = 1; i < entries.size(); i++)
    {
      if (entries[i] <= entries[i - 1])
        {
          fprintf(stderr, "Internal error: array out of order\n");
          break;
        }
    }
}

long ResColumnsSorter::ncmps = 0;
long ResColumnsSorter::ncmps0 = 0;

class ResColumnSorterObject
{
private:
  const Monoid& mMonoid;
  const std::vector<int*> mMonoms;
public:
  ResColumnSorterObject(const Monoid& M, const std::vector<int*> monoms) : mMonoid(M), mMonoms(monoms) {}
  
  bool operator()(int a, int b)
  {
    // implements < function.  In fact, a and b should not refer to objects that are == under this order.
    // should we flag that?

    bool result = false;
    const int* m = mMonoms[a];
    const int* n = mMonoms[b];
    // TODO: make sure this is the order we want!!
    int cmp = mMonoid.compare(m+2, m[1], n+2, n[1]);
    if (cmp == LT) result = false;
    else if (cmp == GT) result = true;
    else
      {
        // compare using tie breaker
        auto cmptie = m[0] - n[0];
        result = (cmptie > 0);
      }
#if 0    
    buffer o;
    o << "comnparing: ";
    mMonoid.elem_text_out(o, m+2);
    o << " and ";
    mMonoid.elem_text_out(o, n+2);
    o << " result: " << (result ? "true" : "false");
    emit_line(o.str());
#endif
    return result;
  }
};

class ResColumnSorter2
{
private:
  const Monoid& mMonoid;
  const ResMonoid& mResMonoid;
  const ResSchreyerOrder& mSchreyerOrder;
  const std::vector<res_packed_monomial>& mColumns;

  memt::Arena mArena;
  std::vector<int*> mMonoms; // each monom: [tiebreaker, basecomp, followed by totalmon]
  std::vector<int> mPositions;
public:
  ResColumnSorter2(const Monoid& M,
                   const ResMonoid& resMonoid,
                   const ResSchreyerOrder& S, // order at level-1 in free res
                   const std::vector<res_packed_monomial>& columns // at level.
                   ) :
    mMonoid(M),
    mResMonoid(resMonoid),
    mSchreyerOrder(S),
    mColumns(columns)
  {
  }

  std::vector<int> sort()
  {
    std::vector<int> result;

    for (int i=0; i<mColumns.size(); i++)
      result.push_back(i);

#if 0    
    std::cout << "sort: creating big array of monomials" << std::endl;
#endif
    // now translate all the monomials to the correct kind:
    for (int i=0; i<mColumns.size(); i++)
      {
#if 0
        std::cout << "  adding in element " << i << " size=" << mMonoid.monomial_size() + 2 << std::endl;
#endif
        std::pair<int*, int*> mon = mArena.allocArrayNoCon<int>(mMonoid.monomial_size() + 2);

#if 0        
        std::cout << " taking res monomial: " << std::flush;
        mResMonoid.showAlpha(mColumns[i]);
#endif

        toMonomial(mColumns[i], mon);
        mMonoms.push_back(mon.first);

#if 0        
        std::cout << " and creating: " << std::flush;
        std::cout << "[" << mon.first[0] << " " << mon.first[1] << " ";
        buffer o;
        mMonoid.elem_text_out(o,mon.first+2);
        std::cout << o.str();
         std::cout << "]" << std::endl;
#endif         
      }
    ResColumnSorterObject C(mMonoid, mMonoms);
#if 0
    std::cout << "sort: doing stable_sort" << std::endl;
#endif    
    std::stable_sort(result.begin(), result.end(), C);
#if 0    
    std::cout << "sort: done with stable_sort" << std::endl;
#endif    
    return result;
  }
private:
  void toMonomial(res_packed_monomial mon, std::pair<int*,int*> resultAlreadyAllocateds)
  {
    int comp, comp2;
    int nvars = mMonoid.n_vars();
    std::pair<int*, int*> exp = mArena.allocArrayNoCon<int>(nvars);
    std::pair<int*, int*> exp2 = mArena.allocArrayNoCon<int>(nvars);
    mResMonoid.to_exponent_vector(mon, exp.first, comp);
#if 0    
    std::cout << " multiply by total monomial: " << std::flush;
    mResMonoid.showAlpha(mSchreyerOrder.mTotalMonom[comp]);
#endif    
    mResMonoid.to_exponent_vector(mSchreyerOrder.mTotalMonom[comp], exp2.first, comp2);
    ntuple::mult(nvars, exp.first, exp2.first, exp2.first);
    auto p = resultAlreadyAllocateds.first;
    *p++ = mSchreyerOrder.mTieBreaker[comp];
    *p++ = comp2;
    mMonoid.from_expvector(exp2.first, p);
    mArena.freeTop(exp2.first); // pop exp, exp2.
    mArena.freeTop(exp.first); // pop exp, exp2.
  }
};

std::vector<int> F4Res::reorderColumns2()
{
  //  std::cout << "creating sorter" << std::endl;

  ResColumnSorter2 sorter(ring().originalMonoid(), monoid(), frame().schreyerOrder(mThisLevel-2), mColumns);

  //  std::cout << "about to sort" << std::endl;

  auto column_order2 = sorter.sort();

  //  std::cout << "done with sort" << std::endl;

  return column_order2;
}
void F4Res::reorderColumns()
{
// Set up to sort the columns.
// Result is an array 0..ncols-1, giving the new order.
// Find the inverse of this permutation: place values into "ord" column fields.
// Loop through every element of the matrix, changing its comp array.

#if 0
  std::cout << "-- rows --" << std::endl;
  debugOutputReducers();
  std::cout << "-- columns --" << std::endl;
  debugOutputColumns();
  
  std::cout << "reorderColumns" << std::endl;
#endif
  ComponentIndex ncols = static_cast<ComponentIndex>(mColumns.size());

  // sort the columns

  auto timeA = timer();

  ComponentIndex* column_order = new ComponentIndex[ncols];
  ComponentIndex* ord = new ComponentIndex[ncols];

  ResColumnsSorter C(monoid(), *this, mThisLevel - 1);
  
  C.reset_ncomparisons();

  for (ComponentIndex i = 0; i < ncols; i++)
    {
      column_order[i] = i;
    }

  if (M2_gbTrace >= 2)
    fprintf(stderr, "  ncomparisons sorting %d columns = ", ncols);

  std::stable_sort(column_order, column_order + ncols, C);

  auto timeB = timer();
  double nsec_sort = seconds(timeB - timeA);
  mFrame.timeSortMatrix += nsec_sort;

  timeA = timer();
  auto column_order2 = reorderColumns2();
  timeB = timer();
  double nsec_sort2 = seconds(timeB - timeA);
  mFrame.timeSortMatrix += nsec_sort2;

  //  std::cout << "done with reorderColumns2" << std::endl;
  
#if 0
  std::cout << "column_order: ";
  for (int i=0; i<ncols; i++)
    {
      std::cout << column_order[i] << " ";
    }
  std::cout << std::endl << "column_order2: ";
  for (int i=0; i<ncols; i++)
    {
      std::cout << column_order2[i] << " ";
    }
  std::cout << std::endl;
#endif  
  bool arrays_same = true;
  for (int i=0; i<ncols; i++)
    if (column_order[i] != column_order2[i])
      arrays_same = false;
  if (!arrays_same)
    std::cout << "SORT FUNCTIONS DIFFER!!" << std::endl;
  
  if (M2_gbTrace >= 2) fprintf(stderr, "%ld, ", C.ncomparisons0());

  if (M2_gbTrace >= 1)
    std::cout << " sort time: " << nsec_sort << " 2nd sort time: " << nsec_sort2 << std::endl;

  timeA = timer();
  ////////////////////////////

  for (ComponentIndex i = 0; i < ncols; i++)
    {
      ord[column_order[i]] = i;
    }

#if 0
  std::cout << "column_order: ";
  for (ComponentIndex i=0; i<ncols; i++) std::cout << " " << column_order[i];
  std::cout <<  std::endl;
  std::cout << "ord: ";
  for (ComponentIndex i=0; i<ncols; i++) std::cout << " " << ord[i];
  std::cout <<  std::endl;
#endif
  // Now move the columns into position
  std::vector<res_packed_monomial> sortedColumnArray;
  std::vector<Row> sortedRowArray;

  sortedColumnArray.reserve(ncols);
  sortedRowArray.reserve(ncols);

  for (ComponentIndex i = 0; i < ncols; i++)
    {
      ComponentIndex newc = column_order[i];
      sortedColumnArray.push_back(mColumns[newc]);
      sortedRowArray.push_back(Row());
      std::swap(sortedRowArray[i], mReducers[newc]);
    }

  std::swap(mColumns, sortedColumnArray);
  std::swap(mReducers, sortedRowArray);

#if 0
  std::cout << "applying permutation to reducers" << std::endl;
#endif

  for (ComponentIndex i = 0; i < mReducers.size(); i++)
    {
#if 0
      std::cout << "reducer " << i << " before:";
      for (ComponentIndex j=0; j<mReducers[i].mComponents.size(); j++) std::cout << " " << mReducers[i].mComponents[j];
      std::cout << std::endl;
#endif
      applyPermutation(ord, mReducers[i].mComponents);
#if 0
      std::cout << "reducer " << i << " after:";
      for (ComponentIndex j=0; j<mReducers[i].mComponents.size(); j++) std::cout << " " << mReducers[i].mComponents[j];
      std::cout << std::endl;
#endif
    }
#if 0
  std::cout << "applying permutation to spairs" << std::endl;
#endif
  for (ComponentIndex i = 0; i < mSPairs.size(); i++)
    {
#if 0
      std::cout << "spair " << i << " before:";
      for (ComponentIndex j=0; j<mSPairs[i].mComponents.size(); j++) std::cout << " " << mSPairs[i].mComponents[j];
      std::cout << std::endl;
#endif
      applyPermutation(ord, mSPairs[i].mComponents);
#if 0
      std::cout << "spair " << i << " after:";
      for (ComponentIndex j=0; j<mSPairs[i].mComponents.size(); j++) std::cout << " " << mSPairs[i].mComponents[j];
      std::cout << std::endl;
#endif
    }

  timeB = timer();
  mFrame.timeReorderMatrix += seconds(timeB - timeA);
  delete[] column_order;
  delete[] ord;
}

void F4Res::makeMatrix()
{
  // std::cout << "entering makeMatrix()" << std::endl;
  auto& myframe = mFrame.level(mThisLevel);
  long r = 0;
  long comp = 0;
  for (auto it = myframe.begin(); it != myframe.end(); ++it)
    {
      if (it->mDegree == mThisDegree)
        {
          mSPairs.push_back(Row());
          mSPairComponents.push_back(comp);
          Row& row = mSPairs[r];
          r++;
          row.mLeadTerm = it->mMonom;
          loadRow(row);
          if (M2_gbTrace >= 4)
            if (r % 5000 == 0)
              std::cout << "makeMatrix  sp: " << r
                        << " #rows = " << mColumns.size() << std::endl;
        }
      comp++;
    }
  // Now we process all monomials in the columns array
  while (mNextReducerToProcess < mColumns.size())
    {
      // Warning: mReducers is being appended to during 'loadRow', and
      // since we act on the Row directly, it might get moved on us!
      // (actually, it did get moved, which prompted this fix)
      Row thisrow;
      std::swap(mReducers[mNextReducerToProcess], thisrow);
      loadRow(thisrow);
      std::swap(mReducers[mNextReducerToProcess], thisrow);
      mNextReducerToProcess++;
      if (M2_gbTrace >= 4)
        if (mNextReducerToProcess % 5000 == 0)
          std::cout << "makeMatrix red: " << mNextReducerToProcess
                    << " #rows = " << mReducers.size() << std::endl;
    }

  reorderColumns();

#if 0
  debugOutputReducers();
  debugOutputColumns();
  std :: cout << "-- reducer matrix --" << std::endl;
  debugOutputMatrix(mReducers);
  debugOutputMatrixSparse(mReducers);

  std :: cout << "-- spair matrix --" << std::endl;
  debugOutputMatrix(mSPairs);
  debugOutputMatrixSparse(mSPairs);
#endif
}

//#define DEBUG_GAUSS

void F4Res::gaussReduce()
{
  bool onlyConstantMaps = false;
  std::vector<bool> track(mReducers.size());
  if (onlyConstantMaps)  // and not exterior algebra?
    {
      for (auto i = 0; i < mReducers.size(); i++)
        {
          track[i] = monoid().is_divisible_by_var_in_range(
              mReducers[i].mLeadTerm,
              monoid().n_vars() - mThisLevel + 1,
              monoid().n_vars() - 1);
        }
    }

  // Reduce to zero every spair. Recording creates the
  // corresponding syzygy, which is auto-reduced and correctly ordered.

  // allocate a dense row, of correct size
  CoefficientVector gauss_row = mRing.resGausser().allocateCoefficientVector(
      static_cast<ComponentIndex>(mColumns.size()));
  //  std::cout << "gauss_row: " << (gauss_row.isNull() ? "null" : "not-null")
  //  << std::endl;
  //  std::cout << "gauss_row size: " << mRing.resGausser().size(gauss_row) <<
  //  std::endl;

  for (long i = 0; i < mSPairs.size(); i++)
    {
#ifdef DEBUG_GAUSS
      std::cout << "reducing row " << i << std::endl;
#endif
      // Reduce spair #i
      // fill in dense row with this element.

      poly_constructor result(mRing);

      Row& r = mSPairs[i];  // row to be reduced.
      long comp = mSPairComponents[i];
      result.appendMonicTerm(mFrame.level(mThisLevel)[comp].mMonom);

      auto& syz = mFrame.level(mThisLevel)[comp]
                      .mSyzygy;  // this is the element we will fill out

      // Note: in the polynomial ring case, the row r is non-zero.
      // BUT: for skew commuting variables, it can happen that r is zero
      // (e.g. a.(acd<0>) = 0).  In this case we have nothing to reduce.
      if (!r.mComponents.empty())
        {
          ComponentIndex firstcol = r.mComponents[0];
          ComponentIndex lastcol = static_cast<ComponentIndex>(
              mColumns.size() -
              1);  // maybe: r.mComponents[r.mComponents.size()-1];

#ifdef DEBUG_GAUSS
          std::cout << "about to fill from sparse " << i << std::endl;
#endif

          mRing.resGausser().fillFromSparse(
              gauss_row,
              static_cast<ComponentIndex>(r.mComponents.size()),
              r.mCoeffs,
              &r.mComponents[0]);  // FIX: not correct call

          while (firstcol <= lastcol)
            {
#ifdef DEBUG_GAUSS
              std::cout << "about to reduce with col " << firstcol << std::endl;
              std::cout << "gauss_row: "
                        << (gauss_row.isNull() ? "null" : "not-null")
                        << std::endl;
              std::cout << "mReducers[" << firstcol << "]: "
                        << (mReducers[firstcol].mCoeffs.isNull() ? "null"
                                                                 : "not-null")
                        << std::endl;
              std::cout << "result: " << (result.coefficientInserter().isNull()
                                              ? "null"
                                              : "not-null")
                        << std::endl;
              std::cout << "  dense: ";
              mRing.resGausser().debugDisplay(std::cout, gauss_row)
                  << std::endl;
              mRing.resGausser().debugDisplay(std::cout,
                                              mReducers[firstcol].mCoeffs);
              std::cout << std::endl;
              mRing.resGausser().debugDisplay(std::cout,
                                              result.coefficientInserter());
              std::cout << std::endl;
#endif

              if (onlyConstantMaps and not track[firstcol])
                {
                  mRing.resGausser().sparseCancel(
                      gauss_row,
                      mReducers[firstcol].mCoeffs,
                      mReducers[firstcol].mComponents.data());
                }
              else
                {
                  mRing.resGausser().sparseCancel(
                      gauss_row,
                      mReducers[firstcol].mCoeffs,
                      mReducers[firstcol].mComponents.data(),
                      result.coefficientInserter());

#ifdef DEBUG_GAUSS
                  std::cout << "  done with sparseCancel" << std::endl;
                  mRing.resGausser().debugDisplay(std::cout, gauss_row)
                      << std::endl;
                  mRing.resGausser().debugDisplay(std::cout,
                                                  mReducers[firstcol].mCoeffs)
                      << std::endl;
                  mRing.resGausser().debugDisplay(std::cout,
                                                  result.coefficientInserter())
                      << std::endl;
                  std::cout << "  about to push back term" << std::endl;
#endif

                  result.pushBackTerm(mReducers[firstcol].mLeadTerm);

#ifdef DEBUG_GAUSS
                  std::cout << "done with col " << firstcol << std::endl;
#endif
                }
              firstcol = mRing.resGausser().nextNonzero(
                  gauss_row, firstcol + 1, lastcol);
            }
        }
#ifdef DEBUG_GAUSS
      std::cout << "about to set syz" << std::endl;
#endif
      result.setPoly(syz);
#ifdef DEBUG_GAUSS
      std::cout << "just set syz" << std::endl;
#endif
    }
  mRing.resGausser().deallocate(gauss_row);
}

void F4Res::construct(int lev, int degree)
{
  decltype(timer()) timeA, timeB;

  resetMatrix(lev, degree);

  timeA = timer();
  makeMatrix();
  timeB = timer();
  mFrame.timeMakeMatrix += seconds(timeB - timeA);

  if (M2_gbTrace >= 2) mHashTable.dump();

  if (M2_gbTrace >= 2)
    std::cout << "  make matrix time: " << seconds(timeB - timeA) << " sec"
              << std::endl;

#if 0
  std::cout << "-- rows --" << std::endl;
  debugOutputReducers();
  std::cout << "-- columns --" << std::endl;
  debugOutputColumns();
  std :: cout << "-- reducer matrix --" << std::endl;
  if (true or lev <= 2)
    debugOutputMatrix(mReducers);
  else
    debugOutputMatrixSparse(mReducers);

  std :: cout << "-- reducer matrix --" << std::endl;
  debugOutputMatrix(mReducers);
  debugOutputMatrixSparse(mReducers);

  std :: cout << "-- spair matrix --" << std::endl;
  debugOutputMatrix(mSPairs);
  debugOutputMatrixSparse(mSPairs);
#endif

  if (M2_gbTrace >= 2)
    std::cout << "  (degree,level)=(" << (mThisDegree - mThisLevel) << ","
              << mThisLevel << ") #spairs=" << mSPairs.size()
              << " reducer= " << mReducers.size() << " x " << mReducers.size()
              << std::endl;

  if (M2_gbTrace >= 2) std::cout << "  gauss reduce matrix" << std::endl;

  timeA = timer();
  gaussReduce();
  timeB = timer();
  mFrame.timeGaussMatrix += seconds(timeB - timeA);

  if (M2_gbTrace >= 2)
    std::cout << "    time: " << seconds(timeB - timeA) << " sec" << std::endl;
  //  mFrame.show(-1);

  timeA = timer();
  clearMatrix();
  timeB = timer();
  mFrame.timeClearMatrix += seconds(timeB - timeA);
}

void F4Res::debugOutputReducers()
{
  std::cout << "-- reducers(rows) -- " << std::endl;
  auto end = mReducers.cend();
  for (auto i = mReducers.cbegin(); i != end; ++i)
    {
      monoid().showAlpha((*i).mLeadTerm);
      std::cout << std::endl;
    }
}
void F4Res::debugOutputColumns()
{
  std::cout << "-- columns --" << std::endl;
  auto end = mColumns.cend();
  for (auto i = mColumns.cbegin(); i != end; ++i)
    {
      monoid().showAlpha((*i));
      std::cout << std::endl;
    }
}

void F4Res::debugOutputMatrixSparse(std::vector<Row>& rows)
{
  for (ComponentIndex i = 0; i < rows.size(); i++)
    {
      std::cout << "coeffs[" << i << "] = ";
      mRing.resGausser().debugDisplay(std::cout, rows[i].mCoeffs);
      std::cout << " comps = ";
      for (long j = 0; j < rows[i].mComponents.size(); ++j)
        std::cout << rows[i].mComponents[j] << " ";
      std::cout << std::endl;
    }
}

void F4Res::debugOutputMatrix(std::vector<Row>& rows)
{
  for (ComponentIndex i = 0; i < rows.size(); i++)
    {
      mRing.resGausser().debugDisplayRow(std::cout,
                                         static_cast<int>(mColumns.size()),
                                         rows[i].mComponents,
                                         rows[i].mCoeffs);
    }
}
void F4Res::debugOutputReducerMatrix() { debugOutputMatrix(mReducers); }
void F4Res::debugOutputSPairMatrix() { debugOutputMatrix(mSPairs); }
// Local Variables:
// compile-command: "make -C $M2BUILDDIR/Macaulay2/e "
// indent-tabs-mode: nil
// End:
