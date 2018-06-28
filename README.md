# Arithmat
Sage implementation of arithmetic matroids and toric arrangements.

Authors: Giovanni Paolini and Roberto Pagaria

## Requirements

* [Python](https://www.python.org/) 2.7 or 3.x (support for Python 3.x is not guaranteed at the moment)
* [Sage](http://www.sagemath.org/) >= 8
* The Python pacakge `networkx` (can be installed with `sage --python -m easy_install networkx` or `sage --python -m pip install networkx`)

## Quick start
...

## Overview

Arithmat is a Sage package that implements arithmetic matroids.
At its core there is the class `ArithmeticMatroidMixin`, which is intended to be used in combination with [any existing matroid class of Sage](http://doc.sagemath.org/html/en/reference/matroids/index.html) (e.g. `RankMatroid`, `BasisMatroid`, `LinearMatroid`) via multiple inheritance.
The most common combinations are already defined, for example: `ArithmeticMatroid` (deriving from `RankMatroid`), `BasisArithmeticMatroid` (deriving from `BasisMatroid`), `LinearArithmeticMatroid` (deriving from `LinearMatroid`).
An additional class `ToricArithmeticMatroid` is implemented, for arithmetic matroids constructed from a fixed given representation.

## Documentation

### Import

All defined classes can be imported at once:
```sage
from arithmat import *
```
Alternatively, it is possible to import only specific classes. For example:
```sage
from arithmat import ArithmeticMatroid, ToricArithmeticMatroid
```


### Available classes for arithmetic matroids

All classes for arithmetic matroids derive from `ArithmeticMatroidMixin` and from some subclass of Sage's `Matroid`.
The class `ArithmeticMatroidMixin` is not intended to be used by itself, but it is possible to subclass it in order to create new classes for arithmetic matroids (see below).

The classes which are already provided in `arithmat` are the following.

* `ArithmeticMatroid(groundset, rank_function, multiplicity_function)`
  
  This is the simplest arithmetic matroid class, and derives from `ArithmeticMatroidMixin` and `RankMatroid`.
  Example:
  ```sage
  E = [1,2,3,4,5]
  
  def rk(X):
      return min(2, len(X))
  
  def m(X):
      if len(X) == 2 and all(x in [3,4,5] for x in X):
          return 2
      else:
          return 1
  
  M = ArithmeticMatroid(E, rk, m)
  print M
  # Arithmetic matroid of rank 2 on 5 elements
  ```
* `ToricArithmeticMatroid(arrangement_matrix, torus_matrix=None, ordered_groundset=None)`

  Arithmetic matroid associated to a given toric arrangement. This class derives from `ArithmeticMatroidMixin` and `Matroid`.
  
  The constructor requires an integer matrix `arrangement_matrix` representing the toric arrangement. Otionally it accepts another integer matrix `torus_matrix` (whose cokernel describes the ambient torus, and defaults to `matrix(ZZ, arrangement_matrix.nrows(), 0)`) and/or an ordered copy `ordered_groundset` of the groundset (defaults to `range(matrix.ncols())`). The number of rows of `arrangement_matrix` must be equal to the numer of rows of `torus_matrix`.
  
  The two matrices are not guaranteed to remain unchanged: internally,`torus_matrix` is kept in Smith normal form (this also affects `arrangement_matrix`).
  
  Example:
  ```sage
  A = matrix(ZZ, [[-1, 1, 0, 7], [6, 1, -1, -2]])
  M = ToricArithmeticMatroid(A)
  
  print M
  # Toric arithmetic matroid of rank 2 on 4 elements
  
  print M.arrangement_matrix()
  # [-1  1  0  7]
  # [ 6  1 -1 -2]
  
  print M.torus_matrix()
  # []
  
  Q = matrix(ZZ, [[5], [1]])
  M = ToricArithmeticMatroid(A, Q)
  
  print M
  # Toric arithmetic matroid of rank 1 on 4 elements
  
  print M.arrangement_matrix()
  # [-31  -4   5  17]
  
  print M.torus_matrix()
  # []
  ```

The other arithmetic matroid classes are of the form `XxxArithmeticMatroid`, deriving from the corresponding Sage class `XxxMatroid`.
An instance of `XxxArithmeticMatroid` can be constructed with `XxxArithmeticMatroid(..., multiplicity_function=m)`, where `...` should be replaced by arguments to construct an instance of `XxxMatroid`, and `m` is the multiplicity function.
The multiplicity function needs to be passed as a keyword argument (and not as a positional argument).

* `BasisArithmeticMatroid`
* `LinearArithmeticMatroid`
* `CircuitClosuresArithmeticMatroid`
* `GraphicArithmeticMatroid`
* `MinorArithmeticMatroid`
* `DualArithmeticMatroid`



### Available methods

All classes for arithmetic matroids must also derive from some subclass of Sage's `Matroid`.
In particular, all `Matroid` methods are still available. For example:
```sage
M = ToricArithmeticMatroid(matrix(ZZ, [[1,2,3], [0,1, 1]]))
print list(M.bases())
# [frozenset([0, 1]), frozenset([0, 2]), frozenset([1, 2])]
```

All subclasses of `ArithmeticMatroidMixin` also implement the following methods.

* `multiplicity(X)`
  Return the multiplicity of the set `X`.


### Creating new classes for arithmetic matroids
...


## Bibliography

...

## Licence

...
