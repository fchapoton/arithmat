import sage.matroids.matroid
import itertools
import networkx as nx
import operator
import sys
import copy
from fractions import gcd

from sage.matroids.matroid import Matroid
from sage.matroids.rank_matroid import RankMatroid
from sage.matroids.linear_matroid import LinearMatroid
from sage.matroids.dual_matroid import DualMatroid
from sage.matroids.minor_matroid import MinorMatroid


"""
TODO

* check if M is decomposable and give the indecomposable addendum
* more tests (minors, dual, copy, deepcopy, ToricArithmeticMatroid, groundset != [0,...,n-1])
* other classes of the form XxxArithmeticMatroid
* _rank -> rank, _multiplicity -> multiplicity
"""


# class ArithmeticMatroid(sage.matroids.matroid.Matroid):
class ArithmeticMatroidMixin(object):
    def __init__(self, *args, **kwargs):
        # get multiplicity function
        try:
            multiplicity = kwargs.pop('multiplicity_function')
        except KeyError:
            """
            # hope that the last positional argument is the multiplicity function
            # FIXME maybe this is dangerous?
            multiplicity = args[-1]
            args = args[:-1]
            """
            multiplicity = None # multiplicity function must be set later
        
        super(ArithmeticMatroidMixin, self).__init__(*args, **kwargs)
        self._multiplicity = multiplicity

    def __repr__(self):
        return "Arithmetic matroid of rank %d on %d elements" % (self.full_rank(), len(self.groundset()))
    
    
    def __hash__(self):
        return hash((self.groundset(), self.full_rank(), self._multiplicity(frozenset()), self._multiplicity(self.groundset())))
        
    def __eq__(self, other):
        if not isinstance(other, ArithmeticMatroidMixin):
            return False
        
        return super(ArithmeticMatroidMixin, self).__eq__(other) and (self._multiplicity == other._multiplicity)
    
    def __ne__(self, other):
        return not self == other
    
    
    def __copy__(self):
        N = super(ArithmeticMatroidMixin, self).__copy__()
        N._multiplicity = self._multiplicity
        N.__class__ = type(self)
        return N
    
    def __deepcopy__(self, *args, **kwargs):
        N = super(ArithmeticMatroidMixin, self).__deepcopy__(*args, **kwargs)
        N._multiplicity = copy.deepcopy(self._multiplicity)
        N.__class__ = type(self)
        return N
    
    def __reduce__(self):
        raise TypeError("unfortunately, functions cannot be saved reliably, so this class doesn't have load/save support.")
    
    
    def _is_isomorphism(self, other, morphism):
        """
        Version of is_isomorphism() that does no type checking.
        (see Matroid.is_isomorphism)
        """
        for X in powerset(self.groundset()):
            Y = frozenset(morphism[e] for e in X)
            if self._rank(X) != other._rank(Y) or self._multiplicity(X) != other._multiplicity(Y):
                return False
        return True
    
    
    def is_independent_from(self, v, X):
        return self._rank(X+[v]) != self._rank(X)
    
    def is_dependent_from(self, v, X):
        return not self.is_independent_from(v, X)
    
    
    def is_valid(self):
        """
        Check if the arithmetic matroid axioms are satisfied.
        """
        if not super(ArithmeticMatroidMixin, self).is_valid():
            # check validity of the underlying matroid
            return False
        
        E = self.groundset()
        
        # check axioms for arithmetic matroids
        for X in powerset(E):
            for v in E:
                if v not in X:
                    if self.is_dependent_from(v, X):
                        # check axiom 1
                        if self._multiplicity(X) % self._multiplicity(X+[v]) != 0:
                            # print >> sys.stderr, "Axiom 1 fails on", X, v
                            return False
                    
                    else:
                        # check axiom 2
                        if self._multiplicity(X+[v]) % self._multiplicity(X) != 0:
                            # print >> sys.stderr, "Axiom 2 fails on", X, v
                            return False
        
        for Y in powerset(E):
            for X in powerset(Y):
                T = []
                F = []
                for y in Y:
                    if y not in X:
                        if self.is_dependent_from(y, X):
                            T.append(y)
                        else:
                            F.append(y)
                
                if len(F) + self._rank(X) == self._rank(Y):
                    # (X, Y) is a molecule
                    
                    # check axiom 3
                    if self._multiplicity(X) * self._multiplicity(Y) != self._multiplicity(X+F) * self._multiplicity(X+T):
                        return False
                    
                    # check axiom P
                    if (-1)**(len(T)) * sum((-1)**(len(Y)-len(Z)-len(X)) * self._multiplicity(X+Z) for Z in powerset([z for z in Y if z not in X])) < 0:
                        return False
        
        return True
    
    
    def _minor(self, contractions=[], deletions=[]):
        # get minor as a (non-arithmetic) matroid
        matroid = super(ArithmeticMatroidMixin, self)._minor(contractions, deletions)
        
        if isinstance(matroid, MinorMatroid):
            # return an instance of MinorArithmeticMatroid
            return MinorArithmeticMatroid(self, contractions, deletions)
        
        else:
            # we use the same (arithmetic) class here
            matroid.__class__ = type(self)
            
            # add multiplicity function
            matroid._multiplicity = lambda X : self._multiplicity(contractions.union(X))
        
            return matroid
    
    
    def dual(self):
        # get dual as a (non-arithmetic) matroid
        matroid = super(ArithmeticMatroidMixin, self).dual()
        
        if isinstance(matroid, DualMatroid):
            # return an instance of DualArithmeticMatroid
            return DualArithmeticMatroid(self)
        
        else:
            # we use the same (arithmetic) class here
            matroid.__class__ = type(self)
            
            # add multiplicity function
            matroid._multiplicity = lambda X : self._multiplicity(self.groundset().difference(X))
            
            return matroid
    
    
    def check_realization(self, A, ordered_groundset=None, check_bases=False):
        """
        Check if the given matrix is a realization for the matroid.
        If check_bases==True, check that the multiplicity is correct only on the bases.
        """
        r = self.full_rank()
        n = len(self.groundset())
        
        if ordered_groundset is not None:
            # use the groundset in the given order
            E = ordered_groundset
            assert frozenset(E) == self.groundset()
        else:
            # to sort the groundset
            E = list(sorted(self.groundset()))
        
        if A.ncols() != n:
            return False
        
        for S in powerset(range(n)):
            T = [E[i] for i in S]   # corresponding subset of E
            if A[:,S].rank() != self._rank(T):
                # print >> sys.stderr, "Not realizable, rank of %r is incorrect" % T
                return False
            
            if check_bases and len(T) != r and self._rank(T) < r:
                # skip multiplicity check
                continue

            if reduce(operator.mul, [d for d in A[:,S].elementary_divisors() if d != 0], 1) != self._multiplicity(T):
                # print >> sys.stderr, "Not realizable, multiplicity of %r is incorrect" % T
                return False
        
        return True
        
    
    def realization_surjective(self, ordered_groundset=None, check_bases=False):
        """
        Find a realization (if it exists) for a surjective matroid (m(E)=1).
        If check_bases==True, find a realization of a matroid (E,rk,m')
        such that m'(B)=m(B) for every basis B.
        """
        assert self._multiplicity(self.groundset()) == 1

        r = self.full_rank()
        n = len(self.groundset())
        
        if ordered_groundset is not None:
            # use the groundset in the given order
            E = ordered_groundset
            assert frozenset(E) == self.groundset()
        else:
            # sort the groundset
            E = list(sorted(self.groundset()))
        
        B = self.basis()
        # print "Basis:", B
                
        # find bipartite graph
        edges = [(x,y) for x in B for y in E if y not in B and self.is_basis(B.difference([x]).union([y]))]
        
        spanning_forest = nx.Graph()
        
        # find spanning forest
        uf = DisjointSet(E)
        for (x,y) in edges:
            if uf.find(x) != uf.find(y):
                spanning_forest.add_edge(x,y)
                uf.union(x,y)
        
        # print "Graph:", edges
        # print "Spanning forest:", spanning_forest.edges()
        
        # fix an order of B
        B = list(sorted(B))
        
        # compute entries of matrix A
        def entry(i,j):
            x = B[i]
            y = E[j]
            
            if y in B:
                return self._multiplicity(B) if x == y else 0
            
            elif (x,y) in edges:
                return self._multiplicity([z for z in B if z != x]+[y])
            
            else:
                return 0
        
        A = matrix(ZZ, r, n, entry)
        # print A
        
        B_to_index = {B[i]: i for i in xrange(r)}
        E_to_index = {E[j]: j for j in xrange(n)}
        
        
        graph = spanning_forest
        while graph.number_of_edges() < len(edges):
            # find all paths in the graph
            paths = nx.all_pairs_dijkstra_path(graph)
            for (x,y) in sorted(edges, key = lambda (x,y): len(paths[x][y])):
                if len(paths[x][y]) == 2:
                    # (x,y) is in the graph
                    assert (x,y) in graph.edges()
                    continue
            
                i = B_to_index[x]
                j = E_to_index[y]
                
                rows = [B_to_index[z] for z in paths[x][y][::2]]
                columns = [E_to_index[z] for z in paths[x][y][1::2]]
                
                # print x, y
                # print "rows:", rows
                # print "columns:", columns
                
                new_tuple = [z for z in B + paths[x][y] if z not in B or z not in paths[x][y]]
                # print "new_tuple:", new_tuple
                expected_mult = self._multiplicity(new_tuple) * self._multiplicity(B)**(len(rows)-1) if self._rank(new_tuple) == r else 0
                if abs(A[rows,columns].determinant()) != expected_mult:
                    # change sign
                    # print "change sign!"
                    # print A[rows,columns].determinant()
                    A[i,j] = -A[i,j]
                    
                    if abs(A[rows,columns].determinant()) != expected_mult:
                        # print A
                        # print A[rows,columns].determinant(), expected_mult
                        return None
                
                graph.add_edge(x,y)
                break
        
        D, U, V = A.smith_form()
        res = V.inverse()[:r,:]
        res = matrix(ZZ, res)
        
        # print >> sys.stderr, "Candidate realization:"
        # print >> sys.stderr, res
        
        # check if this is indeed a realization
        if not self.check_realization(res, ordered_groundset=ordered_groundset, check_bases=check_bases):
            return None
        
        return res


    def all_realizations(self, ordered_groundset=None):
        """
        Generator of all non-equivalent essential realizations.
        """
        # TODO implement m(emptyset) > 1?
        r = self.full_rank()
        n = len(self.groundset())
        
        if self._multiplicity(self.groundset()) == 1:
            res = self.realization_surjective(ordered_groundset=ordered_groundset)
            if res is not None:
                yield res
            return
        
        # construct "reduced" matroid
        denominator = reduce(gcd, [self._multiplicity(B) for B in self.bases()], 0)
        
        def m_bar(X):
            return reduce(gcd, [self._multiplicity(B) for B in self.bases() if self._rank(X) == self._rank([x for x in X if x in B])], 0) // denominator
        
        M = ArithmeticMatroid(self.groundset(), self._rank, multiplicity_function=m_bar)
        
        if not M.is_valid():
            return
        
        # get realization of "reduced" matroid
        A = M.realization_surjective(ordered_groundset=ordered_groundset)
        
        if A is None:
            return
        
        # try all left Hermite normal forms
        for H in hermite_normal_forms(r, self._multiplicity(self.groundset())):
            if self.check_realization(H*A):
                yield H*A
    
    
    def num_realizations(self):
        """
        Compute the number of non-equivalent essential realizations.
        """
        return sum(1 for _ in self.all_realizations())
    
    
    def realization(self, ordered_groundset=None):
        """
        Compute any essential realization.
        Return None if the matroid is not realizable.
        """
        for A in self.all_realizations(ordered_groundset=ordered_groundset):
            return A
        return None

    
    def is_realizable(self):
        """
        Determine if the matroid is a realizable arithmetic matroid.
        """
        return self.realization() is not None
    
    
    def is_orientable(self):
        """
        Determine if the matroid is an orientable arithmetic matroid according to [Pagaria https://arxiv.org/abs/1805.11888].
        """
        # construct "reduced" matroid
        denominator = reduce(gcd, [self._multiplicity(B) for B in self.bases()], 0)
        
        def m_bar(X):
            return reduce(gcd, [self._multiplicity(B) for B in self.bases() if self._rank(X) == self._rank([x for x in X if x in B])], 0) // denominator
        
        M = ArithmeticMatroid(self.groundset(), self._rank, multiplicity_function=m_bar) # note: this matroid might be non-valid
        
        return M.realization_surjective(check_bases=True) is not None
    
    
    def arithmetic_tutte_polynomial(self, x=None, y=None):
        """
        Return the arithmetic Tutte polynomial of the matroid.
        """
        E = self.groundset()
        r = self.full_rank()
        
        a = x
        b = y
        R = ZZ['x, y']
        x, y = R._first_ngens(2)
        T = R(0)
        for X in powerset(self.groundset()):
            T += self._multiplicity(X) * (x-1) ** (r - self._rank(X)) * (y-1) ** (len(X) - self._rank(X))
        if a is not None and b is not None:
            T = T(a, b)
        return T



class ArithmeticMatroid(ArithmeticMatroidMixin, RankMatroid):
    def __init__(self, groundset, rank_function, multiplicity_function):
        # take multiplicity function as third positional argument
        return super(ArithmeticMatroid, self).__init__(groundset, rank_function, multiplicity_function=multiplicity_function)


class LinearArithmeticMatroid(ArithmeticMatroidMixin, LinearMatroid):
    pass



class MinorArithmeticMatroid(ArithmeticMatroidMixin, MinorMatroid):
    """
    Minor of an arithmetic matroid.
    """
    def __init__(self, *args, **kwargs):
        super(ArithmeticMatroidMixin, self).__init__(*args, **kwargs)
    
    def __repr__(self):
        super(ArithmeticMatroidMixin, self).__repr__()
    
    def __eq__(self, other):
        return (self._contractions == other._contractions) and (self._deletions == other._deletions) and (self._matroid == other._matroid)
    
    def __reduce__(self):
        return super(ArithmeticMatroidMixin, self).__reduce__()
    
    def _multiplicity(self, X):
        return self._matroid._multiplicity(self._contractions.union(X))
    
    def _minor(self, contractions=[], deletions=[]):
        return MinorArithmeticMatroid(self._matroid, self._contractions.union(contractions), self._deletions.union(deletions))



class DualArithmeticMatroid(ArithmeticMatroidMixin, DualMatroid):   
    """
    Dual of an arithmetic matroid.
    """
    def __init__(self, matroid):
        if not isinstance(matroid, ArithmeticMatroidMixin):
            raise TypeError("no arithmetic matroid provided to take dual of.")
        self._matroid = matroid
    
    def __repr__(self):
        return "Dual of '" + repr(self._matroid) + "'"
    
    def __eq__(self, other):
        return self._matroid == other._matroid
    
    def __reduce__(self):
        return super(ArithmeticMatroidMixin, self).__reduce__()
    
    
    def _multiplicity(self, X):
        return self._matroid._multiplicity(self.groundset().difference(X))

    def dual(self):
        return self._matroid
    
    def _minor(self, contractions=[], deletions=[]):
        # Assumption: if self._matroid cannot make a dual, neither can its minor.
        return DualArithmeticMatroid(self._matroid._minor(contractions=deletions, deletions=contractions))



class ToricArithmeticMatroid(ArithmeticMatroidMixin, Matroid):
    
    def __init__(self, matrix, torus_matrix=None, ordered_groundset=None):
        self._A = matrix
        self._Q = torus_matrix if torus_matrix is not None else Matrix(ZZ, matrix.nrows(), 0)
        
        assert self._A.nrows() == self._Q.nrows()
        self._normalize()
        
        if ordered_groundset is None:
            ordered_groundset = range(matrix.ncols())
        else:
            assert len(ordered_groundset) == matrix.ncols()
        
        self._groundset = frozenset(ordered_groundset) # non-ordered groundset
        self._E = ordered_groundset                    # ordered groundset
        self._groundset_to_index = {e: i for (i,e) in enumerate(ordered_groundset)} # dictionary groundset -> columns
    
    def _normalize(self):
        """
        Put Q in Smith normal form (this also changes A).
        """
        D, U, V = self._Q.smith_form()  # D = U*Q*V
        self._A = U * self._A
        self._Q = D[:, :D.rank()] # remove zero columns from Q
        
        while self._Q.ncols() > 0 and self._Q[0,0] == 1:
            # delete first row from Q and A
            self._Q = self._Q[1:,1:]
            self._A = self._A[1:,:]
    
    
    def groundset(self):
        return self._groundset
    
    def _rank(self, X):
        T = block_matrix(ZZ, [[self._A[:, [self._groundset_to_index[e] for e in X]], self._Q]])
        return T.rank() - self._Q.ncols()
    
    def _multiplicity(self, X):
        T = block_matrix(ZZ, [[self._A[:, [self._groundset_to_index[e] for e in X]], self._Q]])
        return reduce(operator.mul, [d for d in T.elementary_divisors() if d != 0], 1)
        
    
    def __repr__(self):
        return "Toric arithmetic matroid of rank %d on %d elements" % (self.full_rank(), len(self.groundset()))
    
    
    def __hash__(self):
        return hash((self._E, self._A))
        
    def __eq__(self, other):
        if not isinstance(other, ToricArithmeticMatroid):
            return False
        
        return self._E == other._E and self._A == other._A
    
    
    def __copy__(self):
        return ToricArithmeticMatroid(matrix=self._A, ordered_groundset=self._E)
    
    def __deepcopy__(self, *args, **kwargs):
        return ToricArithmeticMatroid(matrix=copy.deepcopy(self._A), ordered_groundset=copy.deepcopy(self._E))
    
    def __reduce__(self):
        # TODO
        raise NotImplementedError
    
    def is_valid(self):
        return True


    def _minor(self, contractions=[], deletions=[]):
        new_groundset = [e for e in self._E if e not in contractions+deletions]
        A2 = copy.copy(self._A[:, [self._groundset_to_index[e] for e in new_groundset]])
        Q2 = block_matrix(ZZ, [[self._A[:, [self._groundset_to_index[e] for e in contractions]], self._Q]])
        return ToricArithmeticMatroid(matrix=A2, torus_matrix=Q2, ordered_groundset=new_groundset)
    
    
    def dual(self):
        T = block_matrix(ZZ, [[self._A[:, [self._groundset_to_index[e] for e in self._E]], self._Q]]).transpose()
        I = identity_matrix(ZZ, T.nrows())
        
        temp_elements = ["temp_%d" % i for i in xrange(self._Q.ncols())]
        M = ToricArithmeticMatroid(matrix=I, torus_matrix=T, ordered_groundset=self._E+temp_elements)
        return M._minor(deletions=temp_elements)
    
    
    def realization(self, ordered_groundset=None):
        """
        Compute any essential realization.
        Return None if the matroid is not realizable.
        """
        # first try to return self._A
        if self._Q.ncols() == 0:
            if ordered_groundset is not None:
                # use the groundset in the given order
                E = ordered_groundset
                assert frozenset(E) == self.groundset()
            else:
                # use self._E (which is ordered)
                E = self._E
            
            # return self._A, with shuffled columns
            return self._A[:, [self._groundset_to_index[e] for e in E]] # TODO should also return Q, when m(emptyset) > 1?
        
        return super(ToricArithmeticMatroid, self).realization(ordered_groundset=ordered_groundset)

    
    def is_orientable(self):
        """
        Determine if the matroid is an orientable arithmetic matroid according to [Pagaria https://arxiv.org/abs/1805.11888].
        """
        if self._Q.ncols() == 0:
            return True
        
        else:
            return super(ToricArithmeticMatroid, self).is_orientable()
    
    
    def is_equivalent(self, other, morphism=None):
        """
        Check if the realizations are equivalent.
        If morphism is None, assume that the groundsets coincide
        """
        if not isinstance(other, ToricArithmeticMatroid):
            raise TypeError("can only test for equivalence between toric arithmetic matroids.")
        
        if self._Q.ncols() > 0 or other._Q.ncols() > 0:
            # TODO
            raise NotImplementedError
        
        if morphism is None:
            morphism = {e: e for e in self.groundset()}
        
        E = self._E
        
        # take matrices in Hermite normal form, removing zero rows
        # (copy is needed to make matrices mutable)
        M = copy.copy(self._A.echelon_form(include_zero_rows=False))
        N = copy.copy(other._A[:, [other._groundset_to_index[morphism[e]] for e in self._E]].echelon_form(include_zero_rows=False))
        
        # choose a basis
        B = self.basis()
        if not other.is_basis(frozenset(morphism[e] for e in B)):
            return False
        
        # find bipartite graph
        edges = []
        for x in B:
            for y in E:
                C = B.difference([x]).union([y])
                if y not in B and self.is_basis(C):
                    if not other.is_basis(frozenset(morphism[e] for e in C)):
                        return False
                    
                    edges.append((x,y))
        
        spanning_forest = nx.Graph()
        
        # find spanning forest
        uf = DisjointSet(E)
        for (x,y) in edges:
            if uf.find(x) != uf.find(y):
                spanning_forest.add_edge(x,y)
                uf.union(x,y)
        
        B_indices = list(sorted(self._groundset_to_index[e] for e in B))
        
        M1 = M[:, B_indices].inverse() * M
        N1 = N[:, B_indices].inverse() * N
        
        def change_signs(A, A1):
            for (i,j) in nx.edge_dfs(spanning_forest):
                (x,y) = (i,j) if i in B else (j,i)
                if A1[x,y] < 0:
                    if j in B:
                        # change sign of row j and column j
                        A1[j,:] *= -1
                        A1[:,j] *= -1
                        
                        A[j,:] *= -1
                        A[:,j] *= -1
                        
                        assert A1 == A[:, B_indices].inverse() * A
                    
                    else:
                        # change sign of column j
                        A1[:,j] *= -1
                        
                        A[:,j] *= -1
        
        change_signs(M, M1)
        change_signs(N, N1)
        
        return M.echelon_form() == N.echelon_form()
    
    
    def decomposition(self):
        """
        Find the decomposition of the matroid as a direct sum of indecomposable matroids.
        Returns a partition of the groundset.
        """
        A = self._A.echelon_form()
        uf = DisjointSet(self.groundset())
        
        for i in xrange(A.nrows()):
            for j in xrange(i+1, A.ncols()):
                if A[i,j] != 0:
                    uf.union(self._E[i], self._E[j])
        
        return SetPartition(uf)
        
    


def hermite_normal_forms(r, det):
    """
    Generate all r x r integer matrices in (left) Hermite normal form
    with the given determinant.
    """
    if r == 0:
        if det == 1:
            yield matrix(ZZ, 0, [])
    
    else:
        for d in divisors(det):
            for A in hermite_normal_forms(r-1, det//d):
                for column in itertools.product(range(d), repeat=r-1):
                    yield matrix(ZZ, r, r, lambda i, j:
                        A[i,j] if i < r-1 and j < r-1
                        else d if i == r-1 and j == r-1
                        else column[i] if j == r-1
                        else 0
                    )



if __name__ == '__main__':
    E = [1,2,3,4,5]

    def rk(X):
        return min(2, len(X))


    def m(X):
        if len(X) == 2 and all(x in [3,4,5] for x in X):
            return 2
        else:
            return 1


    M = ArithmeticMatroid(E, rk, multiplicity_function=m)

    print M
    print "Valid:", M.is_valid()

    print M.realization()
    print M.arithmetic_tutte_polynomial()
    
    M.__custom_name = "Pippo"
    print deepcopy(M)
    
    
    
    
