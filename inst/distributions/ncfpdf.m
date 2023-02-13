## Copyright (C) 2022 Andreas Bertsatos <abertsatos@biol.uoa.gr>
##
## This file is part of the statistics package for GNU Octave.
##
## This program is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free Software
## Foundation; either version 3 of the License, or (at your option) any later
## version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along with
## this program; if not, see <http://www.gnu.org/licenses/>.

## -*- texinfo -*-
## @deftypefn  {statistics} {@var{y} =} ncfpdf (@var{x}, @var{df1}, @var{df2}, @var{delta})
##
## Noncentral F probability density function (PDF).
##
## @code{@var{y} = ncfpdf (@var{x}, @var{df1}, @var{df2}, @var{delta})} returns
## the noncentral F distribution with @var{df1} and @var{df2} numerator and
## denumerator degrees of freedom, respectively, and noncentrality parameter
## @var{delta}, at the values of @var{x}.
##
## The size of @var{y} is the common size of @var{df} and @var{delta}.  A scalar
## input functions as a constant matrix of the same size as the K_all inputs.
##
## @seealso{ncfcdf, ncfinv, ncfrnd, ncfstat}
## @end deftypefn

function y = ncfpdf (x, df1, df2, delta)

  ## Check for valid input arguments
  if (nargin <  4)
    error ("ncfpdf: too few input arguments.");
  endif

  ## Check and fix size of input arguments
  [err, x, df1, df2, delta] = common_size (x, df1, df2, delta);
  if (err > 0)
    error ("ncfpdf: input size mismatch.");
  endif

  ## Initialize Y
  if (isa (x, "single") || isa (df1, "single") || ...
      isa (df2, "single") || isa (delta, "single"))
    y = zeros (size (x), "single");
  else
    y = zeros (size (x));
  endif

  ## Find NaNs in input arguments (if any) and propagate them to p
  is_nan = isnan (x) | isnan (df1) | isnan (df2) | isnan (delta);
  y(is_nan) = NaN;

  ## Force invalid parameter cases to NaN
  k1 = df1 <= 0 | df2 <= 0 | delta < 0;
  y(k1) = NaN;

  ## Handle edge cases where x == 0
  k2 = x == 0 & df1 < 2 & ! k1;
  y(k2) = Inf;
  k3 = x == 0 & df1 == 2 & ! k1;
  if (any (k3(:)))
    y(k3) = exp (-delta(k3) / 2);
  endif

  ## Handle central distribution where delta == 0
  k4 = delta == 0 & ! k1 & x > 0;
  if any(k4(:))
    y(k4) = fpdf (x(k4), df1(k4), df2(k4));
  endif

  ## Handle normal cases
  td = find (x > 0 & ! (k1 | k4));
  ## Return if finished all normal cases
  if (isempty (td))
    return;
  endif

  ## Reset input variables to remaining cases and pre-divide df1, df2 and delta
  x = x(td);
  df1 = df1(td) / 2;
  df2 = df2(td) / 2;
  delta = delta(td) / 2;

  ## Use z and scaled x for convenience
  z = df1 .* x ./ (df1 .* x + df2);
  z1 = df2 ./ (df1 .* x + df2);
  xs = delta .* z;

  % Find max K at which we start the recursion series
  K = zeros (size (x));
  termK = zeros (size (x));
  rsum = zeros (size (x));
  ## Handy constant
  lnsr2pi = 0.9189385332046727;

  ## Process integer and non-integer df2 separately
  df2int = df2 == floor (df2);
  if (any (df2int(:))) # integers
    smallx = xs <= df1 ./ df2;
    largex = xs >= df2 .* (df1 + df2 - 1) & ! smallx;
    K(df2int & largex) = df2(df2int & largex);
    ## Compute K
    idx = df2int & ! (smallx | largex);
    if (any (idx(:)))
      d = 0.5 * (1 - xs(idx) - df1(idx));
      K(idx) = floor (d + sqrt (d .^ 2 + xs(idx) .* (df2(idx) + 1)));
    endif
    ## For K == df2
    K_df2 = df2int & K == df2;
    idz1 = K_df2 & z < 0.9;
    termK(idz1) = (df1(idz1) + df2(idz1) - 1) .* log (z(idz1));
    idz2 = K_df2 & ! idz1;
    termK(idz2) = (df1(idz2) + df2(idz2) - 1) .* log1p (-z1(idz2));
    ## For K == 0
    Kzero = df2int & (df1 + K) <= 1;
    termK(Kzero) = StirlingError (df1(Kzero) + df2(Kzero)) - ...
                   StirlingError (df1(Kzero)) - StirlingError (df2(Kzero)) - ...
                   BinoPoisson (df1(Kzero), ...
                               (df1(Kzero) + df2(Kzero)) .* z(Kzero)) - ...
                   BinoPoisson (df2(Kzero), ...
                               (df1(Kzero) + df2(Kzero)) .* z1(Kzero));
    ## For all other K
    K_all = df2int & ! (K_df2 | Kzero);
    termK(K_all) = StirlingError (df1(K_all) + df2(K_all) - 1) - ...
                   StirlingError (df1(K_all) + K(K_all) -1) - ...
                   StirlingError (df2(K_all) - K(K_all)) - ...
                   BinoPoisson (df1(K_all) + K(K_all) - 1, ...
                               (df1(K_all) + df2(K_all) - 1) .* z(K_all)) - ...
                   BinoPoisson (df2(K_all) - K(K_all), ...
                               (df1(K_all) + df2(K_all) - 1) .* z1(K_all));
    ## Poisson density for the leading term
    x1 = delta .* z1;
    smallk = df2int & K <= x1 * realmin;
    y(td(smallk)) = termK(smallk) - x1(smallk);
    otherk = df2int & ! smallk;
    y(td(otherk)) = termK(otherk) - lnsr2pi - 0.5 * log (K(otherk)) - ...
                    StirlingError (K(otherk)) - ...
                    BinoPoisson (K(otherk), x1(otherk));
    ## Sum recursively downwards
    term = ones (size (x));
    k = K;
    ok = df2int & k > 0;
    while (any (ok(:)))
      k(ok) = k(ok) - 1;
      term(ok) = term(ok) .* (k(ok) + 1) .* ...
                             (k(ok) + df1(ok)) ./ (df2(ok) - k(ok)) ./ xs(ok);
      ok = ok & term >= eps (rsum);
      rsum(ok) = rsum(ok) + term(ok);
    endwhile
    ## Sum recursively upwards
    term = ones (size (x));
    k = K;
    ok = df2int & k < df2;
    while any(ok(:))
      term(ok) = term(ok) .* xs(ok) .* ...
                 (df2(ok) - k(ok)) ./ (k(ok) + df1(ok)) ./ (k(ok) + 1);
      ok = ok & term >= eps(rsum);
      rsum(ok) = rsum(ok) + term(ok);
      k(ok) = k(ok) + 1;
    endwhile
  endif

  if (any (! df2int(:))) # non-integers
    ## Compute K
    largex = ! df2int & xs > df1 ./ (df1 + df2);
    d = 0.5 * (1 + xs(largex) - df1(largex));
    K(largex) = floor (d + sqrt (d .^ 2 + xs(largex) .* ...
                      (df1(largex) + df2(largex) - 1)));
    ## For K == 0
    Kzero = ! df2int & (df1 + K) <= 1;
    termK(Kzero) = StirlingError (df1(Kzero) + df2(Kzero)) - ...
                   StirlingError (df1(Kzero)) - ...
                   StirlingError (df2(Kzero)) - ...
                   BinoPoisson (df1(Kzero), ...
                               (df1(Kzero) + df2(Kzero)) .* z(Kzero)) - ...
                   BinoPoisson (df2(Kzero), ...
                               (df1(Kzero) + df2(Kzero)) .* z1(Kzero));
    ## For K != 0
    K_all = ! df2int & ! Kzero;
    termK(K_all) = StirlingError (df1(K_all) + df2(K_all) + K(K_all) - 1) - ...
                   StirlingError (df1(K_all) + K(K_all) - 1) - ...
                   StirlingError (df2(K_all)) - ...
                   BinoPoisson (df1(K_all) + K(K_all) - 1, ...
                               (df1(K_all) + df2(K_all) + K(K_all) - 1) .* ...
                               z(K_all)) - ...
                   BinoPoisson (df2(K_all), ...
                               (df1(K_all) + df2(K_all) + K(K_all) - 1) .* ...
                               z1(K_all));
    ## Poisson density for the leading term
    smallk = ! df2int & K <= delta * realmin;
    y(td(smallk)) = termK(smallk) - delta(smallk);
    K_all = ! df2int & ! smallk;
    y(td(K_all)) = termK(K_all) - lnsr2pi - 0.5 * log (K(K_all)) - ...
                   StirlingError (K(K_all)) - ...
                   BinoPoisson (K(K_all), delta(K_all));
    ## Sum recursively downwards
    term = ones (size (x));
    k = K;
    ok = ! df2int & k > 0;
    while (any (ok(:)))
      k(ok) = k(ok) - 1;
      term(ok) = term(ok) .* (k(ok) + 1) .* (k(ok) + df1(ok)) ./ ...
                             (k(ok) + df1(ok) + df2(ok)) ./ xs(ok);
      ok = ok & term >= eps (rsum);
      rsum(ok) = rsum(ok) + term(ok);
    endwhile
    ## Sum recursively upwards
    term = ones (size (x));
    k = K;
    ok = ! df2int;
    while (any (ok(:)))
      term(ok) = term(ok) .* xs(ok) .* (k(ok) + df1(ok) + df2(ok)) ./ ...
                                       (k(ok) + df1(ok)) ./ (k(ok) + 1);
      ok = ok & term >= eps (rsum);
      rsum(ok) = rsum(ok) + term(ok);
      k(ok) = k(ok)+1;
    endwhile
  endif

  ## Compute density
  pi2 = 2 * pi;
  Kzero = (df1 + K) <= 1;
  y(td(Kzero)) = exp (y(td(Kzero))) .* (1 + rsum(Kzero)) .* ...
                 sqrt (df1(Kzero) .* df2(Kzero) ./ ...
                      (df1(Kzero) + df2(Kzero)) / pi2) ./ ...
                 x(Kzero);
  K_df2 = ! Kzero & df2int & K == df2;
  y(td(K_df2)) = exp (y(td(K_df2))) .* (1 + rsum(K_df2)) .* ...
                 df1(K_df2) .* z1(K_df2);
  idx = ! Kzero & df2int & ! K_df2;
  y(td(idx)) = exp (y(td(idx))) .* (1 + rsum(idx)) .* df1(idx) .* z1(idx) .* ...
               sqrt((df1(idx) + df2(idx) - 1) ./ (df2(idx) - K(idx)) ./ ...
                    (df1(idx) + K(idx) - 1) / pi2);
  idx = ! df2int & ! Kzero;
  y(td(idx)) = exp (y(td(idx))) .* (1 + rsum(idx)) .* df1(idx) .* z1(idx) .* ...
               sqrt ((df1(idx) + df2(idx) + K(idx) - 1) ./ ...
               df2(idx) ./ (df1(idx) + K(idx) - 1) / pi2);

endfunction

## Error of Stirling-De Moivre approximation to n factorial.
function delta = StirlingError (n)
  is_class = class (n);
  delta = zeros (size (n), is_class);
  nn = n .* n;
  ## Define S0=1/12 S1=1/360 S2=1/1260 S3=1/1680 S4=1/1188
  S0 = 8.333333333333333e-02;
  S1 = 2.777777777777778e-03;
  S2 = 7.936507936507937e-04;
  S3 = 5.952380952380952e-04;
  S4 = 8.417508417508418e-04;
  ## Define delta(n) for n<0:0.5:15
  sfe=[                    0;       1.534264097200273e-01;...
       8.106146679532726e-02;       5.481412105191765e-02;...
       4.134069595540929e-02;       3.316287351993629e-02;...
       2.767792568499834e-02;       2.374616365629750e-02;...
       2.079067210376509e-02;       1.848845053267319e-02;...
       1.664469118982119e-02;       1.513497322191738e-02;...
       1.387612882307075e-02;       1.281046524292023e-02;...
       1.189670994589177e-02;       1.110455975820868e-02;...
       1.041126526197210e-02;       9.799416126158803e-03;...
       9.255462182712733e-03;       8.768700134139385e-03;...
       8.330563433362871e-03;       7.934114564314021e-03;...
       7.573675487951841e-03;       7.244554301320383e-03;...
       6.942840107209530e-03;       6.665247032707682e-03;...
       6.408994188004207e-03;       6.171712263039458e-03;...
       5.951370112758848e-03;       5.746216513010116e-03;...
       5.554733551962801e-03];
  k = find (n <= 15);
  if (any (k))
    n1 = n(k);
    n2 = 2 * n1;
    if (all (n2 == round (n2)))
        delta(k) = sfe(n2+1);
    else
        lnsr2pi = 0.9189385332046728;
        delta(k) = gammaln(n1+1)-(n1+0.5).*log(n1)+n1-lnsr2pi;
    endif
  endif
  k = find (n > 15 & n <= 35);
  if (any (k))
    delta(k) = (S0 - (S1 - (S2 - (S3 - S4 ./ nn(k)) ./ nn(k)) ./ ...
                                             nn(k)) ./ nn(k)) ./ n(k);
  endif
  k = find (n > 35 & n <= 80);
  if (any (k))
    delta(k) = (S0 - (S1 - (S2 - S3 ./ nn(k)) ./ nn(k)) ./ nn(k)) ./ n(k);
  endif
  k = find(n > 80 & n <= 500);
  if (any (k))
    delta(k) = (S0 - (S1 - S2 ./ nn(k)) ./ nn(k)) ./ n(k);
  endif
  k = find(n > 500);
  if (any (k))
    delta(k) = (S0 - S1 ./ nn(k)) ./ n(k);
  endif
endfunction

## Deviance term for binomial and Poisson probability calculation.
function BP = BinoPoisson (x, np)
  if (isa (x,'single') || isa (np,'single'))
    BP = zeros (size (x), "single");
  else
    BP = zeros (size (x));
  endif
  k = abs (x - np) < 0.1 * (x + np);
  if any(k(:))
    s = (x(k) - np(k)) .* (x(k) - np(k)) ./ (x(k) + np(k));
    v = (x(k) - np(k)) ./ (x(k) + np(k));
    ej = 2 .* x(k) .* v;
    is_class = class (s);
    s1 = zeros (size (s), is_class);
    ok = true (size (s));
    j = 0;
    while any(ok(:))
      ej(ok) = ej(ok) .* v(ok) .* v(ok);
      j = j + 1;
      s1(ok) = s(ok) + ej(ok) ./ (2 * j + 1);
      ok = ok & s1 != s;
      s(ok) = s1(ok);
    endwhile
    BP(k) = s;
  endif
  k = ! k;
  if (any (k(:)))
    BP(k) = x(k) .* log (x(k) ./ np(k)) + np(k) - x(k);
  endif
endfunction

## Input validation tests
%!error<ncfpdf: too few input arguments.> p = ncfpdf ();
%!error<ncfpdf: too few input arguments.> p = ncfpdf (2);
%!error<ncfpdf: too few input arguments.> p = ncfpdf (2, 4);
%!error<ncfpdf: too few input arguments.> p = ncfpdf (2, 4, 3);
%!error<ncfpdf: input size mismatch.> p = ncfpdf (5, 2,  [4, 3], [3, 4, 5]);

## Output validation tests
%!shared x1, df1, df2, delta
%! x1 = [-Inf, 2, NaN, 4, Inf];
%! df1 = [2, 0, -1, 1, 4];
%! df2 = [2, 4, 5, 6, 8];
%! delta = [1, NaN, 3, -1, 2];
%!assert (ncfpdf (x1, df1, df2, delta), [0, NaN, NaN, NaN, NaN]);
%!assert (ncfpdf (x1, df1, df2, 1), [0, NaN, NaN, ...
%!                                   0.05607937264237208, NaN], 1e-14);
%!assert (ncfpdf (x1, df1, df2, 3), [0, NaN, NaN, ...
%!                                   0.080125760971946518, NaN], 1e-14);
%!assert (ncfpdf (x1, df1, df2, 2), [0, NaN, NaN, ...
%!                                   0.0715902008258656, NaN], 1e-14);
%!assert (ncfpdf (x1, 3, 5, delta), [0, NaN, NaN, NaN, NaN]);
%!assert (ncfpdf (2, df1, df2, delta), [0.1254046999837947, NaN, NaN, ...
%!                                      NaN, 0.2152571783045893], 1e-14);
%!assert (ncfpdf (4, df1, df2, delta), [0.05067089541001374, NaN, NaN, ...
%!                                      NaN, 0.05560846335398539], 1e-14);
